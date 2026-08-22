-- 107_addon_animation_layer_751.sql -- the "aliveness" layer for map 751, DB step 46.
--
-- THE SYMPTOM
--   "the forsaken front area looks very silent/static somehow, but lots of npcs --
--    have all scripts etc been ported for that area?"
--
-- THE SCRIPTS ARE FINE. THIS IS NOT A SCRIPT GAP -- measured for Silverpine (zone 4935)
-- against cata_world, entry for entry:
--
--     AIName = 'SmartAI'    ours 50   source 50
--     smart_scripts rows    ours 50   source 50
--     creature_text         ours 12   source 12
--     C++ ScriptName        ours  3   source  3
--     SmartAI rows with a dead AIName                       0
--
--   Nothing was skipped. What is missing is the layer UNDER the scripts.
--
-- WHAT IS ACTUALLY MISSING -- the creature_addon animation layer, which is EMPTY for
-- the whole +4,100,000 extension band:
--
--     Silverpine, ours   emote 0    auras 0
--     Silverpine, nelt   emote 25   auras 222
--
--   `creature_addon.emote` and `bytes1` are what make a camp look inhabited: the
--   kneeling, the working, the sitting, the combat stance, the weapon drawn. With both
--   zero every NPC stands in the default idle pose, which reads exactly as "lots of
--   NPCs, nothing happening". Same defect family as 101_ / 103_ / 105_: the base table
--   was cloned onto the band and the side table was left behind. The older +3,600,000
--   band DID get it (92 emotes / 79 bytes1 / 542 auras live on map 751 today, all of
--   them in that band), which is why only the new zones feel dead.
--
--   Recoverable from nelt at entry level: 50 entries with an emote, 40 with a bytes1
--   pose, 72 with auras -- covering 1,207 of our spawns.
--
-- AURAS ARE FILTERED, AND THIS IS THE TRAP IN THIS FILE.
--   Importing the aura column blind HIDES NPCs. Checked against spell_dbc rather than
--   assumed, and the risk is real in this exact data set:
--
--     29266 / 84386  Permanent Feign Death        8 entries -- NPC lies down as a corpse
--     49414 / 49415  Generic Quest Invisibility   8 entries -- invisible outside its phase
--     80636          Feigned                      1 entry
--     89702          Camouflage                   1 entry
--
--   Those are excluded. NOT excluded, despite matching a naive name filter:
--     18950  "Invisibility and Stealth Detection" -- this one DETECTS stealth, it does
--            not hide the caster. Dropping it would break stealth-detecting guards.
--   Everything else is cosmetic or combat flavour (Frost Armor, Shadowform, poisons,
--   Retribution Aura, the fire/visual effects) and is imported.
--
-- path_id IS NEVER TOUCHED. 2,935 map-751 spawns already have a creature_addon row, and
-- for most of them the ONLY thing in it is `path_id` -- the waypoint link. This file
-- UPDATEs those rows on the animation columns only and INSERTs rows just for spawns that
-- have none, so no patrol route is clobbered.
--
-- ENTRY-LEVEL, NOT GUID-LEVEL. Our spawn guids have no correspondence to nelt's, so the
-- value is taken per ENTRY: the most common non-zero value across that entry's nelt
-- spawns, ties broken by the lower value so the result is deterministic and re-runnable.
-- That is the same approach 102_ used for wander distance, and it is right for this data
-- because an emote/pose is a property of what the NPC IS, not of where it stands.
--
-- ONLY FILLS GAPS. Every write is conditional on our column currently being empty, so
-- anything already set by hand survives.

-- ---------------------------------------------------------------------------
-- 1. Dominant animation values per entry, from nelt
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS `_dc_addon_751`;

