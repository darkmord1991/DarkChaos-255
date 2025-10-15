-- HLBG_TimerCompat.lua - Compatibility layer for C_Timer
-- *** CRITICAL: THIS FILE MUST LOAD FIRST (after HLBG_LoadDebug.lua) ***
-- This file provides compatibility functions for WoW 3.3.5a (Wrath of the Lich King)
-- It implements the C_Timer API that is used throughout the addon
-- The addon WILL NOT WORK without this file loading first
-- Verify that this file is the SECOND script listed in the TOC file

-- Record this file loading in diagnostics
if _G.HLBG_RecordFileLoad then
    _G.HLBG_RecordFileLoad("HLBG_TimerCompat.lua")
end

-- Check if C_Timer already exists (newer WoW versions)
if not C_Timer then
    -- Create our own implementation for older WoW versions
    C_Timer = {}
    
    -- Frame to handle our timers
    local timerFrame = CreateFrame("Frame")
    local timers = {}
    
    -- After function implementation
    function C_Timer.After(seconds, callback)
        if type(seconds) ~= "number" or type(callback) ~= "function" then
            return
        end
        
        -- Insert the timer into our tracking table
        table.insert(timers, {
            expires = GetTime() + seconds,
            callback = callback
        })
        
        -- Make sure our frame is running
        timerFrame:Show()
    end
    
    -- NewTimer function (creates a cancellable timer)
    function C_Timer.NewTimer(seconds, callback)
        if type(seconds) ~= "number" or type(callback) ~= "function" then
            return
        end
        
        local timer = {
            expires = GetTime() + seconds,
            callback = callback,
            cancelled = false
        }
        
        -- Insert the timer into our tracking table
        table.insert(timers, timer)
        
        -- Make sure our frame is running
        timerFrame:Show()
        
        -- Return a handle with a Cancel method
        return {
            Cancel = function()
                timer.cancelled = true
            end
        }
    end
    
    -- NewTicker function (creates a repeating timer)
    function C_Timer.NewTicker(seconds, callback, iterations)
        if type(seconds) ~= "number" or type(callback) ~= "function" then
            return
        end
        
        iterations = iterations or math.huge
        
        local ticker = {
            expires = GetTime() + seconds,
            callback = callback,
            iterations = iterations,
            cancelled = false,
            period = seconds
        }
        
        -- Insert the ticker into our tracking table
        table.insert(timers, ticker)
        
        -- Make sure our frame is running
        timerFrame:Show()
        
        -- Return a handle with a Cancel method
        return {
            Cancel = function()
                ticker.cancelled = true
            end
        }
    end
    
    -- Process the timers on each frame update
    timerFrame:SetScript("OnUpdate", function(self, elapsed)
        local now = GetTime()
        local i = 1
        
        -- Process all timers
        while i <= #timers do
            local timer = timers[i]
            
            -- If this timer has expired and isn't cancelled
            if timer.expires <= now and not timer.cancelled then
                -- Call the callback
                pcall(timer.callback)
                
                -- If this is a ticker with remaining iterations
                if timer.period and timer.iterations > 1 then
                    -- Reduce the iterations and set new expiry time
                    timer.iterations = timer.iterations - 1
                    timer.expires = now + timer.period
                    i = i + 1
                else
                    -- Remove one-time timers or completed tickers
                    table.remove(timers, i)
                end
            else
                -- Move to the next timer
                i = i + 1
            end
        end
        
        -- Hide the frame if there are no timers to process
        if #timers == 0 then
            self:Hide()
        end
    end)
    
    -- Start hidden
    timerFrame:Hide()
end

-- Alert that the compatibility layer is in place
if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00HLBG:|r C_Timer compatibility layer loaded successfully")
    
    -- Add a delayed message to ensure it's visible
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_ENTERING_WORLD" then
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00HLBG:|r C_Timer compatibility active")
            end
            self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        end
    end)
end
-- HLBG_TimerCompat.lua - Compatibility layer for C_Timer
-- *** CRITICAL: THIS FILE MUST LOAD FIRST (after HLBG_LoadDebug.lua) ***
-- This file provides compatibility functions for WoW 3.3.5a (Wrath of the Lich King)
-- It implements the C_Timer API that is used throughout the addon
-- The addon WILL NOT WORK without this file loading first
-- Verify that this file is the SECOND script listed in the TOC file

-- Record this file loading in diagnostics
if _G.HLBG_RecordFileLoad then
    _G.HLBG_RecordFileLoad("HLBG_TimerCompat.lua")
end

-- Check if C_Timer already exists (newer WoW versions)
if not C_Timer then
    -- Create our own implementation for older WoW versions
    C_Timer = {}
    
    -- Frame to handle our timers
    local timerFrame = CreateFrame("Frame")
    local timers = {}
    
    -- After function implementation
    function C_Timer.After(seconds, callback)
        if type(seconds) ~= "number" or type(callback) ~= "function" then
            return
        end
        
        -- Insert the timer into our tracking table
        table.insert(timers, {
            expires = GetTime() + seconds,
            callback = callback
        })
        
        -- Make sure our frame is running
        timerFrame:Show()
    end
    
    -- NewTimer function (creates a cancellable timer)
    function C_Timer.NewTimer(seconds, callback)
        if type(seconds) ~= "number" or type(callback) ~= "function" then
            return
        end
        
        local timer = {
            expires = GetTime() + seconds,
            callback = callback,
            cancelled = false
        }
        
        -- Insert the timer into our tracking table
        table.insert(timers, timer)
        
        -- Make sure our frame is running
        timerFrame:Show()
        
        -- Return a handle with a Cancel method
        return {
            Cancel = function()
                timer.cancelled = true
            end
        }
    end
    
    -- NewTicker function (creates a repeating timer)
    function C_Timer.NewTicker(seconds, callback, iterations)
        if type(seconds) ~= "number" or type(callback) ~= "function" then
            return
        end
        
        iterations = iterations or math.huge
        
        local ticker = {
            expires = GetTime() + seconds,
            callback = callback,
            iterations = iterations,
            cancelled = false,
            period = seconds
        }
        
        -- Insert the ticker into our tracking table
        table.insert(timers, ticker)
        
        -- Make sure our frame is running
        timerFrame:Show()
        
        -- Return a handle with a Cancel method
        return {
            Cancel = function()
                ticker.cancelled = true
            end
        }
    end
    
    -- Process the timers on each frame update
    timerFrame:SetScript("OnUpdate", function(self, elapsed)
        local now = GetTime()
        local i = 1
        
        -- Process all timers
        while i <= #timers do
            local timer = timers[i]
            
            -- If this timer has expired and isn't cancelled
            if timer.expires <= now and not timer.cancelled then
                -- Call the callback
                pcall(timer.callback)
                
                -- If this is a ticker with remaining iterations
                if timer.period and timer.iterations > 1 then
                    -- Reduce the iterations and set new expiry time
                    timer.iterations = timer.iterations - 1
                    timer.expires = now + timer.period
                    i = i + 1
                else
                    -- Remove one-time timers or completed tickers
                    table.remove(timers, i)
                end
            else
                -- Move to the next timer
                i = i + 1
            end
        end
        
        -- Hide the frame if there are no timers to process
        if #timers == 0 then
            self:Hide()
        end
    end)
    
    -- Start hidden
    timerFrame:Hide()
end

-- Alert that the compatibility layer is in place
if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00HLBG:|r C_Timer compatibility layer loaded successfully")
    
    -- Add a delayed message to ensure it's visible
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_ENTERING_WORLD" then
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00HLBG:|r C_Timer compatibility active")
            end
            self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        end
    end)
end
