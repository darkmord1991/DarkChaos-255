# DarkChaos-255 Prestige + Dungeon Quest System - Master Implementation Guide

## 📋 Document Overview

This is the master implementation guide combining:
1. **Prestige System** (Level 255 Reset with Stat Bonuses)
2. **Dungeon Quest System** (Phased quest NPCs in dungeons)
3. **Database Architecture** (World DB + Character DB)
4. **DBC Additions** (Achievements, Titles, Items)

**Status**: Ready for Phase 1 Implementation  
**Last Updated**: November 3, 2025  
**Estimated Timeline**: 4-6 weeks total

---

## 📚 Related Files

Before starting implementation, review these key documents:

### DBC Preparation
- ✅ `DBC_PRESTIGE_ADDITIONS.md` - CSV modifications for Item, Achievement, CharTitles
- ✅ `PRESTIGE_SYSTEM_COMPLETE.sql` - All prestige database tables

### Dungeon Quest System
- ✅ `PHASED_NPC_IMPLEMENTATION_ANALYSIS.md` - Phased NPC complexity assessment
- ✅ `DungeonQuestSystem/NPC_SPAWNING_DAILY_WEEKLY_QUESTS.md` - Quest architecture
- ✅ `DungeonQuestSystem/IMPLEMENTATION_CHECKLIST_v2.0.md` - Step-by-step guide

### Reference Architecture
- ✅ `DungeonQuestSystem/DUNGEON_QUEST_NPC_SCHEMA_AND_ACHIEVEMENTS.sql` - Full schema
- ✅ `DungeonQuestSystem/DUNGEON_QUEST_NPC_FEATURE_EVALUATION.md` - Complete analysis

---

## 🎯 Implementation Phases

### Phase 1: Database Setup (Week 1)
- [ ] Create prestige tables (character DB)
- [ ] Create dungeon quest phase tables (world DB)
- [ ] Update DBC CSV files (Item, Achievement, CharTitles)
- [ ] Verify schema integrity

### Phase 2: Core Systems (Weeks 2-3)
- [ ] Implement prestige system core
- [ ] Implement phase system core
- [ ] Add stat bonus calculations
- [ ] Create NPC quest giver script

### Phase 3: Instance Integration (Weeks 3-4)
- [ ] Modify 10+ dungeon instance scripts
- [ ] Add phasing hooks
- [ ] Implement visibility logic
- [ ] Test phase transitions

### Phase 4: Testing & Polish (Weeks 4-5)
- [ ] Test prestige achievement earning
- [ ] Test stat bonuses apply correctly
- [ ] Test quest NPC visibility in dungeons
- [ ] Test rewards distribution
- [ ] Performance testing

### Phase 5: Deployment & Monitoring (Week 6)
- [ ] Deploy to staging
- [ ] Deploy to production
- [ ] Monitor for issues
- [ ] Collect player feedback

---

## 📊 System Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│          DARKCHAOS-255 PROGRESSION SYSTEM                   │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         LEVEL PROGRESSION (1 → 255)                 │  │
│  │  Normal Leveling: 1-80 (Vanilla + Wrath content)    │  │
│  │  Extended Leveling: 81-255 (Custom progression)     │  │
│  └──────────────────────────────────────────────────────┘  │
│                           ↓                                 │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         PRESTIGE SYSTEM (Level 255 Reset)           │  │
│  │  • 10 prestige levels (1-10)                         │  │
│  │  • +1% to +10% permanent stat bonuses               │  │
│  │  • Exclusive titles and rewards                      │  │
│  │  • Achievements for each prestige                    │  │
│  │  • Prestige tabards and cosmetics                    │  │
│  └──────────────────────────────────────────────────────┘  │
│                           ↓                                 │
│  ┌──────────────────────────────────────────────────────┐  │
│  │    DUNGEON QUEST SYSTEM (Instance Phasing)          │  │
│  │  • 53 quest NPCs (700000-700052)                    │  │
│  │  • 10+ dungeons with daily/weekly quests             │  │
│  │  • Phased NPC visibility (dungeon-specific)          │  │
│  │  • Token-based reward system                         │  │
│  │  • Tier-based NPC distribution                       │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

---

## 🗄️ Database Architecture

### Character Database (acore_characters)

