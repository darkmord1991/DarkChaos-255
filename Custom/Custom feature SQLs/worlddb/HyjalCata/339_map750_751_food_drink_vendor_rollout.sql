-- ---------------------------------------------------------------------------
-- 339  Food & drink on every innkeeper / general / food vendor, maps 750 + 751
-- ---------------------------------------------------------------------------
-- The branded consumable line is 400800-400823: four tiers, each with three
-- food/drink items (subclass 5) and three potions (subclass 1).
--
--   Emberwood   ReqLvl  80    Trail Ration / Spring Tea / Hearty Stew
--   Skyfire     ReqLvl  95    Camp Bread / Infused Water / Hearty Stew
--   Summit      ReqLvl 110    Ranger Ration / Moonwell Water / Feast
--   Nordrassil  ReqLvl 125    Ancient Bread / Moonwater / World Tree Feast
--
-- Coverage measured before writing anything (106 target NPCs across both maps):
--
--            map 750                      map 751
--   innkeeper      15 / 15  done            0 / 17
--   food vendor    15 / 22                  0 / 43
--   general goods   4 /  7                  0 /  2
--
-- So map 751 was **completely uncovered** -- not one of its 62 innkeepers,
-- food or general vendors sells any of it -- and map 750 was missing 10.
--
-- ---------------------------------------------------------------------------
-- 🔴 WHY 245_ MISSED 10 VENDORS ON A MAP IT ALREADY COVERED
-- ---------------------------------------------------------------------------
-- 245_ selected food sellers by NAME, not by the flag:
--
--     AND ((ct.npcflag & 0x10000) <> 0            -- innkeeper
--          OR ct.subname LIKE '%Food%' OR ct.subname LIKE '%Drink%'
--          OR ct.subname LIKE '%Butcher%' OR ct.subname LIKE '%Baker%'
--          OR ct.subname LIKE '%Cook%'
--          OR ct.entry IN (830139, 830152))       -- hand-patched exceptions
--
-- It never tested `npcflag & 0x200` (UNIT_NPC_FLAG_VENDOR_FOOD), which is the
-- actual "this is a food vendor" bit. Any food vendor whose subname does not
-- happen to contain one of five English words was skipped -- and the two
-- hand-added entry ids at the end are the tell that this was already patched
-- around once instead of fixed.
--
-- This file matches on the FLAGS the user's three categories actually mean:
--     0x10000 INNKEEPER      0x100 VENDOR_AMMO (general goods)   0x200 VENDOR_FOOD
--
-- ---------------------------------------------------------------------------
-- 🔴 THREE NPCS ARE FLAGGED AS SHOPS BUT CANNOT SELL
-- ---------------------------------------------------------------------------
-- `UNIT_NPC_FLAG_VENDOR` (0x80) is the bit that actually opens a vendor window
-- (HandleListInventoryOpcode -> GetNPCIfCanInteractWith(.., UNIT_NPC_FLAG_VENDOR));
-- 0x100/0x200 are only the sub-type used for the icon. These three carry a shop
-- role with no 0x80, so stocking them without step 1 would write rows nobody can
-- ever reach:
--
--     3650045  Pleasure Palace Waitress   npcflag 512    (map 750)
--     3603960  Ulthaan <Butcher>          npcflag 514    (map 750)
--     3647857  Roman Garner <Innkeeper>   npcflag 65537  (map 751)
--
-- ---------------------------------------------------------------------------
-- WHAT EACH MAP GETS
-- ---------------------------------------------------------------------------
-- MAP 750 -- band-aware, exactly as 245_ intended: a vendor stocks the tiers
-- whose RequiredLevel fits its zone band, plus one tier ahead
-- (`ReqLevel <= t_hi + 10`) so the next tier can always be pre-bought.
--
-- MAP 751 -- 🔴 there is NO band table for 751 and NO 751-appropriate tier. Its
-- zones run levels 133-157 (measured: zone 4933 avg 133 ... zone 4924 avg 157)
-- while the consumable line STOPS AT RequiredLevel 125. So 751 gets the top two
-- tiers, Summit (110) and Nordrassil (125), which is the best that exists.
--
-- 🔴 That is a real content gap, not a tuning choice: every 751 vendor will sell
-- food capped 30+ levels below its own zone. Closing it means authoring a fifth
-- tier (~ReqLvl 140) in 400824+ -- deliberately NOT invented here, because the
-- restore spell values would be guesses and the line's spells live in
-- spell_dbc (300550-300569 / 300584-300587), which needs a DBC pass, not a
-- vendor row.
--
-- ---------------------------------------------------------------------------
-- SCOPE: FOOD & DRINK ONLY -- POTIONS ARE LEFT ALONE
-- ---------------------------------------------------------------------------
-- The DELETE below is restricted to `subclass = 5` rows, so 245_'s potion stock
-- (subclass 1, general-goods vendors on map 750) survives untouched. Deleting
-- the whole 400800-400823 range and re-inserting only food -- which is what a
-- careless "supersede 245_" would do -- would silently wipe every potion vendor
-- on the continent.
--
-- 🔴 Map 751 therefore still has NO potions either. Same one-line fix as the
-- food; say the word and it rides along.
--
-- 🔴 IF 245_ IS EVER RE-RUN IT WILL UNDO THIS. Its `DELETE FROM npc_vendor WHERE
-- item BETWEEN 400800 AND 400823` is unscoped and its INSERT only knows about
-- map 750. Re-run 339_ after it, or better, treat 339_ as the owner of the
-- food/drink rows from here on.
--
-- 🔴 No `USE` statement -- select acore_world in your client.
--
-- Apply against acore_world. Idempotent (DELETE + re-derive). Needs a
-- worldserver restart.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 1. Give the three shop NPCs the vendor bit they are missing
-- ---------------------------------------------------------------------------
UPDATE `creature_template` ct
SET ct.`npcflag` = ct.`npcflag` | 0x80
WHERE (ct.`npcflag` & (0x10000 | 0x100 | 0x200)) <> 0
  AND (ct.`npcflag` & 0x80) = 0
  AND ct.`entry` IN (SELECT DISTINCT `id` FROM `creature` WHERE `map` IN (750, 751));

