-- ============================================================================
-- DC-Collection Transmog Migration (CHAR DB step)
-- ============================================================================
-- Run this file while connected to your CHARACTER database.
--
-- Prerequisites:
--   1) Run WORLD step first:
--        worlddb/CollectionSystem/migrate_legacy_transmog_world.sql
--      This creates: dc_migration_item_display in your Char DB.
--
-- Optional (if you used legacy auth.account_transmog):
--   2) Run AUTH step before this:
--        authdb/CollectionSystem/migrate_legacy_transmog_auth.sql
--      This populates: dc_migration_auth_unlocks in your Char DB.
--
-- This script:
--   - Migrates unlocks -> dc_collection_items (type=6, entry_id=DisplayId)
--   - Migrates applied per-slot -> dc_character_transmog
--   - Drops legacy CHAR DB tables (per request)
-- ============================================================================

SET @COLLECTION_TYPE_TRANSMOG := 6;

-- ---------------------------------------------------------------------------
-- SAFETY: Ensure helper tables exist (no-op if already created)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `dc_migration_item_display` (
  `entry` MEDIUMINT UNSIGNED NOT NULL,
  `displayid` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`entry`),
  KEY `idx_displayid` (`displayid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Migration helper: item_template entry -> displayid';

CREATE TABLE IF NOT EXISTS `dc_migration_auth_unlocks` (
  `account_id` INT UNSIGNED NOT NULL,
  `displayid` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`account_id`, `displayid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Migration staging: auth unlocks (account_id -> displayid)';

-- ---------------------------------------------------------------------------
-- 1) MIGRATE UNLOCKS
-- ---------------------------------------------------------------------------

-- 1a) From AUTH staging table (populated by auth step). If empty, no effect.
INSERT IGNORE INTO `dc_collection_items`
  (`account_id`,`collection_type`,`entry_id`,`source_type`,`unlocked`,`acquired_date`)
SELECT
  a.`account_id`, @COLLECTION_TYPE_TRANSMOG, a.`displayid`, 'MIGRATE_AUTH_ACCOUNT_TRANSMOG', 1, NOW()
FROM `dc_migration_auth_unlocks` a
WHERE a.`displayid` IS NOT NULL AND a.`displayid` > 0;

-- 1b) From legacy char table: custom_unlocked_appearances(account_id, item_template_id)
--     Resolve displayid via dc_migration_item_display.
INSERT IGNORE INTO `dc_collection_items`
  (`account_id`,`collection_type`,`entry_id`,`source_type`,`unlocked`,`acquired_date`)
SELECT
  cua.`account_id`, @COLLECTION_TYPE_TRANSMOG, mid.`displayid`, 'MIGRATE_CHARS_CUSTOM_UNLOCKED', 1, NOW()
FROM `custom_unlocked_appearances` cua
JOIN `dc_migration_item_display` mid ON mid.`entry` = cua.`item_template_id`
WHERE mid.`displayid` IS NOT NULL AND mid.`displayid` > 0;

-- 1c) From legacy char table: custom_transmogrification(FakeEntry, Owner)
--     Owner -> account via characters; FakeEntry -> displayid via dc_migration_item_display.
INSERT IGNORE INTO `dc_collection_items`
  (`account_id`,`collection_type`,`entry_id`,`source_type`,`unlocked`,`acquired_date`)
SELECT
  ch.`account`, @COLLECTION_TYPE_TRANSMOG, mid.`displayid`, 'MIGRATE_CHARS_CUSTOM_TRANSMOG', 1, NOW()
FROM `custom_transmogrification` ct
JOIN `characters` ch ON ch.`guid` = ct.`Owner`
JOIN `dc_migration_item_display` mid ON mid.`entry` = ct.`FakeEntry`
WHERE mid.`displayid` IS NOT NULL AND mid.`displayid` > 0;

-- ---------------------------------------------------------------------------
-- 2) MIGRATE APPLIED PER-SLOT TRANSMOG
-- ---------------------------------------------------------------------------

-- Legacy: character_transmog(player_guid, slot(varchar), item, real_item)
-- New:    dc_character_transmog(guid, slot(tinyint), fake_entry, real_entry)
INSERT INTO `dc_character_transmog` (`guid`,`slot`,`fake_entry`,`real_entry`)
SELECT
  ct.`player_guid`, CAST(ct.`slot` AS UNSIGNED), ct.`item`, ct.`real_item`
FROM `character_transmog` ct
WHERE ct.`player_guid` IS NOT NULL
  AND ct.`item` IS NOT NULL AND ct.`item` > 0
  AND ct.`real_item` IS NOT NULL AND ct.`real_item` > 0
  AND CAST(ct.`slot` AS UNSIGNED) BETWEEN 0 AND 18
ON DUPLICATE KEY UPDATE
  `fake_entry` = VALUES(`fake_entry`),
  `real_entry` = VALUES(`real_entry`);

-- ---------------------------------------------------------------------------
-- 3) DROP LEGACY CHAR DB TABLES (PER REQUEST)
-- ---------------------------------------------------------------------------

DROP TABLE IF EXISTS `character_transmog`;
DROP TABLE IF EXISTS `custom_transmogrification`;
DROP TABLE IF EXISTS `custom_transmogrification_sets`;
DROP TABLE IF EXISTS `custom_unlocked_appearances`;

-- Optional: drop helper/staging tables after migration
-- DROP TABLE IF EXISTS `dc_migration_item_display`;
-- DROP TABLE IF EXISTS `dc_migration_auth_unlocks`;

SELECT 'CHAR step complete: transmog migrated + legacy char tables dropped.' AS status;
