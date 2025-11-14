# Mythic+ System Evaluation for DarkChaos-255

**Date:** November 4, 2025  
**Project:** Custom Mythic+ System Implementation Feasibility Study  
**Scope:** Raid Mythic Difficulty + Mythic+ Dungeons

---

## 📋 Executive Summary

**Concept:** Implement a Retail-like Mythic+ system with:
- Mythic difficulty for raids (scaled damage/HP)
- Mythic+ dungeons with progressive difficulty levels
- Timer-based mechanics
- Rating/Season system
- Affixes system
- Custom achievements

**Overall Assessment:** ✅ **HIGHLY FEASIBLE**

**Complexity Level:** ⭐⭐⭐⭐ (4/5 - Medium-High)

**Implementation Effort:** 300-500 hours estimated

**Recommended Approach:** **Phased Implementation** (MVP → Full Feature Set)

---

## 🎯 Core Concept Breakdown

### 1. **Mythic Raid Difficulty**

**What it involves:**
- Add 4th difficulty level to raid encounters (Normal, Heroic, Mythic, Mythic+)
- Scale boss HP + damage by percentage (e.g., +15-25% HP, +10-15% damage)
- Potentially modify mechanics (add phases, new abilities)
- Different loot tables per difficulty

**Feasibility: ⭐⭐⭐⭐⭐ (5/5 - Very Easy)**

**Why Easy:**
- AzerothCore already supports multiple difficulty modes
- Map ID system in place
- Creature scaling exists (creature_template.hp_multiplier)
- Loot system extensible

**Implementation Steps:**
```sql
-- Add creature_template scaling
UPDATE creature_template SET HealthModifier = 1.2 WHERE difficulty = 'Mythic';

-- Create separate loot tables
INSERT INTO creature_loot_template (Entry, Item, ChanceOrQuestChance, LootMode)
SELECT Entry, Item, ChanceOrQuestChance, 1 FROM creature_loot_template
WHERE LootMode = 2 -- Heroic
UNION
SELECT Entry, MythicItem, MythicChance, 4 FROM ... -- Mythic specific
```

**Effort:** 40-60 hours

---

### 2. **Mythic+ Dungeon System**

**What it involves:**
- Progressive difficulty levels (M0, M+1, M+2... M+15+)
- Keystones (items that set dungeon level)
- Timer-based mechanics
- Scaling creatures/bosses
- Affixes (rotating modifiers)
- Loot scaling with difficulty

**Feasibility: ⭐⭐⭐⭐ (4/5 - Moderate)**

**Why Moderate:**
- Requires custom systems (not in standard AzerothCore)
- Timer mechanics need scripting
- Affix system needs custom implementation
- Rating system requires database schema

**Core Components Needed:**

#### A. Keystone System
```cpp
// Required: Custom item type for keystones
class KeystoneItem {
  uint32 dungeonID;
  uint32 mythicLevel;  // 1-15+
  bool used;
  // Returns loot tier based on level
  uint32 GetLootTier();
};
```

**Implementation Effort:** 30-40 hours

#### B. Timer Mechanics
```cpp
// Required: Dungeon-wide timer tracking
class MythicDungeonTimer {
  uint32 instance_id;
  uint32 start_time;
  uint32 dungeon_level;
  
  // Callbacks:
  // - Warn at 10%, 25%, 50% time
  // - Fail if time expires
  // - Bonus loot for 2x timer completion
};
```

**Implementation Effort:** 50-80 hours

#### C. Affix System
```cpp
// Retail-like affixes
enum MythicAffix {
  AFFIX_NONE = 0,
  AFFIX_TYRANNICAL = 1,     // Bosses harder
  AFFIX_FORTIFIED = 2,       // Trash harder
  AFFIX_EXPLOSIVE = 3,       // Orbs spawn
  AFFIX_RAGING = 4,         // Mob rage meter
  AFFIX_BOLSTERING = 5,     // Trash heals nearby
  AFFIX_SANGUINE = 6,       // Blood pools
  AFFIX_VOLCANIC = 7,       // AoE circles
  AFFIX_QUAKING = 8,        // Ground shake AoE
  AFFIX_TEEMING = 9,        // More trash
  AFFIX_BURSTING = 10,      // Stacking debuff on kills
};
```

**Implementation Effort:** 100-150 hours (varies by affix complexity)

