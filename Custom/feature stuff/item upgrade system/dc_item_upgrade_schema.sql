-- DarkChaos-255: Item Upgrade System Database Schema
-- Tables for managing upgradeable items, tracks, and player progression

-- ============================================================================
-- TABLE 1: Upgrade Tracks Definition
-- ============================================================================
-- Defines each upgrade track (HLBG, Heroic, Mythic, etc.)
-- Contains progression rules, iLvl ranges, and costs

CREATE TABLE IF NOT EXISTS dc_upgrade_tracks (
  track_id INT PRIMARY KEY AUTO_INCREMENT COMMENT 'Unique track identifier',
  track_name VARCHAR(100) NOT NULL COMMENT 'Display name: Heroic Dungeon, Mythic Raid, etc.',
  source_content VARCHAR(50) NOT NULL COMMENT 'Content type: dungeon, raid, hlbg, mythic_plus',
  difficulty VARCHAR(50) NOT NULL COMMENT 'Difficulty: heroic, mythic, mythic+5, etc.',
  
  -- Item Level Progression
  base_ilvl INT NOT NULL COMMENT 'Starting item level from this content',
  max_ilvl INT NOT NULL COMMENT 'Maximum item level after all upgrades',
  upgrade_steps TINYINT NOT NULL DEFAULT 5 COMMENT 'Number of upgrade stages (0-5 usually)',
  ilvl_per_step TINYINT NOT NULL DEFAULT 4 COMMENT 'Item level gain per step (+3 or +4)',
  
  -- Currency Costs
  token_cost_per_upgrade INT NOT NULL DEFAULT 10 COMMENT 'Upgrade tokens needed per step',
  flightstone_cost_base INT NOT NULL DEFAULT 50 COMMENT 'Base flightstone cost (scaled by slot)',
  
  -- Access Requirements
  required_player_level INT NOT NULL DEFAULT 80 COMMENT 'Minimum player level to use this track',
  required_item_level INT NOT NULL DEFAULT 200 COMMENT 'Minimum gear iLvl to access this track',
  
  -- Metadata
  description VARCHAR(255) COMMENT 'UI description for players',
  active BOOLEAN NOT NULL DEFAULT TRUE COMMENT 'Is this track currently available?',
  season INT NOT NULL DEFAULT 0 COMMENT '0 = permanent, else season number',
  created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  UNIQUE KEY uk_track (source_content, difficulty, season),
  KEY k_active (active),
  KEY k_season (season)
) ENGINE=INNODB DEFAULT CHARSET=utf8mb4 COMMENT='Upgrade track definitions';

-- Sample Track Data
INSERT INTO dc_upgrade_tracks (track_name, source_content, difficulty, base_ilvl, max_ilvl, 
                               upgrade_steps, ilvl_per_step, token_cost_per_upgrade, 
                               flightstone_cost_base, required_player_level, required_item_level, 
                               description, season) VALUES
('HLBG Progression', 'hlbg', 'normal', 219, 239, 5, 4, 8, 40, 80, 200, 'Upgrade items from Hinterlands BG', 0),
('Heroic Dungeon Gear', 'dungeon', 'heroic', 226, 245, 5, 4, 10, 50, 80, 210, 'Upgrade items from heroic dungeons', 0),
('Mythic Dungeon Gear', 'dungeon', 'mythic', 239, 258, 5, 4, 12, 60, 80, 225, 'Upgrade items from mythic dungeons', 0),
('Raid Normal', 'raid', 'normal', 245, 264, 5, 4, 15, 75, 80, 240, 'Upgrade items from raid normal', 0),
('Raid Heroic', 'raid', 'heroic', 258, 277, 5, 4, 18, 90, 85, 250, 'Upgrade items from raid heroic', 0),
('Raid Mythic', 'raid', 'mythic', 271, 290, 5, 4, 20, 100, 90, 270, 'Upgrade items from raid mythic', 0);

-- ============================================================================
-- TABLE 2: Item Upgrade Chains
-- ============================================================================
-- Maps base items to their upgrade chains (different item IDs for each iLvl)
-- LOW EFFORT APPROACH: One item entry per iLvl level

