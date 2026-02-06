-- Fix dc_character_layer_assignment bloat
-- Problem: PK was (guid, map_id, zone_id) which created one row per zone a player visited.
--          A player visiting 50 zones = 50 rows. Only the latest row matters on login.
--          Combined with SavePersistentLayerAssignment() not checking IsLayerPersistenceEnabled(),
--          stresstests with fake GUIDs also leaked millions of rows.
--
-- Fix: Change PK to (guid) only — one row per player.
--      Keep the latest assignment per player, drop all older rows.

-- Step 1: Create the new table structure
CREATE TABLE IF NOT EXISTS `dc_character_layer_assignment_new` (
  `guid` BIGINT UNSIGNED NOT NULL,
  `map_id` INT UNSIGNED NOT NULL,
  `zone_id` INT UNSIGNED NOT NULL,
  `layer_id` INT UNSIGNED NOT NULL,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`guid`),
  KEY `idx_map_zone_layer` (`map_id`, `zone_id`, `layer_id`),
  KEY `idx_updated_at` (`updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Step 2: Migrate ONLY the latest row per player (by updated_at)
INSERT INTO `dc_character_layer_assignment_new` (`guid`, `map_id`, `zone_id`, `layer_id`, `updated_at`)
SELECT `guid`, `map_id`, `zone_id`, `layer_id`, `updated_at`
FROM (
    SELECT `guid`, `map_id`, `zone_id`, `layer_id`, `updated_at`,
           ROW_NUMBER() OVER (PARTITION BY `guid` ORDER BY `updated_at` DESC) AS rn
    FROM `dc_character_layer_assignment`
) ranked
WHERE rn = 1;

-- Step 3: Swap tables
DROP TABLE `dc_character_layer_assignment`;
ALTER TABLE `dc_character_layer_assignment_new` RENAME TO `dc_character_layer_assignment`;

-- Step 4: Purge stresstest GUIDs (fake players with counter > 10000 that don't exist in characters table)
DELETE a FROM `dc_character_layer_assignment` a
LEFT JOIN `characters` c ON a.`guid` = c.`guid`
WHERE c.`guid` IS NULL;

-- Step 5: Recreate cleanup event with shorter retention (24h instead of 7 days)
DROP EVENT IF EXISTS `dc_layer_assignment_cleanup`;
DELIMITER //
CREATE EVENT `dc_layer_assignment_cleanup`
ON SCHEDULE EVERY 1 HOUR
STARTS CURRENT_TIMESTAMP
DO
BEGIN
    -- Remove stale assignments older than 24 hours
    DELETE FROM `dc_character_layer_assignment`
    WHERE `updated_at` < DATE_SUB(NOW(), INTERVAL 24 HOUR);

    -- Remove orphaned GUIDs that no longer exist in the characters table
    DELETE a FROM `dc_character_layer_assignment` a
    LEFT JOIN `characters` c ON a.`guid` = c.`guid`
    WHERE c.`guid` IS NULL;
END //
DELIMITER ;
