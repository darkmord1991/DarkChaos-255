# Endless Dungeon — Group Level Scaling Proposal

> **Version**: 1.0  
> **Status**: Proposal  
> **Scope**: How Target Level is determined for groups with mixed levels

---

## Executive Summary

When players form a group for Endless Dungeon, we need clear rules for:
1. **Target Level** — What level are creatures and rewards?
2. **Level Selection** — Who decides (leader, vote, automatic)?
3. **Level Restrictions** — How far apart can party members be?
4. **Reward Fairness** — Do high-level players trivialize content?
5. **XP & Loot Distribution** — Who gets what?

---

## Problem Statement

Consider this scenario:
- Player A: Level 80
- Player B: Level 45
- Player C: Level 30

**Questions:**
1. Should creatures be level 30, 45, 80, or average (52)?
2. Can the level 80 one-shot everything at level 30?
3. Should the level 30 get level 80 loot they can't use?
4. Is it fair to the level 80 to get level 30 rewards?

---

## Proposed Solution: **Leader-Selected Target Level**

### Core Rule

> **The party leader selects the Target Level when starting a run.**

The leader can choose any level between:
- **Floor**: Lowest party member's level
- **Ceiling**: Highest party member's level

This gives groups full control while preventing abuse.

---

## Detailed Rules

### 1. Target Level Selection

| Selection Method | Formula | Use Case |
|------------------|---------|----------|
| **Lowest** | `MIN(all party levels)` | Safe for carries, everyone contributes |
| **Highest** | `MAX(all party levels)` | Challenge mode, fast XP for low-levels |
| **Average** | `ROUND(AVG(all party levels))` | Balanced default |
| **Custom** | Leader picks within range | Full flexibility |

**UI Prompt** (shown to leader):
```
┌─────────────────────────────────────────────────┐
│     SELECT TARGET LEVEL FOR ENDLESS RUN         │
├─────────────────────────────────────────────────┤
│                                                 │
│  Party Levels: 30, 45, 80                       │
│  Allowed Range: 30 - 80                         │
│                                                 │
│  [  30 - Lowest  ]  ← Easiest for all           │
│  [  52 - Average ]  ← Recommended               │
│  [  80 - Highest ]  ← Maximum challenge         │
│                                                 │
│  Or enter custom level: [____]                  │
│                                                 │
│  [ Start Run ]                                  │
│                                                 │
└─────────────────────────────────────────────────┘
```

### 2. Level Gap Restrictions

To prevent extreme carries (level 80 + level 25):

| Config Option | Default | Description |
|---------------|---------|-------------|
| `MAX_LEVEL_GAP` | 15 | Maximum allowed level difference in party |
| `MIN_ENTRY_LEVEL` | 25 | Absolute minimum to enter Endless |
| `ALLOW_OVERLEVEL` | true | Allow Target < player level |

**Validation on Run Start:**
```cpp
// Check level gap
int maxLevel = GetMaxPartyLevel();
int minLevel = GetMinPartyLevel();

if (maxLevel - minLevel > MAX_LEVEL_GAP)
{
    // Error: "Party level gap too large (max 15 levels)"
    return false;
}

if (minLevel < MIN_ENTRY_LEVEL)
{
    // Error: "All party members must be level 25+"
    return false;
}
```

### 3. Creature Scaling

Creatures always scale to the **selected Target Level**:

```cpp
void ApplyGroupScaling(Creature* creature, EndlessRun* run)
{
    uint32 targetLevel = run->GetTargetLevel();  // Leader's selection
    uint32 partySize = run->GetPartySize();
    uint32 floor = run->GetCurrentFloor();
    
    // Set creature level
    creature->SetLevel(targetLevel);
    
    // Apply floor + party size multipliers
    ApplyEndlessScaling(creature, floor, partySize, targetLevel);
}
```

### 4. Player Contribution Scaling

When a player is **significantly above Target Level**, their contribution is scaled down:

| Level Difference | Effect |
|------------------|--------|
| 0–5 above | Full contribution (100%) |
| 6–10 above | Reduced damage dealt (−20% per level above 5) |
| 11–15 above | Reduced damage dealt (−50%), reduced reward weight |
| 16+ above | Not allowed (MAX_LEVEL_GAP) |

**Implementation — Damage Debuff:**
```cpp
void ApplyOverlevelDebuff(Player* player, uint32 targetLevel)
{
    int32 diff = player->GetLevel() - targetLevel;
    
    if (diff > 5)
    {
        // Apply scaling debuff
        float reduction = 0.20f * (diff - 5);  // 20% per level above 5
        reduction = std::min(reduction, 0.75f); // Cap at 75% reduction
        
        // Apply as aura: SPELL_AURA_MOD_DAMAGE_PERCENT_DONE = -(reduction * 100)
        player->CastCustomSpell(SPELL_ENDLESS_OVERLEVEL_DEBUFF, SPELLVALUE_BASE_POINT0, int32(reduction * 100), player, true);
    }
}
```

