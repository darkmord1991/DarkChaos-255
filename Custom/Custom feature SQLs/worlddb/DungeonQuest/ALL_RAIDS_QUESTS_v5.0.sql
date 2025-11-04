-- =====================================================================
-- COMPREHENSIVE RAID QUEST ASSIGNMENTS v5.0
-- ALL EXPANSIONS: Vanilla, TBC, WotLK
-- =====================================================================
-- 17 Raids, 17 NPCs (700055-700071), 94 Quests
-- =====================================================================

-- =====================================================================
-- DELETE OLD RAID NPCs (700055-700071)
-- =====================================================================
DELETE FROM `creature_template` WHERE `entry` IN (700055, 700056, 700057, 700058, 700059, 700060, 700061, 700062, 700063, 700064, 700065, 700066, 700067, 700068, 700069, 700070, 700071);

-- =====================================================================
-- RAID NPC TEMPLATES (All Expansions)
-- =====================================================================

INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `trainer_class`, `trainer_race`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
VALUES
(700055, 0, 0, 0, 0, 0, 'Firekeeper Adagio', 'Raid Quest Master [Vanilla]', 'Speak', 0, 60, 60, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.2, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 3, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),
(700056, 0, 0, 0, 0, 0, 'Blackwing Herald', 'Raid Quest Master [Vanilla]', 'Speak', 0, 60, 60, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.2, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 3, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),
(700057, 0, 0, 0, 0, 0, 'Qiraji Keeper', 'Raid Quest Master [Vanilla]', 'Speak', 0, 60, 60, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.2, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 3, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),
(700058, 0, 0, 0, 0, 0, 'Scarab Warden', 'Raid Quest Master [Vanilla]', 'Speak', 0, 40, 50, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.2, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 3, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),
(700059, 0, 0, 0, 0, 0, 'Tower Master Meredith', 'Raid Quest Master [TBC]', 'Speak', 0, 70, 70, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.2, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 3, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),
(700060, 0, 0, 0, 0, 0, 'Coilfang Quartermaster', 'Raid Quest Master [TBC]', 'Speak', 0, 70, 70, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.2, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 3, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),
(700061, 0, 0, 0, 0, 0, 'Solarian''s Oracle', 'Raid Quest Master [TBC]', 'Speak', 0, 70, 70, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.2, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 3, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),
(700062, 0, 0, 0, 0, 0, 'Hyjal Guardian', 'Raid Quest Master [TBC]', 'Speak', 0, 70, 70, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.2, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 3, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),
(700063, 0, 0, 0, 0, 0, 'Illidari Quartermaster', 'Raid Quest Master [TBC]', 'Speak', 0, 70, 70, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.2, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 3, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),
(700064, 0, 0, 0, 0, 0, 'Sunwell Keeper', 'Raid Quest Master [TBC]', 'Speak', 0, 70, 70, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.2, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 3, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),
(700065, 0, 0, 0, 0, 0, 'Lich King''s Herald', 'Raid Quest Master [WotLK]', 'Speak', 0, 80, 80, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.2, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 3, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),
(700066, 0, 0, 0, 0, 0, 'Aspects'' Oracle', 'Raid Quest Master [WotLK]', 'Speak', 0, 80, 80, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.2, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 3, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),
(700067, 0, 0, 0, 0, 0, 'Twilight Historian', 'Raid Quest Master [WotLK]', 'Speak', 0, 80, 80, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.2, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 3, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),
(700068, 0, 0, 0, 0, 0, 'Titan''s Keeper', 'Raid Quest Master [WotLK]', 'Speak', 0, 80, 80, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.2, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 3, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),
(700069, 0, 0, 0, 0, 0, 'Crusader''s Quartermaster', 'Raid Quest Master [WotLK]', 'Speak', 0, 80, 80, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.2, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 3, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),
(700070, 0, 0, 0, 0, 0, 'Frost Lich Keeper', 'Raid Quest Master [WotLK]', 'Speak', 0, 80, 80, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.2, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 3, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),
(700071, 0, 0, 0, 0, 0, 'Twilight Warden', 'Raid Quest Master [WotLK]', 'Speak', 0, 82, 82, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.2, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 3, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0);

