# DC-Seasons - DarkChaos Seasonal Reward System

## Overview

Complete C++ implementation of the seasonal reward system with minimal Eluna AIO communication bridge.

## Architecture

### C++ Core (src/server/scripts/DC/Seasons/)
- **SeasonalRewardSystem.h/cpp** - Core reward logic, cap management, database operations
- **SeasonalRewardScripts.cpp** - PlayerScript and WorldScript hooks
- **SeasonalRewardCommands.cpp** - GM admin commands (.season)

### Eluna Bridge
- **Custom/Eluna scripts/DC_Seasons_AIO.lua** - Minimal AIO message routing only

### Client Addon
- **Custom/Client addons needed/DC-Seasons/** - UI for reward notifications and progress tracking

## Features

### Phase 1 - Core Rewards ✅
- Quest rewards (configurable per quest)
- Creature kill rewards (dungeon bosses, world bosses)
- Multiplier system (quest, creature, world boss, event)
- Transaction logging to database
- Group loot distribution

### Phase 2 - Weekly System ✅
- Weekly caps (configurable, 0 = unlimited)
- Tuesday 3 PM reset (configurable day/hour)
- Automatic reset on login if new week
- Weekly chest generation (3-slot M+ vault style)
- 10% bonus rewards based on previous week

### Phase 3 - Tracking & Achievements ✅
- Player seasonal stats (tokens, essence, quests, creatures, bosses)
- Achievement auto-tracking (17 milestones)
- Prestige level tracking
- Transaction history

## Database Schema

```sql
-- Player seasonal stats
CREATE TABLE dc_player_seasonal_stats (
    player_guid INT UNSIGNED PRIMARY KEY,
    season_id INT UNSIGNED NOT NULL,
    seasonal_tokens_earned INT UNSIGNED DEFAULT 0,
    seasonal_essence_earned INT UNSIGNED DEFAULT 0,
    weekly_tokens_earned INT UNSIGNED DEFAULT 0,
    weekly_essence_earned INT UNSIGNED DEFAULT 0,
    quests_completed INT UNSIGNED DEFAULT 0,
    creatures_killed INT UNSIGNED DEFAULT 0,
    dungeon_bosses_killed INT UNSIGNED DEFAULT 0,
    world_bosses_killed INT UNSIGNED DEFAULT 0,
    prestige_level INT UNSIGNED DEFAULT 0,
    last_weekly_reset INT UNSIGNED DEFAULT 0,
    last_updated INT UNSIGNED DEFAULT 0,
    INDEX idx_season (season_id)
);

-- Reward definitions (worlddb)
CREATE TABLE dc_seasonal_quest_rewards (
    quest_id INT UNSIGNED PRIMARY KEY,
    season_id INT UNSIGNED NOT NULL,
    token_reward INT UNSIGNED DEFAULT 0,
    essence_reward INT UNSIGNED DEFAULT 0
);

CREATE TABLE dc_seasonal_creature_rewards (
    creature_entry INT UNSIGNED PRIMARY KEY,
    season_id INT UNSIGNED NOT NULL,
    token_reward INT UNSIGNED DEFAULT 0,
    essence_reward INT UNSIGNED DEFAULT 0,
    is_dungeon_boss TINYINT(1) DEFAULT 0,
    is_world_boss TINYINT(1) DEFAULT 0
);

-- Transaction log
CREATE TABLE dc_reward_transactions (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    player_guid INT UNSIGNED NOT NULL,
    season_id INT UNSIGNED NOT NULL,
    source VARCHAR(50) NOT NULL,
    source_id INT UNSIGNED DEFAULT 0,
    tokens_awarded INT UNSIGNED DEFAULT 0,
    essence_awarded INT UNSIGNED DEFAULT 0,
    timestamp INT UNSIGNED NOT NULL,
    INDEX idx_player (player_guid),
    INDEX idx_timestamp (timestamp)
);

-- Weekly snapshots
CREATE TABLE dc_player_weekly_cap_snapshot (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    player_guid INT UNSIGNED NOT NULL,
    season_id INT UNSIGNED NOT NULL,
    week_timestamp INT UNSIGNED NOT NULL,
    tokens_earned INT UNSIGNED DEFAULT 0,
    essence_earned INT UNSIGNED DEFAULT 0,
    dungeons_completed INT UNSIGNED DEFAULT 0,
    INDEX idx_player_week (player_guid, week_timestamp)
);

-- Weekly chests
CREATE TABLE dc_player_seasonal_chests (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    player_guid INT UNSIGNED NOT NULL,
    season_id INT UNSIGNED NOT NULL,
    week_timestamp INT UNSIGNED NOT NULL,
    slot1_tokens INT UNSIGNED DEFAULT 0,
    slot1_essence INT UNSIGNED DEFAULT 0,
    slot2_tokens INT UNSIGNED DEFAULT 0,
    slot2_essence INT UNSIGNED DEFAULT 0,
    slot3_tokens INT UNSIGNED DEFAULT 0,
    slot3_essence INT UNSIGNED DEFAULT 0,
    slots_unlocked TINYINT UNSIGNED DEFAULT 0,
    collected TINYINT(1) DEFAULT 0,
    INDEX idx_player_uncollected (player_guid, collected)
);

-- Stats history
CREATE TABLE dc_player_seasonal_stats_history (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    player_guid INT UNSIGNED NOT NULL,
    season_id INT UNSIGNED NOT NULL,
    seasonal_tokens_earned INT UNSIGNED DEFAULT 0,
    seasonal_essence_earned INT UNSIGNED DEFAULT 0,
    quests_completed INT UNSIGNED DEFAULT 0,
    creatures_killed INT UNSIGNED DEFAULT 0,
    dungeon_bosses_killed INT UNSIGNED DEFAULT 0,
    world_bosses_killed INT UNSIGNED DEFAULT 0,
    prestige_level INT UNSIGNED DEFAULT 0,
    archived_at INT UNSIGNED NOT NULL,
    INDEX idx_player_season (player_guid, season_id)
);
```

## Configuration (darkchaos-custom.conf)

```ini
###################################################################################################
# SECTION 10: SEASONAL REWARD SYSTEM
###################################################################################################

# Enable/disable the seasonal reward system
SeasonalRewards.Enable = 1

# Active season ID
SeasonalRewards.ActiveSeasonID = 1

# Item IDs for rewards
SeasonalRewards.TokenItemID = 49426
SeasonalRewards.EssenceItemID = 47241

# Weekly caps (0 = unlimited)
SeasonalRewards.MaxTokensPerWeek = 0
SeasonalRewards.MaxEssencePerWeek = 0

# Multipliers
SeasonalRewards.QuestMultiplier = 1.0
SeasonalRewards.CreatureMultiplier = 1.0
SeasonalRewards.WorldBossBonus = 1.5
SeasonalRewards.EventBossBonus = 1.25

# System features
SeasonalRewards.LogTransactions = 1
SeasonalRewards.AchievementTracking = 1

# Weekly reset timing (Day: 0=Sunday, 1=Monday, etc.)
SeasonalRewards.WeeklyResetDay = 2
SeasonalRewards.WeeklyResetHour = 15
```

## Admin Commands

```
.season reload               - Reload configuration from file
.season info                 - Display system configuration
.season stats [player]       - Show player seasonal stats
.season award <player> <tokens> <essence> - Manually award rewards
.season reset <player>       - Archive and reset player season
.season setseason <id>       - Change active season (temporary)
.season multiplier <type> <value> - Adjust multipliers (quest/creature/worldboss/event)
.season chest                - View weekly chest (player command)
```

## Client Installation

1. Copy `Custom/Client addons needed/DC-Seasons/` to `World of Warcraft/Interface/AddOns/`
2. Restart WoW client
3. Type `/seasonal` in-game to open progress tracker

## Server Installation

1. Copy `Custom/Eluna scripts/DC_Seasons_AIO.lua` to `lua_scripts/`
2. Rebuild worldserver (C++ changes included in DC scripts)
3. Import SQL schemas (Phase 1 SQL already created: `01_POPULATE_SEASON_1_REWARDS.sql`)
4. Configure `darkchaos-custom.conf` SECTION 10
5. Restart worldserver

## Development Roadmap

### Phase 3 - PvP Integration (Future)
- HLBG rewards on match completion
- Arena rating-based rewards
- Leaderboard system
- Competitive titles

### Phase 4 - Cross-System Integration (Future)
- M+ Great Vault full integration
- Prestige bonus multipliers
- Collection achievements
- Event automation

### Phase 5 - Season Transitions (Future)
- Season end logic (archival)
- Legacy achievements ("Feat of Strength" conversion)
- Season start automation
- Historical leaderboards

## Technical Notes

- All core logic in C++ for performance
- Eluna only handles AIO message routing
- Client addon is optional (system works without it)
- Database operations use prepared statements
- Transaction logging for audit trail
- Weekly reset detection on both login and periodic check
- Group loot distribution (100 yard range)
- Achievement IDs: 11000-11092 (token/essence milestones, collectors, legends, meta)
- Title IDs: 240-248 (fixed conflict with existing DC titles)

## Credits

Author: DarkChaos Development Team  
Date: November 22, 2025  
Version: 1.0.0  
License: GNU AGPL v3
