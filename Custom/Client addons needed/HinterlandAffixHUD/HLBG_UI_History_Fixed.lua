-- HLBG_UI_History_Fixed.lua - Enhanced history tab with pagination fixes

-- Ensure HLBG namespace exists
HLBG = HLBG or {}

-- Enhanced History handler with pagination fixes
function HLBG.History(rows, page, per, total, col, dir)
    HLBG._ensureUI('History')
    local h = HLBG.UI and HLBG.UI.History
    if not h then return end
    
    rows = rows or {}
    h.page = tonumber(page or 1) or 1
    h.per = tonumber(per or 10) or 10
    h.total = tonumber(total or #rows) or #rows
    h.sortKey = col or 'id'
    h.sortDir = dir or 'DESC'
    
    -- Initialize UI components if needed
    if not h.initialized then
        -- Create scrollable content frame
        h.ScrollFrame = CreateFrame("ScrollFrame", "HLBG_HistoryScrollFrame", h, "UIPanelScrollFrameTemplate")
        h.ScrollFrame:SetPoint("TOPLEFT", h, "TOPLEFT", 10, -10)
        h.ScrollFrame:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", -30, 60) -- Leave space for navigation
        
        h.Content = CreateFrame("Frame", "HLBG_HistoryScrollContent", h.ScrollFrame)
        h.Content:SetSize(h:GetWidth() - 40, 400)  -- Height will adjust based on content
        h.ScrollFrame:SetScrollChild(h.Content)
        
        -- Create header row
        h.Header = CreateFrame("Frame", nil, h)
        h.Header:SetPoint("TOPLEFT", h, "TOPLEFT", 10, -10)
        h.Header:SetPoint("RIGHT", h, "RIGHT", -30, 0)
        h.Header:SetHeight(20)
        
        -- Column headers
        local headers = {
            { text = "ID", width = 50 },
            { text = "Date & Time", width = 150 },
            { text = "Winner", width = 80 },
            { text = "Affix", width = 100 },
            { text = "Duration", width = 60 }
        }
        
        h.HeaderText = {}
        local x = 0
        for i, header in ipairs(headers) do
            local headerText = h.Header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            headerText:SetPoint("LEFT", h.Header, "LEFT", x, 0)
            headerText:SetText(header.text)
            headerText:SetWidth(header.width)
            h.HeaderText[i] = headerText
            
            -- Add sort functionality
            local headerButton = CreateFrame("Button", nil, h.Header)
            headerButton:SetPoint("TOPLEFT", headerText, "TOPLEFT", -5, 5)
            headerButton:SetPoint("BOTTOMRIGHT", headerText, "BOTTOMRIGHT", 5, -5)
            
            headerButton:SetScript("OnClick", function()
                local sortKeys = {"id", "ts", "winner", "affix", "duration"}
                local newDir = (h.sortKey == sortKeys[i] and h.sortDir == "ASC") and "DESC" or "ASC"
                
                -- Request new sort order
                local sv = (HLBG and HLBG._getSeason and HLBG._getSeason()) or 0
                local wf = (HinterlandAffixHUDDB and HinterlandAffixHUDDB.histWinner) or 'ALL'
                local af = (HinterlandAffixHUDDB and HinterlandAffixHUDDB.histAffix) or ''
                
                if _G.AIO and _G.AIO.Handle then
                    _G.AIO.Handle("HLBG", "Request", "HISTORY", 1, h.per, sortKeys[i], newDir, wf, HLBG.ResolveAffixFilter and HLBG.ResolveAffixFilter(af) or af, sv)
                end
                
                -- Fallback to chat command if AIO isn't available
                if HLBG.SendServerDot then
                    HLBG.SendServerDot(string.format(".hlbg history 1 %d %s %s", h.per, sortKeys[i], newDir))
                end
            end)
            
            x = x + header.width + 10
        end
        
        -- Create navigation controls
        h.Nav = CreateFrame("Frame", nil, h)
        h.Nav:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", 10, 10)
        h.Nav:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", -30, 10)
        h.Nav:SetHeight(40)
        
        -- Previous page button
        h.Nav.Prev = CreateFrame("Button", nil, h.Nav, "UIPanelButtonTemplate")
        h.Nav.Prev:SetSize(100, 22)
        h.Nav.Prev:SetPoint("LEFT", h.Nav, "LEFT", 0, 0)
        h.Nav.Prev:SetText("< Previous")
        
        -- Page text
        h.Nav.PageText = h.Nav:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        h.Nav.PageText:SetPoint("CENTER", h.Nav, "CENTER", 0, 0)
        h.Nav.PageText:SetText("Page 1 / 1")
        
        -- Next page button
        h.Nav.Next = CreateFrame("Button", nil, h.Nav, "UIPanelButtonTemplate")
        h.Nav.Next:SetSize(100, 22)
        h.Nav.Next:SetPoint("RIGHT", h.Nav, "RIGHT", 0, 0)
        h.Nav.Next:SetText("Next >")
        
        -- Setup navigation button handlers
        h.Nav.Prev:SetScript("OnClick", function()
            local newPage = math.max(1, h.page - 1)
            local sv = (HLBG and HLBG._getSeason and HLBG._getSeason()) or 0
            local wf = (HinterlandAffixHUDDB and HinterlandAffixHUDDB.histWinner) or 'ALL'
            local af = (HinterlandAffixHUDDB and HinterlandAffixHUDDB.histAffix) or ''
            
            if _G.AIO and _G.AIO.Handle then
                _G.AIO.Handle("HLBG", "Request", "HISTORY", newPage, h.per, h.sortKey, h.sortDir, wf, HLBG.ResolveAffixFilter and HLBG.ResolveAffixFilter(af) or af, sv)
            end
            
            -- Use chat-dot fallback
            if HLBG.SendServerDot then
                HLBG.SendServerDot(string.format(".hlbg history %d %d %s %s", newPage, h.per, h.sortKey, h.sortDir))
                HLBG.SendServerDot(string.format(".hlbg history %d %d %d %s %s", newPage, h.per, sv, h.sortKey, h.sortDir))
            end
            
            -- Update page number optimistically
            h.page = newPage
            local maxPage = math.max(1, math.ceil(h.total / h.per))
            h.Nav.PageText:SetText(string.format('Page %d / %d', newPage, maxPage))
            
            if newPage <= 1 then h.Nav.Prev:Disable() else h.Nav.Prev:Enable() end
            h.Nav.Next:Enable()
        end)
        
        h.Nav.Next:SetScript("OnClick", function()
            local newPage = h.page + 1
            local sv = (HLBG and HLBG._getSeason and HLBG._getSeason()) or 0
            local wf = (HinterlandAffixHUDDB and HinterlandAffixHUDDB.histWinner) or 'ALL'
            local af = (HinterlandAffixHUDDB and HinterlandAffixHUDDB.histAffix) or ''
            
            if _G.AIO and _G.AIO.Handle then
                _G.AIO.Handle("HLBG", "Request", "HISTORY", newPage, h.per, h.sortKey, h.sortDir, wf, HLBG.ResolveAffixFilter and HLBG.ResolveAffixFilter(af) or af, sv)
            end
            
            -- Use chat-dot fallback
            if HLBG.SendServerDot then
                HLBG.SendServerDot(string.format(".hlbg history %d %d %s %s", newPage, h.per, h.sortKey, h.sortDir))
                HLBG.SendServerDot(string.format(".hlbg history %d %d %d %s %s", newPage, h.per, sv, h.sortKey, h.sortDir))
            end
            
            -- Update page number optimistically
            h.page = newPage
            local maxPage = math.max(1, math.ceil(h.total / h.per))
            h.Nav.PageText:SetText(string.format('Page %d / %d', newPage, maxPage))
            
            h.Nav.Prev:Enable()
            if newPage >= maxPage then h.Nav.Next:Disable() else h.Nav.Next:Enable() end
        end)
        
        -- Create filter controls
        h.Filter = CreateFrame("Frame", nil, h)
        h.Filter:SetPoint("TOPLEFT", h.Header, "BOTTOMLEFT", 0, -5)
        h.Filter:SetPoint("TOPRIGHT", h.Header, "BOTTOMRIGHT", 0, -5)
        h.Filter:SetHeight(30)
        
        -- Winner filter
        local winnerLabel = h.Filter:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        winnerLabel:SetPoint("LEFT", h.Filter, "LEFT", 0, 0)
        winnerLabel:SetText("Winner:")
        
        local winnerOptions = {"ALL", "Alliance", "Horde", "Draw"}
        h.Filter.Winner = CreateFrame("Frame", nil, h.Filter, "UIDropDownMenuTemplate")
        h.Filter.Winner:SetPoint("LEFT", winnerLabel, "RIGHT", -5, -3)
        
        UIDropDownMenu_SetWidth(h.Filter.Winner, 100)
        UIDropDownMenu_SetText(h.Filter.Winner, HinterlandAffixHUDDB and HinterlandAffixHUDDB.histWinner or "ALL")
        
        UIDropDownMenu_Initialize(h.Filter.Winner, function(self, level)
            for _, option in ipairs(winnerOptions) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = option
                info.value = option
                info.func = function(self)
                    HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
                    HinterlandAffixHUDDB.histWinner = self.value
                    UIDropDownMenu_SetText(h.Filter.Winner, self.value)
                    
                    -- Apply filter
                    local sv = (HLBG and HLBG._getSeason and HLBG._getSeason()) or 0
                    local af = (HinterlandAffixHUDDB and HinterlandAffixHUDDB.histAffix) or ''
                    
                    if _G.AIO and _G.AIO.Handle then
                        _G.AIO.Handle("HLBG", "Request", "HISTORY", 1, h.per, h.sortKey, h.sortDir, self.value, HLBG.ResolveAffixFilter and HLBG.ResolveAffixFilter(af) or af, sv)
                    end
                    
                    -- Fallback
                    if HLBG.SendServerDot then
                        HLBG.SendServerDot(string.format(".hlbg history 1 %d %s %s %s", h.per, h.sortKey, h.sortDir, self.value))
                    end
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)
        
        h.rows = {} -- Will store the row frames
        h.initialized = true
    end
    
    -- Hide old rows
    for i=1, #h.rows do 
        if h.rows[i] then
            h.rows[i]:Hide()
        end
    end
    
    -- Get or create row frames
    local function getRow(i)
        local r = h.rows[i]
        if not r then
            r = CreateFrame("Frame", nil, h.Content)
            r:SetHeight(20)
            
            r.cells = {}
            local cellWidths = {50, 150, 80, 100, 60}
            local x = 0
            
            for j = 1, 5 do
                r.cells[j] = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                r.cells[j]:SetPoint("LEFT", r, "LEFT", x, 0)
                r.cells[j]:SetWidth(cellWidths[j])
                x = x + cellWidths[j] + 10
            end
            
            -- Add background for even rows
            if i % 2 == 0 then
                local bg = r:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints()
                bg:SetColorTexture(0.2, 0.2, 0.2, 0.3)
            end
            
            h.rows[i] = r
        end
        return r
    end
    
    -- Populate rows
    local y = 0
    for i, row in ipairs(rows) do
        local r = getRow(i)
        r:SetPoint("TOPLEFT", h.Content, "TOPLEFT", 0, y)
        r:SetPoint("RIGHT", h.Content, "RIGHT", 0, 0)
        
        -- Extract row data
        local id = row.id or row[1] or ""
        local ts = row.ts or row[2] or ""
        local win = row.winner or row[3] or ""
        local aff = row.affix or row[4] or ""
        local duration = row.duration or row.reason or row[5] or ""
        
        -- Format affix name if helper function exists
        local affixName = aff
        if HLBG.GetAffixName then
            affixName = HLBG.GetAffixName(aff)
        end
        
        -- Format duration if it's a number
        local durationText = duration
        if tonumber(duration) then
            local seconds = tonumber(duration)
            local mins = math.floor(seconds / 60)
            local secs = seconds % 60
            durationText = string.format("%d:%02d", mins, secs)
        end
        
        -- Set cell text
        r.cells[1]:SetText(tostring(id))
        r.cells[2]:SetText(tostring(ts))
        r.cells[3]:SetText(tostring(win))
        r.cells[4]:SetText(tostring(affixName))
        r.cells[5]:SetText(tostring(durationText))
        
        -- Color the winner cell based on faction
        if win == "Alliance" then
            r.cells[3]:SetTextColor(0.2, 0.4, 0.8)
        elseif win == "Horde" then
            r.cells[3]:SetTextColor(0.8, 0.2, 0.2)
        elseif win == "Draw" then
            r.cells[3]:SetTextColor(0.8, 0.8, 0.2)
        else
            r.cells[3]:SetTextColor(1, 1, 1)
        end
        
        r:Show()
        y = y - 25 -- Row height + spacing
    end
    
    -- Update content height
    h.Content:SetHeight(math.max(300, math.abs(y) + 10))
    
    -- Update pagination
    local maxPage = math.max(1, math.ceil(h.total / h.per))
    h.Nav.PageText:SetText(string.format('Page %d / %d', h.page, maxPage))
    
    if h.page <= 1 then 
        h.Nav.Prev:Disable()
    else
        h.Nav.Prev:Enable()
    end
    
    if h.page >= maxPage then
        h.Nav.Next:Disable()
    else
        h.Nav.Next:Enable()
    end
    
    -- Show the UI
    if HLBG.UI and HLBG.UI.Frame and type(ShowTab) == "function" then
        HLBG.UI.Frame:Show()
        ShowTab(3)  -- Show History tab
    end
end

-- TSV fallback handler for history (AIO older builds or chat broadcast)
function HLBG.HistoryStr(tsv, page, per, total, col, dir)
    local rows = {}
    if type(tsv) == 'string' and tsv ~= '' then
        -- Support custom separator '||' -> newline
        if tsv:find('%|%|') then tsv = tsv:gsub('%|%|','\n') end
        for line in string.gmatch(tsv, '[^\n]+') do
            local id, ts, win, aff, data = line:match('^(.-)\t(.-)\t(.-)\t(.-)\t(.*)$')
            if id then 
                -- Try to parse the last column - might be duration or other data
                local duration = tonumber(data) or data
                table.insert(rows, { id = id, ts = ts, winner = win, affix = aff, duration = duration })
            end
        end
    end
    HLBG.History(rows, page, per, total, col, dir)
end