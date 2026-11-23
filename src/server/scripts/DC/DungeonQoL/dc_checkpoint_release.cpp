/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * Checkpoint revive: releasing spirit inside an instance listed in
 * DC.CheckpointRelease.Maps resurrects the player at 50% health and mana at the
 * position of the most recently killed boss of that instance (the entrance if
 * no boss has died yet), instead of sending a ghost on a corpse run.
 *
 * Only out of combat. While a boss encounter is in progress or a living group
 * member is in combat the stock release runs unchanged (ghost at the spirit
 * healer): reviving a released player next to an ongoing fight, or holding the
 * ghost at its corpse until combat ends, would both let the group bypass the
 * battle resurrection budget. The player is told to release after the fight.
 *
 * Active Mythic+ runs keep their own release handling
 * (MythicPlusRunManager::RespawnPlayerAtEntrance). This file records boss
 * checkpoints for runs too, and the run manager asks
 * DC::DungeonQoL::GetMythicPlusReleaseCheckpoint() for the destination, falling
 * back to the entrance while anyone is fighting.
 */

#include "dc_dungeon_qol.h"
#include "Chat.h"
#include "Creature.h"
#include "DC/MythicPlus/dc_mythicplus_run_manager.h"
#include "DataMap.h"
#include "GameTime.h"
#include "InstanceScript.h"
#include "Log.h"
#include "Map.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptMgr.h"

#include <string>

namespace
{
    using namespace DC::DungeonQoL;

    constexpr float RELEASE_RESTORE_PCT = 0.5f;
    constexpr float CHECKPOINT_GROUND_SEARCH = 50.0f;

    std::string const CHECKPOINT_STATE_KEY = "dc_checkpoint";
    std::string const PENDING_RELEASE_KEY = "dc_ckpt_release";

    struct CheckpointState : DataMap::Base
    {
        bool hasCheckpoint = false;
        Position position;
        uint32 bossEntry = 0;
        uint64 killedAt = 0;      // game time, seconds
        uint64 pendingDoneMs = 0; // game time (ms) a boss encounter was last set DONE
    };

    // Set by OnPlayerReleasedGhost, consumed by OnPlayerCanRepopAtGraveyard of the
    // same release. RepopAtGraveyard also runs for other reasons (falling under
    // the map), which must keep the stock behaviour.
    struct PendingRelease : DataMap::Base
    {
        uint64 releasedAtMs = 0;
    };

    uint64 NowMs()
    {
        return static_cast<uint64>(GameTime::GetGameTimeMS().count());
    }

    bool IsListedMap(Settings const& settings, Map const* map)
    {
        return map && map->IsDungeon() && settings.checkpointMaps.contains(map->GetId());
    }

    // Nearest teleport into this map whose source trigger lies outside it: the way in.
    bool FindEntrance(Map const* map, Player const* player, Position& out)
    {
        uint32 const mapId = map->GetId();
        float nearest = -1.0f;
        for (auto const& [triggerId, teleport] : sObjectMgr->GetAllAreaTriggerTeleports())
        {
            if (teleport.target_mapId != mapId)
                continue;

            AreaTrigger const* trigger = sObjectMgr->GetAreaTrigger(triggerId);
            if (trigger && trigger->map == mapId)
                continue;

            float const distance = player->GetExactDistSq(teleport.target_X, teleport.target_Y, teleport.target_Z);
            if (nearest < 0.0f || distance < nearest)
            {
                nearest = distance;
                out.Relocate(teleport.target_X, teleport.target_Y, teleport.target_Z, teleport.target_Orientation);
            }
        }

        return nearest >= 0.0f;
    }

    void RecordCheckpoint(Map* map, CheckpointState& state, Creature const* boss)
    {
        float const x = boss->GetPositionX();
        float const y = boss->GetPositionY();
        float z = boss->GetPositionZ();

        // A boss can die on a ledge or in the air: stand the player on the floor below.
        float const ground = map->GetHeight(boss->GetPhaseMask(), x, y, z, true, CHECKPOINT_GROUND_SEARCH);
        if (ground > INVALID_HEIGHT)
            z = ground;

        state.hasCheckpoint = true;
        state.position.Relocate(x, y, z, boss->GetOrientation());
        state.bossEntry = boss->GetEntry();
        state.killedAt = static_cast<uint64>(GameTime::GetGameTime().count());
        state.pendingDoneMs = 0;

        LOG_INFO("scripts.dc", "Checkpoint: {} (entry {}) died on map {} instance {}; released players revive at "
            "({:.1f}, {:.1f}, {:.1f}).",
            boss->GetName(), boss->GetEntry(), map->GetId(), map->GetInstanceId(), x, y, z);
    }

    // Marks "an encounter just completed", so the creature that dies in the same
    // tick counts as its boss even without a boss flag (BossAI::_JustDied sets
    // DONE before Unit::Kill reaches OnUnitDeath).
    class dc_checkpoint_release_encounters : public GlobalScript
    {
    public:
        dc_checkpoint_release_encounters()
            : GlobalScript("dc_checkpoint_release_encounters", { GLOBALHOOK_ON_BEFORE_SET_BOSS_STATE }) { }

        void OnBeforeSetBossState(uint32 /*id*/, EncounterState newState, EncounterState oldState,
            Map* instance) override
        {
            if (!instance || !instance->IsDungeon())
                return;

            if (newState != DONE || oldState == DONE || oldState == TO_BE_DECIDED)
                return;

            std::shared_ptr<Settings const> const settings = GetSettings();
            if (!settings->checkpointMythicPlus && !IsListedMap(*settings, instance))
                return;

            instance->CustomData.GetDefault<CheckpointState>(CHECKPOINT_STATE_KEY)->pendingDoneMs = NowMs();
        }
    };

