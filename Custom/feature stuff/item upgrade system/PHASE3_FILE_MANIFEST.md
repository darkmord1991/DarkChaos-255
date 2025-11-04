# Phase 3A + 3B: Complete File Manifest

**Date**: November 4, 2025  
**Status**: Build Complete  
**Ready for**: In-Game Testing

---

## C++ Source Files

### ItemUpgradeCommand.cpp
**Location**: `src/server/scripts/DC/ItemUpgrades/ItemUpgradeCommand.cpp`  
**Type**: Command Script  
**Size**: 160 LOC  
**Purpose**: Implements .upgrade chat command with 3 subcommands  
**Status**: ✅ Created & Compiled

**Key Components**:
- ItemUpgradeCommand class (extends CommandScript)
- HandleUpgradeStatus() - Status command handler
- HandleUpgradeList() - List command handler
- HandleUpgradeInfo() - Info command handler
- AddItemUpgradeCommandScript() - Registration function

---

### ItemUpgradeNPC_Vendor.cpp
**Location**: `src/server/scripts/DC/ItemUpgrades/ItemUpgradeNPC_Vendor.cpp`  
**Type**: Creature Script (NPC)  
**Size**: 180 LOC  
**Purpose**: Implements Upgrade Vendor NPC (ID: 190001)  
**Status**: ✅ Created & Compiled

**Key Components**:
- ItemUpgradeVendor class (extends CreatureScript)
- npc_item_upgrade_vendorAI (extends PassiveAI)
- OnGossipHello() - Main menu display
- OnGossipSelect() - Menu interaction handler
- ShowUpgradeMenu() - Submenu function
- ShowTokenExchangeMenu() - Submenu function
- ShowArtifactShopMenu() - Submenu function
- ShowHelpMenu() - Submenu function

---

### ItemUpgradeNPC_Curator.cpp
**Location**: `src/server/scripts/DC/ItemUpgrades/ItemUpgradeNPC_Curator.cpp`  
**Type**: Creature Script (NPC)  
**Size**: 200 LOC  
**Purpose**: Implements Artifact Curator NPC (ID: 190002)  
**Status**: ✅ Created & Compiled

**Key Components**:
- ItemUpgradeCurator class (extends CreatureScript)
- npc_item_upgrade_curatorAI (extends PassiveAI)
- OnGossipHello() - Main menu display
- OnGossipSelect() - Menu interaction handler
- ShowArtifactCollectionMenu() - Submenu function
- ShowDiscoveryInfoMenu() - Submenu function
- ShowCosmeticsMenu() - Submenu function
- ShowStatisticsMenu() - Submenu function
- ShowHelpMenu() - Submenu function

---

## Header Files

### ItemUpgradeScriptLoader.h
**Location**: `src/server/scripts/DC/ItemUpgrades/ItemUpgradeScriptLoader.h`  
**Type**: Header (Registration)  
**Size**: 20 LOC  
**Purpose**: Declares all ItemUpgrade script registration functions  
**Status**: ✅ Created

**Contents**:
- Function declaration: AddItemUpgradeCommandScript()
- Function declaration: AddSC_ItemUpgradeVendor()
- Function declaration: AddSC_ItemUpgradeCurator()
- Inline function: AddSC_ItemUpgradeScripts() (calls all 3)

---

## Build Configuration Files

### CMakeLists.txt (DC)
**Location**: `src/server/scripts/DC/CMakeLists.txt`  
**Type**: CMake Configuration  
**Changes**: +10 lines  
**Status**: ✅ Modified

**Changes Made**:
```cmake
# Added new section:
set(SCRIPTS_DC_ItemUpgrade
    ItemUpgrade/ItemUpgradeCommand.cpp
    ItemUpgrade/ItemUpgradeNPC_Vendor.cpp
    ItemUpgrade/ItemUpgradeNPC_Curator.cpp
)

# Added to SCRIPTS_WORLD:
${SCRIPTS_DC_ItemUpgrade}
```

---

### dc_script_loader.cpp
**Location**: `src/server/scripts/DC/dc_script_loader.cpp`  
**Type**: Script Loader  
**Changes**: +6 lines  
**Status**: ✅ Modified

**Changes Made**:
```cpp
// Added declarations:
void AddItemUpgradeCommandScript();
void AddSC_ItemUpgradeVendor();
void AddSC_ItemUpgradeCurator();

// Added to AddDCScripts():
AddItemUpgradeCommandScript();
AddSC_ItemUpgradeVendor();
AddSC_ItemUpgradeCurator();
```

---

## SQL Files (For Testing)

### dc_npc_creature_templates.sql
**Location**: `Custom/Custom feature SQLs/worlddb/ItemUpgrades/dc_npc_creature_templates.sql`  
**Purpose**: Creates NPC creature template entries  
**Status**: ✅ Created (Not executed yet)

**Contents**:
- Template for NPC 190001 (Item Upgrade Vendor)
- Template for NPC 190002 (Artifact Curator)
- Script name assignments

**Execution**: Manual (before spawning NPCs)

---