CREATE TABLE IF NOT EXISTS dc_item_upgrade_chains (
  chain_id INT PRIMARY KEY AUTO_INCREMENT COMMENT 'Unique chain identifier',
  
  -- Item Identity
  base_item_name VARCHAR(100) NOT NULL COMMENT 'Base item name (e.g. "Heroic Chestplate")',
  item_quality INT NOT NULL DEFAULT 4 COMMENT 'Item quality (2-5, usually 4 for epic)',
  item_slot VARCHAR(50) NOT NULL COMMENT 'Item slot: chest, head, legs, etc.',
  item_type VARCHAR(50) NOT NULL COMMENT 'Item type: plate, mail, cloth, etc.',
  
  -- Track Assignment
  track_id INT NOT NULL COMMENT 'Which upgrade track this item belongs to',
  
  -- Item Entry IDs (one for each upgrade level)
  -- Using formula: BASE_ENTRY + (TRACK_ID * 1000) + (UPGRADE_LEVEL * 10)
  ilvl_0_entry INT NOT NULL COMMENT 'Entry ID at base iLvl (upgrade level 0)',
  ilvl_1_entry INT NOT NULL COMMENT 'Entry ID at base + 4 iLvl',
  ilvl_2_entry INT NOT NULL COMMENT 'Entry ID at base + 8 iLvl',
  ilvl_3_entry INT NOT NULL COMMENT 'Entry ID at base + 12 iLvl',
  ilvl_4_entry INT NOT NULL COMMENT 'Entry ID at base + 16 iLvl',
  ilvl_5_entry INT NOT NULL COMMENT 'Entry ID at base + 20 iLvl (max)',
  
  -- Metadata
  season INT NOT NULL DEFAULT 0 COMMENT '0 = permanent item',
  description VARCHAR(255),
  created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  FOREIGN KEY (track_id) REFERENCES dc_upgrade_tracks(track_id),
  UNIQUE KEY uk_chain (base_item_name, track_id, season),
  KEY k_track (track_id),
  KEY k_season (season)
) ENGINE=INNODB DEFAULT CHARSET=utf8mb4 COMMENT='Item upgrade progression chains';

-- SAMPLE DATA: Heroic Chestplate (track_id = 2 for Heroic Dungeons)
-- Real implementation would create 50+ chains from existing item_template
-- INSERT INTO dc_item_upgrade_chains VALUES
-- (1, 'Heroic Chestplate of the Eternal', 4, 'chest', 'plate', 2,
--  50010, 50020, 50030, 50040, 50050, 50060,
--  0, 'Upgradeable heroic chestplate', NOW());

-- ============================================================================
-- TABLE 3: Player Item Upgrade History
-- ============================================================================
-- Tracks current upgrade level for each item in player inventory
-- Enables checking "can this item be upgraded?" queries quickly

CREATE TABLE IF NOT EXISTS dc_player_item_upgrades (
  upgrade_id INT PRIMARY KEY AUTO_INCREMENT,
  character_guid INT NOT NULL COMMENT 'Character GUID (from characters table)',
  
  -- Item Tracking
  item_guid INT UNIQUE NOT NULL COMMENT 'Unique item instance GUID',
  base_item_name VARCHAR(100) NOT NULL,
  
  -- Current State
  current_ilvl INT NOT NULL COMMENT 'Current item level',
  max_possible_ilvl INT NOT NULL COMMENT 'Max iLvl for this track/player combo',
  current_upgrade_level TINYINT NOT NULL DEFAULT 0 COMMENT '0-5 usually',
  
  -- Timing
  first_upgraded TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_upgraded TIMESTAMP,
  
  -- Metadata
  track_id INT NOT NULL,
  season INT NOT NULL DEFAULT 0,
  
  FOREIGN KEY (track_id) REFERENCES dc_upgrade_tracks(track_id),
  KEY k_character (character_guid),
  KEY k_item_guid (item_guid),
  KEY k_season (season)
) ENGINE=INNODB DEFAULT CHARSET=utf8mb4 COMMENT='Player item upgrade state';

-- ============================================================================
-- TABLE 4: Player Currency Balances
-- ============================================================================
-- Tracks token and flightstone currency per player
-- Can use existing character_currency table or create custom

