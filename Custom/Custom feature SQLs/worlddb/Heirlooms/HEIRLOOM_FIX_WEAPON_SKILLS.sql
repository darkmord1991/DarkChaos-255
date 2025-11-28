-- ============================================================================
-- HEIRLOOM WEAPONS - FIX REQUIRED SKILL DISPLAY
-- ============================================================================
-- Problem: Heirloom weapons don't show "Requires [Weapon Skill]" in tooltip
--          even though the game checks proficiency when equipping.
-- 
-- Solution: Set proper RequiredSkill values so tooltip displays the requirement.
--
-- Weapon Skill IDs (from SkillLine.dbc):
--   43  = Swords (One-Hand)
--   44  = Axes (One-Hand)
--   45  = Bows
--   46  = Guns
--   54  = Maces (One-Hand)
--   55  = Two-Handed Swords
--   136 = Staves
--   160 = Two-Handed Maces
--   172 = Two-Handed Axes
--   173 = Daggers
--   176 = Thrown
--   226 = Crossbows
--   228 = Wands
--   229 = Polearms
--   473 = Fist Weapons
--
-- Item Subclass Reference (class=2 Weapons):
--   0  = One-Hand Axe
--   1  = Two-Hand Axe
--   2  = Bow
--   3  = Gun
--   4  = One-Hand Mace
--   5  = Two-Hand Mace
--   6  = Polearm
--   7  = One-Hand Sword
--   8  = Two-Hand Sword
--   10 = Staff
--   13 = Fist Weapon
--   15 = Dagger
--   16 = Thrown
--   18 = Crossbow
--   19 = Wand
-- ============================================================================

-- ============================================================================
-- HEIRLOOM WEAPONS (300332-300340)
-- ============================================================================

-- 300332: Heirloom Flamefury Blade (One-Hand Sword, subclass=7)
UPDATE `item_template` SET `RequiredSkill` = 43, `RequiredSkillRank` = 1 WHERE `entry` = 300332;

-- 300333: Heirloom Stormfury (One-Hand Sword, subclass=7)
UPDATE `item_template` SET `RequiredSkill` = 43, `RequiredSkillRank` = 1 WHERE `entry` = 300333;

-- 300334: Heirloom Frostbite Axe (One-Hand Axe, subclass=0)
UPDATE `item_template` SET `RequiredSkill` = 44, `RequiredSkillRank` = 1 WHERE `entry` = 300334;

-- 300335: Heirloom Shadow Dagger (Dagger, subclass=15)
UPDATE `item_template` SET `RequiredSkill` = 173, `RequiredSkillRank` = 1 WHERE `entry` = 300335;

-- 300336: Heirloom Arcane Staff (Staff, subclass=10)
UPDATE `item_template` SET `RequiredSkill` = 136, `RequiredSkillRank` = 1 WHERE `entry` = 300336;

-- 300337: Heirloom Zephyr Bow (Bow, subclass=2)
UPDATE `item_template` SET `RequiredSkill` = 45, `RequiredSkillRank` = 1 WHERE `entry` = 300337;

-- 300338: Heirloom Arcane Wand (Wand, subclass=19)
UPDATE `item_template` SET `RequiredSkill` = 228, `RequiredSkillRank` = 1 WHERE `entry` = 300338;

-- 300339: Heirloom Earthshaker Mace (One-Hand Mace, subclass=4)
UPDATE `item_template` SET `RequiredSkill` = 54, `RequiredSkillRank` = 1 WHERE `entry` = 300339;

-- 300340: Heirloom Polearm (Polearm, subclass=6)
UPDATE `item_template` SET `RequiredSkill` = 229, `RequiredSkillRank` = 1 WHERE `entry` = 300340;

-- ============================================================================
-- NOTE: ARMOR ITEMS (300341-300366) DO NOT NEED WEAPON SKILLS
-- ============================================================================
-- Armor items (class=4) check armor type proficiency based on class, not skill.
-- All classes can wear cloth, mail/plate classes can wear leather, etc.
-- The armor proficiency check uses AllowableClass, not RequiredSkill.
-- 
-- These items already have AllowableClass = -1 (all classes allowed), which is
-- correct for heirlooms since they should be usable by any class that can
-- wear the armor type (handled by the client based on armor subclass).
-- ============================================================================

-- ============================================================================
-- VERIFICATION QUERY
-- ============================================================================
-- SELECT entry, name, class, subclass, RequiredSkill, RequiredSkillRank 
-- FROM item_template 
-- WHERE entry BETWEEN 300332 AND 300366
-- ORDER BY entry;
