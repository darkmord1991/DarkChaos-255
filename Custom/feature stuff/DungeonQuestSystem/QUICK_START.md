# 🎮 Dungeon Quest System - Complete Package

## 📦 What's Included

This package contains a fully-implemented dungeon quest system for AzerothCore using **official Blizzard quest IDs** and **canonical WoW map IDs**.

### ✅ Complete Deliverables

| File | Purpose | Status |
|------|---------|--------|
| **SQL Files** | | |
| `sql/01_dc_dungeon_quest_mapping.sql` | Core mapping table (435 quests) | ✅ Ready |
| `sql/02_creature_quest_relations.sql` | NPC quest starter/ender links | ✅ Ready |
| `sql/99_verification_queries.sql` | Database validation checks | ✅ Ready |
| **Data Files** | | |
| `data/dungeon_quests_clean.csv` | Normalized quest data | ✅ Ready |
| `data/dungeon_quests_summary.csv` | Per-dungeon statistics | ✅ Ready |
| `data/dungeon_quest_map_correlation.csv` | Quest→Map ID mappings | ✅ Ready |
| **Documentation** | | |
| `README.md` | Complete system documentation | ✅ Ready |
| `IMPLEMENTATION_SUMMARY.md` | Implementation overview | ✅ Ready |
| `CPP_UPDATE_GUIDE.md` | C++ script modification guide | ✅ Ready |
| `QUICK_START.md` | This file | ✅ Ready |

---

## 🚀 Quick Start (5 Minutes)

### Step 1: Import SQL Files
```bash
# Navigate to SQL directory
cd "Custom/feature stuff/DungeonQuestSystem/sql"

# Import mapping table
mysql -u root -p acore_world < 01_dc_dungeon_quest_mapping.sql

# Import quest relations
mysql -u root -p acore_world < 02_creature_quest_relations.sql

# Verify installation (optional)
mysql -u root -p acore_world < 99_verification_queries.sql
```

### Step 2: Spawn Quest Master NPCs
In-game, spawn the quest master NPCs at your preferred locations:

```
.npc add 700000    # Classic Dungeon Quest Master (Stormwind/Orgrimmar)
.npc add 700001    # TBC Dungeon Quest Master (Shattrath)
.npc add 700002    # WotLK Dungeon Quest Master (Dalaran)
```

### Step 3: Test the System
Talk to any quest master NPC and browse available quests!

---

## 📊 System Overview

### Quest Distribution
- **Total Quests**: 435 (all using Blizzard quest IDs)
- **Classic Dungeons**: 341 quests (NPC 700000)
- **TBC Dungeons**: 37 quests (NPC 700001)
- **WotLK Dungeons**: 57 quests (NPC 700002)

### Top Dungeons
1. Blackrock Depths - 43 quests
2. Caverns of Time - 40 quests
3. Blackrock Spire - 37 quests
4. Dire Maul - 37 quests
5. Uldaman - 29 quests

### Database Tables
- `dc_dungeon_quest_mapping` - Core quest-to-dungeon mappings
- `creature_queststarter` - Quest giver NPCs
- `creature_questender` - Quest completer NPCs
- `quest_template` - Standard WoW quest definitions (existing data)

---

## 🔧 Advanced Setup

### C++ Script Integration (Optional)
If you want to integrate with the existing `DungeonQuestSystem.cpp` script:

1. Read `CPP_UPDATE_GUIDE.md` for detailed instructions
2. Update C++ scripts to query database instead of hardcoded ranges
3. Recompile server
4. Test token rewards and achievements

**Estimated Time**: 4-5 hours for full C++ integration

### Daily/Weekly Quest Rotation (Future)
The system supports daily/weekly quest rotation but requires additional setup:
- Implement `dc_daily_quest_rotation` table
- Implement `dc_weekly_quest_rotation` table
- Update reset handlers

---

## 📖 Documentation Index

### For Server Administrators
- **README.md** - Complete system documentation with installation guides
- **IMPLEMENTATION_SUMMARY.md** - Technical overview and statistics
- **sql/99_verification_queries.sql** - Database validation checks

