-- =====================================================================================
-- Cataclysm Shadowfang Keep -- map 825 clone: the 8 spells the summon chain dies on.
--
-- Baron Silverlaine's worgen-spirit mechanic never produced a single creature, because
-- the original downport stopped one link short. The chain, as the retail data has it:
--
--   93857 Summon Worgen Spirit          SCRIPT_EFFECT -> spell_sfk_summon_worgen_spirit
--                                       casts the *_DUMMY id handed in as base point 0
--   93896 / 93859 / 93921 / 93925       TRIGGER_MISSILE -> 93895 / 93858 / 93922 / 93926
--   93895 / 93858 / 93922 / 93926       *** MISSING *** -- SUMMON, the Worgen Spirit
--   ...Silverlaine's JustSummoned then makes the spirit cast:
--   93899 / 93864 / 93924 / 93927       periodic-trigger aura -> 93897 / 93860 / 93923 / 93929
--   93897 / 93860 / 93923 / 93929       *** MISSING *** -- SUMMON, the named ghost
--
-- 01_sfk_cata_spells.sql downported 56 ids and none of these 8 were among them, so no
-- effect anywhere in the chain had SPELL_EFFECT_SUMMON and the mechanic was inert no
-- matter what the C++ did.
--
-- Extracted with _cata_spell_downport.py from the same source as 01
-- (K:/UntouchedClients/Cata Data/enUS/locale-enUS.MPQ, Spell.dbc + SpellEffect.dbc),
-- layout self-verified against the known-good calibration spells before emitting.
--
-- ---------------------------------------------------------------------------------
-- ONE EDIT vs THE RAW CATA ROWS: EffectMiscValue_1 carries the +5,000,000 offset
-- ---------------------------------------------------------------------------------
-- These are summon effects, so EffectMiscValue_1 is a creature entry, and retail's
-- entry is not this realm's. Each has been remapped into the clone band:
--
--   93895 -> 51047 + 5000000  Worgen Spirit (Nandos)
--   93858 -> 50934 + 5000000  Worgen Spirit (Odo)
--   93922 -> 51080 + 5000000  Worgen Spirit (Razorclaw)
--   93926 -> 51085 + 5000000  Worgen Spirit (Rethilgore)
--   93897 -> 50851 + 5000000  Wolf Master Nandos
--   93860 -> 50857 + 5000000  Odo the Blindwatcher
--   93923 -> 50869 + 5000000  Razorclaw the Butcher
--   93929 -> 50834 + 5000000  Rethilgore
--
-- All eight creature_template rows were confirmed present before writing this file.
-- Leaving the raw retail ids in would summon whatever happens to occupy 51047 etc. on
-- this realm, which is the kind of bug that looks like a random unrelated NPC appearing
-- in the middle of a boss fight.
--
-- This data also settles which creature owns npc_sfk_worgen_spirit: the *_SUMMON spells
-- create the NAMED GHOSTS, so the ghosts are what fight and what needs the AI. See
-- 21_fix_worgen_spirit_scriptname.sql.
--
-- ---------------------------------------------------------------------------------
-- SERVER-SIDE ONLY, like 01
-- ---------------------------------------------------------------------------------
-- `spell_dbc` is merged into sSpellStore at startup (DBCStores.cpp:240,
-- storage.LoadFromDB), so the server resolves these immediately. The CLIENT has no row
-- for them until Spell.dbc itself is rebuilt with tools/spell-dbc-append.py and
-- deployed -- same state as all 56 spells in 01. Nothing here changes that.
--
-- REQUIRES a worldserver restart: DBC stores are loaded once at boot.
-- =====================================================================================

DELETE FROM `spell_dbc` WHERE `ID` IN (93858,93860,93895,93897,93922,93923,93926,93929);

