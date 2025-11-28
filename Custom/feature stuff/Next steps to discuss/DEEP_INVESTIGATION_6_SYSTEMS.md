# 🔬 Deep Investigation Report: 6 Priority Systems
## DarkChaos 3.3.5a AzerothCore Implementation Analysis

**Generated:** November 27, 2025  
**Focus:** Minimizing core modifications, DC scripts priority, Client/Addon requirements

---

## 📊 Executive Summary

| System | Existing Module | Core Changes | Addon Required | DC Script Effort |
|--------|----------------|--------------|----------------|------------------|
| Performance Optimization | ❌ No | ⚠️ Minor | ❌ No | 2-3 weeks |
| Mythic+ Spectator | ✅ mod-npc-spectator | ⚠️ Minor | ✅ Yes | 2-3 weeks |
| AOE Loot | ✅ mod-aoe-loot | ❌ None | ⚠️ Optional | 1 week |
| Phased Dueling | ✅ mod-phased-duels | ❌ None | ❌ No | < 1 week |
| Addon Protocol | ❌ No (AIO exists) | ⚠️ Minor | ✅ Yes | 3-4 weeks |
| Dynamic World Events | ❌ No (OutdoorPvP base) | ⚠️ Minor | ✅ Optional | 4-6 weeks |

---

# 🎯 System 1: Performance Optimization

## Available Implementations
**No dedicated module exists** - Must be custom DC implementation

## Private Server Examples to Check
| Server | Known For | Features |
|--------|-----------|----------|
| **Warmane (Icecrown/Lordaeron)** | 12k+ players | Heavy caching, clustered architecture |
| **ChromieCraft** | AC-based, progression | Uses mod-progression-system |
| **Tauri WoW** | MoP high-pop | Multi-threaded pathfinding |

## Implementation Approach (DC Scripts Only)

### Server-Side Optimizations (Eluna/C++ Scripts)
```
✅ No core changes needed for:
- Creature script caching
- Query result caching in Lua tables
- Lazy loading of non-essential data
- Scheduled task batching

⚠️ Minor core touches for:
- Database connection pooling tweaks (conf file)
- Map update interval adjustments (conf file)
- Visibility distance tuning (conf file)
```

### Key Config Optimizations (worldserver.conf)
```ini
# Already available - no code changes
Updates.EnableDatabases = 0
MapUpdate.Threads = 4
Visibility.Distance.Creature = 100
Rate.Corpse.Decay.Looted = 0.01
```

### DC Script Approach
1. **Cache Layer (Lua)** - Store frequently accessed data in memory
2. **Batch Processing** - Group DB writes (item upgrades, ratings)
3. **Async Queries** - Use Eluna's async DB methods

## Client/Addon Side
**No client changes required** ✅

## Estimated Effort: 2-3 weeks
- Week 1: Profiling, identify bottlenecks
- Week 2: Implement caching layer
- Week 3: Tune and test

---

# 👁️ System 2: Mythic+ Spectator Mode

## Available Implementations

### ✅ AzerothCore Module: mod-npc-spectator
**Repository:** https://github.com/Gozzim/mod-npc-spectator
**Stars:** 10 | **Forks:** 21

**Original Source:** Flameshot/TrinityCore Arena-Spectator branch
**Adapted by:** Gozzim for AzerothCore

### How It Works
```cpp
// ArenaSpectator.h - Already in your codebase!
#define SPECTATOR_ADDON_VERSION 27
#define SPECTATOR_ADDON_PREFIX "ASSUN\x09"

// Commands already exist:
// .spect spectate <player> - Join as spectator
// .spect watch <player>   - Switch view
// .spect leave           - Exit spectator mode
```

### Your Existing Code (src/server/game/ArenaSpectator/)
```
ArenaSpectator.cpp - Full implementation present!
ArenaSpectator.h   - SendCommand templates for addon
```

## Adaptation for Mythic+ (DC Scripts)

### Server-Side (Eluna + existing ArenaSpectator)
```lua
-- DC_MythicSpectator.lua
function DC.MythicSpectator:JoinAsSpectator(player, instanceId)
    -- Check if M+ run is active
    local run = MythicPlusRunManager:GetRunByInstance(instanceId)
    if not run then return false end
    
    -- Use existing spectator teleport logic
    player:SetPendingSpectatorForBG(instanceId)
    player:TeleportTo(run.mapId, run.entranceX, run.entranceY, run.entranceZ)
end
```

