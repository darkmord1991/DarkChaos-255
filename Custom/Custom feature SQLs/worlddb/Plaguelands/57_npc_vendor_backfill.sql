-- ---------------------------------------------------------------------------
-- npc_vendor backfill  (DC Plaguelands, map 751)
-- ---------------------------------------------------------------------------
-- 51 vendor-flagged creatures had NO npc_vendor rows at all (never ported).
-- Cloned directly from nelt_world.npc_vendor (all 51 have complete data
-- there). All referenced items now exist in item_template (see
-- worlddb/dc_vendor_item_downport_2026_07_10.sql for the 19 that were
-- missing and got downported first).
-- ---------------------------------------------------------------------------
DELETE FROM `npc_vendor` WHERE `entry` IN (3610857,3611038,3611056,3611278,3611287,3611536,3612384,3612941,3612942,3616256,3616376,3628500,3629203,3629205,3629207,3629208,3629587,3645148,3645149,3645417,3645451,3645500,3646269,3647104,3647105,3647106,3647139,3647142,3647144,3647148,3647149,3647153,3647164,3647165,3647166,3647167,3647286,3647288,3647717,3647719,3647721,3647756,3647757,3647758,3647761,3647854,3647856,3647858,3647860,3647863,3647864);

INSERT INTO `npc_vendor` (`entry`,`slot`,`item`,`maxcount`,`incrtime`,`ExtendedCost`)
SELECT nv.entry + 3600000, nv.slot, nv.item, nv.maxcount, nv.incrtime, nv.ExtendedCost
FROM `nelt_world`.`npc_vendor` nv
WHERE nv.entry IN (10857,11038,11056,11278,11287,11536,12384,12941,12942,16256,16376,28500,29203,29205,29207,29208,29587,45148,45149,45417,45451,45500,46269,47104,47105,47106,47139,47142,47144,47148,47149,47153,47164,47165,47166,47167,47286,47288,47717,47719,47721,47756,47757,47758,47761,47854,47856,47858,47860,47863,47864)
AND EXISTS (SELECT 1 FROM `item_template` it WHERE it.entry = nv.item);
