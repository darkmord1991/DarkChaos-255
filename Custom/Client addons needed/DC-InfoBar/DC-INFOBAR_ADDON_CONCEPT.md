# DC-InfoBar - Server Information Panel Addon

## ✅ IMPLEMENTATION STATUS: COMPLETE

This addon has been fully implemented. See file structure below.

---

## 🎯 Overview

**DC-InfoBar** is a Titan Panel-inspired information bar addon for DarkChaos-255 that displays server-specific data, player statistics, and useful at-a-glance information in a non-intrusive horizontal bar at the top of the screen.

### Key Features

- **Lightweight**: Single-purpose addon focused on DC server features
- **Integrated**: Communicates with server via DCAddonProtocol
- **Modern**: Clean, minimal UI inspired by retail WoW design
- **Server-Aware**: Shows seasonal data, Mythic+ info, world boss timers
- **Fully Configurable**: Interface > AddOns settings with multiple tabs
- **Repositionable**: Choose top or bottom bar position

---

## 📐 UI Design

### Bar Layout

```
┌──────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ [◆ Season 3] │ [⚔ +15 Key] │ [📍 Giant Isles] │ [⏱ Oondasta: 2h 15m] │ ... │ [💰 12,450g] │ [🔧 87%] │
└──────────────────────────────────────────────────────────────────────────────────────────────────────┘
│<-- LEFT SIDE (Server/Custom Data) ----------------------------------->│<-- RIGHT SIDE (Standard) -->│
```

### Visual Specifications

