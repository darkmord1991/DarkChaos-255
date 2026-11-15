-- DarkChaos map 751: the Horde (Forsaken) Silverpine chain from Cataclysm, plus a Hillsbrad turn-in repair.
--
-- Why: Horde had 16 solo quests in Silverpine Forest (zone 4935, band 134-138), about a third of the XP those levels
-- need, and three of them (27069 -> 27093 -> 27096) plus 27478/27484 could not be started at all: their Cata
-- prerequisite 27065 / 27476 had no giver on 751. The Forsaken questgivers (Sylvanas at Forsaken High Command, the
-- Sepulcher, the Forsaken Front and the Battlefront; Witherbloom, Belmont, Cromush) were never spawned here.
-- The cutscene and companion parts already exist as C++ (src/server/scripts/DC/Plaguelands/Silverpine/, built into
-- the deployed worldserver) and were waiting for exactly these quest rows; quest ids are Cata's raw ids.
--
-- What:
--   1. NPC templates: Sylvanas copies 4144365 (High Command), 831600 (Sepulcher; a 2nd copy of 44365, so the
--      High Command one does not offer the Sepulcher quests), 4145617 (Forsaken Front), 4146124 (Battlefront),
--      Witherbloom 4144778, Belmont 4144789, Cromush 4145631, kill credit 4145769, and the 27513/27548 targets
--      4101889/4101913/4101914 (Ambermill mages, KillCredit 45756) and 4145883 (7th Legion Scout). Values are
--      copied from the existing 751 copies (4110181, 4144912, 4145312, 4148545, 46019) or, for mobs, the 751
--      band model (exp 2, HP 2.5x / 4.5% of a same-level player). Quest NPCs are immune to players and NPCs.
--   2. 55 spawns, guids 9034000-9034066: 8 quest NPCs at their nelt_world/TC Cata map-0 spots (751 keeps
--      map-0 coordinates), 20 Ambermill mages and 27 7th Legion Scouts at nelt_world positions (ground
--      level only, nothing within 100 yd of the Alliance Ambermill post). Sylvanas at High Command stands 5 yd behind
--      her Cata spot, which the 26965 cutscene and the 27098 horse use.
--   3. 14 quests imported from cata_world (texts missing there from TC_Cata_world), 8 existing ones get
--      a giver/turn-in. QuestLevel -1, MinLevel 134, Horde race mask 1237320626, 11-10 gold, Cata XP
--      difficulty, the AUTOCOMPLETE flag 0x10000 stripped (on 3.3.5 it lets a quest be handed in unfinished),
--      gear rewards on the band-134 ladder (421xxx), no new items.
--   4. Chain repairs for skipped quests: 27039 no longer points at 27045 (removed on 11-11 on purpose),
--      27056 follows 27039, 27594 follows 27542 (27580 asks to kill General Marstone, the Alliance camp's
--      questgiver), 27601 follows 27594, 27476 follows 27474. 27056 hands over no item (Belmont's Report 60766
--      has no Item.dbc row), so it is a talk-to quest. 27547/27548 can also be handed in to Sylvanas at the
--      Forsaken Front: their guardian quest NPCs (Ashbury, Walden) stop appearing once 27594 is rewarded.
--   5. Quest POIs (world map area 1270): turn-in marker on the ender spawn, small polygons over ground-level
--      target clusters, none for cutscenes, buildings or the codex upstairs in Ambermill.
--   6. 120 s respawn on the quest mobs and Ferocious Doomweed nodes these quests use.
--   7. 27290 To Forsaken Forward Command (Gilneas breadcrumb, already in quest_template with its turn-in at
--      Belmont 4145312) gets its Cata giver, the Sepulcher Sylvanas: Sepulcher -> Gilneas -> 27438 -> Forsaken Front.
--   8. Hillsbrad 28329 Angry Scrubbing Bubbles / 28330 Trail of Filth: the hostile Angry Blight Slime 4148319 and
--      Chet the Slime-Breeder 4148322 (the kill target of 28330) were the starters. Serge Hinott 4102391, already
--      the turn-in of both and the starter of 28330, now also starts 28329; the two mob starter rows go.
--
-- Not ported (details in the hand-off): 26995, 27180, 27193, 27475, 27550, 27574, 27575, 27577 need quest items
-- with no Item.dbc row; 26998 is a bat vehicle; 27045 was removed on purpose; 27194/27195 are Master Forteski's
-- vehicle escort; 27580 kills the Alliance camp's General Marstone.
--
-- Re-runnable: templates by REPLACE, every row block is deleted and re-inserted, UPDATEs are absolute.
-- Reads cata_world and TC_Cata_world on the same server. Apply to acore_world, then restart the worldserver.

-- 1. creature templates
REPLACE INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`,
    `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`,
    `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`,
    `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`,
    `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`,
    `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`,
    `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`,
    `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT 4144365, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner', 'Banshee Queen', NULL, 0, 142, 142, 0, 118, 2, 0.888888,
    0.992063, 1, 1, 20, 1, 0, 2, 2000, 2000, 1, 1, 2, 768, 2048, 0, 0, 7, 76, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 1200, 20,
    1, 1, 1, 0, 1, 0, 2, '', 0;
REPLACE INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`,
    `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`,
    `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`,
    `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`,
    `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`,
    `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`,
    `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`,
    `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT 831600, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner', 'Banshee Queen', NULL, 0, 142, 142, 0, 118, 2, 0.888888,
    0.992063, 1, 1, 20, 1, 0, 2, 2000, 2000, 1, 1, 2, 768, 2048, 0, 0, 7, 76, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 1200, 20,
    1, 1, 1, 0, 1, 0, 2, '', 0;
REPLACE INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`,
    `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`,
    `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`,
    `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`,
    `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`,
    `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`,
    `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`,
    `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT 4145617, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner', 'Banshee Queen', NULL, 0, 142, 142, 0, 118, 2, 0.888888,
    0.992063, 1, 1, 20, 1, 0, 2, 2000, 2000, 1, 1, 2, 768, 2048, 0, 0, 7, 76, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 1200, 20,
    1, 1, 1, 0, 1, 0, 2, '', 0;
REPLACE INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`,
    `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`,
    `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`,
    `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`,
    `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`,
    `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`,
    `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`,
    `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT 4146124, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner', 'Banshee Queen', NULL, 0, 142, 142, 0, 118, 2, 0.888888,
    0.992063, 1, 1, 20, 1, 0, 2, 2000, 2000, 1, 1, 2, 768, 2048, 0, 0, 7, 76, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 1200, 20,
    1, 1, 1, 0, 1, 0, 2, '', 0;
REPLACE INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`,
    `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`,
    `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`,
    `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`,
    `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`,
    `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`,
    `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`,
    `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT 4144778, 0, 0, 0, 0, 0, 'Apothecary Witherbloom', NULL, '', 0, 136, 136, 2, 68, 2, 1, 1.14286, 1, 1, 20, 0, 0,
    0.758273, 2000, 2000, 1, 1, 2, 0, 2048, 0, 0, 7, 4096, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 0.907656, 2, 1, 1, 0, 0, 1,
    0, 2, '', 0;
REPLACE INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`,
    `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`,
    `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`,
    `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`,
    `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`,
    `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`,
    `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`,
    `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT 4144789, 0, 0, 0, 0, 0, 'Deathstalker Commander Belmont', '', '', 0, 135, 135, 0, 68, 2, 1, 1.14286, 1, 1, 20,
    0, 0, 1, 2000, 2000, 1, 1, 4, 768, 2048, 0, 0, 7, 4096, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 5, 1, 1, 1, 0, 0, 1, 0, 2,
    '', 0;
REPLACE INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`,
    `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`,
    `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`,
    `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`,
    `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`,
    `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`,
    `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`,
    `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT 4145631, 0, 0, 0, 0, 0, 'High Warlord Cromush', '', '', 0, 146, 146, 2, 2322, 2, 1, 1.14286, 1, 1, 20, 1, 0,
    1.30832, 2000, 2000, 1, 1, 1, 768, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 5.73604, 1, 1, 1, 0, 0, 1, 0,
    2, '', 0;
REPLACE INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`,
    `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`,
    `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`,
    `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`,
    `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`,
    `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`,
    `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`,
    `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT 4145769, 0, 0, 0, 0, 0, 'Archmage Kill Credit', NULL, NULL, 0, 140, 140, 0, 68, 0, 1, 1.14286, 1, 1, 20, 1, 0,
    1, 2000, 2000, 1, 1, 2, 0, 2048, 0, 0, 7, 262148, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 1, 1, 1, 1, 0, 0, 1, 0, 0, '', 0;
REPLACE INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`,
    `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`,
    `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`,
    `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`,
    `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`,
    `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`,
    `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`,
    `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT 4101889, 0, 0, 0, 45756, 0, 'Ambermill Witchalok', NULL, NULL, 0, 136, 137, 2, 76, 0, 1, 1.14286, 1, 1, 20, 0,
    0, 0.7583, 2000, 2000, 1, 1, 2, 0, 2048, 0, 0, 7, 0, 4101889, 0, 0, 0, 0, 0, 0, '', 0, 1, 0.9077, 1, 1, 1, 0, 0,
    1, 0, 0, '', 0;
