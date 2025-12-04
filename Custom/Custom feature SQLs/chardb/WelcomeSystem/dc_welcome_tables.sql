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
-- FAQ Content (Optional - for dynamic updates)
-- =============================================================================
-- Allows admins to add/update FAQ entries without addon updates

DROP TABLE IF EXISTS `dc_welcome_faq`;

CREATE TABLE IF NOT EXISTS `dc_welcome_faq` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `category` VARCHAR(30) NOT NULL DEFAULT 'general' COMMENT 'Category: general, mythicplus, prestige, systems, community',
    `question` VARCHAR(255) NOT NULL COMMENT 'The FAQ question',
    `answer` TEXT NOT NULL COMMENT 'The answer (supports color codes)',
    `priority` INT NOT NULL DEFAULT 0 COMMENT 'Display order within category (higher = first)',
    `active` TINYINT(1) NOT NULL DEFAULT 1 COMMENT 'Whether to show this entry',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_category` (`category`),
    KEY `idx_active_priority` (`active`, `category`, `priority` DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Dynamic FAQ content';

-- Insert default FAQ entries (mirrors client-side defaults)
INSERT INTO `dc_welcome_faq` (`category`, `question`, `answer`, `priority`) VALUES
-- General
('general', 'What makes DarkChaos-255 different from other servers?', 'DarkChaos-255 is a custom WotLK server featuring Mythic+ dungeons, a Prestige system, dynamic Hotspots, item upgrades, and seasonal content. We focus on end-game progression with multiple paths to gear up.', 100),
('general', 'Is this server pay-to-win?', 'No. All gear and power progression can be achieved through gameplay. Our shop offers cosmetics and convenience items only.', 95),
('general', 'What is the current max level?', 'The current Max Level is set to 80! It will be extended to the next progression step soon.', 90),
('general', 'How do I get buffs?', 'Use .buff to get some buffs anywhere you are!', 85),
('general', 'How do I navigate the world?', 'You can use a mobile teleporter with your pet or use the ones standing around everywhere. Use the teleporters to navigate to the correct leveling zone location.', 80),
-- Mythic+
('mythicplus', 'How do I get my first keystone?', 'Complete any heroic dungeon at level 80. A level 2 keystone will appear in your bags. Higher keys drop from completing M+ runs within the timer.', 100),
('mythicplus', 'What are affixes?', 'Affixes are modifiers that add difficulty to M+ runs. They rotate weekly. Examples: Fortified (stronger trash), Tyrannical (stronger bosses), Bolstering (enemies buff nearby mobs on death).', 95),
('mythicplus', 'How does the timer work?', 'Each dungeon has a par time. Beat it to upgrade your key (+1 level, or +2/+3 for very fast runs). Fail and your key depletes (lowered by 1 level).', 90),
('mythicplus', 'Can I do M+ solo?', 'Technically yes, but it is designed for groups. Mobs scale to 5 players. Use /lfg or the Group Finder NPC to find parties.', 85),
-- Prestige
('prestige', 'What is the Prestige system?', 'At level 80, you can prestige to reset your character to level 1. In exchange, you gain permanent account-wide bonuses that apply to ALL your characters.', 100),
('prestige', 'What bonuses does Prestige give?', 'Each prestige level grants: +5% XP rate, +3% gold find, +2% drop rate, and unlocks cosmetic rewards like titles and mounts.', 95),
('prestige', 'Do I lose my gear when I prestige?', 'Your gear is stored in a special Prestige Vault accessible at level 80. You do not lose items, but you cannot equip high-level gear until you level up again.', 90),
('prestige', 'Is there a max Prestige level?', 'Currently Prestige 10 is the maximum. Each level takes progressively more effort but gives better rewards.', 85),
-- Systems
('systems', 'How do Hotspots work?', 'Hotspots are zones that rotate every few hours with active bonuses. Check /hotspot to see current zones. Bonuses include +50% XP, +25% drops, rare mob spawns, and world events.', 100),
('systems', 'How do Item Upgrades work?', 'Visit the Upgrade NPC in Dalaran with upgrade tokens. Each upgrade increases item level by 6. Tokens drop from M+ and raids, with higher content dropping better tokens.', 95),
('systems', 'What custom dungeons are available?', 'We have custom dungeons: The Nexus (Lv100), The Oculus (Lv100), Gundrak (Lv130), AhnCahet (Lv130), Auchenai Crypts (Lv160), Mana Tombs (Lv160), Sethekk Halls (Lv160), Shadow Labyrinth (Lv160). More to come!', 90),
('systems', 'What is the Hinterland Battleground?', 'The Hinterland Battleground is an open battlefield for the current set maxlevel, with special scripts, quests, events and more! Access via teleporters!', 85),
('systems', 'How does AOE Looting work?', 'Kill enemies, then loot one corpse to collect from all nearby corpses. Configure settings with /aoe or in DC-Central addon: quality filter, auto-skin, loot range.', 80),
('systems', 'How do I get Tier 11 gear?', 'For T11 you need 2500 tokens for each Tier 11 item.', 75),
('systems', 'How do I get Tier 12 gear?', 'For T12 you need 7500 tokens for each Tier 12 item.', 70),
-- Community
('community', 'How do I join the Discord?', 'Use /discord in-game or visit: discord.gg/pNddMEMbb2', 100),
('community', 'Where is the source code?', 'The sourcecode and full changelog can be found at https://github.com/darkmord1991/DarkChaos-255', 95),
('community', 'How do I report a bug?', 'Use /bug in-game or post in #bug-reports on Discord. Include: what happened, where you were, and steps to reproduce.', 90),
('community', 'Where can I find a guild?', 'Check #guild-recruitment on Discord, or use /gf (Guild Finder) in-game. Many guilds recruit for M+ and raids.', 85),
('community', 'How do I become a tester/helper?', 'Active community members may be invited to help test new features. Participate in Discord, report bugs constructively, and help other players.', 80);

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
