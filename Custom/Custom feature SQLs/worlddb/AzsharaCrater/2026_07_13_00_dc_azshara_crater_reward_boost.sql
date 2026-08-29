-- ============================================================================
-- Azshara Crater - Quest Reward Boost (more XP, more gold, better items)
-- Date: 2026-07-13
-- Scope: all 112 Azshara Crater custom quests (QuestSortID 268, ID 300100-300966)
-- ----------------------------------------------------------------------------
-- Player request: "for all Azshara Crater quests we need better rewards -
--                  more xp, more gold, better items."
--
--   XP    : RewardXPDifficulty -> 6 (was 3-5). QuestXP.dbc column 6 is roughly
--           2-2.5x the previous per-quest XP (column 8 is the max; left as
--           headroom per the chosen "strong but moderate" boost).
--   Gold   : RewardMoneyDifficulty -> 6. Puts level-scaled coin on every quest
--            (most previously rewarded 0 gold). Approx: ~7s @L10, ~55s @L30,
--            ~1g80s @L60, ~14g80s @L80. Overrides the old flat bounty coin,
--            which was always lower at the same level.
--   Items  : Choice accessories upgraded to validated RARE (blue) items per
--            level tier, keeping the choose-your-role layout (physical/caster
--            rings, necks, and trinkets). The guaranteed cloak is kept where it
--            is already epic (tiers 51-80: 23030 / 32524 / 50668) so nothing is
--            downgraded. Rewards are re-tiered by QuestLevel, which also repairs
--            the mis-tiered 300400 block (lvl 34-53) that shared level-40 gear.
--
-- Every item id below was validated in item_template: Quality 3 (blue) where a
-- blue exists for the slot/level, non-unique (MaxCount = 0), all-class
-- (AllowableClass = -1), all-race (AllowableRace = -1), correct InventoryType,
-- and RequiredLevel within its tier. Tiers with no qualifying blue (all of
-- 1-10; necks 11-20; trinkets 31-40) keep their existing item rather than
-- regressing to nothing. These quests are one-time (Flags = 0), so the boosted
-- rewards are not farmable.
-- ============================================================================

-- ---- XP + Gold -------------------------------------------------------------
UPDATE `quest_template`
SET `RewardXPDifficulty` = 6,
    `RewardMoneyDifficulty` = 6
WHERE `QuestSortID` = 268
    AND `ID` BETWEEN 300100 AND 300966;

