# Dungeon Quest System Extensions

**Priority:** B-Tier  
**Effort:** Medium (2 weeks)  
**Impact:** Medium-High  
**Target System:** `src/server/scripts/DC/DungeonQuests/`

---

## Current System Analysis

Based on `src/server/scripts/DC/DungeonQuests/` (8 files):
- Daily dungeon quests system
- Quest generation and tracking
- Database persistence
- Integration with dungeon completion

---

## Proposed Extensions

### 1. Dynamic Quest Objectives

Quests with varied objectives beyond simple completion.

```sql
-- Extended quest definitions
CREATE TABLE dc_dungeon_quest_objectives (
    objective_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    quest_id INT UNSIGNED NOT NULL,
    objective_type ENUM(
        'complete',        -- Complete dungeon
        'boss_kill',       -- Kill specific boss
        'speed_run',       -- Complete under time
        'no_deaths',       -- Zero party deaths
        'full_clear',      -- Kill all mobs
        'specific_kill',   -- Kill certain number of mobs
        'collect',         -- Collect items during run
        'bonus_boss',      -- Kill optional boss
        'challenge_mode',  -- Complete with modifier
        'combo'            -- Multiple objectives combined
    ) NOT NULL,
    target_entry INT UNSIGNED DEFAULT 0,  -- Boss/mob entry
    target_count INT UNSIGNED DEFAULT 1,
    time_limit_seconds INT UNSIGNED DEFAULT 0,
    bonus_modifier TEXT,  -- JSON for challenge mode params
    display_text VARCHAR(255),
    FOREIGN KEY (quest_id) REFERENCES dc_dungeon_quests(quest_id)
);

-- Player objective progress
CREATE TABLE dc_dungeon_quest_objective_progress (
    player_guid INT UNSIGNED NOT NULL,
    objective_id INT UNSIGNED NOT NULL,
    current_count INT UNSIGNED DEFAULT 0,
    best_time_seconds INT UNSIGNED DEFAULT 0,
    attempts INT UNSIGNED DEFAULT 0,
    completed BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (player_guid, objective_id)
);
```

```cpp
enum DungeonQuestObjectiveType
{
    OBJECTIVE_COMPLETE = 0,
    OBJECTIVE_BOSS_KILL = 1,
    OBJECTIVE_SPEED_RUN = 2,
    OBJECTIVE_NO_DEATHS = 3,
    OBJECTIVE_FULL_CLEAR = 4,
    OBJECTIVE_SPECIFIC_KILL = 5,
    OBJECTIVE_COLLECT = 6,
    OBJECTIVE_BONUS_BOSS = 7,
    OBJECTIVE_CHALLENGE_MODE = 8,
    OBJECTIVE_COMBO = 9
};

class DungeonQuestObjectiveTracker
{
public:
    void OnDungeonStart(InstanceScript* instance, Group* group)
    {
        uint32 mapId = instance->instance->GetId();
        
        for (auto* member : GetGroupMembers(group))
        {
            auto quests = GetPlayerActiveQuests(member->GetGUID().GetCounter(), mapId);
            
            for (const auto& quest : quests)
            {
                // Initialize tracking for each objective
                for (const auto& obj : quest.objectives)
                {
                    _tracking[member->GetGUID()][obj.objectiveId] = {
                        .startTime = GameTime::GetGameTime().count(),
                        .deaths = 0,
                        .killCount = 0,
                        .collectCount = 0,
                        .mobsKilled = 0
                    };
                }
            }
        }
    }
    
    void OnCreatureKill(Player* player, Creature* creature, InstanceScript* instance)
    {
        auto& tracking = _tracking[player->GetGUID()];
        
        for (auto& [objId, data] : tracking)
        {
            auto objective = GetObjective(objId);
            if (!objective)
                continue;
            
            switch (objective->type)
            {
                case OBJECTIVE_BOSS_KILL:
                    if (creature->GetEntry() == objective->targetEntry)
                    {
                        data.killCount++;
                        CheckCompletion(player, objId);
                    }
                    break;
                    
                case OBJECTIVE_SPECIFIC_KILL:
                    if (objective->targetEntry == 0 || 
                        creature->GetEntry() == objective->targetEntry)
                    {
                        data.killCount++;
                        if (data.killCount >= objective->targetCount)
                            CheckCompletion(player, objId);
                    }
                    break;
                    
                case OBJECTIVE_FULL_CLEAR:
                    data.mobsKilled++;
                    // Check against instance total mob count
                    if (data.mobsKilled >= GetInstanceTotalMobs(instance))
                        CheckCompletion(player, objId);
                    break;
            }
        }
    }
    
    void OnPlayerDeath(Player* player, InstanceScript* instance)
    {
        auto& tracking = _tracking[player->GetGUID()];
        
        for (auto& [objId, data] : tracking)
        {
            data.deaths++;
            
            auto objective = GetObjective(objId);
            if (objective && objective->type == OBJECTIVE_NO_DEATHS)
            {
                // Failed - cannot complete
                MarkObjectiveFailed(player, objId);
            }
        }
    }
    
    void OnDungeonComplete(InstanceScript* instance, Group* group)
    {
        time_t completionTime = GameTime::GetGameTime().count();
        
        for (auto* member : GetGroupMembers(group))
        {
            auto& tracking = _tracking[member->GetGUID()];
            
            for (auto& [objId, data] : tracking)
            {
                auto objective = GetObjective(objId);
                if (!objective)
                    continue;
                
                uint32 duration = completionTime - data.startTime;
                
                switch (objective->type)
                {
                    case OBJECTIVE_COMPLETE:
                        CompleteObjective(member, objId);
                        break;
                        
                    case OBJECTIVE_SPEED_RUN:
                        if (duration <= objective->timeLimitSeconds)
                            CompleteObjective(member, objId);
                        else
                            FailObjective(member, objId, "Time limit exceeded");
                        break;
                        
                    case OBJECTIVE_NO_DEATHS:
                        if (data.deaths == 0)
                            CompleteObjective(member, objId);
                        break;
                }
            }
        }
    }

private:
    struct TrackingData
    {
        time_t startTime;
        uint32 deaths;
        uint32 killCount;
        uint32 collectCount;
        uint32 mobsKilled;
    };
    
    std::unordered_map<ObjectGuid, std::unordered_map<uint32, TrackingData>> _tracking;
};
```

