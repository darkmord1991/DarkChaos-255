-- =====================================================================================
-- Cataclysm Shadowfang Keep -- map 825 clone, step 9: quests
--
-- The 8 Cataclysm SFK quests, cloned into the DC band 90100-90107.
--
-- REQUIRES 03_templates.sql (dc_sfk825_ct_set + the offset creature_template rows).
--
-- ---------------------------------------------------------------------------------
-- LEVELS ARE LEFT AT THE CATACLYSM VALUES ON PURPOSE
-- ---------------------------------------------------------------------------------
-- QuestLevel 18-21, MinLevel 16, exactly as Blizzard shipped them. That is nowhere near
-- map 751's 130-160 band, and it is deliberate: the re-level happens later as part of the
-- general rescaling pass, together with the creature levels (which this import also left
-- at their Cata 1-85 values) and dungeon_access_template's placeholder gates.
--
-- When that pass comes, everything that needs touching is in ONE place per quest:
--     quest_template.QuestLevel     -- -1 means "scale to player" on this fork
--     quest_template.MinLevel       -- the actual gate
--     quest_template.RewardXPDifficulty / RewardMoney
-- The BFD-820 clone is the worked precedent: QuestLevel -1 + MinLevel 90 + a token reward.
--
-- ---------------------------------------------------------------------------------
-- WHAT IS BEING CLONED
-- ---------------------------------------------------------------------------------
-- Two 4-quest chains, one per faction, linked through quest_template_addon.PrevQuestID:
--
--   Alliance, from Packleader Ivar Bloodfang (47006)
--     90100 Sniffing Them Out          (27917)  kill Baron Ashbury
--     90101 Armored to the Teeth       (27920)  kill Silverlaine + Springvale
--     90102 Fighting Tooth and Claw    (27921)  kill Lord Walden
--     90103 Fury of the Pack           (27968)  kill Lord Godfrey
--
--   Horde, from 47293
--     90104 This Land is Our Land      (27974)  kill Baron Ashbury
--     90105 Plague...Plague Everywhere! (27988) kill Silverlaine + Springvale
--     90106 Orders Are For the Living  (27996)  kill Lord Walden
--     90107 Sweet, Merciless Revenge   (27998)  kill Lord Godfrey
--
-- Every objective is an NPC kill and NONE of the eight has an item objective, so the
-- deferred loot layer does not block any of them -- only the creature entries are remapped.
-- Both givers are spawned inside the instance (6 each) and both came across in 03/04.
--
-- The source ids 27917.. do not exist in acore_world at all, so the offset is not strictly
-- required -- it is applied anyway so that a future Cata quest import cannot collide, and
-- so every SFK-Cata id sits in one reviewable band.
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- 1. Quest id map.
-- -------------------------------------------------------------------------------------
DROP TABLE IF EXISTS `dc_sfk825_qmap`;
CREATE TABLE `dc_sfk825_qmap` (
    `src_quest` INT UNSIGNED NOT NULL PRIMARY KEY,
    `new_quest` INT UNSIGNED NOT NULL,
    UNIQUE KEY `uk_new` (`new_quest`)
) ENGINE=InnoDB;

INSERT INTO `dc_sfk825_qmap` (`src_quest`, `new_quest`) VALUES
    (27917, 90100), (27920, 90101), (27921, 90102), (27968, 90103),
    (27974, 90104), (27988, 90105), (27996, 90106), (27998, 90107);

-- -------------------------------------------------------------------------------------
-- 2. quest_template
--
-- 105 AzerothCore columns against 101 shared with cata_world (RewardMoneyDifficulty,
-- TimeAllowed, AllowableRaces and Unknown0 exist only here and take their defaults).
--
-- The column list is BUILT AT RUNTIME from information_schema rather than typed out.
-- Transcribing 101 names by hand is exactly the kind of thing that produces a silent
-- one-column shift, and this way the statement also survives a future schema change on
-- either side instead of quietly writing the wrong field.
--
-- Copy first, then fix the ids up in place -- far easier to review than 101 CASE arms.
-- -------------------------------------------------------------------------------------
SET SESSION group_concat_max_len = 65535;

SELECT GROUP_CONCAT(CONCAT('`', c.COLUMN_NAME, '`') ORDER BY c.ORDINAL_POSITION SEPARATOR ', ')
  INTO @qt_cols
