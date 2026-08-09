-- Crescent Grove (map 823) -- walk-in entrance.
--
-- The trigger BOX lives in AreaTrigger.dbc id 607006 (added to Custom/CSV DBC/AreaTrigger.csv
-- by Custom/TurtleDungeons/add_turtle_dungeon_dbc_rows.py, already compiled and deployed to
-- patch-4 and the three WarcraftXLHost candidate dirs). It must also reach the SERVER's
-- data/dbc before this row does anything.
--
-- There is deliberately NO exit trigger. On both earlier imports the exit box ended up centred
-- on its own arrival point, so arriving put the player inside the trigger that sends them back
-- out -- an inescapable loop that had to be repaired afterwards in both cases. The way out here
-- is the Crescent Grove Warden (3999006), from _shared/dungeon_entrance_npcs.sql.
--
-- Box is 8x8x10 at the entrance, which is where the source pack's own entrance trigger (its id
-- 5004/5010) sat on map 1. The x/y are Turtle's; only the Z is ours, because map 750's Ashenvale
-- is CATA terrain and the ground there is 14 yd above where vanilla Ashenvale puts it.
DELETE FROM `areatrigger_teleport` WHERE `ID` = 607006;
INSERT INTO `areatrigger_teleport` (`ID`, `Name`, `target_map`, `target_position_x`, `target_position_y`, `target_position_z`, `target_orientation`) VALUES
    (607006, 'Crescent Grove (Entrance)', 823, 585.6, 96.7, 276.92, 5.498);
