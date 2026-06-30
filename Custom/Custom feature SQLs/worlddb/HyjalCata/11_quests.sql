-- Mount Hyjal (DCMountHyjal, map 750)
-- dc_entry = 3,600,000 + original (isolated, tunable). Source cata_world(TDB434)->acore_world. Cross-DB INSERT...SELECT.
SET @OFF := 3600000;

-- 4.3.4 quests are monolithic -> plain clone. Temp table expands the prereq/next/breadcrumb chain closure.
DROP TEMPORARY TABLE IF EXISTS _dc_q;  CREATE TEMPORARY TABLE _dc_q  (q INT UNSIGNED PRIMARY KEY) ENGINE=MEMORY;
DROP TEMPORARY TABLE IF EXISTS _dc_q2; CREATE TEMPORARY TABLE _dc_q2 (q INT UNSIGNED PRIMARY KEY) ENGINE=MEMORY;
INSERT IGNORE INTO _dc_q (q) SELECT quest FROM cata_world.creature_queststarter WHERE id IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId=616))
  UNION SELECT quest FROM cata_world.creature_questender WHERE id IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId=616));
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
  `RequiredNpcOrGo1` = CASE WHEN `RequiredNpcOrGo1`>0 AND `RequiredNpcOrGo1` IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId=616)) THEN `RequiredNpcOrGo1`+@OFF WHEN `RequiredNpcOrGo1`<0 AND -`RequiredNpcOrGo1` IN (SELECT DISTINCT g.id FROM cata_world.gameobject g WHERE (g.map=1 AND g.zoneId=616)) THEN `RequiredNpcOrGo1`-@OFF ELSE `RequiredNpcOrGo1` END,
  `RequiredNpcOrGo2` = CASE WHEN `RequiredNpcOrGo2`>0 AND `RequiredNpcOrGo2` IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId=616)) THEN `RequiredNpcOrGo2`+@OFF WHEN `RequiredNpcOrGo2`<0 AND -`RequiredNpcOrGo2` IN (SELECT DISTINCT g.id FROM cata_world.gameobject g WHERE (g.map=1 AND g.zoneId=616)) THEN `RequiredNpcOrGo2`-@OFF ELSE `RequiredNpcOrGo2` END,
  `RequiredNpcOrGo3` = CASE WHEN `RequiredNpcOrGo3`>0 AND `RequiredNpcOrGo3` IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId=616)) THEN `RequiredNpcOrGo3`+@OFF WHEN `RequiredNpcOrGo3`<0 AND -`RequiredNpcOrGo3` IN (SELECT DISTINCT g.id FROM cata_world.gameobject g WHERE (g.map=1 AND g.zoneId=616)) THEN `RequiredNpcOrGo3`-@OFF ELSE `RequiredNpcOrGo3` END,
  `RequiredNpcOrGo4` = CASE WHEN `RequiredNpcOrGo4`>0 AND `RequiredNpcOrGo4` IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId=616)) THEN `RequiredNpcOrGo4`+@OFF WHEN `RequiredNpcOrGo4`<0 AND -`RequiredNpcOrGo4` IN (SELECT DISTINCT g.id FROM cata_world.gameobject g WHERE (g.map=1 AND g.zoneId=616)) THEN `RequiredNpcOrGo4`-@OFF ELSE `RequiredNpcOrGo4` END
WHERE ID IN (SELECT q FROM _dc_qnew);
DROP TEMPORARY TABLE IF EXISTS _dc_q; DROP TEMPORARY TABLE IF EXISTS _dc_q2; DROP TEMPORARY TABLE IF EXISTS _dc_qnew;
-- quest relations -> remap creature id +@OFF (quest id unchanged)
INSERT IGNORE INTO acore_world.creature_queststarter (`id`, `quest`) SELECT `id`+@OFF, `quest` FROM cata_world.creature_queststarter WHERE id IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId=616)) AND id NOT IN (SELECT entry FROM acore_world.creature_template WHERE entry < @OFF);
INSERT IGNORE INTO acore_world.creature_queststarter (`id`, `quest`) SELECT `id`+@OFF, `quest` FROM acore_world.creature_queststarter WHERE id IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId=616)) AND id IN (SELECT entry FROM acore_world.creature_template WHERE entry < @OFF) AND id < @OFF;
INSERT IGNORE INTO acore_world.creature_questender   (`id`, `quest`) SELECT `id`+@OFF, `quest` FROM cata_world.creature_questender   WHERE id IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId=616)) AND id NOT IN (SELECT entry FROM acore_world.creature_template WHERE entry < @OFF);
INSERT IGNORE INTO acore_world.creature_questender   (`id`, `quest`) SELECT `id`+@OFF, `quest` FROM acore_world.creature_questender   WHERE id IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId=616)) AND id IN (SELECT entry FROM acore_world.creature_template WHERE entry < @OFF) AND id < @OFF;
