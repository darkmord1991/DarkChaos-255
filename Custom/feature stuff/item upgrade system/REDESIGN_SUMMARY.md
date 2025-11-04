# System Redesign Summary: 5 Tokens → 2 Tokens

**Change Date:** November 4, 2025  
**Reason:** Simplification + accessibility for solo/casual players  
**Impact:** Database reduction, easier balance, clearer player communication

---

## 🔄 What Changed

### **Token Economy**

| Aspect | OLD (5 tokens) | NEW (2 tokens) |
|--------|---|---|
| **Currencies** | Leveling, Heroic, Raid, Mythic, Essence | Upgrade Token, Artifact Essence |
| **Weekly Caps** | 4 different caps (500, 1000, 2000, etc) | NO CAPS |
| **Gate Design** | Difficulty → different token type | Higher amounts for higher tier |
| **Philosophy** | Restrict by content | Scale by volume |
| **Solo Access** | Limited (no good solo tokens) | Full (quests give tokens) |

### **Cost Structure**

| Tier | OLD | NEW |
|-----|---|---|
| T1 | 45 tokens | 50 tokens (10 per level) |
| T2 | 250 tokens | 150 tokens (30 per level) |
| T3 | 625 tokens | 375 tokens (75 per level) |
| T4 | 1,250 tokens | 750 tokens (150 per level) |
| T5 | 375 essence | 250 essence (50 per level) |

---

## ✅ Benefits

### **Database**
```
OLD: 5 currency rows + weekly tracking
NEW: 2 currency rows, no weekly fields

Reduction: ~40% fewer database calls
```

### **Balance**
```
OLD: 5 different sources, 5 different caps = complex tuning
NEW: 1 source, no caps = simple scaling

Easier to adjust drop rates if needed
```

### **Player Experience**
```
OLD: "Why don't quests give raid tokens?"
NEW: "Do any content, get same token"

Clearer progression path
```

### **Solo/Casual Access**
```
OLD: Leveling token farmers stuck
NEW: Can upgrade at their own pace

Feels less gated
```

---

## 📊 Progression Expectations

### **Timeline Comparison**

**Solo Player - T1 Completion:**
- OLD: 2-3 weeks (too long for entry level)
- NEW: 1-2 days ✅ FIXED

**Casual Player - T2 Collection:**
- OLD: 8-16 weeks (too long if casual only does heroics)
- NEW: 4-6 weeks ✅ REASONABLE

**Hardcore Player - T4 Completion:**
- OLD: 8-10 weeks (achievable but tight)
- NEW: 10-12 weeks ✅ MORE ACHIEVABLE

---

## 🎮 How Drop Rates Work (Example)

### **Quests**
```
OLD: 1 Leveling Token per quest
NEW: 1-2 Upgrade Tokens per quest

Same effect! Solo progression unchanged.
```

### **Heroic Dungeons**
```
OLD: 3-5 Heroic Tokens per run
NEW: 3-5 Upgrade Tokens per run (same source!)

Casual progression unchanged.
```

### **Mythic Raid**
```
OLD: 20 Mythic Tokens per boss
NEW: 15-20 Upgrade Tokens per boss (roughly same)

Hardcore progression roughly same pace.
```

**Key Insight:** Drop rates SCALE UP for higher tiers, creating natural gates through volume rather than currency type.

---

## 💾 Database Changes Needed

### **New Schema**
```sql
-- SIMPLE 2-token table
CREATE TABLE player_currencies (
    player_guid INT PRIMARY KEY,
    upgrade_tokens INT DEFAULT 0,
    artifact_essence INT DEFAULT 0,
    season INT,
    UNIQUE (player_guid, season)
);

-- Much simpler than old 5-token system!
```

### **No Weekly Tracking Needed**
```
OLD: Track weekly_earned, weekly_cap per currency
NEW: Just track total amount (no cap enforcement)

Less data, faster queries
```

---

## 🔧 Implementation Changes

### **Item Upgrade Costs**
```cpp
// OLD
uint32 GetUpgradeCost(Item* item, uint32 level)
{
    if (tier == 1) return 45;  // One flat cost
    if (tier == 2) return 250; // One flat cost
    // etc
}

// NEW
uint32 GetUpgradeCost(Item* item, uint32 level)
{
    uint32 baseCost[] = {0, 10, 30, 75, 150};  // per tier per level
    return baseCost[tier] * level;  // Scale by level
}
```

### **Currency Check**
```cpp
// OLD
if (HasCurrency(player, CURRENCY_HEROIC_TOKENS, 250)) ...

// NEW
if (HasCurrency(player, CURRENCY_UPGRADE_TOKEN, 150)) ...

Simpler!
```

### **Drop Rate**
```cpp
// OLD - specific to dungeon type
if (dungeon == HEROIC) {
    AddCurrency(player, CURRENCY_HEROIC_TOKENS, 4);
}

// NEW - same token everywhere
AddCurrency(player, CURRENCY_UPGRADE_TOKEN, GetDifficultyTokens());
```

---

## 📈 Expected Player Behavior

### **Solo Player (NEW)**
```
Day 1: Do 20 quests
├─ Get: ~40 Upgrade Tokens
├─ Get: T1 items from quest rewards
└─ Upgrade: Most/all T1 items to level 5

Result: Fully geared T1 player in 1 day
Feeling: "I can actually make progress!"
```

### **Casual Player (NEW)**
```
Week 1: Mix of quests + 2 heroic runs
├─ Tokens: 50 from quests + 8 from dungeons = 58 total
├─ Gear: Several T1 items + 1-2 T2 items
├─ Upgrades: T1 fully upgraded + 1 T2 partially

Week 2-4: Regular heroics, grind T2
├─ Tokens/week: 40-50 from heroics
├─ Items: Collect T2 set
├─ Feel: Real progression, achievable goal

Result: 10-15 T2 items by mid-season
Feeling: "I'm making real progress without insane grinding"
```

### **Hardcore Player (NEW)**
```
Weeks 1-2: Full T1 collection
├─ Token rate: 100-150/day from mixed content
├─ Result: All 150 items + upgrades

Weeks 3-6: Full T2 collection
├─ Token rate: 100-150/day from heroics/m+
├─ Result: All 160 items + upgrades

Weeks 7-12: Partial T3 + start T4
├─ Token rate: 150-200/day from raids
├─ Result: 50+ T3 + 20+ T4 items

Weeks 13-16: Max T4 push + artifacts
├─ Token rate: 200-300/day
├─ Result: 100+ T4 items + 20+ artifacts

Feeling: "Real progression with achievable milestones"
```

---

## 🎯 Success Criteria

✅ Solo players feel accessible entry point (T1 in 1-2 days)  
✅ Casual players have realistic 4-6 week goals (T2 collection)  
✅ Hardcore players have 10+ week endgame grind (T4)  
✅ No weekly cap frustration (natural pacing through volume)  
✅ Simpler to explain and balance  
✅ Same universal token = less confusing  

---

## 📝 Files Updated

1. **TIERED_HEIRLOOM_SYSTEM.md** - Token economy section simplified
2. **SEASON_ITEM_ALLOCATION.md** - Cost breakdown updated to 2 tokens
3. **IMPLEMENTATION_ROADMAP.md** - Database schema simplified
4. **TOKEN_SYSTEM_SIMPLIFIED.md** - NEW comprehensive reference

---

## 🚀 Next Steps

1. ✅ Confirm token amounts look balanced
2. ⏳ Review drop rate scaling by content
3. ⏳ Adjust costs if needed (50 vs 100 per T4 level?)
4. ⏳ Start Phase 1 implementation (database creation)

**Ready to begin implementation?**
