-- HLBG_Handlers.lua
local HLBG = _G.HLBG or {}; _G.HLBG = HLBG
local function DebugPrint(...)
    if HLBG and type(HLBG.Debug) == 'function' then
        HLBG.Debug(...)
    end
end
-- Shared live resources state. Initialize to avoid nil indexing when STATUS messages arrive.
RES = RES or {}
HLBG.RES = HLBG.RES or RES
-- Debug buffer: SavedVariables-backed ring buffer for developer diagnostics
DCHLBG_DebugLog = DCHLBG_DebugLog or {}
HLBG.DebugBuffer = HLBG.DebugBuffer or DCHLBG_DebugLog
HLBG._debugMax = HLBG._debugMax or 500
-- Safe serializer (limited depth, detects cycles, truncates long strings)
local function _safeSerialize(val, depth, seen)
    depth = depth or 0
    seen = seen or {}
    if depth > 4 then return '...<depth>' end
    local t = type(val)
    if t == 'nil' then return 'nil' end
    if t == 'number' or t == 'boolean' then return tostring(val) end
    if t == 'string' then
        local s = val:gsub('\n','\\n'):gsub('\r','\\r')
        if #s > 500 then s = s:sub(1,500) .. '...[truncated]' end
        return string.format('%q', s)
    end
    if t == 'table' then
        if seen[val] then return '<cycle>' end
        seen[val] = true
        local parts = {}
        local n = 0
        for k, v in pairs(val) do
            n = n + 1
            if n > 50 then
                parts[#parts+1] = '...<more>'
                break
            end
            local ks = (type(k) == 'string' and k) or tostring(k)
            parts[#parts+1] = ks .. '=' .. _safeSerialize(v, depth + 1, seen)
        end
        return '{' .. table.concat(parts, ',') .. '}'
    end
    return '<' .. t .. '>'
end
-- Push an entry into the SavedVariables-backed debug log (newest first)
function HLBG.DebugLog(kind, payload)
    local ok, ts = pcall(function() return time() end)
    ts = (ok and ts) or 0
    local entry = { ts = ts, kind = tostring(kind or 'LOG'), data = nil }
    if type(payload) == 'table' then
        entry.data = _safeSerialize(payload)
    else
        local s = tostring(payload or '')
        if #s > 1000 then s = s:sub(1,1000) .. '...[truncated]' end
        entry.data = s
    end
    DCHLBG_DebugLog = DCHLBG_DebugLog or {}
    table.insert(DCHLBG_DebugLog, 1, entry)
    while #DCHLBG_DebugLog > (HLBG._debugMax or 500) do table.remove(DCHLBG_DebugLog) end
    HLBG.DebugBuffer = DCHLBG_DebugLog
    return entry
end
-- Runtime toggle for capture independent of devMode
HLBG._captureIncoming = HLBG._captureIncoming or false
-- Slash commands to inspect/clear the buffer
SLASH_HLBGDUMP1 = '/hlbgdumpbuf'
SLASH_HLBGDUMP2 = '.hlbgdumpbuf'
SlashCmdList['HLBGDUMP'] = function(msg)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG:|r Debug buffer size: ' .. tostring(#(DCHLBG_DebugLog or {})))
        for i = 1, math.min(20, #DCHLBG_DebugLog) do
            local e = DCHLBG_DebugLog[i]
            DEFAULT_CHAT_FRAME:AddMessage(string.format('|cFFFFCC66[%d]|r %s %s', i, tostring(e.ts or 0), tostring((e.kind or '')) ) )
            DEFAULT_CHAT_FRAME:AddMessage('  ' .. (tostring(e.data or ''):sub(1,400)))
        end
    end
end
SLASH_HLBGCLR1 = '/hlbgclearbuf'
SLASH_HLBGCLR2 = '.hlbgclearbuf'
SlashCmdList['HLBGCLR'] = function()
    DCHLBG_DebugLog = {}
    HLBG.DebugBuffer = DCHLBG_DebugLog
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG:|r Debug buffer cleared') end
end
-- Small helper to show a debug UI window listing recent entries
function HLBG.ShowDebugWindow()
    pcall(function()
        if _G['HLBG_DebugWindow'] and _G['HLBG_DebugWindow'].Show then _G['HLBG_DebugWindow']:Show(); return end
        local frame = CreateFrame('Frame', 'HLBG_DebugWindow', UIParent)
        frame:SetSize(600, 360)
        frame:SetPoint('CENTER')
        frame:SetBackdrop({ bgFile = 'Interface/Tooltips/UI-Tooltip-Background', edgeFile = 'Interface/Tooltips/UI-Tooltip-Border', tile=true, tileSize=16, edgeSize=16 })
        frame:SetBackdropColor(0,0,0,0.92)
        frame:EnableMouse(true)
        frame:SetMovable(true)
        frame:RegisterForDrag('LeftButton')
        frame:SetScript('OnDragStart', function(s) s:StartMoving() end)
        frame:SetScript('OnDragStop', function(s) s:StopMovingOrSizing() end)
        local title = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
        title:SetPoint('TOP', frame, 'TOP', 0, -12)
        title:SetText('HLBG Debug Buffer')
        local close = CreateFrame('Button', nil, frame)
        close:SetSize(20,20)
        close:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -8, -8)
        close:SetNormalTexture('Interface/Buttons/UI-Panel-MinimizeButton-Up')
        close:SetScript('OnClick', function() frame:Hide() end)
        local dumpBtn = CreateFrame('Button', nil, frame, 'UIPanelButtonTemplate')
        dumpBtn:SetSize(120, 24)
        dumpBtn:SetPoint('TOPLEFT', frame, 'TOPLEFT', 12, -36)
        dumpBtn:SetText('Clear Buffer')
        dumpBtn:SetScript('OnClick', function()
            DCHLBG_DebugLog = {}
            HLBG.DebugBuffer = DCHLBG_DebugLog
        end)
        local scroll = CreateFrame('ScrollFrame', nil, frame)
        scroll:SetPoint('TOPLEFT', frame, 'TOPLEFT', 12, -68)
        scroll:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -12, 12)
        local content = CreateFrame('Frame', nil, scroll)
        content:SetSize(560, 1)
        scroll:SetScrollChild(content)
        local y = -6
        for i = 1, math.min(#(DCHLBG_DebugLog or {}), 200) do
            local e = DCHLBG_DebugLog[i]
            if not e then break end
            local line = content:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
            line:SetPoint('TOPLEFT', content, 'TOPLEFT', 4, y)
            line:SetJustifyH('LEFT')
            line:SetWidth(540)
            local ts = tostring(e.ts or 0)
            line:SetText(string.format('#%d [%s] %s', i, ts, tostring(e.kind or '') .. ' ' .. (tostring(e.data or ''):sub(1,300))))
            y = y - 18
        end
        frame:Show()
    end)
end
-- Zone watcher: show/hide HUD when entering Hinterlands
local function InHinterlands()
    local z = (type(HLBG) == 'table' and type(HLBG.safeGetRealZoneText) == 'function')
        and HLBG.safeGetRealZoneText()
        or (GetRealZoneText and GetRealZoneText() or "")
    local sz = (GetSubZoneText and GetSubZoneText() or "")

    local zl = tostring(z or ""):lower()
    local szl = tostring(sz or ""):lower()
    if zl == "the hinterlands" then
        return true
    end
    if zl:find("hinterland", 1, true) then
        return true
    end
    if szl:find("hinterland", 1, true) or szl:find("azshara crater", 1, true) then
        return true
    end
    return false
end
local zoneWatcher = CreateFrame("Frame")
zoneWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
zoneWatcher:RegisterEvent("ZONE_CHANGED_NEW_AREA")
zoneWatcher:RegisterEvent("ZONE_CHANGED")
zoneWatcher:RegisterEvent("ZONE_CHANGED_INDOORS")
zoneWatcher:SetScript("OnEvent", function()
    if InHinterlands() then
        if type(HLBG.UpdateHUD) == 'function' then pcall(HLBG.UpdateHUD) end
        if DCHLBGDB and DCHLBGDB.useAddonHud and type(HLBG.HideBlizzHUDDeep) == 'function' then pcall(HLBG.HideBlizzHUDDeep) end
    else
        if HLBG.UI and HLBG.UI.HUD then pcall(function() HLBG.UI.HUD:Hide() end) end
        if HLBG.UI and HLBG.UI.Affix then pcall(function() HLBG.UI.Affix:Hide() end) end
        if type(HLBG.UnhideBlizzHUDDeep) == 'function' then pcall(HLBG.UnhideBlizzHUDDeep) end
    end
end)

-- =====================================================================
-- Unified request helpers (DCAddonProtocol -> AIO -> dot-command)
-- =====================================================================

function HLBG.RequestHistoryUI(page, per, season, sortKey, sortDir)
    page = tonumber(page) or 1
    per = tonumber(per) or 25
    if page < 1 then page = 1 end
    if per < 1 then per = 1 end
    if per > 20 then per = 20 end

    season = tonumber(season) or 0
    sortKey = tostring(sortKey or "id")
    sortDir = tostring(sortDir or "DESC")

    -- Keep UI state in sync so response handlers can render correctly
    HLBG.UI = HLBG.UI or {}
    HLBG.UI.History = HLBG.UI.History or {}
    HLBG.UI.History.page = page
    HLBG.UI.History.per = per
    HLBG.UI.History.sortKey = sortKey
    HLBG.UI.History.sortDir = sortDir

    local DC = rawget(_G, "DCAddonProtocol")
    if DC and type(DC.Send) == "function" then
        -- HLBG extended opcode: CMSG_REQUEST_HISTORY_UI (0x23 = 35 decimal)
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFF33FF99HLBG:|r Requesting history via DCAddonProtocol (opcode 35): page=%d, per=%d, season=%d", page, per, season))
        end
        DC:Send("HLBG", 0x23, tostring(page), tostring(per), tostring(season), sortKey, sortDir)
        return true
    end

    if _G.AIO and _G.AIO.Handle then
        _G.AIO.Handle("HLBG", "Request", "HISTORY", page, per, season, sortKey, sortDir)
        return true
    end

    local sendDot = (HLBG and HLBG.SendServerDot) or _G.HLBG_SendServerDot
    if type(sendDot) == 'function' then
        if season and season > 0 then
            sendDot(string.format('.hlbg historyui %d %d %d %s %s', page, per, season, sortKey, sortDir))
        else
            sendDot(string.format('.hlbg historyui %d %d %s %s', page, per, sortKey, sortDir))
        end
        return true
    end

    if type(HLBG.safeExecSlash) == 'function' then
        if season and season > 0 then
            HLBG.safeExecSlash(string.format('.hlbg historyui %d %d %d %s %s', page, per, season, sortKey, sortDir))
        else
            HLBG.safeExecSlash(string.format('.hlbg historyui %d %d %s %s', page, per, sortKey, sortDir))
        end
        return true
    end

    return false
end

-- Backwards-compatible alias used by some UI code
HLBG.RequestHistory = HLBG.RequestHistory or function()
    local hist = (HLBG and HLBG.UI and HLBG.UI.History) or {}
    local season = (HLBG and HLBG._getSeason and HLBG._getSeason()) or 0
    return HLBG.RequestHistoryUI(hist.page or 1, hist.per or 25, season, hist.sortKey or "id", hist.sortDir or "DESC")
end
-- Ensure PvP tab/button helpers (lazy creation)
local function EnsurePvPTab()
    local _pvp = _G["PVPParentFrame"] or _G["PVPFrame"]
    if not _pvp then return end
    if _G["PVPFrameTabHLBG"] then return end -- Already exists

    local baseName = _pvp:GetName() or "PVPFrame"
    local lastIdx = _pvp.numTabs or 2
    
    -- Try to find the real last tab if numTabs is unreliable
    local realLastTab = _G[baseName.."Tab"..lastIdx]
    if not realLastTab then
        -- Search backwards
        for i = lastIdx, 1, -1 do
            local t = _G[baseName.."Tab"..i]
            if t and t:IsShown() then
                realLastTab = t
                lastIdx = i
                break
            end
        end
    end

    local tab = CreateFrame("Button", "PVPFrameTabHLBG", _pvp, "CharacterFrameTabButtonTemplate")
    tab:SetText("HLBG")
    tab:SetID((lastIdx or 2) + 1)
    
    if realLastTab then 
        tab:SetPoint("LEFT", realLastTab, "RIGHT", -5, 0) 
    else 
        tab:SetPoint("TOPLEFT", _pvp, "BOTTOMLEFT", 10, 7) 
    end
    
    tab:SetScript("OnClick", function()
        if PVPFrameLeft then PVPFrameLeft:Hide() end
        if PVPFrameRight then PVPFrameRight:Hide() end
        if HLBG.UI and HLBG.UI.Frame then HLBG.UI.Frame:Show() end
    if type(ShowTab) == 'function' then pcall(ShowTab, DCHLBGDB and DCHLBGDB.lastInnerTab or 1) end
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
            sendDot('.hlbg historyui 1 25 id DESC')
            sendDot(string.format('.hlbg historyui %d %d %d %s %s', 1, 25, season, 'id', 'DESC'))
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
    if type(ShowTab) == 'function' then pcall(ShowTab, DCHLBGDB and DCHLBGDB.lastInnerTab or 1) end
        if _G.AIO and _G.AIO.Handle then
            local season = (HLBG and HLBG._getSeason and HLBG._getSeason()) or 0
            _G.AIO.Handle("HLBG", "Request", "HISTORY", HLBG.UI and HLBG.UI.History and HLBG.UI.History.page or 1, HLBG.UI and HLBG.UI.History and HLBG.UI.History.per or 25, HLBG.UI and HLBG.UI.History and HLBG.UI.History.sortKey or "id", HLBG.UI and HLBG.UI.History and HLBG.UI.History.sortDir or "DESC")
            _G.AIO.Handle("HLBG", "Request", "HISTORY", HLBG.UI and HLBG.UI.History and HLBG.UI.History.page or 1, HLBG.UI and HLBG.UI.History and HLBG.UI.History.per or 25, season, HLBG.UI and HLBG.UI.History and HLBG.UI.History.sortKey or "id", HLBG.UI and HLBG.UI.History and HLBG.UI.History.sortDir or "DESC")
            _G.AIO.Handle("HLBG", "Request", "STATS")
            _G.AIO.Handle("HLBG", "Request", "STATS", season)
        end
        local sendDot = (HLBG and HLBG.SendServerDot) or _G.HLBG_SendServerDot
        local season = (HLBG and HLBG._getSeason and HLBG._getSeason()) or 0
        if type(sendDot) == 'function' then
            sendDot('.hlbg live players')
            sendDot('.hlbg historyui 1 25 id DESC')
            sendDot(string.format('.hlbg historyui %d %d %d %s %s', 1, 25, season, 'id', 'DESC'))
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
    DCHLBG_DebugLog = DCHLBG_DebugLog or {}
    table.insert(DCHLBG_DebugLog, 1, string.format('[HLBG_SANITIZED] %s', s))
    while #DCHLBG_DebugLog > 500 do table.remove(DCHLBG_DebugLog) end
    end
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    local prefix, msg = ...
    if tostring(prefix) ~= "HLBG" then return end
    -- Optionally capture the raw incoming message into debug buffer
    pcall(function()
        local should = HLBG._captureIncoming or HLBG._devMode or (DCHLBGDB and DCHLBGDB.devMode)
        if should then
            HLBG.DebugLog('AIO_RAW', { prefix = prefix, msg = msg })
        end
    end)
    -- Dev: lightweight receipt log for addon messages (only when dev mode true)
    pcall(function()
        local dev = HLBG._devMode or (DCHLBGDB and DCHLBGDB.devMode)
        if dev and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            local preview = (type(msg)=='string' and (msg:sub(1,180) .. ( #msg>180 and '...[truncated]' or '' )) ) or tostring(msg)
            DebugPrint(string.format('|cFF33FF99HLBG Debug|r Received AIO msg prefix=%s len=%d preview=%s', tostring(prefix), (type(msg)=='string' and #msg) or 0, preview))
        end
    end)
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
        pcall(function() if HLBG._captureIncoming or HLBG._devMode or (DCHLBGDB and DCHLBGDB.devMode) then HLBG.DebugLog('STATUS', msg) end end)
        local A = tonumber(msg:match("A=(%d+)") or 0) or 0
        local H = tonumber(msg:match("H=(%d+)") or 0) or 0
        local ENDt = tonumber(msg:match("END=(%d+)") or 0) or 0
        local LOCK = tonumber(msg:match("LOCK=(%d+)") or 0) or 0
        local APC = tonumber(msg:match("APC=(%d+)") or "")
        local HPC = tonumber(msg:match("HPC=(%d+)") or "")
        -- EXTENSIVE DEBUG: Log parsed values
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage and (HLBG._devMode or (DCHLBGDB and DCHLBGDB.devMode)) then
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFF00FFFF[HLBG STATUS PARSED]|r A=%d H=%d END=%d LOCK=%d", A, H, ENDt, LOCK))
        end
        RES.A = A; RES.H = H; RES.END = ENDt; RES.LOCK = LOCK
        -- Also store in HLBG._lastStatus for UpdateHUD compatibility
        HLBG._lastStatus = HLBG._lastStatus or {}
        HLBG._lastStatus.A = A
        HLBG._lastStatus.H = H
        HLBG._lastStatus.DURATION = ENDt
        if APC ~= nil then HLBG._lastStatus.APC = APC end
        if HPC ~= nil then HLBG._lastStatus.HPC = HPC end
        HLBG._lastStatus.allianceResources = A
        HLBG._lastStatus.hordeResources = H
        HLBG._lastStatus.timeLeft = ENDt
        HLBG._lastStatus.END = ENDt  -- Store END time for HUD visibility check
        HLBG._lastStatusTime = GetTime()  -- Track when we last received a STATUS message
        -- EXTENSIVE DEBUG: Confirm storage
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage and (HLBG._devMode or (DCHLBGDB and DCHLBGDB.devMode)) then
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFF00FFFF[HLBG STATUS STORED]|r _lastStatus.A=%s RES.A=%s", tostring(HLBG._lastStatus.A), tostring(RES.A)))
        end
        -- Update HUD visibility since we just received a STATUS message (we're definitely in BG now)
        if type(HLBG.UpdateHUDVisibility) == 'function' then
            pcall(HLBG.UpdateHUDVisibility)
        end
        -- EXTENSIVE DEBUG: Check UpdateHUD exists and call it
        if type(HLBG.UpdateHUD) == 'function' then
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage and (HLBG._devMode or (DCHLBGDB and DCHLBGDB.devMode)) then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[HLBG STATUS]|r Calling UpdateHUD...")
            end
            pcall(HLBG.UpdateHUD)
        else
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage and (HLBG._devMode or (DCHLBGDB and DCHLBGDB.devMode)) then
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[HLBG STATUS ERROR]|r UpdateHUD not found! Type: " .. type(HLBG.UpdateHUD))
            end
        end
        return
    end
    -- AFFIX messages
    local aff = msg:match("^AFFIX|(.*)$")
    if aff then
    pcall(function() if HLBG._captureIncoming or HLBG._devMode or (DCHLBGDB and DCHLBGDB.devMode) then HLBG.DebugLog('AFFIX', aff) end end)
        HLBG._affixText = tostring(aff)
        if type(HLBG.UpdateHUD) == 'function' then pcall(HLBG.UpdateHUD) end
        -- Always hide legacy floating chip to avoid duplicate Affix text
        if HLBG.UI and HLBG.UI.Affix then pcall(function() HLBG.UI.Affix:Hide() end) end
        return
    end
    -- Warmup notice
    local warm = msg:match('%[HLBG_WARMUP%]%s*(.*)')
    if warm then if type(HLBG.Warmup) == 'function' then pcall(HLBG.Warmup, warm) end; return end
    pcall(function() if HLBG._captureIncoming or HLBG._devMode or (DCHLBGDB and DCHLBGDB.devMode) then HLBG.DebugLog('WARMUP', warm) end end)
    -- Queue status
    local q = msg:match('%[HLBG_QUEUE%]%s*(.*)')
    if q then if type(HLBG.QueueStatus) == 'function' then pcall(HLBG.QueueStatus, q) end; return end
    pcall(function() if HLBG._captureIncoming or HLBG._devMode or (DCHLBGDB and DCHLBGDB.devMode) then HLBG.DebugLog('QUEUE', q) end end)
    -- Results JSON
    local rj = msg:match('%[HLBG_RESULTS_JSON%]%s*(.*)')
    if rj then
        local ok, decoded = pcall(function()
            return (HLBG.json_decode and HLBG.json_decode(rj)) or (type(json_decode) == 'function' and json_decode(rj)) or nil
        end)
    pcall(function() if HLBG._captureIncoming or HLBG._devMode or (DCHLBGDB and DCHLBGDB.devMode) then HLBG.DebugLog('RESULTS_JSON', { raw = rj, parsed = ok and decoded or nil }) end end)
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
    pcall(function() if HLBG._captureIncoming or HLBG._devMode or (DCHLBGDB and DCHLBGDB.devMode) then HLBG.DebugLog('HISTORY_TSV_RAW', htsv) end end)
    local total = tonumber((htsv:match('^TOTAL=(%d+)%s*%|%|') or htsv:match('^TOTAL=(%d+)%s*') or 0)) or 0
    htsv = htsv:gsub('^TOTAL=%d+%s*%|%|', ''):gsub('^TOTAL=%d+%s*', '')
    -- Convert common row separators into real newlines. Some servers use '||' or single '|' between rows.
    htsv = htsv:gsub('%|%|', '\n')
    -- Dev-only: report whether handler converted pipes into newlines
    pcall(function()
        local dev = HLBG._devMode or (DCHLBGDB and DCHLBGDB.devMode)
        if dev and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            local foundPipe = htsv:find('%|') and true or false
            local foundNl = htsv:find('\n') and true or false
            DebugPrint(string.format('|cFF33FF99HLBG Debug|r Handler sanitized: foundPipe=%s foundNewline=%s', tostring(foundPipe), tostring(foundNl)))
        end
    end)
    if htsv:find('%|') and not htsv:find('\n') then htsv = htsv:gsub('%|', '\n') end
        if HLBG.UI and HLBG.UI.History and total and total > 0 then HLBG.UI.History.total = total end
    pcall(function() if HLBG._captureIncoming or HLBG._devMode or (DCHLBGDB and DCHLBGDB.devMode) then HLBG.DebugLog('HISTORY_TSV_POSTSANIT', { total = total, sanit = htsv }) end end)
        if type(HLBG.HistoryStr) == 'function' then pcall(HLBG.HistoryStr, htsv, 1, (HLBG.UI and HLBG.UI.History and HLBG.UI.History.per) or 5, total, 'id', 'DESC') end
        return
    end
    -- Stats JSON fallback
    local sj = msg:match('%[HLBG_STATS_JSON%]%s*(.*)')
    if sj then
        local ok, decoded = pcall(function()
            return (HLBG.json_decode and HLBG.json_decode(sj)) or (type(json_decode) == 'function' and json_decode(sj)) or nil
        end)
        pcall(function() if HLBG._captureIncoming or HLBG._devMode or (DCHLBGDB and DCHLBGDB.devMode) then HLBG.DebugLog('STATS_JSON', { raw = sj, parsed = ok and decoded or nil }) end end)
        if ok and type(decoded) == 'table' then
            if decoded.total and HLBG.UI and HLBG.UI.History then HLBG.UI.History.total = tonumber(decoded.total) or HLBG.UI.History.total end
            if type(HLBG.Stats) == 'function' then pcall(HLBG.Stats, decoded) end
        end
        return
    end
end)

-- Filter raw HLBG payload spam from chat (system/say/etc). Parsing is handled separately.
local function _ShouldFilterHLBGChatMessage(msg)
    if type(msg) ~= 'string' then return false end

    -- Tagged payloads
    if msg:find('[HLBG_', 1, true) then
        return true
    end

    -- Known malformed warmup string (server-side formatting mistake)
    local ml = msg:lower()
    if ml:find('warmup:', 1, true) and ml:find('seconds remaining', 1, true) and ml:find('{}', 1, true) then
        return true
    end

    return false
end

pcall(function()
    if type(ChatFrame_AddMessageEventFilter) ~= 'function' then return end
    local function _hlbgFilter(_, _, msg)
        if _ShouldFilterHLBGChatMessage(msg) then
            return true
        end
        return false
    end

    ChatFrame_AddMessageEventFilter('CHAT_MSG_SYSTEM', _hlbgFilter)
    ChatFrame_AddMessageEventFilter('CHAT_MSG_SAY', _hlbgFilter)
    ChatFrame_AddMessageEventFilter('CHAT_MSG_YELL', _hlbgFilter)
    ChatFrame_AddMessageEventFilter('CHAT_MSG_GUILD', _hlbgFilter)
    ChatFrame_AddMessageEventFilter('CHAT_MSG_PARTY', _hlbgFilter)
    ChatFrame_AddMessageEventFilter('CHAT_MSG_PARTY_LEADER', _hlbgFilter)
    ChatFrame_AddMessageEventFilter('CHAT_MSG_RAID', _hlbgFilter)
    ChatFrame_AddMessageEventFilter('CHAT_MSG_RAID_LEADER', _hlbgFilter)
    ChatFrame_AddMessageEventFilter('CHAT_MSG_WHISPER', _hlbgFilter)
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
    pcall(function()
        if HLBG._captureIncoming or HLBG._devMode or (DCHLBGDB and DCHLBGDB.devMode) then
            HLBG.DebugLog('CHAT_IN', { event = ev, msg = msg })
        end
    end)
    -- STATUS (chat fallback)
    local b = msg:match('%[HLBG_STATUS%]%s*(.*)')
    if b then
    pcall(function() if HLBG._captureIncoming or HLBG._devMode or (DCHLBGDB and DCHLBGDB.devMode) then HLBG.DebugLog('CHAT_STATUS', b) end end)
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
    pcall(function() if HLBG._captureIncoming or HLBG._devMode or (DCHLBGDB and DCHLBGDB.devMode) then HLBG.DebugLog('CHAT_WARMUP', warm) end end)
    -- Queue
    local q = msg:match('%[HLBG_QUEUE%]%s*(.*)')
    if q then if type(HLBG.QueueStatus) == 'function' then pcall(HLBG.QueueStatus, q) end return end
    pcall(function() if HLBG._captureIncoming or HLBG._devMode or (DCHLBGDB and DCHLBGDB.devMode) then HLBG.DebugLog('CHAT_QUEUE', q) end end)
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
    pcall(function() if HLBG._captureIncoming or HLBG._devMode or (DCHLBGDB and DCHLBGDB.devMode) then HLBG.DebugLog('CHAT_HISTORY_TSV_RAW', htsv) end end)
        local total = tonumber((htsv:match('^TOTAL=(%d+)%s*%|%|') or 0)) or 0
        if HLBG.UI and HLBG.UI.History and total and total > 0 then HLBG.UI.History.total = total end
        -- Strip TOTAL prefix
        htsv = htsv:gsub('^TOTAL=%d+%s*%|%|', '')
    -- If multi-row separator exists, convert to newlines for HistoryStr
    -- Dev-only: report pipe/newline state before conversion
        pcall(function()
            local dev = HLBG._devMode or (DCHLBGDB and DCHLBGDB.devMode)
        if dev and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            local foundNl = htsv:find('\n') and true or false
            local pipeCount = 0
            for _ in htsv:gmatch('%|') do pipeCount = pipeCount + 1 end
            DebugPrint(string.format('|cFF33FF99HLBG Debug|r Chat handler before conv: pipeCount=%d foundNewline=%s', pipeCount, tostring(foundNl)))
        end
    end)
    htsv = htsv:gsub('%|%|','\n')
    if htsv:find('%|') and not htsv:find('\n') then htsv = htsv:gsub('%|','\n') end
    -- Dev-only: report pipe/newline state after conversion
    pcall(function()
        local dev = HLBG._devMode or (DCHLBGDB and DCHLBGDB.devMode)
        if dev and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            local foundNl = htsv:find('\n') and true or false
            local pipeCount = 0
            for _ in htsv:gmatch('%|') do pipeCount = pipeCount + 1 end
            DebugPrint(string.format('|cFF33FF99HLBG Debug|r Chat handler after conv: pipeCount=%d foundNewline=%s', pipeCount, tostring(foundNl)))
        end
    end)
        local hasTabs = htsv:find('\t') and true or false
        local hasNL   = htsv:find('\n') and true or false
        pcall(function()
            local dev = HLBG._devMode or (DCHLBGDB and DCHLBGDB.devMode)
            if dev and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                DebugPrint(string.format('|cFF33FF99HLBG Debug|r Chat handler deciding: hasTabs=%s hasNL=%s len=%d', tostring(hasTabs), tostring(hasNL), #htsv))
            end
        end)
        pcall(function()
            DebugPrint(string.format('|cFF33FF99HLBG Debug|r HistoryStr function available: %s', type(HLBG.HistoryStr)))
        end)
        if hasTabs and type(HLBG.HistoryStr) == 'function' then
            pcall(function()
                DebugPrint('|cFF33FF99HLBG Debug|r About to call HistoryStr')
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
                DebugPrint(string.format('|cFF33FF99HLBG Debug|r HistoryStr sanitized lines=%d preview=%s', #lines, htsv:sub(1,200)))
            end)
            local ok, err = pcall(HLBG.HistoryStr, htsv, 1, (HLBG.UI and HLBG.UI.History and HLBG.UI.History.per) or 25, total, 'id', 'DESC')
            if ok then
                pcall(function()
                    DebugPrint('|cFF33FF99HLBG Debug|r HistoryStr call succeeded!')
                end)
            else
                pcall(function()
                    DebugPrint('|cFFFF5555HLBG Debug|r HistoryStr error: '..tostring(err))
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
                pcall(HLBG.HistoryStr, htsv, 1, (HLBG.UI and HLBG.UI.History and HLBG.UI.History.per) or 25, total, 'id', 'DESC')
            end
        end
        return
    end
    -- Stats JSON - FIXED to properly handle incoming JSON and display stats
    local sj = msg:match('%[HLBG_STATS_JSON%]%s*(.*)')
    if sj then
        pcall(function()
            DebugPrint('|cFF33FF99HLBG Debug:|r Processing STATS_JSON, length: ' .. #sj)
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
            -- Extract win counts from byAffix structure (sum across all affixes)
            local allianceWins = 0
            local hordeWins = 0
            local draws = tonumber(decoded.draws) or 0
            if decoded.byAffix and type(decoded.byAffix) == 'table' then
                for affixId, affixData in pairs(decoded.byAffix) do
                    if type(affixData) == 'table' then
                        allianceWins = allianceWins + (tonumber(affixData.Alliance) or 0)
                        hordeWins = hordeWins + (tonumber(affixData.Horde) or 0)
                    end
                end
            end
            -- Also check top-level counts if present (fallback)
            if decoded.counts and type(decoded.counts) == 'table' then
                allianceWins = allianceWins + (tonumber(decoded.counts.Alliance) or 0)
                hordeWins = hordeWins + (tonumber(decoded.counts.Horde) or 0)
            end
            local totalBattles = tonumber(decoded.total) or (allianceWins + hordeWins + draws)
            pcall(function()
                DebugPrint(string.format('|cFF33FF99HLBG Debug:|r JSON decoded: A=%d H=%d D=%d Total=%d', allianceWins, hordeWins, draws, totalBattles))
            end)
            -- Store total if present
            if decoded.total and HLBG.UI and HLBG.UI.History then
                HLBG.UI.History.total = totalBattles
            end
            -- Build normalized stats object
            local normalizedStats = {
                counts = { Alliance = allianceWins, Horde = hordeWins },
                draws = draws,
                totalBattles = totalBattles,
                avgDuration = tonumber(decoded.avgDuration) or 0,
                season = tonumber(decoded.season) or 1,
                seasonName = decoded.seasonName or "Season 1"
            }
            -- Call stats display function with normalized data
            if type(HLBG.Stats) == 'function' then
                pcall(HLBG.Stats, normalizedStats)
                pcall(function()
                    DebugPrint('|cFF33FF99HLBG Debug:|r Called HLBG.Stats with normalized data')
                end)
            end
            if type(HLBG.OnServerStats) == 'function' then
                pcall(HLBG.OnServerStats, normalizedStats)
                pcall(function()
                    DebugPrint('|cFF33FF99HLBG Debug:|r Called HLBG.OnServerStats with normalized data')
                end)
            end
            -- Force update stats display if UI exists
            if HLBG.UI and HLBG.UI.Stats and HLBG.UI.Stats.Text then
                pcall(function()
                    local lines = {}
                    table.insert(lines, "|cFFFFD700=== Hinterland BG Statistics ===|r")
                    table.insert(lines, "")
                    table.insert(lines, string.format("|cFFFFD700Season:|r %s (#%d)", normalizedStats.seasonName or "Season 1", normalizedStats.season or 1))
                    table.insert(lines, "")
                    -- Battle counts
                    table.insert(lines, "|cFFFFD700Battle Summary:|r")
                    table.insert(lines, string.format("  |cFFFFFFFFTotal Battles:|r %d", totalBattles))
                    table.insert(lines, string.format("  |cFF0099FFAlliance Wins:|r %d  |cFFAAAA00(%.1f%%)|r",
                        allianceWins,
                        totalBattles > 0 and (allianceWins / totalBattles * 100) or 0))
                    table.insert(lines, string.format("  |cFFFF0000Horde Wins:|r %d  |cFFAAAA00(%.1f%%)|r",
                        hordeWins,
                        totalBattles > 0 and (hordeWins / totalBattles * 100) or 0))
                    table.insert(lines, string.format("  |cFFAAAA00Draws:|r %d  |cFFAAAA00(%.1f%%)|r",
                        draws,
                        totalBattles > 0 and (draws / totalBattles * 100) or 0))
                    table.insert(lines, "")
                    -- Duration stats
                    table.insert(lines, "|cFFFFD700Performance:|r")
                    table.insert(lines, string.format("  |cFF00FF00Average Duration:|r %.1f seconds", normalizedStats.avgDuration or 0))
                    if normalizedStats.avgDuration and normalizedStats.avgDuration > 0 then
                        local minutes = math.floor(normalizedStats.avgDuration / 60)
                        local seconds = normalizedStats.avgDuration % 60
                        table.insert(lines, string.format("  |cFFAAAA00(~%d min %d sec)|r", minutes, seconds))
                    end
                    table.insert(lines, "")
                    -- Per-affix breakdown if available
                    if decoded.byAffix and type(decoded.byAffix) == 'table' then
                        table.insert(lines, "|cFFFFD700Stats by Affix:|r")
                        for affixId, affixData in pairs(decoded.byAffix) do
                            if type(affixData) == 'table' then
                                local affixName = HLBG.GetAffixName and HLBG.GetAffixName(tonumber(affixId)) or ("Affix " .. affixId)
                                local aWins = tonumber(affixData.Alliance) or 0
                                local hWins = tonumber(affixData.Horde) or 0
                                local affixTotal = aWins + hWins
                                if affixTotal > 0 then
                                    table.insert(lines, string.format("  |cFFFFFFFF%s:|r A:%d H:%d (Total: %d)",
                                        affixName, aWins, hWins, affixTotal))
                                end
                            end
                        end
                        table.insert(lines, "")
                    end
                    -- Win reasons if available
                    if decoded.reasons and type(decoded.reasons) == 'table' then
                        table.insert(lines, "|cFFFFD700Win Reasons:|r")
                        for reason, count in pairs(decoded.reasons) do
                            if tonumber(count) and tonumber(count) > 0 then
                                table.insert(lines, string.format("  |cFFFFFFFF%s:|r %d",
                                    tostring(reason):gsub("^%l", string.upper), count))
                            end
                        end
                        table.insert(lines, "")
                    end
                    table.insert(lines, "|cFFAAAA00Click 'Refresh' to update statistics|r")
                    HLBG.UI.Stats.Text:SetText(table.concat(lines, "\n"))
                    DebugPrint('|cFF33FF99HLBG Debug:|r Updated Stats UI with improved formatted layout')
                end)
            end
        else
            pcall(function()
                DebugPrint('|cFFFF5555HLBG Debug:|r JSON decode failed: ' .. tostring(decoded))
            end)
        end
        return
    end
    -- Queue status response
    if msg:match("^QUEUE_STATUS") then
        pcall(function()
            if type(HLBG.HandleQueueStatus) == 'function' then
                HLBG.HandleQueueStatus(msg)
                if DEFAULT_CHAT_FRAME then
                    DebugPrint('|cFF33FF99HLBG Debug:|r Queue status received and processed')
                end
            else
                if DEFAULT_CHAT_FRAME then
                    DebugPrint('|cFFFFAA00HLBG Debug:|r HandleQueueStatus function not available (will be loaded from HLBG_Queue_Client.lua)')
                end
            end
        end)
        return
    end
    
    -- Config info response
    if msg:match("^CONFIG_INFO") then
        pcall(function()
            if type(HLBG.ParseConfigInfo) == 'function' then
                HLBG.ParseConfigInfo(msg)
                if DEFAULT_CHAT_FRAME then
                    DebugPrint('|cFF33FF99HLBG Debug:|r Config info received and processed')
                end
            else
                if DEFAULT_CHAT_FRAME then
                    DebugPrint('|cFFFFAA00HLBG Debug:|r ParseConfigInfo function not available (will be loaded from HLBG_Info.lua)')
                end
            end
        end)
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
        -- Singleton check: reuse existing frame if present
        local frame = _G["HLBG_Emergency"]
        if frame then
            frame:Show()
            return
        end
        -- Simple basic frame
        frame = CreateFrame("Frame", "HLBG_Emergency", UIParent)
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
    -- Singleton check: reuse existing frame if present
    local existingFrame = _G["HLBG_Fixed"]
    if existingFrame and HLBG.UI and HLBG.UI.Frame then
        HLBG.UI.Frame:Show()
        return
    end
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
    -- Singleton check: reuse existing frame if present
    local existingFrame = _G["HLBG_Nuclear"]
    if existingFrame then
        existingFrame:Show()
        return
    end
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

-- Protocol settings and control commands
SLASH_HLBGPROTO1 = '/hlbgproto'
SLASH_HLBGPROTO2 = '/hlbgprotocol'
SlashCmdList['HLBGPROTO'] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")  -- trim
    DCHLBGDB = DCHLBGDB or {}
    
    if msg == "json" then
        -- Toggle JSON mode for DC protocol
        DCHLBGDB.useDCProtocolJSON = not (DCHLBGDB.useDCProtocolJSON == true)
        DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG:|r DC Protocol JSON mode: ' .. 
            (DCHLBGDB.useDCProtocolJSON and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r"))
    elseif msg == "status" then
        -- Request status via DC protocol
        if HLBG.RequestStatus then
            HLBG.RequestStatus()
            DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG:|r Requesting BG status...')
        else
            DEFAULT_CHAT_FRAME:AddMessage('|cFFFF5555HLBG:|r DC protocol not available')
        end
    elseif msg == "queue" then
        -- Quick queue via DC protocol
        if HLBG.QuickQueue then
            HLBG.QuickQueue()
            DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG:|r Joining HLBG queue...')
        else
            DEFAULT_CHAT_FRAME:AddMessage('|cFFFF5555HLBG:|r DC protocol not available')
        end
    elseif msg == "leave" then
        -- Leave queue via DC protocol
        if HLBG.LeaveQueue then
            HLBG.LeaveQueue()
            DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG:|r Leaving HLBG queue...')
        else
            DEFAULT_CHAT_FRAME:AddMessage('|cFFFF5555HLBG:|r DC protocol not available')
        end
    elseif msg == "stats" then
        -- Request stats via DC protocol
        if HLBG.RequestStats then
            HLBG.RequestStats()
            DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG:|r Requesting stats...')
        else
            DEFAULT_CHAT_FRAME:AddMessage('|cFFFF5555HLBG:|r DC protocol not available')
        end
    elseif msg == "help" then
        DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG Protocol Commands:|r')
        DEFAULT_CHAT_FRAME:AddMessage('  /hlbgproto json - Toggle JSON protocol mode')
        DEFAULT_CHAT_FRAME:AddMessage('  /hlbgproto status - Request BG status')
        DEFAULT_CHAT_FRAME:AddMessage('  /hlbgproto queue - Quick queue for HLBG')
        DEFAULT_CHAT_FRAME:AddMessage('  /hlbgproto leave - Leave HLBG queue')
        DEFAULT_CHAT_FRAME:AddMessage('  /hlbgproto stats - Request your stats')
    else
        -- Show protocol status
        local dcAvail = rawget(_G, "DCAddonProtocol") and "|cFF00FF00YES|r" or "|cFFFF0000NO|r"
        local aioAvail = rawget(_G, "AIO") and "|cFF00FF00YES|r" or "|cFFFF0000NO|r"
        DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG Protocol Status:|r')
        DEFAULT_CHAT_FRAME:AddMessage('  DCAddonProtocol: ' .. dcAvail)
        DEFAULT_CHAT_FRAME:AddMessage('  AIO: ' .. aioAvail)
        DEFAULT_CHAT_FRAME:AddMessage('  JSON mode: ' .. 
            (DCHLBGDB.useDCProtocolJSON and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r"))
        DEFAULT_CHAT_FRAME:AddMessage('  Type /hlbgproto help for commands')
    end
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

-- =====================================================================
-- DC ADDON PROTOCOL HANDLERS (lightweight alternative to AIO)
-- =====================================================================

-- Settings toggle for JSON vs pipe-delimited
DCHLBGDB = DCHLBGDB or {}
DCHLBGDB.useDCProtocolJSON = DCHLBGDB.useDCProtocolJSON or true  -- Prefer JSON by default

-- DCAddonProtocol reference
local DC = rawget(_G, "DCAddonProtocol")

if DC then
    -- Helper to decode JSON from DC protocol
    local function DecodeJSON(jsonStr)
        if type(DC.DecodeJSON) == 'function' then
            return DC:DecodeJSON(jsonStr)
        end
        -- Try HLBG's built-in decoder
        if type(HLBG.json_decode) == 'function' then
            return HLBG.json_decode(jsonStr)
        end
        -- Fallback simple JSON decoder
        local ok, result = pcall(function()
            if type(jsonStr) ~= 'string' then return nil end
            local obj = {}
            for key, val in jsonStr:gmatch('"([^"]+)":([^,}]+)') do
                val = val:gsub('^%s*', ''):gsub('%s*$', '')
                if val == 'true' then obj[key] = true
                elseif val == 'false' then obj[key] = false
                elseif val:match('^"') then obj[key] = val:gsub('^"', ''):gsub('"$', '')
                else obj[key] = tonumber(val) or val end
            end
            return obj
        end)
        return ok and result or nil
    end

    -- Check if message is JSON format (starts with "J" marker)
    local function IsJSONMessage(...)
        local args = {...}
        return args[1] == "J"
    end
    
    local function HLBGPrint(msg)
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99HLBG:|r " .. (msg or ""))
        end
    end

    -- SMSG_STATUS (0x10) - BG status update
    DC:RegisterHandler("HLBG", 0x10, function(...)
        local args = {...}
        
        if IsJSONMessage(...) then
            local json = DecodeJSON(args[2])
            if json then
                RES = RES or {}
                RES.A = json.alliance or json.A or 0
                RES.H = json.horde or json.H or 0
                RES.END = json.duration or json.elapsed or 0
                RES.LOCK = 0
                
                HLBG._lastStatus = HLBG._lastStatus or {}
                HLBG._lastStatus.A = RES.A
                HLBG._lastStatus.H = RES.H
                HLBG._lastStatus.allianceResources = RES.A
                HLBG._lastStatus.hordeResources = RES.H
                HLBG._lastStatus.DURATION = RES.END
                HLBG._lastStatus.allianceBases = json.allianceBases or 0
                HLBG._lastStatus.hordeBases = json.hordeBases or 0
                HLBG._lastStatus.affix = json.affix
                HLBG._lastStatus.season = json.season
                HLBG._lastStatusTime = GetTime()
                
                if json.affix then
                    HLBG._affixText = json.affix
                end
                
                if type(HLBG.UpdateHUDVisibility) == 'function' then
                    pcall(HLBG.UpdateHUDVisibility)
                end
                if type(HLBG.UpdateHUD) == 'function' then
                    pcall(HLBG.UpdateHUD)
                end
                
                pcall(function()
                    if HLBG._devMode or (DCHLBGDB and DCHLBGDB.devMode) then
                        HLBG.DebugLog('DC_STATUS_JSON', json)
                    end
                end)
            end
        else
            -- Pipe-delimited format
            local status, mapId, timeRemaining = args[1], args[2], args[3]
            RES = RES or {}
            RES.END = tonumber(timeRemaining) or 0
            if type(HLBG.UpdateHUD) == 'function' then
                pcall(HLBG.UpdateHUD)
            end
        end
    end)
    
    -- SMSG_RESOURCES (0x11) - Resource update
    DC:RegisterHandler("HLBG", 0x11, function(...)
        local args = {...}
        
        if IsJSONMessage(...) then
            local json = DecodeJSON(args[2])
            if json then
                RES = RES or {}
                RES.A = json.A or json.alliance or RES.A or 0
                RES.H = json.H or json.horde or RES.H or 0
                
                HLBG._lastStatus = HLBG._lastStatus or {}
                HLBG._lastStatus.A = RES.A
                HLBG._lastStatus.H = RES.H
                HLBG._lastStatus.allianceBases = json.aBases or 0
                HLBG._lastStatus.hordeBases = json.hBases or 0
                HLBG._lastStatus.allianceKills = json.aKills or 0
                HLBG._lastStatus.hordeKills = json.hKills or 0
                HLBG._lastStatusTime = GetTime()
                
                if type(HLBG.UpdateHUD) == 'function' then
                    pcall(HLBG.UpdateHUD)
                end
            end
        else
            -- Pipe-delimited format
            local allianceRes, hordeRes, aBases, hBases = args[1], args[2], args[3], args[4]
            RES = RES or {}
            RES.A = tonumber(allianceRes) or RES.A or 0
            RES.H = tonumber(hordeRes) or RES.H or 0
            if type(HLBG.UpdateHUD) == 'function' then
                pcall(HLBG.UpdateHUD)
            end
        end
    end)
    
    -- SMSG_QUEUE_UPDATE (0x13) - Queue status
    DC:RegisterHandler("HLBG", 0x13, function(...)
        local args = {...}
        
        if IsJSONMessage(...) then
            local json = DecodeJSON(args[2])
            if json then
                local status = json.status
                local position = json.position or 0
                local eta = json.eta or 0
                local inQueue = json.inQueue or 0
                
                if status == 1 then
                    HLBGPrint(string.format("Queued for HLBG! Position: %d, ETA: %d sec, Players in queue: %d",
                        position, eta, inQueue))
                elseif status == 0 then
                    HLBGPrint("Left the HLBG queue.")
                end
                
                if type(HLBG.HandleQueueStatus) == 'function' then
                    pcall(HLBG.HandleQueueStatus, json)
                end
            end
        else
            local queueStatus, position, estimatedTime = args[1], args[2], args[3]
            if tonumber(queueStatus) == 1 then
                HLBGPrint("Queued for HLBG!")
            elseif tonumber(queueStatus) == 0 then
                HLBGPrint("Left the HLBG queue.")
            end
        end
    end)
    
    -- SMSG_TIMER_SYNC (0x14) - Timer synchronization
    DC:RegisterHandler("HLBG", 0x14, function(...)
        local args = {...}
        
        if IsJSONMessage(...) then
            local json = DecodeJSON(args[2])
            if json then
                RES = RES or {}
                RES.END = json.max or 0
                HLBG._lastStatus = HLBG._lastStatus or {}
                HLBG._lastStatus.elapsed = json.elapsed or 0
                HLBG._lastStatus.DURATION = json.max or 0
                HLBG._lastStatus.isWarmup = json.warmup or false
                HLBG._lastStatusTime = GetTime()
                
                if type(HLBG.UpdateHUD) == 'function' then
                    pcall(HLBG.UpdateHUD)
                end
            end
        else
            local elapsedMs, maxMs = args[1], args[2]
            RES = RES or {}
            RES.END = tonumber(maxMs) or 0
            if type(HLBG.UpdateHUD) == 'function' then
                pcall(HLBG.UpdateHUD)
            end
        end
    end)
    
    -- SMSG_TEAM_SCORE (0x15) - Team scores
    DC:RegisterHandler("HLBG", 0x15, function(...)
        local args = {...}
        
        if IsJSONMessage(...) then
            local json = DecodeJSON(args[2])
            if json then
                RES = RES or {}
                RES.A = json.aScore or RES.A or 0
                RES.H = json.hScore or RES.H or 0
                
                HLBG._lastStatus = HLBG._lastStatus or {}
                HLBG._lastStatus.A = RES.A
                HLBG._lastStatus.H = RES.H
                HLBG._lastStatus.allianceKills = json.aKills or 0
                HLBG._lastStatus.hordeKills = json.hKills or 0
                HLBG._lastStatus.allianceDeaths = json.aDeaths or 0
                HLBG._lastStatus.hordeDeaths = json.hDeaths or 0
                
                if type(HLBG.UpdateHUD) == 'function' then
                    pcall(HLBG.UpdateHUD)
                end
            end
        else
            local aScore, hScore, aKills, hKills = args[1], args[2], args[3], args[4]
            RES = RES or {}
            RES.A = tonumber(aScore) or RES.A or 0
            RES.H = tonumber(hScore) or RES.H or 0
            if type(HLBG.UpdateHUD) == 'function' then
                pcall(HLBG.UpdateHUD)
            end
        end
    end)
    
    -- SMSG_STATS (0x16) - Player stats
    DC:RegisterHandler("HLBG", 0x16, function(...)
        local args = {...}
        
        if IsJSONMessage(...) then
            local json = DecodeJSON(args[2])
            if json then
                local stats = {
                    season = json.season or 1,
                    totalBattles = json.matches or 0,
                    counts = { Alliance = json.wins or 0, Horde = json.losses or 0 },
                    draws = json.draws or 0,
                    kills = json.kills or 0,
                    deaths = json.deaths or 0,
                    objectives = json.objectives or 0,
                    avgDuration = json.avgDuration or 0
                }
                
                if type(HLBG.Stats) == 'function' then
                    pcall(HLBG.Stats, stats)
                end
                
                HLBGPrint(string.format("Season %d: %d matches, %d wins, %d losses, %d draws",
                    stats.season, stats.totalBattles, stats.counts.Alliance, stats.counts.Horde, stats.draws))
            end
        else
            local total, wins, losses, kills, deaths, obj, season = args[1], args[2], args[3], args[4], args[5], args[6], args[7]
            HLBGPrint(string.format("Stats: %d matches, %d wins, %d losses",
                tonumber(total) or 0, tonumber(wins) or 0, tonumber(losses) or 0))
        end
    end)

    -- SMSG_HISTORY_TSV (0x33) - Match history UI
    DC:RegisterHandler("HLBG", 0x33, function(...)
        local args = {...}
        local total = tonumber(args[1]) or 0
        local tsv = args[2] or ""

        local hist = (HLBG and HLBG.UI and HLBG.UI.History) or {}
        local page = hist.page or 1
        local per = hist.per or 25
        local sortKey = hist.sortKey or "id"
        local sortDir = hist.sortDir or "DESC"

        if type(HLBG.HistoryStr) == 'function' then
            pcall(HLBG.HistoryStr, tsv, page, per, total, sortKey, sortDir)
        end
    end)
    
    -- SMSG_AFFIX_INFO (0x17) - Affix information
    DC:RegisterHandler("HLBG", 0x17, function(...)
        local args = {...}
        
        if IsJSONMessage(...) then
            local json = DecodeJSON(args[2])
            if json then
                HLBG._affixText = json.affixName or ""
                HLBG._affixDesc = json.affixDesc or ""
                HLBG._currentSeason = json.season
                HLBG._currentSeasonName = json.seasonName
                
                if type(HLBG.UpdateHUD) == 'function' then
                    pcall(HLBG.UpdateHUD)
                end
                
                if json.affixName then
                    HLBGPrint("Current affix: " .. json.affixName)
                end
            end
        else
            local affixId1, affixId2, affixId3, seasonId = args[1], args[2], args[3], args[4]
            -- Handle pipe-delimited affix info
        end
    end)
    
    -- SMSG_MATCH_END (0x18) - Match end notification
    DC:RegisterHandler("HLBG", 0x18, function(...)
        local args = {...}
        
        if IsJSONMessage(...) then
            local json = DecodeJSON(args[2])
            if json then
                local winner = json.winner or (json.victory and "Your team" or "Enemy team")
                local aScore = json.aScore or 0
                local hScore = json.hScore or 0
                local reason = json.reason or "resources"
                
                HLBGPrint(string.format("Match ended! Winner: %s (A: %d, H: %d) - %s",
                    winner, aScore, hScore, reason))
                
                if json.honor and json.honor > 0 then
                    HLBGPrint(string.format("Rewards: %d honor, %d rep, %d tokens",
                        json.honor or 0, json.rep or 0, json.tokens or 0))
                end
                
                -- Trigger results display if available
                if type(HLBG.Results) == 'function' then
                    pcall(HLBG.Results, json)
                end
            end
        else
            local victory, personalScore, honor, rep, tokens = args[1], args[2], args[3], args[4], args[5]
            local winText = (victory == "1" or victory == 1) and "Victory!" or "Defeat"
            HLBGPrint(string.format("%s Score: %d, Honor: %d", winText,
                tonumber(personalScore) or 0, tonumber(honor) or 0))
        end
    end)
    
    -- Helper functions to send requests via DC protocol
    HLBG.RequestStatus = function()
        if DC then
            DC:Send("HLBG", 0x01)  -- CMSG_REQUEST_STATUS
        end
    end
    
    HLBG.RequestResources = function()
        if DC then
            DC:Send("HLBG", 0x02)  -- CMSG_REQUEST_RESOURCES
        end
    end
    
    HLBG.QuickQueue = function()
        if DC then
            DC:Send("HLBG", 0x04)  -- CMSG_QUICK_QUEUE
        end
    end
    
    HLBG.LeaveQueue = function()
        if DC then
            DC:Send("HLBG", 0x05)  -- CMSG_LEAVE_QUEUE
        end
    end
    
    HLBG.RequestStats = function(seasonId)
        if DC then
            if seasonId then
                DC:Send("HLBG", 0x06, tostring(seasonId))  -- CMSG_REQUEST_STATS with season
            else
                DC:Send("HLBG", 0x06)  -- CMSG_REQUEST_STATS
            end
        end
    end
    
    -- Log that DC protocol handlers are registered
    pcall(function()
        if DEFAULT_CHAT_FRAME and (HLBG._devMode or (DCHLBGDB and DCHLBGDB.devMode)) then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99HLBG:|r DCAddonProtocol handlers registered")
        end
    end)
end

_G.HLBG = HLBG

