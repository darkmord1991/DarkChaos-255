# World Boss Events System

**Priority:** S2 (High) → **✅ PARTIALLY IMPLEMENTED**  
**Existing:** `src/server/scripts/DC/GiantIsles/` (3 bosses)  
**Addon:** DC-InfoBar shows boss timers  
**Effort:** Low (expand existing system)  
**Impact:** High

> [!NOTE]
> **Existing World Boss System:**
> - `GiantIsles/` has 3 bosses: Oondasta, Thok, Nalak
> - Daily rotation system implemented
> - DC-InfoBar already shows boss spawn timers
> - WRLD addon namespace for boss state sync
>
> **What's Needed:** Expand to more zones, integrate with CrossSystem/Seasons, add scheduling UI.

---

## Current Implementation (Giant Isles)

| Boss | Entry | Script | Notes |
|------|-------|--------|-------|
| **Oondasta** | `boss_oondasta.cpp` | ✅ Complete | King of Dinosaurs |
| **Thok** | `boss_thok.cpp` | ✅ Complete | The Bloodthirsty |
| **Nalak** | `boss_nalak.cpp` | ✅ Complete | Storm Lord |

### Existing Features
- ✅ Daily boss rotation system
- ✅ Zone-wide spawn announcements
- ✅ WRLD addon messages (spawn/engage/death)
- ✅ DC-InfoBar timer display
- ✅ Ancient Altar gossip for boss info

---

## Overview

Scheduled open-world boss encounters that bring the community together. World bosses spawn at specific times, require coordination, and drop valuable loot unique to each boss.

---

## Why This Feature?

### Player Psychology
- **Community Building**: Shared experiences create memories
- **FOMO/Scheduling**: "Must be online at X time"
- **Epic Moments**: Large-scale battles feel epic
- **Accessible Endgame**: No group finder, just show up

### Competitor Examples
- **Turtle WoW**: 5+ custom world bosses (Concavius, Dark Reaver, etc.)
- **Retail WoW**: Weekly world boss rotations
- **Unlimited WoW**: Custom world bosses with unique loot

### DC Synergy
- Rewards include **M+ tokens**, **upgrade materials**, **BP XP**
- Integrates with **Seasonal System** (seasonal bosses)
- Drives players to **open world** content

---

## Feature Specification

### Boss Roster (Initial 5)

| Boss | Location | Level | Spawn Schedule | Theme |
|------|----------|-------|----------------|-------|
| **Morgathos the Fallen** | Hyjal Summit | 200 | Mon/Thu 20:00 | Demonic |
| **Crystalus, Heart of Ice** | Crystalsong Forest | 220 | Tue/Fri 20:00 | Arcane/Frost |
| **Warlord Ghazan** | Azshara Crater | 180 | Wed/Sat 20:00 | Orcish |
| **The Void Leviathan** | Deadwind Pass | 240 | Sun 21:00 | Void/Shadow |
| **SEASONAL BOSS** | Varies | 255 | Fri/Sat 22:00 | Season Theme |

### Spawn Mechanics

```
WORLD BOSS LIFECYCLE
├── Pre-Spawn (15 min): Zone announcement, map marker appears
├── Spawn: Boss materializes with dramatic effect
├── Combat Phase: Standard encounter, no instance
├── Enrage: 20 minute timer, boss enrages (wipes raid)
├── Loot: Personal loot for all participants (contribution-based)
└── Respawn Lockout: 30 min before next eligible spawn
```

### Participation Requirements

| Requirement | Value |
|-------------|-------|
| Minimum Level | Boss Level - 20 |
| Minimum Damage/Healing | 0.5% of boss HP (prevents AFK) |
| Faction | Any (cross-faction tagging allowed) |
| Group Required | No (solo can participate) |

### Loot System

**Personal Loot per Kill:**
- 100% Gold (scaled to boss level)
- 50% Chance: 1-3 Upgrade Tokens
- 25% Chance: Rare Transmog piece
- 10% Chance: Boss-specific Epic item
- 5% Chance: Unique Mount/Pet
- 1% Chance: Legendary Recipe/Pattern

**Weekly Lockout Bonus:**
- First kill per boss per week grants bonus chest
- Guaranteed upgrade token + BP XP

---

## Technical Implementation

### Database Schema

```sql
-- World boss definitions
CREATE TABLE `dc_world_bosses` (
    `boss_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `creature_entry` INT UNSIGNED NOT NULL,
    `display_name` VARCHAR(100),
    `zone_id` INT UNSIGNED,
    `spawn_x` FLOAT,
    `spawn_y` FLOAT,
    `spawn_z` FLOAT,
    `spawn_o` FLOAT,
    `min_level` INT UNSIGNED DEFAULT 160,
    `respawn_time_minutes` INT UNSIGNED DEFAULT 30,
    `enrage_time_seconds` INT UNSIGNED DEFAULT 1200,
    `is_seasonal` TINYINT(1) DEFAULT 0,
    PRIMARY KEY (`boss_id`)
);

