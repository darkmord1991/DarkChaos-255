local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

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

-- Create content frames only once
if not HLBG.UI.History then
    local histBtn = CreateFrame("Button", nil, HLBG.UI.History, "UIPanelButtonTemplate")
    histBtn:SetSize(120, 32)
    histBtn:SetPoint("BOTTOM", HLBG.UI.History, "BOTTOM", 0, 40)
    histBtn:SetText("Test History")
    histBtn:SetScript("OnClick", function() DEFAULT_CHAT_FRAME:AddMessage("History tab button clicked!") end)
    -- Placeholder for History
    local histText = HLBG.UI.History:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    histText:SetPoint("CENTER", HLBG.UI.History, "CENTER", 0, 0)
    histText:SetText("No history data loaded.")
    histText:SetTextColor(1,1,1,1)
    HLBG.UI.History.Placeholder = histText
    HLBG.UI.History = CreateFrame("Frame", nil, HLBG.UI.Frame)
    HLBG.UI.History:SetAllPoints(HLBG.UI.Frame)
    HLBG.UI.History:Hide()
    HLBG.UI.History.Scroll = CreateFrame("ScrollFrame", "HLBG_HistoryScroll", HLBG.UI.History, "UIPanelScrollFrameTemplate")
    HLBG.UI.History.Scroll:SetPoint("TOPLEFT", 16, -40)
    HLBG.UI.History.Scroll:SetPoint("BOTTOMRIGHT", -36, 16)
    HLBG.UI.History.Content = CreateFrame("Frame", nil, HLBG.UI.History.Scroll)
    HLBG.UI.History.Content:SetSize(580, 380)
    HLBG.UI.History.Scroll:SetScrollChild(HLBG.UI.History.Content)
    HLBG.UI.History.rows = {}
    HLBG.UI.History.page = 1
    HLBG.UI.History.per = 15
    HLBG.UI.History.total = 0
    HLBG.UI.History.sortKey = 'id'
    HLBG.UI.History.sortDir = 'DESC'
    HLBG.UI.History.lastRows = {}
    
    -- Add pagination controls
    local prevBtn = CreateFrame("Button", nil, HLBG.UI.History, "UIPanelButtonTemplate")
    prevBtn:SetSize(50, 20)
    prevBtn:SetPoint("BOTTOMLEFT", HLBG.UI.History, "BOTTOMLEFT", 20, 20)
    prevBtn:SetText("Prev")
    prevBtn:SetNormalTexture("Interface/Buttons/UI-Panel-Button-Red")
    prevBtn:SetHighlightTexture("Interface/Buttons/UI-Panel-Button-Red")
    if prevBtn:GetFontString() then prevBtn:GetFontString():SetTextColor(1,0.82,0,1) end
    HLBG.UI.History.PrevBtn = prevBtn
    
    local nextBtn = CreateFrame("Button", nil, HLBG.UI.History, "UIPanelButtonTemplate")
    nextBtn:SetSize(50, 20)
    nextBtn:SetPoint("BOTTOMRIGHT", HLBG.UI.History, "BOTTOMRIGHT", -50, 20)
    nextBtn:SetText("Next")
    nextBtn:SetNormalTexture("Interface/Buttons/UI-Panel-Button-Red")
    nextBtn:SetHighlightTexture("Interface/Buttons/UI-Panel-Button-Red")
    if nextBtn:GetFontString() then nextBtn:GetFontString():SetTextColor(1,0.82,0,1) end
    HLBG.UI.History.NextBtn = nextBtn
    
    local pageText = HLBG.UI.History:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pageText:SetPoint("BOTTOM", HLBG.UI.History, "BOTTOM", 0, 25)
    pageText:SetText("Page 1 / 1")
    HLBG.UI.History.PageText = pageText
end

if not HLBG.UI.Stats then
    local statsBtn = CreateFrame("Button", nil, HLBG.UI.Stats, "UIPanelButtonTemplate")
    statsBtn:SetSize(120, 32)
    statsBtn:SetPoint("BOTTOM", HLBG.UI.Stats, "BOTTOM", 0, 40)
    statsBtn:SetText("Test Stats")
    statsBtn:SetScript("OnClick", function() DEFAULT_CHAT_FRAME:AddMessage("Stats tab button clicked!") end)
    -- Placeholder for Stats
    local statsText = HLBG.UI.Stats:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    statsText:SetPoint("CENTER", HLBG.UI.Stats, "CENTER", 0, 0)
    statsText:SetText("No stats data loaded.")
    statsText:SetTextColor(1,1,1,1)
    HLBG.UI.Stats.Placeholder = statsText
    HLBG.UI.Stats = CreateFrame("Frame", nil, HLBG.UI.Frame)
    HLBG.UI.Stats:SetAllPoints(HLBG.UI.Frame)
    HLBG.UI.Stats:Hide()
    
    -- Create proper Stats UI elements
    local statsText = HLBG.UI.Stats:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    statsText:SetPoint("TOP", HLBG.UI.Stats, "TOP", 0, -50)
    statsText:SetText("Season Statistics")
    
    local dataText = HLBG.UI.Stats:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dataText:SetPoint("TOP", statsText, "BOTTOM", 0, -20)
    dataText:SetText("Loading stats data...")
    HLBG.UI.Stats.Text = dataText  -- This is what HLBG.Stats function expects
    
    -- Add more detailed stats display
    local detailText = HLBG.UI.Stats:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    detailText:SetPoint("TOP", dataText, "BOTTOM", 0, -20)
    detailText:SetText("")
    HLBG.UI.Stats.DetailText = detailText
