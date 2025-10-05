-- HLBG_AIO.lua - AIO communication handlers for Hinterland Battleground

-- Ensure HLBG namespace exists
HLBG = HLBG or {}

-- Defensive fallback: ensure HLBG._ensureUI exists so calls like HLBG._ensureUI('X') do not
-- cause "attempt to call field '_ensureUI' (a nil value)" during early startup when the
-- UI initializer may not yet have run. Return false to indicate UI wasn't ready.
if type(HLBG._ensureUI) ~= 'function' then
    HLBG._ensureUI = function(...) return false end
end

-- Early-safe PrintStartupHistory: provide a minimal, immediate implementation so tools
-- that call /run HLBG.PrintStartupHistory(1) before deferred startup diagnostics can
-- still get a meaningful output. This will be preserved into the AIO-provided table
-- during registration because it exists at registration time.
if type(HLBG.PrintStartupHistory) ~= 'function' then
    HLBG.PrintStartupHistory = function(n)
        n = tonumber(n) or 1
        local hist = HinterlandAffixHUDDB and HinterlandAffixHUDDB.startupHistory
        if not hist or #hist == 0 then
            if type(HLBG.SafePrint) == 'function' then HLBG.SafePrint('HLBG: no startup history saved') else print('HLBG: no startup history saved') end
            return
        end
        if n < 1 then n = 1 end
        if n > #hist then n = #hist end
        local e = hist[n]
        if not e then return end
        if type(HLBG.SafePrint) == 'function' then
            HLBG.SafePrint(string.format('HLBG startup @ %s: AIO=%s handlers=%s ui=%s', date('%Y-%m-%d %H:%M:%S', e.ts), tostring(e.aio), tostring(e.handlers), tostring(e.ui)))
        else
            print(string.format('HLBG startup @ %s: AIO=%s handlers=%s ui=%s', date('%Y-%m-%d %H:%M:%S', e.ts), tostring(e.aio), tostring(e.handlers), tostring(e.ui)))
        end
    end
end

-- SafePrint should already be available from HLBG_EmergencyFix.lua
-- If not available, provide a minimal fallback
if type(HLBG.SafePrint) ~= 'function' then
    function HLBG.SafePrint(msg)
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, tostring(msg or ''))
        else
            print(tostring(msg or ''))
        end
    end
end

-- Small helper: safe debug print that falls back to SafePrint/print if HLBG.Debug isn't defined
local function safeDebug(...)
    local parts = {}
    for i=1, select('#', ...) do parts[i] = tostring(select(i, ...)) end
    local msg = table.concat(parts, ' ')
    if type(HLBG.Debug) == 'function' then pcall(HLBG.Debug, msg) end
    if type(HLBG.SafePrint) == 'function' then pcall(HLBG.SafePrint, msg) else pcall(print, msg) end
end

-- Skip global AddMessage shim since EmergencyFix already provides it
-- Just log that we're using the existing system
if HLBG._AddMessageShimInstalled then
    HLBG.SafePrint("HLBG_AIO: Using existing AddMessage shim from emergency fix")
end

-- Minimal UI open function if not defined elsewhere
if type(HLBG.OpenUI) ~= 'function' then
    function HLBG.OpenUI()
        if HLBG and HLBG.UI and HLBG.UI.Frame and type(HLBG.UI.Frame.Show) == 'function' then HLBG.UI.Frame:Show() end
        local last = (HinterlandAffixHUDDB and HinterlandAffixHUDDB.lastInnerTab) or 1
        if type(_G.ShowTab) == 'function' then pcall(_G.ShowTab, last) end
        if _G.AIO and _G.AIO.Handle then _G.AIO.Handle('HLBG','Request','STATUS') end
    end
end

