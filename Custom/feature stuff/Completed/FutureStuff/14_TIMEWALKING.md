# Timewalking Dungeons System

**Priority:** S3 - Medium Priority  
**Effort:** Medium (2-3 weeks)  
**Impact:** Medium-High  
**Base:** Custom scaling with AutoBalance

---

## Overview

Timewalking Dungeons scale players down to appropriate levels for classic content, making all dungeons relevant at endgame. This adds variety, nostalgia, and extends content lifespan by making all dungeons viable for rewards.

---

## Why It Fits DarkChaos-255

### Content Extension
- Makes all 80+ dungeons relevant
- Adds variety to M+ rotation
- Nostalgia factor for veterans
- Training ground for mechanics

### Funserver Value
- Unique content experience
- Weekend event potential
- Achievement hunting
- Transmog farming (scaled drops)

### Synergies
| System | Integration |
|--------|-------------|
| **Mythic+** | Timewalking M+ keystones |
| **Weekend Events** | Timewalking Weekends |
| **Achievements** | TW-specific achievements |
| **Transmog** | Scaled transmog rewards |

---

## Feature Highlights

### Core Features

1. **Level Scaling**
   - Player stats scaled to dungeon level
   - Gear effectiveness normalized
   - Abilities work at scaled power
   - Keeps class fantasy intact

2. **Dungeon Categories**
   - Classic Dungeons (Level 60)
   - TBC Dungeons (Level 70)
   - WotLK Heroics (Level 80)
   - Each with appropriate scaling

3. **Reward Scaling**
   - Badges/currency at 255 rates
   - Transmog drops
   - Timewalking-specific rewards
   - Achievement points

4. **Queue System**
   - Random Timewalking queue
   - Specific dungeon selection
   - Solo/Group queuing
   - Cross-faction (if enabled)

5. **Timewalking M+**
   - Apply keystones to TW dungeons
   - Unique affix combinations
   - Extended dungeon pool

---

## Technical Implementation

### Database Schema

```sql
-- Timewalking dungeon definitions
CREATE TABLE dc_timewalking_dungeons (
    dungeon_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    map_id INT UNSIGNED,
    dungeon_name VARCHAR(100),
    expansion ENUM('classic', 'tbc', 'wotlk') DEFAULT 'classic',
    
    -- Scaling targets
    target_level INT DEFAULT 60,
    target_item_level INT DEFAULT 60,
    
    -- Queue info
    min_players INT DEFAULT 1,
    max_players INT DEFAULT 5,
    average_time_minutes INT DEFAULT 30,
    
    -- Rewards
    badge_reward INT DEFAULT 5,
    bonus_badge_first INT DEFAULT 3,  -- First of day bonus
    
    -- Availability
    is_active TINYINT DEFAULT 1,
    mythic_plus_enabled TINYINT DEFAULT 1,
    
    INDEX idx_expansion (expansion)
);

-- Player scaling snapshots (for restoration)
CREATE TABLE dc_timewalking_player_state (
    state_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    player_guid INT UNSIGNED,
    dungeon_id INT UNSIGNED,
    
    -- Original stats to restore
    original_health INT UNSIGNED,
    original_mana INT UNSIGNED,
    original_strength INT,
    original_agility INT,
    original_stamina INT,
    original_intellect INT,
    original_spirit INT,
    original_armor INT,
    original_spell_power INT,
    original_attack_power INT,
    
    entered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_player (player_guid)
);

-- Timewalking rewards
CREATE TABLE dc_timewalking_rewards (
    reward_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    expansion ENUM('classic', 'tbc', 'wotlk'),
    reward_type ENUM('mount', 'pet', 'toy', 'transmog', 'title'),
    item_id INT UNSIGNED,
    badge_cost INT UNSIGNED,
    description TEXT
);

-- Sample dungeon data
INSERT INTO dc_timewalking_dungeons 
(map_id, dungeon_name, expansion, target_level, target_item_level, badge_reward) VALUES
-- Classic
(33, 'Shadowfang Keep', 'classic', 60, 60, 3),
(34, 'The Stockade', 'classic', 60, 60, 2),
(36, 'Deadmines', 'classic', 60, 60, 3),
(43, 'Wailing Caverns', 'classic', 60, 60, 3),
(47, 'Razorfen Kraul', 'classic', 60, 60, 3),
(48, 'Blackfathom Deeps', 'classic', 60, 60, 4),
(70, 'Uldaman', 'classic', 60, 60, 4),
(90, 'Gnomeregan', 'classic', 60, 60, 4),
(109, 'Sunken Temple', 'classic', 60, 60, 5),
(129, 'Razorfen Downs', 'classic', 60, 60, 4),
(189, 'Scarlet Monastery', 'classic', 60, 60, 4),
(209, 'Zul''Farrak', 'classic', 60, 60, 5),
(229, 'Blackrock Spire', 'classic', 60, 63, 6),
(230, 'Blackrock Depths', 'classic', 60, 63, 7),
(289, 'Scholomance', 'classic', 60, 65, 6),
(329, 'Stratholme', 'classic', 60, 65, 6),
(349, 'Maraudon', 'classic', 60, 60, 5),
(389, 'Ragefire Chasm', 'classic', 60, 60, 2),
(429, 'Dire Maul', 'classic', 60, 65, 6),

-- TBC
(540, 'Hellfire Ramparts', 'tbc', 70, 100, 4),
(542, 'Blood Furnace', 'tbc', 70, 100, 4),
(543, 'Slave Pens', 'tbc', 70, 100, 4),
(545, 'Steamvault', 'tbc', 70, 110, 5),
(546, 'Underbog', 'tbc', 70, 100, 4),
(547, 'Botanica', 'tbc', 70, 110, 5),
(552, 'Arcatraz', 'tbc', 70, 115, 6),
(553, 'Mechanar', 'tbc', 70, 110, 5),
(554, 'Shadow Labyrinth', 'tbc', 70, 115, 6),
(555, 'Sethekk Halls', 'tbc', 70, 110, 5),
(556, 'Mana-Tombs', 'tbc', 70, 105, 4),
(557, 'Auchenai Crypts', 'tbc', 70, 105, 4),
(558, 'Old Hillsbrad', 'tbc', 70, 110, 5),
(560, 'Black Morass', 'tbc', 70, 115, 6),
(585, 'Magisters'' Terrace', 'tbc', 70, 120, 7);
```

