# Phase 3 Quick Start Guide

## Status: READY TO BEGIN 🚀

**Phase 2 Status**: ✅ Complete and verified
- 940 items generated (Tiers 1-5)
- 110 artifacts defined
- 2 currency items defined
- All SQL files fixed with correct IDs
- Ready to execute

**Phase 3 Status**: 📋 Planning complete, ready to implement

---

## Phase 3: Three Main Components

### Component 1: Chat Commands (`.upgrade`)
**What**: Player command interface for upgrades
**Where**: `ItemUpgradeCommand.cpp` (new file)
**Complexity**: Medium
**Estimated time**: 2-3 hours

### Component 2: Upgrade NPCs
**What**: Two NPC vendors (Vendor + Curator)
**Where**: `ItemUpgradeNPC_*.cpp` (new files)
**Complexity**: Medium
**Estimated time**: 2-3 hours

### Component 3: Integration & Helpers
**What**: Database queries, stat application, discovery tracking
**Where**: `ItemUpgradeManager.cpp` (modify existing)
**Complexity**: Medium-High
**Estimated time**: 3-4 hours

---

## Quick Implementation Order

```
1. Execute Phase 2 SQL Files (5 files)
   ↓
2. Verify Data Loaded (run verification queries)
   ↓
3. Create ItemUpgradeCommand.cpp
   ↓
4. Create ItemUpgradeNPC_Vendor.cpp
   ↓
5. Create ItemUpgradeNPC_Curator.cpp
   ↓
6. Extend ItemUpgradeManager with DB helpers
   ↓
7. Test all components
   ↓
8. Deploy Phase 3
```

---

## File Creation Checklist

### Phase 3A: Commands
- [ ] `src/server/scripts/Custom/ItemUpgrade/ItemUpgradeCommand.cpp`
  - Subcommand handlers
  - Error checking
  - Player feedback messages

### Phase 3B: NPCs
- [ ] `src/server/scripts/Custom/ItemUpgrade/ItemUpgradeNPC_Vendor.cpp`
  - Vendor gossip menu
  - Item shop
  - Welcome text

- [ ] `src/server/scripts/Custom/ItemUpgrade/ItemUpgradeNPC_Curator.cpp`
  - Curator gossip menu
  - Artifact list display
  - Discovery tracking

### Phase 3C: Integration
- [ ] `src/server/scripts/Custom/ItemUpgrade/ItemUpgradeIntegration.cpp`
  - Player login hooks
  - Item equip validation
  - Loot system integration

- [ ] Modify: `src/common/DataStores/ItemUpgradeManager.cpp`
  - Add DB query functions
  - Add stat calculation
  - Add discovery logging

### Phase 3D: SQL (Definitions)
- [ ] `PHASE3_NPC_DEFINITIONS.sql` (NPC creation)
- [ ] `PHASE3_NPC_SCRIPTS.sql` (if using SQL scripts)
- [ ] `PHASE3_COMMANDS.sql` (command registration)

---

## Key Code Patterns

### Pattern 1: Command Handler
```cpp
bool ItemUpgradeCommand::HandleUpgradeCommand(ChatHandler* handler, const char* args)
{
    if (!args || args[0] == '\0')
        return handler->SendSysMessage(".upgrade - Item upgrade system");
    
    char* command = strtok((char*)args, " ");
    
    if (strcmp(command, "list") == 0)
        return HandleUpgradeList(handler);
    else if (strcmp(command, "status") == 0)
        return HandleUpgradeStatus(handler);
    
    return handler->SendSysMessage("Unknown subcommand");
}
```

### Pattern 2: NPC Gossip
```cpp
void OnGossipSelect(Player* player, Creature* creature, uint32 sender, uint32 action)
{
    if (sender != GOSSIP_SENDER_MAIN)
        return;
    
    switch (action)
    {
        case 0: // View upgrades
            HandleViewUpgrades(player, creature);
            break;
        case 1: // View artifacts
            HandleViewArtifacts(player, creature);
            break;
    }
}
```

### Pattern 3: Database Query
```cpp
QueryResult result = WorldDatabase.Query(
    "SELECT token_type, balance FROM dc_player_upgrade_tokens WHERE player_guid = {}", 
    player->GetGUID()
);

if (result)
{
    do
    {
        Field* fields = result->Fetch();
        uint32 tokenType = fields[0].GetUInt32();
        uint32 balance = fields[1].GetUInt32();
        // Process token data
    } while (result->NextRow());
}
```