-- Minimal History handler: draws basic rows as received from server (id, ts, winner, affix, reason)
if type(HLBG.History) ~= 'function' then
    function HLBG.History(rows, page, per, total, col, dir)
        if not HLBG._ensureUI('History') then return end
        rows = rows or {}
        local h = HLBG.UI.History
        h.page = page or 1; h.per = per or 10; h.total = total or #rows; h.sortKey = col or 'id'; h.sortDir = dir or 'DESC'
        -- hide old rows
        for i=1,#h.rows do h.rows[i]:Hide() end
        local function getRow(i)
            local r = h.rows[i]
            if not r then
                r = CreateFrame('Frame', nil, h.Content)
                r:SetSize(420, 14)
                r.id = r:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
                r.ts = r:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
                r.win = r:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
                r.aff = r:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
                r.rea = r:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
                r.id:SetPoint('LEFT', r, 'LEFT', 0, 0); r.id:SetWidth(50)
                r.ts:SetPoint('LEFT', r.id, 'RIGHT', 6, 0); r.ts:SetWidth(120)
                r.win:SetPoint('LEFT', r.ts, 'RIGHT', 6, 0); r.win:SetWidth(80)
                r.aff:SetPoint('LEFT', r.win, 'RIGHT', 6, 0); r.aff:SetWidth(70)
                r.rea:SetPoint('LEFT', r.aff, 'RIGHT', 6, 0); r.rea:SetWidth(50)
                h.rows[i] = r
            end
            return r
        end
        local y = -22
        for i, row in ipairs(rows) do
            local r = getRow(i)
            r:ClearAllPoints(); r:SetPoint('TOPLEFT', h.Content, 'TOPLEFT', 0, y)
            local id = row.id or row[1]
            local ts = row.ts or row[2]
            local win = row.winner or row[3]
            local aff = row.affix or row[4]
            local rea = row.reason or row[5]
            r.id:SetText(tostring(id or ''))
            r.ts:SetText(tostring(ts or ''))
            r.win:SetText(tostring(win or ''))
            r.aff:SetText((HLBG.GetAffixName and HLBG.GetAffixName(aff)) or tostring(aff or ''))
            r.rea:SetText(tostring(rea or ''))
            r:Show(); y = y - 14
        end
        h.Content:SetHeight(math.max(300, -y + 8))
        -- Update pager text and nav if available in fallback UI
        if h.Nav and h.Nav.PageText then
            local totalRows = tonumber(h.total or #rows) or #rows
            local perPage = tonumber(h.per or 10) or 10
            local maxPage = math.max(1, math.ceil((totalRows > 0 and totalRows or #rows)/perPage))
            h.Nav.PageText:SetText(string.format('Page %d / %d', h.page or 1, maxPage))
            if h.Nav.Prev then if (h.page or 1) > 1 then h.Nav.Prev:Enable() else h.Nav.Prev:Disable() end end
            if h.Nav.Next then if (h.page or 1) < maxPage then h.Nav.Next:Enable() else h.Nav.Next:Disable() end end
        end
        if HLBG.UI and HLBG.UI.Frame and not HLBG.UI.Frame:IsShown() then HLBG.UI.Frame:Show() end
    end
end

-- TSV fallback handler for history (AIO older builds or chat broadcast)
if type(HLBG.HistoryStr) ~= 'function' then
    function HLBG.HistoryStr(tsv, page, per, total, col, dir)
        local rows = {}
        if type(tsv) == 'string' and tsv ~= '' then
            -- Support custom separator '||' -> newline
            if tsv:find('%|%|') then tsv = tsv:gsub('%|%|','\n') end
            for line in tsv:gmatch('[^\n]+') do
                local id, ts, win, aff, rea = line:match('^(.-)\t(.-)\t(.-)\t(.-)\t(.*)$')
                if id then table.insert(rows, { id = id, ts = ts, winner = win, affix = aff, reason = rea }) end
            end
        end
        HLBG.History(rows, page, per, total, col, dir)
    end
end

-- Minimal Stats handler: show counts if provided; otherwise clear text
if type(HLBG.Stats) ~= 'function' then
    function HLBG.Stats(stats)
        HLBG._ensureUI('Stats')
        stats = stats or {}
        local counts = stats.counts or {}
        local a = tonumber(counts.Alliance or counts.ALLIANCE or 0) or 0
        local h = tonumber(counts.Horde or counts.HORDE or 0) or 0
        local d = tonumber(stats.draws or 0) or 0
        local avg = tonumber(stats.avgDuration or 0) or 0
        local lines = { string.format('Alliance: %d  Horde: %d  Draws: %d  Avg: %d min', a, h, d, math.floor(avg/60)) }
        if HLBG.UI and HLBG.UI.Stats and HLBG.UI.Stats.Text then HLBG.UI.Stats.Text:SetText(table.concat(lines, '\n')) end
        
        -- Save stats for UI modules to use
        HLBG._lastStats = stats
    end
end

-- Minimal Live handler: render resources and timer from last status payload
if type(HLBG.Live) ~= 'function' then
    function HLBG.Live(payload)
        -- Accept either raw status or rows list; prefer status already collected via chat/AIO
        HLBG._ensureUI('Live')
        HLBG.UpdateLiveFromStatus()
    end
end

-- Queue status handler
if type(HLBG.QueueStatus) ~= 'function' then
    function HLBG.QueueStatus(payload)
        HLBG._ensureUI('Queue')
        local q = HLBG.UI and HLBG.UI.QueuePane
        if not q then return end
        
        -- Parse string payloads from chat
        if type(payload) == 'string' then
            -- parse chat fallback: key=value|key=value
            local data = {}
            for kv in payload:gmatch('[^|]+') do
                local k,v = kv:match('^(%w+)%=(.+)$')
                if k then data[k] = v end
            end
            payload = data
        end
        
        payload = payload or {}
        
        -- Extract queue information
        local team = payload.team or '?'
        local pos = tonumber(payload.pos or 0) or 0
        local size = tonumber(payload.size or 0) or 0
        local eta = tonumber(payload.eta or 0) or 0
        local nextMatchTime = tonumber(payload.nextMatch or 0) or 0
        local aCount = tonumber(payload.countA or 0) or 0
        local hCount = tonumber(payload.countH or 0) or 0
        local isQueued = payload.isQueued or (pos > 0)
        local nextAffixId = payload.nextAffixId or payload.nextAffix or ""
        local nextAffixName = payload.nextAffixName or (nextAffixId and HLBG.GetAffixName and HLBG.GetAffixName(nextAffixId)) or "Unknown"
        local autoPort = (payload.autoPort and payload.autoPort ~= "0") or (payload.autoport and payload.autoport ~= "0")
        
        -- Store queue data
        q.lastQueueData = payload
        
        -- Ensure we have the necessary UI elements
        if not q.initialized then
            -- Header
            q.Header = CreateFrame("Frame", nil, q)
            q.Header:SetPoint("TOP", q, "TOP", 0, -10)
            q.Header:SetPoint("LEFT", q, "LEFT", 10, 0)
            q.Header:SetPoint("RIGHT", q, "RIGHT", -10, 0)
            q.Header:SetHeight(30)
            
            q.Title = q.Header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            q.Title:SetPoint("TOP", q.Header, "TOP", 0, 0)
            q.Title:SetText("Hinterland Battleground Queue")
            
            -- Status area
            q.StatusArea = CreateFrame("Frame", nil, q)
            q.StatusArea:SetPoint("TOP", q.Header, "BOTTOM", 0, -10)
            q.StatusArea:SetPoint("LEFT", q, "LEFT", 20, 0)
            q.StatusArea:SetPoint("RIGHT", q, "RIGHT", -20, 0)
            q.StatusArea:SetHeight(120)
            q.StatusArea:SetBackdrop({
                bgFile = "Interface/Tooltips/UI-Tooltip-Background",
                edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 16,
                insets = { left = 4, right = 4, top = 4, bottom = 4 }
            })
            q.StatusArea:SetBackdropColor(0, 0, 0, 0.5)
            
            -- Queue status text
            q.Status = q.StatusArea:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            q.Status:SetPoint("TOP", q.StatusArea, "TOP", 0, -10)
            q.Status:SetText("Not queued")
            
            -- Counts text
            q.Counts = q.StatusArea:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            q.Counts:SetPoint("TOP", q.Status, "BOTTOM", 0, -10)
            q.Counts:SetText("Queued: Alliance 0 | Horde 0 | Total 0")
            
            -- Next match info
            q.NextMatchTitle = q.StatusArea:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            q.NextMatchTitle:SetPoint("TOP", q.Counts, "BOTTOM", 0, -10)
            q.NextMatchTitle:SetText("Next Match:")
            
            q.NextMatchInfo = q.StatusArea:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            q.NextMatchInfo:SetPoint("TOP", q.NextMatchTitle, "BOTTOM", 0, -5)
            q.NextMatchInfo:SetText("No scheduled match")
            
            -- Queue buttons
            q.ButtonsArea = CreateFrame("Frame", nil, q)
            q.ButtonsArea:SetPoint("TOP", q.StatusArea, "BOTTOM", 0, -10)
            q.ButtonsArea:SetPoint("LEFT", q, "LEFT", 20, 0)
            q.ButtonsArea:SetPoint("RIGHT", q, "RIGHT", -20, 0)
            q.ButtonsArea:SetHeight(40)
            
            q.JoinButton = CreateFrame("Button", nil, q.ButtonsArea, "UIPanelButtonTemplate")
            q.JoinButton:SetSize(120, 24)
            q.JoinButton:SetPoint("LEFT", q.ButtonsArea, "LEFT", 10, 0)
            q.JoinButton:SetText("Join Queue")
            q.JoinButton:SetScript("OnClick", function()
                HLBG.RequestQueue("JOIN")
            end)
            
            q.LeaveButton = CreateFrame("Button", nil, q.ButtonsArea, "UIPanelButtonTemplate")
            q.LeaveButton:SetSize(120, 24)
            q.LeaveButton:SetPoint("LEFT", q.JoinButton, "RIGHT", 20, 0)
            q.LeaveButton:SetText("Leave Queue")
            q.LeaveButton:SetScript("OnClick", function()
                HLBG.RequestQueue("LEAVE")
            end)
            
            -- Settings area
            q.SettingsArea = CreateFrame("Frame", nil, q)
            q.SettingsArea:SetPoint("TOP", q.ButtonsArea, "BOTTOM", 0, -10)
            q.SettingsArea:SetPoint("LEFT", q, "LEFT", 20, 0)
            q.SettingsArea:SetPoint("RIGHT", q, "RIGHT", -20, 0)
            q.SettingsArea:SetHeight(60)
            q.SettingsArea:SetBackdrop({
                bgFile = "Interface/Tooltips/UI-Tooltip-Background",
                edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 16,
                insets = { left = 4, right = 4, top = 4, bottom = 4 }
            })
            q.SettingsArea:SetBackdropColor(0, 0, 0, 0.3)
            
            -- Auto-teleport checkbox
            q.AutoTeleport = CreateFrame("CheckButton", "HLBG_AutoTeleportCheck", q.SettingsArea, "UICheckButtonTemplate")
            q.AutoTeleport:SetPoint("TOPLEFT", q.SettingsArea, "TOPLEFT", 10, -10)
            _G[q.AutoTeleport:GetName().."Text"]:SetText("Auto-teleport when match starts")
            
            -- Load value from saved variables
            q.AutoTeleport:SetChecked((HinterlandAffixHUDDB and HinterlandAffixHUDDB.autoTeleport) or false)
            
            -- Save value when changed
            q.AutoTeleport:SetScript("OnClick", function(self)
                local checked = self:GetChecked()
                HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
                HinterlandAffixHUDDB.autoTeleport = checked
                -- Send the preference to server
                if _G.AIO and _G.AIO.Handle then
                    _G.AIO.Handle("HLBG", "SetPreference", "autoTeleport", checked and "1" or "0")
                end
            end)
            
            -- Timer for queue updates
            q.timer = CreateFrame("Frame")
            q.timer.elapsed = 0
            q.timer.interval = 1 -- Update every second
            q.timer:SetScript("OnUpdate", function(self, elapsed)
                self.elapsed = self.elapsed + elapsed
                if self.elapsed >= self.interval then
                    self.elapsed = 0
                    -- Update ETA and next match countdown if we have data
                    if q.lastQueueData then
                        if q.lastQueueData.eta and q.lastQueueData.eta > 0 then
                            q.lastQueueData.eta = q.lastQueueData.eta - 1
                            if q.Status then
                                local pos = tonumber(q.lastQueueData.pos or 0) or 0
                                local size = tonumber(q.lastQueueData.size or 0) or 0
                                local eta = q.lastQueueData.eta
                                local team = q.lastQueueData.team or "?"
                                q.Status:SetText(string.format('Queue: %s — position %d of %d (ETA %s)', 
                                    tostring(team), pos, size, HLBG._fmtETA and HLBG._fmtETA(eta) or tostring(eta)..'s'))
                            end
                        end
                        
                        if q.lastQueueData.nextMatch and q.lastQueueData.nextMatch > 0 then
                            q.lastQueueData.nextMatch = q.lastQueueData.nextMatch - 1
                            if q.NextMatchInfo then
                                local nextMatch = q.lastQueueData.nextMatch
                                local nextAffix = q.lastQueueData.nextAffixName or "Unknown"
                                q.NextMatchInfo:SetText(string.format('Starting in %s with %s affix', 
                                    HLBG._fmtETA and HLBG._fmtETA(nextMatch) or tostring(nextMatch)..'s', nextAffix))
                                
                                -- If we're close to start (under 10 seconds), flash the text
                                if nextMatch <= 10 then
                                    if nextMatch % 2 == 0 then
                                        q.NextMatchInfo:SetTextColor(1, 0.8, 0)
                                    else
                                        q.NextMatchInfo:SetTextColor(1, 0, 0)
                                    end
                                else
                                    q.NextMatchInfo:SetTextColor(1, 1, 1)
                                end
                            end
                        end
                    end
                end
            end)
            
            -- Request status immediately
            HLBG.RequestQueue("STATUS")
            
            q.initialized = true
        end
        
        -- Update the UI with new data
        if q.Status then
            if isQueued then
                q.Status:SetText(string.format('Queue: %s — position %d of %d (ETA %s)', 
                    tostring(team), pos, size, HLBG._fmtETA and HLBG._fmtETA(eta) or tostring(eta)..'s'))
            else
                q.Status:SetText("Not currently in queue")
            end
        end
        
        if q.Counts then
            q.Counts:SetText(string.format('Queued: Alliance %d | Horde %d | Total %d', aCount, hCount, aCount + hCount))
        end
        
        if q.NextMatchInfo then
            if nextMatchTime > 0 then
                q.NextMatchInfo:SetText(string.format('Starting in %s with %s affix', 
                    HLBG._fmtETA and HLBG._fmtETA(nextMatchTime) or tostring(nextMatchTime)..'s', nextAffixName))
            else
                q.NextMatchInfo:SetText('No scheduled match')
            end
        end
        
        -- Enable/disable buttons based on queue status
        if q.JoinButton then q.JoinButton:SetEnabled(not isQueued) end
        if q.LeaveButton then q.LeaveButton:SetEnabled(isQueued) end
        
        -- Show the UI
        if HLBG.UI and HLBG.UI.Frame then HLBG.UI.Frame:Show(); ShowTab(5) end
    end
end

-- Affixes handler
if type(HLBG.Affixes) ~= 'function' then
    function HLBG.Affixes(rows)
        HLBG._ensureUI('Affixes')
        local a = HLBG.UI and HLBG.UI.AffixPane
        if not a then return end
        rows = rows or {}
        
    -- Debug info
    safeDebug("Affixes received: " .. #rows)
        
        -- Build name map for affix code -> name
        _G.HLBG_AFFIX_NAMES = _G.HLBG_AFFIX_NAMES or {}
        for i=1,#rows do
            local r = rows[i]
            local id = r.id or r[1]
            local name = r.name or r[2]
            if id and name then _G.HLBG_AFFIX_NAMES[id] = name end
        end
        
        -- Normalize the rows data
        local normalizedRows = {}
        for i, r in ipairs(rows) do
            local row = {}
            -- Copy all existing properties
            for k, v in pairs(r) do
                row[k] = v
            end
            
            -- Handle numeric indexed values
            if type(r[1]) ~= "nil" and type(row.id) == "nil" then row.id = r[1] end
            if type(r[2]) ~= "nil" and type(row.name) == "nil" then row.name = r[2] end
            if type(r[3]) ~= "nil" and type(row.effect) == "nil" then row.effect = r[3] end
            if type(r[4]) ~= "nil" and type(row.description) == "nil" then row.description = r[4] end
            
            table.insert(normalizedRows, row)
        end
        rows = normalizedRows
        
        -- Store for later
        a.affixData = rows
        
        -- Clear existing rows
        if not a.Rows then a.Rows = {} end
        for i=1, #a.Rows do
            if a.Rows[i] then a.Rows[i]:Hide() end
        end
        
        -- Check if we need to add search box
        if not a.SearchBox then
            a.SearchHeader = CreateFrame("Frame", nil, a)
            a.SearchHeader:SetPoint("TOPLEFT", a, "TOPLEFT", 5, -5)
            a.SearchHeader:SetPoint("RIGHT", a, "RIGHT", -5, 0)
            a.SearchHeader:SetHeight(30)
            
            a.SearchLabel = a.SearchHeader:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            a.SearchLabel:SetPoint("LEFT", a.SearchHeader, "LEFT", 5, 0)
            a.SearchLabel:SetText("Search:")
            
            a.SearchBox = CreateFrame("EditBox", "HLBG_AffixSearch", a.SearchHeader, "InputBoxTemplate")
            a.SearchBox:SetPoint("LEFT", a.SearchLabel, "RIGHT", 10, 0)
            a.SearchBox:SetPoint("RIGHT", a.SearchHeader, "RIGHT", -10, 0)
            a.SearchBox:SetHeight(20)
            a.SearchBox:SetAutoFocus(false)
            a.SearchBox:SetText(HinterlandAffixHUDDB and HinterlandAffixHUDDB.affixSearch or "")
            
            a.SearchBox:SetScript("OnEnterPressed", function(self)
                self:ClearFocus()
                HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
                HinterlandAffixHUDDB.affixSearch = self:GetText()
                HLBG.RequestAffixes()
            end)
            
            a.SearchBox:SetScript("OnEscapePressed", function(self)
                self:ClearFocus()
            end)
        end
        
        -- Create enhanced affix display with more info
        local y = -40 -- Start below search box
        
        for i, r in ipairs(rows) do
            -- Create a collapsible section for each affix
            local section = a.Rows[i]
            if not section then
                section = CreateFrame("Frame", "HLBG_AffixRow_"..i, a.Content)
                section:SetPoint("LEFT", a.Content, "LEFT", 5, 0)
                section:SetPoint("RIGHT", a.Content, "RIGHT", -5, 0)
                
                -- Header with toggle button
                section.header = CreateFrame("Button", nil, section)
                section.header:SetPoint("TOPLEFT", section, "TOPLEFT", 0, 0)
                section.header:SetPoint("RIGHT", section, "RIGHT", 0, 0)
                section.header:SetHeight(25)
                section.header:SetBackdrop({
                    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
                    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
                    tile = true, tileSize = 16, edgeSize = 16,
                    insets = { left = 4, right = 4, top = 4, bottom = 4 }
                })
                section.header:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
                
                -- Header text
                section.name = section.header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
                section.name:SetPoint("LEFT", section.header, "LEFT", 10, 0)
                section.name:SetJustifyH("LEFT")
                
                -- Toggle button
                section.toggle = CreateFrame("Button", nil, section.header)
                section.toggle:SetSize(16, 16)
                section.toggle:SetPoint("RIGHT", section.header, "RIGHT", -10, 0)
                section.toggle:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
                section.expanded = false
                
                section.toggle:SetScript("OnClick", function(self)
                    section.expanded = not section.expanded
                    if section.expanded then
                        self:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
                        section.details:Show()
                        -- Update layout after expanding
                        HLBG.Affixes(a.affixData)
                    else
                        self:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
                        section.details:Hide()
                        -- Update layout after collapsing
                        HLBG.Affixes(a.affixData)
                    end
                end)
                
                -- Hover effect
                section.header:SetScript("OnEnter", function(self)
                    section.header:SetBackdropColor(0.3, 0.3, 0.7, 0.8)
                end)
                
                section.header:SetScript("OnLeave", function(self)
                    section.header:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
                end)
                
                -- Click to toggle
                section.header:SetScript("OnClick", function()
                    section.toggle:Click()
                end)
                
                -- Details section (hidden by default)
                section.details = CreateFrame("Frame", nil, section)
                section.details:SetPoint("TOPLEFT", section.header, "BOTTOMLEFT", 0, -2)
                section.details:SetPoint("RIGHT", section, "RIGHT", 0, 0)
                section.details:Hide()
                
                -- Effect header
                section.effectHeader = section.details:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                section.effectHeader:SetPoint("TOPLEFT", section.details, "TOPLEFT", 15, -5)
                section.effectHeader:SetText("Effect:")
                
                -- Effect text
                section.effect = section.details:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                section.effect:SetPoint("TOPLEFT", section.effectHeader, "BOTTOMLEFT", 5, -5)
                section.effect:SetPoint("RIGHT", section.details, "RIGHT", -10, 0)
                section.effect:SetJustifyH("LEFT")
                section.effect:SetJustifyV("TOP")
                
                -- Description header (if available)
                section.descHeader = section.details:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                section.descHeader:SetPoint("TOPLEFT", section.effect, "BOTTOMLEFT", -5, -10)
                section.descHeader:SetText("Description:")
                
                -- Description text
                section.description = section.details:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                section.description:SetPoint("TOPLEFT", section.descHeader, "BOTTOMLEFT", 5, -5)
                section.description:SetPoint("RIGHT", section.details, "RIGHT", -10, 0)
                section.description:SetJustifyH("LEFT")
                section.description:SetJustifyV("TOP")
                
                -- Stats header if we have them
                section.statsHeader = section.details:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                section.statsHeader:SetPoint("TOPLEFT", section.description, "BOTTOMLEFT", -5, -10)
                section.statsHeader:SetText("Statistics:")
                
                -- Stats text
                section.stats = section.details:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                section.stats:SetPoint("TOPLEFT", section.statsHeader, "BOTTOMLEFT", 5, -5)
                section.stats:SetPoint("RIGHT", section.details, "RIGHT", -10, 0)
                section.stats:SetJustifyH("LEFT")
                section.stats:SetHeight(30)
                
                a.Rows[i] = section
            end
            
            section = a.Rows[i]
            section:ClearAllPoints()
            section:SetPoint("TOPLEFT", a.Content, "TOPLEFT", 5, y)
            
            -- Update section content
            local id = r.id or ""
            local name = r.name or "Unknown Affix"
            local effect = r.effect or "No effect information available."
            local description = r.description or "No detailed description available."
            
            -- Set display text
            section.name:SetText(name .. " (" .. id .. ")")
            section.effect:SetText(effect)
            section.description:SetText(description)
            
            -- Try to get stats for this affix
            local statsText = "No statistics available for this affix."
            if HLBG._lastStats and HLBG._lastStats.affixWins and HLBG._lastStats.affixWins[id] then
                local affixStats = HLBG._lastStats.affixWins[id]
                local count = tonumber(affixStats.count or 0) or 0
                local alliance = tonumber(affixStats.alliance or 0) or 0
                local horde = tonumber(affixStats.horde or 0) or 0
                local draws = tonumber(affixStats.draws or 0) or 0
                
                -- Calculate percentages
                local aPct = count > 0 and math.floor((alliance / count) * 100) or 0
                local hPct = count > 0 and math.floor((horde / count) * 100) or 0
                local dPct = count > 0 and math.floor((draws / count) * 100) or 0
                
                statsText = string.format("Battles: %d\nAlliance: %d (%d%%)\nHorde: %d (%d%%)\nDraws: %d (%d%%)",
                    count, alliance, aPct, horde, hPct, draws, dPct)
            end
            section.stats:SetText(statsText)
            
            -- Show the section
            section:Show()
            
            -- Calculate height based on content
            local detailsHeight = 0
            if section.expanded then
                section.effect:SetHeight(0)
                section.description:SetHeight(0)
                section.stats:SetHeight(0)
                
                -- Set effect text and get its height
                section.effect:SetText(effect)
                detailsHeight = detailsHeight + section.effectHeader:GetHeight() + 5
                detailsHeight = detailsHeight + section.effect:GetStringHeight() + 10
                
                -- Set description text and get its height
                section.description:SetText(description)
                detailsHeight = detailsHeight + section.descHeader:GetHeight() + 5
                detailsHeight = detailsHeight + section.description:GetStringHeight() + 10
                
                -- Set stats text and get its height
                section.stats:SetText(statsText)
                detailsHeight = detailsHeight + section.statsHeader:GetHeight() + 5
                detailsHeight = detailsHeight + section.stats:GetStringHeight() + 10
                
                -- Update details height
                section.details:SetHeight(detailsHeight)
                section:SetHeight(section.header:GetHeight() + detailsHeight)
            else
                section:SetHeight(section.header:GetHeight())
            end
            
            -- Update y position for next section
            y = y - section:GetHeight() - 5
        end
        
        -- Update content height to accommodate all sections
        a.Content:SetHeight(math.max(300, math.abs(y) + 10))
        
        -- Show the UI
        if HLBG.UI and HLBG.UI.Frame then HLBG.UI.Frame:Show(); ShowTab(4) end
    end
end

-- Minimal Debug message
if type(HLBG.DBG) ~= 'function' then
    function HLBG.DBG(msg)
        HLBG._lastDBG = tostring(msg or '')
    end
end

-- Register handlers once all functions exist; bind when AIO loads (or immediately if already loaded)
do
    -- SafePrint should be available from EmergencyFix; if not, use minimal fallback
    if type(HLBG.SafePrint) ~= 'function' then
        HLBG.SafePrint = function(msg)
            pcall(print, tostring(msg or ''))
        end
    end
    local function register()
        if not (_G.AIO and _G.AIO.AddHandlers) then return false end
        
        -- Check if HLBG_AIO_Check already handled registration via legacy RegisterEvent
        if HLBG._aioRegistered or HLBG._aioRegistering then
            HLBG.SafePrint("HLBG_AIO: Registration already handled by AIO_Check, skipping AddHandlers")
            return true
        end
        
        -- Request a fresh table and then assign handlers for maximum compatibility
        local ok, reg = pcall(function() return _G.AIO.AddHandlers("HLBG", {}) end)
        if not ok or type(reg) ~= "table" then
            local errmsg = tostring(reg or "")
            -- If AddHandlers asserted because the name is already registered, try to attach to any existing global HLBG table
            if errmsg:find("an event is already registered") or errmsg:find("already registered") then
                    if type(_G.HLBG) == "table" then
                    local existing = _G.HLBG
                    -- merge our handlers into the existing table only when missing to avoid stomping
                    existing.OpenUI = existing.OpenUI or HLBG.OpenUI
                    existing.History = existing.History or HLBG.History
                    existing.Stats = existing.Stats or HLBG.Stats
                    existing.PONG = existing.PONG or HLBG.PONG
                    existing.DBG = existing.DBG or HLBG.DBG
                    existing.HistoryStr = existing.HistoryStr or HLBG.HistoryStr
                    existing.Status = existing.Status or HLBG.Status
                    existing.HISTORY = existing.HISTORY or existing.History
                    existing.STATS = existing.STATS or existing.Stats
                    existing.Warmup = existing.Warmup or HLBG.Warmup
                    existing.QueueStatus = existing.QueueStatus or HLBG.QueueStatus
                    existing.Results = existing.Results or HLBG.Results
                    _G.HLBG = existing; HLBG = existing
                    HLBG.SafePrint("HLBG: AIO name already registered; attached to existing HLBG table")
                    return true
                else
                    HLBG.SafePrint("HLBG: AIO name already registered; handlers may belong to another addon — using fallback")
                    -- Treat as terminal (don't spam retries) but not a success for AIO binding
                    return true
                end
            end
            HLBG.SafePrint("HLBG: AIO.AddHandlers returned unexpected value; retrying")
            return false
        end
        
        -- preserve some helper functions and UI from the current HLBG table so we don't lose pointers
        local preservedSendLog = (type(HLBG) == "table" and type(HLBG.SendClientLog) == "function") and HLBG.SendClientLog or nil
        local preservedUI = (type(HLBG) == "table" and type(HLBG.UI) == "table") and HLBG.UI or nil
        
        -- preserve safe helpers that UI and handlers rely on (these can be lost when HLBG table is swapped by AIO)
        local preservedSafe = {}
        if type(HLBG) == 'table' then
            for _, k in ipairs({
                'SafePrint','safeExecSlash','safeRegisterSlash','safeSetJustify','safeIsInInstance',
                'safeGetRealZoneText','safeGetNumWorldStateUI','safeGetWorldStateUIInfo','safeGetPlayerMapPosition',
                -- Preserve diagnostic helper so it remains callable after AIO swaps the HLBG table
                'PrintStartupHistory'
            }) do
                if type(HLBG[k]) == 'function' then preservedSafe[k] = HLBG[k] end
            end
        end
        
        reg.OpenUI     = HLBG.OpenUI
        reg.History    = HLBG.History
        reg.Stats      = HLBG.Stats
        reg.Live       = HLBG.Live
        reg.LIVE       = reg.Live
        reg.Status     = HLBG.Status
        reg.Affixes    = HLBG.Affixes
        reg.Warmup     = HLBG.Warmup
        reg.QueueStatus= HLBG.QueueStatus
        reg.Results    = HLBG.Results
        reg.PONG       = HLBG.PONG
        reg.DBG        = HLBG.DBG
        reg.HistoryStr = HLBG.HistoryStr
    reg.HistoryTSV  = HLBG.HistoryTSV or HLBG.ProcessHistoryTSV
    reg.StatsJSON    = HLBG.StatsJSON or HLBG.ProcessStatsJSON
        reg.HISTORY    = reg.History
        reg.STATS      = reg.Stats
        
        -- Also register some lowercase/alternate aliases; some AIO builds normalize names differently
        reg.history = reg.History
        reg.historystr = reg.HistoryStr
        reg.stats = reg.Stats
        reg.live = reg.Live
        reg.status = reg.Status
        reg.affixes = reg.Affixes
        reg.results = reg.Results
        reg.warmup = reg.Warmup
        reg.queuestatus = reg.QueueStatus
        reg.pong = reg.PONG
        
        -- reattach preserved helpers to the new reg table if present
        if preservedSendLog then reg.SendClientLog = preservedSendLog end
        if preservedUI then reg.UI = preservedUI end
        for k, fn in pairs(preservedSafe) do reg[k] = reg[k] or fn end
        _G.HLBG = reg; HLBG = reg
        
        -- Use SafePrint if available, otherwise fall back to AddMessage with stringified message
        local function safeStartupPrint(msg)
            pcall(function()
                if type(HLBG) == 'table' and type(HLBG.SafePrint) == 'function' then
                    HLBG.SafePrint(msg)
                elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                    DEFAULT_CHAT_FRAME:AddMessage(tostring(msg or ''))
                end
            end)
        end
        safeStartupPrint("HLBG: Handlers successfully registered (History/Stats/PONG/OpenUI)")
        safeStartupPrint(string.format(
            "HLBG: Registered handlers -> History=%s, Stats=%s, PONG=%s, OpenUI=%s",
            tostring(type(HLBG.History)), tostring(type(HLBG.Stats)), tostring(type(HLBG.PONG)), tostring(type(HLBG.OpenUI))
        ))
        
        -- Prime first page
        if _G.AIO and _G.AIO.Handle then
            local sv = (HLBG and HLBG._getSeason and HLBG._getSeason()) or 0
            local wf = (HinterlandAffixHUDDB and HinterlandAffixHUDDB.histWinner) or 'ALL'
            local af = (HinterlandAffixHUDDB and HinterlandAffixHUDDB.histAffix) or ''
            _G.AIO.Handle("HLBG", "Request", "HISTORY", 1, HLBG.UI and HLBG.UI.History and HLBG.UI.History.per or 15, "id", "ASC", wf, HLBG.ResolveAffixFilter and HLBG.ResolveAffixFilter(af) or af, sv)
            _G.AIO.Handle("HLBG", "Request", "STATS")
            _G.AIO.Handle("HLBG", "Request", "AFFIXES", sv, HinterlandAffixHUDDB and HinterlandAffixHUDDB.affixSearch or '')
            _G.AIO.Handle("HLBG", "Request", "QUEUE", "STATUS")
        end
        
        return true
    end

    -- Try immediate register; if it fails, poll for AIO for a few seconds and also listen to ADDON_LOADED
    if not register() then
    HLBG.SafePrint("HLBG: AIO not available yet; starting registration poll")
        local attempts = 0
        local maxAttempts = 20
        local pollT = 0
        local fr = CreateFrame("Frame")
        fr:SetScript("OnUpdate", function(self, elapsed)
            pollT = pollT + (elapsed or 0)
            if pollT < 0.25 then return end
            pollT = 0
            attempts = attempts + 1
            if register() then
                HLBG.SafePrint(string.format("HLBG: registration succeeded after %d attempts", attempts))
                self:SetScript("OnUpdate", nil)
                return
            end
            if attempts >= maxAttempts then
                HLBG.SafePrint("HLBG: registration failed after multiple attempts; handlers not bound")
                self:SetScript("OnUpdate", nil)
            end
        end)
        fr:RegisterEvent("ADDON_LOADED")
        fr:SetScript("OnEvent", function(self, _, name)
            if name == "AIO_Client" or name == "AIO" or name == "RochetAio" then
                HLBG.SafePrint("HLBG: ADDON_LOADED signaled AIO; attempting register")
                if register() then
                    HLBG.SafePrint("HLBG: registration succeeded from ADDON_LOADED")
                    fr:SetScript("OnUpdate", nil); fr:UnregisterAllEvents(); fr:SetScript("OnEvent", nil)
                end
            end
        end)
    end
end

-- Startup diagnostic: print a compact status line so it's easy to see what initialized
do
    local function startupDiag()
        local haveAIO = (_G.AIO and _G.AIO.AddHandlers) and true or false
        local handlersBound = (type(HLBG) == 'table' and (type(HLBG.History) == 'function' or type(HLBG.HISTORY) == 'function')) and true or false
        local uiPresent = (type(HLBG) == 'table' and type(HLBG.UI) == 'table') or (type(UI) == 'table')
    HLBG.SafePrint(string.format("HLBG STARTUP: AIO=%s handlers=%s UI=%s", tostring(haveAIO), tostring(handlersBound), tostring(uiPresent)))
    if not uiPresent and type(UI) == 'table' then HLBG.SafePrint("HLBG STARTUP: attaching local UI to HLBG") ; HLBG.UI = UI end
        -- Print and persist slash registration summary if available
        local regParts = {}
            if HLBG._registered_slashes and #HLBG._registered_slashes > 0 then
            for _,s in ipairs(HLBG._registered_slashes) do table.insert(regParts, s.cmd) end
            HLBG.SafePrint("HLBG: registered slashes -> " .. tostring(table.concat(regParts, ", ")))
        end
        local skipParts = {}
        if HLBG._skipped_slashes and #HLBG._skipped_slashes > 0 then
            for _,s in ipairs(HLBG._skipped_slashes) do table.insert(skipParts, string.format("%s (%s)", tostring(s.cmd), tostring(s.reason))) end
            HLBG.SafePrint("HLBG: skipped slashes -> " .. tostring(table.concat(skipParts, ", ")))
        end
        -- Persist a compact startup summary for later inspection (keep last 20)
        HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
        HinterlandAffixHUDDB.startupHistory = HinterlandAffixHUDDB.startupHistory or {}
        local entry = { ts = time(), aio = haveAIO, handlers = handlersBound, ui = uiPresent, registered = regParts, skipped = skipParts }
        table.insert(HinterlandAffixHUDDB.startupHistory, 1, entry)
        while #HinterlandAffixHUDDB.startupHistory > 20 do table.remove(HinterlandAffixHUDDB.startupHistory) end
        -- provide helper to print startup history
        function HLBG.PrintStartupHistory(n)
            n = tonumber(n) or 1
            local hist = HinterlandAffixHUDDB and HinterlandAffixHUDDB.startupHistory or nil
            if not hist or #hist == 0 then
                if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then HLBG.SafePrint('HLBG: no startup history saved') end
                return
            end
            if n < 1 then n = 1 end
            if n > #hist then n = #hist end
            local e = hist[n]
            if not e then return end
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                HLBG.SafePrint(string.format('HLBG startup @ %s: AIO=%s handlers=%s ui=%s', date('%Y-%m-%d %H:%M:%S', e.ts), tostring(e.aio), tostring(e.handlers), tostring(e.ui)))
                if e.registered and #e.registered > 0 then HLBG.SafePrint(' registered: '..tostring(table.concat(e.registered, ', '))) end
                if e.skipped and #e.skipped > 0 then HLBG.SafePrint(' skipped: '..tostring(table.concat(e.skipped, ', '))) end
            end
        end
    end
    
    -- Delay a tick so ADDON_LOADED messages can arrive first
    local tfr = CreateFrame('Frame')
    local t = 0
    tfr:SetScript('OnUpdate', function(self, elapsed)
        t = t + (elapsed or 0)
        if t > 0.5 then
            startupDiag()
            self:SetScript('OnUpdate', nil)
        end
    end)
end

-- Ensure we have a valid UI parent for the main frame (UIParent as fallback)
if HLBG and HLBG.UI and HLBG.UI.Frame and HLBG.UI.Frame.SetParent then
    HLBG.UI.Frame:SetParent(UIParent)
end

-- Request initial data from server (HISTORY/STATS/AFFIXES/QUEUE STATUS)
if _G.AIO and _G.AIO.Handle then
    local sv = (HLBG and HLBG._getSeason and HLBG._getSeason()) or 0
    local wf = (HinterlandAffixHUDDB and HinterlandAffixHUDDB.histWinner) or 'ALL'
    local af = (HinterlandAffixHUDDB and HinterlandAffixHUDDB.histAffix) or ''
    _G.AIO.Handle("HLBG", "Request", "HISTORY", 1, HLBG.UI and HLBG.UI.History and HLBG.UI.History.per or 15, "id", "ASC", wf, HLBG.ResolveAffixFilter and HLBG.ResolveAffixFilter(af) or af, sv)
    _G.AIO.Handle("HLBG", "Request", "STATS")
    _G.AIO.Handle("HLBG", "Request", "AFFIXES", sv, HinterlandAffixHUDDB and HinterlandAffixHUDDB.affixSearch or '')
    _G.AIO.Handle("HLBG", "Request", "QUEUE", "STATUS")
end