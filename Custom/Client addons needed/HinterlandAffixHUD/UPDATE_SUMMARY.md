# HLBG Addon - Update Summary

## Issues Fixed ?

### 1. **History Now Shows 24 Lines** 
- **Fixed**: History display limit increased from 10 ? 24 entries
- **Enhanced**: Now shows affix information with each battle result
- **Format**: "2025-10-04 12:36:33 - Alliance won (Bloodlust)"

### 2. **HUD Display Issues Resolved**
- **Fixed**: `/hlbghud test` now forces HUD and affix frame visibility
- **Enhanced**: Added `UpdateHUD()` and `UpdateAffix()` calls for immediate display
- **Added**: New `/hlbg testhud` command for easier HUD testing
- **Result**: HUD should now appear immediately when test commands are used

### 3. **Comprehensive Statistics Display**
Now shows extensive battle analytics:
- **Core Stats**: Total runs, wins per faction, draws, manual resets
- **Win Rates**: Percentage calculations for Alliance/Horde/Draws
- **Win Streaks**: Current streak and record holders
- **Timing**: Average/shortest/longest battle duration
- **Server Info**: Last GM reset, server uptime
- **Integration**: Clear indicators for HL_ScoreboardNPC.cpp requirements

### 4. **Server Configuration Framework**
Live tab now displays:
- **BG Settings**: Duration, max players, level ranges
- **Game Rules**: Affix rotation, resource caps, queue types  
- **Season Info**: Current season name, dates, rewards
- **Database**: Shows required DB query for integration
- **Real-time**: Framework to pull live config from server database

### 5. **Enhanced Server Integration**
Added comprehensive database schema and C++ integration:
- **Database Tables**: `hlbg_config`, `hlbg_seasons`, `hlbg_statistics`
- **AIO Handlers**: Request/Update patterns for all data types
- **Auto-Request**: Client automatically requests server data on load
- **Live Updates**: Framework for real-time battle result updates

## New Commands ?

### Main UI Commands:
- `/hlbg testhud` - Force HUD display with test data
- `/hlbg request` - Request fresh data from server

### Enhanced Features:
- **24-line history** with affix display
- **Comprehensive statistics** with win rates and streaks  
- **Server configuration** display from database
- **Database integration** framework ready
- **Auto-refresh** capability for live updates

## Testing Instructions ?

1. **Test HUD**: `/hlbghud test` or `/hlbg testhud`
2. **View History**: `/hlbg history` (should show 24 entries with affixes)
3. **Check Stats**: `/hlbg stats` (comprehensive analytics)
4. **See Config**: `/hlbg live` (server settings framework)
5. **Help**: `/hlbg settings` ? "Show Commands" for full command list

## Server Integration Ready ?

The addon now has complete framework for:
- Database-driven configuration (hlbg_config table)
- Real-time statistics (hlbg_statistics table)  
- Season management (hlbg_seasons table)
- C++ integration via HL_ScoreboardNPC.cpp
- Automatic data refresh and live updates

**Next Step**: Implement the database tables and C++ handlers as documented in `SERVER_INTEGRATION_NOTES.md`