REPLACE INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`,
    `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`,
    `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`,
    `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`,
    `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`,
    `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`,
    `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`,
    `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT 4101913, 0, 0, 0, 45756, 0, 'Ambermill Warder', NULL, NULL, 0, 136, 137, 2, 76, 0, 1, 1.14286, 1, 1, 20, 0, 0,
    0.7715, 2000, 2000, 1, 1, 1, 0, 2048, 0, 0, 7, 0, 4101913, 0, 0, 0, 0, 0, 0, '', 0, 1, 0.9077, 1, 1, 1, 0, 0, 1,
    0, 0, '', 0;
REPLACE INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`,
    `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`,
    `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`,
    `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`,
    `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`,
    `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`,
    `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`,
    `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT 4101914, 0, 0, 0, 45756, 0, 'Ambermill Magister', NULL, NULL, 0, 136, 137, 2, 76, 0, 1, 1.14286, 1, 1, 20, 0,
    0, 0.7583, 2000, 2000, 1, 1, 2, 0, 2048, 0, 0, 7, 0, 4101914, 0, 0, 0, 0, 0, 0, '', 0, 1, 0.9077, 1, 1, 1, 0, 0,
    1, 0, 0, '', 0;
REPLACE INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`,
    `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`,
    `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`,
    `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`,
    `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`,
    `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`,
    `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`,
    `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT 4145883, 0, 0, 0, 0, 0, '7th Legion Scout', NULL, NULL, 0, 137, 138, 2, 123, 0, 1, 1.14286, 1, 1, 20, 0, 0,
    0.773, 2000, 2000, 1, 1, 4, 0, 2048, 0, 0, 7, 0, 4145883, 0, 0, 0, 0, 0, 0, '', 0, 1, 0.9079, 1, 1, 1, 0, 0, 1, 0,
    0, '', 0;

DELETE FROM `creature_template_model` WHERE `CreatureID` IN (831600, 4101889, 4101913, 4101914, 4144365, 4144778);
DELETE FROM `creature_template_model` WHERE `CreatureID` IN (4144789, 4145617, 4145631, 4145769, 4145883, 4146124);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`,
    `VerifiedBuild`) VALUES
(831600, 0, 28213, 1, 1, 0),
(4101889, 0, 3585, 1, 1, 0),
(4101889, 1, 3586, 1, 1, 0),
(4101913, 0, 3592, 1, 1, 0),
(4101913, 1, 3593, 1, 1, 0),
(4101914, 0, 3559, 1, 1, 0),
(4101914, 1, 3560, 1, 1, 0),
(4144365, 0, 28213, 1, 1, 0),
(4144778, 0, 34071, 1, 1, 0),
(4144789, 0, 34077, 1, 1, 0),
(4145617, 0, 28213, 1, 1, 0),
(4145631, 0, 34009, 1, 1, 0),
(4145769, 0, 34611, 1, 1, 0),
(4145883, 0, 36316, 1, 1, 0),
(4145883, 1, 36318, 1, 1, 0),
(4145883, 2, 36319, 1, 1, 0),
(4145883, 3, 36320, 1, 1, 0),
(4146124, 0, 28213, 1, 1, 0);

DELETE FROM `creature_template_addon` WHERE `entry` IN (831600, 4144365, 4144778, 4144789, 4145617, 4145631, 4146124);
INSERT INTO `creature_template_addon` (`entry`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`,
    `visibilityDistanceType`, `auras`) VALUES
(831600, 0, 0, 0, 258, 0, 3, ''),
(4144365, 0, 0, 0, 258, 0, 3, ''),
(4144778, 0, 0, 0, 257, 0, 0, ''),
(4144789, 0, 0, 0, 1, 0, 0, ''),
(4145617, 0, 0, 0, 258, 0, 3, ''),
(4145631, 0, 0, 0, 257, 0, 3, ''),
(4146124, 0, 0, 0, 258, 0, 3, '');

