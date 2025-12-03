-- =============================================================================
-- DC-Welcome Database Tables
-- First-Start Experience System
-- =============================================================================
-- 
-- Run this against the 'characters' database
-- Tables track welcome screen dismissal and feature introduction progress
--

-- Drop tables if they exist (for clean reinstall)
DROP TABLE IF EXISTS `dc_player_welcome`;
DROP TABLE IF EXISTS `dc_player_seen_features`;
DROP TABLE IF EXISTS `dc_welcome_whats_new`;

-- =============================================================================
-- Player Welcome Tracking
-- =============================================================================
-- Tracks when players dismissed the welcome screen
-- Used to determine if we should auto-show on subsequent logins

CREATE TABLE IF NOT EXISTS `dc_player_welcome` (
    `guid` INT UNSIGNED NOT NULL COMMENT 'Character GUID',
    `account_id` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Account ID for account-wide tracking',
    `dismissed_at` DATETIME DEFAULT NULL COMMENT 'When welcome was dismissed',
    `first_login_at` DATETIME DEFAULT NULL COMMENT 'First character login timestamp',
    `last_version_shown` VARCHAR(20) DEFAULT NULL COMMENT 'Last addon version shown',
    `show_on_login` TINYINT(1) NOT NULL DEFAULT 1 COMMENT 'Whether to show welcome on login',
    PRIMARY KEY (`guid`),
    KEY `idx_account` (`account_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Tracks player welcome screen interactions';

-- =============================================================================
-- Feature Introduction Tracking
-- =============================================================================
-- Tracks which feature introductions a player has seen
-- Used for progressive disclosure system

CREATE TABLE IF NOT EXISTS `dc_player_seen_features` (
    `guid` INT UNSIGNED NOT NULL COMMENT 'Character GUID',
    `feature` VARCHAR(50) NOT NULL COMMENT 'Feature identifier (hotspots, prestige, mythicplus, etc.)',
    `seen_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'When feature intro was shown',
    `dismissed` TINYINT(1) NOT NULL DEFAULT 0 COMMENT 'Whether user explicitly dismissed',
    PRIMARY KEY (`guid`, `feature`),
    KEY `idx_feature` (`feature`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Tracks which feature intros players have seen';

-- =============================================================================
-- What's New Content (Optional - for dynamic updates)
-- =============================================================================
-- Allows admins to add "What's New" entries without addon updates

CREATE TABLE IF NOT EXISTS `dc_welcome_whats_new` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `version` VARCHAR(20) NOT NULL COMMENT 'Server/addon version this applies to',
    `title` VARCHAR(100) NOT NULL COMMENT 'Entry title',
    `content` TEXT NOT NULL COMMENT 'Entry content (supports color codes)',
    `icon` VARCHAR(100) DEFAULT NULL COMMENT 'Icon path (Interface\\Icons\\...)',
    `category` ENUM('feature', 'bugfix', 'balance', 'event', 'other') DEFAULT 'feature',
    `priority` INT NOT NULL DEFAULT 0 COMMENT 'Display order (higher = first)',
    `active` TINYINT(1) NOT NULL DEFAULT 1 COMMENT 'Whether to show this entry',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `expires_at` DATETIME DEFAULT NULL COMMENT 'Optional expiration date',
    PRIMARY KEY (`id`),
    KEY `idx_version` (`version`),
    KEY `idx_active_priority` (`active`, `priority` DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Dynamic What''s New content';

-- =============================================================================
-- Sample Data
-- =============================================================================

-- Insert default What's New entries
INSERT INTO `dc_welcome_whats_new` (`version`, `title`, `content`, `icon`, `category`, `priority`) VALUES
('1.0.0', 'Welcome to DarkChaos-255!', 'Your adventure begins on our custom WotLK server. Explore unique features including Mythic+ dungeons, the Prestige system, dynamic Hotspots, and much more!', 'Interface\\Icons\\Achievement_General', 'feature', 100),
('1.0.0', 'Mythic+ Dungeons', 'Challenge yourself with scaling dungeon difficulty! Collect keystones, beat the timer, and earn powerful rewards.', 'Interface\\Icons\\Achievement_challengemode_gold', 'feature', 90),
('1.0.0', 'Prestige System', 'At level 80, reset your character for permanent account-wide bonuses. Each prestige level makes ALL your characters stronger!', 'Interface\\Icons\\Achievement_level_80', 'feature', 85),
('1.0.0', 'Dynamic Hotspots', 'Rotating world zones with bonus XP, increased drop rates, and special events. Use /hotspot to find active zones!', 'Interface\\Icons\\INV_Misc_Map01', 'feature', 80),
('1.0.0', 'Item Upgrades', 'Enhance your gear beyond normal item levels! Earn upgrade tokens from M+ and raids.', 'Interface\\Icons\\INV_Enchant_VoidSphere', 'feature', 75),
('1.0.0', 'AOE Looting', 'Loot multiple corpses at once! Configure your preferences with /aoe or in the settings panel.', 'Interface\\Icons\\INV_Misc_Bag_09', 'feature', 70);

-- =============================================================================
-- Feature List Reference
-- =============================================================================
-- Standard feature identifiers for dc_player_seen_features:
-- 
-- 'welcome'          - Main welcome screen
-- 'getting_started'  - Getting started guide
-- 'features_overview'- Server features overview
-- 'hotspots'         - Hotspot system introduction (level 10)
-- 'prestige_preview' - Prestige system preview (level 20)
-- 'mythicplus'       - Mythic+ introduction (level 80)
-- 'prestige_full'    - Full prestige guide (level 80)
-- 'item_upgrade'     - Item upgrade introduction (level 80)
-- 'seasons'          - Seasonal content introduction
-- 'aoe_loot'         - AOE loot configuration
-- 'daily_login'      - Daily login rewards (future)
-- 'faq'              - FAQ section
-- 'community'        - Discord/website links
