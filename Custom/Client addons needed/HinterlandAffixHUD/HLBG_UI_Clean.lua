local HLBG = _G.HLBG or {}; _G.HLBG = HLBG

HLBG.UI = HLBG.UI or {}



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
    HLBG.UI.Frame:SetBackdropColor(0.12,0.12,0.15,1)
    HLBG.UI.Frame:SetBackdropBorderColor(1,0.82,0,1)
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
    titleText:SetText("Hinterland Battleground")
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

    -- Refresh button
    local refreshBtn = CreateFrame("Button", nil, HLBG.UI.Frame, "UIPanelButtonTemplate")
    refreshBtn:SetSize(28, 28)
    refreshBtn:SetPoint("TOPLEFT", HLBG.UI.Frame, "TOPLEFT", 8, -8)
    refreshBtn:SetText("↻")
    refreshBtn:SetScript("OnClick", function()
        if HLBG and HLBG.RequestHistory then HLBG.RequestHistory() end
        if HLBG and HLBG.RequestStats then HLBG.RequestStats() end
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99HLBG:|r Refresh requested.")
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
    -- Create Scroll and Content
    HLBG.UI.History.Scroll = HLBG.UI.History.Scroll or CreateFrame("ScrollFrame", "HLBG_HistoryScroll", HLBG.UI.History, "UIPanelScrollFrameTemplate")
    HLBG.UI.History.Scroll:SetPoint("TOPLEFT", 16, -85)  -- Moved down more to make room for headers
    HLBG.UI.History.Scroll:SetPoint("BOTTOMRIGHT", -36, 16)
    
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
        local xOffset = 8
        
        for i, name in ipairs(headerNames) do
            local header = HLBG.UI.History.Headers:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            header:SetPoint("LEFT", HLBG.UI.History.Headers, "LEFT", xOffset, 0)
            header:SetWidth(headerWidths[i])
            header:SetText(name)
            header:SetTextColor(1, 0.82, 0, 1)  -- Gold color
            header:SetJustifyH("LEFT")
            xOffset = xOffset + headerWidths[i] + 3
        end
    end
    
    HLBG.UI.History.Content = HLBG.UI.History.Content or CreateFrame("Frame", nil, HLBG.UI.History.Scroll)
    HLBG.UI.History.Content:SetSize(580, 380)
    -- Anchor the content to the top-left of the scroll frame so child rows position predictably
    HLBG.UI.History.Content:SetPoint('TOPLEFT', HLBG.UI.History.Scroll, 'TOPLEFT', 0, 0)
    HLBG.UI.History.Scroll:SetScrollChild(HLBG.UI.History.Content)

    -- Ensure state fields exist
    HLBG.UI.History.rows = HLBG.UI.History.rows or {}
    HLBG.UI.History.page = HLBG.UI.History.page or 1
    HLBG.UI.History.per = HLBG.UI.History.per or 15
    HLBG.UI.History.total = HLBG.UI.History.total or 0
    HLBG.UI.History.sortKey = HLBG.UI.History.sortKey or 'id'
    HLBG.UI.History.sortDir = HLBG.UI.History.sortDir or 'DESC'
    HLBG.UI.History.lastRows = HLBG.UI.History.lastRows or {}

    -- Placeholder and test button
    local histBtn = HLBG.UI.History.HistBtn or CreateFrame("Button", nil, HLBG.UI.History, "UIPanelButtonTemplate")
    histBtn:SetSize(120, 32)
    histBtn:SetPoint("BOTTOM", HLBG.UI.History, "BOTTOM", 0, 40)
    histBtn:SetText("Test History")
    histBtn:SetScript("OnClick", function() DEFAULT_CHAT_FRAME:AddMessage("History tab button clicked!") end)
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
        if ui.page and ui.page > 1 then
            ui.page = ui.page - 1
            -- Request previous page from server
            local cmd = string.format(".hlbg historyui %d %d %s %s", ui.page, ui.per or 15, ui.sortKey or "id", ui.sortDir or "DESC")
            ChatFrameEditBox:SetText(cmd)
            ChatEdit_SendText(ChatFrameEditBox, 0)
            DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99HLBG:|r Requesting page " .. ui.page)
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFAA00HLBG:|r Already on first page")
        end
    end)
    HLBG.UI.History.PrevBtn = prevBtn

    local nextBtn = HLBG.UI.History.NextBtn or CreateFrame("Button", nil, HLBG.UI.History, "UIPanelButtonTemplate")
    nextBtn:SetSize(50, 20)
    nextBtn:SetPoint("BOTTOMRIGHT", HLBG.UI.History, "BOTTOMRIGHT", -50, 20)
    nextBtn:SetText("Next")
    nextBtn:SetNormalTexture("Interface/Buttons/UI-Panel-Button-Red")
    nextBtn:SetHighlightTexture("Interface/Buttons/UI-Panel-Button-Red")
    if nextBtn:GetFontString() then nextBtn:GetFontString():SetTextColor(1,0.82,0,1) end
    nextBtn:SetScript("OnClick", function()
        local ui = HLBG.UI.History
        local maxPage = math.ceil((ui.total or 0) / (ui.per or 15))
        if ui.page and ui.page < maxPage then
            ui.page = ui.page + 1
            -- Request next page from server
            local cmd = string.format(".hlbg historyui %d %d %s %s", ui.page, ui.per or 15, ui.sortKey or "id", ui.sortDir or "DESC")
            ChatFrameEditBox:SetText(cmd)
            ChatEdit_SendText(ChatFrameEditBox, 0)
            DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99HLBG:|r Requesting page " .. ui.page)
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFAA00HLBG:|r Already on last page (page " .. ui.page .. " of " .. maxPage .. ")")
        end
    end)
    HLBG.UI.History.NextBtn = nextBtn

    local pageText = HLBG.UI.History.PageText or HLBG.UI.History:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pageText:SetPoint("BOTTOM", HLBG.UI.History, "BOTTOM", 0, 25)
    pageText:SetText("Page 1 / 1")
    HLBG.UI.History.PageText = pageText
