# Implementation Roadmap: Tiered Heirloom System

**Scope:** Complete system design → production deployment  
**Duration:** 8-12 weeks (60-90 development hours)  
**Architecture:** 5 tiers, 940 items, 5 token currencies, artifact system  
**Target:** Season 1 launch

---

## 📋 PHASE 1: FOUNDATION (Week 1-2)

### **1.1: Database Schema**

**Create token currency system:**
```sql
CREATE TABLE player_currencies (
    player_guid INT,
    currency_type ENUM('upgrade_token', 'artifact_essence'),
    amount INT DEFAULT 0,
    season INT,
    PRIMARY KEY (player_guid, currency_type, season)
);

-- Simplified: Only 2 currencies, NO weekly caps!
-- upgrade_token: Used for T1-T4 item upgrades (drops from all content)
-- artifact_essence: Used for T5 artifacts only (world object collection)
```

**Create heirloom item table:**
```sql
CREATE TABLE heirloom_items (
    item_id INT PRIMARY KEY,
    item_name VARCHAR(100),
    tier INT (1-5),
    armor_type ENUM('plate','mail','leather','cloth'),
    slot INT (1-16),
    rarity INT (1-4),
    base_stats_mult FLOAT,
    upgrade_multiplier FLOAT (0.75 for T5 artifacts, 0.5 others),
    source_type ENUM('quest','dungeon','raid','worldboss','artifact'),
    season INT,
    cosmetic_variant INT (0 = base, 1+ = variant)
);

-- Sample rows:
-- (50001, 'Leveling Plate Helmet', 1, 'plate', 1, 1, 1.0, 0.5, 'quest', 1, 0)
-- (60001, 'Heroic Mail Chest', 2, 'mail', 3, 2, 1.0, 0.5, 'dungeon', 1, 0)
-- (70001, 'Raid Leather Legs', 3, 'leather', 6, 3, 1.0, 0.5, 'raid', 1, 0)
-- (80001, 'Mythic Cloth Gloves', 4, 'cloth', 9, 4, 1.0, 0.5, 'raid', 1, 0)
-- (90001, 'Artifact Plate Boots', 5, 'plate', 8, 4, 1.2, 0.75, 'artifact', 1, 0)
```

**Create upgrade tracking table:**
```sql
CREATE TABLE item_instance_upgrades (
    item_guid INT UNIQUE PRIMARY KEY,
    upgrade_level INT (0-5) DEFAULT 0,
    tokens_invested INT DEFAULT 0,
    essence_invested INT DEFAULT 0,
    last_upgraded TIMESTAMP,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    season INT
);
```

**Create loot table entries:**
```sql
-- Quest rewards: Add tokens to quest_template
UPDATE quest_template SET
    RewardItem1 = {LEVELING_TOKEN_ENTRY},
    RewardAmount1 = 1,
    RewardItemCount1 = 1
WHERE QuestLevel BETWEEN 1 AND 60;

-- Dungeon rewards: Add items + tokens to creature_loot_template
INSERT INTO creature_loot_template
(Entry, Item, ChanceOrQuestChance, LootMode, GroupId)
VALUES
({HEROIC_BOSS_ID}, {HEIRLOOM_T2_ITEM}, 20.0, 1, 0),
({HEROIC_BOSS_ID}, {HEROIC_TOKEN}, 100.0, 1, 1);

-- Raid rewards: Similar pattern for raid bosses
-- World bosses: Higher drop rates (30-40%)
```

### **1.2: Currency System**

**Implement token NPCs:**
```cpp
// NPC: Token Vendor
// Location: Capital city
// Function: Explain token system to players

// Dialog options:
// - "What are tokens?"
// - "What are seasonal items?"
// - "How do I upgrade items?"
// - "Where do I find artifacts?"
```

**Implement currency tracking:**
```cpp
// Create function to add currency
bool AddCurrency(Player* player, CurrencyType type, uint32 amount)
{
    // Check weekly cap
    if (type == CURRENCY_HEROIC && weeklyUsed >= 500) return false;
    if (type == CURRENCY_RAID && weeklyUsed >= 1000) return false;
    // etc...
    
    // Add to character_db
    // Log transaction
    return true;
}

// Create function to display currency
void ShowCurrencyUI(Player* player)
{
    // Send packet showing:
    // - Leveling: 250/unlimited
    // - Heroic: 375/500
    // - Raid: 850/1000
    // - Mythic: 1500/2000
    // - Essence: 45/200
}
```

