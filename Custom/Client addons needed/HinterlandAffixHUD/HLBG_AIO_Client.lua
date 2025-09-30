-- HLBG_AIO_Client.lua
-- Client-side AIO UI and HUD replacement

local AIO = AIO or {}

local HLBG = (AIO.AddHandlers and AIO.AddHandlers("HLBG", {})) or {}
_G.HLBG = HLBG

-- Early bootstrap: ensure slash commands exist even if later init fails
do
    local ver = GetAddOnMetadata and GetAddOnMetadata("HinterlandAffixHUD", "Version") or "?"
    DEFAULT_CHAT_FRAME:AddMessage(string.format("HLBG AIO client active (HinterlandAffixHUD v%s)", tostring(ver)))
    -- Minimal OpenUI so /hlbg always works for debugging
    if type(HLBG.OpenUI) ~= "function" then
        HLBG.OpenUI = function()
            DEFAULT_CHAT_FRAME:AddMessage("HLBG.OpenUI invoked (bootstrap)")
        end
    end
    -- Minimal PONG handler so /hlbgping can verify round-trip
    if type(HLBG.PONG) ~= "function" then
        HLBG.PONG = function() DEFAULT_CHAT_FRAME:AddMessage("HLBG: PONG from server") end
    end
    -- Register slash commands now
    SLASH_HLBG1 = "/hlbg"
    SlashCmdList["HLBG"] = function(msg)
        local ok, err = pcall(function()
            HLBG.OpenUI()
            if AIO and AIO.Handle then
                AIO.Handle("HLBG", "Request", "HISTORY", 1, 25, "id", "DESC")
                AIO.Handle("HLBG", "Request", "STATS")
            end
        end)
        if not ok then DEFAULT_CHAT_FRAME:AddMessage("HLBG error (/hlbg): "..tostring(err)) end
    end
    SLASH_HLBGPING1 = "/hlbgping"
    SlashCmdList["HLBGPING"] = function()
        if AIO and AIO.Handle then AIO.Handle("HLBG", "Request", "PING") else DEFAULT_CHAT_FRAME:AddMessage("HLBG: AIO client not available") end
    end
end
-- (moved startup message to early bootstrap above)

local UI = {}
local RES = { A = 0, H = 0, END = 0, LOCK = 0 }
HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
HinterlandAffixHUDDB.useAddonHud = (HinterlandAffixHUDDB.useAddonHud ~= false) -- default ON
HinterlandAffixHUDDB.scaleHud = HinterlandAffixHUDDB.scaleHud or 1.0
HinterlandAffixHUDDB.anchorHud = HinterlandAffixHUDDB.anchorHud or { point = "TOPRIGHT", rel = "UIParent", relPoint = "TOPRIGHT", x = -30, y = -150 }
HinterlandAffixHUDDB.lastPvPTab = HinterlandAffixHUDDB.lastPvPTab or 1
HinterlandAffixHUDDB.lastInnerTab = HinterlandAffixHUDDB.lastInnerTab or 1

local function SecondsToClock(sec)
    if sec < 0 then sec = 0 end
    local m = math.floor(sec / 60)
    local s = math.floor(sec % 60)
    return string.format("%d:%02d", m, s)
end

-- HUD frame (right side), looks like WG but addon-driven
UI.HUD = CreateFrame("Frame", "HLBG_HUD", UIParent)
UI.HUD:SetSize(240, 92)
UI.HUD:SetPoint(HinterlandAffixHUDDB.anchorHud.point, _G[HinterlandAffixHUDDB.anchorHud.rel] or UIParent, HinterlandAffixHUDDB.anchorHud.relPoint, HinterlandAffixHUDDB.anchorHud.x, HinterlandAffixHUDDB.anchorHud.y)
UI.HUD:SetScale(HinterlandAffixHUDDB.scaleHud)
UI.HUD:SetMovable(true)
UI.HUD:EnableMouse(true)
UI.HUD:RegisterForDrag("LeftButton")
UI.HUD:SetScript("OnDragStart", function(self)
    if not HinterlandAffixHUDDB.lockHud then self:StartMoving() end
end)
UI.HUD:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, rel, rp, x, y = self:GetPoint()
    HinterlandAffixHUDDB.anchorHud = { point = p, rel = rel and rel:GetName() or "UIParent", relPoint = rp, x = x, y = y }
