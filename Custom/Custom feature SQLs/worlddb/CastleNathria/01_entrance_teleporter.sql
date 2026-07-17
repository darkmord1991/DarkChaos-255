-- Castle Nathria (map 2296) — ENTRANCE: DC teleporter menu entry + `.tele` command.
--
-- Placed under teleporter menu 800 "Custom Dungeons" (GM-gated via that parent's security_level 1),
-- right next to Blackwing Descent (id 801). That's the correct home while the raid is a
-- walkable-but-content-incomplete downport — testers reach it, players don't yet. Move it to a
-- player-facing menu (e.g. a "Custom Raids" parent) once bosses/loot are in.
--
-- Landing coord (-1865.94, 6721.381, 4319.212) is the confirmed-walkable interior test point;
-- refine to the actual entrance foyer when known.
--
-- Apply against acore_world, then reload: `.reload game_tele` for the command; the dc_teleporter
-- menu is read at worldserver startup, so restart (or use the module's reload if present) for it.

-- dc_teleporter menu entry (type 2 = destination; faction -1 = both; security_level 0, gated by parent 800)
DELETE FROM `dc_teleporter` WHERE `id` = 802;
INSERT INTO `dc_teleporter` (`id`,`parent`,`type`,`faction`,`security_level`,`comment`,`icon`,`name`,`map`,`x`,`y`,`z`,`o`) VALUES
    (802, 800, 2, -1, 0, 'Castle Nathria raid downport (map 2296)', 2, 'Castle Nathria', 2296, -1865.94, 6721.381, 4319.212, 1.6);

-- `.tele CastleNathria`
DELETE FROM `game_tele` WHERE `name` = 'CastleNathria';
INSERT INTO `game_tele` (`id`,`position_x`,`position_y`,`position_z`,`orientation`,`map`,`name`) VALUES
    (10620, -1865.94, 6721.381, 4319.212, 1.6, 2296, 'CastleNathria');
