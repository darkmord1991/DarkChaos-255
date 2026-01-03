# Custom Dungeon Creation Framework

**Priority:** C3 (Long-term)  
**Effort:** Very High (2-3 months)  
**Impact:** High  
**Base:** Existing Instance System + ADT Reuse

---

## Overview

A framework for creating new dungeons using repurposed/modified existing terrain (ADTs). Faster than creating zones from scratch while still providing unique content.

---

## Why It Fits DarkChaos-255

### Integration Points
| System | Integration |
|--------|-------------|
| **Mythic+** | New M+ dungeons |
| **Item Upgrades** | Dungeon loot feeds upgrades |
| **Seasonal** | Season-exclusive dungeons |
| **Tokens** | Token rewards |
| **Tier Sets** | Tier drops |

### Benefits
- New endgame content
- M+ variety
- Custom boss mechanics
- Fills level gaps
- Shows server uniqueness

---

## ADT Reuse Strategy

### Candidates for Reuse
| Existing Zone | New Dungeon Theme |
|---------------|-------------------|
| Nexus | Crystal Depths (170-185) |
| Utgarde Keep | Vrykul Stronghold (180-200) |
| Halls of Stone | Titan Workshop (200-220) |
| Gundrak | Troll Temple (220-240) |
| Icecrown (outdoor) | Frozen Citadel (240-255) |

### Modification Approach
1. Copy existing instance ADTs
2. Modify lighting/weather
3. Retexture (optional)
4. New NPC spawns
5. New boss scripts
6. Custom loot tables

---

## Dungeon: Crystal Depths (Example)

### Overview
- **Level:** 170-185
- **Bosses:** 4 + 1 Final
- **Theme:** Arcane/Crystal corruption
- **Base ADTs:** The Nexus
- **Loot Tier:** T13 equivalent

### Bosses
| Boss | Mechanics |
|------|-----------|
| Crystalline Sentinel | Crystal Shards, Refraction |
| Arcane Warden | Mana Drain, Arcane Explosion |
| Void-Touched Golem | Void Zones, Shatter |
| Shard Mother | Split Phase, Crystal Adds |
| Nexus Keeper (Final) | All mechanics combined |

---

## Implementation

### Database Schema
```sql
-- Custom dungeon definitions
CREATE TABLE dc_dungeons (
    dungeon_id INT UNSIGNED PRIMARY KEY,
    dungeon_name VARCHAR(100) NOT NULL,
    map_id INT UNSIGNED NOT NULL,
    min_level TINYINT UNSIGNED NOT NULL,
    max_level TINYINT UNSIGNED NOT NULL,
    tier_equivalent TINYINT UNSIGNED DEFAULT 0,
    mythic_plus_enabled BOOLEAN DEFAULT TRUE,
    seasonal_id INT UNSIGNED DEFAULT 0,
    entrance_x FLOAT,
    entrance_y FLOAT,
    entrance_z FLOAT,
    entrance_map INT UNSIGNED
);

-- Boss definitions
CREATE TABLE dc_dungeon_bosses (
    boss_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    dungeon_id INT UNSIGNED NOT NULL,
    creature_entry INT UNSIGNED NOT NULL,
    boss_name VARCHAR(100) NOT NULL,
    boss_order TINYINT UNSIGNED DEFAULT 0,
    is_final_boss BOOLEAN DEFAULT FALSE,
    mechanics TEXT,  -- JSON describing mechanics
    FOREIGN KEY (dungeon_id) REFERENCES dc_dungeons(dungeon_id)
);

-- Custom loot
CREATE TABLE dc_dungeon_loot (
    loot_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    dungeon_id INT UNSIGNED NOT NULL,
    boss_id INT UNSIGNED NOT NULL,
    item_entry INT UNSIGNED NOT NULL,
    drop_chance FLOAT DEFAULT 0.15,
    is_tier_piece BOOLEAN DEFAULT FALSE,
    mythic_plus_only BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (dungeon_id) REFERENCES dc_dungeons(dungeon_id)
);

-- Sample dungeon
INSERT INTO dc_dungeons VALUES
(1, 'Crystal Depths', 578, 170, 185, 13, 1, 0, 3850.0, 6990.0, 69.0, 571);

-- Sample bosses
INSERT INTO dc_dungeon_bosses (dungeon_id, creature_entry, boss_name, boss_order, is_final_boss, mechanics) VALUES
(1, 900001, 'Crystalline Sentinel', 1, 0, '{"shards": true, "refraction": true}'),
(1, 900002, 'Arcane Warden', 2, 0, '{"mana_drain": true, "arcane_explosion": true}'),
(1, 900003, 'Void-Touched Golem', 3, 0, '{"void_zones": true, "shatter": true}'),
(1, 900004, 'Shard Mother', 4, 0, '{"split": true, "crystal_adds": true}'),
(1, 900005, 'Nexus Keeper', 5, 1, '{"all_mechanics": true, "enrage": true}');
```

