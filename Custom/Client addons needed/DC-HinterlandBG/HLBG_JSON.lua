-- HLBG_JSON.lua - JSON utilities for Hinterland Battleground
-- Record file load in diagnostics
if _G.HLBG_RecordFileLoad then
    _G.HLBG_RecordFileLoad("HLBG_JSON.lua")
end
-- Ensure HLBG namespace exists
HLBG = HLBG or {}
-- Check for existing JSON decoder and create one if needed
if type(_G.json_decode) ~= 'function' and type(HLBG.json_decode) ~= 'function' then
    -- Simple robust JSON parser for WoW client (recursive-safe)
    function HLBG.json_decode(str)
        if type(str) ~= 'string' or str == '' then return nil end
        local pos = 1
        local len = #str
        local function skipWs()
            while pos <= len do
                local c = str:byte(pos)
                if c == 32 or c == 9 or c == 10 or c == 13 then -- space, tab, newline, carriage return
                    pos = pos + 1
                else
                    break
                end
            end
        end
        local function parseValue() -- Forward declared below
        end
        local function parseString()
            if pos > len or str:byte(pos) ~= 34 then -- not "
                return nil, "Expected string"
            end
            pos = pos + 1 -- skip opening quote
            local start = pos
            while pos <= len do
                local c = str:byte(pos)
                if c == 34 then -- closing quote
                    local result = str:sub(start, pos - 1)
                    pos = pos + 1
                    -- Basic escape handling
                    result = result:gsub('\\(.)', function(escaped)
                        if escaped == 'n' then return '\n'
                        elseif escaped == 't' then return '\t'
                        elseif escaped == 'r' then return '\r'
                        elseif escaped == '\\' then return '\\'
                        elseif escaped == '"' then return '"'
                        else return escaped end
                    end)
                    return result
                elseif c == 92 then -- backslash
                    pos = pos + 2 -- skip escape sequence
                else
                    pos = pos + 1
                end
            end
            return nil, "Unterminated string"
        end
        local function parseNumber()
            local start = pos
            if pos <= len and (str:byte(pos) == 45) then pos = pos + 1 end -- minus sign
            while pos <= len do
                local c = str:byte(pos)
                if c >= 48 and c <= 57 then -- 0-9
                    pos = pos + 1
                elseif c == 46 then -- decimal point
                    pos = pos + 1
                else
                    break
                end
            end
            local numStr = str:sub(start, pos - 1)
            return tonumber(numStr)
        end
        local function parseArray()
            local result = {}
            pos = pos + 1 -- skip [
            skipWs()
            if pos <= len and str:byte(pos) == 93 then -- ]
                pos = pos + 1
                return result
            end
            while true do
                skipWs()
                local value, err = parseValue()
                if err then return nil, err end
                table.insert(result, value)
                skipWs()
                if pos > len then return nil, "Unexpected end in array" end
                local c = str:byte(pos)
                if c == 93 then -- ]
                    pos = pos + 1
                    break
                elseif c == 44 then -- ,
                    pos = pos + 1
                else
                    return nil, "Expected ',' or ']' in array"
                end
            end
            return result
        end
        local function parseObject()
            local result = {}
            pos = pos + 1 -- skip {
            skipWs()
            if pos <= len and str:byte(pos) == 125 then -- }
                pos = pos + 1
                return result
            end
            while true do
                skipWs()
                local key, err = parseString()
                if err then return nil, "Expected string key: " .. err end
                skipWs()
                if pos > len or str:byte(pos) ~= 58 then -- :
                    return nil, "Expected ':' after key"
                end
                pos = pos + 1
                skipWs()
                local value, err2 = parseValue()
                if err2 then return nil, err2 end
                result[key] = value
                skipWs()
                if pos > len then return nil, "Unexpected end in object" end
                local c = str:byte(pos)
                if c == 125 then -- }
                    pos = pos + 1
                    break
                elseif c == 44 then -- ,
                    pos = pos + 1
                else
                    return nil, "Expected ',' or '}' in object"
                end
            end
            return result
        end
        parseValue = function()
            skipWs()
            if pos > len then return nil, "Unexpected end of input" end
            local c = str:byte(pos)
            if c == 34 then -- "
                return parseString()
            elseif c == 123 then -- {
                return parseObject()
            elseif c == 91 then -- [
                return parseArray()
            elseif c == 116 then -- t (true)
                if str:sub(pos, pos + 3) == "true" then
                    pos = pos + 4
                    return true
                end
                return nil, "Invalid literal"
            elseif c == 102 then -- f (false)
                if str:sub(pos, pos + 4) == "false" then
                    pos = pos + 5
                    return false
                end
                return nil, "Invalid literal"
            elseif c == 110 then -- n (null)
                if str:sub(pos, pos + 3) == "null" then
                    pos = pos + 4
                    return nil
                end
                return nil, "Invalid literal"
            elseif c == 45 or (c >= 48 and c <= 57) then -- - or 0-9
                return parseNumber()
            else
                return nil, "Unexpected character: " .. string.char(c)
            end
        end
        local result, err = parseValue()
        if err then return nil, err end
        skipWs()
        if pos <= len then
            return nil, "Extra characters after JSON"
        end
        return result
    end
    -- Use our implementation as the global function too
    _G.json_decode = HLBG.json_decode
end
-- Helper to safely decode JSON with fallbacks
function HLBG.tryDecodeJson(str)
    if type(str) ~= 'string' or str == '' then return nil end
    local success, result = pcall(function()
        if type(json_decode) == 'function' then return json_decode(str) end
        if type(HLBG) == 'table' and type(HLBG.json_decode) == 'function' then return HLBG.json_decode(str) end
        return nil
    end)
    if success then return result end
    return nil
end
-- Test runner for JSON decoder
function HLBG.RunJsonDecodeTests()
    if not DEFAULT_CHAT_FRAME or not DEFAULT_CHAT_FRAME.AddMessage then return end
    -- prepare a few expanded tests: unicode escapes, malformed JSON, and a large array
    local largeN = 200
    local parts = {}
    for i=1,largeN do parts[#parts+1] = tostring(i) end
    local largeArrayStr = "[" .. table.concat(parts, ",") .. "]"
    local tests = {
        { name = 'null', input = 'null', expectError = false, expected = nil },
        { name = 'true', input = 'true', expectError = false, expected = true },
        { name = 'false', input = 'false', expectError = false, expected = false },
        { name = 'number', input = '123', expectError = false, expected = 123 },
        { name = 'string', input = '"hello"', expectError = false, expected = 'hello' },
        { name = 'array_small', input = '[1,2,3]', expectError = false, expected = {1,2,3} },
        { name = 'object', input = '{"a":1,"b":"x"}', expectError = false, expected = { a=1, b='x' } },
        { name = 'nested', input = '{"nested":{"k":true}}', expectError = false, expected = { nested = { k = true } } },
        { name = 'unicode_latin1', input = '"caf\\u00e9"', expectError = false, expected = 'café' },
        { name = 'unicode_euro', input = '"price\\u20ac"', expectError = false, expected = 'price€' },
        { name = 'malformed_trailing_comma', input = '{"a":1,}', expectError = true },
        { name = 'malformed_missing_comma', input = '{"a":1 "b":2}', expectError = true },
        { name = 'malformed_unclosed_string', input = '"unclosed', expectError = true },
        { name = 'large_array', input = largeArrayStr, expectError = false, expectedLen = largeN },
    }
    local function deepEqual(a,b)
        if type(a) ~= type(b) then return false end
        if type(a) ~= 'table' then return a == b end
        local ka = {}; for k,_ in pairs(a) do ka[#ka+1]=k end
        local kb = {}; for k,_ in pairs(b) do kb[#kb+1]=k end
        table.sort(ka); table.sort(kb)
        if #ka ~= #kb then return false end
        for i=1,#ka do if ka[i] ~= kb[i] then return false end end
        for k,_ in pairs(a) do if not deepEqual(a[k], b[k]) then return false end end
        return true
    end
    local function shortRepr(v)
        local t = type(v)
        if t == 'nil' then return 'nil' end
        if t == 'string' then return string.format('"%s"', tostring(v)) end
        if t == 'number' or t == 'boolean' then return tostring(v) end
        if t == 'table' then
            if #v and #v > 0 then return string.format('<array len=%d>', #v) end
            return '<object>'
        end
        return '<'..t..'>'
    end
    -- saved variable container for persisted test results
    DCHLBG_JsonTestResults = DCHLBG_JsonTestResults or {}
    local run = { ts = time(), results = {} }
    local passed = 0
    for i, t in ipairs(tests) do
        local res, err = json_decode(t.input)
        local ok
        if t.expectError then
            ok = (err ~= nil)
        else
            if err ~= nil then ok = false else
                if t.expectedLen then
                    ok = (type(res) == 'table' and #res == t.expectedLen)
                else
                    ok = deepEqual(res, t.expected)
                end
            end
        end
        if ok then passed = passed + 1 end
        local out = shortRepr(res)
        table.insert(run.results, { name = t.name, pass = ok, error = err and tostring(err) or nil, output = out, expected = t.expectedLen and ('len='..t.expectedLen) or (t.expected ~= nil and shortRepr(t.expected) or nil) })
        DEFAULT_CHAT_FRAME:AddMessage(string.format('HLBG JSON Test %d (%s): %s', i, t.name, ok and 'PASS' or ('FAIL'..(err and (': '..tostring(err)) or ''))))
    end
    run.summary = string.format('%d/%d', passed, #tests)
    table.insert(DCHLBG_JsonTestResults, 1, run)
    -- keep last 20 runs
    while #DCHLBG_JsonTestResults > 20 do table.remove(DCHLBG_JsonTestResults) end
    DEFAULT_CHAT_FRAME:AddMessage(string.format('HLBG JSON tests finished: %s passed (saved to DCHLBG_JsonTestResults)', run.summary))
end
-- Print saved JSON test run(s) to chat. Usage: /hlbgjsontestrun [n]
function HLBG.PrintJsonTestRun(n)
    n = tonumber(n) or 1
    if not DCHLBG_JsonTestResults or #DCHLBG_JsonTestResults == 0 then
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage("HLBG JSON tests: no saved runs found") end
        return
    end
    if n < 1 then n = 1 end
    if n > #DCHLBG_JsonTestResults then n = #DCHLBG_JsonTestResults end
    local run = DCHLBG_JsonTestResults[n]
    if not run then
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage("HLBG JSON tests: run not found") end
        return
    end
    local when = (type(date) == 'function' and date("%Y-%m-%d %H:%M:%S", run.ts)) or tostring(run.ts)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("HLBG JSON Test Run #%d - %s (summary: %s)", n, when, run.summary or ""))
        for i, r in ipairs(run.results or {}) do
            local ok = r.pass and "PASS" or "FAIL"
            local info = string.format("%d) %s: %s", i, r.name or "?", ok)
            if r.error then info = info .. " - error: " .. tostring(r.error) end
            if r.output then info = info .. " - output: " .. tostring(r.output) end
            if r.expected then info = info .. " - expected: " .. tostring(r.expected) end
            DEFAULT_CHAT_FRAME:AddMessage(info)
        end
    end
end
-- Register JSON test-related slash commands
    if HLBG.safeRegisterSlash then
    HLBG.safeRegisterSlash("HLBGJSON", "/hlbgjsontest", HLBG.RunJsonDecodeTests)
    HLBG.safeRegisterSlash("HLBGJSONRUN", "/hlbgjsontestrun", HLBG.PrintJsonTestRun)
else
    -- Fallback to standard slash command registration
    SLASH_HLBGJSON1 = "/hlbgjsontest"
    SlashCmdList["HLBGJSON"] = HLBG.RunJsonDecodeTests
    SLASH_HLBGJSONRUN1 = "/hlbgjsontestrun"
    SlashCmdList["HLBGJSONRUN"] = HLBG.PrintJsonTestRun
end

