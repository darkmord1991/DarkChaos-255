-- =====================================================================
-- DarkChaos Item Upgrade System - Phase 5: Transmutation Database Schema
--
-- Database schema for the transmutation system including synthesis recipes,
-- currency exchange, tier conversion, and logging tables.
--
-- Author: DarkChaos Development Team
-- Date: November 5, 2025
--
-- TABLES ORGANIZATION:
-- World Database (acore_world): Static recipe data
-- Character Database (acore_characters): Player-specific data
-- =====================================================================

-- =====================================================================
-- WORLD DATABASE TABLES (acore_world)
-- Static recipe and configuration data
-- =====================================================================

-- =====================================================================
-- Synthesis Recipes Table
-- =====================================================================

CREATE TABLE IF NOT EXISTS `dc_item_upgrade_synthesis_recipes` (
    `recipe_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(100) NOT NULL,
    `description` TEXT NOT NULL,
    `required_level` TINYINT UNSIGNED NOT NULL DEFAULT 1,
    `input_essence` INT UNSIGNED NOT NULL DEFAULT 0,
    `input_tokens` INT UNSIGNED NOT NULL DEFAULT 0,
    `output_item_id` INT UNSIGNED NOT NULL,
    `output_quantity` TINYINT UNSIGNED NOT NULL DEFAULT 1,
    `success_rate_base` DECIMAL(5,2) NOT NULL DEFAULT 50.00,
    `cooldown_seconds` INT UNSIGNED NOT NULL DEFAULT 3600,
    `required_tier` TINYINT UNSIGNED NOT NULL DEFAULT 1,
    `required_upgrade_level` TINYINT UNSIGNED NOT NULL DEFAULT 1,
    `catalyst_item_id` INT UNSIGNED NOT NULL DEFAULT 0,
    `catalyst_quantity` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `active` TINYINT UNSIGNED NOT NULL DEFAULT 1,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`recipe_id`),
    INDEX `idx_active` (`active`),
    INDEX `idx_required_level` (`required_level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- Synthesis Recipe Inputs Table
-- =====================================================================

CREATE TABLE IF NOT EXISTS `dc_item_upgrade_synthesis_inputs` (
    `recipe_id` INT UNSIGNED NOT NULL,
    `item_id` INT UNSIGNED NOT NULL,
    `quantity` TINYINT UNSIGNED NOT NULL DEFAULT 1,
    `required_tier` TINYINT UNSIGNED NOT NULL DEFAULT 1,
    `required_upgrade_level` TINYINT UNSIGNED NOT NULL DEFAULT 1,
    PRIMARY KEY (`recipe_id`, `item_id`),
    FOREIGN KEY (`recipe_id`) REFERENCES `dc_item_upgrade_synthesis_recipes` (`recipe_id`) ON DELETE CASCADE,
    INDEX `idx_item_id` (`item_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- Sample Synthesis Recipes (World DB)
-- =====================================================================

-- Insert sample synthesis recipes (these would be customized for your server)
INSERT INTO `dc_item_upgrade_synthesis_recipes` (`name`, `description`, `required_level`, `input_essence`, `input_tokens`, `output_item_id`, `output_quantity`, `success_rate_base`, `cooldown_seconds`, `required_tier`, `required_upgrade_level`) VALUES
('Crystal of Power', 'Combine three Tier 2 upgraded items to create a powerful crystal.', 30, 50, 100, 12345, 1, 75.00, 7200, 2, 5),
('Essence Amplifier', 'Amplify artifact essence using upgraded materials.', 40, 25, 200, 12346, 1, 60.00, 3600, 3, 3),
('Tier Catalyst', 'Create a catalyst for tier conversions.', 50, 100, 500, 12347, 1, 45.00, 14400, 4, 8),
('Legendary Core', 'Forge a legendary item core from rare components.', 60, 200, 1000, 12348, 1, 30.00, 28800, 5, 10);

-- Insert sample synthesis inputs
INSERT INTO `dc_item_upgrade_synthesis_inputs` (`recipe_id`, `item_id`, `quantity`, `required_tier`, `required_upgrade_level`) VALUES
(1, 1001, 3, 2, 5),  -- Crystal of Power requires 3 Tier 2+ items upgraded 5+
(2, 1002, 2, 3, 3),  -- Essence Amplifier requires 2 Tier 3+ items upgraded 3+
(3, 1003, 1, 4, 8),  -- Tier Catalyst requires 1 Tier 4+ item upgraded 8+
(4, 1004, 5, 5, 10); -- Legendary Core requires 5 Tier 5 items upgraded 10+

-- =====================================================================
-- CHARACTER DATABASE TABLES (acore_characters)
-- Player-specific data, sessions, and logs
-- =====================================================================

-- =====================================================================
-- Synthesis Cooldowns Table
-- =====================================================================

-- NOTE: This table is now in the character database file:
-- item_upgrade_transmutation_characters_schema.sql

-- =====================================================================
-- Synthesis Log Table
-- =====================================================================

-- NOTE: This table is now in the character database file:
-- item_upgrade_transmutation_characters_schema.sql

-- =====================================================================
-- Transmutation Sessions Table
-- =====================================================================

-- NOTE: This table is now in the character database file:
-- item_upgrade_transmutation_characters_schema.sql

-- =====================================================================
-- Currency Exchange Log Table
-- =====================================================================

-- NOTE: This table is now in the character database file:
-- item_upgrade_transmutation_characters_schema.sql

-- =====================================================================
-- Update existing upgrade tables if needed (Character DB)
-- =====================================================================

-- NOTE: Character database updates are now in the character database file:
-- item_upgrade_transmutation_characters_schema.sql

-- =====================================================================
-- Cleanup old data (optional) - Character DB
-- =====================================================================

-- NOTE: Character database cleanup is now in the character database file:
-- item_upgrade_transmutation_characters_schema.sql

-- =====================================================================
-- Permissions and Grants (if needed)
-- =====================================================================

-- Note: Adjust these based on your database user permissions
-- World DB permissions:
-- GRANT SELECT, INSERT, UPDATE, DELETE ON `dc_item_upgrade_synthesis_*` TO 'acore'@'localhost';
--
-- Character DB permissions are in the character database file:
-- item_upgrade_transmutation_characters_schema.sql