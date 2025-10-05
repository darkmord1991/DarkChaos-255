# HLBG Server Integration Requirements

## Current Status
The HLBG addon is ready for server integration but currently uses placeholder/test data.

## Required Server Integration Points

### 1. Database Schema Requirements
**Suggested Database Tables**:

```sql
-- Main HLBG configuration table
CREATE TABLE `hlbg_config` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `duration_minutes` INT DEFAULT 30,
    `max_players_per_side` INT DEFAULT 40,
    `min_level` INT DEFAULT 255,
    `max_level` INT DEFAULT 255,
    `affix_rotation_enabled` BOOLEAN DEFAULT TRUE,
    `resource_cap` INT DEFAULT 500,
    `queue_type` VARCHAR(50) DEFAULT 'Level255Only',
    `last_updated` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Season information table  
CREATE TABLE `hlbg_seasons` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(100) NOT NULL,
    `start_date` DATE NOT NULL,
    `end_date` DATE NOT NULL,
    `rewards` TEXT,
    `is_active` BOOLEAN DEFAULT FALSE
);

-- Comprehensive statistics table
CREATE TABLE `hlbg_statistics` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `total_runs` INT DEFAULT 0,
    `alliance_wins` INT DEFAULT 0,
    `horde_wins` INT DEFAULT 0,
    `draws` INT DEFAULT 0,
    `manual_resets` INT DEFAULT 0,
    `current_streak_faction` VARCHAR(20) DEFAULT 'None',
    `current_streak_count` INT DEFAULT 0,
    `longest_streak_faction` VARCHAR(20) DEFAULT 'None',
    `longest_streak_count` INT DEFAULT 0,
    `avg_run_time_seconds` INT DEFAULT 0,
    `shortest_run_seconds` INT DEFAULT 0,
    `longest_run_seconds` INT DEFAULT 0,
    `most_popular_affix` INT DEFAULT 0,
    `last_reset_by_gm` TIMESTAMP NULL,
    `server_start_time` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `last_updated` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

### 2. HL_ScoreboardNPC.cpp Integration
**Location**: `src\server\scripts\DC\HinterlandBG\HL_ScoreboardNPC.cpp`

**Required AIO Handlers to Add**:

```cpp
// Request handlers (client requests data)
AIO_Handle("HLBG", "RequestServerConfig", [](Player* player, AIO* aio, AIOPacket* packet) {
    // Query database for current configuration
    QueryResult result = WorldDatabase.Query("SELECT * FROM hlbg_config ORDER BY id DESC LIMIT 1");
    
    if (result) {
        Field* fields = result->Fetch();
        AIOPacket data;
        data.WriteU32(fields[1].GetUInt32()); // duration_minutes
        data.WriteU32(fields[2].GetUInt32()); // max_players_per_side  
        data.WriteU32(fields[3].GetUInt32()); // min_level
        data.WriteU32(fields[4].GetUInt32()); // max_level
        data.WriteBool(fields[5].GetBool());  // affix_rotation_enabled
        data.WriteU32(fields[6].GetUInt32()); // resource_cap
        data.WriteString(fields[7].GetString()); // queue_type
        
        AIO_SendPacket(player, "HLBG", "ServerConfig", data);
    }
});

AIO_Handle("HLBG", "RequestSeasonInfo", [](Player* player, AIO* aio, AIOPacket* packet) {
    QueryResult result = WorldDatabase.Query("SELECT * FROM hlbg_seasons WHERE is_active = 1 LIMIT 1");
    
    if (result) {
        Field* fields = result->Fetch();
        AIOPacket data;
        data.WriteString(fields[1].GetString()); // name
        data.WriteString(fields[2].GetString()); // start_date
        data.WriteString(fields[3].GetString()); // end_date
        data.WriteString(fields[4].GetString()); // rewards
        
        AIO_SendPacket(player, "HLBG", "UpdateSeasonInfo", data);
    }
});

