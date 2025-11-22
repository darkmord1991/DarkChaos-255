# Season System - Comprehensive Design Document

**Project:** DarkChaos-255 WoW 3.3.5a Private Server  
**Date:** November 22, 2025  
**Status:** Research & Design Complete  
**Version:** 2.0

---

## Executive Summary

### Current State Assessment

**What Exists:**
- ✅ **Core Seasonal Framework** (`SeasonalSystem.h/.cpp`) - Independent, generic seasonal system
- ✅ **Database Foundation** - `dc_seasons` table and player season tracking
- ✅ **System Registration Pattern** - Event-driven callbacks for season transitions
- ✅ **HLBG Integration** - Full seasonal participant implementation with rating resets
- ✅ **Item Upgrade Seasonal** - Season-based progression tracking and leaderboards
- ✅ **Mythic+ Season Infrastructure** - `dc_mplus_seasons` table with affix rotation and rewards
- ✅ **Quest/Creature Reward Tables** - `dc_seasonal_quest_rewards`, `dc_seasonal_creature_rewards` (designed, not implemented)
- ✅ **AIO Client Addon Bridge** - Rochet2 addon for server-client communication

**What's Missing:**
- ❌ **Unified Season Manager** - Current systems (ItemUpgrade, HLBG, M+) use separate implementations
- ❌ **Quest/Boss Reward Automation** - No automatic token distribution on quest/kill
- ❌ **Season Progression UI** - No in-game display of season info, progress, leaderboards
- ❌ **Cross-System Integration** - Systems don't benefit from each other (HLBG rating → item upgrade bonuses)
- ❌ **Retail-Style Season Features** - No end-of-season rewards, cosmetics, titles, achievements
- ❌ **Prestige Integration** - Prestige system exists but not tied to seasons
- ❌ **PvP Season Support** - HLBG is seasonal but needs rating-based rewards

**What We Should Build:**
1. **Consolidate existing seasonal implementations** into the core `SeasonalSystem`
2. **Implement quest/boss reward automation** (Phase 1 - Immediate)
3. **Build unified AIO client addon** for season UI across all systems
4. **Extend Mythic+ with seasonal rewards** (Phase 2)
5. **Add PvP seasonal progression** for HLBG (Phase 3)
6. **Create cross-system synergies** and prestige integration (Phase 4)

---

## Existing Infrastructure Analysis

### 1. Core Seasonal Framework

**Location:** `src/server/scripts/DC/Seasons/SeasonalSystem.h/.cpp`

**Architecture:**
```cpp
class SeasonalManager {
    // Season Management
    CreateSeason(), UpdateSeason(), DeleteSeason()
    GetActiveSeason(), TransitionSeason()
    
    // System Registration (Event-Driven)
    RegisterSystem(SystemRegistration)
    FireSeasonEvent(SEASON_EVENT_START/END/RESET)
    
    // Player Management
    GetPlayerSeasonData(), TransitionPlayerSeason()
};

struct SystemRegistration {
    on_season_event         // Callbacks for START/END/RESET
    on_player_season_change // Player transitions
    validate_season_transition
    archive_player_data     // Season end archival
    initialize_player_data  // Season start setup
};
```

**Strengths:**
- Generic, reusable design (supports ItemUpgrade, HLBG, M+)
- Event-driven transitions (automatic, timestamp-based)
- Priority-based system execution
- Database-driven season definitions

**Weaknesses:**
- Underutilized - only HLBG uses full registration pattern
- ItemUpgrade has separate `SeasonResetManagerImpl`
- No unified season commands/UI
- Limited cross-system awareness

### 2. Database Schema

**Character Database:**
```sql
-- Core season tracking
dc_seasons (season_id, season_name, start/end timestamps, carryover config)
dc_player_season_data (player_guid, current_season_id, total_seasons_played)

-- Item Upgrade specific
dc_player_upgrade_tokens (essence, tokens per player)
dc_season_history (archived season data)
dc_upgrade_history (per-upgrade tracking)

-- HLBG specific
dc_hlbg_player_season_data (rating, wins, losses, scores)
dc_hlbg_match_history (archived matches)
```

**World Database:**
```sql
-- Mythic+ seasons
dc_mplus_seasons (season_id, featured_dungeons, affix_schedule, reward_curve)
dc_mplus_affix_schedule (season_id, week_number, affix_pair_id)
dc_mplus_featured_dungeons (season_id, map_id, ilvl rewards)

-- Item Upgrade progression
dc_item_upgrade_costs (tier, level, essence/token cost, season)
dc_item_upgrade_tiers (tier_id, required_ilvl, upgrade_slots, season)

-- Quest/Creature rewards (designed, not in schema.sql yet)
dc_seasonal_quest_rewards (NEW - quest completion tokens)
dc_seasonal_creature_rewards (NEW - boss kill tokens)
dc_seasonal_chest_rewards (NEW - randomized loot)
dc_seasonal_reward_config (NEW - global settings)
```

**Findings:**
- ✅ Good separation of character vs world data
- ✅ Mythic+ seasons already have comprehensive schema
- ⚠️ Item Upgrade seasons use different structure than core `dc_seasons`
- ⚠️ Quest/creature reward tables exist in design docs but not deployed
- ❌ No unified season leaderboard tables

### 3. System-Specific Implementations

#### A. HLBG Seasonal Participant

**File:** `src/server/scripts/DC/Seasons/HLBGSeasonalParticipant.cpp`

**Implementation:**
```cpp
class HLBGSeasonalParticipant : public SeasonalParticipant {
    OnSeasonStart()  -> Reset ratings to 1500, clear stats
    OnSeasonEnd()    -> Calculate rewards (top 100 players)
    OnSeasonReset()  -> Archive match data
    
    ValidateSeasonTransition() -> Require 5 games + 1000 rating
    ArchivePlayerData()        -> Copy to dc_hlbg_player_history
    InitializePlayerData()     -> Create new season entry
};

RegisterHLBGWithSeasonalSystem() {
    SystemRegistration reg;
    reg.system_name = "hlbg";
    reg.priority = 90;
    reg.on_season_event = [callbacks]
    GetSeasonalManager()->RegisterSystem(reg);
}
```

