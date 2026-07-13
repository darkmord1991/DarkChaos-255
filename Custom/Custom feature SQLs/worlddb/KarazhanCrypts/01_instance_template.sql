-- Karazhan Crypts (map 2875) -- register as a dungeon instance.
-- InstanceType=1 requires an instance_template row or the client is rejected with
-- CANNOT_ENTER_UNINSTANCED_DUNGEON on entry.
DELETE FROM `instance_template` WHERE `map` = 2875;
INSERT INTO `instance_template` (`map`, `parent`, `script`, `allowMount`) VALUES
    (2875, 0, '', 0);
