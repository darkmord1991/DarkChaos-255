--[[
    DC-Welcome Core.lua
    Main addon initialization, Plugin API, and DCAddonProtocol integration
    
    Features:
    - First-login detection and welcome popup trigger
    - DCAddonProtocol handler registration
    - Plugin Registration API (replaces DC-Central)
    - Event Bus for inter-addon communication
    - Progress tracking (M+ rating, Prestige, Seasons)
    - Server-side config sync
    - Slash commands (/welcome, /faq, /dcprogress)
    
    Author: DarkChaos-255
    Date: January 2025
    Updated: December 2025 - Added Plugin API and Event Bus
]]

local addonName = "DC-Welcome"
DCWelcome = DCWelcome or {}

-- Version
DCWelcome.VERSION = "2.0.0"

-- =============================================================================
-- Saved Variables & Defaults
-- =============================================================================

local defaults = {
    shown = false,              -- Has the welcome popup been shown?
    dismissed = false,          -- User chose "don't show again"
    lastVersion = nil,          -- Last version shown (for What's New)
    firstLoginComplete = false, -- First login flow finished
    seenFeatures = {},          -- Which feature popups have been shown
    seenLevels = {},            -- Which level milestones have been shown
    showMilestones = true,      -- Show level milestone notifications
    showMinimapButton = true,   -- Minimap button visibility
    enableSounds = true,        -- Sound effects
    showTooltips = true,        -- Feature tooltips
    pluginSettings = {},        -- Per-plugin settings storage
}

-- =============================================================================
-- Plugin Registry (Replaces DC-Central functionality)
-- =============================================================================

DCWelcome.Plugins = {}       -- All registered plugins
DCWelcome.PluginsByID = {}   -- Quick lookup by ID
DCWelcome.Categories = {
    "Dungeons",
    "PvP", 
    "Progression",
    "Gear",
    "World",
    "Competition",
    "Settings",
    "Utility",
    "Other"
}

-- =============================================================================
-- Event Bus (Inter-addon communication)
-- =============================================================================

DCWelcome.EventBus = {
    _handlers = {}
}

-- Register an event handler
function DCWelcome.EventBus:On(eventName, callback)
    self._handlers[eventName] = self._handlers[eventName] or {}
    table.insert(self._handlers[eventName], callback)
end

-- Emit an event to all registered handlers
function DCWelcome.EventBus:Emit(eventName, ...)
    local handlers = self._handlers[eventName]
    if handlers then
        for _, callback in ipairs(handlers) do
            local ok, err = pcall(callback, ...)
            if not ok then
                DCWelcome.Print("|cffff0000EventBus error:|r " .. tostring(err))
            end
        end
    end
end

-- Clear all handlers for an event
function DCWelcome.EventBus:Off(eventName)
    self._handlers[eventName] = nil
end

-- =============================================================================
-- Progress Data Cache
-- =============================================================================

DCWelcome.Progress = {
    mythicRating = nil,
    prestigeLevel = nil,
    prestigeXP = nil,
    seasonRank = nil,
    seasonPoints = nil,
    weeklyVaultProgress = nil,
    achievementPoints = nil,
    keysThisWeek = nil,
    altBonusLevel = nil,
    altBonusPercent = nil,
    _lastUpdate = 0
}

-- Progress cache for tooltip access
DCWelcome.ProgressCache = {}

-- =============================================================================
-- Local Variables
-- =============================================================================

local DC = nil  -- DCAddonProtocol reference
local serverInfo = {}
local currentSeason = { id = 1, name = "Season 1" }
local welcomeFrame = nil
local isLoaded = false

-- =============================================================================
-- Module Identifiers & Opcodes
-- =============================================================================

-- Must match server-side dc_addon_welcome.cpp
DCWelcome.Module = "WELC"

DCWelcome.Opcode = {
    -- Client -> Server
    CMSG_GET_SERVER_INFO = 0x01,
    CMSG_GET_FAQ = 0x02,
    CMSG_DISMISS_WELCOME = 0x03,
    CMSG_MARK_FEATURE_SEEN = 0x04,
    CMSG_GET_WHATS_NEW = 0x05,
    CMSG_GET_PROGRESS = 0x06,        -- NEW: Request progress data
    
    -- Server -> Client
    SMSG_SHOW_WELCOME = 0x10,
    SMSG_SERVER_INFO = 0x11,
    SMSG_FAQ_DATA = 0x12,
    SMSG_FEATURE_UNLOCK = 0x13,
    SMSG_WHATS_NEW = 0x14,
    SMSG_LEVEL_MILESTONE = 0x15,
    SMSG_PROGRESS_DATA = 0x16,       -- NEW: Progress data response
}

-- =============================================================================
-- Utility Functions
-- =============================================================================

local function Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC-Welcome]|r " .. (msg or ""))
    end
end

local function DebugPrint(msg)
    if DCWelcomeDB and DCWelcomeDB.debug then
        Print("|cff888888[Debug]|r " .. (msg or ""))
    end
end

-- =============================================================================
-- Initialization
-- =============================================================================

local function LoadSettings()
    DCWelcomeDB = DCWelcomeDB or {}
    for key, value in pairs(defaults) do
        if DCWelcomeDB[key] == nil then
            DCWelcomeDB[key] = value
        end
    end
end

local function SaveSetting(key, value)
    DCWelcomeDB = DCWelcomeDB or {}
    DCWelcomeDB[key] = value
end

-- =============================================================================
-- Server Info Handling
-- =============================================================================

function DCWelcome:GetServerInfo()
    return serverInfo
end

function DCWelcome:GetCurrentSeason()
    return currentSeason
