-- -------------------------------------------------------------------------
-- Two more Cataclysm sets -- 933 and 942 -- recovered without any C++
-- -------------------------------------------------------------------------
-- Both were deferred by 01_cata_itemsets_phase1.sql because the automatic mask
-- remap could not resolve their 4-piece proc. Neither is actually a dead bonus:
--
--   933 Reinforced Sapphirium Regalia (Paladin Holy)
--       4pc "Grants Spirit after you cast Holy Shock". The Cata mask (0,16,0)
--       expands to "Resistance Aura / Scourge Banner Aura", which is nonsense for
--       this bonus and matches nothing useful here -- so the solver gave up.
--       Holy Shock exists in 3.3.5 with a clean identity mask.
--
--   942 Earthen Warplate (Warrior DPS)
--       4pc "Each time you use Overpower or Raging Blow". Cata mask (0,0,128)
--       expands to nothing at all in 3.3.5. Overpower exists here; Raging Blow
--       does not, so the bonus fires on Overpower alone -- a narrower trigger
--       than retail, not a wrong one.
--
-- The two masks below are therefore HAND-AUTHORED, and each was checked to hit
-- exactly one ability and nothing else:
--     90313 eff0 -> (2097152, 65536, 0)   hits exactly "Holy Shock"
--     90295 eff0 -> (4, 0, 0)             hits exactly "Overpower"
-- Every other mask in this file comes from the same automatic solver used by 01.
--
-- Everything else -- effect values, DieSides transform, proc data, column layout --
-- is identical to 01 and 06. Apply after those. Idempotent.
-- -------------------------------------------------------------------------

-- -------------------------------------------------------------------------
-- 1. The 6 spells these two sets need
-- -------------------------------------------------------------------------

DELETE FROM `spell_dbc` WHERE `ID` IN (90293, 90294, 90295, 90310, 90311, 90313);

INSERT INTO `spell_dbc`
    (`ID`,
     `Attributes`,
     `AttributesEx`,
     `AttributesEx2`,
     `AttributesEx3`,
     `AttributesEx4`,
     `AttributesEx5`,
     `AttributesEx6`,
     `AttributesEx7`,
     `CastingTimeIndex`,
     `DurationIndex`,
     `PowerType`,
     `RangeIndex`,
     `Speed`,
     `ProcTypeMask`,
     `ProcChance`,
     `ProcCharges`,
     `CumulativeAura`,
     `SpellVisualID_1`,
     `SpellVisualID_2`,
     `SpellIconID`,
     `ActiveIconID`,
     `SchoolMask`,
     `EquippedItemClass`,
     `SpellClassSet`,
     `SpellClassMask_1`,
     `SpellClassMask_2`,
     `SpellClassMask_3`,
     `Name_Lang_enUS`,
     `Description_Lang_enUS`,
     `Effect_1`,
     `EffectAura_1`,
     `EffectBasePoints_1`,
     `EffectDieSides_1`,
     `EffectAuraPeriod_1`,
     `EffectMiscValue_1`,
     `EffectMiscValueB_1`,
     `EffectRadiusIndex_1`,
     `EffectTriggerSpell_1`,
     `ImplicitTargetA_1`,
     `ImplicitTargetB_1`,
     `EffectMechanic_1`,
     `EffectChainTargets_1`,
     `EffectItemType_1`,
     `EffectSpellClassMaskA_1`,
     `EffectSpellClassMaskB_1`,
     `EffectSpellClassMaskC_1`,
     `Effect_2`,
     `EffectAura_2`,
     `EffectBasePoints_2`,
     `EffectDieSides_2`,
     `EffectAuraPeriod_2`,
     `EffectMiscValue_2`,
     `EffectMiscValueB_2`,
     `EffectRadiusIndex_2`,
     `EffectTriggerSpell_2`,
     `ImplicitTargetA_2`,
     `ImplicitTargetB_2`,
     `EffectMechanic_2`,
     `EffectChainTargets_2`,
     `EffectItemType_2`,
     `EffectSpellClassMaskA_2`,
     `EffectSpellClassMaskB_2`,
     `EffectSpellClassMaskC_2`,
     `Effect_3`,
     `EffectAura_3`,
     `EffectBasePoints_3`,
     `EffectDieSides_3`,
     `EffectAuraPeriod_3`,
     `EffectMiscValue_3`,
     `EffectMiscValueB_3`,
     `EffectRadiusIndex_3`,
     `EffectTriggerSpell_3`,
     `ImplicitTargetA_3`,
     `ImplicitTargetB_3`,
     `EffectMechanic_3`,
     `EffectChainTargets_3`,
     `EffectItemType_3`,
     `EffectSpellClassMaskA_3`,
     `EffectSpellClassMaskB_3`,
     `EffectSpellClassMaskC_3`)