-- =====================================================================
-- RAID QUEST STARTERS (All Expansions)
-- =====================================================================

-- Molten Core [Vanilla] - NPC 700055
DELETE FROM `creature_queststarter` WHERE `id` = 700055;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(700055, 24424),
(700055, 24425),
(700055, 24426),
(700055, 24427),
(700055, 24428),
(700055, 24429),
(700055, 24430);

-- Blackwing Lair [Vanilla] - NPC 700056
DELETE FROM `creature_queststarter` WHERE `id` = 700056;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(700056, 24432),
(700056, 24433),
(700056, 24434),
(700056, 24435),
(700056, 24436),
(700056, 24437),
(700056, 24438);

-- Temple of Ahn'Qiraj [Vanilla] - NPC 700057
DELETE FROM `creature_queststarter` WHERE `id` = 700057;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(700057, 24440),
(700057, 24441),
(700057, 24442),
(700057, 24443);

-- Ruins of Ahn'Qiraj [Vanilla] - NPC 700058
DELETE FROM `creature_queststarter` WHERE `id` = 700058;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(700058, 24444);

-- Karazhan [TBC] - NPC 700059
DELETE FROM `creature_queststarter` WHERE `id` = 700059;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(700059, 24445),
(700059, 24446),
(700059, 24447),
(700059, 24448),
(700059, 24449),
(700059, 24450),
(700059, 24451);

-- Serpentshrine Cavern [TBC] - NPC 700060
DELETE FROM `creature_queststarter` WHERE `id` = 700060;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(700060, 24452),
(700060, 24453),
(700060, 24454),
(700060, 24455),
(700060, 24456),
(700060, 24457);

-- The Eye [TBC] - NPC 700061
DELETE FROM `creature_queststarter` WHERE `id` = 700061;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(700061, 24458),
(700061, 24459),
(700061, 24460);

-- Mount Hyjal [TBC] - NPC 700062
DELETE FROM `creature_queststarter` WHERE `id` = 700062;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(700062, 24461),
(700062, 24462),
(700062, 24463),
(700062, 24464),
(700062, 24465);

-- Black Temple [TBC] - NPC 700063
DELETE FROM `creature_queststarter` WHERE `id` = 700063;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(700063, 24466),
(700063, 24467),
(700063, 24468),
(700063, 24469),
(700063, 24470);

-- Sunwell Plateau [TBC] - NPC 700064
DELETE FROM `creature_queststarter` WHERE `id` = 700064;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(700064, 24471),
(700064, 24472),
(700064, 24473),
(700064, 24474),
(700064, 24475),
(700064, 24476);

-- Naxxramas [WotLK] - NPC 700065
DELETE FROM `creature_queststarter` WHERE `id` = 700065;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(700065, 13593),
(700065, 13609),
(700065, 13610),
(700065, 13614);

-- The Eye of Eternity [WotLK] - NPC 700066
DELETE FROM `creature_queststarter` WHERE `id` = 700066;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(700066, 13616),
(700066, 13617),
(700066, 13618);

-- The Obsidian Sanctum [WotLK] - NPC 700067
DELETE FROM `creature_queststarter` WHERE `id` = 700067;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(700067, 13619);

-- Ulduar [WotLK] - NPC 700068
DELETE FROM `creature_queststarter` WHERE `id` = 700068;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(700068, 13620),
(700068, 13621),
(700068, 13622),
(700068, 13623),
(700068, 13624),
(700068, 13625),
(700068, 13626),
(700068, 13628),
(700068, 13629);

-- Trial of the Crusader [WotLK] - NPC 700069
DELETE FROM `creature_queststarter` WHERE `id` = 700069;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(700069, 13632);

