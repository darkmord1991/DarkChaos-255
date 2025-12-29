# Endless Dungeon — Architecture / Technical Design v2

> AzerothCore + WotLK 3.3.5a implementation guide.

---

## Constraints & Assumptions
- Server: **AzerothCore** (WotLK 3.3.5a fork).
- Client: WotLK; enhanced via **Lua addons** + standard server primitives.
- Group size: **1–5 players**.
- Entry level: **25+**; rewards scale to Target Level.

---

## System Overview

```
┌────────────────────────────────────────────────────────────────┐
│                       Run Manager (Core)                       │
│  • Creates runs, stores state, computes scaling, issues rewards│
└────────────────────────────────────────────────────────────────┘
        │                       │                       │
        ▼                       ▼                       ▼
┌──────────────┐       ┌──────────────┐       ┌──────────────┐
│ Instance     │       │ Spawn        │       │ Reward       │
│ Controller   │       │ Engine       │       │ Engine       │
│ (state mach) │       │ (DB-driven)  │       │ (currency +  │
│              │       │              │       │  loot)       │
└──────────────┘       └──────────────┘       └──────────────┘
        │                       │                       │
        ▼                       ▼                       ▼
┌──────────────────────────────────────────────────────────────────┐
│                         Database Tables                          │
│  dc_endless_runs, dc_endless_checkpoints, dc_endless_floors,     │
│  dc_endless_trash_groups, dc_endless_loot_tiers,                 │
│  dc_endless_currency_log                                         │
└──────────────────────────────────────────────────────────────────┘
```

---

## Map / Instance Strategy

### Option A – Dedicated "Endless Arena" Map
- Use an unused map ID (e.g., GM Island 1, or add custom map via patch).
- Define **anchor zones** (positions) for 20–40 floor layouts.
- Each floor: teleport party to anchor → spawn pack + boss → clear → next anchor.

**Pros**: Full control, no phasing conflicts.
**Cons**: Requires map work or re-purposing.

### Option B – Reuse Existing Dungeon Instances (Recommended for MVP)
- Maintain a **dungeon pool** (see Concept doc for candidates).
- Each floor maps to a **dungeon + segment** (area between bosses).
- Party is teleported to segment start; mobs spawn scaled at predefined positions.
- On floor complete, teleport to next dungeon/segment (can be same or different map).

**Pros**: No new maps; leverages existing art/layout.
**Cons**: Must handle instance reset/cleanup carefully.

### Hybrid (Long-Term)
- Start with Option B.
- Later, build a dedicated map for "tournament / leaderboard" runs.

---

## Instance State Machine

```
IDLE
  │
  ▼ (player starts run)
FLOOR_ACTIVE
  │
  ├─► trash cleared ─► spawn boss
  │
  ├─► boss killed ─► FLOOR_COMPLETE
  │
  └─► wipe ─► increment strike ─► (strikes < 3 ? reset floor : RUN_ENDED)

FLOOR_COMPLETE
  │
  ├─► floor % 5 == 0 ? save checkpoint
  │
  ▼
INTERMISSION (5–10 s)
  │
  ▼
FLOOR_ACTIVE (next floor)

RUN_ENDED
  │
  ▼
  payout rewards, teleport out, cleanup
```

---

## Database Schema

### `dc_endless_runs`
| Column | Type | Notes |
|--------|------|-------|
| run_id | BIGINT PK | Unique run identifier |
| leader_guid | INT | Character GUID of leader |
| party_guids | TEXT | Comma-separated GUIDs |
| target_level | TINYINT | Scaling level |
| party_size | TINYINT | 1–5 |
| current_floor | INT | Progress |
| strikes | TINYINT | Wipe counter |
| status | ENUM('active','ended','abandoned') | |
| created_at | DATETIME | |
| updated_at | DATETIME | |

### `dc_endless_checkpoints`
| Column | Type | Notes |
|--------|------|-------|
| checkpoint_id | BIGINT PK | |
| character_guid | INT | Owner (solo) or leader (group) |
| floor | INT | Checkpoint floor (5, 10, 15, …) |
| target_level | TINYINT | Original scaling level |
| tokens_collected | TEXT | JSON array of floors already rewarded |
| created_at | DATETIME | |

### `dc_endless_floors`
| Column | Type | Notes |
|--------|------|-------|
| floor_id | INT PK | Template ID |
| map_id | INT | Dungeon map |
| segment_id | TINYINT | Segment within dungeon |
| anchor_x | FLOAT | Teleport position |
| anchor_y | FLOAT | |
| anchor_z | FLOAT | |
| anchor_o | FLOAT | Orientation |
| trash_group_id | INT FK | Reference to trash group |
| boss_entry | INT | Creature entry for boss |
| boss_x | FLOAT | Boss spawn position |
| boss_y | FLOAT | |
| boss_z | FLOAT | |
| min_floor | INT | Earliest floor this template can appear |
| max_floor | INT | Latest floor (0 = no limit) |
| weight | INT | Selection weight |

### `dc_endless_trash_groups`
| Column | Type | Notes |
|--------|------|-------|
| group_id | INT PK | |
| name | VARCHAR | Descriptive |

### `dc_endless_trash_spawns`
| Column | Type | Notes |
|--------|------|-------|
| id | INT PK | |
| group_id | INT FK | |
| creature_entry | INT | |
| rel_x | FLOAT | Relative to anchor |
| rel_y | FLOAT | |
| rel_z | FLOAT | |
| is_elite | BOOL | Counts toward add scaling |

### `dc_endless_loot_tiers`
| Column | Type | Notes |
|--------|------|-------|
| tier_id | INT PK | |
| min_floor | INT | |
| max_floor | INT | |
| loot_template_id | INT | Reference to loot_template or custom table |
| description | VARCHAR | e.g., "Heroic Dungeon Blues" |

### `dc_endless_currency_log`
| Column | Type | Notes |
|--------|------|-------|
| id | BIGINT PK | |
| character_guid | INT | |
| run_id | BIGINT | |
| floor | INT | |
| tokens | INT | |
| essence | INT | |
| timestamp | DATETIME | |

---

## CrossSystem Integration

Endless Dungeon integrates with the DarkChaos CrossSystem infrastructure for unified reward distribution, event broadcasting, and session tracking.

### System Registration

```cpp
// SystemId::EndlessDungeon = 12 (added to CrossSystemCore.h)
// ContentType::EndlessDungeon = 8 (added to CrossSystemCore.h)
```

### Event Types

| EventType | Value | Description |
|-----------|-------|-------------|
| `EndlessDungeonStart` | 1000 | Run begins (new or resumed) |
| `EndlessDungeonFloorComplete` | 1001 | Floor cleared |
| `EndlessDungeonCheckpoint` | 1002 | Checkpoint saved (every 5 floors) |
| `EndlessDungeonWipe` | 1003 | Party wipe (strike added) |
| `EndlessDungeonEnd` | 1004 | Run ended (success or failure) |
| `EndlessDungeonResume` | 1005 | Run resumed from checkpoint |

### Event Data Structure

```cpp
struct EndlessFloorCompleteEvent : EventData
{
    uint32 floor = 0;
    uint8 strikes = 0;
    uint32 tokensAwarded = 0;
    uint32 essenceAwarded = 0;
    uint32 targetLevel = 0;
    uint32 partySize = 0;
    bool isCheckpoint = false;  // floor % 5 == 0
    std::vector<ObjectGuid> participants;
};

struct EndlessRunEndEvent : EventData
{
    uint32 finalFloor = 0;
    uint32 totalTokens = 0;
    uint32 totalEssence = 0;
    uint32 runDurationSeconds = 0;
    uint8 totalDeaths = 0;
    bool wasAbandoned = false;
};
```

