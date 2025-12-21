--[[
    DC-Collection Core.lua
    ======================
    
    Main addon initialization, settings, and slash commands.
    Handles DCAddonProtocol integration and event management.
    
    Author: DarkChaos-255
    Version: 1.0.0
]]

-- Global namespace
DCCollection = DCCollection or {}
local DC = DCCollection
local L = DC.L

-- ============================================================================
-- VERSION & CONSTANTS
-- ============================================================================

DC.VERSION = "1.0.0"
DC.MODULE_ID = "COLL"  -- DCAddonProtocol module identifier

-- Collection types
DC.CollectionType = {
    MOUNT = "mount",
    PET = "pet",
    TOY = "toy",
    HEIRLOOM = "heirloom",
    TRANSMOG = "transmog",
    TITLE = "title",
}

-- Rarity colors
DC.RarityColors = {
    [0] = { r = 0.62, g = 0.62, b = 0.62, hex = "|cff9d9d9d" },  -- Poor/Common
    [1] = { r = 1.00, g = 1.00, b = 1.00, hex = "|cffffffff" },  -- Common
    [2] = { r = 0.12, g = 1.00, b = 0.00, hex = "|cff1eff00" },  -- Uncommon
    [3] = { r = 0.00, g = 0.44, b = 0.87, hex = "|cff0070dd" },  -- Rare
    [4] = { r = 0.64, g = 0.21, b = 0.93, hex = "|cffa335ee" },  -- Epic
    [5] = { r = 1.00, g = 0.50, b = 0.00, hex = "|cffff8000" },  -- Legendary
}

-- Mount types
DC.MountType = {
    GROUND = 0,
    FLYING = 1,
    AQUATIC = 2,
    ALL = 3,
}

-- ============================================================================
-- SAVED VARIABLES DEFAULTS
-- ============================================================================

local defaults = {
    -- Display settings
    showMinimapButton = true,
    minimapButtonAngle = 180,
    showCollectionNotifications = true,
    showWishlistAlerts = true,
    playSounds = true,
    
    -- Filter settings
    defaultFilter = "all",
    rememberFilters = true,
    
    -- Grid settings
    gridColumns = 5,
    gridIconSize = 48,
    showTooltips = true,
    
    -- Communication
    enableServerSync = true,
    debugMode = false,
    
    -- Cache
    lastSyncTime = 0,
    syncVersion = 0,
}

local charDefaults = {
    -- Last viewed tab per character
    lastTab = "mounts",
    
    -- Filter states (if rememberFilters)
    filters = {},
    
    -- UI state
    framePosition = nil,
}

-- ============================================================================
-- COLLECTION DATA
-- ============================================================================

-- Cached collection data
DC.collections = {
    mounts = {},
    pets = {},
    toys = {},
    heirlooms = {},
    transmog = {},
    titles = {},
}

-- Definition data (from server)
DC.definitions = {
    mounts = {},
    pets = {},
    toys = {},
    heirlooms = {},
}

-- Statistics
DC.stats = {
    mounts = { owned = 0, total = 0 },
    pets = { owned = 0, total = 0 },
    toys = { owned = 0, total = 0 },
    heirlooms = { owned = 0, total = 0 },
    transmog = { owned = 0, total = 0 },
    titles = { owned = 0, total = 0 },
}

-- Currency
DC.currency = {
    tokens = 0,
    emblems = 0,
}

-- Wishlist
DC.wishlist = {}

-- Mount speed bonus
DC.mountSpeedBonus = 0

-- ============================================================================
-- STATE MANAGEMENT
-- ============================================================================

DC.isLoaded = false
DC.isDataReady = false
DC.pendingRequests = {}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

function DC:Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC-Collection]|r " .. tostring(msg or ""))
    end
end

function DC:Debug(msg)
    if DCCollectionDB and DCCollectionDB.debugMode then
        self:Print("|cff888888[Debug]|r " .. tostring(msg or ""))
    end
end

function DC:GetRarityColor(rarity)
    return self.RarityColors[rarity] or self.RarityColors[0]
end

function DC:FormatNumber(num)
    if not num then return "0" end
    if num >= 1000000 then
        return string.format("%.1fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.1fK", num / 1000)
    end
    return tostring(num)
end

function DC:FormatCurrency(tokens, emblems)
    local parts = {}
    if tokens and tokens > 0 then
        table.insert(parts, "|cffffd700" .. self:FormatNumber(tokens) .. "|r " .. L.CURRENCY_TOKENS)
    end
    if emblems and emblems > 0 then
        table.insert(parts, "|cffa335ee" .. self:FormatNumber(emblems) .. "|r " .. L.CURRENCY_EMBLEMS)
    end
    return table.concat(parts, " + ")
end

-- ============================================================================
-- SETTINGS MANAGEMENT
-- ============================================================================

