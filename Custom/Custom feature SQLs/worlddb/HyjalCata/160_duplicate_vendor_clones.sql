-- ---------------------------------------------------------------------------
-- 160  Hyjal round-26 -- five vendors cloned twice under two entry ids
-- ---------------------------------------------------------------------------
-- Found by running 158_'s own verification query (same-name service NPCs within
-- 40 yards) after the restart.  It still returned 12 pairs, and NONE of them
-- came from the 155_ import -- these predate it and 154_ missed them, because
-- 154_ worked from a hand-built candidate list rather than the full result set.
-- Lesson: the sanity query is the source of truth, not the list that fed the
-- fix.
--
-- Five are real duplicates.  Each is the SAME vendor cloned into two entries,
-- one in the 3,643,xxx block and one in 3,653,xxx, spawned once each, standing
-- 0-38 yards apart.  None starts or ends a quest, so nothing is lost by
-- dropping one spawn:
--
--   entry     name                  subname                  vendor items
--   3643380 / 3653782  Jalin Lakedeep      Leatherworking Supplies   17 / 17   (0y apart)
--   3643551 / 3653076  Nenduil Meadowshade General Goods             24 / 13   (19y)
--   3643550 / 3653075  Inoho Stronghide    Leatherworking Supplies   17 / 17   (21y)
--   3643379 / 3653780  Limiah Whitebranch  Stable Master              1 /  1   (27y)
--   3643381 / 3653781  Tomo                General Goods             24 / 13   (38y)
--
-- The 3,643,xxx copy is kept in every case.  For Jalin, Inoho and Limiah the
-- two are identical so the lower entry wins by convention; for Nenduil and Tomo
-- it also happens to carry the FULLER stock (24 items vs 13), so keeping it
-- preserves goods that dropping the other way would have lost.
--
-- Verified before writing: these 5 guids have zero rows in `creature_addon`,
-- `pool_creature`, `game_event_creature`, `creature_formations` and guid-keyed
-- `smart_scripts`.  The 3,653,xxx templates are left in place -- only the spawn
-- rows go, so nothing that references the entry breaks.
--
-- NOT touched (the other 7 pairs the query returns, all correct as-is):
--   * Kalecgos 3652995/3653009 at 4y -- quest starter and ender, documented in 154_
--   * Fire Attacker Portal (3652531) x4 pairs on map 861 -- a 10-spawn objective set
--   * Twilight Overseer (3640123) x2 pairs -- generic patrol group
--
-- Idempotent.
-- ---------------------------------------------------------------------------

DELETE FROM `creature` WHERE `guid` IN (
    9843540,   -- Jalin Lakedeep      3653782, 0y from 3643380 guid 9842355
    9843570,   -- Nenduil Meadowshade 3653076, 19y from 3643551 guid 9842748 (13 items vs 24)
    9843565,   -- Inoho Stronghide    3653075, 21y from 3643550 guid 9842747
    9843538,   -- Limiah Whitebranch  3653780, 27y from 3643379 guid 12199068
    9843539    -- Tomo                3653781, 38y from 3643381 guid 12196774 (13 items vs 24)
);

DELETE FROM `creature_addon` WHERE `guid` IN (9843540,9843570,9843565,9843538,9843539);

-- ---------------------------------------------------------------------------
-- Ranshalla -- 156_ missed her because she arrived afterwards
-- ---------------------------------------------------------------------------
-- 157_ (the opt-in Winterspring/snow-area import) brought stock creature 10300
-- "Ranshalla" onto map 750.  She carries the questgiver+gossip npcflag but not
-- UNIT_FLAG_IMMUNE_TO_NPC, because 156_ had already run by then.  This is the
-- ordering hazard of a flag sweep scoped by "is spawned on map 750/861": any
-- later import re-opens the gap.
--
-- Re-running 156_ would also fix it; this repeats the sweep here so 160_ is
-- self-sufficient, and it stays correct if 157_ is applied later or extended to
-- the other three bands.
UPDATE `creature_template` ct
SET ct.`unit_flags` = ct.`unit_flags` | 512
WHERE (ct.`npcflag` & 130) <> 0
  AND (ct.`unit_flags` & 512) = 0
  AND EXISTS (SELECT 1 FROM `creature` c WHERE c.`id` = ct.`entry` AND c.`map` IN (750, 861));