-- mob loot: the 751 drop-ladder reference for their level, as on the Silverpine mobs around them
DELETE FROM `creature_loot_template` WHERE `Entry` IN (4101889, 4101913, 4101914, 4145883);
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`,
    `MinCount`, `MaxCount`, `Comment`) VALUES
(4101889, 0, 752212, 1.2, 0, 1, 0, 1, 1, '751 ladder L130-137'),
(4101913, 0, 752212, 1.2, 0, 1, 0, 1, 1, '751 ladder L130-137'),
(4101914, 0, 752212, 1.2, 0, 1, 0, 1, 1, '751 ladder L130-137'),
(4145883, 0, 752212, 1.2, 0, 1, 0, 1, 1, '751 ladder L130-137');

-- 2. spawns
DELETE FROM `creature` WHERE `guid` BETWEEN 9034000 AND 9034066 AND `id` IN (831600, 4101889, 4101913, 4101914);
DELETE FROM `creature` WHERE `guid` BETWEEN 9034000 AND 9034066 AND `id` IN (4102120, 4144365, 4144778, 4144789);
DELETE FROM `creature` WHERE `guid` BETWEEN 9034000 AND 9034066 AND `id` IN (4145617, 4145631, 4145883, 4146124);
INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`,
    `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `MovementType`, `Comment`) VALUES
(9034000, 4144365, 751, 4935, 16778, 1, 1, 0, 1384.9, 1045.2, 54, 4.03, 300, 0, 0, 'H751: Sylvanas FHC'),
(9034001, 4144778, 751, 4935, 16778, 1, 1, 0, 1409.33, 1065.86, 60.56, 0.23, 300, 0, 0, 'H751: Witherbloom'),
(9034002, 4144789, 751, 4935, 16778, 1, 1, 0, 1415.23, 1010.15, 52.8, 2.29, 300, 0, 0, 'H751: Belmont FHC'),
(9034003, 831600, 751, 4935, 16638, 1, 1, 0, 500.62, 1564.54, 128.35, 4.29, 300, 0, 0, 'H751: Sylvanas Sepulcher'),
(9034004, 4145617, 751, 4935, 16780, 1, 1, 0, -153.32, 1270.27, 51.55, 3.07, 300, 0, 0, 'H751: Sylvanas Front'),
(9034005, 4145631, 751, 4935, 16780, 1, 1, 0, -189.61, 1293.62, 43.05, 2.34, 300, 0, 0, 'H751: Cromush Front'),
(9034006, 4146124, 751, 4935, 16801, 1, 1, 0, -698.39, 1546.57, 27.95, 0, 300, 0, 0, 'H751: Sylvanas Battlefront'),
(9034007, 4102120, 751, 4935, 16642, 1, 1, 0, -136, 1067.24, 66.35, 1.545, 300, 0, 0, 'H751: Ataeric 27518'),
(9034010, 4101889, 751, 4935, 16642, 1, 1, 0, -95.1, 1022.41, 65.71, 4.4, 120, 3, 1, 'H751: 27513 mage'),
(9034011, 4101889, 751, 4935, 16642, 1, 1, 0, -90.46, 983.44, 68.17, 4.021, 120, 3, 1, 'H751: 27513 mage'),
(9034012, 4101889, 751, 4935, 16642, 1, 1, 0, -95.58, 948.89, 68.72, 1.089, 120, 3, 1, 'H751: 27513 mage'),
(9034013, 4101913, 751, 4935, 16642, 1, 1, 0, -134.59, 960.46, 67.58, 4.734, 120, 3, 1, 'H751: 27513 mage'),
(9034014, 4101913, 751, 4935, 16642, 1, 1, 0, -256.94, 845.01, 77.48, 0.381, 120, 3, 1, 'H751: 27513 mage'),
(9034015, 4101913, 751, 4935, 16642, 1, 1, 0, -201.69, 860.21, 69.1, 0.204, 120, 3, 1, 'H751: 27513 mage'),
(9034016, 4101913, 751, 4935, 16642, 1, 1, 0, -163.15, 842.11, 60.36, 0.15, 120, 3, 1, 'H751: 27513 mage'),
(9034017, 4101913, 751, 4935, 16642, 1, 1, 0, -122.98, 848.21, 61.76, 1.78, 120, 3, 1, 'H751: 27513 mage'),
(9034018, 4101913, 751, 4935, 16642, 1, 1, 0, -93.99, 1069.11, 64.95, 1.082, 120, 3, 1, 'H751: 27513 mage'),
(9034019, 4101913, 751, 4935, 16642, 1, 1, 0, -71.14, 1060.25, 64.73, 1.03, 120, 3, 1, 'H751: 27513 mage'),
(9034020, 4101913, 751, 4935, 16642, 1, 1, 0, -78.47, 886.81, 67.29, 2.897, 120, 3, 1, 'H751: 27513 mage'),
(9034021, 4101913, 751, 4935, 16642, 1, 1, 0, -148.5, 1022.99, 66.69, 0.07, 120, 3, 1, 'H751: 27513 mage'),
(9034022, 4101913, 751, 4935, 16642, 1, 1, 0, -193.97, 1072.4, 59.65, 1.518, 120, 3, 1, 'H751: 27513 mage'),
(9034023, 4101914, 751, 4935, 16642, 1, 1, 0, -201.23, 888.02, 65.66, 3.319, 120, 3, 1, 'H751: 27513 mage'),
(9034024, 4101914, 751, 4935, 16642, 1, 1, 0, -193.11, 807.63, 61.66, 2.686, 120, 3, 1, 'H751: 27513 mage'),
(9034025, 4101914, 751, 4935, 16642, 1, 1, 0, -182.59, 919.64, 66.71, 3.724, 120, 3, 1, 'H751: 27513 mage'),
(9034026, 4101914, 751, 4935, 16642, 1, 1, 0, -170.81, 996.19, 65.07, 1.892, 120, 3, 1, 'H751: 27513 mage'),
(9034027, 4101914, 751, 4935, 16642, 1, 1, 0, -220.37, 804.73, 75.43, 4.235, 120, 3, 1, 'H751: 27513 mage'),
(9034028, 4101914, 751, 4935, 16642, 1, 1, 0, -191.27, 913.27, 68.42, 5.157, 120, 3, 1, 'H751: 27513 mage'),
(9034029, 4101914, 751, 4935, 16642, 1, 1, 0, -185.24, 958.17, 65.54, 4.639, 120, 3, 1, 'H751: 27513 mage'),
(9034040, 4145883, 751, 4935, 16633, 1, 1, 0, -435.5, 1500.54, 18.74, 5.341, 120, 3, 1, 'H751: 27548 scout'),
(9034041, 4145883, 751, 4935, 16633, 1, 1, 0, -419.69, 1455.41, 27.19, 6.082, 120, 3, 1, 'H751: 27548 scout'),
(9034042, 4145883, 751, 4935, 16633, 1, 1, 0, -363.68, 1620.63, 20.64, 5.525, 120, 3, 1, 'H751: 27548 scout'),
(9034043, 4145883, 751, 4935, 16633, 1, 1, 0, -419.19, 1657.71, 18.79, 3.25, 120, 3, 1, 'H751: 27548 scout'),
(9034044, 4145883, 751, 4935, 16633, 1, 1, 0, -362.17, 1576.08, 18.74, 2.985, 120, 3, 1, 'H751: 27548 scout'),
(9034045, 4145883, 751, 4935, 16633, 1, 1, 0, -383.15, 1539.58, 18.78, 2.127, 120, 3, 1, 'H751: 27548 scout'),
(9034046, 4145883, 751, 4935, 16633, 1, 1, 0, -438.1, 1531.2, 18.74, 1.012, 120, 3, 1, 'H751: 27548 scout'),
(9034047, 4145883, 751, 4935, 16633, 1, 1, 0, -409.22, 1608.56, 19.9, 5.186, 120, 3, 1, 'H751: 27548 scout'),
(9034048, 4145883, 751, 4935, 16633, 1, 1, 0, -386.07, 1582.45, 18.78, 2.385, 120, 3, 1, 'H751: 27548 scout'),
(9034049, 4145883, 751, 4935, 16633, 1, 1, 0, -354.45, 1435.68, 26.15, 3.179, 120, 3, 1, 'H751: 27548 scout'),
(9034050, 4145883, 751, 4935, 16633, 1, 1, 0, -389.04, 1432.29, 27.01, 2.048, 120, 3, 1, 'H751: 27548 scout'),
(9034051, 4145883, 751, 4935, 16633, 1, 1, 0, -321.53, 1445.32, 30.92, 4.974, 120, 3, 1, 'H751: 27548 scout'),
(9034052, 4145883, 751, 4935, 16633, 1, 1, 0, -394.17, 1493.58, 20.94, 0.927, 120, 3, 1, 'H751: 27548 scout'),
(9034053, 4145883, 751, 4935, 16633, 1, 1, 0, -332.75, 1538.97, 26.14, 1.188, 120, 3, 1, 'H751: 27548 scout'),
(9034054, 4145883, 751, 4935, 16806, 1, 1, 0, -353.49, 1535.22, 25.45, 4.302, 120, 3, 1, 'H751: 27548 scout'),
(9034055, 4145883, 751, 4935, 16633, 1, 1, 0, -448.74, 1470.99, 19.11, 2.575, 120, 3, 1, 'H751: 27548 scout'),
(9034056, 4145883, 751, 4935, 16805, 1, 1, 0, -372.03, 1508.31, 18.78, 1.819, 120, 3, 1, 'H751: 27548 scout'),
(9034057, 4145883, 751, 4935, 16633, 1, 1, 0, -440.7, 1555.58, 18.74, 6.044, 120, 3, 1, 'H751: 27548 scout'),
(9034058, 4145883, 751, 4935, 16633, 1, 1, 0, -416.57, 1588.54, 20.64, 3.952, 120, 3, 1, 'H751: 27548 scout'),
(9034059, 4145883, 751, 4935, 16805, 1, 1, 0, -396.5, 1516.75, 18.78, 1.251, 120, 3, 1, 'H751: 27548 scout'),
(9034060, 4145883, 751, 4935, 16633, 1, 1, 0, -421.89, 1562.54, 18.76, 4.912, 120, 3, 1, 'H751: 27548 scout'),
(9034061, 4145883, 751, 4935, 16633, 1, 1, 0, -325.95, 1639.33, 19.51, 1.994, 120, 3, 1, 'H751: 27548 scout'),
(9034062, 4145883, 751, 4935, 16633, 1, 1, 0, -364.47, 1465.49, 21.18, 1.705, 120, 3, 1, 'H751: 27548 scout'),
(9034063, 4145883, 751, 4935, 16633, 1, 1, 0, -324.42, 1468.43, 32.28, 1.389, 120, 3, 1, 'H751: 27548 scout'),
(9034064, 4145883, 751, 4935, 16633, 1, 1, 0, -438.19, 1608.55, 19.75, 4.656, 120, 3, 1, 'H751: 27548 scout'),
(9034065, 4145883, 751, 4935, 16665, 1, 1, 0, -378.28, 1667.55, 18.41, 3.117, 120, 3, 1, 'H751: 27548 scout'),
(9034066, 4145883, 751, 4935, 16633, 1, 1, 0, -381.44, 1637.49, 18.74, 6.199, 120, 3, 1, 'H751: 27548 scout');

-- 3. quests: the Cata rows (quest_template rows are never deleted, so REPLACE)
REPLACE INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`,
    `SuggestedGroupNum`, `RequiredFactionId1`, `RequiredFactionId2`, `RequiredFactionValue1`, `RequiredFactionValue2`,
    `RewardNextQuest`, `RewardXPDifficulty`, `RewardMoney`, `RewardMoneyDifficulty`, `RewardDisplaySpell`,
    `RewardSpell`, `RewardHonor`, `RewardKillHonor`, `StartItem`, `Flags`, `RequiredPlayerKills`, `RewardItem1`,
    `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `RewardItem4`, `RewardAmount4`,
    `ItemDrop1`, `ItemDropQuantity1`, `ItemDrop2`, `ItemDropQuantity2`, `ItemDrop3`, `ItemDropQuantity3`, `ItemDrop4`,
    `ItemDropQuantity4`, `RewardChoiceItemID1`, `RewardChoiceItemQuantity1`, `RewardChoiceItemID2`,
    `RewardChoiceItemQuantity2`, `RewardChoiceItemID3`, `RewardChoiceItemQuantity3`, `RewardChoiceItemID4`,
    `RewardChoiceItemQuantity4`, `RewardChoiceItemID5`, `RewardChoiceItemQuantity5`, `RewardChoiceItemID6`,
    `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`, `POIy`, `POIPriority`, `RewardTitle`, `RewardTalents`,
    `RewardArenaPoints`, `RewardFactionID1`, `RewardFactionValue1`, `RewardFactionOverride1`, `RewardFactionID2`,
    `RewardFactionValue2`, `RewardFactionOverride2`, `RewardFactionID3`, `RewardFactionValue3`,
    `RewardFactionOverride3`, `RewardFactionID4`, `RewardFactionValue4`, `RewardFactionOverride4`, `RewardFactionID5`,
    `RewardFactionValue5`, `RewardFactionOverride5`, `TimeAllowed`, `AllowableRaces`, `LogTitle`, `LogDescription`,
    `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`,
    `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`, `RequiredNpcOrGoCount3`,
    `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`, `RequiredItemId4`,
    `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`, `RequiredItemCount3`,
    `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `Unknown0`, `ObjectiveText1`, `ObjectiveText2`,
    `ObjectiveText3`, `ObjectiveText4`, `VerifiedBuild`)
