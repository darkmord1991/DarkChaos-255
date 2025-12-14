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
-- ============================================================================
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
(400000,0,0,0,0,0,'Chaos Devilsaur',NULL,NULL,0,80,80,2,14,0,2.4,1.71429,1.2,0,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,76,0,0,0,0,0,1500,2500,'',1,1,25,1,1.5,8,1,0,0,1,0,0,0,'',12340),
(400001,0,0,0,0,0,'Ironhide Chaos Devilsaur',NULL,NULL,0,81,81,2,14,0,2.4,1.71429,1.3,1,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,76,0,0,0,0,0,2000,3000,'',1,1,35,1,2.0,10,1,0,0,1,0,0,128,'',12340),
(400002,0,0,0,0,0,'Tyrant Chaos Devilsaur',NULL,NULL,0,81,81,2,14,0,2.4,1.71429,1.4,1,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,76,0,0,0,0,0,2500,4000,'',1,1,50,1,2.5,12,1,0,0,1,0,0,128,'',12340);

-- Primal Stegodons (from Stegodon 6501-6504) - Entry 400003-400006
-- Heavily armored beasts that roam in herds
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400003,0,0,0,0,0,'Primal Stegodon',NULL,NULL,0,80,80,2,14,0,1.6,1.14286,1.1,0,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,0,0,0,0,0,0,800,1200,'',1,1,18,1,3.0,5,1,0,0,1,0,0,0,'',12340),
(400004,0,0,0,0,0,'Elder Stegodon',NULL,NULL,0,80,80,2,14,0,1.6,1.14286,1.2,0,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,0,0,0,0,0,0,1000,1500,'',1,1,22,1,3.5,6,1,0,0,1,0,0,0,'',12340),
(400005,0,0,0,0,0,'Armored Stegodon',NULL,NULL,0,81,81,2,14,0,1.6,1.14286,1.25,1,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,76,0,0,0,0,0,1200,1800,'',1,1,28,1,4.0,7,1,0,0,1,0,0,0,'',12340),
(400006,0,0,0,0,0,'Ancient Stegodon',NULL,NULL,0,81,81,2,14,0,1.6,1.14286,1.35,1,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,76,0,0,0,0,0,1500,2200,'',1,1,35,1,4.5,8,1,0,0,1,0,0,0,'',12340);

-- Chaos Raptors (from Ravasaur 6505-6508) - Entry 400007-400010
-- Fast and deadly pack hunters
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400007,0,0,0,0,0,'Chaos Raptor',NULL,NULL,0,80,80,2,14,0,1.8,1.42857,1,0,0,1500,2000,1,1,1,32832,2048,0,37,0,0,0,0,1,0,0,0,0,0,0,500,800,'',1,1,12,1,1,4,1,0,0,1,0,0,0,'',12340),
(400008,0,0,0,0,0,'Chaos Raptor Runner',NULL,NULL,0,80,80,2,14,0,2.0,1.71429,1,0,0,1500,2000,1,1,1,32832,2048,0,37,0,0,0,0,1,0,0,0,0,0,0,600,950,'',1,1,14,1,1,5,1,0,0,1,0,0,0,'',12340),
(400009,0,0,0,0,0,'Chaos Raptor Hunter',NULL,NULL,0,80,80,2,14,0,1.8,1.42857,1.05,0,0,1500,2000,1,1,1,32832,2048,0,37,0,0,0,0,1,0,0,0,0,0,0,700,1100,'',1,1,16,1,1.2,5.5,1,0,0,1,0,0,0,'',12340),
(400010,0,0,0,0,0,'Venomhide Chaos Raptor',NULL,NULL,0,81,81,2,14,0,1.8,1.42857,1.1,1,0,1500,2000,1,1,1,32832,2048,0,37,0,0,0,0,1,76,0,0,0,0,0,800,1300,'',1,1,20,1,1.5,6,1,0,0,1,0,0,0,'',12340);

-- Chaos Pterrordax (from Pterrordax 9165-9167) - Entry 400011-400013
-- Flying terrors that patrol the skies
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400011,0,0,0,0,0,'Fledgling Chaos Pterrordax',NULL,NULL,0,80,80,2,14,0,1.6,1.14286,0.9,0,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,0,0,0,0,0,0,400,700,'',1,1,10,1,0.8,3.5,1,0,0,1,0,0,0,'',12340),
(400012,0,0,0,0,0,'Chaos Pterrordax',NULL,NULL,0,80,80,2,14,0,1.6,1.14286,1,0,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,0,0,0,0,0,0,550,900,'',1,1,14,1,1,4.5,1,0,0,1,0,0,0,'',12340),
(400013,0,0,0,0,0,'Frenzied Chaos Pterrordax',NULL,NULL,0,81,81,2,14,0,1.6,1.14286,1.1,1,0,1800,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,76,0,0,0,0,0,700,1100,'',1,1,18,1,1.2,5.5,1,0,0,1,0,0,0,'',12340);

-- Primal Diemetradons (from Diemetradon 9162-9164) - Entry 400014-400016
-- Sail-backed reptiles that hunt near water
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400014,0,0,0,0,0,'Young Primal Diemetradon',NULL,NULL,0,80,80,2,14,0,1.6,1.14286,0.85,0,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,0,0,0,0,0,0,400,650,'',1,1,11,1,1,3.5,1,0,0,1,0,0,0,'',12340),
(400015,0,0,0,0,0,'Primal Diemetradon',NULL,NULL,0,80,80,2,14,0,1.6,1.14286,1,0,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,0,0,0,0,0,0,500,850,'',1,1,15,1,1.2,4.5,1,0,0,1,0,0,0,'',12340),
(400016,0,0,0,0,0,'Elder Primal Diemetradon',NULL,NULL,0,81,81,2,14,0,1.6,1.14286,1.15,1,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,76,0,0,0,0,0,650,1000,'',1,1,20,1,1.5,5.5,1,0,0,1,0,0,0,'',12340);

-- ============================================================================
-- ELITE DINOSAURS - Rare spawns (400050-400059)
-- All are Level 82 (Rare Elite / Boss tier)
-- ============================================================================

-- Rare Elite Dinosaurs (Static Spawns)
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400050,0,0,0,0,0,'Primal Direhorn','Rare Elite',NULL,0,82,82,2,14,0,2.2,1.71429,1.5,2,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,76,0,0,0,0,0,5000,8000,'',1,1,80,1,3,15,2,0,0,1,617299967,0,128,'creature_giant_isles_rare_spawn',12340),
(400051,0,0,0,0,0,'Chaos Rex','Rare Elite',NULL,0,82,82,2,14,0,2.4,1.85714,1.6,2,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,76,0,0,0,0,0,6000,9000,'',1,1,100,1,2.5,18,2,0,0,1,617299967,0,128,'creature_giant_isles_rare_spawn',12340),
(400052,0,0,0,0,0,'Ancient Primordial','Rare Elite',NULL,0,82,82,2,14,0,2.0,1.42857,1.8,2,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,76,0,0,0,0,0,7000,10000,'',1,1,120,1,4,20,2,0,0,1,617299967,0,128,'creature_giant_isles_rare_spawn',12340),
(400053,0,0,0,0,0,'Savage Stegodon Matriarch','Rare Elite',NULL,0,82,82,2,14,0,1.6,1.14286,1.5,2,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,76,0,0,0,0,0,5500,8500,'',1,1,90,1,5,16,2,0,0,1,617299967,0,128,'creature_giant_isles_rare_spawn',12340),
(400054,0,0,0,0,0,'Alpha Chaos Raptor','Rare Elite',NULL,0,82,82,2,14,0,2.2,1.85714,1.3,2,0,1500,2000,1,1,1,32832,2048,0,37,0,0,0,0,1,76,0,0,0,0,0,4500,7000,'',1,1,70,1,2,14,2,0,0,1,617299967,0,128,'creature_giant_isles_rare_spawn',12340);

-- Random Rare Spawns (Dynamically spawned by zone script) - Entry 400055-400059
-- These rares can randomly appear via the zone script with special mechanics
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400055,0,0,0,0,0,'Bonecrusher','Primal Horror',NULL,0,82,82,2,14,0,2.6,2.0,2.0,2,0,1800,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,76,0,0,0,0,0,8000,12000,'',1,1,150,1,3.5,22,2,0,0,1,617299967,0,128,'creature_giant_isles_rare_spawn',12340),
(400056,0,0,0,0,0,'Gorespine the Impaler','Spiked Nightmare',NULL,0,82,82,2,14,0,1.8,1.42857,1.7,2,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,76,0,0,0,0,0,8500,13000,'',1,1,130,1,5.5,20,2,0,0,1,617299967,0,128,'creature_giant_isles_rare_spawn',12340),
(400057,0,0,0,0,0,'Venomfang','Toxic Terror',NULL,0,82,82,2,14,0,2.4,2.0,1.5,2,4,1500,2000,1,1,1,32832,2048,0,37,0,0,0,0,1,76,0,0,0,0,0,7500,11000,'',1,1,110,1,2.5,18,2,0,0,1,617299967,0,128,'creature_giant_isles_rare_spawn',12340),
(400058,0,0,0,0,0,'Skyscreamer','Chaos Windlord',NULL,0,82,82,2,14,0,2.0,1.71429,1.4,2,4,2000,2000,1,1,2,32832,2048,0,0,0,0,0,0,1,76,0,0,0,0,0,7000,10500,'',1,1,100,5,2,16,2,0,0,1,617299967,0,128,'creature_giant_isles_rare_spawn',12340),
(400059,0,0,0,0,0,'Gul\'rok the Cursed','Primal Witch Doctor',NULL,0,82,82,2,14,0,1.4,1.14286,1.2,2,5,2000,2000,1,1,2,32832,2048,0,0,0,0,0,0,7,76,0,0,0,0,0,10000,15000,'',0,1,180,10,2,25,2.5,0,0,1,617299967,0,128,'creature_giant_isles_rare_spawn',12340);

-- ============================================================================
-- WORLD BOSSES (400100-400102)
-- Level 82 (Boss rank = 3)
-- ============================================================================