This prevents a level 80 from instantly killing level 30 mobs while still allowing them to play with friends.

---

## Reward Distribution

### 5. Loot Level

| Reward Type | Level Matches | Notes |
|-------------|---------------|-------|
| **Gear drops** | Target Level | Everyone gets usable items |
| **Currency (Essence)** | Flat amount | Same for all |
| **Currency (Tokens)** | Contribution-weighted | Based on damage/healing done |
| **XP** | Per player | Calculated individually |

### 6. XP Distribution

XP is calculated per player based on **relative level to Target**:

```cpp
uint32 CalculateEndlessXP(Player* player, uint32 targetLevel, uint32 baseXP)
{
    int32 levelDiff = targetLevel - player->GetLevel();
    
    // Standard WoW gray-level formula
    if (levelDiff < -10)
        return 0;  // Trivial content
    else if (levelDiff < -5)
        return baseXP * 0.25f;  // Reduced XP
    else if (levelDiff > 5)
        return baseXP * 1.25f;  // Bonus for challenging content
    else
        return baseXP;  // Full XP
}
```

**Example:**
| Player Level | Target Level | XP Modifier |
|--------------|--------------|-------------|
| 30 | 30 | 100% |
| 45 | 30 | 0% (gray) |
| 80 | 30 | 0% (gray) |
| 30 | 52 | 125% (bonus) |
| 45 | 52 | 100% |
| 80 | 52 | 0% (gray) |

### 7. Token Distribution

One-time floor tokens (at 5, 10, 15, etc.) are distributed based on contribution:

```cpp
void DistributeTokens(EndlessRun* run, uint32 floor)
{
    // Calculate total damage done
    uint32 totalDamage = run->GetTotalPartyDamage();
    
    for (Player* player : run->GetParty())
    {
        // Base token + contribution bonus
        uint32 playerDamage = run->GetPlayerDamage(player->GetGUID());
        float contribution = (float)playerDamage / totalDamage;
        
        // All players get at least 1 token
        uint32 baseTokens = GetBaseTokensForFloor(floor);
        uint32 bonusTokens = uint32(baseTokens * 0.5f * contribution);
        
        player->AddItem(TOKEN_ITEM_ENTRY, baseTokens + bonusTokens);
    }
}
```

---

## Use Cases & Examples

### Case 1: Friends with Level Gap

**Scenario:** Level 80 wants to play with level 50 friend.
**Solution:** 
1. Party up (gap = 30 → fails MAX_LEVEL_GAP check)
2. Level 80 asks friend to level to 65+ OR they play separate runs

**Alternative Config:** Server can set `MAX_LEVEL_GAP = 30` for casual servers.

### Case 2: Power-Leveling

**Scenario:** Level 80 wants to boost level 70.
**Solution:**
1. Set Target Level = 80 (highest)
2. Level 70 gets bonus XP (+25%) for challenging content
3. Level 80 does full damage (within 5-level tolerance)
4. Loot drops at level 80 (usable by level 70 after leveling)

### Case 3: Carrying a New Player

**Scenario:** Two level 40s want to bring a level 25 friend.
**Solution:**
1. Set Target Level = 25 (lowest)
2. Level 40s get −30% damage debuff (15 levels above threshold)
3. All players contribute meaningfully
4. Loot drops at level 25 (everyone can use)
5. XP: Level 25 gets 100%, Level 40s get 0% (gray)

### Case 4: Equal-Level Party

**Scenario:** Five level 60 players.
**Solution:**
1. Target Level = 60 (only option)
2. No debuffs, full contribution
3. All loot level 60
4. Full XP for all

---

## Database Schema Updates

### `dc_endless_runs` — Add `target_level_method`

```sql
ALTER TABLE dc_endless_runs ADD COLUMN target_level_method ENUM(
    'lowest',
    'average', 
    'highest',
    'custom'
) NOT NULL DEFAULT 'average' AFTER target_level;
```

### `dc_endless_config` — Server-Wide Settings

```sql
CREATE TABLE IF NOT EXISTS dc_endless_config (
    config_key VARCHAR(64) PRIMARY KEY,
    config_value VARCHAR(255) NOT NULL,
    description TEXT
);

INSERT INTO dc_endless_config VALUES
('MAX_LEVEL_GAP', '15', 'Maximum allowed level difference between party members'),
('MIN_ENTRY_LEVEL', '25', 'Minimum player level to enter Endless Dungeon'),
('ALLOW_OVERLEVEL', '1', 'Allow players above Target Level (with debuff)'),
('OVERLEVEL_DEBUFF_START', '5', 'Level difference before debuff applies'),
('OVERLEVEL_DEBUFF_PER_LEVEL', '20', 'Damage reduction % per level above threshold'),
('DEFAULT_TARGET_METHOD', 'average', 'Default target level calculation method');
```

