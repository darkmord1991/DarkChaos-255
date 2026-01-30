-- ============================================================================
-- Azshara Crater Quest System - SQL Script (REVISED)
-- Zones 1-3: Quest Givers, Existing Item Rewards, Loot Tables
-- ============================================================================
-- CHANGES FROM V1:
--   1. Added creature_template_model entries for all NPCs
--   2. Using EXISTING WotLK items for all rewards (no custom items)
--   3. Added Token (300311) and Essence (300312) to all quest rewards
-- ============================================================================

-- ============================================================================
-- SECTION 1: QUEST GIVER NPCs (creature_template)
-- ============================================================================

-- Zone 1: Scout Thalindra (Night Elf Scout Female)
DELETE FROM `creature_template` WHERE `entry` = 300001;
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(300001, 0, 0, 0,  268, 0, 'Scout Thalindra', 'Crater Reconnaissance', 'quest', 300001, 10, 10, 0, 35, 3, 1, 1.14286, 1, 1, 20, 1, 0, 0, 1, 2000, 2000, 1, 1, 2, 768, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 1.5, 1, 1, 1, 0, 0, 1, 0, 0, 2, '', 12340);

-- Zone 1: Warden Stonebrook (Dwarf Hunter Male)
DELETE FROM `creature_template` WHERE `entry` = 300002;
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(300002, 0, 0, 0,  268, 0, 'Warden Stonebrook', 'Rare Beast Hunter', 'quest', 300002, 12, 12, 0, 35, 3, 1, 1.14286, 1, 1, 20, 1, 0, 0, 1, 2000, 2000, 1, 1, 1, 768, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 2, 1, 1, 1, 0, 0, 1, 0, 0, 2, '', 12340);

-- Zone 2: Arcanist Melia (High Elf Mage Female)
DELETE FROM `creature_template` WHERE `entry` = 300010;
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(300010, 0, 0, 0,  268, 0, 'Arcanist Melia', 'Kirin Tor Researcher', 'quest', 300010, 20, 20, 0, 35, 3, 1, 1.14286, 1, 1, 20, 1, 0, 0, 1, 2000, 2000, 1, 1, 8, 768, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 1.5, 2, 1, 1, 0, 0, 1, 0, 0, 2, '', 12340);

-- Zone 2: Spirit of Kelvenar (Ghostly Highborne Male)
DELETE FROM `creature_template` WHERE `entry` = 300011;
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(300011, 0, 0, 0,  268, 0, 'Spirit of Kelvenar', 'Echo of the Past', 'quest', 300011, 20, 20, 0, 35, 3, 1, 1.14286, 1, 1, 20, 0.9, 0, 0, 1, 2000, 2000, 1, 1, 8, 768, 2048, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 1, 1, 0.5, 1, 0, 0, 1, 0, 0, 2, '', 12340);

-- Zone 3: Pathfinder Gor'nash (Orc Scout Male)
DELETE FROM `creature_template` WHERE `entry` = 300020;
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(300020, 0, 0, 0,  268, 0, 'Pathfinder Gor''nash', 'Eastern Outpost Scout', 'quest', 300020, 30, 30, 0, 35, 3, 1, 1.14286, 1, 1, 20, 1, 0, 0, 1, 2000, 2000, 1, 1, 1, 768, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 2, 1, 1.5, 1, 0, 0, 1, 0, 0, 2, '', 12340);

