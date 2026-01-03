# World Boss System

**Priority:** S2 - High Priority  
**Effort:** Medium (2 weeks)  
**Impact:** High  
**Base:** Custom C++/Eluna with creature spawning

---

## Overview

A World Boss System adds powerful, open-world bosses that require coordination to defeat. These bosses spawn on schedules or triggers, offer unique rewards, and create community events. Think classic WoW world bosses (Azuregos, Kazzak) combined with modern mechanics.

---

## Why It Fits DarkChaos-255

### Gameplay Value
- Community events that bring players together
- Open-world PvP opportunities (contested spawns)
- Exclusive rewards (mounts, titles, transmog)
- Alternative to instanced content
- Server identity through unique bosses

### Funserver Appeal
- Custom bosses with unique abilities
- Scaled for level 255 challenge
- Integration with hotspot system
- Weekend event potential

### Synergies
| System | Integration |
|--------|-------------|
| **Hotspots** | World boss as hotspot type |
| **Seasonal** | Seasonal world bosses |
| **Weekend Events** | World Boss Weekend |
| **Item Upgrade** | Upgrade materials drop |
| **Prestige** | Kills count toward prestige |

---

## Feature Highlights

### Core Features

1. **Spawn System**
   - Scheduled spawns (known times)
   - Random spawns (within windows)
   - Triggered spawns (event-based)
   - Multi-location spawns

2. **Boss Mechanics**
   - Raid-level mechanics
   - Phase transitions
   - Add spawns
   - Environmental hazards
   - Unique abilities per boss

3. **Loot System**
   - Personal loot (contribution-based)
   - Unique mount drops
   - Cosmetic rewards
   - Upgrade materials
   - Seasonal items

4. **World PvP Integration**
   - Optional PvP flagging
   - Faction competition
   - Cross-faction cooperation option

5. **Announcement System**
   - Server-wide spawn announcements
   - Location broadcasts
   - Health percentage updates
   - Kill announcements

---

## Boss Roster

### Launch Bosses

| Boss Name | Location | Theme | Key Mechanic |
|-----------|----------|-------|--------------|
| **Gorthak the Destroyer** | Icecrown | Death Knight | Raise fallen players as adds |
| **Pyrrhus, Flame Eternal** | Searing Gorge | Fire elemental | Growing fire zones |
| **Netherwing Patriarch** | Netherstorm | Dragon | Flight phases |
| **The Forgotten One** | Silithus | Old God | Mind control, tentacles |
| **Hakkar Reborn** | Stranglethorn | Troll god | Blood siphon, curses |

### Seasonal Bosses

| Boss | Season | Description |
|------|--------|-------------|
| **Frost Queen** | Winter | Ice-themed mechanics |
| **Bloom Guardian** | Spring | Nature/healing mechanics |
| **Solar Avatar** | Summer | Fire/light mechanics |
| **Harvest Lord** | Fall | Decay/harvest mechanics |

### Custom DarkChaos Bosses

| Boss | Location | Unique Feature |
|------|----------|----------------|
| **Chaos Incarnate** | Mall outskirts | Reflects damage type back |
| **The Upgrader** | Near upgrade NPC | Drops upgrade materials |
| **Arena Master** | Near HLBG queue | Spawns after HLBG wins |

---

## Technical Implementation

### Database Schema

