-- -------------------------------------------------------------------------
-- Cataclysm Tier 12 sets, batch 1 -- the first with C++ behind them
-- -------------------------------------------------------------------------
-- Six T12 sets whose bonuses carry SPELL_AURA_DUMMY and so cannot work from data
-- alone. The scripts live in
--     src/server/scripts/DC/ItemSets/dc_cata_itemset_bonuses.cpp
-- registered from dc_script_loader.cpp. THIS FILE NEEDS THAT BUILD -- applied
-- against a worldserver without it, the dummy bonuses simply do nothing (they do
-- not error), so it is safe to apply early but pointless until the build lands.
--
-- Two script families:
--   * "<ability> deals N% additional damage as Fire over 4 sec" -- Crusader Strike,
--     Shield Slam, Mangle/Maul/Shred, and Rogue melee crits. Cataclysm never links
--     the damage-over-time spell through EffectTriggerSpell (the id is only in the
--     tooltip), so the script names it: Flames of the Faithful 99092, Combust 99240,
--     Fiery Claws 99002, Burning Wounds 99173. Those four are minted below even
--     though nothing in the DBC references them.
--   * "when <buff> expires you gain parry" -- Dancing Rune Weapon and Shield Block.
--     The script attaches to the STOCK aura (49028 / 2565) because that is what
--     expires, and is gated on the player having the set bonus, so it is a no-op
--     for everyone else.
--
-- The percentage each script applies is read from the aura effect amount, NOT
-- hardcoded -- retuning any of these is a spell_dbc edit, not a rebuild.
--
-- STILL PARTIAL after this file:
--   1002 Obsidian Arborweave Battlegarb -- 2pc works, 4pc (finishing moves extend
--        Berserk) still needs a script.
--   1006 Vestments of the Dark Phoenix  -- 2pc works, 4pc (Tricks of the Trade)
--        still needs a script.
-- The other four are complete.
--
-- Apply after 01/06. Idempotent.
-- -------------------------------------------------------------------------

-- -------------------------------------------------------------------------
-- 1. Spells (20)
-- -------------------------------------------------------------------------