INSERT INTO `spell_dbc` (`ActiveIconID`, `Attributes`, `AttributesEx`, `AttributesEx2`, `AttributesEx3`, `AttributesEx4`, `AttributesEx5`, `AttributesEx6`, `AttributesEx7`, `CastingTimeIndex`, `Description_Lang_enUS`, `DurationIndex`, `EffectAuraPeriod_1`, `EffectAura_1`, `EffectBasePoints_1`, `EffectDieSides_1`, `EffectMiscValueB_1`, `EffectMiscValue_1`, `EffectRadiusIndex_1`, `EffectTriggerSpell_1`, `Effect_1`, `EquippedItemClass`, `ID`, `ImplicitTargetA_1`, `ImplicitTargetB_1`, `Name_Lang_enUS`, `PowerType`, `ProcChance`, `RangeIndex`, `SchoolMask`, `Speed`, `SpellIconID`, `SpellVisualID_1`, `SpellVisualID_2`) VALUES (0, 256, 268435456, 0, 0, 0, 0, 0, 0, 1, '', 28, 0, 0, -1, 1, 64, 5051047, 0, 0, 28, -1, 93895, 87, 0, 'Summon Spirit of Wolf Master Nandos', 0, 101, 13, 1, 0.0, 1, 0, 0);
INSERT INTO `spell_dbc` (`ActiveIconID`, `Attributes`, `AttributesEx`, `AttributesEx2`, `AttributesEx3`, `AttributesEx4`, `AttributesEx5`, `AttributesEx6`, `AttributesEx7`, `CastingTimeIndex`, `Description_Lang_enUS`, `DurationIndex`, `EffectAuraPeriod_1`, `EffectAura_1`, `EffectBasePoints_1`, `EffectDieSides_1`, `EffectMiscValueB_1`, `EffectMiscValue_1`, `EffectRadiusIndex_1`, `EffectTriggerSpell_1`, `Effect_1`, `EquippedItemClass`, `ID`, `ImplicitTargetA_1`, `ImplicitTargetB_1`, `Name_Lang_enUS`, `PowerType`, `ProcChance`, `RangeIndex`, `SchoolMask`, `Speed`, `SpellIconID`, `SpellVisualID_1`, `SpellVisualID_2`) VALUES (0, 256, 268435456, 0, 0, 0, 0, 0, 0, 1, '', 28, 0, 0, -1, 1, 64, 5050934, 0, 0, 28, -1, 93858, 87, 0, 'Summon Spirit of Odo the Blindwatcher', 0, 101, 13, 1, 0.0, 1, 0, 0);
INSERT INTO `spell_dbc` (`ActiveIconID`, `Attributes`, `AttributesEx`, `AttributesEx2`, `AttributesEx3`, `AttributesEx4`, `AttributesEx5`, `AttributesEx6`, `AttributesEx7`, `CastingTimeIndex`, `Description_Lang_enUS`, `DurationIndex`, `EffectAuraPeriod_1`, `EffectAura_1`, `EffectBasePoints_1`, `EffectDieSides_1`, `EffectMiscValueB_1`, `EffectMiscValue_1`, `EffectRadiusIndex_1`, `EffectTriggerSpell_1`, `Effect_1`, `EquippedItemClass`, `ID`, `ImplicitTargetA_1`, `ImplicitTargetB_1`, `Name_Lang_enUS`, `PowerType`, `ProcChance`, `RangeIndex`, `SchoolMask`, `Speed`, `SpellIconID`, `SpellVisualID_1`, `SpellVisualID_2`) VALUES (0, 256, 268435456, 0, 0, 0, 0, 0, 0, 1, '', 28, 0, 0, -1, 1, 64, 5051080, 0, 0, 28, -1, 93922, 87, 0, 'Summon Spirit of Razorclaw the Butcher', 0, 101, 13, 1, 0.0, 1, 0, 0);
INSERT INTO `spell_dbc` (`ActiveIconID`, `Attributes`, `AttributesEx`, `AttributesEx2`, `AttributesEx3`, `AttributesEx4`, `AttributesEx5`, `AttributesEx6`, `AttributesEx7`, `CastingTimeIndex`, `Description_Lang_enUS`, `DurationIndex`, `EffectAuraPeriod_1`, `EffectAura_1`, `EffectBasePoints_1`, `EffectDieSides_1`, `EffectMiscValueB_1`, `EffectMiscValue_1`, `EffectRadiusIndex_1`, `EffectTriggerSpell_1`, `Effect_1`, `EquippedItemClass`, `ID`, `ImplicitTargetA_1`, `ImplicitTargetB_1`, `Name_Lang_enUS`, `PowerType`, `ProcChance`, `RangeIndex`, `SchoolMask`, `Speed`, `SpellIconID`, `SpellVisualID_1`, `SpellVisualID_2`) VALUES (0, 256, 268435456, 0, 0, 0, 0, 0, 0, 1, '', 28, 0, 0, -1, 1, 64, 5051085, 0, 0, 28, -1, 93926, 87, 0, 'Summon Spirit of Rethilgore', 0, 101, 13, 1, 0.0, 1, 0, 0);
INSERT INTO `spell_dbc` (`ActiveIconID`, `Attributes`, `AttributesEx`, `AttributesEx2`, `AttributesEx3`, `AttributesEx4`, `AttributesEx5`, `AttributesEx6`, `AttributesEx7`, `CastingTimeIndex`, `Description_Lang_enUS`, `DurationIndex`, `EffectAuraPeriod_1`, `EffectAura_1`, `EffectBasePoints_1`, `EffectDieSides_1`, `EffectMiscValueB_1`, `EffectMiscValue_1`, `EffectRadiusIndex_1`, `EffectTriggerSpell_1`, `Effect_1`, `EquippedItemClass`, `ID`, `ImplicitTargetA_1`, `ImplicitTargetB_1`, `Name_Lang_enUS`, `PowerType`, `ProcChance`, `RangeIndex`, `SchoolMask`, `Speed`, `SpellIconID`, `SpellVisualID_1`, `SpellVisualID_2`) VALUES (0, 256, 268435456, 4, 0, 0, 0, 0, 0, 1, '', 21, 0, 0, -1, 1, 64, 5050851, 0, 0, 28, -1, 93897, 87, 0, 'Summon Spirit of Wolf Master Nandos', 0, 101, 13, 1, 0.0, 1, 0, 0);
INSERT INTO `spell_dbc` (`ActiveIconID`, `Attributes`, `AttributesEx`, `AttributesEx2`, `AttributesEx3`, `AttributesEx4`, `AttributesEx5`, `AttributesEx6`, `AttributesEx7`, `CastingTimeIndex`, `Description_Lang_enUS`, `DurationIndex`, `EffectAuraPeriod_1`, `EffectAura_1`, `EffectBasePoints_1`, `EffectDieSides_1`, `EffectMiscValueB_1`, `EffectMiscValue_1`, `EffectRadiusIndex_1`, `EffectTriggerSpell_1`, `Effect_1`, `EquippedItemClass`, `ID`, `ImplicitTargetA_1`, `ImplicitTargetB_1`, `Name_Lang_enUS`, `PowerType`, `ProcChance`, `RangeIndex`, `SchoolMask`, `Speed`, `SpellIconID`, `SpellVisualID_1`, `SpellVisualID_2`) VALUES (0, 256, 268435456, 4, 0, 0, 0, 0, 0, 1, '', 21, 0, 0, -1, 1, 64, 5050857, 0, 0, 28, -1, 93860, 87, 0, 'Summon Spirit of Odo the Blindwatcher', 0, 101, 13, 1, 0.0, 1, 0, 0);
INSERT INTO `spell_dbc` (`ActiveIconID`, `Attributes`, `AttributesEx`, `AttributesEx2`, `AttributesEx3`, `AttributesEx4`, `AttributesEx5`, `AttributesEx6`, `AttributesEx7`, `CastingTimeIndex`, `Description_Lang_enUS`, `DurationIndex`, `EffectAuraPeriod_1`, `EffectAura_1`, `EffectBasePoints_1`, `EffectDieSides_1`, `EffectMiscValueB_1`, `EffectMiscValue_1`, `EffectRadiusIndex_1`, `EffectTriggerSpell_1`, `Effect_1`, `EquippedItemClass`, `ID`, `ImplicitTargetA_1`, `ImplicitTargetB_1`, `Name_Lang_enUS`, `PowerType`, `ProcChance`, `RangeIndex`, `SchoolMask`, `Speed`, `SpellIconID`, `SpellVisualID_1`, `SpellVisualID_2`) VALUES (0, 256, 268435456, 4, 0, 0, 0, 0, 0, 1, '', 21, 0, 0, -1, 1, 64, 5050869, 0, 0, 28, -1, 93923, 87, 0, 'Summon Spirit of Razorclaw the Butcher', 0, 101, 13, 1, 0.0, 1, 0, 0);
INSERT INTO `spell_dbc` (`ActiveIconID`, `Attributes`, `AttributesEx`, `AttributesEx2`, `AttributesEx3`, `AttributesEx4`, `AttributesEx5`, `AttributesEx6`, `AttributesEx7`, `CastingTimeIndex`, `Description_Lang_enUS`, `DurationIndex`, `EffectAuraPeriod_1`, `EffectAura_1`, `EffectBasePoints_1`, `EffectDieSides_1`, `EffectMiscValueB_1`, `EffectMiscValue_1`, `EffectRadiusIndex_1`, `EffectTriggerSpell_1`, `Effect_1`, `EquippedItemClass`, `ID`, `ImplicitTargetA_1`, `ImplicitTargetB_1`, `Name_Lang_enUS`, `PowerType`, `ProcChance`, `RangeIndex`, `SchoolMask`, `Speed`, `SpellIconID`, `SpellVisualID_1`, `SpellVisualID_2`) VALUES (0, 256, 268435456, 4, 0, 0, 0, 0, 0, 1, '', 21, 0, 0, -1, 1, 64, 5050834, 0, 0, 28, -1, 93929, 87, 0, 'Summon Spirit of Rethilgore', 0, 101, 13, 1, 0.0, 1, 0, 0);

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
SELECT 'summon-chain spells now present (want 8)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `spell_dbc` WHERE `ID` IN (93858,93860,93895,93897,93922,93923,93926,93929)
UNION ALL SELECT 'of those, rows whose Effect_1 is SUMMON (want 8)', CAST(COUNT(*) AS CHAR)
    FROM `spell_dbc` WHERE `ID` IN (93858,93860,93895,93897,93922,93923,93926,93929) AND `Effect_1` = 28
