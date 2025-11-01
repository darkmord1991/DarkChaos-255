-- =====================================================
-- DarkChaos-255 Custom Achievement Categories
-- =====================================================
-- These categories will appear in the Achievement UI
-- Parent=0 means top-level category
-- Parent=CategoryID means subcategory

-- Insert custom categories into achievement_category_dbc
INSERT INTO `achievement_category_dbc` (`ID`, `Parent`, `Name_Lang_enUS`, `Name_Lang_enGB`, `Ui_Order`) VALUES
-- Main DarkChaos Category
(10000, -1, 'Dark Chaos', 'Dark Chaos', 100),

-- Subcategories under Dark Chaos
(10001, 10000, 'Custom Zones', 'Custom Zones', 1),
(10002, 10000, 'Custom Dungeons', 'Custom Dungeons', 2),
(10003, 10000, 'Hinterlands Battleground', 'Hinterlands Battleground', 3),
(10004, 10000, 'Prestige System', 'Prestige System', 4),
(10005, 10000, 'Collections', 'Collections', 5),
(10006, 10000, 'Server Firsts', 'Server Firsts', 6),
(10007, 10000, 'Challenge Modes', 'Challenge Modes', 7),
(10008, 10000, 'Level 255', 'Level 255', 8),
(10009, 10000, 'Custom Quests', 'Custom Quests', 9),
(10010, 10000, 'Feats of Strength', 'Feats of Strength', 10);
