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
addon.version = "1.2.2-rankfix"
addon.version = "1.3.1-blizzardmounts"
addon.author = "DarkChaos Team"
addon.description = "Quality of Life improvements for DarkChaos-255"

-- Ping keybinding labels are declared in Core so they're available before Bindings.xml is loaded.
BINDING_HEADER_DCQOS_PING = "DC-QoS Ping"
BINDING_NAME_DCQOS_PING_TEST = "Ping: Test"
BINDING_NAME_DCQOS_PING_CLEAR = "Ping: Clear Active Pings"
BINDING_NAME_DCQOS_PING_WARNING = "Ping: Warning"
BINDING_NAME_DCQOS_PING_ATTACK = "Ping: Attack"
BINDING_NAME_DCQOS_PING_ASSIST = "Ping: Assist"
BINDING_NAME_DCQOS_PING_ONMYWAY = "Ping: On My Way"
BINDING_NAME_DCQOS_PING_DANGER = "Ping: Danger"
BINDING_NAME_DCQOS_PING_INFO = "Ping: Info"
BINDING_NAME_DCQOS_PING_MENU = "Ping: Radial Menu"

-- ============================================================
-- Shared Class Colors (3.3.5a)
-- ============================================================
addon.CLASS_COLORS = RAID_CLASS_COLORS or {
    ["WARRIOR"]     = { r = 0.78, g = 0.61, b = 0.43 },
    ["PALADIN"]     = { r = 0.96, g = 0.55, b = 0.73 },
    ["HUNTER"]      = { r = 0.67, g = 0.83, b = 0.45 },
    ["ROGUE"]       = { r = 1.00, g = 0.96, b = 0.41 },
    ["PRIEST"]      = { r = 1.00, g = 1.00, b = 1.00 },
    ["DEATHKNIGHT"] = { r = 0.77, g = 0.12, b = 0.23 },
    ["SHAMAN"]      = { r = 0.00, g = 0.44, b = 0.87 },
    ["MAGE"]        = { r = 0.41, g = 0.80, b = 0.94 },
    ["WARLOCK"]     = { r = 0.58, g = 0.51, b = 0.79 },
    ["DRUID"]       = { r = 1.00, g = 0.49, b = 0.04 },
}

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
        showNpcKillCount = true,
        showSpellId = true,
        showSpellFamilyMetadata = false,
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
        largerWorldMap = true,
        extendedCameraZoom = true,
        maxZoomFactor = 4,
        buffFrameMove = false,
        buffFrameOffsetX = 10,
        buffFrameOffsetY = -20,
        playerFrameOffsetY = -3,
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
        y = -17,
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

    -- Talent Manager
    talentManager = {
        enabled = true,
        showGlyphs = true,
        confirmLearning = true,
        frameScale = 1.0,
        lockFrame = false,
        autoBackup = true,
    },
}

addon.settings = {}
addon.db = nil
addon.activeProfile = nil
addon.keybindMode = false
addon._editModePreviousKeybindState = false

local function GetCharacterKey()
    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName() or "Unknown"
    return name .. "-" .. realm
end

function addon:GetCharacterKey()
    return GetCharacterKey()
end

function addon:SetKeybindMode(enabled, silent)
    local newState = enabled and true or false
    if self.keybindMode == newState then
        return newState
    end

    self.keybindMode = newState
    self:FireEvent("KEYBIND_MODE_CHANGED", newState)

    if not silent then
        if self.Notify then
            self:Notify("Keybind mode " .. (newState and "enabled" or "disabled") .. ".", "info", { chatFallback = true, title = "Keybinds" })
        else
            self:Print("Keybind mode: " .. (newState and "ENABLED" or "DISABLED"), true)
        end
    end

    return newState
end

function addon:ToggleKeybindMode(silent)
    return self:SetKeybindMode(not self.keybindMode, silent)
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

