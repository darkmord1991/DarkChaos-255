# Bounty/Contract System

**Priority:** B4 (Medium Priority)  
**Effort:** Medium (2 weeks)  
**Impact:** Medium  
**Base:** Custom System (inspired by mod-daily-quests, mod-bounty-hunter)

---

## Overview

A contract board system offering daily/weekly objectives for rewards. Contracts cover PvE kills, PvP targets, dungeon completions, gathering tasks, and more. Provides structured goals beyond standard quests.

---

## Why It Fits DarkChaos-255

### Integration Points
| System | Integration |
|--------|-------------|
| **Dungeon Quests** | Complements existing system |
| **Mythic+** | M+ completion contracts |
| **HLBG** | PvP bounty contracts |
| **Item Upgrades** | Upgrade tokens as rewards |
| **Seasonal** | Season-specific contracts |

### Benefits
- Daily/weekly structured goals
- Variety of content
- Token sink and source
- Encourages exploration
- Solo and group content

---

## Contract Types

### 1. **PvE Contracts**
- Kill X creatures in zone
- Complete dungeon
- Defeat world boss
- Clear M+ at level X

### 2. **PvP Contracts**
- Kill X players in HLBG
- Win X battlegrounds
- Achieve X kills in world PvP
- Bounty on specific high-value targets

### 3. **Gathering Contracts**
- Collect X herbs
- Mine X ore
- Fish X rare fish
- Skin X beasts

### 4. **Exploration Contracts**
- Visit X locations
- Find hidden treasures
- Discover rare NPCs
- Complete zone achievements

---

## Implementation

### Database Schema
```sql
-- Contract definitions
CREATE TABLE dc_contracts (
    contract_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    contract_name VARCHAR(100) NOT NULL,
    contract_type ENUM('pve', 'pvp', 'gathering', 'exploration') NOT NULL,
    description TEXT,
    
    -- Requirements
    objective_type ENUM('kill', 'complete', 'collect', 'visit', 'win') NOT NULL,
    objective_target INT UNSIGNED DEFAULT 0,  -- creature/item/zone entry
    objective_count INT UNSIGNED DEFAULT 1,
    min_level TINYINT UNSIGNED DEFAULT 1,
    max_level TINYINT UNSIGNED DEFAULT 255,
    
    -- Rewards
    reward_tokens INT UNSIGNED DEFAULT 0,
    reward_gold INT UNSIGNED DEFAULT 0,
    reward_item INT UNSIGNED DEFAULT 0,
    reward_item_count INT UNSIGNED DEFAULT 1,
    reward_xp INT UNSIGNED DEFAULT 0,
    
    -- Timing
    duration ENUM('daily', 'weekly', 'monthly') DEFAULT 'daily',
    cooldown_hours INT UNSIGNED DEFAULT 24,
    
    -- Availability
    active BOOLEAN DEFAULT TRUE,
    weight INT UNSIGNED DEFAULT 100,  -- For random selection
    seasonal_only BOOLEAN DEFAULT FALSE,
    season_id INT UNSIGNED DEFAULT 0
);

-- Player contract progress
CREATE TABLE dc_contract_progress (
    progress_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    player_guid INT UNSIGNED NOT NULL,
    contract_id INT UNSIGNED NOT NULL,
    accepted_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    current_count INT UNSIGNED DEFAULT 0,
    completed BOOLEAN DEFAULT FALSE,
    completion_time TIMESTAMP NULL,
    UNIQUE KEY (player_guid, contract_id, accepted_time)
);

-- Contract board (available contracts per day)
CREATE TABLE dc_contract_board (
    board_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    contract_id INT UNSIGNED NOT NULL,
    board_date DATE NOT NULL,
    board_type ENUM('daily', 'weekly') DEFAULT 'daily',
    UNIQUE KEY (contract_id, board_date, board_type)
);

-- Sample contracts
INSERT INTO dc_contracts (contract_name, contract_type, objective_type, objective_target, objective_count, reward_tokens, duration, description) VALUES
('Dungeon Delver', 'pve', 'complete', 0, 3, 50, 'daily', 'Complete 3 dungeons of any difficulty'),
('Mythic Challenge', 'pve', 'complete', 0, 1, 100, 'daily', 'Complete a M+ dungeon at level 5 or higher'),
('HLBG Warrior', 'pvp', 'kill', 0, 10, 75, 'daily', 'Kill 10 players in Hinterland BG'),
('Herb Collector', 'gathering', 'collect', 0, 50, 30, 'daily', 'Collect 50 herbs'),
('Zone Explorer', 'exploration', 'visit', 0, 5, 40, 'daily', 'Visit 5 different zones'),
('Weekly Raid', 'pve', 'complete', 0, 1, 500, 'weekly', 'Complete any raid'),
('Weekly HLBG Champion', 'pvp', 'win', 0, 10, 400, 'weekly', 'Win 10 HLBG matches');
```

