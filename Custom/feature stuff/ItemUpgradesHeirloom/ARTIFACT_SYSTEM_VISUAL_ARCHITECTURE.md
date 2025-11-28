# 🎨 ARTIFACT SYSTEM - VISUAL ARCHITECTURE & DATA FLOW

**Visual Guide to Artifact System Integration**

---

## 📊 SYSTEM ARCHITECTURE DIAGRAM

```
┌─────────────────────────────────────────────────────────────────┐
│                      ARTIFACT SYSTEM OVERVIEW                    │
└─────────────────────────────────────────────────────────────────┘

                         PLAYER CHARACTER
                               │
                ┌──────────────┼──────────────┐
                │              │              │
          ARTIFACT 1      ARTIFACT 2      ARTIFACT 3
         (Weapon)         (Shirt)         (Bag)
             │              │              │
        ┌────┴──────┬────────┴────┬────────┴───────┐
        │           │            │                │
    LAYER 1     LAYER 1      LAYER 1         LAYER 1
   HEIRLOOM    HEIRLOOM      HEIRLOOM       HEIRLOOM
   SCALING     SCALING       SCALING        SCALING
   (Prim Stats) (N/A)        (N/A)        (N/A)
        │                                      │
        ├─────────────────────────────────────┤
        │                                      │
        v                                      v
   LAYER 2                              SPECIAL:
   ENCHANT                            SLOT SCALING
   (Sec Stats)
        │
        v
   LAYER 3
   PROGRESSION
   (Essence)
        │
        v
   FINAL ITEM
   (Fully Enhanced)
```

---

## 🔄 ITEM UPGRADE FLOW

```
WORLD SPAWN
    ↓
    └─→ Artifact Claymore (item 191001)
        Quality: 7 (Heirloom)
        Flags: Heirloom flag (134221824)
        ScalingStatDistribution: 298 (enables auto-scaling)
        UpgradeLevel: 0 (not yet upgraded)
        ↓
        ├─ PLAYER LOOTS ITEM
        │  └─→ Item placed in inventory
        │      Stats: Scaled to player level via heirloom_scaling_255.cpp
        │      Display: "Item Level XX → YY (at level ZZ)"
        │  ↓
        │  ├─ PLAYER EQUIPS
        │  │  └─→ Hook: OnPlayerEquip triggers
        │  │      Action: Read artifact metadata
        │  │      Check: Is upgrade_level > 0?
        │  │      No? → Skip enchant, continue
        │  │      Yes? → Apply enchant (next step)
        │  │
        │  ├─ PLAYER LEVELS UP
        │  │  └─→ Heirloom system triggers (automatic)
        │  │      Action: Recalculate primary stats for new level
        │  │      Result: Stats increase automatically
        │  │      No player action needed!
        │  │
        │  └─ PLAYER UPGRADES WEAPON
        │     └─→ Command: .dcupgrade perform
        │         Check: Has 500 essence?
        │         Spend: 500 essence removed
        │         Update: upgrade_level = 1
        │         Create: Enchant ID 80501
        │         Apply: TEMP_ENCHANTMENT_SLOT gets enchant 80501
        │         Query: spell_bonus_data[80501] → direct_bonus = 0.025
        │         Result: All secondary stats +2.5%
        │         Display: Green bonus text in tooltip
        │  ↓
        │  └─→ FULLY UPGRADED (Level 15)
        │      upgrade_level: 15
        │      Enchant ID: 80515 (active)
        │      Stat Multiplier: 1.75 (+75% all stats)
        │      Total Essence Spent: 30,250
        │
        └─→ Item remains in use throughout progression
            All stats scale with level
            Secondary stats never need manual update
```

---

## 💾 DATABASE RELATIONSHIP DIAGRAM

