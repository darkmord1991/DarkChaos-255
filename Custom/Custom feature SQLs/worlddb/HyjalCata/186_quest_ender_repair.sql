-- ---------------------------------------------------------------------------
-- 186  Hyjal round-45 -- repair quest enders on map 750
-- ---------------------------------------------------------------------------
-- 54 quests offered on map 750 had no quest ender anywhere, so they could be
-- picked up and never handed in.  Tracing each ender NPC's position in
-- cata_world splits them:
--
--   17 quests -- ender stands INSIDE our 279-tile footprint   <- fixable here
--    4 quests -- ender elsewhere on Kalimdor (off our map)
--    2 quests -- ender on map 0 (Eastern Kingdoms)
--    1 quest  -- ender on map 645 (Deepholm)
--    1 quest  -- ender on map 861 (Molten Front)
--   the rest  -- a creature_questender row exists but the NPC has no cata spawn
--
-- Only the first group is actionable; the others are the documented
-- carve-a-zone-out-of-a-continent dead-ends and are left alone.  This file
-- closes 11 of the 17.
--
-- TWO DISTINCT FAILURES, and they need different fixes:
--
--  A. SIX enders are already spawned on map 750 -- only the LINK row is
--     missing.  Raene Wolfrunner and Pelturas Whitemoon each already carry 4
--     other questender rows, so the NPC is fine; the quest just was not wired
--     to them.  These cost one INSERT each.
--
--  B. THREE Winterspring enders were never cloned.  They stand on tile 40_17,
--     inside the ORIGINAL 108 tiles -- which is precisely why they were missed:
--     178_'s mask covered only the 171 NEWLY ADDED tiles, and the earlier
--     rounds that owned the old tiles had narrower scopes of their own.  This
--     is a gap BETWEEN two imports, not a fault in either.  They need template,
--     model, addon and spawn before the link means anything.
--
-- The five in-footprint enders NOT fixed here are in Orgrimmar (Garrosh
-- Hellscream, Bort, Farseer Krogar) and Stonetalon (Saurboz, Kalen Trueshot).
-- Those are buffer zones the import whitelist excludes deliberately, so their
-- quests remain dead-ended by design.
--
-- ORDER: after 178_/180_.  Safe to re-run -- every insert is INSERT IGNORE and
-- the spawn block is guarded by a delete on exactly the ids it creates.
-- ---------------------------------------------------------------------------

SET @OFF := 3600000;