function addon:GetMapUtils()
    if self._mapUtils then
        return self._mapUtils
    end

    local mapDataLib
    local mapUtils = {}

    function mapUtils.NormalizeCoord(value)
        if value == nil then
            return nil
        end

        local n = tonumber(value)
        if not n then
            return nil
        end

        if n > 1 then
            n = n / 100
        end

        if n < 0 or n > 1 then
            return nil
        end

        return n
    end

    function mapUtils.GetMapDataLib()
        if mapDataLib ~= nil then
            return mapDataLib or nil
        end

        if type(LibStub) == "function" then
            mapDataLib = LibStub("LibMapData-1.0", true)
        else
            mapDataLib = false
        end

        return mapDataLib or nil
    end

    function mapUtils.SafeSetMapToCurrentZone()
        if type(SetMapToCurrentZone) ~= "function" then
            return
        end

        local worldMapShown =
            WorldMapFrame and WorldMapFrame.IsShown and WorldMapFrame:IsShown()
        if not worldMapShown then
            pcall(SetMapToCurrentZone)
        end
    end

    function mapUtils.GetPlayerMapPositionSafe()
        local mapId

        if C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition then
            mapId = C_Map.GetBestMapForUnit("player")
            if mapId then
                local pos = C_Map.GetPlayerMapPosition(mapId, "player")
                if pos and pos.x and pos.y and pos.x > 0 and pos.y > 0 then
                    return pos.x, pos.y, mapId
                end
            end
        end

        if type(GetPlayerMapPosition) == "function" then
            local x, y = GetPlayerMapPosition("player")
            if (not x or not y or x <= 0 or y <= 0) then
                mapUtils.SafeSetMapToCurrentZone()
                x, y = GetPlayerMapPosition("player")
            end

            if x and y and x > 0 and y > 0 then
                mapId =
                    (type(GetCurrentMapAreaID) == "function")
                    and GetCurrentMapAreaID()
                    or nil
                return x, y, mapId
            end
        end

        return nil, nil, nil
    end

    function mapUtils.GetMapAreaYards(mapId)
        local mapLib = mapUtils.GetMapDataLib()
        if mapLib and mapId and mapLib.MapArea then
            local floor =
                (type(GetCurrentMapDungeonLevel) == "function")
                and GetCurrentMapDungeonLevel()
                or 0
            local ok, width, height = pcall(mapLib.MapArea, mapLib, mapId, floor)
            if ok and width and height and width > 0 and height > 0 then
                return width, height
            end
        end

        return 10000, 10000
    end

    function mapUtils.ComputeDistanceYards(mapId, x1, y1, x2, y2)
        local width, height = mapUtils.GetMapAreaYards(mapId)
        local dx = (x2 - x1) * width
        local dy = (y2 - y1) * height
        return math.sqrt((dx * dx) + (dy * dy)), dx, dy
    end

    self._mapUtils = mapUtils
    return mapUtils
end

function addon:GetQuestTrackingUtils()
    if self._questTrackingUtils then
        return self._questTrackingUtils
    end

    local mapUtils = type(self.GetMapUtils) == "function" and self:GetMapUtils() or nil
    local GetPlayerMapPositionSafe = mapUtils and mapUtils.GetPlayerMapPositionSafe or nil
    local SafeSetMapToCurrentZone = mapUtils and mapUtils.SafeSetMapToCurrentZone or nil
    local questTrackingUtils = {}

    local function NormalizePositiveNumber(value)
        value = tonumber(value)
        if value and value > 0 then
            return value
        end

        return nil
    end

    local function GetQuestIdFromQuestLogTitle(questLogIndex)
        if type(GetQuestLogTitle) ~= "function" then
            return nil
        end

        local _, _, _, _, _, _, _, result8, result9, result10 = GetQuestLogTitle(questLogIndex)

        if type(result10) == "number" and result10 > 0 then
            return result10
        end
        if type(result9) == "number" and result9 > 0 then
            return result9
        end
        if type(result8) == "number" and result8 > 1000 then
            return result8
        end

        return nil
    end

    function questTrackingUtils.ParseQuestIdFromLink(link)
        if type(link) ~= "string" then
            return nil
        end

        local questId = tonumber(link:match("|Hquest:(%d+):"))
        if questId and questId > 0 then
            return questId
        end

        return nil
    end

    function questTrackingUtils.GetQuestIdFromLogIndex(questLogIndex, options)
        questLogIndex = NormalizePositiveNumber(questLogIndex)
        if not questLogIndex then
            return nil
        end

        options = type(options) == "table" and options or nil

        local questApi = rawget(_G, "C_QuestLog")
        if type(questApi) == "table" and type(questApi.GetQuestIDForQuestLogIndex) == "function" then
            local ok, questId = pcall(questApi.GetQuestIDForQuestLogIndex, questLogIndex)
            questId = NormalizePositiveNumber(questId)
            if ok and questId then
                return questId
            end
        end

        local getter = rawget(_G, "C_QuestLog_GetQuestIDForQuestLogIndex") or rawget(_G, "GetQuestIDForQuestLogIndex")
        if type(getter) == "function" then
            local ok, questId = pcall(getter, questLogIndex)
            questId = NormalizePositiveNumber(questId)
            if ok and questId then
                return questId
            end
        end

        if type(GetQuestLink) == "function" then
            local questId = questTrackingUtils.ParseQuestIdFromLink(GetQuestLink(questLogIndex))
            if questId then
                return questId
            end
        end

        local questId = GetQuestIdFromQuestLogTitle(questLogIndex)
        if questId then
            return questId
        end

        if options and options.allowQuestLogIndexFallback then
            return questLogIndex
        end

        return nil
    end

    function questTrackingUtils.GetSuperTrackedQuestId()
        local nav = addon and addon.Navigation or nil
        if nav and type(nav.GetSuperTrackedQuestID) == "function" then
            local ok, questId = pcall(nav.GetSuperTrackedQuestID, nav)
            questId = NormalizePositiveNumber(questId)
            if ok and questId then
                return questId
            end
        end

        local api = rawget(_G, "C_SuperTrack")
        if type(api) == "table" and type(api.GetSuperTrackedQuestID) == "function" then
            local ok, questId = pcall(api.GetSuperTrackedQuestID)
            questId = NormalizePositiveNumber(questId)
            if ok and questId then
                return questId
            end
        end

        local getter = rawget(_G, "GetSuperTrackedQuestID") or rawget(_G, "C_SuperTrack_GetSuperTrackedQuestID")
        if type(getter) ~= "function" then
            return nil
        end

        local ok, questId = pcall(getter)
        questId = NormalizePositiveNumber(questId)
        if ok and questId then
            return questId
        end

        return nil
    end

    function questTrackingUtils.GetCurrentMapId()
        if type(GetPlayerMapPositionSafe) == "function" then
            local _, _, mapId = GetPlayerMapPositionSafe()
            mapId = NormalizePositiveNumber(mapId)
            if mapId then
                return mapId
            end
        end

        if type(SafeSetMapToCurrentZone) == "function" then
            SafeSetMapToCurrentZone()
        end

        local mapId = type(GetCurrentMapAreaID) == "function" and NormalizePositiveNumber(GetCurrentMapAreaID()) or nil
        if mapId then
            return mapId
        end

        return nil
    end

    function questTrackingUtils.GetNextWaypointForMap(mapId)
        mapId = NormalizePositiveNumber(mapId) or questTrackingUtils.GetCurrentMapId()
        if not mapId then
            return nil
        end

        local superTrackApi = rawget(_G, "C_SuperTrack")
        local getter = type(superTrackApi) == "table" and superTrackApi.GetNextWaypointForMap or nil

        if type(getter) ~= "function" then
            getter = rawget(_G, "GetNextWaypointForMap") or rawget(_G, "C_SuperTrack_GetNextWaypointForMap")
        end

        if type(getter) ~= "function" then
            return nil
        end

        local ok, x, y, waypointText = pcall(getter, mapId)
        if not ok then
            return nil
        end

        return x, y, waypointText, mapId
    end

    self._questTrackingUtils = questTrackingUtils
    return questTrackingUtils
