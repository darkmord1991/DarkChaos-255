-- ============================================================================
-- Azshara Crater Quest System - SQL Script
-- Zones 4-8 & Mini-Dungeons: Quest Givers, Quests, Rewards
-- ============================================================================
-- Created: 2026-01-10
-- Pattern: Following 2026_01_09_00_azshara_crater_quests_zones_1_3.sql
-- ============================================================================

-- ============================================================================
-- SECTION 1: QUEST GIVER NPCs (creature_template)
-- ============================================================================

-- Zone 4: Wavemaster Kol'gar (Troll Shaman Male)
DELETE FROM `creature_template` WHERE `entry` = 300030;
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(300030, 0, 0, 0, 0, 0, 'Wavemaster Kol''gar', 'Central River Scout', 'quest', 300030, 40, 40, 0, 1733, 3, 1, 1.14286, 1, 1, 20, 1, 0, 0, 1, 2000, 2000, 1, 1, 2, 768, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 2, 2, 1, 1, 0, 0, 1, 0, 0, 2, '', 12340);

-- Zone 5: Demonologist Vex'ara (Blood Elf Warlock Female)
DELETE FROM `creature_template` WHERE `entry` = 300040;
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(300040, 0, 0, 0, 0, 0, 'Demonologist Vex''ara', 'Demon Hunter', 'quest', 300040, 50, 50, 0, 1733, 3, 1, 1.14286, 1, 1, 20, 1, 0, 0, 1, 2000, 2000, 1, 1, 8, 768, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 1.5, 2, 1, 1, 0, 0, 1, 0, 0, 2, '', 12340);

-- Zone 6: Felsworn Kael'thos (Blood Elf Paladin Male)
DELETE FROM `creature_template` WHERE `entry` = 300050;
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(300050, 0, 0, 0, 0, 0, 'Felsworn Kael''thos', 'Haldarr Expedition', 'quest', 300050, 60, 60, 0, 1733, 3, 1, 1.14286, 1, 1, 20, 1, 0, 0, 1, 2000, 2000, 1, 1, 2, 768, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 2.5, 1.5, 1.5, 1, 0, 0, 1, 0, 0, 2, '', 12340);

-- Zone 7: Dragonbinder Seryth (Draenei Mage Female)
DELETE FROM `creature_template` WHERE `entry` = 300060;
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(300060, 0, 0, 0, 0, 0, 'Dragonbinder Seryth', 'Wyrmrest Accord', 'quest', 300060, 70, 70, 1, 1733, 3, 1, 1.14286, 1, 1, 20, 1, 0, 0, 1, 2000, 2000, 1, 1, 8, 768, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 2, 3, 1, 1, 0, 0, 1, 0, 0, 2, '', 12340);

-- Zone 8: Archmage Thadeus (Human Mage Male)
DELETE FROM `creature_template` WHERE `entry` = 300070;
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(300070, 0, 0, 0, 0, 0, 'Archmage Thadeus', 'Temple Expedition', 'quest', 300070, 80, 80, 2, 1733, 3, 1, 1.14286, 1, 1, 20, 1, 0, 0, 1, 2000, 2000, 1, 1, 8, 768, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 2, 4, 1, 1, 0, 0, 1, 0, 0, 2, '', 12340);

-- D1 Quest Giver: Magister Idona (High Elf Female)
DELETE FROM `creature_template` WHERE `entry` = 300081;
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(300081, 0, 0, 0, 0, 0, 'Magister Idona', 'Reliquary Seeker', 'quest', 300081, 20, 20, 1, 1733, 3, 1, 1.14286, 1, 1, 20, 1, 0, 0, 1, 2000, 2000, 1, 1, 8, 768, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 2, 1, 1, 1, 0, 0, 1, 0, 0, 2, '', 12340);

-- D2 Quest Giver: Elder Brownpaw (Furbolg)
DELETE FROM `creature_template` WHERE `entry` = 300082;
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(300082, 0, 0, 0, 0, 0, 'Elder Brownpaw', 'Timbermaw Elder', 'quest', 300082, 30, 30, 1, 1733, 3, 1, 1.14286, 1, 1, 20, 1, 0, 0, 1, 2000, 2000, 1, 1, 2, 768, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 2, 1, 1, 1, 0, 0, 1, 0, 0, 2, '', 12340);

-- D3 Quest Giver: Captain Wavescorn (Human Male)
DELETE FROM `creature_template` WHERE `entry` = 300083;
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(300083, 0, 0, 0, 0, 0, 'Prospector Khazgorm', 'Ironforge Explorer', 'quest', 300083, 45, 45, 1, 1733, 3, 1, 1.14286, 1, 1, 20, 1, 0, 0, 1, 2000, 2000, 1, 1, 1, 768, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 2, 1, 1, 1, 0, 0, 1, 0, 0, 2, '', 12340);

-- D4 Quest Giver: Slayer Vorith (Blood Elf Demon Hunter)
DELETE FROM `creature_template` WHERE `entry` = 300084;
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(300084, 0, 0, 0, 0, 0, 'Slayer Vorith', 'Illidari Scout', 'quest', 300084, 60, 60, 1, 1733, 3, 1, 1.14286, 1, 1, 20, 1, 0, 0, 1, 2000, 2000, 1, 1, 4, 768, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 2, 1, 1, 1, 0, 0, 1, 0, 0, 2, '', 12340);

-- D5 Quest Giver: Priestess Lunara (Night Elf Priestess)
DELETE FROM `creature_template` WHERE `entry` = 300085;
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(300085, 0, 0, 0, 0, 0, 'Priestess Lunara', 'Temple Guardian', 'quest', 300085, 70, 70, 2, 1733, 3, 1, 1.14286, 1, 1, 20, 1, 0, 0, 1, 2000, 2000, 1, 1, 8, 768, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 2, 2, 1, 1, 0, 0, 1, 0, 0, 2, '', 12340);

-- D6 Quest Giver: Image of Arcanigos (Blue Dragon Human Form)
DELETE FROM `creature_template` WHERE `entry` = 300086;
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(300086, 0, 0, 0, 0, 0, 'Image of Arcanigos', 'Guardian Projection', 'quest', 300086, 80, 80, 2, 1733, 3, 1, 1.14286, 1, 1, 20, 1, 0, 0, 1, 2000, 2000, 1, 1, 8, 768, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 2, 2, 1, 1, 0, 0, 1, 0, 0, 2, '', 12340);


-- ============================================================================
-- SECTION 2: CREATURE MODEL DATA (creature_template_model)
-- ============================================================================