-- ---------------------------------------------------------------------------
-- 2. Re-derive the food/drink stock for both maps
-- ---------------------------------------------------------------------------
-- 🔴 Scoped to `subclass = 5` so the potion rows are not collateral, and scoped
-- to NPCs that actually spawn on 750/751 so vendors elsewhere are untouched.
DELETE v FROM `npc_vendor` v
JOIN `item_template` it ON it.`entry` = v.`item`
WHERE v.`item` BETWEEN 400800 AND 400823
  AND it.`subclass` = 5
  AND v.`entry` IN (SELECT DISTINCT `id` FROM `creature` WHERE `map` IN (750, 751));

-- 2a. MAP 750 -- band-aware
INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`)
SELECT DISTINCT ct.`entry`, 0, it.`entry`, 0, 0, 0
FROM `creature_template` ct
JOIN (SELECT DISTINCT `id` FROM `creature` WHERE `map` = 750) sp ON sp.`id` = ct.`entry`
JOIN `dc_map750_entryzone` ez ON ez.`entry` = ct.`entry`
JOIN `dc_map750_band` b ON b.`zone` = ez.`zone`
JOIN `item_template` it
  ON it.`entry` BETWEEN 400800 AND 400823 AND it.`subclass` = 5
WHERE it.`RequiredLevel` <= b.`t_hi` + 10
  AND (ct.`npcflag` & (0x10000 | 0x100 | 0x200)) <> 0;

-- 2b. MAP 750 -- vendors 2a's joins cannot reach, so they get the whole line
-- 🔴 TWO separate ways a vendor falls out of 2a, and both really happen here:
--   * it has no `dc_map750_entryzone` row at all (1 vendor);
--   * it HAS one, but its zone has no `dc_map750_band` row -- zone 4928 is
--     missing from the band table, taking Dargon <Food & Drink Merchant>,
--     My'lanna <Food & Drink Merchant> and Daeolyn Summerleaf <General Goods>
--     with it (3 vendors).
-- Both are inner-join silences: the vendor simply is not in the result and
-- nothing says so. Testing for "no entryzone row" alone -- the obvious guard --
-- catches the first and misses the second, which is how the count came out 103
-- against a target of 106. The condition below tests the JOINED pair instead.
INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`)
SELECT DISTINCT ct.`entry`, 0, it.`entry`, 0, 0, 0
FROM `creature_template` ct
JOIN (SELECT DISTINCT `id` FROM `creature` WHERE `map` = 750) sp ON sp.`id` = ct.`entry`
JOIN `item_template` it
  ON it.`entry` BETWEEN 400800 AND 400823 AND it.`subclass` = 5
