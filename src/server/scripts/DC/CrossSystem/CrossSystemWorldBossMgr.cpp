/*
 * CrossSystemWorldBossMgr.cpp - Centralized World Boss Management System
 * ============================================================================
 */

#include "CrossSystemWorldBossMgr.h"

#include "Config.h"
#include "GameTime.h"
#include "Group.h"
#include "Log.h"
#include "ObjectAccessor.h"
#include "World.h"
#include "WorldConfig.h"
#include "WorldSession.h"

namespace DC
{
    // Resolves a zone's display name from AreaTable.dbc, falling back to "Unknown" if the
    // zone id has no entry or the entry has no localized name.
    static std::string GetZoneNameFromDBC(uint32 zoneId)
    {
        std::string zoneName = "Unknown";
        if (AreaTableEntry const* area = sAreaTableStore.LookupEntry(zoneId))
        {
            if (area->area_name[0] && area->area_name[0][0])
                zoneName = area->area_name[0];
        }
        return zoneName;
    }

    WorldBossMgr* WorldBossMgr::Instance()
    {
        static WorldBossMgr instance;
        return &instance;
    }

    void WorldBossMgr::LoadConfig()
    {
        _lockoutEnabled     = sConfigMgr->GetOption<bool>("DC.WorldBoss.Lockout.Enable", true);
        _lockoutSeconds     = sConfigMgr->GetOption<uint32>("DC.WorldBoss.Lockout.Seconds", 604800);
        _gracePeriodSeconds = sConfigMgr->GetOption<uint32>("DC.WorldBoss.Lockout.GraceSeconds", 300);
        _phaseOnEngage      = sConfigMgr->GetOption<bool>("DC.WorldBoss.Phase.OnEngage", false);
        _phaseMask          = sConfigMgr->GetOption<uint32>("DC.WorldBoss.Phase.Mask", 0x40000000);

        // The lockout persists through the core player-settings system (character_settings table),
        // which only writes to the DB when EnablePlayerSettings is on. Without it, lockouts are
        // tracked in memory but reset on relog/restart -- warn loudly so it is not a silent surprise.
        if (_lockoutEnabled && !sWorld->getBoolConfig(CONFIG_PLAYER_SETTINGS_ENABLED))
        {
            LOG_WARN("scripts.dc", "WorldBossMgr: DC.WorldBoss.Lockout.Enable=1 but EnablePlayerSettings=0 -- "
                     "boss loot lockouts will NOT persist across relog/restart. Set EnablePlayerSettings = 1.");
        }

        LOG_INFO("scripts.dc", "WorldBossMgr: config loaded (lockout={}, window={}s, grace={}s, phasing={}, phaseMask=0x{:X})",
                 _lockoutEnabled, _lockoutSeconds, _gracePeriodSeconds, _phaseOnEngage, _phaseMask);
    }

    void WorldBossMgr::RegisterBoss(uint32 entry, uint32 spawnId, std::string_view displayName,
                                     uint32 zoneId, uint32 respawnTimeSeconds, uint32 lockoutSeconds)
    {
        WorldBossInfo info;
        info.creatureEntry = entry;
        info.spawnId = spawnId;
        info.displayName = std::string(displayName);
        info.zoneId = zoneId;
        info.respawnTimeSeconds = respawnTimeSeconds;
        info.lockoutSeconds = lockoutSeconds;
        info.isActive = false;
        info.respawnCountdown = -1;

        _bossesByEntry[entry] = info;
        _spawnIdToEntry[spawnId] = entry;

        LOG_INFO("scripts.dc", "WorldBossMgr: Registered boss {} (entry={}, spawnId={}, zone={})",
                 displayName, entry, spawnId, zoneId);
    }

    WorldBossInfo* WorldBossMgr::GetBossInfo(uint32 entry)
    {
        auto it = _bossesByEntry.find(entry);
        return it != _bossesByEntry.end() ? &it->second : nullptr;
    }

