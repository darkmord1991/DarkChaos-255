-- ---------------------------------------------------------------------------
-- 194  Map 750 -- the 10 spells the imported content references but lacks
-- ---------------------------------------------------------------------------
-- Found by scanning every spell the Darkshore/Felwood layers (189_-193_) point
-- at -- quest RewardSpell / RewardDisplaySpell / SourceSpellID, item spellid_1,
-- npc_spellclick_spells and smart_scripts -- and testing each against BOTH
-- sources, because `spell_dbc` is an OVERLAY on the binary Spell.dbc and a
-- spell counts as present if it is in either. Checking only the overlay
-- reports 742 false positives; the real answer is TEN:
--
--   62803  Ritual Bond Quest Complete         effects: E0=16/aura 0
--   64359  Ritual Bond                        effects: E0=6/aura 106, E1=6/aura 12, E2=77/aura 0
--   65310  Titan's Terminal Quest Complete    effects: E0=61/aura 0
--   65397  Eye of the Vortex - Detect Quest I effects: E0=6/aura 19
--   65399  Eye of the Vortex - Detect Quest I effects: E0=6/aura 19
--   65425  Eye of the Vortex - Detect Quest I effects: E0=6/aura 19
--   88254  Swipe Honey                        effects: E0=3/aura 0
--   88425  Bees! BEES!                        effects: E0=6/aura 89
--   88665  Ruumbo's Silly Dance               effects: E0=77/aura 0
--   94064  Bees!                              effects: E0=77/aura 0
--
-- Six are quest reward spells (the Darkshore "Spirit of the ..." line and the
-- Felwood chain); four are the CataTC Ruumbo scripts' spells, which together
-- with quest 27989/27995 (193_) and item 62820 (192_) finally make those three
-- scripts portable -- see 186_ where they were skipped as dead code.
--
-- Spells that were checked and are ALREADY FINE, so no row is minted for them
-- (minting one would override a correct stock spell globally):
--     61899 Force Reaction 1, 46598 Ride Vehicle Hardcoded,
--     56685 CSA Dummy Effect 1, 52225 Cosmetic - Infected Wounds, 37752 Stand
--
-- SOURCE -- K:\UntouchedClients\Cata, Data\enUS\locale-enUS.MPQ:
--     DBFilesClient\Spell.dbc        73,232 rows x 48 fields
--     DBFilesClient\SpellEffect.dbc  97,356 rows x 27 fields (SpellID at col 24,
--                                    EffectIndex at col 25)
-- Cataclysm split spell data out of Spell.dbc into per-aspect tables, so this is
-- NOT the verbatim copy that Item.db2 was. The 4.3.4 Spell.dbc column layout was
-- calibrated empirically against three spells that exist in BOTH versions
-- (52225, 37752, 46598) by matching known 3.3.5 values back to Cata columns:
--     col 1 = Attributes, 12 = CastingTimeIndex, 13 = DurationIndex,
--     15 = RangeIndex, 17/18 = SpellVisualID, 19 = SpellIconID, 21 = Name,
--     23 = Description, 25 = SchoolMask
-- 46598 was the disambiguator: its DurationIndex 21 and RangeIndex 152 are
-- distinctive enough to pin cols 13 and 15 exactly.
--
-- ONE DELIBERATE TRANSFORM: 3.3.5 computes an effect's value as
-- BasePoints + rand(1..DieSides); Cataclysm dropped DieSides entirely. Rows
-- below therefore carry DieSides = 1 and BasePoints = (cata value - 1), which
-- reproduces the same final amount under 3.3.5 rules. Copying Cata's value
-- straight into BasePoints with DieSides = 0 would be off by one.
--
-- Cata attribute words ExH/ExI/ExJ are dropped -- those bits do not exist in
-- 3.3.5. ProcChance 101 and EquippedItemClass -1 are the 3.3.5 defaults.
--
-- Apply against acore_world, then restart worldserver. `spell_dbc` is a
-- server-side overlay, so NO client update is needed for the server to resolve
-- these; the client will not show icons/tooltips for them until Spell.dbc is
-- rebuilt, which is deliberate and separate. Idempotent.
-- ---------------------------------------------------------------------------