### Reward Distribution

Uses `RewardDistributor` pattern from CrossSystem:

```cpp
#include "DC/CrossSystem/CrossSystemRewards.h"

void EndlessDungeon::AwardFloorRewards(Player* player, uint32 floor, bool isFirstClear)
{
    using namespace DarkChaos::CrossSystem;
    
    // Calculate rewards
    uint32 tokens = isFirstClear ? CalculateTokens(floor) : 0;
    uint32 essence = CalculateEssence(floor);
    
    // Award via CrossSystem (applies prestige/seasonal multipliers)
    if (tokens > 0)
    {
        AwardTokens(player, tokens, 
                    SystemId::EndlessDungeon, 
                    EventType::EndlessDungeonFloorComplete,
                    "Endless Dungeon", 
                    floor);
    }
    
    AwardEssence(player, essence,
                 SystemId::EndlessDungeon,
                 EventType::EndlessDungeonFloorComplete,
                 "Endless Dungeon",
                 floor);
}
```

### Multiplier Calculation

Endless Dungeon rewards benefit from existing CrossSystem multipliers:

| Multiplier | Source | Effect |
|------------|--------|--------|
| Prestige | Player prestige level | +2% per prestige |
| Seasonal | Active season config | Varies |
| First-of-Day | Daily bonus flag | +100% Essence |
| Party Bonus | Full group (5) | +10% |

### Session Context Updates

When a player enters an Endless run:

```cpp
void EndlessDungeon::OnRunStart(Player* player, uint32 targetLevel)
{
    auto* ctx = CrossSystemManager::instance()->GetSessionContext(player->GetGUID());
    if (ctx)
    {
        ctx->activeContent.type = ContentType::EndlessDungeon;
        ctx->activeContent.difficulty = ContentDifficulty::Normal; // or Hard/Nightmare
        ctx->activeContent.mapId = currentMapId;
        ctx->activeContent.instanceId = instance->GetInstanceId();
        ctx->activeContent.isRunActive = true;
        ctx->activeContent.runStartedAt = GameTime::GetGameTime();
    }
}
```

### Great Vault Integration

Endless Dungeon progress can contribute to Great Vault rewards:

| Vault Slot | Requirement | Reward |
|------------|-------------|--------|
| Dungeon #1 | Reach floor 10 | Normal cache |
| Dungeon #2 | Reach floor 25 | Heroic cache |
| Dungeon #3 | Reach floor 50 | Mythic cache |

Track via `dc_endless_runs.highest_floor` and query in vault calculation.

---

## Scaling Engine

### Inputs
- `target_level` (party average or lowest)
- `party_size` (1–5)
- `floor` (current depth)

### Formulas (Configurable)

**HP Multiplier**
```
floor_factor = 1.0 + floor_scaling_rate * (floor - 1)
party_factor = party_hp_table[party_size]
hp_mult = floor_factor * party_factor
```

**Damage Multiplier**
```
floor_factor = 1.0 + floor_dmg_rate * (floor - 1)
party_factor = party_dmg_table[party_size]
dmg_mult = floor_factor * party_factor
```

**Add Count**
```
base_adds = trash_group.base_count
add_modifier = party_add_table[party_size]  // e.g., -2, -1, 0, +1, +2
final_adds = clamp(base_adds + add_modifier, 1, max_adds)
```

### Implementation
- On creature spawn, apply multipliers via `SetMaxHealth`, `SetHealth`, `SetBaseDamage` (or aura-based if preferred).
- Store `base_health`, `base_damage` from creature template; multiply at spawn.

---

## Spawn Flow

### Floor Start
1. Select floor template from `endless_floors` (weighted random, filtered by floor range).
2. Teleport party to anchor position.
3. Spawn trash from `endless_trash_spawns` (apply scaling).
4. Register creatures in instance controller.

### Trash Cleared Detection
- Track spawned creature GUIDs.
- On creature death, decrement counter.
- When counter == 0, spawn boss.

### Boss Spawn
- Spawn boss at `boss_x/y/z`.
- Apply scaling.
- Boss scripts can be reused from original dungeon or custom.

### Floor Complete
1. Despawn any remaining creatures/objects in radius.
2. Award currency + cache.
3. If floor % 5 == 0, save checkpoint.
4. Start intermission timer.
5. Increment floor; loop.

---

## Checkpoint System

### Saving
- On floors 5, 10, 15, …:
  - Upsert `endless_checkpoints` for leader (or each solo player).
  - Store `tokens_collected` (list of floors that already gave one-time Token).

### Resuming
- Player selects "Continue Run" at Gatekeeper.
- Load checkpoint; set `current_floor` to checkpoint floor.
- Re-compute scaling based on **current** party size/level (not original).
- Skip Token rewards for floors in `tokens_collected`; Essence still awarded.

### Expiry (Optional)
- Checkpoints older than X days can be pruned.

---

## Reward Engine

### Token (One-Time)
- On floor complete, check if floor already in `tokens_collected` for this character.
- If not, award tokens per formula (see Concept doc), record floor.

### Essence (Repeatable)
- Always award essence per formula.

### Loot Cache
- Spawn chest GO at boss death position.
- Assign loot template from `endless_loot_tiers` based on floor range and target level.

### Greedy Goblin
- 5 % chance per floor to spawn a "Greedy Goblin" creature alongside trash.
- On spawn, start 10 s despawn timer.
- If killed, drop gold pouch + cosmetic roll.

---

## Wipe / Strike Handling

### Detection
- All party members dead within instance.
- Or: boss resets while party was in combat.

### On Wipe
1. Increment `strikes`.
2. If `strikes >= 3`:
   - Set run status = 'ended'.
   - Payout rewards earned so far.
   - Teleport out; cleanup.
3. Else:
   - Despawn remaining mobs.
   - Respawn trash + boss (same floor).
   - Optionally apply small penalty (−10 % Essence this floor).

---

## Anti-Exploit / Fairness

### Contribution Tracking
Track per-player:
- Damage done
- Healing done
- Damage taken (tank metric)

Require minimum threshold (e.g., 10 % of group total) for:
- Token eligibility
- Loot roll eligibility

### Level / Carry Prevention
- If a player's level is significantly higher than Target Level (e.g., +10), reduce their contribution weight or disqualify from one-time rewards.
- Alternatively: disallow entry if level delta > threshold.

### Checkpoint Abuse
- Checkpoints tied to character; cannot be traded.
- One-time Token rewards recorded per character.

---

## Addon Communication

### Server → Client
Use addon messages (`CHAT_MSG_ADDON`) or world-state updates.

**Message Types**
| Type | Payload | Notes |
|------|---------|-------|
| `ED_RUN_START` | run_id, target_level | |
| `ED_FLOOR` | floor, strikes, xp_bonus | |
| `ED_CURRENCY` | tokens, essence | |
| `ED_CHECKPOINT` | floor | |
| `ED_RUN_END` | final_floor, total_tokens, total_essence | |

### Client Addon
- Displays: floor, strikes, XP bonus, currencies, checkpoint indicator.
- Optional: timer, leaderboard link.

---

## Dungeon Reuse: Practical Steps

### 1. Identify Segments
For each candidate dungeon, define segments:
- Segment = trash pack(s) leading to a boss (entrance → Boss 1, Boss 1 area → Boss 2, etc.).
- Each segment = 1 floor in Endless Dungeon.
- Record anchor position (segment start), boss entry, trash group(s).

### 2. Build Trash Groups
- For each segment, list trash spawns with relative positions.
- Tag elites for add-count scaling.

### 3. Boss Scaling
- Reuse existing boss AI; wrap with scaling hook.
- If boss has adds, scale those too.