-- Spawn schedule
CREATE TABLE `dc_world_boss_schedule` (
    `schedule_id` INT UNSIGNED AUTO_INCREMENT,
    `boss_id` INT UNSIGNED NOT NULL,
    `day_of_week` TINYINT UNSIGNED, -- 0=Sun, 6=Sat
    `spawn_hour` TINYINT UNSIGNED,
    `spawn_minute` TINYINT UNSIGNED DEFAULT 0,
    `is_active` TINYINT(1) DEFAULT 1,
    PRIMARY KEY (`schedule_id`)
);

-- Player participation tracking
CREATE TABLE `dc_world_boss_kills` (
    `guid` INT UNSIGNED NOT NULL,
    `boss_id` INT UNSIGNED NOT NULL,
    `kill_time` DATETIME NOT NULL,
    `damage_done` BIGINT UNSIGNED,
    `healing_done` BIGINT UNSIGNED,
    `weekly_claimed` TINYINT(1) DEFAULT 0,
    PRIMARY KEY (`guid`, `boss_id`, `kill_time`)
);

-- Contribution tracking for loot
CREATE TABLE `dc_world_boss_contribution` (
    `guid` INT UNSIGNED NOT NULL,
    `boss_spawn_id` INT UNSIGNED NOT NULL, -- Unique per spawn instance
    `damage_done` BIGINT UNSIGNED DEFAULT 0,
    `healing_done` BIGINT UNSIGNED DEFAULT 0,
    `damage_taken` BIGINT UNSIGNED DEFAULT 0,
    `participation_score` FLOAT,
    PRIMARY KEY (`guid`, `boss_spawn_id`)
);
```

### Server Components

```cpp
// WorldBossMgr.h
class WorldBossMgr
{
public:
    static WorldBossMgr* Instance();
    
    void Initialize();
    void Update(uint32 diff); // Check spawn schedules
    
    void SpawnBoss(uint32 bossId);
    void OnBossKilled(Creature* boss);
    void RegisterContribution(Player* player, uint32 bossSpawnId, 
                              uint64 damage, uint64 healing);
    void DistributeLoot(uint32 bossSpawnId);
    
    void AnnounceUpcoming(uint32 bossId, uint32 minutesUntil);
    WorldBossInfo* GetNextSpawn();
    
    bool HasWeeklyLockout(Player* player, uint32 bossId);

private:
    std::map<uint32, WorldBossInfo> _bosses;
    std::map<uint32, SpawnInstance> _activeSpawns;
    std::vector<SpawnSchedule> _schedules;
};
```

### Creature Script Example

```cpp
class boss_morgathos : public CreatureScript
{
public:
    boss_morgathos() : CreatureScript("boss_morgathos") { }

    struct boss_morgathosAI : public ScriptedAI
    {
        void JustEngagedWith(Unit* who) override
        {
            sWorldBossMgr->OnBossEngaged(me);
            events.ScheduleEvent(EVENT_SHADOWFLAME, 10000);
            events.ScheduleEvent(EVENT_DOOM_STRIKE, 25000);
            events.ScheduleEvent(EVENT_ENRAGE_CHECK, 1000);
        }

        void UpdateAI(uint32 diff) override
        {
            events.Update(diff);
            
            while (uint32 eventId = events.ExecuteEvent())
            {
                switch (eventId)
                {
                    case EVENT_SHADOWFLAME:
                        DoCastAOE(SPELL_SHADOWFLAME);
                        events.ScheduleEvent(EVENT_SHADOWFLAME, 15000);
                        break;
                    case EVENT_DOOM_STRIKE:
                        DoCastVictim(SPELL_DOOM_STRIKE);
                        events.ScheduleEvent(EVENT_DOOM_STRIKE, 30000);
                        break;
                    case EVENT_ENRAGE_CHECK:
                        if (GetTimeInCombat() > 20 * MINUTE * IN_MILLISECONDS)
                            DoCast(SPELL_ENRAGE);
                        else
                            events.ScheduleEvent(EVENT_ENRAGE_CHECK, 1000);
                        break;
                }
            }
        }
        
