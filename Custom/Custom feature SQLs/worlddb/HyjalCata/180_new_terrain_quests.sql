-- ---------------------------------------------------------------------------
-- 180  Hyjal round-44 -- quest layer for the expanded terrain (phase 2 of 178_)
-- ---------------------------------------------------------------------------
-- 178_ put ~6,300 NPCs and ~1,700 objects on the ground added by the 108 -> 279
-- tile expansion.  They currently offer nothing: quests are a separate layer,
-- exactly as 176_ (content) was followed by 177_ (quests).
--
-- SEED: 104 questgiver NPCs stand on the new terrain, starting 194 quests and
-- ending 201.  From that seed the chain-walk below follows PrevQuestID,
-- NextQuestID, BreadcrumbForQuestId and RewardNextQuest to closure, so partial
-- chains do not ship.
--
-- IDS ARE RAW (no offset).  Quest ids are cloned unchanged and every insert is
-- INSERT IGNORE, so a WotLK quest that already owns an id keeps it and the Cata
-- quest is skipped rather than overwriting live content.  Only the NPC-side
-- links carry +@OFF, matching the cloned creature entries.
--
-- KNOWN LIMIT, same as 177_: Ashenvale and Azshara chains that continue into
-- Kalimdor proper (Stonetalon, Durotar, Orgrimmar, Darnassus) DEAD-END at the
-- map edge -- their next questgiver is not on map 750 and is not imported here.
-- That is inherent to carving zones out of a continent, not a defect in this
-- file.  Breadcrumbs INTO the region are cloned so the chains are reachable.
--
-- ORDER: strictly after 178_ -- the +@OFF creature entries it creates are what
-- the queststarter/questender rows below point at.
-- ---------------------------------------------------------------------------

SET @OFF := 3600000;

