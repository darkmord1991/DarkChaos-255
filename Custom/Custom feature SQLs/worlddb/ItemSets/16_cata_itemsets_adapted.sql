-- -------------------------------------------------------------------------
-- Four Cataclysm sets ADAPTED to 3.3.5 -- retargeted masks, one rescaled value
-- -------------------------------------------------------------------------
-- None of these need C++: every bonus is already a modifier or proc aura. They were
-- held back only because a mask named a Cataclysm ability this expansion lacks.
-- Each is retargeted at a 3.3.5 ability below. These ARE deliberate substitutions,
-- not downports -- the 2pc bonuses are untouched and stay faithful.
--
--   941  Shadowflame Regalia (Warlock)
--        4pc chain ends in "your next 2 Fel Flame spells deal +300% damage".
--        Fel Flame does not exist -> retargeted to SHADOW BOLT, and the value is
--        RESCALED 300% -> 15%. Fel Flame was a weak Cataclysm filler, so +300% on it
--        was reasonable; +300% on the warlock main nuke would not be. 15% sits in
--        the same band as the Wrath-era set bonuses it now lives beside.
--
--   1007 Firehawk Robes of Conflagration (Mage)
--        4pc "increased chance to trigger Brain Freeze or Hot Streak". Both exist in
--        3.3.5 but carry an ALL-ZERO class mask, so no modifier can ever target
--        them -- a proc-chance bonus is simply not expressible here. Adapted to a
--        straight FIREBALL damage bonus (effect 1 converted from CHANCE_OF_SUCCESS
--        to DAMAGE, effect 2 zeroed), which keeps the fire theme and the rough
--        power level. This is the largest reinterpretation in the file.
--        The value is also RESCALED -20 -> +15: the original -20 belonged to a
--        different modifier type, and carrying it into DAMAGE unchanged would have
--        made the 4pc a 20% Fireball PENALTY instead of a bonus.
--
--   1065 Armor of Radiant Glory (Paladin Protection)
--        4pc reduces the cooldown of Divine Guardian and widens its radius. Divine
--        Guardian exists but has an all-zero mask -> retargeted to DIVINE
--        PROTECTION, which has a real cooldown. NOTE the radius half is inert:
--        Divine Protection is a self-buff with no radius, so only the -60s cooldown
--        actually does anything.
--
--   1073 Colossal Dragonplate Battlegear (Warrior)
--        Both procs pointed at Cataclysm masks that expand to nothing here. The
--        abilities they NAME all exist, so they are simply re-masked:
--        2pc -> HEROIC STRIKE, 4pc -> BLOODTHIRST | MORTAL STRIKE. No rescale --
--        this set is a faithful port, it just needed the right bits.
--
-- Every mask below is minimal and isolating: computed from the stand-in ability's
-- own bits with every bit shared by another spell of that family removed, then
-- verified to hit that ability and nothing else.
--     89937  -> (1, 0, 0)             Shadow Bolt
--     99064  -> (1, 0, 0)             Fireball
--     105744 -> (0, 0, 256)           Divine Protection
--     105797 -> (64, 0, 0)            Heroic Strike
--     105907 -> (33554432, 1024, 0)   Bloodthirst | Mortal Strike
--
-- COLOSSUS SMASH (108126), which 1073 4pc procs, used Cataclysm aura 345
-- ("bypass N% of the target armor"). 3.3.5 stops at TOTAL_AURAS = 317, and
-- SpellMgr::LoadSpellInfoStore ASSERTS and then SEGFAULTS on anything above that --
-- an out-of-range aura is a boot-blocker, not a silent no-op. It is rebuilt on
-- aura 76 (MOD_TARGET_RESISTANCE), the same armour debuff Sunder Armor and Faerie
-- Fire use, at -2000 armour. That value is a JUDGEMENT CALL: Cataclysm bypassed
-- 100% of armour, which has no meaning here, so it is scaled to roughly what a
-- full Sunder Armor removes against raid-level targets.
--
-- Apply after 01/06. Idempotent.
-- -------------------------------------------------------------------------

-- -------------------------------------------------------------------------
-- 1. Spells (12)
-- -------------------------------------------------------------------------