end

function DCWelcome:RequestServerInfo()
    if DC then
        DC:Request(self.Module, self.Opcode.CMSG_GET_SERVER_INFO, {})
        DebugPrint("Requested server info")
    end
end

function DCWelcome:RequestFAQ(category)
    if DC then
        DC:Request(self.Module, self.Opcode.CMSG_GET_FAQ, { category = category or "all" })
        DebugPrint("Requested FAQ data")
    end
end

function DCWelcome:RequestWhatsNew()
    if DC then
        DC:Request(self.Module, self.Opcode.CMSG_GET_WHATS_NEW, {})
        DebugPrint("Requested What's New data")
    end
end

-- Merge server FAQ entries with local entries (server takes priority for matching IDs)
function DCWelcome:MergeFAQ(serverEntries)
    if not serverEntries or #serverEntries == 0 then
        return
    end
    
    -- If ExtendedFAQ exists, merge server entries
    if self.ExtendedFAQ then
        -- Create lookup by question for deduplication
        local existing = {}
        for _, entry in ipairs(self.ExtendedFAQ) do
            existing[string.lower(entry.question)] = true
        end
        
        -- Add new server entries
        for _, serverEntry in ipairs(serverEntries) do
            if not existing[string.lower(serverEntry.question)] then
                table.insert(self.ExtendedFAQ, serverEntry)
            end
        end
        
        DebugPrint("Merged " .. #serverEntries .. " server FAQ entries")
    end
end

-- =============================================================================
-- DCAddonProtocol Handlers
-- =============================================================================

local function RegisterHandlers()
    if not DC then
        DC = rawget(_G, "DCAddonProtocol")
    end
    
    if not DC then
        -- Try again later if DC isn't loaded yet
        C_Timer_After(1, RegisterHandlers)
        return
    end
    
    DebugPrint("Registering DCAddonProtocol handlers")
    
    -- SMSG_SHOW_WELCOME - Server tells client to show welcome popup
    DC:RegisterHandler(DCWelcome.Module, DCWelcome.Opcode.SMSG_SHOW_WELCOME, function(data)
        DebugPrint("Received SMSG_SHOW_WELCOME")
        
        if type(data) == "table" then
            -- Update server info if provided
            if data.serverName then
                serverInfo.name = data.serverName
            end
            if data.maxLevel then
                serverInfo.maxLevel = data.maxLevel
            end
            if data.season then
                currentSeason = data.season
            end
            if data.discordUrl then
                serverInfo.discordUrl = data.discordUrl
            end
            if data.websiteUrl then
                serverInfo.websiteUrl = data.websiteUrl
            end
        end
        
        -- Show welcome frame if not dismissed
        if not DCWelcomeDB.dismissed then
            DCWelcome:ShowWelcome()
        end
    end)
    
    -- SMSG_SERVER_INFO - Server sends configuration data
    DC:RegisterHandler(DCWelcome.Module, DCWelcome.Opcode.SMSG_SERVER_INFO, function(data)
        DebugPrint("Received SMSG_SERVER_INFO")
        
        if type(data) == "table" then
            serverInfo = data
            
            if data.season then
                currentSeason = data.season
            end
        end
    end)
    
    -- SMSG_FEATURE_UNLOCK - Server notifies a feature was unlocked
    DC:RegisterHandler(DCWelcome.Module, DCWelcome.Opcode.SMSG_FEATURE_UNLOCK, function(data)
        DebugPrint("Received SMSG_FEATURE_UNLOCK")
        
        if type(data) == "table" and data.feature then
            local feature = data.feature
            local message = data.message or "A new feature has been unlocked!"
            
            -- Show unlock notification
            DCWelcome:ShowFeatureUnlock(feature, message)
        end
    end)
    
    -- SMSG_LEVEL_MILESTONE - Server notifies a level milestone was reached
    DC:RegisterHandler(DCWelcome.Module, DCWelcome.Opcode.SMSG_LEVEL_MILESTONE, function(data)
        DebugPrint("Received SMSG_LEVEL_MILESTONE")
        
        if type(data) == "table" and data.level then
            local level = data.level
            local feature = data.feature
            local message = data.message
            
            -- Check if we've already shown this
            if not DCWelcomeDB.seenLevels[level] then
                DCWelcome:ShowLevelMilestone(level, feature, message)
                DCWelcomeDB.seenLevels[level] = true
            end
        end
    end)
    
    -- SMSG_WHATS_NEW - Server sends What's New content
    DC:RegisterHandler(DCWelcome.Module, DCWelcome.Opcode.SMSG_WHATS_NEW, function(data)
        DebugPrint("Received SMSG_WHATS_NEW")
        
        if type(data) == "table" then
            serverInfo.whatsNew = data.entries or data.content or {}
            serverInfo.version = data.version
            serverInfo.whatsNewCount = data.count or 0
            
            -- Update What's New tab if frame is open
            if welcomeFrame and welcomeFrame:IsShown() then
                DCWelcome:UpdateWhatsNew()
            end
        end
    end)
    
    -- SMSG_FAQ_DATA - Server sends dynamic FAQ entries
    DC:RegisterHandler(DCWelcome.Module, DCWelcome.Opcode.SMSG_FAQ_DATA, function(data)
        DebugPrint("Received SMSG_FAQ_DATA")
        
        if type(data) == "table" and data.entries then
            -- Store server FAQ entries
            DCWelcome.ServerFAQ = data.entries
            serverInfo.faqCount = data.count or #data.entries
            
            -- Merge with local FAQ if needed (server takes priority)
            if DCWelcome.MergeFAQ then
                DCWelcome:MergeFAQ(data.entries)
            end
            
            DebugPrint("Received " .. (data.count or 0) .. " FAQ entries from server")
        end
    end)
    
    -- SMSG_PROGRESS_DATA - Server sends player progress data (NEW)
    DC:RegisterHandler(DCWelcome.Module, DCWelcome.Opcode.SMSG_PROGRESS_DATA, function(data)
        DebugPrint("Received SMSG_PROGRESS_DATA")
        
        if type(data) == "table" then
            local progress = DCWelcome.Progress
            
            -- Update cached progress data
            if data.mythicRating then
                progress.mythicRating = data.mythicRating
            end
            if data.prestigeLevel then
                progress.prestigeLevel = data.prestigeLevel
            end
            if data.prestigeXP then
                progress.prestigeXP = data.prestigeXP
            end
            if data.seasonPoints then
                progress.seasonPoints = data.seasonPoints
            end
            if data.seasonRank then
                progress.seasonRank = data.seasonRank
            end
            if data.weeklyVaultProgress then
                progress.weeklyVaultProgress = data.weeklyVaultProgress
            end
            if data.achievementPoints then
                progress.achievementPoints = data.achievementPoints
            end
            if data.keysThisWeek then
                progress.keysThisWeek = data.keysThisWeek
            end
            
            -- Alt Bonus (Prestige system - max-level alts)
            if data.altBonusLevel then
                progress.altBonusLevel = data.altBonusLevel
            end
            if data.altBonusPercent then
                progress.altBonusPercent = data.altBonusPercent
            end
            
            progress._lastUpdate = time()
            
            -- Store in cache for tooltip access
            DCWelcome.ProgressCache = progress
            
            -- Emit event for UI updates
            DCWelcome.EventBus:Emit("PROGRESS_UPDATED", progress)
            
            DebugPrint("Progress data updated from server")
        end
    end)
    
    -- PRES module: SMSG_INFO (0x10) - Prestige info from server
    DC:RegisterHandler("PRES", 0x10, function(data)
        DebugPrint("Received PRES SMSG_INFO")
        
        if type(data) == "table" then
            local progress = DCWelcome.Progress
            
            if data.level then
                progress.prestigeLevel = data.level
            end
            if data.prestigeLevel then
                progress.prestigeLevel = data.prestigeLevel
            end
            if data.currentXP then
                progress.prestigeXP = data.currentXP
            end
            if data.prestigeXP then
                progress.prestigeXP = data.prestigeXP
            end
            if data.xpToNext then
                progress.prestigeXPMax = data.xpToNext
            end
            if data.altBonusLevel then
                progress.altBonusLevel = data.altBonusLevel
            end
            if data.altBonusPercent then
                progress.altBonusPercent = data.altBonusPercent
            end
            
            progress._lastUpdate = time()
            DCWelcome.ProgressCache = progress
            DCWelcome.EventBus:Emit("PROGRESS_UPDATED", progress)
            
            DebugPrint("Prestige data updated: Level " .. tostring(progress.prestigeLevel))
        end
    end)
    
    -- SEAS module: SMSG_CURRENT (0x10) - Season info from server
    DC:RegisterHandler("SEAS", 0x10, function(data)
        DebugPrint("Received SEAS SMSG_CURRENT")
        
        if type(data) == "table" then
            local progress = DCWelcome.Progress
            
            -- Update season rank from season ID
            if data.seasonId or data.id then
                progress.seasonRank = data.seasonId or data.id
            end
            
            progress._lastUpdate = time()
            DCWelcome.ProgressCache = progress
        end
    end)
    
    -- SEAS module: SMSG_PROGRESS (0x12) - Season progress from server
    DC:RegisterHandler("SEAS", 0x12, function(data)
        DebugPrint("Received SEAS SMSG_PROGRESS")
        
        if type(data) == "table" then
            local progress = DCWelcome.Progress
            
            if data.weeklyTokens or data.tokens then
                -- Prefer weekly progress metric for season display
                progress.seasonPoints = data.weeklyTokens or data.tokens
            end
            if data.seasonLevel then
                progress.seasonRank = data.seasonLevel
            end
            
            progress._lastUpdate = time()
            DCWelcome.ProgressCache = progress
            DCWelcome.EventBus:Emit("PROGRESS_UPDATED", progress)
            
            DebugPrint("Season progress updated")
            DebugPrint("Progress payload: weeklyTokens=" .. tostring(data.weeklyTokens or "nil") .. ", tokens=" .. tostring(data.tokens or "nil") .. ", tokenCap=" .. tostring(data.tokenCap or "nil"))
        end
    end)
    
    Print("Handlers registered (v" .. DCWelcome.VERSION .. ")")
end

-- =============================================================================
-- C_Timer Polyfill for 3.3.5a
-- =============================================================================

if not C_Timer_After then
    C_Timer_After = function(delay, callback)
        local frame = CreateFrame("Frame")
        frame.elapsed = 0
        frame:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = self.elapsed + elapsed
            if self.elapsed >= delay then
                self:SetScript("OnUpdate", nil)
                callback()
            end
        end)
    end
