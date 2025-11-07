-- =========================================================================
-- DarkChaos Item Upgrade System - Two-Tier Refresh
-- World Database import for aligning tier data with the Phase 4B manager changes
-- =========================================================================
--
-- What this script does
--   * Replaces Season 1 tier definitions for the leveling + endgame tracks
--   * Prunes and redefines the per-level upgrade costs for the affected tiers
--   * Realigns existing item templates so newly generated data points to Tier 1/2 only
--
-- NOTE
--   This script intentionally leaves Tier 5 (Artifacts) untouched. Artifact data continues
--   to rely on the existing configuration and remains compatible with the new manager hooks.
-- =========================================================================

START TRANSACTION;

-- -------------------------------------------------------------------------
-- 1) Tier definitions (Season 1)
-- -------------------------------------------------------------------------
DELETE FROM `dc_item_upgrade_tiers`
 WHERE `season` = 1
   AND `tier_id` IN (1, 2);

INSERT INTO `dc_item_upgrade_tiers`
(`tier_id`, `tier_name`, `min_ilvl`, `max_ilvl`, `max_upgrade_level`, `stat_multiplier_max`, `upgrade_cost_per_level`, `source_content`, `is_artifact`, `season`)
VALUES
    (1, 'Leveling Track', 1, 179, 6, 1.30, 12, 'leveling', 0, 1),
    (2, 'Endgame Track', 180, 400, 10, 1.55, 32, 'endgame', 0, 1);

-- -------------------------------------------------------------------------
-- 2) Upgrade costs (Season 1)
-- -------------------------------------------------------------------------
DELETE FROM `dc_item_upgrade_costs`
 WHERE `season` = 1
   AND `tier_id` IN (1, 2);

-- Tier 1 (Leveling) – six upgrade steps
INSERT INTO `dc_item_upgrade_costs`
(`tier_id`, `upgrade_level`, `token_cost`, `essence_cost`, `ilvl_increase`, `stat_increase_percent`, `season`)
VALUES
    (1, 1, 8,   0, 4, 0.05, 1),
    (1, 2, 10,  0, 4, 0.05, 1),
    (1, 3, 12,  0, 4, 0.05, 1),
    (1, 4, 15,  0, 5, 0.06, 1),
    (1, 5, 18,  0, 5, 0.06, 1),
    (1, 6, 22,  0, 6, 0.07, 1);

-- Tier 2 (Endgame) – ten upgrade steps
INSERT INTO `dc_item_upgrade_costs`
(`tier_id`, `upgrade_level`, `token_cost`, `essence_cost`, `ilvl_increase`, `stat_increase_percent`, `season`)
VALUES
    (2,  1, 20, 0, 6, 0.07, 1),
    (2,  2, 22, 0, 6, 0.07, 1),
    (2,  3, 24, 0, 7, 0.08, 1),
    (2,  4, 27, 0, 7, 0.08, 1),
    (2,  5, 31, 0, 7, 0.09, 1),
    (2,  6, 36, 0, 8, 0.09, 1),
    (2,  7, 42, 0, 8, 0.10, 1),
    (2,  8, 49, 0, 8, 0.10, 1),
    (2,  9, 57, 0, 9, 0.11, 1),
    (2, 10, 66, 0, 9, 0.11, 1);

-- -------------------------------------------------------------------------
-- 3) Item template realignment for Season 1
-- -------------------------------------------------------------------------
-- Leveling gear (legacy progression sets and heirlooms)
UPDATE `dc_item_templates_upgrade`
   SET `tier_id` = 1,
       `is_active` = 1
 WHERE `season` = 1
   AND `item_id` BETWEEN 50000 AND 59999;

-- Endgame gear (current heroic/raid slate) – covers the former Tier 2-4 pools
UPDATE `dc_item_templates_upgrade`
   SET `tier_id` = 2,
       `is_active` = 1
 WHERE `season` = 1
   AND `item_id` BETWEEN 60000 AND 89999;

COMMIT;

-- =========================================================================
-- IMPORT INSTRUCTIONS
--   mysql -u <user> -p acore_world < dc_item_upgrade_refresh_2tier.sql
-- =========================================================================
