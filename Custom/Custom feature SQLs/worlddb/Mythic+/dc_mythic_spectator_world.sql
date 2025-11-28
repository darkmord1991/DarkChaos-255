-- =====================================================================
-- DarkChaos Mythic+ Spectator System - WORLD Database Setup
-- =====================================================================
-- Run this on the `acore_world` database.
-- =====================================================================

-- Note: The M+ Spectator system primarily uses character database.
-- This file contains world database tables for spectator-related
-- configurations and NPC data.

-- Spectator NPC Information Table
-- For NPCs that provide spectator services
DROP TABLE IF EXISTS `dc_mythic_spectator_npcs`;
CREATE TABLE `dc_mythic_spectator_npcs` (
    `entry` INT UNSIGNED NOT NULL,
    `name` VARCHAR(100) NOT NULL,
    `subname` VARCHAR(100) DEFAULT 'M+ Spectator',
    `spawn_map` INT UNSIGNED NOT NULL DEFAULT 571 COMMENT 'Dalaran default',
    `spawn_x` FLOAT NOT NULL DEFAULT 5807.0,
    `spawn_y` FLOAT NOT NULL DEFAULT 588.0,
    `spawn_z` FLOAT NOT NULL DEFAULT 660.0,
    `spawn_o` FLOAT NOT NULL DEFAULT 3.14,
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='DarkChaos M+ Spectator - NPC Configuration';

-- Spectator Viewing Positions
-- Pre-defined camera positions for each dungeon
DROP TABLE IF EXISTS `dc_mythic_spectator_positions`;
CREATE TABLE `dc_mythic_spectator_positions` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `map_id` INT UNSIGNED NOT NULL,
    `position_name` VARCHAR(64) NOT NULL COMMENT 'e.g., "First Boss", "Entrance", "Final Boss"',
    `position_x` FLOAT NOT NULL,
    `position_y` FLOAT NOT NULL,
    `position_z` FLOAT NOT NULL,
    `orientation` FLOAT NOT NULL DEFAULT 0,
    `is_default` TINYINT(1) NOT NULL DEFAULT 0 COMMENT 'Default viewing position for spectators',
    PRIMARY KEY (`id`),
    INDEX `idx_map` (`map_id`),
    INDEX `idx_default` (`map_id`, `is_default`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='DarkChaos M+ Spectator - Viewing Positions';

-- Insert default viewing positions for common M+ dungeons
INSERT INTO `dc_mythic_spectator_positions` (`map_id`, `position_name`, `position_x`, `position_y`, `position_z`, `orientation`, `is_default`) VALUES
-- Utgarde Keep (574)
(574, 'Entrance', 156.0, -86.0, 17.0, 1.57, 1),
(574, 'First Boss', 276.0, -319.0, 52.0, 0.0, 0),
(574, 'Final Boss', 259.0, -360.0, 79.0, 3.14, 0),
-- The Nexus (576)
(576, 'Entrance', 180.0, -12.0, -16.0, 0.0, 1),
(576, 'Anomalus', 427.0, 93.0, -15.0, 0.0, 0),
(576, 'Keristrasza', 507.0, 96.0, -45.0, 0.0, 0),
-- Azjol-Nerub (601)
(601, 'Entrance', 535.0, 558.0, 241.0, 0.0, 1),
(601, 'Hadronox', 517.0, 544.0, 119.0, 0.0, 0),
(601, 'Final Boss', 583.0, 788.0, 53.0, 0.0, 0),
-- Ahn'kahet (619)
(619, 'Entrance', 361.0, -471.0, -220.0, 0.0, 1),
(619, 'First Boss', 383.0, -768.0, -276.0, 0.0, 0),
-- Drak'Tharon Keep (600)
(600, 'Entrance', -475.0, -765.0, 28.0, 0.0, 1),
(600, 'Final Boss', -261.0, -664.0, 26.0, 0.0, 0),
-- Violet Hold (608)
(608, 'Entrance', 1898.0, 798.0, 39.0, 0.0, 1),
-- Gundrak (604)
(604, 'Entrance', 1884.0, 650.0, 170.0, 0.0, 1),
(604, 'Final Boss', 1752.0, 697.0, 143.0, 0.0, 0),
-- Halls of Stone (599)
(599, 'Entrance', 1157.0, 786.0, 196.0, 0.0, 1),
(599, 'Tribunal', 1171.0, 490.0, 195.0, 0.0, 0),
-- Halls of Lightning (602)
(602, 'Entrance', 1331.0, -80.0, 63.0, 0.0, 1),
(602, 'Final Boss', 1423.0, -207.0, 52.0, 0.0, 0),
-- Oculus (578)
(578, 'Entrance', 960.0, 1038.0, 360.0, 0.0, 1),
-- Utgarde Pinnacle (575)
(575, 'Entrance', 264.0, -461.0, 109.0, 0.0, 1),
(575, 'Final Boss', 269.0, -356.0, 109.0, 0.0, 0),
-- Culling of Stratholme (595)
(595, 'Entrance', 2366.0, 1195.0, 130.0, 0.0, 1),
(595, 'Final Boss', 2545.0, 1124.0, 130.0, 0.0, 0),
-- Trial of the Champion (650)
(650, 'Entrance', 746.0, 617.0, 411.0, 0.0, 1),
-- Forge of Souls (632)
(632, 'Entrance', 5668.0, 2463.0, 708.0, 0.0, 1),
(632, 'Final Boss', 5627.0, 2249.0, 731.0, 0.0, 0),
-- Pit of Saron (658)
(658, 'Entrance', 433.0, 213.0, 528.0, 0.0, 1),
(658, 'Final Boss', 1062.0, 90.0, 630.0, 0.0, 0),
-- Halls of Reflection (668)
(668, 'Entrance', 5267.0, 1979.0, 707.0, 0.0, 1);

-- Spectator Broadcast Strings
DROP TABLE IF EXISTS `dc_mythic_spectator_strings`;
CREATE TABLE `dc_mythic_spectator_strings` (
    `id` INT UNSIGNED NOT NULL,
    `locale` VARCHAR(4) NOT NULL DEFAULT 'enUS',
    `text` VARCHAR(255) NOT NULL,
    PRIMARY KEY (`id`, `locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='DarkChaos M+ Spectator - Localized Strings';

-- Insert default strings
INSERT INTO `dc_mythic_spectator_strings` (`id`, `locale`, `text`) VALUES
(1, 'enUS', '[M+ Spectator] Now watching: %s (+%d %s)'),
(2, 'enUS', '[M+ Spectator] Switched view to: %s'),
(3, 'enUS', '[M+ Spectator] The run has ended. You have been returned.'),
(4, 'enUS', '[M+ Spectator] Boss defeated: %s (%d/%d)'),
(5, 'enUS', '[M+ Spectator] Timer: %d:%02d remaining'),
(6, 'enUS', '[M+ Spectator] RUN COMPLETED! Time: %d:%02d'),
(7, 'enUS', '[M+ Spectator] Run failed - time expired.'),
(8, 'enUS', '[M+ Spectator] You are now in stream mode (names hidden).'),
(9, 'enUS', '[M+ Spectator] Recording started for this run.'),
(10, 'enUS', '[M+ Spectator] Recording saved. Replay ID: %d');

-- =====================================================================
-- Creature Template for Spectator NPC (uncomment to use)
-- =====================================================================
-- INSERT INTO creature_template (entry, name, subname, ScriptName, unit_flags) VALUES
-- (1000010, 'M+ Spectator Guide', 'Mythic+ Spectating', 'npc_dc_mythic_spectator', 2);
--
-- INSERT INTO creature (id, map, position_x, position_y, position_z, orientation) VALUES
-- (1000010, 571, 5807.0, 588.0, 660.0, 3.14);  -- Dalaran
