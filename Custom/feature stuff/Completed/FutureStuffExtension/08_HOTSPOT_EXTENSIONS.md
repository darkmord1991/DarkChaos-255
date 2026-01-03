# Hotspots System Extensions

**Priority:** B-Tier  
**Effort:** Medium (2 weeks)  
**Impact:** Medium-High  
**Target System:** `src/server/scripts/DC/Hotspot/`

---

## Current System Analysis

Based on `ac_hotspots.cpp` (3256 lines):
- XP bonus zones with configurable rates
- Anti-camping protection (tier-based cooldowns)
- Visual markers and effects
- Addon packets for client display
- Database persistence per player
- Zone filtering support

---

## Proposed Extensions

### 1. Dynamic Hotspots

Hotspots that spawn based on server conditions.

```sql
-- Dynamic hotspot definitions
CREATE TABLE dc_hotspot_dynamic (
    hotspot_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    spawn_type ENUM('time_based', 'population', 'event', 'random', 'chain') NOT NULL,
    map_id INT UNSIGNED NOT NULL,
    zone_id INT UNSIGNED NOT NULL,
    area_id INT UNSIGNED DEFAULT 0,
    center_x FLOAT NOT NULL,
    center_y FLOAT NOT NULL,
    center_z FLOAT NOT NULL,
    radius FLOAT DEFAULT 50.0,
    xp_multiplier FLOAT DEFAULT 2.0,
    drop_multiplier FLOAT DEFAULT 1.0,
    spawn_chance FLOAT DEFAULT 100.0,  -- % chance when conditions met
    duration_minutes INT UNSIGNED DEFAULT 30,
    cooldown_minutes INT UNSIGNED DEFAULT 60,
    spawn_conditions TEXT,  -- JSON conditions
    visual_spell INT UNSIGNED DEFAULT 0,
    announcement TEXT
);

-- Active dynamic hotspots
CREATE TABLE dc_hotspot_active (
    instance_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    hotspot_id INT UNSIGNED NOT NULL,
    spawned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    current_participants INT UNSIGNED DEFAULT 0,
    total_xp_granted BIGINT UNSIGNED DEFAULT 0,
    FOREIGN KEY (hotspot_id) REFERENCES dc_hotspot_dynamic(hotspot_id)
);
```

#### Spawn Conditions
```cpp
struct HotspotSpawnCondition
{
    std::string type;  // "time", "population", "event", "chain"
    
    // Time-based
    uint8 startHour;
    uint8 endHour;
    std::vector<uint8> daysOfWeek;  // 0=Sun, 6=Sat
    
    // Population-based
    uint32 minOnline;
    uint32 maxOnline;
    uint32 minInZone;
    
    // Event-based
    uint32 eventId;  // Custom event trigger
    
    // Chain-based
    uint32 requiresHotspotId;  // Must complete this first
};

void DynamicHotspotManager::CheckSpawnConditions()
{
    time_t now = GameTime::GetGameTime().count();
    tm* timeinfo = localtime(&now);
    uint32 onlinePlayers = sWorld->GetActiveSessionCount();
    
    for (auto& [id, hotspot] : _dynamicHotspots)
    {
        if (IsOnCooldown(id))
            continue;
        
        bool shouldSpawn = true;
        
        for (const auto& cond : hotspot.conditions)
        {
            if (cond.type == "time")
            {
                // Check hour range
                if (timeinfo->tm_hour < cond.startHour || timeinfo->tm_hour >= cond.endHour)
                    shouldSpawn = false;
                
                // Check day of week
                if (!cond.daysOfWeek.empty())
                {
                    if (std::find(cond.daysOfWeek.begin(), cond.daysOfWeek.end(), 
                        timeinfo->tm_wday) == cond.daysOfWeek.end())
                        shouldSpawn = false;
                }
            }
            else if (cond.type == "population")
            {
                if (onlinePlayers < cond.minOnline || onlinePlayers > cond.maxOnline)
                    shouldSpawn = false;
            }
            else if (cond.type == "chain")
            {
                if (!WasHotspotCompletedRecently(cond.requiresHotspotId))
                    shouldSpawn = false;
            }
        }
        
        if (shouldSpawn && roll_chance_f(hotspot.spawnChance))
        {
            SpawnDynamicHotspot(id);
        }
    }
}
```

---

### 2. Group Hotspot Bonuses

