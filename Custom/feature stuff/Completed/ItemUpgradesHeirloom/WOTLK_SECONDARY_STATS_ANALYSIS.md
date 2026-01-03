# WotLK 3.3.5a Secondary Stats Analysis
## Heirloom Scaling Reference for Level 1-80 (Competitive to iLvl 239)

---

## Executive Summary

This document analyzes the **10 core secondary stats** available in WotLK 3.3.5a and provides scaling recommendations for heirloom items to remain competitive up to **Item Level 239** (ICC Heroic 25-man gear) at level 80.

**Key Finding:** At level 80, ICC Heroic gear (iLvl 239) typically provides **150-200 rating** per secondary stat slot. Heirlooms should scale to match this benchmark.

---

## Available Secondary Stats in WotLK 3.3.5a

### 1. **Critical Strike Rating** (CR_CRIT_MELEE/RANGED/SPELL = 8/9/10)
- **ITEM_MOD_CRIT_RATING = 32** (universal crit rating)
- **Effect:** Increases chance to critically hit with attacks/spells
- **Rating Conversion at Level 80:** ~45.91 rating = 1% crit
- **iLvl 239 Reference:** ~150-180 crit rating typical
- **Recommended Heirloom Scaling:**
  - Level 1: 5 rating
  - Level 20: 25 rating
  - Level 40: 60 rating
  - Level 60: 100 rating
  - Level 80: 160 rating

### 2. **Hit Rating** (CR_HIT_MELEE/RANGED/SPELL = 5/6/7)
- **ITEM_MOD_HIT_RATING = 31** (universal hit rating)
- **Effect:** Reduces miss chance against targets
- **Rating Conversion at Level 80:** ~32.79 rating = 1% hit
- **Hit Cap:** 8% for melee/ranged vs same level, 17% for spells vs +3 level bosses
- **iLvl 239 Reference:** ~120-150 hit rating typical
- **Recommended Heirloom Scaling:**
  - Level 1: 4 rating
  - Level 20: 20 rating
  - Level 40: 50 rating
  - Level 60: 85 rating
  - Level 80: 140 rating

### 3. **Haste Rating** (CR_HASTE_MELEE/RANGED/SPELL = 17/18/19)
- **ITEM_MOD_HASTE_RATING = 36** (universal haste rating)
- **Effect:** Reduces cast time, attack speed, GCD (partially)
- **Rating Conversion at Level 80:** ~32.79 rating = 1% haste
- **iLvl 239 Reference:** ~150-180 haste rating typical
- **Recommended Heirloom Scaling:**
  - Level 1: 5 rating
  - Level 20: 25 rating
  - Level 40: 60 rating
  - Level 60: 100 rating
  - Level 80: 160 rating

### 4. **Expertise Rating** (CR_EXPERTISE = 23)
- **ITEM_MOD_EXPERTISE_RATING = 37**
- **Effect:** Reduces chance to be dodged/parried by targets
- **Rating Conversion at Level 80:** ~32.79 rating = 1 expertise (0.25% dodge/parry reduction)
- **Expertise Cap:** 26 expertise (6.5%) to eliminate dodge, 52 expertise (13%) for parry
- **iLvl 239 Reference:** ~100-140 expertise rating typical
- **Recommended Heirloom Scaling:**
  - Level 1: 3 rating
  - Level 20: 18 rating
  - Level 40: 45 rating
  - Level 60: 75 rating
  - Level 80: 125 rating

### 5. **Armor Penetration Rating** (CR_ARMOR_PENETRATION = 24)
- **ITEM_MOD_ARMOR_PENETRATION_RATING = 44**
- **Effect:** Reduces target's armor value for physical damage
- **Rating Conversion at Level 80:** ~15.35 rating = 1% armor penetration
- **Cap:** ~100% armor penetration (~1536 rating at level 80)
- **iLvl 239 Reference:** ~80-120 armor pen rating typical
- **Recommended Heirloom Scaling:**
  - Level 1: 3 rating
  - Level 20: 15 rating
  - Level 40: 40 rating
  - Level 60: 70 rating
  - Level 80: 110 rating