### Key Changes Needed
| Component | Change Type | Scope |
|-----------|-------------|-------|
| ArenaSpectator | ⚠️ Extend for dungeons | C++ modification |
| MythicPlusRunManager | ✅ Add spectator hooks | DC Lua script |
| Spectator NPC | ✅ Clone mod-npc-spectator | Module + SQL |

## Client/Addon Requirements

### Required: Spectator Addon (modify existing ASSUN)
```lua
-- Client addon receives via CHAT_MSG_ADDON
-- Prefix: "ASSUN\x09" (already defined)

-- Data format from ArenaSpectator:
-- "0x{GUID};NME={PlayerName};"
-- "0x{GUID};TRG={TargetGUID};"
-- "0x{GUID};AUR={aura data};"
-- "0x{GUID};SPE={spell cast};"
```

### Addon Modifications for Mythic+
1. Display M+ timer (server sends via AIO)
2. Show death counter
3. Keystone level indicator
4. Affix display

## YouTube References to Check
- Search: "WoW 3.3.5 arena spectator addon"
- Search: "Private server spectator mode setup"
- Warmane has spectator for arenas - check their forums

## Private Servers with Spectator
| Server | Spectator Type |
|--------|---------------|
| **Warmane** | Arena only |
| **Endless WoW** | Arena + BG |
| **Tournament servers** | Full spectator |

## Estimated Effort: 2-3 weeks
- Week 1: Extend ArenaSpectator for dungeon maps
- Week 2: Build Mythic+ spectator UI addon
- Week 3: NPC integration, testing

---

# 💰 System 3: AOE Loot System

## ✅ Ready-to-Use Module: mod-aoe-loot
**Repository:** https://github.com/azerothcore/mod-aoe-loot
**Stars:** 43 | **Forks:** 38 | **Contributors:** 12

## How It Works (Source Code Analysis)
```cpp
// From aoe_loot.cpp - Intercepts CMSG_LOOT packet

// Get configured loot range
float range = sConfigMgr->GetOption<float>("AOELoot.Range", 30.0f);

// Get nearby corpses
std::list<Creature*> nearbyCorpses;
player->GetDeadCreatureListInGrid(nearbyCorpses, range);

// Merge loot from all corpses into main target
for (Creature* creature : nearbyCorpses) {
    Loot* loot = &creature->loot;
    // Transfer items + gold to main loot window
    mainLoot->gold += loot->gold;
    mainLoot->items.push_back(loot->items);
    creature->AllLootRemovedFromCorpse();
}
```

## Configuration Options
```ini
# AOELoot.conf
AOELoot.Enable = 1
AOELoot.Range = 30.0      # Yards
AOELoot.Group = 1          # Work in groups
AOELoot.Message = 1        # Announce on login
```

## Core Changes: ❌ NONE Required
The module hooks into packet handling - fully modular!

## Important Configuration
```ini
# worldserver.conf - REQUIRED CHANGE
Rate.Corpse.Decay.Looted = 0.01  # Lower = corpses stay longer
```

## Client/Addon Side

### No Addon Required ✅
The loot window shows merged loot automatically.

### Optional Enhancement (DC-ItemUpgrade addon)
```lua
-- Add visual indicator for multi-loot
function DC.LootFrame:ShowAOEIndicator(corpseCount)
    if corpseCount > 1 then
        -- Show "Looting X bodies" text
    end
end
```

## Installation Steps
```bash
# 1. Clone module to modules folder
cd modules
git clone https://github.com/azerothcore/mod-aoe-loot

# 2. Rebuild with CMake
cd build && cmake .. && make

# 3. Copy config file
cp modules/mod-aoe-loot/conf/aoe_loot.conf.dist env/dist/etc/

# 4. Adjust corpse decay rate
# Edit worldserver.conf: Rate.Corpse.Decay.Looted = 0.01
```

## Estimated Effort: < 1 week
- Day 1-2: Install module, configure
- Day 3-4: Test with groups, raids
- Day 5: Optional addon enhancements

---

# ⚔️ System 4: Phased Dueling Arenas

## ✅ Ready-to-Use Module: mod-phased-duels
**Repository:** https://github.com/azerothcore/mod-phased-duels
**Stars:** 6 | **Forks:** 11
**Original Author:** Rochet2

