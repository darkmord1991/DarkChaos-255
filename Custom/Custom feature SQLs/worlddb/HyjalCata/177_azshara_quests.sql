-- ---------------------------------------------------------------------------
-- 177  Hyjal round-43b -- Azshara phase 2: the Cata quest layer + Kroum retired
-- ---------------------------------------------------------------------------
-- Companion to 176_ (MUST run after it -- questgiver links reference the +3.6M
-- templates 176_ creates).  Adapted from 11_quests.sql with the id set swapped
-- from Hyjal (zoneId=616) to the box-limited Azshara corner (zoneId=16): seeds
-- from the corner's questgivers, walks Prev/Next/Breadcrumb/RewardNextQuest
-- chains, clones quest_template/_addon at RAW ids (the Cata-layer convention;
-- INSERT IGNORE leaves any same-id WotLK quest untouched), then links
-- queststarter/questender at +3,600,000.
--
-- KNOWN LIMITATION, inherent to a partial-zone port: chains that continue
-- beyond the map edge (into the 89% of Cata Azshara that is off-map) get their
-- referenced quest TEMPLATES but no giver/ender spawns -- those chains dead-end
-- at the edge, matching how the rest of the border zones behave.
--
-- KROUM RETIRED.  Cata removed the Valormok flight point (Bilgewater Harbor,
-- off-map, replaced it), and with 176_ the corner is fully Cata content, so
-- the stock flight master is an anachronism.  The taxi network side (node 338
-- removed from TaxiNodes/TaxiPath/TaxiPathNode, mesh regenerated as 11 nodes)
-- ships in the same round's DBC deploy -- BOTH must go live together, else the
-- client shows a flight point with nobody at it (DBC without spawn) or an NPC
-- with a dead map (spawn without DBC).
--
-- The mail-template guard (172_'s lesson) runs after the import: a cloned
-- quest that carries a RewardMailTemplateID already claimed by a DIFFERENT
-- existing quest loses its mail rather than stealing it -- first-registration
-- wins at the core, and stock must keep winning.
-- ---------------------------------------------------------------------------

SET @OFF := 3600000;

-- --- Kroum, retired with his zone ------------------------------------------
DELETE FROM `creature` WHERE `guid` = 15810001 AND `id` = 8610;

DROP TEMPORARY TABLE IF EXISTS _dc_q;  CREATE TEMPORARY TABLE _dc_q  (q INT UNSIGNED PRIMARY KEY) ENGINE=MEMORY;
DROP TEMPORARY TABLE IF EXISTS _dc_q2; CREATE TEMPORARY TABLE _dc_q2 (q INT UNSIGNED PRIMARY KEY) ENGINE=MEMORY;
INSERT IGNORE INTO _dc_q (q) SELECT quest FROM cata_world.creature_queststarter WHERE id IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId=16 AND c.position_x BETWEEN 3200 AND 5400 AND c.position_y BETWEEN -5334 AND -3200))
  UNION SELECT quest FROM cata_world.creature_questender WHERE id IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId=16 AND c.position_x BETWEEN 3200 AND 5400 AND c.position_y BETWEEN -5334 AND -3200));
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
DROP TEMPORARY TABLE IF EXISTS _dc_qnew; CREATE TEMPORARY TABLE _dc_qnew (q INT UNSIGNED PRIMARY KEY) ENGINE=MEMORY;
INSERT IGNORE INTO _dc_qnew SELECT q FROM _dc_q WHERE q NOT IN (SELECT ID FROM acore_world.quest_template);
INSERT IGNORE INTO acore_world.quest_template (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RequiredFactionId1`, `RequiredFactionId2`, `RequiredFactionValue1`, `RequiredFactionValue2`, `RewardNextQuest`, `RewardXPDifficulty`, `RewardMoney`, `RewardDisplaySpell`, `RewardSpell`, `RewardHonor`, `RewardKillHonor`, `StartItem`, `Flags`, `RequiredPlayerKills`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `RewardItem4`, `RewardAmount4`, `ItemDrop1`, `ItemDropQuantity1`, `ItemDrop2`, `ItemDropQuantity2`, `ItemDrop3`, `ItemDropQuantity3`, `ItemDrop4`, `ItemDropQuantity4`, `RewardChoiceItemID1`, `RewardChoiceItemQuantity1`, `RewardChoiceItemID2`, `RewardChoiceItemQuantity2`, `RewardChoiceItemID3`, `RewardChoiceItemQuantity3`, `RewardChoiceItemID4`, `RewardChoiceItemQuantity4`, `RewardChoiceItemID5`, `RewardChoiceItemQuantity5`, `RewardChoiceItemID6`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`, `POIy`, `POIPriority`, `RewardTitle`, `RewardTalents`, `RewardArenaPoints`, `RewardFactionID1`, `RewardFactionValue1`, `RewardFactionOverride1`, `RewardFactionID2`, `RewardFactionValue2`, `RewardFactionOverride2`, `RewardFactionID3`, `RewardFactionValue3`, `RewardFactionOverride3`, `RewardFactionID4`, `RewardFactionValue4`, `RewardFactionOverride4`, `RewardFactionID5`, `RewardFactionValue5`, `RewardFactionOverride5`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`, `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`, `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`, `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`, `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `ObjectiveText1`, `ObjectiveText2`, `ObjectiveText3`, `ObjectiveText4`, `VerifiedBuild`)
SELECT `ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RequiredFactionId1`, `RequiredFactionId2`, `RequiredFactionValue1`, `RequiredFactionValue2`, `RewardNextQuest`, `RewardXPDifficulty`, `RewardMoney`, `RewardDisplaySpell`, `RewardSpell`, `RewardHonor`, `RewardKillHonor`, `StartItem`, `Flags`, `RequiredPlayerKills`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `RewardItem4`, `RewardAmount4`, `ItemDrop1`, `ItemDropQuantity1`, `ItemDrop2`, `ItemDropQuantity2`, `ItemDrop3`, `ItemDropQuantity3`, `ItemDrop4`, `ItemDropQuantity4`, `RewardChoiceItemID1`, `RewardChoiceItemQuantity1`, `RewardChoiceItemID2`, `RewardChoiceItemQuantity2`, `RewardChoiceItemID3`, `RewardChoiceItemQuantity3`, `RewardChoiceItemID4`, `RewardChoiceItemQuantity4`, `RewardChoiceItemID5`, `RewardChoiceItemQuantity5`, `RewardChoiceItemID6`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`, `POIy`, `POIPriority`, `RewardTitle`, `RewardTalents`, `RewardArenaPoints`, `RewardFactionID1`, `RewardFactionValue1`, `RewardFactionOverride1`, `RewardFactionID2`, `RewardFactionValue2`, `RewardFactionOverride2`, `RewardFactionID3`, `RewardFactionValue3`, `RewardFactionOverride3`, `RewardFactionID4`, `RewardFactionValue4`, `RewardFactionOverride4`, `RewardFactionID5`, `RewardFactionValue5`, `RewardFactionOverride5`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`, `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`, `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`, `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`, `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `ObjectiveText1`, `ObjectiveText2`, `ObjectiveText3`, `ObjectiveText4`, `VerifiedBuild` FROM cata_world.quest_template WHERE ID IN (SELECT q FROM _dc_q) AND ID NOT IN (SELECT ID FROM acore_world.quest_template);
INSERT IGNORE INTO acore_world.quest_template_addon (`ID`, `MaxLevel`, `AllowableClasses`, `SourceSpellID`, `PrevQuestID`, `NextQuestID`, `ExclusiveGroup`, `BreadcrumbForQuestId`, `RewardMailTemplateID`, `RewardMailDelay`, `RequiredSkillID`, `RequiredSkillPoints`, `RequiredMinRepFaction`, `RequiredMaxRepFaction`, `RequiredMinRepValue`, `RequiredMaxRepValue`, `ProvidedItemCount`, `SpecialFlags`)
SELECT `ID`, `MaxLevel`, `AllowableClasses`, `SourceSpellID`, `PrevQuestID`, `NextQuestID`, `ExclusiveGroup`, `BreadcrumbForQuestId`, `RewardMailTemplateID`, `RewardMailDelay`, `RequiredSkillID`, `RequiredSkillPoints`, `RequiredMinRepFaction`, `RequiredMaxRepFaction`, `RequiredMinRepValue`, `RequiredMaxRepValue`, `ProvidedItemCount`, `SpecialFlags` FROM cata_world.quest_template_addon WHERE ID IN (SELECT q FROM _dc_q) AND ID NOT IN (SELECT ID FROM acore_world.quest_template_addon);
UPDATE acore_world.quest_template SET
  `RequiredNpcOrGo1` = CASE WHEN `RequiredNpcOrGo1`>0 AND `RequiredNpcOrGo1` IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId=16 AND c.position_x BETWEEN 3200 AND 5400 AND c.position_y BETWEEN -5334 AND -3200)) THEN `RequiredNpcOrGo1`+@OFF WHEN `RequiredNpcOrGo1`<0 AND -`RequiredNpcOrGo1` IN (SELECT DISTINCT g.id FROM cata_world.gameobject g WHERE (g.map=1 AND g.zoneId=16 AND g.position_x BETWEEN 3200 AND 5400 AND g.position_y BETWEEN -5334 AND -3200)) THEN `RequiredNpcOrGo1`-@OFF ELSE `RequiredNpcOrGo1` END,
  `RequiredNpcOrGo2` = CASE WHEN `RequiredNpcOrGo2`>0 AND `RequiredNpcOrGo2` IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId=16 AND c.position_x BETWEEN 3200 AND 5400 AND c.position_y BETWEEN -5334 AND -3200)) THEN `RequiredNpcOrGo2`+@OFF WHEN `RequiredNpcOrGo2`<0 AND -`RequiredNpcOrGo2` IN (SELECT DISTINCT g.id FROM cata_world.gameobject g WHERE (g.map=1 AND g.zoneId=16 AND g.position_x BETWEEN 3200 AND 5400 AND g.position_y BETWEEN -5334 AND -3200)) THEN `RequiredNpcOrGo2`-@OFF ELSE `RequiredNpcOrGo2` END,
  `RequiredNpcOrGo3` = CASE WHEN `RequiredNpcOrGo3`>0 AND `RequiredNpcOrGo3` IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId=16 AND c.position_x BETWEEN 3200 AND 5400 AND c.position_y BETWEEN -5334 AND -3200)) THEN `RequiredNpcOrGo3`+@OFF WHEN `RequiredNpcOrGo3`<0 AND -`RequiredNpcOrGo3` IN (SELECT DISTINCT g.id FROM cata_world.gameobject g WHERE (g.map=1 AND g.zoneId=16 AND g.position_x BETWEEN 3200 AND 5400 AND g.position_y BETWEEN -5334 AND -3200)) THEN `RequiredNpcOrGo3`-@OFF ELSE `RequiredNpcOrGo3` END,
  `RequiredNpcOrGo4` = CASE WHEN `RequiredNpcOrGo4`>0 AND `RequiredNpcOrGo4` IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId=16 AND c.position_x BETWEEN 3200 AND 5400 AND c.position_y BETWEEN -5334 AND -3200)) THEN `RequiredNpcOrGo4`+@OFF WHEN `RequiredNpcOrGo4`<0 AND -`RequiredNpcOrGo4` IN (SELECT DISTINCT g.id FROM cata_world.gameobject g WHERE (g.map=1 AND g.zoneId=16 AND g.position_x BETWEEN 3200 AND 5400 AND g.position_y BETWEEN -5334 AND -3200)) THEN `RequiredNpcOrGo4`-@OFF ELSE `RequiredNpcOrGo4` END
WHERE ID IN (SELECT q FROM _dc_qnew);
-- Mail-template guard (172_'s lesson) BEFORE the temp tables drop -- an
-- earlier revision ran it after and died with 1146 '_dc_q doesn't exist'.
-- Stock keeps its mail; an imported quest that shares a template loses it.
-- --- mail-template guard (see 172_): imported quests must not steal mail ----
UPDATE acore_world.quest_template_addon a
JOIN _dc_q q ON q.q = a.ID
JOIN acore_world.quest_template_addon other
     ON other.`RewardMailTemplateID` = a.`RewardMailTemplateID` AND other.ID <> a.ID
SET a.`RewardMailTemplateID` = 0, a.`RewardMailDelay` = 0
WHERE a.`RewardMailTemplateID` <> 0;

DROP TEMPORARY TABLE IF EXISTS _dc_q; DROP TEMPORARY TABLE IF EXISTS _dc_q2; DROP TEMPORARY TABLE IF EXISTS _dc_qnew;
INSERT IGNORE INTO acore_world.creature_queststarter (`id`, `quest`) SELECT `id`+@OFF, `quest` FROM cata_world.creature_queststarter WHERE id IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId=16 AND c.position_x BETWEEN 3200 AND 5400 AND c.position_y BETWEEN -5334 AND -3200)) AND id NOT IN (SELECT entry FROM acore_world.creature_template WHERE entry < @OFF);
INSERT IGNORE INTO acore_world.creature_queststarter (`id`, `quest`) SELECT `id`+@OFF, `quest` FROM acore_world.creature_queststarter WHERE id IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId=16 AND c.position_x BETWEEN 3200 AND 5400 AND c.position_y BETWEEN -5334 AND -3200)) AND id IN (SELECT entry FROM acore_world.creature_template WHERE entry < @OFF) AND id < @OFF;
INSERT IGNORE INTO acore_world.creature_questender   (`id`, `quest`) SELECT `id`+@OFF, `quest` FROM cata_world.creature_questender   WHERE id IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId=16 AND c.position_x BETWEEN 3200 AND 5400 AND c.position_y BETWEEN -5334 AND -3200)) AND id NOT IN (SELECT entry FROM acore_world.creature_template WHERE entry < @OFF);
INSERT IGNORE INTO acore_world.creature_questender   (`id`, `quest`) SELECT `id`+@OFF, `quest` FROM acore_world.creature_questender   WHERE id IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId=16 AND c.position_x BETWEEN 3200 AND 5400 AND c.position_y BETWEEN -5334 AND -3200)) AND id IN (SELECT entry FROM acore_world.creature_template WHERE entry < @OFF) AND id < @OFF;


-- Verify -- quest links for the corner's +3.6M questgivers:
--   SELECT COUNT(*) FROM acore_world.creature_queststarter s
--   JOIN acore_world.creature c ON c.id = s.id
--   WHERE c.map = 750 AND c.position_x BETWEEN 3200 AND 5400
--     AND c.position_y BETWEEN -5334 AND -3200;
