-- DarkChaos QoL: scripted questgiver overhead icon overrides
-- Database: acore_world
-- Opt-in table for scripted questgivers that should promote recurring
-- available quests to the blue repeatable overhead icon.

CREATE TABLE IF NOT EXISTS `dc_questgiver_status_overrides` (
    `creature_entry` INT UNSIGNED NOT NULL COMMENT 'creature_template entry using a CreatureScript GetDialogStatus override',
    `enabled` TINYINT(1) NOT NULL DEFAULT 1 COMMENT 'Whether the override is active for this creature entry',
    `promote_daily` TINYINT(1) NOT NULL DEFAULT 1 COMMENT 'Promote available daily quests to repeatable available status',
    `promote_weekly` TINYINT(1) NOT NULL DEFAULT 0 COMMENT 'Promote available weekly quests to repeatable available status',
    `promote_monthly` TINYINT(1) NOT NULL DEFAULT 0 COMMENT 'Promote available monthly quests to repeatable available status',
    `comment` VARCHAR(255) DEFAULT NULL COMMENT 'Freeform note for why this creature is opted in',
    PRIMARY KEY (`creature_entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Opt-in questgiver dialog status overrides for scripted NPCs';

INSERT INTO `dc_questgiver_status_overrides`
    (`creature_entry`, `enabled`, `promote_daily`, `promote_weekly`, `promote_monthly`, `comment`)
VALUES
    (900001, 1, 1, 1, 0, 'HLBG battlemaster: show blue overhead icon for daily and weekly recurring quests'),
    (700100, 1, 1, 1, 0, 'Universal dungeon quest master: show blue overhead icon for daily and weekly recurring quests')
ON DUPLICATE KEY UPDATE
    `enabled` = VALUES(`enabled`),
    `promote_daily` = VALUES(`promote_daily`),
    `promote_weekly` = VALUES(`promote_weekly`),
    `promote_monthly` = VALUES(`promote_monthly`),
    `comment` = VALUES(`comment`);