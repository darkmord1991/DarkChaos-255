-- DarkChaos: map 751 Alliance route - an innkeeper at the Whispering Shore landing in Tirisfal Glades
--
-- Owner's decision of 2026-11-13. The 7th Legion landing at the Whispering Shore (Scout Ellery Halvorsen 830313, 12
-- quests of phases 1 and 2) had no innkeeper, so playerbots had no Alliance hub in Tirisfal (zone 4933): bot hubs
-- come from innkeepers. Innkeeper Rowena Pike (830330) is a copy of Innkeeper Hallam (830307: Stormwind faction 123,
-- innkeeper + food vendor, gossip 345 with the bind option) at level 136, with the display of Innkeeper Brianna
-- (5407, human female, already in the client DBC and creature_model_info), and sells what Innkeeper Brumli (830300)
-- sells, like the two Gilneas innkeepers of phase 2.
-- Spawn guid 9025349 at (2620.0, 1812.0, 17.06), orientation 5.18, zone 4933 / area 16621 (Whispering Shore), 9 yd
-- west of the scout on dry beach; z from the terrain heightmap of the test client (check with .gps).
-- Rested XP is not part of this file: the AreaTrigger.dbc row and areatrigger / areatrigger_tavern are the owner's.
-- Bots: add Playerbots.ZoneBracket.Alliance.4933 = 130,135 in the live playerbots.conf so the hub has an Alliance
-- bracket of its own (without it the faction-neutral 4933 = 130,136 applies).
-- IDS: creature_template 830330, creature guid 9025349 (both verified free; not used by the phase-2 files).
-- DEPENDS ON: phase 1 (830300's vendor list). REVERT: delete creature 9025349, creature_template / _model 830330 and
--   npc_vendor 830330.
-- Re-runnable. Apply to acore_world, then restart the worldserver.

REPLACE INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(830330, 0, 0, 0, 0, 0, 'Innkeeper Rowena Pike', 'Innkeeper', NULL, 345, 136, 136, 0, 123, 66177, 1, 1.14286, 1, 1, 20, 1, 0, 2, 2000, 2000, 1, 1, 1, 512, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 13, 1, 1, 1, 0, 0, 1, 0, 2, '', 0);
DELETE FROM `creature_template_model` WHERE `CreatureID` = 830330;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(830330, 0, 5407, 1, 1, 0);
DELETE FROM `npc_vendor` WHERE `entry` = 830330;
INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`, `VerifiedBuild`)
SELECT 830330, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`, 0 FROM `npc_vendor` WHERE `entry` = 830300;
DELETE FROM `creature` WHERE `guid` = 9025349 AND `id` = 830330;
INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`, `CreateObject`, `Comment`) VALUES
(9025349, 830330, 751, 4933, 16621, 1, 1, 0, 2620, 1812, 17.06, 5.18, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC Alliance 751: Whispering Shore landing innkeeper (bot hub)');

-- Verification, to run after applying (expected values in the labels):
--   SELECT 'innkeeper spawn (want 1)' AS `check`, COUNT(*) AS `n` FROM `creature` WHERE `guid` = 9025349 AND `id` = 830330
--   UNION ALL SELECT 'vendor rows (want 20)', COUNT(*) FROM `npc_vendor` WHERE `entry` = 830330;
