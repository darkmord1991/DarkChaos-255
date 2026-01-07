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
(527, 0.0, 0.0, 30.0, 0.0, 50000000, 'The Celestial Expanse', 'Eye of Eternity raid map'),
-- 3: Nagrand Floating Isles
(530, -1659.0, 8251.0, 57.0, 0.0, 25000000, 'Nagrand Skydock', 'Nagrand floating island above the void'),
-- 4: Designer Island (Flat Sandbox)
(451, 162.0, 162.0, 15.0, 0.0, 50000000, 'Architects Plains', 'Designer Island - Development Map'),
-- 5: Shadowmoon Valley (The Black Temple Top)
(530, -3632.0, 316.0, 36.0, 1.5, 75000000, 'Temple Summit', 'Top of Black Temple (Open World)');
