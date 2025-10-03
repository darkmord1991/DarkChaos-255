-- HLBG_JSON.lua - JSON utilities for Hinterland Battleground

-- Ensure HLBG namespace exists
HLBG = HLBG or {}

-- Check for existing JSON decoder and create one if needed
if type(_G.json_decode) ~= 'function' and type(HLBG.json_decode) ~= 'function' then
    -- Lightweight JSON parser for WoW client (with no external dependencies)
    function HLBG.json_decode(str)
        if type(str) ~= 'string' or str == '' then return nil end
        
        local pos = 1
        local function skipws() 
            local _, newpos = str:find('^%s*', pos)
            if newpos then pos = newpos + 1 end
        end
        
        local function parseError(msg)
            return nil, string.format("json error: %s at position %d in [%.10s...]", msg, pos, str:sub(pos, pos+9))
        end
        
        local function expect(pattern, err)
            local matched = str:match('^' .. pattern, pos)
            if not matched then return parseError(err) end
            pos = pos + #matched
            return matched
        end
        
        local function parseString()
            local s, e = str:find('^"(.-)"', pos)
            if not s then return parseError("unterminated string") end
            local val = str:sub(s+1, e-1)
            pos = e + 1
            
            -- Handle escape sequences
            val = val:gsub('\\(.)', function(c)
                if c == 'n' then return '\n'
                elseif c == 'r' then return '\r'
                elseif c == 't' then return '\t'
                elseif c == 'f' then return '\f'
                elseif c == 'b' then return '\b'
                elseif c == 'u' then 
                    -- Unicode \uXXXX handling (minimal for common cases)
                    local hex = str:match('^\\u(%x%x%x%x)', pos - 2)
                    if hex then
                        local code = tonumber(hex, 16)
                        -- Basic support for common latin-1 and euro symbol
                        if code == 0x20AC then return '€' end  -- Euro sign
                        if code <= 0xFF then return string.char(code) end
                        return '' -- Skip unsupported characters
                    end
                    return ''
                else return c end
            end)
            
            return val
        end
        
        local function parseNumber()
            local num = str:match('^-?%d+%.?%d*[eE]?[+-]?%d*', pos)
            if not num then return parseError("invalid number") end
            pos = pos + #num
            return tonumber(num)
        end
        
        local function parseArray()
            local arr = {}
            skipws()
            if str:sub(pos, pos) == ']' then
                pos = pos + 1
                return arr
            end
            
            while true do
                skipws()
                local val, err = parseValue()
                if err then return nil, err end
                table.insert(arr, val)
                
                skipws()
                local c = str:sub(pos, pos)
                pos = pos + 1
                if c == ']' then break end
                if c ~= ',' then return parseError("expected ',' or ']'") end
            end
            
            return arr
        end
        
        local function parseObject()
            local obj = {}
            skipws()
            if str:sub(pos, pos) == '}' then
                pos = pos + 1
                return obj
            end
            
            while true do
                skipws()
                if str:sub(pos, pos) ~= '"' then return parseError("expected string key") end
                
                local key = parseString()
                if not key then return parseError("invalid key") end
                
                skipws()
                if str:sub(pos, pos) ~= ':' then return parseError("expected ':'") end
                pos = pos + 1
                
                skipws()
                local val, err = parseValue()
                if err then return nil, err end
                obj[key] = val
                
                skipws()
                local c = str:sub(pos, pos)
                pos = pos + 1
                if c == '}' then break end
                if c ~= ',' then return parseError("expected ',' or '}'") end
            end
            
            return obj
        end
        
        -- Forward declaration to resolve recursive dependency
        local parseValue
        
        parseValue = function()
            skipws()
            local c = str:sub(pos, pos)
            
            if c == '"' then return parseString()
            elseif c == '{' then pos = pos + 1; return parseObject()
            elseif c == '[' then pos = pos + 1; return parseArray()
            elseif c == 'n' then
                if str:sub(pos, pos+3) == 'null' then
                    pos = pos + 4
                    return nil
                else
                    return parseError("expected 'null'")
                end
            elseif c == 't' then
                if str:sub(pos, pos+3) == 'true' then
                    pos = pos + 4
                    return true
                else
                    return parseError("expected 'true'")
                end
            elseif c == 'f' then
                if str:sub(pos, pos+4) == 'false' then
                    pos = pos + 5
                    return false
                else
                    return parseError("expected 'false'")
                end
            elseif c == '-' or (c >= '0' and c <= '9') then
                return parseNumber()
            else
                return parseError("unexpected character: " .. c)
            end
        end
        
        skipws()
        local result, err = parseValue()
        if err then return nil, err end
        
        skipws()
        if pos <= #str then
            return nil, "trailing garbage at position " .. pos
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
    HinterlandAffixHUD_JsonTestResults = HinterlandAffixHUD_JsonTestResults or {}
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
    table.insert(HinterlandAffixHUD_JsonTestResults, 1, run)
    -- keep last 20 runs
    while #HinterlandAffixHUD_JsonTestResults > 20 do table.remove(HinterlandAffixHUD_JsonTestResults) end

    DEFAULT_CHAT_FRAME:AddMessage(string.format('HLBG JSON tests finished: %s passed (saved to HinterlandAffixHUD_JsonTestResults)', run.summary))
end

-- Print saved JSON test run(s) to chat. Usage: /hlbgjsontestrun [n]
function HLBG.PrintJsonTestRun(n)
    n = tonumber(n) or 1
    if not HinterlandAffixHUD_JsonTestResults or #HinterlandAffixHUD_JsonTestResults == 0 then
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage("HLBG JSON tests: no saved runs found") end
        return
    end
    if n < 1 then n = 1 end
    if n > #HinterlandAffixHUD_JsonTestResults then n = #HinterlandAffixHUD_JsonTestResults end
    local run = HinterlandAffixHUD_JsonTestResults[n]
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
HLBG.safeRegisterSlash("HLBGJSON", "/hlbgjsontest", HLBG.RunJsonDecodeTests)
HLBG.safeRegisterSlash("HLBGJSONRUN", "/hlbgjsontestrun", HLBG.PrintJsonTestRun)