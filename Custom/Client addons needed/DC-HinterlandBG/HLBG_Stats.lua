local HLBG = _G.HLBG or {}; _G.HLBG = HLBG

-- Comprehensive Stats Module - Matches scoreboard NPC functionality
-- Supports all statistics tracked in hlbg_winner_history database

-- Helper: Get affix name by ID
HLBG.GetAffixName = HLBG.GetAffixName or function(affixId)
    local affixes = {
        [0] = "None",
        [1] = "Haste",
        [2] = "Slow",
        [3] = "Reduced Healing",
        [4] = "Reduced Armor",
        [5] = "Boss Enrage"
    }
    return affixes[affixId] or "Unknown"
end

-- Main stats rendering function
HLBG.Stats = HLBG.Stats or function(player, stats)
    -- Debug logging
    pcall(function()
        local msg = string.format('HLBG.Stats invoked payloadType=%s', type(stats))
        if not DCHLBG_DebugLog then DCHLBG_DebugLog = {} end
        table.insert(DCHLBG_DebugLog, 1, msg)
        while #DCHLBG_DebugLog > 400 do table.remove(DCHLBG_DebugLog) end
        if DEFAULT_CHAT_FRAME and (HLBG._devMode or (DCHLBGDB and DCHLBGDB.devMode)) then
            DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG:|r '..msg)
        end
    end)
    
    -- Cache stats for later use
    HLBG.cachedStats = stats or HLBG.cachedStats
    
    -- Ensure UI is available
    if not (HLBG.UI and HLBG.UI.Stats and HLBG.UI.Stats.Text) then
        if DEFAULT_CHAT_FRAME and (HLBG._devMode or (DCHLBGDB and DCHLBGDB.debugMode)) then
            DEFAULT_CHAT_FRAME:AddMessage('|cFFFF3333HLBG Debug:|r Stats UI elements missing! Deferring...')
        end
        -- Schedule retry
        if not HLBG._statsDeferredRetryScheduled then
            HLBG._statsDeferredRetryScheduled = true
            C_Timer.After(1.0, function()
                HLBG._statsDeferredRetryScheduled = false
                if HLBG.cachedStats then
                    pcall(HLBG.Stats, nil, HLBG.cachedStats)
                end
            end)
        end
        return
    end
    
    -- Show UI frame
    pcall(function() 
        if HLBG.UI.Frame and HLBG.UI.Frame.Show then 
            HLBG.UI.Frame:Show() 
        end 
    end)
    
    -- Render stats using UpdateStats function (defined in HLBG_UI_Clean.lua)
    if HLBG.UpdateStats and type(HLBG.UpdateStats) == 'function' then
        pcall(HLBG.UpdateStats, stats)
    else
        -- Fallback: basic display
        local text = "No stats available. Click Refresh to load data."
        if stats and type(stats) == "table" then
            text = string.format('Alliance: %d | Horde: %d | Draws: %d',
                (stats.allianceWins or 0),
                (stats.hordeWins or 0),
                (stats.draws or 0))
        end
        HLBG.UI.Stats.Text:SetText(text)
    end
    
    if DEFAULT_CHAT_FRAME and (HLBG._devMode or (DCHLBGDB and DCHLBGDB.debugMode)) then
        DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG Debug:|r Stats UI updated')
    end
end

-- Server stats ingestion hook
-- Accepts comprehensive stats payload matching scoreboard NPC data structure
-- Expected fields:
--   Basic: totalBattles, allianceWins, hordeWins, draws
--   Reasons: depletionWins, tiebreakerWins, manualResets
--   Streaks: currentStreak{team,count}, longestStreak{team,count}
--   Margins: largestMargin{date,team,margin,scoreA,scoreH}
--   Per-affix: topWinnersByAffix[], drawsByAffix[], topAffixes[], avgScoresPerAffix[], winRatesPerAffix[], avgMarginPerAffix[], reasonBreakdownPerAffix[], medianMarginPerAffix[], avgDurationPerAffix[]
HLBG.OnServerStats = HLBG.OnServerStats or function(payload, ...)
    if type(payload) ~= 'table' then
        -- Legacy positional params support (deprecated)
        local a,b,c,d,e,f,g = payload, ...
        if type(a) ~= 'table' then
            payload = {
                totalBattles = tonumber(a) or 0,
                allianceWins = tonumber(b) or 0,
                hordeWins    = tonumber(c) or 0,
                draws        = tonumber(d) or 0,
                bestScore    = tonumber(e) or 0,
                totalScore   = tonumber(f) or 0,
                avgDuration  = tonumber(g) or 0,
            }
        end
    end
    
    if type(payload) ~= 'table' then return end
    
    -- Normalize payload to internal stats structure
    local stats = {
        -- Basic counts
        totalBattles = tonumber(payload.totalBattles or payload.total or 0) or 0,
        allianceWins = tonumber(payload.allianceWins or payload.Alliance or 0) or 0,
        hordeWins    = tonumber(payload.hordeWins or payload.Horde or 0) or 0,
        draws        = tonumber(payload.draws or 0) or 0,
        
        -- Win reasons
        depletionWins  = tonumber(payload.depletionWins or 0) or 0,
        tiebreakerWins = tonumber(payload.tiebreakerWins or 0) or 0,
        manualResets   = tonumber(payload.manualResets or 0) or 0,
        
        -- Streaks
        currentStreak  = payload.currentStreak or { team = "None", count = 0 },
        longestStreak  = payload.longestStreak or { team = "None", count = 0 },
        
        -- Largest margin
        largestMargin = payload.largestMargin or nil,
        
        -- Per-affix statistics (arrays)
        topWinnersByAffix       = payload.topWinnersByAffix or {},
        drawsByAffix            = payload.drawsByAffix or {},
        topAffixes              = payload.topAffixes or {},
        avgScoresPerAffix       = payload.avgScoresPerAffix or {},
        winRatesPerAffix        = payload.winRatesPerAffix or {},
        avgMarginPerAffix       = payload.avgMarginPerAffix or {},
        reasonBreakdownPerAffix = payload.reasonBreakdownPerAffix or {},
        medianMarginPerAffix    = payload.medianMarginPerAffix or {},
        avgDurationPerAffix     = payload.avgDurationPerAffix or {},
        
        -- Legacy support
        bestScore   = tonumber(payload.bestScore or 0) or 0,
        totalScore  = tonumber(payload.totalScore or 0) or 0,
        avgDuration = tonumber(payload.avgDuration or 0) or 0,
    }
    
    -- Call main Stats function to render
    HLBG.Stats(nil, stats)
end

-- Request stats from server
HLBG.RequestStats = HLBG.RequestStats or function(season)
    -- Deprecated: HLBG stats/history UI moved to DC-Leaderboards.
    if type(HLBG) == 'table' and type(HLBG.OpenLeaderboards) == 'function' then
        HLBG.OpenLeaderboards()
        return
    end

    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage('|cFFFFAA00HLBG:|r Stats UI moved to |cFF33FF99DC-Leaderboards|r. Use |cFFFFFFFF/leaderboard|r.')
    end
end

