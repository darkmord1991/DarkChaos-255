# DC-QoS - Quality of Service Addon Evaluation

## Document Purpose
Comprehensive evaluation of a new unified **DC-QoS** addon for Dark Chaos server, covering:
- Quality of Life features inspired by top WoW addons
- Server-delivered addon features via DCAddonProtocol
- Extension opportunities for existing DC addons
- Priority implementation roadmap

---

## Executive Summary

**DC-QoS** would serve as a unified Quality of Life addon that consolidates player convenience features into a single, modular addon. Rather than installing 10+ separate addons, players get an integrated experience that leverages DCAddonProtocol for server-enhanced functionality.

### Key Benefits
- **Single addon** for all QoL features (reduces addon clutter)
- **Server-aware** features via DCAddonProtocol integration
- **Unified settings panel** using DC-Welcome's plugin architecture
- **Modular design** - enable/disable individual features
- **Dark Chaos branded** - consistent with other DC addons

---

## Part 1: Most Popular WoW Addon Features Analysis

### Top 20 Most Downloaded Addons (All-Time)

| Rank | Addon | Downloads | Category | Adaptable for DC-QoS? |
|------|-------|-----------|----------|----------------------|
| 1 | DBM (Deadly Boss Mods) | 579M | Boss Encounters | ⚠️ Partial (custom dungeons) |
| 2 | Raider.IO | 407M | M+ Scores | ✅ Already have DC-Leaderboards |
| 3 | Details! | 306M | Damage Meter | ❌ External (Recount works) |
| 4 | WeakAuras | 237M | Buff/Debuff Display | ⚠️ Consider simplified version |
| 5 | BigWigs | 175M | Boss Encounters | ⚠️ Partial (custom dungeons) |
| 6 | Auctionator | 168M | Auction House | ⚠️ Low priority |
| 7 | Questie | 164M | Quest Helper | ⚠️ Custom quests support |
| 8 | Bagnon | 149M | Bag Management | ✅ Excellent candidate |
| 9 | Pawn | 119M | Item Comparison | ✅ Integrate with DC-ItemUpgrade |
| 10 | LittleWigs | 112M | Dungeon Bosses | ⚠️ Partial (Mythic+ dungeons) |
| 11 | RareScanner | 108M | Rare Alerts | ✅ Excellent for hotspots |
| 12 | GTFO | 92M | Bad Stuff Warning | ✅ Simple to implement |
| 13 | MDT | 89M | Dungeon Planning | ⚠️ Complex but valuable |
| 14 | Plater | 83M | Nameplates | ⚠️ Low priority (NotPlater exists) |
| 15 | TomTom | 67M | Navigation | ✅ Waypoint system |
| 16 | OmniCC | 64M | Cooldown Text | ✅ **HIGH PRIORITY** |
| 17 | HandyNotes | 57M | Map Notes | ✅ With DC-Hotspot |
| 18 | Leatrix Plus | 51M | QoL Bundle | ✅ **PRIMARY INSPIRATION** |
| 19 | Syndicator | 17M | Item Search | ✅ Account-wide item tracking |
| 20 | Leatrix Maps | 24M | Map Enhancement | ✅ Coords, zoom, etc |

### Feature Extraction from Top Addons

#### From Leatrix Plus (51M downloads) - QoL Gold Standard
```
✅ AUTOMATE Features:
├── Auto accept quests
├── Auto turn-in quests
├── Auto sell junk (gray items)
├── Auto repair gear
├── Auto accept summons
├── Auto accept resurrections
├── Auto decline duels
├── Auto decline guild invites
├── Fast loot (no animation delay)
└── Skip gossip (one-click NPCs)

✅ ENHANCE Features:
├── Faster camera zoom (farther distance)
├── Faster auto-loot (instant)
├── Max camera distance
├── Character zoom improvements
├── Minimap enhancements
├── Tooltip improvements
└── Quest text speed (instant)

✅ INTERFACE Features:
├── Hide gryphons (action bars)
├── Enhance dressing room
├── Class-colored health bars
├── Wider quest log
├── Show item levels in tooltips
└── Show vendor prices in tooltips
```

#### From OmniCC (64M downloads) - Cooldown Counts
```
✅ Cooldown Text Overlay:
├── Action bar cooldowns
├── Inventory item cooldowns
├── Buff/debuff duration timers
├── Customizable font/size/color
├── Color changes as timer expires
└── Supports all frames (even addons)
```

#### From Bagnon (149M downloads) - Bag Management
```
✅ Unified Bags:
├── All bags in one frame
├── Search/filter functionality
├── Item quality highlighting
├── Bank view anywhere (cached)
├── Character item search
└── Guild bank integration
```

#### From GTFO (92M downloads) - Awareness
```
✅ Environmental Awareness:
├── Audio alert when standing in bad
├── Different sounds for different severity
├── Visual screen flash option
└── Works in custom content
```

