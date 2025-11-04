-- =====================================================================
-- DUNGEON QUEST SYSTEM v5.0 - NPC TEMPLATES (DYNAMIC SPAWN SYSTEM)
-- =====================================================================
-- Purpose: Create all 50 dungeon quest master NPCs with dynamic pet-like spawning
-- Version: 5.0
-- Database: acore_world
-- Date: November 4, 2025
-- 
-- NPCs Created: 700000-700054 (50 Total)
-- - Classic: 700000-700018 (19 NPCs) - Added Scholomance (700018)
-- - TBC: 700020-700035 (16 NPCs)
-- - WotLK: 700040-700054 (15 NPCs) - Added Culling (700053) & Halls of Reflection (700054)
--
-- IMPORTANT: These NPCs spawn DYNAMICALLY as pets when players enter dungeons!
-- See: DungeonQuestMasterFollower.cpp for spawn logic
-- Static spawns NOT needed - handled by script automatically
-- Models chosen to fit each dungeon's theme
-- =====================================================================

-- =====================================================================
-- SECTION 1: CREATURE TEMPLATES
-- =====================================================================
-- Delete old entries (full range for future expansion)
DELETE FROM `creature_template` WHERE `entry` BETWEEN 700000 AND 700054;

-- Insert all 18 Classic Dungeon Quest Master NPCs
INSERT INTO `creature_template` 
(`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, 
`name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, 
`speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, 
`dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, 
`unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, 
`trainer_class`, `trainer_race`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, 
`PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, 
`HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, 
`RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
VALUES
-- NPC 700000: Ragefire Chasm (Orgrimmar - Orc Dungeon)
(700000, 0, 0, 0, 0, 0, 'Emberscar', 'Ragefire Quest Master', 'Speak', 0, 55, 55, 2, 85, 3, 1, 1.14286, 1, 1, 50, 1.2, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 3, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700001: The Deadmines (Westfall - Human/Defias Theme)
(700001, 0, 0, 0, 0, 0, 'Captain Greensails', 'Deadmines Quest Master', 'Speak', 0, 55, 55, 2, 11, 3, 1, 1.14286, 1, 1, 50, 1, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 2, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700002: Blackfathom Deeps (Ashenvale - Night Elf/Naga Theme)
(700002, 0, 0, 0, 0, 0, 'Tidehunter Mara', 'Blackfathom Quest Master', 'Speak', 0, 55, 55, 2, 80, 3, 1, 1.14286, 1, 1, 50, 1.1, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 2.5, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700003: The Stockade (Stormwind - Human Prison)
(700003, 0, 0, 0, 0, 0, 'Warden Thelwater', 'Stockade Quest Master', 'Speak', 0, 55, 55, 2, 11, 3, 1, 1.14286, 1, 1, 50, 1, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 2, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700004: Wailing Caverns (Northern Barrens - Druid/Nature Theme)
(700004, 0, 0, 0, 0, 0, 'Dreamwalker Nala', 'Wailing Caverns Quest Master', 'Speak', 0, 55, 55, 2, 80, 3, 1, 1.14286, 1, 1, 50, 1.05, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 2.2, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700005: Razorfen Kraul (Southern Barrens - Quilboar Theme)
(700005, 0, 0, 0, 0, 0, 'Thornweaver Krug', 'Razorfen Kraul Quest Master', 'Speak', 0, 55, 55, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.15, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 2.5, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700006: Gnomeregan (Dun Morogh - Gnome/Tech Theme)
(700006, 0, 0, 0, 0, 0, 'Tinkmaster Overspark', 'Gnomeregan Quest Master', 'Speak', 0, 55, 55, 2, 54, 3, 1, 1.14286, 1, 1, 50, 0.9, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 2, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700007: Scarlet Monastery (Tirisfal Glades - Scarlet Crusade Theme)
(700007, 0, 0, 0, 0, 0, 'Commander Mardenholde', 'Scarlet Monastery Quest Master', 'Speak', 0, 55, 55, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.1, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 2.5, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700008: Razorfen Downs (Southern Barrens - Death/Undead Theme)
(700008, 0, 0, 0, 0, 0, 'Deathstalker Mortis', 'Razorfen Downs Quest Master', 'Speak', 0, 55, 55, 2, 68, 3, 1, 1.14286, 1, 1, 50, 1.1, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 2.3, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700009: Uldaman (Badlands - Titan/Earthen Theme)
(700009, 0, 0, 0, 0, 0, 'Archaeologist Ironbeard', 'Uldaman Quest Master', 'Speak', 0, 55, 55, 2, 55, 3, 1, 1.14286, 1, 1, 50, 1.2, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 3, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700010: Zul'Farrak (Tanaris - Troll Theme)
(700010, 0, 0, 0, 0, 0, 'Witch Doctor Zum\'rah', 'Zul\'Farrak Quest Master', 'Speak', 0, 55, 55, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.15, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 2.5, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700011: Maraudon (Desolace - Centaur/Earth Theme)
(700011, 0, 0, 0, 0, 0, 'Keeper Remulos', 'Maraudon Quest Master', 'Speak', 0, 55, 55, 2, 80, 3, 1, 1.14286, 1, 1, 50, 1.3, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 3, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700012: Sunken Temple (Swamp of Sorrows - Troll/Green Dragonflight)
(700012, 0, 0, 0, 0, 0, 'Atal\'ai Exile', 'Sunken Temple Quest Master', 'Speak', 0, 55, 55, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.1, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 2.5, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700013: Blackrock Depths (Searing Gorge - Dark Iron Dwarf Theme)
(700013, 0, 0, 0, 0, 0, 'Forgemaster Pyron', 'Blackrock Depths Quest Master', 'Speak', 0, 55, 55, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.1, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 3, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700014: Blackrock Spire (Burning Steppes - Orc/Dragon Theme)
(700014, 0, 0, 0, 0, 0, 'Dragonslayer Orosh', 'Blackrock Spire Quest Master', 'Speak', 0, 55, 55, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.2, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 3, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700015: Stratholme (Eastern Plaguelands - Scourge/Undead Theme)
(700015, 0, 0, 0, 0, 0, 'Crusader Valdelmar', 'Stratholme Quest Master', 'Speak', 0, 55, 55, 2, 11, 3, 1, 1.14286, 1, 1, 50, 1.1, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 2.5, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700016: Dire Maul (Feralas - Night Elf/Ogre Theme)
(700016, 0, 0, 0, 0, 0, 'Scholar Runetongue', 'Dire Maul Quest Master', 'Speak', 0, 55, 55, 2, 80, 3, 1, 1.14286, 1, 1, 50, 1.1, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 2.5, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700017: Shadowfang Keep (Silverpine Forest - Worgen/Undead Theme)
(700017, 0, 0, 0, 0, 0, 'Packmaster Nighthowl', 'Shadowfang Keep Quest Master', 'Speak', 0, 55, 55, 2, 68, 3, 1, 1.14286, 1, 1, 50, 1.1, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 2.3, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700018: Scholomance (Western Plaguelands - Undead/Scourge Theme)
(700018, 0, 0, 0, 0, 0, 'Darkmaster Gandling', 'Scholomance Quest Master', 'Speak', 0, 58, 58, 2, 68, 3, 1, 1.14286, 1, 1, 50, 1.15, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 2.8, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- =====================================================================
-- TBC DUNGEON QUEST MASTERS (NPCs 700020-700035)
-- =====================================================================

-- NPC 700020: Hellfire Ramparts
(700020, 0, 0, 0, 0, 0, 'Fel-Commander Azgoth', 'Hellfire Ramparts Quest Master', 'Speak', 0, 62, 62, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.15, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 2.5, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700021: The Blood Furnace
(700021, 0, 0, 0, 0, 0, 'Bloodsmith Kargath', 'Blood Furnace Quest Master', 'Speak', 0, 62, 62, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.1, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 2.3, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700022: The Shattered Halls
(700022, 0, 0, 0, 0, 0, 'Warbringer Shatterfist', 'Shattered Halls Quest Master', 'Speak', 0, 70, 70, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.2, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 3, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700023: The Slave Pens
(700023, 0, 0, 0, 0, 0, 'Tidecaller Mura', 'Slave Pens Quest Master', 'Speak', 0, 62, 62, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.1, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 2.3, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700024: The Underbog
(700024, 0, 0, 0, 0, 0, 'Bog Keeper Thural', 'Underbog Quest Master', 'Speak', 0, 63, 63, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.15, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 2.5, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700025: The Steamvault
(700025, 0, 0, 0, 0, 0, 'Engineer Vaporix', 'Steamvault Quest Master', 'Speak', 0, 70, 70, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.1, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 2.5, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700026: The Mechanar
(700026, 0, 0, 0, 0, 0, 'Techmaster Kaladrius', 'Mechanar Quest Master', 'Speak', 0, 69, 69, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.1, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 2.3, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700027: The Botanica
(700027, 0, 0, 0, 0, 0, 'Botanist Aelanis', 'Botanica Quest Master', 'Speak', 0, 70, 70, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.1, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 2.5, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700028: The Arcatraz
(700028, 0, 0, 0, 0, 0, 'Warden Crystallus', 'Arcatraz Quest Master', 'Speak', 0, 70, 70, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.15, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 2.5, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700029: Mana-Tombs
(700029, 0, 0, 0, 0, 0, 'Ethereal Curator Nexus', 'Mana-Tombs Quest Master', 'Speak', 0, 64, 64, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.1, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 2.3, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700030: Auchenai Crypts
(700030, 0, 0, 0, 0, 0, 'Soulkeeper D\'reth', 'Auchenai Crypts Quest Master', 'Speak', 0, 65, 65, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.1, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 2.5, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700031: Sethekk Halls
(700031, 0, 0, 0, 0, 0, 'Talon King Skyriss', 'Sethekk Halls Quest Master', 'Speak', 0, 67, 67, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.15, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 2.5, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700032: Shadow Labyrinth
(700032, 0, 0, 0, 0, 0, 'Shadowmancer Murmur', 'Shadow Labyrinth Quest Master', 'Speak', 0, 70, 70, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.1, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 2.5, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700033: Old Hillsbrad Foothills
(700033, 0, 0, 0, 0, 0, 'Chronologist Tareth', 'Old Hillsbrad Quest Master', 'Speak', 0, 66, 66, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.1, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 2.3, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700034: The Black Morass
(700034, 0, 0, 0, 0, 0, 'Timekeeper Sa\'at', 'Black Morass Quest Master', 'Speak', 0, 70, 70, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.1, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 2.5, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700035: Magisters' Terrace
(700035, 0, 0, 0, 0, 0, 'Magister Kaelthas', 'Magisters\' Terrace Quest Master', 'Speak', 0, 70, 70, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.1, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 2.5, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- =====================================================================
-- WOTLK DUNGEON QUEST MASTERS (NPCs 700040-700052)
-- =====================================================================

-- NPC 700040: Utgarde Keep
(700040, 0, 0, 0, 0, 0, 'Vrykul Warlord Thorim', 'Utgarde Keep Quest Master', 'Speak', 0, 70, 70, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.2, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 3, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700041: Utgarde Pinnacle
(700041, 0, 0, 0, 0, 0, 'King Ymiron', 'Utgarde Pinnacle Quest Master', 'Speak', 0, 80, 80, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.2, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 3, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700042: The Nexus
(700042, 0, 0, 0, 0, 0, 'Archmage Berinand', 'The Nexus Quest Master', 'Speak', 0, 71, 71, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.1, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 2.5, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700043: The Oculus
(700043, 0, 0, 0, 0, 0, 'Dragonkeeper Varos', 'The Oculus Quest Master', 'Speak', 0, 80, 80, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.15, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 2.5, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700044: Halls of Stone
(700044, 0, 0, 0, 0, 0, 'Stonekeeper Brann', 'Halls of Stone Quest Master', 'Speak', 0, 77, 77, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.1, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 2.5, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700045: Halls of Lightning
(700045, 0, 0, 0, 0, 0, 'Stormcaller Loken', 'Halls of Lightning Quest Master', 'Speak', 0, 80, 80, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.15, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 2.5, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700046: Azjol-Nerub
(700046, 0, 0, 0, 0, 0, 'Nerubian Vizier Anub', 'Azjol-Nerub Quest Master', 'Speak', 0, 72, 72, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.1, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 2.5, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700047: Ahn'kahet: The Old Kingdom
(700047, 0, 0, 0, 0, 0, 'Old God Herald Jedoga', 'Ahn\'kahet Quest Master', 'Speak', 0, 73, 73, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.1, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 2.5, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700048: Gundrak
(700048, 0, 0, 0, 0, 0, 'Drakkari Prophet Gal\'darah', 'Gundrak Quest Master', 'Speak', 0, 76, 76, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.15, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 2.5, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700049: The Violet Hold
(700049, 0, 0, 0, 0, 0, 'Prison Warden Cyanigosa', 'Violet Hold Quest Master', 'Speak', 0, 75, 75, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.1, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 2.5, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700050: Drak'Tharon Keep
(700050, 0, 0, 0, 0, 0, 'Drak\'Tharon Overlord', 'Drak\'Tharon Keep Quest Master', 'Speak', 0, 74, 74, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.1, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 2.5, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700051: The Forge of Souls
(700051, 0, 0, 0, 0, 0, 'Soulforge Master Bronjahm', 'Forge of Souls Quest Master', 'Speak', 0, 80, 80, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.1, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 2.5, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700052: The Pit of Saron
(700052, 0, 0, 0, 0, 0, 'Scourgelord Tyrannus', 'Pit of Saron Quest Master', 'Speak', 0, 80, 80, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.15, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 2.5, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700053: The Culling of Stratholme (Caverns of Time - Human/Scourge Theme)
(700053, 0, 0, 0, 0, 0, 'Chromie', 'Culling of Stratholme Quest Master', 'Speak', 0, 80, 80, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 2.5, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0),

-- NPC 700054: Halls of Reflection (Icecrown Citadel - Scourge/Lich King Theme)
(700054, 0, 0, 0, 0, 0, 'The Lich King', 'Halls of Reflection Quest Master', 'Speak', 0, 80, 80, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.3, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 3.5, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0);

-- =====================================================================
-- SECTION 2: CREATURE DISPLAY MODELS
-- =====================================================================
-- Assign appropriate models to each NPC based on dungeon theme
DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN 700000 AND 700054;

INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
-- =====================================================================
-- CLASSIC DUNGEON MODELS (700000-700017)
-- =====================================================================
-- NPC 700000: Ragefire Chasm - Orc Warlock (Model: 3705 - Orc Male Fire Mage)
(700000, 0, 3705, 1.2, 1, 0),

-- NPC 700001: Deadmines - Human Pirate (Model: 3902 - Human Male Pirate)
(700001, 0, 3902, 1, 1, 0),

-- NPC 700002: Blackfathom Deeps - Night Elf Female (Model: 4981 - NE Female Druid)
(700002, 0, 4981, 1.1, 1, 0),

-- NPC 700003: Stockade - Human Guard (Model: 3822 - Stormwind Guard)
(700003, 0, 3822, 1, 1, 0),

-- NPC 700004: Wailing Caverns - Tauren Druid (Model: 4625 - Tauren Druid)
(700004, 0, 4625, 1.05, 1, 0),

-- NPC 700005: Razorfen Kraul - Quilboar Shaman (Model: 4615 - Quilboar)
(700005, 0, 4615, 1.15, 1, 0),

-- NPC 700006: Gnomeregan - Gnome Engineer (Model: 3965 - Gnome Male Mage)
(700006, 0, 3965, 0.9, 1, 0),

-- NPC 700007: Scarlet Monastery - Human Paladin (Model: 3835 - Scarlet Crusader)
(700007, 0, 3835, 1.1, 1, 0),

-- NPC 700008: Razorfen Downs - Undead Priest (Model: 4193 - Undead Male Priest)
(700008, 0, 4193, 1.1, 1, 0),

-- NPC 700009: Uldaman - Dwarf Warrior (Model: 4050 - Dwarf Warrior Elite)
(700009, 0, 4050, 1.2, 1, 0),

-- NPC 700010: Zul'Farrak - Troll Priest (Model: 4417 - Troll Male Priest)
(700010, 0, 4417, 1.15, 1, 0),

-- NPC 700011: Maraudon - Night Elf Male Druid (Model: 4232 - NE Male Druid)
(700011, 0, 4232, 1.3, 1, 0),

-- NPC 700012: Sunken Temple - Troll (Model: 4418 - Atal'ai Priest)
(700012, 0, 4418, 1.1, 1, 0),

-- NPC 700013: Blackrock Depths - Dark Iron Dwarf (Model: 4051 - Dark Iron Dwarf)
(700013, 0, 4051, 1.1, 1, 0),

-- NPC 700014: Blackrock Spire - Orc Warrior (Model: 4341 - Orc Warrior Elite)
(700014, 0, 4341, 1.2, 1, 0),

-- NPC 700015: Stratholme - Human Paladin (Model: 4258 - Argent Crusader)
(700015, 0, 4258, 1.1, 1, 0),

-- NPC 700016: Dire Maul - Night Elf Scholar (Model: 4986 - NE Female Mage)
(700016, 0, 4986, 1.1, 1, 0),

-- NPC 700017: Shadowfang Keep - Worgen (Model: 657 - Worgen)
(700017, 0, 657, 1.1, 1, 0),

-- NPC 700018: Scholomance - Lich (Model: 5233 - Darkmaster Gandling)
(700018, 0, 5233, 1.15, 1, 0),

-- =====================================================================
-- TBC DUNGEON MODELS (700020-700035)
-- =====================================================================
-- NPC 700020: Hellfire Ramparts - Fel Orc (Model: 18988 - Fel Orc Warrior)
(700020, 0, 18988, 1.15, 1, 0),

-- NPC 700021: Blood Furnace - Fel Orc (Model: 18986 - Fel Orc Bloodsmith)
(700021, 0, 18986, 1.1, 1, 0),

-- NPC 700022: Shattered Halls - Orc Warrior (Model: 19457 - Shattered Hand Warrior)
(700022, 0, 19457, 1.2, 1, 0),

-- NPC 700023: Slave Pens - Naga (Model: 17534 - Coilfang Naga)
(700023, 0, 17534, 1.1, 1, 0),

-- NPC 700024: Underbog - Broken Draenei (Model: 17402 - Broken)
(700024, 0, 17402, 1.15, 1, 0),

-- NPC 700025: Steamvault - Naga Engineer (Model: 17536 - Steamvault Naga)
(700025, 0, 17536, 1.1, 1, 0),

-- NPC 700026: Mechanar - Mechanar Mage (Model: 17867 - Mechanar Bot)
(700026, 0, 17867, 1.1, 1, 0),

-- NPC 700027: Botanica - Blood Elf Botanist (Model: 16612 - Blood Elf Male Mage)
(700027, 0, 16612, 1.1, 1, 0),

-- NPC 700028: Arcatraz - Ethereal (Model: 18239 - Ethereal)
(700028, 0, 18239, 1.15, 1, 0),

-- NPC 700029: Mana-Tombs - Ethereal (Model: 18238 - Ethereal Sorcerer)
(700029, 0, 18238, 1.1, 1, 0),

-- NPC 700030: Auchenai Crypts - Draenei Ghost (Model: 18309 - Auchenai Soulpriest)
(700030, 0, 18309, 1.1, 1, 0),

-- NPC 700031: Sethekk Halls - Arakkoa (Model: 17367 - Arakkoa Sage)
(700031, 0, 17367, 1.15, 1, 0),

-- NPC 700032: Shadow Labyrinth - Cabal Cultist (Model: 18554 - Cabal Cultist)
(700032, 0, 18554, 1.1, 1, 0),

-- NPC 700033: Old Hillsbrad - Human Timekeeper (Model: 17096 - Human Mage TBC)
(700033, 0, 17096, 1.1, 1, 0),

-- NPC 700034: Black Morass - Bronze Dragon (Model: 17701 - Bronze Dragonkin)
(700034, 0, 17701, 1.1, 1, 0),

-- NPC 700035: Magisters' Terrace - Blood Elf Magister (Model: 23040 - Blood Elf Magister)
(700035, 0, 23040, 1.1, 1, 0),

-- =====================================================================
-- WOTLK DUNGEON MODELS (700040-700052)
-- =====================================================================
-- NPC 700040: Utgarde Keep - Vrykul Warrior (Model: 25616 - Vrykul)
(700040, 0, 25616, 1.2, 1, 0),

-- NPC 700041: Utgarde Pinnacle - Vrykul King (Model: 26503 - King Ymiron) - REDUCED SCALE
(700041, 0, 26503, 0.5, 1, 0),

-- NPC 700042: The Nexus - Arcane Mage (Model: 25871 - Nexus Mage)
(700042, 0, 25871, 1.1, 1, 0),

-- NPC 700043: The Oculus - Azure Dragon (Model: 26234 - Azure Dragonkin)
(700043, 0, 26234, 1.15, 1, 0),

-- NPC 700044: Halls of Stone - Dwarf Stonekeeper (Model: 27153 - Ironforge Dwarf)
(700044, 0, 27153, 1.1, 1, 0),

-- NPC 700045: Halls of Lightning - Lightning Caller (Model: 26639 - Lightning Caster)
(700045, 0, 26639, 1.15, 1, 0),

-- NPC 700046: Azjol-Nerub - Nerubian (Model: 26253 - Nerubian Vizier) - REDUCED SCALE
(700046, 0, 26253, 0.5, 1, 0),

-- NPC 700047: Ahn'kahet - Faceless One (Model: 26682 - Faceless)
(700047, 0, 26682, 1.1, 1, 0),

-- NPC 700048: Gundrak - Ice Troll (Model: 27260 - Drakkari Troll)
(700048, 0, 27260, 1.15, 1, 0),

-- NPC 700049: Violet Hold - Prison Warden (Model: 28160 - Arcane Guardian)
(700049, 0, 28160, 1.1, 1, 0),

-- NPC 700050: Drak'Tharon Keep - Scourge Troll (Model: 27129 - Scourge Troll)
(700050, 0, 27129, 1.1, 1, 0),

-- NPC 700051: Forge of Souls - Soul Forgemaster (Model: 30226 - Bronjahm)
(700051, 0, 30226, 1.1, 1, 0),

-- NPC 700052: Pit of Saron - Scourge Commander (Model: 30294 - Scourgelord)
(700052, 0, 30294, 1.15, 1, 0),

-- NPC 700053: Culling of Stratholme - Chromie (Model: 16110 - Chromie - Gnome Female)
(700053, 0, 16110, 1, 1, 0),

-- NPC 700054: Halls of Reflection - The Lich King (Model: 30721 - Lich King)
(700054, 0, 30721, 1.3, 1, 0);

-- =====================================================================
-- SECTION 3: CREATURE SPAWNS (Daily/Weekly Quest NPCs Only)
-- =====================================================================
-- NOTE: Dungeon quest master NPCs (700000-700054) spawn DYNAMICALLY
-- when players enter dungeons (see DungeonQuestMasterFollower.cpp).
-- Only daily/weekly quest NPCs are spawned in cities.
--
-- Future: Add city NPCs for daily/weekly quests here (700100, 700101, etc.)
-- Example spawn locations:
-- - Orgrimmar: Valley of Strength (1633.33, -4439.18, 15.43)
-- - Stormwind: Trade District (-8844.0, 627.0, 94.0)
-- - Dalaran: Violet Citadel (5819.0, 582.0, 660.0)
--
-- For now, this section is INTENTIONALLY EMPTY.
-- Dungeon NPCs spawn via script when entering dungeons!

-- =====================================================================
-- SECTION 4: GOSSIP MENUS (Optional - for future expansion)
-- =====================================================================
-- Basic gossip menus for each NPC
DELETE FROM `gossip_menu` WHERE `MenuID` BETWEEN 700000 AND 700017;

INSERT INTO `gossip_menu` (`MenuID`, `TextID`) VALUES
(700000, 50000),  -- Ragefire Chasm
(700001, 50001),  -- Deadmines
(700002, 50002),  -- Blackfathom Deeps
(700003, 50003),  -- Stockade
(700004, 50004),  -- Wailing Caverns
(700005, 50005),  -- Razorfen Kraul
(700006, 50006),  -- Gnomeregan
(700007, 50007),  -- Scarlet Monastery
(700008, 50008),  -- Razorfen Downs
(700009, 50009),  -- Uldaman
(700010, 50010),  -- Zul'Farrak
(700011, 50011),  -- Maraudon
(700012, 50012),  -- Sunken Temple
(700013, 50013),  -- Blackrock Depths
(700014, 50014),  -- Blackrock Spire
(700015, 50015),  -- Stratholme
(700016, 50016),  -- Dire Maul
(700017, 50017);  -- Shadowfang Keep

-- =====================================================================
-- SECTION 5: NPC TEXT (Gossip flavor text)
-- =====================================================================
DELETE FROM `npc_text` WHERE `ID` BETWEEN 50000 AND 50017;

INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`, `em0_0`, `em0_1`, `em0_2`, `em0_3`, `em0_4`, `em0_5`, `VerifiedBuild`) VALUES
(50000, 'The fires of Ragefire Chasm burn bright. Are you ready to face the challenges within?', '', 0, 0, 1, 0, 0, 0, 0, 0, 0, 0),
(50001, 'The Deadmines hold many secrets and dangers. What brings you to these depths?', '', 0, 0, 1, 0, 0, 0, 0, 0, 0, 0),
(50002, 'Blackfathom Deeps is a place of ancient power. Tread carefully, adventurer.', '', 0, 0, 1, 0, 0, 0, 0, 0, 0, 0),
(50003, 'The Stockade holds the most dangerous criminals of Stormwind. Are you prepared?', '', 0, 0, 1, 0, 0, 0, 0, 0, 0, 0),
(50004, 'The Wailing Caverns twist and turn. Many have been lost in the emerald nightmare.', '', 0, 0, 1, 0, 0, 0, 0, 0, 0, 0),
(50005, 'Razorfen Kraul is a maze of thorns and danger. The quilboar are fierce opponents.', '', 0, 0, 1, 0, 0, 0, 0, 0, 0, 0),
(50006, 'Gnomeregan was once a marvel of gnomish engineering. Now it is overrun with troggs and worse.', '', 0, 0, 1, 0, 0, 0, 0, 0, 0, 0),
(50007, 'The Scarlet Monastery is a bastion of fanaticism. Steel yourself for battle.', '', 0, 0, 1, 0, 0, 0, 0, 0, 0, 0),
(50008, 'Razorfen Downs reeks of death. The scourge has taken root here.', '', 0, 0, 1, 0, 0, 0, 0, 0, 0, 0),
(50009, 'Uldaman holds the secrets of the titans. What you seek may be buried deep.', '', 0, 0, 1, 0, 0, 0, 0, 0, 0, 0),
(50010, 'Zul\'Farrak stands as a testament to the ancient troll empire. Glory or death awaits.', '', 0, 0, 1, 0, 0, 0, 0, 0, 0, 0),
(50011, 'Maraudon is a place of corruption. Princess Theradras must be stopped.', '', 0, 0, 1, 0, 0, 0, 0, 0, 0, 0),
(50012, 'The Temple of Atal\'Hakkar sinks deeper into the swamp. Time is of the essence.', '', 0, 0, 1, 0, 0, 0, 0, 0, 0, 0),
(50013, 'Blackrock Depths burns with the forges of the Dark Irons. Beware their dark magic.', '', 0, 0, 1, 0, 0, 0, 0, 0, 0, 0),
(50014, 'Blackrock Spire looms above. Dragons and orcs await those who dare enter.', '', 0, 0, 1, 0, 0, 0, 0, 0, 0, 0),
(50015, 'Stratholme is cursed. The plague took everyone. Now only the undead remain.', '', 0, 0, 1, 0, 0, 0, 0, 0, 0, 0),
(50016, 'Dire Maul contains ancient knowledge and terrible power. Seek wisely.', '', 0, 0, 1, 0, 0, 0, 0, 0, 0, 0),
(50017, 'Shadowfang Keep howls with the curse of the worgen. Silver and courage are your allies.', '', 0, 0, 1, 0, 0, 0, 0, 0, 0, 0);

-- =====================================================================
-- VERIFICATION QUERIES
-- =====================================================================

-- Count NPCs created
SELECT 'NPCs Created:' AS Info, COUNT(*) AS Total FROM `creature_template` WHERE `entry` BETWEEN 700000 AND 700054;

-- Count models assigned
SELECT 'Models Assigned:' AS Info, COUNT(*) AS Total FROM `creature_template_model` WHERE `CreatureID` BETWEEN 700000 AND 700054;

-- Count spawns created (should be 0 - all dungeon NPCs spawn dynamically!)
SELECT 'Static Spawns (Should be 0):' AS Info, COUNT(*) AS Total FROM `creature` WHERE `id1` BETWEEN 700000 AND 700054;

-- List all NPCs by expansion
SELECT 
    CASE 
        WHEN entry BETWEEN 700000 AND 700018 THEN 'Classic'
        WHEN entry BETWEEN 700020 AND 700035 THEN 'TBC'
        WHEN entry BETWEEN 700040 AND 700054 THEN 'WotLK'
    END AS Expansion,
    COUNT(*) AS NPC_Count
FROM creature_template 
WHERE entry BETWEEN 700000 AND 700054
GROUP BY Expansion
ORDER BY Expansion;

-- Verify mapping to dungeons
SELECT 
    COUNT(DISTINCT dnm.quest_master_entry) AS Mapped_NPCs,
    COUNT(DISTINCT ct.entry) AS Created_NPCs
FROM dc_dungeon_npc_mapping dnm
RIGHT JOIN creature_template ct ON dnm.quest_master_entry = ct.entry
WHERE ct.entry BETWEEN 700000 AND 700054;

-- =====================================================================
-- COMPLETION MESSAGE
-- =====================================================================
SELECT '✓ DUNGEON QUEST NPC TEMPLATES v5.0 COMPLETE' AS Status;
SELECT '✓ 50 Dungeon Quest Masters created (19 Classic + 16 TBC + 15 WotLK)' AS Info;
SELECT '✓ Added: Scholomance (700018), Culling (700053), Halls of Reflection (700054)' AS NewNPCs;
SELECT '✓ All NPCs spawn DYNAMICALLY when entering dungeons (pet system)' AS Spawn_Method;
SELECT '✓ Next Step: Import MASTER_CREATURE_QUEST_RELATIONS_v4.0.sql to link quests' AS NextAction;

-- List all NPCs with their spawn locations
SELECT 
    ct.entry AS NPC_Entry,
    ct.name AS NPC_Name,
    ct.subname AS Dungeon,
    c.map AS Map_ID,
    CONCAT(ROUND(c.position_x, 1), ', ', ROUND(c.position_y, 1), ', ', ROUND(c.position_z, 1)) AS Coordinates
FROM creature_template ct
LEFT JOIN creature c ON ct.entry = c.id1
WHERE ct.entry BETWEEN 700000 AND 700017
ORDER BY ct.entry;

-- =====================================================================
-- COMPLETION MESSAGE
-- =====================================================================
SELECT '✓ DUNGEON QUEST NPC TEMPLATES v4.0 COMPLETE' AS Status;
SELECT '✓ 18 Classic Dungeon Quest Masters created with unique models and spawn locations' AS Info;
SELECT '✓ Next Step: Import MASTER_CREATURE_QUEST_RELATIONS_v4.0.sql to link quests' AS NextAction;
