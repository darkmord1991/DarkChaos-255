-- Plaguelands (DCPlaguelands, map 751)
-- dc_entry = 3,600,000 + original (isolated, tunable). Source cata_world(TDB434)->acore_world. Cross-DB INSERT...SELECT.
SET @OFF := 3600000;

-- Cata-new templates (clone from cata_world, col intersection)
INSERT IGNORE INTO acore_world.creature_template (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT `entry`+@OFF, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `flags_extra`, `ScriptName`, `VerifiedBuild` FROM cata_world.creature_template
WHERE entry IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=0 AND c.zoneId IN (139,28))) AND entry NOT IN (SELECT entry FROM acore_world.creature_template WHERE entry < @OFF);

-- Stock-AC templates (clone from acore_world, 3.3.5 stats)
INSERT IGNORE INTO acore_world.creature_template (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT `entry`+@OFF, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild` FROM acore_world.creature_template
WHERE entry IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=0 AND c.zoneId IN (139,28))) AND entry < @OFF;

-- display models (cata has no DisplayScale -> defaults)
INSERT IGNORE INTO acore_world.creature_template_model (`CreatureID`, `Idx`, `CreatureDisplayID`, `Probability`, `VerifiedBuild`)
SELECT `CreatureID`+@OFF, `Idx`, `CreatureDisplayID`, `Probability`, `VerifiedBuild` FROM cata_world.creature_template_model WHERE CreatureID IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=0 AND c.zoneId IN (139,28)));

-- template addon (auras/mount/emote)
INSERT IGNORE INTO acore_world.creature_template_addon (`entry`, `mount`, `emote`, `visibilityDistanceType`, `auras`)
SELECT `entry`+@OFF, `mount`, `emote`, `visibilityDistanceType`, `auras` FROM cata_world.creature_template_addon WHERE entry IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=0 AND c.zoneId IN (139,28))) AND entry NOT IN (SELECT entry FROM acore_world.creature_template WHERE entry < @OFF);
INSERT IGNORE INTO acore_world.creature_template_addon (`entry`, `mount`, `emote`, `visibilityDistanceType`, `auras`)
SELECT `entry`+@OFF, `mount`, `emote`, `visibilityDistanceType`, `auras` FROM acore_world.creature_template_addon WHERE entry IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=0 AND c.zoneId IN (139,28))) AND entry IN (SELECT entry FROM acore_world.creature_template WHERE entry < @OFF) AND entry < @OFF;

-- creature_template_movement (cata_world has NO Ground/Swim/Flight/Rooted columns
-- to clone from - only CreatureId/HoverInitiallyEnabled/Random - so this zone's
-- flying NPCs previously got zero movement rows and fell to the ground. Bucket A:
-- reuse the acore-stock original's movement row when one already exists (covers
-- the "Stock-AC templates" branch above and any coincidental id overlap). Bucket
-- B: derive Flight from nelt_world's real InhabitType column (bit 0x4 = air-
-- capable) for everything else; InhabitType=3 is TrinityCore's ground-creature
-- default and is deliberately excluded as an unreliable flight signal.
INSERT IGNORE INTO acore_world.creature_template_movement (`CreatureId`, `Ground`, `Swim`, `Flight`, `Rooted`, `Chase`, `Random`, `InteractionPauseTimer`)
SELECT cl.`entry`, sm.`Ground`, sm.`Swim`, sm.`Flight`, sm.`Rooted`, sm.`Chase`, sm.`Random`, sm.`InteractionPauseTimer`
FROM acore_world.creature_template cl
JOIN acore_world.creature_template_movement sm ON sm.CreatureId = cl.entry - @OFF
WHERE cl.entry IN (SELECT entry+@OFF FROM cata_world.creature_template WHERE entry IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=0 AND c.zoneId IN (139,28))));
INSERT IGNORE INTO acore_world.creature_template_movement (`CreatureId`, `Ground`, `Swim`, `Flight`, `Rooted`, `Chase`, `Random`, `InteractionPauseTimer`)
SELECT n.entry+@OFF, (n.InhabitType & 1), ((n.InhabitType >> 3) & 1), 1, 0, 0, 0, 0
FROM nelt_world.creature_template n
WHERE n.entry IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=0 AND c.zoneId IN (139,28)))
  AND n.InhabitType IN (4,5,6,7);
