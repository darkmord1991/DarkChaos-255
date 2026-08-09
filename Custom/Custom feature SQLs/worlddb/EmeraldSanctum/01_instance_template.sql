-- Emerald Sanctum (map 824) -- register as a raid instance.
--
-- Map.dbc row 824 is InstanceType=2 (raid); without an instance_template row the client is
-- rejected on entry with CANNOT_ENTER_UNINSTANCED_DUNGEON.
--
-- allowMount 1: this map is 4 tiles of open outdoor terrain with no WMOs at all, so there is
-- nothing for a mount to clip through (unlike Timbermaw, which is entirely WMO interior).
DELETE FROM `instance_template` WHERE `map` = 824;
INSERT INTO `instance_template` (`map`, `parent`, `script`, `allowMount`) VALUES
    (824, 0, '', 1);