---

### 2. Weekly Dungeon Challenges

Rotating weekly challenges with special rewards.

```sql
CREATE TABLE dc_dungeon_weekly_challenges (
    challenge_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    week_number TINYINT UNSIGNED NOT NULL,  -- 1-52
    dungeon_ids TEXT NOT NULL,  -- JSON array of dungeon map IDs
    challenge_name VARCHAR(100) NOT NULL,
    challenge_type ENUM('speed', 'survival', 'collection', 'achievement') NOT NULL,
    challenge_params TEXT,  -- JSON parameters
    reward_currency INT UNSIGNED DEFAULT 0,
    reward_currency_amount INT UNSIGNED DEFAULT 0,
    reward_item INT UNSIGNED DEFAULT 0,
    reward_item_count INT UNSIGNED DEFAULT 1,
    bonus_reward_threshold INT UNSIGNED DEFAULT 0,  -- Score for bonus
    bonus_reward_item INT UNSIGNED DEFAULT 0
);

CREATE TABLE dc_dungeon_weekly_progress (
    player_guid INT UNSIGNED NOT NULL,
    challenge_id INT UNSIGNED NOT NULL,
    week_start DATE NOT NULL,
    best_score INT UNSIGNED DEFAULT 0,
    attempts INT UNSIGNED DEFAULT 0,
    completed BOOLEAN DEFAULT FALSE,
    bonus_earned BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (player_guid, challenge_id, week_start)
);
```

