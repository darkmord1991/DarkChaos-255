-- =====================================================================================
-- Blackfathom Deeps (Ashenvale) -- map 820 clone, step 8: the quest layer
--
-- The 11 real Blackfathom quests, cloned into a private id block, re-levelled onto the
-- Ashenvale band and repointed at the clone. The originals are untouched, so the level-20-30
-- dungeon keeps its own quests.
--
-- WHY CLONE INSTEAD OF JUST ATTACHING THE ORIGINALS
-- The originals are level 22-27 and their kill objectives name the ORIGINAL creature entries.
-- Handing quest 6565 to a level-95 player would ask them to kill Lorgus Jett 12902 -- the one
-- on map 48 -- so killing the clone (3912902) would award no credit at all. Cloning lets the
-- objectives point at the clone and the levels match the band.
--
-- WHAT DID *NOT* NEED REMAPPING (checked, not assumed)
-- Of the 11 quests, ten have pure ITEM objectives (5359, 5879, 5881, 5952, 16784, 16790,
-- 16762) and only 6565 has an NPC kill objective. Item ids are untouched by the clone and
-- 04_loot.sql forked the loot tables with the same Item values, so the clone's mobs already
-- drop every quest item. Only 6565's RequiredNpcOrGo needs the creature offset.
--
-- QUEST SOURCE                          -> CLONE
--   971  Knowledge in the Deeps            90001
--   1198 In Search of Thaelrid             90002
--   1199 Twilight Falls                    90003
--   1200 Blackfathom Villainy   (Alliance) 90004
--   1275 Researching the Corruption        90005
--   6561 Blackfathom Villainy   (Horde)    90006
--   6562 Trouble in the Deeps              90007
--   6563 The Essence of Aku'Mai            90008
--   6564 Allegiance to the Old Gods        90009
--   6565 Allegiance to the Old Gods        90010
--   6921 Amongst the Ruins                 90011
-- 26894 / 26898 "Blackfathom Deeps" are deliberately excluded -- they are the Dungeon Finder
-- call-to-arms entries, not content.
--
-- KNOWN WART
-- Quest 6564 is item-started: `item_template` 16790 carries startquest = 6564. That column
-- belongs to a shared item, so it cannot be repointed at the clone without breaking the
-- original dungeon. Looting 16790 inside the clone therefore also offers the ORIGINAL
-- level-22 quest. Harmless -- the clone's own copy (90009) comes from the gatekeeper and is
-- handed in to the Je'neu clone inside -- but a player may end up with a stray low-level
-- quest in their log. Fixing it properly would mean a second copy of item 16790.
--
-- Run AFTER 01-05 and _shared/dungeon_entrance_npcs.sql. Re-runnable.
-- =====================================================================================

SET @C_OFF := 3900000;
SET @G_OFF := 4400000;
SET @GATE := 3999001;            -- Blackfathom Gatekeeper, outside on map 750
SET @THAELRID := 3904787;        -- Argent Guard Thaelrid clone, inside
SET @JENEU := 3912736;           -- Je'neu Sancrea clone, inside (spawned by 05)
SET @TOKEN := 300311;
SET @TOKEN_AMT := 30;            -- Ashenvale band rate, same as the zone's quests
SET @MINLEVEL := 90;             -- band bottom (92) minus 2, matching 234_'s convention

-- -------------------------------------------------------------------------------------
-- id map
-- -------------------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS tmp_bfdq;
CREATE TEMPORARY TABLE tmp_bfdq (old_id INT UNSIGNED PRIMARY KEY, new_id INT UNSIGNED UNIQUE);
INSERT INTO tmp_bfdq VALUES
    (971, 90001), (1198, 90002), (1199, 90003), (1200, 90004), (1275, 90005),
    (6561, 90006), (6562, 90007), (6563, 90008), (6564, 90009), (6565, 90010), (6921, 90011);

-- -------------------------------------------------------------------------------------
-- quest_template
-- -------------------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS tmp_q;
CREATE TEMPORARY TABLE tmp_q LIKE `quest_template`;
ALTER TABLE tmp_q DROP PRIMARY KEY, ADD COLUMN `new_id` INT UNSIGNED;
INSERT INTO tmp_q SELECT q.*, m.new_id FROM tmp_bfdq m JOIN `quest_template` q ON q.`ID` = m.old_id;
UPDATE tmp_q SET `ID` = `new_id`;
ALTER TABLE tmp_q DROP COLUMN `new_id`;

