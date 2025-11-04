# Tiered Heirloom Upgrade System: Complete Design

**Status:** New system specification, Season-based with multi-tier progression  
**Architecture:** Heirloom items with token-gated upgrades + artifact system  
**Date:** November 4, 2025

---

## 🎯 SYSTEM OVERVIEW

Your vision: A **tiered heirloom progression system** where:
- ✅ Low-level items start in normal quests/dungeons
- ✅ Each tier requires specific tokens to upgrade
- ✅ Separate token economies for leveling vs endgame
- ✅ Artifacts add variety and prestige
- ✅ Worldforged mechanics for exploration

---

## 📊 TIER STRUCTURE

### **Tier 1: Leveling Heirlooms (Level 1-60)**
```
Source: Regular quests, dungeons (all content)
Token: Standard Leveling Tokens (common)
Upgrades: 0-3 levels (stat boost 10-30%)
Transmog: Basic appearance
Stats: Modest scaling
```

### **Tier 2: Heroic Progression (Level 60-100)**
```
Source: Heroic dungeons + HLBG
Token: Heroic Tokens (uncommon) + Leveling Tokens
Upgrades: 0-5 levels (stat boost 10-50%)
Transmog: Enhanced appearance
Stats: Moderate scaling
```

### **Tier 3: Raid Progression (Level 100-200)**
```
Source: Heroic Raid + Mythic Dungeons
Token: Raid Tokens (rare) + Flightstone-like tokens
Upgrades: 0-5 levels (stat boost 10-50%)
Transmog: Epic appearance
Stats: Strong scaling
```

### **Tier 4: Mythic Endgame (Level 200-255)**
```
Source: Mythic Raid + Mythic+ Dungeons
Token: Mythic Tokens (epic) + Flightstone-like tokens
Upgrades: 0-5 levels (stat boost 10-50%)
Transmog: Legendary appearance
Stats: Maximum scaling
```

### **Tier 5: Artifacts (All levels, special)**
```
Source: Worldforged mechanics (world objects)
Token: Artifact Essence (special currency)
Upgrades: 0-5 levels (stat boost 15-75% - higher rate!)
Transmog: Unique/legendary appearance
Stats: Premium scaling
```

---

## 🏆 TOKEN ECONOMY (SIMPLIFIED - 2 CURRENCIES)

### **Token Types & Sources**

```
UPGRADE TOKEN (Tiers 1-4)
├─ Source: ALL content (quests, dungeons, raids, world bosses)
├─ Rate: Scales by difficulty
│   ├─ Quests: 1-2 tokens per quest
│   ├─ Heroic Dungeons: 3-5 tokens per run
│   ├─ Mythic Dungeons: 5-8 tokens per run
│   ├─ Heroic Raid: 8-12 tokens per boss
│   ├─ Mythic Raid: 15-20 tokens per boss
│   └─ World bosses: 50-100 tokens per kill
├─ Uses: Upgrade ALL heirlooms (Tier 1-4)
├─ Weekly cap: NONE (no cap - lets all players progress)
├─ Auto-currency: Yes (all content)
└─ Philosophy: ACCESSIBLE TO ALL - progression through VOLUME, not restriction

UPGRADE COSTS BY TIER:
  Tier 1 (Leveling):  10 tokens per level  = 50 tokens total (EASY for solo)
  Tier 2 (Heroic):    30 tokens per level  = 150 tokens total (2-3 hours)
  Tier 3 (Raid):      75 tokens per level  = 375 tokens total (10+ hours)
  Tier 4 (Mythic):   150 tokens per level  = 750 tokens total (50+ hours)

EXAMPLE PROGRESSION:
  New player:  Does quests → gets tokens → upgrades T1 items → done in 2 hours
  Casual:      Does heroics → gets tokens → upgrades T2-3 items → 1-2 weeks
  Hardcore:    Does mythics → gets tokens → upgrades T4 items → 4-6 weeks
```

