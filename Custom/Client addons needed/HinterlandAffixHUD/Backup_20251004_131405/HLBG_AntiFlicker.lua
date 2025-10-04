-- HLBG_AntiFlicker.lua
-- Stabilizes addon behavior to prevent request spamming and flickering

local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

-- Track last request timestamps to prevent rapid repeated calls
HLBG._lastRequestTime = HLBG._lastRequestTime or {}

-- Flag to indicate if we're currently in The Hinterlands
HLBG._inHinterlands = false

-- Flag to indicate if HUD is properly initialized
HLBG._hudInitialized = false

-- Create a frame to manage throttling and error recovery
local throttleFrame = CreateFrame("Frame")

-- Setup safe request function that prevents spamming the server
function HLBG.SafeRequest(requestType, ...)
    -- Don't allow requests more often than every 5 seconds for the same type
    local now = GetTime()
    local lastTime = HLBG._lastRequestTime[requestType] or 0
    
    if now - lastTime < 5 then
        if HLBG._devMode then
            print("|cFFFFAA00HLBG Debug:|r Throttled " .. requestType .. " request (too soon)")
        end
        return false
    end
    
    -- Record the timestamp of this request
    HLBG._lastRequestTime[requestType] = now
    
    -- Send the request to the server
    if _G.AIO and _G.AIO.Handle then
        _G.AIO.Handle("HLBG", "Request", requestType, ...)
        return true
    end
    
    return false
end

-- Check if we're in Hinterlands and update state
function HLBG.UpdateZoneState()
    local z = (type(HLBG.safeGetRealZoneText) == 'function') and HLBG.safeGetRealZoneText() or (GetRealZoneText and GetRealZoneText() or "")
    local inHinterlands = (z == "The Hinterlands")
    
    -- Only take action if state has changed
    if inHinterlands ~= HLBG._inHinterlands then
        HLBG._inHinterlands = inHinterlands
        
        if inHinterlands then
            print("|cFF33FF99HLBG:|r Entered The Hinterlands - activating HUD")
            
            -- Request critical data but throttle the requests
            local function requestStatus() HLBG.SafeRequest("STATUS") end
            local function requestStats() HLBG.SafeRequest("STATS") end
            local function requestHistory() HLBG.SafeRequest("HISTORY", 1, 5, "id", "DESC") end
            local function updateUI()
                if HLBG.UpdateHUD then HLBG.UpdateHUD() end
                if HLBG.UpdateLiveFromStatus then HLBG.UpdateLiveFromStatus() end
            end
            
            -- Use our safe DelayedExecution function if available
            if HLBG.DelayedExecution then
                HLBG.DelayedExecution(0.5, requestStatus)
                HLBG.DelayedExecution(1.5, requestStats)
                HLBG.DelayedExecution(2.5, requestHistory)
                HLBG.DelayedExecution(1.0, updateUI)
            elseif C_Timer and C_Timer.After then
                C_Timer.After(0.5, requestStatus)
                C_Timer.After(1.5, requestStats) 
                C_Timer.After(2.5, requestHistory)
                C_Timer.After(1.0, updateUI)
            else
                -- If no timer is available, execute immediately but in sequence
                requestStatus()
                requestStats()
                requestHistory()
                updateUI()
            end
            
            -- Set the initialized flag
            HLBG._hudInitialized = true
        else
            -- Left the zone
            print("|cFF33FF99HLBG:|r Left The Hinterlands")
            
            -- Reset initialization flag when leaving
            HLBG._hudInitialized = false
        end
    end
    
    -- If we're in Hinterlands but HUD not properly shown, try to fix
    if inHinterlands and HLBG.UI and HLBG.UI.HUD and not HLBG.UI.HUD:IsShown() then
        local function updateUI()
            if HLBG.UpdateHUD then HLBG.UpdateHUD() end
            if HLBG.UpdateLiveFromStatus then HLBG.UpdateLiveFromStatus() end
        end
        
        -- Use our safe DelayedExecution function if available
        if HLBG.DelayedExecution then
            HLBG.DelayedExecution(0.5, updateUI)
        elseif C_Timer and C_Timer.After then
            C_Timer.After(0.5, updateUI)
        else
            -- If no timer is available, execute immediately
            updateUI()
        end
    end
end

