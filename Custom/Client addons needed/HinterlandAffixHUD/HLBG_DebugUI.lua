-- HLBG Debug UI checker
local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

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