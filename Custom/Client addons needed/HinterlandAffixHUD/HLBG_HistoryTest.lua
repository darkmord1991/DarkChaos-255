-- HLBG History Test - Force history data with sample data
local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

-- Add a test command to force history data
SLASH_HLBGTEST1 = '/hlbgtest'
function SlashCmdList.HLBGTEST(msg)
    DEFAULT_CHAT_FRAME:AddMessage('|cFF00FF00=== HLBG History Test ===|r')
    
    -- Check if History function exists
    if type(HLBG.History) ~= 'function' then
        DEFAULT_CHAT_FRAME:AddMessage('|cFFFF0000ERROR:|r HLBG.History function not found!')
        return
    end
    
    -- Create sample history data
    local sampleData = {
        {id=46, season=1, seasonName="Season 1: Chaos Reborn", ts=1728330344, winner="Draw", affix=0, reason="manual"},
        {id=45, season=1, seasonName="Season 1: Chaos Reborn", ts=1728324638, winner="Draw", affix=0, reason="manual"},
        {id=44, season=1, seasonName="Season 1: Chaos Reborn", ts=1728324638, winner="Draw", affix=0, reason="manual"},
        {id=43, season=1, seasonName="Season 1: Chaos Reborn", ts=1728298589, winner="Draw", affix=0, reason="manual"}
    }
    
    DEFAULT_CHAT_FRAME:AddMessage(string.format('|cFF33FF99HLBG Test:|r Calling HLBG.History with %d sample rows', #sampleData))
    
    -- Call the History function directly
    HLBG.History(sampleData, 1, 15, #sampleData, 'id', 'DESC')
    
    DEFAULT_CHAT_FRAME:AddMessage('|cFF00FF00HLBG Test:|r History function called - check History tab!')
end

-- Add a command to check cache state
SLASH_HLBGCACHE1 = '/hlbgcache'
function SlashCmdList.HLBGCACHE(msg)
    DEFAULT_CHAT_FRAME:AddMessage('|cFF00FF00=== HLBG Cache Check ===|r')
    if HLBG.UI and HLBG.UI.History then
        local lastRows = HLBG.UI.History.lastRows or {}
        DEFAULT_CHAT_FRAME:AddMessage(string.format('lastRows count: %d', #lastRows))
        DEFAULT_CHAT_FRAME:AddMessage(string.format('page: %s', tostring(HLBG.UI.History.page)))
        DEFAULT_CHAT_FRAME:AddMessage(string.format('per: %s', tostring(HLBG.UI.History.per)))
        DEFAULT_CHAT_FRAME:AddMessage(string.format('total: %s', tostring(HLBG.UI.History.total)))
    else
        DEFAULT_CHAT_FRAME:AddMessage('|cFFFF0000ERROR:|r HLBG.UI.History not found!')
    end
end

-- Add command to force show the main frame
SLASH_HLBGSHOW1 = '/hlbgshow'
function SlashCmdList.HLBGSHOW(msg)
    DEFAULT_CHAT_FRAME:AddMessage('|cFF00FF00=== Force Show Frame + Structure Check ===|r')
    if HLBG.UI and HLBG.UI.Frame then
        HLBG.UI.Frame:Show()
        DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG:|r Main frame forced to show')
        -- Also show History tab
        if HLBG.UI.History then
            HLBG.UI.History:Show()
            DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG:|r History tab shown')
            
            -- Check UI structure
            local hist = HLBG.UI.History
            DEFAULT_CHAT_FRAME:AddMessage(string.format('History shown: %s', hist:IsShown() and 'YES' or 'NO'))
            
            if hist.Content then
                DEFAULT_CHAT_FRAME:AddMessage('Content frame: EXISTS')
                DEFAULT_CHAT_FRAME:AddMessage(string.format('Content shown: %s', hist.Content:IsShown() and 'YES' or 'NO'))
                DEFAULT_CHAT_FRAME:AddMessage(string.format('Content size: %.0fx%.0f', hist.Content:GetWidth() or 0, hist.Content:GetHeight() or 0))
            else
                DEFAULT_CHAT_FRAME:AddMessage('Content frame: MISSING!')
            end
            
            if hist.rows then
                DEFAULT_CHAT_FRAME:AddMessage(string.format('History rows array: %d elements', #hist.rows))
                for i = 1, math.min(3, #hist.rows) do
                    local r = hist.rows[i]
                    if r then
                        DEFAULT_CHAT_FRAME:AddMessage(string.format('  Row %d: shown=%s', i, r:IsShown() and 'YES' or 'NO'))
                    end
                end
            else
                DEFAULT_CHAT_FRAME:AddMessage('History rows: MISSING!')
            end
        end
        -- Call ShowTab to properly set tab 1
        if type(ShowTab) == 'function' then
            ShowTab(1)
            DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG:|r ShowTab(1) called')
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage('|cFFFF0000ERROR:|r HLBG.UI.Frame not found!')
    end
end

