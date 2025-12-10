# Dark Chaos Addon Protocol Architecture

## Overview

The DC Addon Protocol provides a unified client-server communication layer for all Dark Chaos custom features. It coexists with Rochet2's AIO system but provides a lightweight alternative for simple message passing.

## Protocol Comparison

| Feature | AIO (SAIO/CAIO) | DC Protocol |
|---------|-----------------|-------------|
| Prefix | SAIO (server→client), CAIO (client→server) | DC |
| Serialization | Smallfolk + LZW compression | Simple pipe-delimited |
| Max message size | ~32KB (chunked) | 255 bytes client→server, 2560 server→client |
| Use case | Complex UI, large data | Simple settings, quick requests |
| Chunking | Built-in | Manual (for >255 bytes) |

## Message Format

```
DC|MODULE|OPCODE|DATA1|DATA2|...
```

### Modules

| Module | Code | Description |
|--------|------|-------------|
| CORE | `CORE` | Handshake, version check, feature query |
| AOE Loot | `AOE` | AOE loot settings sync |
| Spectator | `SPEC` | Mythic+ spectator mode |
| Upgrade | `UPG` | Item upgrade system |
| Hinterland | `HLBG` | Hinterland BG (supplements AIO) |
| Duels | `DUEL` | Phased dueling system |
| Mythic+ | `MPLUS` | Mythic+ dungeon system |
| Prestige | `PRES` | Prestige/rebirth system |
| Seasonal | `SEAS` | Seasonal progression |
| Hotspot | `SPOT` | XP bonus zones |
| Events | `EVNT` | Global event feed (invasions, rifts, etc.) |

## Architecture

### Server-Side (C++)

```
src/server/scripts/DC/AddonExtension/
├── DCAddonNamespace.h        # Core namespace, opcodes, Message/Parser classes
├── dc_addon_protocol.cpp     # Main router, hooks, config loading
├── dc_addon_extension_loader.cpp  # Loads all module handlers
├── dc_addon_aoeloot.cpp      # AOE Loot module
├── dc_addon_upgrade.cpp      # Item Upgrade module
├── dc_addon_mythicplus.cpp   # Mythic+ module
├── dc_addon_spectator.cpp    # Spectator module
├── dc_addon_hotspot.cpp      # Hotspot module
├── dc_addon_hlbg.cpp         # Hinterland BG module
└── dc_addon_seasons.cpp      # Seasons module
```

### Client-Side (Lua)

```
Custom/Client addons needed/DC-AddonProtocol/
├── DC-AddonProtocol.toc
└── DCAddonProtocol.lua       # Core protocol library
```

## Usage

### Server-Side: Sending Messages

```cpp
#include "DCAddonNamespace.h"

using namespace DCAddon;

// Simple message
Message(Module::AOE_LOOT, Opcode::AOE::SMSG_SETTINGS_SYNC)
    .Add(enabled)
    .Add(minQuality)
    .Add(autoSkin)
    .Send(player);

// Or use the convenience method
Message msg(Module::SEASONAL, Opcode::Season::SMSG_PROGRESS);
msg.Add(seasonId);
msg.Add(level);
msg.Send(player);
```

### Server-Side: Registering Handlers

```cpp
void RegisterHandlers()
{
    DC_REGISTER_HANDLER(Module::AOE_LOOT, Opcode::AOE::CMSG_GET_SETTINGS, 
        [](Player* player, const ParsedMessage& msg) {
            // Handle message
            SendSettingsSync(player);
        });
}
```

### Client-Side: Sending Messages

```lua
-- Using the protocol library
local DC = DCAddonProtocol

-- Method 1: Direct send
DC:Send("AOE", 0x01, true)  -- Toggle AOE enabled

-- Method 2: Module helpers
DC.AOE.Toggle(true)
DC.AOE.SetQuality(2)  -- Uncommon minimum
DC.AOE.GetStats()
```

### Client-Side: Registering Handlers

```lua
local DC = DCAddonProtocol

-- Register for incoming settings sync
DC:RegisterHandler("AOE", 0x11, function(enabled, quality, autoSkin, ...)
    -- Update local settings
    MyAddon.settings.enabled = enabled
    MyAddon.settings.minQuality = quality
    MyAddon.settings.autoSkin = autoSkin
    MyAddon:UpdateUI()
end)
```

## Configuration

Add to `worldserver.conf`:

```ini
###################################################################################################
# DC ADDON PROTOCOL
###################################################################################################

# Enable/disable modules
DC.AddonProtocol.Core.Enable = 1
DC.AddonProtocol.AOELoot.Enable = 1
DC.AddonProtocol.Spectator.Enable = 1
DC.AddonProtocol.Upgrade.Enable = 1
DC.AddonProtocol.Duels.Enable = 1
DC.AddonProtocol.MythicPlus.Enable = 1
DC.AddonProtocol.Prestige.Enable = 1
DC.AddonProtocol.Seasonal.Enable = 1
DC.AddonProtocol.HinterlandBG.Enable = 1
DC.AddonProtocol.Events.Enable = 1

# Debug & rate limiting
DC.AddonProtocol.Debug.Enable = 0
DC.AddonProtocol.RateLimit.Messages = 30
DC.AddonProtocol.RateLimit.Action = 0  # 0=drop, 1=kick, 2=mute
DC.AddonProtocol.ChunkTimeout = 5000

### Events module toggle

`DC.AddonProtocol.Events.Enable` gates the `EVNT` module that streams dynamic world events (for example Giant Isles invasions) to DC addons. When enabled, scripts such as `dc_giant_isles_invasion.cpp` publish JSON payloads (`SMSG_EVENT_UPDATE`, `SMSG_EVENT_SPAWN`, `SMSG_EVENT_REMOVE`) and DC-InfoBar consumes them via its InfoBar feed. Disable this if you run without the DC-InfoBar client or do not want live world-event broadcasts.
```

## Coexistence with AIO

The DC Protocol and AIO systems are completely independent:

1. **Different prefixes**: AIO uses `SAIO`/`CAIO`, DC uses `DC`
2. **Different purposes**: AIO handles complex UI and large data; DC handles simple settings
3. **No conflicts**: Both can be used simultaneously

### When to use each:

| Use AIO when... | Use DC Protocol when... |
|-----------------|-------------------------|
| Complex UI needed | Simple settings toggle |
| Large data transfer | Small status updates |
| Two-way UI building | Request/response patterns |
| Addon framework features | Lightweight message passing |

## Opcode Ranges

For each module:
- `0x01 - 0x0F`: Client → Server messages (CMSG)
- `0x10 - 0x1F`: Server → Client messages (SMSG)
- `0x20+`: Reserved for future use

## Adding a New Module

1. **Add module constant** in `DCAddonNamespace.h`:
   ```cpp
   namespace Module {
       constexpr const char* MY_MODULE = "MYMOD";
   }
   ```

2. **Add opcodes** in `DCAddonNamespace.h`:
   ```cpp
   namespace Opcode::MyModule {
       constexpr uint8 CMSG_DO_THING = 0x01;
       constexpr uint8 SMSG_THING_DONE = 0x10;
   }
   ```

3. **Create handler file** `dc_addon_mymodule.cpp`:
   ```cpp
   namespace DCAddon::MyModule {
       void RegisterHandlers() {
           DC_REGISTER_HANDLER(Module::MY_MODULE, Opcode::MyModule::CMSG_DO_THING, HandleDoThing);
       }
   }
   void AddSC_dc_addon_mymodule() {
       DCAddon::MyModule::RegisterHandlers();
   }
   ```

4. **Update loader** in `dc_addon_extension_loader.cpp`:
   ```cpp
   void AddSC_dc_addon_mymodule();
   // ...
   AddSC_dc_addon_mymodule();
   ```

5. **Add client-side handler** in your addon:
   ```lua
   DC:RegisterHandler("MYMOD", 0x10, function(data)
       -- Handle response
   end)
   ```

## Database Tables

The following tables may be used by various modules:

```sql
-- AOE Loot settings
CREATE TABLE `dc_aoe_loot_settings` (
    `character_guid` INT UNSIGNED PRIMARY KEY,
    `enabled` TINYINT(1) DEFAULT 1,
    `show_messages` TINYINT(1) DEFAULT 1,
    `min_quality` TINYINT UNSIGNED DEFAULT 0,
    `auto_skin` TINYINT(1) DEFAULT 0,
    `smart_loot` TINYINT(1) DEFAULT 1,
    `loot_range` FLOAT DEFAULT 30.0
);

-- Seasonal progress
CREATE TABLE `dc_season_progress` (
    `character_guid` INT UNSIGNED,
    `season_id` INT UNSIGNED,
    `level` INT UNSIGNED DEFAULT 1,
    `current_xp` INT UNSIGNED DEFAULT 0,
    `total_points` INT UNSIGNED DEFAULT 0,
    PRIMARY KEY (`character_guid`, `season_id`)
);
```

## Troubleshooting

### Messages not being received
1. Check module is enabled in config
2. Verify prefix is exactly "DC"
3. Check for rate limiting

### Debug mode
Enable debug logging:
```ini
DC.AddonProtocol.Debug.Enable = 1
```

Client-side:
```lua
/dc debug
```

### Common issues
- **Rate limit exceeded**: Lower message frequency or increase `RateLimit.Messages`
- **Message too long**: Use chunking or switch to AIO for large data
- **Handler not firing**: Ensure module and opcode match exactly
