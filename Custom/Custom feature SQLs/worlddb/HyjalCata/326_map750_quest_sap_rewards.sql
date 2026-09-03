-- ---------------------------------------------------------------------------
-- 326  Map 750 -- Emberwood Sap on every zone quest
-- ---------------------------------------------------------------------------
-- 🔴 Sap has ONE tap, and 320_ just made it the currency for two whole upgrade
-- tiers. Measured live:
--
--     quests rewarding Emberwood Sap (400000)       0
--     quests rewarding DC Upgrade Token (300311)  716
--
-- Sap comes only from drops -- 550 creatures at 9.33% average for 1-3, i.e.
-- **~0.19 sap per kill** -- while the token it replaced for T4/T5 is paid by
-- 716 quests on top of its own drops. Before 320_ that was fine, because sap
-- only bought the 64 vendor ladder pieces. Now it gates every tier-4 and
-- tier-5 upgrade on the continent, and a single tap cannot carry that.
--
-- This is the companion 320_ needed and did not have.
--
-- ---------------------------------------------------------------------------
-- AMOUNTS -- band-scaled, at SAP magnitude, not token magnitude
-- ---------------------------------------------------------------------------
-- 🔴 Do NOT copy 253_'s numbers. Its 20-75 tokens per quest are calibrated
-- against token prices (5,500 for a full T4 path); sap prices are ~1/33 of that
-- (165 for T4, 600 for T5, 30-50 for a whole vendor gear piece). Paying 20-75
-- sap per quest would hand a player the entire vendor ladder in a dozen quests.
--
--     zone                     band        sap/quest  quests  subtotal
--     4929 Darkshore           80-90            2        87       174
--     4930 Azshara             80-90            2        55       110
--     4931 Ashenvale           88-98            3        51       153
--     4927 Felwood             96-106           4       138       552
--     4928 Moonglade           sanctuary        4         9        36
--     4926 Winterspring        104-115          6        70       420
--     4923 Hyjal Frontier      113-130         10       151     1,510
--                                                    -----------------
--                                                       561     2,955
--
-- ~2,955 sap across the whole 80->130 run. Against the anchors that is roughly
-- the entire 64-piece vendor ladder, OR five full tier-5 upgrade paths (600
-- each), OR seventeen tier-4 paths (165 each) -- with the drop tap still on top.
-- Hyjal alone is half of it, deliberately: it is the band where T4/T5 gear
-- actually drops.
--
-- Retune by editing the CASE and re-running; section A resets this file's own
-- rows first so amounts can be changed freely, exactly as 253_ does.
--
-- ---------------------------------------------------------------------------
-- SLOT CHOICE
-- ---------------------------------------------------------------------------
-- Sap goes in the first FREE `RewardItem` slot, which is never slot 1: 253_
-- already put the Upgrade Token in the first free slot on all 561 of these
-- quests, so slot 1 is always taken. Verified live -- **every one of the 561
-- has a free slot left** (502 free at slot 2, 560 at slot 3, 561 at slot 4;
-- zero quests with slots 2, 3 AND 4 all occupied), so nothing is displaced.
--
-- 🔴 Sap is a plain bag item, NOT a currency-tab token -- 320_ deliberately did
-- not give it BagFamily 0x2000 because it has no CurrencyTypes.dbc row. It
-- stacks to 2,500, so a full run's 2,955 is two bag slots. That is the trade
-- for not needing a client patch; revisit if it becomes annoying.
--
-- Run AFTER 253_ (needs `dc_map750_questzone` and the token already placed) and
-- after 320_. Idempotent. Needs `.reload quest_template` or a restart.
-- ---------------------------------------------------------------------------

USE `acore_world`;

-- ---------------------------------------------------------------------------
-- A) Reset this file's own rows so a re-run can retune the amounts
-- ---------------------------------------------------------------------------
UPDATE `quest_template` q JOIN `dc_map750_questzone` z ON z.`quest` = q.`ID`
SET q.`RewardItem2` = 0, q.`RewardAmount2` = 0 WHERE q.`RewardItem2` = 400000;
UPDATE `quest_template` q JOIN `dc_map750_questzone` z ON z.`quest` = q.`ID`
SET q.`RewardItem3` = 0, q.`RewardAmount3` = 0 WHERE q.`RewardItem3` = 400000;
UPDATE `quest_template` q JOIN `dc_map750_questzone` z ON z.`quest` = q.`ID`
SET q.`RewardItem4` = 0, q.`RewardAmount4` = 0 WHERE q.`RewardItem4` = 400000;