```
ARTIFACT ESSENCE (Tier 5 ONLY)
├─ Source: Worldforged objects (looting world items)
├─ Rate: 1-10 essence per object
├─ Uses: Upgrade ONLY artifacts
├─ Weekly cap: NONE (exploration-based)
├─ Auto-currency: No (manual collection)
├─ Philosophy: PRESTIGE COLLECTION - find artifacts scattered across world
└─ Value: Special (unique cosmetic progression)

ARTIFACT UPGRADE COSTS:
  50 essence per level = 250 essence total per artifact (all 5 levels)
```

---

## 📈 SEASONAL ITEM CALCULATION

### **Retail WoW Seasons Reference**
```
Retail:
├─ Classes: 13
├─ Armor types: 4 (plate, mail, leather, cloth)
├─ Specializations: ~38 (various)
├─ Item slots: 16 main + trinkets
└─ Items per season: ~800-1200 per armor type
    = ~3200-4800 total items

Reality: They track items by:
├─ Armor type (4)
├─ Item slot (16)
├─ Rarity (legendary, epic, rare)
├─ Source (raid, m+, pvp, world)
```

### **Your Server: DarkChaos-255**

```
YOUR SETUP:
├─ Classes: 13 (same as retail)
├─ Armor types: 4
├─ Specializations: ~38 similar
├─ BUT: One level 255 cap (no level variance)
└─ Content: Same raid/dungeon variety

Key difference: No level scaling
Result: Fewer items needed than retail
```

---

## 🎮 SEASON ITEM CALCULATION

### **Base Formula**

```
Items per season = 
  (Armor types × Item slots × Rarity levels) × 
  (Source types × Difficulty multiplier) + 
  Artifacts + Worldforged
```

### **Detailed Breakdown**

#### **Tier 1: Leveling Heirlooms (Level 1-60)**
```
Armor types: 4 (plate, mail, leather, cloth)
Slots: 16 (head, neck, shoulder, chest, waist, legs, feet, 
            wrist, hands, back, finger x2, trinket x2, main hand, off-hand)
Rarity: 2 (uncommon, rare)
Sources: Quests/Dungeons

Calculation:
├─ 4 armor × 16 slots = 64 items (ALL armor types share slots)
├─ But split by armor class: 64/4 = 16 items per class
├─ With 2 rarity levels: 16 × 2 = 32 items per armor type
├─ Total: 4 armor types × 32 = 128 items
├─ Add variants (male/female, cosmetic): × 1.2 = ~150 items
└─ TIER 1 TOTAL: ~150 items

Cost per item: 10-20 Leveling Tokens (cheap, early)
```

#### **Tier 2: Heroic Heirlooms (Level 60-100)**
```
Armor types: 4
Slots: 16
Rarity: 2 (rare, epic)
Sources: Heroic dungeons + HLBG

Calculation:
├─ 4 armor × 16 slots = 64 base
├─ Per armor class: 16 items
├─ Rarity levels: 16 × 2 = 32 per armor
├─ Total: 4 × 32 = 128 items
├─ Add cosmetic variants: × 1.3 = ~160 items
└─ TIER 2 TOTAL: ~160 items

Cost per item: 50-100 Heroic Tokens (moderate)
```

#### **Tier 3: Raid Heirlooms (Level 100-200)**
```
Armor types: 4
Slots: 16
Rarity: 3 (rare, epic, legendary)
Sources: Heroic Raid + Mythic Dungeons

Calculation:
├─ 4 armor × 16 slots = 64 base
├─ Per armor class: 16 items
├─ Rarity levels: 16 × 3 = 48 per armor
├─ Total: 4 × 48 = 192 items
├─ Add cosmetic variants: × 1.3 = ~250 items
└─ TIER 3 TOTAL: ~250 items

Cost per item: 100-200 Raid Tokens (high)
```

