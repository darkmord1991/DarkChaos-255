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
        "" -- Will be populated with interactive elements
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
    -- Store the latest status for season/settings updates
    if data then
        HLBG.lastStatus = data
    end
    
    local frame = CreateMainUI()
    if frame and frame.contentFrames[1] then
        local text = "Current Battleground Status:\n\n"
        if data then
            text = text .. string.format("Alliance: %s\nHorde: %s\n\n", 
                tostring(data.A or "?"), tostring(data.H or "?"))
            
            -- Handle affix display
            if data.affix then
                local affixName = "Unknown"
                if type(data.affix) == "number" then
                    local affixNames = {
                        [1] = "Bloodlust",
                        [2] = "Regeneration", 
                        [3] = "Speed Boost",
                        [4] = "Damage Shield",
                        [5] = "Mana Shield"
                    }
                    affixName = affixNames[data.affix] or ("Affix " .. data.affix)
                else
                    affixName = tostring(data.affix)
                end
                text = text .. "Affix: " .. affixName .. "\n"
            end
            
            -- Handle time display
            if data.timeLeft then
                local timeStr = "Unknown"
                if type(data.timeLeft) == "number" then
                    local minutes = math.floor(data.timeLeft / 60)
                    local seconds = data.timeLeft % 60
                    timeStr = string.format("%d:%02d", minutes, seconds)
                else
                    timeStr = tostring(data.timeLeft)
                end
                text = text .. "Time Left: " .. timeStr .. "\n"
            elseif data.END then
                local remaining = data.END - time()
                if remaining > 0 then
                    local minutes = math.floor(remaining / 60)
                    local seconds = remaining % 60
                    text = text .. string.format("Time Left: %d:%02d\n", minutes, seconds)
                else
                    text = text .. "Time Left: 0:00\n"
                end
            end
            
            text = text .. "\n=== Server Configuration ===\n"
            
            if HLBG.serverSettings then
                text = text .. string.format("BG Duration: %s minutes\n", tostring(HLBG.serverSettings.duration or "Unknown"))
                text = text .. string.format("Max Players: %s per side\n", tostring(HLBG.serverSettings.maxPlayers or "Unknown"))
                text = text .. string.format("Min Level: %s\n", tostring(HLBG.serverSettings.minLevel or "Unknown"))
                text = text .. string.format("Max Level: %s\n", tostring(HLBG.serverSettings.maxLevel or "Unknown"))
                text = text .. string.format("Affix Rotation: %s\n", HLBG.serverSettings.affixEnabled and "Enabled" or "Disabled")
                text = text .. string.format("Resource Cap: %s\n", tostring(HLBG.serverSettings.resourceCap or "Unknown"))
                text = text .. string.format("Queue Type: %s\n", tostring(HLBG.serverSettings.queueType or "Unknown"))
            else
                text = text .. "Loading configuration from server...\n"
                text = text .. "Use AIO to request: 'RequestServerConfig'\n"
            end
            
            if HLBG.currentSeason then
                text = text .. string.format("\n=== Current Season ===\n")
                text = text .. string.format("Name: %s\n", tostring(HLBG.currentSeason.name or "Unknown"))
                text = text .. string.format("Start: %s\n", tostring(HLBG.currentSeason.startDate or "Unknown"))
                text = text .. string.format("End: %s\n", tostring(HLBG.currentSeason.endDate or "Unknown"))
                text = text .. string.format("Rewards: %s\n", tostring(HLBG.currentSeason.rewards or "Unknown"))
            else
                text = text .. "\n=== Season Info ===\n"
                text = text .. "Loading season from server...\n"
            end
            
            text = text .. "\nDB Query: SELECT * FROM hlbg_config"
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
                if i > 24 then break end -- Show last 24 entries
                local date = tostring(entry.date or entry.ts or entry.occurred_at or "?")
                local winner = tostring(entry.winner or "?")
                local affix = ""
                if entry.affix then
                    local affixNames = {[1] = "Bloodlust", [2] = "Regeneration", [3] = "Speed", [4] = "Shield", [5] = "Mana"}
                    affix = " (" .. (affixNames[entry.affix] or ("Affix" .. entry.affix)) .. ")"
                end
                local line = string.format("%s - %s won%s\n", date, winner, affix)
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

