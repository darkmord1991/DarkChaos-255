# Dungeon Quest System - Master File Locations

**Last Updated:** November 3, 2025  
**System Status:** ✅ Production Ready v2.0

---

## 🎯 QUICK START - Files You Need

### For Deployment, Use Only These Files:

#### 1️⃣ Character Database
📁 **Location:** `Custom/Custom feature SQLs/characterdb/`
- `DC_CHARACTER_DUNGEON_QUEST_SCHEMA.sql` ✅ **DEPLOY THIS**

#### 2️⃣ World Database  
📁 **Location:** `Custom/Custom feature SQLs/worlddb/`
- `DC_DUNGEON_QUEST_SCHEMA_v2.sql` ✅ **DEPLOY THIS**
- `DC_DUNGEON_QUEST_CREATURES_v2.sql` ✅ **DEPLOY THIS**
- `DC_DUNGEON_QUEST_TEMPLATES_v2.sql` ✅ **DEPLOY THIS**
- `DC_DUNGEON_QUEST_TOKEN_REWARDS_v2.sql` ✅ **DEPLOY THIS**
- `DC_WORLD_DUNGEON_QUEST_SCHEMA.sql` ✅ **DEPLOY THIS (Optional - additional config)**

#### 3️⃣ DBC Files (Client Data)
📁 **Location:** `Custom/DBCs/` and `Custom/CSV DBC/`
- `Achievement.dbc` ✅ **COPY TO CLIENT**
- `CharTitles.dbc` ✅ **COPY TO CLIENT**
- `ACHIEVEMENTS_DUNGEON_QUESTS_COMPLETE.csv` ✅ **REFERENCE**

#### 4️⃣ Documentation
📁 **Location:** `Custom/feature stuff/DungeonQuestSystem/`
- `00_START_HERE.md` - System overview
- `DEPLOYMENT_GUIDE_v2_CORRECTED.md` - Deployment instructions
- `DEPLOYMENT_CHECKLIST.md` - Verification checklist

#### 5️⃣ C++ Implementation (Future - Phase 3)
📁 **Location:** `src/server/scripts/Custom/DC/` (to be created)
- `npc_dungeon_quest_master_v2.cpp` - Quest event handlers

---

## 📂 Complete Directory Structure

```
DarkChaos-255/
│
├── Custom/
│   │
│   ├── Custom feature SQLs/
│   │   ├── characterdb/                         ← CHARACTER DATABASE
│   │   │   └── DC_CHARACTER_DUNGEON_QUEST_SCHEMA.sql ✅ CURRENT
│   │   │
│   │   ├── worlddb/                             ← WORLD DATABASE
│   │   │   ├── DC_DUNGEON_QUEST_SCHEMA_v2.sql  ✅ CURRENT (v2.0)
│   │   │   ├── DC_DUNGEON_QUEST_CREATURES_v2.sql ✅ CURRENT (v2.0)
│   │   │   ├── DC_DUNGEON_QUEST_TEMPLATES_v2.sql ✅ CURRENT (v2.0)
│   │   │   ├── DC_DUNGEON_QUEST_TOKEN_REWARDS_v2.sql ✅ CURRENT (v2.0)
│   │   │   └── DC_WORLD_DUNGEON_QUEST_SCHEMA.sql ✅ NEW (Nov 3, 2025)
│   │   │
│   │   ├── DUNGEON_QUEST_DATABASE_SCHEMA.sql    ❌ OUTDATED (Nov 2)
│   │   └── README_DUNGEON_QUEST_FILES.md        📘 FILE ORGANIZATION GUIDE
│   │
│   ├── DBCs/                                    ← DBC BINARY FILES
│   │   ├── Achievement.dbc                      ✅ MODIFIED (52 achievements)
│   │   ├── Achievement.dbc.backup               📦 BACKUP
│   │   ├── CharTitles.dbc                       ✅ MODIFIED (52 titles)
│   │   └── CharTitles.dbc.backup                📦 BACKUP
│   │
│   ├── CSV DBC/                                 ← CSV REFERENCE FILES
│   │   ├── Achievement.csv                      📄 EXPORT REFERENCE
│   │   ├── ACHIEVEMENTS_DUNGEON_QUESTS_COMPLETE.csv ✅ LATEST CSV
│   │   └── TITLES_DUNGEON_QUESTS.csv           📄 TITLES CSV
│   │
│   └── feature stuff/
│       └── DungeonQuestSystem/                  ← DOCUMENTATION HUB
│           ├── FILE_LOCATIONS_MASTER.md         📘 THIS FILE
│           ├── 00_START_HERE.md                 📘 START HERE
│           ├── 00_READ_ME_FIRST.md              📘 PROJECT OVERVIEW
│           ├── DEPLOYMENT_GUIDE_v2_CORRECTED.md 📘 DEPLOYMENT STEPS
│           ├── DEPLOYMENT_CHECKLIST.md          ✅ VERIFICATION
│           ├── QUICK_REFERENCE_GUIDE.md         📘 30-SECOND OVERVIEW
│           ├── MASTER_INDEX.md                  📘 NAVIGATION
│           ├── VERSION_2.0_COMPLETE_SUMMARY.md  📘 v2.0 STATUS
│           │
│           ├── DUNGEON_QUEST_NPC_SCHEMA_AND_ACHIEVEMENTS.sql ❌ OUTDATED
│           └── [40+ other documentation files]
│
└── src/server/scripts/Custom/DC/                ← C++ SCRIPTS (Future)
    └── npc_dungeon_quest_master_v2.cpp          ⏳ PHASE 3 (Not yet deployed)
```

