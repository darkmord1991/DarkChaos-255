-- Timbermaw Hold (map 819) -- level gate.
--
-- `dungeon_access_template`.`id` is tinyint unsigned (max 255); live max is 145, so 146 is free.
-- Map 819 has a single MapDifficulty row (difficulty 0, RAID_DIFFICULTY_20PLAYER), so one row.
--
-- min_level 110 places it above the Winterspring band (104-115) and below the Hyjal cap,
-- matching where Timbermaw Hold physically sits on map 750 (Felwood/Winterspring border).
-- This is a TUNING CHOICE, not a constraint from the data -- change min_level freely.
DELETE FROM `dungeon_access_template` WHERE `map_id` = 819;
INSERT INTO `dungeon_access_template` (`id`, `map_id`, `difficulty`, `min_level`, `max_level`, `min_avg_item_level`, `comment`) VALUES
    (146, 819, 0, 110, 0, 0, 'Timbermaw Hold - 20man');
