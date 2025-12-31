-- ============================================================================
-- Giant Isles: Cave / Dungeon Mob Pack (400270-400276)
-- Standalone install file for the cave/dungeon creature templates.
-- Includes:
-- - creature_template / creature_template_model / creature_template_addon
-- - creature_equip_template
-- - smart_scripts (SmartAI)
--
-- Notes:
-- - This file does NOT add any `creature` spawns. After importing, you still need
--   to place spawns (or add them in a separate spawn SQL) for these NPCs to
--   appear in-game.
-- - Equipment is applied per-spawn via `creature`.`equipment_id`.
-- - Spell IDs used by SmartAI are common WotLK spells:
--   Shadow Bolt (9613), Hex (11641), Thunder Clap (8078), Shield Slam (8242), Rend (13443)
-- ============================================================================

-- Templates
DELETE FROM `creature_template` WHERE `entry` BETWEEN 400270 AND 400276;
DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN 400270 AND 400276;
DELETE FROM `creature_template_addon` WHERE `entry` BETWEEN 400270 AND 400276;

INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400270,0,0,0,0,0,'Zandalari Cave Stalker',NULL,NULL,0,80,80,2,16,0,1.3,1.42857,1.0,0,0,1800,2000,1,1,1,32832,2048,0,0,7,0,0,0,0,0,0,650,1100,'SmartAI',1,1,12,1,1.2,5.0,1,0,0,1,0,0,0,'',12340),
(400271,0,0,0,0,0,'Zandalari Cave Hexxer',NULL,NULL,0,80,80,2,16,0,1.2,1.14286,1.0,0,0,2000,2000,1,1,2,32832,2048,0,0,7,0,0,0,0,0,0,650,1100,'SmartAI',1,1,11,6,1.0,4.8,1,0,0,1,0,0,0,'',12340),
(400272,0,0,0,0,0,'Zandalari Boneguard',NULL,NULL,0,81,81,2,16,0,1.4,1.42857,1.1,0,0,1800,2000,1,1,1,32832,2048,0,0,7,76,0,0,0,0,0,900,1400,'SmartAI',1,1,18,1,1.4,6.0,1,0,0,1,0,0,128,'',12340),
(400273,0,0,0,0,0,'Cavebone Ravasaur',NULL,NULL,0,80,80,2,14,0,1.8,1.42857,1.05,0,0,1500,2000,1,1,1,32832,2048,0,37,1,0,0,0,0,0,0,600,1000,'SmartAI',1,1,14,1,1.0,5.0,1,0,0,1,0,0,0,'',12340),
(400274,0,0,0,0,0,'Seeping Cave Pterrordax',NULL,NULL,0,80,80,2,14,0,1.6,1.14286,1.0,0,0,2000,2000,1,1,1,32832,2048,0,0,1,0,0,0,0,0,0,550,900,'SmartAI',1,1,14,1,1.0,4.5,1,0,0,1,0,0,0,'',12340),
(400275,0,0,0,0,0,'Krag\'zul the Bone Collector','Rare',NULL,0,82,82,2,16,0,1.4,1.42857,1.2,2,0,1800,2000,1,1,1,32832,2048,0,0,7,76,0,0,0,0,0,3500,5500,'SmartAI',1,1,70,1,2.2,12.0,2,0,0,1,617299967,0,128,'',12340),
(400276,0,0,0,0,0,'High Ritualist Zor\'kesh','Mini Boss',NULL,0,82,82,2,16,0,1.3,1.42857,1.35,2,0,2000,2000,1,1,2,32832,2048,0,0,7,76,0,0,0,0,0,4500,7000,'SmartAI',1,1,95,20,2.5,14.0,2,0,0,1,617299967,0,128,'',12340);

INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(400270, 0, 11288, 1.0, 1, 12340),
(400271, 0, 11295, 1.0, 1, 12340),
(400272, 0, 11293, 1.1, 1, 12340),
(400273, 0, 5290, 1.05, 1, 12340),
(400274, 0, 8411, 1.0, 1, 12340),
(400275, 0, 11293, 1.2, 1, 12340),
(400276, 0, 11295, 1.35, 1, 12340);

