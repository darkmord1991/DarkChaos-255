-- Custom trainers (Dark Chaos)
-- Adds trainer definitions + creature->trainer mapping for custom mall trainers.
-- Requires the trainer system tables from the trainer refactor:
--   trainer, trainer_spell, creature_default_trainer
--
-- Trainers covered:
--   95001-95014 (professions / secondary skills)
--   95025 (Weapon Master)
--   95026 (Flying Instructor)
--
-- Notes:
-- - These trainer Ids are intentionally the same as the creature_template entry.
-- - trainer_spell rows for these TrainerId values are expected to exist already
--   (see Custom/Custom feature SQLs/npc_trainer_new.sql).

USE acore_world;

-- Avoid load-time errors from invalid placeholder rows
DELETE FROM `trainer_spell`
WHERE `TrainerId` IN (95001,95002,95003,95004,95005,95006,95007,95008,95009,95010,95011,95012,95013,95014,95025,95026)
  AND `SpellId` = 0;

-- Define the trainers (greeting text is what shows in the trainer window)
REPLACE INTO `trainer` (`Id`, `Type`, `Requirement`, `Greeting`, `VerifiedBuild`) VALUES
(95001, 2, 0, 'With alchemy you can turn found herbs into healing and other types of potions.', 12340),
(95002, 2, 0, 'Care to learn how to turn the ore that you find into weapons and metal armor?', 12340),
(95003, 2, 0, 'Enchanting is the art of improving existing items through magic.', 12340),
(95004, 2, 0, 'Engineering is very simple once you grasp the basics.', 12340),
(95005, 2, 0, 'Searching for herbs requires both knowledge and instinct.', 12340),
(95006, 2, 0, 'Would you like to learn the intricacies of inscription?', 12340),
(95007, 2, 0, 'Greetings!  Can I teach you how to cut precious gems and craft jewelry?', 12340),
(95008, 2, 0, 'Greetings!  Can I teach you how to turn beast hides into armor?', 12340),
(95009, 2, 0, 'You have not lived until you have dug deep into the earth.', 12340),
(95010, 2, 0, 'It requires a steady hand to remove the leather from a slain beast.', 12340),
(95011, 2, 0, 'Greetings!  Can I teach you how to turn found cloth into cloth armor?', 12340),
(95012, 2, 0, 'Can I teach you how to turn the meat you find on beasts into a feast?', 12340),
(95013, 2, 0, 'Here, let me show you how to bind those wounds....', 12340),
(95014, 2, 0, 'I can teach you how to use a fishing pole to catch fish.', 12340),
(95025, 2, 0, 'I can help you learn weapon skills.', 12340),
(95026, 1, 0, 'I can teach you how to ride and fly.', 12340);

-- Map creatures to their default trainer templates
REPLACE INTO `creature_default_trainer` (`CreatureId`, `TrainerId`) VALUES
(95001, 95001),
(95002, 95002),
(95003, 95003),
(95004, 95004),
(95005, 95005),
(95006, 95006),
(95007, 95007),
(95008, 95008),
(95009, 95009),
(95010, 95010),
(95011, 95011),
(95012, 95012),
(95013, 95013),
(95014, 95014),
(95025, 95025),
(95026, 95026);
