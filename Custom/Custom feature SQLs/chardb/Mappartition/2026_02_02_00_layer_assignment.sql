-- Layer assignment persistence
-- Stores player layer assignment for restoration on login
CREATE TABLE IF NOT EXISTS `dc_character_layer_assignment` (
  `guid` BIGINT UNSIGNED NOT NULL,
  `map_id` SMALLINT UNSIGNED NOT NULL,
  `zone_id` INT UNSIGNED NOT NULL,
  `layer_id` SMALLINT UNSIGNED NOT NULL,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`guid`, `map_id`, `zone_id`),
  KEY `idx_map_zone_layer` (`map_id`, `zone_id`, `layer_id`),
  KEY `idx_updated_at` (`updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Cleanup event: Remove stale assignments older than 7 days
DROP EVENT IF EXISTS `dc_layer_assignment_cleanup`;
DELIMITER //
CREATE EVENT `dc_layer_assignment_cleanup`
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP
DO
BEGIN
    DELETE FROM `dc_character_layer_assignment` 
    WHERE `updated_at` < DATE_SUB(NOW(), INTERVAL 7 DAY);
END //
DELIMITER ;
