# Dungeon Scaling Analysis - Level & Difficulty Multipliers

## Current WotLK Baseline (Reference)

### WotLK Normal vs Heroic (Existing in 3.3.5a)
Based on your existing documentation and standard WotLK scaling:

```
Normal Dungeons (Level 80):
- HP: 1.0x baseline
- Damage: 1.0x baseline
- Example: Regular trash ~50k HP, Bosses ~200k HP

Heroic Dungeons (Level 80):
- HP: ~1.15-1.30x (varies by dungeon)
- Damage: ~1.10-1.20x (varies by dungeon)
- Example: Heroic trash ~60-65k HP, Bosses ~250-300k HP
- Typical increase: +15-30% HP, +10-20% Damage
```

**Key Insight:** WotLK Heroics are already scaled creatures at the SAME LEVEL (80) with runtime multipliers applied by Blizzard's design.

---

## Proposed System for DarkChaos

### Philosophy
1. **WotLK content (80):** Keep existing Normal/Heroic scaling untouched
2. **TBC content (70):** Keep Heroic at level 70, add Mythic at 80
3. **Vanilla content (60):** Option A or Option B (see below)

---

## Option A: Vanilla Heroic at 60 (Conservative)

### Vanilla Dungeons
```
Normal (Level 60):
- HP: 1.0x baseline
- Damage: 1.0x baseline
- Access: Level 55+

Heroic (Level 60):
- HP: 1.15x baseline  (matching WotLK Heroic ratio)
- Damage: 1.10x baseline
- Access: Level 60+, iLvl 100+
- Reasoning: Same level, scaled difficulty (like WotLK model)

Mythic (Level 80):
- NPCs: Normal 80, Elite 81, Boss 82
- HP: 3.0x baseline of LEVEL 60 creature
- Damage: 2.0x baseline of LEVEL 60 creature
- Access: Level 80+, iLvl 180+
- Reasoning: Level jump + difficulty = substantial power increase
```

**Level 60 → 80 Raw Scaling:**
- A level 60 creature with 10k HP becomes ~25k HP just from level scaling
- Apply 3.0x Mythic multiplier = 75k HP final
- A level 60 boss with 40k HP becomes ~100k at 80 → 300k HP with 3.0x

---

## Option B: Vanilla Heroic at 62 (Differentiated)

### Vanilla Dungeons
```
Normal (Level 60):
- HP: 1.0x baseline
- Damage: 1.0x baseline
- Access: Level 55+

Heroic (Level 62):
- NPCs: Normal 60, Elite 61, Boss 62
- HP: 1.5x baseline of LEVEL 60 creature
- Damage: 1.2x baseline of LEVEL 60 creature
- Access: Level 60+, iLvl 100+
- Reasoning: Slight level differentiation + modest multiplier

Mythic (Level 80):
- NPCs: Normal 80, Elite 81, Boss 82
- HP: 3.0x baseline of LEVEL 60 creature
- Damage: 2.0x baseline of LEVEL 60 creature
- Access: Level 80+, iLvl 180+
```

**Level 60 → 62 Raw Scaling:**
- ~10% HP/Damage increase per level naturally
- Level 62 = ~1.21x stronger than 60 before multipliers
- Apply 1.5x multiplier = ~1.8x total vs Normal

---

## TBC Dungeons (Agreed Approach)

```
Normal (Level 70):
- HP: 1.0x baseline
- Damage: 1.0x baseline
- Access: Level 68+

Heroic (Level 70):
- HP: 1.15x baseline
- Damage: 1.10x baseline
- Access: Level 70+, iLvl 120+
- Reasoning: Mirrors WotLK Normal→Heroic ratio, STAYS AT 70

Mythic (Level 80):
- NPCs: Normal 80, Elite 81, Boss 82
- HP: 3.0x baseline of LEVEL 70 creature
- Damage: 2.0x baseline of LEVEL 70 creature
- Access: Level 80+, iLvl 180+
```

