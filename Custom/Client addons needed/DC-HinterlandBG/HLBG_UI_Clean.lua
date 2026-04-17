local HLBG = _G.HLBG or {}; _G.HLBG = HLBG
HLBG.UI = HLBG.UI or {}

-- Open the unified leaderboards UI (DC-Leaderboards)
HLBG.OpenLeaderboards = HLBG.OpenLeaderboards or function()
    if _G.DCLeaderboards and type(_G.DCLeaderboards.Toggle) == 'function' then
        _G.DCLeaderboards:Toggle()
        return true
    end
    if _G.SlashCmdList and type(_G.SlashCmdList["DCLEADERBOARDS"]) == 'function' then
        _G.SlashCmdList["DCLEADERBOARDS"]("")
        return true
    end
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFAA00HLBG:|r DC-Leaderboards not loaded. Use |cFFFFFFFF/leaderboard|r if available.")
    end
    return false
end
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
    closeBtn:SetScript("OnClick", function()
        if type(HLBG.CloseMainWindow) == 'function' then
            HLBG.CloseMainWindow()
        else
            HLBG.UI.Frame:Hide()
        end
    end)
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
    refreshBtn:SetText("R")
    refreshBtn:SetScript("OnClick", function()
        -- Stats/History UI moved to DC-Leaderboards; keep refresh lightweight.
        if DEFAULT_CHAT_FRAME then
            local DC = _G.DCAddonProtocol
            local hasDC = DC and "YES" or "NO"
            local hasAIO = _G.AIO and "YES" or "NO"
            DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99HLBG Refresh:|r DCAddonProtocol=" .. hasDC .. " AIO=" .. hasAIO)
        end
        if type(HLBG.RequestStatus) == 'function' then pcall(HLBG.RequestStatus) end
        if type(HLBG.RequestResources) == 'function' then pcall(HLBG.RequestResources) end
    end)
    refreshBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT"); GameTooltip:AddLine("Refresh data", 1,1,1); GameTooltip:Show()
    end)
    refreshBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    HLBG.UI.Frame.RefreshBtn = refreshBtn

    -- Re-apply the selected tab whenever the frame becomes visible.
    HLBG.UI.Frame:SetScript("OnShow", function()
        local showFn = HLBG and HLBG.ShowTab
        if type(showFn) == 'function' then
            local target = (DCHLBGDB and DCHLBGDB.lastInnerTab) or 1
            pcall(showFn, target)
        end
    end)
end
-- Create tabs only once
if not HLBG.UI.Tabs then
    -- Ensure active tab content frames are created before tab wiring.
    if not HLBG.UI.Info then HLBG.UI.Info = CreateFrame("Frame", nil, HLBG.UI.Frame); HLBG.UI.Info:SetAllPoints(HLBG.UI.Frame); HLBG.UI.Info:Hide() end
    if not HLBG.UI.Queue then HLBG.UI.Queue = CreateFrame("Frame", nil, HLBG.UI.Frame); HLBG.UI.Queue:SetAllPoints(HLBG.UI.Frame); HLBG.UI.Queue:Hide() end
    local tabNames = {"Info", "Queue"}
    HLBG.UI.Tabs = {}
    for i = 1, #tabNames do
        HLBG.UI.Tabs[i] = CreateFrame("Button", "HLBG_Tab"..i, HLBG.UI.Frame)
        HLBG.UI.Tabs[i]:SetSize(120, 32)
        HLBG.UI.Tabs[i]:SetPoint("TOPLEFT", 8 + (i-1)*122, -38)
        HLBG.UI.Tabs[i]:SetNormalTexture("Interface/PVPFrame/UI-Character-PVP-Tab")
        HLBG.UI.Tabs[i]:SetHighlightTexture("Interface/PVPFrame/UI-Character-PVP-Tab-Highlight")
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
end
-- Legacy in-window History/Stats/Settings panels were removed.
-- Keep lightweight state tables for protocol handlers and compatibility paths.
HLBG.UI.History = HLBG.UI.History or {}
HLBG.UI.History.rows = HLBG.UI.History.rows or {}
HLBG.UI.History.page = HLBG.UI.History.page or 1
HLBG.UI.History.per = HLBG.UI.History.per or 15
HLBG.UI.History.total = HLBG.UI.History.total or 0
HLBG.UI.History.sortKey = HLBG.UI.History.sortKey or 'id'
HLBG.UI.History.sortDir = HLBG.UI.History.sortDir or 'DESC'
HLBG.UI.History.lastRows = HLBG.UI.History.lastRows or {}
HLBG.UI.Stats = HLBG.UI.Stats or {}

