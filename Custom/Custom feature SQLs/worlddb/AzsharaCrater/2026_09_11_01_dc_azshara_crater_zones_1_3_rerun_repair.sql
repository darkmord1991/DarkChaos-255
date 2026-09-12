-- ---------------------------------------------------------------------------
-- Azshara Crater (map 37) -- REPAIR after 2026_01_09_00_..._zones_1_3.sql was re-run
-- ---------------------------------------------------------------------------
-- On 2026-09-11 the January zones 1-3 file was re-applied to the live world DB.
-- That file predates this fork's schema, and it ran past its own errors:
--
--   1. `DELETE FROM creature_template WHERE entry = ...` succeeded, then every
--      INSERT failed on `scale` (moved to creature_template_model.DisplayScale)
--      -> the six zone 1-3 NPC templates were DELETED. Their spawns still exist.
--   2. `DELETE FROM creature_template_model WHERE CreatureID IN (300000, ...)`
--      also took Cromi (300000), whose model the file never re-inserts.
--   3. `DELETE FROM quest_template WHERE ID BETWEEN 300100 AND 300308` + INSERT
--      succeeded -> all 27 zone 1-3 quests reverted to January: January titles and
--      text, January rewards, 300205 at the old level, and 300208 pointing back at
--      Corrupt Water Spirit 5897, which has no spawn on map 37.
--   4. quest_offer_reward / quest_request_items for those quests: January text.
--
-- Not damaged, verified live after the run: zones 4-8 templates and quests,
-- all quest_poi rows, quest giver links (re-inserted identically), npc_text /
-- gossip_menu (re-inserted with the same text), and dc_seasonal_quest_rewards
-- (rewritten with the same January-era amounts every other crater row still has).
--
-- HOW THIS FILE WAS BUILT -- there is no DB backup of the crater (acore_backup
-- holds no quest 3001xx rows), so state is rebuilt from the repo:
--   * creature_template: the January values, mapped to this fork's 55 columns
--     (`scale` dropped -- the scales already live in creature_template_model;
--     `mechanic_immune_mask` + `spell_school_immune_mask` -> CreatureImmunitiesId 0).
--     npcflag 3 / faction 35 / unit_flags 768 / flags_extra 2 / empty AIName and
--     ScriptName were checked against a live read taken earlier the same day,
--     BEFORE the re-run. That read is why Elder Greymane gets no AIName/ScriptName:
--     live had neither (the January 'SmartAI' / npc_elder_greymane_escort has no
--     smart_scripts rows and no C++ script behind it).
--     KillCredit1 is 0, not the January 268: that value was a QuestSortID pasted
--     into the wrong column (it pointed at an unrelated NPC, Sirra Von'Indi).
--     Model rows are NOT touched: the re-run re-inserted the January display ids,
--     and no later file ever changed them.
--   * Cromi 300000 model: the row from acore_backup (display 24877, scale 1).
--   * quest_template / quest texts: every later pass, replayed in its original
--     order, statements copied verbatim from the source files with the ID range
--     narrowed to 300100-300308 so quests 300400+ are not touched:
--       2026_04_09_01 (300205 level) -> 2026_04_09_00 (reward items) ->
--       2026_04_09_02 (300208 target) -> 2026_07_13_00 (XP/gold/items) ->
--       2026_07_14_00 (lore text) -> 2026_08_29_00 (300100 rewards).
--     The replayed result was checked against the same pre-run live read: all 27
--     titles, QuestLevel/MinLevel, objectives + counts, RewardItem1/Amount1,
--     RewardItem2, RewardChoiceItemID1 and XP difficulty match.
--
-- NOT recoverable from anything on disk: a direct edit made to these 27 quests
-- or 6 NPCs in the live DB that never went into a repo file. If you keep your own
-- dumps, a diff against one is the only way to catch that.
--
-- Apply this file, THEN 2026_09_11_00_dc_azshara_crater_quest_relation_restore.sql.
-- Restart the worldserver afterwards: creature_template has no .reload command.
-- Do NOT restart before applying -- the six quest givers would load without a
-- template and vanish from the crater.
--
-- Verify (expect 6 templates, 7 model rows, and the titles/levels listed):
--   SELECT entry, name, npcflag, faction FROM creature_template
--    WHERE entry IN (300001, 300002, 300010, 300011, 300020, 300021);
--   SELECT CreatureID, CreatureDisplayID FROM creature_template_model
--    WHERE CreatureID IN (300000, 300001, 300002, 300010, 300011, 300020, 300021);
--   SELECT ID, LogTitle, QuestLevel, MinLevel, RequiredNpcOrGo1, RewardItem1,
--          RewardAmount1, RewardItem2, RewardChoiceItemID1, RewardXPDifficulty
--     FROM quest_template WHERE ID BETWEEN 300100 AND 300308;
--   -> 300100 'Take Up the Watch' 1/1, RewardItem1 300311 x3, choice 303140
--   -> 300205 'Varo''then''s Journal' 15/11; 300208 'Poisoned Waters' target 17358
--   -> 3001xx RewardItem1 6542 / choice 20906; 3002xx 6314 / 1491; 3003xx 13108 / 7686
--   -> RewardXPDifficulty 6 on all 27
-- ---------------------------------------------------------------------------

-- 1. Zone 1-3 quest giver templates
DELETE FROM `creature_template` WHERE `entry` IN (300001, 300002, 300010, 300011, 300020, 300021);
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(300001, 0, 0, 0, 0, 0, 'Scout Thalindra', 'Crater Reconnaissance', 'quest', 300001, 10, 10, 0, 35, 3, 1, 1.14286, 1, 1, 20, 0, 0, 1, 2000, 2000, 1, 1, 2, 768, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 1.5, 1, 1, 1, 0, 0, 1, 0, 2, '', 12340), -- Scout Thalindra (zone 1)
(300002, 0, 0, 0, 0, 0, 'Warden Stonebrook', 'Rare Beast Hunter', 'quest', 300002, 12, 12, 0, 35, 3, 1, 1.14286, 1, 1, 20, 0, 0, 1, 2000, 2000, 1, 1, 1, 768, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 2, 1, 1, 1, 0, 0, 1, 0, 2, '', 12340), -- Warden Stonebrook (zone 1)
(300010, 0, 0, 0, 0, 0, 'Arcanist Melia', 'Kirin Tor Researcher', 'quest', 300010, 20, 20, 0, 35, 3, 1, 1.14286, 1, 1, 20, 0, 0, 1, 2000, 2000, 1, 1, 8, 768, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 1.5, 2, 1, 1, 0, 0, 1, 0, 2, '', 12340), -- Arcanist Melia (zone 2)
(300011, 0, 0, 0, 0, 0, 'Spirit of Kelvenar', 'Echo of the Past', 'quest', 300011, 20, 20, 0, 35, 3, 1, 1.14286, 1, 1, 20, 0, 0, 1, 2000, 2000, 1, 1, 8, 768, 2048, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 1, 1, 0.5, 1, 0, 0, 1, 0, 2, '', 12340), -- Spirit of Kelvenar (zone 2)
(300020, 0, 0, 0, 0, 0, 'Pathfinder Gor''nash', 'Eastern Outpost Scout', 'quest', 300020, 30, 30, 0, 35, 3, 1, 1.14286, 1, 1, 20, 0, 0, 1, 2000, 2000, 1, 1, 1, 768, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 2, 1, 1.5, 1, 0, 0, 1, 0, 2, '', 12340), -- Pathfinder Gor'nash (zone 3)
(300021, 0, 0, 0, 0, 0, 'Elder Greymane', 'Thistlefur Prisoner', 'quest', 0, 28, 28, 0, 35, 3, 1, 1.14286, 1, 1, 20, 0, 0, 1, 2000, 2000, 1, 1, 2, 768, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 3, 1, 1, 1, 0, 0, 1, 0, 2, '', 12340); -- Elder Greymane (zone 3)

-- 2. Cromi's model row (removed by the re-run's model DELETE)
DELETE FROM `creature_template_model` WHERE `CreatureID` = 300000;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(300000, 0, 24877, 1, 1, NULL);