Scaling bonuses when more players are in the hotspot together.

```sql
CREATE TABLE dc_hotspot_group_scaling (
    hotspot_id INT UNSIGNED NOT NULL,
    min_players TINYINT UNSIGNED NOT NULL,
    max_players TINYINT UNSIGNED NOT NULL,
    xp_multiplier_bonus FLOAT DEFAULT 0,  -- Added to base
    drop_bonus FLOAT DEFAULT 0,
    special_reward_chance FLOAT DEFAULT 0,
    PRIMARY KEY (hotspot_id, min_players)
);

INSERT INTO dc_hotspot_group_scaling VALUES
-- Standard hotspots
(1, 1, 2, 0, 0, 0),
(1, 3, 4, 0.25, 0.1, 5),     -- 3-4 players: +25% XP, +10% drops, 5% special
(1, 5, 9, 0.50, 0.2, 10),    -- 5-9 players: +50% XP, +20% drops, 10% special
(1, 10, 255, 0.75, 0.3, 20); -- 10+ players: +75% XP, +30% drops, 20% special
```

```cpp
float HotspotManager::CalculateGroupBonus(uint32 hotspotId, uint32 playerCount)
{
    float bonus = 0.0f;
    
    auto result = CharacterDatabase.Query(
        "SELECT xp_multiplier_bonus FROM dc_hotspot_group_scaling "
        "WHERE hotspot_id = {} AND {} BETWEEN min_players AND max_players",
        hotspotId, playerCount);
    
    if (result)
        bonus = result->Fetch()[0].Get<float>();
    
    return bonus;
}

void HotspotManager::OnPlayerKillCreature(Player* player, Creature* creature)
{
    auto hotspot = GetHotspotAtPosition(player->GetMap()->GetId(), 
        player->GetPositionX(), player->GetPositionY());
    
    if (!hotspot)
        return;
    
    // Count nearby players in hotspot
    uint32 nearbyPlayers = 0;
    player->GetMap()->DoForAllPlayers([&](Player* p)
    {
        if (p != player && IsInHotspot(p, hotspot->id))
            nearbyPlayers++;
    });
    
    float groupBonus = CalculateGroupBonus(hotspot->id, nearbyPlayers + 1);
    float totalMultiplier = hotspot->xpMultiplier + groupBonus;
    
    // Apply XP bonus
    uint32 baseXP = CalculateXP(player, creature);
    uint32 bonusXP = static_cast<uint32>(baseXP * (totalMultiplier - 1.0f));
    player->GiveXP(bonusXP, nullptr);
    
    // Group synergy announcement
    if (groupBonus > 0 && urand(0, 10) == 0)  // 10% chance to announce
    {
        player->GetSession()->SendAreaTriggerMessage(
            "|cFF00FF00Group Synergy!|r +%.0f%% XP bonus", groupBonus * 100);
    }
}
```

---

### 3. Hotspot Events

Special events that occur within hotspots.

```sql
CREATE TABLE dc_hotspot_events (
    event_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    hotspot_id INT UNSIGNED NOT NULL,
    event_type ENUM('boss_spawn', 'treasure', 'invasion', 'buff_zone', 'double_xp', 'challenge') NOT NULL,
    trigger_type ENUM('time', 'kills', 'random', 'manual') NOT NULL,
    trigger_value INT UNSIGNED DEFAULT 0,  -- Kills needed, random chance %, etc.
    duration_seconds INT UNSIGNED DEFAULT 300,
    cooldown_seconds INT UNSIGNED DEFAULT 1800,
    event_data TEXT,  -- JSON: boss entry, treasure items, etc.
    announcement TEXT
);

CREATE TABLE dc_hotspot_event_log (
    log_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    event_id INT UNSIGNED NOT NULL,
    hotspot_id INT UNSIGNED NOT NULL,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ended_at TIMESTAMP NULL,
    participants INT UNSIGNED DEFAULT 0,
    outcome ENUM('completed', 'failed', 'expired') DEFAULT NULL
);
```

#### Event Types

