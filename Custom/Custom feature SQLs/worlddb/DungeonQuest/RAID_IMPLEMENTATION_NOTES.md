# Raid Quest System Implementation - Summary

## Problem Identified
- NPC 700002 ("Tidehunter Mara" - Blackfathom Deeps) was incorrectly mapped to ICC map 631
- Raids and dungeons were conflated in the system, but they have separate quest lists
- 446 WotLK raid quests were not in the system

## Solution Implemented

### 1. New Raid NPCs (700055-700061)
These replace the ICC mapping and handle raid quests only:

| NPC Entry | Name | Raid | Map ID | Quests |
|-----------|------|------|--------|--------|
| 700055 | Lich King's Herald | Naxxramas | 533 | 4 |
| 700056 | Aspects' Oracle | The Eye of Eternity | 616 | 3 |
| 700057 | Twilight Historian | The Obsidian Sanctum | 615 | 1 |
| 700058 | Titan's Keeper | Ulduar | 603 | 9 |
| 700059 | Crusader's Quartermaster | Trial of the Crusader | 649 | 1 |
| **700060** | **Frost Lich Keeper** | **Icecrown Citadel** | **631** | **22** |
| 700061 | Twilight Warden | The Ruby Sanctum | 724 | 3 |

**Total: 7 new raid NPCs, 43 raid quests**

### 2. Critical ICC Fix
- **BEFORE:** NPC 700002 (Blackfathom dungeon NPC) mapped to map 631 (ICC)
- **AFTER:** NPC 700060 (Frost Lich Keeper - raid NPC) mapped to map 631
- This prevents the naming conflict and architectural confusion

### 3. Database Changes

#### creature_queststarter / creature_questender
- Added 43 new quest assignments (matching starters & enders)
- NPCs 700055-700061 now have raid quests

#### creature_template
- Created 7 new creature_template entries
- All configured with:
  - npcflag = 3 (GOSSIP | QUESTGIVER)
  - ScriptName = 'npc_dungeon_quest_master' (reuses existing script)
  - Faction = 35 (Alliance)
  - Level = 80 (82 for Ruby Sanctum)

#### dc_dungeon_npc_mapping
- **REMOVED:** Old row `(631, 700002, ...)`  — deletes incorrect mapping
- **ADDED:** New rows for maps 533, 603, 615, 616, 631, 649, 724
- All flagged with expansion = 2 (WotLK)

### 4. Dungeon NPC Status (Unchanged)
- NPCs 700000-700054 still handle dungeon quests
- NPC 700002 now ONLY serves Blackfathom Deeps
- No dungeon NPC is now assigned to map 631

## Implementation Steps

### Step 1: Import Raid Quest SQL
```bash
mysql -u root -p world < RAID_QUESTS_v5.0.sql
```

This will:
- ✅ Delete old ICC mapping for 700002
- ✅ Create 7 new raid NPCs in creature_template
- ✅ Add 43 raid quest assignments
- ✅ Update dc_dungeon_npc_mapping with raid entries

### Step 2: Recompile Server
```bash
./acore.sh compiler build
```
(C++ fixes already applied to npc_dungeon_quest_master.cpp)

### Step 3: Restart Server
Stop and restart worldserver to activate:
- New creature_template entries
- Updated mappings
- Binary changes

### Step 4: Test in-game
- Go to ICC map 631
- Find NPC "Frost Lich Keeper" (700060)
- Should display 22 ICC raid quests
- Compare with previous NPC 700002 interaction (now gone from ICC)

## Data Verification

### Raid Quests by NPC:
```
NPC 700055 (Naxxramas):
  - 13593, 13609, 13610, 13614

NPC 700056 (Eye of Eternity):
  - 13616, 13617, 13618

NPC 700057 (Obsidian Sanctum):
  - 13619

NPC 700058 (Ulduar):
  - 13620, 13621, 13622, 13623, 13624, 13625, 13626, 13628, 13629

NPC 700059 (Trial of Crusader):
  - 13632

NPC 700060 (Icecrown Citadel) ← **NEW FOR ICC**:
  - 13633, 13634, 13635, 13636, 13637, 13638, 13639, 13640, 13641, 13642, 13643, 13646, 13649, 13662, 13663, 13664, 13665, 13666, 13667, 13668, 13671, 13672

NPC 700061 (Ruby Sanctum):
  - 13803, 13804, 13805
```

## Architecture Overview

### Dungeon Quest System (Existing)
- NPCs: 700000-700054
- Quest Count: 435
- Instances: Classic, TBC, WotLK dungeons

### Raid Quest System (NEW)
- NPCs: 700055-700061
- Quest Count: 43 (out of 446 available)
- Instances: WotLK raids
- **Note:** This is Phase 1; can be expanded with more raid quests later

### Shared Infrastructure
- Both systems use same `npc_dungeon_quest_master.cpp` script
- Both use `dc_dungeon_npc_mapping` table
- Composite primary key `(map_id, quest_master_entry)` supports both

## Files Modified

1. **RAID_QUESTS_v5.0.sql** ← **New file to import**
   - Contains all SQL changes
   - Ready for import into world database

2. **npc_dungeon_quest_master.cpp** ← Already modified
   - OnGossipHello returns `false`
   - OnGossipSelect returns `false`
   - Recompile required

## Notes for Future Enhancement

- Currently 43 raid quests implemented (Naxx, Eye, Sanctum, Ulduar, ToC, ICC, Ruby)
- 446 total raid quests available on Wowhead
- Can expand by creating more NPC entries (700062+) for additional raids
- Older raids (MC, BWL, AQ40, Zul'Farrak, etc.) can be added if needed