-- QuestLevel -1 = scale to the player, the convention 234_ used for every map-750 quest.
-- Note Quest::GetQuestLevel() returns int32; any consumer must be int32-aware or -1 wraps.
UPDATE tmp_q SET
    `QuestLevel` = -1,
    `MinLevel`   = @MINLEVEL,
    `RequiredNpcOrGo1` = CASE WHEN `RequiredNpcOrGo1` > 0 THEN `RequiredNpcOrGo1` + @C_OFF
                              WHEN `RequiredNpcOrGo1` < 0 THEN -(ABS(`RequiredNpcOrGo1`) + @G_OFF)
                              ELSE 0 END,
    `RequiredNpcOrGo2` = CASE WHEN `RequiredNpcOrGo2` > 0 THEN `RequiredNpcOrGo2` + @C_OFF
                              WHEN `RequiredNpcOrGo2` < 0 THEN -(ABS(`RequiredNpcOrGo2`) + @G_OFF)
                              ELSE 0 END,
    `RequiredNpcOrGo3` = CASE WHEN `RequiredNpcOrGo3` > 0 THEN `RequiredNpcOrGo3` + @C_OFF
                              WHEN `RequiredNpcOrGo3` < 0 THEN -(ABS(`RequiredNpcOrGo3`) + @G_OFF)
                              ELSE 0 END,
    `RequiredNpcOrGo4` = CASE WHEN `RequiredNpcOrGo4` > 0 THEN `RequiredNpcOrGo4` + @C_OFF
                              WHEN `RequiredNpcOrGo4` < 0 THEN -(ABS(`RequiredNpcOrGo4`) + @G_OFF)
                              ELSE 0 END,
    `VerifiedBuild` = 0;

-- Upgrade Token into the first FREE RewardItem slot. Four sequential statements rather than
-- one, because a single UPDATE evaluates assignments left to right using already-updated
-- values and would cascade the token into every slot.
UPDATE tmp_q SET `RewardItem1` = @TOKEN, `RewardAmount1` = @TOKEN_AMT WHERE `RewardItem1` = 0;
UPDATE tmp_q SET `RewardItem2` = @TOKEN, `RewardAmount2` = @TOKEN_AMT
    WHERE `RewardItem1` <> @TOKEN AND `RewardItem2` = 0;
UPDATE tmp_q SET `RewardItem3` = @TOKEN, `RewardAmount3` = @TOKEN_AMT
    WHERE `RewardItem1` <> @TOKEN AND `RewardItem2` <> @TOKEN AND `RewardItem3` = 0;
UPDATE tmp_q SET `RewardItem4` = @TOKEN, `RewardAmount4` = @TOKEN_AMT
    WHERE `RewardItem1` <> @TOKEN AND `RewardItem2` <> @TOKEN AND `RewardItem3` <> @TOKEN
      AND `RewardItem4` = 0;

DELETE FROM `quest_template` WHERE `ID` IN (SELECT new_id FROM tmp_bfdq);
INSERT INTO `quest_template` SELECT * FROM tmp_q;

-- -------------------------------------------------------------------------------------
-- quest_template_addon -- chains, remapped through the id map.
-- A prerequisite that points OUTSIDE this set is zeroed: 1275's PrevQuestID is 3765, an
-- Ashenvale quest that has no clone, and leaving it would make 90005 permanently unobtainable.
-- -------------------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS tmp_qa;
CREATE TEMPORARY TABLE tmp_qa LIKE `quest_template_addon`;
ALTER TABLE tmp_qa DROP PRIMARY KEY, ADD COLUMN `new_id` INT UNSIGNED;
INSERT INTO tmp_qa SELECT a.*, m.new_id FROM tmp_bfdq m JOIN `quest_template_addon` a ON a.`ID` = m.old_id;
UPDATE tmp_qa SET `ID` = `new_id`;
ALTER TABLE tmp_qa DROP COLUMN `new_id`;

UPDATE tmp_qa a LEFT JOIN tmp_bfdq p ON p.old_id = a.`PrevQuestID`
    SET a.`PrevQuestID` = IFNULL(p.new_id, 0) WHERE a.`PrevQuestID` <> 0;
UPDATE tmp_qa a LEFT JOIN tmp_bfdq n ON n.old_id = a.`NextQuestID`
    SET a.`NextQuestID` = IFNULL(n.new_id, 0) WHERE a.`NextQuestID` <> 0;
UPDATE tmp_qa a LEFT JOIN tmp_bfdq x ON x.old_id = ABS(a.`ExclusiveGroup`)
    SET a.`ExclusiveGroup` = IF(x.new_id IS NULL, 0,
                                IF(a.`ExclusiveGroup` < 0, -x.new_id, x.new_id))
    WHERE a.`ExclusiveGroup` <> 0;