-- Icecrown Citadel [WotLK] - NPC 700070
DELETE FROM `creature_queststarter` WHERE `id` = 700070;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(700070, 13633),
(700070, 13634),
(700070, 13635),
(700070, 13636),
(700070, 13637),
(700070, 13638),
(700070, 13639),
(700070, 13640),
(700070, 13641),
(700070, 13642),
(700070, 13643),
(700070, 13646),
(700070, 13649),
(700070, 13662),
(700070, 13663),
(700070, 13664),
(700070, 13665),
(700070, 13666),
(700070, 13667),
(700070, 13668),
(700070, 13671),
(700070, 13672);

-- Ruby Sanctum [WotLK] - NPC 700071
DELETE FROM `creature_queststarter` WHERE `id` = 700071;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(700071, 13803),
(700071, 13804),
(700071, 13805);


-- =====================================================================
-- RAID QUEST ENDERS (All Expansions - Same as Starters)
-- =====================================================================

-- Molten Core - NPC 700055
DELETE FROM `creature_questender` WHERE `id` = 700055;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(700055, 24424),
(700055, 24425),
(700055, 24426),
(700055, 24427),
(700055, 24428),
(700055, 24429),
(700055, 24430);

-- Blackwing Lair - NPC 700056
DELETE FROM `creature_questender` WHERE `id` = 700056;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(700056, 24432),
(700056, 24433),
(700056, 24434),
(700056, 24435),
(700056, 24436),
(700056, 24437),
(700056, 24438);

-- Temple of Ahn'Qiraj - NPC 700057
DELETE FROM `creature_questender` WHERE `id` = 700057;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(700057, 24440),
(700057, 24441),
(700057, 24442),
(700057, 24443);

-- Ruins of Ahn'Qiraj - NPC 700058
DELETE FROM `creature_questender` WHERE `id` = 700058;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(700058, 24444);

-- Karazhan - NPC 700059
DELETE FROM `creature_questender` WHERE `id` = 700059;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(700059, 24445),
(700059, 24446),
(700059, 24447),
(700059, 24448),
(700059, 24449),
(700059, 24450),
(700059, 24451);

-- Serpentshrine Cavern - NPC 700060
DELETE FROM `creature_questender` WHERE `id` = 700060;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(700060, 24452),
(700060, 24453),
(700060, 24454),
(700060, 24455),
(700060, 24456),
(700060, 24457);

-- The Eye - NPC 700061
DELETE FROM `creature_questender` WHERE `id` = 700061;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(700061, 24458),
(700061, 24459),
(700061, 24460);

-- Mount Hyjal - NPC 700062
DELETE FROM `creature_questender` WHERE `id` = 700062;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(700062, 24461),
(700062, 24462),
(700062, 24463),
(700062, 24464),
(700062, 24465);

-- Black Temple - NPC 700063
DELETE FROM `creature_questender` WHERE `id` = 700063;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(700063, 24466),
(700063, 24467),
(700063, 24468),
(700063, 24469),
(700063, 24470);

-- Sunwell Plateau - NPC 700064
DELETE FROM `creature_questender` WHERE `id` = 700064;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(700064, 24471),
(700064, 24472),
(700064, 24473),
(700064, 24474),
(700064, 24475),
(700064, 24476);

-- Naxxramas - NPC 700065
DELETE FROM `creature_questender` WHERE `id` = 700065;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(700065, 13593),
(700065, 13609),
(700065, 13610),
(700065, 13614);

-- The Eye of Eternity - NPC 700066
DELETE FROM `creature_questender` WHERE `id` = 700066;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(700066, 13616),
(700066, 13617),
(700066, 13618);

-- The Obsidian Sanctum - NPC 700067
DELETE FROM `creature_questender` WHERE `id` = 700067;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(700067, 13619);

-- Ulduar - NPC 700068
DELETE FROM `creature_questender` WHERE `id` = 700068;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(700068, 13620),
(700068, 13621),
(700068, 13622),
(700068, 13623),
(700068, 13624),
(700068, 13625),
(700068, 13626),
(700068, 13628),
(700068, 13629);

