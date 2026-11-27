/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * Final boss revive: when the final boss of a 5-player dungeon dies, every dead
 * player of that instance is resurrected where they died, with
 * DC.FinalBossRevive.RestorePct of their health and mana.
 *
 * The final boss is, in this order:
 *   1. the encounter instance_encounters marks as the dungeon's last
 *      (lastEncounterDungeon, an LFG id). Every stock dungeon has one, and one
 *      per wing where a map holds several (Dire Maul, Stratholme, Scarlet
 *      Monastery), so each wing's end boss revives the group.
 *   2. on an encounter list with no such mark (the DC custom dungeons have no
 *      LFG ids), the encounter with the highest DungeonEncounter.dbc OrderIndex.
 *   3. a map:creature pair in DC.FinalBossRevive.ExtraBosses, for the dungeons
 *      that have no encounter data at all.
 * Rules 1 and 2 are matched against the list the core actually credited
 * (Map::UpdateEncounterState), so the borrowed lists of Mythic and of the
 * classic dungeons' Heroic behave like their own.
 *
 * The revive runs from the instance's own update, once nobody is fighting:
 * while a boss encounter is in progress or a living player is in combat it
 * waits, for at most MAX_COMBAT_WAIT_MS.
 *
 * Players who released are ghosts on another map (a dungeon's graveyard is
 * outside), and that map belongs to another map thread. The instance only
 * queues a request; the world thread, which runs after MapMgr::Update has
 * joined every map worker, sends each ghost that died in the instance back to
 * its corpse. The core resurrects a ghost that enters a dungeon holding its
 * corpse (WorldSession::HandleMoveWorldportAck, at 50%); a marker on the player
 * raises that to the configured share.
 */

#include "dc_dungeon_qol.h"
#include "Chat.h"
#include "Creature.h"
#include "DataMap.h"
#include "GameTime.h"
#include "InstanceSaveMgr.h"
#include "Log.h"
#include "Map.h"
#include "ObjectAccessor.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptMgr.h"

#include <algorithm>
#include <atomic>
#include <limits>
#include <mutex>
#include <shared_mutex>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

namespace
{
    using namespace DC::DungeonQoL;

    constexpr uint32 EVALUATE_INTERVAL_MS = 500;
    constexpr uint32 MAX_COMBAT_WAIT_MS = 2 * MINUTE * IN_MILLISECONDS;
    constexpr uint64 RESTORE_MARKER_LIFETIME_MS = MINUTE * IN_MILLISECONDS;

    constexpr char const* REVIVED_TEXT = "|cff00ff00[Dungeon]|r The final boss has fallen: you have been resurrected.";

    std::string const REVIVE_STATE_KEY = "dc_final_boss_revive";
    std::string const RESTORE_MARKER_KEY = "dc_final_boss_restore";

    // Exists only between the final boss's death and the revive.
    struct ReviveState : DataMap::Base
    {
        uint32 creditEntry = 0; // creature entry, or spell id for a spell-credited encounter (logging only)
        uint32 timerMs = 0;
        uint32 waitedMs = 0;
    };

    // Set on a ghost before it is sent back, consumed by its arrival resurrection.
    struct RestoreMarker : DataMap::Base
    {
        uint32 mapId = 0;
        float restore = 1.0f;
        uint64 expiresAtMs = 0;
    };

    struct GhostRequest
    {
        uint32 mapId = 0;
        uint32 instanceId = 0;
        float restore = 1.0f;
    };

    // Filled by map threads, drained by the world thread.
    std::mutex g_ghostLock;
    std::vector<GhostRequest> g_ghostRequests;
    std::atomic<bool> g_hasGhostRequests{false};

    uint64 NowMs()
    {
        return static_cast<uint64>(GameTime::GetGameTimeMS().count());
    }