#### **Tier 4: Mythic Endgame (Level 200-255)**
```
Armor types: 4
Slots: 16
Rarity: 3 (epic, legendary, artifact-exclusive)
Sources: Mythic Raid + Mythic+ Dungeons

Calculation:
├─ 4 armor × 16 slots = 64 base
├─ Per armor class: 16 items
├─ Rarity levels: 16 × 3 = 48 per armor
├─ Total: 4 × 48 = 192 items
├─ Add cosmetic variants: × 1.4 = ~270 items
└─ TIER 4 TOTAL: ~270 items

Cost per item: 200-400 Mythic Tokens (very high)
```

#### **Tier 5: Artifacts (Special - All levels)**
```
Source: Worldforged mechanics (world objects)
Slots: All (can fill any slot)
Special properties: Higher upgrade rate (+75% at max vs +50%)
Class restrictions: Some class-specific

Calculation:
├─ World exploration zones: 8 zones
├─ Items per zone: 5-10 artifacts
├─ Total exploration: 8 × 7 = 56 artifacts
├─ Dungeon/Raid artifacts: 20 special artifacts
├─ Total: 56 + 20 = 76 artifacts
├─ Cosmetic variants: × 1.5 = ~110 artifacts
└─ TIER 5 TOTAL: ~110 artifacts

Cost per item: 50-100 Artifact Essence (varies)
```

### **TOTAL ITEMS PER SEASON**

```
Tier 1 (Leveling):       150 items
Tier 2 (Heroic):         160 items
Tier 3 (Raid):           250 items
Tier 4 (Mythic):         270 items
Tier 5 (Artifacts):      110 items
────────────────────────────────
TOTAL:                   940 items per season

Comparison:
├─ Your server (less classes): 940 items
├─ Retail equivalent: 800-1200 items
├─ Your ratio: ~80% of retail (reasonable!)
├─ Per player: ~70 items average (16 slots)
└─ Time to collect all: ~200+ hours per season
```

---

## 💰 UPGRADE COSTS BY TIER

### **Tier 1: Leveling (1-60)**

```
Item iLvL progression:
├─ Base: 50 iLvL
├─ Upgrade 1: 55 iLvL (+5)
├─ Upgrade 2: 60 iLvL (+5)
└─ Upgrade 3: 65 iLvL (+5)

Cost per upgrade:
├─ Upgrade 1: 10 Leveling Tokens
├─ Upgrade 2: 15 Leveling Tokens
├─ Upgrade 3: 20 Leveling Tokens
└─ Total per item: 45 tokens (very cheap!)

Stat scaling:
├─ Base: 50 STR
├─ Upgrade 1: 50 × 1.1 = 55 STR (+10%)
├─ Upgrade 2: 50 × 1.2 = 60 STR (+20%)
└─ Upgrade 3: 50 × 1.3 = 65 STR (+30%)
```

### **Tier 2: Heroic (60-100)**

```
Item iLvL progression:
├─ Base: 100 iLvL
├─ Upgrade 1: 108 iLvL (+8)
├─ Upgrade 2: 116 iLvL (+8)
├─ Upgrade 3: 124 iLvL (+8)
├─ Upgrade 4: 132 iLvL (+8)
└─ Upgrade 5: 140 iLvL (+8)

Cost per upgrade:
├─ Upgrade 1: 30 Heroic Tokens
├─ Upgrade 2: 40 Heroic Tokens
├─ Upgrade 3: 50 Heroic Tokens
├─ Upgrade 4: 60 Heroic Tokens
├─ Upgrade 5: 70 Heroic Tokens
└─ Total per item: 250 tokens

Stat scaling:
├─ Base: 100 STR
├─ Upgrade 5: 100 × 1.5 = 150 STR (+50%)
```

### **Tier 3: Raid (100-200)**

```
Item iLvL progression:
├─ Base: 200 iLvL
├─ Upgrades 1-5: +15 iLvL each
└─ Final: 275 iLvL

Cost per upgrade:
├─ Upgrade 1: 75 Raid Tokens
├─ Upgrade 2: 100 Raid Tokens
├─ Upgrade 3: 125 Raid Tokens
├─ Upgrade 4: 150 Raid Tokens
├─ Upgrade 5: 175 Raid Tokens
└─ Total per item: 625 tokens

Stat scaling:
├─ Base: 200 STR
├─ Upgrade 5: 200 × 1.5 = 300 STR (+50%)
```