DELETE FROM `spell_dbc` WHERE `ID` IN (
  62803, 64359, 65310, 65397, 65399, 65425, 88254, 88425, 88665, 94064);

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
     `SpellVisualID_1`,
     `SpellVisualID_2`,
     `SpellIconID`,
     `ActiveIconID`,
     `SchoolMask`,
     `ProcChance`,
     `EquippedItemClass`,
     `Name_Lang_enUS`,
     `Description_Lang_enUS`,
     `Effect_1`,`EffectAura_1`,`EffectBasePoints_1`,`EffectDieSides_1`,`EffectAuraPeriod_1`,`EffectMiscValue_1`,`EffectMiscValueB_1`,`EffectRadiusIndex_1`,`EffectTriggerSpell_1`,`ImplicitTargetA_1`,`ImplicitTargetB_1`,`Effect_2`,`EffectAura_2`,`EffectBasePoints_2`,`EffectDieSides_2`,`EffectAuraPeriod_2`,`EffectMiscValue_2`,`EffectMiscValueB_2`,`EffectRadiusIndex_2`,`EffectTriggerSpell_2`,`ImplicitTargetA_2`,`ImplicitTargetB_2`,`Effect_3`,`EffectAura_3`,`EffectBasePoints_3`,`EffectDieSides_3`,`EffectAuraPeriod_3`,`EffectMiscValue_3`,`EffectMiscValueB_3`,`EffectRadiusIndex_3`,`EffectTriggerSpell_3`,`ImplicitTargetA_3`,`ImplicitTargetB_3`)
VALUES
  (62803, 256, 0, 4, 268435712, 0, 0, 0, 0, 1, 0, 0, 13, 0.0000, 13608, 0, 2012, 0, 1, 101, -1, 'Ritual Bond Quest Complete', '', 16, 0, 0, 0, 0, 13569, 0, 0, 0, 25, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (64359, 687865856, 32, 16388, 268435456, 128, 8, 0, 0, 1, 165, 0, 13, 0.0000, 13614, 0, 220, 0, 1, 101, -1, 'Ritual Bond', 'Undergoing the binding.', 6, 106, 0, 0, 0, 0, 0, 0, 0, 25, 0, 6, 12, 0, 0, 0, 0, 0, 0, 0, 25, 0, 77, 0, 0, 0, 0, 0, 0, 0, 0, 25, 0),
  (65310, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0000, 0, 0, 1, 0, 1, 101, -1, 'Titan''s Terminal Quest Complete', '', 61, 0, 0, 0, 0, 21693, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (65397, 384, 0, 0, 0, 0, 0, 0, 0, 1, 21, 0, 5, 0.0000, 0, 0, 1, 0, 1, 101, -1, 'Eye of the Vortex - Detect Quest Invisibility 1', '', 6, 19, 99, 1, 0, 7, 0, 0, 0, 25, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (65399, 384, 0, 0, 0, 0, 0, 0, 0, 1, 21, 0, 5, 0.0000, 0, 0, 1, 0, 1, 101, -1, 'Eye of the Vortex - Detect Quest Invisibility 3', '', 6, 19, 99, 1, 0, 9, 0, 0, 0, 25, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (65425, 384, 0, 0, 0, 0, 0, 0, 0, 1, 21, 0, 5, 0.0000, 0, 0, 1, 0, 1, 101, -1, 'Eye of the Vortex - Detect Quest Invisibility 4', '', 6, 19, 99, 1, 0, 4, 0, 0, 0, 25, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (88254, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 2, 0.0000, 9659, 0, 1, 0, 1, 101, -1, 'Swipe Honey', 'Swipe a glob of honey from a glowing Deadwood Honey Hive.', 3, 0, 0, 0, 0, 0, 0, 0, 0, 38, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (88425, 218103808, 32, 540672, 0, 8193, 393224, 4608, 0, 1, 8, 0, 4, 0.0000, 18723, 0, 116, 0, 1, 101, -1, 'Bees! BEES!', 'Angry bees inflict $s1% damage per second. Jump into a nearby pool to get them off!', 6, 89, 1, 1, 1000, 0, 0, 0, 0, 25, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (88665, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0000, 4682, 0, 1610, 0, 1, 101, -1, 'Ruumbo''s Silly Dance', '', 77, 0, 0, 1, 0, 0, 0, 8, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (94064, 256, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 7, 0.0000, 0, 0, 1, 0, 1, 101, -1, 'Bees!', '', 77, 0, 0, 0, 0, 0, 0, 0, 0, 25, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

-- ---------------------------------------------------------------------------
-- Verification after applying + worldserver restart:
--   SELECT ID, Name_Lang_enUS, Effect_1, EffectAura_1, EffectBasePoints_1,
--          EffectDieSides_1, EffectMiscValue_1
--     FROM spell_dbc WHERE ID IN (62803,64359,65310,65397,65399,65425,
--                                 88254,88425,88665,94064);   -- 10 rows
--
--   -- no quest on map 750 rewards a spell that does not resolve (expect 0):
--   SELECT COUNT(*) FROM quest_template q
--    WHERE q.QuestSortID IN (148,361) AND q.RewardSpell > 0
--      AND NOT EXISTS (SELECT 1 FROM spell_dbc d WHERE d.ID = q.RewardSpell);
--
-- The boot log should no longer report "Quest ... has RewardSpell ... does not
-- exist" for the 13xxx / 27xxx-29xxx quest ranges.
-- ---------------------------------------------------------------------------