CREATE TABLE `_dc_addon_751` (
  `entry` INT UNSIGNED NOT NULL,
  `emote` INT UNSIGNED NOT NULL DEFAULT 0,
  `bytes1` INT UNSIGNED NOT NULL DEFAULT 0,
  `bytes2` INT UNSIGNED NOT NULL DEFAULT 0,
  `mount` INT UNSIGNED NOT NULL DEFAULT 0,
  `auras` TEXT NULL,
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- One row per map-751 entry in the extension band, then one plain UPDATE per column.
-- Deliberately five simple statements rather than one clever pivot: each is readable on
-- its own and each can be checked independently.
INSERT INTO `_dc_addon_751` (`entry`)
SELECT DISTINCT `id` FROM `creature` WHERE `map` = 751 AND `id` >= 4100000;

UPDATE `_dc_addon_751` a JOIN (
  SELECT `base`, `val` FROM (
    SELECT nc.`id` AS `base`, na.`emote` AS `val`,
           ROW_NUMBER() OVER (PARTITION BY nc.`id` ORDER BY COUNT(*) DESC, na.`emote`) AS rn
    FROM `nelt_world`.`creature` nc
    JOIN `nelt_world`.`creature_addon` na ON na.`guid` = nc.`guid`
    WHERE na.`emote` <> 0 GROUP BY nc.`id`, na.`emote`
  ) r WHERE r.`rn` = 1
) d ON d.`base` = CAST(a.`entry` AS SIGNED) - 4100000
SET a.`emote` = d.`val`;

UPDATE `_dc_addon_751` a JOIN (
  SELECT `base`, `val` FROM (
    SELECT nc.`id` AS `base`, na.`bytes1` AS `val`,
           ROW_NUMBER() OVER (PARTITION BY nc.`id` ORDER BY COUNT(*) DESC, na.`bytes1`) AS rn
    FROM `nelt_world`.`creature` nc
    JOIN `nelt_world`.`creature_addon` na ON na.`guid` = nc.`guid`
    WHERE na.`bytes1` <> 0 GROUP BY nc.`id`, na.`bytes1`
  ) r WHERE r.`rn` = 1
) d ON d.`base` = CAST(a.`entry` AS SIGNED) - 4100000
SET a.`bytes1` = d.`val`;

UPDATE `_dc_addon_751` a JOIN (
  SELECT `base`, `val` FROM (
    SELECT nc.`id` AS `base`, na.`bytes2` AS `val`,
           ROW_NUMBER() OVER (PARTITION BY nc.`id` ORDER BY COUNT(*) DESC, na.`bytes2`) AS rn
    FROM `nelt_world`.`creature` nc
    JOIN `nelt_world`.`creature_addon` na ON na.`guid` = nc.`guid`
    WHERE na.`bytes2` <> 0 GROUP BY nc.`id`, na.`bytes2`
  ) r WHERE r.`rn` = 1
) d ON d.`base` = CAST(a.`entry` AS SIGNED) - 4100000
SET a.`bytes2` = d.`val`;

UPDATE `_dc_addon_751` a JOIN (
  SELECT `base`, `val` FROM (
    SELECT nc.`id` AS `base`, na.`mount` AS `val`,
           ROW_NUMBER() OVER (PARTITION BY nc.`id` ORDER BY COUNT(*) DESC, na.`mount`) AS rn
    FROM `nelt_world`.`creature` nc
    JOIN `nelt_world`.`creature_addon` na ON na.`guid` = nc.`guid`
    WHERE na.`mount` <> 0 GROUP BY nc.`id`, na.`mount`
  ) r WHERE r.`rn` = 1
) d ON d.`base` = CAST(a.`entry` AS SIGNED) - 4100000
SET a.`mount` = d.`val`;

UPDATE `_dc_addon_751` a JOIN (
  SELECT `base`, `aur` FROM (
    SELECT nc.`id` AS `base`, na.`auras` AS `aur`,
           ROW_NUMBER() OVER (PARTITION BY nc.`id` ORDER BY COUNT(*) DESC, na.`auras`) AS rn
    FROM `nelt_world`.`creature` nc
    JOIN `nelt_world`.`creature_addon` na ON na.`guid` = nc.`guid`
    WHERE na.`auras` IS NOT NULL AND na.`auras` <> '' GROUP BY nc.`id`, na.`auras`
  ) r WHERE r.`rn` = 1
) d ON d.`base` = CAST(a.`entry` AS SIGNED) - 4100000
SET a.`auras` = d.`aur`;

-- drop the entries that turned out to have nothing to give
DELETE FROM `_dc_addon_751`
WHERE `emote` = 0 AND `bytes1` = 0 AND `bytes2` = 0 AND `mount` = 0
  AND (`auras` IS NULL OR `auras` = '');

-- ---------------------------------------------------------------------------
-- 2. Strip the auras that would hide the NPC
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS `_dc_addon_hiders`;
CREATE TABLE `_dc_addon_hiders` (
  `spell` INT UNSIGNED NOT NULL,
  `why` VARCHAR(64) NOT NULL DEFAULT '',
  PRIMARY KEY (`spell`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `_dc_addon_hiders` (`spell`, `why`) VALUES
(29266, 'Permanent Feign Death'),
(84386, 'Permanent Feign Death'),
(49414, 'Generic Quest Invisibility 1'),
(49415, 'Generic Quest Invisibility 2'),
(80636, 'Feigned'),
(89702, 'Camouflage'),
-- ---------------------------------------------------------------------------
-- Cata auras this core has no spell for. The first run of this file did NOT have
-- these and produced ~250 "has wrong spell ... in `auras`" errors at boot, cleaned
-- up by 108_. They are listed here so a RE-RUN cannot reintroduce them.
--
-- THE ORACLE IS THE BINARY Spell.dbc, NOT the `spell_dbc` table. That table is a
-- sparse overlay: checking against it reports 22 missing ids, 11 of which
-- (5301, 12782, 13730, 13886, 16245, 18847, 26000, 32783, 38232, 42648, 61573)
-- are real spells present in the DBC and working. Only these 11 are genuinely
-- absent, and they match the server log exactly.
--
-- If any of these get downported later (88_ / spell-dbc-append.py), delete its row
-- here and re-run this file to restore the aura from nelt.
-- ---------------------------------------------------------------------------
(64086,  'not in Spell.dbc -- Romo''s Half-Size Bunny'),
(78677,  'not in Spell.dbc -- Stormpike Trainee'),
(80365,  'not in Spell.dbc -- Worgen Renegade'),
(80681,  'not in Spell.dbc -- SI:7 Operative'),
(87972,  'not in Spell.dbc -- Hillsbrad Foreman/Miner/Sentry'),
(87973,  'not in Spell.dbc -- Hillsbrad Foreman/Miner/Sentry'),
(88964,  'not in Spell.dbc -- Generic Bunny - PRK'),
(89281,  'not in Spell.dbc -- Foothill Stalker'),
(90080,  'not in Spell.dbc -- Mudsnout Gnoll/Shaman'),
(91154,  'not in Spell.dbc -- Stormpike Soldier'),
(102371, 'not in Spell.dbc -- Fahrad');

-- RUN FOUR TIMES, ON PURPOSE. `UPDATE ... JOIN` applies ONE matched join row per target
-- row, so a single pass strips only ONE bad spell from an aura string that holds several.
-- 56 spawns carry BOTH 87972 and 87973, so one pass would silently leave half the job
-- done. Four passes clear the longest string in this data with room to spare, and the
-- statement is idempotent -- a pass with nothing left to strip matches nothing.
UPDATE `_dc_addon_751` a JOIN `_dc_addon_hiders` h
  ON FIND_IN_SET(h.`spell`, REPLACE(a.`auras`, ' ', ','))
SET a.`auras` = NULLIF(TRIM(REPLACE(REPLACE(REPLACE(
      CONCAT(' ', REPLACE(a.`auras`, ' ', '  '), ' '), CONCAT(' ', h.`spell`, ' '), ' ')
      , '  ', ' '), '  ', ' ')), '');

UPDATE `_dc_addon_751` a JOIN `_dc_addon_hiders` h
  ON FIND_IN_SET(h.`spell`, REPLACE(a.`auras`, ' ', ','))
SET a.`auras` = NULLIF(TRIM(REPLACE(REPLACE(REPLACE(
      CONCAT(' ', REPLACE(a.`auras`, ' ', '  '), ' '), CONCAT(' ', h.`spell`, ' '), ' ')
      , '  ', ' '), '  ', ' ')), '');

UPDATE `_dc_addon_751` a JOIN `_dc_addon_hiders` h
  ON FIND_IN_SET(h.`spell`, REPLACE(a.`auras`, ' ', ','))
SET a.`auras` = NULLIF(TRIM(REPLACE(REPLACE(REPLACE(
      CONCAT(' ', REPLACE(a.`auras`, ' ', '  '), ' '), CONCAT(' ', h.`spell`, ' '), ' ')
      , '  ', ' '), '  ', ' ')), '');

UPDATE `_dc_addon_751` a JOIN `_dc_addon_hiders` h
  ON FIND_IN_SET(h.`spell`, REPLACE(a.`auras`, ' ', ','))
SET a.`auras` = NULLIF(TRIM(REPLACE(REPLACE(REPLACE(
      CONCAT(' ', REPLACE(a.`auras`, ' ', '  '), ' '), CONCAT(' ', h.`spell`, ' '), ' ')
      , '  ', ' '), '  ', ' ')), '');

-- ---------------------------------------------------------------------------
-- 3. Fill gaps on spawns that ALREADY have a row -- path_id is never touched
-- ---------------------------------------------------------------------------
UPDATE `creature_addon` ca
JOIN `creature` c ON c.`guid` = ca.`guid`
JOIN `_dc_addon_751` a ON a.`entry` = c.`id`
SET ca.`emote`  = CASE WHEN ca.`emote`  = 0 THEN a.`emote`  ELSE ca.`emote`  END,
    ca.`bytes1` = CASE WHEN ca.`bytes1` = 0 THEN a.`bytes1` ELSE ca.`bytes1` END,
    ca.`bytes2` = CASE WHEN ca.`bytes2` = 0 THEN a.`bytes2` ELSE ca.`bytes2` END,
    ca.`mount`  = CASE WHEN ca.`mount`  = 0 THEN a.`mount`  ELSE ca.`mount`  END,
    ca.`auras`  = CASE WHEN ca.`auras` IS NULL OR ca.`auras` = '' THEN a.`auras` ELSE ca.`auras` END
WHERE c.`map` = 751;

-- ---------------------------------------------------------------------------
-- 4. Create rows for spawns that have none
-- ---------------------------------------------------------------------------
INSERT INTO `creature_addon` (`guid`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `auras`)
SELECT c.`guid`, 0, a.`mount`, a.`bytes1`, a.`bytes2`, a.`emote`, a.`auras`
FROM `creature` c
JOIN `_dc_addon_751` a ON a.`entry` = c.`id`
LEFT JOIN `creature_addon` ca ON ca.`guid` = c.`guid`
WHERE c.`map` = 751 AND ca.`guid` IS NULL
  AND (a.`emote` <> 0 OR a.`bytes1` <> 0 OR a.`bytes2` <> 0 OR a.`mount` <> 0
       OR (a.`auras` IS NOT NULL AND a.`auras` <> ''));

-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------
SELECT 'entries with recovered animation data' AS what, COUNT(*) AS n FROM `_dc_addon_751`
UNION ALL SELECT '  ...with an emote', COUNT(*) FROM `_dc_addon_751` WHERE `emote` <> 0
UNION ALL SELECT '  ...with a bytes1 pose', COUNT(*) FROM `_dc_addon_751` WHERE `bytes1` <> 0
UNION ALL SELECT '  ...with auras left after the hider strip', COUNT(*)
  FROM `_dc_addon_751` WHERE `auras` IS NOT NULL AND `auras` <> ''
UNION ALL SELECT 'HIDER auras that survived the strip (must be 0)', COUNT(*)
  FROM `_dc_addon_751` a JOIN `_dc_addon_hiders` h
    ON FIND_IN_SET(h.`spell`, REPLACE(a.`auras`, ' ', ','))
UNION ALL SELECT 'map-751 spawns with an emote now', COUNT(*)
  FROM `creature` c JOIN `creature_addon` ca ON ca.`guid` = c.`guid`
  WHERE c.`map` = 751 AND ca.`emote` <> 0
UNION ALL SELECT 'Silverpine spawns with an emote now (was 0)', COUNT(*)
  FROM `creature` c JOIN `creature_addon` ca ON ca.`guid` = c.`guid`
  WHERE c.`map` = 751 AND c.`zoneId` = 4935 AND ca.`emote` <> 0
UNION ALL SELECT 'waypoint links still intact (path_id > 0)', COUNT(*)
  FROM `creature` c JOIN `creature_addon` ca ON ca.`guid` = c.`guid`
  WHERE c.`map` = 751 AND ca.`path_id` > 0;

DROP TABLE `_dc_addon_751`;
DROP TABLE `_dc_addon_hiders`;