### For Developers
- **CPP_UPDATE_GUIDE.md** - How to modify C++ scripts
- **data/README.md** - Data pipeline documentation
- **data/*.csv** - Source data files for reference

### For Players
- Talk to quest master NPCs (700000, 700001, 700002)
- Browse quests by category (Daily/Weekly/Dungeon/All)
- Complete dungeons and earn rewards

---

## ✅ Verification Checklist

After installation, verify everything works:

### Database Checks
```sql
-- Should return 435
SELECT COUNT(*) FROM dc_dungeon_quest_mapping;

-- Should return 435
SELECT COUNT(*) FROM creature_queststarter WHERE id IN (700000, 700001, 700002);

-- Should return 435
SELECT COUNT(*) FROM creature_questender WHERE id IN (700000, 700001, 700002);

-- Should return 0 (no unmapped quests)
SELECT COUNT(*) FROM dc_dungeon_quest_mapping WHERE map_id = 0;
```

### In-Game Testing
- [ ] NPC 700000 spawned and shows quests
- [ ] NPC 700001 spawned and shows quests
- [ ] NPC 700002 spawned and shows quests
- [ ] Can accept quests from NPCs
- [ ] Can complete quests
- [ ] Gossip menu categories work (Daily/Weekly/Dungeon/All)

---

## 🎯 Features

### Current Implementation ✅
- 435 Blizzard dungeon quests properly mapped
- Standard WoW map IDs from official DBC files
- Three quest master NPCs (one per expansion)
- Database-driven quest-to-dungeon mapping
- Quest filtering by category

### Planned Enhancements ⏳
- Token reward system integration
- Achievement tracking per dungeon
- Statistics system (completions, fastest times)
- Daily/Weekly quest rotation
- Prestige system (optional)

---

## 🆘 Troubleshooting

### Common Issues

**Issue**: Quest NPCs don't show any quests  
**Solution**: 
```sql
-- Check if quest relations exist
SELECT COUNT(*) FROM creature_queststarter WHERE id = 700000;
-- Should be > 0
```

**Issue**: Some quests show incorrect levels  
**Solution**: 
```sql
-- Check mapping table
SELECT quest_id, dungeon_name, quest_level, level_type 
FROM dc_dungeon_quest_mapping 
WHERE quest_level = 0 OR quest_level > 80;
-- Should return 0 rows
```

**Issue**: Quests appear but can't be accepted  
**Solution**: Ensure `quest_template` table has the quest entries (these are Blizzard's official quests from WoW database)

### Debug Queries
Run `sql/99_verification_queries.sql` for comprehensive database validation.

---

## 📞 Support Resources

1. **Installation Issues**: See README.md → Installation section
2. **Database Errors**: Run sql/99_verification_queries.sql
3. **C++ Integration**: See CPP_UPDATE_GUIDE.md
4. **Data Questions**: See data/README.md

---

## 📈 Statistics at a Glance

```
Total Quests:        435
Unique Dungeons:     43
Map IDs Used:        Classic (19), TBC (15), WotLK (11)
Quest Masters:       3 NPCs (700000, 700001, 700002)
Database Tables:     1 custom table + 2 standard tables
CSV Files:           3 data files
SQL Files:           3 scripts (2 setup + 1 verification)
Documentation:       4 comprehensive guides
```

---

## 🎖️ Credits

- **Quest Data**: Official Blizzard quest IDs
- **Map IDs**: Extracted from Map.csv DBC file
- **Framework**: AzerothCore
- **Implementation**: DarkChaos-255 custom server

---

## 📝 License

This system uses official Blizzard quest data and is intended for use with AzerothCore private servers for educational purposes only.

---

## 🔗 Quick Links

- [Full Documentation](README.md)
- [Implementation Summary](IMPLEMENTATION_SUMMARY.md)
- [C++ Update Guide](CPP_UPDATE_GUIDE.md)
- [Data Files](data/)
- [SQL Scripts](sql/)

---

## 🎉 Ready to Go!

Your dungeon quest system is ready for deployment. Simply:
1. Import the SQL files
2. Spawn the quest master NPCs
3. Start questing!

Enjoy your enhanced dungeon questing experience! 🎮
