-- 108_addon_aura_spell_validation.sql -- strip auras the server cannot resolve, DB step 47.
--
-- THE SYMPTOM, straight after applying 107_:
--   Loading Creature Addon Data...
--   Creature (GUID: ...) has wrong spell '87972' defined in `auras` field in `creature_addon`.
--   ...roughly 250 lines of it at boot.
--
-- MY MISS IN 107_. That file filtered auras for spells that would HIDE the NPC, but never
-- checked the spells EXIST. Worse, the audit that informed it used an inner
-- `JOIN spell_dbc`, which silently listed only the auras that were present and hid every
-- one that was not -- so the gap was invisible in exactly the query meant to find it.
--
-- `spell_dbc` IS NOT THE SPELL STORE. It is a sparse DB overlay. The authority is the
-- binary Spell.dbc (54,027 rows). Validating against the table reports 22 missing aura
-- spells; validating against the DBC reports 11 -- and the 11 match the server log
-- exactly. The other 11 (5301, 12782, 13730, 13886, 16245, 18847, 26000, 32783, 38232,
-- 42648, 61573) are real spells that simply are not mirrored into the overlay, and
-- stripping them would have destroyed working data. Use the DBC as the oracle.
--
-- WHAT THESE ARE: Cata-era cosmetic and flavour auras that were never downported. The
-- server already refuses to apply them, so removing them costs nothing that currently
-- works -- it removes ~250 boot errors and makes the data honest about what this core has.
--
--   64086   Romo's Half-Size Bunny                   4 spawns
--   78677   Stormpike Trainee                       33 spawns
--   80365   Worgen Renegade                         30 spawns
--   80681   SI:7 Operative                          10 spawns
--   87972   Hillsbrad Foreman / Miner / Sentry      56 spawns
--   87973   Hillsbrad Foreman / Miner / Sentry      56 spawns
--   88964   Generic Bunny - PRK                      7 spawns
--   89281   Foothill Stalker                        22 spawns
--   90080   Mudsnout Gnoll / Shaman                 20 spawns
--   91154   Stormpike Soldier                       24 spawns
--   102371  Fahrad                                   1 spawns
--
-- NOT A PERMANENT VERDICT. These are exactly the kind of spell 88_ downports. If the
-- visuals are wanted, add them via spell-dbc-append.py (the fork's Spell.dbc is a custom
-- 234-field layout -- csv2wdbc would destroy it) and re-run 107_, which will restore the
-- aura from nelt. Stripping now and downporting later are not in conflict.
--
-- ONE UPDATE PER SPELL, DELIBERATELY. A single UPDATE ... JOIN against a list table would
-- strip only ONE id per row, and 56 spawns carry both 87972 and 87973 -- half the job with
-- no error. Eleven explicit statements are verifiable by reading them.

-- 64086 -- Romo's Half-Size Bunny
UPDATE `creature_addon` ca JOIN `creature` c ON c.`guid` = ca.`guid`
SET ca.`auras` = NULLIF(TRIM(REPLACE(REPLACE(REPLACE(
      CONCAT(' ', REPLACE(ca.`auras`, ' ', '  '), ' '), ' 64086 ', ' ')
      , '  ', ' '), '  ', ' ')), '')
WHERE c.`map` = 751 AND FIND_IN_SET(64086, REPLACE(ca.`auras`, ' ', ','));

-- 78677 -- Stormpike Trainee
UPDATE `creature_addon` ca JOIN `creature` c ON c.`guid` = ca.`guid`
SET ca.`auras` = NULLIF(TRIM(REPLACE(REPLACE(REPLACE(
      CONCAT(' ', REPLACE(ca.`auras`, ' ', '  '), ' '), ' 78677 ', ' ')
      , '  ', ' '), '  ', ' ')), '')
WHERE c.`map` = 751 AND FIND_IN_SET(78677, REPLACE(ca.`auras`, ' ', ','));

-- 80365 -- Worgen Renegade
UPDATE `creature_addon` ca JOIN `creature` c ON c.`guid` = ca.`guid`
SET ca.`auras` = NULLIF(TRIM(REPLACE(REPLACE(REPLACE(
      CONCAT(' ', REPLACE(ca.`auras`, ' ', '  '), ' '), ' 80365 ', ' ')
      , '  ', ' '), '  ', ' ')), '')
WHERE c.`map` = 751 AND FIND_IN_SET(80365, REPLACE(ca.`auras`, ' ', ','));

