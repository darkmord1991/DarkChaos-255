# Enhanced Seasonal Rewards Framework

**Priority:** S-Tier  
**Effort:** Medium (2 weeks)  
**Impact:** Very High  
**Target System:** `src/server/scripts/DC/Seasons/`

---

## Current State Analysis

### From SeasonalSystem.h
```cpp
struct SeasonDefinition
{
    uint32 season_id;
    std::string season_name;
    std::string season_description;
    SeasonType season_type;
    SeasonState season_state;
    time_t start_timestamp;
    time_t end_timestamp;
    bool allow_carryover;
    float carryover_percentage;
    std::string theme_name;
    std::string banner_path;
    std::map<std::string, std::string> custom_properties;
};
```

### Gaps Identified
- No reward tier definitions
- No exclusive content flagging
- No milestone tracking
- No prestige/title integration
- No visual theme application
- No AIO season display

---

## Enhanced Reward System

### Reward Tiers
| Tier | Name | Requirement | Rewards |
|------|------|-------------|---------|
| Bronze | Initiate | Complete 10 M+ keys | Token bonus, portrait border |
| Silver | Challenger | Reach rating 1500 | Exclusive transmog, title |
| Gold | Champion | Reach rating 2500 | Mount, achievement |
| Platinum | Elite | Reach rating 3000 | Armor set, elite title |
| Diamond | Legend | Top 100 realm | Unique mount, realm first access |

---

## Database Schema

```sql
-- Season reward tiers
CREATE TABLE dc_season_reward_tiers (
    tier_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    season_id INT UNSIGNED NOT NULL,
    tier_name VARCHAR(50) NOT NULL,
    tier_order TINYINT UNSIGNED NOT NULL,  -- Display order
    requirement_type ENUM('rating', 'runs', 'achievements', 'time_played', 'rank') NOT NULL,
    requirement_value INT UNSIGNED NOT NULL,
    icon_path VARCHAR(255),
    color_hex VARCHAR(8) DEFAULT 'FFFFFF',
    FOREIGN KEY (season_id) REFERENCES dc_seasons(season_id)
);

-- Tier rewards
CREATE TABLE dc_season_tier_rewards (
    reward_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    tier_id INT UNSIGNED NOT NULL,
    reward_type ENUM('item', 'title', 'mount', 'pet', 'transmog', 'achievement', 'currency', 'portrait_border', 'nameplate') NOT NULL,
    reward_entry INT UNSIGNED NOT NULL,
    reward_count INT UNSIGNED DEFAULT 1,
    display_name VARCHAR(100),
    description TEXT,
    is_exclusive BOOLEAN DEFAULT TRUE,  -- Only available this season
    FOREIGN KEY (tier_id) REFERENCES dc_season_reward_tiers(tier_id)
);

-- Player tier progress
CREATE TABLE dc_season_player_tiers (
    player_guid INT UNSIGNED NOT NULL,
    season_id INT UNSIGNED NOT NULL,
    highest_tier_id INT UNSIGNED DEFAULT 0,
    current_progress INT UNSIGNED DEFAULT 0,
    tier_achieved_at TIMESTAMP NULL,
    rewards_claimed BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (player_guid, season_id)
);

-- Season milestones (intermediate goals)
CREATE TABLE dc_season_milestones (
    milestone_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    season_id INT UNSIGNED NOT NULL,
    milestone_name VARCHAR(100) NOT NULL,
    milestone_order TINYINT UNSIGNED NOT NULL,
    requirement_type ENUM('rating', 'runs', 'dungeons_unique', 'boss_kills', 'affix_combos') NOT NULL,
    requirement_value INT UNSIGNED NOT NULL,
    reward_type ENUM('currency', 'item', 'achievement') NOT NULL,
    reward_entry INT UNSIGNED NOT NULL,
    reward_count INT UNSIGNED DEFAULT 1,
    FOREIGN KEY (season_id) REFERENCES dc_seasons(season_id)
);

-- Player milestone progress
CREATE TABLE dc_season_player_milestones (
    player_guid INT UNSIGNED NOT NULL,
    milestone_id INT UNSIGNED NOT NULL,
    current_progress INT UNSIGNED DEFAULT 0,
    completed BOOLEAN DEFAULT FALSE,
    completed_at TIMESTAMP NULL,
    claimed BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (player_guid, milestone_id)
);

-- Season exclusive content
CREATE TABLE dc_season_exclusive_content (
    content_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    season_id INT UNSIGNED NOT NULL,
    content_type ENUM('dungeon', 'affix', 'item', 'creature', 'quest', 'achievement') NOT NULL,
    content_entry INT UNSIGNED NOT NULL,
    description TEXT,
    available_from TIMESTAMP NULL,
    available_until TIMESTAMP NULL,
    FOREIGN KEY (season_id) REFERENCES dc_seasons(season_id)
);
```

