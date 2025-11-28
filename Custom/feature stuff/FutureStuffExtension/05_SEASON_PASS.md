# Season Pass / Battle Pass Implementation

**Priority:** A-Tier  
**Effort:** High (3-4 weeks)  
**Impact:** High  
**Target System:** `src/server/scripts/DC/Seasons/`

---

## Overview

Modern battle pass system with free and premium tracks, daily/weekly challenges, and progressive reward unlocks. Integrates with existing seasonal framework.

---

## Design Philosophy

### Core Principles
1. **Fair Free Track** - Meaningful rewards without purchase
2. **Time-Respecting** - Achievable without excessive grinding
3. **Catch-Up Friendly** - Late starters can still complete
4. **Alt-Friendly** - Account-wide progress options

### Pass Structure
- **100 Levels** total per season
- **Free Track** - Currencies, consumables, basic cosmetics
- **Premium Track** - Exclusive mounts, transmog, titles
- **XP Required** - Increasing per level (25,000 → 50,000)

---

## Database Schema

```sql
-- Season pass definitions
CREATE TABLE dc_season_pass (
    pass_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    season_id INT UNSIGNED NOT NULL,
    pass_name VARCHAR(100) NOT NULL,
    max_level TINYINT UNSIGNED DEFAULT 100,
    xp_base INT UNSIGNED DEFAULT 25000,
    xp_per_level INT UNSIGNED DEFAULT 250,  -- Additional XP needed per level
    premium_item_id INT UNSIGNED DEFAULT 0,  -- Item that grants premium
    premium_price INT UNSIGNED DEFAULT 0,    -- Cost in custom currency
    starts_at TIMESTAMP NOT NULL,
    ends_at TIMESTAMP NOT NULL,
    catch_up_multiplier FLOAT DEFAULT 1.0,  -- XP boost in final weeks
    FOREIGN KEY (season_id) REFERENCES dc_seasons(season_id)
);

-- Pass reward tracks
CREATE TABLE dc_season_pass_rewards (
    reward_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    pass_id INT UNSIGNED NOT NULL,
    level_required TINYINT UNSIGNED NOT NULL,
    track ENUM('free', 'premium') NOT NULL,
    reward_type ENUM('item', 'currency', 'mount', 'pet', 'title', 'transmog', 'achievement', 'experience') NOT NULL,
    reward_entry INT UNSIGNED NOT NULL,
    reward_count INT UNSIGNED DEFAULT 1,
    display_name VARCHAR(100),
    icon_path VARCHAR(255),
    is_featured BOOLEAN DEFAULT FALSE,  -- Show in marketing
    FOREIGN KEY (pass_id) REFERENCES dc_season_pass(pass_id),
    KEY idx_pass_level (pass_id, level_required)
);

-- Player pass progress
CREATE TABLE dc_season_pass_progress (
    player_guid INT UNSIGNED NOT NULL,
    pass_id INT UNSIGNED NOT NULL,
    current_level TINYINT UNSIGNED DEFAULT 1,
    current_xp INT UNSIGNED DEFAULT 0,
    is_premium BOOLEAN DEFAULT FALSE,
    premium_purchased_at TIMESTAMP NULL,
    last_xp_gain TIMESTAMP NULL,
    total_xp_earned BIGINT UNSIGNED DEFAULT 0,
    PRIMARY KEY (player_guid, pass_id),
    FOREIGN KEY (pass_id) REFERENCES dc_season_pass(pass_id)
);

-- Claimed rewards tracking
CREATE TABLE dc_season_pass_claims (
    player_guid INT UNSIGNED NOT NULL,
    reward_id INT UNSIGNED NOT NULL,
    claimed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (player_guid, reward_id),
    FOREIGN KEY (reward_id) REFERENCES dc_season_pass_rewards(reward_id)
);

-- Daily/Weekly challenges
CREATE TABLE dc_season_pass_challenges (
    challenge_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    pass_id INT UNSIGNED NOT NULL,
    challenge_type ENUM('daily', 'weekly', 'seasonal') NOT NULL,
    challenge_name VARCHAR(100) NOT NULL,
    challenge_description TEXT,
    objective_type ENUM('kills', 'dungeons', 'bgs', 'quests', 'mythic_plus', 'boss_kills', 'gathering', 'crafting', 'pvp_kills', 'achievements') NOT NULL,
    objective_target INT UNSIGNED NOT NULL,
    objective_params TEXT,  -- JSON for specific requirements
    xp_reward INT UNSIGNED NOT NULL,
    bonus_reward_type ENUM('item', 'currency') DEFAULT NULL,
    bonus_reward_entry INT UNSIGNED DEFAULT 0,
    bonus_reward_count INT UNSIGNED DEFAULT 0,
    pool_id TINYINT UNSIGNED DEFAULT 0,  -- For random selection from pool
    weight INT UNSIGNED DEFAULT 100,  -- Selection weight within pool
    FOREIGN KEY (pass_id) REFERENCES dc_season_pass(pass_id)
);

-- Player challenge progress
CREATE TABLE dc_season_pass_challenge_progress (
    player_guid INT UNSIGNED NOT NULL,
    challenge_id INT UNSIGNED NOT NULL,
    assigned_at TIMESTAMP NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    current_progress INT UNSIGNED DEFAULT 0,
    completed BOOLEAN DEFAULT FALSE,
    completed_at TIMESTAMP NULL,
    claimed BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (player_guid, challenge_id, assigned_at),
    FOREIGN KEY (challenge_id) REFERENCES dc_season_pass_challenges(challenge_id)
);
```