    class dc_checkpoint_release_deaths : public UnitScript
    {
    public:
        dc_checkpoint_release_deaths()
            : UnitScript("dc_checkpoint_release_deaths", true, { UNITHOOK_ON_UNIT_DEATH }) { }

        void OnUnitDeath(Unit* unit, Unit* /*killer*/) override
        {
            Creature* creature = unit ? unit->ToCreature() : nullptr;
            if (!creature)
                return;

            Map* map = creature->GetMap();
            if (!map || !map->IsDungeon())
                return;

            std::shared_ptr<Settings const> const settings = GetSettings();
            bool const listed = IsListedMap(*settings, map);
            if (!listed && !settings->checkpointMythicPlus)
                return;

            CheckpointState* state = map->CustomData.Get<CheckpointState>(CHECKPOINT_STATE_KEY);
            bool const encounterJustDone = state && state->pendingDoneMs == NowMs();
            bool isBoss = encounterJustDone || creature->IsDungeonBoss() || creature->isWorldBoss();
            if (!isBoss && !listed)
                isBoss = sMythicRuns->IsBossCreature(creature);

            if (!isBoss)
                return;

            // Unlisted maps only get checkpoints while a Mythic+ run is active.
            if (!listed && !sMythicRuns->IsMythicPlusActive(map))
                return;

            if (!state)
                state = map->CustomData.GetDefault<CheckpointState>(CHECKPOINT_STATE_KEY);

            RecordCheckpoint(map, *state, creature);
        }
    };

    class dc_checkpoint_release_player : public PlayerScript
    {
    public:
        dc_checkpoint_release_player() : PlayerScript("dc_checkpoint_release_player",
            { PLAYERHOOK_ON_PLAYER_RELEASED_GHOST, PLAYERHOOK_CAN_REPOP_AT_GRAVEYARD }) { }

        void OnPlayerReleasedGhost(Player* player) override
        {
            if (!player || !IsListedMap(*GetSettings(), player->GetMap()))
                return;

            player->CustomData.GetDefault<PendingRelease>(PENDING_RELEASE_KEY)->releasedAtMs = NowMs();
        }

        bool OnPlayerCanRepopAtGraveyard(Player* player) override
        {
            if (!player)
                return true;

            PendingRelease* pending = player->CustomData.Get<PendingRelease>(PENDING_RELEASE_KEY);
            if (!pending)
                return true;

            uint64 const releasedAtMs = pending->releasedAtMs;
            player->CustomData.Erase(PENDING_RELEASE_KEY);

            // BuildPlayerRepop and RepopAtGraveyard always run back to back; an older
            // marker belongs to a release whose repop another hook already handled.
            if (releasedAtMs != NowMs() || player->IsAlive() || !player->m_InstanceValid)
                return true;

            Map* map = player->GetMap();
            if (!IsListedMap(*GetSettings(), map))
                return true;

            // A running keystone owns the release (entrance teleport in the M+ scripts).
            if (sMythicRuns->IsMythicPlusActive(map))
                return true;

            if (IsInstanceInCombat(map))
            {
                ChatHandler(player->GetSession()).SendSysMessage(
                    "|cffff8000[Checkpoint]|r Your group is still in combat, so there is no checkpoint revive. "
                    "Release after the fight to revive at the last defeated boss.");
                return true;
            }

            Position destination;
            bool atCheckpoint = false;
            if (CheckpointState const* state = map->CustomData.Get<CheckpointState>(CHECKPOINT_STATE_KEY);
                state && state->hasCheckpoint)
            {
                destination.Relocate(state->position);
                atCheckpoint = true;
            }
            else if (!FindEntrance(map, player, destination))
                return true;

            player->ResurrectPlayer(RELEASE_RESTORE_PCT);
            if (!player->IsAlive())
                return true;

            player->SpawnCorpseBones();
            player->TeleportTo(map->GetId(), destination.GetPositionX(), destination.GetPositionY(),
                destination.GetPositionZ(), destination.GetOrientation());

            ChatHandler(player->GetSession()).SendSysMessage(atCheckpoint
                ? "|cff00ff00[Checkpoint]|r You have been resurrected at the last defeated boss."
                : "|cff00ff00[Checkpoint]|r You have been resurrected at the instance entrance.");

            LOG_INFO("scripts.dc", "Checkpoint: {} released on map {} instance {} and revived at the {}.",
                player->GetName(), map->GetId(), map->GetInstanceId(), atCheckpoint ? "last boss" : "entrance");
            return false;
        }
    };
}

namespace DC::DungeonQoL
{
    bool GetMythicPlusReleaseCheckpoint(Map* map, Position& out)
    {
        if (!map || !map->IsDungeon() || !GetSettings()->checkpointMythicPlus)
            return false;

        // Read on the map thread inside the caller's call, never kept.
        MythicPlusRunManager::InstanceState const* run = sMythicRuns->GetRunState(map);
        if (!run || !run->keystoneLevel || run->completed || run->failed || !run->startedAt)
            return false;

        uint64 const startedAt = run->startedAt;
        CheckpointState const* state = map->CustomData.Get<CheckpointState>(CHECKPOINT_STATE_KEY);
        // A checkpoint older than this run's start belongs to an earlier keystone in the same instance.
        if (!state || !state->hasCheckpoint || state->killedAt < startedAt)
            return false;

        if (IsInstanceInCombat(map))
            return false;

        out.Relocate(state->position);
        return true;
    }

    void RegisterCheckpointReleaseScripts()
    {
        new dc_checkpoint_release_encounters();
        new dc_checkpoint_release_deaths();
        new dc_checkpoint_release_player();
    }
}
