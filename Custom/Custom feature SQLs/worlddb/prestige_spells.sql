-- =====================================================================
-- DarkChaos-255 Prestige System - World Database Spells and Titles
-- =====================================================================
-- Creates custom spells for prestige bonuses and title definitions
-- =====================================================================

-- =====================================================================
-- PART 1: Prestige Bonus Spells (Custom Auras)
-- =====================================================================
-- These spells provide permanent stat bonuses based on prestige level
-- Each spell grants 1-10% bonus to all stats (stacking)
-- =====================================================================

DELETE FROM `spell_template` WHERE `Id` BETWEEN 800010 AND 800019;
INSERT INTO `spell_template` (`Id`, `Difficulty`, `Category`, `Dispel`, `Mechanic`, `Attributes`, `AttributesEx`, `AttributesEx2`, `AttributesEx3`, `AttributesEx4`, `AttributesEx5`, `AttributesEx6`, `AttributesEx7`, `Stances`, `StancesNot`, `Targets`, `TargetCreatureType`, `RequiresSpellFocus`, `FacingCasterFlags`, `CasterAuraState`, `TargetAuraState`, `ExcludeCasterAuraState`, `ExcludeTargetAuraState`, `CasterAuraSpell`, `TargetAuraSpell`, `ExcludeCasterAuraSpell`, `ExcludeTargetAuraSpell`, `CastingTimeIndex`, `RecoveryTime`, `CategoryRecoveryTime`, `InterruptFlags`, `AuraInterruptFlags`, `ChannelInterruptFlags`, `ProcFlags`, `ProcChance`, `ProcCharges`, `MaxLevel`, `BaseLevel`, `SpellLevel`, `DurationIndex`, `RangeIndex`, `StackAmount`, `EquippedItemClass`, `EquippedItemSubClassMask`, `EquippedItemInventoryTypeMask`, `Effect1`, `Effect2`, `Effect3`, `EffectDieSides1`, `EffectDieSides2`, `EffectDieSides3`, `EffectRealPointsPerLevel1`, `EffectRealPointsPerLevel2`, `EffectRealPointsPerLevel3`, `EffectBasePoints1`, `EffectBasePoints2`, `EffectBasePoints3`, `EffectMechanic1`, `EffectMechanic2`, `EffectMechanic3`, `EffectImplicitTargetA1`, `EffectImplicitTargetA2`, `EffectImplicitTargetA3`, `EffectImplicitTargetB1`, `EffectImplicitTargetB2`, `EffectImplicitTargetB3`, `EffectRadiusIndex1`, `EffectRadiusIndex2`, `EffectRadiusIndex3`, `EffectApplyAuraName1`, `EffectApplyAuraName2`, `EffectApplyAuraName3`, `EffectAmplitude1`, `EffectAmplitude2`, `EffectAmplitude3`, `EffectMultipleValue1`, `EffectMultipleValue2`, `EffectMultipleValue3`, `EffectMiscValue1`, `EffectMiscValue2`, `EffectMiscValue3`, `EffectMiscValueB1`, `EffectMiscValueB2`, `EffectMiscValueB3`, `EffectTriggerSpell1`, `EffectTriggerSpell2`, `EffectTriggerSpell3`, `EffectSpellClassMaskA1`, `EffectSpellClassMaskA2`, `EffectSpellClassMaskA3`, `EffectSpellClassMaskB1`, `EffectSpellClassMaskB2`, `EffectSpellClassMaskB3`, `EffectSpellClassMaskC1`, `EffectSpellClassMaskC2`, `EffectSpellClassMaskC3`, `MaxTargetLevel`, `SpellFamilyName`, `SpellFamilyFlags1`, `SpellFamilyFlags2`, `SpellFamilyFlags3`, `MaxAffectedTargets`, `DmgClass`, `PreventionType`, `DmgMultiplier1`, `DmgMultiplier2`, `DmgMultiplier3`, `AreaGroupId`, `SchoolMask`, `Comment`) VALUES
-- Prestige Level 1: 1% All Stats
(800010, 0, 0, 0, 0, 0x10000000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 101, 0, 0, 1, 1, 21, 1, 0, -1, 0, 0, 6, 6, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 137, 137, 137, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1, 'Prestige I Bonus - 1% All Stats'),

-- Prestige Level 2: 2% All Stats
(800011, 0, 0, 0, 0, 0x10000000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 101, 0, 0, 1, 1, 21, 1, 0, -1, 0, 0, 6, 6, 6, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 137, 137, 137, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1, 'Prestige II Bonus - 2% All Stats'),

-- Prestige Level 3: 3% All Stats
(800012, 0, 0, 0, 0, 0x10000000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 101, 0, 0, 1, 1, 21, 1, 0, -1, 0, 0, 6, 6, 6, 0, 0, 0, 0, 0, 0, 2, 2, 2, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 137, 137, 137, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1, 'Prestige III Bonus - 3% All Stats'),

-- Prestige Level 4: 4% All Stats
(800013, 0, 0, 0, 0, 0x10000000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 101, 0, 0, 1, 1, 21, 1, 0, -1, 0, 0, 6, 6, 6, 0, 0, 0, 0, 0, 0, 3, 3, 3, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 137, 137, 137, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1, 'Prestige IV Bonus - 4% All Stats'),