```
┌──────────────────────────────────────────────────────────────┐
│                      DATABASE SCHEMA                         │
└──────────────────────────────────────────────────────────────┘

artifact_items
├─ artifact_id (PK)
├─ item_template_id (FK → item_template)
├─ artifact_type (WEAPON|SHIRT|BAG|TRINKET)
├─ artifact_name
├─ lore_description
├─ special_ability
├─ tier_id = 5
├─ max_upgrade_level = 15
├─ essence_type_id = 200001
└─ is_active

         │ (1-to-Many)
         ↓

artifact_loot_locations
├─ location_id (PK)
├─ artifact_id (FK → artifact_items)
├─ map_id
├─ zone_id
├─ x, y, z, orientation
├─ gameobject_entry
├─ respawn_time_sec
├─ location_name
└─ is_enabled

         │ (1-to-Many)
         ↓

player_artifact_data
├─ player_guid (PK, FK → characters)
├─ artifact_id (PK, FK → artifact_items)
├─ item_guid
├─ upgrade_level (0-15)
├─ essence_spent (0-30250)
├─ acquired_timestamp
├─ last_upgraded_timestamp
├─ currently_equipped
└─ is_active

         │ (Uses)
         ↓

dc_item_upgrade_costs
├─ cost_id (PK)
├─ tier_id = 5 (for artifacts)
├─ upgrade_level (1-15)
├─ token_cost = 0 (not used for artifacts)
├─ essence_cost (500-4000)
└─ gold_cost = 0

         │ (Uses)
         ↓

spell_bonus_data
├─ entry = 80501-80515 (enchant IDs)
├─ direct_bonus (0.025-0.075 = +2.5% to +7.5%)
├─ dot_bonus
├─ ap_bonus
└─ ap_dot_bonus


CONNECTIONS:
item_template ←─── artifact_items ←─── player_artifact_data ──→ characters
      ↓                   ↓
      │            artifact_loot_locations
      └─────────────────────┘

dc_item_upgrade_costs ← artifact tier 5 costs

spell_bonus_data ← enchant bonus configuration
```

---

## 🎮 IN-GAME STAT PROGRESSION VISUALIZATION

```
ARTIFACT WEAPON STAT SCALING OVER TIME

STAT VALUE
    │                                    
 300├─────────────────────────────────── MAX (Level 15, Full upgrade)
    │                              ╱─────
 250├──────────────────────────────
    │                         ╱───
 200├─────────────────────────       UPGRADE PROGRESSION
    │                    ╱───         (Yellow Line)
 150├────────────────────    
    │               ╱──              LEVEL SCALING
 100├────────────────  LEGEND:        (Red Line)
    │          ╱────  ──── Heirloom Scaling (Auto)
  50├────────────    ---- Upgrade Progression (Manual)
    │      ╱─────
   0└────────────────────────────────────────
    1   10  20  30  40  50  60  70  80  90  100+
                      PLAYER LEVEL

INTERPRETATION:
- Vertical axis: Sword damage
- Horizontal axis: Player level
- Red line: Primary stat growth (automatic via heirloom)
- Yellow line: Secondary stat growth (manual via upgrades)
- Both lines end at level 255 (extended heirloom scaling)

AT LEVEL 100:
├─ Unupgraded artifact
│  └─ Damage: ~180 (from heirloom scaling alone)
│
└─ Fully upgraded artifact (level 15)
   └─ Damage: ~180 × 1.75 = 315 (+75% from upgrades)
```

---

## 🔀 STAT CALCULATION FORMULA

```
FINAL STAT VALUE = (Base Stat) × (Heirloom Multiplier) × (Enchant Bonus)

WHERE:

Base Stat = ItemTemplate.stat_value
            (e.g., Claymore: Strength = 250)

Heirloom Multiplier = 1.0 + ((player_level - 80) / 80)
                      [Capped at 4.0 at level 255]
                      
                      Examples:
                      ├─ Level 80: 1.0x
                      ├─ Level 160: 2.0x
                      ├─ Level 240: 4.0x (max cap)
                      └─ Level 255: 4.0x (max cap)

Enchant Bonus = 1.0 + (upgrade_level × 0.025)
                [Only applied if upgrade_level > 0]
                
                Examples:
                ├─ Level 0: 1.0x (no enchant)
                ├─ Level 1: 1.025x (+2.5%)
                ├─ Level 8: 1.2x (+20%)
                └─ Level 15: 1.375x (+37.5%)

STAT MULTIPLIER (applied to ALL stats) = Heirloom × Enchant
                                         = 1.0 to 1.75x


EXAMPLE CALCULATION:
Player: Level 100, Claymore at upgrade level 10

Claymore Base Strength: 250

Heirloom Multiplier = 1 + ((100-80)/80) = 1 + 0.25 = 1.25x

Enchant Bonus = 1 + (10 × 0.025) = 1 + 0.25 = 1.25x

Final Strength = 250 × 1.25 × 1.25 = 390.625 ≈ 391

RESULT: Sword now provides +391 Strength at level 100 with 10 upgrades
```

