-- ═══════════════════════════════════════════════════════════════════════════════
-- dc_item_upgrade_item_overrides — per-item tier pin table
--
-- Replaces dc_item_templates_upgrade. An override pins a specific item to a
-- chosen tier regardless of its item level.  The C++ GetItemTier() checks this
-- table FIRST; if an item_id is found the returned tier is final (no ilvl
-- promotion).  Items NOT in this table are tiered purely by the ilvl ranges
-- in dc_item_upgrade_tiers.
--
-- When to add an override:
--   • A special item belongs to a tier whose ilvl range does not match its
--     actual item level (e.g. the heirloom shirt has no "normal" ilvl).
--   • You want to prevent an item from being auto-promoted to a higher tier
--     whose ilvl range it falls into.
--   • You want to manually exclude an item (tier_id = 0 = TIER_INVALID).
--
-- The old dc_item_templates_upgrade table is no longer queried by the C++ code
-- and can be dropped once this migration is confirmed stable.
-- ═══════════════════════════════════════════════════════════════════════════════

USE `acore_world`;

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Table
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `dc_item_upgrade_item_overrides` (
    `item_id`   INT UNSIGNED        NOT NULL COMMENT 'item_template.entry',
    `tier_id`   TINYINT UNSIGNED    NOT NULL COMMENT 'Pinned upgrade tier (0 = not upgradeable)',
    `season`    TINYINT UNSIGNED    NOT NULL DEFAULT 1,
    `is_active` TINYINT(1)          NOT NULL DEFAULT 1,
    `comment`   VARCHAR(255)        DEFAULT NULL COMMENT 'Human-readable reason for this pin',
    PRIMARY KEY (`item_id`, `season`),
    KEY `idx_active_season` (`season`, `is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  COMMENT='Per-item tier pins; overrides ilvl-based tier assignment. Replaces dc_item_templates_upgrade.';

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Seed data — only items that cannot be correctly tiered by ilvl alone
-- ─────────────────────────────────────────────────────────────────────────────

-- T3 Heirloom Shirt (item 300365): no meaningful base ilvl; must be T3 so it
-- scales with player level using the heirloom upgrade path.
INSERT INTO `dc_item_upgrade_item_overrides`
    (`item_id`, `tier_id`, `season`, `is_active`, `comment`)
VALUES
    (300365, 3, 1, 1, 'Heirloom Shirt — T3 heirloom scaling, tier cannot be derived from ilvl')
ON DUPLICATE KEY UPDATE
    `tier_id`   = VALUES(`tier_id`),
    `is_active` = VALUES(`is_active`),
    `comment`   = VALUES(`comment`);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Examples (commented out — uncomment and adjust as needed)
-- ─────────────────────────────────────────────────────────────────────────────
/*
-- Pin a specific item to T1 even though its ilvl would map to T4:
INSERT INTO `dc_item_upgrade_item_overrides` (item_id, tier_id, season, is_active, comment)
VALUES (400001, 1, 1, 1, 'Emberwood ring — keep at T1 for balance');

-- Exclude an item from the upgrade system entirely (tier 0 = TIER_INVALID):
INSERT INTO `dc_item_upgrade_item_overrides` (item_id, tier_id, season, is_active, comment)
VALUES (49623, 0, 1, 1, 'Shadowmourne — not upgradeable by design');
*/