-- Override History function to properly handle string data
local originalHistory = HLBG.History
if originalHistory then
    HLBG.History = function(rows, page, per, total, col, dir)
        -- Add safety to handle string data
        if type(rows) == 'string' then
            -- Try to parse as TSV
            local tsvRows = {}
            for line in string.gmatch(rows, '[^\n]+') do
                local id, ts, win, aff, data = line:match('^(.-)\t(.-)\t(.-)\t(.-)\t(.*)$')
                if id then
                    -- Try to parse the last column - might be duration or other data
                    local duration = tonumber(data) or data
                    table.insert(tsvRows, { id = id, ts = ts, winner = win, affix = aff, duration = duration })
                end
            end
            
            -- Call original with parsed table
            if #tsvRows > 0 then
                originalHistory(tsvRows, page, per, total, col, dir)
                return
            end
            
            -- If parsing failed, at least show something
            originalHistory({}, page, per, total, col, dir)
            return
        end
        
        -- Call original function for normal tables
        originalHistory(rows, page, per, total, col, dir)
    end
end

-- Override HistoryStr to be more resilient
local originalHistoryStr = HLBG.HistoryStr
if originalHistoryStr then
    HLBG.HistoryStr = function(tsv, page, per, total, col, dir)
        if type(tsv) ~= 'string' then
            -- Convert to string if possible
            if type(tsv) == 'table' then
                local lines = {}
                for i, row in ipairs(tsv) do
                    if type(row) == 'table' then
                        local id = row.id or row[1] or i
                        local ts = row.ts or row[2] or ""
                        local win = row.winner or row[3] or ""
                        local aff = row.affix or row[4] or ""
                        local dur = row.duration or row.reason or row[5] or ""
                        table.insert(lines, id .. "\t" .. ts .. "\t" .. win .. "\t" .. aff .. "\t" .. dur)
                    end
                end
                tsv = table.concat(lines, "\n")
            else
                tsv = ""
            end
        end
        
        -- Call original function
        originalHistoryStr(tsv, page, per, total, col, dir)
    end
end

-- Register for events
throttleFrame:RegisterEvent("ZONE_CHANGED")
throttleFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
throttleFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
throttleFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

throttleFrame:SetScript("OnEvent", function(self, event)
    -- Update zone state on zone change events
    HLBG.UpdateZoneState()
end)

-- Set up polling for zone state (every 5 seconds)
local zoneCheckInterval = 0
throttleFrame:SetScript("OnUpdate", function(self, elapsed)
    zoneCheckInterval = zoneCheckInterval + elapsed
    
    if zoneCheckInterval >= 5 then
        zoneCheckInterval = 0
        HLBG.UpdateZoneState()
    end
end)

-- Also patch AIO.Handle directly to prevent infinite loops
if _G.AIO and _G.AIO.Handle then
    local originalHandle = _G.AIO.Handle
    _G.AIO.Handle = function(prefix, ...)
        -- If this is a request to HLBG, apply throttling
        if prefix == "HLBG" then
            local args = {...}
            local msgType = args[1]
            
            -- If it's a Request type, check if we need throttling
            if msgType == "Request" then
                local requestType = args[2]
                
                -- Track last request timestamps to prevent rapid repeated calls
                local now = GetTime()
                local lastTime = HLBG._lastRequestTime[requestType] or 0
                
                -- Don't allow request spam (more than once every 3 seconds)
                if now - lastTime < 3 then
                    if HLBG._devMode then
                        print("|cFFFFAA00HLBG Debug:|r Blocked AIO spam " .. requestType)
                    end
                    return
                end
                
                -- Record this request time
                HLBG._lastRequestTime[requestType] = now
            end
        end
        
        -- Call the original function
        return originalHandle(prefix, ...)
    end
end

-- Initialize on load
HLBG.UpdateZoneState()

-- Request initial status data once at startup (with delay to let everything initialize)
local function initialRequests()
    HLBG.SafeRequest("STATUS")
    HLBG.SafeRequest("STATS")
end

-- Use our safe DelayedExecution function if available
if HLBG.DelayedExecution then
    HLBG.DelayedExecution(1.0, initialRequests)
elseif C_Timer and C_Timer.After then
    C_Timer.After(1.0, initialRequests)
else
    -- If no timer is available, execute with minimal delay
    local delayFrame = CreateFrame("Frame")
    delayFrame:SetScript("OnUpdate", function(self)
        initialRequests()
        self:SetScript("OnUpdate", nil)
    end)
end

print("|cFF33FF99HLBG:|r AntiFlicker module loaded")