-- 3. Quest replay -- 2026_04_09_01: 300205 level alignment
UPDATE `quest_template` SET `QuestLevel` = 15, `MinLevel` = 11 WHERE `ID` = 300205 AND `QuestSortID` = 268;

-- 4. Quest replay -- 2026_04_09_00: reward item upgrade (narrowed to 300100-300308)
UPDATE `quest_template`
SET
    `RewardItem1` = CASE
        WHEN `ID` = 300100 THEN 300365            -- Heirloom Adventurer's Shirt (Welcome to Crater)
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
WHERE `ID` BETWEEN 300100 AND 300308
  AND `QuestSortID` = 268;

-- 5. Quest replay -- 2026_04_09_02: Corrupt Water Spirit 5897 -> Fouled Water Spirit 17358
UPDATE `quest_template` SET `RequiredNpcOrGo1` = 17358 WHERE `ID` = 300208 AND `RequiredNpcOrGo1` = 5897;

-- 6. Quest replay -- 2026_07_13_00: reward boost (narrowed to 300100-300308)
UPDATE `quest_template`
SET `RewardXPDifficulty` = 6,
    `RewardMoneyDifficulty` = 6
WHERE `QuestSortID` = 268
    AND `ID` BETWEEN 300100 AND 300308;

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
    AND `ID` BETWEEN 300100 AND 300308
    -- 300100 opted out 2026-08-29: its rewards are owned by
    -- 2026_08_29_00_dc_take_up_the_watch_level1_rewards.sql (level-1 reward clones
    -- 303140-303143, and no heirloom shirt - 820058 grants that one). Re-running this
    -- sweep without the exclusion would restore both. The `WHEN ID = 300100 THEN 300365`
    -- branch in the `RewardItem1` CASE above is now unreachable and kept only as history.
    AND `ID` <> 300100;