UNION ALL SELECT 'summon targets missing from creature_template (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `spell_dbc` s LEFT JOIN `creature_template` c ON c.`entry` = s.`EffectMiscValue_1`
    WHERE s.`ID` IN (93858,93860,93895,93897,93922,93923,93926,93929) AND c.`entry` IS NULL
UNION ALL SELECT 'summon targets left on a raw retail entry (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `spell_dbc` WHERE `ID` IN (93858,93860,93895,93897,93922,93923,93926,93929)
      AND `EffectMiscValue_1` NOT BETWEEN 5000000 AND 5099999
UNION ALL SELECT 'Lupine Spirit target 5050923 exists (want 1, see note below)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` = 50923 + 5000000;

-- =====================================================================================
-- STILL OPEN: Summon Lupine Spirit (94199)
-- =====================================================================================
-- Wolf Master Nandos casts 94199 three times on arrival. That spell IS a real summon and
-- IS already in spell_dbc, but its EffectMiscValue_1 is 50923 -- the raw retail entry.
-- Neither 50923 nor 50923 + 5,000,000 exists in `creature_template` on this realm, so
-- the three spectres summon nothing.
--
-- Deliberately NOT fixed here: unlike the eight above, this needs a creature_template
-- row to be downported first (03_templates.sql never created one). Remapping the
-- MiscValue to 5050923 before that row exists would only move the failure. Once the
-- creature is in:
--     UPDATE `spell_dbc` SET `EffectMiscValue_1` = 50923 + 5000000 WHERE `ID` = 94199;
-- =====================================================================================