**Key Features:**
- ✅ Full seasonal lifecycle implementation
- ✅ Rating-based rewards (rank 1-100)
- ✅ Season leaderboards via SQL queries
- ✅ Proper archival and cleanup
- ⚠️ Rewards are placeholder item IDs (not distributed yet)
- ❌ No UI/addon for displaying season info

#### B. Item Upgrade Seasonal

**File:** `src/server/scripts/DC/ItemUpgrades/ItemUpgradeSeasonalImpl.cpp`

**Implementation:**
```cpp
class SeasonResetManagerImpl : public SeasonResetManager {
    ResetPlayerForSeason()
        -> Archive to dc_season_history
        -> Reset upgrades if config.reset_item_upgrades
        -> Calculate carryover (essence/token percentages)
        -> Reset weekly spending caps
    
    ExecuteGlobalSeasonReset()
        -> Reset all players
        -> Apply new season balance adjustments
};

// Separate from SeasonalSystem!
// Uses custom reset config instead of dc_seasons
```

**Key Features:**
- ✅ Carryover percentages for currencies
- ✅ Weekly spending caps (reset on season change)
- ✅ Upgrade history tracking
- ✅ Balance adjustment multipliers
- ⚠️ Not using core `SeasonalManager` registration
- ⚠️ No season events (START/END/RESET)
- ❌ Manual reset required

#### C. Mythic+ Season Infrastructure

**Files:** `src/server/scripts/DC/MythicPlus/MythicPlusRunManager.cpp`

**Current Implementation:**
```cpp
// Reads dc_mplus_seasons table for:
// - Featured dungeons (specific map IDs per season)
// - Affix rotation schedule (weekly affixes)
// - Reward curve (ilvl + tokens per keystone level)

// Season 1 example:
{
  "season_id": 1,
  "featured_dungeons": [533, 542, 568], // Naxx, Blood, Zul'Aman
  "affix_schedule": [
    {"week": 1, "affixPairId": 1},
    {"week": 2, "affixPairId": 2}
  ],
  "reward_curve": {
    "2": {"ilvl": 216, "tokens": 30},
    "5": {"ilvl": 226, "tokens": 50},
    "10": {"ilvl": 239, "tokens": 100}
  }
}
```

**Key Features:**
- ✅ JSON-based configuration (flexible)
- ✅ Weekly affix rotation automation
- ✅ Keystone-level scaling for rewards
- ✅ Great Vault integration (weekly chest system)
- ⚠️ Not registered with core `SeasonalManager`
- ⚠️ Season transitions are manual (no automation)
- ❌ No end-of-season rewards or titles

#### D. Prestige System

**Files:** `src/server/scripts/DC/Prestige/dc_prestige_system.cpp`

**Current Implementation:**
- Prestige ranks (levels 1-10+)
- Alt character bonuses (XP, damage, health)
- Challenge tracking and rewards
- Prestige-specific spell auras

**Integration Opportunities:**
- ✅ Could tie prestige ranks to season progression
- ✅ Seasonal prestige challenges (complete 100 M+ dungeons)
- ✅ Season-exclusive prestige rewards
- ❌ Currently not connected to seasonal system

### 4. Client Addon Infrastructure

**AIO (Azeroth Instant Objects) System:**
- **Location:** `Custom/Client addons needed/AIO_Client/`
- **Technology:** Rochet2's addon bridge (Lua server → client)
- **Capabilities:**
  - Send Lua code from server to client (auto-update addons)
  - Bidirectional messaging (client can request data, server responds)
  - Persistent saved variables (account/character bound)
  - Frame position saving

**Existing DC Addons Using AIO:**
- `DC-MythicPlus` - Keystone UI, dungeon portal selector, Great Vault display
- `DC-ItemUpgrade` - Upgrade NPC UI (basic)
- `DC-HinterlandBG` - Battleground scoring UI
- `DC-MapExtension` - Custom map pins

**Missing:**
- ❌ **Unified Season UI** - No single addon showing season progress, leaderboards, rewards
- ❌ **Season Info Display** - Players don't see season time remaining, multipliers, etc.
- ❌ **Cross-System Dashboard** - No overview of M+, HLBG, ItemUpgrade progress in one place

---

## Retail WoW Season Features Analysis

### Shadowlands Seasons (S1-S4) & Dragonflight Seasons (S1-S4)

**Core Season Elements:**

1. **Duration & Cadence**
   - 6-9 months per season
   - Pre-season preparation period (2 weeks before launch)
   - Post-season "grace period" for claiming rewards

2. **Mythic+ Seasonal Mechanics**
   - **Affix Rotation:** Weekly affix changes (Fortified/Tyrannical alternates)
   - **Seasonal Affix:** Unique mechanic each season (Tormented, Encrypted, Shrouded, Thundering)
   - **Dungeon Pool:** 8 dungeons per season (mix of new + old)
   - **Item Level Scaling:** +13 ilvls per season (Season 1: 236-259, Season 2: 249-272)
   - **Great Vault:** 3 weekly slots unlocked at 4/8/10 dungeons
   - **Keystone Master Achievement:** Complete all dungeons at +15 within timer
   - **Portals:** Permanent teleports unlocked at +20

3. **PvP Seasonal Mechanics**
   - **Rating Resets:** All ratings reset to 0 at season start
   - **Conquest Cap:** Weekly cap increases (750 → 1,000 per week)
   - **Elite Sets:** Transmog unlocked at 1,800+ rating
   - **Gladiator Titles:** Top 0.5% of ladder (Gladiator, Duelist, Rival, Challenger)
   - **Seasonal Mounts:** Unique mount for Gladiator each season
   - **End-of-Season Rewards:** Distributed via in-game mail

