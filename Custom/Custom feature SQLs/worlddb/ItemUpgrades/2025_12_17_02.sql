-- Fix for [1054] Unknown column 'recipe_id' in 'field list'
-- Recreating dc_item_upgrade_synthesis_recipes table

DROP TABLE IF EXISTS `dc_item_upgrade_synthesis_recipes`;
CREATE TABLE `dc_item_upgrade_synthesis_recipes` (
  `recipe_id` int unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `description` text,
  `required_level` int unsigned DEFAULT 0,
  `input_essence` int unsigned DEFAULT 0,
  `input_tokens` int unsigned DEFAULT 0,
  `output_item_id` int unsigned NOT NULL,
  `output_quantity` int unsigned DEFAULT 1,
  `success_rate_base` decimal(5,2) DEFAULT 100.00 COMMENT 'Base success rate as percentage (0-100)',
  `cooldown_seconds` int unsigned DEFAULT 0,
  `required_tier` tinyint unsigned DEFAULT 0,
  `required_upgrade_level` tinyint unsigned DEFAULT 0,
  `catalyst_item_id` int unsigned DEFAULT 0,
  `catalyst_quantity` int unsigned DEFAULT 0,
  `active` tinyint(1) DEFAULT 1,
  PRIMARY KEY (`recipe_id`),
  KEY `idx_active` (`active`),
  KEY `idx_required_level` (`required_level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Synthesis recipes for combining items/materials into new items';

-- Sample synthesis recipes
INSERT INTO `dc_item_upgrade_synthesis_recipes` 
  (`recipe_id`, `name`, `description`, `required_level`, `input_essence`, `input_tokens`, 
   `output_item_id`, `output_quantity`, `success_rate_base`, `cooldown_seconds`, 
   `required_tier`, `required_upgrade_level`, `catalyst_item_id`, `catalyst_quantity`, `active`) 
VALUES
(1, 'Basic Essence Synthesis', 'Combine essences to create a basic upgrade token', 1, 100, 0, 50001, 1, 100.00, 0, 0, 0, 0, 0, 1),
(2, 'Advanced Token Craft', 'Craft advanced tokens from basic materials', 10, 200, 50, 50002, 1, 95.00, 3600, 1, 0, 0, 0, 1),
(3, 'Epic Synthesis', 'High-level synthesis with increased difficulty', 30, 500, 200, 50003, 1, 75.00, 7200, 2, 5, 0, 0, 1),
(4, 'Legendary Transmutation', 'Ultimate synthesis with low success rate', 50, 1000, 500, 50004, 1, 50.00, 14400, 2, 10, 0, 0, 0);
