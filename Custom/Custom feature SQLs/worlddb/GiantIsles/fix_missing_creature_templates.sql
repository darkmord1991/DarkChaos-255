-- ============================================================================
-- FIX: Missing creature_template entries across Giant Isles feature files
-- ============================================================================
-- Root cause: giant_isles_creatures.sql uses broad DELETE BETWEEN ranges that
-- wipe entries owned by sibling files when re-applied:
--   Line 23:  DELETE creature_template       BETWEEN 400000-400999
--   Line 24:  DELETE creature_template       BETWEEN 401000-401999
--   Line 422: DELETE creature_template_model BETWEEN 400000-400999
--   Line 847: DELETE creature_template_model BETWEEN 401000-401999
--   Line 1060: DELETE creature_equip_template BETWEEN 400000-401999
--
-- Apply this file ONCE to restore the current DB to a consistent state.
-- The sibling source files have also been patched to exclude these ranges
-- so the problem does not recur on the next re-run of giant_isles_creatures.sql.
-- ============================================================================

-- ============================================================================
-- 1. Giant Water Monster boss + add (400350, 400351)
--    Source: giant_water_monster.sql / fix_giant_isles_scripts.sql
-- ============================================================================
DELETE FROM `creature_template` WHERE `entry` IN (400350, 400351);
INSERT INTO `creature_template`
    (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`,
     `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`,
     `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`,
     `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`,
     `rank`, `dmgschool`, `DamageModifier`,
     `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`,
     `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`,
     `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`,
     `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`,
     `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`,
     `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`,
     `flags_extra`, `ScriptName`, `VerifiedBuild`)
VALUES
(400350, 0, 0, 0, 0, 0, 'Ancient Terror', 'Giant Isles Boss', '', 0,
 83, 83, 2, 14, 0,
 1, 1.14286, 1, 1, 20,
 3, 0, 5,
 2000, 2000, 1, 1,
 1, 0, 0, 0, 0, 0, 0,
 0, 0, 0, 0, 0,
 0, 0, '', 0, 1,
 100, 1, 1, 1,
 0, 0, 1, 0,
 0, 'npc_giant_water_monster', 0),
(400351, 0, 0, 0, 0, 0, 'Corrupted Elemental', 'Minion of the Deep', '', 0,
 81, 81, 0, 14, 0,
 1, 1.14286, 1, 1, 20,
 1, 0, 1,
 2000, 2000, 1, 1,
 1, 0, 0, 0, 0, 0, 0,
 0, 0, 0, 0, 0,
 0, 0, '', 0, 1,
 10, 1, 1, 1,
 0, 0, 1, 0,
 0, 'npc_corrupted_elemental', 0);

DELETE FROM `creature_template_model` WHERE `CreatureID` IN (400350, 400351);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(400350, 0, 29487, 3.0, 1.0, 0),
(400351, 0, 17203, 1.0, 1.0, 0);

DELETE FROM `creature_template_movement` WHERE `CreatureId` IN (400350, 400351);
INSERT INTO `creature_template_movement` (`CreatureId`, `Ground`, `Swim`, `Flight`, `Rooted`) VALUES
(400350, 1, 1, 0, 0),
(400351, 1, 1, 0, 0);

-- ============================================================================
-- 2. Hydra boss Vorath the Drowned (400360)
--    Source: giant_isles_hydra_drum.sql
-- ============================================================================
DELETE FROM `creature_template` WHERE `entry` = 400360;
INSERT INTO `creature_template`
    (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`,
     `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`,
     `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`,
     `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`,
     `rank`, `dmgschool`, `DamageModifier`,
     `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`,
     `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`,
     `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`,
     `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`,
     `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`,
     `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`,
     `flags_extra`, `ScriptName`, `VerifiedBuild`)
VALUES
(400360, 0, 0, 0, 0, 0, 'Vorath the Drowned', 'Ancient Hydra', '', 0,
 83, 83, 2, 14, 0,
 1, 1.14286, 1, 1, 20,
 3, 0, 8,
 2000, 2000, 1, 1,
 1, 0, 2048, 0, 0, 1, 0,
 0, 0, 0, 0, 0,
 5000, 8000, 'SmartAI', 0, 1,
 150, 1, 2, 1,
 0, 0, 1, 0,
 0, '', 12340);

DELETE FROM `creature_template_model` WHERE `CreatureID` = 400360;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(400360, 0, 500008, 1, 1, 12340);