    WorldBossInfo* WorldBossMgr::GetBossInfoBySpawnId(uint32 spawnId)
    {
        auto it = _spawnIdToEntry.find(spawnId);
        if (it == _spawnIdToEntry.end())
            return nullptr;
        return GetBossInfo(it->second);
    }

    std::vector<WorldBossInfo const*> WorldBossMgr::GetAllBosses() const
    {
        std::vector<WorldBossInfo const*> result;
        result.reserve(_bossesByEntry.size());
        for (auto const& pair : _bossesByEntry)
            result.push_back(&pair.second);
        return result;
    }

    bool WorldBossMgr::IsBossActive(uint32 entry) const
    {
        auto it = _bossesByEntry.find(entry);
        return it != _bossesByEntry.end() && it->second.isActive;
    }

    void WorldBossMgr::OnBossSpawned(Creature* boss)
    {
        if (!boss)
            return;

        auto* info = GetBossInfo(boss->GetEntry());
        if (!info)
        {
            // Boss not registered, but still send the update
            LOG_DEBUG("scripts.worldboss", "WorldBossMgr::OnBossSpawned - Boss {} not registered",
                      boss->GetEntry());
        }
        else
        {
            info->isActive = true;
            info->respawnCountdown = -1;
            info->currentGuid = boss->GetGUID();
            info->phasedPlayers.clear(); // stale phase state must not survive a (re)spawn
        }

        // A rotation despawn/respawn must never leave the boss in a leftover combat phase.
        if (_phaseOnEngage && boss->GetPhaseMask() != PHASEMASK_NORMAL)
            boss->SetPhaseMask(PHASEMASK_NORMAL, true);

        BroadcastBossUpdate(boss, "spawn", true);
    }

    void WorldBossMgr::OnBossEngaged(Creature* boss, Unit* who)
    {
        if (!boss)
            return;

        auto* info = GetBossInfo(boss->GetEntry());
        if (info)
        {
            info->isActive = true;
        }

        // Anti-grief phasing: move the boss and the engaging group into a private combat phase so
        // uninvolved players in the open world cannot tag-steal or grief the encounter.
        if (_phaseOnEngage && info)
        {
            if (boss->GetPhaseMask() != _phaseMask)
                boss->SetPhaseMask(_phaseMask, true);

            Player* engager = who ? who->GetCharmerOrOwnerPlayerOrPlayerItself() : nullptr;
            if (engager)
                PhaseGroupIn(engager, boss, _phaseMask);
        }

        BroadcastBossUpdate(boss, "engage", true);
    }

    void WorldBossMgr::OnBossHPUpdate(Creature* boss, uint8 hpPct, uint8 threshold)
    {
        if (!boss)
            return;

        // Build update with threshold info
        DCAddon::JsonValue bossesArr;
        bossesArr.SetArray();
        DCAddon::JsonValue b;
        b.SetObject();
        BuildBossJson(b, boss, "hp_update", true, -1);
        b.Set("hpPct", DCAddon::JsonValue(static_cast<int32>(hpPct)));
        b.Set("threshold", DCAddon::JsonValue(static_cast<int32>(threshold)));
        bossesArr.Push(b);

        DCAddon::JsonMessage msg(DCAddon::Module::WORLD, DCAddon::Opcode::World::SMSG_UPDATE);
        msg.Set("bosses", bossesArr);

        if (Map* map = boss->GetMap())
        {
            map->DoForAllPlayers([&](Player* player) {
                if (player && player->IsInWorld() && player->GetSession())
                    msg.Send(player);
            });
        }
    }

