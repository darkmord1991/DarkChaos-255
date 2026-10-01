-- Map 1413 (Legion Dalaran guild house): helper NPCs that players could see, and two wolves with broken
-- textures. Every entry below is spawned only on 1413.
--
-- 1. Helper/dummy NPCs. The 2026-06-27 import wrote unit_flags = 0 and flags_extra = 0 for all of them and
--    gave several a visible stand-in display (white rabbit 328, infernal 169, rocket chicken, mechanical
--    rabbit, a textureless dwarf for the two fires). Retail marks them TRIGGER / not selectable. TRIGGER
--    (flags_extra 0x80) makes the core send its invisible model to every non-GM (Unit.cpp); GM accounts in
--    GM mode still see them. unit_flags 0x02000300 = NOT_SELECTABLE | IMMUNE_TO_PC | IMMUNE_TO_NPC, as retail.
--    Kept visible on purpose: the training dummies, the DC boss display dummies and Guardian Orb.
UPDATE `creature_template` SET `flags_extra` = `flags_extra` | 128, `unit_flags` = `unit_flags` | 33555200
WHERE `entry` IN (3500031, 3500029, 3500033, 3500010, 3500008, 3500296, 3500471, 3500440, 3500414, 3500528, 3500423, 3500436, 3500489, 3500082, 3500083, 3500020);
-- 2. Cosmetic Worg Pup: retail uses displays 27719/27720 on the stock direwolf model, and stock 3.3.5 has
--    both. The custom display 500591 put the fur "alpha" texture in the skin slot and left slot 2 empty,
--    which drew the fur layer white.
DELETE FROM `creature_template_model` WHERE `CreatureID` = 3500022;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(3500022, 0, 27719, 1, 1, 0),
(3500022, 1, 27720, 1, 1, 0);
-- 3. Winnie shared 500591 as well; retail Winnie is display 15180 (stock, reddish-brown direwolf).
DELETE FROM `creature_template_model` WHERE `CreatureID` = 3500525;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(3500525, 0, 15180, 1, 1, 0);
