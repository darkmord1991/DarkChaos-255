-- ---------------------------------------------------------------------------
-- 253  Map 750 -- visible Upgrade Token rewards on every zone quest
-- ---------------------------------------------------------------------------
-- Tokens were already awarded for quest turn-ins, but invisibly: the
-- ItemUpgradeTokenHooks `OnPlayerCompleteQuest` hook paid them silently and
-- announced it in chat AFTER the fact. This puts them in the quest's
-- "You will receive:" box instead, so the reward is visible when you pick the
-- quest up and when you hand it in.
--
-- >> REQUIRES the matching C++ change (rebuild): the hook now SKIPS any quest
-- >> that grants the token itself (QuestGrantsTokenDirectly), so these rows
-- >> replace the hook payout rather than doubling it. The hook still pays for
-- >> every other quest on the server, and now scales with player level.
--
-- BAND-SCALED, because upgrade costs climb far faster than quest counts do
-- (210 tokens to max a level-80 leveling piece vs 5,500 for a Hyjal-band one):
--
--     zone                     band       tokens/quest   quests   subtotal
--     4929 Darkshore           80-90           20           84      1,680
--     4930 Azshara             80-90           20           56      1,120
--     4931 Ashenvale           88-98           30           94      2,820
--     4927 Felwood             96-106          40          128      5,120
--     4928 Moonglade           sanctuary       40           21        840
--     4926 Winterspring        104-115         55           69      3,795
--     4923 Hyjal Frontier      113-130         75          151     11,325
--                                                       ------------------
--                                                          603     26,700
--
-- ~26.7k tokens across the whole 80->130 run, i.e. roughly 5 fully-maxed
-- tier-4 pieces (5,500 each) from questing alone, on top of 244_'s rare/boss
-- drops. Retune by editing the CASE below and re-running -- section A resets
-- this file's own rows first, so amounts can be changed freely.
--
-- Slot choice: the token goes in the first FREE RewardItem slot. Verified
-- live -- all 603 quests have one (549 free at slot 1, 68 at slot 2, 2 at
-- slot 3, none full), so nothing is displaced. Item 300311 stacks to
-- 99,999,999 and 254_ makes it a real currency, so it costs no bag space.
--
-- The 8 hand-off/breadcrumb quests (81300-81315) carry their own token
-- rewards, written directly into `Level Areas/.../43_breadcrumbs.sql` where
-- those quests are created (that file runs in the other runner, after this).
--
-- Run AFTER 234_ (needs dc_map750_questzone). Idempotent. Worldserver
-- restart or `.reload quest_template` to take effect.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) reset this file's own rows so a re-run can retune the amounts
-- ---------------------------------------------------------------------------
UPDATE `quest_template` q JOIN `dc_map750_questzone` z ON z.`quest` = q.`ID`
SET q.`RewardItem1` = 0, q.`RewardAmount1` = 0 WHERE q.`RewardItem1` = 300311;
UPDATE `quest_template` q JOIN `dc_map750_questzone` z ON z.`quest` = q.`ID`
SET q.`RewardItem2` = 0, q.`RewardAmount2` = 0 WHERE q.`RewardItem2` = 300311;
UPDATE `quest_template` q JOIN `dc_map750_questzone` z ON z.`quest` = q.`ID`
SET q.`RewardItem3` = 0, q.`RewardAmount3` = 0 WHERE q.`RewardItem3` = 300311;
UPDATE `quest_template` q JOIN `dc_map750_questzone` z ON z.`quest` = q.`ID`
SET q.`RewardItem4` = 0, q.`RewardAmount4` = 0 WHERE q.`RewardItem4` = 300311;

-- ---------------------------------------------------------------------------
-- B) award into the first free slot, amount by band
-- ---------------------------------------------------------------------------
UPDATE `quest_template` q JOIN `dc_map750_questzone` z ON z.`quest` = q.`ID`
SET q.`RewardItem1` = 300311,
    q.`RewardAmount1` = CASE z.`zone`
        WHEN 4929 THEN 20 WHEN 4930 THEN 20 WHEN 4931 THEN 30
        WHEN 4927 THEN 40 WHEN 4928 THEN 40 WHEN 4926 THEN 55
        WHEN 4923 THEN 75 ELSE 20 END