function DC:LoadSettings()
    -- Account-wide settings
    DCCollectionDB = DCCollectionDB or {}
    for key, value in pairs(defaults) do
        if DCCollectionDB[key] == nil then
            DCCollectionDB[key] = value
        end
    end
    
    -- Character-specific settings
    DCCollectionCharDB = DCCollectionCharDB or {}
    for key, value in pairs(charDefaults) do
        if DCCollectionCharDB[key] == nil then
            DCCollectionCharDB[key] = value
        end
    end
end

function DC:SaveSetting(key, value, isCharacter)
    if isCharacter then
        DCCollectionCharDB = DCCollectionCharDB or {}
        DCCollectionCharDB[key] = value
    else
        DCCollectionDB = DCCollectionDB or {}
        DCCollectionDB[key] = value
    end
end

function DC:GetSetting(key, isCharacter)
    if isCharacter then
        return DCCollectionCharDB and DCCollectionCharDB[key]
    else
        return DCCollectionDB and DCCollectionDB[key]
    end
end

-- ============================================================================
-- COLLECTION DATA ACCESS
-- ============================================================================

function DC:GetCollectionCount(collectionType)
    local stats = self.stats[collectionType]
    if stats then
        return stats.owned, stats.total
    end
    return 0, 0
end

function DC:GetTotalCount()
    local owned, total = 0, 0
    for _, stats in pairs(self.stats) do
        owned = owned + stats.owned
        total = total + stats.total
    end
    return owned, total
end

function DC:IsCollected(collectionType, id)
    local collection = self.collections[collectionType]
    return collection and collection[id] ~= nil
end

function DC:IsFavorite(collectionType, id)
    local collection = self.collections[collectionType]
    local item = collection and collection[id]
    return item and item.is_favorite
end

function DC:IsOnWishlist(collectionType, id)
    for _, item in ipairs(self.wishlist) do
        if item.collection_type == collectionType and item.item_id == id then
            return true
        end
    end
    return false
end

-- ============================================================================
-- MAIN FRAME TOGGLE
-- ============================================================================

function DC:Toggle()
    if self.MainFrame then
        if self.MainFrame:IsShown() then
            self.MainFrame:Hide()
        else
            self.MainFrame:Show()
        end
    else
        self:CreateMainFrame()
        if self.MainFrame then
            self.MainFrame:Show()
        end
    end
end

function DC:Show()
    if not self.MainFrame then
        self:CreateMainFrame()
    end
    if self.MainFrame then
        self.MainFrame:Show()
    end
end

function DC:Hide()
    if self.MainFrame then
        self.MainFrame:Hide()
    end
end

function DC:OpenTab(tabName)
    self:Show()
    if self.MainFrame and self.MainFrame.SelectTab then
        self.MainFrame:SelectTab(tabName)
    end
end

function DC:OpenSettings()
    -- Open Interface Options panel
    if self.optionsPanel then
        InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
        InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)  -- WoW bug workaround
    else
        self:Print("Settings panel not yet implemented. Use /dcc debug to toggle debug mode.")
    end
end

-- ============================================================================
-- SLASH COMMANDS
-- ============================================================================

SLASH_DCCOLLECTION1 = "/dccollection"
SLASH_DCCOLLECTION2 = "/dcc"
SLASH_DCCOLLECTION3 = "/collection"

SlashCmdList["DCCOLLECTION"] = function(msg)
    local cmd = string.lower(msg or "")
    
    if cmd == "" or cmd == "show" then
        DC:Toggle()
    elseif cmd == "mounts" then
        DC:OpenTab("mounts")
    elseif cmd == "pets" then
        DC:OpenTab("pets")
    elseif cmd == "toys" then
        DC:OpenTab("toys")
    elseif cmd == "heirlooms" then
        DC:OpenTab("heirlooms")
    elseif cmd == "transmog" then
        DC:OpenTab("transmog")
    elseif cmd == "titles" then
        DC:OpenTab("titles")
    elseif cmd == "shop" then
        DC:OpenTab("shop")
    elseif cmd == "wishlist" then
        DC:OpenTab("wishlist")
    elseif cmd == "sync" then
        DC:Print("Requesting full sync from server...")
        DC:RequestFullSync()
    elseif cmd == "debug" then
        DCCollectionDB.debugMode = not DCCollectionDB.debugMode
        DC:Print("Debug mode: " .. (DCCollectionDB.debugMode and "ON" or "OFF"))
    elseif cmd == "stats" then
        local owned, total = DC:GetTotalCount()
        DC:Print("Collection Statistics:")
        DC:Print(string.format("  Mounts: %d / %d", DC.stats.mounts.owned, DC.stats.mounts.total))
        DC:Print(string.format("  Pets: %d / %d", DC.stats.pets.owned, DC.stats.pets.total))
        DC:Print(string.format("  Toys: %d / %d", DC.stats.toys.owned, DC.stats.toys.total))
        DC:Print(string.format("  Heirlooms: %d / %d", DC.stats.heirlooms.owned, DC.stats.heirlooms.total))
        DC:Print(string.format("  Total: %d / %d (%.1f%%)", owned, total, total > 0 and (owned/total*100) or 0))
        DC:Print(string.format("  Mount Speed Bonus: +%d%%", DC.mountSpeedBonus))
    elseif cmd == "currency" then
        DC:Print("Currency: " .. DC:FormatCurrency(DC.currency.tokens, DC.currency.emblems))
    elseif cmd == "help" then
        DC:Print("Available commands:")
        DC:Print("  /dcc - Toggle collection window")
        DC:Print("  /dcc mounts|pets|toys|heirlooms|transmog|titles - Open specific tab")
        DC:Print("  /dcc shop - Open collection shop")
        DC:Print("  /dcc wishlist - Open wishlist")
        DC:Print("  /dcc sync - Request full data sync")
        DC:Print("  /dcc stats - Show collection statistics")
        DC:Print("  /dcc currency - Show current currency")
        DC:Print("  /dcc debug - Toggle debug mode")
    else
        DC:Print("Unknown command. Type /dcc help for a list of commands.")
    end