end)
UI.HUD:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left=4, right=4, top=4, bottom=4 } })
UI.HUD:SetBackdropColor(0, 0, 0, 0.5)
UI.HUD:Hide()

UI.HUD.A = UI.HUD:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
UI.HUD.A:SetPoint("TOPRIGHT", -4, -4)
UI.HUD.H = UI.HUD:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
UI.HUD.H:SetPoint("TOPRIGHT", UI.HUD.A, "BOTTOMRIGHT", 0, -6)
UI.HUD.Timer = UI.HUD:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
UI.HUD.Timer:SetPoint("TOPRIGHT", UI.HUD.H, "BOTTOMRIGHT", 0, -6)

UI.Affix = CreateFrame("Frame", "HLBG_AffixHeadline", UIParent)
UI.Affix:SetSize(320, 30)
UI.Affix:SetPoint("TOPLEFT", 30, -150)
UI.Affix:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left=4, right=4, top=4, bottom=4 } })
UI.Affix:SetBackdropColor(0, 0, 0, 0.4)
UI.Affix.Text = UI.Affix:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge"); UI.Affix.Text:SetShadowOffset(1, -1)
UI.Affix.Text:SetPoint("CENTER")
UI.Affix:Hide()

UI.HUD:SetScript("OnUpdate", function(self, dt)
    if RES.END and RES.END > 0 then
        local now = time()
        local left = RES.END - now
        if left < 0 then left = 0 end
        UI.HUD.Timer:SetText("Time Remaining: " .. SecondsToClock(left))
    end
end)

local function UpdateHUD()
    if not HinterlandAffixHUDDB.useAddonHud then
        UI.HUD:Hide(); local w = _G["WorldStateAlwaysUpFrame"]; if w then w:Show() end; return
    end
    UI.HUD.A:SetText("|TInterface/TargetingFrame/UI-PVP-ALLIANCE:16|t Resources: " .. tostring(RES.A or 0) .. "/450")
    UI.HUD.H:SetText("|TInterface/TargetingFrame/UI-PVP-HORDE:16|t Resources: " .. tostring(RES.H or 0) .. "/450")
    local w = _G["WorldStateAlwaysUpFrame"]; if w then w:Hide() end
    UI.HUD:Show()
end

local function InHinterlands()
    local z = GetRealZoneText() or ""
    return z == "The Hinterlands"
end

local function HideBlizzHUDDeep()
    local w = _G["WorldStateAlwaysUpFrame"]
    if not w then return end
    w:Hide()
    if not w._hlbgHooked then
        w._hlbgHooked = true
        w:HookScript("OnShow", function(self)
            if HinterlandAffixHUDDB.useAddonHud and InHinterlands() then self:Hide() end
        end)
    end
end

local function UnhideBlizzHUDDeep()
    local w = _G["WorldStateAlwaysUpFrame"]
    if not w then return end
    w:Show()
end

local zoneWatcher = CreateFrame("Frame")
zoneWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
zoneWatcher:RegisterEvent("ZONE_CHANGED_NEW_AREA")
zoneWatcher:RegisterEvent("ZONE_CHANGED")
zoneWatcher:RegisterEvent("ZONE_CHANGED_INDOORS")
zoneWatcher:SetScript("OnEvent", function()
    if InHinterlands() then
        UpdateHUD(); if HinterlandAffixHUDDB.useAddonHud then HideBlizzHUDDeep() end
    else
        UI.HUD:Hide(); UI.Affix:Hide(); UnhideBlizzHUDDeep()
    end
end)

