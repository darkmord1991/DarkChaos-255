# 🗂️ DarkChaos Dungeon Quest System - File Manifest

## Quick Navigation

### 📍 Start Here
- **For quick orientation**: `Custom/Custom feature SQLs/START_HERE.md`
- **For project overview**: `PROJECT_OVERVIEW.md`
- **For current status**: `PHASE_2_COMPLETION_SUMMARY.md`

---

## ✅ COMPLETE & READY (Phase 1, 1B, 2)

### C++ Command System
```
src/server/scripts/Commands/
├── cs_dc_dungeonquests.cpp             [1000+ lines] ✅ CREATED
│   Purpose: Admin commands for quest management
│   Features: 10 subcommands, debug mode, DB integration
│   Status: COMPILED SUCCESSFULLY (0 errors, 0 warnings)
│
└── cs_script_loader.cpp                [MODIFIED] ✅ INTEGRATED
    Changes: Added registration for dc_dungeonquests command
```

### NPC Quest Handler
```
src/server/scripts/Custom/DC/
└── npc_dungeon_quest_master_v2.cpp     [250+ lines] ✅ READY
    Purpose: Quest acceptance/completion event handlers
    Status: Ready to deploy
```

### SQL Database Schema (v2.0 - CORRECTED)
```
Custom/Custom feature SQLs/worlddb/
├── DC_DUNGEON_QUEST_SCHEMA_v2.sql            [500+ lines] ✅
│   Purpose: Create 4 custom database tables
│   Tables: dc_quest_reward_tokens, dc_daily/weekly_quest_token_rewards, dc_npc_quest_link
│   Status: READY FOR DEPLOYMENT
│
├── DC_DUNGEON_QUEST_CREATURES_v2.sql         [600+ lines] ✅ FIXED
│   Purpose: Create NPC templates and quest linking
│   Key Fix: Changed to creature_queststarter/creature_questender (v2.0)
│   NPCs: 53 templates (IDs 700000-700052)
│   Locations: Orgrimmar, Shattrath, Dalaran
│   Status: READY FOR DEPLOYMENT
│
├── DC_DUNGEON_QUEST_TEMPLATES_v2.sql         [400+ lines] ✅
│   Purpose: Define quest templates
│   Quests: 4 daily (0x0800), 4 weekly (0x1000), 8+ dungeon
│   Status: READY FOR DEPLOYMENT
│
└── DC_DUNGEON_QUEST_TOKEN_REWARDS_v2.sql     [300+ lines] ✅
    Purpose: Configure token reward system
    Features: Token definitions, multiplier system
    Status: READY FOR DEPLOYMENT
```

### Documentation (Complete & Organized)
```
Custom/Custom feature SQLs/
├── START_HERE.md                       ✅ Quick start guide
├── DC_DUNGEON_QUEST_DEPLOYMENT.md      ✅ Full deployment guide
├── FILE_ORGANIZATION.md                ✅ File reference
├── PHASE_2_COMPLETE.md                 ✅ C++ compilation report
├── IMPLEMENTATION_CHECKLIST.md         ✅ Complete task checklist
├── CORRECTIONS_COMPLETE.md             ✅ v1.0→v2.0 changes
├── FINAL_STATUS.md                     ✅ Status reports
└── README.md                           ✅ Folder overview

Custom/CSV DBC/
└── DBC_MODIFICATION_GUIDE.md           ✅ How to update DBC files

Root/
├── IMPLEMENTATION_STATUS_REPORT.md     ✅ Master status document
├── PHASE_2_COMPLETION_SUMMARY.md       ✅ Phase 2 summary
└── PROJECT_OVERVIEW.md                 ✅ Complete project overview
```

---

## ⏳ PENDING (Phase 3, 4, 5)

### CSV Reference Files (For DBC Modification)
```
Custom/CSV DBC/DC_Dungeon_Quests/
├── dc_items_tokens.csv                ⏳ REFERENCE for Item.dbc updates
│   Contains: 5 token definitions (700001-700005)
│   Use: As template when updating Item.dbc
│
├── dc_achievements.csv                ⏳ REFERENCE for Achievement.dbc updates
│   Contains: 35+ achievement definitions (700001-700403)
│   Use: As template when updating Achievement.dbc
│
├── dc_titles.csv                      ⏳ REFERENCE for CharTitles.dbc updates
│   Contains: 15 title definitions (1000-1102)
│   Use: As template when updating CharTitles.dbc
│
└── dc_dungeon_npcs.csv                📋 REFERENCE ONLY
    Contains: NPC metadata for reference
```

