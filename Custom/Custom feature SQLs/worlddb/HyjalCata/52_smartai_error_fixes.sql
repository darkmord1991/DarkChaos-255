-- =====================================================================
-- Mount Hyjal / Molten Front Downport  --  52  SmartAI validation error fixes
-- ---------------------------------------------------------------------
-- Cleans up SmartAIMgr::LoadFromDB warnings/errors surfaced by the batch
-- imported in 01/12/29/30/46/50/51. Root causes:
--   A) action_type 44 (SET_INGAME_PHASE_MASK) rows carry a vestigial
--      action_param2=1 from the source data; this action only reads
--      action_param1 (mask) and CheckUnusedActionParams() rejects any
--      nonzero param2.
--   B) Magronos the Unyielding (dc_entry 3608297) kept its pre-offset
--      smart_scripts entryorguid (8297) instead of the +3,600,000 id,
--      so SmartAIMgr never finds any script for the live creature.
--   C) Several rows reference sibling Hyjal/Molten Front creatures by
--      their pre-offset (raw cata_world) entry instead of the
--      +3,600,000 dc_entry that was actually used when those siblings
--      were imported (01_creature_templates.sql). Verified against the
--      live acore_world.creature_template rows before patching.
--   D) waypoints for Sira Moonwarden's (3652955) and Trained Fire
--      Hawk's (3653300) SMART_ACTION_ESCORT_START paths were never
--      copied over from nelt_world (these two are part of the
--      "neltharion" sub-batch, see 29/30/46); the path ids are
--      unchanged (no +3,600,000 offset is used for waypoints here).
-- =====================================================================

-- A) action_param2 vestige on SMART_ACTION_SET_INGAME_PHASE_MASK
UPDATE `smart_scripts` SET `action_param2` = 0
    WHERE `action_type` = 44 AND `action_param2` <> 0
    AND `entryorguid` IN (3647459, 3652955, 3652965, 3653300, 3675030) AND `source_type` = 0;

-- B) Magronos the Unyielding: smart_scripts still keyed on the pre-offset entry
UPDATE `smart_scripts` SET `entryorguid` = 3608297
    WHERE `entryorguid` = 8297 AND `source_type` = 0;

-- C) Sibling creature references missing the +3,600,000 offset
UPDATE `smart_scripts` SET `target_param1` = 3639438
    WHERE `entryorguid` = 3639436 AND `source_type` = 0 AND `id` = 1 AND `target_param1` = 39438;
UPDATE `smart_scripts` SET `target_param1` = 3639431
    WHERE `entryorguid` = 3639436 AND `source_type` = 0 AND `id` = 2 AND `target_param1` = 39431;
UPDATE `smart_scripts` SET `target_param2` = 3675182
    WHERE `entryorguid` = 3652683 AND `source_type` = 0 AND `id` = 0 AND `target_param2` = 75182;
UPDATE `smart_scripts` SET `action_param1` = 3653218
    WHERE `entryorguid` = 3652683 AND `source_type` = 0 AND `id` = 2 AND `action_param1` = 53218;
UPDATE `smart_scripts` SET `target_param1` = 3653329
    WHERE `entryorguid` = 3652683 AND `source_type` = 0 AND `id` = 3 AND `target_param1` = 53329;
UPDATE `smart_scripts` SET `action_param1` = 3652531
    WHERE `entryorguid` = 3653083 AND `source_type` = 0 AND `id` = 5 AND `action_param1` = 52531;
UPDATE `smart_scripts` SET `action_param1` = 3652683
    WHERE `entryorguid` = 3653355 AND `source_type` = 0 AND `id` = 2 AND `action_param1` = 52683;
UPDATE `smart_scripts` SET `action_param1` = 3653328
    WHERE `entryorguid` = 3653355 AND `source_type` = 0 AND `id` = 3 AND `action_param1` = 53328;
UPDATE `smart_scripts` SET `action_param1` = 3653328
    WHERE `entryorguid` = 3653355 AND `source_type` = 0 AND `id` = 4 AND `action_param1` = 53328;
UPDATE `smart_scripts` SET `target_param1` = 3653300
    WHERE `entryorguid` IN (3654252, 3654253, 3654254, 3654255, 3654256, 3654257)
    AND `source_type` = 0 AND `id` = 0 AND `target_param1` = 53300;
UPDATE `smart_scripts` SET `action_param1` = 3653355
    WHERE `entryorguid` = 3675181 AND `source_type` = 0 AND `id` = 0 AND `action_param1` = 53355;
UPDATE `smart_scripts` SET `action_param1` = 3652965
    WHERE `entryorguid` = 3675186 AND `source_type` = 0 AND `id` = 0 AND `action_param1` = 52965;
UPDATE `smart_scripts` SET `action_param1` = 3652955
    WHERE `entryorguid` = 3675186 AND `source_type` = 0 AND `id` = 1 AND `action_param1` = 52955;

-- D) Missing escort waypoints (cross-DB copy from nelt_world, unchanged ids)
DELETE FROM `waypoints` WHERE `entry` IN (53300, 5295500, 5330001);
INSERT INTO `waypoints` (`entry`, `pointid`, `position_x`, `position_y`, `position_z`, `point_comment`)
    SELECT `entry`, `pointid`, `position_x`, `position_y`, `position_z`, `point_comment`
    FROM `nelt_world`.`waypoints`
    WHERE `entry` IN (53300, 5295500, 5330001);