end

-- Export C_Timer_After globally if needed by other files
DCWelcome.After = C_Timer_After

-- =============================================================================
-- Plugin Registration API
-- =============================================================================

--[[
    Register a plugin with DC-Welcome
    
    @param plugin table with the following fields:
        - id (string, required): Unique identifier, e.g. "dc-mythicplus"
        - name (string, required): Display name
        - description (string, optional): Short description
        - icon (string, optional): Icon path
        - color (table, optional): {r, g, b} accent color
        - category (string, optional): Category for grouping (default: "Other")
        - openFunc (function, optional): Called when "Open" is clicked
        - openCommand (string, optional): Slash command equivalent
        - settingsFunc (function, optional): Called when "Settings" is clicked
        - settingsCommand (string, optional): Settings slash command
        - minLevel (number, optional): Minimum player level to show (default: 1)
        - version (string, optional): Plugin version
        - isLoaded (function, optional): Returns true if addon is loaded
        - priority (number, optional): Sort order (higher = first)
        - settingsOnly (boolean, optional): Only show settings button
        - infoOnly (boolean, optional): Info display only, no open button
    
    @return boolean success
]]
function DCWelcome:RegisterPlugin(plugin)
    if not plugin or not plugin.id or not plugin.name then
        DebugPrint("RegisterPlugin: Missing required fields (id, name)")
        return false
    end
    
    -- Check for duplicate
    if self.PluginsByID[plugin.id] then
        DebugPrint("RegisterPlugin: Updating existing plugin: " .. plugin.id)
        -- Update existing registration (allows addons to update their info)
        for i, p in ipairs(self.Plugins) do
            if p.id == plugin.id then
                self.Plugins[i] = plugin
                self.PluginsByID[plugin.id] = plugin
                break
            end
        end
        -- Emit event for update
        self.EventBus:Emit("PLUGIN_UPDATED", plugin)
        return true
    end
    
    -- Set defaults
    plugin.category = plugin.category or "Other"
    plugin.minLevel = plugin.minLevel or 1
    plugin.priority = plugin.priority or 50
    plugin.version = plugin.version or "1.0.0"
    
    -- Add to registry
    table.insert(self.Plugins, plugin)
    self.PluginsByID[plugin.id] = plugin
    
    -- Sort by priority (descending) then name
    table.sort(self.Plugins, function(a, b)
        if a.priority ~= b.priority then
            return a.priority > b.priority
        end
        return a.name < b.name
    end)
    
    DebugPrint("Registered plugin: " .. plugin.id .. " (" .. plugin.name .. ")")
    
    -- Emit event for new registration
    self.EventBus:Emit("PLUGIN_REGISTERED", plugin)
    
    -- Refresh addons panel if open
    if self.RefreshAddonStatus then
        self:RefreshAddonStatus()
    end
    
    return true
