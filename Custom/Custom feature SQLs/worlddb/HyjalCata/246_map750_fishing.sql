-- ---------------------------------------------------------------------------
-- 246  Map 750 -- open-water fishing + rods/lures on the fisher vendors
-- ---------------------------------------------------------------------------
-- fishing_loot_template had ZERO rows for zones 4923-4931: the 247 fishing
-- pools (GO loot) work, but casting into open water caught nothing. Cata's
-- own zone tables are single reference rows into the classic fish pools --
-- and those references (11004/11008/11010/11104) exist locally with byte-
-- identical row counts, so the port is a re-key plus a Cata-fish bonus layer:
--
--   zone                classic ref (as in Cata)   bonus catches (local Cata items)
--   4929 Darkshore      11104                      Mountain Trout 15%
--   4930 Azshara        11008 (cata zone 16)       Albino Cavefish 10%, Volatile Water 5%
--   4931 Ashenvale      11004                      Mountain Trout 20%
--   4927 Felwood        11008                      Sharptooth 20%
--   4928 Moonglade      11008                      Mountain Trout 20%
--   4926 Winterspring   11010                      Albino Cavefish 15%, Mountain Trout 10%
--   4923 Hyjal          11008 (editorial -- Cata   Lavascale Catfish 20%,
--                       has no 616 zone table)     Volatile Air 4%, Volatile Water 4%
--
-- Bonus fish are the Cata-era catch items ALREADY downported (Volatile Water
-- 52326, Volatile Air 52328, Sharptooth 53062, Mountain Trout 53063, Albino
-- Cavefish 53065, Lavascale Catfish 53068). Highland Guppy / Blackbelly
-- Mudfish / Fathom Eel / Deepsea Sagefish / Murglesnout were never downported
-- and are SKIPPED -- add them via the 210_ cata-item pattern if wanted later.
--
-- Rods & lures: the downport corpus has no fishing poles, so the three fisher
-- vendors get the classic kit -- poles 6256/6365/6366/6367 and lures
-- 6529/6530/6532/6533. Vendors: Elizabeth Nesworth 3748552 (Felwood),
-- Wik'Tar 3612962 (Zoram'gar), Zizo Seasizzle 3643776 (Bilgewater Harbor).
-- (Kil'Hiwana 3612961 is the fishing TRAINER and is left as-is.)
--
-- Idempotent (DELETE + re-insert of everything this file owns).
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) zone fishing tables
-- ---------------------------------------------------------------------------
DELETE FROM `fishing_loot_template` WHERE `Entry` IN (4923, 4926, 4927, 4928, 4929, 4930, 4931);
INSERT INTO `fishing_loot_template`
  (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
-- classic base pools (GroupId 1 = the guaranteed catch roll, as in Cata)
(4929, 11104, 11104, 100, 0, 1, 1, 1, 1, 'DC750 Darkshore - classic fish pool'),
(4930, 11008, 11008, 100, 0, 1, 1, 1, 1, 'DC750 Azshara - classic fish pool'),
(4931, 11004, 11004, 100, 0, 1, 1, 1, 1, 'DC750 Ashenvale - classic fish pool'),
(4927, 11008, 11008, 100, 0, 1, 1, 1, 1, 'DC750 Felwood - classic fish pool'),
(4928, 11008, 11008, 100, 0, 1, 1, 1, 1, 'DC750 Moonglade - classic fish pool'),
(4926, 11010, 11010, 100, 0, 1, 1, 1, 1, 'DC750 Winterspring - classic fish pool'),
(4923, 11008, 11008, 100, 0, 1, 1, 1, 1, 'DC750 Hyjal - classic fish pool (editorial)'),
-- Cata-fish bonus layer (independent rolls)
(4929, 53063, 0, 15, 0, 1, 0, 1, 2, 'DC750 Darkshore - Mountain Trout'),
(4930, 53065, 0, 10, 0, 1, 0, 1, 2, 'DC750 Azshara - Albino Cavefish'),
(4930, 52326, 0,  5, 0, 1, 0, 1, 1, 'DC750 Azshara - Volatile Water'),
(4931, 53063, 0, 20, 0, 1, 0, 1, 2, 'DC750 Ashenvale - Mountain Trout'),
(4927, 53062, 0, 20, 0, 1, 0, 1, 2, 'DC750 Felwood - Sharptooth'),
(4928, 53063, 0, 20, 0, 1, 0, 1, 2, 'DC750 Moonglade - Mountain Trout'),
(4926, 53065, 0, 15, 0, 1, 0, 1, 2, 'DC750 Winterspring - Albino Cavefish'),
(4926, 53063, 0, 10, 0, 1, 0, 1, 2, 'DC750 Winterspring - Mountain Trout'),
(4923, 53068, 0, 20, 0, 1, 0, 1, 2, 'DC750 Hyjal - Lavascale Catfish'),
(4923, 52328, 0,  4, 0, 1, 0, 1, 1, 'DC750 Hyjal - Volatile Air'),
(4923, 52326, 0,  4, 0, 1, 0, 1, 1, 'DC750 Hyjal - Volatile Water');

-- ---------------------------------------------------------------------------
-- B) rods & lures on the fisher vendors
-- ---------------------------------------------------------------------------
DELETE FROM `npc_vendor`
WHERE `entry` IN (3748552, 3612962, 3643776)
  AND `item` IN (6256, 6365, 6366, 6367, 6529, 6530, 6532, 6533);

INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`)
SELECT v.entry, 0, i.item, 0, 0, 0
FROM (SELECT 3748552 AS entry UNION ALL SELECT 3612962 UNION ALL SELECT 3643776) v
CROSS JOIN (
  SELECT 6256 AS item UNION ALL SELECT 6365 UNION ALL SELECT 6366
  UNION ALL SELECT 6367 UNION ALL SELECT 6529 UNION ALL SELECT 6530
  UNION ALL SELECT 6532 UNION ALL SELECT 6533
) i;

-- ---------------------------------------------------------------------------
-- Trailer -- verification
-- ---------------------------------------------------------------------------
-- zone tables present (expect 7 zones, 18 rows total):
-- SELECT Entry, COUNT(*) FROM fishing_loot_template
-- WHERE Entry BETWEEN 4923 AND 4931 GROUP BY Entry;
-- every referenced pool + bonus item resolves (expect 0):
-- SELECT f.Entry, f.Item FROM fishing_loot_template f
-- WHERE f.Entry BETWEEN 4923 AND 4931 AND f.Reference = 0
--   AND NOT EXISTS (SELECT 1 FROM item_template it WHERE it.entry = f.Item);
-- SELECT f.Reference FROM fishing_loot_template f
-- WHERE f.Entry BETWEEN 4923 AND 4931 AND f.Reference <> 0
--   AND NOT EXISTS (SELECT 1 FROM reference_loot_template r WHERE r.Entry = f.Reference);
-- vendor kit (expect 8 rows each on the 3 vendors):
-- SELECT entry, COUNT(*) FROM npc_vendor
-- WHERE item IN (6256, 6365, 6366, 6367, 6529, 6530, 6532, 6533)
--   AND entry IN (3748552, 3612962, 3643776) GROUP BY entry;
-- In-game: cast into open water in each zone -- classic fish + occasional
-- Cata bonus catch; buy a pole at Zizo Seasizzle.
