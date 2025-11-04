# Phase 3: Commands, NPCs & Integration

## Overview
Phase 3 focuses on implementing the interactive components of the item upgrade system:
1. **Chat Commands** (`.upgrade`)
2. **Upgrade NPCs** (vendor and artifact curator)
3. **Integration with existing systems**

---

## Phase 3A: Chat Command Implementation

### Command: `.upgrade`

**Purpose**: Allow players to manage their item upgrades

**Subcommands**:

```
.upgrade list               - List all available upgrades for current equipment
.upgrade info <item_id>    - Show detailed upgrade info for an item
.upgrade apply <item_id>   - Apply upgrade token to an item
.upgrade status            - Show current token balance
.upgrade artifact list     - Show discovered artifacts
.upgrade artifact info <artifact_id> - Show artifact details
```

### Implementation Structure

**File**: `ItemUpgradeCommand.cpp` (new)

```cpp
// Key classes/methods needed:
class ItemUpgradeCommand : public CommandScript
{
    static bool HandleUpgradeCommand(ChatHandler* handler, const char* args);
    bool HandleUpgradeList(ChatHandler* handler);
    bool HandleUpgradeInfo(ChatHandler* handler, uint32 itemId);
    bool HandleUpgradeApply(ChatHandler* handler, uint32 itemId);
    bool HandleUpgradeStatus(ChatHandler* handler);
    bool HandleArtifactList(ChatHandler* handler);
    bool HandleArtifactInfo(ChatHandler* handler, uint32 artifactId);
};
```

**Integration Points**:
- Hook into `ItemUpgradeManager` (already created in Phase 1)
- Query `dc_player_item_upgrades` table
- Query `dc_player_upgrade_tokens` table
- Query `dc_player_artifact_discoveries` table

---

## Phase 3B: NPC Implementation

### NPC 1: Upgrade Vendor (Proposed ID: 190001)

**Location**: Major cities (Stormwind, Orgrimmar, Dalaran, etc.)

**Functions**:
- Sell upgrade tokens (vendor shop)
- Sell cosmetic variants
- Display current upgrade prices
- Provide upgrade information

**Gossip Menu Structure**:
```
┌─ Upgrade Vendor
│  ├─ [1] View Upgrade Tokens (shop)
│  ├─ [2] View Cosmetic Items (shop)
│  ├─ [3] How do upgrades work? (quest text)
│  └─ [4] Leave
```

**Implementation**:
- NPC script (Lua or C++)
- Gossip handler
- Item shop vendor

### NPC 2: Artifact Curator (Proposed ID: 190002)

**Location**: Similar to Upgrade Vendor (major cities)

**Functions**:
- Track discovered artifacts
- Show artifact locations
- Provide artifact lore/information
- Accept artifact discoveries (quest turn-in)

**Gossip Menu Structure**:
```
┌─ Artifact Curator
│  ├─ [1] View My Artifacts (list)
│  ├─ [2] Show me all artifacts (database)
│  ├─ [3] How do I discover artifacts? (guide)
│  └─ [4] Leave
```

**Implementation**:
- NPC script (Lua or C++)
- Gossip handler
- Discovery tracking
- Quest integration

---

## Phase 3C: Database Queries & Integration

### Key Queries Needed

**1. Get player's current upgrade tokens**:
```sql
SELECT token_type, balance FROM dc_player_upgrade_tokens 
WHERE player_guid = ?;
```

**2. Get upgradeable items for player**:
```sql
SELECT 
    t.item_id, t.item_name, t.tier_id,
    t.armor_type, t.item_slot, t.rarity,
    i.entry as player_item_entry,
    IFNULL(u.current_level, 0) as current_level
FROM dc_item_templates_upgrade t
LEFT JOIN item_instance i ON i.itemEntry = t.item_id AND i.owner_guid = ?
LEFT JOIN dc_player_item_upgrades u ON u.player_guid = ? AND u.item_id = t.item_id
WHERE t.tier_id >= ? AND t.tier_id <= ?
ORDER BY t.tier_id, t.armor_type, t.item_slot;
```

**3. Get artifact discovery progress**:
```sql
SELECT 
    a.artifact_id, a.artifact_name, a.location_name,
    a.location_type, a.essence_cost, a.rarity,
    IFNULL(d.discovered_date, NULL) as discovery_date,
    CASE WHEN d.discovered_date IS NOT NULL THEN 1 ELSE 0 END as is_discovered
FROM dc_chaos_artifact_items a
LEFT JOIN dc_player_artifact_discoveries d 
    ON d.player_guid = ? AND d.artifact_id = a.artifact_id
ORDER BY a.location_type, a.artifact_name;
```

**4. Check if item can be upgraded**:
```sql
SELECT 
    t.max_level, u.current_level,
    (SELECT cost FROM dc_item_upgrade_costs 
     WHERE tier_id = t.tier_id AND level = u.current_level + 1) as next_cost
FROM dc_item_templates_upgrade t
LEFT JOIN dc_player_item_upgrades u ON u.item_id = t.item_id AND u.player_guid = ?
WHERE t.item_id = ?;
```