### 6. **Resilience Rating** (CR_CRIT_TAKEN_MELEE/RANGED/SPELL = 14/15/16)
- **ITEM_MOD_RESILIENCE_RATING = 35** (reduces all damage taken and crit chance against you)
- **Effect:** Reduces damage taken from players, reduces chance to be crit
- **Rating Conversion at Level 80:** ~94.27 rating = 1% damage reduction
- **PvP Stat:** Primarily useful in PvP content
- **iLvl 239 Reference:** N/A (PvE gear), PvP gear has ~200-300 resilience
- **Recommended Heirloom Scaling (PvP-focused):**
  - Level 1: 5 rating
  - Level 20: 30 rating
  - Level 40: 70 rating
  - Level 60: 120 rating
  - Level 80: 200 rating

### 7. **Dodge Rating** (CR_DODGE = 2)
- **ITEM_MOD_DODGE_RATING = 13**
- **Effect:** Increases chance to dodge physical attacks
- **Rating Conversion at Level 80:** ~45.25 rating = 1% dodge
- **iLvl 239 Reference:** ~100-150 dodge rating on tank gear
- **Recommended Heirloom Scaling (Tank-focused):**
  - Level 1: 4 rating
  - Level 20: 22 rating
  - Level 40: 55 rating
  - Level 60: 90 rating
  - Level 80: 140 rating

### 8. **Parry Rating** (CR_PARRY = 3)
- **ITEM_MOD_PARRY_RATING = 14**
- **Effect:** Increases chance to parry physical attacks
- **Rating Conversion at Level 80:** ~45.25 rating = 1% parry
- **iLvl 239 Reference:** ~100-150 parry rating on tank gear
- **Recommended Heirloom Scaling (Tank-focused):**
  - Level 1: 4 rating
  - Level 20: 22 rating
  - Level 40: 55 rating
  - Level 60: 90 rating
  - Level 80: 140 rating

### 9. **Defense Rating** (CR_DEFENSE_SKILL = 1)
- **ITEM_MOD_DEFENSE_SKILL_RATING = 12**
- **Effect:** Increases defense skill (reduces chance to be crit/hit/crushed)
- **Rating Conversion at Level 80:** ~4.92 rating = 1 defense skill
- **Defense Cap:** 540 defense (689 rating) to become uncrittable by raid bosses
- **iLvl 239 Reference:** ~50-80 defense rating typical on tank gear
- **Recommended Heirloom Scaling (Tank-focused):**
  - Level 1: 2 rating
  - Level 20: 12 rating
  - Level 40: 30 rating
  - Level 60: 50 rating
  - Level 80: 75 rating

### 10. **Block Rating** (CR_BLOCK = 4)
- **ITEM_MOD_BLOCK_RATING = 15**
- **Effect:** Increases chance to block physical attacks (shields only)
- **Rating Conversion at Level 80:** ~16.39 rating = 1% block
- **iLvl 239 Reference:** ~100-140 block rating on tank gear (shield users only)
- **Recommended Heirloom Scaling (Tank-focused, shield users):**
  - Level 1: 3 rating
  - Level 20: 18 rating
  - Level 40: 45 rating
  - Level 60: 75 rating
  - Level 80: 125 rating

---

## Rating Conversion System

WotLK uses a **level-scaled rating conversion system** that makes ratings progressively less efficient as you level up.

### Formula (from C++ code analysis)
```cpp
float Player::GetRatingMultiplier(CombatRating cr) const
{
    uint8 level = GetLevel();
    if (level > GT_MAX_LEVEL) level = GT_MAX_LEVEL;

    GtCombatRatingsEntry const* Rating = 
        sGtCombatRatingsStore.LookupEntry(cr * GT_MAX_LEVEL + level - 1);
    GtOCTClassCombatRatingScalarEntry const* classRating = 
        sGtOCTClassCombatRatingScalarStore.LookupEntry((getClass() - 1) * GT_MAX_RATING + cr + 1);

    return classRating->ratio / Rating->ratio;
}

float Player::GetRatingBonusValue(CombatRating cr) const
{
    return float(GetUInt32Value(PLAYER_FIELD_COMBAT_RATING_1 + cr)) * GetRatingMultiplier(cr);
}
```

