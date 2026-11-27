/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * Dungeon / raid quality-of-life systems:
 *   - battle resurrection charges (dc_battle_resurrection.cpp)
 *   - checkpoint revive on spirit release (dc_checkpoint_release.cpp)
 *   - everyone revives when a dungeon's final boss dies (dc_final_boss_revive.cpp)
 *
 * Everything that changes difficulty is limited to DC content: active Mythic+
 * runs and the instance maps named in the DC.BattleRes.* / DC.CheckpointRelease.*
 * config keys. Stock 1-80 content is untouched unless a map is listed there.
 * The final boss revive is the exception: it applies to every 5-player dungeon
 * (DC.FinalBossRevive.Enable), and only after the dungeon's last fight is over.
 *
 * Per-instance state lives in Map::CustomData and is only touched from that
 * map's update thread. The config snapshot is the only shared container.
 */

#ifndef DC_DUNGEON_QOL_H
#define DC_DUNGEON_QOL_H

#include "Define.h"
#include <memory>
#include <unordered_set>

class Map;
struct Position;

namespace DC::DungeonQoL
{
    struct Settings
    {
        bool battleResEnable = true;
        // 0 = Mythic+ runs never gain a charge beyond the first one.
        uint32 battleResRechargeMinutes = 10;
        std::unordered_set<uint32> battleResRaidMaps;

        std::unordered_set<uint32> checkpointMaps;
        bool checkpointMythicPlus = true;

        bool finalBossReviveEnable = true;
        // Share of health and mana the revive gives back, 0.01 - 1.0.
        float finalBossReviveRestore = 1.0f;
        // Final bosses of dungeons without DungeonEncounter data, as FinalBossKey(map, creature entry).
        std::unordered_set<uint64> finalBossReviveExtraBosses;
    };

    inline uint64 FinalBossKey(uint32 mapId, uint32 creatureEntry)
    {
        return (uint64(mapId) << 32) | creatureEntry;
    }

    // Immutable snapshot, swapped whole on config (re)load. Safe from any thread.
    std::shared_ptr<Settings const> GetSettings();
    void LoadSettings();

    // True while any boss encounter of the instance is IN_PROGRESS.
    bool IsEncounterInProgress(Map* map);
    // True while a living, non-GM player on the map is in combat.
    bool IsAnyPlayerInCombat(Map* map);
    // Either of the two above.
    bool IsInstanceInCombat(Map* map);

    // Mythic+ integration point (map thread only). Fills `out` with the position
    // of the most recently killed boss of the current run and returns true when
    // DC.CheckpointRelease.MythicPlus is on, a boss of this run has died and
    // nobody in the instance is in combat. Otherwise returns false and the
    // caller keeps its own destination (the dungeon entrance).
    bool GetMythicPlusReleaseCheckpoint(Map* map, Position& out);

    // Battle resurrection charges of the instance (map thread only). Returns
    // false when no limit applies there (not an active Mythic+ run, not a
    // listed raid, or the system is disabled).
    bool GetBattleResCharges(Map* map, uint32& remaining, uint32& total);

    // Script registration, called from AddSC_dc_dungeon_qol() only.
    void RegisterBattleResurrectionScripts();
    void RegisterCheckpointReleaseScripts();
    void RegisterFinalBossReviveScripts();
}

#endif // DC_DUNGEON_QOL_H