### **Tier 4: Mythic (200-255)**

```
Item iLvL progression:
├─ Base: 258 iLvL
├─ Upgrades 1-5: +8 iLvL each
└─ Final: 298 iLvL

Cost per upgrade:
├─ Upgrade 1: 150 Mythic Tokens
├─ Upgrade 2: 200 Mythic Tokens
├─ Upgrade 3: 250 Mythic Tokens
├─ Upgrade 4: 300 Mythic Tokens
├─ Upgrade 5: 350 Mythic Tokens
└─ Total per item: 1250 tokens (very expensive!)

Stat scaling:
├─ Base: 258 STR
├─ Upgrade 5: 258 × 1.5 = 387 STR (+50%)
```

### **Tier 5: Artifacts (Special)**

```
Item iLvL progression:
├─ Base: 240 iLvL (starts higher!)
├─ Upgrades 1-5: +12 iLvL each
└─ Final: 300 iLvL (highest!)

Cost per upgrade:
├─ Upgrade 1: 50 Artifact Essence
├─ Upgrade 2: 60 Artifact Essence
├─ Upgrade 3: 75 Artifact Essence
├─ Upgrade 4: 90 Artifact Essence
├─ Upgrade 5: 100 Artifact Essence
└─ Total per item: 375 Essence

Stat scaling (HIGHER than regular items!):
├─ Base: 240 STR
├─ Upgrade 5: 240 × 1.75 = 420 STR (+75% vs +50%)
└─ Result: More powerful endgame option!
```

---

## 🗺️ WORLDFORGED ARTIFACT SYSTEM

### **Concept: Project Ascension-inspired world loot**

Your reference: https://project-ascension.fandom.com/wiki/Worldforged_RPG_Items

```
Worldforged = Items placed as game objects
├─ Hidden around the world
├─ Requires exploration to find
├─ Cosmetics + unique stats
├─ Account-bound or character-bound
└─ Special transmog appearance
```

### **Implementation**

#### **Type 1: Zone Artifacts (56 total)**

```
Leveling Zones (1-60):
├─ Elwynn Forest: 3 artifacts
├─ Westfall: 3 artifacts
├─ Loch Modan: 3 artifacts
├─ Dun Morogh: 3 artifacts
└─ Other starter zones: 4 artifacts
   SUBTOTAL: 16 artifacts (common)

Mid-Level Zones (60-100):
├─ Badlands: 3 artifacts
├─ Searing Gorge: 3 artifacts
├─ Hinterlands: 3 artifacts
└─ Other mid zones: 10 artifacts
   SUBTOTAL: 19 artifacts (uncommon)

High-Level Zones (100-200):
├─ Winterspring: 4 artifacts
├─ Silithus: 4 artifacts
├─ Burning Steppes: 4 artifacts
└─ Other high zones: 9 artifacts
   SUBTOTAL: 21 artifacts (rare)

Total Zone Artifacts: 56
```

#### **Type 2: Dungeon/Raid Artifacts (20 total)**

```
Special artifacts only obtainable from:
├─ Boss loot tables (5% drop)
├─ World bosses (20% drop)
├─ Hidden raid chest (100% if found)
├─ Special event rewards
└─ Achievement unlocks

Breakdown:
├─ Dungeon artifacts: 8
├─ Raid artifacts: 7
├─ World boss artifacts: 5
└─ Total: 20 artifacts (epic rarity)
```

#### **Type 3: Cosmetic Variants (varies)**

```
Each artifact can have:
├─ Male version
├─ Female version
├─ Color variants
├─ Transmog options
└─ Bonus appearance options

Multiplier: × 1.5 (account for variants)

Total unique appearances: 76 × 1.5 = ~110 artifacts
```