-- Zone 3: Elder Greymane (Worgen Elder Male - Escort NPC)
DELETE FROM `creature_template` WHERE `entry` = 300021;
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(300021, 0, 0, 0,  268, 0, 'Elder Greymane', 'Thistlefur Prisoner', 'quest', 0, 28, 28, 0, 35, 3, 1, 1.14286, 1, 1, 20, 1.1, 0, 0, 1, 2000, 2000, 1, 1, 2, 768, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 'SmartAI', 0, 1, 3, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_elder_greymane_escort', 12340);

-- Ensure questgiver flag on templates and spawned creatures
UPDATE `creature_template` SET `npcflag` = `npcflag` | 2
WHERE `entry` IN (300001, 300002, 300010, 300011, 300020, 300021);

UPDATE `creature` SET `npcflag` = `npcflag` | 2
WHERE `id1` IN (300001, 300002, 300010, 300011, 300020, 300021);

-- ============================================================================
-- SECTION 2: CREATURE MODEL DATA (creature_template_model)
-- ============================================================================
-- DisplayIDs from existing WotLK NPCs:
--   Night Elf Female Scout: 4301 (like Sentinel)
--   Dwarf Male Hunter: 1349 (like Ironforge Hunter)
--   High Elf Female Mage: 20602 (like Silver Covenant Mage)
--   Ghostly Highborne Male: 10979 (like Highborne Apparition)
--   Orc Male Scout: 4618 (like Orc Hunter)
--   Worgen Male: 30418 (like Worgen in human form)
-- ============================================================================

DELETE FROM `creature_template_model` WHERE `CreatureID` IN (300000, 300001, 300002, 300010, 300011, 300020, 300021);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(300001, 0, 4301, 1, 1, 12340),   -- Scout Thalindra (Night Elf Female Sentinel)
(300002, 0, 1349, 1, 1, 12340),   -- Warden Stonebrook (Dwarf Male)
(300010, 0, 20602, 1, 1, 12340),  -- Arcanist Melia (High Elf Female Mage)
(300011, 0, 10979, 0.9, 1, 12340), -- Spirit of Kelvenar (Ghostly Highborne)
(300020, 0, 4618, 1, 1, 12340),   -- Pathfinder Gor'nash (Orc Male)
(300021, 0, 4618, 1.1, 1, 12340); -- Elder Greymane (Worgen Male Human Form)

-- UPDATE GOSSIP MENU IDs for Quest Givers (To match Section 9)
UPDATE `creature_template` SET `gossip_menu_id` = 300001 WHERE `entry` = 300001; -- Scout Thalindra
UPDATE `creature_template` SET `gossip_menu_id` = 300002 WHERE `entry` = 300002; -- Warden Stonebrook
UPDATE `creature_template` SET `gossip_menu_id` = 300010 WHERE `entry` = 300010; -- Arcanist Melia
UPDATE `creature_template` SET `gossip_menu_id` = 300011 WHERE `entry` = 300011; -- Spirit of Kelvenar
UPDATE `creature_template` SET `gossip_menu_id` = 300020 WHERE `entry` = 300020; -- Pathfinder Gor'nash

-- ============================================================================
-- SECTION 3: QUEST REWARD REFERENCE (USING EXISTING WOTLK ITEMS)
-- ============================================================================
-- Zone 1 (Level 1-10) - Use low-level green/blue items
--   Quest 1: 6-slot bag (4496 - Small Brown Pouch) + 1 Token + 1 Essence
--   Quest 2: Green Leather Gloves (7279 - Regal Gloves) + 2 Token + 1 Essence
--   Quest 3: 5 Silver + 2 Token + 1 Essence
--   Quest 4: Green Wand (5239 - Black Widow Wand) + 2 Token + 2 Essence
--   Quest 5: Green Cloth Bracers (3321 - Twilight Gloves reskin) + 3 Token + 2 Essence
--   Quest 6: Blue Dagger (12252 - Scepter of Celebras, repurpose) + 5 Token + 3 Essence
--   Quest 7: XP + Flight path unlock + 3 Token + 2 Essence
--
-- Zone 2 (Level 10-20) - Use mid-level green/blue items
--   Quest 1: Green Ring (2951 - Glinting Scale Ring) + 3 Token + 2 Essence
--   Quest 2: Green Cloth Head (6467 - Deviate Scale Gloves alt) + 4 Token + 2 Essence
--   Quest 3: 8-slot bag (804 - Large Blue Sack) + 4 Token + 3 Essence
--   Quest 4: Buff reward (consumable) + 3 Token + 2 Essence
--   Quest 5: Green Sword (3191 - Brutish Sword) + 5 Token + 3 Essence
--   Quest 6: Blue Neck (6392 - Silver Bar Quest Reward) + 6 Token + 4 Essence
--   Quest 7: XP + 4 Token + 3 Essence
--
-- Zone 3 (Level 20-30) - Use higher-level green/blue items
--   Quest 1: Timbermaw Rep + Green Leather Boots (3310 - Ceremonial Leather Gloves alt) + 5 Token + 3 Essence
--   Quest 2: Timbermaw Rep + 5 Token + 3 Essence
--   Quest 3: Green 1H Mace (4121 - Gemmed Copper Gauntlets alt weapon) + 6 Token + 4 Essence
--   Quest 4: Green Ring (6330 - Stonecutter Claymore alt) + 6 Token + 4 Essence
--   Quest 5: Green Back (4700 - Inscribed Leather Gloves alt) + 7 Token + 5 Essence
--   Quest 6: Blue 2H Staff (15274 - Inlaid Mithril Cylinder) + 10 Token + 6 Essence
--   Quest 7: XP + 5 Token + 4 Essence
--
-- ============================================================================
-- NOTE: quest_template entries with RewardItem columns would reference:
--   RewardItem1 = existing WotLK item ID
--   RewardAmount1 = 1
--   RewardItem2 = 300311 (Token)
--   RewardAmount2 = X (varies by quest)
--   RewardItem3 = 300312 (Essence)
--   RewardAmount3 = Y (varies by quest)
-- ============================================================================

-- ============================================================================
-- SECTION 4: LOOT ITEMS (Using existing WotLK items - NO CUSTOM ITEMS)
-- ============================================================================

-- Clean up orphaned quests with invalid data from previous versions
DELETE FROM `quest_template` WHERE `ID` IN (300405, 300406, 300603, 300705);
DELETE FROM `creature_queststarter` WHERE `quest` IN (300405, 300406, 300603, 300705);
DELETE FROM `creature_questender` WHERE `quest` IN (300405, 300406, 300603, 300705);
DELETE FROM `quest_request_items` WHERE `ID` IN (300405, 300406, 300603, 300705);
DELETE FROM `quest_offer_reward` WHERE `ID` IN (300405, 300406, 300603, 300705);

-- ============================================================================
-- Zone 1: Use existing low-level materials
--   Boar Meat: 769 (Roasted Boar Meat)
--   Wolf Pelt: 754 (Light Hide)
--   Spider Silk: 4306 (Silk Cloth) or 3182 (Spider's Silk)
--   Rare Drop: Use existing gems/greens
--
-- Zone 2: Use existing mid-level materials
--   Bone Fragment: 2665 (Stormwind Guard Leggings alt) or 11078 (Bone Fragment)
--   Ghost Essence: Custom quest item needed for quest only
--   Void Shard: 1529 (Jade)
--   Rare Drop: Use existing rings/jewelry
--
-- Zone 3: Use existing higher-level materials
--   Thick Leather: 4234 (Heavy Leather)
--   Spirit Dust: 11137 (Vision Dust)
--   Furbolg items: 11754 (Black Diamond) etc.
-- ============================================================================

-- Zone 1 NPCs - Using existing WotLK loot items

-- ============================================================================
-- SECTION 5: QUEST REWARD SUMMARY (Reference for quest_template)
-- ============================================================================
-- When creating quest_template entries, use these reward configurations:
--
-- ZONE 1 QUESTS (Level 1-10):
-- | Quest | Item Reward | Token (300311) | Essence (300312) |
-- |-------|-------------|----------------|------------------|
-- | Welcome to Crater | 4496 (6-slot bag) | 1 | 1 |
-- | Wildlife Survey | 7279 (Gloves) | 2 | 1 |
-- | Bear Bounty | 5 Silver | 2 | 1 |
-- | Strange Energies | 5239 (Wand) | 2 | 2 |
-- | Web of Danger | 3321 (Bracers) | 3 | 2 |
-- | Ancient's Lair | 12252 (Blue Dagger) | 5 | 3 |
-- | Report to North | XP + Flight | 3 | 2 |
--
-- ZONE 2 QUESTS (Level 10-20):
-- | Quest | Item Reward | Token (300311) | Essence (300312) |
-- |-------|-------------|----------------|------------------|
-- | Haunted Grounds | 2951 (Ring) | 3 | 2 |
-- | Spectral Samples | 6467 (Cloth Helm) | 4 | 2 |
-- | Ancient Relics | 804 (8-slot bag) | 4 | 3 |
-- | Commune Spirit | Buff consumable | 3 | 2 |
-- | Wailing Noble | 3191 (Sword) | 5 | 3 |
-- | Varo'then Journal | 6392 (Blue Neck) | 6 | 4 |
-- | Into Slopes | XP | 4 | 3 |
--
-- ZONE 3 QUESTS (Level 20-30):
-- | Quest | Item Reward | Token (300311) | Essence (300312) |
-- |-------|-------------|----------------|------------------|
-- | Proving Grounds | 3310 (Boots) + Rep | 5 | 3 |
-- | Supply Run | Rep only | 5 | 3 |
-- | Totem Destruction | 4121 (Mace) | 6 | 4 |
-- | Elder's Request | 6330 (Ring) | 6 | 4 |
-- | Corruption Source | 4700 (Cloak) | 7 | 5 |
-- | Cleansing Ritual | 15274 (Blue Staff) | 10 | 6 |
-- | "Furbolg Resources" | Consumables | 5 | 3 |
-- | Murloc Menace | 1468 (Fin) | 8 | 5 |
-- | Elemental Imbalance | 7079 (Globe) | 6 | 4 |
-- | Crocolisk Crisis | 2924 (Meat) | 8 | 5 |
-- | River Awaits | XP | 5 | 4 |
--
-- ============================================================================
-- SECTION 6: QUEST TEMPLATES (quest_template)
-- ============================================================================
-- Quest IDs:
--   Zone 1: 300100 - 300106
--   Zone 2: 300200 - 300206
--   Zone 2: 300200 - 300206, 300207, 300208
--   Zone 3: 300300 - 300306, 300307, 300308
-- ============================================================================

DELETE FROM `quest_template` WHERE `ID` BETWEEN 300100 AND 300308;

-- ----------------------------------------------------------------------------
-- ZONE 1 QUESTS (Level 1-10) - Scout Thalindra (300001)
-- ----------------------------------------------------------------------------

-- Quest 1: Welcome to Crater (Talk to Thalindra)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES
(300100, 2, 1, 1,  268, 0, 0, 3, 0, 117, 5, 300311, 1, 300312, 1, 'Welcome to Crater', 'Speak with Scout Thalindra at the outpost.', 'Welcome, adventurer! This crater is dangerous, but we have established a foothold. Take this supply bag to get started.', 'Azshara Crater', 'You have reported for duty.');

-- Quest 2: Wildlife Survey (Kill Boars and Wolves)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGo2`, `RequiredNpcOrGoCount2`) VALUES
(300101, 2, 4, 1,  268, 0, 0, 3, 0, 38, 1, 300311, 2, 300312, 1, 'Wildlife Survey', 'Kill 6 Young Thistle Boars and 6 Mangy Wolves.', 'The local wildlife is aggressive. We need to clear the area around the camp. Thin out the boars and wolves.', 'Azshara Crater', 'Usage of local wildlife controlled.', 1984, 6, 525, 6);

-- Quest 3: Bear Bounty (Kill Bears)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300102, 2, 6, 2,  268, 0, 0, 3, 500, 300311, 2, 300312, 1, 0, 0, 'Bear Bounty', 'Kill 8 Young Forest Bears.', 'The bears have been encroaching on our supplies. Eliminate them and I will reward you with coin.', 'Azshara Crater', 'Bears defeated.', 822, 8);

-- Quest 4: Strange Energies (Kill Timberlings)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300103, 2, 8, 4,  268, 0, 0, 3, 0, 35, 1, 300311, 2, 300312, 2, 'Strange Energies', 'Kill 8 Timberlings.', 'The elementals here act strangely. Defeat the Timberlings to study their essence.', 'Azshara Crater', 'Timberlings defeated.', 2022, 8);

-- Quest 5: Web of Danger (Kill Spiders)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300104, 2, 9, 5,  268, 0, 0, 3, 0, 25, 1, 300311, 3, 300312, 2, 'Web of Danger', 'Kill 10 Webwood Lurkers.', 'Spiders infest the northern ridge. Clear them out before they overrun us.', 'Azshara Crater', 'Spiders cleared.', 1998, 10);

-- Quest 6: Ancient''s Lair (Boss Kill - Kill 12 Timberlings as placeholder for boss event)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300105, 2, 10, 7,  268, 0, 0, 4, 0, 209, 1, 300311, 5, 300312, 3, 'Ancient''s Lair', 'Defeat 12 Timberlings.', 'We believe an ancient force drives them. Thin their numbers significantly to draw it out.', 'Azshara Crater', 'Threat reduced.', 2022, 12);

-- Quest 7: Report to North (Travel Quest)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES
(300106, 2, 10, 8,  268, 0, 0, 5, 0, 118, 5, 300311, 3, 300312, 2, 'Report to North', 'Travel to the northern checkpoint and inspect the area.', 'Your work here is done. Scout the northern pass for our next expansion.', 'Azshara Crater', 'Area inspected.');

-- Quest 8: Pelt Collection (Collect Light Hide)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredItemId1`, `RequiredItemCount1`) VALUES
(300107, 2, 5, 2,  268, 0, 0, 3, 0, 117, 5, 300311, 2, 300312, 1, 'Pelt Collection', 'Collect 8 Light Hides.', 'The outpost needs warm bedding. Collect hides from the wolves nearby.', 'Azshara Crater', 'Hides collected.', 783, 8);

-- ----------------------------------------------------------------------------
-- ZONE 2 QUESTS (Level 10-20) - Arcanist Melia (300010)
-- ----------------------------------------------------------------------------

-- Quest 1: Haunted Grounds (Kill Skeletons)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300200, 2, 12, 10,  268, 0, 0, 3, 0, 837, 1, 300311, 3, 300312, 2, 'Haunted Grounds', 'Kill 10 Dreadbone Skeletons.', 'The ruins ahead are haunted by the restless dead. Put them to rest.', 'Azshara Crater', 'Skeletons defeated.', 16303, 10);