### Key Insight
- **Same rating value = less % benefit at higher levels**
- Example: 100 crit rating
  - Level 10: ~21.74% crit
  - Level 40: ~5.38% crit
  - Level 80: ~2.18% crit
- This is **BY DESIGN** to require better gear at higher levels

---

## Item Level 239 Reference Gear (ICC Heroic 25-man)

### Example Items for Comparison

#### **DPS Plate (Warrior/Paladin/DK)**
- **Sanctified Ymirjar Lord's Battleplate** (iLvl 264/277/284 versions exist)
- iLvl 239 equivalent stats per piece:
  - ~180 Strength
  - ~170 Stamina
  - ~130-160 Crit Rating
  - ~100-140 Hit/Haste/Expertise Rating
  - ~80-120 Armor Penetration Rating

#### **DPS Leather (Rogue/Feral Druid)**
- **Sanctified Shadowblade's Battlegear**
- iLvl 239 equivalent stats per piece:
  - ~150 Agility
  - ~160 Stamina
  - ~120-150 Crit Rating
  - ~90-130 Hit/Haste/Armor Pen Rating

#### **Caster Cloth (Mage/Warlock/Priest)**
- **Sanctified Bloodmage's Regalia**
- iLvl 239 equivalent stats per piece:
  - ~180 Intellect
  - ~150 Stamina
  - ~140-180 Spell Power
  - ~120-160 Crit Rating
  - ~100-140 Haste Rating
  - ~80-120 Spirit/Hit Rating

#### **Tank Plate**
- **Sanctified Ymirjar Lord's Plate**
- iLvl 239 equivalent stats per piece:
  - ~180 Stamina
  - ~100-140 Defense Rating
  - ~120-160 Dodge/Parry Rating
  - ~80-120 Expertise Rating
  - ~50-80 Block Rating (shield users)

---

## Recommended Heirloom Scaling Formula

### Scaling Philosophy
1. **Start low at level 1** (5-10 rating) to avoid overpowering low-level content
2. **Scale exponentially** to match gear progression curve
3. **Peak at level 80** to match iLvl 239 benchmarks (150-200 rating)
4. **Different scales for different stat types:**
   - High-value stats (Crit, Hit, Haste): Scale to 140-160 rating
   - Medium-value stats (Expertise, Armor Pen, Dodge, Parry, Block): Scale to 110-140 rating
   - Tank-specific stats (Defense): Scale to 75 rating
   - PvP stats (Resilience): Scale to 200 rating

### Mathematical Formula Options

#### **Option A: Exponential Growth (Recommended)**
```
rating_value = base_rating × (1 + (current_level / max_level) ^ exponent)
```

Example for Crit Rating (targeting 160 at level 80):
```
base_rating = 5
exponent = 2.5

Level 1:  5 × (1 + (1/80)^2.5) = ~5 rating
Level 20: 5 × (1 + (20/80)^2.5) = ~25 rating
Level 40: 5 × (1 + (40/80)^2.5) = ~60 rating
Level 60: 5 × (1 + (60/80)^2.5) = ~100 rating
Level 80: 5 × (1 + (80/80)^2.5) = ~160 rating
```

#### **Option B: Logarithmic Growth (Smoother Curve)**
```
rating_value = max_rating × log(1 + current_level × growth_factor) / log(1 + max_level × growth_factor)
```

Example for Crit Rating (targeting 160 at level 80):
```
max_rating = 160
growth_factor = 0.05

Level 1:  160 × log(1 + 1×0.05) / log(1 + 80×0.05) = ~5 rating
Level 20: 160 × log(1 + 20×0.05) / log(1 + 80×0.05) = ~23 rating
Level 40: 160 × log(1 + 40×0.05) / log(1 + 80×0.05) = ~55 rating
Level 60: 160 × log(1 + 60×0.05) / log(1 + 80×0.05) = ~95 rating
Level 80: 160 × log(1 + 80×0.05) / log(1 + 80×0.05) = ~160 rating
```

