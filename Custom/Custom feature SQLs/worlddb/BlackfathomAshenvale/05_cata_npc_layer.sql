-- =====================================================================================
-- Blackfathom Deeps (Ashenvale) -- map 820 clone, step 5: the Cataclysm NPC layer
--
-- Map 48 in our DB carries the WotLK population: 212 spawns of 28 entries. Both the BFA
-- (HavenCore) and Shadowlands (DekkCore) world DBs spawn 41 entries in the same rooms --
-- the extra 13 are the Cataclysm quest/ambience layer that AzerothCore never imported.
-- This file adds that layer to the CLONE only; map 48 stays exactly as it is.
--
-- Verified against the source before writing:
--   * all 13 exist in BFA HavenCore's map-48 spawn set (identical in DekkCore world09)
--   * 7 already have 3.3.5 templates here and are cloned by 01_templates.sql
--   * 6 do not exist in any 3.3.5 DB we have and are built below
--   * 4 of those 6 used Cata-only display ids (28520/28528/28529/28530); those displays
--     have now been DOWNPORTED from the 4.3.4 client together with their extended
--     display info, 2 item displays and 4 baked textures -- see
--     Custom/BlackfathomAshenvale/downport_sentinel_displays.py
--
-- Run AFTER 01-04. Re-runnable.
-- =====================================================================================

SET @C_OFF := 3900000;
SET @GUID := 16760000;   -- own guid block, clear of the +16,700,000 clone block
SET @LVL := 72;
SET @LVL_CAP := 96;

-- -------------------------------------------------------------------------------------
-- The six templates that have to be created. Each is cloned from a stock template of the
-- right archetype so every stat/speed/flag column gets a sane 3.3.5 value, then the
-- identity fields are overridden. Levels take the same +72 as the rest of the clone,
-- clamped to the dungeon's top level so no straggler sits above the band.
-- -------------------------------------------------------------------------------------

DROP TEMPORARY TABLE IF EXISTS tmp_bfd_new;
CREATE TEMPORARY TABLE tmp_bfd_new (
    new_entry  INT UNSIGNED PRIMARY KEY,
    base_entry INT UNSIGNED,
    name       VARCHAR(100),
    subname    VARCHAR(100),
    lvl        SMALLINT,
    faction    SMALLINT UNSIGNED,
    rnk        TINYINT UNSIGNED,
    ctype      TINYINT UNSIGNED,
    uclass     TINYINT UNSIGNED,
    display    INT UNSIGNED,
    note       VARCHAR(120)
);
INSERT INTO tmp_bfd_new VALUES
    (3933256, 3694, 'Ashelan Northwood', '', 94, 1076, 1, 7, 2, 28528, 'Cata display downported from the 4.3.4 client'),
    (3933258, 3694, 'Relwyn Shadestar', '', 95, 1076, 1, 7, 1, 28520, 'Cata display downported from the 4.3.4 client'),
    (3933260, 3694, 'Sentinel Aluwyn', '', 93, 1076, 1, 7, 1, 28530, 'Cata display downported from the 4.3.4 client'),
    (3933261, 3694, 'Sentinel-trainee Issara', '', 93, 1076, 0, 7, 1, 28529, 'Cata display downported from the 4.3.4 client'),
    (3944375, 3694, 'Zeya', '', 95, 35, 0, 7, 1, 4084, 'display 4084 already exists in 3.3.5'),
    (3944387, 4978, 'Flaming Eradicator', '', 96, 35, 1, 4, 1, 12231, 'display 12231 already exists in 3.3.5');

