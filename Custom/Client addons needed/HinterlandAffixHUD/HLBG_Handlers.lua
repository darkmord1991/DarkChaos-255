-- HLBG_Handlers.lua
local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

-- Shared live resources state. Initialize to avoid nil indexing when STATUS messages arrive.
RES = RES or {}
HLBG.RES = HLBG.RES or RES

-- Zone watcher: show/hide HUD when entering Hinterlands
local function InHinterlands()
    local z = GetRealZoneText() or ""
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
            _G.AIO.Handle("HLBG", "Request", "HISTORY", 1, HLBG.UI and HLBG.UI.History and HLBG.UI.History.per or 5, HLBG.UI and HLBG.UI.History and HLBG.UI.History.sortKey or "id", HLBG.UI and HLBG.UI.History and HLBG.UI.History.sortDir or "DESC")
            _G.AIO.Handle("HLBG", "Request", "STATS")
        end
        -- chat fallbacks
        if type(SendChatMessage) == 'function' then
            pcall(function()
                SendChatMessage('.hlbg live players', 'SAY')
                SendChatMessage('.hlbg historyui 1 5 id DESC', 'SAY')
                SendChatMessage('.hlbg statsui', 'SAY')
            end)
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
            _G.AIO.Handle("HLBG", "Request", "HISTORY", HLBG.UI and HLBG.UI.History and HLBG.UI.History.page or 1, HLBG.UI and HLBG.UI.History and HLBG.UI.History.per or 5, HLBG.UI and HLBG.UI.History and HLBG.UI.History.sortKey or "id", HLBG.UI and HLBG.UI.History and HLBG.UI.History.sortDir or "DESC")
            _G.AIO.Handle("HLBG", "Request", "STATS")
        end
        if type(SendChatMessage) == 'function' then
            pcall(function()
                SendChatMessage('.hlbg live players', 'SAY')
                SendChatMessage('.hlbg historyui 1 5 id DESC', 'SAY')
                SendChatMessage('.hlbg statsui', 'SAY')
            end)
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
        if HLBG.UI and HLBG.UI.Affix and HLBG.UI.Affix.Text then
            pcall(function()
                HLBG.UI.Affix.Text:SetText(tostring(aff))
                HLBG.UI.Affix:Show()
                local tfr = CreateFrame('Frame')
                tfr._t = 0
                tfr:SetScript('OnUpdate', function(self, elapsed)
                    self._t = self._t + (elapsed or 0)
                    if self._t >= 6 then
                        if HLBG.UI and HLBG.UI.Affix then HLBG.UI.Affix:Hide() end
                        self:SetScript('OnUpdate', nil)
                        self = nil
                    end
                end)
            end)
        end
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
        local ok, decoded = pcall(function() return HLBG.json_decode and HLBG.json_decode(rj) or nil end)
        if ok and type(decoded) == 'table' and type(HLBG.Results) == 'function' then pcall(HLBG.Results, decoded) end
        return
    end

    -- History TSV fallback
    local htsv = msg:match('%[HLBG_HISTORY_TSV%]%s*(.*)')
    if htsv then
        htsv = htsv:gsub('%|%|', '\n')
        if type(HLBG.HistoryStr) == 'function' then pcall(HLBG.HistoryStr, htsv, 1, 5, 0, 'id', 'DESC') end
        return
    end

    -- Stats JSON fallback
    local sj = msg:match('%[HLBG_STATS_JSON%]%s*(.*)')
    if sj then
        local ok, decoded = pcall(function() return HLBG.json_decode and HLBG.json_decode(sj) or nil end)
        if ok and type(decoded) == 'table' and type(HLBG.Stats) == 'function' then pcall(HLBG.Stats, decoded) end
        return
    end
end)

-- expose helpers for other files
HLBG.EnsurePvPTab = EnsurePvPTab
HLBG.EnsurePvPHeaderButton = EnsurePvPHeaderButton

_G.HLBG = HLBG
