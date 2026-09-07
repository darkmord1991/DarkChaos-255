-- Worgoblin: give worgen (race 12) the SkillRaceClassInfo coverage it never got.
-- Target: acore_world. Server-side only -- see the note at the bottom.
--
-- ROOT CAUSE
-- ----------
-- Player::_LoadSkills (src/server/game/Entities/Player/Player.cpp) validates every row of
-- `character_skills` at login against GetSkillRaceClassInfo(skill, race, class). A skill with no
-- matching SkillRaceClassInfo row is not merely ignored -- it is marked SKILL_DELETED and removed:
--
--     Player Terineva (GUID: 3344), has skill (293) that is invalid for the race/class
--     combination (Race: 12, Class: 1). Will be deleted.
--
-- Everything the character was wearing that needed the lost proficiency then fails to load and is
-- posted to the mailbox instead (EQUIP_ERR_NO_REQUIRED_PROFICIENCY, "reason 8"):
--
--     Player::_LoadInventory: player ... 'Terineva' has item (... entry: 400933) which can't be
--     loaded into inventory (Bag GUID: 0, slot: 0) by reason 8. Item will be sent by mail.
--
-- Race 12 is playable here (670 characters, 148 of them warriors/paladins) but the migration that
-- widened these RaceMasks for the other custom races skipped it. Coverage today:
--
--     race  1 Human ............ 182 rows
--     race 26 Kul Tiran ........ 185 rows   (strict superset of Human -- 0 gaps)
--     race 12 Worgen ........... 131 rows   <-- 53 of Human's rows missing
--
-- The 53 missing rows are weapon/armor proficiencies (incl. Plate Mail), the riding skills and the
-- languages. Plate Mail is the visible one because it has TWO rows and only one was widened:
--
--     SkillID 293  ClassMask 32 (Death Knight)      RaceMask 132382719  -> worgen present
--     SkillID 293  ClassMask  3 (Warrior|Paladin)   RaceMask 132122623  -> worgen MISSING
--
-- which is why worgen death knights kept their plate and worgen warriors did not.

-- ---------------------------------------------------------------------------
-- [1] Mirror race 1 (Human) onto race 12 (Worgen).
--
-- This is the rule DC already applied to the other Human-donor custom races -- Kul Tiran (26) has
-- every row Human has -- and the same idiom 06_race_mask_sweeps.sql uses for quest_template and
-- item_template ("|2048 WHERE & 1"). Worgen borrows Human throughout: playercreateinfo puts it on
-- the Human start, BotStartLocations maps RACE_WORGEN -> RACE_HUMAN, ChrRaces gives it faction 1.
--
-- Idempotent: rows that already carry 2048 are left as they are. Affects 53 rows.
-- ---------------------------------------------------------------------------
UPDATE `skillraceclassinfo_dbc` SET `RaceMask` = `RaceMask` | 2048 WHERE `RaceMask` & 1;

-- ---------------------------------------------------------------------------
-- [2] Racial skill lines 789 (Worgen) / 790 (Goblin).
--
-- 03_playercreateinfo_skills.sql grants these to every new worgen/goblin, but neither skill has a
-- SkillRaceClassInfo row at all, so _LoadSkills strips it again on the character's first login.
-- All 670 race-12 characters currently hold skill 789 only because most are bots that have not
-- logged in yet.
--
-- Flags/ClassMask copied from the stock racial rows (e.g. ID 862, SkillID 754 "Racial - Human").
-- IDs 971/972 are free -- MAX(ID) in this table is 970.
-- ---------------------------------------------------------------------------
DELETE FROM `skillraceclassinfo_dbc` WHERE `ID` IN (971, 972);
INSERT INTO `skillraceclassinfo_dbc` (`ID`, `SkillID`, `RaceMask`, `ClassMask`, `Flags`, `MinLevel`, `SkillTierID`, `SkillCostIndex`) VALUES
(971, 789, 2048, 1535, 1170, 0, 0, 0),  -- Worgen - Racial (race 12)
(972, 790,  256, 1535, 1170, 0, 0, 0);  -- Goblin - Racial (race 9)

-- ---------------------------------------------------------------------------
-- VERIFY (expect 0 rows from the first query, 2 from the second)
-- ---------------------------------------------------------------------------
-- SELECT ID, SkillID, ClassMask, RaceMask FROM `skillraceclassinfo_dbc`
--   WHERE (`RaceMask` & 1) AND (`RaceMask` & 2048) = 0;
-- SELECT ID, SkillID, RaceMask FROM `skillraceclassinfo_dbc` WHERE `SkillID` IN (789, 790);

-- ---------------------------------------------------------------------------
-- NOTE: skillraceclassinfo_dbc is the server-side overlay merged into
-- sSkillRaceClassInfoStore by DBCStores.cpp:368
--   LOAD_DBC(sSkillRaceClassInfoStore, "SkillRaceClassInfo.dbc", "skillraceclassinfo_dbc")
-- so this takes effect on the next worldserver restart with no client patch. The client's own
-- copy of SkillRaceClassInfo.dbc only drives the character-creation UI; proficiency enforcement
-- and the skill deletion above are both server-side.
--
-- Characters that ALREADY lost a skill do not get it back from this file -- a deleted row is gone
-- from `character_skills`. See:
--   Custom/Custom feature SQLs/chardb/restore_worgen_stripped_skills.sql
