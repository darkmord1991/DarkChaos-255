-- dc_teleporter: add the three downported custom maps as teleport destinations under the existing
-- "Custom Locations" menu (id 500). Columns (see dc_teleporter.cpp LoadTeleporterOptions):
--   id, parent, type, faction, security_level, icon, name, map, x, y, z, o
--   type    2 = TELEPORT (a real destination; 1 = submenu, 3 = guildhouse)
--   faction -1 = both factions (0 = Alliance only, 1 = Horde only)
--   security_level 0 = visible to all players
--   icon    2 = taxi/teleport icon (matches the other teleport rows)
-- All three coords are exact in-game [Teleport] positions captured by the user (.gps, GroundZ confirmed):
-- Deepholm = Temple of Earth hub, Undermine, Pandaria = The Summer Fields (Vale of Eternal Blossoms).
-- After running: in-game ".dc teleporter reload" (or restart worldserver) to load without a full restart.

DELETE FROM `dc_teleporter` WHERE `id` IN (505, 506, 507);
INSERT INTO `dc_teleporter`
    (`id`, `parent`, `type`, `faction`, `security_level`, `icon`, `name`,      `map`, `x`,         `y`,         `z`,         `o`) VALUES
    (505,  500,      2,      -1,        0,                2,      'Deepholm',   646,   937.27136,   508.77054,   -49.330883,  0.2042055),
    (506,  500,      2,      -1,        0,                2,      'Undermine',  2706,  85.785385,   251.49202,   -15.268978,  4.724367),
    (507,  500,      2,      -1,        0,                2,      'Pandaria',   870,   864.0239,    840.432,     442.58887,   0.2246241);
