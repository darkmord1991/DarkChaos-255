-- ====================================================================================
-- "Take Up the Watch" (quest 300100) - LEVEL-1 REWARD CHOICES + DROP THE DUPLICATE SHIRT
-- ====================================================================================
-- Database: acore_world
--
-- 300100 is the very first quest a fresh character turns in (Scout Thalindra 300001,
-- map 37), but its four reward choices were stock jewellery gated behind
-- RequiredLevel 10-15:
--
--     20906  Braided Copper Ring          req 10
--     21931  Woven Copper Ring            req 10
--     25438  Malachite Pendant            req 13
--     21934  Ornate Tigerseye Necklace    req 15
--
-- So the reward could be picked but not worn for another 9-14 levels. The stock rows
-- are shared with real world drops and vendors and are NOT touched here; instead each
-- is cloned into the free 3031xx custom band with RequiredLevel 0 and bind-on-pickup,
-- and the quest is repointed at the clones. Stats, display and item level are
-- identical to the originals - only the level gate and the binding change.
--
-- Free-band check (2026-08-29): item_template holds 303100-303139 (heirloom armor
-- parity) and nothing else between 303100 and 303300, so 303140-303143 are free.
--
-- CLIENT/SERVER DBC DEPENDENCY - ALREADY DONE, listed so a re-import knows the order.
-- ObjectMgr::LoadItemTemplates does `if (!sItemStore.LookupEntry(entry)) continue;` - an
-- item_template row with no Item.dbc row is SKIPPED ENTIRELY, and the only trace is a
-- LOG_DEBUG line. So 303140-303143 needed Item.dbc rows before this SQL means anything.
-- Done 2026-08-29: 44 rows appended to `Custom/CSV DBC/Item.csv` (the four clones plus
-- 303100-303139, the heirloom armor-parity set, which had been sitting in item_template
-- since round 5 with no DBC row and therefore never loaded), recompiled with
-- dbc-compile.py (0-diff verified, 154942 -> 154986 records) and deployed byte-verified
-- to client patch-4.MPQ, client enGB/patch-enGB-3.MPQ and the Server/data/dbc staging
-- mirror. The staging mirror still has to be pushed to the live box.
--
-- Clone technique: stage through a REAL table created with CREATE TABLE ... LIKE, so
-- no column list is hand-written (item_template's column order matches no dump).
-- A temporary table is not safe here - a client using more than one connection loses
-- it between statements.
-- ====================================================================================

DROP TABLE IF EXISTS `dc_watch_reward_stage`;
CREATE TABLE `dc_watch_reward_stage` LIKE `item_template`;

INSERT INTO `dc_watch_reward_stage` SELECT * FROM `item_template` WHERE `entry` IN (20906, 21931, 25438, 21934);

UPDATE `dc_watch_reward_stage`
SET `entry` = CASE `entry`
        WHEN 20906 THEN 303140
        WHEN 21931 THEN 303141
        WHEN 25438 THEN 303142
        WHEN 21934 THEN 303143
    END,
    `RequiredLevel` = 0,
    `bonding` = 1,
    `description` = 'Issued to those who first took up the watch over Azshara Crater.',
    `VerifiedBuild` = 0;

DELETE FROM `item_template` WHERE `entry` BETWEEN 303140 AND 303143;
INSERT INTO `item_template` SELECT * FROM `dc_watch_reward_stage`;

DROP TABLE `dc_watch_reward_stage`;

-- Repoint the quest at the level-1 clones (quantities already 1 each).
UPDATE `quest_template`
SET `RewardChoiceItemID1` = 303140,
    `RewardChoiceItemID2` = 303141,
    `RewardChoiceItemID3` = 303142,
    `RewardChoiceItemID4` = 303143
WHERE `ID` = 300100;

-- --------------------------------------------------------------------------------
-- Drop the duplicate Heirloom Adventurer's Shirt (300365).
-- --------------------------------------------------------------------------------
-- Two quests handed out the same shirt: this one and 820058 "The Watchful Eye"
-- (Hervikus 800009 -> Scout Thalindra 300001). 820058 keeps it; 300100 gives the
-- upgrade token and artifact essence it already carried in slots 2 and 3.
--
-- The remaining rewards MUST be shifted up into slots 1 and 2, not just blanked in
-- slot 1: ObjectMgr::LoadQuests (ObjectMgr.cpp ~5638) logs
--   "Quest 300100 has no `RewardItemId1` but has `RewardItem2`. Reward item will not
--    be loaded."
-- for every gap, on every startup - and the reward really is dropped.
UPDATE `quest_template`
SET `RewardItem1` = 300311, `RewardAmount1` = 3,
    `RewardItem2` = 300312, `RewardAmount2` = 2,
    `RewardItem3` = 0,      `RewardAmount3` = 0
WHERE `ID` = 300100;

-- Sanity: expect 4 rows, RequiredLevel 0, bonding 1.
-- SELECT `entry`, `name`, `InventoryType`, `RequiredLevel`, `bonding`, `stat_type1`, `stat_value1`
-- FROM `item_template` WHERE `entry` BETWEEN 303140 AND 303143;
