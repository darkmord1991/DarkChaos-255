-- HLBG_DebugBootstrap_Safe.lua - Safer version without chat hooking

-- Ensure HLBG namespace exists
HLBG = HLBG or {}

-- Debug mode should be off by default (user can enable via /hlbg devmode on)
HLBG._devMode = false

-- Simple debug print function that doesn't hook anything
HLBG.DebugPrint = function(...)
    local args = {...}
    local message = ""
    for i=1, #args do
        message = message .. tostring(args[i]) .. " "
    end
    
    -- Use SafePrint if available, otherwise use basic print
    if type(HLBG.SafePrint) == 'function' then
        HLBG.SafePrint("|cFF88FFFFHLBG Debug:|r " .. message)
    elseif DEFAULT_CHAT_FRAME and type(DEFAULT_CHAT_FRAME.AddMessage) == "function" then
        pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "|cFF88FFFFHLBG Debug:|r " .. message)
    else
        print("|cFF88FFFFHLBG Debug:|r " .. message)
    end
end

-- Add a function to dump the current state for debugging
function HLBG.DumpState()
    HLBG.DebugPrint("=== HLBG Debug State Dump ===")
    HLBG.DebugPrint("Dev Mode:", HLBG._devMode)
    
    -- Affix info
    HLBG.DebugPrint("Current affix:", HLBG._affixText)
    HLBG.DebugPrint("Current affix ID:", HLBG._currentAffixID)
    
    -- UI info
    HLBG.DebugPrint("UI initialized:", HLBG.UI and "yes" or "no")
    if HLBG.UI then
        HLBG.DebugPrint("UI components:")
        HLBG.DebugPrint("  HUD:", HLBG.UI.HUD and "yes" or "no")
        HLBG.DebugPrint("  History:", HLBG.UI.History and "yes" or "no")
        HLBG.DebugPrint("  Stats:", HLBG.UI.Stats and "yes" or "no")
        HLBG.DebugPrint("  Frame visible:", HLBG.UI.Frame and HLBG.UI.Frame:IsShown() and "yes" or "no")
    end
    
    HLBG.DebugPrint("=== End of Debug Dump ===")
end

-- Register slash command for debug
SLASH_HLBGDEBUG1 = "/hlbgdebug"
SlashCmdList["HLBGDEBUG"] = function(msg)
    msg = msg or ""
    if msg:match("^help") then
        HLBG.DebugPrint("HLBG Debug Commands:")
        HLBG.DebugPrint("/hlbgdebug dump - Dump current state")
        HLBG.DebugPrint("/hlbgdebug test - Test basic functions")
    elseif msg:match("^dump") then
        HLBG.DumpState()
    elseif msg:match("^test") then
        HLBG.DebugPrint("Basic test successful - debug system working")
    else
        HLBG.DebugPrint("Unknown debug command. Try /hlbgdebug help")
    end
end

HLBG.DebugPrint("Debug bootstrap loaded (safe version)")