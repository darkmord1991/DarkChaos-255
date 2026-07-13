-- ---------------------------------------------------------------------------
-- npc_vendor backfill catch-up (Mount Hyjal, map 750) -- Edric Downing
-- ---------------------------------------------------------------------------
-- More-db-errors audit pass (2026-07-13): entry 3643565 "Edric Downing"
-- (Butcher, plain VENDOR npcflag) still had zero npc_vendor rows even after
-- 72_npc_vendor_backfill.sql ran. Root cause: 72_'s
-- `AND EXISTS (SELECT 1 FROM item_template WHERE entry = nv.item)` guard
-- silently dropped this entry's only 2 items (59231, 59232) because those
-- items didn't exist in item_template yet at the time 72_ was actually
-- executed against the live DB (worlddb/dc_vendor_item_downport_2026_07_10.sql,
-- which adds 59231/59232, is a separate top-level file -- apply order on the
-- live DB apparently put it after 72_, even though apply_all.sql's own
-- in-file ordering is fine). Items now exist; this just re-runs the same
-- entry through the same idempotent DELETE+INSERT so it picks them up.
-- Not a `stable master` false-positive like 45297 (Deepholm) -- Edric is a
-- plain vendor NPC (npcflag=128 only) that should have real wares.
-- ---------------------------------------------------------------------------
DELETE FROM `npc_vendor` WHERE `entry` = 3643565;

INSERT INTO `npc_vendor` (`entry`,`slot`,`item`,`maxcount`,`incrtime`,`ExtendedCost`)
SELECT nv.entry + 3600000, nv.slot, nv.item, nv.maxcount, nv.incrtime, nv.ExtendedCost
FROM `nelt_world`.`npc_vendor` nv
WHERE nv.entry = 43565
AND EXISTS (SELECT 1 FROM `item_template` it WHERE it.entry = nv.item);
