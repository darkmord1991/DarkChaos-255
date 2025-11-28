# Duel Reset System

**Priority:** S2 (Critical - Quick Win)  
**Effort:** Very Low (1 day)  
**Impact:** Medium  
**Base:** mod-duel-reset (AzerothCore module)

---

## Overview

Automatically restore health, mana, cooldowns, and remove debuffs after duels. This quality-of-life feature eliminates downtime between duels and encourages PvP practice.

---

## Why It Fits DarkChaos-255

### Integration Points
| System | Integration |
|--------|-------------|
| **HLBG** | Same reset logic for HLBG deaths |
| **Phased Duels** | Required for arena-style dueling |
| **Prestige** | Prestige players get faster reset |

### Benefits
- Instant duel reset (no drinking/healing)
- Encourages dueling culture
- No balance impact
- Plug-and-play module
- Required for duel tournaments

---

## Features

### 1. **Full Reset on Duel End**
- Health restored to 100%
- Mana/Energy/Rage restored
- All cooldowns reset
- All debuffs removed
- Pet health restored

### 2. **Configurable Options**
- Enable/disable per zone
- Optional: Only reset winner/loser
- Optional: Add short immunity
- Optional: Announce duel results

### 3. **Arena-Style Reset**
- Both players reset simultaneously
- Ready check before next duel
- Spectator-friendly

---

## Implementation

### Option A: Use Existing Module
```bash
# Clone the module
git clone https://github.com/azerothcore/mod-duel-reset.git modules/mod-duel-reset

# Rebuild server
./acore.sh compiler build
```

### Option B: Custom Eluna Script
```lua
-- Duel Reset via Eluna
local function OnDuelEnd(event, winner, loser)
    -- Reset winner
    winner:SetHealth(winner:GetMaxHealth())
    winner:SetPower(winner:GetPowerType(), winner:GetMaxPower(winner:GetPowerType()))
    winner:RemoveAllAuras()
    
    -- Reset loser
    loser:SetHealth(loser:GetMaxHealth())
    loser:SetPower(loser:GetPowerType(), loser:GetMaxPower(loser:GetPowerType()))
    loser:RemoveAllAuras()
    
    -- Reset cooldowns (requires C++ hook or extended Eluna)
    -- winner:ResetAllCooldowns()
    -- loser:ResetAllCooldowns()
end

RegisterPlayerEvent(13, OnDuelEnd) -- PLAYER_EVENT_ON_DUEL_END
```

### Configuration
```conf
# worldserver.conf
DuelReset.Enable = 1
DuelReset.Cooldowns = 1          # Reset cooldowns
DuelReset.HP = 1                 # Reset health
DuelReset.Mana = 1               # Reset mana/resources
DuelReset.Auras = 1              # Remove debuffs
DuelReset.Pet = 1                # Reset pet
DuelReset.Immunity = 3           # Seconds of immunity after duel
DuelReset.Announce = 1           # Announce winner
```

---

## Zone Configuration

```sql
-- Disable reset in specific zones (if needed)
INSERT INTO duel_reset_zones (zone_id, enabled) VALUES
(1, 1),    -- Durotar - enabled
(12, 1),   -- Elwynn Forest - enabled
(3430, 0), -- Eversong Woods - disabled (example)
```

---

## Commands

```
.duel reset           - Manually reset yourself (if allowed)
.duel stats           - Show your duel W/L record
.duel challenge <n>   - Challenge player by name
```

---

## Timeline

| Task | Duration |
|------|----------|
| Install module | 30 minutes |
| Configuration | 1 hour |
| Testing | 2 hours |
| Documentation | 30 minutes |
| **Total** | **~4 hours** |

---

## Future Enhancements

1. **Duel Leaderboard** - Track W/L ratios
2. **Duel Betting** - Bet tokens on duels
3. **Duel Arenas** - Designated duel zones
4. **Spectator Mode** - Watch ongoing duels
5. **Ranked Duels** - MMR system for duels
