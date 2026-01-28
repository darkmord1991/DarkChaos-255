-- =====================================================================
-- Universal Quest Master NPC (Entry 700100)
-- DarkChaos Dungeon Quest System v4.1
-- =====================================================================
-- This SQL creates the universal quest master NPC that dynamically
-- shows quests based on the current dungeon/raid context.
-- 
-- Quests are sourced from creature_queststarter table:
--   - Dungeons: NPCs 700000-700054
--   - Raids: NPCs 700055-700071
-- =====================================================================

-- Create creature_template entry for Universal Quest Master
DELETE FROM creature_template WHERE entry = 700100;
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
-- Universal Quest Master: Dynamic dungeon/raid NPC
(700100, 0, 0, 0, 0, 0, 'Universal Quest Master', 'Dungeon & Raid Quests', 'Speak', 0, 80, 80, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 500, '', 0, 1, 2, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_universal_quest_master', 0);

-- =====================================================================
-- Add display_id column to dc_dungeon_npc_mapping if not exists
-- This allows dungeon-specific visual appearance for the Universal NPC
-- =====================================================================

SET @dbname = DATABASE();
SET @tablename = 'dc_dungeon_npc_mapping';
SET @columnname = 'display_id';
SET @preparedStatement = (SELECT IF(
  (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = @dbname
    AND TABLE_NAME = @tablename
    AND COLUMN_NAME = @columnname
  ) > 0,
  'SELECT 1',
  CONCAT('ALTER TABLE `', @tablename, '` ADD COLUMN `', @columnname, '` INT UNSIGNED DEFAULT 16466 COMMENT "DisplayId for Universal Quest Master in this dungeon"')
));
PREPARE alterIfNotExists FROM @preparedStatement;
EXECUTE alterIfNotExists;
DEALLOCATE PREPARE alterIfNotExists;

-- =====================================================================
-- Populate display_id from existing creature_template_model
-- Uses the same DisplayIDs that dungeon-specific NPCs already have
-- =====================================================================

UPDATE dc_dungeon_npc_mapping dnm
JOIN creature_template_model ctm ON dnm.quest_master_entry = ctm.CreatureID
SET dnm.display_id = ctm.CreatureDisplayID
WHERE dnm.display_id IS NULL OR dnm.display_id = 0;

-- Fallback: use generic Human Quest Giver (16466) for any without a model
UPDATE dc_dungeon_npc_mapping
SET display_id = 16466
WHERE display_id IS NULL OR display_id = 0;

-- =====================================================================
-- Create dc_dungeon_quest_mapping table 
-- Maps quest_id to map_id for the Universal Quest Master
-- =====================================================================

-- Drop and recreate to ensure correct schema (composite key)
DROP TABLE IF EXISTS `dc_dungeon_quest_mapping`;
CREATE TABLE `dc_dungeon_quest_mapping` (
    `quest_id` INT UNSIGNED NOT NULL COMMENT 'Quest template ID',
    `dungeon_id` INT UNSIGNED NOT NULL COMMENT 'Dungeon/Raid map ID',
    `enabled` TINYINT UNSIGNED NOT NULL DEFAULT 1,
    PRIMARY KEY (`quest_id`, `dungeon_id`),
    KEY `idx_dungeon` (`dungeon_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Maps quests to dungeons/raids for Universal Quest Master';

-- =====================================================================
-- Populate from creature_queststarter for ALL dungeon/raid NPCs
-- This is the PRIMARY source of quest data!
-- Source: MASTER_CREATURE_QUEST_RELATIONS_v5.0_BLIZZARD.sql (dungeons)
-- Source: ALL_RAIDS_QUESTS_v5.0.sql (raids)
-- =====================================================================

-- Insert ALL dungeon quests (NPCs 700000-700054)
INSERT IGNORE INTO dc_dungeon_quest_mapping (quest_id, dungeon_id, enabled)
SELECT cqs.quest, dnm.map_id, 1
FROM creature_queststarter cqs
JOIN dc_dungeon_npc_mapping dnm ON cqs.id = dnm.quest_master_entry
WHERE cqs.id BETWEEN 700000 AND 700054;

-- Insert ALL raid quests (NPCs 700055-700071)
INSERT IGNORE INTO dc_dungeon_quest_mapping (quest_id, dungeon_id, enabled)
SELECT cqs.quest, dnm.map_id, 1
FROM creature_queststarter cqs
JOIN dc_dungeon_npc_mapping dnm ON cqs.id = dnm.quest_master_entry
WHERE cqs.id BETWEEN 700055 AND 700071;

-- =====================================================================
-- Summary Report
-- =====================================================================
SELECT 'Universal Quest Master Setup Complete' AS Status;
SELECT 
    CONCAT('Total Quests Mapped: ', (SELECT COUNT(*) FROM dc_dungeon_quest_mapping)) AS QuestCount,
    CONCAT('Dungeons with Display IDs: ', (SELECT COUNT(*) FROM dc_dungeon_npc_mapping WHERE display_id IS NOT NULL AND display_id > 0)) AS DisplayIdCount;

-- Breakdown by type
SELECT 'Dungeon Quests (NPCs 700000-700054)' AS Type, COUNT(*) AS Count
FROM dc_dungeon_quest_mapping dqm
WHERE dqm.dungeon_id IN (SELECT map_id FROM dc_dungeon_npc_mapping WHERE quest_master_entry BETWEEN 700000 AND 700054)
UNION ALL
SELECT 'Raid Quests (NPCs 700055-700071)' AS Type, COUNT(*) AS Count
FROM dc_dungeon_quest_mapping dqm
WHERE dqm.dungeon_id IN (SELECT map_id FROM dc_dungeon_npc_mapping WHERE quest_master_entry BETWEEN 700055 AND 700071);