WHERE (ct.`npcflag` & (0x10000 | 0x100 | 0x200)) <> 0
  AND NOT EXISTS (
      SELECT 1 FROM `dc_map750_entryzone` ez
      JOIN `dc_map750_band` b ON b.`zone` = ez.`zone`
      WHERE ez.`entry` = ct.`entry`);

-- 2c. MAP 751 -- top two tiers (see the header: no band table, no 130+ tier)
INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`)
SELECT DISTINCT ct.`entry`, 0, it.`entry`, 0, 0, 0
FROM `creature_template` ct
JOIN (SELECT DISTINCT `id` FROM `creature` WHERE `map` = 751) sp ON sp.`id` = ct.`entry`
JOIN `item_template` it
  ON it.`entry` BETWEEN 400800 AND 400823 AND it.`subclass` = 5
WHERE it.`RequiredLevel` >= 110
  AND (ct.`npcflag` & (0x10000 | 0x100 | 0x200)) <> 0
  AND ct.`entry` NOT IN (
      SELECT DISTINCT `id` FROM `creature` WHERE `map` = 750);   -- 750 rules win for
                                                                 -- an NPC on both maps

-- ---------------------------------------------------------------------------
-- Trailer -- verification
-- ---------------------------------------------------------------------------
-- 🔴 THE ONE THAT MATTERS -- every innkeeper / general / food vendor on both maps
-- must now stock food, and must be able to sell it (expect 0 rows):
-- SELECT ct.entry, ct.name, ct.subname, ct.npcflag
-- FROM creature_template ct
-- WHERE ct.entry IN (SELECT DISTINCT id FROM creature WHERE map IN (750,751))
--   AND (ct.npcflag & (0x10000|0x100|0x200)) <> 0
--   AND ((ct.npcflag & 0x80) = 0
--        OR NOT EXISTS (SELECT 1 FROM npc_vendor v JOIN item_template i ON i.entry=v.item
--                       WHERE v.entry=ct.entry AND v.item BETWEEN 400800 AND 400823
--                         AND i.subclass=5));
--
-- Coverage by map and role (expect stocked = npcs on every row):
-- SELECT map, role, COUNT(*) AS npcs, SUM(stocked) AS stocked FROM (
--   SELECT ct.entry, MAX(CASE WHEN c.map=750 THEN 750 ELSE 751 END) AS map,
--     CASE WHEN ct.npcflag & 65536 THEN 'innkeeper'
--          WHEN ct.npcflag & 512 THEN 'food vendor' ELSE 'general goods' END AS role,
--     EXISTS (SELECT 1 FROM npc_vendor v JOIN item_template i ON i.entry=v.item
--             WHERE v.entry=ct.entry AND v.item BETWEEN 400800 AND 400823
--               AND i.subclass=5) AS stocked
--   FROM creature c JOIN creature_template ct ON ct.entry=c.id
--   WHERE c.map IN (750,751) AND ct.npcflag & (65536|256|512)
--   GROUP BY ct.entry, ct.npcflag) t
-- GROUP BY map, role ORDER BY map, role;
--
-- 🔴 POTIONS WERE NOT TOUCHED -- this count must be unchanged from before the run
-- (245_'s map-750 potion stock):
-- SELECT COUNT(*) FROM npc_vendor v JOIN item_template i ON i.entry = v.item
-- WHERE v.item BETWEEN 400800 AND 400823 AND i.subclass = 1;
--
-- 🔴 Zone 4928 has no `dc_map750_band` row. 2b covers its vendors, but anything
-- else that bands by zone is still blind to it -- worth fixing at the source:
-- SELECT DISTINCT ez.zone FROM dc_map750_entryzone ez
-- WHERE NOT EXISTS (SELECT 1 FROM dc_map750_band b WHERE b.zone = ez.zone);
--
-- Sanity on the 751 tiers -- only Summit and Nordrassil, nothing lower:
-- SELECT DISTINCT i.RequiredLevel, i.name FROM npc_vendor v
-- JOIN item_template i ON i.entry = v.item
-- WHERE i.subclass = 5 AND v.item BETWEEN 400800 AND 400823
--   AND v.entry IN (SELECT DISTINCT id FROM creature WHERE map = 751)
-- ORDER BY i.RequiredLevel;
--
-- In game: talk to any innkeeper on either map; the food should be buyable, and
-- on 751 the list should start at Summit Ranger Ration.
-- ---------------------------------------------------------------------------