### `dc_endless_run_stats` — Track Per-Player Contribution

```sql
CREATE TABLE IF NOT EXISTS dc_endless_run_stats (
    run_id BIGINT NOT NULL,
    character_guid INT NOT NULL,
    damage_done BIGINT DEFAULT 0,
    healing_done BIGINT DEFAULT 0,
    damage_taken BIGINT DEFAULT 0,
    deaths INT DEFAULT 0,
    kills INT DEFAULT 0,
    PRIMARY KEY (run_id, character_guid),
    FOREIGN KEY (run_id) REFERENCES dc_endless_runs(run_id) ON DELETE CASCADE
);
```

---

## Addon UI Updates

### Level Selection Panel

```lua
-- EndlessDungeon_LevelSelect.lua
local function ShowLevelSelectPanel(partyLevels)
    local minLevel = math.min(unpack(partyLevels))
    local maxLevel = math.max(unpack(partyLevels))
    local avgLevel = math.floor(GetAverage(partyLevels) + 0.5)
    
    -- Create dropdown or slider
    local slider = CreateFrame("Slider", "EndlessLevelSlider", panel, "OptionsSliderTemplate")
    slider:SetMinMaxValues(minLevel, maxLevel)
    slider:SetValue(avgLevel)  -- Default to average
    
    -- Labels
    slider.Low:SetText(minLevel .. " (Lowest)")
    slider.High:SetText(maxLevel .. " (Highest)")
end
```

### Overlevel Warning

```lua
local function CheckOverlevelWarning(targetLevel)
    local playerLevel = UnitLevel("player")
    local diff = playerLevel - targetLevel
    
    if diff > 5 then
        local reduction = math.min((diff - 5) * 20, 75)
        ShowWarning(string.format(
            "You are %d levels above target. Your damage will be reduced by %d%%.",
            diff, reduction
        ))
    end
end
```

---

## Implementation Phases

### Phase 1: Core (MVP)
- [ ] Add `target_level_method` column
- [ ] Implement leader level selection UI
- [ ] Apply Target Level to creature scaling
- [ ] Validate `MAX_LEVEL_GAP` on run start

### Phase 2: Balance
- [ ] Implement overlevel damage debuff aura
- [ ] Add XP scaling formula
- [ ] Track contribution stats in `dc_endless_run_stats`

### Phase 3: Polish
- [ ] Token distribution based on contribution
- [ ] Addon warnings for overlevel
- [ ] Config options for server customization

---

## Recommendation Summary

| Decision | Recommendation | Rationale |
|----------|----------------|-----------|
| **Target Level Selection** | Leader picks (range: lowest–highest) | Flexibility for all playstyles |
| **Default Method** | Average | Balanced for mixed groups |
| **Level Gap Limit** | 15 levels | Prevents extreme carries |
| **Overlevel Penalty** | Damage debuff (−20%/level above 5) | Keeps high-levels from trivializing |
| **Loot Level** | Matches Target Level | Everyone gets usable items |
| **XP Distribution** | Per-player formula | Fair based on challenge |
| **Token Distribution** | 50% base + 50% contribution | Rewards active participation |

---

## Open Questions for Discussion

1. **Should Target Level be re-selectable at checkpoints?**
   - Pro: Party composition may change when resuming
   - Con: Could be exploited (farm at low, resume at high)

2. **Should there be a "sync" mode that down-levels high players?**
   - Like Timewalking, reduce max level to Target Level
   - More balance, less flexibility

3. **Should XP be granted to gray-level players at all?**
   - Current: 0% (gray content)
   - Alternative: Small % (e.g., 10%) as participation reward

4. **Should contribution-based tokens require minimum %?**
   - Prevent pure AFK leeching (require >5% contribution?)

---

## Appendix: Comparison to Other Systems

| System | Level Scaling | Notes |
|--------|--------------|-------|
| **WoW Timewalking** | All players scaled to dungeon level | Equal playing field |
| **FFXIV Level Sync** | Synced to dungeon | Gear stats normalized |
| **D3 Torment** | No levels, only difficulty tiers | Paragon-based scaling |
| **WoW Delves** | Player level determines tier | Solo content |
| **Our Approach** | Leader selects Target Level | Flexible, group-controlled |

Our system prioritizes **flexibility** while using debuffs to maintain **balance**.
