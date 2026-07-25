-- =====================================================================
-- Molten Front -- 09  In-world polish fixes (from a live play test)
-- ---------------------------------------------------------------------
-- FIX 1 -- boot/runtime spam:
--   "SMART_ACTION_TALK: EntryOrGuid 3653190 SourceType 0 EventType 10
--    TargetType 7 using non-existent Text id 0 for talker 3652660, ignored."
-- The script owner is 3653190 "Northwestern Pool Credit" and it DOES have a
-- creature_text row (group 0, cloned from nelt_world). The TALK action used
-- target_type 7 (ACTION_INVOKER), so whatever tripped the OOC_LOS event became
-- the talker -- in-world that was a Fire Hawk (3652660), which has no text in
-- nelt_world, cata_world or acore_world. So the line could never play and the
-- core logged an error on every trigger.
-- Retargeting the TALK to target_type 1 (SELF) makes the owner speak its own
-- (existing) line, which is clearly the intent, and silences the error.
-- Guarded: only applied if the owner really has a group-0 text row.
--
-- FIX 2 (client side, already deployed -- recorded here for traceability):
-- Creature 3652825 "Theresa Barkskin" logged "has no model defined in
-- creature_template_model". The DB row from 07_ was fine (display 38052), but
-- display **38052 was missing from CreatureDisplayInfo** client-side -- it is in
-- a phase 02's curation excluded, so it was not in the 42-display batch. Added
-- (resolves to CHARACTER\WORGEN\FEMALE\WORGENFEMALE.M2, which already had a DC
-- CreatureModelData id, so no new model needed) and CreatureDisplayInfo.dbc was
-- recompiled into patch-4 + enGB/patch-enGB-3. Restart the worldserver so the
-- creature_template_model row from 07_ is reloaded.
--
-- Idempotent.
-- =====================================================================

UPDATE acore_world.smart_scripts ss
SET ss.target_type = 1
WHERE ss.entryorguid = 3653190 AND ss.source_type = 0 AND ss.id = 0
  AND ss.action_type = 1 AND ss.target_type = 7
  AND EXISTS (SELECT 1 FROM acore_world.creature_text ct
              WHERE ct.CreatureID = 3653190 AND ct.GroupID = ss.action_param1);