---

## Season Theme System

### Theme Definition
```cpp
struct SeasonTheme
{
    uint32 seasonId;
    std::string themeName;
    
    // Visual elements
    std::string bannerTexture;
    std::string loadingScreenOverlay;
    std::string uiColorScheme;  // Hex color for UI accents
    
    // Audio
    uint32 loginMusicId;
    uint32 achievementSoundId;
    
    // World effects
    uint32 weatherSpellId;
    uint32 skyboxOverrideId;
    std::vector<uint32> themeCreatureDisplayIds;
    
    // Transmog set
    uint32 themeTransmogSetId;
    
    // Affixes
    std::vector<AffixType> seasonalAffixes;
    AffixType featuredAffix;
};
```

### Theme Application
```cpp
class SeasonThemeManager
{
public:
    void ApplySeasonTheme(uint32 seasonId);
    void OnPlayerLogin(Player* player);
    void OnZoneChange(Player* player, uint32 newZoneId);

private:
    void ApplyUITheme(Player* player, const SeasonTheme& theme);
    void ApplyWorldEffects(const SeasonTheme& theme);
    void SetSeasonalMOTD(const SeasonTheme& theme);
};

void SeasonThemeManager::OnPlayerLogin(Player* player)
{
    auto theme = GetCurrentSeasonTheme();
    if (!theme)
        return;

    // Send season welcome message
    std::ostringstream msg;
    msg << "|cFFFFD700[" << theme->themeName << " Season]|r\n";
    msg << "Welcome to Season " << theme->seasonId << "!\n";
    msg << "Featured affix: " << GetAffixName(theme->featuredAffix);
    
    ChatHandler(player->GetSession()).SendSysMessage(msg.str().c_str());
    
    // Apply UI theme via AIO
    SendSeasonThemeToClient(player, *theme);
    
    // Check for unclaimed rewards
    CheckUnclaimedRewards(player);
}
```

---

## Reward Manager Implementation

```cpp
class SeasonRewardManager
{
public:
    static SeasonRewardManager* instance();

    // Tier management
    bool CheckTierProgress(ObjectGuid::LowType playerGuid, uint32 seasonId);
    RewardTier* GetPlayerCurrentTier(ObjectGuid::LowType playerGuid, uint32 seasonId);
    RewardTier* GetNextTier(ObjectGuid::LowType playerGuid, uint32 seasonId);
    float GetTierProgressPercent(ObjectGuid::LowType playerGuid, uint32 seasonId);

    // Milestone tracking
    bool UpdateMilestoneProgress(ObjectGuid::LowType playerGuid, uint32 seasonId,
                                  MilestoneType type, uint32 increment);
    std::vector<Milestone*> GetPlayerMilestones(ObjectGuid::LowType playerGuid, uint32 seasonId);
    bool ClaimMilestoneReward(ObjectGuid::LowType playerGuid, uint32 milestoneId);

    // Reward distribution
    bool GrantTierRewards(Player* player, uint32 tierId);
    bool ClaimSeasonRewards(Player* player, uint32 seasonId);
    std::vector<PendingReward> GetUnclaimedRewards(ObjectGuid::LowType playerGuid);

    // Exclusive content
    bool IsContentAvailable(uint32 contentId, ObjectGuid::LowType playerGuid);
    void UnlockExclusiveContent(ObjectGuid::LowType playerGuid, uint32 contentId);

    // End of season
    void ProcessSeasonEnd(uint32 seasonId);
    void ArchiveSeasonProgress(uint32 seasonId);
    void DistributeFinalRewards(uint32 seasonId);

private:
    SeasonRewardManager() = default;
    
    void LoadTiers(uint32 seasonId);
    void LoadMilestones(uint32 seasonId);
    void SendRewardNotification(Player* player, const Reward& reward);
};

#define sSeasonRewards SeasonRewardManager::instance()
```

