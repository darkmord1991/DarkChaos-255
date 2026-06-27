-- =====================================================================
-- Deepholm Downport  --  25  spell_dbc range fix (server boot crash)
-- ---------------------------------------------------------------------
-- The Cata 4.3.4 client uses spell effect ids beyond 3.3.5's range. Spell
-- 93425 "Update Zone Auras" has Effect_1 = 170, but this fork's
-- TOTAL_SPELL_EFFECTS = 165 (valid 0..164) -> LoadSpellInfoStore ASSERT/segfault:
--   "Condition: spellEffectInfo.Effect < TOTAL_SPELL_EFFECTS"
-- 93425 is a server-side zone-phasing helper with no 3.3.5 equivalent; neutralize
-- the out-of-range effect (spell still loads; the effect is a no-op).
-- (Audit: of the 35 imported Deepholm spells, 93425 is the ONLY one out of range;
--  max effect after this = <165, max aura = 236, max mechanic = 0 -- all valid.)
-- =====================================================================

UPDATE `spell_dbc` SET `Effect_1` = 0 WHERE `ID` = 93425 AND `Effect_1` >= 165;