### 4. Instance Reset
- When switching dungeons mid-run, reset the target instance before teleporting.
- Use `InstanceScript::SetData` or manual cleanup.

---

## Difficulty Modes (Optional Layer)

| Mode | HP/Dmg Mult | Reward Mult | Unlock |
|------|-------------|-------------|--------|
| Normal | ×1.0 | ×1.0 | Default |
| Hard | ×1.3 | ×1.5 | Floor 25 reached once |
| Nightmare | ×1.6 | ×2.0 | Floor 50 reached once |

Store unlock in `dc_endless_player_unlocks` table.

---

## Client Patch Approach

Adding a new difficulty mode (e.g., "Endless") requires patching the client's MapDifficulty.dbc file. This section documents the approach and tools.

### DBC Structure

The MapDifficulty.dbc file defines available difficulties for each map. Key columns:

| Column | Type | Description |
|--------|------|-------------|
| ID | int | Unique entry ID |
| MapID | int | Map this difficulty applies to |
| Difficulty | int | 0=Normal, 1=Heroic, 2=Mythic, 3=25H (raids) |
| Message_Lang_* | string | Error message if requirements not met |
| RaidDuration | int | Lockout duration in seconds |
| MaxPlayers | int | 5 for dungeons, 10/25 for raids |
| Difficultystring | string | Display key (e.g., "DUNGEON_DIFFICULTY_5PLAYER") |

### Existing Custom Difficulties

DarkChaos already has Mythic difficulty entries (Difficulty=2) for TBC dungeons:

```csv
# Example from MapDifficulty.csv
"9200","540","2","Mythic mode unlocked for The Shattered Halls.","...","5","DUNGEON_DIFFICULTY_5PLAYER_MYTHIC"
"9201","542","2","Mythic mode unlocked for The Blood Furnace.","...","5","DUNGEON_DIFFICULTY_5PLAYER_MYTHIC"
"9202","543","2","Mythic mode unlocked for Hellfire Ramparts.","...","5","DUNGEON_DIFFICULTY_5PLAYER_MYTHIC"
"9205","547","2","Mythic mode unlocked for The Slave Pens.","...","5","DUNGEON_DIFFICULTY_5PLAYER_MYTHIC"
```

### Adding Endless Difficulty Entries

For Endless Dungeon, we have two options:

#### Option A: Reuse Mythic Difficulty (Recommended)

Leverage existing Difficulty=2 entries for Endless mode:
- Server-side: Detect when player enters via Endless Gatekeeper
- Set an instance flag (`DATA_ENDLESS_MODE = 1`)
- Suppress normal M+ behavior when in Endless mode

```cpp
void EndlessGatekeeper::TeleportToEndless(Player* player, uint32 mapId)
{
    // Force Mythic difficulty (2)
    player->SetDungeonDifficultyID(DIFFICULTY_MYTHIC);
    
    // Teleport to dungeon
    player->TeleportTo(mapId, x, y, z, o);
    
    // Instance script will detect Endless mode via custom data
}
```

**Pros**: No additional client patch needed beyond existing Mythic.
**Cons**: Shares difficulty with M+; need flag to distinguish.

#### Option B: New Difficulty ID (Clean Separation)

Add Difficulty=3 entries for each TBC dungeon (reserve for Endless):

```csv
# New entries for Endless Dungeon (ID range 9300+)
"9300","540","3","Enter the Endless Dungeon.","...","5","DUNGEON_DIFFICULTY_ENDLESS"
"9301","542","3","Enter the Endless Dungeon.","...","5","DUNGEON_DIFFICULTY_ENDLESS"
"9302","543","3","Enter the Endless Dungeon.","...","5","DUNGEON_DIFFICULTY_ENDLESS"
# ... etc for all TBC dungeons
```

**Pros**: Clean separation from M+; dedicated difficulty ID.
**Cons**: Requires client patch; more DBC entries.

### Client Patch Workflow

1. **Export CSV**: DBC → CSV using MPQ tools
2. **Edit CSV**: Add new rows with next available IDs
3. **Convert CSV → DBC**: Use `WDBCTool` or `MyDBCEditor`
4. **Create MPQ patch**: Package as `Patch-E.mpq`
5. **Distribute**: Place in client Data folder

### Server-Side Difficulty Detection

Regardless of approach, the InstanceScript detects Endless mode:

```cpp
void EndlessInstanceScript::Initialize()
{
    // Check if this instance was created for Endless mode
    // Option A: Flag set by Gatekeeper teleport
    // Option B: Check difficulty == DIFFICULTY_ENDLESS (3)
    
    if (instance->GetData(DATA_ENDLESS_MODE) == 1 || 
        instance->GetDifficulty() == DIFFICULTY_ENDLESS)
    {
        _isEndlessMode = true;
        SuppressNormalSpawns();
    }
}
```

### Recommendations

1. **Start with Option A** (reuse Mythic) to avoid client patch complexity
2. **Graduate to Option B** if M+ and Endless coexist on same dungeon and need true separation
3. **Document** which approach is active in server config

---

## Performance Considerations

- Despawn aggressively after floor complete.
- Limit concurrent Endless Dungeon instances (config).
- Snapshot state only on floor boundaries, not every tick.
- Avoid per-player polling; use event hooks.

---

## Implementation Approach

### Recommended Stack
- **C++ InstanceScript** for run manager, state machine, scaling.
- **DB-driven** floor/trash/boss definitions.
- **Eluna** (optional) for rapid iteration on boss tweaks or event hooks.

### File Structure (Example)
```
src/server/scripts/Custom/EndlessDungeon/
  EndlessDungeon.cpp          // Run manager, state machine
  EndlessDungeonScaling.cpp   // Scaling engine
  EndlessDungeonRewards.cpp   // Currency, loot, checkpoint
  EndlessDungeonSpawns.cpp    // Spawn logic
  EndlessDungeonLoader.cpp    // Script loader

sql/custom/
  endless_dungeon_schema.sql  // Tables
  endless_dungeon_data.sql    // Floor templates, trash groups, loot tiers
```

---

## Testing Plan

| Test | Description |
|------|-------------|
| Solo 1–10 | Validate scaling doesn't trivialize or brick |
| Party 5 @ floor 50 | Time-to-kill, wipe rate |
| Checkpoint resume | Ensure state restores correctly |
| Disconnect mid-floor | Player can rejoin |
| Contribution gating | AFK player denied rewards |
| Currency caps | Tokens not re-granted after checkpoint resume |

---

## TBC 5-Player Dungeon Pool (Recommended)

TBC dungeons are ideal for Endless Dungeon floors because they're:
- Compact and linear
- Level 60–70 baseline (easy to scale)
- Familiar to players
- Not competing with WotLK endgame content

### Segment Definition

**One segment = one floor in Endless Dungeon.**

Each segment consists of:
1. Trash pack(s) from the previous boss area (or entrance) to the next boss
2. The boss encounter itself

Example for Hellfire Ramparts (3 bosses = 3 segments):
- **Segment 1**: Entrance → Watchkeeper Gargolmar (trash + boss)
- **Segment 2**: Gargolmar area → Omor the Unscarred (trash + boss)
- **Segment 3**: Omor area → Vazruden/Nazan (trash + boss)

### Recommended TBC Dungeons

