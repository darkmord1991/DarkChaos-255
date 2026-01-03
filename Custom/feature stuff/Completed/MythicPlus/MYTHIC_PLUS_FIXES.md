# Mythic+ System Fixes and Improvements

## Issues Identified

### 1. DC-Hotspot Addon - Token Message Parsing
**Problem:** The addon is receiving `+%u Upgrade Tokens` messages (unformatted server messages) and trying to parse them as hotspot data.

**Fix Applied:** Added filter in `Core.lua` to ignore:
- Messages matching `%%[ud]` (unformatted placeholders)
- Messages matching upgrade token patterns

### 2. Mythic+ Loot System
**Problem:** All creatures in Mythic+ drop loot. Should only drop from final boss.

**Current State:**
- No loot suppression system in place
- Trash mobs drop normal loot
- Mini-bosses drop loot

**Required Changes:**
- Add `OnCreatureGenerateLoot()` hook to suppress all loot except final boss
- Only final boss should award tokens + new keystone
- Implement retail-like loot lockout

### 3. Run Cancellation System
**Problem:** No system for players to cancel a failed run and downgrade keystone.

**Current State:**
- Players can leave dungeon but keystone remains consumed
- No command to officially cancel and downgrade

**Required Changes:**
- Add `.mplus cancel` command
- Implement 5-minute timer after leaving dungeon
- If all players leave and timer expires, downgrade keystone by 1 level
- Keystone at +2 stays at +2 (doesn't go to +1)

### 4. Timer Start Behavior
**Problem:** Timer starts too fast when keystone is activated.

**Current State:**
- Timer begins immediately upon `TryActivateKeystone()`
- No countdown period
- Players may not be ready

**Required Changes:**
- Add 10-second countdown before timer starts
- Display countdown to all players
- Allow players to position themselves

### 5. Player Teleportation
**Problem:** Players are not teleported to dungeon entrance when run starts.

**Current State:**
- Players must manually be at entrance
- Font of Power can be activated from anywhere in dungeon

**Required Changes:**
- Teleport all group members to dungeon entrance when keystone activated
- Use dungeon spawn coordinates from database
- Ensure all players are present before starting

## Implementation Plan

### Phase 1: Loot Suppression (HIGH PRIORITY)
Add to `mythic_plus_core_scripts.cpp`:

```cpp
class MythicPlusLootScript : public AllCreatureScript
{
public:
    MythicPlusLootScript() : AllCreatureScript("MythicPlusLootScript") { }

    void OnCreatureGenerateLoot(Creature* creature) override
    {
        if (!creature)
            return;

        Map* map = creature->GetMap();
        if (!map || !map->IsDungeon())
            return;

        // Only apply in Mythic difficulty
        if (sMythicScaling->ResolveDungeonDifficulty(map) != DUNGEON_DIFFICULTY_EPIC)
            return;

        // Check if keystone is active
        if (sMythicRuns->GetKeystoneLevel(map) == 0)
            return;

        // Check if this is the final boss
        if (!sMythicRuns->IsFinalBoss(map->GetId(), creature->GetEntry()))
        {
            // Suppress all loot from non-final bosses
            creature->loot.clear();
            LOG_INFO("mythic.loot", "Suppressed loot from {} (entry {}) - not final boss",
                     creature->GetName(), creature->GetEntry());
        }
    }
};
```

### Phase 2: Run Cancellation System (HIGH PRIORITY)
Add to `MythicPlusRunManager.h`:

```cpp
// Add to InstanceState struct:
struct InstanceState
{
    // ... existing fields ...
    uint64 abandonedAt = 0;  // Timestamp when last player left
    bool cancellationPending = false;
};

// Add to public methods:
void InitiateCancellation(Map* map);
void ProcessCancellationTimers();
bool CancelRun(Player* player, Map* map);
```

Add to `MythicPlusRunManager.cpp`:

```cpp
void MythicPlusRunManager::InitiateCancellation(Map* map)
{
    if (!map)
        return;

    InstanceState* state = GetState(map);
    if (!state || state->completed || state->failed)
        return;

    // Check if all players have left
    bool allLeft = true;
    for (auto guid : state->participants)
    {
        if (Player* player = ObjectAccessor::FindConnectedPlayer(ObjectGuid::Create<HighGuid::Player>(guid)))
        {
            if (player->GetMapId() == state->mapId && player->GetInstanceId() == state->instanceId)
            {
                allLeft = false;
                break;
            }
        }
    }

    if (allLeft && !state->cancellationPending)
    {
        state->cancellationPending = true;
        state->abandonedAt = GameTime::GetGameTime().count();
        LOG_INFO("mythic.run", "Cancellation initiated for instance {} (map {})", 
                 state->instanceId, state->mapId);
    }
}

void MythicPlusRunManager::ProcessCancellationTimers()
{
    uint64 now = GameTime::GetGameTime().count();
    const uint64 CANCEL_TIMEOUT = 300; // 5 minutes

    std::vector<uint64> toCancel;
    for (auto& [key, state] : _instanceStates)
    {
        if (state.cancellationPending && !state.completed && !state.failed)
        {
            if (now - state.abandonedAt >= CANCEL_TIMEOUT)
            {
                toCancel.push_back(key);
            }
        }
    }

    for (uint64 key : toCancel)
    {
        auto itr = _instanceStates.find(key);
        if (itr != _instanceStates.end())
        {
            InstanceState& state = itr->second;
            HandleFailState(&state, "Run abandoned - all players left", true);
            LOG_INFO("mythic.run", "Auto-cancelled abandoned run for instance {} (map {})",
                     state.instanceId, state.mapId);
        }
    }
}

bool MythicPlusRunManager::CancelRun(Player* player, Map* map)
{
    if (!player || !map)
        return false;

    InstanceState* state = GetState(map);
    if (!state || state->completed)
    {
        SendGenericError(player, "No active Mythic+ run to cancel.");
        return false;
    }

    if (state->ownerGuid != player->GetGUID())
    {
        SendGenericError(player, "Only the keystone owner can cancel the run.");
        return false;
    }

    HandleFailState(state, "Run cancelled by keystone owner", true);
    AnnounceToInstance(map, "|cffff0000Mythic+ run cancelled by group leader. Keystone downgraded.|r");
    return true;
}
```

Add command in `mythic_plus_commands.cpp`:

```cpp
static bool HandleMythicPlusCancelCommand(ChatHandler* handler)
{
    Player* player = handler->GetPlayer();
    if (!player)
        return false;

    Map* map = player->GetMap();
    if (!map || !map->IsDungeon())
    {
        handler->SendSysMessage("You must be inside a dungeon to cancel a Mythic+ run.");
        return false;
    }

    if (sMythicRuns->CancelRun(player, map))
    {
        handler->PSendSysMessage("|cff00ff00Mythic+ run cancelled. Your keystone has been downgraded by 1 level.|r");
        return true;
    }

    return false;
}
```

### Phase 3: Timer Countdown (MEDIUM PRIORITY)
Modify `TryActivateKeystone()` in `MythicPlusRunManager.cpp`:

```cpp
bool MythicPlusRunManager::TryActivateKeystone(Player* player, GameObject* font)
{
    // ... existing validation code ...

    // NEW: Start countdown before activating run
    state->countdownStarted = GameTime::GetGameTime().count();
    state->countdownDuration = 10; // 10 seconds

    AnnounceToInstance(map, "|cffff8000Keystone Activated|r: Countdown starting...");
    
    // Schedule countdown announcements
    for (uint8 i = 10; i > 0; --i)
    {
        map->AddWorldEvent([=]() {
            AnnounceToInstance(map, Acore::StringFormat("|cffff8000Mythic+ starting in {}...|r", i));
        }, i * 1000);
    }

    // Schedule actual run start
    map->AddWorldEvent([=]() {
        StartRun(state, map, player);
    }, 10000);

    return true;
}

void MythicPlusRunManager::StartRun(InstanceState* state, Map* map, Player* activator)
{
    state->startedAt = GameTime::GetGameTime().count();
    
    // Apply scaling and barriers
    ApplyKeystoneScaling(map, state->keystoneLevel);
    ApplyEntryBarrier(map);
    
    AnnounceToInstance(map, "|cff00ff00Mythic+ timer started! Good luck!|r");
}
```

### Phase 4: Entrance Teleportation (MEDIUM PRIORITY)
Add to `TryActivateKeystone()`:

```cpp
// After validation, before countdown
TeleportGroupToEntrance(player, map);

// Add helper method:
void MythicPlusRunManager::TeleportGroupToEntrance(Player* activator, Map* map)
{
    if (!activator || !map)
        return;

    Group* group = activator->GetGroup();
    if (!group)
    {
        // Solo player
        TeleportPlayerToEntrance(activator, map);
        return;
    }

    // Teleport all group members in the instance
    for (GroupReference* itr = group->GetFirstMember(); itr != nullptr; itr = itr->next())
    {
        Player* member = itr->GetSource();
        if (member && member->GetMapId() == map->GetId() && 
            member->GetInstanceId() == map->GetInstanceId())
        {
            TeleportPlayerToEntrance(member, map);
        }
    }
}

void MythicPlusRunManager::TeleportPlayerToEntrance(Player* player, Map* map)
{
    if (!player || !map)
        return;

    // Get entrance coordinates from database or use defaults
    QueryResult result = WorldDatabase.Query(
        "SELECT entrance_x, entrance_y, entrance_z, entrance_o FROM dc_mplus_dungeons WHERE map_id = {}",
        map->GetId()
    );

    if (result)
    {
        Field* fields = result->Fetch();
        float x = fields[0].Get<float>();
        float y = fields[1].Get<float>();
        float z = fields[2].Get<float>();
        float o = fields[3].Get<float>();

        player->TeleportTo(map->GetId(), x, y, z, o);
        ChatHandler(player->GetSession()).PSendSysMessage("|cff00ff00Teleported to dungeon entrance.|r");
    }
    else
    {
        LOG_ERROR("mythic.run", "No entrance coordinates defined for map {}", map->GetId());
    }
}
```

### Database Updates Required

```sql
-- Add entrance coordinates to dungeon profiles
ALTER TABLE `dc_mplus_dungeons` 
ADD COLUMN `entrance_x` FLOAT DEFAULT 0,
ADD COLUMN `entrance_y` FLOAT DEFAULT 0,
ADD COLUMN `entrance_z` FLOAT DEFAULT 0,
ADD COLUMN `entrance_o` FLOAT DEFAULT 0;

-- Example entrance coordinates (need to be filled in per dungeon)
UPDATE `dc_mplus_dungeons` SET 
    entrance_x = -3648.68, entrance_y = -2632.84, entrance_z = 32.13, entrance_o = 5.49
WHERE map_id = 33; -- Shadowfang Keep

-- Add cancellation tracking
ALTER TABLE `dc_mplus_player_keystones`
ADD COLUMN `last_cancelled` INT UNSIGNED DEFAULT 0;
```

## Testing Checklist

- [ ] Verify trash mobs drop no loot in Mythic+
- [ ] Verify mini-bosses drop no loot in Mythic+
- [ ] Verify final boss drops tokens + new keystone
- [ ] Test `.mplus cancel` command
- [ ] Verify keystone downgrades on cancellation
- [ ] Verify +2 keystone stays at +2 (doesn't go to +1)
- [ ] Test 5-minute auto-cancel when all players leave
- [ ] Verify 10-second countdown displays properly
- [ ] Verify all players teleported to entrance on activation
- [ ] Verify timer starts after countdown completes

## Configuration Options

Add to `worldserver.conf`:

```ini
###################################################################################################
# MYTHIC+ BEHAVIOR
#
#    MythicPlus.SuppressTrashLoot
#        Description: Prevent non-final bosses from dropping loot in Mythic+
#        Default:     1 (enabled)

MythicPlus.SuppressTrashLoot = 1

#    MythicPlus.CancellationTimeout
#        Description: Seconds before auto-cancelling abandoned runs
#        Default:     300 (5 minutes)

MythicPlus.CancellationTimeout = 300

#    MythicPlus.CountdownDuration
#        Description: Countdown seconds before run starts
#        Default:     10

MythicPlus.CountdownDuration = 10

#    MythicPlus.TeleportToEntrance
#        Description: Teleport players to entrance when keystone activated
#        Default:     1 (enabled)

MythicPlus.TeleportToEntrance = 1
```

## Priority Implementation Order

1. **Loot suppression** - Most visible issue, affects game balance
2. **Run cancellation** - Quality of life, prevents keystone loss from bugs/disconnects
3. **Countdown timer** - Polish, gives players time to prepare
4. **Entrance teleportation** - Convenience, ensures fair starts

## Notes

- All changes are backwards compatible with existing keystones
- Database schema changes are additive (no data loss)
- Config options allow server operators to customize behavior
- Logging added for debugging and auditing
