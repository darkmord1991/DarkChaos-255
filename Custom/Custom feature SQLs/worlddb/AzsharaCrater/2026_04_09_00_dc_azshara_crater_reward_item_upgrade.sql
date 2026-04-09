-- Enhance Azshara Crater quest rewards with stronger, level-tiered items.
-- Scope: all Azshara Crater quests in the custom ID range.
-- Reward items chosen from unrestricted, non-unique items validated via ACMCP.
-- Adds class-flavored accessory choices by tier (rings/necks/trinkets).

UPDATE `quest_template`
SET
    `RewardItem1` = CASE
        WHEN `QuestLevel` BETWEEN 1 AND 10 THEN 6542   -- Willow Cape (Req 10)
        WHEN `QuestLevel` BETWEEN 11 AND 20 THEN 6314  -- Wolfmaster Cape (Req 20)
        WHEN `QuestLevel` BETWEEN 21 AND 30 THEN 13108 -- Tigerstrike Mantle (Req 29)
        WHEN `QuestLevel` BETWEEN 31 AND 40 THEN 11311 -- Emberscale Cape (Req 40)
        WHEN `QuestLevel` BETWEEN 41 AND 50 THEN 14134 -- Cloak of Fire (Req 50)
        WHEN `QuestLevel` BETWEEN 51 AND 60 THEN 23030 -- Cloak of the Scourge (Req 60)
        WHEN `QuestLevel` BETWEEN 61 AND 70 THEN 32524 -- Shroud of the Highborne (Req 70)
        WHEN `QuestLevel` BETWEEN 71 AND 80 THEN 50668 -- Greatcloak of the Turned Champion (Req 80)
        ELSE `RewardItem1`
    END,
    `RewardAmount1` = CASE
        WHEN `QuestLevel` BETWEEN 1 AND 80 THEN 1
        ELSE `RewardAmount1`
    END,
    `RewardItem2` = 300311,
    `RewardAmount2` = CASE
        WHEN `QuestLevel` BETWEEN 1 AND 10 THEN 3
        WHEN `QuestLevel` BETWEEN 11 AND 20 THEN 5
        WHEN `QuestLevel` BETWEEN 21 AND 30 THEN 8
        WHEN `QuestLevel` BETWEEN 31 AND 40 THEN 12
        WHEN `QuestLevel` BETWEEN 41 AND 50 THEN 18
        WHEN `QuestLevel` BETWEEN 51 AND 60 THEN 24
        WHEN `QuestLevel` BETWEEN 61 AND 70 THEN 30
        WHEN `QuestLevel` BETWEEN 71 AND 80 THEN 40
        ELSE `RewardAmount2`
    END,
    `RewardItem3` = 300312,
    `RewardAmount3` = CASE
        WHEN `QuestLevel` BETWEEN 1 AND 10 THEN 2
        WHEN `QuestLevel` BETWEEN 11 AND 20 THEN 4
        WHEN `QuestLevel` BETWEEN 21 AND 30 THEN 6
        WHEN `QuestLevel` BETWEEN 31 AND 40 THEN 8
        WHEN `QuestLevel` BETWEEN 41 AND 50 THEN 12
        WHEN `QuestLevel` BETWEEN 51 AND 60 THEN 16
        WHEN `QuestLevel` BETWEEN 61 AND 70 THEN 20
        WHEN `QuestLevel` BETWEEN 71 AND 80 THEN 28
        ELSE `RewardAmount3`
    END,
    `RewardChoiceItemID1` = CASE
        WHEN `QuestLevel` BETWEEN 1 AND 10 THEN 20906  -- Melee/Tank ring
        WHEN `QuestLevel` BETWEEN 11 AND 20 THEN 1189
        WHEN `QuestLevel` BETWEEN 21 AND 30 THEN 13094
        WHEN `QuestLevel` BETWEEN 31 AND 40 THEN 13093
        WHEN `QuestLevel` BETWEEN 41 AND 50 THEN 1447
        WHEN `QuestLevel` BETWEEN 51 AND 60 THEN 2246
        WHEN `QuestLevel` BETWEEN 61 AND 70 THEN 31238
        WHEN `QuestLevel` BETWEEN 71 AND 80 THEN 44683
        ELSE 0
    END,
    `RewardChoiceItemID2` = CASE
        WHEN `QuestLevel` BETWEEN 1 AND 10 THEN 21931  -- Caster/Healer ring
        WHEN `QuestLevel` BETWEEN 11 AND 20 THEN 11965
        WHEN `QuestLevel` BETWEEN 21 AND 30 THEN 2039
        WHEN `QuestLevel` BETWEEN 31 AND 40 THEN 2951
        WHEN `QuestLevel` BETWEEN 41 AND 50 THEN 10634
        WHEN `QuestLevel` BETWEEN 51 AND 60 THEN 13283
        WHEN `QuestLevel` BETWEEN 61 AND 70 THEN 25962
        WHEN `QuestLevel` BETWEEN 71 AND 80 THEN 43277
        ELSE 0
    END,
    `RewardChoiceItemID3` = CASE
        WHEN `QuestLevel` BETWEEN 1 AND 10 THEN 25438  -- Physical neck
        WHEN `QuestLevel` BETWEEN 11 AND 20 THEN 21934
        WHEN `QuestLevel` BETWEEN 21 AND 30 THEN 20909
        WHEN `QuestLevel` BETWEEN 31 AND 40 THEN 12020
        WHEN `QuestLevel` BETWEEN 41 AND 50 THEN 13089
        WHEN `QuestLevel` BETWEEN 51 AND 60 THEN 13002
        WHEN `QuestLevel` BETWEEN 61 AND 70 THEN 31194
        WHEN `QuestLevel` BETWEEN 71 AND 80 THEN 44688
        ELSE 0
    END,
    `RewardChoiceItemID4` = CASE
        WHEN `QuestLevel` BETWEEN 1 AND 10 THEN 21934  -- Caster/Healer neck
        WHEN `QuestLevel` BETWEEN 11 AND 20 THEN 25438
        WHEN `QuestLevel` BETWEEN 21 AND 30 THEN 12047
        WHEN `QuestLevel` BETWEEN 31 AND 40 THEN 20967
        WHEN `QuestLevel` BETWEEN 41 AND 50 THEN 9641
        WHEN `QuestLevel` BETWEEN 51 AND 60 THEN 18340
        WHEN `QuestLevel` BETWEEN 61 AND 70 THEN 31196
        WHEN `QuestLevel` BETWEEN 71 AND 80 THEN 35631
        ELSE 0
    END,
    `RewardChoiceItemID5` = CASE
        WHEN `QuestLevel` BETWEEN 31 AND 40 THEN 5079   -- Physical trinket
        WHEN `QuestLevel` BETWEEN 41 AND 50 THEN 11302
        WHEN `QuestLevel` BETWEEN 51 AND 60 THEN 11815
        WHEN `QuestLevel` BETWEEN 61 AND 70 THEN 24376
        WHEN `QuestLevel` BETWEEN 71 AND 80 THEN 38359
        ELSE 0
    END,
    `RewardChoiceItemID6` = CASE
        WHEN `QuestLevel` BETWEEN 31 AND 40 THEN 2802   -- Caster/Healer trinket
        WHEN `QuestLevel` BETWEEN 41 AND 50 THEN 7734
        WHEN `QuestLevel` BETWEEN 51 AND 60 THEN 11832
        WHEN `QuestLevel` BETWEEN 61 AND 70 THEN 24390
        WHEN `QuestLevel` BETWEEN 71 AND 80 THEN 38358
        ELSE 0
    END,
    `RewardChoiceItemQuantity1` = CASE
        WHEN `QuestLevel` BETWEEN 1 AND 80 THEN 1
        ELSE 0
    END,
    `RewardChoiceItemQuantity2` = CASE
        WHEN `QuestLevel` BETWEEN 1 AND 80 THEN 1
        ELSE 0
    END,
    `RewardChoiceItemQuantity3` = CASE
        WHEN `QuestLevel` BETWEEN 1 AND 80 THEN 1
        ELSE 0
    END,
    `RewardChoiceItemQuantity4` = CASE
        WHEN `QuestLevel` BETWEEN 1 AND 80 THEN 1
        ELSE 0
    END,
    `RewardChoiceItemQuantity5` = CASE
        WHEN `QuestLevel` BETWEEN 31 AND 80 THEN 1
        ELSE 0
    END,
    `RewardChoiceItemQuantity6` = CASE
        WHEN `QuestLevel` BETWEEN 31 AND 80 THEN 1
        ELSE 0
    END
WHERE `ID` BETWEEN 300100 AND 300966
  AND `QuestSortID` = 268;