---

## Phase 3D: System Architecture

```
PLAYER INTERFACE
    ↓
.upgrade command
    ↓
ItemUpgradeCommand.cpp
    ↓
ItemUpgradeManager.cpp/h
    ↓
Database Queries
    ├─ dc_player_upgrade_tokens
    ├─ dc_player_item_upgrades
    ├─ dc_player_artifact_discoveries
    ├─ dc_item_templates_upgrade
    └─ dc_chaos_artifact_items

    ↓
Item/Stat Application
    ├─ Add stats to items
    ├─ Update item enchantments
    └─ Trigger inventory updates
```

---

## Phase 3E: Implementation Steps

### Step 1: Create Command Handler
- [ ] Create `ItemUpgradeCommand.cpp`
- [ ] Implement `HandleUpgradeCommand()`
- [ ] Register command in command loader
- [ ] Test command parsing
- [ ] Test subcommand routing

### Step 2: Implement NPCs
- [ ] Create Upgrade Vendor NPC (ID 190001)
  - [ ] NPC script/gossip
  - [ ] Item shop integration
  - [ ] Test vendor interactions
  
- [ ] Create Artifact Curator NPC (ID 190002)
  - [ ] NPC script/gossip
  - [ ] Artifact listing
  - [ ] Discovery tracking
  - [ ] Test curator interactions

### Step 3: Create Database Helpers
- [ ] Write query functions in ItemUpgradeManager
- [ ] Implement token balance checking
- [ ] Implement upgrade eligibility checking
- [ ] Implement stat calculation
- [ ] Implement artifact discovery logging

### Step 4: Integrate with Core Systems
- [ ] Hook into player login (load upgrades)
- [ ] Hook into item equip (validate upgrades)
- [ ] Hook into loot system (artifact discovery)
- [ ] Hook into quest system (if applicable)

### Step 5: Testing & Refinement
- [ ] Unit test command parsing
- [ ] Integration test with DB
- [ ] NPC interaction testing
- [ ] Player upgrade testing
- [ ] Artifact discovery testing
- [ ] Edge case testing

---

## Phase 3F: File Structure

```
src/
├── server/
│   └── scripts/
│       └── Custom/
│           └── ItemUpgrade/
│               ├── ItemUpgradeCommand.cpp        [NEW]
│               ├── ItemUpgradeNPC_Vendor.cpp     [NEW]
│               ├── ItemUpgradeNPC_Curator.cpp    [NEW]
│               └── ItemUpgradeIntegration.cpp    [NEW]
│
├── common/
│   └── DataStores/
│       └── ItemUpgradeManager.cpp/h              [MODIFY - add more functions]

Custom/Custom feature SQLs/worlddb/ItemUpgrades/
├── PHASE3_NPC_DEFINITIONS.sql                  [NEW]
├── PHASE3_NPC_SCRIPTS.sql                      [NEW - if using DB scripts]
└── PHASE3_COMMANDS.sql                         [NEW - register commands]
```

---

## Phase 3G: Proposed NPC IDs & Entry Points

**NPC IDs**:
- **190001**: Upgrade Vendor (main vendor)
- **190002**: Artifact Curator (artifact tracker)

**Spawn Locations** (suggested):
- Stormwind: [112.58, 627.52, 90.46, 0]
- Orgrimmar: [1567.76, -4267.69, 52.13, 0]
- Dalaran: [5866.65, 712.90, 659.94, 0]

**Alternative**: Single universal NPC with both functions

---

## Phase 3H: Testing Scenarios

**Scenario 1: Basic Token Balance**
- [ ] User has 0 tokens initially
- [ ] User earns tokens (via quest/loot)
- [ ] `.upgrade status` shows correct balance

**Scenario 2: Item Upgrade**
- [ ] User equips eligible item
- [ ] User has correct token balance
- [ ] User can upgrade item
- [ ] Upgrade cost deducted correctly
- [ ] Item stats increased correctly

**Scenario 3: Artifact Discovery**
- [ ] User enters zone with artifact
- [ ] Artifact auto-discovers (or manual quest)
- [ ] Discovery logged in DB
- [ ] NPC shows discovered artifact
- [ ] User can view artifact details

**Scenario 4: Multiple Players**
- [ ] Player A upgrades items
- [ ] Player B upgrades items
- [ ] No cross-contamination of data
- [ ] Token balances independent

---

## Next Steps

**Ready for Phase 3?** ✅
- Phase 1: Database + C++ ✅
- Phase 2: Items + Artifacts + Currency ✅ (ready to execute)
- Phase 3: Commands + NPCs → **READY TO START**

**Proceed with Phase 3A** (Chat Command Implementation)?

---

## Notes & Considerations

**Scaling**: System designed to scale to multiple items/artifacts
**Performance**: Use database indexes on player_guid, item_id, artifact_id
**Modularity**: Each component (command, NPC, integration) is independent
**Extensibility**: Easy to add new commands, NPCs, or features later

---
