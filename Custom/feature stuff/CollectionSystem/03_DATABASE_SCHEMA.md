# Collection System - Database Schema

**Component:** MySQL Database (AzerothCore characters database)  
**Tables:** Account-wide collection storage + definitions

---

## Overview

The database schema supports:
1. **Account-Wide Collections** - Mounts, pets, toys, transmog shared across characters
2. **Collection Definitions** - Static data for all collectables
3. **Favorites System** - Per-account favorite marking
4. **Statistics Tracking** - Usage counts, obtained dates
5. **Achievement Integration** - Collection milestone tracking

---

## Entity Relationship Diagram

```
┌─────────────────────────┐     ┌─────────────────────────┐
│   dc_mount_definitions  │     │   dc_pet_definitions    │
├─────────────────────────┤     ├─────────────────────────┤
│ spell_id (PK)           │     │ pet_entry (PK)          │
│ name                    │     │ name                    │
│ mount_type              │     │ pet_spell_id            │
│ source                  │     │ source                  │
│ faction                 │     │ faction                 │
│ class_mask              │     │ display_id              │
│ display_id              │     │ icon                    │
│ icon                    │     │ rarity                  │
│ rarity                  │     └───────────┬─────────────┘
│ speed                   │                 │
└───────────┬─────────────┘                 │
            │                               │
            ▼                               ▼
┌─────────────────────────┐     ┌─────────────────────────┐
│  dc_mount_collection    │     │   dc_pet_collection     │
├─────────────────────────┤     ├─────────────────────────┤
│ account_id (PK)         │     │ account_id (PK)         │
│ spell_id (PK, FK)       │     │ pet_entry (PK, FK)      │
│ obtained_by             │     │ obtained_by             │
│ obtained_date           │     │ obtained_date           │
│ times_used              │     │ pet_name                │
│ is_favorite             │     │ is_favorite             │
└─────────────────────────┘     └─────────────────────────┘

┌─────────────────────────┐     ┌─────────────────────────┐
│   dc_toy_definitions    │     │ dc_heirloom_definitions │
├─────────────────────────┤     ├─────────────────────────┤
│ item_id (PK)            │     │ item_id (PK)            │
│ name                    │     │ name                    │
│ category                │     │ slot                    │
│ source                  │     │ max_upgrade_level       │
│ cooldown                │     │ scaling_type            │
│ icon                    │     │ icon                    │
│ rarity                  │     │ source                  │
└───────────┬─────────────┘     └───────────┬─────────────┘
            │                               │
            ▼                               ▼
┌─────────────────────────┐     ┌─────────────────────────┐
│   dc_toy_collection     │     │  dc_heirloom_collection │
├─────────────────────────┤     ├─────────────────────────┤
│ account_id (PK)         │     │ account_id (PK)         │
│ item_id (PK, FK)        │     │ item_id (PK, FK)        │
│ obtained_by             │     │ upgrade_level           │
│ obtained_date           │     │ obtained_by             │
│ times_used              │     │ obtained_date           │
│ is_favorite             │     └─────────────────────────┘
└─────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│              dc_collection_achievements                  │
├─────────────────────────────────────────────────────────┤
│ achievement_id (PK)                                      │
│ collection_type (enum)                                   │
│ required_count                                           │
│ reward_type (title/mount/pet/item)                       │
│ reward_id                                                │
│ name                                                     │
│ description                                              │
└─────────────────────────────────────────────────────────┘
```

---

## Table Definitions

### dc_mount_definitions

Static mount data - loaded once at server startup.

