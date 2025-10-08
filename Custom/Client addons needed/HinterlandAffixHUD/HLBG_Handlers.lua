-- HLBG_Handlers.lua
local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

-- Shared live resources state. Initialize to avoid nil indexing when STATUS messages arrive.
RES = RES or {}
HLBG.RES = HLBG.RES or RES

-- Zone watcher: show/hide HUD when entering Hinterlands
local function InHinterlands()
    local z = (type(HLBG) == 'table' and type(HLBG.safeGetRealZoneText) == 'function') and HLBG.safeGetRealZoneText() or (GetRealZoneText and GetRealZoneText() or "")
    return z == "The Hinterlands"
end

local zoneWatcher = CreateFrame("Frame")
zoneWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
zoneWatcher:RegisterEvent("ZONE_CHANGED_NEW_AREA")
zoneWatcher:RegisterEvent("ZONE_CHANGED")
zoneWatcher:RegisterEvent("ZONE_CHANGED_INDOORS")
zoneWatcher:SetScript("OnEvent", function()
    if InHinterlands() then
        if type(HLBG.UpdateHUD) == 'function' then pcall(HLBG.UpdateHUD) end
        if HinterlandAffixHUDDB and HinterlandAffixHUDDB.useAddonHud and type(HLBG.HideBlizzHUDDeep) == 'function' then pcall(HLBG.HideBlizzHUDDeep) end
    else
        if HLBG.UI and HLBG.UI.HUD then pcall(function() HLBG.UI.HUD:Hide() end) end
        if HLBG.UI and HLBG.UI.Affix then pcall(function() HLBG.UI.Affix:Hide() end) end
        if type(HLBG.UnhideBlizzHUDDeep) == 'function' then pcall(HLBG.UnhideBlizzHUDDeep) end
    end
end)

-- Ensure PvP tab/button helpers (lazy creation)
local function EnsurePvPTab()
    local _pvp = _G["PVPParentFrame"] or _G["PVPFrame"]
    if not _pvp or _G["PVPFrameTabHLBG"] then return end
    local baseName = _pvp:GetName() or "PVPFrame"
    local lastIdx = _pvp.numTabs or 2
    local lastTab = _G[baseName.."Tab"..lastIdx]
    local tab = CreateFrame("Button", "PVPFrameTabHLBG", _pvp, "CharacterFrameTabButtonTemplate")
    tab:SetText("HLBG")
    tab:SetID((lastIdx or 2) + 1)
    if lastTab then tab:SetPoint("LEFT", lastTab, "RIGHT", -15, 0) else tab:SetPoint("TOPLEFT", _pvp, "BOTTOMLEFT", 10, 7) end
    tab:SetScript("OnClick", function()
        if PVPFrameLeft then PVPFrameLeft:Hide() end
        if PVPFrameRight then PVPFrameRight:Hide() end
        if HLBG.UI and HLBG.UI.Frame then HLBG.UI.Frame:Show() end
        if type(ShowTab) == 'function' then pcall(ShowTab, HinterlandAffixHUDDB.lastInnerTab or 1) end
        if _G.AIO and _G.AIO.Handle then
            local season = (HLBG and HLBG._getSeason and HLBG._getSeason()) or 0
            _G.AIO.Handle("HLBG", "Request", "HISTORY", 1, HLBG.UI and HLBG.UI.History and HLBG.UI.History.per or 5, HLBG.UI and HLBG.UI.History and HLBG.UI.History.sortKey or "id", HLBG.UI and HLBG.UI.History and HLBG.UI.History.sortDir or "DESC")
            _G.AIO.Handle("HLBG", "Request", "HISTORY", 1, HLBG.UI and HLBG.UI.History and HLBG.UI.History.per or 5, season, HLBG.UI and HLBG.UI.History and HLBG.UI.History.sortKey or "id", HLBG.UI and HLBG.UI.History and HLBG.UI.History.sortDir or "DESC")
            _G.AIO.Handle("HLBG", "Request", "STATS")
            _G.AIO.Handle("HLBG", "Request", "STATS", season)
        end
        -- chat fallbacks (use raw dot to server)
        local sendDot = (HLBG and HLBG.SendServerDot) or _G.HLBG_SendServerDot
        local season = (HLBG and HLBG._getSeason and HLBG._getSeason()) or 0
        if type(sendDot) == 'function' then
            sendDot('.hlbg live players')
            sendDot('.hlbg historyui 1 5 id DESC')
            sendDot(string.format('.hlbg historyui %d %d %d %s %s', 1, 5, season, 'id', 'DESC'))
            sendDot('.hlbg statsui')
            sendDot(string.format('.hlbg statsui %d', season))
        end
    end)
end

local function EnsurePvPHeaderButton()
    local _pvp = _G["PVPParentFrame"] or _G["PVPFrame"]
    if not _pvp or _G["PVPFrameHLBGButton"] then return end
    local btn = CreateFrame("Button", "PVPFrameHLBGButton", _pvp, "UIPanelButtonTemplate")
    btn:SetSize(56, 20)
    btn:SetPoint("TOPRIGHT", _pvp, "TOPRIGHT", -40, -28)
    btn:SetText("HLBG")
    btn:SetScript("OnClick", function()
        if HLBG.UI and HLBG.UI.Frame then HLBG.UI.Frame:Show() end
        if type(ShowTab) == 'function' then pcall(ShowTab, HinterlandAffixHUDDB.lastInnerTab or 1) end
        if _G.AIO and _G.AIO.Handle then
            local season = (HLBG and HLBG._getSeason and HLBG._getSeason()) or 0
            _G.AIO.Handle("HLBG", "Request", "HISTORY", HLBG.UI and HLBG.UI.History and HLBG.UI.History.page or 1, HLBG.UI and HLBG.UI.History and HLBG.UI.History.per or 5, HLBG.UI and HLBG.UI.History and HLBG.UI.History.sortKey or "id", HLBG.UI and HLBG.UI.History and HLBG.UI.History.sortDir or "DESC")
            _G.AIO.Handle("HLBG", "Request", "HISTORY", HLBG.UI and HLBG.UI.History and HLBG.UI.History.page or 1, HLBG.UI and HLBG.UI.History and HLBG.UI.History.per or 5, season, HLBG.UI and HLBG.UI.History and HLBG.UI.History.sortKey or "id", HLBG.UI and HLBG.UI.History and HLBG.UI.History.sortDir or "DESC")
            _G.AIO.Handle("HLBG", "Request", "STATS")
            _G.AIO.Handle("HLBG", "Request", "STATS", season)
        end
        local sendDot = (HLBG and HLBG.SendServerDot) or _G.HLBG_SendServerDot
        local season = (HLBG and HLBG._getSeason and HLBG._getSeason()) or 0
        if type(sendDot) == 'function' then
            sendDot('.hlbg live players')
            sendDot('.hlbg historyui 1 5 id DESC')
            sendDot(string.format('.hlbg historyui %d %d %d %s %s', 1, 5, season, 'id', 'DESC'))
            sendDot('.hlbg statsui')
            sendDot(string.format('.hlbg statsui %d', season))
        end
    end)
    _pvp:HookScript("OnHide", function()
        if HLBG.UI and HLBG.UI.Frame and HLBG.UI.Frame:GetParent() == _pvp then HLBG.UI.Frame:Hide() end
    end)