-- ---------------------------------------------------------------------------
-- B) Place sap in the first free slot, cascading 2 -> 3 -> 4
-- ---------------------------------------------------------------------------
-- Each statement excludes quests that already carry sap, so a quest is paid
-- exactly once and the cascade cannot double-place.
UPDATE `quest_template` q
JOIN `dc_map750_questzone` z ON z.`quest` = q.`ID`
SET q.`RewardItem2` = 400000,
    q.`RewardAmount2` = CASE z.`zone`
        WHEN 4929 THEN 2 WHEN 4930 THEN 2 WHEN 4931 THEN 3
        WHEN 4927 THEN 4 WHEN 4928 THEN 4 WHEN 4926 THEN 6
        WHEN 4923 THEN 10 ELSE 2 END
WHERE q.`RewardItem2` = 0
  AND 400000 NOT IN (q.`RewardItem1`, q.`RewardItem3`, q.`RewardItem4`);

UPDATE `quest_template` q
JOIN `dc_map750_questzone` z ON z.`quest` = q.`ID`
SET q.`RewardItem3` = 400000,
    q.`RewardAmount3` = CASE z.`zone`
        WHEN 4929 THEN 2 WHEN 4930 THEN 2 WHEN 4931 THEN 3
        WHEN 4927 THEN 4 WHEN 4928 THEN 4 WHEN 4926 THEN 6
        WHEN 4923 THEN 10 ELSE 2 END
WHERE q.`RewardItem3` = 0
  AND 400000 NOT IN (q.`RewardItem1`, q.`RewardItem2`, q.`RewardItem4`);

UPDATE `quest_template` q
JOIN `dc_map750_questzone` z ON z.`quest` = q.`ID`
SET q.`RewardItem4` = 400000,
    q.`RewardAmount4` = CASE z.`zone`
        WHEN 4929 THEN 2 WHEN 4930 THEN 2 WHEN 4931 THEN 3
        WHEN 4927 THEN 4 WHEN 4928 THEN 4 WHEN 4926 THEN 6
        WHEN 4923 THEN 10 ELSE 2 END
WHERE q.`RewardItem4` = 0
  AND 400000 NOT IN (q.`RewardItem1`, q.`RewardItem2`, q.`RewardItem3`);

-- ---------------------------------------------------------------------------
-- Trailer -- verification
-- ---------------------------------------------------------------------------
-- Every map-750 quest pays sap exactly once (expect 561 / 0):
-- SELECT COUNT(*) paid FROM quest_template q
-- JOIN dc_map750_questzone z ON z.quest = q.ID
-- WHERE 400000 IN (q.RewardItem1, q.RewardItem2, q.RewardItem3, q.RewardItem4);
-- SELECT COUNT(*) doubled FROM quest_template q
-- JOIN dc_map750_questzone z ON z.quest = q.ID
-- WHERE (q.RewardItem1=400000) + (q.RewardItem2=400000)
--     + (q.RewardItem3=400000) + (q.RewardItem4=400000) > 1;
--
-- Per-zone totals (expect the table in the header, 2,955 overall):
-- SELECT z.zone, COUNT(*) quests,
--        SUM(CASE WHEN q.RewardItem2=400000 THEN q.RewardAmount2
--                 WHEN q.RewardItem3=400000 THEN q.RewardAmount3
--                 WHEN q.RewardItem4=400000 THEN q.RewardAmount4 ELSE 0 END) sap
-- FROM quest_template q JOIN dc_map750_questzone z ON z.quest = q.ID
-- GROUP BY z.zone WITH ROLLUP;
--
-- The token was not displaced (expect 561):
-- SELECT COUNT(*) FROM quest_template q JOIN dc_map750_questzone z ON z.quest = q.ID
-- WHERE 300311 IN (q.RewardItem1, q.RewardItem2, q.RewardItem3, q.RewardItem4);
--
-- No quest lost a pre-existing reward (expect 0):
-- SELECT COUNT(*) FROM quest_template q JOIN dc_map750_questzone z ON z.quest = q.ID
-- WHERE (q.RewardItem1 > 0) + (q.RewardItem2 > 0)
--     + (q.RewardItem3 > 0) + (q.RewardItem4 > 0) < 2;
--
-- ROLLBACK: re-run section A on its own.
-- ---------------------------------------------------------------------------