4. **Rewards & Progression**
   - **Valor Points:** Season-specific currency for M+ gear upgrades
   - **Conquest Points:** Season-specific PvP currency
   - **Catalyst Charges:** Convert raid gear to tier sets (weekly cap)
   - **Transmog Sets:** Season-exclusive cosmetics
   - **Achievements:** Seasonal meta-achievements with rewards
   - **Titles:** "Keystone Hero," "Keystone Master," seasonal PvP titles

5. **Patch Cycles**
   - Major patches introduce new seasons
   - Mid-season balance tuning (class changes, affix tweaks)
   - Hotfixes for exploits and bugs

**Key Takeaways for DarkChaos-255:**
- ✅ **Token-Based Rewards:** Use upgrade tokens (like Valor) - already implemented
- ✅ **Weekly Caps:** Prevent farming, encourage weekly play - needs enforcement
- ✅ **Seasonal Affixes:** M+ already has this infrastructure
- ✅ **Leaderboards:** HLBG has rating system, M+ needs leaderboards
- ❌ **End-of-Season Distribution:** No automated reward distribution yet
- ❌ **Cosmetic Rewards:** No seasonal transmog/titles implemented
- ❌ **Achievement System:** Need seasonal achievements

---

## Proposed Architecture

### Core Season Manager (C++ Singleton)

**Consolidation Strategy:**
- Extend existing `SeasonalManager` to be the single source of truth
- Migrate ItemUpgrade's `SeasonResetManagerImpl` into `SeasonalManager`
- Register M+ and Prestige systems with `SeasonalManager`

**Enhanced SeasonalManager:**
```cpp
class SeasonalManager {
public:
    // Existing methods (unchanged)
    CreateSeason(), GetActiveSeason(), RegisterSystem()
    
    // NEW: Unified season control
    ActivateSeason(season_id)
        -> Fire SEASON_EVENT_START to all systems
        -> Load quest/creature rewards from DB
        -> Apply season multipliers
        -> Notify all online players
    
    DeactivateSeason(season_id)
        -> Fire SEASON_EVENT_END to all systems
        -> Calculate and distribute end-of-season rewards
        -> Archive player stats
        -> Reset leaderboards
    
    TransitionSeason(from, to)
        -> Validate all systems ready for transition
        -> Execute carryover logic per system
        -> Atomic database updates
    
    // NEW: Cross-system queries
    GetPlayerSeasonStats(player_guid, season_id)
        -> Aggregate stats from all systems (M+, HLBG, ItemUpgrade)
        -> Return unified SeasonPlayerStats struct
    
    GetSeasonLeaderboards(season_id, system_name)
        -> Query system-specific leaderboards
        -> Return top 100 players
    
    // NEW: Reward distribution
    DistributeSeasonRewards(season_id)
        -> Query all systems for top performers
        -> Award titles, mounts, cosmetics
        -> Send in-game mail notifications
    
    // NEW: Configuration
    GetSeasonMultipliers(season_id)
        -> Quest multiplier, creature multiplier, etc.
        -> Used by quest/boss reward system
    
    GetSeasonConfig(season_id, key)
        -> Generic key-value config (weekly cap, carryover %, etc.)
};
```

### Database Schema Enhancements

**Unified Season Schema:**

```sql
-- =====================================================================
-- CORE SEASON TABLES (CHAR DB)
-- =====================================================================

-- Extend existing dc_seasons with more fields
ALTER TABLE dc_seasons ADD COLUMN (
    theme VARCHAR(50),              -- "Wrath of Winter", "Rise of Titans"
    icon_id INT UNSIGNED,           -- Season icon for UI
    primary_color VARCHAR(7),       -- Hex color for UI (#FF5733)
    featured_systems JSON,          -- ["mythic_plus", "hlbg", "prestige"]
    reward_pool JSON                -- End-of-season reward item IDs
);

-- Unified player season stats (aggregate all systems)
CREATE TABLE dc_player_season_aggregate (
    player_guid INT UNSIGNED NOT NULL,
    season_id INT UNSIGNED NOT NULL,
    
    -- Mythic+ stats
    mplus_runs_completed INT DEFAULT 0,
    mplus_highest_keystone TINYINT DEFAULT 0,
    mplus_tokens_earned INT DEFAULT 0,
    
    -- HLBG stats
    hlbg_rating INT DEFAULT 1500,
    hlbg_wins INT DEFAULT 0,
    hlbg_losses INT DEFAULT 0,
    
    -- Item Upgrade stats
    upgrade_essence_earned INT DEFAULT 0,
    upgrade_tokens_earned INT DEFAULT 0,
    upgrades_applied INT DEFAULT 0,
    
    -- Prestige stats
    prestige_challenges_completed INT DEFAULT 0,
    prestige_level INT DEFAULT 0,
    
    -- Overall
    total_season_score INT DEFAULT 0,
    season_rank INT DEFAULT 0,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    PRIMARY KEY (player_guid, season_id),
    KEY idx_season_rank (season_id, season_rank)
) ENGINE=InnoDB COMMENT='Unified season stats across all systems';

-- Season achievements
CREATE TABLE dc_season_achievements (
    achievement_id INT UNSIGNED AUTO_INCREMENT,
    season_id INT UNSIGNED NOT NULL,
    achievement_name VARCHAR(100) NOT NULL,
    achievement_description TEXT,
    criteria_type ENUM('mplus', 'hlbg', 'item_upgrade', 'prestige', 'cross_system'),
    criteria_json JSON,             -- Flexible criteria definition
    reward_title VARCHAR(100),      -- Reward title text
    reward_item_id INT UNSIGNED,    -- Reward item
    reward_spell_id INT UNSIGNED,   -- Reward spell/cosmetic
    
    PRIMARY KEY (achievement_id),
    KEY idx_season (season_id)
) ENGINE=InnoDB COMMENT='Seasonal achievements';

CREATE TABLE dc_player_season_achievements (
    player_guid INT UNSIGNED NOT NULL,
    achievement_id INT UNSIGNED NOT NULL,
    completed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (player_guid, achievement_id),
    FOREIGN KEY (achievement_id) REFERENCES dc_season_achievements(achievement_id)
) ENGINE=InnoDB;

-- =====================================================================
-- WORLD DB ADDITIONS
-- =====================================================================

-- Deploy existing quest/creature reward tables (already designed)
-- See: Custom/Custom feature SQLs/worlddb/SeasonSystem/dc_seasonal_rewards.sql

-- Add unified season config
CREATE TABLE dc_season_global_config (
    config_id INT UNSIGNED AUTO_INCREMENT,
    config_key VARCHAR(100) NOT NULL,
    config_value TEXT,
    system_name VARCHAR(50),        -- 'global', 'mplus', 'hlbg', etc.
    description TEXT,
    
    PRIMARY KEY (config_id),
    UNIQUE KEY uk_system_key (system_name, config_key)
) ENGINE=InnoDB COMMENT='Global seasonal configuration';

-- Example configs:
INSERT INTO dc_season_global_config VALUES
(NULL, 'weekly_token_cap', '500', 'item_upgrade', 'Max tokens per week'),
(NULL, 'mplus_season_duration_days', '180', 'mplus', '6 months per season'),
(NULL, 'hlbg_rating_decay_enabled', '0', 'hlbg', 'Rating decay disabled'),
(NULL, 'carryover_essence_percent', '10', 'item_upgrade', '10% carryover');
```