end

-- pvp watcher: create PvP tab/header when frames are ready
local pvpWatcher = CreateFrame("Frame")
pvpWatcher:RegisterEvent("PLAYER_LOGIN")
pvpWatcher:RegisterEvent("ADDON_LOADED")
pvpWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
pvpWatcher:SetScript("OnEvent", function(_, ev, name)
    EnsurePvPTab(); EnsurePvPHeaderButton()
    -- When the PvP UI is shown, try to prime data if AIO is missing
    if type(HLBG) == 'table' and type(HLBG.safeExecSlash) == 'function' then
        local hist = (HLBG and HLBG.UI and HLBG.UI.History) or nil
        local p = (hist and hist.page) or 1
        local per = (hist and hist.per) or 5
        local sk = (hist and hist.sortKey) or 'id'
        local sd = (hist and hist.sortDir) or 'DESC'
        HLBG.safeExecSlash(string.format('.hlbg historyui %d %d %s %s', p, per, sk, sd))
        HLBG.safeExecSlash('.hlbg statsui')
    end
end)

-- Also retry a few times after login in case of delayed creation
do
    local tries, t = 0, 0
    local fr = CreateFrame("Frame")
    fr:SetScript("OnUpdate", function(self, elapsed)
        t = t + (elapsed or 0)
        if t > 1.0 then
            t = 0; tries = tries + 1; EnsurePvPTab(); EnsurePvPHeaderButton()
            if _G["PVPFrameTabHLBG"] or _G["PVPFrameHLBGButton"] or tries > 5 then self:SetScript("OnUpdate", nil) end
        end
    end)
end

