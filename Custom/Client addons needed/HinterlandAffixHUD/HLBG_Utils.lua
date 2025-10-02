-- HLBG_Utils.lua
-- Small utility functions extracted from the main client file.
local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

-- Affix code -> friendly name mapping
HLBG.AFFIX_NAMES = HLBG.AFFIX_NAMES or {}

function HLBG.GetAffixName(code)
    if code == nil then return "-" end
    local s = tostring(code)
    local name = HLBG.AFFIX_NAMES[s]
    return name or s
end

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
    HLBG.json_decode = function(_) return nil, "json decoder not loaded" end
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

_G.HLBG = HLBG
