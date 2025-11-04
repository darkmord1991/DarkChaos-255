# Item Upgrade System: Implementation Guide
## Step-by-Step Instructions for Developers

---

## Phase 1: Database Setup (Effort: 2-3 hours)

### Step 1.1: Import Schema
```bash
mysql -u root -p darkchoas_world < Custom/item_upgrade_system/dc_item_upgrade_schema.sql
```

**Verification:**
```sql
SHOW TABLES LIKE 'dc_%';
-- Should show: dc_upgrade_tracks, dc_item_upgrade_chains, dc_player_item_upgrades, 
--              dc_player_currencies, dc_currency_rewards, dc_item_upgrade_npcs, 
--              dc_item_slot_modifiers, dc_upgrade_log, dc_item_upgrade_version
```

### Step 1.2: Verify Initial Data
```sql
SELECT * FROM dc_upgrade_tracks;
-- Should show 6 tracks (HLBG, Heroic, Mythic, Raid Normal/Heroic/Mythic)

SELECT * FROM dc_currency_rewards;
-- Should show reward mappings for each content type
```

**Troubleshooting:**
- If foreign key errors: Check `dc_upgrade_tracks.track_id` matches references
- If character_currency conflicts: May need to merge with existing character currency table

---

## Phase 2: Item Chain Generation (Effort: 3-5 hours)

### Step 2.1: Generate Sample Item Entries
```bash
# Generate for Heroic Dungeons
python Custom/item_upgrade_system/generate_item_chains.py --track heroic_dungeon --output heroic_dungeon_items.sql

# Generate for Mythic Raids
python Custom/item_upgrade_system/generate_item_chains.py --track raid_mythic --output raid_mythic_items.sql

# Generate ALL tracks
python Custom/item_upgrade_system/generate_item_chains.py --generate-all
```

**Output:** Creates SQL files with:
- item_template INSERT statements (6 per base item)
- dc_item_upgrade_chains INSERT statements (maps progression)

### Step 2.2: Import Generated Items
```bash
mysql -u root -p darkchoas_world < heroic_dungeon_items.sql
mysql -u root -p darkchoas_world < raid_mythic_items.sql
# ... etc for all tracks
```

**Verification:**
```sql
-- Check item_template entries created
SELECT COUNT(*) FROM item_template WHERE entry BETWEEN 50000 AND 60000;
-- Should show ~300+ entries (50 items × 6 iLvls = 300)

-- Check chains mapped
SELECT COUNT(*) FROM dc_item_upgrade_chains;
-- Should match number of items you created chains for
```

### Step 2.3: Manual Item Customization (OPTIONAL)
If you want to use existing items instead of creating new ones:

```sql
-- Find existing heroic dungeon items
SELECT entry, name, item_level, inventory_type FROM item_template 
WHERE item_level = 226 AND quality = 4 
LIMIT 50;

-- For each existing item, create chain record manually:
INSERT INTO dc_item_upgrade_chains 
(base_item_name, item_quality, item_slot, item_type, track_id,
 ilvl_0_entry, ilvl_1_entry, ilvl_2_entry, ilvl_3_entry, ilvl_4_entry, ilvl_5_entry)
VALUES 
('Existing Item Name', 4, 'chest', 'plate', 2,
 50010, 50020, 50030, 50040, 50050, 50060);
```

---

## Phase 3: C++ Backend Implementation (Effort: 30-40 hours)

### Step 3.1: Create ItemUpgradeManager Files

**File: `src/server/scripts/Custom/ItemUpgradeManager.h`**

```cpp
#pragma once
#include "Define.h"
#include "Player.h"
#include "Item.h"

class ItemUpgradeManager {
public:
    static ItemUpgradeManager* instance();
    
    struct UpgradeInfo {
        uint32 nextItemEntry;
        uint32 nextIlvl;
        uint32 tokenCost;
        uint32 fligstoneCost;
        bool canUpgrade;
        std::string reason;
    };
    
    // Main operations
    UpgradeInfo GetUpgradeInfo(Player* player, Item* item);
    bool UpgradeItem(Player* player, uint32 itemGuid);
    
    // Currency management
    uint32 GetPlayerTokenBalance(uint32 playerGuid);
    void AddTokens(uint32 playerGuid, uint32 amount, const char* reason);
    void RemoveTokens(uint32 playerGuid, uint32 amount, const char* reason);
    
    // Called by loot system
    void OnItemLooted(Player* player, Item* item, uint32 bossDifficulty);
    
private:
    std::unordered_map<uint32, uint32> m_itemChainCache;  // item entry -> track_id
};

#define sItemUpgradeManager ItemUpgradeManager::instance()
```