AIO_Handle("HLBG", "RequestStats", [](Player* player, AIO* aio, AIOPacket* packet) {
    QueryResult result = WorldDatabase.Query("SELECT * FROM hlbg_statistics ORDER BY id DESC LIMIT 1");
    
    if (result) {
        Field* fields = result->Fetch();
        AIOPacket data;
        data.WriteU32(fields[1].GetUInt32()); // total_runs
        data.WriteU32(fields[2].GetUInt32()); // alliance_wins
        data.WriteU32(fields[3].GetUInt32()); // horde_wins
        data.WriteU32(fields[4].GetUInt32()); // draws
        data.WriteU32(fields[5].GetUInt32()); // manual_resets
        data.WriteString(fields[6].GetString()); // current_streak_faction
        data.WriteU32(fields[7].GetUInt32()); // current_streak_count
        data.WriteString(fields[8].GetString()); // longest_streak_faction
        data.WriteU32(fields[9].GetUInt32()); // longest_streak_count
        data.WriteU32(fields[10].GetUInt32()); // avg_run_time_seconds
        data.WriteU32(fields[11].GetUInt32()); // shortest_run_seconds
        data.WriteU32(fields[12].GetUInt32()); // longest_run_seconds
        data.WriteU32(fields[13].GetUInt32()); // most_popular_affix
        
        // Calculate server uptime
        time_t now = time(nullptr);
        time_t start = fields[15].GetUInt32(); // server_start_time
        uint32 uptimeDays = (now - start) / 86400;
        data.WriteU32(uptimeDays);
        
        AIO_SendPacket(player, "HLBG", "UpdateScoreboardStats", data);
    }
});

// Update handlers (when battles end, reset, etc)
void UpdateHLBGStats(const std::string& winner, uint32 duration, uint32 affix) {
    // Update statistics in database
    WorldDatabase.Execute("UPDATE hlbg_statistics SET total_runs = total_runs + 1, {} = {} + 1, avg_run_time_seconds = (avg_run_time_seconds + {}) / 2",
        winner == "Alliance" ? "alliance_wins" : (winner == "Horde" ? "horde_wins" : "draws"),
        winner == "Alliance" ? "alliance_wins" : (winner == "Horde" ? "horde_wins" : "draws"),
        duration);
    
    // Update win streaks, shortest/longest runs, etc.
    // ... additional logic for comprehensive stats
    
    // Notify all online players
    for (auto& player : sWorld->GetAllSessions()) {
        if (player->GetPlayer()) {
            // Send updated stats to client
            AIO_Handle("HLBG", "RequestStats")(player->GetPlayer(), nullptr, nullptr);
        }
    }
}
```

### 2. Real-time Battle Status
**Current**: Uses test data (A: 350, H: 280)
**Needed**: Live resource counts from active HLBG battles

**Required Handler**:
```cpp
AIO_Handle("HLBG", "UpdateLiveBattle", [](Player* player, AIO* aio, AIOPacket* packet) {
    BattleStatus status = GetCurrentBattleStatus();
    
    AIOPacket data;
    data.WriteU32(status.allianceResources);
    data.WriteU32(status.hordeResources);
    data.WriteU32(status.currentAffix);
    data.WriteU32(status.timeRemaining);
    
    AIO_SendPacket(player, "HLBG", "Status", data);
});
```

### 3. Battle History Integration
**Current**: Shows 24 fake history entries
**Needed**: Real battle results from database

**Required Handler**:
```cpp
AIO_Handle("HLBG", "UpdateBattleHistory", [](Player* player, AIO* aio, AIOPacket* packet) {
    std::vector<BattleResult> history = GetRecentBattles(24);
    
    AIOPacket data;
    data.WriteU32(history.size());
    
    for (const auto& battle : history) {
        data.WriteU32(battle.id);
        data.WriteString(battle.date);
        data.WriteString(battle.winner); // "Alliance", "Horde", or "Draw"
        data.WriteU32(battle.affix);
        data.WriteU32(battle.duration);
    }
    
    AIO_SendPacket(player, "HLBG", "History", data);
});
```

## Client-Side Handlers (Already Implemented)
The following handlers are ready on the client side:

- `HLBG.UpdateScoreboardStats` - Receives real stats
- `HLBG.UpdateSeasonInfo` - Receives season data  
- `HLBG.UpdateServerSettings` - Receives server config
- `Status` - Updates live battle status
- `History` - Updates battle history
- `Stats` - Updates statistics

## Commands for Testing
- `/hlbghud test` - Load test data and force HUD display
- `/hlbg live` - View current status (will show real data once server integrated)
- `/hlbg stats` - View statistics (currently shows placeholder)
- `/hlbg settings` - Interactive settings panel

## Notes
1. The addon currently works with test/placeholder data
2. All UI elements are functional and ready for real server data
3. Statistics tab specifically mentions the need for HL_ScoreboardNPC.cpp integration
4. Once server handlers are implemented, remove the test data generation
