-- DC Addon Protocol v1.2.0
if DCAddonProtocol then return end

DCAddonProtocol = {
    PREFIX = "DC",
    VERSION = "1.2.0",
    _handlers = {},
    _debug = false,
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
    
    -- Simple JSON decoder for flat objects and simple arrays
    -- For WoW 3.3.5a Lua 5.1 compatibility
    local first = string.sub(str, 1, 1)
    
    -- Array
    if first == "[" then
        local arr = {}
        local inner = string.sub(str, 2, -2)
        for val in string.gmatch(inner, "[^,]+") do
            val = string.gsub(val, "^%s+", "")
            val = string.gsub(val, "%s+$", "")
            if val == "true" then
                table.insert(arr, true)
            elseif val == "false" then
                table.insert(arr, false)
            elseif val == "null" then
                table.insert(arr, nil)
            elseif string.sub(val, 1, 1) == "\"" then
                table.insert(arr, string.sub(val, 2, -2))
            elseif tonumber(val) then
                table.insert(arr, tonumber(val))
            end
        end
        return arr
    end
    
    -- Object
    if first == "{" then
        local obj = {}
        local inner = string.sub(str, 2, -2)
        for k, v in string.gmatch(inner, '"([^"]+)"%s*:%s*([^,}]+)') do
            v = string.gsub(v, "^%s+", "")
            v = string.gsub(v, "%s+$", "")
            if v == "true" then
                obj[k] = true
            elseif v == "false" then
                obj[k] = false
            elseif v == "null" then
                obj[k] = nil
            elseif string.sub(v, 1, 1) == "\"" then
                obj[k] = string.sub(v, 2, -2)
            elseif tonumber(v) then
                obj[k] = tonumber(v)
            else
                obj[k] = v
            end
        end
        return obj
    end
    
    return nil
end

DC.JSON = { encode = function(v) return DC:EncodeJSON(v) end, decode = function(s) return DC:DecodeJSON(s) end }

DC.Module = { CORE = "CORE", AOE_LOOT = "AOE", SPECTATOR = "SPEC", UPGRADE = "UPG", HINTERLAND = "HLBG", DUELS = "DUEL", MYTHIC_PLUS = "MPLUS", PRESTIGE = "PRES", SEASONAL = "SEAS" }
DC.Opcode = {
    Core = { CMSG_HANDSHAKE = 1, SMSG_HANDSHAKE_ACK = 16, SMSG_FEATURE_LIST = 18 },
    AOE = { CMSG_TOGGLE_ENABLED = 1, CMSG_SET_QUALITY = 2, CMSG_GET_STATS = 3, CMSG_GET_SETTINGS = 6, SMSG_STATS = 16, SMSG_SETTINGS_SYNC = 17 },
    Spec = { CMSG_REQUEST_SPECTATE = 1, CMSG_LIST_RUNS = 3, SMSG_RUN_LIST = 18 },
    Upgrade = { CMSG_GET_ITEM_INFO = 1, CMSG_DO_UPGRADE = 2, SMSG_ITEM_INFO = 16, SMSG_UPGRADE_RESULT = 17 },
    MPlus = { CMSG_GET_KEY_INFO = 1, SMSG_KEY_INFO = 16 },
    Season = { CMSG_GET_CURRENT = 1, SMSG_CURRENT = 16 },
}

DC.AOE = {
    Toggle = function(e) DC:Send("AOE", 1, e) end,
    SetQuality = function(q) DC:Send("AOE", 2, q) end,
    GetStats = function() DC:Send("AOE", 3) end,
    GetSettings = function() DC:Send("AOE", 6) end,
}
DC.Spectator = { ListRuns = function() DC:Send("SPEC", 3) end }
DC.MythicPlus = { GetKeyInfo = function() DC:Send("MPLUS", 1) end }
DC.Season = { GetCurrent = function() DC:Send("SEAS", 1) end }

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
    if msg == "json" then
        local t = {name = "Test", level = 80}
        DEFAULT_CHAT_FRAME:AddMessage("[DC] Encode: " .. DC:EncodeJSON(t))
        local decoded = DC:DecodeJSON('{"name":"Player","level":80}')
        if decoded then
            DEFAULT_CHAT_FRAME:AddMessage("[DC] Decode: name=" .. tostring(decoded.name))
        end
    elseif msg == "sendjson" then
        DC:SendJSON("CORE", 99, {action = "test"})
        DEFAULT_CHAT_FRAME:AddMessage("[DC] Sent JSON test")
    elseif msg == "status" then
        DEFAULT_CHAT_FRAME:AddMessage("[DC] v" .. DC.VERSION .. " loaded")
    else
        DEFAULT_CHAT_FRAME:AddMessage("[DC] /dc json | /dc sendjson | /dc status")
    end
end

function DC:CountHandlers()
    local count = 0
    for _ in pairs(self._handlers) do count = count + 1 end
    return count
end

DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC Protocol]|r v" .. DC.VERSION .. " loaded")