SELECT `q`.`ID`, `q`.`QuestType`, -1, 134, `q`.`QuestSortID`, `q`.`QuestInfoID`, `q`.`SuggestedGroupNum`,
    `q`.`RequiredFactionId1`, `q`.`RequiredFactionId2`, `q`.`RequiredFactionValue1`, `q`.`RequiredFactionValue2`,
    `q`.`RewardNextQuest`, `q`.`RewardXPDifficulty`, `q`.`RewardMoney`, 0, `q`.`RewardDisplaySpell`,
    `q`.`RewardSpell`, `q`.`RewardHonor`, `q`.`RewardKillHonor`, `q`.`StartItem`, `q`.`Flags` & ~65536,
    `q`.`RequiredPlayerKills`, `q`.`RewardItem1`, `q`.`RewardAmount1`, `q`.`RewardItem2`, `q`.`RewardAmount2`,
    `q`.`RewardItem3`, `q`.`RewardAmount3`, `q`.`RewardItem4`, `q`.`RewardAmount4`, `q`.`ItemDrop1`,
    `q`.`ItemDropQuantity1`, `q`.`ItemDrop2`, `q`.`ItemDropQuantity2`, `q`.`ItemDrop3`, `q`.`ItemDropQuantity3`,
    `q`.`ItemDrop4`, `q`.`ItemDropQuantity4`, `q`.`RewardChoiceItemID1`, `q`.`RewardChoiceItemQuantity1`,
    `q`.`RewardChoiceItemID2`, `q`.`RewardChoiceItemQuantity2`, `q`.`RewardChoiceItemID3`,
    `q`.`RewardChoiceItemQuantity3`, `q`.`RewardChoiceItemID4`, `q`.`RewardChoiceItemQuantity4`,
    `q`.`RewardChoiceItemID5`, `q`.`RewardChoiceItemQuantity5`, `q`.`RewardChoiceItemID6`,
    `q`.`RewardChoiceItemQuantity6`, `q`.`POIContinent`, `q`.`POIx`, `q`.`POIy`, `q`.`POIPriority`, `q`.`RewardTitle`,
    `q`.`RewardTalents`, `q`.`RewardArenaPoints`, `q`.`RewardFactionID1`, `q`.`RewardFactionValue1`,
    `q`.`RewardFactionOverride1`, `q`.`RewardFactionID2`, `q`.`RewardFactionValue2`, `q`.`RewardFactionOverride2`,
    `q`.`RewardFactionID3`, `q`.`RewardFactionValue3`, `q`.`RewardFactionOverride3`, `q`.`RewardFactionID4`,
    `q`.`RewardFactionValue4`, `q`.`RewardFactionOverride4`, `q`.`RewardFactionID5`, `q`.`RewardFactionValue5`,
    `q`.`RewardFactionOverride5`, 0, 1237320626, `q`.`LogTitle`, `q`.`LogDescription`, `q`.`QuestDescription`,
    `q`.`AreaDescription`, `q`.`QuestCompletionLog`, `q`.`RequiredNpcOrGo1`, `q`.`RequiredNpcOrGo2`,
    `q`.`RequiredNpcOrGo3`, `q`.`RequiredNpcOrGo4`, `q`.`RequiredNpcOrGoCount1`, `q`.`RequiredNpcOrGoCount2`,
    `q`.`RequiredNpcOrGoCount3`, `q`.`RequiredNpcOrGoCount4`, `q`.`RequiredItemId1`, `q`.`RequiredItemId2`,
    `q`.`RequiredItemId3`, `q`.`RequiredItemId4`, `q`.`RequiredItemId5`, `q`.`RequiredItemId6`,
    `q`.`RequiredItemCount1`, `q`.`RequiredItemCount2`, `q`.`RequiredItemCount3`, `q`.`RequiredItemCount4`,
    `q`.`RequiredItemCount5`, `q`.`RequiredItemCount6`, 0, `q`.`ObjectiveText1`, `q`.`ObjectiveText2`,
    `q`.`ObjectiveText3`, `q`.`ObjectiveText4`, `q`.`VerifiedBuild`
FROM `cata_world`.`quest_template` AS `q`
WHERE `q`.`ID` IN (26992, 27056, 27097, 27098, 27099, 27472, 27474, 27510, 27518, 27542, 27547, 27548, 27594, 27601);

DELETE FROM `quest_template_addon` WHERE `ID` IN (26992, 27056, 27097, 27098, 27099, 27472, 27474, 27510, 27518, 27542);
DELETE FROM `quest_template_addon` WHERE `ID` IN (27547, 27548, 27594, 27601);
INSERT INTO `quest_template_addon` (`ID`, `MaxLevel`, `AllowableClasses`, `SourceSpellID`, `PrevQuestID`,
    `NextQuestID`, `ExclusiveGroup`, `BreadcrumbForQuestId`, `RewardMailTemplateID`, `RewardMailDelay`,
    `RequiredSkillID`, `RequiredSkillPoints`, `RequiredMinRepFaction`, `RequiredMaxRepFaction`, `RequiredMinRepValue`,
    `RequiredMaxRepValue`, `ProvidedItemCount`, `SpecialFlags`)
SELECT `a`.`ID`, `a`.`MaxLevel`, `a`.`AllowableClasses`, `a`.`SourceSpellID`, `a`.`PrevQuestID`, `a`.`NextQuestID`,
    `a`.`ExclusiveGroup`, `a`.`BreadcrumbForQuestId`, `a`.`RewardMailTemplateID`, `a`.`RewardMailDelay`,
    `a`.`RequiredSkillID`, `a`.`RequiredSkillPoints`, `a`.`RequiredMinRepFaction`, `a`.`RequiredMaxRepFaction`,
    `a`.`RequiredMinRepValue`, `a`.`RequiredMaxRepValue`, `a`.`ProvidedItemCount`, `a`.`SpecialFlags`
FROM `cata_world`.`quest_template_addon` AS `a`
WHERE `a`.`ID` IN (26992, 27056, 27097, 27098, 27099, 27472, 27474, 27510, 27518, 27542, 27547, 27548, 27594, 27601);

-- texts: cata_world first; TC_Cata_world for the ones cata_world lacks
DELETE FROM `quest_offer_reward` WHERE `ID` IN (26992, 27056, 27097, 27098, 27099, 27472, 27474, 27510, 27518, 27542);
DELETE FROM `quest_offer_reward` WHERE `ID` IN (27547, 27548, 27594, 27601);
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `Emote2`, `Emote3`, `Emote4`, `EmoteDelay1`, `EmoteDelay2`,
    `EmoteDelay3`, `EmoteDelay4`, `RewardText`, `VerifiedBuild`)
SELECT `c`.`ID`, `c`.`Emote1`, `c`.`Emote2`, `c`.`Emote3`, `c`.`Emote4`, `c`.`EmoteDelay1`, `c`.`EmoteDelay2`,
    `c`.`EmoteDelay3`, `c`.`EmoteDelay4`, `c`.`RewardText`, `c`.`VerifiedBuild`
FROM `cata_world`.`quest_offer_reward` AS `c`
WHERE `c`.`ID` IN (26992, 27056, 27097, 27098, 27099, 27472, 27474, 27510, 27518, 27542, 27547, 27548, 27594, 27601)
UNION ALL
SELECT `t`.`ID`, `t`.`Emote1`, `t`.`Emote2`, `t`.`Emote3`, `t`.`Emote4`, `t`.`EmoteDelay1`, `t`.`EmoteDelay2`,
    `t`.`EmoteDelay3`, `t`.`EmoteDelay4`, `t`.`RewardText`, `t`.`VerifiedBuild`
FROM `TC_Cata_world`.`quest_offer_reward` AS `t`
WHERE `t`.`ID` IN (26992, 27056, 27097, 27098, 27099, 27472, 27474, 27510, 27518, 27542, 27547, 27548, 27594, 27601)
AND `t`.`ID` NOT IN (SELECT `x`.`ID` FROM `cata_world`.`quest_offer_reward` AS `x`);

DELETE FROM `quest_request_items` WHERE `ID` IN (26992, 27056, 27097, 27098, 27099, 27472, 27474, 27510, 27518, 27542);
DELETE FROM `quest_request_items` WHERE `ID` IN (27547, 27548, 27594, 27601);
INSERT INTO `quest_request_items` (`ID`, `EmoteOnComplete`, `EmoteOnIncomplete`, `CompletionText`, `VerifiedBuild`)
SELECT `c`.`ID`, `c`.`EmoteOnComplete`, `c`.`EmoteOnIncomplete`, `c`.`CompletionText`, `c`.`VerifiedBuild`
FROM `cata_world`.`quest_request_items` AS `c`
WHERE `c`.`ID` IN (26992, 27056, 27097, 27098, 27099, 27472, 27474, 27510, 27518, 27542, 27547, 27548, 27594, 27601)
UNION ALL
SELECT `t`.`ID`, `t`.`EmoteOnComplete`, `t`.`EmoteOnIncomplete`, `t`.`CompletionText`, `t`.`VerifiedBuild`
FROM `TC_Cata_world`.`quest_request_items` AS `t`
WHERE `t`.`ID` IN (26992, 27056, 27097, 27098, 27099, 27472, 27474, 27510, 27518, 27542, 27547, 27548, 27594, 27601)
AND `t`.`ID` NOT IN (SELECT `x`.`ID` FROM `cata_world`.`quest_request_items` AS `x`);

DELETE FROM `quest_details` WHERE `ID` IN (26992, 27056, 27097, 27098, 27099, 27472, 27474, 27510, 27518, 27542, 27547);
DELETE FROM `quest_details` WHERE `ID` IN (27548, 27594, 27601);
INSERT INTO `quest_details` (`ID`, `Emote1`, `Emote2`, `Emote3`, `Emote4`, `EmoteDelay1`, `EmoteDelay2`,
    `EmoteDelay3`, `EmoteDelay4`, `VerifiedBuild`)
SELECT `c`.`ID`, `c`.`Emote1`, `c`.`Emote2`, `c`.`Emote3`, `c`.`Emote4`, `c`.`EmoteDelay1`, `c`.`EmoteDelay2`,
    `c`.`EmoteDelay3`, `c`.`EmoteDelay4`, `c`.`VerifiedBuild`