-- ============================================================================
-- 3. Temple of Atal'Hakkar clone — trash, sub-bosses, bosses, questgivers
--    (400500-400527) — Source: temple_atal_hakkar_clone.sql
-- ============================================================================
DELETE FROM `creature_template` WHERE `entry` BETWEEN 400500 AND 400527;
INSERT INTO `creature_template`
    (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,
     `KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,
     `minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,
     `speed_walk`,`speed_run`,`speed_swim`,`speed_flight`,`detection_range`,
     `rank`,`dmgschool`,`DamageModifier`,
     `BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,
     `unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`type`,`type_flags`,
     `lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,
     `mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,
     `HealthModifier`,`ManaModifier`,`ArmorModifier`,`ExperienceModifier`,
     `RacialLeader`,`movementId`,`RegenHealth`,`CreatureImmunitiesId`,
     `flags_extra`,`ScriptName`,`VerifiedBuild`)
VALUES
-- Trash mobs (400500-400505)
(400500,0,0,0,0,0,'Awakened Atal\'ai Warrior',NULL,NULL,0,80,80,2,16,0,1.2,1.28571,1.0,1.0,20.0,0,0,5.0,2000,2000,1,1,1,32832,2048,0,0,7,0,400500,400500,0,0,0,600,1000,'SmartAI',1,1,14,1,1.4,1,0,0,1,0,0,'',12340),
(400501,0,0,0,0,0,'Awakened Atal\'ai Witch Doctor',NULL,NULL,0,80,80,2,16,0,1.2,1.14286,1.0,1.0,20.0,0,0,4.5,2000,2000,1,1,2,32832,2048,0,0,7,0,400501,400501,0,0,0,600,1000,'SmartAI',1,1,12,5,1.2,1,0,0,1,0,0,'',12340),
(400502,0,0,0,0,0,'Risen Atal\'ai Priest',NULL,NULL,0,81,81,2,16,0,1.2,1.14286,1.0,1.0,20.0,1,0,6.0,2000,2000,1,1,2,32832,2048,0,0,6,0,400502,400502,0,0,0,700,1100,'SmartAI',1,1,20,8,1.3,1,0,0,1,0,128,'',12340),
(400503,0,0,0,0,0,'Atal\'ai Boneguard',NULL,NULL,0,80,80,2,16,0,1.2,1.28571,1.0,1.0,20.0,0,0,5.0,2000,2000,1,1,1,32832,2048,0,0,6,0,400503,0,0,0,0,500,900,'SmartAI',1,1,13,1,1.5,1,0,0,1,0,0,'',12340),
(400504,0,0,0,0,0,'Atal\'ai Soulflayer',NULL,NULL,0,81,81,2,16,0,1.4,1.42857,1.0,1.0,20.0,1,0,6.5,1800,2000,1,1,1,32832,2048,0,0,7,0,400504,400504,0,0,0,700,1200,'SmartAI',1,1,18,1,1.3,1,0,0,1,0,128,'',12340),
(400505,0,0,0,0,0,'Hakkar\'s Devotee',NULL,NULL,0,80,80,2,16,0,1.0,1.14286,1.0,1.0,20.0,0,0,4.0,2000,2000,1,1,2,32832,2048,0,0,7,0,400505,400505,0,0,0,500,800,'SmartAI',1,1,11,5,1.2,1,0,0,1,0,0,'',12340),
-- Sub-bosses / Four Bloodseekers (400510-400513)
(400510,0,0,0,0,0,'Zul\'kar the Flayer','Bloodseeker',NULL,0,81,81,2,37,0,1.2,1.28571,1.0,1.0,20.0,1,0,9.0,1800,2000,1,1,1,32832,2048,0,0,7,76,400510,400510,0,0,0,1000,1600,'SmartAI',1,1,28,1,1.5,1,0,0,1,0,128,'',12340),
(400511,0,0,0,0,0,'Seer Mazra','Bloodseeker',NULL,0,81,81,2,37,0,1.0,1.14286,1.0,1.0,20.0,1,0,8.5,2000,2000,1,1,2,32832,2048,0,0,7,76,400511,400511,0,0,0,1000,1600,'SmartAI',1,1,25,8,1.3,1,0,0,1,0,128,'',12340),
(400512,0,0,0,0,0,'Bone Weaver Zolo','Bloodseeker',NULL,0,81,81,2,37,0,1.0,1.14286,1.0,1.0,20.0,1,0,8.0,2000,2000,1,1,2,32832,2048,0,0,7,76,400512,400512,0,0,0,1000,1600,'SmartAI',1,1,26,8,1.3,1,0,0,1,0,128,'',12340),
(400513,0,0,0,0,0,'Soul Raker Mijan','Bloodseeker',NULL,0,81,81,2,37,0,1.3,1.42857,1.0,1.0,20.0,1,0,9.0,1800,2000,1,1,1,32832,2048,0,0,7,76,400513,400513,0,0,0,1000,1600,'SmartAI',1,1,27,1,1.4,1,0,0,1,0,128,'',12340),
-- Main bosses (400520-400523)
(400520,0,0,0,0,0,'Atal\'alarion the Eternal','Guardian of the Idol',NULL,0,82,82,2,37,0,0.666668,1.14286,1.0,1.0,20.0,2,0,14.0,3000,2000,1,1,1,32832,2048,0,0,7,76,400520,400520,0,0,0,4000,6000,'SmartAI',1,1,70,1,2.0,2,0,0,1,0,128,'',12340),
(400521,0,0,0,0,0,'Jammal\'an the Eternal','Eternal Prophet',NULL,0,83,83,2,37,0,1.0,1.14286,1.0,1.0,20.0,2,0,16.0,2000,2000,1,1,2,320,2048,0,0,7,76,400521,400521,0,0,0,5000,8000,'SmartAI',1,1,90,6,1.8,2,0,0,1,0,128,'',12340),
(400522,0,0,0,0,0,'Reawakened Avatar of Hakkar','Blood God',NULL,0,83,83,2,16,0,4.28,1.14286,1.0,1.0,20.0,3,0,35.0,2000,2000,1,1,1,64,2048,8,0,10,76,400522,0,0,0,0,20000,30000,'SmartAI',0,1,400,1,2.5,3,0,0,1,0,129,'',12340),
(400523,0,0,0,0,0,'Ancient Shade of Eranikus','Nightmare Wyrm',NULL,0,82,82,2,50,0,1.0,1.42857,1.0,1.0,20.0,2,0,14.0,2000,2000,1,1,1,832,2048,0,0,2,76,400523,0,400523,0,0,4000,7000,'SmartAI',1,1,85,1,1.8,2,0,0,1,0,130,'',12340),
-- Quest NPCs (400525-400527)
-- 400525: ScriptName set directly to match the UPDATE in giant_isles_hydra_drum.sql
(400525,0,0,0,0,0,'Scholar Zal\'ira','Zandalari Historian','Speak',0,80,80,2,35,3,1.0,1.14286,1.0,1.0,20.0,0,0,1.0,2000,2000,1,1,1,768,2048,0,0,7,0,0,0,0,0,0,0,0,'',0,1,10,1,1,1,0,0,1,0,2,'npc_giant_isles_questgiver',12340),
(400526,0,0,0,0,0,'Sentinel Liriel','Alliance Warden','Speak',0,80,80,2,12,3,1.0,1.14286,1.0,1.0,20.0,0,0,1.0,2000,2000,1,1,1,768,2048,0,0,7,0,0,0,0,0,0,0,0,'',0,1,10,1,1,1,0,0,1,0,2,'',12340),
(400527,0,0,0,0,0,'Shadow Priest Mokra','Horde Shadow Agent','Speak',0,80,80,2,29,3,1.0,1.14286,1.0,1.0,20.0,0,0,1.0,2000,2000,1,1,1,768,2048,0,0,7,0,0,0,0,0,0,0,0,'',0,1,10,1,1,1,0,0,1,0,2,'',12340);

