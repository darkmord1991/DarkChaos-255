-- SkillLineAbility: open FACTION-WIDE class spells to the custom races.
--
-- Player::IsSpellFitByClassAndRace() gates every learnable spell on SkillLineAbility.RaceMask,
-- and the DC level-up learner (dc_firststart_learnspells.cpp) calls it before teaching anything.
-- 10,099 of 10,229 rows use RaceMask 0 (all races) and are fine; the rest name races explicitly.
--
-- Only rows naming at least THREE stock races of a faction are touched. That is the line between
-- a faction-gated CLASS spell (mage portals, paladin seals and class mounts, shaman Bloodlust,
-- the faction languages) and a RACIAL, which names one race. A blanket faction sweep here would
-- hand Zandalari War Stomp, Blood Fury, Shadowmeld and Arcane Torrent -- ClassMask is NOT a safe
-- discriminator either, since Blood Fury and Arcane Torrent carry one.
--
-- skilllineability_dbc is empty on a stock install: these rows OVERRIDE the .dbc entries of the
-- same ID (DBCStores.cpp LoadDBC runs storage.LoadFromDB AFTER reading the file), so the
-- WORLDSERVER needs no DBC deploy.
--
-- The CLIENT does. It never sees this table -- it reads DBFilesClient\SkillLineAbility.dbc out of
-- the MPQ chain -- so an overlay row here and a stale .dbc there silently disagree. That gap sat
-- open on rows 590/592 (the two faction LANGUAGES) until 2026-09-05: the client's copy still
-- carried the stock+worgoblin masks 3149/946, listing none of races 22-27. Whenever a row here is
-- re-masked, mirror it into `Custom/DBCs/SkillLineAbility.dbc` and deploy that to patch-4 plus the
-- enGB patch chain (which outranks the numbered patches). Same rule for skillraceclassinfo_dbc.

DELETE FROM `skilllineability_dbc` WHERE `ID` IN (590, 592, 20867, 20868, 14779, 14787, 14788, 18299, 20289, 20290, 3269, 3270, 3271, 3272, 3273, 3274, 5989, 5990, 5991, 5992, 5993, 5994, 14815, 14816, 14817, 14818, 15040, 15041, 15606, 15607, 16999, 17000, 17003, 17004, 21723, 13151, 21724, 7594, 12518, 20089, 20091, 20110, 20283);
INSERT INTO `skilllineability_dbc` (`ID`, `SkillLine`, `Spell`, `RaceMask`, `ClassMask`, `ExcludeRace`, `ExcludeClass`, `MinSkillLineRank`, `SupercededBySpell`, `AcquireMethod`, `TrivialSkillLineRankHigh`, `TrivialSkillLineRankLow`, `CharacterPoints_1`, `CharacterPoints_2`) VALUES
(590, 98, 668, 35654733, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0),
(592, 109, 669, 29361074, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0),
(20867, 183, 63645, 65015807, 1535, 0, 0, 1, 0, 2, 0, 0, 0, 0),
(20868, 183, 63644, 65015807, 1535, 0, 0, 1, 0, 2, 0, 0, 0, 0),
(14779, 184, 31801, 35652613, 2, 0, 0, 1, 0, 0, 0, 0, 0, 0),
(14787, 184, 31803, 35652613, 2, 0, 0, 1, 0, 0, 0, 0, 0, 0),
(14788, 184, 31804, 35652613, 2, 0, 0, 1, 0, 0, 0, 0, 0, 0),
(18299, 184, 53726, 35652613, 2, 0, 0, 1, 0, 0, 0, 0, 0, 0),
(20289, 202, 60867, 35654733, 0, 0, 0, 1, 0, 0, 490, 480, 0, 0),
(20290, 202, 60866, 29361074, 0, 0, 0, 1, 0, 0, 490, 480, 0, 0),
(3269, 237, 3565, 35654733, 128, 0, 0, 1, 0, 0, 0, 0, 0, 0),
(3270, 237, 3562, 35654733, 128, 0, 0, 1, 0, 0, 0, 0, 0, 0),
(3271, 237, 3567, 29361074, 128, 0, 0, 1, 0, 0, 0, 0, 0, 0),
(3272, 237, 3561, 35654733, 128, 0, 0, 1, 0, 0, 0, 0, 0, 0),
(3273, 237, 3566, 29361074, 128, 0, 0, 1, 0, 0, 0, 0, 0, 0),
(3274, 237, 3563, 29361074, 128, 0, 0, 1, 0, 0, 0, 0, 0, 0),
(5989, 237, 11419, 35654733, 128, 0, 0, 1, 0, 0, 0, 0, 0, 0),
(5990, 237, 11416, 35654733, 128, 0, 0, 1, 0, 0, 0, 0, 0, 0),
(5991, 237, 11417, 29361074, 128, 0, 0, 1, 0, 0, 0, 0, 0, 0),
(5992, 237, 10059, 35654733, 128, 0, 0, 1, 0, 0, 0, 0, 0, 0),
(5993, 237, 11420, 29361074, 128, 0, 0, 1, 0, 0, 0, 0, 0, 0),
(5994, 237, 11418, 29361074, 128, 0, 0, 1, 0, 0, 0, 0, 0, 0),
(14815, 237, 32271, 35654733, 128, 0, 0, 1, 0, 0, 0, 0, 0, 0),
(14816, 237, 32272, 29361074, 128, 0, 0, 1, 0, 0, 0, 0, 0, 0),
(14817, 237, 32266, 35654733, 128, 0, 0, 1, 0, 0, 0, 0, 0, 0),
(14818, 237, 32267, 29361074, 128, 0, 0, 1, 0, 0, 0, 0, 0, 0),
(15040, 237, 33690, 35654733, 128, 0, 0, 1, 0, 0, 0, 0, 0, 0),
(15041, 237, 33691, 35654733, 128, 0, 0, 1, 0, 0, 0, 0, 0, 0),
(15606, 237, 35715, 29361074, 128, 0, 0, 1, 0, 0, 0, 0, 0, 0),
(15607, 237, 35717, 29361074, 128, 0, 0, 1, 0, 0, 0, 0, 0, 0),
(16999, 237, 49359, 35654733, 128, 0, 0, 1, 0, 0, 0, 0, 0, 0),
(17000, 237, 49358, 29361074, 128, 0, 0, 1, 0, 0, 0, 0, 0, 0),
(17003, 237, 49361, 29361074, 128, 0, 0, 1, 0, 0, 0, 0, 0, 0),
(17004, 237, 49360, 35654733, 128, 0, 0, 1, 0, 0, 0, 0, 0, 0),
(21723, 253, 75460, 65015807, 8, 0, 0, 1, 0, 2, 0, 0, 0, 0),
(13151, 373, 2825, 29360546, 64, 0, 0, 1, 0, 0, 0, 0, 0, 0),
(21724, 375, 75461, 65015807, 64, 0, 0, 1, 0, 2, 0, 0, 0, 0),
(7594, 594, 13819, 35652613, 2, 0, 0, 1, 0, 0, 0, 0, 0, 0),
(12518, 594, 23214, 35652613, 2, 0, 0, 1, 0, 0, 0, 0, 0, 0),
(20089, 777, 23214, 35652613, 2, 0, 0, 1, 0, 0, 0, 0, 0, 0),
(20091, 777, 13819, 35652613, 2, 0, 0, 1, 0, 0, 0, 0, 0, 0),
(20110, 777, 55531, 29361074, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0),
(20283, 777, 60424, 35654733, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0);
