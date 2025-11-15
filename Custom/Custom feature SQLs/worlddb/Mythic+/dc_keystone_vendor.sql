/*
 * Mythic+ Keystone Vendor NPC
 * Single vendor NPC that distributes keystone items via gossip
 * Entry: 100100
 */

-- ============================================================
-- CREATURE TEMPLATE: Mythic+ Keystone Vendor
-- ============================================================

DELETE FROM `creature_template` WHERE (`entry` = 100100);
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `trainer_class`, `trainer_race`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(100100, 0, 0, 0, 0, 0, 'Keystone Vendor', 'Mythic+ Keystones', '', 100100, 70, 70, 0, 35, 4097, 1, 1.14286, 1, 1, 0, 1, 0, 0, 1, 2000, 2000, 1, 1, 8, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, '', 0, 1, 1, 1, 1, 1, 0, 0, 1, 0, 0, 0, 'npc_keystone_vendor', NULL);

-- ============================================================
-- CREATURE TEMPLATE MODEL: Keystone Vendor Display
-- ============================================================

DELETE FROM `creature_template_model` WHERE (`CreatureID` = 100100) AND (`Idx` IN (0, 1));
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(100100, 1, 30259, 1, 1, 0);

-- ============================================================
-- GOSSIP MENU: Keystone vendor options
-- ============================================================

DELETE FROM gossip_menu WHERE MenuID = 100100;
INSERT INTO gossip_menu (MenuID, TextID) VALUES (100100, 100100);

DELETE FROM npc_text WHERE ID = 100100;
INSERT INTO npc_text (ID, text0_0, text0_1, BroadcastTextID0, lang0, Probability0, em0_0, em0_1, em0_2, em0_3, em0_4, em0_5, VerifiedBuild)
VALUES (100100, 
    'Welcome, adventurer! I can provide you with a starter Mythic Keystone.$B$BTo begin your journey into Mythic+ dungeons, you must be level 80. The keystone will unlock access to challenging, scaled dungeon content with weekly affixes and valuable rewards.$B$BReady to test your mettle?',
    '', 0, 0, 1.0, 1, 0, 0, 0, 0, 0, 12340);

DELETE FROM gossip_menu_option WHERE MenuID = 100100;
INSERT INTO gossip_menu_option (MenuID, OptionID, OptionIcon, OptionText, OptionBroadcastTextID, OptionType, OptionNpcFlag, ActionMenuID, ActionPoiID, BoxCoded, BoxMoney, BoxText, BoxBroadcastTextID, VerifiedBuild) VALUES
(100100, 1, 0, '|cff00ff00I would like a Mythic Keystone +2|r (Requires Level 80)', 0, 1, 1, 0, 0, 0, 0, '', 0, 12340),
(100100, 2, 0, 'Nevermind.', 0, 1, 1, 0, 0, 0, 0, '', 0, 12340);

-- ============================================================
-- PLACEMENT NOTES
-- ============================================================

/*
 * To place the keystone vendor in the world:
 * 1. Use admin command: .npc add 100100  (at your cursor location)
 * 2. Example location: Main city hub or dungeon entrance area
 * 
 * The vendor will offer gossip menu to distribute keystone items (190001-190009)
 * based on the player's current keystone level stored in the database
 */
