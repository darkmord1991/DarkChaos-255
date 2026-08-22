-- -------------------------------------------------------------------------
-- Set 924 Gladiator's Desecration -- already fully supported, data only
-- -------------------------------------------------------------------------
-- This set was in the "needs C++" bucket, but it needs nothing at all.
--
-- Its 4pc is spell 61257, a WotLK-era Death Knight PvP set bonus that AzerothCore
-- ALREADY implements: spell_dk.cpp defines spell_dk_pvp_4p_bonus (an AuraScript on
-- EFFECT_0 / SPELL_AURA_DUMMY that procs on MECHANIC_ROOT or MECHANIC_SNARE and
-- casts SPELL_DK_RUNIC_RETURN 61258), and it is registered via RegisterSpellScript
-- at spell_dk.cpp:3077.
--
-- All four of its spells already resolve in stock Spell.dbc -- 61257, 92252, 92253,
-- 92254 -- as does the 61258 the script casts. So no spell_dbc rows are needed and
-- no new C++ is needed; only the set row and the item wiring were missing.
--
-- Worth re-checking the rest of the C++ bucket for this shape: a Cata set whose
-- bonus reuses a WotLK spell id may already be scripted upstream. A scan of all 44
-- dummy/script spells across the 35 sets found 61257 to be the ONLY one, but the
-- check is cheap and the payoff is a free set.
--
-- Idempotent.
-- -------------------------------------------------------------------------

DELETE FROM `itemset_dbc` WHERE `ID` = 924;

INSERT INTO `itemset_dbc`
    (`ID`, `Name_Lang_enUS`, `Name_Lang_enGB`, `Name_Lang_koKR`, `Name_Lang_frFR`, `Name_Lang_deDE`, `Name_Lang_enCN`, `Name_Lang_zhCN`, `Name_Lang_enTW`, `Name_Lang_zhTW`, `Name_Lang_esES`, `Name_Lang_esMX`, `Name_Lang_ruRU`, `Name_Lang_ptPT`, `Name_Lang_ptBR`, `Name_Lang_itIT`, `Name_Lang_Unk`, `Name_Lang_Mask`, `ItemID_1`, `ItemID_2`, `ItemID_3`, `ItemID_4`, `ItemID_5`, `ItemID_6`, `ItemID_7`, `ItemID_8`, `ItemID_9`, `ItemID_10`, `ItemID_11`, `ItemID_12`, `ItemID_13`, `ItemID_14`, `ItemID_15`, `ItemID_16`, `ItemID_17`, `SetSpellID_1`, `SetSpellID_2`, `SetSpellID_3`, `SetSpellID_4`, `SetSpellID_5`, `SetSpellID_6`, `SetSpellID_7`, `SetSpellID_8`, `SetThreshold_1`, `SetThreshold_2`, `SetThreshold_3`, `SetThreshold_4`, `SetThreshold_5`, `SetThreshold_6`, `SetThreshold_7`, `SetThreshold_8`, `RequiredSkill`, `RequiredSkillRank`)
VALUES
  (924, 'Gladiator''s Desecration', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 64982, 64981, 64980, 64979, 64978, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 92254, 92253, 61257, 92252, 0, 0, 0, 0, 2, 2, 4, 4, 0, 0, 0, 0, 0, 0);

UPDATE `item_template` SET `itemset` = 924 WHERE `entry` IN (64978, 64979, 64980, 64981, 64982);

-- -------------------------------------------------------------------------
-- Verification
-- -------------------------------------------------------------------------
--   SELECT COUNT(*) FROM itemset_dbc;                          -- 53
--   SELECT COUNT(*) FROM item_template WHERE itemset = 924;    -- 5
-- -------------------------------------------------------------------------
