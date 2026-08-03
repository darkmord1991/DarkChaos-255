-- ---------------------------------------------------------------------------
-- 199  Hyjal round-45 -- rows SmartAIMgr REJECTS at load, so they never run
-- ---------------------------------------------------------------------------
-- These do not merely log a warning: SmartAIMgr sets valid = false and SKIPS
-- THE WHOLE ROW.  The behaviour silently does not exist in game, which is why
-- they are worth fixing rather than filtering out of the log.
--
-- The core validates by UNION SIZE: CheckUnusedEventParams / -TargetParams take
-- the byte size of the param struct for that event/target type and require
-- every dword BEYOND it to be zero.  So "unused" is defined per type:
--
--   SMART_EVENT_LINK (61)            -> NO_PARAMS: all four must be 0.
--        The imports converted an event into a link but left the ORIGINAL
--        event's numbers behind ("Between 0-30% Health" keeps 0/30/0/0).
--   SMART_EVENT_VICTIM_CASTING (13)  -> RepeatMin, RepeatMax, spellid: only
--        params 1-3 are used, so a leftover param4 kills the row.
--   SMART_TARGET_VICTIM (2)          -> "our current target", takes no params,
--        so a leftover target_param1 kills the row.
--
-- SCOPE IS EXACTLY 13 ROWS, and that number is verified twice: it matches the
-- 21 log lines the worldserver emitted (several rows trip more than one param),
-- and a rule-based sweep of map 750 finds the same 7 + 2 + 4.  An earlier count
-- of "108 + 47 + 14" was wrong -- that query joined smart_scripts to `creature`,
-- which multiplies every script row by its SPAWN COUNT.  Script rows are keyed
-- by entry, not by spawn; never join them to `creature` to count.
--
-- Checked and clean: source_type 9 (action lists) and source_type 1
-- (gameobjects) have ZERO rows in any of these three classes.
--
-- The UPDATEs are written as the validation rule itself rather than as a list
-- of ids, so they stay correct if another import reintroduces the pattern.
-- ---------------------------------------------------------------------------

-- --- 1. LINK events must carry no params (7 rows) --------------------------
UPDATE `smart_scripts` SET `event_param1` = 0, `event_param2` = 0, `event_param3` = 0, `event_param4` = 0
WHERE `source_type` = 0 AND `event_type` = 61
  AND (`event_param1` <> 0 OR `event_param2` <> 0 OR `event_param3` <> 0 OR `event_param4` <> 0)
  AND `entryorguid` IN (SELECT `id` FROM (SELECT DISTINCT `id` FROM `creature` WHERE `map` = 750) x);

-- --- 2. VICTIM_CASTING uses params 1-3 only (2 rows) -----------------------
UPDATE `smart_scripts` SET `event_param4` = 0
WHERE `source_type` = 0 AND `event_type` = 13 AND `event_param4` <> 0
  AND `entryorguid` IN (SELECT `id` FROM (SELECT DISTINCT `id` FROM `creature` WHERE `map` = 750) x);

-- --- 3. TARGET_VICTIM takes no params (4 rows) -----------------------------
UPDATE `smart_scripts` SET `target_param1` = 0
WHERE `source_type` = 0 AND `target_type` = 2 AND `target_param1` <> 0
  AND `entryorguid` IN (SELECT `id` FROM (SELECT DISTINCT `id` FROM `creature` WHERE `map` = 750) x);

-- --- 4. the one dead SPELLHIT trigger --------------------------------------
-- Blazebound Elemental (3638896, 20 spawns) has "On spell 74723 hit -> Die".
-- 74723 is a Cataclysm spell absent from our Spell.dbc, AND NOTHING ON MAP 750
-- CASTS IT (verified: zero cast actions reference it anywhere).  So the event
-- can never fire no matter what -- minting the spell would not make it work,
-- it would only silence the log.  The row is provably dead weight; removing it
-- also removes a permanent false positive from every future boot.
-- The elemental's other row (In Combat -> cast 80031) is unaffected and works.
DELETE FROM `smart_scripts`
WHERE `source_type` = 0 AND `entryorguid` = 3638896 AND `id` = 1
  AND `event_type` = 8 AND `event_param1` = 74723;

-- Verify -- all four should read 0, and the boot log should lose its
-- "has unused ..., skipped" lines entirely:
--   SELECT COUNT(*) FROM `smart_scripts` WHERE source_type=0 AND event_type=61
--     AND (event_param1<>0 OR event_param2<>0 OR event_param3<>0 OR event_param4<>0)
--     AND entryorguid IN (SELECT DISTINCT id FROM `creature` WHERE map=750);
--   SELECT COUNT(*) FROM `smart_scripts` WHERE source_type=0 AND event_type=13 AND event_param4<>0
--     AND entryorguid IN (SELECT DISTINCT id FROM `creature` WHERE map=750);
--   SELECT COUNT(*) FROM `smart_scripts` WHERE source_type=0 AND target_type=2 AND target_param1<>0
--     AND entryorguid IN (SELECT DISTINCT id FROM `creature` WHERE map=750);
--   SELECT COUNT(*) FROM `smart_scripts` WHERE source_type=0 AND event_type=8 AND event_param1=74723;