```cpp
class HotspotEventManager
{
public:
    void TriggerEvent(uint32 hotspotId, uint32 eventId)
    {
        auto event = GetEvent(eventId);
        if (!event)
            return;
        
        switch (event->type)
        {
            case EVENT_BOSS_SPAWN:
                SpawnEventBoss(hotspotId, event);
                break;
                
            case EVENT_TREASURE:
                SpawnTreasureChests(hotspotId, event);
                break;
                
            case EVENT_INVASION:
                StartInvasion(hotspotId, event);
                break;
                
            case EVENT_BUFF_ZONE:
                ApplyZoneBuff(hotspotId, event);
                break;
                
            case EVENT_DOUBLE_XP:
                EnableDoubleXP(hotspotId, event);
                break;
                
            case EVENT_CHALLENGE:
                StartChallenge(hotspotId, event);
                break;
        }
        
        // Announce
        if (!event->announcement.empty())
            AnnounceToHotspot(hotspotId, event->announcement);
    }
    
private:
    void SpawnEventBoss(uint32 hotspotId, const HotspotEvent* event)
    {
        auto hotspot = sHotspotMgr->GetHotspot(hotspotId);
        
        // Parse event data
        auto data = nlohmann::json::parse(event->eventData);
        uint32 bossEntry = data["boss_entry"].get<uint32>();
        
        // Spawn boss at hotspot center
        Creature* boss = hotspot->map->SummonCreature(bossEntry,
            hotspot->centerX, hotspot->centerY, hotspot->centerZ, 0,
            TEMPSUMMON_TIMED_OR_DEAD_DESPAWN, event->durationSeconds * 1000);
        
        if (boss)
        {
            // Scale based on participants
            uint32 participants = GetHotspotPlayerCount(hotspotId);
            float healthMod = 1.0f + (participants * 0.25f);
            boss->SetMaxHealth(boss->GetMaxHealth() * healthMod);
            boss->SetHealth(boss->GetMaxHealth());
            
            // Register for loot distribution
            _activeEventBosses[boss->GetGUID()] = { hotspotId, event->eventId };
        }
    }
    
    void StartInvasion(uint32 hotspotId, const HotspotEvent* event)
    {
        auto hotspot = sHotspotMgr->GetHotspot(hotspotId);
        auto data = nlohmann::json::parse(event->eventData);
        
        uint32 mobEntry = data["mob_entry"].get<uint32>();
        uint32 waveCount = data["waves"].get<uint32>();
        uint32 mobsPerWave = data["mobs_per_wave"].get<uint32>();
        
        _invasions[hotspotId] = {
            .eventId = event->eventId,
            .currentWave = 0,
            .totalWaves = waveCount,
            .mobsPerWave = mobsPerWave,
            .mobEntry = mobEntry,
            .activeMobs = {},
            .nextWaveTime = GameTime::GetGameTime().count() + 10
        };
        
        SpawnInvasionWave(hotspotId);
    }
};
```

---

### 4. Hotspot Leaderboards

Competitive rankings for hotspot participation.

```sql
CREATE TABLE dc_hotspot_leaderboard (
    player_guid INT UNSIGNED NOT NULL,
    hotspot_id INT UNSIGNED NOT NULL,
    period ENUM('daily', 'weekly', 'monthly', 'alltime') NOT NULL,
    period_start DATE NOT NULL,
    xp_earned BIGINT UNSIGNED DEFAULT 0,
    kills INT UNSIGNED DEFAULT 0,
    time_spent_seconds INT UNSIGNED DEFAULT 0,
    events_completed INT UNSIGNED DEFAULT 0,
    PRIMARY KEY (player_guid, hotspot_id, period, period_start)
);

CREATE TABLE dc_hotspot_leaderboard_rewards (
    reward_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    hotspot_id INT UNSIGNED DEFAULT 0,  -- 0 = global
    period ENUM('daily', 'weekly', 'monthly') NOT NULL,
    rank_min TINYINT UNSIGNED NOT NULL,
    rank_max TINYINT UNSIGNED NOT NULL,
    reward_type ENUM('item', 'currency', 'title', 'cosmetic') NOT NULL,
    reward_entry INT UNSIGNED NOT NULL,
    reward_count INT UNSIGNED DEFAULT 1
);
```

