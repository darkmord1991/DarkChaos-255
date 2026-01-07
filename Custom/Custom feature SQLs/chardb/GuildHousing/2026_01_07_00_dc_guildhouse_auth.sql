-- Dark Chaos Guild Housing - Permissions & Audit System

-- Table: dc_guild_house_permissions
-- Stores permission flags per guild rank
DROP TABLE IF EXISTS `dc_guild_house_permissions`;
CREATE TABLE `dc_guild_house_permissions` (
    `guildId` INT UNSIGNED NOT NULL,
    `rankId` TINYINT UNSIGNED NOT NULL,
    `permission` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`guildId`, `rankId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Permission Flags (Documented for reference):
-- 1: CAN_SPAWN (Spawn NPCs/Objects)
-- 2: CAN_DELETE (Delete NPCs/Objects)
-- 4: CAN_MOVE (Move Objects)
-- 8: CAN_ADMIN (Change permissions, etc)
-- 16: CAN_USE_WORKSHOP (Use guild benches)

-- Table: dc_guild_house_log
-- Audit log for all modification actions
DROP TABLE IF EXISTS `dc_guild_house_log`;
CREATE TABLE `dc_guild_house_log` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `guildId` INT UNSIGNED NOT NULL,
    `playerGuid` INT UNSIGNED NOT NULL,
    `actionType` TINYINT UNSIGNED NOT NULL COMMENT '1=Spawn, 2=Delete, 3=Move',
    `entityType` TINYINT UNSIGNED NOT NULL COMMENT '1=Creature, 2=GameObject',
    `entityEntry` INT UNSIGNED NOT NULL,
    `entityGuid` INT UNSIGNED NOT NULL COMMENT 'LowGUID of the entity involved',
    `mapId` INT UNSIGNED NOT NULL,
    `posX` FLOAT NOT NULL,
    `posY` FLOAT NOT NULL,
    `posZ` FLOAT NOT NULL,
    `orientation` FLOAT NOT NULL,
    `timestamp` INT UNSIGNED NOT NULL,
    INDEX `idx_guild` (`guildId`),
    INDEX `idx_time` (`timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
