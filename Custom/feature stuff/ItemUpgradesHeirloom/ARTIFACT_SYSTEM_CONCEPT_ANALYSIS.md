# 🎭 Artifact System - Comprehensive Concept & Implementation Analysis
**Date:** November 16, 2025  
**Author:** System Design Document  
**Reference:** Project Ascension Wiki, AzerothCore ItemUpgrade System, Heirloom Scaling v255

---

## 📋 EXECUTIVE SUMMARY

You want to create a **hybrid artifact system** combining:
1. **Loot-based acquisition** (gameobject placements in world)
2. **Heirloom mechanics** (primary stats scale with player level via heirloom system)
3. **Essence-based upgrades** (secondary stats + special effects upgraded via essence currency)
4. **Dynamic stat modification** (enchantments + custom effects)

### ✅ **FEASIBILITY: HIGHLY POSSIBLE**

The AzerothCore infrastructure already supports all required mechanics. You can combine:
- **Heirloom Scaling** (primary stats auto-level with player)
- **ItemUpgrade System** (essence-based tier progression)
- **Enchantment System** (dynamic secondary stat modification via TEMP_ENCHANTMENT_SLOT)
- **Custom Scripts** (artifact-specific logic)

---

## 🏗️ SYSTEM ARCHITECTURE

### **Three-Tier Integration Model**

```
┌─────────────────────────────────────────────────────────────┐
│                    ARTIFACT ITEM INSTANCES                  │
│                  (World Loot + Equipped Items)              │
└──────────────────┬──────────────────────────────────────────┘
                   │
        ┌──────────┴──────────┬──────────────┐
        │                     │              │
   ┌────▼─────┐    ┌─────────▼────┐    ┌────▼────────┐
   │  LAYER 1  │    │   LAYER 2    │    │   LAYER 3   │
   │ HEIRLOOM  │    │  ENCHANTMENT │    │  ESSENCES   │
   │  SCALING  │    │   APPLICATION│    │  UPGRADES   │
   └────┬─────┘    └──────┬───────┘    └─────┬───────┘
        │                  │                   │
        │                  │                   │
  PRIMARY STATS:      SECONDARY STATS:   PROGRESSION SYSTEM:
  ✓ Str/Agi/Sta      ✓ Crit Rating     ✓ Tier (1-5)
  ✓ Int/Spi          ✓ Haste Rating    ✓ Essence Costs
  ✓ Armor            ✓ Hit Rating      ✓ Stat Multipliers
  ✓ Health           ✓ Custom Effects  ✓ Max Level (15)
  ✓ Mana             ✓ Spell Power     ✓ Unique Bonuses
```

---

## 🎯 CORE MECHANICS BREAKDOWN

### **LAYER 1: HEIRLOOM PRIMARY STAT SCALING**

**How it works:**
- Use standard WoW heirloom quality (Quality 7)
- Flag item with `ScalingStatDistribution` (DBC-based scaling)
- Apply `heirloom_scaling_255.cpp` script to extend scaling to level 255

**Advantages:**
- ✅ Automatic player-level scaling (no manual upgrades for primary stats)
- ✅ Base damage/armor/attributes grow naturally
- ✅ Works across all player levels automatically
- ✅ Tried and tested in your codebase

**Implementation:**
```
Database:
  - Set item Quality = 7 (HEIRLOOM)
  - Set item ScalingStatDistribution = <DBC ID>
  - Set item Flags = 134221824 (heirloom flag)

Script:
  - heirloom_scaling_255.cpp handles level-based scaling
  - Applies up to 4x multiplier at level 255 (configurable)
```

**Primary Stats Affected:**
- Strength → Physical damage, block value
- Agility → Dodge, crit, armor (leather users)
- Stamina → Health pool
- Intellect → Mana, spell power
- Spirit → Mana regeneration

---

### **LAYER 2: ENCHANTMENT-BASED SECONDARY STAT UPGRADES**

**How it works:**
- When artifact is equipped, apply dynamic enchant via `TEMP_ENCHANTMENT_SLOT`
- Enchant ID encodes: tier + upgrade level (e.g., 80000 + tier*100 + level)
- `spell_bonus_data` table configures multipliers for all stat types
- Enchant applies percentage-based bonuses to:
  - Crit Rating
  - Haste Rating
  - Hit Rating
  - Spell Power
  - Defense/Resistance
  - Dodge/Parry/Block
  - And all other derived attributes

