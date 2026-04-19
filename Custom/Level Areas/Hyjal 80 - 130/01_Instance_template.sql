-- Hyjal Frontier (map 1410) - instance_template registration
-- Continent-style open world map (not a raid / not a dungeon).
-- parent=0, script='' (no instance script), allowMount=1.

DELETE FROM `instance_template` WHERE `map` = 1410;
INSERT INTO `instance_template` (`map`, `parent`, `script`, `allowMount`) VALUES
(1410, 0, '', 1);
