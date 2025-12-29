# Azshara Crater - Scalable Dungeon Design
## Copied WotLK Dungeons for Multi-Level Scaling

> [!NOTE]
> Similar approach to Hyjal and Stratholme - copy existing WotLK dungeon maps and scale NPCs for different level ranges.

---

## Concept: Scalable Dungeon System

Instead of creating new dungeon geometry, we **copy existing WotLK dungeon maps** and populate them with scaled versions of creatures for different level brackets.

### Level Brackets
| Tier | Level Range | Dungeon Difficulty |
|------|-------------|-------------------|
| **Tier 1** | 15-25 | Easy (Normal mobs) |
| **Tier 2** | 25-35 | Medium (Some elites) |
| **Tier 3** | 45-55 | Hard (More elites) |
| **Tier 4** | 55-65 | Very Hard (Elite packs) |
| **Tier 5** | 75-80 | Endgame (All elite) |

---

## Recommended Dungeon Maps to Copy

### Option 1: Wailing Caverns (Map 43)
**Best for: Timbermaw Deep (D2) - Level 25-35**

| Property | Value |
|----------|-------|
| Map ID | 43 |
| Original Level | 17-24 |
| Theme | Cave system, nature |
| Size | Medium |
| Boss Count | 5 |
| Layout | Linear with branches |

**Why it fits:**
- Natural cave aesthetic matches Timbermaw theme
- Multiple boss encounter points
- Open areas for pack fights
- Existing pathing/vmaps available

**Scaling Plan:**
| Original NPC | Replacement | Level |
|--------------|-------------|-------|
| Druid of the Fang | Corrupted Furbolg | 28 |
| Deviate Raptor | Cave Bear | 26 |
| Mutanus the Devourer | Ursol Shambler (Boss) | 35 |

---

### Option 2: Shadowfang Keep (Map 33)
**Best for: Ruins of Zin-Azshari (D1) - Level 15-25**

| Property | Value |
|----------|-------|
| Map ID | 33 |
| Original Level | 22-30 |
| Theme | Gothic castle, undead |
| Size | Medium |
| Boss Count | 6 |
| Layout | Multi-floor vertical |

**Why it fits:**
- Undead/ghost theme matches Highborne ruins
- Atmospheric for ancient Night Elf architecture
- Multiple levels for progression
- Existing scripts can be adapted

**Scaling Plan:**
| Original NPC | Replacement | Level |
|--------------|-------------|-------|
| Haunted Servitor | Highborne Apparition (7971) | 18 |
| Shadowfang Moonwalker | Highborne Lichling (7972) | 19 |
| Baron Silverlaine | Varo'then's Ghost (7970) | 25 |

---

### Option 3: Maraudon (Map 349)
**Best for: Spitelash Depths (D3) - Level 45-55**

| Property | Value |
|----------|-------|
| Map ID | 349 |
| Original Level | 46-55 |
| Theme | Crystal caverns, nature/water |
| Size | Large |
| Boss Count | 8 |
| Layout | Split paths, convergent |

**Why it fits:**
- Water/nature theme matches Naga caves
- Crystal aesthetics work for underwater feeling
- Large enough for extended dungeon run
- Good for level 45-55 content

**Scaling Plan:**
| Original NPC | Replacement | Level |
|--------------|-------------|-------|
| Deeprot Horror | Spitelash Warrior (6190) | 48 |
| Noxxious Scion | Spitelash Siren (6195) | 49 |
| Princess Theradras | Duke Hydraxis (13278) | 55 |

---

### Option 4: Dire Maul (Map 429)
**Best for: The Fel Pit (D4) - Level 55-65**

| Property | Value |
|----------|-------|
| Map ID | 429 |
| Original Level | 58-62 |
| Theme | Night Elf ruins, demons |
| Size | Very Large (3 wings) |
| Boss Count | 10+ |
| Layout | Three separate wings |

**Why it fits:**
- Demon-corrupted Night Elf theme is PERFECT
- Existing demon NPCs in West wing
- Satyr presence in original dungeon
- Can use just one wing for sizing

**Recommended Wing: Dire Maul West**
- Demon heavy, satyr enemies
- Portal room aesthetic works for Fel Pit
- Immol'thar fight can be Sethir template

**Scaling Plan:**
| Original NPC | Replacement | Level |
|--------------|-------------|-------|
| Wildspawn Satyr (11451) | Legashi Satyr (6133) | 58 |
| Wildspawn Hellcaller (11454) | Legashi Hellcaller (6135) | 60 |
| Immol'thar | Sethir the Ancient (6909) | 65 |

---

### Option 5: Halls of Stone (Map 599)
**Best for: Sanctum of the Highborne (D5) - Level 75-80**

| Property | Value |
|----------|-------|
| Map ID | 599 |
| Original Level | 77-80 |
| Theme | Titan ruins, ancient magic |
| Size | Medium-Large |
| Boss Count | 4 |
| Layout | Linear with side rooms |

**Why it fits:**
- Ancient magical architecture
- Construct/golem enemies match our Temple theme
- WotLK level range is already correct
- Impressive final boss room

**Scaling Plan:**
| Original NPC | Replacement | Level |
|--------------|-------------|-------|
| Dark Rune Guardian | Arcane Guardian (15691) | 77 |
| Iron Golem | Temple Construct | 78 |
| Sjonnir the Ironshaper | Azuregos (6109) | 80 |

---

## Technical Implementation

### Step 1: Map Cloning (Similar to Hyjal/Stratholme)

