--[[
    DC Addon Protocol v1.5.1
    Unified communication library for all DarkChaos addons
    
    Features:
    - Pipe-delimited message format (MODULE|OPCODE|args...)
    - JSON support for complex data structures (DEFAULT standard)
    - DC:Request() method for JSON-by-default messaging
    - Handler registration per module/opcode
    - Module wrappers: DC.AOE, DC.Hotspot, DC.Upgrade, DC.Spectator, etc.
    - Connection status and feature tracking
    - Debug mode with /dc debug
    - Settings panel with JSON editor for testing (/dc panel)
    
    v1.5.1 Changes:
    - Fixed SetColorTexture -> SetTexture for 3.3.5a compatibility
    - Added test response handlers (CORE 0x63, 0xFF)
    - Connection feedback message on handshake ACK
    
    v1.5.0 Changes:
    - Added settings panel with debug/testing interface
    - JSON text editor for sending custom messages
    - Quick preset buttons for common requests
    - Slash commands: /dc panel, /dcpanel, /dcprotocol
    
    v1.4.0 Changes:
    - Added DC:Request(module, opcode, data) - JSON format as standard
    - All module wrappers now use DC:Request()
    - All DC addons converted to JSON format
    
    Author: DarkChaos Development Team
    Date: November 29, 2025
]]
if DCAddonProtocol then return end

DCAddonProtocol = {
    PREFIX = "DC",
    VERSION = "1.6.0",
    _handlers = {},
    _debug = false,
    _connected = false,
    _serverVersion = nil,
    _features = {},
    _handshakeSent = false,
    _lastHandshakeTime = 0,
    
    -- Request tracking system
    _requestLog = {},           -- Array of request entries
    _requestLogMax = 100,       -- Max entries to keep
    _responseLog = {},          -- Array of response entries
    _responseLogMax = 100,
    _pendingRequests = {},      -- Requests waiting for response (keyed by module_opcode)
    
    -- Statistics tracking
    _stats = {
        totalRequests = 0,
        totalResponses = 0,
        totalTimeouts = 0,
        avgResponseTime = 0,
        moduleStats = {},
        sessionStart = 0,  -- Will be set to time() after load
    },
    _errorHandlers = {},
    _globalErrorHandlers = {},
}

local DC = DCAddonProtocol

-- Ensure the addon-message prefix is registered (required for SendAddonMessage/CHAT_MSG_ADDON)
if type(RegisterAddonMessagePrefix) == "function" then
    pcall(RegisterAddonMessagePrefix, DC.PREFIX)
end

-- ============================================================================
-- ChatFrame Channel Name Protection (WoW 3.3.5a Bug Fix)
-- ============================================================================
-- Fixes: "bad argument #1 to 'format' (string expected, got nil)"
-- This occurs when ChatFrame.lua tries to format a channel message
-- but the channel name is nil (common after teleporting to a new map).
-- We hook ChatFrame_MessageEventHandler to protect against nil channel names.
-- ============================================================================
do
    local orig_ChatFrame_MessageEventHandler = ChatFrame_MessageEventHandler
    if orig_ChatFrame_MessageEventHandler then
        ChatFrame_MessageEventHandler = function(self, event, ...)
            -- Only process CHAT_MSG_CHANNEL events for protection
            if event == "CHAT_MSG_CHANNEL" then
                -- arg7 is the channel number, arg8 is the channel name in 3.3.5a
                local msg, sender, lang, channelString, _, _, channelNumber, channelName = ...
                
                -- If channel name is nil, the format() call in ChatFrame.lua will fail
                -- We can either skip the message entirely or provide a fallback
                if channelNumber and (not channelName or channelName == "") then
                    -- Try to get the channel name ourselves
                    local id, name = GetChannelName(channelNumber)
                    if not name or name == "" then
                        -- Channel not yet initialized, silently skip this message
                        -- It's usually just a join/leave message during teleport
                        return
                    end
                end
            end
            
            -- Call original handler
            return orig_ChatFrame_MessageEventHandler(self, event, ...)
        end
        DC._chatFrameProtected = true
    end
end

-- Module names for display
DC.ModuleNames = {
    CORE = "Core",
    AOEL = "AOE Loot",
    SPOT = "Hotspot",
    UPGR = "Item Upgrade",
    SPEC = "Spectator",
    DUEL = "Phased Duels",
    MPLS = "Mythic+",
    SEAS = "Seasonal",
    LBRD = "Leaderboards",
    WELC = "Welcome",
    GRPF = "Group Finder",
}

-- Shared Keystone item IDs mapping for client addons (faster inventory detection)
-- Default placeholder. If DCCentral exists, prefer the canonical list from it.
DC.KEYSTONE_ITEM_IDS = {
    -- Placeholder IDs used in DC: update as needed
    [60000] = true,
    [60001] = true,
    [60002] = true,
}

-- If DC Central is loaded, prefer its KEYSTONE_ITEM_IDS definition
local central = rawget(_G, "DCCentral")
if central and central.KEYSTONE_ITEM_IDS then
    DC.KEYSTONE_ITEM_IDS = central.KEYSTONE_ITEM_IDS
end

-- Shared scan tooltip accessor. If DCCentral exposes one (DCScanTooltip), use it; otherwise DC will lazily create a fallback.
function DC:GetScanTooltip()
    if self.ScanTooltip and type(self.ScanTooltip) == "table" then
        return self.ScanTooltip
    end
    -- Check for DCCentral provided tooltip first
    local globalTT = rawget(_G, "DCScanTooltip")
    if globalTT then
        self.ScanTooltip = globalTT
        return self.ScanTooltip
    end
    -- Create lazy fallback tooltip if not present
    if not self.ScanTooltip then
        local tt = CreateFrame("GameTooltip", "DCScanTooltip", nil, "GameTooltipTemplate")
        tt:SetOwner(WorldFrame, "ANCHOR_NONE")
        self.ScanTooltip = tt
    end
    return self.ScanTooltip
end

-- Ensure we link to DCCentral KEYSTONE mapping and shared tooltip if present after addon load
do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(self, event, arg1)
        local central = rawget(_G, "DCCentral")
        if central and central.KEYSTONE_ITEM_IDS then
            DC.KEYSTONE_ITEM_IDS = central.KEYSTONE_ITEM_IDS
        end
        if rawget(_G, "DCScanTooltip") then
            DC.ScanTooltip = rawget(_G, "DCScanTooltip")
        end
    end)
end

-- Group Finder Opcodes
DC.GroupFinderOpcodes = {
    -- Client -> Server: Listings
    CMSG_CREATE_LISTING      = 0x10,  -- Create a new group listing
    CMSG_SEARCH_LISTINGS     = 0x11,  -- Search for groups
    CMSG_APPLY_TO_GROUP      = 0x12,  -- Apply to join a group
    CMSG_CANCEL_APPLICATION  = 0x13,  -- Cancel pending application
    CMSG_ACCEPT_APPLICATION  = 0x14,  -- Leader accepts an applicant
    CMSG_DECLINE_APPLICATION = 0x15,  -- Leader declines an applicant
    CMSG_DELIST_GROUP        = 0x16,  -- Remove group listing
    CMSG_UPDATE_LISTING      = 0x17,  -- Update group listing
    CMSG_GET_MY_APPLICATIONS = 0x18,  -- Get my active applications
    
    -- Client -> Server: Keystone & Difficulty
    CMSG_GET_MY_KEYSTONE     = 0x20,  -- Request player's keystone info
    CMSG_SET_DIFFICULTY      = 0x21,  -- Request difficulty change
    CMSG_GET_DUNGEON_LIST    = 0x22,  -- Get M+ dungeon list from DB
    CMSG_GET_RAID_LIST       = 0x23,  -- Get raid list from DB
    CMSG_GET_SYSTEM_INFO     = 0x24,  -- Get system config (rewards, etc)
    
    -- Client -> Server: Spectating
    CMSG_START_SPECTATE      = 0x25,  -- Request to spectate a run
    CMSG_STOP_SPECTATE       = 0x26,  -- Stop spectating
    CMSG_GET_SPECTATE_LIST   = 0x27,  -- Get available runs to spectate
    
    -- Client -> Server: Scheduled Events
    CMSG_CREATE_EVENT        = 0x60,  -- Create scheduled event
    CMSG_SIGNUP_EVENT        = 0x61,  -- Sign up for event
    CMSG_CANCEL_SIGNUP       = 0x62,  -- Cancel event signup
    CMSG_GET_SCHEDULED_EVENTS= 0x63,  -- Get upcoming events
    CMSG_GET_MY_SIGNUPS      = 0x64,  -- Get my event signups
    CMSG_CANCEL_EVENT        = 0x65,  -- Cancel event (leader only)
    
    -- Server -> Client: Listings
    SMSG_LISTING_CREATED     = 0x30,  -- Confirm listing created
    SMSG_SEARCH_RESULTS      = 0x31,  -- Search results
    SMSG_APPLICATION_STATUS  = 0x32,  -- Application accepted/declined
    SMSG_NEW_APPLICATION     = 0x33,  -- Leader: new applicant
    SMSG_GROUP_UPDATED       = 0x34,  -- Group composition changed
    SMSG_MY_APPLICATIONS     = 0x35,  -- List of my active applications
    
    -- Server -> Client: Keystone & Difficulty
    SMSG_KEYSTONE_INFO       = 0x40,  -- Player's keystone data
    SMSG_DIFFICULTY_CHANGED  = 0x41,  -- Confirm difficulty changed
    SMSG_DUNGEON_LIST        = 0x42,  -- M+ dungeon list from DB
    SMSG_RAID_LIST           = 0x43,  -- Raid list from DB
    SMSG_SYSTEM_INFO         = 0x44,  -- System config (rewards, etc)
    
    -- Server -> Client: Spectating
    SMSG_SPECTATE_DATA       = 0x45,  -- Spectator live data
    SMSG_SPECTATE_LIST       = 0x47,  -- Available runs to spectate
    SMSG_SPECTATE_STARTED    = 0x48,  -- Spectating started
    SMSG_SPECTATE_ENDED      = 0x49,  -- Spectating ended
    
    -- Server -> Client: Scheduled Events
    SMSG_EVENT_CREATED       = 0x70,  -- Event created confirmation
    SMSG_EVENT_SIGNUP_RESULT = 0x71,  -- Signup result
    SMSG_SCHEDULED_EVENTS    = 0x72,  -- List of events
    SMSG_MY_SIGNUPS          = 0x73,  -- My event signups
    
    -- Server -> Client: Errors
    SMSG_ERROR               = 0x5F,  -- Error response
}

-- Log a request
function DC:LogRequest(module, opcode, data)
    local entry = {
        id = #self._requestLog + 1,
        timestamp = time(),
        timeStr = date("%H:%M:%S"),
        player = UnitName("player"),
        module = module,
        moduleName = self.ModuleNames[module] or module,
        opcode = opcode,
        data = data,
        status = "pending",
        responseTime = nil,
    }
    
    table.insert(self._requestLog, 1, entry) -- Add to front
    
    -- Trim log if too long
    while #self._requestLog > self._requestLogMax do
        table.remove(self._requestLog)
    end
    
    -- Track pending request
    local key = module .. "_" .. tostring(opcode)
    self._pendingRequests[key] = entry
    
    -- Update statistics
    self:UpdateStats("request", entry)
    
    return entry
