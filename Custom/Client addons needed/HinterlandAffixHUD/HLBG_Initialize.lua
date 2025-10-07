-- HLBG_Initialize.lua - Comprehensive initialization and setup

local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

-- Tab names for easy reference  
HLBG.TabNames = {"History", "Stats", "Info", "Queue", "Settings"}

-- Initialization state tracking
HLBG.InitState = {
    uiLoaded = false,
    modernStylingApplied = false,
    testDataLoaded = false,
    eventsRegistered = false,
    historyDataLoaded = false
}

-- Data cache for one-time loading
HLBG.DataCache = {
    historyData = nil,
    statsData = nil,
    lastHistoryLoad = 0
}

-- Comprehensive initialization function
function HLBG.Initialize()
    print("|cFF33FF99HLBG:|r Starting comprehensive initialization...")
    
    -- Step 1: Ensure UI is created
    if not HLBG.UI or not HLBG.UI.Frame then
        print("|cFF888888HLBG:|r UI not ready yet, will retry...")
        return false
    end
    
    -- Step 2: Apply modern styling
    if not HLBG.InitState.modernStylingApplied and HLBG.ApplyModernStyling then
        HLBG.ApplyModernStyling()
        HLBG.InitState.modernStylingApplied = true
        print("|cFF33FF99HLBG:|r Modern styling applied")
    end
    
    -- Step 3: Load test data if needed
    if not HLBG.InitState.testDataLoaded then
        HLBG.LoadTestData()
        HLBG.InitState.testDataLoaded = true
        print("|cFF33FF99HLBG:|r Test data loaded")
    end
    
    -- Step 3.5: Load real data once
    if not HLBG.InitState.historyDataLoaded then
        HLBG.LoadInitialData()
        HLBG.InitState.historyDataLoaded = true
        print("|cFF33FF99HLBG:|r Initial data loaded")
    end
    
    -- Step 4: Setup enhanced tab switching
    HLBG.SetupEnhancedTabs()
    
    -- Step 5: Register helpful commands
    HLBG.RegisterCommands()
    
    HLBG.InitState.uiLoaded = true
    print("|cFF33FF99HLBG:|r Initialization complete!")
    
    return true
end

-- One-time data loading function
function HLBG.LoadInitialData()
    local now = GetTime()
    HLBG.DataCache.lastHistoryLoad = now
    
    print("|cFF33FF99HLBG:|r Loading initial history and stats data...")
    
    -- Load history data once
    local season = (HLBG and HLBG._getSeason and HLBG._getSeason()) or 0
    
    -- Single AIO call for history
    if _G.AIO and _G.AIO.Handle then
        local ok, err = pcall(_G.AIO.Handle, "HLBG", "Request", "HISTORY", 1, 15, season, "id", "DESC")
        if not ok then
            print("|cFFFF6600HLBG:|r AIO history request failed:", err or "unknown error")
        end
    end
    
    -- Single AIO call for stats  
    if _G.AIO and _G.AIO.Handle then
        local ok, err = pcall(_G.AIO.Handle, "HLBG", "Request", "STATS", season)
        if not ok then
            print("|cFFFF6600HLBG:|r AIO stats request failed:", err or "unknown error")
        end
    end
    
    -- Fallback dot commands
    local sendDot = (HLBG and HLBG.SendServerDot) or _G.HLBG_SendServerDot
    if type(sendDot) == 'function' then
        sendDot(string.format(".hlbg historyui 1 15 %d id DESC", season))
        sendDot(string.format(".hlbg stats %d", season))
    end
    
    print("|cFF33FF99HLBG:|r Initial data requests sent")
end

-- Function to check if we need to reload data (only on explicit reload)
function HLBG.ShouldReloadData()
    -- Only reload if explicitly requested or if no data cached
    return not HLBG.DataCache.historyData or HLBG.InitState.historyDataLoaded == false
end