-- Oondasta - The King of Dinosaurs (Based on MoP world boss)
-- Massive Devilsaur that terrorizes the island
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400100,0,0,0,0,0,'Oondasta','King of Dinosaurs','VehicleCursor',0,82,82,2,14,0,2.8,2.14286,3.0,3,0,2000,2000,1,1,1,64,2048,8,0,0,0,0,0,1,108,0,0,0,0,0,50000,75000,'',0,1,2000,1,4,50,3,0,0,1,2147483647,0,129,'boss_oondasta',12340);

-- Thok the Bloodthirsty - The Primal Hunter
-- Savage raptor boss that hunts in packs
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400101,0,0,0,0,0,'Thok the Bloodthirsty','Primal Hunter','VehicleCursor',0,82,82,2,14,0,3.2,2.5,2.5,3,0,1500,2000,1,1,1,64,2048,8,37,0,0,0,0,1,108,0,0,0,0,0,45000,65000,'',0,1,1800,1,3,45,3,0,0,1,2147483647,0,129,'boss_thok',12340);

-- Nalak the Storm Lord - Ancient Thunder Lizard
-- Lightning-infused Pterrordax elder
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400102,0,0,0,0,0,'Nalak the Storm Lord','Ancient Thunder Lizard','VehicleCursor',0,82,82,2,14,0,2.4,1.85714,2.8,3,4,2000,2000,1,1,2,64,2048,8,0,0,0,0,0,1,108,0,0,0,0,0,48000,70000,'',0,1,1600,100,2.5,40,3,0,0,1,2147483647,0,129,'boss_nalak',12340);

-- ============================================================================
-- TROLL NPCS - Zandalari faction (400200-400249)
-- Level 80 for friendly NPCs
-- ============================================================================

-- Based on Zandalari models from Zul'Gurub/Zul'Aman
-- These are the expedition NPCs for the zone

INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400200,0,0,0,0,0,'Elder Zul\'jin','Zandalari Expedition Leader','Speak',400000,80,80,2,35,3,1,1.14286,1,0,0,2000,2000,1,1,1,768,2048,0,0,0,0,0,0,7,0,0,0,0,0,0,0,0,'',0,1,10,1,1,1,1,0,0,1,0,0,2,'',12340),
(400202,0,0,0,0,0,'Rokhan the Beast Tamer','Zandalari Beast Master','Speak',400002,80,80,2,35,3,1,1.14286,1,0,0,2000,2000,1,1,1,768,2048,0,0,0,0,0,0,7,0,0,0,0,0,0,0,0,'',0,1,10,1,1,1,1,0,0,1,0,0,2,'',12340),
(400203,0,0,0,0,0,'Scout Zan\'do','Zandalari Scout','Speak',400003,80,80,2,35,3,1,1.14286,1,0,0,2000,2000,1,1,1,768,2048,0,0,0,0,0,0,7,0,0,0,0,0,0,0,0,'',0,1,5,1,1,1,1,0,0,1,0,0,2,'',12340);

INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400210,0,0,0,0,0,'Trader Zal\'aman','Zandalari Supplies','Speak',400010,80,80,2,35,129,1,1.14286,1,0,0,2000,2000,1,1,1,768,2048,0,0,0,0,0,0,7,0,0,0,0,0,0,0,0,'',0,1,8,1,1,1,1,0,0,1,0,0,2,'',12340);

INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400220,0,0,0,0,0,'Zandalari Expedition Guard',NULL,NULL,0,81,81,2,35,0,1.2,1.28571,1,1,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,7,0,0,0,0,0,0,0,0,'',1,1,25,1,2,8,1,0,0,1,0,0,0,'',12340);

-- ============================================================================
-- HOSTILE TROLLS - Primal Enemies (400250-400274)
-- Level 80 normal, Level 81 elite, Level 82 for mini-bosses
-- ============================================================================

-- Primal Troll enemies (hostile to all)
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400250,0,0,0,0,0,'Primal Troll Warrior',NULL,NULL,0,80,80,2,16,0,1.2,1.28571,1,0,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,7,0,0,0,0,0,0,600,1000,'',1,1,12,1,1.5,5,1,0,0,1,0,0,0,'',12340),
(400251,0,0,0,0,0,'Primal Troll Shadowcaster',NULL,NULL,0,80,80,2,16,0,1.2,1.14286,1,0,0,2000,2000,1,1,2,32832,2048,0,0,0,0,0,0,7,0,0,0,0,0,0,600,1000,'',1,1,10,5,1,4.5,1,0,0,1,0,0,0,'',12340),
(400252,0,0,0,0,0,'Primal Troll Berserker',NULL,NULL,0,81,81,2,16,0,1.4,1.42857,1.4,1,0,1800,2000,1,1,1,32832,2048,0,0,0,0,0,0,7,0,0,0,0,0,0,800,1200,'',1,1,15,1,1.2,6,1,0,0,1,0,0,128,'',12340),
(400253,0,0,0,0,0,'Primal Troll Witch Doctor',NULL,NULL,0,81,81,2,16,0,1.2,1.14286,1.3,1,0,2000,2000,1,1,2,32832,2048,0,0,0,0,0,0,7,0,0,0,0,0,0,800,1200,'',1,1,12,8,1,5.5,1,0,0,1,0,0,128,'',12340),
(400254,0,0,0,0,0,'Primal Troll Headhunter',NULL,NULL,0,81,81,2,16,0,1.3,1.42857,1.3,1,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,7,0,0,0,0,0,0,900,1400,'',1,1,14,1,1.3,6,1,0,0,1,0,0,128,'',12340);

-- Primal Troll Elite (mini-boss) - Level 82
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400260,0,0,0,0,0,'Warlord Gha\'tul','Primal Chieftain',NULL,0,82,82,2,16,0,1.4,1.42857,1.15,2,0,1800,2000,1,1,1,32832,2048,0,0,0,0,0,0,7,76,0,0,0,0,0,3000,5000,'',1,1,60,1,2.5,12,2,0,0,1,617299967,0,128,'',12340);


INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400300,0,0,0,0,0,'Spirit of the Primal',NULL,NULL,400020,80,80,2,35,1,1,1.14286,2.0,0,0,2000,2000,1,1,1,32768,2048,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,'',0,1,50,1,1,5,1,0,0,1,0,0,2,'npc_spirit_of_primal',12340);
-- (400310 original SmartAI entry removed)

-- Bartender Zul'tik - Innkeeper for the zone
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400310,0,0,0,0,0,'Bartender Zul\'tik','Zandalari Innkeeper','Interact',400030,80,80,2,35,65539,1,1.14286,1,0,0,2000,2000,1,1,1,768,2048,0,0,0,0,0,0,7,0,0,0,0,0,0,0,0,'',0,1,8,1,1,1,1,0,0,1,0,0,2,'',12340);

-- Windwalker Ta'zo - Flight Master
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400311,0,0,0,0,0,'Windwalker Ta\'zo','Zandalari Flight Master','Taxi',400031,80,80,2,35,8201,1,1.14286,1,0,0,2000,2000,1,1,1,768,2048,0,0,0,0,0,0,7,0,0,0,0,0,0,0,0,'',0,1,10,1,1,1,1,0,0,1,0,0,2,'',12340);

-- ============================================================================
-- CANNON QUEST NPCs (400320-400329)
-- Daily Quest: "Sink the Zandalari Scout"
-- ============================================================================

-- Captain Harlan - Quest giver (Human sailor model)
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400320,0,0,0,0,0,'Captain Harlan','Coastal Defense','Speak',400320,80,80,2,35,3,1,1.14286,1.3,0,0,2000,2000,1,1,1,768,2048,0,0,0,0,0,0,7,0,0,0,0,0,0,0,0,'',0,1,10,1,1,1,1,0,0,1,0,0,2,'npc_captain_harlan',12340);

-- Coastal Cannon - Vehicle (uses siege cannon model)
-- VehicleId 554 is the ICC Gunship Cannon vehicle seat
-- unit_flags = 4 (DISABLE_MOVE), npcflag = 16777216 (SPELLCLICK), flags_extra includes IMMOBILIZED
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400321,0,0,0,0,0,'Coastal Cannon',NULL,'VehicleCursor',0,80,80,2,35,16777216,0,0,2.0,0,0,2000,2000,1,1,1,4,2048,0,0,0,0,0,0,9,8,0,0,0,0,554,0,0,'',0,1,100,1,1,1,0,0,0,1,650854271,0,1073741826,'npc_coastal_cannon',12340);

-- Spellclick entry for the cannon (same as ICC Gunship Cannon - spell 70510)
DELETE FROM `npc_spellclick_spells` WHERE `npc_entry` = 400321;
INSERT INTO `npc_spellclick_spells` (`npc_entry`, `spell_id`, `cast_flags`, `user_type`) VALUES
(400321, 70510, 1, 0);

-- Cannon spell action bar (same as ICC Gunship Cannon 36838)
-- Spell 0 = 69399 (Cannon Blast), Spell 1 = 70174 (Incinerating Blast)
DELETE FROM `creature_template_spell` WHERE `CreatureID` = 400321;
INSERT INTO `creature_template_spell` (`CreatureID`, `Index`, `Spell`, `VerifiedBuild`) VALUES
(400321, 0, 69399, 12340),
(400321, 1, 70174, 12340);

-- ============================================================================
-- ZANDALARI SCOUT SHIP - GameObject + Hitbox Creature
-- ============================================================================

-- Zandalari Scout Ship - GameObject (visual ship model)
-- Type 5 = GAMEOBJECT_TYPE_GENERIC (static decoration)
-- DisplayID 9232 = Pirate Ship model
DELETE FROM `gameobject_template` WHERE `entry` = 400322;
INSERT INTO `gameobject_template` (`entry`, `type`, `displayId`, `name`, `IconName`, `castBarCaption`, `unk1`, `size`, `Data0`, `Data1`, `Data2`, `Data3`, `Data4`, `Data5`, `Data6`, `Data7`, `Data8`, `Data9`, `Data10`, `Data11`, `Data12`, `Data13`, `Data14`, `Data15`, `Data16`, `Data17`, `Data18`, `Data19`, `Data20`, `Data21`, `Data22`, `Data23`, `AIName`, `ScriptName`, `VerifiedBuild`) VALUES
(400322, 5, 9232, 'Zandalari Scout Ship', '', '', '', 1.5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340);

