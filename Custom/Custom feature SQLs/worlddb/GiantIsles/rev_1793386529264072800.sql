-- Isles of Giants: repair for rev_1793385646011983500 (2026-10-30). Its foothold game events were 1405-1407, but
-- game_event refused those ids while game_event_creature and game_event_gameobject took them, which left 21 spawn
-- links on events that do not exist. Moves the camps to 251-253: free in every game_event table.
-- Foothold camps. Never active on their own: start_time = end_time keeps them off, and the script starts and
-- stops them from the campaign world state (251 at foothold 1+, 252 at 3+, 253 at 5). Event ids stop at 255:
-- game_event.eventEntry is a tinyint unsigned and the core reads it as uint8.
DELETE FROM `game_event` WHERE `eventEntry` IN (251, 252, 253);
INSERT INTO `game_event` (`eventEntry`, `start_time`, `end_time`, `occurence`, `length`, `holiday`, `holidayStage`, `description`, `world_event`, `announce`) VALUES
(251, '2000-01-01 14:00:00', '2000-01-01 14:00:00', 5184000, 2592000, 0, 0, 'Isles of Giants - Zandalari foothold: the terrace', 0, 0),
(252, '2000-01-01 14:00:00', '2000-01-01 14:00:00', 5184000, 2592000, 0, 0, 'Isles of Giants - Zandalari foothold: the beach garrison', 0, 0),
(253, '2000-01-01 14:00:00', '2000-01-01 14:00:00', 5184000, 2592000, 0, 0, 'Isles of Giants - Zandalari foothold: the Warpath outposts', 0, 0);

DELETE FROM `game_event_creature` WHERE `guid` BETWEEN 9014000 AND 9014107;
INSERT INTO `game_event_creature` (`eventEntry`, `guid`) VALUES
(251, 9014090),
(251, 9014091),
(251, 9014092),
(251, 9014093),
(252, 9014094),
(252, 9014095),
(252, 9014096),
(252, 9014097),
(252, 9014098),
(252, 9014099),
(252, 9014100),
(252, 9014101),
(253, 9014102),
(253, 9014103),
(253, 9014104),
(253, 9014105),
(253, 9014106),
(253, 9014107);

DELETE FROM `game_event_gameobject` WHERE `guid` BETWEEN 9014000 AND 9014005;
INSERT INTO `game_event_gameobject` (`eventEntry`, `guid`) VALUES
(251, 9014003),
(252, 9014004),
(253, 9014005);
