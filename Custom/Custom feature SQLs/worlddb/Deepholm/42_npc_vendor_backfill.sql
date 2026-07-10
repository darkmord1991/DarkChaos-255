-- ---------------------------------------------------------------------------
-- npc_vendor backfill  (Deepholm, map 646)
-- ---------------------------------------------------------------------------
-- 10 vendor-flagged creatures had NO npc_vendor rows at all (never ported).
-- Cloned directly from nelt_world.npc_vendor (richer/more complete source
-- than cata_world for this table -- cata_world only had data for 2/11 of
-- these entries; nelt_world has all 10 recoverable ones). The 11th
-- vendor-flagged entry (45407 "Ibdil the Mender") has zero vendor rows in
-- BOTH source DBs -- genuinely empty in retail too (repair-only), not a gap.
-- All referenced items now exist in item_template (see
-- worlddb/dc_vendor_item_downport_2026_07_10.sql for the 19 that were
-- missing and got downported first).
-- ---------------------------------------------------------------------------
DELETE FROM `npc_vendor` WHERE `entry` IN (44970,44972,45289,45290,45293,45294,45298,45361,45408);

INSERT INTO `npc_vendor` (`entry`,`slot`,`item`,`maxcount`,`incrtime`,`ExtendedCost`)
SELECT nv.entry, nv.slot, nv.item, nv.maxcount, nv.incrtime, nv.ExtendedCost
FROM `nelt_world`.`npc_vendor` nv
WHERE nv.entry IN (44970,44972,45289,45290,45293,45294,45298,45361,45408)
AND EXISTS (SELECT 1 FROM `item_template` it WHERE it.entry = nv.item);
