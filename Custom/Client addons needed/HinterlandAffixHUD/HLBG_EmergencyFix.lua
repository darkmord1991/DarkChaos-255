-- HLBG_EmergencyFix.lua
-- Emergency compatibility fix to prevent "error in error handling"

-- Create the most basic HLBG namespace and SafePrint function first
_G.HLBG = _G.HLBG or {}

-- Ultra-safe print function that never fails
if not _G.HLBG.SafePrint then
    _G.HLBG.SafePrint = function(...)
        local args = {...}
        local message = ""
        for i = 1, #args do
            if args[i] ~= nil then
                message = message .. tostring(args[i]) .. " "
            else
                message = message .. "nil "
            end
        end
        
        -- Use the most basic approach possible
        if DEFAULT_CHAT_FRAME and type(DEFAULT_CHAT_FRAME.AddMessage) == "function" then
            -- Pcall to prevent any errors from crashing the load process
            local ok = pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, message)
            if not ok then
                -- If even that fails, use print as last resort
                print(message)
            end
        else
            print(message)
        end
    end
end

-- Simple diagnostic function
_G.HLBG.DiagnosticPrint = function(msg)
    msg = tostring(msg or "")
    if DEFAULT_CHAT_FRAME and type(DEFAULT_CHAT_FRAME.AddMessage) == "function" then
        pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "|cFFFF00FF[HLBG Diag]|r " .. msg)
    else
        print("[HLBG Diag] " .. msg)
    end
end

-- Log that this emergency fix loaded
_G.HLBG.DiagnosticPrint("Emergency fix loaded - SafePrint available")