    void WorldBossMgr::OnBossDied(Creature* boss)
    {
        if (!boss)
            return;

        uint32 const entry = boss->GetEntry();

        // Save eligible looters to this boss for the lockout window. isTappedBy() mirrors the
        // engine's own loot eligibility, so the set of locked players matches exactly who can loot.
        // The post-kill grace period (see IsPlayerLockedOut) keeps THIS corpse lootable for them.
        // Only stamp players who are NOT already locked from a prior kill: re-stamping would move the
        // lock's start time to now, so grace would let an already-locked player loot every kill.
        if (_lockoutEnabled && GetBossInfo(entry))
        {
            if (Map* map = boss->GetMap())
            {
                map->DoForAllPlayers([&](Player* player)
                {
                    if (player && player->IsInWorld() && boss->isTappedBy(player)
                        && GetLockoutRemaining(player, entry) == 0)
                        LockPlayer(player, entry);
                });
            }
        }

        // Release the combat phase (kill path) so the corpse and its looters are back in the normal world.
        if (_phaseOnEngage)
            RestoreBossPhase(boss);

        auto* info = GetBossInfo(entry);
        int32 spawnIn = -1;

        if (info)
        {
            info->isActive = false;
            info->currentGuid.Clear();

            // Calculate respawn time
            boss->SetRespawnTime(boss->GetRespawnDelay());
            boss->SaveRespawnTime();

            time_t now = GameTime::GetGameTime().count();
            int64 diff = 0;

            if (Map* map = boss->GetMap())
            {
                time_t rt = map->GetCreatureRespawnTime(static_cast<ObjectGuid::LowType>(boss->GetSpawnId()));
                diff = static_cast<int64>(rt) - static_cast<int64>(now);
            }

            if (diff <= 0)
                diff = static_cast<int64>(boss->GetRespawnTimeEx()) - static_cast<int64>(now);

            spawnIn = diff > 0 ? static_cast<int32>(diff) : static_cast<int32>(boss->GetRespawnDelay());
            info->respawnCountdown = spawnIn;
        }

        BroadcastBossUpdate(boss, "death", false, spawnIn);
    }

    void WorldBossMgr::Update(uint32 diffMs)
    {
        int32 diffSec = static_cast<int32>(diffMs / 1000);
        if (diffSec <= 0)
            return;

        for (auto& pair : _bossesByEntry)
        {
            WorldBossInfo& info = pair.second;
            if (!info.isActive && info.respawnCountdown > 0)
            {
                info.respawnCountdown -= diffSec;
                if (info.respawnCountdown < 0)
                    info.respawnCountdown = 0;
            }
        }
    }

    void WorldBossMgr::BroadcastBossUpdate(Creature* boss, std::string_view action, bool active, int32 spawnIn)
    {
        DCAddon::JsonValue bossesArr;
        bossesArr.SetArray();
        DCAddon::JsonValue b;
        b.SetObject();
        BuildBossJson(b, boss, action, active, spawnIn);
        bossesArr.Push(b);

        DCAddon::JsonMessage msg(DCAddon::Module::WORLD, DCAddon::Opcode::World::SMSG_UPDATE);
        msg.Set("bosses", bossesArr);

        if (Map* map = boss->GetMap())
        {
            map->DoForAllPlayers([&](Player* player) {
                if (player && player->IsInWorld() && player->GetSession())
                    msg.Send(player);
            });
        }
    }

    void WorldBossMgr::BuildBossJson(DCAddon::JsonValue& b, Creature* boss, std::string_view action,
                                      bool active, int32 spawnIn) const
    {
        uint32 zoneId = boss->GetZoneId();

        b.Set("entry", DCAddon::JsonValue(static_cast<int32>(boss->GetEntry())));
        b.Set("spawnId", DCAddon::JsonValue(static_cast<int32>(boss->GetSpawnId())));
        b.Set("name", DCAddon::JsonValue(boss->GetName()));
        b.Set("mapId", DCAddon::JsonValue(static_cast<int32>(boss->GetMapId())));
        b.Set("zoneId", DCAddon::JsonValue(static_cast<int32>(zoneId)));

        // Zone name from DBC
        b.Set("zone", DCAddon::JsonValue(GetZoneNameFromDBC(zoneId)));

        // Normalized coordinates for map pin placement
        float nx = 0.0f, ny = 0.0f;
        if (DarkChaos::CrossSystem::MapCoords::TryComputeNormalized(zoneId, boss->GetPositionX(), boss->GetPositionY(), nx, ny))
        {
            b.Set("nx", DCAddon::JsonValue(nx));
            b.Set("ny", DCAddon::JsonValue(ny));
        }

        b.Set("guid", DCAddon::JsonValue(boss->GetGUID().ToString()));
        b.Set("active", DCAddon::JsonValue(active));
        b.Set("hpPct", DCAddon::JsonValue(static_cast<int32>(boss->GetHealthPct())));
        b.Set("action", DCAddon::JsonValue(std::string(action)));

        if (spawnIn >= 0)
        {
            b.Set("spawnIn", DCAddon::JsonValue(spawnIn));
            b.Set("status", DCAddon::JsonValue("spawning"));
        }
        else if (active)
        {
            b.Set("status", DCAddon::JsonValue("active"));
        }
    }