end

if not HLBG.UI.Stats.Content then
    HLBG.UI.Stats.Content = CreateFrame("Frame", nil, HLBG.UI.Stats)
    HLBG.UI.Stats.Content:SetAllPoints()
    
    -- Create scrollable stats frame
    local statsScroll = CreateFrame("ScrollFrame", "HLBG_StatsScrollFrame", HLBG.UI.Stats.Content, "UIPanelScrollFrameTemplate")
    statsScroll:SetPoint("TOPLEFT", HLBG.UI.Stats.Content, "TOPLEFT", 16, -50)
    statsScroll:SetPoint("BOTTOMRIGHT", HLBG.UI.Stats.Content, "BOTTOMRIGHT", -32, 20)
    
    local statsScrollChild = CreateFrame("Frame", nil, statsScroll)
    statsScrollChild:SetSize(560, 1200)  -- Large height for all stats
    statsScroll:SetScrollChild(statsScrollChild)
    
    -- Stats text (matching scoreboard NPC format)
    local statsText = statsScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statsText:SetPoint("TOPLEFT", 8, -8)
    statsText:SetWidth(540)
    statsText:SetJustifyH("LEFT")
    statsText:SetText([[|cFFFFD700Hinterland BG Statistics|r

|cFFFFFFFFTotal records:|r Loading...
|cFFFFFFFFAlliance wins:|r Loading...  |cFFAAAA(losses:|r Loading...)|r
|cFFFFFFFFHorde wins:|r Loading...  |cFFAAAA(losses:|r Loading...)|r
|cFFFFFFFFDraws:|r Loading...  |cFFAAAAManual resets:|r Loading...|r
|cFFFFFFFFWin reasons:|r depletion Loading..., tiebreaker Loading...

|cFFFFFFFFCurrent streak:|r Loading...
|cFFFFFFFFLongest streak:|r Loading...

|cFFFFFFFFLargest margin:|r Loading...

|cFFFFD700Top winners by affix:|r
Loading...

|cFFFFD700Draws by affix:|r
Loading...

|cFFFFD700Top outcomes by affix (incl. draws):|r
Loading...

|cFFFFD700Top affixes by matches:|r
Loading...

|cFFFFD700Average score per affix:|r
Loading...

|cFFAAAAAARequest updated stats with the Refresh button (↻)|r]])
    HLBG.UI.Stats.Text = statsText
    
    -- Refresh button for stats
    local refreshStatsBtn = CreateFrame("Button", nil, HLBG.UI.Stats.Content, "UIPanelButtonTemplate")
    refreshStatsBtn:SetSize(100, 25)
    refreshStatsBtn:SetPoint("TOPRIGHT", HLBG.UI.Stats.Content, "TOPRIGHT", -40, -55)
    refreshStatsBtn:SetText("Refresh")
    refreshStatsBtn:SetScript("OnClick", function()
        -- Request stats from server via chat command
        local cmd = ".hlbg stats"
        ChatFrameEditBox:SetText(cmd)
        ChatEdit_SendText(ChatFrameEditBox, 0)
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99HLBG:|r Requesting statistics...")
    end)
