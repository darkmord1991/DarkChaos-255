-- ============================================================================
-- GIANT ISLES - CREATURE TEMPLATES
-- ============================================================================
-- Zone: Giant Isles (Port from Pandaria Isle of Giants)
-- Map ID: 1405
-- Entry Range: 400000-400999 (Creatures), 401000-401999 (NPCs/Guards)
-- ============================================================================
-- Level Guidelines (Updated Dec 2025):
-- - Normal NPCs/Creatures: Level 80
-- - Elite NPCs/Creatures: Level 81 (silver dragon)
-- - Bosses/Rare Elites: Level 82 (gold dragon)
-- ============================================================================
-- Zone Sectors:
-- 1. Warden's Landing (Southern Beach) - Safe Hub
-- 2. Raptor Beaches (Eastern Coastline)
-- 3. Direhorn Valley (Western Grasslands)
-- 4. Devilsaur Heights (Central-North Volcanic)
-- 5. Zandalari Warcamp (Southeast Peninsula)
-- 6. The Chaos Rift (Central Caldera)
-- 7. The King's Plateau (Northwest Mountains)
-- 8. The Bone Pit (Northeast)
-- ============================================================================

-- ============================================================================
-- CLEANUP - Delete existing entries if re-running
-- ============================================================================
DELETE FROM `creature_template` WHERE `entry` BETWEEN 400000 AND 400999;
DELETE FROM `creature_template` WHERE `entry` BETWEEN 401000 AND 401999;
DELETE FROM `gossip_menu` WHERE `MenuId` BETWEEN 400000 AND 400199;
DELETE FROM `gossip_menu_option` WHERE `MenuId` BETWEEN 400000 AND 400199;
DELETE FROM `npc_text` WHERE `ID` BETWEEN 400000 AND 400199;

-- ============================================================================
-- ZONE DINOSAURS - Basic mobs (400000-400049)
-- Level 80 normal, Level 81 elite variants
-- ============================================================================

-- Chaos Devilsaurs (from Devilsaur 6498-6500) - Entry 400000-400002
-- These are the apex predators of Giant Isles
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400000,0,0,0,0,0,'Chaos Devilsaur',NULL,NULL,0,80,80,2,14,0,2.4,1.71429,1.2,0,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,76,400000,0,0,0,0,1500,2500,'SmartAI',1,1,25,1,1.5,8,1,0,0,1,0,0,0,'',12340),
(400001,0,0,0,0,0,'Ironhide Chaos Devilsaur',NULL,NULL,0,81,81,2,14,0,2.4,1.71429,1.3,1,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,76,400001,0,0,0,0,2000,3000,'SmartAI',1,1,35,1,2.0,10,1,0,0,1,0,0,0,'',12340),
(400002,0,0,0,0,0,'Tyrant Chaos Devilsaur',NULL,NULL,0,81,81,2,14,0,2.4,1.71429,1.4,1,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,76,400002,0,0,0,0,2500,4000,'SmartAI',1,1,50,1,2.5,12,1,0,0,1,0,0,0,'',12340);

-- Primal Stegodons (from Stegodon 6501-6504) - Entry 400003-400006
-- Heavily armored beasts that roam in herds
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400003,0,0,0,0,0,'Primal Stegodon',NULL,NULL,0,80,80,2,14,0,1.6,1.14286,1.1,0,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,0,400003,0,0,0,0,800,1200,'SmartAI',1,1,18,1,3.0,5,1,0,0,1,0,0,0,'',12340),
(400004,0,0,0,0,0,'Elder Stegodon',NULL,NULL,0,80,80,2,14,0,1.6,1.14286,1.2,0,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,0,400004,0,0,0,0,1000,1500,'SmartAI',1,1,22,1,3.5,6,1,0,0,1,0,0,0,'',12340),
(400005,0,0,0,0,0,'Armored Stegodon',NULL,NULL,0,81,81,2,14,0,1.6,1.14286,1.25,1,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,76,400005,0,0,0,0,1200,1800,'SmartAI',1,1,28,1,4.0,7,1,0,0,1,0,0,0,'',12340),
(400006,0,0,0,0,0,'Ancient Stegodon',NULL,NULL,0,81,81,2,14,0,1.6,1.14286,1.35,1,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,76,400006,0,0,0,0,1500,2200,'SmartAI',1,1,35,1,4.5,8,1,0,0,1,0,0,0,'',12340);

-- Chaos Raptors (from Ravasaur 6505-6508) - Entry 400007-400010
-- Fast and deadly pack hunters
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400007,0,0,0,0,0,'Chaos Raptor',NULL,NULL,0,80,80,2,14,0,1.8,1.42857,1,0,0,1500,2000,1,1,1,32832,2048,0,37,0,0,0,0,1,0,400007,0,0,0,0,500,800,'SmartAI',1,1,12,1,1,4,1,0,0,1,0,0,0,'',12340),
(400008,0,0,0,0,0,'Chaos Raptor Runner',NULL,NULL,0,80,80,2,14,0,2.0,1.71429,1,0,0,1500,2000,1,1,1,32832,2048,0,37,0,0,0,0,1,0,400008,0,0,0,0,600,950,'SmartAI',1,1,14,1,1,5,1,0,0,1,0,0,0,'',12340),
(400009,0,0,0,0,0,'Chaos Raptor Hunter',NULL,NULL,0,80,80,2,14,0,1.8,1.42857,1.05,0,0,1500,2000,1,1,1,32832,2048,0,37,0,0,0,0,1,0,400009,0,0,0,0,700,1100,'SmartAI',1,1,16,1,1.2,5.5,1,0,0,1,0,0,0,'',12340),
(400010,0,0,0,0,0,'Venomhide Chaos Raptor',NULL,NULL,0,81,81,2,14,0,1.8,1.42857,1.1,1,0,1500,2000,1,1,1,32832,2048,0,37,0,0,0,0,1,76,400010,0,0,0,0,800,1300,'SmartAI',1,1,20,1,1.5,6,1,0,0,1,0,0,0,'',12340);

-- Chaos Pterrordax (from Pterrordax 9165-9167) - Entry 400011-400013
-- Flying terrors that patrol the skies
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400011,0,0,0,0,0,'Fledgling Chaos Pterrordax',NULL,NULL,0,80,80,2,14,0,1.6,1.14286,0.9,0,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,0,400011,0,0,0,0,400,700,'SmartAI',1,1,10,1,0.8,3.5,1,0,0,1,0,0,0,'',12340),
(400012,0,0,0,0,0,'Chaos Pterrordax',NULL,NULL,0,80,80,2,14,0,1.6,1.14286,1,0,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,0,400012,0,0,0,0,550,900,'SmartAI',1,1,14,1,1,4.5,1,0,0,1,0,0,0,'',12340),
(400013,0,0,0,0,0,'Frenzied Chaos Pterrordax',NULL,NULL,0,81,81,2,14,0,1.6,1.14286,1.1,1,0,1800,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,76,400013,0,0,0,0,700,1100,'SmartAI',1,1,18,1,1.2,5.5,1,0,0,1,0,0,0,'',12340);

-- Primal Diemetradons (from Diemetradon 9162-9164) - Entry 400014-400016
-- Sail-backed reptiles that hunt near water
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400014,0,0,0,0,0,'Young Primal Diemetradon',NULL,NULL,0,80,80,2,14,0,1.6,1.14286,0.85,0,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,0,400014,0,0,0,0,400,650,'SmartAI',1,1,11,1,1,3.5,1,0,0,1,0,0,0,'',12340),
(400015,0,0,0,0,0,'Primal Diemetradon',NULL,NULL,0,80,80,2,14,0,1.6,1.14286,1,0,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,0,400015,0,0,0,0,500,850,'SmartAI',1,1,15,1,1.2,4.5,1,0,0,1,0,0,0,'',12340),
(400016,0,0,0,0,0,'Elder Primal Diemetradon',NULL,NULL,0,81,81,2,14,0,1.6,1.14286,1.15,1,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,76,400016,0,0,0,0,650,1000,'SmartAI',1,1,20,1,1.5,5.5,1,0,0,1,0,0,0,'',12340);

-- ============================================================================
-- ELITE DINOSAURS - Rare spawns (400050-400059)
-- All are Level 82 (Rare Elite / Boss tier)
-- ============================================================================

