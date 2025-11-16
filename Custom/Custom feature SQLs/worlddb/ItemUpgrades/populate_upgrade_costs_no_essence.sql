-- Tier 1: Leveling (6 upgrade levels)
INSERT INTO `dc_item_upgrade_costs` (`tier_id`, `upgrade_level`, `token_cost`, `essence_cost`, `gold_cost`) VALUES
(1, 1, 10, 0, 0),
(1, 2, 20, 0, 0),
(1, 3, 30, 0, 0),
(1, 4, 40, 0, 0),
(1, 5, 50, 0, 0),
(1, 6, 60, 0, 0);

-- Tier 2: Heroic (15 upgrade levels, starting at ilvl 213)
INSERT INTO `dc_item_upgrade_costs` (`tier_id`, `upgrade_level`, `token_cost`, `essence_cost`, `gold_cost`) VALUES
(2, 1, 15, 0, 0),
(2, 2, 30, 0, 0),
(2, 3, 45, 0, 0),
(2, 4, 60, 0, 0),
(2, 5, 75, 0, 0),
(2, 6, 90, 0, 0),
(2, 7, 105, 0, 0),
(2, 8, 120, 0, 0),
(2, 9, 135, 0, 0),
(2, 10, 150, 0, 0),
(2, 11, 165, 0, 0),
(2, 12, 180, 0, 0),
(2, 13, 195, 0, 0),
(2, 14, 210, 0, 0),
(2, 15, 225, 0, 0);