-- Update comprehensive stats display
function HLBG.UpdateStats(statsData)
    local frame = CreateMainUI()
    if frame and frame.contentFrames[3] then
        local text = "HLBG Statistics:\n\n"
        if statsData and type(statsData) == "table" then
            if statsData.note then
                text = text .. statsData.note .. "\n\n"
            end
            
            -- Core Statistics
            text = text .. "=== Battle Results ===\n"
            text = text .. string.format("Total Runs: %s\n", tostring(statsData.totalRuns or 0))
            text = text .. string.format("Alliance Wins: %s\n", tostring(statsData.allianceWins or 0))
            text = text .. string.format("Horde Wins: %s\n", tostring(statsData.hordeWins or 0))
            text = text .. string.format("Draws: %s\n", tostring(statsData.draws or 0))
            text = text .. string.format("Manual Resets: %s\n", tostring(statsData.manualResets or 0))
            
            -- Win Rates
            local total = (statsData.totalRuns or 0)
            if total > 0 then
                local allianceRate = math.floor(((statsData.allianceWins or 0) / total) * 100)
                local hordeRate = math.floor(((statsData.hordeWins or 0) / total) * 100) 
                local drawRate = math.floor(((statsData.draws or 0) / total) * 100)
                text = text .. string.format("\n=== Win Rates ===\n")
                text = text .. string.format("Alliance: %d%%\n", allianceRate)
                text = text .. string.format("Horde: %d%%\n", hordeRate)
                text = text .. string.format("Draws: %d%%\n", drawRate)
            end
            
            -- Win Streaks
            text = text .. "\n=== Win Streaks ===\n"
            if statsData.currentWinStreak then
                text = text .. string.format("Current: %s (%d)\n", 
                    tostring(statsData.currentWinStreak.faction or "None"), 
                    tonumber(statsData.currentWinStreak.count or 0))
            end
            if statsData.longestWinStreak then
                text = text .. string.format("Record: %s (%d)\n",
                    tostring(statsData.longestWinStreak.faction or "Unknown"),
                    tonumber(statsData.longestWinStreak.count or 0))
            end
            
            -- Timing Statistics
            text = text .. "\n=== Timing ===\n"
            if statsData.avgRunTime and statsData.avgRunTime > 0 then
                local avgMins = math.floor(statsData.avgRunTime / 60)
                local avgSecs = statsData.avgRunTime % 60
                text = text .. string.format("Avg Duration: %d:%02d\n", avgMins, avgSecs)
            else
                text = text .. "Avg Duration: N/A\n"
            end
            
            if statsData.shortestRun and statsData.shortestRun > 0 then
                local shortMins = math.floor(statsData.shortestRun / 60)
                local shortSecs = statsData.shortestRun % 60
                text = text .. string.format("Shortest: %d:%02d\n", shortMins, shortSecs)
            end
            
            if statsData.longestRun and statsData.longestRun > 0 then
                local longMins = math.floor(statsData.longestRun / 60) 
                local longSecs = statsData.longestRun % 60
                text = text .. string.format("Longest: %d:%02d\n", longMins, longSecs)
            end
            
            -- Server Info
            text = text .. "\n=== Server Info ===\n"
            text = text .. string.format("Last Reset: %s\n", tostring(statsData.lastReset or "Never"))
            text = text .. string.format("Uptime: %s\n", tostring(statsData.serverUptime or "Unknown"))
            
            if total == 0 then
                text = text .. "\n=== Integration Required ===\n"
                text = text .. "Source: HL_ScoreboardNPC.cpp\n"
                text = text .. "Location: src\\server\\scripts\\DC\\\nHinterlandBG\\"
            end
        else
            text = text .. "No statistics available\n\nWaiting for server integration...\n\nRequired: HL_ScoreboardNPC.cpp data"
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
    -- Test data that matches for both HUD and Live tab
    local testData = {
        A = 350,
        H = 280,
        affix = 1, -- Bloodlust
        timeLeft = 930, -- 15:30 in seconds
        END = time() + 930
    }
    
    -- Update both HUD and live status with same data
    if HLBG.UpdateStatus then
        HLBG.UpdateStatus(testData)
    end
    HLBG.UpdateLiveStatus(testData)
    
    -- Test history with persistent data (24 entries instead of 12)
    local testHistory = {}
    local winners = {"Alliance", "Horde", "Draw"}
    for i = 1, 24 do
        table.insert(testHistory, {
            id = i,
            date = date("%Y-%m-%d %H:%M:%S", time() - (i * 1800)), -- Every 30 minutes instead of 1 hour
            winner = winners[math.random(1, 3)],
            affix = math.random(1, 5),
            duration = math.random(600, 1800)
        })
    end
    HLBG.UpdateHistory(testHistory)
    
    -- Comprehensive stats (should be replaced with HL_ScoreboardNPC.cpp data)
    HLBG.UpdateStats({
        totalRuns = 0,
        allianceWins = 0, 
        hordeWins = 0,
        draws = 0,
        manualResets = 0,
        currentWinStreak = {faction = "None", count = 0},
        longestWinStreak = {faction = "Alliance", count = 0},
        avgRunTime = 0,
        shortestRun = 0,
        longestRun = 0,
        mostPopularAffix = 0,
        lastReset = "Never",
        serverUptime = "0 days",
        lastUpdated = time(),
        note = "Waiting for HL_ScoreboardNPC.cpp integration"
    })
    
    -- Store test data persistently
    if not HinterlandAffixHUDDB.testData then
        HinterlandAffixHUDDB.testData = {}
    end
    HinterlandAffixHUDDB.testData.status = testData
    HinterlandAffixHUDDB.testData.history = testHistory
    HinterlandAffixHUDDB.testData.stats = {
        allianceWins = 45,
        hordeWins = 38,
        draws = 7,
        total = 90,
        avgDuration = 1350,
        lastUpdated = time()
    }
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
    
    -- Server integration handlers for future use
    handlers.UpdateScoreboardStats = function(player, data)
        if type(data) == "table" then
            HLBG.UpdateStats(data)
        end
    end
    
    handlers.UpdateSeasonInfo = function(player, seasonData)
        if type(seasonData) == "table" then
            HLBG.currentSeason = seasonData
            -- Update Live tab with season info
            HLBG.UpdateLiveStatus(HLBG.lastStatus or {})
        end
    end
    
    handlers.UpdateServerSettings = function(player, settings)
        if type(settings) == "table" then
            HLBG.serverSettings = settings
            -- Update Live tab with real settings
            HLBG.UpdateLiveStatus(HLBG.lastStatus or {})
        end
    end
    
    -- Handler for comprehensive server configuration
    handlers.ServerConfig = function(player, config)
        if type(config) == "table" then
            HLBG.serverSettings = config
            HLBG.UpdateLiveStatus(HLBG.lastStatus or {})
            if DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[HLBG]|r Server configuration updated")
            end
        end
    end
    
    -- Request fresh data when handlers are registered
    if AIO and AIO.Handle then
        -- Request server configuration
        AIO.Handle("HLBG", "RequestServerConfig")
        -- Request current season
        AIO.Handle("HLBG", "RequestSeasonInfo")  
        -- Request comprehensive stats
        AIO.Handle("HLBG", "RequestStats")
    end
    
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[HLBG AIO]|r Integration active - requesting server data")
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
        elseif command == "testhud" then
            -- Force show HUD with test data
            if HLBG.UpdateStatus then
                HLBG.UpdateStatus({A = 350, H = 280, affix = 1, timeLeft = 930, END = time() + 930})
            end
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[HLBG]|r HUD test triggered - check top of screen")
        elseif command == "request" then
            -- Request fresh server data
            if AIO and AIO.Handle then
                AIO.Handle("HLBG", "RequestServerConfig")
                AIO.Handle("HLBG", "RequestSeasonInfo")  
                AIO.Handle("HLBG", "RequestStats")
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[HLBG]|r Requested fresh server data")
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[HLBG]|r AIO not available")
            end
        elseif command == "help" then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[HLBG]|r Commands:")
            DEFAULT_CHAT_FRAME:AddMessage("  /hlbg - Open main UI")
            DEFAULT_CHAT_FRAME:AddMessage("  /hlbg live/history/stats/settings - Open specific tab")
            DEFAULT_CHAT_FRAME:AddMessage("  /hlbg testhud - Force HUD display with test data")
            DEFAULT_CHAT_FRAME:AddMessage("  /hlbg request - Request fresh data from server")
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

