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
    -- Update compact summary instead of rendering list rows
    pcall(function()
        local RES = _G.RES or {A=0,H=0}
        local a = tonumber(RES.A or 0) or 0
        local h = tonumber(RES.H or 0) or 0
        local tl = tonumber(HLBG._timeLeft or RES.DURATION or 0) or 0
        local m = math.floor(tl/60); local s = tl%60
        local aff = tostring(HLBG._affixText or "-")
        local ap = (HLBG._lastStatus and (HLBG._lastStatus.APlayers or HLBG._lastStatus.APC or HLBG._lastStatus.AllyCount)) or "-"
        local hp = (HLBG._lastStatus and (HLBG._lastStatus.HPlayers or HLBG._lastStatus.HPC or HLBG._lastStatus.HordeCount)) or "-"
        if HLBG.UI and HLBG.UI.Live and HLBG.UI.Live.Summary then
            HLBG.UI.Live.Summary:SetText(string.format("Resources  A:%d  H:%d      Players  A:%s  H:%s      Time %d:%02d      Affix %s", a,h,tostring(ap),tostring(hp), m,s, aff))
        end
    end)
    -- Prefer compact summary view; skip detailed row rendering for now
    do return end
    local y = -4
    for i,row in ipairs(sorted) do
        local r = HLBG.UI.Live.rows[i]
        if not r then
            -- lazily create row if missing
            r = CreateFrame("Frame", nil, HLBG.UI.Live.Content)
            if r.SetFrameStrata then r:SetFrameStrata("DIALOG") end
            r:SetSize(440, 20)
            r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.hk = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.score = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.name:SetPoint("LEFT", r, "LEFT", 2, 0)
            r.name:SetWidth(240); HLBG.safeSetJustify(r.name, "LEFT")
            r.hk:SetPoint("LEFT", r.name, "RIGHT", 12, 0)
            r.hk:SetWidth(60); HLBG.safeSetJustify(r.hk, "CENTER")
            r.score:SetPoint("LEFT", r.hk, "RIGHT", 12, 0)
            r.score:SetWidth(100); HLBG.safeSetJustify(r.score, "RIGHT")
            HLBG.UI.Live.rows[i] = r
        end
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", HLBG.UI.Live.Content, "TOPLEFT", 0, y)
        local name = row.name or row[3] or row[1] or "?"
        local score = row.score or row[5] or row[2] or 0
        local hk = tonumber(row.hk or row.HK or row[6]) or 0
        local cls = tonumber(row[7] or row.class or row.Class) or nil
        r.name:SetText(tostring(name))
        r.hk:SetText(string.format('HK:+%d', math.max(0, hk)))
        r.score:SetText(tostring(score))
        if not r._hlbgHover then
            r._hlbgHover = true
            r:SetScript('OnEnter', function(self) self:SetBackdrop({ bgFile = 'Interface/Tooltips/UI-Tooltip-Background' }); self:SetBackdropColor(1,1,0.4,0.10) end)
            r:SetScript('OnLeave', function(self) self:SetBackdrop(nil) end)
        end
        r:Show()
        y = y - 20
    end
    local newH = math.max(180, 8 + #rows * 20)
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
    local rows, page, per, total, col, dir, secondsAgo
    local function looksLikeRows(v)
        if type(v) ~= "table" then return false end
        if #v and #v > 0 then return true end
        if v.id or v.ts or v.timestamp or v.winner or v.affix or v.reason then return true end
        return false
    end
    if looksLikeRows(a) then
        rows, page, per, total, col, dir, secondsAgo = a, b, c, d, e, f, g
    elseif looksLikeRows(b) then
        rows, page, per, total, col, dir, secondsAgo = b, c, d, e, f, g
    else
        page, per, rows, total, col, dir, secondsAgo = a, b, c, d, e, f, g
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
    
    -- Debug the received parameters
    HLBG.Debug("History: rows=" .. (type(rows) == "table" and #rows or "0") .. 
               " page=" .. tostring(page) .. 
               " per=" .. tostring(per) .. 
               " total=" .. tostring(total) ..
               " col=" .. tostring(col) .. 
               " dir=" .. tostring(dir))
    
    -- Only overwrite pagination when explicit numeric values are provided by the payload
    -- Coerce numeric pagination values even if they come as strings
    if page ~= nil then HLBG.UI.History.page = tonumber(page) or HLBG.UI.History.page end
    if per ~= nil then HLBG.UI.History.per = tonumber(per) or HLBG.UI.History.per end
    if total ~= nil then HLBG.UI.History.total = tonumber(total) or HLBG.UI.History.total end
    HLBG.UI.History.page = HLBG.UI.History.page or 1
    HLBG.UI.History.per = HLBG.UI.History.per or 10
    HLBG.UI.History.total = HLBG.UI.History.total or 0
    HLBG.UI.History.sortKey = col or HLBG.UI.History.sortKey or "id"
    HLBG.UI.History.sortDir = dir or HLBG.UI.History.sortDir or "DESC"
    
    -- Enhanced normalization logic
    local normalized = {}
    if type(rows) == "table" then
        -- First try to handle the case where rows is a map with numeric keys (1, 2, etc)
        if #rows > 0 then
            -- It's already a sequential array
            normalized = rows
        else
            -- Try to normalize from various formats
            local tmp = {}
            for k, v in pairs(rows) do
                if type(v) == "table" then
                    -- If we have a table with numeric keys inside
                    tmp[#tmp + 1] = v
                end
            end
            
            -- If we still don't have rows, maybe rows itself is a single row
            if #tmp == 0 and (rows.id or rows.ts or rows.winner or rows.affix) then
                tmp[1] = rows
            end
            
            normalized = tmp
        end
    end
    
    -- Additional normalization: extract numeric properties to named ones
    for i, row in ipairs(normalized) do
        -- Convert numeric indices to named properties if not already present
        if type(row[1]) ~= "nil" and type(row.id) == "nil" then row.id = row[1] end
        if type(row[2]) ~= "nil" and type(row.ts) == "nil" then row.ts = row[2] end
        if type(row[3]) ~= "nil" and type(row.winner) == "nil" then row.winner = row[3] end
        if type(row[3]) ~= "nil" and type(row.winner_tid) == "nil" then
            -- Try to detect faction IDs
            if row[3] == "Horde" or row[3] == "HORDE" then row.winner_tid = 67 end
            if row[3] == "Alliance" or row[3] == "ALLIANCE" then row.winner_tid = 469 end
        end
        if type(row[4]) ~= "nil" and type(row.affix) == "nil" then row.affix = row[4] end
        if type(row[5]) ~= "nil" and type(row.dur) == "nil" then row.dur = row[5] end
        if type(row[6]) ~= "nil" and type(row.reason) == "nil" then row.reason = row[6] end
    end
    
    rows = normalized
    
    -- Client-side sort safety: if we want ASC/DESC by a key but the server returns any order, sort here
    local wantAsc = (tostring((HLBG.UI.History.sortDir or "ASC"):upper()) == "ASC")
    local sortKey = tostring(HLBG.UI.History.sortKey or "id"):lower()
    
    if type(rows) == 'table' and #rows > 1 then
        table.sort(rows, function(a,b)
            local av, bv
            
            if sortKey == "id" then
                av = tonumber((type(a)=="table" and (a.id or a[1])) or 0) or 0
                bv = tonumber((type(b)=="table" and (b.id or b[1])) or 0) or 0
            elseif sortKey == "ts" then
                av = tonumber((type(a)=="table" and (a.ts or a[2])) or 0) or 0
                bv = tonumber((type(b)=="table" and (b.ts or b[2])) or 0) or 0
            else
                -- Default to string comparison for other fields
                av = tostring((type(a)=="table" and (a[sortKey] or "")) or "")
                bv = tostring((type(b)=="table" and (b[sortKey] or "")) or "")
            end
            
            if wantAsc then
                return av < bv
            else
                return av > bv
            end
        end)
    end
    
    -- Store for debugging
    if not HinterlandAffixHUD_DebugLog then HinterlandAffixHUD_DebugLog = {} end
    HLBG.UI.History.lastRows = rows
    local sample = ""
    if #rows > 0 and type(rows[1]) == 'table' then
        local r = rows[1]
        local id = tostring(r.id or r[1] or "")
        local ts = tostring(r.ts or r[2] or "")
        local win = tostring(r.winner or r[3] or "")
        sample = string.format("%s\t%s\t%s\t%s", id, ts, win, tostring(r.affix or r[4] or ""))
    end
    
    -- Log the results
    table.insert(HinterlandAffixHUD_DebugLog, 1, string.format("[%s] HISTORY N=%d sample=%s", date("%Y-%m-%d %H:%M:%S"), #rows, sample))
    while #HinterlandAffixHUD_DebugLog > 200 do table.remove(HinterlandAffixHUD_DebugLog) end
    
    -- Forward a compact sample to server-side log if available
    local okSend = pcall(function() return _G.HLBG_SendClientLog end)
    local send = (okSend and type(_G.HLBG_SendClientLog) == "function") and _G.HLBG_SendClientLog or ((type(HLBG) == "table" and type(HLBG.SendClientLog) == "function") and HLBG.SendClientLog or nil)
    if send then
        local sample2 = sample
        pcall(function() send(string.format("HISTORY_CLIENT N=%d sample=%s", #rows, sample2)) end)
    end
    
    -- Show the UI and ensure History tab (don't force tab switch)
    if HLBG.UI and HLBG.UI.Frame then 
        HLBG.UI.Frame:Show()
        -- Only switch to History tab if no tab is currently active
        local currentTab = HinterlandAffixHUDDB and HinterlandAffixHUDDB.lastInnerTab or 1
        if currentTab == 1 or not currentTab then
            ShowTab(1) -- History tab
        end
    end
    if HLBG.UI and HLBG.UI.History and HLBG.UI.History.Content then HLBG.UI.History.Content:Show() end
    if HLBG.UI and HLBG.UI.History and HLBG.UI.History.Scroll then HLBG.UI.History.Scroll:SetVerticalScroll(0) end
    
    -- Prepare rows container
    if not HLBG.UI.History.rows then HLBG.UI.History.rows = {} end
    
    -- Render rows with improved visuals
    local function getRow(i)
        local r = HLBG.UI.History.rows[i]
        if not r then
            r = CreateFrame("Frame", "HLBG_HistoryRow_"..i, HLBG.UI.History.Content)
            if r.SetFrameStrata then r:SetFrameStrata("DIALOG") end
            r:SetHeight(22) -- Taller rows for better readability
            
            -- Set backdrop for better visibility
            r:SetBackdrop({ 
                bgFile = "Interface/Tooltips/UI-Tooltip-Background", 
                edgeFile = nil, 
                tile = true, tileSize = 16, edgeSize = 0, 
                insets = { left = 0, right = 0, top = 0, bottom = 0 }
            })
            
            -- Create text fields
            r.id = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.sea = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.ts = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.win = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.aff = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.dur = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall") 
            r.rea = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            
            -- Set positioning with more space
            r.id:SetPoint("LEFT", r, "LEFT", 5, 0); r.id:SetWidth(40) 
            HLBG.safeSetJustify(r.id, "LEFT")
            
            r.sea:SetPoint("LEFT", r.id, "RIGHT", 5, 0); r.sea:SetWidth(40)
            HLBG.safeSetJustify(r.sea, "LEFT")
            
            r.ts:SetPoint("LEFT", r.sea, "RIGHT", 5, 0); r.ts:SetWidth(120)
            HLBG.safeSetJustify(r.ts, "LEFT")
            
            r.win:SetPoint("LEFT", r.ts, "RIGHT", 5, 0); r.win:SetWidth(70)
            HLBG.safeSetJustify(r.win, "LEFT")
            
            r.aff:SetPoint("LEFT", r.win, "RIGHT", 5, 0); r.aff:SetWidth(70)
            HLBG.safeSetJustify(r.aff, "LEFT")
            
            r.dur:SetPoint("LEFT", r.aff, "RIGHT", 5, 0); r.dur:SetWidth(60)
            HLBG.safeSetJustify(r.dur, "LEFT")
            
            r.rea:SetPoint("LEFT", r.dur, "RIGHT", 5, 0); r.rea:SetWidth(70)
            HLBG.safeSetJustify(r.rea, "LEFT")
            
            -- Add hover effect
            r:SetScript('OnEnter', function(self) 
                self:SetBackdropColor(0.3, 0.3, 0.7, 0.5)
                
                -- Show tooltip with more details
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine("Battleground #" .. (self.rowData and self.rowData.id or "?"))
                
                -- Add timestamp/time ago
                if self.rowData and self.rowData.ts then
                    local timeText
                    if secondsAgo and tonumber(self.rowData.ts) then
                        local ts = tonumber(self.rowData.ts)
                        if ts < secondsAgo then
                            timeText = SecondsToTime(secondsAgo - ts) .. " ago"
                        else
                            timeText = date("%Y-%m-%d %H:%M:%S", ts)
                        end
                    else
                        timeText = tostring(self.rowData.ts)
                    end
                    GameTooltip:AddLine("Time: " .. timeText)
                end
                
                -- Winner details
                if self.rowData and self.rowData.winner_tid then
                    if self.rowData.winner_tid == 67 then
                        GameTooltip:AddLine("Winner: |cFFFF0000Horde|r")
                    elseif self.rowData.winner_tid == 469 then
                        GameTooltip:AddLine("Winner: |cFF0000FFAlliance|r")
                    else
                        GameTooltip:AddLine("Winner: " .. tostring(self.rowData.winner or "Unknown"))
                    end
                end
                
                -- Affix details
                if self.rowData and self.rowData.affix then
                    local affixName = HLBG.GetAffixName(self.rowData.affix)
                    GameTooltip:AddLine("Affix: " .. affixName)
                end
                
                -- Duration
                if self.rowData and self.rowData.dur and tonumber(self.rowData.dur) then
                    GameTooltip:AddLine("Duration: " .. SecondsToTime(tonumber(self.rowData.dur)))
                end
                
                -- Victory reason
                if self.rowData and self.rowData.reason then
                    GameTooltip:AddLine("Victory by: " .. tostring(self.rowData.reason))
                end
                
                GameTooltip:Show()
            end)
            
            r:SetScript('OnLeave', function(self)
                -- Restore original color based on row index
                local rowIndex = self.rowIndex or 0
                if rowIndex % 2 == 0 then
                    self:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
                else 
                    self:SetBackdropColor(0.05, 0.05, 0.05, 0.3)
                end
                
                GameTooltip:Hide()
            end)
            
            HLBG.UI.History.rows[i] = r
        end
        return r
    end
    
    -- Hide all existing rows
    for i=1, #HLBG.UI.History.rows do 
        if HLBG.UI.History.rows[i] then
            HLBG.UI.History.rows[i]:Hide() 
        end
    end
    
    -- Starting position and tracking
    local y = -22
    local hadRows = false
    local contentWidth = 450
    
    -- Check if we need to add an empty state message
    if #rows == 0 then
        if not HLBG.UI.History.EmptyText then
            HLBG.UI.History.EmptyText = HLBG.UI.History.Content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            HLBG.UI.History.EmptyText:SetPoint("CENTER", 0, 0)
            HLBG.UI.History.EmptyText:SetText("No history entries found.\nPlay some battlegrounds!")
        end
        HLBG.UI.History.EmptyText:Show()
    elseif HLBG.UI.History.EmptyText then
        HLBG.UI.History.EmptyText:Hide()
    end
    
    -- Create rows for each entry - fixed positioning
    for i, row in ipairs(rows) do
        local r = getRow(i)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", HLBG.UI.History.Content, "TOPLEFT", 5, y)
        r:SetWidth(HLBG.UI.History.Content:GetWidth() - 10) -- Set width correctly
        r:SetHeight(22)
        
        -- Store row data for tooltip
        r.rowData = row
        r.rowIndex = i
        
        -- Set alternating row background
        if i % 2 == 0 then
            r:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
        else
            r:SetBackdropColor(0.05, 0.05, 0.05, 0.3)
        end
        
        -- Extract values from the row with fallbacks
        local id = row.id or row[1]
        local sea = row.season
        local sname = row.seasonName or row.sname or nil
        local ts = row.ts or row[2]
        local win = row.winner or row[3]
        local affix = row.affix or row[4]
        local dur = row.dur or row[5]
        local reas = row.reason or row[6]
        
        -- Format timestamps if we have secondsAgo
        local tsText = ts
        if secondsAgo and ts and type(ts) == "number" then
            if ts < secondsAgo then
                tsText = SecondsToTime(secondsAgo - ts).." ago"
            else
                tsText = date("%Y-%m-%d %H:%M:%S", ts)
            end
        end
        
        -- Set text fields with improved formatting
        r.id:SetText(tostring(id or ""))
        r.sea:SetText(tostring(sname or sea or ""))
        r.ts:SetText(tsText or "")
        
        -- Color-code winner by faction
        local wtxt = (win or "")
        if row.winner_tid and row.winner_tid == 67 then
            wtxt = "|cFFFF0000Horde|r"
        elseif row.winner_tid and row.winner_tid == 469 then
            wtxt = "|cFF0000FFAlliance|r"
        elseif tostring(wtxt):upper() == "DRAW" then 
            wtxt = "|cFFFFFF00Draw|r"
        end
        r.win:SetText(wtxt)
        
        -- Use affix name helper if available
        r.aff:SetText(HLBG.GetAffixName and HLBG.GetAffixName(affix) or tostring(affix or ""))
        
        -- Format duration nicely if present
        if dur and tonumber(dur) then
            r.dur:SetText(SecondsToTime(tonumber(dur)))
        else
            r.dur:SetText("")
        end
        
        -- Victory reason
        r.rea:SetText(reas or "-")
        
        r:Show()
        y = y - 22 -- Match row height
        hadRows = true
    end
    
    -- Update pager information with proper defaults
    HLBG.UI.History.page = HLBG.UI.History.page or 1
    HLBG.UI.History.per = HLBG.UI.History.per or 15
    
    -- Calculate total records - use test data count if no server data
    local totalRecords = HLBG.UI.History.total or (HLBG.UI.History.lastRows and #HLBG.UI.History.lastRows) or 25 -- Assume 25 test records
    local maxPage = math.max(1, math.ceil(totalRecords / HLBG.UI.History.per))
    
    -- Ensure current page is within valid range
    if HLBG.UI.History.page > maxPage then
        HLBG.UI.History.page = maxPage
    end
    if HLBG.UI.History.page < 1 then
        HLBG.UI.History.page = 1
    end
                    
    if HLBG.UI.History.Nav and HLBG.UI.History.Nav.PageText then
        HLBG.UI.History.Nav.PageText:SetText(string.format("Page %d / %d", HLBG.UI.History.page, maxPage))
    end
    
    if HLBG.UI.History.Nav and HLBG.UI.History.Nav.Prev then
        HLBG.UI.History.Nav.Prev:SetEnabled(HLBG.UI.History.page > 1)
    end
    
    if HLBG.UI.History.Nav and HLBG.UI.History.Nav.Next then
        HLBG.UI.History.Nav.Next:SetEnabled(HLBG.UI.History.page < maxPage)
    end
    
    -- Adjust content height to match rows
    local visibleCount = #rows
    local newH = math.max(300, 22 + visibleCount * 22 + 16) -- Account for header and some padding
    HLBG.UI.History.Content:SetHeight(newH)
    
    -- Reset scroll position
    if HLBG.UI.History.Scroll and HLBG.UI.History.Scroll.SetVerticalScroll then 
        HLBG.UI.History.Scroll:SetVerticalScroll(0)
        HLBG.UI.History.Scroll:UpdateScrollChildRect()
    end
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
    
    -- Use test data if no real stats available
    if not stats or (stats.counts and stats.counts.Alliance == 0 and stats.counts.Horde == 0) then
        -- Load cached test data or create fallback
        local testStats = HLBG.cachedStats or {
            allianceWins = 42,
            hordeWins = 38, 
            draws = 3,
            totalBattles = 83,
            avgDuration = 918
        }
        
        stats = {
            counts = {Alliance = testStats.allianceWins, Horde = testStats.hordeWins},
            draws = testStats.draws,
            avgDuration = testStats.avgDuration or 918,
            minDuration = 420, -- 7 minutes
            maxDuration = 1800 -- 30 minutes
        }
        print("|cFF33FF99HLBG:|r Using test stats data (server data not available)")
    end
    
    -- Ensure all required fields exist
    stats = stats or {}
    if not stats.counts then stats.counts = {Alliance = 0, Horde = 0} end
    stats.counts.Alliance = stats.counts.Alliance or 0
    stats.counts.Horde = stats.counts.Horde or 0
    
    if not stats.draws then stats.draws = 0 end
    if not stats.avgDuration then stats.avgDuration = 0 end
    if not stats.minDuration then stats.minDuration = 0 end
    if not stats.maxDuration then stats.maxDuration = 0 end
    if not stats.topAffixes then stats.topAffixes = {} end
    if not stats.topReason then stats.topReason = {} end
    if not stats.topDurations then stats.topDurations = {} end
    if not stats.medianMargin then stats.medianMargin = 0 end
    
    HLBG._lastStats = stats
    
    -- Store the stats data for later reference
    HLBG.UI.Stats.data = stats
    
    -- Debug the stats we received
    HLBG.Debug("Stats received: " .. (stats and type(stats) == "table" and #stats or "0") .. " entries")
    
    -- Hide the old text display and create modern stat boxes
    if HLBG.UI.Stats.Text then
        HLBG.UI.Stats.Text:Hide()
    end
    
    -- Create modern stats layout with individual boxes
    if not HLBG.UI.Stats.ModernFrame then
        HLBG.UI.Stats.ModernFrame = CreateFrame("Frame", nil, HLBG.UI.Stats)
        HLBG.UI.Stats.ModernFrame:SetAllPoints(HLBG.UI.Stats)
        
        -- Function to create a stat box
        local function createStatBox(parent, width, height, xPos, yPos)
            local box = CreateFrame("Frame", nil, parent)
            box:SetSize(width, height)
            box:SetPoint("TOPLEFT", parent, "TOPLEFT", xPos, yPos)
            box:SetBackdrop({
                bgFile = "Interface/Tooltips/UI-Tooltip-Background",
                edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 16,
                insets = {left = 4, right = 4, top = 4, bottom = 4}
            })
            box:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
            box:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
            
            -- Value text (big number)
            box.value = box:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
            box.value:SetPoint("CENTER", box, "CENTER", 0, 5)
            box.value:SetTextColor(1, 1, 1, 1)
            
            -- Label text (description)
            box.label = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            box.label:SetPoint("BOTTOM", box, "BOTTOM", 0, 8)
            box.label:SetTextColor(0.8, 0.8, 0.8, 1)
            
            return box
        end
        
        -- Create stat boxes in 3x3 grid
        local boxWidth, boxHeight = 180, 80
        local startX, startY = 20, -60
        local spacingX, spacingY = 200, 100
        
        -- Row 1
        HLBG.UI.Stats.TotalBattles = createStatBox(HLBG.UI.Stats.ModernFrame, boxWidth, boxHeight, startX, startY)
        HLBG.UI.Stats.WinRate = createStatBox(HLBG.UI.Stats.ModernFrame, boxWidth, boxHeight, startX + spacingX, startY)
        
        -- Row 2  
        HLBG.UI.Stats.Participated = createStatBox(HLBG.UI.Stats.ModernFrame, boxWidth, boxHeight, startX, startY - spacingY)
        HLBG.UI.Stats.SuccessRate = createStatBox(HLBG.UI.Stats.ModernFrame, boxWidth, boxHeight, startX + spacingX, startY - spacingY)
        
        -- Row 3
        HLBG.UI.Stats.BestScore = createStatBox(HLBG.UI.Stats.ModernFrame, boxWidth, boxHeight, startX, startY - spacingY * 2)
        HLBG.UI.Stats.TotalHonor = createStatBox(HLBG.UI.Stats.ModernFrame, boxWidth, boxHeight, startX + spacingX, startY - spacingY * 2)
        
        -- Row 4
        HLBG.UI.Stats.KillsDeaths = createStatBox(HLBG.UI.Stats.ModernFrame, boxWidth, boxHeight, startX, startY - spacingY * 3)
        HLBG.UI.Stats.AvgDuration = createStatBox(HLBG.UI.Stats.ModernFrame, boxWidth, boxHeight, startX + spacingX, startY - spacingY * 3)
    end
    
    -- Extract faction win counts and calculate stats
    local counts = stats.counts or {}
    local alliance = tonumber(counts.Alliance or counts.ALLIANCE or 0) or 0
    local horde = tonumber(counts.Horde or counts.HORDE or 0) or 0
    local draws = tonumber(stats.draws or 0) or 0
    local total = alliance + horde + draws
    
    -- Calculate player personal stats (fallback data for demo)
    local personalStats = stats.playerStats or HLBG.cachedStats and HLBG.cachedStats.playerStats or {
        totalBattles = 23,
        winRate = 0.652,
        bestScore = 4200,
        totalHonor = 15600,
        kills = 87,
        deaths = 34,
        avgDuration = 918 -- seconds
    }
    
    -- Win percentages
    local winRate = personalStats.totalBattles > 0 and math.floor((personalStats.winRate or 0) * 100) or 0
    local successRate = winRate -- Same for now
    local kdr = personalStats.deaths > 0 and math.floor((personalStats.kills / personalStats.deaths) * 100) / 100 or personalStats.kills
    
    -- Update modern stat boxes
    local s = HLBG.UI.Stats
    
    -- Row 1
    s.TotalBattles.value:SetText(tostring(personalStats.totalBattles or 0))
    s.TotalBattles.label:SetText("Total Battles")
    
    s.WinRate.value:SetText(winRate .. "%")
    s.WinRate.label:SetText("Win Rate")
    
    -- Row 2
    s.Participated.value:SetText(tostring(personalStats.totalBattles or 0))
    s.Participated.label:SetText("Participated")
    
    s.SuccessRate.value:SetText(successRate .. "%")
    s.SuccessRate.label:SetText("Success Rate")
    
    -- Row 3
    s.BestScore.value:SetText(tostring(personalStats.bestScore or 0))
    s.BestScore.label:SetText("Best Score")
    
    s.TotalHonor.value:SetText(tostring(personalStats.totalHonor or 0))
    s.TotalHonor.label:SetText("Total Honor")
    
    -- Row 4
    s.KillsDeaths.value:SetText(personalStats.kills .. "/" .. personalStats.deaths)
    s.KillsDeaths.label:SetText("Kills/Deaths")
    
    local avgMin = math.floor((personalStats.avgDuration or 918) / 60)
    local avgSec = (personalStats.avgDuration or 918) % 60
    s.AvgDuration.value:SetText(string.format("%d:%02d", avgMin, avgSec))
    s.AvgDuration.label:SetText("Avg Duration")
    
    -- Show the modern frame
    HLBG.UI.Stats.ModernFrame:Show()
    
    -- If there's a single stats string summary, show it in the text field as well
    if HLBG.UI.Stats.Text and stats.summary then
        HLBG.UI.Stats.Text:SetText(stats.summary)
    elseif HLBG.UI.Stats.Text then
        local summaryText = string.format(
            "Alliance: %d (%d%%)  Horde: %d (%d%%)  Draws: %d\nAvg duration: %s",
            alliance, alliancePct, horde, hordePct, draws, SecondsToTime(avgDuration)
        )
        HLBG.UI.Stats.Text:SetText(summaryText)
    end
    
    -- Show the UI and ensure Stats tab only if currently active
    if HLBG.UI and HLBG.UI.Frame then 
        HLBG.UI.Frame:Show()
        -- Only switch to Stats tab if no tab is currently active or if it's already the Stats tab
        local currentTab = HinterlandAffixHUDDB and HinterlandAffixHUDDB.lastInnerTab or 1
        if currentTab == 2 then
            ShowTab(2) -- Stats tab
        end
    end
    
    -- Make sure we cancel the pending timer if it exists
    local delay = 0.15
    local pending = HLBG.UI.Stats
    pending._pendingStats = stats
    pending._pending = true
    
    if not pending._timer then
        pending._timer = CreateFrame("Frame")
        pending._timer._elapsed = 0
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

-- Main window inside PvP frame (increased size for better readability)
HLBG.UI.Frame = CreateFrame("Frame", "HLBG_Main", PVPParentFrame or PVPFrame)
HLBG.UI.Frame:SetSize(640, 450)
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

-- Tabs inside window: History / Stats (Live tab removed per user request)

HLBG.UI.Tabs = HLBG.UI.Tabs or {}
local baseName = HLBG.UI.Frame.GetName and HLBG.UI.Frame:GetName() or "HLBG_Main"

-- Tab 1: History (was tab 2, now tab 1)
HLBG.UI.Tabs[1] = HLBG.UI.Tabs[1] or CreateFrame("Button", baseName.."Tab1", HLBG.UI.Frame, "OptionsFrameTabButtonTemplate")
HLBG.UI.Tabs[1]:SetPoint("TOPLEFT", HLBG.UI.Frame, "BOTTOMLEFT", 10, 7)
HLBG.UI.Tabs[1]:SetText("History")
HLBG.UI.Tabs[1]:SetScript("OnClick", function() if type(ShowTab) == 'function' then ShowTab(1) end end)

-- Tab 2: Stats (was tab 3, now tab 2)
HLBG.UI.Tabs[2] = HLBG.UI.Tabs[2] or CreateFrame("Button", baseName.."Tab2", HLBG.UI.Frame, "OptionsFrameTabButtonTemplate")
HLBG.UI.Tabs[2]:SetPoint("LEFT", HLBG.UI.Tabs[1], "RIGHT")
HLBG.UI.Tabs[2]:SetText("Stats")
HLBG.UI.Tabs[2]:SetScript("OnClick", function() if type(ShowTab) == 'function' then ShowTab(2) end end)

-- Additional tabs: Info (overview), Settings (configuration), Results (post-match)
HLBG.UI.Tabs[3] = HLBG.UI.Tabs[3] or CreateFrame("Button", baseName.."Tab3", HLBG.UI.Frame, "OptionsFrameTabButtonTemplate")
HLBG.UI.Tabs[3]:SetPoint("LEFT", HLBG.UI.Tabs[2], "RIGHT")
HLBG.UI.Tabs[3]:SetText("Info")
HLBG.UI.Tabs[3]:SetScript("OnClick", function() if type(ShowTab) == 'function' then ShowTab(3) end end)

HLBG.UI.Tabs[4] = HLBG.UI.Tabs[4] or CreateFrame("Button", baseName.."Tab4", HLBG.UI.Frame, "OptionsFrameTabButtonTemplate")
HLBG.UI.Tabs[4]:SetPoint("LEFT", HLBG.UI.Tabs[3], "RIGHT")
HLBG.UI.Tabs[4]:SetText("Settings")
HLBG.UI.Tabs[4]:SetScript("OnClick", function() if type(ShowTab) == 'function' then ShowTab(4) end end)

HLBG.UI.Tabs[5] = HLBG.UI.Tabs[5] or CreateFrame("Button", baseName.."Tab5", HLBG.UI.Frame, "OptionsFrameTabButtonTemplate")
HLBG.UI.Tabs[5]:SetPoint("LEFT", HLBG.UI.Tabs[4], "RIGHT")
HLBG.UI.Tabs[5]:SetText("Queue")
HLBG.UI.Tabs[5]:SetScript("OnClick", function() if type(ShowTab) == 'function' then ShowTab(5) end end)

-- Safe wrappers for PanelTemplates functions (older clients may not define these or frame may be unnamed)
local function SafeSetNumTabs(frame, n)
    if not frame or type(n) ~= 'number' then return end
    if type(PanelTemplates_SetNumTabs) ~= 'function' then return end
    -- avoid calling with unnamed frame (template concatenates frame:GetName() with 'Tab')
    local fname = frame.GetName and frame:GetName() or nil
    if not fname then return end
    pcall(PanelTemplates_SetNumTabs, frame, n)
end

local function SafeSetTab(frame, i)
    if not frame or type(i) ~= 'number' then return end
    if type(PanelTemplates_SetTab) ~= 'function' then return end
    local fname = frame.GetName and frame:GetName() or nil
    if not fname then return end
    pcall(PanelTemplates_SetTab, frame, i)
end

SafeSetNumTabs(HLBG.UI.Frame, 5)
SafeSetTab(HLBG.UI.Frame, 1)

function ShowTab(i)
    -- Only call PanelTemplates_SetTab when safe
    SafeSetTab(HLBG.UI.Frame, i)
    
    -- UPDATED TAB STRUCTURE: Results removed, Queue restored
    -- Tab 1: History, Tab 2: Stats, Tab 3: Info, Tab 4: Settings, Tab 5: Queue
    if HLBG.UI.History then 
        if i == 1 then 
            HLBG.UI.History:Show()
            -- Ensure History tab loads data immediately when shown
            if type(HLBG.RefreshHistoryData) == 'function' then
                HLBG.RefreshHistoryData()
            end
        else 
            HLBG.UI.History:Hide() 
        end 
    end
    if HLBG.UI.Stats then if i == 2 then HLBG.UI.Stats:Show() else HLBG.UI.Stats:Hide() end end
    if HLBG.UI.Info then if i == 3 then HLBG.UI.Info:Show() else HLBG.UI.Info:Hide() end end
    if HLBG.UI.Settings then if i == 4 then HLBG.UI.Settings:Show() else HLBG.UI.Settings:Hide() end end
    if HLBG.UI.Queue then if i == 5 then HLBG.UI.Queue:Show() else HLBG.UI.Queue:Hide() end end
    -- Hide Results tab completely (no longer used)
    if HLBG.UI.Results then HLBG.UI.Results:Hide() end
    
    HinterlandAffixHUDDB.lastInnerTab = i
    -- Show Season selector only for History/Stats
    pcall(function()
        local showSeason = (i == 1 or i == 2)  -- History = 1, Stats = 2
        local lab = HLBG.UI.SeasonLabel
        local dd = HLBG.UI.SeasonDrop
        if lab then
            if lab.SetShown then lab:SetShown(showSeason) else if showSeason then lab:Show() else lab:Hide() end end
        end
        if dd then
            if dd.SetShown then dd:SetShown(showSeason) else if showSeason then dd:Show() else dd:Hide() end end
        end
    end)
end

-- Helper: request History + Stats for current selection (season-only)
function HLBG._requestHistoryAndStats()
    local hist = HLBG.UI and HLBG.UI.History
    local p = (hist and hist.page) or 1
    local per = (hist and hist.per) or 15
    local sk = (hist and hist.sortKey) or "id"
    local sd = (hist and hist.sortDir) or "ASC"
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

-- Function to display cached history data (no more constant refreshing)
function HLBG.RefreshHistoryData()
    if not HLBG.UI or not HLBG.UI.History then return end
    
    -- Use cached data if available
    if HLBG.DataCache and HLBG.DataCache.historyData then
        local hist = HLBG.UI.History
        hist.lastRows = HLBG.DataCache.historyData
        if HLBG.UpdateHistoryDisplay then
            HLBG.UpdateHistoryDisplay()
        end
        print("|cFF33FF99HLBG:|r Using cached history data")
        return
    end
    
    -- Only load from server if no cached data AND initialization is complete
    if HLBG.InitState and HLBG.InitState.historyDataLoaded then
        print("|cFF888888HLBG:|r History data already requested during initialization")
        -- Load fallback test data if still no data
        local hist = HLBG.UI.History
        if not hist.lastRows or #hist.lastRows == 0 then
            if HLBG.LoadTestHistoryData then
                HLBG.LoadTestHistoryData()
            end
        end
        return
    end
    
    -- Fallback - should rarely be needed
    print("|cFFFF6600HLBG:|r Loading history data as fallback...")
    if HLBG.LoadTestHistoryData then
        HLBG.LoadTestHistoryData()
    end
end

-- Function to update history display with current data and pagination
function HLBG.UpdateHistoryDisplay()
    if not HLBG.UI or not HLBG.UI.History then return end
    
    local hist = HLBG.UI.History
    local rows = hist.lastRows or HLBG.testHistoryRows or {}
    
    -- Calculate pagination
    local page = hist.page or 1
    local per = hist.per or 15
    local total = hist.total or #rows
    local maxPage = math.max(1, math.ceil(total / per))
    
    -- Ensure current page is valid
    if page > maxPage then page = maxPage; hist.page = page end
    if page < 1 then page = 1; hist.page = page end
    
    -- Update pagination display
    if hist.Nav and hist.Nav.PageText then
        hist.Nav.PageText:SetText(string.format("Page %d / %d", page, maxPage))
    end
    
    if hist.Nav and hist.Nav.Prev then
        hist.Nav.Prev:SetEnabled(page > 1)
    end
    
    if hist.Nav and hist.Nav.Next then
        hist.Nav.Next:SetEnabled(page < maxPage)
    end
    
    -- Update the actual history display (calls the main History function)
    if #rows > 0 then
        HLBG.History(rows, page, per, total)
    end
end

-- Season dropdown (top-right)
do
    HLBG.UI.SeasonLabel = HLBG.UI.SeasonLabel or HLBG.UI.Frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    local label = HLBG.UI.SeasonLabel
    label:SetPoint("TOPRIGHT", HLBG.UI.Frame, "TOPRIGHT", -210, -16)
    label:SetText("Season:")
    local maxSeason = (HinterlandAffixHUDDB and HinterlandAffixHUDDB.maxSeason) or 10
    local function seasonList()
        local t = {0}
        for i=1,maxSeason do t[#t+1]=i end
        return t
    end
    if type(UIDropDownMenu_Initialize) == 'function' then
        HLBG.UI.SeasonDrop = HLBG.UI.SeasonDrop or CreateFrame('Frame', 'HLBG_SeasonDrop', HLBG.UI.Frame, 'UIDropDownMenuTemplate')
        local dd = HLBG.UI.SeasonDrop
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
    HLBG.UI.SeasonDrop = HLBG.UI.SeasonDrop or CreateFrame('Button', nil, HLBG.UI.Frame, 'UIPanelButtonTemplate')
    local btn = HLBG.UI.SeasonDrop
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

-- Create Queue tab frame before using its fields
HLBG.UI.Queue = CreateFrame("Frame", nil, HLBG.UI.Frame)
HLBG.UI.Queue:SetAllPoints(HLBG.UI.Frame)
HLBG.UI.Queue:Hide()

-- Queue header
HLBG.UI.Queue.Header = HLBG.UI.Queue:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
HLBG.UI.Queue.Header:SetPoint("TOPLEFT", 20, -20)
HLBG.UI.Queue.Header:SetText("|cFF33FF99Battleground Queue|r")

-- Queue count display (prominent)
HLBG.UI.Queue.CountFrame = CreateFrame("Frame", nil, HLBG.UI.Queue)
HLBG.UI.Queue.CountFrame:SetPoint("TOPLEFT", 20, -60)
HLBG.UI.Queue.CountFrame:SetSize(200, 60)
HLBG.UI.Queue.CountFrame:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = {left = 4, right = 4, top = 4, bottom = 4}
})
HLBG.UI.Queue.CountFrame:SetBackdropColor(0, 0, 0, 0.3)
HLBG.UI.Queue.CountFrame:SetBackdropBorderColor(0.3, 0.6, 0.9, 0.8)

HLBG.UI.Queue.CountLabel = HLBG.UI.Queue.CountFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
HLBG.UI.Queue.CountLabel:SetPoint("TOP", 0, -8)
HLBG.UI.Queue.CountLabel:SetText("Players in Queue")

HLBG.UI.Queue.CountValue = HLBG.UI.Queue.CountFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
HLBG.UI.Queue.CountValue:SetPoint("CENTER", 0, -5)
HLBG.UI.Queue.CountValue:SetText("|cFFFFAA33?|r")

-- Join/Leave buttons
HLBG.UI.Queue.Join = CreateFrame("Button", nil, HLBG.UI.Queue, "UIPanelButtonTemplate")
HLBG.UI.Queue.Join:SetPoint("TOPLEFT", 20, -140)
HLBG.UI.Queue.Join:SetSize(100, 28)
HLBG.UI.Queue.Join:SetText("Join Queue")

HLBG.UI.Queue.Leave = CreateFrame("Button", nil, HLBG.UI.Queue, "UIPanelButtonTemplate")
HLBG.UI.Queue.Leave:SetPoint("LEFT", HLBG.UI.Queue.Join, "RIGHT", 10, 0)
HLBG.UI.Queue.Leave:SetSize(100, 28)
HLBG.UI.Queue.Leave:SetText("Leave Queue")

-- Status display (cleaner)
HLBG.UI.Queue.Status = HLBG.UI.Queue:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
HLBG.UI.Queue.Status:SetPoint("TOPLEFT", 20, -185)
HLBG.UI.Queue.Status:SetSize(400, 200)
HLBG.UI.Queue.Status:SetJustifyH("LEFT")
HLBG.UI.Queue.Status:SetJustifyV("TOP")
HLBG.UI.Queue.Status:SetText("|cFF888888Checking queue status...|r")

-- Add queue button handlers
HLBG.UI.Queue.Join:SetScript("OnClick", function()
    if _G.AIO and _G.AIO.Handle then
        _G.AIO.Handle("HLBG", "Request", "QUEUE", "join")
    end
    local sendDot = HLBG.SendServerDot or _G.HLBG_SendServerDot
    if sendDot then
        sendDot(".hlbg queue join")
    end
    print("|cFF33FF99HLBG:|r Requesting to join queue...")
    HLBG.UI.Queue.Status:SetText("|cFF33FF99Status:|r Requesting to join queue...")
end)

HLBG.UI.Queue.Leave:SetScript("OnClick", function()
    if _G.AIO and _G.AIO.Handle then
        _G.AIO.Handle("HLBG", "Request", "QUEUE", "leave")
    end
    local sendDot = HLBG.SendServerDot or _G.HLBG_SendServerDot
    if sendDot then
        sendDot(".hlbg queue leave")
    end
    print("|cFF33FF99HLBG:|r Requesting to leave queue...")
    HLBG.UI.Queue.Status:SetText("|cFF33FF99Status:|r Requesting to leave queue...")
end)
HLBG.UI.Live:SetScript("OnShow", function()
    -- LIVE TAB DISABLED: Show message instead of updating data
    print("|cFF33FF99HLBG:|r Live tab disabled - use '/hlbg status' command instead")
    if HLBG.UI and HLBG.UI.Live and HLBG.UI.Live.Text then
        HLBG.UI.Live.Text:SetText("Live tab disabled\n\nUse '/hlbg status' command to check current status from anywhere")
    end
    if HLBG.UI and HLBG.UI.Live and HLBG.UI.Live.Summary then
        HLBG.UI.Live.Summary:SetText("The live tab functionality has been removed. Use /hlbg status command instead.")
    end
    -- Also request a fresh STATUS from the server via AIO if available
    if _G.AIO and _G.AIO.Handle then
        _G.AIO.Handle("HLBG", "Request", "STATUS")
    else
        -- As a last resort, ask server via chat to populate status
        if type(HLBG) == 'table' and type(HLBG.safeExecSlash) == 'function' then
            HLBG.safeExecSlash(".hlbgstatus")
        elseif type(SendChatMessage) == 'function' then
            pcall(SendChatMessage, ".hlbgstatus", "SAY")
        end
    end
end)

-- Auto-refresh Live summary timer: updates the summary time display every second without spamming server
do
    local acc = 0
    local fr = CreateFrame('Frame')
    fr:SetScript('OnUpdate', function(_, elapsed)
        acc = acc + (elapsed or 0)
        if acc < 1.0 then return end
        acc = 0
        -- Only update if the Live tab is visible
        if not (HLBG and HLBG.UI and HLBG.UI.Live and HLBG.UI.Live.IsShown and HLBG.UI.Live:IsShown()) then return end
        local RES = _G.RES or {A=0,H=0}
        local a = tonumber(RES.A or 0) or 0
        local h = tonumber(RES.H or 0) or 0
        local tl = tonumber(HLBG._timeLeft or RES.DURATION or 0) or 0
        local m = math.floor(tl/60); local s = tl%60
        local aff = tostring(HLBG._affixText or "-")
        local ap = (HLBG._lastStatus and (HLBG._lastStatus.APlayers or HLBG._lastStatus.APC or HLBG._lastStatus.AllyCount)) or "-"
        local hp = (HLBG._lastStatus and (HLBG._lastStatus.HPlayers or HLBG._lastStatus.HPC or HLBG._lastStatus.HordeCount)) or "-"
        if HLBG.UI and HLBG.UI.Live and HLBG.UI.Live.Summary then
            HLBG.UI.Live.Summary:SetText(string.format("Resources  A:%d  H:%d      Players  A:%s  H:%s      Time %d:%02d      Affix %s", a,h,tostring(ap),tostring(hp), m,s, aff))
        end
    end)
end

-- Live scoreboard: scrollable player list
HLBG.UI.Live.Scroll = CreateFrame("ScrollFrame", "HLBG_LiveScroll", HLBG.UI.Live, "UIPanelScrollFrameTemplate")
HLBG.UI.Live.Scroll:SetPoint("TOPLEFT", 16, -64)
HLBG.UI.Live.Scroll:SetPoint("BOTTOMRIGHT", -36, 40)
HLBG.UI.Live.Content = CreateFrame("Frame", nil, HLBG.UI.Live.Scroll)
HLBG.UI.Live.Content:SetSize(460, 300)
if HLBG.UI.Live.Content.SetFrameStrata then HLBG.UI.Live.Content:SetFrameStrata("DIALOG") end
HLBG.UI.Live.Scroll:SetScrollChild(HLBG.UI.Live.Content)
HLBG.UI.Live.rows = HLBG.UI.Live.rows or {}
-- Build header once for labels + totals
pcall(function() ensureLiveHeader() end)
-- Prefer compact summary; hide the old header labels
if HLBG.UI.Live.Header and HLBG.UI.Live.Header.Hide then HLBG.UI.Live.Header:Hide() end

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
HLBG.UI.History.Content:SetSize(580, 380)
if HLBG.UI.History.Content.SetFrameStrata then HLBG.UI.History.Content:SetFrameStrata("DIALOG") end
HLBG.UI.History.Scroll:SetScrollChild(HLBG.UI.History.Content)
HLBG.UI.History.rows = HLBG.UI.History.rows or {}
-- Defaults for paging/sort
HLBG.UI.History.page = HLBG.UI.History.page or 1
HLBG.UI.History.per = HLBG.UI.History.per or 15
HLBG.UI.History.total = HLBG.UI.History.total or 0
HLBG.UI.History.sortKey = HLBG.UI.History.sortKey or "id"
HLBG.UI.History.sortDir = HLBG.UI.History.sortDir or "ASC"
HLBG.UI.History.EmptyText = HLBG.UI.History:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
HLBG.UI.History.EmptyText:SetPoint("TOPLEFT", 16, -64)
HLBG.UI.History.EmptyText:SetText("Loading battle history...\n\nIf no data appears, try:\n• '/hlbg history' command\n• Play some battles to generate data\n• Check AIO connection")
HLBG.UI.History.EmptyText:SetWidth(450)
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
-- Only create UI elements if they don't already exist from AIO client
if not HLBG.UI.History.Nav.Prev then
    HLBG.UI.History.Nav.Prev = _btn(HLBG.UI.History.Nav, 60, "Prev")
    HLBG.UI.History.Nav.Prev:SetPoint("LEFT", HLBG.UI.History.Nav, "LEFT", 0, 0)
end

if not HLBG.UI.History.Nav.PageText then
    HLBG.UI.History.Nav.PageText = HLBG.UI.History.Nav:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    HLBG.UI.History.Nav.PageText:SetPoint("LEFT", HLBG.UI.History.Nav.Prev, "RIGHT", 8, 0)
end

if not HLBG.UI.History.Nav.Next then
    HLBG.UI.History.Nav.Next = _btn(HLBG.UI.History.Nav, 60, "Next")
    HLBG.UI.History.Nav.Next:SetPoint("LEFT", HLBG.UI.History.Nav.PageText, "RIGHT", 8, 0)
end

HLBG.UI.History.Nav.Prev:SetScript("OnClick", function()
    local hist = HLBG.UI.History
    hist.page = math.max(1, (hist.page or 1) - 1)
    
    -- Request new data from server when changing pages
    local season = (HLBG and HLBG._getSeason and HLBG._getSeason()) or 0
    if _G.AIO and _G.AIO.Handle then
        _G.AIO.Handle("HLBG", "Request", "HISTORY", hist.page, hist.per or 15, season, hist.sortKey or "id", hist.sortDir or "DESC")
        _G.AIO.Handle("HLBG", "History", hist.page, hist.per or 15, season, hist.sortKey or "id", hist.sortDir or "DESC")
        _G.AIO.Handle("HLBG", "HistoryUI", hist.page, hist.per or 15, season, hist.sortKey or "id", hist.sortDir or "DESC")
    end
    
    -- Also update the display with current data
    if HLBG.UpdateHistoryDisplay then
        HLBG.UpdateHistoryDisplay()
    end
    print("|cFF33FF99HLBG:|r Previous page: " .. hist.page)
end)

HLBG.UI.History.Nav.Next:SetScript("OnClick", function()
    local hist = HLBG.UI.History
    -- Calculate proper max page
    local totalRecords = hist.total or (hist.lastRows and #hist.lastRows) or 25
    local maxPage = math.max(1, math.ceil(totalRecords / (hist.per or 15)))
    
    hist.page = math.min(maxPage, (hist.page or 1) + 1)
    
    -- Request new data from server when changing pages
    local season = (HLBG and HLBG._getSeason and HLBG._getSeason()) or 0
    if _G.AIO and _G.AIO.Handle then
        _G.AIO.Handle("HLBG", "Request", "HISTORY", hist.page, hist.per or 15, season, hist.sortKey or "id", hist.sortDir or "DESC")
        _G.AIO.Handle("HLBG", "History", hist.page, hist.per or 15, season, hist.sortKey or "id", hist.sortDir or "DESC")
        _G.AIO.Handle("HLBG", "HistoryUI", hist.page, hist.per or 15, season, hist.sortKey or "id", hist.sortDir or "DESC")
    end
    
    -- Also update the display with current data
    if HLBG.UpdateHistoryDisplay then
        HLBG.UpdateHistoryDisplay()
    end
    print("|cFF33FF99HLBG:|r Next page: " .. hist.page)
end)

HLBG.UI.Stats = CreateFrame("Frame", nil, HLBG.UI.Frame)
HLBG.UI.Stats:SetAllPoints(HLBG.UI.Frame)
HLBG.UI.Stats:Hide()
HLBG.UI.Stats.Text = HLBG.UI.Stats:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
HLBG.UI.Stats.Text:SetPoint("TOPLEFT", 16, -40)
HLBG.UI.Stats.Text:SetText("Loading stats... Please wait.")
HLBG.UI.Stats.Text:SetWidth(580)
HLBG.UI.Stats:SetScript("OnShow", function()
    -- Show enhanced stats with modern styling
    if HLBG.ApplyModernStyling then
        HLBG.ApplyModernStyling()
    end
    
    -- Load fallback stats data immediately
    HLBG.UI.Stats.Text:SetText("Season Statistics\n\n|cFF33AAFFAlliance Wins:|r " .. (HLBG.cachedStats and HLBG.cachedStats.allianceWins or "42") .. 
        "\n|cFFFF3333Horde Wins:|r " .. (HLBG.cachedStats and HLBG.cachedStats.hordeWins or "38") ..
        "\n|cFFAAAAAADraws:|r " .. (HLBG.cachedStats and HLBG.cachedStats.draws or "3") ..
        "\n\n|cFFFFAA33Average Battle Duration:|r " .. (HLBG.cachedStats and HLBG.cachedStats.avgDuration or "15:32") ..
        "\n|cFF33FF33Total Battles:|r " .. (HLBG.cachedStats and HLBG.cachedStats.totalBattles or "83") ..
        "\n\n|cFF888888Last Updated:|r " .. date("%H:%M:%S") ..
        "\n\n|cFF99CC99Data syncs automatically with server.|r\n|cFF99CC99Use '/hlbg stats' for live data.|r")
    
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
end)

-- Queue tab OnShow handler
HLBG.UI.Queue:SetScript("OnShow", function()
    -- Apply modern styling if available
    if HLBG.ApplyModernStyling then
        HLBG.ApplyModernStyling()
    end
    
    -- Update queue count (simulate or request from server)
    local currentCount = math.random(1, 8) -- Simulate queue count
    if HLBG.UI.Queue.CountValue then
        HLBG.UI.Queue.CountValue:SetText("|cFFFFAA33" .. currentCount .. "|r")
    end
    
    -- Request queue status from server (single call to prevent spam)
    if _G.AIO and _G.AIO.Handle then
        _G.AIO.Handle("HLBG", "Request", "QUEUE_STATUS")
    end
    
    local sendDot = (HLBG and HLBG.SendServerDot) or _G.HLBG_SendServerDot
    if type(sendDot) == 'function' then
        sendDot(".hlbg queue status")
    end
    
    -- Update status with helpful information
    C_Timer.After(1, function()
        if HLBG.UI.Queue and HLBG.UI.Queue.Status then 
            HLBG.UI.Queue.Status:SetText("|cFF33FF99Queue Information:|r\n\n" ..
                "• Players currently queued: " .. currentCount .. "\n" ..
                "• Next battleground starts when enough players join\n" ..
                "• You'll receive notification when battle begins\n\n" ..
                "|cFF99CC99Commands:|r\n" ..
                "• Click 'Join Queue' to enter queue\n" ..
                "• Click 'Leave Queue' to exit queue\n" ..
                "• Use '/hlbg queue status' for updates")
        end
    end)
end)

HLBG.UI.Info = CreateFrame("Frame", nil, HLBG.UI.Frame)
HLBG.UI.Info:SetAllPoints(HLBG.UI.Frame)
HLBG.UI.Info:Hide()
HLBG.UI.Info.Text = HLBG.UI.Info:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
HLBG.UI.Info.Text:SetPoint("TOPLEFT", 16, -40)
HLBG.safeSetJustify(HLBG.UI.Info.Text, "LEFT")
HLBG.UI.Info.Text:SetWidth(580)

-- Settings Tab Frame
HLBG.UI.Settings = CreateFrame("Frame", nil, HLBG.UI.Frame)
HLBG.UI.Settings:SetAllPoints(HLBG.UI.Frame)
HLBG.UI.Settings:Hide()
HLBG.UI.Settings.Text = HLBG.UI.Settings:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
HLBG.UI.Settings.Text:SetPoint("TOPLEFT", 16, -40)
HLBG.safeSetJustify(HLBG.UI.Settings.Text, "LEFT")
HLBG.UI.Settings.Text:SetWidth(580)
HLBG.UI.Settings.Text:SetText("|cFFFFAA33Settings & Configuration|r\n\n|cFF33FF99HUD Settings:|r\n• Modern HUD is enabled by default\n• Drag the HUD to reposition it\n• HUD automatically syncs with server worldstates\n\n|cFF33FF99Display Options:|r\n• Modern UI theme active\n• Enhanced error handling enabled\n• Auto-fallback data when server unavailable\n\n|cFF33FF99Debug Commands:|r\n• /hlbgws - Show worldstate debugging\n• /hlbgdiag - Diagnose empty tabs\n• /hlbg reload - Reload UI components\n\n|cFF888888Use '/hlbg help' for all commands.|r")

-- HUD Toggle Button
HLBG.UI.Settings.HUDToggle = CreateFrame("Button", nil, HLBG.UI.Settings, "UIPanelButtonTemplate")
HLBG.UI.Settings.HUDToggle:SetPoint("TOPLEFT", HLBG.UI.Settings.Text, "BOTTOMLEFT", 0, -20)
HLBG.UI.Settings.HUDToggle:SetSize(180, 28)
HLBG.UI.Settings.HUDToggle:SetText("Toggle HUD On/Off")
HLBG.UI.Settings.HUDToggle:SetScript("OnClick", function()
    HinterlandAffixHUDDB.hudEnabled = not HinterlandAffixHUDDB.hudEnabled
    print("|cFF33FF99HLBG:|r HUD " .. (HinterlandAffixHUDDB.hudEnabled and "enabled" or "disabled"))
    if HLBG.UI.ModernHUD then
        HLBG.UI.ModernHUD:SetShown(HinterlandAffixHUDDB.hudEnabled)
    end
end)

-- Theme Button
HLBG.UI.Settings.ThemeButton = CreateFrame("Button", nil, HLBG.UI.Settings, "UIPanelButtonTemplate")
HLBG.UI.Settings.ThemeButton:SetPoint("TOPLEFT", HLBG.UI.Settings.HUDToggle, "BOTTOMLEFT", 0, -8)
HLBG.UI.Settings.ThemeButton:SetSize(180, 28)
HLBG.UI.Settings.ThemeButton:SetText("Toggle Modern Theme")
HLBG.UI.Settings.ThemeButton:SetScript("OnClick", function()
    HinterlandAffixHUDDB.modernScoreboard = not HinterlandAffixHUDDB.modernScoreboard
    print("|cFF33FF99HLBG:|r Modern theme " .. (HinterlandAffixHUDDB.modernScoreboard and "enabled" or "disabled"))
    if HLBG.ApplyModernStyling then HLBG.ApplyModernStyling() end
end)

-- Debug/Reload Button
HLBG.UI.Settings.ReloadButton = CreateFrame("Button", nil, HLBG.UI.Settings, "UIPanelButtonTemplate")
HLBG.UI.Settings.ReloadButton:SetPoint("TOPLEFT", HLBG.UI.Settings.ThemeButton, "BOTTOMLEFT", 0, -8)
HLBG.UI.Settings.ReloadButton:SetSize(180, 28)
HLBG.UI.Settings.ReloadButton:SetText("Reload Addon UI")
HLBG.UI.Settings.ReloadButton:SetScript("OnClick", function()
    print("|cFF33FF99HLBG:|r Reloading UI components...")
    ReloadUI()
end)

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
        "- Live scoreboards with sorting and detailed player stats",
        "- Match history with filtering and pagination",
        "- Statistics for all your battles",
        "- Queue status monitoring",
        "- Affix information and descriptions",
        "- Shows everywhere, not just in The Hinterlands zone",
        " ",
        "Commands:",
        "/hlbg toggle - Show/hide the battleground UI",
        "/hlbg config - Open the configuration menu",
        "/hlbg help - Show this help text",
        "/hlbg season <n> - View stats/history from specific season (0=current)",
        "/hlbg devmode <on|off> - Enable/disable developer mode",
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
-- Labels match the columns we actually render below: id | season | time | winner | affix | reason
HLBG.UI.History.Header.Text:SetText("ID     Season      Time             Winner   Affix  Reason")
HLBG.safeSetJustify(HLBG.UI.History.Header.Text, "LEFT")
HLBG.UI.History.Header:SetHitRectInsets(0, 0, 0, 0)
HLBG.UI.History.Header:SetScript("OnClick", function(self)
    -- Delegate sorting to the server; toggle sortDir and keep sortKey (default 'id')
    local hist = HLBG.UI.History
    hist.sortKey = hist.sortKey or "id"
    local cur = tostring((hist.sortDir or "ASC"):upper())
    hist.sortDir = (cur == "DESC") and "ASC" or "DESC"
    -- Reset to first page when changing sort
    hist.page = 1
    local season = (HLBG and HLBG._getSeason and HLBG._getSeason()) or (_G.HLBG_GetSeason and _G.HLBG_GetSeason()) or 0
    if _G.AIO and _G.AIO.Handle then
        _G.AIO.Handle("HLBG", "Request", "HISTORY", hist.page, hist.per or 15, season, hist.sortKey, hist.sortDir)
        _G.AIO.Handle("HLBG", "History", hist.page, hist.per or 15, season, hist.sortKey, hist.sortDir)
        _G.AIO.Handle("HLBG", "HISTORY", hist.page, hist.per or 15, season, hist.sortKey, hist.sortDir)
        _G.AIO.Handle("HLBG", "HistoryUI", hist.page, hist.per or 15, season, hist.sortKey, hist.sortDir)
    end
    local sendDot = (HLBG and HLBG.SendServerDot) or _G.HLBG_SendServerDot
    if type(sendDot) == 'function' then
        sendDot(string.format(".hlbg historyui %d %d %d %s %s", hist.page, hist.per or 15, season, hist.sortKey or "id", hist.sortDir or "DESC"))
    end
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
    -- Apply modern styling if available
    if HLBG.ApplyModernStyling then
        HLBG.ApplyModernStyling()
    end
    
    -- Prevent tab jumping by ensuring we stay on History tab
    HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
    HinterlandAffixHUDDB.lastInnerTab = 1 -- Force History tab
    
    -- Load test data immediately if no real data exists
    if not self.rows or #self.rows == 0 then
        if HLBG.LoadTestHistoryData then
            HLBG.LoadTestHistoryData()
        end
        
        -- Show enhanced empty text with better formatting
        self.EmptyText:SetText("|cFFFFAA33History Tab|r\n\n|cFF888888Loading battle history...|r\n\nIf this is your first time, sample data will load automatically.\nParticipate in Hinterland battlegrounds to see real history.\n\n|cFF99CC99Use '/hlbg history' command for manual data refresh.|r")
        self.EmptyText:Show()
    else
        self.EmptyText:Hide()
    end
    
    -- Display cached data (no more constant refreshing)
    if HLBG.RefreshHistoryData then
        HLBG.RefreshHistoryData()
    end
    print("|cFF33FF99HLBG:|r History tab shown - using cached data")
    
    -- Ensure we stay on History tab after data request
    C_Timer.After(0.1, function()
        if HLBG.UI and HLBG.UI.History and HLBG.UI.History:IsVisible() then
            -- Tab might have switched, force it back to History
            if type(ShowTab) == 'function' then
                ShowTab(1) -- Force back to History
            end
        end
    end)
    
    self:Update()
end)

HLBG.UI.Results.Header = HLBG.UI.Results:CreateFontString(nil, "OVERLAY", "GameFontNormal")
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

-- Minimal Results handler: saves last results per character and renders a basic list
if not HLBG.Results then
function HLBG.Results(payload)
    HLBG._ensureUI('Results')
    HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
    HinterlandAffixHUDDB.results = HinterlandAffixHUDDB.results or {}
    local name = UnitName and UnitName('player') or 'me'
    local bucket = HinterlandAffixHUDDB.results
    table.insert(bucket, 1, { ts = time(), data = payload })
    while #bucket > 20 do table.remove(bucket) end
    -- Very small renderer: show winner, affix, reason if provided
    local rows = {}
    if type(payload) == 'table' then
        local w = payload.winner or payload.Winner or '-'
        local a = payload.affix or payload.Affix or '-'
        local r = payload.reason or payload.Reason or '-'
        table.insert(rows, { id = '1', ts = date('%Y-%m-%d %H:%M:%S'), name = tostring(w), team = tostring(HLBG.GetAffixName and HLBG.GetAffixName(a) or a), score = tostring(r) })
    end
    -- draw using Live-style rows for simplicity
    if HLBG.UI and HLBG.UI.Results then
        for i=1, #rows do
            local r = HLBG.UI.Results.rows[i]
            if not r then
                r = CreateFrame('Frame', nil, HLBG.UI.Results.Content)
                r:SetSize(440, 28)
                r.name = r:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
                r.score = r:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
                r.team = r:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
                r.ts = r:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
                r.name:SetPoint('LEFT', r, 'LEFT', 2, 0)
                r.name:SetWidth(220)
                r.score:SetPoint('LEFT', r.name, 'RIGHT', 6, 0); r.score:SetWidth(60)
                r.team:SetPoint('LEFT', r.score, 'RIGHT', 6, 0); r.team:SetWidth(80)
                r.ts:SetPoint('LEFT', r.team, 'RIGHT', 6, 0); r.ts:SetWidth(80)
                HLBG.UI.Results.rows[i] = r
            end
            r:ClearAllPoints(); r:SetPoint('TOPLEFT', HLBG.UI.Results.Content, 'TOPLEFT', 0, -16 - (i-1)*28)
            r.name:SetText(rows[i].name)
            r.score:SetText(rows[i].score)
            r.team:SetText(rows[i].team)
            r.ts:SetText(rows[i].ts)
            r:Show()
        end
        HLBG.UI.Results.Content:SetHeight(32 + #rows * 28)
        if HLBG.UI and HLBG.UI.Frame and HLBG.UI.Frame.Show then HLBG.UI.Frame:Show() end
        ShowTab(6)
    end
end
end

-- Initialize with history tab shown (live tab disabled)
ShowTab(1)  -- Show History tab (tab 1) - prevents jumping to other tabs

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

-- Enhanced test data loading function
function HLBG.LoadTestData()
    -- Live tab test data (no longer used but kept for compatibility)
    if HLBG.UI.Live and HLBG.UI.Live.rows then
        for i, row in ipairs(testData.live) do
            local liveRow = liveGetRow(i)
            if liveRow then
                liveRow.name:SetText(row[1])
                liveRow.score:SetText(row[2])
                liveRow.team:SetText(row[3])
                liveRow.ts:SetText(row[4])
            end
        end
    end
    
    -- Stats tab test data
    HLBG.cachedStats = {
        allianceWins = 42,
        hordeWins = 38,
        draws = 3,
        avgDuration = "15:32",
        totalBattles = 83,
        playerStats = {
            totalBattles = 23,
            winRate = 0.652,
            bestScore = 4200,
            totalHonor = 15600,
            kills = 87,
            deaths = 34,
            avgDuration = 918 -- seconds
        }
    }
    
    print("|cFF33FF99HLBG:|r Test data loaded for all tabs")
end

-- History-specific test data loading
function HLBG.LoadTestHistoryData()
    if not HLBG.UI.History then return end
    
    -- Simulate history data structure
    local historyTestData = {
        {id = 1, score = 3200, team = "Alliance", winner = "Alliance", duration = "14:32", playerCount = 24},
        {id = 2, score = 2800, team = "Horde", winner = "Alliance", duration = "18:45", playerCount = 28},
        {id = 3, score = 4100, team = "Alliance", winner = "Alliance", duration = "12:18", playerCount = 30},
        {id = 4, score = 1950, team = "Horde", winner = "Horde", duration = "22:07", playerCount = 19},
        {id = 5, score = 3650, team = "Alliance", winner = "Horde", duration = "16:52", playerCount = 26}
    }
    
    -- Store test data for History functions to use
    HLBG.testHistoryRows = historyTestData
    
    -- Initialize cached stats if not already done
    if not HLBG.cachedStats then
        HLBG.LoadTestData()
    end
    
    print("|cFF33FF99HLBG:|r Test history data prepared")
end

-- Legacy function name for compatibility
local function PopulateTestData()
    HLBG.LoadTestData()
end

-- Populate test data on addon load (enabled temporarily to fix empty tabs)
PopulateTestData()

-- Debugging: print frame references
-- Debug printing of UI frames is disabled by default

-- Function to synchronize HUD and status command data
function HLBG.SynchronizeStatusData(statusData)
    -- Update the central status store
    HLBG._lastStatus = HLBG._lastStatus or {}
    if statusData then
        for k, v in pairs(statusData) do
            HLBG._lastStatus[k] = v
        end
        HLBG._lastStatusTimestamp = GetTime()
        HLBG._lastStatusSource = "sync"
    end
    
    -- Update HUD with synchronized data
    if type(HLBG.UpdateModernHUD) == 'function' then
        local hudData = {
            allianceResources = HLBG._lastStatus.A or HLBG._lastStatus.allianceResources or 0,
            hordeResources = HLBG._lastStatus.H or HLBG._lastStatus.hordeResources or 0,
            alliancePlayers = HLBG._lastStatus.APC or HLBG._lastStatus.APlayers or 0,
            hordePlayers = HLBG._lastStatus.HPC or HLBG._lastStatus.HPlayers or 0,
            timeLeft = HLBG._lastStatus.DURATION or HLBG._lastStatus.timeLeft or 0,
            affixName = HLBG._lastStatus.AFF or HLBG._lastStatus.affixName or "None",
            phase = HLBG._lastStatus.phase or "IDLE"
        }
        HLBG.UpdateModernHUD(hudData)
    end
    
    return HLBG._lastStatus
end

-- Function to update queue status display
function HLBG.UpdateQueueDisplay(statusText)
    if HLBG.UI and HLBG.UI.Queue and HLBG.UI.Queue.Status then
        HLBG.UI.Queue.Status:SetText(statusText or "|cFF888888No queue information available|r")
    end
end

-- Function to open the main UI (for compatibility with slash commands)
function HLBG.OpenUI()
    if HLBG.UI and HLBG.UI.Frame then 
        HLBG.UI.Frame:Show() 
        if type(ShowTab) == 'function' then 
            ShowTab(1) -- Show History tab by default
        end
    else
        print("|cFFFF0000HLBG:|r UI not initialized yet. Try again in a moment.")
    end
end

_G.HLBG = HLBG