    // Rules 1 and 2 of the header, on the encounter list Map::UpdateEncounterState credited.
    // Returns the rule that matched, for the log, or nullptr when this is not a final encounter.
    char const* FinalEncounterRule(DungeonEncounterList const* encounters, EncounterCreditType type,
        uint32 creditEntry)
    {
        if (!encounters)
            return nullptr;

        bool anyMarked = false;
        int32 lastOrder = std::numeric_limits<int32>::min();
        for (DungeonEncounter const* encounter : *encounters)
        {
            if (!encounter || !encounter->dbcEntry)
                continue;

            if (encounter->lastEncounterDungeon)
                anyMarked = true;

            lastOrder = std::max(lastOrder, encounter->dbcEntry->orderIndex);
        }

        for (DungeonEncounter const* encounter : *encounters)
        {
            if (!encounter || !encounter->dbcEntry || encounter->creditType != type
                || encounter->creditEntry != creditEntry)
                continue;

            if (anyMarked && encounter->lastEncounterDungeon)
                return "marked final encounter";

            if (!anyMarked && encounter->dbcEntry->orderIndex == lastOrder)
                return "highest OrderIndex";
        }

        return nullptr;
    }

    void ScheduleRevive(Map* map, uint32 creditEntry, std::string_view bossName, char const* rule)
    {
        // The encounter credit and the death hook can both report the same kill: the first one wins.
        if (map->CustomData.Get<ReviveState>(REVIVE_STATE_KEY))
            return;

        map->CustomData.GetDefault<ReviveState>(REVIVE_STATE_KEY)->creditEntry = creditEntry;

        LOG_INFO("scripts.dc", "Final boss revive: {} (credit {}) down on map {} instance {} ({}), "
            "reviving once the instance is out of combat.",
            bossName.empty() ? std::string_view("final encounter") : bossName, creditEntry, map->GetId(),
            map->GetInstanceId(), rule);
    }

    uint32 ReviveDeadOnMap(Map* map, float restore)
    {
        // Collected first: resurrecting touches zone and visibility state, never the map's player list.
        std::vector<Player*> dead;
        for (auto const& ref : map->GetPlayers())
        {
            Player* player = ref.GetSource();
            if (player && player->IsInWorld() && !player->IsAlive() && !player->IsBeingTeleported())
                dead.push_back(player);
        }

        uint32 revived = 0;
        for (Player* player : dead)
        {
            player->ResurrectPlayer(restore);
            if (!player->IsAlive()) // refused by an OnPlayerCanResurrect hook
                continue;

            player->SpawnCorpseBones();
            ChatHandler(player->GetSession()).SendSysMessage(REVIVED_TEXT);
            ++revived;
        }

        return revived;
    }

    void QueueReleasedGhosts(Map* map, float restore)
    {
        std::lock_guard<std::mutex> guard(g_ghostLock);
        g_ghostRequests.push_back({ map->GetId(), map->GetInstanceId(), restore });
        g_hasGhostRequests.store(true, std::memory_order_release);
    }

    // The ghost died in that very instance and a teleport would put it back there.
    bool DiedIn(Player* player, GhostRequest const& request)
    {
        if (player->GetCorpseLocation().GetMapId() != request.mapId)
            return false;

        // The instance Player::TeleportTo picks (MapInstanced::CreateInstanceForPlayer).
        return sInstanceSaveMgr->PlayerGetDestinationInstanceId(player, request.mapId, player->GetDifficulty(false))
            == request.instanceId;
    }

