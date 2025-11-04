# Item Upgrade System: Technical Deep-Dive & Solutions
## Addressing Key Architecture Decisions

**Date:** November 4, 2025  
**Document Type:** Technical Analysis & Solutions  
**Status:** Critical Design Decisions

---

## 🎯 PROBLEM 1: Multiple Item Entries for Each iLvL

### **The Challenge**
```
Traditional Approach (BLOATED):
Item Table: 50000 items × 6 iLvL levels = 300,000 entries
├─ Heroic Chestplate (226)      → Entry 50000
├─ Heroic Chestplate (230)      → Entry 50001
├─ Heroic Chestplate (234)      → Entry 50002
├─ Heroic Chestplate (238)      → Entry 50003
├─ Heroic Chestplate (242)      → Entry 50004
└─ Heroic Chestplate (246)      → Entry 50005

Problem: item_template becomes massive!
```

### **Solution 1: Track Upgrade Level in Player Inventory (RECOMMENDED)**

```cpp
// BEST SOLUTION: Store upgrade level in item custom fields

// In character database:
CREATE TABLE item_instance_upgrades (
    item_guid INT UNIQUE PRIMARY KEY,
    upgrade_level TINYINT DEFAULT 0,          // 0-5
    max_upgrade_level TINYINT DEFAULT 5,      // Per track
    base_item_entry INT,                       // Original item ID
    track_id INT,
    created_date TIMESTAMP
);

// When displaying item:
QUERY: SELECT upgrade_level FROM item_instance_upgrades WHERE item_guid = {guid}
APPLY: GetItemIlvl = base_ilvl + (upgrade_level × 4)

// Advantages:
✅ Single item entry needed (50000, not 50000-50005)
✅ No item_template bloat
✅ Scales to unlimited items
✅ Upgrade level displayed in tooltip
✅ Can show progress bar
```

### **How to Display Upgrade Level**

```cpp
// In ItemTemplate tooltip generation:

void Item::SetUpgradeDisplay() {
    uint32 upgradeLevel = GetUpgradeLevel();  // 0-5
    
    if (upgradeLevel > 0) {
        // Show in tooltip
        std::string tooltip = GetTooltip();
        tooltip += "\n|cFFFFFF00Upgraded:|r " + std::to_string(upgradeLevel) + "/5";
        
        // Show iLvL progression
        uint32 baseIlvl = GetTemplate()->ItemLevel;
        uint32 currentIlvl = baseIlvl + (upgradeLevel * 4);
        tooltip += "\n|cFF00FF00Item Level:|r " + std::to_string(currentIlvl);
        
        // Show next upgrade cost
        if (upgradeLevel < 5) {
            tooltip += "\n|cFFFFFF00Next upgrade:|r " + std::to_string(baseIlvl + ((upgradeLevel + 1) * 4)) + " iLvL";
        }
    }
}

// Client-side (Lua):
function ItemUpgrade:ShowItemTooltip(itemLink)
    local upgradeLevel = GetItemUpgradeLevel(itemGUID)  -- From server
    local baseIlvl = GetItemInfo(itemLink)
    local currentIlvl = baseIlvl + (upgradeLevel * 4)
    
    GameTooltip:AddLine("Upgrade Level: " .. upgradeLevel .. "/5", 1, 1, 0)
    GameTooltip:AddLine("Item Level: " .. currentIlvl, 0, 1, 0)
end
```

### **Visual Display Options**

```
Option A: Chat Message
"Your Heroic Chestplate is now Upgrade Level 3 (iLvL 238/246)"

Option B: Tooltip Addition
Heroic Chestplate of the Eternal
Item Level: 238
Rarity: Epic
Upgrade Level: 3/5 [████░]
Next upgrade: +4 iLvL (242)
Cost: 10 Tokens

Option C: UI Icon Overlay
[Item Icon]
3/5 ← shown in corner

Option D: Armor window
Equipment shows iLvL, equipment pane shows "[Upgrade 3/5]"
```

---

## 🎯 PROBLEM 2: Heirloom-like System with Minimum Stats

### **The Concept**
```
Current approach:
- Item at iLvL 226 has fixed stats
- Upgrade to 230 creates NEW item with higher stats

Heirloom approach:
- SAME item scales with upgrades
- Stats stored per character/item instance
- Single item entry level for all upgrades
```

### **Solution: Dynamic Item Stats Based on Upgrade Level**

