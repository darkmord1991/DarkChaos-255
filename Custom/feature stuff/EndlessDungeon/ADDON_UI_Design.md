# Endless Dungeon — Addon & UI Design

> Client-side addon specification for the Endless Dungeon system.  
> Built on existing **DC-AddonProtocol** patterns; integrates with **DC-Leaderboards** and **DC-MythicPlus** Group Finder.

---

## Overview

The Endless Dungeon addon provides:
1. **HUD** – Real-time floor/strike/currency display during runs
2. **Group Finder Integration** – Queue/browse for Endless Dungeon runs (new tab in DC-MythicPlus)
3. **Leaderboard Extension** – New category in DC-Leaderboards
4. **Spectator Mode** – Watch active runs (leverages existing DC Spectator patterns)
5. **Run Summary** – End-of-run popup with rewards and stats

---

## 1. DC-AddonProtocol Integration

### Module Registration
```lua
-- Module ID
DC.ModuleNames.EDNG = "Endless Dungeon"

-- Opcodes (Client → Server)
CMSG_EDNG_START_RUN       = 0x01  -- Start new run (includes difficulty + target level)
CMSG_EDNG_RESUME_RUN      = 0x02  -- Resume from checkpoint
CMSG_EDNG_LEAVE_RUN       = 0x03  -- Voluntary exit
CMSG_EDNG_SET_DIFFICULTY  = 0x07  -- Set difficulty before run start
CMSG_EDNG_GET_STATE       = 0x04  -- Request current state
CMSG_EDNG_GET_CHECKPOINTS = 0x05  -- List my checkpoints
CMSG_EDNG_GET_LEADERBOARD = 0x06  -- Leaderboard request
CMSG_EDNG_QUEUE_JOIN      = 0x10  -- Join group finder queue
CMSG_EDNG_QUEUE_LEAVE     = 0x11  -- Leave queue
CMSG_EDNG_GROUP_LIST      = 0x12  -- Browse listed groups
CMSG_EDNG_GROUP_CREATE    = 0x13  -- Create listing
CMSG_EDNG_GROUP_APPLY     = 0x14  -- Apply to listing
CMSG_EDNG_SPECTATE_LIST   = 0x20  -- List spectatable runs
CMSG_EDNG_SPECTATE_JOIN   = 0x21  -- Join as spectator

-- Opcodes (Server → Client)
SMSG_EDNG_STATE           = 0x01  -- Full state update
SMSG_EDNG_FLOOR_START     = 0x02  -- Floor started
SMSG_EDNG_FLOOR_COMPLETE  = 0x03  -- Floor cleared
SMSG_EDNG_CHECKPOINT      = 0x04  -- Checkpoint saved
SMSG_EDNG_WIPE            = 0x05  -- Wipe/strike
SMSG_EDNG_RUN_END         = 0x06  -- Run ended
SMSG_EDNG_CURRENCY        = 0x07  -- Currency update
SMSG_EDNG_CHECKPOINTS     = 0x08  -- Checkpoint list
SMSG_EDNG_LEADERBOARD     = 0x09  -- Leaderboard data
SMSG_EDNG_QUEUE_STATUS    = 0x10  -- Queue status
SMSG_EDNG_GROUP_LIST      = 0x11  -- Group listings
SMSG_EDNG_SPECTATE_LIST   = 0x20  -- Spectatable runs
SMSG_EDNG_SPECTATE_STATE  = 0x21  -- Spectator state update
SMSG_EDNG_ERROR           = 0xFF  -- Error response
```

### JSON Payloads (Examples)

**SMSG_EDNG_STATE**
```json
{
  "runId": 12345,
  "floor": 17,
  "strikes": 1,
  "maxStrikes": 3,
  "xpBonus": 17,
  "tokens": 22,
  "essence": 48,
  "checkpointFloor": 15,
  "dungeonName": "The Blood Furnace",
  "partySize": 3,
  "targetLevel": 80,
  "difficulty": "heroic",
  "difficultyMult": 1.3,
  "inProgress": true
}
```

**SMSG_EDNG_FLOOR_COMPLETE**
```json
{
  "floor": 17,
  "tokensEarned": 1,
  "essenceEarned": 4,
  "xpBonus": 17,
  "isCheckpoint": false,
  "cacheItemId": 123456,
  "greedyGoblinKilled": false
}
```

**SMSG_EDNG_RUN_END**
```json
{
  "finalFloor": 23,
  "totalTokens": 30,
  "totalEssence": 72,
  "totalXpBonus": 23,
  "bestFloorThisWeek": 23,
  "reason": "wipe"
}
```

---

## 2. HUD Design