DROP TABLE IF EXISTS `_dc_ntq_mask`;
CREATE TABLE `_dc_ntq_mask` (
  `xmin` FLOAT NOT NULL, `xmax` FLOAT NOT NULL,
  `ymin` FLOAT NOT NULL, `ymax` FLOAT NOT NULL
) ENGINE=InnoDB;
INSERT INTO `_dc_ntq_mask` (`xmin`,`xmax`,`ymin`,`ymax`) VALUES
(6933.333,7466.667,2133.333,2666.667),
(6400.0,6933.333,2133.333,2666.667),
(5866.667,6400.0,2133.333,2666.667),
(5333.333,5866.667,2133.333,2666.667),
(4800.0,5333.333,2133.333,2666.667),
(4266.667,4800.0,2133.333,2666.667),
(3733.333,4266.667,2133.333,2666.667),
(3200.0,3733.333,2133.333,2666.667),
(2666.667,3200.0,2133.333,2666.667),
(6933.333,7466.667,1600.0,2133.333),
(6400.0,6933.333,1600.0,2133.333),
(5866.667,6400.0,1600.0,2133.333),
(5333.333,5866.667,1600.0,2133.333),
(4800.0,5333.333,1600.0,2133.333),
(4266.667,4800.0,1600.0,2133.333),
(3733.333,4266.667,1600.0,2133.333),
(3200.0,3733.333,1600.0,2133.333),
(2666.667,3200.0,1600.0,2133.333),
(7466.667,8000.0,1066.667,1600.0),
(6933.333,7466.667,1066.667,1600.0),
(6400.0,6933.333,1066.667,1600.0),
(5866.667,6400.0,1066.667,1600.0),
(5333.333,5866.667,1066.667,1600.0),
(4800.0,5333.333,1066.667,1600.0),
(4266.667,4800.0,1066.667,1600.0),
(3733.333,4266.667,1066.667,1600.0),
(3200.0,3733.333,1066.667,1600.0),
(2666.667,3200.0,1066.667,1600.0),
(2666.667,3200.0,533.333,1066.667),
(2133.333,2666.667,533.333,1066.667),
(1600.0,2133.333,533.333,1066.667),
(8000.0,8533.333,0.0,533.333),
(2666.667,3200.0,0.0,533.333),
(2133.333,2666.667,0.0,533.333),
(1600.0,2133.333,0.0,533.333),
(8000.0,8533.333,-533.333,0.0),
(2666.667,3200.0,-533.333,0.0),
(2133.333,2666.667,-533.333,0.0),
(1600.0,2133.333,-533.333,0.0),
(8533.333,9066.667,-1066.667,-533.333),
(8000.0,8533.333,-1066.667,-533.333),
(2666.667,3200.0,-1066.667,-533.333),
(2133.333,2666.667,-1066.667,-533.333),
(1600.0,2133.333,-1066.667,-533.333),
(8533.333,9066.667,-1600.0,-1066.667),
(8000.0,8533.333,-1600.0,-1066.667),
(2666.667,3200.0,-1600.0,-1066.667),
(2133.333,2666.667,-1600.0,-1066.667),
(1600.0,2133.333,-1600.0,-1066.667),
(1066.667,1600.0,-1600.0,-1066.667),
(8533.333,9066.667,-2133.333,-1600.0),
(8000.0,8533.333,-2133.333,-1600.0),
(2666.667,3200.0,-2133.333,-1600.0),
(2133.333,2666.667,-2133.333,-1600.0),
(1600.0,2133.333,-2133.333,-1600.0),
(1066.667,1600.0,-2133.333,-1600.0),
(8533.333,9066.667,-2666.667,-2133.333),
(8000.0,8533.333,-2666.667,-2133.333),
(2666.667,3200.0,-2666.667,-2133.333),
(2133.333,2666.667,-2666.667,-2133.333),
(1600.0,2133.333,-2666.667,-2133.333),
(1066.667,1600.0,-2666.667,-2133.333),
(8533.333,9066.667,-3200.0,-2666.667),
(8000.0,8533.333,-3200.0,-2666.667),
(2666.667,3200.0,-3200.0,-2666.667),
(2133.333,2666.667,-3200.0,-2666.667),
(1600.0,2133.333,-3200.0,-2666.667),
(1066.667,1600.0,-3200.0,-2666.667),
(8533.333,9066.667,-3733.333,-3200.0),
(8000.0,8533.333,-3733.333,-3200.0),
(2666.667,3200.0,-3733.333,-3200.0),
(2133.333,2666.667,-3733.333,-3200.0),
(1600.0,2133.333,-3733.333,-3200.0),
(1066.667,1600.0,-3733.333,-3200.0),
(8533.333,9066.667,-4266.667,-3733.333),
(8000.0,8533.333,-4266.667,-3733.333),
(2666.667,3200.0,-4266.667,-3733.333),
(2133.333,2666.667,-4266.667,-3733.333),
(1600.0,2133.333,-4266.667,-3733.333),
(8533.333,9066.667,-4800.0,-4266.667),
(8000.0,8533.333,-4800.0,-4266.667),
(2666.667,3200.0,-4800.0,-4266.667),
(2133.333,2666.667,-4800.0,-4266.667),
(8533.333,9066.667,-5333.333,-4800.0),
(8000.0,8533.333,-5333.333,-4800.0),
(2666.667,3200.0,-5333.333,-4800.0),
(2133.333,2666.667,-5333.333,-4800.0),
(8533.333,9066.667,-5866.667,-5333.333),
(8000.0,8533.333,-5866.667,-5333.333),
(7466.667,8000.0,-5866.667,-5333.333),
(6933.333,7466.667,-5866.667,-5333.333),
(6400.0,6933.333,-5866.667,-5333.333),
(5866.667,6400.0,-5866.667,-5333.333),
(5333.333,5866.667,-5866.667,-5333.333),
(4800.0,5333.333,-5866.667,-5333.333),
(4266.667,4800.0,-5866.667,-5333.333),
(3733.333,4266.667,-5866.667,-5333.333),
(3200.0,3733.333,-5866.667,-5333.333),
(2666.667,3200.0,-5866.667,-5333.333),
(2133.333,2666.667,-5866.667,-5333.333),
(1600.0,2133.333,-5866.667,-5333.333),
(1066.667,1600.0,-5866.667,-5333.333),
(8533.333,9066.667,-6400.0,-5866.667),
(8000.0,8533.333,-6400.0,-5866.667),
(7466.667,8000.0,-6400.0,-5866.667),
(6933.333,7466.667,-6400.0,-5866.667),
(6400.0,6933.333,-6400.0,-5866.667),
(5866.667,6400.0,-6400.0,-5866.667),
(5333.333,5866.667,-6400.0,-5866.667),
(4800.0,5333.333,-6400.0,-5866.667),
(4266.667,4800.0,-6400.0,-5866.667),
(3733.333,4266.667,-6400.0,-5866.667),
(3200.0,3733.333,-6400.0,-5866.667),
(2666.667,3200.0,-6400.0,-5866.667),
(2133.333,2666.667,-6400.0,-5866.667),
(1600.0,2133.333,-6400.0,-5866.667),
(1066.667,1600.0,-6400.0,-5866.667),
(8533.333,9066.667,-6933.333,-6400.0),
(8000.0,8533.333,-6933.333,-6400.0),
(7466.667,8000.0,-6933.333,-6400.0),
(6933.333,7466.667,-6933.333,-6400.0),
(6400.0,6933.333,-6933.333,-6400.0),
(5866.667,6400.0,-6933.333,-6400.0),
(5333.333,5866.667,-6933.333,-6400.0),
(4800.0,5333.333,-6933.333,-6400.0),
(4266.667,4800.0,-6933.333,-6400.0),
(3733.333,4266.667,-6933.333,-6400.0),
(3200.0,3733.333,-6933.333,-6400.0),
(2666.667,3200.0,-6933.333,-6400.0),
(2133.333,2666.667,-6933.333,-6400.0),
(1600.0,2133.333,-6933.333,-6400.0),
(1066.667,1600.0,-6933.333,-6400.0),
(5866.667,6400.0,-7466.667,-6933.333),
(5333.333,5866.667,-7466.667,-6933.333),
(4800.0,5333.333,-7466.667,-6933.333),
(4266.667,4800.0,-7466.667,-6933.333),
(3733.333,4266.667,-7466.667,-6933.333),
(3200.0,3733.333,-7466.667,-6933.333),
(2666.667,3200.0,-7466.667,-6933.333),
(2133.333,2666.667,-7466.667,-6933.333),
(1600.0,2133.333,-7466.667,-6933.333),
(1066.667,1600.0,-7466.667,-6933.333),
(5866.667,6400.0,-8000.0,-7466.667),
(5333.333,5866.667,-8000.0,-7466.667),
(4800.0,5333.333,-8000.0,-7466.667),
(4266.667,4800.0,-8000.0,-7466.667),
(3733.333,4266.667,-8000.0,-7466.667),
(3200.0,3733.333,-8000.0,-7466.667),
(2666.667,3200.0,-8000.0,-7466.667),
(2133.333,2666.667,-8000.0,-7466.667),
(1600.0,2133.333,-8000.0,-7466.667),
(1066.667,1600.0,-8000.0,-7466.667),
(5866.667,6400.0,-8533.333,-8000.0),
(5333.333,5866.667,-8533.333,-8000.0),
(4800.0,5333.333,-8533.333,-8000.0),
(4266.667,4800.0,-8533.333,-8000.0),
(3733.333,4266.667,-8533.333,-8000.0),
(3200.0,3733.333,-8533.333,-8000.0),
(2666.667,3200.0,-8533.333,-8000.0),
(2133.333,2666.667,-8533.333,-8000.0),
(1600.0,2133.333,-8533.333,-8000.0),
(1066.667,1600.0,-8533.333,-8000.0),
(5333.333,5866.667,-9066.667,-8533.333),
(4800.0,5333.333,-9066.667,-8533.333),
(4266.667,4800.0,-9066.667,-8533.333),
(3733.333,4266.667,-9066.667,-8533.333),
(3200.0,3733.333,-9066.667,-8533.333),
(2666.667,3200.0,-9066.667,-8533.333),
(2133.333,2666.667,-9066.667,-8533.333),
(1600.0,2133.333,-9066.667,-8533.333),
(1066.667,1600.0,-9066.667,-8533.333);

