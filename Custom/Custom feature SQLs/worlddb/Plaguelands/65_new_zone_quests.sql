-- 65_new_zone_quests.sql — map 751 Lordaeron extension, DB step 5.
--
-- Quests for the 7 new zones + the NPC/GO links that hand them out.
-- REQUIRES 62_ (templates + dc_map751_src_* sets). 63_/64_ are independent.
--
-- QUEST IDS ARE NOT OFFSET. Quest ids are a single global space and the client
-- keys its quest log to them, so a quest keeps its real id — which makes ID
-- COLLISION the whole problem with this file.
--
-- 436 quests are involved. 92 already exist in acore_world:
--   * 89 are the SAME quest (identical LogTitle) -> acore's row is kept as-is and
--     only the NPC/GO link is written. acore's copy is the 3.3.5-correct one and
--     stock map-0 content depends on it; overwriting it would edit the live game.
--   * 3 are a DIFFERENT quest sharing the id -> SKIPPED ENTIRELY, no template and
--     no link, because wiring our NPC to them would make it offer unrelated
--     content. Measured, not assumed:
--         6321  cata "Supplying Brill"                vs acore "Supplying the Sepulcher"
--         6324  cata "Return to Morris"               vs acore "Return to Podrig"
--        14351  cata "[DEPRECATED] Battle of Hillsbrad" vs acore "Battle of Hillsbrad"
--     (6321/6324 are Cata renames of vanilla quests; 14351 is deprecated upstream,
--     so acore's version is the better one in all three cases.)
--   The exclusion is computed by comparing LogTitle at run time, NOT hardcoded, so
--   it stays correct if either database changes.
--
-- OBJECTIVE REMAP — the part that decides whether these quests are completable:
-- RequiredNpcOrGo1-4 hold creature entries (positive) and gameobject entries
-- (negative). Left raw they point at the stock map-0 creature, so killing our
-- clone on 751 would never count. Each is remapped to the offset id when that
-- creature/GO is part of this import, and left alone when it is not (the target
-- genuinely lives elsewhere).
--
-- POIContinent 0 -> 751 for the same reason.
--
-- DEFERRED: quest_poi / quest_poi_points. Those rows carry a WorldMapAreaId, and
-- map 751 has no per-zone WorldMapArea rows yet (only the 1217/1267 pair). Import
-- them together with the world-map layer or the markers land in the wrong place.

SET @COFF := 4100000;
SET @GOFF := 4600000;

-- ---------------------------------------------------------------------------
-- The quest set: everything our creatures/GOs hand out or take in, minus the
-- id-collision casualties.
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS `dc_map751_src_quest`;
CREATE TABLE `dc_map751_src_quest` (
  `quest` INT UNSIGNED NOT NULL,
  `already_in_acore` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`quest`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `dc_map751_src_quest` (`quest`,`already_in_acore`)
SELECT x.`quest`, IF(a.`ID` IS NULL, 0, 1)
FROM (
  SELECT q.`quest` FROM `cata_world`.`creature_queststarter`   q JOIN `dc_map751_src_creature`   s ON s.`id` = q.`id`
  UNION SELECT q.`quest` FROM `cata_world`.`creature_questender`     q JOIN `dc_map751_src_creature`   s ON s.`id` = q.`id`
  UNION SELECT q.`quest` FROM `cata_world`.`gameobject_queststarter` q JOIN `dc_map751_src_gameobject` s ON s.`id` = q.`id`
  UNION SELECT q.`quest` FROM `cata_world`.`gameobject_questender`   q JOIN `dc_map751_src_gameobject` s ON s.`id` = q.`id`
) x
JOIN `cata_world`.`quest_template` cq ON cq.`ID` = x.`quest`
LEFT JOIN `quest_template` a ON a.`ID` = x.`quest`
-- drop the id-collision casualties: same id, different quest
WHERE a.`ID` IS NULL OR a.`LogTitle` = cq.`LogTitle`;

-- ---------------------------------------------------------------------------
-- quest_template — only for quests acore does not already have
-- ---------------------------------------------------------------------------
INSERT INTO `quest_template`
 (`ID`,`QuestType`,`QuestLevel`,`MinLevel`,`QuestSortID`,`QuestInfoID`,`SuggestedGroupNum`,
  `RequiredFactionId1`,`RequiredFactionId2`,`RequiredFactionValue1`,`RequiredFactionValue2`,
  `RewardNextQuest`,`RewardXPDifficulty`,`RewardMoney`,`RewardDisplaySpell`,`RewardSpell`,
  `RewardHonor`,`RewardKillHonor`,`StartItem`,`Flags`,`RequiredPlayerKills`,
  `RewardItem1`,`RewardAmount1`,`RewardItem2`,`RewardAmount2`,`RewardItem3`,`RewardAmount3`,
  `RewardItem4`,`RewardAmount4`,`ItemDrop1`,`ItemDropQuantity1`,`ItemDrop2`,`ItemDropQuantity2`,
  `ItemDrop3`,`ItemDropQuantity3`,`ItemDrop4`,`ItemDropQuantity4`,
  `RewardChoiceItemID1`,`RewardChoiceItemQuantity1`,`RewardChoiceItemID2`,`RewardChoiceItemQuantity2`,
  `RewardChoiceItemID3`,`RewardChoiceItemQuantity3`,`RewardChoiceItemID4`,`RewardChoiceItemQuantity4`,
  `RewardChoiceItemID5`,`RewardChoiceItemQuantity5`,`RewardChoiceItemID6`,`RewardChoiceItemQuantity6`,
  `POIContinent`,`POIx`,`POIy`,`POIPriority`,`RewardTitle`,`RewardTalents`,`RewardArenaPoints`,
  `RewardFactionID1`,`RewardFactionValue1`,`RewardFactionOverride1`,
  `RewardFactionID2`,`RewardFactionValue2`,`RewardFactionOverride2`,
  `RewardFactionID3`,`RewardFactionValue3`,`RewardFactionOverride3`,
  `RewardFactionID4`,`RewardFactionValue4`,`RewardFactionOverride4`,
  `RewardFactionID5`,`RewardFactionValue5`,`RewardFactionOverride5`,
  `LogTitle`,`LogDescription`,`QuestDescription`,`AreaDescription`,`QuestCompletionLog`,
  `RequiredNpcOrGo1`,`RequiredNpcOrGo2`,`RequiredNpcOrGo3`,`RequiredNpcOrGo4`,
  `RequiredNpcOrGoCount1`,`RequiredNpcOrGoCount2`,`RequiredNpcOrGoCount3`,`RequiredNpcOrGoCount4`,
  `RequiredItemId1`,`RequiredItemId2`,`RequiredItemId3`,`RequiredItemId4`,`RequiredItemId5`,`RequiredItemId6`,
  `RequiredItemCount1`,`RequiredItemCount2`,`RequiredItemCount3`,`RequiredItemCount4`,
  `RequiredItemCount5`,`RequiredItemCount6`,
  `ObjectiveText1`,`ObjectiveText2`,`ObjectiveText3`,`ObjectiveText4`,`VerifiedBuild`,
  `AllowableRaces`,`TimeAllowed`,`RewardMoneyDifficulty`,`Unknown0`)
SELECT
  c.`ID`,c.`QuestType`,c.`QuestLevel`,c.`MinLevel`,c.`QuestSortID`,c.`QuestInfoID`,c.`SuggestedGroupNum`,
  c.`RequiredFactionId1`,c.`RequiredFactionId2`,c.`RequiredFactionValue1`,c.`RequiredFactionValue2`,
  c.`RewardNextQuest`,c.`RewardXPDifficulty`,c.`RewardMoney`,c.`RewardDisplaySpell`,c.`RewardSpell`,
  c.`RewardHonor`,c.`RewardKillHonor`,c.`StartItem`,c.`Flags`,c.`RequiredPlayerKills`,
  c.`RewardItem1`,c.`RewardAmount1`,c.`RewardItem2`,c.`RewardAmount2`,c.`RewardItem3`,c.`RewardAmount3`,
  c.`RewardItem4`,c.`RewardAmount4`,c.`ItemDrop1`,c.`ItemDropQuantity1`,c.`ItemDrop2`,c.`ItemDropQuantity2`,
  c.`ItemDrop3`,c.`ItemDropQuantity3`,c.`ItemDrop4`,c.`ItemDropQuantity4`,
  c.`RewardChoiceItemID1`,c.`RewardChoiceItemQuantity1`,c.`RewardChoiceItemID2`,c.`RewardChoiceItemQuantity2`,
  c.`RewardChoiceItemID3`,c.`RewardChoiceItemQuantity3`,c.`RewardChoiceItemID4`,c.`RewardChoiceItemQuantity4`,
  c.`RewardChoiceItemID5`,c.`RewardChoiceItemQuantity5`,c.`RewardChoiceItemID6`,c.`RewardChoiceItemQuantity6`,
  IF(c.`POIContinent` = 0, 751, c.`POIContinent`),
  c.`POIx`,c.`POIy`,c.`POIPriority`,c.`RewardTitle`,c.`RewardTalents`,c.`RewardArenaPoints`,
  c.`RewardFactionID1`,c.`RewardFactionValue1`,c.`RewardFactionOverride1`,
  c.`RewardFactionID2`,c.`RewardFactionValue2`,c.`RewardFactionOverride2`,
  c.`RewardFactionID3`,c.`RewardFactionValue3`,c.`RewardFactionOverride3`,
  c.`RewardFactionID4`,c.`RewardFactionValue4`,c.`RewardFactionOverride4`,
  c.`RewardFactionID5`,c.`RewardFactionValue5`,c.`RewardFactionOverride5`,
  c.`LogTitle`,c.`LogDescription`,c.`QuestDescription`,c.`AreaDescription`,c.`QuestCompletionLog`,
  -- objective targets: creature (>0) and gameobject (<0), remapped only when the
  -- target is part of this import
  CASE WHEN c.`RequiredNpcOrGo1` > 0 AND EXISTS(SELECT 1 FROM `dc_map751_src_creature`   m WHERE m.`id` =  c.`RequiredNpcOrGo1`) THEN c.`RequiredNpcOrGo1` + @COFF
       WHEN c.`RequiredNpcOrGo1` < 0 AND EXISTS(SELECT 1 FROM `dc_map751_src_gameobject` m WHERE m.`id` = -c.`RequiredNpcOrGo1`) THEN c.`RequiredNpcOrGo1` - @GOFF
       ELSE c.`RequiredNpcOrGo1` END,
  CASE WHEN c.`RequiredNpcOrGo2` > 0 AND EXISTS(SELECT 1 FROM `dc_map751_src_creature`   m WHERE m.`id` =  c.`RequiredNpcOrGo2`) THEN c.`RequiredNpcOrGo2` + @COFF
       WHEN c.`RequiredNpcOrGo2` < 0 AND EXISTS(SELECT 1 FROM `dc_map751_src_gameobject` m WHERE m.`id` = -c.`RequiredNpcOrGo2`) THEN c.`RequiredNpcOrGo2` - @GOFF
       ELSE c.`RequiredNpcOrGo2` END,
  CASE WHEN c.`RequiredNpcOrGo3` > 0 AND EXISTS(SELECT 1 FROM `dc_map751_src_creature`   m WHERE m.`id` =  c.`RequiredNpcOrGo3`) THEN c.`RequiredNpcOrGo3` + @COFF
       WHEN c.`RequiredNpcOrGo3` < 0 AND EXISTS(SELECT 1 FROM `dc_map751_src_gameobject` m WHERE m.`id` = -c.`RequiredNpcOrGo3`) THEN c.`RequiredNpcOrGo3` - @GOFF
       ELSE c.`RequiredNpcOrGo3` END,
  CASE WHEN c.`RequiredNpcOrGo4` > 0 AND EXISTS(SELECT 1 FROM `dc_map751_src_creature`   m WHERE m.`id` =  c.`RequiredNpcOrGo4`) THEN c.`RequiredNpcOrGo4` + @COFF
       WHEN c.`RequiredNpcOrGo4` < 0 AND EXISTS(SELECT 1 FROM `dc_map751_src_gameobject` m WHERE m.`id` = -c.`RequiredNpcOrGo4`) THEN c.`RequiredNpcOrGo4` - @GOFF
       ELSE c.`RequiredNpcOrGo4` END,
  c.`RequiredNpcOrGoCount1`,c.`RequiredNpcOrGoCount2`,c.`RequiredNpcOrGoCount3`,c.`RequiredNpcOrGoCount4`,
  c.`RequiredItemId1`,c.`RequiredItemId2`,c.`RequiredItemId3`,c.`RequiredItemId4`,c.`RequiredItemId5`,c.`RequiredItemId6`,
  c.`RequiredItemCount1`,c.`RequiredItemCount2`,c.`RequiredItemCount3`,c.`RequiredItemCount4`,
  c.`RequiredItemCount5`,c.`RequiredItemCount6`,
  c.`ObjectiveText1`,c.`ObjectiveText2`,c.`ObjectiveText3`,c.`ObjectiveText4`,c.`VerifiedBuild`,
  -- these four live in cata's quest_template_addon, not its quest_template
  COALESCE(ca.`AllowableRaces`, 0),
  COALESCE(ca.`TimeAllowed`, 0),
  COALESCE(ca.`RewardMoneyDifficulty`, 0),
  0
FROM `cata_world`.`quest_template` c
JOIN `dc_map751_src_quest` q ON q.`quest` = c.`ID` AND q.`already_in_acore` = 0
LEFT JOIN `cata_world`.`quest_template_addon` ca ON ca.`ID` = c.`ID`;

-- ---------------------------------------------------------------------------
-- quest_template_addon. Chain pointers that lead to a quest we did not import are
-- zeroed: a dangling PrevQuestID/NextQuestID breaks the chain check at load.
-- ---------------------------------------------------------------------------
INSERT INTO `quest_template_addon`
 (`ID`,`MaxLevel`,`AllowableClasses`,`SourceSpellID`,`PrevQuestID`,`NextQuestID`,`ExclusiveGroup`,
  `BreadcrumbForQuestId`,`RewardMailTemplateID`,`RewardMailDelay`,`RequiredSkillID`,
  `RequiredSkillPoints`,`RequiredMinRepFaction`,`RequiredMaxRepFaction`,`RequiredMinRepValue`,
  `RequiredMaxRepValue`,`ProvidedItemCount`,`SpecialFlags`)
SELECT
  a.`ID`, a.`MaxLevel`, a.`AllowableClasses`, a.`SourceSpellID`,
  IF(a.`PrevQuestID` <> 0 AND NOT EXISTS(SELECT 1 FROM `quest_template` t WHERE t.`ID` = ABS(a.`PrevQuestID`)), 0, a.`PrevQuestID`),
  IF(a.`NextQuestID` <> 0 AND NOT EXISTS(SELECT 1 FROM `quest_template` t WHERE t.`ID` = ABS(a.`NextQuestID`)), 0, a.`NextQuestID`),
  a.`ExclusiveGroup`,
  IF(a.`BreadcrumbForQuestId` <> 0 AND NOT EXISTS(SELECT 1 FROM `quest_template` t WHERE t.`ID` = ABS(a.`BreadcrumbForQuestId`)), 0, a.`BreadcrumbForQuestId`),
  a.`RewardMailTemplateID`, a.`RewardMailDelay`, a.`RequiredSkillID`, a.`RequiredSkillPoints`,
  a.`RequiredMinRepFaction`, a.`RequiredMaxRepFaction`, a.`RequiredMinRepValue`,
  a.`RequiredMaxRepValue`, a.`ProvidedItemCount`, a.`SpecialFlags`
FROM `cata_world`.`quest_template_addon` a
JOIN `dc_map751_src_quest` q ON q.`quest` = a.`ID` AND q.`already_in_acore` = 0
WHERE NOT EXISTS (SELECT 1 FROM `quest_template_addon` e WHERE e.`ID` = a.`ID`);

-- ---------------------------------------------------------------------------
-- The NPC / GO links, with the entry offsets applied.
-- ---------------------------------------------------------------------------
DELETE FROM `creature_queststarter`   WHERE `id` BETWEEN 4100000 AND 4199999;
DELETE FROM `creature_questender`     WHERE `id` BETWEEN 4100000 AND 4199999;
DELETE FROM `gameobject_queststarter` WHERE `id` BETWEEN 4600000 AND 4899999;
DELETE FROM `gameobject_questender`   WHERE `id` BETWEEN 4600000 AND 4899999;

INSERT INTO `creature_queststarter` (`id`,`quest`)
SELECT r.`id` + @COFF, r.`quest` FROM `cata_world`.`creature_queststarter` r
JOIN `dc_map751_src_creature` s ON s.`id` = r.`id`
JOIN `dc_map751_src_quest`    q ON q.`quest` = r.`quest`;

INSERT INTO `creature_questender` (`id`,`quest`)
SELECT r.`id` + @COFF, r.`quest` FROM `cata_world`.`creature_questender` r
JOIN `dc_map751_src_creature` s ON s.`id` = r.`id`
JOIN `dc_map751_src_quest`    q ON q.`quest` = r.`quest`;

INSERT INTO `gameobject_queststarter` (`id`,`quest`)
SELECT r.`id` + @GOFF, r.`quest` FROM `cata_world`.`gameobject_queststarter` r
JOIN `dc_map751_src_gameobject` s ON s.`id` = r.`id`
JOIN `dc_map751_src_quest`      q ON q.`quest` = r.`quest`;

INSERT INTO `gameobject_questender` (`id`,`quest`)
SELECT r.`id` + @GOFF, r.`quest` FROM `cata_world`.`gameobject_questender` r
JOIN `dc_map751_src_gameobject` s ON s.`id` = r.`id`
JOIN `dc_map751_src_quest`      q ON q.`quest` = r.`quest`;

-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------
SELECT 'quests in scope'            AS what, COUNT(*) AS n FROM `dc_map751_src_quest`
UNION ALL SELECT '  newly inserted',        COUNT(*) FROM `dc_map751_src_quest` WHERE `already_in_acore` = 0
UNION ALL SELECT '  reused acore rows',     COUNT(*) FROM `dc_map751_src_quest` WHERE `already_in_acore` = 1
UNION ALL SELECT 'creature_queststarter',   COUNT(*) FROM `creature_queststarter`   WHERE `id` BETWEEN 4100000 AND 4199999
UNION ALL SELECT 'creature_questender',     COUNT(*) FROM `creature_questender`     WHERE `id` BETWEEN 4100000 AND 4199999
UNION ALL SELECT 'gameobject_queststarter', COUNT(*) FROM `gameobject_queststarter` WHERE `id` BETWEEN 4600000 AND 4899999
UNION ALL SELECT 'gameobject_questender',   COUNT(*) FROM `gameobject_questender`   WHERE `id` BETWEEN 4600000 AND 4899999;

-- the 3 collisions we refused to touch, shown so the decision stays visible
SELECT 'SKIPPED: id reused by a different quest' AS note, cq.`ID`,
       cq.`LogTitle` AS cata_quest, a.`LogTitle` AS acore_quest_kept
FROM `cata_world`.`quest_template` cq
JOIN `quest_template` a ON a.`ID` = cq.`ID`
WHERE a.`LogTitle` <> cq.`LogTitle`
  AND cq.`ID` IN (
    SELECT q.`quest` FROM `cata_world`.`creature_queststarter`   q JOIN `dc_map751_src_creature`   s ON s.`id` = q.`id`
    UNION SELECT q.`quest` FROM `cata_world`.`creature_questender`     q JOIN `dc_map751_src_creature`   s ON s.`id` = q.`id`
    UNION SELECT q.`quest` FROM `cata_world`.`gameobject_queststarter` q JOIN `dc_map751_src_gameobject` s ON s.`id` = q.`id`
    UNION SELECT q.`quest` FROM `cata_world`.`gameobject_questender`   q JOIN `dc_map751_src_gameobject` s ON s.`id` = q.`id`);

-- must be zero: a link pointing at a quest that does not exist
SELECT 'PROBLEM: link to missing quest' AS problem, COUNT(*) AS n FROM (
  SELECT r.`quest` FROM `creature_queststarter`   r WHERE r.`id` BETWEEN 4100000 AND 4199999
  UNION ALL SELECT r.`quest` FROM `creature_questender`     r WHERE r.`id` BETWEEN 4100000 AND 4199999
  UNION ALL SELECT r.`quest` FROM `gameobject_queststarter` r WHERE r.`id` BETWEEN 4600000 AND 4899999
  UNION ALL SELECT r.`quest` FROM `gameobject_questender`   r WHERE r.`id` BETWEEN 4600000 AND 4899999
) l LEFT JOIN `quest_template` t ON t.`ID` = l.`quest` WHERE t.`ID` IS NULL;

-- objectives that still point at a stock creature we also cloned (should be zero)
SELECT 'PROBLEM: objective not remapped' AS problem, COUNT(*) AS n
FROM `quest_template` t JOIN `dc_map751_src_quest` q ON q.`quest` = t.`ID` AND q.`already_in_acore` = 0
WHERE (t.`RequiredNpcOrGo1` > 0 AND EXISTS(SELECT 1 FROM `dc_map751_src_creature` m WHERE m.`id` = t.`RequiredNpcOrGo1`))
   OR (t.`RequiredNpcOrGo2` > 0 AND EXISTS(SELECT 1 FROM `dc_map751_src_creature` m WHERE m.`id` = t.`RequiredNpcOrGo2`))
   OR (t.`RequiredNpcOrGo3` > 0 AND EXISTS(SELECT 1 FROM `dc_map751_src_creature` m WHERE m.`id` = t.`RequiredNpcOrGo3`))
   OR (t.`RequiredNpcOrGo4` > 0 AND EXISTS(SELECT 1 FROM `dc_map751_src_creature` m WHERE m.`id` = t.`RequiredNpcOrGo4`));