## How It Works (Source Code Analysis)
```cpp
// From mod_phased_duels.cpp

void PhasedDueling::OnPlayerDuelStart(Player* first, Player* second) {
    // Find unused phase (bit scanning)
    for (uint32 phase = 2; phase <= UINT_MAX / 2; phase *= 2) {
        if (!(usedPhases & phase)) {
            // Phase both players and the duel flag
            firstplayer->SetPhaseMask(phase, false);
            secondplayer->SetPhaseMask(phase, false);
            go->SetPhaseMask(phase, true);  // Duel arbiter GO
            return;
        }
    }
}

void PhasedDueling::OnPlayerDuelEnd(Player* first, Player* second) {
    // Restore normal phase
    firstplayer->SetPhaseMask(getNormalPhase(firstplayer), false);
    secondplayer->SetPhaseMask(getNormalPhase(secondplayer), false);
    
    // Optional features:
    firstplayer->SetHealth(firstplayer->GetMaxHealth());  // Full HP
    firstplayer->RemoveAllSpellCooldown();                // Reset CDs
}
```

## Configuration Options
```ini
# mod_phased_duels.conf
PhasedDuels.Enable = 1
PhasedDuelsAnnounce.Enable = 1
SetMaxHP.Enable = 1              # Restore HP after duel
ResetCoolDowns.Enable = 1        # Reset cooldowns
RestorePower.Enable = 1          # Restore mana/energy
ReviveOrRestorPetHealth.Enable = 1
```

## Core Changes: ❌ NONE Required
Uses PlayerScript hooks - fully modular!

## Client/Addon Side

### No Addon Required ✅
Phasing is handled server-side, client sees it automatically.

### Optional Enhancement Ideas
```lua
-- DC_DuelArena.lua (Eluna)
-- Create dedicated duel zones with teleport
function DC.DuelArena:TeleportToDuelZone(player1, player2)
    -- Custom arena with obstacles, pillars
    player1:Teleport(mapId, x, y, z)
    player2:Teleport(mapId, x, y, z)
end
```

## Extension: Custom Duel Arenas

### Current Limitation
Phasing works anywhere - but cluttered areas are messy.

### DC Enhancement (Eluna Script)
```lua
-- Designated duel zones with custom features
local DuelArenas = {
    { name = "Gurubashi Arena", mapId = 0, x = -13229, y = 226, z = 33 },
    { name = "Dire Maul Arena", mapId = 1, x = -3739, y = 1095, z = 132 },
    { name = "Custom Arena 1", mapId = 0, x = ..., y = ..., z = ... }
}
```

## Installation Steps
```bash
# 1. Clone module
cd modules
git clone https://github.com/azerothcore/mod-phased-duels

# 2. Rebuild
cmake .. && make

# 3. Enable in config
```

## Estimated Effort: < 1 week
- Day 1: Install and test module
- Day 2-3: Configure options
- Day 4-5: Optional: Add custom arena zones

---

# 📡 System 5: Addon Protocol Enhancement

## Current System: AIO.lua
Your codebase already uses AIO for server-client communication.

## 3.3.5a Limitations (from WoW API research)
```
SendAddonMessage():
- Prefix: max 16 characters
- Message: max 255 characters  ← MAIN LIMITATION
- Server can send 2560 chars per message
- Client is THROTTLED (ChatThrottleLib needed)
```

## Available Libraries (from Wowpedia)

### Compression/Encoding
| Library | Purpose | Recommended |
|---------|---------|-------------|
| **LibDeflate** | Compression | ✅ Yes |
| **LibSerialize** | Data serialization | ✅ Yes |
| **LibCompress** | Alternative compression | ⚠️ Older |
| **ChatThrottleLib** | Throttle management | ✅ Essential |
| **AceComm** | Communication wrapper | ✅ Yes |

### Example Implementation Pattern
```lua
-- Client-side (addon)
local LibSerialize = LibStub("LibSerialize")
local LibDeflate = LibStub("LibDeflate")

function DC:SendData(data)
    local serialized = LibSerialize:Serialize(data)
    local compressed = LibDeflate:CompressDeflate(serialized)
    local encoded = LibDeflate:EncodeForWoWAddonChannel(compressed)
    self:SendCommMessage("DCComm", encoded, "WHISPER", UnitName("player"))
end

function DC:ReceiveData(payload)
    local decoded = LibDeflate:DecodeForWoWAddonChannel(payload)
    local decompressed = LibDeflate:DecompressDeflate(decoded)
    local success, data = LibSerialize:Deserialize(decompressed)
    return data
end
```