```cpp
void HotspotManager::UpdateLeaderboard(ObjectGuid::LowType playerGuid, 
    uint32 hotspotId, uint32 xpGained, uint32 kills, uint32 timeSeconds)
{
    time_t now = GameTime::GetGameTime().count();
    
    // Update all periods
    for (const auto& period : { "daily", "weekly", "monthly", "alltime" })
    {
        std::string periodStart = GetPeriodStart(period, now);
        
        CharacterDatabase.Execute(
            "INSERT INTO dc_hotspot_leaderboard "
            "(player_guid, hotspot_id, period, period_start, xp_earned, kills, time_spent_seconds) "
            "VALUES ({}, {}, '{}', '{}', {}, {}, {}) "
            "ON DUPLICATE KEY UPDATE "
            "xp_earned = xp_earned + VALUES(xp_earned), "
            "kills = kills + VALUES(kills), "
            "time_spent_seconds = time_spent_seconds + VALUES(time_spent_seconds)",
            playerGuid, hotspotId, period, periodStart, xpGained, kills, timeSeconds);
    }
}

std::vector<LeaderboardEntry> HotspotManager::GetLeaderboard(
    uint32 hotspotId, const std::string& period, uint32 limit)
{
    std::string periodStart = GetPeriodStart(period, GameTime::GetGameTime().count());
    
    auto result = CharacterDatabase.Query(
        "SELECT l.player_guid, c.name, l.xp_earned, l.kills, l.time_spent_seconds "
        "FROM dc_hotspot_leaderboard l "
        "JOIN characters c ON c.guid = l.player_guid "
        "WHERE l.hotspot_id = {} AND l.period = '{}' AND l.period_start = '{}' "
        "ORDER BY l.xp_earned DESC LIMIT {}",
        hotspotId, period, periodStart, limit);
    
    std::vector<LeaderboardEntry> entries;
    if (result)
    {
        uint8 rank = 1;
        do
        {
            Field* fields = result->Fetch();
            entries.push_back({
                .rank = rank++,
                .playerGuid = fields[0].Get<uint32>(),
                .playerName = fields[1].Get<std::string>(),
                .xpEarned = fields[2].Get<uint64>(),
                .kills = fields[3].Get<uint32>(),
                .timeSpent = fields[4].Get<uint32>()
            });
        } while (result->NextRow());
    }
    
    return entries;
}
```

---

### 5. Hotspot Chains

Series of connected hotspots with progressive rewards.

```sql
CREATE TABLE dc_hotspot_chains (
    chain_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    chain_name VARCHAR(100) NOT NULL,
    chain_description TEXT,
    required_completion_order BOOLEAN DEFAULT FALSE,  -- Must complete in sequence
    completion_reward_type ENUM('item', 'currency', 'achievement', 'cosmetic') NOT NULL,
    completion_reward_entry INT UNSIGNED NOT NULL,
    completion_reward_count INT UNSIGNED DEFAULT 1,
    reset_type ENUM('daily', 'weekly', 'never') DEFAULT 'daily'
);

CREATE TABLE dc_hotspot_chain_members (
    chain_id INT UNSIGNED NOT NULL,
    sequence_order TINYINT UNSIGNED NOT NULL,
    hotspot_id INT UNSIGNED NOT NULL,
    required_time_seconds INT UNSIGNED DEFAULT 0,  -- 0 = any amount
    required_kills INT UNSIGNED DEFAULT 0,
    PRIMARY KEY (chain_id, sequence_order),
    FOREIGN KEY (chain_id) REFERENCES dc_hotspot_chains(chain_id)
);

CREATE TABLE dc_hotspot_chain_progress (
    player_guid INT UNSIGNED NOT NULL,
    chain_id INT UNSIGNED NOT NULL,
    current_step TINYINT UNSIGNED DEFAULT 0,
    step_progress TEXT,  -- JSON: {"time": 0, "kills": 0}
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP NULL,
    reset_date DATE NULL,
    PRIMARY KEY (player_guid, chain_id)
);
```