---

## 🛡️ ENCHANT APPLICATION SEQUENCE

```
ARTIFACT EQUIP → ENCHANT APPLICATION FLOW

1. Player equips artifact weapon
   │
   └─→ Triggers: OnPlayerEquip()
       └─→ Check: Is this an artifact?
           │
           ├─ NO → Done, no special handling
           │
           └─ YES → Continue
               │
               └─→ Query artifact metadata
                   ├─ artifact_id = 1
                   ├─ tier_id = 5
                   └─ current_upgrade_level = ? (from DB)
                   │
                   ├─ If upgrade_level == 0
                   │  └─→ No enchant needed (no upgrades yet)
                   │      Done
                   │
                   └─ If upgrade_level > 0
                      │
                      └─→ Calculate enchant ID:
                          Formula: 300003 + (tier × 100) + level
                          Example: 300003 + (5 × 100) + 10 = 80510
                          │
                          └─→ Apply enchant to TEMP_ENCHANTMENT_SLOT
                              │
                              ├─ item.SetEnchantment(TEMP_ENCHANTMENT_SLOT, 80510)
                              │
                              └─→ player.ApplyEnchantment(item, TEMP_ENCHANTMENT_SLOT, true)
                                  │
                                  └─→ Queries spell_bonus_data[80510]
                                      │
                                      ├─ direct_bonus = 0.250 (+25%)
                                      ├─ dot_bonus = 0.250
                                      ├─ ap_bonus = 0.250
                                      └─ ap_dot_bonus = 0.250
                                      │
                                      └─→ Applies all modifiers to player
                                          │
                                          ├─ Crit Rating: +25%
                                          ├─ Haste Rating: +25%
                                          ├─ Hit Rating: +25%
                                          ├─ Defense: +25%
                                          ├─ Armor: +25%
                                          └─ All other stats: +25%
                                              │
                                              └─→ RESULT: Secondary stats fully buffed!


PLAYER UNEQUIPS ARTIFACT WEAPON
   │
   └─→ Triggers: OnPlayerUnequip()
       │
       ├─ Check: Is TEMP_ENCHANTMENT_SLOT active?
       │  └─→ YES → Remove it
       │      │
       │      └─→ player.ApplyEnchantment(item, TEMP_ENCHANTMENT_SLOT, false)
       │          └─→ All bonuses removed immediately
       │
       └─→ RESULT: Enchant fully removed, stats revert
```

---

## 📈 UPGRADE COST PROGRESSION

```
ESSENCE COST TO REACH EACH LEVEL

Level  Cumulative   Per-Level  Total Cost  Stat Multiplier
0-1    500         500        500         1.025x
1-2    1,250       750        1,250       1.050x
2-3    2,250       1,000      2,250       1.075x
3-4    3,500       1,250      3,500       1.100x
4-5    5,000       1,500      5,000       1.125x
5-6    6,750       1,750      6,750       1.150x
6-7    8,750       2,000      8,750       1.175x
7-8    10,750      2,000      10,750      1.200x
8-9    12,750      2,000      12,750      1.225x
9-10   15,000      2,250      15,000      1.250x
10-11  17,750      2,750      17,750      1.275x
11-12  20,750      3,000      20,750      1.300x
12-13  24,000      3,250      24,000      1.325x
13-14  27,250      3,250      27,250      1.350x
14-15  30,250      3,000      30,250      1.375x

TOTAL TO MAX LEVEL 15: 30,250 ESSENCE

VISUALIZATION:
Essence Cost
    │
 4000├─────────────── 
      │              ╱───
 3500├──────────────╱
      │           ╱
 3000├──────────╱
      │        ╱
 2500├──────╱
      │     ╱
 2000├────╱
      │   ╱
 1500├──╱
      │ ╱
 1000├╱
      │
  500├
      │
    0└─────────────────────────
      1  2  3  4  5  6  7  8  9 10 11 12 13 14 15
         UPGRADE LEVEL

NOTE: Costs increase up to level 13, then slightly decrease for level 14-15
This creates an interesting economic decision for players:
- Reach level 13 = expensive grinding
- Finish to 15 = relatively cheap (sunk cost fallacy helps!)
```

