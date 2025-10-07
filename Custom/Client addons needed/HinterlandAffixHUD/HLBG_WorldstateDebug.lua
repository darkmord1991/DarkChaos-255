-- HLBG_WorldstateDebug.lua - Debug worldstate values f        elseif msg == "hud" then
        if HLBG.UpdateHUD then
            print("|cFF33FF99HLBG:|r Forcing HUD update...")
            HLBG.UpdateHUD()
        else
            print("|cFFFF0000HLBG:|r UpdateHUD function not found")
        end
    elseif msg == "stopblink" or msg == "notelemetry" then
        HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
        HinterlandAffixHUDDB.enableTelemetry = false
        print("|cFF33FF99HLBG:|r Telemetry disabled - this should stop HUD blinking")
        print("|cFF888888Use /reload to fully apply changes|r")
    elseleshooting

local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

-- Debug function to show all worldstates
function HLBG.ShowWorldstates()
    if not GetNumWorldStateUI then
        print("|cFFFF0000HLBG:|r GetNumWorldStateUI not available")
        return
    end
    
    local count = GetNumWorldStateUI()
    print("|cFF33FF99HLBG:|r Found " .. count .. " worldstates:")
    
    for i = 1, count do
        local text, value, a, b, c, id = GetWorldStateUIInfo(i)
        local idStr = id and string.format("0x%X (%d)", id, id) or "nil"
        print(string.format("|cFF33FF99%d:|r ID=%s Text='%s' Value=%s", 
            i, idStr, tostring(text or "nil"), tostring(value or "nil")))
    end
    
    -- Also show RES global
    local res = _G.RES
    if res then
        print("|cFF33FF99HLBG:|r _G.RES table:")
        for k, v in pairs(res) do
            print(string.format("  RES.%s = %s", tostring(k), tostring(v)))
        end
    else
        print("|cFF33FF99HLBG:|r _G.RES is nil")
    end
    
    -- Show HLBG._lastStatus
    if HLBG._lastStatus then
        print("|cFF33FF99HLBG:|r _lastStatus:")
        for k, v in pairs(HLBG._lastStatus) do
            print(string.format("  _lastStatus.%s = %s", tostring(k), tostring(v)))
        end
    else
        print("|cFF33FF99HLBG:|r _lastStatus is nil")
    end
end

-- Register debug command
SLASH_HLBGWS1 = "/hlbgws"
SlashCmdList["HLBGWS"] = function()
    HLBG.ShowWorldstates()
end

-- Register alternative command
SLASH_HLBGDEBUG1 = "/hlbgdebug"
SlashCmdList["HLBGDEBUG"] = function(msg)
    if msg == "ws" or msg == "worldstates" then
        HLBG.ShowWorldstates()
    elseif msg == "hud" then
        if HLBG.UpdateHUD then
            print("|cFF33FF99HLBG:|r Forcing HUD update...")
            HLBG.UpdateHUD()
        else
            print("|cFFFF0000HLBG:|r UpdateHUD function not found")
        end
    else
        print("|cFF33FF99HLBG Debug Commands:|r")
        print("  /hlbgdebug ws - Show all worldstates")
        print("  /hlbgdebug hud - Force HUD update")
        print("  /hlbgdebug stopblink - Disable telemetry to stop HUD blinking")
        print("  /hlbgws - Show all worldstates (shortcut)")
    end
end

print("|cFF33FF99HLBG:|r Worldstate debugging loaded. Use /hlbgws or /hlbgdebug ws")