| Dungeon | Map ID | Bosses | Segments | Notes |
|---------|--------|--------|----------|-------|
| Hellfire Ramparts | 543 | 3 | 3 | Short, linear |
| The Blood Furnace | 542 | 3 | 3 | Compact, clear layout |
| The Slave Pens | 547 | 3 | 3 | Underwater theme |
| The Underbog | 546 | 4 | 4 | Nature theme, Hungarfen/Ghaz'an/Swamplord/Black Stalker |
| Mana-Tombs | 557 | 4 | 4 | Pandemonius/Tavarok/Nexus-Prince/Yor (heroic) |
| Auchenai Crypts | 558 | 2 | 2 | Shirrak/Exarch Maladaar |
| Sethekk Halls | 556 | 3 | 3 | Darkweaver/Talon King/Anzu (heroic) |
| Shadow Labyrinth | 555 | 4 | 4 | Ambassador/Blackheart/Grandmaster/Murmur |
| The Mechanar | 554 | 4 | 4 | Gyro-Kill/Ironhand/Capacitus/Pathaleon |
| The Botanica | 553 | 5 | 5 | Sarannis/Freywinn/Thorngrin/Laj/Warp Splinter |
| The Arcatraz | 552 | 4 | 4 | Zereketh/Dalliah/Soccothrates/Harbinger |
| The Shattered Halls | 540 | 4 | 4 | Nethekurse/Porung/O'mrogg/Kargath |
| Magister's Terrace | 585 | 4 | 4 | Selin/Vexallus/Delrissa/Kael'thas |
| Old Hillsbrad Foothills | 560 | 3 | 3 | Drake/Skarloc/Epoch Hunter |
| The Black Morass | 269 | 3 | 3 | Chrono Lord/Temporus/Aeonus |

**Total: 53 segments from 15 dungeons.**

With 53 unique segments, players can push through 50+ floors before seeing significant repetition (and with weekly rotation of 5-8 active dungeons, each week feels fresh).

### Variety Analysis

| Metric | Value | Notes |
|--------|-------|-------|
| Total segments | 53 | Each is a unique floor |
| Avg segments/dungeon | 3.5 | Range: 2-5 |
| Weekly active pool | 5-8 dungeons | ~18-28 segments |
| Floors before repeat | ~15-25 | With anti-repeat logic |
| Unique 10-floor runs | 53! / 43! ≈ billions | Theoretical combinations |

### Why Level 25+ Entry

Starting at level 25 ensures players have:
- **Talents**: First tier complete (~15 points spent)
- **Skills**: Core class abilities unlocked
- **Gear**: Enough gear slots filled for meaningful scaling
- **Experience**: Familiarity with group content
- **Item pool**: Sufficient variety for loot rewards (quest gear, dungeon drops)

---

## Spawn Isolation: Reusing Dungeons Without Affecting Originals

This is the critical technical challenge: how to spawn different creatures in the same dungeon map without breaking normal dungeon runs.

### Option 1: Separate Instance Difficulty (Recommended)

WotLK supports multiple difficulties per dungeon. TBC dungeons have Normal and Heroic. We can add a **third "Endless" difficulty**.

#### How It Works
1. Create a new difficulty ID (e.g., `DIFFICULTY_ENDLESS = 4`).
2. When entering Endless mode, force the instance to this difficulty.
3. In InstanceScript, check difficulty and:
   - If Endless: suppress normal spawns, use Endless spawn system.
   - If Normal/Heroic: run vanilla scripts.

#### Implementation
```cpp
// In InstanceScript::Initialize()
if (instance->GetDifficulty() == DIFFICULTY_ENDLESS)
{
    // Disable normal creature spawns
    instance->SetData(DATA_ENDLESS_MODE, 1);
    
    // Clear any pre-spawned creatures in the segment area
    DespawnAllCreaturesInRadius(anchor, 100.0f);
    
    // Endless spawn system takes over
    SpawnEndlessFloor(currentFloor);
}
```

#### Difficulty Registration
```cpp
// In worldserver.conf or via DB
// Map 543 (Hellfire Ramparts) supports difficulties: 0 (Normal), 1 (Heroic), 4 (Endless)
```

**Pros**: Clean separation; no phasing complexity; works with existing instance system.
**Cons**: Requires adding difficulty to each TBC map; client shows "Unknown Difficulty" (cosmetic).

### Option 2: Phasing Within Instance

Use phase masks to separate Endless spawns from normal spawns.

#### How It Works
1. Normal dungeon creatures have `phasemask = 1`.
2. Endless creatures spawn with `phasemask = 2`.
3. On Endless entry, set players to `phasemask = 2`.

#### Implementation
```cpp
// On Endless entry
for (auto& player : partyPlayers)
{
    player->SetPhaseMask(2, true);
}

// Spawn Endless creatures with phase 2
Creature* c = instance->SummonCreature(entry, pos);
c->SetPhaseMask(2, true);
```

**Pros**: No difficulty modification needed.
**Cons**: Requires all Endless spawns to be runtime-summoned (not DB-spawned); players might see brief flicker.

### Option 3: Full Runtime Spawning (No DB Creatures)

Don't rely on DB creature spawns at all. All Endless creatures are summoned at runtime.

#### How It Works
1. On Endless floor start, despawn ALL creatures in segment radius.
2. Spawn Endless trash/boss via `SummonCreature()`.
3. On floor complete, despawn all.

#### Implementation
```cpp
void EndlessInstance::StartFloor(uint32 floorId)
{
    FloorTemplate tmpl = LoadFloorTemplate(floorId);
    
    // Despawn everything in radius
    DespawnAllCreaturesInRadius(tmpl.anchor, 80.0f);
    
    // Spawn our pack
    for (auto& spawn : tmpl.trashSpawns)
    {
        Position pos = tmpl.anchor + spawn.relativePos;
        Creature* c = instance->SummonCreature(spawn.entry, pos);
        ApplyEndlessScaling(c, floor, partySize, targetLevel);
        trackedCreatures.insert(c->GetGUID());
    }
}
```

**Pros**: Maximum control; no conflict with normal dungeon.
**Cons**: Must handle all spawns manually; can't reuse DB spawn templates directly.

### Recommended Approach: Option 1 + Option 3 Hybrid

1. Register Endless difficulty for TBC maps.
2. When instance is Endless difficulty:
   - Suppress or despawn DB-spawned creatures on load.
   - Use runtime spawning for all Endless content.
3. Normal/Heroic runs are completely unaffected.

---

## Creature Level Scaling (Any Target Level)

AzerothCore creatures have a fixed level from `creature_template`. To support Endless runs at any player level, we need runtime level scaling.

### Challenge
- `creature_template.minlevel` / `maxlevel` are static.
- We need creatures to scale to Target Level (e.g., level 30 run uses level 30 creatures).

### Solution: Runtime Stat Override

On spawn, override creature stats based on Target Level:

```cpp
void ApplyEndlessScaling(Creature* creature, uint32 floor, uint32 partySize, uint32 targetLevel)
{
    // 1. Set creature level
    creature->SetLevel(targetLevel);
    
    // 2. Calculate base stats for target level
    CreatureBaseStats const* stats = sObjectMgr->GetCreatureBaseStats(targetLevel, creature->GetCreatureTemplate()->unit_class);
    
    // 3. Apply floor and party scaling
    float hpMult = CalculateHPMultiplier(floor, partySize);
    float dmgMult = CalculateDamageMultiplier(floor, partySize);
    
    // 4. Set health
    uint32 baseHealth = stats->GenerateHealth(creature->GetCreatureTemplate());
    uint32 scaledHealth = uint32(baseHealth * hpMult);
    creature->SetMaxHealth(scaledHealth);
    creature->SetHealth(scaledHealth);
    
    // 5. Set damage
    float baseDamage = stats->GenerateBaseDamage(creature->GetCreatureTemplate());
    float scaledDamage = baseDamage * dmgMult;
    creature->SetBaseWeaponDamage(BASE_ATTACK, MINDAMAGE, scaledDamage * 0.9f);
    creature->SetBaseWeaponDamage(BASE_ATTACK, MAXDAMAGE, scaledDamage * 1.1f);
    creature->UpdateDamagePhysical(BASE_ATTACK);
    
    // 6. Set armor (scales with level)
    creature->SetArmor(stats->GenerateArmor(creature->GetCreatureTemplate()));
    
    // 7. Optionally: spell damage via aura
    // creature->AddAura(SPELL_ENDLESS_DAMAGE_SCALE, creature);
}
```

