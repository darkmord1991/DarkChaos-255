# Phase 3: Quick Reference & Next Steps

**Status**: Phase 3A IN PROGRESS | Overall: 75% Complete  
**Session**: November 4, 2025

---

## CURRENT STATE: What's Done, What's Next

### ✅ COMPLETED (All Phases)

**Phase 1**: 100%
- ✅ 8 database tables created (World DB)
- ✅ 4 database tables created (Char DB)
- ✅ C++ ItemUpgradeManager compiled
- ✅ 310 items loaded (T1-2)

**Phase 2**: 100%
- ✅ 940 total items generated
- ✅ 110 Chaos Artifacts generated
- ✅ 2 Currency items created
- ✅ All SQL files executed successfully
- ✅ All verification queries passing

**Phase 3A (Current)**: 30%
- ✅ ItemUpgradeCommand.cpp created
- ✅ 3 subcommands implemented (.upgrade status|list|info)
- ⏳ Build integration pending

---

## THE FILES YOU NOW HAVE

### New Phase 3 Files Created

```
Custom/Custom feature SQLs/worlddb/ItemUpgrades/
├── PHASE3A_COMMANDS_STATUS.md              [Detailed command status]
├── PHASE3_IMPLEMENTATION_ROADMAP.md        [This comprehensive guide]
├── PHASE3_QUICK_REFERENCE.md               [This file]
└── [Previous Phase 2 files...]

src/server/game/Scripting/Commands/
└── ItemUpgradeCommand.cpp                  [✅ Ready - 140 lines]
```

---

## IMMEDIATE NEXT STEPS (Do This Next)

### Option 1: Build & Test Commands (Recommended)
**Time**: 30-45 minutes

```bash
# Step 1: Add to CMakeLists.txt
# Location: src/server/game/CMakeLists.txt
# Add line: Scripting/Commands/ItemUpgradeCommand.cpp

# Step 2: Compile
./acore.sh compiler build

# Step 3: Test in-game (as admin)
.upgrade status
.upgrade list
.upgrade info 50000
```

**Expected Output**:
```
=== Upgrade Token Status ===
This is a placeholder. Full implementation coming in Phase 3B.
Equipped Items:
  [Shows your equipped items with iLvL]
```

### Option 2: Jump to Phase 3B (NPC Creation)
**Time**: 3-4 hours total

Create two NPC systems:
1. Upgrade Vendor (190001) - Token management UI
2. Artifact Curator (190002) - Artifact tracking UI

**Files to create**:
- `src/server/game/Scripting/CreatureScripts/ItemUpgradeNPC_Vendor.cpp`
- `src/server/game/Scripting/CreatureScripts/ItemUpgradeNPC_Curator.cpp`

---

## CURRENT PROJECT STATUS SNAPSHOT

```
PHASE 1: ████████████████████████████ 100% ✅ DEPLOYED
PHASE 2: ████████████████████████████ 100% ✅ EXECUTED
PHASE 3: ███████░░░░░░░░░░░░░░░░░░░░░  30% 🟠 STARTED

OVERALL: 75% COMPLETE (Up from 70% at session start)
```

### What's Working
- ✅ Database fully configured (12 tables)
- ✅ All 940 items in system
- ✅ All 110 artifacts in system
- ✅ Currency items (100999, 109998)
- ✅ Chat command framework created

### What's Pending
- ⏳ Build integration (5 min task)
- ⏳ In-game testing (10 min task)
- ⏳ NPC implementations (Phase 3B)
- ⏳ Full database integration (Phase 3C)
- ⏳ Testing suite (Phase 3D)

---

## CODE REFERENCE: ItemUpgradeCommand.cpp

**Location**: `src/server/game/Scripting/Commands/ItemUpgradeCommand.cpp`

**What It Does**:
- Defines `.upgrade` command with 3 subcommands
- Reads equipped items from player
- Calculates tier based on item level
- Formats output to player

**Key Functions**:
```cpp
GetCommands()              // Returns ChatCommandBuilder table
HandleUpgradeStatus()      // .upgrade status
HandleUpgradeList()        // .upgrade list
HandleUpgradeInfo()        // .upgrade info <id>
AddItemUpgradeCommandScript()  // Registration
```

**Tier Calculation**:
```
iLvL < 60    → Tier 1
iLvL 60-99   → Tier 2
iLvL 100-149 → Tier 3
iLvL 150-199 → Tier 4
iLvL ≥ 200   → Tier 5
```

---

## CRITICAL IDs (Copy for Reference)

### Currency Items
```
100999 = Upgrade Token (for T1-T4)
109998 = Artifact Essence (for T5)
```

### Item Tier Ranges
```
T1: 50000-50149   (150 items)
T2: 60000-60159   (160 items)
T3: 70000-70249   (250 items)
T4: 80000-80269   (270 items)
T5: 90000-90109   (110 items)
```

### NPC IDs (for Phase 3B)
```
190001 = Upgrade Vendor
190002 = Artifact Curator
```

---

## COMPILATION STEPS

### Before Build
```bash
cd "c:\Users\flori\Desktop\WoW Server\Azeroth Fork\DarkChaos-255"
```

### Add File to CMakeLists.txt
**File**: `src/server/game/CMakeLists.txt`

**Find**: Section with other Scripting files
**Add**: `set(game_CHAT_SCRIPTS ... Scripting/Commands/ItemUpgradeCommand.cpp ...)`

Or add to game_source_files if using that pattern.

### Compile
```bash
./acore.sh compiler build
# OR
make -j$(nproc)  # On WSL/Linux
make -j4          # On Windows
```

### Check for Errors
- Look for "error:" in output
- Look for "undefined reference" to ItemUpgradeCommand
- ItemUpgradeCommand should compile cleanly (140 LOC)