```
CHARACTER PRESTIGE TABLES:
├── character_prestige (Main prestige data)
│   ├── guid (FK → characters.guid)
│   ├── prestige_level (0-10)
│   ├── prestige_exp (XP towards next level)
│   ├── total_prestiges (lifetime count)
│   ├── stat_multiplier (1.00 - 1.10)
│   └── prestige_rewards_claimed (bitmask)
│
├── character_prestige_stats (Historical tracking)
│   ├── guid (PK)
│   ├── prestige_number (1st, 2nd, etc.)
│   ├── time_to_prestige_hours
│   ├── bosses_defeated
│   ├── dungeons_completed
│   └── prestige_date
│
├── character_prestige_currency
│   ├── guid (PK)
│   ├── currency_type (honor, prestige_coins)
│   ├── amount (current balance)
│   └── earned_total / spent_total
│
└── prestige_audit_log (Logging)
    ├── guid
    ├── action (prestige_achieved, reward_claimed)
    ├── prestige_level
    └── action_timestamp
```

**Tables Created**: 4  
**Total Rows**: ~100,000 (assuming 10,000 characters with prestige data)  
**Storage**: ~20 MB (with indexes)

### World Database (acore_world)

```
PRESTIGE CONFIGURATION:
├── prestige_levels (Config - 10 rows)
│   ├── prestige_level (PK)
│   ├── required_xp (XP to next prestige)
│   ├── stat_bonus_percent (1.01 - 1.10)
│   ├── title_id (FK → CharTitles.dbc)
│   ├── achievement_id (FK → Achievement.dbc)
│   ├── reward_item_id
│   ├── gold_reward
│   ├── tabard_id
│   └── description
│
├── prestige_rewards (Detailed rewards)
│   ├── id (PK)
│   ├── prestige_level (FK)
│   ├── reward_type (enum)
│   └── reward_id
│
├── prestige_vendor_items (Shop items)
│   ├── id (PK)
│   ├── prestige_minimum (level required)
│   ├── item_id
│   └── prestige_points_cost
│
└── prestige_seasons (Optional seasonal events)
    ├── season_id (PK)
    ├── season_name
    ├── start_date / end_date
    └── max_prestige_achievable

DUNGEON QUEST PHASING:
├── creature_phase (NEW - Visibility mapping)
│   ├── CreatureGuid (PK, FK → creature.guid)
│   └── Phase (PK)
│
└── dungeon_quest_phase_mapping (NEW - Config)
    ├── dungeon_id (PK)
    ├── dungeon_name
    ├── map_id
    ├── phase_id
    ├── min_level / max_level
    └── npc_entry
```

**Tables Created**: 7 total (4 character + 3 world)  
**Total Rows**: ~500 (mostly configuration)  
**Storage**: ~2 MB

---

## 🎮 Game Mechanics

### Prestige Mechanics

**When Player Reaches Level 255:**

```
Level 255 Reached (in dungeon/raid)
        ↓
Player Sees "PRESTIGE AVAILABLE" Message
        ↓
Player Talks to Prestige NPC / Uses Command
        ↓
Decision Point:
├─ CONFIRM: Reset to Level 1
│   ├─ Award Achievement (13500-13509)
│   ├─ Award Title (200-209)
│   ├─ Award Cache Item (90001-90010)
│   ├─ Award Gold Bonus (10,000-100,000 based on prestige level)
│   ├─ Increase Stat Multiplier (+1%)
│   ├─ Reset: Level 1, Experience 0
│   ├─ Keep: All gear, mounts, achievements, talents
│   └─ Prestige Counter Increments
│
└─ CANCEL: Stay Level 255
    ├─ Player continues normal gameplay
    └─ Can prestige later
```

**Stat Bonus Application:**

```cpp
// When calculating unit stats:
total_stat = base_stat * stat_multiplier

// Where stat_multiplier = 1.0 + (prestige_level * 0.01)
// Prestige 1 = 1.01 (1% bonus)
// Prestige 5 = 1.05 (5% bonus)
// Prestige 10 = 1.10 (10% bonus)
```

### Dungeon Quest Mechanics

**When Player Enters Dungeon:**

