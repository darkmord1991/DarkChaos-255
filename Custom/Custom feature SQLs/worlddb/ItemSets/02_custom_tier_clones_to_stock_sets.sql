-- -------------------------------------------------------------------------
-- DC custom tier clones (300007-300194) -> their stock Tier 10 set
-- -------------------------------------------------------------------------
-- OPTIONAL, and a BALANCE DECISION rather than a data fix -- read the caveat
-- before applying. Nothing in 01_cata_itemsets_phase1.sql depends on this file.
--
-- The 188 items the "T11" and "T12" vendors (creature 800005 / 800006, see
-- Custom/Custom Items/Itemsets/) sell are ilvl-500 reskins of the Wrath Tier 10
-- "Sanctified" sets, and every one of them currently carries itemset = 0, so
-- they grant no set bonus at all. Each maps by NAME onto exactly one stock set
-- (verified: no clone name resolves to two different stock itemset values), so
-- the mapping below is mechanical, not a guess.
--
-- Effect of applying: wearing 2/4 pieces grants the stock Tier 10 set bonus for
-- that class and spec. AC counts an item toward a set purely by its
-- item_template.itemset value -- Item::AddItemsSetItem looks the set up by id and
-- does not require the entry to appear in the ItemSet.dbc ItemID array -- so no
-- DBC change is needed for the bonus to apply server-side.
--
-- CAVEAT 1 -- IT MERGES THE TWO CUSTOM TIERS. 300007-300100 ("T11") and
-- 300101-300194 ("T12") are the SAME items duplicated, so both halves resolve to
-- the same stock set id. After this file, DC's T11 and T12 are one set for bonus
-- purposes: five T11 pieces plus five T12 pieces is a 10-piece count against a
-- 2/4-piece set, not two separate 4-piece bonuses. If T11 and T12 are meant to be
-- distinct tiers with distinct bonuses, do NOT apply this -- mint two new
-- ItemSet ids instead (1200+ is free; ItemSet.dbc currently tops out at 1089
-- after phase 1) and author the bonuses deliberately.
--
-- CAVEAT 2 -- the client tooltip lists the set's members from the ItemSet.dbc
-- ItemID array, which holds the STOCK entries. The green "(2/5)" counter follows
-- equipped items' set id and so counts the clones correctly, but the item list
-- shown in the tooltip will name the stock pieces, not these.
--
-- CAVEAT 3 -- these are ilvl 500 items receiving Tier 10 (ilvl 264) bonuses.
-- That is exactly what the names promise, but it is a power increase to gear
-- that is already the top of the custom curve.
--
-- Idempotent: only touches rows still at itemset = 0.
-- -------------------------------------------------------------------------

