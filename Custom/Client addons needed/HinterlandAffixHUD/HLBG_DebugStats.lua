-- HLBG Stats Debug Commands
local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

-- Command to check stats data source
SLASH_HLBGSTATS1 = '/hlbgstats'  
function SlashCmdList.HLBGSTATS(msg)
    DEFAULT_CHAT_FRAME:AddMessage('|cFF00FF00=== HLBG Stats Debug ===|r')
    
    -- Check if we have any local/cached stats data
    if HinterlandAffixHUD_LastStats then
        DEFAULT_CHAT_FRAME:AddMessage('Local cached stats found:')
        if HinterlandAffixHUD_LastStats.counts then
            local counts = HinterlandAffixHUD_LastStats.counts
            DEFAULT_CHAT_FRAME:AddMessage('  Alliance: ' .. (counts.Alliance or 0))  
            DEFAULT_CHAT_FRAME:AddMessage('  Horde: ' .. (counts.Horde or 0))
            DEFAULT_CHAT_FRAME:AddMessage('  Draws: ' .. (HinterlandAffixHUD_LastStats.draws or 0))
        end
        DEFAULT_CHAT_FRAME:AddMessage('  Total matches: ' .. (HinterlandAffixHUD_LastStats.draws and ((HinterlandAffixHUD_LastStats.counts and (HinterlandAffixHUD_LastStats.counts.Alliance + HinterlandAffixHUD_LastStats.counts.Horde) or 0) + HinterlandAffixHUD_LastStats.draws) or 'Unknown'))
        DEFAULT_CHAT_FRAME:AddMessage('  Season: ' .. (HinterlandAffixHUD_LastStats.season or 'Unknown'))
    else
        DEFAULT_CHAT_FRAME:AddMessage('No local cached stats found')
    end
    
    -- Check UI stats display
    if HLBG.UI and HLBG.UI.Stats and HLBG.UI.Stats.lastStats then
        DEFAULT_CHAT_FRAME:AddMessage('UI has stats data: YES')
    else
        DEFAULT_CHAT_FRAME:AddMessage('UI has stats data: NO')
    end
    
    -- Check what's actually displayed in Stats tab
    if HLBG.UI and HLBG.UI.Stats then
        DEFAULT_CHAT_FRAME:AddMessage('Stats tab exists: YES')
        DEFAULT_CHAT_FRAME:AddMessage('Stats tab shown: ' .. (HLBG.UI.Stats:IsShown() and 'YES' or 'NO'))
        
        -- Look for text elements that might be showing old data
        if HLBG.UI.Stats.Content then
            DEFAULT_CHAT_FRAME:AddMessage('Stats content exists: YES')
            -- Try to find displayed text
            for i = 1, 20 do
                local textElement = HLBG.UI.Stats.Content['text' .. i]
                if textElement and textElement.GetText then
                    local text = textElement:GetText()
                    if text and text ~= '' then
                        DEFAULT_CHAT_FRAME:AddMessage('  Text' .. i .. ': ' .. text)
                    end
                end
            end
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage('Stats tab exists: NO')
    end
    
    DEFAULT_CHAT_FRAME:AddMessage('========================')
end

-- Command to clear stats cache for testing
SLASH_HLBGCLEARSTATS1 = '/hlbgclearstats'
function SlashCmdList.HLBGCLEARSTATS(msg)
    HinterlandAffixHUD_LastStats = nil
    if HLBG.UI and HLBG.UI.Stats then
        HLBG.UI.Stats.lastStats = nil
        -- Also clear any displayed stats content
        if HLBG.UI.Stats.Content then
            for i = 1, 20 do -- Clear up to 20 possible text elements
                if HLBG.UI.Stats.Content["text" .. i] then
                    HLBG.UI.Stats.Content["text" .. i]:SetText("")
                end
            end
        end
        -- Force hide stats frame content
        if HLBG.UI.Stats.Hide then HLBG.UI.Stats:Hide() end
        if HLBG.UI.Stats.Show then HLBG.UI.Stats:Show() end
    end
    DEFAULT_CHAT_FRAME:AddMessage('|cFF00FF00HLBG:|r Stats cache and UI cleared!')
