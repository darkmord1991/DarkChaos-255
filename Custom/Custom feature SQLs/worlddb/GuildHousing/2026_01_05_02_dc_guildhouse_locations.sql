-- Dark Chaos Guild Housing - Multi-Map Selection System
-- Table: dc_guild_house_locations

DROP TABLE IF EXISTS `dc_guild_house_locations`;
CREATE TABLE `dc_guild_house_locations` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `map` INT UNSIGNED NOT NULL,
    `posX` FLOAT NOT NULL,
    `posY` FLOAT NOT NULL,
    `posZ` FLOAT NOT NULL,
    `orientation` FLOAT NOT NULL,
    `cost` INT UNSIGNED NOT NULL DEFAULT 10000000, -- Copper (1000g default)
    `name` VARCHAR(100) NOT NULL,
    `required_achievement` INT UNSIGNED DEFAULT 0,
    `comment` VARCHAR(255)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Initial Locations
INSERT INTO `dc_guild_house_locations` (`map`, `posX`, `posY`, `posZ`, `orientation`, `cost`, `name`, `comment`) VALUES
-- 1: GM Island (Classic)
(1, 16222.972, 16267.802, 13.136777, 1.461173, 10000000, 'The Secret Island', 'GM Island default location'),
-- 2: The Void (Eye of Eternity Platform)
(527, 0.0, 0.0, 30.0, 0.0, 50000000, 'The Celestial Expanse', 'Eye of Eternity raid map');