### C++ Scaling System

```cpp
// TimewalkingManager.h

class TimewalkingManager
{
public:
    static TimewalkingManager* instance();
    
    // Dungeon management
    void LoadDungeons();
    TimewalkingDungeon* GetDungeon(uint32 mapId);
    std::vector<TimewalkingDungeon*> GetDungeonsByExpansion(Expansion exp);
    
    // Player scaling
    void ScalePlayerDown(Player* player, TimewalkingDungeon* dungeon);
    void RestorePlayer(Player* player);
    void SavePlayerState(Player* player);
    PlayerState* GetSavedState(ObjectGuid guid);
    
    // Stat calculations
    int32 CalculateScaledStat(Player* player, Stats stat, uint32 targetLevel);
    int32 CalculateScaledHealth(Player* player, uint32 targetLevel);
    int32 CalculateScaledMana(Player* player, uint32 targetLevel);
    float GetScalingFactor(uint32 playerLevel, uint32 targetLevel);
    
    // Queue
    void QueuePlayer(Player* player, Expansion expansion);
    void ProcessQueues();
    
private:
    std::map<uint32, TimewalkingDungeon*> _dungeons;
    std::map<ObjectGuid, PlayerState*> _savedStates;
    std::map<Expansion, std::vector<Player*>> _queues;
};

#define sTimewalkingMgr TimewalkingManager::instance()
```

