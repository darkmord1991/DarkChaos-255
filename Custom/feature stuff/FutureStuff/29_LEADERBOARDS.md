# Seasonal Leaderboard System

**Priority:** B4 (Medium-term)  
**Effort:** Medium (2-3 weeks)  
**Impact:** High  
**Base:** Existing Seasons + Mythic+ Systems

---

## Overview

Comprehensive leaderboard tracking for all competitive content across seasons. Provides rankings, rewards, and visibility for top performers in PvE and PvP activities.

---

## Why It Fits DarkChaos-255

### Leverages Existing Systems
| System | Integration |
|--------|-------------|
| **Seasons** | Per-season rankings |
| **Mythic+** | M+ keystones |
| **Prestige** | Prestige achievements |
| **Hotspot** | Zone performance |
| **HinterlandBG** | BG rankings |
| **Gilneas BG** | BG rankings |

### Benefits
- Competitive motivation
- Season rewards goal
- Guild competition
- Player retention
- Bragging rights

---

## Leaderboard Categories

### PvE Categories
| Category | Metric | Tracked |
|----------|--------|---------|
| **M+ Score** | Sum of best runs | Character |
| **M+ Speed** | Fastest completion | Group |
| **Boss Kills** | World boss kills | Character |
| **Dungeon Clears** | Total cleared | Character |
| **Achievement Points** | DC achievements | Character |

### PvP Categories
| Category | Metric | Tracked |
|----------|--------|---------|
| **BG Rating** | Win/loss rating | Character |
| **Kill Score** | Weighted kills | Character |
| **HLBG Champion** | Hinterland BG | Character |
| **Gilneas Hero** | Gilneas BG | Character |
| **Duel Master** | Duel wins | Character |

### Economy Categories
| Category | Metric | Tracked |
|----------|--------|---------|
| **Wealth** | Total gold (hidden) | Account |
| **Collector** | Items collected | Account |
| **Crafter** | Items crafted | Character |

### Guild Categories
| Category | Metric | Tracked |
|----------|--------|---------|
| **Combined M+** | Sum of all members | Guild |
| **Raid Progress** | Bosses killed | Guild |
| **PvP Score** | Combined rating | Guild |
| **Activity** | Weekly activity | Guild |

---

## Database Schema

```sql
-- Leaderboard definitions
CREATE TABLE dc_leaderboards (
    leaderboard_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    leaderboard_name VARCHAR(100) NOT NULL,
    category ENUM('pve', 'pvp', 'economy', 'guild', 'seasonal') NOT NULL,
    metric_type VARCHAR(50) NOT NULL, -- e.g., 'mythic_score', 'kills'
    tracking_type ENUM('character', 'account', 'guild', 'group') NOT NULL,
    display_count INT UNSIGNED DEFAULT 100, -- Top X shown
    season_specific BOOLEAN DEFAULT TRUE,
    is_active BOOLEAN DEFAULT TRUE,
    reward_tier_1 INT UNSIGNED, -- Top 10
    reward_tier_2 INT UNSIGNED, -- Top 100
    reward_tier_3 INT UNSIGNED  -- Top 1000
);

-- Leaderboard entries
CREATE TABLE dc_leaderboard_entries (
    entry_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    leaderboard_id INT UNSIGNED NOT NULL,
    season_id INT UNSIGNED NOT NULL,
    entity_guid BIGINT UNSIGNED NOT NULL, -- player, account, or guild GUID
    entity_name VARCHAR(50) NOT NULL,
    score BIGINT NOT NULL DEFAULT 0,
    rank INT UNSIGNED DEFAULT 0,
    previous_rank INT UNSIGNED DEFAULT 0,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    snapshot_data TEXT, -- JSON with breakdown
    FOREIGN KEY (leaderboard_id) REFERENCES dc_leaderboards(leaderboard_id),
    INDEX idx_lb_season (leaderboard_id, season_id),
    INDEX idx_score (leaderboard_id, season_id, score DESC),
    INDEX idx_entity (entity_guid, leaderboard_id)
);

-- Historical snapshots (daily)
CREATE TABLE dc_leaderboard_history (
    history_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    leaderboard_id INT UNSIGNED NOT NULL,
    season_id INT UNSIGNED NOT NULL,
    snapshot_date DATE NOT NULL,
    entity_guid BIGINT UNSIGNED NOT NULL,
    rank INT UNSIGNED NOT NULL,
    score BIGINT NOT NULL,
    INDEX idx_history (leaderboard_id, season_id, snapshot_date)
);

-- Season rewards
CREATE TABLE dc_leaderboard_rewards (
    reward_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    leaderboard_id INT UNSIGNED NOT NULL,
    rank_min INT UNSIGNED NOT NULL,
    rank_max INT UNSIGNED NOT NULL,
    reward_type ENUM('item', 'title', 'mount', 'pet', 'currency', 'achievement') NOT NULL,
    reward_entry INT UNSIGNED NOT NULL,
    reward_count INT UNSIGNED DEFAULT 1,
    FOREIGN KEY (leaderboard_id) REFERENCES dc_leaderboards(leaderboard_id)
);

-- Populate base leaderboards
INSERT INTO dc_leaderboards (leaderboard_name, category, metric_type, tracking_type, season_specific) VALUES
('Mythic+ Score', 'pve', 'mythic_score', 'character', 1),
('Mythic+ Speed Champions', 'pve', 'mythic_speed', 'group', 1),
('PvP Rating', 'pvp', 'bg_rating', 'character', 1),
('Hinterland Champions', 'pvp', 'hlbg_wins', 'character', 1),
('Achievement Hunter', 'pve', 'achievement_points', 'character', 1),
('Guild Power', 'guild', 'combined_score', 'guild', 1);
```

