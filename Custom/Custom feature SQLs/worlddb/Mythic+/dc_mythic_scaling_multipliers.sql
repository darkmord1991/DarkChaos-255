-- ============================================================================
-- Mythic+ Scaling Multipliers Table
-- ============================================================================
-- Purpose: Store difficulty scaling multipliers for creatures in Mythic+ runs
-- Allows for easy balancing without recompiling code
-- ============================================================================

DROP TABLE IF EXISTS `dc_mythic_scaling_multipliers`;

CREATE TABLE `dc_mythic_scaling_multipliers` (
    `keystoneLevel` INT UNSIGNED NOT NULL PRIMARY KEY COMMENT 'Keystone difficulty level (0-30+)',
    `hpMultiplier` FLOAT NOT NULL DEFAULT '1.0' COMMENT 'Health multiplier for creatures',
    `damageMultiplier` FLOAT NOT NULL DEFAULT '1.0' COMMENT 'Damage multiplier for creatures',
    `description` VARCHAR(100) COMMENT 'Label for this difficulty (e.g. "M+2", "M+10")',
    KEY `idx_keystoneLevel` (`keystoneLevel`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Creature scaling multipliers for each Mythic+ keystone level';

-- ============================================================================
-- Retail WoW Dragonflight-style Scaling (Season 1)
-- Source: https://www.wowhead.com/guide/mythic-plus-dungeons
-- ============================================================================

INSERT INTO `dc_mythic_scaling_multipliers` (`keystoneLevel`, `hpMultiplier`, `damageMultiplier`, `description`) VALUES
    (0,  1.00, 1.00, 'M+0/M+1 (Baseline)'),
    (1,  1.00, 1.00, 'M+1 (Baseline)'),
    (2,  1.00, 1.00, 'M+2 (0%)'),
    (3,  1.14, 1.14, 'M+3 (+14%)'),
    (4,  1.23, 1.23, 'M+4 (+23%)'),
    (5,  1.31, 1.31, 'M+5 (+31%)'),
    (6,  1.40, 1.40, 'M+6 (+40%)'),
    (7,  1.50, 1.50, 'M+7 (+50%)'),
    (8,  1.61, 1.61, 'M+8 (+61%)'),
    (9,  1.72, 1.72, 'M+9 (+72%)'),
    (10, 1.84, 1.84, 'M+10 (+84%)'),
    (11, 2.02, 2.02, 'M+11 (+102%)'),
    (12, 2.22, 2.22, 'M+12 (+122%)'),
    (13, 2.45, 2.45, 'M+13 (+145%)'),
    (14, 2.69, 2.69, 'M+14 (+169%)'),
    (15, 2.96, 2.96, 'M+15 (+196%)'),
    (16, 3.26, 3.26, 'M+16 (+226%, exponential)'),
    (17, 3.58, 3.58, 'M+17 (+258%, exponential)'),
    (18, 3.94, 3.94, 'M+18 (+294%, exponential)'),
    (19, 4.33, 4.33, 'M+19 (+333%, exponential)'),
    (20, 4.76, 4.76, 'M+20 (+376%, exponential)');

-- ============================================================================
-- Notes:
-- - M+2 through M+15 follow retail Dragonflight scaling
-- - M+16+ use exponential scaling: previous * 1.10
-- - Both HP and damage use the same multiplier for balanced difficulty
-- - Adjust these values to customize server-specific difficulty
-- ============================================================================
