-- Blackwing Descent (map 669) — boss-kill quests on a dedicated raid-styled quest NPC.
-- BWD has no native quests; these are authored fresh. The DC dungeon-quest system is intentionally
-- NOT used for this raid (no dc_dungeon_* rows) — the quests hang on a custom Drakonid questgiver
-- via plain creature_queststarter/questender, with direct gold rewards.
-- RequiredNpcOrGo uses the encounter credit entries (Omnotron credit = Toxitron 42180).

-- ---------------------------------------------------------------------------
-- quest_template (6 boss kills, gold rewards)
-- NOTE: QuestType corrected 2 -> 62 (QUEST_TYPE_RAID). Type=2 matches no
-- QuestTypes enum value, so Quest::IsRaidQuest() returned false and the core
-- (Player::PrepareQuestMenu / CanCompleteQuest, PlayerQuest.cpp) hid these
-- quests from anyone in an actual raid group -- i.e. everyone who could earn
-- them. QuestInfoID 62 (log-tab category, a separate field) was already
-- correct; only the gameplay-gating QuestType was wrong.
-- ---------------------------------------------------------------------------
DELETE FROM `quest_template` WHERE `ID` BETWEEN 700701 AND 700706;
INSERT INTO `quest_template`
    (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `Flags`,
     `LogTitle`, `LogDescription`, `QuestDescription`, `QuestCompletionLog`,
     `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`, `RewardMoney`, `RewardNextQuest`)
VALUES
    (700701, 62, -1, 85, 0, 62, 0, 'Blackwing Descent: Magmaw',
        'Slay Magmaw in Blackwing Descent.', 'Enter Blackwing Descent and destroy the great magma worm Magmaw.',
        'Magmaw lies dead. Return to Emissary Blackscale for your reward.', 41570, 1, 500000, 0),
    (700702, 62, -1, 85, 0, 62, 0, 'Blackwing Descent: Omnotron Defense System',
        'Disable the Omnotron Defense System in Blackwing Descent.', 'Destroy Nefarian''s automated Omnotron Defense System.',
        'The Omnotron Defense System is scrap. Return to Emissary Blackscale for your reward.', 42180, 1, 500000, 0),
    (700703, 62, -1, 85, 0, 62, 0, 'Blackwing Descent: Maloriak',
        'Slay Maloriak in Blackwing Descent.', 'Put an end to the mad alchemist Maloriak and his twisted experiments.',
        'Maloriak is dead. Return to Emissary Blackscale for your reward.', 41378, 1, 500000, 0),
    (700704, 62, -1, 85, 0, 62, 0, 'Blackwing Descent: Atramedes',
        'Slay Atramedes in Blackwing Descent.', 'Silence the blind dragon Atramedes.',
        'Atramedes hears nothing now. Return to Emissary Blackscale for your reward.', 41442, 1, 500000, 0),
    (700705, 62, -1, 85, 0, 62, 0, 'Blackwing Descent: Chimaeron',
        'Slay Chimaeron in Blackwing Descent.', 'Destroy Nefarian''s abomination, Chimaeron.',
        'Chimaeron is slain. Return to Emissary Blackscale for your reward.', 43296, 1, 500000, 700709),
    (700706, 62, -1, 85, 0, 62, 0, 'Blackwing Descent: Nefarian''s End',
        'Defeat Nefarian and Onyxia in Blackwing Descent.', 'Confront Lord Victor Nefarius and end the threat of Nefarian and his resurrected sister Onyxia.',
        'Nefarian has fallen at last. Return to Emissary Blackscale for your reward.', 41376, 1, 1000000, 700710);

