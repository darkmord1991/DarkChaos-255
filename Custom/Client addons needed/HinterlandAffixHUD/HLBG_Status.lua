-- HLBG_Status.lua - Status updating functionality for Hinterland Battleground Addon

-- Ensure HLBG namespace exists
HLBG = HLBG or {}

-- Function to request status update from server
function HLBG.RequestStatus()
    -- Send status request through AIO if available
    if _G.AIO and _G.AIO.Handle then
        _G.AIO.Handle('HLBG', 'Request', 'STATUS')
        _G.AIO.Handle('HLBG', 'Status')
        _G.AIO.Handle('HLBG', 'STATUS')
    end
    
    -- Also use server dot command as fallback
    if type(HLBG.SendServerDot) == 'function' then
        HLBG.SendServerDot('.hlbg status')
    end
    
    -- Debug output if dev mode enabled
    if HLBG._devMode then
        print("HLBG: Status request sent")
    end
end

-- Process status update received from server
function HLBG.ProcessStatusUpdate(status)
    if type(status) ~= 'table' then
        -- Try to parse string format
        if type(status) == 'string' then
            -- Parse key=value pairs
            local parsed = {}
            for pair in status:gmatch("[^|]+") do
                local key, value = pair:match("^(%w+)=(.+)$")
                if key then parsed[key] = value end
            end
            status = parsed
        else
            -- Create empty status if not valid
            status = {}
        end
    end
    
    -- Store status in the addon's cache
    HLBG._lastStatus = status
    
    -- Extract affix information
    local affixID = status.affix or status.affixID or status.affixId or status.AFF
    if affixID then
        -- If we have an affix ID from server, get its name
        if HLBG.GetAffixName and type(HLBG.GetAffixName) == 'function' then
            HLBG._affixText = HLBG.GetAffixName(affixID)
        else
            HLBG._affixText = tostring(affixID)
        end
        
        -- Store the affix ID 
        HLBG._currentAffixID = affixID
    end
    
    -- Update the HUD display
    if type(HLBG.UpdateHUD) == 'function' then
        pcall(HLBG.UpdateHUD)
    end
    
    -- Update the Live tab if present
    if type(HLBG.UpdateLiveFromStatus) == 'function' then
        pcall(HLBG.UpdateLiveFromStatus)
    end
    
    -- Debug output
    if HLBG._devMode then
        print("HLBG: Status update processed")
        print("  Affix ID:", HLBG._currentAffixID)
        print("  Affix Text:", HLBG._affixText)
    end
end

-- Set up a timer to periodically request status updates
local statusUpdateTimer = nil
local function SetupStatusTimer()
    if not statusUpdateTimer then
        -- Request status now
        HLBG.RequestStatus()
        
        -- Create our own ticker if C_Timer.NewTicker isn't available
        if C_Timer and C_Timer.NewTicker then
            -- Set up timer to request status every 10 seconds using C_Timer
            statusUpdateTimer = C_Timer.NewTicker(10, function()
                HLBG.RequestStatus()
            end)
        else
            -- Create a frame-based timer as fallback
            local timerFrame = CreateFrame("Frame")
            local elapsed = 0
            local interval = 10 -- 10 seconds
            
            timerFrame:SetScript("OnUpdate", function(self, e)
                elapsed = elapsed + e
                if elapsed >= interval then
                    elapsed = 0
                    HLBG.RequestStatus()
                end
            end)
            
            statusUpdateTimer = timerFrame
        end
    end
end

-- Add to HLBG initialization
local originalInit = HLBG.Init
HLBG.Init = function(...)
    -- Call the original init function if it exists
    if type(originalInit) == 'function' then
        originalInit(...)
    end
    
    -- Set up our status timer
    SetupStatusTimer()
end

-- Register AIO handler for status updates
if _G.AIO and _G.AIO.AddHandlers then
    local handler = _G.AIO.AddHandlers('HLBG', {})
    handler.Status = HLBG.ProcessStatusUpdate
    handler.STATUS = HLBG.ProcessStatusUpdate
end

-- Initialize right away if HLBG is already loaded
if HLBG._initialized then
    SetupStatusTimer()
end