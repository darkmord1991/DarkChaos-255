-- =====================================================================================
-- Repair: `areatrigger` geometry on the custom continents (maps 750 and 751)
--
-- NOT a Shadowfang Keep fix -- a pre-existing DC bug found while chasing the SFK exit.
--
-- ---------------------------------------------------------------------------------
-- WHAT IS WRONG
-- ---------------------------------------------------------------------------------
-- The `areatrigger` rows for maps 750 and 751 were imported with a THREE COLUMN OFFSET.
-- AreaTrigger.dbc column order is
--     ID, ContinentID, X, Y, Z, Radius, Box_Length, Box_Width, Box_Height, Box_Yaw
-- and the DB table is
--     entry, map, x, y, z, radius, length, width, height, orientation
-- which is a 1:1 mapping -- but the values landed three columns to the right:
--
--     trigger 6811   DBC: radius 8, box 0/0/0        DB: radius 0, l 0, w 0, h 8
--     trigger 6815   DBC: radius 0, box 4/10.22/15   DB: radius 0, l 0, w 0, h 0, o 4
--
-- So Radius went into `height`, Box_Length went into `orientation`, and Box_Width /
-- Box_Height / Box_Yaw fell off the end entirely.
--
-- ---------------------------------------------------------------------------------
-- WHY IT MATTERS
-- ---------------------------------------------------------------------------------
-- Player::IsInAreaTriggerRadius (Player.cpp:2256) branches on radius:
--     radius > 0  -> sphere test against radius
--     radius == 0 -> BOX test against length/2, width/2, height/2
-- With radius 0 and length/width 0, every one of these takes the box branch against a
-- zero-width box and can never contain the player. The triggers are silently inert:
-- the client sends CMSG_AREATRIGGER, the server drops it, nothing is logged above debug.
--
-- 23 of 24 triggers on map 751 and 9 of 14 on map 750 are in this state, so effectively
-- NO areatrigger has ever fired on the Lordaeron extension or Hyjal.
--
-- ---------------------------------------------------------------------------------
-- THE FIX
-- ---------------------------------------------------------------------------------
-- Every value below is read straight out of Custom/DBCs/AreaTrigger.dbc, which is
-- correct -- only the DB copy was mangled. 32 rows are repaired.
--
-- FOUR ROWS ARE DELIBERATELY NOT TOUCHED: 5049 (map 1), 4836 (451), 5048 (571) and
-- 5626 (580) are zero-volume in the DBC as well, i.e. genuinely stock quirks rather than
-- import damage. Rewriting those would be inventing data.
-- =====================================================================================

DELETE FROM `areatrigger` WHERE `entry` IN (
    6818, 6826, 6867, 6868, 6869, 6871, 6872, 6877, 6920,
    6811, 6812, 6813, 6814, 6815, 6822, 6823, 6824, 6828, 6833, 6840,
    6844, 6845, 6846, 6847, 6848, 6849, 6850, 6851, 6852, 6853, 6854, 6855);