### AzerothCore API References
- `Creature::SetLevel(uint32 level)` – Sets creature level.
- `CreatureBaseStats` – Provides base HP/mana/damage for level+class.
- `sObjectMgr->GetCreatureBaseStats(level, unitClass)` – Lookup function.
- `Creature::SetMaxHealth()`, `Creature::SetHealth()` – HP manipulation.
- `Creature::SetBaseWeaponDamage()` – Melee damage.
- `Creature::UpdateDamagePhysical()` – Recalculate after damage change.

### Spell Damage Scaling
For caster mobs, melee damage scaling isn't enough. Options:
1. **Aura-based**: Apply a hidden aura that modifies spell damage (`SPELL_AURA_MOD_DAMAGE_DONE`).
2. **Script hook**: Override `Creature::SpellDamageBonusDone()`.
3. **Spell replacement**: Map original spells to scaled versions.

**Recommended**: Aura-based is cleanest. Create a custom spell:
```sql
-- Custom spell: Endless Dungeon Damage Scaling
-- Applies SPELL_AURA_MOD_DAMAGE_PERCENT_DONE to all schools
-- Stacks based on floor/party size
```

### Example Scaling Table

| Target Level | Base HP (Elite) | Base Damage | Notes |
|--------------|-----------------|-------------|-------|
| 20 | 1,500 | 40 | Low-level brackets |
| 40 | 4,000 | 80 | Mid-level |
| 60 | 8,000 | 150 | Classic cap |
| 70 | 15,000 | 250 | TBC cap |
| 80 | 25,000 | 400 | WotLK cap |

These are then multiplied by floor and party size factors.

---

## Preventing Collision with Normal Dungeon Runs

### Instance ID Separation
- Endless runs use **separate instance IDs** from normal runs.
- When player enters Endless, create a new instance with Endless difficulty.
- Normal groups entering the same dungeon get a different instance.

### DB Spawn Suppression
For Endless difficulty, set a flag that prevents DB-spawned creatures from loading:

```cpp
// In Map::LoadGrid() or InstanceScript::Initialize()
if (GetDifficulty() == DIFFICULTY_ENDLESS)
{
    // Skip loading creature spawns from creature table
    skipCreatureSpawns = true;
}
```

Or, on instance load, immediately despawn all DB creatures:
```cpp
void EndlessInstanceScript::Initialize()
{
    if (instance->GetDifficulty() == DIFFICULTY_ENDLESS)
    {
        for (auto& pair : instance->GetCreatureMap())
        {
            pair.second->DespawnOrUnsummon();
        }
    }
}
```

---

## Replayability Enhancements

1. **Rotating Dungeon Pool**: Each week, 5 of 15 TBC dungeons are active. Forces variety.
2. **Daily First-Run Bonus**: First 10 floors each day grant 2× Essence.
3. **Weekly Leaderboard Reset**: Fresh competition each week.
4. **Seasonal Cosmetics**: Time-limited rewards for floor milestones.
5. **Greedy Goblin Hunt**: Track total goblins killed; milestone rewards.
6. **Dungeon Mastery**: Bonus tokens for completing runs in specific dungeons.
7. **Party Size Challenges**: Bonus for solo runs or full 5-man at high floors.

---

## Dungeon Cloning: Effort Analysis

### What "Cloning a Dungeon" Would Require

If we were to create a fully separate dungeon copy (new map ID), the effort is **significant**:

| Asset | Effort | Notes |
|-------|--------|-------|
| **Map.dbc** | Medium | Add new entry with unique MapID, copy properties |
| **MapDifficulty.dbc** | Low | Add difficulty entries for new MapID |
| **AreaTable.dbc** | Medium | Clone all area entries for the map |
| **WorldMapArea.dbc** | Low | Add minimap reference |
| **LfgDungeons.dbc** | Low | Optional for LFG integration |
| **creature table** | High | Copy ~50-200 rows per dungeon, update map column |
| **gameobject table** | High | Copy ~30-100 rows per dungeon |
| **creature_addon** | Medium | Copy linked rows |
| **creature_template_addon** | Low | Usually shared |
| **instance_template** | Low | Add new entry |
| **access_requirement** | Low | Add entry requirements |
| **Client MPQ patch** | High | Requires distributing updated DBCs |

**Estimated effort per dungeon: 4-8 hours + client patch distribution**

### Why Cloning Is NOT Recommended

1. **Maintenance burden**: Every upstream fix to creature spawns must be duplicated
2. **Client patch required**: Players must install custom DBC files
3. **No gameplay benefit**: Same result achievable with runtime scaling
4. **Database bloat**: 15 TBC dungeons × 100+ rows each = 1500+ duplicate rows

### Recommended: Mythic Difficulty + Runtime Scaling

**Zero cloning required.** Reuse existing M+ infrastructure:

| Component | Existing | Effort |
|-----------|----------|--------|
| Difficulty 2 (Mythic) | ✅ Already in MapDifficulty.dbc | None |
| Runtime scaling | ✅ `MythicDifficultyScaling.cpp` | Extend |
| Dungeon profiles | ✅ `dc_dungeon_mythic_profile` | Add rows |
| Instance detection | ✅ `MythicPlusRunManager` | Extend |

---

## Mythic-Only Approach: Run Flow Design

Using Mythic difficulty (Difficulty=2) for Endless Dungeon with runtime scaling.

### Run Lifecycle

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         ENDLESS DUNGEON RUN FLOW                        │
└─────────────────────────────────────────────────────────────────────────┘

[Gatekeeper NPC]
       │
       ▼
┌─────────────────┐
│ SELECT ACTION   │
│ • New Run       │
│ • Continue Run  │
│ • View Progress │
└─────────────────┘
       │
       ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          RUN INITIALIZATION                             │