-- Main window inside PvP frame
UI.Frame = CreateFrame("Frame", "HLBG_Main", PVPParentFrame or PVPFrame)
UI.Frame:SetSize(512, 350)
UI.Frame:Hide()
UI.Frame:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left=4, right=4, top=4, bottom=4 } })
UI.Frame:SetBackdropColor(0,0,0,0.5)
UI.Frame:ClearAllPoints()
UI.Frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
UI.Frame:EnableMouse(true)
UI.Frame:SetMovable(true)
UI.Frame:RegisterForDrag("LeftButton")
UI.Frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
UI.Frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
-- Close button instead of hooking UIParent OnKeyDown (not reliable on 3.3.5)
local close = CreateFrame("Button", nil, UI.Frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", UI.Frame, "TOPRIGHT", 0, 0)

UI.Frame.Title = UI.Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
UI.Frame.Title:SetPoint("TOPLEFT", 16, -12)
UI.Frame.Title:SetText("Hinterland Battleground")

-- Tabs inside window: Live / History / Stats
UI.Tabs = {}
UI.Tabs[1] = CreateFrame("Button", UI.Frame:GetName().."Tab1", UI.Frame, "OptionsFrameTabButtonTemplate")
UI.Tabs[1]:SetPoint("TOPLEFT", UI.Frame, "BOTTOMLEFT", 10, 7)
UI.Tabs[1]:SetText("Live")
UI.Tabs[2] = CreateFrame("Button", UI.Frame:GetName().."Tab2", UI.Frame, "OptionsFrameTabButtonTemplate")
UI.Tabs[2]:SetPoint("LEFT", UI.Tabs[1], "RIGHT")
UI.Tabs[2]:SetText("History")
UI.Tabs[3] = CreateFrame("Button", UI.Frame:GetName().."Tab3", UI.Frame, "OptionsFrameTabButtonTemplate")
UI.Tabs[3]:SetPoint("LEFT", UI.Tabs[2], "RIGHT")
UI.Tabs[3]:SetText("Stats")

PanelTemplates_SetNumTabs(UI.Frame, 3)
PanelTemplates_SetTab(UI.Frame, 1)

local function ShowTab(i)
    PanelTemplates_SetTab(UI.Frame, i)
    if i == 1 then UI.Live:Show() else UI.Live:Hide() end
    if i == 2 then UI.History:Show() else UI.History:Hide() end
    if i == 3 then UI.Stats:Show() else UI.Stats:Hide() end
    HinterlandAffixHUDDB.lastInnerTab = i
end

UI.Live = CreateFrame("Frame", nil, UI.Frame)
UI.Live:SetAllPoints(UI.Frame)
UI.Live.Text = UI.Live:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
UI.Live.Text:SetPoint("TOPLEFT", 16, -40)
UI.Live.Text:SetText("Live status shows resources, timer and affix. Use the HUD on the world view.")

UI.History = CreateFrame("Frame", nil, UI.Frame)
UI.History:SetAllPoints(UI.Frame)
UI.History:Hide()
UI.History.Scroll = CreateFrame("ScrollFrame", "HLBG_HistoryScroll", UI.History, "UIPanelScrollFrameTemplate")
UI.History.Scroll:SetPoint("TOPLEFT", 16, -40)
UI.History.Scroll:SetPoint("BOTTOMRIGHT", -36, 16)
UI.History.Content = CreateFrame("Frame", nil, UI.History.Scroll)
UI.History.Content:SetSize(440, 300)
UI.History.Scroll:SetScrollChild(UI.History.Content)

UI.Stats = CreateFrame("Frame", nil, UI.Frame)
UI.Stats:SetAllPoints(UI.Frame)
UI.Stats:Hide()
UI.Stats.Text = UI.Stats:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
UI.Stats.Text:SetPoint("TOPLEFT", 16, -40)
UI.Stats.Text:SetText("Stats will appear here.")

-- History controls: columns, pagination
UI.History.Columns = {}
local headers = { {text="ID", w=40}, {text="Timestamp", w=140}, {text="Winner", w=80}, {text="Affix", w=100}, {text="Reason", w=80} }
local x = 0
for i,col in ipairs(headers) do
    local h = CreateFrame("Button", nil, UI.History.Content)
    h:SetPoint("TOPLEFT", x, 0)
    h:SetSize(col.w, 18)
    h.Text = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    h.Text:SetPoint("LEFT", 2, 0)
    h.Text:SetText(col.text)
    h:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine("Click to sort", 1,1,1); GameTooltip:Show() end)
    h:SetScript("OnLeave", function() GameTooltip:Hide() end)
    h:SetScript("OnClick", function() UI.History.sortKey = col.text; AIO.Handle("HLBG", "Request", "HISTORY", UI.History.page or 1, UI.History.per or 25) end)
    UI.History.Columns[i] = h
    x = x + col.w + 8
