-- Worgoblin: give back the skills that were stripped from existing race 12 (worgen) characters.
-- Target: acore_characters. Run AFTER worlddb/Worgoblin/15_skillraceclassinfo.sql and a restart.
--
-- Player::_LoadSkills deletes any `character_skills` row with no SkillRaceClassInfo entry for the
-- character's race/class. Worgen was missing 53 of Human's rows, so every worgen that logged in
-- lost those skills permanently -- the world-DB fix stops the bleeding but cannot undo it, because
-- the rows are already gone from this table.
--
-- Only Plate Mail is restored here. The other 52 skills are either trainer-taught at a level the
-- affected characters have not reached, or were never granted in the first place; re-adding them
-- wholesale would hand out proficiencies the character never earned. Plate Mail is different: it
-- is the one that silently unequipped worn gear and mailed it away.
--
-- Gated on level >= 40, which is where warriors and paladins learn Plate Mail (spell 750). Verified
-- against unaffected races on this realm: the lowest character holding skill 293 is level 41.
--
-- Idempotent -- re-running inserts nothing.

-- ---------------------------------------------------------------------------
-- Preview first (expect 4 rows as of the 2026-09-07 audit, Terineva among them)
-- ---------------------------------------------------------------------------
-- SELECT c.guid, c.name, c.level, c.`class`
-- FROM `characters` c
-- WHERE c.race = 12 AND c.`class` IN (1, 2) AND c.level >= 40
--   AND NOT EXISTS (SELECT 1 FROM `character_skills` s WHERE s.guid = c.guid AND s.skill = 293);

INSERT INTO `character_skills` (`guid`, `skill`, `value`, `max`)
SELECT c.`guid`, 293, 1, 1
FROM `characters` c
WHERE c.`race` = 12
  AND c.`class` IN (1, 2)
  AND c.`level` >= 40
  AND NOT EXISTS (SELECT 1 FROM `character_skills` s WHERE s.`guid` = c.`guid` AND s.`skill` = 293);

-- Plate Mail is a pass/fail proficiency, not a levelled skill: stock rows carry value = max = 1.
--
-- Items already posted to the mailbox stay there -- the character can simply take them back out
-- and re-equip once the proficiency is present again.
