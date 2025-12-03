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

-- Configuration: periodic LIVE broadcast and chat fallback settings
local HLBG_Config = HLBG_Config or {}
HLBG_Config.live_broadcast = HLBG_Config.live_broadcast or {
    enabled = false,        -- set to true to enable periodic broadcasts
    interval = 30,          -- seconds between broadcasts
    scope = "zone",       -- "zone" or "world"
    zoneId = 47,            -- zone id for The Hinterlands (override if needed)
    max_chat_len = 1000,    -- max characters for JSON chat fallback (safe cap)
}

-- Server-side client log file path (absolute path on your host/container)
-- Default to requested location under azeroth-server logs directory.
HLBG_Config.server_log_path = HLBG_Config.server_log_path or "/home/wowcore/azeroth-server/logs/hlbg_client.log"

-- Minimal JSON encoder for simple arrays/tables containing strings/numbers
local function json_encode_value(v)
    local t = type(v)
    if t == "string" then
        -- escape quotes and backslashes
        local s = v:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n','\\n'):gsub('\r','\\r')
        return '"' .. s .. '"'
    elseif t == "number" or t == "boolean" then
        return tostring(v)
    elseif t == "table" then
        -- detect array-like
        local n = 0; for k,_ in pairs(v) do if type(k) == "number" then n = n + 1 end end
        if n > 0 then
            local parts = {}
            for i=1,#v do table.insert(parts, json_encode_value(v[i])) end
            return '[' .. table.concat(parts, ',') .. ']'
        else
            local parts = {}
            for k,val in pairs(v) do
                table.insert(parts, json_encode_value(tostring(k)) .. ':' .. json_encode_value(val))
            end
            return '{' .. table.concat(parts, ',') .. '}'
        end
    else
        return 'null'
    end
end

local function json_encode(obj)
    return json_encode_value(obj)
end
-- Ensure chat fallback strings are valid UTF-8 and safe for single-line broadcast
local function sanitize_for_chat(s)
    if type(s) ~= 'string' then return tostring(s or '') end
    -- normalize CRLF -> LF, collapse newlines to a visible marker (we prefer to keep newlines replaced later)
    s = s:gsub('\r\n','\n'):gsub('\r','\n')
    -- Replace control chars except LF/TAB with space
    s = s:gsub('[%z\1-\31]', function(c) if c=='\n' or c=='\t' then return c else return ' ' end end)
    -- Validate UTF-8: attempt to keep valid sequences, replace invalid bytes with '?'
    local out = {}
    local i = 1; local n = #s
    while i <= n do
        local b = string.byte(s, i)
        if not b then break end
        if b < 0x80 then
            table.insert(out, string.char(b)); i = i + 1
        elseif b >= 0xC2 and b <= 0xDF and i+1 <= n then
            local b2 = string.byte(s, i+1)
            if b2 and b2 >= 0x80 and b2 <= 0xBF then table.insert(out, s:sub(i,i+1)); i = i + 2 else table.insert(out, '?'); i = i + 1 end
        elseif b >= 0xE0 and b <= 0xEF and i+2 <= n then
            local b2,b3 = string.byte(s, i+1, i+2)
            if b2 and b3 and b2>=0x80 and b2<=0xBF and b3>=0x80 and b3<=0xBF then table.insert(out, s:sub(i,i+2)); i = i + 3 else table.insert(out, '?'); i = i + 1 end
        elseif b >= 0xF0 and b <= 0xF4 and i+3 <= n then
            local b2,b3,b4 = string.byte(s, i+1, i+3)
            if b2 and b3 and b4 and b2>=0x80 and b2<=0xBF and b3>=0x80 and b3<=0xBF and b4>=0x80 and b4<=0xBF then table.insert(out, s:sub(i,i+3)); i = i + 4 else table.insert(out, '?'); i = i + 1 end
        else
            table.insert(out, '?'); i = i + 1
        end
    end
    return table.concat(out)
end

local function safeQuery(dbfunc, sql)
    local ok, res = pcall(dbfunc, sql)
    if not ok then return nil end
    return res
end

-- Coerce Eluna DB api return values (which can be userdata for UInt64) into Lua numbers
local function asNumber(v)
    if type(v) == "userdata" then
        local s = tostring(v)
        local n = tonumber(s)
        if n then return n end
        return 0
    end
    return tonumber(v) or 0
end

-- Small cache for information_schema lookups so we don't spam queries
local __hlbg_col_cache = {}
local function hasColumn(tableName, columnName)
    if not tableName or not columnName then return false end
    local key = tostring(tableName).."|"..tostring(columnName)
    if __hlbg_col_cache[key] ~= nil then return __hlbg_col_cache[key] end
    local q = string.format("SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME='%s' AND COLUMN_NAME='%s'", tostring(tableName):gsub("'","''"), tostring(columnName):gsub("'","''"))
    local r = safeQuery(CharDBQuery, q)
    local ok = false
    if r then
        local raw = (r.GetUInt64 and r:GetUInt64(0)) or (r.GetUInt32 and r:GetUInt32(0)) or 0
        local n = asNumber(raw)
        ok = (n > 0)
    end
    __hlbg_col_cache[key] = ok
    return ok
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
        season = "season",
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

-- Build WHERE clause parts for HISTORY filters
-- Resolve affix name to id using CharDB table dc_hlbg_affixes, preferring a specific season when provided
local function resolveAffixToken(token, seasonId)
    if not token or token == '' then return nil end
    if tonumber(token) then return math.floor(tonumber(token)) end
    local name = tostring(token)
    local sql
    if seasonId and hasColumn('dc_hlbg_affixes','season_id') then
        sql = string.format("SELECT id FROM dc_hlbg_affixes WHERE name = '%s' AND season_id = %d LIMIT 1", name:gsub("'","''"), tonumber(seasonId) or 0)
    else
        if hasColumn('dc_hlbg_affixes','season_id') then
            sql = string.format("SELECT id FROM dc_hlbg_affixes WHERE name = '%s' ORDER BY season_id IS NULL ASC LIMIT 1", name:gsub("'","''"))
        else
            sql = string.format("SELECT id FROM dc_hlbg_affixes WHERE name = '%s' LIMIT 1", name:gsub("'","''"))
        end
    end
    local res = safeQuery(CharDBQuery, sql)
    if res then
        local id = res:GetUInt32(0)
        if id and id > 0 then return id end
    end
    return nil
end

local function buildHistoryWhereClause(winnerFilter, affixFilter, seasonId)
    local where = {}
    -- winnerFilter can be a comma-separated list of 'Alliance','Horde','DRAW' or 0/1/2
    if winnerFilter and tostring(winnerFilter) ~= "" and tostring(winnerFilter):lower() ~= "all" then
        local tids = {}
        for _,w in ipairs(splitCSV(winnerFilter)) do
            w = tostring(w):lower()
            if w == "alliance" or w == "a" or w == "0" then table.insert(tids, 0)
            elseif w == "horde" or w == "h" or w == "1" then table.insert(tids, 1)
            elseif w == "draw" or w == "d" or w == "2" then table.insert(tids, 2) end
        end
        if #tids > 0 then
            local parts = {}
            for i=1,#tids do parts[i] = tostring(math.floor(tonumber(tids[i]) or 0)) end
            table.insert(where, string.format("winner_tid IN (%s)", table.concat(parts, ",")))
        end
    end
    -- affixFilter can be CSV of numbers or names; support server-side name resolution via dc_hlbg_affixes
    if affixFilter and tostring(affixFilter) ~= "" and tostring(affixFilter):lower() ~= "all" then
        local ids = {}
        for _,a in ipairs(splitCSV(affixFilter)) do
            local n = tonumber(a)
            if n then
                table.insert(ids, tostring(math.floor(n)))
            else
                local rid = resolveAffixToken(a, seasonId)
                if rid then table.insert(ids, tostring(rid)) end
            end
        end
        if #ids > 0 then
            table.insert(where, string.format("affix IN (%s)", table.concat(ids, ",")))
        end
    end
    -- Optional: if a seasonId > 0 was provided, filter by season column in history (only if column exists)
    if seasonId and tonumber(seasonId) and tonumber(seasonId) > 0 and hasColumn('dc_hlbg_winner_history','season') then
        table.insert(where, string.format("(season = %d)", tonumber(seasonId)))
    end
    if #where > 0 then return " WHERE " .. table.concat(where, " AND ") else return "" end
