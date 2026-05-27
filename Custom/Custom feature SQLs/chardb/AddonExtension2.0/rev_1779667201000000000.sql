-- Persist HLBG secondary and tertiary affix slots in winner history.

ALTER TABLE `dc_hlbg_winner_history`
    ADD COLUMN `affix_secondary` TINYINT UNSIGNED NOT NULL DEFAULT 0 AFTER `affix`,
    ADD COLUMN `affix_tertiary` TINYINT UNSIGNED NOT NULL DEFAULT 0 AFTER `affix_secondary`;