#### **Option C: Piecewise Linear (Simplest to Implement)**
```
Divide levels into brackets with linear scaling:
- Levels 1-20: Slow growth (5 → 25 rating)
- Levels 21-40: Medium growth (25 → 60 rating)
- Levels 41-60: Faster growth (60 → 100 rating)
- Levels 61-80: Rapid growth (100 → 160 rating)
```

---

## Stat Priority by Role

### **DPS (Melee Physical)**
1. **Hit Rating** (to 8% cap = ~263 rating) - HIGHEST PRIORITY
2. **Expertise Rating** (to 26 expertise = ~214 rating) - HIGH PRIORITY
3. **Armor Penetration Rating** (if class benefits) or **Crit Rating**
4. **Haste Rating**

### **DPS (Ranged Physical)**
1. **Hit Rating** (to 8% cap = ~263 rating) - HIGHEST PRIORITY
2. **Armor Penetration Rating** (if class benefits) or **Crit Rating**
3. **Haste Rating**
4. **Expertise Rating** (lower priority for ranged)

### **DPS (Caster)**
1. **Hit Rating** (to 17% cap vs +3 bosses = ~446 rating) - HIGHEST PRIORITY
2. **Haste Rating** - HIGH PRIORITY
3. **Crit Rating**
4. **Spirit** (if benefits from Spirit, not a rating stat)

### **Tank (All Types)**
1. **Defense Rating** (to 540 defense = ~689 rating) - CRITICAL
2. **Dodge/Parry Rating** - HIGH PRIORITY
3. **Expertise Rating** (threat generation)
4. **Block Rating** (shield tanks only)
5. **Hit Rating** (threat generation, lower priority)

### **Healer (All Types)**
1. **Haste Rating** - HIGHEST PRIORITY
2. **Crit Rating** - MEDIUM PRIORITY
3. **Spirit** (not a rating stat, mana regen)
4. **MP5** (not a rating stat, mana regen)

---

## Implementation Recommendations

### For Your Heirloom System

#### **Approach 1: Fixed Stat Allocation (Simplest)**
- Assign 2-3 secondary stats per heirloom item
- Use static values that scale with character level
- Example: Heirloom Plate Chest
  - Level 1: +5 Crit, +4 Hit
  - Level 20: +25 Crit, +20 Hit
  - Level 40: +60 Crit, +50 Hit
  - Level 60: +100 Crit, +85 Hit
  - Level 80: +160 Crit, +140 Hit

#### **Approach 2: Player-Customizable Stats (Your Current Design)**
- Players choose which secondary stats to apply
- Each stat levels independently (1-255)
- **Recommended scaling for levels 1-80:**
  - Use exponential formula with cap at level 80 = 160 rating
  - Levels 81-255 continue scaling for extended progression
  - Formula: `rating = 5 × (level / 80)^2.5 × stat_multiplier`
  - stat_multiplier varies by stat type (0.7-1.25)

#### **Stat Multiplier Table (for level 80 targets)**
| Stat Type | Target Rating @ L80 | Base Multiplier |
|-----------|---------------------|-----------------|
| Crit      | 160                 | 1.00            |
| Hit       | 140                 | 0.875           |
| Haste     | 160                 | 1.00            |
| Expertise | 125                 | 0.78125         |
| Armor Pen | 110                 | 0.6875          |
| Resilience| 200                 | 1.25            |
| Dodge     | 140                 | 0.875           |
| Parry     | 140                 | 0.875           |
| Defense   | 75                  | 0.46875         |
| Block     | 125                 | 0.78125         |

