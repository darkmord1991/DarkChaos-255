# Phase 3 Implementation - Comprehensive Roadmap

**Session**: November 4, 2025  
**Current Status**: Phase 3A IN PROGRESS (30% complete)  
**Overall Project**: 75% complete (Phase 1: 100% ✅ | Phase 2: 100% ✅ | Phase 3: 30% ⏳)

---

## Phase 3A: Chat Commands - STATUS: IN PROGRESS

### ✅ COMPLETED (Phase 3A)

**ItemUpgradeCommand.cpp Created**
- Location: `src/server/game/Scripting/Commands/ItemUpgradeCommand.cpp`
- Status: Ready for build integration
- Size: 140 lines of clean, documented code

**Command Structure Implemented**:
```
.upgrade status         → Show token balance
.upgrade list           → List upgradeable items
.upgrade info <id>      → Show item upgrade info
```

**Features Implemented**:
- ✅ Proper CommandScript inheritance
- ✅ AzerothCore ChatCommandBuilder integration
- ✅ Equipment slot enumeration
- ✅ Item template lookups
- ✅ Tier calculation (iLvL-based)
- ✅ Error handling
- ✅ Console output formatting

**Architecture**:
- Class: `ItemUpgradeCommand : public CommandScript`
- Entry point: `AddItemUpgradeCommandScript()` function
- Handler pattern: Static member functions with `ChatHandler* handler` parameter
- Command table: Static std::vector<ChatCommandBuilder>

### ⏳ NEXT (Phase 3A - Immediate)

**Build Integration**
1. Add ItemUpgradeCommand.cpp to CMakeLists.txt
2. Compile with: `./acore.sh compiler build`
3. Test in-game

**Location for Build File**: `src/server/game/CMakeLists.txt` (likely)

---

## Phase 3B: NPC Implementation - STATUS: PLANNED

### Components to Create

**1. ItemUpgradeNPC_Vendor.cpp**
- **NPC ID**: 190001
- **Name**: Chaos Upgrade Vendor
- **Locations**: Stormwind, Orgrimmar, Dalaran
- **Functions**:
  - Gossip menu with upgrade options
  - Token shop interface
  - Upgrade information display
  - Item preview system

**2. ItemUpgradeNPC_Curator.cpp**
- **NPC ID**: 190002
- **Name**: Artifact Curator
- **Locations**: Same as Vendor
- **Functions**:
  - Artifact tracking menu
  - Discovery progress display
  - Artifact lore/descriptions
  - Artifact collection rewards

### NPC Features

#### Upgrade Vendor Gossip Menu
```
┌─ Upgrade Vendor (190001) ─┐
├─ [Tell me about upgrades]
│  └─ [Show available upgrades for my items]
│  └─ [What upgrades can I apply?]
│
├─ [I want to upgrade an item]
│  └─ [Apply upgrade token]
│
├─ [Show my upgrade status]
│  └─ [Display token balance]
│
└─ [Nevermind]
```

#### Artifact Curator Gossip Menu
```
┌─ Artifact Curator (190002) ───┐
├─ [What are Chaos Artifacts?]
│  └─ [General lore and purpose]
│
├─ [Show my discovered artifacts]
│  └─ [List with counts by type]
│
├─ [I want artifact information]
│  └─ [Zone | Dungeon | Cosmetic]
│
└─ [Nevermind]
```

### Implementation Details

**CreatureScript Pattern** (Similar to CommandScript):
```cpp
class ItemUpgradeVendor : public CreatureScript
{
public:
    ItemUpgradeVendor() : CreatureScript("ItemUpgradeVendor") { }
    
    struct npc_upgrade_vendorAI : public ScriptedAI
    {
        // AI implementation
    };
    
    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_upgrade_vendorAI(creature);
    }
};
```

**Gossip Handling**:
```cpp
bool OnGossipHello(Player* player, Creature* creature) override
{
    // Build gossip menu with options
    player->ADD_GOSSIP_ITEM(GOSSIP_ICON_CHAT, "Tell me about upgrades", GOSSIP_SENDER_MAIN, 1);
    player->ADD_GOSSIP_ITEM(GOSSIP_ICON_VENDOR, "I want to upgrade an item", GOSSIP_SENDER_MAIN, 2);
    player->ADD_GOSSIP_ITEM(GOSSIP_ICON_INTERACT_1, "Show my status", GOSSIP_SENDER_MAIN, 3);
    player->SEND_GOSSIP_MENU(DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
    return true;
}
```

### Estimated Effort

- Vendor NPC: 1.5-2 hours
- Curator NPC: 1.5-2 hours
- Total Phase 3B: 3-4 hours

---

## Phase 3C: Database Integration - STATUS: PLANNED

### Functions to Implement

**In ItemUpgradeManager (Extension)**:

1. **Token Management**
   ```cpp
   uint32 GetPlayerTokenBalance(ObjectGuid playerGuid);
   uint32 GetPlayerArtifactEssenceBalance(ObjectGuid playerGuid);
   bool AddTokens(ObjectGuid playerGuid, uint32 amount);
   bool RemoveTokens(ObjectGuid playerGuid, uint32 amount);
   ```

