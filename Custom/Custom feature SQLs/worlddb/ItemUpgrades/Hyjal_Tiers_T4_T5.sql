-- ═══════════════════════════════════════════════════════════════════════════════
-- DarkChaos Item Upgrade System — Hyjal Frontier Tiers (T4 & T5)
--
-- Tier 4 — Hyjal Progression (ilvl 300-411)
--   Covers all leveling/progression gear in the Hyjal Frontier zone (400xxx
--   items at ilvl 300-404).  10 upgrade levels at +5% per level = +50% max.
--
-- Tier 5 — Hyjal Endgame (ilvl 412+)
--   Covers the endgame ICC/PvP/Ascendant analogues (400230-400707, ilvl 412).
--   15 upgrade levels at +4% per level = +60% max.
--
-- ilvl increase per upgrade:
--   T4: +3 ilvl per step → max +30 (e.g. 300 → 330 at full upgrade)
--   T5: +2 ilvl per step → max +30 (e.g. 412 → 442 at full upgrade)
--
-- Currency: token-only for both tiers (essence is reserved for T3 heirlooms).
--
-- Apply after: FIX_dc_item_upgrade_costs_schema.sql, dc_item_upgrade_overrides_schema.sql
-- C++ companion changes: ItemUpgradeManager.h (enum + NUM_TIERS),
--                        ItemUpgradeManager.cpp (mastery switch + item_overrides rename)
-- ═══════════════════════════════════════════════════════════════════════════════

USE `acore_world`;

-- =============================================================================
-- 1. Tier definitions
-- =============================================================================
-- stat_multiplier_max drives GetFinalMultiplier linear interpolation:
--   T4: 1.0 + (level/10) × 0.50 → +5% per level, capped at +50%
--   T5: 1.0 + (level/15) × 0.60 → +4% per level, capped at +60%
DELETE FROM `dc_item_upgrade_tiers` WHERE `tier_id` IN (4, 5) AND `season` = 1;

INSERT INTO `dc_item_upgrade_tiers`
    (`tier_id`, `tier_name`, `description`,
     `min_ilvl`, `max_ilvl`, `max_upgrade_level`, `stat_multiplier_max`,
     `upgrade_cost_per_level`, `source_content`, `is_artifact`, `season`, `is_active`)
VALUES
(4, 'Hyjal Progression',
    'Hyjal Frontier leveling gear — 10 upgrades, +5% per level (+50% max)',
    300, 411, 10, 1.50,
    500, 'Hyjal Frontier', 0, 1, 1),
(5, 'Hyjal Endgame',
    'Hyjal Frontier endgame gear — 15 upgrades, +4% per level (+60% max)',
    412, 0, 15, 1.60,
    1000, 'Hyjal Frontier Endgame', 0, 1, 1);

-- =============================================================================
-- 2. Upgrade costs (token-only; essence = 0 for both tiers)
--    Columns: tier_id, upgrade_level, token_cost, essence_cost,
--             ilvl_increase, stat_increase_percent, season
-- =============================================================================
DELETE FROM `dc_item_upgrade_costs` WHERE `tier_id` IN (4, 5) AND `season` = 1;

INSERT INTO `dc_item_upgrade_costs`
    (`tier_id`, `upgrade_level`, `token_cost`, `essence_cost`,
     `ilvl_increase`, `stat_increase_percent`, `season`)
VALUES
-- ── Tier 4: 10 levels, +3 ilvl each, +5% stats each ─────────────────────────
(4,  1,  100, 0, 3, 0.05, 1),
(4,  2,  200, 0, 3, 0.05, 1),
(4,  3,  300, 0, 3, 0.05, 1),
(4,  4,  400, 0, 3, 0.05, 1),
(4,  5,  500, 0, 3, 0.05, 1),
(4,  6,  600, 0, 3, 0.05, 1),
(4,  7,  700, 0, 3, 0.05, 1),
(4,  8,  800, 0, 3, 0.05, 1),
(4,  9,  900, 0, 3, 0.05, 1),
(4, 10, 1000, 0, 3, 0.05, 1),
-- ── Tier 5: 15 levels, +2 ilvl each, +4% stats each ─────────────────────────
(5,  1,  300, 0, 2, 0.04, 1),
(5,  2,  600, 0, 2, 0.04, 1),
(5,  3,  900, 0, 2, 0.04, 1),
(5,  4, 1200, 0, 2, 0.04, 1),
(5,  5, 1500, 0, 2, 0.04, 1),
(5,  6, 1800, 0, 2, 0.04, 1),
(5,  7, 2100, 0, 2, 0.04, 1),
(5,  8, 2400, 0, 2, 0.04, 1),
(5,  9, 2700, 0, 2, 0.04, 1),
(5, 10, 3000, 0, 2, 0.04, 1),
(5, 11, 3300, 0, 2, 0.04, 1),
(5, 12, 3600, 0, 2, 0.04, 1),
(5, 13, 3900, 0, 2, 0.04, 1),
(5, 14, 4200, 0, 2, 0.04, 1),
(5, 15, 4500, 0, 2, 0.04, 1);

-- Note: dc_item_upgrade_enchants is defined in ItemUpgrade_Schema_WORLD.sql but
-- is not queried by LoadUpgradeData and does not exist on the live server.
-- Stat multipliers are driven entirely by dc_item_upgrade_tiers.stat_multiplier_max
-- and dc_item_upgrade_costs.stat_increase_percent — no enchants table needed.
