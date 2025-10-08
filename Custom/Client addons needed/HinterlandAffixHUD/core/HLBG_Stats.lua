local HLBG = _G.HLBG or {}; _G.HLBG = HLBG

-- Stats module (placeholder refactor) - future: integrate real DB-driven stats payload

HLBG.Stats = HLBG.Stats or function(player, stats)
    -- Debug: announce stats invocation in dev mode and add to debug buffer
    pcall(function()
        local msg = string.format('HLBG.Stats invoked payloadType=%s', type(stats))
        if not HinterlandAffixHUD_DebugLog then HinterlandAffixHUD_DebugLog = {} end
        table.insert(HinterlandAffixHUD_DebugLog, 1, msg)
        while #HinterlandAffixHUD_DebugLog > 400 do table.remove(HinterlandAffixHUD_DebugLog) end
        if DEFAULT_CHAT_FRAME and (HLBG._devMode or (HinterlandAffixHUDDB and HinterlandAffixHUDDB.devMode)) then
            DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG:|r '..msg)
        end
    end)
    -- Normalize invocation forms:
    -- 1) HLBG.Stats(playerName, statsTable)
    -- 2) HLBG.Stats(statsTable)  (legacy or AIO passing single table)
    if type(player) == 'table' and stats == nil then
        stats = player
        player = nil
    end
    if not (HLBG._ensureUI and HLBG._ensureUI('Stats')) then return end

    stats = stats or HLBG.cachedStats or {
        counts = { Alliance = 0, Horde = 0 },
        draws = 0,
        totalBattles = 0,
        bestScore = 0,
        totalScore = 0,
        avgDuration = 0,
    }

    HLBG.cachedStats = stats
    -- Minimal rendering hook (UI code still lives in main UI until further split)
    if HLBG.UI and HLBG.UI.Stats and HLBG.UI.Stats.Text then
        pcall(function() if HLBG and HLBG.UI and HLBG.UI.Frame and HLBG.UI.Frame.Show then HLBG.UI.Frame:Show() end end)
        local statsText = string.format('Alliance: %d | Horde: %d | Draws: %d | Total: %d',
            (stats.counts and stats.counts.Alliance) or 0,
            (stats.counts and stats.counts.Horde) or 0,
            stats.draws or 0,
            stats.totalBattles or ((stats.counts and stats.counts.Alliance or 0) + (stats.counts and stats.counts.Horde or 0) + (stats.draws or 0)))
        HLBG.UI.Stats.Text:SetText(statsText)
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG Debug:|r Directly updated Stats UI text: ' .. statsText)
        end
    else
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage('|cFFFF3333HLBG Debug:|r Stats UI elements missing! UI=' .. tostring(HLBG.UI ~= nil) .. ' Stats=' .. tostring(HLBG.UI and HLBG.UI.Stats ~= nil) .. ' Text=' .. tostring(HLBG.UI and HLBG.UI.Stats and HLBG.UI.Stats.Text ~= nil))
        end
    end
end

-- Lightweight server stats ingestion hook. Accepts either a table payload or positional params.
-- Supported table fields: totalBattles, allianceWins, hordeWins, draws, bestScore, totalScore, avgDuration
-- Positional form: (totalBattles, allianceWins, hordeWins, draws, bestScore, totalScore, avgDuration)
if not HLBG.OnServerStats then
    function HLBG.OnServerStats(a,b,c,d,e,f,g)
        local payload
        if type(a) == 'table' then
            payload = a
        else
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
        if type(payload) ~= 'table' then return end
        local stats = {
            counts = {
                Alliance = tonumber(payload.allianceWins or payload.Alliance or payload.A or 0) or 0,
                Horde    = tonumber(payload.hordeWins or payload.Horde or payload.H or 0) or 0,
            },
            draws        = tonumber(payload.draws or payload.Draws or 0) or 0,
            totalBattles = tonumber(payload.totalBattles or payload.Total or payload.Battles or 0) or 0,
            bestScore    = tonumber(payload.bestScore or payload.Best or 0) or 0,
            totalScore   = tonumber(payload.totalScore or payload.ScoreSum or 0) or 0,
            avgDuration  = tonumber(payload.avgDuration or payload.AvgDuration or 0) or 0,
        }
        HLBG.Stats(stats)
    end
end
