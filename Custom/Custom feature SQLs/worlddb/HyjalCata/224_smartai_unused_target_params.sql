-- ---------------------------------------------------------------------------
-- 224  The last "unused target_param1" rows SmartAIMgr throws away
-- ---------------------------------------------------------------------------
-- Same defect class 199_ cleared for SMART_TARGET_VICTIM, one target type it
-- did not cover.  These are not warnings: CheckUnusedTargetParams sets
-- valid = false, so the WHOLE ROW is dropped and the behaviour does not exist
-- in game.
--
--   Entry 3644444 id 1   "Cast Dark Plague on Death"
--   Entry 3645156 id 1   "Cast Acid Cloud on Death"
--   Entry 3645444 id 0   "Cast Blight Bomb on Death"
--   + 2 more on imported entries that have no spawn yet
--
-- All five are on-death casts with target_type 0 and a stray target_param1 = 1.
-- SmartScriptMgr.h:930 lists SMART_TARGET_NONE as NO_PARAMS, so any non-zero
-- target param kills the row.  The 1 is import noise -- it carries no meaning
-- for a target type that reads no params -- so zeroing it restores the cast
-- without changing what the row does.
--
-- WRITTEN FOR ALL THREE NO_PARAMS TARGET TYPES, not just the one that is
-- currently dirty: NONE (0), SELF (1) and VICTIM (2) are all NO_PARAMS at
-- SmartScriptMgr.h:930-932.  Types 1 and 2 are clean in the band right now
-- (199_ fixed 2 for map 750), so those branches are no-ops today and stay
-- correct if a later import reintroduces the pattern.
--
-- Scope is the clone band 3600000-3999999, matching 222_ and for the same
-- reason -- it is 2 rows wider than "spawned on map 750/751" because two of
-- the entries have no spawn yet, and they carry the identical defect.
-- No stock row is in range.  Safe to re-run.
-- ---------------------------------------------------------------------------

UPDATE `smart_scripts`
SET `target_param1` = 0, `target_param2` = 0, `target_param3` = 0
WHERE `source_type` = 0
  AND `target_type` IN (0, 1, 2)
  AND `entryorguid` BETWEEN 3600000 AND 3999999
  AND (`target_param1` <> 0 OR `target_param2` <> 0 OR `target_param3` <> 0);

-- Verify -- must return 0, and the boot log must lose its remaining
-- "uses unused target_param1 with value 1, it must be 0" lines:
--   SELECT COUNT(*) FROM `smart_scripts`
--    WHERE source_type = 0 AND target_type IN (0,1,2)
--      AND entryorguid BETWEEN 3600000 AND 3999999
--      AND (target_param1 <> 0 OR target_param2 <> 0 OR target_param3 <> 0);
