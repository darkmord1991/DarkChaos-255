-- =====================================================================
-- Molten Front (map 750) -- 03  Quests + questgiver relations
-- ---------------------------------------------------------------------
-- Clones every quest handed out / turned in by a curated Molten Front NPC
-- (02's spawn set), sourced from cata_world (modern AC quest_template schema,
-- same as HyjalCata/50). Seed = all quests linked to the curated MF creatures
-- via cata relations, + prereq/next/breadcrumb closure. Then:
--   * clone quest_template + quest_template_addon (INSERT IGNORE)
--   * remap kill/use objectives to the +3,600,000 clones (guarded)
--   * NORMALIZE QuestSortID to 616 (the Cata "Mount Hyjal" zone the rest of
--     map 750's 169 quests already use) so MF quests group with the zone
--   * clone creature/GO queststarter + questender onto the +@OFF clones
-- Extends HyjalCata/50 (which only seeded the 6 core chain quests); INSERT
-- IGNORE means the ~11 already-present MF quests are not duplicated, but they
-- DO get their MF giver relations + QuestSortID normalized here.
-- Idempotent. Run AFTER 01/02 and ../HyjalCata/apply_all.sql.
-- =====================================================================
SET @OFF := 3600000;

DROP TEMPORARY TABLE IF EXISTS _mfq;  CREATE TEMPORARY TABLE _mfq  (q INT UNSIGNED PRIMARY KEY) ENGINE=MEMORY;
DROP TEMPORARY TABLE IF EXISTS _mfq2; CREATE TEMPORARY TABLE _mfq2 (q INT UNSIGNED PRIMARY KEY) ENGINE=MEMORY;

-- seed: quests started or ended by a curated MF creature (cata base id = nelt id)
INSERT IGNORE INTO _mfq (q)
SELECT s.quest FROM cata_world.creature_queststarter s
WHERE s.id IN (SELECT DISTINCT id FROM nelt_world.creature WHERE map=861 AND phaseMask IN (2047,8,16,128))
  AND s.quest IN (SELECT ID FROM cata_world.quest_template);
INSERT IGNORE INTO _mfq (q)
SELECT e.quest FROM cata_world.creature_questender e
WHERE e.id IN (SELECT DISTINCT id FROM nelt_world.creature WHERE map=861 AND phaseMask IN (2047,8,16,128))
  AND e.quest IN (SELECT ID FROM cata_world.quest_template);

-- prereq/next/breadcrumb closure (3 passes; helper table -- MySQL forbids
-- referencing a TEMP table twice in one statement)
INSERT IGNORE INTO _mfq2 (q) SELECT d.ref FROM (SELECT x.ref FROM (
  SELECT ID qid, PrevQuestID ref FROM cata_world.quest_template_addon WHERE PrevQuestID<>0
  UNION ALL SELECT ID, NextQuestID FROM cata_world.quest_template_addon WHERE NextQuestID<>0
  UNION ALL SELECT ID, BreadcrumbForQuestId FROM cata_world.quest_template_addon WHERE BreadcrumbForQuestId<>0
  UNION ALL SELECT ID, RewardNextQuest FROM cata_world.quest_template WHERE RewardNextQuest<>0) x
  JOIN _mfq c ON c.q=x.qid WHERE x.ref IN (SELECT ID FROM cata_world.quest_template)) d;
INSERT IGNORE INTO _mfq (q) SELECT q FROM _mfq2; DELETE FROM _mfq2;
INSERT IGNORE INTO _mfq2 (q) SELECT d.ref FROM (SELECT x.ref FROM (
  SELECT ID qid, PrevQuestID ref FROM cata_world.quest_template_addon WHERE PrevQuestID<>0
  UNION ALL SELECT ID, NextQuestID FROM cata_world.quest_template_addon WHERE NextQuestID<>0
  UNION ALL SELECT ID, BreadcrumbForQuestId FROM cata_world.quest_template_addon WHERE BreadcrumbForQuestId<>0
  UNION ALL SELECT ID, RewardNextQuest FROM cata_world.quest_template WHERE RewardNextQuest<>0) x
  JOIN _mfq c ON c.q=x.qid WHERE x.ref IN (SELECT ID FROM cata_world.quest_template)) d;
INSERT IGNORE INTO _mfq (q) SELECT q FROM _mfq2; DELETE FROM _mfq2;
INSERT IGNORE INTO _mfq2 (q) SELECT d.ref FROM (SELECT x.ref FROM (
  SELECT ID qid, PrevQuestID ref FROM cata_world.quest_template_addon WHERE PrevQuestID<>0
  UNION ALL SELECT ID, NextQuestID FROM cata_world.quest_template_addon WHERE NextQuestID<>0
  UNION ALL SELECT ID, BreadcrumbForQuestId FROM cata_world.quest_template_addon WHERE BreadcrumbForQuestId<>0
  UNION ALL SELECT ID, RewardNextQuest FROM cata_world.quest_template WHERE RewardNextQuest<>0) x
  JOIN _mfq c ON c.q=x.qid WHERE x.ref IN (SELECT ID FROM cata_world.quest_template)) d;
INSERT IGNORE INTO _mfq (q) SELECT q FROM _mfq2;

-- capture the genuinely-new quests before insert (objective-remap scope)
DROP TEMPORARY TABLE IF EXISTS _mfqnew; CREATE TEMPORARY TABLE _mfqnew (q INT UNSIGNED PRIMARY KEY) ENGINE=MEMORY;
INSERT IGNORE INTO _mfqnew SELECT q FROM _mfq WHERE q NOT IN (SELECT ID FROM acore_world.quest_template);

INSERT IGNORE INTO acore_world.quest_template (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RequiredFactionId1`, `RequiredFactionId2`, `RequiredFactionValue1`, `RequiredFactionValue2`, `RewardNextQuest`, `RewardXPDifficulty`, `RewardMoney`, `RewardDisplaySpell`, `RewardSpell`, `RewardHonor`, `RewardKillHonor`, `StartItem`, `Flags`, `RequiredPlayerKills`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `RewardItem4`, `RewardAmount4`, `ItemDrop1`, `ItemDropQuantity1`, `ItemDrop2`, `ItemDropQuantity2`, `ItemDrop3`, `ItemDropQuantity3`, `ItemDrop4`, `ItemDropQuantity4`, `RewardChoiceItemID1`, `RewardChoiceItemQuantity1`, `RewardChoiceItemID2`, `RewardChoiceItemQuantity2`, `RewardChoiceItemID3`, `RewardChoiceItemQuantity3`, `RewardChoiceItemID4`, `RewardChoiceItemQuantity4`, `RewardChoiceItemID5`, `RewardChoiceItemQuantity5`, `RewardChoiceItemID6`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`, `POIy`, `POIPriority`, `RewardTitle`, `RewardTalents`, `RewardArenaPoints`, `RewardFactionID1`, `RewardFactionValue1`, `RewardFactionOverride1`, `RewardFactionID2`, `RewardFactionValue2`, `RewardFactionOverride2`, `RewardFactionID3`, `RewardFactionValue3`, `RewardFactionOverride3`, `RewardFactionID4`, `RewardFactionValue4`, `RewardFactionOverride4`, `RewardFactionID5`, `RewardFactionValue5`, `RewardFactionOverride5`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`, `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`, `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`, `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`, `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `ObjectiveText1`, `ObjectiveText2`, `ObjectiveText3`, `ObjectiveText4`, `VerifiedBuild`)
SELECT `ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RequiredFactionId1`, `RequiredFactionId2`, `RequiredFactionValue1`, `RequiredFactionValue2`, `RewardNextQuest`, `RewardXPDifficulty`, `RewardMoney`, `RewardDisplaySpell`, `RewardSpell`, `RewardHonor`, `RewardKillHonor`, `StartItem`, `Flags`, `RequiredPlayerKills`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `RewardItem4`, `RewardAmount4`, `ItemDrop1`, `ItemDropQuantity1`, `ItemDrop2`, `ItemDropQuantity2`, `ItemDrop3`, `ItemDropQuantity3`, `ItemDrop4`, `ItemDropQuantity4`, `RewardChoiceItemID1`, `RewardChoiceItemQuantity1`, `RewardChoiceItemID2`, `RewardChoiceItemQuantity2`, `RewardChoiceItemID3`, `RewardChoiceItemQuantity3`, `RewardChoiceItemID4`, `RewardChoiceItemQuantity4`, `RewardChoiceItemID5`, `RewardChoiceItemQuantity5`, `RewardChoiceItemID6`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`, `POIy`, `POIPriority`, `RewardTitle`, `RewardTalents`, `RewardArenaPoints`, `RewardFactionID1`, `RewardFactionValue1`, `RewardFactionOverride1`, `RewardFactionID2`, `RewardFactionValue2`, `RewardFactionOverride2`, `RewardFactionID3`, `RewardFactionValue3`, `RewardFactionOverride3`, `RewardFactionID4`, `RewardFactionValue4`, `RewardFactionOverride4`, `RewardFactionID5`, `RewardFactionValue5`, `RewardFactionOverride5`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`, `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`, `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`, `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`, `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `ObjectiveText1`, `ObjectiveText2`, `ObjectiveText3`, `ObjectiveText4`, `VerifiedBuild`
FROM cata_world.quest_template WHERE ID IN (SELECT q FROM _mfq) AND ID NOT IN (SELECT ID FROM acore_world.quest_template);

INSERT IGNORE INTO acore_world.quest_template_addon (`ID`, `MaxLevel`, `AllowableClasses`, `SourceSpellID`, `PrevQuestID`, `NextQuestID`, `ExclusiveGroup`, `BreadcrumbForQuestId`, `RewardMailTemplateID`, `RewardMailDelay`, `RequiredSkillID`, `RequiredSkillPoints`, `RequiredMinRepFaction`, `RequiredMaxRepFaction`, `RequiredMinRepValue`, `RequiredMaxRepValue`, `ProvidedItemCount`, `SpecialFlags`)
SELECT `ID`, `MaxLevel`, `AllowableClasses`, `SourceSpellID`, `PrevQuestID`, `NextQuestID`, `ExclusiveGroup`, `BreadcrumbForQuestId`, `RewardMailTemplateID`, `RewardMailDelay`, `RequiredSkillID`, `RequiredSkillPoints`, `RequiredMinRepFaction`, `RequiredMaxRepFaction`, `RequiredMinRepValue`, `RequiredMaxRepValue`, `ProvidedItemCount`, `SpecialFlags`
FROM cata_world.quest_template_addon WHERE ID IN (SELECT q FROM _mfq) AND ID NOT IN (SELECT ID FROM acore_world.quest_template_addon);

-- remap kill/use objectives to the +@OFF clones (only newly-imported quests, only where the clone exists)
UPDATE acore_world.quest_template SET
  `RequiredNpcOrGo1` = CASE WHEN `RequiredNpcOrGo1`>0 AND (`RequiredNpcOrGo1`+@OFF) IN (SELECT entry FROM acore_world.creature_template) THEN `RequiredNpcOrGo1`+@OFF WHEN `RequiredNpcOrGo1`<0 AND (-`RequiredNpcOrGo1`+@OFF) IN (SELECT entry FROM acore_world.gameobject_template) THEN `RequiredNpcOrGo1`-@OFF ELSE `RequiredNpcOrGo1` END,
  `RequiredNpcOrGo2` = CASE WHEN `RequiredNpcOrGo2`>0 AND (`RequiredNpcOrGo2`+@OFF) IN (SELECT entry FROM acore_world.creature_template) THEN `RequiredNpcOrGo2`+@OFF WHEN `RequiredNpcOrGo2`<0 AND (-`RequiredNpcOrGo2`+@OFF) IN (SELECT entry FROM acore_world.gameobject_template) THEN `RequiredNpcOrGo2`-@OFF ELSE `RequiredNpcOrGo2` END,
  `RequiredNpcOrGo3` = CASE WHEN `RequiredNpcOrGo3`>0 AND (`RequiredNpcOrGo3`+@OFF) IN (SELECT entry FROM acore_world.creature_template) THEN `RequiredNpcOrGo3`+@OFF WHEN `RequiredNpcOrGo3`<0 AND (-`RequiredNpcOrGo3`+@OFF) IN (SELECT entry FROM acore_world.gameobject_template) THEN `RequiredNpcOrGo3`-@OFF ELSE `RequiredNpcOrGo3` END,
  `RequiredNpcOrGo4` = CASE WHEN `RequiredNpcOrGo4`>0 AND (`RequiredNpcOrGo4`+@OFF) IN (SELECT entry FROM acore_world.creature_template) THEN `RequiredNpcOrGo4`+@OFF WHEN `RequiredNpcOrGo4`<0 AND (-`RequiredNpcOrGo4`+@OFF) IN (SELECT entry FROM acore_world.gameobject_template) THEN `RequiredNpcOrGo4`-@OFF ELSE `RequiredNpcOrGo4` END
WHERE ID IN (SELECT q FROM _mfqnew);

-- group MF quests with the rest of map 750 (its 169 quests use Cata zone 616)
UPDATE acore_world.quest_template SET `QuestSortID`=616 WHERE ID IN (SELECT q FROM _mfq);

-- questgiver relations onto the +@OFF clones (quest id unchanged), for ALL MF
-- quests (incl. the already-present ones whose givers weren't spawned before);
-- guarded by clone existence, INSERT IGNORE dedupes.
INSERT IGNORE INTO acore_world.creature_queststarter (`id`, `quest`)
SELECT s.id+@OFF, s.quest FROM cata_world.creature_queststarter s
WHERE s.quest IN (SELECT q FROM _mfq) AND (s.id+@OFF) IN (SELECT entry FROM acore_world.creature_template);
INSERT IGNORE INTO acore_world.creature_questender (`id`, `quest`)
SELECT e.id+@OFF, e.quest FROM cata_world.creature_questender e
WHERE e.quest IN (SELECT q FROM _mfq) AND (e.id+@OFF) IN (SELECT entry FROM acore_world.creature_template);
INSERT IGNORE INTO acore_world.gameobject_queststarter (`id`, `quest`)
SELECT s.id+@OFF, s.quest FROM cata_world.gameobject_queststarter s
WHERE s.quest IN (SELECT q FROM _mfq) AND (s.id+@OFF) IN (SELECT entry FROM acore_world.gameobject_template);
INSERT IGNORE INTO acore_world.gameobject_questender (`id`, `quest`)
SELECT e.id+@OFF, e.quest FROM cata_world.gameobject_questender e
WHERE e.quest IN (SELECT q FROM _mfq) AND (e.id+@OFF) IN (SELECT entry FROM acore_world.gameobject_template);

DROP TEMPORARY TABLE IF EXISTS _mfq; DROP TEMPORARY TABLE IF EXISTS _mfq2; DROP TEMPORARY TABLE IF EXISTS _mfqnew;
