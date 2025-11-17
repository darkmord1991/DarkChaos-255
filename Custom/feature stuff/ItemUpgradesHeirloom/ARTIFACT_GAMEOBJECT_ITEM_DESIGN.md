# 🎁 ARTIFACT SYSTEM - GAMEOBJECT & ITEM DESIGN

**Level Range:** 1-30  
**Theme:** Azshara Crater  
**Client Version:** 3.3.5a Standard  
**Date:** November 16, 2025  

---

## 📋 EXECUTIVE SUMMARY

### **How Many Items & Treasures?**

**Recommended Loadout:**
- **12 treasure chest gameobjects** (spread across Azshara Crater)
- **18-24 unique artifact items** (to fill treasures + player slots)
- **3 primary artifact types** (Weapon, Shirt, Bag)
- **6-8 secondary artifacts** (cosmetic/utility)
- **Multiple variants** of each type (different themes/appearances)

**Why This Number?**
- 12 treasures = ~4 at each difficulty tier (Easy/Medium/Hard spawns)
- 18-24 items = Enough for collection without oversaturation
- Distributed across level range 1-30 = 2-3 items per 5 levels
- Multiple variants = Encourages exploration and collection

**Total Unique Assets Needed:**
- ✅ 12 gameobject spawn templates
- ✅ 18-24 item_template entries
- ✅ Loot table entries for chests
- ✅ 10-12 different display IDs (from 3.3.5a models)

---

## 🎮 RECOMMENDED ARTIFACT TYPES & DISTRIBUTION

### **PRIMARY ARTIFACTS (Progression - Must Have)**

**Tier 1: Weapon Artifacts (4 variants)**
```
1. Worldforged Claymore      (ID: 191001) - ⚔️ Sword, Level 1+
2. Worldforged Greataxe      (ID: 191011) - 🪓 Axe, Level 10+
3. Worldforged Bow           (ID: 191021) - 🏹 Bow, Level 5+
4. Worldforged Wand          (ID: 191031) - ✨ Caster, Level 8+

Distribution: 4 different chest types
Scaling: Heirloom 1-255, Upgradeable 0-15 via essence
Primary: Damage, Secondary: Stats scaling with enchants
```

**Tier 2: Off-Hand Artifacts (2 variants)**
```
1. Worldforged Shield        (ID: 191051) - 🛡️ Tank, Level 15+
2. Worldforged Orb           (ID: 191061) - 🔮 Caster Off, Level 12+

Distribution: 2 different chest types
Scaling: Heirloom 1-255
Purpose: Tank/caster off-hand progression
```

**Tier 3: Armor Artifacts (2 variants)**
```
1. Worldforged Tunic         (ID: 191002) - 👕 Shirt/Cosmetic
2. Worldforged Cloak         (ID: 191003) - 🧥 Back slot

Distribution: 2 separate chests
Purpose: Cosmetic + Small stat bonuses
Bind: Account-wide for alts
```

**Tier 4: Bag Artifact (1)**
```
1. Worldforged Satchel       (ID: 191004) - 💼 Container

Distribution: Special chest
Purpose: Scaling bag 12→36 slots by level
Note: Code already exists in heirloom_scaling_255.cpp
```

### **SECONDARY ARTIFACTS (Collection - Optional)**

**Cosmetic/Buff Items (6-8 variants)**
```
1. Worldforged Trinket       (ID: 191070) - Ring/Trinket slot
2. Worldforged Crown         (ID: 191080) - Cosmetic head piece
3. Worldforged Bracers       (ID: 191090) - Wrist slot
4. Worldforged Belt          (ID: 191100) - Waist slot
5. Worldforged Boots         (ID: 191110) - Feet slot
6. Worldforged Gloves        (ID: 191120) - Hands slot
7. Worldforged Leggings      (ID: 191130) - Legs slot
8. Worldforged Mantle        (ID: 191140) - Shoulder slot

Scaling: Cosmetic items (no stat scaling required)
Purpose: Transmog collection, account-wide rewards
Distribute: 1 per tier or grouped in special chests
```