INSERT INTO `areatrigger`
    (`entry`, `map`, `x`, `y`, `z`, `radius`, `length`, `width`, `height`, `orientation`) VALUES
    (6818, 750, 5552.09, -683.813, 335.25, 25, 0, 0, 0, 0),
    (6826, 750, 5018.91, -4563.94, 851.75, 50, 0, 0, 0, 0),
    (6867, 750, 5042.17, -2026.51, 1148.98, 5.0508, 0, 0, 0, 0),
    (6868, 750, 5030.84, -2036.3, 1378.09, 8.01933, 0, 0, 0, 0),
    (6869, 750, 4320.92, -3288.2, 1036.05, 3.78454, 2.823, 3.385, 2.795, 0),
    (6871, 750, 3943.9, -2807.49, 618.747, 3.68306, 0, 0, 0, 0),
    (6872, 750, 4664, -3686.81, 956.634, 6.78206, 0, 0, 0, 0),
    (6877, 750, 4678.15, -3682.77, 696.445, 2.23427, 5.438, 3.571, 0, 0),
    (6920, 750, 3980.63, -2924.81, 1017, 0, 18, 40, 32, 5.135),
    (6811, 751, 2924.38, -798.429, 161.611, 8, 0, 0, 0, 0),
    (6812, 751, 683.771, -912.144, 174.5, 5, 0, 0, 0, 0),
    (6813, 751, 2925.18, -820.545, 161.634, 8, 0, 0, 0, 0),
    (6814, 751, 2877.98, -839.267, 163.049, 6, 0, 0, 0, 0),
    (6815, 751, 2864.82, -823.42, 160.332, 0, 4, 10.22, 15, 0.4299),
    (6822, 751, 3237.46, -4060.6, 112.01, 0, 10, 10, 10, 0),
    (6823, 751, 3392.46, -3389.2, 143.073, 0, 22.83, 20, 34.69, 0),
    (6824, 751, 3392.56, -3369, 142.802, 0, 27.94, 20, 35.19, 0),
    (6828, 751, 1282.05, -2548.73, 85.3994, 0, 10.56, 13.03, 21.67, 0.4712),
    (6833, 751, 2843.4, -1553.26, 190.721, 7, 0, 0, 0, 0),
    (6840, 751, 3488.24, -4512.18, 158, 0, 70, 70, 42, 5.319),
    (6844, 751, 2479.34, -5495.73, 421.841, 4, 0, 0, 0, 0),
    (6845, 751, 2469.29, -5545.84, 546.101, 4, 0, 0, 0, 0),
    (6846, 751, 2362.55, -5574.54, 421.838, 4, 0, 0, 0, 0),
    (6847, 751, 2412.68, -5584.65, 546.101, 4, 0, 0, 0, 0),
    (6848, 751, 2558.37, -5612.56, 421.835, 4, 0, 0, 0, 0),
    (6849, 751, 2508.14, -5602.5, 546.101, 4, 0, 0, 0, 0),
    (6850, 751, 2441.37, -5691.42, 421.834, 4, 0, 0, 0, 0),
    (6851, 751, 2451.5, -5641.27, 546.101, 4, 0, 0, 0, 0),
    (6852, 751, 2427.67, -5548.64, 542.091, 4, 0, 0, 0, 0),
    (6853, 751, 2505.39, -5563.9, 542.089, 2, 0, 0, 0, 0),
    (6854, 751, 2419.03, -5622.17, 542.071, 3, 0, 0, 0, 0),
    (6855, 751, 2486.99, -5636.42, 542.136, 3, 0, 0, 0, 0);

-- -------------------------------------------------------------------------------------
-- Report -- all branches numeric (see the collation note in 12).
-- -------------------------------------------------------------------------------------
SELECT 'repaired rows (want 32)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `areatrigger` WHERE `entry` IN (
        6818,6826,6867,6868,6869,6871,6872,6877,6920,
        6811,6812,6813,6814,6815,6822,6823,6824,6828,6833,6840,
        6844,6845,6846,6847,6848,6849,6850,6851,6852,6853,6854,6855)
UNION ALL SELECT 'zero-volume left on map 750 (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `areatrigger` WHERE `map` = 750
      AND `radius` = 0 AND (`length` = 0 OR `width` = 0 OR `height` = 0)
UNION ALL SELECT 'zero-volume left on map 751 (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `areatrigger` WHERE `map` = 751
      AND `radius` = 0 AND (`length` = 0 OR `width` = 0 OR `height` = 0)
UNION ALL SELECT 'triggers on 750/751 that can now fire', CAST(COUNT(*) AS CHAR)
    FROM `areatrigger` WHERE `map` IN (750, 751)
      AND (`radius` > 0 OR (`length` > 0 AND `width` > 0 AND `height` > 0))
-- The four genuine stock zero-volume rows must still be there, untouched.
UNION ALL SELECT 'stock zero-volume rows left alone (want 4)', CAST(COUNT(*) AS CHAR)
    FROM `areatrigger` WHERE `entry` IN (5049, 4836, 5048, 5626);
