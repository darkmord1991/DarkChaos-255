-- ---------------------------------------------------------------------------
-- npc_vendor backfill  (Mount Hyjal, map 750)
-- ---------------------------------------------------------------------------
-- 27 vendor-flagged creatures had NO npc_vendor rows at all (never ported).
-- Cloned directly from nelt_world.npc_vendor (all 27 have complete data
-- there). All referenced items now exist in item_template (see
-- worlddb/dc_vendor_item_downport_2026_07_10.sql for the 19 that were
-- missing and got downported first).
-- ---------------------------------------------------------------------------
DELETE FROM `npc_vendor` WHERE `entry` IN (3643547,3643548,3643493,3643380,3643550,3643551,3653780,3653781,3653782,3653075,3653076,3643554,3643555,3654401,3654402,3640843,3643408,3643410,3643411,3643563,3643564,3643565,3650314,3643381,3643494,3643495,3643379);

INSERT INTO `npc_vendor` (`entry`,`slot`,`item`,`maxcount`,`incrtime`,`ExtendedCost`)
SELECT nv.entry + 3600000, nv.slot, nv.item, nv.maxcount, nv.incrtime, nv.ExtendedCost
FROM `nelt_world`.`npc_vendor` nv
WHERE nv.entry IN (43547,43548,43493,43380,43550,43551,53780,53781,53782,53075,53076,43554,43555,54401,54402,40843,43408,43410,43411,43563,43564,43565,50314,43381,43494,43495,43379)
AND EXISTS (SELECT 1 FROM `item_template` it WHERE it.entry = nv.item);