#### D. Rating/Season System
```sql
CREATE TABLE mythic_plus_runs (
  run_id INT PRIMARY KEY,
  character_guid INT,
  dungeon_id INT,
  mythic_level INT,
  affixes TEXT,
  timer_completed BOOLEAN,
  time_taken INT,
  loot_awarded TEXT,
  season INT,
  rating FLOAT,
  date_completed TIMESTAMP
);

CREATE TABLE mythic_plus_rating (
  character_guid INT PRIMARY KEY,
  rating FLOAT,
  season INT,
  best_run_id INT,
  season_best_level INT
);
```

**Implementation Effort:** 40-60 hours

---

## 🛠️ Implementation Roadmap

### **Phase 1: MVP (Weeks 1-2) - 80-100 hours**
✅ **Core Features:**
- [x] Mythic difficulty for raids (scaling only, no mechanics changes)
- [x] Basic keystone system (item + dungeon entry)
- [x] Simple timer (pass/fail, no bonus)
- [x] Basic loot scaling
- [ ] No affixes yet
- [ ] No rating system yet

**Deliverables:**
- Mythic raid difficulty functional
- M0-M3 dungeons playable with timers
- Basic loot adjustments

---

### **Phase 2: Intermediate (Weeks 3-4) - 120-150 hours**
✅ **Expanded Features:**
- [x] Affix system (start with 3-4 simple ones)
- [x] Rating system foundation
- [x] Timer bonuses (faster completion = better loot)
- [x] Season system basic framework
- [x] LFG/LFR integration for M0

**Deliverables:**
- M+1 to M+7 fully playable
- Affixes working
- Rating tracking
- Season 1 started

---

### **Phase 3: Advanced (Weeks 5-6) - 100-150 hours**
✅ **Polish & Expansion:**
- [x] All 10+ affixes implemented
- [x] Mythic+ 8-15+ tiers
- [x] Leaderboard system
- [x] Achievements system
- [x] Weekly reset mechanics
- [x] Keystone upgrade/downgrade

**Deliverables:**
- Full M+15 and beyond
- Complete leaderboards
- Seasonal progression
- 20+ achievements

---

### **Phase 4: Refinement (Ongoing) - 50-100 hours**
✅ **Quality & Balance:**
- [x] Difficulty tuning/balancing
- [x] Bugfixes from player testing
- [x] Performance optimization
- [x] UI improvements
- [x] Custom boss mechanics for M+ scaling

---

## 💾 Database Schema Requirements

### New Tables Needed

```sql
-- Keystones
CREATE TABLE mythic_keystone (
  item_entry INT PRIMARY KEY,
  dungeon_id INT,
  mythic_level INT,
  used BOOLEAN DEFAULT FALSE
);

-- Dungeon instances with M+ data
CREATE TABLE mythic_dungeon_instance (
  instance_id INT PRIMARY KEY,
  dungeon_id INT,
  mythic_level INT,
  affixes VARCHAR(255),
  start_time INT,
  end_time INT,
  team_size INT,
  completed BOOLEAN,
  timer_met BOOLEAN
);

-- Ratings
CREATE TABLE mythic_plus_player_rating (
  guid INT,
  season INT,
  rating FLOAT,
  best_run INT,
  best_level INT,
  PRIMARY KEY (guid, season)
);

-- Leaderboard
CREATE TABLE mythic_plus_leaderboard (
  rank INT,
  character_guid INT,
  character_name VARCHAR(12),
  rating FLOAT,
  season INT,
  realm_id INT,
  faction INT
);

-- Achievements
CREATE TABLE mythic_plus_achievements (
  achievement_id INT PRIMARY KEY,
  requirement_type VARCHAR(50),  -- 'completion_level', 'timer', 'affix'
  requirement_value INT,
  mythic_level_min INT,
  description VARCHAR(255)
);
```

---

## 🎮 Gameplay Mechanics Details

### **Mythic Raid Mechanics**

```cpp
// Boss Difficulty Scaling
struct BossDifficultyScaling {
  float normal_hp = 1.0f;
  float heroic_hp = 1.15f;
  float mythic_hp = 1.30f;
  float mythic_plus_hp = 1.40f;  // Additional M+ scaling
  
  float normal_damage = 1.0f;
  float heroic_damage = 1.10f;
  float mythic_damage = 1.25f;
  float mythic_plus_damage = 1.35f;
};
```