**Level 70 → 80 Raw Scaling:**
- ~8-10% increase per level naturally
- Level 80 = ~2.0-2.5x stronger than 70 before multipliers
- Apply 3.0x multiplier = ~6.0-7.5x total vs Normal 70

---

## Mythic+ Scaling (All Mythic-Enabled Dungeons)

### Base Mythic (Keystone Level 0)
```
Vanilla/TBC: As defined above (3.0x HP, 2.0x Damage at level 80)
WotLK: Use existing Heroic as baseline, apply 1.8x multiplier
```

### Mythic+ Per Level (Keystone 1-8)
```
Per Keystone Level:
- HP: +15% per level (multiplicative)
- Damage: +12% per level (multiplicative)

Formula:
HP_Multiplier = Base_Mythic_HP × (1.15 ^ keystone_level)
Damage_Multiplier = Base_Mythic_Damage × (1.12 ^ keystone_level)

Examples (Vanilla/TBC with 3.0x base HP, 2.0x base damage):
M+0: 3.00x HP, 2.00x Damage
M+1: 3.45x HP, 2.24x Damage
M+2: 3.97x HP, 2.51x Damage
M+3: 4.56x HP, 2.81x Damage
M+5: 6.03x HP, 3.52x Damage
M+8: 9.15x HP, 4.95x Damage

Examples (WotLK with 1.8x base HP, 1.8x base damage):
M+0: 1.80x HP, 1.80x Damage
M+1: 2.07x HP, 2.02x Damage
M+2: 2.38x HP, 2.26x Damage
M+3: 2.74x HP, 2.53x Damage
M+5: 3.62x HP, 3.17x Damage
M+8: 5.49x HP, 4.45x Damage
```

---

## Comparison Table

### Vanilla Dungeon Boss (Example: 40k HP at level 60)

| Difficulty | Level | Multiplier | Effective HP | vs Normal |
|------------|-------|------------|--------------|-----------|
| Normal | 60 | 1.0x | 40k | Baseline |
| **Option A:** Heroic 60 | 60 | 1.15x | 46k | +15% |
| **Option B:** Heroic 62 | 62 | 1.5x | ~73k | +82% |
| Mythic | 80-82 | 3.0x | ~300k | +650% |
| Mythic+5 | 80-82 | 6.03x | ~603k | +1408% |

### TBC Dungeon Boss (Example: 80k HP at level 70)

| Difficulty | Level | Multiplier | Effective HP | vs Normal |
|------------|-------|------------|--------------|-----------|
| Normal | 70 | 1.0x | 80k | Baseline |
| Heroic | 70 | 1.15x | 92k | +15% |
| Mythic | 80-82 | 3.0x | ~480k | +500% |
| Mythic+5 | 80-82 | 6.03x | ~964k | +1105% |

### WotLK Dungeon Boss (Example: 200k HP at level 80)

| Difficulty | Level | Multiplier | Effective HP | vs Normal |
|------------|-------|------------|--------------|-----------|
| Normal | 80 | 1.0x | 200k | Baseline |
| Heroic | 80 | 1.15x | 230k | +15% |
| Mythic | 80-82 | 1.8x | 360k | +80% |
| Mythic+5 | 80-82 | 3.62x | ~724k | +262% |

---

## Runtime Scaling Implementation

### How Scaling Works

