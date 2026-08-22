-- =====================================================================
-- .tele points for Naxx-40 (map 2921) and its two entrances
-- =====================================================================
-- Two already exist and are NOT touched:
--   10617  dcnaxxin   map 2921 @ 2999.19, -3441.73, 293.92   (entrance chamber)
--   10618  dcnaxx     map 2921 @ 2995.22, -3047.83, 118.38   (ground level below)
--
-- Everything below uses free ids 10650+ (current MAX(id) = 10649).
-- All coordinates are taken from live rows, not estimated:
--   n40 / n40in   = the exact arrival point both entrance scripts teleport to
--   n40rune       = GO 361001 "Teleport To Naxxramas" spawn on map 751
--   n40strath     = creature 351097 "Naxx40 Strath Entrance Trigger" on map 329
--   the boss points are the module's own spawn positions on 2921
-- =====================================================================

DELETE FROM `game_tele` WHERE `id` BETWEEN 10650 AND 10668;
INSERT INTO `game_tele` (`id`, `position_x`, `position_y`, `position_z`, `orientation`, `map`, `name`) VALUES
-- entrances
(10650, 3005.51, -3434.64, 304.195, 6.2831, 2921, 'n40'),          -- arrival point used by both entrance scripts
(10651, 3123.26, -3869.36, 138.34,  0.2175,  751, 'n40rune'),      -- runestone, Plaguewood (DC Eastern Plaguelands)
(10652, 3929.06, -3372.12, 119.653, 4.71395, 329, 'n40strath'),    -- invisible trigger at the Baron end of Stratholme
-- wings / bosses on map 2921
(10653, 3316.47, -3476.23, 287.26,  3.180,  2921, 'n40anub'),      -- Anub'Rekhan       (Arachnid)
(10654, 3353.25, -3620.10, 261.08,  4.730,  2921, 'n40faerlina'),  -- Grand Widow Faerlina
(10655, 3511.38, -3921.58, 299.51,  1.920,  2921, 'n40maexxna'),   -- Maexxna
(10656, 2675.49, -3491.24, 261.53,  6.120,  2921, 'n40noth'),      -- Noth the Plaguebringer (Plague)
(10657, 2793.86, -3707.38, 276.63,  0.593,  2921, 'n40heigan'),    -- Heigan the Unclean
(10658, 2909.00, -3997.41, 274.19,  1.571,  2921, 'n40loatheb'),   -- Loatheb
(10659, 2755.56, -3098.04, 267.86,  6.270,  2921, 'n40razuvious'), -- Instructor Razuvious (Military)
(10660, 2642.14, -3386.96, 285.49,  6.266,  2921, 'n40gothik'),    -- Gothik the Harvester
(10661, 3308.46, -3232.08, 294.24,  3.010,  2921, 'n40patchwerk'), -- Patchwerk (Construct)
(10662, 3205.45, -3341.86, 320.18,  3.263,  2921, 'n40grobbulus'), -- Grobbulus
(10663, 3283.09, -3156.96, 297.79,  3.822,  2921, 'n40gluth'),     -- Gluth
(10664, 3513.84, -2926.55, 302.91,  4.136,  2921, 'n40thaddius'),  -- Thaddius
(10665, 3522.39, -5236.78, 137.71,  4.503,  2921, 'n40sapphiron'), -- Sapphiron   (Frostwyrm Lair)
(10666, 3746.41, -5113.35, 142.03,  2.932,  2921, 'n40kelthuzad'); -- Kel'Thuzad

-- ---------------------------------------------------------------------
-- Usage
-- ---------------------------------------------------------------------
--   .tele n40          -- straight to the Naxx-40 entrance chamber on 2921
--   .tele n40rune      -- the Plaguewood runestone on map 751 (click it to enter properly)
--   .tele n40strath    -- the in-Stratholme trigger, to test the vanilla route
--
-- BEFORE using any map-2921 tele, confirm the server has its terrain:
--   ls -1 <server>/data/maps/2921*.map   | wc -l    -- expect 24 tiles
--   ls -1 <server>/data/vmaps/2921*      | wc -l
-- If they are missing the CLIENT will still draw the map (the ADTs are in
-- patch-4), but the SERVER has no heightmap, so you will fall through the
-- world. Use `.gm on` + `.gm fly on` to look around until the extraction is done.