end

-- 3.3.5a compatible delayed call
function addon:DelayedCall(delay, func)
    if type(func) ~= "function" then
        self:Debug("DelayedCall ignored: callback is not a function")
        return
    end

    delay = tonumber(delay) or 0
    if delay < 0 then
        delay = 0
    end

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
    
    -- Create value display fontstring
    local valueText = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    valueText:SetPoint("TOP", slider, "BOTTOM", 0, 0)
    slider.Value = valueText
    
    -- Hook OnValueChanged to update value display
    slider:HookScript("OnValueChanged", function(self, value)
        if self.Value then
            self.Value:SetText(math.floor(value + 0.5))
        end
    end)
    
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

local WORLD_MAP_SHARED_REFRESH_FUNCTIONS = {
    "WorldMapFrame_DisplayQuests",
    "WorldMapFrame_DisplayQuestPOI",
    "WorldMapFrame_UpdateQuests",
    "WorldMapFrame_SelectQuestFrame",
}

function addon:QueueWorldMapRefreshCycle(callback)
    local bucket = self.__dcqosWorldMapRefreshCycle
    if type(bucket) ~= "table" then
        bucket = {
            pending = false,
            callbacks = {},
        }
        self.__dcqosWorldMapRefreshCycle = bucket
    end

    if type(callback) == "function" then
        table.insert(bucket.callbacks, callback)
    end

    if bucket.pending then
        return
    end

    bucket.pending = true

    local function Flush()
        bucket.pending = false

        local callbacks = bucket.callbacks
        bucket.callbacks = {}

        for index = 1, #callbacks do
            pcall(callbacks[index])
        end
    end

    if type(self.DelayedCall) == "function" then
        self:DelayedCall(0, Flush)
    else
        Flush()
    end
end

function addon:DispatchWorldMapRefreshListeners()
    local registry = self.__dcqosWorldMapRefreshListeners
    if type(registry) ~= "table" then
        return
    end

    local callbacks = {}
    for _, callback in pairs(registry) do
        if type(callback) == "function" then
            table.insert(callbacks, callback)
        end
    end

    if #callbacks == 0 then
        return
    end

    self:QueueWorldMapRefreshCycle(function()
        for index = 1, #callbacks do
            pcall(callbacks[index])
        end
    end)
end

function addon:EnsureWorldMapRefreshHookBridge()
    if self.__dcqosWorldMapRefreshHookBridgeInstalled then
        return true
    end
    if type(hooksecurefunc) ~= "function" then
        return false
    end

    local function RequestSharedRefresh()
        addon:DispatchWorldMapRefreshListeners()
    end

    for index = 1, #WORLD_MAP_SHARED_REFRESH_FUNCTIONS do
        local name = WORLD_MAP_SHARED_REFRESH_FUNCTIONS[index]
        if type(_G[name]) == "function" then
            hooksecurefunc(name, RequestSharedRefresh)
        end
    end

    local function TryHookScript(frame, scriptName)
        if not frame or type(frame.HookScript) ~= "function" then
            return
        end

        pcall(frame.HookScript, frame, scriptName, RequestSharedRefresh)
    end

    TryHookScript(WorldMapFrame, "OnShow")
    TryHookScript(WorldMapButton, "OnShow")
    TryHookScript(WorldMapButton, "OnSizeChanged")
    TryHookScript(WorldMapFrameSizeUpButton, "OnClick")
    TryHookScript(WorldMapFrameSizeDownButton, "OnClick")
    TryHookScript(WorldMapQuestShowObjectives, "OnClick")

    self.__dcqosWorldMapRefreshHookBridgeInstalled = true
    return true
end

