# Mythic+ Rating & Scoring System

**Priority:** A-Tier  
**Effort:** Medium (2 weeks)  
**Impact:** High  
**Target System:** `src/server/scripts/DC/MythicPlus/`

---

## Overview

Implement a Raider.IO-style rating system that tracks player M+ performance, creates persistent scores, and enables comparison/competition outside of formal tournaments.

---

## Current State

From `MythicPlusRunManager.h`:
- `UpdateScore()` exists but implementation unclear
- Run history tracked in `InsertRunHistory()`
- No visible rating calculation
- No cross-dungeon aggregate scoring

---

## Rating System Design

### Core Concept
- Each player has a **Mythic+ Rating** (0-4000+ range)
- Rating derived from best timed runs per dungeon
- Only best run per dungeon per affix set counts
- Seasonal reset with archive

### Rating Formula
```
Dungeon Score = Base Score + Time Bonus + Key Level Bonus - Death Penalty

Base Score = 100 * KeystoneLevel
Time Bonus = BaseScore * min(1.0, ParTime / ActualTime) * 0.4
Key Level Bonus = (KeystoneLevel - 10) * 25 (if level > 10)
Death Penalty = Deaths * 5

Total Rating = Sum of (Best Tyrannical Score + Best Fortified Score) for all dungeons
```

### Example Calculation
```
Dungeon: Utgarde Keep +18, Tyrannical
Par Time: 25 minutes
Actual Time: 22 minutes
Deaths: 2

Base Score = 100 * 18 = 1800
Time Bonus = 1800 * (25/22) * 0.4 = 818
Key Level Bonus = (18 - 10) * 25 = 200
Death Penalty = 2 * 5 = 10

Dungeon Score = 1800 + 818 + 200 - 10 = 2808
```

---

## Database Schema

```sql
-- Player ratings (aggregate)
CREATE TABLE dc_mythic_ratings (
    player_guid INT UNSIGNED NOT NULL,
    season_id INT UNSIGNED NOT NULL,
    total_rating INT UNSIGNED DEFAULT 0,
    runs_completed INT UNSIGNED DEFAULT 0,
    highest_timed_key TINYINT UNSIGNED DEFAULT 0,
    highest_completed_key TINYINT UNSIGNED DEFAULT 0,
    average_key_level FLOAT DEFAULT 0,
    percentile_rank FLOAT DEFAULT 0,
    last_run_at TIMESTAMP NULL,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (player_guid, season_id),
    KEY idx_season_rating (season_id, total_rating DESC)
);

-- Per-dungeon best scores
CREATE TABLE dc_mythic_dungeon_scores (
    player_guid INT UNSIGNED NOT NULL,
    season_id INT UNSIGNED NOT NULL,
    dungeon_map_id INT UNSIGNED NOT NULL,
    affix_type ENUM('tyrannical', 'fortified') NOT NULL,
    keystone_level TINYINT UNSIGNED NOT NULL,
    score INT UNSIGNED NOT NULL,
    completion_time INT UNSIGNED NOT NULL,  -- seconds
    deaths TINYINT UNSIGNED DEFAULT 0,
    run_timestamp TIMESTAMP NOT NULL,
    PRIMARY KEY (player_guid, season_id, dungeon_map_id, affix_type),
    FOREIGN KEY (season_id) REFERENCES dc_seasons(season_id)
);

-- Rating history (for graphs/trends)
CREATE TABLE dc_mythic_rating_history (
    id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    player_guid INT UNSIGNED NOT NULL,
    season_id INT UNSIGNED NOT NULL,
    rating INT UNSIGNED NOT NULL,
    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY idx_player_season (player_guid, season_id),
    KEY idx_time (recorded_at)
);

-- Leaderboard cache (updated periodically)
CREATE TABLE dc_mythic_leaderboard (
    rank_position INT UNSIGNED NOT NULL,
    season_id INT UNSIGNED NOT NULL,
    player_guid INT UNSIGNED NOT NULL,
    player_name VARCHAR(50) NOT NULL,
    rating INT UNSIGNED NOT NULL,
    class_id TINYINT UNSIGNED NOT NULL,
    spec_id TINYINT UNSIGNED NOT NULL,
    faction TINYINT UNSIGNED NOT NULL,
    guild_name VARCHAR(50),
    runs_this_week INT UNSIGNED DEFAULT 0,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (season_id, rank_position),
    KEY idx_player (player_guid, season_id)
);
```

---

## Implementation

