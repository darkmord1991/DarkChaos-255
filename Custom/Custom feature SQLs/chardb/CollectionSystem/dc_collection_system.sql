-- ============================================================================
-- DC Collection System - Character Database Tables (Generic)
-- ============================================================================
-- Version: 2.0.0
-- Author: DarkChaos-255
-- Updated: Copilot
-- Description:
--   Generic schema used by the server-side handler:
--   src/server/scripts/DC/CollectionSystem/dc_addon_collection.cpp
-- ============================================================================

-- ============================================================================
-- GENERIC COLLECTION ITEMS
-- ============================================================================

CREATE TABLE IF NOT EXISTS `dc_collection_items` (
    `account_id` INT UNSIGNED NOT NULL,
    `collection_type` TINYINT UNSIGNED NOT NULL COMMENT '1=mount,2=pet,3=toy,4=heirloom,5=title,6=transmog',
    `entry_id` INT UNSIGNED NOT NULL COMMENT 'SpellId (mount/pet), ItemId (toy/heirloom), TitleId, DisplayId (transmog)',
    `unlocked` TINYINT(1) NOT NULL DEFAULT 1,
    `is_favorite` TINYINT(1) NOT NULL DEFAULT 0,
    `source_type` VARCHAR(16) NOT NULL DEFAULT 'UNKNOWN',
    `source_id` INT UNSIGNED DEFAULT NULL,
    `acquired_date` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `times_used` INT UNSIGNED NOT NULL DEFAULT 0,
    `last_used` TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (`account_id`, `collection_type`, `entry_id`),
    KEY `idx_type_account` (`collection_type`, `account_id`),
    KEY `idx_fav` (`account_id`, `collection_type`, `is_favorite`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Generic account-wide collection items';

-- ============================================================================
-- WISHLIST
-- ============================================================================

CREATE TABLE IF NOT EXISTS `dc_collection_wishlist` (
    `account_id` INT UNSIGNED NOT NULL,
    `collection_type` TINYINT UNSIGNED NOT NULL,
    `entry_id` INT UNSIGNED NOT NULL,
    `added_date` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`account_id`, `collection_type`, `entry_id`),
    KEY `idx_added` (`account_id`, `added_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Collection wishlist (generic)';

-- ============================================================================
-- CURRENCY
-- ============================================================================

-- NOTE (Dec 2025):
-- The DC-Collection server handler now reuses the existing ItemUpgrade currency
-- implementation (shared by CrossSystem/Seasons):
--   - Table: `dc_player_upgrade_tokens`
--   - currency_type: 'upgrade_token' (tokens) and 'artifact_essence' (emblems)
--   - Season: resolved via DarkChaos::ItemUpgrade::GetCurrentSeasonId()
--
-- The `dc_collection_currency` table below is kept ONLY for older revisions and
-- is not used by the current server code.

CREATE TABLE IF NOT EXISTS `dc_collection_currency` (
    `account_id` INT UNSIGNED NOT NULL,
    `currency_id` INT UNSIGNED NOT NULL COMMENT '1=tokens, 2=emblems',
    `amount` INT UNSIGNED NOT NULL DEFAULT 0,
    `lifetime_amount` INT UNSIGNED NOT NULL DEFAULT 0,
    `last_updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`account_id`, `currency_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Collection currency per account (generic)';

-- ============================================================================
-- SHOP PURCHASES
-- ============================================================================

CREATE TABLE IF NOT EXISTS `dc_collection_shop_purchases` (
    `id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `account_id` INT UNSIGNED NOT NULL,
    `shop_item_id` INT UNSIGNED NOT NULL,
    `character_guid` INT UNSIGNED NOT NULL,
    `price_tokens` INT UNSIGNED NOT NULL DEFAULT 0,
    `price_emblems` INT UNSIGNED NOT NULL DEFAULT 0,
    `purchase_date` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY `idx_account` (`account_id`),
    KEY `idx_shop_item` (`shop_item_id`),
    KEY `idx_date` (`purchase_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Collection shop purchase history (generic)';

-- ============================================================================
-- TRANSMOG: ACTIVE SELECTIONS (PER CHARACTER)
-- ============================================================================

CREATE TABLE IF NOT EXISTS `dc_character_transmog` (
    `guid` INT UNSIGNED NOT NULL COMMENT 'Character GUID (low)',
    `slot` TINYINT UNSIGNED NOT NULL COMMENT 'Equipment slot (0-18)',
    `fake_entry` INT UNSIGNED NOT NULL COMMENT 'Item entry used for appearance',
    `real_entry` INT UNSIGNED NOT NULL COMMENT 'Real equipped item entry',
    PRIMARY KEY (`guid`, `slot`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Applied transmog per character';

-- ============================================================================
-- MIGRATIONS (OPTIONAL)
-- ============================================================================

CREATE TABLE IF NOT EXISTS `dc_collection_migrations` (
    `account_id` INT UNSIGNED NOT NULL,
    `migration_key` VARCHAR(64) NOT NULL,
    `done` TINYINT(1) NOT NULL DEFAULT 1,
    `done_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`account_id`, `migration_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='One-time account migrations for DC-Collection';

-- NOTE:
-- The previous per-type schema and stored procedures were removed in v2.0.0.
-- All counters/totals are computed by the server from dc_collection_items and
-- worlddb definitions.

-- ============================================================================
-- OPTIONAL INITIAL DATA
-- ============================================================================

-- Optional: initialize currency rows (tokens + emblems) for existing accounts.
-- Adjust auth DB name if needed.
-- INSERT IGNORE INTO dc_collection_currency (account_id, currency_id, amount, lifetime_amount)
-- SELECT a.id, 1, 0, 0 FROM acore_auth.account a;
-- INSERT IGNORE INTO dc_collection_currency (account_id, currency_id, amount, lifetime_amount)
-- SELECT a.id, 2, 0, 0 FROM acore_auth.account a;