**File: `src/server/scripts/Custom/ItemUpgradeManager.cpp`**

See the ITEM_UPGRADE_SYSTEM_DESIGN.md for full implementation.

### Step 3.2: Create NPC Script

**File: `src/server/scripts/Custom/ItemUpgradeNPC.cpp`**

See the ITEM_UPGRADE_SYSTEM_DESIGN.md for full gossip implementation.

### Step 3.3: Add CMake Entries

**File: `src/server/scripts/Custom/CMakeLists.txt`**

Add these lines:
```cmake
set(custom_SRCS
    ${custom_SRCS}
    Custom/ItemUpgradeManager.cpp
    Custom/ItemUpgradeNPC.cpp
)

add_library(custom_scripts SHARED ${custom_SRCS})
```

### Step 3.4: Register Script Loader

**File: `src/server/scripts/Custom/CustomScripts.cpp`**

Add function declarations:
```cpp
void AddSC_item_upgrade_npc();

void AddCustomScripts() {
    AddSC_item_upgrade_npc();
    // ... other custom scripts
}
```

### Step 3.5: Build and Test

```bash
cd src/server/scripts/Custom
# or rebuild entire project
./acore.sh compiler build
```

**Verify Compilation:**
```bash
# Check for errors
tail -100 var/build/CMakeFiles/CMakeOutput.log | grep -i "error"
```

---

## Phase 4: NPC Placement (Effort: 1-2 hours)

### Step 4.1: Create NPC in Game
```sql
-- Insert into creature_template (or modify existing NPC)
INSERT INTO creature_template (
    entry, difficulty_entry_1, difficulty_entry_2, difficulty_entry_3,
    name, subname, icon_name, classification, type, display_id, health_mod, mana_mod,
    armor_mod, faction_a, faction_h, speed_walk, speed_run, speed_swim, speed_flight,
    detection_range, scale, rank, dmg_multiplier, health_multiplier,
    mana_multiplier, armor_multiplier, experience_mod, racial_leader,
    movementType, hover, flags, script_name
) VALUES (
    600001,  -- entry (custom range)
    0, 0, 0,
    'Item Master Velisande', 'Item Upgrade NPC', NULL, 0, 7, 15470, 1, 1,
    1, 35, 35, 1, 1.14286, 1.15, 1.2,
    20, 1, 0, 1, 1,
    1, 1, 1, 0,
    0, 0, 33555200, 'npc_item_upgrade'  -- Important: script_name
);

-- OR update existing NPC
UPDATE creature_template SET script_name = 'npc_item_upgrade' WHERE entry = 600001;
```

### Step 4.2: Place NPC in World
```sql
-- Add to world at specific location
INSERT INTO creature (
    guid, id, map, zone_id, area_id, spawnMask, phaseMask,
    modelid, equipment_id, position_x, position_y, position_z, orientation,
    spawntimesecs, spawndist, currentwaypoint, curhealth, curmana,
    movementType, npcflag, unit_flags, dynamicflags, is_pet
) VALUES (
    999001,  -- guid
    600001,  -- id (creature_template.entry)
    1,       -- map (1 = Eastern Kingdoms)
    14,      -- zone (14 = Darnassus or wherever)
    0,       -- area_id
    1,       -- spawnMask
    0,       -- phaseMask
    0,       -- modelid (uses template default)
    0,       -- equipment_id
    -8949.95, -132.493, 83.6112,  -- position (Darnassus)
    1.5,     -- orientation
    7200,    -- respawn time (2 hours)
    0,       -- no wander
    0,       -- waypoint
    0,       -- health
    0,       -- mana
    0,       -- movementType (0 = stationary)
    1,       -- npcflag (1 = gossip)
    0,       -- unit_flags
    0,       -- dynamicflags
    0        -- not a pet
);
```

### Step 4.3: Add NPC Configuration
```sql
INSERT INTO dc_item_upgrade_npcs (
    npc_entry, npc_name, available_track_ids, map_id,
    location_x, location_y, location_z, orientation, season, active
) VALUES (
    600001, 'Item Master Velisande', '[1, 2, 3, 4, 5, 6]', 1,
    -8949.95, -132.493, 83.6112, 1.5, 0, TRUE
);
```