CREATE TABLE IF NOT EXISTS dc_player_currencies (
  currency_id INT PRIMARY KEY AUTO_INCREMENT,
  character_guid INT NOT NULL UNIQUE COMMENT 'Unique per character',
  
  -- Primary Currency: Upgrade Tokens
  upgrade_tokens INT NOT NULL DEFAULT 0 COMMENT 'Accumulated upgrade tokens',
  tokens_earned_total INT NOT NULL DEFAULT 0 COMMENT 'Lifetime tokens earned (stats)',
  tokens_spent_total INT NOT NULL DEFAULT 0 COMMENT 'Lifetime tokens spent (stats)',
  
  -- Secondary Currency: Flightstones
  flightstones INT NOT NULL DEFAULT 0 COMMENT 'Current flightstone balance',
  flightstones_earned_total INT NOT NULL DEFAULT 0 COMMENT 'Lifetime earned',
  flightstones_spent_total INT NOT NULL DEFAULT 0 COMMENT 'Lifetime spent',
  
  -- Weekly Caps
  tokens_earned_this_week INT NOT NULL DEFAULT 0,
  flightstones_earned_this_week INT NOT NULL DEFAULT 0,
  week_reset_date DATE COMMENT 'When weekly cap resets',
  
  -- Metadata
  last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  season INT NOT NULL DEFAULT 0,
  
  KEY k_guid (character_guid),
  KEY k_season (season)
) ENGINE=INNODB DEFAULT CHARSET=utf8mb4 COMMENT='Player currency balances';

-- ============================================================================
-- TABLE 5: Currency Acquisition Rules
-- ============================================================================
-- Defines how much currency players earn from different content sources

CREATE TABLE IF NOT EXISTS dc_currency_rewards (
  reward_id INT PRIMARY KEY AUTO_INCREMENT,
  
  -- Source Definition
  source_type VARCHAR(50) NOT NULL COMMENT 'dungeon, raid, quest, daily, etc.',
  source_difficulty VARCHAR(50) COMMENT 'heroic, mythic, etc. (NULL = all difficulties)',
  
  -- Rewards
  tokens_awarded INT NOT NULL DEFAULT 0 COMMENT 'Tokens given per completion',
  flightstones_awarded INT NOT NULL DEFAULT 0 COMMENT 'Flightstones per completion',
  
  -- Availability
  active BOOLEAN NOT NULL DEFAULT TRUE,
  season INT NOT NULL DEFAULT 0,
  
  -- Metadata
  notes VARCHAR(255),
  
  UNIQUE KEY uk_reward (source_type, source_difficulty, season),
  KEY k_active (active)
) ENGINE=INNODB DEFAULT CHARSET=utf8mb4 COMMENT='Currency reward table';

-- Sample Rewards
INSERT INTO dc_currency_rewards (source_type, source_difficulty, tokens_awarded, flightstones_awarded, notes) VALUES
('hlbg', NULL, 3, 15, 'Hinterlands BG victory'),
('dungeon', 'heroic', 5, 25, 'Heroic dungeon clear'),
('dungeon', 'mythic', 8, 50, 'Mythic dungeon clear'),
('raid', 'normal', 10, 75, 'Raid normal boss kill'),
('raid', 'heroic', 15, 90, 'Raid heroic boss kill'),
('raid', 'mythic', 20, 100, 'Raid mythic boss kill');

-- ============================================================================
-- TABLE 6: NPC Configuration
-- ============================================================================
-- Defines which NPCs offer item upgrades and which tracks they have

CREATE TABLE IF NOT EXISTS dc_item_upgrade_npcs (
  npc_id INT PRIMARY KEY AUTO_INCREMENT,
  npc_entry INT NOT NULL UNIQUE COMMENT 'Creature entry from creature_template',
  npc_name VARCHAR(100) NOT NULL,
  
  -- Tracks they offer (JSON format or comma-separated)
  available_track_ids VARCHAR(255) NOT NULL COMMENT 'JSON: [1, 2, 3] or comma-separated',
  
  -- Location
  map_id INT NOT NULL,
  location_x FLOAT NOT NULL,
  location_y FLOAT NOT NULL,
  location_z FLOAT NOT NULL,
  orientation FLOAT DEFAULT 0,
  
  -- Availability
  season INT NOT NULL DEFAULT 0 COMMENT '0 = permanent',
  active BOOLEAN NOT NULL DEFAULT TRUE,
  description VARCHAR(255),
  
  KEY k_entry (npc_entry),
  KEY k_active (active)
) ENGINE=INNODB DEFAULT CHARSET=utf8mb4 COMMENT='Item upgrade NPC locations';

