-- Create and refresh shared DC-Welcome content tables in world DB.
-- Per-player welcome state remains in acore_chars (`dc_player_welcome`, `dc_player_seen_features`).
-- NOTE: If you previously stored custom FAQ or What's New rows in acore_chars,
-- move them manually before dropping the old tables there.

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Dynamic FAQ content for DC-Welcome';

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Dynamic What''s New content for DC-Welcome';

DELETE FROM `dc_welcome_faq`
WHERE `question` IN (
    'What makes DarkChaos-255 different from other servers?',
    'Is this server pay-to-win?',
    'What is the current max level?',
    'How do I get buffs?',
    'How do I navigate the world?',
    'Where do I find all DarkChaos addons?',
    'How do I get my first keystone?',
    'What are affixes?',
    'How does the timer work?',
    'Can I do M+ solo?',
    'How do I find groups for Mythic+?',
    'What is the Prestige system?',
    'What bonuses does Prestige give?',
    'Do I lose my gear when I prestige?',
    'Is there a max Prestige level?',
    'What is the Prestige alt bonus?',
    'How do Hotspots work?',
    'How do Item Upgrades work?',
    'What custom dungeons are available?',
    'What is the Hinterland Battleground?',
    'How does AOE Looting work?',
    'How do I get Tier 11 gear?',
    'How do I get Tier 12 gear?',
    'What does DC-QOS do?',
    'How do I browse mounts, pets, toys, and appearances?',
    'How do I join the Discord?',
    'Where is the source code?',
    'How do I report a bug?',
    'Where can I find a guild?',
    'How do I become a tester/helper?',
    'Where can I find current guides and setup notes?'
);

INSERT INTO `dc_welcome_faq` (`category`, `question`, `answer`, `priority`) VALUES
('general', 'What makes DarkChaos-255 different from other servers?', 'DarkChaos-255 uses bracketed progression toward a long-term level 255 plan, while combining Mythic+, challenge modes, custom dungeon tiers, and a full client addon suite for long-term play.', 100),
('general', 'Is this server pay-to-win?', 'No. All gear and power progression can be achieved through gameplay. Our shop offers cosmetics and convenience items only. Donate to support the server, not to gain advantage.', 95),
('general', 'What is the current max level?', 'The current live max level is 80. DarkChaos progresses in brackets, with future caps planned for 100, 130, 160, 200, and eventually 255.', 90),
('general', 'How do I navigate the world?', 'Use the server teleporter network and the DC-Mapupgrades addon for hotspots, world-content markers, and navigation help. You can also use /hotspot for the current bonus zones.', 85),
('general', 'Where do I find all DarkChaos addons?', 'Open the Addons tab in DC-Welcome or type /dcaddons. From there you can launch DC-MythicPlus, DC-QOS, DC-Collection, DC-InfoBar, DC-Mapupgrades, and the rest of the client suite.', 80),
('mythicplus', 'How do I get my first keystone?', 'Complete any heroic dungeon at level 80. A level 2 keystone will appear in your bags. Higher keys drop from completing M+ runs within the timer.', 100),
('mythicplus', 'What are affixes?', 'Affixes are modifiers that add difficulty to M+ runs. They rotate weekly. Examples: Fortified (stronger trash), Tyrannical (stronger bosses), Bolstering (enemies buff nearby mobs on death).', 95),
('mythicplus', 'How does the timer work?', 'Each dungeon has a par time. Beat it to upgrade your key (+1 level, or +2/+3 for very fast runs). Fail and your key depletes (lowered by 1 level).', 90),
('mythicplus', 'How do I find groups for Mythic+?', 'Use the DC-MythicPlus group finder with /dcgf, or open the Mythic+ suite from the Addons tab. The addon handles group browsing, activity tools, and related M+ UI features.', 85),
('prestige', 'What is the Prestige system?', 'Prestige is planned for the future 255 bracket. Once that bracket is live and characters can reach it, prestige will reset a capped character back to level 1 for long-term progression rewards.', 100),
('prestige', 'What bonuses does Prestige give?', 'The planned prestige setup grants +1% to all stats per prestige level and can unlock prestige-related titles or rewards. The separate alt bonus system is also tied to later max-level progression once higher brackets are available.', 95),
('prestige', 'Do I lose my gear when I prestige?', 'The planned prestige flow is built to preserve your progress where possible, with the exact retention rules controlled by the live server setup when the 255 bracket opens.', 90),
('prestige', 'Is there a max Prestige level?', 'The planned prestige cap is 10 by default. Once the 255 bracket is live, .prestige info can be used to inspect the active prestige settings and your current status.', 85),
('prestige', 'What is the Prestige alt bonus?', 'The planned alt bonus grants +5% XP per max-level character, up to +25%. It becomes relevant once later progression brackets and the eventual 255 cap are live.', 80),
('systems', 'How do Hotspots work?', 'Hotspots rotate on a timer and provide bonus XP plus world-map support through DC-Mapupgrades. Use /hotspot for the active zones and /dchotspot or /dcmap for the client map tools.', 100),
('systems', 'How do Item Upgrades work?', 'Open DC-ItemUpgrade from the Addons tab or use /dcu. Upgrade tokens come from progression content, and the addon also supports heirloom upgrades through its secondary interface.', 95),
('systems', 'What custom dungeons are available?', 'DarkChaos progression includes later custom dungeon brackets at level 100 (The Nexus, The Oculus), 130 (Gundrak, Ahn''kahet), and 160 (Auchenai Crypts, Mana-Tombs, Sethekk Halls, Shadow Labyrinth). Those brackets open as progression advances beyond the current level-80 cap.', 90),
('systems', 'What is the Hinterland Battleground?', 'Hinterland BG is DarkChaos''s open-world PvP battleground with a dedicated addon, queue HUD, live stats, and seasonal support. Use the Addons tab to open the HLBG UI when the addon is loaded.', 85),
('systems', 'How does AOE Looting work?', 'Loot one corpse to collect nearby corpses in range. Configure it with /aoeloot or through DC-AOESettings for quality filters, auto-skinning, and related behavior.', 80),
('systems', 'What does DC-QOS do?', 'DC-QOS packages tooltip upgrades, automation helpers, cooldown text, bag and vendor improvements, mail helpers, nameplates, and other quality-of-life features under one addon.', 75),
('systems', 'How do I browse mounts, pets, toys, and appearances?', 'Open DC-Collection with /dcc or from the Addons tab. It brings together collections, titles, heirlooms, toys, and wardrobe-style appearance browsing in one interface.', 70),
('community', 'How do I join the Discord?', 'Use /discord in-game or copy the Discord link from the Community tab in DC-Welcome.', 100),
('community', 'Where is the source code?', 'The current repository, changelog history, and project files live at https://github.com/darkmord1991/DarkChaos-255', 95),
('community', 'How do I report a bug?', 'Use the GitHub issue tracker or the Discord bug-report channels. Include what happened, where it happened, and how to reproduce it.', 90),
('community', 'Where can I find current guides and setup notes?', 'Check the README and the Information folder in the GitHub repository. DC-Welcome''s Community tab also keeps the latest project links together in one place.', 85);

