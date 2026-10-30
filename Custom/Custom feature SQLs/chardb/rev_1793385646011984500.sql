-- Giant Isles invasion: move its world states off ids the core owns (2026-10-30). 20001 is the arena point
-- distribution and 20002 the weekly quest reset (WorldStateDefines.h); the invasion wrote wave and kill numbers
-- into both and zeroed them on every boot. Both stay as they are here: a zero makes the core recompute them.
-- The foothold restarts at 1 instead of carrying 3 over: those defeats came from a warlord nobody could attack.
DELETE FROM `worldstates` WHERE `entry` = 14050003;
INSERT INTO `worldstates` (`entry`, `value`, `comment`)
SELECT 14050003, `value`, 'Giant Isles invasion: last end' FROM `worldstates` WHERE `entry` = 20010;

DELETE FROM `worldstates` WHERE `entry` = 14050004;
INSERT INTO `worldstates` (`entry`, `value`, `comment`) VALUES
(14050004, 1, 'Giant Isles invasion: Zandalari foothold');

DELETE FROM `worldstates` WHERE `entry` IN (20000, 20010, 20011);