-- Function to cache received data
function HLBG.CacheData(dataType, data)
    if not HLBG.DataCache then
        HLBG.DataCache = {}
    end
    
    if dataType == "history" then
        HLBG.DataCache.historyData = data
        print("|cFF33FF99HLBG:|r History data cached (" .. (data and #data or 0) .. " entries)")
    elseif dataType == "stats" then
        HLBG.DataCache.statsData = data
        print("|cFF33FF99HLBG:|r Stats data cached")
    end
end

-- Enhanced tab setup
function HLBG.SetupEnhancedTabs()
    if not HLBG.UI or not HLBG.UI.Tabs then return end
    
    -- Override the ShowTab function with enhanced version
    HLBG.ShowTab = function(index)
        if HLBG.SafeShowTab then
            return HLBG.SafeShowTab(index)
        end
        
        -- Fallback implementation
        for i, name in ipairs(HLBG.TabNames) do
            if HLBG.UI[name] then
                if i == index then
                    HLBG.UI[name]:Show()
                else
                    HLBG.UI[name]:Hide()
                end
            end
        end
        
        HLBG.UI.activeTab = index
        if HLBG.UpdateModernTabStyling then
            HLBG.UpdateModernTabStyling()
        end
        
        return true
    end
    
    -- Ensure first tab is shown by default
    HLBG.ShowTab(1)
end

-- Register helpful slash commands
function HLBG.RegisterCommands()
    -- Main command handler
    SLASH_HLBGMAIN1 = "/hlbg"
    SlashCmdList["HLBGMAIN"] = function(msg)
        local cmd = string.lower(msg or "")
        
        if cmd == "show" or cmd == "" then
            if HLBG.UI and HLBG.UI.Frame then
                HLBG.UI.Frame:Show()
                print("|cFF33FF99HLBG:|r Main window opened")
            else
                print("|cFFFF0000HLBG:|r UI not available")
            end
            
        elseif cmd == "hide" then
            if HLBG.UI and HLBG.UI.Frame then
                HLBG.UI.Frame:Hide()
                print("|cFF33FF99HLBG:|r Main window closed")
            end
            
        elseif cmd == "reload" or cmd == "reset" then
            print("|cFF33FF99HLBG:|r Reloading UI...")
            HLBG.InitState.modernStylingApplied = false
            HLBG.Initialize()
            
        elseif cmd == "testdata" or cmd == "test" then
            HLBG.LoadTestData()
            print("|cFF33FF99HLBG:|r Test data reloaded")
            
        elseif cmd == "style" or cmd == "modern" then
            if HLBG.ApplyModernStyling then
                HLBG.ApplyModernStyling()
                print("|cFF33FF99HLBG:|r Modern styling reapplied")
            end
            
        elseif cmd == "stats" then
            if HLBG.RefreshStatsCards then
                HLBG.RefreshStatsCards()
            end
            print("|cFF33FF99HLBG:|r Stats refreshed")
            
        elseif cmd == "data" or cmd == "refresh" then
            -- Force reload data from server
            HLBG.InitState.historyDataLoaded = false
            HLBG.DataCache.historyData = nil
            HLBG.DataCache.statsData = nil
            HLBG.LoadInitialData()
            print("|cFF33FF99HLBG:|r Data reloaded from server")
            
        elseif cmd == "help" then
            print("|cFF33FF99HLBG Commands:|r")
            print("  /hlbg show - Open main window")
            print("  /hlbg hide - Close main window") 
            print("  /hlbg reload - Reload UI components")
            print("  /hlbg testdata - Reload test data")
            print("  /hlbg style - Reapply modern styling")
            print("  /hlbg stats - Refresh statistics")
            print("  /hlbg data - Force reload data from server")
            print("  /hlbgws - Show worldstate debug info")
            print("  /hlbgdiag - Diagnose empty tabs")
            
        else
            print("|cFFFF0000HLBG:|r Unknown command: " .. cmd .. ". Use '/hlbg help' for commands.")
        end
    end
    
    -- Quick show command
    SLASH_HLBGSHOW1 = "/hlbgshow"
    SlashCmdList["HLBGSHOW"] = function()
        if HLBG.UI and HLBG.UI.Frame then
            HLBG.UI.Frame:Show()
        end
    end
end

-- Auto-initialization with retry logic
local function AttemptInitialization()
    if HLBG.InitState.uiLoaded then
        return -- Already initialized
    end
    
    local success = HLBG.Initialize()
    if not success then
        -- Retry in 2 seconds
        C_Timer.After(2, AttemptInitialization)
    end
end

-- Multiple initialization triggers for robustness
local initFrame = CreateFrame("Frame")

-- Try on addon loaded
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "HinterlandAffixHUD" then
        C_Timer.After(0.5, AttemptInitialization)
    end
end)

-- Also try when player enters world
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1, AttemptInitialization)
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end)

-- Immediate attempt if UI already exists
if HLBG.UI and HLBG.UI.Frame then
    AttemptInitialization()
end

print("|cFF33FF99HLBG:|r Initialization system loaded")