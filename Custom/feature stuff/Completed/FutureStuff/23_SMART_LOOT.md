# Smart Loot System

**Priority:** B6 (Medium Priority)  
**Effort:** High (3 weeks)  
**Impact:** Medium  
**Base:** Custom Loot System (inspired by retail Personal Loot)

---

## Overview

A modern loot system that provides spec-appropriate drops, personal loot options, bonus roll mechanics, and duplicate protection. Reduces loot drama and improves gear acquisition flow.

---

## Why It Fits DarkChaos-255

### Integration Points
| System | Integration |
|--------|-------------|
| **Mythic+** | M+ uses personal loot |
| **Item Upgrades** | Loot feeds upgrade system |
| **Seasonal** | Season affects loot tables |
| **Tokens** | Bonus rolls cost tokens |

### Benefits
- Reduces loot drama
- Spec-appropriate drops
- Solo-friendly loot
- Bonus roll excitement
- Modern feel

---

## Features

### 1. **Personal Loot Mode**
- Each player gets their own loot roll
- Drops are appropriate to current spec
- No ninja looting possible
- Can trade within 2 hours

### 2. **Spec-Based Filtering**
- Items match current specialization
- Optional: Include off-spec items
- Respects stat priorities
- Avoids completely useless drops

### 3. **Bonus Roll System**
- Use tokens to roll again
- Higher key = better bonus chance
- Weekly limit on bonus rolls
- Consolation prize if no loot

### 4. **Duplicate Protection**
- Less likely to get items you have
- Higher item level replaces lower
- Transmog collection tracking
- Bad luck protection counter

---

## Implementation

### Database Schema
```sql
-- Player loot settings
CREATE TABLE dc_loot_settings (
    guid INT UNSIGNED PRIMARY KEY,
    loot_spec TINYINT UNSIGNED DEFAULT 0,  -- 0 = current spec
    allow_offspec BOOLEAN DEFAULT TRUE,
    trade_window_hours TINYINT UNSIGNED DEFAULT 2,
    show_loot_notifications BOOLEAN DEFAULT TRUE
);

-- Personal loot history (for duplicate protection)
CREATE TABLE dc_loot_history (
    history_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    guid INT UNSIGNED NOT NULL,
    item_entry INT UNSIGNED NOT NULL,
    item_level SMALLINT UNSIGNED NOT NULL,
    source_type ENUM('dungeon', 'raid', 'world_boss', 'mythic_plus') NOT NULL,
    source_id INT UNSIGNED NOT NULL,
    loot_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    traded_to INT UNSIGNED DEFAULT 0,
    INDEX (guid, item_entry)
);

-- Bonus roll tracking
CREATE TABLE dc_bonus_rolls (
    guid INT UNSIGNED NOT NULL,
    week_start DATE NOT NULL,
    rolls_used TINYINT UNSIGNED DEFAULT 0,
    rolls_max TINYINT UNSIGNED DEFAULT 3,
    PRIMARY KEY (guid, week_start)
);

-- Bad luck protection
CREATE TABLE dc_bad_luck_protection (
    guid INT UNSIGNED NOT NULL,
    source_type VARCHAR(50) NOT NULL,
    source_id INT UNSIGNED NOT NULL,
    attempts INT UNSIGNED DEFAULT 0,
    last_drop TIMESTAMP NULL,
    PRIMARY KEY (guid, source_type, source_id)
);

-- Spec item mappings
CREATE TABLE dc_spec_items (
    item_entry INT UNSIGNED NOT NULL,
    class_id TINYINT UNSIGNED NOT NULL,
    spec_id TINYINT UNSIGNED NOT NULL,  -- 0 = all specs
    stat_priority ENUM('primary', 'secondary', 'tertiary') DEFAULT 'primary',
    PRIMARY KEY (item_entry, class_id, spec_id)
);
```

### Smart Loot Manager (C++)
```cpp
class SmartLootManager
{
public:
    static SmartLootManager* instance();
    
    // Loot generation
    std::vector<LootItem> GeneratePersonalLoot(Player* player, Creature* source);
    std::vector<LootItem> GenerateMythicPlusLoot(Player* player, uint32 keyLevel);
    
    // Spec filtering
    bool IsItemForSpec(uint32 itemEntry, uint8 classId, uint8 specId) const;
    std::vector<uint32> GetSpecAppropriateItems(Player* player, LootTemplate const* lootTable) const;
    
    // Duplicate protection
    float GetDuplicateProtectionMod(Player* player, uint32 itemEntry) const;
    void RecordLoot(Player* player, uint32 itemEntry, uint16 itemLevel, LootSourceType source);
    
    // Bonus rolls
    bool CanBonusRoll(Player* player) const;
    uint32 GetBonusRollCost() const;
    LootItem* PerformBonusRoll(Player* player, Creature* source);
    void ConsumesBonusRoll(Player* player);
    
    // Trading
    bool CanTradeLoot(Player* player, Item* item, Player* target) const;
    void TrackTrade(Player* from, Player* to, uint32 itemEntry);
    
    // Bad luck protection
    void IncrementBadLuck(Player* player, LootSourceType type, uint32 sourceId);
    void ResetBadLuck(Player* player, LootSourceType type, uint32 sourceId);
    float GetBadLuckBonus(Player* player, LootSourceType type, uint32 sourceId) const;
    
private:
    std::unordered_map<uint32, SpecItemData> _specItems;
    
    void LoadSpecItems();
    bool RollForItem(Player* player, LootItem const& item, float bonusMod) const;
};

#define sSmartLootMgr SmartLootManager::instance()
```