-- ---------------------------------------------------------------------------
-- quest_template (4 new quests: entrance trial, entrance trash, Finkle
-- follow-up, capstone) -- fleshes out the raid with lore already present in
-- the port (dwarven spirit guardians, renegade drakonid/golem trash guarding
-- the path to Magmaw, Finkle Einhorn's post-Chimaeron gossip, Nefarian's death).
-- ---------------------------------------------------------------------------
DELETE FROM `quest_template` WHERE `ID` BETWEEN 700707 AND 700710;
INSERT INTO `quest_template`
    (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `Flags`,
     `LogTitle`, `LogDescription`, `QuestDescription`, `QuestCompletionLog`,
     `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGo2`, `RequiredNpcOrGoCount2`,
     `RequiredNpcOrGo3`, `RequiredNpcOrGoCount3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount4`,
     `RewardMoney`, `RewardItem1`, `RewardAmount1`)
VALUES
    -- Entrance trial: the bound Dark Iron spirits woken by the Ancient Bell (43119/22/25/26/27/28/29/30).
    (700707, 62, -1, 85, 0, 62, 0, 'Blackwing Descent: The Restless Dead',
        'Silence the spirits guarding the Ancient Bell in Blackwing Descent.',
        'The ringing of the Ancient Bell has roused the bound spirits of the old Dark Iron dwarf lords -- Moltenfist, Anvilrage, Ironstar, and Thaurissan. Nefarian has turned their eternal watch to his own purpose. Put them back to their rest before you press deeper into the mountain.',
        'The old lords sleep once more. Return to Emissary Blackscale for your reward.',
        43125, 1, 43128, 1, 43127, 1, 43126, 1, 250000, 0, 0),
    -- Renegade drakonid + repurposed dwarven constructs blocking the passage to Magmaw.
    (700708, 62, -1, 85, 0, 62, 0, 'Blackwing Descent: Kin of the Black Flight',
        'Clear the drakonid and constructs guarding the way to Magmaw.',
        'Not every drakonid bends the knee to Nefarian willingly, but the ones holding this passage have made their choice. Cut them down, along with the old dwarven constructs his engineers pressed back into service, and clear the way to Magmaw''s chamber.',
        'The passage is clear. Return to Emissary Blackscale for your reward.',
        42362, 2, 42649, 1, 42800, 2, 0, 0, 250000, 0, 0),
    -- Talk-to (negative id) follow-up, gated behind the Chimaeron kill via quest_template_addon below.
    (700709, 62, -1, 85, 0, 62, 0, 'Blackwing Descent: A Favor for Finkle',
        'Check on Finkle Einhorn now that Chimaeron is dead.',
        'With Chimaeron gone, the little gnome trapped in the cage nearby is finally safe to approach. Poor Finkle has been through enough -- go see how he''s holding up.',
        'Finkle is rattled, but grateful to be rid of his monstrous neighbor. Return to Emissary Blackscale.',
        -44202, 1, 0, 0, 0, 0, 0, 0, 200000, 0, 0),
    -- Capstone: no objective, gated behind Nefarian's End via quest_template_addon below.
    (700710, 62, -1, 85, 0, 62, 0, 'Blackwing Descent: A Fitting End',
        'Report your final victory to Emissary Blackscale.',
        'Nefarian is dead. Onyxia''s bones lie shattered a second time. Blackwing Descent belongs to the living once more. Return to Emissary Blackscale -- she has one last reward for the heroes who ended House Nefarius.',
        'Emissary Blackscale is waiting to honor your victory.',
        0, 0, 0, 0, 0, 0, 0, 0, 750000, 71716, 1);

-- ---------------------------------------------------------------------------
-- quest_template_addon (prerequisite gating for the two follow-up quests)
-- ---------------------------------------------------------------------------
DELETE FROM `quest_template_addon` WHERE `ID` IN (700709, 700710);
INSERT INTO `quest_template_addon` (`ID`, `PrevQuestID`) VALUES
    (700709, 700705),
    (700710, 700706);

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
    (700110, 700704), (700110, 700705), (700110, 700706),
    (700110, 700707), (700110, 700708), (700110, 700709), (700110, 700710);

DELETE FROM `creature_questender` WHERE `id` = 700110;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
    (700110, 700701), (700110, 700702), (700110, 700703),
    (700110, 700704), (700110, 700705), (700110, 700706),
    (700110, 700707), (700110, 700708), (700110, 700709), (700110, 700710);

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
