-- -------------------------------------------------------------------------
-- Cataclysm item sets, script batch 3 -- the two Immolation sets (Paladin)
-- -------------------------------------------------------------------------
-- Two Paladin T12 sets. Their scripts reuse templates already in
--     src/server/scripts/DC/ItemSets/dc_cata_itemset_bonuses.cpp
-- so nothing new was invented for them structurally -- only the ability each one
-- keys off had to be chosen. NEEDS THAT BUILD; without it the dummy halves are
-- inert but harmless.
--
--   1011 Regalia of Immolation (Holy) -- COMPLETE
--        2pc is a plain proc (data). 4pc "your Divine Light, Flash of Light and
--        Holy Light also heal an injured target within 15 yards for the same
--        amount". DIVINE LIGHT DOES NOT EXIST in 3.3.5, so the filter is Flash of
--        Light | Holy Light (0xC0000000), verified to hit exactly those two. Losing
--        Divine Light costs nothing here -- it was the Cataclysm replacement for
--        Holy Light, so the same button is still covered.
--
--   1013 Battlearmor of Immolation (Protection) -- COMPLETE
--        2pc "your Shield of the Righteous deals 20% additional damage as Fire".
--        SHIELD OF THE RIGHTEOUS IS CATACLYSM-ONLY -> retargeted to HAMMER OF THE
--        RIGHTEOUS, the 3.3.5 Protection strike that occupies the same slot in the
--        rotation. No rescale: 20% of a comparable ability is the same bonus.
--        4pc "when your Divine Protection expires you gain 12% parry" needed NO
--        adaptation at all -- Divine Protection (498) and its parry buff both exist,
--        so this is a straight reuse of the expiry template, gated on the set aura
--        so it is a no-op for paladins not wearing it.
--
-- Flaming Aegis (99090) is minted below although nothing in the DBC references it:
-- like the other expiry buffs, the script names it directly.
--
-- Apply after 01/06. Idempotent.
-- -------------------------------------------------------------------------

-- -------------------------------------------------------------------------
-- 1. Spells (6)
-- -------------------------------------------------------------------------

