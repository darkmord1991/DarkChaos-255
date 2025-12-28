-- ============================================================
-- DC-QoS: Quality of Service Addon for DarkChaos-255
-- ============================================================
-- Comprehensive Quality of Life improvements adapted from
-- popular addons like Leatrix Plus, optimized for WoW 3.3.5a
-- ============================================================

-- Create the main addon namespace
DCQOS = DCQOS or {}
local addon = DCQOS

-- ============================================================
-- Addon Metadata
-- ============================================================
addon.name = "DC-QOS"
addon.version = "1.0.0"
addon.author = "DarkChaos Team"
addon.description = "Quality of Life improvements for DarkChaos-255"

-- ============================================================
-- Module System
-- ============================================================
addon.modules = {}          -- Registered modules
addon.moduleOrder = {}      -- Module registration order for tabs
addon.initialized = false   -- Initialization flag
addon.events = {}           -- Event callbacks

-- ============================================================
-- Settings Framework
-- ============================================================
addon.defaults = {
    -- Global settings
    minimapButton = true,
    
    -- Tooltip settings
    tooltips = {
        enabled = true,
        showItemId = true,
        showItemLevel = true,
        showUpgradeInfo = true,  -- Show upgrade tier/level on items
        showNpcId = true,
        showSpellId = true,
        showGuildRank = true,
        showTarget = true,
        hideHealthBar = false,
        hideInCombat = false,
        showWithShift = true,
        scale = 1.0,
        anchor = 1,  -- 1=Default, 2=Overlay, 3=Cursor, 4=CursorRight
        cursorOffsetX = 0,
        cursorOffsetY = 0,
    },
    
    -- Automation settings
    automation = {
        enabled = true,
        autoRepair = true,
        autoRepairGuild = false,
        autoSellJunk = true,
        autoDismount = false,
        autoAcceptSummon = false,
        autoAcceptResurrect = false,
        autoDeclineDuels = false,
        autoDeclineGuildInvites = false,
        autoAcceptPartyInvites = false,
    },
    
    -- Chat settings
    chat = {
        enabled = true,
        hideChannelNames = false,
        hideTimestamps = false,
        hideSocialButtons = false,
        stickyChannels = true,
        shortenClassNames = false,
    },
    
    -- Interface settings
    interface = {
        enabled = true,
        combatPlates = false,
        autoQuestWatch = true,
        questLevelText = true,
        hideGryphons = false,
        hideWorldMap = false,
        largerWorldMap = false,
    },
    
    -- Communication settings (server sync)
    communication = {
        enabled = true,
        autoSync = true,
        debugMode = false,
        showProtocolMessages = false,
    },
}

addon.settings = {}

-- ============================================================
-- Utility Functions
-- ============================================================

-- Safe print with addon prefix
function addon:Print(msg, forceShow)
    if forceShow or (self.settings.communication and self.settings.communication.debugMode) then
        print("|cff00ff00[DC-QoS]|r " .. tostring(msg))
    end
end

-- Debug print (only when debug mode enabled)
function addon:Debug(msg)
    if self.settings.communication and self.settings.communication.debugMode then
        print("|cff888888[DC-QoS Debug]|r " .. tostring(msg))
    end
end

-- 3.3.5a compatible delayed call
function addon:DelayedCall(delay, func)
    local frame = CreateFrame("Frame")
    local elapsed = 0
    frame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed >= delay then
            self:SetScript("OnUpdate", nil)
            func()
        end
    end)
end

-- Deep copy table
function addon:DeepCopy(orig)
    local copy
    if type(orig) == 'table' then
        copy = {}
        for k, v in pairs(orig) do
            copy[self:DeepCopy(k)] = self:DeepCopy(v)
        end
    else
        copy = orig
    end
    return copy
end

-- Merge tables (shallow)
function addon:MergeDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if target[k] == nil then
            if type(v) == "table" then
                target[k] = self:DeepCopy(v)
            else
                target[k] = v
            end
        elseif type(v) == "table" and type(target[k]) == "table" then
            self:MergeDefaults(target[k], v)
        end
    end
end

-- ============================================================
-- Module Registration
-- ============================================================

-- Register a new module
-- @param name: string - Module identifier
-- @param config: table - Module configuration
--   .displayName: string - Display name for UI
--   .icon: string - Icon texture path (optional)
--   .defaults: table - Default settings for this module
--   .OnInitialize: function - Called when addon initializes
--   .OnEnable: function - Called when module is enabled
--   .OnDisable: function - Called when module is disabled
--   .CreateSettings: function(panel) - Called to create settings UI
function addon:RegisterModule(name, config)
    if self.modules[name] then
        self:Debug("Module already registered: " .. name)
        return
    end
    
    self.modules[name] = config
    table.insert(self.moduleOrder, name)
    
    -- Merge module defaults into main defaults
    if config.defaults then
        for k, v in pairs(config.defaults) do
            if self.defaults[k] == nil then
                self.defaults[k] = v
            end
        end
    end
    
    self:Debug("Registered module: " .. name)
end

-- Get a registered module
function addon:GetModule(name)
    return self.modules[name]
end

-- Enable a module
function addon:EnableModule(name)
    local module = self.modules[name]
    if module and module.OnEnable then
        module.OnEnable()
    end
end

