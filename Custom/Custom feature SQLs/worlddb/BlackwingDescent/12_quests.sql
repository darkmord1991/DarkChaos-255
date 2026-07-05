-- Blackwing Descent (map 669) — boss-kill quests on the Universal Quest Master (NPC 700100)
-- BWD has no native quests; these are authored fresh in the dungeon-quest id band (700701-708999,
-- DungeonQuestConstants.h) and surfaced by the existing DB-driven Universal Quest Master (no new C++).
-- Rewards (tokens/gold, per-difficulty scaling) are handled by DungeonQuestSystem.cpp — no quest items.
-- RequiredNpcOrGo uses the encounter credit entries (Omnotron credit = Toxitron 42180).

-- ---------------------------------------------------------------------------
-- quest_template (6 boss kills)
-- ---------------------------------------------------------------------------
DELETE FROM `quest_template` WHERE `ID` BETWEEN 700701 AND 700706;
INSERT INTO `quest_template`
    (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `Flags`,
     `LogTitle`, `LogDescription`, `QuestDescription`, `QuestCompletionLog`,
     `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`, `RewardMoney`)
VALUES
    (700701, 2, -1, 85, 0, 1, 0, 'Blackwing Descent: Magmaw',
        'Slay Magmaw in Blackwing Descent.', 'Enter Blackwing Descent and destroy the great magma worm Magmaw.',
        'Magmaw lies dead. Return to the Quartermaster for your reward.', 41570, 1, 0),
    (700702, 2, -1, 85, 0, 1, 0, 'Blackwing Descent: Omnotron Defense System',
        'Disable the Omnotron Defense System in Blackwing Descent.', 'Destroy Nefarian''s automated Omnotron Defense System.',
        'The Omnotron Defense System is scrap. Return for your reward.', 42180, 1, 0),
    (700703, 2, -1, 85, 0, 1, 0, 'Blackwing Descent: Maloriak',
        'Slay Maloriak in Blackwing Descent.', 'Put an end to the mad alchemist Maloriak and his twisted experiments.',
        'Maloriak is dead. Return for your reward.', 41378, 1, 0),
    (700704, 2, -1, 85, 0, 1, 0, 'Blackwing Descent: Atramedes',
        'Slay Atramedes in Blackwing Descent.', 'Silence the blind dragon Atramedes.',
        'Atramedes hears nothing now. Return for your reward.', 41442, 1, 0),
    (700705, 2, -1, 85, 0, 1, 0, 'Blackwing Descent: Chimaeron',
        'Slay Chimaeron in Blackwing Descent.', 'Destroy Nefarian''s abomination, Chimaeron.',
        'Chimaeron is slain. Return for your reward.', 43296, 1, 0),
    (700706, 2, -1, 85, 0, 1, 0, 'Blackwing Descent: Nefarian''s End',
        'Defeat Nefarian and Onyxia in Blackwing Descent.', 'Confront Lord Victor Nefarius and end the threat of Nefarian and his resurrected sister Onyxia.',
        'Nefarian has fallen at last. Return for your reward.', 41376, 1, 0);

-- ---------------------------------------------------------------------------
-- dc_dungeon_quest_mapping (attach the quests to dungeon 669)
-- ---------------------------------------------------------------------------
DELETE FROM `dc_dungeon_quest_mapping` WHERE `quest_id` BETWEEN 700701 AND 700706;
INSERT INTO `dc_dungeon_quest_mapping` (`quest_id`, `dungeon_id`, `enabled`) VALUES
    (700701, 669, 1), (700702, 669, 1), (700703, 669, 1),
    (700704, 669, 1), (700705, 669, 1), (700706, 669, 1);

-- ---------------------------------------------------------------------------
-- dc_quest_difficulty_mapping (per-difficulty reward scaling)
-- ---------------------------------------------------------------------------
DELETE FROM `dc_quest_difficulty_mapping` WHERE `quest_id` BETWEEN 700701 AND 700706;
INSERT INTO `dc_quest_difficulty_mapping` (`quest_id`, `base_difficulty`, `scaling_enabled`, `min_level`, `max_level`, `reward_multiplier`, `token_bonus`, `essence_bonus`, `notes`) VALUES
    (700701, 0, 1, 85, 0, 1, 0, 0, 'BWD Magmaw'),
    (700702, 0, 1, 85, 0, 1, 0, 0, 'BWD Omnotron'),
    (700703, 0, 1, 85, 0, 1, 0, 0, 'BWD Maloriak'),
    (700704, 0, 1, 85, 0, 1, 0, 0, 'BWD Atramedes'),
    (700705, 0, 1, 85, 0, 1, 0, 0, 'BWD Chimaeron'),
    (700706, 0, 1, 85, 0, 1, 0, 0, 'BWD Nefarian');

-- ---------------------------------------------------------------------------
-- dc_dungeon_npc_mapping + Universal Quest Master (700100) spawn at the entrance
-- ---------------------------------------------------------------------------
DELETE FROM `dc_dungeon_npc_mapping` WHERE `map_id` = 669;
INSERT INTO `dc_dungeon_npc_mapping` (`map_id`, `quest_master_entry`, `dungeon_name`, `expansion`, `min_level`, `max_level`, `enabled`, `display_id`) VALUES
    (669, 700100, 'Blackwing Descent', 2, 85, 85, 1, 1825);

DELETE FROM `creature` WHERE `guid` = 9556001;
INSERT INTO `creature` (`guid`, `id`, `map`, `spawnMask`, `phaseMask`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `MovementType`, `Comment`)
VALUES (9556001, 700100, 669, 15, 1, -350.0, -224.3, 193.13, 0, 300, 0, 'BWD Quest Master');
