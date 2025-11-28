-- ====================================================================================
-- HEIRLOOM TIER 3 BONDING FIX - Change bonding from 1 (BoP) to 0 (Not Bound)
-- ====================================================================================
-- Date: November 26, 2025
-- Database: acore_world
--
-- ISSUE:
--   Heirloom items with bonding=1 (Bind on Pickup) trigger client-side bind confirmation
--   dialogs. Since heirloom items are account-bound by their Quality=7 flag, they don't
--   need bonding=1. This causes a client-side Lua error: "attempt to index field '?' (a nil value)"
--
-- SOLUTION:
--   Change all heirloom item entries (300332-300364) to bonding=0 (Not Bound).
--   The client will respect the Quality=7 (ITEM_QUALITY_HEIRLOOM) flag automatically,
--   treating these items as account-bound without triggering bind confirmations.
--
-- REFERENCES:
--   - Error in UIParent.lua:583 when LOOT_BIND_CONFIRM event fires
--   - Items need bonding=0 for heirloom quality items
--   - Quality=7 automatically marks items as account-bound on the client side
-- ====================================================================================

UPDATE `item_template` SET `bonding`=0 WHERE `entry` IN (
    300332, 300333, 300334, 300335, 300336, 300337, 300338, 300339, 300340, 300341,
    300342, 300343, 300344, 300345, 300346, 300347, 300348, 300349, 300350, 300351,
    300352, 300353, 300354, 300355, 300356, 300357, 300358, 300359, 300360, 300361,
    300362, 300363, 300364
);

-- Verify the update
SELECT `entry`, `name`, `Quality`, `bonding`, `Flags` FROM `item_template` WHERE `entry` IN (
    300332, 300333, 300334, 300335, 300336, 300337, 300338, 300339, 300340, 300341,
    300342, 300343, 300344, 300345, 300346, 300347, 300348, 300349, 300350, 300351,
    300352, 300353, 300354, 300355, 300356, 300357, 300358, 300359, 300360, 300361,
    300362, 300363, 300364
) ORDER BY `entry`;
