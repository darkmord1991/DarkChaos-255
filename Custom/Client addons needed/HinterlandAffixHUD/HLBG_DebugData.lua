-- HLBG Debug Data Commands
-- Comprehensive data flow debugging

SLASH_HLBGDATA1 = '/hlbgdata'
function SlashCmdList.HLBGDATA(msg)
    DEFAULT_CHAT_FRAME:AddMessage('|cFFFF9900=== HLBG Data Debug ===|r')
    
    -- Check AIO connectivity
    DEFAULT_CHAT_FRAME:AddMessage('AIO Available: ' .. ((_G.AIO and 'YES') or 'NO'))
    if _G.AIO then
        DEFAULT_CHAT_FRAME:AddMessage('AIO Version: ' .. ((_G.AIO.version and tostring(_G.AIO.version)) or 'Unknown'))
    end
    
    -- Check data cache
    DEFAULT_CHAT_FRAME:AddMessage('History Cache: ' .. ((HLBG and HLBG.UI and HLBG.UI.History and HLBG.UI.History.lastRows and #HLBG.UI.History.lastRows > 0 and tostring(#HLBG.UI.History.lastRows) .. ' rows') or 'EMPTY'))
    DEFAULT_CHAT_FRAME:AddMessage('Stats Cache: ' .. ((HLBG and HLBG._statsData and 'EXISTS') or 'EMPTY'))
    
    -- Check worldstates (using correct server worldstate IDs)
    local wsAlliance = GetWorldStateUIInfo(3680) -- WORLD_STATE_BATTLEFIELD_WG_VEHICLE_A
    local wsHorde = GetWorldStateUIInfo(3490) -- WORLD_STATE_BATTLEFIELD_WG_VEHICLE_H
    local wsTime = GetWorldStateUIInfo(3781) -- WORLD_STATE_BATTLEFIELD_WG_CLOCK
    
    DEFAULT_CHAT_FRAME:AddMessage('WS Alliance: ' .. (wsAlliance or 'nil'))
    DEFAULT_CHAT_FRAME:AddMessage('WS Horde: ' .. (wsHorde or 'nil'))
    DEFAULT_CHAT_FRAME:AddMessage('WS Time: ' .. (wsTime or 'nil'))
    
    -- Check HUD state (check both HLBG.HUD and HLBG.UI.ModernHUD)
    if HLBG and HLBG.UI and HLBG.UI.ModernHUD then
        DEFAULT_CHAT_FRAME:AddMessage('HUD Frame: EXISTS (HLBG.UI.ModernHUD)')
        DEFAULT_CHAT_FRAME:AddMessage('HUD Visible: ' .. (HLBG.UI.ModernHUD:IsShown() and 'YES' or 'NO'))
        DEFAULT_CHAT_FRAME:AddMessage('HUD Enabled: ' .. ((HinterlandAffixHUDDB and HinterlandAffixHUDDB.hudEnabled) and 'YES' or 'NO'))
        DEFAULT_CHAT_FRAME:AddMessage('HUD Position: ' .. (HinterlandAffixHUDDB and HinterlandAffixHUDDB.hudPosition and 'SAVED' or 'DEFAULT'))
    elseif HLBG and HLBG.HUD then
        DEFAULT_CHAT_FRAME:AddMessage('HUD Frame: EXISTS (HLBG.HUD)')
        DEFAULT_CHAT_FRAME:AddMessage('HUD Visible: ' .. ((HLBG.HUD.frame and HLBG.HUD.frame:IsShown()) and 'YES' or 'NO'))
        DEFAULT_CHAT_FRAME:AddMessage('HUD Enabled: ' .. ((HLBG.HUD.enabled) and 'YES' or 'NO'))
    else
        DEFAULT_CHAT_FRAME:AddMessage('HUD Object: MISSING (both HLBG.HUD and HLBG.UI.ModernHUD)')
    end
end

SLASH_HLBGFORCE1 = '/hlbgforce'
function SlashCmdList.HLBGFORCE(msg)
    DEFAULT_CHAT_FRAME:AddMessage('|cFFFF9900=== HLBG Force Refresh ===|r')
    
    -- Force request fresh data from server
    if _G.AIO and _G.AIO.Handle then
        DEFAULT_CHAT_FRAME:AddMessage('Sending AIO requests...')
        _G.AIO.Handle("HLBG", "Request", "HISTORY", 1, 15, "id", "DESC")
        _G.AIO.Handle("HLBG", "Request", "STATS")
        _G.AIO.Handle("HLBG", "Request", "STATUS")
        DEFAULT_CHAT_FRAME:AddMessage('AIO requests sent!')
    else
        DEFAULT_CHAT_FRAME:AddMessage('AIO not available - cannot request data')
    end
    
    -- Force HUD update (try multiple methods)
    if HLBG and HLBG.UI and HLBG.UI.ModernHUD and HLBG.UI.ModernHUD.Update then
        pcall(HLBG.UI.ModernHUD.Update, HLBG.UI.ModernHUD)
        DEFAULT_CHAT_FRAME:AddMessage('Modern HUD update triggered')
    elseif HLBG and HLBG.HUD and HLBG.HUD.Update then
        pcall(HLBG.HUD.Update, HLBG.HUD)
        DEFAULT_CHAT_FRAME:AddMessage('Legacy HUD update triggered')
    else
        DEFAULT_CHAT_FRAME:AddMessage('No HUD update function found')
    end
    
    -- Force worldstate check
    if HLBG and HLBG.CheckWorldStates then
        pcall(HLBG.CheckWorldStates)
        DEFAULT_CHAT_FRAME:AddMessage('Worldstate check triggered')
    end
    
    -- Force show HUD if it exists
    if HLBG and HLBG.UI and HLBG.UI.ModernHUD then
        HLBG.UI.ModernHUD:Show()
        DEFAULT_CHAT_FRAME:AddMessage('Modern HUD visibility forced ON')
    end
end

SLASH_HLBGWS1 = '/hlbgws'
function SlashCmdList.HLBGWS(msg)
    DEFAULT_CHAT_FRAME:AddMessage('|cFFFF9900=== Worldstate Debug ===|r')
    
    -- Check all known worldstates with correct server IDs
    local wsIds = {
        [3680] = 'Alliance_Resources',
        [3490] = 'Horde_Resources',
        [3781] = 'Clock_Time',
        [4354] = 'Clock_Text',
        [3674] = 'WG_Active',
        [3695] = 'Affix_ID',
        [14491664] = 'Old_Affix_WS', -- 0xDD1010 from old HUD
        [5] = 'Possible_BG_State' -- This one had value 3
    }
    
    -- Check specific known worldstates
    for wsId, name in pairs(wsIds) do
        local info = GetWorldStateUIInfo(wsId)
        if info and info ~= "" then
            DEFAULT_CHAT_FRAME:AddMessage(name .. ' (' .. wsId .. '): ' .. tostring(info))
        end
    end
    
    -- Also scan first 50 worldstates to see what's available
    DEFAULT_CHAT_FRAME:AddMessage('--- All Available Worldstates ---')
    for i = 1, 50 do
        local info = GetWorldStateUIInfo(i)
        if info and info ~= "" and info ~= "0" then
            local name = wsIds[i] or ('Unknown_WS_' .. i)
            DEFAULT_CHAT_FRAME:AddMessage(name .. ': ' .. tostring(info))
        end
    end
end

SLASH_HLBGSERVER1 = '/hlbgserver'
function SlashCmdList.HLBGSERVER(msg)
    DEFAULT_CHAT_FRAME:AddMessage('|cFFFF9900=== Server State Check ===|r')
    
    -- Check if we're in Hinterlands
    local zoneName = GetRealZoneText and GetRealZoneText() or "Unknown"
    DEFAULT_CHAT_FRAME:AddMessage('Current Zone: ' .. zoneName)
    DEFAULT_CHAT_FRAME:AddMessage('In Hinterlands: ' .. ((zoneName == "The Hinterlands") and 'YES' or 'NO'))
    
    -- Try to get server status via chat command
    DEFAULT_CHAT_FRAME:AddMessage('Requesting server status...')
    SendChatMessage('.hlbg status', 'GUILD')
    
    -- Also check if there are any players in BG
    DEFAULT_CHAT_FRAME:AddMessage('Player count unknown (server-side data)')
    
    -- Check the important WS_5 that had value 3
    local ws5 = GetWorldStateUIInfo(5)
    DEFAULT_CHAT_FRAME:AddMessage('WS_5 (possible BG state): ' .. (ws5 or 'nil'))
end

SLASH_HLBGSETTINGS1 = '/hlbgsettingsfix'
function SlashCmdList.HLBGSETTINGSFIX(msg)
    DEFAULT_CHAT_FRAME:AddMessage('|cFFFF9900=== Settings Tab Fix ===|r')
    
    if HLBG and HLBG.UI and HLBG.UI.Settings then
        -- Check if Settings text is properly set
        if HLBG.UI.Settings.Text then
            local text = HLBG.UI.Settings.Text:GetText()
            DEFAULT_CHAT_FRAME:AddMessage('Settings text length: ' .. (text and string.len(text) or 0))
            
            -- Force re-create settings content
            HLBG.UI.Settings.Text:SetText(
                "|cFFFFAA33Settings & Configuration|r\n\n" ..
                "|cFF33FF99HUD Settings:|r\n" ..
                "• Modern HUD is enabled by default\n" ..
                "• Drag the HUD to reposition it\n" ..
                "• HUD automatically syncs with server worldstates\n\n" ..
                "|cFF33FF99Display Options:|r\n" ..
                "• Modern UI theme active\n" ..
                "• Enhanced error handling enabled\n" ..
                "• Auto-fallback data when server unavailable\n\n" ..
                "|cFF33FF99Debug Commands:|r\n" ..
                "• /hlbgws - Show worldstate debugging\n" ..
                "• /hlbgdata - Check data flow\n" ..
                "• /hlbgforce - Force refresh all data\n" ..
                "• /hlbg reload - Reload UI components\n\n" ..
                "|cFF888888Use '/hlbg help' for all commands.|r"
            )
            DEFAULT_CHAT_FRAME:AddMessage('Settings text refreshed!')
        else
            DEFAULT_CHAT_FRAME:AddMessage('Settings.Text missing!')
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage('Settings frame missing!')
    end
end