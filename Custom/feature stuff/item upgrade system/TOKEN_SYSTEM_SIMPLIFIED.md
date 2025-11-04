# Simplified 2-Token System

**Date:** November 4, 2025  
**Change:** Simplified from 5 tokens → 2 tokens  
**Philosophy:** Higher amounts scale progression, no weekly caps = accessible to all players

---

## 📊 Token System Overview

### **Token 1: Upgrade Token**
**Used for:** Tier 1-4 item upgrades  
**Drop Rate:** Scales by difficulty
- Quests: 1-2 tokens per quest
- Heroic Dungeons: 3-5 tokens per run
- Mythic Dungeons: 5-8 tokens per run
- Heroic Raid: 8-12 tokens per boss
- Mythic Raid: 15-20 tokens per boss
- World bosses: 50-100 tokens per kill

**Weekly Cap:** NONE (lets all players progress)

**Usage:**
```
T1 (Leveling):  10 tokens per level  =  50 tokens total
T2 (Heroic):    30 tokens per level  = 150 tokens total
T3 (Raid):      75 tokens per level  = 375 tokens total
T4 (Mythic):   150 tokens per level  = 750 tokens total
```

### **Token 2: Artifact Essence**
**Used for:** Tier 5 artifacts ONLY  
**Drop Rate:** 1-10 per worldforged object  
**Weekly Cap:** NONE (exploration-based)

**Usage:**
```
T5 (Artifact):  50 essence per level = 250 essence total
```

---

## ⏱️ Progression Timelines

### **Solo Player (Leveling Content)**
```
Timeline: 1-2 days
├─ Complete quests: 10-15 quests × 1-2 tokens = 20-30 tokens
├─ Get T1 items: Quest rewards (automatic)
├─ Upgrade 1 set: 50 tokens needed
│  ├─ Have: 20-30 tokens from quests
│  ├─ Need: 15-20 more tokens
│  └─ Time: 2-3 more quests = 1 hour
└─ Result: Fully equipped + upgraded T1 heirlooms

BENEFITS:
✅ Accessible immediately
✅ No grinding required
✅ Clear progression path
✅ Feel like progress is real
```

### **Casual Player (Heroic Content)**
```
Timeline: 2-3 weeks
├─ Week 1: Do quests + first heroics
│  ├─ Tokens: 50-100 Upgrade Tokens
│  └─ Gear: T1 and start T2 collection
├─ Week 2-3: Regular heroic runs
│  ├─ 1 run/day × 7 days = 7 runs
│  ├─ Average 4 tokens/run = 28 tokens/week
│  ├─ Total: 50+ tokens/week steady
│  └─ Upgrade 3-4 T2 items per week
└─ Result: 10-15 T2 items at max upgrade, solid gearing

REALISTIC PACE:
✅ 1-2 hours daily playtime
✅ Doable without grinding
✅ Feel good progress
✅ Not dominated by hardcore
```

### **Hardcore Player (All Content)**
```
Timeline: 6-10 weeks per tier
├─ Phase 1 (Weeks 1-2): T1 completion
│  ├─ Target: All 150 items at max
│  ├─ Daily: 2-4 hours quests
│  ├─ Tokens: 100-200/day
│  ├─ Cost: 7,500 tokens total
│  └─ Done in: 2 weeks
│
├─ Phase 2 (Weeks 3-6): T2 completion
│  ├─ Target: All 160 items at max
│  ├─ Daily: 2-3 hours heroics
│  ├─ Tokens: 100-150/day
│  ├─ Cost: 24,000 tokens total
│  └─ Done in: 4 weeks
│
├─ Phase 3 (Weeks 7-12): T3 completion
│  ├─ Target: All 250 items at max
│  ├─ Daily: 3-4 hours raids/m+
│  ├─ Tokens: 150-250/day
│  ├─ Cost: 93,750 tokens total
│  └─ Done in: 5-6 weeks
│
└─ Phase 4 (Weeks 13-16): T4 + Artifacts
   ├─ Target: 50-100 T4 items + 20+ artifacts
   ├─ Daily: 4+ hours endgame
   ├─ Tokens: 250-400/day
   ├─ Cost: 200,000+ tokens
   └─ Done in: Ongoing throughout season

REALISTIC PACE:
✅ 4-8 hours daily playtime
✅ Dedicated players only
✅ Real endgame grind
✅ Achievable but challenging
```

---