### Step 4.4: Verify in Game
1. Start server: `./acore.sh run-worldserver`
2. Login and navigate to NPC location
3. Verify gossip menu appears
4. Test upgrade interface

---

## Phase 5: Loot Integration (Effort: 15-20 hours)

### Step 5.1: Find Loot Triggering Points

**File: `src/server/game/Loot/Loot.cpp`**

Locate where items are looted:
```cpp
// Search for: 
// void Loot::NotifyItemRemoved()
// void Loot::AutoStore()
// Item* Player::StoreNewItem()
```

### Step 5.2: Add Hook for Token Rewards

```cpp
// In Creature.cpp, when boss dies:
void Creature::Die(Unit* killer, Unit* /*savedVictim*/, uint32 spellId) {
    // ... existing code ...
    
    // NEW: Award upgrade tokens based on difficulty
    if (m_creatureInfo->rank >= CREATURE_ELITE_RARE && 
        killer && killer->GetTypeId() == TYPEID_PLAYER) {
        
        Player* player = killer->ToPlayer();
        uint32 tokens = 0;
        uint32 flightstones = 0;
        
        // Determine content source and difficulty
        uint32 mapId = GetMapId();
        uint32 difficulty = player->GetGroup() ? player->GetGroup()->GetDifficulty(mapId) : 0;
        
        // Use the map/raid/dungeon info to determine rewards
        if (IsInInstance()) {
            if (GetMap()->IsDungeon()) {
                if (difficulty == DIFFICULTY_HEROIC) {
                    tokens = 5;
                    flightstones = 25;
                } else if (difficulty == DIFFICULTY_HEROIC_RAID) {
                    tokens = 8;
                    flightstones = 50;
                }
            } else if (GetMap()->IsRaid()) {
                if (difficulty == DIFFICULTY_RAID_10N || difficulty == DIFFICULTY_RAID_25N) {
                    tokens = 10;
                    flightstones = 75;
                } else if (difficulty == DIFFICULTY_RAID_10H || difficulty == DIFFICULTY_RAID_25H) {
                    tokens = 15;
                    flightstones = 90;
                } else if (difficulty == DIFFICULTY_RAID_10M || difficulty == DIFFICULTY_RAID_25M) {
                    tokens = 20;
                    flightstones = 100;
                }
            }
        }
        
        if (tokens > 0) {
            sItemUpgradeManager->AddTokens(player->GetGUID(), tokens, "Boss kill");
            sItemUpgradeManager->AddFlightstones(player->GetGUID(), flightstones, "Boss kill");
            player->GetSession()->SendNotification(
                "You received %u Upgrade Tokens!", tokens);
        }
    }
}
```

### Step 5.3: Test Token Rewards

1. Kill a boss in dungeon
2. Check inventory: `/script print(GetCurrencyInfo(1))`  (if command-based)
3. Verify currency balance shows in NPC gossip

---

## Phase 6: Client Addon UI (Effort: 15-20 hours)

### Step 6.1: Create Addon Structure

```
WoW_Client/Interface/AddOns/DC-ItemUpgrade/
├── DC-ItemUpgrade.toc
├── Core.lua
├── UI.lua
├── Events.lua
└── Locales/
    └── enUS.lua
```

### Step 6.2: Create .toc File

**File: `DC-ItemUpgrade/DC-ItemUpgrade.toc`**

```
## Interface: 30300
## Title: DarkChaos - Item Upgrade
## Author: DarkChaos Team
## Version: 1.0
## Notes: Item upgrade interface for DarkChaos-255
## SavedVariables: DCItemUpgradeDB

Core.lua
UI.lua
Events.lua
Locales/enUS.lua
```

### Step 6.3: Create Core Addon Logic

**File: `DC-ItemUpgrade/Core.lua`**

