-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════
-- ITEM UPGRADE SYSTEM - ENCHANT STAT BONUSES
-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════
-- 
-- This file configures stat bonuses for the item upgrade enchant system.
-- When items are equipped with upgrades, temporary enchants (IDs 80101-80515) are applied.
-- These entries ensure all stats receive the proper multiplier scaling.
--
-- BONUS TYPES (from spell_bonus_data table):
--  - direct_bonus: Flat multiplier applied to ALL direct damage & healing
--  - dot_bonus: Flat multiplier applied to damage-over-time effects
--  - ap_bonus: Multiplier applied to attack power scaling
--  - ap_dot_bonus: Multiplier applied to attack power in DoT effects
--
-- For upgrade enchants, we use DIRECT_BONUS as a universal stat multiplier
-- This affects: Primary Stats, Secondary Stats (Crit/Haste/Hit), Armor, Resistances, etc.
--
-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════

-- First, let's backup existing data if any
CREATE TEMPORARY TABLE temp_spell_bonus_backup AS
SELECT * FROM spell_bonus_data WHERE entry >= 80101 AND entry <= 80515;

-- Clear any existing upgrade enchant bonus data
DELETE FROM spell_bonus_data WHERE entry >= 80101 AND entry <= 80515;

-- ───────────────────────────────────────────────────────────────────────────────────────────────────────────────
-- TIER 1 ENCHANTS (IDs 80101-80115) - COMMON ITEMS
-- Formula: base_multiplier = 1.0 + (level * 0.025), tier_mult = 0.9
-- ───────────────────────────────────────────────────────────────────────────────────────────────────────────────
INSERT INTO spell_bonus_data (entry, direct_bonus, dot_bonus, ap_bonus, ap_dot_bonus, comments) VALUES
(80101, 0.0225, 0.0225, 0.0225, 0.0225, 'Tier 1 Level 1 - Common Upgrade (1.0225x)'),
(80102, 0.0450, 0.0450, 0.0450, 0.0450, 'Tier 1 Level 2 - Common Upgrade (1.0450x)'),
(80103, 0.0675, 0.0675, 0.0675, 0.0675, 'Tier 1 Level 3 - Common Upgrade (1.0675x)'),
(80104, 0.0900, 0.0900, 0.0900, 0.0900, 'Tier 1 Level 4 - Common Upgrade (1.0900x)'),
(80105, 0.1125, 0.1125, 0.1125, 0.1125, 'Tier 1 Level 5 - Common Upgrade (1.1125x)'),
(80106, 0.1350, 0.1350, 0.1350, 0.1350, 'Tier 1 Level 6 - Common Upgrade (1.1350x)'),
(80107, 0.1575, 0.1575, 0.1575, 0.1575, 'Tier 1 Level 7 - Common Upgrade (1.1575x)'),
(80108, 0.1800, 0.1800, 0.1800, 0.1800, 'Tier 1 Level 8 - Common Upgrade (1.1800x)'),
(80109, 0.2025, 0.2025, 0.2025, 0.2025, 'Tier 1 Level 9 - Common Upgrade (1.2025x)'),
(80110, 0.2250, 0.2250, 0.2250, 0.2250, 'Tier 1 Level 10 - Common Upgrade (1.2250x)'),
(80111, 0.2475, 0.2475, 0.2475, 0.2475, 'Tier 1 Level 11 - Common Upgrade (1.2475x)'),
(80112, 0.2700, 0.2700, 0.2700, 0.2700, 'Tier 1 Level 12 - Common Upgrade (1.2700x)'),
(80113, 0.2925, 0.2925, 0.2925, 0.2925, 'Tier 1 Level 13 - Common Upgrade (1.2925x)'),
(80114, 0.3150, 0.3150, 0.3150, 0.3150, 'Tier 1 Level 14 - Common Upgrade (1.3150x)'),
(80115, 0.3375, 0.3375, 0.3375, 0.3375, 'Tier 1 Level 15 - Common Upgrade (1.3375x)');