end

-- ============================================================================
-- EVENT HANDLING
-- ============================================================================

local eventFrame = CreateFrame("Frame", "DCCollectionEventFrame", UIParent)
local events = {}

function events:ADDON_LOADED(addonName)
    if addonName == "DC-Collection" then
        DC:LoadSettings()
        DC:InitializeCache()
        DC:InitializeProtocol()
        
        DC.isLoaded = true
        DC:Print(string.format(L.ADDON_LOADED, DC.VERSION))
        
        -- Request initial data after a short delay
        C_Timer.After(2, function()
            if DC:IsProtocolReady() then
                DC:RequestInitialData()
            end
        end)
    end
end

function events:PLAYER_LOGIN()
    -- Apply mount speed bonus on login
    DC:ApplyMountSpeedBonus()
end

function events:PLAYER_LOGOUT()
    -- Save any pending data
    DC:SaveCache()
end

function events:COMPANION_LEARNED()
    -- A mount or pet was learned
    DC:Debug("COMPANION_LEARNED event")
    DC:RequestCollectionUpdate(DC.CollectionType.MOUNT)
    DC:RequestCollectionUpdate(DC.CollectionType.PET)
end

function events:COMPANION_UPDATE(companionType)
    DC:Debug("COMPANION_UPDATE: " .. tostring(companionType))
end

function events:KNOWN_TITLES_UPDATE()
    DC:Debug("KNOWN_TITLES_UPDATE event")
    -- Titles changed, refresh if needed
end

-- Register events
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if events[event] then
        events[event](self, ...)
    end
end)

for event in pairs(events) do
    eventFrame:RegisterEvent(event)
end

-- ============================================================================
-- INITIALIZATION HELPERS
-- ============================================================================

function DC:InitializeCache()
    -- Load cached data from SavedVariables
    if self.LoadCache then
        self:LoadCache()
    end
end

function DC:InitializeProtocol()
    -- Initialize DCAddonProtocol communication
    if self.SetupProtocol then
        self:SetupProtocol()
    end
end

function DC:IsProtocolReady()
    -- Check if we can communicate with server
    return DCAddonProtocol ~= nil and DCAddonProtocol.IsReady and DCAddonProtocol:IsReady()
end

function DC:RequestInitialData()
    DC:Debug("Requesting initial collection data...")
    
    -- Request currency first
    self:RequestCurrency()
    
    -- Request collection counts
    self:RequestStats()
    
    -- Request definitions (for uncollected items)
    self:RequestDefinitions()
    
    -- Request player collections
    self:RequestCollections()
    
    -- Request shop data
    self:RequestShopData()
end

function DC:RequestFullSync()
    -- Force a complete resync
    DCCollectionDB.lastSyncTime = 0
    DCCollectionDB.syncVersion = 0
    self:RequestInitialData()
end

-- Placeholder functions (implemented in Protocol.lua)
function DC:RequestCurrency() end
function DC:RequestStats() end
function DC:RequestDefinitions() end
function DC:RequestCollections() end
function DC:RequestShopData() end
function DC:RequestCollectionUpdate(collectionType) end

-- Placeholder for mount speed bonus (implemented in Bonuses.lua)
function DC:ApplyMountSpeedBonus() end

-- Placeholder for main frame creation (implemented in UI/MainFrame.lua)
function DC:CreateMainFrame() end

-- Placeholder for cache functions (implemented in Cache.lua)
function DC:LoadCache() end
function DC:SaveCache() end