---

## 🗺️ AZSHARA CRATER TREASURE DISTRIBUTION

### **Map Overview**
- Zone ID: 37 (Azshara Crater = Custom DarkChaos map)
- Existing Objects: Type 173197, 3705, 2850 already spawned
- Level Range: 1-30 suitable for exploring Azshara Crater
- Theme: Ancient ruins, elemental theme, abandoned structures

### **Suggested Spawn Locations (12 Treasures)**

**Easy Difficulty (Levels 1-10) - 4 Treasures**
```
Chest 1: "Ancient Ruin Chest" 
  Location: Starting area (low X, low Y - safe zone)
  Item: Worldforged Claymore (191001) - Level 1
  Display: Type 3, ID 1683 (small ornate chest)
  Respawn: 3600s (1 hour)

Chest 2: "Collapsed Merchant Chest"
  Location: East of starting (mid X, low Y)
  Item: Worldforged Bow (191021) - Level 5
  Display: Type 3, ID 75 (locked chest)
  Respawn: 3600s

Chest 3: "Forgotten Supplies"
  Location: North area (low X, mid Y)
  Item: Worldforged Tunic (191002) - Level 3
  Display: Type 3, ID 73 (wooden chest)
  Respawn: 3600s

Chest 4: "Sunken Cache"
  Location: River/water area (mid X, mid Y)
  Item: Worldforged Wand (191031) - Level 8
  Display: Type 3, ID 1697 (ornate chest)
  Respawn: 3600s
```

**Medium Difficulty (Levels 10-20) - 4 Treasures**
```
Chest 5: "Crystal Formation Cache"
  Location: East area (high X, low Y)
  Item: Worldforged Shield (191051) - Level 15
  Display: Type 3, ID 78 (captain's footlocker)
  Respawn: 5400s (1.5 hours)

Chest 6: "Ruined Temple Vault"
  Location: North-East (high X, mid Y)
  Item: Worldforged Cloak (191003) - Level 12
  Display: Type 3, ID 76 (old jug)
  Respawn: 5400s

Chest 7: "Elemental Deposit"
  Location: Central area (mid X, mid Y)
  Item: Worldforged Orb (191061) - Level 12
  Display: Type 3, ID 77 (broken barrel)
  Respawn: 5400s

Chest 8: "Ancient Sealed Container"
  Location: West area (low X, high Y)
  Item: Worldforged Greataxe (191011) - Level 10
  Display: Type 3, ID 2850 (fancy chest)
  Respawn: 5400s
```

**Hard Difficulty (Levels 20-30) - 4 Treasures**
```
Chest 9: "Draconic Hoard"
  Location: Far North (low X, high Y)
  Item: Worldforged Crown (191080) - Level 25
  Display: Type 3, ID 1691 (special ornate)
  Respawn: 7200s (2 hours)

Chest 10: "Titan's Remnant"
  Location: Far East (high X, high Y)
  Item: Worldforged Belt (191100) - Level 20
  Display: Type 3, ID 1692 (special ornate)
  Respawn: 7200s

Chest 11: "Satchel - Worldforged Satchel"
  Location: Central structure (mid X, high Y)
  Item: Worldforged Satchel (191004) - Level 25
  Display: Type 3, ID 1689 (unique chest)
  Respawn: 7200s

Chest 12: "Ultimate Vault"
  Location: Far South-East (high X, high Y)
  Item: Worldforged Trinket (191070) - Level 30
  Display: Type 3, ID 1690 (unique chest)
  Respawn: 7200s
```

**Spawn Coordinates Strategy:**
- Spread across 4 quadrants (NW, NE, SW, SE)
- Mix with existing spawns (173197, 3705, 2850)
- Average distance: 300-400 units apart
- Heights: Vary Z to match terrain
- Rotations: Random orientation (0-2π)

---

## 📊 COMPLETE ITEM MAPPING TABLE

### **Item IDs Reference (191000-191140)**

