-- =====================================================================================
-- Crescent Grove -- quest chain
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


SET @GATE := 3999005;
SET @TOKEN := 300311;

DELETE FROM `quest_template_addon` WHERE `ID` BETWEEN 700720 AND 700726;
DELETE FROM `quest_template` WHERE `ID` BETWEEN 700720 AND 700726;

INSERT INTO `quest_template`
    (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `RewardMoney`, `Flags`,
     `LogTitle`, `LogDescription`, `QuestDescription`, `QuestCompletionLog`,
     `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`, `RewardItem1`, `RewardAmount1`) VALUES
    (700720, 2, -1, 94, 0, 120000, 0,
     'Where the Moonlight Fails', 'Scout the Crescent Grove and report to the Grove Gatekeeper.', 'The grove was ours once. Now something in the west has torn a wound in it, and the wound is spreading. Go and look, and come back to me.', 'Scout the Crescent Grove and report to the Grove Gatekeeper.',
     0, 0, @TOKEN, 30),
    (700721, 2, -1, 94, 0, 120000, 0,
     'The Keeper''s Fall', 'Defeat Keeper Ranathos.', 'Ranathos kept these trees for three hundred years. Whatever is in him now is not Ranathos. Give him peace.', 'Defeat Keeper Ranathos.',
     4020001, 1, @TOKEN, 30),
    (700722, 2, -1, 94, 0, 120000, 0,
     'Council of Bark and Bone', 'Defeat Grovetender Engryss and both elders.', 'The Grovetender and his elders have gone over to the rot. All three, or none - they will not fall apart.', 'Defeat Grovetender Engryss and both elders.',
     4020002, 1, @TOKEN, 30),
    (700723, 2, -1, 94, 0, 120000, 0,
     'The Moonwell Runs Black', 'Defeat High Priestess A''lathea at the Giant Moonwell.', 'The priestess is drinking from a well that no longer holds moonlight. End it before she finishes.', 'Defeat High Priestess A''lathea at the Giant Moonwell.',
     4020005, 1, @TOKEN, 30),
    (700724, 2, -1, 94, 0, 120000, 0,
     'Into the Vilethorn Scar', 'Defeat Fenektis the Deceiver in the Vilethorn Scar.', 'West of the moonwell the ground itself changes. That is where the satyr Fenektis made the wound. Close it.', 'Defeat Fenektis the Deceiver in the Vilethorn Scar.',
     4020006, 1, @TOKEN, 30),
    (700725, 2, -1, 94, 0, 120000, 0,
     'The Hand Behind the Knife', 'Defeat Master Raxxieth.', 'A satyr does not tear a grove open alone. Something older gave him the blade. Find it behind the brass doors.', 'Defeat Master Raxxieth.',
     4020007, 1, @TOKEN, 30),
    (700726, 2, -1, 94, 0, 120000, 0,
     'What the Grove Remembers', 'Return to the Grove Gatekeeper.', 'The rot is cut out. It will grow back if nobody watches. Take this, and watch.', 'Return to the Grove Gatekeeper.',
     0, 0, @TOKEN, 30);

-- Chain links. Anything pointing outside this set would make a quest unobtainable,
-- so PrevQuestID/NextQuestID only ever reference ids in the band above.
INSERT INTO `quest_template_addon` (`ID`, `PrevQuestID`, `NextQuestID`) VALUES
    (700720, 0, 700721),
    (700721, 700720, 700722),
    (700722, 700721, 700723),
    (700723, 700722, 700724),
    (700724, 700723, 700725),
    (700725, 700724, 700726),
    (700726, 700725, 0);

-- Every quest is given AND turned in at the gatekeeper: it stands on map 750 just
-- outside the door, so players never have to leave the instance to hand in.
DELETE FROM `creature_queststarter` WHERE `quest` BETWEEN 700720 AND 700726;
DELETE FROM `creature_questender` WHERE `quest` BETWEEN 700720 AND 700726;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
    (@GATE, 700720),
    (@GATE, 700721),
    (@GATE, 700722),
    (@GATE, 700723),
    (@GATE, 700724),
    (@GATE, 700725),
    (@GATE, 700726);
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
    (@GATE, 700720),
    (@GATE, 700721),
    (@GATE, 700722),
    (@GATE, 700723),
    (@GATE, 700724),
    (@GATE, 700725),
    (@GATE, 700726);

-- The gatekeeper ships as npcflag 1 (gossip only). Without the QUESTGIVER bit none
-- of the above is ever offered.
UPDATE `creature_template` SET `npcflag` = `npcflag` | 2 WHERE `entry` = @GATE;

-- Offer these through the Universal Quest Master too.
DELETE FROM `dc_dungeon_quest_mapping` WHERE `quest_id` BETWEEN 700720 AND 700726;
INSERT INTO `dc_dungeon_quest_mapping` (`quest_id`, `dungeon_id`, `enabled`) VALUES
    (700720, 823, 1),
    (700721, 823, 1),
    (700722, 823, 1),
    (700723, 823, 1),
    (700724, 823, 1),
    (700725, 823, 1),
    (700726, 823, 1);

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
SELECT 'quests (want 7)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `quest_template` WHERE `ID` BETWEEN 700720 AND 700726
UNION ALL SELECT 'chain rows (want 7)', CAST(COUNT(*) AS CHAR)
    FROM `quest_template_addon` WHERE `ID` BETWEEN 700720 AND 700726
UNION ALL SELECT 'quests with no giver (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `quest_template` q LEFT JOIN `creature_queststarter` s ON s.`quest` = q.`ID`
    WHERE q.`ID` BETWEEN 700720 AND 700726 AND s.`quest` IS NULL
UNION ALL SELECT 'quests with no ender (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `quest_template` q LEFT JOIN `creature_questender` e ON e.`quest` = q.`ID`
    WHERE q.`ID` BETWEEN 700720 AND 700726 AND e.`quest` IS NULL
UNION ALL SELECT 'chain links outside the band (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `quest_template_addon` WHERE `ID` BETWEEN 700720 AND 700726
      AND ((`PrevQuestID` <> 0 AND `PrevQuestID` NOT BETWEEN 700720 AND 700726)
        OR (`NextQuestID` <> 0 AND `NextQuestID` NOT BETWEEN 700720 AND 700726))
UNION ALL SELECT 'kill objectives with no creature_template (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `quest_template` q LEFT JOIN `creature_template` c ON c.`entry` = q.`RequiredNpcOrGo1`
    WHERE q.`ID` BETWEEN 700720 AND 700726 AND q.`RequiredNpcOrGo1` > 0 AND c.`entry` IS NULL
UNION ALL SELECT 'gatekeeper is a questgiver (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` = @GATE AND (`npcflag` & 2) = 2;