    // World thread only.
    void BringBackGhosts(std::vector<GhostRequest> const& requests)
    {
        std::vector<std::pair<Player*, GhostRequest>> ghosts;
        {
            std::shared_lock<std::shared_mutex> lock(*HashMapHolder<Player>::GetLock());
            for (auto const& entry : ObjectAccessor::GetPlayers())
            {
                Player* player = entry.second;

                // Released and out in the world: never pull a ghost out of another instance or a battleground.
                if (!player || !player->IsInWorld() || player->IsAlive() || player->IsBeingTeleported()
                    || !player->HasPlayerFlag(PLAYER_FLAGS_GHOST) || player->GetMap()->Instanceable())
                    continue;

                for (GhostRequest const& request : requests)
                {
                    if (DiedIn(player, request))
                    {
                        ghosts.emplace_back(player, request);
                        break;
                    }
                }
            }
        }

        for (auto const& [player, request] : ghosts)
        {
            RestoreMarker* marker = player->CustomData.GetDefault<RestoreMarker>(RESTORE_MARKER_KEY);
            marker->mapId = request.mapId;
            marker->restore = request.restore;
            marker->expiresAtMs = NowMs() + RESTORE_MARKER_LIFETIME_MS;

            WorldLocation const corpse = player->GetCorpseLocation();
            if (!player->TeleportTo(corpse.GetMapId(), corpse.GetPositionX(), corpse.GetPositionY(),
                corpse.GetPositionZ(), corpse.GetOrientation()))
            {
                player->CustomData.Erase(RESTORE_MARKER_KEY);
                continue;
            }

            LOG_INFO("scripts.dc", "Final boss revive: {} had released and is sent back to the corpse "
                "on map {} instance {}.", player->GetName(), request.mapId, request.instanceId);
        }
    }

    class dc_final_boss_revive_encounters : public GlobalScript
    {
    public:
        dc_final_boss_revive_encounters()
            : GlobalScript("dc_final_boss_revive_encounters", { GLOBALHOOK_ON_AFTER_UPDATE_ENCOUNTER_STATE }) { }

        void OnAfterUpdateEncounterState(Map* map, EncounterCreditType type, uint32 creditEntry, Unit* source,
            Difficulty /*difficulty*/, DungeonEncounterList const* encounters, uint32 /*dungeonCompleted*/,
            bool /*updated*/) override
        {
            if (!map || !map->IsNonRaidDungeon() || !GetSettings()->finalBossReviveEnable)
                return;

            char const* rule = FinalEncounterRule(encounters, type, creditEntry);
            if (!rule)
                return;

            // A spell credit's source is its caster, not the boss.
            bool const sourceIsBoss = type == ENCOUNTER_CREDIT_KILL_CREATURE && source
                && source->GetEntry() == creditEntry;
            ScheduleRevive(map, creditEntry, sourceIsBoss ? std::string_view(source->GetName()) : std::string_view(),
                rule);
        }
    };

    // Rule 3: dungeons without encounter data never reach the encounter hook.
    class dc_final_boss_revive_deaths : public UnitScript
    {
    public:
        dc_final_boss_revive_deaths()
            : UnitScript("dc_final_boss_revive_deaths", true, { UNITHOOK_ON_UNIT_DEATH }) { }

        void OnUnitDeath(Unit* unit, Unit* /*killer*/) override
        {
            Creature* creature = unit ? unit->ToCreature() : nullptr;
            if (!creature)
                return;

            Map* map = creature->GetMap();
            if (!map || !map->IsNonRaidDungeon())
                return;

            std::shared_ptr<Settings const> const settings = GetSettings();
            if (settings->finalBossReviveEnable
                && settings->finalBossReviveExtraBosses.contains(FinalBossKey(map->GetId(), creature->GetEntry())))
                ScheduleRevive(map, creature->GetEntry(), creature->GetName(), "DC.FinalBossRevive.ExtraBosses");
        }
    };

    class dc_final_boss_revive_map : public AllMapScript
    {
    public:
        dc_final_boss_revive_map() : AllMapScript("dc_final_boss_revive_map", { ALLMAPHOOK_ON_MAP_UPDATE }) { }