### Season Progression Tracking

**Unified Progression System:**

```cpp
struct SeasonPlayerStats {
    uint32 player_guid;
    uint32 season_id;
    
    // Aggregate score (weighted combination of all systems)
    uint32 total_season_score;
    uint32 global_rank;
    
    // System-specific scores
    MythicPlusSeasonStats mplus;    // keystone level, runs, vault slots
    HLBGSeasonStats hlbg;           // rating, wins, losses
    ItemUpgradeSeasonStats upgrades; // essence, tokens, upgrades
    PrestigeSeasonStats prestige;    // challenges, level
    
    // Achievements
    std::vector<uint32> completed_achievements;
    
    // Rewards earned
    std::vector<uint32> earned_titles;
    std::vector<uint32> earned_items;
};

class SeasonProgressionTracker {
public:
    // Calculate unified season score
    uint32 CalculateSeasonScore(SeasonPlayerStats stats) {
        // Weighted formula:
        // Score = (M+ Score * 0.35) + (HLBG Rating * 0.25) +
        //         (Upgrades * 0.20) + (Prestige * 0.20)
        
        uint32 mplus_score = stats.mplus.highest_keystone * 100 + 
                            stats.mplus.runs_completed;
        uint32 hlbg_score = stats.hlbg.rating - 1500; // Base 1500
        uint32 upgrade_score = stats.upgrades.upgrades_applied * 10;
        uint32 prestige_score = stats.prestige.prestige_level * 500;
        
        return (mplus_score * 35) / 100 +
               (hlbg_score * 25) / 100 +
               (upgrade_score * 20) / 100 +
               (prestige_score * 20) / 100;
    }
    
    // Update global rankings
    void UpdateSeasonRankings(uint32 season_id) {
        // Query all players, calculate scores, assign ranks
        // Update dc_player_season_aggregate.season_rank
    }
    
    // Check achievements
    void CheckSeasonAchievements(uint32 player_guid, uint32 season_id) {
        // Query dc_season_achievements for criteria
        // Check if player meets criteria
        // Award if not already earned
    }
};
```

### Reward Distribution System

**Automated End-of-Season Rewards:**

```cpp
class SeasonRewardDistributor {
public:
    void DistributeSeasonEndRewards(uint32 season_id) {
        // 1. Query top performers per system
        auto mplus_top100 = GetMythicPlusLeaderboard(season_id, 100);
        auto hlbg_top100 = GetHLBGLeaderboard(season_id, 100);
        auto upgrade_top100 = GetItemUpgradeLeaderboard(season_id, 100);
        
        // 2. Calculate reward tiers
        for (auto& entry : mplus_top100) {
            uint32 reward_title = 0;
            uint32 reward_item = 0;
            
            if (entry.rank == 1) {
                reward_title = GetTitleId("Mythic Champion");
                reward_item = GetSeasonMountId(season_id);
            }
            else if (entry.rank <= 10) {
                reward_title = GetTitleId("Keystone Master");
                reward_item = GetSeasonTransmogSetId(season_id);
            }
            else if (entry.rank <= 100) {
                reward_title = GetTitleId("Keystone Hero");
                reward_item = GetSeasonToyId(season_id);
            }
            
            // 3. Distribute via mail
            SendSeasonRewardMail(entry.player_guid, season_id, 
                                reward_title, reward_item);
        }
        
        // Repeat for HLBG, ItemUpgrade systems
    }
    
    void SendSeasonRewardMail(uint32 player_guid, uint32 season_id,
                             uint32 title_id, uint32 item_id) {
        // Create mail with season congratulations
        // Attach title scroll item (learns title on use)
        // Attach reward item
        // Set 30-day expiration
        
        MailDraft draft;
        draft.SetSubjectAndBody(
            Acore::StringFormat("Season {} Rewards", season_id),
            "Congratulations on your performance this season! ..."
        );
        
        if (title_id > 0)
            draft.AddItem(CreateTitleScrollItem(title_id));
        if (item_id > 0)
            draft.AddItem(CreateItem(item_id));
        
        draft.SendMailTo(player_guid, 30 * DAY);
    }
};
```

### Client Communication (AIO Addon)

**Unified Season Dashboard Addon:**

