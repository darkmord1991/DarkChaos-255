-- =====================================================================
-- Deepholm Downport  --  13  spell_area  (Cata map 646)
-- ---------------------------------------------------------------------
-- Source: cata_world (TrinityCore 4.3.4).  Target: acore_world.
-- REQUIRES cata_world present on the same server at import time (read-only).
--
-- Area-applied auras for the Deepholm sub-areas. 15 rows.
-- Mapping: Cata `flags` (bitmask) -> this fork's `autocast` (the autocast bit,
-- flags & 1). racemask kept as-is (Cata-only race bits simply never match a
-- 3.3.5 player, so they fail safe).
--
-- SCOPE: the Deepholm sub-areas EXCLUDING 5042 -- in this fork area 5042 is
-- "Camp Nooka Nooka" (the retail-5042-vs-authored-4922 zone conflict), so we do
-- NOT touch it here. If/when the zone is reconciled, add the 5042 spell_area rows
-- (remapped to 4922 per Option A in the feasibility report).
--
-- NOTE: several aura_spells are Cata-era ids absent from 3.3.5 Spell.dbc. Those
-- rows are inert (the core logs "spell does not exist" and skips them) until the
-- spell is authored. The storyline PHASE auras specifically must be re-authored
-- with the correct 3.3.5 phasemask BIT (see the PhaseId->bit map in 00_README and
-- the P3 storyline plan) -- a straight import will not reveal the bit-mapped
-- storyline spawns on its own.
-- =====================================================================

DELETE FROM `spell_area`
WHERE `area` IN (5291,5292,5293,5294,5295,5296,5297,5298,5299,5300,5302,5303,5313,5328,5329,5330,5331,5335,5338,5349,5350,5352,5354,5355,5357,5358,5368,5394,5395,5418,5797);

INSERT INTO `spell_area`
(`spell`,`area`,`quest_start`,`quest_end`,`aura_spell`,`racemask`,`gender`,`autocast`,`quest_start_status`,`quest_end_status`)
SELECT `spell`,`area`,`quest_start`,`quest_end`,`aura_spell`,`racemask`,`gender`,(`flags` & 1),`quest_start_status`,`quest_end_status`
FROM `cata_world`.`spell_area`
WHERE `area` IN (5291,5292,5293,5294,5295,5296,5297,5298,5299,5300,5302,5303,5313,5328,5329,5330,5331,5335,5338,5349,5350,5352,5354,5355,5357,5358,5368,5394,5395,5418,5797);
