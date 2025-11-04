# Phase 3C: Token System Integration

**Objective:** Integrate token acquisition hooks into the server so players earn upgrade tokens and artifact essence through gameplay activities.

**Status:** In Planning & Design Phase

---

## Token Acquisition Sources

### Primary Token Sources

| Activity | Token Type | Award Amount | Cooldown | Notes |
|----------|-----------|--------------|----------|-------|
| **Quest Completion** | Upgrade Token | 10-50 | Per char | Scales by quest level/difficulty |
| **Dungeon Kill (Rare)** | Upgrade Token | 5-20 | N/A | Scales by enemy level |
| **Dungeon Boss Kill** | Upgrade Token + Essence | 25 + 5 | Per boss | All players in group |
| **Raid Kill (Heroic+)** | Upgrade Token + Essence | 50 + 10 | Per boss | All raid members |
| **PvP Kill** | Upgrade Token | 15 | Per kill | Scaled by opponent level |
| **Battleground Win** | Upgrade Token | 25 | Per bg | All winners |
| **Daily Quest** | Upgrade Token | 20 | Per day | Account-wide cap |
| **World Event** | Essence | 10 | Event-dependent | Seasonal/holiday events |
| **Achievement** | Essence | 50 | Per achievement | One-time awards |

### Token Caps (Per Season)

- **Weekly Upgrade Token Cap:** 500 (prevents farming)
- **Essence Cap:** Unlimited (artifact-focused players can grind)
- **Daily Quest Cap:** 100 tokens (world quests + daily dungeons combined)

---

## Implementation Strategy

### 1. Hooks into Server Events

**Location:** `ItemUpgradeManager` class adds the following virtual methods:

```cpp
// Quest completion hook
void OnQuestComplete(uint32 player_guid, uint32 quest_id, uint8 quest_level);

// PvP combat hook
void OnPlayerKill(uint32 killer_guid, uint32 victim_guid, uint8 victim_level);

// Creature kill hook (dungeon/raid/world)
void OnCreatureKill(uint32 player_guid, uint32 creature_id, uint32 creature_level, bool is_boss);

// Daily quest hook
void OnDailyQuestTaken(uint32 player_guid, uint32 quest_id);

// Achievement hook
void OnAchievementComplete(uint32 player_guid, uint32 achievement_id);
```

**Integration Point:** Existing `PlayerScript` and `CreatureScript` hooks in AzerothCore call these methods.

### 2. Script Hook Implementations

**File:** `src/server/scripts/DC/ItemUpgrades/ItemUpgradeTokenHooks.cpp`

Implements C++ script listeners:
- `PlayerScript` hook: `OnPVPKill()`, `OnQuestComplete()`
- `CreatureScript` hook: `OnDeath()`
- `GlobalScript` hook: `OnAchievementComplete()`

### 3. Configuration SQL

**File:** `Custom/Custom feature SQLs/chardb/ItemUpgrades/dc_token_event_config.sql`

Defines reward amounts and triggers:
- Quest → Token mapping (quest_id → token_amount)
- Creature → Token mapping (creature_id → token_amount, is_boss flag)
- Achievement → Essence mapping
- Weekly caps and thresholds

### 4. Player Token Status Display

Extended NPC gossip to show:
- Current token balance (both types)
- Weekly earning progress / cap remaining
- Recent transaction history (last 5 acquisitions)
- Achievement-based essence rewards
- Weekly reset timer

**NPC Menu Items:**
```
[Token Status] - View current balance & weekly cap
[Earnings History] - Last 10 token acquisitions
[Achievement Rewards] - Unclaimed essence from achievements
```

### 5. Admin Commands

**New Commands:** `.upgrade token [subcommand]`

```
.upgrade token add <player> <amount> [type]     # Award tokens
.upgrade token remove <player> <amount> [type]  # Remove tokens
.upgrade token set <player> <amount> [type]     # Set exact amount
.upgrade token info <player>                    # Show player token info
.upgrade token reset [season]                   # Reset season caps (admin)
```

---

## Database Schema Extensions

### New Table: dc_token_event_config

```sql
CREATE TABLE `dc_token_event_config` (
  `event_id` INT PRIMARY KEY AUTO_INCREMENT,
  `event_type` ENUM('quest', 'creature', 'achievement', 'pvp'),
  `event_source_id` INT,              -- quest_id, creature_id, achievement_id, or 0 for PvP
  `token_reward` INT DEFAULT 0,
  `essence_reward` INT DEFAULT 0,
  `cooldown_seconds` INT DEFAULT 0,
  `is_active` TINYINT DEFAULT 1,
  `season` INT DEFAULT 1
);
```

### Updated: dc_player_upgrade_tokens

