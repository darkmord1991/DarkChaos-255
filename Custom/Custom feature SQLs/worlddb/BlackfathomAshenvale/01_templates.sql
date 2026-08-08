-- =====================================================================================
-- Blackfathom Deeps (Ashenvale) -- map 820 clone, step 1: templates
--
-- Clones map 48's creature and gameobject templates into a private id block and re-levels
-- them onto the Ashenvale band. Map 48 itself is NEVER touched -- the original 20-24
-- dungeon keeps working for low-level characters.
--
-- Self-deriving: the source id list is read from the live `creature`/`gameobject` tables at
-- run time, so this stays correct if map 48's spawn layer is ever edited. Re-runnable.
--
-- ID SCHEME (see 00_README.md)
--   creature_template / creature_loot_template   +3,900,000
--   gameobject_template / gameobject_loot_template +4,400,000
--   spawn guids                                   +16,700,000
--   levels                                        +72   (source 20-24 -> 92-96)
-- =====================================================================================

SET @C_OFF := 3900000;
SET @G_OFF := 4400000;
SET @LVL   := 72;

-- -------------------------------------------------------------------------------------
-- Source creature set = everything spawned on map 48, PLUS seven creatures that map 48 does
-- not statically spawn but the clone still needs:
--   4977 Murkshallow Softshell / 4978 Aku'mai Servant  - fire-event summons
--   6729 Morridune                                     - summoned by the Altar of the Deeps
--   12876 Baron Aquanis                                - summoned by the Fathom Stone
--   6047 Aqua Guardian / 12736 Je'neu Sancrea / 53488 Summon Enabler Stalker
--                                                      - part of the Cata layer added in 05
-- Miss the summons and the Aku'mai gate event drags level-24 originals into a level-96
-- dungeon; miss the Cata three and 05 has nothing to spawn.
-- -------------------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_src_cre;
CREATE TEMPORARY TABLE tmp_bfd_src_cre (entry INT UNSIGNED PRIMARY KEY);
INSERT IGNORE INTO tmp_bfd_src_cre (entry) SELECT DISTINCT `id` FROM `creature` WHERE `map` = 48;
INSERT IGNORE INTO tmp_bfd_src_cre (entry) VALUES (4977),(4978),(6047),(6729),(12736),(12876),(53488);

DROP TEMPORARY TABLE IF EXISTS tmp_bfd_src_go;
CREATE TEMPORARY TABLE tmp_bfd_src_go (entry INT UNSIGNED PRIMARY KEY);
INSERT IGNORE INTO tmp_bfd_src_go (entry) SELECT DISTINCT `id` FROM `gameobject` WHERE `map` = 48;

-- -------------------------------------------------------------------------------------
-- creature_template
-- Temp-table clone keeps this schema-agnostic: `LIKE` copies the column order, so a future
-- column added to creature_template does not silently shift values into the wrong field.
-- -------------------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_ct;
CREATE TEMPORARY TABLE tmp_bfd_ct LIKE `creature_template`;
INSERT INTO tmp_bfd_ct SELECT * FROM `creature_template` WHERE `entry` IN (SELECT entry FROM tmp_bfd_src_cre);

UPDATE tmp_bfd_ct SET
    `entry`              = `entry` + @C_OFF,
    -- the clone has no heroic/mythic template variants; the DC difficulty system re-levels
    -- at runtime instead, so these must not point at map 48's (nonexistent) variants
    `difficulty_entry_1` = 0,
    `difficulty_entry_2` = 0,
    `difficulty_entry_3` = 0,
    -- killing a clone must not award credit for the level-24 dungeon's quests
    `KillCredit1`        = 0,
    `KillCredit2`        = 0,
    `gossip_menu_id`     = 0,
    `minlevel`           = `minlevel` + @LVL,
    `maxlevel`           = `maxlevel` + @LVL,
    -- preserves the lootid == entry invariant used everywhere else in the custom ranges
    `lootid`             = IF(`lootid`         > 0, `lootid`         + @C_OFF, 0),
    `pickpocketloot`     = IF(`pickpocketloot` > 0, `pickpocketloot` + @C_OFF, 0),
    `skinloot`           = IF(`skinloot`       > 0, `skinloot`       + @C_OFF, 0),
    `VerifiedBuild`      = 0;

DELETE FROM `creature_template` WHERE `entry` IN (SELECT `entry` FROM tmp_bfd_ct);
INSERT INTO `creature_template` SELECT * FROM tmp_bfd_ct;

-- -------------------------------------------------------------------------------------
-- gameobject_template
-- Only type 3 (CHEST) carries a loot id, in Data1 -- offset it so the cloned chests read the
-- cloned loot tables. Every other Data field on these 19 objects is a spell/lock/flag id that
-- must stay pointing at the original.
-- -------------------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_gt;
CREATE TEMPORARY TABLE tmp_bfd_gt LIKE `gameobject_template`;
INSERT INTO tmp_bfd_gt SELECT * FROM `gameobject_template` WHERE `entry` IN (SELECT entry FROM tmp_bfd_src_go);

UPDATE tmp_bfd_gt SET
    `entry` = `entry` + @G_OFF,
    `Data1` = IF(`type` = 3 AND `Data1` > 0, `Data1` + @G_OFF, `Data1`);

DELETE FROM `gameobject_template` WHERE `entry` IN (SELECT `entry` FROM tmp_bfd_gt);
INSERT INTO `gameobject_template` SELECT * FROM tmp_bfd_gt;

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
SELECT 'creature_template'   AS `table`, CAST(COUNT(*) AS CHAR) AS result FROM `creature_template`
    WHERE `entry` BETWEEN @C_OFF AND @C_OFF + 999999
UNION ALL
SELECT 'gameobject_template', CAST(COUNT(*) AS CHAR) FROM `gameobject_template`
    WHERE `entry` BETWEEN @G_OFF AND @G_OFF + 999999
UNION ALL
SELECT 'level range', CONCAT(MIN(`minlevel`), '-', MAX(`maxlevel`)) FROM `creature_template`
    WHERE `entry` BETWEEN @C_OFF AND @C_OFF + 999999;

DROP TEMPORARY TABLE IF EXISTS tmp_bfd_ct;
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_gt;
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_src_cre;
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_src_go;