end

-- Unregister a plugin
function DCWelcome:UnregisterPlugin(pluginId)
    if not self.PluginsByID[pluginId] then
        return false
    end
    
    for i, p in ipairs(self.Plugins) do
        if p.id == pluginId then
            table.remove(self.Plugins, i)
            break
        end
    end
    
    self.PluginsByID[pluginId] = nil
    self.EventBus:Emit("PLUGIN_UNREGISTERED", pluginId)
    return true
end

-- Get all registered plugins
function DCWelcome:GetPlugins()
    return self.Plugins
end

-- Get plugin by ID
function DCWelcome:GetPlugin(pluginId)
    return self.PluginsByID[pluginId]
end

-- Get plugins grouped by category
function DCWelcome:GetPluginsByCategory()
    local byCategory = {}
    for _, plugin in ipairs(self.Plugins) do
        local cat = plugin.category or "Other"
        byCategory[cat] = byCategory[cat] or {}
        table.insert(byCategory[cat], plugin)
    end
    return byCategory
end

-- Check if player can use a plugin
function DCWelcome:CanUsePlugin(pluginId)
    local plugin = self.PluginsByID[pluginId]
    if not plugin then
        return false, "not_found"
    end
    
    -- Check if addon is loaded
    if plugin.isLoaded and not plugin.isLoaded() then
        return false, "not_loaded"
    end
    
    -- Check level requirement
    local playerLevel = UnitLevel("player")
    if plugin.minLevel and playerLevel < plugin.minLevel then
        return false, "level", plugin.minLevel
    end
    
    return true
end

-- Open a plugin
function DCWelcome:OpenPlugin(pluginId)
    local plugin = self.PluginsByID[pluginId]
    if not plugin then
        Print("Plugin not found: " .. tostring(pluginId))
        return false
    end
    
    local canUse, reason = self:CanUsePlugin(pluginId)
    if not canUse then
        if reason == "not_loaded" then
            Print("Plugin not loaded: " .. plugin.name)
        elseif reason == "level" then
            Print("Requires level " .. plugin.minLevel)
        end
        return false
    end
    
    if plugin.openFunc then
        plugin.openFunc()
        return true
    end
    
    return false
end

-- Open plugin settings
function DCWelcome:OpenPluginSettings(pluginId)
    local plugin = self.PluginsByID[pluginId]
    if not plugin then
        return false
    end
    
    if plugin.settingsFunc then
        plugin.settingsFunc()
        return true
    end
    
    return false
end

-- Per-plugin settings storage
function DCWelcome:GetPluginSetting(pluginId, key)
    if DCWelcomeDB and DCWelcomeDB.pluginSettings and DCWelcomeDB.pluginSettings[pluginId] then
        return DCWelcomeDB.pluginSettings[pluginId][key]
    end
    return nil
end

function DCWelcome:SetPluginSetting(pluginId, key, value)
    if DCWelcomeDB then
        DCWelcomeDB.pluginSettings = DCWelcomeDB.pluginSettings or {}
        DCWelcomeDB.pluginSettings[pluginId] = DCWelcomeDB.pluginSettings[pluginId] or {}
        DCWelcomeDB.pluginSettings[pluginId][key] = value
    end
end

-- =============================================================================
-- Progress Data API
-- =============================================================================