#### From TomTom (67M downloads) - Navigation
```
✅ Waypoint System:
├── Arrow pointing to destination
├── Distance display
├── ETA calculation
├── Coordinate input
├── Click-to-set waypoint
└── Integration with quest objectives
```

#### From Pawn (119M downloads) - Item Scoring
```
✅ Item Comparison:
├── Upgrade arrows on items
├── Stat weighting per class/spec
├── Tooltip score display
├── "Is this an upgrade?" indicator
└── Best in slot tracking
```

---

## Part 2: Existing DC Addon Analysis & Extension Opportunities

### Current DC Addon Inventory

| Addon | Purpose | Extension Opportunities |
|-------|---------|------------------------|
| **DC-AddonProtocol** | Communication layer | ✅ Foundation for all DC-QoS features |
| **DC-AOESettings** | AoE Loot config | 🔧 Merge into DC-QoS as module |
| **DC-Collection** | Mounts/Pets/Transmog | 🔧 Add favorites, random mount button |
| **DC-GM** | Admin tools | ❌ Staff only - no changes |
| **DC-HinterlandBG** | Battleground UI | 🔧 Add scoreboard enhancements |
| **DC-Hotspot** | XP Zone markers | 🔧 Add rare scanner integration |
| **DC-InfoBar** | Top info display | 🔧 Add more plugin types |
| **DC-ItemUpgrade** | Upgrade UI | 🔧 Add Pawn-style scoring |
| **DC-Leaderboards** | Rankings | 🔧 Add personal best tracking |
| **DC-MythicPlus** | M+ HUD | 🔧 Add route planning UI |
| **DC-Welcome** | Onboarding | ✅ Plugin registry for DC-QoS |
| **Transmogrification** | Transmog UI | 🔧 Already in DC-Collection |

### Detailed Extension Analysis

#### DC-Collection Extensions
```lua
-- PROPOSED ADDITIONS:

-- 1. Random Mount Button
-- Quick summon a random mount from favorites
-- Respects flying/ground restrictions

-- 2. Favorites System
-- Star mounts/pets for quick access
-- Separate ground/flying/aquatic favorites

-- 3. Set Manager
-- Save transmog sets
-- Quick-apply saved looks

-- 4. Achievement Progress
-- Show collection completion %
-- Track "next unlock" goals

-- 5. Share/Import
-- Export appearance links
-- Import from string codes
```

#### DC-Hotspot Extensions
```lua
-- PROPOSED ADDITIONS:

-- 1. Rare Scanner Integration
-- Alert when rare spawns in current zone
-- Show rare respawn timers

-- 2. Resource Node Tracking
-- Remember herb/ore locations
-- Display on minimap

-- 3. Treasure Detection
-- Alert for nearby treasure chests
-- Custom treasures support

-- 4. Event Alerts
-- World event announcements
-- Custom event timers
```

#### DC-InfoBar Extensions
```lua
-- PROPOSED ADDITIONS:

-- 1. Performance Stats Plugin
-- FPS, latency, memory usage
-- Performance warnings

-- 2. Clock/Calendar Plugin
-- Server time, local time
-- Event countdown timers

-- 3. Durability Plugin
-- Gear durability warning
-- Auto-repair reminder

-- 4. XP/Rep Tracker Plugin
-- XP per hour calculation
-- Rep gains summary

-- 5. Currency Quick View
-- All custom currencies
-- Session gains
```

#### DC-ItemUpgrade Extensions
```lua
-- PROPOSED ADDITIONS:

-- 1. Stat Weights Display
-- Show effective stat values
-- Per-class optimization hints

-- 2. Upgrade Path Visualization
-- Show full tier progression
-- Cost preview for all tiers

-- 3. Quick Upgrade Mode
-- Upgrade all slots at once
-- Batch processing

-- 4. Upgrade History
-- Track what you've upgraded
-- Undo last upgrade option
```

#### DC-MythicPlus Extensions
```lua
-- PROPOSED ADDITIONS:

-- 1. Route Planner (MDT-lite)
-- Simple pull planning
-- Trash percentage calculator

-- 2. Death Tracker
-- Per-player death count
-- Death location map

-- 3. Affix Helper
-- Show current week affixes
-- Affix-specific tips

-- 4. Personal Best Tracking
-- Per-dungeon bests
-- Goal setting (beat by X seconds)
```

---

## Part 3: DC-QoS Module Design

### Architecture Overview

```
DC-QoS/
├── DC-QoS.toc
├── Core.lua                    # Main framework, settings
├── Protocol.lua                # DCAddonProtocol handlers
├── UI/
│   ├── SettingsPanel.lua       # Main config UI
│   └── ModuleSettings.lua      # Per-module config
└── Modules/
    ├── AutoSell.lua            # Auto sell junk
    ├── AutoRepair.lua          # Auto repair gear
    ├── FastLoot.lua            # Instant loot
    ├── CooldownText.lua        # OmniCC-style
    ├── AutoQuest.lua           # Quest automation
    ├── ChatEnhancements.lua    # Chat improvements
    ├── TooltipEnhancements.lua # Tooltip additions
    ├── CameraEnhancements.lua  # Camera options
    ├── MinimapEnhancements.lua # Minimap options
    ├── UIEnhancements.lua      # Interface tweaks
    ├── Waypoints.lua           # TomTom-style nav
    ├── RareAlert.lua           # Rare spawn alerts
    ├── GTFO.lua                # Stand in bad warning
    └── ItemScore.lua           # Upgrade indicators
```