### DBC Files (To Be Modified in Phase 3)
```
Custom/DBCs/
├── Item.dbc                           ⏳ TO UPDATE (add 5 token items)
├── Achievement.dbc                    ⏳ TO UPDATE (add 35+ achievements)
└── CharTitles.dbc                     ⏳ TO UPDATE (add 15 titles)
```

### Tools Location (For Phase 3 DBC Work)
```
apps/extractor/                        ⏳ TO INVESTIGATE
tools/                                 ⏳ TO INVESTIGATE
Purpose: Find DBC export/compile tools
```

---

## 🎯 Usage Guide by Phase

### Phase 1 & 1B: Already Complete ✅
- All SQL files v2.0 generated and corrected
- All C++ code files created
- All documentation written
- Ready for Phase 2 (which is now complete!)

### Phase 2: Already Complete ✅
- C++ command system created
- Successfully compiled (0 errors)
- Integrated into script loader
- Ready for Phase 3

### Phase 3: Next (DBC Modifications)
**Reference Files**:
- Guide: `Custom/CSV DBC/DBC_MODIFICATION_GUIDE.md` ⭐
- Token template: `Custom/CSV DBC/DC_Dungeon_Quests/dc_items_tokens.csv`
- Achievement template: `Custom/CSV DBC/DC_Dungeon_Quests/dc_achievements.csv`
- Title template: `Custom/CSV DBC/DC_Dungeon_Quests/dc_titles.csv`

**Steps**:
1. Read: `DBC_MODIFICATION_GUIDE.md`
2. Find tools in: `apps/extractor/`
3. Export DBC files to CSV
4. Merge with reference CSV data
5. Recompile DBC files
6. Update `Custom/DBCs/` files

### Phase 4: SQL Deployment
**Reference Files**:
- Guide: `Custom/Custom feature SQLs/DC_DUNGEON_QUEST_DEPLOYMENT.md` ⭐
- SQL files in: `Custom/Custom feature SQLs/worlddb/`

**Steps**:
1. Read: `DC_DUNGEON_QUEST_DEPLOYMENT.md`
2. Deploy SQL files in order (4 files)
3. Verify tables created
4. Proceed to Phase 5

### Phase 5: Testing & Validation
**Reference Files**:
- Checklist: `Custom/Custom feature SQLs/IMPLEMENTATION_CHECKLIST.md` ⭐

**Test Categories**:
- Quest visibility and acceptance
- Admin command functionality
- Debug mode operation
- Token/achievement/title system
- Error handling

---

## 📊 File Statistics

### Code Files
| Type | Count | Lines | Status |
|------|-------|-------|--------|
| C++ Files | 2 | 1000+ | ✅ READY |
| SQL Files | 4 | 1800+ | ✅ READY |
| CSV Files | 4 | 100+ | 📋 REFERENCE |
| **Total** | **10** | **3000+** | **✅ READY** |

### Documentation Files
| Type | Count | Pages | Status |
|------|-------|-------|--------|
| Guides | 3 | 20+ | ✅ COMPLETE |
| Checklists | 1 | 15+ | ✅ COMPLETE |
| Status Reports | 4 | 20+ | ✅ COMPLETE |
| References | 2 | 10+ | ✅ COMPLETE |
| **Total** | **10** | **65+** | **✅ COMPLETE** |

### Data Definitions
| Type | Count | Range | Status |
|------|-------|-------|--------|
| NPCs | 53 | 700000-700052 | ✅ DEFINED |
| Quests | 16 | 700101-700999 | ✅ DEFINED |
| Tokens | 5 | 700001-700005 | ✅ DEFINED |
| Achievements | 35+ | 700001-700403 | ✅ DEFINED |
| Titles | 15 | 1000-1102 | ✅ DEFINED |

---

## 🔍 File Location Quick Reference

### By Functionality

**Admin Commands**:
- `src/server/scripts/Commands/cs_dc_dungeonquests.cpp`

**Quest Handlers**:
- `src/server/scripts/Custom/DC/npc_dungeon_quest_master_v2.cpp`

**Database Schema**:
- `Custom/Custom feature SQLs/worlddb/DC_DUNGEON_QUEST_*.sql` (4 files)

**DBC/CSV Data**:
- `Custom/CSV DBC/DC_Dungeon_Quests/dc_*.csv` (4 files)
- `Custom/DBCs/Item.dbc`, `Achievement.dbc`, `CharTitles.dbc`

