-- ---------------------------------------------------------------------------
-- 178  Hyjal round-44 -- populate the terrain added by the 108 -> 279 expansion
-- ---------------------------------------------------------------------------
-- The expansion (client patch-4/patch-6, same round) grew map 750 so the seven
-- zones are whole instead of clipped: southern Ashenvale, eastern Azshara
-- (Bilgewater side), the Moonglade rim and the Winterspring/Darkshore edges.
-- That ground shipped EMPTY.  This file imports the Cata content that belongs
-- on it: 6,323 creatures and 1,669 gameobjects (counted against the live
-- cata_world with this file's exact mask + whitelist).  Ashenvale 3,386 and
-- Azshara 2,810 dominate; Winterspring 90, Moonglade 22, Darkshore 15.
-- A binning pass over the terrain chunks alone returns ~620 more -- those are
-- Stonetalon/Durotar NPCs standing on buffer chunks that the retag folded into
-- Ashenvale/Azshara.  The whitelist excludes them ON PURPOSE.
--
-- SCOPE IS A TILE MASK, NOT A BOX.  `_dc_nt_mask` holds one 533x533 rect per
-- NEWLY ADDED tile (171 of them), so nothing here can touch the 108 tiles that
-- were already populated -- re-running cannot duplicate the existing map.  The
-- zone whitelist (16 Azshara, 148 Darkshore, 331 Ashenvale, 493 Moonglade,
-- 618 Winterspring) is the second guard: the kept tiles also carry Stonetalon,
-- Durotar and Teldrassil buffer chunks, and that terrain is meant to stay empty.
--
-- ZONE TAG: unlike 176_ (single zone) this import spans five zones, so
-- zoneId/areaId are stamped per row from the source zone via CASE.
--
-- NOTE the original 04_spawns.sql begins with a GLOBAL
--   DELETE FROM acore_world.creature WHERE map=750 AND id>=@OFF;
-- which would wipe every Cata spawn on the map.  It is stripped here and
-- replaced by the mask-scoped deletes below -- that is what makes this file
-- idempotent without being destructive.
--
-- ORDER: after the client patch is live and the server has maps/vmaps/mmaps
-- for the 279-tile set, else these spawns sit on ground the server cannot load.
-- ---------------------------------------------------------------------------

SET @OFF := 3600000;

DROP TABLE IF EXISTS `_dc_nt_mask`;
CREATE TABLE `_dc_nt_mask` (
  `xmin` FLOAT NOT NULL, `xmax` FLOAT NOT NULL,
  `ymin` FLOAT NOT NULL, `ymax` FLOAT NOT NULL
) ENGINE=InnoDB;

INSERT INTO `_dc_nt_mask` (`xmin`,`xmax`,`ymin`,`ymax`) VALUES
(6933.333,7466.667,2133.333,2666.667),
(6400.0,6933.333,2133.333,2666.667),
(5866.667,6400.0,2133.333,2666.667),
(5333.333,5866.667,2133.333,2666.667),
(4800.0,5333.333,2133.333,2666.667),
(4266.667,4800.0,2133.333,2666.667),
(3733.333,4266.667,2133.333,2666.667),
(3200.0,3733.333,2133.333,2666.667),
(2666.667,3200.0,2133.333,2666.667),
(6933.333,7466.667,1600.0,2133.333),
(6400.0,6933.333,1600.0,2133.333),
(5866.667,6400.0,1600.0,2133.333),
(5333.333,5866.667,1600.0,2133.333),
(4800.0,5333.333,1600.0,2133.333),
(4266.667,4800.0,1600.0,2133.333),
(3733.333,4266.667,1600.0,2133.333),
(3200.0,3733.333,1600.0,2133.333),
(2666.667,3200.0,1600.0,2133.333),
(7466.667,8000.0,1066.667,1600.0),
(6933.333,7466.667,1066.667,1600.0),
(6400.0,6933.333,1066.667,1600.0),
(5866.667,6400.0,1066.667,1600.0),
(5333.333,5866.667,1066.667,1600.0),
(4800.0,5333.333,1066.667,1600.0),
(4266.667,4800.0,1066.667,1600.0),
(3733.333,4266.667,1066.667,1600.0),
(3200.0,3733.333,1066.667,1600.0),
(2666.667,3200.0,1066.667,1600.0),
(2666.667,3200.0,533.333,1066.667),
(2133.333,2666.667,533.333,1066.667),
(1600.0,2133.333,533.333,1066.667),
(8000.0,8533.333,0.0,533.333),
(2666.667,3200.0,0.0,533.333),
(2133.333,2666.667,0.0,533.333),
(1600.0,2133.333,0.0,533.333),
(8000.0,8533.333,-533.333,0.0),
(2666.667,3200.0,-533.333,0.0),
(2133.333,2666.667,-533.333,0.0),
(1600.0,2133.333,-533.333,0.0),
(8533.333,9066.667,-1066.667,-533.333),
(8000.0,8533.333,-1066.667,-533.333),
(2666.667,3200.0,-1066.667,-533.333),
(2133.333,2666.667,-1066.667,-533.333),
(1600.0,2133.333,-1066.667,-533.333),
(8533.333,9066.667,-1600.0,-1066.667),
(8000.0,8533.333,-1600.0,-1066.667),
(2666.667,3200.0,-1600.0,-1066.667),
(2133.333,2666.667,-1600.0,-1066.667),
(1600.0,2133.333,-1600.0,-1066.667),
(1066.667,1600.0,-1600.0,-1066.667),
(8533.333,9066.667,-2133.333,-1600.0),
(8000.0,8533.333,-2133.333,-1600.0),
(2666.667,3200.0,-2133.333,-1600.0),
(2133.333,2666.667,-2133.333,-1600.0),
(1600.0,2133.333,-2133.333,-1600.0),
(1066.667,1600.0,-2133.333,-1600.0),
(8533.333,9066.667,-2666.667,-2133.333),
(8000.0,8533.333,-2666.667,-2133.333),
(2666.667,3200.0,-2666.667,-2133.333),
(2133.333,2666.667,-2666.667,-2133.333),
(1600.0,2133.333,-2666.667,-2133.333),
(1066.667,1600.0,-2666.667,-2133.333),
(8533.333,9066.667,-3200.0,-2666.667),
(8000.0,8533.333,-3200.0,-2666.667),
(2666.667,3200.0,-3200.0,-2666.667),
(2133.333,2666.667,-3200.0,-2666.667),
(1600.0,2133.333,-3200.0,-2666.667),
(1066.667,1600.0,-3200.0,-2666.667),
(8533.333,9066.667,-3733.333,-3200.0),
(8000.0,8533.333,-3733.333,-3200.0),
(2666.667,3200.0,-3733.333,-3200.0),
(2133.333,2666.667,-3733.333,-3200.0),
(1600.0,2133.333,-3733.333,-3200.0),
(1066.667,1600.0,-3733.333,-3200.0),
(8533.333,9066.667,-4266.667,-3733.333),
(8000.0,8533.333,-4266.667,-3733.333),
(2666.667,3200.0,-4266.667,-3733.333),
(2133.333,2666.667,-4266.667,-3733.333),
(1600.0,2133.333,-4266.667,-3733.333),
(8533.333,9066.667,-4800.0,-4266.667),
(8000.0,8533.333,-4800.0,-4266.667),
(2666.667,3200.0,-4800.0,-4266.667),
(2133.333,2666.667,-4800.0,-4266.667),
(8533.333,9066.667,-5333.333,-4800.0),
(8000.0,8533.333,-5333.333,-4800.0),
(2666.667,3200.0,-5333.333,-4800.0),
(2133.333,2666.667,-5333.333,-4800.0),
(8533.333,9066.667,-5866.667,-5333.333),
(8000.0,8533.333,-5866.667,-5333.333),
(7466.667,8000.0,-5866.667,-5333.333),
(6933.333,7466.667,-5866.667,-5333.333),
(6400.0,6933.333,-5866.667,-5333.333),
(5866.667,6400.0,-5866.667,-5333.333),
(5333.333,5866.667,-5866.667,-5333.333),
(4800.0,5333.333,-5866.667,-5333.333),
(4266.667,4800.0,-5866.667,-5333.333),
(3733.333,4266.667,-5866.667,-5333.333),
(3200.0,3733.333,-5866.667,-5333.333),
(2666.667,3200.0,-5866.667,-5333.333),
(2133.333,2666.667,-5866.667,-5333.333),
(1600.0,2133.333,-5866.667,-5333.333),
(1066.667,1600.0,-5866.667,-5333.333),
(8533.333,9066.667,-6400.0,-5866.667),
(8000.0,8533.333,-6400.0,-5866.667),
(7466.667,8000.0,-6400.0,-5866.667),
(6933.333,7466.667,-6400.0,-5866.667),
(6400.0,6933.333,-6400.0,-5866.667),
(5866.667,6400.0,-6400.0,-5866.667),
(5333.333,5866.667,-6400.0,-5866.667),
(4800.0,5333.333,-6400.0,-5866.667),
(4266.667,4800.0,-6400.0,-5866.667),
(3733.333,4266.667,-6400.0,-5866.667),
(3200.0,3733.333,-6400.0,-5866.667),
(2666.667,3200.0,-6400.0,-5866.667),
(2133.333,2666.667,-6400.0,-5866.667),
(1600.0,2133.333,-6400.0,-5866.667),
(1066.667,1600.0,-6400.0,-5866.667),
(8533.333,9066.667,-6933.333,-6400.0),
(8000.0,8533.333,-6933.333,-6400.0),
(7466.667,8000.0,-6933.333,-6400.0),
(6933.333,7466.667,-6933.333,-6400.0),
(6400.0,6933.333,-6933.333,-6400.0),
(5866.667,6400.0,-6933.333,-6400.0),
(5333.333,5866.667,-6933.333,-6400.0),
(4800.0,5333.333,-6933.333,-6400.0),
(4266.667,4800.0,-6933.333,-6400.0),
(3733.333,4266.667,-6933.333,-6400.0),
(3200.0,3733.333,-6933.333,-6400.0),
(2666.667,3200.0,-6933.333,-6400.0),
(2133.333,2666.667,-6933.333,-6400.0),
(1600.0,2133.333,-6933.333,-6400.0),
(1066.667,1600.0,-6933.333,-6400.0),
(5866.667,6400.0,-7466.667,-6933.333),
(5333.333,5866.667,-7466.667,-6933.333),
(4800.0,5333.333,-7466.667,-6933.333),
(4266.667,4800.0,-7466.667,-6933.333),
(3733.333,4266.667,-7466.667,-6933.333),
(3200.0,3733.333,-7466.667,-6933.333),
(2666.667,3200.0,-7466.667,-6933.333),
(2133.333,2666.667,-7466.667,-6933.333),
(1600.0,2133.333,-7466.667,-6933.333),
(1066.667,1600.0,-7466.667,-6933.333),
(5866.667,6400.0,-8000.0,-7466.667),
(5333.333,5866.667,-8000.0,-7466.667),
(4800.0,5333.333,-8000.0,-7466.667),
(4266.667,4800.0,-8000.0,-7466.667),
(3733.333,4266.667,-8000.0,-7466.667),
(3200.0,3733.333,-8000.0,-7466.667),
(2666.667,3200.0,-8000.0,-7466.667),
(2133.333,2666.667,-8000.0,-7466.667),
(1600.0,2133.333,-8000.0,-7466.667),
(1066.667,1600.0,-8000.0,-7466.667),
(5866.667,6400.0,-8533.333,-8000.0),
(5333.333,5866.667,-8533.333,-8000.0),
(4800.0,5333.333,-8533.333,-8000.0),
(4266.667,4800.0,-8533.333,-8000.0),
(3733.333,4266.667,-8533.333,-8000.0),
(3200.0,3733.333,-8533.333,-8000.0),
(2666.667,3200.0,-8533.333,-8000.0),
(2133.333,2666.667,-8533.333,-8000.0),
(1600.0,2133.333,-8533.333,-8000.0),
(1066.667,1600.0,-8533.333,-8000.0),
(5333.333,5866.667,-9066.667,-8533.333),
(4800.0,5333.333,-9066.667,-8533.333),
(4266.667,4800.0,-9066.667,-8533.333),
(3733.333,4266.667,-9066.667,-8533.333),
(3200.0,3733.333,-9066.667,-8533.333),
(2666.667,3200.0,-9066.667,-8533.333),
(2133.333,2666.667,-9066.667,-8533.333),
(1600.0,2133.333,-9066.667,-8533.333),
(1066.667,1600.0,-9066.667,-8533.333);


-- --- idempotency: clear only prior imports INSIDE the new-tile mask ---------
DELETE FROM `creature_addon` WHERE `guid` IN (SELECT `guid` FROM (
  SELECT c.`guid` FROM `creature` c
  WHERE c.`map` = 750 AND c.`id` >= @OFF
    AND EXISTS (SELECT 1 FROM `_dc_nt_mask` m
                WHERE c.`position_x` > m.`xmin` AND c.`position_x` <= m.`xmax`
                  AND c.`position_y` > m.`ymin` AND c.`position_y` <= m.`ymax`)) t);

DELETE FROM `creature` WHERE `map` = 750 AND `id` >= @OFF
  AND EXISTS (SELECT 1 FROM `_dc_nt_mask` m
              WHERE `position_x` > m.`xmin` AND `position_x` <= m.`xmax`
                AND `position_y` > m.`ymin` AND `position_y` <= m.`ymax`);

DELETE FROM `gameobject` WHERE `map` = 750 AND `id` >= @OFF
  AND EXISTS (SELECT 1 FROM `_dc_nt_mask` m
              WHERE `position_x` > m.`xmin` AND `position_x` <= m.`xmax`
                AND `position_y` > m.`ymin` AND `position_y` <= m.`ymax`);


-- --- creature templates (+model/addon/movement)  (adapted from 01_creature_templates.sql) ---
INSERT IGNORE INTO acore_world.creature_template (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT `entry`+@OFF, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `flags_extra`, `ScriptName`, `VerifiedBuild` FROM cata_world.creature_template
WHERE entry IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId IN (16,148,331,493,618) AND EXISTS (SELECT 1 FROM `_dc_nt_mask` m WHERE c.position_x > m.`xmin` AND c.position_x <= m.`xmax` AND c.position_y > m.`ymin` AND c.position_y <= m.`ymax`))) AND entry NOT IN (SELECT entry FROM acore_world.creature_template WHERE entry < @OFF);