if not HLBG.UI.Info.Content then
    HLBG.UI.Info.Content = CreateFrame("Frame", nil, HLBG.UI.Info)
    HLBG.UI.Info.Content:SetAllPoints()
    HLBG.UI.Info.Content:Show()

    -- Content is rendered by HLBG.UpdateInfo() in HLBG_Info.lua.
    -- Keep this container empty here to avoid duplicate overlays.
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
        if type(HLBG.QueueMessage) == 'function' then
            HLBG.QueueMessage("refreshing")
        end
        -- Set timeout: if no response after 3 seconds, show error
        if C_Timer and C_Timer.After then
            C_Timer.After(3, function()
                -- Only show timeout if status text still shows "Requesting..."
                if HLBG.UI.Queue.StatusText and HLBG.UI.Queue.StatusText:GetText():match("Requesting") then
                    HLBG.UI.Queue.StatusText:SetText(
                        "|cFFFF5555No response from server|r\n\n" ..
                        "Queue system may not be implemented yet.\n" ..
                        "Try talking to Battlemaster NPC 900001 instead.\n\n" ..
                        "|cFFAAAA00Note:|r Queue commands (.hlbgq) are in development.")
                    if type(HLBG.QueueMessage) == 'function' then
                        HLBG.QueueMessage("no_response")
                    end
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
2. Talk to Battlemaster NPC 900001 to queue
3. Alternatively, use the PvP UI if queue system is enabled
|cFFAAAAAANote: You can also use queue commands (/hlbgq join, /hlbgq leave, /hlbgq status).
Check with server administrators for the currently enabled queue method.|r]])
    HLBG.UI.Queue.InfoText = infoText
    -- Auto-request queue status when tab is shown
    HLBG.UI.Queue:SetScript("OnShow", function()
        if type(HLBG.QueueMessage) == 'function' then
            HLBG.QueueMessage("shown_requesting")
        end
        if type(HLBG.RequestQueueStatus) == 'function' then
            C_Timer.After(0.3, function()  -- Small delay to ensure AIO ready
                pcall(HLBG.RequestQueueStatus)
            end)
        else
            if type(HLBG.QueueMessage) == 'function' then
                HLBG.QueueMessage("missing_request_function")
            end
        end
    end)
    -- Initialize queue state
    if not HLBG._queueState then
        HLBG._queueState = { inQueue = false }
    end
end

-- Migrate tab selection from legacy 5-tab layout to the current 2-tab layout.
if DCHLBGDB then
    local layoutVersion = tonumber(DCHLBGDB.innerTabLayoutVersion) or 1
    if layoutVersion < 2 then
        if tonumber(DCHLBGDB.lastInnerTab) == 5 then
            DCHLBGDB.lastInnerTab = 2
        else
            DCHLBGDB.lastInnerTab = 1
        end
        DCHLBGDB.innerTabLayoutVersion = 2
    end
end

-- Tab switching function (single instance)
local function HLBG_ShowTab(i)
    local tabCount = #(HLBG.UI.Tabs or {})
    if tabCount == 0 then
        return
    end

    i = tonumber(i) or 1
    if i < 1 or i > tabCount then
        i = 1
    end

    local debugEnabled = DEFAULT_CHAT_FRAME and (HLBG._devMode or (DCHLBGDB and DCHLBGDB.debugMode))
    if debugEnabled then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFF8800HLBG Debug:|r Switching to tab %d", i))
    end
    -- Visual feedback: highlight the active tab button
    for tabIdx = 1, tabCount do
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
    if HLBG.UI.Info then HLBG.UI.Info:Hide() end
    if HLBG.UI.Queue then HLBG.UI.Queue:Hide() end
    if i == 1 and HLBG.UI.Info then
        HLBG.UI.Info:Show()
        if HLBG.UI.Info.Content then HLBG.UI.Info.Content:Show() end
        if type(HLBG.UpdateInfo) == 'function' then
            pcall(HLBG.UpdateInfo)
        end
    end
    if i == 2 and HLBG.UI.Queue then
        HLBG.UI.Queue:Show()
        if HLBG.UI.Queue.Content then HLBG.UI.Queue.Content:Show() end
    end
    -- Update saved tab
    if DCHLBGDB then
        DCHLBGDB.lastInnerTab = i
    end
end

HLBG.ShowTab = HLBG_ShowTab
_G.HLBG_ShowTab = HLBG_ShowTab

-- Backward-compatible global used by legacy helpers.
function ShowTab(i)
    return HLBG_ShowTab(i)
end

function HLBG.OpenMainWindow(tabIndex)
    if not (HLBG.UI and HLBG.UI.Frame) then
        return false
    end

    HLBG.UI.Frame:Show()
    if HLBG.UI.Frame.Raise then
        HLBG.UI.Frame:Raise()
    end

    local target = tonumber(tabIndex)
        or (DCHLBGDB and tonumber(DCHLBGDB.lastInnerTab))
        or 1
    HLBG_ShowTab(target)
    return true
end

function HLBG.CloseMainWindow()
    if HLBG.UI and HLBG.UI.Frame then
        HLBG.UI.Frame:Hide()
    end

    -- Restore default PvP panes when closing HLBG while PvP is open.
    local pvp = _G["PVPParentFrame"] or _G["PVPFrame"]
    if pvp and pvp.IsShown and pvp:IsShown() then
        if PVPFrameLeft and PVPFrameLeft.Show then
            PVPFrameLeft:Show()
        end
        if PVPFrameRight and PVPFrameRight.Show then
            PVPFrameRight:Show()
        end
    end
end

-- Wire up tab clicks
for idx, tab in ipairs(HLBG.UI.Tabs) do
    local tabIndex = idx
    tab:SetScript("OnClick", function()
        HLBG_ShowTab(tabIndex)
    end)
end
-- Initialize default selected tab without forcing the window visible at addon load.
do
    local tabCount = #(HLBG.UI.Tabs or {})
    local lastTab = DCHLBGDB and tonumber(DCHLBGDB.lastInnerTab) or nil
    if not lastTab or lastTab < 1 or lastTab > tabCount then
        if DCHLBGDB then DCHLBGDB.lastInnerTab = 1 end
    end
    if HLBG.UI.Info then HLBG.UI.Info:Hide() end
    if HLBG.UI.Queue then HLBG.UI.Queue:Hide() end
end

-- Ensure UI helper function
function HLBG._ensureUI(name)
    if not (type(HLBG) == 'table' and type(HLBG.UI) == 'table') then return false end
    if not name then return true end

    -- Compatibility alias for modules still requesting legacy panel names.
    if name == 'Live' then
        return HLBG.UI.Live ~= nil or HLBG.UI.Frame ~= nil
    end

    return HLBG.UI[name] ~= nil
end
DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00HLBG:|r Clean UI loaded successfully")


