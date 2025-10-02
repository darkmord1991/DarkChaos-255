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
_G.HLBG = HLBG
