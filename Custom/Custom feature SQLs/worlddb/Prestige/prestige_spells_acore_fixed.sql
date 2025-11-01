-- =====================================================================
-- DarkChaos-255 Prestige System - AzerothCore Spell Creation (FIXED)
-- =====================================================================
-- Creates custom spells for prestige bonuses
-- Uses AzerothCore's spell_dbc table with correct column structure
-- =====================================================================

-- =====================================================================
-- PART 1: Prestige Bonus Spells (Custom Auras) 
-- =====================================================================
-- These spells provide permanent stat bonuses based on prestige level
-- Each spell grants 1-10% bonus to all stats (stacking)
-- Aura Type: 137 = SPELL_AURA_MOD_STAT (all stats)
-- Effect: 6 = SPELL_EFFECT_APPLY_AURA
-- =====================================================================

-- Delete old entries if they exist
DELETE FROM `spell_dbc` WHERE `ID` BETWEEN 800010 AND 800019;

-- Prestige Level 1: 1% All Stats (spell 800010)
INSERT INTO `spell_dbc` (`ID`, `Effect_1`, `EffectBasePoints_1`, `EffectAura_1`, `ImplicitTargetA_1`, `Name_Lang_enUS`, `SchoolMask`, `DurationIndex`)
VALUES (800010, 6, 0, 137, 1, 'Prestige 1 - Enhanced Stats', 1, 0);

-- Prestige Level 2: 2% All Stats (spell 800011)
INSERT INTO `spell_dbc` (`ID`, `Effect_1`, `EffectBasePoints_1`, `EffectAura_1`, `ImplicitTargetA_1`, `Name_Lang_enUS`, `SchoolMask`, `DurationIndex`)
VALUES (800011, 6, 1, 137, 1, 'Prestige 2 - Enhanced Stats', 1, 0);

-- Prestige Level 3: 3% All Stats (spell 800012)
INSERT INTO `spell_dbc` (`ID`, `Effect_1`, `EffectBasePoints_1`, `EffectAura_1`, `ImplicitTargetA_1`, `Name_Lang_enUS`, `SchoolMask`, `DurationIndex`)
VALUES (800012, 6, 2, 137, 1, 'Prestige 3 - Enhanced Stats', 1, 0);

-- Prestige Level 4: 4% All Stats (spell 800013)
INSERT INTO `spell_dbc` (`ID`, `Effect_1`, `EffectBasePoints_1`, `EffectAura_1`, `ImplicitTargetA_1`, `Name_Lang_enUS`, `SchoolMask`, `DurationIndex`)
VALUES (800013, 6, 3, 137, 1, 'Prestige 4 - Enhanced Stats', 1, 0);

-- Prestige Level 5: 5% All Stats (spell 800014)
INSERT INTO `spell_dbc` (`ID`, `Effect_1`, `EffectBasePoints_1`, `EffectAura_1`, `ImplicitTargetA_1`, `Name_Lang_enUS`, `SchoolMask`, `DurationIndex`)
VALUES (800014, 6, 4, 137, 1, 'Prestige 5 - Enhanced Stats', 1, 0);

-- Prestige Level 6: 6% All Stats (spell 800015)
INSERT INTO `spell_dbc` (`ID`, `Effect_1`, `EffectBasePoints_1`, `EffectAura_1`, `ImplicitTargetA_1`, `Name_Lang_enUS`, `SchoolMask`, `DurationIndex`)
VALUES (800015, 6, 5, 137, 1, 'Prestige 6 - Enhanced Stats', 1, 0);

-- Prestige Level 7: 7% All Stats (spell 800016)
INSERT INTO `spell_dbc` (`ID`, `Effect_1`, `EffectBasePoints_1`, `EffectAura_1`, `ImplicitTargetA_1`, `Name_Lang_enUS`, `SchoolMask`, `DurationIndex`)
VALUES (800016, 6, 6, 137, 1, 'Prestige 7 - Enhanced Stats', 1, 0);

-- Prestige Level 8: 8% All Stats (spell 800017)
INSERT INTO `spell_dbc` (`ID`, `Effect_1`, `EffectBasePoints_1`, `EffectAura_1`, `ImplicitTargetA_1`, `Name_Lang_enUS`, `SchoolMask`, `DurationIndex`)
VALUES (800017, 6, 7, 137, 1, 'Prestige 8 - Enhanced Stats', 1, 0);

-- Prestige Level 9: 9% All Stats (spell 800018)
INSERT INTO `spell_dbc` (`ID`, `Effect_1`, `EffectBasePoints_1`, `EffectAura_1`, `ImplicitTargetA_1`, `Name_Lang_enUS`, `SchoolMask`, `DurationIndex`)
VALUES (800018, 6, 8, 137, 1, 'Prestige 9 - Enhanced Stats', 1, 0);

-- Prestige Level 10: 10% All Stats (spell 800019)
INSERT INTO `spell_dbc` (`ID`, `Effect_1`, `EffectBasePoints_1`, `EffectAura_1`, `ImplicitTargetA_1`, `Name_Lang_enUS`, `SchoolMask`, `DurationIndex`)
VALUES (800019, 6, 9, 137, 1, 'Prestige 10 - Enhanced Stats', 1, 0);

-- =====================================================================
-- Column Reference (AzerothCore spell_dbc):
-- ID = Spell ID (800010-800019)
-- Effect_1 = Effect Type 6 (SPELL_EFFECT_APPLY_AURA)
-- EffectBasePoints_1 = Base Points (0-9 = 1-10% stat bonus per prestige level)
-- EffectAura_1 = Aura Type 137 (SPELL_AURA_MOD_STAT - all stats)
-- ImplicitTargetA_1 = Target Type 1 (TARGET_UNIT_CASTER - self)
-- Name_Lang_enUS = Spell name displayed in client
-- SchoolMask = School of Magic (1 = Physical)
-- DurationIndex = Duration Type (0 = Permanent, no duration)
-- =====================================================================
-- End of prestige spells (AzerothCore spell_dbc compatible)
-- =====================================================================