### Progress Tracking
```cpp
bool SeasonRewardManager::CheckTierProgress(ObjectGuid::LowType playerGuid, uint32 seasonId)
{
    auto playerData = GetPlayerSeasonData(playerGuid, seasonId);
    if (!playerData)
        return false;

    // Get all tiers for this season
    auto tiers = GetSeasonTiers(seasonId);
    
    uint32 currentTierId = playerData->highestTierId;
    bool tierAdvanced = false;
    
    for (const auto& tier : tiers)
    {
        if (tier->tierId <= currentTierId)
            continue;  // Already achieved
        
        // Check requirement
        bool achieved = false;
        switch (tier->requirementType)
        {
            case REQUIREMENT_RATING:
                achieved = (sMythicRating->GetPlayerRating(playerGuid, seasonId) >= tier->requirementValue);
                break;
            case REQUIREMENT_RUNS:
                achieved = (GetPlayerRunCount(playerGuid, seasonId) >= tier->requirementValue);
                break;
            case REQUIREMENT_RANK:
                achieved = (sMythicRating->GetPlayerRank(playerGuid, seasonId) <= tier->requirementValue);
                break;
            // ... other types
        }
        
        if (achieved)
        {
            // Grant tier
            playerData->highestTierId = tier->tierId;
            playerData->tierAchievedAt = GameTime::GetGameTime().count();
            
            // Save to DB
            SavePlayerTierProgress(playerGuid, seasonId, tier->tierId);
            
            // Notify and grant rewards
            if (Player* player = ObjectAccessor::FindPlayer(ObjectGuid(HighGuid::Player, playerGuid)))
            {
                GrantTierRewards(player, tier->tierId);
                AnnounceTierAchievement(player, tier);
            }
            else
            {
                // Player offline, queue rewards
                QueueOfflineRewards(playerGuid, tier->tierId);
            }
            
            tierAdvanced = true;
        }
        else
        {
            break;  // Can't skip tiers
        }
    }
    
    return tierAdvanced;
}
```

---

## AIO Season Display

