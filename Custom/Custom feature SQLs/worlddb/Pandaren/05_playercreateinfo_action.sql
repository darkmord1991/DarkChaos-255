-- Pandaren: starting action bars. Race 22 clones human(1), race 23 clones orc(2);
-- classes one donor race lacks are filled from the other (an ARAC world DB may carry
-- all classes on both, in which case the gap-fills insert nothing).
DELETE FROM `playercreateinfo_action` WHERE `race` IN (22, 23);

INSERT INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`)
SELECT 22, `class`, `button`, `action` FROM `playercreateinfo_action` WHERE `race` = 1;
INSERT INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`)
SELECT 22, a.`class`, a.`button`, a.`action` FROM `playercreateinfo_action` a
WHERE a.`race` = 2 AND a.`class` NOT IN
    (SELECT `class` FROM (SELECT DISTINCT `class` FROM `playercreateinfo_action` WHERE `race` = 1) x);

INSERT INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`)
SELECT 23, `class`, `button`, `action` FROM `playercreateinfo_action` WHERE `race` = 2;
INSERT INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`)
SELECT 23, a.`class`, a.`button`, a.`action` FROM `playercreateinfo_action` a
WHERE a.`race` = 1 AND a.`class` NOT IN
    (SELECT `class` FROM (SELECT DISTINCT `class` FROM `playercreateinfo_action` WHERE `race` = 2) x);
