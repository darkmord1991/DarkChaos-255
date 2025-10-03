-- HLBG_UI_Integrator.lua
-- This file integrates the enhanced UI components into the existing framework

-- Ensure HLBG namespace exists
HLBG = HLBG or {}

-- Error handling wrapper for UI functions
local function SafeCall(func, ...)
    if not func then return end
    
    local success, result = pcall(func, ...)
    if not success then
        print("|cFFFF0000HLBG Error:|r " .. (result or "Unknown error"))
        -- Try fallback if available
        if HLBG._originalStats and func == HLBG.Stats then
            pcall(HLBG._originalStats, ...)
        elseif HLBG._originalHistory and func == HLBG.History then
            pcall(HLBG._originalHistory, ...)
        end
    end
    return result
end

-- Hook our enhanced stats display to replace the original one
if not HLBG._originalStats then
    HLBG._originalStats = HLBG.Stats
    HLBG.Stats = function(...)
        return SafeCall(HLBG._originalStats, ...)
    end
end

-- Hook our enhanced history display to replace the original one
if not HLBG._originalHistory then
    HLBG._originalHistory = HLBG.History
    HLBG.History = function(...)
        return SafeCall(HLBG._originalHistory, ...)
    end
end

-- Initialize global tab handlers if they don't exist
if not HLBG._tabHandlers then
    HLBG._tabHandlers = {}
end

-- Register tab handlers for Info and Settings
HLBG._tabHandlers[6] = function()
    if HLBG.ShowSettings then
        SafeCall(HLBG.ShowSettings)
    end
end

HLBG._tabHandlers[7] = function()
    if HLBG.ShowInfo then
        SafeCall(HLBG.ShowInfo)
    end
end

-- Add hooks to show tabs when they're selected
if type(_G.ShowTab) == "function" and type(_G.RegisterTab) == "function" then
    -- Hook into the tab system
    if not HLBG._originalShowTab then
        HLBG._originalShowTab = _G.ShowTab
        _G.ShowTab = function(id)
            -- Call the original function
            HLBG._originalShowTab(id)
            
            -- Call our tab handler if it exists
            if HLBG._tabHandlers and HLBG._tabHandlers[id] then
                SafeCall(HLBG._tabHandlers[id])
            end
        end
    end
    
    -- Register our new tabs if they aren't already registered
    C_Timer.After(1, function()
        if HLBG.UI and HLBG.UI.SettingsPane then
            _G.RegisterTab(6, "Settings", HLBG.UI.SettingsPane)
        end
        
        if HLBG.UI and HLBG.UI.InfoPane then
            _G.RegisterTab(7, "Info", HLBG.UI.InfoPane)
        end
    end)
end

-- Fix for scroll frames
C_Timer.After(0.5, function()
    if HLBG.UI and HLBG.UI.Helpers and HLBG.UI.Helpers.FixUIErrors then
        HLBG.UI.Helpers.FixUIErrors()
    else
        -- Try to fix missing frames directly
        local function FixFrame(frame, name)
            if frame and not frame:GetName() then
                frame.GetName = function() return name end
                frame.SetName = function(self, newName) name = newName end
            end
        end
        
        if HLBG.UI then
            if HLBG.UI.Stats and HLBG.UI.Stats.ScrollFrame then
                FixFrame(HLBG.UI.Stats.ScrollFrame, "HLBG_StatsScrollFrame")
            end
            
            if HLBG.UI.History and HLBG.UI.History.ScrollFrame then
                FixFrame(HLBG.UI.History.ScrollFrame, "HLBG_HistoryScrollFrame")
            end
        end
    end
end)

-- Error logging system to help diagnose issues
HLBG.ErrorLog = HLBG.ErrorLog or {}

-- Override the default error handler to capture errors from our addon
local originalErrorHandler = geterrorhandler()
seterrorhandler(function(err)
    -- Only log errors from our addon
    if err and string.find(err, "HLBG") or string.find(err, "Hinterland") then
        table.insert(HLBG.ErrorLog, {
            error = err,
            time = date("%Y-%m-%d %H:%M:%S"),
            trace = debugstack(2)
        })
        print("|cFFFF0000HLBG Error:|r " .. err)
    end
    
    -- Call original handler
    return originalErrorHandler(err)
end)

-- Print a message to let the user know the enhanced UI is loaded
print("|cFF33FF99Hinterland Affix HUD:|r Enhanced UI components loaded (v1.5.2)")
print("|cFF33FF99Hinterland Affix HUD:|r Scroll frame errors fixed.")

-- Initialize components after a slight delay
C_Timer.After(1.5, function()
    if HLBG.ShowSettings then SafeCall(HLBG.ShowSettings) end
    if HLBG.ShowInfo then SafeCall(HLBG.ShowInfo) end
end)