```lua
-- File: Custom/Client addons needed/AIO_Client/DC_SeasonDashboard.lua

if AIO.AddAddon() then return end

local SeasonFrame = CreateFrame("Frame", "DCSeasonDashboard", UIParent)
SeasonFrame:SetSize(600, 800)
SeasonFrame:SetPoint("CENTER")
SeasonFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
})
SeasonFrame:Hide()

-- Tabs: Overview | Mythic+ | HLBG | Upgrades | Leaderboard
local tabs = {}
local currentTab = "overview"

function SeasonFrame:InitializeTabs()
    local tabNames = {"Overview", "Mythic+", "PvP", "Upgrades", "Leaderboard"}
    local tabWidth = 600 / #tabNames
    
    for i, name in ipairs(tabNames) do
        local tab = CreateFrame("Button", nil, SeasonFrame)
        tab:SetSize(tabWidth, 30)
        tab:SetPoint("TOPLEFT", (i-1) * tabWidth, 0)
        tab:SetText(name)
        tab:SetScript("OnClick", function()
            SeasonFrame:SwitchTab(name:lower())
        end)
        tabs[name:lower()] = tab
    end
end

function SeasonFrame:SwitchTab(tabName)
    currentTab = tabName
    -- Request data from server
    AIO.Handle("SeasonSystem", "GetTabData", tabName)
end

function SeasonFrame:DisplayOverview(data)
    -- data = {
    --   season_id, season_name, time_remaining,
    --   your_rank, total_score, mplus_score, hlbg_rating,
    --   upgrades_applied, achievements_completed
    -- }
    
    local text = SeasonFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("TOPLEFT", 20, -50)
    text:SetText(string.format(
        "Season %d: %s\\n" ..
        "Time Remaining: %s\\n" ..
        "Your Rank: #%d (Score: %d)\\n\\n" ..
        "Mythic+: %d runs, Keystone +%d\\n" ..
        "PvP Rating: %d (%d-%d)\\n" ..
        "Item Upgrades: %d applied\\n" ..
        "Achievements: %d/%d",
        data.season_id, data.season_name, data.time_remaining,
        data.your_rank, data.total_score,
        data.mplus_runs, data.mplus_highest,
        data.hlbg_rating, data.hlbg_wins, data.hlbg_losses,
        data.upgrades_applied,
        data.achievements_completed, data.achievements_total
    ))
end

-- AIO Handlers
local handlers = AIO.AddHandlers("SeasonSystem", {})

function handlers.UpdateSeasonData(player, data)
    if currentTab == "overview" then
        SeasonFrame:DisplayOverview(data)
    elseif currentTab == "mythic+" then
        SeasonFrame:DisplayMythicPlus(data)
    -- ... other tabs
    end
end

function handlers.ShowSeasonFrame(player)
    SeasonFrame:Show()
end

-- Slash command
SLASH_SEASON1 = "/season"
SlashCmdList["SEASON"] = function()
    AIO.Handle("SeasonSystem", "RequestSeasonData")
    SeasonFrame:Show()
end
```

**Server-Side AIO Handler:**

```cpp
// File: src/server/scripts/DC/SeasonSystem/SeasonalAIOHandler.cpp

#ifdef HAS_AIO
#include "AIO.h"

class SeasonalAIOHandler {
public:
    void RegisterHandlers() {
        AIO::RegisterHandler("SeasonSystem", "RequestSeasonData", 
            [](Player* player, AIO::Message msg) {
                SendSeasonDataToPlayer(player);
            });
        
        AIO::RegisterHandler("SeasonSystem", "GetTabData",
            [](Player* player, AIO::Message msg) {
                std::string tabName = msg.GetString();
                SendTabDataToPlayer(player, tabName);
            });
    }
    
    void SendSeasonDataToPlayer(Player* player) {
        auto seasonMgr = GetSeasonalManager();
        uint32 season_id = seasonMgr->GetCurrentSeasonId();
        auto season = seasonMgr->GetActiveSeason();
        auto stats = seasonMgr->GetPlayerSeasonStats(player->GetGUID().GetCounter());
        
        AIO::Message msg;
        msg.Add("SeasonSystem", "UpdateSeasonData");
        msg.Add(season_id);
        msg.Add(season->season_name);
        msg.Add(FormatTimeRemaining(season->end_timestamp - time(nullptr)));
        msg.Add(stats->global_rank);
        msg.Add(stats->total_season_score);
        msg.Add(stats->mplus.runs_completed);
        msg.Add(stats->mplus.highest_keystone);
        msg.Add(stats->hlbg.rating);
        msg.Add(stats->hlbg.wins);
        msg.Add(stats->hlbg.losses);
        msg.Add(stats->upgrades.upgrades_applied);
        msg.Add(stats->completed_achievements.size());
        msg.Add(GetTotalSeasonAchievements(season_id));
        msg.Send(player);
    }
};
#endif
```

### Integration Points

**1. Mythic+ → SeasonalManager**

```cpp
// In MythicPlusRunManager initialization:
void MythicPlusRunManager::RegisterWithSeasonalSystem() {
    SystemRegistration reg;
    reg.system_name = "mythic_plus";
    reg.system_version = "2.0";
    reg.priority = 100;
    
    reg.on_season_event = [](uint32 season_id, SeasonEventType event) {
        if (event == SEASON_EVENT_START) {
            LoadSeasonDungeons(season_id);
            LoadAffixSchedule(season_id);
            ResetLeaderboards(season_id);
        }
        else if (event == SEASON_EVENT_END) {
            DistributeMythicPlusSeasonRewards(season_id);
            ArchiveSeasonData(season_id);
        }
    };
    
    reg.on_player_season_change = [](uint32 player_guid, uint32 old_season, uint32 new_season) {
        // Archive player's M+ runs from old season
        // Initialize new season keystone vault
    };
    
    GetSeasonalManager()->RegisterSystem(reg);
}
```

**2. ItemUpgrade → SeasonalManager**

