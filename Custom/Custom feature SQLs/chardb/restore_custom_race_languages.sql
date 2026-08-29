-- Restore the faction language skill on custom-race characters that lost it.
--
-- RUN AGAINST acore_characters (the character database), not acore_world.
--
-- Why they lost it: Player::_LoadSkills validates every skill against SkillRaceClassInfo on
-- login and DELETES anything the race/class is not allowed to have. Vulpera/Zandalari/Kul Tiran
-- were missing from those rows (see AlliedRaces/14_playability_fixes.sql), so their language was
-- stripped the first time they logged in.
--
-- Why it stops them chatting: WorldSession::HandleMessagechatOpcode rejects the message outright
-- with LANG_NOT_LEARNED_LANGUAGE when the sender lacks the language SKILL -- ChatHandler.cpp:99.
-- That check runs BEFORE the per-type handling, so it blocks guild chat too, even though guild
-- broadcast itself then uses LANG_UNIVERSAL. Hence "cannot chat in the newcomer guild".
--
-- Fix the world DB first, or the validator will simply delete these rows again on next login.
--
-- Language by race:  Alliance -> 98 Common,  Horde -> 109 Orcish
--   22 Pandaren (A), 26 Kul Tiran, 27 Dark Iron  -> 98
--   23 Pandaren (H), 24 Vulpera,   25 Zandalari  -> 109
-- Languages are always value/max 300, matching every existing row.

INSERT INTO `character_skills` (`guid`, `skill`, `value`, `max`)
SELECT c.`guid`, 98, 300, 300 FROM `characters` c
WHERE c.`race` IN (22, 26, 27)
  AND NOT EXISTS (SELECT 1 FROM `character_skills` s WHERE s.`guid` = c.`guid` AND s.`skill` = 98);

INSERT INTO `character_skills` (`guid`, `skill`, `value`, `max`)
SELECT c.`guid`, 109, 300, 300 FROM `characters` c
WHERE c.`race` IN (23, 24, 25)
  AND NOT EXISTS (SELECT 1 FROM `character_skills` s WHERE s.`guid` = c.`guid` AND s.`skill` = 109);

-- Armour proficiencies, for characters whose class should have them and whose skill was deleted.
-- Cloth: every class. Leather: everyone except mage(8)/priest(5)/warlock(9).
-- Mail: warrior(1)/paladin(2)/hunter(3)/shaman(7). Plate: warrior(1)/paladin(2)/death knight(6).
INSERT INTO `character_skills` (`guid`, `skill`, `value`, `max`)
SELECT c.`guid`, 415, 1, 1 FROM `characters` c
WHERE c.`race` IN (22, 23, 24, 25, 26, 27)
  AND NOT EXISTS (SELECT 1 FROM `character_skills` s WHERE s.`guid` = c.`guid` AND s.`skill` = 415);

INSERT INTO `character_skills` (`guid`, `skill`, `value`, `max`)
SELECT c.`guid`, 414, 1, 1 FROM `characters` c
WHERE c.`race` IN (22, 23, 24, 25, 26, 27) AND c.`class` NOT IN (5, 8, 9)
  AND NOT EXISTS (SELECT 1 FROM `character_skills` s WHERE s.`guid` = c.`guid` AND s.`skill` = 414);

INSERT INTO `character_skills` (`guid`, `skill`, `value`, `max`)
SELECT c.`guid`, 413, 1, 1 FROM `characters` c
WHERE c.`race` IN (22, 23, 24, 25, 26, 27) AND c.`class` IN (1, 2, 3, 7)
  AND NOT EXISTS (SELECT 1 FROM `character_skills` s WHERE s.`guid` = c.`guid` AND s.`skill` = 413);

INSERT INTO `character_skills` (`guid`, `skill`, `value`, `max`)
SELECT c.`guid`, 293, 1, 1 FROM `characters` c
WHERE c.`race` IN (22, 23, 24, 25, 26, 27) AND c.`class` IN (1, 2, 6)
  AND NOT EXISTS (SELECT 1 FROM `character_skills` s WHERE s.`guid` = c.`guid` AND s.`skill` = 293);
