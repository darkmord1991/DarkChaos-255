-- ---------------------------------------------------------------------------
-- 185  Hyjal round-45 -- repair trainer links 184_ removed
-- ---------------------------------------------------------------------------
-- REGRESSION FIX.  184_ cleared creature_default_trainer for EVERY map-750
-- trainer and then re-inserted only those whose `subname` matched its CASE
-- list.  Two NPCs already had correct links and were not in that list, so they
-- lost them:
--
--   Jenna Lemkenilli (3711037) "Engineering Trainer" -- Engineering was simply
--     missing from 184_'s CASE.  Her base entry 11037 links to trainer 92.
--   Meilosh (3711557) -- subname is NULL (a specialization trainer), so no
--     CASE arm could ever match.  Base entry 11557 links to trainer 74.
--
-- The rule below is more robust than matching on subname: MIRROR THE BASE
-- ENTRY'S LINK.  A cloned NPC is the same NPC at an offset entry, so whatever
-- trainer the original is bound to in stock data is by definition right for the
-- clone -- no interpretation of the subname needed, and it self-heals any
-- future import that clones a trainer this file has never heard of.
--
-- Safe to run repeatedly: NOT EXISTS skips anything already linked, so it
-- cannot disturb the 32 links that are currently correct.
-- ---------------------------------------------------------------------------

INSERT INTO `creature_default_trainer` (`CreatureId`, `TrainerId`)
SELECT DISTINCT t.`entry`,
  (SELECT MIN(d2.`TrainerId`) FROM `creature_default_trainer` d2
    WHERE d2.`CreatureId` IN (CAST(t.`entry` AS SIGNED) - 3600000,
                              CAST(t.`entry` AS SIGNED) - 3700000,
                              CAST(t.`entry` AS SIGNED) - 3900000))
FROM `creature` c
JOIN `creature_template` t ON t.`entry` = c.`id`
WHERE c.`map` = 750
  AND (t.`npcflag` & 16)
  AND NOT EXISTS (SELECT 1 FROM `creature_default_trainer` d WHERE d.`CreatureId` = t.`entry`)
  AND EXISTS (SELECT 1 FROM `creature_default_trainer` d3
              WHERE d3.`CreatureId` IN (CAST(t.`entry` AS SIGNED) - 3600000,
                                        CAST(t.`entry` AS SIGNED) - 3700000,
                                        CAST(t.`entry` AS SIGNED) - 3900000));

-- Verify -- expect 0 (every flagged trainer on map 750 now has a link):
--   SELECT COUNT(DISTINCT t.entry) FROM `creature` c
--     JOIN `creature_template` t ON t.entry = c.id
--    WHERE c.map = 750 AND (t.npcflag & 16)
--      AND NOT EXISTS (SELECT 1 FROM `creature_default_trainer` d
--                      WHERE d.CreatureId = t.entry);
