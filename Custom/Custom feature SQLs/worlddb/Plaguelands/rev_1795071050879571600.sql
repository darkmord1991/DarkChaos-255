-- DarkChaos map 751: three caster mobs stand in dense camps and flee for help at 15% health, which pulls the
-- camp onto the player. Meter runs 9 + 10 (bots within 3 levels, solo): Vile Fin Oracle 22% / 27% deaths in
-- 27-33 s fights, Stormpike Engineer 42% in 26 s; median mob on 751 at levels 128-150 about 4% in 14 s. The
-- Torn Fin Oracle flees the same way with 2 camp mates within 30 yd and kills 6%; these have 6-7.
-- They keep their spells; only the flee goes. All three entries are DC copies spawned only on map 751.
-- The three rows are kept in dc_backup_20261119_flee (a re-run keeps the first copy). To restore:
--   INSERT INTO `smart_scripts` SELECT * FROM `dc_backup_20261119_flee`;

CREATE TABLE IF NOT EXISTS `dc_backup_20261119_flee` ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
SELECT * FROM `smart_scripts`
WHERE `source_type` = 0 AND `entryorguid` IN (4101908, 4146573, 4149116) AND `action_type` = 25;

DELETE FROM `smart_scripts`
WHERE `source_type` = 0 AND `entryorguid` IN (4101908, 4146573, 4149116) AND `action_type` = 25;
