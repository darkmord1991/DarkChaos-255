-- =====================================================================
-- DUNGEON QUEST NPC SYSTEM v2.0 - DATABASE SCHEMA
-- CORRECTED FOR AZEROTHCORE STANDARDS
-- =====================================================================
-- Purpose: Core schema for custom dungeon quest system using standard AC APIs
-- Date: November 2, 2025
-- Status: Production Ready
-- Version: 2.0 (Standard AzerothCore compliant)
-- =====================================================================

-- =====================================================================
-- TOKEN SYSTEM - Essential Custom Tables
-- =====================================================================

-- Token Item Definitions
-- Links custom token items (700001-700005) with their properties
CREATE TABLE IF NOT EXISTS `dc_quest_reward_tokens` (
    `token_item_id` INT UNSIGNED NOT NULL PRIMARY KEY COMMENT "Item ID for token (700001-700005)",
    `token_name` VARCHAR(255) NOT NULL COMMENT "Display name of token",
    `token_description` TEXT COMMENT "Token description for players",
    `token_type` ENUM('explorer', 'specialist', 'legendary', 'challenge', 'speedrunner') NOT NULL COMMENT "Token category/type",
    `rarity` TINYINT UNSIGNED DEFAULT 1 COMMENT "Item rarity (1=common, 2=uncommon, 3=rare, 4=epic)",
    `icon_id` INT UNSIGNED COMMENT "Item icon ID from client DBC",
    `created_date` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `token_type` (`token_type`)
) ENGINE=INNODB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT="Custom dungeon quest token definitions";

-- Daily Quest Token Rewards
-- Specifies which token is awarded for completing daily dungeon quests
CREATE TABLE IF NOT EXISTS `dc_daily_quest_token_rewards` (
    `quest_id` INT UNSIGNED NOT NULL PRIMARY KEY COMMENT "Daily quest ID (700101-700104)",
    `token_item_id` INT UNSIGNED NOT NULL COMMENT "Token item ID to award",
    `token_count` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT "Number of tokens awarded",
    `bonus_multiplier` FLOAT NOT NULL DEFAULT 1.0 COMMENT "Multiplier for bonus tokens (difficulty-based)",
    `created_date` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`token_item_id`) REFERENCES `dc_quest_reward_tokens`(`token_item_id`) ON DELETE CASCADE,
    INDEX `token_idx` (`token_item_id`)
) ENGINE=INNODB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT="Daily dungeon quest token rewards - triggers on QUEST_REWARDED status";

-- Weekly Quest Token Rewards
-- Specifies which token is awarded for completing weekly dungeon quests
CREATE TABLE IF NOT EXISTS `dc_weekly_quest_token_rewards` (
    `quest_id` INT UNSIGNED NOT NULL PRIMARY KEY COMMENT "Weekly quest ID (700201-700204)",
    `token_item_id` INT UNSIGNED NOT NULL COMMENT "Token item ID to award",
    `token_count` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT "Number of tokens awarded",
    `bonus_multiplier` FLOAT NOT NULL DEFAULT 1.0 COMMENT "Multiplier for bonus tokens (difficulty-based)",
    `created_date` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`token_item_id`) REFERENCES `dc_quest_reward_tokens`(`token_item_id`) ON DELETE CASCADE,
    INDEX `token_idx` (`token_item_id`)
) ENGINE=INNODB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT="Weekly dungeon quest token rewards - triggers on QUEST_REWARDED status";

-- =====================================================================
-- OPTIONAL: ADMIN REFERENCE TABLES
-- (NOT required for functionality - standard AC tables are authoritative)
-- =====================================================================

-- NPC Quest Link Reference
-- Optional table for admins to easily see which NPCs handle which quests
-- Standard AC tables are: creature_questrelation (starters), creature_involvedrelation (finishers)
CREATE TABLE IF NOT EXISTS `dc_npc_quest_link` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `npc_entry` INT UNSIGNED NOT NULL COMMENT "NPC entry ID (700000-700052)",
    `quest_id` INT UNSIGNED NOT NULL COMMENT "Quest ID (700101-700999)",
    `is_starter` TINYINT(1) NOT NULL DEFAULT 1 COMMENT "If 1: NPC starts this quest (creature_questrelation)",
    `is_ender` TINYINT(1) NOT NULL DEFAULT 1 COMMENT "If 1: NPC completes this quest (creature_involvedrelation)",
    `notes` VARCHAR(255) COMMENT "Admin notes",
    `created_date` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY `npc_quest_link` (`npc_entry`, `quest_id`),
    INDEX `quest_idx` (`quest_id`),
    INDEX `npc_idx` (`npc_entry`)
) ENGINE=INNODB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT="Optional tracking - standard AC tables (creature_questrelation, creature_involvedrelation) are authoritative";

