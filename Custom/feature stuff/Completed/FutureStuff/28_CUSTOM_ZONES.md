# Custom Zones Framework (Level 170-255)

**Priority:** C4 (Future Content)  
**Effort:** Extreme (3-6 months)  
**Impact:** Very High  
**Base:** ADT Reuse + Existing Map Editing Tools

---

## Overview

New outdoor zones for the level 170-255 progression path. Rather than creating entirely new terrain, this leverages existing unused/underused WotLK zones with new quests, creatures, and systems.

---

## Why It Fits DarkChaos-255

### Addresses
| Gap | Solution |
|-----|----------|
| Level progression | 170-255 content |
| Endgame variety | Multiple zones |
| Story continuation | Custom lore |
| World exploration | New areas |

### Integration
| System | Integration |
|--------|-------------|
| **Seasons** | Zone rotations |
| **Item Upgrades** | Zone-specific materials |
| **Mythic+** | Outdoor challenges |
| **Hotspot** | XP zones |
| **Quests** | Zone storylines |

---

## Zone Reuse Strategy

### WotLK Zones for Expansion
| Base Zone | New Purpose | Level Range |
|-----------|-------------|-------------|
| Storm Peaks (North) | Frost Wastes | 170-195 |
| Wintergrasp (unused areas) | War Front | 195-220 |
| Crystalsong Forest | Arcane Reaches | 220-240 |
| Icecrown (unused) | Shadow Citadel | 240-255 |

### Unused Instance Terrain
| Instance | Outdoor Use | Theme |
|----------|-------------|-------|
| Ulduar exterior | Titan Ruins | 200-220 |
| ICC exterior | Scourge Highlands | 240-255 |

---

## Zone 1: Frost Wastes (170-195)

### Overview
- **Location:** Northern Storm Peaks
- **Theme:** Frozen tundra, ancient frost giants
- **Subzones:** 5 unique areas
- **Quests:** 50+ quests
- **Dungeons:** Crystal Depths access

### Subzones
| Subzone | Level | Theme |
|---------|-------|-------|
| Frozen Harbor | 170-175 | Starting area, expedition |
| Frostbite Valley | 175-180 | Frost giant territory |
| Crystal Caverns | 180-185 | Crystalline formations |
| Ancient Titan Dig | 185-190 | Archaeology theme |
| Summit of Storms | 190-195 | Final area, storm magic |

### Key Features
- Frost Giant faction
- Storm magic mechanics
- Vehicle-based content
- World bosses (2)

---

## Zone 2: Arcane Reaches (220-240)

### Overview
- **Location:** Deep Crystalsong Forest
- **Theme:** Corrupted arcane magic
- **Subzones:** 4 unique areas
- **Quests:** 60+ quests
- **Dungeons:** Titan Workshop access

### Subzones
| Subzone | Level | Theme |
|---------|-------|-------|
| Verdant Approach | 220-225 | Forest entrance |
| Arcane Scar | 225-230 | Corrupted zone |
| Crystal Gardens | 230-235 | Beautiful but deadly |
| The Nexus Wound | 235-240 | Portal instability |

### Key Features
- Arcane corruption mechanic
- Portal puzzles
- Dalaran faction quests
- World bosses (2)

---

## Implementation

### Zone Database Structure
```sql
-- Custom zone definitions
CREATE TABLE dc_zones (
    zone_id INT UNSIGNED PRIMARY KEY,
    zone_name VARCHAR(100) NOT NULL,
    map_id INT UNSIGNED NOT NULL,
    min_level TINYINT UNSIGNED NOT NULL,
    max_level TINYINT UNSIGNED NOT NULL,
    base_zone_id INT UNSIGNED, -- Original zone reused
    season_restricted INT UNSIGNED DEFAULT 0,
    faction_id INT UNSIGNED DEFAULT 0
);

-- Subzone definitions
CREATE TABLE dc_subzones (
    subzone_id INT UNSIGNED PRIMARY KEY,
    zone_id INT UNSIGNED NOT NULL,
    subzone_name VARCHAR(100) NOT NULL,
    min_level TINYINT UNSIGNED NOT NULL,
    max_level TINYINT UNSIGNED NOT NULL,
    area_id INT UNSIGNED, -- AreaTable.dbc reference
    FOREIGN KEY (zone_id) REFERENCES dc_zones(zone_id)
);

-- Zone faction progression
CREATE TABLE dc_zone_reputation (
    faction_id INT UNSIGNED PRIMARY KEY,
    faction_name VARCHAR(100) NOT NULL,
    zone_id INT UNSIGNED NOT NULL,
    rewards_table INT UNSIGNED,
    FOREIGN KEY (zone_id) REFERENCES dc_zones(zone_id)
);

-- Populate Frost Wastes
INSERT INTO dc_zones VALUES
(1, 'Frost Wastes', 571, 170, 195, 67, 0, 10001);

INSERT INTO dc_subzones VALUES
(1, 1, 'Frozen Harbor', 170, 175, 0),
(2, 1, 'Frostbite Valley', 175, 180, 0),
(3, 1, 'Crystal Caverns', 180, 185, 0),
(4, 1, 'Ancient Titan Dig', 185, 190, 0),
(5, 1, 'Summit of Storms', 190, 195, 0);
```