### Module Specifications

#### Module 1: AutoSell (Junk Seller)
**Priority: HIGH** | Server Integration: YES

```lua
-- Features:
-- • Auto sell gray items at any vendor
-- • Configurable quality threshold (gray only vs gray+white)
-- • Exception list (don't sell specific items)
-- • Gold earned summary
-- • Integrates with AoE loot settings

-- Server-side benefits:
-- • Can sync exception list across characters
-- • Server can add protected items list (event items, etc)

-- Config Options:
local AutoSellDefaults = {
    enabled = true,
    sellGray = true,
    sellWhite = false,
    showSummary = true,
    protectedItems = {},  -- Player-defined don't-sell list
    serverProtected = {}, -- Server-defined protected items
}
```

#### Module 2: AutoRepair
**Priority: HIGH** | Server Integration: NO

```lua
-- Features:
-- • Auto repair all gear at vendor
-- • Guild repair if available
-- • Low durability warning
-- • Show repair cost before confirming

-- Config Options:
local AutoRepairDefaults = {
    enabled = true,
    useGuildFunds = true,
    warnDurability = 20, -- % to show warning
    showCost = true,
}
```

#### Module 3: FastLoot
**Priority: HIGH** | Server Integration: OPTIONAL

```lua
-- Features:
-- • Eliminate loot animation delay
-- • Instant loot speed
-- • Works with AoE loot

-- Implementation:
-- LOOT_OPENED handler that immediately closes loot window
-- Server can optionally enforce this via config

local FastLootDefaults = {
    enabled = true,
    instant = true,
}
```

#### Module 4: CooldownText (OmniCC-style)
**Priority: HIGH** | Server Integration: NO

```lua
-- Features:
-- • Text overlay on cooldown icons
-- • Color changes based on remaining time
-- • Customizable font, size, threshold
-- • Works on action bars, inventory, buffs

-- Config Options:
local CooldownTextDefaults = {
    enabled = true,
    minDuration = 2,     -- Don't show for < 2 sec
    mmssThreshold = 60,  -- Show MM:SS above this
    fontSize = 18,
    colors = {
        short = {1, 0, 0, 1},      -- Red when < 5 sec
        medium = {1, 1, 0, 1},     -- Yellow when < 30 sec
        long = {1, 1, 1, 1},       -- White otherwise
    },
}
```

#### Module 5: AutoQuest
**Priority: MEDIUM** | Server Integration: YES

```lua
-- Features:
-- • Auto accept quests from NPCs
-- • Auto turn-in completed quests
-- • Skip gossip text (one-click NPCs)
-- • Configurable exceptions

-- Server-side benefits:
-- • Server can flag quests that SHOULD NOT auto-accept
-- • Important story quests can require manual read

local AutoQuestDefaults = {
    enabled = true,
    autoAccept = true,
    autoTurnIn = true,
    skipGossip = true,
    exceptions = {},       -- Quest IDs to never auto-handle
    serverExceptions = {}, -- Server-pushed quest exceptions
}
```

#### Module 6: ChatEnhancements
**Priority: MEDIUM** | Server Integration: OPTIONAL

```lua
-- Features:
-- • Copy chat messages (Shift+click)
-- • URL detection and copy
-- • Channel sticky (remember last used)
-- • Class-colored names
-- • Timestamp display

local ChatEnhancementsDefaults = {
    enabled = true,
    enableCopy = true,
    detectURLs = true,
    classColors = true,
    showTimestamps = true,
    timestampFormat = "[%H:%M] ",
}
```

#### Module 7: TooltipEnhancements
**Priority: MEDIUM** | Server Integration: YES

```lua
-- Features:
-- • Show item ID in tooltips
-- • Show item level
-- • Show vendor sell price
-- • Show upgrade tier info (from DC-ItemUpgrade)
-- • Player item level in player tooltip

-- Server Integration:
-- • Server sends custom item info (upgrade potential, etc)

local TooltipEnhancementsDefaults = {
    enabled = true,
    showItemID = true,
    showItemLevel = true,
    showSellPrice = true,
    showUpgradeTier = true,
    showPlayerItemLevel = true,
}
```

#### Module 8: CameraEnhancements
**Priority: LOW** | Server Integration: NO

```lua
-- Features:
-- • Extended max camera distance
-- • Faster camera zoom
-- • Action cam options

local CameraEnhancementsDefaults = {
    enabled = true,
    maxZoomFactor = 2.0,  -- Multiplier for max distance
    zoomSpeed = 2.0,      -- Faster scroll
}
```

#### Module 9: MinimapEnhancements
**Priority: MEDIUM** | Server Integration: OPTIONAL

