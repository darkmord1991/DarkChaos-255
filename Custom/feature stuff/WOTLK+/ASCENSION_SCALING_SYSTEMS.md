# Ascension Scaling Systems Analysis

## Document Purpose
Analyze Ascension WoW's item versioning and world scaling systems for potential adaptation to Dark Chaos level 255 progression.

---

## 1. Ascension Scaling Overview

### What Makes Ascension Unique
Ascension WoW is a classless 3.3.5a server with extensive custom systems:
- **No fixed classes** - Pick any abilities from any class
- **Worldforged Items** - Scaling "heirloom-style" items
- **World Scaling** - Dynamic difficulty zones
- **Item Versions** - Multiple quality tiers per item
- **Mystic Enchants** - 3000+ custom enchantments

---

## 2. Ascension Item Version System

### 2.1 Item Quality Tiers

Ascension uses a **tiered item quality system** where items have multiple versions:

| Tier | Suffix | Stats Multiplier | Drop Source |
|------|--------|------------------|-------------|
| T0 | (Base) | 1.0x | Normal content |
| T1 | "Adventurer's" | 1.15x | Uncommon events |
| T2 | "Hero's" | 1.30x | Rare events |
| T3 | "Legendary" | 1.50x | Mythic content |
| T4 | "Worldforged" | Scales | Special drops |

### 2.2 How Item Versions Work

**Conceptual Database Structure:**
```sql
-- Base item template
item_template (entry = 50001):
  name = "Blade of the North"
  stat_value1 = 100  -- Strength
  stat_value2 = 50   -- Stamina
  
-- Tiered versions (computed or stored)
item_template_versions:
  item_id | tier | stat_multiplier | suffix
  50001   | 0    | 1.00            | NULL
  50001   | 1    | 1.15            | "Adventurer's"
  50001   | 2    | 1.30            | "Hero's"
  50001   | 3    | 1.50            | "Legendary"
```

**Display to Player:**
- Blade of the North (T0) = 100 STR, 50 STA
- Adventurer's Blade of the North (T1) = 115 STR, 58 STA
- Hero's Blade of the North (T2) = 130 STR, 65 STA
- Legendary Blade of the North (T3) = 150 STR, 75 STA

### 2.3 Dark Chaos Adaptation

**Already Implemented (3-Tier Upgrades):**
Dark Chaos already has a similar system in the item_upgrade module:

```sql
-- Existing Dark Chaos upgrade tiers
item_upgrade_tiers:
  tier | name        | stat_bonus | cost
  1    | "Enhanced"  | +10%       | 100 tokens
  2    | "Superior"  | +25%       | 500 tokens
  3    | "Mythic"    | +50%       | 2500 tokens
```

**Recommended Expansion:**
```sql
-- Extended tiers for 255 progression
ALTER TABLE item_upgrade_tiers ADD COLUMN min_level INT;

INSERT INTO item_upgrade_tiers VALUES
(4, "Epic",       0.75, 10000, 160),
(5, "Legendary",  1.00, 50000, 200),
(6, "Mythic+",    1.50, 250000, 240),
(7, "Godforged",  2.00, 1000000, 255);
```

---

## 3. Ascension Worldforged Item System

### 3.1 What are Worldforged Items?

Worldforged items are **heirloom-style equipment** that:
- Scale with player level
- Provide consistent relative power
- Never become obsolete
- Have special acquisition requirements

### 3.2 Worldforged Mechanics

**Scaling Formula (Estimated):**
```
ItemLevel = BaseILevel + (PlayerLevel * ScaleFactor)
StatValue = BaseStat * (1 + (PlayerLevel / MaxLevel) * ScaleMultiplier)
```

**Example Worldforged Item:**
```
Worldforged Blade
- Level 1:  10 Strength, 5 Stamina, 5 DPS
- Level 40: 50 Strength, 25 Stamina, 25 DPS
- Level 80: 100 Strength, 50 Stamina, 50 DPS
- Level 255: 320 Strength, 160 Stamina, 160 DPS
```

### 3.3 Dark Chaos Worldforged Status

**Already Implemented (Azshara Crater):**
As noted, Dark Chaos already has a Worldforged-style system:
- Heirloom items in Azshara Crater zone
- Scale with level for 1-80 leveling
- Provide consistent power during progression

**Recommended Expansion for 255:**

