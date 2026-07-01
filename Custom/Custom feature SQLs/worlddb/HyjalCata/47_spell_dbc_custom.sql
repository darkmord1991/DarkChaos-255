-- =====================================================================
-- Mount Hyjal (map 750) + Molten Front -- 47  Neltharion CUSTOM spells
-- ---------------------------------------------------------------------
-- 41_spell_dbc.sql covered the 76 stock CATA spells. This file ports the
-- 15 NELTHARION-CUSTOM spells (101097..151267) the ported C++ casts, which
-- exist only in nelt_world's normalized 4.3.4 layout (header spell_dbc +
-- spelleffect_dbc keyed by EffectSpellId). Flattened here into this fork's
-- 234-col 3.3.5 spell_dbc (every column has a DEFAULT, so only meaningful
-- columns are listed). Summon EffectMiscValues are remapped +3,600,000
-- (151010 -> Aronus vehicle 3675024, 151267 -> Forlorn camera 3653017);
-- SummonProperties 827/488 verified present in Custom/CSV DBC.
--
-- Also authors the two Turtle Punter bar spells (stock Cata 93604/93593 --
-- present in NO source DB, minimal serverside rows matching what the
-- SpellScripts expect) and wires their spell_script_names.
--
-- NOT covered: 151415 SPELL_TELEPORT_1 (declared in the C++ enum but absent
-- even from nelt_world and never cast -- dead constant), and the 4 graduation
-- podium spells (see TODO at the bottom).
--
-- CLIENT side: these spells are serverside-only. Auras the player SEES
-- (151235 dismount flash, 151111 fear visual, vehicle bar spells 93604/93593)
-- should eventually get client Spell.csv rows for tooltips/visuals; gameplay
-- works without them. Idempotent. Run on the world-DB host.
-- =====================================================================
SET @OFF := 3600000;

DELETE FROM acore_world.spell_dbc WHERE ID IN (101097,101098,101099,101100,101101,101103,101167,115006,150000,150001,151010,151100,151111,151235,151267,93593,93604);

INSERT INTO acore_world.spell_dbc
(`ID`,`Attributes`,`AttributesEx`,`AttributesEx2`,`AttributesEx3`,`AttributesEx4`,`AttributesEx5`,`AttributesEx6`,`AttributesEx7`,
 `CastingTimeIndex`,`DurationIndex`,`PowerType`,`RangeIndex`,`SchoolMask`,`RuneCostID`,`ProcChance`,`EquippedItemClass`,
 `Effect_1`,`Effect_2`,`Effect_3`,
 `EffectDieSides_1`,`EffectDieSides_2`,`EffectDieSides_3`,
 `EffectBasePoints_1`,`EffectBasePoints_2`,`EffectBasePoints_3`,
 `ImplicitTargetA_1`,`ImplicitTargetA_2`,`ImplicitTargetA_3`,
 `ImplicitTargetB_1`,`ImplicitTargetB_2`,`ImplicitTargetB_3`,
 `EffectRadiusIndex_1`,`EffectRadiusIndex_2`,`EffectRadiusIndex_3`,
 `EffectAura_1`,`EffectAura_2`,`EffectAura_3`,
 `EffectAuraPeriod_1`,`EffectAuraPeriod_2`,`EffectAuraPeriod_3`,
 `EffectMultipleValue_1`,`EffectMultipleValue_2`,`EffectMultipleValue_3`,
 `EffectChainTargets_1`,`EffectChainTargets_2`,`EffectChainTargets_3`,
 `EffectMiscValue_1`,`EffectMiscValue_2`,`EffectMiscValue_3`,
 `EffectMiscValueB_1`,`EffectMiscValueB_2`,`EffectMiscValueB_3`,
 `EffectTriggerSpell_1`,`EffectTriggerSpell_2`,`EffectTriggerSpell_3`,
 `SpellIconID`,`Name_Lang_enUS`,`Name_Lang_Mask`)
