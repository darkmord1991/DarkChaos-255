-- Crescent Grove (map 823) -- level gate.
--
-- `dungeon_access_template`.`id` is tinyint unsigned (max 255); live max is 149, so 150 is free.
-- Map 823 has a single MapDifficulty row (9344, difficulty 0), so one row here.
--
-- min_level 88 puts it at the bottom of the Ashenvale band (88-98), which is where the entrance
-- physically is on map 750. The source pack rates the zone at ExplorationLevel 30, i.e. it was
-- authored as a low-level dungeon on a 1-60 server; on a 255 server that number carries no
-- meaning, so this is a TUNING CHOICE -- change min_level freely once the place has content.
DELETE FROM `dungeon_access_template` WHERE `map_id` = 823;
INSERT INTO `dungeon_access_template` (`id`, `map_id`, `difficulty`, `min_level`, `max_level`, `min_avg_item_level`, `comment`) VALUES
    (150, 823, 0, 88, 0, 0, 'Crescent Grove - 5man');