**How Enchantment Bonus Works:**
```
Enchant ID Scheme:
  Base: 80000
  Formula: 80000 + (tier_id × 100) + upgrade_level
  
  Examples:
    Tier 1, Level 6 → ID 80106
    Tier 2, Level 15 → ID 80215
    Tier 5, Level 15 → ID 80515

Stat Bonus Application:
  spell_bonus_data.direct_bonus = multiplier value
  Example: 0.20 = +20% all stats
  
  When applied:
    - Crit Rating: base × (1 + 0.20) = +20%
    - Haste Rating: base × (1 + 0.20) = +20%
    - Hit Rating: base × (1 + 0.20) = +20%
    - Damage: calculated from AP which is also multiplied
```

**Advantage:**
- ✅ Dynamically applied/removed with enchant
- ✅ Client displays correctly (shows green bonus text)
- ✅ Works with all stat types automatically
- ✅ Can be configured per tier/level combination
- ✅ Integrates with existing AzerothCore enchantment system

---

### **LAYER 3: ESSENCE-BASED UPGRADE PROGRESSION**

**How it works:**
- Use existing `ItemUpgrade` system (already in your codebase)
- Artifacts are **Tier 5** items (highest tier)
- Upgrades require essence currency (not tokens, exclusive to artifacts)
- Each upgrade level (0-15) increases:
  - Secondary stat multiplier
  - Special effects/bonuses
  - Unlock cosmetic variants (optional)

**Cost Structure:**
```
Tier 5 (Artifacts) - Essence-Based Progression

Level 1→2:  500 essence
Level 2→3:  750 essence
Level 3→4:  1000 essence
Level 4→5:  1250 essence
Level 5→6:  1500 essence
Level 6→7:  1750 essence
Level 7→8:  2000 essence
Level 8→9:  2250 essence
Level 9→10: 2500 essence
Level 10→11: 2750 essence
Level 11→12: 3000 essence
Level 12→13: 3250 essence
Level 13→14: 3500 essence
Level 14→15: 3750 essence

Total to Max: 30,250 essence
```

**Stat Multiplier Progression:**
```
Level 0 (Base):  1.0x (100% original stats)
Level 5:         1.25x (125% = +25% bonus)
Level 10:        1.50x (150% = +50% bonus)
Level 15 (Max):  1.75x (175% = +75% bonus)

Per-level: +2.5% bonus per upgrade
```

---

## 🎒 ARTIFACT ITEM VARIANTS

### **TYPE 1: WORLDFORGED WEAPONS** (Artifact + Heirloom Hybrid)

**Item Configuration:**
- Base: Weapon (sword, axe, mace, staff, etc.)
- Quality: 7 (Heirloom)
- Scaling: Heirloom scaling active
- Flag: Artifact-specific custom flag (new)
- Binding: Bind on Pickup (unique to player)

**Stat Progression:**
```
EQUIPPED EFFECTS:
├─ Primary Stats (Auto-scaling with level via Heirloom system)
│  └─ Scales 1x to 4x from level 1 to 255
├─ Secondary Stats (Enchantment-based)
│  └─ Base 1.0x, upgradeable to 1.75x via essence
└─ Special Effects (Custom scripts)
   └─ Proc-based abilities, damage bonuses, etc.
```

**Loot Method:**
- Place as gameobject in world dungeons/raids
- Player interacts with object → loot dialog
- Item placed in inventory at full stats for player level
- Starting upgrade level: 0 (unupgraded)