end

-- Log a response
function DC:LogResponse(module, opcode, data, jsonStr)
    local entry = {
        id = #self._responseLog + 1,
        timestamp = time(),
        timeStr = date("%H:%M:%S"),
        player = UnitName("player"),
        module = module,
        moduleName = self.ModuleNames[module] or module,
        opcode = opcode,
        data = data,
        jsonLength = jsonStr and string.len(jsonStr) or 0,
    }
    
    table.insert(self._responseLog, 1, entry)
    
    while #self._responseLog > self._responseLogMax do
        table.remove(self._responseLog)
    end
    
    -- Update statistics
    self:UpdateStats("response", entry)
    
    -- Check if this was a pending request (response opcode is usually request + 0x0F)
    -- e.g., CMSG 0x01 -> SMSG 0x10
    local requestOpcode = opcode - 0x0F
    if requestOpcode > 0 then
        local key = module .. "_" .. tostring(requestOpcode)
        local pending = self._pendingRequests[key]
        if pending then
            pending.status = "completed"
            pending.responseTime = time() - pending.timestamp
            
            -- Update module avg response time
            local mod = module
            if self._stats.moduleStats[mod] then
                local stats = self._stats.moduleStats[mod]
                stats.totalResponseTime = stats.totalResponseTime + pending.responseTime
                stats.avgResponseTime = stats.totalResponseTime / stats.responses
            end
            
            self._pendingRequests[key] = nil
        end
    end
    
    return entry
end