### Layout (In-Run Display)
```
┌─────────────────────────────────────────┐
│  ENDLESS DUNGEON          [HEROIC]      │
│  ═══════════════════════════════════    │
│  Floor: 17 / Checkpoint: 15             │
│  Strikes: ● ○ ○                         │
│  ───────────────────────────────────    │
│  Dungeon: The Blood Furnace             │
│  Party: 3 players  |  Level: 80         │
│  ───────────────────────────────────    │
│  XP Bonus: +17%   |  Rewards: +30%      │
│  Tokens: 22  |  Essence: 48             │
└─────────────────────────────────────────┘
```

### Features
- **Movable/Lockable** – Drag to reposition; `/edng lock` to lock
- **Collapsible** – Click header to minimize to icon-only
- **Strike Indicators** – Visual dots (filled = used, empty = remaining)
- **Checkpoint Flash** – Glow effect when checkpoint is saved
- **Greedy Goblin Alert** – Flash + sound when goblin spawns
- **Difficulty Badge** – Color-coded: Normal (green), Heroic (orange), Mythic (red)

### Difficulty Colors
```lua
EDNG.DIFFICULTY_COLORS = {
    ["normal"] = { r = 0.2, g = 0.8, b = 0.2, hex = "33cc33" },   -- Green
    ["heroic"] = { r = 1.0, g = 0.6, b = 0.0, hex = "ff9900" },   -- Orange  
    ["mythic"] = { r = 0.8, g = 0.2, b = 0.2, hex = "cc3333" },   -- Red
}
```

### Visibility
- Auto-show when entering Endless Dungeon instance
- Auto-hide when leaving or run ends
- Toggle: `/edng hud`

---

## 2.5 Difficulty Selection Panel (Pre-Run)

**Shown when leader initiates a new Endless run:**