---

## XP System

### XP Per Level Calculation
```cpp
uint32 SeasonPassManager::GetXPForLevel(uint32 passId, uint8 level)
{
    auto pass = GetPass(passId);
    if (!pass)
        return 0;
    
    // Formula: base + (level * perLevel)
    // Level 1: 25000
    // Level 50: 25000 + (50 * 250) = 37500
    // Level 100: 25000 + (100 * 250) = 50000
    return pass->xpBase + (level * pass->xpPerLevel);
}

uint32 SeasonPassManager::GetTotalXPForLevel(uint32 passId, uint8 targetLevel)
{
    uint32 total = 0;
    for (uint8 lvl = 1; lvl < targetLevel; ++lvl)
        total += GetXPForLevel(passId, lvl);
    return total;
}
```

### XP Sources
| Source | XP Amount | Frequency |
|--------|-----------|-----------|
| Daily Login | 500 | Once/day |
| Daily Challenge | 2,500-5,000 | 3/day |
| Weekly Challenge | 15,000-25,000 | 3/week |
| M+ Completion | 1,000 * key level | Per run |
| Dungeon Boss | 500 | Per boss |
| BG Win | 2,000 | Per win |
| BG Loss | 750 | Per loss |
| World Boss | 5,000 | Weekly |
| Achievement | 1,000-10,000 | One-time |

---

## Challenge System

### Daily Challenge Examples
```sql
INSERT INTO dc_season_pass_challenges (pass_id, challenge_type, challenge_name, objective_type, objective_target, xp_reward, pool_id) VALUES
(1, 'daily', 'Dungeon Delver', 'dungeons', 2, 3000, 1),
(1, 'daily', 'Monster Slayer', 'kills', 50, 2500, 1),
(1, 'daily', 'Battleground Hero', 'bgs', 1, 3000, 1),
(1, 'daily', 'Key Master', 'mythic_plus', 1, 4000, 1),
(1, 'daily', 'Quest Champion', 'quests', 5, 2500, 1);
```

