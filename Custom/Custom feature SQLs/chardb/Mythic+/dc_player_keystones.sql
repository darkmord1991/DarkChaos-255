/*
 * Mythic+ Keystone Player Progress Tables
 * Tracks each player's current keystone level and run history
 * Database: acore_characters (for per-character data)
 */

-- ============================================================
-- TABLE: Player Mythic+ Keystones (CHARACTER DB)
-- ============================================================

DROP TABLE IF EXISTS dc_player_keystones;
CREATE TABLE dc_player_keystones (
    player_guid BIGINT UNSIGNED NOT NULL PRIMARY KEY,
    account_id INT UNSIGNED NOT NULL,
    current_keystone_level TINYINT UNSIGNED DEFAULT 2,
    last_completed_level TINYINT UNSIGNED DEFAULT 0,
    best_run_level TINYINT UNSIGNED DEFAULT 0,
    last_keystone_used TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_on BIGINT UNSIGNED DEFAULT 0 COMMENT 'Unix timestamp when keystone expires',
    last_updated INT UNSIGNED DEFAULT 0 COMMENT 'Unix timestamp of last keystone update',
    runs_completed INT UNSIGNED DEFAULT 0,
    runs_failed INT UNSIGNED DEFAULT 0,
    INDEX idx_account (account_id),
    INDEX idx_best_run (best_run_level)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- TABLE: Mythic+ Run History
-- ============================================================

DROP TABLE IF EXISTS dc_mythic_run_history;
CREATE TABLE dc_mythic_run_history (
    run_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    party_leader_guid BIGINT UNSIGNED NOT NULL,
    keystone_level TINYINT UNSIGNED NOT NULL,
    dungeon_id INT UNSIGNED NOT NULL,
    run_start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    run_duration INT UNSIGNED,
    run_success BOOLEAN DEFAULT FALSE,
    time_limit_seconds INT UNSIGNED,
    time_remaining_seconds INT UNSIGNED,
    reward_ilvl SMALLINT UNSIGNED,
    difficulty_scaling FLOAT DEFAULT 1.0,
    INDEX idx_leader (party_leader_guid),
    INDEX idx_level (keystone_level),
    INDEX idx_dungeon (dungeon_id),
    INDEX idx_success (run_success)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- TABLE: Party Runs (Track multi-player runs)
-- ============================================================

DROP TABLE IF EXISTS dc_mythic_party_members;
CREATE TABLE dc_mythic_party_members (
    run_id INT UNSIGNED NOT NULL,
    player_guid BIGINT UNSIGNED NOT NULL,
    role VARCHAR(20),
    class_id TINYINT UNSIGNED,
    damage_done BIGINT UNSIGNED DEFAULT 0,
    healing_done BIGINT UNSIGNED DEFAULT 0,
    deaths INT UNSIGNED DEFAULT 0,
    PRIMARY KEY (run_id, player_guid),
    INDEX idx_run (run_id),
    FOREIGN KEY (run_id) REFERENCES dc_mythic_run_history(run_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- INITIALIZATION: Sample data for documentation
-- ============================================================

/*
 * When a player receives a keystone from the NPC:
 * 1. Check dc_player_keystones for their current level (default M+2)
 * 2. Give keystone item (300313-300321) matching their level
 * 
 * When player uses keystone on pedestal:
 * 1. Verify keystone item exists in inventory
 * 2. Record run start in dc_mythic_run_history
 * 3. Consume keystone item
 * 4. Apply dungeon scaling based on keystone level
 * 5. Start run timer (20 minutes + 5 minutes per level bonus)
 * 
 * On run completion:
 * 1. Determine if run was successful (time limit not exceeded)
 * 2. If success: Upgrade keystone to next level (M+2 → M+3)
 * 3. If failure: Downgrade keystone to previous level (M+5 → M+4)
 * 4. If time perfect (no deaths): Award bonus loot
 * 5. Update player record with new keystone level
 * 6. Generate new keystone item for next run
 * 7. Add run to history for statistics
 */