-- Rare Elite Dinosaurs (Static Spawns)
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400050,0,0,0,0,0,'Primal Direhorn','Rare Elite',NULL,0,82,82,2,14,0,2.2,1.71429,1.5,2,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,76,400050,0,0,0,0,5000,8000,'SmartAI',1,1,80,1,3,15,2,0,0,1,617299967,0,0,'creature_giant_isles_rare_spawn',12340),
(400051,0,0,0,0,0,'Chaos Rex','Rare Elite',NULL,0,82,82,2,14,0,2.4,1.85714,1.6,2,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,76,400051,0,0,0,0,6000,9000,'SmartAI',1,1,100,1,2.5,18,2,0,0,1,617299967,0,0,'creature_giant_isles_rare_spawn',12340),
(400052,0,0,0,0,0,'Ancient Primordial','Rare Elite',NULL,0,82,82,2,14,0,2.0,1.42857,1.8,2,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,76,400052,0,0,0,0,7000,10000,'SmartAI',1,1,120,1,4,20,2,0,0,1,617299967,0,0,'creature_giant_isles_rare_spawn',12340),
(400053,0,0,0,0,0,'Savage Stegodon Matriarch','Rare Elite',NULL,0,82,82,2,14,0,1.6,1.14286,1.5,2,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,76,400053,0,0,0,0,5500,8500,'SmartAI',1,1,90,1,5,16,2,0,0,1,617299967,0,0,'creature_giant_isles_rare_spawn',12340),
(400054,0,0,0,0,0,'Alpha Chaos Raptor','Rare Elite',NULL,0,82,82,2,14,0,2.2,1.85714,1.3,2,0,1500,2000,1,1,1,32832,2048,0,37,0,0,0,0,1,76,400054,0,0,0,0,4500,7000,'SmartAI',1,1,70,1,2,14,2,0,0,1,617299967,0,0,'creature_giant_isles_rare_spawn',12340);

-- Random Rare Spawns (Dynamically spawned by zone script) - Entry 400055-400059
-- These rares can randomly appear via the zone script with special mechanics
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400055,0,0,0,0,0,'Bonecrusher','Primal Horror',NULL,0,82,82,2,14,0,2.6,2.0,2.0,2,0,1800,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,76,400055,0,0,0,0,8000,12000,'SmartAI',1,1,150,1,3.5,22,2,0,0,1,617299967,0,0,'creature_giant_isles_rare_spawn',12340),
(400056,0,0,0,0,0,'Gorespine the Impaler','Spiked Nightmare',NULL,0,82,82,2,14,0,1.8,1.42857,1.7,2,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,76,400056,0,0,0,0,8500,13000,'SmartAI',1,1,130,1,5.5,20,2,0,0,1,617299967,0,0,'creature_giant_isles_rare_spawn',12340),
(400057,0,0,0,0,0,'Venomfang','Toxic Terror',NULL,0,82,82,2,14,0,2.4,2.0,1.5,2,4,1500,2000,1,1,1,32832,2048,0,37,0,0,0,0,1,76,400057,0,0,0,0,7500,11000,'SmartAI',1,1,110,1,2.5,18,2,0,0,1,617299967,0,0,'creature_giant_isles_rare_spawn',12340),
(400058,0,0,0,0,0,'Skyscreamer','Chaos Windlord',NULL,0,82,82,2,14,0,2.0,1.71429,1.4,2,4,2000,2000,1,1,2,32832,2048,0,0,0,0,0,0,1,76,400058,0,0,0,0,7000,10500,'SmartAI',1,1,100,5,2,16,2,0,0,1,617299967,0,0,'creature_giant_isles_rare_spawn',12340),
(400059,0,0,0,0,0,'Gul\'rok the Cursed','Primal Witch Doctor',NULL,0,82,82,2,14,0,1.4,1.14286,1.2,2,5,2000,2000,1,1,2,32832,2048,0,0,0,0,0,0,7,76,400059,0,0,0,0,10000,15000,'SmartAI',0,1,180,10,2,25,2.5,0,0,1,617299967,0,0,'creature_giant_isles_rare_spawn',12340);

-- ============================================================================
-- WORLD BOSSES (400100-400102)
-- Level 82 (Boss rank = 3)
-- ============================================================================

-- Oondasta - The King of Dinosaurs (Based on MoP world boss)
-- Massive Devilsaur that terrorizes the island
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400100,0,0,0,0,0,'Oondasta','King of Dinosaurs','VehicleCursor',0,82,82,2,14,0,2.8,2.14286,3.0,3,0,2000,2000,1,1,1,64,2048,8,0,0,0,0,0,1,108,400100,0,0,0,0,50000,75000,'',0,1,2000,1,4,50,3,0,0,1,2147483647,0,1,'boss_oondasta',12340);

-- Thok the Bloodthirsty - The Primal Hunter
-- Savage raptor boss that hunts in packs
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400101,0,0,0,0,0,'Thok the Bloodthirsty','Primal Hunter','VehicleCursor',0,82,82,2,14,0,3.2,2.5,2.5,3,0,1500,2000,1,1,1,64,2048,8,37,0,0,0,0,1,108,400101,0,0,0,0,45000,65000,'',0,1,1800,1,3,45,3,0,0,1,2147483647,0,1,'boss_thok',12340);

-- Nalak the Storm Lord - Ancient Thunder Lizard
-- Lightning-infused Pterrordax elder
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400102,0,0,0,0,0,'Nalak the Storm Lord','Ancient Thunder Lizard','VehicleCursor',0,82,82,2,14,0,2.4,1.85714,2.8,3,4,2000,2000,1,1,2,64,2048,8,0,0,0,0,0,1,108,400102,0,0,0,0,48000,70000,'',0,1,1600,100,2.5,40,3,0,0,1,2147483647,0,1,'boss_nalak',12340);

-- ============================================================================
-- TROLL NPCS - Zandalari faction (400200-400249)
-- Level 80 for friendly NPCs
-- ============================================================================

-- Based on Zandalari models from Zul'Gurub/Zul'Aman
-- These are the expedition NPCs for the zone

-- Zandalari Quest Givers (Friendly to all)
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400200,0,0,0,0,0,'Elder Zul\'jin','Zandalari Expedition Leader','Speak',400000,80,80,2,35,3,1,1.14286,1,0,0,2000,2000,1,1,1,768,2048,0,0,0,0,0,0,7,0,0,0,0,0,0,0,0,'SmartAI',0,1,10,1,1,1,1,0,0,1,0,0,2,'',12340),
(400201,0,0,0,0,0,'Witch Doctor Tala\'jin','Zandalari Researcher','Speak',400001,80,80,2,35,3,1,1.14286,1,0,0,2000,2000,1,1,2,768,2048,0,0,0,0,0,0,7,0,0,0,0,0,0,0,0,'SmartAI',0,1,8,5,1,1,1,0,0,1,0,0,2,'',12340),
(400202,0,0,0,0,0,'Rokhan the Beast Tamer','Zandalari Beast Master','Speak',400002,80,80,2,35,3,1,1.14286,1,0,0,2000,2000,1,1,1,768,2048,0,0,0,0,0,0,7,0,0,0,0,0,0,0,0,'SmartAI',0,1,10,1,1,1,1,0,0,1,0,0,2,'',12340),
(400203,0,0,0,0,0,'Scout Zan\'do','Zandalari Scout','Speak',400003,80,80,2,35,3,1,1.14286,1,0,0,2000,2000,1,1,1,768,2048,0,0,0,0,0,0,7,0,0,0,0,0,0,0,0,'SmartAI',0,1,5,1,1,1,1,0,0,1,0,0,2,'',12340);

-- Zandalari Vendors
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400210,0,0,0,0,0,'Trader Zal\'aman','Zandalari Supplies','Speak',400010,80,80,2,35,129,1,1.14286,1,0,0,2000,2000,1,1,1,768,2048,0,0,0,0,0,0,7,0,0,0,0,0,0,0,0,'SmartAI',0,1,8,1,1,1,1,0,0,1,0,0,2,'',12340),
(400211,0,0,0,0,0,'Armsmaster Jin\'kala','Zandalari Weaponsmith','Speak',400011,80,80,2,35,131,1,1.14286,1,0,0,2000,2000,1,1,1,768,2048,0,0,0,0,0,0,7,0,0,0,0,0,0,0,0,'SmartAI',0,1,8,1,1,1,1,0,0,1,0,0,2,'',12340);