end

-- Stats update function (to be called when stats data arrives from server)
HLBG.UpdateStats = HLBG.UpdateStats or function(statsData)
    if not HLBG.UI.Stats or not HLBG.UI.Stats.Text then return end
    
    if type(statsData) ~= "table" then
        HLBG.UI.Stats.Text:SetText("|cFFFFAA00No statistics data available.|r\n\nUse |cFFFFFFFF.hlbg stats|r command or click Refresh.")
        return
    end
    
    -- Format stats matching scoreboard NPC output
    local lines = {}
    table.insert(lines, "|cFFFFD700Hinterland BG Statistics|r\n")
    
    -- Basic counts
    table.insert(lines, string.format("|cFFFFFFFFTotal records:|r %d", statsData.total or 0))
    table.insert(lines, string.format("|cFFFFFFFFAlliance wins:|r %d  |cFFAAAA(losses:|r %d)|r", statsData.allianceWins or 0, statsData.hordWins or 0))
    table.insert(lines, string.format("|cFFFFFFFFHorde wins:|r %d  |cFFAAAA(losses:|r %d)|r", statsData.hordeWins or 0, statsData.allianceWins or 0))
    table.insert(lines, string.format("|cFFFFFFFFDraws:|r %d  |cFFAAAAManual resets:|r %d|r", statsData.draws or 0, statsData.manual or 0))
    table.insert(lines, string.format("|cFFFFFFFFWin reasons:|r depletion %d, tiebreaker %d\n", statsData.depletionWins or 0, statsData.tiebreakerWins or 0))
    
    -- Streaks
    if statsData.currentStreak then
        table.insert(lines, string.format("|cFFFFFFFFCurrent streak:|r %s x%d", statsData.currentStreak.team or "None", statsData.currentStreak.count or 0))
    end
    if statsData.longestStreak then
        table.insert(lines, string.format("|cFFFFFFFFLongest streak:|r %s x%d\n", statsData.longestStreak.team or "None", statsData.longestStreak.count or 0))
    end
    
    -- Largest margin
    if statsData.largestMargin then
        local m = statsData.largestMargin
        table.insert(lines, string.format("|cFFFFFFFFLargest margin:|r [%s] %s by %d (A:%d H:%d)\n", m.timestamp or "?", m.team or "?", m.margin or 0, m.alliance or 0, m.horde or 0))
    end
    
    -- Top winners by affix
    if statsData.topWinnersByAffix and #statsData.topWinnersByAffix > 0 then
        table.insert(lines, "|cFFFFD700Top winners by affix:|r")
        for _, entry in ipairs(statsData.topWinnersByAffix) do
            table.insert(lines, string.format("- %s: %s wins x%d", entry.affix or "?", entry.team or "?", entry.count or 0))
        end
        table.insert(lines, "")
    end
    
    -- Average scores
    if statsData.averageScores and #statsData.averageScores > 0 then
        table.insert(lines, "|cFFFFD700Average score per affix:|r")
        for _, entry in ipairs(statsData.averageScores) do
            table.insert(lines, string.format("- %s: A:%.1f H:%.1f (n=%d)", entry.affix or "?", entry.avgAlliance or 0, entry.avgHorde or 0, entry.count or 0))
        end
    end
    
    table.insert(lines, "\n|cFFAAAAAALast updated: " .. date("%Y-%m-%d %H:%M:%S") .. "|r")
    
    HLBG.UI.Stats.Text:SetText(table.concat(lines, "\n"))
end