### Restart Server
```bash
# Kill old server if running
# Start new server
./acore.sh run-worldserver
```

---

## IN-GAME TESTING CHECKLIST

After compiling and starting server, log in as admin and run:

```
✓ .upgrade
  Expected: Shows command help

✓ .upgrade status
  Expected: Placeholder message + your equipped items

✓ .upgrade list
  Expected: List items you can upgrade (T1-T4 only)

✓ .upgrade info 50000
  Expected: "Apprentice's Garb" with iLvL info

✓ .upgrade info 99999
  Expected: "Item not found"

✓ .upgrade info abc
  Expected: "Invalid item ID"
```

**All should work without crashing server**

---

## DATABASE QUERIES (Reference)

### Check Phase 2 Data
```sql
-- Verify items
SELECT COUNT(*) as total FROM dc_item_templates_upgrade;
-- Expected: 940

-- Verify artifacts
SELECT COUNT(*) as total FROM dc_chaos_artifact_items;
-- Expected: 110

-- Verify currency items
SELECT entry, name FROM item_template 
WHERE entry IN (100999, 109998);
-- Expected: 2 rows (Upgrade Token, Artifact Essence)
```

---

## NEXT PHASES PREVIEW

### Phase 3B: NPC Creation (3-4 hours)
Two NPCs to implement:

**Upgrade Vendor (190001)**
- Gossip menu to view/apply upgrades
- Token shop interface
- Upgrade tracker

**Artifact Curator (190002)**
- Artifact discovery tracker
- Lore display
- Collection progress

### Phase 3C: Database Integration (2-3 hours)
Extend ItemUpgradeManager:
- Token balance queries
- Item upgrade state management
- Artifact discovery tracking
- Player login/equip hooks

### Phase 3D: Testing (4-6 hours)
- 10+ test scenarios
- Performance verification
- Edge case handling
- Documentation finalization

---

## ESTIMATED TIME REMAINING

| Phase | Component | Hours | Status |
|-------|-----------|-------|--------|
| 3A | Command Build | 0.5 | ⏳ NEXT |
| 3A | In-Game Testing | 0.5 | ⏳ NEXT |
| 3B | Vendor NPC | 2 | ⏳ AFTER 3A |
| 3B | Curator NPC | 2 | ⏳ AFTER 3A |
| 3C | DB Integration | 3 | ⏳ AFTER 3B |
| 3D | Testing Suite | 5 | ⏳ FINAL |
| | **TOTAL REMAINING** | **13** | |

**Total Invested So Far**: ~100 hours  
**Estimated Total**: ~113 hours  
**Remaining**: ~13 hours

---

## KEY REFERENCES

### AzerothCore Files Used
- `src/server/game/Chat/ChatCommands/ChatCommand.h` - Command framework
- `src/server/game/Scripting/ScriptDefines/CommandScript.h` - Script base class
- `src/server/game/Player.h` - Player class
- `src/server/game/Item.h` - Item class

### Our Custom Files
- `src/server/scripts/DC/ItemUpgrades/ItemUpgradeManager.h`
- `src/server/scripts/DC/ItemUpgrades/ItemUpgradeManager.cpp`
- `Custom/Custom feature SQLs/worlddb/ItemUpgrades/*.sql`

---

## TROUBLESHOOTING

### Command Not Working
- ✓ Check ItemUpgradeCommand.cpp is in CMakeLists.txt
- ✓ Recompile completely: `./acore.sh compiler clean && ./acore.sh compiler build`
- ✓ Restart server
- ✓ Check server logs for compilation errors

### Items Not Showing
- ✓ Verify Phase 2 SQL files were executed
- ✓ Run verification queries
- ✓ Check 940 items are in database

### NPC IDs Conflict
- ✓ NPCs 190001-190002 are custom range (unlikely conflicts)
- ✓ Use .npc add to spawn test NPCs

### Command Crashed Server
- ✓ Check C++ syntax in ItemUpgradeCommand.cpp
- ✓ Verify all includes are available
- ✓ Check for uninitialized variables

---

## SUCCESS CRITERIA

Phase 3A Complete When:
- ✅ ItemUpgradeCommand.cpp compiles without errors
- ✅ `.upgrade` command appears in help
- ✅ `.upgrade status` shows your items
- ✅ `.upgrade list` shows upgradeable items
- ✅ `.upgrade info` works for valid/invalid items
- ✅ Server stable with command active

---

## WHAT'S NEXT AFTER PHASE 3?

### Post-Phase 3 (Phase 4+)
- Advanced stats calculations
- Cosmetic customization system
- Achievement tracking
- PvP integration
- Guild perks system
- Seasonal resets
- Market integration
- Balance adjustments

---

## IMPORTANT NOTES

1. **Placeholder Text**: Phase 3A has placeholder outputs like "coming in Phase 3B"
   - This is intentional - real data comes with database integration

2. **No Token Deduction Yet**: Phase 3A doesn't actually spend tokens
   - Will add in Phase 3C with database integration

3. **Tier Calculation**: Currently iLvL-based, simple
   - Will be database-driven in Phase 3C for more flexibility

4. **No NPC Yet**: Phase 3A is command-only
   - NPCs added in Phase 3B

---

## GET STARTED RIGHT NOW

**5-Minute Quick Build Test**:
```bash
# 1. Add to CMakeLists.txt (1 min)
# 2. Compile (3 min)
./acore.sh compiler build

# 3. Test (1 min)
./acore.sh run-worldserver
# Then: .upgrade status
```

**Or Jump to Phase 3B** (NPC creation - 3-4 hours)

---

**Last Updated**: November 4, 2025  
**Session Progress**: Phase 3A ~30% → Ready for build & test  
**Next Milestone**: Phase 3B NPCs (estimated 3-4 hours)