### Weekly Challenge Examples
```sql
INSERT INTO dc_season_pass_challenges (pass_id, challenge_type, challenge_name, objective_type, objective_target, objective_params, xp_reward, pool_id) VALUES
(1, 'weekly', 'Mythic Challenger', 'mythic_plus', 5, '{"min_level": 10}', 20000, 2),
(1, 'weekly', 'Boss Hunter', 'boss_kills', 20, NULL, 15000, 2),
(1, 'weekly', 'PvP Veteran', 'bgs', 10, NULL, 18000, 2),
(1, 'weekly', 'High Key Runner', 'mythic_plus', 1, '{"min_level": 18}', 25000, 2);
```

### Challenge Assignment
```cpp
void SeasonPassManager::AssignDailyChallenges(uint32 playerGuid, uint32 passId)
{
    // Get available daily challenges for this pass
    auto challenges = GetChallengesInPool(passId, CHALLENGE_DAILY, 1);  // Pool 1
    
    // Randomly select 3 challenges, weighted
    std::vector<Challenge*> selected;
    uint32 totalWeight = 0;
    for (auto& ch : challenges)
        totalWeight += ch.weight;
    
    for (int i = 0; i < 3 && !challenges.empty(); ++i)
    {
        uint32 roll = urand(0, totalWeight);
        uint32 cumulative = 0;
        
        for (auto it = challenges.begin(); it != challenges.end(); ++it)
        {
            cumulative += it->weight;
            if (roll <= cumulative)
            {
                selected.push_back(&(*it));
                totalWeight -= it->weight;
                challenges.erase(it);
                break;
            }
        }
    }
    
    // Assign selected challenges
    time_t now = GameTime::GetGameTime().count();
    time_t expires = GetNextDailyReset();
    
    for (auto* ch : selected)
    {
        AssignChallenge(playerGuid, ch->challengeId, now, expires);
    }
}
```

---

## Season Pass Manager

```cpp
class SeasonPassManager
{
public:
    static SeasonPassManager* instance();

    // Pass lifecycle
    bool CreatePass(const SeasonPassDefinition& def);
    SeasonPass* GetActivePass();
    SeasonPass* GetPass(uint32 passId);
    
    // Player progress
    bool AddXP(ObjectGuid::LowType playerGuid, uint32 amount, const std::string& source);
    bool SetPremium(ObjectGuid::LowType playerGuid, bool premium);
    PlayerPassProgress* GetProgress(ObjectGuid::LowType playerGuid, uint32 passId);
    
    // Rewards
    std::vector<PassReward*> GetAvailableRewards(ObjectGuid::LowType playerGuid, uint32 passId);
    std::vector<PassReward*> GetUnclaimedRewards(ObjectGuid::LowType playerGuid, uint32 passId);
    bool ClaimReward(ObjectGuid::LowType playerGuid, uint32 rewardId);
    bool ClaimAllRewards(ObjectGuid::LowType playerGuid, uint32 passId);
    
    // Challenges
    void AssignDailyChallenges(uint32 playerGuid, uint32 passId);
    void AssignWeeklyChallenges(uint32 playerGuid, uint32 passId);
    bool UpdateChallengeProgress(ObjectGuid::LowType playerGuid, ChallengeType type, uint32 amount, const std::string& params = "");
    std::vector<ChallengeProgress> GetActiveChallenges(ObjectGuid::LowType playerGuid);
    bool ClaimChallengeReward(ObjectGuid::LowType playerGuid, uint32 challengeId);
    
    // Catch-up mechanics
    float GetCatchUpMultiplier(uint32 passId);
    uint32 CalculateXPWithCatchUp(uint32 baseXP, uint32 passId);
    
    // Scheduled tasks
    void ProcessDailyReset();
    void ProcessWeeklyReset();
    void ProcessPassEnd(uint32 passId);

private:
    SeasonPassManager();
    
    void NotifyLevelUp(Player* player, uint8 oldLevel, uint8 newLevel);
    void GrantLevelRewards(Player* player, uint8 level, bool premium);
    
    std::unordered_map<uint32, std::unique_ptr<SeasonPass>> _passes;
};

#define sSeasonPass SeasonPassManager::instance()
```

