-- ---------------------------------------------------------------------------
-- 236  Map 750 -- spread the Cata drop-gear RequiredLevel across the bands
-- ---------------------------------------------------------------------------
-- 99_/149_ filled the ~625 downported Cata armor/weapon shells that drop in
-- this zone with authentic stats but authentic RequiredLevel 80-85. After
-- 233_'s re-level a level-105 Felwood mob would still drop "Requires Level 82"
-- gear. This file re-bands RequiredLevel to the dropping zone:
--
--   RequiredLevel = band t_lo + 2      (80-90 -> 82 ... 113-128 -> 115)
--   multi-zone drops take the LOWEST band (an item usable earlier is harmless)
--
-- ItemLevel / stats are NOT touched: the 400xxx ladder (237_/238_) is the
-- power path; these are the classic flavor greens/blues with real Cata names
-- and icons. (A stat uplift would be a separate, optional file -- deferred.)
--
-- Scope guards, all four required to touch a row:
--   * class 2/4 equippable (weapon/armor), InventoryType > 0
--   * entry in the downport band 60000-299999 (never a stock 3.3.5 item)
--   * entry exists in nelt_world.`db_item-sparse_15595` (it IS a Cata shell)
--   * dropped by a map-750 clone's loot table (post-232 fork: lootid = entry)
--
-- Absolute assignment -> idempotent. Run AFTER 232_ and 233_.
-- ---------------------------------------------------------------------------

UPDATE `item_template` it
JOIN (
    SELECT clt.`Item` AS item, MIN(b.`t_lo`) AS lo
    FROM `creature_loot_template` clt
    JOIN `dc_map750_entryzone` ez ON ez.`entry` = clt.`Entry`
    JOIN `dc_map750_band` b ON b.`zone` = ez.`zone`
    WHERE clt.`Reference` = 0
    GROUP BY clt.`Item`
) d ON d.item = it.`entry`
JOIN `nelt_world`.`db_item-sparse_15595` sp ON sp.`ID` = it.`entry`
SET it.`RequiredLevel` = d.lo + 2
WHERE it.`class` IN (2, 4)
  AND it.`InventoryType` > 0
  AND it.`entry` BETWEEN 60000 AND 299999;

-- ---------------------------------------------------------------------------
-- Trailer -- verification
-- ---------------------------------------------------------------------------
-- distribution after apply (expect peaks at 82 / 90 / 98 / 106 / 115):
-- SELECT it.RequiredLevel, COUNT(*) FROM item_template it
-- JOIN nelt_world.`db_item-sparse_15595` sp ON sp.ID = it.entry
-- WHERE it.class IN (2, 4) AND it.entry BETWEEN 60000 AND 299999
--   AND it.entry IN (SELECT DISTINCT clt.Item FROM creature_loot_template clt
--                    JOIN dc_map750_entryzone ez ON ez.entry = clt.Entry)
-- GROUP BY it.RequiredLevel ORDER BY it.RequiredLevel;
-- nothing outside 82-115 in that set (expect 0):
-- (same query with HAVING it.RequiredLevel NOT IN (82, 90, 98, 106, 115))