-- Ship Hitbox - Invisible creature that takes cannon damage
-- This creature is spawned at the ship's position and handles hit detection
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400324,0,0,0,0,0,'Zandalari Scout Ship',NULL,NULL,0,80,80,2,14,0,0.1,0.12,2,0,0,2000,2000,1,1,1,0,2048,0,0,0,0,0,0,9,0,0,0,0,0,0,0,0,'',0,1,50,1,1,1,0,0,0,0,617299967,0,0,'npc_zandalari_scout_ship',12340);

-- Ship Visual Trigger - For explosion effects
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400323,0,0,0,0,0,'Ship Explosion Trigger',NULL,NULL,0,80,80,2,35,0,1,1.14286,1,0,0,2000,2000,1,1,1,33554944,2048,0,0,0,0,0,0,10,1024,0,0,0,0,0,0,0,'',0,1,1,1,1,1,0,0,0,0,0,0,128,'',12340);

-- ============================================================================
-- CONDITIONS - Allow cannon spells to target our ship (400324)
-- ============================================================================
-- The ICC cannon spells have conditions restricting them to specific creatures.
-- We need to add conditions for our ship so it can be hit by cannon spells.
-- ConditionTypeOrReference 31 = CONDITION_OBJECT_ENTRY_GUID
-- ConditionValue1 = 3 (TYPEID_UNIT)
-- ConditionValue2 = Creature Entry

-- 69400 = Cannon Blast missile (triggers damage on impact)
-- 69402 = Incinerating Blast missile
DELETE FROM `conditions` WHERE `SourceTypeOrReferenceId` = 13 AND `SourceGroup` = 2 AND `SourceEntry` IN (69400, 69402) AND `ConditionValue2` = 400324;
INSERT INTO `conditions` (`SourceTypeOrReferenceId`, `SourceGroup`, `SourceEntry`, `SourceId`, `ElseGroup`, `ConditionTypeOrReference`, `ConditionTarget`, `ConditionValue1`, `ConditionValue2`, `ConditionValue3`, `NegativeCondition`, `ErrorType`, `ErrorTextId`, `ScriptName`, `Comment`) VALUES
(13, 2, 69400, 0, 1, 31, 0, 3, 400324, 0, 0, 0, 0, '', 'Cannon Blast - also target Zandalari Scout Ship'),
(13, 2, 69402, 0, 1, 31, 0, 3, 400324, 0, 0, 0, 0, '', 'Incinerating Blast - also target Zandalari Scout Ship');

-- ============================================================================
-- ZANDALARI INVASION NPCs (400325-400340)
-- ============================================================================
-- Invasion system: Waves of Zandalari attackers assault Seeping Shores
-- Triggered at coordinates:
-- Middle: X: 5809.59 Y: 1200.97 Z: 7.04 O: 1.94
-- Right:  X: 5844.46 Y: 1215.58 Z: 10.58 O: 2.29
-- Left:   X: 5785.77 Y: 1203.52 Z: 2.84 O: 1.55
-- ============================================================================

-- Invasion Horn - Trigger object (GameObject converted to NPC for interaction)
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400325,0,0,0,0,0,'Invasion Warning Horn',NULL,'Interact',0,80,80,2,35,1,1,1.14286,2.0,0,0,2000,2000,1,1,1,33554432,2048,0,0,0,0,0,0,10,16,0,0,0,0,0,0,0,'',0,1,1,1,1,1,0,0,0,0,0,0,2,'npc_invasion_horn',12340);

-- Wave 1: Zandalari Scout Party (400326-400328) - Light scouts and basic troops
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400326,0,0,0,0,0,'Zandalari Invader',NULL,NULL,0,80,80,2,16,0,1.2,1.28571,1.3,0,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,7,0,0,0,0,0,0,300,600,'',1,1,10,1,1,4,1,0,0,1,0,0,0,'npc_invasion_mob',12340),
(400327,0,0,0,0,0,'Zandalari Scout',NULL,NULL,0,80,80,2,16,0,1.4,1.42857,1.3,0,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,7,0,0,0,0,0,0,250,500,'',1,1,8,1,1,3.5,1,0,0,1,0,0,0,'npc_invasion_mob',12340),
(400328,0,0,0,0,0,'Zandalari Spearman',NULL,NULL,0,80,80,2,16,0,1.2,1.28571,1.3,0,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,7,0,0,0,0,0,0,300,600,'',1,1,10,1,1.5,4,1,0,0,1,0,0,0,'npc_invasion_mob',12340);

-- Wave 2: Zandalari Warriors (400329-400331) - Hardened veterans, bigger and stronger
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400329,0,0,0,0,0,'Zandalari Warrior',NULL,NULL,0,80,80,2,16,0,1.2,1.28571,1.35,0,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,7,0,0,0,0,0,0,400,700,'',1,1,14,1,1.5,5,1,0,0,1,0,0,0,'npc_invasion_mob',12340),
(400330,0,0,0,0,0,'Zandalari Berserker',NULL,NULL,0,81,81,2,16,0,1.2,1.42857,1.45,1,0,1800,2000,1,1,1,32832,2048,0,0,0,0,0,0,7,0,0,0,0,0,0,500,850,'',1,1,18,1,1.5,6,1,0,0,1,0,0,128,'npc_invasion_mob',12340),
(400331,0,0,0,0,0,'Zandalari Shadow Hunter',NULL,NULL,0,80,80,2,16,0,1.2,1.14286,1.35,0,0,2000,2000,1,1,2,32832,2048,0,0,0,0,0,0,7,0,0,0,0,0,0,350,650,'',1,1,12,5,1,4.5,1,0,0,1,0,0,0,'npc_invasion_mob',12340);

-- Wave 3: Zandalari Elite Squad (400332-400334) - Elite troops, larger scale, deadlier
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400332,0,0,0,0,0,'Zandalari Blood Guard',NULL,NULL,0,81,81,2,16,0,1.2,1.28571,1.5,1,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,7,0,0,0,0,0,0,600,1000,'',1,1,22,1,2,7,1,0,0,1,0,0,128,'npc_invasion_mob',12340),
(400333,0,0,0,0,0,'Zandalari Witch Doctor',NULL,NULL,0,81,81,2,16,0,1,1.14286,1.45,1,5,2000,2000,1,1,2,32832,2048,0,0,0,0,0,0,7,0,0,0,0,0,0,500,900,'',1,1,18,8,1.5,5.5,1,0,0,1,0,0,128,'npc_invasion_mob',12340),
(400334,0,0,0,0,0,'Zandalari Beast Tamer',NULL,NULL,0,81,81,2,16,0,1.2,1.28571,1.45,1,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,7,0,0,0,0,0,0,550,950,'',1,1,20,1,1.5,6.5,1,0,0,1,0,0,128,'npc_invasion_mob',12340);

-- Wave 3 Add: War Raptor (summoned by Beast Tamer)
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400335,0,0,0,0,0,'Zandalari War Raptor',NULL,NULL,0,80,80,2,16,0,2.0,1.71429,1.3,0,0,1500,2000,1,1,1,32832,2048,0,37,0,0,0,0,1,0,0,0,0,0,0,0,0,'',1,1,10,1,1,5,1,0,0,1,0,0,0,'npc_invasion_mob',12340);

-- Wave 4: Invasion Commander (Mini-Boss) - Towering warlord, massive and terrifying
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400336,0,0,0,0,0,'Warlord Zul\'mar','Invasion Commander',NULL,0,82,82,2,16,0,1.2,1.28571,1.5,2,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,7,76,0,0,0,0,0,2000,3500,'',1,1,60,1,2.5,12,2,0,0,1,617299967,0,128,'npc_invasion_commander',12340);

-- Wave 4 Guards (spawn with boss) - Elite bodyguards, large and heavily armored
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400337,0,0,0,0,0,'Zandalari Honor Guard',NULL,NULL,0,81,81,2,16,0,1.2,1.28571,1.2,1,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,7,0,0,0,0,0,0,700,1200,'',1,1,25,1,2,8,1,0,0,1,0,0,0,'npc_invasion_mob',12340);

-- ============================================================================
-- INVASION CREATURE TEXTS - Yells, taunts, and death cries
-- ============================================================================