```cpp
struct WeeklyChallenge
{
    uint32 challengeId;
    std::string name;
    std::vector<uint32> dungeonIds;
    std::string type;
    nlohmann::json params;
    
    uint32 CalculateScore(const DungeonRunResult& result) const
    {
        uint32 score = 0;
        
        if (type == "speed")
        {
            // Base points minus time penalty
            uint32 parTime = params["par_time"].get<uint32>();
            if (result.completionTime <= parTime)
                score = 1000 + (parTime - result.completionTime) * 10;
            else
                score = std::max(0u, 1000 - (result.completionTime - parTime) * 5);
        }
        else if (type == "survival")
        {
            // Points for no deaths, penalty for deaths
            score = 1000 - (result.totalDeaths * 100);
            score = std::max(0u, score);
        }
        else if (type == "collection")
        {
            // Points per collected item
            uint32 targetItem = params["item_id"].get<uint32>();
            score = result.itemsCollected[targetItem] * 100;
        }
        
        return score;
    }
};

class WeeklyChallengeManager
{
public:
    WeeklyChallenge* GetCurrentChallenge()
    {
        // Get week number of year
        time_t now = GameTime::GetGameTime().count();
        tm* timeinfo = localtime(&now);
        uint8 weekNum = (timeinfo->tm_yday / 7) + 1;
        
        return GetChallengeForWeek(weekNum);
    }
    
    void OnDungeonComplete(Player* player, const DungeonRunResult& result)
    {
        auto challenge = GetCurrentChallenge();
        if (!challenge)
            return;
        
        // Check if dungeon is part of challenge
        if (std::find(challenge->dungeonIds.begin(), challenge->dungeonIds.end(),
            result.dungeonId) == challenge->dungeonIds.end())
            return;
        
        uint32 score = challenge->CalculateScore(result);
        
        // Update progress
        UpdateProgress(player->GetGUID().GetCounter(), challenge->challengeId, score);
        
        // Notify player
        player->GetSession()->SendAreaTriggerMessage(
            "|cFF00FF00Weekly Challenge Score:|r %u", score);
    }
};
```

---

### 3. Dungeon Quest Chains

Multi-dungeon quest chains with progressive difficulty.

```sql
CREATE TABLE dc_dungeon_quest_chains (
    chain_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    chain_name VARCHAR(100) NOT NULL,
    chain_description TEXT,
    required_level TINYINT UNSIGNED DEFAULT 80,
    total_steps TINYINT UNSIGNED NOT NULL,
    completion_reward_type ENUM('item', 'currency', 'mount', 'title', 'achievement') NOT NULL,
    completion_reward_entry INT UNSIGNED NOT NULL,
    completion_reward_count INT UNSIGNED DEFAULT 1,
    repeatable BOOLEAN DEFAULT FALSE,
    cooldown_hours INT UNSIGNED DEFAULT 0
);

CREATE TABLE dc_dungeon_quest_chain_steps (
    step_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    chain_id INT UNSIGNED NOT NULL,
    step_order TINYINT UNSIGNED NOT NULL,
    dungeon_id INT UNSIGNED NOT NULL,  -- Map ID
    objective_type ENUM('complete', 'boss', 'speed', 'no_death', 'mythic') NOT NULL,
    objective_params TEXT,
    step_reward_currency INT UNSIGNED DEFAULT 0,
    step_reward_amount INT UNSIGNED DEFAULT 0,
    FOREIGN KEY (chain_id) REFERENCES dc_dungeon_quest_chains(chain_id),
    UNIQUE KEY idx_chain_order (chain_id, step_order)
);

CREATE TABLE dc_dungeon_quest_chain_progress (
    player_guid INT UNSIGNED NOT NULL,
    chain_id INT UNSIGNED NOT NULL,
    current_step TINYINT UNSIGNED DEFAULT 1,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP NULL,
    last_completion TIMESTAMP NULL,
    total_completions INT UNSIGNED DEFAULT 0,
    PRIMARY KEY (player_guid, chain_id)
);
```

#### Example Quest Chain
```sql
-- "The Wrath Tour" - Complete all WotLK heroics in order
INSERT INTO dc_dungeon_quest_chains VALUES 
(1, 'The Wrath Tour', 'Complete all Wrath of the Lich King heroic dungeons', 80, 16, 'mount', 100000, 1, TRUE, 168);

INSERT INTO dc_dungeon_quest_chain_steps (chain_id, step_order, dungeon_id, objective_type, step_reward_currency, step_reward_amount) VALUES
(1, 1, 619, 'complete', 40752, 50),   -- Ahn'kahet
(1, 2, 601, 'complete', 40752, 50),   -- Azjol-Nerub
(1, 3, 600, 'complete', 40752, 50),   -- Drak'Tharon Keep
(1, 4, 604, 'complete', 40752, 50),   -- Gundrak
(1, 5, 602, 'complete', 40752, 50),   -- Halls of Lightning
(1, 6, 599, 'complete', 40752, 50),   -- Halls of Stone
(1, 7, 658, 'complete', 40752, 50),   -- Pit of Saron
(1, 8, 668, 'complete', 40752, 75),   -- Halls of Reflection
(1, 9, 595, 'complete', 40752, 50),   -- Stratholme
(1, 10, 576, 'complete', 40752, 50),  -- Nexus
(1, 11, 578, 'complete', 40752, 50),  -- Oculus
(1, 12, 608, 'complete', 40752, 50),  -- Violet Hold
(1, 13, 574, 'complete', 40752, 50),  -- Utgarde Keep
(1, 14, 575, 'complete', 40752, 75),  -- Utgarde Pinnacle
(1, 15, 632, 'complete', 40752, 75),  -- Forge of Souls
(1, 16, 650, 'mythic', 40752, 100);   -- Trial of the Champion (M+)
```

