-- HLBG_AIO.lua
-- Server-side AIO handlers for Hinterland BG UI
-- Requires: Rochet2 AIO server loaded (AIO.lua) and Eluna with CharDBQuery available

local okAIO, AIO = pcall(function() return AIO or require("AIO") end)
if not okAIO or not AIO then
    local candidates = {
        "AIO.lua",
        "AIO_Server/AIO.lua",
        "RochetAio/AIO-master/AIO_Server/AIO.lua",
        "Custom/RochetAio/AIO-master/AIO_Server/AIO.lua",
        "../AIO.lua",
    }
    for _,p in ipairs(candidates) do
        local ok = pcall(dofile, p)
        if ok and _G.AIO then AIO = _G.AIO break end
    end
end
if not okAIO or not AIO or not AIO.IsMainState or not AIO.IsMainState() then
    -- AIO not available; keep command fallback but skip handlers registration
end
local Handlers = okAIO and AIO and AIO.AddHandlers and AIO.AddHandlers("HLBG", {}) or {}

local function safeQuery(dbfunc, sql)
    local ok, res = pcall(dbfunc, sql)
    if not ok then return nil end
    return res
end

local function sanitizeSort(key)
    key = tostring(key or "")
    local map = {
        id = "id",
        ts = "ts",
        winner = "winner",
        reason = "reason",
        affix = "affix",
        weather = "weather",
        duration = "duration",
    }
    return map[key] or "id"
end

local function sanitizeDir(dir)
    dir = tostring(dir or "DESC"):upper()
    if dir ~= "ASC" and dir ~= "DESC" then dir = "DESC" end
    return dir
end

local function FetchHistoryPage(page, perPage, sortKey, sortDir)
    page = tonumber(page) or 1
    perPage = tonumber(perPage) or 25
    if page < 1 then page = 1 end
    local offset = (page - 1) * perPage
    local col = sanitizeSort(sortKey)
    local dir = sanitizeDir(sortDir)
    local sql = string.format("SELECT id, ts, winner, margin, reason, affix, weather, duration FROM hlbg_winner_history ORDER BY %s %s LIMIT %d OFFSET %d", col, dir, perPage, offset)
    local res = safeQuery(CharDBQuery, sql)
    local rows = {}
    if res then
        repeat
            table.insert(rows, {
                id = res:GetUInt32(0),
                ts = res:GetString(1),
                winner = res:GetString(2),
                margin = res:IsNull(3) and nil or res:GetInt32(3),
                reason = res:IsNull(4) and nil or res:GetString(4),
                affix = res:IsNull(5) and nil or res:GetString(5),
                weather = res:IsNull(6) and nil or res:GetString(6),
                duration = res:IsNull(7) and nil or res:GetUInt32(7),
            })
        until not res:NextRow()
    end
    local total = 0
    local cnt = safeQuery(CharDBQuery, "SELECT COUNT(*) FROM hlbg_winner_history")
    if cnt then total = cnt:GetUInt64(0) or cnt:GetUInt32(0) or 0 end
    return rows, total, col, dir
end

local function FetchStats()
    local stats = { counts = {}, draws = 0, avgDuration = 0, byAffix = {}, byWeather = {} }
    local res = safeQuery(CharDBQuery, "SELECT winner, COUNT(*) FROM hlbg_winner_history GROUP BY winner")
    if res then
        repeat
            local w = res:GetString(0)
            local c = res:GetUInt32(1)
            if w == "DRAW" or w == "Neutral" or w == "NEUTRAL" then
                stats.draws = c
            else
                stats.counts[w] = c
            end
        until not res:NextRow()
    end
    local res2 = safeQuery(CharDBQuery, "SELECT AVG(duration) FROM hlbg_winner_history WHERE duration IS NOT NULL")
    if res2 then
        stats.avgDuration = res2:IsNull(0) and 0 or res2:GetFloat(0)
    end
    -- By affix and by weather splits
    local res3 = safeQuery(CharDBQuery, "SELECT COALESCE(affix,'(none)'), COALESCE(winner,'DRAW'), COUNT(*) FROM hlbg_winner_history GROUP BY affix, winner")
    if res3 then
        repeat
            local aff = res3:GetString(0)
            local win = res3:GetString(1)
            local c = res3:GetUInt32(2)
            stats.byAffix[aff] = stats.byAffix[aff] or { Alliance = 0, Horde = 0, DRAW = 0 }
            if win == "Alliance" or win == "ALLIANCE" then stats.byAffix[aff].Alliance = c
            elseif win == "Horde" or win == "HORDE" then stats.byAffix[aff].Horde = c
            else stats.byAffix[aff].DRAW = c end
        until not res3:NextRow()
    end
    local res4 = safeQuery(CharDBQuery, "SELECT COALESCE(weather,'(none)'), COALESCE(winner,'DRAW'), COUNT(*) FROM hlbg_winner_history GROUP BY weather, winner")
    if res4 then
        repeat
            local wth = res4:GetString(0)
            local win = res4:GetString(1)
            local c = res4:GetUInt32(2)
            stats.byWeather[wth] = stats.byWeather[wth] or { Alliance = 0, Horde = 0, DRAW = 0 }
            if win == "Alliance" or win == "ALLIANCE" then stats.byWeather[wth].Alliance = c
            elseif win == "Horde" or win == "HORDE" then stats.byWeather[wth].Horde = c
            else stats.byWeather[wth].DRAW = c end
        until not res4:NextRow()
    end
    return stats
end

function Handlers.Request(player, what, arg1, arg2, arg3, arg4)
    if what == "HISTORY" then
        local page = tonumber(arg1) or 1
        local per = tonumber(arg2) or 25
        local sortKey = arg3 or "id"
        local sortDir = arg4 or "DESC"
        local rows, total, col, dir = FetchHistoryPage(page, per, sortKey, sortDir)
        if okAIO and AIO and AIO.Handle then
            AIO.Handle(player, "HLBG", "History", rows, page, per, total, col, dir)
        end
    elseif what == "STATS" then
        local stats = FetchStats()
        if okAIO and AIO and AIO.Handle then
            AIO.Handle(player, "HLBG", "Stats", stats)
        end
    elseif what == "PING" then
        if okAIO and AIO and AIO.Handle then
            AIO.Handle(player, "HLBG", "PONG")
        end
    end
end

-- Optional helper so GMs can open the UI via command
local function OnCommand(event, player, command)
    if command == "hlbgui" then
        if okAIO and AIO and AIO.Handle then
            AIO.Handle(player, "HLBG", "OpenUI")
        else
            player:SendBroadcastMessage("HLBG: UI command received, but AIO is not available. Open PvP (H) and click the HLBG tab.")
        end
        return false
    end
end
RegisterPlayerEvent(42, OnCommand)