### **Artifact Characteristics**

```
Stats:
├─ 20% higher base stats than regular items
├─ 75% upgrade multiplier (vs 50% regular)
├─ Special secondary stats (not available elsewhere)
└─ Unique set bonuses if collecting multiple

Appearance:
├─ Distinctive transmog look
├─ Glowing effects
├─ Particle effects (some)
├─ Custom model variations
└─ "Legendary" visual feedback

Progression:
├─ Can be upgraded same as regular items
├─ Same token system applies
├─ Artifact Essence acts as "premium" currency
└─ Same upgrade tiers (0-5)

Rarity:
├─ Finding all artifacts: ~100+ hours
├─ Special achievement: "Worldforger" title
├─ Cosmetic reward: Account-wide transmog set
└─ Prestige: Shows endgame dedication
```

---

## 📊 COMPLETE TOKEN ECONOMY SUMMARY

### **Weekly Token Acquisition**

```
PLAYER SCENARIO: Casual (10 hours/week)
├─ Quests: 50 Leveling Tokens (abundant)
├─ Heroic dungeons (2/week): 15 Heroic Tokens
├─ HLBG (5 wins): 20 Heroic Tokens
├─ Flightstone-like: 5 tokens
└─ Total: 50 leveling + 35 heroic + 5 flight

PLAYER SCENARIO: Hardcore (30 hours/week)
├─ All content completed:
│  ├─ Heroic dungeons (10/week): 50 Heroic
│  ├─ HLBG (20 wins): 80 Heroic
│  ├─ Heroic Raid (1/week): 30 Raid
│  ├─ Mythic dungeons (5/week): 25 Raid
│  ├─ Mythic Raid (1/week): 25 Mythic
│  ├─ Mythic+ (10/week): 50 Mythic
│  └─ World exploration: 30 Artifact Essence
└─ Weekly total: 80 Heroic + 55 Raid + 75 Mythic + 30 Essence
```

### **Item Upgrade Timeline**

```
TIER 1 LEVELING ITEM (150 tokens total, cheap):
├─ Casual: 3 weeks
├─ Hardcore: < 1 week
└─ Result: Low barrier, accessible

TIER 2 HEROIC ITEM (250 tokens):
├─ Casual: 7 weeks
├─ Hardcore: 1 week
└─ Result: Early season milestone

TIER 3 RAID ITEM (625 tokens):
├─ Casual: 18 weeks
├─ Hardcore: 2 weeks
└─ Result: Mid-season achievement

TIER 4 MYTHIC ITEM (1250 tokens):
├─ Casual: 36+ weeks (entire season!)
├─ Hardcore: 3-4 weeks
└─ Result: Endgame grind

TIER 5 ARTIFACT (375 essence + exploration):
├─ Casual: 12+ weeks (finding + upgrading)
├─ Hardcore: 2-3 weeks
└─ Result: Special prestige item
```

---

## 🎯 SEASONAL STRUCTURE

### **Season Duration: 16 Weeks (4 months)**

```
PHASE 1: Launch (Weeks 1-4) - New Players Catch Up
├─ All tiers available immediately
├─ Leveling tokens: Double rate
├─ Heroic tokens: Normal rate
├─ Focus: All players reach Tier 2
└─ Goal: Inclusive progression

PHASE 2: Grind (Weeks 5-12) - Main Progression
├─ Normal token rates
├─ Raid/Mythic focus
├─ Artifact discovery continues
├─ Weekly challenges for bonus tokens
└─ Goal: Reach endgame items

PHASE 3: Final Push (Weeks 13-16) - Refinement
├─ Token rates unchanged
├─ Hardened players max everything
├─ Artifact hunting continues
├─ Prep for next season
└─ Goal: Complete collector goals

SEASON END:
├─ Items remain (they're heirlooms!)
├─ Stats don't reset
├─ Next season: New tier added
└─ Progression stacks
```

### **Season Progression Example**

