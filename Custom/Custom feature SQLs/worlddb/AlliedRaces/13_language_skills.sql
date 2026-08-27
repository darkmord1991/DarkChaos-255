-- Allied races: the LANGUAGE SKILL (chat gates on the skill, not the language spell).
-- SKILL_LANG_COMMON = 98, SKILL_LANG_ORCISH = 109.
UPDATE `playercreateinfo_skills` SET `raceMask` = `raceMask` | 33554432 WHERE `skill` = 98;   -- Kul Tiran -> Common
UPDATE `playercreateinfo_skills` SET `raceMask` = `raceMask` | 25165824 WHERE `skill` = 109;  -- Vulpera + Zandalari -> Orcish
