-- HLBG_Utils.lua
-- Small utility functions extracted from the main client file.
local HLBG = _G.HLBG or {}; _G.HLBG = HLBG
_G.HLBG = HLBG
-- Affix code -> friendly name mapping
HLBG.AFFIX_NAMES = HLBG.AFFIX_NAMES or {}
-- GetAffixName function moved to HLBG_Affixes.lua
-- SecondsToClock
if type(HLBG.SecondsToClock) ~= 'function' then
    function HLBG.SecondsToClock(seconds)
        seconds = tonumber(seconds) or 0
        if seconds <= 0 then return "0:00" end
        local m = math.floor(seconds / 60)
        local s = seconds % 60
        return string.format("%d:%02d", m, s)
    end
end
-- Minimal JSON decoder placeholder (the main file still contains a full decoder)
if type(HLBG.json_decode) ~= 'function' then
    -- Tiny JSON decoder covering objects, arrays, strings, numbers, true/false/null
    local function skipws(s,i)
        local _,j = s:find("^%s*", i); return (j or i-1)+1
    end
    local function parseString(s,i)
        i = i + 1; local out = {}
        while i <= #s do
            local c = s:sub(i,i)
            if c == '"' then return table.concat(out), i+1 end
            if c == '\\' then
                local n = s:sub(i+1,i+1)
                local map = { ['"']='"', ['\\']='\\', ['/']='/', b='\b', f='\f', n='\n', r='\r', t='\t' }
                if map[n] then out[#out+1] = map[n]; i = i + 2
                elseif n == 'u' then
                    local hex = s:sub(i+2,i+5)
                    local cp = tonumber(hex,16) or 32
                    if cp < 0x80 then out[#out+1] = string.char(cp)
                    elseif cp < 0x800 then out[#out+1] = string.char(0xC0+math.floor(cp/0x40), 0x80+(cp%0x40))
                    else out[#out+1] = string.char(0xE0+math.floor(cp/0x1000), 0x80+math.floor((cp%0x1000)/0x40), 0x80+(cp%0x40)) end
                    i = i + 6
                else
                    return nil, i
                end
            else out[#out+1] = c; i = i + 1 end
        end
        return nil, i
    end
    local function parseNumber(s,i)
        local j = i
        while j <= #s and s:sub(j,j):match('[%d%+%-%eE%.]') do j=j+1 end
        local n = tonumber(s:sub(i,j-1))
        if n == nil then return nil, i end
        return n, j
    end
    local parseValue
    local function parseArray(s,i)
        i = i + 1; local arr = {}; i = skipws(s,i)
        if s:sub(i,i) == ']' then return arr, i+1 end
        while true do
            local v; v, i = parseValue(s, i); if v == nil then return nil, i end
            arr[#arr+1] = v; i = skipws(s,i)
            local ch = s:sub(i,i)
            if ch == ']' then return arr, i+1 end
            if ch ~= ',' then return nil, i end
            i = skipws(s, i+1)
        end
    end
    local function parseObject(s,i)
        i = i + 1; local obj = {}; i = skipws(s,i)
        if s:sub(i,i) == '}' then return obj, i+1 end
        while true do
            if s:sub(i,i) ~= '"' then return nil, i end
            local k; k, i = parseString(s,i); if k == nil then return nil, i end
            i = skipws(s,i); if s:sub(i,i) ~= ':' then return nil, i end
            i = skipws(s, i+1)
            local v; v, i = parseValue(s,i); if v == nil then return nil, i end
            obj[k] = v; i = skipws(s,i)
            local ch = s:sub(i,i)
            if ch == '}' then return obj, i+1 end
            if ch ~= ',' then return nil, i end
            i = skipws(s, i+1)
        end
    end
    parseValue = function(s,i)
        i = skipws(s,i)
        local c = s:sub(i,i)
        if c == '"' then return parseString(s,i)
        elseif c == '{' then return parseObject(s,i)
        elseif c == '[' then return parseArray(s,i)
        elseif c == '-' or c:match('%d') then return parseNumber(s,i)
        elseif s:sub(i,i+3) == 'true' then return true, i+4
        elseif s:sub(i,i+4) == 'false' then return false, i+5
        elseif s:sub(i,i+3) == 'null' then return nil, i+4
        end
        return nil, i
    end
    HLBG.json_decode = function(text)
        if type(text) ~= 'string' then return nil, 'input not string' end
        local v, idx = parseValue(text, 1)
        if v == nil then return nil, 'parse error at '..tostring(idx) end
        return v, nil
    end
end
-- expose
-- Compatibility helper: safely call SetJustifyH on objects that provide it.
-- Some older clients (WotLK 3.3.5a) or certain widget types may not expose SetJustifyH,
-- calling it directly can error. Use this helper everywhere instead.
function HLBG.safeSetJustify(obj, mode)
    if not obj then return end
    local f = obj.SetJustifyH
    if type(f) == 'function' then
        -- pcall to prevent any unexpected errors from bubbling up
        pcall(f, obj, mode)
    end
end
-- Safe instance checker: returns inInstance(bool), instanceType(string or nil)
function HLBG.safeIsInInstance()
    local inInstance = false
    local instanceType = nil
    pcall(function() inInstance = (type(IsInInstance) == 'function') and IsInInstance() or false end)
    local ok, it = pcall(function() return (type(GetInstanceType) == 'function') and GetInstanceType() or nil end)
    if ok then instanceType = it end
    return inInstance, instanceType
end
-- Safe wrapper for GetRealZoneText: returns empty string when unavailable
function HLBG.safeGetRealZoneText()
    local ok, res = pcall(function() return (type(GetRealZoneText) == 'function') and GetRealZoneText() or nil end)
    if not ok or not res then return "" end
    return tostring(res)
end
-- Safe wrappers for WorldState APIs
function HLBG.safeGetNumWorldStateUI()
    local ok, n = pcall(function() return (type(GetNumWorldStateUI) == 'function') and GetNumWorldStateUI() or 0 end)
    if not ok or not n then return 0 end
    return tonumber(n) or 0
end
function HLBG.safeGetWorldStateUIInfo(i)
    if type(i) ~= 'number' then return nil end
    local ok, a, b, c, d, e, f = pcall(function() return (type(GetWorldStateUIInfo) == 'function') and GetWorldStateUIInfo(i) or nil end)
    if not ok or not a then return nil end
    return a, b, c, d, e, f
end
-- Safe player map position
function HLBG.safeGetPlayerMapPosition(unit)
    if type(GetPlayerMapPosition) ~= 'function' then return nil, nil end
    local ok, x, y = pcall(function() return GetPlayerMapPosition(unit) end)
    if not ok then return nil, nil end
    return x, y
end
-- GetAuthoritativeStatus: prefer Wintergrasp-style worldstate values when available.
-- Returns a table: { allianceResources=number, hordeResources=number, timeLeft=number, alliancePlayers=number, hordePlayers=number, affixId=number, affixName=string }
function HLBG.GetAuthoritativeStatus()
    local status = {}
    -- Check for worldstate entries first
    local n = HLBG.safeGetNumWorldStateUI()
    if n and n > 0 then
        for i=1,n do
            local txt, val, a, b, c, id = HLBG.safeGetWorldStateUIInfo(i)
            if id and val then
                -- Known mapping used by server: 0xDD0001..0xDD0008
                if id == 0xDD0001 then status.allianceResources = tonumber(val) or status.allianceResources end
                if id == 0xDD0002 then status.hordeResources = tonumber(val) or status.hordeResources end
                if id == 0xDD0003 then status.timeLeft = tonumber(val) or status.timeLeft end
                if id == 0xDD0007 then status.affixId = tonumber(val) or status.affixId end
                if id == 0xDD0008 then status.affixEpoch = tonumber(val) or status.affixEpoch end
            else
                -- Fallback: scan textual entries for Affix line
                if type(txt) == 'string' then
                    local name = txt:match('[Aa]ffix[:%s]+([%a%s]+)')
                    if name and name ~= '' then status.affixName = name end
                end
            end
        end
    end
    -- If we got nothing, return nil
    if not next(status) then return nil end
    return status
end
-- Ensure UI helper: returns true when the main UI is built and, if a panel name is
-- provided, that specific sub-panel exists (e.g., 'History', 'Stats', 'Live').
-- This avoids calling into UI-dependent render paths before HLBG_UI.lua has run.
if type(HLBG._ensureUI) ~= 'function' then
    function HLBG._ensureUI(name)
        if not (type(HLBG) == 'table' and type(HLBG.UI) == 'table') then return false end
        if not name then return true end
        return HLBG.UI[name] ~= nil
    end
end
-- Centralized debug flag helper
function HLBG.IsDebugEnabled()
    if HLBG._debugOverride ~= nil then
        return HLBG._debugOverride and true or false
    end
    if HLBG._devMode then return true end
    if type(DCHLBGDB) == 'table' then
        if DCHLBGDB.debugLogging then return true end
        if DCHLBGDB.devMode then return true end
    end
    if HLBG.debugLogging or HLBG.devMode then return true end
    return false
end
-- Centralized debug logging with deduplication
function HLBG.Debug(...)
    local enabled = HLBG.IsDebugEnabled and HLBG.IsDebugEnabled()
    if _G.DC_DebugUtils and type(_G.DC_DebugUtils.PrintMulti) == 'function' then
        _G.DC_DebugUtils:PrintMulti("HLBG", enabled, ...)
        return
    end
    if not enabled then return end
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        local msg = ""
        for i = 1, select('#', ...) do
            if i > 1 then msg = msg .. " " end
            msg = msg .. tostring(select(i, ...))
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99HLBG:|r " .. msg)
    end
end

_G.HLBG = HLBG