```
┌─────────────────────────────────────────────────────────────────┐
│            SELECT ENDLESS DUNGEON SETTINGS                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  DIFFICULTY                                                     │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐               │
│  │   NORMAL    │ │   HEROIC    │ │   MYTHIC    │               │
│  │  ───────    │ │  ────────   │ │  ───────    │               │
│  │  Creatures: │ │  Creatures: │ │  Creatures: │               │
│  │  HP ×0.30   │ │  HP ×0.52   │ │  HP ×0.80   │               │
│  │  DMG ×0.40  │ │  DMG ×0.65  │ │  DMG ×0.96  │               │
│  │             │ │             │ │             │               │
│  │  Rewards:   │ │  Rewards:   │ │  Rewards:   │               │
│  │  100%       │ │  +30%       │ │  +75%       │               │
│  │             │ │             │ │             │               │
│  │ [SELECTED]  │ │             │ │             │               │
│  └─────────────┘ └─────────────┘ └─────────────┘               │
│                                                                 │
│  ───────────────────────────────────────────────────────────    │
│                                                                 │
│  TARGET LEVEL                                                   │
│  Your Level: 42  |  Party Range: 38 – 45                        │
│                                                                 │
│  ○ Lowest (38)   ● Average (42)   ○ Highest (45)               │
│                                                                 │
│  Creatures will spawn at level 42.                              │
│  Loot will drop for level 42.                                   │
│                                                                 │
│  ───────────────────────────────────────────────────────────    │
│                                                                 │
│            [ START RUN ]        [ CANCEL ]                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Scaling Explanation (Tooltip on Hover)

**Normal Difficulty:**
> "Recommended for solo players or learning the dungeon.
> Creature stats reduced for comfortable progression.
> Full rewards at 100% rate."

**Heroic Difficulty:**
> "Moderate challenge for experienced players.
> Creatures hit harder and have more HP.
> +30% bonus to all rewards."

**Mythic Difficulty:**
> "Maximum challenge. Not recommended for solo.
> Creatures scaled for coordinated groups.
> +75% bonus to all rewards."

### How Scaling Works (Server-Side)

**Key Insight:** We scale **creatures**, not players. Player stats remain unchanged.

```cpp
// Final creature HP formula
float GetCreatureHP(uint32 floor, uint32 partySize, Difficulty diff, uint32 targetLevel)
{
    // 1. Base HP from CreatureBaseStats for target level
    float baseHP = GetBaseHPForLevel(targetLevel);
    
    // 2. Floor scaling (grows with depth)
    float floorMult = GetFloorMultiplier(floor);  // 1.0 at floor 1, ~2.5 at floor 50
    
    // 3. Party size scaling
    float partyMult = GetPartyMultiplier(partySize);  // 0.30 solo, 1.0 for 5-man
    
    // 4. Difficulty scaling
    float diffMult = GetDifficultyMultiplier(diff);  // Normal 1.0, Heroic 1.3, Mythic 1.6
    
    return baseHP * floorMult * partyMult * diffMult;
}
```

### Solo Player Example (Level 25, Floor 1)

| Difficulty | Creature HP | Creature DMG | Reward Mult |
|------------|-------------|--------------|-------------|
| Normal | ~450 HP | ~15 DPS | 100% |
| Heroic | ~585 HP | ~19 DPS | 130% |
| Mythic | ~720 HP | ~24 DPS | 175% |

At level 25 Normal, creatures should take 5-10 seconds to kill with quest greens.
This makes it accessible without being trivial.

### Solo vs Group Scaling Table

| Party Size | Normal HP× | Heroic HP× | Mythic HP× |
|------------|------------|------------|------------|
| 1 (solo) | 0.30 | 0.39 | 0.48 |
| 2 | 0.60 | 0.78 | 0.96 |
| 3 | 0.80 | 1.04 | 1.28 |
| 4 | 0.95 | 1.24 | 1.52 |
| 5 | 1.00 | 1.30 | 1.60 |

### Protocol Message

**CMSG_EDNG_START_RUN**
```json
{
  "difficulty": "normal",
  "targetLevel": 42,
  "targetLevelMethod": "average",
  "resumeCheckpoint": false
}
```

---

## 3. Group Finder Integration (DC-MythicPlus Extension)

### New Tab: "Endless"
Add to `GF.TAB_NAMES`:
```lua
GF.TAB_NAMES = { "Mythic+", "Raids", "World", "Live Runs", "Scheduled", "Endless", "My Queues" }
```

### Endless Tab Content

#### Sub-tabs
1. **Browse** – View listed groups seeking members
2. **Create** – Create a new listing
3. **Queue** – Solo queue for auto-matching

#### Browse Panel
| Column | Description |
|--------|-------------|
| Leader | Character name + class color |
| Target Floor | Starting floor (1 or checkpoint) |
| Level Range | e.g., "78–80" |
| Party | Current / Max (e.g., "2/5") |
| Note | Leader's description |
| [Apply] | Button |

#### Create Panel
- **Title** (text input)
- **Difficulty** (dropdown: Normal / Heroic / Mythic)
- **Target Floor** (dropdown: New Run / Checkpoint floors)
- **Target Level** (dropdown: Lowest / Average / Highest / Custom)
- **Level Range** (min/max sliders)
- **Party Size** (1–5)
- **Note** (multiline)
- **[Create Listing]** button

#### Queue Panel
- **Role Selection** (Tank / Healer / DPS checkboxes)
- **Level Range** (auto-set to player level ± 5)
- **[Join Queue]** / **[Leave Queue]** button
- **Estimated Wait** display

---

## 4. Leaderboard Extension (DC-Leaderboards)

### New Category
```lua
{
    id = "endless",
    name = "Endless Dungeon",
    icon = "Interface\\Icons\\Spell_Arcane_PortalIronforge",
    color = "9932cc",  -- Purple
    subcats = {
        { id = "endless_floor", name = "Highest Floor" },
        { id = "endless_tokens", name = "Total Tokens" },
        { id = "endless_essence", name = "Total Essence" },
        { id = "endless_runs", name = "Runs Completed" },
        { id = "endless_goblin", name = "Greedy Goblins Killed" },
    },
    hasSeasonFilter = true,  -- Filter by season
}
```

### Server Table
```sql
CREATE TABLE endless_leaderboard (
    character_guid INT NOT NULL,
    season_id INT NOT NULL DEFAULT 1,
    highest_floor INT DEFAULT 0,
    total_tokens INT DEFAULT 0,
    total_essence INT DEFAULT 0,
    runs_completed INT DEFAULT 0,
    goblins_killed INT DEFAULT 0,
    best_floor_solo INT DEFAULT 0,
    best_floor_group INT DEFAULT 0,
    updated_at DATETIME,
    PRIMARY KEY (character_guid, season_id)
);
```

---

## 5. Spectator Mode

### How It Works
1. Player requests spectatable runs via `CMSG_EDNG_SPECTATE_LIST`.
2. Server returns list of public runs (opt-in by leader).
3. Player selects a run and sends `CMSG_EDNG_SPECTATE_JOIN`.
4. Server streams `SMSG_EDNG_SPECTATE_STATE` updates (floor, HP, events).
5. Client displays read-only HUD with party status.

### Spectator HUD
- Same layout as run HUD, but with:
  - "SPECTATING" label
  - Party member HP bars
  - No controls

### Privacy
- Leader can toggle "Allow Spectators" via gossip or `/edng spectate on|off`.
- Default: off.

---

## 6. Run Summary Popup

### Trigger
Displayed on `SMSG_EDNG_RUN_END`.

### Layout
```
┌─────────────────────────────────────────────┐
│           RUN COMPLETE                       │
│  ═══════════════════════════════════════    │
│                                              │
│  Final Floor: 23                            │
│  Best This Week: 23 ⭐ (new!)               │
│                                              │
│  ───────────────────────────────────────    │
│  Tokens Earned:   30                        │
│  Essence Earned:  72                        │
│  XP Bonus:        +23%                      │
│  ───────────────────────────────────────    │
│                                              │
│  [View Leaderboard]    [Queue Again]        │
│                        [Close]              │
└─────────────────────────────────────────────┘
```

### Features
- Play sound on new personal best
- Button to open leaderboard (filtered to Endless)
- Button to re-queue or create new listing

---

## 7. Slash Commands

| Command | Description |
|---------|-------------|
| `/edng` or `/endless` | Toggle Group Finder (Endless tab) |
| `/edng hud` | Toggle HUD visibility |
| `/edng lock` | Lock/unlock HUD position |
| `/edng leave` | Leave current run (confirmation prompt) |
| `/edng spectate` | Toggle spectator mode on your run |
| `/edng checkpoints` | List your saved checkpoints |

---

## 8. Addon File Structure

```
DC-EndlessDungeon/
├── DC-EndlessDungeon.toc
├── Core.lua                 -- Initialization, slash commands, event handling
├── Protocol.lua             -- DC-AddonProtocol handlers (EDNG module)
├── HUD.lua                  -- In-run HUD frame
├── Summary.lua              -- Run summary popup
├── Settings.lua             -- SavedVariables, options panel
├── Media/
│   ├── EndlessIcon.blp      -- Tab icon
│   └── Dungeons/            -- (optional) dungeon thumbnails
└── UI/
    ├── EndlessTab.lua       -- Group Finder tab content
    ├── BrowsePanel.lua      -- Browse listings
    ├── CreatePanel.lua      -- Create listing
    ├── QueuePanel.lua       -- Solo queue
    └── SpectatorHUD.lua     -- Spectator-specific HUD
