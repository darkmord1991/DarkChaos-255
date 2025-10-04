-- HLBG_TimerCompat.lua - Timer compatibility for WoW 3.3.5a

-- Record that this file was loaded
if _G.HLBG_RecordFileLoad then
    _G.HLBG_RecordFileLoad("HLBG_TimerCompat.lua")
end

-- Create C_Timer compatibility for WoW 3.3.5a clients
if not C_Timer then
    C_Timer = {}
    
    local timerFrame = CreateFrame("Frame")
    local timers = {}
    
    timerFrame:SetScript("OnUpdate", function(self, elapsed)
        for i = #timers, 1, -1 do
            local timer = timers[i]
            timer.timeLeft = timer.timeLeft - elapsed
            
            if timer.timeLeft <= 0 then
                -- Remove from table first to prevent issues if the callback creates a new timer
                table.remove(timers, i)
                -- Call the function
                timer.callback()
            end
        end
    end)
    
    function C_Timer.After(duration, callback)
        if type(duration) ~= "number" or type(callback) ~= "function" then
            return false
        end
        
        table.insert(timers, {
            timeLeft = duration,
            callback = callback
        })
        
        return true
    end
    
    function C_Timer.NewTimer(duration, callback)
        return C_Timer.After(duration, callback)
    end
    
    function C_Timer.NewTicker(duration, callback, iterations)
        if type(duration) ~= "number" or type(callback) ~= "function" then
            return nil
        end
        
        iterations = iterations or math.huge
        local ticker = {}
        ticker.remainingIterations = iterations
        
        local function tickerFunc()
            callback()
            ticker.remainingIterations = ticker.remainingIterations - 1
            
            if ticker.remainingIterations > 0 then
                -- Schedule the next tick
                C_Timer.After(duration, tickerFunc)
            end
        end
        
        -- Start the first iteration
        C_Timer.After(duration, tickerFunc)
        
        -- Mock ticker object with cancel function
        ticker.Cancel = function(self)
            self.remainingIterations = 0
        end
        
        return ticker
    end
end

-- Record success if debug is enabled
if DEFAULT_CHAT_FRAME and _G.HLBG_Debug then
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00EEFF[HLBG Timer]|r C_Timer compatibility loaded")
end