```lua
-- Features:
-- • Coordinates display on minimap
-- • Zone text enhancement
-- • Ping notifications
-- • Click-to-set waypoint

local MinimapEnhancementsDefaults = {
    enabled = true,
    showCoords = true,
    coordsFormat = "%.1f, %.1f",
    showZone = true,
    enableWaypoints = true,
}
```

#### Module 10: UIEnhancements
**Priority: LOW** | Server Integration: NO

```lua
-- Features:
-- • Hide gryphon art on action bars
-- • Enhanced dressing room
-- • Wider quest log
-- • Move UI elements

local UIEnhancementsDefaults = {
    enabled = true,
    hideGryphons = false,
    enhancedDressingRoom = true,
    widerQuestLog = false,
}
```

#### Module 11: Waypoints (TomTom-style)
**Priority: MEDIUM** | Server Integration: YES

```lua
-- Features:
-- • On-screen arrow pointing to destination
-- • Distance and ETA display
-- • Set waypoint from coords
-- • Click on map to set waypoint
-- • Integration with DC-Hotspot

-- Server Integration:
-- • Server can set waypoints for quests
-- • Event locations auto-waypoint

local WaypointsDefaults = {
    enabled = true,
    showArrow = true,
    showDistance = true,
    showETA = true,
    arrowScale = 1.0,
}
```

#### Module 12: RareAlert
**Priority: MEDIUM** | Server Integration: YES

```lua
-- Features:
-- • Alert when rare mob spawns nearby
-- • Sound and screen flash
-- • Click to set waypoint
-- • Tracks rare kill history

-- Server Integration:
-- • Server broadcasts rare spawn events
-- • Respawn timer sync

local RareAlertDefaults = {
    enabled = true,
    soundAlert = true,
    screenFlash = true,
    showWaypoint = true,
    alertRange = 500, -- yards
}
```

#### Module 13: GTFO (Ground Effects Warning)
**Priority: LOW** | Server Integration: NO

```lua
-- Features:
-- • Audio alert when standing in bad
-- • Different sounds for severity
-- • Volume control
-- • Visual flash option

local GTFODefaults = {
    enabled = true,
    soundVolume = 0.8,
    highAlert = true,
    lowAlert = true,
    visualFlash = false,
}
```

#### Module 14: ItemScore (Pawn-style)
**Priority: MEDIUM** | Server Integration: YES

```lua
-- Features:
-- • Green arrow on upgrade items
-- • Stat weight calculations
-- • Integration with DC-ItemUpgrade tiers
-- • Tooltip score display

-- Server Integration:
-- • Server provides optimal stat weights per class
-- • Considers custom item properties

local ItemScoreDefaults = {
    enabled = true,
    showArrows = true,
    showScore = true,
    autoWeights = true, -- Use server-provided weights
}
```

---

## Part 4: Server-Side Features (Addon-Delivered)

These features require server-side Eluna scripts that communicate with DC-QoS via DCAddonProtocol.

### Server-Enhanced Features

#### 1. Smart Auto-Sell
```lua
-- Server Script: Syncs protected item list

-- Server sends list of items that should NEVER be auto-sold:
-- • Event items
-- • Quest items (non-gray)
-- • Crafting materials
-- • Custom currency items

-- Eluna Handler:
local function OnPlayerLogin(event, player)
    local protectedItems = GetProtectedItemList()
    DC:SendToPlayer(player, "QOS", 0x01, protectedItems)
end
RegisterPlayerEvent(3, OnPlayerLogin)
```

#### 2. Quest Exception Sync
```lua
-- Server marks quests that should NOT auto-complete:
-- • Story-critical quests
-- • Choice quests (reward selection)
-- • Seasonal content introduction

local function OnPlayerLogin(event, player)
    local questExceptions = GetQuestExceptions()
    DC:SendToPlayer(player, "QOS", 0x02, questExceptions)
end
```

#### 3. Rare Spawn Broadcasts
```lua
-- Server broadcasts rare spawns to nearby players

local function OnRareSpawn(event, creature)
    if IsRareCreature(creature) then
        local nearbyPlayers = GetPlayersInRange(creature, 500)
        for _, player in pairs(nearbyPlayers) do
            local data = {
                id = creature:GetEntry(),
                name = creature:GetName(),
                x = creature:GetX(),
                y = creature:GetY(),
                map = creature:GetMapId(),
            }
            DC:SendToPlayer(player, "QOS", 0x10, data)
        end
    end
end
RegisterCreatureEvent(CREATURE_EVENT_ON_SPAWN, OnRareSpawn)
```

#### 4. Stat Weights Distribution
```lua
-- Server provides optimal stat weights per class/spec

local classWeights = {
    [1] = { -- Warrior
        strength = 2.0,
        stamina = 1.5,
        attackPower = 1.0,
        critRating = 0.8,
        hitRating = 1.5,
    },
    -- ... other classes
}

local function OnPlayerLogin(event, player)
    local class = player:GetClass()
    if classWeights[class] then
        DC:SendToPlayer(player, "QOS", 0x20, classWeights[class])
    end
end
```

