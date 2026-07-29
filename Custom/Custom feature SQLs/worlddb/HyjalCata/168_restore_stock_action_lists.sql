-- ---------------------------------------------------------------------------
-- 168  Hyjal round-36 -- restore the stock action lists 166_ destroyed
-- ---------------------------------------------------------------------------
-- COLLATERAL DAMAGE, not a Hyjal bug.  An earlier revision of 166_ opened its
-- SmartAI block with
--
--     DELETE FROM `smart_scripts`
--     WHERE `source_type` IN (0,9) AND `entryorguid` BETWEEN 3700000 AND 3799999;
--
-- on the assumption that nothing but the border-zone clones lived there.  That
-- was wrong.  AzerothCore numbers timed action lists `creature_entry * 100`, so
-- stock creature entries 37000-37999 own exactly that band -- and 37000-37999
-- is Icecrown Citadel.  The DELETE removed 148 rows across 10 action lists:
--
--     3712000 / 3712001   Highlord Darion Mograine  (37120)
--                         "On Data Set - Run Script" and the
--                         'Mograine's Reunion' quest-completion scene
--     3769600             Crusader Halford          (37696)
--     3780100             Shadow's Edge Bunny       (37801)  -- Shadowmourne
--     3784600 / 3784601   Blood-Queen Lana'thel     (37846)  -- both intro
--                                                              waypoint scenes
--     3785700             The Lich King             (37857)  -- reached WP11
--     3789300             Vegard the Unforgiven     (37893)
--     3795200 / 3795201   Light's Vengeance Vehicle Bunny 2 (37952)
--
-- The 10 calling `smart_scripts` rows (action_type 80) survived, so the symptom
-- is silent: those scripts fire SMART_ACTION_CALL_TIMED_ACTIONLIST at a list
-- with no rows and simply do nothing.  Lana'thel's and the Lich King's intro
-- sequences and the Shadowmourne quest scene stall rather than error.
--
-- WHY acore_backup AND NOT data/sql/base
--   `data/sql/base/db_world/smart_scripts.sql` has all ten, but it is the
--   upstream baseline -- anything a later `data/sql/updates/db_world/` revision
--   changed would be restored stale.  acore_backup is a copy of THIS world DB
--   with the updates already applied, and it holds precisely 148 rows across
--   precisely 10 entryorguids in the band: an exact match for what was lost.
--   cata_world has 9 of the 10 (no Crusader Halford) and is a different core's
--   data, so it is the worse source on both counts.
--
-- 166_ no longer touches this band at all -- cloned action lists moved to
-- raw_list + 370,000,000, and the DELETE there now names the exact ids it is
-- about to write instead of guessing a range.  This file therefore runs once
-- and stays inert; it is still idempotent, keyed on the 10 list ids so a re-run
-- cannot touch anything else.
--
-- Verify afterwards -- expect 0 rows:
--   SELECT DISTINCT s.`action_param1` FROM `smart_scripts` s
--   WHERE s.`action_type` = 80 AND s.`action_param1` BETWEEN 3700000 AND 3799999
--     AND NOT EXISTS (SELECT 1 FROM `smart_scripts` a
--                     WHERE a.`source_type` = 9 AND a.`entryorguid` = s.`action_param1`);
-- ---------------------------------------------------------------------------

DELETE FROM `smart_scripts`
WHERE `source_type` = 9
  AND `entryorguid` IN (3712000, 3712001, 3769600, 3780100, 3784600,
                        3784601, 3785700, 3789300, 3795200, 3795201);

INSERT INTO `smart_scripts`
  (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`,
   `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`,
   `event_param4`, `event_param5`, `event_param6`, `action_type`, `action_param1`,
   `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`,
   `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`,
   `target_x`, `target_y`, `target_z`, `target_o`, `comment`)
SELECT `entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`,
       `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`,
       `event_param4`, `event_param5`, `event_param6`, `action_type`, `action_param1`,
       `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`,
       `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`,
       `target_x`, `target_y`, `target_z`, `target_o`, `comment`
FROM acore_backup.`smart_scripts`
WHERE `source_type` = 9
  AND `entryorguid` IN (3712000, 3712001, 3769600, 3780100, 3784600,
                        3784601, 3785700, 3789300, 3795200, 3795201);