---

## 🔍 File Status Legend

- ✅ **CURRENT** - Production ready, use this
- ❌ **OUTDATED** - Old version, do not use
- ⏳ **FUTURE** - Planned for future phase
- 📘 **DOCUMENTATION** - Reference material
- 📄 **REFERENCE** - CSV/export files
- 📦 **BACKUP** - Backup files

---

## 📋 What Each File Does

### Character Database

#### `DC_CHARACTER_DUNGEON_QUEST_SCHEMA.sql`
**Tables:** 5 tables with `dc_` prefix
- Tracks player progress through dungeon quests
- Records quest completion history
- Manages NPC respawn status (per-player phasing)
- Stores player statistics for achievements
- Handles daily/weekly reset tracking

**Execute in:** `acore_characters` database

---

### World Database

#### `DC_DUNGEON_QUEST_SCHEMA_v2.sql`
**Tables:** 3 tables with `dc_` prefix
- `dc_quest_reward_tokens` - Token item definitions
- `dc_daily_quest_token_rewards` - Daily quest rewards
- `dc_weekly_quest_token_rewards` - Weekly quest rewards

**Execute in:** `acore_world` database

#### `DC_DUNGEON_QUEST_CREATURES_v2.sql`
**Tables:** Standard AC tables
- Adds 53 quest master NPCs to `creature_template`
- Proper faction, display IDs, scripts
- Covers all 53 dungeons

**Execute in:** `acore_world` database

#### `DC_DUNGEON_QUEST_TEMPLATES_v2.sql`
**Tables:** Standard AC tables
- Adds 16+ quests to `quest_template`
- Daily/weekly flags configured (0x0800, 0x1000)
- Links quests to NPCs via `creature_questrelation`

**Execute in:** `acore_world` database

#### `DC_DUNGEON_QUEST_TOKEN_REWARDS_v2.sql`
**Tables:** Custom token reward tables
- Links quests to token rewards
- Configures token counts per quest

**Execute in:** `acore_world` database

#### `DC_WORLD_DUNGEON_QUEST_SCHEMA.sql` (Optional)
**Tables:** 7 tables with `dc_` prefix
- Additional dungeon configuration
- NPC spawning and phasing system
- Quest objective definitions
- Reward configuration
- System config

**Execute in:** `acore_world` database (optional if using v2 files)

---

### DBC Files

#### `Achievement.dbc`
**Format:** Binary DBC file
- 1,916 total achievements (1,864 original + 52 new)
- New IDs: 13500-13551
- 52 dungeon quest achievements added

**Deploy to:** `WoW Client/Data/enUS/DBFilesClient/`

#### `CharTitles.dbc`
**Format:** Binary DBC file
- 204 total titles (152 original + 52 new)
- New IDs: 188-239
- 52 dungeon quest titles added

**Deploy to:** `WoW Client/Data/enUS/DBFilesClient/`

#### `ACHIEVEMENTS_DUNGEON_QUESTS_COMPLETE.csv`
**Format:** CSV reference file
- Contains all 52 achievement definitions
- Includes IconID, Reward_Lang fields
- Use for WDBX import or reference

---

### Documentation Files

#### `00_START_HERE.md`
- Project status overview
- Quick statistics
- File locations summary
- **START HERE** if new to the project