### Rating Manager
```cpp
class MythicRatingManager
{
public:
    static MythicRatingManager* instance();

    // Score calculation
    uint32 CalculateDungeonScore(uint32 mapId, uint8 keystoneLevel, 
                                  uint32 completionTime, uint8 deaths, bool timed);
    
    // Rating updates
    bool RecordRun(ObjectGuid::LowType playerGuid, uint32 seasonId, 
                   const MythicPlusRunManager::InstanceState& state);
    void UpdatePlayerRating(ObjectGuid::LowType playerGuid, uint32 seasonId);
    
    // Queries
    uint32 GetPlayerRating(ObjectGuid::LowType playerGuid, uint32 seasonId);
    PlayerRatingData* GetPlayerRatingData(ObjectGuid::LowType playerGuid, uint32 seasonId);
    std::vector<DungeonScoreData> GetPlayerDungeonScores(ObjectGuid::LowType playerGuid, uint32 seasonId);
    
    // Leaderboard
    void UpdateLeaderboard(uint32 seasonId);
    std::vector<LeaderboardEntry> GetLeaderboard(uint32 seasonId, uint32 offset = 0, uint32 limit = 100);
    uint32 GetPlayerRank(ObjectGuid::LowType playerGuid, uint32 seasonId);
    float GetPlayerPercentile(ObjectGuid::LowType playerGuid, uint32 seasonId);
    
    // Utility
    AffixType GetPrimaryAffix(const std::vector<uint32>& affixes);  // Tyrannical or Fortified
    uint32 GetDungeonParTime(uint32 mapId, uint8 keystoneLevel);
    
private:
    MythicRatingManager() = default;
    
    void RecordRatingHistory(ObjectGuid::LowType playerGuid, uint32 seasonId, uint32 rating);
    
    struct DungeonParTimes
    {
        uint32 mapId;
        uint32 baseParTime;  // seconds at +10
        uint32 perLevelIncrease;  // additional seconds per level
    };
    
    std::unordered_map<uint32, DungeonParTimes> _parTimes;
};

#define sMythicRating MythicRatingManager::instance()
```

### Score Calculation Implementation
```cpp
uint32 MythicRatingManager::CalculateDungeonScore(uint32 mapId, uint8 keystoneLevel, 
                                                   uint32 completionTime, uint8 deaths, bool timed)
{
    // Base score
    uint32 baseScore = 100 * keystoneLevel;
    
    // Get par time for this dungeon at this level
    uint32 parTime = GetDungeonParTime(mapId, keystoneLevel);
    
    // Time bonus (40% of base, scaled by how fast)
    float timeRatio = static_cast<float>(parTime) / static_cast<float>(completionTime);
    timeRatio = std::min(timeRatio, 1.4f);  // Cap at 140% (very fast runs)
    uint32 timeBonus = static_cast<uint32>(baseScore * timeRatio * 0.4f);
    
    // Key level bonus (for high keys)
    uint32 keyLevelBonus = 0;
    if (keystoneLevel > 10)
        keyLevelBonus = (keystoneLevel - 10) * 25;
    
    // Death penalty
    uint32 deathPenalty = deaths * 5;
    
    // Timing penalty (didn't beat timer)
    uint32 timingPenalty = 0;
    if (!timed)
        timingPenalty = baseScore * 0.2f;  // 20% penalty for depleted keys
    
    uint32 score = baseScore + timeBonus + keyLevelBonus - deathPenalty - timingPenalty;
    
    // Minimum score (completed dungeons always count for something)
    return std::max(score, keystoneLevel * 50);
}

bool MythicRatingManager::RecordRun(ObjectGuid::LowType playerGuid, uint32 seasonId,
                                     const MythicPlusRunManager::InstanceState& state)
{
    if (!state.completed)
        return false;

    // Calculate score
    uint32 completionTime = static_cast<uint32>(state.timerEndsAt - state.startedAt);
    bool timed = !state.failed;
    uint32 score = CalculateDungeonScore(state.mapId, state.keystoneLevel, 
                                          completionTime, state.deaths, timed);

    // Determine primary affix (Tyrannical or Fortified)
    AffixType primary = GetPrimaryAffix(state.activeAffixes);
    std::string affixType = (primary == AFFIX_TYRANNICAL) ? "tyrannical" : "fortified";

    // Check if this beats existing score for this dungeon/affix
    auto stmt = CharacterDatabase.GetPreparedStatement(CHAR_SEL_MYTHIC_DUNGEON_SCORE);
    stmt->SetData(0, playerGuid);
    stmt->SetData(1, seasonId);
    stmt->SetData(2, state.mapId);
    stmt->SetData(3, affixType);
    
    PreparedQueryResult result = CharacterDatabase.Query(stmt);
    
    bool isNewBest = false;
    if (!result)
    {
        isNewBest = true;
    }
    else
    {
        Field* fields = result->Fetch();
        uint32 existingScore = fields[0].Get<uint32>();
        isNewBest = (score > existingScore);
    }

    if (isNewBest)
    {
        // Update/insert best score
        auto insertStmt = CharacterDatabase.GetPreparedStatement(CHAR_REP_MYTHIC_DUNGEON_SCORE);
        insertStmt->SetData(0, playerGuid);
        insertStmt->SetData(1, seasonId);
        insertStmt->SetData(2, state.mapId);
        insertStmt->SetData(3, affixType);
        insertStmt->SetData(4, state.keystoneLevel);
        insertStmt->SetData(5, score);
        insertStmt->SetData(6, completionTime);
        insertStmt->SetData(7, state.deaths);
        CharacterDatabase.Execute(insertStmt);

        // Recalculate total rating
        UpdatePlayerRating(playerGuid, seasonId);
        
        return true;
    }

    return false;  // Not a new personal best
}

void MythicRatingManager::UpdatePlayerRating(ObjectGuid::LowType playerGuid, uint32 seasonId)
{
    // Sum best scores from all dungeons (both affix types)
    auto stmt = CharacterDatabase.GetPreparedStatement(CHAR_SEL_MYTHIC_TOTAL_SCORE);
    stmt->SetData(0, playerGuid);
    stmt->SetData(1, seasonId);
    
    PreparedQueryResult result = CharacterDatabase.Query(stmt);
    
    uint32 totalRating = 0;
    if (result)
    {
        Field* fields = result->Fetch();
        totalRating = fields[0].Get<uint32>();
    }

    // Update rating table
    auto updateStmt = CharacterDatabase.GetPreparedStatement(CHAR_REP_MYTHIC_RATING);
    updateStmt->SetData(0, playerGuid);
    updateStmt->SetData(1, seasonId);
    updateStmt->SetData(2, totalRating);
    CharacterDatabase.Execute(updateStmt);

    // Record history point
    RecordRatingHistory(playerGuid, seasonId, totalRating);
}
```

