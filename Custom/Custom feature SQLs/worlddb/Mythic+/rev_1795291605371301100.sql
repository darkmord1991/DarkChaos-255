--
-- DC 2026-11-21: boss kit. Extra boss abilities for Heroic, Mythic and Mythic+ cast next to a boss's own script,
-- so stock instance scripts stay untouched (src/server/scripts/DC/BossKit/dc_boss_kit.cpp). The worldserver reads
-- this table at startup (and on `.dca bosskit reload`). An entry without rows behaves exactly as before, and the
-- table ships empty.
--
-- Columns:
--   event           0 timer: first cast after urand(param1, param2) ms of combat
--                   1 health: cast once health is at or below param1 percent (1-100), param2 unused
--                   2 pull: cast when the boss engages, param1/param2 unused
--   repeatMin/Max   after a cast, cast again every urand(repeatMin, repeatMax) ms (0 = once per pull), for every
--                   event. A health row repeats only while health stays at or below param1.
--   target          0 self, 1 victim, 2 random player, 3 random player that is not the tank, 4 farthest player,
--                   5 every player on the threat list (always cast triggered, so use an instant spell).
--                   2-4 fall back to the victim when no player qualifies.
--   triggered       1 = triggered cast: no cast time or cost, and it does not wait for the boss's current cast.
--   minKeystone     0 = any run. Above 0 the row is active only in a running Mythic+ run of at least that level.
--   difficultyMask  bit n = map difficulty n: 1 Normal (10N), 2 Heroic (25N), 4 Mythic (10H), 8 25H. 0 = all.
-- Every row is checked once per pull (difficulty and keystone are read when the boss engages). The kit waits while
-- the boss is stunned, feared, charging or (for untriggered rows) casting, and stops on evade and death.
--
-- Example, kept commented out: Ingvar the Plunderer (23954, Utgarde Keep) enrages at 30% health on Mythic only.
-- DELETE FROM `dc_boss_kit` WHERE `entry` = 23954 AND `id` = 0;
-- INSERT INTO `dc_boss_kit` (`entry`, `id`, `event`, `param1`, `param2`, `repeatMin`, `repeatMax`, `spellId`,
--     `target`, `triggered`, `minKeystone`, `difficultyMask`, `comment`) VALUES
-- (23954, 0, 1, 30, 0, 0, 0, 8599, 0, 1, 0, 4, 'Ingvar the Plunderer - Enrage at 30% (Mythic)');
--
-- Apply to acore_world. A worldserver started before this table exists logs an error and runs without boss kits.
CREATE TABLE IF NOT EXISTS `dc_boss_kit` (
    `entry` INT UNSIGNED NOT NULL COMMENT 'creature_template.entry',
    `id` TINYINT UNSIGNED NOT NULL COMMENT 'row number within the entry',
    `event` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0 timer, 1 health pct, 2 on pull',
    `param1` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'timer: first cast min ms, health: pct',
    `param2` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'timer: first cast max ms',
    `repeatMin` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'ms between casts after the first, 0 = once per pull',
    `repeatMax` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'ms between casts after the first, upper bound',
    `spellId` INT UNSIGNED NOT NULL,
    `target` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '0 self 1 victim 2 random 3 non-tank 4 farthest 5 all',
    `triggered` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '1 = triggered cast',
    `minKeystone` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0 = any, else minimum running Mythic+ keystone level',
    `difficultyMask` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'bit n = map difficulty n, 0 = all',
    `comment` VARCHAR(255) NOT NULL DEFAULT '',
    PRIMARY KEY (`entry`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='DC boss kit: extra boss abilities';

DELETE FROM `command` WHERE `name` = 'dca bosskit reload';
INSERT INTO `command` (`name`, `security`, `help`) VALUES
('dca bosskit reload', 3, 'Syntax: .dca bosskit reload\nReloads dc_boss_kit. Bosses in combat rebuild their timers.');