| ID | Item Name | Type | Level | Rarity | Binding | Notes |
|-----|-----------|------|-------|--------|---------|-------|
| **WEAPONS** | | | | | | |
| 191001 | Worldforged Claymore | Sword | 1 | Heirloom | BoP | Primary weapon, upgradeable |
| 191011 | Worldforged Greataxe | Polearm | 10 | Heirloom | BoP | DPS alt weapon |
| 191021 | Worldforged Bow | Bow | 5 | Heirloom | BoP | Ranged weapon |
| 191031 | Worldforged Wand | Wand | 8 | Heirloom | BoP | Caster weapon |
| **OFF-HAND** | | | | | | |
| 191051 | Worldforged Shield | Shield | 15 | Heirloom | BoP | Tank off-hand |
| 191061 | Worldforged Orb | Off-hand | 12 | Heirloom | BoP | Caster off-hand |
| **ARMOR** | | | | | | |
| 191002 | Worldforged Tunic | Shirt | 3 | Heirloom | Account | Cosmetic, +5% XP at max |
| 191003 | Worldforged Cloak | Back | 12 | Heirloom | Account | Cosmetic cloak |
| 191004 | Worldforged Satchel | Bag | 25 | Heirloom | BoP | 12→36 slots by level |
| **COSMETICS** | | | | | | |
| 191070 | Worldforged Trinket | Trinket | 5 | Heirloom | Account | Ring/trinket slot |
| 191080 | Worldforged Crown | Head | 25 | Heirloom | Account | Cosmetic crown |
| 191090 | Worldforged Bracers | Wrist | 15 | Heirloom | Account | Wrist cosmetic |
| 191100 | Worldforged Belt | Waist | 20 | Heirloom | Account | Belt cosmetic |
| 191110 | Worldforged Boots | Feet | 18 | Heirloom | Account | Boots cosmetic |
| 191120 | Worldforged Gloves | Hands | 15 | Heirloom | Account | Gloves cosmetic |
| 191130 | Worldforged Leggings | Legs | 20 | Heirloom | Account | Legs cosmetic |
| 191140 | Worldforged Mantle | Shoulder | 22 | Heirloom | Account | Shoulders cosmetic |

**Total Items: 18 (8 core + 10 cosmetic/utility)**

---

## 🎨 3.3.5a GAMEOBJECT DISPLAY IDS & MODELS

### **Available Chest Types (Type 3 - Container)**

| GO ID | Display | Model | Size | Theme | Best For |
|--------|---------|-------|------|-------|----------|
| 73 | 1683 | Small wooden | Small | Common | Easy tier |
| 75 | 1691 | Locked chest | Medium | Classic | Medium tier |
| 76 | 1692 | Ornate | Medium | Fancy | Mixed |
| 77 | 1689 | Barrel | Medium | Storage | Medium tier |
| 78 | 1690 | Footlocker | Medium | Military | Adventure |
| 1683 | Various | Sunken | Small | Water/Cave | Special |
| 1697 | Various | Ambassador | Large | Ornate | Hard tier |
| 2850 | Various | Stone | Medium | Ruins | Hard tier |

**3.3.5a Display ID Recommendations:**
```
Easy Zone (1-10):
- Display 1683: Small ornate chest (intimate, early game)
- Display 1691: Locked chest (classic feel)

Medium Zone (10-20):
- Display 1692: Ornate chest (mid-tier appearance)
- Display 1689: Barrel variations (storage theme)

Hard Zone (20-30):
- Display 1690: Fancy footlocker (adventure theme)
- Display 1697: Ambassador's chest (grand/special)
- Display 2850: Stone structures (ruins theme)
```

**No Newer Models Needed:**
- 3.3.5a has sufficient variety for level 1-30
- 7 different display types = good visual variety
- Mixing types = Prevents repetition
- **Recommendation: Use 3.3.5a models for now**

---

## 🗄️ DATABASE REQUIREMENTS

### **New Tables Needed (4)**

