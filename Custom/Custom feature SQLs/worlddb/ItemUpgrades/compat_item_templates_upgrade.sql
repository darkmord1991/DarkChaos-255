-- ─────────────────────────────────────────────────────────────────────────────
-- BACKWARD-COMPAT: create dc_item_templates_upgrade if it is missing
--
-- The pre-refactor binary queries this table on startup.  If it is absent the
-- server crashes with [1146] / "DB structure not up to date".
-- Creating it empty satisfies the query; the new binary (after recompile)
-- queries dc_item_upgrade_item_overrides instead and ignores this table.
-- Safe to drop after the new binary has been deployed.
-- ─────────────────────────────────────────────────────────────────────────────

USE `acore_world`;

CREATE TABLE IF NOT EXISTS `dc_item_templates_upgrade` (
    `item_id`   INT UNSIGNED        NOT NULL,
    `tier_id`   TINYINT UNSIGNED    NOT NULL DEFAULT 1,
    `is_active` TINYINT(1)          NOT NULL DEFAULT 1,
    `season`    TINYINT UNSIGNED    NOT NULL DEFAULT 1,
    PRIMARY KEY (`item_id`, `season`),
    KEY `idx_active_season` (`season`, `is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  COMMENT='Legacy stub — kept so the pre-refactor binary can start. Drop after recompile.';