if not HLBG.UI.Info.Content then
    HLBG.UI.Info.Content = CreateFrame("Frame", nil, HLBG.UI.Info)
    HLBG.UI.Info.Content:SetAllPoints()
    
    -- Info content (scrollable text) - no title, tabs are already labeled
    local infoScroll = CreateFrame("ScrollFrame", "HLBG_InfoScrollFrame", HLBG.UI.Info.Content, "UIPanelScrollFrameTemplate")
    infoScroll:SetPoint("TOPLEFT", HLBG.UI.Info.Content, "TOPLEFT", 16, -50)
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
    
    -- Settings title
    local title = HLBG.UI.Settings.Content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", HLBG.UI.Settings.Content, "TOP", 0, -75)
    title:SetText("|cFFFFD700HUD Settings|r")
    
    local yOffset = -110
    
    -- HUD Enable/Disable Checkbox
    local hudEnabledCheck = CreateFrame("CheckButton", "HLBG_HUDEnabledCheck", HLBG.UI.Settings.Content, "UICheckButtonTemplate")
    hudEnabledCheck:SetPoint("TOPLEFT", 40, yOffset)
    hudEnabledCheck:SetChecked(HinterlandAffixHUDDB.hudEnabled ~= false)
    hudEnabledCheck:SetScript("OnClick", function(self)
        HinterlandAffixHUDDB.hudEnabled = self:GetChecked()
        if HinterlandAffixHUDDB.hudEnabled then
            if HLBG.UI.ModernHUD then HLBG.UI.ModernHUD:Show() end
            DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99HLBG:|r HUD enabled")
        else
            if HLBG.UI.ModernHUD then HLBG.UI.ModernHUD:Hide() end
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFAA00HLBG:|r HUD disabled")
        end
    end)
    local hudEnabledLabel = HLBG.UI.Settings.Content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hudEnabledLabel:SetPoint("LEFT", hudEnabledCheck, "RIGHT", 5, 0)
    hudEnabledLabel:SetText("Enable HUD")
    yOffset = yOffset - 35
    
    -- Debug Mode Checkbox
    local debugCheck = CreateFrame("CheckButton", "HLBG_DebugCheck", HLBG.UI.Settings.Content, "UICheckButtonTemplate")
    debugCheck:SetPoint("TOPLEFT", 40, yOffset)
    debugCheck:SetChecked(HinterlandAffixHUDDB.debugMode or false)
    debugCheck:SetScript("OnClick", function(self)
        HinterlandAffixHUDDB.debugMode = self:GetChecked()
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFF33FF99HLBG:|r Debug mode %s", HinterlandAffixHUDDB.debugMode and "enabled" or "disabled"))
    end)
    local debugLabel = HLBG.UI.Settings.Content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    debugLabel:SetPoint("LEFT", debugCheck, "RIGHT", 5, 0)
    debugLabel:SetText("Enable Debug Messages")
    yOffset = yOffset - 35
    
    -- Show HUD Everywhere Checkbox
    local showEverywhereCheck = CreateFrame("CheckButton", "HLBG_ShowEverywhereCheck", HLBG.UI.Settings.Content, "UICheckButtonTemplate")
    showEverywhereCheck:SetPoint("TOPLEFT", 40, yOffset)
    showEverywhereCheck:SetChecked(HinterlandAffixHUDDB.showHudEverywhere or false)
    showEverywhereCheck:SetScript("OnClick", function(self)
        HinterlandAffixHUDDB.showHudEverywhere = self:GetChecked()
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFF33FF99HLBG:|r HUD visibility: %s", HinterlandAffixHUDDB.showHudEverywhere and "show everywhere" or "battleground only"))
        if HLBG.UpdateHUDVisibility then HLBG.UpdateHUDVisibility() end
    end)
    local showEverywhereLabel = HLBG.UI.Settings.Content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    showEverywhereLabel:SetPoint("LEFT", showEverywhereCheck, "RIGHT", 5, 0)
    showEverywhereLabel:SetText("Show HUD Everywhere (not just in BG)")
    yOffset = yOffset - 50
    
    -- HUD Scale Slider
    local scaleSlider = CreateFrame("Slider", "HLBG_ScaleSlider", HLBG.UI.Settings.Content, "OptionsSliderTemplate")
    scaleSlider:SetPoint("TOPLEFT", 40, yOffset)
    scaleSlider:SetMinMaxValues(0.5, 2.0)
    scaleSlider:SetValue(HinterlandAffixHUDDB.hudScale or 1.0)
    scaleSlider:SetValueStep(0.1)
    scaleSlider:SetObeyStepOnDrag(true)
    scaleSlider:SetWidth(200)
    _G[scaleSlider:GetName().."Low"]:SetText("0.5")
    _G[scaleSlider:GetName().."High"]:SetText("2.0")
    _G[scaleSlider:GetName().."Text"]:SetText("HUD Scale")
    scaleSlider:SetScript("OnValueChanged", function(self, value)
        HinterlandAffixHUDDB.hudScale = value
        if HLBG.UI.ModernHUD then HLBG.UI.ModernHUD:SetScale(value) end
        _G[self:GetName().."Text"]:SetText(string.format("HUD Scale: %.1f", value))
    end)
    yOffset = yOffset - 50
    
    -- HUD Alpha Slider
    local alphaSlider = CreateFrame("Slider", "HLBG_AlphaSlider", HLBG.UI.Settings.Content, "OptionsSliderTemplate")
    alphaSlider:SetPoint("TOPLEFT", 40, yOffset)
    alphaSlider:SetMinMaxValues(0.1, 1.0)
    alphaSlider:SetValue(HinterlandAffixHUDDB.hudAlpha or 0.9)
    alphaSlider:SetValueStep(0.05)
    alphaSlider:SetObeyStepOnDrag(true)
    alphaSlider:SetWidth(200)
    _G[alphaSlider:GetName().."Low"]:SetText("10%")
    _G[alphaSlider:GetName().."High"]:SetText("100%")
    _G[alphaSlider:GetName().."Text"]:SetText("HUD Transparency")
    alphaSlider:SetScript("OnValueChanged", function(self, value)
        HinterlandAffixHUDDB.hudAlpha = value
        if HLBG.UI.ModernHUD then HLBG.UI.ModernHUD:SetAlpha(value) end
        _G[self:GetName().."Text"]:SetText(string.format("HUD Alpha: %d%%", value * 100))
    end)
    yOffset = yOffset - 60
    
    -- Reset to Defaults Button
    local resetBtn = CreateFrame("Button", nil, HLBG.UI.Settings.Content, "UIPanelButtonTemplate")
    resetBtn:SetSize(150, 30)
    resetBtn:SetPoint("TOPLEFT", 40, yOffset)
    resetBtn:SetText("Reset to Defaults")
    resetBtn:SetScript("OnClick", function()
        HinterlandAffixHUDDB.hudEnabled = true
        HinterlandAffixHUDDB.debugMode = false
        HinterlandAffixHUDDB.showHudEverywhere = false
        HinterlandAffixHUDDB.hudScale = 1.0
        HinterlandAffixHUDDB.hudAlpha = 0.9
        -- Update UI
        hudEnabledCheck:SetChecked(true)
        debugCheck:SetChecked(false)
        showEverywhereCheck:SetChecked(false)
        scaleSlider:SetValue(1.0)
        alphaSlider:SetValue(0.9)
        if HLBG.UI.ModernHUD then
            HLBG.UI.ModernHUD:Show()
            HLBG.UI.ModernHUD:SetScale(1.0)
            HLBG.UI.ModernHUD:SetAlpha(0.9)
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99HLBG:|r Settings reset to defaults")
    end)
    
    -- Info text
    local infoText = HLBG.UI.Settings.Content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoText:SetPoint("BOTTOM", HLBG.UI.Settings.Content, "BOTTOM", 0, 30)
    infoText:SetWidth(500)
    infoText:SetJustifyH("CENTER")
    infoText:SetText("|cFFAAAAAASettings are saved in:\nWTF/Account/<ACCOUNT>/SavedVariables/HinterlandAffixHUD.lua|r")