### Creature Scaling System
```cpp
class dc_zone_creature_scaling : public CreatureScript
{
public:
    dc_zone_creature_scaling() : CreatureScript("dc_zone_creature_scaling") { }

    void OnCreatureCreate(Creature* creature)
    {
        uint32 zoneId = creature->GetZoneId();
        
        // Check if custom zone
        auto zoneData = GetDCZoneData(zoneId);
        if (!zoneData)
            return;

        // Scale creature to zone level range
        uint32 minLevel = zoneData->minLevel;
        uint32 maxLevel = zoneData->maxLevel;
        
        // Calculate based on subzone
        uint32 subzoneId = creature->GetAreaId();
        auto subzoneData = GetDCSubzoneData(subzoneId);
        if (subzoneData)
        {
            minLevel = subzoneData->minLevel;
            maxLevel = subzoneData->maxLevel;
        }

        // Apply level scaling
        uint8 level = urand(minLevel, maxLevel);
        creature->SetLevel(level);
        
        // Scale stats for 255 system
        ApplyLevel255Scaling(creature, level);
    }

private:
    void ApplyLevel255Scaling(Creature* creature, uint8 level)
    {
        float multiplier = 1.0f + (float(level - 80) / 255.0f) * 5.0f;
        
        uint32 baseHP = creature->GetMaxHealth();
        creature->SetMaxHealth(baseHP * multiplier);
        creature->SetHealth(baseHP * multiplier);
        
        // Similar for damage, armor, etc.
    }
};
```

### Quest System Integration
```cpp
// Quest scaling for 170-255
class dc_quest_scaler : public PlayerScript
{
public:
    dc_quest_scaler() : PlayerScript("dc_quest_scaler") { }

    void OnQuestComplete(Player* player, Quest const* quest)
    {
        // Check if custom zone quest
        uint32 questId = quest->GetQuestId();
        auto customQuest = GetDCQuestData(questId);
        if (!customQuest)
            return;

        // Scale rewards
        uint32 playerLevel = player->GetLevel();
        uint32 baseXP = quest->XPValue(player);
        
        // Apply 255 scaling
        float scale = float(playerLevel) / 80.0f;
        uint32 scaledXP = baseXP * scale * 1.5f;
        
        player->GiveXP(scaledXP, nullptr);
        
        // Zone faction rep
        uint32 factionId = customQuest->factionId;
        if (factionId)
        {
            int32 rep = customQuest->repReward * scale;
            player->GetReputationMgr().ModifyReputation(sFactionStore.LookupEntry(factionId), rep);
        }
    }
};
```

---

## Content Creation Pipeline

### Phase 1: Design (2 weeks per zone)
1. Zone layout document
2. Subzone distribution
3. Quest outline
4. Creature list
5. Loot tables

### Phase 2: Database (1 week per zone)
1. creature_template entries
2. quest_template entries
3. item_template for loot
4. Custom tables

### Phase 3: World (2 weeks per zone)
1. Creature spawns
2. GameObject spawns
3. NPC vendors/trainers
4. Quest givers

### Phase 4: Scripts (3 weeks per zone)
1. Creature AI scripts
2. Quest scripts
3. Event scripts
4. World boss scripts

### Phase 5: Testing (2 weeks per zone)
1. Level progression test
2. Quest chain test
3. World boss test
4. Performance test

---

## Client Requirements

### Minimal Changes
- AreaTable.dbc modifications (subzone names)
- Map.dbc (if new instance)
- Loading screens (optional)
- Minimap overlays (optional)

### No Changes Needed
- Terrain (reuse existing)
- Base textures
- Lighting (server can modify)

---

## World Bosses

### Per Zone
| Zone | Boss 1 | Boss 2 |
|------|--------|--------|
| Frost Wastes | Grolmir the Frozen | Storm Colossus |
| Arcane Reaches | The Nexus Devourer | Arcane Titan |
| Shadow Citadel | Lich King's Shadow | Death's Herald |

### Spawn System
```sql
-- World boss spawns
CREATE TABLE dc_world_bosses (
    boss_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    creature_entry INT UNSIGNED NOT NULL,
    boss_name VARCHAR(100) NOT NULL,
    zone_id INT UNSIGNED NOT NULL,
    spawn_x FLOAT,
    spawn_y FLOAT,
    spawn_z FLOAT,
    spawn_o FLOAT,
    respawn_time INT UNSIGNED DEFAULT 604800, -- 1 week
    announce_spawn BOOLEAN DEFAULT TRUE,
    min_raid_size TINYINT UNSIGNED DEFAULT 10,
    FOREIGN KEY (zone_id) REFERENCES dc_zones(zone_id)
);

-- Loot for world bosses
CREATE TABLE dc_world_boss_loot (
    boss_id INT UNSIGNED,
    item_entry INT UNSIGNED,
    drop_chance FLOAT DEFAULT 0.1,
    PRIMARY KEY (boss_id, item_entry)
);
```

---

## Faction System

### New Factions
| Faction | Zone | Rewards |
|---------|------|---------|
| Frostborn Legion | Frost Wastes | Frost gear, mounts |
| Arcane Conclave | Arcane Reaches | Magic gear, recipes |
| Shadow Resistance | Shadow Citadel | Shadow gear, tabards |

### Reputation Rewards
- Honored: Blue quality gear
- Revered: Epic quality gear
- Exalted: Legendary recipes, mounts

---

## Timeline

### Per Zone Development
| Phase | Duration |
|-------|----------|
| Design | 2 weeks |
| Database | 1 week |
| World spawns | 2 weeks |
| Scripts | 3 weeks |
| Testing | 2 weeks |
| Polish | 1 week |
| **Total** | **~11 weeks** |

### Full Rollout
| Zone | Planned |
|------|---------|
| Frost Wastes (170-195) | Season 3 |
| Arcane Reaches (220-240) | Season 4 |
| Shadow Citadel (240-255) | Season 5 |

---

## Future Enhancements

1. **Dynamic Events** - Zone-wide invasions
2. **Phased Content** - Story progression changes zone
3. **Weather Systems** - Affects gameplay
4. **Day/Night Cycles** - Different spawns
5. **Seasonal Changes** - Holiday variants
