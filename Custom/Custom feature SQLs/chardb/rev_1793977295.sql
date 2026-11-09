-- Transmog appearance favorites.
--
-- Appearance ownership lives in dc_transmog_collection (per account, keyed by
-- display id), which has no favorite flag. Favorites get their own small table,
-- keyed the same way, instead of a column on that 1.4M-row table.
-- Written by HandleSetFavorite (collection type 6) and read by
-- LoadFavoriteCollectionIds in dc_addon_collection.cpp, which sends only the
-- favorites whose appearance is still in the account's wardrobe.
CREATE TABLE IF NOT EXISTS `dc_transmog_favorites` (
    `account_id` INT UNSIGNED NOT NULL COMMENT 'Account ID',
    `display_id` INT UNSIGNED NOT NULL COMMENT 'Item display ID, as dc_transmog_collection.display_id',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`account_id`, `display_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Account transmog appearance favorites';