---

### 4. Bonus Objectives

Optional objectives during dungeon runs for extra rewards.

```sql
CREATE TABLE dc_dungeon_bonus_objectives (
    bonus_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    dungeon_id INT UNSIGNED NOT NULL,
    bonus_name VARCHAR(100) NOT NULL,
    bonus_type ENUM('hidden_boss', 'secret_path', 'speed_segment', 'collection', 'puzzle') NOT NULL,
    trigger_conditions TEXT,  -- JSON
    reward_type ENUM('currency', 'item', 'buff', 'xp') NOT NULL,
    reward_entry INT UNSIGNED NOT NULL,
    reward_count INT UNSIGNED DEFAULT 1,
    hidden BOOLEAN DEFAULT TRUE,  -- Not shown until discovered
    one_time_per_run BOOLEAN DEFAULT TRUE
);

CREATE TABLE dc_dungeon_bonus_discoveries (
    player_guid INT UNSIGNED NOT NULL,
    bonus_id INT UNSIGNED NOT NULL,
    discovered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    times_completed INT UNSIGNED DEFAULT 0,
    PRIMARY KEY (player_guid, bonus_id)
);
```

```cpp
class BonusObjectiveManager
{
public:
    void CheckBonusTriggers(InstanceScript* instance, Player* player, 
        const std::string& triggerType, uint32 param = 0)
    {
        uint32 dungeonId = instance->instance->GetId();
        auto bonuses = GetBonusesForDungeon(dungeonId);
        
        for (const auto& bonus : bonuses)
        {
            if (_completedThisRun[instance->instance->GetInstanceId()].count(bonus.bonusId))
                continue;
            
            if (CheckTriggerConditions(bonus, triggerType, param, player))
            {
                DiscoverBonus(player, bonus);
                
                if (bonus.oneTimePerRun)
                    _completedThisRun[instance->instance->GetInstanceId()].insert(bonus.bonusId);
            }
        }
    }
    
    void DiscoverBonus(Player* player, const BonusObjective& bonus)
    {
        ObjectGuid::LowType guid = player->GetGUID().GetCounter();
        
        // Check if already discovered
        bool firstTime = !HasDiscovered(guid, bonus.bonusId);
        
        // Grant reward
        GrantReward(player, bonus.rewardType, bonus.rewardEntry, bonus.rewardCount);
        
        // Update database
        CharacterDatabase.Execute(
            "INSERT INTO dc_dungeon_bonus_discoveries "
            "(player_guid, bonus_id, times_completed) VALUES ({}, {}, 1) "
            "ON DUPLICATE KEY UPDATE times_completed = times_completed + 1",
            guid, bonus.bonusId);
        
        // Announce
        std::string message = firstTime 
            ? Acore::StringFormat("|cFFFFD700Bonus Discovered:|r %s", bonus.bonusName.c_str())
            : Acore::StringFormat("|cFF00FF00Bonus Complete:|r %s", bonus.bonusName.c_str());
        
        player->GetSession()->SendAreaTriggerMessage("%s", message.c_str());
    }

private:
    bool CheckTriggerConditions(const BonusObjective& bonus, 
        const std::string& triggerType, uint32 param, Player* player)
    {
        auto conditions = nlohmann::json::parse(bonus.triggerConditions);
        
        if (conditions["type"].get<std::string>() != triggerType)
            return false;
        
        switch (bonus.bonusType)
        {
            case BONUS_HIDDEN_BOSS:
                return param == conditions["boss_entry"].get<uint32>();
                
            case BONUS_SECRET_PATH:
                return IsNearPosition(player, 
                    conditions["x"].get<float>(),
                    conditions["y"].get<float>(),
                    conditions["z"].get<float>(),
                    conditions.value("radius", 10.0f));
                
            case BONUS_SPEED_SEGMENT:
                // Check if player reached point within time
                return CheckSpeedSegment(player, conditions);
                
            case BONUS_COLLECTION:
                return param == conditions["item_id"].get<uint32>() &&
                       player->GetItemCount(param) >= conditions["count"].get<uint32>();
                
            default:
                return false;
        }
    }
};
```