### Season Hub Frame
```lua
-- SeasonHub.lua
local SeasonHub = AIO.AddAddon()

function SeasonHub:Init()
    self.frame = CreateFrame("Frame", "DCSeasonHub", UIParent)
    self.frame:SetSize(700, 550)
    self.frame:SetPoint("CENTER")
    
    -- Season banner
    self:CreateSeasonBanner()
    
    -- Tier progress
    self:CreateTierProgress()
    
    -- Milestones
    self:CreateMilestonePanel()
    
    -- Rewards preview
    self:CreateRewardsPanel()
    
    -- Timer
    self:CreateSeasonTimer()
end

function SeasonHub:CreateTierProgress()
    self.tierFrame = CreateFrame("Frame", nil, self.frame)
    self.tierFrame:SetSize(650, 100)
    self.tierFrame:SetPoint("TOP", 0, -80)
    
    -- Tier icons
    self.tierIcons = {}
    local tiers = {"Bronze", "Silver", "Gold", "Platinum", "Diamond"}
    local colors = {
        Bronze = {0.8, 0.5, 0.2},
        Silver = {0.75, 0.75, 0.75},
        Gold = {1, 0.84, 0},
        Platinum = {0.9, 0.9, 1},
        Diamond = {0.6, 0.8, 1}
    }
    
    for i, tierName in ipairs(tiers) do
        local icon = CreateFrame("Frame", nil, self.tierFrame)
        icon:SetSize(80, 80)
        icon:SetPoint("LEFT", (i - 1) * 130 + 20, 0)
        
        icon.texture = icon:CreateTexture(nil, "ARTWORK")
        icon.texture:SetAllPoints()
        icon.texture:SetTexture("Interface\\AddOns\\DC_Seasons\\Tiers\\" .. tierName)
        
        icon.glow = icon:CreateTexture(nil, "OVERLAY")
        icon.glow:SetPoint("CENTER")
        icon.glow:SetSize(100, 100)
        icon.glow:SetTexture("Interface\\SpellActivationOverlay\\GenericGlow")
        icon.glow:SetVertexColor(unpack(colors[tierName]))
        icon.glow:SetAlpha(0)
        
        icon.label = icon:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        icon.label:SetPoint("BOTTOM", 0, -15)
        icon.label:SetText(tierName)
        
        self.tierIcons[i] = icon
    end
    
    -- Progress bar
    self.progressBar = CreateFrame("StatusBar", nil, self.tierFrame)
    self.progressBar:SetSize(600, 12)
    self.progressBar:SetPoint("BOTTOM", 0, -10)
    self.progressBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    self.progressBar:SetStatusBarColor(0.2, 0.8, 0.2)
    self.progressBar:SetMinMaxValues(0, 100)
    
    self.progressBar.bg = self.progressBar:CreateTexture(nil, "BACKGROUND")
    self.progressBar.bg:SetAllPoints()
    self.progressBar.bg:SetColorTexture(0.1, 0.1, 0.1)
    
    self.progressBar.text = self.progressBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.progressBar.text:SetPoint("CENTER")
end

function SeasonHub:UpdateTierProgress(data)
    -- Highlight achieved tiers
    for i = 1, #self.tierIcons do
        if i <= data.currentTier then
            self.tierIcons[i].glow:SetAlpha(0.6)
            self.tierIcons[i].texture:SetDesaturated(false)
        else
            self.tierIcons[i].glow:SetAlpha(0)
            self.tierIcons[i].texture:SetDesaturated(true)
        end
    end
    
    -- Update progress bar
    self.progressBar:SetValue(data.progressPercent)
    self.progressBar.text:SetText(data.progressText)
end

function SeasonHub:CreateSeasonTimer()
    self.timer = CreateFrame("Frame", nil, self.frame)
    self.timer:SetSize(200, 40)
    self.timer:SetPoint("TOPRIGHT", -20, -20)
    
    self.timer.label = self.timer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.timer.label:SetPoint("TOP")
    self.timer.label:SetText("Season ends in:")
    
    self.timer.time = self.timer:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    self.timer.time:SetPoint("BOTTOM")
    
    -- Update every second
    self.timer:SetScript("OnUpdate", function(frame, elapsed)
        frame.elapsed = (frame.elapsed or 0) + elapsed
        if frame.elapsed >= 1 then
            frame.elapsed = 0
            self:UpdateSeasonTimer()
        end
    end)
end

function SeasonHub:UpdateSeasonTimer()
    local remaining = self.seasonEndTime - time()
    if remaining <= 0 then
        self.timer.time:SetText("|cFFFF0000Season Ended|r")
        return
    end
    
    local days = math.floor(remaining / 86400)
    local hours = math.floor((remaining % 86400) / 3600)
    local mins = math.floor((remaining % 3600) / 60)
    
    if days > 0 then
        self.timer.time:SetText(string.format("%dd %dh %dm", days, hours, mins))
    else
        self.timer.time:SetText(string.format("%dh %dm", hours, mins))
    end
end
```

---

## Season Transition Handling