```
Season 1 (Weeks 1-16):
├─ Tier 1: Available (Leveling)
├─ Tier 2: Available (Heroic)
├─ Tier 3: Available (Raid)
├─ Tier 4: Available (Mythic)
└─ Tier 5: Available (Artifacts)
   Total items: 940

Season 2 (Weeks 17-32):
├─ All previous items still usable
├─ New Tier 5.5 added (higher-level artifacts)
├─ New cosmetics for all tiers
├─ New world artifacts (56 new)
└─ New dungeon/raid artifacts (20 new)
   New items this season: ~90
   Cumulative items: 940 + 90 = 1030

RESULT: Players keep growing, new challenges added!
```

---

## 🛠️ IMPLEMENTATION PRIORITY

### **Phase 1: Foundation (Week 1-2)**
```
[ ] Create token currency tables (5 types)
[ ] Create heirloom item templates (T1-T5)
[ ] Implement upgrade mechanics
[ ] Set costs per tier
[ ] Create vendor NPCs
```

### **Phase 2: Quests & Dungeons (Week 3-4)**
```
[ ] Add tokens to quest rewards (T1-T2)
[ ] Add tokens to dungeon loot tables (T2-T4)
[ ] Add tokens to raid loot tables (T3-T4)
[ ] Balance token acquisition rates
[ ] Test weekly caps
```

### **Phase 3: Artifacts (Week 5-6)**
```
[ ] Create worldforged game objects (56)
[ ] Implement looting mechanics
[ ] Create Artifact Essence currency
[ ] Add artifact-only items (20)
[ ] Create Artifact transmog system
```

### **Phase 4: UI & Polish (Week 7)**
```
[ ] Create vendor UI
[ ] Create upgrade interface
[ ] Add progress tracking
[ ] Implement tooltips
[ ] Create achievement system
```

### **Phase 5: Testing & Balance (Week 8)**
```
[ ] Full player testing
[ ] Token rate balance
[ ] Difficulty tuning
[ ] Transmog testing
[ ] Performance optimization
```

---

## 📋 FINAL ITEM COUNT BREAKDOWN

```
SEASON 1 TOTAL: 940 items

BY TIER:
├─ Tier 1 (Leveling):      150 items (10% of season)
├─ Tier 2 (Heroic):        160 items (17% of season)
├─ Tier 3 (Raid):          250 items (27% of season)
├─ Tier 4 (Mythic):        270 items (29% of season)
└─ Tier 5 (Artifacts):     110 items (12% of season)

BY SOURCE:
├─ Quests:                 150 items
├─ Dungeons:               210 items
├─ Heroic Raid:            180 items
├─ Mythic Dungeons:        140 items
├─ Mythic Raid:            150 items
└─ World/Special:          110 items

TIME INVESTMENT PER PLAYER:
├─ Casual (1 slot): ~70 items, 100-150 hours per season
├─ Hardcore (all): 940 items, 500+ hours per season
└─ Average player: 200-300 items, 200-300 hours per season

COMPARISON TO RETAIL:
├─ Retail items/season: 800-1200
├─ Your items/season: 940
├─ Ratio: ~85% of retail (excellent!)
└─ Reason: Single level cap (255), no level scaling
```

---

## 💡 UNIQUE FEATURES

### **What Makes This Great**

```
✅ SEPARATE LEVELING ECONOMY
   └─ New players get tokens from quests
   └─ Don't need endgame to upgrade leveling gear
   └─ Solves the "gear gap" problem

✅ ARTIFACT PRESTIGE SYSTEM
   └─ Exploration + upgrades
   └─ Higher stat potential (75% vs 50%)
   └─ Cosmetic rewards for collection
   └─ Endgame goal for hardcore players

✅ TIERED PROGRESSION
   └─ Clear path: Leveling → Heroic → Raid → Mythic → Artifacts
   └─ Accessibility: New players can participate
   └─ Depth: Hardcore has 500+ hours content
   └─ Longevity: Each season adds new items

✅ HEIRLOOM ATTACHMENT
   └─ Same items forever (character-bound)
   └─ Emotional investment
   └─ Prestige of max upgrades
   └─ Transmog for customization

✅ BALANCED TOKEN ECONOMY
   └─ Separate currencies prevent inflation
   └─ Weekly caps prevent farming
   └─ Difficulty scaling fairness
   └─ Accessibility + challenge balance
```

