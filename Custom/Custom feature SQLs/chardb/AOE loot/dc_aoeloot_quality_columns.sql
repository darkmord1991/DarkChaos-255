-- =============================================================================
-- AOE Loot Quality Statistics Columns
-- =============================================================================
-- Adds quality breakdown tracking for looted and filtered items
-- Run on: acore_characters
-- =============================================================================

-- Add quality breakdown columns for looted items
ALTER TABLE `dc_aoeloot_detailed_stats`
    ADD COLUMN `quality_poor` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Gray items looted' AFTER `upgrades`,
    ADD COLUMN `quality_common` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'White items looted' AFTER `quality_poor`,
    ADD COLUMN `quality_uncommon` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Green items looted' AFTER `quality_common`,
    ADD COLUMN `quality_rare` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Blue items looted' AFTER `quality_uncommon`,
    ADD COLUMN `quality_epic` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Purple items looted' AFTER `quality_rare`,
    ADD COLUMN `quality_legendary` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Orange items looted' AFTER `quality_epic`;

-- Add filtered/skipped items columns (items that were filtered due to quality filter)
ALTER TABLE `dc_aoeloot_detailed_stats`
    ADD COLUMN `filtered_poor` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Gray items filtered' AFTER `quality_legendary`,
    ADD COLUMN `filtered_common` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'White items filtered' AFTER `filtered_poor`,
    ADD COLUMN `filtered_uncommon` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Green items filtered' AFTER `filtered_common`,
    ADD COLUMN `filtered_rare` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Blue items filtered' AFTER `filtered_uncommon`,
    ADD COLUMN `filtered_epic` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Purple items filtered' AFTER `filtered_rare`,
    ADD COLUMN `filtered_legendary` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Orange items filtered' AFTER `filtered_epic`;

-- Add indexes for quality-based leaderboard queries
CREATE INDEX `idx_quality_epic` ON `dc_aoeloot_detailed_stats` (`quality_epic`);
CREATE INDEX `idx_quality_rare` ON `dc_aoeloot_detailed_stats` (`quality_rare`);
CREATE INDEX `idx_quality_legendary` ON `dc_aoeloot_detailed_stats` (`quality_legendary`);
