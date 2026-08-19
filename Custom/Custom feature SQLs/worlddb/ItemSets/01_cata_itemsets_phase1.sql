-- -------------------------------------------------------------------------
-- Cataclysm item sets, phase 1 -- the 45 sets that need no C++ script
-- -------------------------------------------------------------------------
-- Adds the Cataclysm item sets whose every set-bonus spell is reproducible from
-- DATA ALONE under 3.3.5 rules, wires the already-present item shells to them,
-- and mints the 68 bonus spells that do not yet resolve.
--
-- SOURCE -- K:\UntouchedClients\Cata, Data\enUS\locale-enUS.MPQ with the
-- wow-update-enUS-15211/15354/15595 patch chain applied via SFileOpenPatchArchive.
-- The update archives hold StormLib PTCH deltas, NOT whole files: extracting one
-- standalone yields a 135 KB "Spell.dbc" against the 17 MB base. Patched sizes:
--     ItemSet.dbc             600 rows x 37 fields  (no patch; same as base)
--     Spell.dbc            73,253 rows x 48 fields
--     SpellEffect.dbc      97,388 rows x 27 fields
--     SpellAuraOptions.dbc  6,145 rows x  5 fields
--     SpellClassOptions.dbc 9,050 rows x  7 fields
--
-- Cataclysm split spell data out of Spell.dbc into per-aspect tables, so the
-- column layout was calibrated empirically, not guessed:
--   Spell.dbc         1 = Attributes (2..8 = AttributesEx..Ex7; the Cata-only
--                     ExH/ExI/ExJ at 9..11 have no 3.3.5 counterpart, dropped),
--                     12 = CastingTimeIndex, 13 = DurationIndex, 14 = PowerType,
--                     15 = RangeIndex, 16 = Speed, 17/18 = SpellVisualID,
--                     19 = SpellIconID, 20 = ActiveIconID, 21 = Name,
--                     23 = Description, 25 = SchoolMask,
--                     32 -> SpellAuraOptions, 36 -> SpellClassOptions
--   SpellEffect.dbc   1 = Effect, 3 = EffectAura, 4 = AuraPeriod, 5 = BasePoints,
--                     8 = ChainTargets, 10 = ItemType, 11 = Mechanic,
--                     12/13 = MiscValue/B, 15 = RadiusIndex,
--                     18/19/20 = SpellClassMask A/B/C, 21 = TriggerSpell,
--                     22/23 = ImplicitTargetA/B, 24 = SpellID, 25 = EffectIndex
--   SpellAuraOptions  1 = StackAmount, 2 = ProcChance, 3 = ProcCharges,
--                     4 = ProcTypeMask. Verified against 3.3.5: Clearcasting
--                     12536 = 1 charge, 16246 = 2 charges, both match.
--   SpellClassOptions 2/3/4 = SpellClassMask, 5 = SpellClassSet
--
-- ONE DELIBERATE TRANSFORM: 3.3.5 computes an effect value as
-- BasePoints + rand(1..DieSides); Cataclysm dropped DieSides. Every effect below
-- carries DieSides = 1 and BasePoints = (cata value - 1), which reproduces the
-- Cata amount exactly. Copying the value in with DieSides = 0 is off by one.
--
-- SPELL FAMILY MASKS -- the part that would silently go wrong. An
-- ADD_FLAT/PCT_MODIFIER or PROC_TRIGGER aura carries a SpellFamilyName plus a
-- class mask naming the abilities it affects. Cata bit assignments are NOT
-- 3.3.5 bit assignments, so a verbatim copy buffs the wrong spells. Every mask
-- here was re-derived instead. Expand the Cata mask to the ability NAMES it hits,
-- look those up in 3.3.5 within the same family, then SELECT bits rather than
-- OR-ing masks: start from the union of the target abilities bits and drop every
-- bit that any NON-target ability of that family also carries. The result hits
-- precisely the intended abilities or the set is not shipped.
--
-- Three rules that this depends on, each learned the hard way:
--   * OR-ing whole masks is wrong. Passives carry a TARGET mask, not an identity,
--     and folding one in explodes the result -- an early pass had the Mage 2P
--     bonus modifying Arcane Intellect and Dampen Magic.
--   * Whether a spell is a passive is decided by EFFECT 1 ALONE. Testing all three
--     effects drops real abilities that merely carry a modifier in a later slot:
--     3.3.5 Envenom is School Damage + aura 108 + aura 107, and excluding it made
--     the Rogue T11 bonuses look unsolvable.
--   * A target whose 3.3.5 class mask is all zero (Juggernaut, Divine Guardian,
--     Brain Freeze -- talents and procs with no family bit) can never be selected
--     by any mask. It is dropped and simply goes unaffected; only a bonus that
--     loses ALL of its targets that way is withheld.
--
-- Where 3.3.5 splits one Cata ability into named variants -- Cata Judgement is
-- Judgement of Light/Wisdom/Justice here -- hitting all of them IS the correct
-- translation, so those masks are accepted with the siblings as collateral.
-- Family 0 masks are written as 0: 3.3.5 SpellInfo::IsAffected requires a family
-- match, so a family-0 mask is inert and copying it would be noise.
--
-- itemset_dbc and spell_dbc are ADDITIVE overlays on the binary DBCs
-- (DBCDatabaseLoader merges DB rows into the index table), so this file adds rows
-- without restating stock ones. The server resolves everything after a worldserver
-- restart; the client shows no set name, bonus text or spell tooltip until
-- ItemSet.dbc and Spell.dbc are rebuilt and deployed, which is deliberate and
-- separate. Idempotent.
-- -------------------------------------------------------------------------

-- -------------------------------------------------------------------------
-- 1. Set bonus spells (68 minted; 13 of the 81 already resolve in stock Spell.dbc)
-- -------------------------------------------------------------------------

