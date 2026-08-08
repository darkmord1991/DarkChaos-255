-- =====================================================================================
-- Blackfathom Deeps (Ashenvale) -- map 820 clone, step 4: loot
--
-- Part A forks the loot tables so the clone drops independently of map 48.
-- Part B makes those drops worth the level band: the Ashenvale themed-gear reference and
-- the DC Upgrade Token, using the same conventions the map-750 loot rounds established.
--
-- Only `Entry` is offset. `Item` and `Reference` are NOT touched:
--   * Item ids are stock 1..24070 and exist unchanged.
--   * Reference ids point at shared global reference_loot_template rows (52 of the 475
--     source rows use one); offsetting them would break every reference.
--
-- Run AFTER 01_templates.sql. Re-runnable.
-- =====================================================================================

SET @C_OFF := 3900000;
SET @G_OFF := 4400000;

-- Ashenvale's themed 15-piece set reference, authored by the map-750 round-48 loot work.
SET @REF_ASHENVALE := 750088;
-- DC Item Upgrade Token (real currency since round 254 -- BagFamily 0x2000).
SET @TOKEN := 300311;

DROP TEMPORARY TABLE IF EXISTS tmp_bfd_src_cre;
CREATE TEMPORARY TABLE tmp_bfd_src_cre (entry INT UNSIGNED PRIMARY KEY);
INSERT IGNORE INTO tmp_bfd_src_cre (entry) SELECT DISTINCT `id` FROM `creature` WHERE `map` = 48;
INSERT IGNORE INTO tmp_bfd_src_cre (entry) VALUES (4977),(4978),(6047),(6729),(12736),(12876),(53488);

-- =====================================================================================
-- PART A -- fork the tables
-- =====================================================================================

-- creature_loot_template: keyed by creature_template.lootid, which 01 set to entry+@C_OFF,
-- so the fork keeps the lootid == entry invariant.
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_clt;
CREATE TEMPORARY TABLE tmp_bfd_clt LIKE `creature_loot_template`;
INSERT INTO tmp_bfd_clt SELECT * FROM `creature_loot_template`
    WHERE `Entry` IN (SELECT entry FROM tmp_bfd_src_cre);
UPDATE tmp_bfd_clt SET `Entry` = `Entry` + @C_OFF;
DELETE FROM `creature_loot_template` WHERE `Entry` IN (SELECT `Entry` FROM tmp_bfd_clt);
INSERT INTO `creature_loot_template` SELECT * FROM tmp_bfd_clt;

-- gameobject_loot_template: keyed by gameobject_template.Data1 for type 3 chests, which 01
-- offset by @G_OFF.
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_glt;
CREATE TEMPORARY TABLE tmp_bfd_glt LIKE `gameobject_loot_template`;
INSERT INTO tmp_bfd_glt SELECT * FROM `gameobject_loot_template`
    WHERE `Entry` IN (
        SELECT DISTINCT `Data1` FROM `gameobject_template`
        WHERE `type` = 3 AND `Data1` > 0
          AND `entry` IN (SELECT DISTINCT `id` FROM `gameobject` WHERE `map` = 48));
UPDATE tmp_bfd_glt SET `Entry` = `Entry` + @G_OFF;
DELETE FROM `gameobject_loot_template` WHERE `Entry` IN (SELECT `Entry` FROM tmp_bfd_glt);
INSERT INTO `gameobject_loot_template` SELECT * FROM tmp_bfd_glt;

-- =====================================================================================
-- PART B -- band-appropriate rewards
--
-- The seven bosses. BFD does not mark bosses by rank (all but Lorgus Jett are plain
-- rank 1, the same as trash), so the list is explicit rather than derived.
-- Baron Aquanis is included: he is summoned by the Fathom Stone, not statically spawned.
-- =====================================================================================
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_bosses;
CREATE TEMPORARY TABLE tmp_bfd_bosses (
    entry INT UNSIGNED PRIMARY KEY,
    ref_chance FLOAT,
    tok_min SMALLINT,
    tok_max SMALLINT,
    label VARCHAR(64)
);
INSERT INTO tmp_bfd_bosses VALUES
    (4887 + @C_OFF, 20, 20, 30, 'Ghamoo-ra'),
    (4831 + @C_OFF, 20, 20, 30, 'Lady Sarevess'),
    (6243 + @C_OFF, 20, 20, 30, 'Gelihast'),
    (4830 + @C_OFF, 25, 25, 35, 'Old Serra''kis'),
    (4832 + @C_OFF, 25, 25, 35, 'Twilight Lord Kelris'),
    (12902 + @C_OFF, 25, 25, 35, 'Lorgus Jett (rare)'),
    (12876 + @C_OFF, 25, 25, 35, 'Baron Aquanis'),
    (4829 + @C_OFF, 40, 40, 60, 'Aku''mai (final)');

-- Themed Ashenvale gear. Convention from the map-750 rounds: `Item` carries the same value
-- as `Reference` (the loader reads Item only when Reference = 0).
DELETE FROM `creature_loot_template`
    WHERE `Reference` = @REF_ASHENVALE AND `Entry` IN (SELECT entry FROM tmp_bfd_bosses);
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT b.entry, @REF_ASHENVALE, @REF_ASHENVALE, b.ref_chance, 0, 1, 0, 1, 1,
       CONCAT('BFD820 themed drop - ', b.label)
FROM tmp_bfd_bosses b;

-- Upgrade token. MinCount/MaxCount are tinyint unsigned -- 255 is the hard ceiling, and the
-- largest value used here is 60, so there is plenty of headroom if these get retuned upward.
DELETE FROM `creature_loot_template`
    WHERE `Item` = @TOKEN AND `Entry` IN (SELECT entry FROM tmp_bfd_bosses);
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT b.entry, @TOKEN, 0, 100, 0, 1, 0, b.tok_min, b.tok_max,
       CONCAT('BFD820 Upgrade Token - ', b.label)
FROM tmp_bfd_bosses b;

-- =====================================================================================
-- Report
-- =====================================================================================
SELECT 'creature_loot rows forked' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `creature_loot_template` WHERE `Entry` BETWEEN @C_OFF AND @C_OFF + 999999
UNION ALL SELECT 'gameobject_loot rows forked', CAST(COUNT(*) AS CHAR)
    FROM `gameobject_loot_template` WHERE `Entry` BETWEEN @G_OFF AND @G_OFF + 999999
UNION ALL SELECT 'bosses with themed ref (want 8)', CAST(COUNT(*) AS CHAR)
    FROM `creature_loot_template` WHERE `Reference` = @REF_ASHENVALE AND `Entry` >= @C_OFF
UNION ALL SELECT 'bosses with token (want 8)', CAST(COUNT(*) AS CHAR)
    FROM `creature_loot_template` WHERE `Item` = @TOKEN AND `Entry` >= @C_OFF AND `Entry` < @C_OFF + 1000000
UNION ALL SELECT 'lootid == entry violations (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` BETWEEN @C_OFF AND @C_OFF + 999999
      AND `lootid` <> 0 AND `lootid` <> `entry`;

DROP TEMPORARY TABLE IF EXISTS tmp_bfd_clt;
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_glt;
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_bosses;
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_src_cre;