```sql
-- Mount definition table (static data)
CREATE TABLE IF NOT EXISTS `dc_mount_definitions` (
    `spell_id` INT UNSIGNED NOT NULL COMMENT 'Mount spell ID',
    `name` VARCHAR(100) NOT NULL COMMENT 'Mount name',
    `mount_type` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=ground, 1=flying, 2=aquatic, 3=all',
    `source` TEXT DEFAULT NULL COMMENT 'JSON: {"type":"drop","location":"Tempest Keep","boss":"Kael\'thas"}',
    `faction` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=both, 1=alliance, 2=horde',
    `class_mask` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=all classes, else class bit mask',
    `display_id` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Creature display ID',
    `icon` VARCHAR(255) DEFAULT '' COMMENT 'Icon path override',
    `rarity` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=common, 1=uncommon, 2=rare, 3=epic, 4=legendary',
    `speed` SMALLINT UNSIGNED NOT NULL DEFAULT 100 COMMENT 'Mount speed percentage',
    `expansion` TINYINT UNSIGNED NOT NULL DEFAULT 2 COMMENT '0=vanilla, 1=tbc, 2=wotlk',
    `is_tradeable` TINYINT(1) NOT NULL DEFAULT 0 COMMENT 'Can be traded between players',
    `profession_required` TINYINT UNSIGNED DEFAULT NULL COMMENT 'Profession ID if required',
    `skill_required` SMALLINT UNSIGNED DEFAULT NULL COMMENT 'Skill level if profession mount',
    PRIMARY KEY (`spell_id`),
    KEY `idx_mount_type` (`mount_type`),
    KEY `idx_rarity` (`rarity`),
    KEY `idx_faction` (`faction`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Mount definitions for collection system';

-- Sample data
INSERT INTO `dc_mount_definitions` (`spell_id`, `name`, `mount_type`, `source`, `faction`, `rarity`, `speed`) VALUES
-- Vendor mounts
(458, 'Brown Horse', 0, '{"type":"vendor","npc":"Katie Hunter","cost":10000}', 1, 0, 60),
(470, 'Black Stallion', 0, '{"type":"vendor","npc":"Katie Hunter","cost":100000}', 1, 1, 100),
(580, 'Timber Wolf', 0, '{"type":"vendor","npc":"Ogunaro Wolfrunner","cost":10000}', 2, 0, 60),

-- Drop mounts
(41252, 'Raven Lord', 1, '{"type":"drop","location":"Sethekk Halls","boss":"Anzu","dropRate":1}', 0, 3, 280),
(32458, 'Ashes of Al\'ar', 1, '{"type":"drop","location":"Tempest Keep","boss":"Kael\'thas Sunstrider","dropRate":1}', 0, 4, 310),
(63963, 'Rusted Proto-Drake', 1, '{"type":"achievement","achievement":"Glory of the Ulduar Raider (10 player)"}', 0, 3, 310),

-- DarkChaos exclusive
(800001, 'Mythic Challenger Mount', 1, '{"type":"achievement","achievement":"Complete Mythic+15","darkChaos":true}', 0, 4, 310),
(800002, 'Season 1 Champion', 1, '{"type":"seasonal","season":1,"rank":"top100"}', 0, 4, 310),
(800003, 'Hinterland Warbeast', 0, '{"type":"pvp","achievement":"500 Hinterland BG Wins","darkChaos":true}', 0, 3, 100);
```

### dc_mount_collection

Player collection data - account-wide.

```sql
-- Account mount collection (player data)
CREATE TABLE IF NOT EXISTS `dc_mount_collection` (
    `account_id` INT UNSIGNED NOT NULL COMMENT 'Account ID',
    `spell_id` INT UNSIGNED NOT NULL COMMENT 'Mount spell ID',
    `obtained_by` INT UNSIGNED NOT NULL COMMENT 'Character GUID who obtained it',
    `obtained_date` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'When the mount was obtained',
    `times_used` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Usage counter',
    `is_favorite` TINYINT(1) NOT NULL DEFAULT 0 COMMENT 'Marked as favorite',
    `last_used` TIMESTAMP NULL DEFAULT NULL COMMENT 'Last time mount was summoned',
    PRIMARY KEY (`account_id`, `spell_id`),
    KEY `idx_obtained_by` (`obtained_by`),
    KEY `idx_favorite` (`account_id`, `is_favorite`),
    KEY `idx_obtained_date` (`obtained_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Account mount collection';

