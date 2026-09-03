-- ====================================================================================
-- DC ONBOARDING: introduction quests for the custom systems
-- Date: 2026-09-03   Database: acore_world
-- ====================================================================================
-- Extends the existing FirstStart onboarding line (820056 "Welcome to Azshara Crater"
-- -> 820057 / 820058 / 820059) with two crater-level quests and a level-80 endgame
-- primer covering Mythic+, item upgrades, heirloom upgrades, guild housing and HLBG.
--
-- QUEST IDS ---------------------------------------------------------------------------
--   Tier A - Azshara Crater, level 1, Hervikus the Chaotic (800009) gives AND takes
--     820060  Roads Beyond the Rim      -> speak to the Teleporter (800002)
--     820061  Wings Over the Crater     -> speak to the Startcamp Flightmaster (800010)
--     820065  Sharpening the Edge       -> upgrade one item      (chains off 820058)
--     820066  Legacies Remade           -> upgrade one heirloom  (chains off 820065)
--
--   Tier B - Jade Forest player base (map 745), level 80, Chronicler Vaelin (800064)
--     820062  A Wider World             -> breadcrumb, auto-granted at level 80
--     820063  A Key to the Deeps        -> take a keystone from the Keystone Vendor
--     820064  Into the Breach           -> complete one Mythic+ run
--     820067  A Roof of Your Own        -> speak to the Guild House Manager
--     820068  The Hinterlands Burn      -> speak to the Hinterlands Battlemaster
--
-- WHY THE TWO UPGRADE QUESTS ARE LEVEL 1 ---------------------------------------------
-- Nothing anywhere in the upgrade path gates on player level, and a fresh character is
-- already equipped to do both:
--   * DCFirstStart grants 100 DC Item Upgrade Tokens on first login
--     (DCFirstStart.SeasonalTokens.Amount) plus class BoA gear. A tier-1 upgrade costs
--     10 tokens, so 820065 is comfortably affordable at level 1.
--   * Quest 820058 "The Watchful Eye", already part of the opening fan-out from
--     Hervikus, hands over item 300365 "Heirloom Adventurer's Shirt" - the item the
--     heirloom upgrade path is built around.
--
-- BY DESIGN: the essence-priced heirloom path applies to the SHIRT ONLY. Do not
-- "fix" this by adding dc_item_upgrade_item_overrides rows.
--     UpgradeManager::GetItemTier() skips every is_artifact tier when matching on item
--     level, so an item reaches tier 3 only through an explicit override row. That
--     table holds exactly two: 300365 (tier 3, this shirt) and 300412 (tier 10). The
--     addon agrees - DC.HEIRLOOM_ITEMS registers the same two entries.
--     Everything else heirloom-quality is meant to take the ORDINARY token-priced
--     upgrade path: the 34-piece custom set 300332-300366 is ilvl 80 and the four class
--     heirlooms granted at login (42949 / 48685 / 42991 / 42943) are ilvl 1, so all of
--     them resolve to tier 1 and upgrade normally. Adding overrides would silently
--     re-price ~370 items from tokens onto essence, which no fresh character has.
--     Hence 820066 names the shirt explicitly rather than saying "any heirloom".
-- Hence the linear chain 820058 (shirt) -> 820065 (item upgrade) -> 820066 (heirloom).
-- 820065 pays out Artifact Essence rather than Upgrade Tokens on purpose: heirloom
-- upgrade level 1 costs 50 essence and 0 tokens (dc_heirloom_upgrade_costs), and
-- nothing at first login grants any essence.
--
-- WHY A NEW QUESTGIVER (800064) ------------------------------------------------------
-- Every NPC already standing in the map-745 hub swallows its gossip window before the
-- client can render a quest menu: npc_mythic_token_vendor (100051/100052) calls
-- SendVendorOpen + CloseGossipMenuFor and returns true, npc_keystone_vendor (100100)
-- and dc_teleporter_creature_script (800002) build their own menu and return true, and
-- the flight masters (800010..800015) answer with SendTaxiMenu. A CreatureScript that
-- returns true from OnGossipHello never reaches PlayerMenu's quest section, so none of
-- them can offer or accept a quest without reworking its gossip flow. One plain
-- questgiver owns the whole endgame line instead; the system NPCs stay untouched apart
-- from the one-line credit calls listed under "REQUIRES A WORLDSERVER REBUILD" below.
--
-- REQUIRES A WORLDSERVER REBUILD -----------------------------------------------------
-- Objectives are credited from C++ because the target NPCs' gossip hooks return true,
-- which is the same trap quest 820059 hit (it needed an explicit KillCreditGO). The
-- matching core changes are:
--   dc_teleporter.cpp                  TalkedToCreature(800002) in OnGossipHello
--   ac_flightmasters.cpp               TalkedToCreature(entry)  in OnGossipHello
--   dc_mythicplus_keystone_vendor.cpp  KilledMonsterCredit(800060) when a key is issued
--   dc_mythicplus_run_manager.cpp      KilledMonsterCredit(800061) per participant
--   dc_addon_upgrade.cpp               KilledMonsterCredit(800062 / 800063) on upgrade
--   dc_guildhouse_npcs.cpp             TalkedToCreature(95103)  in OnGossipHello
--   hlbg_npc_battlemaster.cpp          TalkedToCreature(900001) in OnGossipHello
--   dc_firststart.cpp                  auto-grants 820062 at level 80
-- Without them the quests can be accepted but never complete.
-- ====================================================================================