---

## Implementation

### Leaderboard Manager
```cpp
class LeaderboardMgr
{
public:
    static LeaderboardMgr* Instance()
    {
        static LeaderboardMgr instance;
        return &instance;
    }

    // Update a player's score
    void UpdateScore(uint32 leaderboardId, ObjectGuid guid, int64 scoreDelta, const std::string& name)
    {
        std::lock_guard<std::mutex> lock(_mutex);
        
        auto& entry = _entries[leaderboardId][guid];
        entry.score += scoreDelta;
        entry.name = name;
        entry.dirty = true;
        
        // Flag for recalculation
        _dirtyLeaderboards.insert(leaderboardId);
    }

    // Set absolute score
    void SetScore(uint32 leaderboardId, ObjectGuid guid, int64 score, const std::string& name)
    {
        std::lock_guard<std::mutex> lock(_mutex);
        
        auto& entry = _entries[leaderboardId][guid];
        entry.score = score;
        entry.name = name;
        entry.dirty = true;
        
        _dirtyLeaderboards.insert(leaderboardId);
    }

    // Get top N entries
    std::vector<LeaderboardEntry> GetTopN(uint32 leaderboardId, uint32 count)
    {
        std::lock_guard<std::mutex> lock(_mutex);
        
        // Return cached sorted list
        auto it = _sortedCache.find(leaderboardId);
        if (it == _sortedCache.end())
            return {};

        count = std::min(count, (uint32)it->second.size());
        return std::vector<LeaderboardEntry>(it->second.begin(), it->second.begin() + count);
    }

    // Get player rank
    uint32 GetRank(uint32 leaderboardId, ObjectGuid guid)
    {
        std::lock_guard<std::mutex> lock(_mutex);
        
        auto it = _rankCache.find(leaderboardId);
        if (it == _rankCache.end())
            return 0;

        auto rankIt = it->second.find(guid);
        return rankIt != it->second.end() ? rankIt->second : 0;
    }

    // Recalculate ranks (called periodically)
    void RecalculateRanks()
    {
        std::lock_guard<std::mutex> lock(_mutex);
        
        for (uint32 lbId : _dirtyLeaderboards)
        {
            auto& entries = _entries[lbId];
            auto& sorted = _sortedCache[lbId];
            auto& ranks = _rankCache[lbId];
            
            sorted.clear();
            for (auto& pair : entries)
            {
                sorted.push_back(pair.second);
            }
            
            // Sort by score descending
            std::sort(sorted.begin(), sorted.end(), 
                [](const LeaderboardEntry& a, const LeaderboardEntry& b) 
                { return a.score > b.score; });
            
            // Assign ranks
            ranks.clear();
            for (size_t i = 0; i < sorted.size(); ++i)
            {
                sorted[i].rank = i + 1;
                ranks[sorted[i].guid] = i + 1;
            }
        }
        
        _dirtyLeaderboards.clear();
    }

    // Save to database
    void SaveToDB()
    {
        CharacterDatabase.DirectExecute("DELETE FROM dc_leaderboard_entries WHERE season_id = {}", GetCurrentSeasonId());
        
        for (auto& lbPair : _entries)
        {
            uint32 lbId = lbPair.first;
            for (auto& entryPair : lbPair.second)
            {
                auto& entry = entryPair.second;
                auto rank = GetRank(lbId, entry.guid);
                
                CharacterDatabase.DirectExecute(
                    "INSERT INTO dc_leaderboard_entries (leaderboard_id, season_id, entity_guid, entity_name, score, rank) "
                    "VALUES ({}, {}, {}, '{}', {}, {})",
                    lbId, GetCurrentSeasonId(), entry.guid.GetCounter(), entry.name, entry.score, rank);
            }
        }
    }

private:
    std::map<uint32, std::map<ObjectGuid, LeaderboardEntry>> _entries;
    std::map<uint32, std::vector<LeaderboardEntry>> _sortedCache;
    std::map<uint32, std::map<ObjectGuid, uint32>> _rankCache;
    std::set<uint32> _dirtyLeaderboards;
    std::mutex _mutex;
};

#define sLeaderboardMgr LeaderboardMgr::Instance()
```

