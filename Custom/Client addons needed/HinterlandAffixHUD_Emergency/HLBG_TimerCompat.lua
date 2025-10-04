-- HLBG_TimerCompat.lua - Provides C_Timer compatibility functions for WoW 3.3.5 (Emergency Version)

-- Track that this file was loaded
if _G.HLBG_RecordFileLoad then
    _G.HLBG_RecordFileLoad("HLBG_TimerCompat.lua")
end

-- Create the timer namespace if it doesn't exist
if not _G.C_Timer then
    _G.C_Timer = {}
    
    -- Print initialization message
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00EEEAHLBG Emergency:|r C_Timer compatibility layer created")
    end
end

-- If another addon already created C_Timer, don't override
if not _G.C_Timer.After then
    _G.C_Timer._registry = {}
    _G.C_Timer._frame = CreateFrame("Frame")
    _G.C_Timer._nextId = 1
    
    -- Main update handler
    _G.C_Timer._frame:SetScript("OnUpdate", function(self, elapsed)
        local registry = _G.C_Timer._registry
        local toRemove = {}
        
        for id, timer in pairs(registry) do
            timer.elapsed = timer.elapsed + elapsed
            
            if timer.elapsed >= timer.delay then
                if type(timer.callback) == "function" then
                    local success, error = pcall(timer.callback)
                    if not success and DEFAULT_CHAT_FRAME then
                        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000HLBG Emergency Timer Error:|r " .. tostring(error))
                    end
                end
                table.insert(toRemove, id)
            end
        end
        
        for _, id in ipairs(toRemove) do
            registry[id] = nil
        end
    end)
    
    -- Function to execute a function after a delay in seconds
    function _G.C_Timer.After(delay, callback)
        if type(delay) ~= "number" or delay < 0 then
            delay = 0.01
        end
        
        if type(callback) ~= "function" then
            return
        end
        
        local id = _G.C_Timer._nextId
        _G.C_Timer._nextId = _G.C_Timer._nextId + 1
        
        _G.C_Timer._registry[id] = {
            delay = delay,
            elapsed = 0,
            callback = callback
        }
        
        return id
    end
    
    -- Function to cancel a timer
    function _G.C_Timer.Cancel(id)
        if id and _G.C_Timer._registry[id] then
            _G.C_Timer._registry[id] = nil
            return true
        end
        return false
    end
    
    -- Create a new timer object with an interval
    function _G.C_Timer.NewTimer(delay, callback)
        local id = _G.C_Timer.After(delay, callback)
        
        return {
            id = id,
            Cancel = function(self)
                return _G.C_Timer.Cancel(self.id)
            end
        }
    end
    
    -- Create a repeating timer
    function _G.C_Timer.NewTicker(interval, callback, iterations)
        if type(interval) ~= "number" or interval < 0.01 then
            interval = 0.01
        end
        
        if type(callback) ~= "function" then
            return
        end
        
        iterations = iterations or math.huge
        
        local ticker = {}
        ticker.interval = interval
        ticker.iterations = iterations
        ticker.remainingIterations = iterations
        ticker.callback = callback
        
        local function Tick()
            if ticker.cancelled then return end
            
            local success, error = pcall(ticker.callback)
            if not success and DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000HLBG Emergency Ticker Error:|r " .. tostring(error))
            end
            
            ticker.remainingIterations = ticker.remainingIterations - 1
            
            if ticker.remainingIterations > 0 then
                ticker.id = _G.C_Timer.After(ticker.interval, Tick)
            end
        end
        
        ticker.id = _G.C_Timer.After(interval, Tick)
        
        -- Add methods to the ticker
        ticker.Cancel = function(self)
            self.cancelled = true
            return _G.C_Timer.Cancel(self.id)
        end
        
        return ticker
    end
    
    -- Print completion message
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00HLBG Emergency:|r C_Timer functions created successfully")
    end
end