```

### TOC File
```toc
## Interface: 30300
## Title: DC-EndlessDungeon
## Notes: Endless Dungeon UI for DarkChaos
## Author: DarkChaos Development Team
## Version: 1.0.0
## Dependencies: DC-AddonProtocol
## OptionalDeps: DC-MythicPlus, DC-Leaderboards
## SavedVariables: DCEndlessDungeonDB

Core.lua
Protocol.lua
Settings.lua
HUD.lua
Summary.lua
UI\EndlessTab.lua
UI\BrowsePanel.lua
UI\CreatePanel.lua
UI\QueuePanel.lua
UI\SpectatorHUD.lua
```

---

## 9. Integration Points

### DC-MythicPlus
- Add `"Endless"` to `GF.TAB_NAMES`.
- Call `GF:CreateEndlessTab()` from `GF:ShowEndlessTab()`.
- Reuse existing tab styling, scroll frames, and button templates.

### DC-Leaderboards
- Add `endless` category to `LB.Categories`.
- Server-side: extend `dc_leaderboards` Eluna handler to query `endless_leaderboard`.

### DC-AddonProtocol
- Register `"EDNG"` module with all opcodes.
- Use `DC:Request("EDNG", opcode, data)` for all requests.

---

## 10. Saved Variables

```lua
DCEndlessDungeonDB = {
    -- HUD
    hudPosition = { point = "CENTER", x = 0, y = 150 },
    hudLocked = false,
    hudScale = 1.0,
    hudCollapsed = false,
    
    -- Sound
    soundCheckpoint = true,
    soundGoblin = true,
    soundRunEnd = true,
    
    -- Group Finder
    lastLevelMin = 1,
    lastLevelMax = 80,
    lastRoleSelections = { tank = false, healer = false, dps = true },
    
    -- Spectator
    allowSpectators = false,
}
```

---

## 11. 3.3.5a Compatibility Notes

- Use `SetTexture` + `SetVertexColor` instead of `SetColorTexture`.
- Polyfill `C_Timer.After` (see DC-MythicPlus Core.lua).
- Polyfill `SetShown` for older frame API.
- Use `SendAddonMessage` with `"WHISPER"` channel for player-specific or `"GUILD"`/`"PARTY"` as needed.
- JSON encoding: use existing `DC:EncodeJSON` / `DC:DecodeJSON` from protocol.