```lua
local ADDON_NAME = "DC-ItemUpgrade"
local DCItemUpgrade = {}
_G[ADDON_NAME] = DCItemUpgrade

-- Configuration
DCItemUpgrade.version = "1.0"
DCItemUpgrade.debug = false

-- Cache for item upgrade info
DCItemUpgrade.itemCache = {}
DCItemUpgrade.playerGUID = nil

-- Slash commands
SLASH_DCUPGRADE1 = "/upgrade"
SLASH_DCUPGRADE2 = "/itemupgrade"

SlashCmdList.DCUPGRADE = function(msg)
    if msg == "ui" or msg == "" then
        DCItemUpgrade:ShowUpgradeUI()
    elseif msg == "currency" then
        DCItemUpgrade:ShowCurrency()
    elseif msg == "debug" then
        DCItemUpgrade.debug = not DCItemUpgrade.debug
        print("DC ItemUpgrade Debug: " .. tostring(DCItemUpgrade.debug))
    end
end

function DCItemUpgrade:OnLoad()
    if self.debug then print("DC ItemUpgrade: Loaded") end
    self.playerGUID = UnitGUID("player")
end

function DCItemUpgrade:OnUpdate()
    -- Periodically check for upgradeable items in inventory
    -- This will trigger notifications
end

-- Register events
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("BAG_UPDATE")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == ADDON_NAME then
        DCItemUpgrade:OnLoad()
    elseif event == "PLAYER_LOGIN" then
        DCItemUpgrade:ShowWelcomeMessage()
    elseif event == "BAG_UPDATE" then
        DCItemUpgrade:OnBagUpdate()
    end
end)

function DCItemUpgrade:ShowWelcomeMessage()
    print("|cFF00FF00[DC ItemUpgrade]|r Welcome to the Item Upgrade System!")
    print("Use |cFFFFFF00/upgrade|r to open the upgrade interface")
end
```

### Step 6.4: Create UI Module

**File: `DC-ItemUpgrade/UI.lua`**

See ITEM_UPGRADE_SYSTEM_DESIGN.md for full UI implementation.

### Step 6.5: Package Addon

```bash
# Copy addon to client
cp -r DC-ItemUpgrade "%ProgramFiles%/World of Warcraft/Interface/AddOns/"

# Or create zip for distribution
zip -r DC-ItemUpgrade.zip DC-ItemUpgrade/
```

### Step 6.6: Test Addon

1. Start WoW
2. Verify addon loads: `/script print(IsAddOnLoaded("DC-ItemUpgrade"))`
3. Test command: `/upgrade`
4. Verify UI appears

---

## Phase 7: Integration Testing (Effort: 10-15 hours)

### Test Checklist

```
[✓] Database Schema
  [✓] All tables created
  [✓] Sample data inserted
  [✓] Foreign keys valid
  
[✓] Item Chains
  [✓] Items created in item_template
  [✓] Chains mapped in dc_item_upgrade_chains
  [✓] All iLvl versions exist
  
[✓] C++ Backend
  [✓] Code compiles without errors
  [✓] No memory leaks (valgrind check)
  [✓] ItemUpgradeManager singleton loads
  [✓] GetUpgradeInfo returns correct data
  
[✓] NPC
  [✓] NPC visible in world
  [✓] Gossip menu appears
  [✓] Displays player currency correctly
  
[✓] Loot Integration
  [✓] Tokens awarded on boss kill
  [✓] Currency appears in player balance
  [✓] Correct amounts by difficulty
  
[✓] Upgrade Functionality
  [✓] Can initiate upgrade
  [✓] Item swapped to new entry
  [✓] Currency deducted
  [✓] Item properties preserved (enchants)
  [✓] Cannot upgrade without currency
  [✓] Cannot upgrade at max level
  
[✓] Client Addon
  [✓] Addon loads without errors
  [✓] /upgrade command opens UI
  [✓] UI displays correct item info
  [✓] Currency displays match server
  
[✓] Balance
  [✓] Currency earn rate feels right
  [✓] Upgrade costs reasonable
  [✓] Progression feels meaningful
```

### Sample Test Cases

**Test 1: Basic Upgrade Path**
1. Receive Heroic Chestplate (iLvl 226)
2. Visit NPC
3. See upgrade option: 226 → 230
4. Cost: 10 tokens, 50 flightstones
5. Click upgrade
6. Receive Heroic Chestplate (iLvl 230)
7. Verify item replaced, not added

**Test 2: Insufficient Currency**
1. Receive item with upgrade available
2. Visit NPC
3. Have < 10 tokens
4. Upgrade button disabled
5. See message: "Insufficient tokens"

**Test 3: Maximum Upgrade**
1. Upgrade item 5 times to max (iLvl 245)
2. Visit NPC
3. No upgrade option shown
4. See message: "Already at maximum"

**Test 4: Multiple Items**
1. Have 3 different Heroic items
2. Visit NPC
3. All 3 listed as upgradeable
4. Can upgrade any of them

---

## Phase 8: Performance Optimization (Effort: 5-10 hours)

### Query Optimization

