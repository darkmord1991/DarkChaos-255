-- HLBG_LoadDebug.lua
-- Early loading debug helper to troubleshoot addon loading issues

-- Create a global for load state tracking
_G.HLBG_LoadState = _G.HLBG_LoadState or {}
_G.HLBG_LoadState.files = _G.HLBG_LoadState.files or {}
_G.HLBG_LoadState.errors = _G.HLBG_LoadState.errors or {}

-- Record this file as loaded
table.insert(_G.HLBG_LoadState.files, "HLBG_LoadDebug.lua")

-- Create a frame to watch for errors during loading
local loadFrame = CreateFrame("Frame")

-- Track load errors
loadFrame:SetScript("OnEvent", function(self, event, errorMessage)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "HinterlandAffixHUD" then
            -- Record addon loaded successfully
            _G.HLBG_LoadState.addonLoaded = true
            
            -- Log addon loaded message to chat
            if DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00HLBG:|r Addon loaded successfully. Files processed: " .. #(_G.HLBG_LoadState.files or {}))
            end
            
            -- Check for any C_Timer usage before compatibility layer
            self:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "LUA_ERROR" then
        -- Record the error
        table.insert(_G.HLBG_LoadState.errors, errorMessage or "Unknown error")
        
        -- Log error to chat
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000HLBG Error:|r " .. (errorMessage or "Unknown error"))
        end
    end
end)

-- Register for events
loadFrame:RegisterEvent("ADDON_LOADED")
loadFrame:RegisterEvent("LUA_ERROR")

-- Create safe wrappers for critical functions
_G.HLBG_SafeTimerWrapper = function()
    -- Check if C_Timer exists
    if not _G.C_Timer then
        -- C_Timer doesn't exist, compatibility layer might not be loaded properly
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000HLBG Error:|r C_Timer not found! Compatibility layer might not be loaded properly.")
        end
        
        -- Record error
        table.insert(_G.HLBG_LoadState.errors, "C_Timer not found at usage point")
        
        -- Return dummy functions to prevent errors
        return {
            After = function(seconds, callback) 
                if DEFAULT_CHAT_FRAME then
                    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000HLBG Error:|r Attempted to use C_Timer.After when C_Timer is not available")
                end
            end,
            NewTimer = function(seconds, callback) 
                if DEFAULT_CHAT_FRAME then
                    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000HLBG Error:|r Attempted to use C_Timer.NewTimer when C_Timer is not available")
                end
                return { Cancel = function() end }
            end,
            NewTicker = function(seconds, callback, iterations) 
                if DEFAULT_CHAT_FRAME then
                    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000HLBG Error:|r Attempted to use C_Timer.NewTicker when C_Timer is not available")
                end
                return { Cancel = function() end }
            end
        }
    end
    
    -- C_Timer exists, use it normally
    return _G.C_Timer
end

-- Tracking function to record file loading
_G.HLBG_RecordFileLoad = function(filename)
    if not _G.HLBG_LoadState.files then _G.HLBG_LoadState.files = {} end
    table.insert(_G.HLBG_LoadState.files, filename)
    
    -- If this is the first file loaded, it should be the C_Timer compatibility layer
    if #_G.HLBG_LoadState.files == 1 and filename ~= "HLBG_LoadDebug.lua" and filename ~= "HLBG_TimerCompat.lua" then
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000HLBG Warning:|r First file loaded is " .. filename .. " but should be HLBG_TimerCompat.lua!")
        end
    end
end

-- Add diagnostic command
SLASH_HLBGDIAG1 = "/hlbgdiag"
SlashCmdList["HLBGDIAG"] = function(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[HLBG Diagnostics]|r")
        DEFAULT_CHAT_FRAME:AddMessage("Addon loaded: " .. (_G.HLBG_LoadState.addonLoaded and "Yes" or "No"))
        DEFAULT_CHAT_FRAME:AddMessage("Files loaded: " .. #(_G.HLBG_LoadState.files or {}))
        
        -- Show first 5 files loaded
        DEFAULT_CHAT_FRAME:AddMessage("First files loaded:")
        for i = 1, math.min(5, #(_G.HLBG_LoadState.files or {})) do
            DEFAULT_CHAT_FRAME:AddMessage("  " .. i .. ". " .. (_G.HLBG_LoadState.files[i] or "unknown"))
        end
        
        -- Show errors if any
        if #(_G.HLBG_LoadState.errors or {}) > 0 then
            DEFAULT_CHAT_FRAME:AddMessage("Errors encountered: " .. #_G.HLBG_LoadState.errors)
            for i = 1, math.min(5, #_G.HLBG_LoadState.errors) do
                DEFAULT_CHAT_FRAME:AddMessage("  - " .. (_G.HLBG_LoadState.errors[i] or "unknown"))
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage("No errors recorded.")
        end
        
        -- Check C_Timer
        DEFAULT_CHAT_FRAME:AddMessage("C_Timer available: " .. (_G.C_Timer and "Yes" or "No"))
    end
end

-- Print a debug message so we know this file loaded
if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00EEFF[HLBG Debug]|r Loaded: HLBG_LoadDebug.lua")
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00EEFF[HLBG Debug]|r Load debugging is active")
end

-- Record this file as loaded
_G.HLBG_RecordFileLoad("HLBG_LoadDebug.lua")

-- Enable debug mode globally
_G.HLBG_Debug = true