-- Create interactive settings UI
function HLBG.CreateSettingsUI(parent)
    if not parent then return end
    
    -- Clear any existing content
    for i = 1, parent:GetNumChildren() do
        local child = select(i, parent:GetChildren())
        if child then child:Hide() end
    end
    
    -- Initialize settings if not exists
    if not HLBG.settings then
        HLBG.settings = {
            hudEnabled = true,
            chatEnabled = not (HinterlandAffixHUDDB and HinterlandAffixHUDDB.disableChatUpdates),
            hudPosition = "Top Center",
            hudScale = 1.0
        }
    end
    
    local yOffset = -10
    
    -- Title
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", parent, "TOP", 0, yOffset)
    title:SetText("HLBG Settings")
    yOffset = yOffset - 30
    
    -- HUD Display checkbox
    local hudCheck = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
    hudCheck:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    hudCheck:SetChecked(HLBG.settings.hudEnabled)
    hudCheck:SetScript("OnClick", function(self)
        HLBG.settings.hudEnabled = self:GetChecked()
        if HLBG.UpdateHUD then
            if HLBG.settings.hudEnabled then
                HLBG.UpdateHUD()
            else
                if hudFrame then hudFrame:Hide() end
            end
        end
    end)
    
    local hudLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hudLabel:SetPoint("LEFT", hudCheck, "RIGHT", 5, 0)
    hudLabel:SetText("Enable HUD Display")
    yOffset = yOffset - 25
    
    -- Chat Updates checkbox
    local chatCheck = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
    chatCheck:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    chatCheck:SetChecked(HLBG.settings.chatEnabled)
    chatCheck:SetScript("OnClick", function(self)
        HLBG.settings.chatEnabled = self:GetChecked()
        if HinterlandAffixHUDDB then
            HinterlandAffixHUDDB.disableChatUpdates = not self:GetChecked()
        end
    end)
    
    local chatLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    chatLabel:SetPoint("LEFT", chatCheck, "RIGHT", 5, 0)
    chatLabel:SetText("Enable Chat Updates")
    yOffset = yOffset - 40
    
    -- Commands help button
    local helpButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    helpButton:SetSize(120, 25)
    helpButton:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    helpButton:SetText("Show Commands")
    helpButton:SetScript("OnClick", function()
        HLBG.ShowCommandHelp()
    end)
    
    -- Reset button
    local resetButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    resetButton:SetSize(100, 25)
    resetButton:SetPoint("LEFT", helpButton, "RIGHT", 10, 0)
    resetButton:SetText("Reset HUD")
    resetButton:SetScript("OnClick", function()
        if HLBG.ResetHUD then
            HLBG.ResetHUD()
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00HLBG HUD position reset to default.")
    end)
    yOffset = yOffset - 40
    
    -- Help text
    local helpText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    helpText:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    helpText:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, yOffset)
    helpText:SetJustifyH("LEFT")
    helpText:SetText("Use /hlbg or /hlbghud commands to control the addon. The HUD shows live battleground status at the top of your screen.")
