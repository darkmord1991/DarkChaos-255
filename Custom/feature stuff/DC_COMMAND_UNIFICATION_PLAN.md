# DC Command Unification Plan

## Overview

This document outlines the effort required to rename all DarkChaos commands to use a unified `.dc` prefix and consolidate command files into the DC scripts directory.

---

## Current State Analysis

### Commands Already in DC Scripts Directory (20 files)

| File | Current Command | Proposed Command | Location |
|------|-----------------|------------------|----------|
| `dc_prestige_system.cpp` | `.prestige` | `.dc prestige` | Prestige/ |
| `dc_prestige_challenges.cpp` | `.prestige challenge` | `.dc prestige challenge` | Prestige/ |
| `dc_prestige_alt_bonus.cpp` | `.prestige altbonus` | `.dc prestige altbonus` | Prestige/ |
| `SeasonalRewardCommands.cpp` | `.season` | `.dc season` | Seasons/ |
| `mythic_plus_commands.cpp` | `.mplus` | `.dc mplus` | MythicPlus/ |
| `keystone_admin_commands.cpp` | `.keystone` | `.dc keystone` | MythicPlus/ |
| `dc_mythic_spectator.cpp` | `.spectate` / `.mspec` | `.dc spectate` | MythicPlus/ |
| `ac_hotspots.cpp` | `.hotspots` / `.hotspot` | `.dc hotspots` | Hotspot/ |
| `ac_aoeloot.cpp` | `.aoeloot` | `.dc aoeloot` | DC/ |
| `dc_aoeloot_extensions.cpp` | `.lootpref` / `.lp` | `.dc loot` | DC/ |
| `dc_phased_duels.cpp` | `.duel` | `.dc duel` | PhasedDuels/ |
| `DungeonQuestMasterFollower.cpp` | `.dcquest` | `.dc quest` | DungeonQuests/ |
| `dc_challenge_modes_customized.cpp` | `.challenge` | `.dc challenge` | ChallengeMode/ |
| `ItemUpgradeGMCommands.cpp` | `.upgrade` | `.dc upgrade` | ItemUpgrades/ |
| `ItemUpgradeProgressionImpl.cpp` | `.upgradeprog` | `.dc upgradeprog` | ItemUpgrades/ |
| `ItemUpgradeAdvancedImpl.cpp` | `.upgradeadv` | `.dc upgradeadv` | ItemUpgrades/ |
| `ItemUpgradeSeasonalImpl.cpp` | `.upgradeseason` | `.dc upgradeseason` | ItemUpgrades/ |
| `ItemUpgradeAddonHandler.cpp` | `.dcupgrade` | `.dc upgrade addon` | ItemUpgrades/ |
| `aio_bridge.cpp` | `.aio` | `.dc aio` | AIO/ |
| `cs_gps_test.cpp` | `.gpstest` | `.dc gpstest` | MapExtension/ |
| `cs_flighthelper_test.cpp` | `.flighthelper` | `.dc flighthelper` | AC/ |
| `hlbg_native_broadcast.cpp` | `.hlbglive` | `.dc hlbglive` | HinterlandBG/ |

### Commands in `/src/server/scripts/Commands/` (Need Moving)

| File | Current Command | Proposed Command | Target Location |
|------|-----------------|------------------|-----------------|
| `cs_dcrxp.cpp` | `.dcrxp` / `.dcxrp` | Merge into `.dc` | DC/Commands/ |
| `cs_dc_addons.cpp` | `.dc` | Already `.dc` (hub) | DC/Commands/ |
| `cs_dc_dungeonquests.cpp` | `.dcquests` | `.dc quests` | DC/Commands/ |
| `cs_hl_bg.cpp` | `.hlbg` | `.dc hlbg` | DC/HinterlandBG/ |

---

## Proposed New Command Structure

