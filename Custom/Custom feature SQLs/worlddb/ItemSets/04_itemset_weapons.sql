-- -------------------------------------------------------------------------
-- The 8 weapons of sets 951, 1087, 1088 and 1089
-- -------------------------------------------------------------------------
-- Closes the one gap file 03 left open. Those four sets DO ship in file 01, so
-- without this their bonuses work while the weapons swing for zero.
--
-- Two different problems, two different sources:
--
-- 1. Claws of Agony / Claws of Torment (63537, 63538) -- set 951.
--    These DO have an Item-sparse row, so file 03 already gave them item level,
--    stats, delay and the rest. Only weapon damage was missing, because
--    Cataclysm computes damage from a curve instead of storing it.
--
-- 2. The six Fangs of the Father daggers (77945-77950) -- sets 1087/1088/1089.
--    These have NO Item-sparse row in build 15595 (77938 and 77951 are both
--    present, so it is a real gap in the client data, not a parse fault), and
--    file 03 skipped them entirely. Every column here comes from
--    `skyfire_world.item_template` -- a Mists 5.4 world DB, which is the last
--    pre-squish snapshot and still carries these items with their true
--    Cataclysm item levels and ABSOLUTE stat values. That beats hand-authoring:
--    nothing below is invented.
--    Independent confirmation that the source is the right one: skyfire's
--    `itemset` column reads 1089/1088/1087 for these six, matching the set
--    assignment file 01 derived separately from Cata ItemSet.dbc.
--
-- WEAPON DAMAGE FORMULA (used for all 8):
--     dps = ItemDamageOneHand[ilvl][quality]
--     avg = dps * delay / 1000
--     dmg_min = round(avg * (1 - DmgVariance/2))
--     dmg_max = round(avg * (1 + DmgVariance/2))
-- Validated against stock 3.3.5 weapons, which it reproduces exactly or within
-- one point: 50654 -> 263/489 (exact), 47528 -> 394/732 (exact),
-- 50184 -> 413/766 vs 412/766, 50415 -> 802/1203 vs 801/1203. Shadowmourne
-- (49623) lands ~1% high, which is expected for a hand-tuned legendary.
--
-- DmgVariance lives in Item-sparse. It is the field a lot of layouts mislabel
-- as StatScalingFactor -- identified here by matching it against the known
-- variances of five stock weapons (0.4 / 0.5 / 0.6), all five agreeing.
-- The daggers' 0.5 comes from the retail 9.2.7 ItemSparse dump, which still
-- carries DmgVariance and ItemDelay unsquished.
--
-- MASTERY IS DROPPED, as everywhere else in this series: Item-sparse stat type
-- 49 has no 3.3.5 equivalent (the ITEM_MOD enum stops at 48). The three
-- off-hand daggers each lose one stat and carry four instead of five.
--
-- FlagsExtra is forced to 0. Mists stores 138428416 / 140525568 there, whose
-- bits do not exist in 3.3.5. Flags 128 on the two stage-3 daggers IS kept --
-- that is ITEM_FLAG_NO_EQUIP_COOLDOWN, a real 3.3.5 flag.
--
-- The Mists `spellid_1` values (110211, 107082) are deliberately NOT carried
-- over: those are MoP-era spells that do not resolve here, and pointing an item
-- at a missing spell produces a boot warning. The legendary's actual effect on
-- this server is the set bonus file 01 installs (109939 / 109956 / 109960).
--
-- socketBonus 2782 was checked against the live SpellItemEnchantment.dbc and
-- resolves, so the yellow socket is kept. MaxDurability 75 is the stock value
-- for one-hand daggers and fists (fist weapon 50184 carries exactly 75).
--
-- REQUIRED LEVEL follows the realm's own item level ladder, the same one
-- 09_cata_highend_required_level.sql applies:
--     RequiredLevel = round(80 + (ItemLevel - 300) * 50 / 112), clamped to [80, 130]
-- giving 123 at ilvl 397, 127 at 406 and 130 at 416. It is written here rather than
-- left to 09 because these six have no Item-sparse row, so they are not in 09's id
-- set at all -- 09 would have left them on Blizzard's level 85 forever.
--
-- Idempotent. Apply after 03.
-- -------------------------------------------------------------------------

