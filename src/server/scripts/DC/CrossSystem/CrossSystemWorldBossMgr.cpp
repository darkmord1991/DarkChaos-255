/*
 * CrossSystemWorldBossMgr.cpp - Centralized World Boss Management System
 * ============================================================================
 */

#include "CrossSystemWorldBossMgr.h"

#include "GameTime.h"
#include "Log.h"
#include "WorldSession.h"

namespace DC
{
    WorldBossMgr* WorldBossMgr::Instance()
    {
        static WorldBossMgr instance;
        return &instance;
    }

    void WorldBossMgr::RegisterBoss(uint32 entry, uint32 spawnId, std::string_view displayName,
                                     uint32 zoneId, uint32 respawnTimeSeconds)
    {
        WorldBossInfo info;
        info.creatureEntry = entry;
        info.spawnId = spawnId;
        info.displayName = std::string(displayName);
        info.zoneId = zoneId;
        info.respawnTimeSeconds = respawnTimeSeconds;
        info.isActive = false;
        info.respawnCountdown = -1;

        _bossesByEntry[entry] = info;
        _spawnIdToEntry[spawnId] = entry;

        LOG_INFO("server.loading", "WorldBossMgr: Registered boss {} (entry={}, spawnId={}, zone={})",
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
        }

        BroadcastBossUpdate(boss, "spawn", true);
    }

    void WorldBossMgr::OnBossEngaged(Creature* boss)
    {
        if (!boss)
            return;

        auto* info = GetBossInfo(boss->GetEntry());
        if (info)
        {
            info->isActive = true;
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

        auto* info = GetBossInfo(boss->GetEntry());
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
        std::string zoneName = "Unknown";
        if (const AreaTableEntry* area = sAreaTableStore.LookupEntry(zoneId))
        {
            if (area->area_name[0] && area->area_name[0][0])
                zoneName = area->area_name[0];
        }
        b.Set("zone", DCAddon::JsonValue(zoneName));

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
            b.Set("zoneId", DCAddon::JsonValue(static_cast<int32>(info.zoneId)));
            b.Set("active", DCAddon::JsonValue(info.isActive));

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
                b.Set("status", DCAddon::JsonValue("unknown"));
            }

            // Zone name from DBC
            if (const AreaTableEntry* area = sAreaTableStore.LookupEntry(info.zoneId))
            {
                if (area->area_name[0] && area->area_name[0][0])
                    b.Set("zone", DCAddon::JsonValue(area->area_name[0]));
            }

            arr.Push(b);
        }

        return arr;
    }

} // namespace DC