```
.dc                              - Main hub (shows help)
├── prestige                     - Prestige system
│   ├── info                     - Show prestige info
│   ├── reset                    - Initiate reset
│   ├── confirm                  - Confirm reset
│   ├── challenge                - Challenge subcommands
│   │   ├── start <name>
│   │   ├── status
│   │   └── list
│   └── altbonus info            - Alt bonus info
├── season                       - Seasonal rewards
│   ├── info / stats / reload / award / reset / setseason / multiplier / chest
├── mplus                        - Mythic+ system
│   ├── info / cancel / keystone / give / vault / affix / scaling / season
├── keystone                     - Keystone admin
│   ├── spawn / info / reward / start
├── spectate                     - M+ spectator
│   ├── list / join / code / player / watch / leave / invite / guild / replays / replay / stream / reload
├── hotspots                     - XP hotspots
│   ├── status / bonus / list / spawn / spawnhere / spawnworld / testmsg / testpayload / testxp / setbonus / addonpackets / dump / clear / reload / tp / forcebuff
├── aoeloot                      - AoE loot base
│   ├── info / messages / top / stats / reload / force
├── loot                         - Loot preferences (was .lootpref / .lp)
│   ├── toggle / enable / disable / messages / msg / quality / skin / skinset / smart / smartset / ignore / unignore / stats / reload
├── duel                         - Phased duels
│   ├── stats / top / reset / reload
├── quest                        - Dungeon quest master (was .dcquest)
│   ├── summon / dismiss
├── quests                       - Dungeon quest management (was .dcquests)
│   ├── help / list / info / give-token / reward / progress / reset / debug / achievement / title
├── challenge                    - Challenge modes
│   └── (shows active challenges)
├── upgrade                      - Item upgrade system
│   ├── status / list / info
│   ├── token add/remove/set/info
│   └── mech cost/stats/ilvl/reset
├── upgradeprog                  - Upgrade progression
│   ├── mastery / weekcap / unlocktier / tiercap / testset
├── upgradeadv                   - Advanced upgrades
│   ├── respec / achievements / guild
├── upgradeseason                - Seasonal upgrades
│   ├── info / leaderboard / history / reset
├── hlbg                         - Hinterland BG
│   ├── status / get / set / reset / history / statsmanual / affix / warmup / results / live / historyui / statsui
│   └── queue join/leave/status
├── aio                          - AIO bridge
│   └── ping
├── gpstest                      - GPS diagnostic
├── flighthelper                 - Flight path helper
│   └── path <x> <y> <z>
├── send <player>                - Send XP addon msg (legacy from .dcrxp)
├── sendforce <player>           - Force send XP msg
├── grant <player> <amt>         - Grant XP
├── grantself <amt>              - Grant XP to self
├── givexp <player|self> <amt>   - Give XP
├── difficulty <mode>            - Set dungeon difficulty
└── reload mythic                - Reload mythic config
```

---

## Implementation Approach Options

### Option A: Single Hub File (Not Recommended)
- Create one massive `cs_dc_hub.cpp` with all command routing
- **Pros:** Single point of registration
- **Cons:** Huge file, hard to maintain, merge conflicts

### Option B: Hub + Delegate Pattern (Recommended)
- Create `DC/Commands/cs_dc_hub.cpp` as central router
- Each subsystem keeps its command handlers
- Hub file imports and registers subtables from other files
- **Pros:** Clean separation, each module maintains its commands
- **Cons:** Requires cross-file subtable exports

### Option C: Nested Auto-Registration
- Each command script registers itself under `.dc` namespace
- Use static initialization to build command tree
- **Pros:** Minimal changes to existing files
- **Cons:** Complex initialization order, harder to debug

---

## Phase-by-Phase Implementation

### Phase 1: Create DC Commands Directory & Hub (2-3 hours)

1. Create directory: `src/server/scripts/DC/Commands/`
2. Create `cs_dc_hub.cpp` - central command router
3. Update `DC/CMakeLists.txt` to include new directory
4. Register hub in script loader

**Hub file structure:**
```cpp
// cs_dc_hub.cpp
class dc_hub_commandscript : public CommandScript
{
public:
    dc_hub_commandscript() : CommandScript("dc_hub_commandscript") { }

    ChatCommandTable GetCommands() const override
    {
        // Import subtables from other files (via extern or static accessors)
        static ChatCommandTable dcCommandTable =
        {
            { "prestige",    GetPrestigeSubTable() },
            { "season",      GetSeasonSubTable() },
            { "mplus",       GetMPlusSubTable() },
            { "spectate",    GetSpectateSubTable() },
            { "hotspots",    GetHotspotsSubTable() },
            { "loot",        GetLootSubTable() },
            { "duel",        GetDuelSubTable() },
            { "upgrade",     GetUpgradeSubTable() },
            { "hlbg",        GetHLBGSubTable() },
            // ... etc
        };

        static ChatCommandTable commandTable =
        {
            { "dc", dcCommandTable }
        };
        return commandTable;
    }
};
```

### Phase 2: Modify Existing Command Files (3-4 hours)

For each command file, change from registering top-level to exporting subtable:

**Before:**
```cpp
ChatCommandTable GetCommands() const override
{
    static ChatCommandTable prestigeSubTable = { ... };
    static ChatCommandTable commandTable =
    {
        { "prestige", prestigeSubTable }
    };
    return commandTable;
}
```

**After:**
```cpp
// Export subtable for hub
ChatCommandTable& GetPrestigeSubTable()
{
    static ChatCommandTable prestigeSubTable = { ... };
    return prestigeSubTable;
}

// No longer register top-level command
// (or keep as legacy alias during transition)
```

