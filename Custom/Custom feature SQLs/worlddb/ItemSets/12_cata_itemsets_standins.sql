-- -------------------------------------------------------------------------
-- Five Cataclysm sets whose 4pc names an ability 3.3.5 does not have
-- -------------------------------------------------------------------------
-- READ THIS FIRST: unlike every other file in this series, the five 4-piece
-- bonuses below are NOT faithful downports. Each names a Cataclysm ability that
-- simply does not exist here, so it has been RETARGETED at a chosen 3.3.5
-- stand-in. That is a design substitution and it is the only place in this whole
-- import where the effect is not Blizzard's own. Every 2-piece bonus is untouched
-- and remains faithful.
--
--   934  Reinforced Sapphirium Battlearmor  (Paladin Protection)
--        4pc +50% duration of Guardian of Ancient Kings -> HOLY SHIELD
--        Coherent: Holy Shield has a duration and is the Protection signature.
--
--   936  Mercurial Regalia                  (Priest Shadow)
--        4pc +30% damage of Shadowy Apparitions -> SHADOW WORD: PAIN
--        Coherent, but note +30% on SW:P is a large buff in 3.3.5 terms.
--
--   1069 Spiritwalker's Vestments           (Shaman Restoration)
--        4pc +5s duration of Spiritwalker's Grace -> RIPTIDE
--        Coherent: Riptide is a HoT, so a duration modifier lands cleanly.
--
--   1059 Deep Earth Regalia                 (Druid Balance)   HALF-EFFECTIVE
--        4pc -5s cooldown AND +10% damage of Starsurge -> STARFIRE
--        Starfire has NO cooldown, so the cooldown half is inert by design.
--        Only the +10% damage actually does anything.
--
--   1063 Regalia of Radiant Glory           (Paladin Holy)    HALF-EFFECTIVE
--        4pc +5% direct AND +5% periodic healing of Holy Radiance -> HOLY LIGHT
--        Holy Light is a direct heal with no periodic component, so the DoT half
--        is inert. Only the +5% direct healing applies.
--
-- Set 941 Shadowflame Regalia was deliberately NOT included. Its 4pc is +300%
-- damage on your next 2 Fel Flames -- fine on a weak filler, absurd on any 3.3.5
-- warlock spell. Making it sane would mean changing Blizzard's number, which is
-- inventing balance rather than downporting it.
--
-- MASKS ARE MINIMAL AND ISOLATING. Each was computed by taking the stand-in
-- ability's own bits and dropping every bit any other spell of that family also
-- carries, then verified to hit that one ability and nothing else. This mattered
-- for Shadow Word: Pain in particular: its full class mask drags in Abolish
-- Disease and Cure Disease through a shared dword, so it is trimmed to the single
-- identifying bit (32768, 0, 0).
--     90306  -> (0, 64, 0)          Holy Shield
--     89922  -> (32768, 0, 0)       Shadow Word: Pain
--     105876 -> (0, 0, 16)          Riptide
--     105717 -> (4, 0, 0)           Starfire
--     105798 -> (2147483648, 0, 0)  Holy Light
--
-- Everything else -- effect values, the DieSides transform, proc data, columns --
-- is identical to 01/06/11. Apply after those. Idempotent.
-- -------------------------------------------------------------------------

-- -------------------------------------------------------------------------
-- 1. The 12 spells these five sets need
-- -------------------------------------------------------------------------

