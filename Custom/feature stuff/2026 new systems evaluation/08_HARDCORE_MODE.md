# Hardcore / Ironman Mode

**Priority:** A4 (Medium-High) → **✅ ALREADY IMPLEMENTED**  
**Status:** Complete in `src/server/scripts/DC/Progression/ChallengeMode/`

> [!IMPORTANT]
> **This feature is already fully implemented!**
> See `ChallengeMode/` directory for:
> - `dc_challenge_modes.h` - Mode definitions
> - `dc_challenge_modes_customized.cpp` - Full implementation (70KB)
> - `dc_challenge_mode_enforcement.cpp` - Death/restriction handling

---

## Implemented Challenge Modes

| Mode | Setting | Spell Aura | Description |
|------|---------|------------|-------------|
| **Hardcore** | `SETTING_HARDCORE` | 800020 | Permadeath |
| **Semi-Hardcore** | `SETTING_SEMI_HARDCORE` | 800021 | Limited lives |
| **Self-Crafted** | `SETTING_SELF_CRAFTED` | 800022 | Only equip self-crafted gear |
| **Item Quality** | `SETTING_ITEM_QUALITY_LEVEL` | 800023 | Restricted item quality |
| **Slow XP** | `SETTING_SLOW_XP_GAIN` | 800024 | Reduced XP rate |
| **Very Slow XP** | `SETTING_VERY_SLOW_XP_GAIN` | 800025 | Even slower XP |
| **Quest XP Only** | `SETTING_QUEST_XP_ONLY` | 800026 | No mob XP |
| **Iron Man** | `SETTING_IRON_MAN` | 800027 | Classic ironman ruleset |
| **Iron Man Plus** | `SETTING_IRON_MAN_PLUS` | 800029 | Enhanced ironman |

---

## Features Already Implemented

- ✅ Challenge auras (visual indicators)
- ✅ Title rewards per milestone
- ✅ Talent point rewards
- ✅ Item rewards
- ✅ Achievement integration
- ✅ XP bonuses for challenge modes
- ✅ Equipment restrictions
- ✅ Death enforcement (permadeath logic)
- ✅ Challenge Mode Shrine NPC

---

## What Could Be Added (Future Enhancement)

| Enhancement | Description |
|-------------|-------------|
| Leaderboards | Track highest level per mode |
| Hall of Fame | Display top hardcore characters |
| Death Broadcast | Server-wide death announcements |
| Seasonal HC | Reset with seasons for fresh competition |
| AIO Addon UI | Visual challenge mode status panel |

---

*Document updated - Hardcore Modes are COMPLETE in ChallengeMode/ - January 2026*

---

## Why This Feature?

- **Streaming Appeal**: Hardcore deaths are content
- **Challenge Seekers**: Dedicated audience for this
- **Replayability**: Death means starting over
- **Low Effort**: Mostly tracking + rules

---

## Competitor Reference

### Official WoW Classic Hardcore
- Permadeath
- No trading
- No AH
- BG deaths don't count

### Turtle WoW Hardcore
- Permadeath with bug death appeals
- Leaderboards
- Special rewards for reaching milestones

### Ascension Fellforged
- Roguelike elements
- Draft abilities
- High-risk zones

---

## DC Hardcore Specification

### Mode Types

| Mode | Description | Death Penalty |
|------|-------------|---------------|
| **Hardcore** | Standard permadeath | Character deleted |
| **Ironman** | No gear above white quality | Character deleted |
| **Soul-Bound** | Standard but 1 extra life | Lose life, then delete |
| **Seasonal HC** | Hardcore with season end grace | Move to normal at season end |

### Rules

| Rule | Hardcore | Ironman |
|------|----------|---------|
| Permadeath | ✅ | ✅ |
| No trading | ✅ | ✅ |
| No AH | ✅ | ✅ |
| No mail items | ✅ | ✅ |
| No grouping | ❌ | ✅ |
| Gear restriction | ❌ | White only |
| BG death immunity | ✅ | ✅ |
| Duel death immunity | ✅ | ✅ |

### Milestones & Rewards

| Milestone | Reward (Account-wide) |
|-----------|----------------------|
| Reach Level 80 | "Survivalist" Title |
| Reach Level 160 | Hardcore Tabard |
| Reach Level 200 | Unique Mount |
| Reach Level 255 | "Deathless" Title + Aura |
| Clear M+5 Hardcore | Achievement |
| Clear M+10 Hardcore | Legendary Transmog |

### Death Protection (Exempt Deaths)

| Scenario | Death Counts? |
|----------|---------------|
| Battleground | ❌ No |
| Arena | ❌ No |
| Duel | ❌ No |
| Server crash | ❌ No (appeal) |
| Exploit/bug | ❌ No (appeal) |
| HLBG | ❌ No |
| PvP zone | ✅ Yes |
| Dungeon | ✅ Yes |
| Open world | ✅ Yes |

---

## Technical Implementation

```sql
-- Hardcore character tracking
CREATE TABLE `dc_hardcore` (
    `guid` INT UNSIGNED PRIMARY KEY,
    `mode` ENUM('hardcore', 'ironman', 'soulbound', 'seasonal'),
    `start_time` DATETIME,
    `death_time` DATETIME,
    `death_zone` INT UNSIGNED,
    `death_killer` VARCHAR(100),
    `highest_level` INT UNSIGNED,
    `extra_lives` TINYINT DEFAULT 0,
    `is_alive` TINYINT(1) DEFAULT 1
);

-- Leaderboard
CREATE TABLE `dc_hardcore_leaderboard` (
    `rank` INT UNSIGNED AUTO_INCREMENT,
    `guid` INT UNSIGNED,
    `name` VARCHAR(50),
    `class` TINYINT,
    `final_level` INT UNSIGNED,
    `play_time` INT UNSIGNED,
    `death_cause` VARCHAR(255),
    `season_id` INT UNSIGNED,
    PRIMARY KEY (`rank`, `season_id`)
);
```

```cpp
class HardcoreMgr
{
    bool IsHardcore(Player* player);
    void OnPlayerDeath(Player* player, Unit* killer);
    bool ShouldCountDeath(Player* player, Map* map);
    void ProcessDeath(Player* player);
    void GrantMilestoneReward(Player* player, uint32 level);
};
```

---

## UI Elements (AIO)

- Hardcore icon on nameplate
- Death count (for non-HC) vs "ALIVE" for HC
- Milestone progress tracker
- Graveyard (hall of fame for dead characters)

---

## Implementation Phases

### Phase 1 (Week 1)
- Mode registration
- Death tracking
- Deletion/freeze logic

### Phase 2 (Week 2)
- Milestone rewards
- Leaderboards
- Appeal system skeleton

### Phase 3 (Week 3)
- AIO addon UI
- Death announcements
- Hall of Fame display

---

*Quick spec for Hardcore/Ironman Mode - January 2026*