```sql
-- 1. artifact_items (main artifact definitions)
CREATE TABLE artifact_items (
    id INT PRIMARY KEY,
    item_id INT,
    artifact_type VARCHAR(50),
    artifact_name VARCHAR(255),
    description TEXT,
    tier_id INT,
    max_upgrade_level INT,
    essence_currency_id INT,
    is_active TINYINT
);

-- 2. artifact_loot_locations (chest spawns)
CREATE TABLE artifact_loot_locations (
    id INT PRIMARY KEY AUTO_INCREMENT,
    gameobject_template_id INT,
    map_id INT,
    zone_id INT,
    area_id INT,
    position_x FLOAT,
    position_y FLOAT,
    position_z FLOAT,
    orientation FLOAT,
    item_id INT,
    difficulty_tier VARCHAR(20),
    respawn_time INT,
    description VARCHAR(255)
);

-- 3. artifact_gameobject_templates (GO templates)
CREATE TABLE artifact_gameobject_templates (
    id INT PRIMARY KEY AUTO_INCREMENT,
    display_id INT,
    chest_model VARCHAR(100),
    size_scale FLOAT,
    interaction_type VARCHAR(50)
);

-- 4. artifact_chest_loot_table (loot definitions)
CREATE TABLE artifact_chest_loot_table (
    id INT PRIMARY KEY AUTO_INCREMENT,
    chest_id INT,
    item_id INT,
    item_count INT,
    chance_percent INT,
    min_level INT,
    max_level INT
);
```

### **Modified Tables (Update)**

```sql
-- 1. item_template - Create artifact items with heirloom flags
-- Add 18 new entries for artifact items (191001-191140)

-- 2. gameobject_template - Create treasure chest templates
-- Add 12 new entries for Azshara chests

-- 3. gameobject - Create chest instances in world
-- Add 12 spawn entries at Azshara Crater locations

-- 4. gameobject_loot_template - Link chests to items
-- Add 12 loot table entries (one per chest)
```

---

## 🎯 QUICK SETUP GUIDE

### **Step 1: Create Item Templates (SQL)**
```sql
-- Weapons
INSERT INTO item_template (entry, class, subclass, name, Quality, Flags, ItemLevel, ...) VALUES
(191001, 2, 10, 'Worldforged Claymore', 7, 64, 1, ...),
(191011, 2, 7, 'Worldforged Greataxe', 7, 64, 10, ...),
...
```

**Items Needed:**
- 4 Weapon items (claymore, axe, bow, wand)
- 2 Off-hand items (shield, orb)
- 2 Armor items (tunic, cloak, satchel - bag)
- 8 Cosmetic items (crown, bracers, belt, boots, gloves, legs, mantle, trinket)
= **18 total item entries**

### **Step 2: Create Gameobject Templates (SQL)**
```sql
-- 12 different treasure chest templates
INSERT INTO gameobject_template (entry, type, displayId, name, ...) VALUES
(291001, 3, 1683, 'Ancient Ruin Chest', ...),
(291002, 3, 1691, 'Merchant Chest', ...),
...
```

**Templates Needed:**
- 12 chest template entries
- Mix of display IDs (73, 75, 76, 77, 78, 1683, 1697, 2850)
- All type = 3 (container/chest)

### **Step 3: Create Loot Tables (SQL)**
```sql
-- Link chests to items
INSERT INTO gameobject_loot_template (entry, item, ChanceOrQuestChance, lootmode, ...) VALUES
(491001, 191001, 100, 1, ...),  -- Ancient Ruin Chest -> Worldforged Claymore
(491002, 191021, 100, 1, ...),  -- Merchant Chest -> Worldforged Bow
...
```

**Tables Needed:**
- 12 loot table entries (one per chest type)
- Most items = 100% drop rate
- Some cosmetics = 50% chance for variety

### **Step 4: Create World Spawns (SQL)**
```sql
-- Place chests in Azshara Crater world
INSERT INTO gameobject (guid, id, map, zoneId, areaId, posX, posY, posZ, orientation, ...) VALUES
(5531001, 291001, 37, 0, 0, 150.0, 850.0, 330.0, 1.57, ...),  -- Easy chest
(5531002, 291002, 37, 0, 0, 250.0, 950.0, 285.0, 3.14, ...),  -- Medium chest
...
```

