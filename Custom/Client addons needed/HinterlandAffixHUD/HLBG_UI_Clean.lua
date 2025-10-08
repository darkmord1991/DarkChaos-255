-- Clean HLBG_UI.lua - Essential UI only, no duplicates
local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

HLBG.UI = HLBG.UI or {}

-- Essential UI creation (no duplicates)
if not HLBG.UI.Frame then
    HLBG.UI.Frame = CreateFrame("Frame", "HLBG_Main", PVPParentFrame or PVPFrame)
    HLBG.UI.Frame:SetSize(640, 450)
    HLBG.UI.Frame:Hide()
    if HLBG.UI.Frame.SetFrameStrata then HLBG.UI.Frame:SetFrameStrata("DIALOG") end
    HLBG.UI.Frame:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left=4, right=4, top=4, bottom=4 } })
    HLBG.UI.Frame:SetBackdropColor(0,0,0,0.5)
    HLBG.UI.Frame:ClearAllPoints()
    HLBG.UI.Frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    HLBG.UI.Frame:EnableMouse(true)
    HLBG.UI.Frame:SetMovable(true)
    HLBG.UI.Frame:RegisterForDrag("LeftButton")
    HLBG.UI.Frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    HLBG.UI.Frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
end

-- Create tabs only once
if not HLBG.UI.Tabs then
    HLBG.UI.Tabs = {}
    for i = 1, 5 do
        HLBG.UI.Tabs[i] = CreateFrame("Button", "HLBG_Tab"..i, HLBG.UI.Frame)
        HLBG.UI.Tabs[i]:SetSize(100, 32)
        HLBG.UI.Tabs[i]:SetPoint("TOPLEFT", 8 + (i-1)*102, -8)
        HLBG.UI.Tabs[i]:SetNormalTexture("Interface/ChatFrame/ChatFrameTab")
        HLBG.UI.Tabs[i]:SetHighlightTexture("Interface/ChatFrame/ChatFrameTab")
        local text = HLBG.UI.Tabs[i]:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("CENTER")
        HLBG.UI.Tabs[i].text = text
    end
    
    HLBG.UI.Tabs[1].text:SetText("History")
    HLBG.UI.Tabs[2].text:SetText("Stats")
    HLBG.UI.Tabs[3].text:SetText("Info")
    HLBG.UI.Tabs[4].text:SetText("Settings")
    HLBG.UI.Tabs[5].text:SetText("Queue")
end

-- Create content frames only once
if not HLBG.UI.History then
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
    HLBG.UI.History.PrevBtn = prevBtn
    
    local nextBtn = CreateFrame("Button", nil, HLBG.UI.History, "UIPanelButtonTemplate")
    nextBtn:SetSize(50, 20)
    nextBtn:SetPoint("BOTTOMRIGHT", HLBG.UI.History, "BOTTOMRIGHT", -50, 20)
    nextBtn:SetText("Next")
    HLBG.UI.History.NextBtn = nextBtn
    
    local pageText = HLBG.UI.History:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pageText:SetPoint("BOTTOM", HLBG.UI.History, "BOTTOM", 0, 25)
    pageText:SetText("Page 1 / 1")
    HLBG.UI.History.PageText = pageText
end

if not HLBG.UI.Stats then
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
    
    if HLBG.UI.History then 
        if i == 1 then 
            HLBG.UI.History:Show()
            -- Re-render History tab with existing data when shown
            if HLBG.UI.History.lastRows and #HLBG.UI.History.lastRows > 0 and type(HLBG.History) == 'function' then
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF8800HLBG Debug:|r Re-rendering History with existing data")
                HLBG.History(HLBG.UI.History.lastRows, HLBG.UI.History.page or 1, HLBG.UI.History.per or 15, HLBG.UI.History.total or #HLBG.UI.History.lastRows, HLBG.UI.History.sortKey or 'id', HLBG.UI.History.sortDir or 'DESC')
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFFAA00HLBG Debug:|r No History data to display")
            end
        else 
            HLBG.UI.History:Hide() 
        end 
    end
    if HLBG.UI.Stats then 
        if i == 2 then 
            HLBG.UI.Stats:Show()
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF8800HLBG Debug:|r Stats tab shown")
        else 
            HLBG.UI.Stats:Hide() 
        end 
    end
    if HLBG.UI.Info then 
        if i == 3 then 
            HLBG.UI.Info:Show()
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF8800HLBG Debug:|r Info tab shown")
        else 
            HLBG.UI.Info:Hide() 
        end 
    end
    if HLBG.UI.Settings then 
        if i == 4 then 
            HLBG.UI.Settings:Show()
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF8800HLBG Debug:|r Settings tab shown")
        else 
            HLBG.UI.Settings:Hide() 
        end 
    end
    if HLBG.UI.Queue then 
        if i == 5 then 
            HLBG.UI.Queue:Show()
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF8800HLBG Debug:|r Queue tab shown")
        else 
            HLBG.UI.Queue:Hide() 
        end 
    end
    
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