-- Mount Hyjal (DCMountHyjal, map 750)
-- dc_entry = 3,600,000 + original (isolated, tunable). Source cata_world(TDB434)->acore_world. Cross-DB INSERT...SELECT.


-- 4.3.4 quests are monolithic -> plain clone. Temp table expands the prereq/next/breadcrumb chain closure.
DROP TEMPORARY TABLE IF EXISTS _dc_q;  CREATE TEMPORARY TABLE _dc_q  (q INT UNSIGNED PRIMARY KEY) ENGINE=MEMORY;
DROP TEMPORARY TABLE IF EXISTS _dc_q2; CREATE TEMPORARY TABLE _dc_q2 (q INT UNSIGNED PRIMARY KEY) ENGINE=MEMORY;
INSERT IGNORE INTO _dc_q (q) SELECT quest FROM cata_world.creature_queststarter WHERE id IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId IN (16,148,331,493,618) AND EXISTS (SELECT 1 FROM `_dc_ntq_mask` m WHERE c.position_x > m.`xmin` AND c.position_x <= m.`xmax` AND c.position_y > m.`ymin` AND c.position_y <= m.`ymax`)))
  UNION SELECT quest FROM cata_world.creature_questender WHERE id IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId IN (16,148,331,493,618) AND EXISTS (SELECT 1 FROM `_dc_ntq_mask` m WHERE c.position_x > m.`xmin` AND c.position_x <= m.`xmax` AND c.position_y > m.`ymin` AND c.position_y <= m.`ymax`)));
