-- ===========================================================================
-- DC custom heirlooms 300332-300381 - wire up level scaling (set-wide)
-- ===========================================================================
--
-- Root cause: every custom heirloom row has ScalingStatDistribution = 0 and
-- ScalingStatValue = 0, so Player::_ApplyItemBonuses takes the static-stat
-- branch and applies stat_value1 verbatim at every level. Only the 44 stock
-- Blizzard heirlooms are wired. This has always been the case - it is not a
-- regression.
--
-- !! APPLY THE DBC FIRST. This file is step 2 of 2. !!
--
--   ScalingStatDistribution.dbc custom rows were renumbered 300332-300381 ->
--   500-548, because item_template.ScalingStatDistribution is a SIGNED SMALLINT
--   (max 32767) and ObjectMgr.cpp:3427 loads it with Get<uint16>() - the old
--   300xxx ids could not be stored at all (SQL 1264) and would have been
--   truncated even if they could. Rebuild + deploy the DBC to client
--   patch-4.MPQ AND enGB/patch-enGB-3.MPQ AND the server data/dbc BEFORE running
--   this file. If the SQL lands first, the SSD lookup fails while ScalingStatValue
--   is non-zero, and the items apply NO stats at all until the DBC catches up.
--
--   ScalingStatValues.dbc (255 levels) is already deployed and is not touched.
--
-- The renumbering pass also corrected 14 DBC rows whose stat disagreed with the
-- item that uses them (e.g. Heirloom Battleplate is STR but its row said AGI), so
-- the entry -> dbc-id mapping below is now a clean 1:1 with no remaps.
--
-- ScalingStatValue is a bitmask: the low bits pick which ScalingStatValues.dbc
-- column supplies the stat budget, the high bits pick weapon dps / spell power.
-- Masks are lifted from Blizzard own heirlooms - item 42952 (shoulder), 48691
-- (robe), 42991 (trinket), 50255 (ring), 42944 (1H), 42943 (2H), 42947 (caster
-- staff), 42946 (bow).
--
--   0x00001  ssdMultiplier[0]   shoulder curve    97 @80    346 @255
--   0x00002  ssdMultiplier[1]   trinket curve     97 @80    346 @255
--   0x00004  ssdMultiplier[2]   1H weapon curve   56 @80    200 @255
--   0x00008  ssdMultiplier2     chest curve      131 @80    468 @255
--   0x00010  ssdMultiplier[3]   ranged curve      41 @80    146 @255
--   0x40000  ssdMultiplier3     ring curve        73 @80    261 @255
--
-- NO armor bits are set anywhere in this file, deliberately: ScalingStatValues
-- only carries shoulder, chest and cloak armor curves, so there is nothing
-- correct to point a wrist / waist / glove / leg piece at. Every item keeps its
-- current static armor value, and armor keeps growing through the upgrade
-- system OnPlayerApplyItemArmorBefore multiplier instead.
--
-- stat_type1..N are left untouched. With SSD set, both the core and the client
-- read the stat list out of the DBC and ignore them; they stay as a sane
-- fallback for a client whose patch-4.MPQ predates the DBC rows.
--
-- 300366 (the Haversack) is excluded - it is a container, has no DBC row by
-- design, and scales by swapping bag tiers in heirloom_scaling_255.cpp.
--
-- After applying, the client keeps showing the old stats from its item WDB cache.
-- Bump version.cache_id or clear Cache/WDB before judging the result.
-- ===========================================================================

USE acore_world;

-- --- 1H weapon     + 1H dps --------------------------------------
UPDATE `item_template` SET `ScalingStatDistribution` = 500, `ScalingStatValue` = 516 WHERE `entry` = 300332;     -- Heirloom Flamefury Blade [dbc 500, STR]
UPDATE `item_template` SET `ScalingStatDistribution` = 501, `ScalingStatValue` = 516 WHERE `entry` = 300333;     -- Heirloom Stormfury [dbc 501, STR]
UPDATE `item_template` SET `ScalingStatDistribution` = 502, `ScalingStatValue` = 516 WHERE `entry` = 300334;     -- Heirloom Frostbite Axe [dbc 502, STR]
UPDATE `item_template` SET `ScalingStatDistribution` = 503, `ScalingStatValue` = 516 WHERE `entry` = 300335;     -- Heirloom Shadow Dagger [dbc 503, AGI]

-- --- caster 2H     + caster dps + spell power --------------------
UPDATE `item_template` SET `ScalingStatDistribution` = 504, `ScalingStatValue` = 36872 WHERE `entry` = 300336;   -- Heirloom Arcane Staff [dbc 504, INT]

-- --- ranged        + ranged dps ----------------------------------
UPDATE `item_template` SET `ScalingStatDistribution` = 505, `ScalingStatValue` = 8208 WHERE `entry` = 300337;    -- Heirloom Zephyr Bow [dbc 505, AGI]

-- --- wand          + wand dps ------------------------------------
UPDATE `item_template` SET `ScalingStatDistribution` = 506, `ScalingStatValue` = 16400 WHERE `entry` = 300338;   -- Heirloom Arcane Wand [dbc 506, INT]

