-- Map 751 was imported with no game event links at all, so its holiday spawns stood there all year:
-- Hallow's End pumpkins, skull lights and candles, New Year's mugs and kegs, Day of the Dead candles.
-- Undercity holds about 350 of them, and they cost frame rate everywhere the server sends them.
-- Each entry here is event-only in its source (cata_world, nelt_world or stock), checked against the
-- source spawn at the same coordinates where one entry had several events. Scenery that a source only
-- linked in part (Peacebloom, Doors, Campfire, Scorpion) stays unbound.

-- Hallow's End
DELETE FROM `game_event_gameobject` WHERE `eventEntry` = 12 AND `guid` IN (SELECT `guid` FROM `gameobject` WHERE `map` = 751);
INSERT INTO `game_event_gameobject` (`eventEntry`, `guid`) SELECT 12, `guid` FROM `gameobject` WHERE `map` = 751 AND `id` IN
(3780405, 3780406, 3780407, 3780410, 3780411, 3780415, 3780425, 3780426, 3780427, 3780429, 3780471, 3780472, 3780523, 3790108, 3808069, 3808072, 3808078, 3808156,
4780405, 4780406, 4780407, 4780408, 4780409, 4780410, 4780411, 4780414, 4780415, 4780425, 4780426, 4780427, 4780428, 4780431, 4780433, 4780434, 4780437, 4780471,
4780472, 4780523, 4785438, 4786234, 4786614, 4786615, 4786720, 4790066, 4790074, 4790078, 4790082, 4790089, 4808069, 4808072, 4808078, 4808145, 4808146, 4808148, 4808149);

-- Day of the Dead
DELETE FROM `game_event_gameobject` WHERE `eventEntry` = 51 AND `guid` IN (SELECT `guid` FROM `gameobject` WHERE `map` = 751);
INSERT INTO `game_event_gameobject` (`eventEntry`, `guid`) SELECT 51, `guid` FROM `gameobject` WHERE `map` = 751 AND `id` IN
(4780338, 4780339, 4780340, 4780760, 4782807, 4795063, 4795066, 4795067, 4795068, 4795069, 4795087, 4795090, 4795307);

-- New Year's Eve
DELETE FROM `game_event_gameobject` WHERE `eventEntry` = 6 AND `guid` IN (SELECT `guid` FROM `gameobject` WHERE `map` = 751);
INSERT INTO `game_event_gameobject` (`eventEntry`, `guid`) SELECT 6, `guid` FROM `gameobject` WHERE `map` = 751 AND `id` IN (4780698, 4780699, 4780700, 4780905);

-- Midsummer Fire Festival
DELETE FROM `game_event_gameobject` WHERE `eventEntry` = 1 AND `guid` IN (SELECT `guid` FROM `gameobject` WHERE `map` = 751);
INSERT INTO `game_event_gameobject` (`eventEntry`, `guid`) SELECT 1, `guid` FROM `gameobject` WHERE `map` = 751 AND `id` IN (4781371);

-- Hallow's End creatures: the Headless Horseman's fires, the orphans and the wickerman's crowd
DELETE FROM `game_event_creature` WHERE `eventEntry` = 12 AND `guid` IN (SELECT `guid` FROM `creature` WHERE `map` = 751);
INSERT INTO `game_event_creature` (`eventEntry`, `guid`) SELECT 12, `guid` FROM `creature` WHERE `map` = 751 AND `id` IN
(4115197, 4115309, 4123537, 4123971, 4123973, 4153756, 4153757, 4153760, 4153763);

-- Day of the Dead creatures
DELETE FROM `game_event_creature` WHERE `eventEntry` = 51 AND `guid` IN (SELECT `guid` FROM `creature` WHERE `map` = 751);
INSERT INTO `game_event_creature` (`eventEntry`, `guid`) SELECT 51, `guid` FROM `creature` WHERE `map` = 751 AND `id` IN (4134382, 4134383, 4134476, 4135244);

-- Love is in the Air
DELETE FROM `game_event_creature` WHERE `eventEntry` = 8 AND `guid` IN (SELECT `guid` FROM `creature` WHERE `map` = 751);
INSERT INTO `game_event_creature` (`eventEntry`, `guid`) SELECT 8, `guid` FROM `creature` WHERE `map` = 751 AND `id` IN (4137964);

-- Winter Veil
DELETE FROM `game_event_creature` WHERE `eventEntry` = 2 AND `guid` IN (SELECT `guid` FROM `creature` WHERE `map` = 751);
INSERT INTO `game_event_creature` (`eventEntry`, `guid`) SELECT 2, `guid` FROM `creature` WHERE `map` = 751 AND `id` IN (4115730);