-- Request progress data from server
function DCWelcome:RequestProgressData()
    if DC then
        -- Request main progress data
        DC:Request(self.Module, self.Opcode.CMSG_GET_PROGRESS, {})
        DebugPrint("Requested progress data from server")
        
        -- Also request prestige data from PRES module
        DC:Request("PRES", 0x01, {})  -- CMSG_GET_INFO
        DebugPrint("Requested prestige data from server")
        
        -- Request season data from SEAS module  
        DC:Request("SEAS", 0x01, {})  -- CMSG_GET_CURRENT
        DC:Request("SEAS", 0x03, {})  -- CMSG_GET_PROGRESS
        DebugPrint("Requested season data from server")
    end
    
    -- Also try to get data from loaded addons
    self:RefreshProgressFromAddons()
end

-- Refresh progress data from loaded addons
function DCWelcome:RefreshProgressFromAddons()
    local progress = self.Progress
    
    -- Get M+ rating from DC-MythicPlus
    if _G.DCMythicPlusHUD and DCMythicPlusHUD.GetPlayerRating then
        progress.mythicRating = DCMythicPlusHUD:GetPlayerRating()
    end
    
    -- Get prestige from DC-Prestige (if it exists)
    if _G.DCPrestige and DCPrestige.GetPrestigeLevel then
        progress.prestigeLevel = DCPrestige:GetPrestigeLevel()
        progress.prestigeXP = DCPrestige:GetPrestigeXP()
    end
    
    -- Fallback: Try to get prestige from DC-InfoBar's serverData
    if not progress.prestigeLevel and _G.DCInfoBar and DCInfoBar.serverData and DCInfoBar.serverData.prestige then
        local presData = DCInfoBar.serverData.prestige
        progress.prestigeLevel = presData.level
        progress.prestigeXP = presData.currentXP
    end
    
    -- Fallback: Try to get season data from DCWelcome.Seasons.Data
    if DCWelcome.Seasons and DCWelcome.Seasons.Data then
        local seasData = DCWelcome.Seasons.Data
        if seasData._loaded then
            progress.seasonPoints = seasData.tokens or seasData.weeklyTokens or progress.seasonPoints
        end
    end
    
    -- Get achievement points
    if GetTotalAchievementPoints then
        progress.achievementPoints = GetTotalAchievementPoints()
    end
    
    progress._lastUpdate = time()
    
    -- Emit update event
    self.EventBus:Emit("PROGRESS_UPDATED", progress)
end

-- Get current progress data
function DCWelcome:GetProgress()
    return self.Progress
end

-- =============================================================================
-- Public API
-- =============================================================================

function DCWelcome:ShowWelcome(forceShow)
    if not isLoaded then
        -- Queue for after load
        C_Timer_After(0.5, function() DCWelcome:ShowWelcome(forceShow) end)
        return
    end
    
    if not forceShow and DCWelcomeDB.dismissed then
        return
    end
    
    if welcomeFrame then
        welcomeFrame:Show()
    else
        -- Create frame if it doesn't exist
        if DCWelcome.CreateWelcomeFrame then
            welcomeFrame = DCWelcome:CreateWelcomeFrame()
            if welcomeFrame then
                welcomeFrame:Show()
            end
        end
    end
    
    DCWelcomeDB.shown = true
end

function DCWelcome:HideWelcome()
    if welcomeFrame then
        welcomeFrame:Hide()
    end
end

function DCWelcome:DismissWelcome()
    SaveSetting("dismissed", true)
    DCWelcome:HideWelcome()
    Print(DCWelcome.L["MSG_WELCOME_DISMISSED"])
    
    -- Notify server
    if DC then
        DC:Request(DCWelcome.Module, DCWelcome.Opcode.CMSG_DISMISS_WELCOME, {})
    end
end

function DCWelcome:ShowFeatureUnlock(feature, message)
    -- Show feature unlock popup
    DCWelcome:ShowNotificationPopup(
        "|cffffd700Feature Unlocked!|r",
        message or feature,
        "Interface\\Icons\\Spell_Nature_EnchantArmor",
        "LEVELUP"
    )
end

-- Notification popup for milestones and feature unlocks
local notificationFrame = nil

function DCWelcome:ShowNotificationPopup(title, message, icon, soundId)
    if not notificationFrame then
        notificationFrame = CreateFrame("Frame", "DCWelcomeNotification", UIParent)
        notificationFrame:SetSize(350, 100)
        notificationFrame:SetPoint("TOP", 0, -100)
        notificationFrame:SetFrameStrata("DIALOG")
        
        -- Background
        local bg = notificationFrame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture(0, 0, 0, 0.85)
        
        -- Border glow
        local border = notificationFrame:CreateTexture(nil, "BORDER")
        border:SetPoint("TOPLEFT", -3, 3)
        border:SetPoint("BOTTOMRIGHT", 3, -3)
        border:SetTexture(0.4, 0.8, 0.4, 0.5)
        notificationFrame.border = border
        
        -- Icon
        local iconTex = notificationFrame:CreateTexture(nil, "ARTWORK")
        iconTex:SetSize(48, 48)
        iconTex:SetPoint("LEFT", 15, 0)
        notificationFrame.icon = iconTex
        
        -- Title
        local titleText = notificationFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        titleText:SetPoint("TOPLEFT", 75, -15)
        titleText:SetWidth(260)
        titleText:SetJustifyH("LEFT")
        notificationFrame.title = titleText
        
        -- Message
        local msgText = notificationFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        msgText:SetPoint("TOPLEFT", 75, -35)
        msgText:SetWidth(260)
        msgText:SetJustifyH("LEFT")
        notificationFrame.message = msgText
        
        -- Fade animation
        notificationFrame:SetAlpha(0)
        notificationFrame:Hide()
    end
    
    -- Set content
    notificationFrame.icon:SetTexture(icon or "Interface\\Icons\\Spell_Holy_Restoration")
    notificationFrame.title:SetText(title or "")
    notificationFrame.message:SetText(message or "")
    
    -- Show with fade in
    notificationFrame:Show()
    notificationFrame:SetAlpha(0)
    
    local elapsed = 0
    local state = "fadeIn"  -- fadeIn, show, fadeOut
    
    notificationFrame:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        
        if state == "fadeIn" then
            local alpha = math.min(1, elapsed / 0.5)
            self:SetAlpha(alpha)
            if alpha >= 1 then
                elapsed = 0
                state = "show"
            end
        elseif state == "show" then
            if elapsed >= 5 then  -- Show for 5 seconds
                elapsed = 0
                state = "fadeOut"
            end
        elseif state == "fadeOut" then
            local alpha = math.max(0, 1 - (elapsed / 0.5))
            self:SetAlpha(alpha)
            if alpha <= 0 then
                self:Hide()
                self:SetScript("OnUpdate", nil)
            end
        end
    end)
    
    -- Play sound
    if soundId then
        PlaySound(soundId)
    end
    
    -- Also print to chat
    Print(message or "")