-- Quest 2: Spectral Samples (Kill Voidwalkers)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300201, 2, 14, 11,  268, 0, 0, 3, 0, 846, 1, 300311, 4, 300312, 2, 'Spectral Samples', 'Kill 8 Lesser Voidwalkers.', 'Void energies permeate this place. Destroy the voidwalkers manifesting near the ley lines.', 'Azshara Crater', 'Voidwalkers banished.', 418, 8);

-- Quest 3: Ancient Relics (Kill Golems)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300202, 2, 16, 12,  268, 0, 0, 3, 0, 804, 1, 300311, 4, 300312, 3, 'Ancient Relics', 'Destroy 8 Harvest Golems.', 'These constructs have gone haywire. Dismantle them so we can salvage their parts.', 'Azshara Crater', 'Golems dismantled.', 36, 8);

-- Quest 4: Commune Spirit (Talk to Spirit of Kelvenar)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES
(300203, 2, 16, 13,  268, 0, 0, 3, 0, 118, 5, 300311, 3, 300312, 2, 'Commune with Spirit', 'Speak with the Spirit of Kelvenar nearby.', 'A ghost wanders these ruins. He does not seem hostile. See if he knows the history of this place.', 'Azshara Crater', 'Spirit spoken to.');

-- Quest 5: Wailing Noble (Kill Skeletal Warriors)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300204, 2, 18, 14,  268, 0, 0, 3, 0, 852, 1, 300311, 5, 300312, 3, 'The Wailing Noble', 'Defeat 12 Skeletal Warriors.', 'The elite guard of the old Highborne still serves in death. Break their ranks.', 'Azshara Crater', 'Guards defeated.', 48, 12);

