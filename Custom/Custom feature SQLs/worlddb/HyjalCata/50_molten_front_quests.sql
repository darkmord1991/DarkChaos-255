-- =====================================================================
-- Molten Front -- 50  Quest chain import
-- ---------------------------------------------------------------------
-- The 11_quests.sql closure was seeded from map-1/zone-616 questgivers, so
-- the Molten Front quests (given by map-861 NPCs in cata) were never
-- captured. Seeds the 6 quests the ported C++ drives + prereq/next chain
-- closure, then clones them with 11's exact column set and remaps
-- objectives/relations onto the +3,600,000 clones (guarded by clone
-- existence -- APPLY AFTER the extended 29_neltharion_templates.sql).
-- Source: cata_world (TDB 434). Cross-DB, run on the world-DB host.
-- Idempotent.
--   29143 Wisp Away          29205 The Forlorn Spire   29206 Into the Fire
--   29210 Enduring the Heat  29272 Get Me Out of Here! 29290 Fire in the Skies
-- NOTE: Cata currency rewards (Marks of the World Tree) are not cloned
-- (11's column set has no currency columns); adjust rewards separately if
-- the Molten Front daily hub goes live.
-- =====================================================================
SET @OFF := 3600000;

DROP TEMPORARY TABLE IF EXISTS _dc_q;  CREATE TEMPORARY TABLE _dc_q  (q INT UNSIGNED PRIMARY KEY) ENGINE=MEMORY;
DROP TEMPORARY TABLE IF EXISTS _dc_q2; CREATE TEMPORARY TABLE _dc_q2 (q INT UNSIGNED PRIMARY KEY) ENGINE=MEMORY;
INSERT IGNORE INTO _dc_q (q) VALUES (29143),(29205),(29206),(29210),(29272),(29290);

-- prereq/next/breadcrumb closure (3 passes; helper table because MySQL
-- forbids referencing a TEMP table twice in one statement)
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

-- capture the quests that are actually NEW before insert (objective remap scope)
DROP TEMPORARY TABLE IF EXISTS _dc_qnew; CREATE TEMPORARY TABLE _dc_qnew (q INT UNSIGNED PRIMARY KEY) ENGINE=MEMORY;
INSERT IGNORE INTO _dc_qnew SELECT q FROM _dc_q WHERE q NOT IN (SELECT ID FROM acore_world.quest_template);

INSERT IGNORE INTO acore_world.quest_template (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RequiredFactionId1`, `RequiredFactionId2`, `RequiredFactionValue1`, `RequiredFactionValue2`, `RewardNextQuest`, `RewardXPDifficulty`, `RewardMoney`, `RewardDisplaySpell`, `RewardSpell`, `RewardHonor`, `RewardKillHonor`, `StartItem`, `Flags`, `RequiredPlayerKills`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `RewardItem4`, `RewardAmount4`, `ItemDrop1`, `ItemDropQuantity1`, `ItemDrop2`, `ItemDropQuantity2`, `ItemDrop3`, `ItemDropQuantity3`, `ItemDrop4`, `ItemDropQuantity4`, `RewardChoiceItemID1`, `RewardChoiceItemQuantity1`, `RewardChoiceItemID2`, `RewardChoiceItemQuantity2`, `RewardChoiceItemID3`, `RewardChoiceItemQuantity3`, `RewardChoiceItemID4`, `RewardChoiceItemQuantity4`, `RewardChoiceItemID5`, `RewardChoiceItemQuantity5`, `RewardChoiceItemID6`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`, `POIy`, `POIPriority`, `RewardTitle`, `RewardTalents`, `RewardArenaPoints`, `RewardFactionID1`, `RewardFactionValue1`, `RewardFactionOverride1`, `RewardFactionID2`, `RewardFactionValue2`, `RewardFactionOverride2`, `RewardFactionID3`, `RewardFactionValue3`, `RewardFactionOverride3`, `RewardFactionID4`, `RewardFactionValue4`, `RewardFactionOverride4`, `RewardFactionID5`, `RewardFactionValue5`, `RewardFactionOverride5`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`, `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`, `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`, `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`, `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `ObjectiveText1`, `ObjectiveText2`, `ObjectiveText3`, `ObjectiveText4`, `VerifiedBuild`)
SELECT `ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RequiredFactionId1`, `RequiredFactionId2`, `RequiredFactionValue1`, `RequiredFactionValue2`, `RewardNextQuest`, `RewardXPDifficulty`, `RewardMoney`, `RewardDisplaySpell`, `RewardSpell`, `RewardHonor`, `RewardKillHonor`, `StartItem`, `Flags`, `RequiredPlayerKills`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `RewardItem4`, `RewardAmount4`, `ItemDrop1`, `ItemDropQuantity1`, `ItemDrop2`, `ItemDropQuantity2`, `ItemDrop3`, `ItemDropQuantity3`, `ItemDrop4`, `ItemDropQuantity4`, `RewardChoiceItemID1`, `RewardChoiceItemQuantity1`, `RewardChoiceItemID2`, `RewardChoiceItemQuantity2`, `RewardChoiceItemID3`, `RewardChoiceItemQuantity3`, `RewardChoiceItemID4`, `RewardChoiceItemQuantity4`, `RewardChoiceItemID5`, `RewardChoiceItemQuantity5`, `RewardChoiceItemID6`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`, `POIy`, `POIPriority`, `RewardTitle`, `RewardTalents`, `RewardArenaPoints`, `RewardFactionID1`, `RewardFactionValue1`, `RewardFactionOverride1`, `RewardFactionID2`, `RewardFactionValue2`, `RewardFactionOverride2`, `RewardFactionID3`, `RewardFactionValue3`, `RewardFactionOverride3`, `RewardFactionID4`, `RewardFactionValue4`, `RewardFactionOverride4`, `RewardFactionID5`, `RewardFactionValue5`, `RewardFactionOverride5`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`, `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`, `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`, `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`, `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `ObjectiveText1`, `ObjectiveText2`, `ObjectiveText3`, `ObjectiveText4`, `VerifiedBuild` FROM cata_world.quest_template WHERE ID IN (SELECT q FROM _dc_q) AND ID NOT IN (SELECT ID FROM acore_world.quest_template);

INSERT IGNORE INTO acore_world.quest_template_addon (`ID`, `MaxLevel`, `AllowableClasses`, `SourceSpellID`, `PrevQuestID`, `NextQuestID`, `ExclusiveGroup`, `BreadcrumbForQuestId`, `RewardMailTemplateID`, `RewardMailDelay`, `RequiredSkillID`, `RequiredSkillPoints`, `RequiredMinRepFaction`, `RequiredMaxRepFaction`, `RequiredMinRepValue`, `RequiredMaxRepValue`, `ProvidedItemCount`, `SpecialFlags`)
SELECT `ID`, `MaxLevel`, `AllowableClasses`, `SourceSpellID`, `PrevQuestID`, `NextQuestID`, `ExclusiveGroup`, `BreadcrumbForQuestId`, `RewardMailTemplateID`, `RewardMailDelay`, `RequiredSkillID`, `RequiredSkillPoints`, `RequiredMinRepFaction`, `RequiredMaxRepFaction`, `RequiredMinRepValue`, `RequiredMaxRepValue`, `ProvidedItemCount`, `SpecialFlags` FROM cata_world.quest_template_addon WHERE ID IN (SELECT q FROM _dc_q) AND ID NOT IN (SELECT ID FROM acore_world.quest_template_addon);

-- remap kill/use objectives to the +@OFF clones -- ONLY where the clone
-- actually exists in acore (creature positive / GO negative ids)
UPDATE acore_world.quest_template SET
  `RequiredNpcOrGo1` = CASE WHEN `RequiredNpcOrGo1`>0 AND (`RequiredNpcOrGo1`+@OFF) IN (SELECT entry FROM acore_world.creature_template) THEN `RequiredNpcOrGo1`+@OFF WHEN `RequiredNpcOrGo1`<0 AND (-`RequiredNpcOrGo1`+@OFF) IN (SELECT entry FROM acore_world.gameobject_template) THEN `RequiredNpcOrGo1`-@OFF ELSE `RequiredNpcOrGo1` END,
  `RequiredNpcOrGo2` = CASE WHEN `RequiredNpcOrGo2`>0 AND (`RequiredNpcOrGo2`+@OFF) IN (SELECT entry FROM acore_world.creature_template) THEN `RequiredNpcOrGo2`+@OFF WHEN `RequiredNpcOrGo2`<0 AND (-`RequiredNpcOrGo2`+@OFF) IN (SELECT entry FROM acore_world.gameobject_template) THEN `RequiredNpcOrGo2`-@OFF ELSE `RequiredNpcOrGo2` END,
  `RequiredNpcOrGo3` = CASE WHEN `RequiredNpcOrGo3`>0 AND (`RequiredNpcOrGo3`+@OFF) IN (SELECT entry FROM acore_world.creature_template) THEN `RequiredNpcOrGo3`+@OFF WHEN `RequiredNpcOrGo3`<0 AND (-`RequiredNpcOrGo3`+@OFF) IN (SELECT entry FROM acore_world.gameobject_template) THEN `RequiredNpcOrGo3`-@OFF ELSE `RequiredNpcOrGo3` END,
  `RequiredNpcOrGo4` = CASE WHEN `RequiredNpcOrGo4`>0 AND (`RequiredNpcOrGo4`+@OFF) IN (SELECT entry FROM acore_world.creature_template) THEN `RequiredNpcOrGo4`+@OFF WHEN `RequiredNpcOrGo4`<0 AND (-`RequiredNpcOrGo4`+@OFF) IN (SELECT entry FROM acore_world.gameobject_template) THEN `RequiredNpcOrGo4`-@OFF ELSE `RequiredNpcOrGo4` END
WHERE ID IN (SELECT q FROM _dc_qnew);

-- questgiver relations -> creature id +@OFF (quest id unchanged); only for
-- quests we just imported, only where the clone template exists
INSERT IGNORE INTO acore_world.creature_queststarter (`id`, `quest`)
SELECT s.id+@OFF, s.quest FROM cata_world.creature_queststarter s
WHERE s.quest IN (SELECT q FROM _dc_qnew) AND (s.id+@OFF) IN (SELECT entry FROM acore_world.creature_template);
INSERT IGNORE INTO acore_world.creature_questender (`id`, `quest`)
SELECT e.id+@OFF, e.quest FROM cata_world.creature_questender e
WHERE e.quest IN (SELECT q FROM _dc_qnew) AND (e.id+@OFF) IN (SELECT entry FROM acore_world.creature_template);

DROP TEMPORARY TABLE IF EXISTS _dc_q; DROP TEMPORARY TABLE IF EXISTS _dc_q2; DROP TEMPORARY TABLE IF EXISTS _dc_qnew;