| Property | Value |
|----------|-------|
| Height | 22-24 pixels |
| Background | Semi-transparent dark (#0A0A0C, 85% opacity) |
| Text Color | Light gray (#CCCCCC) for labels, white (#FFFFFF) for values |
| Accent Color | Cyan (#32C4FF) for highlights, Yellow (#FFD100) for warnings |
| Font | Game font small (GameFontNormalSmall) |
| Separator | Vertical line (1px, #333333) |
| Position | Top of screen, below minimap/buffs |

---

## 🧩 Plugin System

DC-InfoBar uses a modular plugin system similar to Titan Panel. Each plugin is a self-contained module that registers with the core framework.

### Plugin Types

1. **Text Plugins** - Display text with optional icon (left-aligned)
2. **Icon Plugins** - Display only icon with tooltip (right-aligned)
3. **Combo Plugins** - Icon + text together

### Plugin Registration

```lua
-- Plugin structure
local MyPlugin = {
    id = "DCInfoBar_MyPlugin",          -- Unique identifier
    name = "My Plugin",                  -- Display name
    category = "server",                 -- server, character, combat, misc
    type = "text",                       -- text, icon, combo
    side = "left",                       -- left, right
    priority = 100,                      -- Sort order (lower = more left)
    
    -- Update function called periodically
    OnUpdate = function(self, elapsed)
        return "Label: ", "Value"        -- Return label, value pairs
    end,
    
    -- Tooltip function
    OnTooltip = function(self, tooltip)
        tooltip:AddLine("Plugin Tooltip")
    end,
    
    -- Click handler
    OnClick = function(self, button)
        if button == "LeftButton" then
            -- Do something
        end
    end,
    
    -- Saved variables
    savedVars = {
        enabled = true,
        showLabel = true,
        showIcon = true,
    },
    
    -- Update interval in seconds
    updateInterval = 1.0,
}

DCInfoBar:RegisterPlugin(MyPlugin)
```

---

## 📦 Core Plugins

### LEFT SIDE - Server/Custom Data

#### 1. **Seasonal Info** (`DCInfoBar_Season`)
```
Category: server
Priority: 10
Icon: Interface\Icons\Achievement_Arena_2v2_1
```

**Display:**
- Current season number and name
- Season progress (if tracked)
- Seasonal tokens earned this week

**Tooltip:**
```
Season 3: Primal Fury
━━━━━━━━━━━━━━━━━━━━
Weekly Tokens: 127 / 500 (cap)
Weekly Essence: 45 / 200 (cap)
Total This Season: 2,450 tokens

Season Ends: 14 days
Weekly Reset: Tuesday 15:00
```

**Click:**
- Left: Open DC-Seasons panel
- Right: Show season leaderboard

**Server Communication:**
```lua
-- Request seasonal data
DC:Send("SEASON", CMSG_GET_PLAYER_SEASON_INFO)

-- Receive updates
DC:RegisterHandler("SEASON", SMSG_PLAYER_SEASON_INFO, function(data)
    -- data.seasonId, data.weeklyTokens, data.weeklyCap, etc.
end)
```

---

#### 2. **Mythic+ Keystone** (`DCInfoBar_Keystone`)
```
Category: server
Priority: 20
Icon: Interface\Icons\INV_Relics_IdolofHealth
```

**Display:**
- Current keystone dungeon abbreviation + level
- "No Key" if none
- Depleted indicator if applicable

**Examples:**
- `+15 UK` (Utgarde Keep +15)
- `+8 HoL` (Halls of Lightning +8)
- `No Key`
- `+12 UK ⚠` (Depleted)

**Tooltip:**
```
Mythic+ Keystone
━━━━━━━━━━━━━━━━━━━━
Current: Utgarde Keep +15
Affixes: Fortified, Bursting, Storming

Best This Week:
• Utgarde Keep +16 (2 chest)
• Halls of Lightning +14 (1 chest)

Weekly Best: +16
Season Best: +22

Click to open Group Finder
```

**Click:**
- Left: Open DC-MythicPlus Group Finder
- Right: Link keystone in chat

---

#### 3. **Location/Zone** (`DCInfoBar_Location`)
```
Category: character
Priority: 30
Icon: Interface\Icons\INV_Misc_Map01
```

**Display:**
- Current zone name (abbreviated if long)
- Subzone if in custom content zones
- Coordinates optional

**Examples:**
- `Giant Isles` (custom zone)
- `Dalaran (55, 72)`
- `Ulduar` (instance)

**Tooltip:**
```
Location
━━━━━━━━━━━━━━━━━━━━
Zone: Giant Isles
Subzone: Warden's Landing
Coordinates: 45.6, 32.1

Zone Type: Custom World Content
Active Events: Zandalari Invasion

Click to copy coordinates
```

**Click:**
- Left: Copy coordinates to clipboard
- Right: Open world map

---

#### 4. **World Boss Timers** (`DCInfoBar_WorldBoss`)
```
Category: server
Priority: 40
Icon: Interface\Icons\INV_Misc_Head_Dragon_01
```

**Display:**
- Next spawning world boss + time remaining
- Or "Active" if boss is currently up
- Cycles through multiple bosses

**Examples:**
- `Oondasta: 2h 15m`
- `Thok: Active!`
- `Nalak: Tomorrow`

**Tooltip:**
```
World Boss Timers
━━━━━━━━━━━━━━━━━━━━
Giant Isles:
  • Oondasta: Spawns in 2h 15m
  • Thok: Active (85% HP)
  • Nalak: Spawns in 5h 30m

Wintergrasp:
  • Archavon: Available after battle

Click to open Group Finder
```

**Click:**
- Left: Open World Content tab in Group Finder
- Shift+Left: Create/join world boss group

---

#### 5. **Active Affixes** (`DCInfoBar_Affixes`)
```
Category: server
Priority: 50
Icon: Interface\Icons\Spell_Nature_WispSplode
```

**Display:**
- Current week's affix icons (3 small icons)
- Or abbreviated text: `Fort/Burst/Storm`

**Tooltip:**
```
Weekly Affixes
━━━━━━━━━━━━━━━━━━━━
[Icon] Fortified
  Non-boss enemies have 20% more health
  and deal 30% more damage.

[Icon] Bursting
  When slain, non-boss enemies explode,
  dealing damage equal to 10% max HP.

[Icon] Storming
  Enemies periodically create damaging
  whirlwinds that move around.

Resets: Tuesday 15:00 (3 days)
```

**Click:**
- Left: Show affix details popup
- Right: Link affixes in chat

---

#### 6. **Zone Events** (`DCInfoBar_Events`)
```
Category: server
Priority: 60
Icon: Interface\Icons\Ability_Warrior_BattleShout
```

**Display:**
- Active zone event (if any)
- Time remaining for event
- Hidden if no active events

**Examples:**
- `Invasion: Wave 2/4`
- `Rift Event: 4:32`
- `Stampede: 12:00`
- (hidden if no events)

**Tooltip:**
```
Zone Events
━━━━━━━━━━━━━━━━━━━━
ACTIVE: Zandalari Invasion
  Location: Warden's Landing
  Wave: 2 of 4
  Enemies Remaining: 15
  Time in Wave: 2:45

Next Events:
  • Chaos Rift: ~45 minutes
  • Primal Stampede: ~2 hours

Click to teleport to event
```

**Click:**
- Left: Open quick-join for event
- Right: Teleport to event (if available)

---

### RIGHT SIDE - Standard Info

#### 7. **Gold** (`DCInfoBar_Gold`)
```
Category: character
Priority: 900
Side: right
Icon: Interface\Icons\INV_Misc_Coin_01
```

**Display:**
- Current gold amount (abbreviated)
- Color coded: Yellow (normal), Green (gained), Red (lost)

**Examples:**
- `12,450g` (12,450 gold)
- `2.1M` (2,100,000+ gold)
- `+250g` (recent gain, green)

**Tooltip:**
```
Gold
━━━━━━━━━━━━━━━━━━━━
Current: 12,450g 32s 15c

Session:
  Started With: 12,200g
  Gained: 450g
  Spent: 200g
  Net: +250g

This Character: 12,450g
All Characters: 245,320g

Click for details
```

**Click:**
- Left: Toggle show/hide silver and copper
- Right: Show all characters gold

---

#### 8. **Durability/Repair** (`DCInfoBar_Durability`)
```
Category: character
Priority: 910
Side: right
Icon: Interface\Icons\Trade_BlackSmithing
```

**Display:**
- Lowest durability percentage
- Color coded: Green (>50%), Yellow (25-50%), Red (<25%)

**Examples:**
- `87%` (green)
- `45%` (yellow)
- `12%` (red, flashing)

**Tooltip:**
```
Equipment Durability
━━━━━━━━━━━━━━━━━━━━
Head:        95% ████████░░
Shoulders:   87% ████████░░
Chest:       92% █████████░
Hands:       45% ████░░░░░░  ⚠
Legs:        88% ████████░░
Feet:        90% █████████░
Weapon:      78% ███████░░░
Shield:      82% ████████░░

Lowest: 45% (Hands)
Repair Cost: 12g 45s

Click to auto-repair (if at vendor)
```

**Click:**
- Left: If at vendor, repair all
- Right: Show breakdown popup

---

#### 9. **Bag Space** (`DCInfoBar_Bags`)
```
Category: character
Priority: 920
Side: right
Icon: Interface\Icons\INV_Misc_Bag_08
```

**Display:**
- Free bag slots / Total slots
- Color coded by remaining space

**Examples:**
- `45/120` (green, plenty of space)
- `15/120` (yellow, getting full)
- `3/120` (red, almost full)

**Tooltip:**
```
Bag Space
━━━━━━━━━━━━━━━━━━━━
Backpack:       8/16 free
Frostweave Bag: 12/20 free
Frostweave Bag: 10/20 free
Glacial Bag:    15/22 free
Glacial Bag:    0/22 free

Total: 45/100 slots free

Special Bags:
Ammo Pouch:     200/200
Herb Bag:       8/32 free

Click to open all bags
```

**Click:**
- Left: Open all bags
- Right: Sort bags (if addon available)

---

#### 10. **Performance** (`DCInfoBar_Performance`)
```
Category: misc
Priority: 930
Side: right
Icon: Interface\Icons\Spell_Nature_TimeStop
```

**Display:**
- FPS and latency
- Color coded by quality

**Examples:**
- `60 fps 45ms` (green)
- `30 fps 150ms` (yellow fps, yellow ms)
- `15 fps 500ms` (red both)

**Tooltip:**
```
Performance
━━━━━━━━━━━━━━━━━━━━
Framerate: 60 fps
Latency: 45 ms (Home) / 52 ms (World)

Memory Usage:
  Total: 128 MB
  DC-InfoBar: 0.5 MB
  DC-MythicPlus: 2.1 MB
  ...

Garbage Collection: 0.02 sec

Left-click to force garbage collection
```

**Click:**
- Left: Force garbage collection
- Right: Show memory breakdown

---

#### 11. **Clock** (`DCInfoBar_Clock`)
```
Category: misc
Priority: 999 (always rightmost)
Side: right
Icon: None (text only)
```

**Display:**
- Server time or local time
- Optional date

**Examples:**
- `15:42` (24h format)
- `3:42 PM` (12h format)

**Tooltip:**
```
Time
━━━━━━━━━━━━━━━━━━━━
Server Time: 15:42:30
Local Time: 16:42:30
UTC: 14:42:30

Date: Friday, December 6, 2025

Daily Reset: 8 hours
Weekly Reset: 4 days, 16 hours

Click to toggle format
```

**Click:**
- Left: Toggle 12h/24h format
- Right: Toggle server/local time

---

## 🔧 Additional Plugins (Future)

### Combat/Performance
| Plugin | Display | Description |
|--------|---------|-------------|
| `DPS/HPS Meter` | `12.5K DPS` | Current combat DPS |
| `Threat` | `85% Threat` | Current threat level |
| `Combat Timer` | `2:45` | Time in combat |

### Character
| Plugin | Display | Description |
|--------|---------|-------------|
| `XP` | `45% (2.1M/4.6M)` | Experience progress |
| `Honor` | `1,250 Honor` | Current honor points |
| `Arena` | `1850 (3v3)` | Arena rating |
| `Ammo` | `1,234 Arrows` | Ammo count (hunter/rogue) |
| `Regen` | `+500 HP/5` | Health/mana regen rates |

### Server-Specific
| Plugin | Display | Description |
|--------|---------|-------------|
| `Prestige` | `P3 ★★★` | Prestige level |
| `Rep` | `Revered` | Tracked reputation |
| `Tokens` | `127 Tokens` | Seasonal tokens |
| `Chest` | `Ready!` | Weekly chest status |
| `Queue` | `DPS: 12m` | Dungeon/BG queue |

---

## 📁 File Structure

```
DC-InfoBar/
├── DC-InfoBar.toc
├── Core.lua                    # Main framework, plugin system
├── Settings.lua                # Saved variables, options
├── Utils.lua                   # Helper functions
├── UI/
│   ├── Bar.lua                 # Main bar frame
│   ├── Plugin.lua              # Plugin button template
│   ├── Tooltip.lua             # Enhanced tooltip system
│   └── Options.lua             # Options panel
├── Plugins/
│   ├── Server/
│   │   ├── Season.lua          # Seasonal info
│   │   ├── Keystone.lua        # M+ keystone
│   │   ├── WorldBoss.lua       # World boss timers
│   │   ├── Affixes.lua         # Weekly affixes
│   │   └── Events.lua          # Zone events
│   ├── Character/
│   │   ├── Location.lua        # Zone/coords
│   │   ├── Gold.lua            # Gold tracker
│   │   ├── Durability.lua      # Repair status
│   │   └── Bags.lua            # Bag space
│   └── Misc/
│       ├── Performance.lua     # FPS/Latency
│       └── Clock.lua           # Time/Date
└── Libs/
    └── (embedded if needed)
```

---

## 📜 TOC File

```toc
## Interface: 30300
## Title: DC-InfoBar
## Notes: Server information bar for DarkChaos-255
## Author: DarkChaos Development Team
## Version: 1.0.0
## SavedVariables: DCInfoBarDB
## Dependencies: DCAddonProtocol

Libs\embeds.xml

Utils.lua
Core.lua
Settings.lua

UI\Bar.lua
UI\Plugin.lua
UI\Tooltip.lua
UI\Options.lua

Plugins\Server\Season.lua
Plugins\Server\Keystone.lua
Plugins\Server\WorldBoss.lua
Plugins\Server\Affixes.lua
Plugins\Server\Events.lua

Plugins\Character\Location.lua
Plugins\Character\Gold.lua
Plugins\Character\Durability.lua
Plugins\Character\Bags.lua

Plugins\Misc\Performance.lua
Plugins\Misc\Clock.lua
```

---

## 🔌 Core.lua Implementation Outline

```lua
-- DC-InfoBar Core Framework
local addonName = "DC-InfoBar"
local DCInfoBar = {}
_G.DCInfoBar = DCInfoBar

-- Configuration
DCInfoBar.BAR_HEIGHT = 22
DCInfoBar.BACKGROUND_COLOR = { 0.04, 0.04, 0.05, 0.85 }
DCInfoBar.UPDATE_INTERVAL = 0.5

-- Plugin registry
DCInfoBar.plugins = {}
DCInfoBar.activePlugins = { left = {}, right = {} }

-- Saved variables reference
DCInfoBarDB = DCInfoBarDB or {}

-- ============================================================
-- Plugin Registration
-- ============================================================

function DCInfoBar:RegisterPlugin(plugin)
    if not plugin.id then
        error("Plugin must have an id")
        return
    end
    
    -- Set defaults
    plugin.side = plugin.side or "left"
    plugin.priority = plugin.priority or 500
    plugin.type = plugin.type or "text"
    plugin.updateInterval = plugin.updateInterval or 1.0
    plugin.enabled = true
    
    -- Store in registry
    self.plugins[plugin.id] = plugin
    
    -- Add to active list if enabled
    if self:IsPluginEnabled(plugin.id) then
        self:ActivatePlugin(plugin.id)
    end
end

function DCInfoBar:ActivatePlugin(pluginId)
    local plugin = self.plugins[pluginId]
    if not plugin then return end
    
    local side = plugin.side
    table.insert(self.activePlugins[side], plugin)
    
    -- Sort by priority
    table.sort(self.activePlugins[side], function(a, b)
        return a.priority < b.priority
    end)
    
    -- Create button for plugin
    self:CreatePluginButton(plugin)
    
    -- Refresh bar layout
    self:RefreshLayout()
end

function DCInfoBar:CreatePluginButton(plugin)
    local bar = self.bar
    local button = CreateFrame("Button", plugin.id .. "Button", bar)
    button.plugin = plugin
    
    -- Background (hover highlight)
    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetAllPoints()
    button.bg:SetColorTexture(0.1, 0.1, 0.12, 0)
    
    -- Icon (if combo or icon type)
    if plugin.type ~= "text" and plugin.icon then
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetSize(16, 16)
        button.icon:SetPoint("LEFT", 4, 0)
        button.icon:SetTexture(plugin.icon)
    end
    
    -- Text
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    if button.icon then
        button.text:SetPoint("LEFT", button.icon, "RIGHT", 4, 0)
    else
        button.text:SetPoint("LEFT", 6, 0)
    end
    
    -- Separator
    button.separator = button:CreateTexture(nil, "ARTWORK")
    button.separator:SetSize(1, 16)
    button.separator:SetPoint("RIGHT", 0, 0)
    button.separator:SetColorTexture(0.2, 0.2, 0.25, 0.5)
    
    -- Event handlers
    button:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(0.1, 0.1, 0.12, 0.5)
        DCInfoBar:ShowPluginTooltip(self.plugin)
    end)
    
    button:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(0.1, 0.1, 0.12, 0)
        GameTooltip:Hide()
    end)
    
    button:SetScript("OnClick", function(self, btn)
        if self.plugin.OnClick then
            self.plugin.OnClick(self.plugin, btn)
        end
    end)
    
    plugin.button = button
end

-- ============================================================
-- Bar Creation
-- ============================================================

function DCInfoBar:CreateBar()
    local bar = CreateFrame("Frame", "DCInfoBarFrame", UIParent)
    bar:SetHeight(self.BAR_HEIGHT)
    bar:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    bar:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0)
    bar:SetFrameStrata("HIGH")
    
    -- Background
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.bg:SetColorTexture(unpack(self.BACKGROUND_COLOR))
    
    -- Bottom border line
    bar.border = bar:CreateTexture(nil, "ARTWORK")
    bar.border:SetPoint("BOTTOMLEFT", 0, 0)
    bar.border:SetPoint("BOTTOMRIGHT", 0, 0)
    bar.border:SetHeight(1)
    bar.border:SetColorTexture(0.2, 0.5, 0.8, 0.5)
    
    self.bar = bar
    return bar
end

-- ============================================================
-- Update System
-- ============================================================

function DCInfoBar:OnUpdate(elapsed)
    for _, plugin in pairs(self.plugins) do
        if plugin.enabled and plugin.button then
            plugin._elapsed = (plugin._elapsed or 0) + elapsed
            
            if plugin._elapsed >= plugin.updateInterval then
                plugin._elapsed = 0
                
                if plugin.OnUpdate then
                    local label, value = plugin.OnUpdate(plugin, elapsed)
                    self:UpdatePluginText(plugin, label, value)
                end
            end
        end
    end
end

function DCInfoBar:UpdatePluginText(plugin, label, value)
    if not plugin.button then return end
    
    local text = ""
    if label and self:GetPluginVar(plugin.id, "showLabel") ~= false then
        text = "|cff888888" .. label .. "|r"
    end
    if value then
        text = text .. "|cffffffff" .. value .. "|r"
    end
    
    plugin.button.text:SetText(text)
    
    -- Auto-size button
    local width = plugin.button.text:GetStringWidth() + 12
    if plugin.button.icon then
        width = width + 20
    end
    plugin.button:SetWidth(width)
end

-- ============================================================
-- Initialization
-- ============================================================

function DCInfoBar:Initialize()
    self:CreateBar()
    
    -- Create update frame
    local updateFrame = CreateFrame("Frame")
    updateFrame:SetScript("OnUpdate", function(_, elapsed)
        DCInfoBar:OnUpdate(elapsed)
    end)
    
    -- Register with DCAddonProtocol
    local DC = rawget(_G, "DCAddonProtocol")
    if DC then
        DC:RegisterHandler("INFOBAR", 0x01, function(data)
            -- Handle server updates
        end)
    end
    
    self.Print("DC-InfoBar initialized")
end

-- Initialize on load
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    DCInfoBar:Initialize()
end)
```

---

## ⚙️ Settings & Configuration

### Saved Variables Structure

```lua
DCInfoBarDB = {
    -- Global settings
    global = {
        barPosition = "top",         -- top, bottom
        barHeight = 22,
        showBackground = true,
        backgroundColor = { 0.04, 0.04, 0.05, 0.85 },
        locked = true,
    },
    
    -- Per-character settings
    char = {
        plugins = {
            ["DCInfoBar_Season"] = {
                enabled = true,
                showLabel = true,
                showIcon = true,
            },
            ["DCInfoBar_Gold"] = {
                enabled = true,
                showLabel = false,
                showSilverCopper = false,
            },
            -- ...
        },
        pluginOrder = {
            left = { "Season", "Keystone", "Location", "WorldBoss", "Affixes" },
            right = { "Gold", "Durability", "Bags", "Performance", "Clock" },
        },
    },
}
```

### Slash Commands

```
/infobar              - Toggle bar visibility
/infobar options      - Open options panel
/infobar reset        - Reset to defaults
/infobar enable <id>  - Enable plugin
/infobar disable <id> - Disable plugin
```

---

## 🔗 Server-Side Integration

### DCAddonProtocol Messages

| Opcode | Direction | Description |
|--------|-----------|-------------|
| 0x01 | S→C | Season info update |
| 0x02 | S→C | Keystone info update |
| 0x03 | S→C | World boss timers |
| 0x04 | S→C | Weekly affixes |
| 0x05 | S→C | Zone event status |
| 0x10 | C→S | Request all info |
| 0x11 | C→S | Request specific info |

### C++ Server Hook Example

```cpp
// In dc_addon_infobar.cpp

class DCInfoBarPlayerScript : public PlayerScript
{
public:
    void OnLogin(Player* player) override
    {
        // Send initial info bar data on login
        SendSeasonInfo(player);
        SendKeystoneInfo(player);
        SendWorldBossTimers(player);
        SendAffixInfo(player);
    }

    void OnUpdateZone(Player* player, uint32 /*oldZone*/, uint32 newZone) override
    {
        // Update zone-specific info
        SendZoneEventStatus(player, newZone);
    }
};
```

---

## 📊 Implementation Priority

### Phase 1: Core Framework
1. Bar creation and positioning
2. Plugin registration system
3. Basic update loop
4. Settings saving/loading

### Phase 2: Essential Plugins
1. Clock (simple, test plugin system)
2. Gold (character data)
3. Bags (character data)
4. Durability (character data)
5. Performance (FPS/latency)
6. Location (zone info)

### Phase 3: Server Integration
1. Season plugin (requires DCAddonProtocol)
2. Keystone plugin (requires server data)
3. Affixes plugin (requires server data)

### Phase 4: Advanced Plugins
1. World Boss timers
2. Zone Events
3. Additional character plugins

### Phase 5: Polish
1. Options panel
2. Drag-and-drop reordering
3. Multiple bar support
4. Profiles

---

## 🎨 Visual Reference

```
Standard View (Top Bar):
┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│ ◆ S3: Primal │ +15 UK │ 📍 Giant Isles │ ⏱ Oondasta: 2h │ ⚔ Fort/Burst │ ... │ 12,450g │ 87% │ 45/120 │ 60fps 45ms │ 15:42 │
└──────────────────────────────────────────────────────────────────────────────────────────────┘

Compact View:
┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│ S3 │ +15 │ Giant Isles │ Oondasta: 2h │ 12K │ 87% │ 45 │ 60/45 │ 15:42 │
└──────────────────────────────────────────────────────────────────────────────────────────────┘

Event Active (Highlighted):
┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│ ◆ S3 │ +15 UK │ 📍 Giant Isles │ |cFFFF0000⚔ INVASION: Wave 2/4|r │ ... │ 15:42 │
└──────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## ✅ Summary

DC-InfoBar provides:

1. **Server Features** - Season info, keystones, affixes, world boss timers, zone events
2. **Character Data** - Gold, durability, bag space, location
3. **System Info** - FPS, latency, memory, clock
4. **Extensibility** - Easy plugin API for future additions
5. **Integration** - Works with DCAddonProtocol for server data
6. **Customization** - Per-plugin settings, show/hide labels, reposition bar

---

## 📁 Implemented File Structure

```
DC-InfoBar/
├── DC-InfoBar.toc              ✅ Created
├── DC-INFOBAR_ADDON_CONCEPT.md ✅ This file
├── Core.lua                    ✅ Created - Plugin system, server comm
├── Settings.lua                ✅ Created - SavedVariables, defaults
├── Utils.lua                   ✅ Created - Helper functions, polyfills
│
├── UI/
│   ├── Bar.lua                 ✅ Created - Main bar, plugin buttons
│   ├── Tooltip.lua             ✅ Created - Enhanced tooltips
│   └── Options.lua             ✅ Created - Interface > AddOns panel
│
└── Plugins/
    ├── Server/
    │   ├── Season.lua          ✅ Created - DCAddonProtocol SEAS
    │   ├── Keystone.lua        ✅ Created - DCAddonProtocol GRPF/MPLUS
    │   ├── Affixes.lua         ✅ Created - Weekly M+ affixes
    │   ├── WorldBoss.lua       ✅ Created - Boss spawn timers
    │   └── Events.lua          ✅ Created - Zone events (invasions)
    │
    ├── Character/
    │   ├── Location.lua        ✅ Created - GetZoneText, GetPlayerMapPosition
    │   ├── Gold.lua            ✅ Created - GetMoney, session tracking
    │   ├── Durability.lua      ✅ Created - GetInventoryItemDurability
    │   └── Bags.lua            ✅ Created - GetContainerNumFreeSlots
    │
    └── Misc/
        ├── Performance.lua     ✅ Created - GetFramerate, GetNetStats
        └── Clock.lua           ✅ Created - GetGameTime, date()
```

---

## ⚙️ Options Panel (Interface > AddOns)

The addon includes a full settings panel accessible via:
- Interface > AddOns > DC-InfoBar
- `/infobar` or `/dcinfo` or `/dcib`

### Tab 1: General
- Enable/Disable addon
- Hide in combat
- Hide in instances
- Show/hide labels globally
- Show/hide icons globally
- Reset to defaults button

### Tab 2: Plugins
- Enable/disable each plugin individually
- Choose side (Left/Right) for each plugin
- Per-plugin options button for specific settings:
  - Season: Show tokens in bar
  - Keystone: Show depleted indicator
  - Affixes: Use abbreviated text
  - Location: Show coordinates, show subzone
  - Gold: Show silver/copper, color on change
  - Durability: Flash when low, show repair cost
  - Bags: Show as percentage, warn when full
  - Performance: Show FPS/Latency/Memory toggles
  - Clock: 12h/24h format, seconds, date, server time

### Tab 3: Position
- Bar position: Top or Bottom of screen
- Show background toggle
- Background opacity slider (0-100%)
- Bar height slider (18-32 pixels)

### Tab 4: Communication
- Connection status display
- Debug options:
  - Show debug messages in chat
  - Log server requests
  - Log server responses
  - Use test/mock data mode
- Refresh Server Data button
- Current server data display panel

---

## 🔌 Data Sources Summary

| Plugin | Data Source | API/Protocol |
|--------|-------------|--------------|
| Season | Server | DCAddonProtocol `SEAS` module |
| Keystone | Server | DCAddonProtocol `GRPF`/`MPLUS` |
| Affixes | Server | Via Keystone or separate message |
| WorldBoss | Server | Custom DCAddonProtocol message |
| Events | Server | Custom DCAddonProtocol message |
| Location | Client | `GetZoneText()`, `GetSubZoneText()`, `GetPlayerMapPosition()` |
| Gold | Client | `GetMoney()` |
| Durability | Client | `GetInventoryItemDurability(slot)` |
| Bags | Client | `GetContainerNumSlots()`, `GetContainerNumFreeSlots()` |
| Performance | Client | `GetFramerate()`, `GetNetStats()`, `GetAddOnMemoryUsage()` |
| Clock | Client | `GetGameTime()`, `date()` |

---

## 🎮 Slash Commands

```
/infobar              - Open options panel
/infobar toggle       - Show/hide bar
/infobar reset        - Reset to defaults  
/infobar debug        - Toggle debug mode
/infobar refresh      - Refresh server data
```

---

*Document Version: 2.0 - Implementation Complete*
*Created: December 2025*
*For: DarkChaos-255 Server*
