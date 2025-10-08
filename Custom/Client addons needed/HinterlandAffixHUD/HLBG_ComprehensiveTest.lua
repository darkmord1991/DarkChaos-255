-- HLBG Comprehensive Test Suite
local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

-- Test command to verify all systems work
SLASH_HLBGCOMPTEST1 = '/hlbgcomptest'
SlashCmdList['HLBGCOMPTEST'] = function(msg)
    DEFAULT_CHAT_FRAME:AddMessage('|cFF00FFFF=== HLBG COMPREHENSIVE TEST STARTING ===|r')
    
    -- Test 1: HUD System Test
    DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99Test 1:|r Testing HUD system...')
    
    local hudExists = HLBG.UI and HLBG.UI.ModernHUD
    local hudVisible = hudExists and HLBG.UI.ModernHUD:IsVisible()
    local hudElements = hudExists and HLBG.UI.ModernHUD.allianceText and HLBG.UI.ModernHUD.hordeText and HLBG.UI.ModernHUD.timerText
    
    DEFAULT_CHAT_FRAME:AddMessage(string.format('  HUD exists: %s, Visible: %s, Elements: %s', 
        hudExists and 'YES' or 'NO',
        hudVisible and 'YES' or 'NO', 
        hudElements and 'YES' or 'NO'))
    
    -- Test 2: Manual HUD Data Injection
    DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99Test 2:|r Testing manual HUD data injection...')
    
    if hudExists and HLBG.UI.ModernHUD.UpdateWithData then
        local testData = {
            allianceResources = 450,
            hordeResources = 450, 
            timeLeft = 2243, -- 37:23
            phase = "IN_PROGRESS",
            affixName = "Test Affix"
        }
        
        pcall(function()
            HLBG.UI.ModernHUD.UpdateWithData(testData)
            DEFAULT_CHAT_FRAME:AddMessage('  Manual data injection: SUCCESS')
        end)
    else
        DEFAULT_CHAT_FRAME:AddMessage('  Manual data injection: FAILED - missing HUD or function')
    end
    
    -- Test 3: Stats JSON Processing
    DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99Test 3:|r Testing stats JSON processing...')
    
    local testStatsJSON = '{"counts":{"Alliance":0,"Horde":0},"draws":45,"avgDuration":1282,"season":1,"seasonName":"Season 1: Chaos Reborn","reasons":{"depletion":0,"tiebreaker":0,"draw":0,"manual":45}}'
    
    -- Simulate receiving stats JSON
    pcall(function()
        local decoded = {}
        
        -- Simple manual parsing for test
        decoded.draws = tonumber(testStatsJSON:match('"draws":(%d+)')) or 0
        decoded.avgDuration = tonumber(testStatsJSON:match('"avgDuration":(%d+)')) or 0
        decoded.season = tonumber(testStatsJSON:match('"season":(%d+)')) or 1
        decoded.seasonName = testStatsJSON:match('"seasonName":"([^"]+)"') or "Season 1"
        
        local allianceCount = tonumber(testStatsJSON:match('"Alliance":(%d+)')) or 0
        local hordeCount = tonumber(testStatsJSON:match('"Horde":(%d+)')) or 0
        decoded.counts = { Alliance = allianceCount, Horde = hordeCount }
        decoded.totalBattles = allianceCount + hordeCount + decoded.draws
        
        DEFAULT_CHAT_FRAME:AddMessage(string.format('  Parsed: Alliance=%d, Horde=%d, Draws=%d, Total=%d', 
            allianceCount, hordeCount, decoded.draws, decoded.totalBattles))
        
        if type(HLBG.Stats) == 'function' then
            HLBG.Stats(decoded)
            DEFAULT_CHAT_FRAME:AddMessage('  Stats function call: SUCCESS')
        else
            DEFAULT_CHAT_FRAME:AddMessage('  Stats function call: FAILED - function not found')
        end
    end)
    
    -- Test 4: History TSV Processing
    DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99Test 4:|r Testing history TSV processing...')
    
    local testTSV = "46\t1\tSeason 1: Chaos Reborn\t2025-10-07 20:05:44\tDraw\t0\tmanual|45\t1\tSeason 1: Chaos Reborn\t2025-10-07 18:30:38\tDraw\t0\tmanual|44\t1\tSeason 1: Chaos Reborn\t2025-10-07 18:30:38\tDraw\t0\tmanual"
    
    pcall(function()
        if type(HLBG.HistoryStr) == 'function' then
            local result = HLBG.HistoryStr(testTSV, 1, 15, 46, 'id', 'DESC')
            DEFAULT_CHAT_FRAME:AddMessage('  History TSV processing: SUCCESS')
            
            if HLBG.UI and HLBG.UI.History and HLBG.UI.History.lastRows then
                DEFAULT_CHAT_FRAME:AddMessage(string.format('  Stored rows: %d', #HLBG.UI.History.lastRows))
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage('  History TSV processing: FAILED - HistoryStr not found')
        end
    end)
    
    -- Test 5: AIO System Check
    DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99Test 5:|r Testing AIO system...')
    
    local aioExists = _G.AIO and type(_G.AIO.Handle) == 'function'
    local handlersRegistered = HLBG._aioHandlersRegistered or false
    
    DEFAULT_CHAT_FRAME:AddMessage(string.format('  AIO available: %s, Handlers registered: %s',
        aioExists and 'YES' or 'NO',
        handlersRegistered and 'YES' or 'NO'))
    
    if aioExists then
        pcall(function()
            _G.AIO.Handle("HLBG", "TestPing", "test")
            DEFAULT_CHAT_FRAME:AddMessage('  AIO test call: SUCCESS')
        end)
    end
    
    -- Test 6: UI Framework Check
    DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99Test 6:|r Testing UI framework...')
    
    local mainFrameExists = HLBG.UI and HLBG.UI.Frame
    local tabsExist = HLBG.UI and HLBG.UI.Tabs
    local historyUIExists = HLBG.UI and HLBG.UI.History
    local statsUIExists = HLBG.UI and HLBG.UI.Stats
    
    DEFAULT_CHAT_FRAME:AddMessage(string.format('  Main frame: %s, Tabs: %s, History UI: %s, Stats UI: %s',
        mainFrameExists and 'YES' or 'NO',
        tabsExist and 'YES' or 'NO',
        historyUIExists and 'YES' or 'NO',
        statsUIExists and 'YES' or 'NO'))
    
    -- Test 7: Data Storage Check
    DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99Test 7:|r Checking stored data...')
    
    local storedHistoryRows = historyUIExists and HLBG.UI.History.lastRows and #HLBG.UI.History.lastRows or 0
    local storedStatsData = HLBG.cachedStats and 'YES' or 'NO'
    local lastStatusData = HLBG._lastStatus and 'YES' or 'NO'
    local resGlobalData = _G.RES and (_G.RES.A or _G.RES.H) and 'YES' or 'NO'
    
    DEFAULT_CHAT_FRAME:AddMessage(string.format('  History rows: %d, Cached stats: %s, Last status: %s, RES global: %s',
        storedHistoryRows, storedStatsData, lastStatusData, resGlobalData))
    
    -- Test 8: Worldstate Reading
    DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99Test 8:|r Testing worldstate reading...')
    
    local worldstateData = {}
    if type(GetNumWorldStateUI) == 'function' and type(GetWorldStateUIInfo) == 'function' then
        local numWS = GetNumWorldStateUI()
        local foundRelevant = 0
        
        for i = 1, numWS do
            local wsType, state, text = GetWorldStateUIInfo(i)
            if wsType == 3680 or wsType == 3490 or wsType == 3781 then
                worldstateData[wsType] = text
                foundRelevant = foundRelevant + 1
            end
        end
        
        DEFAULT_CHAT_FRAME:AddMessage(string.format('  Total worldstates: %d, Relevant found: %d', numWS, foundRelevant))
        if foundRelevant > 0 then
            DEFAULT_CHAT_FRAME:AddMessage(string.format('  Alliance(3680): %s, Horde(3490): %s, Timer(3781): %s',
                worldstateData[3680] or 'nil', 
                worldstateData[3490] or 'nil', 
                worldstateData[3781] or 'nil'))
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage('  Worldstate functions not available')
    end
    
    -- Summary
    DEFAULT_CHAT_FRAME:AddMessage('|cFF00FFFF=== TEST COMPLETE ===|r')
    DEFAULT_CHAT_FRAME:AddMessage('|cFFFFFF00Next steps:|r')
    DEFAULT_CHAT_FRAME:AddMessage('  1. Try /hlbgtestdata to inject test data into HUD')  
    DEFAULT_CHAT_FRAME:AddMessage('  2. Use /hlbgstatsui and /hlbghistui to get fresh server data')
    DEFAULT_CHAT_FRAME:AddMessage('  3. Check /hlbgstatus for current server state')
    DEFAULT_CHAT_FRAME:AddMessage('  4. Use /hlbgws to check worldstate values')
end

-- Quick data verification command
SLASH_HLBGQUICKTEST1 = '/hlbgquicktest'
SlashCmdList['HLBGQUICKTEST'] = function(msg)
    DEFAULT_CHAT_FRAME:AddMessage('|cFF00FFFF=== HLBG QUICK DATA TEST ===|r')
    
    -- Check if HUD shows data correctly
    if HLBG.UI and HLBG.UI.ModernHUD then
        local allianceText = HLBG.UI.ModernHUD.allianceText and HLBG.UI.ModernHUD.allianceText:GetText() or 'nil'
        local hordeText = HLBG.UI.ModernHUD.hordeText and HLBG.UI.ModernHUD.hordeText:GetText() or 'nil'  
        local timerText = HLBG.UI.ModernHUD.timerText and HLBG.UI.ModernHUD.timerText:GetText() or 'nil'
        
        DEFAULT_CHAT_FRAME:AddMessage('Current HUD display:')
        DEFAULT_CHAT_FRAME:AddMessage('  ' .. allianceText)
        DEFAULT_CHAT_FRAME:AddMessage('  ' .. hordeText) 
        DEFAULT_CHAT_FRAME:AddMessage('  ' .. timerText)
    else
        DEFAULT_CHAT_FRAME:AddMessage('HUD not found or not available')
    end
    
    -- Check stored data
    if HLBG.UI and HLBG.UI.History and HLBG.UI.History.lastRows then
        DEFAULT_CHAT_FRAME:AddMessage('History rows stored: ' .. #HLBG.UI.History.lastRows)
    else
        DEFAULT_CHAT_FRAME:AddMessage('No history data stored')
    end
    
    -- Check RES global
    if _G.RES then
        DEFAULT_CHAT_FRAME:AddMessage('RES global: A=' .. (_G.RES.A or 'nil') .. ', H=' .. (_G.RES.H or 'nil'))
    else
        DEFAULT_CHAT_FRAME:AddMessage('RES global not found')
    end
end

-- Force show history window and display data
SLASH_HLBGSHOWHISTORY1 = '/hlbgshowhistory'
SlashCmdList['HLBGSHOWHISTORY'] = function(msg)
    DEFAULT_CHAT_FRAME:AddMessage('|cFF00FFFF=== FORCE SHOW HISTORY WINDOW ===|r')
    
    -- Step 1: Show main UI frame
    if HLBG.UI and HLBG.UI.Frame then
        HLBG.UI.Frame:Show()
        HLBG.UI.Frame:SetFrameStrata("HIGH")
        HLBG.UI.Frame:SetFrameLevel(100)
        DEFAULT_CHAT_FRAME:AddMessage('Main UI frame shown')
    else
        DEFAULT_CHAT_FRAME:AddMessage('|cFFFF5555ERROR:|r Main UI frame not found')
        return
    end
    
    -- Step 2: Click History tab (tab 1)
    if HLBG.UI.Tabs and HLBG.UI.Tabs[1] then
        if HLBG.UI.Tabs[1]:GetScript("OnClick") then
            HLBG.UI.Tabs[1]:GetScript("OnClick")(HLBG.UI.Tabs[1])
            DEFAULT_CHAT_FRAME:AddMessage('History tab clicked')
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage('|cFFFF5555ERROR:|r History tab not found')
    end
    
    -- Step 3: Force update display with stored data
    if HLBG.UI.History and HLBG.UI.History.lastRows then
        DEFAULT_CHAT_FRAME:AddMessage('Found ' .. #HLBG.UI.History.lastRows .. ' stored history rows')
        
        if type(HLBG.UpdateHistoryDisplay) == 'function' then
            pcall(function()
                HLBG.UpdateHistoryDisplay()
                DEFAULT_CHAT_FRAME:AddMessage('UpdateHistoryDisplay called successfully')
            end)
        else
            DEFAULT_CHAT_FRAME:AddMessage('|cFFFF5555ERROR:|r UpdateHistoryDisplay function not found')
        end
        
        -- Also try calling History function directly
        if type(HLBG.History) == 'function' then
            pcall(function()
                HLBG.History(HLBG.UI.History.lastRows, 1, 15, #HLBG.UI.History.lastRows, 'id', 'DESC')
                DEFAULT_CHAT_FRAME:AddMessage('HLBG.History called directly with stored data')
            end)
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage('|cFFFF5555ERROR:|r No stored history data found')
        
        -- Create test history data
        HLBG.UI.History = HLBG.UI.History or {}
        HLBG.UI.History.lastRows = {
            {id = "46", season = 1, seasonName = "Season 1: Chaos Reborn", ts = "2025-10-07 20:05:44", winner = "Draw", affix = "0", reason = "manual"},
            {id = "45", season = 1, seasonName = "Season 1: Chaos Reborn", ts = "2025-10-07 18:30:38", winner = "Draw", affix = "0", reason = "manual"},  
            {id = "44", season = 1, seasonName = "Season 1: Chaos Reborn", ts = "2025-10-07 18:30:38", winner = "Draw", affix = "0", reason = "manual"},
            {id = "43", season = 1, seasonName = "Season 1: Chaos Reborn", ts = "2025-10-07 09:26:29", winner = "Draw", affix = "0", reason = "manual"}
        }
        DEFAULT_CHAT_FRAME:AddMessage('Created test history data with 4 rows')
        
        if type(HLBG.History) == 'function' then
            pcall(function()
                HLBG.History(HLBG.UI.History.lastRows, 1, 15, 4, 'id', 'DESC')
                DEFAULT_CHAT_FRAME:AddMessage('HLBG.History called with test data')
            end)
        end
    end
    
    DEFAULT_CHAT_FRAME:AddMessage('History window force-show complete! Check the addon UI.')
end

_G.HLBG = HLBG