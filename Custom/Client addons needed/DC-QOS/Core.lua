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
-- Reload UI Prompt
-- ============================================================

addon._reloadUIPending = false
addon._reloadUIPrefixes = addon._reloadUIPrefixes or {}

function addon:RegisterReloadUIPrefix(prefix)
    if not prefix or prefix == "" then return end
    table.insert(self._reloadUIPrefixes, prefix)
end

local function EnsureReloadPopup()
    if StaticPopupDialogs and not StaticPopupDialogs["DCQOS_RELOAD_UI"] then
        StaticPopupDialogs["DCQOS_RELOAD_UI"] = {
            text = "DC-QoS: Some changes require a UI reload to take effect.",
            button1 = RELOADUI or "Reload UI",
            button2 = LATER or "Later",
            OnAccept = function()
                ReloadUI()
            end,
            OnCancel = function()
                -- Allow future prompts in case the user keeps changing settings.
                if DCQOS then
                    DCQOS._reloadUIPending = false
                end
            end,
            timeout = 0,
            whileDead = 1,
            hideOnEscape = 1,
            preferredIndex = 3,
        }
    end
end

function addon:PromptReloadUI()
    if self._reloadUIPending then return end
    self._reloadUIPending = true
    EnsureReloadPopup()
    if StaticPopup_Show then
        local shown = StaticPopup_Show("DCQOS_RELOAD_UI")
        if not shown then
            self._reloadUIPending = false
        end
    else
        self._reloadUIPending = false
    end
end

-- ============================================================
-- Settings Framework
-- ============================================================
addon.defaults = {
    -- Global settings
    minimapButton = true,

    -- Profiles
    profiles = {
        enabled = true,
        defaultProfile = "Default",
    },
    
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
        autoAcceptQuests = false,
        autoTurnInQuests = false,
    },
    
    -- Cooldown settings
    cooldowns = {
        enabled = true,
        minDuration = 2, -- Minimum duration to show text
        fontSize = 18,
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

    -- Action Bars
    actionBars = {
        enabled = true,
        mode = "blizzard", -- blizzard | custom
        scale = 1.0,
        buttonSize = 32,
        spacing = 4,
        showMainBar = true,
        showBottomLeft = true,
        showBottomRight = true,
        showRightBar1 = true,
        showRightBar2 = true,
        customAnchor = { point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = 40 },
    },

    -- Minimap
    minimap = {
        enabled = true,
        style = "round", -- round | square
        size = 160,
        point = "TOPRIGHT",
        relPoint = "TOPRIGHT",
        x = -2,
        y = -32,
        useBlizzardPosition = true,
        useDcFrame = true,
        fillFrame = true,
        disableRotate = true,
        hideZoom = false,
        hideTracking = true,
        hideClock = false,
        hideCalendar = true,
        hideWorldMapButton = true,
        mouseWheelZoom = true,
        buttonSpacing = 22,
    },

    -- Keybinds (hover-to-bind)
    keybinds = {
        enabled = true,
        hoverBind = true,
        onlyWhenBindingMode = true,
    },
    
    -- Communication settings (server sync)
    communication = {
        enabled = true,
        autoSync = true,
        debugMode = false,
        showProtocolMessages = false,

        -- Debug output routing
        routeDcDebugToTab = true,
        captureDcDebugFromOtherAddons = true,
        dcDebugTabName = "DCDebug",
    },
}

addon.settings = {}
addon.db = nil
addon.activeProfile = nil
addon.keybindMode = false

local function GetCharacterKey()
    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName() or "Unknown"
    return name .. "-" .. realm
end

local function EnsureProfileTables(db, defaults)
    if type(db.profiles) ~= "table" then
        db.profiles = {}
    end
    if type(db.profileKeys) ~= "table" then
        db.profileKeys = {}
    end
    if not db.globalProfile or db.globalProfile == "" then
        db.globalProfile = (defaults.profiles and defaults.profiles.defaultProfile) or "Default"
    end
    if not db.profiles[db.globalProfile] then
        db.profiles[db.globalProfile] = addon:DeepCopy(defaults)
    end
end

function addon:GetActiveProfileName()
    if not self.db then return nil end
    local charKey = GetCharacterKey()
    return self.db.profileKeys[charKey] or self.db.globalProfile
end

function addon:SetActiveProfile(name, perCharacter)
    if not self.db or not name or name == "" then return end
    if not self.db.profiles[name] then
        self.db.profiles[name] = self:DeepCopy(self.defaults)
    end
    if perCharacter then
        self.db.profileKeys[GetCharacterKey()] = name
    else
        self.db.globalProfile = name
    end
    self.activeProfile = name
    self.settings = self.db.profiles[name]
    self:MergeDefaults(self.settings, self.defaults)
    self:SaveSettings()
    self:PromptReloadUI()
