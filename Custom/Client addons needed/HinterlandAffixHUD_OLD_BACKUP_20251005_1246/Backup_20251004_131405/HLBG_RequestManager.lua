-- HLBG_RequestManager.lua - Central request management to prevent spamming

-- Ensure HLBG namespace exists
HLBG = HLBG or {}

-- Request tracking and throttling
HLBG._lastRequests = HLBG._lastRequests or {}
HLBG._requestQueue = HLBG._requestQueue or {}
HLBG._pendingRequests = HLBG._pendingRequests or {}
HLBG._requestRetries = HLBG._requestRetries or {}

-- Maximum retries for failed requests
HLBG.MAX_RETRIES = 3

-- Cooldown periods for different request types (in seconds)
HLBG.REQUEST_COOLDOWNS = {
    HISTORY = 3.0,
    STATS = 3.0,
    AFFIXES = 5.0,
    STATUS = 2.0,
    QUEUE = 2.0,
    DEFAULT = 2.0
}

-- Throttled request function with retry support
function HLBG.ThrottledRequest(requestType, ...)
    local now = GetTime()
    local lastRequest = HLBG._lastRequests[requestType] or 0
    local cooldown = HLBG.REQUEST_COOLDOWNS[requestType] or HLBG.REQUEST_COOLDOWNS.DEFAULT
    
    -- Generate a unique ID for this request
    local requestId = requestType .. "_" .. tostring(now)
    
    if (now - lastRequest) < cooldown then
        -- Queue this request
        local args = {...}
        table.insert(HLBG._requestQueue, {
            type = requestType, 
            args = args, 
            time = now + cooldown,
            id = requestId
        })
        
        if HLBG._devMode then
            print("HLBG: Request " .. requestType .. " queued, too soon after previous request")
        end
        
        return requestId
    end
    
    -- Update the last request time
    HLBG._lastRequests[requestType] = now
    
    -- Send the request
    if _G.AIO and _G.AIO.Handle then
        if HLBG._devMode then
            print("HLBG: Sending request " .. requestType)
        end
        
        -- Track this request
        HLBG._pendingRequests[requestId] = {
            type = requestType,
            args = {...},
            sent = now,
            timeout = now + 5.0 -- 5 second timeout
        }
        
        -- Send to server
        _G.AIO.Handle("HLBG", "Request", requestType, ...)
        
        return requestId
    end
    
    return nil
end

-- Process queued requests
local requestFrame = CreateFrame("Frame")
requestFrame:SetScript("OnUpdate", function(self, elapsed)
    local now = GetTime()
    
    -- Process the queue
    if #HLBG._requestQueue > 0 then
        local i = 1
        while i <= #HLBG._requestQueue do
            local request = HLBG._requestQueue[i]
            if now >= request.time then
                -- Time to execute this request
                HLBG.ThrottledRequest(request.type, unpack(request.args))
                table.remove(HLBG._requestQueue, i)
            else
                i = i + 1
            end
        end
    end
    
    -- Check for timeouts
    for id, req in pairs(HLBG._pendingRequests) do
        if now > req.timeout then
            -- Request timed out
            local retries = HLBG._requestRetries[id] or 0
            if retries < HLBG.MAX_RETRIES then
                -- Retry with exponential backoff
                retries = retries + 1
                HLBG._requestRetries[id] = retries
                local backoff = math.pow(2, retries) -- 2, 4, 8 seconds
                
                -- Queue a retry
                table.insert(HLBG._requestQueue, {
                    type = req.type,
                    args = req.args,
                    time = now + backoff,
                    id = id .. "_retry" .. retries
                })
                
                if HLBG._devMode then
                    print("HLBG: Request " .. req.type .. " timed out, scheduling retry " .. retries .. " in " .. backoff .. "s")
                end
            else
                if HLBG._devMode then
                    print("HLBG: Request " .. req.type .. " failed after " .. HLBG.MAX_RETRIES .. " retries")
                end
                HLBG._requestRetries[id] = nil
            end
            
            -- Remove the timed out request
            HLBG._pendingRequests[id] = nil
        end
    end
end)

-- Mark a request as complete (call this when receiving a response)
function HLBG.CompleteRequest(requestType)
    -- Find and mark any pending requests of this type as complete
    local now = GetTime()
    local removed = false
    
    for id, req in pairs(HLBG._pendingRequests) do
        if req.type == requestType then
            HLBG._pendingRequests[id] = nil
            HLBG._requestRetries[id] = nil
            removed = true
            if HLBG._devMode then
                print("HLBG: Request " .. requestType .. " completed")
            end
        end
    end
    
    return removed
end

-- Helper function to clear all pending requests (use when switching contexts)
function HLBG.ClearAllRequests()
    HLBG._pendingRequests = {}
    HLBG._requestRetries = {}
    HLBG._requestQueue = {}
    if HLBG._devMode then
        print("HLBG: All pending requests cleared")
    end
end

-- Custom delay function in case C_Timer isn't available
function HLBG.DelayedExecution(seconds, callback)
    if C_Timer and C_Timer.After then
        C_Timer.After(seconds, callback)
    else
        -- Create a simple frame-based timer
        local timerFrame = CreateFrame("Frame")
        local elapsed = 0
        timerFrame:SetScript("OnUpdate", function(self, e)
            elapsed = elapsed + e
            if elapsed >= seconds then
                callback()
                self:SetScript("OnUpdate", nil)
            end
        end)
    end
end

-- Initial staggered data requests
function HLBG.RequestInitialData()
    HLBG.DelayedExecution(0.5, function()
        HLBG.ThrottledRequest("STATUS")
        
        HLBG.DelayedExecution(1.0, function()
            local sv = (HLBG and HLBG._getSeason and HLBG._getSeason()) or 0
            local wf = (HinterlandAffixHUDDB and HinterlandAffixHUDDB.histWinner) or 'ALL'
            local af = (HinterlandAffixHUDDB and HinterlandAffixHUDDB.histAffix) or ''
            
            HLBG.ThrottledRequest("HISTORY", 1, HLBG.UI and HLBG.UI.History and HLBG.UI.History.per or 15, 
                "id", "ASC", wf, HLBG.ResolveAffixFilter and HLBG.ResolveAffixFilter(af) or af, sv)
        end)
        
        HLBG.DelayedExecution(2.0, function()
            HLBG.ThrottledRequest("STATS")
        end)
        
        HLBG.DelayedExecution(3.0, function()
            local sv = (HLBG and HLBG._getSeason and HLBG._getSeason()) or 0
            HLBG.ThrottledRequest("AFFIXES", sv, HinterlandAffixHUDDB and HinterlandAffixHUDDB.affixSearch or '')
        end)
        
        HLBG.DelayedExecution(4.0, function()
            HLBG.ThrottledRequest("QUEUE", "STATUS")
        end)
    end)
end

-- Call our initial data request function after a short delay
HLBG.DelayedExecution(1.0, HLBG.RequestInitialData)