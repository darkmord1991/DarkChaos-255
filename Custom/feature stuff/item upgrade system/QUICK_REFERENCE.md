# Quick Reference - 2 Token System (FINAL)

**Status:** Updated to 2-Token Simplified System  
**Date:** November 4, 2025  
**Change:** 5 tokens simplified to 2 tokens, no weekly caps

---

## 🎯 The Two Tokens

### **1️⃣ Upgrade Token** 
**Where?** All content (quests, dungeons, raids)  
**What for?** Upgrade T1-T4 items (50-750 per item based on tier)  
**Cost per upgrade level:**
- T1: 10 tokens/level = 50 total
- T2: 30 tokens/level = 150 total
- T3: 75 tokens/level = 375 total
- T4: 150 tokens/level = 750 total

### **2️⃣ Artifact Essence**
**Where?** Worldforged objects only  
**What for?** Upgrade T5 artifacts only  
**Cost:** 50 essence per level = 250 total

**Key:** NO WEEKLY CAPS - grind at own pace!

---

## ⏱️ Time to Full Gearing by Playstyle

| Playstyle | T1 | T2 | T3 | T4 | Artifacts |
|-----------|----|----|----|----|-----------|
| **Solo** | 1-2 days | - | - | - | - |
| **Casual** | 1 week | 4-6 weeks | Slow | Not realistic | 2-3 |
| **Hardcore** | 1-2 weeks | 3-4 weeks | 5-6 weeks | 8-10 weeks | 10-15 |

---

## 💰 Total Costs to Max Everything

```
T1: 150 items × 50 tokens = 7,500 tokens
    → Achievable in 1-2 weeks casual play

T2: 160 items × 150 tokens = 24,000 tokens
    → Achievable in 3-4 weeks heroic grinding

T3: 250 items × 375 tokens = 93,750 tokens
    → Achievable in 5-6 weeks raid farming

T4: 270 items × 750 tokens = 202,500 tokens
    → Achievable in 8-10 weeks hard-core

T5: 110 items × 250 essence = 27,500 essence
    → Achievable in 10-15 weeks exploration
```

---

## � Drop Rates by Content

```
Quests:              1-2 Upgrade Tokens (solo-friendly)
Heroic Dungeon:      3-5 Upgrade Tokens (avg 4)
Mythic Dungeon:      5-8 Upgrade Tokens (avg 6)
Heroic Raid:         8-12 per boss (120 per full clear)
Mythic Raid:         15-20 per boss (210 per full clear)
World Boss:          50-100 Upgrade Tokens (rare event)

Worldforged:         1-10 Artifact Essence per object
```

---

## ⚡ No Weekly Caps Philosophy

```
PROGRESSION GATES:
├─ Playtime: How many hours can you play?
├─ Difficulty: Can you do heroics/raids?
├─ Item cost: Higher tier costs more tokens
└─ NOT: Arbitrary weekly limits!

PLAYER FREEDOM:
✅ Farm 8 hours straight? You earn that much
✅ Farm 2 hours daily? Steady reliable progress
✅ Mix content? Any combo works
✅ No frustration: "I hit my cap and wasted time"
```

---

## 🎮 Player Journey Examples

### **Solo Player (Day 1-2)**
```
Activity: Do 15-20 quests (3-4 hours)
├─ Earn: 20-40 Upgrade Tokens
├─ Get: T1 items from quest rewards
├─ Upgrades: Max 1 full set to level 5
└─ Result: FULLY GEARED in 1-2 days!

Achievement Unlocked: "Fresh Adventurer - T1 Complete"
```

### **Casual Player (Week 1-4)**
```
Week 1-2: Mix quests + 2 heroic runs
├─ Earn: 70 tokens + 8 tokens = 78 total
├─ Get: T1 complete + 5-6 T2 items
├─ Upgrades: T2 items at level 1-2

Week 3-4: Regular heroic farming
├─ Earn: ~40 tokens/week
├─ Get: More T2 items
├─ Upgrades: T2 items reaching max

Result by Week 4: ~15 T2 items at max level
Achievement: "Heroic Collector - T2 Complete"
```

### **Hardcore Player (Week 1-4)**
```
Week 1: Heroics + raids start
├─ Earn: Mixed content = 200+ tokens
├─ Get: T1 complete + full T2 start

Week 2: Raid progression
├─ Earn: 150+ tokens/week
├─ Get: T2 complete + start T3

Week 3-4: Raid farm + M+ farming
├─ Earn: 250+ tokens/week
├─ Get: 20-30 T3 items + continue T4

Result by Week 4: All T1, full T2, partial T3+T4
Achievement: "Raider's Arsenal"
```

