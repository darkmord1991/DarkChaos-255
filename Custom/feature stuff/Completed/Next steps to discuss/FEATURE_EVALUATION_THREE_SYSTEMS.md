# 🔬 Deep Feature Evaluation: Three Priority Systems
## DarkChaos-255 Next Development Phase Analysis

**Document Date:** November 30, 2025  
**Last Updated:** November 30, 2025 (Extended Analysis)  
**Scope:** Raid Finder + Mythic Dungeon Finder, Cross-System Integration, First-Start Experience  
**Purpose:** Technical evaluation, feasibility analysis, enhancement proposals - NO CODE  
**Compatibility:** ✅ WoW 3.3.5a Client | ✅ AzerothCore Master Branch

---

## 📋 Table of Contents

1. [Executive Summary](#executive-summary)
2. [3.3.5a Compatibility Matrix](#335a-compatibility-matrix)
3. [System 1: Raid Finder + Mythic Dungeon Finder Extension](#system-1-raid-finder--mythic-dungeon-finder-extension)
4. [System 2: Cross-System Integration (DC Systems)](#system-2-cross-system-integration-dc-systems)
5. [System 3: First-Start Experience (Extended)](#system-3-first-start-experience-extended)
6. [Available AzerothCore Modules](#available-azerothcore-modules)
7. [Implementation Priority Matrix](#implementation-priority-matrix)
8. [Resources & References](#resources--references)

---

# Executive Summary

> ⚠️ **Development Approach:** All new features MUST be implemented as **DC Scripts** (server-side C++) and **DC Addons** (client-side Lua), NOT as separate AzerothCore modules. This ensures maintainability and keeps all DC code centralized.

| System | Effort | Impact | Risk | Priority | 3.3.5a Compatible |
|--------|--------|--------|------|----------|-------------------|
| **Raid Finder + M+ Finder** | 10-14 weeks | ⭐⭐⭐⭐⭐ | Medium | HIGH | ✅ Yes (NPC/Addon) |
| **Cross-System Integration** | 7-11 weeks | ⭐⭐⭐⭐⭐ | High | CRITICAL | ✅ Yes (Server-side) |
| **First-Start Experience** | 3-5 weeks | ⭐⭐⭐⭐ | Low | MEDIUM-HIGH | ✅ Yes (Module+Addon) |

**Recommendation:** Start with **First-Start Experience** (quick win, low risk), then **Cross-System Integration** (foundational), finally **Raid/M+ Finder** (leverages both previous systems).

---

# 3.3.5a Compatibility Matrix

## What Works Natively in 3.3.5a Client

| Feature | Native Support | Workaround Required |
|---------|----------------|---------------------|
| **LFG Dungeon Finder UI** | ✅ Yes | None - full queue system |
| **Raid Browser UI** | ✅ Yes | Listing only, no queue |
| **Role Selection (Tank/Healer/DPS)** | ✅ Yes | Built into LFG frame |
| **Dungeon Teleportation** | ✅ Yes | LFGMgr handles this |
| **Cross-Faction Grouping** | ⚠️ Partial | mod-cfbg for BGs, custom for dungeons |
| **Custom Queue UI** | ❌ No | Addon required |
| **Keystone Level Display** | ❌ No | Addon required |
| **M+ Rating Display** | ❌ No | Addon required |
| **Flex Raid Scaling** | ❌ No | mod-autobalance + custom |

## AzerothCore LFG Types (Already Implemented)

From `src/server/game/DungeonFinding/LFGMgr.h`:
```cpp
enum LfgType {
    LFG_TYPE_NONE    = 0,  // Not in LFG
    LFG_TYPE_DUNGEON = 1,  // 5-man normal
    LFG_TYPE_RAID    = 2,  // Raid browser (listing only!)
    LFG_TYPE_ZONE    = 4,  // Zone-specific
    LFG_TYPE_HEROIC  = 5,  // 5-man heroic
    LFG_TYPE_RANDOM  = 6   // Random dungeon
};
```

**Key Insight:** `LFG_TYPE_RAID` exists but is **listing-only** (Raid Browser). Converting this to queue-based requires extending `LFGMgr`.

---

# System 1: Raid Finder + Mythic Dungeon Finder Extension

## 🎯 What Is This?

A comprehensive group-finding system that extends the existing LFG framework to support:
- **Raid Finder**: Queue-based matching for raids (10/25-man, all difficulties)
- **Mythic+ Finder**: Finding groups for M+ runs with keystone level matching
- **Scheduled Raids**: Calendar-based raid scheduling with signup system

> ### 📋 INTEGRATION DECISION SUMMARY
> 
> | Feature | Use Existing LFG? | Use Custom Addon? | Why? |
> |---------|-------------------|-------------------|------|
> | **Raid Finder (LFR)** | ✅ Yes (with DBC) | Optional overlay | Raids are static content, fits LFG model |
> | **Mythic+ Finder** | ❌ No | ✅ Yes (required) | Keys are dynamic player items, need custom UI |
> | **Scheduled Raids** | ❌ No | ✅ Yes | Calendar system doesn't exist in 3.3.5a |
>
> **Bottom Line:**
> - **LFR**: Edit `LFGDungeons.dbc` to add raids as TypeID=1 (dungeon), distribute patch
> - **M+**: Full custom addon (DC-MythicFinder) + NPC + server-side queue manager
> - **Scheduled**: Full custom addon (DC-Calendar) + NPC

## 🔧 3.3.5a Integration Approaches

### 📊 Client Integration Analysis (Technical Reality)

**The 3.3.5a WoW client has TWO distinct group-finding systems:**

| System | Client UI | Server Behavior | Queue Support |
|--------|-----------|-----------------|---------------|
| **Dungeon Finder (LFD)** | `LFGDungeonReadyDialog` | Full auto-matchmaking | ✅ Yes - Tank/Healer/DPS queue |
| **Raid Browser** | `LFRBrowseFrame` | Listing-only (no queue) | ❌ No - Manual group formation |

**Critical Limitation:**
- `LFG_TYPE_RAID = 2` → Uses **Raid Browser** (listing only!)
- `LFG_TYPE_DUNGEON = 1` → Uses **Dungeon Finder** (full queue)
- The client UI is **hardcoded** based on TypeID from `LFGDungeons.dbc`

### ✅ What CAN Be Done Without Client Patches

#### For Raids (LFR-style Queue):
1. **Add raid entries to LFGDungeons.dbc with TypeID=1** (treat as dungeon)
   - Pros: Full queue system works
   - Cons: Shows in "Dungeon" category, UI says "Dungeon" not "Raid"
2. **NPC + Custom Addon approach**
   - Full control over UI
   - No DBC editing required
   - Can show raid-specific info

#### For Mythic+ (Dynamic Key Levels):
**❌ Cannot use native LFG system effectively** because:
- Keystones are **player items with dynamic levels** (2-30+)
- LFGDungeons.dbc entries are **static** (fixed dungeon IDs)
- Would need 200+ DBC entries (8 dungeons × 25+ key levels)
- Key ownership is **player-specific**, not a fixed dungeon property
- Rating-based matchmaking not supported by native LFG

### Approach A: NPC-Based Queue (Recommended for M+)
**How It Works:**
- Custom NPC acts as "Mythic+ Finder" at major cities
- Players interact with NPC, select dungeon, key level, role
- Server matches players and forms groups
- Teleportation handled by existing LFGMgr infrastructure

**Advantages:**
- No client patches needed
- Works with existing 3.3.5a client
- Can display M+ rating, key level via gossip text
- Easy to add addon overlay for enhanced UI

**Disadvantages:**
- Less integrated feel than native LFG UI
- Requires players to visit NPC (can add `.lfg` command alternative)

### Approach B: Extend Native LFG (Recommended for Raids)
**How It Works:**
- Extend `LFGMgr` to support raid queuing (not just listing)
- Add raid entries to `LFGDungeons.dbc` with **TypeID=1** (dungeon type)
- Leverage existing role check, proposal, teleport systems
- Server-side hooks intercept and handle specially

**Advantages:**
- Uses native LFG frame - familiar UI
- Full integration with existing queue systems
- Role selection built-in

**Disadvantages:**
- Raids appear in "Dungeon" category in UI
- May confuse players expecting Raid Browser behavior
- Requires DBC patch distribution

### Approach C: Full Custom Addon (BEST for M+)
**How It Works:**
- **DC-MythicFinder** addon provides complete custom UI
- NPC at capitals opens addon interface (or `/dcmplus` command)
- Server-side queue manager handles matchmaking
- Uses DC Addon Protocol for communication

**Why This Is Best for M+:**
```
Native LFG Limitation:
├── Dungeon IDs are static (from DBC)
├── Key level is dynamic (player item property)
├── Rating is player-specific (not dungeon property)
└── Cannot filter by "who has the key"

Custom Addon Advantage:
├── Full control over filtering (key level, rating, role)
├── Shows keystone holder info
├── Rating-based matchmaking
├── Key level ranges (e.g., "Looking for +15 to +18")
└── Approval system (key holder accepts applicants)
```

### Approach D: Hybrid System (RECOMMENDED OVERALL)
- **Raids**: DBC entries with TypeID=1 for LFR-style queue
- **M+**: Custom addon + NPC for dynamic key matching
- **Scheduled Raids**: Custom calendar addon

### 📦 DBC Editing Details (For Raids Only) + NPC

## 📊 Current State Analysis

### What Already Exists in AzerothCore

| Component | Status | Location | Notes |
|-----------|--------|----------|-------|
| **5-Man LFG Queue** | ✅ Complete | `src/server/game/DungeonFinding/LFGMgr.cpp` | Full role-based matchmaking |
| **Raid Browser** | ✅ Listing-only | `LFGMgr.cpp` (RBInternalInfo struct) | Manual browsing, no queue |
| **Role Check** | ✅ Complete | `LFGPlayerData`, `LFGGroupData` | Tank/Healer/DPS validation |
| **Proposal System** | ✅ Complete | `LFGMgr::UpdateProposal()` | Accept/decline voting |
| **Dungeon Teleport** | ✅ Complete | `LFGMgr::TeleportPlayer()` | Auto-teleport on queue pop |
| **Cross-Faction BG** | ✅ Complete | `BattlegroundMgr.cpp` | CFBG enum/logic exists |

### What DarkChaos Has

| Component | Status | Location |
|-----------|--------|----------|
| **Mythic+ Core** | ✅ Complete | `src/server/scripts/DC/MythicPlus/` (25 files) |
| **Keystone System** | ✅ Complete | `item_mythic_keystone.cpp`, `MythicPlusRunManager.cpp` |
| **M+ Rating System** | ✅ Complete | `dc_mythic_player_rating` table |
| **Great Vault** | ✅ Complete | `npc_mythic_plus_great_vault.cpp` |
| **Seasonal Integration** | ✅ Complete | `MythicPlusSeasonalIntegration.cpp` |
| **M+ Spectating** | ✅ Complete | `dc_mythic_spectator.cpp/h` - Watch live M+ runs |
| **M+ Group Finder** | ❌ Not Implemented | Design exists in `15_RAID_FINDER.md` |

### What's Missing

1. **Raid Queue System** - Listing-only → Queue-based conversion
2. **M+ Group Finder** - No matchmaking for keystones
3. **Cross-Faction PvE** - CFBG exists, needs extension to dungeons/raids
4. **Flex Scaling Integration** - AutoBalance exists but not LFG-integrated
5. **Rating-Based Matchmaking** - M+ rating exists but not used for queue

## 🌐 Where It Has Been Done (Private Servers)

### Warmane (Icecrown/Lordaeron)
- **What they have**: Custom Raid Finder for ICC/Ulduar with gear requirements
- **How it works**: NPC-based queue, not native LFG UI
- **Population**: 12,000+ concurrent players
- **Source**: Proprietary (not open source)
- **Forum reference**: https://forum.warmane.com/

### TauriWoW (MoP Private Server)
- **What they have**: Full retail-like LFR system
- **How it works**: Modified DBC + LFGMgr extensions
- **Client approach**: Custom MPQ patches for LFR dungeon entries
- **Source**: Proprietary

### ChromieCraft (AzerothCore-based)
- **What they have**: Progressive LFG unlock system
- **How it works**: Content gating via mod-progression-system
- **Relevance**: Shows AC's LFG is fully extensible
- **Source**: https://github.com/chromiecraft

### Project Epoch (3.3.5a Vanilla+ Server)
- **What they have**: Custom dungeon finder with era-appropriate dungeons
- **How it works**: Database-driven dungeon definitions
- **Source**: Closed source

## 📺 YouTube Resources

| Video/Channel | Topic | Link |
|---------------|-------|------|
| StaysafeTV | "How Raid Finder Changed WoW" | History/design philosophy |
| Preach Gaming | "The Problem with M+ Group Finder" | Design lessons from retail |
| MrGM | "Private Server Development" series | General AC development |
| AzerothCore Official | AC module development tutorials | https://www.youtube.com/c/azerothcore |

**Search Terms:**
- "WoW 3.3.5 raid finder private server"
- "AzerothCore LFG customization"
- "WoW Mythic+ matchmaking system"
- "Private server queue system development"

## ✅ Advantages

| Advantage | Impact |
|-----------|--------|
| **Lower Barrier to Entry** | New/returning players can experience raids without guild |
| **Population Sustainability** | Lower player counts can still run content |
| **Uses Existing LFG UI** | Native 3.3.5a client support (no client patches for basic features) |
| **M+ Accessibility** | Opens M+ to non-organized players |
| **Cross-Faction Potential** | Dramatically increases queue pool |
| **Time-Zone Independence** | Global queue vs scheduled guild raids |
| **Alt-Friendly** | Quick gearing via LFR-like rewards |

## ❌ Disadvantages

| Disadvantage | Mitigation |
|--------------|------------|
| **Toxic Behavior Risk** | Votekick system, rating-based matching |
| **Devalues Guild Raiding** | Separate reward tiers (LFR < Normal < Heroic) |
| **Gear Check Drama** | Clear requirements, rating-based for M+ |
| **Long Queue Times (Low Pop)** | Cross-faction, flexible group sizes |
| **Complex Implementation** | Leverage existing LFGMgr, phased approach |
| **Balance Concerns** | AutoBalance integration, scaled difficulty |
| **M+ Key Bricking Risk** | Insurance mechanics, key recovery |

## 🔧 AzerothCore Changes Required

### Core Engine Changes (Low-Medium Impact)

| File | Change Type | Description |
|------|-------------|-------------|
| `LFGMgr.cpp` | Extension | Add `LFG_TYPE_RAID_FINDER`, `LFG_TYPE_MYTHIC_PLUS` queue types |
| `LFGMgr.h` | Extension | New queue state enums |
| `LFGQueue.cpp` | Extension | Rating-based matching, keystone level matching |
| `LFG.h` | Extension | New dungeon type constants |

### Database Changes

| Table | Type | Description |
|-------|------|-------------|
| `lfg_dungeon_template` | Extend | Add raid entries with flex min/max |
| `dc_raid_finder_queue` | New | Queue state storage |
| `dc_mythic_finder_queue` | New | M+ queue with keystone info |
| `dc_raid_finder_scheduled` | New | Calendar raid scheduling |
| `dc_raid_finder_signups` | New | Scheduled raid signups |

### Configuration (worldserver.conf)

```ini
# Raid Finder
DC.RaidFinder.Enable = 1
DC.RaidFinder.CrossFaction = 1
DC.RaidFinder.MinItemLevel.ICC10 = 245
DC.RaidFinder.MinItemLevel.ICC25 = 251
DC.RaidFinder.FlexScaling = 1

# Mythic+ Finder
DC.MythicFinder.Enable = 1
DC.MythicFinder.RatingMatchRange = 200
DC.MythicFinder.KeyLevelMatchRange = 3
DC.MythicFinder.AllowDowngrade = 1
```

## 📱 Client/Addon Requirements

### 🎯 RECOMMENDED APPROACH SUMMARY

| Feature | Implementation | Client Patch? | Addon Required? |
|---------|----------------|---------------|-----------------|
| **Raid Finder (LFR)** | DBC entries (TypeID=1) + Server hooks | ⚠️ DBC patch | Optional overlay |
| **M+ Group Finder** | NPC + Custom addon + Server queue | ❌ No | ✅ Yes (DC-MythicFinder) |
| **Scheduled Raids** | Custom addon + Calendar NPC | ❌ No | ✅ Yes (DC-Calendar) |

### Without Client Patches (M+ Finder)

| Component | Approach |
|-----------|----------|
| **M+ Finder UI** | Fully custom addon (DC-MythicFinder) |
| **Queue Status** | Addon frame shows position, estimated time |
| **Key Browser** | List available keystones from other players |
| **Group Approval** | Key holder accepts/rejects via addon |
| **Notifications** | Chat + addon popup alerts |

### With DBC Patch (Raid Finder Only)

| Component | DBC/MPQ Change |
|-----------|----------------|
| **LFR Raid Entries** | Add to `LFGDungeons.dbc` with TypeID=1 |
| **Teleport Positions** | Add to `lfg_dungeon_template` table |
| **Custom Icons** | Optional: `Interface/LFG` textures |

> ⚠️ **Note:** M+ entries in LFGDungeons.dbc are NOT recommended due to dynamic key levels. Use addon approach instead.

### Addon Architecture

```
DC-GroupFinder/
├── DC-GroupFinder.toc
├── Core.lua                 # Main frame, event handling
├── RaidFinder.lua           # Raid queue UI
├── MythicFinder.lua         # M+ queue UI
├── ScheduledRaids.lua       # Calendar integration
├── libs/
│   └── AIO_Integration.lua  # Server communication
└── Locales/
    └── enUS.lua
```

## 🎹 Keybind Integration: Hooking Into "I" Key (TOGGLELFGPARENT)

### Extend Existing DC-MythicPlus or New Addon?

**Current DC-MythicPlus addon** (`Custom/Client addons needed/DC-MythicPlus/`):
- ✅ Already has DC Protocol handlers for M+ data
- ✅ Already has settings panel integration
- ✅ Already has AIO + DCAddonProtocol support
- ❌ Currently only a HUD display (no group finder UI)

**RECOMMENDATION: Extend DC-MythicPlus**
- Add new files: `GroupFinder.lua`, `LFGIntegration.lua`, `Bindings.xml`
- Keep existing HUD functionality
- Add Group Finder as additional feature

### How the Native LFG Keybind Works (3.3.5a)

The "I" key is bound to `TOGGLELFGPARENT` in `Bindings.xml`:
```xml
<Binding name="TOGGLELFGPARENT">
    ToggleLFDParentFrame();
</Binding>
```

This calls `ToggleLFDParentFrame()` defined in `UIParent.lua`:
```lua
function ToggleLFDParentFrame()
    if ( UnitLevel("player") >= SHOW_LFD_LEVEL ) then
        if ( LFDParentFrame:IsShown() ) then
            HideUIPanel(LFDParentFrame);
        else
            ShowUIPanel(LFDParentFrame);
        end
    end
end
```

### 🔧 Integration Options for DC-MythicFinder

#### Option 1: Hook & Extend (RECOMMENDED)
**Add a tab/button to the existing LFD frame:**

```lua
-- DC-MythicPlus/LFGIntegration.lua

local function CreateMythicPlusTab()
    -- The LFDParentFrame has tabs: LFDParentFrameTab1 (Dungeon), LFDParentFrameTab2 (Raid)
    -- We can add a third tab for Mythic+
    
    local tab = CreateFrame("Button", "LFDParentFrameTab3", LFDParentFrame, "LFDParentFrameTabTemplate")
    tab:SetID(3)
    tab:SetPoint("LEFT", LFDParentFrameTab2, "RIGHT", -16, 0)
    tab:SetText("Mythic+")
    
    -- Create our custom content frame
    local mythicFrame = CreateFrame("Frame", "DCMythicFinderFrame", LFDParentFrame)
    mythicFrame:SetAllPoints(LFDQueueFrame)  -- Same size/position as dungeon queue
    mythicFrame:Hide()
    
    -- Hook tab click to show our frame
    tab:SetScript("OnClick", function()
        PanelTemplates_SetTab(LFDParentFrame, 3)
        LFDQueueFrame:Hide()
        LFRBrowseFrame:Hide()
        mythicFrame:Show()
    end)
    
    -- Hook existing tabs to hide our frame
    hooksecurefunc("LFDParentFrame_SetTab", function(tabID)
        if tabID ~= 3 then
            mythicFrame:Hide()
        end
    end)
end

-- Create tab when LFD loads
if LFDParentFrame then
    CreateMythicPlusTab()
else
    local loader = CreateFrame("Frame")
    loader:RegisterEvent("ADDON_LOADED")
    loader:SetScript("OnEvent", function(self, event, addon)
        if addon == "Blizzard_LookingForGroupUI" then
            CreateMythicPlusTab()
            self:UnregisterAllEvents()
        end
    end)
end
```

#### Option 2: Override Toggle Function
**Replace `ToggleLFDParentFrame` to show DC frame instead:**

```lua
-- DC-MythicFinder/KeybindOverride.lua

-- Save original function
local Original_ToggleLFDParentFrame = ToggleLFDParentFrame

-- Settings: when to use custom frame
DCMythicFinderDB = DCMythicFinderDB or {}
DCMythicFinderDB.overrideLFG = DCMythicFinderDB.overrideLFG or false

function ToggleLFDParentFrame()
    if DCMythicFinderDB.overrideLFG then
        -- Show our custom Mythic+ Finder instead
        if DCMythicFinderFrame and DCMythicFinderFrame:IsShown() then
            DCMythicFinderFrame:Hide()
        elseif DCMythicFinderFrame then
            DCMythicFinderFrame:Show()
        else
            -- Fallback to original if our frame doesn't exist
            Original_ToggleLFDParentFrame()
        end
    else
        -- Show original LFG, but we could add our button to it
        Original_ToggleLFDParentFrame()
    end
end
```

#### Option 3: Add Button to LFD Frame
**Non-intrusive: Add a "Mythic+" button that opens our addon:**

```lua
-- DC-MythicFinder/LFGButton.lua

local function AddMythicPlusButton()
    if not LFDParentFrame then return end
    
    local btn = CreateFrame("Button", "DCMythicFinderButton", LFDParentFrame, "UIPanelButtonTemplate")
    btn:SetSize(100, 22)
    btn:SetPoint("TOPRIGHT", LFDParentFrame, "TOPRIGHT", -30, -30)
    btn:SetText("Mythic+")
    btn:SetScript("OnClick", function()
        if DCMythicFinderFrame then
            if DCMythicFinderFrame:IsShown() then
                DCMythicFinderFrame:Hide()
            else
                DCMythicFinderFrame:Show()
            end
        end
    end)
    
    -- Tooltip
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Open Mythic+ Group Finder")
        GameTooltip:AddLine("Find groups for Mythic+ keystones", 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Hook into LFD frame load
hooksecurefunc("LFDParentFrame_OnLoad", AddMythicPlusButton)
```

#### Option 4: Position Frame Same as LFD (Stand-Alone)
**Create frame at same position, register alternate keybind:**

```lua
-- DC-MythicFinder/StandAlone.lua

local mainFrame = CreateFrame("Frame", "DCMythicFinderFrame", UIParent)

-- Match LFDParentFrame position and style
mainFrame:SetSize(340, 440)
mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
mainFrame:SetFrameStrata("HIGH")
mainFrame:EnableMouse(true)
mainFrame:SetMovable(true)
mainFrame:SetClampedToScreen(true)
mainFrame:Hide()

-- Register as UI Panel (same behavior as LFD - ESC closes, etc.)
UIPanelWindows["DCMythicFinderFrame"] = { area = "left", pushable = 0, whileDead = 1 }

-- Toggle function
function ToggleDCMythicFinder()
    if DCMythicFinderFrame:IsShown() then
        HideUIPanel(DCMythicFinderFrame)
    else
        ShowUIPanel(DCMythicFinderFrame)
    end
end

-- Register keybind (SHIFT+I by default, player can rebind)
BINDING_HEADER_DCMYTHICFINDER = "DC Mythic+ Finder"
BINDING_NAME_TOGGLEDCMYTHICFINDER = "Toggle Mythic+ Finder"

-- Slash command
SLASH_DCMPLUS1 = "/dcmplus"
SLASH_DCMPLUS2 = "/mythicfinder"
SlashCmdList.DCMPLUS = ToggleDCMythicFinder
```

In `Bindings.xml` (inside addon folder):
```xml
<Bindings>
    <Binding name="TOGGLEDCMYTHICFINDER" header="DCMYTHICFINDER">
        ToggleDCMythicFinder()
    </Binding>
</Bindings>
```

### 📋 Extended DC-MythicPlus Addon Structure

```
DC-MythicPlus/
├── DC-MythicPlus.toc          # Updated with new files
├── Bindings.xml               # NEW: Keybind definitions
├── Core.lua                   # Existing HUD code
├── Settings.lua               # Existing settings panel
├── SeasonalData.lua           # NEW: Seasonal table access + caching
├── GroupFinder.lua            # NEW: M+ group finder UI
├── GroupFinderQueue.lua       # NEW: Queue management
├── LFGIntegration.lua         # NEW: Hook into native LFD frame
├── KeyBrowser.lua             # NEW: Browse available keystones
└── Locales/
    └── enUS.lua               # NEW: Localization strings
```

**Updated .toc file:**
```
## Interface: 30300
## Title: DC-MythicPlus
## Notes: Mythic+ HUD, Group Finder, and Seasonal Integration
## Author: DarkChaos-255
## Version: 0.3.0
## Dependencies: AIO_Client
## OptionalDeps: DC-AddonProtocol
## SavedVariables: DCMythicPlusHUDDB

Bindings.xml
Settings.lua
SeasonalData.lua
Core.lua
GroupFinder.lua
GroupFinderQueue.lua
LFGIntegration.lua
KeyBrowser.lua
```

### 📋 RECOMMENDED IMPLEMENTATION

| Approach | Pros | Cons | Best For |
|----------|------|------|----------|
| **Option 1: Add Tab** | Native feel, discoverable | Complex, may break on client updates | Full integration |
| **Option 2: Override** | Complete control | Hides native LFG | M+ only servers |
| **Option 3: Add Button** | Simple, non-breaking | Less prominent | Minimal changes |
| **Option 4: Stand-Alone** | Independent, safe | Separate keybind | Safest option |

**RECOMMENDATION: Start with Option 3 (Add Button) + Option 4 (Stand-Alone with `/dcmplus`)**
- Add a "Mythic+" button to the native LFD frame
- Create stand-alone frame with `/dcmplus` command and optional SHIFT+I bind
- Later, upgrade to Option 1 (Add Tab) for full integration

### Key Addon Features
1. **Role Selection UI** - Tank/Healer/DPS toggles
2. **iLvl Display** - Show requirements vs current
3. **Queue Status** - Estimated wait, position
4. **M+ Key Browser** - Available keystones from other players
5. **Rating Display** - M+ rating requirement indicator
6. **Calendar View** - Scheduled raid browser

## 🗃️ Seasonal Data Access for DC-MythicPlus Addon

### Required Seasonal Tables Access

The M+ addon needs direct access to seasonal data for:
- **Dungeon Pool Rotation** - Which dungeons are active this season
- **Affix Rotation** - Weekly affix schedules
- **Season Info Display** - Current season name, rewards, end date
- **Rating Brackets** - Season-specific rating thresholds

### Existing M+ Seasonal Tables (Server-Side)

| Table | Purpose | Database |
|-------|---------|----------|
| `dc_mplus_seasons` | Season definitions (id, name, start_ts, is_active) | World |
| `dc_mplus_featured_dungeons` | Dungeon pool per season (map_id, dungeon_name, season_id) | World |
| `dc_mplus_affixes` | Affix definitions (affix_id, name, description) | World |
| `dc_mythic_plus_weekly_affixes` | Weekly affix rotation schedule | World |
| `dc_mplus_scores` | Player scores per season (character_guid, season_id, best_level) | Characters |
| `dc_mplus_keystones` | Current player keystones (character_guid, map_id, level) | Characters |

### New Opcodes Needed for Seasonal Access

```cpp
// In dc_addon_mythicplus.cpp - Add these handlers:

namespace Opcode::MPlus {
    // Existing opcodes (0x01-0x16)
    // ...
    
    // NEW: Seasonal opcodes (0x20+)
    constexpr uint8 CMSG_GET_SEASON_INFO     = 0x20;  // Request current season info
    constexpr uint8 CMSG_GET_DUNGEON_POOL    = 0x21;  // Request active dungeon pool
    constexpr uint8 CMSG_GET_AFFIX_SCHEDULE  = 0x22;  // Request affix rotation schedule
    // NOTE: Season history/browser handled by DC-Leaderboards addon (already has HandleGetSeasons)
    
    constexpr uint8 SMSG_SEASON_INFO         = 0x30;  // Season info response
    constexpr uint8 SMSG_DUNGEON_POOL        = 0x31;  // Dungeon pool response
    constexpr uint8 SMSG_AFFIX_SCHEDULE      = 0x32;  // Affix schedule response
    // NOTE: SMSG_ALL_SEASONS already in DC-Leaderboards (dc_addon_leaderboards.cpp:HandleGetSeasons)
}
```

> ⚠️ **Integration Note:** Season history/browser functionality already exists in `dc_addon_leaderboards.cpp` via `HandleGetSeasons()`. The DC-MythicPlus addon should link to DC-Leaderboards for season browsing rather than duplicating this feature.
```

### Server-Side Handler Implementation

```cpp
// Send current season info
static void SendSeasonInfo(Player* player)
{
    QueryResult result = WorldDatabase.Query(
        "SELECT season_id, season_name, start_ts, end_ts, is_active "
        "FROM dc_mplus_seasons WHERE is_active = 1 LIMIT 1");
    
    if (result)
    {
        JsonMessage(Module::MYTHIC_PLUS, Opcode::MPlus::SMSG_SEASON_INFO)
            .Set("seasonId", (*result)[0].Get<uint32>())
            .Set("seasonName", (*result)[1].Get<std::string>())
            .Set("startTimestamp", (*result)[2].Get<uint32>())
            .Set("endTimestamp", (*result)[3].Get<uint32>())
            .Set("isActive", true)
            .Send(player);
    }
}

// Send active dungeon pool for current season
static void SendDungeonPool(Player* player)
{
    uint32 seasonId = DarkChaos::MythicPlus::GetMythicPlusActiveSeason();
    
    QueryResult result = WorldDatabase.Query(
        "SELECT map_id, dungeon_name, short_name, time_limit "
        "FROM dc_mplus_featured_dungeons WHERE season_id = {} ORDER BY map_id",
        seasonId);
    
    JsonValue dungeonArray;
    dungeonArray.SetArray();
    
    if (result)
    {
        do
        {
            JsonValue dungeon;
            dungeon.SetObject();
            dungeon.Set("mapId", (*result)[0].Get<int32>());
            dungeon.Set("name", (*result)[1].Get<std::string>());
            dungeon.Set("shortName", (*result)[2].Get<std::string>());
            dungeon.Set("timeLimit", (*result)[3].Get<int32>());
            dungeonArray.Push(dungeon);
        } while (result->NextRow());
    }
    
    JsonMessage(Module::MYTHIC_PLUS, Opcode::MPlus::SMSG_DUNGEON_POOL)
        .Set("seasonId", seasonId)
        .Set("dungeons", dungeonArray.Encode())
        .Set("count", static_cast<int32>(dungeonArray.Size()))
        .Send(player);
}

// Send affix rotation schedule (next N weeks)
static void SendAffixSchedule(Player* player, uint32 weeksAhead = 4)
{
    uint32 currentWeek = GetCurrentWeekNumber();
    
    QueryResult result = WorldDatabase.Query(
        "SELECT week_number, affix_id, affix_name "
        "FROM dc_mythic_plus_weekly_affixes "
        "WHERE week_number >= {} AND week_number < {} "
        "ORDER BY week_number, affix_id",
        currentWeek, currentWeek + weeksAhead);
    
    // Build week-grouped response
    JsonValue weeksArray;
    weeksArray.SetArray();
    
    // ... group affixes by week_number ...
    
    JsonMessage(Module::MYTHIC_PLUS, Opcode::MPlus::SMSG_AFFIX_SCHEDULE)
        .Set("currentWeek", currentWeek)
        .Set("schedule", weeksArray.Encode())
        .Send(player);
}

// NOTE: SendAllSeasons() NOT needed here - already implemented in dc_addon_leaderboards.cpp
// The DC-Leaderboards addon handles season browsing via HandleGetSeasons()
// DC-MythicPlus should link to DC-Leaderboards for season history viewing
```

### DC-Leaderboards Integration (Season Browser)

The season browser/history functionality already exists in `dc_addon_leaderboards.cpp`:

```cpp
// From dc_addon_leaderboards.cpp - already implemented:
void HandleGetSeasons(Player* player, const DCAddon::ParsedMessage& /*msg*/)
{
    // Queries dc_hlbg_seasons and dc_mplus_seasons
    // Returns JSON array of {id, active} for each season
    // ...
}
```

**DC-MythicPlus links to DC-Leaderboards for season browsing:**
- "View Past Seasons" button → Opens DC-Leaderboards season selector
- "Season Leaderboards" → Opens DC-Leaderboards with M+ category
- Avoids duplicating season history UI in both addons
```

### Client-Side Handler (DC-MythicPlus Addon Extension)

```lua
-- DC-MythicPlus/SeasonalData.lua

local DCMythicPlus = _G.DCMythicPlusHUD or {}
_G.DCMythicPlusHUD = DCMythicPlus

-- Seasonal data cache
DCMythicPlus.SeasonData = {
    currentSeason = nil,
    dungeonPool = {},
    affixSchedule = {}
    -- NOTE: allSeasons not cached here - use DC-Leaderboards for season history
}

local DC = rawget(_G, "DCAddonProtocol")
if not DC then return end

-- SMSG_SEASON_INFO (0x30) - Current season info
DC:RegisterHandler("MPLUS", 0x30, function(data)
    if type(data) == "table" then
        DCMythicPlus.SeasonData.currentSeason = {
            id = data.seasonId,
            name = data.seasonName,
            startTs = data.startTimestamp,
            endTs = data.endTimestamp,
            isActive = data.isActive
        }
        -- Fire event for UI update
        if DCMythicPlus.OnSeasonInfoReceived then
            DCMythicPlus.OnSeasonInfoReceived(DCMythicPlus.SeasonData.currentSeason)
        end
    end
end)

-- SMSG_DUNGEON_POOL (0x31) - Active dungeons this season
DC:RegisterHandler("MPLUS", 0x31, function(data)
    if type(data) == "table" then
        DCMythicPlus.SeasonData.dungeonPool = data.dungeons or {}
        DCMythicPlus.SeasonData.dungeonPoolSeasonId = data.seasonId
        
        if DCMythicPlus.OnDungeonPoolReceived then
            DCMythicPlus.OnDungeonPoolReceived(DCMythicPlus.SeasonData.dungeonPool)
        end
    end
end)

-- SMSG_AFFIX_SCHEDULE (0x32) - Upcoming affix rotations
DC:RegisterHandler("MPLUS", 0x32, function(data)
    if type(data) == "table" then
        DCMythicPlus.SeasonData.affixSchedule = data.schedule or {}
        DCMythicPlus.SeasonData.currentWeek = data.currentWeek
        
        if DCMythicPlus.OnAffixScheduleReceived then
            DCMythicPlus.OnAffixScheduleReceived(DCMythicPlus.SeasonData.affixSchedule)
        end
    end
end)

-- NOTE: Season history/browser is handled by DC-Leaderboards addon
-- Link to leaderboards for season browsing:
function DCMythicPlus.OpenSeasonBrowser()
    -- Check if DC-Leaderboards is loaded
    if DCLeaderboards and DCLeaderboards.ShowSeasonSelector then
        DCLeaderboards.ShowSeasonSelector()
    else
        -- Fallback: open leaderboards addon
        SlashCmdList["DCBOARD"]("seasons")
    end
end

-- Request functions
function DCMythicPlus.RequestSeasonInfo()
    DC:Send("MPLUS", 0x20)  -- CMSG_GET_SEASON_INFO
end

function DCMythicPlus.RequestDungeonPool()
    DC:Send("MPLUS", 0x21)  -- CMSG_GET_DUNGEON_POOL
end

function DCMythicPlus.RequestAffixSchedule()
    DC:Send("MPLUS", 0x22)  -- CMSG_GET_AFFIX_SCHEDULE
end

-- Season history accessed via DC-Leaderboards, not duplicated here

-- Request all seasonal data on login
function DCMythicPlus.RefreshSeasonalData()
    DCMythicPlus.RequestSeasonInfo()
    DCMythicPlus.RequestDungeonPool()
    DCMythicPlus.RequestAffixSchedule()
end

-- Auto-refresh on player login
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", function(self, event)
    -- Delay slightly to ensure protocol is ready
    C_Timer.After(2, function()
        DCMythicPlus.RefreshSeasonalData()
    end)
end)
```

### Group Finder Integration with Seasonal Data

```lua
-- DC-MythicPlus/GroupFinder.lua

function DCMythicPlus.PopulateDungeonDropdown()
    local pool = DCMythicPlus.SeasonData.dungeonPool
    if not pool or #pool == 0 then
        -- Request if not cached
        DCMythicPlus.RequestDungeonPool()
        return
    end
    
    -- Populate dropdown with seasonal dungeons only
    for i, dungeon in ipairs(pool) do
        UIDropDownMenu_AddButton({
            text = dungeon.name,
            value = dungeon.mapId,
            func = function() DCMythicPlus.SelectDungeon(dungeon.mapId) end
        })
    end
end

function DCMythicPlus.ShowCurrentAffixes()
    local season = DCMythicPlus.SeasonData.currentSeason
    local affixes = DCMythicPlus.SeasonData.affixSchedule[1] -- Current week
    
    if season then
        DCMythicPlusFinderFrame.SeasonText:SetText(
            string.format("Season %d: %s", season.id, season.name)
        )
    end
    
    if affixes then
        -- Display this week's affixes in the finder UI
        DCMythicPlusFinderFrame.AffixText:SetText(
            table.concat(affixes, ", ")
        )
    end
end
```

## 📈 Effort Estimation

| Phase | Duration | Focus |
|-------|----------|-------|
| **Phase 1** | 3-4 weeks | Raid Finder queue (extends existing LFGMgr) |
| **Phase 2** | 3-4 weeks | Mythic+ Finder (integrates with M+ system) |
| **Phase 3** | 2-3 weeks | Scheduled Raids calendar system |
| **Phase 4** | 2-3 weeks | Addon UI, polish, cross-faction |

**Total: 10-14 weeks**

## 🔗 Integration with Existing DC Systems

| DC System | Integration Point |
|-----------|-------------------|
| **Mythic+** | Key level, rating used for matchmaking |
| **Seasons** | Seasonal raid pools, reward multipliers |
| **Prestige** | Bonus rewards for LFR completions |
| **Item Upgrade** | Raid drops as upgrade bases |
| **Hotspots** | Raid week hotspot bonus |
| **Leaderboards** | LFR completion stats |

## 🎮 M+ Finder: Keystone Level Matching Design

### The Core Problem
Players need to find groups for specific keystone levels, not generic dungeons. The 3.3.5a LFG UI doesn't support this natively.

### Proposed Solution: DC-MythicFinder Addon + Server

**Server-Side Queue Structure:**
```
dc_mythic_finder_queue:
- player_guid
- keystone_dungeon_id (which dungeon key they have/want)
- keystone_level (2-30+)
- role (tank/healer/dps)
- player_rating (from dc_mythic_player_rating)
- is_key_holder (true if they have the key)
- preferred_min_level, preferred_max_level
- queued_at timestamp
```

**Matching Algorithm:**
1. Key holders create listings with their key level
2. Non-key players browse available keys by level range
3. Players "apply" to key holder's group
4. Key holder accepts/rejects applicants
5. OR: Auto-match based on rating ± range (configurable)

**Addon UI Features:**
- List available keystones (dungeon, level, key holder name, rating)
- Filter by dungeon, level range, roles needed
- One-click apply to join group
- Show your own key and create listing
- Rating display for all participants

### Why This Works Better Than Extending LFG
- Keystones are player items, not dungeon definitions
- Levels are dynamic (2-30+), not fixed like dungeon IDs
- Rating-based matching not supported by native LFG
- Key holder needs to approve group composition

---

# System 2: Cross-System Integration (DC Systems)

## 🎯 What Is This?

A unified architectural framework connecting all DC custom systems (Mythic+, Seasons, Prestige, Item Upgrades, Hotspots, HLBG) through:
- **Central Event Bus** - Publish/subscribe pattern for system-to-system communication
- **Unified Player Profile** - Single source of truth for all DC progression
- **Synergy System** - Cross-system bonuses and multipliers
- **Shared Data Layer** - Common access patterns for player state

## 🔧 Goal: Reduce Complexity, Eliminate Duplication

### Current DC Database Tables (Identified)

| Table | System | Issue |
|-------|--------|-------|
| `dc_seasons` | Seasons | ✅ Core table |
| `dc_season_system_data` | Seasons | Store per-system data |
| `dc_season_events` | Seasons | Event logging |
| `dc_seasonal_quest_rewards` | Seasons | Reward config |
| `dc_seasonal_creature_rewards` | Seasons | Reward config |
| `dc_mythic_player_rating` | Mythic+ | Player M+ stats |
| `dc_prestige_challenges` | Prestige | Challenge tracking |
| (More tables in Item Upgrades, Hotspots, HLBG) | Various | Need audit |

### Consolidation Goals

1. **Unified Player Profile Table** (`dc_player_profile`)
   - Replace multiple per-system player data tables
   - Single row per player with all DC progression
   - Reduces JOIN complexity, improves query performance

2. **Shared Currency Wallet** (`dc_player_currencies`)
   - All DC currencies in one table
   - Seasonal tokens, upgrade tokens, prestige points, etc.
   - Eliminates currency duplication across systems

3. **Config Registry** (`dc_config`)
   - Replace hardcoded NPCs, items, spell IDs
   - Database-driven configuration
   - No recompile needed for tuning

4. **Reduce Hardcoded Values**
   - Current: NPC IDs, item IDs scattered in C++ code
   - Goal: Config table with key-value pairs
   - Example: `NPC_MYTHIC_KEYSTONE_VENDOR = SELECT value FROM dc_config WHERE key = 'npc.mythic.vendor'`

## 📊 Current State Analysis

### Existing DC Systems

| System | Files | Status | Integration Level |
|--------|-------|--------|-------------------|
| **Mythic+** | 25 C++ files | ✅ Complete | Medium (season integration) |
| **Seasons** | 7 C++ files | ✅ Complete | Medium (reward hooks) |
| **Prestige** | 5 C++ files | ✅ Complete | Low (isolated) |
| **Item Upgrades** | 12 C++ files | ✅ Complete | Low (isolated) |
| **Hotspots** | 2 C++ files | ✅ Complete | Low (isolated) |
| **Hinterland BG** | 8 C++ files | ✅ Complete | Medium (seasonal) |
| **Phased Duels** | 1 C++ file | ✅ Complete | None (fully isolated) |
| **Addon Protocol** | Multiple | ✅ Complete | Foundation exists |

### Current Integration Problems

1. **Data Silos** - Each system has separate DB tables, no unified profile
2. **Duplicate Logic** - Player stat lookups repeated in each system
3. **No Event System** - Systems can't react to events from other systems
4. **Addon Fragmentation** - Each system has separate addon communication
5. **Inconsistent Caching** - No shared cache layer
6. **Hard to Extend** - Adding cross-system features requires touching multiple files

## 🌐 Where It Has Been Done

### Retail WoW (Blizzard)
- **Event System**: Internal C++ event manager
- **Unified Profile**: Battle.net account-wide progression
- **Cross-System**: Everything feeds into achievements, collections, transmog

### Ascension WoW (Private Server)
- **What they have**: Unified classless system with cross-system progression
- **How it works**: Central player data manager, event hooks
- **Source**: Proprietary

### Elder Scrolls Online
- **Approach**: "Champion Points" that affect all content
- **Integration**: Single progression system unlocks bonuses everywhere

### Path of Exile
- **Approach**: League mechanics all feed into common reward structure
- **Integration**: Unified item drop system that all mechanics use

## 📺 YouTube Resources

| Topic | Search Terms |
|-------|--------------|
| **Event-Driven Architecture** | "Game event system design", "Observer pattern games" |
| **Unified Game Progression** | "Cross-system progression design", "Player profile architecture" |
| **WoW Addon Development** | "WoW event handling", "AIO addon system" |

## ✅ Advantages

| Advantage | Impact |
|-----------|--------|
| **Reduced Code Duplication** | Easier maintenance, fewer bugs |
| **Dynamic Synergies** | Database-configurable cross-system bonuses |
| **Single Player Profile** | One DB query for all DC data |
| **Event-Driven Design** | Easy to add new features that react to existing ones |
| **Unified Addon Data** | One protocol for all DC addons |
| **Better Performance** | Cached player data, batch operations |
| **Easier Debugging** | Centralized event logging |
| **Extensibility** | New systems plug into existing framework |

## ❌ Disadvantages

| Disadvantage | Mitigation |
|--------------|------------|
| **Large Refactoring Effort** | Phased approach, system by system |
| **Risk of Breaking Existing** | Comprehensive test suite, staged rollout |
| **Complexity Increase** | Good documentation, clear architecture |
| **Performance Overhead (Event Bus)** | Efficient implementation, lazy subscriptions |
| **Learning Curve** | Developer documentation, examples |

## 🔧 AzerothCore Changes Required

### New Core Components (DC Scripts, not AC core)

| Component | Location | Purpose |
|-----------|----------|---------|
| `DCEventBus.h/cpp` | `src/server/scripts/DC/Integration/` | Central event pub/sub |
| `DCSystemRegistry.h/cpp` | `src/server/scripts/DC/Integration/` | System lifecycle management |
| `DCPlayerProfile.h/cpp` | `src/server/scripts/DC/Integration/` | Unified player data |
| `DCSynergyManager.h/cpp` | `src/server/scripts/DC/Integration/` | Cross-system bonus calculator |

### Database Changes

| Table | Type | Description |
|-------|------|-------------|
| `dc_player_profile` | New | Unified player progression data |
| `dc_player_unlocks` | New | Cross-system unlocks (titles, mounts, perks) |
| `dc_player_currencies` | New | Unified currency wallet |
| `dc_system_synergies` | New | Configurable cross-system bonuses |

### Event Types to Implement

```
Player Events:     PLAYER_LOGIN, PLAYER_LOGOUT, PLAYER_LEVEL_UP, PLAYER_DEATH
Combat Events:     CREATURE_KILL, BOSS_KILL, PVP_KILL, DAMAGE_DEALT
Dungeon Events:    DUNGEON_ENTER, DUNGEON_COMPLETE, DUNGEON_WIPE
Mythic+ Events:    MYTHIC_RUN_START, MYTHIC_RUN_COMPLETE, KEYSTONE_UPGRADE
Season Events:     SEASON_START, SEASON_END, SEASON_RANK_CHANGE
ItemUpgrade:       ITEM_UPGRADED, ITEM_UPGRADE_FAILED
Prestige Events:   PRESTIGE_LEVEL_UP, PRESTIGE_TALENT_LEARNED
Hotspot Events:    HOTSPOT_ENTER, HOTSPOT_EXIT, HOTSPOT_XP_GAINED
Economy Events:    CURRENCY_GAINED, CURRENCY_SPENT
```

## 📱 Client/Addon Requirements

### Unified DC Addon Data

| Component | Description |
|-----------|-------------|
| **DC-Integration.lua** | Central data cache for all DC addons |
| **DCEventBus.lua** | Client-side event distribution |
| **Unified API** | `DCIntegration:GetPlayerData()`, `DCIntegration:GetCurrency(id)` |

### AIO Integration Points

```
DC_PROFILE_UPDATE  - Full profile sync
DC_CURRENCY_UPDATE - Wallet changes
DC_UNLOCK_GAINED   - New unlock notification
DC_SYNERGY_ACTIVE  - Active bonus indicators
```

## 📈 Effort Estimation

| Phase | Duration | Focus |
|-------|----------|-------|
| **Phase 1** | 1 week | Event Bus + System Registry |
| **Phase 2** | 1 week | Unified Player Profile |
| **Phase 3** | 2-3 weeks | Migrate existing systems to event-driven |
| **Phase 4** | 1 week | Synergy system implementation |
| **Phase 5** | 1 week | Addon integration layer |
| **Phase 6** | 1 week | Testing, documentation |

**Total: 7-11 weeks**

## 🔗 Example Synergies

| Synergy Name | Source | Condition | Target | Effect |
|--------------|--------|-----------|--------|--------|
| Prestige Upgrade Discount | Prestige | Level ≥ 10 | Item Upgrade | 10% cost reduction |
| M+ Hotspot XP | Mythic+ | Key ≥ 15 | Hotspots | 25% XP bonus |
| Season Loot Boost | Seasons | Pass ≥ 50 | AOE Loot | 15% drop rate |
| Prestige Mythic Bonus | Prestige | Level ≥ 5 | Mythic+ | 5% rating bonus |
| High Key Prestige XP | Mythic+ | Key ≥ 20 | Prestige | 1.5x XP multiplier |

---

# System 3: First-Start Experience (Extended)

## 🎯 What Is This? (Expanded Scope)

A comprehensive **First-Start Experience** system, not just login rewards, including:
- **mod-customlogin Integration** - Base module for first-login rewards
- **Start Screen Addon** (DC-Welcome) - Server info, FAQ, central navigation
- **DC-Central Addon** - Unified settings panel, reduces command spam
- **AOE Loot Settings** - First-start configuration wizard
- **Progressive Tutorial** - Staged introduction to DC features

## 📊 mod-customlogin Current Features

| Feature | Status | Description |
|---------|--------|-------------|
| **Login Announcements** | ✅ | Custom welcome messages |
| **First Login Rewards** | ✅ | BoA gear distribution |
| **Weapon Skills** | ✅ | Grant additional weapon proficiencies |
| **Special Abilities** | ✅ | Custom spells, titles, mounts |
| **Reputation Config** | ✅ | Set starting rep with factions |
| **Starting Gold** | ✅ | Configurable gold/silver/copper |
| **Starting Mount** | ✅ | Mount + riding skill grant |
| **Starting Professions** | ✅ | Auto-learn professions |
| **Starting Bags** | ✅ | Class-appropriate bag assignment |

**Repository:** https://github.com/Brian-Aldridge/mod-customlogin  
**Status:** ✅ Already integrated into DarkChaos

**Note:** Module is already installed - extend functionality via DC scripts, not module modifications.

## 🚀 Enhancement Proposals (DC Scripts & Addons Only)

### Enhancement 1: DC-Welcome Start Screen Addon

**Problem:** Players login and see generic WoW - no idea what DC features exist  
**Solution:** Custom welcome frame on first login

**Features:**
- Server name, logo, brief description
- Quick links: Discord, Website, Donation
- "What's New" section with latest changes
- FAQ with common questions
- "Getting Started" guide for new players
- One-time display (or `/dcwelcome` to reopen)

**Implementation:**
- Addon: `DC-Welcome/`
- Server sends trigger on first character login
- Frame is dismissable, remembers "don't show again"

### Enhancement 2: DC-Central Hub Addon (Extensible Core)

**Problem:** Too many `/dc` commands, fragmented addon ecosystem  
**Solution:** Central hub addon that links to all DC addons and settings

> ⚠️ **CRITICAL REQUIREMENT:** DC-Central MUST be designed as an extensible foundation for:
> - Future upgrades and content patches
> - New addons (automatic discovery and registration)
> - New content (dungeons, raids, seasonal features)
> - New brackets (max level changes: 255 → 300, etc.)
> - Plugin architecture for third-party extensions

**Core Architecture - Plugin System:**
- **Self-Registering Addons** - New addons register themselves automatically
- **Version-Aware Framework** - Handles different max levels, brackets, content patches
- **Hot-Pluggable Modules** - Add/remove features without DC-Central updates
- **Backward Compatible API** - Old addons work with new DC-Central versions

**Plugin Architecture Design:**
```lua
-- DC-Central provides a registration API that all DC addons use:
-- File: DC-Central/Core/PluginAPI.lua

DCCentral = DCCentral or {}
DCCentral.Plugins = {}  -- All registered plugins
DCCentral.Version = "1.0.0"
DCCentral.MaxLevel = 255  -- Configurable, sent from server

-- Every DC addon calls this on load:
function DCCentral:RegisterPlugin(plugin)
    -- plugin = {
    --   id = "dc-mythicplus",              -- Unique ID
    --   name = "Mythic+ Dashboard",        -- Display name
    --   icon = "Interface\\Icons\\...",   -- Hub icon
    --   category = "Dungeons",             -- Hub tab/category
    --   openFunc = function() ... end,     -- Open callback
    --   settingsFunc = function() ... end, -- Settings panel
    --   minLevel = 80,                     -- Required level
    --   brackets = {"80", "255"},          -- Supported level brackets
    --   version = "1.2.0",                 -- Plugin version
    --   dependencies = {"dc-core"},        -- Required plugins
    --   priority = 10                      -- Sort order
    -- }
    table.insert(self.Plugins, plugin)
    self:RefreshHub()  -- Update hub UI
end

-- DC-Central queries server for configuration:
function DCCentral:LoadServerConfig()
    -- Request: DC|CENTRAL|CONFIG|REQUEST
    -- Response: DC|CENTRAL|CONFIG|{"maxLevel":255,"brackets":["80","255"],...}
end
```

**Hub Features:**
- Single `/dc` command opens main hub
- **Dynamic Tabs** (auto-generated from registered plugins):
  - 🏠 **Home** - Server info, announcements, quick actions
  - ⚙️ **Settings** - All DC system settings (auto-populated from plugins)
  - 🎮 **Features** - Dungeons, PvP, World features (categorized)
  - 📊 **Progress** - Unified progression view (M+, Prestige, Season)
  - 🔗 **Addons** - All registered plugins with status/versions
  - ❓ **Help/FAQ** - In-game documentation (plugin-contributed)
- **Plugin Cards:**
  - Status indicator (enabled/disabled/outdated)
  - Version compatibility check
  - One-click open/settings
  - Dependency resolution

**Registered Plugins (Initial):**

| Plugin ID | Name | Category | Min Level |
|-----------|------|----------|-----------|
| `dc-mythicplus` | Mythic+ Dashboard | Dungeons | 80 |
| `dc-itemupgrade` | Item Upgrade | Gear | 80 |
| `dc-leaderboards` | Leaderboards | Competition | 1 |
| `dc-hotspots` | Hotspot Map | World | 10 |
| `dc-aoe-settings` | AOE Loot Settings | Settings | 1 |
| `dc-prestige` | Prestige Panel | Progression | 80 |
| `dc-seasons` | Season Pass | Progression | 1 |
| `dc-spectator` | M+ Spectator | Dungeons | 1 |

**Extensibility for Future Content:**
```lua
-- Example: New expansion adds Level 300 bracket and new dungeon addon
-- The new addon simply registers itself:

-- File: DC-NewDungeons/Core.lua
if DCCentral then
    DCCentral:RegisterPlugin({
        id = "dc-newdungeons",
        name = "Shadowlands Dungeons",
        icon = "Interface\\Icons\\Achievement_Dungeon_...",
        category = "Dungeons",
        openFunc = function() DCNewDungeons:Open() end,
        minLevel = 255,
        brackets = {"300"},  -- Only for new max level
        version = "1.0.0"
    })
end

-- DC-Central automatically:
-- 1. Adds it to the hub under "Dungeons" category
-- 2. Shows it only for level 255+ characters
-- 3. Hides it on servers using "255" bracket if "300" isn't enabled
-- 4. Adds settings entry if plugin provides settingsFunc
```

**Bracket/Max Level System:**
```lua
-- Server configuration (sent on login):
DC|CENTRAL|CONFIG|{
    "maxLevel": 255,
    "activeBrackets": ["1-79", "80", "255"],
    "enabledPlugins": ["dc-mythicplus", "dc-itemupgrade", ...],
    "serverVersion": "2024.12.01",
    "announcements": [...]
}

-- DC-Central filters plugins based on bracket:
function DCCentral:FilterPluginsForCharacter(level)
    local bracket = self:GetBracketForLevel(level)
    local filtered = {}
    for _, plugin in ipairs(self.Plugins) do
        if plugin.minLevel <= level then
            if not plugin.brackets or tContains(plugin.brackets, bracket) then
                table.insert(filtered, plugin)
            end
        end
    end
    return filtered
end
```

**Benefits:**
- **One addon to access everything** - Players learn one command
- **Reduces chat command learning curve** - Visual UI instead of memorizing commands
- **Centralized data sync** - Server pushes config, all plugins receive it
- **Automatically adapts to new addons** - No DC-Central updates needed
- **Ready for content expansions** - New brackets, dungeons, features just plug in
- **Third-party friendly** - External developers can create DC-compatible plugins
- **Graceful degradation** - Missing plugins show as "Not Installed"

### Enhancement 3: First-Start AOE Loot Configuration

**Problem:** AOE loot enabled by default, but players don't know settings  
**Solution:** First-login AOE wizard

**Features:**
- On first login, show quick wizard:
  - "Enable AOE Looting?" Yes/No
  - "Minimum quality to loot?" Dropdown (Poor → Legendary)
  - "Auto-skin beasts?" Yes/No
  - "Loot range?" Slider (10-50 yards)
- Saves preferences immediately
- Can be changed later in DC-Central

### Enhancement 4: Progressive Feature Introduction

**Instead of info dump, staged unlocks:**

| Level | Feature Unlocked | Notification |
|-------|------------------|--------------|
| 1 | Welcome screen, basic FAQ | First login popup |
| 10 | Hotspots introduced | Chat message + addon marker |
| 20 | Prestige system preview | Brief explanation |
| 58 | Item Upgrade teaser | "Upgrade your gear at 80!" |
| 80 | Full Mythic+ unlock | Detailed M+ guide popup |
| 80 | Prestige full unlock | Prestige guide popup |

### Enhancement 5: Server Info FAQ Widget

**In-game accessible FAQ:**
- `/faq` or `/help dc` command
- Addon widget with common questions:
  - "How do I get a keystone?"
  - "What are prestige levels?"
  - "How does item upgrading work?"
  - "Where are the hotspots?"
- Links to more detailed guides (website or in-game)

### Enhancement 6: DC System Integration (Returning Player Detection)

**Problem:** New players don't know about DC features  
**Solution:** First-login tutorial introducing:
- Mythic+ system explanation
- Prestige system introduction
- Hotspot feature demo
- Item Upgrade preview

**Implementation:**
- Add `CustomLogin.DC.Tutorial.Enable`
- NPC dialogue or chat messages explaining DC features
- Optional starter keystone (level 2 or similar)
- Link to in-game help command

### Enhancement 6: DC System Integration (Returning Player Detection)

**Problem:** Existing players creating alts get same treatment as new  
**Solution:** Account-wide checks:
- If account has level 80 character → enhanced alt rewards
- Prestige integration → higher prestige = better alt bonuses
- Skip tutorial for experienced accounts

**Implementation:**
- Add `CustomLogin.AltDetection.Enable`
- Query `dc_player_profile` for account's max prestige
- Scale rewards based on account progression

### Enhancement 7: Faction-Specific Rewards

**Problem:** Generic rewards don't feel faction-appropriate  
**Solution:** Faction-themed packages:
- Alliance: Stormwind tabard, SW rep boost, human mount
- Horde: Orgrimmar tabard, Org rep boost, orc mount
- Racial-specific bag (herb bag for tauren, etc.)

**Implementation:**
- Add per-faction config sections
- `CustomLogin.Alliance.Mount`, `CustomLogin.Horde.Mount`

### Enhancement 4: Class Starter Kit

**Problem:** Some classes need special items to function  
**Solution:** Class-specific kits:
- Hunter: Ammo pouch + starter ammo
- Warlock: Soul bag + soul shards
- Rogue: Thieves' tools, poisons
- Mage: Reagents for portals
- Priest: Candles

**Implementation:**
- Expand existing class-specific config
- Add `CustomLogin.{Class}.StarterKit` items

### Enhancement 5: Progressive Welcome Experience

**Problem:** Overwhelming info dump on first login  
**Solution:** Staged introduction:
- Level 1-10: Basic game mechanics (existing WoW)
- Level 10: DC features unlock announcement
- Level 20: Hotspot introduction
- Level 80: Mythic+ unlock, Prestige intro

**Implementation:**
- Level-based triggers via PlayerScript
- Chat messages or NPC interactions at milestones
- Integration with DC addon for UI guidance

### Enhancement 6: Recruitment/Referral Integration

**Problem:** No friend referral rewards  
**Solution:** Recruiter system:
- Referred players get bonus rewards
- Referrer gets rewards when referee hits milestones
- Account-linked referral tracking

**Implementation:**
- New table `dc_recruitment`
- Custom command `.recruit <code>` or `.recruit create`

### Enhancement 7: Daily Login Rewards

**Problem:** mod-customlogin is first-login only  
**Solution:** Extend to daily rewards:
- Consecutive login tracking
- Escalating rewards (7-day streak = bonus)
- Monthly milestone rewards

**Implementation:**
- New table `dc_daily_login`
- Add `CustomLogin.DailyRewards.Enable`
- Config for day 1, 3, 7, 14, 28 rewards

### Enhancement 8: Server Introduction Video/NPC

**Problem:** Text isn't engaging for new players  
**Solution:** Interactive introduction:
- NPC that explains server features
- Links to Discord, website
- In-game "?" icon for help

**Implementation:**
- NPC script at starting zones
- Gossip menu with feature explanations
- URL links via addon or chat

## 🌐 Where Enhanced First-Start Exists

### Retail WoW (Exile's Reach)
- **Approach**: Dedicated starting zone
- **Features**: Class mechanics tutorial, story introduction
- **Duration**: ~30 minutes of guided content

### GW2 (Guild Wars 2)
- **Approach**: Level-based rewards, login rewards
- **Features**: Daily login calendar, progression milestones

### FFXIV
- **Approach**: Extensive MSQ introduction
- **Features**: Hall of the Novice, Mentor system

### Warmane (Private Server)
- **Approach**: Custom starting NPCs
- **Features**: Donation shop introduction, server rules

## 📺 YouTube Resources

| Topic | Search Terms |
|-------|--------------|
| **WoW New Player Experience** | "WoW Exile's Reach analysis", "New player onboarding" |
| **Player Retention** | "MMO onboarding best practices", "First time user experience" |
| **Private Server Features** | "Private server starter perks", "Fun server features" |

## ✅ Advantages

| Advantage | Impact |
|-----------|--------|
| **Immediate Gratification** | Players start with useful items |
| **Reduced Barrier** | Skip tedious early game |
| **Alt-Friendly** | Alts gear up faster |
| **DC Feature Discovery** | Players learn about custom systems |
| **Retention** | Daily login rewards encourage return |
| **Community Building** | Referral system grows playerbase |
| **Low Risk** | Module is fully modular, easy to tweak |

## ❌ Disadvantages

| Disadvantage | Mitigation |
|--------------|------------|
| **Economy Impact** | Carefully tune gold/item amounts |
| **"Pay to Skip" Feel** | Frame as QoL, not advantage |
| **Information Overload** | Progressive disclosure, staged intro |
| **Complexity Creep** | Keep config simple, good defaults |

## 🔧 AzerothCore Changes Required

### Core Changes: ❌ NONE Required
mod-customlogin is purely modular

### Configuration Extensions

```ini
# DC Integration
CustomLogin.DC.Tutorial.Enable = 1
CustomLogin.DC.Tutorial.StarterKeystone = 1
CustomLogin.DC.Tutorial.KeystoneLevel = 2

# Alt Detection
CustomLogin.AltDetection.Enable = 1
CustomLogin.AltDetection.PrestigeMultiplier = 1.0

# Daily Rewards
CustomLogin.DailyRewards.Enable = 1
CustomLogin.DailyRewards.Day1 = 500000  # 50 gold
CustomLogin.DailyRewards.Day7 = 2500000  # 250 gold
CustomLogin.DailyRewards.Day7.Item = 49426  # Emblem of Frost x5

# Recruitment
CustomLogin.Recruitment.Enable = 1
CustomLogin.Recruitment.ReferralReward = 49426  # Emblem

# Progressive Introduction
CustomLogin.Progressive.Enable = 1
CustomLogin.Progressive.Level10.Message = "DC Hotspots are now available!"
CustomLogin.Progressive.Level80.Message = "Mythic+ dungeons await!"
```

### Database Tables (New)

| Table | Purpose |
|-------|---------|
| `dc_daily_login` | Track consecutive logins, last login |
| `dc_recruitment` | Referral codes, referee tracking |
| `dc_first_login_progress` | Progressive tutorial stage |

## 📱 Client/Addon Requirements

### Optional: DC-WelcomeGuide Addon

| Feature | Description |
|---------|-------------|
| **Feature Tooltip** | Hover explanations for DC systems |
| **Tutorial Arrow** | Point to relevant NPCs/UI |
| **Progress Tracker** | Show introduction progress |
| **Login Reward UI** | Daily reward calendar display |

### AIO Integration

```
DC_WELCOME_TUTORIAL - Tutorial step messages
DC_DAILY_REWARD     - Daily login reward notification
DC_MILESTONE_HIT    - Progressive milestone achieved
```

## 📈 Effort Estimation (Expanded Scope)

| Phase | Duration | Focus |
|-------|----------|-------|
| **Phase 1** | 3-4 days | Install mod-customlogin, base config |
| **Phase 2** | 4-5 days | DC-Welcome addon (start screen) |
| **Phase 3** | 5-7 days | DC-Central addon (settings panel) |
| **Phase 4** | 3-4 days | First-start AOE loot wizard |
| **Phase 5** | 3-4 days | Daily login reward system |
| **Phase 6** | 3-4 days | Progressive introduction triggers |
| **Phase 7** | 2-3 days | Alt detection + prestige integration |

**Total: 3-5 weeks** (expanded scope with addons)

## 🔗 Integration with DC Systems

| DC System | Integration Point |
|-----------|-------------------|
| **Prestige** | Alt bonus scaling based on prestige level |
| **Mythic+** | Starter keystone grant at level 80 |
| **Seasons** | Season pass XP for first character creation |
| **Hotspots** | Introduction message at level 10 |
| **Leaderboards** | Track "newest players" |

---

# Available AzerothCore Modules (Already Integrated)

## Modules Already In Use by DarkChaos

### ✅ mod-autobalance (ALREADY IN USE)
**Repository:** https://github.com/azerothcore/mod-autobalance  
**Status:** ✅ Already integrated into DarkChaos

**What It Does:**
- Scales dungeon/raid difficulty based on player count
- Adjusts mob health, damage, and mana dynamically
- Per-instance configuration possible
- Works with any player count (1-40)

**Relevance to Raid Finder:**
- Critical for flex-scaling raids
- Allows smaller groups to do raids designed for 25
- Already integrated into AC core hooks

### ✅ mod-cfbg (ALREADY IN USE)
**Repository:** https://github.com/azerothcore/mod-cfbg  
**Status:** ✅ Already integrated into DarkChaos

**What It Does:**
- Allows Alliance and Horde in same BG team
- Balances faction populations for faster queues
- Item level checking for fair matches

**Relevance to Raid/M+ Finder:**
- Cross-faction logic already available
- Can leverage for cross-faction dungeon/raid queues

### ✅ mod-customlogin (ALREADY IN USE)
**Repository:** https://github.com/Brian-Aldridge/mod-customlogin  
**Status:** ✅ Already integrated into DarkChaos

**What It Does:**
- First-login rewards (gear, gold, mounts)
- Weapon skill grants
- Reputation configuration
- Class-specific item distribution

**Relevance to First-Start:**
- Base module already in place
- Extend via DC scripts, not module modifications
- Configuration already established

### ✅ Mythic+ Spectator (ALREADY IMPLEMENTED)
**Location:** `src/server/scripts/DC/MythicPlus/dc_mythic_spectator.cpp`  
**Status:** ✅ Custom DC implementation exists

**What It Does:**
- Live M+ run spectating
- Uses ArenaSpectator infrastructure
- Integrated with M+ system

**No additional module needed** - already part of DC scripts

## ⚠️ Development Approach: DC Scripts & Addons ONLY

**IMPORTANT:** All new features should be implemented as:
1. **DC C++ Scripts** (`src/server/scripts/DC/`)
2. **DC Lua/Eluna Scripts** (`Custom/Eluna scripts/`)
3. **DC Client Addons** (`Custom/Client addons needed/`)

**NOT as separate AzerothCore modules.**

This ensures:
- Centralized codebase management
- Consistent naming and architecture
- Easier deployment and updates
- No module dependency conflicts

## Features to Implement (DC Scripts/Addons)

| Feature | Type | Location |
|---------|------|----------|
| **Raid Finder Queue** | DC Script | `src/server/scripts/DC/RaidFinder/` |
| **M+ Group Finder** | DC Script + Addon | `DC/MythicPlus/` + `DC-MythicFinder/` |
| **Daily Login Rewards** | DC Script | `src/server/scripts/DC/DailyLogin/` |
| **Unified Player Profile** | DC Script | `src/server/scripts/DC/Integration/` |
| **DC-Central Addon** | Addon | `DC-Central/` |
| **DC-Welcome Addon** | Addon | `DC-Welcome/` |

---

# Implementation Priority Matrix

## Risk vs Reward Analysis

```
                    HIGH REWARD
                         │
    Cross-System         │         Raid/M+ Finder
    Integration          │
    (7-11 weeks)         │         (10-14 weeks)
         ●───────────────┼─────────────●
    LOWER               │          HIGHER
    RISK                │          RISK
         │               │
         │    First-Start Experience
         │         (3-5 weeks)
         │              ●
         │               │
                    LOW REWARD
```

## Recommended Implementation Order

### Order A: Quick Wins First (Recommended)

1. **First-Start Experience** (3-5 weeks)
   - Low risk, immediate player impact
   - Establishes DC-Central addon foundation
   - Sets up progressive introduction for other systems
   - Establishes account-level tracking

2. **Cross-System Integration** (7-11 weeks)
   - Foundational for future features
   - First-Start can use event bus for milestones
   - Unified profile enables alt detection

3. **Raid Finder + M+ Finder** (10-14 weeks)
   - Leverages unified profile for matchmaking
   - Uses event bus for queue notifications
   - First-Start introduces finder systems

### Order B: Foundation First (Alternative)

1. **Cross-System Integration** (7-11 weeks)
2. **Raid Finder + M+ Finder** (10-14 weeks)
3. **First-Start Script** (2-4 weeks)

**Rationale for Order A:**
- Delivers player-visible features earlier
- First-Start is low risk for testing integration patterns
- Cross-System can be built incrementally alongside other work

---

# Resources & References

## Official Repositories

| Resource | URL |
|----------|-----|
| **mod-customlogin** | https://github.com/Brian-Aldridge/mod-customlogin |
| **AzerothCore** | https://github.com/azerothcore/azerothcore-wotlk |
| **mod-aoe-loot** | https://github.com/azerothcore/mod-aoe-loot |
| **mod-progression-system** | https://github.com/azerothcore/mod-progression-system |

## AzerothCore Documentation

| Topic | Link |
|-------|------|
| **Module Development** | https://www.azerothcore.org/wiki/Create-a-Module |
| **Player Scripts** | https://www.azerothcore.org/wiki/hooks-script |
| **LFG System** | Examine `src/server/game/DungeonFinding/` |
| **Discord** | https://discord.gg/azerothcore |

## Private Server Research

| Server | Focus Area | URL |
|--------|------------|-----|
| **Warmane** | High-pop systems | https://www.warmane.com |
| **ChromieCraft** | Progressive content | https://www.chromiecraft.com |
| **Project Epoch** | Custom systems | Research closed-source approaches |

## Design References

| Topic | Platform |
|-------|----------|
| **Event Bus Pattern** | Game Programming Patterns book |
| **Player Retention** | GDC talks on onboarding |
| **Cross-System Design** | Path of Exile league mechanics |

## Existing DC Documentation

| Document | Location |
|----------|----------|
| **ADDON_PROTOCOL_ARCHITECTURE.md** | `Custom/feature stuff/` |
| **DC_NEW_SYSTEMS_IMPLEMENTATION.md** | `Custom/` |
| **DEEP_INVESTIGATION_6_SYSTEMS.md** | `Custom/feature stuff/Next steps to discuss/` |
| **SYSTEM_EVALUATION_DEEP_ANALYSIS.md** | `Custom/feature stuff/Next steps to discuss/` |
| **15_RAID_FINDER.md** | `Custom/feature stuff/FutureStuff/` |
| **11_CROSS_SYSTEM_INTEGRATION.md** | `Custom/feature stuff/FutureStuffExtension/` |

---

## Summary Decision Matrix

| Factor | First-Start | Cross-System | Raid/M+ Finder |
|--------|-------------|--------------|----------------|
| **Effort** | 3-5 weeks | 7-11 weeks | 10-14 weeks |
| **Risk** | ⭐ Low | ⭐⭐⭐ High | ⭐⭐ Medium |
| **Player Impact** | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Technical Value** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Prerequisites** | None | None | Ideally Cross-System |
| **Core Changes** | None | DC Scripts only | LFGMgr extension |
| **Addon Required** | Yes (DC-Central) | Yes | Yes |
| **3.3.5a Compatible** | ✅ 100% | ✅ 100% | ✅ 100% |

---

## Addon Architecture Summary

### DC Addon Ecosystem (All New Development)

| Addon | Purpose | Priority | Status |
|-------|---------|----------|--------|
| **DC-Central** | Hub for all DC addons, extensible | HIGH | NEW |
| **DC-Welcome** | Start screen, FAQ, Discord links | HIGH | NEW |
| **DC-MythicFinder** | M+ key browser, group apply | HIGH | NEW |
| **DC-ItemUpgrade** | Item upgrade UI | - | ✅ EXISTS |
| **DC-Leaderboards** | Leaderboards display | - | ✅ EXISTS |
| **DC-AOESettings** | AOE loot settings | - | ✅ EXISTS |
| **DC-Hotspot** | Hotspot tracking | - | ✅ EXISTS |
| **DC-TitleFix** | Title display fix | - | ✅ EXISTS |
| **DC-RaidFinder** | Raid queue overlay | MEDIUM | NEW |
| **DC-Calendar** | Scheduled raid browser | LOW | NEW |

### DC-Central Extensibility

```
DC-Central/
├── DC-Central.toc
├── Core.lua           # Main hub frame, tab system
├── AddonRegistry.lua  # Auto-discover DC addons
├── SettingsPanel.lua  # Unified settings
├── ProgressPanel.lua  # Unified progression
├── HelpPanel.lua      # FAQ/Documentation
├── API.lua            # Public API for addon registration
└── Locales/
    └── enUS.lua
```

**All existing DC addons should be updated to register with DC-Central.**

---

**Final Recommendation:**

Start with **First-Start Experience** (3-5 weeks) for quick player-facing value and DC-Central addon foundation, then build **Cross-System Integration** (7-11 weeks) as the technical foundation, and finally implement **Raid Finder + M+ Finder** (10-14 weeks) leveraging both previous systems.

This sequence delivers:
- Early player retention improvements
- Modern addon-based UI (DC-Central reduces command load)
- Clean architecture for future development  
- Comprehensive group-finding that uses unified data

**Total Development Time:** 20-30 weeks (5-8 months)

---

*Document prepared for DarkChaos-255 development planning*  
*Last Updated: November 30, 2025*