-- Schema-agnostic build: copy whole base rows, rewrite the key through a helper column,
-- then patch only the identity fields. No 55-column INSERT list to drift out of sync when
-- creature_template gains a column. The PK is dropped on the temp table because four of
-- the six new NPCs share base template 3694 and would otherwise collide.
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_nt;
CREATE TEMPORARY TABLE tmp_bfd_nt LIKE `creature_template`;
ALTER TABLE tmp_bfd_nt DROP PRIMARY KEY, ADD COLUMN `new_entry` INT UNSIGNED;
INSERT INTO tmp_bfd_nt
    SELECT ct.*, n.new_entry FROM tmp_bfd_new n
    JOIN `creature_template` ct ON ct.`entry` = n.base_entry;
UPDATE tmp_bfd_nt SET `entry` = `new_entry`;
ALTER TABLE tmp_bfd_nt DROP COLUMN `new_entry`;

DELETE FROM `creature_template` WHERE `entry` IN (SELECT new_entry FROM tmp_bfd_new);
INSERT INTO `creature_template` SELECT * FROM tmp_bfd_nt;

-- lootid stays 0: these are quest/ambience NPCs with no loot table, and a non-zero lootid
-- with no matching rows makes the core log a missing-loot-table warning for each of them.
UPDATE `creature_template` ct JOIN tmp_bfd_new n ON n.new_entry = ct.`entry` SET
    ct.`name` = n.name, ct.`subname` = n.subname,
    ct.`minlevel` = n.lvl, ct.`maxlevel` = n.lvl,
    ct.`faction` = n.faction, ct.`rank` = n.rnk,
    ct.`type` = n.ctype, ct.`unit_class` = n.uclass,
    ct.`lootid` = 0, ct.`pickpocketloot` = 0, ct.`skinloot` = 0,
    ct.`difficulty_entry_1` = 0, ct.`difficulty_entry_2` = 0, ct.`difficulty_entry_3` = 0,
    ct.`KillCredit1` = 0, ct.`KillCredit2` = 0, ct.`gossip_menu_id` = 0,
    ct.`npcflag` = 0, ct.`AIName` = '', ct.`ScriptName` = '', ct.`VerifiedBuild` = 0;

-- display ids
DELETE FROM `creature_template_model` WHERE `CreatureID` IN (SELECT new_entry FROM tmp_bfd_new);
INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
SELECT new_entry, 0, display, 1, 1, 0 FROM tmp_bfd_new;

-- loot: the six new NPCs get no loot table of their own (they are quest/ambience NPCs).
-- lootid was set to new_entry above to keep the lootid == entry invariant; with no rows
-- in creature_loot_template that simply means "drops nothing", which is correct.

-- -------------------------------------------------------------------------------------
-- creature_model_info -- the server half of the four downported displays.
-- Without a row the core logs a missing-model-info warning and falls back to defaults.
-- -------------------------------------------------------------------------------------
DELETE FROM `creature_model_info` WHERE `DisplayID` IN (28520, 28528, 28529, 28530);
INSERT INTO `creature_model_info`
    (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`, `DisplayID_Other_Gender`)
VALUES
    (28520, 0.306, 1.5, 1, 0),
    (28528, 0.306, 1.5, 0, 0),
    (28529, 0.306, 1.5, 1, 0),
    (28530, 0.306, 1.5, 1, 0);

-- -------------------------------------------------------------------------------------
-- Spawns. Coordinates come straight from BFA HavenCore's map-48 rows, which are valid on
-- map 820 unchanged because the clone shares map 48's `Blackfathom` terrain.
-- spawnMask 7 = difficulties 0|1|2, matching MapDifficulty rows 9341/9342/9343.
--
-- 6729 Morridune and 12876 Baron Aquanis are intentionally NOT spawned: the Altar of the
-- Deeps and the Fathom Stone summon them (see the source_type 1 SmartAI cloned in 02), so
-- a static copy would put two of each in the dungeon.
-- -------------------------------------------------------------------------------------
DELETE FROM `creature` WHERE `guid` BETWEEN @GUID AND @GUID + 999;
INSERT INTO `creature`
    (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`,
     `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`,
     `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`,
     `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`, `CreateObject`, `Comment`)