```cpp
// Migrate SeasonResetManagerImpl into SeasonalManager callback:
void ItemUpgradeManager::RegisterWithSeasonalSystem() {
    SystemRegistration reg;
    reg.system_name = "item_upgrades";
    reg.priority = 95;
    
    reg.on_season_event = [](uint32 season_id, SeasonEventType event) {
        if (event == SEASON_EVENT_END) {
            // Calculate carryover percentages
            auto config = GetSeasonConfig(season_id);
            ResetAllPlayerUpgrades(config.reset_item_upgrades);
            ApplyCarryover(config.essence_carryover_percent, 
                          config.token_carryover_percent);
        }
    };
    
    GetSeasonalManager()->RegisterSystem(reg);
}
```

**3. Prestige → SeasonalManager**

```cpp
// New integration:
void PrestigeManager::RegisterWithSeasonalSystem() {
    SystemRegistration reg;
    reg.system_name = "prestige";
    reg.priority = 90;
    
    reg.on_season_event = [](uint32 season_id, SeasonEventType event) {
        if (event == SEASON_EVENT_START) {
            // Create seasonal prestige challenges
            CreateSeasonalChallenges(season_id);
        }
        else if (event == SEASON_EVENT_END) {
            // Award prestige points based on season performance
            DistributePrestigeRewards(season_id);
        }
    };
    
    GetSeasonalManager()->RegisterSystem(reg);
}
```

**4. Quest/Boss Rewards → SeasonalManager**

```cpp
// New system:
class SeasonalRewardManager {
public:
    void RegisterWithSeasonalSystem() {
        SystemRegistration reg;
        reg.system_name = "quest_boss_rewards";
        reg.priority = 85;
        
        reg.on_season_event = [this](uint32 season_id, SeasonEventType event) {
            if (event == SEASON_EVENT_START) {
                LoadQuestRewards(season_id);
                LoadCreatureRewards(season_id);
                LoadSeasonMultipliers(season_id);
            }
        };
        
        GetSeasonalManager()->RegisterSystem(reg);
    }
    
    // PlayerScript hook
    void OnPlayerCompleteQuest(Player* player, Quest const* quest) {
        uint32 season_id = GetSeasonalManager()->GetCurrentSeasonId();
        auto reward = GetQuestReward(season_id, quest->GetQuestId());
        
        if (reward) {
            uint32 tokens = CalculateTokenReward(reward, player, quest);
            AwardTokens(player, tokens);
            LogTransaction(player, season_id, "quest", quest->GetQuestId(), tokens);
        }
    }
    
    // UnitScript hook
    void OnCreatureDeath(Creature* creature, Unit* killer) {
        if (!killer->IsPlayer())
            return;
        
        uint32 season_id = GetSeasonalManager()->GetCurrentSeasonId();
        auto reward = GetCreatureReward(season_id, creature->GetEntry());
        
        if (reward) {
            uint32 tokens = CalculateCreatureReward(reward, creature);
            
            // Split among group if applicable
            if (Group* group = killer->ToPlayer()->GetGroup()) {
                tokens /= group->GetMembersCount();
                for (auto member : group->GetMembers()) {
                    AwardTokens(member, tokens);
                    LogTransaction(member, season_id, "creature", creature->GetEntry(), tokens);
                }
            }
            else {
                AwardTokens(killer->ToPlayer(), tokens);
                LogTransaction(killer->ToPlayer(), season_id, "creature", creature->GetEntry(), tokens);
            }
        }
    }
};
```

---

## Implementation Phases

### Phase 1: Foundation (Weeks 1-2) - PRIORITY

**Goal:** Consolidate existing systems, implement quest/boss rewards

**Tasks:**
1. **Migrate ItemUpgrade to SeasonalManager** (2 days)
   - Replace `SeasonResetManagerImpl` with `SeasonalManager` callback
   - Update database queries to use `dc_seasons` table
   - Test carryover logic

2. **Register Mythic+ with SeasonalManager** (1 day)
   - Add `SystemRegistration` for M+
   - Implement season event callbacks
   - Test season transitions

3. **Implement Quest/Boss Reward System** (3 days)
   - Deploy `dc_seasonal_quest_rewards` and `dc_seasonal_creature_rewards` tables
   - Create `SeasonalRewardManager` class
   - Implement `OnPlayerCompleteQuest` hook
   - Implement `OnCreatureDeath` hook
   - Add weekly cap enforcement

4. **Create Admin Commands** (1 day)
   ```cpp
   .season info [season_id]          // Show season details
   .season start <season_id>         // Start season
   .season end <season_id>           // End season
   .season player <name>             // Show player's season stats
   .season leaderboard <system>      // Show top 10
   .season rewards test quest <id>   // Test quest reward
   .season rewards test creature <id> // Test creature reward
   ```

5. **Testing & Validation** (2 days)
   - Test season transitions across all systems
   - Validate quest/boss rewards
   - Check weekly cap enforcement
   - Load test with 100+ players

**Deliverables:**
- ✅ Unified seasonal system (all systems registered)
- ✅ Automatic quest/boss token rewards
- ✅ Admin commands for testing
- ✅ Full transaction logging

### Phase 2: Mythic+ Seasonal Enhancements (Weeks 3-4)

**Goal:** Extend M+ with full seasonal features

**Tasks:**
1. **Implement M+ Seasonal Leaderboards** (2 days)
   ```sql
   CREATE TABLE dc_mplus_season_leaderboard (
       player_guid INT UNSIGNED,
       season_id INT UNSIGNED,
       highest_keystone TINYINT,
       total_runs INT,
       timed_runs INT,
       score INT,  -- Calculated score
       rank INT,
       PRIMARY KEY (player_guid, season_id),
       KEY idx_season_rank (season_id, rank)
   );
   ```

2. **Add Keystone Level Rewards** (2 days)
   - Award tokens per keystone level completed
   - Bonus tokens for timed runs
   - Weekly vault slots (existing, validate integration)

3. **Seasonal Affix Rotation** (1 day)
   - Already exists in `dc_mplus_affix_schedule`
   - Validate weekly rotation works correctly

