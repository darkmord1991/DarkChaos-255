-- ═══════════════════════════════════════════════════════════════════════════════
-- CRITICAL FIX: Item Upgrade Enchants Table & Data
-- ═══════════════════════════════════════════════════════════════════════════════
-- 
-- PROBLEM: ItemUpgradeStatApplication.cpp tries to verify enchants in
--          dc_item_upgrade_enchants table, but the table doesn't exist!
--
-- SOLUTION: 
--   1. Create dc_item_upgrade_enchants table
--   2. Populate with all tier/level combinations (5 tiers * 15 levels = 75 entries)
--   3. Use enchant ID format: 80000 + (tier * 100) + upgrade_level
--
-- EXAMPLES:
--   Tier 1 Level 1 = 80101
--   Tier 1 Level 15 = 80115
--   Tier 5 Level 15 = 80515
--
-- This MUST be run to enable stat application on players!
-- ═══════════════════════════════════════════════════════════════════════════════

-- ───────────────────────────────────────────────────────────────────────────────
-- STEP 1: Create the enchants verification table
-- ───────────────────────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS `dc_item_upgrade_enchants`;
CREATE TABLE IF NOT EXISTS `dc_item_upgrade_enchants` (
  `enchant_id` INT UNSIGNED PRIMARY KEY COMMENT 'Unique enchant ID (format: 80000 + tier*100 + level)',
  `tier_id` TINYINT UNSIGNED NOT NULL COMMENT 'Upgrade tier (1-5)',
  `upgrade_level` TINYINT UNSIGNED NOT NULL COMMENT 'Upgrade level (1-15)',
  `created_date` INT UNSIGNED DEFAULT 0 COMMENT 'Unix timestamp when created',
  
  UNIQUE KEY `uk_tier_level` (`tier_id`, `upgrade_level`),
  KEY `k_tier` (`tier_id`),
  KEY `k_level` (`upgrade_level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
  COMMENT='Upgrade enchant verification table - maps tier/level to enchant IDs';

-- ───────────────────────────────────────────────────────────────────────────────
-- STEP 2: Populate enchants for all tier/level combinations
-- ───────────────────────────────────────────────────────────────────────────────
-- TIER 1: Base enchants (IDs 80101-80115)
INSERT IGNORE INTO `dc_item_upgrade_enchants` (`enchant_id`, `tier_id`, `upgrade_level`) VALUES
(80101, 1, 1), (80102, 1, 2), (80103, 1, 3), (80104, 1, 4), (80105, 1, 5),
(80106, 1, 6), (80107, 1, 7), (80108, 1, 8), (80109, 1, 9), (80110, 1, 10),
(80111, 1, 11), (80112, 1, 12), (80113, 1, 13), (80114, 1, 14), (80115, 1, 15);

-- TIER 2: Heroic enchants (IDs 80201-80215)
INSERT IGNORE INTO `dc_item_upgrade_enchants` (`enchant_id`, `tier_id`, `upgrade_level`) VALUES
(80201, 2, 1), (80202, 2, 2), (80203, 2, 3), (80204, 2, 4), (80205, 2, 5),
(80206, 2, 6), (80207, 2, 7), (80208, 2, 8), (80209, 2, 9), (80210, 2, 10),
(80211, 2, 11), (80212, 2, 12), (80213, 2, 13), (80214, 2, 14), (80215, 2, 15);

-- TIER 3: Mythic enchants (IDs 80301-80315)
INSERT IGNORE INTO `dc_item_upgrade_enchants` (`enchant_id`, `tier_id`, `upgrade_level`) VALUES
(80301, 3, 1), (80302, 3, 2), (80303, 3, 3), (80304, 3, 4), (80305, 3, 5),
(80306, 3, 6), (80307, 3, 7), (80308, 3, 8), (80309, 3, 9), (80310, 3, 10),
(80311, 3, 11), (80312, 3, 12), (80313, 3, 13), (80314, 3, 14), (80315, 3, 15);

-- TIER 4: Raid enchants (IDs 80401-80415)
INSERT IGNORE INTO `dc_item_upgrade_enchants` (`enchant_id`, `tier_id`, `upgrade_level`) VALUES
(80401, 4, 1), (80402, 4, 2), (80403, 4, 3), (80404, 4, 4), (80405, 4, 5),
(80406, 4, 6), (80407, 4, 7), (80408, 4, 8), (80409, 4, 9), (80410, 4, 10),
(80411, 4, 11), (80412, 4, 12), (80413, 4, 13), (80414, 4, 14), (80415, 4, 15);

-- TIER 5: Mythic+ enchants (IDs 80501-80515)
INSERT IGNORE INTO `dc_item_upgrade_enchants` (`enchant_id`, `tier_id`, `upgrade_level`) VALUES
(80501, 5, 1), (80502, 5, 2), (80503, 5, 3), (80504, 5, 4), (80505, 5, 5),
(80506, 5, 6), (80507, 5, 7), (80508, 5, 8), (80509, 5, 9), (80510, 5, 10),
(80511, 5, 11), (80512, 5, 12), (80513, 5, 13), (80514, 5, 14), (80515, 5, 15);

-- ───────────────────────────────────────────────────────────────────────────────
-- STEP 3: Verify the data was created
-- ───────────────────────────────────────────────────────────────────────────────
SELECT 
  tier_id, 
  COUNT(*) as level_count, 
  MIN(enchant_id) as first_enchant,
  MAX(enchant_id) as last_enchant
FROM `dc_item_upgrade_enchants`
GROUP BY tier_id
ORDER BY tier_id;

SELECT CONCAT('Total enchants created: ', COUNT(*)) as status FROM `dc_item_upgrade_enchants`;

-- ═══════════════════════════════════════════════════════════════════════════════
-- SUCCESS CRITERIA:
--   ✓ Table created: dc_item_upgrade_enchants
--   ✓ Total rows: 75 (5 tiers * 15 levels)
--   ✓ Tier 1: 80101-80115 (15 entries)
--   ✓ Tier 2: 80201-80215 (15 entries)
--   ✓ Tier 3: 80301-80315 (15 entries)
--   ✓ Tier 4: 80401-80415 (15 entries)
--   ✓ Tier 5: 80501-80515 (15 entries)
--
-- After running this, ItemUpgradeStatApplication.cpp will no longer fail
-- when checking VerifyEnchantExists() and stats will apply to players!
-- ═══════════════════════════════════════════════════════════════════════════════