**Implementation:**
```sql
-- Artifact Weapon: "Worldforged Claymore"
INSERT INTO item_template VALUES (
  191001,           -- entry
  2,                -- class (WEAPON)
  13,               -- subclass (SWORD 2H)
  -1,               -- name_desc_id
  "Worldforged Claymore",  -- name
  79000,            -- display_id
  7,                -- quality (HEIRLOOM)
  1024,             -- flags (UNIQUE + BIND_ON_PICKUP)
  0,                -- buy_price
  0,                -- sell_price
  45,               -- inv_type (WEAPON)
  0,                -- required_level (0 = scale-based)
  0,                -- required_skill
  0,                -- required_skill_rank
  0,                -- required_spell
  0,                -- required_honor_rank
  0,                -- required_city_rank
  0,                -- required_pvp_medal
  1,                -- item_level
  34,               -- stat_type1 (ITEM_MOD_MANA)
  250,              -- stat_value1
  0,                -- stat_type2
  0,                -- stat_value2
  0,                -- stat_type3
  0,                -- stat_value3
  0,                -- stat_type4
  0,                -- stat_value4
  0,                -- stat_type5
  0,                -- stat_value5
  0,                -- stat_type6
  0,                -- stat_value6
  0,                -- stat_type7
  0,                -- stat_value7
  0,                -- stat_type8
  0,                -- stat_value8
  0,                -- stat_type9
  0,                -- stat_value9
  0,                -- stat_type10
  0,                -- stat_value10
  0,                -- resist0
  0,                -- resist1
  0,                -- resist2
  0,                -- resist3
  0,                -- resist4
  0,                -- resist5
  0,                -- resist6
  0,                -- damage_type
  0,                -- damage_min
  0,                -- damage_max
  0,                -- armor
  0,                -- holy_res
  64,               -- fire_res
  64,               -- nature_res
  64,               -- frost_res
  64,               -- shadow_res
  64,               -- arcane_res
  0,                -- gem_socket_color1
  0,                -- gem_socket_color2
  0,                -- gem_socket_color3
  0,                -- socket_bonus
  298,              -- scaling_stat_distribution (heirloom scaling ID)
  0,                -- random_property
  0,                -- random_suffix
  0,                -- item_set
  0,                -- durability
  0,                -- conjured
  0,                -- material
  0,                -- sheath_type
  0,                -- random_type
  0,                -- holiday_id
  0,                -- item_level_req
  0,                -- class_mask
  0,                -- subclass_mask
  0,                -- min_monstertarget_level
  0,                -- max_monstertarget_level
  0,                -- container_slots
  0,                -- extra_flags
  0,                -- other_team_entry
  NULL,             -- tooltip
  134221824         -- flags (heirloom flags)
);
```

---

### **TYPE 2: ARTIFACT SHIRT** (Starting Item)

**Item Configuration:**
- Base: Shirt (cosmetic slot, no combat stats)
- Quality: 7 (Heirloom)
- Special: Given at character creation (not looted)
- Binding: Bind on Account (shared across characters)

**Purpose:**
- Provides unique cosmetic appearance
- Can have custom enchant effects (buffs, visual effects)
- Scales with heirloom system
- Upgradeable via essence (for special effects)

**Implementation:**
```sql
-- Artifact Shirt: "Worldforged Tunic"
INSERT INTO item_template (
  entry, class, subclass, display_id, name, quality, 
  flags, inv_type, stat_type1, stat_value1, 
  scaling_stat_distribution, holiday_id, extra_flags
) VALUES (
  191002,          -- unique ID
  4,               -- class (ARMOR)
  2,               -- subclass (SHIRT)
  123456,          -- display_id (custom model)
  "Worldforged Tunic",
  7,               -- quality (HEIRLOOM)
  1,               -- flags (BIND_ON_ACCOUNT)
  4,               -- inv_type (SHIRT)
  5,               -- stat_type1 (ALL_STATS maybe)
  10,              -- base stat value
  298,             -- scaling_stat_distribution
  0,
  134221824        -- heirloom flags
);
```

**Use Case:**
- Can wear multiple artifact items simultaneously
- Shirt provides bonus effects when worn with weapon
- Hidden cosmetic benefits (transparency, visual aura, etc.)

---

### **TYPE 3: ARTIFACT BAG** (Heirloom Container)

**Item Configuration:**
- Base: Container (bag)
- Quality: 7 (Heirloom)
- Special: Scales slot count based on player level
- Starting: 12 slots (level 1), scaling to 36 slots (level 130+)

**How it works:**
- `heirloom_scaling_255.cpp` has built-in bag scaling
- Triggered in `OnPlayerEquip` hook
- Dynamically adjusts `CONTAINER_FIELD_NUM_SLOTS`

