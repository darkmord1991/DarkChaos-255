local HLBG = _G.HLBG or {}; _G.HLBG = HLBG
HLBG.UI = HLBG.UI or {}
-- Initialize SavedVariables with defaults if not exists
-- Migrate saved variables to DCHLBGDB (new name). If the old table exists, copy values to preserve user settings.
if not DCHLBGDB then
    DCHLBGDB = {}
    if HinterlandAffixHUDDB and type(HinterlandAffixHUDDB) == 'table' then
        -- migrate known keys from old table, then clear the legacy table
        for k,v in pairs(HinterlandAffixHUDDB) do DCHLBGDB[k] = v end
        -- mark that a migration happened (useful for debugging)
        DCHLBGDB._migratedFromHinterlandAffixHUD = true
        if HLBG and HLBG.Debug then pcall(HLBG.Debug, "Migrated settings from HinterlandAffixHUDDB to DCHLBGDB") end
        -- Clear the legacy table to avoid accidental future writes to the old global
        for k in pairs(HinterlandAffixHUDDB) do HinterlandAffixHUDDB[k] = nil end
        HinterlandAffixHUDDB = nil
    end
end
-- Ensure all expected keys exist with sensible defaults
DCHLBGDB.hudEnabled = (DCHLBGDB.hudEnabled ~= nil) and DCHLBGDB.hudEnabled or true
DCHLBGDB.debugMode = DCHLBGDB.debugMode or false
DCHLBGDB.showHudEverywhere = DCHLBGDB.showHudEverywhere or false
DCHLBGDB.hudScale = DCHLBGDB.hudScale or 1.0
DCHLBGDB.hudAlpha = DCHLBGDB.hudAlpha or 0.9
DCHLBGDB.enableTelemetry = DCHLBGDB.enableTelemetry or false
-- Essential UI creation (no duplicates)
if not HLBG.UI.Frame then
    HLBG.UI.Frame = CreateFrame("Frame", "HLBG_Main", PVPParentFrame or PVPFrame)
    HLBG.UI.Frame:SetSize(640, 450)
    HLBG.UI.Frame:Hide()
    if HLBG.UI.Frame.SetFrameStrata then HLBG.UI.Frame:SetFrameStrata("DIALOG") end
    HLBG.UI.Frame:SetBackdrop({
        bgFile = "Interface/DialogFrame/UI-DialogBox-Background",
        edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left=8, right=8, top=8, bottom=8 }
    })
    HLBG.UI.Frame:SetBackdropColor(0, 0, 0, 0)

    do
        local BG_FELLEATHER = "Interface\\AddOns\\DC-HinterlandBG\\Textures\\Backgrounds\\FelLeather_512.tga"
        local BG_TINT_ALPHA = 0.60

        local bg = HLBG.UI.Frame:CreateTexture(nil, "BACKGROUND", nil, 0)
        bg:SetAllPoints()
        bg:SetTexture(BG_FELLEATHER)
        if bg.SetHorizTile then bg:SetHorizTile(false) end
        if bg.SetVertTile then bg:SetVertTile(false) end

        local tint = HLBG.UI.Frame:CreateTexture(nil, "BACKGROUND", nil, 1)
        tint:SetAllPoints()
        tint:SetTexture(0, 0, 0, BG_TINT_ALPHA)

        HLBG.UI.Frame.__dcBg = bg
        HLBG.UI.Frame.__dcTint = tint
    end
    HLBG.UI.Frame:ClearAllPoints()
    HLBG.UI.Frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    HLBG.UI.Frame:EnableMouse(true)
    HLBG.UI.Frame:SetMovable(true)
    HLBG.UI.Frame:RegisterForDrag("LeftButton")
    HLBG.UI.Frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    HLBG.UI.Frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    -- Title bar
    local titleBar = CreateFrame("Frame", nil, HLBG.UI.Frame)
    -- Title text directly on main frame, no extra bar
    local titleText = HLBG.UI.Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    titleText:SetPoint("TOPLEFT", HLBG.UI.Frame, "TOPLEFT", 18, -14)
    titleText:SetText("DC HLBG Addon")
    titleText:SetTextColor(1, 0.82, 0, 1)
    HLBG.UI.Frame.TitleText = titleText
    -- Close button
    local closeBtn = CreateFrame("Button", nil, HLBG.UI.Frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", HLBG.UI.Frame, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() HLBG.UI.Frame:Hide() end)
    closeBtn:SetFrameLevel(HLBG.UI.Frame:GetFrameLevel() + 10)
    closeBtn:SetScale(1.1)
    closeBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT"); GameTooltip:AddLine("Close window", 1,1,1); GameTooltip:Show()
    end)
    closeBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    HLBG.UI.Frame.CloseBtn = closeBtn
    -- Hide the ? button if it exists (added by frame template)
    if HLBG.UI.Frame.portraitFrame and HLBG.UI.Frame.portraitFrame.CloseButton then
        HLBG.UI.Frame.portraitFrame.CloseButton:Hide()
    end
    -- Alternative location for ? button
    local helpBtn = _G["HLBG_MainHelpButton"] or _G["HLBG_MainPortrait"]
    if helpBtn then helpBtn:Hide() end
    -- Refresh button
    local refreshBtn = CreateFrame("Button", nil, HLBG.UI.Frame, "UIPanelButtonTemplate")
    refreshBtn:SetSize(28, 28)
    refreshBtn:SetPoint("TOPLEFT", HLBG.UI.Frame, "TOPLEFT", 8, -8)
    refreshBtn:SetText("↻")
    refreshBtn:SetScript("OnClick", function()
        -- Show debug info
        local DC = _G.DCAddonProtocol
        local hasDC = DC and "YES" or "NO"
        local hasAIO = _G.AIO and "YES" or "NO"
        
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99HLBG Refresh:|r DCAddonProtocol=" .. hasDC .. " AIO=" .. hasAIO)
        
        if HLBG and HLBG.RequestHistory then 
            DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99HLBG:|r Requesting history data...")
            HLBG.RequestHistory() 
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000HLBG Error:|r RequestHistory function not found!")
        end
        
        if HLBG and HLBG.RequestStats then 
            HLBG.RequestStats() 
        end
    end)
    refreshBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT"); GameTooltip:AddLine("Refresh data", 1,1,1); GameTooltip:Show()
    end)
    refreshBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    HLBG.UI.Frame.RefreshBtn = refreshBtn