-- --- 1H weapon     + 1H dps --------------------------------------
UPDATE `item_template` SET `ScalingStatDistribution` = 507, `ScalingStatValue` = 516 WHERE `entry` = 300339;     -- Heirloom Earthshaker Mace [dbc 507, STR]

-- --- 2H weapon     + 2H dps --------------------------------------
UPDATE `item_template` SET `ScalingStatDistribution` = 508, `ScalingStatValue` = 1032 WHERE `entry` = 300340;    -- Heirloom Polearm [dbc 508, STR]

-- --- major armor   (chest curve) ---------------------------------
UPDATE `item_template` SET `ScalingStatDistribution` = 509, `ScalingStatValue` = 8 WHERE `entry` = 300341;       -- Heirloom War Crown [dbc 509, STA]
UPDATE `item_template` SET `ScalingStatDistribution` = 510, `ScalingStatValue` = 8 WHERE `entry` = 300342;       -- Heirloom Battle Helm [dbc 510, STR]
UPDATE `item_template` SET `ScalingStatDistribution` = 511, `ScalingStatValue` = 8 WHERE `entry` = 300343;       -- Heirloom Kingly Circlet [dbc 511, INT]

-- --- medium armor  (shoulder curve) ------------------------------
UPDATE `item_template` SET `ScalingStatDistribution` = 512, `ScalingStatValue` = 1 WHERE `entry` = 300344;       -- Heirloom Mantle of Honor [dbc 512, STA]
UPDATE `item_template` SET `ScalingStatDistribution` = 513, `ScalingStatValue` = 1 WHERE `entry` = 300345;       -- Heirloom Shoulders of Valor [dbc 513, STR]
UPDATE `item_template` SET `ScalingStatDistribution` = 514, `ScalingStatValue` = 1 WHERE `entry` = 300346;       -- Heirloom Pauldrons of Wisdom [dbc 514, INT]

-- --- major armor   (chest curve) ---------------------------------
UPDATE `item_template` SET `ScalingStatDistribution` = 515, `ScalingStatValue` = 8 WHERE `entry` = 300347;       -- Heirloom Chestplate of the Champion [dbc 515, STA]
UPDATE `item_template` SET `ScalingStatDistribution` = 516, `ScalingStatValue` = 8 WHERE `entry` = 300348;       -- Heirloom Battleplate [dbc 516, STR]
UPDATE `item_template` SET `ScalingStatDistribution` = 517, `ScalingStatValue` = 8 WHERE `entry` = 300349;       -- Heirloom Robes of Insight [dbc 517, INT]

-- --- minor armor   (ring curve) ----------------------------------
UPDATE `item_template` SET `ScalingStatDistribution` = 518, `ScalingStatValue` = 262144 WHERE `entry` = 300350;  -- Heirloom Vambraces of Might [dbc 518, STA]
UPDATE `item_template` SET `ScalingStatDistribution` = 519, `ScalingStatValue` = 262144 WHERE `entry` = 300351;  -- Heirloom Bracers of Battle [dbc 519, STR]
UPDATE `item_template` SET `ScalingStatDistribution` = 520, `ScalingStatValue` = 262144 WHERE `entry` = 300352;  -- Heirloom Cuffs of the Magi [dbc 520, INT]

-- --- medium armor  (shoulder curve) ------------------------------
UPDATE `item_template` SET `ScalingStatDistribution` = 521, `ScalingStatValue` = 1 WHERE `entry` = 300353;       -- Heirloom Gauntlets of Strength [dbc 521, STA]
UPDATE `item_template` SET `ScalingStatDistribution` = 522, `ScalingStatValue` = 1 WHERE `entry` = 300354;       -- Heirloom Grips of Precision [dbc 522, STR]
UPDATE `item_template` SET `ScalingStatDistribution` = 523, `ScalingStatValue` = 1 WHERE `entry` = 300355;       -- Heirloom Gloves of Sorcery [dbc 523, INT]
UPDATE `item_template` SET `ScalingStatDistribution` = 524, `ScalingStatValue` = 1 WHERE `entry` = 300356;       -- Heirloom Girdle of Power [dbc 524, STA]
UPDATE `item_template` SET `ScalingStatDistribution` = 525, `ScalingStatValue` = 1 WHERE `entry` = 300357;       -- Heirloom Belt of Agility [dbc 525, STR]
UPDATE `item_template` SET `ScalingStatDistribution` = 526, `ScalingStatValue` = 1 WHERE `entry` = 300358;       -- Heirloom Cord of Intellect [dbc 526, INT]

-- --- major armor   (chest curve) ---------------------------------
UPDATE `item_template` SET `ScalingStatDistribution` = 527, `ScalingStatValue` = 8 WHERE `entry` = 300359;       -- Heirloom Legplates of the Conqueror [dbc 527, STA]
UPDATE `item_template` SET `ScalingStatDistribution` = 528, `ScalingStatValue` = 8 WHERE `entry` = 300360;       -- Heirloom Leggings of Swiftness [dbc 528, STR]
UPDATE `item_template` SET `ScalingStatDistribution` = 529, `ScalingStatValue` = 8 WHERE `entry` = 300361;       -- Heirloom Trousers of Arcane Power [dbc 529, INT]