---

## 🎯 TIER 5 POSITION IN UPGRADE SYSTEM

```
TIER PROGRESSION HIERARCHY

Tier 1: Common        Tier 2: Uncommon     Tier 3: Rare
├─ Max: 6 levels     ├─ Max: 15 levels    ├─ Max: 15 levels
├─ Cost: Tokens      ├─ Cost: Tokens      ├─ Cost: Tokens
├─ Stats: 0.9x base  ├─ Stats: 0.95x base ├─ Stats: 1.0x base
├─ Use: New players  ├─ Use: Heroic gear  └─ Use: Raid gear
└─ Example: Quest    └─ Example: Dungeon
   rewards             rewards

Tier 4: Epic              Tier 5: Artifact ← ARTIFACTS HERE
├─ Max: 15 levels       ├─ Max: 15 levels
├─ Cost: Tokens         ├─ Cost: Essence (unique!)
├─ Stats: 1.15x base    ├─ Stats: 1.25x base
├─ Use: Mythic gear     ├─ Use: Legendary items
└─ Example: Mythic+     └─ Example: World loot
   dungeon drops           + Heirloom scaling

PROGRESSION PATH:
New Player → Tier 1 → Tier 2 → Tier 3 → Tier 4 → Tier 5 Artifacts
(Level 1-10) (10-30)  (30-60)  (60-100) (100+)  (Long-term goal)

UNIQUE ASPECTS OF TIER 5 ARTIFACTS:
✓ Loot-based (not purchased)
✓ Heirloom scaling (auto-level)
✓ Essence economy (different currency)
✓ Set bonuses (future feature)
✓ Unique effects (future feature)
✓ Account recognition (cosmetic title?)
```

---

## 🔧 COMPONENT INTERACTION DIAGRAM

```
                    CORE SYSTEMS INTEGRATION

┌─────────────────────────────────────────────────────────────┐
│                    Player Equips Artifact                   │
└────────────────────────┬────────────────────────────────────┘
                         │
                ┌────────┴────────┐
                │                 │
                v                 v
    ┌─────────────────┐   ┌──────────────────┐
    │ Heirloom System │   │ ItemUpgrade Mgr  │
    │ (heirloom_     │   │ (ItemUpgradeAddon│
    │  scaling_255)   │   │  Handler.cpp)    │
    │                 │   │                  │
    ├─ ScalingStats   │   ├─ Check upgrade   │
    ├─ Recalculate    │   │  level           │
    │  per level      │   ├─ Get enchant ID  │
    └────────┬────────┘   └────────┬─────────┘
             │                     │
             ├─────────┬───────────┤
             │         │           │
             v         v           v
        PRIMARY    SECONDARY   PROGRESSION
        STATS      STATS       SYSTEM
        ├─STR      ├─CRIT      ├─Essence
        ├─AGI      ├─HASTE     │  currency
        ├─STA      ├─HIT       ├─Tier 5 only
        ├─INT      ├─DEFENSE   ├─Max level 15
        └─SPI      └─ARMOR     └─DB-driven
             │         │           │
             └─────────┴───────────┘
                       │
                       v
        ┌──────────────────────────┐
        │ Apply Enchant to Item    │
        │ (TEMP_ENCHANTMENT_SLOT)  │
        │                          │
        ├─ Enchant ID: 300003+level │
        ├─ Query spell_bonus_data  │
        └─ Apply multiplier        │
                       │
                       v
        ┌──────────────────────────┐
        │ Final Stat Calculation   │
        │                          │
        │ Result = Base × Heirloom │
        │          × Enchant       │
        │          × Item Bonuses  │
        │          × Buffs/Debuffs │
        └──────────────────────────┘
                       │
                       v
        ┌──────────────────────────┐
        │ Display to Client        │
        │                          │
        ├─ Weapon Damage          │
        ├─ Secondary Stats        │
        ├─ Armor Class            │
        └─ Green Bonus Text       │
        └──────────────────────────┘
```