VALUES
  (90293, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 4, 0, 0, 0, 'Item - Warrior T11 DPS 2P Bonus', 'Increases the damage done by your Bloodthirst and Mortal Strike abilities by $s1%.', 6, 108, 4, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 33554432, 1024, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (90294, 0, 0, 0, 0, 0, 0, 0, 0, 1, 9, 0, 1, 0.0, 0, 101, 0, 3, 0, 0, 2024, 0, 1, -1, 0, 0, 0, 0, 'Rage of the Ages', 'Increases your attack power by $s1% for $d when you use Overpower or Raging Blow.', 6, 166, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (90295, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 16, 100, 0, 0, 0, 0, 1, 0, 1, -1, 4, 0, 0, 0, 'Item - Warrior T11 DPS 4P Bonus', 'Each time you use Overpower or Raging Blow you gain a $90294s1% increase to attack power for $90294d stacking up to $90294u times.', 6, 42, 49, 1, 0, 1, 0, 0, 90294, 1, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (90310, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 10, 0, 0, 0, 'Item - Paladin T11 Holy 2P Bonus', 'Increases the critical strike chance of your Holy Light spell by $s1%.', 6, 107, 4, 1, 0, 7, 0, 0, 0, 1, 0, 0, 0, 0, 2147483648, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (90311, 0, 0, 0, 0, 0, 0, 0, 0, 1, 32, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1874, 0, 2, -1, 0, 0, 0, 0, 'Radiant', 'Grants $s1 Spirit for $d after casting Holy Shock.', 6, 29, 539, 1, 0, 4, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (90313, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 81920, 100, 0, 0, 0, 0, 1, 0, 1, -1, 10, 0, 0, 0, 'Item - Paladin T11 Holy 4P Bonus', 'Grants $90311s1 Spirit for $90311d after you cast Holy Shock.', 6, 42, 4, 1, 0, 7, 0, 0, 90311, 1, 0, 0, 0, 0, 2097152, 65536, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

-- -------------------------------------------------------------------------
-- 2. The two sets
-- -------------------------------------------------------------------------

DELETE FROM `itemset_dbc` WHERE `ID` IN (933, 942);

INSERT INTO `itemset_dbc`
    (`ID`, `Name_Lang_enUS`, `Name_Lang_enGB`, `Name_Lang_koKR`, `Name_Lang_frFR`, `Name_Lang_deDE`, `Name_Lang_enCN`, `Name_Lang_zhCN`, `Name_Lang_enTW`, `Name_Lang_zhTW`, `Name_Lang_esES`, `Name_Lang_esMX`, `Name_Lang_ruRU`, `Name_Lang_ptPT`, `Name_Lang_ptBR`, `Name_Lang_itIT`, `Name_Lang_Unk`, `Name_Lang_Mask`, `ItemID_1`, `ItemID_2`, `ItemID_3`, `ItemID_4`, `ItemID_5`, `ItemID_6`, `ItemID_7`, `ItemID_8`, `ItemID_9`, `ItemID_10`, `ItemID_11`, `ItemID_12`, `ItemID_13`, `ItemID_14`, `ItemID_15`, `ItemID_16`, `ItemID_17`, `SetSpellID_1`, `SetSpellID_2`, `SetSpellID_3`, `SetSpellID_4`, `SetSpellID_5`, `SetSpellID_6`, `SetSpellID_7`, `SetSpellID_8`, `SetThreshold_1`, `SetThreshold_2`, `SetThreshold_3`, `SetThreshold_4`, `SetThreshold_5`, `SetThreshold_6`, `SetThreshold_7`, `SetThreshold_8`, `RequiredSkill`, `RequiredSkillRank`)
VALUES
  (933, 'Reinforced Sapphirium Regalia', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 60362, 60361, 60359, 60363, 60360, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 90310, 90313, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (942, 'Earthen Warplate', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 60327, 60324, 60325, 60326, 60323, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 90293, 90295, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0);

-- -------------------------------------------------------------------------
-- 3. Wire the item shells
-- -------------------------------------------------------------------------

-- Reinforced Sapphirium Regalia
UPDATE `item_template` SET `itemset` = 933 WHERE `entry` IN (60359, 60360, 60361, 60362, 60363);
-- Earthen Warplate
UPDATE `item_template` SET `itemset` = 942 WHERE `entry` IN (60323, 60324, 60325, 60326, 60327);

-- -------------------------------------------------------------------------
-- Verification
-- -------------------------------------------------------------------------
--   SELECT COUNT(*) FROM itemset_dbc;                                -- 47
--   SELECT COUNT(*) FROM item_template WHERE itemset IN (933, 942);  -- 10
--   -- the two hand-authored masks must hit one ability each:
--   SELECT ID, EffectSpellClassMaskA_1, EffectSpellClassMaskB_1
--     FROM spell_dbc WHERE ID IN (90313, 90295);
--   -- expect 90313 -> 2097152 / 65536, 90295 -> 4 / 0
-- -------------------------------------------------------------------------
