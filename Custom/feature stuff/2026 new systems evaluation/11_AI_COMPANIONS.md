# AI Companion System (Playerbots)

**Priority:** B3 (Medium)  
**Effort:** High (4-6 weeks)  
**Impact:** Medium  
**Client Required:** No  
**Available Module:** `mod-playerbots`

---

## Overview

AI-controlled party members that can assist solo players in dungeons, leveling, and basic content. Based on mod-playerbots.

---

## Available Module: mod-playerbots

**GitHub:** [azerothcore/mod-playerbots](https://github.com/azerothcore/mod-playerbots)

### Module Features
- Create bot accounts
- Bots follow commands
- Can level, dungeon, raid
- Basic AI for combat
- Configurable behavior

### What DC Should Add
- Limit to certain content (not M+)
- Bot "styles" (tank, healer, dps presets)
- Quest assistance mode
- Daily bot "energy" system

---

## DC Bot Specification

### Bot Types

| Type | Role | AI Priority |
|------|------|-------------|
| Guardian | Tank | Threat, survival |
| Healer | Heal | Party HP, mana management |
| Striker | DPS | Damage rotation |
| Support | Buff/CC | Buffs, interrupts |

### Restrictions

| Content | Bots Allowed? |
|---------|---------------|
| Open World | ✅ Yes |
| Normal Dungeons | ✅ Yes |
| Heroic Dungeons | ✅ Yes (limited) |
| Mythic+ | ❌ No |
| HLBG | ❌ No |
| Raids | ✅ LFR only |
| Arena/BG | ❌ No |

### Bot Energy System

- 100 energy per day
- 1 energy per minute of bot use
- Encourages grouping with real players
- Premium/vote reward = bonus energy

---

## Implementation

### Phase 1 (Week 1-2)
- Integrate mod-playerbots
- Configure restrictions
- Test stability

### Phase 2 (Week 3-4)
- Bot preset templates
- Energy system
- UI for bot control

### Phase 3 (Week 5-6)
- Advanced AI tweaks
- Quest assistance
- Performance optimization

---

*Quick spec for AI Companions - January 2026*