-- Get request log for display
function DC:GetRequestLog(limit)
    limit = limit or 20
    local result = {}
    for i = 1, math.min(limit, #self._requestLog) do
        table.insert(result, self._requestLog[i])
    end
    return result
end

-- Get response log for display
function DC:GetResponseLog(limit)
    limit = limit or 20
    local result = {}
    for i = 1, math.min(limit, #self._responseLog) do
        table.insert(result, self._responseLog[i])
    end
    return result
end

-- Get pending requests
function DC:GetPendingRequests()
    local result = {}
    for key, entry in pairs(self._pendingRequests) do
        -- Check if request is stale (over 30 seconds)
        if time() - entry.timestamp > 30 then
            entry.status = "timeout"
        end
        table.insert(result, entry)
    end
    return result
end

-- Clear logs
function DC:ClearLogs()
    self._requestLog = {}
    self._responseLog = {}
    self._pendingRequests = {}
end

function DC:RegisterHandler(module, opcode, handler)
    local key = module .. "_" .. tostring(opcode)
    if not self._handlers[key] then self._handlers[key] = {} end
    table.insert(self._handlers[key], handler)
end

function DC:UnregisterHandler(module, opcode, handler)
    local key = module .. "_" .. tostring(opcode)
    local h = self._handlers[key]
    if not h then return false end
    -- If specific handler is provided, try to remove it
    if handler then
        if type(h) == 'table' then
            for i = #h, 1, -1 do
                if h[i] == handler then
                    table.remove(h, i)
                end
            end
            if #h == 0 then self._handlers[key] = nil end
            return true
        elseif h == handler then
            self._handlers[key] = nil
            return true
        else
            return false
        end
    end
    -- If no specific handler, remove all handlers for this key
    self._handlers[key] = nil
    return true
end

function DC:RegisterErrorHandler(module, handler)
    if not DC._errorHandlers[module] then DC._errorHandlers[module] = {} end
    table.insert(DC._errorHandlers[module], handler)
end

function DC:RegisterGlobalErrorHandler(handler)
    table.insert(DC._globalErrorHandlers, handler)
end

function DC:RegisterJSONHandler(module, opcode, handler)
    local key = module .. "_" .. tostring(opcode) .. "_json"
    if not self._handlers[key] then self._handlers[key] = {} end
    table.insert(self._handlers[key], handler)
end

function DC:UnregisterJSONHandler(module, opcode, handler)
    local key = module .. "_" .. tostring(opcode) .. "_json"
    local h = self._handlers[key]
    if not h then return false end
    if handler then
        if type(h) == 'table' then
            for i = #h, 1, -1 do
                if h[i] == handler then
                    table.remove(h, i)
                end
            end
            if #h == 0 then self._handlers[key] = nil end
            return true
        elseif h == handler then
            self._handlers[key] = nil
            return true
        else
            return false
        end
    end
    self._handlers[key] = nil
    return true
end

function DC:Send(module, opcode, a1, a2, a3, a4, a5)
    local parts = {module, tostring(opcode)}
        local args = {a1, a2, a3, a4, a5, nil}
    for i = 1, 5 do
        local v = args[i]
        if v ~= nil then
            if type(v) == "boolean" then
                table.insert(parts, v and "1" or "0")
            else
                table.insert(parts, tostring(v))
            end
        end
    end
    local msg = table.concat(parts, "|")
    
    -- Log request
    self:LogRequest(module, opcode, {a1, a2, a3, a4, a5})
    
    if self._debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[DC]|r Sending: " .. msg)
    end
    SendAddonMessage(self.PREFIX, msg, "WHISPER", UnitName("player"))
end

function DC:SendJSON(module, opcode, data)
    local json = self:EncodeJSON(data)
    local msg = module .. "|" .. tostring(opcode) .. "|J|" .. json
    
    -- Log request
    self:LogRequest(module, opcode, data)
    
    if self._debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[DC]|r Sending JSON: " .. module .. " opcode=" .. tostring(opcode))
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[DC]|r Data: " .. string.sub(json, 1, 200) .. (string.len(json) > 200 and "..." or ""))
    end
    SendAddonMessage(self.PREFIX, msg, "WHISPER", UnitName("player"))
end

-- Standard request method - uses JSON format by default
-- data can be nil (empty request), a table (JSON object), or simple values
function DC:Request(module, opcode, data)
    if data == nil then
        -- Empty request - send minimal JSON object
        self:SendJSON(module, opcode, {})
    elseif type(data) == "table" then
        -- Table data - send as JSON
        self:SendJSON(module, opcode, data)
    else
        -- Simple value - wrap in object
        self:SendJSON(module, opcode, { value = data })
    end
end

-- Alias for Request
DC.RequestJSON = DC.Request

function DC:EncodeJSON(val)
    local t = type(val)
    if val == nil then return "null"
    elseif t == "boolean" then return val and "true" or "false"
    elseif t == "number" then return tostring(val)
    elseif t == "string" then return "\"" .. string.gsub(val, "\"", "\\\"") .. "\""
    elseif t == "table" then
        local parts = {}
        local isArr = (val[1] ~= nil)
        if isArr then
            for i = 1, #val do
                table.insert(parts, self:EncodeJSON(val[i]))
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            for k, v in pairs(val) do
                table.insert(parts, "\"" .. tostring(k) .. "\":" .. self:EncodeJSON(v))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    end
    return "null"
end

function DC:DecodeJSON(str)
    if not str or str == "" then return nil end
    
    local pos = 1
    local len = string.len(str)
    
    local function skipWhitespace()
        while pos <= len and string.find(string.sub(str, pos, pos), "[ \t\n\r]") do
            pos = pos + 1
        end
    end
    
    local function parseValue()
        skipWhitespace()
        if pos > len then return nil end
        
        local ch = string.sub(str, pos, pos)
        
        -- String
        if ch == '"' then
            pos = pos + 1
            local startPos = pos
            local result = ""
            while pos <= len do
                local c = string.sub(str, pos, pos)
                if c == '\\' and pos + 1 <= len then
                    local nextC = string.sub(str, pos + 1, pos + 1)
                    if nextC == '"' then result = result .. '"'
                    elseif nextC == '\\' then result = result .. '\\'
                    elseif nextC == 'n' then result = result .. '\n'
                    elseif nextC == 't' then result = result .. '\t'
                    else result = result .. nextC end
                    pos = pos + 2
                elseif c == '"' then
                    pos = pos + 1
                    return result
                else
                    result = result .. c
                    pos = pos + 1
                end
            end
            return result
        end
        
        -- Number
        if ch == '-' or (ch >= '0' and ch <= '9') then
            local numStr = ""
            while pos <= len and string.find(string.sub(str, pos, pos), "[%-%d%.eE%+]") do
                numStr = numStr .. string.sub(str, pos, pos)
                pos = pos + 1
            end
            return tonumber(numStr)
        end
        
        -- Object
        if ch == '{' then
            pos = pos + 1
            local obj = {}
            skipWhitespace()
            if string.sub(str, pos, pos) == '}' then
                pos = pos + 1
                return obj
            end
            while pos <= len do
                skipWhitespace()
                local key = parseValue()
                if type(key) ~= "string" then break end
                skipWhitespace()
                if string.sub(str, pos, pos) ~= ':' then break end
                pos = pos + 1
                local value = parseValue()
                obj[key] = value
                skipWhitespace()
                local sep = string.sub(str, pos, pos)
                if sep == '}' then pos = pos + 1; break end
                if sep == ',' then pos = pos + 1 end
            end
            return obj
        end
        
        -- Array
        if ch == '[' then
            pos = pos + 1
            local arr = {}
            skipWhitespace()
            if string.sub(str, pos, pos) == ']' then
                pos = pos + 1
                return arr
            end
            while pos <= len do
                local value = parseValue()
                table.insert(arr, value)
                skipWhitespace()
                local sep = string.sub(str, pos, pos)
                if sep == ']' then pos = pos + 1; break end
                if sep == ',' then pos = pos + 1 end
            end
            return arr
        end
        
        -- true/false/null
        if string.sub(str, pos, pos + 3) == "true" then
            pos = pos + 4
            return true
        end
        if string.sub(str, pos, pos + 4) == "false" then
            pos = pos + 5
            return false
        end
        if string.sub(str, pos, pos + 3) == "null" then
            pos = pos + 4
            return nil
        end
        
        return nil
    end
    
    return parseValue()
end

DC.JSON = { encode = function(v) return DC:EncodeJSON(v) end, decode = function(s) return DC:DecodeJSON(s) end }

-- Module identifiers (must match server-side)
DC.Module = {
    CORE = "CORE",
    AOE_LOOT = "AOE",
    SPECTATOR = "SPEC",
    UPGRADE = "UPG",
    HOTSPOT = "SPOT",
    HINTERLAND = "HLBG",
    DUELS = "DUEL",
    MYTHIC_PLUS = "MPLUS",
    PRESTIGE = "PRES",
    SEASONAL = "SEAS",
    RESTORE_XP = "RXP",
    LEADERBOARD = "LBRD",
    WELCOME = "WELC",
}

-- Opcode definitions for each module
DC.Opcode = {
    Core = {
        CMSG_HANDSHAKE = 0x01,
        SMSG_HANDSHAKE_ACK = 0x10,
        SMSG_FEATURE_LIST = 0x12,
        SMSG_ERROR = 0x1F,
        SMSG_PERMISSION_DENIED = 0x1E,
    },
    AOE = {
        CMSG_TOGGLE_ENABLED = 0x01,
        CMSG_SET_QUALITY = 0x02,
        CMSG_GET_STATS = 0x03,
        CMSG_GET_SETTINGS = 0x06,
        SMSG_STATS = 0x10,
        SMSG_SETTINGS_SYNC = 0x11,
    },
    Hotspot = {
        CMSG_GET_LIST = 0x01,
        CMSG_GET_INFO = 0x02,
        CMSG_TELEPORT = 0x03,
        SMSG_HOTSPOT_LIST = 0x10,
        SMSG_HOTSPOT_INFO = 0x11,
        SMSG_HOTSPOT_SPAWN = 0x12,
        SMSG_HOTSPOT_EXPIRE = 0x13,
        SMSG_TELEPORT_RESULT = 0x14,
    },
    Upgrade = {
        CMSG_GET_ITEM_INFO = 0x01,
        CMSG_DO_UPGRADE = 0x02,
        CMSG_BATCH_REQUEST = 0x03,
        CMSG_GET_CURRENCY = 0x04,
        CMSG_PACKAGE_SELECT = 0x05,
        SMSG_ITEM_INFO = 0x10,
        SMSG_UPGRADE_RESULT = 0x11,
        SMSG_BATCH_ITEM_INFO = 0x12,
        SMSG_CURRENCY_UPDATE = 0x14,
        SMSG_PACKAGE_SELECTED = 0x15,
    },
    Spec = {
        CMSG_REQUEST_SPECTATE = 0x01,
        CMSG_LIST_RUNS = 0x03,
        SMSG_RUN_LIST = 0x12,
    },
    MPlus = {
        CMSG_GET_KEY_INFO = 0x01,
        CMSG_GET_AFFIXES = 0x02,
        CMSG_GET_BEST_RUNS = 0x03,
        CMSG_GET_KEYSTONE_LIST = 0x04,
        CMSG_REQUEST_HUD = 0x05,
        SMSG_KEY_INFO = 0x10,
        SMSG_AFFIXES = 0x11,
        SMSG_BEST_RUNS = 0x12,
        SMSG_RUN_START = 0x13,
        SMSG_RUN_END = 0x14,
        SMSG_TIMER_UPDATE = 0x15,
        SMSG_OBJECTIVE_UPDATE = 0x16,
        SMSG_KEYSTONE_LIST = 0x17,
    },
    Season = {
        CMSG_GET_CURRENT = 0x01,
        SMSG_CURRENT = 0x10,
    },
    Leaderboard = {
        CMSG_GET_LEADERBOARD = 0x01,
        CMSG_GET_CATEGORIES = 0x02,
        CMSG_GET_MY_RANK = 0x03,
        CMSG_REFRESH = 0x04,
        SMSG_LEADERBOARD_DATA = 0x10,
        SMSG_CATEGORIES = 0x11,
        SMSG_MY_RANK = 0x12,
        SMSG_ERROR = 0x1F,
    },
    Welcome = {
        CMSG_GET_SERVER_INFO = 0x01,
        CMSG_GET_FAQ = 0x02,
        CMSG_DISMISS = 0x03,
        CMSG_MARK_FEATURE_SEEN = 0x04,
        CMSG_GET_WHATS_NEW = 0x05,
        SMSG_SHOW_WELCOME = 0x10,
        SMSG_SERVER_INFO = 0x11,
        SMSG_FAQ_DATA = 0x12,
        SMSG_FEATURE_UNLOCK = 0x13,
        SMSG_WHATS_NEW = 0x14,
        SMSG_LEVEL_MILESTONE = 0x15,
    },
}

-- Convenience API functions for each module (JSON format by default)
DC.AOE = {
    Toggle = function(e) DC:Request("AOE", 0x01, { enabled = e }) end,
    SetQuality = function(q) DC:Request("AOE", 0x02, { quality = q }) end,
    SetAutoSkin = function(e) DC:Request("AOE", 0x04, { enabled = e }) end,
    SetRange = function(r) DC:Request("AOE", 0x05, { range = r }) end,
    GetStats = function() DC:Request("AOE", 0x03, {}) end,
    GetSettings = function() DC:Request("AOE", 0x06, {}) end,
    IgnoreItem = function(id) DC:Request("AOE", 0x07, { itemId = id }) end,
}

DC.Hotspot = {
    GetList = function() DC:Request("SPOT", 0x01, {}) end,
    GetInfo = function(id) DC:Request("SPOT", 0x02, { id = id }) end,
    Teleport = function(id) DC:Request("SPOT", 0x03, { id = id }) end,
    TogglePins = function(e) DC:Request("SPOT", 0x04, { enabled = e }) end,
}

DC.Upgrade = {
    GetItemInfo = function(bag, slot) DC:Request("UPG", 0x01, { bag = bag, slot = slot }) end,
    DoUpgrade = function(bag, slot, level) DC:Request("UPG", 0x02, { bag = bag, slot = slot, targetLevel = level }) end,
    BatchRequest = function(items) DC:Request("UPG", 0x03, { items = items }) end,
    GetCurrency = function() DC:Request("UPG", 0x04, {}) end,
    SelectPackage = function(packageId) DC:Request("UPG", 0x05, { packageId = packageId }) end,
}

DC.Spectator = {
    RequestSpectate = function(runId) DC:Request("SPEC", 0x01, { runId = runId }) end,
    StopSpectate = function() DC:Request("SPEC", 0x02, {}) end,
    ListRuns = function() DC:Request("SPEC", 0x03, {}) end,
    SetHudOption = function(opt, val) DC:Request("SPEC", 0x04, { option = opt, value = val }) end,
}

DC.MythicPlus = {
    GetKeyInfo = function() DC:Request("MPLUS", 0x01, {}) end,
    GetAffixes = function() DC:Request("MPLUS", 0x02, {}) end,
    GetBestRuns = function() DC:Request("MPLUS", 0x03, {}) end,
    GetKeystoneList = function() DC:Request("MPLUS", 0x04, {}) end,
    RequestHUD = function(reason) DC:Request("MPLUS", 0x05, { reason = reason or "client" }) end,
}

DC.Season = {
    GetCurrent = function() DC:Request("SEAS", 0x01, {}) end,
    GetRewards = function() DC:Request("SEAS", 0x02, {}) end,
    GetProgress = function() DC:Request("SEAS", 0x03, {}) end,
    ClaimReward = function(id) DC:Request("SEAS", 0x04, { rewardId = id }) end,
    GetLeaderboard = function() DC:Request("SEAS", 0x05, {}) end,
    GetChallenges = function() DC:Request("SEAS", 0x06, {}) end,
}

DC.Hinterland = {
    GetStatus = function() DC:Request("HLBG", 0x01, {}) end,
    GetResources = function() DC:Request("HLBG", 0x02, {}) end,
    GetObjective = function() DC:Request("HLBG", 0x03, {}) end,
    QuickQueue = function() DC:Request("HLBG", 0x04, {}) end,
    LeaveQueue = function() DC:Request("HLBG", 0x05, {}) end,
    GetStats = function() DC:Request("HLBG", 0x06, {}) end,
}

DC.Duel = {
    GetStats = function() DC:Request("DUEL", 0x01, {}) end,
    GetLeaderboard = function() DC:Request("DUEL", 0x02, {}) end,
    SpectateMatch = function(id) DC:Request("DUEL", 0x03, { matchId = id }) end,
}

DC.Prestige = {
    GetInfo = function() DC:Request("PRES", 0x01, {}) end,
    GetBonuses = function() DC:Request("PRES", 0x02, {}) end,
}

-- Unified Leaderboard API
DC.Leaderboard = {
    -- Request leaderboard data
    Get = function(category, subcategory, page, limit)
        DC:Request("LBRD", 0x01, {
            category = category or "mplus",
            subcategory = subcategory or "mplus_key",
            page = page or 1,
            limit = limit or 25,
            seasonId = 0,
        })
    end,
    -- Request available categories
    GetCategories = function() DC:Request("LBRD", 0x02, {}) end,
    -- Get player's rank in a category
    GetMyRank = function(category, subcategory)
        DC:Request("LBRD", 0x03, {
            category = category or "mplus",
            subcategory = subcategory or "mplus_key",
        })
    end,
    -- Force refresh
    Refresh = function() DC:Request("LBRD", 0x04, {}) end,
}

-- Welcome/First-Start API
DC.Welcome = {
    -- Request server configuration
    GetServerInfo = function() DC:Request("WELC", 0x01, {}) end,
    -- Request FAQ data (future: dynamic FAQ from server)
    GetFAQ = function() DC:Request("WELC", 0x02, {}) end,
    -- Notify server that user dismissed welcome
    Dismiss = function() DC:Request("WELC", 0x03, {}) end,
    -- Mark a feature introduction as seen
    MarkFeatureSeen = function(feature) DC:Request("WELC", 0x04, { feature = feature }) end,
    -- Request What's New content
    GetWhatsNew = function() DC:Request("WELC", 0x05, {}) end,
}

-- Group Finder API (Raid Finder + Mythic Dungeon Finder)
DC.GroupFinder = {
    -- Create a new group listing
    CreateListing = function(data)
        -- data: { dungeonId, keyLevel, note, roles = { tank, healer, dps1, dps2, dps3 } }
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_CREATE_LISTING, data)
    end,
    
    -- Search for groups
    Search = function(filters)
        -- filters: { dungeonId, minLevel, maxLevel, role, hasSlot }
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_SEARCH_LISTINGS, filters or {})
    end,
    
    -- Apply to join a group
    Apply = function(listingId, role, message)
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_APPLY_TO_GROUP, {
            listingId = listingId,
            role = role,
            message = message or ""
        })
    end,
    
    -- Cancel pending application
    CancelApplication = function(listingId)
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_CANCEL_APPLICATION, { listingId = listingId })
    end,
    
    -- Leader: Accept an applicant
    AcceptApplicant = function(listingId, applicantGuid)
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_ACCEPT_APPLICATION, {
            listingId = listingId,
            applicantGuid = applicantGuid
        })
    end,
    
    -- Leader: Decline an applicant
    DeclineApplicant = function(listingId, applicantGuid)
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_DECLINE_APPLICATION, {
            listingId = listingId,
            applicantGuid = applicantGuid
        })
    end,
    
    -- Remove group listing (delist)
    Delist = function(listingId)
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_DELIST_GROUP, { listingId = listingId })
    end,
    
    -- Alias for Delist (backward compatibility)
    CancelListing = function(listingId)
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_DELIST_GROUP, { listingId = listingId })
    end,

    -- Get system info (rewards, etc)
    GetSystemInfo = function()
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_GET_SYSTEM_INFO, {})
    end,
    
    -- Update group listing
    UpdateListing = function(listingId, data)
        data.listingId = listingId
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_UPDATE_LISTING, data)
    end,
    
    -- Get my active applications
    GetMyApplications = function()
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_GET_MY_APPLICATIONS, {})
    end,
    
    -- Get player's keystone info
    GetKeystoneInfo = function()
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_GET_MY_KEYSTONE, {})
    end,
    
    -- Get M+ dungeon list from database (current season)
    GetDungeonList = function()
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_GET_DUNGEON_LIST, {})
    end,
    
    -- Get raid list from database (all eras)
    GetRaidList = function()
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_GET_RAID_LIST, {})
    end,
    
    -- Spectator functions
    StartSpectate = function(runId)
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_START_SPECTATE, { runId = runId })
    end,
    
    StopSpectate = function()
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_STOP_SPECTATE, {})
    end,
    
    GetSpectateList = function()
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_GET_SPECTATE_LIST, {})
    end,
    
    -- Difficulty control
    SetDifficulty = function(difficultyType, difficulty)
        -- difficultyType: "dungeon" or "raid"
        -- difficulty: "normal", "heroic", "mythic" (dungeon) or "10n", "25n", "10h", "25h" (raid)
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_SET_DIFFICULTY, {
            type = difficultyType,
            difficulty = difficulty
        })
    end,
    
    -- ========================================================================
    -- SCHEDULED EVENTS API
    -- ========================================================================
    
    -- Create a scheduled event
    CreateEvent = function(data)
        -- data: { eventType, dungeonId, dungeonName, keyLevel, scheduledTime (unix timestamp), maxSignups, note }
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_CREATE_EVENT, data)
    end,
    
    -- Sign up for an event
    SignupEvent = function(eventId, role, note)
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_SIGNUP_EVENT, {
            eventId = eventId,
            role = role or 0,
            note = note or ""
        })
    end,
    
    -- Cancel signup for an event
    CancelSignup = function(eventId)
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_CANCEL_SIGNUP, { eventId = eventId })
    end,
    
    -- Get upcoming scheduled events
    GetScheduledEvents = function(eventType)
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_GET_SCHEDULED_EVENTS, {
            eventType = eventType or 0  -- 0 = all types
        })
    end,
    
    -- Get my event signups
    GetMySignups = function()
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_GET_MY_SIGNUPS, {})
    end,
    
    -- Cancel an event (leader only)
    CancelEvent = function(eventId)
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_CANCEL_EVENT, { eventId = eventId })
    end,
}