```sql
-- New table: Store per-item stats
CREATE TABLE item_instance_stats (
    item_guid INT UNIQUE PRIMARY KEY,
    upgrade_level TINYINT,
    base_strength INT,
    base_agility INT,
    base_stamina INT,
    base_intellect INT,
    base_spirit INT,
    stat_multiplier FLOAT,         -- Scales with upgrade level
    created_date TIMESTAMP
);

-- Calculate stats for each upgrade level:
-- Level 0: base * 1.0
-- Level 1: base * 1.1
-- Level 2: base * 1.2
-- Level 3: base * 1.3
-- Level 4: base * 1.4
-- Level 5: base * 1.5
```

### **Implementation: Item Stat Scaling**

```cpp
// In Item.cpp

uint32 Item::GetStatValue(uint32 statType) {
    // Get base stat from item_template
    uint32 baseStat = GetTemplate()->GetStat(statType);
    
    // Get upgrade level and multiplier
    uint32 upgradeLevel = GetUpgradeLevel();
    float statMultiplier = 1.0f + (upgradeLevel * 0.1f);  // 1.0 → 1.5
    
    // Calculate final stat
    uint32 finalStat = (uint32)(baseStat * statMultiplier);
    
    return finalStat;
}

// Apply to all stats:
// Strength:    base × (1.0 + upgrade × 0.1)
// Agility:     base × (1.0 + upgrade × 0.1)
// Stamina:     base × (1.0 + upgrade × 0.1)
// Intellect:   base × (1.0 + upgrade × 0.1)
// Spirit:      base × (1.0 + upgrade × 0.1)

// Example:
// Base Strength: 100
// Upgrade Level 0: 100 × 1.0 = 100
// Upgrade Level 1: 100 × 1.1 = 110
// Upgrade Level 2: 100 × 1.2 = 120
// Upgrade Level 3: 100 × 1.3 = 130
// Upgrade Level 4: 100 × 1.4 = 140
// Upgrade Level 5: 100 × 1.5 = 150
```

### **Why This Beats Multiple Entries**

| Aspect | Multiple Entries | Heirloom Scaling |
|--------|------------------|------------------|
| Database Size | 300k+ entries | 50k entries |
| Memory Usage | High | Low |
| Loot Generation | Simple | Simple |
| Upgrades | Swap item | Update stats |
| Flexibility | Fixed stats | Dynamic stats |
| Future Changes | Recreate all | Just adjust multiplier |
| Player Experience | Visually new item | Same item scales |

---

## 🎯 PROBLEM 3: Item Template & Item.DBC Bloat

### **The Problem**
```
Current DBC system:
- item.dbc has 1 entry per item
- Each upgrade = new DBC entry
- Client redownloads on every change
- Database balloon
```

### **Solution: Client-Side Calculation (BEST)**

```cpp
// Approach: Store upgrade level, calculate stats client-side

// Server sends:
struct ItemData {
    uint32 itemEntry;              // Single entry (e.g., 50000)
    uint32 upgradeLevel;           // 0-5 (calculated from DB)
    uint32 enchantmentId;
    uint32 randomPropertyId;
    uint32 baseStamina;            // Multiplied by upgrade
    uint32 baseIntellect;          // Multiplied by upgrade
};

// Client receives item and calculates:
function GetItemStats(itemData)
    local multiplier = 1.0 + (itemData.upgradeLevel * 0.1)
    return {
        stamina = itemData.baseStamina * multiplier,
        intellect = itemData.baseIntellect * multiplier,
        -- etc
    }
end

// Result:
✅ Only 1 DBC entry per item (no bloat)
✅ No client update needed
✅ Server calculates, client displays
✅ Database stays lean
```

### **Alternative: Use Custom Enchantment-like System**

```sql
-- Store scaling as pseudo-enchantment:
-- Entry: Item ID
-- Enchantment: "Upgrade Level 3" = +30% stats

CREATE TABLE item_upgrade_enchantments (
    enchantment_id INT PRIMARY KEY,
    upgrade_level TINYINT,
    stat_multiplier FLOAT,
    display_name VARCHAR(100)
);

INSERT INTO item_upgrade_enchantments VALUES
(10001, 1, 1.1, 'Upgraded [+1]'),
(10002, 2, 1.2, 'Upgraded [+2]'),
(10003, 3, 1.3, 'Upgraded [+3]'),
(10004, 4, 1.4, 'Upgraded [+4]'),
(10005, 5, 1.5, 'Upgraded [+5]');

-- Item has enchantment_id = upgrade level's enchantment
-- Client reads enchantment and applies multiplier
```

