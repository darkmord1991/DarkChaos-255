-- ==============================================================================
-- DIAGNOSTIC (temporary): hide every NEW wxl-baked Legion creature model on 1413 by
-- pointing its display to the stock Invisible Stalker (11686). This removes all 51
-- downported M2s from the render loop without touching the substituted/reused NPCs.
--
-- Apply, then walk the 1413 guildhouse:
--   * crash STOPS  -> the culprit is a wxl-baked M2 (Wraith render). I'll re-convert
--                     those 51 via the M2Mod full-3.3.5 path instead.
--   * crash REMAINS -> the new models are NOT the cause; it's a substitute/spawn/other.
--
-- REVERT: re-apply 2026_06_27_00_dc_legion_dalaran_1413_creature_template.sql
-- ==============================================================================

UPDATE `creature_template_model`
SET `CreatureDisplayID` = 11686
WHERE `CreatureID` BETWEEN 3500000 AND 3500999
  AND `CreatureDisplayID` BETWEEN 501200 AND 501260;
