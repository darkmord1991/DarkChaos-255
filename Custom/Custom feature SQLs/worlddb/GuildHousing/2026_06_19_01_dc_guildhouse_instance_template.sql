-- Dark Chaos Guild Housing - Instanced map registration (Phase B migration)
-- Map 1409 ("guildhousedala") is promoted from a continent (InstanceType 0) to a
-- dungeon-type instance (InstanceType 1, see Map.dbc / MapDifficulty.dbc). Any
-- InstanceType>0 map requires an `instance_template` row, otherwise entry is
-- rejected with CANNOT_ENTER_UNINSTANCED_DUNGEON (MapMgr::PlayerCannotEnter).
-- One shared instance is minted per guild at teleport time; terrain (map/vmap/
-- mmap for 1409) stays a single on-disk copy shared across all live instances.
-- `script` binds the InstanceMapScript registered as "instance_guildhouse"
-- (dc_guildhouse_instance.cpp): auto raid-grouping now, per-guild dynamic
-- decoration spawning in Phase 4.

DELETE FROM `instance_template` WHERE `map` = 1409;
INSERT INTO `instance_template` (`map`, `parent`, `script`, `allowMount`) VALUES
(1409, 0, 'instance_guildhouse', 1);
