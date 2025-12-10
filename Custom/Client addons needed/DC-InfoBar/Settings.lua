--[[
    DC-InfoBar Settings
    Saved variables and default configuration
]]

local addonName = "DC-InfoBar"
local DCInfoBar = DCInfoBar or {}
_G.DCInfoBar = DCInfoBar

-- Default saved variables
local DEFAULTS = {
    -- Bar settings
    bar = {
        position = "top",           -- top, bottom
        height = 22,
        backgroundColor = { 0.04, 0.04, 0.05, 0.85 },
        borderColor = { 0.2, 0.5, 0.8, 0.5 },
        locked = true,
        showBackground = true,
        scale = 1.0,
        strata = "HIGH",
    },
    
    -- Global settings
    global = {
        enabled = true,
        hideInCombat = false,
        hideInInstance = false,
        showLabels = true,
        showIcons = true,
        updateInterval = 1.0,
    },
    
    -- Plugin enable/disable and per-plugin settings
    plugins = {
        -- Server plugins
        ["DCInfoBar_Season"] = {
            enabled = true,
            side = "left",
            priority = 10,
            showLabel = true,
            showIcon = true,
            showTokens = true,
        },
        ["DCInfoBar_Keystone"] = {
            enabled = true,
            side = "left",
            priority = 20,
            showLabel = false,
            showIcon = true,
            showDepleted = true,
        },
        ["DCInfoBar_Affixes"] = {
            enabled = true,
            side = "left",
            priority = 30,
            showLabel = false,
            showIcons = true,    -- Show 3 small icons
            textMode = false,    -- Show as "Fort/Burst/Storm"
        },
        ["DCInfoBar_WorldBoss"] = {
            enabled = true,
            side = "left",
            priority = 40,
            showLabel = false,
            showIcon = true,
            showOnlyActive = false,
        },
        ["DCInfoBar_Events"] = {
            enabled = true,
            side = "right",
            priority = 890,
            showLabel = false,
            hideWhenNone = true,
            showZone = true,
            showTimer = true,
            flashCritical = true,
            maxTooltipEntries = 4,
        },
        ["DCInfoBar_Location"] = {
            enabled = true,
            side = "left",
            priority = 60,
            showLabel = false,
            showIcon = true,
            showCoordinates = false,
            showSubzone = true,
        },
        
        -- Character plugins (right side)
        ["DCInfoBar_Gold"] = {
            enabled = true,
            side = "right",
            priority = 900,
            showLabel = false,
            showIcon = true,
            showSilverCopper = false,
            showSessionChange = true,
        },
        ["DCInfoBar_Durability"] = {
            enabled = true,
            side = "right",
            priority = 910,
            showLabel = false,
            showIcon = true,
            showRepairCost = false,
            flashOnLow = true,
            lowThreshold = 25,
        },
        ["DCInfoBar_Bags"] = {
            enabled = true,
            side = "right",
            priority = 920,
            showLabel = false,
            showIcon = true,
            showAsPercent = false,
            warnWhenFull = true,
        },
        ["DCInfoBar_Performance"] = {
            enabled = true,
            side = "right",
            priority = 930,
            showLabel = false,
            showFPS = true,
            showLatency = true,
            showMemory = false,
        },
        ["DCInfoBar_Clock"] = {
            enabled = true,
            side = "right",
            priority = 999,
            showLabel = false,
            use24Hour = true,
            showSeconds = false,
            showDate = false,
            useServerTime = false,
        },
    },
    
    -- Plugin order (for drag-drop reordering in future)
    pluginOrder = {
        left = { "Season", "Keystone", "Affixes", "WorldBoss", "Events", "Location" },
        right = { "Gold", "Durability", "Bags", "Performance", "Clock" },
    },
    
    -- Communication / Debug settings
    communication = {
        showDebugMessages = false,
        logRequests = false,
        logResponses = false,
        testMode = false,
    },
    
    -- Debug
    debug = false,
}

-- Initialize saved variables
function DCInfoBar:InitializeDB()
    if not DCInfoBarDB then
        DCInfoBarDB = {}
    end
    
    -- Deep copy defaults for missing values
    self.db = self:MergeDefaults(DCInfoBarDB, DEFAULTS)
    
    -- Store reference back
    DCInfoBarDB = self.db
end

-- Deep merge defaults into saved vars
function DCInfoBar:MergeDefaults(saved, defaults)
    if type(defaults) ~= "table" then
        return saved ~= nil and saved or defaults
    end
    
    if type(saved) ~= "table" then
        saved = {}
    end
    
    for k, v in pairs(defaults) do
        if saved[k] == nil then
            if type(v) == "table" then
                saved[k] = self:DeepCopy(v)
            else
                saved[k] = v
            end
        elseif type(v) == "table" and type(saved[k]) == "table" then
            saved[k] = self:MergeDefaults(saved[k], v)
        end
    end
    
    return saved
end

-- Deep copy table
function DCInfoBar:DeepCopy(orig)
    local copy
    if type(orig) == "table" then
        copy = {}
        for k, v in pairs(orig) do
            copy[self:DeepCopy(k)] = self:DeepCopy(v)
        end
    else
        copy = orig
    end
    return copy
end

-- Get plugin setting
function DCInfoBar:GetPluginSetting(pluginId, key)
    if not self.db or not self.db.plugins then return nil end
    
    local pluginSettings = self.db.plugins[pluginId]
    if not pluginSettings then return nil end
    
    return pluginSettings[key]
end

-- Set plugin setting
function DCInfoBar:SetPluginSetting(pluginId, key, value)
    if not self.db or not self.db.plugins then return end
    
    if not self.db.plugins[pluginId] then
        self.db.plugins[pluginId] = {}
    end
    
    self.db.plugins[pluginId][key] = value
    
    -- Notify plugin of setting change
    if self.plugins and self.plugins[pluginId] and self.plugins[pluginId].OnSettingChanged then
        self.plugins[pluginId]:OnSettingChanged(key, value)
    end
end

-- Is plugin enabled?
function DCInfoBar:IsPluginEnabled(pluginId)
    return self:GetPluginSetting(pluginId, "enabled") ~= false
end

-- Get bar setting
function DCInfoBar:GetBarSetting(key)
    if not self.db or not self.db.bar then return nil end
    return self.db.bar[key]
end

-- Set bar setting
function DCInfoBar:SetBarSetting(key, value)
    if not self.db or not self.db.bar then return end
    self.db.bar[key] = value
    
    -- Refresh bar if needed
    if self.bar and self.bar.RefreshSettings then
        self.bar:RefreshSettings()
    end
end

-- Reset to defaults
function DCInfoBar:ResetToDefaults()
    DCInfoBarDB = self:DeepCopy(DEFAULTS)
    self.db = DCInfoBarDB
    
    -- Refresh everything
    if self.bar then
        self.bar:RefreshSettings()
    end
    self:RefreshAllPlugins()
    
    self:Print("Settings reset to defaults.")
end

-- Get defaults (for options panel)
function DCInfoBar:GetDefaults()
    return DEFAULTS
end