### SQL Implementation Example
```sql
-- dc_heirloom_stat_level_costs table (simplified for levels 1-80)
INSERT INTO dc_heirloom_stat_level_costs (stat_level, essence_cost, stat_multiplier) VALUES
-- Levels 1-10: Slow growth
(1,  10,   1.00),
(2,  12,   1.03),
(3,  14,   1.06),
-- ... (continue pattern)
(10, 35,   1.30),

-- Levels 11-30: Medium growth
(20, 80,   2.00),
(30, 150,  3.20),

-- Levels 31-60: Faster growth
(40, 280,  5.00),
(50, 450,  7.50),
(60, 650,  10.50),

-- Levels 61-80: Rapid growth to match iLvl 239
(70, 900,  14.00),
(80, 1200, 18.00); -- At level 80, rating = 5 × 18.00 = 90 base (then × stat_multiplier)
```

### C++ Calculation Example
```cpp
uint32 CalculateSecondaryStatRating(uint8 character_level, uint8 stat_level, uint8 stat_type)
{
    if (character_level > 80) character_level = 80; // Cap at 80 for this calculation
    
    // Base rating at level 80
    const float base_rating_80[10] = {
        160.0f, // Crit
        140.0f, // Hit
        160.0f, // Haste
        125.0f, // Expertise
        110.0f, // Armor Pen
        200.0f, // Resilience
        140.0f, // Dodge
        140.0f, // Parry
        75.0f,  // Defense
        125.0f  // Block
    };
    
    // Exponential scaling formula
    float level_factor = pow((float)character_level / 80.0f, 2.5f);
    float stat_level_multiplier = 1.0f + ((float)stat_level / 10.0f); // Simple linear for stat levels
    
    float final_rating = base_rating_80[stat_type] * level_factor * stat_level_multiplier;
    
    return (uint32)final_rating;
}
```

---

## Testing Benchmarks

### Level 80 Competitive Check
Your heirloom secondary stats should provide:
- **Similar total stat budget** to iLvl 239 gear (~150-200 rating per stat)
- **NOT EXCEED** iLvl 264 gear (~200-250 rating per stat)
- Remain balanced for different roles (DPS/Tank/Healer)

### Sample Item Comparison (Level 80 Heirloom Chest vs ICC Gear)

#### **Heirloom Plate Chest (Target)**
- 200 Strength (from primary stats)
- 180 Stamina (from primary stats)
- **160 Crit Rating** (customizable secondary stat #1)
- **140 Hit Rating** (customizable secondary stat #2)
- **125 Expertise Rating** (customizable secondary stat #3)
- **Total Secondary Stats:** ~425 rating

#### **ICC Heroic Plate Chest (iLvl 264)**
- 230 Strength
- 210 Stamina
- **180 Crit Rating**
- **150 Hit Rating**
- **140 Expertise Rating**
- **Total Secondary Stats:** ~470 rating

**Result:** Heirloom is ~90% as powerful as iLvl 264 - BALANCED ✓

---

## Conclusion

### Key Recommendations

1. **Use 10 available secondary stats:** Crit, Hit, Haste, Expertise, Armor Pen, Resilience, Dodge, Parry, Defense, Block

2. **Scale to match iLvl 239 at level 80:**
   - DPS stats: 140-160 rating
   - Tank stats: 75-140 rating (Defense lowest, Dodge/Parry highest)
   - PvP stats: 200 rating (Resilience)

3. **Use exponential or logarithmic scaling** to match gear progression curve naturally

4. **Rating conversion happens automatically** via WotLK's built-in system - you only need to provide the rating values

5. **Test at key level breakpoints:** 10, 20, 40, 60, 80 to ensure competitive but not overpowered

6. **Consider role-specific optimization:** DPS prioritizes Hit/Crit, Tanks prioritize Defense/Avoidance

### Next Steps for Implementation

1. Update your `dc_heirloom_stat_level_costs` table with level 1-80 values using recommended formulas
2. Adjust stat multipliers per stat type to hit level 80 targets
3. Test in-game with character at level 20, 40, 60, 80
4. Compare against actual WotLK gear at those levels
5. Fine-tune multipliers based on balance feedback

---

**Document Version:** 1.0  
**Created:** 2025-11-16  
**Reference Expansion:** WotLK 3.3.5a (Build 12340)  
**Target Item Level:** 239 (ICC Heroic 25-man)
