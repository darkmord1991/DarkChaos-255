-- HLBG_AIO.lua
-- Server-side AIO handlers for Hinterland BG UI
-- Requires: Rochet2 AIO server loaded (AIO.lua) and Eluna with CharDBQuery available

local AIO = AIO or require("AIO")
if not AIO.IsMainState() then return end

local Handlers = AIO.AddHandlers("HLBG", {})

local function safeQuery(dbfunc, sql)
    local ok, res = pcall(dbfunc, sql)
    if not ok then return nil end
    return res
end

local function FetchHistoryPage(page, perPage)
    page = tonumber(page) or 1
    perPage = tonumber(perPage) or 25
    if page < 1 then page = 1 end
    local offset = (page - 1) * perPage
    local sql = string.format("SELECT id, ts, winner, margin, reason, affix, weather, duration FROM hlbg_winner_history ORDER BY id DESC LIMIT %d OFFSET %d", perPage, offset)
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
    return rows
end

local function FetchStats()
    local stats = { counts = {}, draws = 0, avgDuration = 0 }
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
    return stats
end

function Handlers.Request(player, what, arg1, arg2)
    if what == "HISTORY" then
        local page = tonumber(arg1) or 1
        local per = tonumber(arg2) or 25
        local rows = FetchHistoryPage(page, per)
        AIO.Handle(player, "HLBG", "History", rows, page, per)
    elseif what == "STATS" then
        local stats = FetchStats()
        AIO.Handle(player, "HLBG", "Stats", stats)
    elseif what == "PING" then
        AIO.Handle(player, "HLBG", "PONG")
    end
end

-- Optional helper so GMs can open the UI via command
local function OnCommand(event, player, command)
    if command == "hlbgui" then
        AIO.Handle(player, "HLBG", "OpenUI")
        return false
    end
end
RegisterPlayerEvent(42, OnCommand)
