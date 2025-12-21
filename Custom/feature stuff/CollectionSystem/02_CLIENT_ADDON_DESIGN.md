# Collection System - Client Addon Design

**Component:** WoW 3.3.5a Lua Addon  
**Dependencies:** DCAddonProtocol, Ace3 Libraries  
**Framework:** Plugin-based module system

---

## Overview

The client addon provides:
1. **Unified Collection Frame** - Single window with tabs for all collection types
2. **Shared Components** - Reusable grid, search, preview elements
3. **Module System** - Each collection type is a pluggable module
4. **DCAddonProtocol Integration** - JSON-based server communication
5. **Retail-Inspired UI** - Based on screenshot reference

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     DC-Collections Addon                         │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                 DCCollectionManager                       │   │
│  │  - Module registration                                    │   │
│  │  - State management                                       │   │
│  │  - Server communication                                   │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                   │
│      ┌───────────────────────┼───────────────────────┐          │
│      │                       │                       │          │
│  ┌───┴───┐              ┌────┴────┐            ┌────┴────┐     │
│  │ Mount │              │   Pet   │            │  Toy    │     │
│  │Module │              │ Module  │            │ Module  │     │
│  └───────┘              └─────────┘            └─────────┘     │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    Shared Components                      │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │   │
│  │  │GridView  │  │SearchBar │  │ModelView │  │TabBar    │  │   │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘  │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

---

## File Structure

```
DC-Collections/
├── DC-Collections.toc
├── embeds.xml                    -- Ace3 library loading
├── Core/
│   ├── CollectionManager.lua     -- Main manager singleton
│   ├── CollectionProtocol.lua    -- DCAddonProtocol integration
│   ├── CollectionModule.lua      -- Base module class
│   └── CollectionUtils.lua       -- Shared utilities
├── UI/
│   ├── CollectionFrame.lua       -- Main frame with tabs
│   ├── CollectionFrame.xml       -- Frame layout
│   ├── GridView.lua              -- Scrollable icon grid
│   ├── SearchBar.lua             -- Search/filter component
│   ├── ModelPreview.lua          -- 3D model display
│   ├── StatisticsPanel.lua       -- Collection stats
│   └── TooltipHooks.lua          -- Item tooltip integration
├── Modules/
│   ├── MountModule.lua           -- Mount collection
│   ├── PetModule.lua             -- Pet collection
│   ├── TransmogModule.lua        -- Transmog bridge
│   ├── ToyModule.lua             -- Toy collection
│   └── HeirloomModule.lua        -- Heirloom tracking
├── Locale/
│   ├── enUS.lua
│   └── deDE.lua
└── assets/
    ├── Collection-Tab-Mounts.blp
    ├── Collection-Tab-Pets.blp
    ├── Collection-Tab-Toys.blp
    ├── Collection-Tab-Transmog.blp
    ├── Collection-Grid-Slot.blp
    ├── Collection-Grid-Selected.blp
    ├── Collection-Favorite-Star.blp
    └── Collection-Rarity-Border.blp
```

---

## TOC File

```toc
## Interface: 30300
## Title: DC Collections
## Notes: Unified collection system for mounts, pets, toys, and more
## Version: 1.0.0
## Author: DarkChaos Development Team
## Dependencies: DC-AddonProtocol
## SavedVariables: DCCollectionsDB
## SavedVariablesPerCharacter: DCCollectionsCharDB

# Ace3 Libraries
embeds.xml

# Core
Core\CollectionUtils.lua
Core\CollectionModule.lua
Core\CollectionProtocol.lua
Core\CollectionManager.lua

# UI Components
UI\GridView.lua
UI\SearchBar.lua
UI\ModelPreview.lua
UI\StatisticsPanel.lua
UI\TooltipHooks.lua
UI\CollectionFrame.xml
UI\CollectionFrame.lua

# Collection Modules
Modules\MountModule.lua
Modules\PetModule.lua
Modules\TransmogModule.lua
Modules\ToyModule.lua
Modules\HeirloomModule.lua

# Localization
Locale\enUS.lua
Locale\deDE.lua
```