-- Zandalari Guards (Neutral but protects camp) - Level 81 Elite
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400220,0,0,0,0,0,'Zandalari Expedition Guard',NULL,NULL,0,81,81,2,35,0,1.2,1.28571,1,1,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,7,0,0,0,0,0,0,0,0,'SmartAI',1,1,25,1,2,8,1,0,0,1,0,0,0,'',12340),
(400221,0,0,0,0,0,'Zandalari Beast Handler',NULL,NULL,0,81,81,2,35,0,1.2,1.28571,1,1,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,7,0,0,0,0,0,0,0,0,'SmartAI',1,1,20,1,1.5,6,1,0,0,1,0,0,0,'',12340);

-- ============================================================================
-- HOSTILE TROLLS - Primal Enemies (400250-400274)
-- Level 80 normal, Level 81 elite, Level 82 for mini-bosses
-- ============================================================================

-- Primal Troll enemies (hostile to all)
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400250,0,0,0,0,0,'Primal Troll Warrior',NULL,NULL,0,80,80,2,16,0,1.2,1.28571,1,0,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,7,0,400250,400250,0,0,0,600,1000,'SmartAI',1,1,12,1,1.5,5,1,0,0,1,0,0,0,'',12340),
(400251,0,0,0,0,0,'Primal Troll Shadowcaster',NULL,NULL,0,80,80,2,16,0,1.2,1.14286,1,0,0,2000,2000,1,1,2,32832,2048,0,0,0,0,0,0,7,0,400251,400251,0,0,0,600,1000,'SmartAI',1,1,10,5,1,4.5,1,0,0,1,0,0,0,'',12340),
(400252,0,0,0,0,0,'Primal Troll Berserker',NULL,NULL,0,81,81,2,16,0,1.4,1.42857,1.05,1,0,1800,2000,1,1,1,32832,2048,0,0,0,0,0,0,7,0,400252,400252,0,0,0,800,1200,'SmartAI',1,1,15,1,1.2,6,1,0,0,1,0,0,0,'',12340),
(400253,0,0,0,0,0,'Primal Troll Witch Doctor',NULL,NULL,0,81,81,2,16,0,1.2,1.14286,1,1,0,2000,2000,1,1,2,32832,2048,0,0,0,0,0,0,7,0,400253,400253,0,0,0,800,1200,'SmartAI',1,1,12,8,1,5.5,1,0,0,1,0,0,0,'',12340),
(400254,0,0,0,0,0,'Primal Troll Headhunter',NULL,NULL,0,81,81,2,16,0,1.3,1.42857,1,1,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,7,0,400254,400254,0,0,0,900,1400,'SmartAI',1,1,14,1,1.3,6,1,0,0,1,0,0,0,'',12340);

-- Primal Troll Elite (mini-boss) - Level 82
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400260,0,0,0,0,0,'Warlord Gha\'tul','Primal Chieftain',NULL,0,82,82,2,16,0,1.4,1.42857,1.15,2,0,1800,2000,1,1,1,32832,2048,0,0,0,0,0,0,7,76,400260,400260,0,0,0,3000,5000,'SmartAI',1,1,60,1,2.5,12,2,0,0,1,617299967,0,0,'',12340);

-- ============================================================================
-- SPECIAL NPCS (400300-400349)
-- Level 80 for friendly/service NPCs, Level 82 for daily boss
-- ============================================================================

-- Dinosaur Trainers / Tameable beasts for hunters
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400300,0,0,0,0,0,'Spirit of the Primal',NULL,NULL,400020,80,80,2,35,1,1,1.14286,1.5,0,0,2000,2000,1,1,1,32768,2048,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,'SmartAI',0,1,50,1,1,5,1,0,0,1,0,0,2,'npc_spirit_of_primal',12340),
(400301,0,0,0,0,0,'Corrupted Direhorn Spirit','Daily Boss',NULL,0,82,82,2,14,0,2,1.71429,1.8,2,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,76,400301,0,0,0,0,4000,6000,'SmartAI',0,1,75,1,3,14,2,0,0,1,617299967,0,0,'',12340);

-- Innkeeper for the zone
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400310,0,0,0,0,0,'Bartender Zul\'tik','Zandalari Innkeeper','Interact',400030,80,80,2,35,65539,1,1.14286,1,0,0,2000,2000,1,1,1,768,2048,0,0,0,0,0,0,7,0,0,0,0,0,0,0,0,'SmartAI',0,1,8,1,1,1,1,0,0,1,0,0,2,'',12340);

-- Flightmaster
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400311,0,0,0,0,0,'Windwalker Ta\'zo','Zandalari Flight Master','Taxi',400031,80,80,2,35,8201,1,1.14286,1,0,0,2000,2000,1,1,1,768,2048,0,0,0,0,0,0,7,0,0,0,0,0,0,0,0,'SmartAI',0,1,10,1,1,1,1,0,0,1,0,0,2,'',12340);

-- ============================================================================
-- CANNON QUEST NPCs (400320-400329)
-- Daily Quest: "Sink the Zandalari Scout"
-- ============================================================================

-- Captain Harlan - Quest giver (Human sailor model)
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400320,0,0,0,0,0,'Captain Harlan','Coastal Defense','Speak',400320,80,80,2,35,3,1,1.14286,1,0,0,2000,2000,1,1,1,768,2048,0,0,0,0,0,0,7,0,0,0,0,0,0,0,0,'SmartAI',0,1,10,1,1,1,1,0,0,1,0,0,2,'npc_captain_harlan',12340);

-- Coastal Cannon - Vehicle (uses siege cannon model)
-- VehicleId 554 is the ICC Gunship Cannon vehicle seat
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400321,0,0,0,0,0,'Coastal Cannon',NULL,'VehicleCursor',0,80,80,2,35,16777216,0,0,1,0,0,2000,2000,1,1,1,33554432,2048,0,0,0,0,0,0,9,1024,0,0,0,0,554,0,0,'',0,1,100,1,1,1,0,0,0,1,0,0,2,'npc_coastal_cannon',12340);

-- Zandalari Scout Ship - Target (invisible creature with visual spell)
-- DisplayID 0 = invisible, visual from spell effects
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400322,0,0,0,0,0,'Zandalari Scout Ship',NULL,NULL,0,80,80,2,14,0,0.8,0.571429,3,0,0,2000,2000,1,1,1,33555200,2048,0,0,0,0,0,0,9,1024,0,0,0,0,0,0,0,'',0,1,50,1,1,1,0,0,0,0,617299967,0,128,'npc_zandalari_scout_ship',12340);

-- Ship Visual Trigger - For explosion effects
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400323,0,0,0,0,0,'Ship Explosion Trigger',NULL,NULL,0,80,80,2,35,0,0,0,1,0,0,2000,2000,1,1,1,33554944,2048,0,0,0,0,0,0,10,1024,0,0,0,0,0,0,0,'',0,1,1,1,1,1,0,0,0,0,0,0,128,'',12340);

-- ============================================================================
-- BOSS ADDS / SPAWN CREATURES (400400-400450)
-- ============================================================================

-- Oondasta adds
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400400,0,0,0,0,0,'Young Oondasta','Spawn of Oondasta',NULL,0,80,80,2,14,0,2.0,1.71429,1.2,1,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,'SmartAI',0,1,20,1,1.5,8,1,0,0,1,0,0,0,'npc_young_oondasta',12340);

-- Thok adds
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400401,0,0,0,0,0,'Frenzied Pack Raptor','Thok\'s Brood',NULL,0,80,80,2,14,0,2.5,2.14286,0.9,0,0,1500,2000,1,1,1,32832,2048,0,37,0,0,0,0,1,0,0,0,0,0,0,0,0,'SmartAI',0,1,8,1,1,5,1,0,0,1,0,0,0,'npc_pack_raptor',12340);

-- Nalak adds
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400402,0,0,0,0,0,'Storm Spark','Lightning Elemental',NULL,0,80,80,2,14,0,1.4,1.14286,0.8,0,4,2000,2000,1,1,2,32832,2048,0,0,0,0,0,0,4,0,0,0,0,0,0,0,0,'SmartAI',0,1,6,5,0.8,4,1,0,0,1,0,0,0,'npc_storm_spark',12340),
(400403,0,0,0,0,0,'Static Cloud','Nalak\'s Essence',NULL,0,80,80,2,14,0,0.5,0.5,1,0,4,2000,2000,1,1,2,33554432,2048,0,0,0,0,0,0,4,0,0,0,0,0,0,0,0,'SmartAI',0,1,1,1,1,1,0,0,0,0,0,0,64,'npc_static_cloud',12340);