### Mythic+ Integration
```cpp
// Hook into existing Mythic+ completion
void OnMythicPlusComplete(Player* player, uint32 keystoneLevel, uint32 timeMs)
{
    // Calculate score
    int64 score = CalculateMythicScore(keystoneLevel, timeMs);
    
    // Update leaderboard
    sLeaderboardMgr->UpdateScore(LEADERBOARD_MYTHIC_SCORE, player->GetGUID(), score, player->GetName());
    
    // Check for speed run
    uint32 dungeonId = player->GetInstanceId();
    auto existingSpeed = GetBestSpeedRun(dungeonId, keystoneLevel);
    if (timeMs < existingSpeed)
    {
        // Update speed leaderboard (group tracking)
        Group* group = player->GetGroup();
        if (group)
        {
            std::string groupKey = BuildGroupKey(group);
            sLeaderboardMgr->SetScore(LEADERBOARD_MYTHIC_SPEED, MakeGroupGuid(group), timeMs, groupKey);
        }
    }
}
```

### Chat Commands
```cpp
class dc_leaderboard_commands : public CommandScript
{
public:
    dc_leaderboard_commands() : CommandScript("dc_leaderboard_commands") { }

    std::vector<ChatCommand> GetCommands() const override
    {
        static std::vector<ChatCommand> lbCommandTable =
        {
            { "top",    SEC_PLAYER, false, &HandleTopCommand,    "" },
            { "rank",   SEC_PLAYER, false, &HandleRankCommand,   "" },
            { "guild",  SEC_PLAYER, false, &HandleGuildCommand,  "" },
        };
        
        static std::vector<ChatCommand> commandTable =
        {
            { "lb", SEC_PLAYER, false, nullptr, "", lbCommandTable },
        };
        
        return commandTable;
    }

    static bool HandleTopCommand(ChatHandler* handler, const char* args)
    {
        std::string category = args;
        uint32 lbId = GetLeaderboardIdByCategory(category);
        
        auto entries = sLeaderboardMgr->GetTopN(lbId, 10);
        
        handler->PSendSysMessage("|cff00ff00=== Top 10: %s ===|r", category.c_str());
        for (size_t i = 0; i < entries.size(); ++i)
        {
            handler->PSendSysMessage("|cffffd700%zu.|r %s - |cff00ff00%lld|r", 
                i + 1, entries[i].name.c_str(), entries[i].score);
        }
        
        return true;
    }

    static bool HandleRankCommand(ChatHandler* handler, const char* args)
    {
        Player* player = handler->GetSession()->GetPlayer();
        std::string category = args;
        uint32 lbId = GetLeaderboardIdByCategory(category);
        
        uint32 rank = sLeaderboardMgr->GetRank(lbId, player->GetGUID());
        
        if (rank == 0)
            handler->PSendSysMessage("You are not ranked in %s.", category.c_str());
        else
            handler->PSendSysMessage("Your rank in %s: |cffffd700#%u|r", category.c_str(), rank);
        
        return true;
    }
};
```

---

## AIO Addon Display