DELETE FROM `creature_text` WHERE `CreatureID` IN (400326, 400327, 400328, 400329, 400330, 400331, 400332, 400333, 400334, 400335, 400336, 400337);
INSERT INTO `creature_text` (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`) VALUES
-- Wave 1: Scouts (aggressive but panicked)
(400326, 0, 0, 'For the Zandalari Empire!', 12, 0, 100, 0, 0, 0, 0, 0, 'Zandalari Invader - Aggro'),
(400326, 0, 1, 'These shores belong to Zandalar now!', 12, 0, 100, 0, 0, 0, 0, 0, 'Zandalari Invader - Aggro'),
(400326, 0, 2, 'Push forward! Drive them back!', 12, 0, 100, 0, 0, 0, 0, 0, 'Zandalari Invader - Aggro'),
(400326, 1, 0, 'I... I fall...', 12, 0, 100, 0, 0, 0, 0, 0, 'Zandalari Invader - Death'),
(400326, 1, 1, 'Reinforcements... coming...', 12, 0, 100, 0, 0, 0, 0, 0, 'Zandalari Invader - Death'),

(400327, 0, 0, 'You will not stop us!', 12, 0, 100, 0, 0, 0, 0, 0, 'Zandalari Scout - Aggro'),
(400327, 0, 1, 'The beach will be ours!', 12, 0, 100, 0, 0, 0, 0, 0, 'Zandalari Scout - Aggro'),
(400327, 1, 0, 'Tell... the Warlord... we failed...', 12, 0, 100, 0, 0, 0, 0, 0, 'Zandalari Scout - Death'),

(400328, 0, 0, 'My spear thirsts for blood!', 12, 0, 100, 0, 0, 0, 0, 0, 'Zandalari Spearman - Aggro'),
(400328, 0, 1, 'None shall survive!', 12, 0, 100, 0, 0, 0, 0, 0, 'Zandalari Spearman - Aggro'),
(400328, 1, 0, 'Argh!', 12, 0, 100, 0, 0, 0, 0, 0, 'Zandalari Spearman - Death'),

-- Wave 2: Warriors (confident, battle-hardened)
(400329, 0, 0, 'Feel the wrath of Zandalar!', 12, 0, 100, 0, 0, 0, 0, 0, 'Zandalari Warrior - Aggro'),
(400329, 0, 1, 'Your bones will decorate our ships!', 12, 0, 100, 0, 0, 0, 0, 0, 'Zandalari Warrior - Aggro'),
(400329, 0, 2, 'The Zandalari crush all who oppose us!', 12, 0, 100, 0, 0, 0, 0, 0, 'Zandalari Warrior - Aggro'),
(400329, 1, 0, 'I die... with honor...', 12, 0, 100, 0, 0, 0, 0, 0, 'Zandalari Warrior - Death'),

(400330, 0, 0, 'BLOOD! I SMELL BLOOD!', 14, 0, 100, 0, 0, 0, 0, 0, 'Zandalari Berserker - Aggro'),
(400330, 0, 1, 'I WILL FEAST ON YOUR FLESH!', 14, 0, 100, 0, 0, 0, 0, 0, 'Zandalari Berserker - Aggro'),
(400330, 0, 2, 'DIE! ALL OF YOU!', 14, 0, 100, 0, 0, 0, 0, 0, 'Zandalari Berserker - Aggro'),
(400330, 1, 0, 'NOOO! I wanted... more...', 12, 0, 100, 0, 0, 0, 0, 0, 'Zandalari Berserker - Death'),

(400331, 0, 0, 'The spirits favor our victory!', 12, 0, 100, 0, 0, 0, 0, 0, 'Zandalari Shadow Hunter - Aggro'),
(400331, 0, 1, 'Darkness will consume you!', 12, 0, 100, 0, 0, 0, 0, 0, 'Zandalari Shadow Hunter - Aggro'),
(400331, 0, 2, 'Your souls belong to the Loa!', 12, 0, 100, 0, 0, 0, 0, 0, 'Zandalari Shadow Hunter - Aggro'),
(400331, 1, 0, 'The spirits... abandon me...', 12, 0, 100, 0, 0, 0, 0, 0, 'Zandalari Shadow Hunter - Death'),

-- Wave 3: Elites (fanatical, terrifying)
(400332, 0, 0, 'You face the Blood Guard! Kneel or die!', 14, 0, 100, 0, 0, 0, 0, 0, 'Zandalari Blood Guard - Aggro'),
(400332, 0, 1, 'No mercy! No survivors!', 14, 0, 100, 0, 0, 0, 0, 0, 'Zandalari Blood Guard - Aggro'),
(400332, 0, 2, 'Your blood will honor the empire!', 14, 0, 100, 0, 0, 0, 0, 0, 'Zandalari Blood Guard - Aggro'),
(400332, 1, 0, 'This... cannot be...', 12, 0, 100, 0, 0, 0, 0, 0, 'Zandalari Blood Guard - Death'),

(400333, 0, 0, 'Behold the power of voodoo!', 12, 0, 100, 0, 0, 0, 0, 0, 'Zandalari Witch Doctor - Aggro'),
(400333, 0, 1, 'Your souls will serve me in death!', 12, 0, 100, 0, 0, 0, 0, 0, 'Zandalari Witch Doctor - Aggro'),
(400333, 0, 2, 'The Loa demand sacrifice!', 12, 0, 100, 0, 0, 0, 0, 0, 'Zandalari Witch Doctor - Aggro'),
(400333, 1, 0, 'The curse... is upon me...', 12, 0, 100, 0, 0, 0, 0, 0, 'Zandalari Witch Doctor - Death'),

(400334, 0, 0, 'My beasts will tear you apart!', 12, 0, 100, 0, 0, 0, 0, 0, 'Zandalari Beast Tamer - Aggro'),
(400334, 0, 1, 'Raptors! Attack!', 12, 0, 100, 0, 0, 0, 0, 0, 'Zandalari Beast Tamer - Aggro'),
(400334, 1, 0, 'My beasts... avenge me...', 12, 0, 100, 0, 0, 0, 0, 0, 'Zandalari Beast Tamer - Death'),

(400335, 0, 0, 'SCREEEECH!', 16, 0, 100, 0, 0, 0, 0, 0, 'War Raptor - Aggro'),
(400335, 1, 0, 'KREEEE!', 16, 0, 100, 0, 0, 0, 0, 0, 'War Raptor - Death'),

-- Boss: Warlord Zul'mar (handled in C++ with direct Yell calls)
(400336, 0, 0, 'You dare challenge Zul''mar?! Your bones will join the pile!', 14, 0, 100, 0, 0, 8856, 0, 0, 'Warlord Zul''mar - Aggro'),
(400336, 1, 0, 'You will ALL DIE! For Zandalar!', 14, 0, 100, 0, 0, 8863, 0, 0, 'Warlord Zul''mar - Enrage'),
(400336, 2, 0, 'Pathetic worm!', 12, 0, 100, 0, 0, 0, 0, 0, 'Warlord Zul''mar - Slay'),
(400336, 2, 1, 'Another skull for my collection!', 12, 0, 100, 0, 0, 0, 0, 0, 'Warlord Zul''mar - Slay'),
(400336, 3, 0, 'The Zandalari... will return... you have not won...', 14, 0, 100, 0, 0, 0, 0, 0, 'Warlord Zul''mar - Death'),

(400337, 0, 0, 'Protect the Warlord!', 12, 0, 100, 0, 0, 0, 0, 0, 'Honor Guard - Aggro'),
(400337, 0, 1, 'You shall not pass!', 12, 0, 100, 0, 0, 0, 0, 0, 'Honor Guard - Aggro'),
(400337, 1, 0, 'I have... failed...', 12, 0, 100, 0, 0, 0, 0, 0, 'Honor Guard - Death');

-- ============================================================================
-- BOSS ADDS / SPAWN CREATURES (400400-400450)
-- ============================================================================

-- Oondasta adds
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400400,0,0,0,0,0,'Young Oondasta','Spawn of Oondasta',NULL,0,80,80,2,14,0,2.0,1.71429,1.6,1,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,'',0,1,20,1,1.5,8,1,0,0,1,0,0,128,'npc_young_oondasta',12340);

-- Thok adds
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400401,0,0,0,0,0,'Frenzied Pack Raptor','Thok\'s Brood',NULL,0,80,80,2,14,0,2.5,2.14286,1.2,0,0,1500,2000,1,1,1,32832,2048,0,37,0,0,0,0,1,0,0,0,0,0,0,0,0,'',0,1,8,1,1,5,1,0,0,1,0,0,0,'npc_pack_raptor',12340);

-- Nalak adds
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400402,0,0,0,0,0,'Storm Spark','Lightning Elemental',NULL,0,80,80,2,14,0,1.4,1.14286,1.1,0,4,2000,2000,1,1,2,32832,2048,0,0,0,0,0,0,4,0,0,0,0,0,0,0,0,'',0,1,6,5,0.8,4,1,0,0,1,0,0,0,'npc_storm_spark',12340),
(400403,0,0,0,0,0,'Static Cloud','Nalak\'s Essence',NULL,0,80,80,2,14,0,0.5,0.5,1.3,0,4,2000,2000,1,1,2,33554432,2048,0,0,0,0,0,0,4,0,0,0,0,0,0,0,0,'',0,1,1,1,1,1,0,0,0,0,0,0,64,'npc_static_cloud',12340);

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

-- Zandalari NPCs (using ZG troll models - displayID 11288 male, 11287 female)
(400200, 0, 11288, 1, 1, 12340),   -- Elder Zul'jin
(400201, 0, 11287, 1, 1, 12340),   -- Witch Doctor Tala'jin (female)
(400202, 0, 11288, 1, 1, 12340),   -- Rokhan the Beast Tamer
(400203, 0, 11288, 1, 1, 12340),   -- Scout Zan'do
(400210, 0, 11288, 1, 1, 12340),   -- Trader Zal'aman
(400211, 0, 11288, 1, 1, 12340),   -- Armsmaster Jin'kala
(400220, 0, 11288, 1, 1, 12340),   -- Zandalari Expedition Guard
(400221, 0, 11288, 1, 1, 12340),   -- Zandalari Beast Handler

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
(400310, 0, 11288, 1, 1, 12340),   -- Bartender Zul'tik
(400311, 0, 11288, 1, 1, 12340),   -- Windwalker Ta'zo

-- Cannon Quest NPCs
-- Display IDs: 4422 = Human Sailor, 26788 = ICC Gunship Cannon, 10527 = Small Boat (rowboat-style)
-- Alternative displays: 21151 = Gnomish Cannon, 28535 = Northrend Ship, 30564 = Zeppelin Model
(400320, 0, 4422, 1, 1, 12340),    -- Captain Harlan (human sailor)
(400321, 0, 3146, 1.0, 1, 12340),  -- Coastal Cannon (Southsea Cannon display - known-good)
(400323, 0, 11686, 1, 1, 12340),   -- Ship Explosion Trigger (invisible)
(400324, 0, 28535, 2.0, 1, 12340), -- Zandalari Scout Ship (Northrend ship model, scaled up)

-- Invasion NPCs - Mixed troll models for variety, boss has unique intimidating model
(400325, 0, 3789, 1.5, 1, 12340),  -- Invasion Warning Horn (war drum)
(400326, 0, 11288, 1, 1, 12340),   -- Zandalari Invader (ZG troll standard)
(400327, 0, 11287, 1, 1, 12340),   -- Zandalari Scout (ZG troll leather)
(400328, 0, 11288, 1, 1, 12340),   -- Zandalari Spearman (ZG troll standard)
(400329, 0, 11290, 1.05, 1, 12340),   -- Zandalari Warrior (ZG troll plate, larger)
(400330, 0, 11289, 1.1, 1, 12340),-- Zandalari Berserker (ZG troll naked, larger)
(400331, 0, 11291, 1.05, 1, 12340),   -- Zandalari Shadow Hunter (ZG troll shaman, larger)
(400332, 0, 11293, 1.15, 1, 12340), -- Zandalari Blood Guard (ZG troll champion, larger)
(400333, 0, 11292, 1.1, 1, 12340),   -- Zandalari Witch Doctor (ZG troll priest, larger)
(400334, 0, 11288, 1.1, 1, 12340),   -- Zandalari Beast Tamer (ZG troll standard, larger)
(400335, 0, 5291, 1, 1, 12340),    -- Zandalari War Raptor
(400336, 0, 11295, 1.5, 1, 12340), -- Warlord Zul'mar (ZG boss troll, LARGEST)
(400337, 0, 11293, 1.2, 1, 12340),-- Zandalari Honor Guard (ZG champion, large)

-- Boss Adds
(400400, 0, 5239, 1.2, 1, 12340),  -- Young Oondasta
(400401, 0, 5290, 0.9, 1, 12340),  -- Frenzied Pack Raptor
(400402, 0, 7848, 0.8, 1, 12340),  -- Storm Spark (lightning elemental - water elemental model)
(400403, 0, 11686, 1, 1, 12340);   -- Static Cloud (cloud visual)

-- ============================================================================
-- CREATURE_TEMPLATE_ADDON - Auras and visual effects
-- ============================================================================

DELETE FROM `creature_template_addon` WHERE `entry` BETWEEN 400000 AND 400999;

INSERT INTO `creature_template_addon` (`entry`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `visibilityDistanceType`, `auras`) VALUES
-- Basic Dinosaurs - Extended visibility (normal creatures get visibility type 3 - Large)
(400000, 0, 0, 0, 0, 0, 3, ''),        -- Chaos Devilsaur
(400001, 0, 0, 0, 0, 0, 3, '28126'),   -- Ironhide Chaos Devilsaur
(400002, 0, 0, 0, 0, 0, 3, '28126'),   -- Tyrant Chaos Devilsaur
(400003, 0, 0, 0, 0, 0, 3, ''),        -- Primal Stegodon
(400004, 0, 0, 0, 0, 0, 3, ''),        -- Elder Stegodon
(400005, 0, 0, 0, 0, 0, 3, '28126'),   -- Armored Stegodon
(400006, 0, 0, 0, 0, 0, 3, '28126'),   -- Ancient Stegodon
(400007, 0, 0, 0, 0, 0, 3, ''),        -- Chaos Raptor
(400008, 0, 0, 0, 0, 0, 3, ''),        -- Chaos Raptor Runner
(400009, 0, 0, 0, 0, 0, 3, ''),        -- Chaos Raptor Hunter
(400010, 0, 0, 0, 0, 0, 3, '28126'),   -- Venomhide Chaos Raptor
(400011, 0, 0, 0, 0, 0, 3, ''),        -- Fledgling Chaos Pterrordax
(400012, 0, 0, 0, 0, 0, 3, ''),        -- Chaos Pterrordax
(400013, 0, 0, 0, 0, 0, 3, '28126'),   -- Frenzied Chaos Pterrordax
(400014, 0, 0, 0, 0, 0, 3, ''),        -- Young Primal Diemetradon
(400015, 0, 0, 0, 0, 0, 3, ''),        -- Primal Diemetradon
(400016, 0, 0, 0, 0, 0, 3, '28126'),   -- Elder Primal Diemetradon
-- Rare Elite Dinosaurs - Gigantic visibility (rare spawns get visibility type 4)
(400050, 0, 0, 0, 0, 0, 4, '28126'),   -- Primal Direhorn
(400051, 0, 0, 0, 0, 0, 4, '28126'),   -- Chaos Rex
(400052, 0, 0, 0, 0, 0, 4, '28126'),   -- Ancient Primordial
(400053, 0, 0, 0, 0, 0, 4, '28126'),   -- Savage Stegodon Matriarch
(400054, 0, 0, 0, 0, 0, 4, '28126'),   -- Alpha Chaos Raptor
(400055, 0, 0, 0, 0, 0, 4, '28126'),   -- Bonecrusher (random rare)
(400056, 0, 0, 0, 0, 0, 4, '28126'),   -- Gorespine (random rare)
(400057, 0, 0, 0, 0, 0, 4, '28126'),   -- Venomfang (random rare)
(400058, 0, 0, 0, 0, 0, 4, '28126'),   -- Skyscreamer (random rare)
(400059, 0, 0, 0, 0, 0, 4, '28126'),   -- Gul'rok the Cursed (random rare)
-- World Bosses - Infinite visibility (bosses get visibility type 5)
(400100, 0, 0, 0, 0, 0, 5, '28126'),   -- Oondasta (max visibility)
(400101, 0, 0, 0, 0, 0, 5, '28126'),   -- Thok (max visibility)
(400102, 0, 0, 0, 0, 0, 5, '28126'),   -- Nalak (max visibility)
-- Zandalari Friendly NPCs - Extended visibility (NPCs get visibility type 3)
(400200, 0, 0, 0, 0, 0, 3, ''),        -- Elder Zul'jin
(400202, 0, 0, 0, 0, 0, 3, ''),        -- Rokhan the Beast Tamer
(400203, 0, 0, 0, 0, 0, 3, ''),        -- Scout Zan'do
(400210, 0, 0, 0, 0, 0, 3, ''),        -- Trader Zal'aman
(400220, 0, 0, 0, 0, 0, 3, ''),        -- Zandalari Expedition Guard
-- Hostile Primal Trolls - Extended visibility (mob creatures get visibility type 3)
(400250, 0, 0, 0, 0, 0, 3, ''),        -- Primal Troll Warrior
(400251, 0, 0, 0, 0, 0, 3, ''),        -- Primal Troll Shadowcaster
(400252, 0, 0, 0, 0, 0, 3, ''),        -- Primal Troll Berserker
(400253, 0, 0, 0, 0, 0, 3, ''),        -- Primal Troll Witch Doctor
(400254, 0, 0, 0, 0, 0, 3, ''),        -- Primal Troll Headhunter
(400260, 0, 0, 0, 0, 0, 4, '28126'),   -- Warlord Gha'tul
-- Special NPCs - Extended visibility
(400300, 0, 0, 0, 0, 0, 3, '10848'),   -- Spirit of the Primal (ghost aura)
(400301, 0, 0, 0, 0, 0, 3, '28126'),   -- Corrupted Direhorn Spirit
(400310, 0, 0, 0, 0, 0, 3, ''),        -- Bartender Zul'tik
(400311, 0, 0, 0, 0, 0, 3, ''),        -- Windwalker Ta'zo
-- Cannon Quest NPCs - Increased visibility for ship and cannon
(400321, 0, 0, 0, 0, 0, 5, ''),        -- Coastal Cannon (max visibility)
(400323, 0, 0, 0, 0, 0, 5, ''),        -- Ship Explosion Trigger
(400324, 0, 0, 0, 0, 0, 5, ''),        -- Zandalari Scout Ship (max visibility)
(400325, 0, 0, 0, 0, 0, 3, ''),        -- Invasion Warning Horn
-- Invasion NPCs - Extended visibility (mobs get type 3, NPCs get type 3, boss gets type 5)
(400326, 0, 0, 0, 0, 0, 3, ''),        -- Zandalari Invader
(400327, 0, 0, 0, 0, 0, 3, ''),        -- Zandalari Scout
(400328, 0, 0, 0, 0, 0, 3, ''),        -- Zandalari Spearman
(400329, 0, 0, 0, 0, 0, 3, ''),        -- Zandalari Warrior
(400330, 0, 0, 0, 0, 0, 3, ''),        -- Zandalari Berserker
(400331, 0, 0, 0, 0, 0, 3, ''),        -- Zandalari Shadow Hunter
(400332, 0, 0, 0, 0, 0, 3, ''),        -- Zandalari Blood Guard
(400333, 0, 0, 0, 0, 0, 3, ''),        -- Zandalari Witch Doctor
(400334, 0, 0, 0, 0, 0, 3, ''),        -- Zandalari Beast Tamer
(400335, 0, 0, 0, 0, 0, 3, ''),        -- Zandalari War Raptor
(400336, 0, 0, 0, 0, 0, 5, '28126'),   -- Warlord Zul'mar (boss aura + max visibility)
(400337, 0, 0, 0, 0, 0, 3, ''),        -- Zandalari Honor Guard
-- Boss Adds - Large visibility for visibility
(400400, 0, 0, 0, 0, 0, 3, ''),        -- Young Oondasta
(400401, 0, 0, 0, 0, 0, 3, ''),        -- Frenzied Pack Raptor
(400402, 0, 0, 0, 0, 0, 3, ''),        -- Storm Spark
(400403, 0, 0, 0, 0, 0, 3, '');        -- Static Cloud

-- ============================================================================
-- GUARDS AND DEFENDERS (401000-401099)
-- Level 80 normal, 81 elite, 82 rare elite
-- ============================================================================

DELETE FROM `creature_template` WHERE `entry` BETWEEN 401000 AND 401099;
INSERT INTO `creature_template` (`entry`, `name`, `subname`, `minlevel`, `maxlevel`, `faction`, `npcflag`, `rank`, `type`, `unit_class`, `unit_flags`, `BaseAttackTime`, `RangeAttackTime`, `HealthModifier`, `DamageModifier`, `ArmorModifier`, `mingold`, `maxgold`, `AIName`, `MovementType`, `ScriptName`) VALUES
-- Alliance Guards (Jurassic Expedition)
(401000, 'Primal Warden', 'Jurassic Expedition', 80, 80, 1735, 0, 0, 7, 1, 0, 2000, 2000, 2.0, 1.5, 1.0, 0, 0, '', 1, ''),
(401001, 'Primal Warden Sergeant', 'Jurassic Expedition', 81, 81, 1735, 0, 1, 7, 1, 0, 2000, 2000, 4.0, 2.0, 1.5, 0, 0, '', 1, ''),
(401002, 'Primal Warden Marksman', 'Jurassic Expedition', 80, 80, 1735, 0, 0, 7, 1, 0, 2000, 2000, 1.8, 1.5, 0.8, 0, 0, '', 1, ''),
(401003, 'Primal Warden Captain', 'Jurassic Expedition', 82, 82, 1735, 0, 2, 7, 1, 0, 2000, 2000, 8.0, 3.0, 2.0, 0, 0, '', 0, ''),
-- Horde Guards (Beast Hunters)
(401004, 'Beast Hunter', 'Primal Horde', 80, 80, 1734, 0, 0, 7, 1, 0, 2000, 2000, 2.0, 1.5, 1.0, 0, 0, '', 1, ''),
(401005, 'Beast Hunter Veteran', 'Primal Horde', 81, 81, 1734, 0, 1, 7, 1, 0, 2000, 2000, 4.0, 2.0, 1.5, 0, 0, '', 1, ''),
(401006, 'Beast Hunter Trapper', 'Primal Horde', 80, 80, 1734, 0, 0, 7, 1, 0, 2000, 2000, 1.8, 1.5, 0.8, 0, 0, '', 1, ''),
(401007, 'Beast Hunter Warlord', 'Primal Horde', 82, 82, 1734, 0, 2, 7, 1, 0, 2000, 2000, 8.0, 3.0, 2.0, 0, 0, '', 0, ''),
-- Neutral Guards (Primal Wardens Faction)
(401008, 'Primal Guardian', 'Primal Wardens', 81, 81, 35, 0, 1, 7, 1, 0, 2000, 2000, 5.0, 2.5, 1.5, 0, 0, '', 1, ''),
(401009, 'Ancient Primal Guardian', 'Primal Wardens', 82, 82, 35, 0, 2, 7, 1, 0, 2000, 2000, 10.0, 4.0, 2.0, 0, 0, '', 0, '');

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
(401115, 'Banker Goldtusk', 'Banker', 400115, 80, 80, 35, 134217857, 0, 7, 1, 0, 1.0, '', 0);

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
-- Use Stormwind Guard display (base: creature 68 -> display 3167)
(401000, 0, 3167, 1, 1, 12340),  -- Primal Warden
(401001, 0, 3167, 1, 1, 12340),  -- Primal Warden Sergeant
(401002, 0, 3167, 1, 1, 12340),  -- Primal Warden Marksman
(401003, 0, 3167, 1.1, 1, 12340), -- Primal Warden Captain
-- Horde Guards (Orc models)
(401004, 0, 4259, 1, 1, 12340),  -- Beast Hunter (Orc Male)
(401005, 0, 4259, 1, 1, 12340),  -- Beast Hunter Veteran
(401006, 0, 4259, 1, 1, 12340),  -- Beast Hunter Trapper
(401007, 0, 4259, 1.1, 1, 12340), -- Beast Hunter Warlord
-- Alliance-aligned Guards (use Alliance models; avoid Tauren/Undead)
(401008, 0, 2095, 1, 1, 12340),  -- Primal Guardian (Human Male)
(401009, 0, 2095, 1.1, 1, 12340), -- Ancient Primal Guardian
-- Alliance Service NPCs
-- Use base Alliance displays:
-- - Gnome Male Mage Trainer (creature 5961 -> display 2891)
-- - Human Female Innkeeper (creature 6740 -> display 5444)
-- - Stormwind Gryphon Master (creature 352 -> display 5128)
(401100, 0, 2891, 1, 1, 12340), -- Beeble Cogsworth (Gnome Male)
(401101, 0, 2891, 1, 1, 12340), -- Tinker Sprocketwrench (Gnome Male)
(401102, 0, 5444, 1, 1, 12340), -- Emily Stormwind (Human Female)
(401103, 0, 5128, 1, 1, 12340), -- Flight Master Aldric (Human Male - Gryphon Master)
(401104, 0, 5444, 1, 1, 12340), -- Innkeeper Molly (Human Female)
-- Horde Service NPCs
(401105, 0, 7110, 0.8, 1, 12340),  -- Bozzle (Goblin Male)
(401106, 0, 7110, 0.8, 1, 12340),  -- Grizzek Fizzlecrank
(401107, 0, 19340, 0.8, 1, 12340), -- Zasha (Goblin Female)
(401108, 0, 4259, 1, 1, 12340),    -- Flight Master Krag
(401109, 0, 4259, 1, 1, 12340),    -- Innkeeper Grok
-- Neutral Service NPCs
(401110, 0, 11288, 1, 1, 12340), -- Ku'ma (Zandalari Troll)
(401111, 0, 2095, 1, 1, 12340),  -- Safari Trainer Rex (Human Male)
(401112, 0, 6930, 1, 1, 12340),  -- Professor Ironpaw (Dwarf)
(401113, 0, 2095, 1, 1, 12340),  -- Primal Quartermaster (Human Male)
(401114, 0, 2095, 1, 1, 12340),  -- Stable Master Thornhide (Human Male)
(401115, 0, 7110, 0.8, 1, 12340), -- Banker Goldtusk (Goblin)
-- Quest Givers
(401200, 0, 2095, 1.1, 1, 12340), -- Commander Stonewall (Human)
(401201, 0, 7125, 0.7, 1, 12340), -- Dr. Zira Fossildigger (Gnome Female)
(401202, 0, 2095, 1, 1, 12340),  -- Huntmaster Grimtusk (Human Male)
(401203, 0, 2095, 1, 1, 12340),  -- Sage Primalwisdom (Human Male)
(401210, 0, 2095, 1, 1, 12340), -- Raptor Handler Ka'zak (Human Male)
(401211, 0, 2095, 1, 1, 12340), -- Bone Collector Maz'gor (Human Male)
(401212, 0, 2095, 1, 1, 12340), -- Scout Shadowtooth (Human Male)
(401220, 0, 2095, 1, 1, 12340),  -- Oondasta Tracker Grull (Human Male)
(401221, 0, 2095, 1, 1, 12340), -- Thok Pursuer Raz'jin (Human Male)
(401222, 0, 3882, 1, 1, 12340);  -- Storm Chaser Volta (Human Female)

-- ============================================================================
-- CANNON QUEST DATA - Quest, Gossip, and Waypoints
-- Quest ID: 80100 - "Sink the Zandalari Scout"
-- ============================================================================

-- Captain Harlan Gossip
DELETE FROM `npc_text` WHERE `ID` = 400320;
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextId0`, `lang0`, `Probability0`) VALUES
(400320, 'Soldier! Those blasted Zandalari have been sending scout ships to spy on our defenses. We''ve set up a coastal cannon to deal with them, but I need someone with a steady aim.', '', 0, 0, 1);