### XP Addition with Level-Up
```cpp
bool SeasonPassManager::AddXP(ObjectGuid::LowType playerGuid, uint32 amount, const std::string& source)
{
    auto pass = GetActivePass();
    if (!pass)
        return false;
    
    auto progress = GetProgress(playerGuid, pass->passId);
    if (!progress)
        progress = CreateProgress(playerGuid, pass->passId);
    
    // Apply catch-up multiplier
    amount = CalculateXPWithCatchUp(amount, pass->passId);
    
    progress->currentXp += amount;
    progress->totalXpEarned += amount;
    progress->lastXpGain = GameTime::GetGameTime().count();
    
    // Check for level ups
    uint8 oldLevel = progress->currentLevel;
    while (progress->currentLevel < pass->maxLevel)
    {
        uint32 xpNeeded = GetXPForLevel(pass->passId, progress->currentLevel);
        if (progress->currentXp >= xpNeeded)
        {
            progress->currentXp -= xpNeeded;
            progress->currentLevel++;
        }
        else
            break;
    }
    
    // Cap XP at max level
    if (progress->currentLevel >= pass->maxLevel)
        progress->currentXp = 0;
    
    // Save progress
    SaveProgress(playerGuid, pass->passId);
    
    // Notify player
    if (Player* player = ObjectAccessor::FindPlayer(ObjectGuid(HighGuid::Player, playerGuid)))
    {
        // Send XP gain notification
        SendXPGainNotification(player, amount, source);
        
        // Handle level ups
        if (progress->currentLevel > oldLevel)
        {
            NotifyLevelUp(player, oldLevel, progress->currentLevel);
            
            // Grant rewards for each level gained
            for (uint8 lvl = oldLevel + 1; lvl <= progress->currentLevel; ++lvl)
                GrantLevelRewards(player, lvl, progress->isPremium);
        }
    }
    
    return true;
}
```

---

## Challenge Progress Tracking

### Hook Into Game Events
```cpp
class SeasonPassPlayerScript : public PlayerScript
{
public:
    SeasonPassPlayerScript() : PlayerScript("SeasonPassPlayerScript") { }

    void OnCreatureKill(Player* player, Creature* creature) override
    {
        if (!creature || creature->IsPet())
            return;
        
        sSeasonPass->UpdateChallengeProgress(player->GetGUID().GetCounter(),
            CHALLENGE_KILLS, 1);
        
        if (creature->IsDungeonBoss())
        {
            sSeasonPass->UpdateChallengeProgress(player->GetGUID().GetCounter(),
                CHALLENGE_BOSS_KILLS, 1);
        }
    }

    void OnMapChanged(Player* player) override
    {
        // Check dungeon completion
        Map* map = player->GetMap();
        if (map && map->IsDungeon() && !player->IsInWorld())
        {
            // Player leaving completed dungeon
            sSeasonPass->UpdateChallengeProgress(player->GetGUID().GetCounter(),
                CHALLENGE_DUNGEONS, 1);
        }
    }

    void OnPVPKill(Player* killer, Player* /*killed*/) override
    {
        sSeasonPass->UpdateChallengeProgress(killer->GetGUID().GetCounter(),
            CHALLENGE_PVP_KILLS, 1);
    }
};

// Hook into M+ completion
void MythicPlusRunManager::CompleteRun(Map* map, bool successful)
{
    // ... existing code ...
    
    if (successful)
    {
        for (auto& guid : state->participants)
        {
            std::string params = Acore::StringFormat("{{\"level\":{}}}", state->keystoneLevel);
            sSeasonPass->UpdateChallengeProgress(guid, CHALLENGE_MYTHIC_PLUS, 1, params);
            
            // XP reward
            uint32 xp = 1000 * state->keystoneLevel;
            sSeasonPass->AddXP(guid, xp, "Mythic+ Completion");
        }
    }
}
```

---

## Reward Track Preview