### Contract Manager (C++)
```cpp
class ContractManager
{
public:
    static ContractManager* instance();
    
    // Daily board
    void GenerateDailyBoard();
    void GenerateWeeklyBoard();
    std::vector<Contract*> GetAvailableContracts(Player* player) const;
    
    // Player contracts
    bool AcceptContract(Player* player, uint32 contractId);
    bool AbandonContract(Player* player, uint32 contractId);
    bool CompleteContract(Player* player, uint32 contractId);
    
    // Progress tracking
    void UpdateProgress(Player* player, ContractObjectiveType type, uint32 target, uint32 count);
    uint32 GetProgress(Player* player, uint32 contractId) const;
    bool IsContractComplete(Player* player, uint32 contractId) const;
    
    // Rewards
    void GrantRewards(Player* player, uint32 contractId);
    
private:
    std::unordered_map<uint32, Contract> _contracts;
    std::unordered_map<ObjectGuid, std::vector<PlayerContract>> _playerContracts;
    
    void LoadContracts();
    void CheckCompletion(Player* player, PlayerContract& contract);
};

#define sContractMgr ContractManager::instance()
```

### Eluna Hooks
```lua
-- Hook creature kills
local function OnCreatureKill(event, player, creature)
    UpdateContractProgress(player, "kill", creature:GetEntry(), 1)
end

-- Hook dungeon completion
local function OnDungeonComplete(event, player, mapId)
    UpdateContractProgress(player, "complete", mapId, 1)
end

-- Hook item looting
local function OnLootItem(event, player, item, count)
    UpdateContractProgress(player, "collect", item:GetEntry(), count)
end

-- Hook zone change
local function OnZoneChange(event, player, newZone, newArea)
    UpdateContractProgress(player, "visit", newZone, 1)
end

RegisterPlayerEvent(7, OnCreatureKill)
RegisterPlayerEvent(27, OnZoneChange)
```

---

## Contract Board UI

### NPC Interaction
```lua
-- Contract Board NPC
function ContractBoard.OnGossipHello(event, player, creature)
    -- Show available contracts
    local dailyContracts = GetDailyContracts()
    local weeklyContracts = GetWeeklyContracts()
    local activeContracts = GetPlayerContracts(player:GetGUIDLow())
    
    player:GossipMenuAddItem(0, "[Daily Contracts]", 1, 1)
    player:GossipMenuAddItem(0, "[Weekly Contracts]", 1, 2)
    player:GossipMenuAddItem(0, "[My Active Contracts (" .. #activeContracts .. ")]", 1, 3)
    player:GossipMenuAddItem(0, "[Turn In Completed]", 1, 4)
    
    player:GossipSendMenu(1, creature)
end
```

### AIO Addon
```lua
-- Contract Tracker
-- Shows active contracts with progress bars
-- Mini-map icon for contract board
-- Completion notifications
-- Auto-track nearest objective
```

---

## Daily Contract Examples

| Contract | Type | Objective | Reward |
|----------|------|-----------|--------|
| Dungeon Delver | PvE | Complete 3 dungeons | 50 tokens |
| Mythic Push | PvE | M+5 or higher | 100 tokens |
| HLBG Warrior | PvP | 10 kills in HLBG | 75 tokens |
| Herb Gatherer | Gathering | 50 herbs | 30 tokens |
| Zone Traveler | Exploration | Visit 5 zones | 40 tokens |

## Weekly Contract Examples

| Contract | Type | Objective | Reward |
|----------|------|-----------|--------|
| Raid Champion | PvE | Complete raid | 500 tokens |
| HLBG Dominator | PvP | 10 HLBG wins | 400 tokens |
| Master Gatherer | Gathering | 500 resources | 300 tokens |
| Mythic Master | PvE | M+10 completion | 600 tokens |

---

## Commands

### Player Commands
```
.contract list        - Show available contracts
.contract active      - Show your active contracts
.contract accept <id> - Accept a contract
.contract abandon <id> - Abandon a contract
.contract turnin      - Turn in completed contracts
```

### GM Commands
```
.contract add <id>    - Add contract to player
.contract complete <id> - Force complete contract
.contract reset       - Reset daily/weekly boards
.contract reload      - Reload contract database
```

---

## Timeline

| Task | Duration |
|------|----------|
| Database schema | 2 hours |
| ContractManager C++ | 3 days |
| Progress tracking hooks | 2 days |
| NPC and gossip | 1 day |
| Eluna integration | 1 day |
| AIO addon | 2 days |
| Sample contracts | 4 hours |
| Testing | 2 days |
| **Total** | **~2 weeks** |

---

## Future Enhancements

1. **Elite Contracts** - High difficulty, high reward
2. **Chain Contracts** - Multi-step story contracts
3. **Group Contracts** - Party-wide objectives
4. **Guild Contracts** - Guild-wide goals
5. **PvP Bounties** - Target specific players