```
Player Zone: World Zone (e.g., Stormwind)
Phase: 1 (world phase - NPC invisible)
        ↓
Player Enters Instance Dungeon (e.g., Blackrock Depths)
        ↓
Server Detects: Map 228 (BRD)
        ↓
Server Sets Player Phase: 100 (BRD phase)
        ↓
Quest NPC 700001 Becomes VISIBLE
Phase Condition: Creature phase = 100 (BRD phase)
Player phase = 100 (inside BRD)
Result: Player sees NPC ✓
        ↓
Player Talks to NPC: "Show me quests"
        ↓
NPC Shows: Daily & Weekly Quests
├─ "Defeat Bosses in BRD" (Daily, 5x repeatable)
├─ "Collect Dark Irons" (Weekly)
└─ "Defend the Instance" (Daily)
        ↓
Player Accepts Quest
        ↓
Quest Added to Quest Log
Quest Tracker Shows: "Kill 10 Dark Irons in BRD"
        ↓
[Inside Dungeon] - Player kills mobs
        ↓
Quest Progress: 1/10 → 2/10 → ... → 10/10 Complete
        ↓
Player Returns to NPC
Player Completes Quest
        ↓
Reward: Experience + Token Reward
├─ Regular Token: 10 tokens
├─ Prestige I Token: 15 tokens
└─ Prestige V Token: 25 tokens
        ↓
[Player Leaves Dungeon]
        ↓
Server Sets Player Phase: 1 (world phase)
        ↓
Quest NPC Becomes INVISIBLE
```

---

## 🛠️ Implementation Roadmap

### Week 1: Database Setup

**Monday-Tuesday: Prestige Schema**
```sql
-- Run in character database
SOURCE PRESTIGE_SYSTEM_COMPLETE.sql;

-- Verify tables created
SHOW TABLES LIKE '%prestige%';

-- Verify columns
DESCRIBE character_prestige;
DESCRIBE prestige_levels;
```

**Wednesday: DBC CSV Updates**
- Add 10 achievements to Achievement.csv (IDs 13500-13509)
- Add 10 titles to CharTitles.csv (IDs 200-209)
- Add 10 items to Item.csv (IDs 90001-90010)
- See `DBC_PRESTIGE_ADDITIONS.md` for exact CSV lines

**Thursday: Dungeon Quest Phasing Schema**
```sql
-- Run in world database
CREATE TABLE creature_phase (...);  -- From PHASED_NPC_IMPLEMENTATION_ANALYSIS.md
CREATE TABLE dungeon_quest_phase_mapping (...);
INSERT INTO dungeon_quest_phase_mapping VALUES (...);  -- 53 rows

-- Verify
SELECT COUNT(*) FROM dungeon_quest_phase_mapping;  -- Should be 53
```

**Friday: Schema Verification**
- Backup all databases
- Run integrity checks
- Verify foreign keys
- Document any issues

### Weeks 2-3: Core System Implementation

**Week 2: Prestige System**

```cpp
// Files to Create/Modify:
src/server/scripts/DC/
├── prestige_system_core.cpp (300 lines)
├── prestige_command_handler.cpp (200 lines)
├── prestige_stat_bonus.cpp (150 lines)
└── prestige_npc_vendor.cpp (150 lines)

// Files to Modify:
src/server/scripts/DC/dc_script_loader.cpp
└── AddSC_prestige_system_core();
└── AddSC_prestige_command_handler();
└── etc.

src/server/game/Entities/Unit/Unit.cpp
└── Modify CalculateStats() to apply stat_multiplier
```

**Week 3: Phasing System**

```cpp
// Files to Create:
src/server/scripts/DC/
├── phase_dungeon_quest_system.cpp (350 lines)
├── npc_dungeon_quest_master.cpp (200 lines)
└── instance_phasing_hooks.cpp (100 lines)

// Instance Scripts to Modify (10+ files):
src/server/scripts/EasternKingdoms/BlackrockDepths/
└── instance_blackrock_depths.cpp
└── Add OnPlayerEnter/OnPlayerLeave hooks

src/server/scripts/Eastern Kingdoms/Stratholme/
└── instance_stratholme.cpp
└── Similar modifications...
[... repeat for 10 dungeons ...]
```

### Weeks 4-5: Testing

**Test Cases: Prestige System**
```
TEST: Player reaches level 255
  Expected: "Prestige available" message shown

TEST: Player clicks prestige NPC
  Expected: Prestige menu opens

TEST: Player selects "Prestige"
  Expected: Level resets to 1, prestige_level = 1

TEST: Check player stats
  Expected: All stats × 1.01 multiplier

TEST: Check achievements
  Expected: Achievement 13500 "Prestige I" unlocked

TEST: Check title
  Expected: Title 200 "Prestige Master" available

TEST: Prestige 5 stats
  Expected: All stats × 1.05 multiplier
```