│  1. Determine Target Level (party avg or lowest)                        │
│  2. Set starting floor (1 for new, checkpoint floor for continue)       │
│  3. Select first dungeon from pool (random weighted)                    │
│  4. Create Mythic instance (Difficulty=2) with ENDLESS flag             │
│  5. Teleport party to dungeon entrance                                  │
└─────────────────────────────────────────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                           FLOOR LOOP                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                 │
│  │ FLOOR START │───►│ TRASH PHASE │───►│ BOSS PHASE  │                 │
│  │ (spawn pack)│    │ (kill all)  │    │ (kill boss) │                 │
│  └─────────────┘    └─────────────┘    └─────────────┘                 │
│         │                  │                  │                         │
│         │                  │                  ▼                         │
│         │                  │         ┌─────────────────┐               │
│         │                  │         │ FLOOR COMPLETE  │               │
│         │                  │         │ • Award Essence │               │
│         │                  │         │ • Award Tokens  │               │
│         │                  │         │   (if new floor)│               │
│         │                  │         │ • Spawn cache   │               │
│         │                  │         └─────────────────┘               │
│         │                  │                  │                         │
│         │                  ▼                  ▼                         │
│         │           ┌─────────────┐   ┌─────────────────┐              │
│         │           │    WIPE     │   │ CHECKPOINT?     │              │
│         │           │ +1 strike   │   │ floor % 5 == 0  │              │
│         │           └─────────────┘   └─────────────────┘              │
│         │                  │                  │                         │
│         │                  ▼                  ▼                         │
│         │           ┌───────────────────────────────┐                  │
│         │           │ STRIKES >= 3?                 │                  │
│         │           │ YES → End Run                 │                  │
│         │           │ NO  → Reset to checkpoint     │                  │
│         │           │       OR respawn floor        │                  │
│         │           └───────────────────────────────┘                  │
│         │                                                               │
│         ▼                                                               │
│  ┌─────────────────────────────────────────────────────────────┐       │
│  │ NEXT FLOOR DECISION                                          │       │
│  │ • Same dungeon (next segment) if segments remain             │       │
│  │ • Random new dungeon if all segments cleared                 │       │
│  │ • Apply floor+1 scaling                                      │       │
│  └─────────────────────────────────────────────────────────────┘       │
│                                     │                                   │
│                                     ▼                                   │
│                              [Loop to FLOOR START]                      │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                            RUN END                                      │
│  • Display summary (highest floor, time, rewards)                       │
│  • Award bonus tokens for new personal best                             │
│  • Update leaderboard                                                   │
│  • Teleport to Gatekeeper / Mall                                        │
│  • Options: Retry (same level) / Increase Level / Exit                  │
└─────────────────────────────────────────────────────────────────────────┘
```

### Smooth Run Feel: Key UX Principles

| Principle | Implementation |
|-----------|----------------|
| **No loading screens** | Stay in same instance; teleport to new dungeon segment positions |
| **Minimal downtime** | 5s intermission between floors (loot + breathe) |
| **Clear progress** | HUD shows: Floor, Strikes, Tokens, Essence, XP Bonus |
| **Predictable pacing** | ~2-3 min per floor = 15-20 floors/hour |
| **Quick restart** | "Retry" button on death/end; no NPC re-visit needed |

---

## Player Progression System

### Run Level Concept

Each player has an **Endless Run Level** (1-∞) representing their personal progression tier.

| Run Level | Floor Scaling | Reward Multiplier | Unlock Requirement |
|-----------|---------------|-------------------|--------------------|
| 1 | ×1.00 base | ×1.00 | Default |
| 2 | ×1.15 | ×1.10 | Clear floor 10 at Level 1 |
| 3 | ×1.30 | ×1.20 | Clear floor 15 at Level 2 |
| 4 | ×1.50 | ×1.30 | Clear floor 20 at Level 3 |
| 5 | ×1.75 | ×1.45 | Clear floor 25 at Level 4 |
| 6+ | +0.25 per | +0.15 per | Clear floor 25+ at previous |

### Run Level Progression Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                   RUN LEVEL PROGRESSION                         │
└─────────────────────────────────────────────────────────────────┘

Player starts at Run Level 1
          │
          ▼
    ┌───────────────┐
    │ Complete Run  │
    │ (any floor)   │
    └───────────────┘
          │
          ▼
    ┌───────────────────────────────────────┐
    │ HIGHEST FLOOR >= UNLOCK THRESHOLD?    │
    │                                       │
    │ Run Level 1: Floor 10 required        │
    │ Run Level 2: Floor 15 required        │
    │ Run Level 3: Floor 20 required        │
    │ Run Level 4+: Floor 25 required       │
    └───────────────────────────────────────┘
          │
          ├── NO ──► Stay at current Run Level
          │          (can retry for better floor)
          │
          └── YES ─► ┌─────────────────────────┐
                     │ UNLOCK NEXT RUN LEVEL   │
                     │ • Announce achievement  │
                     │ • Award bonus tokens    │
                     │ • Show "Level Up" popup │
                     └─────────────────────────┘
                               │
                               ▼
                     ┌─────────────────────────┐
                     │ NEXT RUN OPTIONS        │
                     │ • Stay at current level │
                     │ • Advance to new level  │
                     │ • Select any unlocked   │
                     └─────────────────────────┘
```

### Run Level Selection at Gatekeeper

```
┌─────────────────────────────────────────────────────────────────┐
│               ENDLESS DUNGEON - SELECT DIFFICULTY               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Your Highest Unlocked: Level 5                                 │
│  Your Personal Best: Floor 47 (Level 4)                         │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ [Level 1] Apprentice     - 1.0x scaling  - 1.0x rewards │   │
│  │ [Level 2] Journeyman     - 1.15x scaling - 1.1x rewards │   │
│  │ [Level 3] Expert         - 1.30x scaling - 1.2x rewards │   │
│  │ [Level 4] Master     ★   - 1.50x scaling - 1.3x rewards │   │
│  │ [Level 5] Grandmaster    - 1.75x scaling - 1.45x rewards│   │
│  │ [Level 6] 🔒 Locked      - Clear F25 at Level 5         │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ★ = Your current best                                          │
│                                                                 │
│  [Start New Run]  [Continue Run (F32)]  [View Leaderboard]     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Random Dungeon Selection Mechanism

### Pool-Based Selection

```cpp
struct EndlessDungeonPool
{
    std::vector<uint32> activeDungeons;  // Current week's pool (5-8 dungeons)
    std::unordered_map<uint32, float> weights;  // Selection weights
    std::unordered_set<uint32> recentlyUsed;    // Last 3 dungeons used
};
```

### Selection Algorithm

```
On Floor Complete (ready for next floor):

1. Get remaining segments in current dungeon
   IF segments remain → Use next segment (no dungeon change)
   ELSE → Select new dungeon

2. Build selection pool:
   - Start with all active dungeons this week
   - Remove last 2 dungeons used (anti-repeat)
   - Apply weights based on:
     • Floor range affinity (some dungeons better for high floors)
     • Player/group completion history (favor unvisited)
     • Random factor (30% weight)

3. Weighted random selection from pool

4. Select random segment within chosen dungeon
```

### Weekly Rotation

| Week | Active Pool (Example) | Notes |
|------|----------------------|-------|
| Week 1 | Ramparts, Blood Furnace, Slave Pens, Mana-Tombs, Mechanar | 5 dungeons |
| Week 2 | Underbog, Auchenai, Sethekk, Shadow Lab, Botanica | 5 different |
| Week 3 | Arcatraz, Shattered Halls, Magister's Terrace, Old Hillsbrad, Black Morass | 5 different |
| Week 4 | Mix of all (random 7) | Larger pool |

---

## Death, Wipe, and Checkpoint Handling

### Death Terminology

| Term | Definition |
|------|------------|
| **Death** | Single player dies (can be ressed) |
| **Wipe** | All players dead simultaneously |
| **Strike** | Penalty from wipe (3 strikes = run end) |
| **Checkpoint** | Saved progress at floors 5, 10, 15, ... |

### Wipe Handling Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                      WIPE DETECTED                              │
│              (All party members dead)                           │
└─────────────────────────────────────────────────────────────────┘
                           │
                           ▼
                 ┌─────────────────┐
                 │ strikes += 1    │
                 │ Show HUD update │
                 └─────────────────┘
                           │
                           ▼
              ┌────────────────────────┐
              │   strikes >= 3 ?       │
              └────────────────────────┘
                    │           │
                   YES          NO
                    │           │
                    ▼           ▼
        ┌─────────────────┐  ┌─────────────────────────────────┐
        │    RUN ENDED    │  │ WIPE RECOVERY OPTIONS           │
        │                 │  │                                 │
        │ • Show summary  │  │ ┌─────────────────────────────┐ │
        │ • Award earned  │  │ │ [Retry Floor]               │ │
        │   rewards       │  │ │   Respawn at floor start    │ │
        │ • Save progress │  │ │   Keep current floor        │ │
        │   (if eligible) │  │ │   -10% Essence penalty      │ │
        │ • Offer options │  │ └─────────────────────────────┘ │
        │                 │  │                                 │
        └─────────────────┘  │ ┌─────────────────────────────┐ │
                             │ │ [Reset to Checkpoint]       │ │
                             │ │   Return to last saved      │ │
                             │ │   floor (5, 10, 15, ...)    │ │
                             │ │   Reset strikes to 0        │ │
                             │ │   Keep all rewards earned   │ │
                             │ └─────────────────────────────┘ │
                             │                                 │
                             │ ┌─────────────────────────────┐ │
                             │ │ [End Run]                   │ │
                             │ │   Exit and keep rewards     │ │
                             │ │   Checkpoint saved if valid │ │
                             │ └─────────────────────────────┘ │
                             │                                 │
                             └─────────────────────────────────┘
```

