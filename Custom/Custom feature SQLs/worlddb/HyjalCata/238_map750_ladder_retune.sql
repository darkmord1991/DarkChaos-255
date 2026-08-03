-- ---------------------------------------------------------------------------
-- 238  Map 750 -- re-tune the 400xxx ladder RequiredLevels to the bands
-- ---------------------------------------------------------------------------
-- The ladder was authored as 4 tiers for a compressed 80-130 grind:
--
--   tier  entries          ilvl  quality  RequiredLevel  ->  NEW
--   T1    400041-400055    300   rare     82                 82  (unchanged)
--   T2    400056-400070    332   rare     97                 92
--   T3    400083-400097    372   rare     112                102
--   T4    400110-400124    398   epic     127                115
--
-- With the classic bands each tier must be equippable INSIDE the band that
-- drops/sells it: T2 in Ashenvale 88-98, T3 in Felwood 96-106, T4 in Hyjal
-- 113-130. The re-tune also closes the 101-120 item-band hole (previously 62
-- items server-wide) with 30 real pieces at 102/115 -- no new item ids, hence
-- NO client patch: only RequiredLevel moves, stats and ItemLevel stay.
--
-- Vendor side sells the same ids (ItemExtendedCost token pricing unchanged),
-- so the token ladder shifts down in lockstep automatically.
--
-- Absolute assignments -> idempotent. No ordering dependency beyond being in
-- this series (237_'s references work either way).
-- ---------------------------------------------------------------------------

UPDATE `item_template` SET `RequiredLevel` = 92
WHERE `entry` BETWEEN 400056 AND 400070;

UPDATE `item_template` SET `RequiredLevel` = 102
WHERE `entry` BETWEEN 400083 AND 400097;

UPDATE `item_template` SET `RequiredLevel` = 115
WHERE `entry` BETWEEN 400110 AND 400124;

-- ---------------------------------------------------------------------------
-- Trailer -- verification (expect exactly 15 items at each of 82/92/102/115)
-- ---------------------------------------------------------------------------
-- SELECT RequiredLevel, ItemLevel, COUNT(*) FROM item_template
-- WHERE entry BETWEEN 400041 AND 400124
--   AND (entry BETWEEN 400041 AND 400070 OR entry BETWEEN 400083 AND 400097
--        OR entry BETWEEN 400110 AND 400124)
-- GROUP BY RequiredLevel, ItemLevel ORDER BY RequiredLevel;
