-- 62_new_zone_templates.sql — map 751 Lordaeron extension, DB step 2.
--
-- Imports creature + gameobject TEMPLATES for the 7 new zones from cata_world
-- into private id bands.  Spawns are step 3 (63_), loot step 4 (64_).
--
--   creatures    entry + 4,100,000   (cata max 55,808  -> 4,100,000-4,155,808)
--   gameobjects  entry + 4,600,000   (cata max 210,112 -> 4,600,000-4,810,112)
--
-- The DELETE bands are deliberately TIGHT (4,100,000-4,199,999 and
-- 4,600,000-4,899,999), not the whole offset range. A wider creature band would
-- have swallowed **entry 4500002 "Teleporter" <DC-WoW>** — a live DC NPC with a
-- spawn and ScriptName dc_teleporter_creature_script. Re-check for squatters
-- before ever widening these bounds.
-- Existing map-751 content stays at +3,600,000 and is never touched by this file.
--
-- Written as cross-schema INSERT..SELECT rather than literal rows: no quoting or
-- escaping to get wrong, and it re-reads the source on every run.
-- Idempotent — each section DELETEs its own band before inserting.
--
-- Source scope: cata_world.creature/gameobject on map 0 in zones
--   85 Tirisfal, 1497 Undercity, 130 Silverpine, 267 Hillsbrad,
--   47 Hinterlands, 45 Arathi, 4706 Ruins of Gilneas
--
-- DELIBERATELY NOT SET HERE (each has its own follow-up file):
--   * gossip_menu_id -> 0. Cata menu ids do not exist in acore_world; a dangling
--     id is a load-time error. Gossip is imported separately.
--   * movementId -> 0 (acore creature_movement_info is a different id space).
--   * loot ids point at <new entry> so the `lootid == entry` invariant map 750
--     relies on holds from the start; 64_ creates the matching loot rows.
--   * ScriptName is copied VERBATIM on purpose — that is how the cloned NPCs
--     inherit the existing C++ (same trick as HyjalCata/166_border_zone_clone).

SET @COFF := 4100000;
SET @GOFF := 4600000;

