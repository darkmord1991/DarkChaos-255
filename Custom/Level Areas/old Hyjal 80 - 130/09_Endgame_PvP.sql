-- Hyjal Frontier - endgame PvP gear
--
-- Consolidated PvP endgame catalog: 208 equippable Wrathful Gladiator
-- analogues normalized to ilvl 412 in 400500-400707. Contains 80 set
-- pieces plus 128 offset items including weapons, shields, offhands,
-- relics, trinkets, cloaks, necks, rings, belts, boots, bracers and
-- the tabard. Frost Wyrm mount is excluded; this block is for wearable
-- and wieldable gear only.
DELETE FROM `item_template`
WHERE `entry` BETWEEN 400500 AND 400707;

SET @dc_hyjal_pvp_target_ilvl := 412;
SET @dc_hyjal_pvp_old_group_concat_max_len := @@SESSION.group_concat_max_len;
SET SESSION group_concat_max_len = 131072;

DROP TEMPORARY TABLE IF EXISTS `dc_hyjal_pvp_source_map`;
CREATE TEMPORARY TABLE `dc_hyjal_pvp_source_map`
(
    `new_entry` INT UNSIGNED NOT NULL,
    `source_entry` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`new_entry`),
    UNIQUE KEY `ux_source_entry` (`source_entry`)
);

SET @dc_hyjal_pvp_entry := 400499;
INSERT INTO `dc_hyjal_pvp_source_map` (`new_entry`, `source_entry`)
SELECT (@dc_hyjal_pvp_entry := @dc_hyjal_pvp_entry + 1) AS `new_entry`,
       src.`entry` AS `source_entry`
FROM `item_template` AS src
WHERE src.`name` LIKE 'Wrathful Gladiator%'
  AND src.`entry` < 200000
  AND src.`entry` <> 50435
ORDER BY src.`name`, src.`entry`;

SET @dc_hyjal_pvp_columns := (
    SELECT GROUP_CONCAT(CONCAT('`', COLUMN_NAME, '`')
                        ORDER BY ORDINAL_POSITION SEPARATOR ', ')
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'item_template'
);

SET @dc_hyjal_pvp_select := (
    SELECT GROUP_CONCAT(
        CASE
            WHEN COLUMN_NAME = 'entry' THEN 'map.`new_entry`'
            WHEN COLUMN_NAME = 'ItemLevel' THEN '@dc_hyjal_pvp_target_ilvl'
            WHEN COLUMN_NAME = 'RequiredLevel' THEN '130'
            WHEN COLUMN_NAME = 'BuyPrice' THEN '0'
            WHEN COLUMN_NAME = 'SellPrice' THEN 'CASE WHEN src.`ItemLevel` > 0 THEN ROUND(src.`SellPrice` * (@dc_hyjal_pvp_target_ilvl / src.`ItemLevel`)) ELSE src.`SellPrice` END'
            WHEN COLUMN_NAME REGEXP '^stat_value[0-9]+$' THEN CONCAT(
                'CASE WHEN src.`ItemLevel` > 0 THEN ROUND(src.`', COLUMN_NAME,
                '` * (@dc_hyjal_pvp_target_ilvl / src.`ItemLevel`)) ELSE src.`',
                COLUMN_NAME, '` END')
            WHEN COLUMN_NAME REGEXP '^dmg_(min|max)[12]$' THEN CONCAT(
                'CASE WHEN src.`ItemLevel` > 0 THEN ROUND(src.`', COLUMN_NAME,
                '` * (@dc_hyjal_pvp_target_ilvl / src.`ItemLevel`), 6) ELSE src.`',
                COLUMN_NAME, '` END')
            WHEN COLUMN_NAME = 'ArmorDamageModifier' THEN
                'CASE WHEN src.`ItemLevel` > 0 THEN ROUND(src.`ArmorDamageModifier` * (@dc_hyjal_pvp_target_ilvl / src.`ItemLevel`), 6) ELSE src.`ArmorDamageModifier` END'
            WHEN COLUMN_NAME IN ('armor', 'block') THEN CONCAT(
                'CASE WHEN src.`ItemLevel` > 0 THEN ROUND(src.`', COLUMN_NAME,
                '` * (@dc_hyjal_pvp_target_ilvl / src.`ItemLevel`)) ELSE src.`',
                COLUMN_NAME, '` END')
            WHEN COLUMN_NAME = 'description' THEN
                'CONCAT(''Level 130 PvP analogue of '', src.`name`, ''.'')'
            WHEN COLUMN_NAME = 'VerifiedBuild' THEN '0'
            ELSE CONCAT('src.`', COLUMN_NAME, '`')
        END
        ORDER BY ORDINAL_POSITION SEPARATOR ', ')
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'item_template'
);

SET @dc_hyjal_pvp_sql := CONCAT(
    'INSERT INTO `item_template` (', @dc_hyjal_pvp_columns, ') ',
    'SELECT ', @dc_hyjal_pvp_select, ' ',
    'FROM `dc_hyjal_pvp_source_map` AS map ',
    'JOIN `item_template` AS src ON src.`entry` = map.`source_entry` ',
    'ORDER BY map.`new_entry`'
);

PREPARE dc_hyjal_pvp_stmt FROM @dc_hyjal_pvp_sql;
EXECUTE dc_hyjal_pvp_stmt;
DEALLOCATE PREPARE dc_hyjal_pvp_stmt;

DROP TEMPORARY TABLE IF EXISTS `dc_hyjal_pvp_source_map`;
SET SESSION group_concat_max_len = @dc_hyjal_pvp_old_group_concat_max_len;