-- Sample NPC (Requires creature_template entry to exist)
-- INSERT INTO dc_item_upgrade_npcs VALUES
-- (1, 600001, 'Item Master Velisande', '[1, 2, 3, 4, 5, 6]', 1, -8949.95, -132.493, 83.6112, 1.5, 0, TRUE, 'Main upgrade NPC - all tracks');

-- ============================================================================
-- TABLE 7: Upgrade Price Modifiers
-- ============================================================================
-- Item slot affects flightstone cost (heavy slots more expensive)

CREATE TABLE IF NOT EXISTS dc_item_slot_modifiers (
  modifier_id INT PRIMARY KEY AUTO_INCREMENT,
  item_slot VARCHAR(50) NOT NULL UNIQUE COMMENT 'chest, head, legs, etc.',
  flightstone_multiplier FLOAT NOT NULL DEFAULT 1.0 COMMENT '1.5 = 50% more expensive',
  token_multiplier FLOAT NOT NULL DEFAULT 1.0,
  description VARCHAR(255)
) ENGINE=INNODB DEFAULT CHARSET=utf8mb4;

-- Sample slot costs
INSERT INTO dc_item_slot_modifiers (item_slot, flightstone_multiplier, token_multiplier, description) VALUES
('chest', 1.5, 1.0, 'Heavy slot - most expensive'),
('head', 1.5, 1.0, 'Heavy slot - most expensive'),
('legs', 1.5, 1.0, 'Heavy slot - most expensive'),
('shoulders', 1.2, 1.0, 'Medium slot'),
('hands', 1.2, 1.0, 'Medium slot'),
('waist', 1.2, 1.0, 'Medium slot'),
('feet', 1.2, 1.0, 'Medium slot'),
('wrist', 1.0, 1.0, 'Light slot'),
('back', 1.0, 1.0, 'Light slot'),
('neck', 0.8, 0.9, 'Accessory - cheapest'),
('finger', 0.8, 0.9, 'Accessory - cheapest'),
('trinket', 1.0, 1.0, 'Special slot');

-- ============================================================================
-- TABLE 8: Upgrade Transaction Log (Optional)
-- ============================================================================
-- Audit trail for all upgrade operations

CREATE TABLE IF NOT EXISTS dc_upgrade_log (
  log_id INT PRIMARY KEY AUTO_INCREMENT,
  character_guid INT NOT NULL,
  character_name VARCHAR(50),
  
  -- Transaction Details
  from_item_entry INT NOT NULL COMMENT 'Original item ID',
  to_item_entry INT NOT NULL COMMENT 'Upgraded item ID',
  from_ilvl INT NOT NULL,
  to_ilvl INT NOT NULL,
  
  -- Cost
  tokens_paid INT NOT NULL,
  flightstones_paid INT NOT NULL,
  
  -- Timing
  upgrade_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  -- Analytics
  upgrade_level TINYINT COMMENT '0-5',
  track_id INT,
  
  KEY k_character (character_guid),
  KEY k_date (upgrade_date),
  KEY k_track (track_id)
) ENGINE=INNODB DEFAULT CHARSET=utf8mb4 COMMENT='Upgrade transaction audit log';

-- ============================================================================
-- KEY INDEXES FOR PERFORMANCE
-- ============================================================================

-- Query: "Get all upgradeable items in inventory"
CREATE INDEX idx_chain_track_name ON dc_item_upgrade_chains(track_id, base_item_name);

-- Query: "Get player currency balance"
CREATE INDEX idx_currency_character ON dc_player_currencies(character_guid);

-- Query: "Find upgrades for item"
CREATE INDEX idx_player_upgrades_item ON dc_player_item_upgrades(item_guid, character_guid);

-- ============================================================================
-- STORED PROCEDURES
-- ============================================================================

