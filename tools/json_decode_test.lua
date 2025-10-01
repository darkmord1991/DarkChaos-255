-- json_decode_test.lua
-- Offline test harness for HLBG client json_decode implementation
-- Copy the json_decode function from the addon and run these tests with a Lua interpreter.

local json_decode = function(s)
    if type(s) ~= "string" then return nil, "not a string" end
    local i = 1
    local n = #s
    local function peek() return s:sub(i,i) end
    local function nextch() i = i + 1; return s:sub(i-1,i-1) end
    local function skipws()
        while i <= n and s:sub(i,i):match("%s") do i = i + 1 end
    end

    local function parseValue()
        skipws()
        local c = peek()
        if c == '{' then return parseObject()
        elseif c == '[' then return parseArray()
        elseif c == '"' then return parseString()
        elseif c == '-' or c:match('%d') then return parseNumber()
        elseif s:sub(i,i+3) == 'true' then i = i + 4; return true
        elseif s:sub(i,i+4) == 'false' then i = i + 5; return false
        elseif s:sub(i,i+3) == 'null' then i = i + 4; return nil
        else error("Invalid JSON value at position "..i)
        end
    end

    function parseString()
        local out = {}
        assert(nextch() == '"')
        while i <= n do
            local ch = nextch()
            if ch == '"' then break end
            if ch == '\\' then
                local esc = nextch()
                if esc == '"' then table.insert(out, '"')
                elseif esc == '\\' then table.insert(out, '\\')
                elseif esc == '/' then table.insert(out, '/')
                elseif esc == 'b' then table.insert(out, '\b')
                elseif esc == 'f' then table.insert(out, '\f')
                elseif esc == 'n' then table.insert(out, '\n')
                elseif esc == 'r' then table.insert(out, '\r')
                elseif esc == 't' then table.insert(out, '\t')
                elseif esc == 'u' then
                    local hex = s:sub(i, i+3)
                    if not hex or #hex < 4 then error('Invalid unicode escape') end
                    i = i + 4
                    local code = tonumber(hex, 16) or 63
                    if code <= 0x7f then table.insert(out, string.char(code))
                    elseif code <= 0x7ff then
                        table.insert(out, string.char(0xc0 + math.floor(code/0x40)))
                        table.insert(out, string.char(0x80 + (code % 0x40)))
                    else
                        table.insert(out, string.char(0xe0 + math.floor(code/0x1000)))
                        table.insert(out, string.char(0x80 + (math.floor(code/0x40) % 0x40)))
                        table.insert(out, string.char(0x80 + (code % 0x40)))
                    end
                else
                    table.insert(out, esc)
                end
            else
                table.insert(out, ch)
            end
        end
        return table.concat(out)
    end

    function parseNumber()
        local start = i
        if peek() == '-' then i = i + 1 end
        while i <= n and s:sub(i,i):match('%d') do i = i + 1 end
        if s:sub(i,i) == '.' then i = i + 1; while i <= n and s:sub(i,i):match('%d') do i = i + 1 end end
        if s:sub(i,i):lower() == 'e' then i = i + 1; if s:sub(i,i) == '+' or s:sub(i,i) == '-' then i = i + 1 end; while i <= n and s:sub(i,i):match('%d') do i = i + 1 end end
        local num = tonumber(s:sub(start, i-1))
        return num
    end

    function parseArray()
        assert(nextch() == '[')
        local res = {}
        skipws()
        if peek() == ']' then nextch(); return res end
        while true do
            local v = parseValue()
            table.insert(res, v)
            skipws()
            local ch = nextch()
            if ch == ']' then break end
            if ch ~= ',' then error('Expected , or ] in array at '..i) end
        end
        return res
    end

    function parseObject()
        assert(nextch() == '{')
        local res = {}
        skipws()
        if peek() == '}' then nextch(); return res end
        while true do
            skipws()
            local key = parseString()
            skipws()
            assert(nextch() == ':')
            local val = parseValue()
            res[key] = val
            skipws()
            local ch = nextch()
            if ch == '}' then break end
            if ch ~= ',' then error('Expected , or } in object at '..i) end
        end
        return res
    end

    skipws()
    local ok, res = pcall(function() return parseValue() end)
    if not ok then return nil, res end
    return res
end

local tests = {
    { in = 'null', out = nil },
    { in = 'true', out = true },
    { in = 'false', out = false },
    { in = '123', out = 123 },
    { in = '"hello"', out = 'hello' },
    { in = '[1,2,3]', out = {1,2,3} },
    { in = '{"a":1,"b":"x"}', out = { a=1, b='x' } },
    { in = '{"nested":{"k":true}}', out = { nested = { k = true } } },
}

local function deepEqual(a,b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= 'table' then return a == b end
    local ka = {}; for k,_ in pairs(a) do ka[#ka+1]=k end
    local kb = {}; for k,_ in pairs(b) do kb[#kb+1]=k end
    table.sort(ka); table.sort(kb)
    for i=1,#ka do if ka[i] ~= kb[i] then return false end end
    for k,_ in pairs(a) do if not deepEqual(a[k], b[k]) then return false end end
    return true
end

for i,t in ipairs(tests) do
    local ok, res = pcall(function() return json_decode(t.in) end)
    if not ok then
        print(string.format('Test %d: ERROR %s', i, tostring(res)))
    else
        local pass = deepEqual(res, t.out)
        print(string.format('Test %d: %s', i, pass and 'PASS' or 'FAIL'))
    end
end

print('json_decode_test finished')