#### 5. Waypoint Commands
```lua
-- Server can set player waypoints via commands

local function SetPlayerWaypoint(player, mapId, x, y, label)
    local data = {
        map = mapId,
        x = x,
        y = y,
        label = label or "Destination",
    }
    DC:SendToPlayer(player, "QOS", 0x30, data)
end

-- Usage: SetPlayerWaypoint(player, 571, 5789, 643, "Dalaran")
```

---

## Part 5: Implementation Priority Roadmap

### Phase 1: Core QoL (Week 1-2)
**Focus: Highest-value, lowest-complexity features**

| Module | Priority | Complexity | Player Value | Server Req |
|--------|----------|------------|--------------|------------|
| FastLoot | HIGH | Low | Very High | No |
| AutoSell | HIGH | Low | Very High | Optional |
| AutoRepair | HIGH | Low | High | No |
| CooldownText | HIGH | Medium | Very High | No |

**Deliverables:**
- [ ] DC-QoS addon framework
- [ ] Settings panel integration with DC-Welcome
- [ ] FastLoot module
- [ ] AutoSell module
- [ ] AutoRepair module
- [ ] CooldownText module

### Phase 2: Enhanced Experience (Week 3-4)
**Focus: Tooltip and interface improvements**

| Module | Priority | Complexity | Player Value | Server Req |
|--------|----------|------------|--------------|------------|
| TooltipEnhancements | MEDIUM | Medium | High | Yes |
| MinimapEnhancements | MEDIUM | Low | Medium | Optional |
| ChatEnhancements | MEDIUM | Medium | Medium | No |
| AutoQuest | MEDIUM | Medium | High | Yes |

**Deliverables:**
- [ ] Tooltip module with item ID, ilvl, sell price
- [ ] Minimap coords and zone display
- [ ] Chat copy and timestamps
- [ ] Auto quest accept/turn-in

### Phase 3: Navigation & Alerts (Week 5-6)
**Focus: World interaction features**

| Module | Priority | Complexity | Player Value | Server Req |
|--------|----------|------------|--------------|------------|
| Waypoints | MEDIUM | High | High | Yes |
| RareAlert | MEDIUM | Medium | Medium | Yes |
| ItemScore | MEDIUM | High | High | Yes |

**Deliverables:**
- [ ] TomTom-style waypoint arrow
- [ ] Rare spawn alert system
- [ ] Pawn-style item scoring

### Phase 4: Polish (Week 7-8)
**Focus: Extra features and refinement**

| Module | Priority | Complexity | Player Value | Server Req |
|--------|----------|------------|--------------|------------|
| CameraEnhancements | LOW | Low | Medium | No |
| UIEnhancements | LOW | Medium | Low | No |
| GTFO | LOW | Medium | Medium | No |

**Deliverables:**
- [ ] Camera distance options
- [ ] UI cleanup options
- [ ] Ground effects warning

---

## Part 6: DC Addon Extension Recommendations

### Immediate Extensions (Easy Wins)

#### DC-InfoBar Plugin Additions
```lua
-- Add these plugins to DC-InfoBar:

-- 1. FPS/Latency Plugin
-- Shows current FPS and world/home latency

-- 2. Durability Plugin  
-- Shows lowest durability item, warns when low

-- 3. Bag Space Plugin
-- Shows free bag slots, warns when full

-- 4. XP Rate Plugin
-- Shows XP/hour, time to level

-- 5. Clock Plugin
-- Server time, local time, raid reset countdown
```

#### DC-Collection Enhancements
```lua
-- 1. Random Mount Button
-- Add to character frame or keybind
-- Respects flying/swimming

-- 2. Mount Favorites
-- Star system for frequently used mounts
-- Separate categories (ground/flying/water)

-- 3. Quick Apply Transmog
-- Save outfits to slots
-- One-click apply
```

#### DC-Hotspot Enhancements
```lua
-- 1. Rare Integration
-- When a rare spawns, add temporary pin
-- Show respawn timer

-- 2. Resource Tracking
-- Remember herb/ore node locations
-- Display on minimap (like GatherMate)

-- 3. Treasure Pins
-- Custom treasure locations
-- Completion tracking
```

#### DC-MythicPlus Enhancements
```lua
-- 1. Affix Preview
-- Show upcoming week's affixes
-- Affix explanations

-- 2. Route Suggestions
-- Simple pull suggestions per dungeon
-- Percentage tracking

-- 3. Personal Records
-- Per-dungeon best times
-- Track improvement over time
```

---

## Part 7: Code Examples

### DC-QoS Core Framework

