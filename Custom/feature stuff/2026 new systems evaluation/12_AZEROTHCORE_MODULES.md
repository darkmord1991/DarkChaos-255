# AzerothCore Available Modules Analysis

**Purpose:** Evaluate available modules from AzerothCore catalogue for DC integration  
**Last Updated:** January 2026

---

## Module Categories

### ✅ Already Integrated in DC

| Module | Purpose | DC Implementation |
|--------|---------|-------------------|
| `mod-eluna` | Lua scripting | Integrated in DC/AIO |
| `mod-transmog` | Transmogrification | Standard integration |
| `mod-cfbg` | Cross-faction BGs | Merged into core |
| `mod-autobalance` | Dungeon scaling | May be integrated |

---

## High Priority - Recommended Integration

### 1. mod-guildhouse
**GitHub:** [azerothcore/mod-guildhouse](https://github.com/azerothcore/mod-guildhouse)  
**Stars:** 35 | **Forks:** 55 | **Activity:** Active

**Features:**
- Teleport to private guild instance
- Purchase NPCs for guild hall (bank, vendor, trainer, etc.)
- Guild-specific vendor items
- Customizable locations

**DC Integration Notes:**
- Perfect base for Guild Housing system
- Can extend with seasonal decorations
- Add custom NPC unlocks via progression

**Effort:** Low-Medium (mostly configuration)

---

### 2. mod-arena-3v3-solo-queue
**GitHub:** [azerothcore/mod-arena-3v3-solo-queue](https://github.com/azerothcore/mod-arena-3v3-solo-queue)  
**Stars:** 7 | **Forks:** 16 | **Activity:** Active

**Features:**
- Solo queue for 3v3 arena
- MMR-based matchmaking
- Automatic team formation

**DC Integration Notes:**
- Adds competitive solo PvP option
- Can integrate with seasonal rating system
- Pairs with existing HLBG for PvP variety

**Effort:** Low (drop-in module)

---

### 3. mod-1v1-arena
**GitHub:** [azerothcore/mod-1v1-arena](https://github.com/azerothcore/mod-1v1-arena)  
**Stars:** 22 | **Forks:** 60 | **Activity:** Active

**Features:**
- 1v1 arena support
- Separate arena bracket
- Anti-heal/immune protection for balance

**DC Integration Notes:**
- Popular request for PvP servers
- Leaderboard integration potential
- Could be tournament format base

**Effort:** Low (drop-in module)

---

### 4. mod-playerbots
**GitHub:** [azerothcore/mod-playerbots](https://github.com/azerothcore/mod-playerbots)  
**Stars:** High | **Activity:** Very Active

**Features:**
- AI-controlled player bots
- Can level, dungeon, raid
- Follow and assist players
- Multiple bot commands

**DC Integration Notes:**
- Enables solo dungeon content
- Fills groups for low-pop times
- Can be restricted to certain content

**Effort:** Medium (configuration + balance tuning)

---

### 5. mod-zone-difficulty
**GitHub:** [azerothcore/mod-zone-difficulty](https://github.com/azerothcore/mod-zone-difficulty)  
**Stars:** 28 | **Forks:** 33 | **Activity:** Active

**Features:**
- Per-zone difficulty modifiers
- Separate open world from instances
- Configurable health/damage multipliers
- Reward scaling

**DC Integration Notes:**
- Great for 160-255 zone difficulty
- Can create "hard mode" zones
- Synergizes with progression

**Effort:** Low-Medium

---

## Medium Priority - Consider Integration

### 6. mod-progression-system
**GitHub:** [azerothcore/mod-progression-system](https://github.com/azerothcore/mod-progression-system)  
**Stars:** 71 | **Forks:** 68 | **Activity:** Active

**Features:**
- ChromieCraft-style progression
- Content gating by level bracket
- Progressive patch unlocking

**DC Integration Notes:**
- DC already has custom progression
- Could use for seasonal fresh starts
- Useful for progressive server mode

**Effort:** Medium (significant configuration)

---

### 7. mod-duel-reset
**GitHub:** [azerothcore/mod-duel-reset](https://github.com/azerothcore/mod-duel-reset)  
**Stars:** 20 | **Forks:** 39 | **Activity:** Active

**Features:**
- Reset HP/mana after duel
- Restore cooldowns
- Remove debuffs

**DC Integration Notes:**
- Simple QoL improvement
- Already have phased duels
- Could enhance existing system

**Effort:** Very Low (drop-in)

---

### 8. mod-reward-played-time
**GitHub:** [azerothcore/mod-reward-played-time](https://github.com/azerothcore/mod-reward-played-time)  
**Stars:** 17 | **Forks:** 34 | **Activity:** Active

**Features:**
- Rewards based on /played time
- Configurable milestones
- Multiple reward types

**DC Integration Notes:**
- Can complement Battle Pass
- Retention mechanic
- Simple engagement boost

**Effort:** Low

---

### 9. mod-system-vip
**GitHub:** [azerothcore/mod-system-vip](https://github.com/azerothcore/mod-system-vip)  
**Stars:** 3 | **Forks:** 17 | **Activity:** Moderate

**Features:**
- VIP account perks
- Morphing, mobile bank, mobile AH
- Custom commands
- Timed VIP expiration

**DC Integration Notes:**
- Monetization option if needed
- Can be vote reward
- Premium perks without P2W

**Effort:** Low

---

### 10. mod-arena-replay
**GitHub:** [azerothcore/mod-arena-replay](https://github.com/azerothcore/mod-arena-replay)  
**Stars:** 6 | **Forks:** 9 | **Activity:** Moderate

**Features:**
- Record arena matches
- Playback for spectating
- Save replays to database

**DC Integration Notes:**
- Nice-to-have for PvP
- Tournament review
- Content creation tool

**Effort:** Medium

---

## Low Priority - Future Consideration

| Module | Purpose | Notes |
|--------|---------|-------|
| `mod-ah-bot` | Auction house bot | Already referenced, economic filler |
| `mod-npc-buffer` | Buff NPCs | Already have mall NPCs |
| `mod-npc-morph` | Morph NPC | Cosmetic feature |
| `mod-npc-gambler` | Gambling NPC | Fun server feature |
| `mod-dynamic-xp` | Dynamic XP rates | Already have Hotspot |
| `mod-solocraft` | Solo dungeons | Have autobalance |
| `mod-individual-xp` | Player XP control | Could be useful |

---

## Modules NOT Recommended

| Module | Reason |
|--------|--------|
| `mod-progression-system` | Conflicts with DC seasonal approach |
| `mod-tic-tac-toe` | Too casual/off-theme |
| `mod-morphsummon` | Low impact |

---

## Integration Priority Matrix

| Module | Impact | Effort | Priority |
|--------|--------|--------|----------|
| mod-guildhouse | High | Low-Med | ⭐⭐⭐⭐⭐ |
| mod-arena-3v3-solo-queue | Medium | Low | ⭐⭐⭐⭐ |
| mod-1v1-arena | Medium | Low | ⭐⭐⭐⭐ |
| mod-playerbots | High | Medium | ⭐⭐⭐⭐ |
| mod-zone-difficulty | Medium | Low | ⭐⭐⭐ |
| mod-duel-reset | Low | Very Low | ⭐⭐⭐ |
| mod-reward-played-time | Low | Low | ⭐⭐ |
| mod-system-vip | Low | Low | ⭐⭐ |
| mod-arena-replay | Low | Medium | ⭐ |

---

## Module Installation Guide (General)

```bash
# Clone module into modules directory
cd /path/to/azerothcore/modules
git clone https://github.com/azerothcore/mod-<name>

# Rebuild the server
cd /path/to/azerothcore/build
cmake ..
make -j$(nproc)

# Apply SQL migrations (if any)
mysql -u user -p worldserver < modules/mod-<name>/sql/world/*.sql
mysql -u user -p characters < modules/mod-<name>/sql/characters/*.sql

# Configure in worldserver.conf
# Add module-specific settings
```

---

*Module analysis for Dark Chaos 2026 planning - January 2026*