```sql
-- World boss definitions
CREATE TABLE dc_world_bosses (
    boss_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    boss_name VARCHAR(100),
    creature_entry INT UNSIGNED,  -- Creature template entry
    
    -- Stats
    health_multiplier FLOAT DEFAULT 10.0,  -- Base creature HP * this
    damage_multiplier FLOAT DEFAULT 3.0,
    armor_multiplier FLOAT DEFAULT 2.0,
    
    -- Location
    spawn_map INT UNSIGNED,
    spawn_x FLOAT, spawn_y FLOAT, spawn_z FLOAT, spawn_o FLOAT,
    spawn_zone_name VARCHAR(100),
    
    -- Spawn timing
    spawn_type ENUM('scheduled', 'random', 'triggered', 'manual') DEFAULT 'scheduled',
    spawn_interval_hours INT DEFAULT 24,  -- Hours between spawns
    spawn_window_hours INT DEFAULT 2,     -- Random window
    next_spawn_time TIMESTAMP NULL,
    
    -- Combat
    combat_script VARCHAR(100),  -- Eluna script name
    phase_health_thresholds JSON,  -- [75, 50, 25] for phase transitions
    enrage_timer_seconds INT DEFAULT 900,  -- 15 min default
    
    -- Loot
    loot_table_id INT UNSIGNED,
    bonus_loot_count INT DEFAULT 3,  -- Extra loot for contribution
    
    -- Flags
    is_active TINYINT DEFAULT 1,
    is_seasonal TINYINT DEFAULT 0,
    season_id INT UNSIGNED NULL,
    
    -- Stats tracking
    total_kills INT DEFAULT 0,
    last_killed TIMESTAMP NULL,
    last_killer_guild VARCHAR(100)
);

-- Spawn locations (for multi-location bosses)
CREATE TABLE dc_world_boss_locations (
    location_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    boss_id INT UNSIGNED,
    map_id INT UNSIGNED,
    x FLOAT, y FLOAT, z FLOAT, o FLOAT,
    zone_name VARCHAR(100),
    spawn_weight INT DEFAULT 100,  -- Higher = more likely
    FOREIGN KEY (boss_id) REFERENCES dc_world_bosses(boss_id)
);

-- Player contribution tracking (per kill)
CREATE TABLE dc_world_boss_contributions (
    contribution_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    boss_kill_id INT UNSIGNED,  -- From dc_world_boss_kills
    player_guid INT UNSIGNED,
    damage_dealt BIGINT DEFAULT 0,
    healing_done BIGINT DEFAULT 0,
    damage_taken BIGINT DEFAULT 0,
    contribution_score FLOAT DEFAULT 0,  -- Calculated
    loot_eligible TINYINT DEFAULT 0,
    loot_received TINYINT DEFAULT 0
);

-- Kill history
CREATE TABLE dc_world_boss_kills (
    kill_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    boss_id INT UNSIGNED,
    kill_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fight_duration_seconds INT,
    total_participants INT,
    top_contributor_guid INT UNSIGNED,
    top_contributor_name VARCHAR(50),
    first_hit_guild VARCHAR(100),
    FOREIGN KEY (boss_id) REFERENCES dc_world_bosses(boss_id)
);

-- Boss loot tables
CREATE TABLE dc_world_boss_loot (
    loot_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    boss_id INT UNSIGNED,
    item_id INT UNSIGNED,
    drop_chance FLOAT,  -- 0.0 to 1.0
    min_count INT DEFAULT 1,
    max_count INT DEFAULT 1,
    is_guaranteed TINYINT DEFAULT 0,  -- Everyone gets this
    requires_contribution FLOAT DEFAULT 0,  -- Min contribution % to be eligible
    FOREIGN KEY (boss_id) REFERENCES dc_world_bosses(boss_id)
);

-- Sample bosses
INSERT INTO dc_world_bosses 
(boss_name, creature_entry, health_multiplier, damage_multiplier, spawn_map, spawn_x, spawn_y, spawn_z, spawn_o, spawn_zone_name, spawn_type, spawn_interval_hours) VALUES
('Gorthak the Destroyer', 100001, 15.0, 4.0, 571, 6178, 2138, 519, 3.14, 'Icecrown', 'scheduled', 24),
('Pyrrhus, Flame Eternal', 100002, 12.0, 3.5, 0, -7058, -1016, 242, 1.5, 'Searing Gorge', 'random', 12),
('The Forgotten One', 100003, 20.0, 5.0, 1, -8132, 1521, 2.5, 0.5, 'Silithus', 'scheduled', 48),
('Chaos Incarnate', 100004, 10.0, 3.0, 0, -8830, 634, 94, 3.8, 'DarkChaos Mall', 'triggered', 0);
```

### C++ Implementation