        void JustDied(Unit* killer) override
        {
            sWorldBossMgr->OnBossKilled(me);
        }
    };
};
```

---

## Integration Points

### With Existing DC Systems

| System | Integration | Status |
|--------|-------------|--------|
| **DC-InfoBar** | Show boss timers | ✅ Already works |
| **WRLD Namespace** | Boss state sync | ✅ Already in `dc_addon_namespace.h` |
| **Seasonal Rewards** | Boss kills tracked | ✅ In `SeasonalRewardScripts.cpp` |
| **Item Upgrades** | Tokens from bosses | ⚠️ Needs hook |
| **CrossSystem** | Session tracking | ⚠️ Needs SystemId |

### Recommended CrossSystem Integration

Add world boss as a tracked content type:

```cpp
// In CrossSystemCore.h, add:
enum class SystemId : uint8
{
    // ...existing...
    WorldBoss = 13,  // NEW
};

// In dc_crosssystem_sessions.cpp:
void OnWorldBossKill(Player* player, uint32 bossId, uint32 contribution)
{
    SessionContext ctx = sSessionMgr->GetContext(player);
    
    // Create world boss event
    CrossEvent event;
    event.systemId = SystemId::WorldBoss;
    event.eventType = EventType::WorldBossKill;
    event.param1 = bossId;
    event.param2 = contribution;
    
    sCrossSystemCore->ProcessEvent(player, event);
}
```

### Seasonal World Boss Rotation

Tie boss availability to current season:

```cpp
// Each season can have a unique seasonal boss
struct SeasonalBoss
{
    uint32 seasonId;
    uint32 creatureEntry;
    std::string displayName;
    // Spawn only during this season
};

bool IsSeasonalBossAvailable(uint32 bossId)
{
    uint32 currentSeason = sSeasonalCore->GetCurrentSeasonId();
    return seasonalBosses[bossId].seasonId == currentSeason;
}
```

### Battle Pass Integration

| Trigger | BP XP Award |
|---------|-------------|
| Boss Kill (any) | +300 XP |
| First Kill of Week | +500 XP bonus |
| Seasonal Boss Kill | +750 XP |
| Top 10 Damage | +200 XP bonus |

---

## Announcement System

```
[15 minutes before spawn]
╔══════════════════════════════════════════════════════════╗
║  🔥 WORLD BOSS: Morgathos the Fallen spawns in 15 MIN!  ║
║  📍 Location: Hyjal Summit                              ║
║  ⚔️ Recommended: Level 200+, 10+ players                ║
╚══════════════════════════════════════════════════════════╝

[On spawn]
╔══════════════════════════════════════════════════════════╗
║  💀 MORGATHOS THE FALLEN HAS AWAKENED!                  ║
║  📍 Hyjal Summit - Rally your allies!                   ║
╚══════════════════════════════════════════════════════════╝

[On kill]
╔══════════════════════════════════════════════════════════╗
║  ⚔️ Morgathos the Fallen has been SLAIN!                ║
║  👥 37 heroes participated                               ║
║  🏆 Top Damage: [PlayerName] - 15.3M                    ║
║  💰 Loot distributed to all participants                ║
╚══════════════════════════════════════════════════════════╝
```

---

## Boss Design Concepts

### Morgathos the Fallen (Level 200 - Demonic)
**Lore:** A corrupted eredar general who fell during the War of the Ancients.

**Abilities:**
- **Shadowflame Breath** - Cone attack, 8 sec cooldown
- **Doom Strike** - Marks tank for massive damage
- **Summon Imps** - Spawns 10 small adds at 75/50/25%
- **Fel Eruption** - Random ground AoE

**Unique Drops:**
- Fel-Touched Blade (1H Sword, unique proc)
- Morgathos' Corrupted Shoulderpads
- Demonic Warhorn (Toy)

### Crystalus, Heart of Ice (Level 220 - Arcane/Frost)
**Lore:** An ancient arcane construct awakened in Crystalsong.

**Abilities:**
- **Frozen Core** - Raid-wide frost damage
- **Arcane Shards** - Targets random players
- **Ice Tomb** - Encases player, must break free
- **Overload** - Gains 50% damage at 30%

**Unique Drops:**
- Crystal-Infused Staff
- Frozen Heart Pendant
- Shard of Crystalsong (Pet)

---

## Implementation Phases

### Phase 1: Core (Week 1)
- Database schema
- Spawn scheduling system
- Basic contribution tracking
- Zone announcements

### Phase 2: Combat (Week 2)
- 3 boss scripts
- Loot distribution
- Weekly lockout system

### Phase 3: Polish (Week 3)
- 2 more boss scripts
- AIO addon for timers
- Leaderboard integration
- Discord webhook

---

## Success Metrics

- **Peak Concurrent**: 50+ players at boss events
- **Participation Rate**: 60% of active players per week
- **Community Sentiment**: Positive feedback on events

---

*Detailed specs for Dark Chaos World Boss System - January 2026*
