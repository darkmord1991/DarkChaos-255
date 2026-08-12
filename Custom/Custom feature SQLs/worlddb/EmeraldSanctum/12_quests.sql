-- =====================================================================================
-- Emerald Sanctum -- quest chain
--
-- IDS ARE IN THE 700711-708999 BAND ON PURPOSE. DungeonQuestPlayerScript::OnPlayerCompleteQuest
-- fires the token award, stat tracking, dungeon progress and the 13500-13514 achievement ladder
-- for any quest in that band -- and for nothing outside it. The free 90xxx space next to BFD's
-- 90001-90011 would have worked as SQL and silently earned the player none of that.
--
-- QuestLevel -1 = player-scaled. That used to zero the token income silently (GetQuestLevel
-- returns int32 but the token hook took uint32, so -1 wrapped and graded every scaled quest
-- Trivial); the C++ fix has landed, so -1 is correct now.
--
-- The gatekeeper NPC stands OUTSIDE the instance on map 750, so it is a genuine world-side hub
-- and no new questgivers had to be placed. It needs npcflag |= 2 or none of this is offered --
-- 3999002 / 3999005 / 3999007 all ship as gossip-only.
-- =====================================================================================


SET @GATE := 3999007;
SET @TOKEN := 300311;

DELETE FROM `quest_template_addon` WHERE `ID` BETWEEN 700800 AND 700805;
DELETE FROM `quest_template` WHERE `ID` BETWEEN 700800 AND 700805;

INSERT INTO `quest_template`
    (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `RewardMoney`, `Flags`,
     `LogTitle`, `LogDescription`, `QuestDescription`, `QuestCompletionLog`,
     `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`, `RewardItem1`, `RewardAmount1`) VALUES
    (700800, 2, -1, 128, 0, 400000, 0,
     'Into the Dream', 'Speak with the Sanctum Gatekeeper.', 'The green flight kept a waystation here. Its keepers stopped answering, and the fog that came out is not sleep.', 'Speak with the Sanctum Gatekeeper.',
     0, 0, @TOKEN, 60),
    (700801, 2, -1, 128, 0, 400000, 0,
     'Oathstone of the Dreamer', 'Obtain an Oathstone of Ysera''s Dragonflight.', 'You cannot walk in there awake and you cannot walk in there alone. Carry the oathstone - it will hold your name.', 'Obtain an Oathstone of Ysera''s Dragonflight.',
     0, 0, @TOKEN, 60),
    (700802, 2, -1, 128, 0, 400000, 0,
     'Gemstone of Ysera', 'Receive the Gemstone of Ysera from the Sanctum Gatekeeper.', 'The gemstone is the last of it. With this you can cross into the Sanctum without the fog taking you.', 'Receive the Gemstone of Ysera from the Sanctum Gatekeeper.',
     0, 0, @TOKEN, 60),
    (700803, 2, -1, 128, 0, 400000, 0,
     'The Warden Who Stayed', 'Defeat Erennius.', 'One warden held the gate the whole time. He is still holding it, and he no longer knows why.', 'Defeat Erennius.',
     4030001, 1, @TOKEN, 60),
    (700804, 2, -1, 128, 0, 400000, 0,
     'This Week''s Wakener', 'Defeat the Wakener occupying the Emerald Sanctum.', 'One of the flight is trying to sound the waking call early. Which one it is changes - the Dream does not keep to our order.', 'Defeat the Wakener occupying the Emerald Sanctum.',
     4030002, 1, @TOKEN, 60),
    (700805, 2, -1, 128, 0, 400000, 0,
     'Let Them Sleep', 'Return to the Sanctum Gatekeeper.', 'The call is silenced for now. Come back when the next one starts - and one will.', 'Return to the Sanctum Gatekeeper.',
     0, 0, @TOKEN, 60);

-- Chain links. Anything pointing outside this set would make a quest unobtainable,
-- so PrevQuestID/NextQuestID only ever reference ids in the band above.
INSERT INTO `quest_template_addon` (`ID`, `PrevQuestID`, `NextQuestID`) VALUES
    (700800, 0, 700801),
    (700801, 700800, 700802),
    (700802, 700801, 700803),
    (700803, 700802, 700804),
    (700804, 700803, 700805),
    (700805, 700804, 0);