DELETE FROM `dc_welcome_whats_new`
WHERE `title` IN (
    'Welcome to DarkChaos-255!',
    'Mythic+ Dungeons',
    'Prestige System',
    'Dynamic Hotspots',
    'Item Upgrades',
    'AOE Looting',
    'Welcome Hub Refresh',
    'Mythic+ Suite',
    'Bracket Progression',
    'Prestige at 255',
    'Maps, Collections, and QoL',
    'Season Tracking',
    'AOE Loot and UI Cleanup'
);

INSERT INTO `dc_welcome_whats_new` (`version`, `title`, `content`, `icon`, `category`, `priority`) VALUES
('2.0.0', 'Welcome Hub Refresh', 'DC-Welcome now acts as a landing hub for onboarding, FAQ, addon launching, progression tracking, and season tools across the DarkChaos-255 client suite.', 'Interface\\Icons\\Achievement_General', 'feature', 100),
('2.0.0', 'Bracket Progression', 'The live progression cap is currently level 80. Future brackets are planned for 100, 130, 160, 200, and eventually 255 as the server progression path expands.', 'Interface\\Icons\\Ability_DualWield', 'feature', 97),
('2.0.0', 'Mythic+ Suite', 'Mythic+ now highlights the full suite: keystones, affixes, group finder, Great Vault progress, and leaderboard support. Use /dcm and /dcgf to access the tools.', 'Interface\\Icons\\Achievement_challengemode_gold', 'feature', 95),
('2.0.0', 'Prestige at 255', 'Prestige is reserved for the future 255 bracket. Once that cap is live, it will provide reset-based long-term progression plus related bonus systems.', 'Interface\\Icons\\Achievement_level_80', 'feature', 90),
('2.0.0', 'Maps, Collections, and QoL', 'DC-Mapupgrades, DC-Collection, DC-InfoBar, and DC-QOS now form the current utility stack for world navigation, collections, server info, and quality-of-life features.', 'Interface\\Icons\\INV_Misc_Map01', 'feature', 85),
('2.0.0', 'Season Tracking', 'Season points, rank, weekly token progress, and tracker controls are surfaced directly in DC-Welcome. Use /seasonal to toggle the tracker and DC-Leaderboards for standings.', 'Interface\\Icons\\Achievement_Zone_Hyjal', 'feature', 80),
('2.0.0', 'AOE Loot and UI Cleanup', 'AOE looting remains configurable through /aoeloot and /dcaoe, while older tooltip-specific references have been consolidated into the broader DC-QOS addon.', 'Interface\\Icons\\INV_Misc_Bag_09', 'other', 75);