```cpp
void HotspotManager::CheckChainProgress(Player* player, uint32 hotspotId, 
    uint32 timeSpent, uint32 kills)
{
    ObjectGuid::LowType guid = player->GetGUID().GetCounter();
    
    // Find chains containing this hotspot
    auto chains = GetChainsForHotspot(hotspotId);
    
    for (auto& chain : chains)
    {
        auto progress = GetChainProgress(guid, chain.chainId);
        
        // Check if this is the current/next step
        auto currentStep = chain.members[progress.currentStep];
        if (currentStep.hotspotId != hotspotId)
        {
            if (!chain.requiredOrder)
            {
                // Can complete any step - find matching one
                for (size_t i = 0; i < chain.members.size(); ++i)
                {
                    if (chain.members[i].hotspotId == hotspotId && 
                        !IsStepCompleted(progress, i))
                    {
                        UpdateStepProgress(guid, chain.chainId, i, timeSpent, kills);
                        break;
                    }
                }
            }
            continue;  // Wrong step for ordered chain
        }
        
        // Update progress for current step
        UpdateStepProgress(guid, chain.chainId, progress.currentStep, timeSpent, kills);
        
        // Check if step completed
        if (IsStepComplete(progress, currentStep))
        {
            progress.currentStep++;
            
            // Check if chain completed
            if (progress.currentStep >= chain.members.size())
            {
                CompleteChain(player, chain);
            }
            else
            {
                // Announce next step
                player->GetSession()->SendAreaTriggerMessage(
                    "|cFF00FF00Chain Progress:|r Step %u/%u complete! "
                    "Next: %s", 
                    progress.currentStep, chain.members.size(),
                    GetHotspotName(chain.members[progress.currentStep].hotspotId).c_str());
            }
        }
    }
}
```

---

### 6. Enhanced Addon Packets

Extended data for richer client display.

```cpp
void HotspotManager::SendHotspotData(Player* player)
{
    // Build comprehensive hotspot data packet
    nlohmann::json data;
    
    // Static hotspots
    data["static"] = nlohmann::json::array();
    for (const auto& [id, hotspot] : _hotspots)
    {
        if (hotspot.mapId != player->GetMapId())
            continue;
        
        nlohmann::json hs;
        hs["id"] = id;
        hs["name"] = hotspot.name;
        hs["x"] = hotspot.centerX;
        hs["y"] = hotspot.centerY;
        hs["z"] = hotspot.centerZ;
        hs["radius"] = hotspot.radius;
        hs["xp_mult"] = hotspot.xpMultiplier;
        hs["players"] = GetHotspotPlayerCount(id);
        hs["group_bonus"] = CalculateGroupBonus(id, GetHotspotPlayerCount(id));
        hs["active_event"] = GetActiveEvent(id);
        
        // Player-specific data
        auto playerData = GetPlayerHotspotData(player->GetGUID().GetCounter(), id);
        hs["your_time"] = playerData.totalTime;
        hs["your_kills"] = playerData.totalKills;
        hs["camping_tier"] = playerData.campingTier;
        
        data["static"].push_back(hs);
    }
    
    // Dynamic hotspots
    data["dynamic"] = nlohmann::json::array();
    for (const auto& active : _activeHotspots)
    {
        if (active.second.mapId != player->GetMapId())
            continue;
        
        nlohmann::json dh;
        dh["id"] = active.first;
        dh["name"] = active.second.name;
        dh["x"] = active.second.centerX;
        dh["y"] = active.second.centerY;
        dh["z"] = active.second.centerZ;
        dh["radius"] = active.second.radius;
        dh["xp_mult"] = active.second.xpMultiplier;
        dh["expires_in"] = active.second.expiresAt - GameTime::GetGameTime().count();
        dh["is_dynamic"] = true;
        
        data["dynamic"].push_back(dh);
    }
    
    // Chain progress
    data["chains"] = nlohmann::json::array();
    for (const auto& chain : GetPlayerActiveChains(player->GetGUID().GetCounter()))
    {
        nlohmann::json ch;
        ch["id"] = chain.chainId;
        ch["name"] = chain.name;
        ch["current_step"] = chain.currentStep;
        ch["total_steps"] = chain.totalSteps;
        ch["next_hotspot_id"] = chain.nextHotspotId;
        
        data["chains"].push_back(ch);
    }
    
    // Leaderboard position
    data["leaderboard"] = nlohmann::json::object();
    data["leaderboard"]["daily_rank"] = GetPlayerRank(player->GetGUID().GetCounter(), 0, "daily");
    data["leaderboard"]["weekly_rank"] = GetPlayerRank(player->GetGUID().GetCounter(), 0, "weekly");
    
    // Send via Eluna/AIO
    SendAddonPacket(player, "DC_HOTSPOTS", data.dump());
}
```

---

## AIO Addon Enhancements