DELETE FROM `spell_dbc` WHERE `ID` IN (
  98956, 98957, 98966, 98970, 98971, 98996, 99001, 99002, 99009, 99092,
  99093, 99116, 99173, 99174, 99175, 99239, 99240, 99242, 99243, 101162);

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
  (98956, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 20, 100, 0, 0, 0, 0, 1, 0, 1, -1, 15, 0, 0, 0, 'Item - Death Knight T12 Blood 2P Bonus', 'Your melee attacks cause Burning Blood on your target, which deals $98957s1 Fire damage every $98957t1 sec for $98957d and causes your abilities to behave as if you had 2 diseases present on the target.', 6, 42, 4, 1, 0, 0, 0, 0, 98957, 1, 0, 0, 0, 0, 16, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (98957, 16, 0, 4, 262144, 8388608, 0, 0, 0, 1, 32, 5, 13, 0.0, 0, 101, 0, 0, 0, 0, 2968, 0, 4, -1, 15, 0, 0, 0, 'Burning Blood', 'Deals Fire damage every $t1 sec for $d.  Causes owning Death Knight''s abilities to treat the target as if it had 2 diseases active.', 6, 3, 799, 1, 2000, 127, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (98966, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 20, 100, 0, 0, 0, 0, 1, 0, 1, -1, 15, 0, 0, 0, 'Item - Death Knight T12 Blood 4P Bonus', 'When your Dancing Rune Weapon expires, you gain $101162s1% additional parry chance for $101162d.', 6, 4, 14, 1, 0, 8, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (98970, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 17424, 100, 0, 0, 0, 0, 1, 0, 1, -1, 15, 0, 0, 0, 'Item - Death Knight T12 DPS 2P Bonus', 'Your Horn of Winter ability also grants you $98971s1 runic power every $98971t1 sec for $98971d.', 6, 42, 2, 1, 0, 8, 0, 0, 98971, 1, 0, 0, 0, 0, 1073741824, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (98971, 327696, 0, 0, 0, 0, 256, 67108864, 268435456, 1, 4, 5, 1, 0.0, 0, 101, 0, 0, 0, 0, 3878, 0, 1, -1, 0, 0, 1073741824, 0, 'Smoldering Rune', 'Grants $s1 runic power every $t1 sec for $d.', 6, 226, 2, 1, 5000, 6, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (98996, 192, 0, 0, 67108864, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 16, 100, 0, 0, 0, 0, 1, 0, 1, -1, 15, 0, 0, 0, 'Item - Death Knight T12 DPS 4P Bonus', 'Your Obliterate and Scourge Strike abilities instantly deal $s1% additional damage as Fire damage.', 6, 4, 5, 1, 0, 8, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99001, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 16, 100, 0, 0, 0, 0, 1, 0, 1, -1, 7, 0, 0, 0, 'Item - Druid T12 Feral 2P Bonus', 'Your attacks with Mangle, Maul, and Shred deal $s1% additional damage as Fire damage over $99002d.', 6, 4, 9, 1, 0, 8, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99002, 8388608, 136, 536870916, 268697600, 1081728, 8388608, 536870912, 0, 1, 35, 0, 13, 0.0, 0, 101, 0, 0, 2638, 0, 5400, 0, 4, -1, 0, 134217728, 0, 8, 'Fiery Claws', 'Your attacks with Mangle, Maul, and Shred cause your target to burn for an additional percentage of your attack''s damage over $d.', 6, 3, -1, 1, 2000, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99009, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 7, 0, 0, 0, 'Item - Druid T12 Feral 4P Bonus', 'Your finishing moves have a 20% chance per combo point to extend the duration of Berserk by $s1 sec and when your Barkskin ability expires you gain an additional $99011s1% chance to dodge for $99011d.', 6, 4, 1, 1, 0, 8, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99092, 8388608, 136, 536870916, 268697600, 1081728, 8388608, 536870912, 0, 1, 35, 0, 13, 0.0, 0, 101, 0, 0, 2638, 0, 33, 0, 4, -1, 0, 134217728, 0, 8, 'Flames of the Faithful', 'Your attacks with Crusader Strike cause your target to burn for an additional percentage of your attack''s damage over $d.', 6, 3, -1, 1, 2000, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99093, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 16, 100, 0, 0, 0, 0, 1, 0, 1, -1, 10, 0, 0, 0, 'Item - Paladin T12 Retribution 2P Bonus', 'Your Crusader Strike deals $s1% additional damage as Fire damage over $99092d.', 6, 4, 14, 1, 0, 8, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99116, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 10, 0, 0, 0, 'Item - Paladin T12 Retribution 4P Bonus', 'Increases the duration of your Zealotry ability by ${$m1/1000} sec.', 6, 107, 14999, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99173, 8388608, 136, 536870916, 268697600, 1081728, 8388608, 536870912, 0, 1, 35, 0, 13, 0.0, 0, 101, 0, 0, 2638, 0, 2128, 0, 4, -1, 0, 134217728, 0, 8, 'Burning Wounds', 'Your melee critical strikes deal $s1% additional damage as Fire over $d.', 6, 3, 5, 1, 2000, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99174, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 20, 100, 0, 0, 0, 0, 1, 0, 1, -1, 7, 0, 0, 0, 'Item - Rogue T12 2P Bonus', 'Your melee critical strikes deal $99173s1% additional damage as Fire over $99173d.', 6, 4, 9, 1, 0, 8, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99175, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 17424, 100, 0, 0, 0, 0, 1, 0, 1, -1, 8, 0, 0, 0, 'Item - Rogue T12 4P Bonus', 'Your Tricks of the Trade ability also causes you to gain a $s1% increase to one of your combat ratings at random for $99187d.', 6, 4, 24, 1, 0, 8, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99239, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 16, 100, 0, 0, 0, 0, 1, 0, 1, -1, 4, 0, 0, 0, 'Item - Warrior T12 Protection 2P Bonus', 'Your Shield Slam deals $s1% additional damage as Fire damage over $99240d.', 6, 4, 19, 1, 0, 8, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99240, 8388608, 136, 536870916, 1879310336, 1081728, 8388608, 536870912, 0, 1, 35, 0, 13, 0.0, 0, 101, 0, 0, 2638, 0, 18, 0, 4, -1, 0, 134217728, 0, 8, 'Combust', 'Your Shield Slam deals $99239s1% additional damage as Fire damage over $d.', 6, 3, -1, 1, 2000, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99242, 192, 0, 0, 67108864, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 4, 0, 0, 0, 'Item - Warrior T12 Protection 4P Bonus', 'When your Shield Block expires, your parry chance is increased by $99243s1% for $99243d.', 6, 4, 5, 1, 0, 8, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99243, 2147811344, 0, 0, 0, 0, 256, 67108864, 268435456, 1, 1, 5, 1, 0.0, 0, 101, 0, 0, 0, 0, 37, 0, 1, -1, 0, 0, 1073741824, 0, 'Flame Wall', 'Increases Parry chance by $s1% for $d after Shield Block expires.', 6, 47, 5, 1, 0, 6, 0, 11, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (101162, 2147811344, 0, 0, 0, 0, 256, 67108864, 0, 1, 29, 5, 1, 0.0, 0, 101, 0, 0, 0, 0, 5571, 0, 1, -1, 0, 0, 1073741824, 0, 'Flaming Rune Weapon', 'Increases parry chance by $s1% for $d after Dancing Rune Weapon expires.', 6, 47, 14, 1, 0, 6, 0, 11, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

-- -------------------------------------------------------------------------
-- 2. Bind the scripts to their spells
-- -------------------------------------------------------------------------
-- Without these rows the C++ never runs: ObjectMgr::LoadSpellScriptNames is what
-- attaches a named script to a spell id. 49028 and 2565 are STOCK spells -- the
-- scripts on them are gated on the set bonus aura and change nothing otherwise.
-- -------------------------------------------------------------------------

DELETE FROM `spell_script_names` WHERE `ScriptName` IN (
  'spell_dc_paladin_t12_ret_2p',
  'spell_dc_warrior_t12_prot_2p',
  'spell_dc_druid_t12_feral_2p',
  'spell_dc_rogue_t12_2p',
  'spell_dc_dk_t12_dps_4p',
  'spell_dc_dk_t12_blood_4p',
  'spell_dc_warrior_t12_prot_4p');

--   99093  spell_dc_paladin_t12_ret_2p      Crusader Strike -> Flames of the Faithful
--   99239  spell_dc_warrior_t12_prot_2p     Shield Slam -> Combust
--   99001  spell_dc_druid_t12_feral_2p      Mangle / Maul / Shred -> Fiery Claws
--   99174  spell_dc_rogue_t12_2p            melee crits -> Burning Wounds
--   98996  spell_dc_dk_t12_dps_4p           Obliterate / Scourge Strike -> instant fire
--   49028  spell_dc_dk_t12_blood_4p         Dancing Rune Weapon expiry -> Flaming Rune Weapon
--   2565   spell_dc_warrior_t12_prot_4p     Shield Block expiry -> Flame Wall
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
  (99093, 'spell_dc_paladin_t12_ret_2p'),
  (99239, 'spell_dc_warrior_t12_prot_2p'),
  (99001, 'spell_dc_druid_t12_feral_2p'),
  (99174, 'spell_dc_rogue_t12_2p'),
  (98996, 'spell_dc_dk_t12_dps_4p'),
  (49028, 'spell_dc_dk_t12_blood_4p'),
  (2565, 'spell_dc_warrior_t12_prot_4p');

-- -------------------------------------------------------------------------
-- 3. The six sets
-- -------------------------------------------------------------------------

DELETE FROM `itemset_dbc` WHERE `ID` IN (1000, 1001, 1002, 1006, 1012, 1018);

INSERT INTO `itemset_dbc`
    (`ID`, `Name_Lang_enUS`, `Name_Lang_enGB`, `Name_Lang_koKR`, `Name_Lang_frFR`, `Name_Lang_deDE`, `Name_Lang_enCN`, `Name_Lang_zhCN`, `Name_Lang_enTW`, `Name_Lang_zhTW`, `Name_Lang_esES`, `Name_Lang_esMX`, `Name_Lang_ruRU`, `Name_Lang_ptPT`, `Name_Lang_ptBR`, `Name_Lang_itIT`, `Name_Lang_Unk`, `Name_Lang_Mask`, `ItemID_1`, `ItemID_2`, `ItemID_3`, `ItemID_4`, `ItemID_5`, `ItemID_6`, `ItemID_7`, `ItemID_8`, `ItemID_9`, `ItemID_10`, `ItemID_11`, `ItemID_12`, `ItemID_13`, `ItemID_14`, `ItemID_15`, `ItemID_16`, `ItemID_17`, `SetSpellID_1`, `SetSpellID_2`, `SetSpellID_3`, `SetSpellID_4`, `SetSpellID_5`, `SetSpellID_6`, `SetSpellID_7`, `SetSpellID_8`, `SetThreshold_1`, `SetThreshold_2`, `SetThreshold_3`, `SetThreshold_4`, `SetThreshold_5`, `SetThreshold_6`, `SetThreshold_7`, `SetThreshold_8`, `RequiredSkill`, `RequiredSkillRank`)
VALUES
  (1000, 'Elementium Deathplate Battlegear', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 71058, 71059, 71060, 71061, 71062, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 98970, 98996, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (1001, 'Elementium Deathplate Battlearmor', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 70951, 70952, 70953, 70954, 70955, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 98956, 98966, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (1002, 'Obsidian Arborweave Battlegarb', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 71097, 71098, 71099, 71100, 71101, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 99001, 99009, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (1006, 'Vestments of the Dark Phoenix', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 71045, 71046, 71047, 71048, 71049, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 99174, 99175, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (1012, 'Battleplate of Immolation', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 71067, 71066, 71065, 71064, 71063, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 99093, 99116, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (1018, 'Molten Giant Battleplate', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 70941, 70942, 70944, 70943, 70945, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 99239, 99242, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0);

-- -------------------------------------------------------------------------
-- 4. Wire the item shells
-- -------------------------------------------------------------------------

-- Elementium Deathplate Battlegear
UPDATE `item_template` SET `itemset` = 1000 WHERE `entry` IN (71058, 71059, 71060, 71061, 71062);
-- Elementium Deathplate Battlearmor
UPDATE `item_template` SET `itemset` = 1001 WHERE `entry` IN (70951, 70952, 70953, 70954, 70955);
-- Obsidian Arborweave Battlegarb
UPDATE `item_template` SET `itemset` = 1002 WHERE `entry` IN (71097, 71098, 71099, 71100, 71101);
-- Vestments of the Dark Phoenix
UPDATE `item_template` SET `itemset` = 1006 WHERE `entry` IN (71045, 71046, 71047, 71048, 71049);
-- Battleplate of Immolation
UPDATE `item_template` SET `itemset` = 1012 WHERE `entry` IN (71063, 71064, 71065, 71066, 71067);
-- Molten Giant Battleplate
UPDATE `item_template` SET `itemset` = 1018 WHERE `entry` IN (70941, 70942, 70943, 70944, 70945);

-- -------------------------------------------------------------------------
-- Verification
-- -------------------------------------------------------------------------
--   SELECT COUNT(*) FROM itemset_dbc;                     -- 59
--   SELECT COUNT(*) FROM spell_script_names
--    WHERE ScriptName LIKE 'spell_dc_%_t12_%';           -- 7
--
--   -- the boot log must not report an unknown script name for any of these;
--   -- "Spell script name X not assigned to a spell" means the build is missing.
-- -------------------------------------------------------------------------