local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
    if event == "CHAT_MSG_ADDON" then
        -- Accept DC protocol whispers regardless of sender name.
        -- Some server packets can arrive with sender != UnitName("player"),
        -- and filtering on sender would drop all server->client messages.
        if arg1 == DC.PREFIX and (arg3 == "WHISPER" or arg3 == "WHISPER_INFORM" or not arg3) then
            -- Chunked payload support (server may split large messages into INDEX|TOTAL|DATA chunks)
            -- Reassemble before normal parsing.
            local payload = arg2 or ""
            do
                local idxStr, totalStr, dataPart = string.match(payload, "^(%d+)|(%d+)|(.*)$")
                if idxStr and totalStr then
                    local idx = tonumber(idxStr) or 0
                    local total = tonumber(totalStr) or 0
                    if total > 0 and idx >= 0 and idx < total then
                        DC._chunkBuffers = DC._chunkBuffers or {}
                        local sender = arg4 or "_"
                        local now = time()

                        local buf = DC._chunkBuffers[sender]
                        -- Reset buffer if incompatible or stale
                        if not buf or buf.total ~= total or (buf.ts and now - buf.ts > 10) then
                            buf = { total = total, parts = {}, received = 0, seen = {}, ts = now }
                            DC._chunkBuffers[sender] = buf
                        else
                            buf.ts = now
                        end

                        local key = tostring(idx)
                        if not buf.seen[key] then
                            buf.seen[key] = true
                            buf.received = (buf.received or 0) + 1
                        end
                        buf.parts[idx + 1] = dataPart or ""

                        if buf.received >= total then
                            local full = ""
                            for i = 1, total do
                                full = full .. (buf.parts[i] or "")
                            end
                            payload = full
                            DC._chunkBuffers[sender] = nil
                        else
                            -- Wait for more chunks
                            return
                        end
                    end
                end
            end

            local parts = {}
            for p in string.gmatch(payload, "([^|]+)") do table.insert(parts, p) end
            if #parts >= 2 then
                local module = parts[1]
                local opcode = tonumber(parts[2]) or 0
                
                -- Debug output
                if DC._debug then
                    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[DC]|r Received: " .. module .. " opcode=" .. opcode .. " parts=" .. #parts)
                end
                
                -- Early: detect core error codes (SMSG_ERROR / SMSG_PERMISSION_DENIED)
                if opcode == DC.Opcode.Core.SMSG_ERROR or opcode == DC.Opcode.Core.SMSG_PERMISSION_DENIED then
                    -- Parse error payload
                    local errCode = tonumber(parts[3]) or 0
                    local errMsg = parts[4] or ""
                    -- Call module-specific error handlers
                    local errHandlers = DC._errorHandlers[module]
                    if errHandlers then
                        for _, h in ipairs(errHandlers) do
                            pcall(h, errCode, errMsg, opcode)
                        end
                    end
                    -- Call global error handlers
                    for _, h in ipairs(DC._globalErrorHandlers) do
                        pcall(h, module, errCode, errMsg, opcode)
                    end
                    -- Default behavior: display error in chat
                    DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[DC] Error:|r " .. module .. ": " .. (errMsg or "Unknown error"))
                    -- Log response
                    DC:LogResponse(module, opcode, {errCode, errMsg}, nil)
                    return
                end

                -- Check if this is a JSON message (format: MODULE|OPCODE|J|{json})
                if #parts >= 4 and parts[3] == "J" then
                    -- JSON message - reconstruct JSON (in case it had | in it)
                    local jsonParts = {}
                    for i = 4, #parts do
                        table.insert(jsonParts, parts[i])
                    end
                    local jsonStr = table.concat(jsonParts, "|")
                    local data = DC:DecodeJSON(jsonStr)
                    
                    -- Log response
                    DC:LogResponse(module, opcode, data, jsonStr)
                    
                    if DC._debug then
                        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[DC]|r JSON: " .. string.sub(jsonStr, 1, 200) .. (string.len(jsonStr) > 200 and "..." or ""))
                    end
                    
                    -- Try JSON-specific handler first
                    local jsonKey = module .. "_" .. opcode .. "_json"
                    local jsonHandler = DC._handlers[jsonKey]
                    if jsonHandler then
                        if type(jsonHandler) == 'table' then
                            if DC._debug then
                                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Handler(s) found: " .. jsonKey .. " (" .. tostring(#jsonHandler) .. ")")
                            end
                            for _, _h in ipairs(jsonHandler) do
                                pcall(_h, data, jsonStr)
                            end
                        else
                            if DC._debug then
                                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Handler found: " .. jsonKey)
                            end
                            pcall(jsonHandler, data, jsonStr)
                        end
                    else
                        -- Fall back to regular handler with decoded data
                        local key = module .. "_" .. opcode
                        local h = DC._handlers[key]
                        if h then 
                            if type(h) == 'table' then
                                if DC._debug then
                                    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Handler(s) found: " .. key .. " (" .. tostring(#h) .. ")")
                                end
                                for _, handler in ipairs(h) do pcall(handler, data) end
                            else
                                if DC._debug then
                                    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Handler found: " .. key)
                                end
                                pcall(h, data)
                            end
                        elseif DC._debug then
                            DEFAULT_CHAT_FRAME:AddMessage("|cffff6600[DC]|r No handler for: " .. key)
                        end
                    end
                else
                    -- Regular message - log it too
                    DC:LogResponse(module, opcode, {parts[3], parts[4], parts[5]}, nil)
                    
                    local key = module .. "_" .. opcode
                    local h = DC._handlers[key]
                    if type(h) == 'table' then
                        if DC._debug then
                            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[DC]|r Handler(s) found: " .. key .. " (" .. tostring(#h) .. ")")
                        end
                        for _, handler in ipairs(h) do pcall(handler, parts[3], parts[4], parts[5], parts[6], parts[7]) end
                    else
                        if DC._debug then
                            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[DC]|r Handler found: " .. key)
                        end
                        pcall(h, parts[3], parts[4], parts[5], parts[6], parts[7]) 
                    end
                    -- handlers already dispatched above
                end
            end
        end
    elseif event == "PLAYER_LOGIN" then
        DC:Send("CORE", 1, DC.VERSION)
    end
end)