**Suggested Scaling Per Tier:**
- Mythic (base): 125% HP, 120% Damage
- Mythic+ Per Level: +2% HP, +1.5% Damage (stacking)
  - M+1: 127% HP, 121.5% Damage
  - M+5: 137% HP, 128% Damage
  - M+10: 147% HP, 136% Damage
  - M+15: 157% HP, 144% Damage

---

### **Mythic+ Dungeon Mechanics**

#### **Keystone System**
- Players loot keystones from last boss (or dungeon end chest)
- Keystone = Dungeon + Level
- After run completion:
  - ✅ Timer met & all bosses dead: Keystone +1
  - ❌ Timer failed: Keystone depletes
  - ⚠️ Timer met but partial bosses: Keystone stays same

#### **Timer Mechanics**
```
M+1: 25 minutes
M+2: 23 minutes  
M+3: 21 minutes
M+4: 18 minutes  (Mythic Dungeon weekly reset time)
M+5: 16 minutes
M+10: 10 minutes
M+15: 8 minutes
M+20+: 6 minutes

Bonus Loot:
- 2x+ timer: +1 item level (vs completing in time)
- 3x+ timer: Special cosmetic reward
```

#### **Affixes Rotation (Suggested)**
```
Week 1: Tyrannical, Explosive
Week 2: Fortified, Raging
Week 3: Tyrannical, Quaking
Week 4: Fortified, Bolstering
Week 5: Tyrannical, Sanguine

SEASONAL AFFIX (Always on M+10+):
- Shrouded (rotation with seasonal theme)
```

---

## 🏆 Achievements System

### **Suggested Achievement Categories**

**Bronze Tier (Easy)**
- "I Can Heal!" - Complete M0
- "Pitter Patter" - Complete M+1
- "Speed Demon" - Complete M+2 with 2x timer
- "First Blood" - Reach rating 500

**Silver Tier (Medium)**
- "It's Dangerous to Go Alone" - Reach M+5
- "Affix Master" - Complete M+5 with 3 different affix combinations
- "Unstoppable Force" - Complete M+10 with Fortified & Bolstering
- "Elite" - Reach rating 1500
- "Speedrunner" - Complete M+7 in under 10 minutes

**Gold Tier (Hard)**
- "Mythic Legend" - Reach M+15
- "Untouchable" - Complete M+15 with 3x timer
- "The Infinite" - Reach M+20+
- "Gladiator" - Reach rating 2500
- "Seasonal Champion" - Top 10 seasonal leaderboard

---

## 🔧 Technical Implementation Considerations

### **AzerothCore Compatibility**

**What Exists (✅):**
- Difficulty scaling systems
- Loot tables & item distribution
- Instance management
- Group finder (LFG/LFR)
- Achievement framework

**What Needs Building (⚠️):**
- Keystone management
- Timer system (per-instance)
- Affix mechanics (dynamic difficulty modifiers)
- Rating calculation engine
- Season/leaderboard framework
- Custom scaling formulas

### **Performance Impact**

**Estimated Server Load Increase:**
- Database: +3-5% (new queries for ratings/stats)
- CPU: +2-3% (per-player timer calculations)
- Memory: +1-2% (cache for affix/rating data)
- Network: Negligible (<1%)

**Optimization Required:**
- Cache affix data (update weekly)
- Batch rating calculations (nightly)
- Index mythic_plus tables heavily
- Profile timer checks (per-tick overhead)

---

## 🎬 Reference Implementation Analysis

### **YouTube Reference 1 (NPC Shield Wall)**
https://www.youtube.com/watch?v=fni86TZCXr4

**Implementation:**
```cpp
// NPC with dialogue/gossip for difficulty selection
class MythicPlusDungeonMaster : public CreatureScript {
  void OnGossipHello(Player* player, Creature* creature) {
    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Challenge M+1", SENDER_MAIN, 1);
    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Challenge M+5", SENDER_MAIN, 5);
    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Challenge M+10", SENDER_MAIN, 10);
    // ... etc for each level
    SendGossipMenuFor(player, 1000000, creature->GetGUID());
  }
};

// Teleport + spawn shield wall effect
GameObject shield = new GameObject();
shield->Create(SHIELD_GAMEOBJECT_ENTRY);
shield->SetPosition(x, y, z, o);
shield->AddToWorld();
// Shield blocks exit until run completes
```

