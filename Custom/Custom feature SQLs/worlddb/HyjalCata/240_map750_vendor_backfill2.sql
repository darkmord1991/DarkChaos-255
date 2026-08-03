-- ---------------------------------------------------------------------------
-- 240  Map 750 -- second vendor backfill (38 empty shop windows)
-- ---------------------------------------------------------------------------
-- 38 of 144 vendor-flagged templates spawned on map 750 have zero npc_vendor
-- rows -- clicking them opens an empty window. Same class of gap 152_/160_
-- fixed for earlier import rounds; this pass covers everything spawned today.
--
--   * if the Cata source (entry - 3.6M / - 3.7M) has vendor rows: copy them,
--     keeping only items that exist in item_template;
--   * if the source has none either (or every item filtered): strip the
--     vendor bit (0x80) so the window no longer opens empty.
--
-- ExtendedCost is copied verbatim -- stock ItemExtendedCost ids resolve fine.
-- Run any time after 231_ (uses dc_map750_entryzone only in the trailer).
-- Idempotent: the copy targets only vendors that STILL have no rows, the
-- flag-strip only vendors that still have none afterwards.
-- ---------------------------------------------------------------------------

-- 1. copy vendor stock from the Cata source where it exists
INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`)
SELECT ct.`entry`, v.`slot`, v.`item`, v.`maxcount`, v.`incrtime`, v.`ExtendedCost`
FROM `creature_template` ct
JOIN `cata_world`.`npc_vendor` v
  ON v.`entry` = ct.`entry` - IF(ct.`entry` < 3700000, 3600000, 3700000)
WHERE ct.`entry` BETWEEN 3600000 AND 3799999
  AND (ct.`npcflag` & 0x80) <> 0
  AND ct.`entry` IN (SELECT DISTINCT c.`id` FROM `creature` c WHERE c.`map` = 750)
  AND NOT EXISTS (SELECT 1 FROM `npc_vendor` nv WHERE nv.`entry` = ct.`entry`)
  AND EXISTS (SELECT 1 FROM `item_template` it WHERE it.`entry` = v.`item`);

-- 2. strip the vendor bit from windows that are still empty
UPDATE `creature_template` ct
SET ct.`npcflag` = ct.`npcflag` & ~0x80
WHERE ct.`entry` BETWEEN 3600000 AND 3799999
  AND (ct.`npcflag` & 0x80) <> 0
  AND ct.`entry` IN (SELECT DISTINCT c.`id` FROM `creature` c WHERE c.`map` = 750)
  AND NOT EXISTS (SELECT 1 FROM `npc_vendor` nv WHERE nv.`entry` = ct.`entry`);

-- ---------------------------------------------------------------------------
-- Trailer -- verification (expect 0 empty vendors left on map 750)
-- ---------------------------------------------------------------------------
-- SELECT COUNT(*) FROM creature_template ct
-- WHERE ct.entry BETWEEN 3600000 AND 3799999 AND (ct.npcflag & 0x80) <> 0
--   AND ct.entry IN (SELECT DISTINCT id FROM creature WHERE map = 750)
--   AND NOT EXISTS (SELECT 1 FROM npc_vendor nv WHERE nv.entry = ct.entry);
-- what got stocked:
-- SELECT ez.zone, COUNT(DISTINCT nv.entry) vendors, COUNT(*) lines
-- FROM npc_vendor nv JOIN dc_map750_entryzone ez ON ez.entry = nv.entry
-- GROUP BY ez.zone;