SLASH_DC1 = "/dc"
SlashCmdList["DC"] = function(msg)
    local args = {}
    for word in string.gmatch(msg or "", "%S+") do
        table.insert(args, word)
    end
    local cmd = string.lower(args[1] or "")
    
    if cmd == "json" then
        local t = {name = "Test", level = 80, nested = {a = 1, b = 2}}
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Encode: " .. DC:EncodeJSON(t))
        local decoded = DC:DecodeJSON('{"name":"Player","level":80,"items":[1,2,3]}')
        if decoded then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Decode: name=" .. tostring(decoded.name) .. ", items=" .. tostring(decoded.items and #decoded.items or 0))
        end
    elseif cmd == "sendjson" then
        DC:SendJSON("CORE", 99, {action = "test", timestamp = time()})
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Sent JSON test")
    elseif cmd == "debug" then
        DC._debug = not DC._debug
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Debug mode: " .. (DC._debug and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
    elseif cmd == "status" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC Protocol]|r v" .. DC.VERSION)
        DEFAULT_CHAT_FRAME:AddMessage("  Connected: " .. (DC._connected and "|cff00ff00Yes|r" or "|cffff0000No|r"))
        if DC._serverVersion then
            DEFAULT_CHAT_FRAME:AddMessage("  Server Version: " .. DC._serverVersion)
        end
        DEFAULT_CHAT_FRAME:AddMessage("  Handlers: " .. DC:CountHandlers())
        DEFAULT_CHAT_FRAME:AddMessage("  Debug: " .. (DC._debug and "ON" or "OFF"))
    elseif cmd == "reconnect" then
        DC._connected = false
        DC._handshakeSent = false
        DC:Send("CORE", 1, DC.VERSION)
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Handshake sent")
    elseif cmd == "handlers" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Registered handlers (key: count):")
        for key, value in pairs(DC._handlers) do
            if type(value) == 'table' then
                DEFAULT_CHAT_FRAME:AddMessage(string.format("  - %s: %d", key, #value))
            else
                DEFAULT_CHAT_FRAME:AddMessage(string.format("  - %s: 1", key))
            end
        end
    elseif cmd == "unregister" then
        local m = args[2] or ""
        local oArg = args[3]
        local o = nil
        if oArg then
            o = tonumber(oArg)
            if not o then
                -- Try hex 0xNN format
                local s = string.lower(oArg)
                if s:match("^0x[0-9a-f]+$") then
                    o = tonumber(oArg:sub(3), 16)
                else
                    o = oArg -- fallback: treat as string opcode
                end
            end
        end
        local jsonflag = args[4]
        if m == "" or not o then
            DEFAULT_CHAT_FRAME:AddMessage("Usage: /dc unregister <MODULE> <OPCODE> [json]")
        else
            if jsonflag == "json" then
                if DC:UnregisterJSONHandler(m, o) then
                    DEFAULT_CHAT_FRAME:AddMessage(string.format("Unregistered JSON handlers for %s:%s", m, tostring(o)))
                else
                    DEFAULT_CHAT_FRAME:AddMessage(string.format("No JSON handlers found for %s:%s", m, tostring(o)))
                end
            else
                if DC:UnregisterHandler(m, o) then
                    DEFAULT_CHAT_FRAME:AddMessage(string.format("Unregistered handlers for %s:%s", m, tostring(o)))
                else
                    DEFAULT_CHAT_FRAME:AddMessage(string.format("No handlers found for %s:%s", m, tostring(o)))
                end
            end
        end
    elseif cmd == "panel" or cmd == "settings" or cmd == "config" then
        InterfaceOptionsFrame_OpenToCategory(DC.SettingsPanel)
        InterfaceOptionsFrame_OpenToCategory(DC.SettingsPanel)
    elseif cmd == "log" or cmd == "logs" then
        DC:ShowLogPanel()
    elseif cmd == "requests" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Recent Requests:")
        local requests = DC:GetRequestLog(10)
        if #requests == 0 then
            DEFAULT_CHAT_FRAME:AddMessage("  (no requests logged)")
        else
            for _, req in ipairs(requests) do
                local statusColor = req.status == "completed" and "|cff00ff00" or (req.status == "timeout" and "|cffff0000" or "|cffffff00")
                DEFAULT_CHAT_FRAME:AddMessage(string.format("  [%s] %s %s op=%d %s%s|r",
                    req.timeStr, req.moduleName, req.module, req.opcode, statusColor, req.status))
            end
        end
    elseif cmd == "responses" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Recent Responses:")
        local responses = DC:GetResponseLog(10)
        if #responses == 0 then
            DEFAULT_CHAT_FRAME:AddMessage("  (no responses logged)")
        else
            for _, resp in ipairs(responses) do
                DEFAULT_CHAT_FRAME:AddMessage(string.format("  [%s] %s %s op=%d len=%d",
                    resp.timeStr, resp.moduleName, resp.module, resp.opcode, resp.jsonLength or 0))
            end
        end
    elseif cmd == "pending" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Pending Requests:")
        local pending = DC:GetPendingRequests()
        if #pending == 0 then
            DEFAULT_CHAT_FRAME:AddMessage("  (no pending requests)")
        else
            for _, req in ipairs(pending) do
                local age = time() - req.timestamp
                local ageColor = age > 10 and "|cffff0000" or "|cffffff00"
                DEFAULT_CHAT_FRAME:AddMessage(string.format("  %s op=%d %s%ds ago|r",
                    req.moduleName, req.opcode, ageColor, age))
            end
        end
    elseif cmd == "clearlog" or cmd == "clearlogs" then
        DC:ClearLogs()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Logs cleared")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC Protocol]|r Commands:")
        DEFAULT_CHAT_FRAME:AddMessage("  /dc status - Show connection status")
        DEFAULT_CHAT_FRAME:AddMessage("  /dc debug - Toggle debug mode")
        DEFAULT_CHAT_FRAME:AddMessage("  /dc reconnect - Resend handshake")
        DEFAULT_CHAT_FRAME:AddMessage("  /dc handlers - List registered handlers (key: count)")
        DEFAULT_CHAT_FRAME:AddMessage("  /dc unregister <MODULE> <OPCODE> [json] - Unregister handlers (use 'json' for JSON handlers)")
        DEFAULT_CHAT_FRAME:AddMessage("  /dc json - Test JSON encode/decode")
        DEFAULT_CHAT_FRAME:AddMessage("  /dc panel - Open settings/debug panel")
        DEFAULT_CHAT_FRAME:AddMessage("  /dc log - Open request/response log panel")
        DEFAULT_CHAT_FRAME:AddMessage("  /dc requests - Show recent requests")
        DEFAULT_CHAT_FRAME:AddMessage("  /dc responses - Show recent responses")
        DEFAULT_CHAT_FRAME:AddMessage("  /dc pending - Show pending requests")
        DEFAULT_CHAT_FRAME:AddMessage("  /dc clearlog - Clear all logs")
    end
end

function DC:CountHandlers()
    local count = 0
    for key, value in pairs(self._handlers) do
        if type(value) == 'table' then
            count = count + #value
        else
            count = count + 1
        end
    end
    return count
end

-- ============================================================
-- Settings Panel with Debug/Testing Interface
-- ============================================================

local function CreateSettingsPanel()
    local panel = CreateFrame("Frame", "DCProtocolSettingsPanel", UIParent)
    panel.name = "DC Protocol"
    
    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cff00ff00DC Addon Protocol|r - Debug & Testing")
    
    -- Description
    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetWidth(560)
    desc:SetJustifyH("LEFT")
    desc:SetText("Test server communication, send custom JSON messages, and debug protocol handlers.")
    
    local yPos = -70
    
    -- Status Section
    local statusHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    statusHeader:SetPoint("TOPLEFT", 16, yPos)
    statusHeader:SetText("|cffffd700Protocol Status|r")
    yPos = yPos - 20
    
    local statusText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    statusText:SetPoint("TOPLEFT", 16, yPos)
    statusText:SetWidth(300)
    statusText:SetJustifyH("LEFT")
    DC._statusText = statusText
    yPos = yPos - 50
    
    local function UpdateStatus()
        local connected = DC._connected and "|cff00ff00Connected|r" or "|cffff0000Disconnected|r"
        local version = DC._serverVersion or "Unknown"
        local handlers = DC:CountHandlers()
        local debug = DC._debug and "|cff00ff00ON|r" or "|cffff0000OFF|r"
        statusText:SetText(
            "Status: " .. connected .. "\n" ..
            "Client Version: |cff00ccff" .. DC.VERSION .. "|r\n" ..
            "Server Version: |cff00ccff" .. version .. "|r\n" ..
            "Handlers: |cffffff00" .. handlers .. "|r\n" ..
            "Debug Mode: " .. debug
        )
    end
    
    -- Quick Actions Row
    local actionHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    actionHeader:SetPoint("TOPLEFT", 16, yPos)
    actionHeader:SetText("|cffffd700Quick Actions|r")
    yPos = yPos - 25
    
    local function CreateButton(text, tooltip, onClick, xOffset)
        local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        btn:SetWidth(120)
        btn:SetHeight(22)
        btn:SetPoint("TOPLEFT", 16 + xOffset, yPos)
        btn:SetText(text)
        btn:SetScript("OnClick", onClick)
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltip, nil, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return btn
    end
    
    CreateButton("Reconnect", "Send handshake to server", function()
        DC._connected = false
        DC._handshakeSent = false
        DC:Send("CORE", 1, DC.VERSION)
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Handshake sent")
        UpdateStatus()
    end, 0)
    
    CreateButton("Toggle Debug", "Enable/disable debug output", function()
        DC._debug = not DC._debug
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Debug: " .. (DC._debug and "ON" or "OFF"))
        UpdateStatus()
    end, 130)
    
    CreateButton("List Handlers", "Show all registered handlers", function()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Registered handlers:")
        for key, _ in pairs(DC._handlers) do
            DEFAULT_CHAT_FRAME:AddMessage("  - " .. key)
        end
    end, 260)
    
    CreateButton("Test JSON", "Test JSON encode/decode", function()
        local t = {name = "Test", level = 80, nested = {a = 1, b = 2}}
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Encode: " .. DC:EncodeJSON(t))
        local decoded = DC:DecodeJSON('{"name":"Player","level":80}')
        if decoded then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Decode OK: name=" .. tostring(decoded.name))
        end
    end, 390)
    
    yPos = yPos - 40
    
    -- JSON Editor Section
    local editorHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    editorHeader:SetPoint("TOPLEFT", 16, yPos)
    editorHeader:SetText("|cffffd700Send Custom JSON Message|r")
    yPos = yPos - 20
    
    -- Module dropdown
    local moduleLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    moduleLabel:SetPoint("TOPLEFT", 16, yPos)
    moduleLabel:SetText("Module:")
    
    local moduleInput = CreateFrame("EditBox", "DCProtocolModuleInput", panel, "InputBoxTemplate")
    moduleInput:SetPoint("LEFT", moduleLabel, "RIGHT", 10, 0)
    moduleInput:SetWidth(60)
    moduleInput:SetHeight(20)
    moduleInput:SetAutoFocus(false)
    moduleInput:SetText("CORE")
    moduleInput:SetMaxLetters(10)
    
    -- Opcode input
    local opcodeLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    opcodeLabel:SetPoint("LEFT", moduleInput, "RIGHT", 20, 0)
    opcodeLabel:SetText("Opcode:")
    
    local opcodeInput = CreateFrame("EditBox", "DCProtocolOpcodeInput", panel, "InputBoxTemplate")
    opcodeInput:SetPoint("LEFT", opcodeLabel, "RIGHT", 10, 0)
    opcodeInput:SetWidth(50)
    opcodeInput:SetHeight(20)
    opcodeInput:SetAutoFocus(false)
    opcodeInput:SetText("99")
    opcodeInput:SetMaxLetters(5)
    
    yPos = yPos - 30
    
    -- JSON text area label
    local jsonLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    jsonLabel:SetPoint("TOPLEFT", 16, yPos)
    jsonLabel:SetText("JSON Data (enter valid JSON object):")
    yPos = yPos - 18
    
    -- JSON text area with scrollframe
    local scrollFrame = CreateFrame("ScrollFrame", "DCProtocolJSONScroll", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 16, yPos)
    scrollFrame:SetWidth(540)
    scrollFrame:SetHeight(80)
    
    -- Create background (3.3.5 compatible - use solid texture)
    local jsonBg = scrollFrame:CreateTexture(nil, "BACKGROUND")
    jsonBg:SetAllPoints()
    jsonBg:SetTexture(0, 0, 0, 0.5)  -- 3.3.5 uses SetTexture with RGBA values
    
    local jsonEditBox = CreateFrame("EditBox", "DCProtocolJSONInput", scrollFrame)
    jsonEditBox:SetMultiLine(true)
    jsonEditBox:SetFontObject(ChatFontNormal)
    jsonEditBox:SetWidth(520)
    jsonEditBox:SetAutoFocus(false)
    jsonEditBox:SetText('{"action":"test","timestamp":0}')
    jsonEditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scrollFrame:SetScrollChild(jsonEditBox)
    
    yPos = yPos - 90
    
    -- Send buttons
    local sendJsonBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    sendJsonBtn:SetWidth(150)
    sendJsonBtn:SetHeight(24)
    sendJsonBtn:SetPoint("TOPLEFT", 16, yPos)
    sendJsonBtn:SetText("Send JSON Request")
    sendJsonBtn:SetScript("OnClick", function()
        local module = moduleInput:GetText() or "CORE"
        local opcode = tonumber(opcodeInput:GetText()) or 99
        local jsonText = jsonEditBox:GetText() or "{}"
        
        -- Try to decode to validate
        local data = DC:DecodeJSON(jsonText)
        if data then
            DC:Request(module, opcode, data)
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Sent JSON to " .. module .. "|" .. opcode)
            DEFAULT_CHAT_FRAME:AddMessage("|cff888888[DC]|r " .. jsonText)
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[DC]|r Invalid JSON! Check syntax.")
        end
    end)
    
    local sendRawBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    sendRawBtn:SetWidth(150)
    sendRawBtn:SetHeight(24)
    sendRawBtn:SetPoint("LEFT", sendJsonBtn, "RIGHT", 10, 0)
    sendRawBtn:SetText("Send Raw (pipe fmt)")
    sendRawBtn:SetScript("OnClick", function()
        local module = moduleInput:GetText() or "CORE"
        local opcode = tonumber(opcodeInput:GetText()) or 99
        local rawData = jsonEditBox:GetText() or ""
        
        -- Send as raw pipe-delimited (for legacy testing)
        DC:Send(module, opcode, rawData)
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Sent raw to " .. module .. "|" .. opcode .. "|" .. rawData)
    end)
    
    local validateBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    validateBtn:SetWidth(120)
    validateBtn:SetHeight(24)
    validateBtn:SetPoint("LEFT", sendRawBtn, "RIGHT", 10, 0)
    validateBtn:SetText("Validate JSON")
    validateBtn:SetScript("OnClick", function()
        local jsonText = jsonEditBox:GetText() or ""
        local data = DC:DecodeJSON(jsonText)
        if data then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r JSON is valid!")
            -- Pretty print keys
            local keys = {}
            for k, v in pairs(data) do
                table.insert(keys, k .. "=" .. tostring(v))
            end
            DEFAULT_CHAT_FRAME:AddMessage("|cff888888[DC]|r Keys: " .. table.concat(keys, ", "))
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[DC]|r Invalid JSON syntax!")
        end
    end)
    
    yPos = yPos - 40
    
    -- Preset buttons
    local presetHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    presetHeader:SetPoint("TOPLEFT", 16, yPos)
    presetHeader:SetText("|cffffd700Quick Presets|r")
    yPos = yPos - 25
    
    local presets = {
        { label = "Handshake", module = "CORE", opcode = 1, json = '{"version":"' .. DC.VERSION .. '"}' },
        { label = "Get AOE Settings", module = "AOE", opcode = 6, json = '{"action":"get_settings"}' },
        { label = "Get Hotspot List", module = "SPOT", opcode = 1, json = '{"action":"list"}' },
        { label = "Get Season Info", module = "SEAS", opcode = 1, json = '{}' },
        { label = "Get M+ Key", module = "MPLUS", opcode = 1, json = '{}' },
    }
    
    local xOffset = 0
    for i, preset in ipairs(presets) do
        local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        btn:SetWidth(100)
        btn:SetHeight(20)
        btn:SetPoint("TOPLEFT", 16 + xOffset, yPos)
        btn:SetText(preset.label)
        btn:SetScript("OnClick", function()
            moduleInput:SetText(preset.module)
            opcodeInput:SetText(tostring(preset.opcode))
            jsonEditBox:SetText(preset.json)
        end)
        xOffset = xOffset + 105
        if xOffset >= 525 then
            xOffset = 0
            yPos = yPos - 25
        end
    end
    
    yPos = yPos - 40
    
    -- Message Log Section
    local logHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    logHeader:SetPoint("TOPLEFT", 16, yPos)
    logHeader:SetText("|cffffd700Recent Messages|r (check chat for full log)")
    yPos = yPos - 18
    
    local logInfo = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    logInfo:SetPoint("TOPLEFT", 16, yPos)
    logInfo:SetWidth(560)
    logInfo:SetJustifyH("LEFT")
    logInfo:SetText("Enable debug mode (/dc debug) to see all incoming/outgoing messages in chat.\n" ..
                    "Use /dc handlers to list all registered message handlers.\n" ..
                    "Use /dc status for quick protocol status check.")
    
    -- Refresh status on show
    panel:SetScript("OnShow", function()
        UpdateStatus()
    end)
    
    -- Initial status update
    UpdateStatus()
    
    -- Register with interface options
    InterfaceOptions_AddCategory(panel)
    
    return panel
end

-- Create settings panel on load
DC.SettingsPanel = CreateSettingsPanel()

-- Slash command to open settings
SLASH_DCPANEL1 = "/dcpanel"
SLASH_DCPANEL2 = "/dcprotocol"
SlashCmdList["DCPANEL"] = function()
    InterfaceOptionsFrame_OpenToCategory(DC.SettingsPanel)
    InterfaceOptionsFrame_OpenToCategory(DC.SettingsPanel)  -- Call twice for WoW bug
end

-- Debug print helper
function DC:DebugPrint(...)
    if not self._debug then return end
    local parts = {}
    for i = 1, select("#", ...) do
        table.insert(parts, tostring(select(i, ...)))
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cff888888[DC Debug]|r " .. table.concat(parts, " "))
end

-- Check if connected to server
function DC:IsConnected()
    return self._connected
end

-- Get server feature availability
function DC:HasFeature(feature)
    return self._features[feature] == true
end

-- Register built-in handlers for CORE module
DC:RegisterHandler("CORE", 0x10, function(arg1, arg2)
    -- Handle both JSON format (arg1 = table) and pipe format (arg1 = version string)
    local version, features
    if type(arg1) == "table" then
        version = arg1.version or arg1.v or "1.0.0"
        features = arg1.features
    else
        version = arg1 or "1.0.0"
        features = arg2
    end
    
    DC._connected = true
    DC._serverVersion = tostring(version)
    DC:DebugPrint("Handshake ACK received, server v" .. tostring(version))
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC Protocol]|r Connected to server v" .. tostring(version))
    
    if features then
        if type(features) == "table" then
            for _, feat in ipairs(features) do
                DC._features[feat] = true
            end
        elseif type(features) == "string" then
            for feat in string.gmatch(features, "([^,]+)") do
                DC._features[feat] = true
            end
        end
    end
    
    -- Update settings panel if open
    if DC._statusText then
        local connected = "|cff00ff00Connected|r"
        local handlers = DC:CountHandlers()
        local debug = DC._debug and "|cff00ff00ON|r" or "|cffff0000OFF|r"
        DC._statusText:SetText(
            "Status: " .. connected .. "\n" ..
            "Client Version: |cff00ccff" .. DC.VERSION .. "|r\n" ..
            "Server Version: |cff00ccff" .. DC._serverVersion .. "|r\n" ..
            "Handlers: |cffffff00" .. handlers .. "|r\n" ..
            "Debug Mode: " .. debug
        )
    end
end)

