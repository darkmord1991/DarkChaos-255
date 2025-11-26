-- =====================================================================
-- DarkChaos Hotspot XP Buff - Spell 800001
-- =====================================================================
-- CRITICAL: This spell MUST match the client Spell.dbc entry exactly!
-- 
-- Key attributes for VISIBLE buff in aura bar:
--   Attributes = 0x10 (SPELL_ATTR0_IS_ABILITY) - Allows display in buff bar
--   NO 0x80 (SPELL_ATTR0_DO_NOT_DISPLAY) - Would hide from UI
--   AttributesEx = 0 - NO 0x10000000 (SPELL_ATTR1_NO_AURA_ICON) which hides from aura bar
--   Effect_1 = 6 (SPELL_EFFECT_APPLY_AURA)
--   EffectAura_1 = 4 (SPELL_AURA_DUMMY) - MUST be 4, not 3!
--   ImplicitTargetA_1 = 21 (TARGET_UNIT_CASTER - self)
--   DurationIndex = 21 (permanent)
--   EquippedItemClass = -1 (no item requirement)
-- =====================================================================

DELETE FROM `spell_dbc` WHERE `ID`=800001;
INSERT INTO `spell_dbc` 
(`ID`, `Category`, `DispelType`, `Mechanic`, 
 `Attributes`, `AttributesEx`, `AttributesEx2`, `AttributesEx3`, `AttributesEx4`, `AttributesEx5`, `AttributesEx6`, `AttributesEx7`,
 `ShapeshiftMask`, `unk_320_2`, `ShapeshiftExclude`, `unk_320_3`,
 `Targets`, `TargetCreatureType`, `RequiresSpellFocus`, `FacingCasterFlags`,
 `CasterAuraState`, `TargetAuraState`, `ExcludeCasterAuraState`, `ExcludeTargetAuraState`,
 `CasterAuraSpell`, `TargetAuraSpell`, `ExcludeCasterAuraSpell`, `ExcludeTargetAuraSpell`,
 `CastingTimeIndex`, `RecoveryTime`, `CategoryRecoveryTime`,
 `InterruptFlags`, `AuraInterruptFlags`, `ChannelInterruptFlags`,
 `ProcTypeMask`, `ProcChance`, `ProcCharges`,
 `MaxLevel`, `BaseLevel`, `SpellLevel`, `DurationIndex`,
 `PowerType`, `ManaCost`, `ManaCostPerLevel`, `ManaPerSecond`, `ManaPerSecondPerLevel`,
 `RangeIndex`, `Speed`, `ModalNextSpell`, `CumulativeAura`,
 `Totem_1`, `Totem_2`,
 `Reagent_1`, `Reagent_2`, `Reagent_3`, `Reagent_4`, `Reagent_5`, `Reagent_6`, `Reagent_7`, `Reagent_8`,
 `ReagentCount_1`, `ReagentCount_2`, `ReagentCount_3`, `ReagentCount_4`, `ReagentCount_5`, `ReagentCount_6`, `ReagentCount_7`, `ReagentCount_8`,
 `EquippedItemClass`, `EquippedItemSubclass`, `EquippedItemInvTypes`,
 `Effect_1`, `Effect_2`, `Effect_3`,
 `EffectDieSides_1`, `EffectDieSides_2`, `EffectDieSides_3`,
 `EffectRealPointsPerLevel_1`, `EffectRealPointsPerLevel_2`, `EffectRealPointsPerLevel_3`,
 `EffectBasePoints_1`, `EffectBasePoints_2`, `EffectBasePoints_3`,
 `EffectMechanic_1`, `EffectMechanic_2`, `EffectMechanic_3`,
 `ImplicitTargetA_1`, `ImplicitTargetA_2`, `ImplicitTargetA_3`,
 `ImplicitTargetB_1`, `ImplicitTargetB_2`, `ImplicitTargetB_3`,
 `EffectRadiusIndex_1`, `EffectRadiusIndex_2`, `EffectRadiusIndex_3`,
 `EffectAura_1`, `EffectAura_2`, `EffectAura_3`,
 `EffectAuraPeriod_1`, `EffectAuraPeriod_2`, `EffectAuraPeriod_3`,
 `EffectMultipleValue_1`, `EffectMultipleValue_2`, `EffectMultipleValue_3`,
 `EffectChainTargets_1`, `EffectChainTargets_2`, `EffectChainTargets_3`,
 `EffectItemType_1`, `EffectItemType_2`, `EffectItemType_3`,
 `EffectMiscValue_1`, `EffectMiscValue_2`, `EffectMiscValue_3`,
 `EffectMiscValueB_1`, `EffectMiscValueB_2`, `EffectMiscValueB_3`,
 `EffectTriggerSpell_1`, `EffectTriggerSpell_2`, `EffectTriggerSpell_3`,
 `EffectPointsPerCombo_1`, `EffectPointsPerCombo_2`, `EffectPointsPerCombo_3`,
 `EffectSpellClassMaskA_1`, `EffectSpellClassMaskA_2`, `EffectSpellClassMaskA_3`,
 `EffectSpellClassMaskB_1`, `EffectSpellClassMaskB_2`, `EffectSpellClassMaskB_3`,
 `EffectSpellClassMaskC_1`, `EffectSpellClassMaskC_2`, `EffectSpellClassMaskC_3`,
 `SpellVisualID_1`, `SpellVisualID_2`, `SpellIconID`, `ActiveIconID`, `SpellPriority`,
 `Name_Lang_enUS`, `Name_Lang_enGB`, `Name_Lang_koKR`, `Name_Lang_frFR`, `Name_Lang_deDE`,
 `Name_Lang_enCN`, `Name_Lang_zhCN`, `Name_Lang_enTW`, `Name_Lang_zhTW`,
 `Name_Lang_esES`, `Name_Lang_esMX`, `Name_Lang_ruRU`, `Name_Lang_ptPT`, `Name_Lang_ptBR`,
 `Name_Lang_itIT`, `Name_Lang_Unk`, `Name_Lang_Mask`,
 `NameSubtext_Lang_enUS`, `NameSubtext_Lang_enGB`, `NameSubtext_Lang_koKR`, `NameSubtext_Lang_frFR`, `NameSubtext_Lang_deDE`,
 `NameSubtext_Lang_enCN`, `NameSubtext_Lang_zhCN`, `NameSubtext_Lang_enTW`, `NameSubtext_Lang_zhTW`,
 `NameSubtext_Lang_esES`, `NameSubtext_Lang_esMX`, `NameSubtext_Lang_ruRU`, `NameSubtext_Lang_ptPT`, `NameSubtext_Lang_ptBR`,
 `NameSubtext_Lang_itIT`, `NameSubtext_Lang_Unk`, `NameSubtext_Lang_Mask`,
 `Description_Lang_enUS`, `Description_Lang_enGB`, `Description_Lang_koKR`, `Description_Lang_frFR`, `Description_Lang_deDE`,
 `Description_Lang_enCN`, `Description_Lang_zhCN`, `Description_Lang_enTW`, `Description_Lang_zhTW`,
 `Description_Lang_esES`, `Description_Lang_esMX`, `Description_Lang_ruRU`, `Description_Lang_ptPT`, `Description_Lang_ptBR`,
 `Description_Lang_itIT`, `Description_Lang_Unk`, `Description_Lang_Mask`,
 `AuraDescription_Lang_enUS`, `AuraDescription_Lang_enGB`, `AuraDescription_Lang_koKR`, `AuraDescription_Lang_frFR`, `AuraDescription_Lang_deDE`,
 `AuraDescription_Lang_enCN`, `AuraDescription_Lang_zhCN`, `AuraDescription_Lang_enTW`, `AuraDescription_Lang_zhTW`,
 `AuraDescription_Lang_esES`, `AuraDescription_Lang_esMX`, `AuraDescription_Lang_ruRU`, `AuraDescription_Lang_ptPT`, `AuraDescription_Lang_ptBR`,
 `AuraDescription_Lang_itIT`, `AuraDescription_Lang_Unk`, `AuraDescription_Lang_Mask`,
 `ManaCostPct`, `StartRecoveryCategory`, `StartRecoveryTime`, `MaxTargetLevel`,
 `SpellClassSet`, `SpellClassMask_1`, `SpellClassMask_2`, `SpellClassMask_3`,
 `MaxTargets`, `DefenseType`, `PreventionType`, `StanceBarOrder`,
 `EffectChainAmplitude_1`, `EffectChainAmplitude_2`, `EffectChainAmplitude_3`,
 `MinFactionID`, `MinReputation`, `RequiredAuraVision`,
 `RequiredTotemCategoryID_1`, `RequiredTotemCategoryID_2`, `RequiredAreasID`,
 `SchoolMask`, `RuneCostID`, `SpellMissileID`, `PowerDisplayID`,
 `EffectBonusMultiplier_1`, `EffectBonusMultiplier_2`, `EffectBonusMultiplier_3`,
 `SpellDescriptionVariableID`, `SpellDifficultyID`)