-- Trigger to update last_used
DELIMITER //
CREATE TRIGGER `trg_mount_used` BEFORE UPDATE ON `dc_mount_collection`
FOR EACH ROW
BEGIN
    IF NEW.times_used > OLD.times_used THEN
        SET NEW.last_used = CURRENT_TIMESTAMP;
    END IF;
END//
DELIMITER ;
```

### dc_pet_definitions

```sql
-- Pet definition table (static data)
CREATE TABLE IF NOT EXISTS `dc_pet_definitions` (
    `pet_entry` INT UNSIGNED NOT NULL COMMENT 'Pet entry ID (unique per pet type)',
    `name` VARCHAR(100) NOT NULL COMMENT 'Pet name',
    `pet_spell_id` INT UNSIGNED NOT NULL COMMENT 'Spell to summon pet',
    `source` TEXT DEFAULT NULL COMMENT 'JSON source data',
    `faction` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=both, 1=alliance, 2=horde',
    `display_id` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Creature display ID',
    `icon` VARCHAR(255) DEFAULT '' COMMENT 'Icon path',
    `rarity` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=common to 4=legendary',
    `category` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=general, 1=beast, 2=critter, etc.',
    `is_tradeable` TINYINT(1) NOT NULL DEFAULT 0 COMMENT 'Can be traded',
    PRIMARY KEY (`pet_entry`),
    KEY `idx_spell` (`pet_spell_id`),
    KEY `idx_rarity` (`rarity`),
    KEY `idx_category` (`category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Pet definitions for collection system';

-- Sample data
INSERT INTO `dc_pet_definitions` (`pet_entry`, `name`, `pet_spell_id`, `source`, `rarity`) VALUES
(10000, 'Mini Mythic Drake', 800100, '{"type":"achievement","name":"M+10 Complete","darkChaos":true}', 3),
(10001, 'Hinterland Hatchling', 800101, '{"type":"achievement","name":"100 HLBG Wins","darkChaos":true}', 2),
(10002, 'Season 1 Companion', 800102, '{"type":"seasonal","season":1}', 3),
(10003, 'Upgrade Sprite', 800103, '{"type":"achievement","name":"Upgrade 100 items"}', 1),
(10004, 'Prestige Phantom', 800104, '{"type":"achievement","name":"Reach Prestige 5"}', 4);
```

### dc_pet_collection

```sql
-- Account pet collection (player data)
CREATE TABLE IF NOT EXISTS `dc_pet_collection` (
    `account_id` INT UNSIGNED NOT NULL COMMENT 'Account ID',
    `pet_entry` INT UNSIGNED NOT NULL COMMENT 'Pet entry ID',
    `obtained_by` INT UNSIGNED NOT NULL COMMENT 'Character GUID who obtained it',
    `obtained_date` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `pet_name` VARCHAR(50) DEFAULT NULL COMMENT 'Custom pet name',
    `is_favorite` TINYINT(1) NOT NULL DEFAULT 0,
    `times_summoned` INT UNSIGNED NOT NULL DEFAULT 0,
    `last_summoned` TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (`account_id`, `pet_entry`),
    KEY `idx_obtained_by` (`obtained_by`),
    KEY `idx_favorite` (`account_id`, `is_favorite`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Account pet collection';
```

### dc_toy_definitions

```sql
-- Toy definition table (static data)
CREATE TABLE IF NOT EXISTS `dc_toy_definitions` (
    `item_id` INT UNSIGNED NOT NULL COMMENT 'Toy item ID',
    `name` VARCHAR(100) NOT NULL COMMENT 'Toy name',
    `category` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=general, 1=holiday, 2=transform, etc.',
    `source` TEXT DEFAULT NULL COMMENT 'JSON source data',
    `cooldown` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Cooldown in seconds',
    `duration` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Effect duration in seconds',
    `icon` VARCHAR(255) DEFAULT '',
    `rarity` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `expansion` TINYINT UNSIGNED NOT NULL DEFAULT 2,
    PRIMARY KEY (`item_id`),
    KEY `idx_category` (`category`),
    KEY `idx_rarity` (`rarity`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Toy definitions for collection system';

-- Sample data
INSERT INTO `dc_toy_definitions` (`item_id`, `name`, `category`, `source`, `cooldown`, `rarity`) VALUES
(34686, 'Picnic Basket', 0, '{"type":"vendor","npc":"Multiple"}', 300, 1),
(54343, 'Blue Crashin\' Thrashin\' Racer Controller', 0, '{"type":"drop","holiday":"Winter Veil"}', 180, 2),
(45047, 'Argent Tournament Pony', 0, '{"type":"vendor","npc":"Dame Evniki Kapsalis"}', 60, 2);
```

### dc_toy_collection

```sql
-- Account toy collection (player data)
CREATE TABLE IF NOT EXISTS `dc_toy_collection` (
    `account_id` INT UNSIGNED NOT NULL,
    `item_id` INT UNSIGNED NOT NULL,
    `obtained_by` INT UNSIGNED NOT NULL,
    `obtained_date` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `times_used` INT UNSIGNED NOT NULL DEFAULT 0,
    `is_favorite` TINYINT(1) NOT NULL DEFAULT 0,
    `last_used` TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (`account_id`, `item_id`),
    KEY `idx_obtained_by` (`obtained_by`),
    KEY `idx_favorite` (`account_id`, `is_favorite`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Account toy collection';
```

### dc_collection_achievements

```sql
-- Collection achievements table
CREATE TABLE IF NOT EXISTS `dc_collection_achievements` (
    `achievement_id` INT UNSIGNED NOT NULL COMMENT 'Custom achievement ID',
    `collection_type` ENUM('mount', 'pet', 'transmog', 'toy', 'heirloom', 'all') NOT NULL,
    `required_count` INT UNSIGNED NOT NULL COMMENT 'Number of items needed',
    `reward_type` ENUM('title', 'mount', 'pet', 'item', 'currency', 'none') NOT NULL DEFAULT 'none',
    `reward_id` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'ID of reward (title/mount/pet/item)',
    `reward_amount` INT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Amount for currency rewards',
    `name` VARCHAR(100) NOT NULL,
    `description` VARCHAR(255) DEFAULT NULL,
    `icon` VARCHAR(255) DEFAULT '',
    `points` SMALLINT UNSIGNED NOT NULL DEFAULT 10 COMMENT 'Achievement points',
    PRIMARY KEY (`achievement_id`),
    KEY `idx_type_count` (`collection_type`, `required_count`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Collection-based achievements';

-- Sample achievements
INSERT INTO `dc_collection_achievements` VALUES
-- Mount achievements
(9001, 'mount', 10, 'title', 600, 1, 'Stable Keeper', 'Collect 10 mounts', '', 10),
(9002, 'mount', 25, 'title', 601, 1, 'Leading the Cavalry', 'Collect 25 mounts', '', 10),
(9003, 'mount', 50, 'mount', 800050, 1, 'Mountain o\' Mounts', 'Collect 50 mounts', '', 10),
(9004, 'mount', 100, 'mount', 800051, 1, 'We\'re Going to Need More Saddles', 'Collect 100 mounts', '', 10),
(9005, 'mount', 200, 'mount', 800052, 1, 'Mount Parade', 'Collect 200 mounts', '', 25),

-- Pet achievements
(9101, 'pet', 10, 'title', 610, 1, 'Can I Keep Him?', 'Collect 10 pets', '', 10),
(9102, 'pet', 25, 'title', 611, 1, 'Pet Collector', 'Collect 25 pets', '', 10),
(9103, 'pet', 50, 'pet', 10050, 1, 'Plenty of Pets', 'Collect 50 pets', '', 10),
(9104, 'pet', 100, 'pet', 10051, 1, 'That\'s a Lot of Pets', 'Collect 100 pets', '', 10),
(9105, 'pet', 150, 'pet', 10052, 1, 'Pet Hoarder', 'Collect 150 pets', '', 25),

-- Cross-collection achievements
(9201, 'all', 100, 'title', 620, 1, 'Collector', 'Collect 100 items total', '', 10),
(9202, 'all', 500, 'title', 621, 1, 'Avid Collector', 'Collect 500 items total', '', 25),
(9203, 'all', 1000, 'mount', 800060, 1, 'Ultimate Collector', 'Collect 1000 items total', '', 50);
```

---

## Stored Procedures

### sp_add_mount_to_collection

```sql
DELIMITER //

CREATE PROCEDURE `sp_add_mount_to_collection`(
    IN p_account_id INT UNSIGNED,
    IN p_spell_id INT UNSIGNED,
    IN p_obtained_by INT UNSIGNED
)
BEGIN
    DECLARE v_exists TINYINT DEFAULT 0;
    DECLARE v_count INT UNSIGNED DEFAULT 0;
    
    -- Check if already collected
    SELECT COUNT(*) INTO v_exists 
    FROM dc_mount_collection 
    WHERE account_id = p_account_id AND spell_id = p_spell_id;
    
    IF v_exists = 0 THEN
        -- Insert new mount
        INSERT INTO dc_mount_collection (account_id, spell_id, obtained_by)
        VALUES (p_account_id, p_spell_id, p_obtained_by);
        
        -- Get new count for achievement checking
        SELECT COUNT(*) INTO v_count 
        FROM dc_mount_collection 
        WHERE account_id = p_account_id;
        
        -- Return success with new count
        SELECT 1 AS success, v_count AS total_mounts;
    ELSE
        -- Already owned
        SELECT 0 AS success, 'Already collected' AS message;
    END IF;
END//

DELIMITER ;
```

### sp_get_collection_statistics

```sql
DELIMITER //

CREATE PROCEDURE `sp_get_collection_statistics`(
    IN p_account_id INT UNSIGNED
)
BEGIN
    -- Mount statistics
    SELECT 
        'mount' AS collection_type,
        (SELECT COUNT(*) FROM dc_mount_collection WHERE account_id = p_account_id) AS collected,
        (SELECT COUNT(*) FROM dc_mount_definitions) AS total,
        (SELECT COUNT(*) FROM dc_mount_collection WHERE account_id = p_account_id AND is_favorite = 1) AS favorites;
    
    -- Pet statistics
    SELECT 
        'pet' AS collection_type,
        (SELECT COUNT(*) FROM dc_pet_collection WHERE account_id = p_account_id) AS collected,
        (SELECT COUNT(*) FROM dc_pet_definitions) AS total,
        (SELECT COUNT(*) FROM dc_pet_collection WHERE account_id = p_account_id AND is_favorite = 1) AS favorites;
    
    -- Toy statistics
    SELECT 
        'toy' AS collection_type,
        (SELECT COUNT(*) FROM dc_toy_collection WHERE account_id = p_account_id) AS collected,
        (SELECT COUNT(*) FROM dc_toy_definitions) AS total,
        (SELECT COUNT(*) FROM dc_toy_collection WHERE account_id = p_account_id AND is_favorite = 1) AS favorites;
    
    -- Transmog (bridge to existing system)
    -- This would need adjustment based on existing transmog tables
    
    -- Rarity breakdown for mounts
    SELECT 
        md.rarity,
        COUNT(mc.spell_id) AS collected
    FROM dc_mount_definitions md
    LEFT JOIN dc_mount_collection mc 
        ON md.spell_id = mc.spell_id AND mc.account_id = p_account_id
    GROUP BY md.rarity
    ORDER BY md.rarity;
END//

DELIMITER ;
```

---

## Views

### v_mount_collection_full

```sql
-- Full mount collection view with definition data
CREATE OR REPLACE VIEW `v_mount_collection_full` AS
SELECT 
    mc.account_id,
    mc.spell_id,
    md.name,
    md.mount_type,
    md.source,
    md.faction,
    md.class_mask,
    md.display_id,
    COALESCE(md.icon, '') AS icon,
    md.rarity,
    md.speed,
    mc.obtained_by,
    mc.obtained_date,
    mc.times_used,
    mc.is_favorite,
    mc.last_used,
    1 AS is_collected
FROM dc_mount_collection mc
JOIN dc_mount_definitions md ON mc.spell_id = md.spell_id;

-- All mounts view (collected and uncollected for a given account)
CREATE OR REPLACE VIEW `v_mount_definitions_extended` AS
SELECT 
    md.*,
    CASE WHEN md.class_mask = 0 THEN 'All Classes'
         WHEN md.class_mask & 1 THEN 'Warrior'
         WHEN md.class_mask & 2 THEN 'Paladin'
         WHEN md.class_mask & 4 THEN 'Hunter'
         WHEN md.class_mask & 8 THEN 'Rogue'
         WHEN md.class_mask & 16 THEN 'Priest'
         WHEN md.class_mask & 32 THEN 'Death Knight'
         WHEN md.class_mask & 64 THEN 'Shaman'
         WHEN md.class_mask & 128 THEN 'Mage'
         WHEN md.class_mask & 256 THEN 'Warlock'
         WHEN md.class_mask & 1024 THEN 'Druid'
         ELSE 'Multiple Classes'
    END AS class_requirement_text,
    CASE md.mount_type
         WHEN 0 THEN 'Ground'
         WHEN 1 THEN 'Flying'
         WHEN 2 THEN 'Aquatic'
         WHEN 3 THEN 'All'
    END AS mount_type_text,
    CASE md.faction
         WHEN 0 THEN 'Both'
         WHEN 1 THEN 'Alliance'
         WHEN 2 THEN 'Horde'
    END AS faction_text
FROM dc_mount_definitions md;
```

---

## Migration Scripts

### From Existing Transmog

If transmog data exists in a different format, create migration:

```sql
-- Example: Migrate from existing transmog_appearances table
-- INSERT INTO dc_transmog_collection (account_id, item_id, obtained_by, obtained_date)
-- SELECT 
--     a.accountId,
--     ta.item_id,
--     c.guid,
--     ta.collected_date
-- FROM transmog_appearances ta
-- JOIN characters c ON ta.character_guid = c.guid
-- JOIN account a ON c.account = a.id
-- ON DUPLICATE KEY UPDATE obtained_date = VALUES(obtained_date);
```

---

## Performance Indexes

```sql
-- Composite indexes for common queries
CREATE INDEX idx_mount_collection_account_fav 
    ON dc_mount_collection(account_id, is_favorite);

CREATE INDEX idx_mount_def_source_rarity 
    ON dc_mount_definitions(rarity, mount_type);

-- Full-text search on mount names (optional, requires InnoDB)
-- ALTER TABLE dc_mount_definitions ADD FULLTEXT INDEX ft_mount_name (name);
```

---

## Summary

| Table | Purpose | Scope |
|-------|---------|-------|
| dc_mount_definitions | Static mount data | Server-wide |
| dc_mount_collection | Player mount ownership | Account |
| dc_pet_definitions | Static pet data | Server-wide |
| dc_pet_collection | Player pet ownership | Account |
| dc_toy_definitions | Static toy data | Server-wide |
| dc_toy_collection | Player toy ownership | Account |
| dc_collection_achievements | Collection milestones | Server-wide |

**Key Design Decisions:**
1. **Account-wide** - All collections are account-based
2. **Normalized** - Definitions separate from collection data
3. **JSON sources** - Flexible source info without schema changes
4. **Soft denormalization** - Views for common queries
5. **Future-proof** - Easy to add new collection types