**Effort:** 20-30 hours

### **Ascension References (Scaling/M+)**
https://ascension.gg/de/features/new-pve-content/scaling-leveling-dungeons

**Key Features to Adopt:**
- Creature health scales with player gear
- Damage scales dynamically
- Loot auto-scales to item level
- Pre-made scaling items (great reference!)

**Effort:** Already exemplified, 60-80 hours to implement similar

### **Araxia GitHub (Mythic+ Module)**
https://github.com/araxiaonline/mod-mythic-plus

**Provides:**
- Pre-built M+ module code
- Scaling item examples
- Custom drop implementations
- Session hints

**Effort Savings:** 40-50% time reduction if used as foundation

---

## 📊 Loot System Configuration

### **Loot Scaling Formula**

```
Base Item Level = Raid Mythic Item Level (say 500)

Mythic (Raid): 500 iLvl
M0 Dungeon: 480 iLvl
M+1-2: 490 iLvl
M+3-4: 496 iLvl
M+5-6: 503 iLvl
M+7-9: 510 iLvl
M+10-14: 516 iLvl
M+15+: 523 iLvl

Timer Bonus:
- 2x timer met: +3 iLvl
- 3x timer met: +6 iLvl
```

### **Token System**

```sql
-- Option 1: Traditional Tokens (Like WoW retail)
INSERT INTO item_template VALUES (
  182651,           -- Entry
  'Encrypted Vault Token',
  'Mythic+ Vault Token',
  9,               -- Quality (Epic)
  0,               -- Flags
  -1,              -- BuyPrice
  999999,          -- SellPrice
  0,               -- Inventory type (quest item)
  'mythic_token',  -- RequiredClass
  0,               -- RequiredRace
  0                -- Level
);

-- Option 2: Chest at end (Like M+ currently)
-- Drops 2-3 items based on difficulty level
```

---

## ⚖️ Balance Considerations

### **Difficulty Tuning**

**Challenge Should Feel:**
- M+1-2: "Slightly harder heroic"
- M+4: "Entry mythic raiding"
- M+7: "Challenging, requires coordination"
- M+10: "Very difficult, skill-based"
- M+15: "Extremely hard, endgame"
- M+20+: "Almost impossible" (for ultra-hardcore)

**Tuning Method:**
1. Start with 110% base (mythic difficulty)
2. Add +2% per mythic level
3. Gather player data (kill times, deaths)
4. Adjust formula based on statistics
5. Iterate monthly

### **Affix Difficulty Impact**

```
Solo Affix Impact (vs no affixes):
- Tyrannical: +10% encounter difficulty
- Fortified: +8% trash difficulty
- Explosive: +12% awareness required
- Raging: +15% (high skill ceiling)
- Bolstering: +5% (minimal impact if well-geared)

Doubled Affix Impact (not simple multiplication):
- Two affixes: +20-25% difficulty (not +22%)
- Three+ affixes: Scaling diminishes
```

---

## 🚀 Recommended Launch Plan

### **Week 1: Soft Launch**
- [ ] Enable for testing guild only
- [ ] M0-M5 only (conservative difficulty)
- [ ] Gather feedback
- [ ] Monitor logs for issues
- [ ] Adjust timer values

### **Week 2: Limited Launch**
- [ ] Enable for all players (M0-M7)
- [ ] Announce on forums
- [ ] Prize for first M+7 completion
- [ ] Monitor leaderboard
- [ ] Fix any critical bugs

### **Week 3: Season 1 Launch**
- [ ] Full M0-M15+ available
- [ ] Leaderboards live
- [ ] Seasonal rewards announced
- [ ] Weekly affix rotations begin
- [ ] Regular balance passes

---

## ✅ Pros vs ❌ Cons

### **Advantages**

✅ **Engages endgame players** - Fresh endgame content beyond raids

✅ **Replayability** - 200+ unique affix combinations

✅ **Skill-based progression** - Rating system rewards improvement

✅ **Community building** - Leaderboards create friendly competition

✅ **Scalable difficulty** - Adapt to player skill level

✅ **Seasonal framework** - Long-term engagement structure

### **Challenges**

❌ **High development cost** - 300-500 hours initial

❌ **Complexity to balance** - Many variables affecting difficulty

❌ **Requires active maintenance** - Weekly affix tuning, balance patches

