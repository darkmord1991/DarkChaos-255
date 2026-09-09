-- Persisted death markers (world-map pins for Hardcore / Iron Prestige deaths).
-- Mirrors the in-memory DeathMarker struct in dc_addon_death_markers.cpp so markers
-- survive a worldserver restart; rows are cleaned up opportunistically once expired.
CREATE TABLE IF NOT EXISTS `dc_death_markers` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `mode_id` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `mode_label` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `victim_guid` int unsigned NOT NULL DEFAULT 0,
  `victim_name` varchar(24) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `victim_level` tinyint unsigned NOT NULL DEFAULT 0,
  `victim_class` tinyint unsigned NOT NULL DEFAULT 0,
  `killer_type` varchar(16) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'unknown',
  `killer_entry` int unsigned NOT NULL DEFAULT 0,
  `killer_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `killer_level` int unsigned NOT NULL DEFAULT 0,
  `killer_rank` varchar(16) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `environment_type` varchar(16) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `killing_blow_damage` int unsigned NOT NULL DEFAULT 0,
  `spell_id` int unsigned NOT NULL DEFAULT 0,
  `spell_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `failure_reason` varchar(320) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `map_id` int unsigned NOT NULL DEFAULT 0,
  `pos_x` float NOT NULL DEFAULT 0,
  `pos_y` float NOT NULL DEFAULT 0,
  `died_at` int unsigned NOT NULL DEFAULT 0,
  `expires_at` int unsigned NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_expires_at` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Persisted death markers for the world-map death-marker feature';

-- Upgrade path for realms that already created the table with the original column set: the
-- markers gained the killer's level/rank and the killing-blow spell, and the composed failure
-- reason ("Slain by Ragnaros (Level 63 Boss) with Sulfuras Smash.") no longer fits varchar(64).
-- 320 rather than 255: the reason concatenates a killer name (creature_template.name, longest 76)
-- and a spell name (spell_dbc, longest 82) plus ~50 chars of scaffolding, so 255 leaves only ~46
-- chars of margin against future imports - and overflowing it is error 1406 under strict mode,
-- i.e. the marker INSERT fails outright rather than truncating.
-- MySQL 8 has no ADD COLUMN IF NOT EXISTS, so each add is guarded by an information_schema check
-- driving a prepared statement - the same idiom the other chardb migrations here use.
--
-- The ALTER lives inside a single-quoted string, so every quote in it must be doubled: the
-- column default below is written DEFAULT '''' and reaches the parser as DEFAULT ''. Writing it
-- as DEFAULT '' instead closes the string early and fails with error 1064.

SET @has_killer_level := (SELECT COUNT(*)
  FROM `information_schema`.`COLUMNS`
  WHERE `TABLE_SCHEMA` = DATABASE()
    AND `TABLE_NAME` = 'dc_death_markers'
    AND `COLUMN_NAME` = 'killer_level');

SET @stmt := IF(@has_killer_level = 0,
  'ALTER TABLE `dc_death_markers`
     ADD COLUMN `killer_level` int unsigned NOT NULL DEFAULT 0 AFTER `killer_name`,
     ADD COLUMN `killer_rank` varchar(16) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '''' AFTER `killer_level`',
  'DO 0');
PREPARE stmt FROM @stmt;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_spell_id := (SELECT COUNT(*)
  FROM `information_schema`.`COLUMNS`
  WHERE `TABLE_SCHEMA` = DATABASE()
    AND `TABLE_NAME` = 'dc_death_markers'
    AND `COLUMN_NAME` = 'spell_id');

SET @stmt := IF(@has_spell_id = 0,
  'ALTER TABLE `dc_death_markers`
     ADD COLUMN `spell_id` int unsigned NOT NULL DEFAULT 0 AFTER `killing_blow_damage`,
     ADD COLUMN `spell_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '''' AFTER `spell_id`',
  'DO 0');
PREPARE stmt FROM @stmt;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

ALTER TABLE `dc_death_markers`
  MODIFY COLUMN `failure_reason` varchar(320) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '';

-- Existing rows only ever carried the placeholder reason; rebuild what we can from the columns
-- that were already recorded so old pins stop reading "Died.".
UPDATE `dc_death_markers`
SET `failure_reason` = CASE
    WHEN `killer_type` IN ('creature', 'player') AND `killer_name` <> ''
        THEN CONCAT('Slain by ', `killer_name`, '.')
    WHEN `killer_type` = 'environment' AND `environment_type` = 'Falling'  THEN 'Fell to their death.'
    WHEN `killer_type` = 'environment' AND `environment_type` = 'Drowning' THEN 'Drowned.'
    WHEN `killer_type` = 'environment' AND `environment_type` = 'Fatigue'  THEN 'Succumbed to exhaustion.'
    WHEN `killer_type` = 'environment' AND `environment_type` = 'Lava'     THEN 'Burned alive in lava.'
    WHEN `killer_type` = 'environment' AND `environment_type` = 'Slime'    THEN 'Dissolved in slime.'
    WHEN `killer_type` = 'environment' AND `environment_type` = 'Fire'     THEN 'Burned to death.'
    WHEN `killer_type` = 'environment'                                     THEN 'Killed by the environment.'
    ELSE 'Died to an unknown cause.'
END
WHERE `failure_reason` IN ('', 'Died.');