end

if not HLBG.UI.Queue.Content then
    HLBG.UI.Queue.Content = CreateFrame("Frame", nil, HLBG.UI.Queue)
    HLBG.UI.Queue.Content:SetAllPoints()
    
    -- Queue title
    local title = HLBG.UI.Queue.Content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", HLBG.UI.Queue.Content, "TOP", 0, -75)
    title:SetText("|cFFFFD700Battleground Queue|r")
    
    -- Queue status text
    local statusText = HLBG.UI.Queue.Content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    statusText:SetPoint("TOP", HLBG.UI.Queue.Content, "TOP", 0, -110)
    statusText:SetWidth(500)
    statusText:SetJustifyH("CENTER")
    statusText:SetText("|cFF00FF00Not in queue|r")
    HLBG.UI.Queue.StatusText = statusText
    
    -- Queue button
    local queueBtn = CreateFrame("Button", "HLBG_QueueButton", HLBG.UI.Queue.Content, "UIPanelButtonTemplate")
    queueBtn:SetSize(180, 35)
    queueBtn:SetPoint("TOP", statusText, "BOTTOM", 0, -30)
    queueBtn:SetText("Join Hinterland BG")
    queueBtn:SetScript("OnClick", function(self)
        -- Toggle queue state
        local inQueue = HLBG._queueState and HLBG._queueState.inQueue or false
        if inQueue then
            -- Leave queue
            local cmd = ".queue leave"
            ChatFrameEditBox:SetText(cmd)
            ChatEdit_SendText(ChatFrameEditBox, 0)
            HLBG._queueState = { inQueue = false }
            statusText:SetText("|cFFAAAAALeft queue|r")
            self:SetText("Join Hinterland BG")
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFAA00HLBG:|r Left battleground queue")
        else
            -- Join queue
            local cmd = ".queue join hinterland"
            ChatFrameEditBox:SetText(cmd)
            ChatEdit_SendText(ChatFrameEditBox, 0)
            HLBG._queueState = { inQueue = true, joinTime = time() }
            statusText:SetText("|cFF00FF00Queued for Hinterland BG|r")
            self:SetText("Leave Queue")
            DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99HLBG:|r Joined battleground queue")
        end
    end)
    HLBG.UI.Queue.QueueButton = queueBtn
    
    -- Queue info text
    local infoText = HLBG.UI.Queue.Content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoText:SetPoint("TOP", queueBtn, "BOTTOM", 0, -20)
    infoText:SetWidth(500)
    infoText:SetJustifyH("CENTER")
    infoText:SetText([[|cFFAAAAAAQueue system is server-controlled.
Button sends queue commands automatically.

You can also use commands manually:
• |cFFFFFFFF.queue join hinterland|r - Join queue
• |cFFFFFFFF.queue leave|r - Leave queue
• |cFFFFFFFF.queue status|r - Check queue status|r]])
    
    -- Initialize queue state
    if not HLBG._queueState then
        HLBG._queueState = { inQueue = false }
    end