---

## Core Components

### CollectionManager.lua

```lua
--[[
    DCCollectionManager - Core manager for the collection system
    Handles module registration, state, and server communication
]]

local addonName, addon = ...
DCCollectionManager = {}
local CM = DCCollectionManager

-- Module registry
CM.modules = {}
CM.moduleOrder = {}  -- For tab ordering

-- State
CM.currentModule = nil
CM.isLoading = false
CM.accountData = {}

-- Configuration
CM.config = {
    gridColumns = 6,
    gridRows = 5,
    itemsPerPage = 30,
    cacheTimeout = 300,  -- 5 minutes
}

-- Saved variables defaults
local defaults = {
    global = {
        lastTab = "mount",
        favorites = {},
        settings = {
            autoSummonPet = false,
            randomMountOnLogin = false,
        }
    },
    char = {
        windowPosition = nil,
        windowScale = 1.0,
    }
}

-- ============================================================================
-- Module Registration
-- ============================================================================

function CM:RegisterModule(module)
    if not module or not module.type then
        error("DCCollections: Invalid module registration")
        return
    end
    
    self.modules[module.type] = module
    table.insert(self.moduleOrder, module.type)
    
    if DCAddonProtocol and DCAddonProtocol._debug then
        print("|cff00ccff[DCCollections]|r Registered module: " .. module.name)
    end
end

function CM:GetModule(moduleType)
    return self.modules[moduleType]
end

function CM:GetModuleList()
    local list = {}
    for _, type in ipairs(self.moduleOrder) do
        local mod = self.modules[type]
        if mod then
            table.insert(list, {
                type = type,
                name = mod.name,
                icon = mod.icon,
            })
        end
    end
    return list
end

-- ============================================================================
-- Server Communication (via DCAddonProtocol)
-- ============================================================================

function CM:RequestCollection(moduleType, page, filters)
    page = page or 1
    filters = filters or {}
    
    local request = {
        type = moduleType,
        page = page,
        limit = self.config.itemsPerPage,
    }
    
    -- Add filters
    if filters.search and filters.search ~= "" then
        request.query = filters.search
    end
    if filters.rarity then
        request.rarity = filters.rarity
    end
    if filters.source then
        request.source = filters.source
    end
    if filters.collected ~= nil then
        request.collected = filters.collected
    end
    
    DCAddonProtocol:Request("COLL", 0x01, request)
    self.isLoading = true
    
    -- Notify UI
    if DCCollectionFrame and DCCollectionFrame:IsShown() then
        DCCollectionFrame:ShowLoading()
    end
end

function CM:RequestCount(moduleType)
    DCAddonProtocol:Request("COLL", 0x02, { type = moduleType or "all" })
end

function CM:SetFavorite(moduleType, entryId, favorite)
    DCAddonProtocol:Request("COLL", 0x03, {
        type = moduleType,
        entryId = entryId,
        favorite = favorite,
    })
    
    -- Optimistic update
    local key = moduleType .. "_" .. entryId
    if favorite then
        self.db.global.favorites[key] = true
    else
        self.db.global.favorites[key] = nil
    end
end

function CM:UseCollectable(moduleType, entryId)
    DCAddonProtocol:Request("COLL", 0x04, {
        type = moduleType,
        entryId = entryId,
    })
end

function CM:RequestStatistics()
    DCAddonProtocol:Request("COLL", 0x05, {})
end

-- ============================================================================
-- Response Handlers
-- ============================================================================

local function OnCollectionData(data)
    CM.isLoading = false
    
    local moduleType = data.type
    local module = CM:GetModule(moduleType)
    if not module then return end
    
    -- Store data
    CM.accountData[moduleType] = {
        items = data.items or {},
        total = data.total or 0,
        collected = data.collected or 0,
        page = data.page or 1,
        pages = data.pages or 1,
        timestamp = time(),
    }
    
    -- Notify module
    if module.OnDataReceived then
        module:OnDataReceived(data)
    end
    
    -- Update UI
    if DCCollectionFrame and DCCollectionFrame:IsShown() then
        DCCollectionFrame:Refresh()
    end
end

local function OnCountData(data)
    if data.total then
        CM.totalCollected = data.total
    end
    
    -- Per-type counts
    for moduleType, count in pairs(data) do
        if moduleType ~= "total" and CM.modules[moduleType] then
            CM.modules[moduleType].cachedCount = count
        end
    end
    
    -- Update statistics panel
    if DCCollectionFrame and DCCollectionFrame.statsPanel then
        DCCollectionFrame.statsPanel:Update()
    end
end

local function OnItemLearned(data)
    local moduleType = data.type
    local module = CM:GetModule(moduleType)
    
    if module and module.OnItemLearned then
        module:OnItemLearned(data)
    end
    
    -- Show toast notification
    if DCCollectionFrame then
        DCCollectionFrame:ShowToast(data.name, data.icon, moduleType)
    end
    
    -- Invalidate cache
    if CM.accountData[moduleType] then
        CM.accountData[moduleType].timestamp = 0
    end
end

local function OnStatistics(data)
    CM.statistics = data
    
    if DCCollectionFrame and DCCollectionFrame.statsPanel then
        DCCollectionFrame.statsPanel:UpdateFull(data)
    end
end

local function OnError(data)
    CM.isLoading = false
    
    local errorMsg = data.message or "Unknown error"
    print("|cffff0000[DCCollections]|r Error: " .. errorMsg)
    
    if DCCollectionFrame and DCCollectionFrame:IsShown() then
        DCCollectionFrame:ShowError(errorMsg)
    end
end

-- Register handlers
local function RegisterProtocolHandlers()
    local DC = DCAddonProtocol
    
    DC:RegisterJSONHandler("COLL", 0x10, OnCollectionData)    -- SMSG_COLLECTION_DATA
    DC:RegisterJSONHandler("COLL", 0x11, OnCountData)         -- SMSG_COLLECTION_COUNT
    DC:RegisterJSONHandler("COLL", 0x12, OnItemLearned)       -- SMSG_ITEM_LEARNED
    DC:RegisterJSONHandler("COLL", 0x13, OnStatistics)        -- SMSG_STATISTICS
    DC:RegisterJSONHandler("COLL", 0x14, OnSearchResults)     -- SMSG_SEARCH_RESULTS
    DC:RegisterJSONHandler("COLL", 0x1F, OnError)             -- SMSG_ERROR
end

-- ============================================================================
-- Initialization
-- ============================================================================

local function OnAddonLoaded(self, event, arg1)
    if arg1 ~= addonName then return end
    
    -- Initialize saved variables
    CM.db = LibStub("AceDB-3.0"):New("DCCollectionsDB", defaults)
    
    -- Register protocol handlers
    RegisterProtocolHandlers()
    
    -- Register slash commands
    SLASH_DCCOLLECTIONS1 = "/collections"
    SLASH_DCCOLLECTIONS2 = "/coll"
    SLASH_DCCOLLECTIONS3 = "/mounts"
    SLASH_DCCOLLECTIONS4 = "/pets"
    SLASH_DCCOLLECTIONS5 = "/toys"
    SlashCmdList["DCCOLLECTIONS"] = function(msg)
        local cmd = string.lower(msg or "")
        if cmd == "mounts" or cmd == "mount" then
            CM:ShowCollection("mount")
        elseif cmd == "pets" or cmd == "pet" then
            CM:ShowCollection("pet")
        elseif cmd == "toys" or cmd == "toy" then
            CM:ShowCollection("toy")
        elseif cmd == "transmog" then
            CM:ShowCollection("transmog")
        else
            CM:Toggle()
        end
    end
    
    print("|cff00ccff[DCCollections]|r Loaded. Type /collections to open.")
end

local function OnPlayerLogin()
    -- Request initial counts
    CM:RequestCount("all")
    
    -- Restore last tab
    CM.currentModule = CM.db.global.lastTab or "mount"
end

-- Event frame
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        OnAddonLoaded(self, event, ...)
    elseif event == "PLAYER_LOGIN" then
        OnPlayerLogin()
    end
end)

-- ============================================================================
-- Public API
-- ============================================================================

function CM:Toggle()
    if DCCollectionFrame then
        if DCCollectionFrame:IsShown() then
            DCCollectionFrame:Hide()
        else
            DCCollectionFrame:Show()
            self:ShowCollection(self.currentModule or "mount")
        end
    end
end

function CM:ShowCollection(moduleType)
    if not self.modules[moduleType] then
        moduleType = "mount"  -- Default
    end
    
    self.currentModule = moduleType
    self.db.global.lastTab = moduleType
    
    if DCCollectionFrame then
        DCCollectionFrame:SetActiveTab(moduleType)
        
        -- Check cache
        local cached = self.accountData[moduleType]
        if cached and (time() - cached.timestamp) < self.config.cacheTimeout then
            DCCollectionFrame:Refresh()
        else
            self:RequestCollection(moduleType, 1)
        end
    end
end

function CM:IsFavorite(moduleType, entryId)
    local key = moduleType .. "_" .. entryId
    return self.db.global.favorites[key] == true
end

-- Export
addon.Manager = CM
_G["DCCollectionManager"] = CM
```