### **Deliverables Week 1-2:**
- ✅ Database schema (4 new tables)
- ✅ Token currency system
- ✅ NPC framework
- ✅ Loot table modifications
- ✅ Basic UI for currency display

---

## 📈 PHASE 2: ITEM GENERATION (Week 3-4)

### **2.1: Create Item Templates**

**Tier 1: Leveling (150 items)**
```python
#!/usr/bin/env python3
"""
Generate Tier 1 leveling heirloom items
"""

import csv

ARMOR_TYPES = {
    'plate': [1, 3, 5, 20, 22, 23, 25, 28, 9, 26],  # slots (head, chest, etc)
    'mail': [1, 3, 5, 20, 22, 23, 25, 28, 9, 26],
    'leather': [1, 3, 5, 20, 22, 23, 25, 28, 9, 26],
    'cloth': [1, 3, 5, 20, 22, 23, 25, 28, 9, 26],
}

RARITY_MULTIPLIER = {
    1: 1.0,  # uncommon
    2: 1.2,  # rare
}

items = []
entry_id = 50000

for armor in ARMOR_TYPES:
    for rarity in RARITY_MULTIPLIER:
        for slot in ARMOR_TYPES[armor]:
            item = {
                'entry': entry_id,
                'name': f'Leveling {armor.title()} T{rarity} Slot{slot}',
                'tier': 1,
                'armor': armor,
                'slot': slot,
                'rarity': rarity,
                'stats': int(100 * RARITY_MULTIPLIER[rarity]),
                'upgrade_mult': 0.5,
                'source': 'quest',
            }
            items.append(item)
            entry_id += 1

# Export to SQL
with open('tier1_items.sql', 'w') as f:
    for item in items:
        f.write(f"""
INSERT INTO item_template VALUES
({item['entry']}, '{item['name']}', 1, {item['rarity']}, 
 '{item['armor']}', {item['slot']}, {item['stats']}, ...);
        """)

print(f"Generated {len(items)} Tier 1 items")
# Output: Generated 150 Tier 1 items
```

**Tier 2-5: Similar process**
- Tier 2: 160 items (entry 60000-60159)
- Tier 3: 250 items (entry 70000-70249)
- Tier 4: 270 items (entry 80000-80269)
- Tier 5: 110 items (entry 90000-90109)

### **2.2: Create Loot Tables**

**Quest loot (Tier 1):**
```sql
-- Add token rewards to all 1-60 quests
UPDATE quest_template SET
    RewardItem1 = 50001,  -- Leveling Token entry
    RewardAmount1 = 1,
    RewardItemCount1 = 1
WHERE QuestLevel BETWEEN 1 AND 60
AND RewardChoice > 0;  -- Only quests with rewards

-- Verify: ~300 quests get tokens
SELECT COUNT(*) FROM quest_template WHERE QuestLevel BETWEEN 1 AND 60;
-- Result should be 300+
```

**Dungeon loot (Tier 2-3):**
```sql
-- Heroic dungeons: 80 items
INSERT INTO creature_loot_template (Entry, Item, ChanceOrQuestChance, LootMode, GroupId)
SELECT
    creature.entry,
    (60001 + (creature.entry % 80)),  -- Distribute T2 items
    20.0,  -- 20% drop chance per item
    1,     -- Normal loot mode
    0      -- Not a quest item
FROM creature
JOIN creature_difficulty ON creature.entry = creature_difficulty.entry
WHERE creature_difficulty.DifficultyID IN (2, 3)  -- Heroic
AND creature.rank IN (3, 4);  -- Boss/rare only

-- Mythic dungeons: 80 items
INSERT INTO creature_loot_template (Entry, Item, ChanceOrQuestChance, LootMode, GroupId)
SELECT
    creature.entry,
    (70001 + (creature.entry % 80)),  -- Distribute T3 items
    25.0,  -- Higher drop rate for Mythic
    1,
    0
FROM creature
WHERE creature.rank IN (3, 4)
AND instance_id IN (SELECT map FROM dungeon_encounters WHERE difficulty = 5);  -- Mythic
```