DELETE FROM `creature_template_model` WHERE `CreatureID` IN (300030, 300040, 300050, 300060, 300070, 300081, 300082, 300083, 300084, 300085, 300086);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(300030, 0, 20272, 1, 1, 12340),   -- Wavemaster Kol'gar (Troll Male)
(300040, 0, 20590, 1, 1, 12340),  -- Demonologist Vex'ara (Blood Elf Female)
(300050, 0, 20588, 1, 1, 12340),  -- Felsworn Kael'thos (Blood Elf Male)
(300060, 0, 16215, 1, 1, 12340),  -- Dragonbinder Seryth (Draenei Female)
(300070, 0, 3577, 1, 1, 12340),   -- Archmage Thadeus (Human Male Mage)
(300081, 0, 20602, 1, 1, 12340),  -- D1: Magister Idona (High Elf Female)
(300082, 0, 11629, 1, 1, 12340),  -- D2: Elder Brownpaw (Furbolg)
(300083, 0, 1462, 1, 1, 12340),   -- D3: Prospector Khazgorm (Dwarf Male)
(300084, 0, 21390, 1, 1, 12340),  -- D4: Slayer Vorith (Blood Elf DH)
(300085, 0, 4258, 1, 1, 12340),   -- D5: Priestess Lunara (Night Elf Female Priest)
(300086, 0, 26604, 1, 1, 12340);  -- D6: Arcanigos (Human Male with Runes)

-- ============================================================================
-- SECTION 3: QUEST TEMPLATES (quest_template)
-- ============================================================================
-- Quest IDs: Zone 4: 300400-300407, Zone 5: 300500-300507
-- ============================================================================

-- Clean up orphaned quest_request_items from non-existent quests
DELETE FROM `quest_request_items` WHERE `ID` IN (300420, 300421, 300422, 300520, 300521, 300522, 300620, 300621, 300622, 300720, 300721, 300722);

DELETE FROM `quest_template` WHERE `ID` BETWEEN 300400 AND 300807;

-- ----------------------------------------------------------------------------
-- ZONE 4 QUESTS (Level 30-40) - Wavemaster Kol'gar (300030)
-- ----------------------------------------------------------------------------

-- Quest 1: Naga Threat (Kill Spitelash Warriors)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300400, 2, 32, 28, 0, 0, 0, 4, 0, 1468, 1, 300311, 6, 300312, 4, 'Naga Threat', 'Kill 12 Spitelash Warriors.', 'The Naga have claimed the river. Push them back!', 'Azshara Crater', 'Naga driven back.', 6190, 12);

-- Quest 2: Shellhide Shells (Kill Makrura)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300401, 2, 35, 30, 0, 0, 0, 4, 0, 1710, 1, 300311, 7, 300312, 4, 'Shellhide Shells', 'Kill 10 Makrura Shellhide.', 'Their shells make excellent shields. Collect them.', 'Azshara Crater', 'Shells collected.', 6348, 10);

-- Quest 3: Arcane Devourers (Kill Arcane Devourers)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300402, 2, 36, 32, 0, 0, 0, 4, 0, 1721, 1, 300311, 7, 300312, 5, 'Arcane Devourers', 'Kill 8 Arcane Devourers.', 'These creatures consume magical energy. Destroy them.', 'Azshara Crater', 'Devourers destroyed.', 11467, 8);

-- Quest 4: Drake Scales (Kill Blue Drakes)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300403, 2, 39, 35, 0, 0, 0, 4, 500, 2621, 1, 300311, 8, 300312, 5, 'Drake Scales', 'Kill 6 Blue Drakes.', 'Dragon scales fetch a high price. Bring me some.', 'Azshara Crater', 'Scales harvested.', 6129, 6);

-- Quest 5: Bounty: Prince Nazjak (Rare Kill)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300404, 2, 40, 36, 0, 0, 0, 5, 1000, 2879, 1, 300311, 12, 300312, 8, 'Bounty: Prince Nazjak', 'Slay Prince Nazjak.', 'A Naga prince leads their forces. Kill him for a bounty.', 'Azshara Crater', 'Prince slain.', 2779, 1);

-- Quest 6: Proceed to Cliffs (Travel)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES
(300405, 2, 40, 36, 0, 0, 0, 5, 0, 0, 0, 300311, 8, 300312, 5, 'The Western Cliffs', 'Report to Demonologist Vex''ara.', 'Demonic activity increases to the west. Investigate.', 'Azshara Crater', 'Vex''ara found.');

-- Quest 7: River Pollution (Object Interact)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300406, 2, 33, 30, 0, 0, 0, 3, 0, 118, 5, 300311, 6, 300312, 4, 'River Pollution', 'Cleanse 8 Sludge Piles near the river banks.', 'The Naga corruption seeps into the land. Cleanse it.', 'Azshara Crater', 'Sludge cleansed.', 200000, 8); -- Placeholder GO ID

-- Quest 8: Crab Meat (Collect)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredItemId1`, `RequiredItemCount1`) VALUES
(300407, 2, 34, 30, 0, 0, 0, 3, 0, 769, 5, 300311, 6, 300312, 4, 'Crab Meat', 'Collect 10 Tender Crab Meat.', 'The troops need food. The river crabs are edible, if tough.', 'Azshara Crater', 'Meat collected.', 3730, 10); -- Big Bear Meat as placeholder

-- ----------------------------------------------------------------------------
-- ZONE 5 QUESTS (Level 40-50) - Demonologist Vex'ara (300040)
-- ----------------------------------------------------------------------------

-- Quest 1: Satyr Horns (Kill Jadefire Satyrs)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300500, 2, 42, 38, 0, 0, 0, 4, 0, 1604, 1, 300311, 10, 300312, 7, 'Satyr Horns', 'Kill 12 Jadefire Satyrs.', 'These demons corrupt the land. Destroy them.', 'Azshara Crater', 'Satyrs slain.', 11791, 12);

-- Quest 2: Felhound Fangs (Kill Felhounds)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300501, 2, 45, 41, 0, 0, 0, 4, 0, 1677, 1, 300311, 10, 300312, 7, 'Felhound Fangs', 'Kill 10 Felhounds.', 'Their fangs contain fel energy. I need samples.', 'Azshara Crater', 'Fangs collected.', 5865, 10);

-- Quest 3: Fel Steed Subjugation (Kill Fel Steeds)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300502, 2, 44, 40, 0, 0, 0, 4, 0, 4084, 1, 300311, 10, 300312, 7, 'Fel Steed Subjugation', 'Kill 8 Fel Steeds.', 'These mounts carry demons. Ground them permanently.', 'Azshara Crater', 'Steeds destroyed.', 11464, 8);

-- Quest 4: Shadowstalker Hunt (Kill Shadowstalkers)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300503, 2, 46, 42, 0, 0, 0, 4, 0, 300311, 10, 300312, 7, 0, 0, 'Shadowstalker Hunt', 'Kill 10 Hellcalled Shadowstalkers.', 'They stalk from the shadows. Hunt the hunters.', 'Azshara Crater', 'Stalkers eliminated.', 11452, 10);

-- Quest 5: Bounty: Monnos the Elder (Rare Kill)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300504, 2, 48, 44, 0, 0, 0, 5, 1500, 300311, 15, 300312, 10, 0, 0, 'Bounty: Monnos the Elder', 'Slay Monnos the Elder.', 'An ancient satyr leads their cult. End him.', 'Azshara Crater', 'Monnos defeated.', 6144, 1);

-- Quest 6: Proceed to Haldarr (Travel)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES
(300505, 2, 50, 46, 0, 0, 0, 5, 0, 300311, 10, 300312, 7, 0, 0, 'Into Haldarr Territory', 'Report to Felsworn Kael''thos.', 'The demon lords gather in Haldarr. Investigate.', 'Azshara Crater', 'Kael''thos found.');

-- Quest 7: Corrupted Soil (Collect)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredItemId1`, `RequiredItemCount1`) VALUES
(300506, 2, 43, 40, 0, 0, 0, 3, 0, 300311, 10, 300312, 7, 0, 0, 'Corrupted Soil', 'Collect 10 Corrupted Soil Samples.', 'The very earth bleeds with fel. Bring me samples for analysis.', 'Azshara Crater', 'Soil collected.', 300000, 10); -- Placeholder Item ID

