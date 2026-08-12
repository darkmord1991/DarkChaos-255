-- =====================================================================================
-- Timbermaw Hold (map 819) -- DungeonQuest system: RAID EXCEPTION
--
-- The DungeonQuest system was built for 5-man dungeons and has never carried a custom raid.
-- It does not check IsRaid() anywhere -- MapEntry::IsDungeon() is true for raids too
-- (DBCStructure.h:1351: `map_type == MAP_INSTANCE || map_type == MAP_RAID`), so a raid map
-- silently opts IN to everything. Two of those behaviours are wrong for a 20-man, and one of
-- them stops the quests working at all.
--
-- ---------------------------------------------------------------------------
-- 1. QuestInfoID = 62 -- WITHOUT THIS THE RAID QUESTS CANNOT BE COMPLETED
-- ---------------------------------------------------------------------------
-- `Quests.IgnoreRaid = 0` in worldserver.conf (and false by default,
-- WorldConfig.cpp:386). With it off, a player in a RAID GROUP gets no kill credit and the
-- quest is hidden from the log and from turn-in unless Quest::IsRaidQuest() is true:
--     PlayerQuest.cpp:2010  KilledMonsterCredit -- `!GetGroup()->isRaidGroup() || IsAllowedInRaid(...)`
--     PlayerQuest.cpp:2344  PrepareQuestMenu    -- "hide quest if player is in raid-group and quest is no raid quest"
-- These are 20-man raid quests with boss-kill objectives, so every single player who could
-- earn them is in a raid group. They were 100% dead.
--
-- IsRaidQuest() reads `Quest::Type`, and THE COLUMN THAT FEEDS IT IS `QuestInfoID`, NOT
-- `QuestType`. Verified in the loader rather than assumed:
--     ObjectMgr.cpp:5105  SELECT ID, QuestType, QuestLevel, MinLevel, QuestSortID, QuestInfoID, ...
--                         index:  0     1          2          3          4            5
--     QuestDef.cpp:34     Method = questRecord[1]   <- `QuestType`,  values 0/1/2 only
--     QuestDef.cpp:38     Type   = questRecord[5]   <- `QuestInfoID`, the QuestTypes enum
--     SharedDefines.h:3014  QUEST_TYPE_RAID = 62
--
-- So `QuestType` = 2 is CORRECT and must stay (it is the quest Method; 9,575 live quests use
-- it, and 62 there would be meaningless -- Method only accepts 0, 1 or 2). Do not "fix" that
-- column. Blackwing Descent's live rows are the working reference: QuestType 2, QuestInfoID 62.
-- ---------------------------------------------------------------------------
UPDATE `quest_template` SET `QuestInfoID` = 62 WHERE `ID` BETWEEN 700760 AND 700768;

-- ---------------------------------------------------------------------------
-- 2. No Universal Quest Master follower on a raid map
-- ---------------------------------------------------------------------------
-- The dc_dungeon_npc_mapping row is the ENTIRE gate for the follower
-- (DungeonQuestMasterFollower.cpp:62-76 -- GetQuestMasterEntryForMap returns 0 on a miss).
-- Three reasons it is wrong for 20 players, all read out of the source:
--
--   a) It is summoned PER PLAYER on OnPlayerMapChanged, but the "already nearby" re-link at
--      DungeonQuestMasterFollower.cpp:153 does `player->FindNearestCreature(entry, 50.0f)` and
--      adopts ANY nearby 700100 -- including one another player already owns. A raid all lands
--      on the same arrival pad, so players 2..20 adopt player 1's follower. The first
--      OnPlayerEnterCombat (:320) then despawns that one shared creature and leaves every
--      other player's map entry pointing at a dead GUID.
--   b) The follower despawns on entering combat (:320-332). In a raid, trash is continuous, so
--      it is unusable past the entrance anyway.
--   c) It fires a synchronous WorldDatabase.Query per arrival on the map-update thread; 20
--      simultaneous arrivals serialise 20 blocking queries.
--
-- Nothing is lost: the Timbermaw Gatekeeper (3999002) already starts AND ends all 9 quests,
-- which is the same pattern Blackwing Descent uses with Emissary Blackscale (700110) after it
-- opted out the same way (BlackwingDescent/12_quests.sql:91-93).
--
-- NOTE the split: `dc_dungeon_quest_mapping` rows are KEPT. They are read by
-- UniversalQuestMasterCache and by the stat tracker to resolve dungeon_id, and a dungeon_id of
-- 0 would break TrackDifficultyCompletion. Only the follower is opted out.
-- ---------------------------------------------------------------------------
DELETE FROM `dc_dungeon_npc_mapping` WHERE `map_id` = 819;

-- A follower that was persisted to the creature table by an earlier visit would keep spawning
-- regardless of the mapping. BWD needed this exact cleanup (12_quests.sql:134).
DELETE FROM `creature` WHERE `id` = 700100 AND `map` = 819;

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
SELECT 'raid quests flagged QUEST_TYPE_RAID (want 9)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `quest_template` WHERE `ID` BETWEEN 700760 AND 700768 AND `QuestInfoID` = 62
UNION ALL SELECT 'raid quests still un-flagged (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `quest_template` WHERE `ID` BETWEEN 700760 AND 700768 AND `QuestInfoID` <> 62
UNION ALL SELECT 'QuestType left alone as 2 (want 9)', CAST(COUNT(*) AS CHAR)
    FROM `quest_template` WHERE `ID` BETWEEN 700760 AND 700768 AND `QuestType` = 2
UNION ALL SELECT 'follower mapping removed (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `dc_dungeon_npc_mapping` WHERE `map_id` = 819
UNION ALL SELECT 'persisted quest-master spawns (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `id` = 700100 AND `map` = 819
UNION ALL SELECT 'quests with no questgiver (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `quest_template` q
    LEFT JOIN `creature_queststarter` s ON s.`quest` = q.`ID`
    WHERE q.`ID` BETWEEN 700760 AND 700768 AND s.`quest` IS NULL
UNION ALL SELECT 'dungeon quest mappings kept (want 9)', CAST(COUNT(*) AS CHAR)
    FROM `dc_dungeon_quest_mapping` WHERE `dungeon_id` = 819;
