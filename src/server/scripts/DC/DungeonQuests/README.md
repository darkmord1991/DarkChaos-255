# Dungeon Quest System

**Location**: `src/server/scripts/DC/DungeonQuests/`  
**Status**: Integrated into DC Scripts  
**Version**: 2.1 (2025-11-03)

## Overview

The **Dungeon Quest System** is a complete quest framework for DarkChaos-WoW providing:

- **Daily Quests** (700101-700104): Auto-reset every 24 hours
- **Weekly Quests** (700201-700204): Auto-reset every 7 days  
- **Dungeon Quests** (700701-700999): Regular dungeon challenges
- **Token Rewards**: Automatic currency distribution
- **Achievements**: 52 custom achievements (IDs 13500-13551)
- **Titles**: 52 custom titles (IDs 188-239)
- **Progress Tracking**: Full player statistics and history

## File Structure

```
DC/DungeonQuests/
├── DungeonQuestSystem.cpp           ← Core quest completion hooks & rewards (NEW)
├── npc_dungeon_quest_master.cpp     ← Quest NPC implementation v1
├── npc_dungeon_quest_master_v2.cpp  ← Quest NPC implementation v2
├── npc_dungeon_quest_daily_weekly.cpp ← Daily/weekly quest NPCs
└── TokenConfigManager.h             ← Token configuration helper
```

## Features

### Quest System

- **Daily Quests**: Quest IDs 700101-700104
  - Flags: `0x0800` (QUEST_FLAGS_DAILY)
  - Auto-reset: Every 24 hours at 06:00 server time
  - AzerothCore handles resets automatically

- **Weekly Quests**: Quest IDs 700201-700204
  - Flags: `0x1000` (QUEST_FLAGS_WEEKLY)
  - Auto-reset: Every Tuesday at 06:00 server time
  - AzerothCore handles resets automatically

- **Dungeon Quests**: Quest IDs 700701-700999
  - Standard one-time quests (unless repeatable flag set)
  - Track progress per dungeon

### Token Reward System

Tokens are awarded automatically on quest completion:
- Daily quests: Configured in `dc_daily_quest_token_rewards` table
- Weekly quests: Configured in `dc_weekly_quest_token_rewards` table
- Token item ID: Stored in `dc_quest_reward_tokens` table

### Achievement Integration

**Achievement Milestones**:

| Achievement ID | Requirement | Description |
|----------------|-------------|-------------|
| 13500 | 1 dungeon quest | First Steps |
| 13501 | 10 daily quests | Daily Dedication |
| 13502 | 25 daily quests | Daily Devotion |
| 13503 | 50 daily quests | Daily Champion |
| 13504 | 100 daily quests | Daily Legend |
| 13505 | 5 weekly quests | Weekly Warrior |
| 13506 | 10 weekly quests | Weekly Champion |
| 13507 | 25 weekly quests | Weekly Legend |
| 13508 | 50 weekly quests | Weekly Master |
| 13509 | 10 dungeon quests | Dungeon Explorer |
| 13510 | 25 dungeon quests | Dungeon Adventurer |
| 13511 | 50 dungeon quests | Dungeon Champion |
| 13512 | 100 dungeon quests | Dungeon Master |
| 13513 | 250 dungeon quests | Dungeon Legend |
| 13514 | 500 dungeon quests | Dungeon Hero |

### Database Tracking

**Character Database Tables**:
- `dc_character_dungeon_progress` - Per-dungeon completion tracking
- `dc_character_dungeon_quests_completed` - Complete quest history
- `dc_character_dungeon_npc_respawn` - NPC state management
- `dc_character_dungeon_statistics` - Player statistics

**World Database Tables**:
- `dc_quest_reward_tokens` - Token item configuration
- `dc_daily_quest_token_rewards` - Daily quest token amounts
- `dc_weekly_quest_token_rewards` - Weekly quest token amounts

## How It Works

### Quest Completion Flow

```
Player completes quest (700101-700999)
    ↓
OnPlayerBeforeQuestComplete() - Validation
    ↓
OnPlayerCompleteQuest() - Main handler
    ↓
├─→ Log to dc_character_dungeon_quests_completed
├─→ Award tokens from dc_*_quest_token_rewards
├─→ Update statistics in dc_character_dungeon_statistics
├─→ Update progress in dc_character_dungeon_progress
└─→ Check & award achievements (13500-13551)
```

### Token Distribution

1. Quest completes → System checks quest ID range
2. Query `dc_daily_quest_token_rewards` or `dc_weekly_quest_token_rewards`
3. Get token item ID from `dc_quest_reward_tokens`
4. Add tokens to player inventory
5. Send confirmation message to player

### Achievement Logic

- **First dungeon quest** → Award Achievement 13500
- **Daily quest milestones** → Award 13501-13504 based on count
- **Weekly quest milestones** → Award 13505-13508 based on count
- **Dungeon quest milestones** → Award 13509-13514 based on count

All achievement checks query `dc_character_dungeon_statistics` table.

## NPCs

