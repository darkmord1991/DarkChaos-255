-- =========================================================================
-- DarkChaos Item Upgrade System - Tier Configuration Data
-- World Database - Initialization
-- =========================================================================

-- Insert Tier Definitions
INSERT INTO `dc_item_upgrade_tiers` (`tier_id`, `tier_name`, `min_ilvl`, `max_ilvl`, `max_upgrade_level`, `stat_multiplier_max`, `upgrade_cost_per_level`, `source_content`, `is_artifact`, `season`) VALUES
-- Tier 1: Leveling (Level 1-60, Quests)
(1, 'Leveling Heirloom', 1, 100, 5, 1.5, 10, 'quest', 0, 1),
-- Tier 2: Heroic (Level 60-100, Heroic Dungeons)
(2, 'Heroic Heirloom', 100, 145, 5, 1.5, 30, 'dungeon', 0, 1),
-- Tier 3: Raid (Level 100-200, Heroic Raid + Mythic Dungeons)
(3, 'Raid Heirloom', 145, 200, 5, 1.5, 75, 'raid', 0, 1),
-- Tier 4: Mythic (Level 200-255, Mythic Raid + Mythic+ Dungeons)
(4, 'Mythic Heirloom', 200, 255, 5, 1.5, 150, 'mythic', 0, 1),
-- Tier 5: Artifacts (All levels, Prestige/Exploration)
(5, 'Prestige Artifact', 1, 255, 5, 1.75, 0, 'artifact', 1, 1);

-- Insert Upgrade Costs (per tier/level combination)
-- Tier 1: 10 tokens per level (50 total per item)
INSERT INTO `dc_item_upgrade_costs` (`tier_id`, `upgrade_level`, `token_cost`, `essence_cost`, `ilvl_increase`, `stat_increase_percent`, `season`) VALUES
(1, 1, 10, 0, 5, 0.10, 1),
(1, 2, 10, 0, 5, 0.10, 1),
(1, 3, 10, 0, 5, 0.10, 1),
(1, 4, 10, 0, 5, 0.10, 1),
(1, 5, 10, 0, 5, 0.10, 1);

-- Tier 2: 30 tokens per level (150 total per item)
INSERT INTO `dc_item_upgrade_costs` (`tier_id`, `upgrade_level`, `token_cost`, `essence_cost`, `ilvl_increase`, `stat_increase_percent`, `season`) VALUES
(2, 1, 30, 0, 8, 0.10, 1),
(2, 2, 30, 0, 8, 0.10, 1),
(2, 3, 30, 0, 8, 0.10, 1),
(2, 4, 30, 0, 8, 0.10, 1),
(2, 5, 30, 0, 8, 0.10, 1);

-- Tier 3: 75 tokens per level (375 total per item)
INSERT INTO `dc_item_upgrade_costs` (`tier_id`, `upgrade_level`, `token_cost`, `essence_cost`, `ilvl_increase`, `stat_increase_percent`, `season`) VALUES
(3, 1, 75, 0, 15, 0.10, 1),
(3, 2, 75, 0, 15, 0.10, 1),
(3, 3, 75, 0, 15, 0.10, 1),
(3, 4, 75, 0, 15, 0.10, 1),
(3, 5, 75, 0, 15, 0.10, 1);

-- Tier 4: 150 tokens per level (750 total per item)
INSERT INTO `dc_item_upgrade_costs` (`tier_id`, `upgrade_level`, `token_cost`, `essence_cost`, `ilvl_increase`, `stat_increase_percent`, `season`) VALUES
(4, 1, 150, 0, 8, 0.10, 1),
(4, 2, 150, 0, 8, 0.10, 1),
(4, 3, 150, 0, 8, 0.10, 1),
(4, 4, 150, 0, 8, 0.10, 1),
(4, 5, 150, 0, 8, 0.10, 1);

-- Tier 5: Artifacts use Essence (50 essence per level = 250 total per item)
-- Note: Token cost is 0 for artifacts, they use essence_cost instead
INSERT INTO `dc_item_upgrade_costs` (`tier_id`, `upgrade_level`, `token_cost`, `essence_cost`, `ilvl_increase`, `stat_increase_percent`, `season`) VALUES
(5, 1, 0, 50, 12, 0.15, 1),
(5, 2, 0, 50, 12, 0.15, 1),
(5, 3, 0, 50, 12, 0.15, 1),
(5, 4, 0, 50, 12, 0.15, 1),
(5, 5, 0, 50, 12, 0.15, 1);

-- =========================================================================
-- SUMMARY:
-- - 5 tier definitions inserted
-- - 25 cost rows inserted (5 tiers × 5 upgrade levels)
-- - Ready for item template population (Phase 2)
-- =========================================================================
