-- =====================================================================
-- DarkChaos Hotspots System - Map Bounds Database Table
-- =====================================================================
-- 
-- This table stores world map coordinate boundaries used by the hotspots
-- system to:
--   1. Validate spawn coordinate ranges
--   2. Compute normalized map coordinates for addon visualization
--   3. Provide server-specific map extent customization
--
-- The hotspots system loads bounds from multiple sources in order:
--   1. DBC WorldMapArea (if available)
--   2. dc_map_bounds table (THIS FILE)
--   3. var/map_bounds.csv (optional CSV export)
--   4. Client data ADT/WDT parsing (if client files available)
--   5. Hardcoded fallback rectangles (last resort)
--
-- =====================================================================

DROP TABLE IF EXISTS `dc_map_bounds`;

CREATE TABLE `dc_map_bounds` (
    `mapid` INT UNSIGNED NOT NULL,
    `minX` DOUBLE NOT NULL,
    `maxX` DOUBLE NOT NULL,
    `minY` DOUBLE NOT NULL,
    `maxY` DOUBLE NOT NULL,
    `source` VARCHAR(64) NOT NULL DEFAULT 'manual',
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    PRIMARY KEY (`mapid`),
    KEY `idx_source` (`source`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    COMMENT='Hotspots system - world map coordinate boundaries per map';

-- =====================================================================
-- Sample Data: Vanilla WoW Map Extents (3.3.5a)
-- =====================================================================
-- Coordinates are in WoW world units (each unit ~1.92cm in-game)
-- These are approximate bounds; adjust based on actual client data
-- For accurate bounds, use the map_bounds_extractor tool

-- Map 0: Eastern Kingdoms (Azeroth)
-- Contains: Dun Morogh, Loch Modan, Westfall, Elwynn Forest, Duskwood, Redridge, Ironforge, Stormwind, etc.
INSERT INTO `dc_map_bounds` VALUES (0, -12000.0, -2000.0, -9000.0, 3000.0, 'azeroth', DEFAULT)
    ON DUPLICATE KEY UPDATE 
        minX = VALUES(minX),
        maxX = VALUES(maxX),
        minY = VALUES(minY),
        maxY = VALUES(maxY),
        source = VALUES(source);

-- Map 1: Kalimdor
-- Contains: Mulgore, Durotar, Ashenvale, Darkshore, Teldrassil, Barrens, Stonetalon, Darnassus, Orgrimmar, etc.
INSERT INTO `dc_map_bounds` VALUES (1, -12000.0, 12000.0, -15000.0, 8000.0, 'kalimdor', DEFAULT)
    ON DUPLICATE KEY UPDATE 
        minX = VALUES(minX),
        maxX = VALUES(maxX),
        minY = VALUES(minY),
        maxY = VALUES(maxY),
        source = VALUES(source);

-- Map 37: Azshara Crater (Battleground)
-- Special BG instance - tight bounds around crater
INSERT INTO `dc_map_bounds` VALUES (37, -500.0, 500.0, 750.0, 1350.0, 'azshara_crater', DEFAULT)
    ON DUPLICATE KEY UPDATE 
        minX = VALUES(minX),
        maxX = VALUES(maxX),
        minY = VALUES(minY),
        maxY = VALUES(maxY),
        source = VALUES(source);

-- Map 530: Outland (The Burning Crusade)
-- Contains: Hellfire Peninsula, Zangarmarsh, Terokkar Forest, Shadowmoon Valley, Blade's Edge, Netherstorm, Eye
INSERT INTO `dc_map_bounds` VALUES (530, -13000.0, 3000.0, -3000.0, 8000.0, 'outland', DEFAULT)
    ON DUPLICATE KEY UPDATE 
        minX = VALUES(minX),
        maxX = VALUES(maxX),
        minY = VALUES(minY),
        maxY = VALUES(maxY),
        source = VALUES(source);

-- Map 571: Northrend (Wrath of the Lich King)
-- Contains: Howling Fjord, Dragonblight, Grizzly Hills, Zul'Drak, Sholazar Basin, Crystalsong Forest, Storm Peaks, Icecrown
INSERT INTO `dc_map_bounds` VALUES (571, -8000.0, 6000.0, -1000.0, 8000.0, 'northrend', DEFAULT)
    ON DUPLICATE KEY UPDATE 
        minX = VALUES(minX),
        maxX = VALUES(maxX),
        minY = VALUES(minY),
        maxY = VALUES(maxY),
        source = VALUES(source);

-- =====================================================================
-- Notes on Customization
-- =====================================================================
--
-- If you need to customize map bounds:
--
-- 1. Use the map_bounds_extractor tool (tools/_removed/map_bounds_extractor/)
--    to generate accurate bounds from your client data
--
-- 2. Or manually insert bounds based on known coordinates:
--    INSERT INTO dc_map_bounds VALUES (mapId, minX, maxX, minY, maxY, 'custom')
--
-- 3. Source field is optional (for administrative reference only)
--    Suggested values: 'azeroth', 'kalimdor', 'outland', 'northrend', 'custom', 'measured'
--
-- 4. Invalid bounds will be skipped; the system will fallback to hardcoded rectangles
--
-- =====================================================================
