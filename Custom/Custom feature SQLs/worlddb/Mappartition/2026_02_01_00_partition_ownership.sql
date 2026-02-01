-- Partition ownership persistence
CREATE TABLE IF NOT EXISTS `dc_character_partition_ownership` (
  `guid` BIGINT UNSIGNED NOT NULL,
  `map_id` SMALLINT UNSIGNED NOT NULL,
  `partition_id` SMALLINT UNSIGNED NOT NULL,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`guid`, `map_id`),
  KEY `idx_map_partition` (`map_id`, `partition_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