        void OnMapUpdate(Map* map, uint32 diff) override
        {
            if (!map || !map->IsNonRaidDungeon())
                return;

            ReviveState* state = map->CustomData.Get<ReviveState>(REVIVE_STATE_KEY);
            if (!state)
                return;

            state->timerMs += diff;
            if (state->timerMs < EVALUATE_INTERVAL_MS)
                return;

            state->waitedMs += state->timerMs;
            state->timerMs = 0;

            // After the fight, not into it (nor around the battle resurrection budget of a Mythic+ run).
            if (IsInstanceInCombat(map) && state->waitedMs < MAX_COMBAT_WAIT_MS)
                return;

            uint32 const creditEntry = state->creditEntry;
            uint32 const waitedMs = state->waitedMs;
            map->CustomData.Erase(REVIVE_STATE_KEY);

            std::shared_ptr<Settings const> const settings = GetSettings();
            if (!settings->finalBossReviveEnable)
                return;

            uint32 const revived = ReviveDeadOnMap(map, settings->finalBossReviveRestore);
            QueueReleasedGhosts(map, settings->finalBossReviveRestore);

            // Logged also with 0, so every clear shows the revive ran (released ghosts get a line of their own).
            LOG_INFO("scripts.dc", "Final boss revive: map {} instance {} (final credit {}): {} player(s) resurrected "
                "in place after {} ms{}.", map->GetId(), map->GetInstanceId(), creditEntry, revived, waitedMs,
                waitedMs >= MAX_COMBAT_WAIT_MS ? " (combat wait timed out)" : "");
        }
    };

    class dc_final_boss_revive_world : public WorldScript
    {
    public:
        dc_final_boss_revive_world() : WorldScript("dc_final_boss_revive_world", { WORLDHOOK_ON_UPDATE }) { }

        // World thread, after MapMgr::Update has joined every map worker: players on any
        // map can be teleported from here, as Battlefield::Update does.
        void OnUpdate(uint32 /*diff*/) override
        {
            if (!g_hasGhostRequests.load(std::memory_order_acquire))
                return;

            std::vector<GhostRequest> requests;
            {
                std::lock_guard<std::mutex> guard(g_ghostLock);
                requests.swap(g_ghostRequests);
                g_hasGhostRequests.store(false, std::memory_order_release);
            }

            BringBackGhosts(requests);
        }
    };

    class dc_final_boss_revive_player : public PlayerScript
    {
    public:
        dc_final_boss_revive_player()
            : PlayerScript("dc_final_boss_revive_player", { PLAYERHOOK_ON_PLAYER_RESURRECT }) { }

        // The core's arrival resurrection of a ghost BringBackGhosts sent back.
        void OnPlayerResurrect(Player* player, float restorePercent, bool& /*applySickness*/) override
        {
            RestoreMarker const* marker =
                player ? player->CustomData.Get<RestoreMarker>(RESTORE_MARKER_KEY) : nullptr;
            if (!marker)
                return;

            uint32 const mapId = marker->mapId;
            float const restore = marker->restore;
            bool const fresh = NowMs() <= marker->expiresAtMs;
            player->CustomData.Erase(RESTORE_MARKER_KEY);

            if (!fresh || player->GetMapId() != mapId)
                return;

            // The same fields Player::ResurrectPlayer sets.
            if (restore > restorePercent)
            {
                player->SetHealth(uint32(player->GetMaxHealth() * restore));
                player->SetPower(POWER_MANA, uint32(player->GetMaxPower(POWER_MANA) * restore));
                player->SetPower(POWER_ENERGY, uint32(player->GetMaxPower(POWER_ENERGY) * restore));
            }

            ChatHandler(player->GetSession()).SendSysMessage(REVIVED_TEXT);
        }
    };
}

namespace DC::DungeonQoL
{
    void RegisterFinalBossReviveScripts()
    {
        new dc_final_boss_revive_encounters();
        new dc_final_boss_revive_deaths();
        new dc_final_boss_revive_map();
        new dc_final_boss_revive_world();
        new dc_final_boss_revive_player();
    }
}