-- Quest 6: Varo''then''s Journal (Collect Item quest - using Dummy Item for now or Kill Trigger)
-- Using Kill Trigger for simplicity (Kill 1 Skeletal Warrior labeled as 'Varo'then's Guard' conceptually)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300205, 2, 19, 15,  268, 0, 0, 4, 0, 858, 3, 300311, 6, 300312, 4, 'Varo''then''s Journal', 'Retrieve the Journal from the ruins (Kill 15 Skeletons).', 'Somewhere in these piles of bones is a journal of the Highborne. Find it.', 'Azshara Crater', 'Journal found.', 16303, 15);

-- Quest 7: Into the Slopes (Travel)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES
(300206, 2, 20, 16,  268, 0, 0, 5, 0, 300311, 4, 300312, 3, 0, 0, 'Into the Slopes', 'Proceed to the eastern slopes and find the Orc Scout.', 'The magical interference is stronger to the east. Go there and meet our scout.', 'Azshara Crater', 'Scout found.');

-- Quest 8: Dust to Dust (Collect Gold Dust)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredItemId1`, `RequiredItemCount1`) VALUES
(300207, 2, 15, 12,  268, 0, 0, 3, 0, 300311, 3, 300312, 2, 0, 0, 'Dust to Dust', 'Collect 10 Gold Dust.', 'The bones of these skeletons are infused with magic. Bring me samples of their dust for study.', 'Azshara Crater', 'Dust collected.', 773, 10);

-- ----------------------------------------------------------------------------
-- ZONE 3 QUESTS (Level 20-30) - Pathfinder Gor'nash (300020)
-- ----------------------------------------------------------------------------

-- Quest 1: Proving Strength (Kill Satyrs)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300300, 2, 22, 18,  268, 0, 0, 3, 0, 847, 1, 300311, 4, 300312, 2, 'Proving Strength', 'Kill 10 Haldarr Satyrs (or any Satyr).', 'The Satyrs to the east are a plague. Show me your strength by slaying them.', 'Azshara Crater', 'Satyrs slain.', 2044, 10);

-- Quest 2: Satyr Horns (Collect Item)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredItemId1`, `RequiredItemCount1`) VALUES
(300301, 2, 24, 20,  268, 0, 0, 3, 0, 300311, 5, 300312, 3, 0, 0, 'Satyr Horns', 'Collect 10 Satyr Horns.', 'Their horns can be ground into a powerful powder. Bring me a dozen.', 'Azshara Crater', 'Horns collected.', 21974, 10);