**Implementation:**
- Already in `heirloom_scaling_255.cpp` lines 149-191
- Just create a heirloom bag with `Quality = 7`
- Script automatically scales it based on player level

**Code Reference (Already Exists):**
```cpp
// From heirloom_scaling_255.cpp
void OnPlayerEquip(Player* player, Item* item, ...)
{
    // ... heirloom bag scaling ...
    const uint32 MIN_SLOTS = 12;
    const uint32 MAX_SLOTS = 36;
    const uint32 MAX_SCALE_LEVEL = 130;
    
    // Calculate and apply scaled slots
    if (playerLevel >= MAX_SCALE_LEVEL)
        scaledSlots = MAX_SLOTS;
    else
        scaledSlots = MIN_SLOTS + (level - 1) * (36 - 12) / 129;
    
    bag->SetUInt32Value(CONTAINER_FIELD_NUM_SLOTS, scaledSlots);
}
```

---

## 🔄 COMBINED SYSTEM FLOW

### **Player Loots Artifact Weapon**

```
1. Player interacts with gameobject in dungeon
   └─ Receives: Worldforged Claymore (item 191001)
   └─ Starting upgrade level: 0
   └─ Item stats scaled to player level via heirloom system
   └─ No enchant applied yet (upgrade level 0 = no secondary bonus)

2. Player equips Worldforged Claymore
   └─ Heirloom system activates:
      - Primary stats scaled: Str/Agi/Sta/etc. calculated for player level
   └─ No enchant yet (upgrade level 0)
   └─ Item appears in character screen with base stats

3. Player upgrades weapon in UI (.dcupgrade perform command)
   └─ Cost: 500 essence (level 0→1)
   └─ Upgrade successful:
      - upgrade_level = 1
      - stat_multiplier = 1.025 (2.5% bonus)
      - Enchant ID 80105 applied (Tier 5, Level 1)

4. Enchant Applied (TEMP_ENCHANTMENT_SLOT)
   └─ spell_bonus_data[80105] = { direct_bonus: 0.025, ... }
   └─ All secondary stats increased by 2.5%:
      - Crit Rating +2.5%
      - Haste Rating +2.5%
      - Hit Rating +2.5%
      - Defense +2.5%
      - Armor +2.5%
   └─ Client shows green bonus text in tooltip

5. Player levels up to 100
   └─ Heirloom system updates primary stats automatically:
      - Strength: recalculated for level 100
      - Stamina: recalculated for level 100
      - All primary attributes updated
   └─ Enchant still applied (upgrade level 1):
      - Secondary stats still +2.5%
      - No re-application needed

6. Player upgrades to level 15
   └─ Cost: 30,250 essence total (all levels)
   └─ Upgrade successful:
      - upgrade_level = 15
      - stat_multiplier = 1.75 (+75%)
      - Enchant ID 80515 applied
   └─ All secondary stats now +75%
   └─ Weapon fully optimized
```

---

## 💾 DATABASE SCHEMA ADDITIONS

### **New Table: `artifact_items`**

```sql
CREATE TABLE `artifact_items` (
  `artifact_id` INT UNSIGNED NOT NULL,
  `item_template_id` INT UNSIGNED NOT NULL,
  `artifact_type` ENUM('WEAPON', 'SHIRT', 'BAG') NOT NULL,
  `artifact_name` VARCHAR(255) NOT NULL,
  `lore_description` TEXT,
  `special_effect` VARCHAR(255) COMMENT 'Custom effect when fully upgraded',
  `essence_type` INT UNSIGNED DEFAULT 1 COMMENT 'Essence item ID required',
  `essence_cost_per_level` INT UNSIGNED DEFAULT 500,
  `max_upgrade_level` TINYINT DEFAULT 15,
  `tier_id` TINYINT DEFAULT 5 COMMENT 'Always 5 for artifacts',
  `required_quest_id` INT UNSIGNED COMMENT 'Quest to unlock artifact (optional)',
  `cosmetic_display_upgrade` TINYINT DEFAULT 0 COMMENT 'Show visual upgrade at max level',
  `is_active` TINYINT(1) DEFAULT 1,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`artifact_id`),
  UNIQUE KEY `idx_item_template` (`item_template_id`),
  KEY `idx_artifact_type` (`artifact_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### **New Table: `artifact_loot_locations`**

