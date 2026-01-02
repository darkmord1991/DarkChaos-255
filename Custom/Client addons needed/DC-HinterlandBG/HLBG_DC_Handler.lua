-- HLBG_DC_Handler.lua
-- Registers handlers for DCAddonProtocol messages for Hinterland BG

local HLBG = _G.HLBG or {}; _G.HLBG = HLBG

local function RegisterDCHandlers()
    local DC = _G.DCAddonProtocol
    if not DC then 
        if DEFAULT_CHAT_FRAME and (HLBG._devMode or (DCHLBGDB and DCHLBGDB.devMode)) then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000HLBG Error:|r DCAddonProtocol not found. Handlers not registered.")
        end
        return 
    end

    if HLBG._dcHandlersRegistered then return end
    
    -- SMSG_QUEUE_UPDATE = 19 (0x13)
    DC:RegisterHandler("HLBG", 19, function(queueStatus, position, estimatedTime, totalQueued, allianceQueued, hordeQueued, minPlayers, state)
        if DEFAULT_CHAT_FRAME and (HLBG._devMode or (DCHLBGDB and DCHLBGDB.devMode)) then
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFF00FF00HLBG DC Handler:|r QUEUE_UPDATE received (op 19): queueStatus=%s, pos=%s, total=%s",
                tostring(queueStatus), tostring(position), tostring(totalQueued)))
        end
        
        if HLBG.HandleQueueStatusRaw and type(HLBG.HandleQueueStatusRaw) == "function" then
            HLBG.HandleQueueStatusRaw(
                queueStatus,
                position,
                estimatedTime,
                totalQueued,
                allianceQueued,
                hordeQueued,
                minPlayers,
                state
            )
        else
            -- Fallback or wait for load
            if DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000HLBG Error:|r Queue status received but HandleQueueStatusRaw not found.")
            end
        end
    end)
    
    -- SMSG_HISTORY_TSV = 51 (0x33) - Deprecated (history UI moved to DC-Leaderboards)
    DC:RegisterHandler("HLBG", 51, function(...)
        if DEFAULT_CHAT_FRAME and (HLBG._devMode or (DCHLBGDB and DCHLBGDB.devMode)) then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFAA00HLBG:|r Ignoring HISTORY_TSV (deprecated; use /leaderboard).")
        end
    end)
    
    HLBG._dcHandlersRegistered = true
    if DEFAULT_CHAT_FRAME and (HLBG._devMode or (DCHLBGDB and DCHLBGDB.devMode)) then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00HLBG:|r DCAddonProtocol handlers registered.")
    end
end

-- Try to register immediately if DC is loaded
RegisterDCHandlers()

-- Also watch for ADDON_LOADED in case DC loads later
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self, event, addon)
    if event == "ADDON_LOADED" and (addon == "DCAddonProtocol" or addon == "DC-AddonProtocol") then
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99HLBG:|r DCAddonProtocol loaded, registering handlers...")
        end
        RegisterDCHandlers()
    elseif event == "PLAYER_LOGIN" then
        -- Final attempt at player login
        C_Timer.After(1, function()
            RegisterDCHandlers()
        end)
    end
end)