---

## ✅ VALIDATION FLOWCHART

```
ARTIFACT SYSTEM VALIDATION CHECKLIST

START
  │
  ├─→ Database Loaded?
  │   └─→ NO: Create tables (Phase 1)
  │   └─→ YES: Continue
  │       │
  │       ├─→ Artifacts Found?
  │       │   └─→ NO: Insert sample data
  │       │   └─→ YES: Continue
  │       │       │
  │       │       ├─→ Essence Item Exists?
  │       │       │   └─→ NO: Create item 200001
  │       │       │   └─→ YES: Continue
  │       │       │       │
  │       │       │       ├─→ Item Template Correct?
  │       │       │       │   └─→ NO: Fix flags/quality
  │       │       │       │   └─→ YES: Continue
  │       │       │       │       │
  │       │       │       │       └─→ READY FOR COMPILATION
  │
  ├─→ C++ Code Compiles?
  │   └─→ NO: Fix syntax errors
  │   └─→ YES: Continue
  │       │
  │       ├─→ Scripts Load?
  │       │   └─→ NO: Check script manager
  │       │   └─→ YES: Continue
  │       │       │
  │       │       ├─→ Artifact Data Loads?
  │       │       │   └─→ NO: Check database connection
  │       │       │   └─→ YES: Continue
  │       │       │       │
  │       │       │       └─→ READY FOR TESTING
  │
  ├─→ Loot Item Pickup?
  │   └─→ NO: Check gameobject setup
  │   └─→ YES: Continue
  │       │
  │       ├─→ Stats Scale on Equip?
  │       │   └─→ NO: Check heirloom flags
  │       │   └─→ YES: Continue
  │       │       │
  │       │       ├─→ Enchant Applied on Upgrade?
  │       │       │   └─→ NO: Check ApplyEnchantment hook
  │       │       │   └─→ YES: Continue
  │       │       │       │
  │       │       │       ├─→ Secondary Stats Buffed?
  │       │       │       │   └─→ NO: Check spell_bonus_data
  │       │       │       │   └─→ YES: Continue
  │       │       │       │       │
  │       │       │       │       └─→ READY FOR LAUNCH
  │
  └─→ END (SYSTEM OPERATIONAL)
```

---

## 📊 PERFORMANCE IMPACT ESTIMATE

```
ARTIFACT SYSTEM PERFORMANCE OVERHEAD

Event Frequency     CPU Impact          Memory Impact
─────────────────────────────────────────────────────

Equip/Unequip    1-2 per session     +50-100μs          +200 bytes
  (Player)       Low frequency       (negligible)       (per artifact)

Level Up         1 per level         +50μs              No change
  (Auto scaling)  Moderate freq      (heirloom system   (already
                                      already paid for)  counted)

Upgrade          ~1 per session      +100μs             +500 bytes
  (Player)       Very low            (DB update +       (tracking)
                 frequency           enchant apply)     

Login/Logout     1 per session       +50μs              +1000 bytes
  (Progress      Low frequency       (DB query)         (per player)
   restore)

Spell Bonus      Every stat calc     +10μs              No change
  Lookup (Enc)   Frequent            (hash table lookup)


TOTAL OVERHEAD PER ARTIFACT ITEM:
├─ CPU: <200μs per major event (negligible, <0.001%)
├─ Memory: ~1.7KB per artifact tracked
└─ Database: 1-2 queries per session per artifact

SCALE TEST (1000 players, 5 artifacts each):
├─ Memory: ~8.5 MB (tiny)
├─ CPU overhead: <1% during equip events
└─ Database: Scales linearly (well-indexed)

CONCLUSION: ✅ Performance impact is negligible
```

---

**These diagrams provide complete visual understanding of the artifact system architecture, data flow, and integration points.**