-- -------------------------------------------------------------------------
-- 1. Set 951 -- Agony and Torment (damage only; file 03 owns the rest)
-- -------------------------------------------------------------------------
-- ilvl 359, quality 4, delay 2600, DmgVariance 0.60 -> dps 323.4

UPDATE `item_template` SET `dmg_min1` = 841, `dmg_max1` = 1563 WHERE `entry` = 63537;
UPDATE `item_template` SET `dmg_min1` = 841, `dmg_max1` = 1563 WHERE `entry` = 63538;

-- -------------------------------------------------------------------------
-- 2. Sets 1089 / 1088 / 1087 -- the Fangs of the Father daggers (full rows)
-- -------------------------------------------------------------------------

-- 77945 Fear -- Jaws of Retribution (1089), main hand, ilvl 397
UPDATE `item_template` SET
  `Quality` = 4, `Flags` = 0, `FlagsExtra` = 0, `ItemLevel` = 397, `RequiredLevel` = 123,
  `AllowableClass` = -1, `AllowableRace` = -1, `bonding` = 1, `Material` = 1, `sheath` = 3,
  `delay` = 1800, `dmg_min1` = 889, `dmg_max1` = 1482, `dmg_type1` = 0, `MaxDurability` = 75,
  `stat_type1` = 3, `stat_value1` = 188, `stat_type2` = 32, `stat_value2` = 108,
  `stat_type3` = 36, `stat_value3` = 102, `stat_type4` = 31, `stat_value4` = 100,
  `stat_type5` = 7, `stat_value5` = 312,
  `socketColor_1` = 2, `socketContent_1` = 0, `socketBonus` = 2782,
  `BuyPrice` = 0, `SellPrice` = 0, `stackable` = 1, `maxcount` = 0
WHERE `entry` = 77945;

-- 77946 Vengeance -- Jaws of Retribution (1089), off hand, ilvl 397 (mastery 102 dropped)
UPDATE `item_template` SET
  `Quality` = 4, `Flags` = 0, `FlagsExtra` = 0, `ItemLevel` = 397, `RequiredLevel` = 123,
  `AllowableClass` = -1, `AllowableRace` = -1, `bonding` = 1, `Material` = 1, `sheath` = 3,
  `delay` = 1400, `dmg_min1` = 692, `dmg_max1` = 1153, `dmg_type1` = 0, `MaxDurability` = 75,
  `stat_type1` = 3, `stat_value1` = 188, `stat_type2` = 36, `stat_value2` = 106,
  `stat_type3` = 37, `stat_value3` = 101, `stat_type4` = 7, `stat_value4` = 312,
  `stat_type5` = 0, `stat_value5` = 0,
  `socketColor_1` = 2, `socketContent_1` = 0, `socketBonus` = 2782,
  `BuyPrice` = 0, `SellPrice` = 0, `stackable` = 1, `maxcount` = 0
WHERE `entry` = 77946;

-- 77947 The Sleeper -- Maw of Oblivion (1088), main hand, ilvl 406
UPDATE `item_template` SET
  `Quality` = 4, `Flags` = 0, `FlagsExtra` = 0, `ItemLevel` = 406, `RequiredLevel` = 127,
  `AllowableClass` = -1, `AllowableRace` = -1, `bonding` = 1, `Material` = 1, `sheath` = 3,
  `delay` = 1800, `dmg_min1` = 967, `dmg_max1` = 1612, `dmg_type1` = 0, `MaxDurability` = 75,
  `stat_type1` = 3, `stat_value1` = 207, `stat_type2` = 32, `stat_value2` = 117,
  `stat_type3` = 36, `stat_value3` = 111, `stat_type4` = 31, `stat_value4` = 109,
  `stat_type5` = 7, `stat_value5` = 340,
  `socketColor_1` = 2, `socketContent_1` = 0, `socketBonus` = 2782,
  `BuyPrice` = 0, `SellPrice` = 0, `stackable` = 1, `maxcount` = 0
WHERE `entry` = 77947;

