-- =====================================================================
-- Deepholm Downport  --  16  spell_script_names  (Cata map 646)
-- ---------------------------------------------------------------------
-- Target: acore_world.  Pairs with the C++ SpellScript in
--   src/server/scripts/DC/Deepholm/zone_deepholm.cpp  (needs the worldserver
--   built with that file -- already verified to compile + link).
--
-- The 3 creature AIs attach via creature_template.ScriptName (set by 15). A
-- SpellScript instead attaches via this table. Without this row the compiled
-- `spell_deepholm_twilight_buffet_targeting` script is registered but never runs.
--
-- DEPENDENCY: spell 95385 (Twilight Buffet Targeting) is a Cata-era spell absent
-- from 3.3.5 Spell.dbc. Until it is authored (CSV-DBC / extraction track), the
-- core logs a benign "spell script assigned to non-existent spell 95385" warning
-- at load and the script stays inert -- which is fine, because Xariona's
-- CastCustomSpell(95385, ...) also no-ops until the spell exists. Apply this row
-- together with authoring spell 95385.
-- =====================================================================

DELETE FROM `spell_script_names` WHERE `spell_id` = 95385 AND `ScriptName` = 'spell_deepholm_twilight_buffet_targeting';
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES (95385, 'spell_deepholm_twilight_buffet_targeting');
