# Jadeforest UI Components - Addon Extension Plan

This document outlines the technical plan for implementing the required UI components using the existing addon infrastructure.

## 1. Zone Welcome Panel & Tutorial Tracker (DC-QOS)

**Target Addon:** `DC-QOS`
**New Module:** `Modules/Jadeforest.lua`

**Features:**
- **Welcome Popup:** Triggers on `PLAYER_ENTERING_WORLD` when zone ID matches Jade Forest. Shows once per character (saved in SavedVariables).
- **Tutorial Tracker:** A movable frame showing progress of the "Welcome to Dark Chaos" questline.

**Implementation Details:**
- **RegisterModule:** Create a new module `DCQOS:RegisterModule("Jadeforest", ...)`
- **SavedVariables:** Use `DCQoSDB.jadeforest` to store `visited` flag and `tutorialProgress`.
- **Quest Tracking:** Listen for `QUEST_ACCEPTED` and `QUEST_TURNED_IN` events to update the tracker.

**Code Structure:**
```lua
local mod = DCQOS:RegisterModule("Jadeforest", { ... })

function mod:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD", self.CheckLocation)
    self:RegisterEvent("QUEST_TURNED_IN", self.UpdateTracker)
end

function mod:CheckLocation()
    if GetZoneText() == "The Jade Forest" and not self.db.visited then
         self:ShowWelcomePanel()
    end
end
```

## 2. Map Annotations (DC-Mapupgrades)

**Target Addon:** `DC-Mapupgrades`
**Modification:** `Pins.lua` or separate data injection

**Features:**
- **Static Pins:** Show icons for all 14 major hubs.
- **Tooltips:** Custom rich tooltips for each pin.

**Implementation Details:**
- **Hotspot Injection:** The cleanest way is to inject these pins into `Pins.state.hotspots` or use a new list `Pins.state.customPins` in `Pins.lua`.
- **Zone ID:** Map ID `870` (Jade Forest).

**Data Structure:**
```lua
local JADEFOREST_PINS = {
    { x=42.5, y=85.2, name="Paw'Don Village", icon="Interface\\Icons\\INV_Misc_Rune_01", type="Hub" },
    { x=55.1, y=45.3, name="Dawn's Blossom", icon="Interface\\Icons\\Spell_Holy_PrayerOfHealing", type="Social" },
    -- ...
}
```

## 3. Event Calendar & Timer (DC-InfoBar)

**Target Addon:** `DC-InfoBar`
**New Plugin:** `Plugins/Server/JadeEvents.lua`

**Features:**
- **Event Timer:** Shows "Fishing Derby: 20m" or "Next Event: 2h".
- **Calendar:** Tooltip showing weekly schedule.

**Implementation Details:**
- **Plugin:** Register via `DCInfoBar:RegisterPlugin(...)`.
- **Data Source:** Can rely on `DCAddonProtocol` for dynamic events, or a hardcoded schedule for fixed events (e.g. "Every Sunday at 3PM").

**Code Structure:**
```lua
local JadeEvents = { 
    id = "JadeEvents", 
    name = "Jade Events",
    icon = "Interface\\Icons\\Calendar_Icon",
    ... 
}

function JadeEvents:OnUpdate()
    -- Calculate time until next scheduled event
    -- Return text for info bar
end

DCInfoBar:RegisterPlugin(JadeEvents)
```

## 4. Teleporter & Flightmaster UI

**Target:** Server-side Gossip Scripts (C++)
**No Client Addon Required** (Interactive Gossip Menu)

- **Teleporter:** Uses `GossipMenu` with nicely formatted icons (using `|T...|t` in text).
- **Flightmaster:** Standard TaxiPath or custom Gossip menu if instant travel is desired.

## Summary of Work Required

| Component | Addon | Action | Complexity |
|-----------|-------|--------|------------|
| **Welcome Panel** | DC-QOS | New Module | Medium |
| **Tutorial Tracker** | DC-QOS | New Module | Medium |
| **Map Pins** | DC-Mapupgrades | Data Injection | Low |
| **Event Timer** | DC-InfoBar | New Plugin | Low |
| **Teleporter UI** | Core (C++) | C++ Script | Medium |

