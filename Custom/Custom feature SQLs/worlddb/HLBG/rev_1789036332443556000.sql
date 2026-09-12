-- Hinterland BG (maps 1411/1412): arm and armour the Revantusk (Horde) NPCs.
--
-- 1) Weapons were invisible. Every custom Revantusk NPC already had a
--    creature_equip_template row, but Warcaller/Watchblade/Spiritmender/
--    Banner-Singer/Fireside Shaman carry a creature_template_addon (and some a
--    creature_addon) with bytes2 = 0. Creature.cpp only applies SHEATH_STATE_MELEE
--    to creatures with NO addon at all, and skips the sheath byte when bytes2 is 0,
--    so these stood in ready stances with their weapons put away. bytes2 = 1 is
--    SHEATH_STATE_MELEE, what stock guards use. The same defect sat on two Kor'kron
--    Grunt and two Kor'kron Overseer spawns on the Horde side.
-- 2) Armour: the displays were village outfits (3-7 of 11 slots, shirts and robes).
--    Replaced with existing armoured FOREST troll displays so they stay Revantusk:
--    28266 (Renn'az, green mail), 28281 (War Master Voone, grey/green plate),
--    22309/22310 (Amani'shi Guardian plate), 22277/22278 (Amani'shi Warbringer
--    mail), 22261/22262 (Amani'shi Wind Walker mail). Blizzard's Revantusk women
--    already use jungle-troll female models, so the female variant is 18113
--    (red Horde plate). The Amani/Voone displays carry CreatureModelScale 1.2-1.3;
--    DisplayScale counter-scales them back to roughly normal troll size (the
--    Warcaller is left ~1.17 as the commander). All displays have DBC,
--    creature_model_info rows and are used by stock creatures.
-- 3) Weapons re-themed to Zul'Aman troll items (all present in client and server
--    Item.dbc with valid ItemDisplayInfo).
-- Stock entries (14734 Revantusk Drummer, 17598 Renn'az) are untouched: they also
-- spawn in the open-world Hinterlands on map 0.

-- 1) sheath state: weapons in hand
UPDATE `creature_template_addon` SET `bytes2` = 1 WHERE `entry` IN (810006, 810007, 810008, 810012, 810016) AND `bytes2` = 0;
UPDATE `creature_addon` SET `bytes2` = 1 WHERE `bytes2` = 0 AND `guid` IN (SELECT `guid` FROM `creature` WHERE `map` IN (1411, 1412) AND `id` IN (810006, 810007, 810008, 810024, 810027));

-- 2) armoured forest troll displays
DELETE FROM `creature_template_model` WHERE `CreatureID` IN (810000, 810006, 810007, 810008, 810012, 810016);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(810000, 0, 28266, 1, 1, 12340),
(810000, 1, 18113, 1, 1, 12340),
(810006, 0, 22309, 0.9, 1, 12340),
(810006, 1, 22310, 0.9, 1, 12340),
(810007, 0, 22277, 0.8, 1, 12340),
(810007, 1, 22278, 0.8, 1, 12340),
(810008, 0, 22261, 0.8, 1, 12340),
(810008, 1, 22262, 0.8, 1, 12340),
(810012, 0, 28281, 0.85, 1, 12340),
(810012, 1, 28266, 1, 1, 12340),
(810016, 0, 22261, 0.8, 1, 12340),
(810016, 1, 22262, 0.8, 1, 12340);

-- 3) troll weapons (810012 keeps its red spear 13631)
DELETE FROM `creature_equip_template` WHERE `CreatureID` IN (810000, 810006, 810007, 810008, 810016) AND `ID` = 1;
INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`) VALUES
(810000, 1, 53924, 42938, 0, 12340),
(810006, 1, 42940, 42938, 0, 12340),
(810007, 1, 53924, 53924, 0, 12340),
(810008, 1, 19909, 0, 0, 12340),
(810016, 1, 42940, 13318, 0, 12340);
