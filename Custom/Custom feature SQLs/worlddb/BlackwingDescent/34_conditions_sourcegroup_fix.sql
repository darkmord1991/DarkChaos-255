-- ---------------------------------------------------------------------------
-- conditions.SourceGroup wrong effect-index bitmask (Nefarian's End Shadowflame Breath)
-- ---------------------------------------------------------------------------
-- More-db-errors audit pass (2026-07-13, ultracode workflow investigation):
-- "SourceEntry 77826/94124/94125/94126 in `condition` table, has incorrect
-- SourceGroup 4 (spell effectMask) set, ignoring" (ConditionMgr.cpp).
--
-- SourceGroup for SourceTypeOrReferenceId=13 (CONDITION_SOURCE_TYPE_SPELL_IMPLICIT_TARGET)
-- is a 1<<effIndex bitmask; ConditionMgr requires the referenced spell effect's
-- ImplicitTarget to classify as NEARBY/CONE/AREA/TRAJ (ConditionMgr.cpp ~1769-1800).
-- Verified directly against these 4 spells' spell_dbc rows + the SpellInfo.cpp
-- TargetA classification table (all 4 share identical effect/target layout):
--   effect index 0 (bit 1, Effect_1): target  6 TARGET_UNIT_TARGET_ENEMY   -> CATEGORY_DEFAULT (invalid)
--   effect index 1 (bit 2, Effect_2): target 104 TARGET_UNIT_CONE_ENEMY_104 -> CATEGORY_CONE   (valid)
--   effect index 2 (bit 4, Effect_3): target 110 TARGET_DEST_UNK_110       -> CATEGORY_NYI     (invalid)
-- SourceGroup=4 pointed at the invalid effect index 2; the intended index is 1
-- (SourceGroup=2), which is also the actual cone-breath damage effect these
-- "Target Animated Bone Warrior" conditions are meant to gate.
-- ---------------------------------------------------------------------------
UPDATE `conditions`
SET `SourceGroup` = 2
WHERE `SourceTypeOrReferenceId` = 13
  AND `SourceEntry` IN (77826,94124,94125,94126)
  AND `SourceGroup` = 4;
