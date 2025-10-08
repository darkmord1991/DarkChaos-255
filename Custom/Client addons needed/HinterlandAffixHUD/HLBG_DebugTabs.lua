-- HLBG UI Tab Debug Helper
local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

-- Command to inspect UI tab states and rendered content
SLASH_HLBGTABS1 = '/hlbgtabs'
function SlashCmdList.HLBGTABS(msg)
    DEFAULT_CHAT_FRAME:AddMessage('|cFF00FF00=== HLBG Tab Debug ===|r')
    
    if not (HLBG.UI and HLBG.UI.Frame) then
        DEFAULT_CHAT_FRAME:AddMessage('Main UI not found!')
        return
    end
    
    -- Check main frame
    DEFAULT_CHAT_FRAME:AddMessage('Main Frame shown: ' .. (HLBG.UI.Frame:IsShown() and 'YES' or 'NO'))
    
    -- Check tab states
    local tabs = {'History', 'Stats', 'Info', 'Settings', 'Queue'}
    for i, tabName in ipairs(tabs) do
        local tab = HLBG.UI[tabName]
        if tab then
            local shown = tab:IsShown() and 'SHOWN' or 'HIDDEN'
            DEFAULT_CHAT_FRAME:AddMessage(tabName .. ' tab: EXISTS, ' .. shown)
            
            -- Check for content
            if tabName == 'History' and tab.rows then
                local visibleRows = 0
                for j = 1, #tab.rows do
                    if tab.rows[j] and tab.rows[j]:IsShown() then
                        visibleRows = visibleRows + 1
                    end
                end
                DEFAULT_CHAT_FRAME:AddMessage('  History visible rows: ' .. visibleRows .. '/' .. #tab.rows)
                DEFAULT_CHAT_FRAME:AddMessage('  History lastRows: ' .. #(tab.lastRows or {}))
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage(tabName .. ' tab: MISSING')
        end
    end
    
    -- Check current active tab
    if HLBG.UI.activeTab then
        DEFAULT_CHAT_FRAME:AddMessage('Active tab: ' .. tostring(HLBG.UI.activeTab))
    else
        DEFAULT_CHAT_FRAME:AddMessage('No active tab set')
    end
    
    DEFAULT_CHAT_FRAME:AddMessage('=======================')
end

-- Command to force refresh current tab
SLASH_HLBGREFRESH2 = '/hlbgtabrefresh'
function SlashCmdList.HLBGREFRESH2(msg)
    DEFAULT_CHAT_FRAME:AddMessage('|cFF00FF00HLBG:|r Force refreshing current tab...')
    
    -- Try to refresh history specifically
    if HLBG.UI and HLBG.UI.History and HLBG.UI.History.lastRows then
        DEFAULT_CHAT_FRAME:AddMessage('Found History.lastRows: ' .. #HLBG.UI.History.lastRows .. ' items')
        if #HLBG.UI.History.lastRows > 0 then
            DEFAULT_CHAT_FRAME:AddMessage('Re-calling HLBG.History with stored data...')
            if HLBG.History then
                local success, err = pcall(HLBG.History, HLBG.UI.History.lastRows, 
                    HLBG.UI.History.page or 1, 
                    HLBG.UI.History.per or 15, 
                    HLBG.UI.History.total or #HLBG.UI.History.lastRows)
                if success then
                    DEFAULT_CHAT_FRAME:AddMessage('✓ History refresh succeeded')
                else
                    DEFAULT_CHAT_FRAME:AddMessage('✗ History refresh failed: ' .. tostring(err))
                end
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage('No stored history data to refresh')
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage('No History UI or lastRows found')
    end
    
    -- Force show History tab
    if HLBG.UI and HLBG.UI.History then
        HLBG.UI.History:Show()
        DEFAULT_CHAT_FRAME:AddMessage('History tab forced to show')
    end
end