DELETE FROM `gossip_menu` WHERE `MenuId` = 400320;
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
    400324, 0, 0, 0,                 -- RequiredNpcOrGo 1-4 (400324 = ship hitbox creature)
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

-- Ship Waypoint Path - Giant Isles Map 1405
-- Path ID: 4003220 (NPC Entry * 10)
-- This defines the patrol route for the scout ship
DELETE FROM `waypoint_data` WHERE `id` = 4003220;
INSERT INTO `waypoint_data` (`id`, `point`, `position_x`, `position_y`, `position_z`, `orientation`, `delay`, `move_type`, `action`, `action_chance`, `wpguid`) VALUES
-- Ship patrol route along the coast (Map 1405 - Giant Isles)
(4003220, 1, 5835.31, 1738.56, -2.14912, 4.04833, 30, 1, 0, 100, 0),  -- ship1
(4003220, 2, 5818.97, 1710.45, -2.14912, 4.45752, 30, 1, 0, 100, 0),  -- ship2
(4003220, 3, 5810.44, 1682.94, -2.14912, 4.34914, 30, 1, 0, 100, 0),  -- ship3
(4003220, 4, 5798.67, 1654.80, -2.14912, 4.22426, 30, 1, 0, 100, 0),  -- ship4
(4003220, 5, 5760.13, 1617.10, -2.14912, 3.82842, 30, 1, 0, 100, 0),  -- ship5
(4003220, 6, 5730.02, 1598.58, -2.14912, 3.61636, 30, 1, 0, 100, 0),  -- ship6
(4003220, 7, 5702.56, 1587.03, -2.14912, 3.48441, 30, 1, 0, 100, 0),  -- ship7
(4003220, 8, 5684.10, 1578.87, -2.14912, 3.65877, 30, 1, 0, 100, 0),  -- ship8
(4003220, 9, 5665.86, 1563.35, -2.14912, 3.96272, 30, 1, 0, 100, 0);  -- ship9

