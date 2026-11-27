-- Hyjal Frontier - Heartstone of Nordrassil (zone heirloom neck, tier 10)
--
-- Item:   300412  Heartstone of Nordrassil (InventoryType=2 neck, Quality=7 heirloom)
-- Tier:   10      "Frontier Heirloom" — 5 upgrade stages, shares dc_heirloom_upgrade_costs
-- Quests: 81260-81262 Alliance  "What Nordrassil Holds"
--         81270-81272 Horde     "What the Roots Hold"
--
-- Acquisition: short 3-quest chain per faction starting in The Summit area
--   (requires completing enough of the zone to reach Rootbound Colossi, ~lv 120+)
--   Quest mob: Rootbound Colossus (830097, lv 122-124, Nordrassil Roots)
--   Quest item: Root-Bound Memory (400455, existing drop from 830097 via 12_Extended_Quests)
--
-- Client addon: Register item 300412 in DC.HEIRLOOM_ITEMS (DarkChaos_ItemUpgrade_Retail.lua)
--   and add tier 10 entry to Data/TierStatic.lua — both already done in this commit.
--
-- DBC: Item.csv row added for entry 300412 → displayid 70001 (INV_Misc_Gem_Emerald_01).
--   ItemDisplayInfo.csv row 70001 added with the emerald gem icon.
-- Spell.csv rows added:
--   300750  "Nordrassil's Blessing" — passive proc aura (on equip, trigger=1)
--           ProcTypeMask=139944 (taken melee/ranged/magic), ProcChance=10 → fires 300751
--   300751  "Nordrassil's Blessing" — instant nature heal, EffectBasePoints=5000

-- =============================================================================
-- Item template
-- =============================================================================
DELETE FROM `item_template` WHERE `entry` = 300412;
INSERT INTO `item_template`
    (`entry`, `class`, `subclass`, `SoundOverrideSubclass`, `name`, `displayid`,
     `Quality`, `Flags`, `FlagsExtra`, `BuyCount`, `BuyPrice`, `SellPrice`,
     `InventoryType`, `AllowableClass`, `AllowableRace`,
     `ItemLevel`, `RequiredLevel`,
     `maxcount`, `stackable`, `bonding`,
     `stat_type1`, `stat_value1`,
     `ScalingStatDistribution`, `ScalingStatValue`,
     `spellid_1`, `spelltrigger_1`, `spellcharges_1`, `spellppmrate_1`,
     `spellcooldown_1`, `spellcategory_1`, `spellcategorycooldown_1`,
     `description`, `VerifiedBuild`)
VALUES
(300412, 4, 0, -1, 'Heartstone of Nordrassil', 70001,
    7, 524288, 0, 1, 0, 0,
    2, -1, -1,
    1, 1,
    1, 1, 1,
    7, 150,
    0, 0,
    300750, 1, 0, 0, -1, 0, -1,
    'A fragment of the World Tree, shaped into a pendant by Archdruid Rhydel. Base Stamina grows as you upgrade through the stat-package system.',
    0);

-- =============================================================================
-- Upgrade system — Tier 10 "Frontier Heirloom" and item registration
-- =============================================================================
DELETE FROM `dc_item_upgrade_tiers`         WHERE `tier_id` = 10;
DELETE FROM `dc_item_upgrade_item_overrides` WHERE `item_id` = 300412;

INSERT INTO `dc_item_upgrade_tiers`
    (`tier_id`, `tier_name`, `description`,
     `min_ilvl`, `max_ilvl`, `max_upgrade_level`,
     `stat_multiplier_max`, `upgrade_cost_per_level`,
     `source_content`, `is_artifact`, `season`, `is_active`)
VALUES
(10, 'Frontier Heirloom',
    'Zone heirloom items — 5 upgrade stages using the heirloom essence cost table',
    1, 500, 5,
    1.40, 0,
    'Hyjal Frontier', 1, 1, 1);

-- Override forces tier detection for this item (ilvl 1 would otherwise match tier 1).
INSERT INTO `dc_item_upgrade_item_overrides`
    (`item_id`, `tier_id`, `season`, `is_active`, `comment`)
VALUES
(300412, 10, 1, 1, 'Heartstone of Nordrassil — Frontier Heirloom tier (cannot derive from ilvl)');

-- =============================================================================
-- Quest cleanup
-- =============================================================================
DELETE FROM `creature_queststarter` WHERE `quest` BETWEEN 81260 AND 81262;
DELETE FROM `creature_questender`   WHERE `quest` BETWEEN 81260 AND 81262;
DELETE FROM `quest_request_items`   WHERE `ID`    BETWEEN 81260 AND 81262;
DELETE FROM `quest_offer_reward`    WHERE `ID`    BETWEEN 81260 AND 81262;
DELETE FROM `quest_template_addon`  WHERE `ID`    BETWEEN 81260 AND 81262;
DELETE FROM `quest_template`        WHERE `ID`    BETWEEN 81260 AND 81262;