-- expand prereq/next/breadcrumb chain closure. MySQL forbids referencing a TEMP table twice in one
-- statement, so each pass derives new refs into helper _dc_q2 (joining _dc_q once) then merges it back.
DELETE FROM _dc_q2;
INSERT IGNORE INTO _dc_q2 (q) SELECT d.ref FROM (SELECT x.ref FROM (
  SELECT ID qid, PrevQuestID ref FROM cata_world.quest_template_addon WHERE PrevQuestID<>0
  UNION ALL SELECT ID, NextQuestID FROM cata_world.quest_template_addon WHERE NextQuestID<>0
  UNION ALL SELECT ID, BreadcrumbForQuestId FROM cata_world.quest_template_addon WHERE BreadcrumbForQuestId<>0
  UNION ALL SELECT ID, RewardNextQuest FROM cata_world.quest_template WHERE RewardNextQuest<>0) x
  JOIN _dc_q c ON c.q=x.qid WHERE x.ref IN (SELECT ID FROM cata_world.quest_template)) d;
INSERT IGNORE INTO _dc_q (q) SELECT q FROM _dc_q2;
DELETE FROM _dc_q2;
INSERT IGNORE INTO _dc_q2 (q) SELECT d.ref FROM (SELECT x.ref FROM (
  SELECT ID qid, PrevQuestID ref FROM cata_world.quest_template_addon WHERE PrevQuestID<>0
  UNION ALL SELECT ID, NextQuestID FROM cata_world.quest_template_addon WHERE NextQuestID<>0
  UNION ALL SELECT ID, BreadcrumbForQuestId FROM cata_world.quest_template_addon WHERE BreadcrumbForQuestId<>0
  UNION ALL SELECT ID, RewardNextQuest FROM cata_world.quest_template WHERE RewardNextQuest<>0) x
  JOIN _dc_q c ON c.q=x.qid WHERE x.ref IN (SELECT ID FROM cata_world.quest_template)) d;
INSERT IGNORE INTO _dc_q (q) SELECT q FROM _dc_q2;
DELETE FROM _dc_q2;
INSERT IGNORE INTO _dc_q2 (q) SELECT d.ref FROM (SELECT x.ref FROM (
  SELECT ID qid, PrevQuestID ref FROM cata_world.quest_template_addon WHERE PrevQuestID<>0
  UNION ALL SELECT ID, NextQuestID FROM cata_world.quest_template_addon WHERE NextQuestID<>0
  UNION ALL SELECT ID, BreadcrumbForQuestId FROM cata_world.quest_template_addon WHERE BreadcrumbForQuestId<>0
  UNION ALL SELECT ID, RewardNextQuest FROM cata_world.quest_template WHERE RewardNextQuest<>0) x
  JOIN _dc_q c ON c.q=x.qid WHERE x.ref IN (SELECT ID FROM cata_world.quest_template)) d;
INSERT IGNORE INTO _dc_q (q) SELECT q FROM _dc_q2;
DELETE FROM _dc_q2;
INSERT IGNORE INTO _dc_q2 (q) SELECT d.ref FROM (SELECT x.ref FROM (
  SELECT ID qid, PrevQuestID ref FROM cata_world.quest_template_addon WHERE PrevQuestID<>0
  UNION ALL SELECT ID, NextQuestID FROM cata_world.quest_template_addon WHERE NextQuestID<>0
  UNION ALL SELECT ID, BreadcrumbForQuestId FROM cata_world.quest_template_addon WHERE BreadcrumbForQuestId<>0
  UNION ALL SELECT ID, RewardNextQuest FROM cata_world.quest_template WHERE RewardNextQuest<>0) x
  JOIN _dc_q c ON c.q=x.qid WHERE x.ref IN (SELECT ID FROM cata_world.quest_template)) d;
INSERT IGNORE INTO _dc_q (q) SELECT q FROM _dc_q2;
DELETE FROM _dc_q2;
INSERT IGNORE INTO _dc_q2 (q) SELECT d.ref FROM (SELECT x.ref FROM (
  SELECT ID qid, PrevQuestID ref FROM cata_world.quest_template_addon WHERE PrevQuestID<>0
  UNION ALL SELECT ID, NextQuestID FROM cata_world.quest_template_addon WHERE NextQuestID<>0
  UNION ALL SELECT ID, BreadcrumbForQuestId FROM cata_world.quest_template_addon WHERE BreadcrumbForQuestId<>0
  UNION ALL SELECT ID, RewardNextQuest FROM cata_world.quest_template WHERE RewardNextQuest<>0) x
  JOIN _dc_q c ON c.q=x.qid WHERE x.ref IN (SELECT ID FROM cata_world.quest_template)) d;