Add columns:
```sql
ALTER TABLE `dc_player_upgrade_tokens` ADD COLUMN `weekly_earned` INT UNSIGNED DEFAULT 0;
ALTER TABLE `dc_player_upgrade_tokens` ADD COLUMN `week_reset_at` TIMESTAMP NULL;
```

### New Table: dc_token_transaction_log

```sql
CREATE TABLE `dc_token_transaction_log` (
  `id` BIGINT PRIMARY KEY AUTO_INCREMENT,
  `player_guid` INT UNSIGNED,
  `event_type` VARCHAR(50),
  `token_change` INT SIGNED,           -- positive or negative
  `essence_change` INT SIGNED,
  `reason` VARCHAR(200),               -- "Quest: [name]", "PvP kill", etc.
  `timestamp` TIMESTAMP DEFAULT NOW(),
  INDEX(`player_guid`, `timestamp`)
);
```

---

## Detailed Hook Implementation

### Quest Completion Hook

**Trigger:** Player completes a quest

**Logic:**
1. Check if quest_id has token reward in config
2. Scale reward by quest level (base + %level modifier)
3. Check weekly cap not exceeded
4. Award tokens + log transaction
5. Send player notification

**Pseudo-code:**
```cpp
void OnQuestComplete(Player* player, uint32 quest_id) {
  QuestTemplate const* quest = sObjectMgr->GetQuestTemplate(quest_id);
  if (!quest) return;
  
  // Look up base reward
  uint32 base_reward = GetQuestTokenReward(quest_id);
  if (base_reward == 0) return;
  
  // Scale by quest level
  float level_multiplier = 1.0f + (quest->GetMinLevel() - 60) * 0.05f;
  uint32 final_reward = (uint32)(base_reward * level_multiplier);
  
  // Check weekly cap
  uint32 weekly_earned = GetWeeklyEarned(player->GetGUID());
  if (weekly_earned + final_reward > WEEKLY_CAP) {
    final_reward = WEEKLY_CAP - weekly_earned;
    player->SendSysMessage("Weekly token cap limit reached!");
  }
  
  // Award and log
  AddCurrency(player->GetGUID(), CURRENCY_UPGRADE_TOKEN, final_reward);
  LogTokenTransaction(player->GetGUID(), "Quest", quest->GetTitle(), final_reward);
}
```

### Creature Kill Hook

**Trigger:** Player/group kills creature

**Logic:**
1. Check creature_id in token config
2. Scale by creature level (dungeons = more, world = less)
3. If boss, award bonus essence
4. Award to all party members (if group)
5. Log transaction

### PvP Kill Hook

**Trigger:** Player kills another player

**Logic:**
1. Check if both players in PvP zone/flagged
2. Scale by victim level + opponent difficulty rating
3. Award tokens to killer only
4. Honor integration (award with honor)
5. Log transaction

### Achievement Hook

**Trigger:** Player completes achievement

**Logic:**
1. Check if achievement has essence reward configured
2. Award one-time essence (not repeatable)
3. Track in dc_player_artifact_discoveries (mark as claimed)
4. Send notification

---

## Weekly Reset Logic

**When:** Every Sunday at server reset time (configurable)

**What happens:**
1. Query all players with active tokens
2. Reset `weekly_earned` to 0
3. Update `week_reset_at` timestamp
4. Log reset event to db

**SQL Command:**
```sql
UPDATE dc_player_upgrade_tokens 
SET weekly_earned = 0, week_reset_at = NOW() 
WHERE season = CURRENT_SEASON 
AND TIMESTAMPDIFF(DAY, week_reset_at, NOW()) >= 7;
```

---

## NPC Gossip Integration

### New Gossip Menu: Token Status

**Menu Item:** "[Token Status] - View current balance & weekly cap"

**Actions:**
1. Query current token/essence amount
2. Calculate weekly earned vs cap
3. Show remaining cap for week
4. Display reset timer
5. Show achievement bonus essences (if any)

**Output Example:**
```
Upgrade Tokens:     125 / (weekly cap: 500)
Artifact Essence:   50
Weekly Progress:    125 / 500 (75% cap remaining)
Week Reset:         4 days 12 hours
Unclaimed Essence:  0 (no achievements)
```

### New Gossip Menu: Transaction History

**Menu Item:** "[Earnings History] - Recent token acquisitions"

**Actions:**
1. Query dc_token_transaction_log for player_guid, last 10 rows
2. Group by event type (Quests, PvP, Dungeons, etc.)
3. Show timestamp and amount for each
4. Sortable by date/amount

**Output Example:**
```
Recent Earnings:
[Today]   Quest: Bastion of Twilight       +50 tokens
[Today]   PvP Kill vs Horde Warrior        +15 tokens
[Today]   Dungeon Boss: Vortex Pinnacle    +25 tokens +5 essence
[Y'day]   Battleground Win (AB)            +25 tokens
...
```