2. **Item Upgrade State**
   ```cpp
   bool UpgradeItem(ObjectGuid playerGuid, Item* item);
   uint32 GetItemUpgradeLevel(Item* item);
   uint8 GetItemTier(uint32 itemLevel);
   uint32 GetUpgradeCost(uint8 fromTier, uint8 toTier);
   ```

3. **Artifact Management**
   ```cpp
   bool DiscoverArtifact(ObjectGuid playerGuid, uint32 artifactId);
   std::vector<uint32> GetDiscoveredArtifacts(ObjectGuid playerGuid);
   ArtifactInfo GetArtifactInfo(uint32 artifactId);
   ```

4. **Database Queries**
   ```sql
   -- Token balance
   SELECT amount FROM dc_player_upgrade_tokens
   WHERE player_guid = ? AND currency_type = ?
   
   -- Item upgrade state
   SELECT * FROM dc_player_item_upgrades
   WHERE item_guid = ?
   
   -- Discovered artifacts
   SELECT artifact_id FROM dc_player_artifact_discoveries
   WHERE player_guid = ?
   ```

### Integration Points

**Login Hook** (PlayerScript):
```cpp
void OnLogin(Player* player) override
{
    // Load player's upgrade tokens from database
    // Load player's artifact discoveries
    // Initialize upgrade UI if applicable
}
```

**Item Equip Hook** (ItemScript):
```cpp
void OnEquip(Player* player, Item* item, uint8 bag, uint8 slot) override
{
    // Validate item upgrade compatibility
    // Apply stat multiplier if upgraded
    // Update player UI
}
```

**Loot Hook** (LootScript or PlayerScript):
```cpp
void OnLoot(Player* player, LootItem* loot) override
{
    // Check if loot is an artifact
    // Trigger discovery if applicable
    // Log discovery event
}
```

### Estimated Effort

- Database query implementations: 1-1.5 hours
- Hook integrations: 0.5-1 hour
- Testing and debugging: 0.5-1 hour
- Total Phase 3C: 2-3.5 hours

---

## Phase 3D: Testing & Refinement - STATUS: PLANNED

### Test Scenarios

**1. Command Testing** (5 scenarios)
- ✓ `.upgrade status` returns correct token count
- ✓ `.upgrade list` shows only upgradeable items
- ✓ `.upgrade info` displays correct tier info
- ✓ Invalid command parameters handled gracefully
- ✓ Permission checks work (player vs admin)

**2. NPC Interaction Testing** (4 scenarios)
- ✓ Vendor gossip menu displays correctly
- ✓ Curator gossip menu displays correctly
- ✓ Gossip options trigger correct handlers
- ✓ NPCs spawn in correct locations

**3. Upgrade System Testing** (5 scenarios)
- ✓ Token deduction works correctly
- ✓ Item tier increments properly
- ✓ Item level increases appropriately
- ✓ Stat multiplier applied to item stats
- ✓ Upgrade transaction logged to database

**4. Artifact System Testing** (4 scenarios)
- ✓ Artifact discovered correctly on loot
- ✓ Discovery recorded in database
- ✓ Artifact list shows correct discoveries
- ✓ Artifact info displays all details

**5. Edge Case Testing** (5 scenarios)
- ✓ Upgrade with insufficient tokens (blocked)
- ✓ Upgrade max-tier item (blocked)
- ✓ Concurrent upgrades from multiple players (isolated)
- ✓ NPC interaction while upgrading (queued)
- ✓ Logout/login preserves upgrade state (persistent)

**6. Multi-Player Testing** (3 scenarios)
- ✓ Token balance independent per player
- ✓ NPC respawns after death
- ✓ Artifact discoveries isolated per player

### Test Tools

**In-Game Testing Commands**:
```
.upgrade status
.upgrade list
.upgrade info 50000
.upgrade info 60000
```

**Database Verification**:
```sql
SELECT * FROM dc_player_upgrade_tokens WHERE player_guid = ?;
SELECT * FROM dc_player_item_upgrades WHERE player_guid = ?;
SELECT * FROM dc_player_artifact_discoveries WHERE player_guid = ?;
```

**Performance Monitoring**:
- Query response time < 50ms
- Command execution < 100ms
- No memory leaks over extended use

### Estimated Effort

- Writing tests: 1-2 hours
- Executing tests: 1-1.5 hours
- Debugging fixes: 1-1.5 hours
- Documentation: 0.5-1 hour
- Total Phase 3D: 4-6 hours

---

## Critical Implementation References

### Database Schema (Reminder)

**Character DB Tables**:
```sql
dc_player_upgrade_tokens (player_guid, currency_type, amount, season)
dc_player_item_upgrades (item_guid, player_guid, tier_id, upgrade_level, ...)
dc_player_artifact_discoveries (player_guid, artifact_id, discovered_at)
```