**Option A: Extend Existing Heirlooms**
```sql
-- Extend heirloom scaling to 255
UPDATE item_template SET 
    ScalingStatDistribution = 1,  -- Use scaling formula
    ScalingStatValue = 255        -- Scale up to level 255
WHERE entry IN (SELECT entry FROM heirloom_items);

-- Create scaling formula (Eluna)
local function CalculateHeirloomStats(itemEntry, playerLevel)
    local baseStats = GetBaseItemStats(itemEntry)
    local scaleFactor = 1 + (playerLevel / 255) * 3.0  -- 4x stats at 255
    
    return {
        strength = baseStats.strength * scaleFactor,
        stamina = baseStats.stamina * scaleFactor,
        -- ... other stats
    }
end
```

**Option B: Tiered Worldforged Sets**
```sql
-- Create tier-locked Worldforged sets
CREATE TABLE worldforged_sets (
    set_id INT,
    set_name VARCHAR(100),
    min_level INT,
    max_level INT,
    base_ilvl INT,
    scale_per_level FLOAT
);

INSERT INTO worldforged_sets VALUES
(1, 'Apprentice Worldforged', 1, 80, 10, 1.0),
(2, 'Journeyman Worldforged', 80, 130, 200, 1.5),
(3, 'Expert Worldforged', 130, 180, 400, 2.0),
(4, 'Master Worldforged', 180, 220, 700, 2.5),
(5, 'Grandmaster Worldforged', 220, 255, 1000, 3.0);
```

---

## 4. Ascension World Scaling

### 4.1 Dynamic Zone Difficulty

Ascension uses **world scaling** where zones adjust to player power:

| Zone Type | Scaling Behavior | Purpose |
|-----------|-----------------|---------|
| Safe Zones | Fixed, no scaling | Cities, hubs |
| Adventure Zones | Scales to player level | Questing |
| Contested Zones | Scales + PvP enabled | World PvP |
| Mythic Zones | Fixed high difficulty | Endgame |

### 4.2 Creature Scaling Formula

**Estimated Formula:**
```
CreatureLevel = max(ZoneMinLevel, min(PlayerLevel, ZoneMaxLevel))
CreatureHealth = BaseHealth * (1 + (CreatureLevel / 80) * Multiplier)
CreatureDamage = BaseDamage * (1 + (CreatureLevel / 80) * Multiplier)
```

**Zone Configuration:**
```sql
-- Zone scaling configuration
CREATE TABLE zone_scaling (
    zone_id INT PRIMARY KEY,
    min_level INT,
    max_level INT,
    health_multiplier FLOAT,
    damage_multiplier FLOAT,
    loot_multiplier FLOAT
);

INSERT INTO zone_scaling VALUES
-- Classic zones (scaled for 255)
(1, 1, 255, 1.0, 1.0, 1.0),      -- Dun Morogh
(12, 80, 130, 2.0, 1.5, 1.5),    -- Elwynn (Heroic)
(33, 130, 180, 3.0, 2.0, 2.0),   -- Stranglethorn (Epic)
-- etc
```

### 4.3 Dark Chaos World Scaling Implementation

**Current System:**
Dark Chaos uses fixed-level custom zones:
- Azshara Crater: 1-80
- Hyjal: 80-130
- Stratholme Outside: 130-160

**Recommended: Hybrid Approach**

```lua
-- Eluna: Dynamic creature scaling
local SCALING_ZONES = {
    -- zone_id = {min, max, health_mult, damage_mult}
    [1377] = {80, 130, 1.5, 1.3},   -- Crystalsong (repurposed)
    [495] = {130, 180, 2.0, 1.6},   -- Howling Fjord Heroic
    [4395] = {180, 220, 2.5, 2.0},  -- Dalaran Sewers Mythic
}

local function OnCreatureSpawn(event, creature)
    local zone = creature:GetZoneId()
    local scaling = SCALING_ZONES[zone]
    
    if scaling then
        local nearestPlayer = GetNearestPlayer(creature)
        if nearestPlayer then
            local level = nearestPlayer:GetLevel()
            local scaledLevel = math.max(scaling[1], math.min(level, scaling[2]))
            
            -- Apply scaling
            local levelRatio = scaledLevel / 80
            creature:SetMaxHealth(creature:GetMaxHealth() * scaling[3] * levelRatio)
            -- Note: Damage scaling typically done via auras or creature scripts
        end
    end
end
RegisterCreatureEvent(CREATURE_EVENT_ON_SPAWN, OnCreatureSpawn)
```

---

## 5. Ascension Loot Scaling

### 5.1 Loot Tier System

Loot quality scales with content difficulty:

