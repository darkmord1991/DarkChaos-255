-- ═══════════════════════════════════════════════════════════════════════════════
-- POPULATE: dc_item_upgrade_tiers TABLE
-- Purpose: Define tier max levels and properties
-- Tier 1: 6 levels (regular leveling items)
-- Tier 2: 15 levels (heroic dungeon gear)
-- Tier 3: 80 levels (heirlooms - one level per player level)
-- ═══════════════════════════════════════════════════════════════════════════════

USE acore_world;

-- The table already exists with this schema:
-- tier_id, tier_name, description, min_item_level, max_item_level, is_active
-- Note: The C++ code expects additional columns that don't exist in the current schema.
-- The system uses hardcoded values in C++ when database columns are missing.

-- Clear existing data
TRUNCATE TABLE `dc_item_upgrade_tiers`;

-- Insert tier definitions
INSERT INTO `dc_item_upgrade_tiers` 
    (`tier_id`, `tier_name`, `description`, `min_item_level`, `max_item_level`, `is_active`)
VALUES
    -- Tier 1: Regular leveling items (6 upgrade levels)
    (1, 'Leveling', 'Quest and leveling gear - 6 upgrade levels', 1, 212, 1),
    
    -- Tier 2: Heroic dungeon gear (15 upgrade levels)
    (2, 'Heroic', 'Heroic dungeon gear - 15 upgrade levels', 213, 226, 1),
    
    -- Tier 3: Heirlooms (80 levels - scales with player level 1-80)
    (3, 'Heirloom', 'Heirloom items - 80 upgrade levels (one per player level)', 1, 500, 1);

-- Verification query
SELECT 
    tier_id,
    tier_name,
    description,
    min_item_level AS 'Min iLvl',
    max_item_level AS 'Max iLvl',
    is_active AS 'Active'
FROM dc_item_upgrade_tiers
ORDER BY tier_id;

-- Expected output:
-- tier_id | tier_name | description                        | Min iLvl | Max iLvl | Active
-- --------|-----------|------------------------------------|---------|-----------|---------
-- 1       | Leveling  | Quest and leveling gear - 6 levels | 1       | 212       | 1
-- 2       | Heroic    | Heroic dungeon gear - 15 levels    | 213     | 226       | 1
-- 3       | Heirloom  | Heirloom items - 80 levels         | 1       | 500       | 1

-- ═══════════════════════════════════════════════════════════════════════════════
-- NOTES:
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- IMPORTANT: Max upgrade levels are controlled in C++ code, NOT in the database!
-- The ItemUpgradeManager::GetTierMaxLevel() function returns:
--   - Tier 1: 6 levels (defined in ItemUpgradeManager.h)
--   - Tier 2: 15 levels
--   - Tier 3: 80 levels
--
-- This table only stores:
--   - Tier metadata (name, description)
--   - Item level ranges for tier detection
--   - Active/inactive status
--
-- Tier 1 (Leveling): Quest/leveling gear, item levels 1-212
-- Tier 2 (Heroic): Heroic dungeon gear, item levels 213-226
-- Tier 3 (Heirloom): Heirloom items, scales with player level
--
-- ═══════════════════════════════════════════════════════════════════════════════
-- END OF FILE
-- ═══════════════════════════════════════════════════════════════════════════════