DC:RegisterHandler("CORE", 0x12, function(...)
    local features = {...}
    DC:DebugPrint("Feature list received:", table.concat(features, ", "))
    for _, feat in ipairs(features) do
        DC._features[feat] = true
    end
end)

-- Test response handler (opcode 0x63 = 99 decimal) - for debug panel testing
DC:RegisterHandler("CORE", 0x63, function(...)
    local args = {...}
    if type(args[1]) == "table" then
        -- JSON response
        local json = args[1]
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[DC Test Response]|r Received JSON response from server:")
        for k, v in pairs(json) do
            DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00" .. tostring(k) .. "|r = " .. tostring(v))
        end
    else
        -- Pipe-delimited response
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[DC Test Response]|r Server replied: " .. table.concat(args, ", "))
    end
end)

-- SMSG_KEYSTONE_LIST: update client-side keystone mapping from server
DC:RegisterHandler("MPLUS", 0x17, function(data)
    -- Expect JSON payload: { items = [300313, 300314, ...] }
    if type(data) ~= 'table' then
        return
    end
    if data.items then
        -- Support string-encoded arrays (server may send JSON encoded string) and table arrays
        local itemsTbl = nil
        if type(data.items) == 'table' then
            itemsTbl = data.items
        elseif type(data.items) == 'string' then
            -- Try to decode JSON string to a table
            local ok, decoded = pcall(function() return DC:DecodeJSON(data.items) end)
            if ok and type(decoded) == 'table' then
                itemsTbl = decoded
            else
                -- Fallback: parse comma-separated numbers
                itemsTbl = {}
                for num in string.gmatch(data.items, '(%d+)') do
                    table.insert(itemsTbl, tonumber(num))
                end
            end
        end
        if itemsTbl and type(itemsTbl) == 'table' then
            local newMap = {}
            for _, id in ipairs(itemsTbl) do
                local num = tonumber(id)
                if num then
                    newMap[num] = true
                end
            end
            DC.KEYSTONE_ITEM_IDS = newMap
            -- If the DC central module is present, copy to DCCentral too
            local DCCentral = rawget(_G, "DCCentral")
            if DCCentral then
                DCCentral.KEYSTONE_ITEM_IDS = newMap
            end
            if DC._debug then
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[DC]|r Keystone ID list updated from server (" .. tostring(#itemsTbl) .. " items)")
            end
        end
    end
end)

-- Generic echo handler for any module test (opcode 0xFF)
DC:RegisterHandler("CORE", 0xFF, function(...)
    local args = {...}
    if type(args[1]) == "table" then
        local json = args[1]
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[DC Echo]|r Server echoed back:")
        DEFAULT_CHAT_FRAME:AddMessage("  " .. DC:EncodeJSON(json))
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[DC Echo]|r " .. table.concat(args, "|"))
    end
end)

-- ============================================================
-- Request/Response Log Panel (Leaderboard Style)
-- ============================================================

-- Statistics tracking - initialize sessionStart
DC._stats.sessionStart = time()

-- Update statistics when logging
function DC:UpdateStats(entryType, entry)
    if entryType == "request" then
        self._stats.totalRequests = self._stats.totalRequests + 1
        
        -- Per-module stats
        local mod = entry.module or "UNKNOWN"
        if not self._stats.moduleStats[mod] then
            self._stats.moduleStats[mod] = {
                requests = 0,
                responses = 0,
                timeouts = 0,
                totalResponseTime = 0,
                avgResponseTime = 0,
            }
        end
        self._stats.moduleStats[mod].requests = self._stats.moduleStats[mod].requests + 1
        
    elseif entryType == "response" then
        self._stats.totalResponses = self._stats.totalResponses + 1
        
        local mod = entry.module or "UNKNOWN"
        if self._stats.moduleStats[mod] then
            self._stats.moduleStats[mod].responses = self._stats.moduleStats[mod].responses + 1
        end
        
    elseif entryType == "timeout" then
        self._stats.totalTimeouts = self._stats.totalTimeouts + 1
        
        local mod = entry.module or "UNKNOWN"
        if self._stats.moduleStats[mod] then
            self._stats.moduleStats[mod].timeouts = self._stats.moduleStats[mod].timeouts + 1
        end
    end
end

