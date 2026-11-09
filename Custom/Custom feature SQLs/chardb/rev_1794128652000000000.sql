-- DarkChaos: explored-zone words past the 128 of `exploredZones`, i.e. AreaBits 4096-8191, space separated up to
-- the last nonzero word (NULL or empty: none). Player reads it in CHAR_SEL_CHARACTER and writes it in
-- CHAR_UPD_CHARACTER and sends it to the native client in SMSG_DC_EXPLORED_ZONES. Builds that predate it never name
-- the column, so they leave it alone. The worldserver that uses it will not start without it.
SET @has_col := (SELECT COUNT(*) FROM `information_schema`.`COLUMNS`
    WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` = 'characters' AND `COLUMN_NAME` = 'exploredZonesExt');
SET @stmt := IF(@has_col = 0, 'ALTER TABLE `characters` ADD COLUMN `exploredZonesExt` TEXT NULL AFTER `exploredZones`', 'DO 0');
PREPARE stmt FROM @stmt;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
