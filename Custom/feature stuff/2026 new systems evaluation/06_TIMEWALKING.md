# Timewalking System

**Priority:** A2 (High)  
**Effort:** Medium (3-4 weeks)  
**Impact:** High  
**Client Required:** No  
**Base Reference:** Warmane implementation, mod-autobalance

---

## Overview

Scale old dungeons/raids to current endgame level, making classic content relevant again. Players queue and get appropriate rewards.

---

## Why This Feature?

- **Content Recycling**: Tons of unused dungeons at max level
- **Nostalgia**: Players love revisiting old content
- **Easy Wins**: Dungeon already exists, just scale it
- **Variety**: More endgame options

---

## Implementation Approach

### Using mod-autobalance Base

`mod-autobalance` already scales dungeon creatures. Timewalking extends this:

```cpp
// Timewalking wrapper around autobalance
class TimewalkingMgr
{
    void EnableTimewalking(uint32 mapId, uint32 targetLevel);
    void ScaleCreatures(Map* map, uint32 targetLevel);
    void ScaleLoot(Creature* creature, uint32 targetLevel);
    void GrantTimewalkingRewards(Player* player);
};
```

### Target Dungeons (Phase 1)

| Dungeon | Original Level | Timewalking Level |
|---------|----------------|-------------------|
| Deadmines | 15-21 | 200 |
| Shadowfang Keep | 16-26 | 210 |
| Scarlet Monastery (all) | 26-45 | 220 |
| Scholomance | 58-60 | 230 |
| Stratholme | 58-60 | 235 |
| Blackrock Depths | 52-60 | 225 |

### Rewards

| Completion | Reward |
|------------|--------|
| First of Day | Upgrade Token (T1) |
| Weekly Bonus | Upgrade Token (T2) |
| Timewalking Currency | Spend at vendor |
| Battle Pass XP | +300 per run |

---

## Queue System

- Separate queue from regular dungeons
- Random or specific dungeon selection
- Weekly "featured" dungeon with bonus

---

## Technical Notes

1. Create copy of dungeon creature templates for timewalking
2. Apply stat multipliers based on target level
3. Modify loot tables for level-appropriate drops
4. Track weekly lockout separately

---

*Quick spec for Timewalking - January 2026*