end

function DCWelcome:ShowLevelMilestone(level, feature, message)
    -- Check if user wants milestone notifications
    if DCWelcomeDB.showMilestones == false then
        return
    end
    
    local icon = "Interface\\Icons\\Spell_Holy_Restoration"
    local title = "|cffffd700Level " .. level .. " Milestone!|r"
    
    if not message then
        if level == 10 then
            message = "|cff00ccffHotspots|r are now available! Use |cfffff000/hotspot|r to see active zones."
            icon = "Interface\\Icons\\INV_Misc_Map02"
        elseif level == 20 then
            message = "Preview the |cffa335eePrestige System|r at level 80!"
            icon = "Interface\\Icons\\Achievement_Level_80"
        elseif level == 58 then
            message = "Outland awaits! At 80, unlock |cffff8000Item Upgrades|r!"
            icon = "Interface\\Icons\\INV_Misc_Gem_Pearl_03"
        elseif level == 80 then
            message = "Congratulations! You've unlocked |cffff8000Mythic+ Dungeons|r and the |cffa335eePrestige System|r!"
            icon = "Interface\\Icons\\Achievement_Dungeon_GlssDtDngeon_HeroicMc"
            title = "|cffff8000MAX VANILLA LEVEL!|r"
        elseif level == 100 then
            message = "Level 100! New custom dungeons available: |cff00ccffThe Nexus|r & |cff00ccffThe Oculus|r!"
            icon = "Interface\\Icons\\INV_Misc_QirajiCrystal_05"
        elseif level == 130 then
            message = "|cff00ccffGundrak|r and |cff00ccffAhn'kahet|r dungeons are now accessible!"
            icon = "Interface\\Icons\\INV_Misc_QirajiCrystal_02"
        elseif level == 160 then
            message = "Auchindoun unlocked: |cff00ccffCrypts|r, |cff00ccffMana Tombs|r, |cff00ccffSethekk|r, |cff00ccffShadow Lab|r!"
            icon = "Interface\\Icons\\INV_Misc_QirajiCrystal_01"
        elseif level == 200 then
            message = "Level 200! You've entered the |cffff8000ENDGAME TIER|r. Elite challenges await!"
            icon = "Interface\\Icons\\INV_Jewelry_Ring_66"
            title = "|cffa335eeELITE TIER REACHED!|r"
        elseif level == 255 then
            message = "|cffff8000MAXIMUM LEVEL!|r You've reached the pinnacle of power on DarkChaos-255!"
            icon = "Interface\\Icons\\Spell_Holy_SurgeOfLight"
            title = "|cffff8000MAXIMUM POWER!|r"
        else
            message = "You have reached level " .. level .. "!"
        end
    end
    
    local sound = "igQuestLogOpen"
    if level >= 200 or level == 80 or level == 255 then
        sound = "LEVELUP"
    end
    
    DCWelcome:ShowNotificationPopup(title, message, icon, sound)
end

function DCWelcome:SetWelcomeFrame(frame)
    welcomeFrame = frame
end

function DCWelcome:UpdateWhatsNew()
    -- Called when What's New data is received
    if welcomeFrame and welcomeFrame.UpdateWhatsNew then
        welcomeFrame:UpdateWhatsNew()
    end
end

function DCWelcome:IsFirstLogin()
    return not DCWelcomeDB.firstLoginComplete
end

function DCWelcome:CompleteFirstLogin()
    SaveSetting("firstLoginComplete", true)
end

-- =============================================================================
-- Slash Commands
-- =============================================================================