```sql
CREATE TABLE `artifact_loot_locations` (
  `location_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `artifact_id` INT UNSIGNED NOT NULL,
  `map_id` INT UNSIGNED NOT NULL,
  `x` FLOAT NOT NULL,
  `y` FLOAT NOT NULL,
  `z` FLOAT NOT NULL,
  `o` FLOAT NOT NULL DEFAULT 0,
  `gameobject_entry` INT UNSIGNED COMMENT 'Chest/loot object in world',
  `respawn_time` INT UNSIGNED DEFAULT 3600,
  `description` VARCHAR(255),
  `enabled` TINYINT(1) DEFAULT 1,
  PRIMARY KEY (`location_id`),
  KEY `idx_artifact` (`artifact_id`),
  KEY `idx_map` (`map_id`),
  FOREIGN KEY (`artifact_id`) REFERENCES `artifact_items` (`artifact_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### **New Table: `player_artifact_data`**

```sql
CREATE TABLE `player_artifact_data` (
  `player_guid` INT UNSIGNED NOT NULL,
  `artifact_id` INT UNSIGNED NOT NULL,
  `item_guid` INT UNSIGNED,
  `upgrade_level` TINYINT DEFAULT 0,
  `essence_invested` INT UNSIGNED DEFAULT 0,
  `acquired_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `last_upgraded` TIMESTAMP NULL,
  `currently_equipped` TINYINT(1) DEFAULT 0,
  PRIMARY KEY (`player_guid`, `artifact_id`),
  KEY `idx_item` (`item_guid`),
  FOREIGN KEY (`artifact_id`) REFERENCES `artifact_items` (`artifact_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### **Integration with Existing `dc_item_upgrade_costs`**

```sql
-- Add Tier 5 (Artifacts) with essence costs
INSERT INTO `dc_item_upgrade_costs` 
  (`tier_id`, `upgrade_level`, `token_cost`, `essence_cost`, `gold_cost`) 
VALUES
(5, 1, 0, 500, 0),     -- Artifacts use essence only, no tokens
(5, 2, 0, 750, 0),
(5, 3, 0, 1000, 0),
(5, 4, 0, 1250, 0),
(5, 5, 0, 1500, 0),
(5, 6, 0, 1750, 0),
(5, 7, 0, 2000, 0),
(5, 8, 0, 2250, 0),
(5, 9, 0, 2500, 0),
(5, 10, 0, 2750, 0),
(5, 11, 0, 3000, 0),
(5, 12, 0, 3250, 0),
(5, 13, 0, 3500, 0),
(5, 14, 0, 3750, 0),
(5, 15, 0, 4000, 0);
```

---

## 🎮 IMPLEMENTATION STRATEGY

### **PHASE 1: Database Setup** (2-3 hours)
1. Create `artifact_items` table
2. Create `artifact_loot_locations` table  
3. Create `player_artifact_data` table
4. Add Tier 5 entries to `dc_item_upgrade_costs`
5. Create sample artifact items (weapon, shirt, bag)
6. Configure essence costs and stat multipliers

### **PHASE 2: C++ Script Implementation** (4-6 hours)
1. Create `ArtifactSystem.cpp` script handler
   - Check artifact on equip
   - Apply enchant if upgraded
   - Handle upgrade requests
   - Track essence costs

2. Modify `ItemUpgradeAddonHandler.cpp`
   - Add artifact-specific upgrade logic
   - Validate essence currency instead of tokens
   - Apply/remove enchants on upgrade

3. Create `ArtifactLootScript.cpp`
   - Gameobject script for loot activation
   - Grant items to player at appropriate level
   - Initialize upgrade tracking

4. Extend `heirloom_scaling_255.cpp` (if needed)
   - Already handles heirloom scaling
   - No changes needed for basic functionality

### **PHASE 3: Addon UI Updates** (2-3 hours)
1. Update `DC-ItemUpgrade` addon display
   - Show artifact vs regular items differently
   - Display essence costs instead of tokens
   - Show tier 5 specific UI

2. Create artifact-specific tooltip
   - Display lore text
   - Show upgrade progression
   - Estimate total cost to max

### **PHASE 4: Gameplay Configuration** (1-2 hours)
1. Place artifacts in world as gameobjects
2. Configure respawn timers
3. Set up essence currency item
4. Create quest triggers (optional)
5. Test loot acquisition and upgrades

### **PHASE 5: Testing & Balancing** (Ongoing)
1. Test heirloom scaling with artifact weapons
2. Verify enchant application on upgrade
3. Check secondary stat application
4. Test level-up scaling
5. Verify essence cost progression
6. Balance stat multipliers for PvP/PvE

---

## ✅ FEASIBILITY ASSESSMENT

### **What Works Out of the Box:**
- ✅ Heirloom scaling (already implemented in `heirloom_scaling_255.cpp`)
- ✅ Enchantment system (ItemUpgrade system uses TEMP_ENCHANTMENT_SLOT)
- ✅ Secondary stat application (spell_bonus_data system)
- ✅ Tier-based progression (ItemUpgrade Tier 5 exists)
- ✅ Cost calculations (database-driven)
- ✅ Stat multipliers (StatScalingCalculator in place)

### **What Needs Custom Implementation:**
- ⚠️ Artifact-specific UI/addon display
- ⚠️ Loot gameobject integration
- ⚠️ Essence currency handling (different from tokens)
- ⚠️ Artifact initialization on character load
- ⚠️ Lore/flavor system (optional but recommended)

### **Potential Issues & Solutions:**

| Issue | Solution |
|-------|----------|
| Essence currency tracking | Create `player_currency` table entry for essence |
| Item pickup level scaling | Use item context to apply heirloom scaling on spawn |
| Enchant persistence on level-up | Store enchant ID in upgrade tracking, reapply on login |
| Multiple artifact weapons conflict | Track each artifact independently with GUID |
| Bag scaling conflicts | Priority: Artifact bag > regular heirloom bag |
| Cosmetic display on upgrade | Add model ID progression per upgrade level |

---

## 🎯 NEXT STEPS RECOMMENDATION

### **Priority Order:**
1. **Start with Weapon Artifacts** (most valuable, clear progression)
2. **Add Shirt (cosmetic)** (easier, less critical)
3. **Add Bag (utility)** (quality of life improvement)

### **Recommended First Artifact:**
- Create **"Worldforged Claymore"** as proof-of-concept
- Make it loot-able from a test location
- Fully implement tier 5 upgrade path
- Use as template for additional artifacts

### **Configuration Suggestions:**
- Starting item level: 50 (scales to ~1000 at level 255)
- Essence cost: 500-4000 per level (30k total to max)
- Stat bonus: 1.0x → 1.75x (+75% at max)
- Unique effect: +10% damage, +5% movement speed (example)

---

## 🔗 KEY FILES TO MODIFY/CREATE

| File | Action | Purpose |
|------|--------|---------|
| `src/server/scripts/DC/ArtifactSystem.cpp` | **CREATE** | Core artifact logic |
| `src/server/scripts/DC/ArtifactLoot.cpp` | **CREATE** | Gameobject loot script |
| `src/server/scripts/DC/ItemUpgrades/ItemUpgradeAddonHandler.cpp` | **MODIFY** | Add essence support |
| `Custom/Custom feature SQLs/artifacts_schema.sql` | **CREATE** | New tables |
| `Custom/Custom feature SQLs/artifacts_data.sql` | **CREATE** | Sample data |
| `Custom/Client addons needed/DC-ItemUpgrade/*.lua` | **MODIFY** | UI updates |
| `heirloom_scaling_255.cpp` | **NO CHANGE** | Already complete |

---

## 💡 ADVANCED FEATURES (Future)

### **Optional Enhancements:**
1. **Transmog System** - Collect alternate appearances for artifacts
2. **Affixes** - Random bonuses per artifact (like D3 items)
3. **Prestige Path** - Fully upgrade multiple copies for cosmetics
4. **Set Bonuses** - Equip multiple artifacts for special effects
5. **Artifact Quests** - Story-driven upgrade requirements
6. **PvP Ranks** - Different stats for PvP vs PvE
7. **Blessing System** - Temporary stat boosts (weekly)
8. **Legacy Stats** - Account-bound upgrade bonuses

---

## 📊 COMPARISON: HYBRID VS PURE SYSTEMS

### **Your Hybrid Approach:**
```
ARTIFACT WEAPON:
├─ Primary Stats:      HEIRLOOM SCALING (auto-level with player)
├─ Secondary Stats:    ENCHANTMENT-BASED (+2.5% per upgrade level)
├─ Progression:        ESSENCE TIERS (0-15 levels, 30k essence max)
├─ Scaling Formula:    1.0x to 1.75x multiplier
└─ Player Experience:  "Powerful item that grows with me"
```

### **vs Pure ItemUpgrade:**
```
TIER 5 ITEM (standard):
├─ All Stats:          TOKEN-BASED UPGRADES (manual each level)
├─ Scaling Formula:    1.0x to 1.75x multiplier
└─ Player Experience:  "Grindy, requires constant attention"
```

### **vs Pure Heirloom:**
```
HEIRLOOM ITEM (standard):
├─ All Stats:          AUTOMATIC SCALING (no upgrades)
├─ Max Multiplier:     1.5x (capped)
└─ Player Experience:  "Hands-off, but no progression"
```

**Your hybrid wins because:**
- ✅ Automatic level scaling (heirloom benefit)
- ✅ Engagement through upgrades (ItemUpgrade benefit)
- ✅ Essence-based currency encourages targeted farming
- ✅ Clear long-term goal (max upgrade level 15)
- ✅ Best of both systems!

---

## 🎨 COSMETIC CUSTOMIZATION

### **Visual Progression Ideas:**
```
Upgrade Level → Visual Changes
├─ Level 0-5:   Base appearance
├─ Level 6-10:  Glow effect (particle emitter)
├─ Level 11-14: Enhanced glow + Model variant
└─ Level 15:    Full transformation + Unique aura

Implementation:
  - Use item_enchantment_display_name for visual effects
  - Create alternate display IDs per tier
  - Add spell effects on equip (auras)
```

### **Unique Effects by Artifact:**
```
Worldforged Claymore:
  ├─ Lv1-5:   "Glowing Blade" (1.25x stat, +5% damage)
  ├─ Lv6-10:  "Burning Claymore" (1.50x stat, +10% damage, fire glow)
  ├─ Lv11-14: "Inferno Claymore" (1.65x stat, +15% damage, fire aura)
  └─ Lv15:    "Eternal Claymore" (1.75x stat, +20% damage, divine aura)

Worldforged Tunic:
  ├─ Lv1-5:   "Silk Shift" (1.25x defense, +5% defense)
  ├─ Lv6-10:  "Enchanted Tunic" (1.50x defense, +10% defense)
  ├─ Lv11-14: "Legendary Garb" (1.65x defense, +15% defense, shimmer)
  └─ Lv15:    "Divine Vestment" (1.75x defense, +20% defense, holy glow)

Worldforged Satchel:
  ├─ Lv1-5:   "Leather Satchel" (12-16 slots)
  ├─ Lv6-10:  "Enchanted Satchel" (18-24 slots)
  ├─ Lv11-14: "Legendary Pack" (28-32 slots)
  └─ Lv15:    "Infinite Pouch" (36 slots, visual expansion)
```

---

## 🚀 CONCLUSION

### **Can You Build This? YES, 100%**

Your existing infrastructure provides:
- ✅ Heirloom scaling for automatic primary stat growth
- ✅ Enchantment system for secondary stat bonuses
- ✅ ItemUpgrade framework for progression tracking
- ✅ Tier system ready for artifacts (Tier 5)
- ✅ Database schema flexibility for custom tables

### **Estimated Implementation Time:**
- Database setup: 2-3 hours
- C++ scripting: 4-6 hours
- Addon UI: 2-3 hours
- Configuration & testing: 3-5 hours
- **Total: 11-17 hours for full implementation**

### **Starting Point:**
Begin with a single artifact weapon (Worldforged Claymore) to validate the system, then expand to additional artifacts and features.

### **Key Success Factors:**
1. Leverage existing `ItemUpgrade` system for progression
2. Use `heirloom_scaling_255.cpp` for automatic scaling
3. Apply enchants dynamically via `TEMP_ENCHANTMENT_SLOT`
4. Track artifact state in custom database table
5. Create addon UI for artifact-specific display

**Ready to proceed with detailed implementation guide?**