end

local function FetchHistoryPage(page, perPage, sortKey, sortDir, winnerFilter, affixFilter, seasonId)
    page = tonumber(page) or 1
    perPage = tonumber(perPage) or 25
    if page < 1 then page = 1 end
    local offset = (page - 1) * perPage
    local orderBy = buildOrderClause(sortKey, sortDir)
    -- Build WHERE using optional filters (winner/affix/season)
    local where = buildHistoryWhereClause(winnerFilter, affixFilter, seasonId)
    -- Include season column if available
    local haveSeason = hasColumn('dc_hlbg_winner_history','season')
    local seasonSel = haveSeason and ", season" or ""
    local sql = string.format("SELECT id, occurred_at, winner_tid, win_reason, affix%s FROM dc_hlbg_winner_history%s ORDER BY %s LIMIT %d OFFSET %d", seasonSel, where, orderBy, perPage, offset)
    local res = safeQuery(CharDBQuery, sql)
    local rows = {}
    if res then
        while res:NextRow() do
            local id = res:GetUInt64(0)
            local ts = res:GetString(1)
            local tid = res:GetUInt32(2)
            local reason = res:IsNull(3) and nil or res:GetString(3)
            local affix = res:GetUInt32(4)
            local winner = (tid == 0 and "Alliance") or (tid == 1 and "Horde") or "DRAW"
            -- Return named-field rows to avoid transport shape ambiguity on clients
            -- { id = <string>, ts = <string>, winner = <string>, affix = <string>, reason = <string> }
            local row = { id = tostring(id), ts = ts, winner = winner, affix = tostring(affix), reason = reason or "-" }
            if haveSeason then
                -- season column index 5 when selected
                local sv = res:GetUInt32(5) or 0
                row.season = sv
            end
            table.insert(rows, row)
        end
    end
    local total = 0
    local cnt = safeQuery(CharDBQuery, "SELECT COUNT(*) FROM dc_hlbg_winner_history" .. where)
    if cnt then total = asNumber((cnt.GetUInt64 and cnt:GetUInt64(0)) or (cnt.GetUInt32 and cnt:GetUInt32(0)) or 0) end
    -- Return the primary col/dir (first pair), for client display
    local firstCol = sanitizeSort(splitCSV(sortKey)[1] or "id")
    local firstDir = sanitizeDir(splitCSV(sortDir)[1] or "DESC")
    return rows, total, firstCol, firstDir
end

