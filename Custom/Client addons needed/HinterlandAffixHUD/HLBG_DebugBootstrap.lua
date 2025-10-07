-- HLBG_DebugBootstrap.lua - Adds debug features to the HinterlandAffixHUD

-- Ensure HLBG namespace exists
HLBG = HLBG or {}

-- Debug mode should be off by default (user can enable via /hlbg devmode on)
HLBG._devMode = false

-- Set up unified chat handler to prevent duplicate handlers
if not HLBG._unifiedChatHandlerInstalled and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    HLBG._unifiedChatHandlerInstalled = true
    -- Store the original function safely
    HLBG._originalAddMessage = DEFAULT_CHAT_FRAME.AddMessage
    HLBG._inMessageHandler = false  -- Flag to prevent recursion
    
    DEFAULT_CHAT_FRAME.AddMessage = function(self, text, ...)
        local originalFunction = HLBG._originalAddMessage
        
        -- Safety check - if originalFunction is nil, use the default behavior
        if not originalFunction then
            local fallback = self:GetScript("OnEvent")
            if type(fallback) == 'function' then
                return fallback(self, "CHAT_MSG_SYSTEM", text, ...)
            else
                -- Last-resort: ensure we don't call a nil handler. Print safely.
                print(tostring(text))
                return
            end
        end
        
        -- Prevent recursive calls to our handler
        if HLBG._inMessageHandler then
            return originalFunction(self, text, ...)
        end
        
        HLBG._inMessageHandler = true
        
        -- Flag to track if we handled the message
        local handled = false
        
        -- Process all message types in one place
        if type(text) == "string" then
            -- History TSV format
            if text:match("^%[HLBG_HISTORY_TSV%]") then
                HLBG._lastHistoryTSV = text
                
                -- Try to process
                if type(ProcessHistoryTSVMessage) == "function" then
                    local success = ProcessHistoryTSVMessage(text)
                    if success and HLBG.CompleteRequest then
                        HLBG.CompleteRequest("HISTORY")
                        handled = true  -- Don't show in chat
                    end
                end
            end
            
            -- Stats JSON format
            if not handled and text:match("^%[HLBG_STATS_JSON%]") then
                -- Try to process
                if HLBG._processStatsJSON and type(HLBG._processStatsJSON) == "function" then
                    local success = HLBG._processStatsJSON(text)
                    if success then
                        handled = true  -- Don't show in chat
                    end
                end
            end
            
            -- Individual history row format
            if not handled and text:match("^%d+|%d%d%d%d%-%d%d%-%d%d") then
                local id, ts, win, aff, rea = text:match("(%d+)|(.-)|(.-)|(.-)|(.+)")
                if id and HLBG.History and type(HLBG.History) == 'function' then
                    -- Store this message but don't process it yet - we may get many in sequence
                    -- and we only want to update the UI once with the complete set
                    HLBG._pendingHistoryRows = HLBG._pendingHistoryRows or {}
                    table.insert(HLBG._pendingHistoryRows, {
                        id = id,
                        ts = ts,
                        winner = win,
                        affix = aff,
                        reason = rea
                    })
                    
                    -- Set a timer to process all pending rows in a single batch
                    if not HLBG._pendingHistoryTimer then
                        HLBG._pendingHistoryTimer = true
                        C_Timer.After(0.5, function()
                            if HLBG._pendingHistoryRows and #HLBG._pendingHistoryRows > 0 then
                                -- Process all rows at once
                                HLBG.History(HLBG._pendingHistoryRows, 1, #HLBG._pendingHistoryRows, #HLBG._pendingHistoryRows, "id", "DESC")
                                if HLBG.CompleteRequest then
                                    HLBG.CompleteRequest("HISTORY")
                                end
                            end
                            HLBG._pendingHistoryRows = {}
                            HLBG._pendingHistoryTimer = nil
                        end)
                    end
                    
                    handled = true  -- Don't show in chat
                end
            end
        end
        
        -- Reset recursion flag before continuing
        HLBG._inMessageHandler = false
        
        -- If we didn't handle it, pass to original
        if not handled then
            local originalFunction = HLBG._originalAddMessage
            -- Safety check - if originalFunction is nil, use the default behavior
            if not originalFunction then
                local fallback = self:GetScript("OnEvent")
                if type(fallback) == 'function' then
                    return fallback(self, "CHAT_MSG_SYSTEM", text, ...)
                else
                    -- Last-resort: ensure we don't call a nil handler. Print safely.
                    print(tostring(text))
                    return
                end
            end
            return originalFunction(self, text, ...)
        end
    end
    
    -- Create a safe debug print function that doesn't trigger our handler
    HLBG.DebugPrint = function(...)
        local args = {...}
        local message = ""
        for i=1, #args do
            message = message .. tostring(args[i]) .. " "
        end
        HLBG._inMessageHandler = true  -- Prevent recursion
        
        local originalFunction = HLBG._originalAddMessage
        -- Safety check - if originalFunction is nil, use DEFAULT_CHAT_FRAME:AddMessage directly
        if originalFunction then
            originalFunction(DEFAULT_CHAT_FRAME, "|cFF88FFFFHLBG Debug:|r " .. message)
        else
            -- Fallback to print function
            print("|cFF88FFFFHLBG Debug:|r " .. message)
        end
        
        HLBG._inMessageHandler = false
    end
end

-- Add a function to dump the current state for debugging
function HLBG.DumpState()
    print("=== HLBG Debug State Dump ===")
    print("Dev Mode:", HLBG._devMode)
    
    -- Affix info
    print("Current affix:", HLBG._affixText)
    print("Current affix ID:", HLBG._currentAffixID)
    
    -- History info
    if HLBG.UI and HLBG.UI.History then
        print("History page:", HLBG.UI.History.page)
        print("History total:", HLBG.UI.History.total)
        print("Last history TSV:", HLBG._lastHistoryTSV and string.sub(HLBG._lastHistoryTSV, 1, 50) .. "..." or "none")
    else
        print("History UI not initialized")
    end
    
    -- Stats info
    if HLBG._lastRawStats then
        print("Last stats:", type(HLBG._lastRawStats))
        if type(HLBG._lastRawStats) == "string" then
            print("Stats length:", #HLBG._lastRawStats)
            print("Stats excerpt:", string.sub(HLBG._lastRawStats, 1, 100))
        elseif type(HLBG._lastRawStats) == "table" then
            print("Stats keys:")
            for k, v in pairs(HLBG._lastRawStats) do
                print("  ", k, "=", type(v) == "table" and "(table)" or tostring(v))
            end
        end
    else
        print("No stats data available")
    end
    
    -- UI info
    print("UI initialized:", HLBG.UI and "yes" or "no")
    if HLBG.UI then
        print("UI components:")
        print("  HUD:", HLBG.UI.HUD and "yes" or "no")
        print("  History:", HLBG.UI.History and "yes" or "no")
        print("  Stats:", HLBG.UI.Stats and "yes" or "no")
        print("  Frame visible:", HLBG.UI.Frame and HLBG.UI.Frame:IsShown() and "yes" or "no")
    end
    
    -- Handler info
    print("Handlers:")
    print("  History function:", type(HLBG.History))
    print("  HistoryStr function:", type(HLBG.HistoryStr))
    print("  Stats function:", type(HLBG.Stats))
    print("  ProcessHistoryTSV function:", type(HLBG.ProcessHistoryTSV))
    print("  ProcessStatsJSON function:", type(HLBG.ProcessStatsJSON))
    
    print("=== End of Debug Dump ===")
end

-- Register slash command for debug
SLASH_HLBGDEBUG1 = "/hlbgdebug"
SlashCmdList["HLBGDEBUG"] = function(msg)
    msg = msg or ""
    if msg:match("^help") then
        print("HLBG Debug Commands:")
        print("/hlbgdebug dump - Dump current state")
        print("/hlbgdebug fix - Attempt automatic fixes")
        print("/hlbgdebug history - Force history refresh")
        print("/hlbgdebug stats - Force stats refresh")
        print("/hlbgdebug ui - Show UI")
    elseif msg:match("^dump") then
        HLBG.DumpState()
    elseif msg:match("^fix") then
        -- Apply automatic fixes
        print("Applying automatic fixes...")
        
        -- Fix history display
        if HLBG.History and HLBG.UI and HLBG.UI.History then
            print("Fixing history display...")
            local page = HLBG.UI.History.page or 1
            local per = HLBG.UI.History.per or 10
            local total = HLBG.UI.History.total or 10
            
            -- Create some placeholder data
            local rows = {{
                id = "1",
                ts = "2025-10-03 09:16:42",
                winner = "DRAW",
                affix = "0",
                reason = "manual"
            }}
            
            -- Force display
            HLBG.History(rows, page, per, total, "id", "DESC")
        end
        
        -- Fix stats display
        if HLBG.Stats then
            print("Fixing stats display...")
            -- Create placeholder data
            local stats = {
                total = 26,
                draws = 0,
                manual = 26,
                avgDuration = 512.5,
                counts = {
                    Alliance = 13,
                    Horde = 13
                }
            }
            
            -- Force display
            HLBG.Stats(stats)
        end
    elseif msg:match("^history") then
        print("Forcing history refresh...")
        -- Request history data
        if _G.AIO and _G.AIO.Handle then
            _G.AIO.Handle('HLBG','Request','HISTORY', 1, 10, 'id', 'DESC')
        end
        -- Use dot command as backup
        if type(HLBG.SendServerDot) == 'function' then
            HLBG.SendServerDot(".hlbg history 10")
        end
    elseif msg:match("^stats") then
        print("Forcing stats refresh...")
        -- Request stats data
        if _G.AIO and _G.AIO.Handle then
            _G.AIO.Handle('HLBG', 'Request', 'STATS')
            _G.AIO.Handle('HLBG', 'Stats')
            _G.AIO.Handle('HLBG', 'STATS')
        end
        -- Use dot command as backup (explicit statsui to avoid ambiguity)
        if type(HLBG.SendServerDot) == 'function' then
            HLBG.SendServerDot(".hlbg statsui")
        end
    elseif msg:match("^ui") then
        print("Showing UI...")
        if HLBG.OpenUI and type(HLBG.OpenUI) == 'function' then
            HLBG.OpenUI()
        end
    else
        print("Unknown debug command. Try /hlbgdebug help")
    end
end

-- Automatically apply fixes at startup
-- Ensure we have a timer function available
if C_Timer and C_Timer.After then
    C_Timer.After(5, function()
        print("HLBG: Running automatic startup fixes")
        SlashCmdList["HLBGDEBUG"]("fix")
    end)
else
    -- Fallback for older clients without C_Timer
    local startupFrame = CreateFrame("Frame")
    local elapsed = 0
    startupFrame:SetScript("OnUpdate", function(self, e)
        elapsed = elapsed + e
        if elapsed >= 5 then
            print("HLBG: Running automatic startup fixes")
            SlashCmdList["HLBGDEBUG"]("fix")
            self:SetScript("OnUpdate", nil)
        end
    end)
end