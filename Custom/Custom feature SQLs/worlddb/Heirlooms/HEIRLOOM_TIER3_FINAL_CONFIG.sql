-- ====================================================================================
-- HEIRLOOM TIER 3 - FINAL CONFIGURATION
-- ====================================================================================
-- Date: November 26, 2025
-- Database: acore_world
--
-- Only items 300365 and 300366 are given from the chest
-- - 300365: Heirloom Shirt (cosmetic, transmog)
-- - 300366: Heirloom Bag (epic quality, not heirloom)
--
-- All other items (300332-300364) are left as-is for later implementation
-- ====================================================================================

-- Update 300366 to be Epic quality (not heirloom)
UPDATE `item_template` SET `Quality`=4 WHERE `entry`=300366;

-- Verify the update
SELECT `entry`, `name`, `Quality`, `bonding`, `Flags` FROM `item_template` 
WHERE `entry` IN (300365, 300366) ORDER BY `entry`;
