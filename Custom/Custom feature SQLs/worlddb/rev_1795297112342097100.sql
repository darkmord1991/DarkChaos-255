-- DarkChaos: help text for the per-character XP rate commands
-- Used by: src/server/scripts/DC/Progression/dc_xp_rate.cpp (both SEC_PLAYER, so security 0)
DELETE FROM `command` WHERE `name` IN ('dc xp', 'dc xp bonus');
INSERT INTO `command` (`name`, `security`, `help`) VALUES
('dc xp', 0, 'Syntax: .dc xp [$rate|reset]\r\nShows or sets your personal XP rate, a multiplier of the realm rate (for example 0.5). A rate of 0 turns experience off when the realm allows it; reset returns to the realm rate.'),
('dc xp bonus', 0, 'Syntax: .dc xp bonus [on|off]\r\nTurns DC bonus XP (prestige alt bonus, hotspots, prestige talents) on or off for this character. Without an argument it toggles. Rested XP is not affected.');
