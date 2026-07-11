-- Worgoblin: grant the faction-tongue LANGUAGE SKILL to the new races.
--
-- Root cause of "You don't know that language": WorldSession::HandleMessagechatOpcode
-- (src/server/game/Handlers/ChatHandler.cpp) gates chat on Player::HasSkill(langDesc->skill_id)
-- - SKILL_LANG_COMMON = 98, SKILL_LANG_ORCISH = 109 (src/server/shared/SharedDefines.h) -
-- NOT on the "Language: Common/Orcish" spell (668/669) granted in 04_playercreateinfo_spell_custom.sql.
-- Stock races get the skill via a dedicated playercreateinfo_skills row (raceMask-gated);
-- Worgen(12)/Goblin(9) were missing from those rows entirely, so a fresh worgen/goblin has
-- NO skill 98/109 at all (verified: NULL in character_skills for existing test characters)
-- and every chat attempt (not just near any particular NPC) fails with LANG_NOT_LEARNED_LANGUAGE.
UPDATE `playercreateinfo_skills` SET `raceMask` = `raceMask` | 2048 WHERE `skill` = 98;  -- Worgen -> Common
UPDATE `playercreateinfo_skills` SET `raceMask` = `raceMask` | 256  WHERE `skill` = 109; -- Goblin -> Orcish

-- Backfill existing race 9/12 characters created before this fix (idempotent).
INSERT INTO `character_skills` (`guid`, `skill`, `value`, `max`)
SELECT c.`guid`, 98, 300, 300 FROM `characters` c
WHERE c.`race` = 12
  AND NOT EXISTS (SELECT 1 FROM `character_skills` s WHERE s.`guid` = c.`guid` AND s.`skill` = 98);

INSERT INTO `character_skills` (`guid`, `skill`, `value`, `max`)
SELECT c.`guid`, 109, 300, 300 FROM `characters` c
WHERE c.`race` = 9
  AND NOT EXISTS (SELECT 1 FROM `character_skills` s WHERE s.`guid` = c.`guid` AND s.`skill` = 109);
