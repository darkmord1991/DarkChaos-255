-- Timbermaw Hold (map 819) -- register as a raid instance.
-- Map.dbc row 819 is InstanceType=2 (raid); without an instance_template row the client is
-- rejected on entry with CANNOT_ENTER_UNINSTANCED_DUNGEON.
-- allowMount 0: the whole raid is WMO interior, mounting would clip through the geometry.
DELETE FROM `instance_template` WHERE `map` = 819;
INSERT INTO `instance_template` (`map`, `parent`, `script`, `allowMount`) VALUES
    (819, 0, '', 0);