---

## 🎯 PROBLEM 4: Selling/Scrapping Items Back to Tokens

### **The Challenge**
```
How do we prevent:
- Farming low-content items, upgrading, selling for profit?
- Duplicate tokens from flipping?
- Economic collapse?

Formula needed:
- What's the buyback value?
- How does it scale?
- When can players sell?
```

### **Solution: Smart Scrapping System**

```cpp
// Scrap Value Calculator

uint32 CalculateScrappingValue(Item* item, Player* player) {
    uint32 baseTokenValue = 5;        // Base value per rarity tier
    uint32 upgradeLevel = GetUpgradeLevel(item);
    uint32 iLvl = GetItemIlvl(item);
    
    // Calculate earned tokens:
    // If item came from boss: earned_tokens based on difficulty
    // If item upgraded: earned_tokens = upgrades × cost
    
    QueryResult earned = CharacterDatabase.Query(
        "SELECT tokens_spent FROM item_instance_upgrades WHERE item_guid = %u",
        item->GetGUID()
    );
    
    if (earned) {
        uint32 tokensSpent = earned->Fetch()[0].Get<uint32>();
        // Return 50% of upgrade investment
        return tokensSpent / 2;
    } else {
        // First-time scrapping (never upgraded)
        // Return 25% of original boss drop value
        uint32 bossValue = CalculateBossDropValue(item);
        return bossValue / 4;
    }
}

// Example:
// Boss drops item (worth 5 tokens) - player gets nothing for scrapping
// Player upgrades 3 times (30 tokens spent) - scrap for 15 tokens
// Player upgrades 5 times (100 tokens spent) - scrap for 50 tokens

// Rules to prevent farming:
✅ Can only scrap items in town (NPC-only)
✅ Cooldown: 1 scrap per item per 24 hours
✅ Cannot scrap items in progress (upgrading)
✅ Log all scraps for audit trail
✅ Weekly scrap cap per player (e.g., 500 tokens/week)
```

### **Scrapping Formula Tiers**

```
Tier 1: Never Upgraded
├─ Value = 0 tokens (no investment, no refund)

Tier 2: Upgraded 1-2 Times
├─ Value = 20% of upgrade cost
├─ Example: 20 tokens spent → 4 tokens back

Tier 3: Upgraded 3-4 Times
├─ Value = 30% of upgrade cost
├─ Example: 40 tokens spent → 12 tokens back

Tier 4: Fully Upgraded (5 times)
├─ Value = 50% of upgrade cost
├─ Example: 100 tokens spent → 50 tokens back

Rarity Multiplier:
├─ Uncommon: 0.5×
├─ Rare: 1.0×
├─ Epic: 1.5×
├─ Legendary: 2.0×

Slot Multiplier:
├─ Accessories: 0.8×
├─ Medium slots: 1.0×
├─ Heavy slots (chest/head/legs): 1.2×
```

### **Implementation: Scrapping NPC**

```cpp
// NPC "Scrapper" function

bool NPC_Scrapper::OnGossipSelect(Player* player, Creature* creature, 
                                  uint32 action) {
    Item* item = GetItemFromAction(action);
    if (!item) return false;
    
    // Verify item is scrappable
    if (!CanScrapItem(item, player)) {
        SendGossipMenu("Item cannot be scrapped", player, creature);
        return false;
    }
    
    // Calculate value
    uint32 tokenValue = CalculateScrappingValue(item, player);
    
    if (tokenValue == 0) {
        SendGossipMenu("This item has no scrap value", player, creature);
        return false;
    }
    
    // Show confirmation
    std::string confirm = "Scrap " + item->GetName() + 
                         " for " + std::to_string(tokenValue) + " tokens?";
    
    player->ADD_GOSSIP_ITEM(GOSSIP_ICON_CHAT, "Yes, scrap it", action, 1);
    player->ADD_GOSSIP_ITEM(GOSSIP_ICON_CHAT, "No, keep it", action, 2);
    
    player->SEND_GOSSIP_MENU(confirm, creature->GetGUID());
    return true;
}

// On confirmation:
void PerformScrap(Item* item, Player* player, uint32 tokenValue) {
    // Remove item
    player->RemoveItem(item->GetBagSlot(), item->GetSlot(), true);
    
    // Award tokens
    sItemUpgradeManager->AddTokens(player->GetGUID(), tokenValue, "Item scrapped");
    
    // Log transaction
    LOG_INFO("item_scrap", "Player %s scrapped item %u for %u tokens",
        player->GetName().c_str(), item->GetEntry(), tokenValue);
    
    // Notify player
    player->GetSession()->SendNotification("Item scrapped for %u tokens!", tokenValue);
}
```