SELECT
 s.Id, s.Attributes, s.AttributesEx, s.AttributesEx2, s.AttributesEx3, s.AttributesEx4, s.AttributesEx5, s.AttributesEx6, s.AttributesEx7,
 s.CastingTimeIndex, s.DurationIndex, s.powerType, s.rangeIndex, s.SchoolMask, s.runeCostID, 101, -1,
 IFNULL(e0.Effect,0), IFNULL(e1.Effect,0), IFNULL(e2.Effect,0),
 IFNULL(e0.EffectDieSides,0), IFNULL(e1.EffectDieSides,0), IFNULL(e2.EffectDieSides,0),
 IFNULL(e0.EffectBasePoints,0), IFNULL(e1.EffectBasePoints,0), IFNULL(e2.EffectBasePoints,0),
 IFNULL(e0.EffectImplicitTargetA,0), IFNULL(e1.EffectImplicitTargetA,0), IFNULL(e2.EffectImplicitTargetA,0),
 IFNULL(e0.EffectImplicitTargetB,0), IFNULL(e1.EffectImplicitTargetB,0), IFNULL(e2.EffectImplicitTargetB,0),
 IFNULL(e0.EffectRadiusIndex,0), IFNULL(e1.EffectRadiusIndex,0), IFNULL(e2.EffectRadiusIndex,0),
 IFNULL(e0.EffectApplyAuraName,0), IFNULL(e1.EffectApplyAuraName,0), IFNULL(e2.EffectApplyAuraName,0),
 IFNULL(e0.EffectAmplitude,0), IFNULL(e1.EffectAmplitude,0), IFNULL(e2.EffectAmplitude,0),
 IFNULL(e0.EffectValueMultiplier,0), IFNULL(e1.EffectValueMultiplier,0), IFNULL(e2.EffectValueMultiplier,0),
 IFNULL(e0.EffectChainTarget,0), IFNULL(e1.EffectChainTarget,0), IFNULL(e2.EffectChainTarget,0),
 CASE WHEN e0.Effect IN (28,50,76,104,105,106,107,108) AND e0.EffectMiscValue>0 THEN e0.EffectMiscValue+@OFF ELSE IFNULL(e0.EffectMiscValue,0) END,
 CASE WHEN e1.Effect IN (28,50,76,104,105,106,107,108) AND e1.EffectMiscValue>0 THEN e1.EffectMiscValue+@OFF ELSE IFNULL(e1.EffectMiscValue,0) END,
 CASE WHEN e2.Effect IN (28,50,76,104,105,106,107,108) AND e2.EffectMiscValue>0 THEN e2.EffectMiscValue+@OFF ELSE IFNULL(e2.EffectMiscValue,0) END,
 IFNULL(e0.EffectMiscValueB,0), IFNULL(e1.EffectMiscValueB,0), IFNULL(e2.EffectMiscValueB,0),
 IFNULL(e0.EffectTriggerSpell,0), IFNULL(e1.EffectTriggerSpell,0), IFNULL(e2.EffectTriggerSpell,0),
 1,
 CASE s.Id
   WHEN 101097 THEN 'Blazefury Credit'      WHEN 101098 THEN 'Ragepyre Credit'
   WHEN 101099 THEN 'Flashfire Credit'      WHEN 101100 THEN 'Hatespark Credit'
   WHEN 101101 THEN 'Heatflayer Credit'     WHEN 101103 THEN 'Singeslayer Credit'
   WHEN 101167 THEN 'Grant Flawless Victory' WHEN 115006 THEN 'Ludicrous Speed'
   WHEN 150000 THEN 'Ping Orb of Ascension' WHEN 150001 THEN 'Mental Training: Idle Check'
   WHEN 151010 THEN 'Summon Aronus'         WHEN 151100 THEN 'Wisp Away: Dummy Aura Check'
   WHEN 151111 THEN 'Fear Visual'           WHEN 151235 THEN 'Dismount and Cancel Shapeshifts'
   WHEN 151267 THEN 'Summon Forlorn Camera' END,
 16712190
FROM nelt_world.spell_dbc s
LEFT JOIN nelt_world.spelleffect_dbc e0 ON e0.EffectSpellId=s.Id AND e0.EffectIndex=0
LEFT JOIN nelt_world.spelleffect_dbc e1 ON e1.EffectSpellId=s.Id AND e1.EffectIndex=1
LEFT JOIN nelt_world.spelleffect_dbc e2 ON e2.EffectSpellId=s.Id AND e2.EffectIndex=2
WHERE s.Id IN (101097,101098,101099,101100,101101,101103,101167,115006,150000,150001,151010,151100,151111,151235,151267);

-- ---------------------------------------------------------------------
-- Turtle Punter bar spells (stock Cata ids kept so the C++ vehicle bar
-- rows in creature_template_spell resolve). Minimal serverside rows:
--   93604 Drop Off Turtle: EFFECT_1 = SCRIPT_EFFECT (spell_drop_turtle
--         registers OnEffectHitTarget EFFECT_1); the summon of the child
--         (3652177) happens in the SpellScript, not via effect data.
--   93593 Save Turtle:     dummy (spell_tortolla_save_turtle uses OnCast).
-- If in-game testing shows the bar buttons swapped, swap the two
-- spell_script_names rows below (nelt only records spell1=93604, spell2=93593
-- on the punter template, not which is which).
-- ---------------------------------------------------------------------
INSERT INTO acore_world.spell_dbc
(`ID`,`Attributes`,`CastingTimeIndex`,`DurationIndex`,`RangeIndex`,`SchoolMask`,`ProcChance`,`EquippedItemClass`,
 `Effect_1`,`Effect_2`,`ImplicitTargetA_1`,`ImplicitTargetA_2`,`SpellIconID`,`Name_Lang_enUS`,`Name_Lang_Mask`)
VALUES
(93604, 0, 1, 0, 1, 1, 101, -1, 3, 77, 1, 1, 1, 'Drop Off Turtle', 16712190),
(93593, 0, 1, 0, 1, 1, 101, -1, 3,  0, 1, 0, 1, 'Save Turtle',     16712190);

DELETE FROM acore_world.spell_script_names WHERE ScriptName IN ('spell_drop_turtle','spell_tortolla_save_turtle');
INSERT INTO acore_world.spell_script_names (`spell_id`,`ScriptName`) VALUES
(93604, 'spell_drop_turtle'),
(93593, 'spell_tortolla_save_turtle');

-- ---------------------------------------------------------------------
-- TODO (blocked): graduation podium spells. spell_inspiration_graduation /
-- spell_divisiveness_graduation / spell_crazy_graduation /
-- spell_step_down_graduation hook 4 stock Cata player spells granted by
-- aura 293 (SPELL_AURA_OVERRIDE_SPELLS) on 74948 with MiscValue 270 =
-- OverrideSpellData.dbc row 270. That row (and the 4 spell ids it lists)
-- exists in no available DB (acore overridespelldata_dbc, nelt_world and
-- cata_world all lack it) -- it must be read from a Cata 4.3.4 client
-- OverrideSpellData.dbc / wago.tools export. Once known:
--   1. INSERT the overridespelldata_dbc row 270 (+ client DBC append),
--   2. author the 4 spells (EFFECT_0 SCRIPT_EFFECT + one AfterHit dummy),
--   3. wire the 4 spell_script_names rows.
-- Until then the Graduation Speech quest (25315) cannot present choices.
-- ---------------------------------------------------------------------