end

-- Show command help window
function HLBG.ShowCommandHelp()
    if HLBG.helpFrame and HLBG.helpFrame:IsShown() then
        HLBG.helpFrame:Hide()
        return
    end
    
    -- Create help frame
    local frame = CreateFrame("Frame", "HLBG_HelpFrame", UIParent)
    frame:SetSize(400, 320)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    
    -- Background (3.3.5a compatible)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(frame)
    bg:SetTexture(0, 0, 0, 0.8)
    
    -- Border
    local border = CreateFrame("Frame", nil, frame, "DialogBorderTemplate")
    border:SetAllPoints()
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -10)
    title:SetText("HLBG Commands Help")
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
    
    -- Commands text
    local commandsText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    commandsText:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -40)
    commandsText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 20)
    commandsText:SetJustifyH("LEFT")
    commandsText:SetJustifyV("TOP")
    commandsText:SetText([[Available Commands:

=== Main UI Commands ===
/hlbg - Show main UI window
/hlbg ui - Show main UI window  
/hlbg live - Open Live tab (server config)
/hlbg history - Open History tab (24 recent battles)
/hlbg stats - Open Statistics tab (comprehensive)
/hlbg settings - Open Settings tab (interactive)
/hlbg testhud - Force HUD display with test data
/hlbg request - Request fresh server data

=== HUD Commands ===
/hlbghud - Toggle HUD display
/hlbghud show - Show HUD
/hlbghud hide - Hide HUD  
/hlbghud reset - Reset HUD position
/hlbghud test - Generate test data & show HUD

=== Features ===
• HUD shows live battle status (top center)
• Live tab shows server configuration from DB
• History shows 24 recent battles with affixes  
• Stats show comprehensive battle analytics
• Settings provide interactive controls

Server integration via HL_ScoreboardNPC.cpp
Click and drag this window to move it.]])
    
    HLBG.helpFrame = frame
    frame:Show()
