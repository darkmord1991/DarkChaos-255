-- HLBG_DC_Handler.lua
-- Registers handlers for DCAddonProtocol messages for Hinterland BG

local HLBG = _G.HLBG or {}; _G.HLBG = HLBG

local function RegisterDCHandlers()
    local DC = _G.DCAddonProtocol
    if not DC then return end

    if HLBG._dcHandlersRegistered then return end
    
    -- SMSG_QUEUE_UPDATE = 19 (0x13)
    DC:RegisterHandler("HLBG", 19, function(queueStatus, position, estimatedTime, totalQueued, allianceQueued, hordeQueued, minPlayers, state)
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
f:SetScript("OnEvent", function(self, event, addon)
    if addon == "DC-AddonProtocol" then
        RegisterDCHandlers()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