DELETE FROM `spell_dbc` WHERE `ID` IN (
  89934, 89935, 89937, 99061, 99063, 99064, 105744, 105797, 105800, 105860,
  105907, 108126);

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
  (89934, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 5, 0, 0, 0, 'Item - Warlock T11 2P Bonus', 'Reduces the cast time of your Chaos Bolt, Hand of Gul''dan, and Haunt spells by $s1%.', 6, 108, -11, 1, 0, 10, 0, 0, 0, 1, 0, 0, 0, 0, 0, 393216, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (89935, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 262144, 2, 0, 0, 0, 0, 1, 0, 1, -1, 5, 0, 0, 0, 'Item - Warlock T11 4P Bonus', 'Periodic damage from your Immolate and Unstable Affliction spells has a $h% chance to cause your 2 next Fel Flame spells to deal $89937s1% increased damage.', 6, 42, 99, 1, 0, 10, 0, 0, 89937, 1, 0, 0, 0, 0, 0, 393216, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (89937, 0, 0, 0, 0, 0, 0, 0, 0, 1, 8, 0, 1, 0.0, 65536, 100, 2, 0, 0, 0, 2299, 0, 2, -1, 5, 0, 0, 0, 'Fel Spark', 'Your next 2 Fel Flame spells deal $89937s1% increased damage.', 6, 108, 14, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99061, 192, 0, 0, 67108864, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 65536, 20, 0, 0, 0, 0, 1, 0, 1, -1, 3, 0, 0, 0, 'Item - Mage T12 2P Bonus', 'You have a chance to summon a Mirror Image to assist you in battle for $99063d when you cast Frostbolt, Fireball, Frostfire Bolt, or Arcane Blast.', 6, 42, 2, 1, 0, 0, 0, 0, 99063, 1, 0, 0, 0, 0, 8388608, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99063, 0, 0, 0, 0, 65536, 0, 0, 0, 1, 8, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 331, 0, 1, -1, 0, 0, 0, 0, 'Mirror Image', 'Summons a Mirror Image to assist you in battle.', 28, 0, 0, 1, 0, 53438, 2909, 15, 0, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99064, 64, 0, 0, 67108864, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 3, 0, 0, 0, 'Item - Mage T12 4P Bonus', 'Your spells have an increased chance to trigger Brain Freeze or Hot Streak.  In addition, Arcane Power decreases the cost of your damaging spells by 10% instead of increasing their cost.', 6, 107, 14, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 6, 107, 14, 1, 0, 18, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105744, 464, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 10, 0, 0, 0, 'Item - Paladin T13 Protection 4P Bonus (Divine Guardian)', 'Reduces the cooldown of Divine Guardian by ${$m1/-1000} sec and increases the radius of its effect by $s2 yards.', 6, 107, -60001, 1, 0, 11, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 256, 6, 107, 69, 1, 0, 6, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 256, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105797, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 52768, 101, 0, 0, 0, 0, 1, 0, 1, -1, 4, 0, 0, 0, 'Item - Warrior T13 Arms and Fury 2P Bonus (Inner Rage)', 'Heroic Strike costs $s1 less rage while Inner Rage is active.', 6, 42, 9, 1, 0, 0, 0, 0, 105860, 1, 0, 0, 0, 0, 64, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105800, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 69648, 100, 0, 0, 0, 0, 1, 0, 1, -1, 10, 0, 0, 0, 'Item - Paladin T13 Protection 2P Bonus (Judgement)', 'Your Judgement ability now also grants a physical absorbtion shield equal to $s1% of the damage it dealt.', 6, 42, 24, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105860, 16, 1024, 0, 0, 0, 0, 0, 0, 1, 8, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 2779, 0, 1, -1, 4, 0, 0, 0, 'Volatile Outrage', 'Inner Rage reduces the cost of your Heroic Strike ability by $105797s1.', 6, 107, -101, 1, 0, 14, 0, 0, 0, 1, 0, 0, 0, 0, 64, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105907, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 16, 13, 0, 0, 0, 0, 1, 0, 1, -1, 4, 0, 0, 0, 'Item - Warrior T13 Arms and Fury 4P Bonus (Colossus Smash)', 'Your Bloodthirst has a $s1% chance and your Mortal Strike has a $h% chance to apply the Colossus Smash effect on your target for $108126d.', 6, 42, 5, 1, 0, 0, 0, 0, 108126, 1, 0, 0, 0, 0, 33554432, 1024, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (108126, 327696, 134218240, 0, 1152, 0, 0, 0, 0, 1, 32, 1, 2, 0.0, 0, 101, 0, 0, 18383, 0, 5288, 0, 1, -1, 4, 0, 1073741824, 0, 'Colossus Smash', 'Weakens the target''s defenses, allowing your attacks to entirely bypass $s1% of their armor for $d.  Bypasses less armor on players.', 6, 76, -2001, 1, 0, 1, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

-- -------------------------------------------------------------------------
-- 2. The four sets
-- -------------------------------------------------------------------------

DELETE FROM `itemset_dbc` WHERE `ID` IN (941, 1007, 1065, 1073);

INSERT INTO `itemset_dbc`
    (`ID`, `Name_Lang_enUS`, `Name_Lang_enGB`, `Name_Lang_koKR`, `Name_Lang_frFR`, `Name_Lang_deDE`, `Name_Lang_enCN`, `Name_Lang_zhCN`, `Name_Lang_enTW`, `Name_Lang_zhTW`, `Name_Lang_esES`, `Name_Lang_esMX`, `Name_Lang_ruRU`, `Name_Lang_ptPT`, `Name_Lang_ptBR`, `Name_Lang_itIT`, `Name_Lang_Unk`, `Name_Lang_Mask`, `ItemID_1`, `ItemID_2`, `ItemID_3`, `ItemID_4`, `ItemID_5`, `ItemID_6`, `ItemID_7`, `ItemID_8`, `ItemID_9`, `ItemID_10`, `ItemID_11`, `ItemID_12`, `ItemID_13`, `ItemID_14`, `ItemID_15`, `ItemID_16`, `ItemID_17`, `SetSpellID_1`, `SetSpellID_2`, `SetSpellID_3`, `SetSpellID_4`, `SetSpellID_5`, `SetSpellID_6`, `SetSpellID_7`, `SetSpellID_8`, `SetThreshold_1`, `SetThreshold_2`, `SetThreshold_3`, `SetThreshold_4`, `SetThreshold_5`, `SetThreshold_6`, `SetThreshold_7`, `SetThreshold_8`, `RequiredSkill`, `RequiredSkillRank`)
VALUES
  (941, 'Shadowflame Regalia', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 60252, 60251, 60250, 60249, 60248, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 89934, 89935, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (1007, 'Firehawk Robes of Conflagration', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 71290, 71286, 71287, 71288, 71289, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 99061, 99064, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (1065, 'Armor of Radiant Glory', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 77003, 77004, 77005, 77006, 77007, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 105800, 105744, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (1073, 'Colossal Dragonplate Battlegear', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 76983, 76984, 76985, 76986, 76987, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 105797, 105907, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0);

-- -------------------------------------------------------------------------
-- 3. Wire the item shells
-- -------------------------------------------------------------------------

-- Shadowflame Regalia
UPDATE `item_template` SET `itemset` = 941 WHERE `entry` IN (60248, 60249, 60250, 60251, 60252);
-- Firehawk Robes of Conflagration
UPDATE `item_template` SET `itemset` = 1007 WHERE `entry` IN (71286, 71287, 71288, 71289, 71290);
-- Armor of Radiant Glory
UPDATE `item_template` SET `itemset` = 1065 WHERE `entry` IN (77003, 77004, 77005, 77006, 77007);
-- Colossal Dragonplate Battlegear
UPDATE `item_template` SET `itemset` = 1073 WHERE `entry` IN (76983, 76984, 76985, 76986, 76987);

-- -------------------------------------------------------------------------
-- Verification
-- -------------------------------------------------------------------------
--   SELECT COUNT(*) FROM itemset_dbc;   -- 66
--   -- the rescale landed (DieSides 1, so BasePoints is value-1 => 14):
--   SELECT ID, EffectBasePoints_1, EffectDieSides_1 FROM spell_dbc WHERE ID = 89937;
--   -- and the retargeted masks:
--   SELECT ID, EffectSpellClassMaskA_1, EffectSpellClassMaskB_1, EffectSpellClassMaskC_1
--     FROM spell_dbc WHERE ID IN (89937, 99064, 105744, 105797, 105907);
-- -------------------------------------------------------------------------
