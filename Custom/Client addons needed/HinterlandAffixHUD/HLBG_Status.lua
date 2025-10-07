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
    
    -- Normalize numeric fields and clamp to sane ranges
    local function tonum(v) return tonumber(v) or 0 end
    status.A = tonum(status.A)
    status.H = tonum(status.H)
    status.END = tonum(status.END)
    status.APPLAYERS = tonum(status.APLAYERS or status.APlayers or status.APC)
    status.HPLAYERS = tonum(status.HPLAYERS or status.HPlayers or status.HPC)

    -- Ignore duplicate identical status objects to avoid UI flip-flops
    if HLBG._lastStatus then
        local last = HLBG._lastStatus
        if last.A == status.A and last.H == status.H and last.END == status.END then
            -- no meaningful change
            return
        end
    end

    -- Store status in the addon's cache
    HLBG._lastStatus = status
    -- Record a timestamp and source for debugging/dumps
    local now = (type(time) == 'function' and time()) or ((type(GetTime) == 'function' and GetTime()) or 0)
    HLBG._lastStatusTimestamp = now
    HLBG._lastStatusSource = 'AIO'
    
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
    
    -- Live tab functionality disabled - no update needed
    
    -- Debug output
    if HLBG._devMode then
        print("HLBG: Status update processed")
        print("  Affix ID:", HLBG._currentAffixID)
        print("  Affix Text:", HLBG._affixText)
        print("  Timestamp:", HLBG._lastStatusTimestamp)
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

-- Expose status handlers on the HLBG table for central AIO registration
HLBG.Status = HLBG.ProcessStatusUpdate
HLBG.STATUS = HLBG.ProcessStatusUpdate

-- Initialize right away if HLBG is already loaded
if HLBG._initialized then
    SetupStatusTimer()
end