end

UI.History.Nav = CreateFrame("Frame", nil, UI.History)
UI.History.Nav:SetPoint("BOTTOMRIGHT", -16, 12)
UI.History.Nav:SetSize(180, 22)
UI.History.Nav.Prev = CreateFrame("Button", nil, UI.History.Nav, "UIPanelButtonTemplate")
UI.History.Nav.Prev:SetPoint("LEFT")
UI.History.Nav.Prev:SetSize(60, 22)
UI.History.Nav.Prev:SetText("Prev")
UI.History.Nav.Next = CreateFrame("Button", nil, UI.History.Nav, "UIPanelButtonTemplate")
UI.History.Nav.Next:SetPoint("LEFT", UI.History.Nav.Prev, "RIGHT", 8, 0)
UI.History.Nav.Next:SetSize(60, 22)
UI.History.Nav.Next:SetText("Next")
UI.History.Nav.PageText = UI.History.Nav:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
UI.History.Nav.PageText:SetPoint("LEFT", UI.History.Nav.Next, "RIGHT", 8, 0)
UI.History.Nav.Prev:SetScript("OnClick", function()
    local p = (UI.History.page or 1); if p>1 then p=p-1 end
    AIO.Handle("HLBG", "Request", "HISTORY", p, UI.History.per or 25)
end)
UI.History.Nav.Next:SetScript("OnClick", function()
    local p = (UI.History.page or 1) + 1
    AIO.Handle("HLBG", "Request", "HISTORY", p, UI.History.per or 25)
end)

for i=1,3 do UI.Tabs[i]:SetScript("OnClick", function() ShowTab(i) end) end

-- Add a tab to PvP Frame
local function EnsurePvPTab()
    local _pvp = _G["PVPParentFrame"] or _G["PVPFrame"]
    if not _pvp or _G["PVPFrameTabHLBG"] then return end
    -- Create a tab-like button anchored to the last existing tab without changing numTabs
    local baseName = _pvp:GetName() or "PVPFrame"
    local lastIdx = _pvp.numTabs or 2
    local lastTab = _G[baseName.."Tab"..lastIdx]
    local tab = CreateFrame("Button", "PVPFrameTabHLBG", _pvp, "CharacterFrameTabButtonTemplate")
    tab:SetText("HLBG")
    tab:SetID((lastIdx or 2) + 1)
    if lastTab then
        tab:SetPoint("LEFT", lastTab, "RIGHT", -15, 0)
    else
        tab:SetPoint("TOPLEFT", _pvp, "BOTTOMLEFT", 10, 7)
    end
    tab:SetScript("OnClick", function()
        if PVPFrameLeft then PVPFrameLeft:Hide() end
        if PVPFrameRight then PVPFrameRight:Hide() end
        UI.Frame:Show()
        ShowTab(HinterlandAffixHUDDB.lastInnerTab or 1)
        if AIO and AIO.Handle then
            AIO.Handle("HLBG", "Request", "HISTORY", 1, 25, UI.History.sortKey or "id", UI.History.sortDir or "DESC")
            AIO.Handle("HLBG", "Request", "STATS")
        end
    end)
end

