-- HLBG Debug UI checker
local HLBG = _G.HLBG or {}; _G.HLBG = HLBG
-- Add a debug command to check UI state
SLASH_HLBGUI1 = '/hlbgui'
function SlashCmdList.HLBGUI(msg)
    DEFAULT_CHAT_FRAME:AddMessage('|cFF00FF00=== HLBG UI Debug ===|r')
    DEFAULT_CHAT_FRAME:AddMessage('HLBG exists: ' .. (HLBG and 'YES' or 'NO'))
    DEFAULT_CHAT_FRAME:AddMessage('HLBG.UI exists: ' .. (HLBG.UI and 'YES' or 'NO'))
    if HLBG.UI then
        DEFAULT_CHAT_FRAME:AddMessage('HLBG.UI.Frame exists: ' .. (HLBG.UI.Frame and 'YES' or 'NO'))
        if HLBG.UI.Frame then
            DEFAULT_CHAT_FRAME:AddMessage('Frame shown: ' .. (HLBG.UI.Frame:IsShown() and 'YES' or 'NO'))
        end
        DEFAULT_CHAT_FRAME:AddMessage('HLBG.UI.History exists: ' .. (HLBG.UI.History and 'YES' or 'NO'))
        if HLBG.UI.History then
            DEFAULT_CHAT_FRAME:AddMessage('History Content exists: ' .. (HLBG.UI.History.Content and 'YES' or 'NO'))
            DEFAULT_CHAT_FRAME:AddMessage('History lastRows: ' .. (#(HLBG.UI.History.lastRows or {}) .. ' rows'))
            DEFAULT_CHAT_FRAME:AddMessage('History rows elements: ' .. (#(HLBG.UI.History.rows or {}) .. ' elements'))
        end
    end
    DEFAULT_CHAT_FRAME:AddMessage('HLBG.History function: ' .. type(HLBG.History or 'nil'))
    DEFAULT_CHAT_FRAME:AddMessage('======================')
end
-- Add a command to force show UI
SLASH_HLBGSHOW1 = '/hlbgshow'
function SlashCmdList.HLBGSHOW(msg)
    if HLBG and HLBG.UI and HLBG.UI.Frame then
        HLBG.UI.Frame:Show()
        if ShowTab then ShowTab(1) end
        DEFAULT_CHAT_FRAME:AddMessage('|cFF00FF00HLBG UI forced to show|r')
    else
        DEFAULT_CHAT_FRAME:AddMessage('|cFFFF0000HLBG UI not available|r')
    end
end
-- Add a command to check row positioning
SLASH_HLBGROWS1 = '/hlbgrows'
function SlashCmdList.HLBGROWS(msg)
    DEFAULT_CHAT_FRAME:AddMessage('|cFF00FF00=== HLBG Row Debug ===|r')
    if HLBG and HLBG.UI and HLBG.UI.History and HLBG.UI.History.rows then
        DEFAULT_CHAT_FRAME:AddMessage('History rows count: ' .. #HLBG.UI.History.rows)
        for i = 1, math.min(3, #HLBG.UI.History.rows) do
            local row = HLBG.UI.History.rows[i]
            if row then
                local point, relativeTo, relativePoint, x, y = row:GetPoint(1)
                DEFAULT_CHAT_FRAME:AddMessage(string.format('Row %d: %s at %.0f,%.0f (shown=%s)', i, point or 'nil', x or 0, y or 0, tostring(row:IsShown())))
            end
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage('No History rows available')
    end
    DEFAULT_CHAT_FRAME:AddMessage('======================')
end
-- Add a test history command
SLASH_HLBGTEST1 = '/hlbgtest'
function SlashCmdList.HLBGTEST(msg)
    DEFAULT_CHAT_FRAME:AddMessage('|cFFFF8800Testing History with fake data...|r')
    -- Create fake history data
    local testRows = {
        {id=1, season=1, seasonName="Season 1: Chaos Reborn", ts="2025-10-07 20:05:44", winner="Draw", affix=0, reason="manual"},
        {id=2, season=1, seasonName="Season 1: Chaos Reborn", ts="2025-10-07 18:30:38", winner="Horde", affix=0, reason="manual"},
        {id=3, season=1, seasonName="Season 1: Chaos Reborn", ts="2025-10-07 09:26:29", winner="Alliance", affix=3, reason="manual"}
    }
    -- Call HLBG.History directly
    if HLBG and HLBG.History then
        HLBG.History(testRows, 1, 15, 3, 'id', 'DESC')
        -- Force show the UI and History tab
        if HLBG.UI and HLBG.UI.Frame then
            HLBG.UI.Frame:Show()
            if ShowTab then ShowTab(1) end
        end
        DEFAULT_CHAT_FRAME:AddMessage('|cFFFF8800Test complete - UI should be visible with History tab|r')
    else
        DEFAULT_CHAT_FRAME:AddMessage('|cFFFF0000Error: HLBG.History function not found!|r')
    end
end
-- Command to show main UI
SLASH_HLBGSHOWUI1 = '/hlbgshowui'
function SlashCmdList.HLBGSHOWUI(msg)
    if HLBG.UI and HLBG.UI.Frame then
        HLBG.UI.Frame:Show()
        -- Also refresh the current tab with any stored data
        if HLBG.UI.History and HLBG.UI.History.lastRows and #HLBG.UI.History.lastRows > 0 then
            DEFAULT_CHAT_FRAME:AddMessage('Refreshing History with ' .. #HLBG.UI.History.lastRows .. ' stored rows...')
            if HLBG.History then
                pcall(HLBG.History, HLBG.UI.History.lastRows, 1, 15, #HLBG.UI.History.lastRows)
            end
        end
        DEFAULT_CHAT_FRAME:AddMessage('|cFF00FF00HLBG:|r Main UI shown!')
    else
        DEFAULT_CHAT_FRAME:AddMessage('|cFFFF0000HLBG:|r Main UI not found!')
    end
end