---

## Admin Command Suite

### Token Add Command

```
.upgrade token add <player_name_or_guid> <amount> [upgrade_token|artifact_essence]

Example:
  .upgrade token add Thrall 100
  .upgrade token add 5000 50 artifact_essence
```

### Token Info Command

```
.upgrade token info <player_name_or_guid>

Output:
  Player: Thrall (GUID: 5000)
  Season: 1
  Upgrade Tokens: 500 / Weekly Cap: 500
  Artifact Essence: 150
  Weekly Earned: 450 / 500
  Week Reset: 3 days remaining
  Recent Rewards: Quest (50), PvP (15), Raid (50)
```

### Season Reset Command (Admin Only)

```
.upgrade token reset [season_id] [--confirm]

Example:
  .upgrade token reset 2 --confirm   # Reset all players' weekly caps for season 2
```

---

## Testing & Validation Plan

### Local Testing

1. **Unit Tests:**
   - Token calculation formulas (quest scaling, pvp scaling, etc.)
   - Weekly cap enforcement
   - Achievement uniqueness (one-time awards)

2. **Integration Tests:**
   - Quest completion → token award
   - Creature kill → token/essence award
   - PvP kill → token award
   - Achievement → essence award (one-time)
   - Weekly reset logic

3. **Negative Tests:**
   - Over-cap attempts (should be capped)
   - Duplicate achievement rewards (should fail)
   - Invalid player/creature IDs (should be ignored)

### In-Game Testing

1. **Manual Scenario:**
   - Complete a quest → receive tokens
   - Kill a dungeon boss → receive tokens + essence
   - Kill a player → receive tokens
   - Check NPC gossip balance display
   - Run admin commands
   - Reset week and verify cap reset

2. **Verification Checklist:**
   - [ ] Tokens appear in player inventory/balance
   - [ ] Weekly cap enforced correctly
   - [ ] Transaction log records all awards
   - [ ] NPC gossip shows correct balance
   - [ ] Admin commands work as expected
   - [ ] Achievement one-time awards work
   - [ ] Weekly reset logic fires
   - [ ] No database errors in console

---

## Files to Create/Modify

### New Files

1. `src/server/scripts/DC/ItemUpgrades/ItemUpgradeTokenHooks.cpp`
   - PlayerScript, CreatureScript implementations
   - Hook handlers for quest/kill/achievement events
   - ~400-500 lines

2. `src/server/scripts/DC/ItemUpgrades/ItemUpgradeTokenHooks.h`
   - Helper function declarations
   - ~50-100 lines

3. `Custom/Custom feature SQLs/chardb/ItemUpgrades/dc_token_event_config.sql`
   - Event configuration table
   - Default quest/creature/achievement reward mappings
   - ~200-300 lines

4. `Custom/Custom feature SQLs/chardb/ItemUpgrades/dc_token_acquisition_schema.sql`
   - New tables: dc_token_transaction_log, updates to dc_player_upgrade_tokens
   - ~150-200 lines

### Modified Files

1. `src/server/scripts/DC/ItemUpgrades/ItemUpgradeManager.h`
   - Add virtual hook methods

2. `src/server/scripts/DC/ItemUpgrades/ItemUpgradeManager.cpp`
   - Add hook implementations (stub for now, called by script handlers)

3. `src/server/scripts/DC/ItemUpgrades/ItemUpgradeCommand.cpp`
   - Add `.upgrade token` admin command

4. `src/server/scripts/DC/ItemUpgrades/ItemUpgradeNPC_Vendor.cpp`
   - Add token status gossip menu option
   - Add earnings history menu option

5. `src/server/scripts/DC/CMakeLists.txt`
   - Register ItemUpgradeTokenHooks.cpp

---

## Estimated Complexity & Time

- **C++ Implementation:** Medium (3-4 functions + hooks integration)
- **SQL Configuration:** Low (straightforward table creation + inserts)
- **NPC UI:** Low (reuse existing gossip menu patterns)
- **Admin Commands:** Low (ChatCommandBuilder pattern already established)
- **Testing:** Medium (multiple scenarios to validate)

**Total Scope:** 1-2 sessions of focused development

---

## Success Criteria

- ✅ Players earn tokens through quest/kill/pvp activities
- ✅ Weekly cap enforced and tracked per player
- ✅ NPC gossip shows current balance and cap progress
- ✅ Transaction log records all acquisitions
- ✅ Admin commands allow token manipulation for testing
- ✅ Achievement essence awards are one-time only
- ✅ All hooks compile without errors
- ✅ In-game testing confirms proper token flow

---

**Next Step:** Begin implementation of ItemUpgradeTokenHooks.cpp and hook methods.

**Last Updated:** November 4, 2025