---

## Testing Checklist

### Basic Functionality
- [ ] `.upgrade status` shows token balance
- [ ] `.upgrade list` shows available upgrades
- [ ] `.upgrade info <id>` shows item details
- [ ] `.upgrade apply <id>` applies upgrade
- [ ] `.upgrade artifact list` shows artifacts
- [ ] `.upgrade artifact info <id>` shows artifact

### NPC Functionality
- [ ] Upgrade Vendor NPC spawns
- [ ] Upgrade Vendor gossip works
- [ ] Artifact Curator NPC spawns
- [ ] Artifact Curator gossip works
- [ ] NPCs in multiple cities accessible

### Database Integration
- [ ] Tokens deducted correctly
- [ ] Item stats updated correctly
- [ ] Player upgrades logged
- [ ] Artifact discoveries logged
- [ ] Cross-player data isolation

### Edge Cases
- [ ] Player with no items
- [ ] Player with no tokens
- [ ] Duplicate upgrades blocked
- [ ] Invalid item IDs rejected
- [ ] Token overflow (>max stack) handled

---

## Critical Database IDs

**Currency Items** (Item_Template):
- 100999 → Upgrade Token
- 109998 → Artifact Essence

**NPC IDs** (Creature):
- 190001 → Upgrade Vendor
- 190002 → Artifact Curator

**Custom Tables** (World DB):
- `dc_item_templates_upgrade` - 940 items
- `dc_chaos_artifact_items` - 110 artifacts
- `dc_player_upgrade_tokens` - player balances
- `dc_player_item_upgrades` - upgrade tracking
- `dc_player_artifact_discoveries` - discovery log

---

## Integration Points

**Player Login**: Load upgrade tokens
```sql
SELECT token_type, balance FROM dc_player_upgrade_tokens WHERE player_guid = ?
```

**Item Equip**: Validate upgrade eligibility
```sql
SELECT current_level FROM dc_player_item_upgrades 
WHERE player_guid = ? AND item_id = ?
```

**Loot System**: Check for artifact discovery
```sql
INSERT INTO dc_player_artifact_discoveries 
VALUES (?, ?, NOW()) ON DUPLICATE KEY UPDATE discovered_date = NOW()
```

---

## Next Steps

### Immediate (Phase 3 Start):
1. ✅ Review PHASE3_PLANNING.md
2. ⏳ Create ItemUpgradeCommand.cpp
3. ⏳ Implement `.upgrade` commands
4. ⏳ Test command parsing

### Short Term (Phase 3A-B):
5. ⏳ Create NPC files
6. ⏳ Implement NPC gossip menus
7. ⏳ Integrate item shops
8. ⏳ Test NPC interactions

### Medium Term (Phase 3C-D):
9. ⏳ Create DB helper functions
10. ⏳ Hook into player systems
11. ⏳ Comprehensive testing
12. ⏳ Deploy Phase 3

---

## Resources

**Documentation Files**:
- `PHASE3_PLANNING.md` - Detailed architecture
- `PHASE2_VERIFICATION.sql` - Data verification
- `ID_UPDATE_GUIDE.md` - Currency ID changes
- `ItemUpgradeManager.h/cpp` - Base classes (Phase 1)

**Reference Data**:
- 940 items in `dc_item_templates_upgrade`
- 110 artifacts in `dc_chaos_artifact_items`
- Currency items: 100999, 109998
- NPC IDs: 190001, 190002

---

## Success Criteria

Phase 3 is complete when:
- ✅ `.upgrade` command fully functional
- ✅ All subcommands working correctly
- ✅ Both NPCs spawned and interactive
- ✅ All CRUD operations on upgrades work
- ✅ Artifact discovery functional
- ✅ All verification tests pass
- ✅ Zero cross-player data leakage
- ✅ System handles edge cases gracefully

---

## Ready to Begin Phase 3? 🚀

**YES** → Create ItemUpgradeCommand.cpp and start Phase 3A

**QUESTIONS?** → Review PHASE3_PLANNING.md for detailed architecture

---