❌ **Can create toxicity** - Timer pressure + rating system can create stress

❌ **Dungeon dependency** - All WotLK dungeons need tuning/scaling

❌ **Database overhead** - Significant new data tracking

---

## 💰 Resource Requirements

### **Development Team**

**Minimum Team:**
- 1x Senior C++ Developer (lead) - 300 hours
- 1x Database Designer - 80 hours
- 1x Content Designer/Balancer - 120 hours
- 1x QA Tester - 100 hours
- **Total: 600 person-hours**

**Recommended Team:**
- Add 1x Junior Developer - 150 hours (UI, minor features)
- Add 1x Difficulty/PvE Specialist - 100 hours (balance)
- **Total: 850 person-hours**

### **Time Investment**

**Solo Development:**
- Full implementation: 500-700 hours
- Estimated: 4-6 months (part-time)
- Or: 2-3 months (full-time)

**With Team:**
- Full implementation: 300-400 hours (lead)
- Estimated: 6-8 weeks with 3 people

---

## 🎯 Success Metrics

### **How to Measure Success**

| Metric | Target | Timeframe |
|--------|--------|-----------|
| Players completing M0 | 40% of active players | Week 2 |
| Average M+ completion | M+4 | Month 1 |
| Leaderboard participation | Top 100 players | Month 1 |
| Weekly engagement rate | 60% of players | Month 2 |
| Dungeon queue times | <2 min average | Month 2 |
| Player satisfaction | 4.0+/5.0 rating | Month 2 |

---

## 📌 Recommendations

### **My Assessment:**

**This is an EXCELLENT idea for DarkChaos-255 because:**

1. ✅ **Fills endgame gap** - Provides content between regular dungeons and raids
2. ✅ **Leverages existing dungeons** - Uses already-created content
3. ✅ **Scales with player base** - Can be progressive (M0 → M+15)
4. ✅ **Proven system** - Retail WoW M+ is successful model
5. ✅ **Highly customizable** - Easy to balance for your player base

### **Suggested Implementation Path:**

**Phase 1 (Month 1):** MVP with M0-M7 + simple timer + 3 affixes
- Lower scope, faster delivery
- Test core mechanics
- Gather player feedback

**Phase 2 (Month 2):** Expand to M+15+ + full affix set + rating system
- Expand based on Phase 1 learnings
- Refine difficulty balance
- Launch Season 1

**Phase 3 (Month 3+):** Polish, balance, seasonal rotations
- Ongoing maintenance
- Seasonal rewards/themes
- Leaderboard competitions

### **Key Success Factors:**

1. **Start small** - Don't launch all 15 levels at once
2. **Gather feedback** - Listen to player difficulty complaints
3. **Balance actively** - Monthly tuning cycles
4. **Create urgency** - Weekly affix changes, seasonal resets
5. **Reward participation** - Cosmetics, titles, achievements

---

## 📚 References & Resources

**GitHub Reference:** https://github.com/araxiaonline/mod-mythic-plus
- Excellent starting point, consider forking

**Video References:**
- Retail M+ mechanics: https://www.youtube.com/watch?v=QfmoV8XCf80
- Affix examples: https://www.youtube.com/watch?v=rHNpzXPH4AU
- Custom implementation: https://www.youtube.com/watch?v=fni86TZCXr4

**Community:**
- AzerothCore Forum: https://www.azerothcore.org/
- Custom Content Developers: Seek M+ specialists

---

## 🎓 Conclusion

**Overall Recommendation: ⭐⭐⭐⭐⭐ (5/5 Stars)**

This is a **highly valuable feature** that would:
- ✅ Significantly enhance your server's endgame
- ✅ Create long-term player engagement
- ✅ Differentiate your server from others
- ✅ Build a competitive community

**Feasibility: HIGHLY FEASIBLE** with proper planning

**Next Steps:**
1. Review this evaluation with your team
2. Prioritize which features to launch first (MVP)
3. Allocate development resources
4. Start with Phase 1 implementation
5. Plan for ongoing balance adjustments

**Timeline Estimate:**
- MVP (M0-M7): 8-12 weeks
- Full system (M0-M+20+): 16-20 weeks
- Fully polished & balanced: 24+ weeks

Would you like me to dive deeper into any specific aspect (technical implementation, balancing formulas, database schema, etc.)?

---

**Status: ✅ READY FOR DEVELOPMENT PLANNING**