DELETE FROM `spell_dbc` WHERE `ID` IN (
  99067, 99069, 99070, 99074, 99090, 99091);

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
  (99067, 192, 0, 0, 67108864, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 16384, 40, 0, 0, 0, 0, 1, 0, 1, -1, 10, 0, 0, 0, 'Item - Paladin T12 Holy 2P Bonus', 'Healing with Holy Shock has a $h% chance to grant you $99069s1% of your base mana.', 6, 42, 2, 1, 0, 0, 0, 0, 99069, 1, 0, 0, 0, 0, 8389632, 4194312, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99069, 0, 0, 0, 262144, 32768, 0, 0, 0, 1, 0, 0, 6, 0.0, 0, 101, 0, 0, 0, 0, 2176, 0, 1, -1, 0, 0, 0, 0, 'Fires of Heaven', 'Grants you $s1% of your base mana.', 30, 0, 5, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99070, 192, 0, 0, 67108864, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 16384, 100, 0, 0, 0, 0, 1, 0, 1, -1, 10, 0, 0, 0, 'Item - Paladin T12 Holy 4P Bonus', 'Your Divine Light, Flash of Light, and Holy Light spells also heal an injured target within 15 yards for $s1% of the amount healed.', 6, 4, 9, 1, 0, 17, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99074, 192, 0, 0, 67108864, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 16, 100, 0, 0, 0, 0, 1, 0, 1, -1, 10, 0, 0, 0, 'Item - Paladin T12 Protection 2P Bonus', 'Your Shield of the Righteous deals $s1% additional damage as Fire damage.', 6, 4, 19, 1, 0, 8, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99090, 2147811344, 0, 0, 0, 0, 256, 67108864, 268435456, 1, 1, 5, 1, 0.0, 0, 101, 0, 0, 0, 0, 2007, 0, 1, -1, 0, 0, 1073741824, 0, 'Flaming Aegis', 'Increases Parry chance by $s1% for $d after Divine Protection expires.', 6, 47, 11, 1, 0, 6, 0, 11, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99091, 192, 0, 0, 67108864, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 10, 0, 0, 0, 'Item - Paladin T12 Protection 4P Bonus', 'When your Divine Protection expires, you gain an additional $99090s1% parry chance for $99090d .', 6, 4, 11, 1, 0, 8, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

-- -------------------------------------------------------------------------
-- 2. Bind the scripts to their spells
-- -------------------------------------------------------------------------
-- Without these rows the C++ never runs: ObjectMgr::LoadSpellScriptNames is what
-- attaches a named script to a spell id. 49028 and 2565 are STOCK spells -- the
-- scripts on them are gated on the set bonus aura and change nothing otherwise.
-- -------------------------------------------------------------------------

DELETE FROM `spell_script_names` WHERE `ScriptName` IN (
  'spell_dc_paladin_t12_holy_4p',
  'spell_dc_paladin_t12_prot_2p',
  'spell_dc_paladin_t12_prot_4p');

--   99070  spell_dc_paladin_t12_holy_4p     Flash of Light / Holy Light -> second heal
--   99074  spell_dc_paladin_t12_prot_2p     Hammer of the Righteous -> instant fire
--   498    spell_dc_paladin_t12_prot_4p     Divine Protection expiry -> Flaming Aegis
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
  (99070, 'spell_dc_paladin_t12_holy_4p'),
  (99074, 'spell_dc_paladin_t12_prot_2p'),
  (498, 'spell_dc_paladin_t12_prot_4p');

-- -------------------------------------------------------------------------
-- 3. The two sets
-- -------------------------------------------------------------------------

DELETE FROM `itemset_dbc` WHERE `ID` IN (1011, 1013);

INSERT INTO `itemset_dbc`
    (`ID`, `Name_Lang_enUS`, `Name_Lang_enGB`, `Name_Lang_koKR`, `Name_Lang_frFR`, `Name_Lang_deDE`, `Name_Lang_enCN`, `Name_Lang_zhCN`, `Name_Lang_enTW`, `Name_Lang_zhTW`, `Name_Lang_esES`, `Name_Lang_esMX`, `Name_Lang_ruRU`, `Name_Lang_ptPT`, `Name_Lang_ptBR`, `Name_Lang_itIT`, `Name_Lang_Unk`, `Name_Lang_Mask`, `ItemID_1`, `ItemID_2`, `ItemID_3`, `ItemID_4`, `ItemID_5`, `ItemID_6`, `ItemID_7`, `ItemID_8`, `ItemID_9`, `ItemID_10`, `ItemID_11`, `ItemID_12`, `ItemID_13`, `ItemID_14`, `ItemID_15`, `ItemID_16`, `ItemID_17`, `SetSpellID_1`, `SetSpellID_2`, `SetSpellID_3`, `SetSpellID_4`, `SetSpellID_5`, `SetSpellID_6`, `SetSpellID_7`, `SetSpellID_8`, `SetThreshold_1`, `SetThreshold_2`, `SetThreshold_3`, `SetThreshold_4`, `SetThreshold_5`, `SetThreshold_6`, `SetThreshold_7`, `SetThreshold_8`, `RequiredSkill`, `RequiredSkillRank`)
VALUES
  (1011, 'Regalia of Immolation', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 71095, 71094, 71093, 71092, 71091, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 99067, 99070, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (1013, 'Battlearmor of Immolation', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 70946, 70947, 70948, 70949, 70950, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 99074, 99091, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0);

-- -------------------------------------------------------------------------
-- 4. Wire the item shells
-- -------------------------------------------------------------------------

-- Regalia of Immolation
UPDATE `item_template` SET `itemset` = 1011 WHERE `entry` IN (71091, 71092, 71093, 71094, 71095);
-- Battlearmor of Immolation
UPDATE `item_template` SET `itemset` = 1013 WHERE `entry` IN (70946, 70947, 70948, 70949, 70950);

-- -------------------------------------------------------------------------
-- Verification
-- -------------------------------------------------------------------------
--   SELECT COUNT(*) FROM itemset_dbc;                     -- 68
--   SELECT COUNT(*) FROM spell_script_names
--    WHERE ScriptName LIKE 'spell_dc_%_t12_%';           -- 7
--
--   -- the boot log must not report an unknown script name for any of these;
--   -- "Spell script name X not assigned to a spell" means the build is missing.
-- -------------------------------------------------------------------------
