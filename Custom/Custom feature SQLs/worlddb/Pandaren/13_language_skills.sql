-- Pandaren: grant the faction-tongue LANGUAGE SKILL (chat gates on the skill, not
-- the language spell - see Worgoblin/13_language_skills.sql for the full root cause;
-- WorldSession::HandleMessagechatOpcode checks Player::HasSkill(langDesc->skill_id)).
-- SKILL_LANG_COMMON = 98, SKILL_LANG_ORCISH = 109.
UPDATE `playercreateinfo_skills` SET `raceMask` = `raceMask` | 2097152 WHERE `skill` = 98;  -- Pandaren A -> Common
UPDATE `playercreateinfo_skills` SET `raceMask` = `raceMask` | 4194304 WHERE `skill` = 109; -- Pandaren H -> Orcish

-- ======================================================================
-- CHARACTERS DB (acore_characters), NOT world! Backfill for any race 22/23
-- characters created before this fix. Uncomment and run separately.
-- ======================================================================
-- INSERT INTO `character_skills` (`guid`, `skill`, `value`, `max`)
-- SELECT c.`guid`, 98, 300, 300 FROM `characters` c
-- WHERE c.`race` = 22
--   AND NOT EXISTS (SELECT 1 FROM `character_skills` s WHERE s.`guid` = c.`guid` AND s.`skill` = 98);
-- INSERT INTO `character_skills` (`guid`, `skill`, `value`, `max`)
-- SELECT c.`guid`, 109, 300, 300 FROM `characters` c
-- WHERE c.`race` = 23
--   AND NOT EXISTS (SELECT 1 FROM `character_skills` s WHERE s.`guid` = c.`guid` AND s.`skill` = 109);