### Checkpoint Save Logic

```cpp
void EndlessRunManager::OnFloorComplete(uint32 floor)
{
    if (floor % 5 == 0)  // Checkpoint floor
    {
        SaveCheckpoint(floor);
        SendAddonMessage("EDNG|CHECKPOINT|" + std::to_string(floor));
        
        // Visual feedback
        PlaySound(SOUND_CHECKPOINT_SAVED);
        SpawnCheckpointVFX();
    }
}

void EndlessRunManager::SaveCheckpoint(uint32 floor)
{
    CharacterDatabase.Execute(
        "REPLACE INTO dc_endless_checkpoints "
        "(character_guid, floor, target_level, run_level, tokens_collected, created_at) "
        "VALUES ({}, {}, {}, {}, '{}', NOW())",
        _leaderGuid, floor, _targetLevel, _runLevel, 
        SerializeCollectedFloors()
    );
}
```

### Resume from Checkpoint

```cpp
void EndlessRunManager::ResumeFromCheckpoint(Player* leader)
{
    // Load checkpoint
    auto checkpoint = LoadCheckpoint(leader->GetGUID().GetCounter());
    
    if (!checkpoint)
    {
        SendError("No checkpoint found.");
        return;
    }
    
    // Reset strikes
    _strikes = 0;
    
    // Set floor to checkpoint floor
    _currentFloor = checkpoint.floor;
    
    // Restore tokens collected (prevent double-reward)
    _tokensCollected = checkpoint.tokensCollected;
    
    // Select dungeon for this floor
    SelectDungeonForFloor(_currentFloor);
    
    // Teleport and start
    TeleportPartyToFloor(_currentFloor);
    StartFloor(_currentFloor);
    
    SendAddonMessage("EDNG|RESUME|" + std::to_string(_currentFloor));
}
```

### End Run Options

After run ends (3 strikes or voluntary exit):

```
┌─────────────────────────────────────────────────────────────────┐
│                     RUN COMPLETE                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Highest Floor: 23                                              │
│  Run Level: 3 (Expert)                                          │
│  Time: 47:32                                                    │
│                                                                 │
│  Rewards Earned:                                                │
│    Tokens: 340 (includes 23 new floor bonuses)                  │
│    Essence: 1,150                                               │
│    Loot Caches: 5 (opened: 4)                                   │
│                                                                 │
│  Checkpoint Saved: Floor 20                                     │
│                                                                 │
│  ┌───────────────────────────────────────────────────────┐     │
│  │ [Retry at Level 3]                                     │     │
│  │   Start new run at current Run Level                   │     │
│  │   Your checkpoint is preserved for Continue option     │     │
│  └───────────────────────────────────────────────────────┘     │
│                                                                 │
│  ┌───────────────────────────────────────────────────────┐     │
│  │ [Try Level 4] ★ UNLOCKED!                              │     │
│  │   You cleared Floor 20 at Level 3!                     │     │
│  │   Higher scaling (×1.50) but better rewards (×1.30)    │     │
│  └───────────────────────────────────────────────────────┘     │
│                                                                 │
│  ┌───────────────────────────────────────────────────────┐     │
│  │ [Continue from Checkpoint (F20)]                       │     │
│  │   Resume your saved progress                           │     │
│  │   Strikes reset to 0                                   │     │
│  └───────────────────────────────────────────────────────┘     │
│                                                                 │
│  ┌───────────────────────────────────────────────────────┐     │
│  │ [Exit to Town]                                         │     │
│  │   Return to Gatekeeper / Mall                          │     │
│  └───────────────────────────────────────────────────────┘     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Reward Processing Between Runs

### Per-Floor Rewards (Immediate)

| Reward | When | Amount |
|--------|------|--------|
| Essence | Every floor | `10 + (floor × 2)` |
| Tokens | First clear of floor | `5 + (floor × 1)` |
| Loot Cache | Every 5 floors | Tier-appropriate gear |
| XP Bonus | Cumulative | +1% per floor cleared |

### End-of-Run Rewards

| Reward | Condition | Amount |
|--------|-----------|--------|
| Personal Best Bonus | New highest floor at Run Level | `floor × 10` Tokens |
| Leaderboard Bonus | Top 10 weekly | Scaling Tokens |
| Run Level Unlock | Meet threshold | Achievement + 50 Tokens |
| Streak Bonus | 3+ runs same day | +10% Essence |

### Currency Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    REWARD FLOW                                  │
└─────────────────────────────────────────────────────────────────┘

  FLOOR COMPLETE
       │
       ├── ESSENCE (always) ──────────────────────► Player Currency
       │     Formula: 10 + (floor × 2) × runLevelMult
       │
       ├── TOKENS (first-time) ───────────────────► Player Currency
       │     Formula: 5 + floor × runLevelMult
       │     Check: floor NOT in tokensCollected set
       │
       ├── XP BONUS (stacking) ───────────────────► Buff / Aura
       │     +1% per floor, max +100%
       │
       └── LOOT CACHE (every 5 floors) ───────────► Spawn GO
             Tier based on floor range + Target Level

  RUN END
       │
       ├── PERSONAL BEST BONUS ───────────────────► Player Currency
       │     If newHighest > previousHighest at this RunLevel
       │
       ├── RUN LEVEL UNLOCK ──────────────────────► Unlock flag
       │     If floor >= unlockThreshold[currentRunLevel]
       │
       └── LEADERBOARD UPDATE ────────────────────► dc_endless_leaderboard
             Insert/update with floor, time, runLevel
```

---

## Summary
This architecture supports the Manastorm-inspired concept:
- **No affixes**—difficulty is purely scaling.
- **Checkpoints** every 5 floors, stored in DB.
- **Dual currency** with one-time and repeatable tracks.
- **TBC dungeon pool** (15 dungeons, 53 segments).
- **Spawn isolation** via Endless difficulty + runtime spawning.
- **Level scaling** via runtime stat override on creature spawn.
- **Addon messaging** for lightweight client UI.
- **Anti-exploit** contribution and level checks.
- **Replayability** via rotation, daily bonus, leaderboards, seasonal rewards.
- **Run Levels** for vertical progression across runs.
- **Smooth flow** with minimal downtime and clear feedback.
- **Death handling** with retry, checkpoint, and exit options.

---

## New Systems (from Comparative Analysis)

> See [COMPARATIVE_ANALYSIS.md](COMPARATIVE_ANALYSIS.md) for full research and rationale.

The following systems are recommended additions based on analysis of Torghast, Hades, D3 Greater Rifts, and WoW Delves.

---

### Endless Runes (Temporary Powers)

**Concept:** After each boss kill, player picks 1 of 3 Runes. Runes last until run ends. Maximum 5 active Runes; after 5, must replace one.

#### Database Schema