**Spawns Needed:**
- 12 gameobject spawn entries
- Map = 37 (Azshara Crater)
- Zone/Area = 0 (custom)
- Spread locations across map quadrants

---

## 📐 SPAWN COORDINATE TEMPLATE

### **Azshara Crater Coordinate System**

**Quadrant Layout:**
```
     NW                    NE
     (Low,High)            (High,High)
     +-----------+-----------+
     |           |           |
     |   1,2,3   |   9,10    |
     |           |           |
     +-----------O-----------+
     |           |           |
     |   8,5,6   |   7,11,12 |
     |           |           |
     +-----------+-----------+
     (Low,Low)               (High,High)
     SW                      SE
```

**Recommended Coordinates (Example):**
```
Easy (NW):
- Chest 1: (100, 800, 330) - Starting
- Chest 2: (200, 900, 285) - East
- Chest 3: (150, 1000, 340) - North
- Chest 4: (250, 850, 280) - River

Medium (E):
- Chest 5: (450, 800, 320) - East area
- Chest 6: (500, 950, 290) - North-East
- Chest 7: (300, 950, 310) - Central
- Chest 8: (150, 1100, 300) - West

Hard (NE/SE):
- Chest 9: (200, 1150, 345) - Far North
- Chest 10: (600, 1100, 310) - Far East
- Chest 11: (350, 1150, 325) - Central North
- Chest 12: (550, 1150, 315) - Far South-East
```

**Z-Height Tips:**
- Starting zone: 280-340 (varied terrain)
- East area: 280-320 (slightly lower)
- North area: 300-350 (higher elevation)
- Mix variations to match Azshara Crater topology

---

## ⚙️ CONFIGURATION SUMMARY

### **How Many Treasures? ANSWER: 12**

**Reasoning:**
- 3 difficulty tiers × 4 chests each = 12 total
- Level 1-30 span = 10 levels per tier
- Provides good distribution without oversaturation
- Players find 1-2 chests per play session
- Encourages exploration of entire Azshara Crater

**Alternative Options:**
- **Minimal (6):** 2 per tier, less exploration → 2-3 hours playtime
- **Standard (12):** 4 per tier, good coverage → 5-8 hours playtime ⭐ RECOMMENDED
- **Maximum (18):** 6 per tier, treasure hunt → 8-12 hours playtime

### **How Many Items? ANSWER: 18 (core) + 8 (cosmetic) = 26 total**

**Breakdown:**
- **8 core progression items** (weapons/shields/bag/tunic)
  - 4 weapons (different playstyles)
  - 2 off-hands (tank/caster)
  - 2 armor (cosmetic/utility)
  
- **10 additional cosmetic items** (optional collection)
  - Crown, belt, boots, gloves, leggings, mantle, bracers, trinket
  - Account-wide bound for alt sharing
  - Progressive levels (5-30)

**Why 18-26?**
- Players can equip 2-4 artifacts simultaneously (weapon + shield/tunic + bag + cloak)
- Having 4+ weapon options encourages different playstyles
- Cosmetics add collection value (transmog, account sharing)
- Spreads discovery across entire 1-30 level range
- Some items can be in same chest (loot table chance system)

---

## 🎨 GAMEOBJECT DISPLAY STRATEGY

### **Why NOT Newer Models?**

**3.3.5a Models Are Sufficient:**
- ✅ 8+ unique chest display IDs available
- ✅ Different sizes (small to large)
- ✅ Different themes (ornate, military, ruins)
- ✅ Already in game files (no extraction needed)
- ✅ Perfectly compatible
- ✅ Maintains authentic 3.3.5a feel

**To Use Newer Models (TBC/Wrath/Cata) - See Optional Section Below**

### **Recommended Display Rotation**