---

## � Database Structure (Ultra-Simple!)

```sql
CREATE TABLE player_upgrade_tokens (
    player_guid INT PRIMARY KEY,
    upgrade_tokens INT DEFAULT 0,
    artifact_essence INT DEFAULT 0,
    season INT,
    UNIQUE (player_guid, season)
);

-- Incredibly simple! No weekly caps, no complex tracking
-- Just: two numbers per player per season
```

---

## ✅ Why 2-Token System Works

✅ **Accessible:** T1 in 1-2 days for everyone  
✅ **Balanced:** Drop rates naturally gate progression  
✅ **Clear:** Simple to understand and explain  
✅ **Free:** No arbitrary weekly caps  
✅ **Scalable:** Higher tier = more cost (natural gate)  
✅ **Engaging:** Multiple playstyles viable  

---

## 📈 Expected Weekly Progress

| Playstyle | Hours/Week | Tokens/Week | Items/Week |
|-----------|----------|------------|-----------|
| Solo | 5-10 | 20-40 | 0.4-0.8 T1 |
| Casual | 10-15 | 60-100 | 1-2 T2 |
| Raider | 20-30 | 250-400 | 3-5 T2, 1-2 T3 |
| Hardcore | 40-50+ | 500-750+ | 10-15 T2, 3-5 T3, 1-2 T4 |

---

## 🚀 Implementation Priority

**Phase 1 (Week 1-2):** Database + drops  
**Phase 2 (Week 3-4):** Item generation  
**Phase 3 (Week 5-6):** Upgrade mechanics  
**Phase 4 (Week 7):** Vendors & UI  
**Phase 5 (Week 8-9):** Artifacts  
**Phase 6 (Week 10):** Testing  
**Phase 7 (Week 11):** Soft launch  
**Phase 8 (Week 12):** Full launch  

---

## 📚 Full Documentation

- **TIERED_HEIRLOOM_SYSTEM.md** - Complete design (5 tiers, 2 tokens)
- **SEASON_ITEM_ALLOCATION.md** - 940 items breakdown
- **TOKEN_SYSTEM_SIMPLIFIED.md** - Detailed token philosophy
- **DROP_RATE_REFERENCE.md** - Exact farming rates
- **IMPLEMENTATION_ROADMAP.md** - 8-phase development plan
- **REDESIGN_SUMMARY.md** - What changed from 5→2 tokens
- **THIS FILE** - Quick reference card

---

**System is now simplified, accessible, and balanced!**

### Query upgrade cost for item
```sql
CALL dc_get_upgrade_cost(50001, @token_cost, @fs_cost, @next_item, @next_ilvl);
SELECT @token_cost, @fs_cost, @next_item, @next_ilvl;
```

### Check player currency
```sql
SELECT upgrade_tokens, flightstones FROM dc_player_currencies 
WHERE character_guid = {guid};
```

### Find item chain
```sql
SELECT * FROM dc_item_upgrade_chains 
WHERE ilvl_0_entry = {item_entry};
```

## 🎮 Commands

### Player Commands
```
/upgrade                 Open upgrade UI
/upgrade ui             Open upgrade UI
/upgrade currency       Show currency balance
/upgrade help           Show help
```

### Admin Commands (optional)
```
/upgrade admin set-tokens {player} {amount}
/upgrade admin set-fs {player} {amount}
/upgrade admin reset-player {player}
/upgrade admin view-log {player} [limit]
```

## 🛠️ Item Entry ID Naming

```
Formula: (TRACK_ID * 1000) + (UPGRADE_LEVEL * 10) + OFFSET

Examples:
Track 2 (Heroic), Item 0, Level 0: 20000
Track 2 (Heroic), Item 0, Level 1: 20010
Track 2 (Heroic), Item 0, Level 2: 20020
Track 2 (Heroic), Item 1, Level 0: 20100
Track 2 (Heroic), Item 1, Level 1: 20110

Track 6 (Mythic), Item 0, Level 0: 60000
Track 6 (Mythic), Item 0, Level 5: 60050
```

## 📈 Progression Timeline