| Content Tier | Loot Quality | Item Version |
|--------------|--------------|--------------|
| Normal | Common/Uncommon | T0 |
| Heroic | Rare | T1 |
| Mythic | Epic | T2 |
| Mythic+ | Legendary | T3 |
| World Boss | Worldforged | T4 |

### 5.2 Dark Chaos Loot Scaling

**Recommended System:**
```sql
-- Loot tier configuration
CREATE TABLE loot_scaling_tiers (
    tier_id INT PRIMARY KEY,
    tier_name VARCHAR(50),
    item_quality_bonus INT,
    stat_multiplier FLOAT,
    drop_chance_modifier FLOAT
);

INSERT INTO loot_scaling_tiers VALUES
(0, 'Normal', 0, 1.0, 1.0),
(1, 'Heroic', 1, 1.25, 0.8),
(2, 'Epic', 2, 1.5, 0.6),
(3, 'Mythic', 3, 2.0, 0.4),
(4, 'Mythic+5', 3, 2.5, 0.3),
(5, 'Mythic+10', 3, 3.0, 0.2),
(6, 'Mythic+15', 3, 4.0, 0.1),
(7, 'Mythic+20', 3, 5.0, 0.05);

-- Apply to creature loot
CREATE VIEW creature_loot_scaled AS
SELECT 
    clt.Entry,
    clt.Item,
    clt.Chance * lst.drop_chance_modifier as Chance,
    lst.stat_multiplier,
    lst.item_quality_bonus
FROM creature_loot_template clt
JOIN creature_template ct ON clt.Entry = ct.entry
JOIN loot_scaling_tiers lst ON ct.difficulty_tier = lst.tier_id;
```

---

## 6. Currency Scaling for 255

### 6.1 Ascension Currency System

Ascension uses multiple currencies that scale with progression:

| Currency | Purpose | Acquisition |
|----------|---------|-------------|
| Conquest | PvP gear | Rated PvP |
| Valor | PvE upgrades | Dungeons/Raids |
| Honor | Basic PvP | All PvP |
| Mystic Runes | Enchants | Rare drops |
| Worldforged Essence | Worldforged items | World events |

### 6.2 Dark Chaos Currency Recommendations

**Current Currencies (assumed):**
- Justice Points
- Valor Points
- Honor
- Custom tokens

**Recommended 255 Currency Structure:**
```sql
CREATE TABLE currency_tiers (
    currency_id INT,
    tier_name VARCHAR(50),
    level_requirement INT,
    exchange_rate_from_lower FLOAT
);

INSERT INTO currency_tiers VALUES
-- Progression currencies
(1001, 'Chaos Tokens', 1, NULL),      -- Base currency
(1002, 'Dark Tokens', 80, 10.0),      -- 10 Chaos = 1 Dark
(1003, 'Void Tokens', 160, 10.0),     -- 10 Dark = 1 Void
(1004, 'Mythic Tokens', 220, 10.0);   -- 10 Void = 1 Mythic

-- Weekly caps scale with level
CREATE TABLE currency_caps (
    currency_id INT,
    level_range_min INT,
    level_range_max INT,
    weekly_cap INT
);

INSERT INTO currency_caps VALUES
(1001, 1, 79, 1000),
(1001, 80, 159, 5000),
(1001, 160, 219, 20000),
(1001, 220, 255, 100000);
```

---

## 7. Stat Scaling for Level 255

### 7.1 The Scaling Problem

At level 255, stats must scale significantly to maintain progression feel:

**Linear Scaling (Bad):**
- Level 80: 1000 STR
- Level 255: 3188 STR (+218%)

**Exponential Scaling (Better):**
- Level 80: 1000 STR
- Level 255: 50000 STR (+4900%)

### 7.2 Recommended Stat Curve

```
StatValue = BaseStat * (Level / 80) ^ ExponentFactor

Where:
- BaseStat = Stat value at level 80
- Level = Current player level
- ExponentFactor = Tuning variable (1.5-2.0 recommended)
```

**Example with Exponent = 1.7:**
| Level | Multiplier | Example Stat (Base 1000) |
|-------|------------|-------------------------|
| 80 | 1.0x | 1,000 |
| 100 | 1.5x | 1,500 |
| 130 | 2.3x | 2,300 |
| 160 | 3.4x | 3,400 |
| 200 | 5.0x | 5,000 |
| 220 | 6.0x | 6,000 |
| 255 | 8.0x | 8,000 |

### 7.3 Implementation