```cpp
// WorldBossManager.cpp

class WorldBossManager
{
public:
    static WorldBossManager* instance();
    
    // Spawning
    void LoadBosses();
    void SpawnBoss(uint32 bossId);
    void DespawnBoss(uint32 bossId);
    void CheckScheduledSpawns();
    
    // Combat tracking
    void OnBossDamage(Creature* boss, Unit* attacker, uint32 damage);
    void OnBossHeal(Creature* boss, Unit* healer, uint32 heal);
    void OnBossDeath(Creature* boss, Unit* killer);
    
    // Loot
    void DistributeLoot(uint32 bossId, uint32 killId);
    float CalculateContribution(uint32 killId, uint32 playerGuid);
    
    // Announcements
    void AnnounceSpawn(WorldBossInfo* info);
    void AnnounceHealth(WorldBossInfo* info, uint8 percent);
    void AnnounceDeath(WorldBossInfo* info, std::string killerName);
    
private:
    std::map<uint32, WorldBossInfo*> _bosses;
    std::map<ObjectGuid, ActiveBossData*> _activeBosses;
};

// Boss script base class
class WorldBossScript : public CreatureScript
{
public:
    WorldBossScript(const char* name) : CreatureScript(name) { }
    
    void OnCombat(Creature* creature, Unit* /*who*/) override
    {
        // Start contribution tracking
        sWorldBossMgr->StartCombatTracking(creature);
        
        // Start enrage timer
        events.ScheduleEvent(EVENT_ENRAGE, 
            sWorldBossMgr->GetEnrageTimer(creature->GetEntry()));
    }
    
    void DamageTaken(Unit* attacker, uint32& damage) override
    {
        // Track contribution
        sWorldBossMgr->OnBossDamage(me, attacker, damage);
        
        // Check phase transitions
        CheckPhaseTransition();
    }
    
    void JustDied(Unit* killer) override
    {
        sWorldBossMgr->OnBossDeath(me, killer);
    }
    
protected:
    virtual void CheckPhaseTransition() = 0;
    EventMap events;
};

// Example boss: Gorthak the Destroyer
class boss_gorthak : public WorldBossScript
{
public:
    boss_gorthak() : WorldBossScript("boss_gorthak") { }
    
    struct boss_gorthakAI : public BossAI
    {
        boss_gorthakAI(Creature* creature) : BossAI(creature, 0)
        {
            phase = 1;
        }
        
        void EnterCombat(Unit* who) override
        {
            BossAI::EnterCombat(who);
            
            events.ScheduleEvent(EVENT_DEATH_GRIP, 10000);
            events.ScheduleEvent(EVENT_FROST_STRIKE, 5000);
            events.ScheduleEvent(EVENT_SUMMON_GHOULS, 30000);
            
            Announce("|cffff0000Gorthak the Destroyer|r has been engaged!");
        }
        
        void CheckPhaseTransition() override
        {
            uint8 healthPct = me->GetHealthPct();
            
            if (phase == 1 && healthPct <= 75)
            {
                phase = 2;
                Announce("Phase 2: Gorthak begins raising the dead!");
                events.ScheduleEvent(EVENT_RAISE_DEAD, 1000);
            }
            else if (phase == 2 && healthPct <= 50)
            {
                phase = 3;
                Announce("Phase 3: Gorthak unleashes Death's Embrace!");
                events.ScheduleEvent(EVENT_DEATH_EMBRACE, 1000);
            }
            else if (phase == 3 && healthPct <= 25)
            {
                phase = 4;
                Announce("FINAL PHASE: Gorthak enrages!");
                me->AddAura(SPELL_ENRAGE, me);
            }
        }
        
        void UpdateAI(uint32 diff) override
        {
            if (!UpdateVictim())
                return;
                
            events.Update(diff);
            
            while (uint32 eventId = events.ExecuteEvent())
            {
                switch (eventId)
                {
                    case EVENT_DEATH_GRIP:
                        if (Unit* target = SelectTarget(SELECT_TARGET_RANDOM))
                        {
                            DoCast(target, SPELL_DEATH_GRIP);
                        }
                        events.ScheduleEvent(EVENT_DEATH_GRIP, 15000);
                        break;
                        
                    case EVENT_FROST_STRIKE:
                        DoCastVictim(SPELL_FROST_STRIKE);
                        events.ScheduleEvent(EVENT_FROST_STRIKE, 8000);
                        break;
                        
                    case EVENT_SUMMON_GHOULS:
                        // Summon 5 ghouls
                        for (int i = 0; i < 5; ++i)
                            me->SummonCreature(NPC_GHOUL, me->GetPositionX() + frand(-10, 10),
                                me->GetPositionY() + frand(-10, 10), me->GetPositionZ(), 0,
                                TEMPSUMMON_TIMED_DESPAWN_OUT_OF_COMBAT, 60000);
                        events.ScheduleEvent(EVENT_SUMMON_GHOULS, 45000);
                        break;
                        
                    case EVENT_RAISE_DEAD:
                        // Raise dead players as hostile adds
                        RaiseDeadPlayers();
                        events.ScheduleEvent(EVENT_RAISE_DEAD, 60000);
                        break;
                        
                    case EVENT_DEATH_EMBRACE:
                        // AoE damage pulse
                        DoCastAOE(SPELL_DEATH_EMBRACE);
                        events.ScheduleEvent(EVENT_DEATH_EMBRACE, 20000);
                        break;
                }
            }
            
            DoMeleeAttackIfReady();
        }
        
    private:
        uint8 phase;
        
        void RaiseDeadPlayers()
        {
            std::list<Player*> deadPlayers;
            me->GetMap()->GetPlayerList(deadPlayers);
            
            for (Player* player : deadPlayers)
            {
                if (player->isDead() && player->GetDistance(me) < 100.0f)
                {
                    // Spawn hostile copy
                    Creature* ghost = me->SummonCreature(NPC_PLAYER_GHOST,
                        player->GetPosition(), TEMPSUMMON_TIMED_DESPAWN, 60000);
                    if (ghost)
                    {
                        ghost->SetDisplayId(player->GetDisplayId());
                        ghost->SetMaxHealth(player->GetMaxHealth() / 2);
                        ghost->SetFullHealth();
                    }
                }
            }
        }
    };
    
    CreatureAI* GetAI(Creature* creature) const override
    {
        return new boss_gorthakAI(creature);
    }
};
```