---

## Par Times Per Dungeon

### Base Par Times (at +10)
| Dungeon | Map ID | Par Time (min) |
|---------|--------|----------------|
| Utgarde Keep | 574 | 20 |
| The Nexus | 576 | 25 |
| Azjol-Nerub | 601 | 18 |
| Ahn'kahet | 619 | 30 |
| Drak'Tharon Keep | 600 | 22 |
| Gundrak | 604 | 28 |
| Halls of Stone | 599 | 25 |
| Halls of Lightning | 602 | 26 |
| The Oculus | 578 | 30 |
| Utgarde Pinnacle | 575 | 24 |
| Trial of the Champion | 650 | 18 |
| Forge of Souls | 632 | 20 |
| Pit of Saron | 658 | 22 |
| Halls of Reflection | 668 | 20 |
| The Culling of Stratholme | 595 | 25 |
| The Violet Hold | 608 | 22 |

### Per-Level Scaling
```cpp
uint32 MythicRatingManager::GetDungeonParTime(uint32 mapId, uint8 keystoneLevel)
{
    auto it = _parTimes.find(mapId);
    if (it == _parTimes.end())
        return 25 * 60;  // Default 25 minutes in seconds
    
    const DungeonParTimes& pt = it->second;
    
    // Base par at level 10, +30 seconds per level above 10
    uint32 basePar = pt.baseParTime;
    uint32 levelAdjust = (keystoneLevel > 10) ? (keystoneLevel - 10) * pt.perLevelIncrease : 0;
    
    // Lower levels are slightly faster
    if (keystoneLevel < 10)
        levelAdjust = (10 - keystoneLevel) * (pt.perLevelIncrease / 2);
    
    return basePar + levelAdjust;
}
```

---

## Commands

### Player Commands
| Command | Description |
|---------|-------------|
| `.mythic rating` | Show your current rating |
| `.mythic rating <player>` | Show another player's rating |
| `.mythic scores` | Show your dungeon scores breakdown |
| `.mythic leaderboard` | Top 10 players |
| `.mythic rank` | Your rank and percentile |