-- Lightweight fallback: a small header button inside PvP frame to open HLBG
local function EnsurePvPHeaderButton()
    local _pvp = _G["PVPParentFrame"] or _G["PVPFrame"]
    if not _pvp or _G["PVPFrameHLBGButton"] then return end
    local btn = CreateFrame("Button", "PVPFrameHLBGButton", _pvp, "UIPanelButtonTemplate")
    btn:SetSize(56, 20)
    -- place near top-right but leave space for close button if any
    btn:SetPoint("TOPRIGHT", _pvp, "TOPRIGHT", -40, -28)
    btn:SetText("HLBG")
    btn:SetScript("OnClick", function()
        UI.Frame:Show()
        ShowTab(HinterlandAffixHUDDB.lastInnerTab or 1)
        if AIO and AIO.Handle then
            AIO.Handle("HLBG", "Request", "HISTORY", UI.History.page or 1, UI.History.per or 25, UI.History.sortKey or "id", UI.History.sortDir or "DESC")
            AIO.Handle("HLBG", "Request", "STATS")
        end
    end)
    -- hide our inner frame when PvP frame hides
    _pvp:HookScript("OnHide", function()
        if UI.Frame and UI.Frame:GetParent() == _pvp then UI.Frame:Hide() end
    end)
end

-- Create PvP tab lazily when UI exists
local pvpWatcher = CreateFrame("Frame")
pvpWatcher:RegisterEvent("PLAYER_LOGIN")
pvpWatcher:RegisterEvent("ADDON_LOADED")
pvpWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
pvpWatcher:SetScript("OnEvent", function(_, ev, name)
    if ev == "ADDON_LOADED" and name and name ~= "Blizzard_PvPUI" then -- classic WotLK loads FrameXML, still try
        EnsurePvPTab(); EnsurePvPHeaderButton()
    else
        EnsurePvPTab(); EnsurePvPHeaderButton()
    end
end)
-- Also retry a few times after login in case of delayed creation
do
    local tries, t = 0, 0
    UI.Frame:SetScript("OnUpdate", function(self, elapsed)
        t = t + (elapsed or 0)
        if t > 1.0 then
            t = 0; tries = tries + 1; EnsurePvPTab(); EnsurePvPHeaderButton()
            if _G["PVPFrameTabHLBG"] or _G["PVPFrameHLBGButton"] or tries > 5 then UI.Frame:SetScript("OnUpdate", nil) end
        end
    end)
end

-- Handlers from server
function HLBG.OpenUI()
    local pvp = _G["PVPParentFrame"] or _G["PVPFrame"]
    if pvp and pvp:IsShown() then
        if UI.Frame:GetParent() ~= pvp then UI.Frame:SetParent(pvp) end
    else
        if UI.Frame:GetParent() ~= UIParent then UI.Frame:SetParent(UIParent) end
    end
    UI.Frame:Show()
    ShowTab(HinterlandAffixHUDDB.lastInnerTab or 1)
end
DEFAULT_CHAT_FRAME:AddMessage("HLBG client: main OpenUI bound")

function HLBG.History(rows, page, per, total, col, dir)
    -- clear previous
    for i,child in ipairs({UI.History.Content:GetRegions()}) do if child.SetText then child:SetText("") end end
    UI.History.page = page or 1
    UI.History.per = per or 25
    UI.History.total = total or 0
    UI.History.sortKey = col or UI.History.sortKey or "id"
    UI.History.sortDir = dir or UI.History.sortDir or "DESC"
    local y = -22
    rows = rows or {}
    for _, row in ipairs(rows) do
        local fs = UI.History.Content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        local who = (row.winner == "Alliance" or row.winner == "ALLIANCE") and "|cff1e90ffAlliance|r" or (row.winner == "Horde" or row.winner == "HORDE") and "|cffff0000Horde|r" or "|cffffff00Draw|r"
        local aff = row.affix or "-"
        local reason = row.reason or "-"
        fs:SetPoint("TOPLEFT", 0, y)
        fs:SetText(string.format("%4d  %s  %s  %s  %s", tonumber(row.id) or 0, row.ts or "", who, aff, reason))
        y = y - 14
    end
    local maxPage = (UI.History.total and UI.History.total > 0) and math.max(1, math.ceil(UI.History.total/(UI.History.per or 25))) or (UI.History.page or 1)
    UI.History.Nav.PageText:SetText(string.format("Page %d / %d", UI.History.page, maxPage))
    if UI.History.Nav.Prev then UI.History.Nav.Prev:SetEnabled((UI.History.page or 1) > 1) end
    if UI.History.Nav.Next then UI.History.Nav.Next:SetEnabled((UI.History.page or 1) < maxPage) end
