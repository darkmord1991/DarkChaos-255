-- Isle of Giants (map 1405): the zone is named like the retail zone, and the invented subzone names in the
-- invasion, scouting, fishing and token texts are replaced by the retail areas now on the map:
--   Seeping Shores (landing beach, defender line) -> Beeble's Wreck
--   Slimer Bay, Nice's Nice Beach (shoreline)     -> Misty Shores
-- REPLACE() makes every statement a no-op on a second run.

-- Zone name: "Isles of Giants" -> "Isle of Giants"
UPDATE `quest_template` SET `LogDescription` = REPLACE(`LogDescription`, 'Isles of Giants', 'Isle of Giants') WHERE `ID` IN (82016, 400345, 400350);
UPDATE `quest_template` SET `QuestDescription` = REPLACE(`QuestDescription`, 'Isles of Giants', 'Isle of Giants') WHERE `ID` = 82021;
UPDATE `quest_template` SET `QuestCompletionLog` = REPLACE(`QuestCompletionLog`, 'Isles of Giants', 'Isle of Giants') WHERE `ID` IN (82016, 82020, 82021, 82022, 82023);
UPDATE `areatrigger_teleport` SET `Name` = REPLACE(`Name`, 'Isles of Giants', 'Isle of Giants') WHERE `ID` BETWEEN 6963 AND 6984;
UPDATE `game_event` SET `description` = REPLACE(`description`, 'Isles of Giants', 'Isle of Giants') WHERE `eventEntry` IN (251, 252, 253);
UPDATE `dc_path_tasks` SET `name` = REPLACE(`name`, 'Isles of Giants', 'Isle of Giants'), `description` = REPLACE(`description`, 'Isles of Giants', 'Isle of Giants') WHERE `id` = 806;

-- Seeping Shores -> Beeble's Wreck (invasion landing, defender camp)
UPDATE `quest_template` SET `LogDescription` = REPLACE(`LogDescription`, 'Seeping Shores', 'Beeble''s Wreck'), `QuestDescription` = REPLACE(`QuestDescription`, 'Seeping Shores', 'Beeble''s Wreck'), `QuestCompletionLog` = REPLACE(`QuestCompletionLog`, 'Seeping Shores', 'Beeble''s Wreck') WHERE `ID` IN (400340, 400341, 400351);
UPDATE `creature_template` SET `subname` = 'Beeble''s Wreck Defense' WHERE `entry` IN (400365, 400594);
UPDATE `item_template` SET `description` = REPLACE(`description`, 'Seeping Shores', 'Beeble''s Wreck') WHERE `entry` = 400456;

-- Slimer Bay -> Misty Shores (canoes, cages)
UPDATE `quest_template` SET `LogDescription` = REPLACE(`LogDescription`, 'at Slimer Bay', 'on the Misty Shores'), `QuestDescription` = REPLACE(`QuestDescription`, 'at Slimer Bay', 'on da Misty Shores'), `ObjectiveText1` = REPLACE(`ObjectiveText1`, 'Slimer Bay canoes', 'Misty Shores canoes') WHERE `ID` = 400344;
UPDATE `quest_template` SET `LogDescription` = REPLACE(`LogDescription`, 'at Slimer Bay and the bunkers', 'on the Misty Shores and at the bunkers'), `QuestDescription` = REPLACE(`QuestDescription`, 'Da cages at Slimer Bay', 'Da cages on da Misty Shores') WHERE `ID` = 400348;
UPDATE `creature_template` SET `name` = 'Misty Shores Canoes' WHERE `entry` = 400591;

-- Nice's Nice Beach -> Misty Shores (fishing dailies)
UPDATE `quest_template` SET `AreaDescription` = REPLACE(`AreaDescription`, 'Nice''s Nice Beach', 'Misty Shores'), `QuestCompletionLog` = REPLACE(`QuestCompletionLog`, 'at Nice''s Nice Beach', 'on the Misty Shores') WHERE `ID` IN (83100, 83101, 83102);
