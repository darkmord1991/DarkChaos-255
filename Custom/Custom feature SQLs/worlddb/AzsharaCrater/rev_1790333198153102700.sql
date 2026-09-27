-- ---------------------------------------------------------------------------
-- Azshara Crater (map 37) -- the zone 3 and zone 5 hand-offs, 2026-09-25
-- ---------------------------------------------------------------------------
-- 1. 300306 had two quest enders: Scout Thalindra (300001, the zone 1 start hub)
--    and Wavemaster Kol'gar (300030, zone 4). Its text and map marker sent players
--    back to Thalindra, 400 yards and 25 levels behind them. The quest is the zone 3
--    -> zone 4 hand-off: its January title was "The River Awaits", the zones 4-8
--    file added Kol'gar as its ender ("Arrive from Zone 3"), and every other hub
--    hands off to the next one (300106, 300206, 300405, 300505, 300604, 300704).
--    The July lore pass wrote the text from the old log line ("Return to Scout
--    Thalindra") instead. Kol'gar is now the only ender, the January title is
--    back, the text sends the player to him, and the marker points at him.
--    Characters holding 300306 now turn it in to Kol'gar.
--
-- 2. 300505 Into Haldarr Territory (Vex'ara -> Felsworn Kael'thos) had no map
--    marker at all, and no turn-in text either, so Kael'thos showed an empty
--    reward window. Both added.
--
-- Map markers are literal rectangles: quest ender spawn +/- 20 yd, WorldMapAreaId 613.
-- Idempotent: safe to apply twice. Restart afterwards.
-- ---------------------------------------------------------------------------

-- 1. 300306 The River Awaits (Gor'nash -> Kol'gar)
UPDATE `quest_template` SET `LogTitle` = 'The River Awaits',
    `LogDescription` = 'Report to Wavemaster Kol''gar at the river.',
    `QuestDescription` = 'The Thistlefur are broken, $N, and this wood is quiet for the first time since my scouts came to it. That is your doing as much as mine.$B$BBut you did not come to this crater to sit by my fire. Down at the river a troll named Kol''gar holds the shore with his tide-guard, and the naga come out of the water at him every night. He is loud and he is stubborn, and he needs fighters more than he will ever say.$B$BGo to him. Tell him Gor''nash sent you. The river awaits.',
    `QuestCompletionLog` = 'Report to Wavemaster Kol''gar.'
WHERE `ID` = 300306;

DELETE FROM `creature_questender` WHERE `quest` = 300306;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES (300030, 300306);

DELETE FROM `quest_offer_reward` WHERE `ID` = 300306;
INSERT INTO `quest_offer_reward` (`ID`, `RewardText`) VALUES
(300306, 'Gor''nash sent you? HAH! Then the orc finally found someone worth sending.$B$BWelcome to the shore, $N. The Spitelash crawl out of the water every night, and my tide-guard is stretched thin. Catch your breath. Then we go to work.');

DELETE FROM `quest_request_items` WHERE `ID` = 300306;
INSERT INTO `quest_request_items` (`ID`, `EmoteOnComplete`, `EmoteOnIncomplete`, `CompletionText`) VALUES
(300306, 0, 0, 'Gor''nash sent you, did he? Speak up, $N.');

DELETE FROM `quest_poi` WHERE `QuestID` = 300306;
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`) VALUES
(300306, 0, -1, 37, 613, 0, 0, 1, 0);

DELETE FROM `quest_poi_points` WHERE `QuestID` = 300306;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(300306, 0, 0, -71, 493, 0),
(300306, 0, 1, -71, 533, 0),
(300306, 0, 2, -31, 533, 0),
(300306, 0, 3, -31, 493, 0);

-- 2. 300505 Into Haldarr Territory (Vex'ara -> Kael'thos)
DELETE FROM `quest_offer_reward` WHERE `ID` = 300505;
INSERT INTO `quest_offer_reward` (`ID`, `RewardText`) VALUES
(300505, 'The demonologist sent you? Then she has finally smelled what I have smelled for months.$B$BThere is no rest in Haldarr territory, $N. The satyrs root deeper every night, and the Legion watches from the pit. If you can stomach fel on the wind, I can use you.');

DELETE FROM `quest_poi` WHERE `QuestID` = 300505;
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`) VALUES
(300505, 0, -1, 37, 613, 0, 0, 1, 0);

DELETE FROM `quest_poi_points` WHERE `QuestID` = 300505;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(300505, 0, 0, 1094, -106, 0),
(300505, 0, 1, 1094, -66, 0),
(300505, 0, 2, 1134, -66, 0),
(300505, 0, 3, 1134, -106, 0);
