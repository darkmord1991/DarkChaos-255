-- ============================================================
-- DC Auto-Quest Popups (retail-style quest flow) - world DB
-- ============================================================
-- Consumed by src/server/scripts/DC/AddonExtension/dc_addon_questflow.cpp
-- (module QPOP). Loaded once at worldserver startup.
--
-- dc_quest_auto_offer: entering the zone (optionally narrowed to one area)
-- pushes a "quest available" popup the player can accept remotely.
-- dc_quest_auto_complete: when the quest's objectives complete, a "ready to
-- turn in" popup allows remote turn-in (quests with QUEST_FLAGS_AUTOCOMPLETE
-- 0x10000 get this behavior automatically without a row here).

CREATE TABLE IF NOT EXISTS `dc_quest_auto_offer` (
    `quest_id` INT UNSIGNED NOT NULL,
    `zone_id` INT UNSIGNED NOT NULL COMMENT 'AreaTable zone id the offer fires in',
    `area_id` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0 = whole zone, else specific sub-area',
    `min_level` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `max_level` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0 = no cap',
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `comment` VARCHAR(255) NOT NULL DEFAULT '',
    PRIMARY KEY (`quest_id`, `zone_id`, `area_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='DC auto-quest offer popups (QPOP)';

CREATE TABLE IF NOT EXISTS `dc_quest_auto_complete` (
    `quest_id` INT UNSIGNED NOT NULL,
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `comment` VARCHAR(255) NOT NULL DEFAULT '',
    PRIMARY KEY (`quest_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='DC remote turn-in eligible quests (QPOP)';

-- Azshara Crater (zone 268, the 1-80 leveling zone): auto-offer the welcome quest
-- on zone entry. The per-bracket chain starters are included disabled - enable any
-- you want pushed automatically as players level through the zone.
DELETE FROM `dc_quest_auto_offer` WHERE `zone_id` = 268;
INSERT INTO `dc_quest_auto_offer` (`quest_id`, `zone_id`, `area_id`, `min_level`, `max_level`, `enabled`, `comment`) VALUES
(300100, 268, 0, 1, 0, 1, 'Azshara Crater - Welcome to Crater (zone intro)'),
(300200, 268, 0, 10, 0, 0, 'Azshara Crater - Haunted Grounds (10+ bracket starter)'),
(300300, 268, 0, 18, 0, 0, 'Azshara Crater - Proving Strength (18+ bracket starter)');

-- Example rows (disabled; enable and adjust to taste):
-- DELETE FROM `dc_quest_auto_offer` WHERE `quest_id` = 25316;
-- INSERT INTO `dc_quest_auto_offer` (`quest_id`, `zone_id`, `area_id`, `min_level`, `max_level`, `enabled`, `comment`)
-- VALUES (25316, 4923, 0, 80, 0, 0, 'Mount Hyjal intro - offered on zone entry');