end

-- Hook settings creation to tab switching
local originalShowTab = HLBG.ShowTab
function HLBG.ShowTab(tabIndex)
    if originalShowTab then
        originalShowTab(tabIndex)
    end
    
    -- Special handling for Settings tab
    if tabIndex == 4 then
        local frame = CreateMainUI()
        if frame and frame.contentFrames and frame.contentFrames[4] then
            -- Use 3.3.5a compatible timer instead of C_Timer
            local timerFrame = CreateFrame("Frame")
            local elapsed = 0
            timerFrame:SetScript("OnUpdate", function(self, dt)
                elapsed = elapsed + dt
                if elapsed >= 0.1 then
                    HLBG.CreateSettingsUI(frame.contentFrames[4])
                    self:SetScript("OnUpdate", nil)
                end
            end)
        end
    end
end

-- Load saved data on startup
function HLBG.LoadSavedData()
    if HinterlandAffixHUDDB and HinterlandAffixHUDDB.testData then
        local savedData = HinterlandAffixHUDDB.testData
        
        -- Restore status data
        if savedData.status then
            if HLBG.UpdateStatus then
                HLBG.UpdateStatus(savedData.status)
            end
            HLBG.UpdateLiveStatus(savedData.status)
        end
        
        -- Restore history data
        if savedData.history then
            HLBG.UpdateHistory(savedData.history)
        end
        
        -- Restore stats data
        if savedData.stats then
            HLBG.UpdateStats(savedData.stats)
        end
    else
        -- No saved data, initialize with defaults
        HLBG.GenerateTestData()
    end
end

-- Server integration handlers are now registered in InitializeAfterAIO()

-- Enhanced initialization
local function InitializeHLBGFull()
    InitializeHLBG()
    
    -- Create delayed initialization frame for saved data
    local initFrame = CreateFrame("Frame")
    local elapsed = 0
    initFrame:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        if elapsed >= 1.0 then -- Wait 1 second for SavedVariables to load
            HLBG.LoadSavedData()
            self:SetScript("OnUpdate", nil)
        end
    end)
end

-- Register commands and initialize
RegisterSlashCommands()
InitializeHLBGFull()

if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00EEFF[HLBG]|r UI client loaded - Use /hlbg to open")
end