-- ------------------------------------------------------------------------------------
-- Kill-credit templates (never spawned; they exist so quest_template validates and so
-- KilledMonsterCredit has an entry to match against)
-- ------------------------------------------------------------------------------------
DELETE FROM `creature_template` WHERE `entry` BETWEEN 800060 AND 800063;
-- NOTE: creature_template in this fork has NO `scale` column (per-model scale lives in
-- creature_template_model.DisplayScale) and NO `mechanic_immune_mask` (it is
-- `CreatureImmunitiesId`, an id into creature_immunities, not a bitmask). Both are
-- omitted here rather than guessed at.
-- unit_flags 33554946 = 0x02000202 (NOT_SELECTABLE | IMMUNE_TO_NPC | NON_ATTACKABLE)
-- flags_extra 130      = 0x82 (TRIGGER | CIVILIAN) - the standard invisible-trigger set.
INSERT INTO `creature_template`
  (`entry`, `name`, `subname`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`,
   `npcflag`, `speed_walk`, `speed_run`, `rank`, `unit_class`, `unit_flags`,
   `unit_flags2`, `type`, `type_flags`, `AIName`, `MovementType`, `RegenHealth`,
   `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(800060, 'Keystone Acquired',    'DC Quest Credit', 0, 80, 80, 0, 35, 0, 1, 1.14286, 0, 1, 33554946, 2048, 10, 0, '', 0, 1, 130, '', 0),
(800061, 'Mythic Run Completed', 'DC Quest Credit', 0, 80, 80, 0, 35, 0, 1, 1.14286, 0, 1, 33554946, 2048, 10, 0, '', 0, 1, 130, '', 0),
(800062, 'Item Upgraded',        'DC Quest Credit', 0, 80, 80, 0, 35, 0, 1, 1.14286, 0, 1, 33554946, 2048, 10, 0, '', 0, 1, 130, '', 0),
(800063, 'Heirloom Upgraded',    'DC Quest Credit', 0, 80, 80, 0, 35, 0, 1, 1.14286, 0, 1, 33554946, 2048, 10, 0, '', 0, 1, 130, '', 0);

DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN 800060 AND 800063;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(800060, 0, 11686, 1, 1, 0),
(800061, 0, 11686, 1, 1, 0),
(800062, 0, 11686, 1, 1, 0),
(800063, 0, 11686, 1, 1, 0);


-- ------------------------------------------------------------------------------------
-- Chronicler Vaelin (800064) - the endgame line's questgiver, Jade Forest player base.
-- Placed inside the Mythic+ cluster: Keystone Vendor 100100 sits at (909.9, -2533.9),
-- Transmutation Master 190004 at (907.1, -2542.5), Seasonal Quartermaster 100051 at
-- (908.8, -2538.3) - all on the same 179.82 floor.
-- ------------------------------------------------------------------------------------
DELETE FROM `creature_template` WHERE `entry` = 800064;
-- Field-for-field a copy of Guild House Manager 95103 (a plain, working gossip NPC in
-- this same hub) except for npcflag 3 = GOSSIP | QUESTGIVER. unit_flags 768 = 0x300
-- (IMMUNE_TO_PC | IMMUNE_TO_NPC) keeps him out of every fight in the base.
INSERT INTO `creature_template`
  (`entry`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`,
   `faction`, `npcflag`, `speed_walk`, `speed_run`, `rank`, `unit_class`,
   `unit_flags`, `unit_flags2`, `type`, `type_flags`, `AIName`, `MovementType`,
   `RegenHealth`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(800064, 'Chronicler Vaelin', 'Champion''s Primer', 'Speak', 0, 80, 80, 0, 35, 3, 1, 1.14286, 0, 1, 768, 2048, 7, 0, '', 0, 1, 0, '', 0);

DELETE FROM `creature_template_model` WHERE `CreatureID` = 800064;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(800064, 0, 30259, 1, 1, 0);

-- Explicit guid, deliberately below the 0x00FFFFFF spawn-guid cap.
DELETE FROM `creature` WHERE `guid` = 16751210;
DELETE FROM `creature` WHERE `id` = 800064;
INSERT INTO `creature`
  (`guid`, `id`, `map`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`,
   `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`,
   `MovementType`, `VerifiedBuild`) VALUES
(16751210, 800064, 745, 1, 1, 0, 913.0, -2546.5, 179.82, 2.4, 300, 0, 0, 0, 0);


-- ====================================================================================
-- TIER A - Azshara Crater (level 1)
-- ====================================================================================

-- ------------------------------------------------------------------------------------
-- 820060  Roads Beyond the Rim
-- ------------------------------------------------------------------------------------
DELETE FROM `quest_template` WHERE `ID` = 820060;
INSERT INTO `quest_template`
  (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
   `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `LogTitle`, `LogDescription`,
   `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`,
   `RequiredNpcOrGoCount1`, `ObjectiveText1`) VALUES
(820060, 2, 1, 1, 0, 0, 0, 1, 0, 300311, 1,
 'Roads Beyond the Rim',
 'Speak with the Teleporter near the camp, then return to Hervikus the Chaotic.',
 'The crater is wide, $N, and your legs are only mortal. Before you wear them down, learn the shortcut every champion here relies on.$B$BStanding just past the tents is what we call the Teleporter. Ask it where you wish to go and it will simply put you there - the cities of both banners, the old dungeons and raids, the leveling grounds, and the player base out in the Jade Forest where the veterans gather.$B$BGo and speak with it. Read the list. You need not step through today, but you should know it is there before the day comes when you must be elsewhere in a hurry.',
 'Azshara Crater',
 'Return to Hervikus the Chaotic.',
 800002, 1,
 'Teleporter consulted');

DELETE FROM `quest_template_addon` WHERE `ID` = 820060;
INSERT INTO `quest_template_addon` (`ID`, `PrevQuestID`) VALUES
(820060, 820056);

DELETE FROM `quest_offer_reward` WHERE `ID` = 820060;
INSERT INTO `quest_offer_reward` (`ID`, `RewardText`, `VerifiedBuild`) VALUES
(820060, 'Useful, is it not? I have watched champions run themselves ragged for a week before someone thought to mention that stone to them.$B$BUse it freely, $N. The crater will still be here when you come back.', 0);

DELETE FROM `creature_queststarter` WHERE `id` = 800009 AND `quest` = 820060;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES (800009, 820060);
DELETE FROM `creature_questender` WHERE `id` = 800009 AND `quest` = 820060;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES (800009, 820060);


-- ------------------------------------------------------------------------------------
-- 820061  Wings Over the Crater
-- ------------------------------------------------------------------------------------
DELETE FROM `quest_template` WHERE `ID` = 820061;
INSERT INTO `quest_template`
  (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
   `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `LogTitle`, `LogDescription`,
   `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`,
   `RequiredNpcOrGoCount1`, `ObjectiveText1`) VALUES
(820061, 2, 1, 1, 0, 0, 0, 1, 0, 300311, 1,
 'Wings Over the Crater',
 'Speak with the Azshara Flightmaster above the starting camp, then return to Hervikus the Chaotic.',
 'There is a second way to cross this place, $N, and it does not involve your boots at all.$B$BClimb the rise above the camp and you will find one of our flight masters waiting with her birds. Speak to her once and the whole crater network opens to you - the startcamp, the middle terraces, and the far camps where the older beasts prowl. Five roosts in all, and they will carry you between them for a handful of coin.$B$BYou need only introduce yourself. She will do the rest, and the map will remember.',
 'Above the starting camp.',
 'Return to Hervikus the Chaotic.',
 800010, 1,
 'Azshara Flightmaster met');

DELETE FROM `quest_template_addon` WHERE `ID` = 820061;
INSERT INTO `quest_template_addon` (`ID`, `PrevQuestID`) VALUES
(820061, 820056);

DELETE FROM `quest_offer_reward` WHERE `ID` = 820061;
INSERT INTO `quest_offer_reward` (`ID`, `RewardText`, `VerifiedBuild`) VALUES
(820061, 'Good. Walk when you are hunting, $N, and fly when you are only travelling. The crater eats the ones who confuse the two.', 0);

DELETE FROM `creature_queststarter` WHERE `id` = 800009 AND `quest` = 820061;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES (800009, 820061);
DELETE FROM `creature_questender` WHERE `id` = 800009 AND `quest` = 820061;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES (800009, 820061);


-- ------------------------------------------------------------------------------------
-- 820065  Sharpening the Edge   (item upgrades)
-- Chains off 820058 so the player is holding the heirloom shirt before 820066 opens.
-- Pays Artifact Essence, not tokens: they already have 100 tokens from first login and
-- what they will be short of is the 50 essence that heirloom level 1 costs.
-- Credit fires from the addon protocol's CMSG_DO_UPGRADE handler.
-- ------------------------------------------------------------------------------------
DELETE FROM `quest_template` WHERE `ID` = 820065;
INSERT INTO `quest_template`
  (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
   `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardNextQuest`,
   `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`,
   `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`, `ObjectiveText1`) VALUES
(820065, 2, 1, 1, 0, 0, 0, 1, 0, 300312, 75, 820066,
 'Sharpening the Edge',
 'Upgrade any item once, then return to Hervikus the Chaotic.',
 'Empty your bags onto the table, $N. No - I do not want your rations. That gear you were handed when you walked in: look at it properly.$B$BMost who arrive here assume that armour is something you throw away the moment better armour turns up. Down in this crater that habit will leave you naked and broke by the third terrace. There is another way, and you may as well learn it while your gear is still worthless enough that mistakes cost nothing.$B$BType /upgrade. A ledger opens - everything you own on one side, the price on the other. Pick something. Pay the tokens you were given at the gate. Watch the numbers move.$B$BThat is the whole trick, and you will still be using it at level eighty. Go and do it once.',
 'Azshara Crater',
 'Return to Hervikus the Chaotic.',
 800062, 1,
 'Item upgraded');

DELETE FROM `quest_template_addon` WHERE `ID` = 820065;
INSERT INTO `quest_template_addon` (`ID`, `PrevQuestID`, `NextQuestID`) VALUES
(820065, 820058, 820066);

DELETE FROM `quest_offer_reward` WHERE `ID` = 820065;
INSERT INTO `quest_offer_reward` (`ID`, `RewardText`, `VerifiedBuild`) VALUES
(820065, 'There. The same piece of gear you had a moment ago, only now it is worth carrying.$B$BTake this essence, $N. It is a different currency and it buys a different thing - I will show you what, if you have the patience for one more lesson.', 0);

DELETE FROM `creature_queststarter` WHERE `id` = 800009 AND `quest` = 820065;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES (800009, 820065);
DELETE FROM `creature_questender` WHERE `id` = 800009 AND `quest` = 820065;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES (800009, 820065);


-- ------------------------------------------------------------------------------------
-- 820066  Legacies Remade   (heirloom upgrades)
-- Requires the Heirloom Adventurer's Shirt (300365) from 820058 and the 75 Artifact
-- Essence paid out by 820065 - both guaranteed by the PrevQuestID chain above.
-- Credit fires from the heirloom branch of the same upgrade handler.
-- ------------------------------------------------------------------------------------
DELETE FROM `quest_template` WHERE `ID` = 820066;
INSERT INTO `quest_template`
  (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
   `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`,
   `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`,
   `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`, `ObjectiveText1`) VALUES
(820066, 2, 1, 1, 0, 0, 0, 1, 0, 300311, 25,
 'Legacies Remade',
 'Upgrade the Heirloom Adventurer''s Shirt, then return to Hervikus the Chaotic.',
 'That plain shirt Thalindra gave you. Do not throw it out.$B$BIt is an heirloom, $N, and an heirloom does not have a level - it has yours. It fits you now, and it will still fit you at eighty, and it will fit the next character you roll on the day they draw their first breath. That is the point of it.$B$BSo it is not upgraded like other gear. Ordinary steel takes tokens. This takes essence - the essence I just handed you - and what you are buying is not one shirt''s numbers. It is every character you will ever make here.$B$BOpen the ledger, find the heirloom, spend the essence. Then go and be young somewhere else for a while.',
 'Azshara Crater',
 'Return to Hervikus the Chaotic.',
 800063, 1,
 'Heirloom upgraded');

DELETE FROM `quest_template_addon` WHERE `ID` = 820066;
INSERT INTO `quest_template_addon` (`ID`, `PrevQuestID`) VALUES
(820066, 820065);

DELETE FROM `quest_offer_reward` WHERE `ID` = 820066;
INSERT INTO `quest_offer_reward` (`ID`, `RewardText`, `VerifiedBuild`) VALUES
(820066, 'Good. Now you know both currencies and both ledgers, and you have not yet killed anything larger than a boar.$B$BHere are your tokens back, $N. Spend them on whatever the crater takes off you first.', 0);

DELETE FROM `creature_queststarter` WHERE `id` = 800009 AND `quest` = 820066;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES (800009, 820066);
DELETE FROM `creature_questender` WHERE `id` = 800009 AND `quest` = 820066;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES (800009, 820066);


-- ====================================================================================
-- TIER B - Jade Forest player base (map 745), level 80
-- ====================================================================================

-- ------------------------------------------------------------------------------------
-- 820062  A Wider World  (auto-granted at level 80 by DCFirstStart)
-- No objective: the quest completes the moment the player finds Vaelin, which is the
-- whole point of the breadcrumb.
-- ------------------------------------------------------------------------------------
DELETE FROM `quest_template` WHERE `ID` = 820062;
INSERT INTO `quest_template`
  (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
   `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardNextQuest`,
   `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES
(820062, 2, 80, 80, 0, 0, 0, 1, 0, 300311, 5, 820063,
 'A Wider World',
 'Travel to the player base in the Jade Forest and find Chronicler Vaelin.',
 'You have reached the eightieth season of your training, $N, and word of it has already travelled.$B$BThere is a place you have not yet seen - a base the champions of Dark Chaos keep in the Jade Forest, far from any crater. Everything that matters after this point is arranged around it: the keystones that reopen the old dungeons under far crueller rules, the quartermasters who deal in currencies you have only just started earning, the halls where guilds keep their own roofs, and the war in the Hinterlands that never quite ends.$B$BYou already know how to upgrade what you carry - Hervikus saw to that on your first day. What waits out there is everything you were not ready for then.$B$BThe Teleporter will carry you - look for the Jadeforest PlayerBase. Ask for Chronicler Vaelin when you arrive. He keeps the primer, and he has been expecting someone like you.',
 'The Jade Forest player base.',
 'Speak with Chronicler Vaelin at the Jade Forest player base.');

DELETE FROM `quest_template_addon` WHERE `ID` = 820062;
INSERT INTO `quest_template_addon` (`ID`, `NextQuestID`) VALUES
(820062, 820063);

DELETE FROM `quest_offer_reward` WHERE `ID` = 820062;
INSERT INTO `quest_offer_reward` (`ID`, `RewardText`, `VerifiedBuild`) VALUES
(820062, 'Ah - the crater sent me another one. Sit, $N, or do not; you will be moving again shortly either way.$B$BI am Vaelin. I keep the record of what champions do after they stop levelling, which is to say I keep the record of what actually matters. Everything here has a door, and every door has someone standing beside it who will explain it exactly once. I will walk you past all of them.$B$BLet us begin with the one that will kill you fastest.', 0);

DELETE FROM `creature_questender` WHERE `id` = 800064 AND `quest` = 820062;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES (800064, 820062);


-- ------------------------------------------------------------------------------------
-- 820063  A Key to the Deeps   (Mythic+, part 1 of 2 - obtain a keystone)
-- Credit fires from npc_keystone_vendor when a keystone is actually handed over, rather
-- than using RequiredItemId: a required item is destroyed on turn-in, and the keystone
-- is the entire point of the quest.
-- ------------------------------------------------------------------------------------
DELETE FROM `quest_template` WHERE `ID` = 820063;
INSERT INTO `quest_template`
  (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
   `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardNextQuest`,
   `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`,
   `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`, `ObjectiveText1`) VALUES
(820063, 2, 80, 80, 0, 0, 0, 1, 0, 300311, 10, 820064,
 'A Key to the Deeps',
 'Receive a Mythic Keystone from the Keystone Vendor, then return to Chronicler Vaelin.',
 'You have cleared dungeons. I am not interested in those.$B$BWhat I am interested in is what happens when you go back into the same dungeon carrying a keystone. The walls do not change. Everything inside them does - faster, angrier, and on a clock. We call it Mythic Plus, and it is graded: a plus two is a warning, and the numbers go a great deal higher than that.$B$BThe Keystone Vendor stands a few paces from me and asks nothing for the first one. Take a key from her. She will always start you at plus two, and if you ever misplace a key she will hold your earned rank until you come back for it.$B$BGo. She is the one who looks bored.',
 'The Jade Forest player base.',
 'Return to Chronicler Vaelin.',
 800060, 1,
 'Mythic Keystone received');

DELETE FROM `quest_template_addon` WHERE `ID` = 820063;
INSERT INTO `quest_template_addon` (`ID`, `PrevQuestID`, `NextQuestID`) VALUES
(820063, 820062, 820064);

DELETE FROM `quest_offer_reward` WHERE `ID` = 820063;
INSERT INTO `quest_offer_reward` (`ID`, `RewardText`, `VerifiedBuild`) VALUES
(820063, 'There it is. Feels like nothing in the hand, does it not.$B$BThat key is on a timer, $N - a week, and then it is dust. Do not hoard it. Keys are meant to be spent.', 0);

DELETE FROM `creature_queststarter` WHERE `id` = 800064 AND `quest` = 820063;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES (800064, 820063);
DELETE FROM `creature_questender` WHERE `id` = 800064 AND `quest` = 820063;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES (800064, 820063);


-- ------------------------------------------------------------------------------------
-- 820064  Into the Breach   (Mythic+, part 2 of 2 - complete a run)
-- Credit fires from MythicPlusRunManager's completion path, per participant.
-- ------------------------------------------------------------------------------------
DELETE FROM `quest_template` WHERE `ID` = 820064;
INSERT INTO `quest_template`
  (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
   `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`,
   `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`,
   `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`, `ObjectiveText1`) VALUES
(820064, 2, 80, 80, 0, 0, 5, 1, 0, 300311, 25,
 'Into the Breach',
 'Complete a Mythic+ dungeon run, then return to Chronicler Vaelin.',
 'A key in the pocket proves nothing, $N. Spend it.$B$BFind four others - this is not a thing you do alone - and take yourself to any dungeon on the Mythic+ roster. Inside, near the entrance, you will find a Font of Power. Use your keystone on it. The font consumes the key, the doors seal behind you, and the clock starts.$B$BClear it. Every required boss, before the timer runs out. Finish inside the par time and the key sharpens itself for next week; finish late and it still counts, but the key does not grow. Fail outright and it dulls.$B$BCome back and tell me how it went. I will believe the version where you nearly died.',
 'Any Mythic+ dungeon.',
 'Return to Chronicler Vaelin.',
 800061, 1,
 'Mythic+ dungeon completed');

DELETE FROM `quest_template_addon` WHERE `ID` = 820064;
INSERT INTO `quest_template_addon` (`ID`, `PrevQuestID`) VALUES
(820064, 820063);

DELETE FROM `quest_offer_reward` WHERE `ID` = 820064;
INSERT INTO `quest_offer_reward` (`ID`, `RewardText`, `VerifiedBuild`) VALUES
(820064, 'You went in with a key and came out with a story. That is the whole loop, $N - there is nothing more to it, and there is no end to it either.$B$BThe Seasonal Quartermaster takes what you earned in there. The Great Vault remembers your best runs each week. And the key in your bag is worth more than the one you started with.$B$BFeed all of it into that ledger Hervikus taught you to open. The prices are simply larger out here.', 0);

DELETE FROM `creature_queststarter` WHERE `id` = 800064 AND `quest` = 820064;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES (800064, 820064);
DELETE FROM `creature_questender` WHERE `id` = 800064 AND `quest` = 820064;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES (800064, 820064);


-- ------------------------------------------------------------------------------------
-- 820067  A Roof of Your Own   (guild housing)
-- Guild House Manager 95103 stands at (867.1, -2694.2, 192.1) on the same map.
-- ------------------------------------------------------------------------------------
DELETE FROM `quest_template` WHERE `ID` = 820067;
INSERT INTO `quest_template`
  (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
   `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`,
   `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`,
   `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`, `ObjectiveText1`) VALUES
(820067, 2, 80, 80, 0, 0, 0, 1, 50000, 300311, 5,
 'A Roof of Your Own',
 'Speak with the Guild House Manager, then return to Chronicler Vaelin.',
 'A guild without a hall is a list of names, $N.$B$BSouth of here, past the inn, the Guild House Manager keeps the deeds. What she sells is a whole quarter of Dalaran - your own, phased away from everyone else''s, with a butler who summons in the trainers and the auction house and the portals so your members never have to leave. The decorator will let you rearrange the furniture down to the candlestick, if that is the sort of guild you run.$B$BYou need a guild to buy one, and rank enough within it to spend the coin. Go and ask her what it costs even if you cannot afford it today. Knowing the number is how people start saving.',
 'South of the player base.',
 'Return to Chronicler Vaelin.',
 95103, 1,
 'Guild House Manager consulted');

DELETE FROM `quest_template_addon` WHERE `ID` = 820067;
INSERT INTO `quest_template_addon` (`ID`, `PrevQuestID`) VALUES
(820067, 820062);

DELETE FROM `quest_offer_reward` WHERE `ID` = 820067;
INSERT INTO `quest_offer_reward` (`ID`, `RewardText`, `VerifiedBuild`) VALUES
(820067, 'Expensive, is it not. It is meant to be - a hall that costs nothing is a hall nobody defends.$B$BWhen your guild does buy one, $N, put the portals in first and the furniture last. I have seen it done the other way and it is a sad thing to watch.', 0);

DELETE FROM `creature_queststarter` WHERE `id` = 800064 AND `quest` = 820067;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES (800064, 820067);
DELETE FROM `creature_questender` WHERE `id` = 800064 AND `quest` = 820067;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES (800064, 820067);


-- ------------------------------------------------------------------------------------
-- 820068  The Hinterlands Burn   (HLBG)
-- Hinterlands Battlemaster 900001 stands at (901.5, -2560.0, 179.8) - same cluster.
-- ------------------------------------------------------------------------------------
DELETE FROM `quest_template` WHERE `ID` = 820068;
INSERT INTO `quest_template`
  (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
   `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardHonor`,
   `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`,
   `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`, `ObjectiveText1`) VALUES
(820068, 2, 80, 80, 0, 0, 0, 1, 50000, 300311, 5, 500,
 'The Hinterlands Burn',
 'Speak with the Hinterlands Battlemaster, then return to Chronicler Vaelin.',
 'One more door, $N, and this one has other champions on the far side of it.$B$BThe Hinterlands never settled. Wildhammer and Revantusk have been at each other over those hills for as long as anyone here has been counting, and we long ago stopped pretending it would end. What we did instead was open it - a standing battleground, both banners, no queue times worth complaining about.$B$BThe Battlemaster stands just there, beside the quartermasters. He will explain the resource count, the capture points, and why Thrall and Varian both turn up in person when it goes badly.$B$BSpeak with him. Whether you queue today is between you and your temper.',
 'The Jade Forest player base.',
 'Return to Chronicler Vaelin.',
 900001, 1,
 'Hinterlands Battlemaster consulted');

DELETE FROM `quest_template_addon` WHERE `ID` = 820068;
INSERT INTO `quest_template_addon` (`ID`, `PrevQuestID`) VALUES
(820068, 820062);

DELETE FROM `quest_offer_reward` WHERE `ID` = 820068;
INSERT INTO `quest_offer_reward` (`ID`, `RewardText`, `VerifiedBuild`) VALUES
(820068, 'That is the last of them, $N. Keystones, gear, legacies, a hall, and a war.$B$BYou will not need me again. Everything from here is repetition, and repetition is where champions are actually made - the primer only ever gets you to the door.$B$BGo on. Something in the Hinterlands is already on fire.', 0);

DELETE FROM `creature_queststarter` WHERE `id` = 800064 AND `quest` = 820068;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES (800064, 820068);
DELETE FROM `creature_questender` WHERE `id` = 800064 AND `quest` = 820068;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES (800064, 820068);


-- ====================================================================================
-- QUEST POI
-- Map 37 uses WorldMapAreaId 613, map 745 uses 1101 (both taken from the rows the
-- existing Azshara Crater / Jade Forest quests already use).
-- Idx1 -1 marks the turn-in box; Flags 3 = objective, 1 = turn-in.
-- ====================================================================================
DELETE FROM `quest_poi_points` WHERE `QuestID` BETWEEN 820060 AND 820068;
DELETE FROM `quest_poi` WHERE `QuestID` BETWEEN 820060 AND 820068;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`) VALUES
-- Tier A - Azshara Crater (map 37 / WMA 613)
(820060, 0,  0, 37, 613, 0, 0, 3, 0),
(820060, 1, -1, 37, 613, 0, 0, 1, 0),
(820061, 0,  0, 37, 613, 0, 0, 3, 0),
(820061, 1, -1, 37, 613, 0, 0, 1, 0),
-- 820065 / 820066 objectives are actions taken through the /upgrade ledger and are not
-- map-bound, so each carries only a turn-in box on Hervikus.
(820065, 0, -1, 37, 613, 0, 0, 1, 0),
(820066, 0, -1, 37, 613, 0, 0, 1, 0),
-- Tier B - Jade Forest player base (map 745 / WMA 1101)
(820062, 0, -1, 745, 1101, 0, 0, 1, 0),
(820063, 0,  0, 745, 1101, 0, 0, 3, 0),
(820063, 1, -1, 745, 1101, 0, 0, 1, 0),
(820064, 0, -1, 745, 1101, 0, 0, 1, 0),
(820067, 0,  0, 745, 1101, 0, 0, 3, 0),
(820067, 1, -1, 745, 1101, 0, 0, 1, 0),
(820068, 0,  0, 745, 1101, 0, 0, 3, 0),
(820068, 1, -1, 745, 1101, 0, 0, 1, 0);

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
-- 820060 objective: Teleporter 800002 at (119.2, 1030.1); turn-in: Hervikus at (130.5, 999.7)
(820060, 0, 0, 119, 1030, 0),
(820060, 1, 0, 130,  999, 0),
-- 820061 objective: Flightmaster 800010 at (76.4, 932.2); turn-in: Hervikus
(820061, 0, 0,  76,  932, 0),
(820061, 1, 0, 130,  999, 0),
-- 820062 turn-in: Chronicler Vaelin at (913.0, -2546.5)
(820062, 0, 0, 913, -2546, 0),
-- 820063 objective: Keystone Vendor 100100 at (909.9, -2533.9); turn-in: Vaelin
(820063, 0, 0, 909, -2533, 0),
(820063, 1, 0, 913, -2546, 0),
-- 820065 / 820066 turn-in: Hervikus at (130.5, 999.7) in the crater
(820065, 0, 0, 130,  999, 0),
(820066, 0, 0, 130,  999, 0),
-- 820064 turn-in: Vaelin (the Mythic+ run itself is not map-bound)
(820064, 0, 0, 913, -2546, 0),
-- 820067 objective: Guild House Manager 95103 at (867.1, -2694.2); turn-in: Vaelin
(820067, 0, 0, 867, -2694, 0),
(820067, 1, 0, 913, -2546, 0),
-- 820068 objective: Hinterlands Battlemaster 900001 at (901.5, -2560.0); turn-in: Vaelin
(820068, 0, 0, 901, -2560, 0),
(820068, 1, 0, 913, -2546, 0);