---

## 🎯 PROBLEM 5: Loot Tables with Basic Items

### **Loot Pool Based Approach (RECOMMENDED)**

```sql
-- Create loot pools per difficulty/track

CREATE TABLE item_loot_pool (
    pool_id INT PRIMARY KEY AUTO_INCREMENT,
    pool_name VARCHAR(100),
    track_id INT,
    difficulty VARCHAR(50),
    boss_id INT,
    
    item_entry INT,           -- What item to drop
    min_count TINYINT DEFAULT 1,
    max_count TINYINT DEFAULT 1,
    chance FLOAT,             -- 0-1 (e.g., 0.1 = 10% chance)
    quest_required INT,       -- NULL if always available
    
    active BOOLEAN DEFAULT TRUE,
    season INT DEFAULT 0
);

-- Example: Heroic Dungeon Boss Loot
INSERT INTO item_loot_pool VALUES
(1, 'Heroic Boss Chest', 2, 'heroic', 100001,
 50000,  -- Heroic Chestplate (base iLvL 226)
 1, 1, 0.3, NULL, TRUE, 0),
 
(2, 'Heroic Boss Head', 2, 'heroic', 100001,
 50010,  -- Heroic Crown (base iLvL 226)
 1, 1, 0.25, NULL, TRUE, 0),
 
(3, 'Heroic Boss Legs', 2, 'heroic', 100001,
 50020,  -- Heroic Legs (base iLvL 226)
 1, 1, 0.25, NULL, TRUE, 0);

-- Example: Mythic Boss Loot (better items)
INSERT INTO item_loot_pool VALUES
(4, 'Mythic Boss Chest', 3, 'mythic', 100002,
 50000,  -- Mythic Chestplate (base iLvL 239)
 1, 1, 0.3, NULL, TRUE, 0);
```

### **Advantages of Loot Pool Approach**

```
✅ Difficulty-based loot progression
✅ Easy to adjust drop rates
✅ Can exclude items per boss
✅ Supports multiple drops
✅ Easy to add/remove items
✅ Track which items drop where
✅ Easy to rebalance seasonally
✅ Supports quest requirements

Traditional Approach Problems:
❌ Hard-coded drop chances
❌ Difficult to adjust balance
❌ Must restart server to change
❌ Difficult to track by difficulty
```

### **Implementation: Difficulty-Aware Loot**

```cpp
// In Loot.cpp or CreatureLoot.cpp

void Creature::GenerateLoot() {
    uint32 difficulty = GetMap()->GetDifficulty();
    uint32 creatureEntry = GetEntry();
    
    // Query loot pool for this creature/difficulty
    QueryResult result = WorldDatabase.Query(
        "SELECT item_entry, chance FROM item_loot_pool "
        "WHERE boss_id = %u AND difficulty = '%s' AND active = TRUE",
        creatureEntry, GetDifficultyString(difficulty).c_str()
    );
    
    if (result) {
        do {
            Field* fields = result->Fetch();
            uint32 itemEntry = fields[0].Get<uint32>();
            float chance = fields[1].Get<float>();
            
            // Roll for drop
            if (rand() < (RAND_MAX * chance)) {
                loot->AddItem(itemEntry, 1, LootItemType::Normal);
            }
        } while (result->NextRow());
    }
}

// Different loot by difficulty:
// Heroic: iLvL 226 items, lower chance
// Mythic: iLvL 239 items, higher chance
// Raid Normal: iLvL 245 items
// Raid Heroic: iLvL 258 items
// Raid Mythic: iLvL 271 items
```

---

## 🎯 PROBLEM 6: Bracket-wise Creation (Level 100 → 130 → 160 → 200 → etc.)

### **The Challenge**
```
Current 3.3.5a:
- Max level: 80
- We added: Level 80-255 custom scaling

Item progression for 255 levels:
- Level 80-100: iLvL 226-240
- Level 100-130: iLvL 240-260
- Level 130-160: iLvL 260-280
- Level 160-200: iLvL 280-300
- Level 200-255: iLvL 300-320

Question: How to create items for each bracket?
```

