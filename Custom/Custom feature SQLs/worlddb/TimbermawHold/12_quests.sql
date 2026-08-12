-- =====================================================================================
-- Timbermaw Hold -- quest chain
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


SET @GATE := 3999002;
SET @TOKEN := 300311;

DELETE FROM `quest_template_addon` WHERE `ID` BETWEEN 700760 AND 700768;
DELETE FROM `quest_template` WHERE `ID` BETWEEN 700760 AND 700768;

INSERT INTO `quest_template`
    (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `RewardMoney`, `Flags`,
     `LogTitle`, `LogDescription`, `QuestDescription`, `QuestCompletionLog`,
     `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`, `RewardItem1`, `RewardAmount1`) VALUES
    (700760, 2, -1, 128, 0, 400000, 0,
     'The Hold Does Not Answer', 'Enter Timbermaw Hold and report to the Timbermaw Gatekeeper.', 'No word from the deep tunnels in a season. The drums stopped. Go down and find out why.', 'Enter Timbermaw Hold and report to the Timbermaw Gatekeeper.',
     0, 0, @TOKEN, 60),
    (700761, 2, -1, 128, 0, 400000, 0,
     'The Gate Is Held Against Us', 'Defeat Gatewarden Mor''thak.', 'Our own gatewarden bars the way now, and he does not know my voice. Put him down gently if you can.', 'Defeat Gatewarden Mor''thak.',
     4010001, 1, @TOKEN, 60),
    (700762, 2, -1, 128, 0, 400000, 0,
     'The Village Below', 'Defeat the Sundered Chieftain.', 'The chieftain led this hold for forty winters. Whatever wears him now led it into the dark.', 'Defeat the Sundered Chieftain.',
     4010002, 1, @TOKEN, 60),
    (700763, 2, -1, 128, 0, 400000, 0,
     'Cubs of the Nightmare', 'Defeat Den Mother Ursara.', 'The den mother still guards her young. That is the cruel part - she is guarding them from us.', 'Defeat Den Mother Ursara.',
     4010003, 1, @TOKEN, 60),
    (700764, 2, -1, 128, 0, 400000, 0,
     'The Wound in the Wing', 'Defeat Xanthir the Defiler in the Satyr Room.', 'Satyrs in a furbolg hold. They did not walk in - something opened the way for them.', 'Defeat Xanthir the Defiler in the Satyr Room.',
     4010004, 1, @TOKEN, 60),
    (700765, 2, -1, 128, 0, 400000, 0,
     'What Grew in the Dark', 'Defeat the Nightmare Given Root.', 'Past the satyrs the corruption stops pretending to be anything else. It has taken root down there.', 'Defeat the Nightmare Given Root.',
     4010005, 1, @TOKEN, 60),
    (700766, 2, -1, 128, 0, 400000, 0,
     'The Sleeping Twin', 'Defeat Ursol.', 'Ursol dreams, and the hold dreams with him. You will have to go into it. Pinch yourself if it takes you.', 'Defeat Ursol.',
     4010006, 1, @TOKEN, 60),
    (700767, 2, -1, 128, 0, 400000, 0,
     'The Raging Twin', 'Defeat Ursoc.', 'Ursoc does not dream. Ursoc only rages, and something older than the Nightmare is feeding it.', 'Defeat Ursoc.',
     4010007, 1, @TOKEN, 60),
    (700768, 2, -1, 128, 0, 400000, 0,
     'Put Their Spirits to Rest', 'Return to the Timbermaw Gatekeeper.', 'The twin gods are down but they are not at peace. Do this last thing for them, and for us.', 'Return to the Timbermaw Gatekeeper.',
     0, 0, @TOKEN, 60);

-- Chain links. Anything pointing outside this set would make a quest unobtainable,
-- so PrevQuestID/NextQuestID only ever reference ids in the band above.
INSERT INTO `quest_template_addon` (`ID`, `PrevQuestID`, `NextQuestID`) VALUES
    (700760, 0, 700761),
    (700761, 700760, 700762),
    (700762, 700761, 700763),
    (700763, 700762, 700764),
    (700764, 700763, 700765),
    (700765, 700764, 700766),
    (700766, 700765, 700767),
    (700767, 700766, 700768),
    (700768, 700767, 0);

-- Every quest is given AND turned in at the gatekeeper: it stands on map 750 just
-- outside the door, so players never have to leave the instance to hand in.
DELETE FROM `creature_queststarter` WHERE `quest` BETWEEN 700760 AND 700768;
DELETE FROM `creature_questender` WHERE `quest` BETWEEN 700760 AND 700768;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
    (@GATE, 700760),
    (@GATE, 700761),
    (@GATE, 700762),
    (@GATE, 700763),
    (@GATE, 700764),
    (@GATE, 700765),
    (@GATE, 700766),
    (@GATE, 700767),
    (@GATE, 700768);
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
    (@GATE, 700760),
    (@GATE, 700761),
    (@GATE, 700762),
    (@GATE, 700763),
    (@GATE, 700764),
    (@GATE, 700765),
    (@GATE, 700766),
    (@GATE, 700767),
    (@GATE, 700768);

-- The gatekeeper ships as npcflag 1 (gossip only). Without the QUESTGIVER bit none
-- of the above is ever offered.
UPDATE `creature_template` SET `npcflag` = `npcflag` | 2 WHERE `entry` = @GATE;

-- Offer these through the Universal Quest Master too.
DELETE FROM `dc_dungeon_quest_mapping` WHERE `quest_id` BETWEEN 700760 AND 700768;
INSERT INTO `dc_dungeon_quest_mapping` (`quest_id`, `dungeon_id`, `enabled`) VALUES
    (700760, 819, 1),
    (700761, 819, 1),
    (700762, 819, 1),
    (700763, 819, 1),
    (700764, 819, 1),
    (700765, 819, 1),
    (700766, 819, 1),
    (700767, 819, 1),
    (700768, 819, 1);

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
SELECT 'quests (want 9)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `quest_template` WHERE `ID` BETWEEN 700760 AND 700768
UNION ALL SELECT 'chain rows (want 9)', CAST(COUNT(*) AS CHAR)
    FROM `quest_template_addon` WHERE `ID` BETWEEN 700760 AND 700768
UNION ALL SELECT 'quests with no giver (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `quest_template` q LEFT JOIN `creature_queststarter` s ON s.`quest` = q.`ID`
    WHERE q.`ID` BETWEEN 700760 AND 700768 AND s.`quest` IS NULL
UNION ALL SELECT 'quests with no ender (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `quest_template` q LEFT JOIN `creature_questender` e ON e.`quest` = q.`ID`
    WHERE q.`ID` BETWEEN 700760 AND 700768 AND e.`quest` IS NULL
UNION ALL SELECT 'chain links outside the band (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `quest_template_addon` WHERE `ID` BETWEEN 700760 AND 700768
      AND ((`PrevQuestID` <> 0 AND `PrevQuestID` NOT BETWEEN 700760 AND 700768)
        OR (`NextQuestID` <> 0 AND `NextQuestID` NOT BETWEEN 700760 AND 700768))
UNION ALL SELECT 'kill objectives with no creature_template (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `quest_template` q LEFT JOIN `creature_template` c ON c.`entry` = q.`RequiredNpcOrGo1`
    WHERE q.`ID` BETWEEN 700760 AND 700768 AND q.`RequiredNpcOrGo1` > 0 AND c.`entry` IS NULL
UNION ALL SELECT 'gatekeeper is a questgiver (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` = @GATE AND (`npcflag` & 2) = 2;
