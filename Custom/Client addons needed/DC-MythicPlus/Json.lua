-- DC-MythicPlus Json.lua
--
-- Minimal JSON decoder for the DC addon protocol, split out of Core.lua.
--
-- Core.lua carries ~180 file-scope locals against Lua 5.1's hard limit of 200,
-- and this decoder was nine of them (skipWhitespace, parseLiteral, parseNumber,
-- parseString, parseValue, parseArray, parseObject, DecodeJSON and a JsonDecoder
-- table that nothing ever read). Living here it costs Core.lua a single local.
--
-- Exports: namespace.DecodeJSON(str) -> table|nil  (nil on malformed input)

local namespace = _G.DCMythicPlusHUD or {}
_G.DCMythicPlusHUD = namespace

local function skipWhitespace(str, idx)
    local len = #str
    while idx <= len do
        local byte = str:byte(idx)
        if not byte then
            break
        end
        if byte ~= 32 and byte ~= 9 and byte ~= 10 and byte ~= 13 then
            break
        end
        idx = idx + 1
    end
    return idx
end

local function parseLiteral(str, idx, literal, value)
    if str:sub(idx, idx + #literal - 1) == literal then
        return value, idx + #literal
    end
    error("invalid literal")
end

local function parseNumber(str, idx)
    local startIdx = idx
    local len = #str
    while idx <= len do
        local c = str:sub(idx, idx)
        if not c:match("[0-9%+%-%eE%.]") then
            break
        end
        idx = idx + 1
    end
    local num = tonumber(str:sub(startIdx, idx - 1))
    if not num then
        error("invalid number")
    end
    return num, idx
end

local function parseString(str, idx)
    idx = idx + 1
    local len = #str
    local buffer = {}
    while idx <= len do
        local char = str:sub(idx, idx)
        if char == '"' then
            return table.concat(buffer), idx + 1
        elseif char == '\\' then
            local esc = str:sub(idx + 1, idx + 1)
            if esc == 'u' then
                local hex = str:sub(idx + 2, idx + 5)
                local code = tonumber(hex, 16)
                if not code then
                    error("invalid unicode escape")
                end
                if code <= 0x7F then
                    buffer[#buffer + 1] = string.char(code)
                else
                    buffer[#buffer + 1] = "?"
                end
                idx = idx + 6
            else
                local map = {
                    ["\\"] = "\\",
                    ['"'] = '"',
                    ['/'] = '/',
                    ['b'] = string.char(8),
                    ['f'] = string.char(12),
                    ['n'] = "\n",
                    ['r'] = "\r",
                    ['t'] = "\t",
                }
                buffer[#buffer + 1] = map[esc] or esc
                idx = idx + 2
            end
        else
            buffer[#buffer + 1] = char
            idx = idx + 1
        end
    end
    error("unterminated string")
end

local parseValue

local function parseArray(str, idx)
    idx = idx + 1
    local result = {}
    idx = skipWhitespace(str, idx)
    if str:sub(idx, idx) == ']' then
        return result, idx + 1
    end
    local n = 1
    while true do
        local value
        value, idx = parseValue(str, idx)
        result[n] = value
        n = n + 1
        idx = skipWhitespace(str, idx)
        local char = str:sub(idx, idx)
        if char == ']' then
            return result, idx + 1
        end
        if char ~= ',' then
            error("expected comma in array")
        end
        idx = skipWhitespace(str, idx + 1)
    end
end

local function parseObject(str, idx)
    idx = idx + 1
    local result = {}
    idx = skipWhitespace(str, idx)
    if str:sub(idx, idx) == '}' then
        return result, idx + 1
    end
    while true do
        local key
        if str:sub(idx, idx) ~= '"' then
            error("expected string key")
        end
        key, idx = parseString(str, idx)
        idx = skipWhitespace(str, idx)
        if str:sub(idx, idx) ~= ':' then
            error("expected colon")
        end
        idx = skipWhitespace(str, idx + 1)
        local value
        value, idx = parseValue(str, idx)
        result[key] = value
        idx = skipWhitespace(str, idx)
        local char = str:sub(idx, idx)
        if char == '}' then
            return result, idx + 1
        end
        if char ~= ',' then
            error("expected comma in object")
        end
        idx = skipWhitespace(str, idx + 1)
    end
end

function parseValue(str, idx)
    idx = skipWhitespace(str, idx)
    local char = str:sub(idx, idx)
    if char == '{' then
        return parseObject(str, idx)
    elseif char == '[' then
        return parseArray(str, idx)
    elseif char == '"' then
        return parseString(str, idx)
    elseif char == '-' or char:match("%d") then
        return parseNumber(str, idx)
    elseif char == 't' then
        return parseLiteral(str, idx, "true", true)
    elseif char == 'f' then
        return parseLiteral(str, idx, "false", false)
    elseif char == 'n' then
        return parseLiteral(str, idx, "null", nil)
    end
    error("unexpected character in JSON")
end

local function DecodeJSONLua(input)
    local success, result = pcall(function()
        local value, position = parseValue(input, 1)
        position = skipWhitespace(input, position)
        if position <= #input then
            -- ignore trailing commas/spaces gracefully
        end
        return value
    end)
    if success then
        return result
    end
    return nil
end

-- Prefer the decoder in the WotLK-Extensions DLL.
--
-- The client already ships DecodeJSONNative specifically to avoid the cost of a
-- per-payload pure-Lua parse, and DC-AddonProtocol has used it for a while --
-- but DC-MythicPlus never wired itself up and kept parsing byte by byte in Lua.
-- That mattered: the native HUD bridge hands the snapshot over as a JSON string
-- and Core.lua polls it up to ten times a second for the whole run, so every
-- HUD tick was paying for a Lua parse the DLL could do natively.
--
-- Contract (CustomLua.cpp): DecodeJSONNative(str) -> (value, ok). ok == false
-- means "parse error, trailing garbage, or depth cap exceeded, fall back" --
-- so a false here is not an error, it is the DLL declining the payload.
local function DecodeJSON(input)
    if type(input) ~= "string" then
        return nil
    end

    if type(DecodeJSONNative) == "function" then
        local pcallOk, nativeResult, nativeOk = pcall(DecodeJSONNative, input)
        if pcallOk and nativeOk then
            return nativeResult
        end
        -- fall through to the Lua parser
    end

    return DecodeJSONLua(input)
end

namespace.DecodeJSON = DecodeJSON
-- Exposed so a mismatch can be diagnosed against the native path if needed.
namespace.DecodeJSONLua = DecodeJSONLua
