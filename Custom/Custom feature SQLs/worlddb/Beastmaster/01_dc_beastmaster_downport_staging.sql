-- ============================================================================
-- DC Beastmaster - proof-batch CLEANUP (was: retail model downport staging)
-- ============================================================================
-- The original 4-model "proof" downport (990001 Stormfang / 990002 Emberfang /
-- 990003 Duskwing / 990004 Ironhorn) reused CreatureModelData ids 502610/502611/
-- 502612/502617 -- which turned out to already belong to earlier DC downports
-- (hordescorpion / firespider / celestialserpent / mistfox), a collision that
-- rendered those and the proof pets wrong. The proof batch was throwaway and is
-- superseded by the real secret-tame wiring (02/03), so it is removed here and
-- the colliding CreatureModelData/DisplayInfo rows were stripped from
-- Custom/CSV DBC (recompile + redeploy the DBCs). Drop patch-beasts-test.MPQ too.
--
-- Safe/idempotent: only deletes the four proof entries and their rows.
-- ============================================================================

DELETE FROM `dc_beastmaster_pets`      WHERE `creature_id` IN (990001, 990002, 990003, 990004);
DELETE FROM `creature_template_model`  WHERE `CreatureID`  IN (990001, 990002, 990003, 990004);
DELETE FROM `creature_model_info`      WHERE `DisplayID`   IN (503400, 503401, 503402, 503403);
DELETE FROM `creature_template`        WHERE `entry`       IN (990001, 990002, 990003, 990004);