### CollectionModule.lua (Base Class)

```lua
--[[
    DCCollectionModule - Base class for collection modules
    Provides common functionality that modules can override
]]

local addonName, addon = ...

DCCollectionModule = {}
DCCollectionModule.__index = DCCollectionModule

function DCCollectionModule:New(config)
    local module = setmetatable({}, self)
    
    module.type = config.type          -- "mount", "pet", etc.
    module.name = config.name          -- Display name
    module.icon = config.icon          -- Tab icon path
    module.order = config.order or 99  -- Tab order
    
    module.cachedCount = 0
    module.data = {}
    
    return module
end

-- Override in subclasses
function DCCollectionModule:GetDisplayName(entry)
    return entry.name or "Unknown"
end

function DCCollectionModule:GetIcon(entry)
    return entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end

function DCCollectionModule:GetTooltipInfo(entry)
    return {
        name = entry.name,
        rarity = entry.rarity,
        source = entry.source,
        collected = entry.collected,
    }
end

function DCCollectionModule:CanUse(entry)
    return entry.isUsable ~= false
end

function DCCollectionModule:Use(entry)
    DCCollectionManager:UseCollectable(self.type, entry.entryId)
end

function DCCollectionModule:OnDataReceived(data)
    self.data = data.items or {}
    self.cachedCount = data.collected or #self.data
end

function DCCollectionModule:OnItemLearned(data)
    -- Override for custom behavior
end

-- Get filter options for this module
function DCCollectionModule:GetFilterOptions()
    return {
        { type = "collected", label = "Collected", values = {
            { value = nil, label = "All" },
            { value = true, label = "Collected" },
            { value = false, label = "Not Collected" },
        }},
        { type = "rarity", label = "Rarity", values = {
            { value = nil, label = "All" },
            { value = 0, label = "Common" },
            { value = 1, label = "Uncommon" },
            { value = 2, label = "Rare" },
            { value = 3, label = "Epic" },
            { value = 4, label = "Legendary" },
        }},
    }
end

-- Get source filter options (module-specific)
function DCCollectionModule:GetSourceFilters()
    return {}  -- Override in subclass
end

addon.CollectionModule = DCCollectionModule
```

