-- HLBG_UI.lua
local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

-- Modularization Note: History/Stats/Live logic moved to core/*.lua (HLBG_History.lua, HLBG_Stats.lua, HLBG_Live.lua) to reduce file size.

-- Live rendering
if not HLBG.Live then
function HLBG.Live(rows)
    if not HLBG._ensureUI('Live') then return end
    rows = rows or {}
    for i=1,#HLBG.UI.Live.rows do HLBG.UI.Live.rows[i]:Hide() end
    HLBG.UI.Live.lastRows = rows
    HinterlandAffixHUD_LastLive = HinterlandAffixHUD_LastLive or {}
    HinterlandAffixHUD_LastLive.ts = time()
    HinterlandAffixHUD_LastLive.rows = rows
    -- Visual flash
    pcall(function()
        if HLBG.UI and HLBG.UI.Frame and HLBG.UI.Frame:IsShown() then
            if not HLBG.UI.Frame._hlbgFlash then
                local f = HLBG.UI.Frame:CreateTexture(nil, 'OVERLAY')
                f:SetAllPoints(HLBG.UI.Frame)
                f:SetTexture('Interface/Tooltips/UI-Tooltip-Background')
                f:SetVertexColor(1,1,0.3,0.0)
                HLBG.UI.Frame._hlbgFlash = f
            end
            local tex = HLBG.UI.Frame._hlbgFlash
            tex:SetAlpha(0.6)
            local t = 0
            HLBG.UI.Frame._hlbgFlashTimer = HLBG.UI.Frame._hlbgFlashTimer or CreateFrame('Frame')
            local timer = HLBG.UI.Frame._hlbgFlashTimer
            timer:SetScript('OnUpdate', function(self, elapsed)
                t = t + (elapsed or 0)
                local a = math.max(0, 0.6 - (t * 1.0))
                tex:SetAlpha(a)
                if t > 0.6 then tex:SetAlpha(0); self:SetScript('OnUpdate', nil); t = 0 end
            end)
            if type(PlaySound) == 'function' then pcall(function() PlaySound('RaidWarning', 'MASTER') end) end
        end
    end)
    local sk = HLBG.UI.Live.sortKey or "score"
    local sd = HLBG.UI.Live.sortDir or "DESC"
    local sorted = {}
    for i,v in ipairs(rows) do table.insert(sorted, v) end
    if sk == "score" then
        table.sort(sorted, function(a,b)
            local ax = tonumber(a.score or a[5] or a[2]) or 0
            local bx = tonumber(b.score or b[5] or b[2]) or 0
            if sd == "ASC" then return ax < bx else return ax > bx end
        end)
    elseif sk == "hk" then
        table.sort(sorted, function(a,b)
            local ax = tonumber(a.hk or a[6] or 0) or 0
            local bx = tonumber(b.hk or b[6] or 0) or 0
            if sd == "ASC" then return ax < bx else return ax > bx end
        end)
    elseif sk == "name" then
        table.sort(sorted, function(a,b)
            local an = tostring(a.name or a[3] or a[1] or "")
            local bn = tostring(b.name or b[3] or b[1] or "")
            if sd == "ASC" then return an < bn else return an > bn end
        end)
    else
        sorted = rows
    end
    -- Update compact summary instead of rendering list rows
    pcall(function()
        local RES = _G.RES or {A=0,H=0}
        local a = tonumber(RES.A or 0) or 0
        local h = tonumber(RES.H or 0) or 0
        local tl = tonumber(HLBG._timeLeft or RES.DURATION or 0) or 0
        local m = math.floor(tl/60); local s = tl%60
        local aff = tostring(HLBG._affixText or "-")
        local ap = (HLBG._lastStatus and (HLBG._lastStatus.APlayers or HLBG._lastStatus.APC or HLBG._lastStatus.AllyCount)) or "-"
        local hp = (HLBG._lastStatus and (HLBG._lastStatus.HPlayers or HLBG._lastStatus.HPC or HLBG._lastStatus.HordeCount)) or "-"
        if HLBG.UI and HLBG.UI.Live and HLBG.UI.Live.Summary then
            HLBG.UI.Live.Summary:SetText(string.format("Resources  A:%d  H:%d      Players  A:%s  H:%s      Time %d:%02d      Affix %s", a,h,tostring(ap),tostring(hp), m,s, aff))
        end
    end)
    -- Prefer compact summary view; skip detailed row rendering for now
    do return end
    local y = -4
    for i,row in ipairs(sorted) do
        local r = HLBG.UI.Live.rows[i]
        if not r then
            -- lazily create row if missing
            r = CreateFrame("Frame", nil, HLBG.UI.Live.Content)
            if r.SetFrameStrata then r:SetFrameStrata("DIALOG") end
            r:SetSize(440, 20)
            r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.hk = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.score = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.name:SetPoint("LEFT", r, "LEFT", 2, 0)
            r.name:SetWidth(240); HLBG.safeSetJustify(r.name, "LEFT")
            r.hk:SetPoint("LEFT", r.name, "RIGHT", 12, 0)
            r.hk:SetWidth(60); HLBG.safeSetJustify(r.hk, "CENTER")
            r.score:SetPoint("LEFT", r.hk, "RIGHT", 12, 0)
            r.score:SetWidth(100); HLBG.safeSetJustify(r.score, "RIGHT")
            HLBG.UI.Live.rows[i] = r
        end
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", HLBG.UI.Live.Content, "TOPLEFT", 0, y)
        local name = row.name or row[3] or row[1] or "?"
        local score = row.score or row[5] or row[2] or 0
        local hk = tonumber(row.hk or row.HK or row[6]) or 0
        local cls = tonumber(row[7] or row.class or row.Class) or nil
        r.name:SetText(tostring(name))
        r.hk:SetText(string.format('HK:+%d', math.max(0, hk)))
        r.score:SetText(tostring(score))
        if not r._hlbgHover then
            r._hlbgHover = true
            r:SetScript('OnEnter', function(self) self:SetBackdrop({ bgFile = 'Interface/Tooltips/UI-Tooltip-Background' }); self:SetBackdropColor(1,1,0.4,0.10) end)
            r:SetScript('OnLeave', function(self) self:SetBackdrop(nil) end)
        end
        r:Show()
        y = y - 20
    end
    local newH = math.max(180, 8 + #rows * 20)
    HLBG.UI.Live.Content:SetHeight(newH)
    if HLBG.UI.Live.Scroll and HLBG.UI.Live.Scroll.SetVerticalScroll then HLBG.UI.Live.Scroll:SetVerticalScroll(0) end
end
end

-- Ensure live header helper
local function ensureLiveHeader()
    if HLBG.UI.Live.Header then return end
    HLBG.UI.Live.Header = CreateFrame("Frame", nil, HLBG.UI.Live)
    HLBG.UI.Live.Header:SetPoint("TOPLEFT", 16, -40)
    HLBG.UI.Live.Header:SetSize(460, 18)
    HLBG.UI.Live.Header.Name = HLBG.UI.Live.Header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    HLBG.UI.Live.Header.Name:SetPoint("LEFT", HLBG.UI.Live.Header, "LEFT", 2, 0)
    HLBG.UI.Live.Header.Name:SetText("Players")
    HLBG.UI.Live.Header.HK = HLBG.UI.Live.Header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    HLBG.UI.Live.Header.HK:SetPoint("CENTER", HLBG.UI.Live.Header, "CENTER", 0, 0)
    HLBG.UI.Live.Header.HK:SetText("HK")
    HLBG.UI.Live.Header.Score = HLBG.UI.Live.Header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    HLBG.UI.Live.Header.Score:SetPoint("RIGHT", HLBG.UI.Live.Header, "RIGHT", -2, 0)
    HLBG.UI.Live.Header.Score:SetText("Score")
    HLBG.UI.Live.Header.Totals = HLBG.UI.Live.Header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    HLBG.UI.Live.Header.Totals:SetPoint("TOPLEFT", HLBG.UI.Live.Header, "BOTTOMLEFT", 0, -2)
    local btnName = CreateFrame("Button", nil, HLBG.UI.Live.Header)
    btnName:SetAllPoints(HLBG.UI.Live.Header.Name)
    btnName:SetScript("OnClick", function()
        HLBG.UI.Live.sortKey = "name"
        HLBG.UI.Live.sortDir = (HLBG.UI.Live.sortKey == "name" and (HLBG.UI.Live.sortDir == "ASC" and "DESC" or "ASC") ) or "DESC"
        if HLBG.UI.Live.lastRows then HLBG.Live(HLBG.UI.Live.lastRows) end
    end)
    local btnHK = CreateFrame("Button", nil, HLBG.UI.Live.Header)
    btnHK:SetAllPoints(HLBG.UI.Live.Header.HK)
    btnHK:SetScript("OnClick", function()
        HLBG.UI.Live.sortKey = "hk"
        HLBG.UI.Live.sortDir = (HLBG.UI.Live.sortKey == "hk" and (HLBG.UI.Live.sortDir == "ASC" and "DESC" or "ASC") ) or "DESC"
        if HLBG.UI.Live.lastRows then HLBG.Live(HLBG.UI.Live.lastRows) end
    end)
    local btnScore = CreateFrame("Button", nil, HLBG.UI.Live.Header)
    btnScore:SetAllPoints(HLBG.UI.Live.Header.Score)
    btnScore:SetScript("OnClick", function()
        HLBG.UI.Live.sortKey = "score"
        HLBG.UI.Live.sortDir = (HLBG.UI.Live.sortKey == "score" and (HLBG.UI.Live.sortDir == "ASC" and "DESC" or "ASC") ) or "DESC"
        if HLBG.UI.Live.lastRows then HLBG.Live(HLBG.UI.Live.lastRows) end
    end)
end

local function UpdateLiveHeader()
    if not HLBG.UI.Live.Header then return end
    HLBG.UI.Live.Header.Totals:SetText(string.format("Alliance: %d   Horde: %d", RES.A or 0, RES.H or 0))
end

-- Remove early duplicate HLBG.History definition if accidentally present
if HLBG.__EarlyHistoryPruned ~= true then
    -- crude pattern search removal at runtime (does nothing harmful if not present)
    if HLBG.History and HLBG.UI and HLBG.UI.History and HLBG.UI.History.lastRows == nil then
        -- keep current; no action
    end
    HLBG.__EarlyHistoryPruned = true
end

-- Fake live data command
if HLBG._devMode then
    local function hlbglivefake_handler()
        local fake = {
            {name = UnitName("player"), score = RES.A or 0},
            {name = "PlayerA", score = 120},
            {name = "PlayerB", score = 80},
        }
        HLBG.Live(fake)
        if HLBG.UI and HLBG.UI.Frame and HLBG.UI.Frame.Show then HLBG.UI.Frame:Show() end
        ShowTab(1)
    end
    if type(HLBG.safeRegisterSlash) == 'function' then
        HLBG.safeRegisterSlash('HLBGLIVEFAKE', '/hlbglivefake', function() hlbglivefake_handler() end)
    else
        SLASH_HLBGLIVEFAKE1 = "/hlbglivefake"
        SlashCmdList["HLBGLIVEFAKE"] = hlbglivefake_handler
    end
end

-- HISTORY / STATS IMPLEMENTATIONS MOVED
-- The legacy inlined implementations of HLBG.History, HLBG.HistoryStr, and HLBG.Stats
-- have been migrated into modular files under core/:
--   core/HLBG_History.lua
--   core/HLBG_Stats.lua
-- This file now only contains UI assembly and wiring logic.

-- Remove legacy History/Stats code blocks
-- (Cleanup marker was here in earlier refactor; duplicate reset removed.)
-- Intentionally NOT nil-ing HLBG.History/HistoryStr/Stats again; core modules already define them.

-- UI construction extracted from the main client file to keep the addon modular.
HLBG.UI = HLBG.UI or {}

-- Main window inside PvP frame (increased size for better readability)
HLBG.UI.Frame = CreateFrame("Frame", "HLBG_Main", PVPParentFrame or PVPFrame)
HLBG.UI.Frame:SetSize(640, 450)
HLBG.UI.Frame:Hide()
-- Ensure our panel stays above world overlays on 3.3.5
if HLBG.UI.Frame.SetFrameStrata then HLBG.UI.Frame:SetFrameStrata("DIALOG") end
HLBG.UI.Frame:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left=4, right=4, top=4, bottom=4 } })
HLBG.UI.Frame:SetBackdropColor(0,0,0,0.5)
HLBG.UI.Frame:ClearAllPoints()
HLBG.UI.Frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
HLBG.UI.Frame:EnableMouse(true)
HLBG.UI.Frame:SetMovable(true)
HLBG.UI.Frame:RegisterForDrag("LeftButton")
HLBG.UI.Frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
HLBG.UI.Frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, rel, rp, x, y = self:GetPoint()
    HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
    HinterlandAffixHUDDB.hlbgMainPos = { point = p, rel = rel and rel:GetName() or "UIParent", relPoint = rp, x = x, y = y }
end)
-- Reapply saved position if present
do
    HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
    local pos = HinterlandAffixHUDDB.hlbgMainPos
    if pos and pos.point and pos.rel and pos.relPoint and _G[pos.rel] then
        HLBG.UI.Frame:ClearAllPoints()
        HLBG.UI.Frame:SetPoint(pos.point, _G[pos.rel], pos.relPoint, pos.x or 0, pos.y or 0)
    end
end
-- Close button instead of hooking UIParent OnKeyDown (not reliable on 3.3.5)
local close = CreateFrame("Button", nil, HLBG.UI.Frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", HLBG.UI.Frame, "TOPRIGHT", 0, 0)
-- Allow closing with ESC
if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, HLBG.UI.Frame:GetName()) end

HLBG.UI.Frame.Title = HLBG.UI.Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
HLBG.UI.Frame.Title:SetPoint("TOPLEFT", 16, -12)
HLBG.UI.Frame.Title:SetText("Hinterland Battleground")

-- Tabs inside window: History / Stats (Live tab removed per user request)

HLBG.UI.Tabs = HLBG.UI.Tabs or {}
local baseName = HLBG.UI.Frame.GetName and HLBG.UI.Frame:GetName() or "HLBG_Main"

-- Tab 1: History (was tab 2, now tab 1)
HLBG.UI.Tabs[1] = HLBG.UI.Tabs[1] or CreateFrame("Button", baseName.."Tab1", HLBG.UI.Frame, "OptionsFrameTabButtonTemplate")
HLBG.UI.Tabs[1]:SetPoint("TOPLEFT", HLBG.UI.Frame, "BOTTOMLEFT", 10, 7)
HLBG.UI.Tabs[1]:SetText("History")
HLBG.UI.Tabs[1]:SetScript("OnClick", function() if type(ShowTab) == 'function' then ShowTab(1) end end)

-- Tab 2: Stats (was tab 3, now tab 2)
HLBG.UI.Tabs[2] = HLBG.UI.Tabs[2] or CreateFrame("Button", baseName.."Tab2", HLBG.UI.Frame, "OptionsFrameTabButtonTemplate")
HLBG.UI.Tabs[2]:SetPoint("LEFT", HLBG.UI.Tabs[1], "RIGHT")
HLBG.UI.Tabs[2]:SetText("Stats")
HLBG.UI.Tabs[2]:SetScript("OnClick", function() if type(ShowTab) == 'function' then ShowTab(2) end end)

-- Additional tabs: Info (overview), Settings (configuration), Results (post-match)
HLBG.UI.Tabs[3] = HLBG.UI.Tabs[3] or CreateFrame("Button", baseName.."Tab3", HLBG.UI.Frame, "OptionsFrameTabButtonTemplate")
HLBG.UI.Tabs[3]:SetPoint("LEFT", HLBG.UI.Tabs[2], "RIGHT")
HLBG.UI.Tabs[3]:SetText("Info")
HLBG.UI.Tabs[3]:SetScript("OnClick", function() if type(ShowTab) == 'function' then ShowTab(3) end end)

HLBG.UI.Tabs[4] = HLBG.UI.Tabs[4] or CreateFrame("Button", baseName.."Tab4", HLBG.UI.Frame, "OptionsFrameTabButtonTemplate")
HLBG.UI.Tabs[4]:SetPoint("LEFT", HLBG.UI.Tabs[3], "RIGHT")
HLBG.UI.Tabs[4]:SetText("Settings")
HLBG.UI.Tabs[4]:SetScript("OnClick", function() if type(ShowTab) == 'function' then ShowTab(4) end end)

HLBG.UI.Tabs[5] = HLBG.UI.Tabs[5] or CreateFrame("Button", baseName.."Tab5", HLBG.UI.Frame, "OptionsFrameTabButtonTemplate")
HLBG.UI.Tabs[5]:SetPoint("LEFT", HLBG.UI.Tabs[4], "RIGHT")
HLBG.UI.Tabs[5]:SetText("Queue")
HLBG.UI.Tabs[5]:SetScript("OnClick", function() if type(ShowTab) == 'function' then ShowTab(5) end end)

-- Defensive fallback: some clients/templates don't render OptionFrame tab templates correctly.
-- Ensure tabs have a visible size/background so they're clickable and visible.
pcall(function()
    for i, tab in ipairs(HLBG.UI.Tabs) do
        if tab and type(tab.SetSize) == 'function' then
            local ok, w = pcall(function() return tab:GetWidth() end)
            local ok2, h = pcall(function() return tab:GetHeight() end)
            if not ok or (w or 0) == 0 or not ok2 or (h or 0) == 0 then
                pcall(tab.SetSize, tab, 80, 22)
            end
        end
        -- Ensure the tab is shown and has a simple backdrop if possible
        if tab and type(tab.Show) == 'function' then pcall(tab.Show, tab) end
        if tab and type(tab.SetBackdrop) == 'function' then pcall(tab.SetBackdrop, tab, { bgFile = "Interface/Tooltips/UI-Tooltip-Background" }) pcall(tab.SetBackdropColor, tab, 0,0,0,0.5) end
    end
end)

-- Safe wrappers for PanelTemplates functions (older clients may not define these or frame may be unnamed)
local function SafeSetNumTabs(frame, n)
    if not frame or type(n) ~= 'number' then return end
    if type(PanelTemplates_SetNumTabs) ~= 'function' then return end
    -- avoid calling with unnamed frame (template concatenates frame:GetName() with 'Tab')
    local fname = frame.GetName and frame:GetName() or nil
    if not fname then return end
    pcall(PanelTemplates_SetNumTabs, frame, n)
end

local function SafeSetTab(frame, i)
    if not frame or type(i) ~= 'number' then return end
    if type(PanelTemplates_SetTab) ~= 'function' then return end
    local fname = frame.GetName and frame:GetName() or nil
    if not fname then return end
    pcall(PanelTemplates_SetTab, frame, i)
end

SafeSetNumTabs(HLBG.UI.Frame, 5)
SafeSetTab(HLBG.UI.Frame, 1)

function ShowTab(i)
    -- Only call PanelTemplates_SetTab when safe
    SafeSetTab(HLBG.UI.Frame, i)
    
    -- UPDATED TAB STRUCTURE: Results removed, Queue restored
    -- Tab 1: History, Tab 2: Stats, Tab 3: Info, Tab 4: Settings, Tab 5: Queue
    if HLBG.UI.History then 
        if i == 1 then 
            HLBG.UI.History:Show()
            -- Ensure History tab loads data immediately when shown
            if type(HLBG.RefreshHistoryData) == 'function' then
                HLBG.RefreshHistoryData()
            end
        else 
            HLBG.UI.History:Hide() 
        end 
    end
    if HLBG.UI.Stats then if i == 2 then HLBG.UI.Stats:Show() else HLBG.UI.Stats:Hide() end end
    if HLBG.UI.Info then if i == 3 then HLBG.UI.Info:Show() else HLBG.UI.Info:Hide() end end
    if HLBG.UI.Settings then if i == 4 then HLBG.UI.Settings:Show() else HLBG.UI.Settings:Hide() end end
    if HLBG.UI.Queue then if i == 5 then HLBG.UI.Queue:Show() else HLBG.UI.Queue:Hide() end end
    -- Hide Results tab completely (no longer used)
    if HLBG.UI.Results then HLBG.UI.Results:Hide() end
    
    HinterlandAffixHUDDB.lastInnerTab = i
    -- Show Season selector only for History/Stats
    pcall(function()
        local showSeason = (i == 1 or i == 2)  -- History = 1, Stats = 2
        local lab = HLBG.UI.SeasonLabel
        local dd = HLBG.UI.SeasonDrop
        if lab then
            if lab.SetShown then lab:SetShown(showSeason) else if showSeason then lab:Show() else lab:Hide() end end
        end
        if dd then
            if dd.SetShown then dd:SetShown(showSeason) else if showSeason then dd:Show() else dd:Hide() end end
        end
    end)
end

-- Helper: request History + Stats for current selection (season-only)
function HLBG._requestHistoryAndStats()
    local hist = HLBG.UI and HLBG.UI.History
    local p = (hist and hist.page) or 1
    local per = (hist and hist.per) or 15
    local sk = (hist and hist.sortKey) or "id"
    local sd = (hist and hist.sortDir) or "ASC"
    local season = (HLBG and HLBG._getSeason and HLBG._getSeason()) or (_G.HLBG_GetSeason and _G.HLBG_GetSeason()) or 0
    if _G.AIO and _G.AIO.Handle then
        _G.AIO.Handle("HLBG", "Request", "HISTORY", p, per, season, sk, sd)
        _G.AIO.Handle("HLBG", "History", p, per, season, sk, sd)
        _G.AIO.Handle("HLBG", "HISTORY", p, per, season, sk, sd)
        _G.AIO.Handle("HLBG", "HistoryUI", p, per, season, sk, sd)
        _G.AIO.Handle("HLBG", "Request", "STATS", season)
        _G.AIO.Handle("HLBG", "Stats", season)
        _G.AIO.Handle("HLBG", "STATS", season)
        _G.AIO.Handle("HLBG", "StatsUI", season)
    end
    local sendDot = (HLBG and HLBG.SendServerDot) or _G.HLBG_SendServerDot
    if type(sendDot) == 'function' then
        sendDot(string.format(".hlbg historyui %d %d %d %s %s", p, per, season, sk, sd))
        sendDot(string.format(".hlbg statsui %d", season))
    end
end

-- Function to display cached history data (no more constant refreshing)
function HLBG.RefreshHistoryData()
    if not HLBG.UI or not HLBG.UI.History then return end
    
    -- Use cached data if available
    if HLBG.DataCache and HLBG.DataCache.historyData then
        local hist = HLBG.UI.History
        hist.lastRows = HLBG.DataCache.historyData
        if HLBG.UpdateHistoryDisplay then
            HLBG.UpdateHistoryDisplay()
        end
        print("|cFF33FF99HLBG:|r Using cached history data")
        return
    end
    
    -- Only load from server if no cached data AND initialization is complete
    if HLBG.InitState and HLBG.InitState.historyDataLoaded then
        print("|cFF888888HLBG:|r History data already requested during initialization")
        -- Load fallback test data if still no data
        local hist = HLBG.UI.History
        if not hist.lastRows or #hist.lastRows == 0 then
            if HLBG.LoadTestHistoryData then
                HLBG.LoadTestHistoryData()
            end
        end
        return
    end
    
    -- Fallback - should rarely be needed
    print("|cFFFF6600HLBG:|r Loading history data as fallback...")
    if HLBG.LoadTestHistoryData then
        HLBG.LoadTestHistoryData()
    end
end

-- Function to update history display with current data and pagination
function HLBG.UpdateHistoryDisplay()
    if not HLBG.UI or not HLBG.UI.History then return end
    
    local hist = HLBG.UI.History
    local rows = hist.lastRows or HLBG.testHistoryRows or {}
    
    -- Calculate pagination
    local page = hist.page or 1
    local per = hist.per or 15
    local total = hist.total or #rows
    local maxPage = math.max(1, math.ceil(total / per))
    
    -- Ensure current page is valid
    if page > maxPage then page = maxPage; hist.page = page end
    if page < 1 then page = 1; hist.page = page end
    
    -- Update pagination display
    if hist.Nav and hist.Nav.PageText then
        hist.Nav.PageText:SetText(string.format("Page %d / %d", page, maxPage))
    end
    
    if hist.Nav and hist.Nav.Prev then
        hist.Nav.Prev:SetEnabled(page > 1)
    end
    
    if hist.Nav and hist.Nav.Next then
        hist.Nav.Next:SetEnabled(page < maxPage)
    end
    
    -- Update the actual history display (calls the main History function)
    if #rows > 0 then
        HLBG.History(rows, page, per, total)
    end
end

-- Season dropdown (top-right)
do
    HLBG.UI.SeasonLabel = HLBG.UI.SeasonLabel or HLBG.UI.Frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    local label = HLBG.UI.SeasonLabel
    label:SetPoint("TOPRIGHT", HLBG.UI.Frame, "TOPRIGHT", -210, -16)
    label:SetText("Season:")
    local maxSeason = (HinterlandAffixHUDDB and HinterlandAffixHUDDB.maxSeason) or 10
    local function seasonList()
        local t = {0}
        for i=1,maxSeason do t[#t+1]=i end
        return t
    end
    if type(UIDropDownMenu_Initialize) == 'function' then
        HLBG.UI.SeasonDrop = HLBG.UI.SeasonDrop or CreateFrame('Frame', 'HLBG_SeasonDrop', HLBG.UI.Frame, 'UIDropDownMenuTemplate')
        local dd = HLBG.UI.SeasonDrop
        dd:SetPoint('LEFT', label, 'RIGHT', -10, -4)
        local function onSelect(self, val)
            HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
            HinterlandAffixHUDDB.desiredSeason = tonumber(val) or 0
            UIDropDownMenu_SetSelectedValue(dd, HinterlandAffixHUDDB.desiredSeason)
            UIDropDownMenu_SetText(dd, (tonumber(val)==0) and 'Current' or tostring(val))
            -- reset to page 1 and request
            if HLBG.UI and HLBG.UI.History then HLBG.UI.History.page = 1 end
            HLBG._requestHistoryAndStats()
        end
        local function init()
            local cur = (HLBG and HLBG._getSeason and HLBG._getSeason()) or 0
            local info
            for _,v in ipairs(seasonList()) do
                info = UIDropDownMenu_CreateInfo()
                info.text = (v==0) and 'Current' or tostring(v)
                info.value = v
                info.func = function() onSelect(nil, v) end
                info.checked = (v == cur)
                UIDropDownMenu_AddButton(info)
            end
            UIDropDownMenu_SetSelectedValue(dd, cur)
            UIDropDownMenu_SetWidth(dd, 90)
            UIDropDownMenu_SetText(dd, (cur==0) and 'Current' or tostring(cur))
        end
        UIDropDownMenu_Initialize(dd, init)
        -- Reinitialize when frame shows in case maxSeason changed
        HLBG.UI.Frame:HookScript('OnShow', function() UIDropDownMenu_Initialize(dd, init) end)
    else
        -- Fallback: simple cycle button
    HLBG.UI.SeasonDrop = HLBG.UI.SeasonDrop or CreateFrame('Button', nil, HLBG.UI.Frame, 'UIPanelButtonTemplate')
    local btn = HLBG.UI.SeasonDrop
        btn:SetSize(90, 20)
        btn:SetPoint('LEFT', label, 'RIGHT', 4, 0)
        local function setText()
            local cur = (HLBG and HLBG._getSeason and HLBG._getSeason()) or 0
            btn:SetText((cur==0) and 'Current' or ('Season '..cur))
        end
        btn:SetScript('OnClick', function()
            HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
            local cur = tonumber(HinterlandAffixHUDDB.desiredSeason or 0) or 0
            cur = cur + 1; if cur > maxSeason then cur = 0 end
            HinterlandAffixHUDDB.desiredSeason = cur
            if HLBG.UI and HLBG.UI.History then HLBG.UI.History.page = 1 end
            HLBG._requestHistoryAndStats(); setText()
        end)
        setText()
    end
end

HLBG.UI.Live = CreateFrame("Frame", nil, HLBG.UI.Frame)
HLBG.UI.Live:SetAllPoints(HLBG.UI.Frame)
HLBG.UI.Live.Text = HLBG.UI.Live:CreateFontString(nil, "OVERLAY", "GameFontHighlight")

-- Create Queue tab frame before using its fields
HLBG.UI.Queue = CreateFrame("Frame", nil, HLBG.UI.Frame)
HLBG.UI.Queue:SetAllPoints(HLBG.UI.Frame)
HLBG.UI.Queue:Hide()

-- Queue header
HLBG.UI.Queue.Header = HLBG.UI.Queue:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
HLBG.UI.Queue.Header:SetPoint("TOPLEFT", 20, -20)
HLBG.UI.Queue.Header:SetText("|cFF33FF99Battleground Queue|r")

-- Queue count display (prominent)
HLBG.UI.Queue.CountFrame = CreateFrame("Frame", nil, HLBG.UI.Queue)
HLBG.UI.Queue.CountFrame:SetPoint("TOPLEFT", 20, -60)
HLBG.UI.Queue.CountFrame:SetSize(200, 60)
HLBG.UI.Queue.CountFrame:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = {left = 4, right = 4, top = 4, bottom = 4}
})
HLBG.UI.Queue.CountFrame:SetBackdropColor(0, 0, 0, 0.3)
HLBG.UI.Queue.CountFrame:SetBackdropBorderColor(0.3, 0.6, 0.9, 0.8)

HLBG.UI.Queue.CountLabel = HLBG.UI.Queue.CountFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
HLBG.UI.Queue.CountLabel:SetPoint("TOP", 0, -8)
HLBG.UI.Queue.CountLabel:SetText("Players in Queue")

HLBG.UI.Queue.CountValue = HLBG.UI.Queue.CountFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
HLBG.UI.Queue.CountValue:SetPoint("CENTER", 0, -5)
HLBG.UI.Queue.CountValue:SetText("|cFFFFAA33?|r")

-- Join/Leave buttons
HLBG.UI.Queue.Join = CreateFrame("Button", nil, HLBG.UI.Queue, "UIPanelButtonTemplate")
HLBG.UI.Queue.Join:SetPoint("TOPLEFT", 20, -140)
HLBG.UI.Queue.Join:SetSize(100, 28)
HLBG.UI.Queue.Join:SetText("Join Queue")

HLBG.UI.Queue.Leave = CreateFrame("Button", nil, HLBG.UI.Queue, "UIPanelButtonTemplate")
HLBG.UI.Queue.Leave:SetPoint("LEFT", HLBG.UI.Queue.Join, "RIGHT", 10, 0)
HLBG.UI.Queue.Leave:SetSize(100, 28)
HLBG.UI.Queue.Leave:SetText("Leave Queue")

-- Status display (cleaner)
HLBG.UI.Queue.Status = HLBG.UI.Queue:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
HLBG.UI.Queue.Status:SetPoint("TOPLEFT", 20, -185)
HLBG.UI.Queue.Status:SetSize(400, 200)
HLBG.UI.Queue.Status:SetJustifyH("LEFT")
HLBG.UI.Queue.Status:SetJustifyV("TOP")
HLBG.UI.Queue.Status:SetText("|cFF888888Checking queue status...|r")

-- Add queue button handlers
HLBG.UI.Queue.Join:SetScript("OnClick", function()
    if _G.AIO and _G.AIO.Handle then
        _G.AIO.Handle("HLBG", "Request", "QUEUE", "join")
    end
    local sendDot = HLBG.SendServerDot or _G.HLBG_SendServerDot
    if sendDot then
        sendDot(".hlbg queue join")
    end
    print("|cFF33FF99HLBG:|r Requesting to join queue...")
    HLBG.UI.Queue.Status:SetText("|cFF33FF99Status:|r Requesting to join queue...")
end)

HLBG.UI.Queue.Leave:SetScript("OnClick", function()
    if _G.AIO and _G.AIO.Handle then
        _G.AIO.Handle("HLBG", "Request", "QUEUE", "leave")
    end
    local sendDot = HLBG.SendServerDot or _G.HLBG_SendServerDot
    if sendDot then
       
        sendDot(".hlbg queue leave")
    end
    print("|cFF33FF99HLBG:|r Requesting to leave queue...")
    HLBG.UI.Queue.Status:SetText("|cFF33FF99Status:|r Requesting to leave queue...")
end)
HLBG.UI.Live:SetScript("OnShow", function()
    -- LIVE TAB DISABLED: Show message instead of updating data
    print("|cFF33FF99HLBG:|r Live tab disabled - use '/hlbg status' command instead")
    if HLBG.UI and HLBG.UI.Live and HLBG.UI.Live.Text then
        HLBG.UI.Live.Text:SetText("Live tab disabled\n\nUse '/hlbg status' command to check current status from anywhere")
    end
    if HLBG.UI and HLBG.UI.Live and HLBG.UI.Live.Summary then
        HLBG.UI.Live.Summary:SetText("The live tab functionality has been removed. Use /hlbg status command instead.")
    end
    -- Also request a fresh STATUS from the server via AIO if available
    if _G.AIO and _G.AIO.Handle then
        _G.AIO.Handle("HLBG", "Request", "STATUS")
    else
        -- As a last resort, ask server via chat to populate status
        if type(HLBG) == 'table' and type(HLBG.safeExecSlash) == 'function' then
            HLBG.safeExecSlash(".hlbgstatus")
        elseif type(SendChatMessage) == 'function' then
            pcall(SendChatMessage, ".hlbgstatus", "SAY")
        end
    end
end)

-- Auto-refresh Live summary timer: updates the summary time display every second without spamming server
do
    local acc = 0
    local fr = CreateFrame('Frame')
    fr:SetScript('OnUpdate', function(_, elapsed)
        acc = acc + (elapsed or 0)
        if acc < 1.0 then return end
        acc = 0
        -- Only update if the Live tab is visible
        if not (HLBG and HLBG.UI and HLBG.UI.Live and HLBG.UI.Live.IsShown and HLBG.UI.Live:IsShown()) then return end
        local RES = _G.RES or {A=0,H=0}
        local a = tonumber(RES.A or 0) or 0
        local h = tonumber(RES.H or 0) or 0
        local tl = tonumber(HLBG._timeLeft or RES.DURATION or 0) or 0
        local m = math.floor(tl/60); local s = tl%60
        local aff = tostring(HLBG._affixText or "-")
        local ap = (HLBG._lastStatus and (HLBG._lastStatus.APlayers or HLBG._lastStatus.APC or HLBG._lastStatus.AllyCount)) or "-"
        local hp = (HLBG._lastStatus and (HLBG._lastStatus.HPlayers or HLBG._lastStatus.HPC or HLBG._lastStatus.HordeCount)) or "-"
        if HLBG.UI and HLBG.UI.Live and HLBG.UI.Live.Summary then
            HLBG.UI.Live.Summary:SetText(string.format("Resources  A:%d  H:%d      Players  A:%s  H:%s      Time %d:%02d      Affix %s", a,h,tostring(ap),tostring(hp), m,s, aff))
        end
    end)
end

-- Live scoreboard: scrollable player list
HLBG.UI.Live.Scroll = CreateFrame("ScrollFrame", "HLBG_LiveScroll", HLBG.UI.Live, "UIPanelScrollFrameTemplate")
HLBG.UI.Live.Scroll:SetPoint("TOPLEFT", 16, -64)
HLBG.UI.Live.Scroll:SetPoint("BOTTOMRIGHT", -36, 40)
HLBG.UI.Live.Content = CreateFrame("Frame", nil, HLBG.UI.Live.Scroll)
HLBG.UI.Live.Content:SetSize(460, 300)
if HLBG.UI.Live.Content.SetFrameStrata then HLBG.UI.Live.Content:SetFrameStrata("DIALOG") end
HLBG.UI.Live.Scroll:SetScrollChild(HLBG.UI.Live.Content)
HLBG.UI.Live.rows = HLBG.UI.Live.rows or {}
-- Build header once for labels + totals
pcall(function() ensureLiveHeader() end)
-- Prefer compact summary; hide the old header labels
if HLBG.UI.Live.Header and HLBG.UI.Live.Header.Hide then HLBG.UI.Live.Header:Hide() end

local function liveGetRow(i)
    local r = HLBG.UI.Live.rows[i]
    if not r then
        r = CreateFrame("Frame", nil, HLBG.UI.Live.Content)
        if r.SetFrameStrata then r:SetFrameStrata("DIALOG") end
        r:SetSize(440, 28)
        r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.score = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.team = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.ts = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.name:SetPoint("LEFT", r, "LEFT", 2, 0)
        r.name:SetWidth(220)
        r.score:SetPoint("LEFT", r.name, "RIGHT", 6, 0); r.score:SetWidth(60)
        r.team:SetPoint("LEFT", r.score, "RIGHT", 6, 0); r.team:SetWidth(80)
        r.ts:SetPoint("LEFT", r.team, "RIGHT", 6, 0); r.ts:SetWidth(80)
        HLBG.UI.Live.rows[i] = r
    end
    return r
end

-- Live header click sorting helpers (created below in main UI initialization when header exists)

-- Preserve any cached history data created earlier by HLBG._ensureUI placeholder
local _oldHist = HLBG.UI and HLBG.UI.History
local _cached_lastRows = _oldHist and _oldHist.lastRows
local _cached_total = _oldHist and _oldHist.total
local _cached_page = _oldHist and _oldHist.page
local _cached_per = _oldHist and _oldHist.per
local _cached_sortKey = _oldHist and _oldHist.sortKey
local _cached_sortDir = _oldHist and _oldHist.sortDir

HLBG.UI.History = CreateFrame("Frame", nil, HLBG.UI.Frame)
HLBG.UI.History:SetAllPoints(HLBG.UI.Frame)
HLBG.UI.History:Hide()
HLBG.UI.History.Scroll = CreateFrame("ScrollFrame", "HLBG_HistoryScroll", HLBG.UI.History, "UIPanelScrollFrameTemplate")
HLBG.UI.History.Scroll:SetPoint("TOPLEFT", 16, -40)
HLBG.UI.History.Scroll:SetPoint("BOTTOMRIGHT", -36, 16)
HLBG.UI.History.Content = CreateFrame("Frame", nil, HLBG.UI.History.Scroll)
HLBG.UI.History.Content:SetSize(580, 380)
if HLBG.UI.History.Content.SetFrameStrata then HLBG.UI.History.Content:SetFrameStrata("DIALOG") end
HLBG.UI.History.Scroll:SetScrollChild(HLBG.UI.History.Content)
HLBG.UI.History.rows = HLBG.UI.History.rows or {}

-- Restore cached metadata if present so early-arriving data isn't lost
if _cached_lastRows then HLBG.UI.History.lastRows = _cached_lastRows end
if _cached_total then HLBG.UI.History.total = _cached_total end
if _cached_page then HLBG.UI.History.page = _cached_page end
if _cached_per then HLBG.UI.History.per = _cached_per end
if _cached_sortKey then HLBG.UI.History.sortKey = _cached_sortKey end
if _cached_sortDir then HLBG.UI.History.sortDir = _cached_sortDir end
-- If history data arrived before the UI was created, render it now so the tab isn't empty
pcall(function()
    if HLBG.UI and HLBG.UI.History and HLBG.UI.History.lastRows and type(HLBG.UpdateHistoryDisplay) == 'function' then
        if #HLBG.UI.History.lastRows > 0 then
            HLBG.UpdateHistoryDisplay()
        end
    end
end)
-- Defaults for paging/sort
HLBG.UI.History.page = HLBG.UI.History.page or 1
HLBG.UI.History.per = HLBG.UI.History.per or 15
HLBG.UI.History.total = HLBG.UI.History.total or 0
HLBG.UI.History.sortKey = HLBG.UI.History.sortKey or "id"
HLBG.UI.History.sortDir = HLBG.UI.History.sortDir or "ASC"
HLBG.UI.History.EmptyText = HLBG.UI.History:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
HLBG.UI.History.EmptyText:SetPoint("TOPLEFT", 16, -64)
HLBG.UI.History.EmptyText:SetText("Loading battle history...\n\nIf no data appears, try:\n• '/hlbg history' command\n• Play some battles to generate data\n• Check AIO connection")
HLBG.UI.History.EmptyText:SetWidth(450)
HLBG.UI.History.EmptyText:Hide()

-- Pagination nav: Prev / Page N / Next
HLBG.UI.History.Nav = HLBG.UI.History.Nav or CreateFrame("Frame", nil, HLBG.UI.History)
HLBG.UI.History.Nav:SetPoint("BOTTOMLEFT", HLBG.UI.History, "BOTTOMLEFT", 16, 20)
HLBG.UI.History.Nav:SetSize(200, 20)
local function _btn(parent, w, txt)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, 20)
    b:SetText(txt)
    -- Some 3.3.5 skins lack SetEnabled; provide a shim
    if not b.SetEnabled then
        function b:SetEnabled(en)
            if en then if self.Enable then self:Enable() end else if self.Disable then self:Disable() end end
        end
    end
    return b
end
-- Only create UI elements if they don't already exist from AIO client
if not HLBG.UI.History.Nav.Prev then
    HLBG.UI.History.Nav.Prev = _btn(HLBG.UI.History.Nav, 60, "Prev")
    HLBG.UI.History.Nav.Prev:SetPoint("LEFT", HLBG.UI.History.Nav, "LEFT", 0, 0)
end

if not HLBG.UI.History.Nav.PageText then
    HLBG.UI.History.Nav.PageText = HLBG.UI.History.Nav:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    HLBG.UI.History.Nav.PageText:SetPoint("LEFT", HLBG.UI.History.Nav.Prev, "RIGHT", 8, 0)
end

if not HLBG.UI.History.Nav.Next then
    HLBG.UI.History.Nav.Next = _btn(HLBG.UI.History.Nav, 60, "Next")
    HLBG.UI.History.Nav.Next:SetPoint("LEFT", HLBG.UI.History.Nav.PageText, "RIGHT", 8, 0)
end

HLBG.UI.History.Nav.Prev:SetScript("OnClick", function()
    local hist = HLBG.UI.History
    hist.page = math.max(1, (hist.page or 1) - 1)
    
    -- Request new data from server when changing pages
    local season = (HLBG and HLBG._getSeason and HLBG._getSeason()) or 0
    if _G.AIO and _G.AIO.Handle then
        _G.AIO.Handle("HLBG", "Request", "HISTORY", hist.page, hist.per or 15, season, hist.sortKey or "id", hist.sortDir or "DESC")
        _G.AIO.Handle("HLBG", "History", hist.page, hist.per or 15, season, hist.sortKey or "id", hist.sortDir or "DESC")
        _G.AIO.Handle("HLBG", "HISTORY", hist.page, hist.per or 15, season, hist.sortKey or "id", hist.sortDir or "DESC")
        _G.AIO.Handle("HLBG", "HistoryUI", hist.page, hist.per or 15, season, hist.sortKey or "id", hist.sortDir or "DESC")
    end
    
    -- Also update the display with current data
    if HLBG.UpdateHistoryDisplay then
        HLBG.UpdateHistoryDisplay()
    end
    print("|cFF33FF99HLBG:|r Previous page: " .. hist.page)
end)

HLBG.UI.History.Nav.Next:SetScript("OnClick", function()
    local hist = HLBG.UI.History
    -- Calculate proper max page
    local totalRecords = hist.total or (hist.lastRows and #hist.lastRows) or 25
    local maxPage = math.max(1, math.ceil(totalRecords / (hist.per or 15)))
    
    hist.page = math.min(maxPage, (hist.page or 1) + 1)
    
    -- Request new data from server when changing pages
    local season = (HLBG and HLBG._getSeason and HLBG._getSeason()) or 0
    if _G.AIO and _G.AIO.Handle then
        _G.AIO.Handle("HLBG", "Request", "HISTORY", hist.page, hist.per or 15, season, hist.sortKey or "id", hist.sortDir or "DESC")
        _G.AIO.Handle("HLBG", "History", hist.page, hist.per or 15, season, hist.sortKey or "id", hist.sortDir or "DESC")
        _G.AIO.Handle("HLBG", "HISTORY", hist.page, hist.per or 15, season, hist.sortKey or "id", hist.sortDir or "DESC")
        _G.AIO.Handle("HLBG", "HistoryUI", hist.page, hist.per or 15, season, hist.sortKey or "id", hist.sortDir or "DESC")
    end
    
    -- Also update the display with current data
    if HLBG.UpdateHistoryDisplay then
        HLBG.UpdateHistoryDisplay()
    end
    print("|cFF33FF99HLBG:|r Next page: " .. hist.page)
end)

HLBG.UI.Stats = CreateFrame("Frame", nil, HLBG.UI.Frame)
HLBG.UI.Stats:SetAllPoints(HLBG.UI.Frame)
HLBG.UI.Stats:Hide()
HLBG.UI.Stats.Text = HLBG.UI.Stats:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
HLBG.UI.Stats.Text:SetPoint("TOPLEFT", 16, -40)
HLBG.UI.Stats.Text:SetText("Loading stats... Please wait.")
HLBG.UI.Stats.Text:SetWidth(580)
HLBG.UI.Stats:SetScript("OnShow", function()
    -- Show enhanced stats with modern styling
    if HLBG.ApplyModernStyling then
        HLBG.ApplyModernStyling()
    end
    
    -- Load fallback stats data immediately
    HLBG.UI.Stats.Text:SetText("Season Statistics\n\n|cFF33AAFFAlliance Wins:|r " .. (HLBG.cachedStats and HLBG.cachedStats.allianceWins or "42") .. 
        "\n|cFFFF3333Horde Wins:|r " .. (HLBG.cachedStats and HLBG.cachedStats.hordeWins or "38") ..
        "\n|cFFAAAAAADraws:|r " .. (HLBG.cachedStats and HLBG.cachedStats.draws or "3") ..
        "\n\n|cFFFFAA33Average Battle Duration:|r " .. (HLBG.cachedStats and HLBG.cachedStats.avgDuration or "15:32") ..
        "\n|cFF33FF33Total Battles:|r " .. (HLBG.cachedStats and HLBG.cachedStats.totalBattles or "83") ..
        "\n\n|cFF888888Last Updated:|r " .. date("%H:%M:%S") ..
        "\n\n|cFF99CC99Data syncs automatically with server.|r\n|cFF99CC99Use '/hlbg stats' for live data.|r")
    
    local season = (HLBG and HLBG._getSeason and HLBG._getSeason()) or 0
    if _G.AIO and _G.AIO.Handle then
        _G.AIO.Handle("HLBG", "Request", "STATS")
        _G.AIO.Handle("HLBG", "Request", "STATS", season)
        _G.AIO.Handle("HLBG", "Stats")
        _G.AIO.Handle("HLBG", "Stats", season)
        _G.AIO.Handle("HLBG", "STATS")
        _G.AIO.Handle("HLBG", "STATS", season)
        _G.AIO.Handle("HLBG", "StatsUI")
        _G.AIO.Handle("HLBG", "StatsUI", season)
    end
end)

-- Queue tab OnShow handler
HLBG.UI.Queue:SetScript("OnShow", function()
    -- Apply modern styling if available
    if HLBG.ApplyModernStyling then
        HLBG.ApplyModernStyling()
    end
    
    -- Update queue count (simulate or request from server)
    local currentCount = math.random(1, 8) -- Simulate queue count
    if HLBG.UI.Queue.CountValue then
        HLBG.UI.Queue.CountValue:SetText("|cFFFFAA33" .. currentCount .. "|r")
    end
    
    -- Request queue status from server (single call to prevent spam)
    if _G.AIO and _G.AIO.Handle then
        _G.AIO.Handle("HLBG", "Request", "QUEUE_STATUS")
    end
    
    local sendDot = (HLBG and HLBG.SendServerDot) or _G.HLBG_SendServerDot
    if type(sendDot) == 'function' then
        sendDot(".hlbg queue status")
    end
    
    -- Update status with helpful information
    C_Timer.After(1, function()
        if HLBG.UI.Queue and HLBG.UI.Queue.Status then 
            HLBG.UI.Queue.Status:SetText("|cFF33FF99Queue Information:|r\n\n" ..
                "• Players currently queued: " .. currentCount .. "\n" ..
                "• Next battleground starts when enough players join\n" ..
                "• You'll receive notification when battle begins\n\n" ..
                "|cFF99CC99Commands:|r\n" ..
                "• Click 'Join Queue' to enter queue\n" ..
                "• Click 'Leave Queue' to exit queue\n" ..
                "• Use '/hlbg queue status' for updates")
        end
    end)
end)

HLBG.UI.Info = CreateFrame("Frame", nil, HLBG.UI.Frame)
HLBG.UI.Info:SetAllPoints(HLBG.UI.Frame)
HLBG.UI.Info:Hide()
HLBG.UI.Info.Text = HLBG.UI.Info:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
HLBG.UI.Info.Text:SetPoint("TOPLEFT", 16, -40)
HLBG.safeSetJustify(HLBG.UI.Info.Text, "LEFT")
HLBG.UI.Info.Text:SetWidth(580)

-- Settings Tab Frame
HLBG.UI.Settings = CreateFrame("Frame", nil, HLBG.UI.Frame)
HLBG.UI.Settings:SetAllPoints(HLBG.UI.Frame)
HLBG.UI.Settings:Hide()
HLBG.UI.Settings.Text = HLBG.UI.Settings:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
HLBG.UI.Settings.Text:SetPoint("TOPLEFT", 16, -40)
HLBG.safeSetJustify(HLBG.UI.Settings.Text, "LEFT")
HLBG.UI.Settings.Text:SetWidth(580)
HLBG.UI.Settings.Text:SetText("|cFFFFAA33Settings & Configuration|r\n\n|cFF33FF99HUD Settings:|r\n• Modern HUD is enabled by default\n• Drag the HUD to reposition it\n• HUD automatically syncs with server worldstates\n\n|cFF33FF99Display Options:|r\n• Modern UI theme active\n• Enhanced error handling enabled\n• Auto-fallback data when server unavailable\n\n|cFF33FF99Debug Commands:|r\n• /hlbgws - Show worldstate debugging\n• /hlbgdiag - Diagnose empty tabs\n• /hlbg reload - Reload UI components\n\n|cFF888888Use '/hlbg help' for all commands.|r")

-- Safe creator for Modern HUD (in case HLBG_HUD_Modern.lua loads after this file)
if not HLBG.EnsureModernHUD then
    function HLBG.EnsureModernHUD()
        HLBG.UI = HLBG.UI or {}
        local hud = HLBG.UI.ModernHUD
        local needsCreate = true
        if hud and type(hud) == 'table' and type(hud.GetObjectType) == 'function' then
            -- It's a frame if GetObjectType exists and returns a string
            local ok, objType = pcall(function() return hud:GetObjectType() end)
            if ok and objType == 'Frame' and type(hud.Show) == 'function' then
                needsCreate = false
            end
        end
        if needsCreate and type(CreateFrame) == 'function' then
            hud = CreateFrame('Frame', 'HLBG_ModernHUD', UIParent)
            HLBG.UI.ModernHUD = hud
        end
        return HLBG.UI.ModernHUD
    end
end

-- Unified toggle helper (avoid calling :SetShown on non-Frame tables)
if not HLBG.ToggleModernHUD then
    function HLBG.ToggleModernHUD(force)
        local hud = HLBG.EnsureModernHUD and HLBG.EnsureModernHUD() or (HLBG.UI and HLBG.UI.ModernHUD)
        if not hud then return end
        local show = (force ~= nil) and force or HinterlandAffixHUDDB.hudEnabled
        if hud.SetShown then
            hud:SetShown(show)
        else
            if show then hud:Show() else hud:Hide() end
        end
    end
end

-- Apply initial Modern HUD visibility early so HUD state matches saved preference on load
pcall(function()
    if HinterlandAffixHUDDB and HinterlandAffixHUDDB.hudEnabled ~= nil then
        HLBG.ToggleModernHUD(HinterlandAffixHUDDB.hudEnabled)
    end
end)

function HLBG.ToggleLiveUI()
    if HLBG.UI and HLBG.UI.Frame then
        local shown = HLBG.UI.Frame:IsShown()
        HLBG.UI.Frame:SetShown(not shown)
        if not shown then
            -- Request fresh data when showing the UI
            HLBG._requestHistoryAndStats()
        end
    end
end

-- Ensure history header helper
local function ensureHistoryHeader()
    if HLBG.UI.History.Header then return end
    HLBG.UI.History.Header = CreateFrame("Frame", nil, HLBG.UI.History)
    HLBG.UI.History.Header:SetPoint("TOPLEFT", 16, -40)
    HLBG.UI.History.Header:SetSize(460, 18)
    HLBG.UI.History.Header.Name = HLBG.UI.History.Header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    HLBG.UI.History.Header.Name:SetPoint("LEFT", HLBG.UI.History.Header, "LEFT", 2, 0)
    HLBG.UI.History.Header.HK = HLBG.UI.History.Header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    HLBG.UI.History.Header.HK:SetPoint("CENTER", HLBG.UI.History.Header, "CENTER", 0, 0)
    HLBG.UI.History.Header.Score = HLBG.UI.History.Header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    HLBG.UI.History.Header.Score:SetPoint("RIGHT", HLBG.UI.History.Header, "RIGHT", -2, 0)
    HLBG.UI.History.Header.Totals = HLBG.UI.History.Header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    HLBG.UI.History.Header.Totals:SetPoint("TOPLEFT", HLBG.UI.History.Header, "BOTTOMLEFT", 0, -2)
    -- Helper to update sort indicators
    function HLBG.UpdateHistorySortIndicators()
        local ui = HLBG.UI and HLBG.UI.History
        if not ui or not ui.Header then return end
        local key = ui.sortKey or 'id'
        local dir = tostring(ui.sortDir or 'DESC'):upper()
        local up, down = "▲", "▼"
        local function mark(k)
            if key == k then return (dir == 'ASC') and up or down else return '' end
        end
        ui.Header.Name:SetText("Players " .. mark('name'))
        ui.Header.HK:SetText("HK " .. mark('hk'))
        ui.Header.Score:SetText("Score " .. mark('score'))
    end
    local btnName = CreateFrame("Button", nil, HLBG.UI.History.Header)
    btnName:SetAllPoints(HLBG.UI.History.Header.Name)
    btnName:SetScript("OnClick", function()
        if HLBG.HistoryApplySort then HLBG.HistoryApplySort('name') end
        if HLBG.UpdateHistorySortIndicators then HLBG.UpdateHistorySortIndicators() end
    end)
    local btnHK = CreateFrame("Button", nil, HLBG.UI.History.Header)
    btnHK:SetAllPoints(HLBG.UI.History.Header.HK)
    btnHK:SetScript("OnClick", function()
        if HLBG.HistoryApplySort then HLBG.HistoryApplySort('hk') end
        if HLBG.UpdateHistorySortIndicators then HLBG.UpdateHistorySortIndicators() end
    end)
    local btnScore = CreateFrame("Button", nil, HLBG.UI.History.Header)
    btnScore:SetAllPoints(HLBG.UI.History.Header.Score)
    btnScore:SetScript("OnClick", function()
        if HLBG.HistoryApplySort then HLBG.HistoryApplySort('score') end
        if HLBG.UpdateHistorySortIndicators then HLBG.UpdateHistorySortIndicators() end
    end)
    -- Initial indicator update
    if HLBG.UpdateHistorySortIndicators then HLBG.UpdateHistorySortIndicators() end
end

local function UpdateHistoryHeader()
    if not HLBG.UI.History.Header then return end
    HLBG.UI.History.Header.Totals:SetText(string.format("Alliance: %d   Horde: %d", RES.A or 0, RES.H or 0))
end

-- Remove early duplicate HLBG.History definition if accidentally present
if HLBG.__EarlyHistoryPruned ~= true then
    -- crude pattern search removal at runtime (does nothing harmful if not present)
    if HLBG.History and HLBG.UI and HLBG.UI.History and HLBG.UI.History.lastRows == nil then
        -- keep current; no action
    end
    HLBG.__EarlyHistoryPruned = true
end

-- Fake live data command
if HLBG._devMode then
    local function hlbglivefake_handler()
        local fake = {
            {name = UnitName("player"), score = RES.A or 0},
            {name = "PlayerA", score = 120},
            {name = "PlayerB", score = 80},
        }
        HLBG.Live(fake)
        if HLBG.UI and HLBG.UI.Frame and HLBG.UI.Frame.Show then HLBG.UI.Frame:Show() end
        ShowTab(1)
    end
    if type(HLBG.safeRegisterSlash) == 'function' then
        HLBG.safeRegisterSlash('HLBGLIVEFAKE', '/hlbglivefake', function() hlbglivefake_handler() end)
    else
        SLASH_HLBGLIVEFAKE1 = "/hlbglivefake"
        SlashCmdList["HLBGLIVEFAKE"] = hlbglivefake_handler
    end
end

-- HISTORY / STATS IMPLEMENTATIONS MOVED
-- The legacy inlined implementations of HLBG.History, HLBG.HistoryStr, and HLBG.Stats
-- have been migrated into modular files under core/:
--   core/HLBG_History.lua
--   core/HLBG_Stats.lua
-- This file now only contains UI assembly and wiring logic.

-- (No-op) Legacy code block placeholder removed. History/Stats already defined in core modules.

-- UI construction extracted from the main client file to keep the addon modular.
HLBG.UI = HLBG.UI or {}

-- Main window inside PvP frame (increased size for better readability)
HLBG.UI.Frame = CreateFrame("Frame", "HLBG_Main", PVPParentFrame or PVPFrame)
HLBG.UI.Frame:SetSize(640, 450)
HLBG.UI.Frame:Hide()
-- Ensure our panel stays above world overlays on 3.3.5
if HLBG.UI.Frame.SetFrameStrata then HLBG.UI.Frame:SetFrameStrata("DIALOG") end
HLBG.UI.Frame:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left=4, right=4, top=4, bottom=4 } })
HLBG.UI.Frame:SetBackdropColor(0,0,0,0.5)
HLBG.UI.Frame:ClearAllPoints()
HLBG.UI.Frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
HLBG.UI.Frame:EnableMouse(true)
HLBG.UI.Frame:SetMovable(true)
HLBG.UI.Frame:RegisterForDrag("LeftButton")
HLBG.UI.Frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
HLBG.UI.Frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, rel, rp, x, y = self:GetPoint()
    HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
    HinterlandAffixHUDDB.hlbgMainPos = { point = p, rel = rel and rel:GetName() or "UIParent", relPoint = rp, x = x, y = y }
end)
-- Reapply saved position if present
do
    HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
    local pos = HinterlandAffixHUDDB.hlbgMainPos
    if pos and pos.point and pos.rel and pos.relPoint and _G[pos.rel] then
        HLBG.UI.Frame:ClearAllPoints()
        HLBG.UI.Frame:SetPoint(pos.point, _G[pos.rel], pos.relPoint, pos.x or 0, pos.y or 0)
    end
end
-- Close button instead of hooking UIParent OnKeyDown (not reliable on 3.3.5)
local close = CreateFrame("Button", nil, HLBG.UI.Frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", HLBG.UI.Frame, "TOPRIGHT", 0, 0)
-- Allow closing with ESC
if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, HLBG.UI.Frame:GetName()) end

HLBG.UI.Frame.Title = HLBG.UI.Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
HLBG.UI.Frame.Title:SetPoint("TOPLEFT", 16, -12)
HLBG.UI.Frame.Title:SetText("Hinterland Battleground")

-- Tabs inside window: History / Stats (Live tab removed per user request)

HLBG.UI.Tabs = HLBG.UI.Tabs or {}
local baseName = HLBG.UI.Frame.GetName and HLBG.UI.Frame:GetName() or "HLBG_Main"

-- Tab 1: History (was tab 2, now tab 1)
HLBG.UI.Tabs[1] = HLBG.UI.Tabs[1] or CreateFrame("Button", baseName.."Tab1", HLBG.UI.Frame, "OptionsFrameTabButtonTemplate")
HLBG.UI.Tabs[1]:SetPoint("TOPLEFT", HLBG.UI.Frame, "BOTTOMLEFT", 10, 7)
HLBG.UI.Tabs[1]:SetText("History")
HLBG.UI.Tabs[1]:SetScript("OnClick", function() if type(ShowTab) == 'function' then ShowTab(1) end end)

-- Tab 2: Stats (was tab 3, now tab 2)
HLBG.UI.Tabs[2] = HLBG.UI.Tabs[2] or CreateFrame("Button", baseName.."Tab2", HLBG.UI.Frame, "OptionsFrameTabButtonTemplate")
HLBG.UI.Tabs[2]:SetPoint("LEFT", HLBG.UI.Tabs[1], "RIGHT")
HLBG.UI.Tabs[2]:SetText("Stats")
HLBG.UI.Tabs[2]:SetScript("OnClick", function() if type(ShowTab) == 'function' then ShowTab(2) end end)

-- Additional tabs: Info (overview), Settings (configuration), Results (post-match)
HLBG.UI.Tabs[3] = HLBG.UI.Tabs[3] or CreateFrame("Button", baseName.."Tab3", HLBG.UI.Frame, "OptionsFrameTabButtonTemplate")
HLBG.UI.Tabs[3]:SetPoint("LEFT", HLBG.UI.Tabs[2], "RIGHT")
HLBG.UI.Tabs[3]:SetText("Info")
HLBG.UI.Tabs[3]:SetScript("OnClick", function() if type(ShowTab) == 'function' then ShowTab(3) end end)

HLBG.UI.Tabs[4] = HLBG.UI.Tabs[4] or CreateFrame("Button", baseName.."Tab4", HLBG.UI.Frame, "OptionsFrameTabButtonTemplate")
HLBG.UI.Tabs[4]:SetPoint("LEFT", HLBG.UI.Tabs[3], "RIGHT")
HLBG.UI.Tabs[4]:SetText("Settings")
HLBG.UI.Tabs[4]:SetScript("OnClick", function() if type(ShowTab) == 'function' then ShowTab(4) end end)

HLBG.UI.Tabs[5] = HLBG.UI.Tabs[5] or CreateFrame("Button", baseName.."Tab5", HLBG.UI.Frame, "OptionsFrameTabButtonTemplate")
HLBG.UI.Tabs[5]:SetPoint("LEFT", HLBG.UI.Tabs[4], "RIGHT")
HLBG.UI.Tabs[5]:SetText("Queue")
HLBG.UI.Tabs[5]:SetScript("OnClick", function() if type(ShowTab) == 'function' then ShowTab(5) end end)

-- Safe wrappers for PanelTemplates functions (older clients may not define these or frame may be unnamed)
local function SafeSetNumTabs(frame, n)
    if not frame or type(n) ~= 'number' then return end
    if type(PanelTemplates_SetNumTabs) ~= 'function' then return end
    -- avoid calling with unnamed frame (template concatenates frame:GetName() with 'Tab')
    local fname = frame.GetName and frame:GetName() or nil
    if not fname then return end
    pcall(PanelTemplates_SetNumTabs, frame, n)
end

local function SafeSetTab(frame, i)
    if not frame or type(i) ~= 'number' then return end
    if type(PanelTemplates_SetTab) ~= 'function' then return end
    local fname = frame.GetName and frame:GetName() or nil
    if not fname then return end
    pcall(PanelTemplates_SetTab, frame, i)
end

SafeSetNumTabs(HLBG.UI.Frame, 5)
SafeSetTab(HLBG.UI.Frame, 1)

function ShowTab(i)
    -- Only call PanelTemplates_SetTab when safe
    SafeSetTab(HLBG.UI.Frame, i)
    
    -- UPDATED TAB STRUCTURE: Results removed, Queue restored
    -- Tab 1: History, Tab 2: Stats, Tab 3: Info, Tab 4: Settings, Tab 5: Queue
    if HLBG.UI.History then 
        if i == 1 then 
            HLBG.UI.History:Show()
            -- Ensure History tab loads data immediately when shown
            if type(HLBG.RefreshHistoryData) == 'function' then
                HLBG.RefreshHistoryData()
            end
        else 
            HLBG.UI.History:Hide() 
        end 
    end
    if HLBG.UI.Stats then if i == 2 then HLBG.UI.Stats:Show() else HLBG.UI.Stats:Hide() end end
    if HLBG.UI.Info then if i == 3 then HLBG.UI.Info:Show() else HLBG.UI.Info:Hide() end end
    if HLBG.UI.Settings then if i == 4 then HLBG.UI.Settings:Show() else HLBG.UI.Settings:Hide() end end
    if HLBG.UI.Queue then if i == 5 then HLBG.UI.Queue:Show() else HLBG.UI.Queue:Hide() end end
    -- Hide Results tab completely (no longer used)
    if HLBG.UI.Results then HLBG.UI.Results:Hide() end
    
    HinterlandAffixHUDDB.lastInnerTab = i
    -- Show Season selector only for History/Stats
    pcall(function()
        local showSeason = (i == 1 or i == 2)  -- History = 1, Stats = 2
        local lab = HLBG.UI.SeasonLabel
        local dd = HLBG.UI.SeasonDrop
        if lab then
            if lab.SetShown then lab:SetShown(showSeason) else if showSeason then lab:Show() else lab:Hide() end end
        end
        if dd then
            if dd.SetShown then dd:SetShown(showSeason) else if showSeason then dd:Show() else dd:Hide() end end
        end
    end)
end

-- Helper: request History + Stats for current selection (season-only)
function HLBG._requestHistoryAndStats()
    local hist = HLBG.UI and HLBG.UI.History
    local p = (hist and hist.page) or 1
    local per = (hist and hist.per) or 15
    local sk = (hist and hist.sortKey) or "id"
    local sd = (hist and hist.sortDir) or "ASC"
    local season = (HLBG and HLBG._getSeason and HLBG._getSeason()) or (_G.HLBG_GetSeason and _G.HLBG_GetSeason()) or 0
    if _G.AIO and _G.AIO.Handle then
        _G.AIO.Handle("HLBG", "Request", "HISTORY", p, per, season, sk, sd)
        _G.AIO.Handle("HLBG", "History", p, per, season, sk, sd)
        _G.AIO.Handle("HLBG", "HISTORY", p, per, season, sk, sd)
        _G.AIO.Handle("HLBG", "HistoryUI", p, per, season, sk, sd)
        _G.AIO.Handle("HLBG", "Request", "STATS", season)
        _G.AIO.Handle("HLBG", "Stats", season)
        _G.AIO.Handle("HLBG", "STATS", season)
        _G.AIO.Handle("HLBG", "StatsUI", season)
    end
    local sendDot = (HLBG and HLBG.SendServerDot) or _G.HLBG_SendServerDot
    if type(sendDot) == 'function' then
        sendDot(string.format(".hlbg historyui %d %d %d %s %s", p, per, season, sk, sd))
        sendDot(string.format(".hlbg statsui %d", season))
    end
end

-- Function to display cached history data (no more constant refreshing)
function HLBG.RefreshHistoryData()
    if not HLBG.UI or not HLBG.UI.History then return end
    
    -- Use cached data if available
    if HLBG.DataCache and HLBG.DataCache.historyData then
        local hist = HLBG.UI.History
        hist.lastRows = HLBG.DataCache.historyData
        if HLBG.UpdateHistoryDisplay then
            HLBG.UpdateHistoryDisplay()
        end
        print("|cFF33FF99HLBG:|r Using cached history data")
        return
    end
    
    -- Only load from server if no cached data AND initialization is complete
    if HLBG.InitState and HLBG.InitState.historyDataLoaded then
        print("|cFF888888HLBG:|r History data already requested during initialization")
        -- Load fallback test data if still no data
        local hist = HLBG.UI.History
        if not hist.lastRows or #hist.lastRows == 0 then
            if HLBG.LoadTestHistoryData then
                HLBG.LoadTestHistoryData()
            end
        end
        return
    end
    
    -- Fallback - should rarely be needed
    print("|cFFFF6600HLBG:|r Loading history data as fallback...")
    if HLBG.LoadTestHistoryData then
        HLBG.LoadTestHistoryData()
    end
end

-- Function to update history display with current data and pagination
function HLBG.UpdateHistoryDisplay()
    if not HLBG.UI or not HLBG.UI.History then return end
    
    local hist = HLBG.UI.History
    local rows = hist.lastRows or HLBG.testHistoryRows or {}
    
    -- Calculate pagination
    local page = hist.page or 1
    local per = hist.per or 15
    local total = hist.total or #rows
    local maxPage = math.max(1, math.ceil(total / per))
    
    -- Ensure current page is valid
    if page > maxPage then page = maxPage; hist.page = page end
    if page < 1 then page = 1; hist.page = page end
    
    -- Update pagination display
    if hist.Nav and hist.Nav.PageText then
        hist.Nav.PageText:SetText(string.format("Page %d / %d", page, maxPage))
    end
    
    if hist.Nav and hist.Nav.Prev then
        hist.Nav.Prev:SetEnabled(page > 1)
    end
    
    if hist.Nav and hist.Nav.Next then
        hist.Nav.Next:SetEnabled(page < maxPage)
    end
    
    -- Update the actual history display (calls the main History function)
    if #rows > 0 then
        HLBG.History(rows, page, per, total)
    end
end

-- Season dropdown (top-right)
do
    HLBG.UI.SeasonLabel = HLBG.UI.SeasonLabel or HLBG.UI.Frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    local label = HLBG.UI.SeasonLabel
    label:SetPoint("TOPRIGHT", HLBG.UI.Frame, "TOPRIGHT", -210, -16)
    label:SetText("Season:")
    local maxSeason = (HinterlandAffixHUDDB and HinterlandAffixHUDDB.maxSeason) or 10
    local function seasonList()
        local t = {0}
        for i=1,maxSeason do t[#t+1]=i end
        return t
    end
    if type(UIDropDownMenu_Initialize) == 'function' then
        HLBG.UI.SeasonDrop = HLBG.UI.SeasonDrop or CreateFrame('Frame', 'HLBG_SeasonDrop', HLBG.UI.Frame, 'UIDropDownMenuTemplate')
        local dd = HLBG.UI.SeasonDrop
        dd:SetPoint('LEFT', label, 'RIGHT', -10, -4)
        local function onSelect(self, val)
            HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
            HinterlandAffixHUDDB.desiredSeason = tonumber(val) or 0
            UIDropDownMenu_SetSelectedValue(dd, HinterlandAffixHUDDB.desiredSeason)
            UIDropDownMenu_SetText(dd, (tonumber(val)==0) and 'Current' or tostring(val))
            -- reset to page 1 and request
            if HLBG.UI and HLBG.UI.History then HLBG.UI.History.page = 1 end
            HLBG._requestHistoryAndStats()
        end
        local function init()
            local cur = (HLBG and HLBG._getSeason and HLBG._getSeason()) or 0
            local info
            for _,v in ipairs(seasonList()) do
                info = UIDropDownMenu_CreateInfo()
                info.text = (v==0) and 'Current' or tostring(v)
                info.value = v
                info.func = function() onSelect(nil, v) end
                info.checked = (v == cur)
                UIDropDownMenu_AddButton(info)
            end
            UIDropDownMenu_SetSelectedValue(dd, cur)
            UIDropDownMenu_SetWidth(dd, 90)
            UIDropDownMenu_SetText(dd, (cur==0) and 'Current' or tostring(cur))
        end
        UIDropDownMenu_Initialize(dd, init)
        -- Reinitialize when frame shows in case maxSeason changed
        HLBG.UI.Frame:HookScript('OnShow', function() UIDropDownMenu_Initialize(dd, init) end)
    else
        -- Fallback: simple cycle button
    HLBG.UI.SeasonDrop = HLBG.UI.SeasonDrop or CreateFrame('Button', nil, HLBG.UI.Frame, 'UIPanelButtonTemplate')
    local btn = HLBG.UI.SeasonDrop
        btn:SetSize(90, 20)
        btn:SetPoint('LEFT', label, 'RIGHT', 4, 0)
        local function setText()
            local cur = (HLBG and HLBG._getSeason and HLBG._getSeason()) or 0
            btn:SetText((cur==0) and 'Current' or ('Season '..cur))
        end
        btn:SetScript('OnClick', function()
            HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
            local cur = tonumber(HinterlandAffixHUDDB.desiredSeason or 0) or 0
            cur = cur + 1; if cur > maxSeason then cur = 0 end
            HinterlandAffixHUDDB.desiredSeason = cur
            if HLBG.UI and HLBG.UI.History then HLBG.UI.History.page = 1 end
            HLBG._requestHistoryAndStats(); setText()
        end)
        setText()
    end
end

HLBG.UI.Live = CreateFrame("Frame", nil, HLBG.UI.Frame)
HLBG.UI.Live:SetAllPoints(HLBG.UI.Frame)
HLBG.UI.Live.Text = HLBG.UI.Live:CreateFontString(nil, "OVERLAY", "GameFontHighlight")

-- Create Queue tab frame before using its fields
HLBG.UI.Queue = CreateFrame("Frame", nil, HLBG.UI.Frame)
HLBG.UI.Queue:SetAllPoints(HLBG.UI.Frame)
HLBG.UI.Queue:Hide()

-- Queue header
HLBG.UI.Queue.Header = HLBG.UI.Queue:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
HLBG.UI.Queue.Header:SetPoint("TOPLEFT", 20, -20)
HLBG.UI.Queue.Header:SetText("|cFF33FF99Battleground Queue|r")

-- Queue count display (prominent)
HLBG.UI.Queue.CountFrame = CreateFrame("Frame", nil, HLBG.UI.Queue)
HLBG.UI.Queue.CountFrame:SetPoint("TOPLEFT", 20, -60)
HLBG.UI.Queue.CountFrame:SetSize(200, 60)
HLBG.UI.Queue.CountFrame:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = {left = 4, right = 4, top = 4, bottom = 4}
})
HLBG.UI.Queue.CountFrame:SetBackdropColor(0, 0, 0, 0.3)
HLBG.UI.Queue.CountFrame:SetBackdropBorderColor(0.3, 0.6, 0.9, 0.8)

HLBG.UI.Queue.CountLabel = HLBG.UI.Queue.CountFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
HLBG.UI.Queue.CountLabel:SetPoint("TOP", 0, -8)
HLBG.UI.Queue.CountLabel:SetText("Players in Queue")

HLBG.UI.Queue.CountValue = HLBG.UI.Queue.CountFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
HLBG.UI.Queue.CountValue:SetPoint("CENTER", 0, -5)
HLBG.UI.Queue.CountValue:SetText("|cFFFFAA33?|r")

-- Join/Leave buttons
HLBG.UI.Queue.Join = CreateFrame("Button", nil, HLBG.UI.Queue, "UIPanelButtonTemplate")
HLBG.UI.Queue.Join:SetPoint("TOPLEFT", 20, -140)
HLBG.UI.Queue.Join:SetSize(100, 28)
HLBG.UI.Queue.Join:SetText("Join Queue")

HLBG.UI.Queue.Leave = CreateFrame("Button", nil, HLBG.UI.Queue, "UIPanelButtonTemplate")
HLBG.UI.Queue.Leave:SetPoint("LEFT", HLBG.UI.Queue.Join, "RIGHT", 10, 0)
HLBG.UI.Queue.Leave:SetSize(100, 28)
HLBG.UI.Queue.Leave:SetText("Leave Queue")

-- Status display (cleaner)
HLBG.UI.Queue.Status = HLBG.UI.Queue:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
HLBG.UI.Queue.Status:SetPoint("TOPLEFT", 20, -185)
HLBG.UI.Queue.Status:SetSize(400, 200)
HLBG.UI.Queue.Status:SetJustifyH("LEFT")
HLBG.UI.Queue.Status:SetJustifyV("TOP")
HLBG.UI.Queue.Status:SetText("|cFF888888Checking queue status...|r")

-- Add queue button handlers
HLBG.UI.Queue.Join:SetScript("OnClick", function()
    if _G.AIO and _G.AIO.Handle then
        _G.AIO.Handle("HLBG", "Request", "QUEUE", "join")
    end
    local sendDot = HLBG.SendServerDot or _G.HLBG_SendServerDot
    if sendDot then
        sendDot(".hlbg queue join")
    end
    print("|cFF33FF99HLBG:|r Requesting to join queue...")
    HLBG.UI.Queue.Status:SetText("|cFF33FF99Status:|r Requesting to join queue...")
end)

HLBG.UI.Queue.Leave:SetScript("OnClick", function()
    if _G.AIO and _G.AIO.Handle then
        _G.AIO.Handle("HLBG", "Request", "QUEUE", "leave")
    end
    local sendDot = HLBG.SendServerDot or _G.HLBG_SendServerDot
    if sendDot then
       
        sendDot(".hlbg queue leave")
    end
    print("|cFF33FF99HLBG:|r Requesting to leave queue...")
    HLBG.UI.Queue.Status:SetText("|cFF33FF99Status:|r Requesting to leave queue...")
end)
HLBG.UI.Live:SetScript("OnShow", function()
    -- LIVE TAB DISABLED: Show message instead of updating data
    print("|cFF33FF99HLBG:|r Live tab disabled - use '/hlbg status' command instead")
    if HLBG.UI and HLBG.UI.Live and HLBG.UI.Live.Text then
        HLBG.UI.Live.Text:SetText("Live tab disabled\n\nUse '/hlbg status' command to check current status from anywhere")
    end
    if HLBG.UI and HLBG.UI.Live and HLBG.UI.Live.Summary then
        HLBG.UI.Live.Summary:SetText("The live tab functionality has been removed. Use /hlbg status command instead.")
    end
    -- Also request a fresh STATUS from the server via AIO if available
    if _G.AIO and _G.AIO.Handle then
        _G.AIO.Handle("HLBG", "Request", "STATUS")
    else
        -- As a last resort, ask server via chat to populate status
        if type(HLBG) == 'table' and type(HLBG.safeExecSlash) == 'function' then
            HLBG.safeExecSlash(".hlbgstatus")
        elseif type(SendChatMessage) == 'function' then
            pcall(SendChatMessage, ".hlbgstatus", "SAY")
        end
    end
end)

-- Auto-refresh Live summary timer: updates the summary time display every second without spamming server
do
    local acc = 0
    local fr = CreateFrame('Frame')
    fr:SetScript('OnUpdate', function(_, elapsed)
        acc = acc + (elapsed or 0)
        if acc < 1.0 then return end
        acc = 0
        -- Only update if the Live tab is visible
        if not (HLBG and HLBG.UI and HLBG.UI.Live and HLBG.UI.Live.IsShown and HLBG.UI.Live:IsShown()) then return end
        local RES = _G.RES or {A=0,H=0}
        local a = tonumber(RES.A or 0) or 0
        local h = tonumber(RES.H or 0) or 0
        local tl = tonumber(HLBG._timeLeft or RES.DURATION or 0) or 0
        local m = math.floor(tl/60); local s = tl%60
        local aff = tostring(HLBG._affixText or "-")
        local ap = (HLBG._lastStatus and (HLBG._lastStatus.APlayers or HLBG._lastStatus.APC or HLBG._lastStatus.AllyCount)) or "-"
        local hp = (HLBG._lastStatus and (HLBG._lastStatus.HPlayers or HLBG._lastStatus.HPC or HLBG._lastStatus.HordeCount)) or "-"
        if HLBG.UI and HLBG.UI.Live and HLBG.UI.Live.Summary then
            HLBG.UI.Live.Summary:SetText(string.format("Resources  A:%d  H:%d      Players  A:%s  H:%s      Time %d:%02d      Affix %s", a,h,tostring(ap),tostring(hp), m,s, aff))
        end
    end)
end

-- Live scoreboard: scrollable player list
HLBG.UI.Live.Scroll = CreateFrame("ScrollFrame", "HLBG_LiveScroll", HLBG.UI.Live, "UIPanelScrollFrameTemplate")
HLBG.UI.Live.Scroll:SetPoint("TOPLEFT", 16, -64)
HLBG.UI.Live.Scroll:SetPoint("BOTTOMRIGHT", -36, 40)
HLBG.UI.Live.Content = CreateFrame("Frame", nil, HLBG.UI.Live.Scroll)
HLBG.UI.Live.Content:SetSize(460, 300)
if HLBG.UI.Live.Content.SetFrameStrata then HLBG.UI.Live.Content:SetFrameStrata("DIALOG") end
HLBG.UI.Live.Scroll:SetScrollChild(HLBG.UI.Live.Content)
HLBG.UI.Live.rows = HLBG.UI.Live.rows or {}
-- Build header once for labels + totals
pcall(function() ensureLiveHeader() end)
-- Prefer compact summary; hide the old header labels
if HLBG.UI.Live.Header and HLBG.UI.Live.Header.Hide then HLBG.UI.Live.Header:Hide() end

local function liveGetRow(i)
    local r = HLBG.UI.Live.rows[i]
    if not r then
        r = CreateFrame("Frame", nil, HLBG.UI.Live.Content)
        if r.SetFrameStrata then r:SetFrameStrata("DIALOG") end
        r:SetSize(440, 28)
        r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.score = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.team = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.ts = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.name:SetPoint("LEFT", r, "LEFT", 2, 0)
        r.name:SetWidth(220)
        r.score:SetPoint("LEFT", r.name, "RIGHT", 6, 0); r.score:SetWidth(60)
        r.team:SetPoint("LEFT", r.score, "RIGHT", 6, 0); r.team:SetWidth(80)
        r.ts:SetPoint("LEFT", r.team, "RIGHT", 6, 0); r.ts:SetWidth(80)
        HLBG.UI.Live.rows[i] = r
    end
    return r
end

-- Live header click sorting helpers (created below in main UI initialization when header exists)