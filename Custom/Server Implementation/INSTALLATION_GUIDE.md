# HLBG Server Implementation - Installation Guide

## ?? Installation Steps

### 1. Database Setup

**Execute the SQL schema:**
```bash
# Navigate to your AzerothCore directory
cd /path/to/azerothcore

# Import the database schema
mysql -u root -p world < "Custom/Server Implementation/hlbg_database_schema.sql"
```

**Verify tables were created:**
```sql
USE world;
SHOW TABLES LIKE 'hlbg%';
```

Expected output:
- `hlbg_affixes`
- `hlbg_battle_history` 
- `hlbg_config`
- `hlbg_player_stats`
- `hlbg_seasons`
- `hlbg_statistics`

### 2. Server Code Integration

**Add the AIO handlers to your project:**

1. **Copy handler file:**
   ```bash
   cp "Custom/Server Implementation/HLBG_AIO_Handlers.cpp" "src/server/scripts/DC/HinterlandBG/"
   ```

2. **Add to CMakeLists.txt:**
   ```cmake
   # In src/server/scripts/DC/HinterlandBG/CMakeLists.txt
   set(scripts_STAT_SRCS
     ${scripts_STAT_SRCS}
     DC/HinterlandBG/HL_ScoreboardNPC.cpp
     DC/HinterlandBG/HLBG_AIO_Handlers.cpp  # Add this line
   )
   ```

3. **Initialize in World.cpp:**
   ```cpp
   // In src/server/worldserver/World/World.cpp
   // Add in World::SetInitialWorldSettings() or similar initialization function
   
   #include "path/to/HLBG_AIO_Handlers.cpp"
   
   void World::SetInitialWorldSettings()
   {
       // ... existing code ...
       
       // Initialize HLBG handlers
       InitializeHLBGHandlers();
       
       LOG_INFO("server.loading", "HLBG AIO handlers initialized");
   }
   ```

### 3. GM Commands Integration

**Add GM commands:**

1. **Copy command file:**
   ```bash
   cp "Custom/Server Implementation/HLBG_GM_Commands.cpp" "src/server/scripts/Commands/"
   ```

2. **Add to Commands CMakeLists.txt:**
   ```cmake
   # In src/server/scripts/Commands/CMakeLists.txt
   set(scripts_STAT_SRCS
     ${scripts_STAT_SRCS}
     Commands/cs_account.cpp
     Commands/cs_achievement.cpp
     # ... existing commands ...
     Commands/HLBG_GM_Commands.cpp  # Add this line
   )
   ```

3. **Register in ScriptLoader.cpp:**
   ```cpp
   // In src/server/scripts/ScriptLoader.cpp
   void AddSC_hlbg_commandscript();  // Add declaration
   
   void AddScripts()
   {
       // ... existing AddSC calls ...
       AddSC_hlbg_commandscript();    // Add this line
   }
   ```

### 4. Existing Battleground Integration

**Integrate with your current HLBG system:**

1. **Add integration calls to your existing battleground code:**
   ```cpp
   // In your existing Hinterland BG files, add these includes:
   #include "path/to/HLBG_Integration_Helper.cpp"
   
   // In your battleground start function:
   HinterlandBattlegroundIntegration::OnBattlegroundStart(instanceId, affixId);
   
   // In your battleground end function:
   HinterlandBattlegroundIntegration::OnBattlegroundEnd(instanceId, winner, allianceRes, hordeRes, duration, affixId);
   
   // In your player join handler:
   HinterlandBattlegroundIntegration::OnPlayerEnterBG(player, instanceId);
   
   // In your PvP kill handler:
   HinterlandBattlegroundIntegration::OnPlayerKill(killer, victim, instanceId);
   
   // Add periodic status broadcast (every 5-10 seconds):
   HinterlandBattlegroundIntegration::BroadcastLiveStatus(allianceRes, hordeRes, affixId, timeLeft);
   ```

### 5. Compilation

**Build your server:**
```bash
cd build
make -j$(nproc)
```

## ??? GM Commands Reference

After installation, GMs can use these commands:

### Configuration Management
```
.hlbg config                          # Show current configuration
.hlbg config duration 45              # Set battle duration to 45 minutes
.hlbg config maxplayers 50            # Set max 50 players per side
.hlbg config resources 750            # Set resource cap to 750
.hlbg config affix on                 # Enable affix rotation
.hlbg config active off               # Deactivate HLBG
```

### Statistics Management
```
.hlbg stats                           # Show current statistics
.hlbg stats reset                     # Reset all statistics
.hlbg reset                          # Manually reset current battle
```

### Season Management
```
.hlbg season                         # Show current season
.hlbg season list                    # List all seasons
.hlbg season create "Season 2" "2025-11-01" "2025-12-31"
.hlbg season activate 2              # Activate season ID 2
```

### History and Players
```
.hlbg history 20                     # Show last 20 battles
.hlbg players top                    # Show top 10 players
```

## ?? Configuration Options

### Database Configuration
Edit `hlbg_config` table to adjust:
- `duration_minutes` - Battle length
- `max_players_per_side` - Player limits
- `resource_cap` - Points needed to win
- `affix_rotation_enabled` - Enable/disable affixes
- `respawn_time_seconds` - Death penalty time

### Season Management
Use `hlbg_seasons` table to:
- Create seasonal events
- Set rewards for factions
- Track seasonal statistics

## ?? Data Flow

1. **Battle Start** ? Record in `hlbg_battle_history`
2. **Live Updates** ? Broadcast via AIO to all clients
3. **Battle End** ? Update statistics in all tables
4. **Client Requests** ? Real-time data from database
5. **GM Commands** ? Instant config changes + broadcasts

## ?? Testing

1. **Start server** with new code
2. **Check logs** for "HLBG AIO handlers initialized"
3. **Test client** with `/hlbg request` command
4. **Verify GM commands** work with `.hlbg config`
5. **Run test battle** and check database updates

## ?? Performance Notes

- Statistics are updated in real-time during battles
- History is limited to prevent database bloat  
- Player stats track individual performance
- All queries are optimized with proper indexes

## ?? Troubleshooting

**Common issues:**
- **"AIO handlers not found"** ? Check initialization in World.cpp
- **"Database table missing"** ? Re-run schema SQL
- **"GM commands not working"** ? Verify ScriptLoader registration
- **"No data in client"** ? Check AIO integration and server logs

The system is now ready for full production use with real-time statistics, GM management, and comprehensive player tracking! ??