```lua
-- LeaderboardFrame.lua
local LeaderboardFrame = AIO.AddAddon()

function LeaderboardFrame:Init()
    self.frame = CreateFrame("Frame", "DCLeaderboardFrame", UIParent)
    self.frame:SetSize(400, 500)
    self.frame:SetPoint("CENTER")
    self.frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
    })
    self.frame:Hide()
    
    -- Title
    self.title = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    self.title:SetPoint("TOP", 0, -15)
    self.title:SetText("Season Leaderboards")
    
    -- Category tabs
    self:CreateCategoryTabs()
    
    -- Entry list
    self:CreateEntryList()
    
    -- Player rank display
    self:CreatePlayerRankDisplay()
end

function LeaderboardFrame:CreateEntryList()
    self.entries = {}
    for i = 1, 15 do
        local entry = CreateFrame("Frame", nil, self.frame)
        entry:SetSize(360, 28)
        entry:SetPoint("TOP", 0, -80 - (i-1) * 30)
        
        entry.rank = entry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        entry.rank:SetPoint("LEFT", 10, 0)
        entry.rank:SetWidth(40)
        
        entry.name = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        entry.name:SetPoint("LEFT", 60, 0)
        entry.name:SetWidth(200)
        entry.name:SetJustifyH("LEFT")
        
        entry.score = entry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        entry.score:SetPoint("RIGHT", -10, 0)
        entry.score:SetWidth(80)
        entry.score:SetJustifyH("RIGHT")
        
        self.entries[i] = entry
    end
end

function LeaderboardFrame:UpdateDisplay(data)
    for i, entry in ipairs(self.entries) do
        if data[i] then
            local d = data[i]
            entry.rank:SetText(GetRankColor(d.rank) .. "#" .. d.rank .. "|r")
            entry.name:SetText(d.name)
            entry.score:SetText("|cff00ff00" .. FormatScore(d.score) .. "|r")
            entry:Show()
        else
            entry:Hide()
        end
    end
end

-- Color based on rank
function GetRankColor(rank)
    if rank == 1 then return "|cffffd700" -- Gold
    elseif rank <= 3 then return "|cffc0c0c0" -- Silver
    elseif rank <= 10 then return "|cffcd7f32" -- Bronze
    else return "|cffffffff" end
end
```

---

## Season End Rewards

### Distribution Logic
```cpp
void DistributeSeasonRewards(uint32 seasonId)
{
    auto leaderboards = GetAllLeaderboards();
    
    for (auto& lb : leaderboards)
    {
        auto rewards = GetRewardsForLeaderboard(lb.id);
        auto entries = sLeaderboardMgr->GetTopN(lb.id, 1000);
        
        for (auto& entry : entries)
        {
            for (auto& reward : rewards)
            {
                if (entry.rank >= reward.rankMin && entry.rank <= reward.rankMax)
                {
                    // Mail reward to player
                    MailItem(entry.guid, reward.type, reward.entry, reward.count,
                        "Season " + std::to_string(seasonId) + " Reward",
                        "Congratulations on achieving rank #" + std::to_string(entry.rank) + 
                        " in " + lb.name + "!");
                }
            }
        }
    }
}
```

### Reward Tiers
| Rank | Reward |
|------|--------|
| 1 | Unique title + Mount + 1000 tokens |
| 2-3 | Unique title + 500 tokens |
| 4-10 | Title + 250 tokens |
| 11-100 | 100 tokens + transmog set |
| 101-1000 | 50 tokens |

---

## Commands Summary

| Command | Description |
|---------|-------------|
| `.lb top mythic` | View Mythic+ leaderboard |
| `.lb top pvp` | View PvP leaderboard |
| `.lb top guild` | View Guild leaderboard |
| `.lb rank mythic` | Check your Mythic+ rank |
| `.lb history` | Your ranking over season |

---

## Timeline

| Phase | Duration |
|-------|----------|
| Database + Manager | 3 days |
| System integrations | 5 days |
| AIO addon | 4 days |
| Season rewards | 2 days |
| Testing | 3 days |
| **Total** | **~2.5 weeks** |

---

## Future Enhancements

1. **Real-time updates** - Live rank changes
2. **Spectator mode** - Watch top players
3. **Hall of Fame** - Permanent #1 recognition
4. **Region boards** - Per-timezone rankings
5. **Historical stats** - All-time records
