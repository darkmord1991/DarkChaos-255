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
local isMain = (okAIO and AIO and AIO.IsMainState and AIO.IsMainState()) and true or false
print(string.format("[HLBG_AIO] AIO available: %s | main state: %s", okAIO and (AIO and "yes" or "no") or "no", isMain and "yes" or "no"))
local Handlers = okAIO and AIO and AIO.AddHandlers and AIO.AddHandlers("HLBG", {}) or {}
if Handlers then
    print("[HLBG_AIO] AddHandlers returned table (size="..tostring(#Handlers or 0)..")")
end

local function safeQuery(dbfunc, sql)
    local ok, res = pcall(dbfunc, sql)
    if not ok then return nil end
    return res
end

local function sanitizeSort(key)
    key = tostring(key or "")
    local map = {
        id = "id",
        ts = "occurred_at",
        winner = "winner_tid",
        reason = "win_reason",
        affix = "affix",
        weather = "affix", -- no weather column; map to affix for stability
        duration = "duration_seconds",
    }
    return map[key] or "id"
end

local function sanitizeDir(dir)
    dir = tostring(dir or "DESC"):upper()
    if dir ~= "ASC" and dir ~= "DESC" then dir = "DESC" end
    return dir
end

local function splitCSV(s)
    local t = {}
    if not s or s == "" then return t end
    for part in tostring(s):gmatch("[^,]+") do
        table.insert(t, (part:gsub("^%s+", ""):gsub("%s+$", "")))
    end
    return t
end

local function buildOrderClause(sortKeys, sortDirs)
    local keys = splitCSV(sortKeys)
    local dirs = splitCSV(sortDirs)
    local parts = {}
    for i,k in ipairs(keys) do
        local col = sanitizeSort(k)
        local dir = sanitizeDir(dirs[i] or dirs[1] or "DESC")
        table.insert(parts, string.format("%s %s", col, dir))
    end
    -- always add id DESC as a final stable tie-breaker if not present
    local hasId = false
    for _,p in ipairs(parts) do if p:match("^id ") then hasId = true break end end
    if not hasId then table.insert(parts, "id DESC") end
    if #parts == 0 then return "id DESC" end
    return table.concat(parts, ", ")
end

local function FetchHistoryPage(page, perPage, sortKey, sortDir)
    page = tonumber(page) or 1
    perPage = tonumber(perPage) or 25
    if page < 1 then page = 1 end
    local offset = (page - 1) * perPage
    local orderBy = buildOrderClause(sortKey, sortDir)
    local sql = string.format("SELECT id, occurred_at, winner_tid, win_reason, affix, duration_seconds, score_alliance, score_horde FROM hlbg_winner_history ORDER BY %s LIMIT %d OFFSET %d", orderBy, perPage, offset)
    local res = safeQuery(CharDBQuery, sql)
    local rows = {}
    if res then
        repeat
            local id = res:GetUInt64(0)
            local ts = res:GetString(1)
            local tid = res:GetUInt32(2)
            local reason = res:IsNull(3) and nil or res:GetString(3)
            local affix = res:GetUInt32(4)
            local duration = res:GetUInt32(5)
            local sa = res:GetUInt32(6)
            local sh = res:GetUInt32(7)
            local winner = (tid == 0 and "Alliance") or (tid == 1 and "Horde") or "DRAW"
            table.insert(rows, {
                id = tostring(id),
                ts = ts,
                winner = winner,
                reason = reason,
                affix = tostring(affix),
                weather = nil,
                duration = duration,
                score_alliance = sa,
                score_horde = sh,
            })
        until not res:NextRow()
    end
    local total = 0
    local cnt = safeQuery(CharDBQuery, "SELECT COUNT(*) FROM hlbg_winner_history")
    if cnt then total = cnt:GetUInt64(0) or cnt:GetUInt32(0) or 0 end
    -- Return the primary col/dir (first pair), for client display
    local firstCol = sanitizeSort(splitCSV(sortKey)[1] or "id")
    local firstDir = sanitizeDir(splitCSV(sortDir)[1] or "DESC")
    return rows, total, firstCol, firstDir
end

local function FetchStats()
    local stats = { counts = {}, draws = 0, avgDuration = 0, byAffix = {}, byWeather = {}, affixDur = {}, weatherDur = {} }
    -- winner_tid: 0 Alliance, 1 Horde, 2 Neutral/Draw
    local res = safeQuery(CharDBQuery, "SELECT winner_tid, COUNT(*) FROM hlbg_winner_history GROUP BY winner_tid")
    if res then
        repeat
            local tid = res:GetUInt32(0)
            local c = res:GetUInt32(1)
            if tid == 0 then stats.counts["Alliance"] = c
            elseif tid == 1 then stats.counts["Horde"] = c
            else stats.draws = c end
        until not res:NextRow()
    end
    local res2 = safeQuery(CharDBQuery, "SELECT AVG(duration_seconds) FROM hlbg_winner_history WHERE duration_seconds IS NOT NULL")
    if res2 then
        stats.avgDuration = res2:IsNull(0) and 0 or res2:GetFloat(0)
    end
    -- By affix splits
    local res3 = safeQuery(CharDBQuery, "SELECT affix, winner_tid, COUNT(*) FROM hlbg_winner_history GROUP BY affix, winner_tid")
    if res3 then
        repeat
            local aff = tostring(res3:GetUInt32(0))
            local tid = res3:GetUInt32(1)
            local c = res3:GetUInt32(2)
            stats.byAffix[aff] = stats.byAffix[aff] or { Alliance = 0, Horde = 0, DRAW = 0 }
            if tid == 0 then stats.byAffix[aff].Alliance = c
            elseif tid == 1 then stats.byAffix[aff].Horde = c
            else stats.byAffix[aff].DRAW = c end
        until not res3:NextRow()
    end
    -- No weather column in schema; leave byWeather empty
    -- Duration aggregates per affix
    local res5 = safeQuery(CharDBQuery, "SELECT affix, COUNT(*), SUM(duration_seconds), AVG(duration_seconds) FROM hlbg_winner_history WHERE duration_seconds IS NOT NULL GROUP BY affix")
    if res5 then
        repeat
            local aff = tostring(res5:GetUInt32(0))
            local c = res5:GetUInt32(1)
            local s = res5:IsNull(2) and 0 or res5:GetUInt64(2)
            local a = res5:IsNull(3) and 0 or res5:GetFloat(3)
            stats.affixDur[aff] = { count = c, sum = s, avg = a }
        until not res5:NextRow()
    end
    -- No weather duration aggregates (column absent)
    return stats
end

function Handlers.Request(player, what, arg1, arg2, arg3, arg4)
    if what == "HISTORY" then
        local page = tonumber(arg1) or 1
        local per = tonumber(arg2) or 25
        local sortKey = arg3 or "id"
        local sortDir = arg4 or "DESC"
        local rows, total, col, dir = FetchHistoryPage(page, per, sortKey, sortDir)
        print(string.format("[HLBG_AIO] HISTORY page=%d per=%d -> rows=%d total=%s sort=%s %s", page, per, (rows and #rows or 0), tostring(total), tostring(col), tostring(dir)))
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
    if command == "hlbgui" or command == ".hlbgui" then
        print("[HLBG_AIO] OnCommand received: "..tostring(command))
        if okAIO and AIO and AIO.Handle then
            print("[HLBG_AIO] Sending OpenUI to client via AIO.Handle")
            AIO.Handle(player, "HLBG", "OpenUI")
        else
            player:SendBroadcastMessage("HLBG: UI command received, but AIO is not available. Open PvP (H) and click the HLBG tab.")
            print("[HLBG_AIO] AIO unavailable for Handle()")
        end
        return false
    end
end
RegisterPlayerEvent(42, OnCommand)
print("[HLBG_AIO] OnCommand hook registered (.hlbgui)")