    DCAddon::JsonValue WorldBossMgr::BuildBossesContentArray() const
    {
        DCAddon::JsonValue arr;
        arr.SetArray();

        for (auto const& pair : _bossesByEntry)
        {
            WorldBossInfo const& info = pair.second;

            DCAddon::JsonValue b;
            b.SetObject();
            b.Set("entry", DCAddon::JsonValue(static_cast<int32>(info.creatureEntry)));
            b.Set("spawnId", DCAddon::JsonValue(static_cast<int32>(info.spawnId)));
            b.Set("name", DCAddon::JsonValue(info.displayName));
            b.Set("mapId", DCAddon::JsonValue(static_cast<int32>(info.zoneId))); // Use zoneId as mapId for client WRLD compatibility
            b.Set("zoneId", DCAddon::JsonValue(static_cast<int32>(info.zoneId)));
            b.Set("active", DCAddon::JsonValue(info.isActive));

            // Normalized coordinates for map pin placement
            // We need to look up the creature definition to get X/Y if the boss isn't spawned
            float posX = 0.0f, posY = 0.0f;
            bool havePos = false;

            if (const CreatureData* data = sObjectMgr->GetCreatureData(info.spawnId))
            {
                posX = data->posX;
                posY = data->posY;
                havePos = true;
            }

            if (havePos)
            {
                float nx = 0.0f, ny = 0.0f;
                if (DarkChaos::CrossSystem::MapCoords::TryComputeNormalized(info.zoneId, posX, posY, nx, ny))
                {
                    b.Set("nx", DCAddon::JsonValue(nx));
                    b.Set("ny", DCAddon::JsonValue(ny));
                }
            }

            if (!info.isActive && info.respawnCountdown > 0)
            {
                b.Set("spawnIn", DCAddon::JsonValue(info.respawnCountdown));
                b.Set("status", DCAddon::JsonValue("spawning"));
            }
            else if (info.isActive)
            {
                b.Set("status", DCAddon::JsonValue("active"));
            }
            else
            {
                // If not active and no timer, it's ready to spawn (or just unknown).
                // Usually this means it's available.
                b.Set("status", DCAddon::JsonValue("active"));
                b.Set("active", DCAddon::JsonValue(true)); // Force active flag if it's "ready"
            }

            // Zone name from DBC
            b.Set("zone", DCAddon::JsonValue(GetZoneNameFromDBC(info.zoneId)));

            arr.Push(b);
        }

        return arr;
    }

    // ========================================================================
    // Loot lockout
    // ========================================================================

    std::string WorldBossMgr::GetLockSource(uint32 entry)
    {
        // Player-setting source key: one character_settings row per boss entry.
        return "dc-worldboss#" + std::to_string(entry);
    }

    uint32 WorldBossMgr::GetLockoutSecondsFor(uint32 entry) const
    {
        auto it = _bossesByEntry.find(entry);
        if (it != _bossesByEntry.end() && it->second.lockoutSeconds > 0)
            return it->second.lockoutSeconds; // per-boss override
        return _lockoutSeconds;               // global default
    }