```lua
--[[
    DC-QoS Core.lua
    Quality of Service Addon for Dark Chaos
]]

local addonName = "DC-QoS"
DCQoS = DCQoS or {}

-- Version
DCQoS.VERSION = "1.0.0"
DCQoS.MODULE_ID = "QOS"

-- Module Registry
DCQoS.Modules = {}
DCQoS.ModuleDefaults = {}

-- DCAddonProtocol reference
local DC = nil

-- ============================================================================
-- Module Registration API
-- ============================================================================

function DCQoS:RegisterModule(moduleId, module)
    if self.Modules[moduleId] then
        return false -- Already registered
    end
    
    self.Modules[moduleId] = module
    
    -- Initialize module if we're already loaded
    if self.loaded and module.OnInitialize then
        module:OnInitialize()
    end
    
    return true
end

function DCQoS:GetModule(moduleId)
    return self.Modules[moduleId]
end

function DCQoS:EnableModule(moduleId)
    local module = self.Modules[moduleId]
    if module and module.Enable then
        module:Enable()
        self.db.modules[moduleId] = true
    end
end

function DCQoS:DisableModule(moduleId)
    local module = self.Modules[moduleId]
    if module and module.Disable then
        module:Disable()
        self.db.modules[moduleId] = false
    end
end

-- ============================================================================
-- Settings Management
-- ============================================================================

local defaults = {
    modules = {
        FastLoot = true,
        AutoSell = true,
        AutoRepair = true,
        CooldownText = true,
        TooltipEnhancements = true,
        MinimapEnhancements = true,
        ChatEnhancements = false,
        AutoQuest = false,
        Waypoints = true,
        RareAlert = true,
        ItemScore = false,
        CameraEnhancements = false,
        UIEnhancements = false,
        GTFO = false,
    },
    moduleSettings = {}, -- Per-module settings
}

-- ============================================================================
-- Initialization
-- ============================================================================

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("ADDON_LOADED")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- Load saved variables
        DCQoS_DB = DCQoS_DB or {}
        for k, v in pairs(defaults) do
            if DCQoS_DB[k] == nil then
                DCQoS_DB[k] = v
            end
        end
        DCQoS.db = DCQoS_DB
        
        -- Initialize DCAddonProtocol connection
        DC = rawget(_G, "DCAddonProtocol")
        if DC then
            DCQoS:InitializeProtocol()
        end
        
        -- Initialize all registered modules
        for moduleId, module in pairs(DCQoS.Modules) do
            if module.OnInitialize then
                module:OnInitialize()
            end
            
            -- Enable if saved as enabled
            if DCQoS.db.modules[moduleId] and module.Enable then
                module:Enable()
            end
        end
        
        DCQoS.loaded = true
        DCQoS:Print("Loaded - " .. DCQoS:GetEnabledModuleCount() .. " modules active")
        
    elseif event == "PLAYER_LOGIN" then
        -- Request server sync
        if DC then
            DC:Request(DCQoS.MODULE_ID, 0x01, {})  -- Request config sync
        end
        
    elseif event == "PLAYER_LOGOUT" then
        -- Save settings
        DCQoS_DB = DCQoS.db
    end
end)

function DCQoS:GetEnabledModuleCount()
    local count = 0
    for moduleId, enabled in pairs(self.db.modules) do
        if enabled then count = count + 1 end
    end
    return count
end

function DCQoS:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC-QoS]|r " .. msg)
end

-- ============================================================================
-- Protocol Handlers
-- ============================================================================

function DCQoS:InitializeProtocol()
    -- Register handlers for server messages
    DC:On(self.MODULE_ID, 0x01, function(data)  -- Config sync
        if data.protectedItems then
            local autoSell = self:GetModule("AutoSell")
            if autoSell then
                autoSell:SetServerProtected(data.protectedItems)
            end
        end
    end)
    
    DC:On(self.MODULE_ID, 0x02, function(data)  -- Quest exceptions
        local autoQuest = self:GetModule("AutoQuest")
        if autoQuest then
            autoQuest:SetServerExceptions(data.exceptions)
        end
    end)
    
    DC:On(self.MODULE_ID, 0x10, function(data)  -- Rare spawn alert
        local rareAlert = self:GetModule("RareAlert")
        if rareAlert then
            rareAlert:OnRareSpawn(data)
        end
    end)
    
    DC:On(self.MODULE_ID, 0x20, function(data)  -- Stat weights
        local itemScore = self:GetModule("ItemScore")
        if itemScore then
            itemScore:SetStatWeights(data)
        end
    end)
    
    DC:On(self.MODULE_ID, 0x30, function(data)  -- Waypoint command
        local waypoints = self:GetModule("Waypoints")
        if waypoints then
            waypoints:SetWaypoint(data.map, data.x, data.y, data.label)
        end
    end)
end

-- ============================================================================
-- Slash Commands
-- ============================================================================

SLASH_DCQOS1 = "/dcqos"
SLASH_DCQOS2 = "/qos"
SlashCmdList["DCQOS"] = function(msg)
    if msg == "" or msg == "config" or msg == "settings" then
        DCQoS:OpenSettings()
    elseif msg == "list" then
        DCQoS:ListModules()
    else
        DCQoS:Print("Usage: /dcqos [config|list]")
    end
end

function DCQoS:ListModules()
    self:Print("Modules:")
    for moduleId, enabled in pairs(self.db.modules) do
        local status = enabled and "|cff00ff00ON|r" or "|cffff0000OFF|r"
        print("  " .. moduleId .. ": " .. status)
    end
end
```

