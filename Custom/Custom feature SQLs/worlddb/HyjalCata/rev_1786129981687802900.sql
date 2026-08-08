--
-- Fix: "Auras: unknown creature id = 42193 ... From Spell Aura Transform in Spell ID = 78703"
--
-- Spell 78703 'Ghostform' (custom spell_dbc row, Cata downport) has an
-- SPELL_AURA_TRANSFORM effect whose EffectMiscValue_1 is the raw Cata creature id
-- 42193 'Ghostpaw Runner'. The clone import brought the Cata SmartAI across (casters
-- 3703823 / 3703825 on map 750) but embedded ids inside spell effects keep their raw
-- value, and 42193 was never imported -- the WotLK Ghostpaw Runner is entry 3823.
-- With no template to read a model from, the core falls back to display 16358 (pink pig)
-- and logs the error on every aura application.
--
-- Display 2446 (model 171, texture WolfSkin_Ghost) is the model the Cata template used;
-- it already exists in CreatureDisplayInfo.dbc and creature_model_info, so only the
-- template + template_model rows are missing. Entry 42193 is free and matches the
-- fork's existing practice of importing Cata content at its raw id in this band.

-- REPLACE (not DELETE + INSERT): `creature_template` is a protected table for the
-- SQL codestyle check, which forbids DELETE against it.
REPLACE INTO `creature_template` (`entry`, `name`, `subname`, `minlevel`, `maxlevel`, `faction`, `speed_walk`, `speed_run`, `unit_class`, `family`, `type`, `type_flags`, `AIName`) VALUES
(42193, 'Ghostpaw Runner', NULL, 19, 20, 1712, 1, 1.14286, 1, 1, 1, 1, '');

DELETE FROM `creature_template_model` WHERE `CreatureID` = 42193;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`) VALUES
(42193, 0, 2446, 1, 1);