WHERE q.`RewardItem1` = 0
  AND q.`RewardItem2` <> 300311 AND q.`RewardItem3` <> 300311 AND q.`RewardItem4` <> 300311;

UPDATE `quest_template` q JOIN `dc_map750_questzone` z ON z.`quest` = q.`ID`
SET q.`RewardItem2` = 300311,
    q.`RewardAmount2` = CASE z.`zone`
        WHEN 4929 THEN 20 WHEN 4930 THEN 20 WHEN 4931 THEN 30
        WHEN 4927 THEN 40 WHEN 4928 THEN 40 WHEN 4926 THEN 55
        WHEN 4923 THEN 75 ELSE 20 END
WHERE q.`RewardItem1` <> 0 AND q.`RewardItem2` = 0
  AND q.`RewardItem1` <> 300311 AND q.`RewardItem3` <> 300311 AND q.`RewardItem4` <> 300311;

UPDATE `quest_template` q JOIN `dc_map750_questzone` z ON z.`quest` = q.`ID`
SET q.`RewardItem3` = 300311,
    q.`RewardAmount3` = CASE z.`zone`
        WHEN 4929 THEN 20 WHEN 4930 THEN 20 WHEN 4931 THEN 30
        WHEN 4927 THEN 40 WHEN 4928 THEN 40 WHEN 4926 THEN 55
        WHEN 4923 THEN 75 ELSE 20 END
WHERE q.`RewardItem1` <> 0 AND q.`RewardItem2` <> 0 AND q.`RewardItem3` = 0
  AND q.`RewardItem1` <> 300311 AND q.`RewardItem2` <> 300311 AND q.`RewardItem4` <> 300311;

UPDATE `quest_template` q JOIN `dc_map750_questzone` z ON z.`quest` = q.`ID`
SET q.`RewardItem4` = 300311,
    q.`RewardAmount4` = CASE z.`zone`
        WHEN 4929 THEN 20 WHEN 4930 THEN 20 WHEN 4931 THEN 30
        WHEN 4927 THEN 40 WHEN 4928 THEN 40 WHEN 4926 THEN 55
        WHEN 4923 THEN 75 ELSE 20 END
WHERE q.`RewardItem1` <> 0 AND q.`RewardItem2` <> 0 AND q.`RewardItem3` <> 0 AND q.`RewardItem4` = 0
  AND q.`RewardItem1` <> 300311 AND q.`RewardItem2` <> 300311 AND q.`RewardItem3` <> 300311;

-- ---------------------------------------------------------------------------
-- Trailer -- verification
-- ---------------------------------------------------------------------------
-- coverage + payout per zone (expect every quest covered, amounts as above):
-- SELECT z.zone, COUNT(*) quests,
--        SUM(300311 IN (q.RewardItem1, q.RewardItem2, q.RewardItem3, q.RewardItem4)) with_token,
--        MAX(GREATEST(IF(q.RewardItem1 = 300311, q.RewardAmount1, 0),
--                     IF(q.RewardItem2 = 300311, q.RewardAmount2, 0),
--                     IF(q.RewardItem3 = 300311, q.RewardAmount3, 0),
--                     IF(q.RewardItem4 = 300311, q.RewardAmount4, 0))) amount
-- FROM quest_template q JOIN dc_map750_questzone z ON z.quest = q.ID GROUP BY z.zone;
-- nobody got it twice (expect 0):
-- SELECT COUNT(*) FROM quest_template q JOIN dc_map750_questzone z ON z.quest = q.ID
-- WHERE (q.RewardItem1 = 300311) + (q.RewardItem2 = 300311)
--     + (q.RewardItem3 = 300311) + (q.RewardItem4 = 300311) > 1;
-- no quest left without a token (expect 0):
-- SELECT COUNT(*) FROM quest_template q JOIN dc_map750_questzone z ON z.quest = q.ID
-- WHERE 300311 NOT IN (q.RewardItem1, q.RewardItem2, q.RewardItem3, q.RewardItem4);
-- In-game: pick up any Hyjal quest -- the reward box must show 75 Upgrade
-- Tokens, and turning it in must NOT also print the "+N Upgrade Tokens" chat
-- line (that would mean the C++ rebuild is missing).