### dc_npc_spawns.sql
**Location**: `Custom/Custom feature SQLs/worlddb/ItemUpgrades/dc_npc_spawns.sql`  
**Purpose**: Spawns NPCs in the world  
**Status**: ✅ Created (Not executed yet)

**Contents**:
- Vendor spawn in Stormwind (ID: 450001)
- Vendor spawn in Orgrimmar (ID: 450002)
- Curator spawn in Shattrath (ID: 450003)

**Execution**: Manual (after executing creature templates)

---

## Documentation Files

### PHASE3A_3B_IMPLEMENTATION_COMPLETE.md
**Location**: `Custom/Custom feature SQLs/worlddb/ItemUpgrades/PHASE3A_3B_IMPLEMENTATION_COMPLETE.md`  
**Size**: 12 KB  
**Purpose**: Complete implementation documentation  
**Status**: ✅ Created

**Sections**:
- Phase 3A overview
- Phase 3B overview
- Build integration details
- Testing checklist
- Key IDs reference
- Compilation instructions
- Known limitations
- Success criteria

---

### PHASE3A_3B_TESTING_GUIDE.md
**Location**: `Custom/Custom feature SQLs/worlddb/ItemUpgrades/PHASE3A_3B_TESTING_GUIDE.md`  
**Size**: 18 KB  
**Purpose**: Comprehensive testing guide for in-game testing  
**Status**: ✅ Created

**Sections**:
- Quick start guide
- 15 detailed test procedures
- Expected output examples
- Pass/fail criteria for each test
- NPC spawn instructions
- Server log verification
- Troubleshooting guide
- Test summary sheet

---

### SESSION8_PHASE3AB_SUMMARY.md
**Location**: `Custom/Custom feature SQLs/worlddb/ItemUpgrades/SESSION8_PHASE3AB_SUMMARY.md`  
**Size**: 15 KB  
**Purpose**: Session summary and project status  
**Status**: ✅ Created

**Sections**:
- Executive summary
- Files created/modified
- Build verification
- Phase 3A details
- Phase 3B details
- Testing checklist
- Project status
- Performance metrics
- Next steps

---

### PHASE3_FILE_MANIFEST.md (This File)
**Location**: `Custom/Custom feature SQLs/worlddb/ItemUpgrades/PHASE3_FILE_MANIFEST.md`  
**Size**: This file  
**Purpose**: Complete listing of all Phase 3A+3B files  
**Status**: ✅ Creating now

---

## Existing Support Files

### ItemUpgradeManager.h
**Location**: `src/server/scripts/DC/ItemUpgrades/ItemUpgradeManager.h`  
**Type**: Header (Manager Interface)  
**Status**: ✅ Pre-existing (Created in Phase 1)

**Purpose**: Defines UpgradeManager interface and data structures

---

### ItemUpgradeManager.cpp
**Location**: `src/server/scripts/DC/ItemUpgrades/ItemUpgradeManager.cpp`  
**Type**: Implementation  
**Status**: ✅ Pre-existing (Created in Phase 1)

**Purpose**: Implements UpgradeManager functionality (basic stubs for Phase 3C)

---

## File Organization Diagram

```
src/server/scripts/DC/ItemUpgrades/
├── ItemUpgradeCommand.cpp                    [✅ Phase 3A]
├── ItemUpgradeNPC_Vendor.cpp                 [✅ Phase 3B]
├── ItemUpgradeNPC_Curator.cpp                [✅ Phase 3B]
├── ItemUpgradeScriptLoader.h                 [✅ Phase 3A+3B]
├── ItemUpgradeManager.h                      [✅ Phase 1]
└── ItemUpgradeManager.cpp                    [✅ Phase 1]

src/server/scripts/DC/
├── CMakeLists.txt                            [✅ Modified Phase 3A+3B]
└── dc_script_loader.cpp                      [✅ Modified Phase 3A+3B]

Custom/Custom feature SQLs/worlddb/ItemUpgrades/
├── dc_npc_creature_templates.sql             [✅ Phase 3A+3B]
├── dc_npc_spawns.sql                         [✅ Phase 3A+3B]
├── PHASE3A_3B_IMPLEMENTATION_COMPLETE.md    [✅ Phase 3A+3B]
├── PHASE3A_3B_TESTING_GUIDE.md               [✅ Phase 3A+3B]
├── SESSION8_PHASE3AB_SUMMARY.md              [✅ Phase 3A+3B]
└── PHASE3_FILE_MANIFEST.md                   [✅ This file]
```

---

## Build Integration

### What Changed in Build System

**CMakeLists.txt**:
- Added SCRIPTS_DC_ItemUpgrade variable
- Added 3 source files to list
- Added to SCRIPTS_WORLD list

**dc_script_loader.cpp**:
- Added 3 forward declarations
- Added 3 function calls in AddDCScripts()

**Result**: All scripts now compiled into worldserver

---

## Compilation Output

**Build Status**: ✅ SUCCESS
```
[100%] Built target worldserver
```

**No Errors**: ✅
**No Warnings**: ✅
**Linker Errors**: ✅ None
**Undefined References**: ✅ None

