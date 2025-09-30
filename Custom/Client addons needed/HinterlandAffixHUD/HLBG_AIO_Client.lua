local HLBG = _G.HLBG or {}
_G.HLBG = HLBG
-- Note: AIO handlers are registered after all functions are defined (see bottom)

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
            if _G.AIO and _G.AIO.Handle then
                _G.AIO.Handle("HLBG", "Request", "HISTORY", 1, 25, "id", "DESC")
                _G.AIO.Handle("HLBG", "Request", "STATS")
            end
        end)
        if not ok then DEFAULT_CHAT_FRAME:AddMessage("HLBG error (/hlbg): "..tostring(err)) end
    end
    SLASH_HLBGPING1 = "/hlbgping"
    SlashCmdList["HLBGPING"] = function()
        if _G.AIO and _G.AIO.Handle then _G.AIO.Handle("HLBG", "Request", "PING") else DEFAULT_CHAT_FRAME:AddMessage("HLBG: AIO client not available") end
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

-- Affix code -> friendly name mapping (edit as needed to your server's rotation)
local AFFIX_NAMES = _G.HLBG_AFFIX_NAMES or {
    -- ["1"] = "Bloodlust",
    -- ["2"] = "Storms",
    -- ["3"] = "Frenzy",
    -- ["4"] = "Plague",
    -- ["5"] = "Blight",
}
_G.HLBG_AFFIX_NAMES = AFFIX_NAMES
local function GetAffixName(code)
    if code == nil then return "-" end
    local s = tostring(code)
    local name = AFFIX_NAMES[s]
    return name or s -- fall back to the code when unknown
end
-- optionally expose for other addons, but keep mapping local (AddHandlers requires only functions)
HLBG.GetAffixName = GetAffixName

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
-- Ensure our panel stays above world overlays on 3.3.5
if UI.Frame.SetFrameStrata then UI.Frame:SetFrameStrata("DIALOG") end
UI.Frame:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left=4, right=4, top=4, bottom=4 } })
UI.Frame:SetBackdropColor(0,0,0,0.5)
UI.Frame:ClearAllPoints()
UI.Frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
UI.Frame:EnableMouse(true)
UI.Frame:SetMovable(true)
UI.Frame:RegisterForDrag("LeftButton")
UI.Frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
UI.Frame:SetScript("OnDragStop", function(self)
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
        UI.Frame:ClearAllPoints()
        UI.Frame:SetPoint(pos.point, _G[pos.rel], pos.relPoint, pos.x or 0, pos.y or 0)
    end
end
-- Close button instead of hooking UIParent OnKeyDown (not reliable on 3.3.5)
local close = CreateFrame("Button", nil, UI.Frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", UI.Frame, "TOPRIGHT", 0, 0)
-- Allow closing with ESC
if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, UI.Frame:GetName()) end

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
-- Width roughly equals visible scroll area (512 frame - 16 left - 36 right = 460)
UI.History.Content:SetSize(460, 300)
UI.History.Scroll:SetScrollChild(UI.History.Content)
UI.History.rows = UI.History.rows or {}
-- Empty-state label
UI.History.EmptyText = UI.History:CreateFontString(nil, "OVERLAY", "GameFontDisable")
UI.History.EmptyText:SetPoint("TOPLEFT", 16, -64)
UI.History.EmptyText:SetText("No data yet…")
UI.History.EmptyText:Hide()

UI.Stats = CreateFrame("Frame", nil, UI.Frame)
UI.Stats:SetAllPoints(UI.Frame)
UI.Stats:Hide()
UI.Stats.Text = UI.Stats:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
UI.Stats.Text:SetPoint("TOPLEFT", 16, -40)
UI.Stats.Text:SetText("Stats will appear here.")

-- History controls: columns, pagination
UI.History.Columns = {}
-- Keep total <= ~460 width (including spacing)
local headers = {
    {text="ID", w=50},
    {text="Timestamp", w=156},
    {text="Winner", w=80},
    {text="Affix", w=90},
    {text="Reason", w=60},
}
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
    h:SetScript("OnClick", function() UI.History.sortKey = col.text; if _G.AIO and _G.AIO.Handle then _G.AIO.Handle("HLBG", "Request", "HISTORY", UI.History.page or 1, UI.History.per or 25) end end)
    UI.History.Columns[i] = h
    x = x + col.w + 6
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
    if _G.AIO and _G.AIO.Handle then _G.AIO.Handle("HLBG", "Request", "HISTORY", p, UI.History.per or 5, UI.History.sortKey or "id", UI.History.sortDir or "DESC") end
end)
UI.History.Nav.Next:SetScript("OnClick", function()
    local p = (UI.History.page or 1) + 1
    if _G.AIO and _G.AIO.Handle then _G.AIO.Handle("HLBG", "Request", "HISTORY", p, UI.History.per or 5, UI.History.sortKey or "id", UI.History.sortDir or "DESC") end
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
        if _G.AIO and _G.AIO.Handle then
            _G.AIO.Handle("HLBG", "Request", "HISTORY", 1, UI.History.per or 5, UI.History.sortKey or "id", UI.History.sortDir or "DESC")
            _G.AIO.Handle("HLBG", "Request", "STATS")
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
        if _G.AIO and _G.AIO.Handle then
            _G.AIO.Handle("HLBG", "Request", "HISTORY", UI.History.page or 1, UI.History.per or 5, UI.History.sortKey or "id", UI.History.sortDir or "DESC")
            _G.AIO.Handle("HLBG", "Request", "STATS")
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

function HLBG.History(a, b, c, d, e, f, g)
    -- Accept both signatures:
    -- 1) History(rows, page, per, total, col, dir)
    -- 2) History(player, rows, page, per, total, col, dir)
    local rows, page, per, total, col, dir
    if type(a) == "table" then
        rows, page, per, total, col, dir = a, b, c, d, e, f
    else
        rows, page, per, total, col, dir = b, c, d, e, f, g
    end
    -- debug trace
    if DEFAULT_CHAT_FRAME and type(DEFAULT_CHAT_FRAME.AddMessage) == "function" then
        local t = type(rows)
        local n = (t == "table" and #rows) or 0
        DEFAULT_CHAT_FRAME:AddMessage(string.format("HLBG: History handler invoked (rowsType=%s, n=%d)", t, n))
    end
    if type(rows) ~= "table" then rows = {} end
    UI.History.page = page or UI.History.page or 1
    UI.History.per = per or UI.History.per or 25
    UI.History.total = total or UI.History.total or 0
    UI.History.sortKey = col or UI.History.sortKey or "id"
    UI.History.sortDir = dir or UI.History.sortDir or "DESC"

    -- Render with a simple row widget pool
    local function getRow(i)
        local r = UI.History.rows[i]
        if not r then
            r = CreateFrame("Frame", nil, UI.History.Content)
            r:SetSize(420, 14)
            r.id = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.ts = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.win = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.aff = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.rea = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            -- layout mirrors headers: ID(50), TS(156), WIN(80), AFF(90), REASON(60) with 6px spacing
            r.id:SetPoint("LEFT", r, "LEFT", 0, 0)
            r.id:SetWidth(50); r.id:SetJustifyH("LEFT")
            r.ts:SetPoint("LEFT", r.id, "RIGHT", 6, 0)
            r.ts:SetWidth(156); r.ts:SetJustifyH("LEFT")
            r.win:SetPoint("LEFT", r.ts, "RIGHT", 6, 0)
            r.win:SetWidth(80); r.win:SetJustifyH("LEFT")
            r.aff:SetPoint("LEFT", r.win, "RIGHT", 6, 0)
            r.aff:SetWidth(90); r.aff:SetJustifyH("LEFT")
            r.rea:SetPoint("LEFT", r.aff, "RIGHT", 6, 0)
            r.rea:SetWidth(60); r.rea:SetJustifyH("LEFT")
            UI.History.rows[i] = r
        end
        return r
    end

    -- hide all previously visible rows
    for i=1,#UI.History.rows do UI.History.rows[i]:Hide() end

    local y = -22
    local hadRows = false
    for i, row in ipairs(rows) do
        local r = getRow(i)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", UI.History.Content, "TOPLEFT", 0, y)
        -- Support both compact array rows {id, ts, winner, affix, reason} and map rows
        local id    = (type(row[1]) ~= "nil") and row[1] or row.id
        local ts    = row[2] or row.ts
        local win   = row[3] or row.winner
        local affix = row[4] or row.affix
        local reas  = row[5] or row.reason
        local who = (win == "Alliance" or win == "ALLIANCE") and "|cff1e90ffAlliance|r" or (win == "Horde" or win == "HORDE") and "|cffff0000Horde|r" or "|cffffff00Draw|r"
        r.id:SetText(tostring(tonumber(id) or 0))
        r.ts:SetText(ts or "")
        r.win:SetText(who)
        r.aff:SetText(GetAffixName(affix))
        r.rea:SetText(reas or "-")
        r:Show()
        y = y - 14
        hadRows = true
    end

    local maxPage = (UI.History.total and UI.History.total > 0) and math.max(1, math.ceil(UI.History.total/(UI.History.per or 25))) or (UI.History.page or 1)
    UI.History.Nav.PageText:SetText(string.format("Page %d / %d", UI.History.page, maxPage))
    local hasPrev = (UI.History.page or 1) > 1
    local hasNext = (UI.History.page or 1) < maxPage
    if UI.History.Nav.Prev then if hasPrev then UI.History.Nav.Prev:Enable() else UI.History.Nav.Prev:Disable() end end
    if UI.History.Nav.Next then if hasNext then UI.History.Nav.Next:Enable() else UI.History.Nav.Next:Disable() end end

    -- Resize scroll child to the content and reset scroll to top
    local visibleCount = (type(rows) == "table" and #rows) or 0
    local base = 22 -- header area height used above
    local rowH = 14
    local minH = 300
    local newH = math.max(minH, base + visibleCount * rowH + 8)
    UI.History.Content:SetHeight(newH)
    if UI.History.Scroll and UI.History.Scroll.SetVerticalScroll then UI.History.Scroll:SetVerticalScroll(0) end
    if UI.History.EmptyText then
        if hadRows then UI.History.EmptyText:Hide() else UI.History.EmptyText:Show() end
    end

    -- optional debug
    DEFAULT_CHAT_FRAME:AddMessage(string.format("HLBG: History received rows=%d total=%s", visibleCount, tostring(UI.History.total)))
end

function HLBG.Stats(player, stats)
    if type(player) ~= "string" and type(player) ~= "userdata" then
        stats = player
    end
    DEFAULT_CHAT_FRAME:AddMessage(string.format("HLBG: Stats(raw) type=%s", type(stats)))
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

-- Provide uppercase aliases in case the dispatcher normalizes names
HLBG.HISTORY = function(...) return HLBG.History(...) end
HLBG.STATS = function(...) return HLBG.Stats(...) end
function HLBG.DBG(msg)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("HLBG DBG: "..tostring(msg)) end
end

-- Fallback: parse History from TSV string payload
function HLBG.HistoryStr(a, b, c, d, e, f, g)
    local tsv, page, per, total, col, dir
    if type(a) == "string" then
        tsv, page, per, total, col, dir = a, b, c, d, e, f
    else
        tsv, page, per, total, col, dir = b, c, d, e, f, g
    end
    local rows = {}
    if type(tsv) == "string" and tsv ~= "" then
        for line in tsv:gmatch("[^\n]+") do
            local id, ts, win, aff, rea = string.match(line, "^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)$")
            table.insert(rows, { id or "", ts or "", win or "", aff or "", rea or "" })
        end
    end
    return HLBG.History(rows, page, per, total, col, dir)
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
                UI.Affix.Text:SetText("Affix: " .. GetAffixName(aff))
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
    if _G.AIO and _G.AIO.Handle then
    _G.AIO.Handle("HLBG", "Request", "HISTORY", UI.History.page or 1, UI.History.per or 5, UI.History.sortKey or "id", UI.History.sortDir or "DESC")
        _G.AIO.Handle("HLBG", "Request", "STATS")
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
        if _G.AIO and _G.AIO.Handle then
            _G.AIO.Handle("HLBG", "Request", "HISTORY", UI.History.page or 1, UI.History.per or 5, UI.History.sortKey, UI.History.sortDir)
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
    if _G.AIO and _G.AIO.Handle then
        _G.AIO.Handle("HLBG", "Request", "HISTORY", UI.History.page or 1, UI.History.per or 5, UI.History.sortKey or "id", UI.History.sortDir or "DESC")
        _G.AIO.Handle("HLBG", "Request", "STATS")
    end
end

-- Round-trip ping test
function HLBG.PONG()
    DEFAULT_CHAT_FRAME:AddMessage("HLBG: PONG from server")
end
SLASH_HLBGPING1 = "/hlbgping"
SlashCmdList["HLBGPING"] = function()
    if _G.AIO and _G.AIO.Handle then _G.AIO.Handle("HLBG", "Request", "PING") else DEFAULT_CHAT_FRAME:AddMessage("HLBG: AIO client not available") end
end
SLASH_HLBGUI1 = "/hlbgui"
SlashCmdList["HLBGUI"] = SlashCmdList["HLBG"]

-- Register handlers once all functions exist; bind when AIO loads (or immediately if already loaded)
do
    local function register()
        if not (_G.AIO and _G.AIO.AddHandlers) then return false end
        -- Request a fresh table and then assign handlers for maximum compatibility
        local reg = _G.AIO.AddHandlers("HLBG", {})
    reg.OpenUI     = HLBG.OpenUI
    reg.History    = HLBG.History
    reg.Stats      = HLBG.Stats
    reg.PONG       = HLBG.PONG
    reg.DBG        = HLBG.DBG
    reg.HistoryStr = HLBG.HistoryStr
    reg.HISTORY    = reg.History
    reg.STATS      = reg.Stats
        _G.HLBG = reg; HLBG = reg
        DEFAULT_CHAT_FRAME:AddMessage("HLBG: Handlers registered (History/Stats)")
        DEFAULT_CHAT_FRAME:AddMessage("HLBG: AIO.AddHandlers returned new table")
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "HLBG: Registered handlers -> History=%s, Stats=%s, PONG=%s, OpenUI=%s",
            tostring(type(HLBG.History)), tostring(type(HLBG.Stats)), tostring(type(HLBG.PONG)), tostring(type(HLBG.OpenUI))
        ))
        -- Prime first page
        if _G.AIO and _G.AIO.Handle then
            _G.AIO.Handle("HLBG", "Request", "HISTORY", 1, HLBG and HLBG.History and (UI and UI.History and UI.History.per or 5) or 5, "id", "DESC")
            _G.AIO.Handle("HLBG", "Request", "STATS")
        end
        return true
    end
    if not register() then
        local fr = CreateFrame("Frame")
        fr:RegisterEvent("ADDON_LOADED")
        fr:SetScript("OnEvent", function(_, _, name)
            if name == "AIO_Client" or name == "AIO" or name == "RochetAio" then
                register()
                -- keep the handler in case AIO defers parts; but also stop spamming after success
                fr:UnregisterAllEvents(); fr:SetScript("OnEvent", nil)
            end
        end)
    end
end

-- Debug: local fake data to validate rendering path without server
SLASH_HLBGFAKE1 = "/hlbgfake"
SlashCmdList["HLBGFAKE"] = function()
    local fakeRows = {
        { id = "101", ts = date("%Y-%m-%d %H:%M:%S"), winner = "Alliance", affix = "3", reason = "Score", duration = 1200 },
        { id = "100", ts = date("%Y-%m-%d %H:%M:%S"), winner = "Horde", affix = "5", reason = "Timer", duration = 900 },
    }
    HLBG.History(fakeRows, 1, 3, 11, "id", "DESC")
    UI.Frame:Show(); ShowTab(2)
end
