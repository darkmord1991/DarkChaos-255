-- Restructure dc_heirloom_upgrade_costs: add tier_id to primary key
-- so each heirloom tier has its own independent cost curve.
--
-- Before:  PK = (upgrade_level)          — single flat table, shared by all heirlooms
-- After:   PK = (tier_id, upgrade_level) — per-tier subtables
--
-- Existing tier 3 rows are preserved with the same values.
-- Tier 10 (Frontier Heirloom / Heartstone of Nordrassil) added with 5 stages.

DROP TABLE IF EXISTS `dc_heirloom_upgrade_costs`;
CREATE TABLE `dc_heirloom_upgrade_costs` (
    `tier_id`       tinyint unsigned NOT NULL DEFAULT 3,
    `upgrade_level` tinyint unsigned NOT NULL,
    `token_cost`    int unsigned     NOT NULL DEFAULT 0,
    `essence_cost`  int unsigned     NOT NULL DEFAULT 0,
    `description`   varchar(64)      DEFAULT NULL,
    PRIMARY KEY (`tier_id`, `upgrade_level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =============================================================================
-- Tier 3: Heirloom Adventurer's Shirt — 15 levels
-- Values match live dc_heirloom_upgrade_costs rows (server is authoritative).
-- =============================================================================
INSERT INTO `dc_heirloom_upgrade_costs`
    (`tier_id`, `upgrade_level`, `token_cost`, `essence_cost`, `description`)
VALUES
(3,  1, 0, 50,   'Initiate - Package Selection'),
(3,  2, 0, 75,   NULL),
(3,  3, 0, 100,  NULL),
(3,  4, 0, 150,  NULL),
(3,  5, 1, 200,  'Adept'),
(3,  6, 1, 275,  NULL),
(3,  7, 1, 350,  NULL),
(3,  8, 2, 450,  NULL),
(3,  9, 2, 575,  NULL),
(3, 10, 3, 725,  'Expert'),
(3, 11, 3, 900,  NULL),
(3, 12, 4, 1100, NULL),
(3, 13, 4, 1350, NULL),
(3, 14, 5, 1650, NULL),
(3, 15, 5, 2050, 'Master - Maximum Level');

-- =============================================================================
-- Tier 10: Frontier Heirloom (Heartstone of Nordrassil) — 5 stages
-- Budget values reuse the first 5 levels of the shared stat-package scale,
-- but the cost curve can diverge from tier 3 here in the future if desired.
-- =============================================================================
INSERT INTO `dc_heirloom_upgrade_costs`
    (`tier_id`, `upgrade_level`, `token_cost`, `essence_cost`, `description`)
VALUES
(10, 1, 0, 50,  'Stage 1 - Package Selection'),
(10, 2, 0, 75,  NULL),
(10, 3, 0, 100, NULL),
(10, 4, 0, 150, NULL),
(10, 5, 1, 200, 'Stage 5 - Maximum');