SLASH_DCWELCOME1 = "/welcome"
SLASH_DCWELCOME2 = "/dcwelcome"
SlashCmdList["DCWELCOME"] = function(msg)
    local args = {}
    for word in string.gmatch(msg or "", "%S+") do
        table.insert(args, string.lower(word))
    end
    
    local cmd = args[1] or ""
    
    if cmd == "reset" then
        SaveSetting("shown", false)
        SaveSetting("dismissed", false)
        SaveSetting("seenLevels", {})
        SaveSetting("seenFeatures", {})
        Print("Welcome settings reset. Use |cfffff000/welcome|r to show the welcome screen.")
    elseif cmd == "debug" then
        DCWelcomeDB.debug = not DCWelcomeDB.debug
        Print("Debug mode: " .. (DCWelcomeDB.debug and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
    elseif cmd == "info" then
        local info = DCWelcome:GetServerInfo()
        Print("Server Info:")
        Print("  Name: " .. (info.name or "Unknown"))
        Print("  Max Level: " .. (info.maxLevel or 80))
        Print("  Season: " .. (currentSeason.name or "Unknown"))
    else
        DCWelcome:ShowWelcome(true)
    end
end

SLASH_DCFAQ1 = "/faq"
SLASH_DCFAQ2 = "/dcfaq"
SlashCmdList["DCFAQ"] = function(msg)
    DCWelcome:ShowWelcome(true)
    -- Switch to FAQ tab after a short delay
    C_Timer_After(0.1, function()
        if welcomeFrame and welcomeFrame.SelectTab then
            welcomeFrame:SelectTab("faq")
        end
    end)
end

SLASH_DCDISCORD1 = "/discord"
SlashCmdList["DCDISCORD"] = function(msg)
    local url = "https://discord.gg/pNddMEMbb2"
    Print("Discord: |cff00ccff" .. url .. "|r")
    Print("Click the link in chat or copy it!")
    -- Put URL in edit box for easy copy
    if ChatFrame1EditBox then
        ChatFrame1EditBox:SetText(url)
        ChatFrame1EditBox:Show()
        ChatFrame1EditBox:SetFocus()
        ChatFrame1EditBox:HighlightText()
    end
end

-- Progress command
SLASH_DCPROGRESS1 = "/dcprogress"
SLASH_DCPROGRESS2 = "/progress"
SlashCmdList["DCPROGRESS"] = function(msg)
    local args = {}
    for word in string.gmatch(msg or "", "%S+") do
        table.insert(args, string.lower(word))
    end
    
    local cmd = args[1] or ""
    
    if cmd == "refresh" then
        DCWelcome:RequestProgressData()
        Print("Refreshing progress data...")
    elseif cmd == "show" or cmd == "" then
        DCWelcome:ShowWelcome(true)
        C_Timer_After(0.1, function()
            if welcomeFrame and welcomeFrame.SelectTab then
                welcomeFrame:SelectTab("progress")
            end
        end)
    else
        Print("Usage: /dcprogress [show|refresh]")
    end
end

-- Addons hub command
SLASH_DCADDONS1 = "/dcaddons"
SLASH_DCADDONS2 = "/addons"
SlashCmdList["DCADDONS"] = function(msg)
    DCWelcome:ShowWelcome(true)
    C_Timer_After(0.1, function()
        if welcomeFrame and welcomeFrame.SelectTab then
            welcomeFrame:SelectTab("addons")
        end
    end)
end

-- =============================================================================
-- Settings Panel (Interface Options)
-- =============================================================================

local function CreateSettingsPanel()
    local panel = CreateFrame("Frame", "DCWelcomeSettingsPanel", UIParent)
    panel.name = "DC-Welcome"
    
    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cff00ff00DC-Welcome|r Settings")
    
    -- Description
    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetWidth(560)
    desc:SetJustifyH("LEFT")
    desc:SetText("Configure the welcome screen and first-start experience settings.")
    
    local yPos = -70
    
    -- Server Info Section
    local serverHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    serverHeader:SetPoint("TOPLEFT", 16, yPos)
    serverHeader:SetText("|cffffd700Server Information|r")
    yPos = yPos - 22
    
    local serverInfo = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    serverInfo:SetPoint("TOPLEFT", 24, yPos)
    serverInfo:SetWidth(300)
    serverInfo:SetJustifyH("LEFT")
    panel.serverInfoText = serverInfo
    yPos = yPos - 60
    
    -- Discord link
    local discordLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    discordLabel:SetPoint("TOPLEFT", 16, yPos)
    discordLabel:SetText("|cffffd700Discord:|r |cff00ccffhttps://discord.gg/pNddMEMbb2|r")
    yPos = yPos - 25
    
    local discordBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    discordBtn:SetSize(150, 24)
    discordBtn:SetPoint("TOPLEFT", 24, yPos)
    discordBtn:SetText("Copy Discord Link")
    discordBtn:SetScript("OnClick", function()
        if ChatFrame1EditBox then
            ChatFrame1EditBox:SetText("https://discord.gg/pNddMEMbb2")
            ChatFrame1EditBox:Show()
            ChatFrame1EditBox:SetFocus()
            ChatFrame1EditBox:HighlightText()
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC-Welcome]|r Discord link copied to chat input!")
    end)
    yPos = yPos - 40
    
    -- Settings Section
    local settingsHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    settingsHeader:SetPoint("TOPLEFT", 16, yPos)
    settingsHeader:SetText("|cffffd700Display Settings|r")
    yPos = yPos - 25
    
    -- Show on login checkbox
    local showOnLoginCheck = CreateFrame("CheckButton", "DCWelcome_ShowOnLogin", panel, "InterfaceOptionsCheckButtonTemplate")
    showOnLoginCheck:SetPoint("TOPLEFT", 24, yPos)
    showOnLoginCheck:SetHitRectInsets(0, -200, 0, 0)
    _G["DCWelcome_ShowOnLoginText"]:SetText("Show welcome screen on first login")
    showOnLoginCheck:SetScript("OnClick", function(self)
        DCWelcomeDB = DCWelcomeDB or {}
        DCWelcomeDB.dismissed = not self:GetChecked()
    end)
    yPos = yPos - 28
    
    -- Show level milestones checkbox
    local showMilestonesCheck = CreateFrame("CheckButton", "DCWelcome_ShowMilestones", panel, "InterfaceOptionsCheckButtonTemplate")
    showMilestonesCheck:SetPoint("TOPLEFT", 24, yPos)
    showMilestonesCheck:SetHitRectInsets(0, -200, 0, 0)
    _G["DCWelcome_ShowMilestonesText"]:SetText("Show level milestone notifications")
    showMilestonesCheck:SetScript("OnClick", function(self)
        DCWelcomeDB = DCWelcomeDB or {}
        DCWelcomeDB.showMilestones = self:GetChecked()
    end)
    yPos = yPos - 40
    
    -- Quick Actions Section
    local actionsHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    actionsHeader:SetPoint("TOPLEFT", 16, yPos)
    actionsHeader:SetText("|cffffd700Quick Actions|r")
    yPos = yPos - 25
    
    local openWelcomeBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    openWelcomeBtn:SetSize(150, 24)
    openWelcomeBtn:SetPoint("TOPLEFT", 24, yPos)
    openWelcomeBtn:SetText("Open Welcome Screen")
    openWelcomeBtn:SetScript("OnClick", function()
        DCWelcome:ShowWelcome(true)
    end)
    
    local openFAQBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    openFAQBtn:SetSize(100, 24)
    openFAQBtn:SetPoint("LEFT", openWelcomeBtn, "RIGHT", 10, 0)
    openFAQBtn:SetText("Open FAQ")
    openFAQBtn:SetScript("OnClick", function()
        DCWelcome:ShowWelcome(true)
        C_Timer_After(0.1, function()
            if welcomeFrame and welcomeFrame.SelectTab then
                welcomeFrame:SelectTab("faq")
            end
        end)
    end)
    yPos = yPos - 35
    
    local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetBtn:SetSize(150, 24)
    resetBtn:SetPoint("TOPLEFT", 24, yPos)
    resetBtn:SetText("Reset Welcome State")
    resetBtn:SetScript("OnClick", function()
        DCWelcomeDB = DCWelcomeDB or {}
        DCWelcomeDB.shown = false
        DCWelcomeDB.dismissed = false
        DCWelcomeDB.seenLevels = {}
        DCWelcomeDB.seenFeatures = {}
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC-Welcome]|r Welcome state reset. Use /welcome to show again.")
    end)
    yPos = yPos - 50
    
    -- About Section
    local aboutHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    aboutHeader:SetPoint("TOPLEFT", 16, yPos)
    aboutHeader:SetText("|cffffd700About|r")
    yPos = yPos - 20
    
    local aboutText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    aboutText:SetPoint("TOPLEFT", 24, yPos)
    aboutText:SetWidth(500)
    aboutText:SetJustifyH("LEFT")
    aboutText:SetText("DC-Welcome v1.0.0\n" ..
                      "First-start experience and new player introduction for DarkChaos-255.\n\n" ..
                      "Commands:\n" ..
                      "  /welcome - Open the welcome screen\n" ..
                      "  /faq - Open the FAQ section\n" ..
                      "  /discord - Get Discord invite link")
    
    -- Update values on show
    panel:SetScript("OnShow", function(self)
        DCWelcomeDB = DCWelcomeDB or {}
        showOnLoginCheck:SetChecked(not DCWelcomeDB.dismissed)
        showMilestonesCheck:SetChecked(DCWelcomeDB.showMilestones ~= false)
        
        local info = DCWelcome:GetServerInfo()
        local season = DCWelcome:GetCurrentSeason()
        self.serverInfoText:SetText(
            "Server: |cff00ff00" .. (info.name or "DarkChaos-255") .. "|r\n" ..
            "Max Level: |cffffff00" .. (info.maxLevel or 80) .. "|r\n" ..
            "Season: |cff00ccff" .. (season.name or "Season 1") .. "|r"
        )
    end)
    
    -- Register with interface options
    InterfaceOptions_AddCategory(panel)
    
    return panel