```
Easy Chests (1-10):
  Chest 1-2: Display 1683 (small ornate)
  Chest 3-4: Display 1691 (locked chest)

Medium Chests (10-20):
  Chest 5-6: Display 1692 (ornate chest)
  Chest 7-8: Display 1689 (barrel)

Hard Chests (20-30):
  Chest 9-10: Display 1690 (footlocker)
  Chest 11-12: Display 1697/2850 (fancy)
```

**Visual Progression:**
- Early game: Familiar wooden chests
- Mid game: Ornate/military themes
- Late game: Grand/unique appearances
- Creates sense of progression through terrain

---

## 🔧 OPTIONAL: USING NEWER CLIENT MODELS

### **How to Add TBC/Wrath/Cata Models**

**Option 1: Extract from Latest WoW Client**
```powershell
# Requires: World of Warcraft game files (latest)
# 1. Download CascView tool
# 2. Open World of Warcraft casc_root folder
# 3. Navigate: World/model/Chest/
# 4. Export desired models (.mdx, .blp files)
# 5. Add to DarkChaos client model folders
# 6. Update displayid references in gameobject_template
```

**Option 2: Use Pre-Extracted Model Packs**
```
Wrath Chest Models:
- Display 1821: Grand Ornate Chest (fancy, Ulduar theme)
- Display 1822: Frozen Coffer (ice theme)
- Display 1823: Titan Vault (dwarf theme)

Cata Chest Models:
- Display 1901: Elemental Coffer (fire/water themed)
- Display 1902: Twilight Vault (shadow themed)
```

**Option 3: Mixed Approach (Recommended)**
```
Keep 3.3.5a models for:
- Easy tier (authentic starting experience)
- Already installed (zero setup)

Add select Wrath models for:
- Hard tier (better visual distinction)
- 2-3 special display IDs maximum

Installation:
1. Create: client_data/Models/TBC_Chests/
2. Add exported .mdx + .blp files
3. Update gameobject_template.sql with new displayid refs
4. Clients auto-download on login (if MPQ enabled)
```

**NOT RECOMMENDED:**
- ❌ Massive model extraction (performance impact)
- ❌ Mixing too many client versions (confusion)
- ❌ Unsupported models (causes crashes)

**RECOMMENDATION:** Use 3.3.5a models now. Can upgrade later if needed.

---

## 📝 IMPLEMENTATION CHECKLIST

### **Database Phase (1-2 hours)**

- [ ] Create 18 item_template entries (191001-191140)
- [ ] Create 12 gameobject_template entries (291001-291012)
- [ ] Create 12 loot_template entries (491001-491012)
- [ ] Create 12 gameobject spawn entries at Azshara Crater
- [ ] Test: Loot items from chests in-game
- [ ] Test: Items have heirloom flag + correct level requirements
- [ ] Test: Bag slot scaling (if bag implemented)

### **Item Configuration (30 min)**

- [ ] Set item class/subclass correctly for each type
- [ ] Assign display IDs (from game client)
- [ ] Set quality = 7 (HEIRLOOM) for all
- [ ] Set binding = BoP for weapons/bag, BoA for cosmetics
- [ ] Set armor/damage values appropriate to level
- [ ] Verify armor progression (1-30 level range)
- [ ] Verify weapon damage progression

### **Gameobject Configuration (1 hour)**

- [ ] Create 12 template entries with different display IDs
- [ ] Mix display IDs by difficulty tier
- [ ] Set spawntimesecs (3600/5400/7200 by tier)
- [ ] Verify locations don't overlap existing Azshara spawns
- [ ] Test: GOs visible in world at correct coordinates
- [ ] Test: Chests openable and contain items
- [ ] Test: Respawn timers work correctly

### **Artifact Integration (2-3 hours)**

- [ ] Tag items as artifacts in item_template (custom field)
- [ ] Update ItemUpgrade system to recognize artifact items
- [ ] Verify Tier 5 essence costs apply to artifacts
- [ ] Test: Upgrading artifact applies correct enchants
- [ ] Test: Heirloom scaling works on artifacts
- [ ] Test: Multiple artifacts can be equipped
- [ ] Update addon UI to display artifact info