-- 7. Quest replay -- 2026_07_14_00: lore text pass, quests 300100-300308
UPDATE `quest_template` SET `LogTitle` = 'Take Up the Watch', `LogDescription` = 'Ready yourself for duty with Scout Thalindra at the outpost.', `QuestDescription` = 'Stay your step, $N, and keep your voice low. This crater is no meadow to wander. When the Well of Eternity broke the world, it left this bowl drowning in wild magic, and that magic pulls all manner of hungering things down into it.$B$BStill, we hold. A handful of Sentinels, one stubborn dwarf, and now you. Take this supply bag and ready yourself. If you mean to earn a place at this outpost, I will find work enough for a $C of your mettle.', `AreaDescription` = 'Azshara Crater', `QuestCompletionLog` = 'You stand ready for duty.' WHERE `ID` = 300100;
UPDATE `quest_offer_reward` SET `RewardText` = 'Good. Elune knows we need every willing hand. This crater teems with things that would see our tents burned by morning. Keep your blade close, $N, and your eyes closer.' WHERE `ID` = 300100;
UPDATE `quest_request_items` SET `CompletionText` = 'Have you spoken to Scout Thalindra yet?' WHERE `ID` = 300100;
UPDATE `quest_template` SET `LogTitle` = 'Fang and Tusk', `LogDescription` = 'Slay 6 Young Thistle Boars and 6 Mangy Wolves.', `QuestDescription` = 'Ye want to be useful, $N? Then start with the beasts. The boars have gone mean and the wolves bolder still, all of ''em stirred wrong by whatever sours the air down here.$B$BGo thin ''em out. Six o'' the young thistle boars and six o'' the mangy wolves ought to give the camp room to breathe. A hunter earns respect one clean kill at a time.', `AreaDescription` = 'Azshara Crater', `QuestCompletionLog` = 'The boars and wolves have been thinned.' WHERE `ID` = 300101;
UPDATE `quest_offer_reward` SET `RewardText` = 'Aye, that''s the way of it. The camp''s a sight safer with those beasts culled. Good huntin'', $N.' WHERE `ID` = 300101;
UPDATE `quest_request_items` SET `CompletionText` = 'Those beasts still prowl the camp''s edge. Have ye thinned their numbers?' WHERE `ID` = 300101;
UPDATE `quest_template` SET `LogTitle` = 'Bears at the Larder', `LogDescription` = 'Slay 8 Young Forest Bears.', `QuestDescription` = 'Bears, $N. Great shaggy thieves, the lot of ''em. They''ve caught the scent of our stores, and now they''ll not leave off till the larder''s bare.$B$BPut down eight o'' the young forest bears prowlin'' near the outpost. Do it clean, and there''s silver waitin'' for ye.', `AreaDescription` = 'Azshara Crater', `QuestCompletionLog` = 'The forest bears have been driven off.' WHERE `ID` = 300102;
UPDATE `quest_offer_reward` SET `RewardText` = 'Hah! That''ll learn ''em to raid a dwarf''s larder. Here now, take yer pay, $N. Ye earned every bit of it.' WHERE `ID` = 300102;
UPDATE `quest_request_items` SET `CompletionText` = 'I still spy bears sniffin'' round the stores. See to ''em.' WHERE `ID` = 300102;
UPDATE `quest_template` SET `LogTitle` = 'Restless Timberlings', `LogDescription` = 'Slay 8 Timberlings.', `QuestDescription` = 'Have you marked the little tree-things that walk the underbrush, $N? Timberlings, we name them, saplings given a crude and clumsy life. They should be harmless. They are not.$B$BSomething in the crater''s wild magic has set them stirring wrong. Fell eight of them, and I will study what quickens their sap. Knowledge is a Sentinel''s first weapon.', `AreaDescription` = 'Azshara Crater', `QuestCompletionLog` = 'The Timberlings have been felled.' WHERE `ID` = 300103;
UPDATE `quest_offer_reward` SET `RewardText` = 'Fascinating... the sap fairly crackles with unspent magic. This crater changes even the gentlest of growing things. I have much to consider.' WHERE `ID` = 300103;
UPDATE `quest_request_items` SET `CompletionText` = 'I still need the essence of those Timberlings. Have you felled them?' WHERE `ID` = 300103;
UPDATE `quest_template` SET `LogTitle` = 'The Webwood Ridge', `LogDescription` = 'Slay 10 Webwood Lurkers.', `QuestDescription` = 'The northern ridge crawls, $N. Webwood lurkers have spun their nests thick across the rocks, and each day they creep a little nearer the outpost.$B$BI will not have my scouts wrapped in silk before they can cry a warning. Burn them out, ten of the lurkers and no fewer, and the ridge is ours again.', `AreaDescription` = 'Azshara Crater', `QuestCompletionLog` = 'The Webwood Lurkers have been cleared.' WHERE `ID` = 300104;
UPDATE `quest_offer_reward` SET `RewardText` = 'The ridge is quiet again. Well done, $N. One less dark path for the crater to send its horrors through.' WHERE `ID` = 300104;
UPDATE `quest_request_items` SET `CompletionText` = 'The lurkers still hold the ridge. Return when it is clear.' WHERE `ID` = 300104;
UPDATE `quest_template` SET `LogTitle` = 'What Stirs the Grove', `LogDescription` = 'Defeat 12 Timberlings.', `QuestDescription` = 'The Timberlings do not simply wander, $N. They gather, they turn, as though some old will bends them to a single purpose. I would know what wakes beneath this grove.$B$BStrike down twelve of them. Cut deep enough into their number, and whatever commands them may show itself. Be ready if it does.', `AreaDescription` = 'Azshara Crater', `QuestCompletionLog` = 'You have thinned the Timberlings'' ranks.' WHERE `ID` = 300105;
UPDATE `quest_offer_reward` SET `RewardText` = 'You faced them and returned whole? Then perhaps this crater has not yet swallowed our hopes after all. You have earned my trust, $N. It is not given lightly.' WHERE `ID` = 300105;
UPDATE `quest_request_items` SET `CompletionText` = 'The grove still stirs. Do not return until their ranks are broken.' WHERE `ID` = 300105;
UPDATE `quest_template` SET `LogTitle` = 'The Northern Pass', `LogDescription` = 'Travel to the northern checkpoint and survey the area.', `QuestDescription` = 'You have proven steady, $N, and I have need of steady eyes. If this outpost is ever to grow, we must know what waits along the northern pass before we set a single tent there.$B$BTravel to the northern checkpoint and mark what you find. Tracks, nests, anything that moves. Come back with more than guesses.', `AreaDescription` = 'Azshara Crater', `QuestCompletionLog` = 'You have surveyed the northern pass.' WHERE `ID` = 300106;
UPDATE `quest_offer_reward` SET `RewardText` = 'The pass is clear enough to hold? Good. Then we push north. You have won this outpost its next foothold, $N.' WHERE `ID` = 300106;
UPDATE `quest_request_items` SET `CompletionText` = 'Have you reached the northern checkpoint?' WHERE `ID` = 300106;
UPDATE `quest_template` SET `LogTitle` = 'Hides Against the Cold', `LogDescription` = 'Collect 8 Light Hides.', `QuestDescription` = 'Nights bite hard down in this bowl, $N, and half the camp''s beddin'' is little more than rags. Won''t do. Cold soldiers make slow ones, and slow ones make dead ones.$B$BThe wolves hereabouts carry good hide. Bring me eight light hides off ''em, and we''ll have folk sleepin'' warm before the frost sets in.', `AreaDescription` = 'Azshara Crater', `QuestCompletionLog` = 'You have gathered 8 Light Hides.' WHERE `ID` = 300107;
UPDATE `quest_offer_reward` SET `RewardText` = 'Aye, that''s fine hide, thick and warm. The camp''ll thank ye come nightfall, and so do I. Well done, $N.' WHERE `ID` = 300107;
UPDATE `quest_request_items` SET `CompletionText` = 'Still short on hides. Winter won''t wait for ye, $N.' WHERE `ID` = 300107;
UPDATE `quest_template` SET `LogTitle` = 'Tide of Murlocs', `LogDescription` = 'Slay 10 Murloc Foragers along the coast.', `QuestDescription` = 'The Sundering reshaped even this shore, $N, and the murlocs were quick to claim it. Now their foragers slink up along our supply lines and haul off whatever they can carry.$B$BDrive ten of the murloc foragers back into the surf. Let them learn this crater is not theirs to pick clean.', `AreaDescription` = 'Azshara Crater', `QuestCompletionLog` = 'You have slain the Murloc Foragers.' WHERE `ID` = 300108;
UPDATE `quest_template` SET `LogTitle` = 'The Restless Dead', `LogDescription` = 'Destroy 10 Dreadbone Skeletons.', `QuestDescription` = 'You feel it, do you not? The air here will not rest. These ruins were part of Zin-Azshari once, and the dead of that drowned court do not lie quiet.$B$BDreadbone skeletons claw up from the rubble faster than I can catalogue them. Put ten of them back down, $N. The living have work to do in these stones, and the dead keep interrupting it.', `AreaDescription` = 'Azshara Crater', `QuestCompletionLog` = 'The Dreadbone Skeletons have been laid to rest.' WHERE `ID` = 300200;
UPDATE `quest_offer_reward` SET `RewardText` = 'Quieted, for now. They will rise again, they always do, but you have bought us the time we needed. You have my thanks, $N.' WHERE `ID` = 300200;
UPDATE `quest_request_items` SET `CompletionText` = 'The dead still rattle among the stones. Have you put them down?' WHERE `ID` = 300200;
UPDATE `quest_template` SET `LogTitle` = 'Rifts in the Ley', `LogDescription` = 'Destroy 8 Lesser Voidwalkers.', `QuestDescription` = 'There is a wrongness threading these ruins, $N. Not the wild arcane the crater leaks, but something colder. Void. It seeps in wherever the ley lines have frayed, and things crawl through the seams.$B$BLesser voidwalkers are gathering at the broken lines. Destroy eight of them before the rift they widen becomes a wound we cannot close.', `AreaDescription` = 'Azshara Crater', `QuestCompletionLog` = 'The Lesser Voidwalkers have been destroyed.' WHERE `ID` = 300201;
UPDATE `quest_offer_reward` SET `RewardText` = 'Void energies, unmistakable. I will see these traces sealed away where they can do no more harm. You have a careful hand, $N. I may have further need of it.' WHERE `ID` = 300201;
UPDATE `quest_request_items` SET `CompletionText` = 'The voidwalkers still bleed through the ley lines. We need them gone.' WHERE `ID` = 300201;
UPDATE `quest_template` SET `LogTitle` = 'Golems Run Wild', `LogDescription` = 'Destroy 8 Harvest Golems.', `QuestDescription` = 'Some expedition before ours left these harvest golems to tend the ruins, and the crater''s magic has since driven them mad. Now they shatter the very things they were built to protect.$B$BDismantle eight of them, $N. Whatever survives their rampage we can still salvage, and I would far rather the salvage came from them than from us.', `AreaDescription` = 'Azshara Crater', `QuestCompletionLog` = 'The Harvest Golems have been dismantled.' WHERE `ID` = 300202;
UPDATE `quest_offer_reward` SET `RewardText` = 'Good. Their cores are still sound, more than enough to serve constructs of our own. Waste nothing in a place like this, $N. That is the first rule of ruins.' WHERE `ID` = 300202;
UPDATE `quest_request_items` SET `CompletionText` = 'The golems still rampage. Dismantle them before they wreck what remains.' WHERE `ID` = 300202;
UPDATE `quest_template` SET `LogTitle` = 'A Voice Among the Ruins', `LogDescription` = 'Speak with the Spirit of Kelvenar in the ruins.', `QuestDescription` = 'A ghost walks the far ruins, $N. I have watched him from a safe distance. He does not rage as the others do. He grieves. There is old memory in that spirit, and memory is the one thing these stones refuse to give me.$B$BGo to him. Speak gently. If he remembers what this place once was, I would hear it from one who lived it.', `AreaDescription` = 'Azshara Crater', `QuestCompletionLog` = 'You have spoken with the Spirit of Kelvenar.' WHERE `ID` = 300203;
UPDATE `quest_offer_reward` SET `RewardText` = 'He spoke to you? Then there is more sorrow buried here than even I had feared. The Highborne brought this ruin upon themselves, yet that makes the mourning no lighter. Thank you, $N.' WHERE `ID` = 300203;
UPDATE `quest_request_items` SET `CompletionText` = 'The spirit lingers still, waiting. Go to him. He means you no harm.' WHERE `ID` = 300203;
UPDATE `quest_template` SET `LogTitle` = 'The Wailing Noble', `LogDescription` = 'Defeat 12 Skeletal Warriors.', `QuestDescription` = 'You wear your living breath so lightly, mortal. Once, so did I.$B$BBehold what remains of Her Majesty''s guard: the Skeletal Warriors who stood the walls of Zin-Azshari, and stand them yet, though the walls are drowned and the Queen long since fled to the deep. They know no rest, only the old command. Twelve of them bar the way, $N. Break their ranks, and grant them the ending I cannot give myself.', `AreaDescription` = 'Azshara Crater', `QuestCompletionLog` = 'You have broken the guard of the Wailing Noble.' WHERE `ID` = 300204;
UPDATE `quest_offer_reward` SET `RewardText` = 'It is done. The Wailing Noble is silent, his torment ended at last. You have given the dead what the living never could: mercy. Go in peace, $N. Few in this crater ever will.' WHERE `ID` = 300204;
UPDATE `quest_request_items` SET `CompletionText` = 'The Noble''s guard still keeps its endless watch. They will not rest until you make it so.' WHERE `ID` = 300204;
UPDATE `quest_template` SET `LogTitle` = 'Varo''then''s Journal', `LogDescription` = 'Retrieve Varo''then''s Journal from the ruins by slaying 15 Skeletons.', `QuestDescription` = 'Among the bones of this court lies a journal, $N. The writings of one Captain Varo''then, Azshara''s own champion in the days before the Sundering. If any hand set down what the Highborne dared here, it was his.$B$BThe restless dead guard it still, whether they know it or not. Cut through fifteen of the skeletons and bring me that journal. I must learn how deep their folly truly ran.', `AreaDescription` = 'Azshara Crater', `QuestCompletionLog` = 'You have recovered Varo''then''s Journal.' WHERE `ID` = 300205;
UPDATE `quest_offer_reward` SET `RewardText` = 'This... this confirms every fear I carried into these ruins. The Highborne did not merely wield the arcane. They gorged upon it, until it remade them body and soul. We stand in the ashes of their hunger, $N. Let us be the wiser for it.' WHERE `ID` = 300205;
UPDATE `quest_request_items` SET `CompletionText` = 'The journal is still out there, somewhere among the bones. Keep searching.' WHERE `ID` = 300205;
UPDATE `quest_template` SET `LogTitle` = 'To the Eastern Slopes', `LogDescription` = 'Travel to the eastern slopes and find the Orc Scout.', `QuestDescription` = 'The interference thickens toward the eastern slopes, $N. My instruments go blind the moment I turn them that way. I will not send you in wholly alone.$B$BAn orc scout works those slopes for the Horde expedition. Strange bedfellows, I know, but in this crater the living must lean on the living. Find him, and see what he has learned.', `AreaDescription` = 'Azshara Crater', `QuestCompletionLog` = 'You have found the Orc Scout.' WHERE `ID` = 300206;
UPDATE `quest_offer_reward` SET `RewardText` = 'You found him, and both of you in one piece. Good. The slopes are his charge now, and yours besides, if you will take them. Watch yourself out there, $N.' WHERE `ID` = 300206;
UPDATE `quest_request_items` SET `CompletionText` = 'The eastern slopes are treacherous. Have you found the orc scout?' WHERE `ID` = 300206;
UPDATE `quest_template` SET `LogTitle` = 'Dust of the Fallen', `LogDescription` = 'Collect 10 Gold Dust.', `QuestDescription` = 'When these skeletons fall, $N, they crumble to a fine gold dust. The arcane that saturated the Highborne in life, still clinging to them in death. It is a rare reagent, and I will not see it blow away on the wind.$B$BGather ten measures of the gold dust for me. What destroyed them may yet serve the living.', `AreaDescription` = 'Azshara Crater', `QuestCompletionLog` = 'You have gathered 10 Gold Dust.' WHERE `ID` = 300207;
UPDATE `quest_offer_reward` SET `RewardText` = 'Ah, feel how it hums against the skin. Potent, and pure. There is a bitter irony in it, that the Highborne''s ruin should become our reagent. Still, we waste nothing here. My thanks, $N.' WHERE `ID` = 300207;
UPDATE `quest_request_items` SET `CompletionText` = 'I have not gathered enough dust for my work. Return when you have more.' WHERE `ID` = 300207;
UPDATE `quest_template` SET `LogTitle` = 'Poisoned Waters', `LogDescription` = 'Destroy 8 Fouled Water Spirits.', `QuestDescription` = 'The waters that pool through these ruins were once pure ley-fed springs, $N. No longer. Something has fouled them to their depths, and the spirits born of that water have turned poisonous along with it.$B$BEight of the fouled water spirits drift near the fractured lines. Destroy them before their corruption spreads deeper into the ley and beyond our reach.', `AreaDescription` = 'Azshara Crater', `QuestCompletionLog` = 'You have destroyed the Fouled Water Spirits.' WHERE `ID` = 300208;
UPDATE `quest_template` SET `LogTitle` = 'A Test of Steel', `LogDescription` = 'Slay 10 Haldarr Satyrs (or any satyr) in the woods east of the outpost.', `QuestDescription` = 'You come to my fire wanting to fight? Good. Talk is wind.$B$BThe Haldarr satyrs den in the woods east of here, fel-twisted things that were night elves once and remember none of it. They reek of the same broken magic that scarred this crater.$B$BGo east, $C. Cut down ten of them and come back bloodied. Then I will know your steel is worth my time.', `QuestCompletionLog` = 'Ten satyrs slain.' WHERE `ID` = 300300;
UPDATE `quest_offer_reward` SET `RewardText` = 'Hah. Ten of them dead, and you still stand.$B$BThe Haldarr will feel that loss. You have the steel I hoped for, $N.' WHERE `ID` = 300300;
UPDATE `quest_request_items` SET `CompletionText` = 'The satyrs still prowl the eastern wood. Go back and finish the work.' WHERE `ID` = 300300;
UPDATE `quest_template` SET `LogTitle` = 'Ten Cursed Horns', `LogDescription` = 'Collect 10 Satyr Horns.', `QuestDescription` = 'The satyrs grow their horns thick with the crater''s corruption, $N. Ground to powder, that filth burns clean in fire and wards our blades against their poison.$B$BBring me ten Satyr Horns, and take them from fresh kills. Old horns crumble to dust in the hand and are worth nothing.', `QuestCompletionLog` = 'Ten Satyr Horns gathered.' WHERE `ID` = 300301;
UPDATE `quest_offer_reward` SET `RewardText` = 'Ten horns, all sound. Good.$B$BThe grinding is grim work, but this powder keeps their taint off our steel. My thanks, $N.' WHERE `ID` = 300301;
UPDATE `quest_request_items` SET `CompletionText` = 'You have not gathered enough horns yet. Return to the satyr dens.' WHERE `ID` = 300301;
UPDATE `quest_template` SET `LogTitle` = 'Silence the Totems', `LogDescription` = 'Destroy 5 Thistlefur Totems.', `QuestDescription` = 'The Thistlefur were furbolgs once, honest beasts of the wood. The crater''s madness took them, and now they raise totems that pulse with that same sick power.$B$BEvery totem left standing feeds their frenzy, $N. Go into their camp and smash five Thistlefur Totems to splinters. Rob them of the magic before we rob them of their heads.', `QuestCompletionLog` = 'Five Thistlefur Totems destroyed.' WHERE `ID` = 300302;
UPDATE `quest_offer_reward` SET `RewardText` = 'The totems are kindling now? Good.$B$BTheir dark magic sputters without them. The Thistlefur will break all the easier.' WHERE `ID` = 300302;
UPDATE `quest_request_items` SET `CompletionText` = 'The totems still stand. Cut down the totemics who guard them and smash the poles.' WHERE `ID` = 300302;
UPDATE `quest_template` SET `LogTitle` = 'The Captive Elder', `LogDescription` = 'Kill 10 Thistlefur Shamans.', `QuestDescription` = 'The Thistlefur hold an elder caged deep in their camp, and it is their shamans who keep the wards that bind him.$B$BI have no love for cages, $N, whatever beast sits inside one. Kill ten Thistlefur Shamans and their binding magic will fray. Then we can cut the elder loose and be done with it.', `QuestCompletionLog` = 'Ten Thistlefur Shamans defeated.' WHERE `ID` = 300303;
UPDATE `quest_offer_reward` SET `RewardText` = 'The shamans are dead and their wards unravel.$B$BThe elder will taste free air soon. You have my respect, $N.' WHERE `ID` = 300303;
UPDATE `quest_request_items` SET `CompletionText` = 'The shamans still chant and the wards still hold. Silence them.' WHERE `ID` = 300303;
UPDATE `quest_template` SET `LogTitle` = 'Rot at the Root', `LogDescription` = 'Kill 15 Thistlefur Avengers.', `QuestDescription` = 'The rot in these furbolgs runs deepest in their Avengers, $N. Hulking, armored brutes, the corruption''s chosen fists.$B$BStrike at the top and the rest lose their spine. Fifteen Thistlefur Avengers is hard work. I would not send a weakling to do it.', `QuestCompletionLog` = 'Fifteen Thistlefur Avengers slain.' WHERE `ID` = 300304;
UPDATE `quest_offer_reward` SET `RewardText` = 'Their strongest lie broken.$B$BWith the Avengers gone the corruption has nothing left to lean on. Well fought, $N.' WHERE `ID` = 300304;
UPDATE `quest_request_items` SET `CompletionText` = 'The Avengers still guard the camp''s heart. Cut them down.' WHERE `ID` = 300304;
UPDATE `quest_template` SET `LogTitle` = 'Drive Them from the Wood', `LogDescription` = 'Defeat 20 Thistlefurs of any kind.', `QuestDescription` = 'Now we finish it. No more picking at the edges. We drive the Thistlefur from these woods for good.$B$BWade into their camp and put down twenty of them, $N, whatever they are: shaman, avenger, whelp, it makes no difference. Break their numbers and break their nerve.$B$BGo. Make it loud.', `QuestCompletionLog` = 'Twenty Thistlefurs defeated.' WHERE `ID` = 300305;
UPDATE `quest_offer_reward` SET `RewardText` = 'Twenty down and the rest running!$B$BThe wood is ours again, $N. That was a fight worth singing about.' WHERE `ID` = 300305;
UPDATE `quest_request_items` SET `CompletionText` = 'The Thistlefur still hold their ground. The assault is not yet finished.' WHERE `ID` = 300305;
UPDATE `quest_template` SET `LogTitle` = 'Word for Thalindra', `LogDescription` = 'Return to Scout Thalindra.', `QuestDescription` = 'You have done this wood a great service, $N, and word of it belongs with the night elves who watch over the crater.$B$BReturn to Scout Thalindra at the outpost and tell her the Thistlefur are broken. She trusts my scouts little. A warrior of your kind speaking plainly will carry more weight than my word ever could.', `QuestCompletionLog` = 'Report to Scout Thalindra.' WHERE `ID` = 300306;
UPDATE `quest_offer_reward` SET `RewardText` = 'Broken and driven off, truly?$B$BThen Gor''nash and his scouts have earned their place at our fire this once. You have my thanks, $N. The eastern wood can breathe again.' WHERE `ID` = 300306;
UPDATE `quest_request_items` SET `CompletionText` = 'Have you carried word of our victory to Scout Thalindra?' WHERE `ID` = 300306;
UPDATE `quest_template` SET `LogTitle` = 'Beads of the Thistlefur', `LogDescription` = 'Collect 10 Gnoll War Beads.', `QuestDescription` = 'Strange thing, this. The Thistlefur string beads through their fur the way the gnolls do, the same crude craft. My scouts fear the corruption is creeping from beast to beast, and I mean to know.$B$BBring me ten Gnoll War Beads off their bodies, $N. If the taint jumps between tribes, better we learn it now than at the point of a spear.', `QuestCompletionLog` = 'Ten Gnoll War Beads gathered.' WHERE `ID` = 300307;
UPDATE `quest_offer_reward` SET `RewardText` = 'Ten beads, all of the same make.$B$BThis tells me more than I wanted to know. The rot does not care what wears it. My thanks, $N.' WHERE `ID` = 300307;
UPDATE `quest_request_items` SET `CompletionText` = 'You have not brought enough beads yet. Search the Thistlefur dead.' WHERE `ID` = 300307;
UPDATE `quest_template` SET `LogTitle` = 'Teeth in the Shallows', `LogDescription` = 'Hunt 6 Giant Wetlands Crocolisks.', `QuestDescription` = 'The crocolisks in the river have swollen fat and mean on the crater''s tainted water. Great brutes now, big as war-boars, and they have started dragging our pack-beasts under.$B$BOur supply road runs right past their bank, $N. Hunt down six Giant Wetlands Crocolisks before they take the whole caravan next.', `QuestCompletionLog` = 'Six Giant Wetlands Crocolisks hunted.' WHERE `ID` = 300308;

-- 8. Quest replay -- 2026_08_29_00: 300100 level-1 reward clones + slot shift
UPDATE `quest_template`
SET `RewardChoiceItemID1` = 303140,
    `RewardChoiceItemID2` = 303141,
    `RewardChoiceItemID3` = 303142,
    `RewardChoiceItemID4` = 303143
WHERE `ID` = 300100;

UPDATE `quest_template`
SET `RewardItem1` = 300311, `RewardAmount1` = 3,
    `RewardItem2` = 300312, `RewardAmount2` = 2,
    `RewardItem3` = 0,      `RewardAmount3` = 0
WHERE `ID` = 300100;