-- ───────────────────────────────────────────────────────────────────────────────────────────────────────────────
-- TIER 2 ENCHANTS (IDs 80201-80215) - UNCOMMON ITEMS
-- Formula: base_multiplier = 1.0 + (level * 0.025), tier_mult = 0.95
-- ───────────────────────────────────────────────────────────────────────────────────────────────────────────────
INSERT INTO spell_bonus_data (entry, direct_bonus, dot_bonus, ap_bonus, ap_dot_bonus, comments) VALUES
(80201, 0.0237, 0.0237, 0.0237, 0.0237, 'Tier 2 Level 1 - Uncommon Upgrade (1.0237x)'),
(80202, 0.0475, 0.0475, 0.0475, 0.0475, 'Tier 2 Level 2 - Uncommon Upgrade (1.0475x)'),
(80203, 0.0712, 0.0712, 0.0712, 0.0712, 'Tier 2 Level 3 - Uncommon Upgrade (1.0712x)'),
(80204, 0.0950, 0.0950, 0.0950, 0.0950, 'Tier 2 Level 4 - Uncommon Upgrade (1.0950x)'),
(80205, 0.1187, 0.1187, 0.1187, 0.1187, 'Tier 2 Level 5 - Uncommon Upgrade (1.1187x)'),
(80206, 0.1425, 0.1425, 0.1425, 0.1425, 'Tier 2 Level 6 - Uncommon Upgrade (1.1425x)'),
(80207, 0.1662, 0.1662, 0.1662, 0.1662, 'Tier 2 Level 7 - Uncommon Upgrade (1.1662x)'),
(80208, 0.1900, 0.1900, 0.1900, 0.1900, 'Tier 2 Level 8 - Uncommon Upgrade (1.1900x)'),
(80209, 0.2137, 0.2137, 0.2137, 0.2137, 'Tier 2 Level 9 - Uncommon Upgrade (1.2137x)'),
(80210, 0.2375, 0.2375, 0.2375, 0.2375, 'Tier 2 Level 10 - Uncommon Upgrade (1.2375x)'),
(80211, 0.2612, 0.2612, 0.2612, 0.2612, 'Tier 2 Level 11 - Uncommon Upgrade (1.2612x)'),
(80212, 0.2850, 0.2850, 0.2850, 0.2850, 'Tier 2 Level 12 - Uncommon Upgrade (1.2850x)'),
(80213, 0.3087, 0.3087, 0.3087, 0.3087, 'Tier 2 Level 13 - Uncommon Upgrade (1.3087x)'),
(80214, 0.3325, 0.3325, 0.3325, 0.3325, 'Tier 2 Level 14 - Uncommon Upgrade (1.3325x)'),
(80215, 0.3562, 0.3562, 0.3562, 0.3562, 'Tier 2 Level 15 - Uncommon Upgrade (1.3562x)');

-- ───────────────────────────────────────────────────────────────────────────────────────────────────────────────
-- TIER 3 ENCHANTS (IDs 80301-80315) - RARE ITEMS  
-- Formula: base_multiplier = 1.0 + (level * 0.025), tier_mult = 1.0 (no adjustment)
-- ───────────────────────────────────────────────────────────────────────────────────────────────────────────────
INSERT INTO spell_bonus_data (entry, direct_bonus, dot_bonus, ap_bonus, ap_dot_bonus, comments) VALUES
(80301, 0.0250, 0.0250, 0.0250, 0.0250, 'Tier 3 Level 1 - Rare Upgrade (1.0250x)'),
(80302, 0.0500, 0.0500, 0.0500, 0.0500, 'Tier 3 Level 2 - Rare Upgrade (1.0500x)'),
(80303, 0.0750, 0.0750, 0.0750, 0.0750, 'Tier 3 Level 3 - Rare Upgrade (1.0750x)'),
(80304, 0.1000, 0.1000, 0.1000, 0.1000, 'Tier 3 Level 4 - Rare Upgrade (1.1000x)'),
(80305, 0.1250, 0.1250, 0.1250, 0.1250, 'Tier 3 Level 5 - Rare Upgrade (1.1250x)'),
(80306, 0.1500, 0.1500, 0.1500, 0.1500, 'Tier 3 Level 6 - Rare Upgrade (1.1500x)'),
(80307, 0.1750, 0.1750, 0.1750, 0.1750, 'Tier 3 Level 7 - Rare Upgrade (1.1750x)'),
(80308, 0.2000, 0.2000, 0.2000, 0.2000, 'Tier 3 Level 8 - Rare Upgrade (1.2000x)'),
(80309, 0.2250, 0.2250, 0.2250, 0.2250, 'Tier 3 Level 9 - Rare Upgrade (1.2250x)'),
(80310, 0.2500, 0.2500, 0.2500, 0.2500, 'Tier 3 Level 10 - Rare Upgrade (1.2500x)'),
(80311, 0.2750, 0.2750, 0.2750, 0.2750, 'Tier 3 Level 11 - Rare Upgrade (1.2750x)'),
(80312, 0.3000, 0.3000, 0.3000, 0.3000, 'Tier 3 Level 12 - Rare Upgrade (1.3000x)'),
(80313, 0.3250, 0.3250, 0.3250, 0.3250, 'Tier 3 Level 13 - Rare Upgrade (1.3250x)'),
(80314, 0.3500, 0.3500, 0.3500, 0.3500, 'Tier 3 Level 14 - Rare Upgrade (1.3500x)'),
(80315, 0.3750, 0.3750, 0.3750, 0.3750, 'Tier 3 Level 15 - Rare Upgrade (1.3750x)');

