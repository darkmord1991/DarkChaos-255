-- Dalaran Guildhouse Teleporter Guard gossip text
DELETE FROM `gossip_menu` WHERE `MenuID` = 8000300;
INSERT INTO `gossip_menu` (`MenuID`, `TextID`) VALUES
(8000300, 8000300);

DELETE FROM `npc_text` WHERE `ID` = 8000300;
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`, `em0_0`, `em0_1`, `em0_2`, `em0_3`, `em0_4`, `em0_5`, `VerifiedBuild`)
VALUES (8000300,
    'Greetings, guild champion. Within the violet walls of Dalaran, your guildhouse stands as a beacon of unity and honor.$B$BChoose your destination, and may the Kirin Tor watch your path.',
    '', 0, 0, 1.0, 1, 0, 0, 0, 0, 0, 12340);