-- Models for temple entries (copy display IDs from original Atal'Hakkar creatures)
DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN 400500 AND 400527;
INSERT INTO `creature_template_model` (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT 400500,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,12340 FROM `creature_template_model` WHERE `CreatureID`=5256 LIMIT 1;
INSERT INTO `creature_template_model` (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT 400501,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,12340 FROM `creature_template_model` WHERE `CreatureID`=5259 LIMIT 1;
INSERT INTO `creature_template_model` (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT 400502,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,12340 FROM `creature_template_model` WHERE `CreatureID`=5273 LIMIT 1;
INSERT INTO `creature_template_model` (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT 400503,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,12340 FROM `creature_template_model` WHERE `CreatureID`=5267 LIMIT 1;
INSERT INTO `creature_template_model` (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT 400504,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,12340 FROM `creature_template_model` WHERE `CreatureID`=5270 LIMIT 1;
INSERT INTO `creature_template_model` (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT 400505,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,12340 FROM `creature_template_model` WHERE `CreatureID`=5263 LIMIT 1;
INSERT INTO `creature_template_model` (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT 400510,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,12340 FROM `creature_template_model` WHERE `CreatureID`=5713 LIMIT 1;
INSERT INTO `creature_template_model` (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT 400511,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,12340 FROM `creature_template_model` WHERE `CreatureID`=5715 LIMIT 1;
INSERT INTO `creature_template_model` (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT 400512,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,12340 FROM `creature_template_model` WHERE `CreatureID`=5716 LIMIT 1;
INSERT INTO `creature_template_model` (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT 400513,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,12340 FROM `creature_template_model` WHERE `CreatureID`=5717 LIMIT 1;
INSERT INTO `creature_template_model` (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT 400520,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,12340 FROM `creature_template_model` WHERE `CreatureID`=8580 LIMIT 1;
INSERT INTO `creature_template_model` (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT 400521,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,12340 FROM `creature_template_model` WHERE `CreatureID`=5710 LIMIT 1;
INSERT INTO `creature_template_model` (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT 400522,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,12340 FROM `creature_template_model` WHERE `CreatureID`=8443 LIMIT 1;
INSERT INTO `creature_template_model` (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT 400523,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,12340 FROM `creature_template_model` WHERE `CreatureID`=5709 LIMIT 1;
-- Scholar Zal'ira borrows the Elder Zul'jin (400200) appearance
INSERT INTO `creature_template_model` (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT 400525,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,12340 FROM `creature_template_model` WHERE `CreatureID`=400200 LIMIT 1;
INSERT INTO `creature_template_model` (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT 400526,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,12340 FROM `creature_template_model` WHERE `CreatureID`=2155 LIMIT 1;
INSERT INTO `creature_template_model` (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT 400527,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,12340 FROM `creature_template_model` WHERE `CreatureID`=660 LIMIT 1;

-- ============================================================================
-- 4. Fishing area NPCs (401119-401123)
--    Source: giant_isles_fishing.sql
-- ============================================================================
DELETE FROM `creature_template` WHERE `entry` IN (401119, 401120, 401121, 401122, 401123);
INSERT INTO `creature_template`
    (`entry`, `name`, `subname`, `gossip_menu_id`, `minlevel`, `maxlevel`,
     `faction`, `npcflag`, `speed_walk`, `speed_run`, `rank`, `unit_class`,
     `unit_flags`, `RegenHealth`, `ScriptName`, `VerifiedBuild`)
VALUES
(401119, 'Grak''zar',           'Ancient Cook',           400119, 80, 80, 35,   1, 1.0, 1.14286, 0, 1, 0, 1, 'npc_giant_isles_primal_cook', 12340),
(401120, 'Angler Tideborn',     'Fishing Trainer',         400130, 80, 80, 35,  17, 1.0, 1.14286, 0, 1, 0, 1, '',                            12340),
(401121, 'Tide-Watcher Mazu',   'Fishing Daily Quests',    400131, 80, 80, 35,   3, 1.0, 1.14286, 0, 1, 0, 1, '',                            12340),
(401122, 'Bait Keeper Ruk''lo', 'Fishing Supplies',        400132, 80, 80, 35, 129, 1.0, 1.14286, 0, 1, 0, 1, '',                            12340),
(401123, 'Primal Fisher',       NULL,                           0, 80, 80, 35,   0, 1.0, 1.14286, 0, 1, 0, 1, '',                            12340);

DELETE FROM `creature_template_model` WHERE `CreatureID` IN (401119, 401120, 401121, 401122, 401123);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`) VALUES
(401119, 0, 4259, 1.0, 1.0),
(401120, 0, 2095, 1.0, 1.0),
(401121, 0, 5444, 1.0, 1.0),
(401122, 0, 4259, 1.0, 1.0),
(401123, 0, 2095, 1.0, 1.0);

DELETE FROM `creature_equip_template` WHERE `CreatureID` IN (401120, 401121, 401122, 401123);
INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`) VALUES
(401120, 1,  6256, 0, 0, 12340),
(401121, 1, 12584, 0, 0, 12340),
(401122, 1,     0, 0, 0, 12340),
(401123, 1,  6256, 0, 0, 12340);

-- ============================================================================
-- 5. Quest fixes
-- ============================================================================

-- 5a. Fishing daily quests 83100-83102
--     ZoneOrSort=-101 is the Fishing sort category; the server expects
--     RequiredSkillID=356 in quest_template_addon to match. Set it with
--     RequiredSkillPoints=0 so no minimum skill is enforced (the fishing-loot
--     table already gates the actual fish behind 375 skill).
UPDATE `quest_template_addon` SET `RequiredSkillID` = 356 WHERE `ID` IN (83100, 83101, 83102);

-- 5b. Daily dungeon quests 700101-700104
--     Flags=0x1000 marks them as daily but SpecialFlags must also carry bit 1
--     (repeatable) for the server's quest system to recognise them as
--     repeatable. Without this the server logs "not marked as repeatable in
--     SpecialFlags, added" on every startup.
DELETE FROM `quest_template_addon` WHERE `ID` IN (700101, 700102, 700103, 700104);
INSERT INTO `quest_template_addon`
    (`ID`, `MaxLevel`, `AllowableClasses`, `SourceSpellID`, `PrevQuestID`, `NextQuestID`,
     `ExclusiveGroup`, `BreadcrumbForQuestId`, `RewardMailTemplateID`, `RewardMailDelay`,
     `RequiredSkillID`, `RequiredSkillPoints`,
     `RequiredMinRepFaction`, `RequiredMaxRepFaction`,
     `RequiredMinRepValue`, `RequiredMaxRepValue`,
     `ProvidedItemCount`, `SpecialFlags`)
VALUES
(700101, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3),
(700102, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3),
(700103, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3),
(700104, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3);