```sql
-- Index for fast chain lookups
CREATE INDEX idx_chain_entry_0 ON dc_item_upgrade_chains(ilvl_0_entry);
CREATE INDEX idx_chain_entry_1 ON dc_item_upgrade_chains(ilvl_1_entry);
-- ... etc for all levels

-- Index for currency lookups
CREATE INDEX idx_currency_char ON dc_player_currencies(character_guid);

-- Index for player upgrade history
CREATE INDEX idx_upgrade_item ON dc_player_item_upgrades(item_guid);
CREATE INDEX idx_upgrade_char ON dc_player_item_upgrades(character_guid);
```

### Cache Strategy

```cpp
// In ItemUpgradeManager
private:
    std::unordered_map<uint32, ItemChain> m_chainCache;
    std::unordered_map<uint32, UpgradeTrack> m_trackCache;
    
    // Cache refresh every 1 hour or on update
    uint32 m_cacheRefreshTime = 3600000;  // milliseconds
```

---

## Phase 9: Documentation (Effort: 2-3 hours)

### Create Admin Guide

```markdown
# Item Upgrade System Admin Guide

## Configuration
- Edit `dc_upgrade_tracks` to adjust costs
- Edit `dc_currency_rewards` to change earn rates
- Edit `dc_item_slot_modifiers` for slot-based pricing

## Monitoring
- Query `dc_upgrade_log` for upgrade history
- Monitor `dc_player_currencies` for balance checks

## Maintenance
- Weekly: Check for exploits in logs
- Monthly: Review balance and adjust if needed
- Seasonal: Archive old season data
```

### Create Player Guide

```markdown
# Item Upgrade System Player Guide

## How It Works
1. Earn Upgrade Tokens from bosses (difficulty-based)
2. Visit Item Upgrade NPC
3. Select item to upgrade
4. Confirm cost
5. Item increases in item level

## Currency
- Upgrade Tokens: Primary currency
- Flightstones: Secondary currency

## Costs
- Token cost varies by source difficulty
- Flightstone cost varies by item slot
- Heavy slots (chest, head, legs) cost more
```

---

## Deployment Checklist

```
PRE-DEPLOYMENT
[ ] All code reviewed and tested
[ ] Database backups created
[ ] Client addon tested
[ ] Documentation complete

DEPLOYMENT (DOWNTIME REQUIRED)
[ ] Stop world server
[ ] Import SQL schemas
[ ] Import item chains
[ ] Rebuild C++ code
[ ] Verify compilation successful
[ ] Start world server
[ ] Verify NPC loads
[ ] Verify database queries work

POST-DEPLOYMENT
[ ] Players can login
[ ] NPC visible
[ ] Currency system working
[ ] Can initiate upgrades
[ ] Monitor for errors
[ ] Gather player feedback
```

---

## Troubleshooting

### Issue: NPC doesn't appear in world
```
Solution:
1. Check creature entry exists: SELECT * FROM creature_template WHERE entry = 600001;
2. Check spawn in world: SELECT * FROM creature WHERE id = 600001;
3. Verify script_name set: UPDATE creature_template SET script_name = 'npc_item_upgrade' WHERE entry = 600001;
4. Restart server
```

### Issue: Currency not awarded
```
Solution:
1. Verify dc_currency_rewards populated: SELECT * FROM dc_currency_rewards;
2. Check loot hooks firing: Add LOG_DEBUG in Creature::Die
3. Verify ItemUpgradeManager instantiating
4. Check player can see currency in gossip
```

### Issue: Cannot upgrade item
```
Solution:
1. Verify chain exists: SELECT * FROM dc_item_upgrade_chains WHERE ilvl_0_entry = {item_entry};
2. Check player has currency: SELECT * FROM dc_player_currencies WHERE character_guid = {guid};
3. Verify item is upgradeable: UpgradeInfo should be !canUpgrade = false
4. Check database for errors: SHOW ENGINE INNODB STATUS;
```

### Issue: Memory leak or server crashes
```
Solution:
1. Run valgrind: valgrind --leak-check=full ./acore-worldserver
2. Check for infinite loops in ItemUpgradeManager
3. Verify all database queries properly cleaned up
4. Check for dangling pointers in NPC script
```

---

## Support

For issues or questions:
1. Check logs: `var/log/worldserver.log`
2. Enable debug: `ItemUpgradeManager::SetDebug(true)`
3. Review SQL schema: `dc_item_upgrade_schema.sql`
4. Test with single item first

---

**Next Phase:** Launch with MVP → Gather feedback → Implement polish features