-- Quest 8: Demonic Runes (Collect)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredItemId1`, `RequiredItemCount1`) VALUES
(300507, 2, 47, 43, 0, 0, 0, 4, 0, 12662, 1, 300311, 10, 300312, 7, 'Demonic Runes', 'Collect 6 Demonic Runes from Satyrs.', 'The Satyrs use runes to channel their power. Seize them.', 'Azshara Crater', 'Runes collected.', 12662, 6); -- Demonic Rune

-- ----------------------------------------------------------------------------
-- ZONE 6 QUESTS (Level 50-60) - Felsworn Kael'thos (300050)
-- ----------------------------------------------------------------------------

-- Quest 1: Legashi Cull (Kill Satyrs)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300600, 2, 52, 48, 0, 0, 0, 4, 0, 8270, 1, 300311, 12, 300312, 8, 'Legashi Cull', 'Kill 12 Legashi Satyrs.', 'The Legashi satyrs must be purged.', 'Azshara Crater', 'Satyrs culled.', 6200, 12);

-- Quest 2: Infernal Cores (Collect Item)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredItemId1`, `RequiredItemCount1`) VALUES
(300601, 2, 55, 50, 0, 0, 0, 4, 0, 6660, 1, 300311, 12, 300312, 8, 'Infernal Cores', 'Collect 8 Entropic Cores from Entropic Beasts.', 'The infernals are powered by chaotic cores. Retrieve them.', 'Azshara Crater', 'Cores collected.', 5218, 8); -- Using 'Cleaned Infernal Core' (5218) as placeholder

-- Quest 3: Doomguard Commander (Kill Elite)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300602, 2, 58, 52, 0, 0, 0, 5, 0, 8318, 1, 300311, 12, 300312, 8, 'Doomguard Commander', 'Kill 4 Doomguard Commanders.', 'The Legion forces here are led by Doomguards. Eliminate their leadership.', 'Azshara Crater', 'Commanders defeated.', 7671, 4);

-- Quest 4: Bounty: Gatekeeper Karlindos (Rare Kill)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300603, 2, 58, 54, 0, 0, 0, 5, 2000, 300311, 20, 300312, 10, 0, 0, 'Bounty: Gatekeeper Karlindos', 'Slay Gatekeeper Karlindos.', 'Karlindos guards the secrets of the Fel Pit. Remove him.', 'Azshara Crater', 'Karlindos slain.', 10831, 1);

-- Quest 5: Proceed to Dragon Coast (Travel)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES
(300604, 2, 60, 55, 0, 0, 0, 5, 0, 300311, 12, 300312, 8, 0, 0, 'Dragon Coast', 'Find Dragonbinder Seryth on the coast.', 'Dragons have been sighted on the coast. Secure the area.', 'Azshara Crater', 'Seryth found.');

-- Quest 6: Portal Sabotage (Interact/Kill)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300605, 2, 53, 50, 0, 0, 0, 4, 0, 300311, 12, 300312, 8, 0, 0, 'Portal Sabotage', 'Sabotage 3 Legion Portals (Kill Felguard Sentries).', 'The portals are protected by sentries. Kill them to disrupt the flow.', 'Azshara Crater', 'Sentries slain.', 8716, 6);

-- Quest 7: Fel Armaments (Collect)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredItemId1`, `RequiredItemCount1`) VALUES
(300606, 2, 56, 52, 0, 0, 0, 4, 0, 23508, 1, 300311, 12, 300312, 8, 'Fel Armaments', 'Collect 10 Fel Armaments.', 'Their weapons are forged in fel. We must study them to defeat them.', 'Azshara Crater', 'Armaments collected.', 23508, 10); -- Fel Armament

-- ----------------------------------------------------------------------------
-- ZONE 7 QUESTS (Level 60-70) - Dragonbinder Seryth (300060)
-- ----------------------------------------------------------------------------

-- Quest 1: Whelpling Menace (Kill Whelps)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300700, 2, 62, 58, 0, 0, 0, 4, 0, 10246, 1, 300311, 15, 300312, 10, 'Whelpling Menace', 'Kill 12 Azure Whelplings.', 'The blue dragonflight breeds here. Thin their numbers.', 'Azshara Crater', 'Whelps slain.', 6130, 12);

-- Quest 2: Mana Surge (Kill Elementals)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300701, 2, 65, 60, 0, 0, 0, 4, 0, 10271, 1, 300311, 15, 300312, 10, 'Mana Surge', 'Destroy 10 Mana Surges.', 'Unbound magic manifests as elementals. Dissipate them.', 'Azshara Crater', 'Surges destroyed.', 15527, 10);

-- Quest 3: Netherwing Presence (Kill Drake)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300702, 2, 68, 64, 0, 0, 0, 5, 0, 10367, 1, 300311, 15, 300312, 10, 'Netherwing Presence', 'Kill 6 Azure Netherwing Drakes.', 'Netherwing drakes corrupt the flight. Eliminate them.', 'Azshara Crater', 'Drakes grounded.', 23456, 6);

-- Quest 4: Bounty: General Colbatann (Rare Kill)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300703, 2, 68, 65, 0, 0, 0, 5, 2500, 300311, 20, 300312, 15, 0, 0, 'Bounty: General Colbatann', 'Kill General Colbatann.', 'The Wyrmcult is led by Colbatann. Slay him.', 'Azshara Crater', 'General defeated.', 10196, 1);

-- Quest 5: The Temple Approach (Travel)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES
(300704, 2, 70, 68, 0, 0, 0, 5, 0, 300311, 15, 300312, 10, 0, 0, 'The Temple Approach', 'Report to Archmage Thadeus at the Temple.', 'The final battle awaits at the Temple of Eternity.', 'Azshara Crater', 'Thadeus found.');

-- Quest 6: Dragon Egg Hunt (Collect/Destoy)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300705, 2, 64, 60, 0, 0, 0, 3, 0, 300311, 15, 300312, 10, 0, 0, 'Dragon Egg Hunt', 'Destroy 8 Blue Dragon Eggs.', 'The eggs must not hatch. Destroy them for the sanctity of the flight.', 'Azshara Crater', 'Eggs destroyed.', 181057, 8); -- Placeholder GO ID

-- Quest 7: Cultist Orders (Collect)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredItemId1`, `RequiredItemCount1`) VALUES
(300706, 2, 67, 65, 0, 0, 0, 4, 0, 300311, 15, 300312, 10, 0, 0, 'Cultist Orders', 'Collect 6 Wyrmcult Orders.', 'The cultists are up to something. Find their orders.', 'Azshara Crater', 'Orders collected.', 24449, 6); -- Wyrmcult Orders

