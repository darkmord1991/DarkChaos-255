-- Hyjal Frontier - gossip menus and NPC text
--
-- npc_text IDs   : 83000-83021
-- gossip_menu IDs: 83000-83021 (one menu per NPC, MenuID == npc_text ID for clarity)
--
-- Coverage:
--   83000-83004  Alliance quest chain (Elowen, Aelaris, Elunor, Starfall, Rhydel)
--   83005-83009  Horde quest chain (Kargra, Mavak, Zorok, Gromtar, Toran)
--   83010        Hyjal Flight Master (Alliance 830020, reused by Horde 830145)
--   83011        Innkeeper Cerelina (Alliance 830023)
--   83012        Innkeeper Garruka  (Horde 830146)
--   83013        Emberwood Quartermaster (Alliance 830024, reused by Horde 830147)
--   83014        Food & Drink vendor (both 830139/830152)
--   83015        General Goods vendor (both 830137/830150)

-- =============================================================================
-- Cleanup
-- =============================================================================
DELETE FROM `gossip_menu`        WHERE `MenuID`  BETWEEN 83000 AND 83021;
DELETE FROM `gossip_menu_option` WHERE `MenuID`  BETWEEN 83000 AND 83021;
DELETE FROM `npc_text`           WHERE `ID`      BETWEEN 83000 AND 83021;

-- =============================================================================
-- NPC text entries
-- text0_0 = greeting shown when gossip window opens (text0_1 = alternate line)
-- Probability0 = 1.0 (always show)
-- All other slots left as 0/empty.
-- =============================================================================
INSERT INTO `npc_text`
    (`ID`,`text0_0`,`text0_1`,`BroadcastTextID0`,`lang0`,`Probability0`,
     `em0_0`,`em0_1`,`em0_2`,`em0_3`,`em0_4`,`em0_5`,
     `text1_0`,`text1_1`,`BroadcastTextID1`,`lang1`,`Probability1`,
     `em1_0`,`em1_1`,`em1_2`,`em1_3`,`em1_4`,`em1_5`,
     `text2_0`,`text2_1`,`BroadcastTextID2`,`lang2`,`Probability2`,
     `em2_0`,`em2_1`,`em2_2`,`em2_3`,`em2_4`,`em2_5`,
     `text3_0`,`text3_1`,`BroadcastTextID3`,`lang3`,`Probability3`,
     `em3_0`,`em3_1`,`em3_2`,`em3_3`,`em3_4`,`em3_5`,
     `text4_0`,`text4_1`,`BroadcastTextID4`,`lang4`,`Probability4`,
     `em4_0`,`em4_1`,`em4_2`,`em4_3`,`em4_4`,`em4_5`,
     `text5_0`,`text5_1`,`BroadcastTextID5`,`lang5`,`Probability5`,
     `em5_0`,`em5_1`,`em5_2`,`em5_3`,`em5_4`,`em5_5`,
     `text6_0`,`text6_1`,`BroadcastTextID6`,`lang6`,`Probability6`,
     `em6_0`,`em6_1`,`em6_2`,`em6_3`,`em6_4`,`em6_5`,
     `text7_0`,`text7_1`,`BroadcastTextID7`,`lang7`,`Probability7`,
     `em7_0`,`em7_1`,`em7_2`,`em7_3`,`em7_4`,`em7_5`,
     `VerifiedBuild`)
VALUES
-- 83000  Commander Elowen (Alliance chain start)
(83000,
 'The Foothills are overrun. Every sword counts — do not waste time.',
 'Report to Sentinel Aelaris at the outer line when you are ready to move.',
 0,0,1.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0, 0),

-- 83001  Sentinel Aelaris (Alliance Foothills hub)
(83001,
 'The scourge never sleeps. If you are going to survive these foothills, neither can you.',
 'Ask me about the surrounding threats when you are ready.',
 0,0,1.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0, 0),

-- 83002  Keeper Elunor (Alliance Scorched hub)
(83002,
 'The groves are still burning. Something is feeding the flames from within the ruins.',
 'I need fighters, not witnesses.',
 0,0,1.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0, 0),

-- 83003  Warden Starfall (Alliance Summit hub)
(83003,
 'The summit is contested on three fronts. Do not charge in blind.',
 'Every inch of ground here was paid for in blood. Do not give it back.',
 0,0,1.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0, 0),

-- 83004  Archdruid Rhydel (Alliance Nordrassil hub)
(83004,
 'Nordrassil''s roots hold memories older than your people. Do not let them be silenced.',
 'The corruption runs deep. Strike swiftly, and do not be drawn into its despair.',
 0,0,1.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0, 0),

-- 83005  Warmaster Kargra (Horde chain start)
(83005,
 'The vanguard does not retreat. Show me what you are worth.',
 'Mavak is at the forward line. Get there before the dead do.',
 0,0,1.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0, 0),

-- 83006  Scout Mavak (Horde Foothills hub)
(83006,
 'I have mapped every patrol route the dead use. Use that knowledge or die ignorant.',
 'Stay fast, stay low, and finish what you start.',
 0,0,1.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0, 0),

-- 83007  Spiritcaller Zorok (Horde Scorched hub)
(83007,
 'The fire spirits are angry. The demons have poisoned the land far deeper than we expected.',
 'If you can hear the earth screaming, you are in the right place.',
 0,0,1.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0, 0),