-- =====================================================================
-- STANDARD AZEROTHCORE TABLES USED (DO NOT CREATE - ALREADY EXIST!)
-- =====================================================================

-- These tables are standard in AzerothCore and MUST be used:
-- 1. creature_template         - NPC definitions
-- 2. creature                  - NPC spawns
-- 3. quest_template            - Quest definitions
-- 4. quest_template_addon      - Quest addon data
-- 5. creature_questrelation    - Links NPCs that START quests
-- 6. creature_involvedrelation - Links NPCs that COMPLETE quests
-- 7. character_queststatus     - Player quest progress (auto-managed by AC)
-- 8. character_achievement     - Player achievements (auto-managed by AC)
-- 9. character_inventory       - Player inventory/tokens (auto-managed by AC)

-- =====================================================================
-- QUEST LINKING REFERENCE
-- =====================================================================

-- To link an NPC to quests (STANDARD AC METHOD - NO CUSTOM CODE!):
--
-- 1. NPC STARTS quest:
--    INSERT INTO creature_questrelation VALUES (npc_entry, quest_id);
--
-- 2. NPC COMPLETES quest (same NPC can do both):
--    INSERT INTO creature_involvedrelation VALUES (npc_entry, quest_id);
--
-- Example: NPC 700001 starts AND completes quest 700701
--    INSERT INTO creature_questrelation VALUES (700001, 700701);
--    INSERT INTO creature_involvedrelation VALUES (700001, 700701);
--
-- AzerothCore automatically:
-- - Shows gossip menu options (START QUEST / COMPLETE QUEST)
-- - Tracks progress in character_queststatus
-- - Handles daily/weekly resets via quest_template.Flags (0x0800=DAILY, 0x1000=WEEKLY)
-- - No custom tracking needed!

-- =====================================================================
-- DAILY/WEEKLY QUEST RESETS (STANDARD AC - AUTOMATIC!)
-- =====================================================================

-- Daily Quest (Auto-resets every 24 hours):
--    INSERT INTO quest_template (ID, Flags, ...)
--    VALUES (700101, 0x0800 | other_flags, ...);
--
-- Weekly Quest (Auto-resets every 7 days):
--    INSERT INTO quest_template (ID, Flags, ...)
--    VALUES (700201, 0x1000 | other_flags, ...);
--
-- AzerothCore handles resets automatically at daily/weekly reset time!
-- Players see quests become available again without manual tracking!

-- =====================================================================
-- IMPORTANT NOTES
-- =====================================================================

-- 1. ALL custom tables have 'dc_' prefix for clarity
-- 2. Only ESSENTIAL custom tables created above
-- 3. Standard AC tables handle everything else automatically
-- 4. No custom progress tracking needed - AC does it!
-- 5. No custom daily/weekly reset code - AC handles it!
-- 6. No custom achievement tracking - AC does it!
-- 7. C++ scripts only need to:
--    - Call AddItem() for token rewards
--    - Call CompletedAchievement() for achievements
--    - Query dc_*_token_rewards for multipliers

-- =====================================================================
-- VERSION HISTORY
-- =====================================================================
-- v2.0 (2025-11-02):
--   - Removed redundant custom tracking tables
--   - Simplified to use standard AzerothCore APIs
--   - All tables prefixed with 'dc_'
--   - Documented standard AC table usage
--   - Removed daily/weekly custom reset logic (AC handles it)
--   - Removed custom progress tracking (AC handles it)
-- v1.0 (Initial):
--   - Over-engineered with custom tracking tables
--   - Redundant with standard AC functionality

SET FOREIGN_KEY_CHECKS=1;