-- ============================================================================
-- CREATURE_TEMPLATE_MODEL - Assign display models to creatures
-- ============================================================================
-- Format: (CreatureID, Idx, CreatureDisplayID, DisplayScale, Probability, VerifiedBuild)
-- Reference display IDs from existing creatures:
-- Devilsaur: 5239 (6498), 5238 (6499), 5240 (6500)
-- King Mosh: 5305 (6584)
-- Stegodon: 5241 (6501), 5287 (6502), 5288 (6503), 5289 (6504)
-- Ravasaur: 5242 (6505), 5290 (6506), 5292 (6507), 5291 (6508)
-- Pterrordax: 8410 (9165), 8411 (9166), 8412 (9167)
-- Diemetradon: 8510 (9162), 8511 (9163), 8512 (9164)
-- ============================================================================

DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN 400000 AND 400999;

INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
-- Chaos Devilsaurs (using Devilsaur models)
(400000, 0, 5239, 1.2, 1, 12340),  -- Chaos Devilsaur
(400001, 0, 5238, 1.3, 1, 12340),  -- Ironhide Chaos Devilsaur
(400002, 0, 5240, 1.4, 1, 12340),  -- Tyrant Chaos Devilsaur

-- Primal Stegodons (using Stegodon models)
(400003, 0, 5241, 1.1, 1, 12340),  -- Primal Stegodon
(400004, 0, 5287, 1.2, 1, 12340),  -- Elder Stegodon
(400005, 0, 5288, 1.25, 1, 12340), -- Armored Stegodon
(400006, 0, 5289, 1.35, 1, 12340), -- Ancient Stegodon

-- Chaos Raptors (using Ravasaur models)
(400007, 0, 5242, 1, 1, 12340),    -- Chaos Raptor
(400008, 0, 5290, 1, 1, 12340),    -- Chaos Raptor Runner
(400009, 0, 5292, 1.05, 1, 12340), -- Chaos Raptor Hunter
(400010, 0, 5291, 1.1, 1, 12340),  -- Venomhide Chaos Raptor

-- Chaos Pterrordax (using Pterrordax models)
(400011, 0, 8410, 0.9, 1, 12340),  -- Fledgling Chaos Pterrordax
(400012, 0, 8411, 1, 1, 12340),    -- Chaos Pterrordax
(400013, 0, 8412, 1.1, 1, 12340),  -- Frenzied Chaos Pterrordax

-- Primal Diemetradons (using Diemetradon models)
(400014, 0, 8510, 0.85, 1, 12340), -- Young Primal Diemetradon
(400015, 0, 8511, 1, 1, 12340),    -- Primal Diemetradon
(400016, 0, 8512, 1.15, 1, 12340), -- Elder Primal Diemetradon

-- Rare Elite Dinosaurs
(400050, 0, 5305, 1.5, 1, 12340),  -- Primal Direhorn (King Mosh model)
(400051, 0, 5240, 1.6, 1, 12340),  -- Chaos Rex (Tyrant Devilsaur)
(400052, 0, 5289, 1.8, 1, 12340),  -- Ancient Primordial (Thunderstomp Stegodon)
(400053, 0, 5288, 1.5, 1, 12340),  -- Savage Stegodon Matriarch
(400054, 0, 5291, 1.3, 1, 12340),  -- Alpha Chaos Raptor (Venomhide)

-- Random Rare Spawns (spawned dynamically by zone script)
(400055, 0, 5305, 2.0, 1, 12340),  -- Bonecrusher (massive devilsaur)
(400056, 0, 5288, 1.7, 1, 12340),  -- Gorespine the Impaler (spiked stegodon)
(400057, 0, 5291, 1.5, 1, 12340),  -- Venomfang (toxic raptor)
(400058, 0, 8412, 1.4, 1, 12340),  -- Skyscreamer (chaos pterrordax)
(400059, 0, 11288, 1.2, 1, 12340), -- Gul'rok the Cursed (witch doctor troll)

-- World Bosses (massive scale)
(400100, 0, 5305, 3.0, 1, 12340),  -- Oondasta - King Mosh model, massive
(400101, 0, 5291, 2.5, 1, 12340),  -- Thok - Large Venomhide Raptor
(400102, 0, 8412, 2.8, 1, 12340),  -- Nalak - Frenzied Pterrordax

