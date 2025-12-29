-- Stratholme Leveling Zone 130-160 - Creature Equipment
-- Links to creature_template via equipment_id used in previous file (implied update needed for template file if not already set, but we will assume updates or direct use).

-- NOTE: In 3.3.5a, `creature_equip_template` uses entry ID, but `creature_template` has `equipmentId` column. 
-- We will assume the Entry ID from creature_template is used as key here for simplicity, or we update the template to point here.
-- For this file, we use IDs matching the NPC entries involving equipment.

DELETE FROM `creature_equip_template` WHERE `CreatureID` BETWEEN 410000 AND 410999;

-- 410107: Cultist Initiate (Staff)
INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`) VALUES
(410107, 1, 35664, 0, 0); -- Staff of the Redeemer model

-- 410123: Fallen Crusader (Sword + Shield)
INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`) VALUES
(410123, 1, 37401, 35642, 0); -- Red Sword + Lordaeron Shield

-- 410800: Deathlord Trainee (Runeblade)
INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`) VALUES
(410800, 1, 38632, 0, 0); -- Greatsword of the Ebon Hold

-- 410803: Risen Commander (2H Axe)
INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`) VALUES
(410803, 1, 49623, 0, 0); -- Shadowmourne (Visual Only) or similar generic axe

-- 410804: Spectral Archer (Bow)
INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`) VALUES
(410804, 1, 30906, 0, 0); -- Bristleblitz Striker

-- UPDATE `creature_template` to use these IDs if not auto-matched (In AC, if entry matches, it often defaults, but best to force update)
UPDATE `creature_template` SET `equipmentId` = `entry` WHERE `entry` IN (410107, 410123, 410800, 410803, 410804);