-- ============================================================================
-- CREATURE SPAWNS - Cannon Quest NPCs
-- Map 1405 (Giant Isles)
-- ============================================================================

DELETE FROM `creature` WHERE `guid` IN (9000132, 9000133);
INSERT INTO `creature` (`guid`, `id1`, `id2`, `id3`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`, `CreateObject`, `Comment`) VALUES
-- Coastal Cannon (Vehicle) - Entry 400321
(9000132, 400321, 0, 0, 1405, 0, 0, 1, 1, 0, 5818.28, 1555.64, 46.1046, 2.40827, 300, 0, 0, 1260000, 0, 0, 0, 0, 0, '', NULL, 0, 'Giant Isles - Coastal Cannon'),
-- Captain Harlan (Quest Giver) - Entry 400320 - Positioned near the cannon
(9000133, 400320, 0, 0, 1405, 0, 0, 1, 1, 0, 5812.94, 1550.37, 45.5279, 5.60106, 300, 0, 0, 126000, 0, 0, 0, 0, 0, '', NULL, 0, NULL);

-- ============================================================================
-- ANCIENT WATER CREATURES (400060-400069)
-- ============================================================================

-- Primal Threshadon (Elite) - Entry 400060
-- Model: 995 (Deep Sea Threshadon - actual dinosaur model)
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400060,0,0,0,0,0,'Primal Threshadon',NULL,NULL,0,80,80,2,14,0,1.0,1.14286,1.8,1,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,0,0,0,0,0,0,800,1200,'',1,1,25,1,1.5,8,1,0,0,1,0,0,0,'',12340);

-- Primal Crocodile - Entry 400061
-- Model: 2549 (Crocodile/Crocolisk model)
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400061,0,0,0,0,0,'Primal Crocodile',NULL,NULL,0,80,80,2,14,0,0.8,1.0,1.5,0,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,0,0,0,0,0,0,500,800,'',1,1,20,1,2.0,5,1,0,0,1,0,0,0,'',12340);

-- Abyssal Sea Serpent (Elite) - Entry 400062
-- Model: 15182 (Razzashi Serpent - proper sea serpent)
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400062,0,0,0,0,0,'Abyssal Sea Serpent',NULL,NULL,0,81,81,2,14,0,1.2,1.4,1.2,1,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,0,0,0,0,0,0,1000,1500,'',1,1,30,1,1.5,10,1,0,0,1,0,0,0,'',12340);

-- ============================================================================
-- CAVE CREATURES (400070-400079)
-- ============================================================================

-- Cavernous Pterrordax - Entry 400070
-- Model: 9166 (Dark Pterrordax)
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400070,0,0,0,0,0,'Cavernous Pterrordax',NULL,NULL,0,80,80,2,14,0,1.6,1.14286,1.0,0,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,0,0,0,0,0,0,400,700,'',1,1,12,1,1.0,4,1,0,0,1,0,0,0,'',12340);

-- Subterranean Saurok - Entry 400071
-- Model: 46068 (Saurok)
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400071,0,0,0,0,0,'Subterranean Saurok',NULL,NULL,0,80,80,2,14,0,1.4,1.14286,1.0,0,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,7,0,0,0,0,0,0,500,800,'',1,1,15,1,1.2,5,1,0,0,1,0,0,0,'',12340);

-- Crystal Spine Spider - Entry 400072
-- Model: 4263 (Crystal Spider)
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400072,0,0,0,0,0,'Crystal Spine Spider',NULL,NULL,0,80,80,2,14,0,1.4,1.14286,1.2,0,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,1,0,0,0,0,0,0,400,600,'',1,1,10,1,1.0,4,1,0,0,1,0,0,0,'',12340);

-- ============================================================================
-- CREATURE EQUIPMENT TEMPLATES
-- ============================================================================
-- Equipment IDs follow AzerothCore standard equipment_template table format
-- Equipment slots: 1 = Main Hand, 2 = Off Hand, 3 = Ranged
-- ============================================================================

DELETE FROM `creature_equip_template` WHERE `CreatureID` BETWEEN 400000 AND 401999;

-- Zandalari NPCs Equipment
INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`) VALUES
-- Quest Givers
(400200, 1, 12584, 0, 0, 12340),      -- Elder Zul'jin - Troll Staff
(400201, 1, 5598, 0, 0, 12340),       -- Witch Doctor Tala'jin - Tribal Wand
(400202, 1, 12748, 0, 2506, 12340),   -- Rokhan the Beast Tamer - Axe + Crossbow
(400203, 1, 12584, 12651, 0, 12340),  -- Scout Zan'do - Spear + Shield