-- Zandalari NPCs (using Zul'Aman troll models - displayID 21286 male, 21287 female)
(400200, 0, 21286, 1, 1, 12340),   -- Elder Zul'jin
(400201, 0, 21287, 1, 1, 12340),   -- Witch Doctor Tala'jin (female)
(400202, 0, 21286, 1, 1, 12340),   -- Rokhan the Beast Tamer
(400203, 0, 21286, 1, 1, 12340),   -- Scout Zan'do
(400210, 0, 21286, 1, 1, 12340),   -- Trader Zal'aman
(400211, 0, 21286, 1, 1, 12340),   -- Armsmaster Jin'kala
(400220, 0, 21286, 1, 1, 12340),   -- Zandalari Expedition Guard
(400221, 0, 21286, 1, 1, 12340),   -- Zandalari Beast Handler

-- Hostile Primal Trolls (using ZG troll models - displayID 11288)
(400250, 0, 11288, 1, 1, 12340),   -- Primal Troll Warrior
(400251, 0, 11288, 1, 1, 12340),   -- Primal Troll Shadowcaster
(400252, 0, 11288, 1.05, 1, 12340),-- Primal Troll Berserker
(400253, 0, 11288, 1, 1, 12340),   -- Primal Troll Witch Doctor
(400254, 0, 11288, 1, 1, 12340),   -- Primal Troll Headhunter
(400260, 0, 11288, 1.15, 1, 12340),-- Warlord Gha'tul

-- Special NPCs
(400300, 0, 5305, 1.5, 1, 12340),  -- Spirit of the Primal (ghostly devilsaur)
(400301, 0, 5305, 1.8, 1, 12340),  -- Corrupted Direhorn Spirit
(400310, 0, 21286, 1, 1, 12340),   -- Bartender Zul'tik
(400311, 0, 21286, 1, 1, 12340),   -- Windwalker Ta'zo

-- Cannon Quest NPCs
(400320, 0, 4422, 1, 1, 12340),    -- Captain Harlan (Human Male Sailor - DisplayID 4422)
(400321, 0, 27101, 1.5, 1, 12340), -- Coastal Cannon (Siege Cannon - DisplayID 27101)
(400322, 0, 0, 3, 1, 12340),       -- Zandalari Scout Ship (invisible - visual from spell)
(400323, 0, 11686, 1, 1, 12340),   -- Ship Explosion Trigger (invisible trigger)

-- Boss Adds
(400400, 0, 5239, 1.2, 1, 12340),  -- Young Oondasta
(400401, 0, 5290, 0.9, 1, 12340),  -- Frenzied Pack Raptor
(400402, 0, 16946, 0.8, 1, 12340), -- Storm Spark (lightning elemental)
(400403, 0, 11686, 1, 1, 12340);   -- Static Cloud (cloud visual)

-- ============================================================================
-- CREATURE_TEMPLATE_ADDON - Auras and visual effects
-- ============================================================================

DELETE FROM `creature_template_addon` WHERE `entry` BETWEEN 400000 AND 400999;

INSERT INTO `creature_template_addon` (`entry`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `visibilityDistanceType`, `auras`) VALUES
-- Chaos visual aura (28126 = Spirit Particles Purple) on elite/rare creatures
(400002, 0, 0, 0, 0, 0, 0, '28126'),   -- Tyrant Chaos Devilsaur
(400050, 0, 0, 0, 0, 0, 1, '28126'),   -- Primal Direhorn
(400051, 0, 0, 0, 0, 0, 1, '28126'),   -- Chaos Rex
(400052, 0, 0, 0, 0, 0, 1, '28126'),   -- Ancient Primordial
(400053, 0, 0, 0, 0, 0, 1, '28126'),   -- Savage Stegodon Matriarch
(400054, 0, 0, 0, 0, 0, 1, '28126'),   -- Alpha Chaos Raptor
(400055, 0, 0, 0, 0, 0, 2, '28126'),   -- Bonecrusher (random rare)
(400056, 0, 0, 0, 0, 0, 2, '28126'),   -- Gorespine (random rare)
(400057, 0, 0, 0, 0, 0, 2, '28126'),   -- Venomfang (random rare)
(400058, 0, 0, 0, 0, 0, 2, '28126'),   -- Skyscreamer (random rare)
(400059, 0, 0, 0, 0, 0, 2, '28126'),   -- Gul'rok the Cursed (random rare)
(400100, 0, 0, 0, 0, 0, 3, '28126'),   -- Oondasta (max visibility)
(400101, 0, 0, 0, 0, 0, 3, '28126'),   -- Thok (max visibility)
(400102, 0, 0, 0, 0, 0, 3, '28126'),   -- Nalak (max visibility)
(400260, 0, 0, 0, 0, 0, 1, '28126'),   -- Warlord Gha'tul
(400300, 0, 0, 0, 0, 0, 0, '10848'),   -- Spirit of the Primal (ghost aura)
(400301, 0, 0, 0, 0, 0, 1, '28126');   -- Corrupted Direhorn Spirit

-- ============================================================================
-- GUARDS AND DEFENDERS (401000-401099)
-- Level 80 normal, 81 elite, 82 rare elite
-- ============================================================================

DELETE FROM `creature_template` WHERE `entry` BETWEEN 401000 AND 401099;
INSERT INTO `creature_template` (`entry`, `name`, `subname`, `minlevel`, `maxlevel`, `faction`, `npcflag`, `rank`, `type`, `unit_class`, `unit_flags`, `BaseAttackTime`, `RangeAttackTime`, `HealthModifier`, `DamageModifier`, `ArmorModifier`, `mingold`, `maxgold`, `AIName`, `MovementType`, `ScriptName`) VALUES
-- Alliance Guards (Jurassic Expedition)
(401000, 'Primal Warden', 'Jurassic Expedition', 80, 80, 1735, 0, 0, 7, 1, 0, 2000, 2000, 2.0, 1.5, 1.0, 0, 0, 'SmartAI', 1, ''),
(401001, 'Primal Warden Sergeant', 'Jurassic Expedition', 81, 81, 1735, 0, 1, 7, 1, 0, 2000, 2000, 4.0, 2.0, 1.5, 0, 0, 'SmartAI', 1, ''),
(401002, 'Primal Warden Marksman', 'Jurassic Expedition', 80, 80, 1735, 0, 0, 7, 1, 0, 2000, 2000, 1.8, 1.5, 0.8, 0, 0, 'SmartAI', 1, ''),
(401003, 'Primal Warden Captain', 'Jurassic Expedition', 82, 82, 1735, 0, 2, 7, 1, 0, 2000, 2000, 8.0, 3.0, 2.0, 0, 0, 'SmartAI', 0, ''),
-- Horde Guards (Beast Hunters)
(401004, 'Beast Hunter', 'Primal Horde', 80, 80, 1734, 0, 0, 7, 1, 0, 2000, 2000, 2.0, 1.5, 1.0, 0, 0, 'SmartAI', 1, ''),
(401005, 'Beast Hunter Veteran', 'Primal Horde', 81, 81, 1734, 0, 1, 7, 1, 0, 2000, 2000, 4.0, 2.0, 1.5, 0, 0, 'SmartAI', 1, ''),
(401006, 'Beast Hunter Trapper', 'Primal Horde', 80, 80, 1734, 0, 0, 7, 1, 0, 2000, 2000, 1.8, 1.5, 0.8, 0, 0, 'SmartAI', 1, ''),
(401007, 'Beast Hunter Warlord', 'Primal Horde', 82, 82, 1734, 0, 2, 7, 1, 0, 2000, 2000, 8.0, 3.0, 2.0, 0, 0, 'SmartAI', 0, ''),
-- Neutral Guards (Primal Wardens Faction)
(401008, 'Primal Guardian', 'Primal Wardens', 81, 81, 35, 0, 1, 7, 1, 0, 2000, 2000, 5.0, 2.5, 1.5, 0, 0, 'SmartAI', 1, ''),
(401009, 'Ancient Primal Guardian', 'Primal Wardens', 82, 82, 35, 0, 2, 7, 1, 0, 2000, 2000, 10.0, 4.0, 2.0, 0, 0, 'SmartAI', 0, '');

-- ============================================================================
-- VENDORS AND SERVICES (401100-401199)
-- Level 80 for all service NPCs
-- ============================================================================

DELETE FROM `creature_template` WHERE `entry` BETWEEN 401100 AND 401150;
INSERT INTO `creature_template` (`entry`, `name`, `subname`, `gossip_menu_id`, `minlevel`, `maxlevel`, `faction`, `npcflag`, `rank`, `type`, `unit_class`, `unit_flags`, `HealthModifier`, `AIName`, `MovementType`) VALUES
-- Alliance Services (Beeble's Wreck)
(401100, 'Beeble Cogsworth', 'Gnome Expedition Leader', 400100, 80, 80, 1735, 3, 0, 7, 1, 0, 1.0, '', 0),
(401101, 'Tinker Sprocketwrench', 'Repairs', 400101, 80, 80, 1735, 4225, 0, 7, 1, 0, 1.0, '', 0),
(401102, 'Emily Stormwind', 'General Goods', 400102, 80, 80, 1735, 4225, 0, 7, 1, 0, 1.0, '', 0),
(401103, 'Flight Master Aldric', 'Flight Master', 400103, 80, 80, 1735, 8201, 0, 7, 1, 0, 1.0, '', 0),
(401104, 'Innkeeper Molly', 'Innkeeper', 400104, 80, 80, 1735, 65537, 0, 7, 1, 0, 1.0, '', 0),
-- Horde Services (Bozzle's Wreck)
(401105, 'Bozzle', 'Goblin Expedition Leader', 400105, 80, 80, 1734, 3, 0, 7, 1, 0, 1.0, '', 0),
(401106, 'Grizzek Fizzlecrank', 'Repairs', 400106, 80, 80, 1734, 4225, 0, 7, 1, 0, 1.0, '', 0),
(401107, 'Zasha', 'General Goods', 400107, 80, 80, 1734, 4225, 0, 7, 1, 0, 1.0, '', 0),
(401108, 'Flight Master Krag', 'Flight Master', 400108, 80, 80, 1734, 8201, 0, 7, 1, 0, 1.0, '', 0),
(401109, 'Innkeeper Grok', 'Innkeeper', 400109, 80, 80, 1734, 65537, 0, 7, 1, 0, 1.0, '', 0),
-- Neutral Services (Primal Camp)
(401110, 'Ku\'ma', 'The Bone Collector', 400110, 80, 80, 35, 131, 0, 7, 1, 0, 1.0, '', 0),
(401111, 'Safari Trainer Rex', 'Dinosaur Taming', 400111, 80, 80, 35, 19, 0, 7, 1, 0, 1.0, '', 0),
(401112, 'Professor Ironpaw', 'Archaeology Trainer', 400112, 80, 80, 35, 19, 0, 7, 1, 0, 1.0, '', 0),
(401113, 'Primal Quartermaster', 'Reputation Rewards', 400113, 80, 80, 35, 129, 0, 7, 1, 0, 1.0, '', 0),
(401114, 'Stable Master Thornhide', 'Stable Master', 400114, 80, 80, 35, 4194433, 0, 7, 1, 0, 1.0, '', 0),
(401115, 'Banker Goldtusk', 'Banker', 400115, 80, 80, 35, 134217856, 0, 7, 1, 0, 1.0, '', 0);

-- ============================================================================
-- QUEST GIVERS (401200-401299)
-- Level 80 for all quest NPCs
-- ============================================================================

DELETE FROM `creature_template` WHERE `entry` BETWEEN 401200 AND 401230;
INSERT INTO `creature_template` (`entry`, `name`, `subname`, `gossip_menu_id`, `minlevel`, `maxlevel`, `faction`, `npcflag`, `rank`, `type`, `unit_class`, `unit_flags`, `HealthModifier`, `AIName`, `MovementType`) VALUES
-- Main Story Quest Givers
(401200, 'Commander Stonewall', 'Expedition Commander', 400120, 80, 80, 35, 3, 0, 7, 1, 0, 1.5, '', 0),
(401201, 'Dr. Zira Fossildigger', 'Lead Archaeologist', 400121, 80, 80, 35, 3, 0, 7, 1, 0, 1.0, '', 0),
(401202, 'Huntmaster Grimtusk', 'Beast Tracker', 400122, 80, 80, 35, 3, 0, 7, 1, 0, 1.0, '', 0),
(401203, 'Sage Primalwisdom', 'Lore Keeper', 400123, 80, 80, 35, 3, 0, 7, 1, 0, 1.0, '', 0),
-- Daily Quest Givers
(401210, 'Raptor Handler Ka\'zak', 'Daily Quests', 400124, 80, 80, 35, 3, 0, 7, 1, 0, 1.0, '', 0),
(401211, 'Bone Collector Maz\'gor', 'Daily Quests', 400125, 80, 80, 35, 3, 0, 7, 1, 0, 1.0, '', 0),
(401212, 'Scout Shadowtooth', 'Daily Quests', 400126, 80, 80, 35, 3, 0, 7, 1, 0, 1.0, '', 0),
-- World Boss Quest Givers
(401220, 'Oondasta Tracker Grull', 'World Boss Hunter', 400127, 80, 80, 35, 3, 0, 7, 1, 0, 1.0, '', 0),
(401221, 'Thok Pursuer Raz\'jin', 'World Boss Hunter', 400128, 80, 80, 35, 3, 0, 7, 1, 0, 1.0, '', 0),
(401222, 'Storm Chaser Volta', 'World Boss Hunter', 400129, 80, 80, 35, 3, 0, 7, 1, 0, 1.0, '', 0);

-- ============================================================================
-- GOSSIP MENUS - NPC Text and Options
-- ============================================================================

-- NPC Text Entries
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextId0`, `lang0`, `Probability0`, `em0_0`, `em0_1`, `em0_2`, `em0_3`, `em0_4`, `em0_5`) VALUES
-- Zandalari NPCs (400000-400019)
(400000, 'Welcome to da Giant Isles, mon. Da Zandalari Expedition be seekin\' brave souls to help us tame dese primal beasts. Da loa have blessed dis land with creatures of unimaginable power.', '', 0, 0, 1, 0, 0, 0, 0, 0, 0),
(400001, 'Da spirits speak of ancient secrets buried beneath dis isle, mon. If ya be willin\' to brave da dangers, great knowledge awaits ya.', '', 0, 0, 1, 0, 0, 0, 0, 0, 0),
(400002, 'Dese beasts be unlike anythin\' ya\'ve seen before. Devilsaurs dat shake da very ground, raptors faster dan da wind, and direhorns wit armor tough as steel.', '', 0, 0, 1, 0, 0, 0, 0, 0, 0),
(400003, 'I\'ve scouted every corner of dis isle. Da Zandalari Warcamp to da east be dangerous - stay away unless ya be lookin\' for a fight.', '', 0, 0, 1, 0, 0, 0, 0, 0, 0),
-- Vendor NPCs (400010-400019)
(400010, 'Need supplies? I got everythin\' an expedition needs - food, drink, torches, and more. Just don\'t ask where I got da raptor jerky.', '', 0, 0, 1, 0, 0, 0, 0, 0, 0),
(400011, 'Da finest weapons forged from primal bone and chaos-touched steel. Each blade be blessed by da loa of war.', '', 0, 0, 1, 0, 0, 0, 0, 0, 0),
-- Special NPCs (400020-400039)
(400020, 'I am da Spirit of da Primal - da essence of dis ancient land. Da chaos corruption spreads through our sacred grounds. Help us purge it, and da spirits will reward ya.', '', 0, 0, 1, 0, 0, 0, 0, 0, 0),
(400030, 'Need a place to rest? Da Primal Inn offers da finest accommodations on da isle. We even got raptor-hide beds!', '', 0, 0, 1, 0, 0, 0, 0, 0, 0),
(400031, 'Ready to fly? I can take ya anywhere on da isle, or back to da mainland. Just hold on tight - dese pterrordaxes be a bit... temperamental.', '', 0, 0, 1, 0, 0, 0, 0, 0, 0),
-- Alliance/Horde Services (400100-400119)
(400100, 'The Gnomish Expedition was the first to establish a permanent base here. Our technology gives us an edge against these prehistoric terrors!', '', 0, 0, 1, 0, 0, 0, 0, 0, 0),
(400101, 'Need your gear repaired? These dinosaurs really do a number on equipment. I\'ve got the tools and the skills to patch you up.', '', 0, 0, 1, 0, 0, 0, 0, 0, 0),
(400102, 'Supplies, potions, reagents - if you need it for survival, I\'ve got it in stock.', '', 0, 0, 1, 0, 0, 0, 0, 0, 0),
(400103, 'The winds of the Giant Isles can be treacherous. But with the right mount, you can navigate them safely.', '', 0, 0, 1, 0, 0, 0, 0, 0, 0),
(400104, 'Welcome to the Expedition Rest House! Set your hearthstone here and rest easy.', '', 0, 0, 1, 0, 0, 0, 0, 0, 0),
(400105, 'Hey there! Bozzle\'s Salvage Operation is the best operation on the whole island. If it\'s valuable, we\'ve probably got it - for the right price.', '', 0, 0, 1, 0, 0, 0, 0, 0, 0),
(400106, 'Your gear looks like a raptor chewed on it. Lucky for you, I can fix anything - for a small fee.', '', 0, 0, 1, 0, 0, 0, 0, 0, 0),
(400107, 'Fresh supplies, straight from the Horde! Well, as fresh as anything can be on this dinosaur-infested rock.', '', 0, 0, 1, 0, 0, 0, 0, 0, 0),
(400108, 'Ready to fly, friend? I\'ve trained these wyverns to handle the island\'s unique... challenges.', '', 0, 0, 1, 0, 0, 0, 0, 0, 0),
(400109, 'Lok\'tar ogar! Welcome to Bozzle\'s Inn. Make yourself at home.', '', 0, 0, 1, 0, 0, 0, 0, 0, 0),
(400110, 'Bones... I collect bones. Bring me the bones of the great beasts, and I shall craft for you items of incredible power.', '', 0, 0, 1, 0, 0, 0, 0, 0, 0),
(400111, 'So you want to tame one of these prehistoric beasts? It won\'t be easy, but I can teach you the ancient techniques.', '', 0, 0, 1, 0, 0, 0, 0, 0, 0),
(400112, 'The archaeological treasures of this island are beyond imagination! Ancient Titan artifacts, fossilized remains, and more!', '', 0, 0, 1, 0, 0, 0, 0, 0, 0),
(400113, 'Prove your worth to the Primal Wardens, and you shall have access to our finest rewards.', '', 0, 0, 1, 0, 0, 0, 0, 0, 0),
(400114, 'Your pets will be safe with me. I\'ve got plenty of space in the stables.', '', 0, 0, 1, 0, 0, 0, 0, 0, 0),
(400115, 'Your gold is safe with me. Even the dinosaurs can\'t break into my vault!', '', 0, 0, 1, 0, 0, 0, 0, 0, 0),
-- Quest Givers (400120-400129)
(400120, 'The expedition faces threats from all sides - hostile Zandalari, corrupted beasts, and the world bosses that terrorize this land. We need capable adventurers.', '', 0, 0, 1, 0, 0, 0, 0, 0, 0),
(400121, 'The secrets buried here predate even the Titans! We must uncover them before the Zandalari do.', '', 0, 0, 1, 0, 0, 0, 0, 0, 0),
(400122, 'I\'ve tracked every beast on this island. If you need to find something, I\'m your man.', '', 0, 0, 1, 0, 0, 0, 0, 0, 0),
(400123, 'The ancient lore of this place speaks of a great corruption that threatens to consume all. We must stop it.', '', 0, 0, 1, 0, 0, 0, 0, 0, 0),
(400124, 'The raptors are getting out of control again. Think you can help thin their numbers?', '', 0, 0, 1, 0, 0, 0, 0, 0, 0),
(400125, 'I need more bones for my collection. The bigger, the better!', '', 0, 0, 1, 0, 0, 0, 0, 0, 0),
(400126, 'The Zandalari are up to something. I need eyes on their camp.', '', 0, 0, 1, 0, 0, 0, 0, 0, 0),
(400127, 'Oondasta, the King of Dinosaurs, roams the northwestern plateau. Defeating him would be a feat worthy of legend.', '', 0, 0, 1, 0, 0, 0, 0, 0, 0),
(400128, 'Thok the Bloodthirsty lurks in the Bone Pit. He\'s the most savage raptor ever to exist.', '', 0, 0, 1, 0, 0, 0, 0, 0, 0),
(400129, 'Nalak the Storm Lord circles the Chaos Rift. Lightning incarnate - be prepared for a shocking encounter.', '', 0, 0, 1, 0, 0, 0, 0, 0, 0);

-- Gossip Menu Entries
INSERT INTO `gossip_menu` (`MenuId`, `TextId`) VALUES
-- Zandalari NPCs
(400000, 400000), -- Elder Zul'jin
(400001, 400001), -- Witch Doctor Tala'jin
(400002, 400002), -- Rokhan the Beast Tamer
(400003, 400003), -- Scout Zan'do
(400010, 400010), -- Trader Zal'aman
(400011, 400011), -- Armsmaster Jin'kala
(400020, 400020), -- Spirit of the Primal
(400030, 400030), -- Bartender Zul'tik
(400031, 400031), -- Windwalker Ta'zo
-- Alliance Services
(400100, 400100), -- Beeble Cogsworth
(400101, 400101), -- Tinker Sprocketwrench
(400102, 400102), -- Emily Stormwind
(400103, 400103), -- Flight Master Aldric
(400104, 400104), -- Innkeeper Molly
-- Horde Services
(400105, 400105), -- Bozzle
(400106, 400106), -- Grizzek Fizzlecrank
(400107, 400107), -- Zasha
(400108, 400108), -- Flight Master Krag
(400109, 400109), -- Innkeeper Grok
-- Neutral Services
(400110, 400110), -- Ku'ma
(400111, 400111), -- Safari Trainer Rex
(400112, 400112), -- Professor Ironpaw
(400113, 400113), -- Primal Quartermaster
(400114, 400114), -- Stable Master Thornhide
(400115, 400115), -- Banker Goldtusk
-- Quest Givers
(400120, 400120), -- Commander Stonewall
(400121, 400121), -- Dr. Zira Fossildigger
(400122, 400122), -- Huntmaster Grimtusk
(400123, 400123), -- Sage Primalwisdom
(400124, 400124), -- Raptor Handler Ka'zak
(400125, 400125), -- Bone Collector Maz'gor
(400126, 400126), -- Scout Shadowtooth
(400127, 400127), -- Oondasta Tracker Grull
(400128, 400128), -- Thok Pursuer Raz'jin
(400129, 400129); -- Storm Chaser Volta

-- Gossip Menu Options
INSERT INTO `gossip_menu_option` (`MenuId`, `OptionId`, `OptionIcon`, `OptionText`, `OptionBroadcastTextId`, `OptionType`, `OptionNpcFlag`, `ActionMenuId`, `ActionPoiId`, `BoxCoded`, `BoxMoney`, `BoxText`, `BoxBroadcastTextId`) VALUES
-- Vendor gossip options (Browse Goods)
(400010, 0, 1, 'Let me see what you have for sale.', 0, 3, 128, 0, 0, 0, 0, '', 0),
(400011, 0, 1, 'Show me your weapons.', 0, 3, 128, 0, 0, 0, 0, '', 0),
(400101, 0, 5, 'Repair my equipment.', 0, 5, 4096, 0, 0, 0, 0, '', 0),
(400102, 0, 1, 'I need supplies.', 0, 3, 128, 0, 0, 0, 0, '', 0),
(400106, 0, 5, 'Repair my equipment.', 0, 5, 4096, 0, 0, 0, 0, '', 0),
(400107, 0, 1, 'I need supplies.', 0, 3, 128, 0, 0, 0, 0, '', 0),
(400110, 0, 1, 'What can you craft for me?', 0, 3, 128, 0, 0, 0, 0, '', 0),
(400113, 0, 1, 'Show me your reputation rewards.', 0, 3, 128, 0, 0, 0, 0, '', 0),
-- Trainer gossip options
(400111, 0, 3, 'Train me in dinosaur taming.', 0, 5, 16, 0, 0, 0, 0, '', 0),
(400112, 0, 3, 'Teach me about archaeology.', 0, 5, 16, 0, 0, 0, 0, '', 0),
-- Innkeeper gossip options
(400030, 0, 6, 'Make this inn your home.', 0, 8, 65536, 0, 0, 0, 0, '', 0),
(400104, 0, 6, 'Make this inn your home.', 0, 8, 65536, 0, 0, 0, 0, '', 0),
(400109, 0, 6, 'Make this inn your home.', 0, 8, 65536, 0, 0, 0, 0, '', 0),
-- Spirit of the Primal - special options
(400020, 0, 0, 'Tell me about the chaos corruption.', 0, 1, 1, 400021, 0, 0, 0, '', 0),
(400020, 1, 0, 'What can I do to help?', 0, 1, 1, 400022, 0, 0, 0, '', 0);

-- Sub-menus for Spirit of the Primal
INSERT INTO `npc_text` (`ID`, `text0_0`) VALUES
(400021, 'Da chaos corruption be an ancient evil, mon. It seeps through da very land, twistin\' creatures into shadows of deir former selves. Da world bosses - Oondasta, Thok, and Nalak - dey be da greatest threats, but even da common beasts be affected.'),
(400022, 'Hunt da corrupted creatures, cleanse da tainted shrines, and face da world bosses. Each victory pushes back da darkness. Da loa will reward ya handsomely for ya efforts.');

INSERT INTO `gossip_menu` (`MenuId`, `TextId`) VALUES
(400021, 400021),
(400022, 400022);

-- ============================================================================
-- CREATURE_TEMPLATE_MODEL - Display models for NPCs (401000+)
-- ============================================================================

DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN 401000 AND 401999;

INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
-- Alliance Guards (Human models)
(401000, 0, 2095, 1, 1, 12340),  -- Primal Warden (Human Male)
(401001, 0, 2095, 1, 1, 12340),  -- Primal Warden Sergeant
(401002, 0, 2095, 1, 1, 12340),  -- Primal Warden Marksman
(401003, 0, 2095, 1.1, 1, 12340), -- Primal Warden Captain
-- Horde Guards (Orc models)
(401004, 0, 7555, 1, 1, 12340),  -- Beast Hunter (Orc Male)
(401005, 0, 7555, 1, 1, 12340),  -- Beast Hunter Veteran
(401006, 0, 7555, 1, 1, 12340),  -- Beast Hunter Trapper
(401007, 0, 7555, 1.1, 1, 12340), -- Beast Hunter Warlord
-- Neutral Guards (Tauren models)
(401008, 0, 9268, 1, 1, 12340),  -- Primal Guardian (Tauren Male)
(401009, 0, 9268, 1.1, 1, 12340), -- Ancient Primal Guardian
-- Alliance Service NPCs
(401100, 0, 7125, 0.7, 1, 12340), -- Beeble Cogsworth (Gnome Male)
(401101, 0, 7125, 0.7, 1, 12340), -- Tinker Sprocketwrench
(401102, 0, 3882, 1, 1, 12340),  -- Emily Stormwind (Human Female)
(401103, 0, 2095, 1, 1, 12340),  -- Flight Master Aldric
(401104, 0, 3882, 1, 1, 12340),  -- Innkeeper Molly
-- Horde Service NPCs
(401105, 0, 7127, 0.8, 1, 12340), -- Bozzle (Goblin Male)
(401106, 0, 7127, 0.8, 1, 12340), -- Grizzek Fizzlecrank
(401107, 0, 7126, 0.8, 1, 12340), -- Zasha (Goblin Female)
(401108, 0, 7555, 1, 1, 12340),  -- Flight Master Krag
(401109, 0, 7555, 1, 1, 12340),  -- Innkeeper Grok
-- Neutral Service NPCs
(401110, 0, 21286, 1, 1, 12340), -- Ku'ma (Zandalari Troll)
(401111, 0, 9268, 1, 1, 12340),  -- Safari Trainer Rex (Tauren)
(401112, 0, 6930, 1, 1, 12340),  -- Professor Ironpaw (Dwarf)
(401113, 0, 9268, 1, 1, 12340),  -- Primal Quartermaster
(401114, 0, 9268, 1, 1, 12340),  -- Stable Master Thornhide
(401115, 0, 7127, 0.8, 1, 12340), -- Banker Goldtusk (Goblin)
-- Quest Givers
(401200, 0, 2095, 1.1, 1, 12340), -- Commander Stonewall (Human)
(401201, 0, 7125, 0.7, 1, 12340), -- Dr. Zira Fossildigger (Gnome Female)
(401202, 0, 7555, 1, 1, 12340),  -- Huntmaster Grimtusk (Orc)
(401203, 0, 9268, 1, 1, 12340),  -- Sage Primalwisdom (Tauren)
(401210, 0, 21286, 1, 1, 12340), -- Raptor Handler Ka'zak (Troll)
(401211, 0, 21286, 1, 1, 12340), -- Bone Collector Maz'gor (Troll)
(401212, 0, 21286, 1, 1, 12340), -- Scout Shadowtooth (Troll)
(401220, 0, 7555, 1, 1, 12340),  -- Oondasta Tracker Grull (Orc)
(401221, 0, 21286, 1, 1, 12340), -- Thok Pursuer Raz'jin (Troll)
(401222, 0, 3882, 1, 1, 12340);  -- Storm Chaser Volta (Human Female)

-- ============================================================================
-- CANNON QUEST DATA - Quest, Gossip, and Waypoints
-- Quest ID: 80100 - "Sink the Zandalari Scout"
-- ============================================================================

-- Captain Harlan Gossip
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextId0`, `lang0`, `Probability0`) VALUES
(400320, 'Soldier! Those blasted Zandalari have been sending scout ships to spy on our defenses. We''ve set up a coastal cannon to deal with them, but I need someone with a steady aim.', '', 0, 0, 1);

INSERT INTO `gossip_menu` (`MenuId`, `TextId`) VALUES
(400320, 400320);

-- Quest: Sink the Zandalari Scout
-- Using correct AzerothCore quest_template schema
DELETE FROM `quest_template` WHERE `ID` = 80100;
INSERT INTO `quest_template` (
    `ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
    `RequiredFactionId1`, `RequiredFactionId2`, `RequiredFactionValue1`, `RequiredFactionValue2`,
    `RewardNextQuest`, `RewardXPDifficulty`, `RewardMoney`, `RewardMoneyDifficulty`,
    `RewardDisplaySpell`, `RewardSpell`, `RewardHonor`, `RewardKillHonor`, `StartItem`, `Flags`,
    `RequiredPlayerKills`,
    `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `RewardItem4`, `RewardAmount4`,
    `ItemDrop1`, `ItemDropQuantity1`, `ItemDrop2`, `ItemDropQuantity2`, `ItemDrop3`, `ItemDropQuantity3`, `ItemDrop4`, `ItemDropQuantity4`,
    `RewardChoiceItemID1`, `RewardChoiceItemQuantity1`, `RewardChoiceItemID2`, `RewardChoiceItemQuantity2`,
    `RewardChoiceItemID3`, `RewardChoiceItemQuantity3`, `RewardChoiceItemID4`, `RewardChoiceItemQuantity4`,
    `RewardChoiceItemID5`, `RewardChoiceItemQuantity5`, `RewardChoiceItemID6`, `RewardChoiceItemQuantity6`,
    `POIContinent`, `POIx`, `POIy`, `POIPriority`,
    `RewardTitle`, `RewardTalents`, `RewardArenaPoints`,
    `RewardFactionID1`, `RewardFactionValue1`, `RewardFactionOverride1`,
    `RewardFactionID2`, `RewardFactionValue2`, `RewardFactionOverride2`,
    `RewardFactionID3`, `RewardFactionValue3`, `RewardFactionOverride3`,
    `RewardFactionID4`, `RewardFactionValue4`, `RewardFactionOverride4`,
    `RewardFactionID5`, `RewardFactionValue5`, `RewardFactionOverride5`,
    `TimeAllowed`, `AllowableRaces`,
    `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`,
    `RequiredNpcOrGo1`, `RequiredNpcOrGo2`, `RequiredNpcOrGo3`, `RequiredNpcOrGo4`,
    `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`, `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`,
    `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`, `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`,
    `RequiredItemCount1`, `RequiredItemCount2`, `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`,
    `Unknown0`,
    `ObjectiveText1`, `ObjectiveText2`, `ObjectiveText3`, `ObjectiveText4`,
    `VerifiedBuild`
) VALUES (
    80100, 2, 80, 70, 5000, 0, 0,   -- ID, Type, Level, MinLevel, SortID, InfoID, GroupNum
    0, 0, 0, 0,                      -- RequiredFaction
    0, 7, 250000, 0,                 -- RewardNextQuest, XPDiff, Money, MoneyDiff
    0, 0, 0, 0, 0, 8388616,          -- DisplaySpell, Spell, Honor, KillHonor, StartItem, Flags (DAILY)
    0,                               -- RequiredPlayerKills
    0, 0, 0, 0, 0, 0, 0, 0,          -- RewardItem 1-4
    0, 0, 0, 0, 0, 0, 0, 0,          -- ItemDrop 1-4
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  -- RewardChoiceItem 1-6
    0, 0, 0, 0,                      -- POI
    0, 0, 0,                         -- RewardTitle, Talents, ArenaPoints
    0, 400, 0,                       -- RewardFaction1 (Primal Wardens rep = 400)
    0, 0, 0,                         -- RewardFaction2
    0, 0, 0,                         -- RewardFaction3
    0, 0, 0,                         -- RewardFaction4
    0, 0, 0,                         -- RewardFaction5
    0, 0,                            -- TimeAllowed, AllowableRaces
    'Sink the Zandalari Scout',
    'Use the Coastal Cannon at Warden''s Landing to sink a Zandalari scout ship.',
    'Captain Harlan has spotted a Zandalari scout ship approaching our waters. Man the coastal cannon and sink it before they can report back to their masters!$B$BThe cannon has enough firepower to sink the ship in just a few direct hits. Get in there and show them what we''re made of!',
    '',
    'You sank the Zandalari scout ship! That''ll teach them to spy on us.',
    400322, 0, 0, 0,                 -- RequiredNpcOrGo 1-4 (400322 = ship)
    1, 0, 0, 0,                      -- RequiredNpcOrGoCount 1-4
    0, 0, 0, 0, 0, 0,                -- RequiredItemId 1-6
    0, 0, 0, 0, 0, 0,                -- RequiredItemCount 1-6
    0,                               -- Unknown0
    'Zandalari scout ship sunk', '', '', '',  -- ObjectiveText 1-4
    12340                            -- VerifiedBuild
);

-- Quest starter/ender
DELETE FROM `creature_queststarter` WHERE `quest` = 80100;
DELETE FROM `creature_questender` WHERE `quest` = 80100;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES (400320, 80100);
INSERT INTO `creature_questender` (`id`, `quest`) VALUES (400320, 80100);

-- Ship Waypoint Path (placeholder coordinates - UPDATE WITH REAL ZONE COORDS)
-- Path ID: 4003220 (NPC Entry * 10)
-- This defines the patrol route for the scout ship
DELETE FROM `waypoint_data` WHERE `id` = 4003220;
INSERT INTO `waypoint_data` (`id`, `point`, `position_x`, `position_y`, `position_z`, `orientation`, `delay`, `move_type`, `action`, `action_chance`, `wpguid`) VALUES
-- TODO: Replace with actual Giant Isles coordinates
-- These are placeholder waypoints forming a patrol path offshore
(4003220, 1, 0, 0, 0, 0, 0, 0, 0, 100, 0),   -- Start position (spawned by script)
(4003220, 2, 50, 0, 0, 0, 0, 0, 0, 100, 0),  -- Patrol point 1
(4003220, 3, 100, -30, 0, 0, 0, 0, 0, 100, 0), -- Patrol point 2
(4003220, 4, 150, 0, 0, 0, 0, 0, 0, 100, 0),   -- Patrol point 3
(4003220, 5, 100, 30, 0, 0, 0, 0, 0, 100, 0),  -- Patrol point 4
(4003220, 6, 50, 0, 0, 0, 0, 0, 0, 100, 0);    -- Return to start area

-- ============================================================================
-- END OF GIANT ISLES CREATURE TEMPLATES
-- ============================================================================
