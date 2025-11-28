-- =====================================================
-- Item Upgrade System - Enchantment-Based Stat Scaling
-- =====================================================
-- This file creates enchantment entries for the Item Upgrade system
-- Each tier + level combination gets a unique enchant ID
-- 
-- Enchant ID Format: 80000 + (tier * 100) + level
-- Example: Tier 1 Level 5 = 80105
--          Tier 5 Level 15 = 80515
--
-- Date: November 8, 2025
-- =====================================================

-- Mapping table for quick lookup
CREATE TABLE IF NOT EXISTS `dc_item_upgrade_enchants` (
  `enchant_id` INT UNSIGNED NOT NULL PRIMARY KEY,
  `tier_id` TINYINT UNSIGNED NOT NULL,
  `upgrade_level` TINYINT UNSIGNED NOT NULL,
  `stat_multiplier` FLOAT NOT NULL,
  `description` VARCHAR(255),
  INDEX `idx_tier_level` (`tier_id`, `upgrade_level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Item Upgrade enchant mapping';

-- Generate enchant entries for all tier/level combinations
-- Tier 1: Levels 1-15 (IDs 80101-80115)
-- Tier 2: Levels 1-15 (IDs 80201-80215)
-- Tier 3: Levels 1-15 (IDs 80301-80315)
-- Tier 4: Levels 1-15 (IDs 80401-80415)
-- Tier 5: Levels 1-15 (IDs 80501-80515)

TRUNCATE TABLE `dc_item_upgrade_enchants`;

-- Tier 1 enchants (Common)
INSERT INTO `dc_item_upgrade_enchants` (`enchant_id`, `tier_id`, `upgrade_level`, `stat_multiplier`, `description`) VALUES
(80101, 1, 1, 1.0225, 'Item Upgrade: Tier 1 Level 1 (+2.25%)'),
(80102, 1, 2, 1.0450, 'Item Upgrade: Tier 1 Level 2 (+4.5%)'),
(80103, 1, 3, 1.0675, 'Item Upgrade: Tier 1 Level 3 (+6.75%)'),
(80104, 1, 4, 1.0900, 'Item Upgrade: Tier 1 Level 4 (+9%)'),
(80105, 1, 5, 1.1125, 'Item Upgrade: Tier 1 Level 5 (+11.25%)'),
(80106, 1, 6, 1.1350, 'Item Upgrade: Tier 1 Level 6 (+13.5%)'),
(80107, 1, 7, 1.1575, 'Item Upgrade: Tier 1 Level 7 (+15.75%)'),
(80108, 1, 8, 1.1800, 'Item Upgrade: Tier 1 Level 8 (+18%)'),
(80109, 1, 9, 1.2025, 'Item Upgrade: Tier 1 Level 9 (+20.25%)'),
(80110, 1, 10, 1.2250, 'Item Upgrade: Tier 1 Level 10 (+22.5%)'),
(80111, 1, 11, 1.2475, 'Item Upgrade: Tier 1 Level 11 (+24.75%)'),
(80112, 1, 12, 1.2700, 'Item Upgrade: Tier 1 Level 12 (+27%)'),
(80113, 1, 13, 1.2925, 'Item Upgrade: Tier 1 Level 13 (+29.25%)'),
(80114, 1, 14, 1.3150, 'Item Upgrade: Tier 1 Level 14 (+31.5%)'),
(80115, 1, 15, 1.3375, 'Item Upgrade: Tier 1 Level 15 (+33.75%)');

-- Tier 2 enchants (Uncommon)
INSERT INTO `dc_item_upgrade_enchants` (`enchant_id`, `tier_id`, `upgrade_level`, `stat_multiplier`, `description`) VALUES
(80201, 2, 1, 1.0238, 'Item Upgrade: Tier 2 Level 1 (+2.38%)'),
(80202, 2, 2, 1.0475, 'Item Upgrade: Tier 2 Level 2 (+4.75%)'),
(80203, 2, 3, 1.0713, 'Item Upgrade: Tier 2 Level 3 (+7.13%)'),
(80204, 2, 4, 1.0950, 'Item Upgrade: Tier 2 Level 4 (+9.5%)'),
(80205, 2, 5, 1.1188, 'Item Upgrade: Tier 2 Level 5 (+11.88%)'),
(80206, 2, 6, 1.1425, 'Item Upgrade: Tier 2 Level 6 (+14.25%)'),
(80207, 2, 7, 1.1663, 'Item Upgrade: Tier 2 Level 7 (+16.63%)'),
(80208, 2, 8, 1.1900, 'Item Upgrade: Tier 2 Level 8 (+19%)'),
(80209, 2, 9, 1.2138, 'Item Upgrade: Tier 2 Level 9 (+21.38%)'),
(80210, 2, 10, 1.2375, 'Item Upgrade: Tier 2 Level 10 (+23.75%)'),
(80211, 2, 11, 1.2613, 'Item Upgrade: Tier 2 Level 11 (+26.13%)'),
(80212, 2, 12, 1.2850, 'Item Upgrade: Tier 2 Level 12 (+28.5%)'),
(80213, 2, 13, 1.3088, 'Item Upgrade: Tier 2 Level 13 (+30.88%)'),
(80214, 2, 14, 1.3325, 'Item Upgrade: Tier 2 Level 14 (+33.25%)'),
(80215, 2, 15, 1.3563, 'Item Upgrade: Tier 2 Level 15 (+35.63%)');

-- Tier 3 enchants (Rare)
INSERT INTO `dc_item_upgrade_enchants` (`enchant_id`, `tier_id`, `upgrade_level`, `stat_multiplier`, `description`) VALUES
(80301, 3, 1, 1.0250, 'Item Upgrade: Tier 3 Level 1 (+2.5%)'),
(80302, 3, 2, 1.0500, 'Item Upgrade: Tier 3 Level 2 (+5%)'),
(80303, 3, 3, 1.0750, 'Item Upgrade: Tier 3 Level 3 (+7.5%)'),
(80304, 3, 4, 1.1000, 'Item Upgrade: Tier 3 Level 4 (+10%)'),
(80305, 3, 5, 1.1250, 'Item Upgrade: Tier 3 Level 5 (+12.5%)'),
(80306, 3, 6, 1.1500, 'Item Upgrade: Tier 3 Level 6 (+15%)'),
(80307, 3, 7, 1.1750, 'Item Upgrade: Tier 3 Level 7 (+17.5%)'),
(80308, 3, 8, 1.2000, 'Item Upgrade: Tier 3 Level 8 (+20%)'),
(80309, 3, 9, 1.2250, 'Item Upgrade: Tier 3 Level 9 (+22.5%)'),
(80310, 3, 10, 1.2500, 'Item Upgrade: Tier 3 Level 10 (+25%)'),
(80311, 3, 11, 1.2750, 'Item Upgrade: Tier 3 Level 11 (+27.5%)'),
(80312, 3, 12, 1.3000, 'Item Upgrade: Tier 3 Level 12 (+30%)'),
(80313, 3, 13, 1.3250, 'Item Upgrade: Tier 3 Level 13 (+32.5%)'),
(80314, 3, 14, 1.3500, 'Item Upgrade: Tier 3 Level 14 (+35%)'),
(80315, 3, 15, 1.3750, 'Item Upgrade: Tier 3 Level 15 (+37.5%)');

-- Tier 4 enchants (Epic)
INSERT INTO `dc_item_upgrade_enchants` (`enchant_id`, `tier_id`, `upgrade_level`, `stat_multiplier`, `description`) VALUES
(80401, 4, 1, 1.0288, 'Item Upgrade: Tier 4 Level 1 (+2.88%)'),
(80402, 4, 2, 1.0575, 'Item Upgrade: Tier 4 Level 2 (+5.75%)'),
(80403, 4, 3, 1.0863, 'Item Upgrade: Tier 4 Level 3 (+8.63%)'),
(80404, 4, 4, 1.1150, 'Item Upgrade: Tier 4 Level 4 (+11.5%)'),
(80405, 4, 5, 1.1438, 'Item Upgrade: Tier 4 Level 5 (+14.38%)'),
(80406, 4, 6, 1.1725, 'Item Upgrade: Tier 4 Level 6 (+17.25%)'),
(80407, 4, 7, 1.2013, 'Item Upgrade: Tier 4 Level 7 (+20.13%)'),
(80408, 4, 8, 1.2300, 'Item Upgrade: Tier 4 Level 8 (+23%)'),
(80409, 4, 9, 1.2588, 'Item Upgrade: Tier 4 Level 9 (+25.88%)'),
(80410, 4, 10, 1.2875, 'Item Upgrade: Tier 4 Level 10 (+28.75%)'),
(80411, 4, 11, 1.3163, 'Item Upgrade: Tier 4 Level 11 (+31.63%)'),
(80412, 4, 12, 1.3450, 'Item Upgrade: Tier 4 Level 12 (+34.5%)'),
(80413, 4, 13, 1.3738, 'Item Upgrade: Tier 4 Level 13 (+37.38%)'),
(80414, 4, 14, 1.4025, 'Item Upgrade: Tier 4 Level 14 (+40.25%)'),
(80415, 4, 15, 1.4313, 'Item Upgrade: Tier 4 Level 15 (+43.13%)');

-- Tier 5 enchants (Legendary)
INSERT INTO `dc_item_upgrade_enchants` (`enchant_id`, `tier_id`, `upgrade_level`, `stat_multiplier`, `description`) VALUES
(80501, 5, 1, 1.0313, 'Item Upgrade: Tier 5 Level 1 (+3.13%)'),
(80502, 5, 2, 1.0625, 'Item Upgrade: Tier 5 Level 2 (+6.25%)'),
(80503, 5, 3, 1.0938, 'Item Upgrade: Tier 5 Level 3 (+9.38%)'),
(80504, 5, 4, 1.1250, 'Item Upgrade: Tier 5 Level 4 (+12.5%)'),
(80505, 5, 5, 1.1563, 'Item Upgrade: Tier 5 Level 5 (+15.63%)'),
(80506, 5, 6, 1.1875, 'Item Upgrade: Tier 5 Level 6 (+18.75%)'),
(80507, 5, 7, 1.2188, 'Item Upgrade: Tier 5 Level 7 (+21.88%)'),
(80508, 5, 8, 1.2500, 'Item Upgrade: Tier 5 Level 8 (+25%)'),
(80509, 5, 9, 1.2813, 'Item Upgrade: Tier 5 Level 9 (+28.13%)'),
(80510, 5, 10, 1.3125, 'Item Upgrade: Tier 5 Level 10 (+31.25%)'),
(80511, 5, 11, 1.3438, 'Item Upgrade: Tier 5 Level 11 (+34.38%)'),
(80512, 5, 12, 1.3750, 'Item Upgrade: Tier 5 Level 12 (+37.5%)'),
(80513, 5, 13, 1.4063, 'Item Upgrade: Tier 5 Level 13 (+40.63%)'),
(80514, 5, 14, 1.4375, 'Item Upgrade: Tier 5 Level 14 (+43.75%)'),
(80515, 5, 15, 1.4688, 'Item Upgrade: Tier 5 Level 15 (+46.88%)');

-- Note: These are PERCENTAGE multipliers
-- The actual stat bonuses will be calculated by applying these multipliers
-- to the item's base stats via the enchantment system
