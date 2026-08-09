-- Emerald Sanctum (map 824) -- level gate.
--
-- `dungeon_access_template`.`id` is tinyint unsigned (max 255); 150 goes to Crescent Grove, so
-- 151 is the next free. Map 824 has a single MapDifficulty row (9345, difficulty 0,
-- RAID_DIFFICULTY_20PLAYER, 3-day lockout), so one row here.
--
-- min_level 113 places it at the bottom of the Hyjal Frontier band (113-130), which is where
-- the entrance physically sits on map 750, and one step above Timbermaw's 110. A TUNING
-- CHOICE, not a constraint from the data -- change freely.
DELETE FROM `dungeon_access_template` WHERE `map_id` = 824;
INSERT INTO `dungeon_access_template` (`id`, `map_id`, `difficulty`, `min_level`, `max_level`, `min_avg_item_level`, `comment`) VALUES
    (151, 824, 0, 113, 0, 0, 'Emerald Sanctum - 20man');
