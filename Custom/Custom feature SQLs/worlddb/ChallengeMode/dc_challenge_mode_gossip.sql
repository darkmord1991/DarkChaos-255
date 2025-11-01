-- =====================================================================
-- DarkChaos-255 Challenge Mode Gossip Menus
-- =====================================================================
-- Creates gossip menus for the challenge mode gameobject
-- These are required for gossip text to display properly
-- =====================================================================

-- Delete existing entries
DELETE FROM `gossip_menu` WHERE `MenuID` BETWEEN 70001 AND 70020;
DELETE FROM `npc_text` WHERE `ID` BETWEEN 70001 AND 70020;

-- =====================================================================
-- NPC Text Entries (shown when opening gossip)
-- =====================================================================

-- Main menu text
INSERT INTO `npc_text` (`ID`, `text0_0`) VALUES
(70001, 'You feel a strange presence as you stand before this ancient idol.\n\nThe Challenge Mode Manager allows you to activate special gameplay modes that will test your skills and determination.\n\nSelect a mode to learn more about it.');

-- =====================================================================
-- Gossip Menu Entries (links text to menu)
-- =====================================================================

-- Main menu
INSERT INTO `gossip_menu` (`MenuID`, `TextID`) VALUES
(70001, 70001);

-- =====================================================================
-- Notes:
-- =====================================================================
-- The gossip options are handled in C++ (dc_challenge_modes_customized.cpp)
-- This SQL only provides the background text that appears in the gossip window
-- 
-- To use this in C++, change SendGossipMenuFor from:
--   SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, player->GetGUID());
-- To:
--   SendGossipMenuFor(player, 70001, player->GetGUID());
-- =====================================================================
