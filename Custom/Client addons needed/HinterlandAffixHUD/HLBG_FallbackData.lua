-- HLBG_FallbackData.lua - Provide fallback data when server data isn't available

local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

-- Fallback Stats function
function HLBG.ShowFallbackStats()
    if not HLBG.UI or not HLBG.UI.Stats or not HLBG.UI.Stats.Text then return end
    
    local statsText = "Hinterland Battleground Statistics\n\n"
    
    -- Try to get some basic data
    local totalBattles = 0
    local allianceWins = 0
    local hordeWins = 0
    local draws = 0
    
    -- If we have saved data, use it
    if HinterlandAffixHUDDB and HinterlandAffixHUDDB.statsCache then
        local cache = HinterlandAffixHUDDB.statsCache
        totalBattles = cache.total or 0
        allianceWins = cache.allianceWins or 0
        hordeWins = cache.hordeWins or 0
        draws = cache.draws or 0
    end
    
    statsText = statsText .. string.format("Total Battles: %d\n", totalBattles)
    statsText = statsText .. string.format("Alliance Wins: %d\n", allianceWins)
    statsText = statsText .. string.format("Horde Wins: %d\n", hordeWins)
    statsText = statsText .. string.format("Draws: %d\n\n", draws)
    
    if totalBattles > 0 then
        local alliancePercent = math.floor((allianceWins / totalBattles) * 100)
        local hordePercent = math.floor((hordeWins / totalBattles) * 100)
        statsText = statsText .. string.format("Alliance Win Rate: %d%%\n", alliancePercent)
        statsText = statsText .. string.format("Horde Win Rate: %d%%\n\n", hordePercent)
    end
    
    statsText = statsText .. "Use '/hlbg stats' for detailed statistics.\n"
    statsText = statsText .. "Data updates automatically during battles."
    
    HLBG.UI.Stats.Text:SetText(statsText)
end

-- Fallback History function  
function HLBG.ShowFallbackHistory()
    if not HLBG.UI or not HLBG.UI.History then return end
    
    -- Show empty text with helpful info
    if HLBG.UI.History.EmptyText then
        HLBG.UI.History.EmptyText:Show()
    end
    
    print("|cFF33FF99HLBG:|r No history data available. Try '/hlbg history' command.")
end

-- Enhanced Stats tab handler
local originalStatsOnShow = nil
if HLBG.UI and HLBG.UI.Stats and HLBG.UI.Stats.GetScript then
    originalStatsOnShow = HLBG.UI.Stats:GetScript("OnShow")
end

-- Override or enhance Stats OnShow
local function enhancedStatsOnShow()
    -- Call original handler first
    if originalStatsOnShow then
        pcall(originalStatsOnShow)
    end
    
    -- Wait a bit, then show fallback if still empty
    C_Timer.After(2, function()
        if HLBG.UI and HLBG.UI.Stats and HLBG.UI.Stats.Text then
            local currentText = HLBG.UI.Stats.Text:GetText() or ""
            if currentText == "Stats will appear here." or currentText == "" or currentText:find("Loading") then
                HLBG.ShowFallbackStats()
            end
        end
    end)
end

-- Apply enhanced handler when UI is ready
C_Timer.After(1, function()
    if HLBG.UI and HLBG.UI.Stats then
        HLBG.UI.Stats:SetScript("OnShow", enhancedStatsOnShow)
        print("|cFF33FF99HLBG:|r Fallback data handlers installed")
    end
end)

print("|cFF33FF99HLBG:|r Fallback data module loaded")