INSERT IGNORE INTO _dc_q (q) SELECT q FROM _dc_q2;
DELETE FROM _dc_q2;
INSERT IGNORE INTO _dc_q2 (q) SELECT d.ref FROM (SELECT x.ref FROM (
  SELECT ID qid, PrevQuestID ref FROM cata_world.quest_template_addon WHERE PrevQuestID<>0
  UNION ALL SELECT ID, NextQuestID FROM cata_world.quest_template_addon WHERE NextQuestID<>0
  UNION ALL SELECT ID, BreadcrumbForQuestId FROM cata_world.quest_template_addon WHERE BreadcrumbForQuestId<>0
  UNION ALL SELECT ID, RewardNextQuest FROM cata_world.quest_template WHERE RewardNextQuest<>0) x
  JOIN _dc_q c ON c.q=x.qid WHERE x.ref IN (SELECT ID FROM cata_world.quest_template)) d;
INSERT IGNORE INTO _dc_q (q) SELECT q FROM _dc_q2;
DELETE FROM _dc_q2;
INSERT IGNORE INTO _dc_q2 (q) SELECT d.ref FROM (SELECT x.ref FROM (
  SELECT ID qid, PrevQuestID ref FROM cata_world.quest_template_addon WHERE PrevQuestID<>0
  UNION ALL SELECT ID, NextQuestID FROM cata_world.quest_template_addon WHERE NextQuestID<>0
  UNION ALL SELECT ID, BreadcrumbForQuestId FROM cata_world.quest_template_addon WHERE BreadcrumbForQuestId<>0
  UNION ALL SELECT ID, RewardNextQuest FROM cata_world.quest_template WHERE RewardNextQuest<>0) x
  JOIN _dc_q c ON c.q=x.qid WHERE x.ref IN (SELECT ID FROM cata_world.quest_template)) d;
INSERT IGNORE INTO _dc_q (q) SELECT q FROM _dc_q2;
DELETE FROM _dc_q2;
INSERT IGNORE INTO _dc_q2 (q) SELECT d.ref FROM (SELECT x.ref FROM (
  SELECT ID qid, PrevQuestID ref FROM cata_world.quest_template_addon WHERE PrevQuestID<>0
  UNION ALL SELECT ID, NextQuestID FROM cata_world.quest_template_addon WHERE NextQuestID<>0
  UNION ALL SELECT ID, BreadcrumbForQuestId FROM cata_world.quest_template_addon WHERE BreadcrumbForQuestId<>0
  UNION ALL SELECT ID, RewardNextQuest FROM cata_world.quest_template WHERE RewardNextQuest<>0) x
  JOIN _dc_q c ON c.q=x.qid WHERE x.ref IN (SELECT ID FROM cata_world.quest_template)) d;
