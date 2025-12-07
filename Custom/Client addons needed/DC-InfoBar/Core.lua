--[[
    DC-InfoBar Core
    Main framework and plugin system
]]

local addonName = "DC-InfoBar"
local DCInfoBar = DCInfoBar or {}
_G.DCInfoBar = DCInfoBar

-- ============================================================================
-- Core Variables
-- ============================================================================

DCInfoBar.VERSION = "1.0.0"
DCInfoBar.plugins = {}              -- Registered plugins
DCInfoBar.activePlugins = { left = {}, right = {} }
DCInfoBar.serverData = {}           -- Cached server data

-- DCAddonProtocol reference
local DC = nil

-- ============================================================================
-- Server Data Cache (populated by DCAddonProtocol)
-- ============================================================================

DCInfoBar.serverData = {
    -- Seasonal data
    season = {
        id = 0,
        name = "Unknown",
        weeklyTokens = 0,
        weeklyCap = 500,
        weeklyEssence = 0,
        essenceCap = 200,
        totalTokens = 0,
        endsIn = 0,           -- Seconds until season ends
        weeklyReset = 0,      -- Seconds until weekly reset
    },
    
    -- Keystone data
    keystone = {
        hasKey = false,
        dungeonId = 0,
        dungeonName = "None",
        dungeonAbbrev = "",
        level = 0,
        depleted = false,
        weeklyBest = 0,
        seasonBest = 0,
    },
    
    -- Affixes data
    affixes = {
        ids = {},             -- Array of spell IDs
        names = {},           -- Array of names
        descriptions = {},    -- Array of descriptions
        resetIn = 0,          -- Seconds until reset
    },
    
    -- World boss timers
    worldBosses = {
        -- { name = "Oondasta", zone = "Giant Isles", status = "spawning", spawnIn = 3600, hp = nil }
    },
    
    -- Zone events
    events = {
        -- { name = "Zandalari Invasion", zone = "Giant Isles", type = "invasion", wave = 2, maxWaves = 4, timeRemaining = 300 }
    },
}

-- ============================================================================
-- Plugin Registration
-- ============================================================================

function DCInfoBar:RegisterPlugin(plugin)
    if not plugin.id then
        self:Print("Error: Plugin must have an id")
        return
    end
    
    -- Set defaults
    plugin.side = plugin.side or "left"
    plugin.priority = plugin.priority or 500
    plugin.type = plugin.type or "text"
    plugin.updateInterval = plugin.updateInterval or 1.0
    plugin._elapsed = 0
    
    -- Store in registry
    self.plugins[plugin.id] = plugin
    
    self:Debug("Registered plugin: " .. plugin.id)
end

function DCInfoBar:ActivatePlugin(pluginId)
    local plugin = self.plugins[pluginId]
    if not plugin then return end
    
    -- Check if enabled in settings
    if not self:IsPluginEnabled(pluginId) then
        return
    end
    
    -- Get side from settings or plugin default
    local side = self:GetPluginSetting(pluginId, "side") or plugin.side
    plugin.side = side
    
    -- Get priority from settings or plugin default
    local priority = self:GetPluginSetting(pluginId, "priority") or plugin.priority
    plugin.priority = priority
    
    -- Add to active list
    table.insert(self.activePlugins[side], plugin)
    
    -- Sort by priority
    table.sort(self.activePlugins[side], function(a, b)
        return a.priority < b.priority
    end)
    
    -- Create button for plugin
    if self.bar then
        self.bar:CreatePluginButton(plugin)
    end
    
    -- Call plugin's OnActivate if exists
    if plugin.OnActivate then
        plugin:OnActivate()
    end
    
    self:Debug("Activated plugin: " .. pluginId)
end

function DCInfoBar:DeactivatePlugin(pluginId)
    local plugin = self.plugins[pluginId]
    if not plugin then return end
    
    -- Remove from active list
    for side, list in pairs(self.activePlugins) do
        for i, p in ipairs(list) do
            if p.id == pluginId then
                table.remove(list, i)
                break
            end
        end
    end
    
    -- Hide button
    if plugin.button then
        plugin.button:Hide()
    end
    
    -- Call plugin's OnDeactivate if exists
    if plugin.OnDeactivate then
        plugin:OnDeactivate()
    end
end