### **Solution: Mass Creation with Brackets**

```sql
-- Create bracket table
CREATE TABLE item_level_brackets (
    bracket_id INT PRIMARY KEY AUTO_INCREMENT,
    bracket_name VARCHAR(100),
    player_level_min INT,
    player_level_max INT,
    item_level_start INT,
    item_level_end INT,
    active BOOLEAN DEFAULT TRUE
);

-- Insert brackets
INSERT INTO item_level_brackets VALUES
(1, 'Leveling 80-100', 80, 100, 226, 250, TRUE),
(2, 'Leveling 100-130', 100, 130, 250, 275, TRUE),
(3, 'Leveling 130-160', 130, 160, 275, 300, TRUE),
(4, 'Leveling 160-200', 160, 200, 300, 325, TRUE),
(5, 'Endgame 200-255', 200, 255, 325, 350, TRUE);
```

### **Mass Creation Strategy: Use Existing Items as Templates**

```python
#!/usr/bin/env python3
"""
Generate item brackets from existing items
"""

def generate_items_for_bracket(base_item_id, bracket_id, target_ilvl_range):
    """
    Generate items for entire bracket
    
    Usage:
    - Input: Base item template (e.g., 50000 = Heroic Chestplate 226 iLvL)
    - Output: New items for target bracket
    - Calculation: Scale stats based on new iLvL
    """
    
    base_item = get_item_template(base_item_id)
    new_bracket_items = []
    
    for new_ilvl in range(target_ilvl_range['min'], target_ilvl_range['max'] + 1, 4):
        # Calculate stat scaling
        ilvl_diff = new_ilvl - base_item['item_level']
        stat_multiplier = 1.0 + (ilvl_diff / 100.0)  # +1% per iLvL
        
        # Create new item
        new_item = {
            'entry': generate_new_entry_id(),
            'name': base_item['name'] + f' [{new_ilvl}]',
            'item_level': new_ilvl,
            'quality': base_item['quality'],
            'class': base_item['class'],
            'subclass': base_item['subclass'],
            
            # Scale stats
            'stamina': int(base_item['stamina'] * stat_multiplier),
            'intellect': int(base_item['intellect'] * stat_multiplier),
            'strength': int(base_item['strength'] * stat_multiplier),
            'armor': int(base_item['armor'] * stat_multiplier),
            
            'bracket_id': bracket_id,
        }
        
        new_bracket_items.append(new_item)
    
    return new_bracket_items

# Example:
# Generate items for level 100-130 bracket
# Start with Heroic Chestplate (50000, iLvL 226)
# Create versions at iLvL: 250, 254, 258, 262, 266, 270, 274
items = generate_items_for_bracket(
    base_item_id=50000,
    bracket_id=2,
    target_ilvl_range={'min': 250, 'max': 275}
)

# Generate SQL
for item in items:
    print(f"INSERT INTO item_template VALUES ({item['entry']}, ...)")
```

### **Practical Mass Creation Approach**

```bash
# Step 1: Export base items from 3.3.5a DB
mysql darkchoas_world -e "
SELECT entry, name, item_level, class, subclass, ...
FROM item_template
WHERE item_level BETWEEN 226 AND 239
AND quality = 4
" > base_items.csv

# Step 2: Run Python script to generate all brackets
python generate_brackets.py \
    --input base_items.csv \
    --brackets 5 \
    --ilvl-step 4 \
    --output bracket_items.sql

# Step 3: Import generated items
mysql darkchoas_world < bracket_items.sql

# Result: Auto-generated items for all 5 brackets
```

### **Don't Create Manually - Automate It**

```
BAD ❌:
- Manually create 300+ items
- Copy/paste stats
- Easy to make mistakes
- Takes days

GOOD ✅:
- Write script once (2 hours)
- Run for all brackets (5 minutes)
- Consistent quality
- Reproducible
```

---

## 🎯 INTEGRATED SOLUTION: All Problems Together

### **Complete Item Lifecycle**