DELETE FROM `spell_dbc` WHERE `ID` IN (
  89923, 90157, 90158, 90159, 90162, 90165, 90290, 90291, 90296, 90297,
  90454, 90456, 90460, 90472, 90473, 90494, 90498, 90499, 90501, 90502,
  90503, 90505, 92252, 92253, 92254, 92255, 92256, 92257, 92258, 92260,
  92261, 92711, 94744, 94745, 95671, 95672, 95762, 95763, 96411, 99057,
  99058, 99059, 99060, 99131, 99132, 99134, 99135, 99136, 99209, 99213,
  99220, 99221, 99229, 99232, 99233, 99234, 99237, 99238, 105765, 105767,
  105819, 105820, 109939, 109941, 109955, 109956, 109959, 109960);

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
  (89923, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 9, 0, 0, 0, 'Item - Hunter T11 2P Bonus', 'Increases the critical strike chance of your Serpent Sting ability by $s1%.', 6, 107, 4, 1, 0, 7, 0, 0, 0, 1, 0, 0, 0, 0, 16384, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (90157, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 7, 0, 0, 0, 'Item - Druid T11 Restoration 2P Bonus', 'Increases the critical strike chance of the periodic portion of your Lifebloom spell by $s1%.', 6, 107, 4, 1, 0, 7, 0, 0, 0, 1, 0, 0, 0, 0, 0, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (90158, 192, 0, 0, 67108864, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 16384, 100, 0, 0, 0, 0, 1, 0, 1, -1, 7, 0, 0, 0, 'Item - Druid T11 Restoration 4P Bonus', 'While your Harmony mastery bonus to periodic healing is active, you gain $90159s1 Spirit.', 6, 42, 4, 1, 0, 7, 0, 0, 90159, 1, 0, 0, 0, 0, 0, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (90159, 0, 0, 0, 0, 0, 1024, 0, 0, 1, 1, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 2886, 0, 2, -1, 0, 0, 0, 0, 'Bloom', 'Grants $s1 Spirit while your Harmony mastery bonus to periodic healing is active.', 6, 29, 539, 1, 0, 4, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (90162, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 7, 0, 0, 0, 'Item - Druid T11 Feral 2P Bonus', 'Increases the periodic damage done by your Rake and Lacerate abilities by $s1%.', 6, 108, 9, 1, 0, 22, 0, 0, 0, 1, 0, 0, 0, 0, 36864, 256, 262144, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (90165, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 16, 100, 0, 0, 0, 0, 1, 0, 1, -1, 7, 0, 0, 0, 'Item - Druid T11 Feral 4P Bonus', 'Each time you use Mangle (Cat) you gain a $90166s1% increase to attack power for $90166d stacking up to $90166u times, and the duration of your Survival Instinct ability is increased by $s1%.', 6, 108, 49, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 128, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (90290, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 3, 0, 0, 0, 'Item - Mage T11 2P Bonus', 'Increases the critical strike chance of Arcane Missiles, Ice Lance, and Pyroblast by $s1%.', 6, 107, 4, 1, 0, 7, 0, 0, 0, 1, 0, 0, 0, 0, 4327450, 64, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (90291, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 3, 0, 0, 0, 'Item - Mage T11 4P Bonus', 'Reduces the cast time of Arcane Blast, Fireball, Frostfire Bolt, and Frostbolt by $s1%.', 6, 108, -11, 1, 0, 10, 0, 0, 0, 1, 0, 0, 0, 0, 536870945, 4096, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (90296, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 4, 0, 0, 0, 'Item - Warrior T11 Protection 2P Bonus', 'Increases the damage done by your Shield Slam ability by $s1%.', 6, 108, 4, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 512, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (90297, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 4, 0, 0, 0, 'Item - Warrior T11 Protection 4P Bonus', 'Increases the duration of your Shield Wall ability by $s1%.', 6, 108, 49, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 8192, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (90454, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 15, 0, 0, 0, 'Item - Death Knight T11 Blood 2P Bonus', 'Increases the damage done by your Death Strike ability by $s1%.', 6, 108, 4, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 16, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (90456, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 15, 0, 0, 0, 'Item - Death Knight T11 Blood 4P Bonus', 'Increases the duration of your Icebound Fortitude ability by $s1%.', 6, 108, 49, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 1048576, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (90460, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 8, 0, 0, 0, 'Item - Rogue T11 2P Bonus', 'Increases the critical strike chance of your Backstab, Mutilate, and Sinister Strike abilities by $s1%.', 6, 107, 4, 1, 0, 7, 0, 0, 0, 1, 0, 0, 0, 0, 6, 2097152, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (90472, 0, 0, 0, 0, 0, 0, 0, 0, 1, 8, 0, 1, 0.0, 16, 100, 1, 1, 0, 0, 4857, 0, 1, -1, 8, 0, 0, 0, 'Deadly Scheme', 'Increases your critical strike chance with your next Envenom or Eviscerate by $s1%.  Lasts $d.', 6, 107, 99, 1, 0, 7, 0, 0, 0, 1, 0, 0, 0, 0, 131072, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (90473, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 4, 1, 0, 0, 0, 0, 1, 0, 1, -1, 8, 0, 0, 0, 'Item - Rogue T11 4P Bonus', 'Each of your melee autoattacks has a $h% chance to activate Deadly Scheme for $90472d, increasing the critical strike chance on your next Eviscerate or Envenom by $90472s1%.', 6, 42, 4, 1, 0, 7, 0, 0, 90472, 1, 0, 0, 0, 0, 6, 2097152, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (90494, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 11, 0, 0, 0, 'Item - Shaman T11 Restoration 2P Bonus', 'Increases the critical strike chance of your Healing Wave spell by $s1%.', 6, 107, 4, 1, 0, 7, 0, 0, 0, 1, 0, 0, 0, 0, 64, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (90498, 0, 0, 0, 0, 0, 0, 0, 0, 1, 32, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 3057, 0, 8, -1, 0, 0, 0, 0, 'Surging Tides', 'Increases Spirit by $s1 for $d.', 6, 29, 539, 1, 0, 4, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (90499, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 16384, 100, 0, 0, 0, 0, 1, 0, 1, -1, 11, 0, 0, 0, 'Item - Shaman T11 Restoration 4P Bonus', 'Grants $90498s1 Spirit for $90498d after you cast Riptide.', 6, 42, 4, 1, 0, 7, 0, 0, 90498, 1, 0, 0, 0, 0, 64, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (90501, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 11, 0, 0, 0, 'Item - Shaman T11 Enhancement 2P Bonus', 'Increases damage done by your Lava Lash and Stormstrike abilities by $s1%.', 6, 108, 9, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 16777232, 5124, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (90502, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 11, 0, 0, 0, 'Item - Shaman T11 Enhancment 4P Bonus', 'Increases the critical strike chance of your Lightning Bolt spell by $s1%.', 6, 107, 9, 1, 0, 7, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (90503, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 11, 0, 0, 0, 'Item - Shaman T11 Elemental 2P Bonus', 'Increases the critical strike chance of your Flame Shock spell by $s1%.', 6, 107, 9, 1, 0, 7, 0, 0, 0, 1, 0, 0, 0, 0, 268435456, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (90505, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 11, 0, 0, 0, 'Item - Shaman T11 Elemental 4P Bonus', 'Reduces the cast time of your Lightning Bolt spell by $s1%.', 6, 108, -11, 1, 0, 10, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (92252, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 0, 0, 0, 0, 'Strength 90', 'Increases Strength by $s1.', 6, 29, 89, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (92253, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 0, 0, 0, 0, 'Strength 70', 'Increases Strength by $s1.', 6, 29, 69, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (92254, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 0, 0, 0, 0, 'Increased Resilience 400', '+$s1 resilience rating.', 6, 189, 399, 1, 0, 114688, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (92255, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 8, -1, 0, 0, 0, 0, 'Intellect 90', 'Increases Intellect by $s1.', 6, 29, 89, 1, 0, 3, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (92256, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 8, -1, 0, 0, 0, 0, 'Intellect 70', 'Increases Intellect by $s1.', 6, 29, 69, 1, 0, 3, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (92257, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 0, 0, 0, 0, 'Agility 90', 'Increases Agility by $s1.', 6, 29, 89, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (92258, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 0, 0, 0, 0, 'Agiilty 70', 'Increases Agility by $s1.', 6, 29, 69, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (92260, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 8, -1, 0, 0, 0, 0, 'Intellect 90', 'Increases Intellect by $s1.', 6, 29, 89, 1, 0, 3, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (92261, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 8, -1, 0, 0, 0, 0, 'Intellect 70', 'Increases Intellect by $s1.', 6, 29, 69, 1, 0, 3, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (92711, 464, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 566, 0, 1, -1, 6, 0, 0, 0, 'Mind Blast and Mind Spike Cast Time Reduction', 'Reduces the casting time of your Mind Blast and Mind Spike spells by $s1%.', 6, 108, -6, 1, 0, 10, 0, 0, 0, 1, 0, 0, 0, 0, 8192, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (94744, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 0, 0, 0, 0, 'Spiritmend', 'Increases Spirit by $s1.', 6, 29, 39, 1, 0, 4, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (94745, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 0, 0, 0, 0, 'Deathsilk', 'Increases Intellect by $s1.', 6, 29, 39, 1, 0, 3, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (95671, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 0, 0, 0, 0, 'The Dark Brand', 'Increases Stamina by $s1.', 6, 29, 59, 1, 0, 2, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (95672, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 0, 0, 0, 0, 'The Big Wave', 'Increases mastery rating by $s1.', 6, 189, 39, 1, 0, 33554432, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (95762, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 0.0, 0, 101, 0, 0, 20033, 0, 5316, 0, 1, -1, 0, 0, 0, 0, 'Agony and Torment', 'Haste rating increased by $s1 for $d.', 6, 189, 999, 1, 0, 917504, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (95763, 192, 0, 0, 67108864, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 340, 10, 0, 0, 0, 0, 1, 0, 1, -1, 10, 0, 0, 0, 'Item - Proc Haste Rating', 'Your melee and ranged attacks have a chance to grant $95762s1 haste rating for $95762d.', 6, 42, 99, 1, 0, 0, 0, 0, 95762, 1, 0, 0, 0, 0, 8389632, 4194312, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (96411, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 256, 10, 0, 0, 0, 0, 1, 0, 1, -1, 9, 0, 0, 0, 'Item - Hunter T11 4P Bonus', 'Reduces the cast time of your Steady Shot and Cobra Shot by ${$m1/-1000}.1 sec.', 6, 107, -201, 1, 0, 10, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99057, 192, 0, 0, 67108864, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 256, 10, 0, 0, 0, 0, 1, 0, 1, -1, 9, 0, 0, 0, 'Item - Hunter T12 2P Bonus', 'Your Steady Shot and Cobra Shot have a $h% chance to trigger a Flaming Arrow, dealing $99058s2% instant weapon damage as Fire.', 6, 42, 2, 1, 0, 0, 0, 0, 99058, 1, 0, 0, 0, 0, 8388608, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99058, 262162, 0, 1073872896, 32, 0, 0, 0, 0, 1, 0, 0, 6, 0.0, 0, 101, 0, 0, 0, 0, 105, 0, 4, -1, 0, 0, 0, 33554432, 'Flaming Arrow', 'Deals ranged weapon damage as Fire.', 121, 0, -1, 1, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 31, 0, 79, 1, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 49, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99059, 192, 0, 0, 67108864, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 64, 10, 0, 0, 0, 0, 1, 0, 1, -1, 9, 0, 0, 0, 'Item - Hunter T12 4P Bonus', 'You have a $h% chance from your autoshots to make your next shot or Kill Command cost no focus.', 6, 42, 2, 1, 0, 0, 0, 0, 99060, 1, 0, 0, 0, 0, 8388608, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99060, 327680, 0, 4, 1073741824, 32768, 0, 0, 0, 1, 8, 0, 6, 0.0, 87376, 100, 1, 0, 2736, 0, 1710, 0, 1, -1, 9, 0, 0, 0, 'Burning Adrenaline', 'Your next Shot or Kill Command costs no focus.', 6, 108, -1001, 1, 0, 14, 0, 0, 0, 1, 0, 0, 0, 0, 137728, 2147616768, 33537, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99131, 0, 0, 0, 262144, 32768, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1930, 0, 1, -1, 0, 0, 0, 0, 'Divine Fire', 'Grants you $s1% of your base mana.', 30, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99132, 0, 0, 0, 262144, 32768, 0, 0, 0, 1, 8, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1930, 0, 1, -1, 0, 0, 0, 0, 'Divine Fire', 'Grants you $s1% of your base mana every 5 sec for $d.', 6, 23, 1, 1, 5000, 0, 0, 0, 99131, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99134, 192, 0, 0, 67108864, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 16384, 100, 0, 0, 0, 0, 1, 0, 1, -1, 6, 0, 0, 0, 'Item - Priest T12 Healer 2P Bonus', 'Casting your Flash Heal, Heal, Greater Heal, and Prayer of Mending spells cause you to regenerate $99132s1% of your base mana every 5 sec for $99132d.', 6, 42, 1, 1, 0, 0, 0, 0, 99132, 1, 0, 0, 0, 0, 8388608, 1572864, 64, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99135, 192, 0, 0, 67108864, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 16384, 5, 0, 0, 0, 0, 1, 0, 1, -1, 6, 0, 0, 0, 'Item - Priest T12 Healer 4P Bonus', 'You have a chance when you cast a helpful spell to summon a Cauterizing Flame at the target''s location.  Each sec the Cauterizing Flame will heal an injured party member within 40 yards for $99152s1.  Lasts $99136d.', 6, 42, 1, 1, 0, 0, 0, 0, 99136, 1, 0, 0, 0, 0, 8388608, 1572864, 64, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99136, 0, 131072, 524288, 1073938432, 0, 0, 0, 0, 1, 28, 0, 13, 0.0, 0, 101, 0, 0, 0, 0, 1878, 0, 2, -1, 6, 0, 0, 0, 'Cauterizing Flame', 'You have a chance when you cast a helpful spell to summon a Cauterizing Flame at the target''s location.  Each sec the Cauterizing Flame will heal an injured party member within 40 yards for $99152s1.  Lasts $99136d.', 28, 0, 0, 1, 0, 53475, 3162, 0, 0, 63, 91, 0, 0, 0, 0, 0, 0, 0, 0, 29, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99209, 192, 0, 0, 67108864, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 7, 0, 0, 0, 'Item - Shaman T12 Enhancement 2P Bonus', 'Your Lava Lash gains an additional $s1% damage increase per application of Searing Flames on the target.', 6, 42, 4, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 8388608, 0, 2097152, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99213, 192, 0, 0, 67108864, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 7, 0, 0, 0, 'Item - Shaman T12 Enhancement 4P Bonus', 'Your Stormstrike ability also causes the target to take $99212s1% increased damage from your Fire Nova, Flame Shock, Flametongue Weapon, Lava Burst, Lava Lash, and Unleash Flame abilities.', 6, 42, 4, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 8388608, 0, 2097152, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99220, 192, 0, 0, 67108864, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 262144, 5, 0, 0, 0, 0, 1, 0, 1, -1, 5, 0, 0, 0, 'Item - Warlock T12 2P Bonus', 'Your periodic damage has a chance to summon a Fiery Imp to assist you in battle for $99221d.', 6, 42, 2, 1, 0, 0, 0, 0, 99221, 1, 0, 0, 0, 0, 8388608, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99221, 0, 0, 0, 0, 65536, 0, 0, 0, 1, 8, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 3171, 0, 1, -1, 0, 0, 0, 0, 'Fiery Imp', 'Summons a Fiery Imp to assist you in battle.', 28, 0, 0, 1, 0, 53491, 2909, 15, 0, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99229, 192, 0, 0, 67108864, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 65536, 5, 0, 0, 0, 0, 1, 0, 1, -1, 5, 0, 0, 0, 'Item - Warlock T12 4P Bonus', 'Casting your Shadow Bolt, Incinerate, Soul Fire, and Drain Soul spells has a $h% chance to increase all Shadow and Fire damage you deal by $99232s1% for $99232d.', 6, 42, 2, 1, 0, 0, 0, 0, 99232, 1, 0, 0, 0, 0, 8388608, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99232, 0, 0, 0, 0, 0, 0, 0, 0, 1, 31, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 4675, 0, 1, -1, 0, 0, 0, 0, 'Apocalypse', 'Increases Fire and Shadow damage done by $s1%.', 6, 79, 19, 1, 0, 33554468, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99233, 327696, 0, 0, 0, 0, 256, 67108864, 0, 1, 32, 5, 1, 0.0, 0, 101, 0, 0, 0, 0, 2008, 0, 1, -1, 0, 0, 1073741824, 0, 'Burning Rage', 'Your Battle Shout and Commanding Shout abilities increase all physical damage you deal by $99233s1% for $?s12835[6 sec]?s12321[9 sec][12 sec].', 6, 79, 9, 1, 0, 1, 0, 11, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99234, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 17424, 100, 0, 0, 0, 0, 1, 0, 1, -1, 4, 0, 0, 0, 'Item - Warrior T12 DPS 2P Bonus', 'Your Battle Shout and Commanding Shout abilities increase all physical damage you deal by $99233s1% for $?s12835[6 sec]?s12321[9 sec][12 sec].', 6, 42, 34, 1, 0, 8, 0, 0, 99233, 1, 0, 0, 0, 0, 1073741824, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99237, 262160, 0, 1073872896, 1073741856, 0, 0, 0, 0, 1, 0, 0, 6, 0.0, 0, 101, 0, 0, 0, 0, 105, 0, 4, -1, 0, 0, 0, 33554432, 'Fiery Attack', 'Deals melee weapon damage as Fire.', 121, 0, -1, 1, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 31, 0, 99, 1, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 49, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99238, 192, 0, 0, 67108864, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 16, 30, 0, 0, 0, 0, 1, 0, 1, -1, 4, 0, 0, 0, 'Item - Warrior T12 DPS 4P Bonus', 'Your Mortal Strike and Raging Blow abilities have a $h% chance to trigger a Fiery Attack, dealing $99237s2% instant weapon damage as Fire.', 6, 42, 2, 1, 0, 0, 0, 0, 99237, 1, 0, 0, 0, 0, 8388608, 8388608, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105765, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 69648, 100, 0, 0, 0, 0, 1, 0, 1, -1, 10, 0, 0, 0, 'Item - Paladin T13 Retribution 2P Bonus (Judgement)', 'Your Judgement ability now also generates 1 Holy Power.', 6, 42, 99, 1, 0, 0, 0, 0, 105767, 1, 0, 0, 0, 0, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105767, 327680, 0, 0, 1073742336, 32769, 0, 0, 65536, 1, 0, 0, 6, 0.0, 0, 101, 0, 0, 18980, 0, 156, 0, 2, -1, 10, 0, 0, 0, 'Virtuous Empowerment', 'Your Judgement ability also generates 1 Holy Power.', 30, 0, 0, 1, 0, 9, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105819, 0, 0, 0, 0, 0, 0, 0, 0, 1, 18, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 2230, 0, 1, -1, 10, 0, 0, 0, 'Zeal of the Crusader', 'Damage done by your abilities increased by $s1%.', 6, 108, 17, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 178275368, 543654026, 0, 6, 108, 17, 1, 0, 22, 0, 0, 0, 1, 0, 0, 0, 0, 10503200, 543654026, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105820, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 17424, 100, 0, 0, 0, 0, 1, 0, 1, -1, 10, 0, 0, 0, 'Item - Paladin T13 Retribution 4P Bonus (Zealotry)', 'While Zealotry is active your abilities deal $105819s1% more damage.', 6, 42, 11, 1, 0, 0, 0, 0, 105819, 1, 0, 0, 0, 0, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (109939, 192, 0, 0, 67108864, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 20, 100, 0, 0, 0, 0, 5492, 0, 1, -1, 0, 0, 0, 0, 'Item - Dragon Soul Legendary Daggers', 'Your melee attacks have a chance to grant Shadows of the Destroyer, increasing your Agility by $109941s1, stacking up to $109941u times. Each application past $109939m1 grants an increasing chance to trigger Fury of the Destroyer. When triggered, this consumes all applications of Shadows of the Destroyer, immediately granting $109949s1 combo points and cause your finishing moves to generate $109950s1 combo points.  Lasts $109949d.', 6, 42, 29, 1, 0, 0, 0, 0, 109941, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (109941, 0, 0, 0, 65536, 0, 0, 0, 0, 1, 9, 0, 1, 0.0, 0, 101, 0, 50, 0, 0, 5492, 0, 1, -1, 0, 0, 0, 0, 'Shadows of the Destroyer', 'Increases your Agility by $109941s1, stacking up to $109941u times.  Once you have acquired $109939m1 stacks of Shadows of the Destoyer, each stack gained grants an increasing chance to trigger Fury of the Destroyer and cancel all stacks of Shadows of the Destroyer.  Fury of the Destroyer immediately grants $109949s1 combo points and causes your finishing moves to grant $109950s1 combo points.  Lasts $109949d.', 6, 29, 16, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (109955, 16, 0, 0, 0, 0, 0, 0, 0, 1, 9, 0, 1, 0.0, 0, 101, 0, 50, 0, 0, 1958, 0, 1, -1, 0, 0, 0, 0, 'Nightmare', 'Increases your Agility by $s1, stacking up to $u times.', 6, 29, 4, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (109956, 192, 0, 0, 67108864, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 20, 100, 0, 0, 0, 0, 5492, 0, 1, -1, 0, 0, 0, 0, 'Item - Dragon Soul Legendary Daggers', 'Your melee attacks have a chance to grant Nightmare, increasing your Agility by $109955s1, stacking up to $109955u times.', 6, 42, 19, 1, 0, 0, 0, 0, 109955, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (109959, 16, 0, 0, 0, 0, 0, 0, 0, 1, 9, 0, 1, 0.0, 0, 101, 0, 50, 0, 0, 55, 0, 1, -1, 0, 0, 0, 0, 'Suffering', 'Increases your Agility by $s1, stacking up to $u times.', 6, 29, 1, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (109960, 192, 0, 0, 67108864, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 20, 100, 0, 0, 0, 0, 5492, 0, 1, -1, 0, 0, 0, 0, 'Item - Dragon Soul Legendary Daggers', 'Your melee attacks have a chance to grant Suffering, increasing your Agility by $109959s1, stacking up to $109959u times.', 6, 42, 19, 1, 0, 0, 0, 0, 109959, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

-- -------------------------------------------------------------------------
-- 2. The item sets themselves
-- -------------------------------------------------------------------------
-- Name_Lang_Mask 16712190 is what every stock ItemSet.dbc row carries. Only the
-- first 10 ItemID slots are read server-side -- MAX_ITEM_SET_ITEMS = 10, per the
-- DBC format string "dssssssssssssssssxiiiiiiiiiixxxxxxxiiiiiiiiiiiiiiiiii" --
-- and no set here has more than 10 pieces. Bonuses ordered by ascending threshold.
-- -------------------------------------------------------------------------

DELETE FROM `itemset_dbc` WHERE `ID` IN (
  908, 909, 910, 912, 913, 914, 915, 917, 918, 919, 920, 922,
  923, 926, 927, 928, 930, 931, 937, 938, 939, 940, 943, 944,
  945, 949, 950, 951, 963, 964, 965, 966, 967, 968, 969, 970,
  1005, 1008, 1009, 1015, 1017, 1064, 1087, 1088, 1089);

INSERT INTO `itemset_dbc`
    (`ID`, `Name_Lang_enUS`, `Name_Lang_enGB`, `Name_Lang_koKR`, `Name_Lang_frFR`, `Name_Lang_deDE`, `Name_Lang_enCN`, `Name_Lang_zhCN`, `Name_Lang_enTW`, `Name_Lang_zhTW`, `Name_Lang_esES`, `Name_Lang_esMX`, `Name_Lang_ruRU`, `Name_Lang_ptPT`, `Name_Lang_ptBR`, `Name_Lang_itIT`, `Name_Lang_Unk`, `Name_Lang_Mask`, `ItemID_1`, `ItemID_2`, `ItemID_3`, `ItemID_4`, `ItemID_5`, `ItemID_6`, `ItemID_7`, `ItemID_8`, `ItemID_9`, `ItemID_10`, `ItemID_11`, `ItemID_12`, `ItemID_13`, `ItemID_14`, `ItemID_15`, `ItemID_16`, `ItemID_17`, `SetSpellID_1`, `SetSpellID_2`, `SetSpellID_3`, `SetSpellID_4`, `SetSpellID_5`, `SetSpellID_6`, `SetSpellID_7`, `SetSpellID_8`, `SetThreshold_1`, `SetThreshold_2`, `SetThreshold_3`, `SetThreshold_4`, `SetThreshold_5`, `SetThreshold_6`, `SetThreshold_7`, `SetThreshold_8`, `RequiredSkill`, `RequiredSkillRank`)
VALUES
  (908, 'The Defiler''s Resolve', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 20184, 20177, 20181, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 41853, 39486, 0, 0, 0, 0, 0, 0, 2, 3, 0, 0, 0, 0, 0, 0, 0, 0),
  (909, 'Gladiator''s Battlegear', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 64947, 64946, 64945, 64944, 64943, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 92254, 92253, 22738, 92252, 0, 0, 0, 0, 2, 2, 4, 4, 0, 0, 0, 0, 0, 0),
  (910, 'Gladiator''s Felshroud', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 64977, 64976, 64975, 64974, 64973, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 92254, 92261, 23047, 92260, 0, 0, 0, 0, 2, 2, 4, 4, 0, 0, 0, 0, 0, 0),
  (912, 'Gladiator''s Earthshaker', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 64962, 64961, 64960, 64959, 64958, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 92254, 92258, 33018, 92257, 0, 0, 0, 0, 2, 2, 4, 4, 0, 0, 0, 0, 0, 0),
  (913, 'Gladiator''s Wartide', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 65151, 65150, 65149, 65148, 65147, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 92254, 92256, 44299, 92255, 0, 0, 0, 0, 2, 2, 4, 4, 0, 0, 0, 0, 0, 0),
  (914, 'Gladiator''s Vestments', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 64967, 64966, 64965, 64964, 64963, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 92254, 92258, 21975, 92257, 0, 0, 0, 0, 2, 2, 4, 4, 0, 0, 0, 0, 0, 0),
  (915, 'Gladiator''s Raiment', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 64942, 64941, 64940, 64939, 64938, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 92254, 92261, 92711, 92260, 0, 0, 0, 0, 2, 2, 4, 4, 0, 0, 0, 0, 0, 0),
  (917, 'Gladiator''s Vindication', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 64937, 64936, 64935, 64934, 64933, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 92254, 92253, 61776, 92252, 0, 0, 0, 0, 2, 2, 4, 4, 0, 0, 0, 0, 0, 0),
  (918, 'Gladiator''s Redemption', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 64952, 64951, 64950, 64949, 64948, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 92254, 92256, 58000, 92255, 0, 0, 0, 0, 2, 2, 4, 4, 0, 0, 0, 0, 0, 0),
  (919, 'Gladiator''s Regalia', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 64932, 64931, 64930, 64929, 64928, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 92254, 92261, 44302, 92260, 0, 0, 0, 0, 2, 2, 4, 4, 0, 0, 0, 0, 0, 0),
  (920, 'Gladiator''s Pursuit', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 64992, 64991, 64990, 64989, 64988, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 92254, 92258, 61256, 92257, 0, 0, 0, 0, 2, 2, 4, 4, 0, 0, 0, 0, 0, 0),
  (922, 'Gladiator''s Sanctuary', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 64987, 64986, 64985, 64984, 64983, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 92254, 92258, 23218, 92257, 0, 0, 0, 0, 2, 2, 4, 4, 0, 0, 0, 0, 0, 0),
  (923, 'Gladiator''s Refuge', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 64972, 64971, 64970, 64969, 64968, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 92254, 92256, 38417, 92255, 0, 0, 0, 0, 2, 2, 4, 4, 0, 0, 0, 0, 0, 0),
  (926, 'Magma Plated Battlearmor', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 60349, 60350, 60351, 60352, 60353, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 90454, 90456, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (927, 'Stormrider''s Battlegarb', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 60290, 60286, 60288, 60287, 60289, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 90162, 90165, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (928, 'Stormrider''s Vestments', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 60280, 60277, 60278, 60276, 60279, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 90157, 90158, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (930, 'Lightning-Charged Battlegear', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 60306, 60305, 60303, 60307, 60304, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 89923, 96411, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (931, 'Firelord''s Vestments', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 60246, 60244, 60245, 60243, 60247, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 90290, 90291, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (937, 'Wind Dancer''s Regalia', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 60302, 60300, 60299, 60298, 60301, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 90460, 90473, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (938, 'Vestments of the Raging Elements', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 60311, 60310, 60308, 60312, 60309, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 90494, 90499, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (939, 'Battlegear of the Raging Elements', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 60322, 60321, 60320, 60319, 60318, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 90501, 90502, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (940, 'Regalia of the Raging Elements', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 60317, 60316, 60315, 60314, 60313, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 90503, 90505, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (943, 'Earthen Battleplate', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 60331, 60330, 60328, 60332, 60329, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 90296, 90297, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (944, 'Spiritmender', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 54486, 54485, 54484, 54483, 54482, 54481, 54480, 54479, 0, 0, 0, 0, 0, 0, 0, 0, 0, 94744, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (945, 'Deathspeaker', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 54478, 54477, 54476, 54475, 54474, 54473, 54472, 54471, 0, 0, 0, 0, 0, 0, 0, 0, 0, 94745, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (949, 'The Dark Brand', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 56513, 56509, 56505, 56499, 56495, 56491, 56484, 56483, 0, 0, 0, 0, 0, 0, 0, 0, 0, 95671, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (950, 'The Big Wave', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 56512, 56508, 56504, 56498, 56494, 56490, 56482, 56481, 0, 0, 0, 0, 0, 0, 0, 0, 0, 95672, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (951, 'Agony and Torment', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 63538, 63537, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 95763, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (963, 'Bloodthirsty Pyrium', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 70010, 70005, 70011, 70004, 70006, 70007, 70008, 70009, 0, 0, 0, 0, 0, 0, 0, 0, 0, 92254, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (964, 'Bloodthirsty Ornate Pyrium', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 70018, 70013, 70019, 70012, 70014, 70015, 70016, 70017, 0, 0, 0, 0, 0, 0, 0, 0, 0, 92254, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (965, 'Bloodthirsty Leather', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 70020, 70021, 70022, 70023, 70024, 70025, 70026, 70027, 0, 0, 0, 0, 0, 0, 0, 0, 0, 92254, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (966, 'Bloodthirsty Wyrmhide', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 70028, 70029, 70030, 70031, 70032, 70033, 70034, 70035, 0, 0, 0, 0, 0, 0, 0, 0, 0, 92254, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (967, 'Bloodthirsty Dragonscale', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 70036, 70037, 70038, 70039, 70040, 70041, 70042, 70043, 0, 0, 0, 0, 0, 0, 0, 0, 0, 92254, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (968, 'Bloodthirsty Charscale', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 70044, 70045, 70046, 70047, 70048, 70049, 70050, 70051, 0, 0, 0, 0, 0, 0, 0, 0, 0, 92254, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (969, 'Bloodthirsty Embersilk', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 70062, 70061, 70063, 70070, 70067, 70065, 70066, 70060, 70064, 0, 0, 0, 0, 0, 0, 0, 0, 92254, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (970, 'Bloodthirsty Fireweave', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 70052, 70053, 70054, 70055, 70056, 70057, 70058, 70059, 0, 0, 0, 0, 0, 0, 0, 0, 0, 92254, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (1005, 'Flamewaker''s Battlegear', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 71050, 71051, 71052, 71053, 71054, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 99057, 99059, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (1008, 'Balespider''s Burning Vestments', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 71281, 71283, 71282, 71284, 71285, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 99220, 99229, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (1009, 'Vestments of the Cleansing Flame', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 71271, 71272, 71273, 71274, 71275, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 99134, 99135, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (1015, 'Volcanic Battlegear', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 71305, 71304, 71303, 71302, 71301, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 99209, 99213, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (1017, 'Molten Giant Warplate', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 71072, 71071, 71069, 71068, 71070, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 99234, 99238, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (1064, 'Battleplate of Radiant Glory', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 76874, 76875, 76876, 76877, 76878, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 105765, 105820, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (1087, 'Fangs of the Father', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 77949, 77950, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 109939, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (1088, 'Maw of Oblivion', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 77947, 77948, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 109956, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (1089, 'Jaws of Retribution', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 77945, 77946, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 109960, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0);

-- -------------------------------------------------------------------------
-- 3. Point the item shells at their set
-- -------------------------------------------------------------------------
-- Every entry below already exists in item_template (retail appearance-shell
-- downport) carrying itemset = 0. Stats and item level are a separate job.
-- -------------------------------------------------------------------------

-- PvP Season 9/10: The Defiler's Resolve
UPDATE `item_template` SET `itemset` = 908 WHERE `entry` IN (20184, 20177, 20181);
-- PvP Season 9/10: Gladiator's Battlegear
UPDATE `item_template` SET `itemset` = 909 WHERE `entry` IN (64947, 64946, 64945, 64944, 64943);
-- PvP Season 9/10: Gladiator's Felshroud
UPDATE `item_template` SET `itemset` = 910 WHERE `entry` IN (64977, 64976, 64975, 64974, 64973);
-- PvP Season 9/10: Gladiator's Earthshaker
UPDATE `item_template` SET `itemset` = 912 WHERE `entry` IN (64962, 64961, 64960, 64959, 64958);
-- PvP Season 9/10: Gladiator's Wartide
UPDATE `item_template` SET `itemset` = 913 WHERE `entry` IN (65151, 65150, 65149, 65148, 65147);
-- PvP Season 9/10: Gladiator's Vestments
UPDATE `item_template` SET `itemset` = 914 WHERE `entry` IN (64967, 64966, 64965, 64964, 64963);
-- PvP Season 9/10: Gladiator's Raiment
UPDATE `item_template` SET `itemset` = 915 WHERE `entry` IN (64942, 64941, 64940, 64939, 64938);
-- PvP Season 9/10: Gladiator's Vindication
UPDATE `item_template` SET `itemset` = 917 WHERE `entry` IN (64937, 64936, 64935, 64934, 64933);
-- PvP Season 9/10: Gladiator's Redemption
UPDATE `item_template` SET `itemset` = 918 WHERE `entry` IN (64952, 64951, 64950, 64949, 64948);
-- PvP Season 9/10: Gladiator's Regalia
UPDATE `item_template` SET `itemset` = 919 WHERE `entry` IN (64932, 64931, 64930, 64929, 64928);
-- PvP Season 9/10: Gladiator's Pursuit
UPDATE `item_template` SET `itemset` = 920 WHERE `entry` IN (64992, 64991, 64990, 64989, 64988);
-- PvP Season 9/10: Gladiator's Sanctuary
UPDATE `item_template` SET `itemset` = 922 WHERE `entry` IN (64987, 64986, 64985, 64984, 64983);
-- PvP Season 9/10: Gladiator's Refuge
UPDATE `item_template` SET `itemset` = 923 WHERE `entry` IN (64972, 64971, 64970, 64969, 64968);
-- Tier 11: Magma Plated Battlearmor
UPDATE `item_template` SET `itemset` = 926 WHERE `entry` IN (60349, 60350, 60351, 60352, 60353);
-- Tier 11: Stormrider's Battlegarb
UPDATE `item_template` SET `itemset` = 927 WHERE `entry` IN (60290, 60286, 60288, 60287, 60289);
-- Tier 11: Stormrider's Vestments
UPDATE `item_template` SET `itemset` = 928 WHERE `entry` IN (60280, 60277, 60278, 60276, 60279);
-- Tier 11: Lightning-Charged Battlegear
UPDATE `item_template` SET `itemset` = 930 WHERE `entry` IN (60306, 60305, 60303, 60307, 60304);
-- Tier 11: Firelord's Vestments
UPDATE `item_template` SET `itemset` = 931 WHERE `entry` IN (60246, 60244, 60245, 60243, 60247);
-- Tier 11: Wind Dancer's Regalia
UPDATE `item_template` SET `itemset` = 937 WHERE `entry` IN (60302, 60300, 60299, 60298, 60301);
-- Tier 11: Vestments of the Raging Elements
UPDATE `item_template` SET `itemset` = 938 WHERE `entry` IN (60311, 60310, 60308, 60312, 60309);
-- Tier 11: Battlegear of the Raging Elements
UPDATE `item_template` SET `itemset` = 939 WHERE `entry` IN (60322, 60321, 60320, 60319, 60318);
-- Tier 11: Regalia of the Raging Elements
UPDATE `item_template` SET `itemset` = 940 WHERE `entry` IN (60317, 60316, 60315, 60314, 60313);
-- Tier 11: Earthen Battleplate
UPDATE `item_template` SET `itemset` = 943 WHERE `entry` IN (60331, 60330, 60328, 60332, 60329);
-- Crafted / misc: Spiritmender
UPDATE `item_template` SET `itemset` = 944 WHERE `entry` IN (54486, 54485, 54484, 54483, 54482, 54481, 54480, 54479);
-- Crafted / misc: Deathspeaker
UPDATE `item_template` SET `itemset` = 945 WHERE `entry` IN (54478, 54477, 54476, 54475, 54474, 54473, 54472, 54471);
-- Crafted / misc: The Dark Brand
UPDATE `item_template` SET `itemset` = 949 WHERE `entry` IN (56513, 56509, 56505, 56499, 56495, 56491, 56484, 56483);
-- Crafted / misc: The Big Wave
UPDATE `item_template` SET `itemset` = 950 WHERE `entry` IN (56512, 56508, 56504, 56498, 56494, 56490, 56482, 56481);
-- Crafted / misc: Agony and Torment
UPDATE `item_template` SET `itemset` = 951 WHERE `entry` IN (63538, 63537);
-- PvP Season 9/10: Bloodthirsty Pyrium
UPDATE `item_template` SET `itemset` = 963 WHERE `entry` IN (70010, 70005, 70011, 70004, 70006, 70007, 70008, 70009);
-- PvP Season 9/10: Bloodthirsty Ornate Pyrium
UPDATE `item_template` SET `itemset` = 964 WHERE `entry` IN (70018, 70013, 70019, 70012, 70014, 70015, 70016, 70017);
-- PvP Season 9/10: Bloodthirsty Leather
UPDATE `item_template` SET `itemset` = 965 WHERE `entry` IN (70020, 70021, 70022, 70023, 70024, 70025, 70026, 70027);
-- PvP Season 9/10: Bloodthirsty Wyrmhide
UPDATE `item_template` SET `itemset` = 966 WHERE `entry` IN (70028, 70029, 70030, 70031, 70032, 70033, 70034, 70035);
-- PvP Season 9/10: Bloodthirsty Dragonscale
UPDATE `item_template` SET `itemset` = 967 WHERE `entry` IN (70036, 70037, 70038, 70039, 70040, 70041, 70042, 70043);
-- PvP Season 9/10: Bloodthirsty Charscale
UPDATE `item_template` SET `itemset` = 968 WHERE `entry` IN (70044, 70045, 70046, 70047, 70048, 70049, 70050, 70051);
-- PvP Season 9/10: Bloodthirsty Embersilk
UPDATE `item_template` SET `itemset` = 969 WHERE `entry` IN (70062, 70061, 70063, 70070, 70067, 70065, 70066, 70060, 70064);
-- PvP Season 9/10: Bloodthirsty Fireweave
UPDATE `item_template` SET `itemset` = 970 WHERE `entry` IN (70052, 70053, 70054, 70055, 70056, 70057, 70058, 70059);
-- Tier 12: Flamewaker's Battlegear
UPDATE `item_template` SET `itemset` = 1005 WHERE `entry` IN (71050, 71051, 71052, 71053, 71054);
-- Tier 12: Balespider's Burning Vestments
UPDATE `item_template` SET `itemset` = 1008 WHERE `entry` IN (71281, 71283, 71282, 71284, 71285);
-- Tier 12: Vestments of the Cleansing Flame
UPDATE `item_template` SET `itemset` = 1009 WHERE `entry` IN (71271, 71272, 71273, 71274, 71275);
-- Tier 12: Volcanic Battlegear
UPDATE `item_template` SET `itemset` = 1015 WHERE `entry` IN (71305, 71304, 71303, 71302, 71301);
-- Tier 12: Molten Giant Warplate
UPDATE `item_template` SET `itemset` = 1017 WHERE `entry` IN (71072, 71071, 71069, 71068, 71070);
-- Tier 13: Battleplate of Radiant Glory
UPDATE `item_template` SET `itemset` = 1064 WHERE `entry` IN (76874, 76875, 76876, 76877, 76878);
-- Dragon Soul legendary: Fangs of the Father
UPDATE `item_template` SET `itemset` = 1087 WHERE `entry` IN (77949, 77950);
-- Dragon Soul legendary: Maw of Oblivion
UPDATE `item_template` SET `itemset` = 1088 WHERE `entry` IN (77947, 77948);
-- Dragon Soul legendary: Jaws of Retribution
UPDATE `item_template` SET `itemset` = 1089 WHERE `entry` IN (77945, 77946);

-- -------------------------------------------------------------------------
-- Verification (after apply + worldserver restart)
-- -------------------------------------------------------------------------
--   SELECT COUNT(*) FROM itemset_dbc;                             -- 45
--   SELECT COUNT(*) FROM item_template WHERE itemset >= 908;      -- 248
--   SELECT COUNT(DISTINCT itemset) FROM item_template WHERE itemset >= 908;  -- 45
--
--   -- every shipped set spell must resolve, in the overlay or in stock Spell.dbc:
--   SELECT i.ID, i.SetSpellID_1 FROM itemset_dbc i
--    WHERE i.SetSpellID_1 > 0
--      AND i.SetSpellID_1 NOT IN (SELECT ID FROM spell_dbc);
--   -- expect only stock-resolved ids (21975, 22738, 23047, 23218, 33018, 38417, 39486, 41853, 44299, 44302, 58000, 61256, 61776), never a Cata id
--
-- The boot log must not report "Item (Entry: N) has value (ItemSet: X) not
-- existing in ItemSet.dbc, forced to 0" for any entry above.
-- -------------------------------------------------------------------------

-- -------------------------------------------------------------------------
-- DELIBERATELY NOT SHIPPED -- 10 sets whose bonuses need a hand-authored mask
-- -------------------------------------------------------------------------
--   933  Reinforced Sapphirium Regalia            no 3.3.5 target
--   934  Reinforced Sapphirium Battlearmor        no 3.3.5 target
--   936  Mercurial Regalia                        no 3.3.5 target
--   941  Shadowflame Regalia                      no 3.3.5 target
--   942  Earthen Warplate                         no 3.3.5 target
--   1007 Firehawk Robes of Conflagration          no 3.3.5 target
--   1059 Deep Earth Regalia                       no 3.3.5 target
--   1063 Regalia of Radiant Glory                 no 3.3.5 target
--   1065 Armor of Radiant Glory                   no 3.3.5 target has a class mask (Divine Guardian)
--   1069 Spiritwalker's Vestments                 no 3.3.5 target
--
--
-- All ten are the same class of problem: the ability the bonus modifies does not
-- exist in 3.3.5 (Shadowy Apparition, Guardian of Ancient Kings, Starsurge, Holy
-- Radiance, Spiritwalker's Grace, Fel Flame, Divine Guardian), so no mask can
-- express them. Shipping one needs a 3.3.5 ability chosen to stand in, which is a
-- design decision and is deliberately not made here.
-- -------------------------------------------------------------------------
