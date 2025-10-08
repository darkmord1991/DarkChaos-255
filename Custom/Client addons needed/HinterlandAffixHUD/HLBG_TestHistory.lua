-- HLBG History Test Command
local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

-- Add a command to manually trigger history with test data
SLASH_HLBGTEST1 = '/hlbgtest'
function SlashCmdList.HLBGTEST(msg)
    DEFAULT_CHAT_FRAME:AddMessage('|cFF00FF00=== Testing History Function ===|r')
    
    -- Create some test data
    local testRows = {
        {id = 46, season = 1, seasonName = "Season 1: Chaos Reborn", ts = "2025-10-07 20:05:44", winner = "Draw", affix = 0, reason = "manual"},
        {id = 45, season = 1, seasonName = "Season 1: Chaos Reborn", ts = "2025-10-07 18:30:38", winner = "Draw", affix = 0, reason = "manual"},
        {id = 44, season = 1, seasonName = "Season 1: Chaos Reborn", ts = "2025-10-07 18:30:38", winner = "Draw", affix = 0, reason = "manual"}
    }
    
    DEFAULT_CHAT_FRAME:AddMessage('Test data created: ' .. #testRows .. ' rows')
    DEFAULT_CHAT_FRAME:AddMessage('HLBG.History exists: ' .. tostring(HLBG.History ~= nil))
    
    if HLBG.History then
        DEFAULT_CHAT_FRAME:AddMessage('Calling HLBG.History...')
        local success, err = pcall(HLBG.History, testRows, 1, 15, #testRows, 'id', 'DESC')
        if success then
            DEFAULT_CHAT_FRAME:AddMessage('HLBG.History call succeeded!')
        else
            DEFAULT_CHAT_FRAME:AddMessage('HLBG.History call failed: ' .. tostring(err))
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage('HLBG.History function not found!')
    end
    
    DEFAULT_CHAT_FRAME:AddMessage('===========================')
end

-- Command to manually test parsing chat history format
SLASH_HLBGPARSE1 = '/hlbgparse'
function SlashCmdList.HLBGPARSE(msg)
    DEFAULT_CHAT_FRAME:AddMessage('|cFF00FF00=== Testing Chat History Parser ===|r')
    
    -- Sample chat data from the server output
    local chatHistory = {
        "  [2025-10-07 20:05:44] Draw  A:450 H:450  (manual)",
        "  [2025-10-07 18:30:38] Draw  A:450 H:450  (manual)",
        "  [2025-10-07 09:26:29] Draw  A:450 H:450  (manual)"
    }
    
    DEFAULT_CHAT_FRAME:AddMessage('Sample data: ' .. #chatHistory .. ' lines')
    
    -- Try to parse these lines into the expected format
    local parsedRows = {}
    for i, line in ipairs(chatHistory) do
        DEFAULT_CHAT_FRAME:AddMessage('Parsing: ' .. line)
        
        -- Try to extract: timestamp, winner, alliance score, horde score, reason
        local timestamp, winner, aScore, hScore, reason = line:match('%[([^%]]+)%]%s+(%w+)%s+A:(%d+)%s+H:(%d+)%s+%(([^%)]+)%)')
        if timestamp then
            table.insert(parsedRows, {
                id = 46 - i + 1,  -- Mock ID
                ts = timestamp,
                winner = winner,
                ally_score = tonumber(aScore),
                horde_score = tonumber(hScore),
                reason = reason,
                season = 1,
                seasonName = "Season 1: Chaos Reborn"
            })
            DEFAULT_CHAT_FRAME:AddMessage('  ✓ Parsed: ID=' .. (46-i+1) .. ', Winner=' .. winner .. ', A=' .. aScore .. ', H=' .. hScore)
        else
            DEFAULT_CHAT_FRAME:AddMessage('  ✗ Failed to parse')
        end
    end
    
    DEFAULT_CHAT_FRAME:AddMessage('Successfully parsed: ' .. #parsedRows .. ' rows')
    
    -- Try to call History with parsed data
    if #parsedRows > 0 and HLBG.History then
        DEFAULT_CHAT_FRAME:AddMessage('Calling HLBG.History with parsed chat data...')
        local success, err = pcall(HLBG.History, parsedRows, 1, 15, #parsedRows, 'id', 'DESC')
        if success then
            DEFAULT_CHAT_FRAME:AddMessage('|cFF00FF00✓ History call succeeded!|r')
        else
            DEFAULT_CHAT_FRAME:AddMessage('|cFFFF0000✗ History call failed:|r ' .. tostring(err))
        end
    end
    
    DEFAULT_CHAT_FRAME:AddMessage('===================================')
end