-- ---- Better items (rare/blue, tiered by QuestLevel) ------------------------
UPDATE `quest_template`
SET
    `RewardItem1` = CASE
        WHEN `ID` = 300100 THEN 300365            -- Heirloom Adventurer's Shirt (intro quest)
        WHEN `QuestLevel` BETWEEN 1 AND 10 THEN 6542   -- Willow Cape (no blue cloak < req20)
        WHEN `QuestLevel` BETWEEN 11 AND 20 THEN 6314  -- Wolfmaster Cape (blue)
        WHEN `QuestLevel` BETWEEN 21 AND 30 THEN 13108 -- Tigerstrike Mantle (blue)
        WHEN `QuestLevel` BETWEEN 31 AND 40 THEN 11311 -- Emberscale Cape (blue)
        WHEN `QuestLevel` BETWEEN 41 AND 50 THEN 14134 -- Cloak of Fire (blue)
        WHEN `QuestLevel` BETWEEN 51 AND 60 THEN 23030 -- Cloak of the Scourge (epic - kept)
        WHEN `QuestLevel` BETWEEN 61 AND 70 THEN 32524 -- Shroud of the Highborne (epic - kept)
        WHEN `QuestLevel` BETWEEN 71 AND 80 THEN 50668 -- Greatcloak of the Turned Champion (epic - kept)
        ELSE `RewardItem1`
    END,
    `RewardAmount1` = 1,
    `RewardChoiceItemID1` = CASE               -- physical/melee/tank ring
        WHEN `QuestLevel` BETWEEN 1 AND 10 THEN 20906  -- Braided Copper Ring (no blue < req20)
        WHEN `QuestLevel` BETWEEN 11 AND 20 THEN 1491  -- Ring of Precision
        WHEN `QuestLevel` BETWEEN 21 AND 30 THEN 7686  -- Ironspine's Eye
        WHEN `QuestLevel` BETWEEN 31 AND 40 THEN 29158 -- Truesilver Commander's Ring
        WHEN `QuestLevel` BETWEEN 41 AND 50 THEN 1447  -- Ring of Saviors (epic - kept)
        WHEN `QuestLevel` BETWEEN 51 AND 60 THEN 2246  -- Myrmidon's Signet (epic - kept)
        WHEN `QuestLevel` BETWEEN 61 AND 70 THEN 37751 -- Tooga's Lost Toenail
        WHEN `QuestLevel` BETWEEN 71 AND 80 THEN 37151 -- Band of Frosted Thorns
        ELSE `RewardChoiceItemID1`
    END,
    `RewardChoiceItemID2` = CASE               -- caster/healer ring
        WHEN `QuestLevel` BETWEEN 1 AND 10 THEN 21931  -- Woven Copper Ring (no blue < req20)
        WHEN `QuestLevel` BETWEEN 11 AND 20 THEN 6463  -- Deep Fathom Ring
        WHEN `QuestLevel` BETWEEN 21 AND 30 THEN 6693  -- Agamaggan's Clutch
        WHEN `QuestLevel` BETWEEN 31 AND 40 THEN 2951  -- Ring of the Underwood
        WHEN `QuestLevel` BETWEEN 41 AND 50 THEN 5266  -- Eye of Adaegus
        WHEN `QuestLevel` BETWEEN 51 AND 60 THEN 24154 -- Witching Band
        WHEN `QuestLevel` BETWEEN 61 AND 70 THEN 27491 -- Signet of Repose
        WHEN `QuestLevel` BETWEEN 71 AND 80 THEN 37232 -- Ring of the Traitor King
        ELSE `RewardChoiceItemID2`
    END,
    `RewardChoiceItemID3` = CASE               -- physical neck
        WHEN `QuestLevel` BETWEEN 1 AND 10 THEN 25438  -- Malachite Pendant (no blue neck < req30)
        WHEN `QuestLevel` BETWEEN 11 AND 20 THEN 21934 -- Ornate Tigerseye Necklace (no blue neck < req30)
        WHEN `QuestLevel` BETWEEN 21 AND 30 THEN 44213 -- Darkmoon Pendant
        WHEN `QuestLevel` BETWEEN 31 AND 40 THEN 13088 -- Gazlowe's Charm
        WHEN `QuestLevel` BETWEEN 41 AND 50 THEN 13089 -- Skibi's Pendant
        WHEN `QuestLevel` BETWEEN 51 AND 60 THEN 24073 -- Garrote-String Necklace
        WHEN `QuestLevel` BETWEEN 61 AND 70 THEN 27779 -- Bone Chain Necklace
        WHEN `QuestLevel` BETWEEN 71 AND 80 THEN 45206 -- Choker of Feral Fury
        ELSE `RewardChoiceItemID3`
    END,
    `RewardChoiceItemID4` = CASE               -- caster/healer neck
        WHEN `QuestLevel` BETWEEN 1 AND 10 THEN 21934  -- Ornate Tigerseye Necklace (no blue neck < req30)
        WHEN `QuestLevel` BETWEEN 11 AND 20 THEN 25438 -- Malachite Pendant (no blue neck < req30)
        WHEN `QuestLevel` BETWEEN 21 AND 30 THEN 44215 -- Darkmoon Necklace
        WHEN `QuestLevel` BETWEEN 31 AND 40 THEN 7722  -- Triune Amulet
        WHEN `QuestLevel` BETWEEN 41 AND 50 THEN 17707 -- Gemshard Heart
        WHEN `QuestLevel` BETWEEN 51 AND 60 THEN 24096 -- Heartblood Prayer Beads
        WHEN `QuestLevel` BETWEEN 61 AND 70 THEN 37748 -- Winterfall's Frozen Necklace
        WHEN `QuestLevel` BETWEEN 71 AND 80 THEN 43404 -- Zuramat's Necklace
        ELSE `RewardChoiceItemID4`
    END,
    `RewardChoiceItemID5` = CASE               -- physical trinket (tiers 31-80)
        WHEN `QuestLevel` BETWEEN 31 AND 40 THEN 5079  -- Cold Basilisk Eye (no blue trinket at 31-40)
        WHEN `QuestLevel` BETWEEN 41 AND 50 THEN 45631 -- High-powered Flashlight
        WHEN `QuestLevel` BETWEEN 51 AND 60 THEN 11815 -- Hand of Justice (kept - iconic phys trinket)
        WHEN `QuestLevel` BETWEEN 61 AND 70 THEN 29179 -- Xi'ri's Gift
        WHEN `QuestLevel` BETWEEN 71 AND 80 THEN 37723 -- Incisor Fragment
        ELSE 0
    END,
    `RewardChoiceItemID6` = CASE               -- caster/healer trinket (tiers 31-80)
        WHEN `QuestLevel` BETWEEN 31 AND 40 THEN 2802  -- Blazing Emblem (no blue trinket at 31-40)
        WHEN `QuestLevel` BETWEEN 41 AND 50 THEN 7734  -- Six Demon Bag
        WHEN `QuestLevel` BETWEEN 51 AND 60 THEN 11832 -- Burst of Knowledge (kept - caster trinket)
        WHEN `QuestLevel` BETWEEN 61 AND 70 THEN 28418 -- Shiffar's Nexus-Horn
        WHEN `QuestLevel` BETWEEN 71 AND 80 THEN 37264 -- Pendulum of Telluric Currents
        ELSE 0
    END,
    `RewardChoiceItemQuantity1` = 1,
    `RewardChoiceItemQuantity2` = 1,
    `RewardChoiceItemQuantity3` = 1,
    `RewardChoiceItemQuantity4` = 1,
    `RewardChoiceItemQuantity5` = CASE WHEN `QuestLevel` BETWEEN 31 AND 80 THEN 1 ELSE 0 END,
    `RewardChoiceItemQuantity6` = CASE WHEN `QuestLevel` BETWEEN 31 AND 80 THEN 1 ELSE 0 END
WHERE `QuestSortID` = 268
    AND `ID` BETWEEN 300100 AND 300966
    -- 300100 opted out 2026-08-29: its rewards are owned by
    -- 2026_08_29_00_dc_take_up_the_watch_level1_rewards.sql (level-1 reward clones
    -- 303140-303143, and no heirloom shirt - 820058 grants that one). Re-running this
    -- sweep without the exclusion would restore both. The `WHEN ID = 300100 THEN 300365`
    -- branch in the `RewardItem1` CASE above is now unreachable and kept only as history.
    AND `ID` <> 300100;