```cpp
// TimewalkingManager.cpp

void TimewalkingManager::ScalePlayerDown(Player* player, TimewalkingDungeon* dungeon)
{
    // Save original state
    SavePlayerState(player);
    
    uint32 targetLevel = dungeon->targetLevel;
    uint32 targetILevel = dungeon->targetItemLevel;
    
    // Calculate scaling factor
    float factor = GetScalingFactor(player->GetLevel(), targetLevel);
    
    // Scale base stats
    for (uint8 stat = STAT_STRENGTH; stat < MAX_STATS; ++stat)
    {
        int32 originalValue = player->GetStat(Stats(stat));
        int32 scaledValue = CalculateScaledStat(player, Stats(stat), targetLevel);
        
        // Apply as aura modification
        player->ApplyStatMod(Stats(stat), originalValue - scaledValue, false);
    }
    
    // Scale health and mana
    uint32 scaledHealth = CalculateScaledHealth(player, targetLevel);
    uint32 scaledMana = CalculateScaledMana(player, targetLevel);
    
    player->SetMaxHealth(scaledHealth);
    player->SetHealth(scaledHealth);
    player->SetMaxPower(POWER_MANA, scaledMana);
    player->SetPower(POWER_MANA, scaledMana);
    
    // Scale gear effectiveness
    for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
    {
        if (Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot))
        {
            // Store original enchants/bonuses
            // Apply scaled versions
            ScaleItemStats(player, item, targetILevel);
        }
    }
    
    // Apply visual buff to indicate scaling
    player->AddAura(SPELL_TIMEWALKING_SCALED, player);
    
    // Notify player
    ChatHandler(player->GetSession()).PSendSysMessage(
        "|cff00ff00[Timewalking]|r Your power has been scaled to level %u.", targetLevel);
}

void TimewalkingManager::RestorePlayer(Player* player)
{
    PlayerState* state = GetSavedState(player->GetGUID());
    if (!state)
        return;
    
    // Restore all original stats
    player->SetMaxHealth(state->maxHealth);
    player->SetHealth(state->maxHealth);
    player->SetMaxPower(POWER_MANA, state->maxMana);
    player->SetPower(POWER_MANA, state->maxMana);
    
    // Remove stat modifications
    for (uint8 stat = STAT_STRENGTH; stat < MAX_STATS; ++stat)
    {
        player->ApplyStatMod(Stats(stat), 0, true);  // Reset mods
    }
    
    // Restore gear stats
    for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
    {
        if (Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot))
        {
            RestoreItemStats(player, item);
        }
    }
    
    // Remove scaling buff
    player->RemoveAura(SPELL_TIMEWALKING_SCALED);
    
    // Cleanup
    delete state;
    _savedStates.erase(player->GetGUID());
}

float TimewalkingManager::GetScalingFactor(uint32 playerLevel, uint32 targetLevel)
{
    if (playerLevel <= targetLevel)
        return 1.0f;
    
    // Formula: scale down proportionally
    // At 255 -> 60, factor is approximately 0.24
    // But we want to maintain relative power within the group
    
    // Use item level equivalence
    // Level 60 gear ~ iLvl 60-70
    // Level 255 gear ~ iLvl 1000+ (custom)
    
    float baseFactor = static_cast<float>(targetLevel) / static_cast<float>(playerLevel);
    
    // Add some buffer to not feel too weak
    return baseFactor * 1.5f;  // 50% power buffer
}
```

### Eluna Queue System

