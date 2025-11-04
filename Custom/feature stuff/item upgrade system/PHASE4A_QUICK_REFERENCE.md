# Phase 4A: Quick Reference Guide

## Cost Formulas

### Single Level Upgrade Cost
```
Cost = Base_Cost * (1.1 ^ current_level)
```

| Tier | Base Essence | Base Tokens | Level 0 | Level 5 | Level 10 | Level 15 |
|------|---|---|---|---|---|---|
| Common | 10 | 5 | 10 | 16 | 26 | 43 |
| Uncommon | 25 | 10 | 25 | 40 | 65 | 104 |
| Rare | 50 | 15 | 50 | 80 | 130 | 209 |
| Epic | 100 | 25 | 100 | 161 | 259 | 418 |
| Legendary | 200 | 50 | 200 | 322 | 518 | 836 |

### Cumulative Costs (0 → Target Level)

| Tier | → Level 5 | → Level 10 | → Level 15 |
|------|---|---|---|
| Common | 61 E / 30 T | 159 E / 79 T | 414 E / 205 T |
| Uncommon | 153 E / 61 T | 397 E / 159 T | 1035 E / 414 T |
| Rare | 306 E / 92 T | 794 E / 238 T | 2071 E / 621 T |
| Epic | 612 E / 153 T | 1589 E / 397 T | 4142 E / 1035 T |
| Legendary | 1224 E / 306 T | 3178 E / 794 T | 8285 E / 2071 T |

## Stat Multipliers

### Base Multiplier (Any Tier)
```
= 1.0 + (level * 0.025)
```

| Level | Multiplier | Bonus |
|-------|---|---|
| 0 | 1.000x | 0% |
| 5 | 1.125x | +12.5% |
| 10 | 1.250x | +25.0% |
| 15 | 1.375x | +37.5% |

### Tier Adjustment
```
Final = (Base - 1.0) * Tier_Mult + 1.0
```

| Tier | Multiplier | Level 10 Example |
|------|---|---|
| Common | 0.9x | 1.225x (+22.5%) |
| Uncommon | 0.95x | 1.238x (+23.8%) |
| Rare | 1.0x | 1.250x (+25.0%) |
| Epic | 1.15x | 1.288x (+28.8%) |
| Legendary | 1.25x | 1.344x (+34.4%) |

## Item Level Bonuses

### Bonus Per Level
```
Bonus = level * bonus_per_level[tier]
```

| Tier | Per Level | Max Level | Max Bonus |
|------|---|---|---|
| Common | 1.0 | 10 | +10 |
| Uncommon | 1.0 | 12 | +12 |
| Rare | 1.5 | 15 | +22 |
| Epic | 2.0 | 15 | +30 |
| Legendary | 2.5 | 15 | +37 |

### Examples (Base: 385 ilvl)
| Tier | Level | Bonus | Final |
|------|---|---|---|
| Rare | 10 | +15 | 400 |
| Epic | 10 | +20 | 405 |
| Legendary | 15 | +37 | 422 |

## NPC Gossip Options

**Main Menu**:
1. View Upgradeable Items
2. View My Upgrade Statistics
3. How does item upgrading work?
4. Nevermind

**Item Detail**:
- Shows: Level, Stats %, iLvL, Total Investment, Next Cost
- Action: UPGRADE BUTTON (if affordable)

## Admin Commands

### Cost Information
```
.upgrade mech cost 3 5
→ Shows essence/token cost for Rare level 5→6 upgrade
→ Includes cumulative costs
```

### Stat Information
```
.upgrade mech stats 4 10
→ Shows stat multiplier for Epic level 10
→ Base × Tier × Final breakdown
```

### Item Level Information
```
.upgrade mech ilvl 5 15 385
→ Shows ilvl bonus for Legendary level 15 with 385 base
→ Bonus amount and final ilvl
```

### Reset Player Upgrades
```
.upgrade mech reset PlayerName
→ Warns admin, counts items
→ Requires confirmation to execute
```

## Database Queries

### Check Player Upgrades
```sql
SELECT * FROM item_upgrades WHERE player_guid = X;
```

### View Player Stats
```sql
SELECT * FROM player_upgrade_summary WHERE player_guid = X;
```

### Audit Trail
```sql
SELECT * FROM item_upgrade_log WHERE player_guid = X ORDER BY timestamp DESC;
```

### Upgrade Speed
```sql
SELECT * FROM upgrade_speed_stats WHERE player_guid = X;
```

