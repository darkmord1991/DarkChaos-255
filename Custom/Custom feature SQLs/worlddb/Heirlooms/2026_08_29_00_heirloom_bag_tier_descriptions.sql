-- ====================================================================================
-- HEIRLOOM ADVENTURER'S HAVERSACK - TIER-AWARE FLAVOUR TEXT
-- ====================================================================================
-- Database: acore_world
--
-- All six haversack tiers shipped with the same placeholder description ("Heirloom
-- Bag"), so nothing in the tooltip told the player the pack grows. The slot count is
-- NOT a live field - heirloom_scaling_255.cpp swaps the equipped bag for the next
-- item_template row (300366 -> 302607 -> ... -> 302611) as the owner levels, per the
-- tier table in that file:
--
--     300366   16 slots   level   1
--     302607   20 slots   level  26
--     302608   24 slots   level  51
--     302609   28 slots   level  76
--     302610   32 slots   level 101
--     302611   36 slots   level 126   (36 is the client's per-bag hard cap)
--
-- Each row now names its OWN next step, so the tooltip stays accurate after a swap.
-- Keep this file in sync with HEIRLOOM_BAG_TIERS[] if the level thresholds move.
-- ====================================================================================

UPDATE `item_template` SET `description` = 'Grows with its bearer. Reach level 26 for 20 slots, and again every 25 levels up to 36.' WHERE `entry` = 300366;
UPDATE `item_template` SET `description` = 'Grows with its bearer. Reach level 51 for 24 slots, and again every 25 levels up to 36.' WHERE `entry` = 302607;
UPDATE `item_template` SET `description` = 'Grows with its bearer. Reach level 76 for 28 slots, and again every 25 levels up to 36.' WHERE `entry` = 302608;
UPDATE `item_template` SET `description` = 'Grows with its bearer. Reach level 101 for 32 slots, and again at level 126 for 36.' WHERE `entry` = 302609;
UPDATE `item_template` SET `description` = 'Grows with its bearer. Reach level 126 for 36 slots, the largest pack you can carry.' WHERE `entry` = 302610;
UPDATE `item_template` SET `description` = 'Grown to its full size - 36 slots is the largest pack you can carry.' WHERE `entry` = 302611;