**Test Cases: Dungeon Quest System**
```
TEST: Player in world (not in dungeon)
  Expected: Quest NPC invisible

TEST: Player enters BRD instance
  Expected: Phase changes to 100
  Expected: Quest NPC 700001 becomes visible

TEST: Player talks to NPC in BRD
  Expected: Quest menu shows "Show me quests"
  Expected: Daily and weekly quests listed

TEST: Player accepts quest
  Expected: Quest added to quest log
  Expected: Quest tracker shows objective

TEST: Player completes quest in dungeon
  Expected: Quest marked complete
  Expected: Player can turn in to NPC

TEST: Player receives reward
  Expected: Experience awarded
  Expected: Tokens received (amount based on prestige)

TEST: Player leaves dungeon
  Expected: Phase resets to 1
  Expected: Quest NPC becomes invisible
```

### Week 6: Deployment

**Staging Deployment**
- Compile code on staging server
- Apply database migrations
- Test all features with test characters
- Monitor logs for errors

**Production Deployment**
- Apply database migrations (backup first)
- Deploy compiled code
- Restart world servers
- Monitor for issues
- Collect player feedback

---

## 📋 Prestige System - Quick Reference

### Prestige Levels

| Level | Stat Bonus | Achievement ID | Title ID | Title Name |
|-------|-----------|-----------------|----------|------------|
| 1 | +1% | 13500 | 200 | Prestige Master |
| 2 | +2% | 13501 | 201 | Prestige Veteran |
| 3 | +3% | 13502 | 202 | Prestige Hero |
| 4 | +4% | 13503 | 203 | Prestige Legend |
| 5 | +5% | 13504 | 204 | Prestige Champion |
| 6 | +6% | 13505 | 205 | Prestige Immortal |
| 7 | +7% | 13506 | 206 | Prestige Eternal |
| 8 | +8% | 13507 | 207 | Prestige Infinite |
| 9 | +9% | 13508 | 208 | Prestige Ascendant |
| 10 | +10% | 13509 | 209 | Eternal Champion |

### Item Rewards

| ID | Name | Type | Prestige |
|----|----|------|----------|
| 90001 | Prestige Cache I | Quest Item | 1 |
| 90002 | Prestige Cache II | Quest Item | 2 |
| ... | ... | ... | ... |
| 90010 | Prestige Cache X | Quest Item | 10 |

### Commands

```
.prestige reset        - Reset to level 1 with prestige
.prestige status       - Show current prestige level
.prestige vendor       - Open prestige shop
.prestige rewards      - Show all rewards available
```

---

## 📋 Dungeon Quest System - Quick Reference

### NPC IDs

```
NPC ID Range: 700000-700052 (53 NPCs)

Tier-1 (Vanilla Dungeons): 700001-700011 (11 NPCs)
  - Blackrock Depths
  - Stratholme
  - Scholomance
  - etc.

Tier-2 (TBC Dungeons): 700012-700027 (16 NPCs)
  - Black Temple
  - Karazhan
  - Tempest Keep
  - etc.

Tier-3 (WotLK Dungeons): 700028-700052 (26 NPCs)
  - Naxxramas
  - Ulduar
  - Trial of the Crusader
  - etc.
```

### Phase IDs

```
Phase ID Range: 100-152 (53 phases, one per dungeon)

100 = Blackrock Depths (Map 228)
101 = Stratholme (Map 329)
102 = Molten Core (Map 409)
103 = Black Temple (Map 564)
... etc.

All creatures in dungeon have phase_id set to their dungeon's phase
```

### Quest Structure

```
Daily Quests: 5 per dungeon (repeatable every 24h)
  - "Defeat Bosses" (5 kills)
  - "Collect Items" (10 items)
  - etc.

Weekly Quests: 2 per dungeon (repeatable every 7d)
  - "Clear the Dungeon" (boss kill achievement)
  - "Legendary Challenge" (difficult objectives)

Rewards:
  - Experience (scaling with player level)
  - Tokens: 10 base, 15 (Prestige 1), 25 (Prestige 5)
  - Gold: 100-500 based on difficulty
```

---

## ⚠️ Considerations & Gotchas