-- Support addon-channel STATUS & AFFIX messages to drive HUD
local eventFrame = CreateFrame("Frame")
-- 3.3.5a requires registering addon message prefixes explicitly
pcall(function()
    if type(RegisterAddonMessagePrefix) == 'function' then
        RegisterAddonMessagePrefix('HLBG')
    end
end)
    
    -- Slash command to dump last sanitized TSV (client-side debug)
    SLASH_HLBGSANIT1 = '/hlbgsanitize'
    SLASH_HLBGSANIT2 = '.hlbgsanitize'
    SlashCmdList['HLBGSANIT'] = function(msg)
        local s = (HLBG and HLBG._lastSanitizedTSV) or nil
        if not s or s == '' then
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG:|r No sanitized TSV available') end
            return
        end
        -- Print a trimmed preview and store full content in debug buffer
        local preview = (string.len(s) > 400) and (s:sub(1,400) .. '...[truncated]') or s
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG sanitized TSV preview:|r ' .. preview) end
        HinterlandAffixHUD_DebugLog = HinterlandAffixHUD_DebugLog or {}
        table.insert(HinterlandAffixHUD_DebugLog, 1, string.format('[HLBG_SANITIZED] %s', s))
        while #HinterlandAffixHUD_DebugLog > 500 do table.remove(HinterlandAffixHUD_DebugLog) end
    end
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    local prefix, msg = ...
    if tostring(prefix) ~= "HLBG" then return end

    -- Forward a compact raw sample of incoming addon messages to the server-side log (throttled)
    pcall(function()
        local send = _G.HLBG_SendClientLog or (type(HLBG) == 'table' and HLBG.SendClientLog)
        if type(send) == 'function' then
            HLBG._rawSampleState = HLBG._rawSampleState or { lastSample = nil, lastTs = 0 }
            local raw = tostring(prefix or "") .. "\t" .. tostring(msg or "")
            local sample = raw
            if #sample > 256 then sample = sample:sub(1,256) .. "...[truncated]" end
            local now = time()
            local changed = (HLBG._rawSampleState.lastSample ~= sample)
            local elapsed = now - (HLBG._rawSampleState.lastTs or 0)
            if changed or elapsed >= 5 then
                HLBG._rawSampleState.lastSample = sample
                HLBG._rawSampleState.lastTs = now
                pcall(send, string.format("ADDON_MSG_SAMPLE prefix=%s len=%d sample=%s", tostring(prefix), (type(msg)=="string" and #msg) or 0, sample))
            end
        end
    end)

    if type(msg) ~= 'string' then return end

    -- STATUS messages
    if msg:match("^STATUS|") then
        local A = tonumber(msg:match("A=(%d+)") or 0) or 0
        local H = tonumber(msg:match("H=(%d+)") or 0) or 0
        local ENDt = tonumber(msg:match("END=(%d+)") or 0) or 0
        local LOCK = tonumber(msg:match("LOCK=(%d+)") or 0) or 0
        RES.A = A; RES.H = H; RES.END = ENDt; RES.LOCK = LOCK
        if type(HLBG.UpdateHUD) == 'function' then pcall(HLBG.UpdateHUD) end
        return
    end

    -- AFFIX messages
    local aff = msg:match("^AFFIX|(.*)$")
    if aff then
        HLBG._affixText = tostring(aff)
        if type(HLBG.UpdateHUD) == 'function' then pcall(HLBG.UpdateHUD) end
        -- Always hide legacy floating chip to avoid duplicate Affix text
        if HLBG.UI and HLBG.UI.Affix then pcall(function() HLBG.UI.Affix:Hide() end) end
        return
    end

    -- Warmup notice
    local warm = msg:match('%[HLBG_WARMUP%]%s*(.*)')
    if warm then if type(HLBG.Warmup) == 'function' then pcall(HLBG.Warmup, warm) end; return end

    -- Queue status
    local q = msg:match('%[HLBG_QUEUE%]%s*(.*)')
    if q then if type(HLBG.QueueStatus) == 'function' then pcall(HLBG.QueueStatus, q) end; return end

    -- Results JSON
    local rj = msg:match('%[HLBG_RESULTS_JSON%]%s*(.*)')
    if rj then
        local ok, decoded = pcall(function()
            return (HLBG.json_decode and HLBG.json_decode(rj)) or (type(json_decode) == 'function' and json_decode(rj)) or nil
        end)
        if ok and type(decoded) == 'table' and type(HLBG.Results) == 'function' then pcall(HLBG.Results, decoded) end
        return
    end

    -- History TSV fallback
    local htsv = msg:match('%[HLBG_HISTORY_TSV%]%s*(.*)')
    if htsv then
        -- Handler-side sanitization (pre-process common chat fallback shapes)
        -- Convert '||' markers into newlines, strip optional TOTAL= prefix, and remove high-byte garbage
        local function strip_high_bytes(s)
            if type(s) ~= 'string' then return s end
            local out = {}
            for i=1,#s do local b = string.byte(s,i); if b and b < 128 then table.insert(out, string.char(b)) end end
            return table.concat(out)
        end
    htsv = strip_high_bytes(htsv)
    local total = tonumber((htsv:match('^TOTAL=(%d+)%s*%|%|') or htsv:match('^TOTAL=(%d+)%s*') or 0)) or 0
    htsv = htsv:gsub('^TOTAL=%d+%s*%|%|', ''):gsub('^TOTAL=%d+%s*', '')
    -- Convert common row separators into real newlines. Some servers use '||' or single '|' between rows.
    htsv = htsv:gsub('%|%|', '\n')
    -- Dev-only: report whether handler converted pipes into newlines
    pcall(function()
        local dev = HLBG._devMode or (HinterlandAffixHUDDB and HinterlandAffixHUDDB.devMode)
        if dev and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            local foundPipe = htsv:find('%|') and true or false
            local foundNl = htsv:find('\n') and true or false
            DEFAULT_CHAT_FRAME:AddMessage(string.format('|cFF33FF99HLBG Debug|r Handler sanitized: foundPipe=%s foundNewline=%s', tostring(foundPipe), tostring(foundNl)))
        end
    end)
    if htsv:find('%|') and not htsv:find('\n') then htsv = htsv:gsub('%|', '\n') end
        if HLBG.UI and HLBG.UI.History and total and total > 0 then HLBG.UI.History.total = total end
        if type(HLBG.HistoryStr) == 'function' then pcall(HLBG.HistoryStr, htsv, 1, (HLBG.UI and HLBG.UI.History and HLBG.UI.History.per) or 5, total, 'id', 'DESC') end
        return
    end

    -- Stats JSON fallback
    local sj = msg:match('%[HLBG_STATS_JSON%]%s*(.*)')
    if sj then
        local ok, decoded = pcall(function()
            return (HLBG.json_decode and HLBG.json_decode(sj)) or (type(json_decode) == 'function' and json_decode(sj)) or nil
        end)
        if ok and type(decoded) == 'table' then
            if decoded.total and HLBG.UI and HLBG.UI.History then HLBG.UI.History.total = tonumber(decoded.total) or HLBG.UI.History.total end
            if type(HLBG.Stats) == 'function' then pcall(HLBG.Stats, decoded) end
        end
        return
    end
end)

-- Some servers send HLBG payloads to regular chat (not addon channel). Listen broadly
local chatFrame = CreateFrame('Frame')
chatFrame:RegisterEvent('CHAT_MSG_SAY')
chatFrame:RegisterEvent('CHAT_MSG_YELL')
chatFrame:RegisterEvent('CHAT_MSG_GUILD')
chatFrame:RegisterEvent('CHAT_MSG_PARTY')
chatFrame:RegisterEvent('CHAT_MSG_PARTY_LEADER')
chatFrame:RegisterEvent('CHAT_MSG_RAID')
chatFrame:RegisterEvent('CHAT_MSG_RAID_LEADER')
chatFrame:RegisterEvent('CHAT_MSG_SYSTEM')
chatFrame:RegisterEvent('CHAT_MSG_WHISPER')
chatFrame:SetScript('OnEvent', function(_, ev, msg)
    if type(msg) ~= 'string' then return end
    -- STATUS (chat fallback)
    local b = msg:match('%[HLBG_STATUS%]%s*(.*)')
    if b then
        RES = RES or {}
        local A = tonumber(b:match('%f[%w]A=(%d+)') or 0) or 0
        local H = tonumber(b:match('%f[%w]H=(%d+)') or 0) or 0
        local ENDTS = tonumber(b:match('%f[%w]END=(%d+)') or 0) or 0
        local LOCK = tonumber(b:match('%f[%w]LOCK=(%d+)') or 0) or 0
        local AFF = b:match('%f[%w]AFF=([^|]+)') or b:match('%f[%w]AFFIX=([^|]+)')
        RES.A = A; RES.H = H; RES.END = ENDTS; RES.LOCK = LOCK
        if AFF then HLBG._affixText = AFF end
        if type(HLBG.UpdateHUD) == 'function' then pcall(HLBG.UpdateHUD) end
        -- Also mirror to Live tab as two rows if available
        pcall(function()
            if type(HLBG.UpdateLiveFromStatus) == 'function' then HLBG.UpdateLiveFromStatus() else
                if type(HLBG.Live) == 'function' then
                    local nowts = (type(date)=="function" and date("%Y-%m-%d %H:%M:%S")) or ""
                    HLBG.Live({ { id = 'A', ts = nowts, name = 'Alliance', team = 'Alliance', score = A }, { id = 'H', ts = nowts, name = 'Horde', team = 'Horde', score = H } })
                end
            end
        end)
        return
    end
    -- Warmup
    local warm = msg:match('%[HLBG_WARMUP%]%s*(.*)')
    if warm then if type(HLBG.Warmup) == 'function' then pcall(HLBG.Warmup, warm) end return end
    -- Queue
    local q = msg:match('%[HLBG_QUEUE%]%s*(.*)')
    if q then if type(HLBG.QueueStatus) == 'function' then pcall(HLBG.QueueStatus, q) end return end
    -- Results JSON
    local rj = msg:match('%[HLBG_RESULTS_JSON%]%s*(.*)')
    if rj then
        local ok, decoded = pcall(function()
            return (HLBG.json_decode and HLBG.json_decode(rj)) or (type(json_decode) == 'function' and json_decode(rj)) or nil
        end)
        if ok and type(decoded) == 'table' and type(HLBG.Results) == 'function' then pcall(HLBG.Results, decoded) end
        return
    end
    -- History TSV
    local htsv = msg:match('%[HLBG_HISTORY_TSV%]%s*(.*)')
    if htsv then
        local total = tonumber((htsv:match('^TOTAL=(%d+)%s*%|%|') or 0)) or 0
        if HLBG.UI and HLBG.UI.History and total and total > 0 then HLBG.UI.History.total = total end
        -- Strip TOTAL prefix
        htsv = htsv:gsub('^TOTAL=%d+%s*%|%|', '')
    -- If multi-row separator exists, convert to newlines for HistoryStr
    -- Dev-only: report pipe/newline state before conversion
    pcall(function()
        local dev = HLBG._devMode or (HinterlandAffixHUDDB and HinterlandAffixHUDDB.devMode)
        if dev and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            local foundNl = htsv:find('\n') and true or false
            local pipeCount = 0
            for _ in htsv:gmatch('%|') do pipeCount = pipeCount + 1 end
            DEFAULT_CHAT_FRAME:AddMessage(string.format('|cFF33FF99HLBG Debug|r Chat handler before conv: pipeCount=%d foundNewline=%s', pipeCount, tostring(foundNl)))
        end
    end)
    htsv = htsv:gsub('%|%|','\n')
    if htsv:find('%|') and not htsv:find('\n') then htsv = htsv:gsub('%|','\n') end
    -- Dev-only: report pipe/newline state after conversion
    pcall(function()
        local dev = HLBG._devMode or (HinterlandAffixHUDDB and HinterlandAffixHUDDB.devMode)
        if dev and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            local foundNl = htsv:find('\n') and true or false
            local pipeCount = 0
            for _ in htsv:gmatch('%|') do pipeCount = pipeCount + 1 end
            DEFAULT_CHAT_FRAME:AddMessage(string.format('|cFF33FF99HLBG Debug|r Chat handler after conv: pipeCount=%d foundNewline=%s', pipeCount, tostring(foundNl)))
        end
    end)
        local hasTabs = htsv:find('\t') and true or false
        local hasNL   = htsv:find('\n') and true or false
        pcall(function()
            local dev = HLBG._devMode or (HinterlandAffixHUDDB and HinterlandAffixHUDDB.devMode)
            if dev and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                DEFAULT_CHAT_FRAME:AddMessage(string.format('|cFF33FF99HLBG Debug|r Chat handler deciding: hasTabs=%s hasNL=%s len=%d', tostring(hasTabs), tostring(hasNL), #htsv))
            end
        end)
        pcall(function()
            DEFAULT_CHAT_FRAME:AddMessage(string.format('|cFF33FF99HLBG Debug|r HistoryStr function available: %s', type(HLBG.HistoryStr)))
        end)
        if hasTabs and type(HLBG.HistoryStr) == 'function' then
            pcall(function()
                DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG Debug|r About to call HistoryStr')
            end)
            
            -- Store the sanitized TSV for debugging
            HLBG._lastSanitizedTSV = htsv
            local lines = {}
            for line in htsv:gmatch('[^\n]+') do
                if line and line:trim() ~= '' then
                    table.insert(lines, line)
                end
            end
            
            pcall(function()
                DEFAULT_CHAT_FRAME:AddMessage(string.format('|cFF33FF99HLBG Debug|r HistoryStr sanitized lines=%d preview=%s', #lines, htsv:sub(1,200)))
            end)
            
            local ok, err = pcall(HLBG.HistoryStr, htsv, 1, (HLBG.UI and HLBG.UI.History and HLBG.UI.History.per) or 5, total, 'id', 'DESC')
            if ok then
                pcall(function()
                    DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG Debug|r HistoryStr call succeeded!')
                end)
            else
                pcall(function()
                    DEFAULT_CHAT_FRAME:AddMessage('|cFFFF5555HLBG Debug|r HistoryStr error: '..tostring(err))
                end)
            end
        else
            -- Tabs missing (some servers strip them in chat). Try flexible single-line parser per row.
            local rows = {}
            for line in htsv:gmatch('[^\n]+') do
                if type(HLBG._parseHistLineFlexible) == 'function' then
                    local row = HLBG._parseHistLineFlexible(line)
                    if row then table.insert(rows, row) end
                end
            end
            if #rows > 0 and type(HLBG.History) == 'function' then
                pcall(HLBG.History, rows, 1, (HLBG.UI and HLBG.UI.History and HLBG.UI.History.per) or #rows, total, 'id', 'DESC')
            elseif type(HLBG.HistoryStr) == 'function' then
                -- Fall back to whatever the UI parser can do
                pcall(HLBG.HistoryStr, htsv, 1, (HLBG.UI and HLBG.UI.History and HLBG.UI.History.per) or 5, total, 'id', 'DESC')
            end
        end
        return
    end
    -- Stats JSON - FIXED to properly handle incoming JSON and display stats
    local sj = msg:match('%[HLBG_STATS_JSON%]%s*(.*)')
    if sj then
        pcall(function()
            DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG Debug:|r Processing STATS_JSON, length: ' .. #sj)
        end)
        
        local ok, decoded = pcall(function()
            -- First try built-in JSON decoder if available
            if HLBG.json_decode and type(HLBG.json_decode) == 'function' then
                return HLBG.json_decode(sj)
            elseif type(json_decode) == 'function' then
                return json_decode(sj)
            else
                -- Fallback: Simple JSON parsing for known structure
                local stats = {}
                
                -- Extract key values from JSON string manually
                stats.draws = tonumber(sj:match('"draws":(%d+)')) or 0
                stats.avgDuration = tonumber(sj:match('"avgDuration":(%d+)')) or 0
                stats.season = tonumber(sj:match('"season":(%d+)')) or 1
                stats.seasonName = sj:match('"seasonName":"([^"]+)"') or "Season 1"
                
                -- Extract counts object
                local allianceCount = tonumber(sj:match('"Alliance":(%d+)')) or 0
                local hordeCount = tonumber(sj:match('"Horde":(%d+)')) or 0
                stats.counts = { Alliance = allianceCount, Horde = hordeCount }
                
                -- Calculate total battles
                stats.totalBattles = allianceCount + hordeCount + stats.draws
                
                return stats
            end
        end)
        
        if ok and type(decoded) == 'table' then
            pcall(function()
                DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG Debug:|r JSON decoded successfully: Alliance=' .. (decoded.counts and decoded.counts.Alliance or 'nil') .. ', Horde=' .. (decoded.counts and decoded.counts.Horde or 'nil') .. ', Draws=' .. (decoded.draws or 'nil'))
            end)
            
            -- Store total if present
            if decoded.total and HLBG.UI and HLBG.UI.History then 
                HLBG.UI.History.total = tonumber(decoded.total) or HLBG.UI.History.total 
            end
            
            -- Call stats display function with decoded data - TRY MULTIPLE APPROACHES
            if type(HLBG.Stats) == 'function' then 
                pcall(HLBG.Stats, decoded) 
                pcall(function()
                    DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG Debug:|r Called HLBG.Stats with decoded data')
                end)
            end
            
            if type(HLBG.OnServerStats) == 'function' then
                pcall(HLBG.OnServerStats, decoded)
                pcall(function()
                    DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG Debug:|r Called HLBG.OnServerStats with decoded data')
                end)
            end
            
            -- Force update stats display if UI exists
            if HLBG.UI and HLBG.UI.Stats and HLBG.UI.Stats.Text then
                pcall(function()
                    local totalBattles = (decoded.counts and decoded.counts.Alliance or 0) + (decoded.counts and decoded.counts.Horde or 0) + (decoded.draws or 0)
                    HLBG.UI.Stats.Text:SetText(string.format('|cFF33FF99Stats:|r Battles %d  Alliance Wins %d  Horde Wins %d  Draws %d',
                        totalBattles,
                        decoded.counts and decoded.counts.Alliance or 0,
                        decoded.counts and decoded.counts.Horde or 0,
                        decoded.draws or 0))
                    DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG Debug:|r Directly updated Stats UI text')
                end)
            end
            
        else
            pcall(function()
                DEFAULT_CHAT_FRAME:AddMessage('|cFFFF5555HLBG Debug:|r JSON decode failed: ' .. tostring(decoded))
            end)
        end
        return
    end
end)

-- Slash command to force reparse last sanitized TSV (dev aid)
SLASH_HLBGREPARSE1 = '/hlbgreparse'
SlashCmdList['HLBGREPARSE'] = function()
    local tsv = HLBG._lastSanitizedTSV
    if not tsv or tsv == '' then
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG:|r No last sanitized TSV to reparse') end
        return
    end
    if type(HLBG.HistoryStr) == 'function' then
        local ok, err = pcall(HLBG.HistoryStr, tsv, 1, (HLBG.UI and HLBG.UI.History and HLBG.UI.History.per) or 15, (HLBG.UI and HLBG.UI.History and HLBG.UI.History.total) or 0, 'id', 'DESC')
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            if ok then
                DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG:|r Reparse invoked')
            else
                DEFAULT_CHAT_FRAME:AddMessage('|cFFFF5555HLBG:|r Reparse error '..tostring(err))
            end
        end
    end
end

-- Slash command to check HLBG functions and force test
SLASH_HLBGTEST1 = '/hlbgtest'
SlashCmdList['HLBGTEST'] = function()
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(string.format('|cFF33FF99HLBG Test:|r HistoryStr type: %s', type(HLBG.HistoryStr)))
        DEFAULT_CHAT_FRAME:AddMessage(string.format('|cFF33FF99HLBG Test:|r History type: %s', type(HLBG.History)))
        local keys = {}
        for k,v in pairs(HLBG or {}) do
            keys[#keys + 1] = tostring(k)
        end
        DEFAULT_CHAT_FRAME:AddMessage(string.format('|cFF33FF99HLBG Test:|r HLBG keys: %s', table.concat(keys, ', ')))
        if type(HLBG.HistoryStr) == 'function' then
            local testTSV = "1\t1\tSeason 1: Test\t2025-10-07 20:00:00\tDraw\t0\tmanual\n2\t1\tSeason 1: Test\t2025-10-07 19:00:00\tAlliance\t1\tauto"
            local ok, err = pcall(HLBG.HistoryStr, testTSV, 1, 15, 2, 'id', 'DESC')
            if ok then
                DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG Test:|r HistoryStr test call succeeded')
            else
                DEFAULT_CHAT_FRAME:AddMessage('|cFFFF5555HLBG Test:|r HistoryStr test error: '..tostring(err))
            end
        else
            -- Try to manually load the History module
            DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG Test:|r Attempting to load History module manually...')
        end
    end
end

-- Force show HLBG window and create tabs manually
SLASH_HLBGSHOW1 = '/hlbgshow'
SlashCmdList['HLBGSHOW'] = function()
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG:|r Attempting to show HLBG window and create tabs...')
        
        -- Try to show main frame
        if HLBG.UI and HLBG.UI.Frame then
            HLBG.UI.Frame:Show()
            DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG:|r Main frame shown')
        else
            DEFAULT_CHAT_FRAME:AddMessage('|cFFFF5555HLBG:|r No main frame found')
        end
        
        -- Check for tabs
        if HLBG.UI and HLBG.UI.Tabs then
            HLBG.UI.Tabs:Show()
            DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG:|r Tabs container shown')
        else
            DEFAULT_CHAT_FRAME:AddMessage('|cFFFF5555HLBG:|r No tabs container found')
        end
        
        -- Try to force create History UI
        if type(HLBG._ensureUI) == 'function' then
            pcall(HLBG._ensureUI, 'History')
            DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG:|r Attempted to ensure History UI')
        end
        
        -- Try UpdateHistoryDisplay if available
        if type(HLBG.UpdateHistoryDisplay) == 'function' then
            pcall(HLBG.UpdateHistoryDisplay)
            DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG:|r Attempted UpdateHistoryDisplay')
        end
        
        -- Show tab status
        local tabCount = 0
        if HLBG.UI and HLBG.UI.Tabs then
            for i=1,10 do
                local tab = _G["HLBG_Tab_"..i]
                if tab then tabCount = tabCount + 1 end
            end
        end
        DEFAULT_CHAT_FRAME:AddMessage(string.format('|cFF33FF99HLBG:|r Found %d tabs', tabCount))
        
        -- Report stored data
        local rowCount = HLBG and HLBG.UI and HLBG.UI.History and HLBG.UI.History.lastRows and #HLBG.UI.History.lastRows or 0
        DEFAULT_CHAT_FRAME:AddMessage(string.format('|cFF33FF99HLBG:|r Stored rows: %d', rowCount))
    end
end

-- Simple emergency window
SLASH_HLBGTABS1 = '/hlbgtabs'
SlashCmdList['HLBGTABS'] = function()
    local ok, err = pcall(function()
        DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG:|r Creating emergency window...')
        
        -- Simple basic frame
        local frame = CreateFrame("Frame", "HLBG_Emergency", UIParent)
        frame:SetSize(500, 300)
        frame:SetPoint("CENTER")
        frame:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border", 
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        frame:SetBackdropColor(0, 0, 0, 0.9)
        frame:EnableMouse(true)
        frame:SetMovable(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", function() frame:StartMoving() end)
        frame:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
        
        -- Title
        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", frame, "TOP", 0, -15)
        title:SetText("HLBG History Data")
        
        -- Close button
        local close = CreateFrame("Button", nil, frame)
        close:SetSize(20, 20)
        close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
        close:SetNormalTexture("Interface/Buttons/UI-Panel-MinimizeButton-Up")
        close:SetScript("OnClick", function() frame:Hide() end)
        
        -- Content area
        local scroll = CreateFrame("ScrollFrame", nil, frame)
        scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -40)
        scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -15, 15)
        
        local content = CreateFrame("Frame", nil, scroll)
        content:SetSize(460, 1000)
        scroll:SetScrollChild(content)
        
        -- Show stored data
        local rowCount = HLBG and HLBG.UI and HLBG.UI.History and HLBG.UI.History.lastRows and #HLBG.UI.History.lastRows or 0
        
        local y = -10
        local info = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        info:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        info:SetText(string.format("Stored History Rows: %d", rowCount))
        y = y - 25
        
        if rowCount > 0 and HLBG.UI.History and HLBG.UI.History.lastRows then
            for i, row in ipairs(HLBG.UI.History.lastRows) do
                local rowText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                rowText:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
                rowText:SetWidth(450)
                rowText:SetJustifyH("LEFT")
                rowText:SetText(string.format("#%s: %s - %s vs %s (%s)", 
                    row.id or '?', 
                    row.seasonName or '?', 
                    row.winner or '?', 
                    row.affix or '?',
                    row.reason or '?'
                ))
                y = y - 18
                if i >= 20 then break end -- Limit display
            end
        else
            local noData = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            noData:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
            noData:SetText("No history data found in HLBG.UI.History.lastRows")
        end
        
        frame:Show()
        DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG:|r Emergency window created and shown!')
    end)
    
    if not ok then
        DEFAULT_CHAT_FRAME:AddMessage('|cFFFF5555HLBG:|r Emergency window error: ' .. tostring(err))
    end
end

-- Fix main addon window
SLASH_HLBGFIX1 = '/hlbgfix'
SlashCmdList['HLBGFIX'] = function()
    DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG:|r Attempting to fix main addon window...')
    
    -- Check main addon state
    local hasMainFrame = HLBG and HLBG.UI and HLBG.UI.Frame
    local hasHistoryFrame = hasMainFrame and HLBG.UI.History
    local hasData = hasHistoryFrame and HLBG.UI.History.lastRows and #HLBG.UI.History.lastRows > 0
    local hasUpdateFunction = type(HLBG.UpdateHistoryDisplay) == 'function'
    
    DEFAULT_CHAT_FRAME:AddMessage(string.format('|cFF33FF99HLBG:|r Main frame: %s, History frame: %s, Data: %s (%d rows), Update function: %s',
        hasMainFrame and "YES" or "NO",
        hasHistoryFrame and "YES" or "NO", 
        hasData and "YES" or "NO",
        hasData and #HLBG.UI.History.lastRows or 0,
        hasUpdateFunction and "YES" or "NO"
    ))
    
    if hasMainFrame then
        -- Show main frame and focus history tab
        HLBG.UI.Frame:Show()
        if HLBG.UI.Tabs and HLBG.UI.Tabs[1] then
            -- Click first tab (History)
            if HLBG.UI.Tabs[1]:GetScript("OnClick") then
                HLBG.UI.Tabs[1]:GetScript("OnClick")(HLBG.UI.Tabs[1])
                DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG:|r Clicked History tab')
            end
        end
        
        -- Force update display if we have data
        if hasData and hasUpdateFunction then
            pcall(function() 
                HLBG.UpdateHistoryDisplay() 
                DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG:|r Called UpdateHistoryDisplay()')
            end)
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage('|cFFFF5555HLBG:|r Main frame not found - addon may not be loaded properly')
    end
end

-- Complete UI System Fix
SLASH_HLBGFULLFIX1 = '/hlbgfullfix'
SlashCmdList['HLBGFULLFIX'] = function()
    DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG:|r Performing complete UI system fix...')
    
    -- Step 1: AGGRESSIVELY disable ALL Modern UI functions
    if HLBG.ApplyModernStyling then 
        HLBG.ApplyModernStyling = function() 
            DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG:|r Modern styling blocked!')
        end
    end
    if HLBG.ModernizeContentAreas then
        HLBG.ModernizeContentAreas = function() 
            DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG:|r ModernizeContentAreas blocked!')
        end
    end
    if HLBG.UpdateModernTabStyling then
        HLBG.UpdateModernTabStyling = function() end
    end
    if HLBG.CreateModernStatsCards then
        HLBG.CreateModernStatsCards = function() end
    end
    DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG:|r Disabled ALL Modern UI systems aggressively')
    
    -- Step 2: Hide any conflicting HUD/windows
    if _G["HLBG_Rebuilt"] then _G["HLBG_Rebuilt"]:Hide() end
    if _G["HLBG_ModernHUD"] then _G["HLBG_ModernHUD"]:Hide() end
    
    -- Step 3: Ensure main frame exists and is properly configured
    if not (HLBG and HLBG.UI and HLBG.UI.Frame) then
        DEFAULT_CHAT_FRAME:AddMessage('|cFFFF5555HLBG:|r Creating main frame - original was missing')
        HLBG.UI = HLBG.UI or {}
        HLBG.UI.Frame = CreateFrame("Frame", "HLBG_Fixed", UIParent)
        HLBG.UI.Frame:SetSize(600, 400)
        HLBG.UI.Frame:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        HLBG.UI.Frame:SetBackdropColor(0, 0, 0, 0.8)
    end
    
    -- Step 4: Fix frame positioning and show it
    HLBG.UI.Frame:ClearAllPoints()
    HLBG.UI.Frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    HLBG.UI.Frame:SetFrameStrata("HIGH")
    HLBG.UI.Frame:SetFrameLevel(100)
    HLBG.UI.Frame:Show()
    
    -- Step 5: Create or fix tabs with proper positioning INSIDE the frame
    HLBG.UI.Tabs = HLBG.UI.Tabs or {}
    local tabNames = {"History", "Stats", "Info", "Settings", "Queue"}
    
    for i = 1, 5 do
        -- Create tab if it doesn't exist
        if not HLBG.UI.Tabs[i] then
            HLBG.UI.Tabs[i] = CreateFrame("Button", "HLBG_Tab"..i, HLBG.UI.Frame)
        end
        
        local tab = HLBG.UI.Tabs[i]
        tab:ClearAllPoints()
        
        -- Position INSIDE the frame, not below it
        if i == 1 then
            tab:SetPoint("TOPLEFT", HLBG.UI.Frame, "TOPLEFT", 20, -40)
        else
            tab:SetPoint("LEFT", HLBG.UI.Tabs[i-1], "RIGHT", 5, 0)
        end
        
        tab:SetSize(80, 25)
        tab:SetText(tabNames[i])
        tab:SetNormalFontObject("GameFontNormal")
        
        -- Clear any existing backdrop and add a simple visible one
        tab:SetBackdrop(nil)
        tab:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background"})
        tab:SetBackdropColor(0.2, 0.2, 0.2, 0.9)
        
        -- Ensure tab is visible and clickable
        tab:SetFrameStrata("HIGH")
        tab:SetFrameLevel(101)
        tab:EnableMouse(true)
        tab:Show()
        
        -- Set click handler
        if i == 1 then -- History tab
            tab:SetScript("OnClick", function()
                -- Highlight this tab
                tab:SetBackdropColor(0.4, 0.4, 0.4, 0.9)
                -- Dim other tabs
                for j = 2, 5 do
                    if HLBG.UI.Tabs[j] then
                        HLBG.UI.Tabs[j]:SetBackdropColor(0.2, 0.2, 0.2, 0.9)
                    end
                end
                
                -- Show history content
                if HLBG.UI.History then
                    HLBG.UI.History:Show()
                    -- Call original update function if it exists
                    if type(HLBG.UpdateHistoryDisplay) == 'function' then
                        pcall(HLBG.UpdateHistoryDisplay)
                    end
                    DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG:|r History tab activated')
                end
                
                -- Hide other content
                if HLBG.UI.Stats then HLBG.UI.Stats:Hide() end
                if HLBG.UI.Info then HLBG.UI.Info:Hide() end
                if HLBG.UI.Settings then HLBG.UI.Settings:Hide() end
                if HLBG.UI.Queue then HLBG.UI.Queue:Hide() end
            end)
        elseif i == 2 then -- Stats tab
            tab:SetScript("OnClick", function()
                tab:SetBackdropColor(0.4, 0.4, 0.4, 0.9)
                HLBG.UI.Tabs[1]:SetBackdropColor(0.2, 0.2, 0.2, 0.9)
                for j = 3, 5 do
                    if HLBG.UI.Tabs[j] then HLBG.UI.Tabs[j]:SetBackdropColor(0.2, 0.2, 0.2, 0.9) end
                end
                
                if HLBG.UI.Stats then HLBG.UI.Stats:Show() end
                if HLBG.UI.History then HLBG.UI.History:Hide() end
                DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG:|r Stats tab activated')
            end)
        else -- Other tabs
            tab:SetScript("OnClick", function()
                DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG:|r '..tabNames[i]..' tab clicked (content not implemented yet)')
            end)
        end
    end
    
    DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG:|r Fixed all 5 tabs with proper positioning and visibility')
    
    -- Step 6: Activate History tab by default
    if HLBG.UI.Tabs[1] then
        HLBG.UI.Tabs[1]:GetScript("OnClick")(HLBG.UI.Tabs[1])
    end
    
    -- Step 7: Add close button if missing
    if not HLBG.UI.Frame.closeBtn then
        local close = CreateFrame("Button", nil, HLBG.UI.Frame)
        close:SetSize(20, 20)
        close:SetPoint("TOPRIGHT", HLBG.UI.Frame, "TOPRIGHT", -10, -10)
        close:SetNormalTexture("Interface/Buttons/UI-Panel-MinimizeButton-Up")
        close:SetScript("OnClick", function() HLBG.UI.Frame:Hide() end)
        HLBG.UI.Frame.closeBtn = close
    end
    
    DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG:|r Complete UI fix applied - tabs should now be visible and functional!')
end

-- Nuclear option: Show absolutely minimal working UI 
SLASH_HLBGNUCLEAR1 = '/hlbgnuclear'
SlashCmdList['HLBGNUCLEAR'] = function()
    DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG:|r NUCLEAR OPTION: Creating completely isolated UI...')
    
    -- Disable everything that might interfere
    HLBG.ApplyModernStyling = function() end
    HLBG.ModernizeContentAreas = function() end
    HLBG.UpdateModernTabStyling = function() end
    HLBG.CreateModernStatsCards = function() end
    
    -- Hide any existing conflicting frames
    for _, frameName in ipairs({"HLBG_Main", "HLBG_Fixed", "HLBG_Rebuilt", "HLBG_ModernHUD"}) do
        local frame = _G[frameName]
        if frame and frame.Hide then frame:Hide() end
    end
    
    -- Create completely new, isolated frame 
    local frame = CreateFrame("Frame", "HLBG_Nuclear", UIParent)
    frame:SetSize(600, 400)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(1000) -- Very high level to ensure visibility
    
    -- Bright, obvious background so we can see it
    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(0.1, 0.1, 0.5, 0.9) -- Dark blue so we can see it
    frame:SetBackdropBorderColor(1, 1, 1, 1) -- White border
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -15)
    title:SetText("HLBG - Nuclear Mode")
    title:SetTextColor(1, 1, 1, 1) -- White text
    
    -- Close button 
    local close = CreateFrame("Button", nil, frame)
    close:SetSize(20, 20)
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
    close:SetNormalTexture("Interface/Buttons/UI-Panel-MinimizeButton-Up")
    close:SetScript("OnClick", function() frame:Hide() end)
    
    -- Create super simple tabs
    local tabs = {}
    local tabNames = {"History", "Stats"}
    local currentContent = nil
    
    for i = 1, 2 do
        local tab = CreateFrame("Button", nil, frame)
        tab:SetSize(100, 30)
        tab:SetPoint("TOPLEFT", frame, "TOPLEFT", 20 + ((i-1) * 105), -50)
        tab:SetText(tabNames[i])
        tab:SetNormalFontObject("GameFontNormal")
        
        -- Very visible tab background
        tab:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background"})
        tab:SetBackdropColor(0.3, 0.3, 0.3, 1)
        tab:SetFrameLevel(1001)
        
        tab:SetScript("OnClick", function()
            -- Clear previous content
            if currentContent then currentContent:Hide() end
            
            -- Highlight clicked tab
            for j, t in ipairs(tabs) do
                t:SetBackdropColor(j == i and 0.5 or 0.3, j == i and 0.5 or 0.3, j == i and 0.5 or 0.3, 1)
            end
            
            -- Create content area for this tab
            currentContent = CreateFrame("Frame", nil, frame)
            currentContent:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -90)
            currentContent:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 20)
            currentContent:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background"})
            currentContent:SetBackdropColor(0.05, 0.05, 0.2, 0.9) -- Dark blue content area
            currentContent:SetFrameLevel(1002)
            
            if i == 1 then -- History tab
                local text = currentContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                text:SetPoint("TOPLEFT", currentContent, "TOPLEFT", 10, -10)
                text:SetText("Battle History:")
                text:SetTextColor(1, 1, 1, 1)
                
                -- Show actual data from memory if available
                local rowCount = HLBG and HLBG.UI and HLBG.UI.History and HLBG.UI.History.lastRows and #HLBG.UI.History.lastRows or 0
                local dataText = currentContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                dataText:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -10)
                dataText:SetWidth(550)
                dataText:SetJustifyH("LEFT")
                dataText:SetTextColor(0.8, 0.8, 1, 1)
                
                if rowCount > 0 then
                    local lines = {string.format("Found %d stored battle entries:", rowCount)}
                    for j, row in ipairs(HLBG.UI.History.lastRows) do
                        if j > 10 then break end -- Limit display
                        table.insert(lines, string.format("#%s: %s (%s)", row.id or '?', row.winner or '?', row.reason or '?'))
                    end
                    dataText:SetText(table.concat(lines, "\n"))
                else
                    dataText:SetText("No battle history found in memory")
                end
                
            elseif i == 2 then -- Stats tab
                local text = currentContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                text:SetPoint("TOPLEFT", currentContent, "TOPLEFT", 10, -10)
                text:SetText("Statistics: Stats tab functionality not implemented in nuclear mode")
                text:SetTextColor(1, 1, 1, 1)
            end
            
            currentContent:Show()
            DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG:|r Nuclear mode - '..tabNames[i]..' tab activated')
        end)
        
        tabs[i] = tab
    end
    
    -- Show frame and activate History tab
    frame:Show()
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() frame:StartMoving() end)
    frame:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    
    -- Auto-click History tab
    tabs[1]:GetScript("OnClick")(tabs[1])
    
    DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG:|r Nuclear mode activated - completely isolated UI should now be visible!')
end

-- Request full history data from server
SLASH_HLBGREFRESH1 = '/hlbgrefresh'  
SlashCmdList['HLBGREFRESH'] = function()
    DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG:|r Requesting fresh data from server...')
    
    -- Request new data
    if type(SendAddonMessage) == 'function' then
        pcall(function()
            SendAddonMessage("HLBG_REQUEST", "HISTORY", "WHISPER", UnitName("player"))
            SendAddonMessage("HLBG_REQUEST", "STATS", "WHISPER", UnitName("player")) 
            DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG:|r Sent data requests via addon messages')
        end)
    end
    
    -- Also try slash command fallbacks
    pcall(function()
        SendChatMessage(".hlbg history", "GUILD")
        SendChatMessage(".hlbg stats", "GUILD") 
        DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG:|r Sent fallback chat commands')
    end)
end

-- Emergency: Enhanced HistoryStr function to properly handle TSV data and display
HLBG.HistoryStr = HLBG.HistoryStr or function(tsv, page, per, total, sortKey, sortDir)
    pcall(function()
        DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG Emergency:|r HistoryStr called with TSV length: ' .. (tsv and #tsv or 0))
    end)
    
    local rows = {}
    if type(tsv) == 'string' and tsv ~= '' then
        -- Enhanced sanitization: convert pipes to newlines if needed
        tsv = tsv:gsub('%|%|', '\n')  
        if tsv:find('|') and not tsv:find('\n') then
            tsv = tsv:gsub('|', '\n')
        end
        
        -- Parse TSV lines with better error handling
        for line in tsv:gmatch('[^\n]+') do
            line = line:gsub('^%s+',''):gsub('%s+$','') -- trim whitespace
            if line ~= '' and not line:match('^%s*$') then -- skip empty lines
                local cols = {}
                -- Handle both tab and space-separated values
                if line:find('\t') then
                    for col in line:gmatch('[^\t]+') do
                        local trimmed = col:gsub('^%s+',''):gsub('%s+$','')
                        if trimmed ~= '' then
                            cols[#cols + 1] = trimmed
                        end
                    end
                else
                    -- Fallback: split on multiple spaces
                    for col in line:gmatch('%S+') do
                        cols[#cols + 1] = col
                    end
                end
                
                -- Create row if we have enough columns
                if #cols >= 4 then
                    rows[#rows + 1] = {
                        id = cols[1] or '',
                        season = cols[2] or '1',
                        seasonName = cols[3] or 'Season 1',
                        ts = cols[4] or '',
                        winner = cols[5] or 'Unknown',
                        affix = cols[6] or '0',
                        reason = cols[7] or 'unknown'
                    }
                end
            end
        end
    end
    
    pcall(function()
        DEFAULT_CHAT_FRAME:AddMessage(string.format('|cFF33FF99HLBG Emergency:|r Parsed %d rows from TSV', #rows))
        if #rows > 0 then
            DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG Emergency:|r First row: ID=' .. (rows[1].id or 'nil') .. ', Winner=' .. (rows[1].winner or 'nil') .. ', Season=' .. (rows[1].seasonName or 'nil'))
        end
    end)
    
    -- Store rows in UI system
    HLBG.UI = HLBG.UI or {}
    HLBG.UI.History = HLBG.UI.History or {}
    HLBG.UI.History.lastRows = rows
    HLBG.UI.History.page = tonumber(page) or 1
    HLBG.UI.History.per = tonumber(per) or 15
    HLBG.UI.History.total = tonumber(total) or #rows
    
    -- Try calling the real History function if available
    if type(HLBG.History) == 'function' then
        pcall(function()
            HLBG.History(rows, page, per, total, sortKey, sortDir)
            DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG Emergency:|r Called HLBG.History with parsed rows')
        end)
    end
    
    -- Try to render/update display
    if type(HLBG.UpdateHistoryDisplay) == 'function' then
        pcall(function()
            HLBG.UpdateHistoryDisplay()
            DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG Emergency:|r Called UpdateHistoryDisplay')
        end)
    end
    
    -- Force show main UI if available and populated
    if #rows > 0 and HLBG.UI and HLBG.UI.Frame then
        pcall(function()
            HLBG.UI.Frame:Show()
            -- Click history tab if available
            if HLBG.UI.Tabs and HLBG.UI.Tabs[1] and HLBG.UI.Tabs[1]:GetScript("OnClick") then
                HLBG.UI.Tabs[1]:GetScript("OnClick")(HLBG.UI.Tabs[1])
            end
            DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG Emergency:|r Attempted to show UI with ' .. #rows .. ' history rows')
        end)
    end
    
    return rows -- Return parsed data for any caller that needs it
end

-- expose helpers for other files
HLBG.EnsurePvPTab = EnsurePvPTab
HLBG.EnsurePvPHeaderButton = EnsurePvPHeaderButton

_G.HLBG = HLBG
