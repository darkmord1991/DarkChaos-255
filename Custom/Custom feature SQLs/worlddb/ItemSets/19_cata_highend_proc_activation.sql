-- -----------------------------------------------------------------------
-- Activate the inert item procs from the Cataclysm high-end catalogue
--
-- 468 of the imported items carry a proc. Two dozen of those procs shipped
-- in 06_cata_highend_proc_spells.sql as SPELL_AURA_DUMMY: in Cata a C++
-- script read the dummy and did the work, so on 3.3.5 they load, show a
-- tooltip, and do nothing. This file makes them work without new C++.
--
-- APPLY AFTER 06 and 07. Requires no core rebuild.
--
-- Part A -- 13 spells that the shipped procs reference but that were never
--           minted. File 06 followed EffectTriggerSpell chains; these are
--           named only inside description text ("$96977s1"), so nothing
--           pointed at them. Without them the rewrites in part B would
--           trigger a spell that does not resolve, and the client would
--           render a broken token in the tooltip.
--
-- Part B -- each dummy rewritten into a real 3.3.5 aura. Where Cata used a
--           mechanic 3.3.5 does not have (mastery, health-percent proc
--           conditions, banked resources, random element selection) the
--           substitution and its scaling are stated inline.
--
-- Part C -- pacing that Cata held in script: internal cooldowns and the
--           crit-only gate, expressed through spell_proc.
--
-- Part D -- destinations for the Cloak of Coordination teleports, which
--           3.3.5 reads from spell_target_position.
--
-- Left deliberately inert, documented rather than faked:
--   99245  Druid of the Flames -- a Cat Form model swap for the
--          Flamescythe. Cosmetic only; the weapon itself works.
--   96173  Corrupted Egg Shell -- a cooldown marker. The absorb it guards
--          (91308 Egg Shell) is a plain aura and already works.
--   96890 Electrical Charge, 96923 Titanic Power, 91832 Raw Fury -- stack
--          counters. They still display; nothing now reads them.
-- -----------------------------------------------------------------------

-- Part A -- referenced spells that were never minted -----------------

