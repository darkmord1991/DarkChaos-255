-- DarkChaos Well Rested (spell 800030). Re-runnable.
-- Code: src/server/scripts/DC/Progression/dc_well_rested.cpp (config DC.WellRested.*).
-- Client row: Custom/CSV DBC/Spell.csv (800030), same values.
--
-- A visible self buff that carries no stat of its own: a DUMMY aura of 10 (EffectBasePoints_1 9), so the
-- tooltip can say $s1%. The script adds the XP in OnPlayerGiveXP, where `.dc xp bonus off` is respected.
-- Duration index 367 = 2 hours (the script sets the real duration from DC.WellRested.DurationMinutes).
-- AttributesEx3 0x00100000 = kept through death, AttributesEx4 0x00200000 = kept when entering an arena.
-- Icon 44 = Spell_Nature_Sleep. Family 0 with no class mask, so it is exclusive with nothing.
DELETE FROM `spell_dbc` WHERE `ID` = 800030;
INSERT INTO `spell_dbc` (`ID`, `Attributes`, `AttributesEx3`, `AttributesEx4`, `CastingTimeIndex`, `ProcChance`,
    `DurationIndex`, `RangeIndex`, `EquippedItemClass`, `Effect_1`, `EffectDieSides_1`, `EffectBasePoints_1`,
    `ImplicitTargetA_1`, `EffectAura_1`, `SpellIconID`, `Name_Lang_enUS`, `Name_Lang_Mask`, `NameSubtext_Lang_Mask`,
    `Description_Lang_enUS`, `Description_Lang_Mask`, `AuraDescription_Lang_enUS`, `AuraDescription_Lang_Mask`,
    `EffectChainAmplitude_1`, `EffectChainAmplitude_2`, `EffectChainAmplitude_3`, `SchoolMask`) VALUES
(800030, 0, 1048576, 2097152, 1, 101, 367, 1, -1, 6, 1, 9, 1, 4, 44,
    'Well Rested', 16712190, 16712188,
    'Resting in an inn has left you well rested. Experience gained from killing monsters and completing quests is increased by $s1% for $d of play time. The time only runs while you are online.',
    16712190,
    'Experience gained from killing monsters and completing quests increased by $s1%.',
    16712190, 1, 1, 1, 1);