-- Quest 3: Destroy The Totem (Object Interaction - using Kill Credit or Dummy Object)
-- Using Kill Credit NPC for "Totem Destroyed"
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300302, 2, 25, 21,  268, 0, 0, 3, 0, 1296, 1, 300311, 5, 300312, 3, 'Smash the Totems', 'Destroy 5 Thistlefur Totems.', 'The Furbolgs use totems to channel their dark magic. Smash them.', 'Azshara Crater', 'Totems smashed.', 3922, 5);

-- Quest 4: Elder''s Request (Rescue Elder Greymane)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300303, 2, 26, 23,  268, 0, 0, 3, 0, 851, 1, 300311, 6, 300312, 4, 'Elder''s Request', 'Kill Thistlefur Shamans (10).', 'They hold an elder prisoner. We must weaken their magic before we can free him. Kill their Shamans.', 'Azshara Crater', 'Shamans defeated.', 3924, 10);

-- Quest 5: Corruption Source (Kill more Avengers)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300304, 2, 28, 24,  268, 0, 0, 3, 0, 862, 1, 300311, 7, 300312, 5, 'Source of Corruption', 'Kill 15 Thistlefur Avengers.', 'The corruption flows from the top. Cut down their elite guards.', 'Azshara Crater', 'Elites defeated.', 3925, 15);

-- Quest 6: Cleansing Ritual (Kill mass Thistlefurs)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300305, 2, 30, 25,  268, 0, 0, 4, 0, 929, 5, 300311, 10, 300312, 6, 'Cleansing Ritual', 'Defeat 20 Thistlefurs of any kind.', 'We are ready to drive them out completely. Launch a full assault.', 'Azshara Crater', 'Assault successful.', 3926, 20);

-- Quest 7: The River Awaits (Final XP)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES
(300306, 2, 30, 25,  268, 0, 0, 5, 0, 300311, 5, 300312, 4, 0, 0, 'The River Awaits', 'Return to Scout Thalindra.', 'You have done well. Return to the outpost and report our victory.', 'Azshara Crater', 'Victory reported.');

