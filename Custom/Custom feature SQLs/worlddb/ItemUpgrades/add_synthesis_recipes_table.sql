-- Add synthesis recipes table to world database
-- This should be run after the main acore_world.sql has been imported

-- Exportiere Struktur von Tabelle acore_world.dc_synthesis_recipes
DROP TABLE IF EXISTS `dc_synthesis_recipes`;
CREATE TABLE IF NOT EXISTS `dc_synthesis_recipes` (
  `recipe_id` int unsigned NOT NULL,
  `type` varchar(50) NOT NULL,
  `name` varchar(100) NOT NULL,
  `description` text,
  `required_level` int unsigned NOT NULL DEFAULT '1',
  `input_essence` int unsigned NOT NULL DEFAULT '0',
  `input_tokens` int unsigned NOT NULL DEFAULT '0',
  `output_item_id` int unsigned NOT NULL,
  `success_rate_base` float NOT NULL DEFAULT '0',
  PRIMARY KEY (`recipe_id`),
  KEY `idx_type` (`type`),
  KEY `idx_required_level` (`required_level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Synthesis recipes for item transmutation';

-- Exportiere Daten aus Tabelle acore_world.dc_synthesis_recipes: ~0 rows (ungefähr)
-- Sample data can be added here when recipes are defined