-- 83008  Battlelord Gromtar (Horde Summit hub)
(83008,
 'I have held this ridge for six days. Six days of blood and nothing that can kill me has found me yet.',
 'The summit falls only when the last of us falls. Make sure that is not today.',
 0,0,1.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0, 0),

-- 83009  Earthwarden Toran (Horde Nordrassil hub)
(83009,
 'Nordrassil is life itself. Whatever poisons it must be ripped out root and stem.',
 'The earth endures. So must you.',
 0,0,1.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0, 0),

-- 83010  Flight Master (shared both factions)
(83010,
 'Name your destination. The winds over Hyjal wait for no one.',
 '',
 0,0,1.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0, 0),

-- 83011  Innkeeper Cerelina (Alliance)
(83011,
 'Rest your head here, champion. The encampment is safer than it looks.',
 'Would you like to make this your home?',
 0,0,1.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0, 0),

-- 83012  Innkeeper Garruka (Horde)
(83012,
 'Sleep fast, warrior. The fighting starts again at dawn.',
 'Make yourself at home. This is Thrall''s Vanguard, after all.',
 0,0,1.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0, 0),

-- 83013  Emberwood Sap Quartermaster (both factions)
(83013,
 'Emberwood Sap is the currency of the frontier. Bring me enough and I will outfit you properly.',
 '',
 0,0,1.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0, 0),

-- 83014  Food & Drink vendor
(83014,
 'I carry provisions for every stage of the frontier, from the Foothills to Nordrassil itself.',
 '',
 0,0,1.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0, 0),

-- 83015  General Goods vendor
(83015,
 'Potions, bandages, tools — whatever keeps you alive past the next fight.',
 '',
 0,0,1.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0,
 '','',0,0,0.0, 0,0,0,0,0,0, 0);

-- =============================================================================
-- Gossip menus (MenuID → TextID, one-to-one for clarity)
-- =============================================================================
INSERT INTO `gossip_menu` (`MenuID`,`TextID`) VALUES
(83000,83000),(83001,83001),(83002,83002),(83003,83003),(83004,83004),
(83005,83005),(83006,83006),(83007,83007),(83008,83008),(83009,83009),
(83010,83010),(83011,83011),(83012,83012),(83013,83013),(83014,83014),
(83015,83015);

-- =============================================================================
-- Gossip menu options
-- Quest givers need no options (AzerothCore injects quest buttons automatically).
-- Service NPCs get one "placeholder" option row so the window is not blank
-- when no service action is available.
-- OptionType 1 = gossip (plain text / no action),  5 = innkeeper bind
-- OptionNpcFlag: 0 = plain option
-- =============================================================================
INSERT INTO `gossip_menu_option`
    (`MenuID`,`OptionID`,`OptionIcon`,`OptionText`,`OptionBroadcastTextID`,
     `OptionType`,`OptionNpcFlag`,`ActionMenuID`,`ActionPoiID`,
     `BoxCoded`,`BoxMoney`,`BoxText`,`BoxBroadcastTextID`,`VerifiedBuild`)
VALUES
-- Inn options (type 5 = innkeeper)
(83011, 0, 0, 'Make this inn my home.',      0, 5, 65536, 0, 0, 0, 0, '', 0, 0),
(83012, 0, 0, 'Make this inn my home.',      0, 5, 65536, 0, 0, 0, 0, '', 0, 0),
-- Vendor options (type 3 = vendor)
(83013, 0, 1, 'Let me browse your wares.',  0, 3, 128,   0, 0, 0, 0, '', 0, 0),
(83014, 0, 1, 'Let me browse your wares.',  0, 3, 128,   0, 0, 0, 0, '', 0, 0),
(83015, 0, 1, 'Let me browse your wares.',  0, 3, 128,   0, 0, 0, 0, '', 0, 0);

-- =============================================================================
-- Wire gossip menus into creature_template
-- =============================================================================
UPDATE `creature_template` SET `gossip_menu_id`=83000 WHERE `entry`=830030;
UPDATE `creature_template` SET `gossip_menu_id`=83001 WHERE `entry`=830031;
UPDATE `creature_template` SET `gossip_menu_id`=83002 WHERE `entry`=830032;
UPDATE `creature_template` SET `gossip_menu_id`=83003 WHERE `entry`=830033;
UPDATE `creature_template` SET `gossip_menu_id`=83004 WHERE `entry`=830034;
UPDATE `creature_template` SET `gossip_menu_id`=83005 WHERE `entry`=830035;
UPDATE `creature_template` SET `gossip_menu_id`=83006 WHERE `entry`=830036;
UPDATE `creature_template` SET `gossip_menu_id`=83007 WHERE `entry`=830037;
UPDATE `creature_template` SET `gossip_menu_id`=83008 WHERE `entry`=830038;
UPDATE `creature_template` SET `gossip_menu_id`=83009 WHERE `entry`=830039;
UPDATE `creature_template` SET `gossip_menu_id`=83010 WHERE `entry` IN (830020,830145);
UPDATE `creature_template` SET `gossip_menu_id`=83011 WHERE `entry`=830023;
UPDATE `creature_template` SET `gossip_menu_id`=83012 WHERE `entry`=830146;
UPDATE `creature_template` SET `gossip_menu_id`=83013 WHERE `entry` IN (830024,830147);
UPDATE `creature_template` SET `gossip_menu_id`=83014 WHERE `entry` IN (830139,830152);
UPDATE `creature_template` SET `gossip_menu_id`=83015 WHERE `entry` IN (830137,830150);