### Boss Script Template
```cpp
// Boss: Crystalline Sentinel
class boss_crystalline_sentinel : public CreatureScript
{
public:
    boss_crystalline_sentinel() : CreatureScript("boss_crystalline_sentinel") { }

    struct boss_crystalline_sentinelAI : public BossAI
    {
        boss_crystalline_sentinelAI(Creature* creature) : BossAI(creature, DATA_CRYSTALLINE_SENTINEL) { }

        void Reset() override
        {
            _Reset();
            events.Reset();
        }

        void JustEngagedWith(Unit* who) override
        {
            _JustEngagedWith(who);
            events.ScheduleEvent(EVENT_CRYSTAL_SHARDS, 8s);
            events.ScheduleEvent(EVENT_REFRACTION, 15s);
            Talk(SAY_AGGRO);
        }

        void UpdateAI(uint32 diff) override
        {
            if (!UpdateVictim())
                return;

            events.Update(diff);

            if (me->HasUnitState(UNIT_STATE_CASTING))
                return;

            while (uint32 eventId = events.ExecuteEvent())
            {
                switch (eventId)
                {
                    case EVENT_CRYSTAL_SHARDS:
                        DoCast(SPELL_CRYSTAL_SHARDS);
                        events.Repeat(12s, 15s);
                        break;
                    case EVENT_REFRACTION:
                        DoCastAOE(SPELL_REFRACTION);
                        events.Repeat(20s, 25s);
                        break;
                }
            }

            DoMeleeAttackIfReady();
        }

        void JustDied(Unit* killer) override
        {
            _JustDied();
            Talk(SAY_DEATH);
            instance->SetBossState(DATA_CRYSTALLINE_SENTINEL, DONE);
        }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new boss_crystalline_sentinelAI(creature);
    }
};
```

### Instance Script
```cpp
class instance_crystal_depths : public InstanceMapScript
{
public:
    instance_crystal_depths() : InstanceMapScript("instance_crystal_depths", MAP_CRYSTAL_DEPTHS) { }

    struct instance_crystal_depths_InstanceMapScript : public InstanceScript
    {
        instance_crystal_depths_InstanceMapScript(Map* map) : InstanceScript(map) 
        {
            SetHeaders(DataHeader);
            SetBossNumber(MAX_ENCOUNTERS);
        }

        void OnCreatureCreate(Creature* creature) override
        {
            switch (creature->GetEntry())
            {
                case NPC_CRYSTALLINE_SENTINEL:
                    CrystallineSentinelGUID = creature->GetGUID();
                    break;
                // ... other bosses
            }
        }

        ObjectGuid GetGuidData(uint32 type) const override
        {
            switch (type)
            {
                case DATA_CRYSTALLINE_SENTINEL:
                    return CrystallineSentinelGUID;
            }
            return ObjectGuid::Empty;
        }

    private:
        ObjectGuid CrystallineSentinelGUID;
        // ... other boss GUIDs
    };

    InstanceScript* GetInstanceScript(Map* map) const override
    {
        return new instance_crystal_depths_InstanceMapScript(map);
    }
};
```

---

## Client Requirements

### Map.dbc Entry
```
MapID: 578
MapName: Crystal Depths
InstanceType: 1 (Dungeon)
Expansion: 2 (WotLK)
MinLevel: 170
MaxLevel: 185
```

### Loading Screen
- Use existing Nexus loading screen
- OR create simple modified version

### Minimap
- Use existing Nexus minimap data
- Minor modifications if needed

---

## Development Pipeline

### Phase 1: Design (1 week)
1. Choose base ADT zone
2. Design boss mechanics
3. Create loot tables
4. Plan M+ integration

### Phase 2: Server (3 weeks)
1. Create database entries
2. Write instance script
3. Write boss scripts
4. Implement mechanics

### Phase 3: Content (2 weeks)
1. Spawn creature positions
2. Create creature_template entries
3. Set up loot tables
4. Add achievements

### Phase 4: Testing (2 weeks)
1. Solo testing
2. Group testing
3. M+ testing
4. Balance adjustments

### Phase 5: Polish (1 week)
1. Announcements
2. Guide creation
3. Bug fixes
4. Release

---

## Planned Dungeons

| Priority | Dungeon | Level | Base |
|----------|---------|-------|------|
| 1 | Crystal Depths | 170-185 | Nexus |
| 2 | Vrykul Stronghold | 180-200 | Utgarde |
| 3 | Titan Workshop | 200-220 | Halls of Stone |
| 4 | Ancient Troll Temple | 220-240 | Gundrak |
| 5 | Frozen Citadel | 240-255 | Icecrown |

---

## Timeline (Per Dungeon)

| Task | Duration |
|------|----------|
| Design document | 3 days |
| Database setup | 1 day |
| Instance script | 3 days |
| Boss scripts (5) | 10 days |
| Creature spawns | 2 days |
| Loot tables | 1 day |
| Client files | 1 day |
| Testing | 5 days |
| Polish | 2 days |
| **Total per dungeon** | **~4 weeks** |

---

## Future Enhancements

1. **Heroic Versions** - Hard mode with different mechanics
2. **Challenge Modes** - Bronze/Silver/Gold times
3. **Achievement Integration** - Per-dungeon glory achievements
4. **Seasonal Dungeons** - Rotate available dungeons
5. **Community Dungeons** - Player-designed content
