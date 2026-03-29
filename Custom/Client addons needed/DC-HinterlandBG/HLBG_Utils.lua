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
-- Queue-facing message templates so all queue text stays consistent.
HLBG.QueueTextTemplates = HLBG.QueueTextTemplates or {
    request_status_dc = "|cFF33FF99HLBG Queue:|r Requesting status via DC protocol...",
    request_status_aio = "|cFF33FF99HLBG Queue:|r Requesting status via AIO...",
    request_status_cmd = "|cFF33FF99HLBG Queue:|r Requesting status via command...",
    join_dc = "|cFF33FF99HLBG Queue:|r Joining via DC protocol...",
    join_aio = "|cFF33FF99HLBG Queue:|r Joining via AIO...",
    leave_dc = "|cFF33FF99HLBG Queue:|r Leaving via DC protocol...",
    leave_aio = "|cFF33FF99HLBG Queue:|r Leaving via AIO...",
    leave_cmd = "|cFF33FF99HLBG Queue:|r Leaving via command...",
    fallback_no_transport = "|cFFFFAA00HLBG Queue:|r No DC protocol or AIO detected. Using command fallback.",
    fallback_join_hint = "|cFFFFAA00HLBG Queue:|r Try |cFFFFFFFF.hlbg queue join|r or talk to Battlemaster NPC 900001.",
    refreshing = "|cFF33FF99HLBG Queue:|r Refreshing queue status...",
    shown_requesting = "|cFF33FF99HLBG Queue:|r Queue tab shown, requesting status...",
    no_response = "|cFFFF5555HLBG Queue:|r No response received. Queue system may not be active on this server.",
    missing_request_function = "|cFFFF0000HLBG Queue Error:|r RequestQueueStatus function not found.",
    unknown_status = "|cFFFFAA00HLBG Queue:|r %s",
    commands_header = "|cFFFFD700HLBG Queue Commands:|r",
    commands_status = "  /hlbgq status (or /hlbgq) - Check queue status",
    commands_join = "  /hlbgq join - Join the queue",
    commands_leave = "  /hlbgq leave - Leave the queue",
    proto_help_queue = "  /hlbgproto queue - Quick queue for HLBG",
    proto_help_leave = "  /hlbgproto leave - Leave HLBG queue",
    proto_joining = "|cFF33FF99HLBG Queue:|r Joining queue...",
    proto_leaving = "|cFF33FF99HLBG Queue:|r Leaving queue..."
}

function HLBG.QueueText(key, ...)
    local templates = HLBG.QueueTextTemplates
    local tpl = templates and templates[key]
    if not tpl then
        return nil
    end
    if select('#', ...) > 0 then
        local ok, formatted = pcall(string.format, tpl, ...)
        if ok then
            return formatted
        end
    end
    return tpl
end

function HLBG.QueueMessage(key, ...)
    local msg = HLBG.QueueText(key, ...)
    if not msg then
        msg = tostring(key or "")
    end
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(msg)
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


