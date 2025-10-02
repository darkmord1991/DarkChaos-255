-- HLBG_UI.lua
local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

-- Live rendering
if not HLBG.Live then
function HLBG.Live(rows)
    if not HLBG._ensureUI('Live') then return end
    rows = rows or {}
    for i=1,#HLBG.UI.Live.rows do HLBG.UI.Live.rows[i]:Hide() end
    HLBG.UI.Live.lastRows = rows
    HinterlandAffixHUD_LastLive = HinterlandAffixHUD_LastLive or {}
    HinterlandAffixHUD_LastLive.ts = time()
    HinterlandAffixHUD_LastLive.rows = rows
    -- Visual flash
    pcall(function()
        if HLBG.UI and HLBG.UI.Frame and HLBG.UI.Frame:IsShown() then
            if not HLBG.UI.Frame._hlbgFlash then
                local f = HLBG.UI.Frame:CreateTexture(nil, 'OVERLAY')
                f:SetAllPoints(HLBG.UI.Frame)
                f:SetTexture('Interface/Tooltips/UI-Tooltip-Background')
                f:SetVertexColor(1,1,0.3,0.0)
                HLBG.UI.Frame._hlbgFlash = f
            end
            local tex = HLBG.UI.Frame._hlbgFlash
            tex:SetAlpha(0.6)
            local t = 0
            HLBG.UI.Frame._hlbgFlashTimer = HLBG.UI.Frame._hlbgFlashTimer or CreateFrame('Frame')
            local timer = HLBG.UI.Frame._hlbgFlashTimer
            timer:SetScript('OnUpdate', function(self, elapsed)
                t = t + (elapsed or 0)
                local a = math.max(0, 0.6 - (t * 1.0))
                tex:SetAlpha(a)
                if t > 0.6 then tex:SetAlpha(0); self:SetScript('OnUpdate', nil); t = 0 end
            end)
            if type(PlaySound) == 'function' then pcall(function() PlaySound('RaidWarning', 'MASTER') end) end
        end
    end)
    local sk = HLBG.UI.Live.sortKey or "score"
    local sd = HLBG.UI.Live.sortDir or "DESC"
    local sorted = {}
    for i,v in ipairs(rows) do table.insert(sorted, v) end
    if sk == "score" then
        table.sort(sorted, function(a,b)
            local ax = tonumber(a.score or a[5] or a[2]) or 0
            local bx = tonumber(b.score or b[5] or b[2]) or 0
            if sd == "ASC" then return ax < bx else return ax > bx end
        end)
    elseif sk == "hk" then
        table.sort(sorted, function(a,b)
            local ax = tonumber(a.hk or a[6] or 0) or 0
            local bx = tonumber(b.hk or b[6] or 0) or 0
            if sd == "ASC" then return ax < bx else return ax > bx end
        end)
    elseif sk == "name" then
        table.sort(sorted, function(a,b)
            local an = tostring(a.name or a[3] or a[1] or "")
            local bn = tostring(b.name or b[3] or b[1] or "")
            if sd == "ASC" then return an < bn else return an > bn end
        end)
    else
        sorted = rows
    end
    local y = -4
    for i,row in ipairs(sorted) do
        local r = HLBG.UI.Live.rows[i]
        if not r then
            -- lazily create row if missing
            r = CreateFrame("Frame", nil, HLBG.UI.Live.Content)
            if r.SetFrameStrata then r:SetFrameStrata("DIALOG") end
            r:SetSize(440, 28)
            r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            r.score = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            r.meta = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            r.ts = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            r.name:SetPoint("TOPLEFT", r, "TOPLEFT", 2, -2)
            r.name:SetWidth(300); HLBG.safeSetJustify(r.name, "LEFT")
            r.score:SetPoint("TOPRIGHT", r, "TOPRIGHT", -2, -2)
            r.score:SetWidth(100); HLBG.safeSetJustify(r.score, "RIGHT")
            r.meta:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 2, 2)
            r.meta:SetWidth(220); HLBG.safeSetJustify(r.meta, "LEFT")
            r.ts:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", -2, 2)
            r.ts:SetWidth(200); HLBG.safeSetJustify(r.ts, "RIGHT")
            HLBG.UI.Live.rows[i] = r
        end
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", HLBG.UI.Live.Content, "TOPLEFT", 0, y)
        local name = row.name or row[3] or row[1] or "?"
        local score = row.score or row[5] or row[2] or 0
        local hk = tonumber(row.hk or row.HK or row[6]) or 0
        local cls = tonumber(row[7] or row.class or row.Class) or nil
        local subgroup = (type(row.subgroup) ~= 'nil' and tonumber(row.subgroup)) or nil
        local team = tostring(row.team or row.Team or "")
        r.name:SetText(tostring(name))
        r.score:SetText(tostring(score))
        local parts = {}
        if team ~= '' then table.insert(parts, team) end
        table.insert(parts, string.format('HK:+%d', math.max(0, hk)))
        if cls then table.insert(parts, 'Class:'..tostring(cls)) end
        if subgroup and subgroup >= 0 then table.insert(parts, 'Group:'..tostring(subgroup)) end
        r.meta:SetText(table.concat(parts, '  '))
        if not r._hlbgHover then
            r._hlbgHover = true
            r:SetScript('OnEnter', function(self) self:SetBackdrop({ bgFile = 'Interface/Tooltips/UI-Tooltip-Background' }); self:SetBackdropColor(1,1,0.4,0.10) end)
            r:SetScript('OnLeave', function(self) self:SetBackdrop(nil) end)
        end
        r:Show()
        y = y - 18
    end
    local newH = math.max(300, 8 + #rows * 18)
    HLBG.UI.Live.Content:SetHeight(newH)
    if HLBG.UI.Live.Scroll and HLBG.UI.Live.Scroll.SetVerticalScroll then HLBG.UI.Live.Scroll:SetVerticalScroll(0) end
end
end

-- Ensure live header helper
local function ensureLiveHeader()
    if HLBG.UI.Live.Header then return end
    HLBG.UI.Live.Header = CreateFrame("Frame", nil, HLBG.UI.Live)
    HLBG.UI.Live.Header:SetPoint("TOPLEFT", 16, -40)
    HLBG.UI.Live.Header:SetSize(460, 18)
    HLBG.UI.Live.Header.Name = HLBG.UI.Live.Header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    HLBG.UI.Live.Header.Name:SetPoint("LEFT", HLBG.UI.Live.Header, "LEFT", 2, 0)
    HLBG.UI.Live.Header.Name:SetText("Players")
    HLBG.UI.Live.Header.HK = HLBG.UI.Live.Header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    HLBG.UI.Live.Header.HK:SetPoint("CENTER", HLBG.UI.Live.Header, "CENTER", 0, 0)
    HLBG.UI.Live.Header.HK:SetText("HK")
    HLBG.UI.Live.Header.Score = HLBG.UI.Live.Header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    HLBG.UI.Live.Header.Score:SetPoint("RIGHT", HLBG.UI.Live.Header, "RIGHT", -2, 0)
    HLBG.UI.Live.Header.Score:SetText("Score")
    HLBG.UI.Live.Header.Totals = HLBG.UI.Live.Header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    HLBG.UI.Live.Header.Totals:SetPoint("TOPLEFT", HLBG.UI.Live.Header, "BOTTOMLEFT", 0, -2)
    local btnName = CreateFrame("Button", nil, HLBG.UI.Live.Header)
    btnName:SetAllPoints(HLBG.UI.Live.Header.Name)
    btnName:SetScript("OnClick", function()
        HLBG.UI.Live.sortKey = "name"
        HLBG.UI.Live.sortDir = (HLBG.UI.Live.sortKey == "name" and (HLBG.UI.Live.sortDir == "ASC" and "DESC" or "ASC") ) or "DESC"
        if HLBG.UI.Live.lastRows then HLBG.Live(HLBG.UI.Live.lastRows) end
    end)
    local btnHK = CreateFrame("Button", nil, HLBG.UI.Live.Header)
    btnHK:SetAllPoints(HLBG.UI.Live.Header.HK)
    btnHK:SetScript("OnClick", function()
        HLBG.UI.Live.sortKey = "hk"
        HLBG.UI.Live.sortDir = (HLBG.UI.Live.sortKey == "hk" and (HLBG.UI.Live.sortDir == "ASC" and "DESC" or "ASC") ) or "DESC"
        if HLBG.UI.Live.lastRows then HLBG.Live(HLBG.UI.Live.lastRows) end
    end)
    local btnScore = CreateFrame("Button", nil, HLBG.UI.Live.Header)
    btnScore:SetAllPoints(HLBG.UI.Live.Header.Score)
    btnScore:SetScript("OnClick", function()
        HLBG.UI.Live.sortKey = "score"
        HLBG.UI.Live.sortDir = (HLBG.UI.Live.sortKey == "score" and (HLBG.UI.Live.sortDir == "ASC" and "DESC" or "ASC") ) or "DESC"
        if HLBG.UI.Live.lastRows then HLBG.Live(HLBG.UI.Live.lastRows) end
    end)
end

local function UpdateLiveHeader()
    if not HLBG.UI.Live.Header then return end
    HLBG.UI.Live.Header.Totals:SetText(string.format("Alliance: %d   Horde: %d", RES.A or 0, RES.H or 0))
end

-- Fake live data command
if HLBG._devMode then
    local function hlbglivefake_handler()
        local fake = {
            {name = UnitName("player"), score = RES.A or 0},
            {name = "PlayerA", score = 120},
            {name = "PlayerB", score = 80},
        }
        HLBG.Live(fake)
        if HLBG.UI and HLBG.UI.Frame and HLBG.UI.Frame.Show then HLBG.UI.Frame:Show() end
        ShowTab(1)
    end
    if type(HLBG.safeRegisterSlash) == 'function' then
        HLBG.safeRegisterSlash('HLBGLIVEFAKE', '/hlbglivefake', function() hlbglivefake_handler() end)
    else
        SLASH_HLBGLIVEFAKE1 = "/hlbglivefake"
        SlashCmdList["HLBGLIVEFAKE"] = hlbglivefake_handler
    end
end

-- History rendering and TSV parser
if not HLBG.History then
function HLBG.History(a, b, c, d, e, f, g)
    if not HLBG._ensureUI('History') then return end
    local rows, page, per, total, col, dir
    local function looksLikeRows(v)
        if type(v) ~= "table" then return false end
        if #v and #v > 0 then return true end
        if v.id or v.ts or v.timestamp or v.winner or v.affix or v.reason then return true end
        return false
    end
    if looksLikeRows(a) then
        rows, page, per, total, col, dir = a, b, c, d, e, f
    elseif looksLikeRows(b) then
        rows, page, per, total, col, dir = b, c, d, e, f, g
    else
        rows, page, per, total, col, dir = b, c, d, e, f, g
    end
    if type(rows) ~= "table" then
        local tsv = nil
        if type(a) == "string" and a:find("\t") then tsv = a end
        if not tsv and type(b) == "string" and b:find("\t") then tsv = b end
        if tsv and type(HLBG.HistoryStr) == "function" then
            return HLBG.HistoryStr(a,b,c,d,e,f,g)
        end
        rows = {}
    end
    HLBG.UI.History.page = page or HLBG.UI.History.page or 1
    HLBG.UI.History.per = per or HLBG.UI.History.per or 25
    HLBG.UI.History.total = total or HLBG.UI.History.total or 0
    HLBG.UI.History.sortKey = col or HLBG.UI.History.sortKey or "id"
    HLBG.UI.History.sortDir = dir or HLBG.UI.History.sortDir or "DESC"
    local normalized = {}
    if type(rows) == "table" then
        if #rows and #rows > 0 then
            normalized = rows
        else
            local tmp = {}
            for k,v in pairs(rows) do
                if type(v) == "table" then
                    local nk = tonumber(k)
                    if nk then tmp[nk] = v else table.insert(tmp, v) end
                end
            end
            local hasNumeric = false
            for k,_ in pairs(tmp) do if type(k) == "number" then hasNumeric = true; break end end
            if hasNumeric then local i = 1; while tmp[i] do table.insert(normalized, tmp[i]); i=i+1 end else for _,v in ipairs(tmp) do table.insert(normalized, v) end end
        end
    end
    if #normalized == 0 and type(rows) == "table" then
        if type(rows.id) ~= "nil" or type(rows.ts) ~= "nil" then table.insert(normalized, rows) end
    end
    rows = normalized
    if not HinterlandAffixHUD_DebugLog then HinterlandAffixHUD_DebugLog = {} end
    HLBG.UI.History.lastRows = rows
    local sample = ""
    if #rows > 0 and type(rows[1]) == 'table' then
        local r = rows[1]
        local id = tostring(r[1] or r.id or "")
        local ts = tostring(r[2] or r.ts or "")
        local win = tostring(r[3] or r.winner or "")
        sample = string.format("%s\t%s\t%s\t%s", id, ts, win, tostring(r[4] or r.affix or ""))
    end
    table.insert(HinterlandAffixHUD_DebugLog, 1, string.format("[%s] HISTORY N=%d sample=%s", date("%Y-%m-%d %H:%M:%S"), #rows, sample))
    while #HinterlandAffixHUD_DebugLog > 200 do table.remove(HinterlandAffixHUD_DebugLog) end
    -- forward a compact sample to server-side log if available
    local okSend = pcall(function() return _G.HLBG_SendClientLog end)
    local send = (okSend and type(_G.HLBG_SendClientLog) == "function") and _G.HLBG_SendClientLog or ((type(HLBG) == "table" and type(HLBG.SendClientLog) == "function") and HLBG.SendClientLog or nil)
    if send then
        local sample2 = sample
        pcall(function() send(string.format("HISTORY_CLIENT N=%d sample=%s", #rows, sample2)) end)
    end
    if HLBG.UI and HLBG.UI.Frame then HLBG.UI.Frame:Show(); ShowTab(2) end
    if HLBG.UI and HLBG.UI.History and HLBG.UI.History.Content then HLBG.UI.History.Content:Show() end
    if HLBG.UI and HLBG.UI.History and HLBG.UI.History.Scroll then HLBG.UI.History.Scroll:SetVerticalScroll(0) end
    -- render rows (simplified)
    local function getRow(i)
        local r = HLBG.UI.History.rows[i]
        if not r then
            r = CreateFrame("Frame", nil, HLBG.UI.History.Content)
            if r.SetFrameStrata then r:SetFrameStrata("DIALOG") end
            r:SetSize(420, 14)
            r.id = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.sea = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.ts = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.win = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.aff = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.rea = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.id:SetPoint("LEFT", r, "LEFT", 0, 0); r.id:SetWidth(50); HLBG.safeSetJustify(r.id, "LEFT")
            r.sea:SetPoint("LEFT", r.id, "RIGHT", 6, 0); r.sea:SetWidth(50)
            r.ts:SetPoint("LEFT", r.sea, "RIGHT", 6, 0); r.ts:SetWidth(120)
            r.win:SetPoint("LEFT", r.ts, "RIGHT", 6, 0); r.win:SetWidth(80)
            r.aff:SetPoint("LEFT", r.win, "RIGHT", 6, 0); r.aff:SetWidth(70)
            r.rea:SetPoint("LEFT", r.aff, "RIGHT", 6, 0); r.rea:SetWidth(50)
            HLBG.UI.History.rows[i] = r
        end
        return r
    end
    for i=1,#HLBG.UI.History.rows do HLBG.UI.History.rows[i]:Hide() end
    local y = -22; local hadRows = false
    for i, row in ipairs(rows) do
        local r = getRow(i)
        r:ClearAllPoints(); r:SetPoint("TOPLEFT", HLBG.UI.History.Content, "TOPLEFT", 0, y)
        local id = row.id or row[1]
        local sea = row.season
        local sname = row.seasonName or row.sname or nil
        local compact_len = (type(row) == 'table' and #row) or 0
        local ts, win, affix, reas
        if compact_len >= 5 then ts,row3,win,affix,reas = row[2],row[3],row[3],row[4],row[5] end
        r.id:SetText(tostring(id or ""))
        r.sea:SetText(tostring(sname or sea or ""))
        r.ts:SetText(ts or row.ts or "")
        r.win:SetText(win or row.winner or "")
        r.aff:SetText(HLBG.GetAffixName(affix or row.affix))
        r.rea:SetText(reas or row.reason or "-")
        if not r._hlbgHover then r._hlbgHover = true; r:SetScript('OnEnter', function(self) self:SetBackdrop({ bgFile = 'Interface/Tooltips/UI-Tooltip-Background' }); self:SetBackdropColor(1,1,0.4,0.10) end); r:SetScript('OnLeave', function(self) self:SetBackdrop(nil) end) end
        r:Show(); y = y - 14; hadRows = true
    end
    local maxPage = (HLBG.UI.History.total and HLBG.UI.History.total > 0) and math.max(1, math.ceil(HLBG.UI.History.total/(HLBG.UI.History.per or 25))) or (HLBG.UI.History.page or 1)
    HLBG.UI.History.Nav.PageText:SetText(string.format("Page %d / %d", HLBG.UI.History.page, maxPage))
    HLBG.UI.History.Nav.Prev:SetEnabled((HLBG.UI.History.page or 1) > 1)
    HLBG.UI.History.Nav.Next:SetEnabled((HLBG.UI.History.page or 1) < maxPage)
    local visibleCount = (type(rows) == "table" and #rows) or 0
    local newH = math.max(300, 22 + visibleCount * 14 + 8)
    HLBG.UI.History.Content:SetHeight(newH)
    if HLBG.UI.History.Scroll and HLBG.UI.History.Scroll.SetVerticalScroll then HLBG.UI.History.Scroll:SetVerticalScroll(0) end
    if HLBG.UI.History.EmptyText then if hadRows then HLBG.UI.History.EmptyText:Hide() else HLBG.UI.History.EmptyText:Show() end end
end
end

if not HLBG.HistoryStr then
function HLBG.HistoryStr(a, b, c, d, e, f, g)
    if not HLBG._ensureUI('HistoryStr') then return end
    local tsv, page, per, total, col, dir
    if type(a) == "string" then tsv, page, per, total, col, dir = a, b, c, d, e, f else tsv, page, per, total, col, dir = b, c, d, e, f, g end
    local rows = {}
    local reportedTotal = tonumber(total or 0) or 0
    if type(tsv) == "string" and tsv ~= "" then
        -- Allow a leading meta like: TOTAL=123||<rows...>
        local meta = tsv:match("^TOTAL=(%d+)%s*%|%|")
        if meta then
            reportedTotal = tonumber(meta) or reportedTotal
            tsv = tsv:gsub("^TOTAL=%d+%s*%|%|", "")
        end
        for line in tsv:gmatch("[^\n]+") do
            local id7, season7, sname7, ts7, win7, aff7, rea7 = string.match(line, "^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)$")
            if id7 and ts7 and win7 and aff7 and rea7 then
                table.insert(rows, { id = id7 or "", season = tonumber(season7) or season7, seasonName = sname7, ts = ts7 or "", winner = win7 or "", affix = aff7 or "", reason = rea7 or "" })
            else
                local id, season, ts, win, aff, rea = string.match(line, "^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)$")
                if id and ts and win and aff and rea then
                    table.insert(rows, { id = id or "", season = tonumber(season) or season, ts = ts or "", winner = win or "", affix = aff or "", reason = rea or "" })
                else
                    local lid, lts, lwin, laff, lrea = string.match(line, "^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)$")
                    if lid then table.insert(rows, { id = lid or "", ts = lts or "", winner = lwin or "", affix = laff or "", reason = lrea or "" }) end
                end
            end
        end
    end
    return HLBG.History(rows, page, per, reportedTotal, col, dir)
end
end

if not HLBG.Stats then
function HLBG.Stats(player, stats)
    if not HLBG._ensureUI('Stats') then return end
    if type(player) ~= "string" and type(player) ~= "userdata" then stats = player end
    stats = stats or {}
    HLBG._lastStats = stats
    local delay = 0.15
    local pending = HLBG.UI.Stats
    pending._pendingStats = stats; pending._pending = true
    if not pending._timer then
        pending._timer = CreateFrame("Frame"); pending._timer._elapsed = 0
        pending._timer:SetScript("OnUpdate", function(self, elapsed)
            pending._timer._elapsed = pending._timer._elapsed + (elapsed or 0)
            if pending._timer._elapsed < delay then return end
            pending._timer._elapsed = 0
            self:SetScript("OnUpdate", nil)
            pending._pending = false
            local s = pending._pendingStats or {}
            local counts = s.counts or {}
            local a = (counts["Alliance"] or counts["ALLIANCE"] or 0)
            local h = (counts["Horde"] or counts["HORDE"] or 0)
            local d = s.draws or 0
            local ssz = tonumber(s.season or s.Season or 0) or 0
            local sname = s.seasonName or s.SeasonName
            local seasonStr
            if sname and sname ~= "" then seasonStr = "  Season: "..tostring(sname) elseif ssz and ssz > 0 then seasonStr = "  Season: "..tostring(ssz) else seasonStr = "" end
            local lines = { string.format("Alliance: %d  Horde: %d  Draws: %d  Avg: %d min%s", a, h, d, math.floor((s.avgDuration or 0)/60), seasonStr) }
            local safeGetAffix = HLBG.GetAffixName
            local function top3Flexible(v)
                local items = {}
                if type(v) == 'table' then
                    if #v > 0 then
                        for i=1,#v do
                            local row = v[i]
                            local total = (tonumber(row.Alliance or row.alliance or row.A or 0) or 0) + (tonumber(row.Horde or row.horde or row.H or 0) or 0) + (tonumber(row.DRAW or row.draw or row.D or 0) or 0)
                            local label = row.weather or (row.affix and safeGetAffix(row.affix)) or tostring(i)
                            table.insert(items, {label=label, total=total})
                        end
                    else
                        for k,row in pairs(v) do
                            local total = (tonumber(row.Alliance or 0) or 0) + (tonumber(row.Horde or 0) or 0) + (tonumber(row.DRAW or 0) or 0)
                            table.insert(items, {label=tostring(k), total=total})
                        end
                    end
                end
                table.sort(items, function(a,b) return a.total > b.total end)
                local out = {}
                for i=1,math.min(3,#items) do table.insert(out, string.format("%s:%d", items[i].label, items[i].total)) end
                return table.concat(out, ", ")
            end
            if s.byAffix and next(s.byAffix) then table.insert(lines, "Top Affixes: "..top3Flexible(s.byAffix)) end
            if s.byWeather and next(s.byWeather) then table.insert(lines, "Top Weather: "..top3Flexible(s.byWeather)) end
            local function top3avg(map)
                local arr = {}
                for k,v in pairs(map or {}) do table.insert(arr, {k=k, v=tonumber(v.avg or 0)}) end
                table.sort(arr, function(x,y) return x.v>y.v end)
                local out = {}
                for i=1,math.min(3,#arr) do table.insert(out, string.format("%s:%d min", arr[i].k, math.floor((arr[i].v or 0)/60))) end
                return table.concat(out, ", ")
            end
            if s.affixDur and next(s.affixDur) then table.insert(lines, "Slowest Affixes (avg): "..top3avg(s.affixDur)) end
            if s.weatherDur and next(s.weatherDur) then table.insert(lines, "Slowest Weather (avg): "..top3avg(s.weatherDur)) end
            if HLBG.UI and HLBG.UI.Stats and HLBG.UI.Stats.Text then HLBG.UI.Stats.Text:SetText(table.concat(lines, "\n")) end
        end)
    else
        pending._timer._elapsed = 0
        pending._timer:SetScript("OnUpdate", pending._timer:GetScript("OnUpdate"))
    end
end
end


-- UI construction extracted from the main client file to keep the addon modular.
HLBG.UI = HLBG.UI or {}

-- Main window inside PvP frame
HLBG.UI.Frame = CreateFrame("Frame", "HLBG_Main", PVPParentFrame or PVPFrame)
HLBG.UI.Frame:SetSize(512, 350)
HLBG.UI.Frame:Hide()
-- Ensure our panel stays above world overlays on 3.3.5
if HLBG.UI.Frame.SetFrameStrata then HLBG.UI.Frame:SetFrameStrata("DIALOG") end
HLBG.UI.Frame:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left=4, right=4, top=4, bottom=4 } })
HLBG.UI.Frame:SetBackdropColor(0,0,0,0.5)
HLBG.UI.Frame:ClearAllPoints()
HLBG.UI.Frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
HLBG.UI.Frame:EnableMouse(true)
HLBG.UI.Frame:SetMovable(true)
HLBG.UI.Frame:RegisterForDrag("LeftButton")
HLBG.UI.Frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
HLBG.UI.Frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, rel, rp, x, y = self:GetPoint()
    HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
    HinterlandAffixHUDDB.hlbgMainPos = { point = p, rel = rel and rel:GetName() or "UIParent", relPoint = rp, x = x, y = y }
end)
-- Reapply saved position if present
do
    HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
    local pos = HinterlandAffixHUDDB.hlbgMainPos
    if pos and pos.point and pos.rel and pos.relPoint and _G[pos.rel] then
        HLBG.UI.Frame:ClearAllPoints()
        HLBG.UI.Frame:SetPoint(pos.point, _G[pos.rel], pos.relPoint, pos.x or 0, pos.y or 0)
    end
end
-- Close button instead of hooking UIParent OnKeyDown (not reliable on 3.3.5)
local close = CreateFrame("Button", nil, HLBG.UI.Frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", HLBG.UI.Frame, "TOPRIGHT", 0, 0)
-- Allow closing with ESC
if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, HLBG.UI.Frame:GetName()) end

HLBG.UI.Frame.Title = HLBG.UI.Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
HLBG.UI.Frame.Title:SetPoint("TOPLEFT", 16, -12)
HLBG.UI.Frame.Title:SetText("Hinterland Battleground")

-- Tabs inside window: Live / History / Stats
HLBG.UI.Tabs = {}
HLBG.UI.Tabs[1] = CreateFrame("Button", HLBG.UI.Frame:GetName().."Tab1", HLBG.UI.Frame, "OptionsFrameTabButtonTemplate")
HLBG.UI.Tabs[1]:SetPoint("TOPLEFT", HLBG.UI.Frame, "BOTTOMLEFT", 10, 7)
HLBG.UI.Tabs[1]:SetText("Live")
HLBG.UI.Tabs[1]:SetScript("OnClick", function() if type(ShowTab) == 'function' then ShowTab(1) end end)
HLBG.UI.Tabs[2] = CreateFrame("Button", HLBG.UI.Frame:GetName().."Tab2", HLBG.UI.Frame, "OptionsFrameTabButtonTemplate")
HLBG.UI.Tabs[2]:SetPoint("LEFT", HLBG.UI.Tabs[1], "RIGHT")
HLBG.UI.Tabs[2]:SetText("History")
HLBG.UI.Tabs[2]:SetScript("OnClick", function() if type(ShowTab) == 'function' then ShowTab(2) end end)
HLBG.UI.Tabs[3] = CreateFrame("Button", HLBG.UI.Frame:GetName().."Tab3", HLBG.UI.Frame, "OptionsFrameTabButtonTemplate")
HLBG.UI.Tabs[3]:SetPoint("LEFT", HLBG.UI.Tabs[2], "RIGHT")
HLBG.UI.Tabs[3]:SetText("Stats")
HLBG.UI.Tabs[3]:SetScript("OnClick", function() if type(ShowTab) == 'function' then ShowTab(3) end end)

-- New tabs: Queue (join next run), Info (overview), Results (post-match)
HLBG.UI.Tabs[4] = CreateFrame("Button", HLBG.UI.Frame:GetName().."Tab4", HLBG.UI.Frame, "OptionsFrameTabButtonTemplate")
HLBG.UI.Tabs[4]:SetPoint("LEFT", HLBG.UI.Tabs[3], "RIGHT")
HLBG.UI.Tabs[4]:SetText("Queue")
HLBG.UI.Tabs[4]:SetScript("OnClick", function() if type(ShowTab) == 'function' then ShowTab(4) end end)
HLBG.UI.Tabs[5] = CreateFrame("Button", HLBG.UI.Frame:GetName().."Tab5", HLBG.UI.Frame, "OptionsFrameTabButtonTemplate")
HLBG.UI.Tabs[5]:SetPoint("LEFT", HLBG.UI.Tabs[4], "RIGHT")
HLBG.UI.Tabs[5]:SetText("Info")
HLBG.UI.Tabs[5]:SetScript("OnClick", function() if type(ShowTab) == 'function' then ShowTab(5) end end)
HLBG.UI.Tabs[6] = CreateFrame("Button", HLBG.UI.Frame:GetName().."Tab6", HLBG.UI.Frame, "OptionsFrameTabButtonTemplate")
HLBG.UI.Tabs[6]:SetPoint("LEFT", HLBG.UI.Tabs[5], "RIGHT")
HLBG.UI.Tabs[6]:SetText("Results")
HLBG.UI.Tabs[6]:SetScript("OnClick", function() if type(ShowTab) == 'function' then ShowTab(6) end end)

PanelTemplates_SetNumTabs(HLBG.UI.Frame, 6)
PanelTemplates_SetTab(HLBG.UI.Frame, 1)

function ShowTab(i)
    PanelTemplates_SetTab(HLBG.UI.Frame, i)
    if HLBG.UI.Live then if i == 1 then HLBG.UI.Live:Show() else HLBG.UI.Live:Hide() end end
    if HLBG.UI.History then if i == 2 then HLBG.UI.History:Show() else HLBG.UI.History:Hide() end end
    if HLBG.UI.Stats then if i == 3 then HLBG.UI.Stats:Show() else HLBG.UI.Stats:Hide() end end
    if HLBG.UI.Queue then if i == 4 then HLBG.UI.Queue:Show() else HLBG.UI.Queue:Hide() end end
    if HLBG.UI.Info then if i == 5 then HLBG.UI.Info:Show() else HLBG.UI.Info:Hide() end end
    if HLBG.UI.Results then if i == 6 then HLBG.UI.Results:Show() else HLBG.UI.Results:Hide() end end
    HinterlandAffixHUDDB.lastInnerTab = i
end

-- Helper: request History + Stats for current selection (season-only)
function HLBG._requestHistoryAndStats()
    local hist = HLBG.UI and HLBG.UI.History
    local p = (hist and hist.page) or 1
    local per = (hist and hist.per) or 5
    local sk = (hist and hist.sortKey) or "id"
    local sd = (hist and hist.sortDir) or "DESC"
    local season = (HLBG and HLBG._getSeason and HLBG._getSeason()) or (_G.HLBG_GetSeason and _G.HLBG_GetSeason()) or 0
    if _G.AIO and _G.AIO.Handle then
        _G.AIO.Handle("HLBG", "Request", "HISTORY", p, per, season, sk, sd)
        _G.AIO.Handle("HLBG", "History", p, per, season, sk, sd)
        _G.AIO.Handle("HLBG", "HISTORY", p, per, season, sk, sd)
        _G.AIO.Handle("HLBG", "HistoryUI", p, per, season, sk, sd)
        _G.AIO.Handle("HLBG", "Request", "STATS", season)
        _G.AIO.Handle("HLBG", "Stats", season)
        _G.AIO.Handle("HLBG", "STATS", season)
        _G.AIO.Handle("HLBG", "StatsUI", season)
    end
    local sendDot = (HLBG and HLBG.SendServerDot) or _G.HLBG_SendServerDot
    if type(sendDot) == 'function' then
        sendDot(string.format(".hlbg historyui %d %d %d %s %s", p, per, season, sk, sd))
        sendDot(string.format(".hlbg statsui %d", season))
    end
end

-- Season dropdown (top-right)
do
    local label = HLBG.UI.Frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOPRIGHT", HLBG.UI.Frame, "TOPRIGHT", -210, -16)
    label:SetText("Season:")
    local maxSeason = (HinterlandAffixHUDDB and HinterlandAffixHUDDB.maxSeason) or 10
    local function seasonList()
        local t = {0}
        for i=1,maxSeason do t[#t+1]=i end
        return t
    end
    if type(UIDropDownMenu_Initialize) == 'function' then
        local dd = CreateFrame('Frame', 'HLBG_SeasonDrop', HLBG.UI.Frame, 'UIDropDownMenuTemplate')
        dd:SetPoint('LEFT', label, 'RIGHT', -10, -4)
        local function onSelect(self, val)
            HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
            HinterlandAffixHUDDB.desiredSeason = tonumber(val) or 0
            UIDropDownMenu_SetSelectedValue(dd, HinterlandAffixHUDDB.desiredSeason)
            UIDropDownMenu_SetText(dd, (tonumber(val)==0) and 'Current' or tostring(val))
            -- reset to page 1 and request
            if HLBG.UI and HLBG.UI.History then HLBG.UI.History.page = 1 end
            HLBG._requestHistoryAndStats()
        end
        local function init()
            local cur = (HLBG and HLBG._getSeason and HLBG._getSeason()) or 0
            local info
            for _,v in ipairs(seasonList()) do
                info = UIDropDownMenu_CreateInfo()
                info.text = (v==0) and 'Current' or tostring(v)
                info.value = v
                info.func = function() onSelect(nil, v) end
                info.checked = (v == cur)
                UIDropDownMenu_AddButton(info)
            end
            UIDropDownMenu_SetSelectedValue(dd, cur)
            UIDropDownMenu_SetWidth(dd, 90)
            UIDropDownMenu_SetText(dd, (cur==0) and 'Current' or tostring(cur))
        end
        UIDropDownMenu_Initialize(dd, init)
        -- Reinitialize when frame shows in case maxSeason changed
        HLBG.UI.Frame:HookScript('OnShow', function() UIDropDownMenu_Initialize(dd, init) end)
    else
        -- Fallback: simple cycle button
        local btn = CreateFrame('Button', nil, HLBG.UI.Frame, 'UIPanelButtonTemplate')
        btn:SetSize(90, 20)
        btn:SetPoint('LEFT', label, 'RIGHT', 4, 0)
        local function setText()
            local cur = (HLBG and HLBG._getSeason and HLBG._getSeason()) or 0
            btn:SetText((cur==0) and 'Current' or ('Season '..cur))
        end
        btn:SetScript('OnClick', function()
            HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
            local cur = tonumber(HinterlandAffixHUDDB.desiredSeason or 0) or 0
            cur = cur + 1; if cur > maxSeason then cur = 0 end
            HinterlandAffixHUDDB.desiredSeason = cur
            if HLBG.UI and HLBG.UI.History then HLBG.UI.History.page = 1 end
            HLBG._requestHistoryAndStats(); setText()
        end)
        setText()
    end
end

HLBG.UI.Live = CreateFrame("Frame", nil, HLBG.UI.Frame)
HLBG.UI.Live:SetAllPoints(HLBG.UI.Frame)
HLBG.UI.Live.Text = HLBG.UI.Live:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
HLBG.UI.Live.Text:SetPoint("TOPLEFT", 16, -40)
HLBG.UI.Live.Text:SetText("Live status shows resources, timer and affix. Use the HUD on the world view.")
HLBG.UI.Live:SetScript("OnShow", function()
    if type(HLBG) == 'table' and type(HLBG.safeExecSlash) == 'function' then
        HLBG.safeExecSlash(".hlbg live players")
    elseif type(SendChatMessage) == 'function' then
        -- last resort: send to /say so server-side chat handler can pick it up
        pcall(SendChatMessage, ".hlbg live players", "SAY")
    end
end)

-- Live scoreboard: scrollable player list
HLBG.UI.Live.Scroll = CreateFrame("ScrollFrame", "HLBG_LiveScroll", HLBG.UI.Live, "UIPanelScrollFrameTemplate")
HLBG.UI.Live.Scroll:SetPoint("TOPLEFT", 16, -64)
HLBG.UI.Live.Scroll:SetPoint("BOTTOMRIGHT", -36, 40)
HLBG.UI.Live.Content = CreateFrame("Frame", nil, HLBG.UI.Live.Scroll)
HLBG.UI.Live.Content:SetSize(460, 300)
if HLBG.UI.Live.Content.SetFrameStrata then HLBG.UI.Live.Content:SetFrameStrata("DIALOG") end
HLBG.UI.Live.Scroll:SetScrollChild(HLBG.UI.Live.Content)
HLBG.UI.Live.rows = HLBG.UI.Live.rows or {}

local function liveGetRow(i)
    local r = HLBG.UI.Live.rows[i]
    if not r then
        r = CreateFrame("Frame", nil, HLBG.UI.Live.Content)
        if r.SetFrameStrata then r:SetFrameStrata("DIALOG") end
        r:SetSize(440, 28)
        r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.score = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.team = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.ts = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.name:SetPoint("LEFT", r, "LEFT", 2, 0)
        r.name:SetWidth(220)
        r.score:SetPoint("LEFT", r.name, "RIGHT", 6, 0); r.score:SetWidth(60)
        r.team:SetPoint("LEFT", r.score, "RIGHT", 6, 0); r.team:SetWidth(80)
        r.ts:SetPoint("LEFT", r.team, "RIGHT", 6, 0); r.ts:SetWidth(80)
        HLBG.UI.Live.rows[i] = r
    end
    return r
end

-- Live header click sorting helpers (created below in main UI initialization when header exists)

HLBG.UI.History = CreateFrame("Frame", nil, HLBG.UI.Frame)
HLBG.UI.History:SetAllPoints(HLBG.UI.Frame)
HLBG.UI.History:Hide()
HLBG.UI.History.Scroll = CreateFrame("ScrollFrame", "HLBG_HistoryScroll", HLBG.UI.History, "UIPanelScrollFrameTemplate")
HLBG.UI.History.Scroll:SetPoint("TOPLEFT", 16, -40)
HLBG.UI.History.Scroll:SetPoint("BOTTOMRIGHT", -36, 16)
HLBG.UI.History.Content = CreateFrame("Frame", nil, HLBG.UI.History.Scroll)
HLBG.UI.History.Content:SetSize(460, 300)
if HLBG.UI.History.Content.SetFrameStrata then HLBG.UI.History.Content:SetFrameStrata("DIALOG") end
HLBG.UI.History.Scroll:SetScrollChild(HLBG.UI.History.Content)
HLBG.UI.History.rows = HLBG.UI.History.rows or {}
-- Defaults for paging/sort
HLBG.UI.History.page = HLBG.UI.History.page or 1
HLBG.UI.History.per = HLBG.UI.History.per or 5
HLBG.UI.History.total = HLBG.UI.History.total or 0
HLBG.UI.History.sortKey = HLBG.UI.History.sortKey or "id"
HLBG.UI.History.sortDir = HLBG.UI.History.sortDir or "DESC"
HLBG.UI.History.EmptyText = HLBG.UI.History:CreateFontString(nil, "OVERLAY", "GameFontDisable")
HLBG.UI.History.EmptyText:SetPoint("TOPLEFT", 16, -64)
HLBG.UI.History.EmptyText:SetText("No data yet…")
HLBG.UI.History.EmptyText:Hide()

-- Pagination nav: Prev / Page N / Next
HLBG.UI.History.Nav = HLBG.UI.History.Nav or CreateFrame("Frame", nil, HLBG.UI.History)
HLBG.UI.History.Nav:SetPoint("BOTTOMLEFT", HLBG.UI.History, "BOTTOMLEFT", 16, 20)
HLBG.UI.History.Nav:SetSize(200, 20)
local function _btn(parent, w, txt)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, 20)
    b:SetText(txt)
    -- Some 3.3.5 skins lack SetEnabled; provide a shim
    if not b.SetEnabled then
        function b:SetEnabled(en)
            if en then if self.Enable then self:Enable() end else if self.Disable then self:Disable() end end
        end
    end
    return b
end
HLBG.UI.History.Nav.Prev = HLBG.UI.History.Nav.Prev or _btn(HLBG.UI.History.Nav, 60, "Prev")
HLBG.UI.History.Nav.Prev:ClearAllPoints()
HLBG.UI.History.Nav.Prev:SetPoint("LEFT", HLBG.UI.History.Nav, "LEFT", 0, 0)
HLBG.UI.History.Nav.PageText = HLBG.UI.History.Nav.PageText or HLBG.UI.History.Nav:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
HLBG.UI.History.Nav.PageText:ClearAllPoints()
HLBG.UI.History.Nav.PageText:SetPoint("LEFT", HLBG.UI.History.Nav.Prev, "RIGHT", 8, 0)
HLBG.UI.History.Nav.Next = HLBG.UI.History.Nav.Next or _btn(HLBG.UI.History.Nav, 60, "Next")
HLBG.UI.History.Nav.Next:ClearAllPoints()
HLBG.UI.History.Nav.Next:SetPoint("LEFT", HLBG.UI.History.Nav.PageText, "RIGHT", 8, 0)

HLBG.UI.History.Nav.Prev:SetScript("OnClick", function()
    local hist = HLBG.UI.History
    local maxPage = (hist.total and hist.total > 0) and math.max(1, math.ceil(hist.total/(hist.per or 5))) or (hist.page or 1)
    hist.page = math.max(1, (hist.page or 1) - 1)
    HLBG.UI.History.Nav.PageText:SetText(string.format("Page %d / %d", hist.page, maxPage))
    local season = (HLBG and HLBG._getSeason and HLBG._getSeason()) or (_G.HLBG_GetSeason and _G.HLBG_GetSeason()) or 0
    if _G.AIO and _G.AIO.Handle then
        _G.AIO.Handle("HLBG", "Request", "HISTORY", hist.page, hist.per or 5, season, hist.sortKey or "id", hist.sortDir or "DESC")
        _G.AIO.Handle("HLBG", "History", hist.page, hist.per or 5, season, hist.sortKey or "id", hist.sortDir or "DESC")
        _G.AIO.Handle("HLBG", "HISTORY", hist.page, hist.per or 5, season, hist.sortKey or "id", hist.sortDir or "DESC")
        _G.AIO.Handle("HLBG", "HistoryUI", hist.page, hist.per or 5, season, hist.sortKey or "id", hist.sortDir or "DESC")
    end
    do
        local sendDot = (HLBG and HLBG.SendServerDot) or _G.HLBG_SendServerDot
        if type(sendDot) == 'function' then
            sendDot(string.format(".hlbg historyui %d %d %d %s %s", hist.page, hist.per or 5, season, hist.sortKey or "id", hist.sortDir or "DESC"))
        end
    end
end)

HLBG.UI.History.Nav.Next:SetScript("OnClick", function()
    local hist = HLBG.UI.History
    local maxPage = (hist.total and hist.total > 0) and math.max(1, math.ceil(hist.total/(hist.per or 5))) or (hist.page or 1)
    hist.page = math.min(maxPage, (hist.page or 1) + 1)
    HLBG.UI.History.Nav.PageText:SetText(string.format("Page %d / %d", hist.page, maxPage))
    local season = (HLBG and HLBG._getSeason and HLBG._getSeason()) or (_G.HLBG_GetSeason and _G.HLBG_GetSeason()) or 0
    if _G.AIO and _G.AIO.Handle then
        _G.AIO.Handle("HLBG", "Request", "HISTORY", hist.page, hist.per or 5, season, hist.sortKey or "id", hist.sortDir or "DESC")
        _G.AIO.Handle("HLBG", "History", hist.page, hist.per or 5, season, hist.sortKey or "id", hist.sortDir or "DESC")
        _G.AIO.Handle("HLBG", "HISTORY", hist.page, hist.per or 5, season, hist.sortKey or "id", hist.sortDir or "DESC")
        _G.AIO.Handle("HLBG", "HistoryUI", hist.page, hist.per or 5, season, hist.sortKey or "id", hist.sortDir or "DESC")
    end
    do
        local sendDot = (HLBG and HLBG.SendServerDot) or _G.HLBG_SendServerDot
        if type(sendDot) == 'function' then
            sendDot(string.format(".hlbg historyui %d %d %d %s %s", hist.page, hist.per or 5, season, hist.sortKey or "id", hist.sortDir or "DESC"))
        end
    end
end)

HLBG.UI.Stats = CreateFrame("Frame", nil, HLBG.UI.Frame)
HLBG.UI.Stats:SetAllPoints(HLBG.UI.Frame)
HLBG.UI.Stats:Hide()
HLBG.UI.Stats.Text = HLBG.UI.Stats:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
HLBG.UI.Stats.Text:SetPoint("TOPLEFT", 16, -40)
HLBG.UI.Stats.Text:SetText("Stats will appear here.")
HLBG.UI.Stats:SetScript("OnShow", function()
    local season = (HLBG and HLBG._getSeason and HLBG._getSeason()) or 0
    if _G.AIO and _G.AIO.Handle then
        _G.AIO.Handle("HLBG", "Request", "STATS")
        _G.AIO.Handle("HLBG", "Request", "STATS", season)
        _G.AIO.Handle("HLBG", "Stats")
        _G.AIO.Handle("HLBG", "Stats", season)
        _G.AIO.Handle("HLBG", "STATS")
        _G.AIO.Handle("HLBG", "STATS", season)
        _G.AIO.Handle("HLBG", "StatsUI")
        _G.AIO.Handle("HLBG", "StatsUI", season)
    end
    do
        local sendDot = (HLBG and HLBG.SendServerDot) or _G.HLBG_SendServerDot
        if type(sendDot) == 'function' then
            sendDot(".hlbg statsui")
            sendDot(string.format(".hlbg statsui %d", season))
        end
    end
end)

-- Queue tab: join next run, show warmup/queue status
HLBG.UI.Queue = CreateFrame("Frame", nil, HLBG.UI.Frame)
HLBG.UI.Queue:SetAllPoints(HLBG.UI.Frame)
HLBG.UI.Queue:Hide()
HLBG.UI.Queue.Join = CreateFrame("Button", nil, HLBG.UI.Queue, "UIPanelButtonTemplate")
HLBG.UI.Queue.Join:SetPoint("TOPLEFT", 16, -40)
HLBG.UI.Queue.Join:SetSize(140, 24)
HLBG.UI.Queue.Join:SetText("Join Next Run")
HLBG.UI.Queue.Status = HLBG.UI.Queue:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
HLBG.UI.Queue.Status:SetPoint("TOPLEFT", HLBG.UI.Queue.Join, "BOTTOMLEFT", 0, -8)
HLBG.UI.Queue.Status:SetText("Queue status: unknown")
-- Wire the join button
HLBG.UI.Queue.Join:SetScript("OnClick", function()
    if _G.AIO and _G.AIO.Handle then
        -- Try multiple server-side handlers
        _G.AIO.Handle("HLBG", "Request", "QUEUE_JOIN")
        _G.AIO.Handle("HLBG", "QueueJoin")
        _G.AIO.Handle("HLBG", "QUEUE", "JOIN")
    end
    local sendDot = (HLBG and HLBG.SendServerDot) or _G.HLBG_SendServerDot
    if type(sendDot) == 'function' then sendDot(".hlbg queue join") end
    if HLBG.UI and HLBG.UI.Queue and HLBG.UI.Queue.Status then HLBG.UI.Queue.Status:SetText("Queue status: requested join…") end
end)

HLBG.UI.Info = CreateFrame("Frame", nil, HLBG.UI.Frame)
HLBG.UI.Info:SetAllPoints(HLBG.UI.Frame)
HLBG.UI.Info:Hide()
HLBG.UI.Info.Text = HLBG.UI.Info:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
HLBG.UI.Info.Text:SetPoint("TOPLEFT", 16, -40)
HLBG.safeSetJustify(HLBG.UI.Info.Text, "LEFT")
HLBG.UI.Info.Text:SetWidth(460)

local function BuildInfoText()
    HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
    local minLevel = HinterlandAffixHUDDB.minLevel or 1
    local rewards = HinterlandAffixHUDDB.rewardsText or "Honor, XP, custom tokens"
    local settings = {
        string.format("Addon HUD: %s", HinterlandAffixHUDDB.useAddonHud and "On" or "Off"),
        string.format("AFK warning: %s", HinterlandAffixHUDDB.enableAFKWarning and "On" or "Off"),
        string.format("Warmup prompt: %s", HinterlandAffixHUDDB.enableWarmupCTA and "On" or "Off"),
    }
    local lines = {
        "Hinterland Battleground (HLBG)",
        " ",
        "Features:",
        "- Movable worldstate HUD (resources/timer/affix)",
        "- Live scoreboards with sorting",
        "- History and stats panels",
        "- Join queue and info tabs",
        " ",
        "Commands:",
        "/hlbg toggle - Show/hide the battleground UI",
        "/hlbg config - Open the configuration menu",
        "/hlbg help - Show this help text",
        " ",
        "Minimum level: " .. minLevel,
        "Rewards: " .. rewards,
        "Settings:",
        table.concat(settings, "\n"),
    }
    HLBG.UI.Info.Text:SetText(table.concat(lines, "\n"))
end

HLBG.UI.Info:SetScript("OnShow", BuildInfoText)

HLBG.UI.Results = CreateFrame("Frame", nil, HLBG.UI.Frame)
HLBG.UI.Results:SetAllPoints(HLBG.UI.Frame)
HLBG.UI.Results:Hide()
HLBG.UI.Results.Text = HLBG.UI.Results:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
HLBG.UI.Results.Text:SetPoint("TOPLEFT", 16, -40)
HLBG.UI.Results.Text:SetText("Results will appear here.")

-- Results scroll area to mirror history layout and support future row rendering
HLBG.UI.Results.Scroll = CreateFrame("ScrollFrame", "HLBG_ResultsScroll", HLBG.UI.Results, "UIPanelScrollFrameTemplate")
HLBG.UI.Results.Scroll:SetPoint("TOPLEFT", 16, -64)
HLBG.UI.Results.Scroll:SetPoint("BOTTOMRIGHT", -36, 16)
HLBG.UI.Results.Content = CreateFrame("Frame", nil, HLBG.UI.Results.Scroll)
HLBG.UI.Results.Content:SetSize(460, 300)
if HLBG.UI.Results.Content.SetFrameStrata then HLBG.UI.Results.Content:SetFrameStrata("DIALOG") end
HLBG.UI.Results.Scroll:SetScrollChild(HLBG.UI.Results.Content)
HLBG.UI.Results.EmptyText = HLBG.UI.Results:CreateFontString(nil, "OVERLAY", "GameFontDisable")
HLBG.UI.Results.EmptyText:SetPoint("TOPLEFT", 16, -64)
HLBG.UI.Results.EmptyText:SetText("No results yet…")
HLBG.UI.Results.EmptyText:Hide()

-- History header: clickable to sort by column
HLBG.UI.History.Header = CreateFrame("Button", nil, HLBG.UI.History)
HLBG.UI.History.Header:SetPoint("TOPLEFT", HLBG.UI.History.Scroll, "TOPLEFT", 0, 16)
HLBG.UI.History.Header:SetPoint("TOPRIGHT", HLBG.UI.History.Scroll, "TOPRIGHT", 0, 16)
HLBG.UI.History.Header:SetHeight(24)
HLBG.UI.History.Header:SetNormalFontObject("GameFontNormal")
HLBG.UI.History.Header:SetHighlightFontObject("GameFontHighlight")
-- Create an explicit FontString child for consistent API across clients (3.3.5 Button:SetJustifyH may be nil)
HLBG.UI.History.Header.Text = HLBG.UI.History.Header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
HLBG.UI.History.Header.Text:SetPoint("LEFT", 2, 0)
HLBG.UI.History.Header.Text:SetText("Player Name          Score  Team  Time")
HLBG.safeSetJustify(HLBG.UI.History.Header.Text, "LEFT")
HLBG.UI.History.Header:SetHitRectInsets(0, 0, 0, 0)
HLBG.UI.History.Header:SetScript("OnClick", function(self)
    if not HLBG.UI.History.sortBy then HLBG.UI.History.sortBy = {} end
    local sortIndex = self.sortIndex or 1
    HLBG.UI.History.sortDescending = not HLBG.UI.History.sortDescending
    table.sort(HLBG.UI.History.rows, function(a, b)
        local av, bv = a[sortIndex], b[sortIndex]
        if type(av) == "string" then av = av:lower() end
        if type(bv) == "string" then bv = bv:lower() end
        if HLBG.UI.History.sortDescending then
            return av > bv
        else
            return av < bv
        end
    end)
    HLBG.UI.History.sorted = true
    HLBG.UI.History:Update()
end)

HLBG.UI.History.Header.sortIndex = 1
HLBG.UI.History.sortDescending = false

function HLBG.UI.History:Update()
    if not self.sorted then return end
    self.sorted = false
    local rowHeight = 28
    local offset = 0
    for i, row in ipairs(self.rows) do
        row:ClearAllPoints()
        if i == 1 then
            row:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -16)
        else
            row:SetPoint("TOPLEFT", self.rows[i-1], "BOTTOMLEFT", 0, 0)
        end
        row:SetPoint("TOPRIGHT", self.rows[i], "TOPRIGHT", 0, 0)
        row:Show()
        offset = offset + rowHeight
    end
    self.Content:SetHeight(offset)
    self.Scroll:SetVerticalScroll(0)
end

HLBG.UI.History:SetScript("OnShow", function(self)
    if not self.rows or #self.rows == 0 then
        self.EmptyText:Show()
    else
        self.EmptyText:Hide()
    end
    -- Auto-request history for current paging/sort (AIO + fallback)
    local p = self.page or 1
    local per = self.per or 5
    local sk = self.sortKey or "id"
    local sd = self.sortDir or "DESC"
    -- Only load current season results
    local season = (HLBG and HLBG._getSeason and HLBG._getSeason()) or (_G.HLBG_GetSeason and _G.HLBG_GetSeason()) or 0
    if _G.AIO and _G.AIO.Handle then
        -- Season-specific variants only
        _G.AIO.Handle("HLBG", "Request", "HISTORY", p, per, season, sk, sd)
        _G.AIO.Handle("HLBG", "History", p, per, season, sk, sd)
        _G.AIO.Handle("HLBG", "HISTORY", p, per, season, sk, sd)
        _G.AIO.Handle("HLBG", "HistoryUI", p, per, season, sk, sd)
    end
    do
        local sendDot = (HLBG and HLBG.SendServerDot) or _G.HLBG_SendServerDot
        if type(sendDot) == 'function' then
            sendDot(string.format(".hlbg historyui %d %d %d %s %s", p, per, season, sk, sd))
        end
    end
    self:Update()
end)

HLBG.UI.Results.Header = HLBG.UI.History.Header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
HLBG.UI.Results.Header:SetPoint("TOPLEFT", HLBG.UI.Results, "TOPLEFT", 0, -16)
HLBG.UI.Results.Header:SetPoint("TOPRIGHT", HLBG.UI.Results, "TOPRIGHT", 0, -16)
HLBG.UI.Results.Header:SetHeight(24)
HLBG.UI.Results.Header:SetText("Player Name          Score  Team  Time")
HLBG.safeSetJustify(HLBG.UI.Results.Header, "LEFT")

HLBG.UI.Results.rows = {}
HLBG.UI.Results.sorted = false

function HLBG.UI.Results:Update()
    if not self.sorted then return end
    self.sorted = false
    local rowHeight = 28
    local offset = 0
    for i, row in ipairs(self.rows) do
        row:ClearAllPoints()
        if i == 1 then
            row:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -16)
        else
            row:SetPoint("TOPLEFT", self.rows[i-1], "BOTTOMLEFT", 0, 0)
        end
        row:SetPoint("TOPRIGHT", self.rows[i], "TOPRIGHT", 0, 0)
        row:Show()
        offset = offset + rowHeight
    end
    self.Content:SetHeight(offset)
    self.Scroll:SetVerticalScroll(0)
end

HLBG.UI.Results:SetScript("OnShow", function(self)
    if not self.rows or #self.rows == 0 then
        if self.EmptyText then self.EmptyText:Show() end
    else
        if self.EmptyText then self.EmptyText:Hide() end
    end
    -- Optional: request a results snapshot
    if _G.AIO and _G.AIO.Handle then _G.AIO.Handle("HLBG", "Request", "RESULTS") end
    self:Update()
end)

-- Initialize with live tab shown
ShowTab(1)

-- Moved from main file: auto-open the frame in battlegrounds
local function eventHandler(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        local inInstance = false
        local instanceType = nil
        if type(HLBG) == 'table' and type(HLBG.safeIsInInstance) == 'function' then
            local okIns, okType = pcall(function() return HLBG.safeIsInInstance() end)
            if okIns and type(okType) == 'table' then
                inInstance = okType[1] or false
                instanceType = okType[2]
            elseif okIns and type(okType) ~= 'table' then
                -- safeIsInInstance may return two values; handle both
                inInstance, instanceType = HLBG.safeIsInInstance()
            end
        else
            pcall(function() inInstance = IsInInstance() end)
            -- Some clients or environments may not expose GetInstanceType; guard it
            local ok, it = pcall(function() return (type(GetInstanceType) == 'function') and GetInstanceType() or nil end)
            if ok then instanceType = it end
        end
        if inInstance and (instanceType == "pvp" or instanceType == "arena") then
            HLBG.UI.Frame:Show()
        else
            HLBG.UI.Frame:Hide()
        end
    elseif event == "PLAYER_LEAVING_WORLD" then
        HLBG.UI.Frame:Hide()
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        local inInstance = false
        local instanceType = nil
        if type(HLBG) == 'table' and type(HLBG.safeIsInInstance) == 'function' then
            local okIns, okType = pcall(function() return HLBG.safeIsInInstance() end)
            if okIns and type(okType) == 'table' then
                inInstance = okType[1] or false
                instanceType = okType[2]
            elseif okIns and type(okType) ~= 'table' then
                inInstance, instanceType = HLBG.safeIsInInstance()
            end
        else
            pcall(function() inInstance = IsInInstance() end)
            local ok2, it2 = pcall(function() return (type(GetInstanceType) == 'function') and GetInstanceType() or nil end)
            if ok2 then instanceType = it2 end
        end
        if inInstance and (instanceType == "pvp" or instanceType == "arena") then
            HLBG.UI.Frame:Show()
        else
            HLBG.UI.Frame:Hide()
        end
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_LEAVING_WORLD")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:SetScript("OnEvent", eventHandler)

-- Slash command is registered in the bootstrap client file to ensure availability
-- (kept out of the UI module to avoid duplicate SLASH_* registrations)

-- Moved from main file: update UI scale based on saved variable
local function UpdateUIScale()
    local scale = HinterlandAffixHUDDB and HinterlandAffixHUDDB.uiScale or 1
    HLBG.UI.Frame:SetScale(scale)
end

-- Hook to update scale on login and when the frame is shown
local function OnEvent(self, event, ...)
    if event == "PLAYER_LOGIN" then
        UpdateUIScale()
    elseif event == "VARIABLES_LOADED" then
        UpdateUIScale()
    elseif event == "UI_SCALE_CHANGED" then
        UpdateUIScale()
    end
end

local f2 = CreateFrame("Frame")
f2:RegisterEvent("PLAYER_LOGIN")
f2:RegisterEvent("VARIABLES_LOADED")
f2:RegisterEvent("UI_SCALE_CHANGED")
f2:SetScript("OnEvent", OnEvent)

-- Initial scale update
UpdateUIScale()

HLBG.UI.Frame:SetScript("OnShow", function()
    -- Update the frame position and scale when shown
    UpdateUIScale()
    if HinterlandAffixHUDDB.hlbgMainPos then
        HLBG.UI.Frame:ClearAllPoints()
        HLBG.UI.Frame:SetPoint(HinterlandAffixHUDDB.hlbgMainPos.point, _G[HinterlandAffixHUDDB.hlbgMainPos.rel], HinterlandAffixHUDDB.hlbgMainPos.relPoint, HinterlandAffixHUDDB.hlbgMainPos.x or 0, HinterlandAffixHUDDB.hlbgMainPos.y or 0)
    end
end)

-- Test data for live and history tabs
local testData = {
    live = {
        { "Player1", 1500, "Alliance", "00:10" },
        { "Player2", 1200, "Horde", "00:12" },
        { "Player3", 1800, "Alliance", "00:08" },
        { "Player4", 1100, "Horde", "00:14" },
    },
    history = {
        { "Player1", 3000, "Alliance", "00:20" },
        { "Player2", 2400, "Horde", "00:22" },
        { "Player3", 3600, "Alliance", "00:18" },
        { "Player4", 2200, "Horde", "00:28" },
    },
}

-- Populate test data function
local function PopulateTestData()
    -- Live tab
    for i, row in ipairs(testData.live) do
        local liveRow = liveGetRow(i)
        liveRow.name:SetText(row[1])
        liveRow.score:SetText(row[2])
        liveRow.team:SetText(row[3])
        liveRow.ts:SetText(row[4])
    end

    -- History tab
    for i, row in ipairs(testData.history) do
        local historyRow = HLBG.UI.History.rows[i]
        if historyRow then
            historyRow.name:SetText(row[1])
            historyRow.score:SetText(row[2])
            historyRow.team:SetText(row[3])
            historyRow.ts:SetText(row[4])
        end
    end

    HLBG.UI.History:Update()
end

-- Populate test data on addon load (disabled in production to avoid noise)
-- PopulateTestData()

-- Debugging: print frame references
-- Debug printing of UI frames is disabled by default

_G.HLBG = HLBG