4. **M+ Achievements** (2 days)
   - "Keystone Master" (complete all dungeons at +15)
   - "Mythic Champion" (complete all at +20)
   - "Speedrunner" (complete 100 timed runs)

5. **End-of-Season Rewards** (1 day)
   - Top 100 players get seasonal mount
   - Top 10% get transmog set
   - All participants get title

**Deliverables:**
- ✅ M+ leaderboards
- ✅ Keystone-level rewards
- ✅ Seasonal achievements
- ✅ End-of-season distribution

### Phase 3: PvP Seasonal System (Weeks 5-6)

**Goal:** Extend HLBG with full PvP season features

**Tasks:**
1. **Rating-Based Rewards** (2 days)
   - Award tokens based on rating thresholds (1500, 1800, 2100, 2400)
   - Weekly conquest cap system
   - Rating decay prevention during season

2. **PvP Titles** (1 day)
   - "Gladiator" (top 0.5%)
   - "Duelist" (top 2%)
   - "Rival" (top 10%)
   - "Challenger" (1800+ rating)

3. **Seasonal Cosmetics** (2 days)
   - Unique mount for Gladiator (season-specific)
   - Elite transmog set (1800+ rating)
   - Seasonal tabard (participation)

4. **PvP Leaderboards** (1 day)
   - Already exists in HLBG, enhance with UI

5. **Cross-System Synergy** (2 days)
   - High HLBG rating → +10% item upgrade token gain
   - High M+ score → +5% HLBG rating gains
   - Prestige level → bonus season score

**Deliverables:**
- ✅ Rating-based rewards
- ✅ PvP titles and cosmetics
- ✅ Cross-system bonuses

### Phase 4: Unified Client UI (Weeks 7-8)

**Goal:** Single addon for all season info

**Tasks:**
1. **Season Dashboard Frame** (3 days)
   - Overview tab (season info, your rank, score)
   - Mythic+ tab (runs, keystone level, vault)
   - PvP tab (rating, wins/losses, leaderboard)
   - Upgrades tab (essence, tokens, upgrades applied)
   - Leaderboard tab (global rankings)

2. **Server-Client Messaging** (2 days)
   - AIO handlers for requesting data
   - Push notifications (season start/end)
   - Real-time leaderboard updates

3. **Seasonal Progress Bar** (1 day)
   - Display on main UI (near minimap)
   - Shows time remaining, your rank, next reward

4. **Achievement Tracking UI** (2 days)
   - List seasonal achievements
   - Progress bars for each
   - Reward previews

**Deliverables:**
- ✅ Unified season dashboard addon
- ✅ Real-time updates via AIO
- ✅ Progress tracking UI

### Phase 5: Advanced Features (Weeks 9-10)

**Goal:** Polish and expansion

**Tasks:**
1. **Prestige Integration** (2 days)
   - Seasonal prestige challenges
   - Prestige points awarded at season end
   - Prestige-specific rewards

2. **Cosmetic Seasons** (2 days)
   - Seasonal transmog variants
   - Heirloom appearance changes per season
   - Toy/pet rewards

3. **Analytics Dashboard** (2 days)
   - Admin tool for viewing season metrics
   - Player engagement tracking
   - Balance adjustments based on data

4. **Automated Balance Tuning** (2 days)
   - Weekly multiplier adjustments
   - Dynamic weekly cap increases
   - Hotfix system for exploits

**Deliverables:**
- ✅ Prestige seasonal features
- ✅ Cosmetic rewards
- ✅ Admin analytics tools

---

## Migration Plan

### Handling Existing Data

**Scenario 1: Migrating from Old ItemUpgrade Seasons**

```sql
-- Step 1: Backup existing data
CREATE TABLE dc_season_history_backup AS SELECT * FROM dc_season_history;
CREATE TABLE dc_player_season_data_backup AS SELECT * FROM dc_player_season_data;

-- Step 2: Migrate to unified dc_seasons table
INSERT INTO dc_seasons (season_id, season_name, start_timestamp, end_timestamp)
SELECT DISTINCT season_id, 
       CONCAT('Season ', season_id), 
       UNIX_TIMESTAMP(created_at),
       UNIX_TIMESTAMP(created_at) + 15552000  -- 180 days
FROM dc_season_history
WHERE season_id NOT IN (SELECT season_id FROM dc_seasons);

-- Step 3: Populate dc_player_season_aggregate
INSERT INTO dc_player_season_aggregate 
(player_guid, season_id, upgrade_essence_earned, upgrade_tokens_earned, upgrades_applied)
SELECT player_guid, season_id, essence_earned, tokens_earned, total_upgrades
FROM dc_player_season_data;
```

**Scenario 2: Mythic+ Season Data**

```sql
-- dc_mplus_seasons already has correct structure
-- Just need to link to dc_seasons:

-- Add foreign key constraint
ALTER TABLE dc_mplus_seasons 
ADD CONSTRAINT fk_mplus_season 
FOREIGN KEY (season_id) REFERENCES dc_seasons(season_id);

-- Ensure all M+ seasons exist in dc_seasons
INSERT INTO dc_seasons (season_id, season_name, start_timestamp, end_timestamp)
SELECT season_id, label, start_ts, end_ts
FROM dc_mplus_seasons
WHERE season_id NOT IN (SELECT season_id FROM dc_seasons);
```

**Scenario 3: HLBG Season Data**

```sql
-- HLBG uses SeasonalManager correctly, just validate:

-- Check that all HLBG seasons are in dc_seasons
SELECT DISTINCT season_id 
FROM dc_hlbg_player_season_data
WHERE season_id NOT IN (SELECT season_id FROM dc_seasons);

-- Add missing seasons if any
INSERT INTO dc_seasons (season_id, season_name, start_timestamp, end_timestamp)
VALUES (1, 'HLBG Season 1', UNIX_TIMESTAMP('2025-01-01'), UNIX_TIMESTAMP('2025-07-01'));
```