-- ───────────────────────────────────────────────────────────────────────────────────────────────────────────────
-- TIER 4 ENCHANTS (IDs 80401-80415) - EPIC ITEMS
-- Formula: base_multiplier = 1.0 + (level * 0.025), tier_mult = 1.15 (enhanced scaling)
-- ───────────────────────────────────────────────────────────────────────────────────────────────────────────────
INSERT INTO spell_bonus_data (entry, direct_bonus, dot_bonus, ap_bonus, ap_dot_bonus, comments) VALUES
(80401, 0.0288, 0.0288, 0.0288, 0.0288, 'Tier 4 Level 1 - Epic Upgrade (1.0288x)'),
(80402, 0.0575, 0.0575, 0.0575, 0.0575, 'Tier 4 Level 2 - Epic Upgrade (1.0575x)'),
(80403, 0.0862, 0.0862, 0.0862, 0.0862, 'Tier 4 Level 3 - Epic Upgrade (1.0862x)'),
(80404, 0.1150, 0.1150, 0.1150, 0.1150, 'Tier 4 Level 4 - Epic Upgrade (1.1150x)'),
(80405, 0.1437, 0.1437, 0.1437, 0.1437, 'Tier 4 Level 5 - Epic Upgrade (1.1437x)'),
(80406, 0.1725, 0.1725, 0.1725, 0.1725, 'Tier 4 Level 6 - Epic Upgrade (1.1725x)'),
(80407, 0.2012, 0.2012, 0.2012, 0.2012, 'Tier 4 Level 7 - Epic Upgrade (1.2012x)'),
(80408, 0.2300, 0.2300, 0.2300, 0.2300, 'Tier 4 Level 8 - Epic Upgrade (1.2300x)'),
(80409, 0.2587, 0.2587, 0.2587, 0.2587, 'Tier 4 Level 9 - Epic Upgrade (1.2587x)'),
(80410, 0.2875, 0.2875, 0.2875, 0.2875, 'Tier 4 Level 10 - Epic Upgrade (1.2875x)'),
(80411, 0.3162, 0.3162, 0.3162, 0.3162, 'Tier 4 Level 11 - Epic Upgrade (1.3162x)'),
(80412, 0.3450, 0.3450, 0.3450, 0.3450, 'Tier 4 Level 12 - Epic Upgrade (1.3450x)'),
(80413, 0.3737, 0.3737, 0.3737, 0.3737, 'Tier 4 Level 13 - Epic Upgrade (1.3737x)'),
(80414, 0.4025, 0.4025, 0.4025, 0.4025, 'Tier 4 Level 14 - Epic Upgrade (1.4025x)'),
(80415, 0.4312, 0.4312, 0.4312, 0.4312, 'Tier 4 Level 15 - Epic Upgrade (1.4312x)');