VALUES 
(800001, -- ID
 0, 0, 0, -- Category, DispelType, Mechanic
 0x10010, 0, 0, 0, 0, 0, 0, 0, -- Attributes (0x10010=65552: IS_ABILITY+CLIENT_FLAGS to match Spell.dbc)
 0, 0, 0, 0, -- ShapeshiftMask, unk_320_2, ShapeshiftExclude, unk_320_3
 0, 0, 0, 0, -- Targets, TargetCreatureType, RequiresSpellFocus, FacingCasterFlags
 0, 0, 0, 0, -- CasterAuraState, TargetAuraState, ExcludeCasterAuraState, ExcludeTargetAuraState
 0, 0, 0, 0, -- CasterAuraSpell, TargetAuraSpell, ExcludeCasterAuraSpell, ExcludeTargetAuraSpell
 1, 0, 0, -- CastingTimeIndex (1=instant), RecoveryTime, CategoryRecoveryTime
 0, 0, 0, -- InterruptFlags, AuraInterruptFlags, ChannelInterruptFlags
 0, 0, 0, -- ProcTypeMask, ProcChance, ProcCharges
 0, 0, 0, 42, -- MaxLevel, BaseLevel, SpellLevel, DurationIndex (42=matches client Spell.dbc)
 0, 0, 0, 0, 0, -- PowerType, ManaCost, ManaCostPerLevel, ManaPerSecond, ManaPerSecondPerLevel
 1, 0, 0, 0, -- RangeIndex (1=self), Speed, ModalNextSpell, CumulativeAura
 0, 0, -- Totem_1, Totem_2
 0, 0, 0, 0, 0, 0, 0, 0, -- Reagent_1-8
 0, 0, 0, 0, 0, 0, 0, 0, -- ReagentCount_1-8
 -1, 0, 0, -- EquippedItemClass (-1=no requirement), EquippedItemSubclass, EquippedItemInvTypes
 6, 0, 0, -- Effect_1 (6=APPLY_AURA), Effect_2, Effect_3
 0, 0, 0, -- EffectDieSides_1-3
 0, 0, 0, -- EffectRealPointsPerLevel_1-3
 59, 0, 0, -- EffectBasePoints_1-3 (59=matches client Spell.dbc)
 0, 0, 0, -- EffectMechanic_1-3
 1, 0, 0, -- ImplicitTargetA_1 (1=TARGET_UNIT_CASTER=self - MUST match client!), 2, 3
 0, 0, 0, -- ImplicitTargetB_1-3
 0, 0, 0, -- EffectRadiusIndex_1-3
 4, 0, 0, -- EffectAura_1 (4=SPELL_AURA_DUMMY), EffectAura_2, EffectAura_3 -- CRITICAL: Must be 4!
 0, 0, 0, -- EffectAuraPeriod_1-3
 0, 0, 0, -- EffectMultipleValue_1-3
 0, 0, 0, -- EffectChainTargets_1-3
 0, 0, 0, -- EffectItemType_1-3
 0, 0, 0, -- EffectMiscValue_1-3
 0, 0, 0, -- EffectMiscValueB_1-3
 0, 0, 0, -- EffectTriggerSpell_1-3
 0, 0, 0, -- EffectPointsPerCombo_1-3
 0, 0, 0, -- EffectSpellClassMaskA_1-3
 0, 0, 0, -- EffectSpellClassMaskB_1-3
 0, 0, 0, -- EffectSpellClassMaskC_1-3
 0, 0, 4124, 0, 0, -- SpellVisualID_1, SpellVisualID_2, SpellIconID (4124=MUST match client!), ActiveIconID, SpellPriority
 'DC Hotspot - XP Buff 100%', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, -- Name_Lang
 NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, -- NameSubtext_Lang
 'Increases experience gained by 100% while in an XP Hotspot zone.', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, -- Description_Lang
 'Experience gained increased by 100%.', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, -- AuraDescription_Lang
 0, 0, 0, 0, -- ManaCostPct, StartRecoveryCategory, StartRecoveryTime, MaxTargetLevel
 0, 0, 0, 0, -- SpellClassSet, SpellClassMask_1-3
 0, 0, 0, 0, -- MaxTargets, DefenseType, PreventionType, StanceBarOrder
 0, 0, 0, -- EffectChainAmplitude_1-3
 0, 0, 0, -- MinFactionID, MinReputation, RequiredAuraVision
 0, 0, 0, -- RequiredTotemCategoryID_1, RequiredTotemCategoryID_2, RequiredAreasID
 1, 0, 0, 0, -- SchoolMask (1=Physical), RuneCostID, SpellMissileID, PowerDisplayID
 0, 0, 0, -- EffectBonusMultiplier_1-3
 0, 0); -- SpellDescriptionVariableID, SpellDifficultyID

-- Register the spell script
DELETE FROM `spell_script_names` WHERE `spell_id`=800001 AND `ScriptName`='spell_hotspot_buff_800001_aura';
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES (800001, 'spell_hotspot_buff_800001_aura');
