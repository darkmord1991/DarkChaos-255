-- -------------------------------------------------------------------------
-- Cataclysm item sets, script batch 2 -- three more sets
-- -------------------------------------------------------------------------
-- Three sets whose bonuses need the C++ in
--     src/server/scripts/DC/ItemSets/dc_cata_itemset_bonuses.cpp
-- (batch 2: spell_dc_rogue_t13_2p, spell_dc_dk_t13_blood_2p,
--  spell_dc_druid_t12_resto_4p). Applied without that build the dummy bonuses do
-- nothing -- they do not error -- so this is safe to apply early but inert until
-- the worldserver carrying those scripts is running.
--
--   1004 Obsidian Arborweave Vestments -- COMPLETE. 2pc is a plain proc (data);
--        4pc "Swiftmend also heals an injured target within 15 yards for the same
--        amount" is scripted -- the second heal is dealt for exactly the amount the
--        original landed for, because Blizzard ships no spell for it.
--
--   1068 Blackfang Battleweave -- COMPLETE. 2pc "after Tricks of the Trade your
--        abilities cost less energy" fires Tricks of Time 105864, which carries the
--        actual MOD_POWER_COST_SCHOOL_PCT. 105864 is named only in the tooltip
--        text, never linked through EffectTriggerSpell, so it is minted here even
--        though nothing in the DBC references it. 4pc is pure data.
--
--   1056 Necrotic Boneplate Armor -- PARTIAL. 2pc "when an attack drops your health
--        below 35% a Blood Rune activates" is scripted, and deliberately fires only
--        on the hit that CROSSES the threshold (health before vs after), so it does
--        not re-trigger on every swing while already low. The 4pc ("Vampiric Blood
--        also affects your raid") is NOT implemented -- it needs a raid-wide version
--        of Vampiric Blood that does not exist -- so that half stays inert.
--
-- The 35% threshold is read from the aura effect amount, not hardcoded.
--
-- Apply after 01/06. Idempotent.
-- -------------------------------------------------------------------------

-- -------------------------------------------------------------------------
-- 1. Spells (9)
-- -------------------------------------------------------------------------

DELETE FROM `spell_dbc` WHERE `ID` IN (
  99007, 99013, 99015, 105552, 105582, 105587, 105849, 105864, 105865);

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
  (99007, 0, 0, 0, 262144, 32768, 0, 0, 0, 1, 0, 0, 6, 0.0, 0, 101, 0, 0, 0, 0, 1923, 0, 1, -1, 0, 0, 0, 0, 'Heartfire', 'Grants you $s1% of your base mana.', 30, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99013, 192, 0, 0, 67108864, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 262144, 40, 0, 0, 0, 0, 1, 0, 1, -1, 7, 0, 0, 0, 'Item - Druid T12 Restoration 2P Bonus', 'Your periodic healing from Lifebloom has a $h% chance to restore $99007s1% of your base mana each time it heals a target.', 6, 42, 0, 1, 0, 8, 0, 0, 99007, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99015, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 16384, 100, 0, 0, 0, 0, 1, 0, 1, -1, 7, 0, 0, 0, 'Item - Druid T12 Restoration 4P Bonus', 'Your Swiftmend also heals an injured target within 15 yards for the same amount.', 6, 4, 0, 1, 0, 8, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105552, 192, 0, 0, 67108864, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 666280, 100, 0, 0, 0, 0, 1, 0, 1, -1, 15, 0, 0, 0, 'Item - Death Knight T13 Blood 2P Bonus', 'When an attack drops your health below $s1%, one of your Blood Runes will immediately activate and convert into a Death Rune for the next $105582d. This effect cannot occur more than once every $s2 sec.', 6, 42, 34, 1, 0, 0, 0, 0, 105582, 1, 0, 0, 0, 0, 16, 0, 4, 3, 0, 44, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105582, 0, 1024, 33554432, 0, 0, 0, 0, 0, 1, 18, -2, 1, 0.0, 0, 101, 0, 0, 11149, 0, 694, 0, 1, -1, 0, 8, 0, 0, 'Kiss of Death', 'Immediately activates a Blood Rune and converts it into a Death Rune for the next $d.  Death Runes count as a Blood, Frost or Unholy Rune.', 146, 0, 0, 1, 0, 3, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 6, 249, 0, 1, 0, 0, 3, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105587, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 15, 0, 0, 0, 'Item - Death Knight T13 Blood 4P Bonus', 'Your Vampiric Blood ability also affects all party and raid members for $s1% of the effect it has on you.', 6, 4, 49, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 3, 0, 44, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105849, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 8, 0, 0, 0, 'Item - Rogue T13 2P Bonus (Tricks of the Trade)', 'After triggering Tricks of the Trade, your abilities cost $105864s1% less energy for $105864d.', 6, 4, 34, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105864, 262144, 1024, 0, 0, 0, 0, 0, 0, 1, 32, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 5682, 0, 8, -1, 7, 0, 0, 0, 'Tricks of Time', 'Your abilities cost $s1% less energy for $d after triggering Tricks of the Trade.', 6, 72, -21, 1, 0, 127, 8, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105865, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 8, 0, 0, 0, 'Item - Rogue T13 4P Bonus (Shadow Dance, Adrenaline Rush, and Vendetta)', 'Increases the duration of Shadow Dance by ${$m1/1000} sec, Adrenaline Rush by ${$m2/1000} sec, and Vendetta by ${$m3/1000} sec.', 6, 107, 1999, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 33554432, 0, 6, 107, 2999, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 128, 0, 6, 107, 8999, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0);

-- -------------------------------------------------------------------------
-- 2. Bind the scripts to their spells
-- -------------------------------------------------------------------------
-- Without these rows the C++ never runs: ObjectMgr::LoadSpellScriptNames is what
-- attaches a named script to a spell id. 49028 and 2565 are STOCK spells -- the
-- scripts on them are gated on the set bonus aura and change nothing otherwise.
-- -------------------------------------------------------------------------

DELETE FROM `spell_script_names` WHERE `ScriptName` IN (
  'spell_dc_rogue_t13_2p',
  'spell_dc_dk_t13_blood_2p',
  'spell_dc_druid_t12_resto_4p');

--   105849 spell_dc_rogue_t13_2p            Tricks of the Trade -> Tricks of Time
--   105552 spell_dc_dk_t13_blood_2p         health crosses 35% -> Kiss of Death
--   99015  spell_dc_druid_t12_resto_4p      Swiftmend -> second heal on a nearby ally
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
  (105849, 'spell_dc_rogue_t13_2p'),
  (105552, 'spell_dc_dk_t13_blood_2p'),
  (99015, 'spell_dc_druid_t12_resto_4p');

-- -------------------------------------------------------------------------
-- 3. The three sets
-- -------------------------------------------------------------------------

DELETE FROM `itemset_dbc` WHERE `ID` IN (1004, 1056, 1068);

INSERT INTO `itemset_dbc`
    (`ID`, `Name_Lang_enUS`, `Name_Lang_enGB`, `Name_Lang_koKR`, `Name_Lang_frFR`, `Name_Lang_deDE`, `Name_Lang_enCN`, `Name_Lang_zhCN`, `Name_Lang_enTW`, `Name_Lang_zhTW`, `Name_Lang_esES`, `Name_Lang_esMX`, `Name_Lang_ruRU`, `Name_Lang_ptPT`, `Name_Lang_ptBR`, `Name_Lang_itIT`, `Name_Lang_Unk`, `Name_Lang_Mask`, `ItemID_1`, `ItemID_2`, `ItemID_3`, `ItemID_4`, `ItemID_5`, `ItemID_6`, `ItemID_7`, `ItemID_8`, `ItemID_9`, `ItemID_10`, `ItemID_11`, `ItemID_12`, `ItemID_13`, `ItemID_14`, `ItemID_15`, `ItemID_16`, `ItemID_17`, `SetSpellID_1`, `SetSpellID_2`, `SetSpellID_3`, `SetSpellID_4`, `SetSpellID_5`, `SetSpellID_6`, `SetSpellID_7`, `SetSpellID_8`, `SetThreshold_1`, `SetThreshold_2`, `SetThreshold_3`, `SetThreshold_4`, `SetThreshold_5`, `SetThreshold_6`, `SetThreshold_7`, `SetThreshold_8`, `RequiredSkill`, `RequiredSkillRank`)
VALUES
  (1004, 'Obsidian Arborweave Vestments', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 71102, 71103, 71104, 71105, 71106, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 99013, 99015, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (1056, 'Necrotic Boneplate Armor', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 77008, 77009, 77010, 77011, 77012, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 105552, 105587, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (1068, 'Blackfang Battleweave', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 77023, 77024, 77025, 77026, 77027, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 105849, 105865, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0);

-- -------------------------------------------------------------------------
-- 4. Wire the item shells
-- -------------------------------------------------------------------------

-- Obsidian Arborweave Vestments
UPDATE `item_template` SET `itemset` = 1004 WHERE `entry` IN (71102, 71103, 71104, 71105, 71106);
-- Necrotic Boneplate Armor
UPDATE `item_template` SET `itemset` = 1056 WHERE `entry` IN (77008, 77009, 77010, 77011, 77012);
-- Blackfang Battleweave
UPDATE `item_template` SET `itemset` = 1068 WHERE `entry` IN (77023, 77024, 77025, 77026, 77027);

-- -------------------------------------------------------------------------
-- Verification
-- -------------------------------------------------------------------------
--   SELECT COUNT(*) FROM itemset_dbc;                     -- 62
--   SELECT COUNT(*) FROM spell_script_names
--    WHERE ScriptName LIKE 'spell_dc_%_t12_%';           -- 7
--
--   -- the boot log must not report an unknown script name for any of these;
--   -- "Spell script name X not assigned to a spell" means the build is missing.
-- -------------------------------------------------------------------------