```cpp
// Pseudo-code for creature scaling hook
void ScaleCreature(Creature* creature, Map* map)
{
    uint32 mapId = map->GetId();
    Difficulty difficulty = map->GetDifficulty();
    
    // Load dungeon profile from dc_dungeon_mythic_profile
    DungeonProfile profile = LoadProfile(mapId);
    
    // Determine multipliers based on difficulty
    float hpMult = 1.0f;
    float dmgMult = 1.0f;
    
    switch(difficulty)
    {
        case DIFFICULTY_NORMAL:
            // No scaling
            break;
            
        case DIFFICULTY_HEROIC:
            if (profile.expansion == EXPANSION_VANILLA && USE_OPTION_B)
            {
                // Option B: Level 60→62 + 1.5x multiplier
                SetCreatureLevel(creature, 60, 61, 62); // normal/elite/boss
                hpMult = 1.5f;
                dmgMult = 1.2f;
            }
            else if (profile.expansion == EXPANSION_VANILLA && USE_OPTION_A)
            {
                // Option A: Stay level 60, 1.15x multiplier
                hpMult = 1.15f;
                dmgMult = 1.10f;
            }
            else if (profile.expansion == EXPANSION_TBC)
            {
                // TBC: Stay level 70, 1.15x multiplier
                hpMult = 1.15f;
                dmgMult = 1.10f;
            }
            break;
            
        case DIFFICULTY_EPIC: // Mythic (difficulty 3)
            if (profile.expansion <= EXPANSION_TBC)
            {
                // Force level 80/81/82
                SetCreatureLevel(creature, 80, 81, 82);
                hpMult = 3.0f;
                dmgMult = 2.0f;
            }
            else // WotLK
            {
                // Keep level 80, modest multiplier
                hpMult = 1.8f;
                dmgMult = 1.8f;
            }
            
            // Check for Mythic+ keystone
            uint32 keystoneLevel = GetKeystoneLevel(map);
            if (keystoneLevel > 0)
            {
                hpMult *= pow(1.15f, keystoneLevel);
                dmgMult *= pow(1.12f, keystoneLevel);
            }
            break;
    }
    
    // Apply multipliers
    creature->SetMaxHealth(creature->GetMaxHealth() * hpMult);
    creature->SetHealth(creature->GetMaxHealth());
    creature->SetModifierValue(UNIT_MOD_DAMAGE_MAINHAND, BASE_VALUE,
        creature->GetModifierValue(UNIT_MOD_DAMAGE_MAINHAND, BASE_VALUE) * dmgMult);
}

void SetCreatureLevel(Creature* creature, uint8 normalLevel, uint8 eliteLevel, uint8 bossLevel)
{
    uint8 rank = creature->GetCreatureTemplate()->rank;
    
    if (rank == CREATURE_ELITE_WORLDBOSS || rank == CREATURE_ELITE_RAREELITE)
        creature->SetLevel(bossLevel);
    else if (rank == CREATURE_ELITE_ELITE)
        creature->SetLevel(eliteLevel);
    else
        creature->SetLevel(normalLevel);
}
```

---

## Recommendation

### For Vanilla Heroics:

**Option A (Level 60, Conservative):**
- ✅ Consistent with WotLK model (same level, scaled difficulty)
- ✅ Simpler implementation (no level changes)
- ✅ Players familiar with "Heroic = harder version of same content"
- ❌ Less visual distinction (no level change on tooltip)

**Option B (Level 62, Differentiated):**
- ✅ More dramatic difficulty increase (level + multiplier)
- ✅ Clear visual distinction (boss shows level 62)
- ✅ Smoother progression curve (60→62→80)
- ❌ Slight inconsistency with TBC/WotLK approach
- ❌ Requires level adjustment SQL for all Vanilla dungeons

### My Recommendation: **Option A**

**Reasoning:**
1. Matches the proven WotLK formula (same level, scaled stats)
2. Keeps TBC/Vanilla Heroics consistent with each other
3. Saves significant implementation time
4. Players understand "Heroic = +15% difficulty" across ALL expansions
5. Mythic at 80 already provides the massive power spike
6. Level 60→62 only adds ~20% power before multipliers (not worth complexity)

### Summary Table

| Content | Normal | Heroic | Mythic | Mythic+5 |
|---------|--------|--------|--------|----------|
| **Vanilla** | Lv60, 1.0x | Lv60, 1.15x | Lv80-82, 3.0x | Lv80-82, 6.03x |
| **TBC** | Lv70, 1.0x | Lv70, 1.15x | Lv80-82, 3.0x | Lv80-82, 6.03x |
| **WotLK** | Lv80, 1.0x | Lv80, 1.15x | Lv80-82, 1.8x | Lv80-82, 3.62x |

**All Heroics use same-level scaling (like retail Normal→Heroic)**
**All Mythics require level 80+ and provide major power jump**
**All Mythic+ scales exponentially with keystone level**