-- Vendors
(400210, 1, 12584, 0, 0, 12340),      -- Trader Zal'aman - Staff
(400211, 1, 44504, 44504, 0, 12340),  -- Armsmaster Jin'kala - Dual Troll Axes

-- Zandalari Guards
(400220, 1, 12749, 12651, 0, 12340),  -- Zandalari Expedition Guard - Sword + Shield
(400221, 1, 12748, 0, 2506, 12340),   -- Zandalari Beast Handler - Axe + Crossbow

-- Hostile Primal Trolls
(400250, 1, 12749, 12651, 0, 12340),  -- Primal Troll Warrior - Sword + Shield
(400251, 1, 5598, 0, 0, 12340),       -- Primal Troll Shadowcaster - Wand
(400252, 1, 12748, 12748, 0, 12340),  -- Primal Troll Berserker - Dual Axes
(400253, 1, 12584, 0, 0, 12340),      -- Primal Troll Witch Doctor - Staff
(400254, 1, 12584, 0, 2506, 12340),   -- Primal Troll Headhunter - Spear + Bow
(400260, 1, 13160, 12651, 0, 12340),  -- Warlord Gha'tul - 2H Sword + Shield

-- Captain Harlan (Human Sailor)
(400320, 1, 13160, 0, 2507, 12340),   -- Captain Harlan - 2H Sword + Rifle

-- Alliance Guards (Primal Wardens)
(401000, 1, 12749, 12651, 0, 12340),  -- Primal Warden - Sword + Shield
(401001, 1, 13160, 12651, 0, 12340),  -- Primal Warden Sergeant - 2H Sword + Shield
(401002, 1, 12749, 0, 2507, 12340),   -- Primal Warden Marksman - Sword + Rifle
(401003, 1, 13160, 13160, 0, 12340),  -- Primal Warden Captain - Dual Epic Swords

-- Horde Guards (Beast Hunters)
(401004, 1, 12748, 12651, 0, 12340),  -- Beast Hunter - Axe + Shield
(401005, 1, 13160, 12651, 0, 12340),  -- Beast Hunter Veteran - 2H Sword + Shield
(401006, 1, 12748, 0, 2506, 12340),   -- Beast Hunter Trapper - Axe + Crossbow
(401007, 1, 13160, 13160, 0, 12340),  -- Beast Hunter Warlord - Dual Epic Axes

-- Neutral Guards (Primal Guardians - Tauren)
(401008, 1, 13160, 12651, 0, 12340),  -- Primal Guardian - 2H Sword + Shield
(401009, 1, 13160, 13160, 0, 12340),  -- Ancient Primal Guardian - Dual Epic Maces

-- Alliance Service NPCs
(401101, 1, 5956, 0, 0, 12340),       -- Tinker Sprocketwrench - Wrench
(401102, 1, 0, 0, 0, 12340),          -- Emily Stormwind - No weapon
(401103, 1, 12749, 0, 0, 12340),      -- Flight Master Aldric - Sword
(401104, 1, 0, 0, 0, 12340),          -- Innkeeper Molly - No weapon

-- Horde Service NPCs
(401106, 1, 5956, 0, 0, 12340),       -- Grizzek Fizzlecrank - Wrench
(401107, 1, 0, 0, 0, 12340),          -- Zasha - No weapon
(401108, 1, 12748, 0, 0, 12340),      -- Flight Master Krag - Axe
(401109, 1, 0, 0, 0, 12340),          -- Innkeeper Grok - No weapon

-- Neutral Service NPCs
(401110, 1, 12584, 0, 0, 12340),      -- Ku'ma (Bone Collector) - Staff
(401111, 1, 12748, 0, 0, 12340),      -- Safari Trainer Rex - Axe
(401112, 1, 12584, 0, 0, 12340),      -- Professor Ironpaw - Staff
(401113, 1, 12749, 12651, 0, 12340),  -- Primal Quartermaster - Sword + Shield
(401114, 1, 12748, 0, 0, 12340),      -- Stable Master Thornhide - Axe
(401115, 1, 0, 0, 0, 12340),          -- Banker Goldtusk - No weapon

-- Quest Givers
(401200, 1, 13160, 12651, 0, 12340),  -- Commander Stonewall - 2H Sword + Shield
(401201, 1, 12584, 0, 0, 12340),      -- Dr. Zira Fossildigger - Staff
(401202, 1, 12748, 0, 2506, 12340),   -- Huntmaster Grimtusk - Axe + Crossbow
(401203, 1, 12584, 0, 0, 12340),      -- Sage Primalwisdom - Staff
(401210, 1, 12584, 0, 2506, 12340),   -- Raptor Handler Ka'zak - Spear + Bow
(401211, 1, 12584, 0, 0, 12340),      -- Bone Collector Maz'gor - Staff
(401212, 1, 12749, 12651, 0, 12340),  -- Scout Shadowtooth - Sword + Shield
(401220, 1, 13160, 0, 2506, 12340),   -- Oondasta Tracker Grull - 2H Sword + Bow
(401221, 1, 12584, 0, 2506, 12340),   -- Thok Pursuer Raz'jin - Spear + Bow
(401222, 1, 12584, 0, 0, 12340),      -- Storm Chaser Volta - Staff

-- Invasion NPCs Equipment - Better weapons for higher waves, EPIC for boss
(400326, 1, 12749, 12651, 0, 12340),  -- Zandalari Invader - Sword + Shield
(400327, 1, 12584, 0, 2506, 12340),   -- Zandalari Scout - Spear + Crossbow
(400328, 1, 12584, 12651, 0, 12340),  -- Zandalari Spearman - Spear + Shield
(400329, 1, 13160, 12651, 0, 12340),  -- Zandalari Warrior - 2H Sword + Shield
(400330, 1, 44504, 44504, 0, 12340),  -- Zandalari Berserker - Dual Axes
(400331, 1, 12584, 0, 2506, 12340),   -- Zandalari Shadow Hunter - Staff + Bow
(400332, 1, 13160, 12651, 0, 12340),  -- Zandalari Blood Guard - Epic Axe + Shield
(400333, 1, 13396, 0, 0, 12340),       -- Zandalari Witch Doctor - Epic Staff
(400334, 1, 13160, 0, 2506, 12340),   -- Zandalari Beast Tamer - 2H Sword + Bow
(400336, 1, 50730, 50729, 0, 12340),  -- Warlord Zul'mar - Dual Epic Blades (Glorenzelg)
(400337, 1, 13160, 12651, 0, 12340);  -- Zandalari Honor Guard - Epic Axe + Shield