---

## 🎮 PLAYER JOURNEY EXAMPLE

```
NEW PLAYER - WEEK 1
└─ Starts character
   ├─ Receives Tier 1 starter heirloom (green)
   ├─ Completes quests
   ├─ Gets Leveling Tokens (abundant)
   ├─ Upgrades T1 item once (cheap: 10 tokens)
   ├─ Notices stat increase (+10%)
   └─ Feels progression ✓

CASUAL PLAYER - WEEK 4
└─ Level 60, now using Tier 2
   ├─ Runs Heroic dungeons
   ├─ Gets Heroic Tokens (scarce)
   ├─ Upgrades T2 item once (costs 30 tokens)
   ├─ Notices better gear than quests provide
   ├─ Can reach T3 items eventually
   └─ Feels challenged but achievable ✓

HARDCORE PLAYER - WEEK 8
└─ Level 255, doing everything
   ├─ Running Mythic raids
   ├─ Collecting artifacts (found 12/110)
   ├─ Has T4 items at upgrade level 3
   ├─ Collecting cosmetic transmogs
   ├─ Planning artifact collection journey
   └─ Feels endgame prestige ✓

END OF SEASON - WEEK 16
└─ ALL PLAYERS REACHED TIER 3+
   ├─ New player: T3 items, upgrade level 2
   ├─ Casual: T4 items, upgrade level 1
   ├─ Hardcore: T5 items + artifacts, max upgrade
   ├─ Everyone has visible progression
   ├─ Items carry over to Season 2
   └─ Next season adds Tier 5.5 ✓
```

---

## 📊 RETENTION & ENGAGEMENT

### **Weekly Engagement Hooks**

```
CASUAL PLAYERS (10h/week):
├─ Quest rewards: 3 sessions/week
├─ Weekly dungeon challenge: 1 session
├─ Upgrade decision: "Should I save for T3?"
├─ Visual feedback: See item stats grow
└─ Motivation: Eventually reach next tier

HARDCORE PLAYERS (30h/week):
├─ Daily dungeon runs: Token chase
├─ Weekly raid lockouts: Maximize drops
├─ Artifact hunting: Exploration achievement
├─ Optimization: Perfect transmog
├─ Competition: Leaderboards for most items
└─ Motivation: Complete everything

SEASONAL RESETS:
├─ New content every 16 weeks
├─ Items carry over (no loss of progress)
├─ New tier added (progression continues)
├─ New cosmetics (transmog variety)
├─ Community event: "Season launch"
└─ Motivation: New goals
```

---

## 🎯 CONCLUSION

### **System Metrics**

```
Season 1 Items: 940 total
├─ Obtainable: 800 (main progression)
├─ Prestige: 110 (artifacts + cosmetics)
└─ Per player: 70-100 average

Time Investment:
├─ Casual: 100-200 hours for tier 3
├─ Hardcore: 500+ hours for everything
└─ Casual average per item: 3-5 hours

Engagement Longevity:
├─ Per season: 16 weeks
├─ Per player journey: 8-50 hours/week options
├─ Prestige ceiling: Extremely high (artifacts)
└─ Replayability: Each season new

Token Economy:
├─ 5 separate currencies = no inflation
├─ Weekly caps = fairness
├─ Difficulty scaling = accessibility
└─ Separate systems = longevity
```

This is a **complete, season-based progression system** that works for both casual and hardcore players!

---

*Tiered Heirloom Upgrade System with Artifacts*  
*940 items per season | 5 tiers | Worldforged mechanics*  
*Ready for implementation*