function addon:RegisterWorldMapRefreshListener(listenerKey, callback)
    if type(listenerKey) ~= "string" or listenerKey == "" or type(callback) ~= "function" then
        return false
    end

    local registry = self.__dcqosWorldMapRefreshListeners
    if type(registry) ~= "table" then
        registry = {}
        self.__dcqosWorldMapRefreshListeners = registry
    end

    registry[listenerKey] = callback
    return self:EnsureWorldMapRefreshHookBridge() ~= false
end

function addon:UnregisterWorldMapRefreshListener(listenerKey)
    local registry = self.__dcqosWorldMapRefreshListeners
    if type(registry) ~= "table" or type(listenerKey) ~= "string" then
        return false
    end

    if registry[listenerKey] == nil then
        return false
    end

    registry[listenerKey] = nil
    return true
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
        self:MergeModuleDefaults(config.defaults)
    end
    
    self:Debug("Registered module: " .. name)
end

-- Utility: Merge module defaults into addon.defaults (deep merge)
-- This is the shared utility to avoid code duplication in each module
function addon:MergeModuleDefaults(moduleDefaults)
    if not moduleDefaults then return end
    for k, v in pairs(moduleDefaults) do
        if self.defaults[k] == nil then
            if type(v) == "table" then
                self.defaults[k] = self:DeepCopy(v)
            else
                self.defaults[k] = v
            end
        elseif type(v) == "table" and type(self.defaults[k]) == "table" then
            for k2, v2 in pairs(v) do
                if self.defaults[k][k2] == nil then
                    if type(v2) == "table" then
                        self.defaults[k][k2] = self:DeepCopy(v2)
                    else
                        self.defaults[k][k2] = v2
                    end
                end
            end
        end
    end
end

