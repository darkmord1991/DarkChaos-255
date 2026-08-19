-- 86_smartai_repairs.sql -- map 751 Lordaeron extension, DB step 25.
--
-- Post-restart SmartAI error pass. Six classes, all verified against the core
-- source and against stock/Cata data rather than inferred from the message text.
--
-- Of the 171 SmartAIMgr errors in this boot, this file clears ~45. The remaining
-- ~120 are all "uses non-existent Spell entry NNNNN" and need a real Spell.dbc
-- downport (120 distinct Cata spells) -- see the note at the end of this file.
--
-- ===========================================================================
-- 1. Escort paths: the `waypoints` table was never imported
--
--    "SmartAIMgr: Creature 4150372 Event 0 Action 53 uses non-existent
--     WaypointPath id 50372, skipped."
--
--    Action 53 (SMART_ACTION_ESCORT_START) validates its path against
--    sSmartWaypointMgr, i.e. the **`waypoints`** table -- NOT `waypoint_data`,
--    which is the creature_addon path table 79_ used for the haulers. Two
--    separate systems with confusingly similar names.
--
--    The path id is in **action_param2** (`wpStart { forcedMovement; pathID; ... }`,
--    SmartScriptMgr.h:1030-1038), not action_param1. Reading param1 as the path
--    is why an earlier pass wrongly concluded these rows meant "use the
--    creature's own path".
--
--    Same root cause as creature_text and npc_spellclick_spells: the import
--    copied smart_scripts but not the table it depends on. 14 rows reference 14
--    distinct paths; all 14 exist in cata_world.waypoints, 214 points in total.
--
--    THE IDS ARE REMAPPED (+4,100,000) RATHER THAN COPIED AS-IS, because 5 of the
--    14 ALREADY EXIST in our `waypoints` under those numbers, belonging to the
--    STOCK creatures of the same id -- 5662 Sergeant Houser, 5697 Theresa, 6176
--    Bath'rah, 36217 Overseer Kraggosh, 61760. Importing over them would corrupt
--    stock data, and leaving them binds our imported NPC to a stock path with no
--    error logged at all: for 6176 the two even differ in length (ours 7 points,
--    Cata's 14), so that creature has been walking the wrong route silently.
--    Remapping gives every imported creature its own private, correct path and
--    leaves stock untouched. For the source_type=0 rows the remapped path id
--    lands on the creature's own entry, which is the usual AzerothCore
--    convention anyway.
--
--    The 14 source ids are written out literally rather than re-derived from
--    smart_scripts, because the UPDATEs below CHANGE the values a derived list
--    would read -- a second run would then select nothing and quietly repair
--    nothing. With literals, re-running is both safe and corrective.
--
--    All 14 targets were verified unoccupied. Two do not stay in the usual band:
--    504140 -> 4604140 and 3891000/3891001 -> 7991000/7991001, because those
--    Cata paths already use an entry*100-style id.
--
--    Column note: cata_world.waypoints has 10 columns to our 8 -- it adds
--    `velocity` and `smoothTransition`. Both are dropped; columns are listed
--    explicitly on both sides so the mismatch cannot shift a value.
-- ===========================================================================
DELETE FROM `waypoints` WHERE `entry` IN (
    4102435, 4105662, 4105697, 4106176, 4114739, 4136217, 4139117,
    4147405, 4150372, 4150414, 4161760, 4604140, 7991000, 7991001);

INSERT INTO `waypoints` (`entry`, `pointid`, `position_x`, `position_y`, `position_z`, `orientation`, `delay`, `point_comment`)
SELECT cw.`entry` + 4100000, cw.`pointid`, cw.`position_x`, cw.`position_y`, cw.`position_z`,
       cw.`orientation`, cw.`delay`, cw.`point_comment`
FROM `cata_world`.`waypoints` cw
WHERE cw.`entry` IN (
    2435, 5662, 5697, 6176, 14739, 36217, 39117,
    47405, 50372, 50414, 61760, 504140, 3891000, 3891001);

-- 1a. Repoint action 53 at the imported copy.
--     The `< 4100000` guard makes this idempotent -- an already-remapped id is
--     never shifted twice.
UPDATE `smart_scripts`
SET `action_param2` = `action_param2` + 4100000
WHERE `action_type` = 53
  AND ((`entryorguid` BETWEEN 4100000 AND 4199999)
    OR (`entryorguid` BETWEEN 410000000 AND 419999999))
  AND `action_param2` IN (2435, 5662, 5697, 6176, 14739, 36217, 39117,
                          47405, 50372, 50414, 61760, 504140, 3891000, 3891001);

-- 1b. THE OTHER HALF, WITHOUT WHICH 1a SILENTLY BREAKS WORKING SCRIPTS.
--
--     The escort EVENTS carry the same path id in **event_param2**
--     (`waypoint { pointID; pathID; }`, SmartScriptMgr.h:351-355), and at runtime
--     SmartScript.cpp:4645 compares it against GetPathId() -- the path action 53
--     started. Remap one without the other and every "on waypoint N reached"
--     trigger stops firing, because the row waits on 47405 while the creature
--     walks 4147405. That is worse than the bug being fixed: no error is logged,
--     the NPC just walks its route doing none of its stops.
--
--     15 rows are affected, all event_type 40 (ESCORT_REACHED) or 58
--     (ESCORT_ENDED). Their actions are the actual content -- pause, set
--     orientation, set emote state, run script -- for Southshore Crier, Theresa,
--     Overseer Kraggosh, Lilian Voss, The Chef, Aradne and Risen Recruit.
--
--     Events 55/56/57 are included for completeness; the band has none today.
--     Event 39 (ESCORT_START) is deliberately EXCLUDED: SmartScript.cpp:4631-4634
--     compares waypoint.pathID against var0, which SmartAI.cpp:264 passes as the
--     POINT id, so event_param2 is not a path id at runtime for that event. The
--     band has no event-39 rows, so nothing is lost either way.
--
--     Events 108/109 (WAYPOINT_REACHED/ENDED) and 34 (MOVEMENTINFORM) also carry
--     a path id, but theirs is me->GetWaypointPath() -- the creature_addon path
--     in `waypoint_data`, a different table. They must NOT be remapped here.
UPDATE `smart_scripts`
SET `event_param2` = `event_param2` + 4100000
WHERE `event_type` IN (40, 55, 56, 57, 58)
  AND ((`entryorguid` BETWEEN 4100000 AND 4199999)
    OR (`entryorguid` BETWEEN 410000000 AND 419999999))
  AND `event_param2` IN (2435, 5662, 5697, 6176, 14739, 36217, 39117,
                         47405, 50372, 50414, 61760, 504140, 3891000, 3891001);

-- ===========================================================================
-- 2. "has unused event_paramN with value X, it must be 0, skipped"
--
--    SmartAIMgr::CheckUnusedEventParams (SmartScriptMgr.cpp:609-732) is a pure
--    sizeof check: for each event type it computes how many uint32 slots that
--    event's struct occupies and requires every slot past it to be exactly 0.
--    A single stray value rejects the WHOLE row -- before action validation --
--    so a perfectly good cast or emote is thrown away over dead data.
--
--    19 rows, listed literally because the offending field differs per row.
--    Each was checked against the event's struct to confirm the value really is
--    outside it and therefore never read:
--      * event 13 / 11  -> 3-slot structs, so event_param4 is dead
--      * event 61 (LINK) -> no params at all; these rows are link TARGETS and
--        the importer copied the parent's params down into them as a comment.
--        The parent rows keep their own params, so the link still fires.
--      * event 6 with target_type 0 (NONE) -> target takes no params
--
--    Note 4102435 id 0 appears here AND in section 1: it needs both the path
--    import and this zeroing before it will load.
-- ===========================================================================
UPDATE `smart_scripts` SET `event_param4` = 0
WHERE `source_type` = 0 AND (`entryorguid`, `id`) IN (
    (4102254,2),(4102422,1),(4102435,0),(4102581,0),(4102584,1),
    (4104481,1),(4110696,2),(4148923,3),(4149263,1));

UPDATE `smart_scripts` SET `event_param1` = 0
WHERE `source_type` = 0 AND (`entryorguid`, `id`) IN (
    (4102610,3),(4106566,1),(4138910,1),(4138910,3),(4138910,8),(4138910,9),
    (4147405,2),(4147405,4));

UPDATE `smart_scripts` SET `event_param2` = 0
WHERE `source_type` = 0 AND `event_type` = 61 AND (`entryorguid`, `id`) IN (
    (4147405,2),(4147405,4));

UPDATE `smart_scripts` SET `target_param1` = 0
WHERE `source_type` = 0 AND (`entryorguid`, `id`) IN (
    (4147792,1),(4148187,2));

-- ===========================================================================
-- 3. "Entry 4102346 SourceType 0 Event 1 Action 11 has pct value above 100"
--
--    A CATA-VS-WOTLK PARAM LAYOUT DIVERGENCE, not a bad value. AC's
--    SMART_EVENT_FRIENDLY_HEALTH_PCT (74) struct is
--       { min, max, repeatMin, repeatMax, hpPct, radius }   SmartScriptMgr.h:434-442
--    while Cata's is shifted one slot left. Stock AzerothCore carries the very
--    same row for the un-remapped creature (2346 Dun Garok Priest, same event,
--    same spell 11642), which settles the correct values without guessing:
--
--       stock 2346 : 0 / 0  / 15000 / 21000 / 40    / 0   -> heal below 40%, every 15-21s
--       cata  2346 : 0 / 40 / 100   / 15000 / 21000 / 0   -> hpPct reads as 21000, rejected
--
--    This is the band's ONLY event-74 row, so the divergence is fully contained
--    -- but it is worth knowing the class exists: had the shifted value landed
--    under 100 it would have passed validation and been silently wrong.
-- ===========================================================================
UPDATE `smart_scripts`
SET `event_param1` = 0, `event_param2` = 0, `event_param3` = 15000,
    `event_param4` = 21000, `event_param5` = 40, `event_param6` = 0
WHERE `entryorguid` = 4102346 AND `source_type` = 0 AND `id` = 1 AND `event_type` = 74;

-- ===========================================================================
-- 4. "Table `command` contains data for non-existant command 'chat'"
--
--    5 rows naming commands this core does not register. Pre-existing DC data,
--    unrelated to map 751, but it is 5 lines of boot noise and the rows do
--    nothing -- a `command` row only supplies the security level and help text
--    for a command the core already has.
-- ===========================================================================
DELETE FROM `command` WHERE `name` IN ('chat', 'chat off', 'chat on', 'chata', 'chath');

-- ===========================================================================
-- NOT FIXED HERE, and why
--
-- * ~120 "uses non-existent Spell entry NNNNN" -- 120 distinct Cata spells
--   referenced by band SmartAI CAST/ADD_AURA actions. Checked against the live
--   Spell.dbc: of the 145 spell ids the band references above 60000, 25 exist and
--   120 do not. This is the single largest error class and needs the Cata spell
--   downport (Spell.dbc reassembly), not a DB change. It is also the cause of the
--   35 "Creature entry (N) has SmartAI enabled but no SmartAI entries" lines --
--   verified: ZERO band templates actually lack smart_scripts rows, so every one
--   of those is a template whose rows were all skipped for missing spells. Both
--   classes clear together when the spells land.
--
-- * "Event SMART_EVENT_DISTANCE_CREATURE using invalid creature entry 39038" and
--   the action-12/33 creature references (38980, 39002, 39038, 44175, 49337) --
--   five templates that exist in Cata but were never imported at all, in any
--   form. They have no spawn rows in Cata (they are script-summoned or
--   kill-credit NPCs), so the spawn-driven import never saw them. Handled
--   separately because each needs the full display chain (creature_template +
--   creature_template_model + creature_model_info) rather than a single row.
--   44175 "Spell Practice Credit" alone is blocking 6 quests.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------
SELECT 'waypoint points imported (want 214)' AS what, COUNT(*) AS n
FROM `waypoints` WHERE `entry` IN (4102435, 4105662, 4105697, 4106176, 4114739, 4136217,
    4139117, 4147405, 4150372, 4150414, 4161760, 4604140, 7991000, 7991001)
UNION ALL SELECT 'distinct paths imported (want 14)', COUNT(DISTINCT `entry`)
FROM `waypoints` WHERE `entry` IN (4102435, 4105662, 4105697, 4106176, 4114739, 4136217,
    4139117, 4147405, 4150372, 4150414, 4161760, 4604140, 7991000, 7991001)
UNION ALL SELECT 'action-53 rows pointing at an EXISTING path (want 14)', COUNT(*)
FROM `smart_scripts` s WHERE s.`action_type` = 53
  AND ((s.`entryorguid` BETWEEN 4100000 AND 4199999) OR (s.`entryorguid` BETWEEN 410000000 AND 419999999))
  AND EXISTS (SELECT 1 FROM `waypoints` w WHERE w.`entry` = s.`action_param2`)
UNION ALL SELECT 'escort-event rows remapped (want 15)', COUNT(*)
FROM `smart_scripts` WHERE `event_type` IN (40,55,56,57,58) AND `event_param2` > 4100000
  AND ((`entryorguid` BETWEEN 4100000 AND 4199999) OR (`entryorguid` BETWEEN 410000000 AND 419999999))
UNION ALL SELECT 'stock paths still intact (want 5)', COUNT(DISTINCT `entry`)
FROM `waypoints` WHERE `entry` IN (5662, 5697, 6176, 36217, 61760)
UNION ALL SELECT 'stock 6176 still 7 points, not 14 (want 7)', COUNT(*)
FROM `waypoints` WHERE `entry` = 6176
UNION ALL SELECT 'event-74 row now matches stock layout (want 1)', COUNT(*)
FROM `smart_scripts` WHERE `entryorguid` = 4102346 AND `id` = 1 AND `event_param5` = 40
UNION ALL SELECT 'bogus command rows left (want 0)', COUNT(*)
FROM `command` WHERE `name` IN ('chat', 'chat off', 'chat on', 'chata', 'chath');

-- must be empty: a band script still pointing at a path that does not exist
SELECT 'PROBLEM: escort path still missing' AS problem, s.`entryorguid`, s.`id`,
       s.`action_param2`, LEFT(s.`comment`, 50) AS cmt
FROM `smart_scripts` s
WHERE s.`action_type` = 53
  AND ((s.`entryorguid` BETWEEN 4100000 AND 4199999) OR (s.`entryorguid` BETWEEN 410000000 AND 419999999))
  AND s.`action_param2` > 0
  AND NOT EXISTS (SELECT 1 FROM `waypoints` w WHERE w.`entry` = s.`action_param2`);

-- must be empty: an escort EVENT left behind, still waiting on the old path id
-- while its creature now walks the remapped one
SELECT 'PROBLEM: escort event not remapped' AS problem, s.`entryorguid`, s.`id`,
       s.`event_type`, s.`event_param2`, LEFT(s.`comment`, 46) AS cmt
FROM `smart_scripts` s
WHERE s.`event_type` IN (40, 55, 56, 57, 58) AND s.`event_param2` > 0
  AND ((s.`entryorguid` BETWEEN 4100000 AND 4199999) OR (s.`entryorguid` BETWEEN 410000000 AND 419999999))
  AND NOT EXISTS (SELECT 1 FROM `waypoints` w WHERE w.`entry` = s.`event_param2`);

-- must be empty: an imported path whose point ids are not a clean run, which
-- would stall the creature partway along the route
SELECT 'PROBLEM: gap in imported path' AS problem, `entry`, COUNT(*) AS pts,
       MIN(`pointid`) AS lo, MAX(`pointid`) AS hi
FROM `waypoints` WHERE `entry` IN (4102435, 4105662, 4105697, 4106176, 4114739, 4136217,
    4139117, 4147405, 4150372, 4150414, 4161760, 4604140, 7991000, 7991001)
GROUP BY `entry` HAVING COUNT(*) <> MAX(`pointid`) - MIN(`pointid`) + 1;