-- --- B: templates for the 3 uncloned Winterspring enders  (adapted from 01_creature_templates.sql) ---
INSERT IGNORE INTO acore_world.creature_template (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT `entry`+@OFF, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `flags_extra`, `ScriptName`, `VerifiedBuild` FROM cata_world.creature_template
WHERE entry IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.`id` IN (49396,49436,49537))) AND entry NOT IN (SELECT entry FROM acore_world.creature_template WHERE entry < @OFF);
INSERT IGNORE INTO acore_world.creature_template (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT `entry`+@OFF, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild` FROM acore_world.creature_template
WHERE entry IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.`id` IN (49396,49436,49537))) AND entry < @OFF;
INSERT IGNORE INTO acore_world.creature_template_model (`CreatureID`, `Idx`, `CreatureDisplayID`, `Probability`, `VerifiedBuild`)
SELECT `CreatureID`+@OFF, `Idx`, `CreatureDisplayID`, `Probability`, `VerifiedBuild` FROM cata_world.creature_template_model WHERE CreatureID IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.`id` IN (49396,49436,49537)));
INSERT IGNORE INTO acore_world.creature_template_addon (`entry`, `mount`, `emote`, `visibilityDistanceType`, `auras`)
SELECT `entry`+@OFF, `mount`, `emote`, `visibilityDistanceType`, `auras` FROM cata_world.creature_template_addon WHERE entry IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.`id` IN (49396,49436,49537))) AND entry NOT IN (SELECT entry FROM acore_world.creature_template WHERE entry < @OFF);
INSERT IGNORE INTO acore_world.creature_template_addon (`entry`, `mount`, `emote`, `visibilityDistanceType`, `auras`)
SELECT `entry`+@OFF, `mount`, `emote`, `visibilityDistanceType`, `auras` FROM acore_world.creature_template_addon WHERE entry IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.`id` IN (49396,49436,49537))) AND entry IN (SELECT entry FROM acore_world.creature_template WHERE entry < @OFF) AND entry < @OFF;
INSERT IGNORE INTO acore_world.creature_template_movement (`CreatureId`, `Ground`, `Swim`, `Flight`, `Rooted`, `Chase`, `Random`, `InteractionPauseTimer`)
SELECT cl.`entry`, sm.`Ground`, sm.`Swim`, sm.`Flight`, sm.`Rooted`, sm.`Chase`, sm.`Random`, sm.`InteractionPauseTimer`
FROM acore_world.creature_template cl
JOIN acore_world.creature_template_movement sm ON sm.CreatureId = cl.entry - @OFF
WHERE cl.entry IN (SELECT entry+@OFF FROM cata_world.creature_template WHERE entry IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.`id` IN (49396,49436,49537))));
INSERT IGNORE INTO acore_world.creature_template_movement (`CreatureId`, `Ground`, `Swim`, `Flight`, `Rooted`, `Chase`, `Random`, `InteractionPauseTimer`)
SELECT n.entry+@OFF, (n.InhabitType & 1), ((n.InhabitType >> 3) & 1), 1, 0, 0, 0, 0
FROM nelt_world.creature_template n
WHERE n.entry IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.`id` IN (49396,49436,49537)))
  AND n.InhabitType IN (4,5,6,7);


-- B: their spawns.  Delete first so a re-run cannot stack duplicates (spawns
-- use auto-guid), scoped to exactly the three ids this file creates.
DELETE FROM `creature` WHERE `map` = 750 AND `id` IN (3649396,3649436,3649537);


-- --- B: spawn rows, tagged Winterspring (4926)  (adapted from 04_spawns.sql) ---
INSERT INTO acore_world.creature (`id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`)
SELECT c.`id`+@OFF, 750, 4926, 4926, c.`spawnMask`, c.`phaseMask`, c.`equipment_id`, c.`position_x`, c.`position_y`, c.`position_z`, c.`orientation`, c.`spawntimesecs`, c.`wander_distance`, c.`currentwaypoint`, COALESCE(c.`curhealth`,1), COALESCE(c.`curmana`,0), c.`MovementType`, COALESCE(c.`npcflag`,0), COALESCE(c.`unit_flags`,0)
FROM cata_world.creature c WHERE (c.`id` IN (49396,49436,49537));


-- --- A + B: the questender links -------------------------------------------
-- INSERT IGNORE, so the six NPCs that already carry other links keep them.
INSERT IGNORE INTO `creature_questender` (`id`, `quest`) VALUES
  (3603691, 13645),  -- Raene Wolfrunner
  (3603880, 13935),  -- Sentinel Melyria Frostshadow
  (3603891, 26463),  -- Teronis' Corpse
  (3603894, 26474),  -- Pelturas Whitemoon
  (3617310, 13796),  -- Gnarl
  (3635086, 14155),  -- Labor Captain Grabbit
  (3649396, 28641),  -- Jez Goodgrub
  (3649396, 28718),  -- Jez Goodgrub
  (3649436, 28639),  -- Francis Morcott
  (3649436, 28719),  -- Francis Morcott
  (3649537, 28782);  -- Jeb Guthrie


-- Verify -- expect the no-ender count to drop from 54 to 43:
--   SELECT COUNT(DISTINCT qs.quest) FROM `creature_queststarter` qs
--     JOIN `creature` c ON c.id = qs.id
--    WHERE c.map = 750
--      AND qs.quest NOT IN (SELECT quest FROM `creature_questender`)
--      AND qs.quest NOT IN (SELECT quest FROM `gameobject_questender`);
-- And that the three new enders exist and are spawned:
--   SELECT id, name FROM `creature_template` WHERE entry IN (3649396, 3649436, 3649537);
--   SELECT id, COUNT(*) FROM `creature` WHERE map = 750
--     AND id IN (3649396, 3649436, 3649537) GROUP BY id;