end
-- Create tabs only once
if not HLBG.UI.Tabs then
    -- Ensure all tab content frames are created before any tab logic
    if not HLBG.UI.History then HLBG.UI.History = CreateFrame("Frame", nil, HLBG.UI.Frame); HLBG.UI.History:SetAllPoints(HLBG.UI.Frame); HLBG.UI.History:Hide() end
    if not HLBG.UI.Stats then HLBG.UI.Stats = CreateFrame("Frame", nil, HLBG.UI.Frame); HLBG.UI.Stats:SetAllPoints(HLBG.UI.Frame); HLBG.UI.Stats:Hide() end
    if not HLBG.UI.Info then HLBG.UI.Info = CreateFrame("Frame", nil, HLBG.UI.Frame); HLBG.UI.Info:SetAllPoints(HLBG.UI.Frame); HLBG.UI.Info:Hide() end
    if not HLBG.UI.Settings then HLBG.UI.Settings = CreateFrame("Frame", nil, HLBG.UI.Frame); HLBG.UI.Settings:SetAllPoints(HLBG.UI.Frame); HLBG.UI.Settings:Hide() end
    if not HLBG.UI.Queue then HLBG.UI.Queue = CreateFrame("Frame", nil, HLBG.UI.Frame); HLBG.UI.Queue:SetAllPoints(HLBG.UI.Frame); HLBG.UI.Queue:Hide() end
    HLBG.UI.Tabs = {}
    for i = 1, 5 do
        HLBG.UI.Tabs[i] = CreateFrame("Button", "HLBG_Tab"..i, HLBG.UI.Frame)
        HLBG.UI.Tabs[i]:SetSize(100, 32)
        HLBG.UI.Tabs[i]:SetPoint("TOPLEFT", 8 + (i-1)*102, -38)
        HLBG.UI.Tabs[i]:SetNormalTexture("Interface/PVPFrame/UI-Character-PVP-Tab")
        HLBG.UI.Tabs[i]:SetHighlightTexture("Interface/PVPFrame/UI-Character-PVP-Tab-Highlight")
            local tabNames = {"History", "Stats", "Info", "Settings", "Queue"}
            local text = HLBG.UI.Tabs[i]:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            text:SetPoint("CENTER")
            text:SetText(tabNames[i])
            text:SetTextColor(1,1,1,1)
            HLBG.UI.Tabs[i].text = text
            -- Add highlight texture for active tab
            HLBG.UI.Tabs[i].highlight = HLBG.UI.Tabs[i]:CreateTexture(nil, "ARTWORK")
            HLBG.UI.Tabs[i].highlight:SetAllPoints()
            HLBG.UI.Tabs[i].highlight:SetTexture("Interface/Buttons/UI-Panel-Button-Highlight")
            HLBG.UI.Tabs[i].highlight:SetVertexColor(1, 0.82, 0, 0.25)
            HLBG.UI.Tabs[i].highlight:Hide()
    end
    HLBG.UI.Tabs[1].text:SetText("History")
    HLBG.UI.Tabs[2].text:SetText("Stats")
    HLBG.UI.Tabs[3].text:SetText("Info")
    HLBG.UI.Tabs[4].text:SetText("Settings")
    HLBG.UI.Tabs[5].text:SetText("Queue")
