# DarkChaos Phased Duels System

## Overview

The Phased Duels System creates isolated phases for dueling players, preventing interference from bystanders. When a duel starts, both participants are moved to a unique phase, ensuring a fair and private fight. After the duel, players are restored to full health with cooldowns reset.

**File Location:** `src/server/scripts/DC/PhasedDuels/dc_phased_duels.cpp`

---

## Feature Highlights

### 🔒 Isolated Phase Dueling
- Players are moved to a unique phase when duel starts
- Bystanders cannot see or interfere with the duel
- Duel flag is also phased for proper arbitration
- Automatic return to normal phase on duel end

### ❤️ Full State Restoration
- Health reset to 100% after duel
- Mana/Energy/Rage/Runic Power restored
- All spell cooldowns cleared
- Pet health restored (for hunters, warlocks)
- Optional: exclude rogue/warrior resource restoration

### 📊 Statistics Tracking
- Win/Loss/Draw record
- Total damage dealt and taken
- Longest duel duration
- Fastest win time
- Last opponent tracking
- Database persistence

### 🏟️ Arena Zone Support
- Optional restriction to specific zone
- Great for designated duel zones (e.g., Gurubashi Arena)
- Configurable zone ID

---

## Chat Commands

| Command | Permission | Description |
|---------|------------|-------------|
| `.duel stats [player]` | Player | View duel statistics (yours or another player's) |
| `.duel top [count]` | Player | View top duelists leaderboard (default: 10) |
| `.duel reset <player>` | Admin | Reset a player's duel statistics |
| `.duel reload` | Admin | Reload configuration |

---

## Configuration Options

Located in `darkchaos-custom.conf.dist` under **Section 12: Phased Dueling System**

```ini
# Master toggle
PhasedDuels.Enable = 1

# Login announcement
PhasedDuels.AnnounceOnLogin = 1

# State restoration
PhasedDuels.ResetHealth = 1
PhasedDuels.ResetCooldowns = 1
PhasedDuels.RestorePower = 1
PhasedDuels.RestorePetHealth = 1
PhasedDuels.ExcludeRogueWarriorPower = 0   # Don't restore energy/rage

# Statistics
PhasedDuels.TrackStatistics = 1

# Restrictions
PhasedDuels.AllowInDungeons = 0            # Disable phased duels in dungeons
PhasedDuels.ArenaZoneId = 0                # 0 = allow everywhere, or specific zone ID

# Phase management
PhasedDuels.PhaseRadius = 100.0            # Radius to check for occupied phases
PhasedDuels.MaxPhaseId = 2147483647        # Maximum phase ID (0x7FFFFFFF)
```

---

## SQL Database Tables

### `dc_duel_statistics`
Stores duel statistics per player.

```sql
CREATE TABLE IF NOT EXISTS `dc_duel_statistics` (
    `player_guid` INT UNSIGNED NOT NULL,
    `wins` INT UNSIGNED NOT NULL DEFAULT 0,
    `losses` INT UNSIGNED NOT NULL DEFAULT 0,
    `draws` INT UNSIGNED NOT NULL DEFAULT 0,
    `total_damage_dealt` INT UNSIGNED NOT NULL DEFAULT 0,
    `total_damage_taken` INT UNSIGNED NOT NULL DEFAULT 0,
    `longest_duel_seconds` INT UNSIGNED NOT NULL DEFAULT 0,
    `shortest_win_seconds` INT UNSIGNED NOT NULL DEFAULT 4294967295,
    `last_duel_time` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `last_opponent_guid` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`player_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

---

## How Phasing Works

### Phase Selection Algorithm
1. Get duel flag location
2. Search for all players within `PhaseRadius` yards
3. Collect all phases currently in use
4. Find first available phase ID (powers of 2, starting at 2)
5. Skip phase 1 (normal world phase)

### Phase Lifecycle
```
Duel Request → Duel Accept → Find Free Phase → Phase Players + Flag
                    ↓
               Duel Fight
                    ↓
Duel End → Restore Normal Phase → Reset Health/Power/Cooldowns
                    ↓
           Update Statistics → Persist to Database
```

---

## Architecture

### Key Classes

| Class/Struct | Purpose |
|--------------|---------|
| `PhasedDuelsConfig` | Configuration singleton |
| `DuelStats` | Per-player statistics structure |
| `ActiveDuel` | Tracking active duel state |
| `DCPhasedDuelsPlayerScript` | Duel event handlers |
| `DCPhasedDuelsCommandScript` | Chat command handlers |

### Key Functions

| Function | Purpose |
|----------|---------|
| `GetNormalPhase()` | Determine player's base phase mask |
| `FindFreePhase()` | Find an unused phase for dueling |
| `RecordDuelStart()` | Initialize duel tracking |
| `RecordDuelEnd()` | Finalize stats and cleanup |
| `RestorePlayerState()` | Reset health/power/cooldowns |

### Global State

| Variable | Purpose |
|----------|---------|
| `sPlayerDuelStats` | Map of player GUID → DuelStats |
| `sActiveDuels` | Map of player GUID → ActiveDuel |
| `sUsedPhases` | Set of currently occupied phase IDs |

---

## Event Hooks

| Hook | Trigger |
|------|---------|
| `OnLogin` | Load statistics, show announcement |
| `OnLogout` | Cleanup player data from memory |
| `OnDuelStart` | Phase players, record start time |
| `OnDuelEnd` | Restore phase, reset state, update stats |

---

## Statistics Display Example

```
========== DUEL STATISTICS ==========
Player: Arthas
Record: 42 W / 15 L / 3 D (70.0% Win Rate)
Total Damage Dealt: 1,234,567
Total Damage Taken: 456,789
Longest Duel: 312 seconds
Fastest Win: 8 seconds
======================================
```

---

## Future Improvements

### Short-term
- [ ] Add duel request cooldown (prevent spam)
- [ ] Spectator system for phased duels
- [ ] Betting system with gold wagers
- [ ] Duel announcements for high-ranked players

### Medium-term
- [ ] Ranked duel seasons with rewards
- [ ] Class-specific leaderboards
- [ ] Duel replay recording (similar to M+ spectator)
- [ ] Achievement integration (100 wins, fastest win, etc.)

### Long-term
- [ ] Tournament mode with brackets
- [ ] Team duels (2v2, 3v3 phased)
- [ ] Cross-realm duel challenges
- [ ] Machine learning for skill rating (ELO-like)

---

## Zone Restriction Examples

To restrict duels to specific zones, use:

| Zone | Zone ID |
|------|---------|
| Gurubashi Arena | 2177 |
| Ring of Trials (Nagrand) | 3698 |
| Circle of Blood (Blade's Edge) | 3702 |
| Dalaran Sewers | 4378 |

---

## Notes

- Phase 1 is reserved for normal world visibility
- Phase IDs are powers of 2 (2, 4, 8, 16, 32...)
- Maximum safe phase ID is 0x7FFFFFFF
- Pets are automatically restored for hunter happiness
- Damage tracking requires custom combat hooks (partially implemented)
- Statistics are loaded on login, saved on duel end
- Draws occur when duel is interrupted or both players leave