### Example Module: FastLoot

```lua
--[[
    DC-QoS FastLoot Module
    Eliminates loot animation delay for instant looting
]]

local FastLoot = {}
DCQoS.Modules = DCQoS.Modules or {}

-- Module registration
local MODULE_ID = "FastLoot"

-- Defaults
local defaults = {
    enabled = true,
}

-- ============================================================================
-- Module API
-- ============================================================================

function FastLoot:OnInitialize()
    self.db = DCQoS.db.moduleSettings[MODULE_ID] or {}
    for k, v in pairs(defaults) do
        if self.db[k] == nil then
            self.db[k] = v
        end
    end
    DCQoS.db.moduleSettings[MODULE_ID] = self.db
    
    -- Create loot frame hook
    self.frame = CreateFrame("Frame")
end

function FastLoot:Enable()
    self.enabled = true
    self.frame:RegisterEvent("LOOT_READY")
    self.frame:RegisterEvent("LOOT_OPENED")
    self.frame:SetScript("OnEvent", function(f, event, autoLoot)
        if event == "LOOT_READY" then
            -- In WotLK 3.3.5a, we speed up by processing loot quickly
            if GetCVarBool("autoLootDefault") ~= IsModifiedClick("AUTOLOOTTOGGLE") then
                for i = GetNumLootItems(), 1, -1 do
                    LootSlot(i)
                end
            end
        elseif event == "LOOT_OPENED" and autoLoot then
            -- Auto-loot is active, close quickly
            for i = GetNumLootItems(), 1, -1 do
                LootSlot(i)
            end
        end
    end)
end

function FastLoot:Disable()
    self.enabled = false
    self.frame:UnregisterAllEvents()
end

function FastLoot:GetSettingsPanel()
    -- Return settings UI elements for the DC-QoS settings panel
    return {
        {
            type = "checkbox",
            label = "Enable Fast Loot",
            get = function() return self.db.enabled end,
            set = function(v) 
                self.db.enabled = v
                if v then self:Enable() else self:Disable() end
            end,
        },
    }
end

-- Register module
DCQoS:RegisterModule(MODULE_ID, FastLoot)
```

### Example Module: CooldownText

