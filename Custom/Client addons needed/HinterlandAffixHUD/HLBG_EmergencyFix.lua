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

-- Provide an extremely small PrintStartupHistory so users can run the diagnostic
-- even if later files haven't attached the full implementation yet.
if type(_G.HLBG.PrintStartupHistory) ~= 'function' then
    _G.HLBG.PrintStartupHistory = function(n)
        n = tonumber(n) or 1
        local hist = HinterlandAffixHUDDB and HinterlandAffixHUDDB.startupHistory
        if not hist or #hist == 0 then
            _G.HLBG.DiagnosticPrint('HLBG: no startup history saved')
            return
        end
        if n < 1 then n = 1 end
        if n > #hist then n = #hist end
        local e = hist[n]
        if not e then return end
        _G.HLBG.DiagnosticPrint(string.format('HLBG startup @ %s: AIO=%s handlers=%s ui=%s', date('%Y-%m-%d %H:%M:%S', e.ts), tostring(e.aio), tostring(e.handlers), tostring(e.ui)))
    end
end