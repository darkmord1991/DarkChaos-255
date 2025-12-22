-- DB update 2025_12_21_03 -> 2025_12_21_04
-- DC-Collection: auto-populate mount + pet definitions from `item_template`
--
-- Goal:
-- - Ensure the full WotLK mount (misc/mounts) and companion pet datasets are present
--   without manually maintaining per-item lists.
--
-- Notes:
-- - Pulls from `item_template` (class=15 misc): mounts are subclass=5, companions are subclass=2.
-- - Uses spellid_1..spellid_5 to find the learned/summon spell.
-- - Creates missing tables and populates them idempotently (safe to re-run).
-- - Adds rows into `dc_collection_definitions` so totals/definitions can be driven from a single index.

-- ---------------------------------------------------------------------------
-- Tables (match schema in Custom/Custom feature SQLs/worlddb/CollectionSystem/dc_collection_definitions.sql)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `dc_collection_definitions` (
    `collection_type` TINYINT UNSIGNED NOT NULL COMMENT '1=mount,2=pet,3=toy,4=heirloom,5=title,6=transmog',
    `entry_id` INT UNSIGNED NOT NULL,
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (`collection_type`, `entry_id`),
    KEY `idx_enabled` (`collection_type`, `enabled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Generic collection definition index';

CREATE TABLE IF NOT EXISTS `dc_mount_definitions` (
    `spell_id` INT UNSIGNED NOT NULL PRIMARY KEY COMMENT 'Mount spell ID',
    `name` VARCHAR(100) NOT NULL COMMENT 'Mount name',
    `mount_type` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=ground, 1=flying, 2=aquatic, 3=all',
    `source` TEXT DEFAULT NULL COMMENT 'JSON source info',
    `faction` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=both, 1=alliance, 2=horde',
    `class_mask` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=all, else class bitmask',
    `display_id` INT UNSIGNED NOT NULL DEFAULT 0,
    `icon` VARCHAR(255) DEFAULT '' COMMENT 'Icon path override',
    `rarity` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=common, 1=uncommon, 2=rare, 3=epic, 4=legendary',
    `speed` SMALLINT UNSIGNED NOT NULL DEFAULT 100 COMMENT 'Speed percentage',
    `expansion` TINYINT UNSIGNED NOT NULL DEFAULT 2 COMMENT '0=vanilla, 1=tbc, 2=wotlk',
    `is_tradeable` TINYINT(1) NOT NULL DEFAULT 0,
    `profession_required` TINYINT UNSIGNED DEFAULT NULL,
    `skill_required` SMALLINT UNSIGNED DEFAULT NULL,
    `flags` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Custom flags',
    KEY `idx_mount_type` (`mount_type`),
    KEY `idx_rarity` (`rarity`),
    KEY `idx_faction` (`faction`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Mount definitions';

CREATE TABLE IF NOT EXISTS `dc_pet_definitions` (
    `pet_entry` INT UNSIGNED NOT NULL PRIMARY KEY COMMENT 'Pet entry or spell ID',
    `name` VARCHAR(100) NOT NULL,
    `pet_type` ENUM('companion', 'minipet') NOT NULL DEFAULT 'companion',
    `pet_spell_id` INT UNSIGNED DEFAULT NULL COMMENT 'Summon spell if different',
    `source` TEXT DEFAULT NULL COMMENT 'JSON source info',
    `faction` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `display_id` INT UNSIGNED NOT NULL DEFAULT 0,
    `icon` VARCHAR(255) DEFAULT '',
    `rarity` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `expansion` TINYINT UNSIGNED NOT NULL DEFAULT 2,
    `flags` INT UNSIGNED NOT NULL DEFAULT 0,
    KEY `idx_rarity` (`rarity`),
    KEY `idx_faction` (`faction`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Pet definitions';

-- ---------------------------------------------------------------------------
-- Insert mounts from item_template (misc/mounts)
-- ---------------------------------------------------------------------------

INSERT IGNORE INTO `dc_mount_definitions` (`spell_id`, `name`, `rarity`, `display_id`, `source`)
SELECT
    m.spell_id,
    SUBSTRING(MIN(m.item_name), 1, 100) AS name,
    MAX(m.rarity) AS rarity,
    MAX(m.display_id) AS display_id,
    JSON_OBJECT('type', 'unknown', 'item_id', MIN(m.item_id))
FROM (
    SELECT i.entry AS item_id, i.name AS item_name, i.spellid_1 AS spell_id, i.Quality AS rarity, i.displayid AS display_id
    FROM item_template i
    WHERE i.class = 15 AND i.subclass = 5 AND i.spellid_1 > 0
    UNION ALL
    SELECT i.entry AS item_id, i.name AS item_name, i.spellid_2 AS spell_id, i.Quality AS rarity, i.displayid AS display_id
    FROM item_template i
    WHERE i.class = 15 AND i.subclass = 5 AND i.spellid_2 > 0
    UNION ALL
    SELECT i.entry AS item_id, i.name AS item_name, i.spellid_3 AS spell_id, i.Quality AS rarity, i.displayid AS display_id
    FROM item_template i
    WHERE i.class = 15 AND i.subclass = 5 AND i.spellid_3 > 0
    UNION ALL
    SELECT i.entry AS item_id, i.name AS item_name, i.spellid_4 AS spell_id, i.Quality AS rarity, i.displayid AS display_id
    FROM item_template i
    WHERE i.class = 15 AND i.subclass = 5 AND i.spellid_4 > 0
    UNION ALL
    SELECT i.entry AS item_id, i.name AS item_name, i.spellid_5 AS spell_id, i.Quality AS rarity, i.displayid AS display_id
    FROM item_template i
    WHERE i.class = 15 AND i.subclass = 5 AND i.spellid_5 > 0
) m
GROUP BY m.spell_id;

INSERT IGNORE INTO `dc_collection_definitions` (`collection_type`, `entry_id`, `enabled`)
SELECT 1 AS collection_type, d.spell_id AS entry_id, 1 AS enabled
FROM `dc_mount_definitions` d;

-- ---------------------------------------------------------------------------
-- Insert pets from item_template (misc/companions)
--
-- IMPORTANT:
-- - `pet_entry` is the item_id (matches existing PopulatePetDefinitions())
-- - `pet_spell_id` is the summon spell
-- ---------------------------------------------------------------------------

INSERT IGNORE INTO `dc_pet_definitions` (`pet_entry`, `name`, `pet_spell_id`, `rarity`, `display_id`, `source`)
SELECT
    p.item_id AS pet_entry,
    SUBSTRING(MIN(p.item_name), 1, 100) AS name,
    MIN(p.spell_id) AS pet_spell_id,
    MAX(p.rarity) AS rarity,
    MAX(p.display_id) AS display_id,
    JSON_OBJECT('type', 'unknown', 'item_id', p.item_id)
FROM (
    SELECT i.entry AS item_id, i.name AS item_name, i.spellid_1 AS spell_id, i.Quality AS rarity, i.displayid AS display_id
    FROM item_template i
    WHERE i.class = 15 AND i.subclass = 2 AND i.spellid_1 > 0
    UNION ALL
    SELECT i.entry AS item_id, i.name AS item_name, i.spellid_2 AS spell_id, i.Quality AS rarity, i.displayid AS display_id
    FROM item_template i
    WHERE i.class = 15 AND i.subclass = 2 AND i.spellid_2 > 0
    UNION ALL
    SELECT i.entry AS item_id, i.name AS item_name, i.spellid_3 AS spell_id, i.Quality AS rarity, i.displayid AS display_id
    FROM item_template i
    WHERE i.class = 15 AND i.subclass = 2 AND i.spellid_3 > 0
    UNION ALL
    SELECT i.entry AS item_id, i.name AS item_name, i.spellid_4 AS spell_id, i.Quality AS rarity, i.displayid AS display_id
    FROM item_template i
    WHERE i.class = 15 AND i.subclass = 2 AND i.spellid_4 > 0
    UNION ALL
    SELECT i.entry AS item_id, i.name AS item_name, i.spellid_5 AS spell_id, i.Quality AS rarity, i.displayid AS display_id
    FROM item_template i
    WHERE i.class = 15 AND i.subclass = 2 AND i.spellid_5 > 0
) p
GROUP BY p.item_id;

INSERT IGNORE INTO `dc_collection_definitions` (`collection_type`, `entry_id`, `enabled`)
SELECT 2 AS collection_type, d.pet_entry AS entry_id, 1 AS enabled
FROM `dc_pet_definitions` d;
