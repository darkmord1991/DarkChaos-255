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
    VERSION = "1.5.1",
    _handlers = {},
    _debug = false,
    _connected = false,
    _serverVersion = nil,
    _features = {},
    _handshakeSent = false,
    _lastHandshakeTime = 0,
}

local DC = DCAddonProtocol

function DC:RegisterHandler(module, opcode, handler)
    local key = module .. "_" .. tostring(opcode)
    self._handlers[key] = handler
end

function DC:RegisterJSONHandler(module, opcode, handler)
    local key = module .. "_" .. tostring(opcode) .. "_json"
    self._handlers[key] = handler
end

function DC:Send(module, opcode, a1, a2, a3, a4, a5)
    local parts = {module, tostring(opcode)}
    local args = {a1, a2, a3, a4, a5}
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
    SendAddonMessage(self.PREFIX, msg, "WHISPER", UnitName("player"))
end

function DC:SendJSON(module, opcode, data)
    local json = self:EncodeJSON(data)
    local msg = module .. "|" .. tostring(opcode) .. "|J|" .. json
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
}

-- Opcode definitions for each module
DC.Opcode = {
    Core = {
        CMSG_HANDSHAKE = 0x01,
        SMSG_HANDSHAKE_ACK = 0x10,
        SMSG_FEATURE_LIST = 0x12,
        SMSG_ERROR = 0x1F,
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
        SMSG_ITEM_INFO = 0x10,
        SMSG_UPGRADE_RESULT = 0x11,
        SMSG_BATCH_ITEM_INFO = 0x12,
        SMSG_CURRENCY_UPDATE = 0x14,
    },
    Spec = {
        CMSG_REQUEST_SPECTATE = 0x01,
        CMSG_LIST_RUNS = 0x03,
        SMSG_RUN_LIST = 0x12,
    },
    MPlus = {
        CMSG_GET_KEY_INFO = 0x01,
        SMSG_KEY_INFO = 0x10,
    },
    Season = {
        CMSG_GET_CURRENT = 0x01,
        SMSG_CURRENT = 0x10,
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

local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
    if event == "CHAT_MSG_ADDON" then
        if arg1 == DC.PREFIX and arg4 == UnitName("player") then
            local parts = {}
            for p in string.gmatch(arg2, "([^|]+)") do table.insert(parts, p) end
            if #parts >= 2 then
                local module = parts[1]
                local opcode = parts[2]
                
                -- Check if this is a JSON message (format: MODULE|OPCODE|J|{json})
                if #parts >= 4 and parts[3] == "J" then
                    -- JSON message - reconstruct JSON (in case it had | in it)
                    local jsonParts = {}
                    for i = 4, #parts do
                        table.insert(jsonParts, parts[i])
                    end
                    local jsonStr = table.concat(jsonParts, "|")
                    local data = DC:DecodeJSON(jsonStr)
                    
                    -- Try JSON-specific handler first
                    local jsonKey = module .. "_" .. opcode .. "_json"
                    local jsonHandler = DC._handlers[jsonKey]
                    if jsonHandler then
                        pcall(jsonHandler, data, jsonStr)
                    else
                        -- Fall back to regular handler with decoded data
                        local key = module .. "_" .. opcode
                        local h = DC._handlers[key]
                        if h then pcall(h, data) end
                    end
                else
                    -- Regular message
                    local key = module .. "_" .. opcode
                    local h = DC._handlers[key]
                    if h then pcall(h, parts[3], parts[4], parts[5], parts[6], parts[7]) end
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
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Registered handlers:")
        for key, _ in pairs(DC._handlers) do
            DEFAULT_CHAT_FRAME:AddMessage("  - " .. key)
        end
    elseif cmd == "panel" or cmd == "settings" or cmd == "config" then
        InterfaceOptionsFrame_OpenToCategory(DC.SettingsPanel)
        InterfaceOptionsFrame_OpenToCategory(DC.SettingsPanel)
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC Protocol]|r Commands:")
        DEFAULT_CHAT_FRAME:AddMessage("  /dc status - Show connection status")
        DEFAULT_CHAT_FRAME:AddMessage("  /dc debug - Toggle debug mode")
        DEFAULT_CHAT_FRAME:AddMessage("  /dc reconnect - Resend handshake")
        DEFAULT_CHAT_FRAME:AddMessage("  /dc handlers - List registered handlers")
        DEFAULT_CHAT_FRAME:AddMessage("  /dc json - Test JSON encode/decode")
        DEFAULT_CHAT_FRAME:AddMessage("  /dc panel - Open settings/debug panel")
    end
end

function DC:CountHandlers()
    local count = 0
    for _ in pairs(self._handlers) do count = count + 1 end
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
DC:RegisterHandler("CORE", 0x10, function(version, features)
    DC._connected = true
    DC._serverVersion = version
    DC:DebugPrint("Handshake ACK received, server v" .. tostring(version))
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC Protocol]|r Connected to server v" .. tostring(version))
    if features then
        for feat in string.gmatch(features, "([^,]+)") do
            DC._features[feat] = true
        end
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

DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC Protocol]|r v" .. DC.VERSION .. " loaded")
