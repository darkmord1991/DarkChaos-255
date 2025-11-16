-- Tier 1: Leveling items (6 max upgrade levels)
INSERT INTO `dc_item_upgrade_tiers` (`tier_id`, `tier_name`, `description`, `min_item_level`, `max_item_level`, `is_active`) VALUES
(1, 'Leveling', 'Basic leveling gear with 6 upgrade levels', 1, 78, 1);

-- Tier 2: Heroic items (15 max upgrade levels, starting at ilvl 213)
INSERT INTO `dc_item_upgrade_tiers` (`tier_id`, `tier_name`, `description`, `min_item_level`, `max_item_level`, `is_active`) VALUES
(2, 'Heroic', 'Heroic quality gear with 15 upgrade levels', 213, 226, 1);
