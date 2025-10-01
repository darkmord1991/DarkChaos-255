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
            -- Return named-field rows to avoid transport shape ambiguity on clients
            -- { id = <string>, ts = <string>, winner = <string>, affix = <string>, reason = <string> }
            table.insert(rows, { id = tostring(id), ts = ts, winner = winner, affix = tostring(affix), reason = reason or "-" })
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
            -- DEBUG: also send a short plain chat broadcast to the player with a TSV sample so clients
            -- that don't decode AIO properly still receive a visible sample for debugging.
            local ok, err = pcall(function()
                if player and player.SendBroadcastMessage then
                    local sample = (tsv and #tsv>200) and tsv:sub(1,200) or tsv
                    player:SendBroadcastMessage("[HLBG_DBG_TSV] "..tostring(sample or ""))
                end
            end)
            -- Debug ping to confirm client receive path
            AIO.Handle(player, "HLBG", "PONG")
            -- Lightweight debug string (avoid large tables) so client can confirm receipt
            AIO.Handle(player, "HLBG", "DBG", string.format("HISTORY_N=%d TOTAL=%s", rows and #rows or 0, tostring(total)))
        end
    elseif what == "STATS" then
        local stats = FetchStats()
        if okAIO and AIO and AIO.Handle then
            AIO.Handle(player, "HLBG", "Stats", stats)
            -- Debug ping to confirm client receive path
            AIO.Handle(player, "HLBG", "PONG")
            AIO.Handle(player, "HLBG", "DBG", "STATS_OK")
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
            -- create a flush timer once
            if not __hlbg_log_flush_timer then
                __hlbg_log_flush_timer = CreateFrame("Frame")
                __hlbg_log_flush_timer._elapsed = 0
                local flushInterval = 2.0 -- seconds
                __hlbg_log_flush_timer:SetScript("OnUpdate", function(self, elapsed)
                    self._elapsed = self._elapsed + (elapsed or 0)
                    if self._elapsed < flushInterval then return end
                    self._elapsed = 0
                    if not __hlbg_log_buffer or #__hlbg_log_buffer == 0 then return end
                    -- swap buffers to minimise time holding the active buffer
                    local toWrite = __hlbg_log_buffer
                    __hlbg_log_buffer = {}
                    -- write all queued lines in one open/close
                    local logPath = "/home/wowcore/azeroth-server/logs/hlbg_client.log"
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
                end)
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
        player:SendBroadcastMessage("[HLBG_DUMP] "..(tsv or ""))
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
                    player:SendBroadcastMessage("[HLBG_DUMP] "..tostring(safeTSV))
                end
            AIO.Handle(player, "HLBG", "PONG")
            print("[HLBG_AIO] Sent test HISTORY array to player")
        else
            player:SendBroadcastMessage("HLBG: test payload prepared but AIO unavailable")
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
    local sql = string.format("SELECT id, occurred_at, score_alliance, score_horde, zone_id FROM hlbg_winner_history WHERE zone_id = %d ORDER BY occurred_at DESC LIMIT 1", tonumber(zoneId) or 0)
    local res = safeQuery(CharDBQuery, sql)
    if res then
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