```lua
-- HotspotEnhanced.lua
local HotspotFrame = AIO.AddAddon()

function HotspotFrame:CreateMinimap()
    -- Minimap icons for hotspots
    self.minimapIcons = {}
    
    -- Create icon pool
    for i = 1, 20 do
        local icon = CreateFrame("Frame", nil, Minimap)
        icon:SetSize(16, 16)
        icon.texture = icon:CreateTexture(nil, "OVERLAY")
        icon.texture:SetAllPoints()
        icon.texture:SetTexture("Interface\\Minimap\\ObjectIcons")
        icon:Hide()
        
        icon:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            HotspotFrame:ShowHotspotTooltip(self.hotspotId)
        end)
        
        self.minimapIcons[i] = icon
    end
end

function HotspotFrame:UpdateMinimapIcons(hotspots)
    local px, py = GetPlayerMapPosition("player")
    local iconIdx = 1
    
    for _, hs in ipairs(hotspots) do
        if iconIdx > #self.minimapIcons then break end
        
        -- Calculate minimap position
        local dx = hs.x - px
        local dy = hs.y - py
        local dist = math.sqrt(dx*dx + dy*dy)
        
        if dist < 500 then  -- Within range
            local icon = self.minimapIcons[iconIdx]
            local angle = math.atan2(dy, dx)
            local radius = math.min(dist / 10, 60)
            
            icon:SetPoint("CENTER", Minimap, "CENTER", 
                math.cos(angle) * radius, 
                math.sin(angle) * radius)
            
            -- Color based on type
            if hs.is_dynamic then
                icon.texture:SetVertexColor(1, 0.5, 0)  -- Orange for dynamic
            elseif hs.active_event then
                icon.texture:SetVertexColor(1, 0, 1)    -- Purple for event
            else
                icon.texture:SetVertexColor(0, 1, 0)    -- Green for static
            end
            
            icon.hotspotId = hs.id
            icon:Show()
            iconIdx = iconIdx + 1
        end
    end
    
    -- Hide unused icons
    for i = iconIdx, #self.minimapIcons do
        self.minimapIcons[i]:Hide()
    end
end

function HotspotFrame:CreateChainTracker()
    self.chainFrame = CreateFrame("Frame", nil, UIParent)
    self.chainFrame:SetSize(200, 100)
    self.chainFrame:SetPoint("RIGHT", -20, 0)
    
    self.chainFrame.title = self.chainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.chainFrame.title:SetPoint("TOP")
    self.chainFrame.title:SetText("Active Chains")
    
    self.chainFrame.chains = {}
    for i = 1, 3 do
        local row = CreateFrame("Frame", nil, self.chainFrame)
        row:SetSize(190, 25)
        row:SetPoint("TOP", 0, -20 - (i-1) * 28)
        
        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.name:SetPoint("LEFT")
        
        row.progress = CreateFrame("StatusBar", nil, row)
        row.progress:SetSize(60, 12)
        row.progress:SetPoint("RIGHT")
        row.progress:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        row.progress:SetStatusBarColor(0, 0.7, 0)
        row.progress.bg = row.progress:CreateTexture(nil, "BACKGROUND")
        row.progress.bg:SetAllPoints()
        row.progress.bg:SetColorTexture(0.2, 0.2, 0.2)
        
        self.chainFrame.chains[i] = row
    end
end
```

---

## GM Commands

```cpp
// .hotspot dynamic create <type> <zone> <x> <y> <z> <radius> <multiplier>
// .hotspot dynamic spawn <id>
// .hotspot dynamic expire <id>
// .hotspot event trigger <hotspot_id> <event_id>
// .hotspot event list <hotspot_id>
// .hotspot chain create <name>
// .hotspot chain add <chain_id> <hotspot_id> <order>
// .hotspot leaderboard show <hotspot_id> <period>
// .hotspot leaderboard reset <hotspot_id> <period>
```

---

## Timeline

| Phase | Duration | Tasks |
|-------|----------|-------|
| Dynamic | 3 days | Spawn conditions, lifecycle |
| Group Bonuses | 2 days | Scaling calculation, display |
| Events | 4 days | Event types, triggers, rewards |
| Leaderboards | 2 days | Tracking, display, rewards |
| Chains | 3 days | Progress tracking, completion |
| Addon | 3 days | Enhanced UI components |
| Testing | 2 days | Full system integration |
| **Total** | **~2.5 weeks** | |

---

## Integration Points

- **Seasons**: Seasonal hotspots with unique rewards
- **Mythic+**: Hotspots in dungeon areas during events
- **Prestige**: Higher prestige = better hotspot bonuses
- **ItemUpgrades**: Hotspot events drop upgrade materials