-- ───────────────────────────────────────────────────────────────────────────────────────────────────────────────
-- TIER 5 ENCHANTS (IDs 80501-80515) - LEGENDARY ITEMS
-- Formula: base_multiplier = 1.0 + (level * 0.025), tier_mult = 1.25 (maximum scaling)
-- ───────────────────────────────────────────────────────────────────────────────────────────────────────────────
INSERT INTO spell_bonus_data (entry, direct_bonus, dot_bonus, ap_bonus, ap_dot_bonus, comments) VALUES
(80501, 0.0312, 0.0312, 0.0312, 0.0312, 'Tier 5 Level 1 - Legendary Upgrade (1.0312x)'),
(80502, 0.0625, 0.0625, 0.0625, 0.0625, 'Tier 5 Level 2 - Legendary Upgrade (1.0625x)'),
(80503, 0.0937, 0.0937, 0.0937, 0.0937, 'Tier 5 Level 3 - Legendary Upgrade (1.0937x)'),
(80504, 0.1250, 0.1250, 0.1250, 0.1250, 'Tier 5 Level 4 - Legendary Upgrade (1.1250x)'),
(80505, 0.1562, 0.1562, 0.1562, 0.1562, 'Tier 5 Level 5 - Legendary Upgrade (1.1562x)'),
(80506, 0.1875, 0.1875, 0.1875, 0.1875, 'Tier 5 Level 6 - Legendary Upgrade (1.1875x)'),
(80507, 0.2187, 0.2187, 0.2187, 0.2187, 'Tier 5 Level 7 - Legendary Upgrade (1.2187x)'),
(80508, 0.2500, 0.2500, 0.2500, 0.2500, 'Tier 5 Level 8 - Legendary Upgrade (1.2500x)'),
(80509, 0.2812, 0.2812, 0.2812, 0.2812, 'Tier 5 Level 9 - Legendary Upgrade (1.2812x)'),
(80510, 0.3125, 0.3125, 0.3125, 0.3125, 'Tier 5 Level 10 - Legendary Upgrade (1.3125x)'),
(80511, 0.3437, 0.3437, 0.3437, 0.3437, 'Tier 5 Level 11 - Legendary Upgrade (1.3437x)'),
(80512, 0.3750, 0.3750, 0.3750, 0.3750, 'Tier 5 Level 12 - Legendary Upgrade (1.3750x)'),
(80513, 0.4062, 0.4062, 0.4062, 0.4062, 'Tier 5 Level 13 - Legendary Upgrade (1.4062x)'),
(80514, 0.4375, 0.4375, 0.4375, 0.4375, 'Tier 5 Level 14 - Legendary Upgrade (1.4375x)'),
(80515, 0.4687, 0.4687, 0.4687, 0.4687, 'Tier 5 Level 15 - Legendary Upgrade (1.4687x)');

-- ───────────────────────────────────────────────────────────────────────────────────────────────────────────────
-- VERIFICATION QUERIES
-- ───────────────────────────────────────────────────────────────────────────────────────────────────────────────

-- Verify all enchants were added
SELECT 'VERIFICATION: Enchant Entries Added' as status;
SELECT COUNT(*) as total_entries FROM spell_bonus_data WHERE entry >= 80101 AND entry <= 80515;

-- Show bonus progression by tier
SELECT 
  CASE 
    WHEN entry >= 80101 AND entry <= 80115 THEN 'Tier 1 (Common)'
    WHEN entry >= 80201 AND entry <= 80215 THEN 'Tier 2 (Uncommon)'
    WHEN entry >= 80301 AND entry <= 80315 THEN 'Tier 3 (Rare)'
    WHEN entry >= 80401 AND entry <= 80415 THEN 'Tier 4 (Epic)'
    WHEN entry >= 80501 AND entry <= 80515 THEN 'Tier 5 (Legendary)'
  END as tier,
  MIN(entry) as min_id,
  MAX(entry) as max_id,
  COUNT(*) as level_count,
  MIN(direct_bonus) as min_bonus,
  MAX(direct_bonus) as max_bonus,
  ROUND(MAX(direct_bonus) * 100, 2) as max_bonus_percent
FROM spell_bonus_data 
WHERE entry >= 80101 AND entry <= 80515
GROUP BY tier
ORDER BY min_id;

-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════
-- SUCCESS CRITERIA
-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════
-- ✓ Total entries added: 75 (5 tiers * 15 levels)
-- ✓ All spell_bonus_data entries include: direct_bonus, dot_bonus, ap_bonus, ap_dot_bonus
-- ✓ Each bonus includes meaningful comments showing tier, level, and calculated multiplier
-- ✓ Tier-based scaling applied:
--   - Tier 1 (Common): 0.9x multiplier
--   - Tier 2 (Uncommon): 0.95x multiplier  
--   - Tier 3 (Rare): 1.0x multiplier
--   - Tier 4 (Epic): 1.15x multiplier
--   - Tier 5 (Legendary): 1.25x multiplier
-- ✓ Secondary stats (Crit/Haste/Hit) are now properly scaled via these bonuses
-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════