**Files to modify:**
1. `dc_prestige_system.cpp`
2. `dc_prestige_challenges.cpp`
3. `dc_prestige_alt_bonus.cpp`
4. `SeasonalRewardCommands.cpp`
5. `mythic_plus_commands.cpp`
6. `keystone_admin_commands.cpp`
7. `dc_mythic_spectator.cpp`
8. `ac_hotspots.cpp`
9. `ac_aoeloot.cpp`
10. `dc_aoeloot_extensions.cpp`
11. `dc_phased_duels.cpp`
12. `DungeonQuestMasterFollower.cpp`
13. `dc_challenge_modes_customized.cpp`
14. `ItemUpgradeGMCommands.cpp`
15. `ItemUpgradeProgressionImpl.cpp`
16. `ItemUpgradeAdvancedImpl.cpp`
17. `ItemUpgradeSeasonalImpl.cpp`
18. `ItemUpgradeAddonHandler.cpp`
19. `aio_bridge.cpp`
20. `cs_gps_test.cpp`
21. `cs_flighthelper_test.cpp`
22. `hlbg_native_broadcast.cpp`

### Phase 3: Move Files from Commands/ to DC/ (1-2 hours)

| Source | Destination |
|--------|-------------|
| `Commands/cs_dcrxp.cpp` | Merge into `DC/Commands/cs_dc_hub.cpp` |
| `Commands/cs_dc_addons.cpp` | Merge into `DC/Commands/cs_dc_hub.cpp` |
| `Commands/cs_dc_dungeonquests.cpp` | `DC/DungeonQuests/` or `DC/Commands/` |
| `Commands/cs_hl_bg.cpp` | `DC/HinterlandBG/` |

**CMake updates needed:**
1. `src/server/scripts/Commands/CMakeLists.txt` - Remove moved files
2. `src/server/scripts/DC/CMakeLists.txt` - Add Commands subdirectory
3. `src/server/scripts/DC/Commands/CMakeLists.txt` - Create new

### Phase 4: Update Script Loader (30 min)

Modify `cs_script_loader.cpp` to remove old AddSC calls and add new ones.

### Phase 5: Legacy Alias Support (1 hour)

Keep old commands working during transition:
```cpp
// In hub or separate alias file
static ChatCommandTable legacyAliases =
{
    { "prestige", GetPrestigeSubTable() },  // .prestige still works
    { "mplus",    GetMPlusSubTable() },     // .mplus still works
    { "hlbg",     GetHLBGSubTable() },      // .hlbg still works
    // etc
};
```

### Phase 6: Documentation & Testing (1 hour)

1. Update `Custom/Commands.md`
2. Update any addon Lua code that uses old commands
3. Test all commands in-game

---

## Effort Summary

| Phase | Description | Estimated Time |
|-------|-------------|----------------|
| 1 | Create hub structure | 2-3 hours |
| 2 | Modify existing command files | 3-4 hours |
| 3 | Move files to DC directory | 1-2 hours |
| 4 | Update script loader | 30 min |
| 5 | Add legacy aliases | 1 hour |
| 6 | Documentation & testing | 1 hour |
| **Total** | | **8-11 hours** |

---

## Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| Breaking player macros using old commands | High | Keep legacy aliases for 2-3 patches |
| Breaking addon code expecting old responses | Medium | Test addon communication thoroughly |
| Build failures from moved files | Low | Careful CMake updates, incremental changes |
| Command conflicts with AzerothCore base | Low | `.dc` prefix ensures uniqueness |
| Initialization order issues | Medium | Use lazy initialization for subtables |

---

## Alternative: Minimal Effort Approach

If full unification is too much work, consider:

1. **Just add `.dc` aliases** without moving files
2. Keep existing commands working as-is
3. Document `.dc` as the "preferred" prefix

**Changes needed:**
- Modify `cs_dc_addons.cpp` to add subtable routing
- Each existing file adds one line to expose subtable
- No file moving required

**Effort:** 2-3 hours total

---

## Decision Points

Before proceeding, decide:

1. **Full unification vs minimal aliases?**
2. **Keep legacy commands forever or deprecate after X patches?**
3. **Move files immediately or leave in place?**
4. **Update addons simultaneously or after server changes?**

---

## Files Reference

### New Files to Create
- `src/server/scripts/DC/Commands/CMakeLists.txt`
- `src/server/scripts/DC/Commands/cs_dc_hub.cpp`
- `src/server/scripts/DC/Commands/dc_command_exports.h` (optional, for subtable declarations)

### Files to Modify
- All 22 command files listed in Phase 2
- `src/server/scripts/DC/CMakeLists.txt`
- `src/server/scripts/Commands/CMakeLists.txt`
- `src/server/scripts/Commands/cs_script_loader.cpp`
- `Custom/Commands.md`

### Files to Move/Merge
- `cs_dcrxp.cpp` → merge
- `cs_dc_addons.cpp` → merge
- `cs_dc_dungeonquests.cpp` → move
- `cs_hl_bg.cpp` → move

---

*Document created: 2025-11-30*
*Status: Planning/Evaluation*