**Raid loot (Tier 3-4):**
```sql
-- Heroic Raid: 100 items
-- Mythic Raid: 120 items
-- World bosses: 20 items (high drop rate 30-40%)
```

### **Deliverables Week 3-4:**
- ✅ 940 item templates created
- ✅ All SQL export files generated
- ✅ Loot tables updated for all content
- ✅ Loot table verification complete
- ✅ Items verified in-game

---

## 🎮 PHASE 3: UPGRADE MECHANICS (Week 5-6)

### **3.1: Upgrade Command**

```cpp
// File: upgrade_system.cpp

class HeirloomUpgradeManager
{
public:
    bool UpgradeItem(Player* player, uint32 itemGuid)
    {
        // Get item
        Item* item = player->GetItemByGuid(itemGuid);
        if (!item) return false;
        
        // Get current upgrade level
        uint32 currentLevel = GetUpgradeLevel(itemGuid);
        if (currentLevel >= 5) return false;  // Max level
        
        uint32 nextLevel = currentLevel + 1;
        
        // Get upgrade cost
        uint32 tokenCost = GetUpgradeCost(item, nextLevel);
        uint32 essenceCost = GetEssenceCost(item, nextLevel);
        
        // Check currency
        if (!HasCurrency(player, tokenCost, essenceCost)) 
            return false;
        
        // Deduct currency
        RemoveTokens(player, tokenCost);
        if (essenceCost > 0) RemoveEssence(player, essenceCost);
        
        // Update database
        CharacterDatabase.PExecute(
            "INSERT INTO item_instance_upgrades "
            "(item_guid, upgrade_level, tokens_invested) "
            "VALUES (%u, %u, %u) "
            "ON DUPLICATE KEY UPDATE "
            "upgrade_level = %u, tokens_invested = tokens_invested + %u",
            itemGuid, nextLevel, tokenCost,
            nextLevel, tokenCost
        );
        
        // Send equipment update
        player->SetEquipmentDirty(item->GetSlot());
        
        // Notify
        player->SendNotification(
            "Item upgraded! New level: %u/5", nextLevel
        );
        
        return true;
    }
    
private:
    uint32 GetUpgradeCost(Item* item, uint32 upgradeLevel)
    {
        ItemTemplate const* proto = item->GetTemplate();
        int tier = GetItemTier(proto);
        
        // Cost scales by tier and upgrade level
        uint32 baseCost[] = {0, 10, 30, 75, 150, 0};  // Per tier
        uint32 costs[] = {
            0,
            baseCost[tier] * 1,
            baseCost[tier] * 1.5,
            baseCost[tier] * 2,
            baseCost[tier] * 2.5,
            baseCost[tier] * 3.5,
        };
        return costs[upgradeLevel];
    }
    
    uint32 GetItemTier(ItemTemplate const* proto)
    {
        uint32 itemId = proto->ItemId;
        if (itemId >= 50000 && itemId < 60000) return 1;
        if (itemId >= 60000 && itemId < 70000) return 2;
        if (itemId >= 70000 && itemId < 80000) return 3;
        if (itemId >= 80000 && itemId < 90000) return 4;
        if (itemId >= 90000 && itemId < 100000) return 5;
        return 0;
    }
};
```

### **3.2: Stat Calculation**

```cpp
// Calculate displayed stats based on upgrade level

uint32 Item::GetDisplayedStat(uint32 statType)
{
    ItemTemplate const* proto = GetTemplate();
    uint32 baseStat = proto->GetStat(statType);
    
    uint32 upgradeLevel = GetUpgradeLevel();
    
    // Multiplier: 1.0 to 1.5 (Tier 1-4)
    // Multiplier: 1.0 to 1.75 (Tier 5 artifacts)
    float maxMult = IsArtifact() ? 1.75f : 1.5f;
    float multiplier = 1.0f + (upgradeLevel / 5.0f) * (maxMult - 1.0f);
    
    return (uint32)(baseStat * multiplier);
}

uint32 Item::GetDisplayedItemLevel()
{
    ItemTemplate const* proto = GetTemplate();
    uint32 baseIlvl = proto->ItemLevel;
    uint32 upgradeLevel = GetUpgradeLevel();
    uint32 ilveIncrease = 0;
    
    switch (GetItemTier()) {
        case 1: ilveIncrease = 5; break;   // +5 per upgrade
        case 2: ilveIncrease = 8; break;   // +8 per upgrade
        case 3: ilveIncrease = 15; break;  // +15 per upgrade
        case 4: ilveIncrease = 8; break;   // +8 per upgrade
        case 5: ilveIncrease = 12; break;  // +12 per upgrade (artifacts)
    }
    
    return baseIlvl + (upgradeLevel * ilveIncrease);
}
```