INSERT INTO `creature_template_addon` (`entry`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `visibilityDistanceType`, `auras`) VALUES
(400270, 0, 0, 0, 0, 0, 3, '1784'),
(400271, 0, 0, 0, 0, 0, 3, ''),
(400272, 0, 0, 0, 0, 0, 3, ''),
(400273, 0, 0, 0, 0, 0, 3, '28126'),
(400274, 0, 0, 0, 0, 0, 3, '28126'),
(400275, 0, 0, 0, 0, 0, 4, '28126'),
(400276, 0, 0, 0, 0, 0, 4, '28126');

-- Equipment (spawn uses creature.equipment_id)
DELETE FROM `creature_equip_template` WHERE `CreatureID` BETWEEN 400270 AND 400276;
INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`) VALUES
(400270, 1, 12748, 0, 0, 12340),
(400271, 1, 5598, 0, 0, 12340),
(400272, 1, 12749, 12651, 0, 12340),
(400273, 1, 0, 0, 0, 12340),
(400274, 1, 0, 0, 0, 12340),
(400275, 1, 13160, 0, 0, 12340),
(400276, 1, 12584, 0, 0, 12340);

-- SmartAI
UPDATE `creature_template` SET `AIName` = 'SmartAI' WHERE `entry` BETWEEN 400270 AND 400276;
DELETE FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` BETWEEN 400270 AND 400276;
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
-- 400270: Zandalari Cave Stalker
(400270, 0, 0, 0, 0, 0, 100, 0, 5000, 7000, 12000, 15000, 0, 0, 11, 13443, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Zandalari Cave Stalker - In Combat - Cast \'Rend\''),

-- 400271: Zandalari Cave Hexxer
(400271, 0, 0, 0, 0, 0, 100, 0, 2000, 3000, 3000, 4000, 0, 0, 11, 9613, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Zandalari Cave Hexxer - In Combat - Cast \'Shadow Bolt\''),
(400271, 0, 1, 0, 0, 0, 100, 0, 9000, 14000, 20000, 30000, 0, 0, 11, 11641, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Zandalari Cave Hexxer - In Combat - Cast \'Hex\''),

-- 400272: Zandalari Boneguard
(400272, 0, 0, 0, 0, 0, 100, 0, 4000, 6000, 7000, 9000, 0, 0, 11, 8242, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Zandalari Boneguard - In Combat - Cast \'Shield Slam\''),
(400272, 0, 1, 0, 0, 0, 100, 0, 7000, 10000, 12000, 15000, 0, 0, 11, 8078, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Zandalari Boneguard - In Combat - Cast \'Thunder Clap\''),

-- 400273: Cavebone Ravasaur
(400273, 0, 0, 0, 0, 0, 100, 0, 5000, 7000, 12000, 15000, 0, 0, 11, 13443, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Cavebone Ravasaur - In Combat - Cast \'Rend\''),

-- 400274: Seeping Cave Pterrordax
(400274, 0, 0, 0, 0, 0, 100, 0, 5000, 7000, 12000, 15000, 0, 0, 11, 13443, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Seeping Cave Pterrordax - In Combat - Cast \'Rend\''),

-- 400275: Krag\'zul the Bone Collector (Rare)
(400275, 0, 0, 0, 0, 0, 100, 0, 3500, 5500, 6500, 9000, 0, 0, 11, 8242, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Krag\'zul the Bone Collector - In Combat - Cast \'Shield Slam\''),
(400275, 0, 1, 0, 0, 0, 100, 0, 6500, 9500, 11000, 15000, 0, 0, 11, 8078, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Krag\'zul the Bone Collector - In Combat - Cast \'Thunder Clap\''),
(400275, 0, 2, 0, 0, 0, 100, 0, 5500, 8000, 12000, 16000, 0, 0, 11, 13443, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Krag\'zul the Bone Collector - In Combat - Cast \'Rend\''),

-- 400276: High Ritualist Zor\'kesh (Mini Boss)
(400276, 0, 0, 0, 0, 0, 100, 0, 2000, 3000, 3000, 4000, 0, 0, 11, 9613, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'High Ritualist Zor\'kesh - In Combat - Cast \'Shadow Bolt\''),
(400276, 0, 1, 0, 0, 0, 100, 0, 9000, 14000, 22000, 30000, 0, 0, 11, 11641, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'High Ritualist Zor\'kesh - In Combat - Cast \'Hex\'');
