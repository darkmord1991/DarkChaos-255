-- Heirloom Adventurer Shirt (300365) - wire up level scaling.
--
-- item_template.ScalingStatDistribution and .ScalingStatValue are both 0, so the
-- shirt has always applied its literal stat_value1 (+10 Stamina) at every level.
--
-- !! APPLY THE RENUMBERED ScalingStatDistribution.dbc FIRST !!  The custom rows
-- moved from 300332-300381 to 500-548 because item_template.ScalingStatDistribution
-- is a SIGNED SMALLINT (max 32767) and ObjectMgr.cpp:3427 reads it with
-- Get<uint16>(). The shirt row is now 533.
--
-- ScalingStatValue = 1 selects ssdMultiplier[0] and sets no armor bits, so the
-- shirt keeps its flat 20 armor.
--
-- Resulting stats (server and client tooltip agree):
--   L20  STR+2 AGI+2 INT+2 STA+2 SPI+1
--   L60  STR+9 AGI+9 INT+9 STA+7 SPI+5
--   L80  STR+24 AGI+24 INT+24 STA+19 SPI+14
--   L120 STR+36 AGI+36 INT+36 STA+29 SPI+22
--   L255 STR+86 AGI+86 INT+86 STA+69 SPI+51
--
-- stat_type1..5 below are only a fallback - with SSD set both the core and the
-- client read the stat list out of the DBC and ignore them.

UPDATE `item_template` SET
    `ScalingStatDistribution` = 533,
    `ScalingStatValue`        = 1,
    `stat_type1`  = 4, `stat_value1` = 24,
    `stat_type2`  = 3, `stat_value2` = 24,
    `stat_type3`  = 5, `stat_value3` = 24,
    `stat_type4`  = 7, `stat_value4` = 19,
    `stat_type5`  = 6, `stat_value5` = 14
WHERE `entry` = 300365;

SELECT `entry`, `name`, `ScalingStatDistribution` AS SSD, `ScalingStatValue` AS SSV, `armor`
FROM `item_template` WHERE `entry` = 300365;