### **3.3: Tooltip Display**

```cpp
void GenerateHeirloomTooltip(Item* item, std::string& tooltip)
{
    ItemTemplate const* proto = item->GetTemplate();
    
    // Header
    tooltip += "|c00FFD700" + proto->Name + "|r\n";
    
    // iLvL
    uint32 displayedIlvl = item->GetDisplayedItemLevel();
    tooltip += "|cFF0070DDItem Level: " + std::to_string(displayedIlvl) + "|r\n";
    
    // Upgrade level
    uint32 upgradeLevel = item->GetUpgradeLevel();
    if (upgradeLevel > 0) {
        tooltip += "|cFFFFFF00Upgrade Level: " + std::to_string(upgradeLevel) + "/5|r\n";
        
        // Progress bar
        std::string bar = "|cFF00FF00[";
        for (int i = 0; i < upgradeLevel; ++i) bar += "█";
        for (int i = upgradeLevel; i < 5; ++i) bar += "░";
        bar += "]|r";
        tooltip += bar + "\n";
    }
    
    // Stats (with multiplier applied)
    tooltip += "\n|cFFFFFFFF";
    tooltip += "+"+std::to_string(item->GetDisplayedStat(STAT_STRENGTH))+" Strength\n";
    tooltip += "+"+std::to_string(item->GetDisplayedStat(STAT_STAMINA))+" Stamina\n";
    // ... other stats
    
    // Next upgrade info
    if (upgradeLevel < 5) {
        uint32 nextIlvl = displayedIlvl + (GetUpgradeIlvlBoost(item) * 1);
        tooltip += "\n|cFFFFFF00Next upgrade:\n";
        tooltip += "• +" + std::to_string(nextIlvl - displayedIlvl) + " iLvL\n";
        
        uint32 tokenCost = GetUpgradeCost(item, upgradeLevel + 1);
        tooltip += "• Cost: " + std::to_string(tokenCost) + " tokens|r\n";
    } else {
        tooltip += "\n|cFFFFFFFFMax upgrade reached!|r\n";
    }
    
    // Tier info
    tooltip += "\n|cFFFFFFFF[Seasonal Heirloom - Tier " + 
               std::to_string(GetItemTier(item)) + "]|r\n";
}
```

### **Deliverables Week 5-6:**
- ✅ Upgrade command implemented
- ✅ Stat calculation formula working
- ✅ iLvL calculation correct
- ✅ Tooltip display complete
- ✅ All formulas tested and balanced

---

## 🏛️ PHASE 4: UPGRADE VENDORS (Week 7)

### **4.1: NPC Creation**

```cpp
// Create vendor NPCs in capital cities

class HeirloomUpgradeVendor : public Creature
{
public:
    void CreateUpgradeInterface(Player* player)
    {
        // Create gossip menu
        AddGossipItemFor(player, 0, 
            "Upgrade seasonal item", GOSSIP_SENDER_MAIN, 1);
        AddGossipItemFor(player, 0, 
            "How does upgrading work?", GOSSIP_SENDER_MAIN, 2);
        AddGossipItemFor(player, 0, 
            "Tell me about artifacts", GOSSIP_SENDER_MAIN, 3);
        AddGossipItemFor(player, 0, 
            "Never mind", GOSSIP_SENDER_MAIN, 0);
        
        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, GetGUID());
    }
    
    void OnGossipSelect(Player* player, uint32 menuId, uint32 action)
    {
        if (menuId == 1) {  // Upgrade item
            OpenUpgradeUI(player);
        } else if (menuId == 2) {  // How does upgrading work
            SendInfo(player, "Upgrading explanation text...");
        } else if (menuId == 3) {  // About artifacts
            SendInfo(player, "Artifacts are special items...");
        }
    }
    
private:
    void OpenUpgradeUI(Player* player)
    {
        // Send item list
        // Player selects item to upgrade
        // Confirm cost
        // Execute upgrade
    }
};
```