```lua
--[[
    DC-QoS CooldownText Module
    Adds text overlay to cooldown animations (OmniCC-style)
]]

local CooldownText = {}
local MODULE_ID = "CooldownText"

local defaults = {
    enabled = true,
    minDuration = 2,
    fontSize = 18,
    fontFace = "Fonts\\FRIZQT__.TTF",
    showDecimals = true,
    decimalThreshold = 3,
    colors = {
        short = {1, 0, 0, 1},      -- Red < 5 sec
        medium = {1, 0.8, 0, 1},   -- Yellow < 30 sec
        long = {1, 1, 1, 1},       -- White otherwise
    },
}

-- Track hooked cooldown frames
local hookedCooldowns = {}

-- ============================================================================
-- Core Functions
-- ============================================================================

local function FormatCooldown(seconds)
    if seconds >= 86400 then
        return string.format("%dd", math.floor(seconds / 86400))
    elseif seconds >= 3600 then
        return string.format("%dh", math.floor(seconds / 3600))
    elseif seconds >= 60 then
        return string.format("%dm", math.floor(seconds / 60))
    elseif seconds >= CooldownText.db.decimalThreshold then
        return string.format("%d", math.floor(seconds))
    else
        return string.format("%.1f", seconds)
    end
end

local function GetCooldownColor(remaining)
    local db = CooldownText.db
    if remaining < 5 then
        return unpack(db.colors.short)
    elseif remaining < 30 then
        return unpack(db.colors.medium)
    else
        return unpack(db.colors.long)
    end
end

local function UpdateCooldownText(cooldown)
    local textFrame = cooldown.dcqosText
    if not textFrame then return end
    
    local start, duration = cooldown:GetCooldownTimes()
    if duration == 0 then
        textFrame:SetText("")
        return
    end
    
    -- Convert from milliseconds in WotLK
    start = start / 1000
    duration = duration / 1000
    
    local remaining = start + duration - GetTime()
    
    if remaining <= 0 then
        textFrame:SetText("")
    elseif remaining < CooldownText.db.minDuration then
        textFrame:SetText("")
    else
        textFrame:SetText(FormatCooldown(remaining))
        textFrame:SetTextColor(GetCooldownColor(remaining))
    end
end

local function HookCooldown(cooldown)
    if hookedCooldowns[cooldown] then return end
    
    -- Create text overlay
    local text = cooldown:CreateFontString(nil, "OVERLAY")
    text:SetFont(CooldownText.db.fontFace, CooldownText.db.fontSize, "OUTLINE")
    text:SetPoint("CENTER", 0, 0)
    cooldown.dcqosText = text
    
    -- Hook the SetCooldown method
    local originalSetCooldown = cooldown.SetCooldown
    if originalSetCooldown then
        cooldown.SetCooldown = function(self, start, duration)
            originalSetCooldown(self, start, duration)
            UpdateCooldownText(self)
        end
    end
    
    hookedCooldowns[cooldown] = true
end

-- ============================================================================
-- Module API
-- ============================================================================

function CooldownText:OnInitialize()
    self.db = DCQoS.db.moduleSettings[MODULE_ID] or {}
    for k, v in pairs(defaults) do
        if self.db[k] == nil then
            self.db[k] = v
        end
    end
    DCQoS.db.moduleSettings[MODULE_ID] = self.db
    
    self.frame = CreateFrame("Frame")
end

function CooldownText:Enable()
    self.enabled = true
    
    -- Hook all action buttons
    for i = 1, 12 do
        local button = _G["ActionButton"..i]
        if button then
            local cooldown = button.cooldown or _G[button:GetName().."Cooldown"]
            if cooldown then HookCooldown(cooldown) end
        end
    end
    
    -- Hook additional action bars
    local barPrefixes = {
        "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
        "MultiBarLeftButton", "MultiBarRightButton",
    }
    for _, prefix in ipairs(barPrefixes) do
        for i = 1, 12 do
            local button = _G[prefix..i]
            if button then
                local cooldown = button.cooldown or _G[prefix..i.."Cooldown"]
                if cooldown then HookCooldown(cooldown) end
            end
        end
    end
    
    -- Update timer
    self.frame:SetScript("OnUpdate", function(f, elapsed)
        f.elapsed = (f.elapsed or 0) + elapsed
        if f.elapsed >= 0.1 then
            f.elapsed = 0
            for cooldown in pairs(hookedCooldowns) do
                UpdateCooldownText(cooldown)
            end
        end
    end)
end

function CooldownText:Disable()
    self.enabled = false
    self.frame:SetScript("OnUpdate", nil)
    
    -- Hide all text
    for cooldown in pairs(hookedCooldowns) do
        if cooldown.dcqosText then
            cooldown.dcqosText:SetText("")
        end
    end
end

function CooldownText:GetSettingsPanel()
    return {
        {
            type = "checkbox",
            label = "Enable Cooldown Text",
            get = function() return self.db.enabled end,
            set = function(v) 
                self.db.enabled = v
                if v then self:Enable() else self:Disable() end
            end,
        },
        {
            type = "slider",
            label = "Font Size",
            min = 10, max = 32, step = 1,
            get = function() return self.db.fontSize end,
            set = function(v) self.db.fontSize = v end,
        },
        {
            type = "slider",
            label = "Minimum Duration",
            min = 0, max = 10, step = 0.5,
            get = function() return self.db.minDuration end,
            set = function(v) self.db.minDuration = v end,
        },
    }
end

DCQoS:RegisterModule(MODULE_ID, CooldownText)
```

---

## Part 8: Integration with DC-Welcome Plugin System

DC-Welcome already has a plugin registration system. DC-QoS should register as a plugin:

```lua
-- In DC-QoS Core.lua, after initialization:

-- Register with DC-Welcome Plugin System
if DCWelcome and DCWelcome.RegisterPlugin then
    DCWelcome.RegisterPlugin({
        id = "DC-QoS",
        name = "Quality of Service",
        icon = "Interface\\Icons\\INV_Gizmo_GoblinBoomBox_01",
        category = "Utility",
        description = "Quality of Life improvements: fast loot, auto sell, cooldown text, and more.",
        slashCommand = "/dcqos",
        openSettings = function()
            DCQoS:OpenSettings()
        end,
    })
end
```

---

## Summary

### What DC-QoS Provides
1. **Unified QoL addon** - One addon for all convenience features
2. **Modular design** - Enable only what you want
3. **Server integration** - Enhanced features via DCAddonProtocol
4. **Consistent branding** - Matches other DC addons

### Top Priority Features (Highest Player Value)
1. **FastLoot** - Instant looting (everyone wants this)
2. **AutoSell** - Auto-sell gray items at vendors
3. **AutoRepair** - Auto-repair gear at vendors
4. **CooldownText** - Countdown on ability icons
5. **TooltipEnhancements** - Item IDs, levels, prices

### Existing Addon Extensions
1. **DC-InfoBar** - Add FPS, durability, bag space plugins
2. **DC-Collection** - Add favorites, random mount button
3. **DC-Hotspot** - Add rare scanner integration
4. **DC-MythicPlus** - Add route planning, affix preview

### Development Timeline
- **Phase 1 (Week 1-2)**: Core QoL modules
- **Phase 2 (Week 3-4)**: Tooltip and interface
- **Phase 3 (Week 5-6)**: Navigation and alerts
- **Phase 4 (Week 7-8)**: Polish and extras

This creates a comprehensive QoL system that rivals retail's built-in conveniences while leveraging Dark Chaos's unique server-addon communication capabilities.
