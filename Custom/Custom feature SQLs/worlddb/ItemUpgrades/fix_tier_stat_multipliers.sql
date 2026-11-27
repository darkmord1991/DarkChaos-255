-- ═══════════════════════════════════════════════════════════════════════════════
-- FIX: dc_item_upgrade_tiers — correct stat_multiplier_max for T1, T2, T3
--
-- The original values stored the *total* cap (1.07 = +7% total) instead of
-- compounding the *per-level* percentage across all upgrade steps:
--
--   T1 Leveling  :  6 levels × 7%/level  = +42%  total  → 1.42
--   T2 Heroic    : 15 levels × 5%/level  = +75%  total  → 1.75
--   T3 Heirloom  : 80 levels × 3.75%/level = +300% total → 4.00
--
-- GetFinalMultiplier uses linear interpolation:
--   multiplier = 1.0 + (upgrade_level / max_level) × (stat_multiplier_max - 1.0)
-- so at every step the bonus increases by exactly (stat_multiplier_max - 1.0) / max_level:
--   T1 step: (1.42 - 1.0) / 6  = 0.07  (+7% per level)
--   T2 step: (1.75 - 1.0) / 15 = 0.05  (+5% per level)
--   T3 step: (4.00 - 1.0) / 80 = 0.0375 (+3.75% per level, cap at +300%)
--
-- Also updates stat_increase_percent in dc_item_upgrade_costs to match
-- (informational column — not used in the multiplier calculation, but
-- shown in upgrade tooltips and stored in upgrade state).
-- ═══════════════════════════════════════════════════════════════════════════════

USE `acore_world`;

-- ── dc_item_upgrade_tiers ─────────────────────────────────────────────────────
UPDATE `dc_item_upgrade_tiers`
SET `stat_multiplier_max` = 1.42
WHERE `tier_id` = 1 AND `season` = 1;

UPDATE `dc_item_upgrade_tiers`
SET `stat_multiplier_max` = 1.75
WHERE `tier_id` = 2 AND `season` = 1;

UPDATE `dc_item_upgrade_tiers`
SET `stat_multiplier_max` = 4.00
WHERE `tier_id` = 3 AND `season` = 1;

-- ── dc_item_upgrade_costs (stat_increase_percent per level) ───────────────────
UPDATE `dc_item_upgrade_costs`
SET `stat_increase_percent` = 0.07
WHERE `tier_id` = 1 AND `season` = 1;

UPDATE `dc_item_upgrade_costs`
SET `stat_increase_percent` = 0.05
WHERE `tier_id` = 2 AND `season` = 1;

UPDATE `dc_item_upgrade_costs`
SET `stat_increase_percent` = 0.0375
WHERE `tier_id` = 3 AND `season` = 1;
