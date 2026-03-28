-- Hinterlands Battleground Battlemaster NPC

-- Creature template (AzerothCore schema - models in separate table)
DELETE FROM `creature_template` WHERE `entry` = 900001;
INSERT INTO `creature_template` (
    `entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, 
    `KillCredit1`, `KillCredit2`, 
    `name`, `subname`, `IconName`, 
    `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, 
    `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, 
    `rank`, `dmgschool`, `DamageModifier`, 
    `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, 
    `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, 
    `family`, `trainer_type`, `trainer_spell`, `trainer_class`, `trainer_race`, 
    `type`, `type_flags`, 
    `lootid`, `pickpocketloot`, `skinloot`, 
    `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, 
    `AIName`, `MovementType`, `HoverHeight`, 
    `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, 
    `RacialLeader`, `movementId`, `RegenHealth`, 
    `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, 
    `ScriptName`, `VerifiedBuild`
) VALUES (
    900001, 0, 0, 0,                          -- entry, difficulty variants
    0, 0,                                      -- kill credits
    'Hinterlands Battlemaster', 'Battleground Organizer', NULL,  -- name, subname, icon
    900001, 255, 255, 2, 35, 1,                -- gossip, levels, exp, faction, npcflag (gossip)
    1, 1.14286, 1, 1, 20, 1,                   -- speeds, detection, scale
    0, 0, 1,                                   -- rank, dmgschool, damage modifier
    2000, 2000, 1, 1,                          -- attack times, variance
    1, 2, 2048, 0,                             -- class, flags
    0, 0, 0, 0, 0,                             -- trainer data
    7, 0,                                      -- type (humanoid), type_flags
    0, 0, 0,                                   -- loot
    0, 0, 0, 0,                                -- pet/vehicle, gold
    '', 0, 1,                                  -- AI, movement, hover
    1, 1, 1, 1,                                -- modifiers
    0, 0, 1,                                   -- racial leader, movement id, regen
    0, 0, 0,                                   -- immune masks, flags_extra
    'npc_hinterlands_battlemaster', 12340      -- script, build
);

-- Creature model (model ID 16345 is a standard battlemaster model)
DELETE FROM `creature_template_model` WHERE `CreatureID` = 900001;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(900001, 0, 16345, 1, 100, 12340);

-- Gossip menu
DELETE FROM `gossip_menu` WHERE `MenuID` = 50000;
INSERT INTO `gossip_menu` (`MenuID`, `TextID`) VALUES
(900001, 900001);

-- Gossip text
DELETE FROM `npc_text` WHERE `ID` = 50000;
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`, `em0_0`, `em0_1`, `em0_2`, `em0_3`, `em0_4`, `em0_5`, `text1_0`, `text1_1`, `BroadcastTextID1`, `lang1`, `Probability1`, `em1_0`, `em1_1`, `em1_2`, `em1_3`, `em1_4`, `em1_5`, `text2_0`, `text2_1`, `BroadcastTextID2`, `lang2`, `Probability2`, `em2_0`, `em2_1`, `em2_2`, `em2_3`, `em2_4`, `em2_5`, `text3_0`, `text3_1`, `BroadcastTextID3`, `lang3`, `Probability3`, `em3_0`, `em3_1`, `em3_2`, `em3_3`, `em3_4`, `em3_5`, `text4_0`, `text4_1`, `BroadcastTextID4`, `lang4`, `Probability4`, `em4_0`, `em4_1`, `em4_2`, `em4_3`, `em4_4`, `em4_5`, `text5_0`, `text5_1`, `BroadcastTextID5`, `lang5`, `Probability5`, `em5_0`, `em5_1`, `em5_2`, `em5_3`, `em5_4`, `em5_5`, `text6_0`, `text6_1`, `BroadcastTextID6`, `lang6`, `Probability6`, `em6_0`, `em6_1`, `em6_2`, `em6_3`, `em6_4`, `em6_5`, `text7_0`, `text7_1`, `BroadcastTextID7`, `lang7`, `Probability7`, `em7_0`, `em7_1`, `em7_2`, `em7_3`, `em7_4`, `em7_5`, `VerifiedBuild`) VALUES
(900001, 'Welcome to the Hinterlands Battleground!\n\nThis is a custom 255 level battleground featuring unique mechanics, objectives, and rewards. Teams must work together to capture strategic points and defeat the enemy.\n\nGood luck, hero!', '', 0, 0, 1, 0, 0, 0, 0, 0, 0, '', '', 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 0, 0, 0, 0, 0, 0, 0, 0, 0, 12340);

-- Example creature spawn (adjust coordinates for your server)
-- DELETE FROM `creature` WHERE `guid` = 5000001;
-- INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `modelid`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`) VALUES
-- (5000001, 900001, 0, 0, 0, 1, 1, 0, 1, -8838.84, 862.916, 99.2371, 5.51524, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0);

-- Add to script loader (you'll need to manually add this to your script loader file)
-- AddSC_npc_hinterlands_battlemaster();