### **Testing Phase (2-3 hours)**

- [ ] Level 1 character, find first chest
- [ ] Equip weapon, verify stats scale correctly
- [ ] Upgrade weapon, verify essence cost/enchant apply
- [ ] Level to 30, verify stats recalculate on each level
- [ ] Test all 12 chests respawn on timer
- [ ] Test item binding (BoP stays, BoA tradable)
- [ ] Balance essence costs based on playtesting
- [ ] Performance check (no lag from 12 chests)

### **Deployment (1 hour)**

- [ ] Final SQL review for errors
- [ ] Backup database before import
- [ ] Execute all SQL scripts
- [ ] Verify no SQL errors in logs
- [ ] Reload game server
- [ ] Test in world: chests spawn correctly
- [ ] Test in world: items lootable and equippable
- [ ] Announce to players (patch notes)

**Total Time: 6-10 hours (with comprehensive testing)**

---

## 💾 QUICK REFERENCE: ITEM ID RANGES

```
Artifact Weapons:  191001-191031  (4 items)
Artifact Off-hand: 191051-191061  (2 items)
Artifact Armor:    191002-191004  (3 items)
Artifact Cosmetic: 191070-191140  (8 items)
Essence Currency:  200001         (1 item)

Gameobject IDs:    291001-291012  (12 chests)
Loot Tables:       491001-491012  (12 tables)
```

---

## 📊 FINAL SUMMARY

| Aspect | Quantity | Distribution | Notes |
|--------|----------|--------------|-------|
| **Treasures** | 12 | 4 per tier | Spread across Azshara |
| **Artifact Items** | 18 | Level 1-30 | 8 core + 10 cosmetic |
| **Weapon Variants** | 4 | Level 1,5,8,10 | Different playstyles |
| **Off-Hand Options** | 2 | Level 12,15 | Tank & caster |
| **Armor Pieces** | 3 | Level 3,12,25 | Tunic + Cloak + Bag |
| **Cosmetics** | 8 | Level 5-30 | Crown, belt, boots, etc |
| **Display IDs** | 7-8 | 3.3.5a models | No new extraction needed |
| **Difficulty Tiers** | 3 | Easy/Med/Hard | Level progression |
| **Time to Implement** | 6-10 hrs | Database→Testing | Comprehensive setup |

---

## 🎮 EXPECTED PLAYER FLOW

```
Level 1: Finds Claymore in starting chest
         → Equips weapon, stats scale automatically
         → Begins collecting other artifacts as leveling

Level 5-10: Finds 3-4 more weapons/off-hand items
            → Collects cosmetics (crown, bracers)
            → Tests different playstyles

Level 10-20: Mid-tier chests open (harder to reach)
             → Collects shield or orb
             → Accumulates essence from kills
             → Starts upgrading first artifact

Level 20-30: Final chests in distant locations
             → Finds satchel bag (12→36 slots)
             → Finds rare cosmetics (crown, mantle)
             → Max upgrades artifact to level 15
             → Complete collection (18 items)

Post 30: Can still find chests on respawn
         → Farm essence for additional items
         → Hunt cosmetics for transmog
         → Share via BoA items to alts
```

---

## ✅ SUCCESS CRITERIA

System complete when:

- ✅ All 12 chests spawn in Azshara Crater
- ✅ 18 artifact items lootable from chests
- ✅ Items have heirloom flag + correct level scaling
- ✅ Weapons show correct damage values
- ✅ Armor shows correct armor values
- ✅ Items upgradeable via essence system
- ✅ Cosmetics shareable account-wide
- ✅ Chest respawn timers work correctly
- ✅ No duplicates or missing items
- ✅ UI displays artifact info correctly
- ✅ Performance acceptable (no lag)
- ✅ Gameplay feels rewarding for players

---

**Next Steps:**
1. Review item distribution (is 18 enough? too many?)
2. Confirm treasure locations work with Azshara map
3. Create SQL scripts for all items/treasures
4. Run Phase 1 database setup
5. Test in development environment