### MountModule.lua

```lua
--[[
    Mount Collection Module
    Handles mount-specific collection features
]]

local addonName, addon = ...
local L = addon.L or {}

local MountModule = addon.CollectionModule:New({
    type = "mount",
    name = L["Mounts"] or "Mounts",
    icon = "Interface\\Icons\\Ability_Mount_RidingHorse",
    order = 1,
})

-- Mount type constants
MountModule.MOUNT_TYPE_GROUND = 0
MountModule.MOUNT_TYPE_FLYING = 1
MountModule.MOUNT_TYPE_AQUATIC = 2
MountModule.MOUNT_TYPE_ALL = 3

-- ============================================================================
-- Mount-Specific Methods
-- ============================================================================

function MountModule:GetDisplayName(entry)
    return entry.name or GetSpellInfo(entry.spellId) or "Unknown Mount"
end

function MountModule:GetIcon(entry)
    if entry.icon then
        return entry.icon
    end
    -- Try to get icon from spell
    if entry.spellId then
        local _, _, icon = GetSpellInfo(entry.spellId)
        return icon or "Interface\\Icons\\Ability_Mount_RidingHorse"
    end
    return "Interface\\Icons\\Ability_Mount_RidingHorse"
end

function MountModule:Use(entry)
    if entry.spellId then
        -- Request server to cast mount spell
        DCAddonProtocol:Request("COLL", 0x10, { spellId = entry.spellId })
    end
end

function MountModule:SummonRandom(favoritesOnly)
    DCAddonProtocol:Request("COLL", 0x11, { favoritesOnly = favoritesOnly or false })
end

function MountModule:GetSourceFilters()
    return {
        { value = "", label = L["All Sources"] or "All Sources" },
        { value = "drop", label = L["Drops"] or "Drops" },
        { value = "vendor", label = L["Vendors"] or "Vendors" },
        { value = "achievement", label = L["Achievements"] or "Achievements" },
        { value = "quest", label = L["Quests"] or "Quests" },
        { value = "profession", label = L["Professions"] or "Professions" },
        { value = "event", label = L["Events"] or "Events" },
        { value = "promotion", label = L["Promotion"] or "Promotion" },
    }
end

function MountModule:GetFilterOptions()
    local baseFilters = addon.CollectionModule.GetFilterOptions(self)
    
    -- Add mount-specific filters
    table.insert(baseFilters, {
        type = "mountType",
        label = L["Type"] or "Type",
        values = {
            { value = nil, label = L["All"] or "All" },
            { value = 0, label = L["Ground"] or "Ground" },
            { value = 1, label = L["Flying"] or "Flying" },
            { value = 2, label = L["Aquatic"] or "Aquatic" },
        }
    })
    
    return baseFilters
end

function MountModule:GetTooltipInfo(entry)
    local info = addon.CollectionModule.GetTooltipInfo(self, entry)
    
    -- Add mount-specific info
    info.mountType = entry.mountType
    info.speed = entry.speed or 100
    
    if entry.source then
        -- Parse source JSON
        -- info.sourceDetails = ...
    end
    
    return info
end

function MountModule:OnItemLearned(data)
    -- Play mount-specific sound
    PlaySound("AchievementMenuOpen", "sfx")
    
    -- Show special toast for rare mounts
    if data.rarity and data.rarity >= 3 then
        -- Epic or better - special announcement
        UIErrorsFrame:AddMessage(
            string.format("|cffff8000New Mount:|r %s", data.name), 
            1.0, 0.5, 0
        )
    end
end

-- Smart random mount - considers flying vs ground
function MountModule:GetSmartRandomRequest()
    local canFly = IsFlyableArea and IsFlyableArea() or false
    return {
        favoritesOnly = DCCollectionManager.db.global.settings.randomFavoritesOnly or false,
        preferFlying = canFly,
    }
end

-- ============================================================================
-- Register Module
-- ============================================================================

DCCollectionManager:RegisterModule(MountModule)
addon.MountModule = MountModule
```