-- Sanctified Bloodmage (Mage)
UPDATE `item_template` SET `itemset` = 883 WHERE `itemset` = 0 AND `entry` IN (300036, 300037, 300038, 300039, 300040, 300130, 300131, 300132, 300133, 300134);
-- Sanctified Dark Coven (Warlock)
UPDATE `item_template` SET `itemset` = 884 WHERE `itemset` = 0 AND `entry` IN (300086, 300087, 300088, 300089, 300090, 300180, 300181, 300182, 300183, 300184);
-- Sanctified Crimson Acolyte, gloves group (Priest)
UPDATE `item_template` SET `itemset` = 885 WHERE `itemset` = 0 AND `entry` IN (300061, 300062, 300063, 300064, 300065, 300155, 300156, 300157, 300158, 300159);
-- Sanctified Crimson Acolyte, cowl group (Priest)
UPDATE `item_template` SET `itemset` = 886 WHERE `itemset` = 0 AND `entry` IN (300056, 300057, 300058, 300059, 300060, 300150, 300151, 300152, 300153, 300154);
-- Sanctified Lasherweave, gauntlets group (Druid)
UPDATE `item_template` SET `itemset` = 887 WHERE `itemset` = 0 AND `entry` IN (300016, 300017, 300018, 300019, 300020, 300110, 300111, 300112, 300113, 300114);
-- Sanctified Lasherweave, cover group (Druid)
UPDATE `item_template` SET `itemset` = 888 WHERE `itemset` = 0 AND `entry` IN (300026, 300027, 300028, 300029, 300030, 300120, 300121, 300122, 300123, 300124);
-- Sanctified Lasherweave, handgrips group (Druid)
UPDATE `item_template` SET `itemset` = 889 WHERE `itemset` = 0 AND `entry` IN (300021, 300022, 300023, 300024, 300025, 300115, 300116, 300117, 300118, 300119);
-- Sanctified Shadowblade (Rogue)
UPDATE `item_template` SET `itemset` = 890 WHERE `itemset` = 0 AND `entry` IN (300066, 300067, 300068, 300069, 300070, 300160, 300161, 300162, 300163, 300164);
-- Sanctified Ahn'Kahar Blood Hunter's (Hunter)
UPDATE `item_template` SET `itemset` = 891 WHERE `itemset` = 0 AND `entry` IN (300031, 300032, 300033, 300034, 300035, 300125, 300126, 300127, 300128, 300129);
-- Sanctified Frost Witch's, handguards group (Shaman)
UPDATE `item_template` SET `itemset` = 892 WHERE `itemset` = 0 AND `entry` IN (300076, 300077, 300078, 300079, 300080, 300170, 300171, 300172, 300173, 300174);
-- Sanctified Frost Witch's, gloves group (Shaman)
UPDATE `item_template` SET `itemset` = 893 WHERE `itemset` = 0 AND `entry` IN (300081, 300082, 300083, 300084, 300085, 300175, 300176, 300177, 300178, 300179);
-- Sanctified Frost Witch's, chestguard group (Shaman)
UPDATE `item_template` SET `itemset` = 894 WHERE `itemset` = 0 AND `entry` IN (300071, 300072, 300073, 300074, 300075, 300165, 300166, 300167, 300168, 300169);
-- Sanctified Ymirjar Lord's, battleplate group (Warrior)
UPDATE `item_template` SET `itemset` = 895 WHERE `itemset` = 0 AND `entry` IN (300091, 300092, 300093, 300094, 300095, 300185, 300186, 300187, 300188, 300189);
-- Sanctified Ymirjar Lord's, breastplate group (Warrior)
UPDATE `item_template` SET `itemset` = 896 WHERE `itemset` = 0 AND `entry` IN (300096, 300097, 300098, 300099, 300100, 300190, 300191, 300192, 300193, 300194);
-- Sanctified Scourgelord, battleplate group (Death Knight)
UPDATE `item_template` SET `itemset` = 897 WHERE `itemset` = 0 AND `entry` IN (300012, 300013, 300014, 300015, 300106, 300107, 300108, 300109);
-- Sanctified Scourgelord, chestguard group (Death Knight)
UPDATE `item_template` SET `itemset` = 898 WHERE `itemset` = 0 AND `entry` IN (300007, 300008, 300009, 300010, 300011, 300101, 300102, 300103, 300104, 300105);
-- Sanctified Lightsworn, gloves group (Paladin)
UPDATE `item_template` SET `itemset` = 899 WHERE `itemset` = 0 AND `entry` IN (300051, 300052, 300053, 300054, 300055, 300145, 300146, 300147, 300148, 300149);
-- Sanctified Lightsworn, battleplate group (Paladin)
UPDATE `item_template` SET `itemset` = 900 WHERE `itemset` = 0 AND `entry` IN (300041, 300042, 300043, 300044, 300045, 300135, 300136, 300137, 300138, 300139);
-- Sanctified Lightsworn, chestguard group (Paladin)
UPDATE `item_template` SET `itemset` = 901 WHERE `itemset` = 0 AND `entry` IN (300046, 300047, 300048, 300049, 300050, 300140, 300141, 300142, 300143, 300144);

-- -------------------------------------------------------------------------
-- Verification
-- -------------------------------------------------------------------------
--   SELECT COUNT(*) FROM item_template
--    WHERE entry BETWEEN 300007 AND 300194 AND itemset <> 0;          -- 188
--
--   SELECT itemset, COUNT(*) FROM item_template
--    WHERE entry BETWEEN 300007 AND 300194 GROUP BY itemset;          -- 19 groups
--
--   -- nothing left behind in the custom tier band:
--   SELECT entry, name FROM item_template
--    WHERE entry BETWEEN 300007 AND 300194 AND class IN (2, 4) AND itemset = 0;
-- -------------------------------------------------------------------------