UPDATE tmp_qa a LEFT JOIN tmp_bfdq b ON b.old_id = a.`BreadcrumbForQuestId`
    SET a.`BreadcrumbForQuestId` = IFNULL(b.new_id, 0) WHERE a.`BreadcrumbForQuestId` <> 0;

DELETE FROM `quest_template_addon` WHERE `ID` IN (SELECT new_id FROM tmp_bfdq);
INSERT INTO `quest_template_addon` SELECT * FROM tmp_qa;

-- -------------------------------------------------------------------------------------
-- Quest text. Without these the quest has no accept/progress/completion body.
-- -------------------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS tmp_qor;
CREATE TEMPORARY TABLE tmp_qor LIKE `quest_offer_reward`;
ALTER TABLE tmp_qor DROP PRIMARY KEY, ADD COLUMN `new_id` INT UNSIGNED;
INSERT INTO tmp_qor SELECT o.*, m.new_id FROM tmp_bfdq m JOIN `quest_offer_reward` o ON o.`ID` = m.old_id;
UPDATE tmp_qor SET `ID` = `new_id`;
ALTER TABLE tmp_qor DROP COLUMN `new_id`;
DELETE FROM `quest_offer_reward` WHERE `ID` IN (SELECT new_id FROM tmp_bfdq);
INSERT INTO `quest_offer_reward` SELECT * FROM tmp_qor;

DROP TEMPORARY TABLE IF EXISTS tmp_qri;
CREATE TEMPORARY TABLE tmp_qri LIKE `quest_request_items`;
ALTER TABLE tmp_qri DROP PRIMARY KEY, ADD COLUMN `new_id` INT UNSIGNED;
INSERT INTO tmp_qri SELECT r.*, m.new_id FROM tmp_bfdq m JOIN `quest_request_items` r ON r.`ID` = m.old_id;
UPDATE tmp_qri SET `ID` = `new_id`;
ALTER TABLE tmp_qri DROP COLUMN `new_id`;
DELETE FROM `quest_request_items` WHERE `ID` IN (SELECT new_id FROM tmp_bfdq);
INSERT INTO `quest_request_items` SELECT * FROM tmp_qri;

DROP TEMPORARY TABLE IF EXISTS tmp_qd;
CREATE TEMPORARY TABLE tmp_qd LIKE `quest_details`;
ALTER TABLE tmp_qd DROP PRIMARY KEY, ADD COLUMN `new_id` INT UNSIGNED;
INSERT INTO tmp_qd SELECT d.*, m.new_id FROM tmp_bfdq m JOIN `quest_details` d ON d.`ID` = m.old_id;
UPDATE tmp_qd SET `ID` = `new_id`;
ALTER TABLE tmp_qd DROP COLUMN `new_id`;
DELETE FROM `quest_details` WHERE `ID` IN (SELECT new_id FROM tmp_bfdq);
INSERT INTO `quest_details` SELECT * FROM tmp_qd;

-- -------------------------------------------------------------------------------------
-- Givers and enders.
--
-- The structure mirrors the original: quests that were handed out in the world now come from
-- the gatekeeper standing at the cave mouth, and the two quests that lore-wise belong to an
-- NPC INSIDE the dungeon keep that NPC -- its clone is spawned on map 820, so the chain still
-- reads "go in, find Thaelrid". Making the gatekeeper end "In Search of Thaelrid" would let a
-- player complete it without ever entering.
--
--   gatekeeper 3999001 : 971, 1198, 1199, 1275, 6562, 6564, 6921 (givers) + the outside enders
--   Thaelrid   3904787 : ends 90002, starts 90004 / 90006
--   Je'neu     3912736 : the Horde chain inside
-- -------------------------------------------------------------------------------------
DELETE FROM `creature_queststarter` WHERE `quest` IN (SELECT new_id FROM tmp_bfdq);
DELETE FROM `creature_questender`   WHERE `quest` IN (SELECT new_id FROM tmp_bfdq);

INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
    (@GATE, 90001), (@GATE, 90002), (@GATE, 90003), (@GATE, 90005),
    (@GATE, 90007), (@GATE, 90009), (@GATE, 90011),
    (@THAELRID, 90004), (@THAELRID, 90006),
    (@JENEU, 90008), (@JENEU, 90010);