-- ----------------------------------------------------------------------------
-- ZONE 8 QUESTS (Level 70-80) - Archmage Thadeus (300070)
-- ----------------------------------------------------------------------------

-- Quest 1: Skeletal Army (Kill Skeletons)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300800, 2, 72, 70, 0, 0, 0, 4, 0, 24913, 1, 300311, 20, 300312, 15, 'Skeletal Army', 'Kill 12 Skeletal Craftsmen.', 'The enemy rebuilds their forces using the dead. Stop them.', 'Azshara Crater', 'Skeletons destroyed.', 32164, 12);

-- Quest 2: Faceless Horror (Kill Aberrations)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300801, 2, 75, 72, 0, 0, 0, 4, 0, 36136, 1, 300311, 20, 300312, 15, 'Faceless Horror', 'Kill 8 Faceless Lurkers.', 'The Old Gods'' influence is strong here. Banish the Faceless.', 'Azshara Crater', 'Lurkers banished.', 31691, 8);

-- Quest 3: Forgotten Captains (Kill Elites)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300802, 2, 78, 75, 0, 0, 0, 5, 0, 36141, 1, 300311, 20, 300312, 15, 'Forgotten Captains', 'Kill 4 Forgotten Captains.', 'Undead captains command the temple grounds. Slay them.', 'Azshara Crater', 'Captains slain.', 27220, 4);

-- Quest 4: Bounty: Antilos (Rare Kill)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300803, 2, 80, 78, 0, 0, 0, 5, 3000, 36032, 1, 300311, 25, 300312, 20, 'Bounty: Antilos', 'Slay Antilos.', 'A powerful griffin patrols the skies. Bring it down.', 'Azshara Crater', 'Antilos slain.', 6910, 1);

-- Quest 5: Temple Artifacts (Collect)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredItemId1`, `RequiredItemCount1`) VALUES
(300804, 2, 73, 70, 0, 0, 0, 4, 0, 300311, 20, 300312, 15, 0, 0, 'Temple Artifacts', 'Collect 10 Ancient Artifacts.', 'The temple holds ancient secrets. Retrieve them before the undead destroy them.', 'Azshara Crater', 'Artifacts collected.', 3822, 10); -- Ancient Coin

-- Quest 6: Ghostly Essence (Collect)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredItemId1`, `RequiredItemCount1`) VALUES
(300805, 2, 76, 73, 0, 0, 0, 4, 0, 300311, 20, 300312, 15, 0, 0, 'Ghostly Essence', 'Collect 8 Phantom Essences.', 'The phantoms are bound by this essence. Bring it to me to break the binding.', 'Azshara Crater', 'Essences collected.', 23180, 8); -- Phantom Dust



-- ----------------------------------------------------------------------------
-- DUNGEON QUESTS (D1-D5)
-- ----------------------------------------------------------------------------

-- D1: Ruins of Zin-Azshari (Kill Lady Sarevess - Level 25 Elite)
DELETE FROM `quest_template` WHERE `ID` BETWEEN 300900 AND 300940;
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300900, 2, 25, 18, 0, 0, 5, 5, 1000, 3046, 1, 300311, 25, 300312, 15, 'Ruins of Zin-Azshari', 'Defeat Lady Sarevess.', 'The Highborne Lady Sarevess commands the naga here. Defeat her to clear the ruins.', 'Ruins of Zin-Azshari', 'Sarevess defeated.', 4831, 1),
(300901, 2, 24, 18, 0, 0, 5, 5, 800, 300311, 20, 300312, 10, 0, 0, 'Targorr the Dread', 'Slay Targorr the Dread.', 'The Blackrock Orcs have rooted themselves in the ruins. Their leader, Targorr, must be removed.', 'Ruins of Zin-Azshari', 'Targorr slain.', 1716, 1);

-- D2: Timbermaw Deep (Kill Death Speaker Jargba - Level 30 Elite)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300910, 2, 30, 24, 0, 0, 5, 5, 1500, 2565, 1, 300311, 25, 300312, 15, 'Timbermaw Deep', 'Defeat Death Speaker Jargba.', 'The corruption is led by Jargba. Silence the Death Speaker.', 'Timbermaw Deep', 'Jargba slain.', 4424, 1),
(300911, 2, 29, 24, 0, 0, 5, 5, 1200, 300311, 20, 300312, 10, 0, 0, 'Aggem Thorncurse', 'Slay Aggem Thorncurse.', 'Aggem Thorncurse leads the assault. Ensure he never threatens us again.', 'Timbermaw Deep', 'Aggem slain.', 4428, 1);

INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGo2`, `RequiredNpcOrGoCount2`) VALUES
(300912, 2, 30, 24, 0, 0, 5, 5, 1000, 300311, 15, 300312, 5, 0, 0, 'The Mosshide Menace', 'Slay 8 Mosshide Brutes and 8 Mosshide Mystics.', 'The Mosshide Gnolls have desecrated our sacred cave. Clear them out.', 'Timbermaw Deep', 'Mosshide cleared.', 1012, 8, 1013, 8);

-- D3: Spitelash Depths (Kill Lord Skwol - Level 51 Elite)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300920, 2, 50, 45, 0, 0, 5, 5, 2000, 8270, 1, 300311, 25, 300312, 15, 'The Pyromancer', 'Defeat Pyromancer Loregrain.', 'The Dark Iron Pyromancer Loregrain commands the invasion. His flames must be extinguished.', 'Spitelash Depths', 'Loregrain defeated.', 9024, 1),
(300922, 2, 49, 45, 0, 0, 5, 5, 1800, 300311, 20, 300312, 10, 0, 0, 'Faulty Engineering', 'Destroy the Faulty War Golem.', 'A massive War Golem guards the forge chambers. Its unstable core makes it dangerous. Destroy it before it explodes.', 'Spitelash Depths', 'Golem destroyed.', 8279, 1),
(300923, 2, 51, 46, 0, 0, 5, 5, 2200, 300311, 25, 300312, 15, 0, 0, 'Ambassador of Flame', 'Slay Ambassador Flamelash.', 'The Dark Iron have summoned a powerful fire elemental lord. Ambassador Flamelash must be banished before he can open a portal to the Firelands.', 'Spitelash Depths', 'Flamelash banished.', 9156, 1);

INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGo2`, `RequiredNpcOrGoCount2`) VALUES
(300921, 2, 48, 44, 0, 0, 5, 5, 1500, 300311, 20, 300312, 10, 0, 0, 'The Iron Legion', 'Slay 10 Dark Iron Watchmen and 10 Dark Iron Geologists.', 'The Dark Iron ranks are swelling. Thin their numbers before they breach the surface.', 'Spitelash Depths', 'Legion thinned.', 8637, 10, 5839, 10);

-- D4: The Fel Pit (Kill Prince Tortheldrin - Level 61 Elite)
DELETE FROM `quest_template` WHERE `ID` BETWEEN 300930 AND 300934;
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300930, 2, 61, 55, 0, 0, 5, 5, 2500, 10271, 1, 300311, 25, 300312, 15, 'The Fel Pit', 'Defeat Prince Tortheldrin.', 'The Prince has turned to demons for power. End his madness.', 'The Fel Pit', 'Prince defeated.', 11486, 1);

INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGo2`, `RequiredNpcOrGoCount2`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES
(300931, 2, 58, 54, 0, 0, 5, 5, 2200, 300311, 20, 300312, 12, 12143, 1, 0, 0, 'Lady Hederine', 'Defeat Lady Hederine.', 'Lady Hederine commands the Satyr forces. Defeat her to weaken their hold on the Fel Pit.', 'The Fel Pit', 'Hederine defeated.'),
(300932, 2, 59, 55, 0, 0, 5, 5, 2300, 300311, 21, 300312, 13, 19261, 1, 0, 0, 'Infernal Warbringer', 'Slay the Infernal Warbringer.', 'An Infernal Warbringer has been summoned from the Twisting Nether. Banish it before it can open a portal.', 'The Fel Pit', 'Infernal banished.'),
(300933, 2, 60, 56, 0, 0, 5, 5, 2400, 300311, 22, 300312, 14, 18044, 1, 0, 0, 'Doomguard Punisher', 'Slay the Doomguard Punisher.', 'The Doomguard Punisher leads the demon legions. Destroy it to scatter their forces.', 'The Fel Pit', 'Doomguard destroyed.'),
(300934, 2, 57, 53, 0, 0, 5, 5, 2100, 300311, 19, 300312, 11, 6135, 8, 7671, 6, 'Demon Legion', 'Slay 8 Legashi Hellcallers and 6 Doomguard Commanders.', 'The demon forces grow stronger. Thin their ranks before they can summon reinforcements.', 'The Fel Pit', 'Legion weakened.');

-- D5: Temple of Elune (Level 60-70)
DELETE FROM `quest_template` WHERE `ID` BETWEEN 300940 AND 300946;
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300940, 2, 70, 65, 0, 0, 5, 5, 3000, 15806, 1, 300311, 25, 300312, 15, 'Temple of Elune', 'Defeat Priestess Delrissa.', 'Priestess Delrissa has corrupted the Temple of Elune. She must be stopped before the corruption spreads.', 'Temple of Elune', 'Delrissa defeated.', 24560, 1),
(300941, 2, 68, 63, 0, 0, 5, 5, 2500, 300311, 20, 300312, 12, 0, 0, 'The Twilight Threat', 'Slay Twilight Lord Kelris.', 'Twilight Lord Kelris leads the cultists infiltrating the temple. Eliminate this threat.', 'Temple of Elune', 'Kelris slain.', 4832, 1),
(300942, 2, 69, 64, 0, 0, 5, 5, 2700, 300311, 22, 300312, 13, 0, 0, 'Arcane Corruption', 'Defeat Arcane Torrent.', 'An arcane anomaly known as Arcane Torrent is destabilizing the temple\'s wards. Destroy it.', 'Temple of Elune', 'Torrent destroyed.', 16485, 1),
(300943, 2, 67, 62, 0, 0, 5, 5, 2400, 300311, 18, 300312, 11, 0, 0, 'High Priestess Arlokk', 'Defeat High Priestess Arlokk.', 'High Priestess Arlokk guards the inner sanctum. Defeat her to reach Delrissa.', 'Temple of Elune', 'Arlokk defeated.', 14515, 1);

INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGo2`, `RequiredNpcOrGoCount2`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES
(300944, 2, 65, 61, 0, 0, 5, 5, 2200, 300311, 16, 300312, 10, 10683, 8, 6492, 8, 'Highborne Corruption', 'Slay 8 Highborne Lichlings and 8 Highborne Summoners.', 'The Highborne spirits have been corrupted by dark magic. Cleanse them from the temple grounds.', 'Temple of Elune', 'Highborne cleansed.'),
(300945, 2, 66, 62, 0, 0, 5, 5, 2300, 300311, 17, 300312, 11, 15467, 10, 15621, 5, 'Moonkin Madness', 'Slay 10 Moonkin Oracles and 5 Moonkin Matriarchs.', 'The Moonkin have been driven mad by the corruption. Put them out of their misery.', 'Temple of Elune', 'Moonkin cleansed.'),
(300946, 2, 68, 63, 0, 0, 5, 5, 2600, 300311, 19, 300312, 12, 13019, 8, 13022, 6, 'Eldreth Incursion', 'Slay 8 Eldreth Sorcerers and 6 Eldreth Seethers.', 'The Eldreth demons have invaded the temple. Drive them back into the shadows.', 'Temple of Elune', 'Eldreth repelled.');

