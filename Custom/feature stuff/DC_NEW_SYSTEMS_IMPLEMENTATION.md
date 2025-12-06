# DarkChaos Systems Implementation Summary

## Overview

This document summarizes the implementation of three new systems for DarkChaos-255:
1. **Phased Dueling System**
2. **Mythic+ Spectator System** (with Invite Links, Replay, HUD Sync)
3. **AoE Loot Extensions** (with Client Addon)

---

## 1. Phased Dueling System

**Location:** `src/server/scripts/DC/PhasedDuels/dc_phased_duels.cpp`

### Core Features
- **Isolated Phase Dueling**: Players are moved to unique phases during duels, preventing interference
- **State Restoration**: Full HP/mana/cooldown reset after duels end
- **Pet Handling**: Resurrects and heals pets post-duel
- **Statistics Tracking**: Comprehensive W/L/D tracking with database persistence

### Commands
| Command | Access | Description |
|---------|--------|-------------|
| `.duel stats [player]` | Player | View your duel statistics |
| `.duel top [count]` | Player | View server-wide leaderboard |
| `.duel reset <player>` | Admin | Reset a player's duel stats |
| `.duel reload` | Admin | Reload configuration |

### DC-Specific Enhancements
1. **Arena Zone Restriction**: Optional config to only enable phased duels in designated zones
2. **Class Power Exceptions**: Option to exclude rogues/warriors from power restoration
3. **Damage Tracking**: Records total damage dealt/taken per duel
4. **Duration Records**: Tracks longest duel and fastest win times
5. **Phase Radius Check**: Intelligent phase allocation based on nearby occupied phases

### Database Files
- **Character DB**: `Custom/Custom feature SQLs/dc_phased_duels_char.sql`
- **World DB**: `Custom/Custom feature SQLs/dc_phased_duels_world.sql`

### Future Extension Ideas
- [ ] **Tournament Mode**: Automated bracket tournaments with rankings
- [ ] **Rated Duels**: ELO-based matchmaking system
- [ ] **Spectator Support**: Allow watching duels (integrate with Spectator system)
- [ ] **Class Matchup Analysis**: Server-wide class vs class win rate statistics
- [ ] **Duel Arenas**: Custom instanced duel arenas with leaderboards
- [ ] **Wager System**: Allow betting gold/tokens on duel outcomes

---

## 2. Mythic+ Spectator System

**Location:** `src/server/scripts/DC/MythicPlus/dc_mythic_spectator.h` and `.cpp`

### Core Features
- **Live Run Listing**: View all active M+ runs available for spectating
- **Real-time Updates**: Periodic broadcasts of run progress to spectators
- **Camera Control**: Bind viewpoint to specific players
- **Stream Mode**: Anonymous viewing for content creators
- **Invite Links**: Shareable codes for private spectator access
- **Replay Recording**: Record and playback completed runs
- **HUD Synchronization**: Spectators see M+ timer and boss progress

### Commands
| Command | Access | Description |
|---------|--------|-------------|
| `.spectate list` | Player | List available M+ runs |
| `.spectate join <ID>` | Player | Join a run by instance ID |
| `.spectate code <code>` | Player | Join via invite code |
| `.spectate player <name>` | Player | Spectate a specific player's run |
| `.spectate watch <name>` | Player | Switch camera to another player |
| `.spectate leave` | Player | Stop spectating |
| `.spectate invite [mins] [uses]` | Player | Generate invite link (default: 30 mins, 10 uses) |
| `.spectate guild` | Player | Broadcast invite to guild |
| `.spectate replays [limit]` | Player | List recent replays |
| `.spectate replay <ID>` | Player | Watch a saved replay |
| `.spectate stream [mode]` | Mod | Toggle stream mode (0/1/2) |
| `.spectate reload` | Admin | Reload configuration |

### Invite Link System
- 8-character alphanumeric codes
- Configurable expiration (default 30 minutes)
- Limited uses per link (default 10)
- Automatically cleans up expired invites

### Replay System
- Automatic recording of all runs (configurable)
- Events captured: player positions, spell casts, boss kills, deaths
- Database storage with configurable retention
- Playback support (basic implementation)

### HUD Synchronization
- Sends worldstates to spectators for M+ UI display
- Timer, boss progress, and key level visible
- Integrates with MythicPlusRunManager

### Stream Modes
| Mode | Description |
|------|-------------|
| 0 | Normal (all names visible) |
| 1 | Names Hidden (players shown as "Player 1", "Player 2") |
| 2 | Full Anonymous (class icons only) |

### Database Files
- **Character DB**: `Custom/Custom feature SQLs/dc_mythic_spectator_char.sql`
  - Session logs, player settings, popularity stats
  - Replay storage, invite links
- **World DB**: `Custom/Custom feature SQLs/dc_mythic_spectator_world.sql`
  - Spectator NPCs, viewing positions, localized strings

---

## 3. AoE Loot Extensions

**Location:** `src/server/scripts/DC/dc_aoeloot_extensions.cpp`

### Core Features
- **Quality Filtering**: Only loot items above a certain quality threshold
- **Profession Integration**: Auto-skin/mine/herb after looting
- **Smart Loot Preferences**: Prioritize spec-appropriate gear
- **Detailed Statistics**: Track comprehensive loot data per player
- **Client Addon Integration**: Settings panel via addon messages

