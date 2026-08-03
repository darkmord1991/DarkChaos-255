-- ---------------------------------------------------------------------------
-- 222  Range-based SmartAI events -- distance stored in the WRONG PARAMS
-- ---------------------------------------------------------------------------
-- This started as "fix the 17 rows the log rejects" and turned out to be the
-- visible tip of a 226-row layout mismatch.  Only 17 of them log anything.
--
-- THIS CORE IS NOT UPSTREAM HERE.  Upstream AzerothCore's SMART_EVENT_RANGE
-- takes four params and reads the DISTANCE from params 1/2:
--     IsInRange(victim, e.event.minMaxRepeat.min, e.event.minMaxRepeat.max)
-- Our fork extended minMaxRepeat to six fields and moved the distance to
-- params 5/6, leaving 1/2 as an initial-timer pair:
--     SmartScriptMgr.h:108   // min, max, repeatMin, repeatMax, rangeMin, rangeMax
--     SmartScript.cpp:4254   IsInRange(victim, minMaxRepeat.rangeMin, minMaxRepeat.rangeMax)
--     SmartScript.cpp:4996   RecalcTimer(e, minMaxRepeat.min, minMaxRepeat.max)
-- So on THIS core the correct shape is  p1=0, p2=0, p3/p4=repeat, p5/p6=distance.
-- Stock content already follows it: 1460 of 1504 stock rows populate param6.
-- Our Cata imports followed the UPSTREAM shape, so 226 of 245 clone-band rows
-- put the distance somewhere the engine never reads.
--
-- WHY THIS MATTERS MORE THAN THE LOG SUGGESTS.  IsInRange(victim, 0, 0) is not
-- "no limit" -- maxdist collapses to the combined bounding radius, so the event
-- only fires when the victim is literally touching the caster.  Every one of
-- these rows is a ranged ability that currently fires only in melee, or a
-- combat-movement toggle that never flips.  The rows load without complaint;
-- they just quietly do the wrong thing.  The 17 the log DOES reject are only
-- the subset where rangeMin got through but rangeMax did not, making the pair
-- invalid (IsMinMaxValid, SmartScriptMgr.h:2147) -- e.g. "(5/0)".
--
-- FOUR EVENT TYPES share the minMaxRepeat union and the same rangeMin/rangeMax
-- reads, so all four are repaired: 9 RANGE, 67 IS_BEHIND_TARGET,
-- 105 AREA_CASTING, 106 AREA_RANGE.
--
-- CHECKED AND DELIBERATELY LEFT ALONE:
--   74 FRIENDLY_HEALTH_PCT -- also six params, but they are (hpPct, radius),
--      not a distance pair.  All 5 rows already carry hpPct in param5, and all
--      5 use target types that take the GetTargets() path where radius is never
--      read (SmartScript.cpp:4708-4732).  Shifting them would corrupt hpPct.
--   110 IS_IN_MELEE_RANGE -- params are (dist, invert); zero rows in the band.
--
-- WHERE THE VALUES COME FROM.  Three distinct damage patterns, so three rules.
-- The row's own comment is the fallback source and it is trustworthy here: it
-- is generated from the source script ("... - Within 5-30 Range - Cast X"), it
-- travelled with the row, and it agrees with whichever param slot survived in
-- every case where one did.  It is the ONLY carrier for 40 rows where both
-- numbers were dropped.  Re-deriving from cata_world was rejected: the source
-- row ids do not line up (cata 3691 has ids 1/2/3 = Net/Explosive Shot/Volley,
-- ours has 1/2/4 = Multi-Shot/Explosive Shot/Net), so a per-row join would
-- silently pair the wrong abilities.
--
-- SCOPE is the clone band 3600000-3999999 (Cata-derived content: Hyjal +3.6M,
-- border creatures +3.7M, gameobjects +3.9M).  That is 37 rows wider than the
-- "spawned on map 750/751" scoping used by 199_/201_ -- those 37 belong to
-- imported entries with no spawn yet.  They load into SmartAIMgr all the same
-- and carry the identical defect, so fixing them now costs nothing and avoids
-- a repeat of this file the day something spawns them.  No stock row is in
-- range of any statement below, and all 245 rows are source_type 0.
--
-- Every statement is written as its rule, not as an id list, and each is a
-- no-op on a row that is already correct -- safe to re-run.
-- ---------------------------------------------------------------------------

-- --- A. distance sits in params 1/2, upstream-style (169 rows) --------------
-- Move it to 5/6 and clear 1/2.  Clearing is correct, not merely tidy: 1/2 are
-- the initial-timer pair here, and the values found there are distances (5, 8,
-- 20, 30, 40) which as a timer mean "a few milliseconds" -- i.e. fire at once,
-- which is what stock's 0/0 already does.  No timing changes.
--
-- ASSIGNMENT ORDER BELOW IS LOAD-BEARING: MySQL evaluates single-table UPDATE
-- assignments left to right and later ones see the already-updated values, so
-- the two reads MUST come before the two zeroings.  Swap them and every row
-- ends up with 0/0 for the distance -- silently, with the same row count.
UPDATE `smart_scripts`
SET `event_param5` = `event_param1`,
    `event_param6` = `event_param2`,
    `event_param1` = 0,
    `event_param2` = 0