INSERT INTO `creature_questender` (`id`, `quest`) VALUES
    (@GATE, 90001), (@GATE, 90003), (@GATE, 90004), (@GATE, 90005), (@GATE, 90006),
    (@THAELRID, 90002),
    (@JENEU, 90007), (@JENEU, 90008), (@JENEU, 90009), (@JENEU, 90010), (@JENEU, 90011);

-- The gatekeeper needs the QUESTGIVER bit or none of this shows.
-- (_shared/dungeon_entrance_npcs.sql already sets npcflag 3; this is belt and braces so the
-- file is safe to apply on its own.)
UPDATE `creature_template` SET `npcflag` = `npcflag` | 2 WHERE `entry` = @GATE;

-- -------------------------------------------------------------------------------------
-- Report
--
-- NOTE: this deliberately uses the literal id range instead of `SELECT new_id FROM tmp_bfdq`.
-- MySQL cannot reopen a TEMPORARY table within a single statement, so a UNION that names one
-- eleven times dies with error 1137 "Can't reopen table". The cloned ids are contiguous
-- (90001-90011), so a BETWEEN is exact and needs no temp table at all.
-- -------------------------------------------------------------------------------------
SET @Q_LO := 90001;
SET @Q_HI := 90011;

SELECT 'quests cloned (want 11)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `quest_template` WHERE `ID` BETWEEN @Q_LO AND @Q_HI
UNION ALL SELECT 'addon rows (want 11)', CAST(COUNT(*) AS CHAR)
    FROM `quest_template_addon` WHERE `ID` BETWEEN @Q_LO AND @Q_HI
UNION ALL SELECT 'offer_reward text (want 11)', CAST(COUNT(*) AS CHAR)
    FROM `quest_offer_reward` WHERE `ID` BETWEEN @Q_LO AND @Q_HI
UNION ALL SELECT 'request_items text (want 11)', CAST(COUNT(*) AS CHAR)
    FROM `quest_request_items` WHERE `ID` BETWEEN @Q_LO AND @Q_HI
UNION ALL SELECT 'starters (want 11)', CAST(COUNT(*) AS CHAR)
    FROM `creature_queststarter` WHERE `quest` BETWEEN @Q_LO AND @Q_HI
UNION ALL SELECT 'enders (want 11)', CAST(COUNT(*) AS CHAR)
    FROM `creature_questender` WHERE `quest` BETWEEN @Q_LO AND @Q_HI
UNION ALL SELECT 'quests with no starter (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `quest_template` q WHERE q.`ID` BETWEEN @Q_LO AND @Q_HI
      AND NOT EXISTS (SELECT 1 FROM `creature_queststarter` s WHERE s.`quest` = q.`ID`)
UNION ALL SELECT 'quests with no ender (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `quest_template` q WHERE q.`ID` BETWEEN @Q_LO AND @Q_HI
      AND NOT EXISTS (SELECT 1 FROM `creature_questender` e WHERE e.`quest` = q.`ID`)
UNION ALL SELECT 'kill objectives repointed at the clone (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `quest_template` q JOIN `creature_template` ct ON ct.`entry` = q.`RequiredNpcOrGo1`
    WHERE q.`ID` BETWEEN @Q_LO AND @Q_HI AND q.`RequiredNpcOrGo1` > 0
UNION ALL SELECT 'quests granting the token (want 11)', CAST(COUNT(*) AS CHAR)
    FROM `quest_template` WHERE `ID` BETWEEN @Q_LO AND @Q_HI
      AND @TOKEN IN (`RewardItem1`, `RewardItem2`, `RewardItem3`, `RewardItem4`)
UNION ALL SELECT 'givers that exist as templates (want 3)', CAST(COUNT(DISTINCT s.`id`) AS CHAR)
    FROM `creature_queststarter` s JOIN `creature_template` ct ON ct.`entry` = s.`id`
    WHERE s.`quest` BETWEEN @Q_LO AND @Q_HI
UNION ALL SELECT 'orphan quest relations (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_queststarter` s
    LEFT JOIN `quest_template` q ON q.`ID` = s.`quest`
    WHERE s.`quest` BETWEEN @Q_LO AND @Q_HI AND q.`ID` IS NULL;

DROP TEMPORARY TABLE IF EXISTS tmp_q;
DROP TEMPORARY TABLE IF EXISTS tmp_qa;
DROP TEMPORARY TABLE IF EXISTS tmp_qor;
DROP TEMPORARY TABLE IF EXISTS tmp_qri;
DROP TEMPORARY TABLE IF EXISTS tmp_qd;
DROP TEMPORARY TABLE IF EXISTS tmp_bfdq;