#### `DEPLOYMENT_GUIDE_v2_CORRECTED.md`
- Step-by-step deployment instructions
- SQL execution order
- Verification steps
- Troubleshooting

#### `DEPLOYMENT_CHECKLIST.md`
- Interactive checklist
- Verify each step
- Track progress

#### `README_DUNGEON_QUEST_FILES.md`
- File organization guide
- Version comparison
- Deployment order
- Table summary

---

## ⚠️ Important Notes

### Files to AVOID (Outdated)

1. **`Custom/Custom feature SQLs/DUNGEON_QUEST_DATABASE_SCHEMA.sql`** ❌
   - Old combined file (character + world DB mixed)
   - **Replaced by:** Separated character/world files
   - **Date:** Nov 2, 2025 (outdated)

2. **`Custom/feature stuff/DungeonQuestSystem/DUNGEON_QUEST_NPC_SCHEMA_AND_ACHIEVEMENTS.sql`** ❌
   - Old schema without dc_ prefix
   - Over-engineered (10+ tables)
   - **Replaced by:** v2 files
   - **Date:** Nov 2, 2025 (outdated)

### Why Two Schema Files?

You might notice two world database schema files:

1. **DC_DUNGEON_QUEST_SCHEMA_v2.sql** (v2 files)
   - Minimal, AzerothCore standard compliant
   - Uses existing AC tables (quest_template, creature_template)
   - Only adds 3 custom tables for tokens
   - **Recommended for production**

2. **DC_WORLD_DUNGEON_QUEST_SCHEMA.sql** (New comprehensive)
   - Additional dungeon configuration system
   - Adds 7 more custom tables
   - More features: phasing, NPC spawning, quest objectives
   - **Optional - for advanced features**

**You can use:**
- **Option A:** Just v2 files (minimal, production-ready)
- **Option B:** v2 files + world schema (full feature set)

---

## 📊 Deployment Timeline

### ✅ Phase 1A: DBC Implementation (COMPLETE)
- Achievement.dbc modified ✅
- CharTitles.dbc modified ✅
- CSV files created ✅

### ⏳ Phase 1B: Database Deployment (READY TO START)
- Character DB schema deployment
- World DB schema deployment
- Quest configuration
- NPC spawning

### ⏳ Phase 2: C++ Implementation (PENDING)
- Quest event handlers
- Token reward logic
- Achievement triggers
- Title rewards

### ⏳ Phase 3: Testing & QA (PENDING)
- In-game testing
- Quest functionality verification
- Achievement unlock testing
- Title reward testing

### ⏳ Phase 4: Production Deployment (PENDING)
- Server deployment
- Client updates
- Player announcement

---

## 🆘 Need Help?

**If deployment issues occur:**
1. Check `README_DUNGEON_QUEST_FILES.md` for file organization
2. Review `DEPLOYMENT_GUIDE_v2_CORRECTED.md` for step-by-step
3. Use `DEPLOYMENT_CHECKLIST.md` to track progress
4. Reference this file for correct file locations

**If files are missing:**
- All v2 SQL files should be in `Custom/Custom feature SQLs/worlddb/`
- Character DB file should be in `Custom/Custom feature SQLs/characterdb/`
- DBC files should be in `Custom/DBCs/`

---

## 📞 Quick Reference

| What You Need | File Location |
|--------------|---------------|
| Character DB Schema | `Custom/Custom feature SQLs/characterdb/DC_CHARACTER_DUNGEON_QUEST_SCHEMA.sql` |
| World DB Schema (v2) | `Custom/Custom feature SQLs/worlddb/DC_DUNGEON_QUEST_SCHEMA_v2.sql` |
| NPC Creatures | `Custom/Custom feature SQLs/worlddb/DC_DUNGEON_QUEST_CREATURES_v2.sql` |
| Quest Templates | `Custom/Custom feature SQLs/worlddb/DC_DUNGEON_QUEST_TEMPLATES_v2.sql` |
| Token Rewards | `Custom/Custom feature SQLs/worlddb/DC_DUNGEON_QUEST_TOKEN_REWARDS_v2.sql` |
| Achievement DBC | `Custom/DBCs/Achievement.dbc` |
| Titles DBC | `Custom/DBCs/CharTitles.dbc` |
| Deployment Guide | `Custom/feature stuff/DungeonQuestSystem/DEPLOYMENT_GUIDE_v2_CORRECTED.md` |
| File Organization | `Custom/Custom feature SQLs/README_DUNGEON_QUEST_FILES.md` |

---

**End of Master File Locations Guide**