FROM `cata_world`.`quest_details` AS `c`
WHERE `c`.`ID` IN (26992, 27056, 27097, 27098, 27099, 27472, 27474, 27510, 27518, 27542, 27547, 27548, 27594, 27601)
UNION ALL
SELECT `t`.`ID`, `t`.`Emote1`, `t`.`Emote2`, `t`.`Emote3`, `t`.`Emote4`, `t`.`EmoteDelay1`, `t`.`EmoteDelay2`,
    `t`.`EmoteDelay3`, `t`.`EmoteDelay4`, `t`.`VerifiedBuild`
FROM `TC_Cata_world`.`quest_details` AS `t`
WHERE `t`.`ID` IN (26992, 27056, 27097, 27098, 27099, 27472, 27474, 27510, 27518, 27542, 27547, 27548, 27594, 27601)
AND `t`.`ID` NOT IN (SELECT `x`.`ID` FROM `cata_world`.`quest_details` AS `x`);

-- 27542 Taking the Battlefront has no quest text in any source DB
UPDATE `quest_template` SET
    `LogDescription` = 'Join Lord Godfrey and his men at the Battlefront in Silverpine Forest.',
    `QuestDescription` = CONCAT('Godfrey has devised a plan to break the Alliance at the Battlefront, $N. ',
        'He, Walden and Ashbury will join you once you reach the Battlefront to the west.$B$B',
        'Go with them, and bring me victory.')
WHERE `ID` = 27542;

-- level, races, gold, money difficulty on every quest of this port (the existing ones were never offered)
UPDATE `quest_template` SET `QuestLevel` = -1, `MinLevel` = 134, `AllowableRaces` = 1237320626,
    `RewardMoneyDifficulty` = 0 WHERE `ID` IN (26992, 27039, 27056, 27065, 27097, 27098, 27099, 27181, 27472, 27474,
    27476, 27484, 27510, 27512, 27513, 27518, 27542, 27547, 27548, 27594, 27601);
UPDATE `quest_template` SET `AllowableRaces` = 1237320626 WHERE `ID` = 27438;
UPDATE `quest_template` SET `Flags` = `Flags` & ~65536 WHERE `ID` IN (27039, 27065, 27181, 27438, 27476, 27484, 27512,
    27513);
UPDATE `quest_template` SET `RewardMoney` = 12330 WHERE `ID` IN (27056, 27065, 27542);
UPDATE `quest_template` SET `RewardMoney` = 92480 WHERE `ID` IN (27039);
UPDATE `quest_template` SET `RewardMoney` = 123300 WHERE `ID` IN (26992, 27181, 27476, 27484, 27510, 27512, 27547,
    27548);
UPDATE `quest_template` SET `RewardMoney` = 154120 WHERE `ID` IN (27097, 27474, 27513);
UPDATE `quest_template` SET `RewardMoney` = 184950 WHERE `ID` IN (27098, 27099, 27518, 27594);
UPDATE `quest_template` SET `RewardMoney` = 246600 WHERE `ID` IN (27472, 27601);

-- objectives that name the 751 entry (the C++ credits both forms; AC drops an objective whose template is missing)
UPDATE `quest_template` SET `RequiredNpcOrGo1` = 4145617 WHERE `ID` = 27472;
UPDATE `quest_template` SET `RequiredNpcOrGo1` = 4145750 WHERE `ID` = 27510;
UPDATE `quest_template` SET `RequiredNpcOrGo1` = 4145769 WHERE `ID` = 27518;
UPDATE `quest_template` SET `RequiredNpcOrGo1` = 4145910 WHERE `ID` = 27547;
UPDATE `quest_template` SET `RequiredNpcOrGo1` = 4145883 WHERE `ID` = 27548;
-- 27056: Belmont's Report 60766 has no Item.dbc row; the report is delivered by word of mouth
UPDATE `quest_template` SET `StartItem` = 0, `RequiredItemId1` = 0, `RequiredItemCount1` = 0 WHERE `ID` = 27056;
UPDATE `quest_template_addon` SET `ProvidedItemCount` = 0 WHERE `ID` = 27056;
-- 27472: RewardSpell 85206 is in neither Spell.dbc nor spell_dbc here
UPDATE `quest_template` SET `RewardSpell` = 0 WHERE `ID` = 27472;

-- rewards: gear on the band-134 ladder, the steak on the 751 consumable, slots compacted
-- 27099: 62859->421209, 62858 dropped (no ladder slot), 62857->421214
UPDATE `quest_template` SET `RewardItem1` = 0, `RewardItem2` = 0, `RewardItem3` = 0, `RewardItem4` = 0,
    `RewardAmount1` = 0, `RewardAmount2` = 0, `RewardAmount3` = 0, `RewardAmount4` = 0,
    `RewardChoiceItemID1` = 421209, `RewardChoiceItemID2` = 421214, `RewardChoiceItemID3` = 0,
    `RewardChoiceItemID4` = 0, `RewardChoiceItemID5` = 0, `RewardChoiceItemID6` = 0, `RewardChoiceItemQuantity1` = 1,
    `RewardChoiceItemQuantity2` = 1, `RewardChoiceItemQuantity3` = 0, `RewardChoiceItemQuantity4` = 0,
    `RewardChoiceItemQuantity5` = 0, `RewardChoiceItemQuantity6` = 0 WHERE `ID` = 27099;
-- 27510: 62909->400818, 62885->421203, 62884->421185, 62883->421176
UPDATE `quest_template` SET `RewardItem1` = 400818, `RewardItem2` = 0, `RewardItem3` = 0, `RewardItem4` = 0,
    `RewardAmount1` = 5, `RewardAmount2` = 0, `RewardAmount3` = 0, `RewardAmount4` = 0,
    `RewardChoiceItemID1` = 421203, `RewardChoiceItemID2` = 421185, `RewardChoiceItemID3` = 421176,
    `RewardChoiceItemID4` = 0, `RewardChoiceItemID5` = 0, `RewardChoiceItemID6` = 0, `RewardChoiceItemQuantity1` = 1,
    `RewardChoiceItemQuantity2` = 1, `RewardChoiceItemQuantity3` = 1, `RewardChoiceItemQuantity4` = 0,
    `RewardChoiceItemQuantity5` = 0, `RewardChoiceItemQuantity6` = 0 WHERE `ID` = 27510;
-- 27518: 62891->421198, 62890->421179, 62889->421206
UPDATE `quest_template` SET `RewardItem1` = 0, `RewardItem2` = 0, `RewardItem3` = 0, `RewardItem4` = 0,
    `RewardAmount1` = 0, `RewardAmount2` = 0, `RewardAmount3` = 0, `RewardAmount4` = 0,
    `RewardChoiceItemID1` = 421198, `RewardChoiceItemID2` = 421179, `RewardChoiceItemID3` = 421206,
    `RewardChoiceItemID4` = 0, `RewardChoiceItemID5` = 0, `RewardChoiceItemID6` = 0, `RewardChoiceItemQuantity1` = 1,
    `RewardChoiceItemQuantity2` = 1, `RewardChoiceItemQuantity3` = 1, `RewardChoiceItemQuantity4` = 0,
    `RewardChoiceItemQuantity5` = 0, `RewardChoiceItemQuantity6` = 0 WHERE `ID` = 27518;
-- 27594: 62894->421207, 62893->421207 (duplicate, merged), 62892->421207 (duplicate, merged)
UPDATE `quest_template` SET `RewardItem1` = 0, `RewardItem2` = 0, `RewardItem3` = 0, `RewardItem4` = 0,
    `RewardAmount1` = 0, `RewardAmount2` = 0, `RewardAmount3` = 0, `RewardAmount4` = 0,
    `RewardChoiceItemID1` = 421207, `RewardChoiceItemID2` = 0, `RewardChoiceItemID3` = 0, `RewardChoiceItemID4` = 0,
    `RewardChoiceItemID5` = 0, `RewardChoiceItemID6` = 0, `RewardChoiceItemQuantity1` = 1,
    `RewardChoiceItemQuantity2` = 0, `RewardChoiceItemQuantity3` = 0, `RewardChoiceItemQuantity4` = 0,
    `RewardChoiceItemQuantity5` = 0, `RewardChoiceItemQuantity6` = 0 WHERE `ID` = 27594;
-- 27601: 62897->421245, 62896->421226, 62895->421220
UPDATE `quest_template` SET `RewardItem1` = 0, `RewardItem2` = 0, `RewardItem3` = 0, `RewardItem4` = 0,
    `RewardAmount1` = 0, `RewardAmount2` = 0, `RewardAmount3` = 0, `RewardAmount4` = 0,
    `RewardChoiceItemID1` = 421245, `RewardChoiceItemID2` = 421226, `RewardChoiceItemID3` = 421220,
    `RewardChoiceItemID4` = 0, `RewardChoiceItemID5` = 0, `RewardChoiceItemID6` = 0, `RewardChoiceItemQuantity1` = 1,
    `RewardChoiceItemQuantity2` = 1, `RewardChoiceItemQuantity3` = 1, `RewardChoiceItemQuantity4` = 0,
    `RewardChoiceItemQuantity5` = 0, `RewardChoiceItemQuantity6` = 0 WHERE `ID` = 27601;

