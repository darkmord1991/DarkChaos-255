-- HLBG_AIO_Client.lua - Clean AIO integration for HLBG addon
-- Compatible with WotLK 3.3.5a client

local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

-- Initialize saved variables for UI
HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
if HinterlandAffixHUDDB.disableChatUpdates == nil then 
    HinterlandAffixHUDDB.disableChatUpdates = true 
end

-- UI Tab constants
HLBG.UI = HLBG.UI or {}
HLBG.UI.TAB_LIVE = 1
HLBG.UI.TAB_HISTORY = 2
HLBG.UI.TAB_STATS = 3
HLBG.UI.TAB_SETTINGS = 4

-- History buffer and stats
HLBG._histBuf = HLBG._histBuf or {}
HLBG._cachedStats = HLBG._cachedStats or {}

-- UI Frame reference
local mainFrame = nil

-- Create main UI frame (3.3.5a compatible)
local function CreateMainUI()
    if mainFrame then return mainFrame end
    
    mainFrame = CreateFrame("Frame", "HLBG_MainFrame", UIParent)
    mainFrame:SetSize(650, 450)
    mainFrame:SetPoint("CENTER")
    
    -- 3.3.5a compatible backdrop
    mainFrame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    mainFrame:SetBackdropColor(0, 0, 0, 0.9)
    
    -- Make draggable
    mainFrame:EnableMouse(true)
    mainFrame:SetMovable(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetClampedToScreen(true)
    mainFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    mainFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", 0, 0)
    
    -- Title
    local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Hinterland Battleground")
    
    -- Tab buttons (3.3.5a compatible)
    local tabs = {}
    local tabNames = {"Live", "History", "Stats", "Settings"}
    
    for i, name in ipairs(tabNames) do
        -- Use CharacterFrameTabButtonTemplate for better 3.3.5a compatibility
        local tab = CreateFrame("Button", "HLBG_Tab"..i, mainFrame, "CharacterFrameTabButtonTemplate")
        tab:SetText(name)
        tab:SetID(i)
        
        if i == 1 then
            tab:SetPoint("TOPLEFT", mainFrame, "BOTTOMLEFT", 10, 7)
        else
            tab:SetPoint("LEFT", tabs[i-1], "RIGHT", -15, 0)
        end
        
        tab:SetScript("OnClick", function(self) 
            HLBG.ShowTab(self:GetID()) 
        end)
        
        tabs[i] = tab
    end
    
    mainFrame.tabs = tabs
    
    -- Content area
    local contentArea = CreateFrame("ScrollFrame", "HLBG_ContentArea", mainFrame, "UIPanelScrollFrameTemplate")
    contentArea:SetPoint("TOPLEFT", 16, -50)
    contentArea:SetPoint("BOTTOMRIGHT", -32, 16)
    
    local scrollChild = CreateFrame("Frame", nil, contentArea)
    scrollChild:SetSize(600, 380)
    contentArea:SetScrollChild(scrollChild)
    
    -- Content frames for each tab
    local contentFrames = {}
    local tabContent = {
        "Live Status:\nWaiting for server data...\n\nUse the HUD in the top corners to see live battle status.",
        "Battle History:\nNo history data available yet.\n\nThis will show the last 10 battles with dates and winners.",
        "Statistics:\nNo statistics available yet.\n\nThis will show win rates, average duration, and affix performance.",
        "Settings:\nChat Updates: " .. (HinterlandAffixHUDDB.disableChatUpdates and "Disabled" or "Enabled") .. "\nHUD Display: Enabled\n\nUse /hlbghud commands to configure the addon."
    }
    
    for i = 1, 4 do
        local frame = CreateFrame("Frame", nil, scrollChild)
        frame:SetAllPoints(scrollChild)
        frame:Hide()
        
        local content = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        content:SetPoint("TOPLEFT", 10, -10)
        content:SetPoint("TOPRIGHT", -10, -10)
        content:SetJustifyH("LEFT")
        content:SetText(tabContent[i])
        frame.content = content
        
        contentFrames[i] = frame
    end
    
    mainFrame.contentFrames = contentFrames
    mainFrame.currentTab = 1
    
    return mainFrame
end

-- Show specific tab
function HLBG.ShowTab(tabIndex)
    local frame = CreateMainUI()
    if not frame or not frame.contentFrames then return end
    
    -- Hide all tabs
    for i, contentFrame in ipairs(frame.contentFrames) do
        contentFrame:Hide()
    end
    
    -- Show selected tab
    if frame.contentFrames[tabIndex] then
        frame.contentFrames[tabIndex]:Show()
        frame.currentTab = tabIndex
        
        -- Update tab appearance (simplified)
        for i, tab in ipairs(frame.tabs) do
            if i == tabIndex then
                -- Make active tab look highlighted
                tab:SetAlpha(1.0)
            else
                tab:SetAlpha(0.7)
            end
        end
    end
end

-- Main ShowUI function that was missing
function HLBG.ShowUI(tabIndex)
    local frame = CreateMainUI()
    if not frame then 
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[HLBG]|r Failed to create UI frame")
        end
        return false
    end
    
    frame:Show()
    
    -- Show specific tab if requested
    if tabIndex and type(tabIndex) == "number" and tabIndex >= 1 and tabIndex <= 4 then
        HLBG.ShowTab(tabIndex)
    else
        HLBG.ShowTab(1) -- Default to Live tab
    end
    
    -- Request fresh data when opening UI
    if AIO and AIO.Handle then
        AIO.Handle("HLBG", "RequestStatus")
        AIO.Handle("HLBG", "RequestHistory")
        AIO.Handle("HLBG", "RequestStats")
    end
    
    return true
end

-- Update live status
function HLBG.UpdateLiveStatus(data)
    local frame = CreateMainUI()
    if frame and frame.contentFrames[1] then
        local text = "Live Status:\n"
        if data then
            text = text .. string.format("Alliance: %s\nHorde: %s\n", 
                tostring(data.A or "?"), tostring(data.H or "?"))
            if data.affix then
                text = text .. "Affix: " .. tostring(data.affix) .. "\n"
            end
            if data.timeLeft then
                text = text .. "Time Left: " .. tostring(data.timeLeft) .. "\n"
            end
        else
            text = text .. "No data available"
        end
        frame.contentFrames[1].content:SetText(text)
    end
end

-- Update history display
function HLBG.UpdateHistory(historyData)
    local frame = CreateMainUI()
    if frame and frame.contentFrames[2] then
        local text = "Recent History:\n\n"
        if historyData and type(historyData) == "table" and #historyData > 0 then
            for i, entry in ipairs(historyData) do
                if i > 10 then break end -- Show only last 10
                local date = tostring(entry.date or entry.ts or entry.occurred_at or "?")
                local winner = tostring(entry.winner or "?")
                local line = string.format("%s - %s won\n", date, winner)
                text = text .. line
            end
        else
            text = text .. "No history available"
        end
        frame.contentFrames[2].content:SetText(text)
    end
    
    -- Also store in buffer for stats calculation
    if historyData and type(historyData) == "table" then
        HLBG._histBuf = historyData
        HLBG._recomputeStats()
    end
end

-- Update stats display
function HLBG.UpdateStats(statsData)
    local frame = CreateMainUI()
    if frame and frame.contentFrames[3] then
        local text = "Statistics:\n\n"
        if statsData and type(statsData) == "table" then
            text = text .. string.format("Alliance Wins: %s\n", tostring(statsData.allianceWins or 0))
            text = text .. string.format("Horde Wins: %s\n", tostring(statsData.hordeWins or 0))
            text = text .. string.format("Draws: %s\n", tostring(statsData.draws or 0))
            text = text .. string.format("Total Games: %s\n", tostring(statsData.total or 0))
        else
            text = text .. "No statistics available"
        end
        frame.contentFrames[3].content:SetText(text)
    end
    
    HLBG._cachedStats = statsData or {}
end

-- Recompute stats from history buffer
function HLBG._recomputeStats()
    local stats = {allianceWins = 0, hordeWins = 0, draws = 0, total = 0}
    
    for _, entry in ipairs(HLBG._histBuf or {}) do
        stats.total = stats.total + 1
        local winner = tostring(entry.winner or ""):lower()
        if winner == "alliance" then
            stats.allianceWins = stats.allianceWins + 1
        elseif winner == "horde" then
            stats.hordeWins = stats.hordeWins + 1
        else
            stats.draws = stats.draws + 1
        end
    end
    
    HLBG._cachedStats = stats
    HLBG.UpdateStats(stats)
end

-- Generate test data
function HLBG.GenerateTestData()
    -- Test live status
    HLBG.UpdateLiveStatus({
        A = 350,
        H = 280,
        affix = "Bloodlust",
        timeLeft = "15:30"
    })
    
    -- Test history
    local testHistory = {}
    local winners = {"Alliance", "Horde", "Draw"}
    for i = 1, 12 do
        table.insert(testHistory, {
            id = i,
            date = date("%Y-%m-%d %H:%M:%S", time() - (i * 3600)),
            winner = winners[math.random(1, 3)],
            affix = "Affix" .. math.random(1, 5)
        })
    end
    HLBG.UpdateHistory(testHistory)
end

-- AIO Integration with error handling
HLBG.InitializeAfterAIO = function()
    if not AIO or not AIO.AddHandlers then
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[HLBG AIO]|r AIO client not available")
        end
        return false
    end

    -- Register AIO handlers with error protection
    local success, handlers = pcall(function()
        return AIO.AddHandlers("HLBG", {})
    end)
    
    if not success or not handlers then
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[HLBG AIO]|r Failed to register handlers")
        end
        return false
    end
    
    -- Status handler - updates HUD and live tab
    handlers.Status = function(player, data)
        if type(data) == "table" then
            -- Update core HUD if available
            if HLBG.UpdateStatus then
                HLBG.UpdateStatus(data)
            end
            -- Update live tab
            HLBG.UpdateLiveStatus(data)
        end
    end
    
    -- History handler
    handlers.History = function(player, data)
        if type(data) == "table" then
            HLBG.UpdateHistory(data)
        end
    end
    
    -- Stats handler
    handlers.Stats = function(player, data)
        if type(data) == "table" then
            HLBG.UpdateStats(data)
        end
    end
    
    -- ShowUI handler
    handlers.ShowUI = function(player, tabIndex)
        HLBG.ShowUI(tabIndex or 1)
    end
    
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[HLBG AIO]|r Integration active")
    end
    
    return true
end

-- Enhanced slash commands
local function RegisterSlashCommands()
    SLASH_HLBG1 = "/hlbg"
    SLASH_HLBG2 = "/hinterland"
    SlashCmdList["HLBG"] = function(msg)
        local args = {}
        for arg in msg:gmatch("%S+") do
            table.insert(args, arg:lower())
        end
        
        local command = args[1] or ""
        
        if command == "test" then
            HLBG.GenerateTestData()
            HLBG.ShowUI(1)
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[HLBG]|r Test data loaded")
        elseif command == "ui" or command == "" then
            HLBG.ShowUI()
        elseif command == "live" then
            HLBG.ShowUI(1)
        elseif command == "history" then
            HLBG.ShowUI(2)
        elseif command == "stats" then
            HLBG.ShowUI(3)
        elseif command == "settings" then
            HLBG.ShowUI(4)
        elseif command == "help" then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[HLBG]|r Commands:")
            DEFAULT_CHAT_FRAME:AddMessage("  /hlbg - Open main UI")
            DEFAULT_CHAT_FRAME:AddMessage("  /hlbg live/history/stats/settings - Open specific tab")
            DEFAULT_CHAT_FRAME:AddMessage("  /hlbg test - Load test data")
            DEFAULT_CHAT_FRAME:AddMessage("  /hlbghud - Configure HUD display")
        else
            HLBG.ShowUI()
        end
    end
end

-- Robust initialization system
local function InitializeHLBG()
    -- Try to initialize AIO
    if HLBG.InitializeAfterAIO() then
        return
    end
    
    -- If AIO isn't ready, set up event listener
    local initFrame = CreateFrame("Frame")
    local attempts = 0
    local maxAttempts = 30 -- 15 seconds max wait
    
    initFrame:SetScript("OnUpdate", function(self, elapsed)
        attempts = attempts + 1
        
        if AIO and AIO.AddHandlers then
            HLBG.InitializeAfterAIO()
            self:SetScript("OnUpdate", nil)
            return
        end
        
        if attempts >= maxAttempts then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF8800[HLBG]|r AIO not found - UI available, server features disabled")
            self:SetScript("OnUpdate", nil)
        end
    end)
    
    -- Also listen for addon load events
    initFrame:RegisterEvent("ADDON_LOADED")
    initFrame:SetScript("OnEvent", function(self, event, addonName)
        if addonName == "AIO_Client" or addonName == "AIO" then
            if HLBG.InitializeAfterAIO() then
                self:SetScript("OnUpdate", nil)
                self:UnregisterEvent("ADDON_LOADED")
            end
        end
    end)
end

-- Register commands and initialize
RegisterSlashCommands()
InitializeHLBG()

if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00EEFF[HLBG]|r UI client loaded - Use /hlbg to open")
end