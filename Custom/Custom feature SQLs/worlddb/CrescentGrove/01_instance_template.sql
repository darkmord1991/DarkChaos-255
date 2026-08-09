-- Crescent Grove (map 823) -- register as a 5-man dungeon instance.
--
-- Map.dbc row 823 is InstanceType=1 (dungeon); without an instance_template row the client is
-- rejected on entry with CANNOT_ENTER_UNINSTANCED_DUNGEON.
--
-- allowMount 1: unlike Timbermaw, this map is real outdoor terrain (16 ADT tiles, only 11 WMOs
-- and those are open elf ruins), so mounts have somewhere to go and nothing to clip through.
DELETE FROM `instance_template` WHERE `map` = 823;
INSERT INTO `instance_template` (`map`, `parent`, `script`, `allowMount`) VALUES
    (823, 0, '', 1);