### Eluna Spawn Management

```lua
-- World Boss Spawn Manager
local WorldBossMgr = {}
WorldBossMgr.ActiveBosses = {}

-- Check spawns every minute
CreateLuaEvent(function()
    WorldBossMgr.CheckScheduledSpawns()
end, 60000, 0)

function WorldBossMgr.CheckScheduledSpawns()
    local now = os.time()
    
    local query = CharDBQuery([[
        SELECT boss_id, boss_name, creature_entry, spawn_map, 
               spawn_x, spawn_y, spawn_z, spawn_o, spawn_zone_name
        FROM dc_world_bosses
        WHERE is_active = 1 
          AND spawn_type = 'scheduled'
          AND next_spawn_time <= NOW()
          AND boss_id NOT IN (SELECT boss_id FROM dc_active_world_bosses)
    ]])
    
    if query then
        repeat
            local bossId = query:GetUInt32(0)
            local bossName = query:GetString(1)
            local entry = query:GetUInt32(2)
            local mapId = query:GetUInt32(3)
            local x, y, z, o = query:GetFloat(4), query:GetFloat(5), query:GetFloat(6), query:GetFloat(7)
            local zoneName = query:GetString(8)
            
            WorldBossMgr.SpawnBoss(bossId, bossName, entry, mapId, x, y, z, o, zoneName)
        until not query:NextRow()
    end
end

function WorldBossMgr.SpawnBoss(bossId, bossName, entry, mapId, x, y, z, o, zoneName)
    -- Get map instance
    local map = GetMapById(mapId)
    if not map then return end
    
    -- Spawn creature
    local creature = PerformIngameSpawn(1, entry, mapId, 0, x, y, z, o, true, 0)
    
    if creature then
        WorldBossMgr.ActiveBosses[bossId] = {
            creature = creature,
            bossName = bossName,
            spawnTime = os.time()
        }
        
        -- Server announcement
        SendWorldMessage("|cffff0000[WORLD BOSS]|r |cff00ff00" .. bossName .. 
            "|r has spawned in |cff00ffff" .. zoneName .. "|r!")
        
        -- Mark as active in DB
        CharDBExecute("INSERT INTO dc_active_world_bosses (boss_id, spawn_time) VALUES (" .. 
            bossId .. ", NOW())")
        
        -- Schedule next spawn
        CharDBExecute("UPDATE dc_world_bosses SET next_spawn_time = " ..
            "DATE_ADD(NOW(), INTERVAL spawn_interval_hours HOUR) WHERE boss_id = " .. bossId)
    end
end

-- Boss death handler
local function OnWorldBossDeath(event, creature, killer)
    for bossId, data in pairs(WorldBossMgr.ActiveBosses) do
        if data.creature and data.creature:GetGUIDLow() == creature:GetGUIDLow() then
            WorldBossMgr.OnBossDeath(bossId, data, killer)
            return
        end
    end
end

function WorldBossMgr.OnBossDeath(bossId, data, killer)
    local killerName = killer and killer:GetName() or "Unknown"
    local guildName = ""
    
    if killer and killer:GetGuild() then
        guildName = killer:GetGuild():GetName()
    end
    
    -- Announce death
    SendWorldMessage("|cffff0000[WORLD BOSS]|r |cff00ff00" .. data.bossName .. 
        "|r has been defeated by |cffff8800" .. killerName .. "|r!")
    
    -- Record kill
    CharDBExecute([[
        INSERT INTO dc_world_boss_kills 
        (boss_id, fight_duration_seconds, top_contributor_name, first_hit_guild)
        VALUES (]] .. bossId .. [[, ]] .. (os.time() - data.spawnTime) .. 
        [[, ']] .. killerName .. [[', ']] .. guildName .. [[')
    ]])
    
    -- Distribute loot
    WorldBossMgr.DistributeLoot(bossId, data.creature)
    
    -- Cleanup
    WorldBossMgr.ActiveBosses[bossId] = nil
    CharDBExecute("DELETE FROM dc_active_world_bosses WHERE boss_id = " .. bossId)
end

-- Loot distribution
function WorldBossMgr.DistributeLoot(bossId, creature)
    local lootQuery = CharDBQuery([[
        SELECT item_id, drop_chance, min_count, max_count, is_guaranteed, requires_contribution
        FROM dc_world_boss_loot WHERE boss_id = ]] .. bossId)
    
    if not lootQuery then return end
    
    -- Get all nearby players
    local players = creature:GetPlayersInRange(100)
    
    for _, player in ipairs(players) do
        lootQuery:Reset()
        repeat
            local itemId = lootQuery:GetUInt32(0)
            local dropChance = lootQuery:GetFloat(1)
            local minCount = lootQuery:GetUInt32(2)
            local maxCount = lootQuery:GetUInt32(3)
            local guaranteed = lootQuery:GetUInt8(4) == 1
            
            if guaranteed or math.random() < dropChance then
                local count = math.random(minCount, maxCount)
                player:AddItem(itemId, count)
                player:SendBroadcastMessage("|cff00ff00Loot: " .. GetItemLink(itemId) .. 
                    " x" .. count .. "|r")
            end
        until not lootQuery:NextRow()
    end
end

RegisterCreatureEvent(0, 4, OnWorldBossDeath)  -- CREATURE_EVENT_ON_DIED
```