### End of Season Process
```cpp
void SeasonRewardManager::ProcessSeasonEnd(uint32 seasonId)
{
    LOG_INFO("season", "Processing end of season {}", seasonId);
    
    // 1. Freeze all progress
    FreezeSeasonProgress(seasonId);
    
    // 2. Calculate final standings
    sMythicRating->FinalizeLeaderboard(seasonId);
    
    // 3. Distribute tier rewards to all players
    DistributeFinalRewards(seasonId);
    
    // 4. Grant rank-based exclusive rewards
    DistributeRankRewards(seasonId);
    
    // 5. Archive season data
    ArchiveSeasonProgress(seasonId);
    
    // 6. Announce top players
    AnnounceSeasonWinners(seasonId);
    
    // 7. Lock exclusive content
    LockSeasonExclusiveContent(seasonId);
    
    // 8. Prepare for next season
    uint32 nextSeasonId = GetNextSeasonId(seasonId);
    InitializeNewSeason(nextSeasonId);
    
    LOG_INFO("season", "Season {} processing complete", seasonId);
}

void SeasonRewardManager::DistributeRankRewards(uint32 seasonId)
{
    // Top 1: Unique mount + title "Season X Champion"
    auto top1 = sMythicRating->GetLeaderboard(seasonId, 0, 1);
    if (!top1.empty())
    {
        GrantSpecialReward(top1[0].playerGuid, REWARD_SEASON_CHAMPION_MOUNT);
        GrantTitle(top1[0].playerGuid, TITLE_SEASON_CHAMPION, seasonId);
        RecordRealmFirst("Season Champion", top1[0].playerGuid, seasonId);
    }
    
    // Top 10: Elite title + exclusive transmog
    auto top10 = sMythicRating->GetLeaderboard(seasonId, 0, 10);
    for (const auto& entry : top10)
    {
        GrantTitle(entry.playerGuid, TITLE_SEASON_ELITE, seasonId);
        GrantTransmogSet(entry.playerGuid, GetSeasonEliteTransmogId(seasonId));
    }
    
    // Top 100: Elite achievement
    auto top100 = sMythicRating->GetLeaderboard(seasonId, 0, 100);
    for (const auto& entry : top100)
    {
        GrantAchievement(entry.playerGuid, GetSeasonTop100AchievementId(seasonId));
    }
}
```

---

## Timeline

| Phase | Duration | Tasks |
|-------|----------|-------|
| Schema | 1 day | Database tables |
| Tiers | 3 days | Tier system implementation |
| Milestones | 2 days | Milestone tracking |
| Rewards | 3 days | Reward granting and claiming |
| Theme | 2 days | Season theme system |
| UI | 3 days | AIO season hub |
| Transition | 2 days | End-of-season handling |
| **Total** | **~2.5 weeks** | |

---

## Example Season Configuration

### Season 1: "Frozen Dominion"
```sql
-- Season definition
INSERT INTO dc_seasons (season_id, season_name, theme_name, start_timestamp, end_timestamp) VALUES
(1, 'Frozen Dominion', 'frost', '2025-01-01 00:00:00', '2025-03-31 23:59:59');

-- Tiers
INSERT INTO dc_season_reward_tiers (season_id, tier_name, tier_order, requirement_type, requirement_value, color_hex) VALUES
(1, 'Bronze', 1, 'runs', 10, 'CD7F32'),
(1, 'Silver', 2, 'rating', 1500, 'C0C0C0'),
(1, 'Gold', 3, 'rating', 2500, 'FFD700'),
(1, 'Platinum', 4, 'rating', 3000, 'E5E4E2'),
(1, 'Diamond', 5, 'rank', 100, '00BFFF');

-- Tier rewards
INSERT INTO dc_season_tier_rewards (tier_id, reward_type, reward_entry, display_name) VALUES
(1, 'currency', 1001, '500 Mythic Tokens'),
(1, 'portrait_border', 1, 'Bronze Frame'),
(2, 'transmog', 80001, 'Challenger\'s Cloak'),
(2, 'title', 501, 'Challenger'),
(3, 'mount', 60001, 'Frost Wyrm'),
(3, 'achievement', 20001, 'Season 1 Champion'),
(4, 'item', 70001, 'Frozen Dominion Armor Set'),
(4, 'title', 502, 'Elite'),
(5, 'mount', 60002, 'Glacial Drake'),
(5, 'title', 503, 'Legend');
```