-- Trial of the Crusader - NPC 700069
DELETE FROM `creature_questender` WHERE `id` = 700069;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(700069, 13632);

-- Icecrown Citadel - NPC 700070
DELETE FROM `creature_questender` WHERE `id` = 700070;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(700070, 13633),
(700070, 13634),
(700070, 13635),
(700070, 13636),
(700070, 13637),
(700070, 13638),
(700070, 13639),
(700070, 13640),
(700070, 13641),
(700070, 13642),
(700070, 13643),
(700070, 13646),
(700070, 13649),
(700070, 13662),
(700070, 13663),
(700070, 13664),
(700070, 13665),
(700070, 13666),
(700070, 13667),
(700070, 13668),
(700070, 13671),
(700070, 13672);

-- Ruby Sanctum - NPC 700071
DELETE FROM `creature_questender` WHERE `id` = 700071;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(700071, 13803),
(700071, 13804),
(700071, 13805);


-- =====================================================================
-- RAID NPC MAPPINGS (Update dc_dungeon_npc_mapping)
-- =====================================================================

-- Remove old mapping for NPC 700002 from ICC (Blackfathom should not serve ICC)
DELETE FROM `dc_dungeon_npc_mapping` WHERE `map_id` = 631 AND `quest_master_entry` = 700002;

-- Insert all raid mappings
INSERT INTO `dc_dungeon_npc_mapping` (`map_id`, `quest_master_entry`, `dungeon_name`, `expansion`, `min_level`, `max_level`) VALUES
(409, 700055, 'Molten Core', 0, 60, 60),
(469, 700056, 'Blackwing Lair', 0, 60, 60),
(531, 700057, 'Temple of Ahn''Qiraj', 0, 60, 60),
(509, 700058, 'Ruins of Ahn''Qiraj', 0, 40, 50),
(532, 700059, 'Karazhan', 1, 70, 70),
(552, 700060, 'Serpentshrine Cavern', 1, 70, 70),
(554, 700061, 'The Eye', 1, 70, 70),
(534, 700062, 'Mount Hyjal', 1, 70, 70),
(564, 700063, 'Black Temple', 1, 70, 70),
(580, 700064, 'Sunwell Plateau', 1, 70, 70),
(533, 700065, 'Naxxramas', 2, 80, 80),
(616, 700066, 'The Eye of Eternity', 2, 80, 80),
(615, 700067, 'The Obsidian Sanctum', 2, 80, 80),
(603, 700068, 'Ulduar', 2, 80, 80),
(649, 700069, 'Trial of the Crusader', 2, 80, 80),
(631, 700070, 'Icecrown Citadel', 2, 80, 80),
(724, 700071, 'Ruby Sanctum', 2, 82, 82);

-- =====================================================================
-- SUMMARY
-- =====================================================================
-- Total Raids Added: 17
-- Total NPCs Created: 17 (700055-700071)
-- Total Quests Added: 94
--
-- BREAKDOWN BY EXPANSION:
-- Vanilla Raids (4):     Molten Core, Blackwing Lair, Temple of Ahn'Qiraj, Ruins of Ahn'Qiraj
--   NPCs: 700055-700058 (4 NPCs, 19 quests)
--
-- TBC Raids (6):         Karazhan, Serpentshrine Cavern, The Eye, Mount Hyjal, Black Temple, Sunwell Plateau
--   NPCs: 700059-700064 (6 NPCs, 38 quests)
--
-- WotLK Raids (7):       Naxxramas, Eye of Eternity, Obsidian Sanctum, Ulduar, Trial of Crusader, ICC, Ruby Sanctum
--   NPCs: 700065-700071 (7 NPCs, 37 quests)
--
-- KEY FIXES:
-- ✓ ICC (map 631) now uses NPC 700070 (Frost Lich Keeper) for raid quests
-- ✓ NPC 700002 (Blackfathom Deeps) no longer conflicted with ICC
-- ✓ All raids separated by expansion level
-- ✓ All NPCs use script: npc_dungeon_quest_master
-- =====================================================================