---

## UI Components

### GridView.lua

```lua
--[[
    DCCollectionGridView - Scrollable grid of collection items
    Reusable component for all collection types
]]

local addonName, addon = ...

DCCollectionGridView = {}
DCCollectionGridView.__index = DCCollectionGridView

local SLOT_SIZE = 48
local SLOT_PADDING = 4
local SLOT_SPACING = 6

function DCCollectionGridView:Create(parent, config)
    local grid = setmetatable({}, self)
    
    config = config or {}
    grid.columns = config.columns or 6
    grid.rows = config.rows or 5
    grid.slotSize = config.slotSize or SLOT_SIZE
    grid.spacing = config.spacing or SLOT_SPACING
    
    grid.items = {}
    grid.buttons = {}
    grid.selectedIndex = nil
    grid.onSelect = config.onSelect
    grid.onUse = config.onUse
    
    -- Create main frame
    local width = (grid.slotSize + grid.spacing) * grid.columns
    local height = (grid.slotSize + grid.spacing) * grid.rows
    
    grid.frame = CreateFrame("Frame", nil, parent)
    grid.frame:SetSize(width, height)
    
    -- Create scroll frame
    grid.scrollFrame = CreateFrame("ScrollFrame", nil, grid.frame, "FauxScrollFrameTemplate")
    grid.scrollFrame:SetPoint("TOPLEFT")
    grid.scrollFrame:SetPoint("BOTTOMRIGHT", -22, 0)
    grid.scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, grid.slotSize + grid.spacing, function()
            grid:Refresh()
        end)
    end)
    
    -- Create content frame
    grid.content = CreateFrame("Frame", nil, grid.scrollFrame)
    grid.content:SetSize(width - 22, height)
    grid.scrollFrame:SetScrollChild(grid.content)
    
    -- Create button pool
    grid:CreateButtons()
    
    return grid
end

function DCCollectionGridView:CreateButtons()
    local totalButtons = self.columns * self.rows
    
    for i = 1, totalButtons do
        local row = math.floor((i - 1) / self.columns)
        local col = (i - 1) % self.columns
        
        local btn = CreateFrame("Button", nil, self.content)
        btn:SetSize(self.slotSize, self.slotSize)
        btn:SetPoint("TOPLEFT", 
            col * (self.slotSize + self.spacing),
            -row * (self.slotSize + self.spacing))
        
        -- Background
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.bg:SetTexture("Interface\\AddOns\\DC-Collections\\assets\\Collection-Grid-Slot")
        
        -- Icon
        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.icon:SetPoint("TOPLEFT", 3, -3)
        btn.icon:SetPoint("BOTTOMRIGHT", -3, 3)
        
        -- Rarity border
        btn.rarityBorder = btn:CreateTexture(nil, "OVERLAY")
        btn.rarityBorder:SetAllPoints()
        btn.rarityBorder:SetTexture("Interface\\AddOns\\DC-Collections\\assets\\Collection-Rarity-Border")
        btn.rarityBorder:Hide()
        
        -- Favorite star
        btn.favoriteStar = btn:CreateTexture(nil, "OVERLAY", nil, 1)
        btn.favoriteStar:SetSize(16, 16)
        btn.favoriteStar:SetPoint("TOPRIGHT", -2, -2)
        btn.favoriteStar:SetTexture("Interface\\AddOns\\DC-Collections\\assets\\Collection-Favorite-Star")
        btn.favoriteStar:Hide()
        
        -- Selected highlight
        btn.selected = btn:CreateTexture(nil, "OVERLAY", nil, 2)
        btn.selected:SetAllPoints()
        btn.selected:SetTexture("Interface\\AddOns\\DC-Collections\\assets\\Collection-Grid-Selected")
        btn.selected:Hide()
        
        -- Not collected overlay
        btn.notCollected = btn:CreateTexture(nil, "OVERLAY")
        btn.notCollected:SetAllPoints()
        btn.notCollected:SetColorTexture(0, 0, 0, 0.6)
        btn.notCollected:Hide()
        
        -- Scripts
        btn:SetScript("OnClick", function(self, button)
            if button == "LeftButton" then
                if IsControlKeyDown() then
                    -- Toggle favorite
                    local entry = self.entry
                    if entry and entry.collected then
                        local isFav = DCCollectionManager:IsFavorite(entry.type, entry.entryId)
                        DCCollectionManager:SetFavorite(entry.type, entry.entryId, not isFav)
                    end
                elseif self.grid.onSelect then
                    self.grid:Select(self.index)
                end
            elseif button == "RightButton" then
                -- Use/summon
                if self.entry and self.entry.collected and self.grid.onUse then
                    self.grid.onUse(self.entry)
                end
            end
        end)
        
        btn:SetScript("OnEnter", function(self)
            if self.entry then
                self.grid:ShowTooltip(self, self.entry)
            end
        end)
        
        btn:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
        
        btn.grid = self
        btn.index = i
        self.buttons[i] = btn
    end
end

function DCCollectionGridView:SetItems(items)
    self.items = items or {}
    self:Refresh()
end

function DCCollectionGridView:Refresh()
    local offset = FauxScrollFrame_GetOffset(self.scrollFrame)
    local totalItems = #self.items
    local visibleButtons = self.columns * self.rows
    
    for i, btn in ipairs(self.buttons) do
        local itemIndex = offset * self.columns + i
        local entry = self.items[itemIndex]
        
        if entry then
            btn.entry = entry
            btn.icon:SetTexture(entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            
            -- Collected state
            if entry.collected then
                btn.icon:SetDesaturated(false)
                btn.notCollected:Hide()
            else
                btn.icon:SetDesaturated(true)
                btn.notCollected:Show()
            end
            
            -- Rarity border
            local rarityColor = self:GetRarityColor(entry.rarity)
            if rarityColor then
                btn.rarityBorder:SetVertexColor(unpack(rarityColor))
                btn.rarityBorder:Show()
            else
                btn.rarityBorder:Hide()
            end
            
            -- Favorite
            if entry.isFavorite then
                btn.favoriteStar:Show()
            else
                btn.favoriteStar:Hide()
            end
            
            -- Selected
            if self.selectedIndex == itemIndex then
                btn.selected:Show()
            else
                btn.selected:Hide()
            end
            
            btn:Show()
        else
            btn.entry = nil
            btn:Hide()
        end
    end
    
    -- Update scroll bar
    local totalRows = math.ceil(totalItems / self.columns)
    FauxScrollFrame_Update(self.scrollFrame, totalRows, self.rows, self.slotSize + self.spacing)
end

function DCCollectionGridView:Select(index)
    self.selectedIndex = index
    self:Refresh()
    
    if self.onSelect and self.items[index] then
        self.onSelect(self.items[index])
    end
end

function DCCollectionGridView:GetRarityColor(rarity)
    local colors = {
        [0] = {0.6, 0.6, 0.6, 1},     -- Common (gray)
        [1] = {0.12, 1, 0, 1},        -- Uncommon (green)
        [2] = {0, 0.44, 0.87, 1},     -- Rare (blue)
        [3] = {0.64, 0.21, 0.93, 1},  -- Epic (purple)
        [4] = {1, 0.5, 0, 1},         -- Legendary (orange)
    }
    return colors[rarity]
end

function DCCollectionGridView:ShowTooltip(button, entry)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    
    -- Name with rarity color
    local rarityColor = self:GetRarityColor(entry.rarity) or {1, 1, 1, 1}
    GameTooltip:AddLine(entry.name, rarityColor[1], rarityColor[2], rarityColor[3])
    
    -- Source
    if entry.source then
        GameTooltip:AddLine(entry.source, 1, 0.82, 0)
    end
    
    -- Collection status
    if entry.collected then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Collected", 0, 1, 0)
        if entry.obtainedDate then
            GameTooltip:AddLine("Obtained: " .. date("%Y-%m-%d", entry.obtainedDate), 0.5, 0.5, 0.5)
        end
    else
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Not Collected", 1, 0, 0)
    end
    
    -- Usage hint
    if entry.collected then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cff00ff00Right-click to use|r")
        GameTooltip:AddLine("|cff00ff00Ctrl+click to favorite|r")
    end
    
    GameTooltip:Show()
end

addon.GridView = DCCollectionGridView
```