    void WorldBossMgr::LockPlayer(Player* player, uint32 entry)
    {
        if (!player)
            return;

        uint32 const now = static_cast<uint32>(GameTime::GetGameTime().count());
        uint32 const expiry = now + GetLockoutSecondsFor(entry);
        player->UpdatePlayerSetting(GetLockSource(entry), 0, expiry);
    }

    bool WorldBossMgr::IsPlayerLockedOut(Player const* player, uint32 entry) const
    {
        if (!_lockoutEnabled || !player)
            return false;

        // GetPlayerSetting is not const (it lazily creates a zero row); the read itself is harmless.
        uint32 const expiry = const_cast<Player*>(player)->GetPlayerSetting(GetLockSource(entry), 0).value;
        if (expiry == 0)
            return false;

        uint32 const now = static_cast<uint32>(GameTime::GetGameTime().count());
        if (now >= expiry)
            return false; // lockout window elapsed -> lootable again

        // Locked, but honour the post-kill grace period so the group that just tagged the boss can
        // still loot (and re-open) the fresh corpse. The lock was stamped at kill time = expiry - window.
        uint32 const lockSetTime = expiry - GetLockoutSecondsFor(entry);
        if (now < lockSetTime + _gracePeriodSeconds)
            return false;

        return true;
    }

    uint32 WorldBossMgr::GetLockoutRemaining(Player const* player, uint32 entry) const
    {
        if (!player)
            return 0;

        uint32 const expiry = const_cast<Player*>(player)->GetPlayerSetting(GetLockSource(entry), 0).value;
        uint32 const now = static_cast<uint32>(GameTime::GetGameTime().count());
        return expiry > now ? (expiry - now) : 0;
    }

    void WorldBossMgr::ClearPlayerLockout(Player* player, uint32 entry)
    {
        if (!player)
            return;

        player->UpdatePlayerSetting(GetLockSource(entry), 0, 0);
    }

    std::string WorldBossMgr::FormatDuration(uint32 seconds)
    {
        uint32 const days = seconds / 86400; seconds %= 86400;
        uint32 const hours = seconds / 3600;  seconds %= 3600;
        uint32 const mins = seconds / 60;

        std::string out;
        if (days)
            out += std::to_string(days) + "d ";
        if (hours || days)
            out += std::to_string(hours) + "h ";
        out += std::to_string(mins) + "m";
        return out;
    }

    // ========================================================================
    // Anti-grief phasing
    // ========================================================================

    void WorldBossMgr::PhaseGroupIn(Player* leader, Creature* boss, uint32 phaseMask)
    {
        auto* info = GetBossInfo(boss->GetEntry());
        if (!info)
            return;

        auto phaseOne = [&](Player* p)
        {
            if (!p || !p->IsInWorld())
                return;
            // Save each player's original mask once so RestoreBossPhase can put them back exactly.
            if (info->phasedPlayers.find(p->GetGUID()) == info->phasedPlayers.end())
            {
                info->phasedPlayers[p->GetGUID()] = p->GetPhaseMask();
                p->SetPhaseMask(phaseMask, true);
            }
        };

        if (Group* group = leader->GetGroup())
        {
            for (GroupReference* itr = group->GetFirstMember(); itr != nullptr; itr = itr->next())
            {
                Player* member = itr->GetSource();
                // Only pull in members actually at the fight (same map as the boss).
                if (member && member->GetMap() == boss->GetMap())
                    phaseOne(member);
            }
        }
        else
        {
            phaseOne(leader);
        }
    }

    void WorldBossMgr::RestoreBossPhase(Creature* boss)
    {
        if (!boss)
            return;

        if (boss->GetPhaseMask() != PHASEMASK_NORMAL)
            boss->SetPhaseMask(PHASEMASK_NORMAL, true);

        auto* info = GetBossInfo(boss->GetEntry());
        if (!info)
            return;

        for (auto const& [guid, originalMask] : info->phasedPlayers)
        {
            if (Player* p = ObjectAccessor::FindPlayer(guid))
                p->SetPhaseMask(originalMask, true);
        }
        info->phasedPlayers.clear();
    }

} // namespace DC