end

function addon:CreateProfile(name, copyFrom)
    if not self.db or not name or name == "" then return false end
    if self.db.profiles[name] then return false end
    if copyFrom and self.db.profiles[copyFrom] then
        self.db.profiles[name] = self:DeepCopy(self.db.profiles[copyFrom])
    else
        self.db.profiles[name] = self:DeepCopy(self.defaults)
    end
    self:SaveSettings()
    return true
end

function addon:DeleteProfile(name)
    if not self.db or not name or name == "" then return false end
    if name == (self.defaults.profiles and self.defaults.profiles.defaultProfile) then return false end
    if not self.db.profiles[name] then return false end
    self.db.profiles[name] = nil
    if self.activeProfile == name then
        self:SetActiveProfile(self.db.globalProfile or self.defaults.profiles.defaultProfile, true)
    end
    self:SaveSettings()
    return true
end

local function EscapeProfileValue(value)
    value = tostring(value)
    value = value:gsub("\\", "\\\\")
    value = value:gsub("\n", "\\n")
    value = value:gsub("=", "\\=")
    value = value:gsub(";", "\\;")
    return value
end

local function UnescapeProfileValue(value)
    value = value:gsub("\\;", ";")
    value = value:gsub("\\=", "=")
    value = value:gsub("\\n", "\n")
    value = value:gsub("\\\\", "\\")
    return value
end

local function SerializeTable(tbl, prefix, out)
    for k, v in pairs(tbl) do
        local key = prefix ~= "" and (prefix .. "." .. k) or k
        if type(v) == "table" then
            SerializeTable(v, key, out)
        elseif type(v) ~= "function" then
            table.insert(out, key .. "=" .. EscapeProfileValue(v))
        end
    end
end

function addon:ExportProfile(name)
    if not self.db or not self.db.profiles[name] then return nil end
    local out = {}
    SerializeTable(self.db.profiles[name], "", out)
    return table.concat(out, ";")
end

