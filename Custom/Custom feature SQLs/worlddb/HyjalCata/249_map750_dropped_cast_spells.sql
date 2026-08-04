-- ---------------------------------------------------------------------------
-- 249  Map 750 -- server-side downport of 10 Cataclysm combat-cast spells
-- ---------------------------------------------------------------------------
-- The SmartAI rows that 250_ re-imports cast ten spells that exist in neither
-- the server's binary Spell.dbc (verified against the LIVE worldserver's
-- data/dbc, 53,156 rows) nor the `spell_dbc` overlay (verified empty for all
-- ten) -- without these rows the core rejects those casts at load as
-- "unknown spell" and the SmartAI rows never run. All ten are used by the
-- 250_ re-imported combat casts:
--
--   80009  Serpent Sting       effects: E0=6/aura 3 (3000ms periodic Nature)
--   80012  Chimera Shot        effects: E0=77, E1=121, E2=31 (125% weapon)
--   80066  Tornado             effects: E0=28 summon 42895 / props 1761
--   80068  Thunderstorm        effects: E0=2 school dmg, E1=98 knockback
--   80546  Bile Blast          effects: E0=2 dmg, E1=6/aura 3 (5000ms DoT)
--   81020  Heave               effects: E0=2 dmg, E1=145 pull to dest (back)
--   87420  Shadowflame Blast   effects: E0=2 cone dmg (target 104)
--   89399  Release Wisp        effects: E0=3 dummy
--   91997  Shadow Bolt         effects: E0=2 Shadow dmg
--   91998  Throw Rock          effects: E0=2 Physical dmg
--
-- SOURCE -- K:\UntouchedClients\Cata, Data\enUS\locale-enUS.MPQ:
--     DBFilesClient\Spell.dbc        73,232 rows x 48 fields
--     DBFilesClient\SpellEffect.dbc  97,356 rows x 27 fields (SpellID at col 24,
--                                    EffectIndex at col 25)
-- Same method and column calibration as 194_ (see that file for how the 4.3.4
-- Spell.dbc layout was pinned empirically): col 1 = Attributes,
-- 12 = CastingTimeIndex, 13 = DurationIndex, 14 = PowerType, 15 = RangeIndex,
-- 16 = Speed, 17/18 = SpellVisualID, 19 = SpellIconID, 21 = Name,
-- 23 = Description, 25 = SchoolMask.
--
-- ONE DELIBERATE TRANSFORM: 3.3.5 computes an effect's value as
-- BasePoints + rand(1..DieSides); Cataclysm dropped DieSides entirely. Rows
-- below therefore carry DieSides = 1 and BasePoints = (cata value - 1), which
-- reproduces the same final amount under 3.3.5 rules; effects whose Cata value
-- is 0 keep BasePoints 0 / DieSides 0, exactly as 194_ did.
--
-- Cata attribute words ExH/ExI/ExJ are dropped -- those bits do not exist in
-- 3.3.5 (all ten spells carry zeroes there anyway, so nothing is lost).
-- ProcChance 101 and EquippedItemClass -1 are the 3.3.5 defaults. Every
-- extracted effect id is below 165, so nothing hits this fork's
-- effect-id >= 165 boot assert and no effect had to be clamped or dropped.
-- Every referenced index row (SpellCastTimes 1/4/5/14/18/19/20, SpellDuration
-- 1/8/28, SpellRange 1/2/4/5/14/54/114, SpellRadius 9/18/29/47,
-- SummonProperties 1761) was verified present in the live server's DBC set.
--
-- Two extraction notes:
--   * 80066 Tornado summons creature 42895 (the Cata Tornado NPC), which is
--     not in `creature_template` yet. The id is kept verbatim per the
--     embedded-ids convention (see clone-import rules); the summon is a no-op
--     that logs until a later layer imports that template.
--   * 80012 Chimera Shot's multi-line Cata tooltip was collapsed to its first
--     sentence -- descriptions are cosmetic and server-side only here.
--
-- Apply against acore_world, then restart worldserver. `spell_dbc` is a
-- server-side overlay, so NO client update is needed for the server to resolve
-- these; the client will not show icons/tooltips for them until Spell.dbc is
-- rebuilt, which is deliberate and separate (194_'s precedent). Idempotent.
-- ---------------------------------------------------------------------------

DELETE FROM `spell_dbc` WHERE `ID` IN (
  80009, 80012, 80066, 80068, 80546, 81020, 87420, 89399, 91997, 91998);

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
  (80009, 589826, 2048, 131072, 0, 0, 0, 0, 0, 18, 8, 0, 5, 40.0000, 3179, 0, 536, 0, 8, 101, -1, 'Serpent Sting', 'Stings the target, causing Nature damage over $d.', 6, 3, 3, 1, 3000, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (80012, 65538, 0, 131072, 0, 0, 0, 0, 0, 18, 0, 2, 114, 40.0000, 11725, 0, 3412, 0, 8, 101, -1, 'Chimera Shot', 'You deal $s3% weapon damage, refreshing the current Sting on your target and triggering an effect.', 77, 0, 0, 0, 0, 0, 0, 0, 0, 6, 0, 121, 0, 0, 0, 0, 0, 0, 0, 0, 6, 0, 31, 0, 124, 1, 0, 0, 0, 0, 0, 6, 0),
  (80066, 0, 0, 0, 0, 0, 0, 0, 0, 20, 28, 0, 4, 0.0000, 7967, 0, 3063, 0, 1, 101, -1, 'Tornado', 'Creates a Tornado under an enemy target.', 28, 0, 0, 0, 0, 42895, 1761, 0, 0, 53, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (80068, 524288, 136, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0000, 11718, 0, 2018, 0, 8, 101, -1, 'Thunderstorm', 'Call down a bolt of lightning damaging nearby enemies within $a1 yards. Deals Nature damage to all nearby enemies, knocking them back.', 2, 0, 22, 1, 0, 0, 0, 47, 0, 22, 15, 98, 0, 49, 1, 0, 75, 0, 18, 0, 22, 15, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (80546, 524288, 2048, 0, 0, 0, 0, 0, 0, 19, 1, 0, 4, 40.0000, 7910, 0, 68, 0, 8, 101, -1, 'Bile Blast', 'Shoots poison at an enemy, inflicting Nature damage, then additional damage every $t2 sec. for $d.', 2, 0, 11, 1, 0, 0, 0, 0, 0, 6, 0, 6, 3, 2, 1, 5000, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (81020, 786432, 0, 0, 0, 0, 0, 0, 0, 4, 0, 0, 2, 0.0000, 17135, 0, 4429, 0, 1, 101, -1, 'Heave', 'Deals damage and tosses the target over the caster''s shoulder.', 2, 0, 22, 1, 0, 0, 0, 0, 0, 6, 0, 145, 0, 74, 1, 0, 75, 0, 29, 0, 6, 48, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (87420, 524288, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 1, 0.0000, 18466, 0, 4068, 0, 36, 101, -1, 'Shadowflame Blast', 'Deals Shadowflame damage to enemies in front of the caster.', 2, 0, 31, 1, 0, 0, 0, 9, 0, 104, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (89399, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 14, 20.0000, 18986, 0, 1, 0, 1, 101, -1, 'Release Wisp', '', 3, 0, 0, 0, 0, 0, 0, 0, 0, 25, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (91997, 589824, 0, 0, 0, 0, 0, 0, 0, 14, 0, 0, 5, 24.0000, 64, 0, 213, 0, 32, 101, -1, 'Shadow Bolt', 'Hurls a bolt of dark magic at an enemy, inflicting Shadow damage.', 2, 0, 35, 1, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (91998, 4784144, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 54, 15.0000, 19395, 0, 2305, 0, 1, 101, -1, 'Throw Rock', 'Hurls a rock at an enemy, inflicting Physical damage.', 2, 0, 31, 1, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

-- ---------------------------------------------------------------------------
-- Verification after applying + worldserver restart:
--   SELECT ID, Name_Lang_enUS, Effect_1, EffectAura_1, EffectBasePoints_1,
--          EffectDieSides_1, EffectMiscValue_1
--     FROM spell_dbc WHERE ID IN (80009,80012,80066,80068,80546,81020,
--                                 87420,89399,91997,91998);   -- 10 rows
--
--   -- after 250_ lands: no smart_scripts cast (action 11) on these ids may
--   -- remain unresolved (expect 0):
--   SELECT COUNT(*) FROM smart_scripts s
--    WHERE s.action_type = 11
--      AND s.action_param1 IN (80009,80012,80066,80068,80546,81020,
--                              87420,89399,91997,91998)
--      AND NOT EXISTS (SELECT 1 FROM spell_dbc d WHERE d.ID = s.action_param1);
--
-- The boot log should no longer reject the 250_ SmartAI rows with
-- "Entry ... SourceType 0 Event ... Action 11 uses non-existent Spell entry
-- ..." for these ten ids.
-- ---------------------------------------------------------------------------