-- ---------------------------------------------------------------------------
-- Source id sets (kept as real tables so later files and audits can reuse them)
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS `dc_map751_src_creature`;
CREATE TABLE `dc_map751_src_creature` (
  `id` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
INSERT INTO `dc_map751_src_creature` (`id`)
  SELECT DISTINCT c.`id` FROM `cata_world`.`creature` c
  WHERE c.`map` = 0 AND c.`zoneId` IN (85,1497,130,267,47,45,4706);

DROP TABLE IF EXISTS `dc_map751_src_gameobject`;
CREATE TABLE `dc_map751_src_gameobject` (
  `id` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
INSERT INTO `dc_map751_src_gameobject` (`id`)
  SELECT DISTINCT g.`id` FROM `cata_world`.`gameobject` g
  WHERE g.`map` = 0 AND g.`zoneId` IN (85,1497,130,267,47,45,4706);

-- ---------------------------------------------------------------------------
-- creature_template
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template` WHERE `entry` BETWEEN 4100000 AND 4199999;
INSERT INTO `creature_template`
  (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,
   `KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,
   `minlevel`,`maxlevel`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`rank`,
   `dmgschool`,`DamageModifier`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,
   `RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`family`,`type`,
   `type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,
   `mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,
   `ManaModifier`,`ArmorModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,
   `RegenHealth`,`flags_extra`,`ScriptName`,`VerifiedBuild`)
SELECT
  t.`entry` + @COFF,
  -- difficulty/killcredit ids only survive if that creature is in this import too,
  -- otherwise they would dangle into an id we never created
  IF(t.`difficulty_entry_1` > 0 AND d1.`id` IS NOT NULL, t.`difficulty_entry_1` + @COFF, 0),
  IF(t.`difficulty_entry_2` > 0 AND d2.`id` IS NOT NULL, t.`difficulty_entry_2` + @COFF, 0),
  IF(t.`difficulty_entry_3` > 0 AND d3.`id` IS NOT NULL, t.`difficulty_entry_3` + @COFF, 0),
  IF(t.`KillCredit1` > 0 AND k1.`id` IS NOT NULL, t.`KillCredit1` + @COFF, 0),
  IF(t.`KillCredit2` > 0 AND k2.`id` IS NOT NULL, t.`KillCredit2` + @COFF, 0),
  t.`name`, t.`subname`, t.`IconName`,
  0,                                            -- gossip_menu_id, see header
  t.`minlevel`, t.`maxlevel`, t.`faction`, t.`npcflag`,
  t.`speed_walk`, t.`speed_run`, t.`rank`, t.`dmgschool`, t.`DamageModifier`,
  t.`BaseAttackTime`, t.`RangeAttackTime`, t.`BaseVariance`, t.`RangeVariance`,
  t.`unit_class`, t.`unit_flags`, t.`unit_flags2`, t.`family`, t.`type`,
  t.`type_flags`,
  IF(t.`lootid` > 0,         t.`entry` + @COFF, 0),
  IF(t.`pickpocketloot` > 0, t.`entry` + @COFF, 0),
  IF(t.`skinloot` > 0,       t.`entry` + @COFF, 0),
  t.`PetSpellDataId`, t.`VehicleId`, t.`mingold`, t.`maxgold`,
  t.`AIName`, t.`MovementType`, t.`HoverHeight`, t.`HealthModifier`,
  t.`ManaModifier`, t.`ArmorModifier`, t.`ExperienceModifier`, t.`RacialLeader`,
  0,                                            -- movementId, see header
  t.`RegenHealth`, t.`flags_extra`, t.`ScriptName`, t.`VerifiedBuild`
FROM `cata_world`.`creature_template` t
JOIN `dc_map751_src_creature` s  ON s.`id`  = t.`entry`
LEFT JOIN `dc_map751_src_creature` d1 ON d1.`id` = t.`difficulty_entry_1`
LEFT JOIN `dc_map751_src_creature` d2 ON d2.`id` = t.`difficulty_entry_2`
LEFT JOIN `dc_map751_src_creature` d3 ON d3.`id` = t.`difficulty_entry_3`
LEFT JOIN `dc_map751_src_creature` k1 ON k1.`id` = t.`KillCredit1`
LEFT JOIN `dc_map751_src_creature` k2 ON k2.`id` = t.`KillCredit2`;

-- ---------------------------------------------------------------------------
-- Side tables. Modern AzerothCore keeps models / resistances / spells OUT of
-- creature_template; cata_world still has modelid1-4, resistance1-6, spell1-8.
-- Missing creature_template_model rows = invisible NPCs, so this is not optional.
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template_model`      WHERE `CreatureID` BETWEEN 4100000 AND 4199999;
INSERT INTO `creature_template_model` (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT x.`CreatureID`, x.`Idx`, x.`CreatureDisplayID`, x.`DisplayScale`, 1, 0 FROM (
  SELECT t.`entry` + @COFF AS `CreatureID`, 0 AS `Idx`, t.`modelid1` AS `CreatureDisplayID`, IFNULL(t.`scale`,1) AS `DisplayScale`
    FROM `cata_world`.`creature_template` t JOIN `dc_map751_src_creature` s ON s.`id`=t.`entry` WHERE t.`modelid1` > 0
  UNION ALL
  SELECT t.`entry` + @COFF, 1, t.`modelid2`, IFNULL(t.`scale`,1)
    FROM `cata_world`.`creature_template` t JOIN `dc_map751_src_creature` s ON s.`id`=t.`entry` WHERE t.`modelid2` > 0
  UNION ALL
  SELECT t.`entry` + @COFF, 2, t.`modelid3`, IFNULL(t.`scale`,1)
    FROM `cata_world`.`creature_template` t JOIN `dc_map751_src_creature` s ON s.`id`=t.`entry` WHERE t.`modelid3` > 0
  UNION ALL
  SELECT t.`entry` + @COFF, 3, t.`modelid4`, IFNULL(t.`scale`,1)
    FROM `cata_world`.`creature_template` t JOIN `dc_map751_src_creature` s ON s.`id`=t.`entry` WHERE t.`modelid4` > 0
) x;

DELETE FROM `creature_template_resistance` WHERE `CreatureID` BETWEEN 4100000 AND 4199999;
INSERT INTO `creature_template_resistance` (`CreatureID`,`School`,`Resistance`,`VerifiedBuild`)
SELECT y.`CreatureID`, y.`School`, y.`Resistance`, 0 FROM (
  SELECT t.`entry` + @COFF AS `CreatureID`, 1 AS `School`, t.`resistance1` AS `Resistance` FROM `cata_world`.`creature_template` t JOIN `dc_map751_src_creature` s ON s.`id`=t.`entry` WHERE t.`resistance1` <> 0
  UNION ALL SELECT t.`entry` + @COFF, 2, t.`resistance2` FROM `cata_world`.`creature_template` t JOIN `dc_map751_src_creature` s ON s.`id`=t.`entry` WHERE t.`resistance2` <> 0
  UNION ALL SELECT t.`entry` + @COFF, 3, t.`resistance3` FROM `cata_world`.`creature_template` t JOIN `dc_map751_src_creature` s ON s.`id`=t.`entry` WHERE t.`resistance3` <> 0
  UNION ALL SELECT t.`entry` + @COFF, 4, t.`resistance4` FROM `cata_world`.`creature_template` t JOIN `dc_map751_src_creature` s ON s.`id`=t.`entry` WHERE t.`resistance4` <> 0
  UNION ALL SELECT t.`entry` + @COFF, 5, t.`resistance5` FROM `cata_world`.`creature_template` t JOIN `dc_map751_src_creature` s ON s.`id`=t.`entry` WHERE t.`resistance5` <> 0
  UNION ALL SELECT t.`entry` + @COFF, 6, t.`resistance6` FROM `cata_world`.`creature_template` t JOIN `dc_map751_src_creature` s ON s.`id`=t.`entry` WHERE t.`resistance6` <> 0
) y;

DELETE FROM `creature_template_spell`      WHERE `CreatureID` BETWEEN 4100000 AND 4199999;
INSERT INTO `creature_template_spell` (`CreatureID`,`Index`,`Spell`,`VerifiedBuild`)
SELECT z.`CreatureID`, z.`Index`, z.`Spell`, 0 FROM (
  SELECT t.`entry` + @COFF AS `CreatureID`, 0 AS `Index`, t.`spell1` AS `Spell` FROM `cata_world`.`creature_template` t JOIN `dc_map751_src_creature` s ON s.`id`=t.`entry` WHERE t.`spell1` > 0
  UNION ALL SELECT t.`entry` + @COFF, 1, t.`spell2` FROM `cata_world`.`creature_template` t JOIN `dc_map751_src_creature` s ON s.`id`=t.`entry` WHERE t.`spell2` > 0
  UNION ALL SELECT t.`entry` + @COFF, 2, t.`spell3` FROM `cata_world`.`creature_template` t JOIN `dc_map751_src_creature` s ON s.`id`=t.`entry` WHERE t.`spell3` > 0
  UNION ALL SELECT t.`entry` + @COFF, 3, t.`spell4` FROM `cata_world`.`creature_template` t JOIN `dc_map751_src_creature` s ON s.`id`=t.`entry` WHERE t.`spell4` > 0
  UNION ALL SELECT t.`entry` + @COFF, 4, t.`spell5` FROM `cata_world`.`creature_template` t JOIN `dc_map751_src_creature` s ON s.`id`=t.`entry` WHERE t.`spell5` > 0
  UNION ALL SELECT t.`entry` + @COFF, 5, t.`spell6` FROM `cata_world`.`creature_template` t JOIN `dc_map751_src_creature` s ON s.`id`=t.`entry` WHERE t.`spell6` > 0
  UNION ALL SELECT t.`entry` + @COFF, 6, t.`spell7` FROM `cata_world`.`creature_template` t JOIN `dc_map751_src_creature` s ON s.`id`=t.`entry` WHERE t.`spell7` > 0
  UNION ALL SELECT t.`entry` + @COFF, 7, t.`spell8` FROM `cata_world`.`creature_template` t JOIN `dc_map751_src_creature` s ON s.`id`=t.`entry` WHERE t.`spell8` > 0
) z;

-- cata_world keeps the UNIT_FIELD_BYTES_1/2 components in separate columns
-- (StandState, AnimTier, VisFlags, SheathState, PvPFlags); AzerothCore wants them
-- packed into two ints. Packing verified against the code that consumes them,
-- Creature.cpp:2763-2797:
--   bytes1 = StandState | (VisFlags << 16) | (AnimTier << 24)   (byte 1 forced 0)
--   bytes2 = SheathState | (PvPFlags << 8)                      (bytes 2,3 forced 0)
-- path_id stays 0 on purpose: a non-zero path with no waypoint_data rows makes the
-- creature fail to load. Waypoints are imported later, and set it then.
DELETE FROM `creature_template_addon` WHERE `entry` BETWEEN 4100000 AND 4199999;
INSERT INTO `creature_template_addon` (`entry`,`path_id`,`mount`,`bytes1`,`bytes2`,`emote`,`visibilityDistanceType`,`auras`)
SELECT
  a.`entry` + @COFF,
  0,
  a.`mount`,
  a.`StandState`   + a.`VisFlags`  * 65536 + a.`AnimTier` * 16777216,
  a.`SheathState`  + a.`PvPFlags`  * 256,
  a.`emote`,
  a.`visibilityDistanceType`,
  a.`auras`
FROM `cata_world`.`creature_template_addon` a
JOIN `dc_map751_src_creature` s ON s.`id` = a.`entry`;

-- ---------------------------------------------------------------------------
-- gameobject_template
-- Data fields carry ids. The linked-trap slot differs PER TYPE
-- (BUTTON=Data3, CHEST=Data7, SPELL_FOCUS=Data2, GOOBER=Data12) and CHEST also
-- keeps its loot id in Data1 — remapped here so nothing points at a raw cata id.
-- ---------------------------------------------------------------------------
DELETE FROM `gameobject_template` WHERE `entry` BETWEEN 4600000 AND 4899999;
INSERT INTO `gameobject_template`
  (`entry`,`type`,`displayId`,`name`,`IconName`,`castBarCaption`,`unk1`,`size`,
   `Data0`,`Data1`,`Data2`,`Data3`,`Data4`,`Data5`,`Data6`,`Data7`,`Data8`,`Data9`,
   `Data10`,`Data11`,`Data12`,`Data13`,`Data14`,`Data15`,`Data16`,`Data17`,`Data18`,
   `Data19`,`Data20`,`Data21`,`Data22`,`Data23`,`AIName`,`ScriptName`,`VerifiedBuild`)
SELECT
  t.`entry` + @GOFF, t.`type`, t.`displayId`, t.`name`, t.`IconName`,
  t.`castBarCaption`, t.`unk1`, t.`size`,
  t.`Data0`,
  IF(t.`type` = 3 AND t.`Data1` > 0, t.`entry` + @GOFF, t.`Data1`),   -- CHEST loot id
  IF(t.`type` = 8 AND t.`Data2` > 0 AND f2.`id` IS NOT NULL, t.`Data2` + @GOFF, t.`Data2`),
  IF(t.`type` = 1 AND t.`Data3` > 0 AND f3.`id` IS NOT NULL, t.`Data3` + @GOFF, t.`Data3`),
  t.`Data4`, t.`Data5`, t.`Data6`,
  IF(t.`type` = 3 AND t.`Data7` > 0 AND f7.`id` IS NOT NULL, t.`Data7` + @GOFF, t.`Data7`),
  t.`Data8`, t.`Data9`, t.`Data10`, t.`Data11`,
  IF(t.`type` = 10 AND t.`Data12` > 0 AND f12.`id` IS NOT NULL, t.`Data12` + @GOFF, t.`Data12`),
  t.`Data13`, t.`Data14`, t.`Data15`, t.`Data16`, t.`Data17`, t.`Data18`,
  t.`Data19`, t.`Data20`, t.`Data21`, t.`Data22`, t.`Data23`,
  t.`AIName`, t.`ScriptName`, t.`VerifiedBuild`
FROM `cata_world`.`gameobject_template` t
JOIN `dc_map751_src_gameobject` s ON s.`id` = t.`entry`
LEFT JOIN `dc_map751_src_gameobject` f2  ON f2.`id`  = t.`Data2`
LEFT JOIN `dc_map751_src_gameobject` f3  ON f3.`id`  = t.`Data3`
LEFT JOIN `dc_map751_src_gameobject` f7  ON f7.`id`  = t.`Data7`
LEFT JOIN `dc_map751_src_gameobject` f12 ON f12.`id` = t.`Data12`;

-- ---------------------------------------------------------------------------
-- Verification. Every one of these should return zero rows / sane counts.
-- ---------------------------------------------------------------------------
SELECT 'creature_template'            AS what, COUNT(*) AS n FROM `creature_template`            WHERE `entry`      BETWEEN 4100000 AND 4199999
UNION ALL SELECT 'creature_template_model',      COUNT(*) FROM `creature_template_model`      WHERE `CreatureID` BETWEEN 4100000 AND 4199999
UNION ALL SELECT 'creature_template_resistance', COUNT(*) FROM `creature_template_resistance` WHERE `CreatureID` BETWEEN 4100000 AND 4199999
UNION ALL SELECT 'creature_template_spell',      COUNT(*) FROM `creature_template_spell`      WHERE `CreatureID` BETWEEN 4100000 AND 4199999
UNION ALL SELECT 'creature_template_addon',      COUNT(*) FROM `creature_template_addon`      WHERE `entry`      BETWEEN 4100000 AND 4199999
UNION ALL SELECT 'gameobject_template',          COUNT(*) FROM `gameobject_template`          WHERE `entry`      BETWEEN 4600000 AND 4899999;

-- imported creatures with no model row at all = invisible in game
SELECT 'creatures with NO model row' AS problem, COUNT(*) AS n
FROM `creature_template` t
LEFT JOIN `creature_template_model` m ON m.`CreatureID` = t.`entry`
WHERE t.`entry` BETWEEN 4100000 AND 4199999 AND m.`CreatureID` IS NULL;

-- any GO Data slot still pointing at a raw (un-offset) cata id we also imported
SELECT 'GO linked id left un-offset' AS problem, t.`entry`, t.`type`,
       CASE t.`type` WHEN 1 THEN t.`Data3` WHEN 3 THEN t.`Data7`
                     WHEN 8 THEN t.`Data2` WHEN 10 THEN t.`Data12` END AS linked
FROM `gameobject_template` t
WHERE t.`entry` BETWEEN 4600000 AND 4899999 AND t.`type` IN (1,3,8,10)
HAVING linked > 0 AND linked < 4600000
   AND linked IN (SELECT `id` FROM `dc_map751_src_gameobject`);

-- VehicleId values that must exist in Vehicle.dbc or the creature fails to load
SELECT 'distinct VehicleIds to validate against Vehicle.dbc' AS note,
       GROUP_CONCAT(DISTINCT `VehicleId` ORDER BY `VehicleId`) AS ids
FROM `creature_template`
WHERE `entry` BETWEEN 4100000 AND 4199999 AND `VehicleId` > 0;

-- Aura spells on the imported addons. Any id that exists in neither Spell.dbc nor
-- the spell_dbc override table is stripped at load with a warning; the Cata-only
-- ones need downporting the same way Plaguelands/53_ did for the first import.
-- 128 of the 1,127 addon rows carry auras.
SELECT 'addon aura spell ids (validate against Spell.dbc + spell_dbc)' AS note,
       COUNT(*) AS rows_with_auras
FROM `creature_template_addon`
WHERE `entry` BETWEEN 4100000 AND 4199999 AND `auras` <> '';

-- 11 source rows carried a waypointPathId that this file deliberately dropped to 0.
-- Re-apply them together with the waypoint_data import, never before it.
SELECT 'source rows whose waypointPathId was dropped' AS note, COUNT(*) AS n
FROM `cata_world`.`creature_template_addon` a
JOIN `dc_map751_src_creature` s ON s.`id` = a.`entry`
WHERE a.`waypointPathId` > 0;