-- Prestige Level 5: 5% All Stats
(800014, 0, 0, 0, 0, 0x10000000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 101, 0, 0, 1, 1, 21, 1, 0, -1, 0, 0, 6, 6, 6, 0, 0, 0, 0, 0, 0, 4, 4, 4, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 137, 137, 137, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1, 'Prestige V Bonus - 5% All Stats'),

-- Prestige Level 6: 6% All Stats
(800015, 0, 0, 0, 0, 0x10000000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 101, 0, 0, 1, 1, 21, 1, 0, -1, 0, 0, 6, 6, 6, 0, 0, 0, 0, 0, 0, 5, 5, 5, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 137, 137, 137, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1, 'Prestige VI Bonus - 6% All Stats'),

-- Prestige Level 7: 7% All Stats
(800016, 0, 0, 0, 0, 0x10000000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 101, 0, 0, 1, 1, 21, 1, 0, -1, 0, 0, 6, 6, 6, 0, 0, 0, 0, 0, 0, 6, 6, 6, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 137, 137, 137, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1, 'Prestige VII Bonus - 7% All Stats'),

-- Prestige Level 8: 8% All Stats
(800017, 0, 0, 0, 0, 0x10000000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 101, 0, 0, 1, 1, 21, 1, 0, -1, 0, 0, 6, 6, 6, 0, 0, 0, 0, 0, 0, 7, 7, 7, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 137, 137, 137, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1, 'Prestige VIII Bonus - 8% All Stats'),

-- Prestige Level 9: 9% All Stats
(800018, 0, 0, 0, 0, 0x10000000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 101, 0, 0, 1, 1, 21, 1, 0, -1, 0, 0, 6, 6, 6, 0, 0, 0, 0, 0, 0, 8, 8, 8, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 137, 137, 137, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1, 'Prestige IX Bonus - 9% All Stats'),

-- Prestige Level 10: 10% All Stats
(800019, 0, 0, 0, 0, 0x10000000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 101, 0, 0, 1, 1, 21, 1, 0, -1, 0, 0, 6, 6, 6, 0, 0, 0, 0, 0, 0, 9, 9, 9, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 137, 137, 137, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1, 'Prestige X Bonus - 10% All Stats');

-- =====================================================================
-- PART 2: Prestige Title Rewards (Optional - requires DBC editing)
-- =====================================================================
-- NOTE: Titles in WoW 3.3.5a are stored in CharTitles.dbc
-- This section provides reference data for custom title creation
-- You must use a DBC editor to add these titles to CharTitles.dbc
-- =====================================================================

-- Reference Title IDs (add to CharTitles.dbc):
-- ID 300: "Prestige I %s"
-- ID 301: "Prestige II %s"
-- ID 302: "Prestige III %s"
-- ID 303: "Prestige IV %s"
-- ID 304: "Prestige V %s"
-- ID 305: "Prestige VI %s"
-- ID 306: "Prestige VII %s"
-- ID 307: "Prestige VIII %s"
-- ID 308: "Prestige IX %s"
-- ID 309: "Prestige X %s"

-- Alternative: Use existing title IDs if you prefer not to edit DBC
-- Example: Use titles from achievement system or PvP ranks

-- =====================================================================
-- PART 3: Optional Prestige Achievements (requires achievement_dbc.sql)
-- =====================================================================
-- These achievements can be created to track prestige milestones
-- =====================================================================

-- DELETE FROM `achievement_dbc` WHERE `ID` BETWEEN 10000 AND 10010;
-- INSERT INTO `achievement_dbc` (`ID`, `faction`, `mapID`, `previous`, `name_lang_1`, `description_lang_1`, `category`, `points`, `orderInGroup`, `flags`, `iconID`, `rewardTitle_lang_1`, `minCriteria`) VALUES
-- (10000, -1, -1, 0, 'Prestige I', 'Reach Prestige Level 1', 1, 10, 0, 0, 1506, '', 1),
-- (10001, -1, -1, 10000, 'Prestige II', 'Reach Prestige Level 2', 1, 10, 1, 0, 1506, '', 1),
-- (10002, -1, -1, 10001, 'Prestige III', 'Reach Prestige Level 3', 1, 10, 2, 0, 1506, '', 1),
-- (10003, -1, -1, 10002, 'Prestige IV', 'Reach Prestige Level 4', 1, 10, 3, 0, 1506, '', 1),
-- (10004, -1, -1, 10003, 'Prestige V', 'Reach Prestige Level 5', 1, 10, 4, 0, 1506, '', 1),
-- (10005, -1, -1, 10004, 'Prestige VI', 'Reach Prestige Level 6', 1, 10, 5, 0, 1506, '', 1),
-- (10006, -1, -1, 10005, 'Prestige VII', 'Reach Prestige Level 7', 1, 10, 6, 0, 1506, '', 1),
-- (10007, -1, -1, 10006, 'Prestige VIII', 'Reach Prestige Level 8', 1, 10, 7, 0, 1506, '', 1),
-- (10008, -1, -1, 10007, 'Prestige IX', 'Reach Prestige Level 9', 1, 10, 8, 0, 1506, '', 1),
-- (10009, -1, -1, 10008, 'Prestige X', 'Reach Prestige Level 10', 1, 25, 9, 0, 1506, '', 1);

-- =====================================================================
-- End of prestige spells and titles
-- =====================================================================
