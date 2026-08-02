-- ---------------------------------------------------------------------------
-- 207  Map 750 -- put the floating and buried mining nodes back on the ground
-- ---------------------------------------------------------------------------
-- 219 ore-node spawns across 131 positions do not sit on map 750's
-- terrain: 74 positions are BURIED (the ground is above them, so the node
-- is invisible and unmineable) and 57 are FLOATING. Worst cases are
-- -513.8y underground and +57.1y in the air.
--
-- WHY -- and why "delete them all and re-import from one source" would NOT have
-- worked. The node z values are not corrupt. 418 of the 718 nodes were cloned
-- from stock Kalimdor (entry + 3,900,000) and every one of them still matches
-- its map-1 original to the last decimal -- verified, 418/418 identical z.
-- They are Blizzard's exact coordinates.
--
-- What changed is the GROUND. Map 750 is not Kalimdor: Map.dbc gives it its own
-- terrain directory, DCMountHyjal, and that heightmap was re-authored when the
-- half-baked borders were replaced with sea. Sampling the same point in stock
-- Kalimdor and in map 750's terrain differs by up to 168y. So a node imported
-- with a perfectly good Kalimdor z lands wherever map 750's own landscape
-- happens to be -- sometimes 500y out. Re-importing from any database would
-- reproduce exactly the same wrong heights, because no database knows what the
-- terrain looks like. The correct z can only come from the terrain itself.
--
-- WHERE THE NUMBERS COME FROM. Each new_z is the real terrain height at that
-- node's x/y, read out of the ADT files and computed with the SAME arithmetic
-- the worldserver uses, so the node ends up exactly where a player stands:
--   * src/tools/map_extractor/adt.h + System.cpp  -- MCNK/MCVT -> V9/V8 grids
--   * GridTerrainData::getHeightFromFloat         -- grid lookup, triangle pick
-- Terrain source: K:\Dark-Chaos\retailextracts\dc_hyjal_sea_335 (the expanded
-- 144-tile build; it is identical to the older 81-tile dcmounthyjal set on
-- every tile they share, and adds the tiles the Darkshore side needs).
--
-- CALIBRATION, so these numbers can be trusted: of the 484 node positions, 347
-- already sit within 2y of the computed terrain and most match to within 0.05y.
-- A sampler that reproduces 347 known-good heights to two decimals is not
-- guessing about the other 131.
--
-- WHAT IS DELIBERATELY NOT TOUCHED:
--   * 2 positions over a terrain HOLE -- a hole means the ADT surface is absent
--     (cave mouth, overhang) and the real floor is a WMO. Snapping those to the
--     heightmap would yank a cave node up through the rock.
--   * 1 position outside the authored tiles.
--   * 3 positions (8 spawns) that float but sit inside a WMO bounding box, i.e.
--     they may legitimately stand on a structure.
--   * 347 positions already on the ground.
-- Only x/y stay authoritative; nothing is moved horizontally.
--
-- Apply against acore_world, then restart worldserver. Idempotent -- it sets
-- absolute values, so re-running changes nothing.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) The measured ground heights (kept as a table so the change is auditable)
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS `dc_map750_node_ground`;