VALUES
    (@GUID +   0, 3904977, 820, 0, 0, 7, 1, 0, -866.951, -166, -24.3158, 0.261799, 3600, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'BFD820 Cata layer - Murkshallow Softshell'),
    (@GUID +   1, 3904977, 820, 0, 0, 7, 1, 0, -869.373, -152.18, -24.3078, 5.28835, 3600, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'BFD820 Cata layer - Murkshallow Softshell'),
    (@GUID +   2, 3904977, 820, 0, 0, 7, 1, 0, -867.536, -176.77, -24.3141, 1.53589, 3600, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'BFD820 Cata layer - Murkshallow Softshell'),
    (@GUID +   3, 3904977, 820, 0, 0, 7, 1, 0, -866.07, -156.004, -24.3127, 6.03884, 3600, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'BFD820 Cata layer - Murkshallow Softshell'),
    (@GUID +   4, 3904977, 820, 0, 0, 7, 1, 0, -767.067, -156.371, -24.315, 2.47837, 3600, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'BFD820 Cata layer - Murkshallow Softshell'),
    (@GUID +   5, 3904977, 820, 0, 0, 7, 1, 0, -767.368, -164.428, -24.3158, 5.89921, 3600, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'BFD820 Cata layer - Murkshallow Softshell'),
    (@GUID +   6, 3904977, 820, 0, 0, 7, 1, 0, -766.824, -151.186, -24.3032, 0.733038, 3600, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'BFD820 Cata layer - Murkshallow Softshell'),
    (@GUID +   7, 3904977, 820, 0, 0, 7, 1, 0, -869.775, -163.409, -24.3158, 1.78024, 3600, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'BFD820 Cata layer - Murkshallow Softshell'),
    (@GUID +   8, 3904977, 820, 0, 0, 7, 1, 0, -769.717, -173.93, -24.3149, 1.16937, 3600, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'BFD820 Cata layer - Murkshallow Softshell'),
    (@GUID +   9, 3904977, 820, 0, 0, 7, 1, 0, -767.464, -176.266, -24.3146, 3.12414, 3600, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'BFD820 Cata layer - Murkshallow Softshell'),
    (@GUID +  10, 3904978, 820, 0, 0, 7, 1, 0, -868.361, -164.055, -24.3158, 0.296706, 3600, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'BFD820 Cata layer - Aku''mai Servant'),
    (@GUID +  11, 3904978, 820, 0, 0, 7, 1, 0, -767.812, -164.874, -24.3158, 0.191986, 3600, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'BFD820 Cata layer - Aku''mai Servant'),
    (@GUID +  12, 3906047, 820, 0, 0, 7, 1, 0, -804.504, -52.7006, -29.6848, 5.71884, 3600, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'BFD820 Cata layer - Aqua Guardian'),
    (@GUID +  13, 3906047, 820, 0, 0, 7, 1, 0, -727.918, -106.326, -30.0872, 6.02908, 3600, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'BFD820 Cata layer - Aqua Guardian'),
    (@GUID +  14, 3906047, 820, 0, 0, 7, 1, 0, -722.66, 4.36189, -30.0333, 1.48555, 3600, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'BFD820 Cata layer - Aqua Guardian'),
    (@GUID +  15, 3906047, 820, 0, 0, 7, 1, 0, -719.398, -24.3841, -37.7361, 4.39387, 3600, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'BFD820 Cata layer - Aqua Guardian'),
    (@GUID +  16, 3906047, 820, 0, 0, 7, 1, 0, -721.349, -49.7427, -37.7336, 1.58614, 3600, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'BFD820 Cata layer - Aqua Guardian'),
    (@GUID +  17, 3906047, 820, 0, 0, 7, 1, 0, -784.532, -57.9479, -29.7302, 3.85498, 3600, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'BFD820 Cata layer - Aqua Guardian'),
    (@GUID +  18, 3906047, 820, 0, 0, 7, 1, 0, -801.2, -57.299, -29.6816, 6.15904, 3600, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'BFD820 Cata layer - Aqua Guardian'),
    (@GUID +  19, 3906047, 820, 0, 0, 7, 1, 0, -826.03, -69.1943, -29.6827, 6.15866, 3600, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'BFD820 Cata layer - Aqua Guardian'),
    (@GUID +  20, 3906047, 820, 0, 0, 7, 1, 0, -825.543, -59.5041, -29.6853, 6.09583, 3600, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'BFD820 Cata layer - Aqua Guardian'),
    (@GUID +  21, 3906047, 820, 0, 0, 7, 1, 0, -821.483, -50.1987, -29.6855, 5.65993, 3600, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'BFD820 Cata layer - Aqua Guardian'),
    (@GUID +  22, 3912736, 820, 0, 0, 7, 1, 0, -157.078, 74.129, -45.5308, 1.5708, 3600, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'BFD820 Cata layer - Je''neu Sancrea'),
    (@GUID +  23, 3933256, 820, 0, 0, 7, 1, 0, -167.009, 79.2494, -45.7184, 0, 3600, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'BFD820 Cata layer - Ashelan Northwood'),
    (@GUID +  24, 3933258, 820, 0, 0, 7, 1, 0, -164.906, 79.3527, -46.014, 3.33358, 3600, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'BFD820 Cata layer - Relwyn Shadestar'),
    (@GUID +  25, 3933260, 820, 0, 0, 7, 1, 0, -158.536, 74.219, -45.7543, 0.890118, 3600, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'BFD820 Cata layer - Sentinel Aluwyn'),
    (@GUID +  26, 3933261, 820, 0, 0, 7, 1, 0, -156.314, 74.0989, -45.4139, 0, 3600, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'BFD820 Cata layer - Sentinel-trainee Issara'),
    (@GUID +  27, 3944375, 820, 0, 0, 7, 1, 0, -164.933, 76.5771, -45.8097, 0.418879, 3600, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'BFD820 Cata layer - Zeya'),
    (@GUID +  28, 3944387, 820, 0, 0, 7, 1, 0, -732.92, 21.3355, -30.3792, 0.855211, 3600, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'BFD820 Cata layer - Flaming Eradicator'),
    (@GUID +  29, 3953488, 820, 0, 0, 7, 1, 0, -156.814, 85.1028, -45.0317, 4.39823, 3600, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'BFD820 Cata layer - Summon Enabler Stalker'),
    (@GUID +  30, 3953488, 820, 0, 0, 7, 1, 0, -151.668, 101.15, -40.7822, 4.39823, 3600, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'BFD820 Cata layer - Summon Enabler Stalker');

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
SELECT 'new templates built (want 6)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `creature_template` WHERE `entry` IN (SELECT new_entry FROM tmp_bfd_new)
UNION ALL SELECT 'Cata layer spawns (want 31)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `guid` BETWEEN @GUID AND @GUID + 999
UNION ALL SELECT 'Cata spawns missing a template (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature` c LEFT JOIN `creature_template` ct ON ct.`entry` = c.`id`
    WHERE c.`guid` BETWEEN @GUID AND @GUID + 999 AND ct.`entry` IS NULL
UNION ALL SELECT 'Cata spawns missing a display (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature` c LEFT JOIN `creature_template_model` m ON m.`CreatureID` = c.`id`
    WHERE c.`guid` BETWEEN @GUID AND @GUID + 999 AND m.`CreatureID` IS NULL
UNION ALL SELECT 'downported displays with model_info (want 4)', CAST(COUNT(*) AS CHAR)
    FROM `creature_model_info` WHERE `DisplayID` IN (28520, 28528, 28529, 28530)
UNION ALL SELECT 'map 820 total creature spawns', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `map` = 820;

DROP TEMPORARY TABLE IF EXISTS tmp_bfd_nt;
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_nt2;
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_new;