-- 4. chain: skipped quests re-linked
UPDATE `quest_template` SET `RewardNextQuest` = 0 WHERE `ID` = 27039 AND `RewardNextQuest` = 27045;
UPDATE `quest_template_addon` SET `PrevQuestID` = 27039 WHERE `ID` = 27056;
UPDATE `quest_template_addon` SET `PrevQuestID` = 27097 WHERE `ID` = 27099;
UPDATE `quest_template_addon` SET `PrevQuestID` = 27099 WHERE `ID` = 27098;
UPDATE `quest_template_addon` SET `PrevQuestID` = 27474 WHERE `ID` = 27476;
UPDATE `quest_template_addon` SET `PrevQuestID` = 27542 WHERE `ID` = 27594;
UPDATE `quest_template_addon` SET `PrevQuestID` = 27594 WHERE `ID` = 27601;
-- 27548 pointed at 27577 (not ported); 27601 -> 27746 Empire of Dirt is kept, it exists
UPDATE `quest_template` SET `RewardNextQuest` = 0 WHERE `ID` = 27548 AND `RewardNextQuest` = 27577;

-- relations
DELETE FROM `creature_queststarter` WHERE (`id`, `quest`) IN ((44951, 27099), (45878, 27594), (45879, 27548));
DELETE FROM `creature_queststarter` WHERE (`id`, `quest`) IN ((45880, 27547), (831600, 27181), (831600, 27290));
DELETE FROM `creature_queststarter` WHERE (`id`, `quest`) IN ((4101938, 27484), (4102391, 28329), (4144365, 27065));
DELETE FROM `creature_queststarter` WHERE (`id`, `quest`) IN ((4144365, 27097), (4144365, 27098), (4144365, 27099));
DELETE FROM `creature_queststarter` WHERE (`id`, `quest`) IN ((4144778, 26992), (4144789, 27039), (4144789, 27056));
DELETE FROM `creature_queststarter` WHERE (`id`, `quest`) IN ((4145312, 27438), (4145617, 27472), (4145617, 27474));
DELETE FROM `creature_queststarter` WHERE (`id`, `quest`) IN ((4145617, 27476), (4145617, 27512), (4145617, 27518));
DELETE FROM `creature_queststarter` WHERE (`id`, `quest`) IN ((4145617, 27542), (4145617, 27601), (4145631, 27510));
DELETE FROM `creature_queststarter` WHERE (`id`, `quest`) IN ((4145752, 27513));
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(44951, 27099),
(45878, 27594),
(45879, 27548),
(45880, 27547),
(831600, 27181),
(831600, 27290),
(4101938, 27484),
(4102391, 28329),
(4144365, 27065),
(4144365, 27097),
(4144365, 27098),
(4144365, 27099),
(4144778, 26992),
(4144789, 27039),
(4144789, 27056),
(4145312, 27438),
(4145617, 27472),
(4145617, 27474),
(4145617, 27476),
(4145617, 27512),
(4145617, 27518),
(4145617, 27542),
(4145617, 27601),
(4145631, 27510),
(4145752, 27513);
DELETE FROM `creature_questender` WHERE (`id`, `quest`) IN ((45879, 27548), (45880, 27547), (831600, 27098));
DELETE FROM `creature_questender` WHERE (`id`, `quest`) IN ((831600, 27181), (4144365, 27056), (4144365, 27096));
DELETE FROM `creature_questender` WHERE (`id`, `quest`) IN ((4144365, 27097), (4144365, 27099), (4144778, 26992));
DELETE FROM `creature_questender` WHERE (`id`, `quest`) IN ((4145617, 27438), (4145617, 27472), (4145617, 27474));
DELETE FROM `creature_questender` WHERE (`id`, `quest`) IN ((4145617, 27484), (4145617, 27513), (4145617, 27518));
DELETE FROM `creature_questender` WHERE (`id`, `quest`) IN ((4145617, 27542), (4145617, 27547), (4145617, 27548));
DELETE FROM `creature_questender` WHERE (`id`, `quest`) IN ((4145617, 27594), (4145631, 27510), (4146124, 27601));
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(45879, 27548),
(45880, 27547),
(831600, 27098),
(831600, 27181),
(4144365, 27056),
(4144365, 27096),
(4144365, 27097),
(4144365, 27099),
(4144778, 26992),
(4145617, 27438),
(4145617, 27472),
(4145617, 27474),
(4145617, 27484),
(4145617, 27513),
(4145617, 27518),
(4145617, 27542),
(4145617, 27547),
(4145617, 27548),
(4145617, 27594),
(4145631, 27510),
(4146124, 27601);
DELETE FROM `gameobject_questender` WHERE (`id`, `quest`) IN ((4805143, 27039));
INSERT INTO `gameobject_questender` (`id`, `quest`) VALUES
(4805143, 27039);
-- 28329/28330: no quest from the hostile slime or from Chet, the mob 28330 asks you to kill
DELETE FROM `creature_queststarter` WHERE (`id`, `quest`) IN ((4148319, 28329), (4148322, 28330));

