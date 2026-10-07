-- DC Random Enchants: reroll service (DC.RandomEnchants.Reroll.*)
--
-- dc_item_random_enchant_rerolls: how many lines of an item have been rerolled. Every earlier
-- reroll raises the price of the next one (DC.RandomEnchants.Reroll.CostIncrease); keyed by the
-- item, so the count follows it through trades and mail.
-- dc_item_random_enchant_log: one row per paid action with every line before and after and the
-- price, written in the same transaction as the inventory save that spends the currency.
CREATE TABLE IF NOT EXISTS `dc_item_random_enchant_rerolls` (
  `item_guid` INT UNSIGNED NOT NULL COMMENT 'item_instance.guid',
  `reroll_count` INT UNSIGNED NOT NULL DEFAULT 0,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`item_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='DC random enchant reroll count per item';

CREATE TABLE IF NOT EXISTS `dc_item_random_enchant_log` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `player_guid` INT UNSIGNED NOT NULL,
  `item_guid` INT UNSIGNED NOT NULL,
  `item_entry` INT UNSIGNED NOT NULL,
  `action` TINYINT UNSIGNED NOT NULL COMMENT '1 reroll a line, 2 add a line, 3 reroll every line',
  `old_line_1` INT UNSIGNED NOT NULL DEFAULT 0,
  `old_line_2` INT UNSIGNED NOT NULL DEFAULT 0,
  `old_line_3` INT UNSIGNED NOT NULL DEFAULT 0,
  `new_line_1` INT UNSIGNED NOT NULL DEFAULT 0,
  `new_line_2` INT UNSIGNED NOT NULL DEFAULT 0,
  `new_line_3` INT UNSIGNED NOT NULL DEFAULT 0,
  `currency_type` TINYINT UNSIGNED NOT NULL COMMENT '1 Upgrade Tokens, 2 Artifact Essence, 3 Emberwood Sap',
  `currency_amount` INT UNSIGNED NOT NULL DEFAULT 0,
  `money` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'copper',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_item` (`item_guid`),
  KEY `idx_player` (`player_guid`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='DC random enchant reroll audit log';