-- Every quest is given AND turned in at the gatekeeper: it stands on map 750 just
-- outside the door, so players never have to leave the instance to hand in.
DELETE FROM `creature_queststarter` WHERE `quest` BETWEEN 700800 AND 700805;
DELETE FROM `creature_questender` WHERE `quest` BETWEEN 700800 AND 700805;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
    (@GATE, 700800),
    (@GATE, 700801),
    (@GATE, 700802),
    (@GATE, 700803),
    (@GATE, 700804),
    (@GATE, 700805);
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
    (@GATE, 700800),
    (@GATE, 700801),
    (@GATE, 700802),
    (@GATE, 700803),
    (@GATE, 700804),
    (@GATE, 700805);

-- The gatekeeper ships as npcflag 1 (gossip only). Without the QUESTGIVER bit none
-- of the above is ever offered.
UPDATE `creature_template` SET `npcflag` = `npcflag` | 2 WHERE `entry` = @GATE;

-- Offer these through the Universal Quest Master too.
DELETE FROM `dc_dungeon_quest_mapping` WHERE `quest_id` BETWEEN 700800 AND 700805;
INSERT INTO `dc_dungeon_quest_mapping` (`quest_id`, `dungeon_id`, `enabled`) VALUES
    (700800, 824, 1),
    (700801, 824, 1),
    (700802, 824, 1),
    (700803, 824, 1),
    (700804, 824, 1),
    (700805, 824, 1);

-- ATTUNEMENT. There is no DC attunement system, but stock AzerothCore's
-- `dungeon_access_requirements` already is one and is fully wired:
--   requirement_type 0 = achievement, 1 = quest, 2 = item ; faction 0/1/2
-- `requirement_note` is the refusal message the player actually sees.
-- Gated on the LAST quest of the Into the Dream chain (700802).
DELETE FROM `dungeon_access_requirements` WHERE `dungeon_access_id` IN (151, 156, 157);
INSERT INTO `dungeon_access_requirements`
    (`dungeon_access_id`, `requirement_type`, `requirement_id`, `requirement_note`, `faction`, `leader_only`) VALUES
    (151, 1, 700802, 'You must complete "Into the Dream" before entering the Emerald Sanctum.', 2, 0),
    (156, 1, 700802, 'You must complete "Into the Dream" before entering the Emerald Sanctum.', 2, 0),
    (157, 1, 700802, 'You must complete "Into the Dream" before entering the Emerald Sanctum.', 2, 0);
-- Reloadable in place with `.reload access_requirement`.

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
SELECT 'quests (want 6)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `quest_template` WHERE `ID` BETWEEN 700800 AND 700805
UNION ALL SELECT 'chain rows (want 6)', CAST(COUNT(*) AS CHAR)
    FROM `quest_template_addon` WHERE `ID` BETWEEN 700800 AND 700805
UNION ALL SELECT 'quests with no giver (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `quest_template` q LEFT JOIN `creature_queststarter` s ON s.`quest` = q.`ID`
    WHERE q.`ID` BETWEEN 700800 AND 700805 AND s.`quest` IS NULL
UNION ALL SELECT 'quests with no ender (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `quest_template` q LEFT JOIN `creature_questender` e ON e.`quest` = q.`ID`
    WHERE q.`ID` BETWEEN 700800 AND 700805 AND e.`quest` IS NULL
UNION ALL SELECT 'chain links outside the band (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `quest_template_addon` WHERE `ID` BETWEEN 700800 AND 700805
      AND ((`PrevQuestID` <> 0 AND `PrevQuestID` NOT BETWEEN 700800 AND 700805)
        OR (`NextQuestID` <> 0 AND `NextQuestID` NOT BETWEEN 700800 AND 700805))
UNION ALL SELECT 'kill objectives with no creature_template (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `quest_template` q LEFT JOIN `creature_template` c ON c.`entry` = q.`RequiredNpcOrGo1`
    WHERE q.`ID` BETWEEN 700800 AND 700805 AND q.`RequiredNpcOrGo1` > 0 AND c.`entry` IS NULL
UNION ALL SELECT 'gatekeeper is a questgiver (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` = @GATE AND (`npcflag` & 2) = 2;