end

-- Command to request fresh stats from server  
SLASH_HLBGREFRESH1 = '/hlbgrefresh'
function SlashCmdList.HLBGREFRESH(msg)
    DEFAULT_CHAT_FRAME:AddMessage('|cFF00FF00HLBG:|r Requesting fresh data from server...')
    
    -- Try AIO first
    if AIO and AIO.Handle then
        DEFAULT_CHAT_FRAME:AddMessage('Sending AIO requests...')
        pcall(function() AIO.Handle("HLBG", "RequestStats") end)
        pcall(function() AIO.Handle("HLBG", "RequestHistory") end)
    end
    
    -- Fallback chat commands  
    DEFAULT_CHAT_FRAME:AddMessage('Sending chat command fallbacks...')
    pcall(function() SendChatMessage(".hlbg statsui", "SAY") end)
    pcall(function() SendChatMessage(".hlbg historyui", "SAY") end)
end

-- Command to manually process the JSON stats we saw in logs
SLASH_HLBGFIXSTATS1 = '/hlbgfixstats'
function SlashCmdList.HLBGFIXSTATS(msg)
    DEFAULT_CHAT_FRAME:AddMessage('|cFF00FF00=== Manually Processing New Stats ===|r')
    
    -- Use the JSON data we saw in the logs
    local statsJson = '{"counts":{"Alliance":0,"Horde":0},"draws":45,"avgDuration":1282,"season":1,"seasonName":"Season 1: Chaos Reborn","reasons":{"depletion":0,"tiebreaker":0,"draw":0,"manual":45},"margins":{"avg":1,"largest":{"team":"","margin":0,"a":0,"h":0,"ts":"","id":0}},"streaks":{"longest":{"team":"","len":0},"current":{"team":"","len":0}},"byAffix":[{"affix":0,"Alliance":0,"Horde":0,"DRAW":44,"avg":728},{"affix":3,"Alliance":0,"Horde":0,"DRAW":1,"avg":0}],"byWeather":[{"weather":"Fine","Alliance":0,"Horde":0,"DRAW":45,"avg":712}]}'
    
    DEFAULT_CHAT_FRAME:AddMessage('Parsing JSON stats...')
    
    -- Parse the JSON (use our HLBG_JSON.lua functions if available)
    local success, statsData = pcall(function()
        if HLBG and HLBG.DecodeJson then
            return HLBG.DecodeJson(statsJson)
        else
            -- Fallback manual parsing for the key fields
            return {
                counts = {Alliance = 0, Horde = 0},
                draws = 45,
                avgDuration = 1282,
                season = 1,
                seasonName = "Season 1: Chaos Reborn",
                reasons = {manual = 45}
            }
        end
    end)
    
    if success and statsData then
        DEFAULT_CHAT_FRAME:AddMessage('✓ JSON parsed successfully')
        DEFAULT_CHAT_FRAME:AddMessage('Alliance: ' .. (statsData.counts and statsData.counts.Alliance or 0))
        DEFAULT_CHAT_FRAME:AddMessage('Horde: ' .. (statsData.counts and statsData.counts.Horde or 0))
        DEFAULT_CHAT_FRAME:AddMessage('Draws: ' .. (statsData.draws or 0))
        DEFAULT_CHAT_FRAME:AddMessage('Total: ' .. ((statsData.counts and (statsData.counts.Alliance + statsData.counts.Horde) or 0) + (statsData.draws or 0)))
        
        -- Try to call HLBG.Stats function directly
        if HLBG and HLBG.Stats then
            DEFAULT_CHAT_FRAME:AddMessage('Calling HLBG.Stats with new data...')
            local callSuccess, err = pcall(HLBG.Stats, statsData)
            if callSuccess then
                DEFAULT_CHAT_FRAME:AddMessage('✓ HLBG.Stats call succeeded!')
            else
                DEFAULT_CHAT_FRAME:AddMessage('✗ HLBG.Stats call failed: ' .. tostring(err))
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage('HLBG.Stats function not found')
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage('✗ Failed to parse JSON: ' .. tostring(statsData))
    end
    
    DEFAULT_CHAT_FRAME:AddMessage('====================================')
end