**Guides & Documentation**:
- `Custom/Custom feature SQLs/START_HERE.md`
- `Custom/Custom feature SQLs/DC_DUNGEON_QUEST_DEPLOYMENT.md`
- `Custom/CSV DBC/DBC_MODIFICATION_GUIDE.md`
- `IMPLEMENTATION_CHECKLIST.md`

**Status & Overview**:
- `IMPLEMENTATION_STATUS_REPORT.md`
- `PHASE_2_COMPLETION_SUMMARY.md`
- `PROJECT_OVERVIEW.md`

---

## 🚀 Quick Command Reference

### Compilation (Already Done ✅)
```bash
./acore.sh compiler build
# Result: ✅ COMPILATION SUCCESSFUL (0 Errors, 0 Warnings)
```

### DBC Export (Phase 3)
```bash
# Locate tools first
ls -la apps/extractor/
# Then use tool to export (command varies)
./dbc_extract Custom/DBCs/Item.dbc -o Custom/CSV_DBC/Item_export.csv
```

### SQL Deployment (Phase 4)
```bash
# Via MySQL client
SOURCE Custom/Custom\ feature\ SQLs/worlddb/DC_DUNGEON_QUEST_SCHEMA_v2.sql;
SOURCE Custom/Custom\ feature\ SQLs/worlddb/DC_DUNGEON_QUEST_CREATURES_v2.sql;
SOURCE Custom/Custom\ feature\ SQLs/worlddb/DC_DUNGEON_QUEST_TEMPLATES_v2.sql;
SOURCE Custom/Custom\ feature\ SQLs/worlddb/DC_DUNGEON_QUEST_TOKEN_REWARDS_v2.sql;
```

### Testing (Phase 5)
```
/run print(GetItemInfo(700001))              # Check token item
.dcquests help                              # Show admin commands
.dcquests debug on                          # Enable debug logging
.dcquests list daily                        # List daily quests
```

---

## ✅ Verification Checklist

Before proceeding to next phase, verify:

**Phase 2 Complete?** ✅
- [x] C++ code compiled (0 errors)
- [x] Script loader integrated
- [x] Command system created

**Phase 3 Ready?** ⏳
- [ ] DBC tools located
- [ ] Reference CSV files present
- [ ] DBC modification guide reviewed

**Phase 4 Ready?** ⏳
- [ ] SQL files present
- [ ] Database backed up
- [ ] Deployment guide reviewed

**Phase 5 Ready?** ⏳
- [ ] Test environment available
- [ ] Admin account prepared
- [ ] Test cases reviewed

---

## 📋 File Dependency Map

```
                    PROJECT_OVERVIEW.md
                            │
         ┌──────────────────┼──────────────────┐
         │                  │                  │
    PHASE_2_               IMPLEMENTATION_    START_HERE.md
    COMPLETION_            STATUS_REPORT.md   (Quick Start)
    SUMMARY.md                │
         │                  ┌──┴───┬────────┐
         │                  │      │        │
         │         ┌────────┘   ┌──┴──┐   ┌─┴────┐
         │         │            │     │   │      │
    Phase 1-2  Phase 3 Guide  SQL  C++  CSV  Tests
    Complete   (DBC_MOD)     Deploy Code Files


Key Dependencies:
Phase 3 → Requires: apps/extractor/ (tools)
Phase 4 → Requires: Phase 3 complete (DBC files)
Phase 5 → Requires: Phase 4 complete (DB deployed)
```

---

## 📞 Support File Directory

**"I need to..."**

| Task | File |
|------|------|
| Get started quickly | `START_HERE.md` |
| Deploy SQL to database | `DC_DUNGEON_QUEST_DEPLOYMENT.md` |
| Update DBC files | `DBC_MODIFICATION_GUIDE.md` |
| See complete checklist | `IMPLEMENTATION_CHECKLIST.md` |
| Check current status | `IMPLEMENTATION_STATUS_REPORT.md` |
| Understand architecture | `PROJECT_OVERVIEW.md` |
| See Phase 2 summary | `PHASE_2_COMPLETION_SUMMARY.md` |

---

**📂 Total Files**: 30+
**📄 Total Documentation**: 65+ pages
**💾 Total Code**: 3000+ lines
**✅ Status**: Phase 2 Complete, Ready for Phase 3

*Last Updated: Current Session*
*Next Action: Phase 3 - DBC Modifications*
