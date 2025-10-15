local HLBG = _G.HLBG or {}; _G.HLBG = HLBG

HLBG.Live = HLBG.Live or function(rows)
    if not (HLBG._ensureUI and HLBG._ensureUI('Live')) then return end
    rows = rows or {}
    HLBG.UI.Live.lastRows = rows
    -- Basic summary refresh (delegated to existing summary code if present)
    if HLBG.UI and HLBG.UI.Live and HLBG.UI.Live.Summary then
        local RES = _G.RES or {A=0,H=0}
        local a = tonumber(RES.A or 0) or 0
        local h = tonumber(RES.H or 0) or 0
        local tl = tonumber(HLBG._timeLeft or RES.DURATION or 0) or 0
        local m = math.floor(tl/60); local s = tl%60
        local aff = tostring(HLBG._affixText or '-')
        local ap = (HLBG._lastStatus and (HLBG._lastStatus.APlayers or HLBG._lastStatus.APC or HLBG._lastStatus.AllyCount)) or '-'
        local hp = (HLBG._lastStatus and (HLBG._lastStatus.HPlayers or HLBG._lastStatus.HPC or HLBG._lastStatus.HordeCount)) or '-'
        HLBG.UI.Live.Summary:SetText(string.format('Resources  A:%d  H:%d      Players  A:%s  H:%s      Time %d:%02d      Affix %s', a,h,tostring(ap),tostring(hp), m,s, aff))
    end
end
local HLBG = _G.HLBG or {}; _G.HLBG = HLBG

HLBG.Live = HLBG.Live or function(rows)
    if not (HLBG._ensureUI and HLBG._ensureUI('Live')) then return end
    rows = rows or {}
    HLBG.UI.Live.lastRows = rows
    -- Basic summary refresh (delegated to existing summary code if present)
    if HLBG.UI and HLBG.UI.Live and HLBG.UI.Live.Summary then
        local RES = _G.RES or {A=0,H=0}
        local a = tonumber(RES.A or 0) or 0
        local h = tonumber(RES.H or 0) or 0
        local tl = tonumber(HLBG._timeLeft or RES.DURATION or 0) or 0
        local m = math.floor(tl/60); local s = tl%60
        local aff = tostring(HLBG._affixText or '-')
        local ap = (HLBG._lastStatus and (HLBG._lastStatus.APlayers or HLBG._lastStatus.APC or HLBG._lastStatus.AllyCount)) or '-'
        local hp = (HLBG._lastStatus and (HLBG._lastStatus.HPlayers or HLBG._lastStatus.HPC or HLBG._lastStatus.HordeCount)) or '-'
        HLBG.UI.Live.Summary:SetText(string.format('Resources  A:%d  H:%d      Players  A:%s  H:%s      Time %d:%02d      Affix %s', a,h,tostring(ap),tostring(hp), m,s, aff))
    end
end