end

if not HLBG.UI.Info then
    local infoBtn = CreateFrame("Button", nil, HLBG.UI.Info, "UIPanelButtonTemplate")
    infoBtn:SetSize(120, 32)
    infoBtn:SetPoint("BOTTOM", HLBG.UI.Info, "BOTTOM", 0, 40)
    infoBtn:SetText("Test Info")
    infoBtn:SetScript("OnClick", function() DEFAULT_CHAT_FRAME:AddMessage("Info tab button clicked!") end)
    -- Placeholder for Info
    local infoText = HLBG.UI.Info:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    infoText:SetPoint("CENTER", HLBG.UI.Info, "CENTER", 0, 0)
    infoText:SetText("Info tab placeholder.")
    infoText:SetTextColor(1,1,1,1)
    HLBG.UI.Info.Placeholder = infoText
    HLBG.UI.Info = CreateFrame("Frame", nil, HLBG.UI.Frame)
    HLBG.UI.Info:SetAllPoints(HLBG.UI.Frame)
    HLBG.UI.Info:Hide()
    HLBG.UI.Info.Content = CreateFrame("Frame", nil, HLBG.UI.Info)
    HLBG.UI.Info.Content:SetAllPoints()
    -- Populate Info tab immediately
    C_Timer.After(0.1, function()
        if HLBG.UpdateInfo and type(HLBG.UpdateInfo) == 'function' then
            HLBG.UpdateInfo()
        end
    end)
end

if not HLBG.UI.Settings then
    local setBtn = CreateFrame("Button", nil, HLBG.UI.Settings, "UIPanelButtonTemplate")
    setBtn:SetSize(120, 32)
    setBtn:SetPoint("BOTTOM", HLBG.UI.Settings, "BOTTOM", 0, 40)
    setBtn:SetText("Test Settings")
    setBtn:SetScript("OnClick", function() DEFAULT_CHAT_FRAME:AddMessage("Settings tab button clicked!") end)
    -- Placeholder for Settings
    local setText = HLBG.UI.Settings:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    setText:SetPoint("CENTER", HLBG.UI.Settings, "CENTER", 0, 0)
    setText:SetText("Settings tab placeholder.")
    setText:SetTextColor(1,1,1,1)
    HLBG.UI.Settings.Placeholder = setText
    HLBG.UI.Settings = CreateFrame("Frame", nil, HLBG.UI.Frame)
    HLBG.UI.Settings:SetAllPoints(HLBG.UI.Frame)
    HLBG.UI.Settings:Hide()
    HLBG.UI.Settings.Content = CreateFrame("Frame", nil, HLBG.UI.Settings)
    HLBG.UI.Settings.Content:SetAllPoints()
    -- Populate Settings tab immediately
    C_Timer.After(0.1, function()
        if HLBG.UpdateSettings and type(HLBG.UpdateSettings) == 'function' then
            HLBG.UpdateSettings()
        end
    end)
end

if not HLBG.UI.Queue then
    local queueBtn = CreateFrame("Button", nil, HLBG.UI.Queue, "UIPanelButtonTemplate")
    queueBtn:SetSize(120, 32)
    queueBtn:SetPoint("BOTTOM", HLBG.UI.Queue, "BOTTOM", 0, 40)
    queueBtn:SetText("Test Queue")
    queueBtn:SetScript("OnClick", function() DEFAULT_CHAT_FRAME:AddMessage("Queue tab button clicked!") end)
    -- Placeholder for Queue
    local queueText = HLBG.UI.Queue:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    queueText:SetPoint("CENTER", HLBG.UI.Queue, "CENTER", 0, 0)
    queueText:SetText("Queue tab placeholder.")
    queueText:SetTextColor(1,1,1,1)
    HLBG.UI.Queue.Placeholder = queueText
    HLBG.UI.Queue = CreateFrame("Frame", nil, HLBG.UI.Frame)
    HLBG.UI.Queue:SetAllPoints(HLBG.UI.Frame)
    HLBG.UI.Queue:Hide()
    
    -- Add queue status display
    local queueText = HLBG.UI.Queue:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    queueText:SetPoint("TOP", HLBG.UI.Queue, "TOP", 0, -50)
    queueText:SetText("Queue Status")
    
    local statusText = HLBG.UI.Queue:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusText:SetPoint("CENTER", HLBG.UI.Queue, "CENTER", 0, 0)
    statusText:SetText("Not in queue\n\nUse server commands to queue for battleground")
    HLBG.UI.Queue.StatusText = statusText
end

-- Tab switching function (single instance)
function ShowTab(i)
    -- Debug tab switching
    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFF8800HLBG Debug:|r Switching to tab %d", i))
    
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