INSERT IGNORE INTO acore_world.creature_template (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT `entry`+@OFF, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild` FROM acore_world.creature_template
WHERE entry IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId IN (16,148,331,493,618) AND EXISTS (SELECT 1 FROM `_dc_nt_mask` m WHERE c.position_x > m.`xmin` AND c.position_x <= m.`xmax` AND c.position_y > m.`ymin` AND c.position_y <= m.`ymax`))) AND entry < @OFF;

INSERT IGNORE INTO acore_world.creature_template_model (`CreatureID`, `Idx`, `CreatureDisplayID`, `Probability`, `VerifiedBuild`)
SELECT `CreatureID`+@OFF, `Idx`, `CreatureDisplayID`, `Probability`, `VerifiedBuild` FROM cata_world.creature_template_model WHERE CreatureID IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId IN (16,148,331,493,618) AND EXISTS (SELECT 1 FROM `_dc_nt_mask` m WHERE c.position_x > m.`xmin` AND c.position_x <= m.`xmax` AND c.position_y > m.`ymin` AND c.position_y <= m.`ymax`)));

INSERT IGNORE INTO acore_world.creature_template_addon (`entry`, `mount`, `emote`, `visibilityDistanceType`, `auras`)
SELECT `entry`+@OFF, `mount`, `emote`, `visibilityDistanceType`, `auras` FROM cata_world.creature_template_addon WHERE entry IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId IN (16,148,331,493,618) AND EXISTS (SELECT 1 FROM `_dc_nt_mask` m WHERE c.position_x > m.`xmin` AND c.position_x <= m.`xmax` AND c.position_y > m.`ymin` AND c.position_y <= m.`ymax`))) AND entry NOT IN (SELECT entry FROM acore_world.creature_template WHERE entry < @OFF);
INSERT IGNORE INTO acore_world.creature_template_addon (`entry`, `mount`, `emote`, `visibilityDistanceType`, `auras`)
SELECT `entry`+@OFF, `mount`, `emote`, `visibilityDistanceType`, `auras` FROM acore_world.creature_template_addon WHERE entry IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId IN (16,148,331,493,618) AND EXISTS (SELECT 1 FROM `_dc_nt_mask` m WHERE c.position_x > m.`xmin` AND c.position_x <= m.`xmax` AND c.position_y > m.`ymin` AND c.position_y <= m.`ymax`))) AND entry IN (SELECT entry FROM acore_world.creature_template WHERE entry < @OFF) AND entry < @OFF;

INSERT IGNORE INTO acore_world.creature_template_movement (`CreatureId`, `Ground`, `Swim`, `Flight`, `Rooted`, `Chase`, `Random`, `InteractionPauseTimer`)
SELECT cl.`entry`, sm.`Ground`, sm.`Swim`, sm.`Flight`, sm.`Rooted`, sm.`Chase`, sm.`Random`, sm.`InteractionPauseTimer`
FROM acore_world.creature_template cl
JOIN acore_world.creature_template_movement sm ON sm.CreatureId = cl.entry - @OFF
WHERE cl.entry IN (SELECT entry+@OFF FROM cata_world.creature_template WHERE entry IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId IN (16,148,331,493,618) AND EXISTS (SELECT 1 FROM `_dc_nt_mask` m WHERE c.position_x > m.`xmin` AND c.position_x <= m.`xmax` AND c.position_y > m.`ymin` AND c.position_y <= m.`ymax`))));
INSERT IGNORE INTO acore_world.creature_template_movement (`CreatureId`, `Ground`, `Swim`, `Flight`, `Rooted`, `Chase`, `Random`, `InteractionPauseTimer`)
SELECT n.entry+@OFF, (n.InhabitType & 1), ((n.InhabitType >> 3) & 1), 1, 0, 0, 0, 0
FROM nelt_world.creature_template n
WHERE n.entry IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId IN (16,148,331,493,618) AND EXISTS (SELECT 1 FROM `_dc_nt_mask` m WHERE c.position_x > m.`xmin` AND c.position_x <= m.`xmax` AND c.position_y > m.`ymin` AND c.position_y <= m.`ymax`)))
  AND n.InhabitType IN (4,5,6,7);


-- --- gameobject templates  (adapted from 02_gameobject_templates.sql) ---
INSERT IGNORE INTO acore_world.gameobject_template (`entry`, `type`, `displayId`, `name`, `IconName`, `castBarCaption`, `unk1`, `size`, `Data0`, `Data1`, `Data2`, `Data3`, `Data4`, `Data5`, `Data6`, `Data7`, `Data8`, `Data9`, `Data10`, `Data11`, `Data12`, `Data13`, `Data14`, `Data15`, `Data16`, `Data17`, `Data18`, `Data19`, `Data20`, `Data21`, `Data22`, `Data23`, `AIName`, `ScriptName`, `VerifiedBuild`)
SELECT `entry`+@OFF, `type`, `displayId`, `name`, `IconName`, `castBarCaption`, `unk1`, `size`, `Data0`, `Data1`, `Data2`, `Data3`, `Data4`, `Data5`, `Data6`, `Data7`, `Data8`, `Data9`, `Data10`, `Data11`, `Data12`, `Data13`, `Data14`, `Data15`, `Data16`, `Data17`, `Data18`, `Data19`, `Data20`, `Data21`, `Data22`, `Data23`, `AIName`, `ScriptName`, `VerifiedBuild` FROM cata_world.gameobject_template WHERE entry IN (SELECT DISTINCT g.id FROM cata_world.gameobject g WHERE (g.map=1 AND g.zoneId IN (16,148,331,493,618) AND EXISTS (SELECT 1 FROM `_dc_nt_mask` m WHERE g.position_x > m.`xmin` AND g.position_x <= m.`xmax` AND g.position_y > m.`ymin` AND g.position_y <= m.`ymax`))) AND entry NOT IN (SELECT entry FROM acore_world.gameobject_template WHERE entry < @OFF);
INSERT IGNORE INTO acore_world.gameobject_template (`entry`, `type`, `displayId`, `name`, `IconName`, `castBarCaption`, `unk1`, `size`, `Data0`, `Data1`, `Data2`, `Data3`, `Data4`, `Data5`, `Data6`, `Data7`, `Data8`, `Data9`, `Data10`, `Data11`, `Data12`, `Data13`, `Data14`, `Data15`, `Data16`, `Data17`, `Data18`, `Data19`, `Data20`, `Data21`, `Data22`, `Data23`, `AIName`, `ScriptName`, `VerifiedBuild`)
SELECT `entry`+@OFF, `type`, `displayId`, `name`, `IconName`, `castBarCaption`, `unk1`, `size`, `Data0`, `Data1`, `Data2`, `Data3`, `Data4`, `Data5`, `Data6`, `Data7`, `Data8`, `Data9`, `Data10`, `Data11`, `Data12`, `Data13`, `Data14`, `Data15`, `Data16`, `Data17`, `Data18`, `Data19`, `Data20`, `Data21`, `Data22`, `Data23`, `AIName`, `ScriptName`, `VerifiedBuild` FROM acore_world.gameobject_template WHERE entry IN (SELECT DISTINCT g.id FROM cata_world.gameobject g WHERE (g.map=1 AND g.zoneId IN (16,148,331,493,618) AND EXISTS (SELECT 1 FROM `_dc_nt_mask` m WHERE g.position_x > m.`xmin` AND g.position_x <= m.`xmax` AND g.position_y > m.`ymin` AND g.position_y <= m.`ymax`))) AND entry < @OFF;
INSERT IGNORE INTO acore_world.gameobject_template_addon (`entry`, `faction`, `flags`, `mingold`, `maxgold`, `artkit0`, `artkit1`, `artkit2`, `artkit3`)
SELECT `entry`+@OFF, `faction`, `flags`, `mingold`, `maxgold`, `artkit0`, `artkit1`, `artkit2`, `artkit3` FROM cata_world.gameobject_template_addon WHERE entry IN (SELECT DISTINCT g.id FROM cata_world.gameobject g WHERE (g.map=1 AND g.zoneId IN (16,148,331,493,618) AND EXISTS (SELECT 1 FROM `_dc_nt_mask` m WHERE g.position_x > m.`xmin` AND g.position_x <= m.`xmax` AND g.position_y > m.`ymin` AND g.position_y <= m.`ymax`))) AND entry NOT IN (SELECT entry FROM acore_world.gameobject_template WHERE entry < @OFF);
INSERT IGNORE INTO acore_world.gameobject_template_addon (`entry`, `faction`, `flags`, `mingold`, `maxgold`, `artkit0`, `artkit1`, `artkit2`, `artkit3`)
SELECT `entry`+@OFF, `faction`, `flags`, `mingold`, `maxgold`, `artkit0`, `artkit1`, `artkit2`, `artkit3` FROM acore_world.gameobject_template_addon WHERE entry IN (SELECT DISTINCT g.id FROM cata_world.gameobject g WHERE (g.map=1 AND g.zoneId IN (16,148,331,493,618) AND EXISTS (SELECT 1 FROM `_dc_nt_mask` m WHERE g.position_x > m.`xmin` AND g.position_x <= m.`xmax` AND g.position_y > m.`ymin` AND g.position_y <= m.`ymax`))) AND entry IN (SELECT entry FROM acore_world.gameobject_template WHERE entry < @OFF) AND entry < @OFF;


-- --- spawns (zone tagged per source zone)  (adapted from 04_spawns.sql) ---
INSERT INTO acore_world.creature (`id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`)
SELECT c.`id`+@OFF, 750, CASE c.`zoneId` WHEN 16 THEN 4930 WHEN 148 THEN 4929 WHEN 331 THEN 4931 WHEN 493 THEN 4928 WHEN 618 THEN 4926 ELSE 0 END, CASE c.`zoneId` WHEN 16 THEN 4930 WHEN 148 THEN 4929 WHEN 331 THEN 4931 WHEN 493 THEN 4928 WHEN 618 THEN 4926 ELSE 0 END, c.`spawnMask`, c.`phaseMask`, c.`equipment_id`, c.`position_x`, c.`position_y`, c.`position_z`, c.`orientation`, c.`spawntimesecs`, c.`wander_distance`, c.`currentwaypoint`, COALESCE(c.`curhealth`,1), COALESCE(c.`curmana`,0), c.`MovementType`, COALESCE(c.`npcflag`,0), COALESCE(c.`unit_flags`,0)
FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId IN (16,148,331,493,618) AND EXISTS (SELECT 1 FROM `_dc_nt_mask` m WHERE c.position_x > m.`xmin` AND c.position_x <= m.`xmax` AND c.position_y > m.`ymin` AND c.position_y <= m.`ymax`));

INSERT INTO acore_world.gameobject (`id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `position_x`, `position_y`, `position_z`, `orientation`, `rotation0`, `rotation1`, `rotation2`, `rotation3`, `spawntimesecs`, `animprogress`, `state`)
SELECT g.`id`+@OFF, 750, CASE g.`zoneId` WHEN 16 THEN 4930 WHEN 148 THEN 4929 WHEN 331 THEN 4931 WHEN 493 THEN 4928 WHEN 618 THEN 4926 ELSE 0 END, CASE g.`zoneId` WHEN 16 THEN 4930 WHEN 148 THEN 4929 WHEN 331 THEN 4931 WHEN 493 THEN 4928 WHEN 618 THEN 4926 ELSE 0 END, g.`spawnMask`, g.`phaseMask`, g.`position_x`, g.`position_y`, g.`position_z`, g.`orientation`, g.`rotation0`, g.`rotation1`, g.`rotation2`, g.`rotation3`, g.`spawntimesecs`, g.`animprogress`, g.`state`
FROM cata_world.gameobject g WHERE (g.map=1 AND g.zoneId IN (16,148,331,493,618) AND EXISTS (SELECT 1 FROM `_dc_nt_mask` m WHERE g.position_x > m.`xmin` AND g.position_x <= m.`xmax` AND g.position_y > m.`ymin` AND g.position_y <= m.`ymax`));