DELETE FROM `spell_dbc` WHERE `ID` IN (91310, 91311, 96890, 96891, 96927, 96977, 96993, 97139, 100403, 107785, 108008, 109867, 109868);
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
  (91310, 150994944, 0, 4, 0, 0, 0, 0, 0, 1, 0, 0, 6, 0.0, 0, 101, 0, 0, 12489, 0, 3202, 0, 1, -1, 0, 0, 0, 0, 'Mystic Egg', 'Grants $s1 mana.', 30, 0, 5699, 1, 0, 0, 0, 0, 0, 21, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (91311, 150994944, 0, 4, 0, 0, 0, 0, 0, 1, 0, 0, 6, 0.0, 0, 101, 0, 0, 12489, 0, 3202, 0, 1, -1, 0, 0, 0, 0, 'Mystic Egg', 'Grants $s1 mana.', 30, 0, 474, 1, 0, 0, 0, 0, 0, 21, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (96890, 0, 0, 0, 0, 0, 0, 0, 0, 1, 21, 0, 1, 0.0, 0, 101, 0, 10, 0, 0, 47, 0, 1, -1, 0, 0, 0, 0, 'Electrical Charge', 'Gained an Electrical Charge.  Each Electrical Charge has a chance to cause the release of a Lightning Bolt dealing $96891s1 damage per Electrical Charge.', 6, 4, 983, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (96891, 65536, 0, 1073741824, 0, 0, 0, 0, 0, 1, 0, 0, 36, 20.0, 0, 101, 0, 0, 173, 0, 62, 0, 8, -1, 11, 0, 0, 0, 'Lightning Bolt', 'Casts a bolt of lightning at the target for $s1 Nature damage per Electrical Charge accumulated.', 2, 0, 983, 1, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (96927, 0, 0, 0, 0, 0, 0, 0, 0, 1, 8, 0, 1, 0.0, 0, 101, 0, 0, 7553, 0, 1950, 0, 1, -1, 0, 0, 0, 0, 'Blessing of the Shaper', 'Haste rating increased for $d.', 6, 189, 507, 1, 0, 917504, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (96977, 0, 0, 0, 0, 0, 0, 0, 0, 1, 9, 0, 1, 0.0, 0, 101, 0, 0, 7553, 0, 5383, 0, 1, -1, 0, 0, 0, 0, 'Matrix Restabilized', 'Haste rating increased by $s1 for $d.', 6, 189, 1623, 1, 0, 917504, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (96993, 2751463424, 0, 536870912, 262144, 0, 8388608, 0, 33554432, 1, 1, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1474, 0, 1, -1, 0, 0, 0, 0, 'Stay Withdrawn', 'Take $s1% of recently absorbed damage every $t sec for $d.', 6, 3, 7, 1, 2000, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (97139, 0, 0, 0, 0, 0, 0, 0, 0, 1, 9, 0, 1, 0.0, 0, 101, 0, 0, 7553, 0, 5383, 0, 1, -1, 0, 0, 0, 0, 'Matrix Restabilized', 'Haste rating increased by $s1 for $d.', 6, 189, 1833, 1, 0, 917504, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (100403, 0, 4, 0, 0, 0, 0, 0, 0, 1, 18, 0, 3, 0.0, 0, 101, 0, 0, 21191, 0, 2833, 0, 8, -1, 0, 0, 0, 0, 'Blessing of the Moonwell', 'Increases Mastery by $s1.', 6, 189, 1699, 1, 0, 1792, 0, 0, 0, 92, 92, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1000, 0, 0, 0, 0, 92, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (107785, 0, 0, 0, 262144, 0, 0, 0, 0, 1, 0, 0, 36, 0.0, 0, 101, 0, 0, 17159, 0, 18, 0, 4, -1, 0, 0, 0, 0, 'Flameblast', 'Deals $s1 fire damage.', 2, 0, 7652, 1, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (108008, 671088640, 0, 0, 0, 0, 0, 0, 0, 1, 32, 0, 1, 0.0, 0, 101, 0, 0, 1726, 0, 5552, 0, 2, -1, 0, 0, 0, 0, 'Indomitable', 'Absorbs physical damage.  Lasts $d.', 6, 69, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (109867, 0, 0, 0, 262144, 0, 0, 0, 0, 1, 0, 0, 36, 0.0, 0, 101, 0, 0, 8031, 0, 213, 0, 32, -1, 0, 0, 0, 0, 'Shadowblast', 'Deals $s1 shadow damage.', 2, 0, 6779, 1, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (109868, 0, 0, 0, 262144, 0, 0, 0, 0, 1, 0, 0, 36, 0.0, 0, 101, 0, 0, 8031, 0, 213, 0, 32, -1, 0, 0, 0, 0, 'Shadowblast', 'Deals $s1 shadow damage.', 2, 0, 8638, 1, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

-- Part B -- rewrite each inert dummy into a working 3.3.5 aura -------

-- 96887 effect 1: crit-gated Lightning Bolt, 2.5s internal cooldown
UPDATE `spell_dbc` SET
    `Effect_1` = 6, `EffectAura_1` = 227,
    `EffectBasePoints_1` = 984, `EffectDieSides_1` = 0,
    `EffectMiscValue_1` = 0, `EffectTriggerSpell_1` = 96891,
    `ImplicitTargetA_1` = 1
WHERE `ID` = 96887;

-- 97119 effect 1: crit-gated Lightning Bolt, 2.5s internal cooldown
UPDATE `spell_dbc` SET
    `Effect_1` = 6, `EffectAura_1` = 227,
    `EffectBasePoints_1` = 2888, `EffectDieSides_1` = 0,
    `EffectMiscValue_1` = 0, `EffectTriggerSpell_1` = 96891,
    `ImplicitTargetA_1` = 1
WHERE `ID` = 97119;

-- 96976 effect 1: always grants haste (no mastery in 3.3.5)
UPDATE `spell_dbc` SET
    `Effect_1` = 6, `EffectAura_1` = 42,
    `EffectBasePoints_1` = 0, `EffectDieSides_1` = 0,
    `EffectMiscValue_1` = 0, `EffectTriggerSpell_1` = 96977,
    `ImplicitTargetA_1` = 1
WHERE `ID` = 96976;

-- 97138 effect 1: always grants haste (no mastery in 3.3.5)
UPDATE `spell_dbc` SET
    `Effect_1` = 6, `EffectAura_1` = 42,
    `EffectBasePoints_1` = 0, `EffectDieSides_1` = 0,
    `EffectMiscValue_1` = 0, `EffectTriggerSpell_1` = 97139,
    `ImplicitTargetA_1` = 1
WHERE `ID` = 97138;

-- 96934 effect 1: 3-stack equivalent haste, 15s, no stack consumption
UPDATE `spell_dbc` SET
    `Effect_1` = 6, `EffectAura_1` = 189,
    `EffectBasePoints_1` = 1524, `EffectDieSides_1` = 0,
    `EffectMiscValue_1` = 917504, `EffectTriggerSpell_1` = 0,
    `ImplicitTargetA_1` = 1
WHERE `ID` = 96934;

-- 97127 effect 1: 3-stack equivalent haste, 15s, no stack consumption
UPDATE `spell_dbc` SET
    `Effect_1` = 6, `EffectAura_1` = 189,
    `EffectBasePoints_1` = 1725, `EffectDieSides_1` = 0,
    `EffectMiscValue_1` = 917504, `EffectTriggerSpell_1` = 0,
    `ImplicitTargetA_1` = 1
WHERE `ID` = 97127;

-- 109785 effect 1: i384: flat 19500 absorb, 60s internal cooldown, no health gate
UPDATE `spell_dbc` SET
    `Effect_1` = 6, `EffectAura_1` = 227,
    `EffectBasePoints_1` = 19500, `EffectDieSides_1` = 0,
    `EffectMiscValue_1` = 0, `EffectTriggerSpell_1` = 108008,
    `ImplicitTargetA_1` = 1
WHERE `ID` = 109785;

-- 108007 effect 1: i397: flat 22500 absorb, 60s internal cooldown, no health gate
UPDATE `spell_dbc` SET
    `Effect_1` = 6, `EffectAura_1` = 227,
    `EffectBasePoints_1` = 22500, `EffectDieSides_1` = 0,
    `EffectMiscValue_1` = 0, `EffectTriggerSpell_1` = 108008,
    `ImplicitTargetA_1` = 1
WHERE `ID` = 108007;

-- 109786 effect 1: i410: flat 25000 absorb, 60s internal cooldown, no health gate
UPDATE `spell_dbc` SET
    `Effect_1` = 6, `EffectAura_1` = 227,
    `EffectBasePoints_1` = 25000, `EffectDieSides_1` = 0,
    `EffectMiscValue_1` = 0, `EffectTriggerSpell_1` = 108008,
    `ImplicitTargetA_1` = 1
WHERE `ID` = 109786;

-- 109866 effect 1: i390: Shadowblast 6780 (was random of 3, identical damage)
UPDATE `spell_dbc` SET
    `Effect_1` = 6, `EffectAura_1` = 42,
    `EffectBasePoints_1` = 0, `EffectDieSides_1` = 0,
    `EffectMiscValue_1` = 0, `EffectTriggerSpell_1` = 109867,
    `ImplicitTargetA_1` = 1
WHERE `ID` = 109866;

-- 107786 effect 1: i403: Flameblast 7653 (was random of 3, identical damage)
UPDATE `spell_dbc` SET
    `Effect_1` = 6, `EffectAura_1` = 42,
    `EffectBasePoints_1` = 0, `EffectDieSides_1` = 0,
    `EffectMiscValue_1` = 0, `EffectTriggerSpell_1` = 107785,
    `ImplicitTargetA_1` = 1
WHERE `ID` = 107786;

-- 109873 effect 1: i416: Shadowblast 8639 (was random of 3, identical damage)
UPDATE `spell_dbc` SET
    `Effect_1` = 6, `EffectAura_1` = 42,
    `EffectBasePoints_1` = 0, `EffectDieSides_1` = 0,
    `EffectMiscValue_1` = 0, `EffectTriggerSpell_1` = 109868,
    `ImplicitTargetA_1` = 1
WHERE `ID` = 109873;

-- 92272 effect 1: flat 175 mana per 5 sec in place of the 4200 mana battery
UPDATE `spell_dbc` SET
    `Effect_1` = 6, `EffectAura_1` = 85,
    `EffectBasePoints_1` = 175, `EffectDieSides_1` = 0,
    `EffectMiscValue_1` = 0, `EffectTriggerSpell_1` = 0,
    `ImplicitTargetA_1` = 1
WHERE `ID` = 92272;

-- 96879 effect 1: plus 2% healing done in place of the overheal bank
UPDATE `spell_dbc` SET
    `Effect_1` = 6, `EffectAura_1` = 136,
    `EffectBasePoints_1` = 2, `EffectDieSides_1` = 0,
    `EffectMiscValue_1` = 0, `EffectTriggerSpell_1` = 0,
    `ImplicitTargetA_1` = 1
WHERE `ID` = 96879;

-- 97117 effect 1: plus 2% healing done in place of the overheal bank
UPDATE `spell_dbc` SET
    `Effect_1` = 6, `EffectAura_1` = 136,
    `EffectBasePoints_1` = 2, `EffectDieSides_1` = 0,
    `EffectMiscValue_1` = 0, `EffectTriggerSpell_1` = 0,
    `ImplicitTargetA_1` = 1
WHERE `ID` = 97117;

-- 89157 effect 2 blanked: SCRIPT_EFFECT faction check; the teleport itself is effect 1
UPDATE `spell_dbc` SET
    `Effect_2` = 0, `EffectAura_2` = 0,
    `EffectBasePoints_2` = 0, `EffectDieSides_2` = 0,
    `EffectMiscValue_2` = 0, `EffectTriggerSpell_2` = 0
WHERE `ID` = 89157;

-- 89158 effect 2 blanked: SCRIPT_EFFECT faction check; the teleport itself is effect 1
UPDATE `spell_dbc` SET
    `Effect_2` = 0, `EffectAura_2` = 0,
    `EffectBasePoints_2` = 0, `EffectDieSides_2` = 0,
    `EffectMiscValue_2` = 0, `EffectTriggerSpell_2` = 0
WHERE `ID` = 89158;

-- 91322 effect 2 blanked: consumed Inner Eye -- a Cata priest mechanic with no 3.3.5 equivalent. The mana grant on effect 1 is untouched.
UPDATE `spell_dbc` SET
    `Effect_2` = 0, `EffectAura_2` = 0,
    `EffectBasePoints_2` = 0, `EffectDieSides_2` = 0,
    `EffectMiscValue_2` = 0, `EffectTriggerSpell_2` = 0
WHERE `ID` = 91322;

-- 92331 effect 2 blanked: consumed Inner Eye -- a Cata priest mechanic with no 3.3.5 equivalent. The mana grant on effect 1 is untouched.
UPDATE `spell_dbc` SET
    `Effect_2` = 0, `EffectAura_2` = 0,
    `EffectBasePoints_2` = 0, `EffectDieSides_2` = 0,
    `EffectMiscValue_2` = 0, `EffectTriggerSpell_2` = 0
WHERE `ID` = 92331;

-- 108007 effect 2 blanked: script placeholder (absorb percent)
UPDATE `spell_dbc` SET
    `Effect_2` = 0, `EffectAura_2` = 0,
    `EffectBasePoints_2` = 0, `EffectDieSides_2` = 0,
    `EffectMiscValue_2` = 0, `EffectTriggerSpell_2` = 0
WHERE `ID` = 108007;

-- 108007 effect 3 blanked: script placeholder (internal cooldown)
UPDATE `spell_dbc` SET
    `Effect_3` = 0, `EffectAura_3` = 0,
    `EffectBasePoints_3` = 0, `EffectDieSides_3` = 0,
    `EffectMiscValue_3` = 0, `EffectTriggerSpell_3` = 0
WHERE `ID` = 108007;

-- 109785 effect 2 blanked: script placeholder (absorb percent)
UPDATE `spell_dbc` SET
    `Effect_2` = 0, `EffectAura_2` = 0,
    `EffectBasePoints_2` = 0, `EffectDieSides_2` = 0,
    `EffectMiscValue_2` = 0, `EffectTriggerSpell_2` = 0
WHERE `ID` = 109785;

-- 109785 effect 3 blanked: script placeholder (internal cooldown)
UPDATE `spell_dbc` SET
    `Effect_3` = 0, `EffectAura_3` = 0,
    `EffectBasePoints_3` = 0, `EffectDieSides_3` = 0,
    `EffectMiscValue_3` = 0, `EffectTriggerSpell_3` = 0
WHERE `ID` = 109785;

-- 109786 effect 2 blanked: script placeholder (absorb percent)
UPDATE `spell_dbc` SET
    `Effect_2` = 0, `EffectAura_2` = 0,
    `EffectBasePoints_2` = 0, `EffectDieSides_2` = 0,
    `EffectMiscValue_2` = 0, `EffectTriggerSpell_2` = 0
WHERE `ID` = 109786;

-- 109786 effect 3 blanked: script placeholder (internal cooldown)
UPDATE `spell_dbc` SET
    `Effect_3` = 0, `EffectAura_3` = 0,
    `EffectBasePoints_3` = 0, `EffectDieSides_3` = 0,
    `EffectMiscValue_3` = 0, `EffectTriggerSpell_3` = 0
WHERE `ID` = 109786;

-- 92272 effect 2 blanked: script placeholder (battery cap)
UPDATE `spell_dbc` SET
    `Effect_2` = 0, `EffectAura_2` = 0,
    `EffectBasePoints_2` = 0, `EffectDieSides_2` = 0,
    `EffectMiscValue_2` = 0, `EffectTriggerSpell_2` = 0
WHERE `ID` = 92272;

-- 89157 effect 1 target: TARGET_DEST_DB -- required by spell_target_position
UPDATE `spell_dbc` SET `ImplicitTargetA_1` = 17 WHERE `ID` = 89157;

-- 89158 effect 1 target: TARGET_DEST_DB -- required by spell_target_position
UPDATE `spell_dbc` SET `ImplicitTargetA_1` = 17 WHERE `ID` = 89158;

-- 96934 now applies an aura, so it needs a duration (15 sec)
UPDATE `spell_dbc` SET `DurationIndex` = 8 WHERE `ID` = 96934;

-- 97127 now applies an aura, so it needs a duration (15 sec)
UPDATE `spell_dbc` SET `DurationIndex` = 8 WHERE `ID` = 97127;

-- these three are now passive auras; clearing the proc metadata stops
-- the proc system from evaluating them on every combat event.
UPDATE `spell_dbc` SET `ProcTypeMask` = 0, `ProcChance` = 0, `ProcCharges` = 0
WHERE `ID` IN (92272, 96879, 97117);

-- Part C -- proc pacing ----------------------------------------------

DELETE FROM `spell_proc` WHERE `SpellId` IN (96887, 97119, 96976, 97138, 107786, 109866, 109873, 108007, 109785, 109786);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
  (96887, 0, 0, 0, 0, 0, 327680, 1, 2, 2, 0, 0, 0, 100, 2500, 0),
  (97119, 0, 0, 0, 0, 0, 327680, 1, 2, 2, 0, 0, 0, 100, 2500, 0),
  (96976, 0, 0, 0, 0, 0, 340, 0, 2, 0, 0, 0, 0, 20, 30000, 0),
  (97138, 0, 0, 0, 0, 0, 340, 0, 2, 0, 0, 0, 0, 20, 30000, 0),
  (107786, 0, 0, 0, 0, 0, 20, 0, 2, 0, 0, 0, 0, 7, 0, 0),
  (109866, 0, 0, 0, 0, 0, 20, 0, 2, 0, 0, 0, 0, 7, 0, 0),
  (109873, 0, 0, 0, 0, 0, 20, 0, 2, 0, 0, 0, 0, 7, 0, 0),
  (108007, 0, 0, 0, 0, 0, 664232, 0, 0, 0, 0, 0, 0, 100, 60000, 0),
  (109785, 0, 0, 0, 0, 0, 664232, 0, 0, 0, 0, 0, 0, 100, 60000, 0),
  (109786, 0, 0, 0, 0, 0, 664232, 0, 0, 0, 0, 0, 0, 100, 60000, 0);

-- Part D -- Cloak of Coordination destinations -----------------------

DELETE FROM `spell_target_position` WHERE `ID` IN (89157, 89158);
INSERT INTO `spell_target_position` (`ID`, `EffectIndex`, `MapID`, `PositionX`, `PositionY`, `PositionZ`, `Orientation`) VALUES
  (89157, 0, 0, -8833.38, 628.628, 94.0066, 1.06535),  -- Stormwind City
  (89158, 0, 1, 1629.85, -4373.64, 31.5573, 3.69762);  -- Orgrimmar

