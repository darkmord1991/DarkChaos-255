-- =====================================================================================
-- Emerald Sanctum (map 824) -- DungeonQuest system: RAID EXCEPTION
--
-- Same exception as TimbermawHold/15_dungeonquest_raid_exception.sql; see that file for the
-- full reasoning. Short version: the DungeonQuest system never checks IsRaid()
-- (MapEntry::IsDungeon() is true for raids, DBCStructure.h:1351), so a raid map silently opts
-- in to 5-man behaviour.
--
-- ---------------------------------------------------------------------------
-- 1. QuestInfoID = 62 -- WITHOUT THIS THE RAID QUESTS CANNOT BE COMPLETED
-- ---------------------------------------------------------------------------
-- With `Quests.IgnoreRaid = 0`, a player in a raid group gets no kill credit and cannot see or
-- hand in a quest unless Quest::IsRaidQuest() is true (PlayerQuest.cpp:2010 and :2344).
-- IsRaidQuest() reads `Quest::Type`, which the loader fills from column index 5 =
-- `QuestInfoID` (ObjectMgr.cpp:5105 + QuestDef.cpp:38) -- NOT from `QuestType`, which is the
-- Method field and must stay 2.
--
-- 700804 "This Week's Wakener" is the one that would have been most confusing to debug: it
-- credits on any of the four rotating Wakeners, so it would have looked like a rotation bug
-- rather than a raid-group bug.
-- ---------------------------------------------------------------------------
UPDATE `quest_template` SET `QuestInfoID` = 62 WHERE `ID` BETWEEN 700800 AND 700805;

-- ---------------------------------------------------------------------------
-- 2. No Universal Quest Master follower on a raid map
-- ---------------------------------------------------------------------------
-- Summoned per player, re-links to any 700100 within 50 yd (so a raid landing on one pad all
-- adopt the same creature, DungeonQuestMasterFollower.cpp:153), and despawns on entering
-- combat (:320). The Emerald Sanctum Gatekeeper (3999007) already starts and ends all 6
-- quests, so the follower adds nothing here.
--
-- `dc_dungeon_quest_mapping` rows are deliberately KEPT -- they resolve dungeon_id for stat
-- tracking. Only the follower is opted out.
-- ---------------------------------------------------------------------------
DELETE FROM `dc_dungeon_npc_mapping` WHERE `map_id` = 824;

DELETE FROM `creature` WHERE `id` = 700100 AND `map` = 824;

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
SELECT 'raid quests flagged QUEST_TYPE_RAID (want 6)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `quest_template` WHERE `ID` BETWEEN 700800 AND 700805 AND `QuestInfoID` = 62
UNION ALL SELECT 'raid quests still un-flagged (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `quest_template` WHERE `ID` BETWEEN 700800 AND 700805 AND `QuestInfoID` <> 62
UNION ALL SELECT 'QuestType left alone as 2 (want 6)', CAST(COUNT(*) AS CHAR)
    FROM `quest_template` WHERE `ID` BETWEEN 700800 AND 700805 AND `QuestType` = 2
UNION ALL SELECT 'follower mapping removed (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `dc_dungeon_npc_mapping` WHERE `map_id` = 824
UNION ALL SELECT 'persisted quest-master spawns (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `id` = 700100 AND `map` = 824
UNION ALL SELECT 'quests with no questgiver (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `quest_template` q
    LEFT JOIN `creature_queststarter` s ON s.`quest` = q.`ID`
    WHERE q.`ID` BETWEEN 700800 AND 700805 AND s.`quest` IS NULL
UNION ALL SELECT 'dungeon quest mappings kept (want 6)', CAST(COUNT(*) AS CHAR)
    FROM `dc_dungeon_quest_mapping` WHERE `dungeon_id` = 824
-- Crescent Grove (823) is a genuine 5-man and deliberately gets NO exception file: it keeps
-- the follower and its quests correctly stay at QuestInfoID 0, because a party group is not a
-- raid group and IsRaidQuest() never comes into play.
UNION ALL SELECT 'Crescent Grove keeps its follower (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `dc_dungeon_npc_mapping` WHERE `map_id` = 823;