---

## Transmog Bridge Module

```lua
--[[
    Transmog Bridge Module
    Bridges existing Transmogrification addon with the collection system
    Does NOT replace the Transmogrification addon - just provides collection view
]]

local addonName, addon = ...
local L = addon.L or {}

local TransmogModule = addon.CollectionModule:New({
    type = "transmog",
    name = L["Appearances"] or "Appearances",
    icon = "Interface\\Icons\\INV_Misc_Desecrated_ClothHelm",
    order = 4,
})

-- Slot mapping (matches existing transmog addon)
TransmogModule.slotFilters = {
    { id = 1, name = L["Head"] or "Head", icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Head" },
    { id = 3, name = L["Shoulder"] or "Shoulder", icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Shoulder" },
    { id = 5, name = L["Chest"] or "Chest", icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Chest" },
    { id = 6, name = L["Waist"] or "Waist", icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Waist" },
    { id = 7, name = L["Legs"] or "Legs", icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Legs" },
    { id = 8, name = L["Feet"] or "Feet", icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Feet" },
    { id = 9, name = L["Wrist"] or "Wrist", icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Wrists" },
    { id = 10, name = L["Hands"] or "Hands", icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Hands" },
    { id = 15, name = L["Back"] or "Back", icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Chest" },
    { id = 16, name = L["Main Hand"] or "Main Hand", icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-MainHand" },
    { id = 17, name = L["Off Hand"] or "Off Hand", icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-SecondaryHand" },
}

function TransmogModule:GetFilterOptions()
    local baseFilters = addon.CollectionModule.GetFilterOptions(self)
    
    -- Add slot filter
    local slotValues = {{ value = nil, label = L["All Slots"] or "All Slots" }}
    for _, slot in ipairs(self.slotFilters) do
        table.insert(slotValues, { value = slot.id, label = slot.name })
    end
    
    table.insert(baseFilters, 1, {
        type = "slot",
        label = L["Slot"] or "Slot",
        values = slotValues
    })
    
    return baseFilters
end

function TransmogModule:GetIcon(entry)
    if entry.itemId then
        return GetItemIcon(entry.itemId) or "Interface\\Icons\\INV_Misc_QuestionMark"
    end
    return entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end

function TransmogModule:Use(entry)
    -- Open transmog window if available, or show preview
    if TransmogrificationFrame then
        if not TransmogrificationFrame:IsShown() then
            -- Trigger transmog window open
            if Transmogrification and Transmogrification.HandleSlashCommand then
                Transmogrification:HandleSlashCommand("")
            end
        end
        
        -- Try to select the item in transmog window
        -- This depends on existing transmog addon implementation
    end
end

function TransmogModule:IsCollected(itemId)
    -- Check existing CollectedAppearances table from Transmogrification addon
    if CollectedAppearances and type(CollectedAppearances) == "table" then
        for _, id in ipairs(CollectedAppearances) do
            if id == itemId then
                return true
            end
        end
    end
    return false
end

function TransmogModule:OnDataReceived(data)
    -- Merge with local CollectedAppearances
    addon.CollectionModule.OnDataReceived(self, data)
    
    -- Mark items as collected based on local table
    if data.items then
        for _, item in ipairs(data.items) do
            if self:IsCollected(item.itemId) then
                item.collected = true
            end
        end
    end
end

-- ============================================================================
-- Register Module
-- ============================================================================

DCCollectionManager:RegisterModule(TransmogModule)
addon.TransmogModule = TransmogModule
```

---

## Summary

| Component | Purpose | Reusability |
|-----------|---------|-------------|
| CollectionManager | Central state/communication | Core |
| CollectionModule | Base class for modules | Inherited |
| GridView | Scrollable icon grid | 100% shared |
| SearchBar | Filter/search | 100% shared |
| ModelPreview | 3D preview | 95% shared |
| MountModule | Mount-specific logic | Mount only |
| PetModule | Pet-specific logic | Pet only |
| TransmogModule | Bridge to existing | Transmog only |

**Key Design Decisions:**
1. **Plugin Architecture** - New collection types = new module file
2. **DCAddonProtocol** - Unified JSON messaging
3. **Ace3 Libraries** - Proven, stable framework
4. **Transmog Bridge** - Works alongside existing addon
5. **Retail-Inspired UI** - Familiar to players