## 💡 Key Advantages

### **For Solo/Casual Players**
```
✅ T1 fully accessible in 1-2 days
✅ No weekly cap frustration
✅ Can upgrade on their own pace
✅ Not blocked by artificial gates
✅ Feel real progression daily
✅ Can always do SOMETHING useful
```

### **For Hardcore Players**
```
✅ Clear long-term grind goal
✅ More tokens = more progression
✅ Can no-life and get rewarded
✅ Real endgame challenge
✅ Achieve T4 = prestige
✅ Artifact hunting = sidequest
```

### **For Server Economy**
```
✅ Simpler database (2 tables vs 5)
✅ No complex cap calculations
✅ Easier to balance
✅ Less chance of exploits
✅ Easier to explain to players
✅ Better scaling potential
```

---

## 📈 Scaling Philosophy

**Old system:** Different tokens by difficulty = players forced into specific content

**New system:** Same token everywhere = players choose difficulty based on playstyle

```
Choice 1: Solo in quests
├─ 1-2 tokens per quest
├─ Slow but steady
├─ Always available
└─ Perfect for casuals

Choice 2: Group in heroics
├─ 3-5 tokens per run
├─ Better per hour
├─ Need group
└─ Good for casuals+

Choice 3: Raid content
├─ 8-20 tokens per boss
├─ Best per hour
├─ Need raid team
└─ For hardcore

Same token = All content is viable
Player chooses pace = Freedom
Higher cost = Natural progression gate
```

---

## 📊 Expected Weekly Earnings

### **Casual Player (Heroic Dungeons)**
```
Scenario: 10-15 hours/week in heroics
├─ Average 4 tokens per run
├─ 2 runs/day × 5 days = 10 runs
├─ 10 runs × 4 tokens = 40 tokens/week
├─ Monthly: 160 tokens = Max 1 T2 item per week

Per month: 4 T2 items at max level
```

### **Hardcore Player (Multiple Content)**
```
Scenario: 50+ hours/week (mix of everything)
├─ 10 quests: 20 tokens
├─ 10 heroic runs: 40 tokens
├─ 10 m+ runs: 70 tokens
├─ 5 raid bosses: 50 tokens
├─ Total/day: ~18 hours = 180 tokens
├─ Weekly: 1,260 tokens (roughly)

Per month: 50+ T2 items OR 10+ T3 items OR 5+ T4 items
```

---

## ✅ Implementation Changes

**Database:**
```sql
-- OLD (5 currencies)
currency_type ENUM('leveling', 'heroic', 'raid', 'mythic', 'essence')
weekly_earned INT
weekly_cap INT

-- NEW (2 currencies)
currency_type ENUM('upgrade_token', 'artifact_essence')
-- No weekly fields needed!
```

**NPC Vendors:**
```
OLD: 5 different vendors (one per tier)
NEW: 1 vendor (shows prices in Upgrade Tokens)

OLD: Complex explanations
NEW: Simple - "Higher tier = more tokens needed"
```

**Player Communication:**
```
OLD: "You have 250/500 Heroic Tokens. Need 500 Raid Tokens to upgrade T3."
NEW: "You have 1,500 Upgrade Tokens. Tier 3 item costs 375 tokens."

Much clearer!
```

---

## 🎯 Success Metrics

**For Solo Players:**
- ✅ T1 full set in 1 day
- ✅ One T2 item per week
- ✅ 10-15 items total per season

**For Casual Players:**
- ✅ T1 full set + upgrades: Week 1
- ✅ 15-20 T2 items: Week 4-8
- ✅ Prestige through T2 collection

**For Hardcore Players:**
- ✅ T1 complete: Week 2
- ✅ T2 complete: Week 6
- ✅ T3 partial complete: Week 12
- ✅ T4 items: Ongoing
- ✅ 20+ artifacts: Season end

---

## 🔄 Seasonal Reset

Each season:
```
New season = New items (940 fresh)
Previous season items = Become cosmetic transmog (legacy)
Tokens reset = 0 tokens at season start
Same farming patterns = Familiar to players
```

**Retention:**
```
Players come back because:
├─ New items to collect
├─ New cosmetics to find
├─ New tier to conquer
├─ Same token system = not scary
└─ Faster progression on alts (understanding)
```

---

**Summary:** 2 tokens, no weekly caps, higher amounts = accessible for all while maintaining proper endgame progression gates through sheer volume.