## Current AIO.lua Analysis
```lua
-- Your existing AIO handles message splitting
-- From AIO.lua - already splits messages > 255 chars
AIO_ShortMsg = "..." -- Short message identifier
-- Server can send up to 2560 chars, splits to 255 chunks
```

## Enhancement Strategy (DC Scripts)

### Option A: Enhance AIO (Recommended)
```lua
-- Add compression layer on top of existing AIO
function AIO.SendCompressed(player, data)
    local serialized = DC.Serialize(data)
    local compressed = DC.Compress(serialized)  -- Lua compression lib
    AIO.Handle(player, "DCData", compressed)
end
```

### Option B: Replace with LibDeflate
```lua
-- Pure Lua compression for 3.3.5a
-- LibDeflate Lua port exists: https://github.com/SafeteeWoW/LibDeflate
```

## Core Changes: ⚠️ Minor
- May need to adjust server-side message handler for compressed data
- ChatHandler modifications for larger payloads

## Client/Addon Requirements: ✅ REQUIRED

### Must Include
1. **LibDeflate** - For compression
2. **LibSerialize** - For data serialization
3. **ChatThrottleLib** - Prevent disconnects from spam

### Addon Structure
```
DC-Protocol/
├── libs/
│   ├── LibDeflate/
│   ├── LibSerialize/
│   └── ChatThrottleLib/
├── DC_Protocol.lua
└── DC_Protocol.toc
```

## Estimated Effort: 3-4 weeks
- Week 1: Integrate LibDeflate + LibSerialize
- Week 2: Update AIO to use compression
- Week 3: Test all existing DC systems
- Week 4: Optimize, handle edge cases

---

# 🌍 System 6: Dynamic World Events

## Available Base Systems in AzerothCore

### 1. GameEventMgr (Scheduled Events)
```cpp
// src/server/game/Events/GameEventMgr.h
class GameEventMgr {
    bool StartEvent(uint16 eventId, bool overwrite);
    void StopEvent(uint16 eventId, bool overwrite);
    void GameEventSpawn(int16 eventId);  // Spawn NPCs/GOs
};
```

### 2. OutdoorPvP (Zone Control)
```cpp
// src/server/game/OutdoorPvP/OutdoorPvP.h
class OutdoorPvP : public ZoneScript {
    virtual void HandlePlayerEnterZone(Player* player, uint32 zone);
    virtual void HandlePlayerLeaveZone(Player* player, uint32 zone);
    virtual bool Update(uint32 diff);
    void TeamApplyBuff(TeamId teamId, uint32 spellId);
};
```

### 3. Existing OutdoorPvP Zones (Reference)
| Zone | File | Features |
|------|------|----------|
| Eastern Plaguelands | OutdoorPvPEP.cpp | Tower control, buffs |
| Halaa (Nagrand) | OutdoorPvPNA.cpp | Capture points, vendors |
| Hellfire Peninsula | OutdoorPvPHP.cpp | Stadium towers |
| Zangarmarsh | OutdoorPvPZM.cpp | Twin Spire |
| Silithus | OutdoorPvPSI.cpp | Silithyst collection |
| Grizzly Hills | OutdoorPvPGH.cpp | Venture Bay |

## No Dedicated Module Exists ❌
Must build custom DC system

## Private Server Examples to Check
| Server | Event Type | Implementation |
|--------|-----------|----------------|
| **Warmane** | World bosses on schedule | DB-driven spawns |
| **Ascension WoW** | Custom invasions | Scripted events |
| **Project Epoch** | Progressive content | GameEventMgr |

## Implementation Strategy (DC Scripts)

### Approach: Eluna + GameEventMgr + OutdoorPvP hooks

```lua
-- DC_WorldEvents.lua

DC.WorldEvents = {
    -- Define custom events
    events = {
        {
            id = 100,
            name = "Scourge Invasion",
            zones = {139, 28, 1519},  -- EPL, Duskwood, Stormwind
            duration = 3600,          -- 1 hour
            interval = 14400,         -- Every 4 hours
            bosses = {123456, 123457},
            rewards = {item = 50000, gold = 100000}
        }
    }
}

function DC.WorldEvents:StartEvent(eventId)
    local event = self.events[eventId]
    
    -- Spawn bosses
    for _, bossEntry in ipairs(event.bosses) do
        local zone = event.zones[math.random(#event.zones)]
        -- Use GameEventMgr or direct spawn
        PerformIngameSpawn(1, bossEntry, mapId, 0, x, y, z, 0, false, event.duration)
    end
    
    -- Notify players
    SendWorldMessage("EVENT: " .. event.name .. " has begun!")
    
    -- Schedule end
    CreateLuaEvent(function()
        self:EndEvent(eventId)
    end, event.duration * 1000, 1)
end
```