-- Disable a module
function addon:DisableModule(name)
    local module = self.modules[name]
    if module and module.OnDisable then
        module.OnDisable()
    end
end

-- ============================================================
-- Event System
-- ============================================================

-- Register event callback
function addon:RegisterEvent(event, callback)
    if not self.events[event] then
        self.events[event] = {}
    end
    table.insert(self.events[event], callback)
end

-- Fire event to all registered callbacks
function addon:FireEvent(event, ...)
    if self.events[event] then
        for _, callback in ipairs(self.events[event]) do
            callback(...)
        end
    end
end

-- ============================================================
-- Settings Management
-- ============================================================

function addon:LoadSettings()
    -- Load from SavedVariables
    if DCQoSDB then
        self.settings = DCQoSDB
        -- Merge any new defaults
        self:MergeDefaults(self.settings, self.defaults)
    else
        self.settings = self:DeepCopy(self.defaults)
    end
end

function addon:SaveSettings()
    DCQoSDB = self.settings
end

function addon:GetSetting(path)
    -- path can be "tooltips.showItemId" or just "minimapButton"
    local parts = {strsplit(".", path)}
    local current = self.settings
    
    for _, part in ipairs(parts) do
        if type(current) ~= "table" then
            return nil
        end
        current = current[part]
    end
    
    return current
end

function addon:SetSetting(path, value)
    local parts = {strsplit(".", path)}
    local current = self.settings
    
    for i = 1, #parts - 1 do
        if type(current[parts[i]]) ~= "table" then
            current[parts[i]] = {}
        end
        current = current[parts[i]]
    end
    
    current[parts[#parts]] = value
    self:SaveSettings()
    
    -- Fire setting changed event
    self:FireEvent("SETTING_CHANGED", path, value)
end

-- ============================================================
-- Initialization
-- ============================================================

function addon:Initialize()
    if self.initialized then return end
    
    self:Print("Initializing DC-QoS v" .. self.version, true)
    
    -- Load settings from SavedVariables
    self:LoadSettings()
    
    -- Initialize all registered modules
    for _, name in ipairs(self.moduleOrder) do
        local module = self.modules[name]
        if module.OnInitialize then
            local success, err = pcall(module.OnInitialize)
            if not success then
                self:Print("Error initializing module " .. name .. ": " .. tostring(err), true)
            else
                self:Debug("Initialized module: " .. name)
            end
        end
    end
    
    -- Enable modules based on settings
    for _, name in ipairs(self.moduleOrder) do
        local module = self.modules[name]
        local settingKey = module.settingKey or name:lower()
        local moduleSettings = self.settings[settingKey]
        
        if not moduleSettings or moduleSettings.enabled ~= false then
            self:EnableModule(name)
        end
    end
    
    self.initialized = true
    self:Print("Loaded successfully! Type |cffffd700/dcqos|r or find in Interface → AddOns.", true)
end

-- ============================================================
-- Main Event Frame
-- ============================================================

local eventFrame = CreateFrame("Frame", "DCQoSEventFrame", UIParent)
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "ADDON_LOADED" then
        if arg1 == "DC-QOS" then
            -- Wait for other DC addons to load
            addon:DelayedCall(0.5, function()
                addon:Initialize()
            end)
        end
    elseif event == "PLAYER_LOGIN" then
        -- Re-sync with server after login
        addon:FireEvent("PLAYER_LOGIN")
    elseif event == "PLAYER_LOGOUT" then
        addon:SaveSettings()
        addon:FireEvent("PLAYER_LOGOUT")
    elseif event == "PLAYER_ENTERING_WORLD" then
        addon:FireEvent("PLAYER_ENTERING_WORLD")
    end
end)

-- ============================================================
-- Slash Commands
-- ============================================================

SLASH_DCQOS1 = "/dcqos"
SLASH_DCQOS2 = "/qos"
SlashCmdList["DCQOS"] = function(msg)
    msg = msg and strlower(strtrim(msg)) or ""
    
    if msg == "" or msg == "options" or msg == "settings" then
        -- Open settings panel
        if addon.ToggleSettings then
            addon:ToggleSettings()
        else
            InterfaceOptionsFrame_OpenToCategory("DC-QoS")
            InterfaceOptionsFrame_OpenToCategory("DC-QoS")
        end
    elseif msg == "debug" then
        addon.settings.communication.debugMode = not addon.settings.communication.debugMode
        addon:SaveSettings()
        addon:Print("Debug mode: " .. (addon.settings.communication.debugMode and "ENABLED" or "DISABLED"), true)
    elseif msg == "reset" then
        addon.settings = addon:DeepCopy(addon.defaults)
        addon:SaveSettings()
        addon:Print("Settings reset to defaults.", true)
        ReloadUI()
    elseif msg == "reload" then
        ReloadUI()
    elseif msg == "help" then
        addon:Print("Commands:", true)
        print("  |cffffd700/dcqos|r - Open settings panel")
        print("  |cffffd700/dcqos debug|r - Toggle debug mode")
        print("  |cffffd700/dcqos reset|r - Reset all settings to defaults")
        print("  |cffffd700/dcqos reload|r - Reload UI")
        print("  |cffffd700/dcqos help|r - Show this help message")
    else
        addon:Print("Unknown command. Type |cffffd700/dcqos help|r for help.", true)
    end
end