### Commands
| Command | Access | Description |
|---------|--------|-------------|
| `.lootpref toggle` | Player | Enable/disable AoE loot |
| `.lootpref quality <0-6>` | Player | Set minimum quality filter |
| `.lootpref skin` | Player | Toggle auto-skinning |
| `.lootpref smart` | Player | Toggle smart loot prioritization |
| `.lootpref ignore <itemId>` | Player | Add item to ignore list |
| `.lootpref unignore <itemId>` | Player | Remove from ignore list |
| `.lootpref stats` | Player | View detailed loot statistics |
| `.lootpref reload` | Admin | Reload configuration |

### Client Addon: DC_AoELoot_Settings
**Location:** `Custom/Client addons needed/DC_AoELoot_Settings/`

A lightweight addon providing a settings UI for AoE loot preferences:
- **Slash commands**: `/aoeloot`, `/dcaoe`, `/aoeloot stats`
- **Features**:
  - Toggle AoE loot on/off
  - Set minimum quality filter (color-coded buttons)
  - Toggle auto-skin/mine/herb
  - Toggle smart loot detection
  - Toggle auto-vendor poor items
  - Adjustable loot range slider (15-100 yards)
  - View loot statistics

### DC-Specific Enhancements
1. **Mythic+ Range Bonus**: 1.5x loot range in M+ dungeons
2. **Auto-Vendor Poor Items**: Automatically sell gray items for gold
3. **Upgrade Detection**: Highlights items that are gear upgrades
4. **Per-Player Preferences**: Saved to database, persists across sessions
5. **Raid Mode**: Increased max corpses (25) in raid environments
6. **Ignored Items List**: Blacklist specific items from AoE loot
7. **Addon Message Support**: Server-side handling for client addon communication

### Database Files
- **Character DB**: `Custom/Custom feature SQLs/dc_aoeloot_extensions_char.sql`
  - Player preferences, detailed stats, accumulated gold
  - Quality distribution, session tracking
- **World DB**: `Custom/Custom feature SQLs/dc_aoeloot_extensions_world.sql`
  - Global config, zone modifiers, item blacklist
  - Smart loot categories

---

## Configuration Summary

All configuration options are in `Custom/Config files/darkchaos-custom.conf.dist`:

| Section | Config Prefix | Description |
|---------|---------------|-------------|
| 10 | `PhasedDuels.*` | Phased Dueling system settings |
| 11 | `MythicSpectator.*` | M+ Spectator system settings |
| 12 | `AoELoot.Extensions.*` | AoE Loot extension settings |

---

## Database Setup

### Character Database (`acore_characters`)
1. `Custom/Custom feature SQLs/dc_phased_duels_char.sql`
2. `Custom/Custom feature SQLs/dc_mythic_spectator_char.sql`
3. `Custom/Custom feature SQLs/dc_aoeloot_extensions_char.sql`

### World Database (`acore_world`)
1. `Custom/Custom feature SQLs/dc_phased_duels_world.sql`
2. `Custom/Custom feature SQLs/dc_mythic_spectator_world.sql`
3. `Custom/Custom feature SQLs/dc_aoeloot_extensions_world.sql`

---

## Client Addons Required

### DC_AoELoot_Settings
**Installation:** Copy `Custom/Client addons needed/DC_AoELoot_Settings/` to `Interface/AddOns/`

| File | Purpose |
|------|---------|
| `DC_AoELoot_Settings.toc` | Addon manifest |
| `DC_AoELoot_Settings.lua` | Main addon code |

---

## Script Registration

Add to your script loader:

```cpp
void AddSC_dc_phased_duels();
void AddSC_dc_mythic_spectator();
void AddSC_dc_aoeloot_extensions();

// In AddDCScripts() or equivalent:
AddSC_dc_phased_duels();
AddSC_dc_mythic_spectator();
AddSC_dc_aoeloot_extensions();
```

---

## Integration Points

### Phased Duels
- Hooks: `OnDuelStart`, `OnDuelEnd`, `OnLogin`, `OnLogout`
- No core modifications required

### M+ Spectator
- Hooks: `OnUpdate` (WorldScript), `OnLogout`, `OnMapChanged`, `OnAddonMessage`
- Integration with `MythicPlusRunManager::GetState()` for run data
- Uses ArenaSpectator bindsight spell (6277)
- Sends worldstates for HUD synchronization

### AoE Loot Extensions
- Extends existing `ac_aoeloot.cpp` system
- Hooks: `OnLogin`, `OnLogout`, `OnAddonMessage`
- Optional integration with skinning/mining/herbalism
- Addon message protocol: `DCAOE` prefix

---

## Summary

These three systems add significant quality-of-life and engagement features:

1. **Phased Duels** - Eliminates duel griefing and adds competitive tracking
2. **M+ Spectator** - Enables community engagement with high-key runs, invite links, replay recording, and HUD sync
3. **AoE Loot Ext** - Reduces tedium and adds smart loot management with client addon support

All systems follow DC patterns, use configuration-driven design, and persist data to the database for cross-session continuity.