### Season 1 Example
| Level | Free Track | Premium Track |
|-------|------------|---------------|
| 1 | 1000 Tokens | Exclusive Portrait |
| 5 | Consumable Pack | Transmog Helm |
| 10 | 2000 Tokens | Transmog Shoulders |
| 15 | Health Potion x20 | Transmog Chest |
| 20 | 3000 Tokens | Pet: Season Companion |
| 25 | Toy: Campfire | Transmog Gloves |
| 30 | 4000 Tokens | Transmog Belt |
| 35 | XP Boost Scroll | Transmog Legs |
| 40 | 5000 Tokens | Transmog Boots |
| 45 | Flask x10 | Transmog Cloak |
| 50 | **Mount: Basic** | **Mount: Premium** |
| 60 | 7500 Tokens | Weapon Transmog |
| 70 | Consumable Bundle | Title: "Season Champion" |
| 80 | 10000 Tokens | Unique Aura Effect |
| 90 | Toy: Banner | Achievement: Season Dedication |
| 100 | **Title: Dedicated** | **Mount: Prestige** + Full Set |

---

## AIO Addon Interface

```lua
-- SeasonPass.lua
local PassFrame = AIO.AddAddon()

function PassFrame:Init()
    self.frame = CreateFrame("Frame", "DCSeasonPass", UIParent)
    self.frame:SetSize(900, 600)
    self.frame:SetPoint("CENTER")
    
    -- Level progress bar
    self:CreateLevelBar()
    
    -- Reward track display
    self:CreateRewardTrack()
    
    -- Challenge panel
    self:CreateChallengePanel()
    
    -- Premium purchase button
    self:CreatePremiumButton()
end

function PassFrame:CreateRewardTrack()
    self.trackFrame = CreateFrame("ScrollFrame", nil, self.frame, "UIPanelScrollFrameTemplate")
    self.trackFrame:SetSize(860, 300)
    self.trackFrame:SetPoint("CENTER", 0, -50)
    
    self.trackContent = CreateFrame("Frame", nil, self.trackFrame)
    self.trackContent:SetSize(860 * 2, 300)  -- Wide for scrolling
    self.trackFrame:SetScrollChild(self.trackContent)
    
    -- Create level nodes
    self.levelNodes = {}
    for i = 1, 100 do
        local node = self:CreateLevelNode(i)
        node:SetPoint("LEFT", (i - 1) * 80, 0)
        self.levelNodes[i] = node
    end
end

function PassFrame:CreateLevelNode(level)
    local node = CreateFrame("Frame", nil, self.trackContent)
    node:SetSize(70, 280)
    
    -- Level number
    node.levelText = node:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    node.levelText:SetPoint("TOP", 0, -5)
    node.levelText:SetText(level)
    
    -- Free track reward
    node.freeReward = CreateFrame("Button", nil, node)
    node.freeReward:SetSize(50, 50)
    node.freeReward:SetPoint("TOP", 0, -30)
    node.freeReward.icon = node.freeReward:CreateTexture(nil, "ARTWORK")
    node.freeReward.icon:SetAllPoints()
    node.freeReward.border = node.freeReward:CreateTexture(nil, "OVERLAY")
    node.freeReward.border:SetPoint("CENTER")
    node.freeReward.border:SetSize(54, 54)
    
    -- Premium track reward
    node.premiumReward = CreateFrame("Button", nil, node)
    node.premiumReward:SetSize(50, 50)
    node.premiumReward:SetPoint("TOP", 0, -100)
    node.premiumReward.icon = node.premiumReward:CreateTexture(nil, "ARTWORK")
    node.premiumReward.icon:SetAllPoints()
    node.premiumReward.border = node.premiumReward:CreateTexture(nil, "OVERLAY")
    node.premiumReward.border:SetPoint("CENTER")
    node.premiumReward.border:SetSize(54, 54)
    node.premiumReward.lock = node.premiumReward:CreateTexture(nil, "OVERLAY")
    node.premiumReward.lock:SetPoint("CENTER")
    node.premiumReward.lock:SetSize(20, 20)
    node.premiumReward.lock:SetTexture("Interface\\PetBattles\\PetBattle-LockIcon")
    
    -- Connection line
    if level < 100 then
        node.connector = node:CreateTexture(nil, "BACKGROUND")
        node.connector:SetPoint("LEFT", node, "RIGHT", 0, 0)
        node.connector:SetSize(10, 4)
        node.connector:SetColorTexture(0.5, 0.5, 0.5)
    end
    
    return node
end

function PassFrame:UpdateProgress(data)
    -- Update level bar
    self.levelBar:SetMinMaxValues(0, data.xpNeeded)
    self.levelBar:SetValue(data.currentXp)
    self.levelText:SetText("Level " .. data.currentLevel .. " / 100")
    self.xpText:SetText(data.currentXp .. " / " .. data.xpNeeded .. " XP")
    
    -- Update reward nodes
    for i, node in ipairs(self.levelNodes) do
        if i <= data.currentLevel then
            -- Unlocked
            node.freeReward.icon:SetDesaturated(false)
            if data.isPremium then
                node.premiumReward.icon:SetDesaturated(false)
                node.premiumReward.lock:Hide()
            end
            
            -- Check if claimed
            if data.claimedFree[i] then
                node.freeReward.border:SetTexture("Interface\\Buttons\\CheckButtonHilight")
            end
        else
            -- Locked
            node.freeReward.icon:SetDesaturated(true)
            node.premiumReward.icon:SetDesaturated(true)
            if not data.isPremium then
                node.premiumReward.lock:Show()
            end
        end
    end
    
    -- Scroll to current level
    local scrollPos = math.max(0, (data.currentLevel - 5) * 80)
    self.trackFrame:SetHorizontalScroll(scrollPos)
end

function PassFrame:CreateChallengePanel()
    self.challengePanel = CreateFrame("Frame", nil, self.frame)
    self.challengePanel:SetSize(300, 200)
    self.challengePanel:SetPoint("BOTTOMRIGHT", -20, 20)
    
    self.challengePanel.title = self.challengePanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    self.challengePanel.title:SetPoint("TOP")
    self.challengePanel.title:SetText("Challenges")
    
    -- Daily challenges
    self.dailyHeader = self.challengePanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.dailyHeader:SetPoint("TOPLEFT", 10, -30)
    self.dailyHeader:SetText("|cFFFFD700Daily|r")
    
    self.dailyChallenges = {}
    for i = 1, 3 do
        local ch = self:CreateChallengeRow(self.challengePanel, i)
        ch:SetPoint("TOPLEFT", 10, -50 - (i-1) * 25)
        self.dailyChallenges[i] = ch
    end
    
    -- Weekly challenges
    self.weeklyHeader = self.challengePanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.weeklyHeader:SetPoint("TOPLEFT", 10, -135)
    self.weeklyHeader:SetText("|cFF00BFFFWeekly|r")
    
    self.weeklyChallenges = {}
    for i = 1, 3 do
        local ch = self:CreateChallengeRow(self.challengePanel, i + 3)
        ch:SetPoint("TOPLEFT", 10, -155 - (i-1) * 25)
        self.weeklyChallenges[i] = ch
    end
end
```

---

## Timeline

| Phase | Duration | Tasks |
|-------|----------|-------|
| Schema | 2 days | Database tables, sample data |
| Core | 5 days | PassManager, XP system |
| Challenges | 4 days | Challenge assignment, tracking |
| Rewards | 3 days | Reward claiming, distribution |
| Hooks | 3 days | Game event integration |
| UI | 5 days | AIO addon pass interface |
| Testing | 4 days | Full pass progression test |
| **Total** | **~3.5 weeks** | |

---

## Future Enhancements

1. **Prestige Pass** - Restart pass for bonus rewards
2. **Gift Pass** - Purchase premium for other players
3. **Challenge Rerolls** - Skip unwanted challenges
4. **XP Boost Items** - Temporary XP multipliers
5. **Retroactive Premium** - Claim all passed premium rewards