-- 5. quest POIs
DELETE FROM `quest_poi` WHERE `QuestID` IN (26992, 27039, 27056, 27065, 27097, 27098, 27099, 27181, 27438, 27472);
DELETE FROM `quest_poi` WHERE `QuestID` IN (27474, 27476, 27484, 27510, 27512, 27513, 27518, 27542, 27547, 27548);
DELETE FROM `quest_poi` WHERE `QuestID` IN (27594, 27601, 27096);
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`,
    `VerifiedBuild`) VALUES
(26992, 0, 4, 751, 1270, 0, 0, 1, 0),
(26992, 1, 4, 751, 1270, 0, 0, 1, 0),
(26992, 2, 4, 751, 1270, 0, 0, 1, 0),
(26992, 3, 4, 751, 1270, 0, 0, 1, 0),
(26992, 4, 4, 751, 1270, 0, 0, 1, 0),
(26992, 5, -1, 751, 1270, 0, 0, 1, 0),
(27039, 0, -1, 751, 1270, 0, 0, 1, 0),
(27056, 0, -1, 751, 1270, 0, 0, 1, 0),
(27065, 0, -1, 751, 1270, 0, 0, 1, 0),
(27097, 0, 0, 751, 1270, 0, 0, 1, 0),
(27097, 1, 0, 751, 1270, 0, 0, 1, 0),
(27097, 2, 0, 751, 1270, 0, 0, 1, 0),
(27097, 3, 0, 751, 1270, 0, 0, 1, 0),
(27097, 4, 0, 751, 1270, 0, 0, 1, 0),
(27097, 5, -1, 751, 1270, 0, 0, 1, 0),
(27098, 0, -1, 751, 1270, 0, 0, 1, 0),
(27099, 0, -1, 751, 1270, 0, 0, 1, 0),
(27181, 0, 0, 751, 1270, 0, 0, 1, 0),
(27181, 1, 0, 751, 1270, 0, 0, 1, 0),
(27181, 2, 0, 751, 1270, 0, 0, 1, 0),
(27181, 3, 0, 751, 1270, 0, 0, 1, 0),
(27181, 4, 0, 751, 1270, 0, 0, 1, 0),
(27181, 5, -1, 751, 1270, 0, 0, 1, 0),
(27438, 0, -1, 751, 1270, 0, 0, 1, 0),
(27472, 0, -1, 751, 1270, 0, 0, 1, 0),
(27474, 0, -1, 751, 1270, 0, 0, 1, 0),
(27476, 0, -1, 751, 1270, 0, 0, 1, 0),
(27484, 0, -1, 751, 1270, 0, 0, 1, 0),
(27510, 0, 0, 751, 1270, 0, 0, 1, 0),
(27510, 1, 0, 751, 1270, 0, 0, 1, 0),
(27510, 2, 0, 751, 1270, 0, 0, 1, 0),
(27510, 3, -1, 751, 1270, 0, 0, 1, 0),
(27512, 0, -1, 751, 1270, 0, 0, 1, 0),
(27513, 0, 0, 751, 1270, 0, 0, 1, 0),
(27513, 1, 0, 751, 1270, 0, 0, 1, 0),
(27513, 2, 0, 751, 1270, 0, 0, 1, 0),
(27513, 3, 0, 751, 1270, 0, 0, 1, 0),
(27513, 4, 0, 751, 1270, 0, 0, 1, 0),
(27513, 5, -1, 751, 1270, 0, 0, 1, 0),
(27518, 0, 0, 751, 1270, 0, 0, 1, 0),
(27518, 1, -1, 751, 1270, 0, 0, 1, 0),
(27542, 0, -1, 751, 1270, 0, 0, 1, 0),
(27547, 0, 0, 751, 1270, 0, 0, 1, 0),
(27547, 1, 0, 751, 1270, 0, 0, 1, 0),
(27547, 2, 0, 751, 1270, 0, 0, 1, 0),
(27547, 3, 0, 751, 1270, 0, 0, 1, 0),
(27547, 4, -1, 751, 1270, 0, 0, 1, 0),
(27548, 0, 0, 751, 1270, 0, 0, 1, 0),
(27548, 1, 0, 751, 1270, 0, 0, 1, 0),
(27548, 2, 0, 751, 1270, 0, 0, 1, 0),
(27548, 3, 0, 751, 1270, 0, 0, 1, 0),
(27548, 4, 0, 751, 1270, 0, 0, 1, 0),
(27548, 5, -1, 751, 1270, 0, 0, 1, 0),
(27594, 0, 0, 751, 1270, 0, 0, 1, 0),
(27594, 1, -1, 751, 1270, 0, 0, 1, 0),
(27601, 0, -1, 751, 1270, 0, 0, 1, 0),
(27096, 0, -1, 751, 1270, 0, 0, 1, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` IN (26992, 27039, 27056, 27065, 27097, 27098, 27099, 27181, 27438);
DELETE FROM `quest_poi_points` WHERE `QuestID` IN (27472, 27474, 27476, 27484, 27510, 27512, 27513, 27518, 27542);
DELETE FROM `quest_poi_points` WHERE `QuestID` IN (27547, 27548, 27594, 27601, 27096);
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(26992, 0, 0, 1455, 955, 0),
(26992, 0, 1, 1439, 994, 0),
(26992, 0, 2, 1400, 1010, 0),
(26992, 0, 3, 1361, 994, 0),
(26992, 0, 4, 1345, 955, 0),
(26992, 0, 5, 1361, 916, 0),
(26992, 0, 6, 1400, 900, 0),
(26992, 0, 7, 1439, 916, 0),
(26992, 1, 0, 1322, 966, 0),
(26992, 1, 1, 1313, 988, 0),
(26992, 1, 2, 1291, 997, 0),
(26992, 1, 3, 1270, 988, 0),
(26992, 1, 4, 1260, 966, 0),
(26992, 1, 5, 1270, 944, 0),
(26992, 1, 6, 1291, 935, 0),
(26992, 1, 7, 1313, 944, 0),
(26992, 2, 0, 1475, 870, 0),
(26992, 2, 1, 1466, 893, 0),
(26992, 2, 2, 1444, 902, 0),
(26992, 2, 3, 1421, 893, 0),
(26992, 2, 4, 1412, 870, 0),
(26992, 2, 5, 1421, 848, 0),
(26992, 2, 6, 1444, 839, 0),
(26992, 2, 7, 1466, 848, 0),
(26992, 3, 0, 1268, 1152, 0),
(26992, 3, 1, 1261, 1168, 0),
(26992, 3, 2, 1245, 1175, 0),
(26992, 3, 3, 1228, 1168, 0),
(26992, 3, 4, 1221, 1152, 0),
(26992, 3, 5, 1228, 1135, 0),
(26992, 3, 6, 1245, 1129, 0),
(26992, 3, 7, 1261, 1135, 0),
(26992, 4, 0, 1349, 813, 0),
(26992, 4, 1, 1343, 827, 0),
(26992, 4, 2, 1328, 833, 0),
(26992, 4, 3, 1314, 827, 0),
(26992, 4, 4, 1308, 813, 0),
(26992, 4, 5, 1314, 798, 0),
(26992, 4, 6, 1328, 792, 0),
(26992, 4, 7, 1343, 798, 0),
(26992, 5, 0, 1409, 1066, 0),
(27039, 0, 0, 1304, 1188, 0),
(27056, 0, 0, 1385, 1045, 0),
(27065, 0, 0, 1069, 1601, 0),
(27097, 0, 0, 977, 691, 0),
(27097, 0, 1, 961, 730, 0),
(27097, 0, 2, 922, 746, 0),
(27097, 0, 3, 883, 730, 0),
(27097, 0, 4, 867, 691, 0),
(27097, 0, 5, 883, 652, 0),
(27097, 0, 6, 922, 636, 0),
(27097, 0, 7, 961, 652, 0),
(27097, 1, 0, 881, 688, 0),
(27097, 1, 1, 866, 724, 0),
(27097, 1, 2, 830, 739, 0),
(27097, 1, 3, 793, 724, 0),
(27097, 1, 4, 778, 688, 0),
(27097, 1, 5, 793, 651, 0),
(27097, 1, 6, 830, 636, 0),
(27097, 1, 7, 866, 651, 0),
(27097, 2, 0, 1075, 725, 0),
(27097, 2, 1, 1059, 762, 0),
(27097, 2, 2, 1022, 778, 0),
(27097, 2, 3, 984, 762, 0),
(27097, 2, 4, 969, 725, 0),
(27097, 2, 5, 984, 688, 0),
(27097, 2, 6, 1022, 672, 0),
(27097, 2, 7, 1059, 688, 0),
(27097, 3, 0, 1013, 618, 0),
(27097, 3, 1, 1001, 647, 0),
(27097, 3, 2, 972, 659, 0),
(27097, 3, 3, 943, 647, 0),
(27097, 3, 4, 931, 618, 0),
(27097, 3, 5, 943, 589, 0),
(27097, 3, 6, 972, 577, 0),
(27097, 3, 7, 1001, 589, 0),
(27097, 4, 0, 1129, 722, 0),
(27097, 4, 1, 1118, 749, 0),
(27097, 4, 2, 1090, 761, 0),
(27097, 4, 3, 1063, 749, 0),
(27097, 4, 4, 1051, 722, 0),
(27097, 4, 5, 1063, 695, 0),
(27097, 4, 6, 1090, 683, 0),
(27097, 4, 7, 1118, 695, 0),
(27097, 5, 0, 1385, 1045, 0),
(27098, 0, 0, 501, 1565, 0),
(27099, 0, 0, 1385, 1045, 0),
(27181, 0, 0, 185, 1437, 0),
(27181, 0, 1, 170, 1472, 0),
(27181, 0, 2, 135, 1487, 0),
(27181, 0, 3, 100, 1472, 0),
(27181, 0, 4, 85, 1437, 0),
(27181, 0, 5, 100, 1402, 0),
(27181, 0, 6, 135, 1387, 0),
(27181, 0, 7, 170, 1402, 0),
(27181, 1, 0, 298, 1441, 0),
(27181, 1, 1, 282, 1479, 0),
(27181, 1, 2, 245, 1495, 0),
(27181, 1, 3, 207, 1479, 0),
(27181, 1, 4, 191, 1441, 0),
(27181, 1, 5, 207, 1403, 0),
(27181, 1, 6, 245, 1388, 0),
(27181, 1, 7, 282, 1403, 0),
(27181, 2, 0, 303, 1564, 0),
(27181, 2, 1, 289, 1597, 0),
(27181, 2, 2, 256, 1610, 0),
(27181, 2, 3, 224, 1597, 0),
(27181, 2, 4, 210, 1564, 0),
(27181, 2, 5, 224, 1531, 0),
(27181, 2, 6, 256, 1518, 0),
(27181, 2, 7, 289, 1531, 0),
(27181, 3, 0, 224, 1378, 0),
(27181, 3, 1, 215, 1400, 0),
(27181, 3, 2, 193, 1409, 0),
(27181, 3, 3, 172, 1400, 0),
(27181, 3, 4, 163, 1378, 0),
(27181, 3, 5, 172, 1357, 0),
(27181, 3, 6, 193, 1347, 0),
(27181, 3, 7, 215, 1357, 0),
(27181, 4, 0, 239, 1494, 0),
(27181, 4, 1, 232, 1511, 0),
(27181, 4, 2, 215, 1518, 0),
(27181, 4, 3, 198, 1511, 0),
(27181, 4, 4, 191, 1494, 0),
(27181, 4, 5, 198, 1477, 0),
(27181, 4, 6, 215, 1470, 0),
(27181, 4, 7, 232, 1477, 0),
(27181, 5, 0, 501, 1565, 0),
(27438, 0, 0, -153, 1270, 0),
(27472, 0, 0, -153, 1270, 0),
(27474, 0, 0, -153, 1270, 0),
(27476, 0, 0, 456, 1473, 0),
(27484, 0, 0, -153, 1270, 0),
(27510, 0, 0, -430, 828, 0),
(27510, 0, 1, -442, 855, 0),
(27510, 0, 2, -469, 866, 0),
(27510, 0, 3, -496, 855, 0),
(27510, 0, 4, -508, 828, 0),
(27510, 0, 5, -496, 800, 0),
(27510, 0, 6, -469, 789, 0),
(27510, 0, 7, -442, 800, 0),
(27510, 1, 0, -406, 730, 0),
(27510, 1, 1, -419, 762, 0),
(27510, 1, 2, -451, 776, 0),
(27510, 1, 3, -483, 762, 0),
(27510, 1, 4, -497, 730, 0),
(27510, 1, 5, -483, 698, 0),
(27510, 1, 6, -451, 684, 0),
(27510, 1, 7, -419, 698, 0),
(27510, 2, 0, -444, 896, 0),
(27510, 2, 1, -452, 918, 0),
(27510, 2, 2, -474, 926, 0),
(27510, 2, 3, -495, 918, 0),
(27510, 2, 4, -504, 896, 0),
(27510, 2, 5, -495, 875, 0),
(27510, 2, 6, -474, 866, 0),
(27510, 2, 7, -452, 875, 0),
(27510, 3, 0, -190, 1294, 0),
(27512, 0, 0, -291, 1011, 0),
(27513, 0, 0, -148, 895, 0),
(27513, 0, 1, -162, 928, 0),
(27513, 0, 2, -194, 941, 0),
(27513, 0, 3, -227, 928, 0),
(27513, 0, 4, -240, 895, 0),
(27513, 0, 5, -227, 863, 0),
(27513, 0, 6, -194, 849, 0),
(27513, 0, 7, -162, 863, 0),
(27513, 1, 0, -35, 1022, 0),
(27513, 1, 1, -50, 1058, 0),
(27513, 1, 2, -86, 1073, 0),
(27513, 1, 3, -122, 1058, 0),
(27513, 1, 4, -136, 1022, 0),
(27513, 1, 5, -122, 986, 0),
(27513, 1, 6, -86, 971, 0),
(27513, 1, 7, -50, 986, 0),
(27513, 2, 0, -120, 992, 0),
(27513, 2, 1, -134, 1027, 0),
(27513, 2, 2, -168, 1041, 0),
(27513, 2, 3, -202, 1027, 0),
(27513, 2, 4, -216, 992, 0),
(27513, 2, 5, -202, 958, 0),
(27513, 2, 6, -168, 944, 0),
(27513, 2, 7, -134, 958, 0),
(27513, 3, 0, -85, 955, 0),
(27513, 3, 1, -94, 976, 0),
(27513, 3, 2, -115, 985, 0),
(27513, 3, 3, -137, 976, 0),
(27513, 3, 4, -145, 955, 0),
(27513, 3, 5, -137, 933, 0),
(27513, 3, 6, -115, 924, 0),
(27513, 3, 7, -94, 933, 0),
(27513, 4, 0, -113, 845, 0),
(27513, 4, 1, -122, 867, 0),
(27513, 4, 2, -143, 875, 0),
(27513, 4, 3, -165, 867, 0),
(27513, 4, 4, -173, 845, 0),
(27513, 4, 5, -165, 824, 0),
(27513, 4, 6, -143, 815, 0),
(27513, 4, 7, -122, 824, 0),
(27513, 5, 0, -153, 1270, 0),
(27518, 0, 0, -121, 1067, 0),
(27518, 0, 1, -125, 1078, 0),
(27518, 0, 2, -136, 1082, 0),
(27518, 0, 3, -147, 1078, 0),
(27518, 0, 4, -151, 1067, 0),
(27518, 0, 5, -147, 1057, 0),
(27518, 0, 6, -136, 1052, 0),
(27518, 0, 7, -125, 1057, 0),
(27518, 1, 0, -153, 1270, 0),
(27542, 0, 0, -153, 1270, 0),
(27547, 0, 0, -366, 1599, 0),
(27547, 0, 1, -380, 1632, 0),
(27547, 0, 2, -413, 1646, 0),
(27547, 0, 3, -447, 1632, 0),
(27547, 0, 4, -460, 1599, 0),
(27547, 0, 5, -447, 1565, 0),
(27547, 0, 6, -413, 1552, 0),
(27547, 0, 7, -380, 1565, 0),
(27547, 1, 0, -303, 1592, 0),
(27547, 1, 1, -314, 1618, 0),
(27547, 1, 2, -340, 1629, 0),
(27547, 1, 3, -367, 1618, 0),
(27547, 1, 4, -378, 1592, 0),
(27547, 1, 5, -367, 1565, 0),
(27547, 1, 6, -340, 1554, 0),
(27547, 1, 7, -314, 1565, 0),
(27547, 2, 0, -293, 1489, 0),
(27547, 2, 1, -307, 1524, 0),
(27547, 2, 2, -342, 1538, 0),
(27547, 2, 3, -377, 1524, 0),
(27547, 2, 4, -391, 1489, 0),
(27547, 2, 5, -377, 1454, 0),
(27547, 2, 6, -342, 1440, 0),
(27547, 2, 7, -307, 1454, 0),
(27547, 3, 0, -358, 1477, 0),
(27547, 3, 1, -371, 1507, 0),
(27547, 3, 2, -401, 1519, 0),
(27547, 3, 3, -431, 1507, 0),
(27547, 3, 4, -444, 1477, 0),
(27547, 3, 5, -431, 1447, 0),
(27547, 3, 6, -401, 1434, 0),
(27547, 3, 7, -371, 1447, 0),
(27547, 4, 0, -153, 1270, 0),
(27548, 0, 0, -337, 1583, 0),
(27548, 0, 1, -353, 1622, 0),
(27548, 0, 2, -392, 1638, 0),
(27548, 0, 3, -431, 1622, 0),
(27548, 0, 4, -447, 1583, 0),
(27548, 0, 5, -431, 1544, 0),
(27548, 0, 6, -392, 1528, 0),
(27548, 0, 7, -353, 1544, 0),
(27548, 1, 0, -314, 1467, 0),
(27548, 1, 1, -330, 1504, 0),
(27548, 1, 2, -366, 1519, 0),
(27548, 1, 3, -403, 1504, 0),
(27548, 1, 4, -418, 1467, 0),
(27548, 1, 5, -403, 1431, 0),
(27548, 1, 6, -366, 1415, 0),
(27548, 1, 7, -330, 1431, 0),
(27548, 2, 0, -381, 1505, 0),
(27548, 2, 1, -395, 1539, 0),
(27548, 2, 2, -430, 1554, 0),
(27548, 2, 3, -464, 1539, 0),
(27548, 2, 4, -479, 1505, 0),
(27548, 2, 5, -464, 1470, 0),
(27548, 2, 6, -430, 1456, 0),
(27548, 2, 7, -395, 1470, 0),
(27548, 3, 0, -357, 1654, 0),
(27548, 3, 1, -367, 1680, 0),
(27548, 3, 2, -393, 1691, 0),
(27548, 3, 3, -419, 1680, 0),
(27548, 3, 4, -429, 1654, 0),
(27548, 3, 5, -419, 1628, 0),
(27548, 3, 6, -393, 1618, 0),
(27548, 3, 7, -367, 1628, 0),
(27548, 4, 0, -323, 1537, 0),
(27548, 4, 1, -329, 1552, 0),
(27548, 4, 2, -343, 1558, 0),
(27548, 4, 3, -358, 1552, 0),
(27548, 4, 4, -364, 1537, 0),
(27548, 4, 5, -358, 1523, 0),
(27548, 4, 6, -343, 1517, 0),
(27548, 4, 7, -329, 1523, 0),
(27548, 5, 0, -153, 1270, 0),
(27594, 0, 0, -789, 1339, 0),
(27594, 0, 1, -794, 1350, 0),
(27594, 0, 2, -804, 1354, 0),
(27594, 0, 3, -815, 1350, 0),
(27594, 0, 4, -819, 1339, 0),
(27594, 0, 5, -815, 1328, 0),
(27594, 0, 6, -804, 1324, 0),
(27594, 0, 7, -794, 1328, 0),
(27594, 1, 0, -153, 1270, 0),
(27601, 0, 0, -698, 1547, 0),
(27096, 0, 0, 1385, 1045, 0);