---

## Implementation Phases

### Phase 1 (Week 1): Core System
- [ ] Database schema
- [ ] Spawn manager
- [ ] Basic announcement system
- [ ] Single test boss

### Phase 2 (Week 2): Combat & Loot
- [ ] Boss scripts (2-3 bosses)
- [ ] Contribution tracking
- [ ] Loot distribution
- [ ] Kill history

---

## Loot Tables

### Example: Gorthak the Destroyer

| Item | Drop Rate | Type |
|------|-----------|------|
| Frostbrood Proto-Wyrm | 0.5% | Mount |
| Helm of the Destroyer | 5% | Transmog |
| Gorthak's Greataxe | 5% | Transmog |
| Frozen Upgrade Crystal | 100% | Upgrade material |
| Emblems of Frost x10 | 100% | Currency |

---

## Hotspot Integration

```lua
-- Register world bosses as hotspot events
local function RegisterBossHotspot(bossId, bossName, zoneName)
    -- Add to hotspot system
    HotspotManager.AddHotspot({
        type = "worldboss",
        name = bossName,
        zone = zoneName,
        description = "World Boss Active!",
        expiry = 0,  -- Until killed
        bossId = bossId
    })
end
```

---

## Success Metrics

- Player participation numbers
- Average kill times
- Loot acquisition rates
- Repeat engagement

---

**Recommendation:** Start with 2-3 bosses with simple mechanics. Add complex phase transitions after proving the spawn/loot system works reliably. Consider weekend-only bosses initially to concentrate player population.