### Spec Detection
```cpp
uint8 SmartLootManager::GetPlayerSpec(Player* player) const
{
    // Detect current spec from talent tree
    uint8 primarySpec = 0;
    uint32 maxPoints = 0;
    
    for (uint8 spec = 0; spec < MAX_TALENT_SPECS; ++spec)
    {
        uint32 points = player->GetTalentPointsInSpec(spec);
        if (points > maxPoints)
        {
            maxPoints = points;
            primarySpec = spec;
        }
    }
    
    return primarySpec;
}

// Stat priority mapping
StatPriority SmartLootManager::GetStatPriority(uint8 classId, uint8 specId) const
{
    // Returns primary stat (str, agi, int, spirit) for spec
    static std::map<std::pair<uint8, uint8>, StatPriority> priorities = {
        {{WARRIOR, WARRIOR_ARMS}, {STRENGTH, CRIT, HASTE}},
        {{WARRIOR, WARRIOR_PROT}, {STRENGTH, STAMINA, DEFENSE}},
        {{PALADIN, PALADIN_HOLY}, {INTELLECT, SPIRIT, HASTE}},
        {{PALADIN, PALADIN_PROT}, {STRENGTH, STAMINA, DEFENSE}},
        {{PALADIN, PALADIN_RET}, {STRENGTH, CRIT, HASTE}},
        // ... more mappings
    };
    
    return priorities[{classId, specId}];
}
```

---

## Bonus Roll Interface

```lua
-- Bonus Roll Frame (AIO Addon)
local BonusRollFrame = CreateFrame("Frame", "DCBonusRoll", UIParent)

function BonusRollFrame:Show(lootSource)
    -- Show bonus roll button
    -- Display token cost
    -- Countdown timer (10 seconds to decide)
end

function BonusRollFrame:OnRollClick()
    -- Validate player has tokens
    -- Send bonus roll request
    -- Play roll animation
    -- Show result (item or consolation)
end
```

---

## Configuration

```conf
# worldserver.conf
SmartLoot.Enable = 1
SmartLoot.PersonalLoot = 1          # Enable personal loot
SmartLoot.SpecFiltering = 1         # Filter by spec
SmartLoot.DuplicateProtection = 1   # Enable dup protection
SmartLoot.BonusRolls = 1            # Enable bonus rolls
SmartLoot.BonusRollCost = 50        # Tokens per roll
SmartLoot.BonusRollsPerWeek = 3     # Max weekly rolls
SmartLoot.TradeWindow = 2           # Hours to trade loot
SmartLoot.BadLuckProtection = 1     # Enable BLP
SmartLoot.BadLuckMax = 10           # Max BLP bonus %
```

---

## Commands

### Player Commands
```
.loot spec <primary|offspec|all>  - Set loot spec preference
.loot history                      - Show recent loot
.loot bonusrolls                   - Show remaining bonus rolls
.loot settings                     - Show loot settings
```

### GM Commands
```
.loot grant <player> <rolls>       - Grant bonus rolls
.loot reset <player> blp           - Reset bad luck protection
.loot simulate <creature>          - Simulate loot drop
```

---

## Loot Flow

```
1. Boss dies / Chest opened
2. For each player:
   a. Generate personal loot pool
   b. Filter by spec
   c. Apply duplicate protection
   d. Apply bad luck protection
   e. Roll for each item
   f. Award drops
3. Offer bonus roll (if available)
4. Start trade timer
5. Log loot history
```

---

## Timeline

| Task | Duration |
|------|----------|
| Database schema | 2 hours |
| SmartLootManager | 4 days |
| Spec filtering system | 2 days |
| Duplicate protection | 2 days |
| Bonus roll system | 2 days |
| Bad luck protection | 1 day |
| Trade tracking | 1 day |
| AIO addon UI | 2 days |
| Testing | 3 days |
| **Total** | **~3 weeks** |

---

## Future Enhancements

1. **Loot Council Integration** - For guild raids
2. **Wish List** - Prioritize certain items
3. **Group Loot Analysis** - Post-run loot summary
4. **Transmog Mode** - Loot for appearances
5. **Token Consolation** - Get tokens on failed rolls
