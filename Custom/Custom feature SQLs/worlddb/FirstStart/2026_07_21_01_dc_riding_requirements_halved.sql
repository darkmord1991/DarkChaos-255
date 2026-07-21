-- ============================================================================
-- DC FirstStart - Riding requirements halved (levels and costs)
-- Date: 2026-07-21
-- Stock riding gating is too slow for a 1-255 realm. New curve (user-chosen
-- "halved"): Apprentice 10, Journeyman 20, Expert flying 30, Artisan epic
-- flying 40, Cold Weather Flying 40. Training costs cut ~50%.
-- Updates every trainer row by SpellId (unconditional on purpose - guarding on
-- the old value silently no-ops if a prior tweak changed it).
-- DCFirstStart.StartingMount.MinLevel (10) already matches new Apprentice level.
-- ============================================================================

-- Apprentice Riding (75): level 20 -> 10, 4g -> 2g
UPDATE `trainer_spell` SET `ReqLevel` = 10, `MoneyCost` = 20000 WHERE `SpellId` = 33388;

-- Journeyman Riding (150): level 40 -> 20, 50g -> 25g
UPDATE `trainer_spell` SET `ReqLevel` = 20, `MoneyCost` = 250000 WHERE `SpellId` = 33391;

-- Expert Riding (225, flying): level 60 -> 30, 250g -> 125g
UPDATE `trainer_spell` SET `ReqLevel` = 30, `MoneyCost` = 1250000 WHERE `SpellId` = 34090;

-- Artisan Riding (300, epic flying): level 70 -> 40, 5000g -> 2500g
UPDATE `trainer_spell` SET `ReqLevel` = 40, `MoneyCost` = 25000000 WHERE `SpellId` = 34091;

-- Cold Weather Flying: level 77 -> 40, 1000g -> 500g
UPDATE `trainer_spell` SET `ReqLevel` = 40, `MoneyCost` = 5000000 WHERE `SpellId` = 54197;