FROM information_schema.COLUMNS c
JOIN information_schema.COLUMNS k
  ON k.TABLE_SCHEMA = 'cata_world' AND k.TABLE_NAME = 'quest_template'
 AND k.COLUMN_NAME = c.COLUMN_NAME
WHERE c.TABLE_SCHEMA = DATABASE() AND c.TABLE_NAME = 'quest_template';

DELETE FROM `quest_template` WHERE `ID` BETWEEN 90100 AND 90107;

-- Re-run safety. The rows are inserted under their SOURCE ids and re-keyed a statement
-- later; if a run ever dies in between, the source ids would be left sitting in the table
-- and the next run's re-key would collide. Clearing them first is safe because these ids
-- are not stock AzerothCore content -- verified absent from acore_world before this file
-- was written, and they only ever appear here as a transient.
DELETE FROM `quest_template` WHERE `ID` IN (SELECT `src_quest` FROM `dc_sfk825_qmap`);

SET @sql = CONCAT(
    'INSERT INTO `quest_template` (', @qt_cols, ') SELECT ', @qt_cols,
    ' FROM `cata_world`.`quest_template` WHERE `ID` IN (SELECT `src_quest` FROM `dc_sfk825_qmap`)');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- Re-key to the DC band.
UPDATE `quest_template` q
JOIN `dc_sfk825_qmap` m ON m.src_quest = q.ID
SET q.ID = m.new_quest
WHERE q.ID IN (SELECT `src_quest` FROM `dc_sfk825_qmap`);

-- Point the kill objectives at the CLONE creatures. Without this the quests would credit
-- kills in classic Shadowfang Keep on map 33 instead -- 3887 and 4278 are shared entries.
UPDATE `quest_template` q
SET q.RequiredNpcOrGo1 = IF(q.RequiredNpcOrGo1 > 0
        AND q.RequiredNpcOrGo1 IN (SELECT `entry` FROM `dc_sfk825_ct_set`),
        q.RequiredNpcOrGo1 + 5000000, q.RequiredNpcOrGo1),
    q.RequiredNpcOrGo2 = IF(q.RequiredNpcOrGo2 > 0
        AND q.RequiredNpcOrGo2 IN (SELECT `entry` FROM `dc_sfk825_ct_set`),
        q.RequiredNpcOrGo2 + 5000000, q.RequiredNpcOrGo2),
    q.RequiredNpcOrGo3 = IF(q.RequiredNpcOrGo3 > 0
        AND q.RequiredNpcOrGo3 IN (SELECT `entry` FROM `dc_sfk825_ct_set`),
        q.RequiredNpcOrGo3 + 5000000, q.RequiredNpcOrGo3),
    q.RequiredNpcOrGo4 = IF(q.RequiredNpcOrGo4 > 0
        AND q.RequiredNpcOrGo4 IN (SELECT `entry` FROM `dc_sfk825_ct_set`),
        q.RequiredNpcOrGo4 + 5000000, q.RequiredNpcOrGo4)
WHERE q.ID BETWEEN 90100 AND 90107;

-- RewardNextQuest is a quest id; remap any that points inside the set.
UPDATE `quest_template` q
JOIN `dc_sfk825_qmap` m ON m.src_quest = q.RewardNextQuest
SET q.RewardNextQuest = m.new_quest
WHERE q.ID BETWEEN 90100 AND 90107;

-- -------------------------------------------------------------------------------------
-- 3. quest_template_addon -- clean 1:1 (18 columns).
--    PrevQuestID is what makes each chain a chain, so it must be remapped or every quest
--    becomes independently available.
-- -------------------------------------------------------------------------------------
DELETE FROM `quest_template_addon` WHERE `ID` BETWEEN 90100 AND 90107;
INSERT INTO `quest_template_addon`
    (`ID`, `MaxLevel`, `AllowableClasses`, `SourceSpellID`, `PrevQuestID`, `NextQuestID`,
     `ExclusiveGroup`, `BreadcrumbForQuestId`, `RewardMailTemplateID`, `RewardMailDelay`,
     `RequiredSkillID`, `RequiredSkillPoints`, `RequiredMinRepFaction`, `RequiredMaxRepFaction`,
     `RequiredMinRepValue`, `RequiredMaxRepValue`, `ProvidedItemCount`, `SpecialFlags`)