---

## Testing Artifacts

### SQL Files for Testing

| File | Purpose | Status |
|------|---------|--------|
| dc_npc_creature_templates.sql | Define NPCs | Ready to execute |
| dc_npc_spawns.sql | Spawn NPCs | Ready to execute |

**Note**: These are OPTIONAL for testing but RECOMMENDED for full feature testing

---

## Total Statistics

### Code
- Source files created: 3 (540 LOC)
- Header files created: 1 (20 LOC)
- Build files modified: 2 (+16 lines)
- **Total code**: 576 LOC

### Documentation
- Implementation guides: 1 (12 KB)
- Testing guides: 1 (18 KB)
- Session summary: 1 (15 KB)
- File manifest: 1 (This file)
- **Total documentation**: 46+ KB

### SQL
- Creature templates: 1 (2 NPCs)
- Spawn locations: 1 (3 spawns)

---

## Execution Sequence

### Step 1: Build (COMPLETED ✅)
```bash
./acore.sh compiler build
Result: ✅ SUCCESS
```

### Step 2: Restart World Server (YOUR STEP)
```bash
./acore.sh run-worldserver
```

### Step 3: (OPTIONAL) Execute NPC SQL
```bash
# In world database:
mysql world < dc_npc_creature_templates.sql
mysql world < dc_npc_spawns.sql
```

### Step 4: Test Commands (YOUR STEP)
```
.upgrade status
.upgrade list
.upgrade info 50000
```

### Step 5: Test NPCs (YOUR STEP - If SQL executed)
- Find NPCs in Stormwind/Orgrimmar/Shattrath
- Click to interact
- Test menu navigation

---

## Dependency Graph

```
ItemUpgradeCommand.cpp
    ├── Includes: CommandScript.h
    ├── Includes: Chat.h
    ├── Includes: Player.h
    └── Includes: Item.h

ItemUpgradeNPC_Vendor.cpp
    ├── Includes: ScriptMgr.h
    ├── Includes: CreatureScript.h
    ├── Includes: CreatureAI.h
    ├── Includes: Player.h
    └── Includes: Chat.h

ItemUpgradeNPC_Curator.cpp
    ├── Includes: ScriptMgr.h
    ├── Includes: CreatureScript.h
    ├── Includes: CreatureAI.h
    ├── Includes: Player.h
    └── Includes: Chat.h
```

All dependencies are standard AzerothCore headers ✅

---

## Files NOT Modified

These files exist but were NOT changed:

- ItemUpgradeManager.h (Phase 1)
- ItemUpgradeManager.cpp (Phase 1)
- All Phase 2 item SQL files
- All Phase 2 currency SQL files
- All other scripts in DC directory

---

## What You Need to Do

### For In-Game Testing
1. Review: PHASE3A_3B_TESTING_GUIDE.md
2. Start worldserver with new build
3. Test commands listed in guide
4. Test NPC menus (if you execute spawn SQLs)
5. Document results

### To Proceed to Phase 3C
1. Complete testing
2. Report any issues found
3. If all pass: Ready for Phase 3C
4. If issues: I'll fix them before Phase 3C

---

## Quick Reference

### Commands to Test
```
.upgrade status         → Show equipped items
.upgrade list          → List upgradeable items
.upgrade info 50000    → Show item details
```

### NPCs to Find (If spawned)
```
NPC 190001 (Vendor)    → Stormwind / Orgrimmar
NPC 190002 (Curator)   → Shattrath
```

### SQL Files to Execute (Optional)
```
1. dc_npc_creature_templates.sql
2. dc_npc_spawns.sql
```

---

## Status Summary

| Component | Status |
|-----------|--------|
| Source Code | ✅ Created |
| Headers | ✅ Created |
| Build Integration | ✅ Done |
| Compilation | ✅ Success |
| Documentation | ✅ Complete |
| Testing Guide | ✅ Ready |
| In-Game Testing | ⏳ Your Turn |
| SQL Spawn Files | ✅ Ready |

---

## Next Phases

### Phase 3C: Database Integration
- Extend ItemUpgradeManager with database queries
- Connect commands to database
- Connect NPCs to database
- Add login/equip/loot hooks

### Phase 3D: Testing & Refinement
- Comprehensive test suite
- Edge case testing
- Performance testing
- Final optimizations

---

## Support Files

For more information, see:
- **PHASE3A_3B_IMPLEMENTATION_COMPLETE.md** - Technical details
- **PHASE3A_3B_TESTING_GUIDE.md** - How to test
- **SESSION8_PHASE3AB_SUMMARY.md** - Session summary

---

**Created**: November 4, 2025  
**Status**: Build Complete, Ready for Testing  
**Next**: In-Game Testing and Phase 3C Integration

---

## Quick Checklist

Before testing, verify:
- ✅ Build completed successfully
- ✅ Worldserver started with new build
- ✅ Admin character logged in
- ✅ Testing guide available
- ✅ Ready to test 15 different scenarios

**Good luck with testing! 🎮**