---

### 5. Quest Reward Scaling

Dynamic reward scaling based on difficulty and performance.

```cpp
struct QuestRewardScaling
{
    float baseMultiplier = 1.0f;
    float speedBonus = 0.0f;      // Bonus for fast completion
    float noDeathBonus = 0.0f;    // Bonus for zero deaths
    float mythicMultiplier = 1.0f; // Mythic+ scaling
    float prestigeBonus = 0.0f;    // Prestige level bonus
    float groupSizeBonus = 0.0f;   // Full group bonus
};

class QuestRewardCalculator
{
public:
    QuestRewardScaling CalculateScaling(Player* player, const DungeonRunResult& result)
    {
        QuestRewardScaling scaling;
        
        // Speed bonus - up to 25% for beating par time
        uint32 parTime = GetParTime(result.dungeonId);
        if (parTime > 0 && result.completionTime < parTime)
        {
            float speedRatio = 1.0f - (float(result.completionTime) / float(parTime));
            scaling.speedBonus = std::min(0.25f, speedRatio * 0.5f);
        }
        
        // No death bonus - 15% for zero deaths
        if (result.totalDeaths == 0)
            scaling.noDeathBonus = 0.15f;
        
        // Mythic+ scaling - 10% per key level
        if (result.mythicLevel > 0)
            scaling.mythicMultiplier = 1.0f + (result.mythicLevel * 0.10f);
        
        // Prestige bonus - 2% per prestige level
        uint8 prestige = sPrestige->GetPrestige(player->GetGUID().GetCounter());
        scaling.prestigeBonus = prestige * 0.02f;
        
        // Group size bonus - 10% for full group
        if (result.groupSize >= 5)
            scaling.groupSizeBonus = 0.10f;
        
        // Calculate total multiplier
        scaling.baseMultiplier = 1.0f + scaling.speedBonus + scaling.noDeathBonus +
                                  scaling.prestigeBonus + scaling.groupSizeBonus;
        scaling.baseMultiplier *= scaling.mythicMultiplier;
        
        return scaling;
    }
    
    void ApplyScaling(Player* player, DungeonQuestReward& reward, 
        const QuestRewardScaling& scaling)
    {
        if (reward.currencyAmount > 0)
            reward.currencyAmount = uint32(reward.currencyAmount * scaling.baseMultiplier);
        
        if (reward.xpAmount > 0)
            reward.xpAmount = uint32(reward.xpAmount * scaling.baseMultiplier);
        
        // Item quantity doesn't scale, but bonus items may be added
        if (scaling.baseMultiplier >= 1.5f && reward.bonusItemChance > 0)
        {
            if (roll_chance_f(reward.bonusItemChance * (scaling.baseMultiplier - 1.0f) * 100))
                reward.bonusItemCount++;
        }
    }
};
```

---

### 6. Quest Progress UI

Enhanced addon interface for quest tracking.