function DCInfoBar:RefreshAllPlugins()
    -- Clear active lists
    self.activePlugins = { left = {}, right = {} }
    
    -- Re-activate all enabled plugins
    for id, plugin in pairs(self.plugins) do
        self:ActivatePlugin(id)
    end
    
    -- Refresh bar layout
    if self.bar then
        self.bar:RefreshLayout()
    end
end

-- ============================================================================
-- Server Communication (DCAddonProtocol)
-- ============================================================================

-- Season Opcodes (matches server-side dc_addon_season.cpp)
local SEAS_CMSG_GET_CURRENT = 0x01
local SEAS_SMSG_CURRENT     = 0x10
local SEAS_SMSG_PROGRESS    = 0x12

-- M+ Opcodes (if DC.Opcode.MPlus doesn't exist)
local MPLUS_CMSG_GET_KEY_INFO = 0x01
local MPLUS_SMSG_KEY_INFO     = 0x10

function DCInfoBar:SetupServerCommunication()
    DC = rawget(_G, "DCAddonProtocol")
    
    if not DC then
        self:Debug("DCAddonProtocol not found - server features disabled")
        return false
    end
    
    self:Debug("DCAddonProtocol found - registering handlers")
    
    -- Register handlers for server data
    
    -- Season info (using direct opcodes - not DC.Opcode.Season which doesn't exist)
    DC:RegisterHandler("SEAS", SEAS_SMSG_CURRENT, function(data)
        DCInfoBar:HandleSeasonData(data)
    end)
    
    -- Also handle progress data for more detailed season info
    DC:RegisterHandler("SEAS", SEAS_SMSG_PROGRESS, function(data)
        DCInfoBar:HandleSeasonProgressData(data)
    end)
    
    -- Keystone info (from Group Finder)
    if DC.GroupFinderOpcodes and DC.GroupFinderOpcodes.SMSG_KEYSTONE_INFO then
        DC:RegisterHandler("GRPF", DC.GroupFinderOpcodes.SMSG_KEYSTONE_INFO, function(data)
            DCInfoBar:HandleKeystoneData(data)
        end)
    end
    
    -- Keystone info (from MythicPlus module)
    DC:RegisterHandler("MPLUS", MPLUS_SMSG_KEY_INFO, function(data)
        DCInfoBar:HandleKeystoneData(data)
    end)
    
    -- We'll also hook into DCMythicPlusHUD if available for affix data
    
    return true
end

function DCInfoBar:RequestServerData()
    if not DC then 
        DC = rawget(_G, "DCAddonProtocol")
    end
    
    if not DC then
        self:Debug("DCAddonProtocol not available for RequestServerData")
        return
    end
    
    self:Debug("Requesting server data...")
    
    -- Request seasonal info (using direct opcode)
    DC:Request("SEAS", SEAS_CMSG_GET_CURRENT, {})
    DC:Request("SEAS", 0x03, {})  -- Also try CMSG_GET_PROGRESS
    
    -- Request keystone info from both modules for redundancy
    if DC.GroupFinderOpcodes and DC.GroupFinderOpcodes.CMSG_GET_MY_KEYSTONE then
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_GET_MY_KEYSTONE, {})
    end
    
    DC:Request("MPLUS", MPLUS_CMSG_GET_KEY_INFO, {})
    
    -- Request hotspot list
    DC:Request("SPOT", 0x01, {})
    if DC.Hotspot and DC.Hotspot.GetList then
        DC.Hotspot.GetList()
    end
    
    -- Request prestige info
    DC:Request("PRES", 0x01, {})
end

-- Handle season progress data (SMSG 0x12)
function DCInfoBar:HandleSeasonProgressData(data)
    if not data then return end
    
    -- Update season data with progress info
    local season = self.serverData.season
    
    if data.seasonId or data.id then
        season.id = data.seasonId or data.id
    end
    if data.tokens then
        season.weeklyTokens = data.tokens
    end
    if data.weeklyTokens then
        season.weeklyTokens = data.weeklyTokens
    end
    if data.essence then
        season.weeklyEssence = data.essence
    end
    if data.weeklyEssence then
        season.weeklyEssence = data.weeklyEssence
    end
    if data.tokenCap then
        season.weeklyCap = data.tokenCap
    end
    if data.essenceCap then
        season.essenceCap = data.essenceCap
    end
    if data.totalTokens then
        season.totalTokens = data.totalTokens
    end
    
    -- Notify season plugin
    if self.plugins["DCInfoBar_Season"] and self.plugins["DCInfoBar_Season"].OnServerData then
        self.plugins["DCInfoBar_Season"]:OnServerData(season)
    end
    
    self:Debug("Season progress data received")
end

-- Handle incoming season data
function DCInfoBar:HandleSeasonData(data)
    if not data then return end
    
    self.serverData.season = {
        id = data.seasonId or data.id or 0,
        name = data.seasonName or data.name or "Unknown",
        weeklyTokens = data.weeklyTokens or 0,
        weeklyCap = data.weeklyCap or 500,
        weeklyEssence = data.weeklyEssence or 0,
        essenceCap = data.essenceCap or 200,
        totalTokens = data.totalTokens or 0,
        endsIn = data.endsIn or 0,
        weeklyReset = data.weeklyReset or 0,
    }
    
    -- Notify season plugin
    if self.plugins["DCInfoBar_Season"] and self.plugins["DCInfoBar_Season"].OnServerData then
        self.plugins["DCInfoBar_Season"]:OnServerData(self.serverData.season)
    end
    
    self:Debug("Season data received: " .. self.serverData.season.name)
end

-- Handle incoming keystone data
function DCInfoBar:HandleKeystoneData(data)
    if not data then return end
    
    self.serverData.keystone = {
        hasKey = (data.level and data.level > 0) or false,
        dungeonId = data.dungeonId or data.mapId or 0,
        dungeonName = data.dungeonName or data.name or "None",
        dungeonAbbrev = data.abbreviation or data.abbrev or "",
        level = data.level or data.keyLevel or 0,
        depleted = data.depleted or false,
        weeklyBest = data.weeklyBest or 0,
        seasonBest = data.seasonBest or 0,
    }
    
    -- Generate abbreviation if not provided
    if self.serverData.keystone.dungeonName and self.serverData.keystone.dungeonAbbrev == "" then
        self.serverData.keystone.dungeonAbbrev = self:GenerateDungeonAbbrev(self.serverData.keystone.dungeonName)
    end
    
    -- Notify keystone plugin
    if self.plugins["DCInfoBar_Keystone"] and self.plugins["DCInfoBar_Keystone"].OnServerData then
        self.plugins["DCInfoBar_Keystone"]:OnServerData(self.serverData.keystone)
    end
    
    self:Debug("Keystone data received: +" .. self.serverData.keystone.level .. " " .. self.serverData.keystone.dungeonAbbrev)
end

-- Handle incoming affix data
function DCInfoBar:HandleAffixData(data)
    if not data then return end
    
    self.serverData.affixes = {
        ids = data.affixIds or data.ids or {},
        names = data.affixNames or data.names or {},
        descriptions = data.descriptions or {},
        resetIn = data.resetIn or 0,
    }
    
    -- Notify affixes plugin
    if self.plugins["DCInfoBar_Affixes"] and self.plugins["DCInfoBar_Affixes"].OnServerData then
        self.plugins["DCInfoBar_Affixes"]:OnServerData(self.serverData.affixes)
    end
end

-- Generate dungeon abbreviation from name
function DCInfoBar:GenerateDungeonAbbrev(name)
    if not name or name == "" then return "" end
    
    -- Known abbreviations
    local known = {
        ["Utgarde Keep"] = "UK",
        ["Utgarde Pinnacle"] = "UP",
        ["The Nexus"] = "Nex",
        ["The Oculus"] = "Occ",
        ["Halls of Stone"] = "HoS",
        ["Halls of Lightning"] = "HoL",
        ["The Culling of Stratholme"] = "CoS",
        ["Azjol-Nerub"] = "AN",
        ["Ahn'kahet"] = "AK",
        ["Drak'Tharon Keep"] = "DTK",
        ["Gundrak"] = "GD",
        ["The Violet Hold"] = "VH",
        ["Trial of the Champion"] = "ToC",
        ["Forge of Souls"] = "FoS",
        ["Pit of Saron"] = "PoS",
        ["Halls of Reflection"] = "HoR",
    }
    
    if known[name] then
        return known[name]
    end
    
    -- Generate from first letters of words
    local abbrev = ""
    for word in string.gmatch(name, "%S+") do
        -- Skip common words
        if word ~= "The" and word ~= "of" and word ~= "the" then
            abbrev = abbrev .. string.sub(word, 1, 1)
        end
    end
    
    return string.upper(abbrev)
end

-- ============================================================================
-- Update System
-- ============================================================================

function DCInfoBar:OnUpdate(elapsed)
    if not self.db or not self.db.global or not self.db.global.enabled then
        return
    end
    
    -- Hide in combat if configured
    if self.db.global.hideInCombat and UnitAffectingCombat("player") then
        if self.bar and self.bar:IsShown() then
            self.bar:Hide()
        end
        return
    elseif self.bar and not self.bar:IsShown() and self.db.global.enabled then
        self.bar:Show()
    end
    
    -- Update each active plugin
    for _, side in ipairs({"left", "right"}) do
        for _, plugin in ipairs(self.activePlugins[side]) do
            if plugin.button and plugin.button:IsShown() then
                plugin._elapsed = (plugin._elapsed or 0) + elapsed
                
                if plugin._elapsed >= (plugin.updateInterval or 1.0) then
                    plugin._elapsed = 0
                    
                    if plugin.OnUpdate then
                        local success, label, value, color = pcall(plugin.OnUpdate, plugin, elapsed)
                        if success then
                            self.bar:UpdatePluginText(plugin, label, value, color)
                        end
                    end
                end
            end
        end
    end
end

-- ============================================================================
-- Initialization
-- ============================================================================

function DCInfoBar:Initialize()
    -- Initialize saved variables
    self:InitializeDB()
    
    -- Setup server communication
    self:SetupServerCommunication()
    
    -- Create the bar
    if self.CreateBar then
        self.bar = self:CreateBar()
    end
    
    -- Activate all enabled plugins
    for id, plugin in pairs(self.plugins) do
        if self:IsPluginEnabled(id) then
            self:ActivatePlugin(id)
        end
    end
    
    -- Refresh bar layout
    if self.bar then
        self.bar:RefreshLayout()
    end
    
    -- Create update frame
    local updateFrame = CreateFrame("Frame")
    local updateElapsed = 0
    updateFrame:SetScript("OnUpdate", function(_, elapsed)
        updateElapsed = updateElapsed + elapsed
        if updateElapsed >= 0.1 then  -- Update at 10 FPS max
            DCInfoBar:OnUpdate(updateElapsed)
            updateElapsed = 0
        end
    end)
    
    -- Request server data after a short delay (wait for connection)
    C_Timer.After(2, function()
        DCInfoBar:RequestServerData()
    end)
    
    -- Setup slash commands
    self:SetupSlashCommands()
    
    self:Print("DC-InfoBar v" .. self.VERSION .. " loaded. Type /infobar for options.")
end

-- ============================================================================
-- Slash Commands
-- ============================================================================

function DCInfoBar:SetupSlashCommands()
    SLASH_DCINFOBAR1 = "/infobar"
    SLASH_DCINFOBAR2 = "/dcinfo"
    SLASH_DCINFOBAR3 = "/dcib"
    
    SlashCmdList["DCINFOBAR"] = function(msg)
        local cmd = string.lower(msg or "")
        
        if cmd == "" or cmd == "options" or cmd == "config" then
            self:OpenOptions()
        elseif cmd == "toggle" then
            self.db.global.enabled = not self.db.global.enabled
            if self.bar then
                self.bar:SetShown(self.db.global.enabled)
            end
            self:Print("InfoBar " .. (self.db.global.enabled and "enabled" or "disabled"))
        elseif cmd == "reset" then
            self:ResetToDefaults()
        elseif cmd == "debug" then
            self.db.debug = not self.db.debug
            self:Print("Debug mode " .. (self.db.debug and "enabled" or "disabled"))
        elseif cmd == "refresh" then
            self:RequestServerData()
            self:Print("Refreshing server data...")
        else
            self:Print("Commands:")
            self:Print("  /infobar - Open options")
            self:Print("  /infobar toggle - Show/hide bar")
            self:Print("  /infobar reset - Reset to defaults")
            self:Print("  /infobar debug - Toggle debug mode")
            self:Print("  /infobar refresh - Refresh server data")
        end
    end
end

function DCInfoBar:OpenOptions()
    if InterfaceOptionsFrame and InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
        InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)  -- Called twice due to WoW bug
    elseif self.optionsPanel then
        self.optionsPanel:Show()
    else
        self:Print("Options panel not yet initialized.")
    end
end

-- ============================================================================
-- Event Handler
-- ============================================================================

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(0.5, function()
            DCInfoBar:Initialize()
        end)
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Refresh location data
        if DCInfoBar.plugins["DCInfoBar_Location"] then
            DCInfoBar.plugins["DCInfoBar_Location"]._elapsed = 999  -- Force update
        end
    end
end)