```
1. CREATION
   ↓
   Use automated bracket script
   Generate items for all 5 level brackets
   Result: 500-1000 unique items (all brackets)

2. DROP (from boss)
   ↓
   Difficulty-aware loot pool
   Boss in Heroic: drop iLvL 226 items
   Boss in Mythic: drop iLvL 239 items
   Result: Player gets base item at correct iLvL

3. DISPLAY
   ↓
   Single item entry in database
   Upgrade level stored per player item
   Client calculates stats: base × (1.0 + upgrade × 0.1)
   Tooltip shows: "Upgrade Level 3/5" + iLvL + stats
   Result: No bloat in item_template

4. UPGRADE
   ↓
   Player visits NPC with item
   Pay tokens + flightstones
   Server updates upgrade_level in DB
   Client recalculates stats
   Result: Same item, higher stats

5. SELL/SCRAP
   ↓
   Player visits Scrapper NPC
   Sell upgraded item for partial token refund
   Formula: 50% of upgrade cost
   Result: Economic balance, no farming

6. NEXT BRACKET
   ↓
   Player reaches level 100+
   Gets better items from higher bracket bosses
   Repeats upgrade cycle
   Result: 255 levels of continuous progression
```

### **Database Size Comparison**

```
Traditional Approach (BLOATED):
├─ 5 brackets × 200 items × 6 iLvL = 6,000 entries
└─ Plus all existing 3.3.5a items = 10,000+ entries

Smart Approach (LEAN):
├─ 5 brackets × 200 items × 1 entry = 1,000 entries
├─ Plus all existing 3.3.5a items = 5,000+ entries
└─ Upgrade levels stored per player (small table)

Savings: 50% item_template bloat reduction
```

---

## 📋 FINAL ARCHITECTURE SUMMARY

### **The Stack**

```
┌─────────────────────────────────────────────────────┐
│           CLIENT (WoW Game)                         │
│  - Displays item with tooltip                       │
│  - Shows upgrade level: 3/5                         │
│  - Calculates displayed stats                       │
└──────────────────┬──────────────────────────────────┘
                   │
        (Send upgrade request)
                   ↓
┌─────────────────────────────────────────────────────┐
│           SERVER (AzerothCore)                      │
│  - Process upgrade command                          │
│  - Update item_instance_upgrades table              │
│  - Send back new upgrade level                      │
└──────────────────┬──────────────────────────────────┘
                   │
        (Return success + new level)
                   ↓
┌─────────────────────────────────────────────────────┐
│    DATABASE (MySQL - Lean & Mean)                   │
│                                                     │
│  item_template (1,000 entries)                      │
│  ├─ Single entry per item                          │
│  └─ Base stats only                                │
│                                                     │
│  item_instance_upgrades (per player)                │
│  ├─ item_guid → upgrade_level (0-5)                │
│  ├─ Minimal storage                                │
│  └─ Fast lookup                                    │
│                                                     │
│  item_loot_pool                                    │
│  ├─ Define drops per difficulty                    │
│  └─ Easy to adjust                                 │
│                                                     │
│  player_currencies                                 │
│  ├─ upgrade_tokens balance                         │
│  ├─ flightstones balance                           │
│  └─ Weekly tracking                                │
└─────────────────────────────────────────────────────┘
```

---

## ✅ QUICK CHECKLIST: All Problems Solved

```
[✅] Multiple iLvL versions
    Solution: Track upgrade_level in character DB (not multiple item entries)

[✅] Display upgrade level
    Solution: Tooltip + UI shows "Upgrade Level 3/5"

[✅] Heirloom-like system
    Solution: Dynamic stat scaling with multiplier (1.0 → 1.5)

[✅] Item.DBC bloat
    Solution: Single item entry, client calculates display

[✅] Character DB instead of item template
    Solution: Store upgrade_level in item_instance_upgrades table

[✅] Sell/scrap items back
    Solution: Scrapper NPC + formula (50% of upgrade cost)

[✅] Good loot tables
    Solution: Difficulty-aware loot pools (pool-based by difficulty)

[✅] Bracket-wise item creation
    Solution: Mass creation script (automated, not manual)
```

---

## 🚀 IMPLEMENTATION ORDER

1. **Phase 1:** Create bracket structure (SQL)
2. **Phase 2:** Mass-generate items via script
3. **Phase 3:** Create loot pools (SQL)
4. **Phase 4:** Implement upgrade_level storage (DB table)
5. **Phase 5:** Implement tooltip display (C++ + Lua)
6. **Phase 6:** Implement stat scaling (C++ backend)
7. **Phase 7:** Implement scrapping system (NPC + formula)
8. **Phase 8:** Testing + balancing

**Total time: 40-60 hours additional from original design**

---

*Document compiled: November 4, 2025*  
*Item Upgrade System: Deep-Dive Solutions*  
*Status: Ready for Implementation*