WHERE `source_type` = 0
  AND `event_type` IN (9, 67, 105, 106)
  AND `entryorguid` BETWEEN 3600000 AND 3999999
  AND `event_param6` = 0
  AND `event_param2` > 0;

-- --- B. rangeMin survived, rangeMax was dropped (17 rows) -------------------
-- These are exactly the rows the worldserver rejects with "uses min/max params
-- wrong": param5 = 5 or 25 against param6 = 0.  Recover the max from the
-- comment; the guard requires a well-formed "A-B" that is actually larger than
-- the min, so a malformed comment skips the row rather than inventing a range.
UPDATE `smart_scripts`
SET `event_param6` = CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(SUBSTRING_INDEX(`comment`, ' Range', 1), ' ', -1), '-', -1) AS UNSIGNED)
WHERE `source_type` = 0
  AND `event_type` IN (9, 67, 105, 106)
  AND `entryorguid` BETWEEN 3600000 AND 3999999
  AND `event_param6` = 0
  AND `event_param2` = 0
  AND `event_param5` > 0
  AND SUBSTRING_INDEX(SUBSTRING_INDEX(`comment`, ' Range', 1), ' ', -1) REGEXP '^[0-9]+-[0-9]+$'
  AND CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(SUBSTRING_INDEX(`comment`, ' Range', 1), ' ', -1), '-', -1) AS UNSIGNED) > `event_param5`;

-- --- C. both numbers dropped, comment is the only record (40 rows) ---------
-- The import wrote the comment but neither param pair.  Same guarded parse.
-- It intentionally matches both comment styles the imports produced --
-- "... - Within 0-5 Range - ..." and "Mastok Wrilehiss - 0-5 Range - ..." --
-- by taking the last token before " Range" rather than anchoring on "Within".
UPDATE `smart_scripts`
SET `event_param5` = CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(SUBSTRING_INDEX(`comment`, ' Range', 1), ' ', -1), '-', 1) AS UNSIGNED),
    `event_param6` = CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(SUBSTRING_INDEX(`comment`, ' Range', 1), ' ', -1), '-', -1) AS UNSIGNED)
WHERE `source_type` = 0
  AND `event_type` IN (9, 67, 105, 106)
  AND `entryorguid` BETWEEN 3600000 AND 3999999
  AND `event_param6` = 0
  AND `event_param2` = 0
  AND `event_param5` = 0
  AND SUBSTRING_INDEX(SUBSTRING_INDEX(`comment`, ' Range', 1), ' ', -1) REGEXP '^[0-9]+-[0-9]+$'
  AND CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(SUBSTRING_INDEX(`comment`, ' Range', 1), ' ', -1), '-', -1) AS UNSIGNED) > 0
  AND CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(SUBSTRING_INDEX(`comment`, ' Range', 1), ' ', -1), '-', -1) AS UNSIGNED)
      >= CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(SUBSTRING_INDEX(`comment`, ' Range', 1), ' ', -1), '-', 1) AS UNSIGNED);

-- ---------------------------------------------------------------------------
-- FIVE ROWS ARE NOT REPAIRABLE FROM ANYTHING ON DISK, and are left untouched
-- rather than guessed at.  All five are "fires only at contact" today:
--
--   3612858 id 14  "Torek - IC - Cast Rend"
--        Event type is RANGE but the comment says IC (in combat) and carries no
--        distance at all.  Looks like the source event type was mistranslated
--        on import; converting it to SMART_EVENT_UPDATE_IC (0) would probably
--        be right, but that is a behaviour change, not a data repair.
--   3614715 id 11  "Silverwing Elite - Within 0-0 Range - Disable Combat Movement"
--        The comment itself says 0-0.  Its three sibling archers (3614733,
--        3614753, 3624738) all use 5-15 for the same row, so this is very
--        likely a source typo -- but "very likely" is not a reason to write
--        gameplay numbers, so it stays 0-0 and stays listed here.
--   3 further rows whose comments carry no numeric range in any form.
--
-- Query them any time with the inverse of the three rules above:
--   SELECT entryorguid, id, event_type, event_param5, event_param6, comment
--     FROM `smart_scripts`
--    WHERE source_type = 0 AND event_type IN (9,67,105,106)
--      AND entryorguid BETWEEN 3600000 AND 3999999 AND event_param6 = 0;
-- ---------------------------------------------------------------------------

-- Verify -- (1) must return 0, (2) must return exactly the 5 rows above:
--   SELECT COUNT(*) FROM `smart_scripts`
--    WHERE source_type = 0 AND event_type IN (9,67,105,106)
--      AND entryorguid BETWEEN 3600000 AND 3999999
--      AND (event_param2 > 0 OR (event_param5 > 0 AND event_param6 = 0));
--   SELECT COUNT(*) FROM `smart_scripts`
--    WHERE source_type = 0 AND event_type IN (9,67,105,106)
--      AND entryorguid BETWEEN 3600000 AND 3999999 AND event_param6 = 0;
-- and the boot log must lose all 17 "uses min/max params wrong" lines.