```sql
-- Rune definitions
CREATE TABLE dc_endless_runes (
    rune_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(64) NOT NULL,
    description TEXT,
    category ENUM('offense', 'defense', 'utility', 'class', 'synergy') NOT NULL,
    rarity ENUM('common', 'uncommon', 'rare', 'epic') DEFAULT 'common',
    min_floor INT DEFAULT 0,
    effect_type VARCHAR(32) NOT NULL,
    effect_value FLOAT NOT NULL,
    effect_target VARCHAR(32),
    synergy_tag VARCHAR(32),
    class_mask INT DEFAULT 0,
    icon_id INT DEFAULT 0,
    weight INT DEFAULT 100
);

-- Active Runes per run
CREATE TABLE dc_endless_run_runes (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    run_id BIGINT NOT NULL,
    character_guid INT NOT NULL,
    rune_id INT NOT NULL,
    slot INT NOT NULL,
    acquired_floor INT NOT NULL,
    upgraded BOOL DEFAULT FALSE
);
```

#### Sample Runes

| Rune | Category | Rarity | Effect |
|------|----------|--------|--------|
| Rune of Fury | Offense | Common | +15% Attack Speed |
| Rune of Recovery | Defense | Common | Heal 3% HP on kill |
| Rune of the Juggernaut | Defense | Uncommon | +25% HP, −10% Speed |
| Rune of Devastation | Offense | Rare | +30% Crit Damage |
| Rune of the Phoenix | Defense | Epic | Revive once per floor with 50% HP |

---

### Fragments (Run Currency)

**Concept:** Dropped by elites and in caches. Spent at checkpoint vendors.

| Source | Fragments |
|--------|-----------|
| Elite mob | `5 + floor/5` |
| Boss kill | `10 + floor/3` |
| Cache loot | `3 + floor/10` |
| Greedy Goblin | `50 + floor` |

---

### Difficulty Selection

**Normal/Heroic/Mythic for solo accessibility.**

#### Design Principle: Scale Creatures, Not Players

WotLK 3.3.5a does not support player level scaling (like retail Timewalking). Our solution:
- **Players keep their actual stats** (no artificial buffs/debuffs to player power)
- **Creatures are scaled** based on difficulty + party size + floor

This means a level 25 in quest greens can solo Normal, while a level 80 in BiS still finds Mythic challenging.

#### Difficulty Multipliers

| Difficulty | Base HP× | Base DMG× | Reward× | Notes |
|------------|----------|-----------|---------|-------|
| **Normal** | 1.0× | 1.0× | 100% | Entry mode, solo-friendly |
| **Heroic** | 1.3× | 1.3× | 130% | Moderate challenge |
| **Mythic** | 1.6× | 1.6× | 175% | Group recommended |

#### Combined with Party Size Scaling

| Party Size | HP× (before diff) | Final HP× (Normal) | Final HP× (Heroic) | Final HP× (Mythic) |
|------------|-------------------|--------------------|--------------------|---------------------|
| 1 (solo) | 0.30 | 0.30 | 0.39 | 0.48 |
| 2 | 0.60 | 0.60 | 0.78 | 0.96 |
| 3 | 0.80 | 0.80 | 1.04 | 1.28 |
| 4 | 0.95 | 0.95 | 1.24 | 1.52 |
| 5 | 1.00 | 1.00 | 1.30 | 1.60 |

#### Example: Level 25 Solo Player (Floor 1)

Base creature HP at level 25: ~1,500 (elite)

| Difficulty | HP After Scaling | Expected Kill Time |
|------------|------------------|---------------------|
| Normal | 1,500 × 0.30 = **450 HP** | 5-8 seconds |
| Heroic | 1,500 × 0.39 = **585 HP** | 8-12 seconds |
| Mythic | 1,500 × 0.48 = **720 HP** | 12-18 seconds |

At Normal difficulty, a fresh level 25 in quest greens can comfortably progress.

#### Database Schema

```sql
CREATE TABLE dc_endless_difficulty (
    difficulty_id TINYINT PRIMARY KEY,
    name VARCHAR(16) NOT NULL,
    hp_multiplier FLOAT NOT NULL DEFAULT 1.0,
    dmg_multiplier FLOAT NOT NULL DEFAULT 1.0,
    reward_multiplier FLOAT NOT NULL DEFAULT 1.0,
    min_recommended_ilvl SMALLINT DEFAULT 0,
    description TEXT
);

INSERT INTO dc_endless_difficulty VALUES
(0, 'Normal', 1.0, 1.0, 1.00, 0, 'Entry difficulty. Solo-friendly.'),
(1, 'Heroic', 1.3, 1.3, 1.30, 0, 'Moderate challenge. +30% rewards.'),
(2, 'Mythic', 1.6, 1.6, 1.75, 0, 'Maximum challenge. +75% rewards.');

-- Add difficulty column to runs table
ALTER TABLE dc_endless_runs ADD COLUMN difficulty_id TINYINT DEFAULT 0 AFTER target_level;
```

#### C++ Implementation

```cpp
float CalculateFinalHPMultiplier(uint32 partySize, uint8 difficultyId)
{
    // Party size scaling
    static const float partyMult[] = { 1.0f, 0.30f, 0.60f, 0.80f, 0.95f, 1.00f };
    float partySizeMult = partyMult[std::min(partySize, 5u)];
    
    // Difficulty scaling from DB
    float diffMult = sEndlessMgr->GetDifficultyMultiplier(difficultyId);
    
    return partySizeMult * diffMult;
}

void ApplyEndlessScaling(Creature* creature, EndlessRun* run)
{
    uint32 targetLevel = run->GetTargetLevel();
    uint32 partySize = run->GetPartySize();
    uint8 difficultyId = run->GetDifficultyId();
    uint32 floor = run->GetCurrentFloor();
    
    // Set creature level to match target
    creature->SetLevel(targetLevel);
    
    // Get base stats for level
    CreatureBaseStats const* stats = sObjectMgr->GetCreatureBaseStats(
        targetLevel, creature->GetCreatureTemplate()->unit_class);
    
    // Calculate multipliers
    float hpMult = CalculateFinalHPMultiplier(partySize, difficultyId);
    float floorMult = GetFloorMultiplier(floor);
    
    // Apply HP
    uint32 baseHP = stats->GenerateHealth(creature->GetCreatureTemplate());
    uint32 scaledHP = uint32(baseHP * hpMult * floorMult);
    creature->SetMaxHealth(scaledHP);
    creature->SetHealth(scaledHP);
    
    // Apply damage similarly...
}
```

---

### Endless Talents (Meta Progression)

**Permanent upgrades purchased with Tokens/Essence between runs.**

| Talent | Tier | Cost | Effect |
|--------|------|------|--------|
| Endless Vigor | 1 | 10 Tokens | +5% max HP |
| Endless Might | 1 | 10 Tokens | +5% damage |
| Starting Rune | 2 | 25 Tokens | Begin with 1 Common Rune |
| Fragment Finder | 2 | 25 Tokens | +15% Fragment drops |
| Checkpoint Heal | 3 | 50 Tokens | Full heal at checkpoints |

---

### Weekly Modifiers

**Blessings (buffs) and Torments (debuffs with bonus rewards).**

| Type | Example | Effect | Reward Bonus |
|------|---------|--------|--------------|
| Blessing | Swift | +15% speed | None |
| Torment | Frail | −15% HP | +20% rewards |

---

## Implementation Phases

### Phase 1 (MVP)
- [x] Basic floor progression
- [x] Checkpoints every 5 floors
- [x] Token/Essence currencies
- [x] 3-strike system
- [x] Difficulty selection — UI spec complete (ADDON_UI_Design.md §2.5)
- [x] Difficulty selection — DB schema + C++ code spec complete
- [ ] Difficulty selection — C++ implementation
- [ ] Basic Rune system (30-50 Runes)

### Phase 2 (Enhancement)
- [ ] Fragments + checkpoint vendor
- [ ] Rune rarity tiers
- [ ] Scoring system

### Phase 3 (Meta)
- [ ] Endless Talents tree
- [ ] Weekly Blessings/Torments
- [ ] Leaderboards