end

-- Tab switching function (single instance)
function ShowTab(i)
    -- Debug tab switching
    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFF8800HLBG Debug:|r Switching to tab %d", i))
    
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
        -- Re-render History tab with existing data when shown
        if HLBG.UI.History.lastRows and #HLBG.UI.History.lastRows > 0 and type(HLBG.History) == 'function' then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF8800HLBG Debug:|r Re-rendering History with existing data")
            HLBG.History(HLBG.UI.History.lastRows, HLBG.UI.History.page or 1, HLBG.UI.History.per or 15, HLBG.UI.History.total or #HLBG.UI.History.lastRows, HLBG.UI.History.sortKey or 'id', HLBG.UI.History.sortDir or 'DESC')
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFAA00HLBG Debug:|r No History data to display")
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
                            local per = HLBG.UI.History.per or 5
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
                                if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG:|r History retried and rendered after delay') end
                            else
                                if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage('|cFFFFAA00HLBG:|r Retry completed but no history rows arrived') end
                            end
                        end)
                    else
                        -- Fallback without C_Timer: do a simple request and log
                        HLBG._showTabRetryScheduled = false
                        if _G.AIO and _G.AIO.Handle then pcall(_G.AIO.Handle, 'HLBG', 'Request', 'HISTORY', HLBG.UI.History.page or 1, HLBG.UI.History.per or 5, HLBG.UI.History.sortKey or 'id', HLBG.UI.History.sortDir or 'DESC') end
                        if type(HLBG.safeExecSlash) == 'function' then pcall(HLBG.safeExecSlash, string.format('.hlbg historyui %d %d %s %s', HLBG.UI.History.page or 1, HLBG.UI.History.per or 5, HLBG.UI.History.sortKey or 'id', HLBG.UI.History.sortDir or 'DESC')) end
                    end
                end)
            end
        end
    end
    if i == 2 and HLBG.UI.Stats then HLBG.UI.Stats:Show() end
    if i == 3 and HLBG.UI.Info then HLBG.UI.Info:Show() end
    if i == 4 and HLBG.UI.Settings then HLBG.UI.Settings:Show() end
    if i == 5 and HLBG.UI.Queue then HLBG.UI.Queue:Show() end
    
    -- Update saved tab
    if HinterlandAffixHUDDB then
        HinterlandAffixHUDDB.lastInnerTab = i
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