local function ApplyFlatKey(dest, path, value)
    local cur = dest
    local parts = {}
    for part in string.gmatch(path, "[^%.]+") do
        table.insert(parts, part)
    end
    for i = 1, #parts - 1 do
        local p = parts[i]
        cur[p] = cur[p] or {}
        cur = cur[p]
    end
    local last = parts[#parts]
    local num = tonumber(value)
    if value == "true" then
        cur[last] = true
    elseif value == "false" then
        cur[last] = false
    elseif num ~= nil then
        cur[last] = num
    else
        cur[last] = value
    end
end

function addon:ImportProfile(name, data)
    if not name or name == "" or not data or data == "" then return false end
    local profile = self:DeepCopy(self.defaults)
    for entry in string.gmatch(data, "[^;]+") do
        local key, val = entry:match("^(.-)=(.*)$")
        if key and val then
            ApplyFlatKey(profile, key, UnescapeProfileValue(val))
        end
    end
    self.db.profiles[name] = profile
    self:SaveSettings()
    return true
end

-- ============================================================
-- Utility Functions
-- ============================================================

local function FindChatWindowIndexByName(windowName)
    if not windowName or windowName == "" then return nil end
    if not GetChatWindowInfo then return nil end
    for i = 1, NUM_CHAT_WINDOWS do
        local name = GetChatWindowInfo(i)
        if name == windowName then
            return i
        end
    end
    return nil
end

function addon:GetChatFrameByWindowName(windowName)
    local index = FindChatWindowIndexByName(windowName)
    if not index then return nil end
    return _G["ChatFrame" .. index]
end

function addon:EnsureChatWindow(windowName)
    if not windowName or windowName == "" then return nil end

    local frame = self:GetChatFrameByWindowName(windowName)
    if frame then
        return frame
    end

    if FCF_OpenNewWindow then
        -- Protect against FrameXML errors inside FCF_OpenNewWindow/FCF_FadeInChatFrame.
        pcall(FCF_OpenNewWindow, windowName)
    end

    return self:GetChatFrameByWindowName(windowName)
end

function addon:RenameChatWindow(oldName, newName)
    if not oldName or oldName == "" or not newName or newName == "" then return false end
    if oldName == newName then return true end

    -- If the destination exists, don't rename into it.
    if self:GetChatFrameByWindowName(newName) then
        return true
    end

    local oldFrame = self:GetChatFrameByWindowName(oldName)
    if not oldFrame then return false end

    if FCF_SetWindowName then
        FCF_SetWindowName(oldFrame, newName)
        return self:GetChatFrameByWindowName(newName) ~= nil
    end

    return false
end

function addon:GetDcDebugChatFrame()
    local comm = self.settings and self.settings.communication
    local name = comm and comm.dcDebugTabName or "DCDebug"
    return self:GetChatFrameByWindowName(name)
end

-- Safe print with addon prefix
function addon:Print(msg, forceShow)
    if forceShow or (self.settings.communication and self.settings.communication.debugMode) then
        print("|cff00ff00[DC-QoS]|r " .. tostring(msg))
    end
end

-- Debug print (only when debug mode enabled)
function addon:Debug(msg)
    if self.settings.communication and self.settings.communication.debugMode then
        local line = "|cff888888[DC-QoS Debug]|r " .. tostring(msg)
        local comm = self.settings.communication

        if comm and comm.routeDcDebugToTab then
            local target = self:EnsureChatWindow(comm.dcDebugTabName or "DCDebug")
            if target and target.AddMessage then
                target:AddMessage(line)
                return
            end
        end

        print(line)
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

-- Helper to create a checkbox with 3.3.5a compatibility
function addon:CreateCheckbox(parent, name)
    local cb = CreateFrame("CheckButton", name, parent, "InterfaceOptionsCheckButtonTemplate")
    
    -- Fix for 3.3.5a: find the text fontstring and assign it to .Text
    local cbName = cb:GetName()
    if cbName then
        cb.Text = _G[cbName .. "Text"]
    else
        -- For anonymous frames, find the fontstring region
        for _, region in ipairs({cb:GetRegions()}) do
            if region:GetObjectType() == "FontString" then
                cb.Text = region
                break
            end
        end
    end
    
    return cb
end

-- Helper to create a slider with 3.3.5a compatibility
function addon:CreateSlider(parent, name)
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    
    -- Fix for 3.3.5a: find the fontstring regions and assign them
    local sliderName = slider:GetName()
    if sliderName then
        slider.Text = _G[sliderName .. "Text"]
        slider.Low = _G[sliderName .. "Low"]
        slider.High = _G[sliderName .. "High"]
    else
        -- For anonymous frames, find the fontstring regions
        for _, region in ipairs({slider:GetRegions()}) do
            if region:GetObjectType() == "FontString" then
                local rName = region:GetName()
                if rName then
                    if rName:find("Text$") then slider.Text = region
                    elseif rName:find("Low$") then slider.Low = region
                    elseif rName:find("High$") then slider.High = region
                    end
                end
            end
        end
    end
    
    return slider
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
        -- Legacy migration: convert flat settings into profile storage
        if DCQoSDB.profiles == nil and DCQoSDB.profileKeys == nil then
            local legacy = DCQoSDB
            DCQoSDB = {
                profiles = {},
                profileKeys = {},
                globalProfile = (self.defaults.profiles and self.defaults.profiles.defaultProfile) or "Default",
            }
            DCQoSDB.profiles[DCQoSDB.globalProfile] = legacy
        end
        self.db = DCQoSDB
        EnsureProfileTables(self.db, self.defaults)

        local activeProfile = self:GetActiveProfileName() or (self.defaults.profiles and self.defaults.profiles.defaultProfile) or "Default"
        if not self.db.profiles[activeProfile] then
            self.db.profiles[activeProfile] = self:DeepCopy(self.defaults)
        end
        self.activeProfile = activeProfile
        self.settings = self.db.profiles[activeProfile]

        -- Merge any new defaults into active profile
        self:MergeDefaults(self.settings, self.defaults)

        -- One-time migration: enable DC debug routing for existing users
        if self.settings.communication then
            if self.settings.communication._dcDebugRouteMigrated ~= true then
                self.settings.communication.routeDcDebugToTab = true
                self.settings.communication._dcDebugRouteMigrated = true
            end

            -- One-time migration: rename default chat tab "DC" -> "DCDebug" (don't clobber custom names)
            if self.settings.communication._dcDebugTabMigrated ~= true then
                local oldName = "DC"
                local newName = "DCDebug"
                local currentName = self.settings.communication.dcDebugTabName

                if not currentName or currentName == "" or currentName == oldName then
                    self:RenameChatWindow(oldName, newName)
                    self.settings.communication.dcDebugTabName = newName
                end

                self.settings.communication._dcDebugTabMigrated = true
            end
        end
    else
        self.db = { profiles = {}, profileKeys = {}, globalProfile = (self.defaults.profiles and self.defaults.profiles.defaultProfile) or "Default" }
        EnsureProfileTables(self.db, self.defaults)
        self.activeProfile = self.db.globalProfile
        self.settings = self.db.profiles[self.activeProfile]
    end
end

function addon:SaveSettings()
    if self.db and self.activeProfile and self.settings then
        self.db.profiles[self.activeProfile] = self.settings
    end
    DCQoSDB = self.db or self.settings
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

    -- If the setting commonly needs a reload, prompt once.
    -- 1) Module enable toggles (e.g. "bags.enabled")
    if type(path) == "string" and string.match(path, "^%w+%.enabled$") then
        self:PromptReloadUI()
        return
    end

    -- 2) Any registered prefixes (modules can opt-in)
    if type(path) == "string" and self._reloadUIPrefixes then
        for _, prefix in ipairs(self._reloadUIPrefixes) do
            if prefix and prefix ~= "" and string.sub(path, 1, string.len(prefix)) == prefix then
                self:PromptReloadUI()
                return
            end
        end
    end
