-- Naxxramas (map 2921) -- register as a dungeon instance so it can be entered at all.
DELETE FROM `instance_template` WHERE `map` = 2921;
INSERT INTO `instance_template` (`map`, `parent`, `script`, `allowMount`) VALUES
    (2921, 0, '', 0);