DELETE FROM `creature_queststarter` WHERE `quest` BETWEEN 81270 AND 81272;
DELETE FROM `creature_questender`   WHERE `quest` BETWEEN 81270 AND 81272;
DELETE FROM `quest_request_items`   WHERE `ID`    BETWEEN 81270 AND 81272;
DELETE FROM `quest_offer_reward`    WHERE `ID`    BETWEEN 81270 AND 81272;
DELETE FROM `quest_template_addon`  WHERE `ID`    BETWEEN 81270 AND 81272;
DELETE FROM `quest_template`        WHERE `ID`    BETWEEN 81270 AND 81272;

-- =============================================================================
-- Quest templates
-- =============================================================================
INSERT INTO `quest_template`
    (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`,
     `QuestInfoID`, `RewardXPDifficulty`, `RewardMoney`, `AllowableRaces`,
     `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`,
     `QuestCompletionLog`,
     `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`,
     `RequiredNpcOrGo2`, `RequiredNpcOrGoCount2`,
     `RequiredItemId1`, `RequiredItemCount1`,
     `RewardItem1`, `RewardAmount1`,
     `ObjectiveText1`, `ObjectiveText2`, `VerifiedBuild`)
VALUES

-- ─────────────────────────────────────────────────────────────────────────────
-- ALLIANCE CHAIN  "What Nordrassil Holds"
-- ─────────────────────────────────────────────────────────────────────────────

-- Quest 81260: Kill Colossi + collect Root-Bound Memories
(81260, 2, 122, 120, 6100, 0, 8, 0, 1101,
 'What Nordrassil Holds',
 'Warden Starfall has noticed that the Rootbound Colossi carry fragments of Nordrassil''s memory in their bark. Archdruid Rhydel believes these fragments can be shaped into something that preserves the tree''s power.',
 'The Rootbound Colossi below the ridge carry pieces of the World Tree''s bark — fragments that were torn away during the Third War and are still alive with the tree''s memory. Kill six of them and recover four of those fragments. Rhydel says he can work with them.',
 'Nordrassil Roots, lower root-caverns.',
 'Four fragments. Enough for the archdruid to begin his work.',
 830097, 6, 0, 0, 400455, 4,
 0, 0,
 'Rootbound Colossi slain', 'Root-Bound Memories collected', 0),

-- Quest 81261: Deliver memories to Archdruid Rhydel
(81261, 2, 122, 120, 6100, 0, 7, 0, 1101,
 'The Archdruid''s Work',
 'Take the Root-Bound Memories to Archdruid Rhydel at Nordrassil''s edge. He has been waiting for viable fragments.',
 'Rhydel is at the great root on Nordrassil''s southern edge. He says the fragments speak to the tree, and the tree can speak back through them. Bring him the memories before the bark dies.',
 'Nordrassil edge — Archdruid Rhydel''s position.',
 'Rhydel accepts the fragments. He will begin the shaping.',
 830034, 1, 0, 0, 400455, 4,
 0, 0,
 'Deliver Root-Bound Memories to Archdruid Rhydel', '', 0),

-- Quest 81262: Collect the finished Heartstone
(81262, 2, 122, 120, 6100, 0, 5, 100000, 1101,
 'Heartstone of Nordrassil',
 'Archdruid Rhydel has finished shaping the pendant. Return to him at Nordrassil''s edge to receive it.',
 'The shaping took one night. Rhydel says the pendant carries both the tree''s memory and something older — a ward against the corruption that tried to unmake Nordrassil at the Third War. It is yours to wear.',
 'Nordrassil edge — Archdruid Rhydel''s position.',
 'The Heartstone of Nordrassil is yours.',
 0, 0, 0, 0, 0, 0,
 300412, 1,
 '', '', 0),

-- ─────────────────────────────────────────────────────────────────────────────
-- HORDE CHAIN  "What the Roots Hold"
-- ─────────────────────────────────────────────────────────────────────────────

-- Quest 81270: Kill Colossi + collect memories
(81270, 2, 122, 120, 6100, 0, 8, 0, 690,
 'What the Roots Hold',
 'Battlelord Gromtar has seen the earthmenders watching the Rootbound Colossi with unusual interest. Earthwarden Toran believes those colossi carry something worth recovering from the rubble.',
 'Toran says the bark those colossi carry is still alive with the World Tree''s memory. He wants four of those fragments to make something out of them. Kill six of the colossi in the roots below and take what they carry.',
 'Nordrassil Roots, lower root-caverns.',
 'Four memory-fragments. Toran will know what to do with them.',
 830097, 6, 0, 0, 400455, 4,
 0, 0,
 'Rootbound Colossi slain', 'Root-Bound Memories collected', 0),

-- Quest 81271: Deliver memories to Earthwarden Toran
(81271, 2, 122, 120, 6100, 0, 7, 0, 690,
 'The Earthwarden''s Craft',
 'Take the Root-Bound Memories to Earthwarden Toran at Nordrassil''s edge. He has the tools and the knowledge to shape them.',
 'Toran is at the great root. He works with living wood and memory, not with steel. Bring him the fragments before the bark dries out and the memory in them goes silent.',
 'Nordrassil edge — Earthwarden Toran''s position.',
 'Toran accepts the fragments and begins his work.',
 830039, 1, 0, 0, 400455, 4,
 0, 0,
 'Deliver Root-Bound Memories to Earthwarden Toran', '', 0),

-- Quest 81272: Collect the finished Heartstone
(81272, 2, 122, 120, 6100, 0, 5, 100000, 690,
 'Heartstone of Nordrassil',
 'Earthwarden Toran has finished his work. Return to him at Nordrassil''s edge to claim what he shaped for you.',
 'Toran says the pendant holds the memory of the tree and a piece of its will. He shaped it to bind itself to its bearer. It will grow stronger as you do — if you give it the essence it needs. Take it.',
 'Nordrassil edge — Earthwarden Toran''s position.',
 'The Heartstone of Nordrassil is yours.',
 0, 0, 0, 0, 0, 0,
 300412, 1,
 '', '', 0);

-- =============================================================================
-- Quest addon chains
-- =============================================================================
INSERT INTO `quest_template_addon` (`ID`, `PrevQuestID`, `NextQuestID`, `SpecialFlags`) VALUES
-- Alliance
(81260, 0,     81261, 0),
(81261, 81260, 81262, 0),
(81262, 81261, 0,     0),
-- Horde
(81270, 0,     81271, 0),
(81271, 81270, 81272, 0),
(81272, 81271, 0,     0);

-- =============================================================================
-- Quest request items (in-progress NPC text while the quest is incomplete)
-- =============================================================================
INSERT INTO `quest_request_items`
    (`ID`, `EmoteOnComplete`, `EmoteOnIncomplete`, `CompletionText`, `VerifiedBuild`)
VALUES
(81260, 6, 0, 'Six colossi and four memories. The roots are full of them.', 0),
(81261, 6, 0, 'Rhydel is at the great root. He needs those fragments before they go cold.', 0),
(81262, 6, 0, 'The work is done. Come and take it.', 0),
(81270, 6, 0, 'Six colossi. Four fragments. Toran is waiting.', 0),
(81271, 6, 0, 'Toran is at the root''s edge. Do not let the bark dry out.', 0),
(81272, 6, 0, 'It is shaped. Come and claim it.', 0);

-- =============================================================================
-- Quest offer reward (completion text shown when turning in)
-- =============================================================================
INSERT INTO `quest_offer_reward`
    (`ID`, `Emote1`, `Emote2`, `Emote3`, `Emote4`,
     `EmoteDelay1`, `EmoteDelay2`, `EmoteDelay3`, `EmoteDelay4`,
     `RewardText`, `VerifiedBuild`)
VALUES
(81260, 0, 0, 0, 0, 0, 0, 0, 0, 'Four fragments. Rhydel will be pleased. Those colossi have been wandering for twenty years with the tree''s memory locked inside them.', 0),
(81261, 0, 0, 0, 0, 0, 0, 0, 0, 'The fragments are still alive. I can work with these. Return in the morning — the shaping will take what it takes.', 0),
(81262, 0, 0, 0, 0, 0, 0, 0, 0, 'Nordrassil does not forget those who fought for it. Neither does this pendant.', 0),
(81270, 0, 0, 0, 0, 0, 0, 0, 0, 'You pulled them out cleanly. Good. The fragments are still speaking. Toran can work with live bark.', 0),
(81271, 0, 0, 0, 0, 0, 0, 0, 0, 'Four memories. Enough. Come back when the next sun is overhead. What I am making needs the night to set.', 0),
(81272, 0, 0, 0, 0, 0, 0, 0, 0, 'The tree gave you this piece of itself. Do not waste it. Upgrade it as you earn the essence — the pendant will reward you.', 0);

-- =============================================================================
-- Quest starters and enders
-- =============================================================================
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
-- Alliance — Warden Starfall starts the chain, Rhydel gives the final reward
(830033, 81260),
(830033, 81261),
(830034, 81262),
-- Horde — Battlelord Gromtar starts, Toran gives the reward
(830038, 81270),
(830038, 81271),
(830039, 81272);

INSERT INTO `creature_questender` (`id`, `quest`) VALUES
-- Alliance
(830033, 81260),
(830034, 81261),
(830034, 81262),
-- Horde
(830038, 81270),
(830039, 81271),
(830039, 81272);