-- Quest 8: Furbolg Resources (Collect Gnoll War Beads)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredItemId1`, `RequiredItemCount1`) VALUES
(300307, 2, 23, 20,  268, 0, 0, 3, 0, 118, 5, 300311, 5, 300312, 3, 'Furbolg Beads', 'Collect 10 Gnoll War Beads.', 'The Furbolgs carry beads similar to Gnolls. Collect them for analysis.', 'Azshara Crater', 'Beads collected.', 527, 10);

-- ----------------------------------------------------------------------------
-- WATER QUESTS (Zones 1-3) - Using Existing WotLK NPCs
-- ----------------------------------------------------------------------------

-- Quest: Murloc Menace (Zone 1 - Level 8)
-- Kill 10 Murloc Foragers (Entry 46)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300108, 2, 8, 5,  268, 0, 0, 3, 0, 36, 1, 300311, 3, 300312, 2, 'Murloc Menace', 'Slay 10 Murloc Foragers along the coast.', 'The murlocs along the newly formed coast are becoming a nuisance. They are encroaching on our supply lines.\\n\\nThin their numbers, $N. Show them this crater belongs to us.', 'Azshara Crater', 'Slay 10 Murloc Foragers.', 46, 10);

-- Quest: Elemental Imbalance (Zone 2 - Level 18)
-- Kill 8 Corrupt Water Spirits (Entry 5897)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300208, 2, 18, 14,  268, 0, 0, 3, 0, 159, 5, 300311, 5, 300312, 3, 'Elemental Imbalance', 'Defeat 8 Corrupt Water Spirits.', 'The water elementals here have become unstable. Their corruption threatens the ley lines.\\n\\nDestroy them before they can spread further.', 'Azshara Crater', 'Defeat 8 Corrupt Water Spirits.', 5897, 8);

-- Quest: Crocolisk Crisis (Zone 3 - Level 25)
-- Kill 6 Giant Wetlands Crocolisks (Entry 2089)
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`) VALUES
(300308, 2, 25, 21,  268, 0, 0, 3, 0, 200, 1, 300311, 6, 300312, 4, 'Crocolisk Crisis', 'Hunt 6 Giant Wetlands Crocolisks.', 'The river crocolisks have grown massive and aggressive. They threaten our supply routes.\\n\\nHunt them down before they attack the caravan.', 'Azshara Crater', 'Hunt 6 Giant Wetlands Crocolisks.', 2089, 6);

-- ============================================================================
-- SECTION 7: NPC QUEST RELATIONS (creature_queststarter / creature_questender)
-- ============================================================================

-- Cleanup existing relations for these NPCs
DELETE FROM `creature_queststarter` WHERE `id` IN (300001, 300002, 300010, 300011, 300020, 300021);
DELETE FROM `creature_questender` WHERE `id` IN (300001, 300002, 300010, 300011, 300020, 300021);

-- ----------------------------------------------------------------------------
-- ZONE 1: Scout Thalindra (300001)
-- ----------------------------------------------------------------------------
-- Starters
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(300001, 300100), -- Welcome to Crater
(300001, 300103), -- Strange Energies
(300001, 300106), -- Report to North
(300001, 300108); -- Murloc Menace

-- ----------------------------------------------------------------------------
-- ZONE 1: Warden Stonebrook (300002)
-- ----------------------------------------------------------------------------
-- Starters
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(300002, 300101), -- Wildlife Survey
(300002, 300102), -- Bear Bounty
(300002, 300104), -- Web of Danger
(300002, 300105), -- Ancient's Lair
(300002, 300107); -- Pelt Collection

-- Enders
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(300001, 300100), -- Welcome to Crater (Self-complete)
(300001, 300103), -- Strange Energies
(300001, 300108), -- Murloc Menace
(300001, 300306); -- The River Awaits (Return from Zone 3)

-- Enders (Stonebrook)
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(300002, 300101), -- Wildlife Survey
(300002, 300102), -- Bear Bounty
(300002, 300104), -- Web of Danger
(300002, 300105), -- Ancient's Lair
(300002, 300107); -- Pelt Collection

-- ----------------------------------------------------------------------------
-- ZONE 2: Arcanist Melia (300010)
-- ----------------------------------------------------------------------------
-- Starters
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(300010, 300200), -- Haunted Grounds
(300010, 300201), -- Spectral Samples
(300010, 300202), -- Ancient Relics
(300010, 300203), -- Commune with Spirit
(300010, 300206), -- Into the Slopes
(300010, 300207), -- Dust to Dust
(300010, 300208); -- Elemental Imbalance

-- Enders
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(300010, 300106), -- Report to North (Arrive from Zone 1)
(300010, 300200), -- Haunted Grounds
(300010, 300201), -- Spectral Samples
(300010, 300202), -- Ancient Relics
(300010, 300207), -- Dust to Dust
(300010, 300208); -- Elemental Imbalance

-- ----------------------------------------------------------------------------
-- ZONE 2: Spirit of Kelvenar (300011)
-- ----------------------------------------------------------------------------
-- Starters
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(300011, 300204), -- The Wailing Noble
(300011, 300205); -- Varo'then's Journal

-- Enders
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(300011, 300203), -- Commune with Spirit (Arrive from Melia)
(300011, 300204), -- The Wailing Noble
(300011, 300205); -- Varo'then's Journal


-- ----------------------------------------------------------------------------
-- ZONE 3: Pathfinder Gor'nash (300020)
-- ----------------------------------------------------------------------------
-- Starters
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(300020, 300300), -- Proving Grounds
(300020, 300301), -- Supply Run
(300020, 300302), -- Totem Destruction
(300020, 300303), -- Elder's Request
(300020, 300304), -- Source of Corruption
(300020, 300305), -- Cleansing Ritual
(300020, 300306), -- The River Awaits
(300020, 300307), -- Furbolg Resources
(300020, 300308); -- Crocolisk Crisis