```lua
-- DungeonQuestTracker.lua
local QuestFrame = AIO.AddAddon()

function QuestFrame:Init()
    -- Main frame
    self.frame = CreateFrame("Frame", "DCDungeonQuests", UIParent)
    self.frame:SetSize(250, 300)
    self.frame:SetPoint("RIGHT", -10, 0)
    
    -- Header
    self.header = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    self.header:SetPoint("TOP", 0, -10)
    self.header:SetText("Dungeon Quests")
    
    -- Daily quests section
    self:CreateSection("Daily", -35, 3)
    
    -- Weekly challenge section
    self:CreateSection("Weekly", -150, 1)
    
    -- Chain progress section
    self:CreateSection("Chain", -220, 1)
end

function QuestFrame:CreateSection(name, yOffset, count)
    self[name:lower()] = {}
    
    local header = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", 10, yOffset)
    header:SetText("|cFFFFD700" .. name .. "|r")
    
    for i = 1, count do
        local row = CreateFrame("Frame", nil, self.frame)
        row:SetSize(230, 30)
        row:SetPoint("TOPLEFT", 10, yOffset - 20 - (i-1) * 35)
        
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(24, 24)
        row.icon:SetPoint("LEFT")
        
        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 5, 5)
        row.name:SetWidth(140)
        row.name:SetJustifyH("LEFT")
        
        row.progress = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.progress:SetPoint("LEFT", row.icon, "RIGHT", 5, -8)
        
        row.reward = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.reward:SetPoint("RIGHT")
        row.reward:SetTextColor(1, 0.82, 0)
        
        -- Progress bar
        row.bar = CreateFrame("StatusBar", nil, row)
        row.bar:SetSize(140, 8)
        row.bar:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 5, 0)
        row.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        row.bar:SetStatusBarColor(0.2, 0.8, 0.2)
        row.bar.bg = row.bar:CreateTexture(nil, "BACKGROUND")
        row.bar.bg:SetAllPoints()
        row.bar.bg:SetColorTexture(0.2, 0.2, 0.2)
        
        self[name:lower()][i] = row
    end
end

function QuestFrame:UpdateDaily(quests)
    for i, row in ipairs(self.daily) do
        local quest = quests[i]
        if quest then
            row:Show()
            row.icon:SetTexture(quest.icon)
            row.name:SetText(quest.name)
            row.progress:SetText(string.format("%d/%d", quest.current, quest.target))
            row.reward:SetText(quest.reward)
            row.bar:SetMinMaxValues(0, quest.target)
            row.bar:SetValue(quest.current)
            
            if quest.current >= quest.target then
                row.bar:SetStatusBarColor(0, 1, 0)
            else
                row.bar:SetStatusBarColor(0.2, 0.8, 0.2)
            end
        else
            row:Hide()
        end
    end
end

function QuestFrame:UpdateWeekly(challenge)
    local row = self.weekly[1]
    if challenge then
        row:Show()
        row.icon:SetTexture(challenge.icon)
        row.name:SetText(challenge.name)
        row.progress:SetText(string.format("Score: %d", challenge.score))
        row.reward:SetText(challenge.reward)
        row.bar:SetMinMaxValues(0, challenge.maxScore)
        row.bar:SetValue(challenge.score)
    else
        row:Hide()
    end
end

function QuestFrame:UpdateChain(chain)
    local row = self.chain[1]
    if chain then
        row:Show()
        row.icon:SetTexture(chain.icon)
        row.name:SetText(chain.name)
        row.progress:SetText(string.format("Step %d/%d", chain.currentStep, chain.totalSteps))
        row.reward:SetText(chain.reward)
        row.bar:SetMinMaxValues(0, chain.totalSteps)
        row.bar:SetValue(chain.currentStep - 1)
    else
        row:Hide()
    end
end
```

---

## GM Commands

```cpp
// .dungeonquest objective add <quest_id> <type> [params]
// .dungeonquest objective list <quest_id>
// .dungeonquest chain create <name> <reward_type> <reward_id>
// .dungeonquest chain addstep <chain_id> <dungeon_id> <objective>
// .dungeonquest weekly set <week> <challenge_id>
// .dungeonquest bonus add <dungeon_id> <name> <type> <reward>
// .dungeonquest bonus trigger <player> <bonus_id>
// .dungeonquest progress <player> [quest_id]
// .dungeonquest reset <player> [quest_id]
```

---

## Timeline

| Phase | Duration | Tasks |
|-------|----------|-------|
| Objectives | 3 days | Dynamic objective system |
| Weekly | 2 days | Challenge rotation |
| Chains | 3 days | Multi-dungeon chains |
| Bonus | 2 days | Hidden objectives |
| Scaling | 2 days | Reward calculation |
| UI | 2 days | Addon interface |
| Testing | 2 days | Full integration |
| **Total** | **~2.5 weeks** | |

---

## Integration Points

- **Mythic+**: M+ runs count for quest objectives
- **Seasons**: Seasonal quest chains
- **Prestige**: Prestige affects reward scaling
- **ItemUpgrades**: Upgrade materials as rewards
- **Hotspots**: Bonus objectives in dungeon hotspots