end
-- Create content frames only once (idempotent and robust)
-- Ensure the History frame exists first (created earlier during tabs setup)
HLBG.UI.History = HLBG.UI.History or CreateFrame("Frame", nil, HLBG.UI.Frame)
HLBG.UI.History:SetAllPoints(HLBG.UI.Frame)
HLBG.UI.History:Hide()
-- Only create the scroll/content/controls if Content is missing
if not HLBG.UI.History.Content then
    -- Create Scroll and Content with mouse wheel support
    HLBG.UI.History.Scroll = HLBG.UI.History.Scroll or CreateFrame("ScrollFrame", "HLBG_HistoryScroll", HLBG.UI.History, "UIPanelScrollFrameTemplate")
    HLBG.UI.History.Scroll:SetPoint("TOPLEFT", 16, -85)  -- Moved down more to make room for headers
    HLBG.UI.History.Scroll:SetPoint("BOTTOMRIGHT", -36, 50)  -- Leave room for pagination buttons
    HLBG.UI.History.Scroll:EnableMouseWheel(true)
    HLBG.UI.History.Scroll:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        local scrollStep = 44  -- Height of two rows (22*2) for smoother scrolling
        if delta < 0 then
            -- Scroll down
            self:SetVerticalScroll(math.min(maxScroll, current + scrollStep))
        else
            -- Scroll up
            self:SetVerticalScroll(math.max(0, current - scrollStep))
        end
    end)
    -- Add column headers
    if not HLBG.UI.History.Headers then
        HLBG.UI.History.Headers = CreateFrame("Frame", nil, HLBG.UI.History)
        HLBG.UI.History.Headers:SetPoint("TOPLEFT", 21, -68)  -- Position above scroll frame (moved down more for spacing)
        HLBG.UI.History.Headers:SetSize(550, 25)
        HLBG.UI.History.Headers:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        HLBG.UI.History.Headers:SetBackdropColor(0.1, 0.2, 0.4, 0.8)
        HLBG.UI.History.Headers:SetBackdropBorderColor(0.4, 0.6, 0.8, 1)
        
        local headerNames = {"ID", "S", "Timestamp", "Winner", "Affix", "Time", "Reason"}
        local headerWidths = {40, 40, 135, 65, 65, 55, 80}
        local sortKeys = {"id", "season", "occurred_at", "winner_tid", "affix", "duration_seconds", "win_reason"}
        local xOffset = 8
        
        HLBG.UI.History.HeaderButtons = HLBG.UI.History.HeaderButtons or {}
        
        for i, name in ipairs(headerNames) do
            -- Create clickable button for each header
            local headerBtn = CreateFrame("Button", nil, HLBG.UI.History.Headers)
            headerBtn:SetSize(headerWidths[i], 24)
            headerBtn:SetPoint("LEFT", HLBG.UI.History.Headers, "LEFT", xOffset, 0)
            
            -- Header text
            local headerText = headerBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            headerText:SetPoint("LEFT", headerBtn, "LEFT", 2, 0)
            headerText:SetText(name)
            headerText:SetTextColor(1, 0.82, 0, 1)  -- Gold color
            headerBtn.text = headerText
            
            -- Sort arrow indicator
            local arrow = headerBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            arrow:SetPoint("RIGHT", headerBtn, "RIGHT", -2, 0)
            arrow:SetText("")
            arrow:SetTextColor(0.2, 1, 0.2, 1)  -- Green
            headerBtn.arrow = arrow
            
            -- Click handler for sorting
            headerBtn:SetScript("OnClick", function(self)
                local hist = HLBG.UI.History
                local newSortKey = sortKeys[i]
                
                -- Toggle direction if clicking same column, otherwise default to DESC
                if hist.sortKey == newSortKey then
                    hist.sortDir = (hist.sortDir == "DESC") and "ASC" or "DESC"
                else
                    hist.sortKey = newSortKey
                    hist.sortDir = "DESC"
                end
                
                -- Update arrow indicators
                for _, btn in ipairs(HLBG.UI.History.HeaderButtons) do
                    btn.arrow:SetText("")
                end
                self.arrow:SetText(hist.sortDir == "DESC" and "▼" or "▲")
                
                -- Request new data with updated sort
                if type(HLBG.RequestHistoryUI) == 'function' then
                    HLBG.RequestHistoryUI(hist.page or 1, hist.per or 25, 0, hist.sortKey, hist.sortDir)
                end
            end)
            
            -- Hover effect
            headerBtn:SetScript("OnEnter", function(self)
                self.text:SetTextColor(1, 1, 1, 1)  -- White on hover
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:AddLine("Click to sort by " .. name, 1, 1, 1)
                GameTooltip:Show()
            end)
            
            headerBtn:SetScript("OnLeave", function(self)
                local hist = HLBG.UI.History
                if hist.sortKey == sortKeys[i] then
                    self.text:SetTextColor(0.2, 1, 0.2, 1)  -- Green if active sort
                else
                    self.text:SetTextColor(1, 0.82, 0, 1)  -- Gold otherwise
                end
                GameTooltip:Hide()
            end)
            
            HLBG.UI.History.HeaderButtons[i] = headerBtn
            xOffset = xOffset + headerWidths[i] + 3
        end
        
        -- Set initial sort indicator
        if HLBG.UI.History.HeaderButtons[1] then
            HLBG.UI.History.HeaderButtons[1].arrow:SetText("▼")
            HLBG.UI.History.HeaderButtons[1].text:SetTextColor(0.2, 1, 0.2, 1)
        end
    end
    HLBG.UI.History.Content = HLBG.UI.History.Content or CreateFrame("Frame", nil, HLBG.UI.History.Scroll)
    HLBG.UI.History.Content:SetSize(580, 380)
    -- Anchor the content to the top-left of the scroll frame so child rows position predictably
    HLBG.UI.History.Content:SetPoint('TOPLEFT', HLBG.UI.History.Scroll, 'TOPLEFT', 0, 0)
    HLBG.UI.History.Scroll:SetScrollChild(HLBG.UI.History.Content)
    
    -- Auto-load history when History tab is shown
    HLBG.UI.History:SetScript("OnShow", function()
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99HLBG:|r History tab shown, requesting data...")
        if type(HLBG.RequestHistory) == 'function' then
            C_Timer.After(0.3, function()
                pcall(HLBG.RequestHistory)
            end)
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000HLBG Error:|r RequestHistory function not found!")
        end
    end)
    
    -- Ensure state fields exist
    HLBG.UI.History.rows = HLBG.UI.History.rows or {}
    HLBG.UI.History.page = HLBG.UI.History.page or 1
    HLBG.UI.History.per = HLBG.UI.History.per or 15
    HLBG.UI.History.total = HLBG.UI.History.total or 0
    HLBG.UI.History.sortKey = HLBG.UI.History.sortKey or 'id'
    HLBG.UI.History.sortDir = HLBG.UI.History.sortDir or 'DESC'
    HLBG.UI.History.lastRows = HLBG.UI.History.lastRows or {}
    -- Placeholder and test button (hidden when history loads)
    local histBtn = HLBG.UI.History.HistBtn or CreateFrame("Button", nil, HLBG.UI.History, "UIPanelButtonTemplate")
    histBtn:SetSize(120, 32)
    histBtn:SetPoint("BOTTOM", HLBG.UI.History, "BOTTOM", 0, 40)
    histBtn:SetText("Test History")
    histBtn:SetScript("OnClick", function() DEFAULT_CHAT_FRAME:AddMessage("History tab button clicked!") end)
    histBtn:Hide()  -- Hide test button - not needed in production
    HLBG.UI.History.HistBtn = histBtn
    local histText = HLBG.UI.History.Placeholder or HLBG.UI.History:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    histText:SetPoint("CENTER", HLBG.UI.History, "CENTER", 0, 0)
    histText:SetText("No history data loaded.")
    histText:SetTextColor(1,1,1,1)
    HLBG.UI.History.Placeholder = histText
    -- Alias for legacy renderer: some code expects ui.EmptyText to exist and hides it when rows are present
    HLBG.UI.History.EmptyText = histText
    -- Add pagination controls (idempotent)
    local prevBtn = HLBG.UI.History.PrevBtn or CreateFrame("Button", nil, HLBG.UI.History, "UIPanelButtonTemplate")
    prevBtn:SetSize(50, 20)
    prevBtn:SetPoint("BOTTOMLEFT", HLBG.UI.History, "BOTTOMLEFT", 20, 20)
    prevBtn:SetText("Prev")
    prevBtn:SetNormalTexture("Interface/Buttons/UI-Panel-Button-Red")
    prevBtn:SetHighlightTexture("Interface/Buttons/UI-Panel-Button-Red")
    if prevBtn:GetFontString() then prevBtn:GetFontString():SetTextColor(1,0.82,0,1) end
    prevBtn:SetScript("OnClick", function()
        local ui = HLBG.UI.History
        local currentPage = tonumber(ui.page) or 1
        if currentPage > 1 then
            local newPage = currentPage - 1
            -- Request previous page from server (don't update ui.page yet - let server response do it)
            local cmd = string.format(".hlbg historyui %d %d %s %s", newPage, ui.per or 25, ui.sortKey or "id", ui.sortDir or "DESC")
            local editBox = DEFAULT_CHAT_FRAME.editBox or ChatFrame1EditBox
            if editBox then
                editBox:SetText(cmd)
                ChatEdit_SendText(editBox, 0)
            end
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFF33FF99HLBG:|r Requesting page %d (current: %d)", newPage, currentPage))
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFAA00HLBG:|r Already on first page")
        end
    end)
    HLBG.UI.History.PrevBtn = prevBtn
    local nextBtn = HLBG.UI.History.NextBtn or CreateFrame("Button", nil, HLBG.UI.History, "UIPanelButtonTemplate")
    nextBtn:SetSize(50, 20)
    nextBtn:SetPoint("BOTTOMRIGHT", HLBG.UI.History, "BOTTOMRIGHT", -50, 20)
    nextBtn:SetText("Next")
    nextBtn:SetScript("OnClick", function()
        local ui = HLBG.UI.History
        local currentPage = tonumber(ui.page) or 1
        local totalRecords = tonumber(ui.total) or 0
        local perPage = tonumber(ui.per) or 25
        local maxPage = (totalRecords > 0) and math.max(1, math.ceil(totalRecords / perPage)) or 1
        if currentPage < maxPage then
            local newPage = currentPage + 1
            -- Request next page from server (don't update ui.page yet - let server response do it)
            local cmd = string.format(".hlbg historyui %d %d %s %s", newPage, perPage, ui.sortKey or "id", ui.sortDir or "DESC")
            local editBox = DEFAULT_CHAT_FRAME.editBox or ChatFrame1EditBox
            if editBox then
                editBox:SetText(cmd)
                ChatEdit_SendText(editBox, 0)
            end
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFF33FF99HLBG:|r Requesting page %d of %d (current: %d)", newPage, maxPage, currentPage))
        else
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFFAA00HLBG:|r Already on last page (page %d of %d)", currentPage, maxPage))
        end
    end)
    HLBG.UI.History.NextBtn = nextBtn
    local pageText = HLBG.UI.History.PageText or HLBG.UI.History:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pageText:SetPoint("BOTTOM", HLBG.UI.History, "BOTTOM", 0, 25)
    pageText:SetText("Page 1 / 1")
    HLBG.UI.History.PageText = pageText
    -- Create Nav table for History function compatibility
    HLBG.UI.History.Nav = HLBG.UI.History.Nav or {}
    HLBG.UI.History.Nav.PageText = pageText
    HLBG.UI.History.Nav.Prev = prevBtn
    HLBG.UI.History.Nav.Next = nextBtn
end
if not HLBG.UI.Stats.Content then
    HLBG.UI.Stats.Content = CreateFrame("Frame", nil, HLBG.UI.Stats)
    HLBG.UI.Stats.Content:SetAllPoints()
    HLBG.UI.Stats.Content:Show()  -- Explicitly show
    -- Create scrollable stats frame
    local statsScroll = CreateFrame("ScrollFrame", "HLBG_StatsScrollFrame", HLBG.UI.Stats.Content, "UIPanelScrollFrameTemplate")
    statsScroll:SetPoint("TOPLEFT", HLBG.UI.Stats.Content, "TOPLEFT", 16, -80)
    statsScroll:SetPoint("BOTTOMRIGHT", HLBG.UI.Stats.Content, "BOTTOMRIGHT", -32, 20)
    local statsScrollChild = CreateFrame("Frame", nil, statsScroll)
    statsScrollChild:SetSize(560, 1200)  -- Large height for all stats
    statsScroll:SetScrollChild(statsScrollChild)
    HLBG.UI.Stats.Scroll = statsScroll
    HLBG.UI.Stats.ScrollChild = statsScrollChild
    -- Stats text (matching scoreboard NPC format)
    local statsText = statsScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statsText:SetPoint("TOPLEFT", 8, -8)
    statsText:SetWidth(540)
    statsText:SetJustifyH("LEFT")
    statsText:SetText([[|cFFFFD700Hinterland BG Statistics|r
|cFFFFFFFFTotal records:|r --
|cFFFFFFFFAlliance wins:|r --  |cFFAAAAAA(losses:|r --)|r
|cFFFFFFFFHorde wins:|r --  |cFFAAAAAA(losses:|r --)|r
|cFFFFFFFFDraws:|r --  |cFFAAAAAAManual resets:|r --|r
|cFFFFFFFFWin reasons:|r depletion --, tiebreaker --
|cFFFFFFFFCurrent streak:|r --
|cFFFFFFFFLongest streak:|r --
|cFFFFFFFFLargest margin:|r --
|cFFFFD700Top winners by affix:|r
No data - waiting for server

|cFFFFD700Draws by affix:|r
No data - waiting for server

|cFFFFD700Top outcomes by affix (incl. draws):|r
No data - waiting for server

|cFFFFD700Top affixes by matches:|r
No data - waiting for server

|cFFFFD700Average score per affix:|r
No data - waiting for server

|cFFAAAAAAClick Refresh (↻) button to request stats from server|r]])
    HLBG.UI.Stats.Text = statsText
    -- Refresh button for stats
    local refreshStatsBtn = CreateFrame("Button", nil, HLBG.UI.Stats.Content, "UIPanelButtonTemplate")
    refreshStatsBtn:SetSize(100, 25)
    refreshStatsBtn:SetPoint("TOPRIGHT", HLBG.UI.Stats.Content, "TOPRIGHT", -40, -55)
    refreshStatsBtn:SetText("Refresh")  -- Set button text
    refreshStatsBtn:SetScript("OnClick", function()
        -- Request stats from server via chat command (.hlbg statsui is the correct command)
        local cmd = ".hlbg statsui"
        local editBox = DEFAULT_CHAT_FRAME.editBox or ChatFrame1EditBox
        if editBox then
            editBox:SetText(cmd)
            ChatEdit_SendText(editBox, 0)
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99HLBG:|r Requesting statistics...")
    end)
end
-- Stats update function (to be called when stats data arrives from server)
HLBG.UpdateStats = HLBG.UpdateStats or function(statsData)
    if not HLBG.UI.Stats or not HLBG.UI.Stats.Text then return end
    if type(statsData) ~= "table" then
        HLBG.UI.Stats.Text:SetText("|cFFFFAA00No statistics data available.|r\n\nUse |cFFFFFFFF.hlbg statsui|r command or click Refresh.")
        return
    end
    
    local lines = {}
    local function addLine(text) table.insert(lines, text) end
    local function addSection(title) addLine("\n|cFFFFD700" .. title .. "|r") end
    
    -- Header
    addLine("|cFFFFD700═══════════════════════════════════════|r")
    addLine("|cFFFFD700    Hinterland Battleground Statistics    |r")
    addLine("|cFFFFD700═══════════════════════════════════════|r\n")
    
    -- Basic Counts
    addSection("Overall Statistics")
    addLine(string.format("  Total Battles: |cFFFFFFFF%d|r", statsData.totalBattles or 0))
    addLine(string.format("  Alliance Wins: |cFF0080FF%d|r", statsData.allianceWins or 0))
    addLine(string.format("  Horde Wins: |cFFFF4040%d|r", statsData.hordeWins or 0))
    addLine(string.format("  Draws: |cFFAAAA88%d|r", statsData.draws or 0))
    
    -- Win Reasons
    addSection("Win Reasons")
    addLine(string.format("  Depletion: |cFFFFFFFF%d|r", statsData.depletionWins or 0))
    addLine(string.format("  Tiebreaker: |cFFFFFFFF%d|r", statsData.tiebreakerWins or 0))
    addLine(string.format("  Manual Resets: |cFFFFFFFF%d|r", statsData.manualResets or 0))
    
    -- Streaks
    addSection("Streaks")
    local currStreak = statsData.currentStreak or {}
    local longStreak = statsData.longestStreak or {}
    
    local currTeam = currStreak.team or "None"
    local currCount = currStreak.count or 0
    local currColor = currTeam == "Alliance" and "0080FF" or (currTeam == "Horde" and "FF4040" or "AAAAAA")
    addLine(string.format("  Current: |cFF%s%s x%d|r", currColor, currTeam, currCount))
    
    local longTeam = longStreak.team or "None"
    local longCount = longStreak.count or 0
    local longColor = longTeam == "Alliance" and "0080FF" or (longTeam == "Horde" and "FF4040" or "AAAAAA")
    addLine(string.format("  Longest: |cFF%s%s x%d|r", longColor, longTeam, longCount))
    
    -- Largest Margin
    addSection("Largest Margin Victory")
    if statsData.largestMargin then
        local lm = statsData.largestMargin
        local team = lm.team or "Unknown"
        local margin = lm.margin or 0
        local scoreA = lm.scoreA or 0
        local scoreH = lm.scoreH or 0
        local date = lm.date or "Unknown"
        local color = team == "Alliance" and "0080FF" or "FF4040"
        addLine(string.format("  |cFF%s%s|r by |cFFFFFFFF%d|r points", color, team, margin))
        addLine(string.format("  Score: A:%d H:%d  |cFFAAAA88(%s)|r", scoreA, scoreH, date))
    else
        addLine("  No data available")
    end
    
    -- Top Winners by Affix
    if statsData.topWinnersByAffix and #statsData.topWinnersByAffix > 0 then
        addSection("Top Winners by Affix")
        for i, entry in ipairs(statsData.topWinnersByAffix) do
            if i <= 5 then  -- Show top 5
                local affixName = HLBG.GetAffixName and HLBG.GetAffixName(entry.affix) or ("Affix " .. (entry.affix or 0))
                local team = entry.team or "Unknown"
                local wins = entry.wins or 0
                local color = team == "Alliance" and "0080FF" or "FF4040"
                addLine(string.format("  %s: |cFF%s%s|r (%d wins)", affixName, color, team, wins))
            end
        end
    end
    
    -- Draws by Affix
    if statsData.drawsByAffix and #statsData.drawsByAffix > 0 then
        addSection("Draws by Affix")
        for i, entry in ipairs(statsData.drawsByAffix) do
            if i <= 5 then
                local affixName = HLBG.GetAffixName and HLBG.GetAffixName(entry.affix) or ("Affix " .. (entry.affix or 0))
                addLine(string.format("  %s: |cFFFFFFFF%d|r draws", affixName, entry.draws or 0))
            end
        end
    end
    
    -- Top Affixes by Match Count
    if statsData.topAffixes and #statsData.topAffixes > 0 then
        addSection("Most Played Affixes")
        for i, entry in ipairs(statsData.topAffixes) do
            if i <= 5 then
                local affixName = HLBG.GetAffixName and HLBG.GetAffixName(entry.affix) or ("Affix " .. (entry.affix or 0))
                addLine(string.format("  %s: |cFFFFFFFF%d|r matches", affixName, entry.matches or 0))
            end
        end
    end
    
    -- Average Scores per Affix
    if statsData.avgScoresPerAffix and #statsData.avgScoresPerAffix > 0 then
        addSection("Average Scores by Affix")
        for i, entry in ipairs(statsData.avgScoresPerAffix) do
            if i <= 5 then
                local affixName = HLBG.GetAffixName and HLBG.GetAffixName(entry.affix) or ("Affix " .. (entry.affix or 0))
                addLine(string.format("  %s: A:|cFF0080FF%.1f|r H:|cFFFF4040%.1f|r (n=%d)",
                    affixName, entry.avgAlliance or 0, entry.avgHorde or 0, entry.matches or 0))
            end
        end
    end
    
    -- Win Rates per Affix
    if statsData.winRatesPerAffix and #statsData.winRatesPerAffix > 0 then
        addSection("Win Rates by Affix")
        for i, entry in ipairs(statsData.winRatesPerAffix) do
            if i <= 5 then
                local affixName = HLBG.GetAffixName and HLBG.GetAffixName(entry.affix) or ("Affix " .. (entry.affix or 0))
                addLine(string.format("  %s: A:|cFF0080FF%.1f%%|r H:|cFFFF4040%.1f%%|r Draw:|cFFAAAA88%.1f%%|r",
                    affixName, entry.alliancePct or 0, entry.hordePct or 0, entry.drawPct or 0))
            end
        end
    end
    
    -- Average Margin per Affix
    if statsData.avgMarginPerAffix and #statsData.avgMarginPerAffix > 0 then
        addSection("Average Victory Margin by Affix")
        for i, entry in ipairs(statsData.avgMarginPerAffix) do
            if i <= 5 then
                local affixName = HLBG.GetAffixName and HLBG.GetAffixName(entry.affix) or ("Affix " .. (entry.affix or 0))
                addLine(string.format("  %s: |cFFFFFFFF%.1f|r points (n=%d)",
                    affixName, entry.avgMargin or 0, entry.matches or 0))
            end
        end
    end
    
    -- Median Margin per Affix (if available)
    if statsData.medianMarginPerAffix and #statsData.medianMarginPerAffix > 0 then
        addSection("Median Victory Margin by Affix")
        for i, entry in ipairs(statsData.medianMarginPerAffix) do
            if i <= 5 then
                local affixName = HLBG.GetAffixName and HLBG.GetAffixName(entry.affix) or ("Affix " .. (entry.affix or 0))
                addLine(string.format("  %s: |cFFFFFFFF%.1f|r points", affixName, entry.medianMargin or 0))
            end
        end
    end
    
    -- Reason Breakdown per Affix
    if statsData.reasonBreakdownPerAffix and #statsData.reasonBreakdownPerAffix > 0 then
        addSection("Win Reasons by Affix")
        for i, entry in ipairs(statsData.reasonBreakdownPerAffix) do
            if i <= 5 then
                local affixName = HLBG.GetAffixName and HLBG.GetAffixName(entry.affix) or ("Affix " .. (entry.affix or 0))
                addLine(string.format("  %s: Depletion:%d Tiebreaker:%d (n=%d)",
                    affixName, entry.depletion or 0, entry.tiebreaker or 0, entry.total or 0))
            end
        end
    end
    
    -- Average Duration per Affix
    if statsData.avgDurationPerAffix and #statsData.avgDurationPerAffix > 0 then
        addSection("Average Duration by Affix")
        for i, entry in ipairs(statsData.avgDurationPerAffix) do
            if i <= 5 then
                local affixName = HLBG.GetAffixName and HLBG.GetAffixName(entry.affix) or ("Affix " .. (entry.affix or 0))
                local duration = entry.avgDuration or 0
                local minutes = math.floor(duration / 60)
                local seconds = math.floor(duration % 60)
                addLine(string.format("  %s: |cFFFFFFFF%dm %ds|r (n=%d)",
                    affixName, minutes, seconds, entry.matches or 0))
            end
        end
    end
    
    -- Footer
    addLine("\n|cFFAAAA88Last updated: " .. date("%Y-%m-%d %H:%M:%S") .. "|r")
    
    HLBG.UI.Stats.Text:SetText(table.concat(lines, "\n"))

    -- Resize scroll child so text height remains consistent after refresh
    if HLBG.UI.Stats.ScrollChild and HLBG.UI.Stats.Text then
        -- Ensure width is set before measuring height
        HLBG.UI.Stats.Text:SetWidth(540)
        local textHeight = HLBG.UI.Stats.Text:GetStringHeight()
        -- If height is 0 (frame hidden), use a safe default or try to estimate
        if textHeight == 0 then textHeight = 1200 end
        local targetHeight = math.max(400, (textHeight or 0) + 32)
        HLBG.UI.Stats.ScrollChild:SetHeight(targetHeight)
    end
end
if not HLBG.UI.Info.Content then
    HLBG.UI.Info.Content = CreateFrame("Frame", nil, HLBG.UI.Info)
    HLBG.UI.Info.Content:SetAllPoints()
    HLBG.UI.Info.Content:Show()  -- Explicitly show
    -- Info content (scrollable text) - positioned lower to avoid tab overlap
    local infoScroll = CreateFrame("ScrollFrame", "HLBG_InfoScrollFrame", HLBG.UI.Info.Content, "UIPanelScrollFrameTemplate")
    infoScroll:SetPoint("TOPLEFT", HLBG.UI.Info.Content, "TOPLEFT", 16, -60)  -- Moved down from -50 to -60
    infoScroll:SetPoint("BOTTOMRIGHT", HLBG.UI.Info.Content, "BOTTOMRIGHT", -32, 20)
    local infoContent = CreateFrame("Frame", nil, infoScroll)
    infoContent:SetSize(500, 400)
    infoScroll:SetScrollChild(infoContent)
    local infoText = infoContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    infoText:SetPoint("TOPLEFT", 8, -8)
    infoText:SetWidth(480)
    infoText:SetJustifyH("LEFT")
    infoText:SetText([[|cFFFFD700Objective:|r
Capture and hold strategic points to gain resources. First team to reach 500 resources wins!
|cFFFFD700How to Play:|r
• Capture nodes by standing near them
• Each controlled node generates resources over time
• Defend your nodes and assault enemy positions
• Work with your team to control the battlefield
|cFFFFD700Commands:|r
• .hlbg status - View current battleground status
• .hlbg historyui - View match history
• Type /hlbg or click minimap button to open this UI
|cFFFFD700Affixes:|r
Special modifiers that change gameplay each season. Check the HUD for the current affix!]])
    HLBG.UI.Info.Text = infoText
    -- Populate Info tab
    if HLBG.UpdateInfo and type(HLBG.UpdateInfo) == 'function' then
        C_Timer.After(0.1, HLBG.UpdateInfo)
    end
end
if not HLBG.UI.Settings.Content then
    HLBG.UI.Settings.Content = CreateFrame("Frame", nil, HLBG.UI.Settings)
    HLBG.UI.Settings.Content:SetAllPoints()
    HLBG.UI.Settings.Content:Show()
    
    -- Simple message directing users to Interface Options
    local title = HLBG.UI.Settings.Content:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOP", HLBG.UI.Settings.Content, "TOP", 0, -100)
    title:SetText("|cFFFFD700Settings|r")
    
    local message = HLBG.UI.Settings.Content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    message:SetPoint("TOP", title, "BOTTOM", 0, -40)
    message:SetWidth(550)
    message:SetJustifyH("CENTER")
    message:SetText("|cFFFFFFFFSettings have been moved to|r\n|cFF33FF99Interface Options → AddOns → DC HLBG Addon|r\n\n|cFFAAAAAAYou can access them from the game's main menu:|r\n|cFFFFFFFFEsc → Interface → AddOns|r")
    
    -- Button to open Interface Options
    local openBtn = CreateFrame("Button", nil, HLBG.UI.Settings.Content, "UIPanelButtonTemplate")
    openBtn:SetSize(200, 35)
    openBtn:SetPoint("TOP", message, "BOTTOM", 0, -40)
    openBtn:SetText("Open Interface Options")
    openBtn:SetScript("OnClick", function()
        -- Close HLBG UI
        if HLBG.UI.Frame then HLBG.UI.Frame:Hide() end
        -- Open Interface Options
        if InterfaceOptionsFrame_OpenToCategory then
            -- Call twice because of WoW bug where first call sometimes doesn't work
            InterfaceOptionsFrame_OpenToCategory("DC HLBG Addon")
            InterfaceOptionsFrame_OpenToCategory("DC HLBG Addon")
        end
    end)
    openBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:AddLine("Open Blizzard Interface Options", 1,1,1)
        GameTooltip:AddLine("Settings are available in the AddOns section", 0.7,0.7,0.7,1)
        GameTooltip:Show()
    end)
    openBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    -- Info text at bottom
    local infoText = HLBG.UI.Settings.Content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoText:SetPoint("BOTTOM", HLBG.UI.Settings.Content, "BOTTOM", 0, 30)
    infoText:SetWidth(500)
    infoText:SetJustifyH("CENTER")
    infoText:SetText("|cFFAAAAAASettings are saved in:\nWTF/Account/<ACCOUNT>/SavedVariables/DCHLBG.lua|r")
end
if not HLBG.UI.Queue.Content then
    HLBG.UI.Queue.Content = CreateFrame("Frame", nil, HLBG.UI.Queue)
    HLBG.UI.Queue.Content:SetAllPoints()
    HLBG.UI.Queue.Content:Show()  -- Explicitly show
    -- Queue status text
    local statusText = HLBG.UI.Queue.Content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    statusText:SetPoint("TOP", HLBG.UI.Queue.Content, "TOP", 0, -60)
    statusText:SetWidth(560)
    statusText:SetJustifyH("CENTER")
    statusText:SetText("|cFFAAAAAANot in queue|r\n\nUse the button below to join")
    HLBG.UI.Queue.StatusText = statusText
    -- Join/Leave Queue button
    local queueBtn = CreateFrame("Button", nil, HLBG.UI.Queue.Content, "UIPanelButtonTemplate")
    queueBtn:SetSize(140, 35)
    queueBtn:SetPoint("TOP", statusText, "BOTTOM", 0, -30)
    queueBtn:SetText("Join Queue")
    if queueBtn:GetFontString() then
        queueBtn:GetFontString():SetTextColor(0.2, 1, 0.2, 1)  -- Green initially
    end
    queueBtn:SetScript("OnClick", function()
        if HLBG.IsInQueue then
            HLBG.LeaveQueue()
        else
            HLBG.JoinQueue()
        end
    end)
    HLBG.UI.Queue.JoinButton = queueBtn
    -- Refresh button
    local refreshBtn = CreateFrame("Button", nil, HLBG.UI.Queue.Content, "UIPanelButtonTemplate")
    refreshBtn:SetSize(100, 25)
    refreshBtn:SetPoint("TOP", queueBtn, "BOTTOM", 0, -15)
    refreshBtn:SetText("Refresh")
    refreshBtn:SetScript("OnClick", function()
        -- Show "waiting" indicator
        if HLBG.UI.Queue.StatusText then
            HLBG.UI.Queue.StatusText:SetText("|cFFFFAA00Requesting queue status...|r\n\nWaiting for server response...")
        end
        HLBG.RequestQueueStatus()
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99HLBG:|r Refreshing queue status...")
        -- Set timeout: if no response after 3 seconds, show error
        if C_Timer and C_Timer.After then
            C_Timer.After(3, function()
                -- Only show timeout if status text still shows "Requesting..."
                if HLBG.UI.Queue.StatusText and HLBG.UI.Queue.StatusText:GetText():match("Requesting") then
                    HLBG.UI.Queue.StatusText:SetText(
                        "|cFFFF5555No response from server|r\n\n" ..
                        "Queue system may not be implemented yet.\n" ..
                        "Try talking to the Battlemaster NPC instead.\n\n" ..
                        "|cFFAAAA00Note:|r Queue commands (.hlbgq) are in development.")
                    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF5555HLBG Queue:|r No response received. Queue system may not be active on this server.")
                end
            end)
        end
    end)
    -- Info text about queue system
    local infoText = HLBG.UI.Queue.Content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoText:SetPoint("TOP", refreshBtn, "BOTTOM", 0, -30)
    infoText:SetWidth(500)
    infoText:SetJustifyH("LEFT")
    infoText:SetText([[|cFFFFD700How to Join Hinterland BG:|r
To participate in Hinterland Battleground, currently you need to:
1. Travel to the Hinterland BG entrance
2. Talk to the Battlemaster NPC to queue
3. Alternatively, use the PvP UI if queue system is enabled
|cFFAAAAAANote: Automated queue commands (.hlbgq join/leave) are being developed.
Check with server administrators for the current queue method.|r]])
    HLBG.UI.Queue.InfoText = infoText
    -- Auto-request queue status when tab is shown
    HLBG.UI.Queue:SetScript("OnShow", function()
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99HLBG:|r Queue tab shown, requesting status...")
        if type(HLBG.RequestQueueStatus) == 'function' then
            C_Timer.After(0.3, function()  -- Small delay to ensure AIO ready
                pcall(HLBG.RequestQueueStatus)
            end)
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000HLBG Error:|r RequestQueueStatus function not found!")
        end
    end)
    -- Initialize queue state
    if not HLBG._queueState then
        HLBG._queueState = { inQueue = false }
    end
end
-- Tab switching function (single instance)
function ShowTab(i)
    local debugEnabled = DEFAULT_CHAT_FRAME and (HLBG._devMode or (DCHLBGDB and DCHLBGDB.debugMode))
    if debugEnabled then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFF8800HLBG Debug:|r Switching to tab %d", i))
    end
    -- Visual feedback: highlight the active tab button
    for tabIdx = 1, 5 do
        local tab = HLBG.UI.Tabs[tabIdx]
        if tab then
            if tabIdx == i then
                -- Active tab: bright yellow with slight glow
                tab:SetNormalFontObject(GameFontHighlightLarge)
                if tab.text then
                    tab.text:SetTextColor(1.0, 0.9, 0.2, 1.0) -- Bright yellow/gold
                end
            else
                -- Inactive tabs: normal white
                tab:SetNormalFontObject(GameFontNormal)
                if tab.text then
                    tab.text:SetTextColor(0.9, 0.9, 0.9, 1.0) -- Light gray/white
                end
            end
        end
    end
    -- Hide all content frames, then show the selected one
    if HLBG.UI.History then HLBG.UI.History:Hide() end
    if HLBG.UI.Stats then HLBG.UI.Stats:Hide() end
    if HLBG.UI.Info then HLBG.UI.Info:Hide() end
    if HLBG.UI.Settings then HLBG.UI.Settings:Hide() end
    if HLBG.UI.Queue then HLBG.UI.Queue:Hide() end
    if i == 1 and HLBG.UI.History then
        HLBG.UI.History:Show()
        -- Explicitly show Content frame (shouldn't be needed but ensures visibility)
        if HLBG.UI.History.Content then HLBG.UI.History.Content:Show() end
        -- Re-render History tab with existing data when shown
        if HLBG.UI.History.lastRows and #HLBG.UI.History.lastRows > 0 and type(HLBG.History) == 'function' then
            if debugEnabled then
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF8800HLBG Debug:|r Re-rendering History with existing data")
            end
            HLBG.History(HLBG.UI.History.lastRows, HLBG.UI.History.page or 1, HLBG.UI.History.per or 15, HLBG.UI.History.total or #HLBG.UI.History.lastRows, HLBG.UI.History.sortKey or 'id', HLBG.UI.History.sortDir or 'DESC')
        else
            if debugEnabled then
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFFAA00HLBG Debug:|r No History data to display")
            end
            -- Schedule a one-shot retry to re-request history in case of race/timing
            if not HLBG._showTabRetryScheduled then
                HLBG._showTabRetryScheduled = true
                pcall(function()
                    -- Use C_Timer compatibility layer if present
                    if type(C_Timer) == 'table' and type(C_Timer.After) == 'function' then
                        C_Timer.After(0.6, function()
                            HLBG._showTabRetryScheduled = false
                            -- Re-request via AIO and fallback chat commands
                            local page = HLBG.UI.History.page or 1
                            local per = HLBG.UI.History.per or 25
                            local sk = HLBG.UI.History.sortKey or 'id'
                            local sd = HLBG.UI.History.sortDir or 'DESC'
                            if _G.AIO and _G.AIO.Handle then
                                pcall(_G.AIO.Handle, 'HLBG', 'Request', 'HISTORY', page, per, sk, sd)
                            end
                            if type(HLBG.safeExecSlash) == 'function' then
                                pcall(HLBG.safeExecSlash, string.format('.hlbg historyui %d %d %s %s', page, per, sk, sd))
                            end
                            -- If data has arrived in the interim, render it
                            if HLBG.UI and HLBG.UI.History and HLBG.UI.History.lastRows and #HLBG.UI.History.lastRows > 0 and type(HLBG.History) == 'function' then
                                pcall(HLBG.History, HLBG.UI.History.lastRows, HLBG.UI.History.page or 1, HLBG.UI.History.per or 15, HLBG.UI.History.total or #HLBG.UI.History.lastRows, HLBG.UI.History.sortKey or 'id', HLBG.UI.History.sortDir or 'DESC')
                                if debugEnabled and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                                    DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG:|r History retried and rendered after delay')
                                end
                            else
                                if debugEnabled and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                                    DEFAULT_CHAT_FRAME:AddMessage('|cFFFFAA00HLBG:|r Retry completed but no history rows arrived')
                                end
                            end
                        end)
                    else
                        -- Fallback without C_Timer: do a simple request and log
                        HLBG._showTabRetryScheduled = false
                        if _G.AIO and _G.AIO.Handle then pcall(_G.AIO.Handle, 'HLBG', 'Request', 'HISTORY', HLBG.UI.History.page or 1, HLBG.UI.History.per or 25, HLBG.UI.History.sortKey or 'id', HLBG.UI.History.sortDir or 'DESC') end
                        if type(HLBG.safeExecSlash) == 'function' then pcall(HLBG.safeExecSlash, string.format('.hlbg historyui %d %d %s %s', HLBG.UI.History.page or 1, HLBG.UI.History.per or 25, HLBG.UI.History.sortKey or 'id', HLBG.UI.History.sortDir or 'DESC')) end
                    end
                end)
            end
        end
    end
    if i == 2 and HLBG.UI.Stats then
        HLBG.UI.Stats:Show()
        if HLBG.UI.Stats.Content then HLBG.UI.Stats.Content:Show() end
    end
    if i == 3 and HLBG.UI.Info then
        HLBG.UI.Info:Show()
        if HLBG.UI.Info.Content then HLBG.UI.Info.Content:Show() end
    end
    if i == 4 and HLBG.UI.Settings then
        HLBG.UI.Settings:Show()
        if HLBG.UI.Settings.Content then HLBG.UI.Settings.Content:Show() end
    end
    if i == 5 and HLBG.UI.Queue then
        HLBG.UI.Queue:Show()
        if HLBG.UI.Queue.Content then HLBG.UI.Queue.Content:Show() end
    end
    -- Update saved tab
    if DCHLBGDB then
        DCHLBGDB.lastInnerTab = i
    end
end
-- Wire up tab clicks
HLBG.UI.Tabs[1]:SetScript("OnClick", function() ShowTab(1) end)
HLBG.UI.Tabs[2]:SetScript("OnClick", function() ShowTab(2) end)
HLBG.UI.Tabs[3]:SetScript("OnClick", function() ShowTab(3) end)
HLBG.UI.Tabs[4]:SetScript("OnClick", function() ShowTab(4) end)
HLBG.UI.Tabs[5]:SetScript("OnClick", function() ShowTab(5) end)
-- Show first tab by default and make main frame visible
ShowTab(1)
HLBG.UI.Frame:Show()
-- Ensure UI helper function
if not HLBG._ensureUI then
    function HLBG._ensureUI(name)
        if not (type(HLBG) == 'table' and type(HLBG.UI) == 'table') then return false end
        if not name then return true end
        return HLBG.UI[name] ~= nil
    end
end
DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00HLBG:|r Clean UI loaded successfully")