-- --- creature text  (adapted from 07_creature_text.sql) ---
INSERT IGNORE INTO acore_world.creature_text (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`)
SELECT `CreatureID`+@OFF, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment` FROM cata_world.creature_text WHERE CreatureID IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId IN (16,148,331,493,618) AND EXISTS (SELECT 1 FROM `_dc_nt_mask` m WHERE c.position_x > m.`xmin` AND c.position_x <= m.`xmax` AND c.position_y > m.`ymin` AND c.position_y <= m.`ymax`))) AND CreatureID NOT IN (SELECT entry FROM acore_world.creature_template WHERE entry < @OFF);
INSERT IGNORE INTO acore_world.creature_text (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`)
SELECT `CreatureID`+@OFF, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment` FROM acore_world.creature_text WHERE CreatureID IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId IN (16,148,331,493,618) AND EXISTS (SELECT 1 FROM `_dc_nt_mask` m WHERE c.position_x > m.`xmin` AND c.position_x <= m.`xmax` AND c.position_y > m.`ymin` AND c.position_y <= m.`ymax`))) AND CreatureID IN (SELECT entry FROM acore_world.creature_template WHERE entry < @OFF) AND CreatureID < @OFF;


-- --- loot  (adapted from 08_loot.sql) ---
INSERT IGNORE INTO acore_world.creature_loot_template (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT lt.`Entry`, lt.`Item`, lt.`Reference`, lt.`Chance`, lt.`QuestRequired`, lt.`LootMode`, lt.`GroupId`, lt.`MinCount`, lt.`MaxCount`, lt.`Comment`
FROM (
  SELECT DISTINCT ct.lootid AS lootid
  FROM cata_world.creature_template ct
  JOIN cata_world.creature c ON c.id = ct.entry
  LEFT JOIN acore_world.creature_template ac ON ac.entry = ct.entry AND ac.entry < @OFF
  WHERE ct.lootid > 0 AND (c.map=1 AND c.zoneId IN (16,148,331,493,618) AND EXISTS (SELECT 1 FROM `_dc_nt_mask` m WHERE c.position_x > m.`xmin` AND c.position_x <= m.`xmax` AND c.position_y > m.`ymin` AND c.position_y <= m.`ymax`)) AND ac.entry IS NULL
) L
JOIN cata_world.creature_loot_template lt ON lt.Entry = L.lootid;


-- --- gossip  (adapted from 09_gossip.sql) ---
INSERT IGNORE INTO acore_world.gossip_menu (`MenuID`, `TextID`)
SELECT gm.MenuID, gm.TextID FROM cata_world.gossip_menu gm
JOIN (SELECT DISTINCT ct.gossip_menu_id AS mid
  FROM cata_world.creature_template ct
  JOIN cata_world.creature c ON c.id = ct.entry
  LEFT JOIN acore_world.creature_template ac ON ac.entry = ct.entry AND ac.entry < @OFF
  WHERE ct.gossip_menu_id > 0 AND (c.map=1 AND c.zoneId IN (16,148,331,493,618) AND EXISTS (SELECT 1 FROM `_dc_nt_mask` m WHERE c.position_x > m.`xmin` AND c.position_x <= m.`xmax` AND c.position_y > m.`ymin` AND c.position_y <= m.`ymax`)) AND ac.entry IS NULL) M ON M.mid = gm.MenuID;
INSERT IGNORE INTO acore_world.npc_text (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`, `text1_0`, `text1_1`, `BroadcastTextID1`, `lang1`, `Probability1`, `text2_0`, `text2_1`, `BroadcastTextID2`, `lang2`, `Probability2`, `text3_0`, `text3_1`, `BroadcastTextID3`, `lang3`, `Probability3`, `text4_0`, `text4_1`, `BroadcastTextID4`, `lang4`, `Probability4`, `text5_0`, `text5_1`, `BroadcastTextID5`, `lang5`, `Probability5`, `text6_0`, `text6_1`, `BroadcastTextID6`, `lang6`, `Probability6`, `text7_0`, `text7_1`, `BroadcastTextID7`, `lang7`, `Probability7`, `VerifiedBuild`)
SELECT nt.`ID`, nt.`text0_0`, nt.`text0_1`, nt.`BroadcastTextID0`, nt.`lang0`, nt.`Probability0`, nt.`text1_0`, nt.`text1_1`, nt.`BroadcastTextID1`, nt.`lang1`, nt.`Probability1`, nt.`text2_0`, nt.`text2_1`, nt.`BroadcastTextID2`, nt.`lang2`, nt.`Probability2`, nt.`text3_0`, nt.`text3_1`, nt.`BroadcastTextID3`, nt.`lang3`, nt.`Probability3`, nt.`text4_0`, nt.`text4_1`, nt.`BroadcastTextID4`, nt.`lang4`, nt.`Probability4`, nt.`text5_0`, nt.`text5_1`, nt.`BroadcastTextID5`, nt.`lang5`, nt.`Probability5`, nt.`text6_0`, nt.`text6_1`, nt.`BroadcastTextID6`, nt.`lang6`, nt.`Probability6`, nt.`text7_0`, nt.`text7_1`, nt.`BroadcastTextID7`, nt.`lang7`, nt.`Probability7`, nt.`VerifiedBuild` FROM cata_world.npc_text nt
JOIN (SELECT DISTINCT gm.TextID AS tid FROM cata_world.gossip_menu gm JOIN (SELECT DISTINCT ct.gossip_menu_id AS mid
  FROM cata_world.creature_template ct
  JOIN cata_world.creature c ON c.id = ct.entry
  LEFT JOIN acore_world.creature_template ac ON ac.entry = ct.entry AND ac.entry < @OFF
  WHERE ct.gossip_menu_id > 0 AND (c.map=1 AND c.zoneId IN (16,148,331,493,618) AND EXISTS (SELECT 1 FROM `_dc_nt_mask` m WHERE c.position_x > m.`xmin` AND c.position_x <= m.`xmax` AND c.position_y > m.`ymin` AND c.position_y <= m.`ymax`)) AND ac.entry IS NULL) M ON M.mid = gm.MenuID WHERE gm.TextID>0) T ON T.tid = nt.ID;
INSERT IGNORE INTO acore_world.gossip_menu_option (`MenuID`, `OptionID`, `OptionIcon`, `OptionText`, `OptionBroadcastTextID`, `OptionType`, `OptionNpcFlag`, `ActionMenuID`, `ActionPoiID`, `BoxCoded`, `BoxMoney`, `BoxText`, `BoxBroadcastTextID`, `VerifiedBuild`)
SELECT gmo.`MenuID`, gmo.`OptionID`, gmo.`OptionIcon`, gmo.`OptionText`, gmo.`OptionBroadcastTextID`, gmo.`OptionType`, gmo.`OptionNpcFlag`, gmo.`ActionMenuID`, gmo.`ActionPoiID`, gmo.`BoxCoded`, gmo.`BoxMoney`, gmo.`BoxText`, gmo.`BoxBroadcastTextID`, gmo.`VerifiedBuild` FROM cata_world.gossip_menu_option gmo
JOIN (SELECT DISTINCT ct.gossip_menu_id AS mid
  FROM cata_world.creature_template ct
  JOIN cata_world.creature c ON c.id = ct.entry
  LEFT JOIN acore_world.creature_template ac ON ac.entry = ct.entry AND ac.entry < @OFF
  WHERE ct.gossip_menu_id > 0 AND (c.map=1 AND c.zoneId IN (16,148,331,493,618) AND EXISTS (SELECT 1 FROM `_dc_nt_mask` m WHERE c.position_x > m.`xmin` AND c.position_x <= m.`xmax` AND c.position_y > m.`ymin` AND c.position_y <= m.`ymax`)) AND ac.entry IS NULL) M ON M.mid = gmo.MenuID;


-- --- SmartAI  (adapted from 12_smart_scripts.sql) ---
INSERT IGNORE INTO acore_world.smart_scripts (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`)
SELECT `entryorguid`+@OFF, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_x`, `target_y`, `target_z`, `target_o`, `comment` FROM cata_world.smart_scripts WHERE source_type=0 AND entryorguid>0 AND entryorguid IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId IN (16,148,331,493,618) AND EXISTS (SELECT 1 FROM `_dc_nt_mask` m WHERE c.position_x > m.`xmin` AND c.position_x <= m.`xmax` AND c.position_y > m.`ymin` AND c.position_y <= m.`ymax`))) AND entryorguid NOT IN (SELECT entry FROM acore_world.creature_template WHERE entry < @OFF);
INSERT IGNORE INTO acore_world.smart_scripts (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`)
SELECT `entryorguid`+@OFF, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_x`, `target_y`, `target_z`, `target_o`, `comment` FROM acore_world.smart_scripts WHERE source_type=0 AND entryorguid>0 AND entryorguid IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId IN (16,148,331,493,618) AND EXISTS (SELECT 1 FROM `_dc_nt_mask` m WHERE c.position_x > m.`xmin` AND c.position_x <= m.`xmax` AND c.position_y > m.`ymin` AND c.position_y <= m.`ymax`))) AND entryorguid IN (SELECT entry FROM acore_world.creature_template WHERE entry < @OFF) AND entryorguid < @OFF;


DROP TABLE IF EXISTS `_dc_nt_mask`;

-- Verify -- expect +6,323 creatures / +1,669 gameobjects on the new terrain:
--   SELECT COUNT(*) FROM `creature`   WHERE `map`=750 AND `zoneId` IN (4926,4928,4929,4930,4931);
--   SELECT COUNT(*) FROM `gameobject` WHERE `map`=750 AND `zoneId` IN (4926,4928,4929,4930,4931);