end

-- ============================================================
-- Initialization
-- ============================================================

function addon:Initialize()
    if self.initialized then return end
    
    self:Print("Initializing DC-QoS v" .. self.version, true)
    
    -- Load settings from SavedVariables
    self:LoadSettings()

    -- If enabled, ensure the DC debug chat tab exists early
    if self.settings and self.settings.communication and self.settings.communication.routeDcDebugToTab then
        self:EnsureChatWindow(self.settings.communication.dcDebugTabName or "DCDebug")
    end
    
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
        if addon.db and addon.activeProfile then
            addon.db.profiles[addon.activeProfile] = addon.settings
        end
        addon:SaveSettings()
        addon:Print("Current profile reset to defaults.", true)
        ReloadUI()
    elseif msg == "reload" then
        ReloadUI()
    elseif msg:find("^bind") then
        addon.keybindMode = not addon.keybindMode
        addon:Print("Keybind mode: " .. (addon.keybindMode and "ENABLED" or "DISABLED"), true)
    elseif msg:find("^profile") then
        local args = {}
        for token in msg:gmatch("[^%s]+") do
            table.insert(args, token)
        end
        local sub = args[2]
        if sub == "list" then
            if addon.db and addon.db.profiles then
                addon:Print("Profiles: " .. table.concat((function()
                    local names = {}
                    for name in pairs(addon.db.profiles) do
                        table.insert(names, name)
                    end
                    table.sort(names)
                    return names
                end)(), ", "), true)
            end
        elseif sub == "set" and args[3] then
            addon:SetActiveProfile(args[3], true)
        elseif sub == "setglobal" and args[3] then
            addon:SetActiveProfile(args[3], false)
        elseif sub == "new" and args[3] then
            local copyFrom = args[4]
            if addon:CreateProfile(args[3], copyFrom) then
                addon:Print("Profile created: " .. args[3], true)
            else
                addon:Print("Profile already exists: " .. args[3], true)
            end
        elseif sub == "delete" and args[3] then
            if addon:DeleteProfile(args[3]) then
                addon:Print("Profile deleted: " .. args[3], true)
            else
                addon:Print("Unable to delete profile: " .. args[3], true)
            end
        elseif sub == "export" and args[3] then
            local data = addon:ExportProfile(args[3])
            if data then
                addon:Print("Profile export (" .. args[3] .. "):", true)
                print(data)
            end
        elseif sub == "import" and args[3] and args[4] then
            local name = args[3]
            local data = msg:gsub("^profile%s+import%s+" .. name .. "%s+", "")
            if addon:ImportProfile(name, data) then
                addon:Print("Profile imported: " .. name, true)
            else
                addon:Print("Profile import failed.", true)
            end
        else
            addon:Print("Profile commands:", true)
            print("  /dcqos profile list")
            print("  /dcqos profile set <name>")
            print("  /dcqos profile setglobal <name>")
            print("  /dcqos profile new <name> [copyFrom]")
            print("  /dcqos profile delete <name>")
            print("  /dcqos profile export <name>")
            print("  /dcqos profile import <name> <data>")
        end
    elseif msg == "help" then
        addon:Print("Commands:", true)
        print("  |cffffd700/dcqos|r - Open settings panel")
        print("  |cffffd700/dcqos debug|r - Toggle debug mode")
        print("  |cffffd700/dcqos reset|r - Reset all settings to defaults")
        print("  |cffffd700/dcqos bind|r - Toggle keybind mode")
        print("  |cffffd700/dcqos profile ...|r - Manage profiles")
        print("  |cffffd700/dcqos reload|r - Reload UI")
        print("  |cffffd700/dcqos help|r - Show this help message")
    else
        addon:Print("Unknown command. Type |cffffd700/dcqos help|r for help.", true)
    end
end
