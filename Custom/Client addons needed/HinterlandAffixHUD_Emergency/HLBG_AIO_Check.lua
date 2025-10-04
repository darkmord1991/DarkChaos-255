-- HLBG_AIO_Check.lua - Ensures AIO is loaded before initializing HLBG (Emergency Version)

-- Track that this file was loaded
if _G.HLBG_RecordFileLoad then
    _G.HLBG_RecordFileLoad("HLBG_AIO_Check.lua")
end

-- Create or use existing namespace
local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

-- Create a frame to monitor loading state
local aioCheckFrame = CreateFrame("Frame")
aioCheckFrame.retryCount = 0
aioCheckFrame.maxRetries = 10
aioCheckFrame.initialized = false

-- Function to check if AIO is available and initialize our addon
local function CheckAIO()
    if aioCheckFrame.initialized then
        return
    end
    
    -- Always print AIO status for emergency version
    if DEFAULT_CHAT_FRAME then
        if _G.AIO and type(_G.AIO) == "table" and type(_G.AIO.Handle) == "function" then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00HLBG Emergency:|r AIO detected: YES")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF6600HLBG Emergency:|r AIO detected: NO (attempt " .. aioCheckFrame.retryCount .. ")")
        end
    end
    
    if _G.AIO and type(_G.AIO) == "table" and type(_G.AIO.Handle) == "function" then
        -- AIO is available, we can initialize
        aioCheckFrame.initialized = true
        
        -- Log success
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00HLBG Emergency:|r AIO dependency verified, initializing addon")
        end
        
        -- Record in the load state
        if _G.HLBG_LoadState then
            _G.HLBG_LoadState.aioVerified = true
            _G.HLBG_LoadState.aioLoaded = true
            _G.HLBG_LoadState.aioAvailable = true
        end
        
        -- Unregister the update script
        aioCheckFrame:SetScript("OnUpdate", nil)
        
        -- Ensure the HLBG table has required fields
        HLBG._lastStatus = HLBG._lastStatus or {}
        HLBG._devMode = true -- Always enable dev mode in emergency version
        
        -- Register with AIO
        if _G.AIO and _G.AIO.RegisterEvent then
            _G.AIO.RegisterEvent("HLBG", function(command, args)
                if type(command) ~= "string" then return end
                
                -- Always log AIO commands in emergency version
                local argsStr = ""
                if type(args) == "table" then
                    for k,v in pairs(args) do 
                        argsStr = argsStr .. " " .. tostring(k) .. "=" .. tostring(v) 
                    end
                else
                    argsStr = tostring(args or "nil")
                end
                
                DEFAULT_CHAT_FRAME:AddMessage("|cFF88EEEEHLBG Command:|r " .. command .. " Args: " .. argsStr)
                
                -- Simple command handling
                if command == "Status" or command == "status" then
                    DEFAULT_CHAT_FRAME:AddMessage("|cFF88EEEEHLBG:|r Status update received!")
                elseif command == "Error" or command == "error" then
                    if type(args) == "table" and type(args.message) == "string" then
                        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000HLBG Error:|r " .. args.message)
                    end
                end
            end)
            
            -- Send a test command to verify connection
            _G.AIO.Handle("HLBG", "Ping", { emergency = true, time = time() })
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00HLBG Emergency:|r AIO test command sent")
        end
        
        return true
    else
        -- AIO not available yet, increment retry counter
        aioCheckFrame.retryCount = aioCheckFrame.retryCount + 1
        
        if aioCheckFrame.retryCount >= aioCheckFrame.maxRetries then
            -- Too many retries, give up and show error
            aioCheckFrame:SetScript("OnUpdate", nil)
            
            if DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000HLBG Emergency Error:|r Required dependency AIO_Client not found after " .. 
                    aioCheckFrame.maxRetries .. " attempts. Please ensure AIO_Client addon is installed and enabled.")
            end
            
            -- Record error in the load state
            if _G.HLBG_LoadState then
                _G.HLBG_LoadState.errors = _G.HLBG_LoadState.errors or {}
                table.insert(_G.HLBG_LoadState.errors, "AIO_Client dependency not found after " .. aioCheckFrame.maxRetries .. " attempts")
                _G.HLBG_LoadState.aioVerified = false
            end
            
            return false
        end
        
        return false
    end
end

-- Set up OnUpdate to check for AIO
aioCheckFrame:SetScript("OnUpdate", function(self, elapsed)
    -- Only check every 0.5 seconds
    if not self.timeSinceLastCheck then self.timeSinceLastCheck = 0 end
    self.timeSinceLastCheck = self.timeSinceLastCheck + elapsed
    
    if self.timeSinceLastCheck >= 0.5 then
        self.timeSinceLastCheck = 0
        CheckAIO()
    end
end)

-- Also register for ADDON_LOADED event for AIO_Client
aioCheckFrame:RegisterEvent("ADDON_LOADED")
aioCheckFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" then
        -- Log all addon loads in emergency version
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFAAFF88HLBG Emergency:|r ADDON_LOADED: " .. addonName)
        end
        
        if addonName == "AIO_Client" then
            -- AIO_Client loaded, check if it's ready
            CheckAIO()
        end
    end
end)

-- Store the check function globally for use by other files
_G.HLBG_CheckAIO = CheckAIO

-- Do an initial check immediately
CheckAIO()

-- Simple send command function
function HLBG.SendCommand(command, args)
    if type(command) ~= "string" then return end
    args = args or {}
    if type(args) ~= "table" then args = { value = tostring(args) } end
    
    -- Verify AIO is loaded and ready
    if not _G.AIO or not _G.AIO.Handle then 
        if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000HLBG Error:|r AIO not ready") end
        return
    end
    
    -- Log all outgoing commands in emergency version
    if DEFAULT_CHAT_FRAME then
        local argsStr = ""
        for k,v in pairs(args) do argsStr = argsStr .. " " .. tostring(k) .. "=" .. tostring(v) end
        DEFAULT_CHAT_FRAME:AddMessage("|cFF88AA88HLBG Emergency Sending:|r " .. command .. " Args: " .. argsStr)
    end
    
    -- Send command via AIO
    _G.AIO.Handle("HLBG", command, args)
end