### World Boss Spawn System
```lua
-- DC_WorldBoss.lua
DC.WorldBoss = {
    bosses = {
        { entry = 50001, name = "Azuregos", map = 1, x = 2568, y = -5266, z = 85 },
        { entry = 50002, name = "Kazzak", map = 0, x = -10706, y = -2395, z = 51 }
    },
    spawnInterval = 4 * 3600,  -- 4 hours
    activeIndex = 0
}

function DC.WorldBoss:RotateSpawn()
    self.activeIndex = (self.activeIndex % #self.bosses) + 1
    local boss = self.bosses[self.activeIndex]
    
    -- Spawn with announcement
    local creature = PerformIngameSpawn(1, boss.entry, boss.map, 0, boss.x, boss.y, boss.z, 0)
    SendWorldMessage(boss.name .. " has awakened in " .. GetAreaName(boss.map))
end

-- Register scheduled spawner
RegisterServerHook(30, function()  -- SCHEDULED_EVENT
    DC.WorldBoss:RotateSpawn()
end)
```

## Core Changes: ⚠️ Minor
- May need custom OutdoorPvP zone registration
- WorldState updates for UI indicators

## Client/Addon Requirements: ⚠️ Optional

### Without Addon (Basic)
- Server announcements only
- Players rely on chat/world messages

### With Addon (Enhanced)
```lua
-- DC_WorldEvents_Addon.lua
local frame = CreateFrame("Frame", "DCWorldEventsFrame", UIParent)

-- Event tracker UI
function DC.WorldEvents:UpdateUI(eventData)
    -- Show active event
    -- Display timer
    -- Show boss health (if spectating)
end

-- World map markers
function DC.WorldEvents:AddMapMarker(mapId, x, y, eventName)
    -- Custom map pins for events
end
```

### AIO Integration for Event Data
```lua
-- Server sends event updates via AIO
AIO.Handle(player, "WorldEvent", {
    eventId = 100,
    status = "active",
    timeRemaining = 1800,
    bossHP = 75,
    participantCount = 45
})
```

## Estimated Effort: 4-6 weeks
- Week 1-2: Event scheduling framework
- Week 3: World boss rotation system  
- Week 4: Zone control mechanics
- Week 5: Client addon UI
- Week 6: Testing, balancing

---

# 📋 Implementation Priority Order

## Phase 1: Quick Wins (Weeks 1-2)
1. **mod-aoe-loot** - Install and configure (2 days)
2. **mod-phased-duels** - Install and configure (2 days)

## Phase 2: Spectator System (Weeks 3-5)
3. **Mythic+ Spectator** - Extend existing ArenaSpectator (3 weeks)

## Phase 3: Protocol & Events (Weeks 6-12)
4. **Addon Protocol Enhancement** - Add compression (3-4 weeks)
5. **Dynamic World Events** - Build framework (4-6 weeks)

## Phase 4: Optimization (Ongoing)
6. **Performance Optimization** - Profile and tune (2-3 weeks, ongoing)

---

# 🔗 Resources & Links

## Official Modules
- mod-aoe-loot: https://github.com/azerothcore/mod-aoe-loot
- mod-phased-duels: https://github.com/azerothcore/mod-phased-duels
- mod-npc-spectator: https://github.com/Gozzim/mod-npc-spectator

## Libraries for Protocol
- LibDeflate: https://github.com/SafeteeWoW/LibDeflate
- LibSerialize: https://github.com/rossnichols/LibSerialize
- ChatThrottleLib: https://www.wowace.com/projects/chatthrottlelib

## API Documentation
- SendAddonMessage: https://wowpedia.fandom.com/wiki/API_C_ChatInfo.SendAddonMessage

## Private Servers to Research
- Warmane (Icecrown): https://www.warmane.com
- ChromieCraft: https://www.chromiecraft.com
- AzerothCore Discord: https://discord.gg/azerothcore

## Your Existing Code
- ArenaSpectator: `src/server/game/ArenaSpectator/`
- OutdoorPvP: `src/server/scripts/OutdoorPvP/`
- GameEventMgr: `src/server/game/Events/GameEventMgr.cpp`
- AIO.lua: Check your Eluna scripts folder

---

*This analysis focuses on maximizing DC script usage while minimizing AzerothCore core modifications.*
