-- ---------------------------------------------------------------------------
-- 245  Map 750 -- the 80-130 consumable line on every innkeeper/goods vendor
-- ---------------------------------------------------------------------------
-- The branded consumable line (400800-400823: Emberwood 80 / Skyfire 95 /
-- Summit 110 / Nordrassil 125 -- food+drink+feast and heal/mana/restore
-- potions per tier) was only sold at the nine Hyjal-hub vendors (98_). On a
-- continent-wide leveling path players must be able to resupply at EVERY hub:
--
--   * FOOD & DRINK (subclass 5) -> every innkeeper and food-selling vendor;
--   * POTIONS (subclass 1)      -> every general-goods/trade/provisioner
--     vendor;
--   * stock is BAND-AWARE: a vendor carries the tiers whose RequiredLevel
--     fits its zone's band (tier ReqLvl <= band top + 10, so the next tier is
--     always available for pre-buying). Darkshore/Azshara/Ashenvale sell
--     Emberwood+Skyfire, Felwood adds Summit, Winterspring/Hyjal sell all.
--
-- SUPERSEDES 98_'s stocking (this file's DELETE re-derives those rows; the
-- nine Hyjal vendors are zone 4923 and get the full line again). Innkeepers
-- that lack the vendor bit (e.g. Kyteran, 0x10001) get it OR'd on.
--
-- 98_'s prerequisite is RESOLVED: the consumable spells 300550-300569 /
-- 300584-300587 are present in server spell_dbc (verified 24/24 rows,
-- 2026-08-03) -- the food/potions are fully functional.
--
-- Run AFTER 231_ (dc_map750_entryzone) and 233_ (dc_map750_band).
-- Idempotent (full DELETE + re-derive of the 400800-400823 vendor rows).
-- ---------------------------------------------------------------------------

-- 1. innkeepers on map 750 that cannot sell yet: add the vendor bit
UPDATE `creature_template` ct
JOIN `dc_map750_entryzone` ez ON ez.`entry` = ct.`entry`
SET ct.`npcflag` = ct.`npcflag` | 0x80
WHERE (ct.`npcflag` & 0x10000) <> 0
  AND (ct.`npcflag` & 0x80) = 0;

-- 2. re-derive all consumable stock rows
DELETE FROM `npc_vendor` WHERE `item` BETWEEN 400800 AND 400823;

-- 2a. food & drink -> innkeepers and food vendors, band-aware
INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`)
SELECT DISTINCT ct.`entry`, 0, it.`entry`, 0, 0, 0
FROM `creature_template` ct
JOIN `dc_map750_entryzone` ez ON ez.`entry` = ct.`entry`
JOIN `dc_map750_band` b ON b.`zone` = ez.`zone`
JOIN `item_template` it
  ON it.`entry` BETWEEN 400800 AND 400823 AND it.`subclass` = 5
WHERE it.`RequiredLevel` <= b.`t_hi` + 10
  AND ((ct.`npcflag` & 0x10000) <> 0
       OR ct.`subname` LIKE '%Food%' OR ct.`subname` LIKE '%Drink%'
       OR ct.`subname` LIKE '%Butcher%' OR ct.`subname` LIKE '%Baker%'
       OR ct.`subname` LIKE '%Cook%'
       OR ct.`entry` IN (830139, 830152));  -- camp Cooks (name-only templates)

-- 2b. potions -> general-goods / trade / provisioner vendors, band-aware
INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`)
SELECT DISTINCT ct.`entry`, 0, it.`entry`, 0, 0, 0
FROM `creature_template` ct
JOIN `dc_map750_entryzone` ez ON ez.`entry` = ct.`entry`
JOIN `dc_map750_band` b ON b.`zone` = ez.`zone`
JOIN `item_template` it
  ON it.`entry` BETWEEN 400800 AND 400823 AND it.`subclass` = 1
WHERE it.`RequiredLevel` <= b.`t_hi` + 10
  AND (ct.`npcflag` & 0x80) <> 0
  AND (ct.`subname` LIKE '%General%' OR ct.`subname` LIKE '%Goods%'
       OR ct.`subname` LIKE '%Trade%' OR ct.`subname` LIKE '%Provision%'
       OR ct.`subname` LIKE '%Supplies%' OR ct.`subname` LIKE '%Supplier%'
       OR ct.`entry` IN (830137, 830150));  -- camp Provisioners (name-only)

-- Moonglade (4928) has no band row -- its Nighthaven vendors sit outside the
-- joins above by design (sanctuary, no re-level). Give its innkeeper/goods
-- vendors the full line so the rest stop is a real rest stop.
INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`)
SELECT DISTINCT ct.`entry`, 0, it.`entry`, 0, 0, 0
FROM `creature_template` ct
JOIN `dc_map750_entryzone` ez ON ez.`entry` = ct.`entry` AND ez.`zone` = 4928
JOIN `item_template` it ON it.`entry` BETWEEN 400800 AND 400823
WHERE ((ct.`npcflag` & 0x10000) <> 0 AND it.`subclass` = 5)
   OR ((ct.`npcflag` & 0x80) <> 0 AND it.`subclass` = 1
       AND (ct.`subname` LIKE '%General%' OR ct.`subname` LIKE '%Goods%'
            OR ct.`subname` LIKE '%Trade%' OR ct.`subname` LIKE '%Provision%'
            OR ct.`subname` LIKE '%Supplies%' OR ct.`subname` LIKE '%Supplier%'));

-- ---------------------------------------------------------------------------
-- Trailer -- verification
-- ---------------------------------------------------------------------------
-- vendors carrying the line, per zone (expect every zone represented):
-- SELECT ez.zone, COUNT(DISTINCT nv.entry) vendors, COUNT(*) lines
-- FROM npc_vendor nv JOIN dc_map750_entryzone ez ON ez.entry = nv.entry
-- WHERE nv.item BETWEEN 400800 AND 400823 GROUP BY ez.zone;
-- band-awareness spot check -- a Darkshore innkeeper must NOT sell Nordrassil
-- (125) tier:
-- SELECT nv.item FROM npc_vendor nv WHERE nv.entry = 3743420 ORDER BY nv.item;
-- no innkeeper without vendor bit left on 750 (expect 0):
-- SELECT COUNT(*) FROM creature_template ct
-- JOIN dc_map750_entryzone ez ON ez.entry = ct.entry
-- WHERE (ct.npcflag & 0x10000) <> 0 AND (ct.npcflag & 0x80) = 0;