```lua
-- Eluna: Stat scaling on level up
local STAT_EXPONENT = 1.7
local BASE_LEVEL = 80

local function CalculateScaledStat(baseStat, level)
    if level <= BASE_LEVEL then
        return baseStat
    end
    
    local multiplier = (level / BASE_LEVEL) ^ STAT_EXPONENT
    return math.floor(baseStat * multiplier)
end

local function OnLevelUp(event, player, oldLevel)
    local level = player:GetLevel()
    if level > BASE_LEVEL then
        -- Recalculate all equipped item stats
        for slot = 0, 18 do
            local item = player:GetItemByPos(255, slot)
            if item then
                -- Apply scaling (via aura or stat modification)
                ApplyScaledStats(player, item, level)
            end
        end
    end
end
```

---

## 8. Damage/Health Scaling

### 8.1 Combat Scaling Challenge

With scaled stats, combat values must also scale:

| Level | Player HP (Tank) | Boss HP | Player DPS | Boss DPS |
|-------|------------------|---------|------------|----------|
| 80 | 50,000 | 5,000,000 | 5,000 | 3,000 |
| 130 | 150,000 | 20,000,000 | 15,000 | 10,000 |
| 180 | 400,000 | 80,000,000 | 40,000 | 30,000 |
| 220 | 800,000 | 200,000,000 | 80,000 | 60,000 |
| 255 | 1,500,000 | 500,000,000 | 150,000 | 100,000 |

### 8.2 Database Configuration

```sql
-- Creature scaling by level tier
CREATE TABLE creature_level_scaling (
    level_tier_min INT,
    level_tier_max INT,
    health_multiplier FLOAT,
    damage_multiplier FLOAT,
    armor_multiplier FLOAT
);

INSERT INTO creature_level_scaling VALUES
(1, 80, 1.0, 1.0, 1.0),
(81, 100, 1.5, 1.3, 1.2),
(101, 130, 2.5, 2.0, 1.5),
(131, 160, 4.0, 3.0, 2.0),
(161, 200, 7.0, 5.0, 3.0),
(201, 220, 12.0, 8.0, 4.0),
(221, 255, 20.0, 12.0, 5.0);
```

---

## 9. Integration Summary

### 9.1 Features to Adopt from Ascension

| Feature | Priority | Dark Chaos Status | Effort |
|---------|----------|-------------------|--------|
| Item Versioning | High | Partial (upgrades) | Medium |
| Worldforged Items | High | Partial (heirlooms) | Low |
| World Scaling | Medium | Fixed zones | High |
| Currency Tiers | Medium | Basic | Medium |
| Stat Scaling | High | Needs work | Medium |
| Loot Tiers | High | Via M+ | Low |

### 9.2 Recommended Implementation Order

1. **Extend Item Upgrade Tiers** (Week 1)
   - Add tiers 4-7 for levels 160-255
   - Balance stat multipliers

2. **Extend Worldforged/Heirlooms** (Week 2)
   - Scale existing heirlooms to 255
   - Add new tier-locked sets

3. **Implement Stat Scaling** (Week 3)
   - Exponential stat curve
   - Combat value adjustments

4. **Currency Tier System** (Week 4)
   - Multiple progression currencies
   - Exchange rates between tiers

5. **Optional: World Scaling** (Weeks 5-8)
   - Dynamic zone difficulty
   - Player-level creature scaling

---

## 10. Conclusion

### Key Takeaways from Ascension

1. **Item Versions provide progression depth** - Multiple tiers per item extends content
2. **Worldforged solves leveling item obsolescence** - Essential for 255 progression
3. **Scaling must be exponential** - Linear scaling feels flat at high levels
4. **Currency tiers prevent inflation** - Multiple currencies for different progression stages

### Dark Chaos Advantages

- Already has item upgrade system (extend it)
- Already has heirloom implementation (scale it)
- Already has Mythic+ with loot tiers (proven model)
- AIO can display all scaling info without patches

### Final Recommendation

**Adopt Ascension's scaling philosophy, not implementation:**
- Use existing Dark Chaos systems as foundation
- Apply exponential scaling curves
- Add currency and item version tiers
- Focus on content scaling via M+ dungeon system

---

## References
- Ascension Wiki: https://project-ascension.fandom.com/
- Ascension Worldforged: https://project-ascension.fandom.com/wiki/Worldforged
- Dark Chaos Item Upgrades: (internal documentation)
- WoW Stat Formulas: https://wowpedia.fandom.com/wiki/Formulas