-- --- medium armor  (shoulder curve) ------------------------------
UPDATE `item_template` SET `ScalingStatDistribution` = 530, `ScalingStatValue` = 1 WHERE `entry` = 300362;       -- Heirloom Sabatons of Fury [dbc 530, STA]
UPDATE `item_template` SET `ScalingStatDistribution` = 531, `ScalingStatValue` = 1 WHERE `entry` = 300363;       -- Heirloom Boots of Haste [dbc 531, STR]
UPDATE `item_template` SET `ScalingStatDistribution` = 532, `ScalingStatValue` = 1 WHERE `entry` = 300364;       -- Heirloom Sandals of Brilliance [dbc 532, INT]

-- --- shirt         (shoulder curve) ------------------------------
UPDATE `item_template` SET `ScalingStatDistribution` = 533, `ScalingStatValue` = 1 WHERE `entry` = 300365;       -- Heirloom Adventurer Shirt [dbc 533, bespoke 5-stat STR/AGI/INT/STA/SPI]

-- --- minor armor   (ring curve) ----------------------------------
UPDATE `item_template` SET `ScalingStatDistribution` = 534, `ScalingStatValue` = 262144 WHERE `entry` = 300367;  -- Heirloom Pendant of Might [dbc 534, STA]
UPDATE `item_template` SET `ScalingStatDistribution` = 535, `ScalingStatValue` = 262144 WHERE `entry` = 300368;  -- Heirloom Pendant of Agility [dbc 535, STR]
UPDATE `item_template` SET `ScalingStatDistribution` = 536, `ScalingStatValue` = 262144 WHERE `entry` = 300369;  -- Heirloom Pendant of Wisdom [dbc 536, INT]
UPDATE `item_template` SET `ScalingStatDistribution` = 537, `ScalingStatValue` = 262144 WHERE `entry` = 300370;  -- Heirloom Cape of Valor [dbc 537, STA]
UPDATE `item_template` SET `ScalingStatDistribution` = 538, `ScalingStatValue` = 262144 WHERE `entry` = 300371;  -- Heirloom Drape of Swiftness [dbc 538, STR]
UPDATE `item_template` SET `ScalingStatDistribution` = 539, `ScalingStatValue` = 262144 WHERE `entry` = 300372;  -- Heirloom Cloak of Insight [dbc 539, INT]

-- --- ring          (ring curve) ----------------------------------
UPDATE `item_template` SET `ScalingStatDistribution` = 540, `ScalingStatValue` = 262144 WHERE `entry` = 300373;  -- Heirloom Band of Power [dbc 540, STA]
UPDATE `item_template` SET `ScalingStatDistribution` = 541, `ScalingStatValue` = 262144 WHERE `entry` = 300374;  -- Heirloom Band of Precision [dbc 541, STR]
UPDATE `item_template` SET `ScalingStatDistribution` = 542, `ScalingStatValue` = 262144 WHERE `entry` = 300375;  -- Heirloom Band of Intellect [dbc 542, INT]

-- --- trinket       (trinket curve) -------------------------------
UPDATE `item_template` SET `ScalingStatDistribution` = 543, `ScalingStatValue` = 2 WHERE `entry` = 300376;       -- Heirloom Badge of Might [dbc 543, STA]
UPDATE `item_template` SET `ScalingStatDistribution` = 544, `ScalingStatValue` = 2 WHERE `entry` = 300377;       -- Heirloom Charm of Agility [dbc 544, STR]
UPDATE `item_template` SET `ScalingStatDistribution` = 545, `ScalingStatValue` = 2 WHERE `entry` = 300378;       -- Heirloom Stone of Wisdom [dbc 545, INT]

-- --- shield        (shoulder curve) ------------------------------
UPDATE `item_template` SET `ScalingStatDistribution` = 546, `ScalingStatValue` = 1 WHERE `entry` = 300379;       -- Heirloom Bulwark of Might [dbc 546, STA]
UPDATE `item_template` SET `ScalingStatDistribution` = 547, `ScalingStatValue` = 1 WHERE `entry` = 300380;       -- Heirloom Bulwark of Swiftness [dbc 547, STR]

-- --- off-hand held (ring curve) ----------------------------------
UPDATE `item_template` SET `ScalingStatDistribution` = 548, `ScalingStatValue` = 262144 WHERE `entry` = 300381;  -- Heirloom Tome of Insight [dbc 548, INT]

-- --- verification ---------------------------------------------------------
SELECT `entry`, `name`, `ScalingStatDistribution` AS SSD, `ScalingStatValue` AS SSV, `armor`, `ItemLevel`
FROM `item_template`
WHERE `entry` BETWEEN 300332 AND 300381 AND `Quality` = 7
ORDER BY `entry`;
-- Expect 50 rows: 49 with SSD in 500-548 and SSV non-zero, plus 300366 at 0/0.