-- 80681 -- SI:7 Operative
UPDATE `creature_addon` ca JOIN `creature` c ON c.`guid` = ca.`guid`
SET ca.`auras` = NULLIF(TRIM(REPLACE(REPLACE(REPLACE(
      CONCAT(' ', REPLACE(ca.`auras`, ' ', '  '), ' '), ' 80681 ', ' ')
      , '  ', ' '), '  ', ' ')), '')
WHERE c.`map` = 751 AND FIND_IN_SET(80681, REPLACE(ca.`auras`, ' ', ','));

-- 87972 -- Hillsbrad Foreman / Miner / Sentry
UPDATE `creature_addon` ca JOIN `creature` c ON c.`guid` = ca.`guid`
SET ca.`auras` = NULLIF(TRIM(REPLACE(REPLACE(REPLACE(
      CONCAT(' ', REPLACE(ca.`auras`, ' ', '  '), ' '), ' 87972 ', ' ')
      , '  ', ' '), '  ', ' ')), '')
WHERE c.`map` = 751 AND FIND_IN_SET(87972, REPLACE(ca.`auras`, ' ', ','));

-- 87973 -- Hillsbrad Foreman / Miner / Sentry
UPDATE `creature_addon` ca JOIN `creature` c ON c.`guid` = ca.`guid`
SET ca.`auras` = NULLIF(TRIM(REPLACE(REPLACE(REPLACE(
      CONCAT(' ', REPLACE(ca.`auras`, ' ', '  '), ' '), ' 87973 ', ' ')
      , '  ', ' '), '  ', ' ')), '')
WHERE c.`map` = 751 AND FIND_IN_SET(87973, REPLACE(ca.`auras`, ' ', ','));

-- 88964 -- Generic Bunny - PRK
UPDATE `creature_addon` ca JOIN `creature` c ON c.`guid` = ca.`guid`
SET ca.`auras` = NULLIF(TRIM(REPLACE(REPLACE(REPLACE(
      CONCAT(' ', REPLACE(ca.`auras`, ' ', '  '), ' '), ' 88964 ', ' ')
      , '  ', ' '), '  ', ' ')), '')
WHERE c.`map` = 751 AND FIND_IN_SET(88964, REPLACE(ca.`auras`, ' ', ','));

-- 89281 -- Foothill Stalker
UPDATE `creature_addon` ca JOIN `creature` c ON c.`guid` = ca.`guid`
SET ca.`auras` = NULLIF(TRIM(REPLACE(REPLACE(REPLACE(
      CONCAT(' ', REPLACE(ca.`auras`, ' ', '  '), ' '), ' 89281 ', ' ')
      , '  ', ' '), '  ', ' ')), '')
WHERE c.`map` = 751 AND FIND_IN_SET(89281, REPLACE(ca.`auras`, ' ', ','));

-- 90080 -- Mudsnout Gnoll / Shaman
UPDATE `creature_addon` ca JOIN `creature` c ON c.`guid` = ca.`guid`
SET ca.`auras` = NULLIF(TRIM(REPLACE(REPLACE(REPLACE(
      CONCAT(' ', REPLACE(ca.`auras`, ' ', '  '), ' '), ' 90080 ', ' ')
      , '  ', ' '), '  ', ' ')), '')
WHERE c.`map` = 751 AND FIND_IN_SET(90080, REPLACE(ca.`auras`, ' ', ','));

-- 91154 -- Stormpike Soldier
UPDATE `creature_addon` ca JOIN `creature` c ON c.`guid` = ca.`guid`
SET ca.`auras` = NULLIF(TRIM(REPLACE(REPLACE(REPLACE(
      CONCAT(' ', REPLACE(ca.`auras`, ' ', '  '), ' '), ' 91154 ', ' ')
      , '  ', ' '), '  ', ' ')), '')
WHERE c.`map` = 751 AND FIND_IN_SET(91154, REPLACE(ca.`auras`, ' ', ','));

-- 102371 -- Fahrad
UPDATE `creature_addon` ca JOIN `creature` c ON c.`guid` = ca.`guid`
SET ca.`auras` = NULLIF(TRIM(REPLACE(REPLACE(REPLACE(
      CONCAT(' ', REPLACE(ca.`auras`, ' ', '  '), ' '), ' 102371 ', ' ')
      , '  ', ' '), '  ', ' ')), '')