### Command Implementation
```cpp
static bool HandleMythicRatingCommand(ChatHandler* handler, Optional<PlayerIdentifier> target)
{
    Player* targetPlayer = target ? target->GetConnectedPlayer() : handler->GetPlayer();
    if (!targetPlayer)
    {
        handler->SendSysMessage("Player not found.");
        return true;
    }

    uint32 seasonId = sMythicRuns->GetCurrentSeasonId();
    uint32 rating = sMythicRating->GetPlayerRating(targetPlayer->GetGUID().GetCounter(), seasonId);
    uint32 rank = sMythicRating->GetPlayerRank(targetPlayer->GetGUID().GetCounter(), seasonId);
    float percentile = sMythicRating->GetPlayerPercentile(targetPlayer->GetGUID().GetCounter(), seasonId);

    handler->PSendSysMessage("|cFF00FF00[Mythic+ Rating]|r %s", targetPlayer->GetName().c_str());
    handler->PSendSysMessage("  Rating: |cFFFFD700%u|r", rating);
    handler->PSendSysMessage("  Rank: |cFFFFD700#%u|r (Top %.1f%%)", rank, percentile);

    // Show per-dungeon breakdown
    auto scores = sMythicRating->GetPlayerDungeonScores(targetPlayer->GetGUID().GetCounter(), seasonId);
    if (!scores.empty())
    {
        handler->SendSysMessage("  |cFFAAAAAA--- Dungeon Scores ---|r");
        for (const auto& score : scores)
        {
            handler->PSendSysMessage("    %s: T|cFF00FF00%u|r F|cFF00BFFF%u|r",
                GetDungeonName(score.mapId).c_str(),
                score.tyrannicalScore,
                score.fortifiedScore);
        }
    }

    return true;
}
```

---

## AIO Addon Integration

### Rating Display Frame
```lua
-- MythicRating.lua
local RatingFrame = AIO.AddAddon()

function RatingFrame:Init()
    -- Rating display on character panel
    self.ratingText = CreateFrame("Frame", nil, CharacterFrame)
    self.ratingText:SetPoint("TOPRIGHT", -50, -60)
    
    self.ratingValue = self.ratingText:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    self.ratingValue:SetText("0")
    
    self.ratingLabel = self.ratingText:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.ratingLabel:SetPoint("TOP", self.ratingValue, "BOTTOM")
    self.ratingLabel:SetText("M+ Rating")
    
    -- Color rating by tier
    self:ColorByRating(0)
end

function RatingFrame:UpdateRating(rating)
    self.ratingValue:SetText(rating)
    self:ColorByRating(rating)
end

function RatingFrame:ColorByRating(rating)
    local color
    if rating >= 3500 then
        color = {1, 0.5, 0}      -- Orange (legendary)
    elseif rating >= 3000 then
        color = {0.64, 0.21, 0.93}  -- Purple (epic)
    elseif rating >= 2500 then
        color = {0, 0.44, 0.87}  -- Blue (rare)
    elseif rating >= 2000 then
        color = {0.12, 1, 0}     -- Green (uncommon)
    elseif rating >= 1500 then
        color = {1, 1, 1}        -- White (common)
    else
        color = {0.6, 0.6, 0.6}  -- Gray (poor)
    end
    
    self.ratingValue:SetTextColor(unpack(color))
end
```

### Dungeon Score Panel
```lua
function RatingFrame:CreateDungeonPanel()
    self.dungeonPanel = CreateFrame("Frame", "DCMythicDungeonPanel", UIParent)
    self.dungeonPanel:SetSize(400, 500)
    self.dungeonPanel:SetPoint("CENTER")
    
    self.dungeonRows = {}
    
    for i = 1, 16 do
        local row = CreateFrame("Frame", nil, self.dungeonPanel)
        row:SetSize(380, 24)
        row:SetPoint("TOPLEFT", 10, -30 * i)
        
        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.name:SetPoint("LEFT")
        row.name:SetWidth(150)
        
        row.tyrannical = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.tyrannical:SetPoint("LEFT", row.name, "RIGHT", 20, 0)
        
        row.fortified = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.fortified:SetPoint("LEFT", row.tyrannical, "RIGHT", 30, 0)
        
        row.total = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        row.total:SetPoint("RIGHT")
        
        self.dungeonRows[i] = row
    end
end

function RatingFrame:UpdateDungeonScores(scores)
    for i, score in ipairs(scores) do
        local row = self.dungeonRows[i]
        if row then
            row.name:SetText(score.dungeonName)
            row.tyrannical:SetText("|cFF00FF00" .. score.tyrannical .. "|r")
            row.fortified:SetText("|cFF00BFFF" .. score.fortified .. "|r")
            row.total:SetText(score.tyrannical + score.fortified)
        end
    end
end
```

---

## Timeline

| Phase | Duration | Tasks |
|-------|----------|-------|
| Schema | 1 day | Database tables |
| Core | 4 days | RatingManager, score calculation |
| Integration | 2 days | Hook into run completion |
| Leaderboard | 2 days | Ranking and percentile |
| Commands | 1 day | Player commands |
| UI | 3 days | AIO addon rating display |
| Testing | 2 days | Score validation |
| **Total** | **~2 weeks** | |

---

## Future Enhancements

1. **Rating Decay** - Inactive players slowly lose rating
2. **Role-Specific Rating** - Tank/Healer/DPS ratings
3. **Dungeon Mastery** - Achievements for rating per dungeon
4. **Rating Rewards** - Cosmetics at rating thresholds
5. **Graph/History View** - Rating progression over time
