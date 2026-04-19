-- copy NPCs from Hyjal summit
-- use them for a bit of flair

DELETE FROM `creature_template` WHERE `entry` BETWEEN 830000 AND 830017;
INSERT INTO `creature_template`
	(`entry`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`,
	 `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`,
	 `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`,
	 `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`,
	 `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`,
	 `dynamicflags`, `family`, `type`, `type_flags`, `AIName`,
	 `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`,
	 `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`,
	 `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`,
	 `VerifiedBuild`)
VALUES
(830000, 'Night Elf Archer',      'DC-WoW', NULL, 0, 130, 130, 1, 1718, 0, 1.2, 1.14286, 1, 1, 20, 1, 0, 7.5, 1400, 2000, 1, 1, 1, 32832, 2048, 0, 0, 7, 8, '', 1, 1, 6, 1, 1, 1, 0, 121, 1, 0, 0, '', 12340),
(830001, 'Dryad',                 'DC-WoW', NULL, 0, 130, 130, 1, 1718, 0, 1.2, 1.14286, 1, 1, 20, 1, 0, 7.5, 1400, 2000, 1, 1, 2, 64, 2048, 0, 0, 7, 8, '', 1, 1, 6, 6, 1, 1, 0, 121, 1, 0, 0, '', 12340),
(830002, 'Night Elf Huntress',    'DC-WoW', NULL, 0, 130, 130, 1, 1718, 0, 1.2, 1.14286, 1, 1, 20, 1, 0, 7.5, 1400, 2000, 1, 1, 1, 32832, 2048, 0, 0, 7, 8, '', 1, 1, 6, 1, 1, 1, 0, 0,   1, 0, 0, '', 12340),
(830003, 'Ancient Wisp',          'DC-WoW', NULL, 0, 130, 130, 1, 1719, 0, 1.2, 1.14286, 1, 1, 20, 1, 0, 7.5, 2000, 2000, 1, 1, 1, 64, 2048, 0, 0, 10, 8, '', 0, 1, 2.8, 1, 1, 1, 0, 125, 1, 0, 2, 'npc_ancient_wisp', 12340),
(830004, 'Red Crystal Bunny',     'DC-WoW', NULL, 0, 130, 130, 1, 114,  0, 1,   1.14286, 1, 1, 20, 0, 0, 1,   2000, 2000, 1, 1, 1, 33555200, 2048, 0, 0, 10, 0, 'SmartAI', 1, 1, 1.35, 1, 1, 1, 0, 0,   1, 0, 2, '', 12340),
(830005, 'Tyrande Whisperwind',   'DC-WoW', NULL, 0, 130, 130, 1, 1718, 1, 1.2, 1.14286, 1, 1, 20, 3, 0, 35,  1200, 2000, 1, 1, 2, 64, 2048, 0, 0, 7, 12, '', 0, 1, 300, 15, 1, 1, 0, 0,   1, 0, 1, '', 12340),
(830006, 'Malfurion Stormrage',   'DC-WoW', NULL, 0, 130, 130, 1, 1718, 0, 1.2, 1.14286, 1, 1, 20, 3, 0, 35,  2000, 2000, 1, 1, 1, 0,  2048, 0, 0, 7, 12, '', 0, 1, 300, 15, 1, 1, 0, 0,   1, 0, 1, '', 12340),
(830007, 'Alliance Peasant',      'DC-WoW', NULL, 0, 130, 130, 1, 1716, 0, 1.2, 1.14286, 1, 1, 20, 1, 0, 7.5, 1400, 2000, 1, 1, 1, 0,  2048, 0, 0, 7, 8, '', 0, 1, 1,   1, 1, 1, 0, 121, 1, 0, 2, '', 12340),
(830008, 'Horde Grunt',           'DC-WoW', NULL, 0, 130, 130, 1, 1718, 0, 1.2, 1.14286, 1, 1, 18, 1, 0, 7.5, 1400, 2000, 1, 1, 1, 8256, 2048, 0, 0, 7, 8, '', 1, 1, 8,   1, 1, 1, 0, 121, 1, 0, 0, '', 12340),
(830009, 'Tauren Warrior',        'DC-WoW', NULL, 0, 130, 130, 1, 1718, 0, 1.2, 1.14286, 1, 1, 20, 1, 0, 7.5, 1400, 2000, 1, 1, 1, 64, 2048, 0, 0, 7, 8, '', 1, 1, 12,  1, 1, 1, 0, 121, 1, 0, 0, '', 12340),
(830010, 'Horde Headhunter',      'DC-WoW', NULL, 0, 130, 130, 1, 1718, 0, 1.2, 1.14286, 1, 1, 20, 1, 0, 7.5, 1400, 2000, 1, 1, 1, 8256, 2048, 0, 0, 7, 8, '', 1, 1, 6,   1, 1, 1, 0, 121, 1, 0, 0, '', 12340),
(830011, 'Horde Witch Doctor',    'DC-WoW', NULL, 0, 130, 130, 1, 1718, 0, 1.2, 1.14286, 1, 1, 20, 1, 0, 7.5, 1400, 2000, 1, 1, 2, 64, 2048, 0, 0, 7, 8, '', 1, 1, 6,   8, 1, 1, 0, 121, 1, 0, 0, '', 12340),
(830012, 'Horde Shaman',          'DC-WoW', NULL, 0, 130, 130, 1, 1718, 0, 1.2, 1.14286, 1, 1, 18, 1, 0, 7.5, 1400, 2000, 1, 1, 2, 64, 2048, 0, 0, 7, 8, '', 1, 1, 6,   8, 1, 1, 0, 121, 1, 0, 0, '', 12340),
(830013, 'Horde Peon',            'DC-WoW', NULL, 0, 130, 130, 1, 1719, 0, 1.2, 1.14286, 1, 1, 18, 1, 0, 7.5, 1400, 2000, 1, 1, 1, 64, 2048, 0, 0, 7, 8, '', 1, 1, 6,   1, 1, 1, 0, 121, 1, 0, 2, '', 12340),
(830014, 'Alliance Footman',      'DC-WoW', NULL, 0, 130, 130, 1, 1718, 0, 1.2, 1.14286, 1, 1, 20, 1, 0, 7.5, 1400, 2000, 1, 1, 1, 32832, 2048, 0, 0, 7, 8, '', 1, 1, 6,   1, 1, 1, 0, 121, 1, 0, 0, '', 12340),
(830015, 'Alliance Knight',       'DC-WoW', NULL, 0, 130, 130, 1, 1718, 0, 1.2, 1.14286, 1, 1, 20, 1, 0, 7.5, 1400, 2000, 1, 1, 1, 64, 2048, 0, 0, 7, 8, '', 1, 1, 12,  1, 1, 1, 0, 164, 1, 0, 0, '', 12340),
(830016, 'Alliance Rifleman',     'DC-WoW', NULL, 0, 130, 130, 1, 1718, 0, 1.2, 1.14286, 1, 1, 20, 1, 0, 7.5, 1400, 2000, 1, 1, 1, 32832, 2048, 0, 0, 7, 8, '', 1, 1, 6,   1, 1, 1, 0, 121, 1, 0, 0, 'alliance_rifleman', 12340),
(830017, 'Alliance Sorceress',    'DC-WoW', NULL, 0, 130, 130, 1, 1718, 0, 1.2, 1.14286, 1, 1, 20, 1, 0, 7.5, 1400, 2000, 1, 1, 8, 32832, 2048, 0, 0, 7, 8, '', 1, 1, 6,   5, 1, 1, 0, 121, 1, 0, 0, '', 12340);

-- AzerothCore now resolves creature displays through creature_template_model.
-- Keep these rows in sync with the template rows above so the Hyjal NPCs
-- remain visible on current world DB schema.
DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN 830000 AND 830017;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(830000, 0, 17339, 1, 1, 12340),
(830001, 0, 17340, 1, 1, 12340),
(830002, 0, 17341, 1, 1, 12340),
(830003, 0, 17607, 1, 1, 12340),
(830004, 0, 17200, 1, 1, 12340),
(830005, 0, 17873, 1, 1, 12340),
(830006, 0, 15399, 1, 1, 12340),
(830007, 0, 17330, 1, 1, 12340),
(830008, 0, 17331, 1, 1, 12340),
(830009, 0, 17332, 1, 1, 12340),
(830010, 0, 17335, 1, 1, 12340),
(830011, 0, 17336, 1, 1, 12340),
(830012, 0, 17337, 1, 1, 12340),
(830013, 0, 17338, 1, 1, 12340),
(830014, 0, 17322, 1, 1, 12340),
(830015, 0, 17389, 1, 1, 12340),
(830016, 0, 17324, 1, 1, 12340),
(830017, 0, 17325, 1, 1, 12340);

-- creature equip template
DELETE FROM `creature_equip_template` WHERE (`CreatureID` = 830000);
INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`) VALUES
(830000, 1, 1896, 0, 5260, 18019);
DELETE FROM `creature_equip_template` WHERE (`CreatureID` = 830001);
INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`) VALUES
(830001, 1, 5870, 0, 0, 18019);
DELETE FROM `creature_equip_template` WHERE (`CreatureID` = 830002);
INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`) VALUES
(830002, 1, 5598, 0, 0, 18019);
DELETE FROM `creature_equip_template` WHERE (`CreatureID` = 830007);
INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`) VALUES
(830007, 1, 1905, 0, 0, 18019);
DELETE FROM `creature_equip_template` WHERE (`CreatureID` = 830008);
INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`) VALUES
(830008, 1, 5289, 0, 0, 18019);
DELETE FROM `creature_equip_template` WHERE (`CreatureID` = 830009);
INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`) VALUES
(830009, 1, 14084, 0, 0, 18019);
DELETE FROM `creature_equip_template` WHERE (`CreatureID` = 830010);
INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`) VALUES
(830010, 1, 6680, 0, 5870, 18019);
DELETE FROM `creature_equip_template` WHERE (`CreatureID` = 830011);
INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`) VALUES
(830011, 1, 19214, 0, 0, 18019);
DELETE FROM `creature_equip_template` WHERE (`CreatureID` = 830012);
INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`) VALUES
(830012, 1, 19214, 0, 0, 18019);
DELETE FROM `creature_equip_template` WHERE (`CreatureID` = 830014);
INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`) VALUES
(830014, 1, 1899, 1984, 0, 18019);
DELETE FROM `creature_equip_template` WHERE (`CreatureID` = 830015);
INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`) VALUES
(830015, 1, 12890, 0, 0, 18019);
DELETE FROM `creature_equip_template` WHERE (`CreatureID` = 830016);
INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`) VALUES
(830016, 1, 1905, 0, 12523, 18019);

update creature set equipment_id = 1 where id1 >= 830000 and id1 <= 830017;