## Configuration Changes

### Adjust Tier Costs (Example: Make Uncommon cheaper)
```sql
UPDATE item_upgrade_costs 
SET base_essence_cost = 15, base_token_cost = 7
WHERE tier_id = 2;
```

### Adjust Stat Scaling (Example: Increase scaling to 3% per level)
```sql
UPDATE item_upgrade_stat_scaling 
SET base_multiplier_per_level = 0.03;
```

### Adjust Item Level Multiplier (Example: Legendary gets 3.0 per level)
```sql
UPDATE item_upgrade_costs 
SET ilvl_multiplier = 3.0 
WHERE tier_id = 5;
```

### Disable Tier (Example: Disable Legendary temporarily)
```sql
UPDATE item_upgrade_costs SET enabled = 0 WHERE tier_id = 5;
```

## Tier Summary Table

| Tier | Name | Max Level | Base E/T | Multipliers | Comments |
|------|------|---|---|---|---|
| 1 | Common | 10 | 10/5 | 0.8x cost, 0.9x stat, 1.0x ilvl | Budget tier, lowest cost |
| 2 | Uncommon | 12 | 25/10 | 1.0x cost, 0.95x stat, 1.0x ilvl | Entry-level |
| 3 | Rare | 15 | 50/15 | 1.2x cost, 1.0x stat, 1.5x ilvl | Balanced |
| 4 | Epic | 15 | 100/25 | 1.5x cost, 1.15x stat, 2.0x ilvl | Higher tier |
| 5 | Legendary | 15 | 200/50 | 2.0x cost, 1.25x stat, 2.5x ilvl | Highest tier |

## Player Interface Flow

```
Talk to NPC
    ↓
[Main Menu]
├─ View Upgradeable Items
│   ↓
│   [Item List] (click item)
│   ↓
│   [Item Detail]
│   ├─ Show current level
│   ├─ Show current stats %
│   ├─ Show current ilvl
│   ├─ Show next cost
│   ├─ Show affordability
│   └─ [UPGRADE] button
│       ↓
│       Perform upgrade, save to DB, show confirmation
│
├─ View My Upgrade Statistics
│   ↓
│   [Stats Summary]
│   ├─ Total items upgraded
│   ├─ Fully upgraded count
│   ├─ Total resources spent
│   ├─ Average stat bonus
│   ├─ Average ilvl gain
│   └─ Last upgrade time
│
├─ How does item upgrading work?
│   ↓
│   [Help Information]
│   ├─ What is upgrading?
│   ├─ Cost structure
│   ├─ Stat scaling
│   ├─ Ilvl bonuses
│   ├─ Escalation mechanic
│   └─ Pro tips
│
└─ Nevermind → Close gossip
```

## Performance Targets

| Operation | Target | Typical |
|---|---|---|
| Cost calculation | <1μs | <1μs |
| Stat scaling | <1μs | <1μs |
| Item level calc | <1μs | <1μs |
| DB player query | <10ms | <5ms |
| DB audit query | <50ms | <20ms |
| NPC gossip load | <100ms | <50ms |

## Troubleshooting

**NPC doesn't show gossip**
- Check script is registered in ScriptLoader
- Check NPC in game matches configured NPC ID
- Check player can see NPC (range, visibility)

**Costs seem wrong**
- Verify tier ID (1-5)
- Verify level (0-14 for next upgrade)
- Check item_upgrade_costs table for multipliers
- Try admin command to verify formula

**Stat bonus seems off**
- Verify tier multiplier in item_upgrade_costs
- Verify base_multiplier_per_level in item_upgrade_stat_scaling
- Calculate manually: (1.0 + level*0.025 - 1.0) * tier_mult + 1.0

**Items not showing as upgradeable**
- Check item quality (must be Uncommon+)
- Check item in correct inventory slot
- Check CanUpgradeItem logic
- Query item_upgrades table for existing state

## Integration Checklist

- [ ] SQL migration executed
- [ ] CMakeLists.txt updated
- [ ] Script loader registered
- [ ] NPC created in game
- [ ] Talk to NPC - main menu shows
- [ ] "View Items" - shows upgradeable items
- [ ] Click item - detail UI appears
- [ ] "View Stats" - shows player statistics
- [ ] "Help" - shows information
- [ ] Admin commands work (.upgrade mech cost, etc.)
- [ ] Database tables populated
- [ ] No compilation errors/warnings

---

**For detailed information, see PHASE4A_MECHANICS_COMPLETE.md**
