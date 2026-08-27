-- Allied races: starting action bars cloned from the faction's base race.
DELETE FROM `playercreateinfo_action` WHERE `race` IN (24, 25, 26);
INSERT INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`)
SELECT 24, `class`, `button`, `action` FROM `playercreateinfo_action` WHERE `race` = 2;
INSERT INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`)
SELECT 25, `class`, `button`, `action` FROM `playercreateinfo_action` WHERE `race` = 2;
INSERT INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`)
SELECT 26, `class`, `button`, `action` FROM `playercreateinfo_action` WHERE `race` = 1;
