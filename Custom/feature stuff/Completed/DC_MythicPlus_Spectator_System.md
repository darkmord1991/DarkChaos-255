# DarkChaos Mythic+ Spectator System

## Overview

The M+ Spectator System allows players to watch live Mythic+ dungeon runs in real-time. Built upon the ArenaSpectator framework, it provides comprehensive spectating functionality including invite codes, guild broadcasts, replay recording, and HUD synchronization.

**File Location:** `src/server/scripts/DC/MythicPlus/dc_mythic_spectator.cpp`

---

## Feature Highlights

### 🎥 Live Spectating
- Watch active M+ runs in real-time
- Invisible GM mode for non-intrusive viewing
- Follow specific players with camera binding
- See boss progress, timer, and death count

### 🔗 Invite System
- Generate shareable invite codes (6-character alphanumeric)
- Configurable expiration (default: 1 hour)
- Limited or unlimited uses per code
- Direct player invites with clickable links
- Guild-wide broadcast invitations

### 📹 Replay System
- Automatic recording of M+ runs
- Event-based timeline (boss kills, deaths, completions)
- Database persistence with configurable storage limit
- Replay browser with search functionality

### 📊 HUD Synchronization
- Mirror dungeon worldstates to spectators
- Timer display sync
- Boss/trash kill count updates
- Death counter synchronization

### 🎭 Stream Mode (Privacy)
- **Mode 0:** Normal - all names visible
- **Mode 1:** Names Hidden - "Player 1", "Player 2", etc.
- **Mode 2:** Full Anonymous - class icons only

---

## Chat Commands

| Command | Permission | Description |
|---------|------------|-------------|
| `.spectate list` | Player | List all active M+ runs available for spectating |
| `.spectate join <ID>` | Player | Start spectating a run by instance ID |
| `.spectate player <name>` | Player | Spectate whichever run a player is in |
| `.spectate watch <name>` | Player | Switch camera to follow another player |
| `.spectate leave` | Player | Stop spectating and return to saved position |
| `.spectate code <CODE>` | Player | Join a run using an invite code |
| `.spectate invite [mins] [uses]` | Player | Generate an invite code (default: 30min, 10 uses) |
| `.spectate guild` | Player | Broadcast spectate invite to your guild |
| `.spectate replays [limit]` | Player | List recent recorded replays |
| `.spectate replay <ID>` | Player | Watch a recorded replay |
| `.spectate stream [mode]` | Moderator | Toggle stream mode (privacy) |
| `.spectate reload` | Admin | Reload configuration |

**Shortcut:** `.mspec` can be used instead of `.spectate`

---

## Configuration Options

Located in `darkchaos-custom.conf.dist` under **Section 4: Mythic+ Dungeon System**

```ini
# Master toggle
MythicSpectator.Enable = 1

# Core settings
MythicSpectator.AllowWhileInProgress = 1    # Allow joining mid-run
MythicSpectator.RequireSameRealm = 0        # Cross-realm restriction
MythicSpectator.AnnounceNewSpectators = 1   # Notify run participants
MythicSpectator.MaxSpectatorsPerRun = 50    # Maximum viewers per run
MythicSpectator.UpdateIntervalMs = 1000     # Broadcast update frequency
MythicSpectator.MinKeystoneLevel = 2        # Minimum key level to spectate
MythicSpectator.AllowPublicListing = 1      # Show in .spectate list

# Privacy
MythicSpectator.StreamModeEnabled = 1       # Allow stream mode
MythicSpectator.DefaultStreamMode = 0       # Default privacy level

# Invite links
MythicSpectator.InviteLinks.Enable = 1
MythicSpectator.InviteLinks.ExpireSeconds = 3600

# Replay system
MythicSpectator.Replay.Enable = 1
MythicSpectator.Replay.MaxStoredRuns = 100
MythicSpectator.Replay.RecordPositions = 0  # Position tracking (heavy)
MythicSpectator.Replay.RecordCombatLog = 0  # Combat log (heavy)

# HUD sync
MythicSpectator.SyncHudToSpectators = 1
```

---

## SQL Database Tables

### `dc_mythic_spectator_replays`
Stores recorded replay data for M+ runs.

```sql
CREATE TABLE IF NOT EXISTS `dc_mythic_spectator_replays` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `map_id` INT UNSIGNED NOT NULL,
    `keystone_level` TINYINT UNSIGNED NOT NULL,
    `leader_name` VARCHAR(12) NOT NULL,
    `start_time` BIGINT UNSIGNED NOT NULL,
    `end_time` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `completed` TINYINT(1) NOT NULL DEFAULT 0,
    `replay_data` LONGTEXT NOT NULL,
    PRIMARY KEY (`id`),
    INDEX `idx_start_time` (`start_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

---

## Architecture

### Key Classes

| Class | Purpose |
|-------|---------|
| `MythicSpectatorManager` | Singleton managing all spectating state |
| `MythicSpectatorConfig` | Configuration holder with hot-reload |
| `SpectateableRun` | Active M+ run data structure |
| `SpectatorState` | Per-spectator tracking (position, target, mode) |
| `SpectatorInvite` | Invite code management |
| `RunReplay` | Replay recording and serialization |

### Integration Points

- **MythicPlusRunManager:** Queries active runs, timer state, boss kills
- **ArenaSpectator Framework:** Bind sight spell (6741), viewpoint handling
- **Guild System:** Guild chat broadcast for invites
- **Map Manager:** Instance lookups for teleportation

---

## Future Improvements

### Short-term
- [ ] Add spectator chat channel (spectators can chat with each other)
- [ ] Implement death spectator cam (camera flies to death location)
- [ ] Add "watch random" feature for discovering runs
- [ ] Spectator count display on M+ leaderboards

### Medium-term
- [ ] Full replay playback with ghost player simulation
- [ ] VOD-style controls (pause, rewind, speed control)
- [ ] Integration with addon for enhanced spectator UI
- [ ] Automatic highlight detection (clutch heals, big pulls)

### Long-term
- [ ] Cross-server spectating (for linked realms)
- [ ] Twitch/Discord integration for stream notifications
- [ ] Machine learning for "best moments" compilation
- [ ] Commentary system for casters

---

## Event System (for Replays)

Recorded event types:
- `RUN_START` - Run initialization with metadata
- `RUN_END` - Completion or failure
- `BOSS_KILL` - Boss defeated with timestamp
- `PLAYER_DEATH` - Death event with killer info
- `WIPE` - Full party wipe
- `KEY_UPGRADE` - Timer completion (key upgraded)

---

## Notes

- Spectators are placed in GM mode for invisibility
- Original position is saved and restored on leave
- Minimum keystone level prevents spam of low-key spectating
- Invite codes use non-confusing characters (no 0/O, 1/I/l)
- Replays are JSON serialized for flexibility
