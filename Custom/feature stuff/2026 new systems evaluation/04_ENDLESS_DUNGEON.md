# Endless Dungeon Mode (Roguelike)

**Priority:** S3 (High)  
**Effort:** Medium (4-6 weeks)  
**Impact:** High  
**Client Required:** AIO Addon for UI

> [!IMPORTANT]
> **Existing Design Docs Available!**
> Comprehensive design already exists in `Custom/feature stuff/EndlessDungeon/`:
> - [README.md](file:///k:/Dark-Chaos/DarkChaos-255/Custom/feature%20stuff/EndlessDungeon/README.md) - Overview
> - [CONCEPT_EndlessDungeon.md](file:///k:/Dark-Chaos/DarkChaos-255/Custom/feature%20stuff/EndlessDungeon/CONCEPT_EndlessDungeon.md) - Full gameplay concept
> - [ARCH_Tech_Architecture.md](file:///k:/Dark-Chaos/DarkChaos-255/Custom/feature%20stuff/EndlessDungeon/ARCH_Tech_Architecture.md) - Technical spec
> - [ADDON_UI_Design.md](file:///k:/Dark-Chaos/DarkChaos-255/Custom/feature%20stuff/EndlessDungeon/ADDON_UI_Design.md) - Addon UI design
>
> This evaluation document is a summary; see above for implementation details.

---

## Overview

A roguelike dungeon experience where players progress through increasingly difficult floors, gaining temporary power-ups and facing randomized encounters. Inspired by Ascension's Manastorms, Hour of Twilight, and Path of Exile's Delve.

---

## Why This Feature?

### Player Psychology
- **Infinite Replayability**: No two runs are identical
- **Risk/Reward**: Push deeper for better rewards
- **Solo-Friendly**: Progress at own pace
- **Skill Expression**: Strategy matters as much as gear

### Competitor Examples
- **Ascension**: Manastorms endless climbing mode
- **Hour of Twilight**: ARPG-style solo dungeons
- **Path of Exile**: Delve endless dungeon
- **Retail WoW**: Torghast (Legion Mage Tower inspiration)

### DC Synergy
- Complements **Mythic+** for different playstyle
- Uses **Autobalance** technology for scaling
- Rewards include **upgrade tokens**, **BP XP**
- **Seasonal** variants with unique modifiers

---

## Feature Specification

### Core Concept

```
ENDLESS DUNGEON STRUCTURE
├── Floors: Infinite, increasing difficulty
├── Rooms per Floor: 3-5 (randomized)
├── Room Types: Combat, Boss, Treasure, Rest, Event
├── Power-ups: Temporary buffs (Runes) gained during run
├── Death: Run ends, progress is lost
└── Rewards: Based on highest floor reached
```

### Entry Requirements

| Requirement | Value |
|-------------|-------|
| Minimum Level | 160 |
| Entry Cost | None (free weekly entries) or Token |
| Party Size | 1-5 players |
| Weekly Free Runs | 3 |
| Additional Runs | 1 Endless Token per run |

### Difficulty Scaling

| Floor Range | Monster Level | Modifier |
|-------------|---------------|----------|
| 1-5 | Player Level | x1.0 HP/DMG |
| 6-10 | +5 | x1.25 |
| 11-15 | +10 | x1.5 |
| 16-20 | +15 | x2.0 |
| 21-30 | +20 | x3.0 |
| 31-40 | +25 | x4.0 |
| 41-50 | +30 | x5.0 |
| 51+ | +35 | x6.0+ (scaling) |

### Room Types

| Type | Frequency | Description |
|------|-----------|-------------|
| **Combat** | 60% | Fight waves of enemies |
| **Boss** | Every 5th floor | Powerful boss encounter |
| **Treasure** | 10% | Choose from 3 Runes |
| **Rest** | 10% | Restore 50% HP/Mana, choose 1 Rune |
| **Event** | 10% | Random event (gamble, shrine, trap) |
| **Shop** | Every 10th floor | Buy Runes with floor currency |

### Rune System (Temporary Power-ups)

Runes are temporary buffs that last for the current run only.

**Rune Tiers:**
- **Common** (White): Small stat boosts
- **Uncommon** (Green): Moderate boosts + minor effects
- **Rare** (Blue): Strong effects
- **Epic** (Purple): Build-defining effects
- **Legendary** (Orange): Game-changing (1 per run max)

**Example Runes:**

| Rune | Tier | Effect |
|------|------|--------|
| Iron Skin | Common | +10% Armor |
| Vampiric Touch | Uncommon | 5% Lifesteal |
| Lightning Reflexes | Rare | +20% Haste, dodge has 10% chance to counterattack |
| Chaos Infusion | Epic | Spells have 15% chance to cast twice |
| Avatar of War | Legendary | +100% damage, take 50% more damage |
| Time Dilation | Legendary | Cooldowns reduced by 50% |
| Phoenix Blessing | Legendary | Revive once on death with 50% HP |

### Loot & Rewards

**Floor Progression Rewards:**
| Floor | Reward |
|-------|--------|
| 5 | Upgrade Token (T1) x1 |
| 10 | Endless Token x1, BP XP +500 |
| 15 | Upgrade Token (T2) x1 |
| 20 | Random Epic item, BP XP +1000 |
| 25 | Upgrade Token (T2) x2 |
| 30 | Endless Mount unlock progress |
| 40 | Upgrade Token (T3) x1 |
| 50 | Unique Transmog set piece |
| 50+ | Leaderboard ranking, cosmetic rewards |

**Currency: Void Shards**
- Dropped by all enemies
- Spent at floor 10/20/30... shops
- Lost on run end
- Cannot be saved between runs

---

## Technical Implementation

### Database Schema

```sql
-- Endless dungeon run tracking
CREATE TABLE `dc_endless_runs` (
    `run_id` INT UNSIGNED AUTO_INCREMENT,
    `leader_guid` INT UNSIGNED NOT NULL,
    `party_size` TINYINT UNSIGNED DEFAULT 1,
    `start_time` DATETIME NOT NULL,
    `end_time` DATETIME,
    `highest_floor` INT UNSIGNED DEFAULT 0,
    `total_kills` INT UNSIGNED DEFAULT 0,
    `total_deaths` INT UNSIGNED DEFAULT 0,
    `season_id` INT UNSIGNED,
    PRIMARY KEY (`run_id`)
);

-- Participants in a run
CREATE TABLE `dc_endless_participants` (
    `run_id` INT UNSIGNED NOT NULL,
    `guid` INT UNSIGNED NOT NULL,
    `damage_done` BIGINT UNSIGNED DEFAULT 0,
    `healing_done` BIGINT UNSIGNED DEFAULT 0,
    `deaths` INT UNSIGNED DEFAULT 0,
    PRIMARY KEY (`run_id`, `guid`)
);

-- Active runes in a run
CREATE TABLE `dc_endless_runes` (
    `run_id` INT UNSIGNED NOT NULL,
    `guid` INT UNSIGNED NOT NULL,
    `rune_id` INT UNSIGNED NOT NULL,
    `acquired_floor` INT UNSIGNED,
    PRIMARY KEY (`run_id`, `guid`, `rune_id`)
);

-- Rune definitions
CREATE TABLE `dc_endless_rune_pool` (
    `rune_id` INT UNSIGNED AUTO_INCREMENT,
    `display_name` VARCHAR(100),
    `description` TEXT,
    `tier` ENUM('common', 'uncommon', 'rare', 'epic', 'legendary'),
    `spell_id` INT UNSIGNED, -- Aura to apply
    `is_stackable` TINYINT(1) DEFAULT 0,
    `max_stacks` INT UNSIGNED DEFAULT 1,
    `weight` INT UNSIGNED DEFAULT 100, -- Drop weight
    PRIMARY KEY (`rune_id`)
);

-- Floor templates
CREATE TABLE `dc_endless_floors` (
    `floor_template_id` INT UNSIGNED AUTO_INCREMENT,
    `map_id` INT UNSIGNED NOT NULL,
    `room_type` ENUM('combat', 'boss', 'treasure', 'rest', 'event', 'shop'),
    `creature_pool` TEXT, -- JSON array of possible spawns
    `min_floor` INT UNSIGNED DEFAULT 1,
    `max_floor` INT UNSIGNED DEFAULT 999,
    PRIMARY KEY (`floor_template_id`)
);

-- Weekly entries tracking
CREATE TABLE `dc_endless_weekly` (
    `guid` INT UNSIGNED NOT NULL,
    `week_number` INT UNSIGNED NOT NULL,
    `free_runs_used` TINYINT UNSIGNED DEFAULT 0,
    `token_runs` INT UNSIGNED DEFAULT 0,
    `highest_floor` INT UNSIGNED DEFAULT 0,
    PRIMARY KEY (`guid`, `week_number`)
);

-- Leaderboard
CREATE TABLE `dc_endless_leaderboard` (
    `rank` INT UNSIGNED AUTO_INCREMENT,
    `guid` INT UNSIGNED NOT NULL,
    `character_name` VARCHAR(50),
    `class` TINYINT UNSIGNED,
    `highest_floor` INT UNSIGNED,
    `clear_time_seconds` INT UNSIGNED,
    `season_id` INT UNSIGNED,
    `achieved_date` DATETIME,
    PRIMARY KEY (`rank`, `season_id`)
);
```

### Server Components

```cpp
// EndlessDungeonMgr.h
class EndlessDungeonMgr
{
public:
    static EndlessDungeonMgr* Instance();
    
    // Run Management
    uint32 StartRun(Player* leader, Group* group = nullptr);
    void EndRun(uint32 runId, bool success);
    void AbandonRun(uint32 runId);
    
    // Floor Progression
    void GenerateNextFloor(uint32 runId);
    void OnFloorComplete(uint32 runId);
    FloorTemplate* GetFloorTemplate(uint32 floor);
    
    // Rune System
    void OfferRunes(Player* player, uint32 runId, uint32 count);
    void SelectRune(Player* player, uint32 runId, uint32 runeId);
    void ApplyRunes(Player* player);
    void RemoveAllRunes(Player* player);
    
    // Scaling
    float GetHealthModifier(uint32 floor);
    float GetDamageModifier(uint32 floor);
    uint32 GetMonsterLevel(Player* player, uint32 floor);
    
    // Rewards
    void DistributeFloorRewards(uint32 runId, uint32 floor);
    void DistributeFinalRewards(uint32 runId);
    
    // Leaderboard
    void UpdateLeaderboard(uint32 runId);
    std::vector<LeaderboardEntry> GetTopRuns(uint32 count);

private:
    std::unordered_map<uint32, EndlessRun> _activeRuns;
    std::vector<FloorTemplate> _floorTemplates;
    std::vector<RuneDefinition> _runePool;
};
```

### Map Usage

Uses existing dungeon maps as "floor themes":

| Floor Theme | Source Map | Notes |
|-------------|------------|-------|
| Crypts | Scarlet Monastery | Floors 1-10 |
| Caverns | Wailing Caverns | Floors 5-15 |
| Fortress | Stratholme | Floors 10-25 |
| Demonic | Black Temple | Floors 20-35 |
| Void | Obsidian Sanctum | Floors 30-50 |
| Custom | Deadwind Pass | Floors 40+ |

---

## AIO Addon UI

```
┌─────────────────────────────────────────────────────────────┐
│  ENDLESS DUNGEON - Run #12847                               │
├─────────────────────────────────────────────────────────────┤
│  Floor: 23 / Best: 35          ⏱️ 47:32                     │
│  Party: Solo                   💀 Deaths: 1                 │
├─────────────────────────────────────────────────────────────┤
│  ACTIVE RUNES:                                              │
│  [🟢 Iron Skin x2] [🔵 Vampiric Touch] [🟣 Chaos Infusion] │
├─────────────────────────────────────────────────────────────┤
│  FLOOR MAP:  ◉ → ⚔ → 💰 → ⚔ → 💀                          │
│              You  Combat Chest Combat BOSS                  │
├─────────────────────────────────────────────────────────────┤
│  Void Shards: 1,247             [🛒 Shop at Floor 30]      │
└─────────────────────────────────────────────────────────────┘
```

### Rune Selection UI

```
┌─────────────────────────────────────────────────────────────┐
│  🎁 CHOOSE YOUR RUNE                                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  [🟢 Fortified]      [🔵 Spell Echo]     [🔵 Berserker]    │
│  +15% HP             Spells have 10%     +30% damage        │
│                      to cast twice       -10% armor         │
│                                                             │
│           [Select]        [Select]         [Select]         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Implementation Phases

### Phase 1: Core Framework (Week 1-2)
- Run start/end logic
- Basic floor generation
- Teleport between floors
- Death = run over

### Phase 2: Rune System (Week 2-3)
- Rune database
- Offer/select mechanics
- Apply as auras
- Remove on run end

### Phase 3: Content (Week 3-4)
- 10+ floor templates
- 30+ runes
- Boss encounters
- Event rooms

### Phase 4: UI & Polish (Week 5-6)
- AIO addon UI
- Leaderboard
- Rewards distribution
- Weekly reset

---

## Success Metrics

- **Weekly Participation**: 70% of active players try once
- **Average Run**: 15-20 floors
- **Solo vs Group**: 60% solo, 40% group
- **Session Extension**: +25% play time on run days

---

*Detailed specs for Dark Chaos Endless Dungeon - January 2026*