-- Get next upgrade cost for an item
DELIMITER //
CREATE PROCEDURE dc_get_upgrade_cost(
  IN p_item_entry INT,
  OUT p_token_cost INT,
  OUT p_flightstone_cost INT,
  OUT p_next_item_entry INT,
  OUT p_next_ilvl INT
)
BEGIN
  DECLARE v_chain_id INT;
  DECLARE v_item_slot VARCHAR(50);
  DECLARE v_flightstone_base INT;
  DECLARE v_slot_modifier FLOAT;
  
  -- Find the chain this item belongs to
  SELECT chain_id, item_slot INTO v_chain_id, v_item_slot
  FROM dc_item_upgrade_chains
  WHERE ilvl_0_entry = p_item_entry 
     OR ilvl_1_entry = p_item_entry
     OR ilvl_2_entry = p_item_entry
     OR ilvl_3_entry = p_item_entry
     OR ilvl_4_entry = p_item_entry
     OR ilvl_5_entry = p_item_entry
  LIMIT 1;
  
  IF v_chain_id IS NULL THEN
    SET p_token_cost = 0;
    SET p_flightstone_cost = 0;
    LEAVE;
  END IF;
  
  -- Get track costs
  SELECT t.token_cost_per_upgrade, t.flightstone_cost_base
  INTO p_token_cost, v_flightstone_base
  FROM dc_upgrade_tracks t
  WHERE t.track_id = (
    SELECT track_id FROM dc_item_upgrade_chains WHERE chain_id = v_chain_id
  );
  
  -- Apply slot multiplier
  SELECT flightstone_multiplier INTO v_slot_modifier
  FROM dc_item_slot_modifiers
  WHERE item_slot = v_item_slot;
  
  SET p_flightstone_cost = ROUND(v_flightstone_base * v_slot_modifier);
  
  -- Calculate next item entry
  IF p_item_entry = (SELECT ilvl_0_entry FROM dc_item_upgrade_chains WHERE chain_id = v_chain_id) THEN
    SELECT ilvl_1_entry, 4 INTO p_next_item_entry, p_next_ilvl FROM dc_item_upgrade_chains WHERE chain_id = v_chain_id;
  ELSEIF p_item_entry = (SELECT ilvl_1_entry FROM dc_item_upgrade_chains WHERE chain_id = v_chain_id) THEN
    SELECT ilvl_2_entry, 8 INTO p_next_item_entry, p_next_ilvl FROM dc_item_upgrade_chains WHERE chain_id = v_chain_id;
  ELSEIF p_item_entry = (SELECT ilvl_2_entry FROM dc_item_upgrade_chains WHERE chain_id = v_chain_id) THEN
    SELECT ilvl_3_entry, 12 INTO p_next_item_entry, p_next_ilvl FROM dc_item_upgrade_chains WHERE chain_id = v_chain_id;
  ELSEIF p_item_entry = (SELECT ilvl_3_entry FROM dc_item_upgrade_chains WHERE chain_id = v_chain_id) THEN
    SELECT ilvl_4_entry, 16 INTO p_next_item_entry, p_next_ilvl FROM dc_item_upgrade_chains WHERE chain_id = v_chain_id;
  ELSEIF p_item_entry = (SELECT ilvl_4_entry FROM dc_item_upgrade_chains WHERE chain_id = v_chain_id) THEN
    SELECT ilvl_5_entry, 20 INTO p_next_item_entry, p_next_ilvl FROM dc_item_upgrade_chains WHERE chain_id = v_chain_id;
  ELSE
    -- Already at max
    SET p_token_cost = 0;
    SET p_next_item_entry = NULL;
  END IF;
END //
DELIMITER ;

-- ============================================================================
-- VERSION TRACKING
-- ============================================================================

CREATE TABLE IF NOT EXISTS dc_item_upgrade_version (
  version_id INT PRIMARY KEY AUTO_INCREMENT,
  schema_version VARCHAR(20),
  implemented_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  notes TEXT
) ENGINE=INNODB;

INSERT INTO dc_item_upgrade_version (schema_version, notes) VALUES
('1.0', 'Initial schema: tracks, chains, currencies, NPCs');