DELETE FROM `spell_dbc` WHERE `ID` IN (89915, 89922, 90301, 90306, 105717, 105722, 105742, 105743, 105763, 105764, 105798, 105876);

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
  (89915, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 6, 0, 0, 0, 'Item - Priest T11 Shadow 2P Bonus', 'Increases the critical strike chance of your Mind Flay and Mind Sear spells by $s1%.', 6, 107, 4, 1, 0, 7, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1572864, 64, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (89922, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 6, 0, 0, 0, 'Item - Priest T11 Shadow 4P Bonus', 'Increases the damage done by your Shadowy Apparitions by $s1%.', 6, 108, 29, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 32768, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (90301, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 10, 0, 0, 0, 'Item - Paladin T11 Protection 2P Bonus', 'Increases the damage done by your Crusader Strike ability by $s1%.', 6, 108, 9, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 32768, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (90306, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 10, 0, 0, 0, 'Item - Paladin T11 Protection 4P Bonus', 'Increases the duration of your Guardian of Ancient Kings ability by $s1%.', 6, 108, 49, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 64, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105717, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 7, 0, 0, 0, 'Item - Druid T13 Balance 4P Bonus (Starsurge)', 'Reduces the cooldown of Starsurge by ${$m1/-1000} sec and increases its damage by $s2%.', 6, 107, -5001, 1, 0, 11, 0, 0, 0, 1, 0, 0, 0, 0, 4, 0, 0, 6, 108, 9, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105722, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 7, 0, 0, 0, 'Item - Druid T13 Balance 2P Bonus (Insect Swarm)', 'Insect Swarm increases all damage done by your Starfire, Starsurge, and Wrath spells against that target by $s1%.', 6, 107, 2, 1, 0, 12, 0, 0, 0, 1, 0, 0, 0, 0, 2097168, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105742, 262144, 1024, 0, 0, 0, 0, 0, 0, 1, 8, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1871, 0, 2, -1, 10, 0, 0, 0, 'Saint''s Vigor', 'Reduces the mana cost of all healing spells by $s1% for $d.', 6, 108, -26, 1, 0, 14, 1, 0, 0, 1, 0, 0, 0, 0, 3223322624, 65536, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105743, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 17408, 100, 0, 0, 0, 0, 1, 0, 1, -1, 10, 0, 0, 0, 'Item - Paladin T13 Holy 2P Bonus (Divine Favor)', 'After using Divine Favor, the mana cost of your healing spells is reduced by $105742s1% for $105742d.', 6, 42, 34, 1, 0, 0, 0, 0, 105742, 1, 0, 0, 0, 0, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105763, 262144, 1024, 0, 0, 0, 0, 0, 0, 1, 8, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 5080, 0, 8, -1, 11, 0, 0, 0, 'Spiritual Stimulus', 'Reduces the mana cost of all healing spells by $s1% for $d.', 6, 108, -26, 1, 0, 14, 1, 0, 0, 1, 0, 0, 0, 0, 448, 1024, 80, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105764, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 17408, 100, 0, 0, 0, 0, 1, 0, 1, -1, 11, 0, 0, 0, 'Item - Shaman T13 Restoration 2P Bonus (Mana Tide)', 'After using Mana Tide Totem, the cost of your healing spells are reduced by $105763s1% for $105763d.', 6, 42, 34, 1, 0, 0, 0, 0, 105763, 1, 0, 0, 0, 0, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105798, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 10, 0, 0, 0, 'Item - Paladin T13 Holy 4P Bonus (Holy Radiance)', 'Increases the healing done by your Holy Radiance spell by $s1%.', 6, 108, 4, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 2147483648, 0, 0, 6, 108, 4, 1, 0, 22, 0, 0, 0, 1, 0, 0, 0, 0, 2147483648, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105876, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 11, 0, 0, 0, 'Item - Shaman T13 Restoration 4P Bonus (Spiritwalker''s Grace)', 'Increases the duration of Spiritwalker''s Grace by ${$m1/1000} sec, and you gain $105877s1% haste while Spiritwalker''s grace is active.', 6, 107, 4999, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

-- -------------------------------------------------------------------------
-- 2. The five sets
-- -------------------------------------------------------------------------

DELETE FROM `itemset_dbc` WHERE `ID` IN (934, 936, 1059, 1063, 1069);

INSERT INTO `itemset_dbc`
    (`ID`, `Name_Lang_enUS`, `Name_Lang_enGB`, `Name_Lang_koKR`, `Name_Lang_frFR`, `Name_Lang_deDE`, `Name_Lang_enCN`, `Name_Lang_zhCN`, `Name_Lang_enTW`, `Name_Lang_zhTW`, `Name_Lang_esES`, `Name_Lang_esMX`, `Name_Lang_ruRU`, `Name_Lang_ptPT`, `Name_Lang_ptBR`, `Name_Lang_itIT`, `Name_Lang_Unk`, `Name_Lang_Mask`, `ItemID_1`, `ItemID_2`, `ItemID_3`, `ItemID_4`, `ItemID_5`, `ItemID_6`, `ItemID_7`, `ItemID_8`, `ItemID_9`, `ItemID_10`, `ItemID_11`, `ItemID_12`, `ItemID_13`, `ItemID_14`, `ItemID_15`, `ItemID_16`, `ItemID_17`, `SetSpellID_1`, `SetSpellID_2`, `SetSpellID_3`, `SetSpellID_4`, `SetSpellID_5`, `SetSpellID_6`, `SetSpellID_7`, `SetSpellID_8`, `SetThreshold_1`, `SetThreshold_2`, `SetThreshold_3`, `SetThreshold_4`, `SetThreshold_5`, `SetThreshold_6`, `SetThreshold_7`, `SetThreshold_8`, `RequiredSkill`, `RequiredSkillRank`)
VALUES
  (934, 'Reinforced Sapphirium Battlearmor', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 60358, 60357, 60356, 60355, 60354, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 90301, 90306, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (936, 'Mercurial Regalia', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 60253, 60254, 60255, 60256, 60257, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 89915, 89922, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (1059, 'Deep Earth Regalia', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 77018, 77019, 77020, 77021, 77022, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 105722, 105717, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (1063, 'Regalia of Radiant Glory', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 76765, 76766, 76767, 76768, 76769, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 105743, 105798, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (1069, 'Spiritwalker''s Vestments', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 76756, 76757, 76758, 76759, 76760, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 105764, 105876, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0);

-- -------------------------------------------------------------------------
-- 3. Wire the item shells
-- -------------------------------------------------------------------------

-- Reinforced Sapphirium Battlearmor
UPDATE `item_template` SET `itemset` = 934 WHERE `entry` IN (60354, 60355, 60356, 60357, 60358);
-- Mercurial Regalia
UPDATE `item_template` SET `itemset` = 936 WHERE `entry` IN (60253, 60254, 60255, 60256, 60257);
-- Deep Earth Regalia
UPDATE `item_template` SET `itemset` = 1059 WHERE `entry` IN (77018, 77019, 77020, 77021, 77022);
-- Regalia of Radiant Glory
UPDATE `item_template` SET `itemset` = 1063 WHERE `entry` IN (76765, 76766, 76767, 76768, 76769);
-- Spiritwalker's Vestments
UPDATE `item_template` SET `itemset` = 1069 WHERE `entry` IN (76756, 76757, 76758, 76759, 76760);

-- -------------------------------------------------------------------------
-- Verification
-- -------------------------------------------------------------------------
--   SELECT COUNT(*) FROM itemset_dbc;   -- 52
--   SELECT COUNT(*) FROM item_template WHERE itemset IN (934,936,1059,1063,1069);  -- 25
--   -- each retargeted mask must hit exactly one ability:
--   SELECT ID, EffectSpellClassMaskA_1, EffectSpellClassMaskB_1, EffectSpellClassMaskC_1
--     FROM spell_dbc WHERE ID IN (90306, 89922, 105876, 105717, 105798);
-- -------------------------------------------------------------------------
