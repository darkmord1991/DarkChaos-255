-- Custom-race racials: grant them the way stock racials are granted, through SkillLineAbility.
--
-- Every custom racial (Pandaren, Vulpera, Zandalari, Kul Tiran, Dark Iron) was granted ONLY by a
-- playercreateinfo_spell_custom row. Player::LearnCustomSpells() reads that table only when
-- worldserver.conf has PlayerStart.CustomSpells = 1, and the live server runs 0 -- because the same
-- table also carries the ~700-row "start with every class spell" set for every race, which that
-- switch would push onto every character at every login. So no custom racial has ever been learned
-- (checked 2026-09-26: 0 of ~4,000 characters of races 22-27 know one).
--
-- Stock racials do not use that table. Stoneform is SkillLineAbility row 11727: skill line 101
-- (Racial - Dwarf), RaceMask 4, AcquireMethod 2 (learned on skill learn). At every login
-- Player::_LoadSkills -> learnSkillRewardedSpells(skill) teaches each ability of each skill the
-- character has whose RaceMask matches, and the spell is not stored in character_spell.
--
-- The custom races have no racial skill line, but every one of them has its faction language skill
-- (playercreateinfo_skills: Common 98 raceMask 102763597, Orcish 109 raceMask 29361074), so the
-- racials ride those lines with the race's own bit as RaceMask. Nothing else can pick them up:
-- Player::IsSpellFitByClassAndRace() now finds a SkillLineAbility row that names one race.
--
-- skilllineability_dbc is the server-side overlay (DBCStores LOAD_DBC reads the table after the
-- file, and the per-skill-line index is built after that), so no worldserver DBC deploy. The client
-- does not need these rows: the spells are in its Spell.dbc and show in the General tab.
--
-- Ids 31501-31523: the client SkillLineAbility.dbc stops at 31448 and this table at 21724.
-- Not granted: 312925 (Nose for Trouble's triggered hit) and 265227 (Dungeon Delver's indoor
-- speed, applied by src/server/scripts/DC/Races/dc_dark_iron.cpp).
--
-- Needs the spell rows first: Pandaren/10_spell_dbc.sql, AlliedRaces/10_spell_dbc.sql,
-- Tier1Reskins/03_darkiron_spell_dbc.sql. A row whose spell the server does not know is skipped.

DELETE FROM `skilllineability_dbc` WHERE `ID` BETWEEN 31501 AND 31523;
INSERT INTO `skilllineability_dbc` (`ID`, `SkillLine`, `Spell`, `RaceMask`, `ClassMask`, `ExcludeRace`, `ExcludeClass`, `MinSkillLineRank`, `SupercededBySpell`, `AcquireMethod`, `TrivialSkillLineRankHigh`, `TrivialSkillLineRankLow`, `CharacterPoints_1`, `CharacterPoints_2`) VALUES
-- Alliance, skill 98 (Language: Common)
-- Pandaren (A) 22 = 1 << 21
(31501, 98, 107072, 2097152, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0),    -- Epicurean
(31502, 98, 107073, 2097152, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0),    -- Gourmand
(31503, 98, 107074, 2097152, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0),    -- Inner Peace
(31504, 98, 107076, 2097152, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0),    -- Bouncy
(31505, 98, 107079, 2097152, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0),    -- Quaking Palm
-- Kul Tiran 26 = 1 << 25
(31506, 98, 287712, 33554432, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0),   -- Haymaker
(31507, 98, 280331, 33554432, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0),   -- Child of the Sea
(31508, 98, 287829, 33554432, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0),   -- Rime of the Ancient Mariner
-- Dark Iron Dwarf 27 = 1 << 26
(31509, 98, 265221, 67108864, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0),   -- Fireblood
(31510, 98, 265224, 67108864, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0),   -- Forged in Flames
(31511, 98, 265222, 67108864, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0),   -- Mass Production
(31512, 98, 265223, 67108864, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0),   -- Dungeon Delver
-- Horde, skill 109 (Language: Orcish)
-- Pandaren (H) 23 = 1 << 22
(31513, 109, 107072, 4194304, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0),   -- Epicurean
(31514, 109, 107073, 4194304, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0),   -- Gourmand
(31515, 109, 107074, 4194304, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0),   -- Inner Peace
(31516, 109, 107076, 4194304, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0),   -- Bouncy
(31517, 109, 107079, 4194304, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0),   -- Quaking Palm
-- Vulpera 24 = 1 << 23
(31518, 109, 312411, 8388608, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0),   -- Bag of Tricks
(31519, 109, 312924, 8388608, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0),   -- Nose for Trouble
(31520, 109, 265225, 8388608, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0),   -- Fire Resistance
-- Zandalari Troll 25 = 1 << 24
(31521, 109, 291944, 16777216, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0),  -- Regeneratin'
(31522, 109, 281954, 16777216, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0),  -- Pterrordax Swoop
(31523, 109, 291628, 16777216, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0);  -- City of Gold