end

-- Create settings panel on load
DCWelcome.SettingsPanel = nil

-- Slash command to open settings
SLASH_DCWELCOMESETTINGS1 = "/dcwelcomesettings"
SLASH_DCWELCOMESETTINGS2 = "/welcomesettings"
SlashCmdList["DCWELCOMESETTINGS"] = function()
    InterfaceOptionsFrame_OpenToCategory(DCWelcome.SettingsPanel)
    InterfaceOptionsFrame_OpenToCategory(DCWelcome.SettingsPanel)  -- Call twice for WoW bug
end

-- =============================================================================
-- Event Handling
-- =============================================================================

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then
            LoadSettings()
            DebugPrint("Settings loaded")
            
            -- Create settings panel after load
            DCWelcome.SettingsPanel = CreateSettingsPanel()
            DebugPrint("Settings panel created")
        elseif loadedAddon == "DC-AddonProtocol" then
            RegisterHandlers()
        end
        
    elseif event == "PLAYER_LOGIN" then
        -- Register handlers if DC is already loaded
        if not DC then
            RegisterHandlers()
        end
        
        isLoaded = true
        
        -- Check for first login
        if DCWelcome:IsFirstLogin() then
            -- Wait a moment for the world to load
            C_Timer_After(3, function()
                -- Request server info
                DCWelcome:RequestServerInfo()
                
                -- Show welcome after a brief delay
                C_Timer_After(1, function()
                    if not DCWelcomeDB.dismissed then
                        DCWelcome:ShowWelcome()
                        DCWelcome:CompleteFirstLogin()
                        Print(DCWelcome.L["MSG_FIRST_LOGIN"])
                    end
                end)
            end)
        end
        
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Additional first-time setup if needed
    end
end)

-- =============================================================================
-- Addon Loaded Message
-- =============================================================================

Print("v1.0.0 loaded. Use |cfffff000/welcome|r to open.")