WHERE c.`map` = 751 AND FIND_IN_SET(102371, REPLACE(ca.`auras`, ' ', ','));

-- ---------------------------------------------------------------------------
-- Verification -- every one of these must come back 0
-- ---------------------------------------------------------------------------
SELECT 'spawns still carrying 64086' AS what, COUNT(*) AS n
  FROM `creature` c JOIN `creature_addon` ca ON ca.`guid` = c.`guid`
  WHERE c.`map` = 751 AND FIND_IN_SET(64086, REPLACE(ca.`auras`, ' ', ','))
UNION ALL SELECT 'spawns still carrying 78677' AS what, COUNT(*) AS n
  FROM `creature` c JOIN `creature_addon` ca ON ca.`guid` = c.`guid`
  WHERE c.`map` = 751 AND FIND_IN_SET(78677, REPLACE(ca.`auras`, ' ', ','))
UNION ALL SELECT 'spawns still carrying 80365' AS what, COUNT(*) AS n
  FROM `creature` c JOIN `creature_addon` ca ON ca.`guid` = c.`guid`
  WHERE c.`map` = 751 AND FIND_IN_SET(80365, REPLACE(ca.`auras`, ' ', ','))
UNION ALL SELECT 'spawns still carrying 80681' AS what, COUNT(*) AS n
  FROM `creature` c JOIN `creature_addon` ca ON ca.`guid` = c.`guid`
  WHERE c.`map` = 751 AND FIND_IN_SET(80681, REPLACE(ca.`auras`, ' ', ','))
UNION ALL SELECT 'spawns still carrying 87972' AS what, COUNT(*) AS n
  FROM `creature` c JOIN `creature_addon` ca ON ca.`guid` = c.`guid`
  WHERE c.`map` = 751 AND FIND_IN_SET(87972, REPLACE(ca.`auras`, ' ', ','))
UNION ALL SELECT 'spawns still carrying 87973' AS what, COUNT(*) AS n
  FROM `creature` c JOIN `creature_addon` ca ON ca.`guid` = c.`guid`
  WHERE c.`map` = 751 AND FIND_IN_SET(87973, REPLACE(ca.`auras`, ' ', ','))
UNION ALL SELECT 'spawns still carrying 88964' AS what, COUNT(*) AS n
  FROM `creature` c JOIN `creature_addon` ca ON ca.`guid` = c.`guid`
  WHERE c.`map` = 751 AND FIND_IN_SET(88964, REPLACE(ca.`auras`, ' ', ','))
UNION ALL SELECT 'spawns still carrying 89281' AS what, COUNT(*) AS n
  FROM `creature` c JOIN `creature_addon` ca ON ca.`guid` = c.`guid`
  WHERE c.`map` = 751 AND FIND_IN_SET(89281, REPLACE(ca.`auras`, ' ', ','))
UNION ALL SELECT 'spawns still carrying 90080' AS what, COUNT(*) AS n
  FROM `creature` c JOIN `creature_addon` ca ON ca.`guid` = c.`guid`
  WHERE c.`map` = 751 AND FIND_IN_SET(90080, REPLACE(ca.`auras`, ' ', ','))
UNION ALL SELECT 'spawns still carrying 91154' AS what, COUNT(*) AS n
  FROM `creature` c JOIN `creature_addon` ca ON ca.`guid` = c.`guid`
  WHERE c.`map` = 751 AND FIND_IN_SET(91154, REPLACE(ca.`auras`, ' ', ','))
UNION ALL SELECT 'spawns still carrying 102371' AS what, COUNT(*) AS n
  FROM `creature` c JOIN `creature_addon` ca ON ca.`guid` = c.`guid`
  WHERE c.`map` = 751 AND FIND_IN_SET(102371, REPLACE(ca.`auras`, ' ', ','))
UNION ALL SELECT 'map-751 spawns still having ANY aura (should stay > 0)', COUNT(*)
  FROM `creature` c JOIN `creature_addon` ca ON ca.`guid` = c.`guid`
  WHERE c.`map` = 751 AND ca.`auras` IS NOT NULL AND ca.`auras` <> ''
UNION ALL SELECT 'waypoint links still intact (path_id > 0)', COUNT(*)
  FROM `creature` c JOIN `creature_addon` ca ON ca.`guid` = c.`guid`
  WHERE c.`map` = 751 AND ca.`path_id` > 0;
