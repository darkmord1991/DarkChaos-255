-- EffectRadiusIndex repair for Cataclysm spells in spell_dbc -- the Silverpine port's spells (112_).
--
-- Cataclysm's SpellEffect.dbc leaves EffectRadiusIndex at 0 on many area effects and stores the radius in
-- EffectRadiusMaxIndex; TrinityCore 4.3.4 (SpellEffectInfo::CalcRadius) falls back to the max entry when the
-- plain one is 0. 3.3.5 has one radius column and the downport generators (HyjalCata/194_, 112_ and the ones
-- after them) copied only EffectRadiusIndex, so these area/cone effects searched a radius of 0 and hit nobody.
--
-- Each value is the Cata EffectRadiusMaxIndex of the same spell id and effect index, read from the 4.3.4
-- client (K:/UntouchedClients/Cata/Data/enUS/locale-enUS.MPQ SpellEffect.dbc). Every spell's name was checked
-- against the Cata Spell.dbc name first. Radius ids 1-65 are identical in both clients; the two Cata-only ids
-- used are mapped to ours: 67 (30 yd) -> 10 (30 yd) and 84 (17 yd) -> 19 (18 yd, nearest).
-- Only effects whose radius is still 0 are touched, so the file is safe to re-run.
-- Generator: K:/Dark-Chaos/retailextracts/_spellradius_fix_20261109/_scripts/ (plan_radius_fix.py, write_radius_sql.py).
-- Raise Forsaken 83173 is the cast that stands the fallen humans up in "The Warchief Cometh".
-- 14 effects in 8 spells.

-- 83173 Raise Forsaken
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 10 WHERE `ID` = 83173 AND `EffectRadiusIndex_1` = 0;

-- 83903 Bush Chicken Explosion!
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 13 WHERE `ID` = 83903 AND `EffectRadiusIndex_1` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_3` = 13 WHERE `ID` = 83903 AND `EffectRadiusIndex_3` = 0;

-- 84012 Doomhowl
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 32 WHERE `ID` = 84012 AND `EffectRadiusIndex_1` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 32 WHERE `ID` = 84012 AND `EffectRadiusIndex_2` = 0;

-- 84474 Explosion
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 11 WHERE `ID` = 84474 AND `EffectRadiusIndex_1` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 11 WHERE `ID` = 84474 AND `EffectRadiusIndex_2` = 0;

-- 85197 Raise Forsaken
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 10 WHERE `ID` = 85197 AND `EffectRadiusIndex_1` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 10 WHERE `ID` = 85197 AND `EffectRadiusIndex_2` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_3` = 10 WHERE `ID` = 85197 AND `EffectRadiusIndex_3` = 0;

-- 85373 Dimensional Beam
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 33 WHERE `ID` = 85373 AND `EffectRadiusIndex_1` = 0;

-- 85950 Raise Forsaken
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 33 WHERE `ID` = 85950 AND `EffectRadiusIndex_1` = 0;

-- 87249 Arcane Expulsion
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 13 WHERE `ID` = 87249 AND `EffectRadiusIndex_2` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_3` = 13 WHERE `ID` = 87249 AND `EffectRadiusIndex_3` = 0;