```lua
-- Timewalking Queue Manager
local TWQueue = {}
TWQueue.Queues = {
    classic = {},
    tbc = {},
    wotlk = {}
}
TWQueue.MIN_PLAYERS = 1  -- Solo allowed
TWQueue.MAX_PLAYERS = 5

-- Queue player for TW
function TWQueue.QueuePlayer(player, expansion)
    local guid = player:GetGUIDLow()
    
    -- Check if already queued
    for exp, queue in pairs(TWQueue.Queues) do
        for _, qPlayer in ipairs(queue) do
            if qPlayer.guid == guid then
                player:SendBroadcastMessage("|cffff0000You are already in a Timewalking queue.|r")
                return
            end
        end
    end
    
    table.insert(TWQueue.Queues[expansion], {
        guid = guid,
        player = player,
        role = TWQueue.GetPlayerRole(player),
        queuedAt = os.time()
    })
    
    player:SendBroadcastMessage("|cff00ff00Queued for " .. expansion:upper() .. " Timewalking.|r")
    
    -- Try to form group
    TWQueue.TryFormGroup(expansion)
end

-- Try to form a group from queue
function TWQueue.TryFormGroup(expansion)
    local queue = TWQueue.Queues[expansion]
    
    if #queue < TWQueue.MIN_PLAYERS then
        return
    end
    
    -- Simple group formation: take first 5 in queue
    local groupMembers = {}
    for i = 1, math.min(#queue, TWQueue.MAX_PLAYERS) do
        table.insert(groupMembers, queue[i])
    end
    
    -- Remove from queue
    for i = 1, #groupMembers do
        table.remove(queue, 1)
    end
    
    -- Select random dungeon
    local dungeon = TWQueue.GetRandomDungeon(expansion)
    
    -- Create group and start
    TWQueue.StartDungeon(groupMembers, dungeon)
end

-- Start dungeon instance
function TWQueue.StartDungeon(members, dungeon)
    -- Create group if needed
    local group = nil
    if #members > 1 then
        -- Form group
        local leader = members[1].player
        group = CreateGroup(leader)
        for i = 2, #members do
            group:AddMember(members[i].player)
        end
    end
    
    -- Teleport and scale each player
    for _, member in ipairs(members) do
        local player = member.player
        
        -- Save return location
        player:SetData("tw_return_map", player:GetMapId())
        player:SetData("tw_return_x", player:GetX())
        player:SetData("tw_return_y", player:GetY())
        player:SetData("tw_return_z", player:GetZ())
        
        -- Scale player (calls C++ via command or direct Eluna)
        TWQueue.ScalePlayer(player, dungeon)
        
        -- Teleport to dungeon
        player:Teleport(dungeon.mapId, dungeon.entranceX, dungeon.entranceY, dungeon.entranceZ, 0)
        
        player:SendBroadcastMessage("|cff00ff00[Timewalking]|r Entering " .. dungeon.name)
    end
end

-- Handle dungeon completion
function TWQueue.OnDungeonComplete(player, dungeonId)
    local dungeon = TWQueue.GetDungeon(dungeonId)
    if not dungeon then return end
    
    -- Award badges
    local badges = dungeon.badgeReward
    
    -- Check for first of day bonus
    local lastComplete = player:GetData("tw_last_complete_" .. dungeon.expansion)
    local today = os.date("%Y-%m-%d")
    if lastComplete ~= today then
        badges = badges + dungeon.bonusBadgeFirst
        player:SetData("tw_last_complete_" .. dungeon.expansion, today)
        player:SendBroadcastMessage("|cff00ff00First Timewalking of the day bonus!|r")
    end
    
    -- Award currency
    player:ModifyMoney(badges * 10000)  -- Or custom currency
    player:SendBroadcastMessage("|cff00ff00+" .. badges .. " Timewalking Badges|r")
    
    -- Restore player stats
    TWQueue.RestorePlayer(player)
    
    -- Teleport back
    player:Teleport(
        player:GetData("tw_return_map"),
        player:GetData("tw_return_x"),
        player:GetData("tw_return_y"),
        player:GetData("tw_return_z"),
        0
    )
end

-- Commands
local function HandleTWCommand(player, command, args)
    if command ~= "timewalking" and command ~= "tw" then
        return true
    end
    
    local subCmd, param = args:match("(%S+)%s*(.*)")
    subCmd = subCmd or args
    
    if subCmd == "queue" or subCmd == "q" then
        local expansion = param ~= "" and param or "classic"
        if expansion == "classic" or expansion == "tbc" or expansion == "wotlk" then
            TWQueue.QueuePlayer(player, expansion)
        else
            player:SendBroadcastMessage("Usage: .tw queue [classic|tbc|wotlk]")
        end
        
    elseif subCmd == "leave" then
        TWQueue.LeaveQueue(player)
        
    elseif subCmd == "list" then
        player:SendBroadcastMessage("|cff00ff00=== Timewalking Dungeons ===|r")
        player:SendBroadcastMessage("Classic: " .. TWQueue.GetDungeonCount("classic") .. " dungeons")
        player:SendBroadcastMessage("TBC: " .. TWQueue.GetDungeonCount("tbc") .. " dungeons")
        player:SendBroadcastMessage("WotLK: " .. TWQueue.GetDungeonCount("wotlk") .. " dungeons")
        
    else
        player:SendBroadcastMessage("Usage: .tw queue|leave|list")
    end
    
    return false
end
RegisterPlayerEvent(42, HandleTWCommand)
```

---

## Implementation Phases

### Phase 1 (Week 1): Core Scaling
- [ ] Database schema
- [ ] Player scaling system
- [ ] Stat calculation formulas
- [ ] State save/restore

### Phase 2 (Week 2): Queue & Dungeons
- [ ] Queue system
- [ ] Group formation
- [ ] Dungeon data population
- [ ] Teleport handling

### Phase 3 (Week 3): Rewards & Polish
- [ ] Badge rewards
- [ ] Vendor setup
- [ ] Timewalking M+ support
- [ ] Testing all dungeons

---

## Commands Reference

| Command | Description |
|---------|-------------|
| `.tw queue classic` | Queue for Classic dungeons |
| `.tw queue tbc` | Queue for TBC dungeons |
| `.tw queue wotlk` | Queue for WotLK heroics |
| `.tw leave` | Leave queue |
| `.tw list` | Show available dungeons |

---

## Rewards

### Timewalking Badge Vendor

| Item | Cost | Type |
|------|------|------|
| Mount: Infinite Timereaver | 5000 | Mount |
| Pet: Paradox Spirit | 1000 | Pet |
| Transmog Token | 100 | Currency |
| Upgrade Crystal | 500 | Upgrade material |
| Classic Tier Token | 750 | Transmog |
| TBC Tier Token | 750 | Transmog |

---

## Success Metrics

- Queue times per expansion
- Dungeon completion rates
- Badge acquisition rate
- Player engagement with old content

---

**Recommendation:** Start with Classic dungeons only. Add TBC and WotLK in later phases. Integrate with Weekend Events for "Timewalking Weekends" bonus events. Consider Timewalking M+ as a stretch goal.