-- ============================================================================
-- INVASION HORN FIX
-- ============================================================================
DELETE FROM `npc_text` WHERE `ID` = 400325;
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextId0`, `lang0`, `Probability0`) VALUES 
(400325, 'The horn is ancient and covered in Zandalari carvings. Sounding it will surely alert the invaders... and rally our defenders.', '', 0, 0, 1);

DELETE FROM `gossip_menu` WHERE `MenuId` = 400325;
INSERT INTO `gossip_menu` (`MenuId`, `TextId`) VALUES (400325, 400325);

UPDATE `creature_template` SET `gossip_menu_id` = 400325 WHERE `entry` = 400325;

-- ============================================================================
-- CREATURE MODELS & INHABIT TYPES
-- ============================================================================

-- Note: creature_model_info entries for DisplayIDs 9166 and 46068 should already exist
-- If they don't exist in your DBC, replace with valid display IDs from creature_model_info

-- Add models for new creatures
DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN 400060 AND 400072;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(400060, 0, 995, 1.0, 1, 12340),   -- Primal Threshadon (Threshadon model - verified)
(400061, 0, 2549, 1.0, 1, 12340),  -- Primal Crocodile (Crocolisk model - verified)
(400062, 0, 15182, 1.0, 1, 12340), -- Abyssal Sea Serpent (Razzashi Serpent - verified)
(400070, 0, 8410, 1.0, 1, 12340),  -- Cavernous Pterrordax (Using 8410 instead of 9166)
(400071, 0, 11288, 1.0, 1, 12340), -- Subterranean Saurok (Using ZG troll model instead of 46068)
(400072, 0, 4263, 1.0, 1, 12340);  -- Crystal Spine Spider (Crystal Spider - verified)

-- Update InhabitType for Water Creatures
-- Using creature_template_movement table (Ground, Swim, Flight, Rooted)
DELETE FROM `creature_template_movement` WHERE `CreatureId` BETWEEN 400060 AND 400072;
DELETE FROM `creature_template_movement` WHERE `CreatureId` = 400324;
INSERT INTO `creature_template_movement` (`CreatureId`, `Ground`, `Swim`, `Flight`, `Rooted`) VALUES
(400060, 1, 1, 0, 0), -- Threshadon (Water/Ground)
(400061, 1, 1, 0, 0), -- Crocodile (Water/Ground)
(400062, 0, 1, 0, 0), -- Sea Serpent (Water Only)
(400070, 1, 0, 1, 0), -- Pterrordax (Air/Ground)
(400324, 0, 1, 0, 0); -- Zandalari Scout Ship (Water Only)

-- ============================================================================
-- SMART_SCRIPTS - Invasion NPCs
-- ============================================================================
DELETE FROM `smart_scripts` WHERE `entryorguid` BETWEEN 400326 AND 400337 AND `source_type` = 0;

-- 400326: Zandalari Invader (Warrior)
-- Event 0: In Combat - Charge (Range 8-25)
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
(400326, 0, 0, 0, 0, 0, 100, 0, 3000, 3000, 8000, 25000, 11, 11578, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 'Invader - Charge'),
(400326, 0, 1, 0, 0, 0, 100, 0, 5000, 7000, 0, 0, 11, 11976, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 'Invader - Strike');

-- 400327: Zandalari Scout (Rogue)
-- Event 0: In Combat - Sinister Strike
-- Event 1: HP < 30% - Evasion
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
(400327, 0, 0, 0, 0, 0, 100, 0, 4000, 6000, 0, 0, 11, 11971, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 'Scout - Sinister Strike'),
(400327, 0, 1, 0, 2, 0, 100, 0, 0, 30, 0, 0, 11, 5277, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 'Scout - Evasion');

-- 400328: Zandalari Spearman (Ranged)
-- Event 0: In Combat - Throw (Range 10-30)
-- Event 1: In Combat - Net (Random)
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
(400328, 0, 0, 0, 0, 0, 100, 0, 3000, 5000, 10000, 30000, 11, 10277, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 'Spearman - Throw'),
(400328, 0, 1, 0, 0, 0, 100, 0, 10000, 15000, 0, 0, 11, 6533, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 'Spearman - Net');

-- 400329: Zandalari Warrior (Tank)
-- Event 0: In Combat - Sunder Armor
-- Event 1: Target Casting - Shield Bash
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
(400329, 0, 0, 0, 0, 0, 100, 0, 5000, 8000, 0, 0, 11, 11971, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 'Warrior - Sunder Armor'),
(400329, 0, 1, 0, 8, 0, 100, 0, 0, 0, 0, 0, 11, 11972, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 'Warrior - Shield Bash');

-- 400330: Zandalari Berserker (DPS)
-- Event 0: In Combat - Cleave
-- Event 1: HP < 25% - Enrage
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
(400330, 0, 0, 0, 0, 0, 100, 0, 6000, 8000, 0, 0, 11, 15284, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 'Berserker - Cleave'),
(400330, 0, 1, 0, 2, 0, 100, 0, 0, 25, 0, 0, 11, 8599, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 'Berserker - Enrage');

-- 400331: Zandalari Shadow Hunter (Hybrid)
-- Event 0: Ally HP < 50% - Healing Wave
-- Event 1: In Combat - Hex
-- Event 2: In Combat - Shoot
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
(400331, 0, 0, 0, 0, 0, 100, 0, 10000, 15000, 0, 0, 11, 11986, 0, 0, 0, 0, 0, 21, 30, 0, 0, 0, 0, 0, 0, 'Shadow Hunter - Healing Wave'),
(400331, 0, 1, 0, 0, 0, 100, 0, 15000, 20000, 0, 0, 11, 16097, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 'Shadow Hunter - Hex'),
(400331, 0, 2, 0, 0, 0, 100, 0, 3000, 5000, 10000, 30000, 11, 6660, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 'Shadow Hunter - Shoot');

-- 400332: Zandalari Blood Guard (Elite)
-- Event 0: In Combat - Mortal Strike
-- Event 1: In Combat - War Stomp
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
(400332, 0, 0, 0, 0, 0, 100, 0, 6000, 8000, 0, 0, 11, 16856, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 'Blood Guard - Mortal Strike'),
(400332, 0, 1, 0, 0, 0, 100, 0, 12000, 15000, 0, 0, 11, 11876, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 'Blood Guard - War Stomp');

-- 400333: Zandalari Witch Doctor (Caster)
-- Event 0: In Combat - Shadow Bolt
-- Event 1: In Combat - Healing Ward
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
(400333, 0, 0, 0, 0, 0, 100, 0, 3000, 4000, 0, 0, 11, 9613, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 'Witch Doctor - Shadow Bolt'),
(400333, 0, 1, 0, 0, 0, 100, 0, 15000, 20000, 0, 0, 11, 5605, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 'Witch Doctor - Healing Ward');

-- 400334: Zandalari Beast Tamer (Hunter)
-- Event 0: In Combat - Multi-Shot
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
(400334, 0, 0, 0, 0, 0, 100, 0, 8000, 12000, 0, 0, 11, 14443, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 'Beast Tamer - Multi-Shot');

-- 400335: Zandalari War Raptor (Pet)
-- Event 0: In Combat - Bite
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
(400335, 0, 0, 0, 0, 0, 100, 0, 4000, 6000, 0, 0, 11, 16827, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 'War Raptor - Bite');

-- 400337: Zandalari Honor Guard (Elite)
-- Event 0: In Combat - Heroic Strike
-- Event 1: HP < 20% - Shield Wall
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
(400337, 0, 0, 0, 0, 0, 100, 0, 4000, 6000, 0, 0, 11, 29426, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 'Honor Guard - Heroic Strike'),
(400337, 0, 1, 0, 2, 0, 100, 0, 0, 20, 0, 0, 11, 871, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 'Honor Guard - Shield Wall');

-- Invasion Leader (Ship Commander)
INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400338,0,0,0,0,0,'General Rak\'zor','Zandalari Invasion Commander',NULL,0,83,83,2,16,0,1.0,1.0,1.5,3,0,2000,2000,1,1,1,32832,2048,0,0,0,0,0,0,7,0,0,0,0,0,0,0,0,'',0,1,100,1,1,1,1,0,0,1,0,0,2,'npc_invasion_leader',12340);

-- ============================================================================
-- SMART_SCRIPTS - New Creatures (Water & Cave)
-- ============================================================================
DELETE FROM `smart_scripts` WHERE `entryorguid` BETWEEN 400060 AND 400072 AND `source_type` = 0;

-- 400060: Primal Threshadon
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
(400060, 0, 0, 0, 0, 0, 100, 0, 10000, 15000, 0, 0, 11, 5782, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 'Threshadon - Fear'),
(400060, 0, 1, 0, 0, 0, 100, 0, 4000, 6000, 0, 0, 11, 16827, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 'Threshadon - Bite');

-- 400061: Primal Crocodile
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
(400061, 0, 0, 0, 0, 0, 100, 0, 15000, 20000, 0, 0, 11, 20542, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 'Crocodile - Armor Shell'),
(400061, 0, 1, 0, 0, 0, 100, 0, 4000, 6000, 0, 0, 11, 16827, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 'Crocodile - Bite');

-- 400062: Abyssal Sea Serpent
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
(400062, 0, 0, 0, 0, 0, 100, 0, 8000, 12000, 0, 0, 11, 16099, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 'Sea Serpent - Frost Breath'),
(400062, 0, 1, 0, 0, 0, 100, 0, 10000, 15000, 0, 0, 11, 15589, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 'Sea Serpent - Tail Sweep');

-- 400070: Cavernous Pterrordax
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
(400070, 0, 0, 0, 0, 0, 100, 0, 6000, 10000, 0, 0, 11, 8281, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 'Pterrordax - Sonic Burst');

-- 400071: Subterranean Saurok
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
(400071, 0, 0, 0, 0, 0, 100, 0, 5000, 8000, 0, 0, 11, 11977, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 'Saurok - Rend'),
(400071, 0, 1, 0, 0, 0, 100, 0, 10000, 15000, 0, 0, 11, 10278, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 'Saurok - Leap');

-- 400072: Crystal Spine Spider
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
(400072, 0, 0, 0, 0, 0, 100, 0, 8000, 12000, 0, 0, 11, 745, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 'Spider - Web'),
(400072, 0, 1, 0, 0, 0, 100, 0, 5000, 8000, 0, 0, 11, 744, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 'Spider - Poison');

-- ============================================================================
-- END OF GIANT ISLES CREATURE TEMPLATES
-- ============================================================================

DELETE FROM `creature_template_model` WHERE (`CreatureID` = 400324) AND (`Idx` IN (0));
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(400324, 0, 23278, 2, 1, 12340);
UPDATE `creature_template_addon` SET `visibilityDistanceType` = 4 WHERE (`entry` = 400324);

DELETE FROM `creature_template_model` WHERE (`CreatureID` = 400338) AND (`Idx` IN (0));
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(400338, 0, 21899, 1.5, 1, 12340);