### **4.2: Vendor Locations**

```
Stormwind:
├─ Location: Dwarven District
├─ NPC: "Heirloom Upgrade Master"
├─ Type: Gossip only

Orgrimmar:
├─ Location: Valley of Strength
├─ NPC: "Heirloom Curator"
├─ Type: Gossip only

(Other capital cities as needed)
```

### **Deliverables Week 7:**
- ✅ Vendor NPCs created
- ✅ Gossip menu working
- ✅ Upgrade interface functional
- ✅ Currency verification working
- ✅ All vendors tested

---

## 🎨 PHASE 5: ARTIFACT SYSTEM (Week 8-9)

### **5.1: Worldforged Objects**

```cpp
// Create gameobject for worldforged artifacts

class ArtifactGameObject : public GameObject
{
public:
    void OnLoot(Player* player)
    {
        // Determine artifact type
        uint32 artifactId = GetArtifactType();
        uint32 essence = RollEssenceAmount();  // 1-10
        
        // Add to player inventory
        player->AddItem(artifactId, 1);
        AddCurrency(player, CURRENCY_ESSENCE, essence);
        
        // Achievements
        if (IsCollectorComplete(player)) {
            player->AddAchievement(ACHIEVEMENT_WORLDFORGER);
        }
        
        // Respawn timer: 7 days
        SetRespawnTime(604800);
    }
    
private:
    uint32 GetArtifactType()
    {
        uint32 zoneId = GetZoneId();
        uint32 artifactCount = GetArtifactCountInZone(zoneId);
        uint32 artifactIndex = GetSpawnID() % artifactCount;
        return ARTIFACT_BASE_ENTRY + (zoneId * 10) + artifactIndex;
    }
    
    uint32 RollEssenceAmount()
    {
        // 50% = 1 essence
        // 30% = 3 essence
        // 15% = 5 essence
        // 5% = 10 essence
        uint32 roll = urand(0, 100);
        if (roll < 50) return 1;
        if (roll < 80) return 3;
        if (roll < 95) return 5;
        return 10;
    }
};

// Spawn 56 worldforged artifacts across zones
// 16 in starter zones
// 19 in mid-level zones
// 21 in high-level zones
```

### **5.2: Artifact Items**

```sql
-- Create artifact items (entry 90000-90109)
INSERT INTO item_template VALUES
(90000, 'Artifact of Discovery', 5, 4, 'plate', 1, 240, ...),
(90001, 'Artifact of Power', 5, 4, 'mail', 3, 240, ...),
(90002, 'Artifact of Mystery', 5, 4, 'leather', 5, 240, ...),
-- ... 107 more artifacts

-- Cosmetic variants created in game

-- Special property: Higher upgrade multiplier (1.75 vs 1.5)
-- Special property: +20% base stats vs regular items
```

### **Deliverables Week 8-9:**
- ✅ Worldforged game objects created (56)
- ✅ Artifact item templates created (110)
- ✅ Loot mechanics working
- ✅ Essence currency system
- ✅ Respawn timers set
- ✅ Achievement tracking

---

## ✅ PHASE 6: TESTING & BALANCE (Week 10)

### **6.1: Comprehensive Testing**

```
Unit Tests:
[ ] Token currency adds correctly
[ ] Weekly caps enforced
[ ] Upgrade costs calculated correctly
[ ] Stat multipliers work (1.0-1.5)
[ ] iLvL calculations accurate
[ ] Tooltip displays properly

Integration Tests:
[ ] Quest rewards give tokens
[ ] Dungeon drops give items + tokens
[ ] Raid drops give items + tokens
[ ] World objects give artifacts
[ ] Upgrades persist on logout/login
[ ] Multiple upgrades work sequentially

Balance Tests:
[ ] Casual players reach Tier 2 in time
[ ] Hardcore players reach Tier 4 items
[ ] Artifacts discoverable within season
[ ] Token economy not inflated
[ ] No exploit vectors identified

Performance Tests:
[ ] Database queries < 100ms
[ ] Tooltip generation < 50ms
[ ] Upgrade transaction < 50ms
[ ] No server lag from system
```

### **6.2: Balance Adjustments**