```sql
-- Example: Clone Shadowfang Keep as "Ruins of Zin-Azshari"
-- Map 33 → Map 850

-- Server-side: Copy map data
-- maps/33 → maps/850
-- vmaps/33 → vmaps/850
-- mmaps/33 → mmaps/850
```

### Step 2: DBC Modifications

```
Map.dbc:
- New Map ID: 850
- Directory: "RuinsOfZinAzshari"
- MapName: "Ruins of Zin-Azshari"
- InstanceType: 1 (Dungeon)
- Expansion: 2 (WotLK)
```

### Step 3: Creature Template Scaling

```sql
-- Scale existing creature to new level
UPDATE creature_template SET
    minlevel = 18,
    maxlevel = 20,
    faction = 14, -- Hostile
    Health_mod = 2.5, -- Adjust for level
    Damage_mod = 1.5
WHERE entry = 7971; -- Highborne Apparition
```

### Step 4: Instance Template

```sql
INSERT INTO instance_template (map, parent, script, allowMount)
VALUES (850, 0, 'instance_ruins_of_zinashzari', 0);
```

---

## Scalable Dungeon Concept: "The Phantom Halls"

**Single map used for ALL 5 dungeons at different levels**

### Concept
Use **Scarlet Monastery** (Maps 189) as the base, with different "phases" for each level tier:

| Phase | Level | Theme | Boss |
|-------|-------|-------|------|
| Phase 1 | 15-25 | Ghostly Library | Varo'then's Ghost |
| Phase 2 | 25-35 | Corrupted Armory | Ursol Shambler |
| Phase 3 | 45-55 | Flooded Cathedral | Duke Hydraxis |
| Phase 4 | 55-65 | Demonic Chapel | Sethir the Ancient |
| Phase 5 | 75-80 | Void-touched Halls | Azuregos |

### Benefits
- Single map to clone and maintain
- Players learn layout, face different enemies
- Efficient use of resources
- Progressive difficulty feeling

### Phasing Implementation
```sql
-- Different creature spawns per player phase
INSERT INTO creature (guid, id, map, spawnMask, phaseMask, ...)
VALUES 
    (1001, 7971, 850, 1, 1, ...), -- Phase 1: Ghosts
    (1002, 7157, 850, 1, 2, ...), -- Phase 2: Furbolgs
    (1003, 6190, 850, 1, 4, ...); -- Phase 3: Naga
```

---

## Dungeon Rewards Scaling

| Tier | Level | Item Level | Drop Type |
|------|-------|------------|-----------|
| 1 | 15-25 | iLvl 20-25 | Green + 1 Blue boss |
| 2 | 25-35 | iLvl 30-35 | Green + 2 Blue boss |
| 3 | 45-55 | iLvl 50-55 | Blue + 1 Epic chance |
| 4 | 55-65 | iLvl 60-65 | Blue + Epic boss |
| 5 | 75-80 | iLvl 78-80 | Epic + Pre-raid quality |

---

## Alternative: Outdoor "Dungeon" Areas

If map cloning is too complex, use **outdoor caves/ruins** within Azshara Crater:

### Cave-based Dungeons (No instance)
| Dungeon | Area Type | Example |
|---------|-----------|---------|
| D1 | Ruined temple entrance | Like Dire Maul entrance |
| D2 | Deep cave system | Like Blackfathom Deeps exterior |
| D3 | Underwater grotto | Like Coilfang entrance |
| D4 | Fel-corrupted cavern | Like Demon Fall Ridge |
| D5 | Ancient palace interior | Like Sunken Temple area |

**Benefits:**
- No client patch needed
- Easier to implement
- World PvP enabled
- Seamless with open world

**Drawbacks:**
- Less controlled environment
- Possible griefing
- No instance lockouts

---

## Recommended Approach

### For Azshara Crater, use HYBRID approach:

1. **D1-D2 (Low level):** Outdoor cave areas
   - No instance needed
   - Simple creature spawns
   - Easy to test and iterate

2. **D3-D4 (Mid level):** Copied small dungeons
   - Clone Wailing Caverns or Shadowfang Keep
   - Scale creatures appropriately
   - Add custom bosses

3. **D5 (Endgame):** Copied WotLK dungeon
   - Clone Halls of Stone or Gundrak
   - Full instance experience
   - Proper loot tables

---

## Files Needed for Implementation

| File Type | Count | Purpose |
|-----------|-------|---------|
| Map copies | 2-3 | Map/vmap/mmap clones |
| DBC edits | ~10 rows | Map.dbc, AreaTable.dbc |
| SQL scripts | ~5 files | creature_template, instance_template |
| Lua scripts | ~5 files | Boss encounters (Eluna) |
| Client patch | 1 MPQ | DBC + worldmap textures |

---

## Special Features for Scaled Dungeons

### 1. Scaling Buff System
Apply buff based on player level:
- Below dungeon level: +10% damage taken
- At level: Normal
- Above level: -10% loot chance

### 2. Heirloom Synergy
- Heirloom gear provides dungeon bonus
- +5% XP in dungeons per heirloom piece
- Special heirloom chest at final boss

### 3. Repeatable Weekly Quests
Each dungeon has weekly quest:
- "Clear the [Dungeon Name]"
- Reward: Heirloom upgrade token
- Bonus: Cosmetic rewards

---

> [!TIP]
> Start with the outdoor approach for D1-D2, then expand to instanced dungeons for D3-D5 after testing the system.