CREATE TABLE `dc_map750_node_ground` (
  `px`     DOUBLE NOT NULL,
  `py`     DOUBLE NOT NULL,
  `old_z`  DOUBLE NOT NULL,
  `new_z`  DOUBLE NOT NULL,
  `dz`     DOUBLE NOT NULL,
  `spawns` INT    NOT NULL,
  PRIMARY KEY (`px`, `py`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `dc_map750_node_ground` (`px`,`py`,`old_z`,`new_z`,`dz`,`spawns`) VALUES
  (3253.48, -4371.95, 126.52, 243.9764, -117.46, 3),
  (3271.04, -745.76, 157.88, 280.1515, -122.27, 2),
  (3369.31, -782.57, 170.34, 281.2923, -110.95, 2),
  (3371.16, -582.34, 187.62, 214.8752, -27.26, 2),
  (3609.35, 382.27, 24.56, 12.8182, 11.74, 2),
  (3753.26, 618.90, 14.71, 7.5841, 7.13, 1),
  (3826.96, 240.72, 5.31, 1.0928, 4.22, 2),
  (3944.90, 241.40, 23.52, 21.4957, 2.02, 1),
  (4210.82, -5213.95, 116.94, 133.4830, -16.54, 2),
  (4242.91, -2339.80, 1151.26, 1179.2590, -28.00, 1),
  (4251.63, -3925.23, 946.65, 978.0264, -31.38, 3),
  (4303.28, -4317.09, 919.43, 914.5579, 4.87, 4),
  (4316.22, -4112.67, 950.76, 981.7028, -30.94, 4),
  (4349.52, -4551.59, 916.66, 920.0089, -3.35, 4),
  (4374.90, 568.30, 58.70, 56.2208, 2.48, 1),
  (4402.74, -4176.74, 958.78, 932.5747, 26.21, 3),
  (4420.88, 826.08, 15.33, -0.4457, 15.78, 1),
  (4461.34, -4291.08, 918.87, 909.2047, 9.67, 3),
  (4476.95, -4007.41, 953.97, 968.7093, -14.74, 4),
  (4524.30, 949.84, -39.00, 28.2440, -67.24, 1),
  (4535.69, 902.66, 7.68, 19.6137, -11.93, 1),
  (4553.72, 134.69, 61.47, 58.4874, 2.98, 1),
  (4562.35, 820.46, 3.32, 10.3637, -7.04, 1),
  (4568.27, 998.60, -24.93, 25.7508, -50.68, 1),
  (4580.22, 709.54, 25.27, 0.4591, 24.81, 1),
  (4583.18, -3926.66, 944.87, 976.8337, -31.96, 1),
  (4593.95, -2.97, 71.38, 126.1562, -54.78, 2),
  (4604.01, -4412.63, 895.80, 899.8230, -4.02, 4),
  (4606.25, -16.06, 72.86, 108.2216, -35.36, 1),
  (4619.51, -4749.00, 896.16, 889.0264, 7.13, 3),
  (4621.02, 900.49, -4.39, 36.9842, -41.37, 1),
  (4622.56, 926.28, -43.37, 55.6265, -99.00, 1),
  (4650.94, -4615.60, 884.62, 919.5486, -34.93, 3),
  (4661.66, 961.58, -37.01, 8.2626, -45.27, 1),
  (4662.22, 766.79, 30.52, -6.1276, 36.65, 1),
  (4705.70, -4935.97, 908.93, 895.2421, 13.69, 3),
  (4707.35, -4339.67, 917.00, 938.0686, -21.07, 3),
  (4751.59, -878.72, 358.64, 343.9082, 14.73, 2),
  (4753.38, -589.89, 283.66, 412.9995, -129.34, 3),
  (4760.73, -579.28, 281.06, 383.2773, -102.22, 3),
  (4762.79, -550.72, 285.20, 356.6751, -71.48, 3),
  (4765.10, -4964.92, 896.76, 904.3342, -7.57, 4),
  (4776.80, 379.23, 46.08, 35.8394, 10.24, 1),
  (4787.53, 766.54, 8.54, -3.5439, 12.08, 1),
  (4788.81, -536.96, 286.51, 320.7296, -34.22, 3),
  (4802.70, -557.87, 275.07, 317.9040, -42.83, 3),
  (4845.31, -4821.64, 894.40, 881.8353, 12.56, 4),
  (4854.44, 535.21, 10.56, 1.8109, 8.75, 1),
  (4855.59, 722.66, 5.87, -3.7154, 9.59, 1),
  (4860.06, -4527.42, 891.68, 870.1867, 21.49, 3),
  (4907.07, -2214.38, 1115.71, 1448.5853, -332.88, 1),
  (5016.97, -2005.27, 1148.98, 1389.2318, -240.25, 1),
  (5032.76, -557.99, 300.95, 336.0224, -35.07, 3),
  (5039.02, -2079.90, 1274.52, 1369.3235, -94.80, 1),
  (5049.82, -2018.10, 1272.60, 1373.9063, -101.31, 1),
  (5062.96, -2210.68, 1138.88, 1389.9261, -251.05, 1),
  (5069.84, -538.98, 314.15, 335.6832, -21.53, 2),
  (5122.07, 354.77, 11.82, 1.7372, 10.08, 1),
  (5129.34, 146.26, 48.55, 44.0414, 4.51, 1),
  (5131.26, -426.74, 301.30, 441.8977, -140.60, 2),
  (5153.76, 458.86, 26.07, 7.8800, 18.19, 1),
  (5161.25, 31.97, 44.84, -6.6880, 51.53, 1),
  (5163.09, 716.39, -9.10, -1.7091, -7.39, 2),
  (5214.68, 316.01, 43.32, 20.1023, 23.22, 1),
  (5256.66, -5014.92, 867.90, 873.5836, -5.68, 2),
  (5278.41, -541.09, 273.12, 321.9883, -48.87, 3),
  (5315.99, -588.57, 247.06, 333.1212, -86.06, 2),
  (5381.58, -554.62, 272.88, 356.0932, -83.21, 2),
  (5393.58, 149.12, 41.42, 18.1094, 23.31, 2),
  (5573.86, 468.62, 20.34, 13.5588, 6.78, 2),
  (5631.78, -3292.44, 1568.07, 1629.5231, -61.45, 1),
  (5663.70, -3274.18, 1568.15, 1629.6138, -61.46, 1),
  (5664.99, 351.46, 17.83, 11.3944, 6.44, 1),
  (5667.13, -3270.84, 1582.94, 1629.8437, -46.90, 1),
  (5682.87, -3242.78, 1582.93, 1688.5679, -105.64, 1),
  (5712.04, -3246.46, 1582.70, 1657.5977, -74.90, 1),
  (5717.19, -3245.58, 1582.63, 1655.2373, -72.61, 1),
  (5738.26, 499.74, 6.80, 4.4967, 2.30, 2),
  (5753.65, -155.07, 13.77, 216.6158, -202.85, 1),
  (5776.75, 49.06, 45.81, 17.9346, 27.88, 2),
  (5788.55, 180.10, 41.59, 37.6993, 3.89, 1),
  (5818.03, -88.58, 23.43, 98.5104, -75.08, 1),
  (5822.17, -986.86, 418.93, 412.3794, 6.55, 3),
  (5845.18, -171.19, 15.24, 202.6378, -187.40, 1),
  (5896.12, -4029.86, 597.13, 1110.9684, -513.84, 2),
  (5954.85, -58.27, 47.11, 45.0731, 2.04, 2),
  (6004.19, -47.53, 23.18, -33.9137, 57.09, 1),
  (6030.14, -4209.83, 628.19, 804.1538, -175.96, 2),
  (6060.44, 90.78, 44.69, 31.7110, 12.98, 1),
  (6132.12, -4236.62, 654.10, 777.4621, -123.36, 2),
  (6139.67, -4271.55, 657.49, 748.5848, -91.09, 2),
  (6140.81, -77.58, 37.69, -15.4103, 53.10, 1),
  (6176.48, 463.12, 24.82, 17.0261, 7.79, 1),
  (6183.53, 107.97, 31.58, 18.6556, 12.92, 1),
  (6276.09, 152.29, 38.20, 16.5858, 21.61, 1),
  (6314.40, 83.03, 44.35, 18.2516, 26.10, 1),
  (6325.67, -1790.15, 421.58, 623.8612, -202.28, 3),
  (6335.66, -169.05, 47.58, 50.5014, -2.92, 1),
  (6354.29, 119.99, 22.10, 13.5363, 8.56, 1),
  (6355.19, -94.28, 28.08, -11.9982, 40.08, 1),
  (6359.27, -170.51, 44.61, 49.4435, -4.83, 1),
  (6556.81, -5255.44, 754.40, 924.6904, -170.29, 2),
  (6573.82, -218.57, 48.15, 40.5610, 7.59, 1),
  (6585.01, 291.72, 39.61, 20.0789, 19.53, 1),
  (6593.73, -5284.18, 754.34, 939.4914, -185.15, 2),
  (6650.88, -5297.41, 753.44, 894.9027, -141.46, 2),
  (6657.28, 89.49, 34.87, 10.2620, 24.61, 1),
  (6716.60, -637.98, 69.57, 223.2317, -153.66, 1),
  (6717.78, -632.35, 69.70, 219.2806, -149.58, 2),
  (6748.01, -706.95, 70.22, 265.0988, -194.88, 1),
  (6753.14, -688.31, 89.66, 264.1737, -174.51, 1),
  (6758.47, -688.70, 89.41, 256.2723, -166.86, 1),
  (6780.64, -702.90, 73.93, 227.4099, -153.48, 1),
  (6782.25, -644.61, 66.42, 153.4947, -87.07, 1),
  (6793.42, -739.79, 69.67, 247.3905, -177.72, 1),
  (6798.90, 231.38, 25.71, 21.9327, 3.78, 1),
  (6811.93, -544.64, 61.43, 29.2094, 32.22, 1),
  (6817.57, -663.55, 64.16, 172.3669, -108.21, 1),
  (6822.61, -654.83, 86.77, 141.1425, -54.37, 1),
  (6828.22, -761.09, 59.05, 282.5331, -223.48, 1),
  (6836.17, -291.01, 40.54, 9.0566, 31.48, 1),
  (6840.30, -674.38, 64.10, 120.7689, -56.67, 1),
  (6862.49, -664.13, 83.77, 108.7028, -24.93, 1),
  (6898.08, -588.40, 30.67, -6.3632, 37.03, 1),
  (7063.30, -212.51, 48.61, 6.9582, 41.65, 2),
  (7093.88, -456.05, 32.29, 13.0151, 19.27, 1),
  (7116.58, -332.78, 36.59, 5.1114, 31.48, 1),
  (7149.56, -284.31, 36.52, -9.7494, 46.27, 1),
  (7193.37, -473.36, 37.76, 31.3640, 6.40, 2),
  (7196.19, -576.26, 38.99, 35.5372, 3.45, 2),
  (7388.04, -370.99, 5.46, -21.5690, 27.03, 2);

-- ---------------------------------------------------------------------------
-- B) Snap the nodes
-- ---------------------------------------------------------------------------
-- The join key is ROUND(...,1) on both sides. That is not a tolerance window --
-- it exactly reproduces the grouping that produced these rows, so one spawn can
-- never match two keys (checked: no duplicate keys in the set above).
--
-- The gameobject_template filter matters: several of these positions also hold
-- non-mining objects, and only the ore nodes should move.
-- ---------------------------------------------------------------------------
UPDATE `gameobject` g
  JOIN `gameobject_template` gt ON gt.`entry` = g.`id`
  JOIN `dc_map750_node_ground` k
    ON ROUND(g.`position_x`, 1) = ROUND(k.`px`, 1)
   AND ROUND(g.`position_y`, 1) = ROUND(k.`py`, 1)
   SET g.`position_z` = k.`new_z`
 WHERE g.`map` = 750
   AND gt.`type` = 3
   AND gt.`Data0` IN (38, 39, 40, 41, 42, 379, 380, 400, 939, 1861, 1874);

-- ---------------------------------------------------------------------------
-- Verification after applying + restart:
--   SELECT COUNT(*) FROM dc_map750_node_ground;                       -- 131
--   SELECT SUM(spawns) FROM dc_map750_node_ground;                    -- 219
--
--   -- every listed node now sits at its measured ground height (expect 0):
--   SELECT COUNT(*) FROM gameobject g
--     JOIN gameobject_template gt ON gt.entry = g.id
--     JOIN dc_map750_node_ground k
--       ON ROUND(g.position_x,1) = ROUND(k.px,1)
--      AND ROUND(g.position_y,1) = ROUND(k.py,1)
--    WHERE g.map = 750 AND gt.type = 3
--      AND gt.Data0 IN (38,39,40,41,42,379,380,400,939,1861,1874)
--      AND ABS(g.position_z - k.new_z) > 0.01;
--
--   -- what moved the most, for spot-checking in game:
--   SELECT px, py, old_z, new_z, dz FROM dc_map750_node_ground
--    ORDER BY ABS(dz) DESC LIMIT 10;
--
-- In game: no ore vein should hang in the air or be missing where the map shows
-- one. The worst offenders are good places to check -- (5896, -4030) was 514y
-- below its ground, and the Darkshore ridge around (6750..6900, -630..-760) had
-- a whole cluster of veins sunk 100-220y into the hillside.
--
-- NOT COVERED HERE: this file only moves MINING nodes, which is what was
-- reported. The same measurement can be run for the other 3,698 gameobjects on
-- map 750 -- the terrain sampler does not care what kind of object it is.
-- ---------------------------------------------------------------------------