### Safe Deployment Strategy

```bash
# 1. Server maintenance announcement (1 week notice)
# 2. Disable season transitions during migration
UPDATE dc_seasons SET season_state = 3 WHERE season_state = 1;  -- Maintenance mode

# 3. Backup all databases
mysqldump acore_characters > backup_characters_$(date +%Y%m%d).sql
mysqldump acore_world > backup_world_$(date +%Y%m%d).sql

# 4. Deploy new schema
mysql acore_characters < dc_season_unified_schema.sql
mysql acore_world < dc_seasonal_rewards.sql

# 5. Run migration scripts
mysql acore_characters < migrate_itemupgrade_seasons.sql
mysql acore_characters < migrate_hlbg_seasons.sql
mysql acore_world < migrate_mplus_seasons.sql

# 6. Validate data integrity
mysql acore_characters -e "SELECT COUNT(*) FROM dc_player_season_aggregate"
mysql acore_world -e "SELECT COUNT(*) FROM dc_seasonal_quest_rewards"

# 7. Deploy new C++ code
cp src/server/scripts/DC/SeasonSystem/* /path/to/build/
make -j8
systemctl restart worldserver

# 8. Reactive seasons
UPDATE dc_seasons SET season_state = 1 WHERE season_id = <current_season>;

# 9. Announce completion
# 10. Monitor for 24h
```

---

## Quick Reference

### Key Files to Create/Modify

**New Files:**
```
src/server/scripts/DC/SeasonSystem/
├── SeasonalRewardManager.h          (NEW - quest/boss rewards)
├── SeasonalRewardManager.cpp        (NEW)
├── SeasonalProgressionTracker.h     (NEW - unified scoring)
├── SeasonalProgressionTracker.cpp   (NEW)
├── SeasonalAIOHandler.cpp           (NEW - client communication)
└── SeasonalRewardCommands.cpp       (NEW - admin commands)

Custom/Client addons needed/AIO_Client/
└── DC_SeasonDashboard.lua           (NEW - unified UI)

Custom/Custom feature SQLs/
├── chardb/
│   ├── dc_season_unified_schema.sql (NEW - aggregate tables)
│   └── migrate_*.sql                (NEW - migration scripts)
└── worlddb/
    └── SeasonSystem/
        └── dc_seasonal_rewards.sql  (DEPLOY - already designed)
```

**Modified Files:**
```
src/server/scripts/DC/Seasons/SeasonalSystem.h
    -> Add DistributeSeasonRewards(), GetSeasonMultipliers()

src/server/scripts/DC/Seasons/SeasonalSystem.cpp
    -> Enhance with reward distribution logic

src/server/scripts/DC/ItemUpgrades/ItemUpgradeManager.cpp
    -> Remove SeasonResetManagerImpl, use SeasonalManager callbacks

src/server/scripts/DC/MythicPlus/MythicPlusRunManager.cpp
    -> Add RegisterWithSeasonalSystem()

src/server/scripts/DC/Prestige/dc_prestige_system.cpp
    -> Add RegisterWithSeasonalSystem()
```

### Configuration Checklist

**Before Going Live:**
- [ ] Deploy `dc_seasonal_rewards.sql` to world DB
- [ ] Deploy `dc_season_unified_schema.sql` to char DB
- [ ] Run migration scripts for existing data
- [ ] Populate `dc_seasonal_quest_rewards` with quest rewards
- [ ] Populate `dc_seasonal_creature_rewards` with boss rewards
- [ ] Configure `dc_season_global_config` with caps and multipliers
- [ ] Create Season 1 in `dc_seasons` table
- [ ] Register all systems with `SeasonalManager`
- [ ] Test season transitions
- [ ] Deploy AIO client addon
- [ ] Announce season start date

### Admin Commands Summary

```bash
# Season Management
.season info [season_id]             # Show season details
.season list                         # List all seasons
.season create <name> <duration>     # Create new season
.season start <season_id>            # Start season (fire events)
.season end <season_id>              # End season (distribute rewards)

# Player Management
.season player <name>                # Show player's season stats
.season player <name> score          # Show detailed score breakdown
.season player <name> achievements   # Show season achievements

# Leaderboards
.season leaderboard global           # Global leaderboard (all systems)
.season leaderboard mplus            # Mythic+ leaderboard
.season leaderboard hlbg             # HLBG leaderboard
.season leaderboard upgrades         # Item Upgrade leaderboard

# Testing & Debug
.season rewards test quest <id>      # Simulate quest completion
.season rewards test creature <id>   # Simulate boss kill
.season config set <key> <value>     # Update global config
.season reset <season_id>            # Force season reset (dev only)
.season distribute <season_id>       # Force reward distribution (dev only)
```

---

## Conclusion

This comprehensive design consolidates DarkChaos-255's fragmented seasonal systems into a unified, extensible framework. By leveraging the existing `SeasonalSystem` architecture and extending it with quest/boss rewards, Mythic+ enhancements, PvP seasons, and a unified client UI, we create a retail-quality seasonal experience that:

1. **Automates everything** - Season transitions, reward distribution, leaderboards
2. **Engages players** - Clear progression, visible rankings, desirable rewards
3. **Scales efficiently** - Database-driven, no code recompiles for tuning
4. **Supports expansion** - Easy to add new systems (raids, world events, etc.)

**Estimated Total Development Time:** 8-10 weeks (2 developers)

**Priority Order:**
1. Phase 1 (Quest/Boss Rewards) - Immediate value
2. Phase 2 (Mythic+) - Leverages existing infrastructure
3. Phase 4 (Client UI) - Makes everything visible to players
4. Phase 3 (PvP) - HLBG enhancement
5. Phase 5 (Advanced) - Polish and extras

---

**Document Created:** November 22, 2025  
**Author:** GitHub Copilot  
**For:** DarkChaos-255 Development Team  
**Status:** Ready for Implementation
