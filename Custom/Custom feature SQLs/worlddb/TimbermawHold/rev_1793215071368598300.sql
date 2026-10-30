-- ============================================================================================
-- Timbermaw Hold (map 819) -- model scale fix for the tortoise-wow port (rev_1793212190166823600)
--
-- Turtle's creature_template.scale is the FINAL size. The 1.12 client never applies
-- CreatureDisplayInfo.CreatureModelScale; vmangos only falls back to it when scale is 0.
-- The 3.3.5 client multiplies DisplayScale by CreatureModelScale itself. Every port creature with a
-- Turtle scale set, on a stock display whose CreatureModelScale is not 1.0, was therefore drawn too
-- large or too small by that factor (Tainted Mass: 3.0 x 4.0 = 12x).
-- DisplayScale = Turtle scale / our CreatureModelScale.
-- Combat reach and bounding radius follow, because the core multiplies creature_model_info by the
-- object scale.
-- ============================================================================================

-- Kodiak (display 9276, model scale 1.3): Turtle 2.25
UPDATE `creature_template_model` SET `DisplayScale` = 1.731 WHERE `CreatureID` = 4010003 AND `Idx` = 0;
-- Vile Skitterer (959, 0.55): Turtle 0.5
UPDATE `creature_template_model` SET `DisplayScale` = 0.909 WHERE `CreatureID` = 4010106 AND `Idx` = 0;
-- Tainted Mass (15463, 4.0): Turtle 3.0
UPDATE `creature_template_model` SET `DisplayScale` = 0.75 WHERE `CreatureID` = 4010110 AND `Idx` = 0;
-- Corruption of Loktanag (1086, 1.3): Turtle 1.8
UPDATE `creature_template_model` SET `DisplayScale` = 1.385 WHERE `CreatureID` = 4010111 AND `Idx` = 0;
-- Twisted Rumbler (1108, 0.7): Turtle 1.65
UPDATE `creature_template_model` SET `DisplayScale` = 2.357 WHERE `CreatureID` = 4010112 AND `Idx` = 0;
-- Foulheart Deceiver / Satyr / Trickster (11338 and 2687, 1.5): Turtle 1.5
UPDATE `creature_template_model` SET `DisplayScale` = 1 WHERE `CreatureID` IN (4010113, 4010114, 4010115) AND `Idx` = 0;
-- Foulheart Hellcaller (2687, 1.5): Turtle 1.6
UPDATE `creature_template_model` SET `DisplayScale` = 1.067 WHERE `CreatureID` = 4010116 AND `Idx` = 0;
-- Son of Ursol (1082, 1.5): Turtle 2.5
UPDATE `creature_template_model` SET `DisplayScale` = 1.667 WHERE `CreatureID` = 4010117 AND `Idx` = 0;

-- Foulheart Imp. Display 32986 is a female goblin NPC on our client. The upport pack hosts Turtle's
-- FireImp.mdx at that id, but our client does not have that model. Use Turtle's own display id instead:
-- 12190, the stock Imp.mdx with the same ImpSkinRed texture and model scale 1.5. Turtle's scale was 0,
-- which means the display's own scale, so the imp keeps Turtle's size.
UPDATE `creature_template_model` SET `CreatureDisplayID` = 12190, `DisplayScale` = 1
WHERE `CreatureID` = 4010015 AND `Idx` = 0;

-- Ursol's display 4010010 has model scale 2.0. Turtle's reach of 1.5 was multiplied by Turtle's object
-- scale, which was that same 2.0. Ours is 1.0, so the factor has to be stored here.
UPDATE `creature_model_info` SET `BoundingRadius` = 3, `CombatReach` = 3 WHERE `DisplayID` = 4010010;

-- Gameobjects were written at size 1. These are Turtle's sizes. Each display points at the same model
-- file as Turtle's, and GameObjectDisplayInfo has no scale column, so the sizes carry over unchanged.
-- The portal and campfire sizes come from Turtle's per-spawn object_scaling rows (guids 5030596 and
-- 5026138); each of these templates has exactly one spawn here.
UPDATE `gameobject_template` SET `size` = 1.0379 WHERE `entry` IN (4010001, 4010002, 4010003, 4010004);
-- Barrier of Ursol
UPDATE `gameobject_template` SET `size` = 3 WHERE `entry` = 4010005;
-- Narkogg's Medicine Pouch, Putrid Flower
UPDATE `gameobject_template` SET `size` = 2 WHERE `entry` IN (4010006, 4010007);
-- Instance Portal
UPDATE `gameobject_template` SET `size` = 3 WHERE `entry` = 4010008;
-- Campfire
UPDATE `gameobject_template` SET `size` = 2 WHERE `entry` = 4010010;