-- Get module statistics as leaderboard-style sorted list
function DC:GetModuleLeaderboard()
    local list = {}
    for mod, stats in pairs(self._stats.moduleStats) do
        table.insert(list, {
            module = mod,
            moduleName = self.ModuleNames[mod] or mod,
            requests = stats.requests,
            responses = stats.responses,
            timeouts = stats.timeouts,
            successRate = stats.requests > 0 and math.floor((stats.responses / stats.requests) * 100) or 0,
            avgResponseTime = stats.avgResponseTime,
        })
    end
    
    -- Sort by requests (most active first)
    table.sort(list, function(a, b) return a.requests > b.requests end)
    
    return list
end

function DC:ShowLogPanel()
    if self.LogPanel then
        self.LogPanel:Show()
        self:RefreshLogPanel()
        return
    end
    
    -- Create the log panel (wider for leaderboard style)
    local frame = CreateFrame("Frame", "DCProtocolLogPanel", UIParent)
    frame:SetSize(850, 550)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    
    -- Background
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background")
    bg:SetVertexColor(0.08, 0.08, 0.08, 0.98)
    
    -- Border
    local border = CreateFrame("Frame", nil, frame)
    border:SetAllPoints()
    border:SetBackdrop({
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    
    -- Title bar
    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetSize(830, 28)
    titleBar:SetPoint("TOP", 0, -8)
    local titleBarBg = titleBar:CreateTexture(nil, "ARTWORK")
    titleBarBg:SetAllPoints()
    titleBarBg:SetTexture(0.15, 0.15, 0.15, 0.6)
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText("|cff00ff00DC Protocol Monitor|r")
    
    -- Subtitle with session info
    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -2)
    subtitle:SetText("|cff888888Request/Response Tracking & Statistics|r")
    frame.subtitle = subtitle
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
    
    tinsert(UISpecialFrames, "DCProtocolLogPanel")
    
    -- Left panel: Statistics summary
    local statsPanel = CreateFrame("Frame", nil, frame)
    statsPanel:SetSize(200, 460)
    statsPanel:SetPoint("TOPLEFT", 15, -50)
    frame.statsPanel = statsPanel
    
    local statsBg = statsPanel:CreateTexture(nil, "BACKGROUND")
    statsBg:SetAllPoints()
    statsBg:SetTexture(0.12, 0.12, 0.12, 0.8)
    
    local statsTitle = statsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statsTitle:SetPoint("TOP", 0, -10)
    statsTitle:SetText("|cffffd700Session Statistics|r")
    
    -- Stats will be populated in RefreshLogPanel
    frame.statsLabels = {}
    
    -- Right panel: Tab content area
    local contentPanel = CreateFrame("Frame", nil, frame)
    contentPanel:SetSize(610, 460)
    contentPanel:SetPoint("TOPRIGHT", -15, -50)
    frame.contentPanel = contentPanel
    
    -- Tab buttons (inside content panel)
    local tabFrame = CreateFrame("Frame", nil, contentPanel)
    tabFrame:SetSize(610, 28)
    tabFrame:SetPoint("TOP", 0, 0)
    
    local tabs = {
        { id = "requests", label = "Requests", icon = "Interface\\Icons\\INV_Letter_15" },
        { id = "responses", label = "Responses", icon = "Interface\\Icons\\INV_Letter_16" },
        { id = "pending", label = "Pending", icon = "Interface\\Icons\\Spell_Holy_BorrowedTime" },
        { id = "modules", label = "By Module", icon = "Interface\\Icons\\Trade_Engineering" },
    }
    
    frame.tabButtons = {}
    local tabX = 0
    for _, tab in ipairs(tabs) do
        local btn = CreateFrame("Button", nil, tabFrame)
        btn:SetSize(145, 26)
        btn:SetPoint("LEFT", tabX, 0)
        
        local btnBg = btn:CreateTexture(nil, "BACKGROUND")
        btnBg:SetAllPoints()
        btnBg:SetTexture(0.2, 0.2, 0.2, 0.8)
        btn.bg = btnBg
        
        local btnIcon = btn:CreateTexture(nil, "ARTWORK")
        btnIcon:SetSize(18, 18)
        btnIcon:SetPoint("LEFT", 5, 0)
        btnIcon:SetTexture(tab.icon)
        
        local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btnText:SetPoint("LEFT", btnIcon, "RIGHT", 5, 0)
        btnText:SetText(tab.label)
        btn.text = btnText
        
        btn:SetScript("OnClick", function()
            frame.currentTab = tab.id
            DC:RefreshLogPanel()
        end)
        
        btn:SetScript("OnEnter", function(self)
            if frame.currentTab ~= tab.id then
                self.bg:SetTexture(0.3, 0.3, 0.3, 0.8)
            end
        end)
        
        btn:SetScript("OnLeave", function(self)
            if frame.currentTab ~= tab.id then
                self.bg:SetTexture(0.2, 0.2, 0.2, 0.8)
            end
        end)
        
        frame.tabButtons[tab.id] = btn
        tabX = tabX + 150
    end
    
    -- Action buttons
    local clearBtn = CreateFrame("Button", nil, contentPanel, "UIPanelButtonTemplate")
    clearBtn:SetSize(70, 20)
    clearBtn:SetPoint("TOPRIGHT", 0, 0)
    clearBtn:SetText("Clear")
    clearBtn:SetScript("OnClick", function()
        DC:ClearLogs()
        DC._stats = {
            totalRequests = 0,
            totalResponses = 0,
            totalTimeouts = 0,
            avgResponseTime = 0,
            moduleStats = {},
            sessionStart = time(),
        }
        DC:RefreshLogPanel()
    end)
    
    -- Column headers (dynamic based on tab)
    local headerFrame = CreateFrame("Frame", nil, contentPanel)
    headerFrame:SetSize(590, 22)
    headerFrame:SetPoint("TOP", tabFrame, "BOTTOM", 0, -5)
    frame.headerFrame = headerFrame
    
    local headerBg = headerFrame:CreateTexture(nil, "BACKGROUND")
    headerBg:SetAllPoints()
    headerBg:SetTexture(0.18, 0.18, 0.18, 0.9)
    
    frame.headerLabels = {}
    
    -- Scroll frame for entries
    local scrollFrame = CreateFrame("ScrollFrame", "DCLogScrollFrame", contentPanel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(590, 380)
    scrollFrame:SetPoint("TOP", headerFrame, "BOTTOM", 0, -2)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(570, 1)
    scrollFrame:SetScrollChild(scrollChild)
    frame.scrollChild = scrollChild
    
    -- Bottom status bar
    local statusBar = CreateFrame("Frame", nil, frame)
    statusBar:SetSize(820, 20)
    statusBar:SetPoint("BOTTOM", 0, 10)
    
    local statusText = statusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("LEFT", 20, 0)
    statusText:SetText("|cff888888Session started: " .. date("%H:%M:%S") .. "|r")
    frame.statusText = statusText
    
    frame.currentTab = "requests"
    frame.entryFrames = {}
    
    self.LogPanel = frame
    self:RefreshLogPanel()
end

function DC:RefreshLogPanel()
    if not self.LogPanel then return end
    
    local frame = self.LogPanel
    local scrollChild = frame.scrollChild
    local headerFrame = frame.headerFrame
    
    -- Update statistics panel
    self:UpdateStatsPanel()
    
    -- Clear existing entries
    for _, entryFrame in ipairs(frame.entryFrames) do
        entryFrame:Hide()
        entryFrame:SetParent(nil)
    end
    frame.entryFrames = {}
    
    -- Clear header labels
    for _, label in ipairs(frame.headerLabels) do
        label:SetText("")
    end
    
    -- Update tab highlighting
    for id, btn in pairs(frame.tabButtons) do
        if frame.currentTab == id then
            btn.bg:SetTexture(0.2, 0.4, 0.2, 0.9)
            btn.text:SetText("|cff00ff00" .. btn.text:GetText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") .. "|r")
        else
            btn.bg:SetTexture(0.2, 0.2, 0.2, 0.8)
            btn.text:SetText(btn.text:GetText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
        end
    end
    
    -- Setup columns and get data based on current tab
    local columns, entries
    
    if frame.currentTab == "requests" then
        columns = {
            { x = 5, width = 55, label = "#" },
            { x = 40, width = 65, label = "Time" },
            { x = 110, width = 100, label = "Module" },
            { x = 210, width = 60, label = "Opcode" },
            { x = 280, width = 80, label = "Status" },
            { x = 370, width = 200, label = "Data Preview" },
        }
        entries = self:GetRequestLog(50)
        
    elseif frame.currentTab == "responses" then
        columns = {
            { x = 5, width = 55, label = "#" },
            { x = 40, width = 65, label = "Time" },
            { x = 110, width = 100, label = "Module" },
            { x = 210, width = 60, label = "Opcode" },
            { x = 280, width = 70, label = "Size" },
            { x = 360, width = 210, label = "Data Preview" },
        }
        entries = self:GetResponseLog(50)
        
    elseif frame.currentTab == "pending" then
        columns = {
            { x = 5, width = 55, label = "#" },
            { x = 40, width = 65, label = "Time" },
            { x = 110, width = 100, label = "Module" },
            { x = 210, width = 60, label = "Opcode" },
            { x = 280, width = 70, label = "Age" },
            { x = 360, width = 80, label = "Status" },
            { x = 450, width = 120, label = "Data" },
        }
        entries = self:GetPendingRequests()
        
    elseif frame.currentTab == "modules" then
        columns = {
            { x = 5, width = 40, label = "Rank" },
            { x = 50, width = 120, label = "Module" },
            { x = 180, width = 70, label = "Requests" },
            { x = 260, width = 70, label = "Responses" },
            { x = 340, width = 60, label = "Timeouts" },
            { x = 410, width = 80, label = "Success %" },
            { x = 500, width = 70, label = "Avg Time" },
        }
        entries = self:GetModuleLeaderboard()
    end
    
    -- Create header labels
    for i, col in ipairs(columns) do
        local label = frame.headerLabels[i]
        if not label then
            label = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            frame.headerLabels[i] = label
        end
        label:ClearAllPoints()
        label:SetPoint("LEFT", col.x, 0)
        label:SetText("|cffffd700" .. col.label .. "|r")
    end
    
    -- Create entry rows
    local yOffset = 0
    local rowHeight = 24
    
    for i, entry in ipairs(entries) do
        local row = CreateFrame("Button", nil, scrollChild)
        row:SetSize(570, rowHeight)
        row:SetPoint("TOPLEFT", 0, yOffset)
        
        -- Alternating background with hover
        local rowBg = row:CreateTexture(nil, "BACKGROUND")
        rowBg:SetAllPoints()
        local bgColor = i % 2 == 0 and 0.14 or 0.10
        rowBg:SetTexture(bgColor, bgColor, bgColor, 0.7)
        row.bg = rowBg
        row.bgColor = bgColor
        
        row:SetScript("OnEnter", function(self)
            self.bg:SetTexture(0.25, 0.25, 0.3, 0.8)
        end)
        row:SetScript("OnLeave", function(self)
            self.bg:SetTexture(self.bgColor, self.bgColor, self.bgColor, 0.7)
        end)
        
        -- Populate based on tab
        if frame.currentTab == "modules" then
            -- Module leaderboard row
            self:CreateModuleRow(row, entry, i, columns)
        else
            -- Log entry row
            self:CreateLogRow(row, entry, i, columns, frame.currentTab)
        end
        
        table.insert(frame.entryFrames, row)
        yOffset = yOffset - rowHeight
    end
    
    -- Update scroll child height
    scrollChild:SetHeight(math.max(1, math.abs(yOffset)))
    
    -- Show empty message if no entries
    if #entries == 0 then
        local emptyText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        emptyText:SetPoint("CENTER", 0, 50)
        emptyText:SetText("|cff666666No " .. frame.currentTab .. " to display|r")
        local emptyFrame = CreateFrame("Frame", nil, scrollChild)
        emptyFrame:SetAllPoints()
        table.insert(frame.entryFrames, emptyFrame)
    end
    
    -- Update status bar
    local sessionTime = time() - self._stats.sessionStart
    local hours = math.floor(sessionTime / 3600)
    local mins = math.floor((sessionTime % 3600) / 60)
    local secs = sessionTime % 60
    frame.statusText:SetText(string.format(
        "|cff888888Session: %02d:%02d:%02d | Requests: %d | Responses: %d | Timeouts: %d|r",
        hours, mins, secs,
        self._stats.totalRequests,
        self._stats.totalResponses,
        self._stats.totalTimeouts
    ))
end

function DC:CreateLogRow(row, entry, index, columns, tabType)
    -- Row number
    local numText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    numText:SetPoint("LEFT", columns[1].x, 0)
    numText:SetText("|cff888888" .. index .. "|r")
    
    -- Time
    local timeText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    timeText:SetPoint("LEFT", columns[2].x, 0)
    timeText:SetText("|cffffffff" .. (entry.timeStr or "--:--:--") .. "|r")
    
    -- Module with color
    local modText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    modText:SetPoint("LEFT", columns[3].x, 0)
    local modColor = self:GetModuleColor(entry.module)
    modText:SetText(modColor .. (entry.moduleName or entry.module or "?") .. "|r")
    
    -- Opcode
    local opText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    opText:SetPoint("LEFT", columns[4].x, 0)
    opText:SetText("|cffffff00" .. string.format("0x%02X", entry.opcode or 0) .. "|r")
    
    if tabType == "requests" then
        -- Status
        local statusText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        statusText:SetPoint("LEFT", columns[5].x, 0)
        local statusColor = entry.status == "completed" and "|cff00ff00" or 
                           (entry.status == "timeout" and "|cffff0000" or "|cffffff00")
        statusText:SetText(statusColor .. (entry.status or "?") .. "|r")
        
        -- Data preview
        local dataText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        dataText:SetPoint("LEFT", columns[6].x, 0)
        dataText:SetWidth(190)
        dataText:SetJustifyH("LEFT")
        dataText:SetText("|cff888888" .. self:FormatDataPreview(entry.data, 40) .. "|r")
        
    elseif tabType == "responses" then
        -- Size
        local sizeText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        sizeText:SetPoint("LEFT", columns[5].x, 0)
        local size = entry.jsonLength or 0
        local sizeColor = size > 1000 and "|cffff8800" or "|cff00ff00"
        sizeText:SetText(sizeColor .. size .. " B|r")
        
        -- Data preview
        local dataText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        dataText:SetPoint("LEFT", columns[6].x, 0)
        dataText:SetWidth(200)
        dataText:SetJustifyH("LEFT")
        dataText:SetText("|cff888888" .. self:FormatDataPreview(entry.data, 45) .. "|r")
        
    elseif tabType == "pending" then
        -- Age
        local ageText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        ageText:SetPoint("LEFT", columns[5].x, 0)
        local age = time() - (entry.timestamp or time())
        local ageColor = age > 10 and "|cffff0000" or (age > 5 and "|cffffff00" or "|cff00ff00")
        ageText:SetText(ageColor .. age .. "s|r")
        
        -- Status
        local statusText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        statusText:SetPoint("LEFT", columns[6].x, 0)
        local statusColor = age > 30 and "|cffff0000" or "|cffffff00"
        statusText:SetText(statusColor .. (age > 30 and "TIMEOUT" or "waiting...") .. "|r")
        
        -- Data
        local dataText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        dataText:SetPoint("LEFT", columns[7].x, 0)
        dataText:SetWidth(110)
        dataText:SetJustifyH("LEFT")
        dataText:SetText("|cff888888" .. self:FormatDataPreview(entry.data, 25) .. "|r")
    end
end

function DC:CreateModuleRow(row, entry, index, columns)
    -- Rank with medal colors
    local rankText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rankText:SetPoint("LEFT", columns[1].x, 0)
    local rankColor = index == 1 and "|cffffff00" or (index == 2 and "|cffc0c0c0" or (index == 3 and "|cffcd7f32" or "|cffffffff"))
    rankText:SetText(rankColor .. "#" .. index .. "|r")
    
    -- Module name
    local modText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    modText:SetPoint("LEFT", columns[2].x, 0)
    local modColor = self:GetModuleColor(entry.module)
    modText:SetText(modColor .. entry.moduleName .. "|r")
    
    -- Requests count
    local reqText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    reqText:SetPoint("LEFT", columns[3].x, 0)
    reqText:SetText("|cff00ccff" .. entry.requests .. "|r")
    
    -- Responses count
    local respText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    respText:SetPoint("LEFT", columns[4].x, 0)
    respText:SetText("|cff00ff00" .. entry.responses .. "|r")
    
    -- Timeouts count
    local timeoutText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    timeoutText:SetPoint("LEFT", columns[5].x, 0)
    local toColor = entry.timeouts > 0 and "|cffff0000" or "|cff888888"
    timeoutText:SetText(toColor .. entry.timeouts .. "|r")
    
    -- Success rate with color gradient
    local successText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    successText:SetPoint("LEFT", columns[6].x, 0)
    local successColor = entry.successRate >= 90 and "|cff00ff00" or 
                        (entry.successRate >= 70 and "|cffffff00" or "|cffff0000")
    successText:SetText(successColor .. entry.successRate .. "%|r")
    
    -- Average response time
    local avgText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    avgText:SetPoint("LEFT", columns[7].x, 0)
    avgText:SetText("|cff888888" .. string.format("%.1fs", entry.avgResponseTime or 0) .. "|r")
end

function DC:UpdateStatsPanel()
    if not self.LogPanel or not self.LogPanel.statsPanel then return end
    
    local panel = self.LogPanel.statsPanel
    
    -- Clear existing stat labels
    for _, child in pairs({panel:GetChildren()}) do
        child:Hide()
    end
    
    local yOffset = -35
    local stats = {
        { label = "Total Requests", value = self._stats.totalRequests, color = "|cff00ccff" },
        { label = "Total Responses", value = self._stats.totalResponses, color = "|cff00ff00" },
        { label = "Total Timeouts", value = self._stats.totalTimeouts, color = self._stats.totalTimeouts > 0 and "|cffff0000" or "|cff888888" },
        { label = "", value = "", color = "" }, -- Spacer
        { label = "Pending Requests", value = #self:GetPendingRequests(), color = "|cffffff00" },
        { label = "Active Modules", value = self:CountTable(self._stats.moduleStats), color = "|cff00ff00" },
    }
    
    for _, stat in ipairs(stats) do
        if stat.label ~= "" then
            local labelText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            labelText:SetPoint("TOPLEFT", 10, yOffset)
            labelText:SetText("|cff888888" .. stat.label .. ":|r")
            
            local valueText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            valueText:SetPoint("TOPRIGHT", -10, yOffset)
            valueText:SetText(stat.color .. tostring(stat.value) .. "|r")
        end
        yOffset = yOffset - 20
    end
    
    -- Success rate
    local successRate = self._stats.totalRequests > 0 and 
        math.floor((self._stats.totalResponses / self._stats.totalRequests) * 100) or 0
    
    yOffset = yOffset - 10
    local rateLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rateLabel:SetPoint("TOPLEFT", 10, yOffset)
    rateLabel:SetText("|cffffd700Success Rate:|r")
    
    yOffset = yOffset - 25
    local rateValue = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    rateValue:SetPoint("TOP", 0, yOffset)
    local rateColor = successRate >= 90 and "|cff00ff00" or 
                     (successRate >= 70 and "|cffffff00" or "|cffff0000")
    rateValue:SetText(rateColor .. successRate .. "%|r")
    
    -- Session time
    yOffset = yOffset - 40
    local sessionLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sessionLabel:SetPoint("TOPLEFT", 10, yOffset)
    sessionLabel:SetText("|cff888888Session Time:|r")
    
    local sessionTime = time() - self._stats.sessionStart
    local hours = math.floor(sessionTime / 3600)
    local mins = math.floor((sessionTime % 3600) / 60)
    local secs = sessionTime % 60
    
    yOffset = yOffset - 18
    local sessionValue = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sessionValue:SetPoint("TOP", 0, yOffset)
    sessionValue:SetText(string.format("|cffffffff%02d:%02d:%02d|r", hours, mins, secs))
    
    -- Most active module
    local moduleList = self:GetModuleLeaderboard()
    if #moduleList > 0 then
        yOffset = yOffset - 30
        local topLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        topLabel:SetPoint("TOPLEFT", 10, yOffset)
        topLabel:SetText("|cffffd700Most Active:|r")
        
        yOffset = yOffset - 18
        local topValue = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        topValue:SetPoint("TOP", 0, yOffset)
        local modColor = self:GetModuleColor(moduleList[1].module)
        topValue:SetText(modColor .. moduleList[1].moduleName .. "|r")
        
        yOffset = yOffset - 15
        local topCount = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        topCount:SetPoint("TOP", 0, yOffset)
        topCount:SetText("|cff888888(" .. moduleList[1].requests .. " requests)|r")
    end
end

function DC:GetModuleColor(module)
    local colors = {
        CORE = "|cff00ff00",
        AOEL = "|cffff8800",
        SPOT = "|cff00ccff",
        UPGR = "|cffa335ee",
        SPEC = "|cff0070dd",
        DUEL = "|cffff0000",
        MPLS = "|cffff8000",
        SEAS = "|cffffff00",
        LBRD = "|cff00ff96",
    }
    return colors[module] or "|cffffffff"
end

function DC:FormatDataPreview(data, maxLen)
    if not data then return "-" end
    
    local preview = ""
    if type(data) == "table" then
        preview = self:EncodeJSON(data)
    else
        preview = tostring(data)
    end
    
    if string.len(preview) > maxLen then
        preview = string.sub(preview, 1, maxLen - 3) .. "..."
    end
    
    return preview
end

function DC:CountTable(t)
    local count = 0
    for _ in pairs(t or {}) do count = count + 1 end
    return count
end

DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC Protocol]|r v" .. DC.VERSION .. " loaded" .. (DC._chatFrameProtected and " (ChatFrame protected)" or ""))