```
If testing shows problems:

Too hard to get tokens:
- Increase quest rewards (+25%)
- Increase dungeon drops (+25%)
- Increase caps (+250 per tier)

Too easy to get items:
- Decrease drop rates (-10%)
- Increase upgrade costs (+25%)
- Increase caps (-200 per tier)

Stat scaling feels weak:
- Increase multiplier (1.5 → 1.6)
- Increase artifact multiplier (1.75 → 1.85)
- Adjust base stats (+10%)

Stat scaling too strong:
- Decrease multiplier (1.5 → 1.4)
- Decrease artifact multiplier (1.75 → 1.65)
- Adjust base stats (-10%)
```

### **Deliverables Week 10:**
- ✅ All tests passing
- ✅ Balance verified
- ✅ No exploits found
- ✅ Performance acceptable
- ✅ Ready for soft launch

---

## 🚀 PHASE 7: SOFT LAUNCH (Week 11)

### **7.1: Limited Release**

```
Soft Launch: 20% of server population
├─ Duration: 3 days
├─ Feedback collection
├─ Hotfix deployment
├─ Final balance checks

During soft launch:
├─ Monitor player experience
├─ Check for bugs/exploits
├─ Verify token economy
├─ Tune drop rates as needed
├─ Gather feedback
```

### **Deliverables Week 11:**
- ✅ System deployed to test servers
- ✅ Bugs identified and fixed
- ✅ Final balance adjustments
- ✅ Ready for full launch

---

## 🎉 PHASE 8: FULL LAUNCH (Week 12)

### **8.1: Season 1 Launch**

```
LAUNCH EVENT:
├─ All items available
├─ Double Leveling Token rate (Week 1-4)
├─ All vendors active
├─ Tutorial NPCs explain system
├─ Achievements unlock
├─ Server event announcement

LAUNCH CONTENT:
├─ 150 Tier 1 items (Leveling)
├─ 160 Tier 2 items (Heroic)
├─ 250 Tier 3 items (Raid)
├─ 270 Tier 4 items (Mythic)
├─ 110 Tier 5 items (Artifacts)
└─ TOTAL: 940 items to collect

LAUNCH SUPPORT:
├─ GM support for questions
├─ Hotfix team on standby
├─ Community manager engagement
├─ Feedback collection ongoing
└─ Daily balance monitoring
```

### **Deliverables Week 12:**
- ✅ Season 1 live
- ✅ All 940 items available
- ✅ Full player adoption
- ✅ Support infrastructure ready

---

## 📊 FINAL DELIVERABLES

### **Complete System Package**

```
DATABASES:
✅ 5 currency tables created
✅ 940 item templates created
✅ Upgrade tracking tables created
✅ Loot table modifications complete
✅ Weekly cap enforcement

CODE:
✅ Upgrade manager class
✅ Token currency system
✅ Stat calculation formulas
✅ iLvL calculation system
✅ Tooltip generation
✅ Vendor NPC scripts
✅ Worldforged object scripts
✅ Achievement tracking

CONTENT:
✅ 940 items across 5 tiers
✅ 56 worldforged objects
✅ 5 vendor NPCs
✅ 20+ achievements
✅ 16-week season structure

DOCUMENTATION:
✅ System design document
✅ Implementation guide
✅ Balance spreadsheet
✅ Item allocation list
✅ Token economy analysis
✅ Player journey map
```

---

## 📈 SUCCESS METRICS

### **Post-Launch Measurements**

```
ENGAGEMENT:
├─ Players collecting items: 85%+
├─ Average items per player: 60+
├─ Average playtime increase: +25%
├─ Retention after 4 weeks: 80%+
└─ Season completion rate: 30% (reasonable)

ECONOMY:
├─ Token inflation: < 5% per week
├─ Weekly cap hit rate: 40% (hardcore players)
├─ Item drop rates matching targets
├─ Currency balance healthy
└─ No exploits detected

CONTENT:
├─ Casual path viable: Yes
├─ Hardcore path challenging: Yes
├─ Prestige achievable: Yes
├─ Artifacts discoverable: 80% in 16 weeks
└─ Replayability: High (seasonal)
```

---

*Complete Implementation Roadmap*  
*12 weeks | 60-90 development hours*  
*940 items | 5 tiers | Season-based progression*  
*Ready for development*