INSERT IGNORE INTO _dc_q (q) SELECT q FROM _dc_q2;
-- capture CATA-NEW quests (ours) before insert so the objective remap only touches quests we own
DROP TEMPORARY TABLE IF EXISTS _dc_qnew; CREATE TEMPORARY TABLE _dc_qnew (q INT UNSIGNED PRIMARY KEY) ENGINE=MEMORY;
INSERT IGNORE INTO _dc_qnew SELECT q FROM _dc_q WHERE q NOT IN (SELECT ID FROM acore_world.quest_template);
INSERT IGNORE INTO acore_world.quest_template (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RequiredFactionId1`, `RequiredFactionId2`, `RequiredFactionValue1`, `RequiredFactionValue2`, `RewardNextQuest`, `RewardXPDifficulty`, `RewardMoney`, `RewardDisplaySpell`, `RewardSpell`, `RewardHonor`, `RewardKillHonor`, `StartItem`, `Flags`, `RequiredPlayerKills`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `RewardItem4`, `RewardAmount4`, `ItemDrop1`, `ItemDropQuantity1`, `ItemDrop2`, `ItemDropQuantity2`, `ItemDrop3`, `ItemDropQuantity3`, `ItemDrop4`, `ItemDropQuantity4`, `RewardChoiceItemID1`, `RewardChoiceItemQuantity1`, `RewardChoiceItemID2`, `RewardChoiceItemQuantity2`, `RewardChoiceItemID3`, `RewardChoiceItemQuantity3`, `RewardChoiceItemID4`, `RewardChoiceItemQuantity4`, `RewardChoiceItemID5`, `RewardChoiceItemQuantity5`, `RewardChoiceItemID6`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`, `POIy`, `POIPriority`, `RewardTitle`, `RewardTalents`, `RewardArenaPoints`, `RewardFactionID1`, `RewardFactionValue1`, `RewardFactionOverride1`, `RewardFactionID2`, `RewardFactionValue2`, `RewardFactionOverride2`, `RewardFactionID3`, `RewardFactionValue3`, `RewardFactionOverride3`, `RewardFactionID4`, `RewardFactionValue4`, `RewardFactionOverride4`, `RewardFactionID5`, `RewardFactionValue5`, `RewardFactionOverride5`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`, `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`, `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`, `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`, `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `ObjectiveText1`, `ObjectiveText2`, `ObjectiveText3`, `ObjectiveText4`, `VerifiedBuild`)
SELECT `ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RequiredFactionId1`, `RequiredFactionId2`, `RequiredFactionValue1`, `RequiredFactionValue2`, `RewardNextQuest`, `RewardXPDifficulty`, `RewardMoney`, `RewardDisplaySpell`, `RewardSpell`, `RewardHonor`, `RewardKillHonor`, `StartItem`, `Flags`, `RequiredPlayerKills`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `RewardItem4`, `RewardAmount4`, `ItemDrop1`, `ItemDropQuantity1`, `ItemDrop2`, `ItemDropQuantity2`, `ItemDrop3`, `ItemDropQuantity3`, `ItemDrop4`, `ItemDropQuantity4`, `RewardChoiceItemID1`, `RewardChoiceItemQuantity1`, `RewardChoiceItemID2`, `RewardChoiceItemQuantity2`, `RewardChoiceItemID3`, `RewardChoiceItemQuantity3`, `RewardChoiceItemID4`, `RewardChoiceItemQuantity4`, `RewardChoiceItemID5`, `RewardChoiceItemQuantity5`, `RewardChoiceItemID6`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`, `POIy`, `POIPriority`, `RewardTitle`, `RewardTalents`, `RewardArenaPoints`, `RewardFactionID1`, `RewardFactionValue1`, `RewardFactionOverride1`, `RewardFactionID2`, `RewardFactionValue2`, `RewardFactionOverride2`, `RewardFactionID3`, `RewardFactionValue3`, `RewardFactionOverride3`, `RewardFactionID4`, `RewardFactionValue4`, `RewardFactionOverride4`, `RewardFactionID5`, `RewardFactionValue5`, `RewardFactionOverride5`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`, `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`, `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`, `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`, `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `ObjectiveText1`, `ObjectiveText2`, `ObjectiveText3`, `ObjectiveText4`, `VerifiedBuild` FROM cata_world.quest_template WHERE ID IN (SELECT q FROM _dc_q) AND ID NOT IN (SELECT ID FROM acore_world.quest_template);
INSERT IGNORE INTO acore_world.quest_template_addon (`ID`, `MaxLevel`, `AllowableClasses`, `SourceSpellID`, `PrevQuestID`, `NextQuestID`, `ExclusiveGroup`, `BreadcrumbForQuestId`, `RewardMailTemplateID`, `RewardMailDelay`, `RequiredSkillID`, `RequiredSkillPoints`, `RequiredMinRepFaction`, `RequiredMaxRepFaction`, `RequiredMinRepValue`, `RequiredMaxRepValue`, `ProvidedItemCount`, `SpecialFlags`)
SELECT `ID`, `MaxLevel`, `AllowableClasses`, `SourceSpellID`, `PrevQuestID`, `NextQuestID`, `ExclusiveGroup`, `BreadcrumbForQuestId`, `RewardMailTemplateID`, `RewardMailDelay`, `RequiredSkillID`, `RequiredSkillPoints`, `RequiredMinRepFaction`, `RequiredMaxRepFaction`, `RequiredMinRepValue`, `RequiredMaxRepValue`, `ProvidedItemCount`, `SpecialFlags` FROM cata_world.quest_template_addon WHERE ID IN (SELECT q FROM _dc_q) AND ID NOT IN (SELECT ID FROM acore_world.quest_template_addon);
-- remap kill/use objectives on OUR quests to the +@OFF clones (creature +, GO -); only entities we cloned.
UPDATE acore_world.quest_template SET
  `RequiredNpcOrGo1` = CASE WHEN `RequiredNpcOrGo1`>0 AND `RequiredNpcOrGo1` IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId IN (16,148,331,493,618) AND EXISTS (SELECT 1 FROM `_dc_ntq_mask` m WHERE c.position_x > m.`xmin` AND c.position_x <= m.`xmax` AND c.position_y > m.`ymin` AND c.position_y <= m.`ymax`))) THEN `RequiredNpcOrGo1`+@OFF WHEN `RequiredNpcOrGo1`<0 AND -`RequiredNpcOrGo1` IN (SELECT DISTINCT g.id FROM cata_world.gameobject g WHERE (g.map=1 AND g.zoneId IN (16,148,331,493,618) AND EXISTS (SELECT 1 FROM `_dc_ntq_mask` m WHERE g.position_x > m.`xmin` AND g.position_x <= m.`xmax` AND g.position_y > m.`ymin` AND g.position_y <= m.`ymax`))) THEN `RequiredNpcOrGo1`-@OFF ELSE `RequiredNpcOrGo1` END,
  `RequiredNpcOrGo2` = CASE WHEN `RequiredNpcOrGo2`>0 AND `RequiredNpcOrGo2` IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId IN (16,148,331,493,618) AND EXISTS (SELECT 1 FROM `_dc_ntq_mask` m WHERE c.position_x > m.`xmin` AND c.position_x <= m.`xmax` AND c.position_y > m.`ymin` AND c.position_y <= m.`ymax`))) THEN `RequiredNpcOrGo2`+@OFF WHEN `RequiredNpcOrGo2`<0 AND -`RequiredNpcOrGo2` IN (SELECT DISTINCT g.id FROM cata_world.gameobject g WHERE (g.map=1 AND g.zoneId IN (16,148,331,493,618) AND EXISTS (SELECT 1 FROM `_dc_ntq_mask` m WHERE g.position_x > m.`xmin` AND g.position_x <= m.`xmax` AND g.position_y > m.`ymin` AND g.position_y <= m.`ymax`))) THEN `RequiredNpcOrGo2`-@OFF ELSE `RequiredNpcOrGo2` END,
  `RequiredNpcOrGo3` = CASE WHEN `RequiredNpcOrGo3`>0 AND `RequiredNpcOrGo3` IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId IN (16,148,331,493,618) AND EXISTS (SELECT 1 FROM `_dc_ntq_mask` m WHERE c.position_x > m.`xmin` AND c.position_x <= m.`xmax` AND c.position_y > m.`ymin` AND c.position_y <= m.`ymax`))) THEN `RequiredNpcOrGo3`+@OFF WHEN `RequiredNpcOrGo3`<0 AND -`RequiredNpcOrGo3` IN (SELECT DISTINCT g.id FROM cata_world.gameobject g WHERE (g.map=1 AND g.zoneId IN (16,148,331,493,618) AND EXISTS (SELECT 1 FROM `_dc_ntq_mask` m WHERE g.position_x > m.`xmin` AND g.position_x <= m.`xmax` AND g.position_y > m.`ymin` AND g.position_y <= m.`ymax`))) THEN `RequiredNpcOrGo3`-@OFF ELSE `RequiredNpcOrGo3` END,
  `RequiredNpcOrGo4` = CASE WHEN `RequiredNpcOrGo4`>0 AND `RequiredNpcOrGo4` IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId IN (16,148,331,493,618) AND EXISTS (SELECT 1 FROM `_dc_ntq_mask` m WHERE c.position_x > m.`xmin` AND c.position_x <= m.`xmax` AND c.position_y > m.`ymin` AND c.position_y <= m.`ymax`))) THEN `RequiredNpcOrGo4`+@OFF WHEN `RequiredNpcOrGo4`<0 AND -`RequiredNpcOrGo4` IN (SELECT DISTINCT g.id FROM cata_world.gameobject g WHERE (g.map=1 AND g.zoneId IN (16,148,331,493,618) AND EXISTS (SELECT 1 FROM `_dc_ntq_mask` m WHERE g.position_x > m.`xmin` AND g.position_x <= m.`xmax` AND g.position_y > m.`ymin` AND g.position_y <= m.`ymax`))) THEN `RequiredNpcOrGo4`-@OFF ELSE `RequiredNpcOrGo4` END
WHERE ID IN (SELECT q FROM _dc_qnew);
-- Mail-template guard (172_'s lesson) -- an imported quest must not claim a
-- mail template another quest already owns.  Runs HERE, while _dc_q is still
-- alive: 177_ first had this at the tail, after the drops, and failed 1146.
UPDATE acore_world.quest_template_addon a
JOIN _dc_q q ON q.q = a.ID
JOIN acore_world.quest_template_addon other
     ON other.`RewardMailTemplateID` = a.`RewardMailTemplateID` AND other.ID <> a.ID
SET a.`RewardMailTemplateID` = 0, a.`RewardMailDelay` = 0
WHERE a.`RewardMailTemplateID` <> 0;

DROP TEMPORARY TABLE IF EXISTS _dc_q; DROP TEMPORARY TABLE IF EXISTS _dc_q2; DROP TEMPORARY TABLE IF EXISTS _dc_qnew;
-- quest relations -> remap creature id +@OFF (quest id unchanged)
INSERT IGNORE INTO acore_world.creature_queststarter (`id`, `quest`) SELECT `id`+@OFF, `quest` FROM cata_world.creature_queststarter WHERE id IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId IN (16,148,331,493,618) AND EXISTS (SELECT 1 FROM `_dc_ntq_mask` m WHERE c.position_x > m.`xmin` AND c.position_x <= m.`xmax` AND c.position_y > m.`ymin` AND c.position_y <= m.`ymax`))) AND id NOT IN (SELECT entry FROM acore_world.creature_template WHERE entry < @OFF);
INSERT IGNORE INTO acore_world.creature_queststarter (`id`, `quest`) SELECT `id`+@OFF, `quest` FROM acore_world.creature_queststarter WHERE id IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId IN (16,148,331,493,618) AND EXISTS (SELECT 1 FROM `_dc_ntq_mask` m WHERE c.position_x > m.`xmin` AND c.position_x <= m.`xmax` AND c.position_y > m.`ymin` AND c.position_y <= m.`ymax`))) AND id IN (SELECT entry FROM acore_world.creature_template WHERE entry < @OFF) AND id < @OFF;
INSERT IGNORE INTO acore_world.creature_questender   (`id`, `quest`) SELECT `id`+@OFF, `quest` FROM cata_world.creature_questender   WHERE id IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId IN (16,148,331,493,618) AND EXISTS (SELECT 1 FROM `_dc_ntq_mask` m WHERE c.position_x > m.`xmin` AND c.position_x <= m.`xmax` AND c.position_y > m.`ymin` AND c.position_y <= m.`ymax`))) AND id NOT IN (SELECT entry FROM acore_world.creature_template WHERE entry < @OFF);
INSERT IGNORE INTO acore_world.creature_questender   (`id`, `quest`) SELECT `id`+@OFF, `quest` FROM acore_world.creature_questender   WHERE id IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId IN (16,148,331,493,618) AND EXISTS (SELECT 1 FROM `_dc_ntq_mask` m WHERE c.position_x > m.`xmin` AND c.position_x <= m.`xmax` AND c.position_y > m.`ymin` AND c.position_y <= m.`ymax`))) AND id IN (SELECT entry FROM acore_world.creature_template WHERE entry < @OFF) AND id < @OFF;

-- --- id-collision guard ------------------------------------------------------
-- Quest ids are cloned RAW, so a Cata quest can land on an id acore_world
-- already uses.  INSERT IGNORE keeps OUR quest -- correct -- but the NPC link
-- above was still written, so the questgiver would offer whatever quest happens
-- to hold that id.
--
-- Measured on this seed: 23 of the 194 started quests collide, and 22 are the
-- SAME quest (identical LogTitle) -- those links are fine and must be kept.
-- Exactly one is a real mismatch: id 25 is "Stonetalon Standstill" here and
-- "Simmer Down Now" in Cata.  Rather than special-casing that id, drop any link
-- whose quest resolves to a DIFFERENT title than the source expected -- the
-- questgiver then offers nothing, which beats offering the wrong quest.
DELETE qs FROM acore_world.creature_queststarter qs
JOIN acore_world.quest_template a ON a.ID = qs.quest
JOIN cata_world.quest_template  k ON k.ID = qs.quest
WHERE a.`LogTitle` <> k.`LogTitle`
  AND qs.`id` IN (SELECT DISTINCT c.`id` + @OFF FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId IN (16,148,331,493,618) AND EXISTS (SELECT 1 FROM `_dc_ntq_mask` m WHERE c.position_x > m.`xmin` AND c.position_x <= m.`xmax` AND c.position_y > m.`ymin` AND c.position_y <= m.`ymax`)));

DELETE qe FROM acore_world.creature_questender qe
JOIN acore_world.quest_template a ON a.ID = qe.quest
JOIN cata_world.quest_template  k ON k.ID = qe.quest
WHERE a.`LogTitle` <> k.`LogTitle`
  AND qe.`id` IN (SELECT DISTINCT c.`id` + @OFF FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId IN (16,148,331,493,618) AND EXISTS (SELECT 1 FROM `_dc_ntq_mask` m WHERE c.position_x > m.`xmin` AND c.position_x <= m.`xmax` AND c.position_y > m.`ymin` AND c.position_y <= m.`ymax`)));

DROP TABLE IF EXISTS `_dc_ntq_mask`;

-- Verify -- quests now offered on the new terrain:
--   SELECT COUNT(DISTINCT qs.quest) FROM `creature_queststarter` qs
--     JOIN `creature` c ON c.id = qs.id WHERE c.map = 750
--      AND c.zoneId IN (4926, 4928, 4929, 4930, 4931);