SELECT m.new_quest, a.MaxLevel, a.AllowableClasses, a.SourceSpellID,
       IFNULL((SELECT p.new_quest FROM `dc_sfk825_qmap` p WHERE p.src_quest = a.PrevQuestID), a.PrevQuestID),
       IFNULL((SELECT n.new_quest FROM `dc_sfk825_qmap` n WHERE n.src_quest = a.NextQuestID), a.NextQuestID),
       a.ExclusiveGroup, a.BreadcrumbForQuestId, a.RewardMailTemplateID, a.RewardMailDelay,
       a.RequiredSkillID, a.RequiredSkillPoints, a.RequiredMinRepFaction, a.RequiredMaxRepFaction,
       a.RequiredMinRepValue, a.RequiredMaxRepValue, a.ProvidedItemCount, a.SpecialFlags
FROM `cata_world`.`quest_template_addon` a
JOIN `dc_sfk825_qmap` m ON m.src_quest = a.ID;

-- -------------------------------------------------------------------------------------
-- 4. Gossip text tables -- both clean 1:1.
-- -------------------------------------------------------------------------------------
DELETE FROM `quest_offer_reward` WHERE `ID` BETWEEN 90100 AND 90107;
INSERT INTO `quest_offer_reward`
    (`ID`, `Emote1`, `Emote2`, `Emote3`, `Emote4`, `EmoteDelay1`, `EmoteDelay2`,
     `EmoteDelay3`, `EmoteDelay4`, `RewardText`, `VerifiedBuild`)
SELECT m.new_quest, o.Emote1, o.Emote2, o.Emote3, o.Emote4, o.EmoteDelay1, o.EmoteDelay2,
       o.EmoteDelay3, o.EmoteDelay4, o.RewardText, o.VerifiedBuild
FROM `cata_world`.`quest_offer_reward` o
JOIN `dc_sfk825_qmap` m ON m.src_quest = o.ID;

DELETE FROM `quest_request_items` WHERE `ID` BETWEEN 90100 AND 90107;
INSERT INTO `quest_request_items`
    (`ID`, `EmoteOnComplete`, `EmoteOnIncomplete`, `CompletionText`, `VerifiedBuild`)
SELECT m.new_quest, r.EmoteOnComplete, r.EmoteOnIncomplete, r.CompletionText, r.VerifiedBuild
FROM `cata_world`.`quest_request_items` r
JOIN `dc_sfk825_qmap` m ON m.src_quest = r.ID;

-- -------------------------------------------------------------------------------------
-- 5. Questgiver bindings.
--    Both the quest id AND the giver entry shift: the givers are inside the instance, so
--    they are clone creatures in the +5,000,000 band.
-- -------------------------------------------------------------------------------------
DELETE FROM `creature_queststarter` WHERE `quest` BETWEEN 90100 AND 90107;
INSERT INTO `creature_queststarter` (`id`, `quest`)
SELECT s.id + 5000000, m.new_quest
FROM `cata_world`.`creature_queststarter` s
JOIN `dc_sfk825_qmap` m ON m.src_quest = s.quest
WHERE s.id IN (SELECT `entry` FROM `dc_sfk825_ct_set`);

DELETE FROM `creature_questender` WHERE `quest` BETWEEN 90100 AND 90107;
INSERT INTO `creature_questender` (`id`, `quest`)
SELECT e.id + 5000000, m.new_quest
FROM `cata_world`.`creature_questender` e
JOIN `dc_sfk825_qmap` m ON m.src_quest = e.quest
WHERE e.id IN (SELECT `entry` FROM `dc_sfk825_ct_set`);

