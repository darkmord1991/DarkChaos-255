-- HLBG_AIO_Check.lua - Check if AIO is available and set up initialization

-- Record that this file was loaded
if _G.HLBG_RecordFileLoad then
    _G.HLBG_RecordFileLoad("HLBG_AIO_Check.lua")
end

-- Global variable to store AIO availability
_G.HLBG_AIO_Available = false

-- Callback queue for functions that need AIO
_G.HLBG_AIO_Callbacks = {}

-- Function to check if AIO is available
function _G.HLBG_AIO_Check()
    if _G.AIO and type(_G.AIO.Handle) == "function" and type(_G.AIO.AddHandlers) == "function" then
        _G.HLBG_AIO_Available = true
        return true
    else
        _G.HLBG_AIO_Available = false
        return false
    end
end

-- Helper function for external code to check AIO availability
function _G.HLBG_AIO_Available()
    return _G.HLBG_AIO_Check()
end

-- Register a callback to run after AIO is available
function _G.HLBG_RegisterAIOCallback(callback, name)
    if type(callback) ~= "function" then
        return false
    end
    
    name = name or "unnamed_" .. #_G.HLBG_AIO_Callbacks + 1
    
    table.insert(_G.HLBG_AIO_Callbacks, {
        func = callback,
        name = name
    })
    
    -- If AIO is already available, execute callback immediately
    if _G.HLBG_AIO_Check() then
        if DEFAULT_CHAT_FRAME and _G.HLBG_Debug then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00EEFF[HLBG AIO]|r Executing callback immediately: " .. name)
        end
        callback()
        return true
    end
    
    if DEFAULT_CHAT_FRAME and _G.HLBG_Debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00EEFF[HLBG AIO]|r Registered callback for later: " .. name)
    end
    return true
end

-- Set up timer to keep checking for AIO
local frame = CreateFrame("Frame")
local checkInterval = 1.0 -- Check every second
local maxChecks = 30      -- Maximum number of checks (30 seconds)
local checkCount = 0

frame:SetScript("OnUpdate", function(self, elapsed)
    -- Wait for check interval
    if not self.checkTime then
        self.checkTime = checkInterval
    end
    
    self.checkTime = self.checkTime - elapsed
    if self.checkTime > 0 then
        return
    end
    
    -- Reset timer
    self.checkTime = checkInterval
    
    -- Check if AIO is available
    if _G.HLBG_AIO_Check() then
        -- AIO is available, process callbacks
        if DEFAULT_CHAT_FRAME and _G.HLBG_Debug then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00EEFF[HLBG AIO]|r AIO is available, processing callbacks")
        end
        
        -- Execute all registered callbacks
        for _, callback in ipairs(_G.HLBG_AIO_Callbacks) do
            if DEFAULT_CHAT_FRAME and _G.HLBG_Debug then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00EEFF[HLBG AIO]|r Executing callback: " .. callback.name)
            end
            
            local success, err = pcall(callback.func)
            if not success and DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[HLBG AIO Error]|r Callback failed: " .. tostring(err))
            end
        end
        
        -- Stop checking
        self:SetScript("OnUpdate", nil)
        
        if DEFAULT_CHAT_FRAME and _G.HLBG_Debug then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00EEFF[HLBG AIO]|r All callbacks processed")
        end
    else
        -- AIO not available yet
        checkCount = checkCount + 1
        
        if DEFAULT_CHAT_FRAME and _G.HLBG_Debug then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00EEFF[HLBG AIO]|r AIO not available yet, check " .. checkCount .. "/" .. maxChecks)
        end
        
        -- If we've checked too many times, give up
        if checkCount >= maxChecks then
            if DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[HLBG AIO]|r AIO not found after " .. maxChecks .. " checks, giving up")
            end
            self:SetScript("OnUpdate", nil)
        end
    end
end)

-- Run an immediate check in case AIO is already available
if _G.HLBG_AIO_Check() then
    if DEFAULT_CHAT_FRAME and _G.HLBG_Debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00EEFF[HLBG AIO]|r AIO is immediately available")
    end
else
    if DEFAULT_CHAT_FRAME and _G.HLBG_Debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00EEFF[HLBG AIO]|r AIO not immediately available, will check later")
    end
end