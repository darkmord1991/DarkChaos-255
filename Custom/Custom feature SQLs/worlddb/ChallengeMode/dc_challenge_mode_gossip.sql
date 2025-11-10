-- =====================================================================
-- DarkChaos-255 Challenge Mode Gossip Menus
-- =====================================================================
-- Creates gossip menus for the challenge mode gameobject AND prestige challenges
-- These are required for gossip text to display properly
-- =====================================================================

-- Delete existing entries
DELETE FROM `gossip_menu` WHERE `MenuID` BETWEEN 70001 AND 70030;
DELETE FROM `npc_text` WHERE `ID` BETWEEN 70001 AND 70030;

-- =====================================================================
-- NPC Text Entries (shown when opening gossip)
-- =====================================================================

-- Main menu text
INSERT INTO `npc_text` (`ID`, `text0_0`) VALUES
(70001, 'You feel a strange presence as you stand before this ancient idol.\n\nThe Challenge Mode Manager allows you to activate special gameplay modes that will test your skills and determination.\n\nSelect a mode to learn more about it.');

-- Prestige Challenges Info
INSERT INTO `npc_text` (`ID`, `text0_0`) VALUES
(70010, '|cFFFFD700=== PRESTIGE CHALLENGES ===|r\n\nOptional hard mode challenges for prestige leveling!\n\n|cFF00FF00[Iron Prestige]|r\n• Reach level 255 without dying\n• Rewards: Special title + 2% permanent stats\n• Difficulty: Extreme\n\n|cFF00FF00[Speed Prestige]|r\n• Reach level 255 in <100 hours played\n• Rewards: Special title + 2% permanent stats\n• Difficulty: High\n\n|cFF00FF00[Solo Prestige]|r\n• Reach level 255 without joining groups\n• Rewards: Special title + 2% permanent stats\n• Difficulty: Medium\n\nYou can attempt multiple challenges simultaneously!\nUse .prestige challenge commands to manage.');

-- Alt Bonus Info
INSERT INTO `npc_text` (`ID`, `text0_0`) VALUES
(70011, '|cFFFFD700=== ALT-FRIENDLY XP BONUS ===|r\n\nAccount-wide progression system!\n\n• Gain |cFF00FF00+5% XP bonus|r per max-level (255) character on your account\n• Maximum |cFF00FF00+25% bonus|r (capped at 5 characters)\n• Bonus applies automatically to all XP gains\n• Only non-max-level characters receive the bonus\n\nExample:\n• 1 max-level char = 5% bonus\n• 3 max-level chars = 15% bonus\n• 5+ max-level chars = 25% bonus (maximum)\n\nCheck your current bonus with:\n.prestige altbonus info');

-- =====================================================================
-- Gossip Menu Entries (links text to menu)
-- =====================================================================

-- Main menu
INSERT INTO `gossip_menu` (`MenuID`, `TextID`) VALUES
(70001, 70001);

-- Prestige Challenges menu
INSERT INTO `gossip_menu` (`MenuID`, `TextID`) VALUES
(70010, 70010);

-- Alt Bonus menu
INSERT INTO `gossip_menu` (`MenuID`, `TextID`) VALUES
(70011, 70011);

-- =====================================================================
-- Notes:
-- =====================================================================
-- The gossip options are handled in C++ (dc_challenge_modes_customized.cpp)
-- This SQL only provides the background text that appears in the gossip window
-- 
-- To add prestige challenge info to the challenge mode shrine:
-- 1. Add gossip option: "Tell me about Prestige Challenges"
-- 2. Link to menu ID 70010
-- 3. Add gossip option: "Tell me about Alt XP Bonus"
-- 4. Link to menu ID 70011
-- 
-- Or create a separate NPC/GameObject for prestige info
-- =====================================================================