-- Enders
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(300020, 300206), -- Into the Slopes (Arrive from Zone 2)
(300020, 300300), -- Proving Grounds
(300020, 300301), -- Supply Run
(300020, 300302), -- Totem Destruction
(300020, 300303), -- Elder's Request
(300020, 300304), -- Source of Corruption
(300020, 300305), -- Cleansing Ritual
(300020, 300307), -- Furbolg Resources
(300020, 300308); -- Crocolisk Crisis

-- ----------------------------------------------------------------------------
-- ZONE 3: Elder Greymane (300021)
-- ----------------------------------------------------------------------------
-- Currently not assigned quest starts/ends to simplify flow and avoid phasing issues.
-- Can be added later if "Elder's Request" becomes an actual delivery quest.

-- ============================================================================
-- SECTION 8: QUEST TEXTS (quest_offer_reward / quest_request_items)
-- ============================================================================
-- Used when turning in quest (OfferReward) or returning incomplete (RequestItems)
-- IDs match Quest IDs
-- ============================================================================

DELETE FROM `quest_offer_reward` WHERE `ID` BETWEEN 300100 AND 300308;
DELETE FROM `quest_request_items` WHERE `ID` BETWEEN 300100 AND 300308;

-- ZONE 1 QUESTS
INSERT INTO `quest_offer_reward` (`ID`, `RewardText`) VALUES
(300100, 'Excellent. We need everyone we can get. The crater is teeming with hostiles.'),
(300101, 'Good work. The camp is safer now, thanks to you.'),
(300102, 'Hah! That will teach them to steal our rations. Here is your bounty.'),
(300103, 'Fascinating... the elemental energies are indeed turbulent. This requires further study.'),
(300104, 'Disgusting creatures. I am glad they are gone. Well done.'),
(300105, 'You faced them and returned? Impressive. Perhaps we have a chance here after all.'),
(300106, 'The northern pass is secure? Good. We can proceed with the expansion.'),
(300107, 'These pelts will keep us warm during the cold nights. Thank you.');

INSERT INTO `quest_request_items` (`ID`, `CompletionText`) VALUES
(300100, 'Have you spoken to Scout Thalindra yet?'),
(300101, 'The wildlife is still a threat. Have you thinned their numbers?'),
(300102, 'I still see bears roaming near our supplies. Deal with them.'),
(300103, 'Have you collected the essence from the Timberlings?'),
(300104, 'The spiders are still a menace. Return when you have cleared them.'),
(300105, 'The ancient threat still looms. Do not return until the deed is done.'),
(300106, 'Have you inspected the northern checkpoint?'),
(300107, 'We need more pelts. The winter will be harsh.');

-- ZONE 2 QUESTS
INSERT INTO `quest_offer_reward` (`ID`, `RewardText`) VALUES
(300200, 'The restless dead have been quieted... for now. Thank you.'),
(300201, 'Void energies... disturbing. I will dispose of these samples properly.'),
(300202, 'Excellent. These parts will be useful for our own constructs.'),
(300203, 'He spoke to you? Amazing. The history of this place is tragic indeed.'),
(300204, 'The Wailing Noble has been silenced. His torment is over.'),
(300205, 'This journal... it confirms my suspicions. The Highborne were meddling with dangerous powers.'),
(300206, 'You made it. The Orc scout has been waiting for you.'),
(300207, 'This dust... it hums with arcane energy. A potent reagent, indeed.');

INSERT INTO `quest_request_items` (`ID`, `CompletionText`) VALUES
(300200, 'The skeletons still rattle in the ruins. Have you destroyed them?'),
(300201, 'The voidwalkers are still manifesting. We need more samples.'),
(300202, 'The golems are still active. Dismantle them.'),
(300203, 'The spirit is still waiting for you. Do not be afraid.'),
(300204, 'The Wailing Noble still commands his guard. Defeat them.'),
(300205, 'Have you found the journal yet? It must be in the ruins somewhere.'),
(300206, 'The eastern slopes are dangerous. Have you found the scout?'),
(300207, 'I need more bone dust for my experiments. Return when you have it.');

-- ZONE 3 QUESTS
INSERT INTO `quest_offer_reward` (`ID`, `RewardText`) VALUES
(300300, 'Hmph. Not bad for an outsider. The Furbolgs will think twice now.'),
(300301, 'That will show them. Our supplies are safe for the moment.'),
(300302, 'The totems are destroyed? Good. Their dark magic weakens.'),
(300303, 'You killed their shamans? The Elder will be pleased to hear this.'),
(300304, 'Their elite guard is broken. The corruption is stemming.'),
(300305, 'A glorious battle! The Thistlefurs are in retreat. Victory is ours!'),
(300306, 'You have returned. Thalindra will be glad to hear of our success in the east.'),
(300307, 'This leather is tough. It will make excellent armor for our troops.');