-- 77948 The Dreamer -- Maw of Oblivion (1088), off hand, ilvl 406 (mastery 112 dropped)
UPDATE `item_template` SET
  `Quality` = 4, `Flags` = 0, `FlagsExtra` = 0, `ItemLevel` = 406, `RequiredLevel` = 127,
  `AllowableClass` = -1, `AllowableRace` = -1, `bonding` = 1, `Material` = 1, `sheath` = 3,
  `delay` = 1400, `dmg_min1` = 752, `dmg_max1` = 1254, `dmg_type1` = 0, `MaxDurability` = 75,
  `stat_type1` = 3, `stat_value1` = 207, `stat_type2` = 36, `stat_value2` = 115,
  `stat_type3` = 37, `stat_value3` = 110, `stat_type4` = 7, `stat_value4` = 340,
  `stat_type5` = 0, `stat_value5` = 0,
  `socketColor_1` = 2, `socketContent_1` = 0, `socketBonus` = 2782,
  `BuyPrice` = 0, `SellPrice` = 0, `stackable` = 1, `maxcount` = 0
WHERE `entry` = 77948;

-- 77949 Golad, Twilight of Aspects -- Fangs of the Father (1087), main hand, ilvl 416
UPDATE `item_template` SET
  `Quality` = 5, `Flags` = 128, `FlagsExtra` = 0, `ItemLevel` = 416, `RequiredLevel` = 130,
  `AllowableClass` = -1, `AllowableRace` = -1, `bonding` = 1, `Material` = 1, `sheath` = 3,
  `delay` = 1800, `dmg_min1` = 1061, `dmg_max1` = 1769, `dmg_type1` = 0, `MaxDurability` = 75,
  `stat_type1` = 3, `stat_value1` = 229, `stat_type2` = 32, `stat_value2` = 156,
  `stat_type3` = 36, `stat_value3` = 150, `stat_type4` = 31, `stat_value4` = 148,
  `stat_type5` = 7, `stat_value5` = 373,
  `socketColor_1` = 2, `socketContent_1` = 0, `socketBonus` = 2782,
  `BuyPrice` = 0, `SellPrice` = 0, `stackable` = 1, `maxcount` = 0
WHERE `entry` = 77949;

-- 77950 Tiriosh, Nightmare of Ages -- Fangs of the Father (1087), off hand, ilvl 416 (mastery 150 dropped)
UPDATE `item_template` SET
  `Quality` = 5, `Flags` = 128, `FlagsExtra` = 0, `ItemLevel` = 416, `RequiredLevel` = 130,
  `AllowableClass` = -1, `AllowableRace` = -1, `bonding` = 1, `Material` = 1, `sheath` = 3,
  `delay` = 1400, `dmg_min1` = 826, `dmg_max1` = 1376, `dmg_type1` = 0, `MaxDurability` = 75,
  `stat_type1` = 3, `stat_value1` = 229, `stat_type2` = 36, `stat_value2` = 154,
  `stat_type3` = 37, `stat_value3` = 149, `stat_type4` = 7, `stat_value4` = 373,
  `stat_type5` = 0, `stat_value5` = 0,
  `socketColor_1` = 2, `socketContent_1` = 0, `socketBonus` = 2782,
  `BuyPrice` = 0, `SellPrice` = 0, `stackable` = 1, `maxcount` = 0
WHERE `entry` = 77950;

-- -------------------------------------------------------------------------
-- Verification
-- -------------------------------------------------------------------------
--   -- all 8 now swing (expect 0 rows):
--   SELECT entry, name FROM item_template
--    WHERE entry IN (63537,63538,77945,77946,77947,77948,77949,77950)
--      AND dmg_max1 = 0;
--
--   -- the daggers are fully specified (expect 6 rows, all non-zero):
--   SELECT entry, name, ItemLevel, RequiredLevel, delay, dmg_min1, dmg_max1,
--          stat_type1, stat_value1, MaxDurability
--     FROM item_template WHERE entry BETWEEN 77945 AND 77950 ORDER BY entry;
--
--   -- no mastery survived (expect 0 rows):
--   SELECT entry FROM item_template
--    WHERE entry IN (63537,63538,77945,77946,77947,77948,77949,77950)
--      AND 49 IN (stat_type1, stat_type2, stat_type3, stat_type4, stat_type5);
--
--   -- dps sanity: both halves of a pair must match, and dps must climb with
--   -- item level -- expect 658.6 / 658.9 (ilvl 397), 716.4 / 716.4 (406),
--   -- 786.1 / 786.4 (416). 63537 and 63538 are both 462.3.
--   SELECT entry, name, ROUND((dmg_min1+dmg_max1)/2/(delay/1000),1) AS dps
--     FROM item_template WHERE entry BETWEEN 77945 AND 77950 ORDER BY entry;
-- -------------------------------------------------------------------------