### Prestige System

**Consider**: Stat bonus balance
- +10% at Prestige 10 might be too strong
- Alternative: +1-5% scaling instead of 1-10%
- Test damage output vs boss health scaling

**Consider**: Gold rewards
- 100k gold at Prestige 10 might inflate economy
- Alternative: Token currency instead of gold
- Track currency spending

**Consider**: Prestige reset cooldown
- Should prestige be limited per week/month?
- Alternative: Immediate unlimited prestiges
- Prevents excessive farming

### Dungeon Quest System

**Consider**: Phase mask conflicts
- What if player is in group with non-dungeon player?
- Solution: Phase group leader's instance phase
- Alternative: Each player sees own phase

**Consider**: Phase transitions
- Teleporting between dungeons maintains phase?
- Walking between dungeons resets phase?
- Solution: Detect map change, update phase accordingly

**Consider**: Performance at scale
- 100+ players entering dungeons simultaneously
- Solution: Phase system is native, optimized
- Monitor CPU with load test

---

## 📞 Support & Debugging

### Common Issues

**Issue**: Prestige achievement doesn't unlock
```
Debug: SELECT * FROM character_achievement WHERE achievement = 13500;
Check: Is player level 255?
Check: Did prestige command execute?
```

**Issue**: Quest NPC invisible in dungeon
```
Debug: SELECT * FROM creature_phase WHERE CreatureGuid = 123456;
Check: Is phase_id = 100 (for BRD)?
Check: Is player in dungeon?
Check: SELECT * FROM creature WHERE guid = 123456 AND map = 228;
```

**Issue**: Stat bonus not applying
```
Debug: SELECT stat_multiplier FROM character_prestige WHERE guid = X;
Check: Is multiplier = 1.01 for Prestige 1?
Check: Does CalculateStats() multiply by multiplier?
Verify: Unit::CalculateStats() in Unit.cpp
```

### Logging

Add to prestige_system_core.cpp:
```cpp
LOG_INFO("scripts.dc.prestige", "Player {} achieved Prestige {}", 
  player->GetName(), prestige_level);

LOG_INFO("scripts.dc.phasing", "Player {} entering phase {}", 
  player->GetName(), phase_id);
```

View logs:
```
tail -f server.log | grep prestige
tail -f server.log | grep phasing
```

---

## 📊 Performance Expectations

### Prestige System Impact
- Query time: <1ms per prestige check
- Memory: ~100KB for 10,000 characters
- CPU: Negligible (runs only on level-up)

### Dungeon Quest Phase System Impact
- Query time: <1ms per player entering dungeon
- Memory: ~2KB for phase mappings (cached)
- CPU: Negligible (runs on map change)

### Combined Impact
- **Server Load**: <0.1% CPU increase
- **Memory**: <1 MB increase
- **Disk I/O**: Minimal (infrequent writes)

---

## ✅ Pre-Deployment Checklist

- [ ] All database tables created
- [ ] All DBC CSV entries added
- [ ] All C++ code compiled without errors
- [ ] All instance scripts modified
- [ ] Prestige system tested with 10 test characters
- [ ] Dungeon quest phasing tested in 5 dungeons
- [ ] Stat bonuses verified at each prestige level
- [ ] Quest rewards calculated correctly
- [ ] No SQL errors in migration scripts
- [ ] Performance tested with 100+ concurrent players
- [ ] Backup of production database created
- [ ] Rollback procedure documented
- [ ] Player announcement prepared
- [ ] Admin command documentation complete

---

## 📞 Contact & Support

For questions during implementation:
1. Check `PHASED_NPC_IMPLEMENTATION_ANALYSIS.md`
2. Review `DBC_PRESTIGE_ADDITIONS.md`
3. Consult `DungeonQuestSystem/` documentation
4. Check AzerothCore wiki for phasing
5. Review server logs for errors

---

## Conclusion

This master guide provides complete instructions for implementing:
- ✅ Prestige system with 10 levels
- ✅ Stat bonus progression (+1% to +10%)
- ✅ Phased dungeon quest NPCs
- ✅ Instance-specific questing
- ✅ Token-based rewards

**Total Effort**: 4-6 weeks  
**Total Code**: ~2,000 lines  
**Database Tables**: 7 new/modified  
**Testing Time**: 1-2 weeks  

Ready to begin Phase 1!