-- 6. 120 s respawn for the quest mobs and nodes these quests use
UPDATE `creature` SET `spawntimesecs` = 120 WHERE `id` = 4144966 AND `guid` IN (16715199, 16715200, 16715294,
    16715297, 16715298, 16715382, 16715383, 16715508, 16715510, 16715512, 16715513, 16715516, 16715517, 16715519,
    16715520, 16715523, 16715571, 16715692, 16715693);
UPDATE `creature` SET `spawntimesecs` = 120 WHERE `id` = 4144954 AND `guid` IN (16715293, 16715295, 16715299,
    16715380, 16715381, 16715384, 16715385, 16715509, 16715511, 16715514, 16715515, 16715518, 16715521, 16715567,
    16715568, 16715569, 16715570, 16715572, 16715573, 16715574, 16715689, 16715690, 16715691);
UPDATE `creature` SET `spawntimesecs` = 120 WHERE `id` = 4145195 AND `guid` IN (16714847, 16714848, 16714851,
    16714853, 16714861, 16714862, 16714867, 16714870, 16714871, 16714889, 16714894, 16714895, 16714897, 16714900,
    16714905, 16714907, 16714909, 16714910, 16714917, 16714920, 16714925, 16714928, 16714931, 16714936);
UPDATE `creature` SET `spawntimesecs` = 120 WHERE `id` = 4145750 AND `guid` IN (16714539, 16714540, 16714541,
    16714542, 16714544, 16714546, 16714548, 16714549, 16714633, 16714635, 16714637, 16714638, 16714639, 16714640,
    16714641, 16714643, 16714644, 16714645, 16714646, 16714649, 16714650, 16714651, 16714652, 16714653, 16714654,
    16714672, 16714674, 16714677, 16714716);
UPDATE `creature` SET `spawntimesecs` = 120 WHERE `id` = 4145910 AND `guid` IN (11545900, 11545901, 11545902,
    11545903, 11545904, 11545905, 11545906, 11545907, 11545908, 11545909, 11545910, 11545911, 11545912, 11545913,
    11545914, 11545915, 11545916, 11545917, 11545918, 11545919, 11545920, 11545921);
UPDATE `gameobject` SET `spawntimesecs` = 120 WHERE `id` = 4805099 AND `guid` IN (16401505, 16401508, 16401509,
    16401510, 16401512, 16401513, 16401525, 16401526, 16401530, 16401531, 16401532, 16401533, 16401534, 16401535,
    16401536, 16401538, 16401539, 16401540);
