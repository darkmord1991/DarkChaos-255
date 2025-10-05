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
loadFrame:SetScript("OnEvent", function(self, event, ...)
    local varargs = {...}
    local eventLocal = event
    local ok, err = pcall(function()
        local args = varargs
        if eventLocal == "ADDON_LOADED" then
            local addonName = args[1]
            if addonName == "HinterlandAffixHUD" then
                HLBG = HLBG or {}
                -- Record addon loaded successfully
                _G.HLBG_LoadState.addonLoaded = true
                
                -- Log addon loaded message to chat (use SafePrint if available and ensure numeric parts are stringified)
                if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                    local count = tostring(#(_G.HLBG_LoadState.files or {}))
                    if type(HLBG.SafePrint) == 'function' then
                        HLBG.SafePrint("|cFF00FF00HLBG:|r Addon loaded successfully. Files processed: " .. count)
                    else
                        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00HLBG:|r Addon loaded successfully. Files processed: " .. count)
                    end
                end

                -- Check for any C_Timer usage before compatibility layer
                self:UnregisterEvent("ADDON_LOADED")
            end
        elseif eventLocal == "LUA_ERROR" then
            local errorMessage = args[1]
            -- Record the error
            table.insert(_G.HLBG_LoadState.errors, errorMessage or "Unknown error")
            HLBG = HLBG or {}
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                local m = tostring(errorMessage or "Unknown error")
                if type(HLBG.SafePrint) == 'function' then
                    HLBG.SafePrint("|cFFFF0000HLBG Error:|r " .. m)
                else
                    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000HLBG Error:|r " .. m)
                end
            end
        end
    end)
    if not ok then
        -- Handler itself errored; persist the error to the global load-state so it can be inspected
        local e = tostring(err or 'unknown error in HLBG_LoadDebug.OnEvent')
        _G.HLBG_LoadState = _G.HLBG_LoadState or {}
        _G.HLBG_LoadState.errors = _G.HLBG_LoadState.errors or {}
        table.insert(_G.HLBG_LoadState.errors, "LoadHandlerError: " .. e)
        _G.HLBG_LoadState.lastHandlerError = e

        -- Try a minimal, non-failing notification: prefer SafePrint but don't rely on AddMessage
        pcall(function()
            if type(HLBG) == 'table' and type(HLBG.SafePrint) == 'function' then
                HLBG.SafePrint("HLBG Load handler recorded error; run /hlbgdiag for details")
            end
        end)
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
        HLBG = HLBG or {}
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            if type(HLBG.SafePrint) == 'function' then
                HLBG.SafePrint("|cFFFF0000HLBG Error:|r C_Timer not found! Compatibility layer might not be loaded properly.")
            else
                DEFAULT_CHAT_FRAME:AddMessage(tostring("|cFFFF0000HLBG Error:|r C_Timer not found! Compatibility layer might not be loaded properly."))
            end
        end
        
        -- Record error
        table.insert(_G.HLBG_LoadState.errors, "C_Timer not found at usage point")
        
        -- Return dummy functions to prevent errors
        return {
            After = function(seconds, callback)
                if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                    HLBG = HLBG or {}
                    if type(HLBG.SafePrint) == 'function' then
                        HLBG.SafePrint("|cFFFF0000HLBG Error:|r Attempted to use C_Timer.After when C_Timer is not available")
                    else
                        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000HLBG Error:|r Attempted to use C_Timer.After when C_Timer is not available")
                    end
                end
                return nil
            end,
            NewTimer = function(seconds, callback)
                if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                    HLBG = HLBG or {}
                    if type(HLBG.SafePrint) == 'function' then
                        HLBG.SafePrint("|cFFFF0000HLBG Error:|r Attempted to use C_Timer.NewTimer when C_Timer is not available")
                    else
                        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000HLBG Error:|r Attempted to use C_Timer.NewTimer when C_Timer is not available")
                    end
                end
                return { Cancel = function() end }
            end,
            NewTicker = function(seconds, callback, iterations)
                if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                    HLBG = HLBG or {}
                    if type(HLBG.SafePrint) == 'function' then
                        HLBG.SafePrint("|cFFFF0000HLBG Error:|r Attempted to use C_Timer.NewTicker when C_Timer is not available")
                    else
                        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000HLBG Error:|r Attempted to use C_Timer.NewTicker when C_Timer is not available")
                    end
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
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000HLBG Warning:|r First file loaded is " .. tostring(filename or "unknown") .. " but should be HLBG_TimerCompat.lua!")
        end
    end
end

-- Add diagnostic command
SLASH_HLBGDIAG1 = "/hlbgdiag"
SlashCmdList["HLBGDIAG"] = function(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[HLBG Diagnostics]|r")
        DEFAULT_CHAT_FRAME:AddMessage("Addon loaded: " .. (_G.HLBG_LoadState.addonLoaded and "Yes" or "No"))
    DEFAULT_CHAT_FRAME:AddMessage("Files loaded: " .. tostring(#(_G.HLBG_LoadState.files or {})))
        
        -- Show first 5 files loaded
        DEFAULT_CHAT_FRAME:AddMessage("First files loaded:")
        for i = 1, math.min(5, #(_G.HLBG_LoadState.files or {})) do
            DEFAULT_CHAT_FRAME:AddMessage("  " .. tostring(i) .. ". " .. tostring(_G.HLBG_LoadState.files[i] or "unknown"))
        end
        
        -- Show errors if any
        if #(_G.HLBG_LoadState.errors or {}) > 0 then
            HLBG = HLBG or {}
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                DEFAULT_CHAT_FRAME:AddMessage(tostring("Errors encountered: " .. tostring(#_G.HLBG_LoadState.errors)))
                for i = 1, math.min(5, #_G.HLBG_LoadState.errors) do
                    DEFAULT_CHAT_FRAME:AddMessage(tostring("  - " .. tostring(_G.HLBG_LoadState.errors[i] or "unknown")))
                end
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage(tostring("No errors recorded."))
        end

        -- Check C_Timer
        DEFAULT_CHAT_FRAME:AddMessage("C_Timer available: " .. (_G.C_Timer and "Yes" or "No"))
    end
end

-- Print a debug message so we know this file loaded
if DEFAULT_CHAT_FRAME then
    HLBG = HLBG or {}
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        if type(HLBG.SafePrint) == 'function' then
            HLBG.SafePrint("|cFF00FFFF[HLBG Load Debug]|r Debug module loaded, use /hlbgdiag for diagnostics")
        else
            DEFAULT_CHAT_FRAME:AddMessage(tostring("|cFF00FFFF[HLBG Load Debug]|r Debug module loaded, use /hlbgdiag for diagnostics"))
        end
    end
end

-- Record this file as loaded
_G.HLBG_RecordFileLoad("HLBG_LoadDebug.lua")