local function FetchStats(seasonId)
    -- Rich stats modeled after npc_hl_scoreboard: totals, streaks, margins, per-affix splits
    local stats = { counts = {}, draws = 0, avgDuration = 0, byAffix = {}, affixDur = {}, winRates = {}, totals = {}, reasons = {} }
    local whereParts = {}
    -- Treat seasonId=0 as "current/all" (no filter). Only filter when > 0 and column exists.
    if seasonId and tonumber(seasonId) and tonumber(seasonId) > 0 and hasColumn('dc_hlbg_winner_history','season') then
        table.insert(whereParts, string.format("season = %d", tonumber(seasonId)))
    end
    -- Optionally exclude manual resets if configured via OutdoorPvPHL (when available)
    local includeManual = true
    do
        local ok, OutdoorPvPHL = pcall(function() return OutdoorPvPHL end)
        if ok and OutdoorPvPHL and OutdoorPvPHL.GetStatsIncludeManualResets then
            local hl = GetHL and GetHL() or nil
            if hl and hl.GetStatsIncludeManualResets then includeManual = hl:GetStatsIncludeManualResets() and true or false end
        end
    end
    if not includeManual then
        table.insert(whereParts, "(win_reason IS NULL OR win_reason <> 'manual')")
    end
    local where = (#whereParts>0) and (" WHERE "..table.concat(whereParts, " AND ")) or ""
    -- total
    do
        local t = safeQuery(CharDBQuery, "SELECT COUNT(*) FROM dc_hlbg_winner_history"..where)
        if t then stats.total = asNumber((t.GetUInt64 and t:GetUInt64(0)) or (t.GetUInt32 and t:GetUInt32(0)) or 0) end
    end
    -- winner_tid: 0 Alliance, 1 Horde, 2 Neutral/Draw
    local res = safeQuery(CharDBQuery, "SELECT winner_tid, COUNT(*) FROM dc_hlbg_winner_history"..where.." GROUP BY winner_tid")
    if res then
        while res:NextRow() do
            local tid = res:GetUInt32(0)
            local c = res:GetUInt32(1)
            if tid == 0 then stats.counts["Alliance"] = c
            elseif tid == 1 then stats.counts["Horde"] = c
            else stats.draws = c end
        end
    end
    -- Win reasons summary
    do
        local rr = safeQuery(CharDBQuery, "SELECT SUM(win_reason='depletion'), SUM(win_reason='tiebreaker'), SUM(win_reason='manual') FROM dc_hlbg_winner_history"..where)
        if rr then
            stats.reasons = { depletion = asNumber(rr:GetUInt64(0) or 0), tiebreaker = asNumber(rr:GetUInt64(1) or 0), manual = asNumber(rr:GetUInt64(2) or 0) }
        end
    end
    if hasColumn('dc_hlbg_winner_history','duration_seconds') then
        -- Include the base WHERE clause (if any) before appending additional predicates
        local sep = (where ~= "" and " AND ") or " WHERE "
        local res2 = safeQuery(CharDBQuery, "SELECT AVG(duration_seconds) FROM dc_hlbg_winner_history"..where..sep.."duration_seconds IS NOT NULL")
        if res2 then
            stats.avgDuration = res2:IsNull(0) and 0 or res2:GetFloat(0)
        end
    else
        stats.avgDuration = 0
    end
    -- Minimal by-affix split (optional)
    local res3 = safeQuery(CharDBQuery, "SELECT affix, winner_tid, COUNT(*) FROM dc_hlbg_winner_history"..where.." GROUP BY affix, winner_tid")
    if res3 then
        while res3:NextRow() do
            local aff = tostring(res3:GetUInt32(0))
            local tid = res3:GetUInt32(1)
            local c = res3:GetUInt32(2)
            stats.byAffix[aff] = stats.byAffix[aff] or { Alliance = 0, Horde = 0, DRAW = 0 }
            if tid == 0 then stats.byAffix[aff].Alliance = c
            elseif tid == 1 then stats.byAffix[aff].Horde = c
            else stats.byAffix[aff].DRAW = c end
        end
    end
    -- Per-affix win rates (A/H/D counts + n)
    do
        local rr = safeQuery(CharDBQuery, "SELECT affix, SUM(winner_tid=0), SUM(winner_tid=1), SUM(winner_tid=2), COUNT(*) FROM dc_hlbg_winner_history"..where.." GROUP BY affix ORDER BY affix")
        if rr then
            while rr:NextRow() do
                local aff = tostring(rr:GetUInt32(0))
                local a = asNumber(rr:GetUInt64(1) or 0)
                local h = asNumber(rr:GetUInt64(2) or 0)
                local d = asNumber(rr:GetUInt64(3) or 0)
                local n = asNumber(rr:GetUInt64(4) or 0)
                stats.winRates[aff] = { A = a, H = h, D = d, n = n }
            end
        end
    end
    -- No weather column in schema; leave byWeather empty
    -- Duration aggregates per affix
    if hasColumn('dc_hlbg_winner_history','duration_seconds') then
        -- Include the base WHERE clause (if any) before appending additional predicates
        local sep = (where ~= "" and " AND ") or " WHERE "
        local res5 = safeQuery(CharDBQuery, "SELECT affix, COUNT(*), SUM(duration_seconds), AVG(duration_seconds) FROM dc_hlbg_winner_history"..where..sep.."duration_seconds IS NOT NULL GROUP BY affix")
        if res5 then
            while res5:NextRow() do
                local aff = tostring(res5:GetUInt32(0))
                local c = res5:GetUInt32(1)
                local s = res5:IsNull(2) and 0 or asNumber(res5:GetUInt64(2))
                local a = res5:IsNull(3) and 0 or tonumber(res5:GetFloat(3)) or 0
                stats.affixDur[aff] = { count = c, sum = s, avg = a }
            end
        end
    end
    -- Current and longest streaks (last 200)
    do
        local q = safeQuery(CharDBQuery, "SELECT winner_tid FROM dc_hlbg_winner_history"..where.." ORDER BY id DESC LIMIT 200")
        local currCount, currTeam = 0, 2
        local bestCount, bestTeam = 0, 2
        if q then
            local first = true
            local prev = 2
            while q:NextRow() do
                local t = q:GetUInt32(0)
                if t ~= 0 and t ~= 1 then
                    if first then currCount = 0; currTeam = 2; first = false end
                    prev = 2
                else
                    if first then currTeam = t; currCount = 1; first = false end
                    if prev == t then
                        currCount = currCount + 1
                    elseif prev == 2 then
                        currCount = 1; currTeam = t
                    else
                        if currCount > bestCount then bestCount = currCount; bestTeam = prev end
                        currCount = 1; currTeam = t
                    end
                    prev = t
                end
            end
            if currCount > bestCount then bestCount = currCount; bestTeam = currTeam end
        end
        local function tn(id) return (id==0 and 'Alliance') or (id==1 and 'Horde') or 'None' end
        stats.currentStreakTeam = tn(currTeam)
        stats.currentStreakLen = currCount
        stats.longestStreakTeam = tn(bestTeam)
        stats.longestStreakLen = bestCount
    end
    -- Largest margin among A/H
    do
        local sep = (where ~= "" and " AND ") or " WHERE "
        local rm = safeQuery(CharDBQuery, "SELECT occurred_at, winner_tid, score_alliance, score_horde FROM dc_hlbg_winner_history"..where..sep.."winner_tid IN (0,1) ORDER BY ABS(score_alliance - score_horde) DESC, id DESC LIMIT 1")
        if rm and rm:NextRow() then
            local ts = rm:GetString(0)
            local tid = rm:GetUInt32(1)
            local a = rm:GetUInt32(2)
            local h = rm:GetUInt32(3)
            local margin = (a>h) and (a-h) or (h-a)
            stats.largestMargin = { ts = ts, winner = (tid==0 and 'Alliance' or 'Horde'), a = a, h = h, margin = margin }
        end
    end
    -- Average scores per affix
    do
        local ra = safeQuery(CharDBQuery, "SELECT affix, AVG(score_alliance), AVG(score_horde), COUNT(*) FROM dc_hlbg_winner_history"..where.." GROUP BY affix ORDER BY affix")
        if ra then
            stats.avgScorePerAffix = {}
            while ra:NextRow() do
                local aff = tostring(ra:GetUInt32(0))
                local avga = tonumber(ra:GetDouble(1)) or 0
                local avgh = tonumber(ra:GetDouble(2)) or 0
                local n    = asNumber(ra:GetUInt64(3) or 0)
                stats.avgScorePerAffix[aff] = { A = avga, H = avgh, n = n }
            end
        end
    end
    -- Average margin per affix
    do
        local ram = safeQuery(CharDBQuery, "SELECT affix, AVG(ABS(score_alliance - score_horde)) AS am, COUNT(*) FROM dc_hlbg_winner_history"..where.." GROUP BY affix ORDER BY am DESC")
        if ram then
            stats.affixAvgMargin = {}
            while ram:NextRow() do
                local aff = tostring(ram:GetUInt32(0))
                local avgm = tonumber(ram:GetDouble(1)) or 0
                local n = asNumber(ram:GetUInt64(2) or 0)
                stats.affixAvgMargin[aff] = { avg = avgm, n = n }
            end
        end
    end
    -- Reason breakdown per affix
    do
        local rrb = safeQuery(CharDBQuery, "SELECT affix, SUM(win_reason='depletion'), SUM(win_reason='tiebreaker'), COUNT(*) FROM dc_hlbg_winner_history"..where.." GROUP BY affix ORDER BY affix")
        if rrb then
            stats.affixReasons = {}
            while rrb:NextRow() do
                local aff = tostring(rrb:GetUInt32(0))
                local dep = asNumber(rrb:GetUInt64(1) or 0)
                local tie = asNumber(rrb:GetUInt64(2) or 0)
                local n   = asNumber(rrb:GetUInt64(3) or 0)
                stats.affixReasons[aff] = { depletion = dep, tiebreaker = tie, n = n }
            end
        end
    end
    -- Top lists (limit 5)
    local topN = 5
    do
        local sep = (where ~= "" and " AND ") or " WHERE "
        local rt = safeQuery(CharDBQuery, "SELECT winner_tid, affix, COUNT(*) AS c FROM dc_hlbg_winner_history"..where..sep.."winner_tid IN (0,1) GROUP BY winner_tid, affix ORDER BY c DESC LIMIT "..topN)
        if rt then
            stats.topWinnersByAffix = {}
            while rt:NextRow() do
                local tid = rt:GetUInt32(0)
                local aff = rt:GetUInt32(1)
                local c   = asNumber(rt:GetUInt64(2) or 0)
                table.insert(stats.topWinnersByAffix, { tid = tid, winner = (tid==0 and 'Alliance' or 'Horde'), affix = aff, count = c })
            end
        end
    end
    do
        local sep = (where ~= "" and " AND ") or " WHERE "
        local rdraw = safeQuery(CharDBQuery, "SELECT affix, COUNT(*) AS c FROM dc_hlbg_winner_history"..where..sep.."winner_tid=2 GROUP BY affix ORDER BY c DESC LIMIT "..topN)
        if rdraw then
            stats.drawsByAffix = {}
            while rdraw:NextRow() do
                local aff = rdraw:GetUInt32(0)
                local c   = asNumber(rdraw:GetUInt64(1) or 0)
                table.insert(stats.drawsByAffix, { affix = aff, count = c })
            end
        end
    end
    do
        local rtd = safeQuery(CharDBQuery, "SELECT winner_tid, affix, COUNT(*) AS c FROM dc_hlbg_winner_history"..where.." GROUP BY winner_tid, affix ORDER BY c DESC LIMIT "..topN)
        if rtd then
            stats.topOutcomesByAffix = {}
            while rtd:NextRow() do
                local tid = rtd:GetUInt32(0)
                local aff = rtd:GetUInt32(1)
                local c   = asNumber(rtd:GetUInt64(2) or 0)
                local oname = (tid==0 and 'Alliance') or (tid==1 and 'Horde') or 'Draw'
                table.insert(stats.topOutcomesByAffix, { affix = aff, outcome = oname, tid = tid, count = c })
            end
        end
    end
    do
        local raf = safeQuery(CharDBQuery, "SELECT affix, COUNT(*) AS c FROM dc_hlbg_winner_history"..where.." GROUP BY affix ORDER BY c DESC, affix ASC LIMIT "..topN)
        if raf then
            stats.topAffixesByMatches = {}
            while raf:NextRow() do
                local aff = raf:GetUInt32(0)
                local c   = asNumber(raf:GetUInt64(1) or 0)
                table.insert(stats.topAffixesByMatches, { affix = aff, count = c })
            end
        end
    end
    -- Median margin using window functions if supported (DB >= MariaDB 10.2 or MySQL 8)
    do
        local supports = false
        local ver = safeQuery(CharDBQuery, "SELECT VERSION()")
        if ver and ver:NextRow() then
            local v = tostring(ver:GetString(0) or "")
            if v:find("MariaDB") then
                local p = v:find("10%.")
                supports = (p ~= nil)
            else
                local first = v:match("^(%d+)")
                supports = (tonumber(first or 0) or 0) >= 8
            end
        end
        if supports then
            local cond = where:gsub("^%s*WHERE%s*", "")
            if cond == '' then cond = '1=1' end
            local sql = (
                "WITH ranked AS ("..
                "SELECT affix, ABS(score_alliance - score_horde) AS m, "..
                "ROW_NUMBER() OVER (PARTITION BY affix ORDER BY ABS(score_alliance - score_horde)) AS rn, "..
                "COUNT(*) OVER (PARTITION BY affix) AS cnt FROM dc_hlbg_winner_history WHERE "..cond..") "..
                "SELECT affix, AVG(m) AS med FROM ranked WHERE rn IN (FLOOR((cnt+1)/2), FLOOR((cnt+2)/2)) GROUP BY affix ORDER BY med DESC"
            )
            local rmed = safeQuery(CharDBQuery, sql)
            if rmed then
                stats.affixMedianMargin = {}
                while rmed:NextRow() do
                    local aff = rmed:GetUInt32(0)
                    local med = tonumber(rmed:GetDouble(1)) or 0
                    stats.affixMedianMargin[aff] = med
                end
            end
        end
    end
    -- No weather duration aggregates (column absent)
    return stats
end

-- Lightweight match state and queue management
local HLBG_State = HLBG_State or {
    phase = "idle",     -- idle | warmup | active | ended
    affix = 0,
    startTs = 0,         -- os.time() when started (warmup or active)
    endTs = 0,           -- os.time() when current phase ends
    duration = 0,        -- seconds for the current phase (for convenience)
    scoreA = 0,
    scoreH = 0,
    locked = false,
}

local HLBG_Queue = HLBG_Queue or { Alliance = {}, Horde = {} }

HLBG_Config.queue = HLBG_Config.queue or {
    teleport_on_reset = false,
    map = 0, -- Eastern Kingdoms
    Alliance = { x = -45.0, y = -45.0, z = 0.5, o = 0.0 }, -- sample placeholders, change to safe coords
    Horde = { x = -35.0, y = -35.0, z = 0.5, o = 0.0 },
}

local function teamNameFromId(tid)
    if tid == 0 then return "Alliance" elseif tid == 1 then return "Horde" else return "Neutral" end
end

local function playerTeamName(player)
    local t = 2
    pcall(function() t = player:GetTeam() end)
    return teamNameFromId(t)
end

local function inQueue(tbl, guid)
    for i=1,#tbl do if tbl[i] == guid then return i end end
    return nil
end

local function joinQueue(player)
    if not player or not player.GetGUIDLow then return end
    local guid = player:GetGUIDLow()
    local team = playerTeamName(player)
    local q = HLBG_Queue[team]
    if not q then HLBG_Queue[team] = {}; q = HLBG_Queue[team] end
    local pos = inQueue(q, guid)
    if not pos then table.insert(q, guid); pos = #q end
    return team, pos, #q
end

local function leaveQueue(player)
    if not player or not player.GetGUIDLow then return end
    local guid = player:GetGUIDLow()
    local team = playerTeamName(player)
    local q = HLBG_Queue[team]
    if q then
        local idx = inQueue(q, guid)
        if idx then table.remove(q, idx) end
    end
    return team, (q and #q or 0)
end

local function queuePosition(player)
    if not player or not player.GetGUIDLow then return nil, nil, nil end
    local guid = player:GetGUIDLow()
    local team = playerTeamName(player)
    local q = HLBG_Queue[team]
    local pos = q and inQueue(q, guid) or nil
    return team, pos, (q and #q or 0)
end

local function secondsRemaining()
    local now = os.time()
    local rem = (HLBG_State.endTs or 0) - now
    if rem < 0 then rem = 0 end
    return rem
end

local function BuildStatusPayload()
    -- Compute live faction player counts in configured zone (best-effort)
    local zoneId = HLBG_Config and HLBG_Config.live_broadcast and HLBG_Config.live_broadcast.zoneId or 47
    local aPlayers, hPlayers = 0, 0
    for _,pl in ipairs(GetPlayersInWorld() or {}) do
        local okZ, zid = pcall(function() return pl:GetZoneId() end)
        if okZ and tonumber(zid) == tonumber(zoneId) then
            local okT, t = pcall(function() return pl:GetTeam() end)
            if okT then if t == 0 then aPlayers = aPlayers + 1 elseif t == 1 then hPlayers = hPlayers + 1 end end
        end
    end
    return {
        A = HLBG_State.scoreA or 0,
        H = HLBG_State.scoreH or 0,
        END = HLBG_State.endTs or 0,
        LOCK = HLBG_State.locked and 1 or 0,
        AFF = HLBG_State.affix or 0,
        DURATION = HLBG_State.duration or 0,
        PHASE = HLBG_State.phase or "idle",
        APlayers = aPlayers,
        HPlayers = hPlayers,
        -- aliases for older client keys
        APC = aPlayers,
        HPC = hPlayers,
    }
end

local function BroadcastStatus(toPlayer)
    local payload = BuildStatusPayload()
    if okAIO and AIO and AIO.Handle then
        if toPlayer then
            AIO.Handle(toPlayer, "HLBG", "Status", payload)
        else
            for _,pl in ipairs(GetPlayersInWorld() or {}) do pcall(function() AIO.Handle(pl, "HLBG", "Status", payload) end) end
        end
    end
    -- Chat fallback
    local msg = string.format("[HLBG_STATUS] A=%d|H=%d|END=%d|LOCK=%d|AFF=%d|DURATION=%d|PHASE=%s|APLAYERs=%d|HPLAYERS=%d",
        payload.A, payload.H, payload.END, payload.LOCK, payload.AFF, payload.DURATION, tostring(payload.PHASE),
        tonumber(payload.APlayers or 0) or 0, tonumber(payload.HPlayers or 0) or 0)
    if toPlayer and toPlayer.SendBroadcastMessage then
        toPlayer:SendBroadcastMessage(msg)
    else
        for _,pl in ipairs(GetPlayersInWorld() or {}) do pcall(function() pl:SendBroadcastMessage(msg) end) end
    end
end

local function BroadcastWarmup(seconds)
    local sec = tonumber(seconds) or 0
    local msg = string.format("[HLBG_WARMUP] seconds=%d|affix=%d", sec, HLBG_State.affix or 0)
    for _,pl in ipairs(GetPlayersInWorld() or {}) do pcall(function() pl:SendBroadcastMessage(msg) end) end
end

local function SendQueueMessage(player, action, data)
    local parts = { "[HLBG_QUEUE] action="..tostring(action) }
    if data then
        for k,v in pairs(data) do table.insert(parts, tostring(k).."="..tostring(v)) end
    end
    local line = table.concat(parts, "|")
    if player and player.SendBroadcastMessage then player:SendBroadcastMessage(line) end
end

local function StartWarmup(seconds, affix)
    HLBG_State.phase = "warmup"
    HLBG_State.affix = tonumber(affix) or (HLBG_State.affix or 0)
    HLBG_State.duration = tonumber(seconds) or 120
    HLBG_State.startTs = os.time()
    HLBG_State.endTs = HLBG_State.startTs + HLBG_State.duration
    HLBG_State.locked = true
    BroadcastWarmup(HLBG_State.duration)
    BroadcastStatus()
    -- Optionally port queued players at warmup start
    if HLBG_Config.queue and HLBG_Config.queue.teleport_on_reset then
        for team,q in pairs(HLBG_Queue) do
            for i=1,#q do
                local guid = q[i]
                for _,pl in ipairs(GetPlayersInWorld() or {}) do
                    if pl:GetGUIDLow() == guid then
                        local pos = HLBG_Config.queue[team]
                        if pos then
                            pcall(function() pl:Teleport(HLBG_Config.queue.map or 0, pos.x, pos.y, pos.z, pos.o) end)
                            SendQueueMessage(pl, "teleported", { team = team, phase = "warmup" })
                        end
                    end
                end
            end
        end
    end
end

local function StartMatch(seconds, affix)
    HLBG_State.phase = "active"
    HLBG_State.affix = tonumber(affix) or (HLBG_State.affix or 0)
    HLBG_State.duration = tonumber(seconds) or 900
    HLBG_State.startTs = os.time()
    HLBG_State.endTs = HLBG_State.startTs + HLBG_State.duration
    HLBG_State.locked = true
    BroadcastStatus()
    -- Optionally port queued players at match start (if not already teleported)
    if HLBG_Config.queue and HLBG_Config.queue.teleport_on_reset then
        for team,q in pairs(HLBG_Queue) do
            for i=1,#q do
                local guid = q[i]
                for _,pl in ipairs(GetPlayersInWorld() or {}) do
                    if pl:GetGUIDLow() == guid then
                        local pos = HLBG_Config.queue[team]
                        if pos then
                            pcall(function() pl:Teleport(HLBG_Config.queue.map or 0, pos.x, pos.y, pos.z, pos.o) end)
                            SendQueueMessage(pl, "teleported", { team = team, phase = "start" })
                        end
                    end
                end
            end
        end
    end
end

local function EndMatch()
    HLBG_State.phase = "ended"
    HLBG_State.duration = 0
    HLBG_State.endTs = os.time()
    HLBG_State.locked = false
    BroadcastStatus()
end

local function ResetMatch()
    HLBG_State.phase = "idle"
    HLBG_State.duration = 0
    HLBG_State.startTs = 0
    HLBG_State.endTs = 0
    HLBG_State.locked = false
    BroadcastStatus()
    -- Optional teleport queued players to faction spawns
    if HLBG_Config.queue and HLBG_Config.queue.teleport_on_reset then
        for team,q in pairs(HLBG_Queue) do
            for i=1,#q do
                local guid = q[i]
                for _,pl in ipairs(GetPlayersInWorld() or {}) do
                    if pl:GetGUIDLow() == guid then
                        local pos = HLBG_Config.queue[team]
                        if pos then
                            pcall(function() pl:Teleport(HLBG_Config.queue.map or 0, pos.x, pos.y, pos.z, pos.o) end)
                            SendQueueMessage(pl, "teleported", { team = team })
                        end
                    end
                end
            end
        end
    end
    -- Clear queues after reset
    HLBG_Queue = { Alliance = {}, Horde = {} }
end

-- Background timer to auto-transition when timers elapse
if not __hlbg_tick_event then
    __hlbg_tick_event = CreateLuaEvent(function(e)
        if HLBG_State.phase == "warmup" or HLBG_State.phase == "active" then
            if secondsRemaining() <= 0 then
                if HLBG_State.phase == "warmup" then
                    -- auto-start match after warmup
                    StartMatch(900, HLBG_State.affix)
                else
                    -- active ended
                    EndMatch()
                    ResetMatch()
                end
            end
        end
    end, 1000, 0)
    print("[HLBG_AIO] Tick event registered for state transitions")
end

function Handlers.Request(player, what, arg1, arg2, arg3, arg4, arg5, arg6, arg7)
    if what == "HISTORY" then
        local page = tonumber(arg1) or 1
        local per = tonumber(arg2) or 25
        -- Accept both shapes:
        --  New:  page, per, sortKey, sortDir, winnerFilter, affixFilter, seasonId
        --  Legacy: page, per, seasonId, sortKey, sortDir
        local sortKey, sortDir, winnerFilter, affixFilter, seasonId
        if arg3 and tonumber(arg3) and (not tonumber(arg4)) and (arg5 or arg6 or arg7) then
            -- Likely legacy with season in arg3
            seasonId = tonumber(arg3)
            sortKey = arg4 or "id"
            sortDir = arg5 or "DESC"
            winnerFilter = arg6
            affixFilter = arg7
        else
            sortKey = arg3 or "id"
            sortDir = arg4 or "DESC"
            winnerFilter = arg5
            affixFilter = arg6
            seasonId = tonumber(arg7)
        end
    local rows, total, col, dir = FetchHistoryPage(page, per, sortKey, sortDir, winnerFilter, affixFilter, seasonId)
        print(string.format("[HLBG_AIO] HISTORY page=%d per=%d -> rows=%d total=%s sort=%s %s", page, per, (rows and #rows or 0), tostring(total), tostring(col), tostring(dir)))
        if okAIO and AIO and AIO.Handle then
            -- Send as table (preferred)
            AIO.Handle(player, "HLBG", "History", rows, page, per, total, col, dir)
            -- Also send a compact TSV string fallback for older AIO builds
            local buf = {}
            for i=1,#rows do
                local r = rows[i]
                -- r = { id = <>, ts = <>, winner = <>, affix = <>, reason = <> }
                table.insert(buf, table.concat({ r.id or "", r.ts or "", r.winner or "", r.affix or "", r.reason or "" }, "\t"))
            end
            local tsv = table.concat(buf, "\n")
            AIO.Handle(player, "HLBG", "HistoryStr", tsv, page, per, total, col, dir)
            -- DEBUG (disabled): also send a short plain chat broadcast to the player with a TSV sample so clients
            -- that don't decode AIO properly still receive a visible sample for debugging.
            -- local ok, err = pcall(function()
            --     if player and player.SendBroadcastMessage then
            --         local sample = (tsv and #tsv>200) and tsv:sub(1,200) or tsv
            --         sample = sanitize_for_chat(sample)
            --         player:SendBroadcastMessage("[HLBG_DBG_TSV] "..tostring(sample or ""))
            --     end
            -- end)
            -- Debug ping to confirm client receive path
            AIO.Handle(player, "HLBG", "PONG")
            -- Lightweight debug string (avoid large tables) so client can confirm receipt
            AIO.Handle(player, "HLBG", "DBG", string.format("HISTORY_N=%d TOTAL=%s", rows and #rows or 0, tostring(total)))
        end
    elseif what == "STATS" then
        local season = tonumber(arg1)
        local stats = FetchStats(season)
        if okAIO and AIO and AIO.Handle then
            AIO.Handle(player, "HLBG", "Stats", stats)
            -- Debug ping to confirm client receive path
            AIO.Handle(player, "HLBG", "PONG")
            AIO.Handle(player, "HLBG", "DBG", "STATS_OK")
        end
    elseif what == "RESULTS" then
        -- Return the last recorded match (optionally for a given season)
        local season = tonumber(arg1)
        local haveSeason = hasColumn('dc_hlbg_winner_history','season')
        local where = ""
        if season and haveSeason then where = string.format(" WHERE season = %d", season) end
        local sql = "SELECT id, occurred_at, winner_tid, win_reason, affix" .. (haveSeason and ", season" or "") ..
                    " FROM dc_hlbg_winner_history" .. where .. " ORDER BY occurred_at DESC LIMIT 1"
        local res = safeQuery(CharDBQuery, sql)
        local payload = {}
        if res and res:NextRow() then
            local id = res:GetUInt64(0)
            local ts = res:GetString(1)
            local tid = res:GetUInt32(2)
            local reason = res:IsNull(3) and nil or res:GetString(3)
            local affix = res:GetUInt32(4)
            local winner = (tid == 0 and "Alliance") or (tid == 1 and "Horde") or "DRAW"
            payload = { id = tostring(id), ts = ts, winner = winner, affix = tostring(affix), reason = reason or "-" }
            if haveSeason then payload.season = res:GetUInt32(5) end
        end
        if okAIO and AIO and AIO.Handle then
            AIO.Handle(player, "HLBG", "Results", payload)
        end
    elseif what == "AFFIXES" then
        local seasonId = tonumber(arg1)
        local search = tostring(arg2 or "")
        -- Preflight column availability via information_schema to avoid MySQL aborts when columns are missing
        local hasEffect, hasSeason = false, false
        do
            local qEff = "SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME='dc_hlbg_affixes' AND COLUMN_NAME='effect'"
            local rEff = safeQuery(CharDBQuery, qEff)
            if rEff then local n = asNumber((rEff.GetUInt64 and rEff:GetUInt64(0)) or (rEff.GetUInt32 and rEff:GetUInt32(0)) or 0); hasEffect = (n > 0) end
            local qSea = "SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME='dc_hlbg_affixes' AND COLUMN_NAME='season_id'"
            local rSea = safeQuery(CharDBQuery, qSea)
            if rSea then local n2 = asNumber((rSea.GetUInt64 and rSea:GetUInt64(0)) or (rSea.GetUInt32 and rSea:GetUInt32(0)) or 0); hasSeason = (n2 > 0) end
        end
        -- Build WHERE with guards for optional columns
        local whereParts = {}
        if seasonId and hasSeason then table.insert(whereParts, string.format("(season_id = %d OR season_id IS NULL)", seasonId)) end
        if search ~= "" then
            local s = search:gsub("'", "''")
            local nameLike = string.format("(name LIKE '%%%s%%')", s)
            if hasEffect then
                table.insert(whereParts, "(" .. nameLike .. string.format(" OR (effect LIKE '%%%s%%')", s) .. ")")
            else
                table.insert(whereParts, nameLike)
            end
        end
        local where = (#whereParts > 0) and (" WHERE "..table.concat(whereParts, " AND ")) or ""
        local selEffect = hasEffect and "effect" or "''"
        local selSeason = hasSeason and "COALESCE(season_id,0)" or "0"
        local sql = string.format("SELECT id, name, %s, %s FROM dc_hlbg_affixes%s ORDER BY name ASC", selEffect, selSeason, where)
        local res = safeQuery(CharDBQuery, sql)
        local rows = {}
        if res then
            repeat
                local id = res:GetUInt32(0)
                local name = res:GetString(1)
                local effect = hasEffect and res:GetString(2) or ""
                local sid = hasSeason and res:GetUInt32(3) or 0
                table.insert(rows, { id = id, name = name, effect = effect, season_id = sid })
            until not res:NextRow()
        end
        if okAIO and AIO and AIO.Handle then
            AIO.Handle(player, "HLBG", "Affixes", rows)
        end
    elseif what == "STATUS" then
        BroadcastStatus(player)
    elseif what == "QUEUE" then
        local action = tostring(arg1 or "status"):lower()
        if action == "join" then
            local team, pos, size = joinQueue(player)
            local eta = secondsRemaining()
            if okAIO and AIO and AIO.Handle then
                local aCount = HLBG_Queue.Alliance and #HLBG_Queue.Alliance or 0
                local hCount = HLBG_Queue.Horde and #HLBG_Queue.Horde or 0
                AIO.Handle(player, "HLBG", "QueueStatus", { team = team, pos = pos, size = size, eta = eta, countA = aCount, countH = hCount })
            end
            SendQueueMessage(player, "joined", { team = team, pos = pos, size = size, eta = eta })
        elseif action == "leave" then
            local team, size = leaveQueue(player)
            if okAIO and AIO and AIO.Handle then
                local aCount = HLBG_Queue.Alliance and #HLBG_Queue.Alliance or 0
                local hCount = HLBG_Queue.Horde and #HLBG_Queue.Horde or 0
                AIO.Handle(player, "HLBG", "QueueStatus", { team = team, pos = 0, size = size, eta = secondsRemaining(), countA = aCount, countH = hCount })
            end
            SendQueueMessage(player, "left", { team = team, size = size })
        else
            local team, pos, size = queuePosition(player)
            if okAIO and AIO and AIO.Handle then
                local aCount = HLBG_Queue.Alliance and #HLBG_Queue.Alliance or 0
                local hCount = HLBG_Queue.Horde and #HLBG_Queue.Horde or 0
                AIO.Handle(player, "HLBG", "QueueStatus", { team = team, pos = pos or 0, size = size or 0, eta = secondsRemaining(), countA = aCount, countH = hCount })
            end
            SendQueueMessage(player, "status", { team = team or "?", pos = pos or 0, size = size or 0, eta = secondsRemaining() })
        end
    elseif what == "PING" then
        if okAIO and AIO and AIO.Handle then
            AIO.Handle(player, "HLBG", "PONG")
        end
    elseif what == "CLIENTLOG" then
        -- arg1 is a string payload from the client; enqueue to server-side log buffer
        if type(arg1) == "string" and arg1 ~= "" then
            local line = tostring(arg1)
            -- lightweight protective truncation to avoid runaway memory
            if #line > 2000 then line = line:sub(1,2000) .. "...[truncated]" end
            -- enqueue instead of immediate io.open per-message to reduce I/O
            if not __hlbg_log_buffer then __hlbg_log_buffer = {} end
            if not __hlbg_log_stats then __hlbg_log_stats = {lastFlush = os.time(), enqueued = 0} end
            -- store structured entry with player name to enable aggregation and dedupe
            local who = "?"
            pcall(function()
                if player and player.GetName then who = tostring(player:GetName()) end
            end)
            if not __hlbg_log_buffer then __hlbg_log_buffer = {} end
            table.insert(__hlbg_log_buffer, { who = who, line = line })
            __hlbg_log_stats.enqueued = (__hlbg_log_stats.enqueued or 0) + 1
            -- protect against unbounded growth
            if #__hlbg_log_buffer > 20000 then
                -- drop oldest entries to keep memory bounded
                local drop = #__hlbg_log_buffer - 15000
                for i=1,drop do table.remove(__hlbg_log_buffer,1) end
            end
            -- create a server-side flush event once (use CreateLuaEvent on server)
            if not __hlbg_log_flush_event then
                local flushIntervalMs = 2000 -- milliseconds
                __hlbg_log_flush_event = CreateLuaEvent(function(e)
                    if not __hlbg_log_buffer or #__hlbg_log_buffer == 0 then return end
                    -- swap buffers to minimise time holding the active buffer
                    local toWrite = __hlbg_log_buffer
                    __hlbg_log_buffer = {}
                    -- write all queued lines in one open/close
                    local logPath = HLBG_Config.server_log_path or "/home/wowcore/azeroth-server/logs/hlbg_client.log"
                    -- Try to ensure directory exists (best-effort)
                    pcall(function()
                        local dir = string.match(logPath, "^(.*)/[^/]+$")
                        if dir and dir ~= "" and os and os.execute then os.execute('mkdir -p '..dir) end
                    end)
                    local ok, f = pcall(function() return io.open(logPath, "a") end)
                    if ok and f then
                        -- Aggregate by content to avoid writing repeated identical lines.
                        local counts = {}
                        for i=1,#toWrite do
                            local ent = toWrite[i]
                            local full = string.format("%s: %s", tostring(ent.who or "?"), tostring(ent.line))
                            counts[full] = (counts[full] or 0) + 1
                        end
                        -- Convert to array of {line, count} and sort by count desc
                        local items = {}
                        for k,v in pairs(counts) do table.insert(items, { line = k, cnt = v }) end
                        table.sort(items, function(a,b) return a.cnt > b.cnt end)
                        local maxUnique = 50
                        local wrote = 0
                        for i=1,math.min(#items, maxUnique) do
                            local it = items[i]
                            if it.cnt > 1 then
                                pcall(function() f:write(string.format("[%s] %s  [repeats=%d]\n", os.date("%Y-%m-%d %H:%M:%S"), it.line, it.cnt)) end)
                            else
                                pcall(function() f:write(string.format("[%s] %s\n", os.date("%Y-%m-%d %H:%M:%S"), it.line)) end)
                            end
                            wrote = wrote + 1
                        end
                        if #items > maxUnique then
                            pcall(function() f:write(string.format("[%s] HLBG_AIO: %d unique lines omitted in this flush (cap=%d)\n", os.date("%Y-%m-%d %H:%M:%S"), #items - maxUnique, maxUnique)) end)
                            print(string.format("[HLBG_AIO] CLIENTLOG: flushed %d unique lines (omitted %d) to %s", wrote, #items - maxUnique, tostring(logPath)))
                        else
                            print(string.format("[HLBG_AIO] CLIENTLOG: flushed %d unique lines to %s", wrote, tostring(logPath)))
                        end
                        f:close()
                        __hlbg_log_stats.lastFlush = os.time()
                    else
                        -- if open failed, print to console to avoid silent loss
                        for i=1,#toWrite do local ent = toWrite[i]; print("[HLBG_CLIENTLOG] " .. tostring(ent.line)) end
                        print(string.format("[HLBG_AIO] CLIENTLOG: failed to open %s (err=%s); printed to console", tostring(logPath), tostring(f or "")))
                    end
                end, flushIntervalMs, 0)
                print(string.format("[HLBG_AIO] CLIENTLOG: buffer flush event registered (path=%s, interval_ms=%d)", tostring(HLBG_Config.server_log_path), flushIntervalMs))
            end
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

-- Also support /hlbg from client by mapping to same behavior
local function OnSlashHLBG(event, player, command)
    if command == "hlbg" or command == ".hlbg" then
        print("[HLBG_AIO] OnCommand received: "..tostring(command))
        if okAIO and AIO and AIO.Handle then
            AIO.Handle(player, "HLBG", "OpenUI")
            -- Prime initial data so tabs aren't empty
            AIO.Handle(player, "HLBG", "PONG")
            -- Status first, then stats/history minimal
            AIO.Handle(player, "HLBG", "Status", BuildStatusPayload())
            local rows, total = FetchHistoryPage(1, 10, "id", "DESC")
            AIO.Handle(player, "HLBG", "History", rows, 1, 10, total, "id", "DESC")
            AIO.Handle(player, "HLBG", "Stats", FetchStats())
        else
            player:SendBroadcastMessage("HLBG: UI requested. If AIO is unavailable, use PvP pane HLBG tab.")
        end
        return false
    end
end
RegisterPlayerEvent(42, OnSlashHLBG)

-- Bridge AIO calls used by clients (HistoryUI/StatsUI) to our unified request handler
if Handlers then
    function Handlers.HistoryUI(player, p, per, a3, a4, a5, a6, a7)
        -- Delegate to unified HISTORY path which already normalizes legacy/new shapes
        Handlers.Request(player, "HISTORY", p, per, a3, a4, a5, a6, a7)
    end
    function Handlers.StatsUI(player, season)
        Handlers.Request(player, "STATS", season)
    end
end

-- GM helper: broadcast a TSV dump of the current first page so clients can receive a visible sample
local function DumpHistoryToPlayer(player, page, per, sortKey, sortDir)
    page = tonumber(page) or 1; per = tonumber(per) or 5
    local rows, total, col, dir = FetchHistoryPage(page, per, sortKey, sortDir)
    -- build TSV
    local buf = {}
    if rows and #rows>0 then
        for i=1,#rows do
            local r = rows[i]
            table.insert(buf, table.concat({ r.id or "", r.ts or "", r.winner or "", r.affix or "", r.reason or "" }, "\t"))
        end
    end
    -- join rows with a safe delimiter '||' so chat doesn't collapse newlines; client will convert back
    local tsv = table.concat(buf, "||")
            if player and player.SendBroadcastMessage then
                local safe = sanitize_for_chat(tsv or "")
                player:SendBroadcastMessage("[HLBG_DUMP] "..safe)
            end
    return rows, total
end

-- Extend OnCommand to support .hlbgdump
local function OnCommandExtended(event, player, command)
    if command == "hlbgdump" or command == ".hlbgdump" then
        print("[HLBG_AIO] OnCommand received dump request: "..tostring(command))
        DumpHistoryToPlayer(player, 1, 5, "id", "DESC")
        return false
    end
    if command == "hlbgtest" or command == ".hlbgtest" then
        print("[HLBG_AIO] OnCommand received test request: "..tostring(command))
        -- Build a guaranteed array-shaped payload
        local now = os.date("%Y-%m-%d %H:%M:%S")
        local rows = {
            { id = "999", ts = now, winner = "Alliance", affix = "3", reason = "TestEntryA" },
            { id = "998", ts = now, winner = "Horde", affix = "5", reason = "TestEntryB" },
        }
        if okAIO and AIO and AIO.Handle then
            AIO.Handle(player, "HLBG", "History", rows, 1, 5, 2, "id", "DESC")
            -- also send a TSV fallback
            local buf = {}
            for i=1,#rows do
                local r = rows[i]
                table.insert(buf, table.concat({ r.id or "", r.ts or "", r.winner or "", r.affix or "", r.reason or "" }, "\t"))
            end
            local tsv = table.concat(buf, "\n")
            AIO.Handle(player, "HLBG", "HistoryStr", tsv, 1, 5, 2, "id", "DESC")
            -- Also send a chat broadcast fallback so non-AIO clients still receive a sample
            if player and player.SendBroadcastMessage then
                local safeTSV = tsv
                -- replace newlines with '||' to keep chat on a single line (client will convert back)
                safeTSV = safeTSV:gsub("\n", "||")
                safeTSV = sanitize_for_chat(safeTSV)
                player:SendBroadcastMessage("[HLBG_DUMP] "..tostring(safeTSV))
            end
            AIO.Handle(player, "HLBG", "PONG")
            print("[HLBG_AIO] Sent test HISTORY array to player")
        else
            player:SendBroadcastMessage("HLBG: test payload prepared but AIO unavailable")
        end
        return false
    end
    -- Fallback: history/historyui via chat command -> broadcast TSV with TOTAL prefix
    if command:match('^hlbg%s+historyui') or command:match('^%.hlbg%s+historyui') then
        local c = command:gsub('^%.','')
        local p, per, season, sk, sd = c:match('^hlbg%s+historyui%s+(%d+)%s+(%d+)%s+(%d+)%s+(%S+)%s+(%S+)')
        if not p then
            p, per, sk, sd = c:match('^hlbg%s+historyui%s+(%d+)%s+(%d+)%s+(%S+)%s+(%S+)')
        end
        local page = tonumber(p) or 1
        local perPage = tonumber(per) or 5
        local seasonId = season and tonumber(season) or nil
        local sortKey = sk or 'id'
        local sortDir = sd or 'DESC'
        local rows, total = FetchHistoryPage(page, perPage, sortKey, sortDir, nil, nil, seasonId)
        local lines = {}
        for i=1,#rows do
            local r = rows[i]
            table.insert(lines, table.concat({ r.id or '', r.season or '', r.seasonName or '', r.ts or '', r.winner or '', r.affix or '', r.reason or '' }, "\t"))
        end
        local tsv = table.concat(lines, '||')
        if player and player.SendBroadcastMessage then
            player:SendBroadcastMessage("[HLBG_HISTORY_TSV] TOTAL="..tostring(total or 0).."||"..tsv)
        end
        return false
    end
    if command:match('^hlbg%s+history') or command:match('^%.hlbg%s+history') then
        local c = command:gsub('^%.','')
        local p, per, season, sk, sd = c:match('^hlbg%s+history%s+(%d+)%s+(%d+)%s+(%d+)%s+(%S+)%s+(%S+)')
        if not p then
            p, per, sk, sd = c:match('^hlbg%s+history%s+(%d+)%s+(%d+)%s+(%S+)%s+(%S+)')
        end
        local page = tonumber(p) or 1
        local perPage = tonumber(per) or 5
        local seasonId = season and tonumber(season) or nil
        local sortKey = sk or 'id'
        local sortDir = sd or 'DESC'
        local rows, total = FetchHistoryPage(page, perPage, sortKey, sortDir, nil, nil, seasonId)
        local lines = {}
        for i=1,#rows do
            local r = rows[i]
            table.insert(lines, table.concat({ r.id or '', r.ts or '', r.winner or '', r.affix or '', r.reason or '' }, "\t"))
        end
        if player and player.SendBroadcastMessage then
            player:SendBroadcastMessage("[HLBG_HISTORY_TSV] TOTAL="..tostring(total or 0).."||"..table.concat(lines, '||'))
        end
        return false
    end
    -- Fallback: statsui -> broadcast compact JSON
    if command:match('^hlbg%s+statsui') or command:match('^%.hlbg%s+statsui') then
        local c = command:gsub('^%.','')
        local s = c:match('^hlbg%s+statsui%s+(%d+)')
        local season = tonumber(s)
        local stats = FetchStats(season)
        local json = json_encode(stats)
        if player and player.SendBroadcastMessage then
            player:SendBroadcastMessage("[HLBG_STATS_JSON] "..json)
        end
        return false
    end
    return true
end
RegisterPlayerEvent(42, OnCommandExtended)

    -- GM helper: broadcast a LIVE payload (rows of {name, score}) to a player for client LIVE testing
    local function BroadcastLiveToPlayer(player, rows)
        rows = rows or {}
        -- preferred: AIO Handle with table
        if okAIO and AIO and AIO.Handle then
            -- Preferred: send structured rows. We expect rows shaped as { id, ts, name, team, score }
            AIO.Handle(player, "HLBG", "Live", rows)
            -- also send a chat fallback; prefer compact JSON when safe, otherwise fall back to TSV.
            local ok, chatPayload = pcall(function()
                local j = json_encode(rows)
                if type(j) == "string" and #j <= (HLBG_Config.live_broadcast.max_chat_len or 1000) then
                    return true, j
                end
                -- JSON too large, fall back to TSV
                local lines = {}
                for i=1,#rows do
                    local r = rows[i]
                    local id = tostring(r.id or r[1] or i)
                    local ts = tostring(r.ts or r[2] or os.date("%Y-%m-%d %H:%M:%S"))
                    local n = tostring(r.name or r[3] or r[1] or "?")
                    local team = tostring(r.team or r[4] or "?")
                    local s = tostring(r.score or r[5] or r[2] or 0)
                    table.insert(lines, table.concat({ id, ts, n, team, s }, "\t"))
                end
                return false, table.concat(lines, "||")
            end)
            if player and player.SendBroadcastMessage then
                if ok and chatPayload then
                    if type(chatPayload) == "string" then
                        -- prefix JSON payload with marker so client can choose JSON path
                        if ok and chatPayload:sub(1,1) == '{' or chatPayload:sub(1,1) == '[' then
                            player:SendBroadcastMessage("[HLBG_LIVE_JSON] " .. chatPayload)
                        else
                            player:SendBroadcastMessage("[HLBG_LIVE] " .. chatPayload)
                        end
                    end
                end
            end
        else
            -- fallback: use chat-only broadcast with compact 'id:name:score' pairs
            local parts = {}
            for i=1,#rows do
                local r = rows[i]
                local id = tostring(r.id or r[1] or i)
                local n = tostring(r.name or r[3] or r[1] or "?")
                local s = tostring(r.score or r[5] or r[2] or 0)
                table.insert(parts, id .. ":" .. n .. ":" .. s)
            end
            if player and player.SendBroadcastMessage then
                player:SendBroadcastMessage("[HLBG_LIVE] " .. table.concat(parts, ";"))
            end
        end
    end

-- Collect a simple live snapshot: by default, iterate players in scope and build minimal rows
local function GetLiveRows(scope, zoneId)
    -- Prefer DB-backed latest-match snapshot (historical/post-match). If none found, fall back to scanning players.
    scope = scope or "zone"
    zoneId = tonumber(zoneId) or HLBG_Config.live_broadcast.zoneId

    -- Try to query the latest entry for the zone (if zone_id exists in table)
    local haveZone = hasColumn('dc_hlbg_winner_history','zone_id')
    local haveScoreA = hasColumn('dc_hlbg_winner_history','score_alliance')
    local haveScoreH = hasColumn('dc_hlbg_winner_history','score_horde')
    if haveZone and haveScoreA and haveScoreH then
        local sql = string.format("SELECT id, occurred_at, score_alliance, score_horde, zone_id FROM dc_hlbg_winner_history WHERE zone_id = %d ORDER BY occurred_at DESC LIMIT 1", tonumber(zoneId) or 0)
        local res = safeQuery(CharDBQuery, sql)
        if res and res:NextRow() then
        -- found a recorded match; build two per-team rows (Alliance/Horde)
        local id = tostring(res:GetUInt64(0) or 0)
        local ts = res:GetString(1) or os.date("%Y-%m-%d %H:%M:%S")
        local sa = res:IsNull(2) and 0 or res:GetUInt32(2)
        local sh = res:IsNull(3) and 0 or res:GetUInt32(3)
        -- Create compact rows matching the expected client shape: { id, ts, name, team, score }
        local rows = {}
        table.insert(rows, { id = id.."-A", ts = ts, name = "Alliance", team = "Alliance", score = tonumber(sa) or sa })
        table.insert(rows, { id = id.."-H", ts = ts, name = "Horde", team = "Horde", score = tonumber(sh) or sh })
        return rows
        end
    end

    -- Fallback: iterate players in scope and provide placeholder per-player rows (score unknown)
    local rows = {}
    local players = {}
    if scope == "world" then
        players = GetPlayersInWorld() or {}
    else
        local all = GetPlayersInWorld() or {}
        for _,p in ipairs(all) do
            local ok, zid = pcall(function() return p:GetZoneId() end)
            if ok and tonumber(zid) == zoneId then table.insert(players, p) end
        end
    end
    for i,p in ipairs(players) do
        local ok, name = pcall(function() return p:GetName() end)
        local ok2, team = pcall(function() return p:GetTeam() end)
        local tname = (ok2 and team == 0 and "Alliance") or (ok2 and team == 1 and "Horde") or "?"
        table.insert(rows, { id = tostring(i), ts = os.date("%Y-%m-%d %H:%M:%S"), name = tostring(name or "?"), team = tname, score = 0 })
    end
    return rows
end

-- Periodic broadcaster setup using CreateLuaEvent (ms interval)
if HLBG_Config.live_broadcast.enabled then
    local ms = math.max(1000, (HLBG_Config.live_broadcast.interval or 30) * 1000)
    CreateLuaEvent(function(e)
        local rows = GetLiveRows(HLBG_Config.live_broadcast.scope, HLBG_Config.live_broadcast.zoneId)
        -- broadcast to all players in scope
        if HLBG_Config.live_broadcast.scope == "world" then
            for _,pl in ipairs(GetPlayersInWorld() or {}) do pcall(function() BroadcastLiveToPlayer(pl, rows) end) end
        else
            for _,pl in ipairs(GetPlayersInWorld() or {}) do
                local ok, zid = pcall(function() return pl:GetZoneId() end)
                if ok and tonumber(zid) == (HLBG_Config.live_broadcast.zoneId or 47) then
                    pcall(function() BroadcastLiveToPlayer(pl, rows) end)
                end
            end
        end
    end, ms, 0)
    print(string.format("[HLBG_AIO] Periodic live broadcaster enabled (interval=%ds, scope=%s, zone=%s)", HLBG_Config.live_broadcast.interval or 30, HLBG_Config.live_broadcast.scope or "zone", tostring(HLBG_Config.live_broadcast.zoneId)))
end

    -- Extend OnCommandExtended to support .hlbglive for quick broadcasting
    local function OnCommandLive(event, player, command)
        if command == "hlbglive" or command == ".hlbglive" then
            print("[HLBG_AIO] OnCommand received live request: "..tostring(command))
            local now = os.date("%Y-%m-%d %H:%M:%S")
            local rows = {
                { id = "1", ts = now, name = tostring(player and player:GetName() or "GM"), team = "Alliance", score = 0 },
                { id = "2", ts = now, name = "TestPlayerA", team = "Alliance", score = 120 },
                { id = "3", ts = now, name = "TestPlayerB", team = "Horde", score = 80 },
            }
            BroadcastLiveToPlayer(player, rows)
            return false
        end
        return true
    end
    RegisterPlayerEvent(42, OnCommandLive)

-- GM/status control commands
local function OnCommandState(event, player, command)
    -- Trim leading dot
    local cmd = command:gsub("^%.", "")
    if cmd:match("^hlbgwarmup") then
        local secs = tonumber(cmd:match("hlbgwarmup%s+(%d+)") or "") or 120
        local aff = tonumber(cmd:match("affix=(%d+)") or "") or HLBG_State.affix or 0
        StartWarmup(secs, aff)
        player:SendBroadcastMessage(string.format("HLBG: warmup %ds affix=%d", secs, aff))
        return false
    elseif cmd:match("^hlbgstart") then
        local secs = tonumber(cmd:match("hlbgstart%s+(%d+)") or "") or 900
        local aff = tonumber(cmd:match("affix=(%d+)") or "") or HLBG_State.affix or 0
        StartMatch(secs, aff)
        player:SendBroadcastMessage(string.format("HLBG: match started %ds affix=%d", secs, aff))
        return false
    elseif cmd:match("^hlbgstatus") then
        BroadcastStatus(player)
        return false
    elseif cmd:match("^hlbgreset") then
        ResetMatch()
        player:SendBroadcastMessage("HLBG: match reset")
        return false
    elseif cmd:match("^hlbgq%s+join") then
        local team, pos, size = joinQueue(player)
        SendQueueMessage(player, "joined", { team = team, pos = pos, size = size, eta = secondsRemaining() })
        return false
    elseif cmd:match("^hlbgq%s+leave") then
        local team, size = leaveQueue(player)
        SendQueueMessage(player, "left", { team = team, size = size })
        return false
    elseif cmd:match("^hlbgq") then
        local team, pos, size = queuePosition(player)
        SendQueueMessage(player, "status", { team = team or "?", pos = pos or 0, size = size or 0, eta = secondsRemaining() })
        return false
    end
end
RegisterPlayerEvent(42, OnCommandState)
