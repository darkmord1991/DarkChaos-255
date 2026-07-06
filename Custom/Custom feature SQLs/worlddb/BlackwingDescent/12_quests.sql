-- Blackwing Descent (map 669) — boss-kill quests on a dedicated raid-styled quest NPC.
-- BWD has no native quests; these are authored fresh. The DC dungeon-quest system is intentionally
-- NOT used for this raid (no dc_dungeon_* rows) — the quests hang on a custom Drakonid questgiver
-- via plain creature_queststarter/questender, with direct gold rewards.
-- RequiredNpcOrGo uses the encounter credit entries (Omnotron credit = Toxitron 42180).

-- ---------------------------------------------------------------------------
-- quest_template (6 boss kills, gold rewards)
-- ---------------------------------------------------------------------------
DELETE FROM `quest_template` WHERE `ID` BETWEEN 700701 AND 700706;
INSERT INTO `quest_template`
    (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `Flags`,
     `LogTitle`, `LogDescription`, `QuestDescription`, `QuestCompletionLog`,
     `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`, `RewardMoney`)
VALUES
    (700701, 2, -1, 85, 0, 62, 0, 'Blackwing Descent: Magmaw',
        'Slay Magmaw in Blackwing Descent.', 'Enter Blackwing Descent and destroy the great magma worm Magmaw.',
        'Magmaw lies dead. Return to Emissary Blackscale for your reward.', 41570, 1, 500000),
    (700702, 2, -1, 85, 0, 62, 0, 'Blackwing Descent: Omnotron Defense System',
        'Disable the Omnotron Defense System in Blackwing Descent.', 'Destroy Nefarian''s automated Omnotron Defense System.',
        'The Omnotron Defense System is scrap. Return to Emissary Blackscale for your reward.', 42180, 1, 500000),
    (700703, 2, -1, 85, 0, 62, 0, 'Blackwing Descent: Maloriak',
        'Slay Maloriak in Blackwing Descent.', 'Put an end to the mad alchemist Maloriak and his twisted experiments.',
        'Maloriak is dead. Return to Emissary Blackscale for your reward.', 41378, 1, 500000),
    (700704, 2, -1, 85, 0, 62, 0, 'Blackwing Descent: Atramedes',
        'Slay Atramedes in Blackwing Descent.', 'Silence the blind dragon Atramedes.',
        'Atramedes hears nothing now. Return to Emissary Blackscale for your reward.', 41442, 1, 500000),
    (700705, 2, -1, 85, 0, 62, 0, 'Blackwing Descent: Chimaeron',
        'Slay Chimaeron in Blackwing Descent.', 'Destroy Nefarian''s abomination, Chimaeron.',
        'Chimaeron is slain. Return to Emissary Blackscale for your reward.', 43296, 1, 500000),
    (700706, 2, -1, 85, 0, 62, 0, 'Blackwing Descent: Nefarian''s End',
        'Defeat Nefarian and Onyxia in Blackwing Descent.', 'Confront Lord Victor Nefarius and end the threat of Nefarian and his resurrected sister Onyxia.',
        'Nefarian has fallen at last. Return to Emissary Blackscale for your reward.', 41376, 1, 1000000);

-- ---------------------------------------------------------------------------
-- Custom questgiver: Emissary Blackscale (Black Drakonid, stock display 14885)
-- ---------------------------------------------------------------------------
DELETE FROM `dc_dungeon_quest_mapping` WHERE `quest_id` BETWEEN 700701 AND 700706;
DELETE FROM `dc_quest_difficulty_mapping` WHERE `quest_id` BETWEEN 700701 AND 700706;
DELETE FROM `dc_dungeon_npc_mapping` WHERE `map_id` = 669;

DELETE FROM `creature_template` WHERE `entry` = 700110;
INSERT INTO `creature_template`
    (`entry`, `name`, `subname`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`,
     `unit_class`, `unit_flags`, `type`, `type_flags`, `rank`, `RegenHealth`, `flags_extra`, `AIName`, `ScriptName`)
VALUES
    (700110, 'Emissary Blackscale', 'Blackwing Descent', 83, 83, 2, 35, 2, 1, 1.14286,
     1, 768, 9, 0, 1, 1, 2, '', '');

DELETE FROM `creature_template_model` WHERE `CreatureID` = 700110;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
    (700110, 0, 14885, 1.15, 1, 0);

DELETE FROM `creature_queststarter` WHERE `id` = 700110;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
    (700110, 700701), (700110, 700702), (700110, 700703),
    (700110, 700704), (700110, 700705), (700110, 700706);

DELETE FROM `creature_questender` WHERE `id` = 700110;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
    (700110, 700701), (700110, 700702), (700110, 700703),
    (700110, 700704), (700110, 700705), (700110, 700706);

DELETE FROM `creature` WHERE `guid` = 9556001;
INSERT INTO `creature` (`guid`, `id`, `map`, `spawnMask`, `phaseMask`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `MovementType`, `Comment`)
VALUES (9556001, 700110, 669, 15, 1, -350.0, -224.3, 193.13, 0, 300, 0, 'BWD Emissary Blackscale (questgiver)');

-- ---------------------------------------------------------------------------
-- DC teleporter: Custom Dungeons -> Blackwing Descent; Custom Locations -> DC Plaguelands
-- (Hyjal 410/411/412 and Deepholm 505 already exist.)
-- ---------------------------------------------------------------------------
DELETE FROM `dc_teleporter` WHERE `id` IN (801, 508);
INSERT INTO `dc_teleporter` (`id`, `parent`, `type`, `faction`, `security_level`, `icon`, `name`, `map`, `x`, `y`, `z`, `o`) VALUES
    (801, 800, 2, -1, 0, 2, 'Blackwing Descent', 669, -345.872, -224.344, 193.127, 0),
    (508, 500, 2, -1, 0, 2, 'DC Plaguelands', 751, 2245.789, -5235.96, 75.365, 0);

-- The dungeon-quest system had already persisted a spawn of the Universal Quest Master (700100)
-- on map 669 before it was disabled here — remove any such stray spawn rows.
DELETE FROM `creature` WHERE `id` = 700100 AND `map` = 669;