end

function HLBG.Stats(stats)
    stats = stats or {}
    local counts = stats.counts or {}
    local a = (counts["Alliance"] or counts["ALLIANCE"] or 0)
    local h = (counts["Horde"] or counts["HORDE"] or 0)
    local d = stats.draws or 0
    local lines = { string.format("Alliance: %d  Horde: %d  Draws: %d  Avg: %d min", a, h, d, math.floor((stats.avgDuration or 0)/60)) }
    -- append top 3 affix and weather splits if present
    local function top3(map)
        local arr = {}
        for k,v in pairs(map or {}) do table.insert(arr, {k=k, v=(v.Alliance or 0)+(v.Horde or 0)+(v.DRAW or 0)}) end
        table.sort(arr, function(x,y) return x.v>y.v end)
        local out = {}
        for i=1,math.min(3,#arr) do table.insert(out, arr[i].k..":"..arr[i].v) end
        return table.concat(out, ", ")
    end
    if stats.byAffix and next(stats.byAffix) then table.insert(lines, "Top Affixes: "..top3(stats.byAffix)) end
    if stats.byWeather and next(stats.byWeather) then table.insert(lines, "Top Weather: "..top3(stats.byWeather)) end
    -- show top 3 average durations per affix and weather
    local function top3avg(map)
        local arr = {}
        for k,v in pairs(map or {}) do table.insert(arr, {k=k, v=tonumber(v.avg or 0)}) end
        table.sort(arr, function(x,y) return x.v>y.v end)
        local out = {}
        for i=1,math.min(3,#arr) do table.insert(out, string.format("%s:%d min", arr[i].k, math.floor((arr[i].v or 0)/60))) end
        return table.concat(out, ", ")
    end
    if stats.affixDur and next(stats.affixDur) then table.insert(lines, "Slowest Affixes (avg): "..top3avg(stats.affixDur)) end
    if stats.weatherDur and next(stats.weatherDur) then table.insert(lines, "Slowest Weather (avg): "..top3avg(stats.weatherDur)) end
    UI.Stats.Text:SetText(table.concat(lines, "\n"))
end

-- Support addon-channel STATUS & AFFIX messages to drive HUD
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    local prefix, msg = ...
    if prefix == "HLBG" and type(msg) == "string" then
        local a = msg:match("STATUS|A=(%d+)")
        if a then
            RES.A = tonumber(a) or RES.A
            local h = msg:match("|H=(%d+)")
            local endt = msg:match("|END=(%d+)")
            local lock = msg:match("|LOCK=(%d+)")
            if h then RES.H = tonumber(h) or RES.H end
            if endt then RES.END = tonumber(endt) or RES.END end
            if lock then RES.LOCK = tonumber(lock) or RES.LOCK end
            UpdateHUD()
            UI.HUD:Show()
            return
        end
        local aff = msg:match("AFFIX|([^|]+)")
        if aff then
            if InHinterlands() then
                UI.Affix.Text:SetText("Affix: " .. aff)
                UI.Affix:Show()
            else
                UI.Affix:Hide()
            end
            return
        end
    end
end)

-- Add a simple Refresh button on the History and Stats panes
UI.Refresh = CreateFrame("Button", nil, UI.Frame, "UIPanelButtonTemplate")
UI.Refresh:SetSize(80, 22)
UI.Refresh:SetPoint("TOPRIGHT", UI.Frame, "TOPRIGHT", -18, -10)
UI.Refresh:SetText("Refresh")
UI.Refresh:SetScript("OnClick", function()
    if AIO and AIO.Handle then
        AIO.Handle("HLBG", "Request", "HISTORY", UI.History.page or 1, UI.History.per or 25, UI.History.sortKey or "id", UI.History.sortDir or "DESC")
        AIO.Handle("HLBG", "Request", "STATS")
    end
end)

-- Make column headers actually sort (toggle ASC/DESC)
for i,h in ipairs(UI.History.Columns) do
    h:SetScript("OnClick", function()
        local keyMap = { ID = "id", Timestamp = "ts", Winner = "winner", Affix = "affix", Reason = "reason" }
        local sk = keyMap[h.Text:GetText()] or "id"
        if UI.History.sortKey == sk then
            UI.History.sortDir = (UI.History.sortDir == "ASC") and "DESC" or "ASC"
        else
            UI.History.sortKey = sk; UI.History.sortDir = "DESC"
        end
        if AIO and AIO.Handle then
            AIO.Handle("HLBG", "Request", "HISTORY", UI.History.page or 1, UI.History.per or 25, UI.History.sortKey, UI.History.sortDir)
        end
    end)
end

-- Options in Interface panel to control addon HUD usage
local opt = CreateFrame("Frame", "HLBG_AIO_Options", InterfaceOptionsFramePanelContainer)
opt.name = "HLBG HUD"
opt:Hide()
opt:SetScript("OnShow", function(self)
  if self.init then return end; self.init = true
  local title = self:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge"); title:SetPoint("TOPLEFT", 16, -16); title:SetText("HLBG HUD")
  local cb = CreateFrame("CheckButton", nil, self, "InterfaceOptionsCheckButtonTemplate")
  cb:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    -- 3.3.5: InterfaceOptionsCheckButtonTemplate may not expose .Text reliably; create our own label
    local cbLabel = self:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    cbLabel:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    cbLabel:SetText("Use addon HUD instead of Blizzard WG HUD")
    cb._label = cbLabel
  cb:SetChecked(HinterlandAffixHUDDB.useAddonHud)
    cb:SetScript("OnClick", function(s)
        HinterlandAffixHUDDB.useAddonHud = s:GetChecked() and true or false
        UpdateHUD()
    end)
    local scale = CreateFrame("Slider", nil, self, "OptionsSliderTemplate"); scale:SetPoint("TOPLEFT", cb, "BOTTOMLEFT", 0, -24)
    scale:SetMinMaxValues(0.8, 1.6); if scale.SetValueStep then scale:SetValueStep(0.05) end
    if scale.SetObeyStepOnDrag then scale:SetObeyStepOnDrag(true) end
    if scale.Low then scale.Low:SetText("0.8") end
    if scale.High then scale.High:SetText("1.6") end
    if scale.Text then scale.Text:SetText("HUD Scale") end
  scale:SetValue(HinterlandAffixHUDDB.scaleHud or 1.0)
  scale:SetScript("OnValueChanged", function(s,val) HinterlandAffixHUDDB.scaleHud = tonumber(string.format("%.2f", val)); UI.HUD:SetScale(HinterlandAffixHUDDB.scaleHud) end)
end)
InterfaceOptions_AddCategory(opt)

-- Slash to open HLBG window even if server AIO command isn't available
SLASH_HLBG1 = "/hlbg"
SlashCmdList["HLBG"] = function(msg)
    EnsurePvPTab(); EnsurePvPHeaderButton()
    HLBG.OpenUI()
    if AIO and AIO.Handle then
        AIO.Handle("HLBG", "Request", "HISTORY", UI.History.page or 1, UI.History.per or 25, UI.History.sortKey or "id", UI.History.sortDir or "DESC")
        AIO.Handle("HLBG", "Request", "STATS")
    end
end

-- Round-trip ping test
function HLBG.PONG()
    DEFAULT_CHAT_FRAME:AddMessage("HLBG: PONG from server")
end
SLASH_HLBGPING1 = "/hlbgping"
SlashCmdList["HLBGPING"] = function()
    if AIO and AIO.Handle then AIO.Handle("HLBG", "Request", "PING") else DEFAULT_CHAT_FRAME:AddMessage("HLBG: AIO client not available") end
end
SLASH_HLBGUI1 = "/hlbgui"
SlashCmdList["HLBGUI"] = SlashCmdList["HLBG"]