**World DB Tables**:
```sql
dc_item_templates_upgrade (entry, item_id, tier_id, ...)
dc_chaos_artifact_items (artifact_id, artifact_name, item_id, ...)
```

### Critical IDs

**Item IDs**:
- T1: 50000-50149 (150 items)
- T2: 60000-60159 (160 items)
- T3: 70000-70249 (250 items)
- T4: 80000-80269 (270 items)
- T5: 90000-90109 (110 items)
- Upgrade Token: 100999
- Artifact Essence: 109998

**NPC IDs**:
- Upgrade Vendor: 190001
- Artifact Curator: 190002

### Important Code Patterns

**AzerothCore Command Handler**:
```cpp
static bool HandleMyCommand(ChatHandler* handler, char const* args)
{
    Player* player = handler->GetSession()->GetPlayer();
    handler->SendSysMessage("Message");
    handler->PSendSysMessage("Formatted: %s", value);
    return true;
}
```

**Item Access**:
```cpp
for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
{
    Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
    if (!item) continue;
    ItemTemplate const* proto = item->GetTemplate();
}
```

---

## Current File Status

### Created Files

| File | Location | Status | Size |
|------|----------|--------|------|
| ItemUpgradeCommand.cpp | `src/server/game/Scripting/Commands/` | ✅ Created | 140 LOC |
| PHASE3A_COMMANDS_STATUS.md | `Custom/Custom feature SQLs/worlddb/ItemUpgrades/` | ✅ Created | Detailed |
| PHASE3_IMPLEMENTATION_ROADMAP.md | `Custom/Custom feature SQLs/worlddb/ItemUpgrades/` | ✅ This file | Comprehensive |

### Pending Files

| File | Phase | Status | Priority |
|------|-------|--------|----------|
| ItemUpgradeNPC_Vendor.cpp | 3B | ⏳ Planned | P1 |
| ItemUpgradeNPC_Curator.cpp | 3B | ⏳ Planned | P1 |
| ItemUpgradeManager_Extended.cpp | 3C | ⏳ Planned | P1 |
| ItemUpgradeIntegration.cpp | 3C | ⏳ Planned | P1 |
| Phase3_Testing.md | 3D | ⏳ Planned | P2 |

---

## Build Integration Checklist

**Before Compilation**:
- [ ] Add ItemUpgradeCommand.cpp to CMakeLists.txt
- [ ] Verify all includes are available
- [ ] Check no undefined references

**Compilation**:
- [ ] Run: `./acore.sh compiler build`
- [ ] Check for compilation errors
- [ ] Verify no warnings in ItemUpgrade code
- [ ] Link successful

**Post-Compilation**:
- [ ] Server starts without errors
- [ ] Command registered (check help)
- [ ] Test commands in-game
- [ ] Check server logs for any issues

**In-Game Testing**:
- [ ] `.upgrade status` works
- [ ] `.upgrade list` shows items
- [ ] `.upgrade info <id>` works
- [ ] Error handling for invalid input
- [ ] Help text displays correctly

---

## Next Immediate Actions

### RIGHT NOW (If building)
1. Add ItemUpgradeCommand.cpp to CMakeLists.txt build
2. Compile: `./acore.sh compiler build`
3. Test in-game

### Phase 3B (NPC Creation)
1. Create ItemUpgradeNPC_Vendor.cpp
2. Create ItemUpgradeNPC_Curator.cpp
3. Add gossip handling
4. Add to CMakeLists.txt
5. Compile and test

### Phase 3C (Database Integration)
1. Extend ItemUpgradeManager with DB helpers
2. Implement query functions
3. Hook into player login/equip/loot
4. Add to CMakeLists.txt
5. Test with actual token/artifact operations

### Phase 3D (Testing)
1. Execute all test scenarios
2. Document findings
3. Fix any issues
4. Performance tune
5. Final documentation

---

## Timeline Estimate

| Phase | Component | Est. Hours | Status |
|-------|-----------|-----------|--------|
| 3A | Commands | 2-3 | 🟠 IN PROGRESS (30%) |
| 3A | Build Integration | 0.5-1 | ⏳ NEXT |
| 3B | Vendor NPC | 1.5-2 | ⏳ PLANNED |
| 3B | Curator NPC | 1.5-2 | ⏳ PLANNED |
| 3C | DB Integration | 2-3.5 | ⏳ PLANNED |
| 3D | Testing | 4-6 | ⏳ PLANNED |
| **TOTAL** | **Phase 3** | **11-17.5** | **🟠 30% Complete** |

**Remaining**: ~8-12 hours of work

---

## Success Metrics

✅ Phase 3 Complete When:
- All commands working and returning correct data
- Both NPCs spawned and functional
- All database queries optimized
- 10/10 test scenarios passing
- Zero memory leaks
- Clean, documented code
- Server compiles without warnings
- No performance degradation

---

**Last Updated**: November 4, 2025  
**Created By**: GitHub Copilot  
**Status**: Phase 3A ~30%, Phase 3 Overall ~75% Complete