The system includes 7 quest NPCs (IDs 700000-700006):

| NPC ID | Name | Location | Quest Types |
|--------|------|----------|-------------|
| 700000 | Quest Master | Orgrimmar | Daily, Weekly, Dungeon |
| 700001 | Quest Master | Stormwind | Daily, Weekly, Dungeon |
| 700002 | Quest Master | Shattrath | TBC Quests |
| 700003 | Quest Master | Dalaran | WotLK Quests |
| 700004-700006 | Additional Masters | Various | Specialized quests |

NPCs are linked via:
- `creature_queststarter` - Quest givers
- `creature_questender` - Quest turn-in
- `creature_template_model` - Display models

## Database Setup

### Required SQL Files (Execute in Order)

**Character Database**:
```sql
SOURCE Custom/Custom feature SQLs/characterdb/DC_CHARACTER_DUNGEON_QUEST_SCHEMA.sql;
```

**World Database**:
```sql
SOURCE Custom/Custom feature SQLs/worlddb/DC_DUNGEON_QUEST_SCHEMA_v2.sql;
SOURCE Custom/Custom feature SQLs/worlddb/DC_DUNGEON_QUEST_CREATURES_v2.sql;
SOURCE Custom/Custom feature SQLs/worlddb/DC_DUNGEON_QUEST_TEMPLATES_v2_CORRECTED.sql;
SOURCE Custom/Custom feature SQLs/worlddb/DC_DUNGEON_QUEST_TOKEN_REWARDS_v2.sql;
```

### DBC Files

Copy to client (requires client restart + cache delete):
```
Custom/DBCs/Achievement.dbc → WoW Client/Data/enUS/DBFilesClient/
Custom/DBCs/CharTitles.dbc → WoW Client/Data/enUS/DBFilesClient/
```

## Compilation

The scripts are automatically included in the build:

```bash
./acore.sh compiler build
```

Build configuration is in:
- `src/server/scripts/DC/CMakeLists.txt` (includes SCRIPTS_DC_DungeonQuests)
- `src/server/scripts/DC/dc_script_loader.cpp` (calls AddSC_DungeonQuestSystem())

## Debugging

### Enable Debug Logging

Edit `worldserver.conf`:
```conf
Logger.scripts=6,Console Server
```

Then check logs for:
```
DungeonQuest: Player XXX completed dungeon quest YYY
DungeonQuest: Awarded Z tokens to player XXX
DungeonQuest: Awarded achievement AAAA to player XXX
```

### Common Issues

**Tokens not awarded:**
- Check `dc_quest_reward_tokens` table has token item ID
- Verify token item exists in `item_template`
- Check `dc_daily_quest_token_rewards` or `dc_weekly_quest_token_rewards` has quest entry

**Achievements not working:**
- Verify Achievement.dbc copied to client
- Delete client cache folder
- Check achievement IDs 13500-13551 exist in DBC

**Quests not showing:**
- Verify NPCs spawned: `.npc info` in-game
- Check `creature_queststarter` table
- Verify quest IDs in `quest_template`

**Database errors on startup:**
- Execute all SQL files in correct order
- Check table names have `dc_` prefix
- Verify foreign keys to `characters` table (not `character`)

## API Reference

### Main Hook: OnPlayerCompleteQuest

```cpp
void OnPlayerCompleteQuest(Player* player, Quest const* quest)
```

**Parameters:**
- `player` - Player who completed the quest
- `quest` - Quest object with ID and details

**Called when:** Player turns in a quest (after validation)

**Processing:**
1. Validates quest ID is in dungeon quest range
2. Logs completion to database
3. Awards tokens based on quest type
4. Updates player statistics
5. Checks and awards achievements

### Helper Functions

```cpp
// Get token reward amount for daily quest
uint32 DungeonQuestDB::GetDailyQuestTokenReward(uint32 questId)

// Get token reward amount for weekly quest
uint32 DungeonQuestDB::GetWeeklyQuestTokenReward(uint32 questId)

// Get configured token item ID
uint32 DungeonQuestDB::GetTokenItemId()

// Update dungeon progress
void DungeonQuestDB::UpdateDungeonProgress(Player* player, uint32 dungeonId, uint32 questId)

// Log quest completion
void DungeonQuestDB::LogQuestCompletion(Player* player, uint32 questId)

// Update statistics
void DungeonQuestDB::UpdateStatistics(Player* player, const std::string& stat_name, uint32 value)
```

## Version History

- **v2.1** (2025-11-03): 
  - Integrated into DC scripts (removed module structure)
  - Fixed quest_template schema for AzerothCore
  - Added comprehensive achievement system
  - Moved Custom/DC scripts to DC/DungeonQuests

- **v2.0** (2025-11-03): 
  - Complete C++ implementation
  - Token reward system
  - Achievement integration

- **v1.0** (2025-11-02): 
  - Initial database schema
  - DBC files created

## Credits

- DarkChaos-WoW Development Team
- AzerothCore Project

## License

GNU General Public License v2