```
Week 1: HLBG + Heroic Dungeons (226-245 iLvl)
  └─ Earn: ~30-40 tokens/week
  └─ Can complete: 3-4 upgrades

Week 2-3: Mythic Dungeons (239-258 iLvl)
  └─ Earn: ~40-50 tokens/week
  └─ Can complete: 3-4 upgrades

Week 4-6: Raid Normal (245-264 iLvl)
  └─ Earn: ~50-60 tokens/week
  └─ Can complete: 3-4 upgrades

Week 7-10: Raid Heroic (258-277 iLvl)
  └─ Earn: ~60-70 tokens/week
  └─ Can complete: 3-4 upgrades

Week 11+: Raid Mythic (271-290 iLvl)
  └─ Earn: ~80-100 tokens/week
  └─ Can complete: 4-5 upgrades
  └─ Max level reached at week 15-20
```

## ⚙️ Configuration Points

### To adjust difficulty progression:
```sql
UPDATE dc_upgrade_tracks 
SET base_ilvl = {new}, max_ilvl = {new} 
WHERE track_id = {id};
```

### To adjust token costs:
```sql
UPDATE dc_upgrade_tracks 
SET token_cost_per_upgrade = {new} 
WHERE track_id = {id};
```

### To adjust earn rates:
```sql
UPDATE dc_currency_rewards 
SET tokens_awarded = {new}, flightstones_awarded = {new}
WHERE source_type = '{type}' AND source_difficulty = '{diff}';
```

### To add new track:
```sql
INSERT INTO dc_upgrade_tracks (track_name, source_content, difficulty, 
    base_ilvl, max_ilvl, upgrade_steps, ilvl_per_step, 
    token_cost_per_upgrade, flightstone_cost_base)
VALUES ('{name}', '{content}', '{diff}', {base}, {max}, 5, 4, {tokens}, {fs});
```

## 🐛 Common Issues & Fixes

| Issue | Cause | Fix |
|-------|-------|-----|
| NPC not visible | Creature not spawned | Check `creature` table entry |
| Cannot upgrade | No currency | Kill more bosses |
| Cannot upgrade | Already max | Check `dc_upgrade_tracks` |
| Currency not awarded | Loot hook not firing | Verify `Creature.cpp` changes |
| Wrong cost | Slot modifier missing | Add slot to `dc_item_slot_modifiers` |
| Item disappears | Entry ID not in chain | Verify `dc_item_upgrade_chains` |

## 📊 Performance Targets

- **Gossip menu:** < 100ms load time
- **Upgrade cost calculation:** < 50ms
- **Database queries:** < 20ms with indexes
- **Player login:** No noticeable slowdown
- **NPC response:** < 1 second

## 🎯 Testing Priorities

1. **Core functionality** - Can upgrade item?
2. **Currency handling** - Correct amounts?
3. **Chain integrity** - All items exist?
4. **Edge cases** - Max level? Insufficient funds?
5. **Performance** - Scales to 100+ players?

## 🔐 Security Checklist

```
[ ] Can't upgrade without enough currency
[ ] Can't upgrade beyond max level
[ ] Can't duplicate items
[ ] Can't exchange currency with other players (initially)
[ ] Currency only added by boss kills
[ ] Log all transactions for audit
[ ] Verify item ownership before upgrade
[ ] Block upgrade during combat
[ ] Prevent packet replay exploits
```

## 📚 File Locations

```
Design Doc       → Custom/ITEM_UPGRADE_SYSTEM_DESIGN.md
Database Schema  → Custom/item_upgrade_system/dc_item_upgrade_schema.sql
Python Script    → Custom/item_upgrade_system/generate_item_chains.py
Impl Guide       → Custom/item_upgrade_system/IMPLEMENTATION_GUIDE.md
This Card        → Custom/item_upgrade_system/QUICK_REFERENCE.md

C++ Code         → src/server/scripts/Custom/ItemUpgradeManager.*
                → src/server/scripts/Custom/ItemUpgradeNPC.cpp

Addon UI         → WoW_Client/Interface/AddOns/DC-ItemUpgrade/
```

## 📞 Support Matrix

| Topic | File | Section |
|-------|------|---------|
| How it works? | DESIGN | Player Experience |
| Build it? | IMPLEMENTATION_GUIDE | Phases 1-9 |
| Database? | dc_item_upgrade_schema.sql | Table definitions |
| Automate it? | generate_item_chains.py | Usage |
| Code? | ItemUpgradeManager.cpp | Implementation |
| NPC? | ItemUpgradeNPC.cpp | Gossip |
| UI? | DC-ItemUpgrade addon | UI.lua |
| Balance? | dc_upgrade_tracks | Costs/progression |
| Troubleshoot? | IMPLEMENTATION_GUIDE | Phase 9 |

---

**Last Updated:** November 4, 2025  
**Version:** 1.0  
**Status:** Ready for Development ✅