-- -------------------------------------------------------------------------------------
-- 6. Quest POI -- the map markers.
--
-- AzerothCore's quest_poi carries an `id` column that cata_world does not; cata calls the
-- same thing `BlobIndex`. MapID is rewritten to 825 so the blob lands on the clone.
-- WorldMapAreaID stays as-is: 825 shares map 33's terrain and reports the same area.
-- -------------------------------------------------------------------------------------
DELETE FROM `quest_poi` WHERE `QuestID` BETWEEN 90100 AND 90107;
INSERT INTO `quest_poi`
    (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`,
     `Flags`, `VerifiedBuild`)
SELECT m.new_quest, p.BlobIndex, p.ObjectiveIndex, 825, p.WorldMapAreaID, p.Floor,
       p.Priority, p.Flags, p.VerifiedBuild
FROM `cata_world`.`quest_poi` p
JOIN `dc_sfk825_qmap` m ON m.src_quest = p.QuestID;

DELETE FROM `quest_poi_points` WHERE `QuestID` BETWEEN 90100 AND 90107;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT m.new_quest, p.Idx1, p.Idx2, p.X, p.Y, p.VerifiedBuild
FROM `cata_world`.`quest_poi_points` p
JOIN `dc_sfk825_qmap` m ON m.src_quest = p.QuestID;

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
SELECT 'quest_template (want 8)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `quest_template` WHERE `ID` BETWEEN 90100 AND 90107
UNION ALL SELECT 'quest_template_addon (want 8)', CAST(COUNT(*) AS CHAR)
    FROM `quest_template_addon` WHERE `ID` BETWEEN 90100 AND 90107
UNION ALL SELECT 'quest_offer_reward (want 8)', CAST(COUNT(*) AS CHAR)
    FROM `quest_offer_reward` WHERE `ID` BETWEEN 90100 AND 90107
UNION ALL SELECT 'quest_request_items (want 3)', CAST(COUNT(*) AS CHAR)
    FROM `quest_request_items` WHERE `ID` BETWEEN 90100 AND 90107
UNION ALL SELECT 'queststarter (want 8)', CAST(COUNT(*) AS CHAR)
    FROM `creature_queststarter` WHERE `quest` BETWEEN 90100 AND 90107
UNION ALL SELECT 'questender (want 8)', CAST(COUNT(*) AS CHAR)
    FROM `creature_questender` WHERE `quest` BETWEEN 90100 AND 90107
UNION ALL SELECT 'quest_poi (want 18)', CAST(COUNT(*) AS CHAR)
    FROM `quest_poi` WHERE `QuestID` BETWEEN 90100 AND 90107
UNION ALL SELECT 'quest_poi_points (want 18)', CAST(COUNT(*) AS CHAR)
    FROM `quest_poi_points` WHERE `QuestID` BETWEEN 90100 AND 90107
-- Every kill objective must point into the clone band, never at a stock entry.
UNION ALL SELECT 'objectives still pointing at STOCK entries (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `quest_template` WHERE `ID` BETWEEN 90100 AND 90107
      AND (   (`RequiredNpcOrGo1` > 0 AND `RequiredNpcOrGo1` < 5000000)
           OR (`RequiredNpcOrGo2` > 0 AND `RequiredNpcOrGo2` < 5000000)
           OR (`RequiredNpcOrGo3` > 0 AND `RequiredNpcOrGo3` < 5000000)
           OR (`RequiredNpcOrGo4` > 0 AND `RequiredNpcOrGo4` < 5000000))
UNION ALL SELECT 'objectives with no matching template (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `quest_template` q WHERE q.ID BETWEEN 90100 AND 90107
      AND q.RequiredNpcOrGo1 > 0
      AND q.RequiredNpcOrGo1 NOT IN (SELECT `entry` FROM `creature_template`)
-- Both chains must be 3 links deep (quest 1 of each has no prerequisite).
UNION ALL SELECT 'chain links inside the band (want 6)', CAST(COUNT(*) AS CHAR)
    FROM `quest_template_addon` WHERE `ID` BETWEEN 90100 AND 90107
      AND `PrevQuestID` BETWEEN 90100 AND 90107
UNION ALL SELECT 'givers outside the clone band (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_queststarter` WHERE `quest` BETWEEN 90100 AND 90107
      AND `id` NOT BETWEEN 5000000 AND 5099999
-- The source quests must remain absent: they were never in acore and must stay that way.
UNION ALL SELECT 'STOCK 27917.. leaked in (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `quest_template` WHERE `ID` IN (27917, 27920, 27921, 27968, 27974, 27988, 27996, 27998)
UNION ALL SELECT 'levels (left at Cata values on purpose)',
    (SELECT GROUP_CONCAT(CONCAT(`ID`, ':', `QuestLevel`) ORDER BY `ID` SEPARATOR ' ')
     FROM `quest_template` WHERE `ID` BETWEEN 90100 AND 90107);