-- D6: Sanctum of the Highborne (Level 75-80)
DELETE FROM `quest_template` WHERE `ID` BETWEEN 300960 AND 300966;
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300960, 2, 77, 74, 0, 0, 10, 5, 5000, 34138, 1, 300311, 25, 300312, 15, 'Sanctum of the Highborne', 'Defeat Cyanigosa.', 'The Blue Dragonflight protects this Sanctum. Prove your strength against Cyanigosa.', 'Sanctum of the Highborne', 'Cyanigosa defeated.', 29317, 1),
(300961, 2, 76, 73, 0, 0, 10, 5, 4500, 300311, 22, 300312, 13, 0, 0, 'Magister Kalendris', 'Defeat Magister Kalendris.', 'Magister Kalendris commands the Highborne spirits. Defeat him to weaken their hold on the Sanctum.', 'Sanctum of the Highborne', 'Kalendris defeated.', 11487, 1),
(300962, 2, 75, 72, 0, 0, 10, 5, 4000, 300311, 20, 300312, 12, 0, 0, 'The Forgotten Ones', 'Slay 10 Forgotten Ones.', 'The Forgotten Ones lurk in the shadows of the Sanctum. Cleanse them from this sacred place.', 'Sanctum of the Highborne', 'Forgotten Ones cleansed.', 27959, 10),
(300963, 2, 75, 72, 0, 0, 10, 5, 4000, 300311, 20, 300312, 12, 0, 0, 'Arcane Sentinels', 'Destroy 10 Arcane Sentinels.', 'The Arcane Sentinels guard the Sanctum\'s halls. Disable them to progress deeper.', 'Sanctum of the Highborne', 'Sentinels destroyed.', 15689, 10);

INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGo2`, `RequiredNpcOrGoCount2`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES
(300964, 2, 76, 73, 0, 0, 10, 5, 4200, 300311, 21, 300312, 13, 37881, 12, 31363, 8, 'Wretched Infestation', 'Slay 12 Wretched Ghouls and 8 Wretched Belchers.', 'The Wretched have infested the lower halls of the Sanctum. Purge them.', 'Sanctum of the Highborne', 'Wretched purged.'),
(300965, 2, 77, 74, 0, 0, 10, 5, 4400, 300311, 22, 300312, 14, 6116, 10, 7850, 8, 'Highborne Spirits', 'Banish 10 Highborne Apparitions and 8 Ancient Highborne Spirits.', 'The ancient Highborne spirits linger in torment. Release them from their eternal prison.', 'Sanctum of the Highborne', 'Spirits released.'),
(300966, 2, 78, 75, 0, 0, 10, 5, 4600, 300311, 23, 300312, 15, 27099, 6, 0, 0, 'Faceless Horror', 'Slay 6 Faceless Lurkers.', 'The Faceless Ones serve the Old Gods. They must not be allowed to corrupt the Sanctum further.', 'Sanctum of the Highborne', 'Faceless threat eliminated.');

-- ============================================================================
-- DUNGEON INTRODUCTION QUESTS (Breadcrumbs from Zone Givers)
-- ============================================================================

DELETE FROM `quest_template` WHERE `ID` BETWEEN 300950 AND 300955;

-- D1 Introduction: Zone 2 -> D1 (Arcanist Melia -> Magister Idona)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES
(300950, 2, 20, 18, 0, 0, 5, 4, 500, 300311, 5, 300312, 3, 'The Ruins of Zin-Azshari', 'Speak with Magister Idona at the Ruins of Zin-Azshari.', 'The ancient Highborne ruins to the south are stirring with dark magic. Magister Idona is investigating. Seek her out - she may need assistance from a capable group.', 'Azshara Crater', 'You have found Magister Idona.');

-- D2 Introduction: Zone 3 -> D2 (Pathfinder Gor'nash -> Elder Brownpaw)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES
(300951, 2, 28, 25, 0, 0, 5, 4, 800, 300311, 8, 300312, 5, 'Timbermaw Deep', 'Speak with Elder Brownpaw at Timbermaw Deep.', 'The Furbolg Elder Brownpaw has sent word of a great corruption spreading through the sacred caves. He seeks brave warriors to help cleanse the depths.', 'Azshara Crater', 'You have found Elder Brownpaw.');

-- D3 Introduction: Zone 4 -> D3 (Wavemaster Kol'gar -> Prospector Khazgorm)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES
(300952, 2, 45, 40, 0, 0, 5, 4, 1500, 300311, 12, 300312, 8, 'The Dark Iron Invasion', 'Speak with Prospector Khazgorm near Spitelash Depths.', 'Prospector Khazgorm has discovered a Dark Iron invasion force deep beneath the crater. They are excavating something dangerous. Gather your allies and find him immediately!', 'Azshara Crater', 'You have found Prospector Khazgorm.');

-- D4 Introduction: Zone 6 -> D4 (Felsworn Kael'thos -> Slayer Vorith)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES
(300953, 2, 58, 55, 0, 0, 5, 4, 2000, 300311, 15, 300312, 10, 'The Fel Pit Beckons', 'Speak with Slayer Vorith at The Fel Pit.', 'The Illidari have detected a massive demonic presence in the Fel Pit. Slayer Vorith is coordinating an assault. Only the strongest should answer this call.', 'Azshara Crater', 'You have found Slayer Vorith.');

-- D5 Introduction: Zone 7 -> D5 (Dragonbinder Seryth -> Priestess Lunara)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES
(300955, 2, 67, 63, 0, 0, 5, 4, 2500, 300311, 18, 300312, 11, 'The Temple of Elune', 'Speak with Priestess Lunara at the Temple of Elune.', 'Priestess Lunara has sent word of a great corruption within the Temple of Elune. She requires champions to help cleanse the sacred grounds.', 'Azshara Crater', 'You have found Priestess Lunara.');

-- D6 Introduction: Zone 8 -> D6 (Archmage Thadeus -> Image of Arcanigos)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES
(300954, 2, 76, 74, 0, 0, 10, 5, 3000, 300311, 20, 300312, 15, 'The Sanctum Guardian', 'Speak with the Image of Arcanigos at the Sanctum of the Highborne.', 'The ancient Sanctum holds secrets that could turn the tide of war. The Blue Dragonflight has sent a guardian projection to test worthy champions. This will be your greatest challenge yet.', 'Azshara Crater', 'You have found the Image of Arcanigos.');


-- ============================================================================
-- SECTION 5: NPC QUEST RELATIONS
-- ============================================================================

DELETE FROM `creature_queststarter` WHERE `id` IN (300030, 300040, 300050, 300060, 300070, 300081, 300082, 300083, 300084, 300085);
DELETE FROM `creature_questender` WHERE `id` IN (300030, 300040, 300050, 300060, 300070, 300081, 300082, 300083, 300084, 300085);

-- Delete orphaned quest relations for non-existent quests
DELETE FROM `creature_queststarter` WHERE `quest` IN (300420, 300421, 300422, 300520, 300521, 300522, 300620, 300621, 300622, 300720, 300721, 300722);
DELETE FROM `creature_questender` WHERE `quest` IN (300420, 300421, 300422, 300520, 300521, 300522, 300620, 300621, 300622, 300720, 300721, 300722);

-- Delete breadcrumb quest relations
DELETE FROM `creature_queststarter` WHERE `quest` BETWEEN 300950 AND 300954;
DELETE FROM `creature_questender` WHERE `quest` BETWEEN 300950 AND 300954;

-- Breadcrumb Quests (Zone Givers -> Dungeon Givers)
-- D1: Arcanist Melia (300010) gives quest to find Magister Idona
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES (300010, 300950);
INSERT INTO `creature_questender` (`id`, `quest`) VALUES (300081, 300950);

-- D2: Pathfinder Gor'nash (300020) gives quest to find Elder Brownpaw
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES (300020, 300951);
INSERT INTO `creature_questender` (`id`, `quest`) VALUES (300082, 300951);

-- D3: Wavemaster Kol'gar (300030) gives quest to find Prospector Khazgorm
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES (300030, 300952);
INSERT INTO `creature_questender` (`id`, `quest`) VALUES (300083, 300952);

-- D4: Felsworn Kael'thos (300050) gives quest to find Slayer Vorith
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES (300050, 300953);
INSERT INTO `creature_questender` (`id`, `quest`) VALUES (300084, 300953);

-- D5: Dragonbinder Seryth (300060) gives quest to find Priestess Lunara
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES (300060, 300955);
INSERT INTO `creature_questender` (`id`, `quest`) VALUES (300085, 300955);

-- D6: Archmage Thadeus (300070) gives quest to find Image of Arcanigos
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES (300070, 300954);
INSERT INTO `creature_questender` (`id`, `quest`) VALUES (300086, 300954);

-- Dungeon Quest Givers
-- D1: Magister Idona (300081)
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(300081, 300900), (300081, 300901);
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(300081, 300900), (300081, 300901);

-- D2: Elder Brownpaw (300082)
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(300082, 300910), (300082, 300911), (300082, 300912);
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(300082, 300910), (300082, 300911), (300082, 300912);

-- D3: Prospector Khazgorm (300083)
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(300083, 300920), (300083, 300921), (300083, 300922), (300083, 300923);
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(300083, 300920), (300083, 300921), (300083, 300922), (300083, 300923);

-- D4: Slayer Vorith (300084)
DELETE FROM `creature_queststarter` WHERE `id` = 300084 AND `quest` BETWEEN 300930 AND 300934;
DELETE FROM `creature_questender` WHERE `id` = 300084 AND `quest` BETWEEN 300930 AND 300934;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(300084, 300930), (300084, 300931), (300084, 300932), (300084, 300933), (300084, 300934);
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(300084, 300930), (300084, 300931), (300084, 300932), (300084, 300933), (300084, 300934);

-- D5: Priestess Lunara (300085)
DELETE FROM `creature_queststarter` WHERE `id` = 300085 AND `quest` BETWEEN 300940 AND 300946;
DELETE FROM `creature_questender` WHERE `id` = 300085 AND `quest` BETWEEN 300940 AND 300946;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(300085, 300940), (300085, 300941), (300085, 300942), (300085, 300943), (300085, 300944), (300085, 300945), (300085, 300946);
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(300085, 300940), (300085, 300941), (300085, 300942), (300085, 300943), (300085, 300944), (300085, 300945), (300085, 300946);

-- D6: Image of Arcanigos (300086)
DELETE FROM `creature_queststarter` WHERE `id` = 300086 AND `quest` BETWEEN 300960 AND 300966;
DELETE FROM `creature_questender` WHERE `id` = 300086 AND `quest` BETWEEN 300960 AND 300966;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(300086, 300960), (300086, 300961), (300086, 300962), (300086, 300963), (300086, 300964), (300086, 300965), (300086, 300966);
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(300086, 300960), (300086, 300961), (300086, 300962), (300086, 300963), (300086, 300964), (300086, 300965), (300086, 300966);

-- Kol'gar (Zone 4)
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(300030, 300400), (300030, 300401), (300030, 300402), (300030, 300403), (300030, 300404), (300030, 300405), (300030, 300406), (300030, 300407);
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(300030, 300306), -- Arrive from Zone 3
(300030, 300400), (300030, 300401), (300030, 300402), (300030, 300403), (300030, 300404), (300030, 300406), (300030, 300407);

-- Vex'ara (Zone 5)
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(300040, 300500), (300040, 300501), (300040, 300502), (300040, 300503), (300040, 300504), (300040, 300505), (300040, 300506), (300040, 300507);
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(300040, 300405), -- Arrive from Zone 4
(300040, 300500), (300040, 300501), (300040, 300502), (300040, 300503), (300040, 300504), (300040, 300506), (300040, 300507);

-- Kael'thos (Zone 6)
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(300050, 300600), (300050, 300601), (300050, 300602), (300050, 300603), (300050, 300604), (300050, 300605), (300050, 300606);
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(300050, 300505), -- Arrive from Zone 5
(300050, 300600), (300050, 300601), (300050, 300602), (300050, 300603), (300050, 300605), (300050, 300606);

-- Seryth (Zone 7)
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(300060, 300700), (300060, 300701), (300060, 300702), (300060, 300703), (300060, 300704), (300060, 300705), (300060, 300706);
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(300060, 300604), -- Arrive from Zone 6
(300060, 300700), (300060, 300701), (300060, 300702), (300060, 300703), (300060, 300705), (300060, 300706);

-- Thadeus (Zone 8)
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(300070, 300800), (300070, 300801), (300070, 300802), (300070, 300803), (300070, 300804), (300070, 300805);
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(300070, 300704), -- Arrive from Zone 7
(300070, 300800), (300070, 300801), (300070, 300802), (300070, 300803), (300070, 300804), (300070, 300805);

-- ============================================================================
-- SECTION 6: QUEST TEXTS / GOSSIP
-- ============================================================================

DELETE FROM `quest_offer_reward` WHERE `ID` BETWEEN 300400 AND 300966;
INSERT INTO `quest_offer_reward` (`ID`, `RewardText`) VALUES
(300400, 'The waters run red with Strashaz blood. Good.'),
(300401, 'These shells will reinforce our bunkers.'),
(300402, 'Rock Elementals have been shattered.'),
(300403, 'Hydra scales... excellent.'),
(300404, 'Prince Nazjak is dead? HAH! The tides turn in our favor.'),
(300406, 'The river is clearer already. Well done.'),
(300407, 'It smells... potent. But it will feed the troops.'),
(300500, 'One less demon to worry about.'),
(300504, 'Monnos is slain. The satyrs will be in disarray.'),
(300506, 'This soil is teeming with corruption. I will analyze it.'),
(300507, 'These runes vibrate with dark power. Excellent.'),
(300603, 'Karlindos has fallen. The Pit is vulnerable.'),
(300605, 'The portals flicker and fade. You have bought us time.'),
(300606, 'Crude, but effective weaponry. We know their methods now.'),
(300700, 'The Phase Hunters are banished. Are they truly gone?'),
(300701, 'The surges are dissipated.'),
(300702, 'The skies are clearer.'),
(300703, 'Colbatann destroyed! The Wyrmcult will crumble.'),
(300705, 'The eggs are smashed. The cycle is broken.'),
(300706, 'These orders reveal their next move. Good work.'),
(300800, 'The skeletons are dusted. We can advance.'),
(300803, 'Antilos grounded. The skies are ours.'),
(300804, 'Exquisite artifacts. They belong in a museum, or my study.'),
(300805, 'The essence dissipates. The spirits are free.'),
(300900, 'The Highborne are at rest. Zin-Azshari is quiet.'),
(300901, 'Targorr is dead. The Blackrock presence will crumble without leadership.'),
(300910, 'My people can sleep peacefully now. Thank you.'),
(300911, 'Aggem is dead. A fitting end for such a traitor.'),
(300912, 'The cave is clearer now, though the stench of Gnolls may linger.'),
(300920, 'Loregrain is ashes. The Dark Irons will scatter.'),
(300921, 'Their ranks are broken. Good work.'),
(300922, 'The Golem is scrap. Maybe we can salvage the parts.'),
(300923, 'Flamelash is banished. The Firelands portal is sealed... for now.'),
-- D4 Quests
(300930, 'Prince Tortheldrin\'s madness ends here. The Fel Pit is cleansed.'),
(300931, 'Lady Hederine falls. The Satyr forces scatter.'),
(300932, 'The Infernal is banished. The portal is sealed.'),
(300933, 'The Doomguard Punisher is destroyed. The demon legion weakens.'),
(300934, 'Their numbers are thinned. The Fel Pit grows quieter.'),
-- D5 Quests (Temple of Elune)
(300940, 'Priestess Delrissa has fallen. The Temple of Elune is purified.'),
(300941, 'Twilight Lord Kelris is no more. The cultist threat is eliminated.'),
(300942, 'The Arcane Torrent is destroyed. The temple\'s wards are stabilizing.'),
(300943, 'High Priestess Arlokk has been defeated. The inner sanctum is accessible.'),
(300944, 'The corrupted Highborne are cleansed. The temple grows purer.'),
(300945, 'The Moonkin are at peace. Their madness has ended.'),
(300946, 'The Eldreth are banished. The temple is secure.'),
-- D6 Quests (Sanctum of the Highborne)
(300960, 'Cyanigosa is defeated. You have proven yourself worthy.'),
(300961, 'Magister Kalendris falls. The Highborne spirits weaken.'),
(300962, 'The Forgotten Ones are cleansed from the Sanctum.'),
(300963, 'The Arcane Sentinels are disabled. The path is clear.'),
(300964, 'The Wretched are purged. The halls are cleansed.'),
(300965, 'The Highborne spirits are released. They can finally rest.'),
(300966, 'The Faceless threat is eliminated. The Sanctum is safe... for now.');

DELETE FROM `npc_text` WHERE `ID` IN (300030, 300040, 300050, 300060, 300070, 300081, 300082, 300083, 300084, 300085, 300086);
INSERT INTO `npc_text` (`ID`, `text0_0`) VALUES
(300030, 'The river is treacherous, outsider.'),
(300040, 'Do you seek power? Or death? The cliffs offer both.'),
(300050, 'The Light guides my blades, even in this fel pit.'),
(300060, 'The dragons must be stopped.'),
(300070, 'Welcome to the Temple. We prepare for the final assault.'),
(300081, 'The ruins hold many secrets. And many dangers.'),
(300082, 'The corruption spreads deep. Will you help us?'),
(300083, 'The Naga are relentless. We must push them back.'),
(300084, 'I hunt the hunters. Care to join the fray?'),
(300085, 'The Temple of Elune calls for champions. Will you answer?'),
(300086, 'I am but an image. The true Guardian awaits within.');

DELETE FROM `gossip_menu` WHERE `MenuID` IN (300030, 300040, 300050, 300060, 300070, 300081, 300082, 300083, 300084, 300085, 300086);
INSERT INTO `gossip_menu` (`MenuID`, `TextID`) VALUES
(300030, 300030), (300040, 300040), (300050, 300050), (300060, 300060), (300070, 300070), 
(300081, 300081), (300082, 300082), (300083, 300083), (300084, 300084), (300085, 300085), (300086, 300086);


-- =========================================================================
-- SECTION 9: Phase 4 Expansion - Secondary Quest Givers (Zones 4-8)
-- =========================================================================

DELETE FROM `creature_template` WHERE `entry` IN (300031, 300041, 300051, 300061, 300071);
INSERT INTO `creature_template` (`entry`, `name`, `subname`, `minlevel`, `maxlevel`, `faction`, `npcflag`, `scale`, `rank`, `unit_class`) VALUES
(300031, 'Engineer Whizzbang', 'Exploration Team', 35, 35, 35, 3, 1.0, 0, 1),    -- Zone 4 (Goblin)
(300041, 'Earthcaller Ryga', 'Earthen Ring', 45, 45, 35, 3, 1.0, 0, 1),        -- Zone 5 (Tauren)
(300051, 'Vindicator Boros', 'Hand of Argus', 55, 55, 35, 3, 1.0, 0, 1),       -- Zone 6 (Draenei)
(300061, 'Ambassador Caelestrasz', 'Cenarion Emissary', 65, 65, 35, 3, 1.0, 0, 1), -- Zone 7 (Night Elf)
(300071, 'Nexus-Prince Haramad', 'Consortium', 75, 75, 35, 3, 1.0, 0, 1);       -- Zone 8 (Ethereal)

DELETE FROM `creature_template_model` WHERE `CreatureID` IN (300031, 300041, 300051, 300061, 300071);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(300031, 0, 7114, 1.0, 1.0, 0),    -- Engineer Whizzbang (Goblin Male)
(300041, 0, 20585, 1.0, 1.0, 0),   -- Earthcaller Ryga (Tauren Female)
(300051, 0, 17565, 1.0, 1.0, 0),   -- Vindicator Boros (Draenei Male Vindicator)
(300061, 0, 20366, 1.0, 1.0, 0),   -- Ambassador Caelestrasz (Night Elf Male)
(300071, 0, 18888, 1.0, 1.0, 0);   -- Nexus-Prince Haramad (Ethereal)

-- End of Script