INSERT INTO `quest_request_items` (`ID`, `CompletionText`) VALUES
(300300, 'The Furbolg scouts are still prowling. Kill them.'),
(300301, 'They still raid our camps. Kill the Avengers.'),
(300302, 'The totems still stand. Destroy the totemics who guard them.'),
(300303, 'The shamans still channel their magic. Stop them.'),
(300304, 'The source of corruption remains. Kill the Avengers.'),
(300305, 'The battle is not over. Defeat more Thistlefurs!'),
(300306, 'Have you reported our victory to Thalindra?'),
(300307, 'We need more leather. The Furbolgs have plenty.');

-- ============================================================================
-- SECTION 8: SEASONAL REWARD HOOKS (dc_seasonal_quest_rewards)
-- ============================================================================
-- Populate seasonal rewards for Azshara Crater quests in this file.
-- Uses token/essence amounts from quest_template reward items (300311/300312).

INSERT INTO `dc_seasonal_quest_rewards`
	(`season_id`, `quest_id`, `reward_type`, `base_token_amount`, `base_essence_amount`,
	 `quest_difficulty`, `seasonal_multiplier`, `is_daily`, `is_weekly`, `enabled`)
SELECT
	1 AS season_id,
	q.ID AS quest_id,
	CASE
		WHEN q.token_amt > 0 AND q.essence_amt > 0 THEN 3
		WHEN q.token_amt > 0 THEN 1
		WHEN q.essence_amt > 0 THEN 2
		ELSE 3
	END AS reward_type,
	q.token_amt,
	q.essence_amt,
	2 AS quest_difficulty,
	1.0 AS seasonal_multiplier,
	0 AS is_daily,
	0 AS is_weekly,
	1 AS enabled
FROM (
	SELECT
		`ID`,
		(IF(`RewardItem1` = 300311, `RewardAmount1`, 0)
		 + IF(`RewardItem2` = 300311, `RewardAmount2`, 0)
		 + IF(`RewardItem3` = 300311, `RewardAmount3`, 0)) AS token_amt,
		(IF(`RewardItem1` = 300312, `RewardAmount1`, 0)
		 + IF(`RewardItem2` = 300312, `RewardAmount2`, 0)
		 + IF(`RewardItem3` = 300312, `RewardAmount3`, 0)) AS essence_amt
	FROM `quest_template`
	WHERE `ID` BETWEEN 300100 AND 300308
) q
WHERE q.token_amt > 0 OR q.essence_amt > 0
ON DUPLICATE KEY UPDATE
	`reward_type` = VALUES(`reward_type`),
	`base_token_amount` = VALUES(`base_token_amount`),
	`base_essence_amount` = VALUES(`base_essence_amount`),
	`quest_difficulty` = VALUES(`quest_difficulty`),
	`seasonal_multiplier` = VALUES(`seasonal_multiplier`),
	`enabled` = VALUES(`enabled`),
	`updated_at` = CURRENT_TIMESTAMP;

-- ============================================================================
-- SECTION 9: NPC GOSSIP (npc_text / gossip_menu)
-- ============================================================================

DELETE FROM `npc_text` WHERE `ID` IN (300001, 300002, 300010, 300011, 300020);
DELETE FROM `gossip_menu` WHERE `MenuID` IN (300001, 300002, 300010, 300011, 300020);

-- Scout Thalindra (300001)
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`) VALUES
(300001, 'Greetings, traveler. Welcome to Azshara Crater. We are holding the line here, but threats encroach from all sides.', 'Greetings, traveler. Welcome to Azshara Crater. We are holding the line here, but threats encroach from all sides.');

INSERT INTO `gossip_menu` (`MenuID`, `TextID`) VALUES
(300001, 300001);

-- Warden Stonebrook (300002)
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`) VALUES
(300002, 'The beasts of this crater are unlike any I have seen. Watch yourself.', 'The beasts of this crater are unlike any I have seen. Watch yourself.');

INSERT INTO `gossip_menu` (`MenuID`, `TextID`) VALUES
(300002, 300002);

-- Arcanist Melia (300010)
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`) VALUES
(300010, 'The magical energies in this crater are... peculiar. Ancient Highborne magic mixed with something else. It warrants investigation.', 'The magical energies in this crater are... peculiar. Ancient Highborne magic mixed with something else. It warrants investigation.');

INSERT INTO `gossip_menu` (`MenuID`, `TextID`) VALUES
(300010, 300010);

-- Spirit of Kelvenar (300011)
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`) VALUES
(300011, 'My people... they suffer even in death. The echo of our fall still resonates here.', 'My people... they suffer even in death. The echo of our fall still resonates here.');

INSERT INTO `gossip_menu` (`MenuID`, `TextID`) VALUES
(300011, 300011);

-- Pathfinder Gor'nash (300020)
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`) VALUES
(300020, 'Lok''tar! The Furbolgs here are corrupted by a dark power. We will purge them.', 'Lok''tar! The Furbolgs here are corrupted by a dark power. We will purge them.');

INSERT INTO `gossip_menu` (`MenuID`, `TextID`) VALUES
(300020, 300020);

-- ============================================================================
-- END OF SQL SCRIPT
-- ============================================================================

-- ============================================================================
-- END OF SQL SCRIPT
-- ============================================================================

