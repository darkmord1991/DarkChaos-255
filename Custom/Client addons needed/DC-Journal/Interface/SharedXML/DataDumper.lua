--[[ DataDumper.lua
Copyright (c) 2007 Olivetti-Engineering SA

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
]]

local dumplua_closure = [[local a={}local function b(c)a[#a+1]=c;c[1]=assert(loadstring(c[1]))return c[1]end;for d,c in pairs(a)do for e=2,#c do debug.setupvalue(c[1],e-1,c[e])end end]]

local lua_reserved_keywords = {
    'and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for',
    'function', 'if', 'in', 'local', 'nil', 'not', 'or', 'repeat',
    'return', 'then', 'true', 'until', 'while' }

local function keys(t)
    local res = {}
    local oktypes = { stringstring = true, numbernumber = true }
    local function cmpfct(a,b)
        if oktypes[type(a)..type(b)] then
            return a < b
        else
            return type(a) < type(b)
        end
    end
    for k in pairs(t) do
        res[#res+1] = k
    end
    table.sort(res, cmpfct)
    return res
end

local c_functions = {}
for _,lib in pairs{'_G', 'string', 'table', 'math',
                   'io', 'os', 'coroutine', 'package', 'debug'} do
    local t = _G[lib] or {}
    lib = lib .. "."
    if lib == "_G." then lib = "" end
    for k,v in pairs(t) do
        if type(v) == 'function' and not pcall(string.dump, v) then
            c_functions[v] = lib..k
        end
    end
end

function DataDumper(value, varname, fastmode, ident)
    local defined, dumplua = {}
    -- Local variables for speed optimization
    local string_format, type, string_dump, string_rep =
    string.format, type, string.dump, string.rep
    local tostring, pairs, table_concat =
    tostring, pairs, table.concat
    local keycache, strvalcache, out, closure_cnt = {}, {}, {}, 0
    setmetatable(strvalcache, {__index = function(t,value)
        local res = string_format('%q', value)
        t[value] = res
        return res
    end})
    local fcts = {
        string = function(value) return strvalcache[value] end,
        number = function(value) if value == math.huge then return "math.huge" else return value end end,
        boolean = function(value) return tostring(value) end,
        ['nil'] = function(value) return 'nil' end
    }
    local function test_defined(value, path)
        if defined[value] then
            if path:match("^getmetatable.*%)$") then
                out[#out+1] = string_format("s%s, %s) ", path:sub(2,-2), defined[value])
            else
                out[#out+1] = path .. " = " .. defined[value] .. " "
            end
            return true
        end
        defined[value] = path
    end
    local function make_key(t, key)
        local s
        if type(key) == 'string' and key:match('^[_%a][_%w]*$') then
            s = key .. "="
        else
            s = "[" .. dumplua(key, 0) .. "]="
        end
        t[key] = s
        return s
    end
    for _,k in ipairs(lua_reserved_keywords) do
        keycache[k] = '["'..k..'"] = '
    end
    if fastmode then
        fcts.table = function (value)
            -- Table value
            local numidx = 1
            out[#out+1] = "{"
            for key,val in pairs(value) do
                if key == numidx then
                    numidx = numidx + 1
                else
                    out[#out+1] = keycache[key]
                end
                local str = dumplua(val)
                out[#out+1] = str..","
            end
            if string.sub(out[#out], -1) == "," then
                out[#out] = string.sub(out[#out], 1, -2);
            end
            out[#out+1] = "}"
            return ""
        end
    else
        fcts.table = function (value, ident, path)
            if test_defined(value, path) then return "nil" end
            -- Table value
            local sep, str, numidx, totallen = " ", {}, 1, 0
            local meta, metastr = (debug or getfenv()).getmetatable(value)
            if meta then
                ident = ident + 1
                metastr = dumplua(meta, ident, "getmetatable("..path..")")
                totallen = totallen + #metastr + 16
            end
            for _,key in pairs(keys(value)) do
                local val = value[key]
                local s = ""
                local subpath = path or ""
                if key == numidx then
                    subpath = subpath .. "[" .. numidx .. "]"
                    numidx = numidx + 1
                else
                    s = keycache[key]
                    if not s:match "^%[" then subpath = subpath .. "." end
                    subpath = subpath .. s:gsub("%s*=%s*$","")
                end
                local value = dumplua(val, ident+1, subpath)
                if value then
                    s = s .. value
                    str[#str+1] = s
                    totallen = totallen + #s + 2
                end
            end
            str = "{"..sep..table_concat(str, ","..sep).." "..sep:sub(1,-3).."}"
            if meta and false then -- Disable metatable processing for now
                sep = sep:sub(1,-3)
                return "setmetatable("..sep..str..","..sep..metastr..sep:sub(1,-3)..")"
            end
            return str
        end
    end
    function dumplua(value, ident, path)
        if fcts[type(value)] then
            return fcts[type(value)](value, ident, path)
        else
            return nil
        end
    end
    if varname == nil then
        varname = "return "
    elseif varname:match("^[%a_][%w_]*$") then
        varname = varname .. " = "
    end
    if fastmode then
        local value = dumplua(value, 0)
        if value then
            setmetatable(keycache, {__index = make_key })
            out[1] = varname
            table.insert(out, value)
            return table.concat(out)
        end
    else
        setmetatable(keycache, {__index = make_key })
        local items = {}
        for i=1,10 do items[i] = '' end
        items[3] = dumplua(value, ident or 0, "t")
        if closure_cnt > 0 then
            items[1], items[6] = dumplua_closure:match("(.*\n)\n(.*)")
            out[#out+1] = ""
        end
        if #out > 0 then
            items[2], items[4] = "local t = ", "\n"
            items[5] = table.concat(out)
            items[7] = varname .. "t"
        else
            items[2] = varname
        end
        return table.concat(items)
    end
end