-- Utility: Get class color code string for a class token
function addon:GetClassColorCode(classToken)
    local color = self.CLASS_COLORS[classToken]
    if color then
        return string.format("|cff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
    end
    return "|cffffffff"
end

-- Ensure quest tracking remains active even when minimap tracking UI is hidden.
function addon:EnsureQuestMinimapTrackingEnabled(reason)
    local ensured = false
    local questTrackingFound = false
    local questTrackingActive = false
    local reasonText = reason and tostring(reason) or "unspecified"
    local refreshActive = self.__dcqosQuestPoiRefreshActive == true

    local function RefreshQuestPoiDisplays()
        if refreshActive or self.__dcqosQuestPoiRefreshActive == true then
            return
        end

        self.__dcqosQuestPoiRefreshActive = true
        if type(SetMapToCurrentZone) == "function" then
            local worldMapShown = WorldMapFrame
                and type(WorldMapFrame.IsShown) == "function"
                and WorldMapFrame:IsShown()
            if not worldMapShown then
                pcall(SetMapToCurrentZone)
            end
        end

        if type(QuestWatch_Update) == "function" then
            pcall(QuestWatch_Update)
        end
        if type(WatchFrame_Update) == "function" then
            pcall(WatchFrame_Update)
        end
        if type(QuestPOIUpdateIcons) == "function" then
            pcall(QuestPOIUpdateIcons)
        end
        if type(MiniMapTracking_Update) == "function" then
            pcall(MiniMapTracking_Update)
        end
        if type(MiniMapTrackingButton_Update) == "function" then
            pcall(MiniMapTrackingButton_Update)
        end
        if type(MiniMapWorldMapButton_Update) == "function" then
            pcall(MiniMapWorldMapButton_Update)
        end

        self.__dcqosQuestPoiRefreshActive = false
    end

    -- Keep quest objective systems enabled globally so both world map and
    -- minimap POI layers can render.
    if type(SetCVar) == "function" then
        pcall(SetCVar, "questPOI", "1")
        ensured = true
    end
    if _G and _G.SHOW_QUEST_OBJECTIVES_ON_MAP ~= "1" then
        _G.SHOW_QUEST_OBJECTIVES_ON_MAP = "1"
        ensured = true
    end
    if WatchFrame then
        WatchFrame.showObjectives = true
        ensured = true
    end

    -- Retail-style clients can gate minimap POIs behind C_Minimap tracking
    -- filters. Enable them when available.
    if type(C_Minimap) == "table"
        and type(Enum) == "table"
        and type(Enum.MinimapTrackingFilter) == "table"
        and type(C_Minimap.SetTrackingFilter) == "function" then
        local filters = {
            Enum.MinimapTrackingFilter.QuestPOIs,
            Enum.MinimapTrackingFilter.POI,
        }

        for i = 1, #filters do
            local filter = filters[i]
            if filter ~= nil then
                if type(C_Minimap.GetTrackingFilter) == "function" then
                    local ok, active = pcall(C_Minimap.GetTrackingFilter, filter)
                    if ok and active ~= true then
                        pcall(C_Minimap.SetTrackingFilter, filter, true)
                        ensured = true
                    elseif ok and active == true then
                        ensured = true
                    end
                else
                    pcall(C_Minimap.SetTrackingFilter, filter, true)
                    ensured = true
                end
            end
        end
    end

    if type(GetNumTrackingTypes) ~= "function"
        or type(GetTrackingInfo) ~= "function"
        or type(SetTracking) ~= "function" then
        RefreshQuestPoiDisplays()

        if self.settings.communication and self.settings.communication.debugMode then
            self:Debug(string.format(
                "Quest minimap ensure[%s]: legacy tracking API unavailable; ensured=%s questPOI=%s trackingShown=%s worldMapButtonShown=%s",
                reasonText,
                tostring(ensured),
                tostring(type(GetCVar) == "function" and GetCVar("questPOI") or "n/a"),
                tostring(MiniMapTracking and MiniMapTracking.IsShown and MiniMapTracking:IsShown() or "n/a"),
                tostring(MiniMapWorldMapButton and MiniMapWorldMapButton.IsShown and MiniMapWorldMapButton:IsShown() or "n/a")
            ))
        end

        return ensured
    end

    local localizedTrackQuests = type(TRACK_QUESTS) == "string"
        and TRACK_QUESTS or nil
    local numTracking = GetNumTrackingTypes() or 0

    for i = 1, numTracking do
        local name, texture, active = GetTrackingInfo(i)
        local matches = false

        if localizedTrackQuests and type(name) == "string"
            and name == localizedTrackQuests then
            matches = true
        end

        if not matches and type(name) == "string" then
            local lowerName = string.lower(name)
            if lowerName:find("quest", 1, true)
                or lowerName:find("objective", 1, true) then
                matches = true
            end
        end

        if not matches and type(texture) == "string" then
            local lowerTexture = string.lower(texture)
            if lowerTexture:find("trackquest", 1, true) then
                matches = true
            end
        end

        if matches then
            questTrackingFound = true
            if not active then
                pcall(SetTracking, i, true)
                ensured = true
            end
            questTrackingActive = true
        end
    end

    RefreshQuestPoiDisplays()

    local queue = self.__dcqosQuestMinimapEnsureQueue
    if type(queue) ~= "table" then
        queue = { pending = false }
        self.__dcqosQuestMinimapEnsureQueue = queue
    end

    queue.lastReason = reasonText
    if type(self.DelayedCall) == "function" and not queue.pending then
        queue.pending = true
        self:DelayedCall(0.15, function()
            queue.pending = false
            RefreshQuestPoiDisplays()

            if self.settings.communication and self.settings.communication.debugMode then
                self:Debug(string.format(
                    "Quest minimap ensure[%s]: delayed refresh map=%s questTrackingFound=%s questTrackingActive=%s questPOI=%s",
                    tostring(queue.lastReason or "delayed"),
                    tostring(type(GetCurrentMapAreaID) == "function" and GetCurrentMapAreaID() or "n/a"),
                    tostring(questTrackingFound),
                    tostring(questTrackingActive),
                    tostring(type(GetCVar) == "function" and GetCVar("questPOI") or "n/a")
                ))
            end
        end)
    end

    if self.settings.communication and self.settings.communication.debugMode then
        self:Debug(string.format(
            "Quest minimap ensure[%s]: map=%s found=%s active=%s ensured=%s questPOI=%s trackingShown=%s worldMapButtonShown=%s",
            reasonText,
            tostring(type(GetCurrentMapAreaID) == "function" and GetCurrentMapAreaID() or "n/a"),
            tostring(questTrackingFound),
            tostring(questTrackingActive),
            tostring(ensured),
            tostring(type(GetCVar) == "function" and GetCVar("questPOI") or "n/a"),
            tostring(MiniMapTracking and MiniMapTracking.IsShown and MiniMapTracking:IsShown() or "n/a"),
            tostring(MiniMapWorldMapButton and MiniMapWorldMapButton.IsShown and MiniMapWorldMapButton:IsShown() or "n/a")
        ))
    end

    return ensured
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

        -- Ensure persistent NPC kill stats storage
        if type(self.db.npcKillStats) ~= "table" then
            self.db.npcKillStats = {}
        end
        if type(self.db.npcKillStats.account) ~= "table" then
            self.db.npcKillStats.account = { byEntry = {}, byName = {}, nameByEntry = {} }
        end
        if type(self.db.npcKillStats.characters) ~= "table" then
            self.db.npcKillStats.characters = {}
        end
        local charKey = GetCharacterKey()
        if not self.db.npcKillStats.characters[charKey] then
            self.db.npcKillStats.characters[charKey] = { byEntry = {}, byName = {}, nameByEntry = {} }
        end

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

        if type(self.db.npcKillStats) ~= "table" then
            self.db.npcKillStats = {}
        end
        if type(self.db.npcKillStats.account) ~= "table" then
            self.db.npcKillStats.account = { byEntry = {}, byName = {}, nameByEntry = {} }
        end
        if type(self.db.npcKillStats.characters) ~= "table" then
            self.db.npcKillStats.characters = {}
        end
        local charKey = GetCharacterKey()
        if not self.db.npcKillStats.characters[charKey] then
            self.db.npcKillStats.characters[charKey] = { byEntry = {}, byName = {}, nameByEntry = {} }
        end
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

local function PrintTooltipTransportStatus(tooltipsModule)
    local snapshot = tooltipsModule
        and tooltipsModule.GetNativeBridgeSnapshot
        and tooltipsModule.GetNativeBridgeSnapshot()

    if not snapshot then
        addon:Print("Tooltip transport diagnostics are not available.", true)
        return false
    end

    local state = "inactive"
    if not snapshot.exportsPresent then
        state = "missing-native-exports"
    elseif not snapshot.clientCapability and snapshot.clientMask > 0 then
        state = "client-capability-missing"
    elseif snapshot.connected and not snapshot.negotiatedCapability then
        state = "not-negotiated"
    elseif snapshot.stats and snapshot.stats.sessionDisabled then
        state = "session-disabled"
    elseif snapshot.stats and snapshot.stats.enabled then
        state = "enabled"
    elseif snapshot.bridgeAvailable then
        state = "available-disabled"
    end

    addon:Print(
        "Tooltip transport: state=" .. state
        .. " exports=" .. (snapshot.exportsPresent and "yes" or "no")
        .. " rawExport=" .. (snapshot.rawExportPresent and "yes" or "no")
        .. " rawDebug=" .. (snapshot.rawDebugStringPresent and "yes" or "no")
        .. " clientCap=" .. (snapshot.clientCapability and "yes" or "no")
        .. " negotiated=" .. (snapshot.negotiatedCapability and "yes" or "no")
        .. " bridge=" .. (snapshot.bridgeAvailable and "yes" or "no"),
        true)
    addon:Print(string.format(
        "Tooltip transport masks: client=0x%X negotiated=0x%X connected=%s server=%s",
        tonumber(snapshot.clientMask) or 0,
        tonumber(snapshot.negotiatedMask) or 0,
        snapshot.connected and "yes" or "no",
        tostring(snapshot.serverVersion or "nil")),
        true)
    if snapshot.nativeBuildFingerprint then
        addon:Print(
            "Tooltip native build: "
            .. tostring(snapshot.nativeBuildFingerprint),
            true)
    end
    if snapshot.nativeTooltipRuntimeSignature then
        addon:Print(
            "Tooltip native runtime: "
            .. tostring(snapshot.nativeTooltipRuntimeSignature),
            true)
    end
    if snapshot.rawState then
        addon:Print(
            "Tooltip raw runtime: enabled="
            .. (snapshot.rawState.enabled and "yes" or "no")
            .. " sessionDisabled="
            .. (snapshot.rawState.sessionDisabled and "yes" or "no")
            .. " pendingTimedOut="
            .. (snapshot.rawState.pendingTimedOut and "yes" or "no")
            .. " hasResult="
            .. (snapshot.rawState.hasResult and "yes" or "no")
            .. " cached="
            .. tostring(snapshot.rawState.cachedResultCount)
            .. " pendingRequestId="
            .. tostring(snapshot.rawState.pendingRequestId)
            .. " pendingSpellId="
            .. tostring(snapshot.rawState.pendingSpellId)
            .. " pendingContextHash="
            .. tostring(snapshot.rawState.pendingContextHash),
            true)
        addon:Print(
            "Tooltip raw counters: consecutiveTimeouts="
            .. tostring(snapshot.rawState.consecutiveTimeouts)
            .. " totalTimeouts="
            .. tostring(snapshot.rawState.totalTimeouts)
            .. " stale="
            .. tostring(snapshot.rawState.staleResponses)
            .. " accepted="
            .. tostring(snapshot.rawState.acceptedResponses)
            .. " rejected="
            .. tostring(snapshot.rawState.rejectedResponses),
            true)
    elseif snapshot.rawStateError then
        addon:Print(
            "Tooltip raw runtime unavailable: "
            .. tostring(snapshot.rawStateError),
            true)
    end
    if snapshot.rawDebugString then
        addon:Print(
            "Tooltip raw debug string: " .. tostring(snapshot.rawDebugString),
            true)
    elseif snapshot.rawDebugStringError then
        addon:Print(
            "Tooltip raw debug string unavailable: "
            .. tostring(snapshot.rawDebugStringError),
            true)
    end
    if snapshot.handshakeParserMode then
        addon:Print(
            "Tooltip handshake: parser=" .. tostring(snapshot.handshakeParserMode)
            .. " raw2=" .. tostring(snapshot.handshakeRawArg2 or "<nil>")
            .. " raw3=" .. tostring(snapshot.handshakeRawArg3 or "<nil>")
            .. " raw4=" .. tostring(snapshot.handshakeRawArg4 or "<nil>"),
            true)
    end
    if snapshot.lastBridgeSync then
        addon:Print(
            "Tooltip bridge sync: reason="
            .. tostring(snapshot.lastBridgeSync.reason or "unknown")
            .. " desired="
            .. (snapshot.lastBridgeSync.desiredEnabled and "yes" or "no")
            .. " negotiated="
            .. (snapshot.lastBridgeSync.negotiated and "yes" or "no")
            .. " tooltips="
            .. (snapshot.lastBridgeSync.tooltipsEnabled and "yes" or "no")
            .. " comm="
            .. (snapshot.lastBridgeSync.communicationEnabled and "yes" or "no")
            .. " configure="
            .. (snapshot.lastBridgeSync.configureOk and "ok" or "fail")
            .. " toggle="
            .. (snapshot.lastBridgeSync.toggleOk and "ok" or "fail")
            .. " readbackEnabled="
            .. tostring(snapshot.lastBridgeSync.readbackEnabled)
            .. " readbackSessionDisabled="
            .. tostring(snapshot.lastBridgeSync.readbackSessionDisabled),
            true)
        if snapshot.lastBridgeSync.configureError then
            addon:Print(
                "Tooltip bridge configure error: "
                .. tostring(snapshot.lastBridgeSync.configureError),
                true)
        end
        if snapshot.lastBridgeSync.resetError then
            addon:Print(
                "Tooltip bridge reset error: "
                .. tostring(snapshot.lastBridgeSync.resetError),
                true)
        end
        if snapshot.lastBridgeSync.toggleError then
            addon:Print(
                "Tooltip bridge toggle error: "
                .. tostring(snapshot.lastBridgeSync.toggleError),
                true)
        end
        if snapshot.lastBridgeSync.readbackError then
            addon:Print(
                "Tooltip bridge readback error: "
                .. tostring(snapshot.lastBridgeSync.readbackError),
                true)
        end
    end

    if snapshot.stats then
        addon:Print(string.format(
            "Tooltip native stats: enabled=%s sessionDisabled=%s accepted=%d rejected=%d stale=%d totalTimeouts=%d consecutiveTimeouts=%d timeoutMs=%d intervalMs=%d maxTimeouts=%d",
            snapshot.stats.enabled and "yes" or "no",
            snapshot.stats.sessionDisabled and "yes" or "no",
            tonumber(snapshot.stats.acceptedResponses) or 0,
            tonumber(snapshot.stats.rejectedResponses) or 0,
            tonumber(snapshot.stats.staleResponses) or 0,
            tonumber(snapshot.stats.totalTimeouts) or 0,
            tonumber(snapshot.stats.consecutiveTimeouts) or 0,
            tonumber(snapshot.stats.timeoutMs) or 0,
            tonumber(snapshot.stats.minRequestIntervalMs) or 0,
            tonumber(snapshot.stats.maxConsecutiveTimeouts) or 0),
            true)

        if snapshot.stats.enabled
            and (tonumber(snapshot.stats.acceptedResponses) or 0) == 0
            and (tonumber(snapshot.stats.rejectedResponses) or 0) == 0
            and (tonumber(snapshot.stats.totalTimeouts) or 0) == 0 then
            addon:Print(
                "Tooltip native bridge is armed but not exercised yet. Hover a spell, then rerun /dcqos transport.",
                true)
        end
    elseif snapshot.statsError then
        addon:Print("Tooltip native stats error: " .. tostring(snapshot.statsError), true)
    end

    return true
end

local function PrintShapeshiftTooltipDebug(tooltipsModule)
    local snapshot = tooltipsModule
        and tooltipsModule.GetLastShapeshiftTooltipDebug
        and tooltipsModule.GetLastShapeshiftTooltipDebug()
    if not snapshot then
        addon:Print(
            "Shapeshift tooltip: no stance/presence/stealth hover captured yet.",
            true)
        return false
    end

    addon:Print(
        "Shapeshift tooltip: path=" .. tostring(snapshot.path or "<nil>")
        .. " button=" .. tostring(snapshot.buttonName or "<nil>")
        .. " formIndex=" .. tostring(snapshot.formIndex or "<nil>")
        .. " formName=" .. tostring(snapshot.formName or "<nil>")
        .. " spellId=" .. tostring(snapshot.resolvedSpellId or "<nil>")
        .. " lines=" .. tostring(snapshot.tooltipLines or "<nil>"),
        true)
    addon:Print(
        "Shapeshift sources: buttonSpellId="
        .. tostring(snapshot.buttonSpellId or "<nil>")
        .. " action=" .. tostring(snapshot.actionSlot or "<nil>")
        .. " actionType=" .. tostring(snapshot.actionType or "<nil>")
        .. " actionValue=" .. tostring(snapshot.actionValue or "<nil>")
        .. " actionSpellId=" .. tostring(snapshot.actionSpellId or "<nil>")
        .. " directSpellId=" .. tostring(snapshot.directSpellId or "<nil>"),
        true)
    addon:Print(
        "Shapeshift render: nativeShape="
        .. tostring(snapshot.nativeSetShapeshift)
        .. " nativeSpellByID=" .. tostring(snapshot.nativeSetSpellByID)
        .. " clientDesc=" .. tostring(snapshot.clientDescriptionShown)
        .. " clientDescLen=" .. tostring(snapshot.clientDescriptionLength or 0),
        true)
    return true
end

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
    elseif msg == "edit" or msg == "editor" then
        if addon.ToggleEditMode then
            addon:ToggleEditMode()
        else
            addon:Print("Edit mode is not available yet.", true)
        end
    elseif msg:find("^bind") then
        addon:ToggleKeybindMode(false)
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
    elseif msg:find("^nav") then
        local navMsg = strtrim(msg:gsub("^nav", "", 1))
        if SlashCmdList["DCQOSNAV"] then
            SlashCmdList["DCQOSNAV"](navMsg)
        else
            addon:Print("Navigation module is not loaded.", true)
        end
    elseif msg:find("^ping") then
        local pingMsg = strtrim(msg:gsub("^ping", "", 1))
        if SlashCmdList["DCQOSPING"] then
            SlashCmdList["DCQOSPING"](pingMsg)
        else
            addon:Print("Ping System module is not loaded.", true)
        end
    elseif msg == "transport" or msg == "tooltiptransport" or msg == "tooltip" then
        local tooltipsModule = addon.modules and addon.modules["Tooltips"]
        PrintTooltipTransportStatus(tooltipsModule)
    elseif msg == "shapetooltip" or msg == "shapetooltipdebug" then
        local tooltipsModule = addon.modules and addon.modules["Tooltips"]
        PrintShapeshiftTooltipDebug(tooltipsModule)
    elseif msg == "telemetry" or msg == "diag" or msg == "diagnostics" then
        local tooltipsModule = addon.modules and addon.modules["Tooltips"]
        local snapshot = tooltipsModule and tooltipsModule.GetTelemetrySnapshot and tooltipsModule.GetTelemetrySnapshot()
        if not snapshot then
            addon:Print("Tooltip telemetry is not available.", true)
            return
        end

        addon:Print(string.format("Tooltip telemetry (uptime %.0fs)", snapshot.uptime or 0), true)
        local spell = snapshot.spell or {}
        local upgrade = snapshot.upgrade or {}
        local npc = snapshot.npc or {}

        local spellLine =
            "Spell: sent=" .. tostring(tonumber(spell.requestsSent) or 0)
            .. " fail=" .. tostring(tonumber(spell.requestSendFailures) or 0)
            .. " recv=" .. tostring(tonumber(spell.responsesReceived) or 0)
            .. " ok=" .. tostring(tonumber(spell.responsesSuccess) or 0)
            .. " err=" .. tostring(tonumber(spell.responsesError) or 0)
            .. " noPending=" .. tostring(tonumber(spell.responsesWithoutPending) or 0)
            .. " remapByReq=" .. tostring(tonumber(spell.responsesRemappedByRequestId) or 0)
            .. " ridMismatch=" .. tostring(tonumber(spell.responseRequestIdMismatch) or 0)
            .. " pendingRecoveries=" .. tostring(tonumber(spell.pendingTimeoutRecoveries) or 0)
            .. " renderDisabled=" .. tostring(tonumber(spell.skippedRenderModeDisabled) or 0)
            .. " prefetchRuns=" .. tostring(tonumber(spell.prefetchRuns) or 0)
            .. " prefetchSent=" .. tostring(tonumber(spell.prefetchRequestsSent) or 0)
        addon:Print(spellLine, true)

        local spellClientDescriptionLine =
            "Spell clientDesc: missingExport=" .. tostring(tonumber(spell.clientDescriptionMissingExport) or 0)
            .. " callError=" .. tostring(tonumber(spell.clientDescriptionCallError) or 0)
            .. " nil=" .. tostring(tonumber(spell.clientDescriptionNilReturn) or 0)
            .. " empty=" .. tostring(tonumber(spell.clientDescriptionEmptyBody) or 0)
            .. " placeholderReject=" .. tostring(tonumber(spell.clientDescriptionPlaceholderRejected) or 0)
        addon:Print(spellClientDescriptionLine, true)

        local upgradeLine =
            "Upgrade: sent=" .. tostring(tonumber(upgrade.requestsSent) or 0)
            .. " recv=" .. tostring(tonumber(upgrade.responsesReceived) or 0)
            .. " pendingRecoveries=" .. tostring(tonumber(upgrade.pendingTimeoutRecoveries) or 0)
        addon:Print(upgradeLine, true)

        local npcLine =
            "NPC: sent=" .. tostring(tonumber(npc.requestsSent) or 0)
            .. " recv=" .. tostring(tonumber(npc.responsesReceived) or 0)
            .. " pendingRecoveries=" .. tostring(tonumber(npc.pendingTimeoutRecoveries) or 0)
        addon:Print(npcLine, true)
        PrintShapeshiftTooltipDebug(tooltipsModule)
        PrintTooltipTransportStatus(tooltipsModule)
    elseif msg == "help" then
        addon:Print("Commands:", true)
        print("  |cffffd700/dcqos|r - Open settings panel")
        print("  |cffffd700/dcqos debug|r - Toggle debug mode")
        print("  |cffffd700/dcqos reset|r - Reset all settings to defaults")
        print("  |cffffd700/dcqos edit|r - Toggle unified edit mode")
        print("  |cffffd700/dcqos bind|r - Toggle keybind mode")
        print("  |cffffd700/dcqos nav <x> <y>|r - Set manual navigation waypoint")
        print("  |cffffd700/dcqos nav follow [questLogIndex]|r - Follow selected/indexed quest")
        print("  |cffffd700/dcqos nav clear|r - Clear manual waypoint and followed quest")
        print("  |cffffd700/dcqos ping ...|r - Forward to Ping System (/dcping)")
        print("  |cffffd700/dcping test|r - Show a local on-screen test ping")
        print("  |cffffd700/dcping menu|r - Open ping radial menu (release key/click to confirm)")
        print("  |cffffd700/dcqos telemetry|r - Print tooltip protocol diagnostics")
        print("  |cffffd700/dcqos transport|r - Print native spell-tooltip bridge status")
        print("  |cffffd700/dcqos shapetooltip|r - Print last stance/presence hover")
        print("  |cffffd700/dcqos profile ...|r - Manage profiles")
        print("  |cffffd700/dcqos reload|r - Reload UI")
        print("  |cffffd700/dcqos help|r - Show this help message")
    else
        addon:Print("Unknown command. Type |cffffd700/dcqos help|r for help.", true)
    end
end
