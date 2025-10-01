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
                if HLBG.UI and HLBG.UI.Frame then HLBG.UI.Frame:Show() end
                if type(ShowTab) == "function" then pcall(ShowTab, HinterlandAffixHUDDB.lastInnerTab or 1) end
            end
        end
    -- Minimal PONG handler so /hlbgping can verify round-trip
    if type(HLBG.PONG) ~= "function" then
        HLBG.PONG = function() DEFAULT_CHAT_FRAME:AddMessage("HLBG: PONG from server") end
    end
        if type(HLBG.History) ~= "function" then
            HLBG.History = function(rows, page, per, total)
                DEFAULT_CHAT_FRAME:AddMessage(string.format("HLBG: HISTORY rows=%s page=%s total=%s", tostring(rows and #rows or 0), tostring(page or "?"), tostring(total or "?")))
            end
        end
        if type(HLBG.Stats) ~= "function" then
            HLBG.Stats = function(stats)
                local counts = (stats and stats.counts) or {}
                DEFAULT_CHAT_FRAME:AddMessage(string.format("HLBG: STATS A=%s H=%s D=%s", tostring(counts.Alliance or 0), tostring(counts.Horde or 0), tostring((stats and stats.draws) or 0)))
            end
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
                -- Chat fallbacks so UI works without AIO server handlers
                SendChatCommand(".hlbg live players")
                SendChatCommand(".hlbg historyui 1 5 id DESC")
                SendChatCommand(".hlbg statsui")
        end)
        if not ok then DEFAULT_CHAT_FRAME:AddMessage("HLBG error (/hlbg): "..tostring(err)) end
    end
    SLASH_HLBGPING1 = "/hlbgping"
    SlashCmdList["HLBGPING"] = function()
        if _G.AIO and _G.AIO.Handle then _G.AIO.Handle("HLBG", "Request", "PING") else DEFAULT_CHAT_FRAME:AddMessage("HLBG: AIO client not available") end
    end
end
-- (moved startup message to early bootstrap above)

-- Quick early AIO registration: attempt to bind handlers immediately to avoid "Unknown AIO block handle: 'HLBG'" errors
do
    local function quickRegister()
        if not (_G.AIO and _G.AIO.AddHandlers) then return false end
        local ok, reg = pcall(function() return _G.AIO.AddHandlers("HLBG", {}) end)
        if not ok or type(reg) ~= "table" then return false end
        reg.OpenUI     = HLBG.OpenUI
        reg.History    = HLBG.History
        reg.Stats      = HLBG.Stats
        reg.Live       = HLBG.Live
        reg.LIVE       = reg.Live
        reg.Warmup     = HLBG.Warmup
        reg.QueueStatus= HLBG.QueueStatus
        reg.Results    = HLBG.Results
        reg.PONG       = HLBG.PONG
        reg.DBG        = HLBG.DBG
        reg.HistoryStr = HLBG.HistoryStr
        reg.HISTORY    = reg.History
        reg.STATS      = reg.Stats
        _G.HLBG = reg; HLBG = reg
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage("HLBG: quick handlers registered") end
        return true
    end
    pcall(quickRegister)
end

-- Create HUD frame (small, draggable) used to display resources on the world view
-- Ensure saved-table and UI root exist before indexing them (avoid attempt to index global 'UI' nil)
HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
HinterlandAffixHUDDB.anchorHud = HinterlandAffixHUDDB.anchorHud or {}
-- Namespace UI under HLBG to avoid global pollution
HLBG.UI = HLBG.UI or {}
-- DO NOT create a local UI alias; use HLBG.UI everywhere to avoid globals
HLBG.UI.HUD = HLBG.UI.HUD or CreateFrame("Frame", "HLBG_HUD", UIParent)
HLBG.UI.HUD:SetSize(200, 72)
HLBG.UI.HUD:SetPoint(HinterlandAffixHUDDB.anchorHud.point or "TOPRIGHT", HinterlandAffixHUDDB.anchorHud.rel and _G[HinterlandAffixHUDDB.anchorHud.rel] or UIParent, HinterlandAffixHUDDB.anchorHud.relPoint or "TOPRIGHT", HinterlandAffixHUDDB.anchorHud.x or -30, HinterlandAffixHUDDB.anchorHud.y or -150)
HLBG.UI.HUD:EnableMouse(true)
HLBG.UI.HUD:SetMovable(true)
HLBG.UI.HUD:RegisterForDrag("LeftButton")
HLBG.UI.HUD:SetScript("OnDragStart", function(self) if not HinterlandAffixHUDDB.lockHud then self:StartMoving() end end)
HLBG.UI.HUD:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); local p, rel, rp, x, y = self:GetPoint(); HinterlandAffixHUDDB.anchorHud = { point = p, rel = rel and rel:GetName() or "UIParent", relPoint = rp, x = x, y = y } end)
HLBG.UI.HUD:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left=4, right=4, top=4, bottom=4 } })
HLBG.UI.HUD:SetBackdropColor(0, 0, 0, 0.5)
HLBG.UI.HUD:Hide()

-- Ensure RES table exists for HUD/status updates (guard against nil when CHAT_MSG_ADDON arrives early)
RES = RES or {}
RES.A = RES.A or 0
RES.H = RES.H or 0
RES.END = RES.END or 0
RES.LOCK = RES.LOCK or 0

-- Compatibility: SecondsToClock isn't present on some older client environments; provide a simple fallback
if type(SecondsToClock) ~= "function" then
    function SecondsToClock(seconds)
        seconds = tonumber(seconds) or 0
        if seconds <= 0 then return "0:00" end
        local m = math.floor(seconds / 60)
        local s = seconds % 60
        return string.format("%d:%02d", m, s)
    end
end

-- Minimal JSON decoder (handles objects, arrays, strings, numbers, booleans, null)
-- Lightweight and tolerant - sufficient for the server's simple encoder output
local function json_decode(s)
    if type(s) ~= "string" then return nil, "not a string" end
    local i = 1
    local n = #s
    local function peek() return s:sub(i,i) end
    local function nextch() i = i + 1; return s:sub(i-1,i-1) end
    local function skipws()
        while i <= n and s:sub(i,i):match("%s") do i = i + 1 end
    end

    local function parseValue()
        skipws()
        local c = peek()
        if c == '{' then return parseObject()
        elseif c == '[' then return parseArray()
        elseif c == '"' then return parseString()
        elseif c == '-' or c:match('%d') then return parseNumber()
        elseif s:sub(i,i+3) == 'true' then i = i + 4; return true
        elseif s:sub(i,i+4) == 'false' then i = i + 5; return false
        elseif s:sub(i,i+3) == 'null' then i = i + 4; return nil
        else error("Invalid JSON value at position "..i)
        end
    end

    function parseString()
        local out = {}
        assert(nextch() == '"')
        while i <= n do
            local ch = nextch()
            if ch == '"' then break end
            if ch == '\\' then
                local esc = nextch()
                if esc == '"' then table.insert(out, '"')
                elseif esc == '\\' then table.insert(out, '\\')
                elseif esc == '/' then table.insert(out, '/')
                elseif esc == 'b' then table.insert(out, '\b')
                elseif esc == 'f' then table.insert(out, '\f')
                elseif esc == 'n' then table.insert(out, '\n')
                elseif esc == 'r' then table.insert(out, '\r')
                elseif esc == 't' then table.insert(out, '\t')
                elseif esc == 'u' then
                    -- basic \uXXXX handling: convert to a Unicode codepoint (hex) and encode as UTF-8
                    local hex = s:sub(i, i+3)
                    if not hex or #hex < 4 then error('Invalid unicode escape') end
                    i = i + 4
                    local code = tonumber(hex, 16) or 63
                    if code <= 0x7f then table.insert(out, string.char(code))
                    elseif code <= 0x7ff then
                        table.insert(out, string.char(0xc0 + math.floor(code/0x40)))
                        table.insert(out, string.char(0x80 + (code % 0x40)))
                    else
                        table.insert(out, string.char(0xe0 + math.floor(code/0x1000)))
                        table.insert(out, string.char(0x80 + (math.floor(code/0x40) % 0x40)))
                        table.insert(out, string.char(0x80 + (code % 0x40)))
                    end
                else
                    -- unknown escape, insert literally
                    table.insert(out, esc)
                end
            else
                table.insert(out, ch)
            end
        end
        return table.concat(out)
    end

    function parseNumber()
        local start = i
        if peek() == '-' then i = i + 1 end
        while i <= n and s:sub(i,i):match('%d') do i = i + 1 end
        if s:sub(i,i) == '.' then i = i + 1; while i <= n and s:sub(i,i):match('%d') do i = i + 1 end end
        if s:sub(i,i):lower() == 'e' then i = i + 1; if s:sub(i,i) == '+' or s:sub(i,i) == '-' then i = i + 1 end; while i <= n and s:sub(i,i):match('%d') do i = i + 1 end end
        local num = tonumber(s:sub(start, i-1))
        return num
    end

    function parseArray()
        assert(nextch() == '[')
        local res = {}
        skipws()
        if peek() == ']' then nextch(); return res end
        while true do
            local v = parseValue()
            table.insert(res, v)
            skipws()
            local ch = nextch()
            if ch == ']' then break end
            if ch ~= ',' then error('Expected , or ] in array at '..i) end
        end
        return res
    end

    function parseObject()
        assert(nextch() == '{')
        local res = {}
        skipws()
        if peek() == '}' then nextch(); return res end
        while true do
            skipws()
            local key = parseString()
            skipws()
            assert(nextch() == ':')
            local val = parseValue()
            res[key] = val
            skipws()
            local ch = nextch()
            if ch == '}' then break end
            if ch ~= ',' then error('Expected , or } in object at '..i) end
        end
        return res
    end

    skipws()
    local ok, res = pcall(function() return parseValue() end)
    if not ok then return nil, res end
    return res
end

    -- Safe wrapper for GetAffixName: some client builds/frames may not provide this function
    -- Use HLBG.GetAffixName everywhere so we can guard and fallback to the raw affix string
    local function SafeGetAffixName(aff)
        if not aff then return "" end
        if type(GetAffixName) == 'function' then
            local ok, name = pcall(GetAffixName, aff)
            if ok and name then return tostring(name) end
        end
        -- Fallback: if aff is a numeric id or string, return a reasonable representation
        return tostring(aff)
    end
    HLBG.GetAffixName = SafeGetAffixName

-- Create fontstrings on the namespaced HUD
HLBG.UI.HUD.A = HLBG.UI.HUD:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
HLBG.UI.HUD.A:SetPoint("TOPRIGHT", -4, -4)
HLBG.UI.HUD.H = HLBG.UI.HUD:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
HLBG.UI.HUD.H:SetPoint("TOPRIGHT", HLBG.UI.HUD.A, "BOTTOMRIGHT", 0, -6)
HLBG.UI.HUD.Timer = HLBG.UI.HUD:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
HLBG.UI.HUD.Timer:SetPoint("TOPRIGHT", HLBG.UI.HUD.H, "BOTTOMRIGHT", 0, -6)

HLBG.UI.Affix = CreateFrame("Frame", "HLBG_AffixHeadline", UIParent)
HLBG.UI.Affix:SetSize(320, 30)
HLBG.UI.Affix:SetPoint("TOPLEFT", 30, -150)
HLBG.UI.Affix:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left=4, right=4, top=4, bottom=4 } })
HLBG.UI.Affix:SetBackdropColor(0, 0, 0, 0.4)
HLBG.UI.Affix.Text = HLBG.UI.Affix:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge"); HLBG.UI.Affix.Text:SetShadowOffset(1, -1)
HLBG.UI.Affix.Text:SetPoint("CENTER")
HLBG.UI.Affix:Hide()

HLBG.UI.HUD:SetScript("OnUpdate", function(self, dt)
    if RES.END and RES.END > 0 then
        local now = time()
        local left = RES.END - now
        if left < 0 then left = 0 end
        HLBG.UI.HUD.Timer:SetText("Time Remaining: " .. SecondsToClock(left))
    end
end)

local function UpdateHUD()
    if not HinterlandAffixHUDDB.useAddonHud then
        HLBG.UI.HUD:Hide(); local w = _G["WorldStateAlwaysUpFrame"]; if w then w:Show() end; return
    end
    HLBG.UI.HUD.A:SetText("|TInterface/TargetingFrame/UI-PVP-ALLIANCE:16|t Resources: " .. tostring(RES.A or 0) .. "/450")
    HLBG.UI.HUD.H:SetText("|TInterface/TargetingFrame/UI-PVP-HORDE:16|t Resources: " .. tostring(RES.H or 0) .. "/450")
    local w = _G["WorldStateAlwaysUpFrame"]; if w then w:Hide() end
    HLBG.UI.HUD:Show()
    -- ensure live header and update totals
    ensureLiveHeader()
    UpdateLiveHeader()
end

-- Lightweight helper to send a chat command (dot command) to the server
-- Useful as a fallback when no AIO server handler exists
local function SendChatCommand(cmd)
    if type(cmd) ~= 'string' or cmd == '' then return end
    -- Using SAY is sufficient to trigger server-side command parsing for .commands
    if type(SendChatMessage) == 'function' then
        pcall(SendChatMessage, cmd, 'SAY')
    end
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
        HLBG.UI.HUD:Hide(); HLBG.UI.Affix:Hide(); UnhideBlizzHUDDeep()
    end
end)

-- Main window inside PvP frame
HLBG.UI.Frame = CreateFrame("Frame", "HLBG_Main", PVPParentFrame or PVPFrame)
HLBG.UI.Frame:SetSize(512, 350)
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

-- Tabs inside window: Live / History / Stats
HLBG.UI.Tabs = {}
HLBG.UI.Tabs[1] = CreateFrame("Button", HLBG.UI.Frame:GetName().."Tab1", HLBG.UI.Frame, "OptionsFrameTabButtonTemplate")
HLBG.UI.Tabs[1]:SetPoint("TOPLEFT", HLBG.UI.Frame, "BOTTOMLEFT", 10, 7)
HLBG.UI.Tabs[1]:SetText("Live")
HLBG.UI.Tabs[2] = CreateFrame("Button", HLBG.UI.Frame:GetName().."Tab2", HLBG.UI.Frame, "OptionsFrameTabButtonTemplate")
HLBG.UI.Tabs[2]:SetPoint("LEFT", HLBG.UI.Tabs[1], "RIGHT")
HLBG.UI.Tabs[2]:SetText("History")
HLBG.UI.Tabs[3] = CreateFrame("Button", HLBG.UI.Frame:GetName().."Tab3", HLBG.UI.Frame, "OptionsFrameTabButtonTemplate")
HLBG.UI.Tabs[3]:SetPoint("LEFT", HLBG.UI.Tabs[2], "RIGHT")
HLBG.UI.Tabs[3]:SetText("Stats")

-- New tabs: Queue (join next run), Info (overview), Results (post-match)
HLBG.UI.Tabs[4] = CreateFrame("Button", HLBG.UI.Frame:GetName().."Tab4", HLBG.UI.Frame, "OptionsFrameTabButtonTemplate")
HLBG.UI.Tabs[4]:SetPoint("LEFT", HLBG.UI.Tabs[3], "RIGHT")
HLBG.UI.Tabs[4]:SetText("Queue")
HLBG.UI.Tabs[5] = CreateFrame("Button", HLBG.UI.Frame:GetName().."Tab5", HLBG.UI.Frame, "OptionsFrameTabButtonTemplate")
HLBG.UI.Tabs[5]:SetPoint("LEFT", HLBG.UI.Tabs[4], "RIGHT")
HLBG.UI.Tabs[5]:SetText("Info")
HLBG.UI.Tabs[6] = CreateFrame("Button", HLBG.UI.Frame:GetName().."Tab6", HLBG.UI.Frame, "OptionsFrameTabButtonTemplate")
HLBG.UI.Tabs[6]:SetPoint("LEFT", HLBG.UI.Tabs[5], "RIGHT")
HLBG.UI.Tabs[6]:SetText("Results")

PanelTemplates_SetNumTabs(HLBG.UI.Frame, 6)
PanelTemplates_SetTab(HLBG.UI.Frame, 1)

local function ShowTab(i)
    PanelTemplates_SetTab(HLBG.UI.Frame, i)
    if HLBG.UI.Live then if i == 1 then HLBG.UI.Live:Show() else HLBG.UI.Live:Hide() end end
    if HLBG.UI.History then if i == 2 then HLBG.UI.History:Show() else HLBG.UI.History:Hide() end end
    if HLBG.UI.Stats then if i == 3 then HLBG.UI.Stats:Show() else HLBG.UI.Stats:Hide() end end
    if HLBG.UI.Queue then if i == 4 then HLBG.UI.Queue:Show() else HLBG.UI.Queue:Hide() end end
    if HLBG.UI.Info then if i == 5 then HLBG.UI.Info:Show() else HLBG.UI.Info:Hide() end end
    if HLBG.UI.Results then if i == 6 then HLBG.UI.Results:Show() else HLBG.UI.Results:Hide() end end
    HinterlandAffixHUDDB.lastInnerTab = i
end

HLBG.UI.Live = CreateFrame("Frame", nil, HLBG.UI.Frame)
HLBG.UI.Live:SetAllPoints(HLBG.UI.Frame)
HLBG.UI.Live.Text = HLBG.UI.Live:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
HLBG.UI.Live.Text:SetPoint("TOPLEFT", 16, -40)
HLBG.UI.Live.Text:SetText("Live status shows resources, timer and affix. Use the HUD on the world view.")
HLBG.UI.Live:SetScript("OnShow", function()
    SendChatCommand(".hlbg live players")
end)

-- Live scoreboard: scrollable player list
HLBG.UI.Live.Scroll = CreateFrame("ScrollFrame", "HLBG_LiveScroll", HLBG.UI.Live, "UIPanelScrollFrameTemplate")
HLBG.UI.Live.Scroll:SetPoint("TOPLEFT", 16, -64)
HLBG.UI.Live.Scroll:SetPoint("BOTTOMRIGHT", -36, 40)
HLBG.UI.Live.Content = CreateFrame("Frame", nil, HLBG.UI.Live.Scroll)
HLBG.UI.Live.Content:SetSize(460, 300)
if HLBG.UI.Live.Content.SetFrameStrata then HLBG.UI.Live.Content:SetFrameStrata("DIALOG") end
HLBG.UI.Live.Scroll:SetScrollChild(HLBG.UI.Live.Content)
HLBG.UI.Live.rows = HLBG.UI.Live.rows or {}

local function liveGetRow(i)
    local r = HLBG.UI.Live.rows[i]
    if not r then
        r = CreateFrame("Frame", nil, HLBG.UI.Live.Content)
        if r.SetFrameStrata then r:SetFrameStrata("DIALOG") end
        -- Slightly taller to allow a compact two-line display: name+score above, team+ts below
        r:SetSize(440, 28)
        -- Primary name (larger)
        r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        -- Primary score (aligned right)
        r.score = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    -- Secondary metadata line: team/HK/class/subgroup
        r.meta = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        -- Secondary timestamp (right-aligned)
        r.ts = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")

        r.name:SetPoint("TOPLEFT", r, "TOPLEFT", 2, -2)
        r.name:SetWidth(300); r.name:SetJustifyH("LEFT")
        r.score:SetPoint("TOPRIGHT", r, "TOPRIGHT", -2, -2)
        r.score:SetWidth(100); r.score:SetJustifyH("RIGHT")
        r.meta:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 2, 2)
        r.meta:SetWidth(220); r.meta:SetJustifyH("LEFT")
        r.ts:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", -2, 2)
        r.ts:SetWidth(200); r.ts:SetJustifyH("RIGHT")

        HLBG.UI.Live.rows[i] = r
    end
    return r
end

function HLBG.Live(rows)
    rows = rows or {}
    -- hide previous
    for i=1,#HLBG.UI.Live.rows do HLBG.UI.Live.rows[i]:Hide() end
    -- store for re-sorting (also persist last live payload)
    HLBG.UI.Live.lastRows = rows
    HinterlandAffixHUD_LastLive = HinterlandAffixHUD_LastLive or {}
    HinterlandAffixHUD_LastLive.ts = time()
    HinterlandAffixHUD_LastLive.rows = rows
    -- Visual cue: brief flash on main Frame to indicate new live payload
    pcall(function()
        if HLBG.UI and HLBG.UI.Frame and HLBG.UI.Frame:IsShown() then
            -- create a flash overlay if not present
            if not HLBG.UI.Frame._hlbgFlash then
                local f = HLBG.UI.Frame:CreateTexture(nil, 'OVERLAY')
                f:SetAllPoints(HLBG.UI.Frame)
                f:SetTexture('Interface/Tooltips/UI-Tooltip-Background')
                f:SetVertexColor(1,1,0.3,0.0)
                HLBG.UI.Frame._hlbgFlash = f
            end
            local tex = HLBG.UI.Frame._hlbgFlash
            tex:SetAlpha(0.6)
            -- animate fade out over ~0.6s using OnUpdate
            local t = 0
            HLBG.UI.Frame._hlbgFlashTimer = HLBG.UI.Frame._hlbgFlashTimer or CreateFrame('Frame')
            local timer = HLBG.UI.Frame._hlbgFlashTimer
            timer:SetScript('OnUpdate', function(self, elapsed)
                t = t + (elapsed or 0)
                local a = math.max(0, 0.6 - (t * 1.0))
                tex:SetAlpha(a)
                if t > 0.6 then tex:SetAlpha(0); self:SetScript('OnUpdate', nil); t = 0 end
            end)
            -- optional sound cue if PlaySound is available
            if type(PlaySound) == 'function' then pcall(function() PlaySound('RaidWarning', 'MASTER') end) end
        end
    end)
    -- determine sort key/dir
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
        -- keep incoming order
        sorted = rows
    end
    local y = -4
    for i,row in ipairs(sorted) do
        local r = liveGetRow(i)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", HLBG.UI.Live.Content, "TOPLEFT", 0, y)
        local name = row.name or row[3] or row[1] or "?"
        local score = row.score or row[5] or row[2] or 0
        -- Extra metrics (optional): hk, class, subgroup, team
        local hk = tonumber(row.hk or row.HK or row[6]) or 0
        local cls = tonumber(row[7] or row.class or row.Class) or nil
        local subgroup = (type(row.subgroup) ~= 'nil' and tonumber(row.subgroup)) or nil
        local team = tostring(row.team or row.Team or "")
        r.name:SetText(tostring(name))
        r.score:SetText(tostring(score))
        -- Build meta text if we have details
        local function ClassName(id)
            if type(id) ~= 'number' then return nil end
            local map = {
                [1] = 'Warrior', [2] = 'Paladin', [3] = 'Hunter', [4] = 'Rogue', [5] = 'Priest',
                [6] = 'Death Knight', [7] = 'Shaman', [8] = 'Mage', [9] = 'Warlock', [11] = 'Druid'
            }
            return map[id]
        end
        local parts = {}
        if team ~= '' then table.insert(parts, team) end
        table.insert(parts, string.format('HK:+%d', math.max(0, hk)))
        local cname = ClassName(cls)
        if cname then table.insert(parts, 'Class:'..cname) end
        if subgroup and subgroup >= 0 then table.insert(parts, 'Group:'..tostring(subgroup)) end
        r.meta:SetText(table.concat(parts, '  '))
        if not r._hlbgHover then
            r._hlbgHover = true
            r:SetScript('OnEnter', function(self)
                self:SetBackdrop({ bgFile = 'Interface/Tooltips/UI-Tooltip-Background' })
                self:SetBackdropColor(1,1,0.4,0.10)
            end)
            r:SetScript('OnLeave', function(self)
                self:SetBackdrop(nil)
            end)
        end
        r:Show()
        y = y - 18
    end
    -- resize content
    local newH = math.max(300, 8 + #rows * 18)
    HLBG.UI.Live.Content:SetHeight(newH)
    HLBG.UI.Live.Scroll:SetVerticalScroll(0)
end

-- Live header: resource totals and sorting controls (created lazily)
local function ensureLiveHeader()
    if HLBG.UI.Live.Header then return end
    HLBG.UI.Live.Header = CreateFrame("Frame", nil, HLBG.UI.Live)
    HLBG.UI.Live.Header:SetPoint("TOPLEFT", 16, -40)
    HLBG.UI.Live.Header:SetSize(460, 18)
    HLBG.UI.Live.Header.Name = HLBG.UI.Live.Header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    HLBG.UI.Live.Header.Name:SetPoint("LEFT", HLBG.UI.Live.Header, "LEFT", 2, 0)
    HLBG.UI.Live.Header.Name:SetText("Players")
    -- Optional HK header in the middle
    HLBG.UI.Live.Header.HK = HLBG.UI.Live.Header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    HLBG.UI.Live.Header.HK:SetPoint("CENTER", HLBG.UI.Live.Header, "CENTER", 0, 0)
    HLBG.UI.Live.Header.HK:SetText("HK")
    HLBG.UI.Live.Header.Score = HLBG.UI.Live.Header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    HLBG.UI.Live.Header.Score:SetPoint("RIGHT", HLBG.UI.Live.Header, "RIGHT", -2, 0)
    HLBG.UI.Live.Header.Score:SetText("Score")
    HLBG.UI.Live.Header.Totals = HLBG.UI.Live.Header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    HLBG.UI.Live.Header.Totals:SetPoint("TOPLEFT", HLBG.UI.Live.Header, "BOTTOMLEFT", 0, -2)

    -- clickable sorting
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

-- Update Live header totals from RES
local function UpdateLiveHeader()
    if not HLBG.UI.Live.Header then return end
    HLBG.UI.Live.Header.Totals:SetText(string.format("Alliance: %d   Horde: %d", RES.A or 0, RES.H or 0))
end

-- Fake live data for testing
SLASH_HLBGLIVEFAKE1 = "/hlbglivefake"
SlashCmdList["HLBGLIVEFAKE"] = function()
    local fake = {
        {name = UnitName("player"), score = RES.A or 0},
        {name = "PlayerA", score = 120},
        {name = "PlayerB", score = 80},
    }
    HLBG.Live(fake)
    HLBG.UI.Frame:Show(); ShowTab(1)
end

HLBG.UI.History = CreateFrame("Frame", nil, HLBG.UI.Frame)
HLBG.UI.History:SetAllPoints(HLBG.UI.Frame)
HLBG.UI.History:Hide()
HLBG.UI.History.Scroll = CreateFrame("ScrollFrame", "HLBG_HistoryScroll", HLBG.UI.History, "UIPanelScrollFrameTemplate")
HLBG.UI.History.Scroll:SetPoint("TOPLEFT", 16, -40)
HLBG.UI.History.Scroll:SetPoint("BOTTOMRIGHT", -36, 16)
HLBG.UI.History.Content = CreateFrame("Frame", nil, HLBG.UI.History.Scroll)
-- Width roughly equals visible scroll area (512 frame - 16 left - 36 right = 460)
HLBG.UI.History.Content:SetSize(460, 300)
-- Ensure content is above other UI elements during testing
if HLBG.UI.History.Content.SetFrameStrata then HLBG.UI.History.Content:SetFrameStrata("DIALOG") end
HLBG.UI.History.Scroll:SetScrollChild(HLBG.UI.History.Content)
HLBG.UI.History.rows = HLBG.UI.History.rows or {}
-- Empty-state label
HLBG.UI.History.EmptyText = HLBG.UI.History:CreateFontString(nil, "OVERLAY", "GameFontDisable")
HLBG.UI.History.EmptyText:SetPoint("TOPLEFT", 16, -64)
HLBG.UI.History.EmptyText:SetText("No data yet…")
HLBG.UI.History.EmptyText:Hide()

HLBG.UI.Stats = CreateFrame("Frame", nil, HLBG.UI.Frame)
HLBG.UI.Stats:SetAllPoints(HLBG.UI.Frame)
HLBG.UI.Stats:Hide()
HLBG.UI.Stats.Text = HLBG.UI.Stats:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
HLBG.UI.Stats.Text:SetPoint("TOPLEFT", 16, -40)
HLBG.UI.Stats.Text:SetText("Stats will appear here.")

-- Queue tab: join next run, show warmup/queue status
HLBG.UI.Queue = CreateFrame("Frame", nil, HLBG.UI.Frame)
HLBG.UI.Queue:SetAllPoints(HLBG.UI.Frame)
HLBG.UI.Queue:Hide()
HLBG.UI.Queue.Join = CreateFrame("Button", nil, HLBG.UI.Queue, "UIPanelButtonTemplate")
HLBG.UI.Queue.Join:SetPoint("TOPLEFT", 16, -40)
HLBG.UI.Queue.Join:SetSize(140, 24)
HLBG.UI.Queue.Join:SetText("Join Next Run")
HLBG.UI.Queue.Status = HLBG.UI.Queue:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
HLBG.UI.Queue.Status:SetPoint("TOPLEFT", HLBG.UI.Queue.Join, "BOTTOMLEFT", 0, -8)
HLBG.UI.Queue.Status:SetText("Queue status: unknown")
HLBG.UI.Queue.Join:SetScript("OnClick", function()
    if UnitAffectingCombat and UnitAffectingCombat("player") then
        DEFAULT_CHAT_FRAME:AddMessage("HLBG: Can't join while in combat")
        return
    end
    if _G.AIO and _G.AIO.Handle then
        _G.AIO.Handle("HLBG", "Request", "QUEUE", "JOIN")
    end
    -- Fallback to server chat command so it works even without AIO server handlers
    SendChatCommand(".hlbg queue join")
    DEFAULT_CHAT_FRAME:AddMessage("HLBG: Queue join requested")
end)

-- When showing the Queue tab, proactively request a status update
HLBG.UI.Queue:SetScript("OnShow", function()
    if HLBG.UI and HLBG.UI.Queue and HLBG.UI.Queue.Status then
        HLBG.UI.Queue.Status:SetText("Queue status: checking…")
    end
    if _G.AIO and _G.AIO.Handle then _G.AIO.Handle("HLBG", "Request", "QUEUE", "STATUS") end
    SendChatCommand(".hlbg queue status")
end)

-- Info tab: overview/features/settings/rewards
HLBG.UI.Info = CreateFrame("Frame", nil, HLBG.UI.Frame)
HLBG.UI.Info:SetAllPoints(HLBG.UI.Frame)
HLBG.UI.Info:Hide()
HLBG.UI.Info.Text = HLBG.UI.Info:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
HLBG.UI.Info.Text:SetPoint("TOPLEFT", 16, -40)
HLBG.UI.Info.Text:SetJustifyH("LEFT")
HLBG.UI.Info.Text:SetWidth(460)
local function BuildInfoText()
    HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
    local minLevel = HinterlandAffixHUDDB.minLevel or 1
    local rewards = HinterlandAffixHUDDB.rewardsText or "Honor, XP, custom tokens"
    local settings = {
        string.format("Addon HUD: %s", HinterlandAffixHUDDB.useAddonHud and "On" or "Off"),
        string.format("AFK warning: %s", HinterlandAffixHUDDB.enableAFKWarning and "On" or "Off"),
        string.format("Warmup prompt: %s", HinterlandAffixHUDDB.enableWarmupCTA and "On" or "Off"),
    }
    local lines = {
        "Hinterland Battleground (HLBG)",
        " ",
        "Features:",
        "- Movable worldstate HUD (resources/timer/affix)",
        "- PvP UI integration with Live/History/Stats/Results",
        "- Join next run via Queue tab",
        "- AFK warning (optional)",
        "- Warmup notice with quick-join",
        " ",
        string.format("Level requirement: %d", minLevel),
        "Current settings:",
        "  - "..table.concat(settings, "\n  - "),
        " ",
        "Rewards:",
        "  - "..rewards,
    }
    return table.concat(lines, "\n")
end
HLBG.UI.Info:SetScript("OnShow", function()
    HLBG.UI.Info.Text:SetText(BuildInfoText())
end)

-- Results tab: post-match scoreboard summary (placeholder rendering)
HLBG.UI.Results = CreateFrame("Frame", nil, HLBG.UI.Frame)
HLBG.UI.Results:SetAllPoints(HLBG.UI.Frame)
HLBG.UI.Results:Hide()
HLBG.UI.Results.Text = HLBG.UI.Results:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
HLBG.UI.Results.Text:SetPoint("TOPLEFT", 16, -40)
HLBG.UI.Results.Text:SetJustifyH("LEFT")
HLBG.UI.Results.Text:SetWidth(460)
HLBG.UI.Results.Text:SetText("Results will appear after each match.")

HLBG.UI.History.Columns = {}
-- Keep total <= ~460 width (including spacing)
local headers = {
    {text="ID", w=50},
    {text="Season", w=50},
    {text="Timestamp", w=120},
    {text="Winner", w=80},
    {text="Affix", w=70},
    {text="Reason", w=50},
}
local x = 0
for i,col in ipairs(headers) do
    local h = CreateFrame("Button", nil, HLBG.UI.History.Content)
    h:SetPoint("TOPLEFT", x, 0)
    h:SetSize(col.w, 18)
    h.Text = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    h.Text:SetPoint("LEFT", 2, 0)
    h.Text:SetText(col.text)
    -- sort arrow glyph (hidden by default)
    h.Arrow = h:CreateTexture(nil, "OVERLAY")
    h.Arrow:SetTexture("Interface/Buttons/UI-SortArrow")
    h.Arrow:SetSize(10, 10)
    h.Arrow:SetPoint("RIGHT", h, "RIGHT", -2, 0)
    h.Arrow:Hide()
    h:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine("Click to sort", 1,1,1); GameTooltip:Show() end)
    h:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- OnClick handler is assigned later in a single place to keep sorting logic unified
    HLBG.UI.History.Columns[i] = h
    x = x + col.w + 6
end

HLBG.UI.History.Nav = CreateFrame("Frame", nil, HLBG.UI.History)
HLBG.UI.History.Nav:SetPoint("BOTTOMRIGHT", -16, 12)
HLBG.UI.History.Nav:SetSize(180, 22)
HLBG.UI.History.Nav.Prev = CreateFrame("Button", nil, HLBG.UI.History.Nav, "UIPanelButtonTemplate")
HLBG.UI.History.Nav.Prev:SetPoint("LEFT")
HLBG.UI.History.Nav.Prev:SetSize(60, 22)
HLBG.UI.History.Nav.Prev:SetText("Prev")
HLBG.UI.History.Nav.Next = CreateFrame("Button", nil, HLBG.UI.History.Nav, "UIPanelButtonTemplate")
HLBG.UI.History.Nav.Next:SetPoint("LEFT", HLBG.UI.History.Nav.Prev, "RIGHT", 8, 0)
HLBG.UI.History.Nav.Next:SetSize(60, 22)
HLBG.UI.History.Nav.Next:SetText("Next")
HLBG.UI.History.Nav.PageText = HLBG.UI.History.Nav:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
HLBG.UI.History.Nav.PageText:SetPoint("LEFT", HLBG.UI.History.Nav.Next, "RIGHT", 8, 0)
HLBG.UI.History.Nav.Prev:SetScript("OnClick", function()
    local p = (HLBG.UI.History.page or 1); if p>1 then p=p-1 end
    if _G.AIO and _G.AIO.Handle then _G.AIO.Handle("HLBG", "Request", "HISTORY", p, HLBG.UI.History.per or 5, HLBG.UI.History.sortKey or "id", HLBG.UI.History.sortDir or "DESC") end
end)
HLBG.UI.History.Nav.Next:SetScript("OnClick", function()
    local p = (HLBG.UI.History.page or 1) + 1
    if _G.AIO and _G.AIO.Handle then _G.AIO.Handle("HLBG", "Request", "HISTORY", p, HLBG.UI.History.per or 5, HLBG.UI.History.sortKey or "id", HLBG.UI.History.sortDir or "DESC") end
end)

for i=1,6 do HLBG.UI.Tabs[i]:SetScript("OnClick", function() ShowTab(i) end) end

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
        HLBG.UI.Frame:Show()
        ShowTab(HinterlandAffixHUDDB.lastInnerTab or 1)
        if _G.AIO and _G.AIO.Handle then
            _G.AIO.Handle("HLBG", "Request", "HISTORY", 1, HLBG.UI.History.per or 5, HLBG.UI.History.sortKey or "id", HLBG.UI.History.sortDir or "DESC")
            _G.AIO.Handle("HLBG", "Request", "STATS")
        end
    SendChatCommand(".hlbg live players")
        SendChatCommand(".hlbg historyui 1 5 id DESC")
        SendChatCommand(".hlbg statsui")
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
        HLBG.UI.Frame:Show()
        ShowTab(HinterlandAffixHUDDB.lastInnerTab or 1)
        if _G.AIO and _G.AIO.Handle then
            _G.AIO.Handle("HLBG", "Request", "HISTORY", HLBG.UI.History.page or 1, HLBG.UI.History.per or 5, HLBG.UI.History.sortKey or "id", HLBG.UI.History.sortDir or "DESC")
            _G.AIO.Handle("HLBG", "Request", "STATS")
        end
    SendChatCommand(".hlbg live players")
        SendChatCommand(".hlbg historyui 1 5 id DESC")
        SendChatCommand(".hlbg statsui")
    end)
    -- hide our inner frame when PvP frame hides
    _pvp:HookScript("OnHide", function()
        if HLBG.UI.Frame and HLBG.UI.Frame:GetParent() == _pvp then HLBG.UI.Frame:Hide() end
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
    HLBG.UI.Frame:SetScript("OnUpdate", function(self, elapsed)
        t = t + (elapsed or 0)
        if t > 1.0 then
            t = 0; tries = tries + 1; EnsurePvPTab(); EnsurePvPHeaderButton()
            if _G["PVPFrameTabHLBG"] or _G["PVPFrameHLBGButton"] or tries > 5 then HLBG.UI.Frame:SetScript("OnUpdate", nil) end
        end
    end)
end

-- Handlers from server
function HLBG.OpenUI()
    local pvp = _G["PVPParentFrame"] or _G["PVPFrame"]
    if pvp and pvp:IsShown() then
        if HLBG.UI.Frame:GetParent() ~= pvp then HLBG.UI.Frame:SetParent(pvp) end
    else
        if HLBG.UI.Frame:GetParent() ~= UIParent then HLBG.UI.Frame:SetParent(UIParent) end
    end
    HLBG.UI.Frame:Show()
    ShowTab(HinterlandAffixHUDDB.lastInnerTab or 1)
    -- Prime queries through chat as well in case server AIO isn't available
    SendChatCommand(".hlbg live players")
    SendChatCommand(".hlbg historyui 1 5 id DESC")
    SendChatCommand(".hlbg statsui")
end
DEFAULT_CHAT_FRAME:AddMessage("HLBG client: main OpenUI bound")

function HLBG.History(a, b, c, d, e, f, g)
    -- Accept both signatures:
    -- 1) History(rows, page, per, total, col, dir)
    -- 2) History(player, rows, page, per, total, col, dir)
    local rows, page, per, total, col, dir
    -- robust detection: check which argument looks like an array of rows
    local function looksLikeRows(v)
        if type(v) ~= "table" then return false end
        -- array-like with at least one numeric entry
        if #v and #v > 0 then return true end
        -- sometimes single-row payloads may be a map; detect common keys
        if v.id or v.ts or v.timestamp or v.winner or v.affix or v.reason then return true end
        return false
    end
    if looksLikeRows(a) then
        rows, page, per, total, col, dir = a, b, c, d, e, f
    elseif looksLikeRows(b) then
        rows, page, per, total, col, dir = b, c, d, e, f, g
    else
        -- fallback: try to coerce b (common case where first arg is player userdata/string)
        rows, page, per, total, col, dir = b, c, d, e, f, g
    end
    -- small debug to surface incoming argument shapes when things go wrong
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        local function shortType(v) if v == nil then return "nil" end return type(v) end
        local sampleInfo = ""
        if type(rows) == "table" then
            local n = #rows
            if n > 0 and type(rows[1]) == "table" then
                local first = rows[1]
                local keys = {}
                for k,_ in pairs(first) do table.insert(keys, tostring(k)) end
                sampleInfo = string.format(" sampleRowKeys=%s", table.concat(keys, ","))
            elseif n > 0 then
                sampleInfo = string.format(" sampleRow0=%s", tostring(rows[1]))
            end
        end
        -- debug trace
        if type(DEFAULT_CHAT_FRAME.AddMessage) == "function" then
            local newH = math.max(300, 8 + #rows * 28)
            local n = (#rows) or 0
            DEFAULT_CHAT_FRAME:AddMessage(string.format("HLBG: History handler invoked (rowsType=%s, n=%d)%s", shortType(rows), n, sampleInfo))
        end
    end
    -- If rows is not a table but we received a TSV string in one of the args, try the TSV fallback parser
    if type(rows) ~= "table" then
        -- detect a TSV payload among args (usually first or second arg)
        local tsv = nil
        if type(a) == "string" and a:find("\t") then tsv = a end
        if not tsv and type(b) == "string" and b:find("\t") then tsv = b end
        if tsv and type(HLBG.HistoryStr) == "function" then
            DEFAULT_CHAT_FRAME:AddMessage("HLBG DBG: No table rows received, attempting TSV fallback")
            return HLBG.HistoryStr(a,b,c,d,e,f,g)
        end
        rows = {}
    end
    HLBG.UI.History.page = page or HLBG.UI.History.page or 1
    HLBG.UI.History.per = per or HLBG.UI.History.per or 25
    HLBG.UI.History.total = total or HLBG.UI.History.total or 0
    HLBG.UI.History.sortKey = col or HLBG.UI.History.sortKey or "id"
    HLBG.UI.History.sortDir = dir or HLBG.UI.History.sortDir or "DESC"

    -- Normalize rows: some transports may send a map rather than a sequence
    local normalized = {}
    if type(rows) == "table" then
        -- Fast path: already sequence-like
        if #rows and #rows > 0 then
            normalized = rows
        else
            -- Collect values which are tables (likely row objects) and sort by numeric key if present
            local tmp = {}
            for k,v in pairs(rows) do
                if type(v) == "table" then
                    local nk = tonumber(k)
                    if nk then
                        tmp[nk] = v
                    else
                        table.insert(tmp, v)
                    end
                end
            end
            -- If tmp has numeric indices, build dense array in numeric order
            local hasNumeric = false
            for k,_ in pairs(tmp) do if type(k) == "number" then hasNumeric = true; break end end
            if hasNumeric then
                local i = 1
                while tmp[i] do table.insert(normalized, tmp[i]); i = i + 1 end
            else
                -- fallback: take insertion order
                for _,v in ipairs(tmp) do table.insert(normalized, v) end
            end
        end
    end
    -- If we still have nothing, ensure rows is at least an empty array
    if #normalized == 0 and type(rows) == "table" then
        -- maybe rows is a single map representing one row
        if type(rows.id) ~= "nil" or type(rows.ts) ~= "nil" then
            table.insert(normalized, rows)
        end
    end

    -- debug: report normalized shapes
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("HLBG DBG: Normalized rows count=%d (origType=%s)", #normalized, type(rows)))
    end

    rows = normalized

    -- send a compact sample to server-side log for easier debugging (if helper available)
    local okSend, sendFn = pcall(function() return _G.HLBG_SendClientLog end)
    local send = (okSend and type(_G.HLBG_SendClientLog) == "function") and _G.HLBG_SendClientLog or ((type(HLBG) == "table" and type(HLBG.SendClientLog) == "function") and HLBG.SendClientLog or nil)
    if send then
        local sample = ""
        if #rows > 0 and type(rows[1]) == "table" then
            local r = rows[1]
            local id = tostring(r[1] or r.id or "")
            local ts = tostring(r[2] or r.ts or "")
            local win = tostring(r[3] or r.winner or "")
            local aff = tostring(r[4] or r.affix or "")
            sample = string.format("%s\t%s\t%s\t%s", id, ts, win, aff)
        end
        pcall(function() send(string.format("HISTORY_CLIENT N=%d sample=%s", #rows, sample)) end)
    end

    -- Additional local debug: print first-row keys/values and force UI visible so we can inspect rendering
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("HLBG DBG: After normalize rows=%d total=%s", #rows, tostring(HLBG.UI.History.total)))
        if #rows > 0 and type(rows[1]) == "table" then
            local keys = {}
            for k,v in pairs(rows[1]) do table.insert(keys, tostring(k)..":"..tostring(v)) end
            DEFAULT_CHAT_FRAME:AddMessage("HLBG DBG: firstRow="..table.concat(keys, ", "))
        end
    end

    -- Ensure the UI is visible so the user can inspect whether rows were created
    if HLBG.UI and HLBG.UI.Frame then HLBG.UI.Frame:Show(); ShowTab(2) end
    if HLBG.UI and HLBG.UI.History and HLBG.UI.History.Content then HLBG.UI.History.Content:Show() end
    if HLBG.UI and HLBG.UI.History and HLBG.UI.History.Scroll then HLBG.UI.History.Scroll:SetVerticalScroll(0) end

    -- Render with a simple row widget pool
    local function getRow(i)
        local r = HLBG.UI.History.rows[i]
        if not r then
            r = CreateFrame("Frame", nil, HLBG.UI.History.Content)
                if r.SetFrameStrata then r:SetFrameStrata("DIALOG") end
            r:SetSize(420, 14)
            r.id = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.sea = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.ts = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.win = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.aff = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.rea = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                -- force visible text color for debugging
                if r.id.SetTextColor then r.id:SetTextColor(1,1,1,1) end
                if r.sea.SetTextColor then r.sea:SetTextColor(1,1,1,1) end
                if r.ts.SetTextColor then r.ts:SetTextColor(1,1,1,1) end
                if r.win.SetTextColor then r.win:SetTextColor(1,1,1,1) end
                if r.aff.SetTextColor then r.aff:SetTextColor(1,1,1,1) end
                if r.rea.SetTextColor then r.rea:SetTextColor(1,1,1,1) end
            -- layout mirrors headers: ID(50), SEASON(50), TS(120), WIN(80), AFF(70), REASON(50) with 6px spacing
            r.id:SetPoint("LEFT", r, "LEFT", 0, 0)
            r.id:SetWidth(50); r.id:SetJustifyH("LEFT")
            r.sea:SetPoint("LEFT", r.id, "RIGHT", 6, 0)
            r.sea:SetWidth(50); r.sea:SetJustifyH("LEFT")
            r.ts:SetPoint("LEFT", r.sea, "RIGHT", 6, 0)
            r.ts:SetWidth(120); r.ts:SetJustifyH("LEFT")
            r.win:SetPoint("LEFT", r.ts, "RIGHT", 6, 0)
            r.win:SetWidth(80); r.win:SetJustifyH("LEFT")
            r.aff:SetPoint("LEFT", r.win, "RIGHT", 6, 0)
            r.aff:SetWidth(70); r.aff:SetJustifyH("LEFT")
            r.rea:SetPoint("LEFT", r.aff, "RIGHT", 6, 0)
            r.rea:SetWidth(50); r.rea:SetJustifyH("LEFT")
            HLBG.UI.History.rows[i] = r
        end
        return r
    end

    -- hide all previously visible rows
    for i=1,#HLBG.UI.History.rows do HLBG.UI.History.rows[i]:Hide() end

    local y = -22
    local hadRows = false
    for i, row in ipairs(rows) do
        local r = getRow(i)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", HLBG.UI.History.Content, "TOPLEFT", 0, y)
        -- Prefer named fields; fallback to compact array rows {id, [season], ts, winner, affix, reason}
    local id    = row.id or row[1]
    local sea   = row.season or row[2]
    local sname = row.seasonName or row.sname or nil
        -- if season present at [2], ts may be at [3]; otherwise [2]
        local ts    = row.ts or row[3] or row[2]
        local win   = row.winner or row[4] or row[3]
        local affix = row.affix or row[5] or row[4]
        local reas  = row.reason or row[6] or row[5]
        local who = (win == "Alliance" or win == "ALLIANCE") and "|cff1e90ffAlliance|r" or (win == "Horde" or win == "HORDE") and "|cffff0000Horde|r" or "|cffffff00Draw|r"
    r.id:SetText(tostring(tonumber(id) or 0))
    if sname and sname ~= "" then
        r.sea:SetText(tostring(sname))
    else
        r.sea:SetText(tostring(tonumber(sea or row.season or 0) or 0))
    end
    r.ts:SetText(ts or "")
    r.win:SetText(who)
    r.aff:SetText(HLBG.GetAffixName(affix))
    r.rea:SetText(reas or "-")
        if not r._hlbgHover then
            r._hlbgHover = true
            r:SetScript('OnEnter', function(self)
                self:SetBackdrop({ bgFile = 'Interface/Tooltips/UI-Tooltip-Background' })
                self:SetBackdropColor(1,1,0.4,0.10)
            end)
            r:SetScript('OnLeave', function(self)
                self:SetBackdrop(nil)
            end)
        end
        r:Show()
        y = y - 14
        hadRows = true
    end

    local maxPage = (HLBG.UI.History.total and HLBG.UI.History.total > 0) and math.max(1, math.ceil(HLBG.UI.History.total/(HLBG.UI.History.per or 25))) or (HLBG.UI.History.page or 1)
    HLBG.UI.History.Nav.PageText:SetText(string.format("Page %d / %d", HLBG.UI.History.page, maxPage))
    local hasPrev = (HLBG.UI.History.page or 1) > 1
    local hasNext = (HLBG.UI.History.page or 1) < maxPage
    if HLBG.UI.History.Nav.Prev then if hasPrev then HLBG.UI.History.Nav.Prev:Enable() else HLBG.UI.History.Nav.Prev:Disable() end end
    if HLBG.UI.History.Nav.Next then if hasNext then HLBG.UI.History.Nav.Next:Enable() else HLBG.UI.History.Nav.Next:Disable() end end

    -- Resize scroll child to the content and reset scroll to top
    local visibleCount = (type(rows) == "table" and #rows) or 0
    local base = 22 -- header area height used above
    local rowH = 14
    local minH = 300
    local newH = math.max(minH, base + visibleCount * rowH + 8)
    HLBG.UI.History.Content:SetHeight(newH)
    if HLBG.UI.History.Scroll and HLBG.UI.History.Scroll.SetVerticalScroll then HLBG.UI.History.Scroll:SetVerticalScroll(0) end
    if HLBG.UI.History.EmptyText then
        if hadRows then HLBG.UI.History.EmptyText:Hide() else HLBG.UI.History.EmptyText:Show() end
    end

    -- optional debug
    DEFAULT_CHAT_FRAME:AddMessage(string.format("HLBG: History received rows=%d total=%s", visibleCount, tostring(HLBG.UI.History.total)))
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
    local ssz = tonumber(stats.season or stats.Season or 0) or 0
    local sname = stats.seasonName or stats.SeasonName
    local seasonStr
    if sname and sname ~= "" then
        seasonStr = "  Season: "..tostring(sname)
    elseif ssz and ssz > 0 then
        seasonStr = "  Season: "..tostring(ssz)
    else
        seasonStr = ""
    end
    local lines = { string.format("Alliance: %d  Horde: %d  Draws: %d  Avg: %d min%s", a, h, d, math.floor((stats.avgDuration or 0)/60), seasonStr) }
    -- append top 3 affix and weather splits if present (handle array or map payloads)
    local function top3Flexible(v)
        local items = {}
        if type(v) == 'table' then
            if #v > 0 then
                -- array of rows
                for i=1,#v do
                    local row = v[i]
                    local total = (tonumber(row.Alliance or row.alliance or row.A or 0) or 0)
                                + (tonumber(row.Horde or row.horde or row.H or 0) or 0)
                                + (tonumber(row.DRAW or row.draw or row.D or 0) or 0)
                    local label = row.weather or (row.affix and HLBG.GetAffixName(row.affix)) or tostring(i)
                    table.insert(items, {label=label, total=total})
                end
            else
                -- map keyed by label -> {Alliance,Horde,DRAW}
                for k,row in pairs(v) do
                    local total = (tonumber(row.Alliance or 0) or 0) + (tonumber(row.Horde or 0) or 0) + (tonumber(row.DRAW or 0) or 0)
                    table.insert(items, {label=tostring(k), total=total})
                end
            end
        end
        table.sort(items, function(a,b) return a.total > b.total end)
        local out = {}
        for i=1,math.min(3,#items) do table.insert(out, string.format("%s:%d", items[i].label, items[i].total)) end
        return table.concat(out, ", ")
    end
    if stats.byAffix and next(stats.byAffix) then table.insert(lines, "Top Affixes: "..top3Flexible(stats.byAffix)) end
    if stats.byWeather and next(stats.byWeather) then table.insert(lines, "Top Weather: "..top3Flexible(stats.byWeather)) end
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
    HLBG.UI.Stats.Text:SetText(table.concat(lines, "\n"))
end

-- Provide uppercase aliases in case the dispatcher normalizes names
HLBG.HISTORY = function(...) return HLBG.History(...) end
HLBG.STATS = function(...) return HLBG.Stats(...) end
function HLBG.DBG(msg)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("HLBG DBG: "..tostring(msg)) end
end

-- Warmup notice handler: server can notify client warmup has begun
function HLBG.Warmup(info)
    HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
    if not HinterlandAffixHUDDB.enableWarmupCTA then return end
    local txt = "Warmup has begun! Use the Queue tab to join from safe areas."
    if type(info) == 'string' and info ~= '' then txt = info end
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00HLBG|r: "..txt) end
    if HLBG.UI and HLBG.UI.Queue and HLBG.UI.Queue.Status then HLBG.UI.Queue.Status:SetText("Warmup active — join now!") end
end

-- Queue status updates (e.g., position in queue, joined, left)
function HLBG.QueueStatus(status)
    local s = (type(status) == 'string' and status) or (type(status) == 'table' and (status.text or status.state)) or 'Unknown'
    if HLBG.UI and HLBG.UI.Queue and HLBG.UI.Queue.Status then HLBG.UI.Queue.Status:SetText("Queue status: "..tostring(s)) end
end

-- Results payload from server after match completion
function HLBG.Results(summary)
    local lines = { "Results will appear after each match." }
    if type(summary) == 'table' then
        local win = summary.winner or summary.Win or summary.result
        local aff = summary.affix or summary.Affix
        local dur = summary.duration or summary.Duration
        table.insert(lines, string.format("Winner: %s", tostring(win or "?")))
        if aff then table.insert(lines, "Affix: "..HLBG.GetAffixName(aff)) end
        if dur then table.insert(lines, string.format("Duration: %s", SecondsToClock(tonumber(dur) or 0))) end
        if summary.rewards then table.insert(lines, "Rewards: "..tostring(summary.rewards)) end
        if summary.special then table.insert(lines, "Special: "..tostring(summary.special)) end
    end
    if HLBG.UI and HLBG.UI.Results and HLBG.UI.Results.Text then HLBG.UI.Results.Text:SetText(table.concat(lines, "\n")) end
    -- switch to Results tab if user has window open
    if HLBG.UI and HLBG.UI.Frame and HLBG.UI.Frame:IsShown() then ShowTab(6) end
end

-- Send a client log line to server for file-backed logging via AIO
-- Provide a stable global SendClientLog function so slash handlers work even if HLBG table is replaced
local function SendClientLogLocal(msg)
    if not msg then return end
    local payload = string.format("[%s] %s", date("%Y-%m-%d %H:%M:%S"), tostring(msg))
    if _G.AIO and _G.AIO.Handle then
        pcall(function() _G.AIO.Handle("HLBG", "Request", "CLIENTLOG", payload) end)
    else
        -- fallback: store in saved buffer for later
        if not HinterlandAffixHUD_DebugLog then HinterlandAffixHUD_DebugLog = {} end
        table.insert(HinterlandAffixHUD_DebugLog, 1, payload)
        while #HinterlandAffixHUD_DebugLog > 200 do table.remove(HinterlandAffixHUD_DebugLog) end
    end
end

-- Attach both to HLBG (if present) and a global name to avoid timing issues when AIO.AddHandlers swaps the HLBG table
if type(HLBG) == "table" then HLBG.SendClientLog = SendClientLogLocal end
_G.HLBG_SendClientLog = SendClientLogLocal


-- Slash to send most recent saved debug line to server log
SLASH_HLBGLOG1 = "/hlbglog"
SlashCmdList["HLBGLOG"] = function()
    local line = (HinterlandAffixHUD_DebugLog and HinterlandAffixHUD_DebugLog[1]) or ("HLBG log ping from client: nil")
    HLBG.SendClientLog(line)
    DEFAULT_CHAT_FRAME:AddMessage("HLBG: Sent client log to server (check Custom/Logs/hlbg_client.log)")
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
            -- Newest 7-column format: id\tseason\tseasonName\tts\twinner\taffix\treason
            local id7, season7, sname7, ts7, win7, aff7, rea7 = string.match(line, "^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)$")
            if id7 and ts7 and win7 and aff7 and rea7 then
                table.insert(rows, { id = id7 or "", season = tonumber(season7) or season7, seasonName = sname7, ts = ts7 or "", winner = win7 or "", affix = aff7 or "", reason = rea7 or "" })
            else
                -- Prior 6-column format: id\tseason\tts\twinner\taffix\treason
                local id, season, ts, win, aff, rea = string.match(line, "^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)$")
                if id and ts and win and aff and rea then
                    table.insert(rows, { id = id or "", season = tonumber(season) or season, ts = ts or "", winner = win or "", affix = aff or "", reason = rea or "" })
                else
                    -- Legacy 5-column format: id\tts\twinner\taffix\treason
                    local lid, lts, lwin, laff, lrea = string.match(line, "^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)$")
                    if lid then table.insert(rows, { id = lid or "", ts = lts or "", winner = lwin or "", affix = laff or "", reason = lrea or "" }) end
                end
            end
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
        -- normalize args
        if type(player) ~= "string" and type(player) ~= "userdata" then stats = player end
        stats = stats or {}

        local counts = stats.counts or {}
        local a = tonumber(counts.Alliance or counts.ALLIANCE or 0) or 0
        local h = tonumber(counts.Horde or counts.HORDE or 0) or 0
        local draws = tonumber(stats.draws or 0) or 0
        local avgDur = tonumber(stats.avgDuration or 0) or 0
        local seasonId = tonumber(stats.season or stats.Season or 0) or 0
        local seasonName = tostring(stats.seasonName or stats.SeasonName or "")

        local reasons = stats.reasons or {}
        local rDepl = tonumber(reasons.depletion or 0) or 0
        local rTie  = tonumber(reasons.tiebreaker or 0) or 0
        local rMan  = tonumber(reasons.manual or 0) or 0
        local rDraw = tonumber(reasons.draw or 0) or draws

        local margins = stats.margins or {}
        local avgMargin = tonumber(margins.avg or 0) or 0
        local largest = margins.largest or {}
        local lTeam = tostring(largest.team or "")
        local lMargin = tonumber(largest.margin or 0) or 0
        local lA = tonumber(largest.a or 0) or 0
        local lH = tonumber(largest.h or 0) or 0
        local lTs = tostring(largest.ts or "")
        local lId = tostring(largest.id or "")

        local streaks = stats.streaks or {}
        local cur = streaks.current or {}
        local lon = streaks.longest or {}
        local curTeam = tostring(cur.team or "")
        local curLen = tonumber(cur.len or 0) or 0
        local lonTeam = tostring(lon.team or "")
        local lonLen = tonumber(lon.len or 0) or 0

        local affixRows = stats.byAffix or {}

        local function icon(team)
            if team == "Alliance" or team == "ALLIANCE" then return "|TInterface/TargetingFrame/UI-PVP-ALLIANCE:16|t" end
            if team == "Horde" or team == "HORDE" then return "|TInterface/TargetingFrame/UI-PVP-HORDE:16|t" end
            return ""
        end
        local function teamColor(team, text)
            if team == "Alliance" or team == "ALLIANCE" then return "|cff1e90ff"..text.."|r" end
            if team == "Horde" or team == "HORDE" then return "|cffff0000"..text.."|r" end
            return text
        end
        local function mm(seconds) return math.floor((tonumber(seconds) or 0)/60) end

        -- Header line: icons + counts + draws + avg + season
        local seasonStr = ""
        if seasonName ~= "" then seasonStr = "  Season: "..seasonName
        elseif seasonId > 0 then seasonStr = "  Season: "..tostring(seasonId) end
        local header = string.format("%s %d    %s %d    Draws: %d    Avg: %d min%s",
            icon("Alliance"), a, icon("Horde"), h, draws, mm(avgDur), seasonStr)

        -- Reasons line (omit draws here since already above)
        local reasonsLine = string.format("Reasons: depletion %d, tiebreaker %d, manual %d", rDepl, rTie, rMan)

        -- Streaks line
        local streaksLine = string.format("Streaks: current %s x%d, longest %s x%d",
            teamColor(curTeam, curTeam ~= "" and curTeam or "-"), curLen,
            teamColor(lonTeam, lonTeam ~= "" and lonTeam or "-"), lonLen)

        -- Margins line
        local marginsLine = string.format("Margins: avg %d, largest %d (%s %d-%d, id #%s, %s)",
            avgMargin, lMargin, teamColor(lTeam, lTeam ~= "" and lTeam or "-"), lA, lH, lId, lTs)

        -- Affix table (top 5 for compactness)
        local affixLines = {}
        local maxAffix = math.min(5, #affixRows)
        for i=1,maxAffix do
            local r = affixRows[i]
            local name = HLBG.GetAffixName(r.affix)
            local aa = tonumber(r.Alliance or r.alliance or r.A or r.a or 0) or 0
            local hh = tonumber(r.Horde or r.horde or r.H or r.h or 0) or 0
            local dd = tonumber(r.DRAW or r.draw or r.D or r.d or 0) or 0
            local ad = tonumber(r.avg or r.Avg or 0) or 0
            affixLines[#affixLines+1] = string.format("- %s  %s %d   %s %d   D:%d   avg:%d min",
                tostring(name), icon("Alliance"), aa, icon("Horde"), hh, dd, mm(ad))
        end
        if #affixLines == 0 then affixLines = { "(no per-affix data)" } end

        local lines = {
            header,
            reasonsLine,
            streaksLine,
            marginsLine,
            " ",
            "Per-Affix (top):",
            table.concat(affixLines, "\n")
        }
        HLBG.UI.Stats.Text:SetText(table.concat(lines, "\n"))

-- Global chat fallback listener for broadcast JSON/TSV messages
local chatListener = CreateFrame('Frame')
chatListener:RegisterEvent('CHAT_MSG_CHANNEL')
chatListener:RegisterEvent('CHAT_MSG_SYSTEM')
chatListener:RegisterEvent('CHAT_MSG_SAY')
chatListener:RegisterEvent('CHAT_MSG_YELL')
chatListener:RegisterEvent('CHAT_MSG_PARTY')
chatListener:RegisterEvent('CHAT_MSG_GUILD')
chatListener:SetScript('OnEvent', function(self, event, msg, ...)
    if type(msg) ~= 'string' then return end
    -- JSON broadcast prefix
    local jprefix = msg:match('%[HLBG_LIVE_JSON%]%s*(.*)')
    if jprefix then
        local ok, decoded = pcall(function() return json_decode(jprefix) end)
        if ok and type(decoded) == 'table' then
            local rows = nil
            if #decoded > 0 then rows = decoded else rows = {} for k,v in pairs(decoded) do table.insert(rows, v) end end
            if rows and #rows > 0 and type(HLBG.Live) == 'function' then pcall(HLBG.Live, rows) end
            return
        end
    end
    -- TSV broadcast prefix
    local tprefix = msg:match('%[HLBG_LIVE%]%s*(.*)')
    if tprefix then
        local rows = {}
        tprefix = tprefix:gsub('%|%|', '\n')
        for line in tprefix:gmatch('[^\n]+') do
            local parts = {}
            for part in line:gmatch('([^\t]+)') do table.insert(parts, part) end
            if #parts >= 5 then table.insert(rows, { id = parts[1], ts = parts[2], name = parts[3], team = parts[4], score = tonumber(parts[5]) or parts[5] }) end
        end
        if #rows > 0 and type(HLBG.Live) == 'function' then pcall(HLBG.Live, rows) end
        return
    end

    -- Warmup notice
    local warm = msg:match('%[HLBG_WARMUP%]%s*(.*)')
    if warm then
        if type(HLBG.Warmup) == 'function' then pcall(HLBG.Warmup, warm) end
        return
    end

    -- Queue status
    local q = msg:match('%[HLBG_QUEUE%]%s*(.*)')
    if q then
        if type(HLBG.QueueStatus) == 'function' then pcall(HLBG.QueueStatus, q) end
        return
    end

    -- Results JSON
    local rj = msg:match('%[HLBG_RESULTS_JSON%]%s*(.*)')
    if rj then
        local ok, decoded = pcall(function() return json_decode(rj) end)
        if ok and type(decoded) == 'table' and type(HLBG.Results) == 'function' then pcall(HLBG.Results, decoded) end
        return
    end

    -- History TSV fallback
    local htsv = msg:match('%[HLBG_HISTORY_TSV%]%s*(.*)')
    if htsv then
        -- Convert our '||' line placeholders back to real newlines and reuse HistoryStr
        htsv = htsv:gsub('%|%|', '\n')
        if type(HLBG.HistoryStr) == 'function' then pcall(HLBG.HistoryStr, htsv, 1, 5, 0, 'id', 'DESC') end
        return
    end

    -- Stats JSON fallback
    local sj = msg:match('%[HLBG_STATS_JSON%]%s*(.*)')
    if sj then
        local ok, decoded = pcall(function() return json_decode(sj) end)
        if ok and type(decoded) == 'table' and type(HLBG.Stats) == 'function' then pcall(HLBG.Stats, decoded) end
        return
    end
end)

-- Add a simple Refresh button on the History and Stats panes
HLBG.UI.Refresh = CreateFrame("Button", nil, HLBG.UI.Frame, "UIPanelButtonTemplate")
HLBG.UI.Refresh:SetSize(80, 22)
HLBG.UI.Refresh:SetPoint("TOPRIGHT", HLBG.UI.Frame, "TOPRIGHT", -18, -10)
HLBG.UI.Refresh:SetText("Refresh")
HLBG.UI.Refresh:SetScript("OnClick", function()
    if _G.AIO and _G.AIO.Handle then
        _G.AIO.Handle("HLBG", "Request", "HISTORY", HLBG.UI.History.page or 1, HLBG.UI.History.per or 5, HLBG.UI.History.sortKey or "id", HLBG.UI.History.sortDir or "DESC")
        _G.AIO.Handle("HLBG", "Request", "STATS")
    end
    -- Also use chat fallbacks so refresh works without server-side AIO
    SendChatCommand(string.format(".hlbg historyui %d %d %s %s", HLBG.UI.History.page or 1, HLBG.UI.History.per or 5, HLBG.UI.History.sortKey or "id", HLBG.UI.History.sortDir or "DESC"))
    SendChatCommand(".hlbg statsui")
end)

-- Make column headers actually sort (toggle ASC/DESC)
for i,h in ipairs(HLBG.UI.History.Columns) do
    h:SetScript("OnClick", function()
    local keyMap = { ID = "id", Season = "season", Timestamp = "occurred_at", Winner = "winner", Affix = "affix", Reason = "reason" }
        local sk = keyMap[h.Text:GetText()] or "id"
        if HLBG.UI.History.sortKey == sk then
            HLBG.UI.History.sortDir = (HLBG.UI.History.sortDir == "ASC") and "DESC" or "ASC"
        else
            HLBG.UI.History.sortKey = sk; HLBG.UI.History.sortDir = "DESC"
        end
        if _G.AIO and _G.AIO.Handle then
            _G.AIO.Handle("HLBG", "Request", "HISTORY", HLBG.UI.History.page or 1, HLBG.UI.History.per or 5, HLBG.UI.History.sortKey, HLBG.UI.History.sortDir)
        end
        -- Fallback: ask server via chat endpoints too
        SendChatCommand(string.format(".hlbg historyui %d %d %s %s", HLBG.UI.History.page or 1, HLBG.UI.History.per or 5, HLBG.UI.History.sortKey, HLBG.UI.History.sortDir))
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

    -- AFK warning toggle
    local cbAFK = CreateFrame("CheckButton", nil, self, "InterfaceOptionsCheckButtonTemplate")
    cbAFK:SetPoint("TOPLEFT", cb, "BOTTOMLEFT", 0, -12)
    local cbAFKLabel = self:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    cbAFKLabel:SetPoint("LEFT", cbAFK, "RIGHT", 4, 0)
    cbAFKLabel:SetText("Enable AFK warning (combat-safe)")
    cbAFK._label = cbAFKLabel
    cbAFK:SetChecked(HinterlandAffixHUDDB.enableAFKWarning)
    cbAFK:SetScript("OnClick", function(s)
        HinterlandAffixHUDDB.enableAFKWarning = s:GetChecked() and true or false
    end)

    -- Warmup CTA toggle
    local cbWarm = CreateFrame("CheckButton", nil, self, "InterfaceOptionsCheckButtonTemplate")
    cbWarm:SetPoint("TOPLEFT", cbAFK, "BOTTOMLEFT", 0, -12)
    local cbWarmLabel = self:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    cbWarmLabel:SetPoint("LEFT", cbWarm, "RIGHT", 4, 0)
    cbWarmLabel:SetText("Enable warmup join prompt")
    cbWarm._label = cbWarmLabel
    cbWarm:SetChecked(HinterlandAffixHUDDB.enableWarmupCTA)
    cbWarm:SetScript("OnClick", function(s)
        HinterlandAffixHUDDB.enableWarmupCTA = s:GetChecked() and true or false
    end)
    local scale = CreateFrame("Slider", nil, self, "OptionsSliderTemplate"); scale:SetPoint("TOPLEFT", cb, "BOTTOMLEFT", 0, -24)
    scale:SetMinMaxValues(0.8, 1.6); if scale.SetValueStep then scale:SetValueStep(0.05) end
    if scale.SetObeyStepOnDrag then scale:SetObeyStepOnDrag(true) end
    if scale.Low then scale.Low:SetText("0.8") end
    if scale.High then scale.High:SetText("1.6") end
    if scale.Text then scale.Text:SetText("HUD Scale") end
    scale:SetValue(HinterlandAffixHUDDB.scaleHud or 1.0)
    scale:SetScript("OnValueChanged", function(s,val) HinterlandAffixHUDDB.scaleHud = tonumber(string.format("%.2f", val)); HLBG.UI.HUD:SetScale(HinterlandAffixHUDDB.scaleHud) end)
end)
InterfaceOptions_AddCategory(opt)

-- Minimal AFK warning stub (client-side only, non-invasive)
do
    local afkTimer, afkAccum = nil, 0
    local lastX, lastY, lastTime = nil, nil, 0
    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function(_, elapsed)
        if not HinterlandAffixHUDDB or not HinterlandAffixHUDDB.enableAFKWarning then return end
        afkAccum = afkAccum + (elapsed or 0)
        if afkAccum < 5.0 then return end -- check every 5s
        afkAccum = 0
        local inBG = InHinterlands()
        if not inBG then return end
        -- approximate movement using map position if available
        local x,y = 0,0
        if type(GetPlayerMapPosition) == 'function' then
            local px, py = GetPlayerMapPosition("player")
            if px and py then x,y = px,py end
        end
        local moved = (lastX == nil or math.abs((x - (lastX or 0))) > 0.001 or math.abs((y - (lastY or 0))) > 0.001)
        local now = time()
        if moved then lastX, lastY, lastTime = x, y, now; return end
        -- no movement; if more than N seconds, warn
        local idleSec = now - (lastTime or now)
        local threshold = (HinterlandAffixHUDDB.afkWarnSeconds or 120)
        if idleSec >= threshold then
            DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00HLBG|r: You seem AFK. Please move or you may be removed.")
            -- reset timer to avoid spamming
            lastTime = now - (threshold/2)
        end
    end)
end

-- Slash to open HLBG window even if server AIO command isn't available
SLASH_HLBG1 = "/hlbg"
SlashCmdList["HLBG"] = function(msg)
    EnsurePvPTab(); EnsurePvPHeaderButton()
    HLBG.OpenUI()
    if _G.AIO and _G.AIO.Handle then
        _G.AIO.Handle("HLBG", "Request", "HISTORY", HLBG.UI.History.page or 1, HLBG.UI.History.per or 5, HLBG.UI.History.sortKey or "id", HLBG.UI.History.sortDir or "DESC")
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
        local ok, reg = pcall(function() return _G.AIO.AddHandlers("HLBG", {}) end)
        if not ok or type(reg) ~= "table" then
            local errmsg = tostring(reg or "")
            -- If AddHandlers asserted because the name is already registered, try to attach to any existing global HLBG table
            if errmsg:find("an event is already registered") or errmsg:find("already registered") then
                if type(_G.HLBG) == "table" then
                    local existing = _G.HLBG
                    -- merge our handlers into the existing table only when missing to avoid stomping
                    existing.OpenUI = existing.OpenUI or HLBG.OpenUI
                    existing.History = existing.History or HLBG.History
                    existing.Stats = existing.Stats or HLBG.Stats
                    existing.PONG = existing.PONG or HLBG.PONG
                    existing.DBG = existing.DBG or HLBG.DBG
                    existing.HistoryStr = existing.HistoryStr or HLBG.HistoryStr
                    existing.HISTORY = existing.HISTORY or existing.History
                    existing.STATS = existing.STATS or existing.Stats
                    existing.Warmup = existing.Warmup or HLBG.Warmup
                    existing.QueueStatus = existing.QueueStatus or HLBG.QueueStatus
                    existing.Results = existing.Results or HLBG.Results
                    _G.HLBG = existing; HLBG = existing
                    DEFAULT_CHAT_FRAME:AddMessage("HLBG: AIO name already registered; attached to existing HLBG table")
                    return true
                else
                    DEFAULT_CHAT_FRAME:AddMessage("HLBG: AIO name already registered; handlers may belong to another addon — using fallback")
                    -- Treat as terminal (don't spam retries) but not a success for AIO binding
                    return true
                end
            end
            DEFAULT_CHAT_FRAME:AddMessage("HLBG: AIO.AddHandlers returned unexpected value; retrying")
            return false
        end
    -- preserve some helper functions from the current HLBG table (e.g., SendClientLog)
    local preservedSendLog = (type(HLBG) == "table" and type(HLBG.SendClientLog) == "function") and HLBG.SendClientLog or nil
    reg.OpenUI     = HLBG.OpenUI
        reg.History    = HLBG.History
        reg.Stats      = HLBG.Stats
        reg.Live       = HLBG.Live
        reg.LIVE       = reg.Live
    reg.Warmup     = HLBG.Warmup
    reg.QueueStatus= HLBG.QueueStatus
    reg.Results    = HLBG.Results
        reg.PONG       = HLBG.PONG
        reg.DBG        = HLBG.DBG
        reg.HistoryStr = HLBG.HistoryStr
        reg.HISTORY    = reg.History
        reg.STATS      = reg.Stats
        -- Also register some lowercase/alternate aliases; some AIO builds normalize names differently
        reg.history = reg.History
        reg.historystr = reg.HistoryStr
        reg.stats = reg.Stats
        reg.live = reg.Live
    reg.results = reg.Results
    reg.warmup = reg.Warmup
    reg.queuestatus = reg.QueueStatus
        reg.pong = reg.PONG
    -- reattach preserved helpers to the new reg table if present
    if preservedSendLog then reg.SendClientLog = preservedSendLog end
    _G.HLBG = reg; HLBG = reg
        DEFAULT_CHAT_FRAME:AddMessage("HLBG: Handlers successfully registered (History/Stats/PONG/OpenUI)")
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "HLBG: Registered handlers -> History=%s, Stats=%s, PONG=%s, OpenUI=%s",
            tostring(type(HLBG.History)), tostring(type(HLBG.Stats)), tostring(type(HLBG.PONG)), tostring(type(HLBG.OpenUI))
        ))
        -- Prime first page
        if _G.AIO and _G.AIO.Handle then
            _G.AIO.Handle("HLBG", "Request", "HISTORY", 1, HLBG.UI and HLBG.UI.History and HLBG.UI.History.per or 5, "id", "DESC")
            _G.AIO.Handle("HLBG", "Request", "STATS")
            _G.AIO.Handle("HLBG", "Request", "QUEUE", "STATUS")
        end
        return true
    end

    -- Try immediate register; if it fails, poll for AIO for a few seconds and also listen to ADDON_LOADED
    if not register() then
        DEFAULT_CHAT_FRAME:AddMessage("HLBG: AIO not available yet; starting registration poll")
        local attempts = 0
        local maxAttempts = 20
        local pollT = 0
        local fr = CreateFrame("Frame")
        fr:SetScript("OnUpdate", function(self, elapsed)
            pollT = pollT + (elapsed or 0)
            if pollT < 0.25 then return end
            pollT = 0
            attempts = attempts + 1
            if register() then
                DEFAULT_CHAT_FRAME:AddMessage(string.format("HLBG: registration succeeded after %d attempts", attempts))
                self:SetScript("OnUpdate", nil)
                return
            end
            if attempts >= maxAttempts then
                DEFAULT_CHAT_FRAME:AddMessage("HLBG: registration failed after multiple attempts; handlers not bound")
                self:SetScript("OnUpdate", nil)
            end
        end)
        fr:RegisterEvent("ADDON_LOADED")
        fr:SetScript("OnEvent", function(self, _, name)
            if name == "AIO_Client" or name == "AIO" or name == "RochetAio" then
                DEFAULT_CHAT_FRAME:AddMessage("HLBG: ADDON_LOADED signaled AIO; attempting register")
                if register() then
                    DEFAULT_CHAT_FRAME:AddMessage("HLBG: registration succeeded from ADDON_LOADED")
                    fr:SetScript("OnUpdate", nil); fr:UnregisterAllEvents(); fr:SetScript("OnEvent", nil)
                end
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
    HLBG.UI.Frame:Show(); ShowTab(2)
end

-- Dump last LIVE payload saved to saved-variables for offline inspection
SLASH_HLBGLIVEDUMP1 = "/hlbglivedump"
SlashCmdList["HLBGLIVEDUMP"] = function()
    local dump = HinterlandAffixHUD_LastLive
    if not dump then
        DEFAULT_CHAT_FRAME:AddMessage("HLBG: no saved LIVE payload")
        return
    end
    DEFAULT_CHAT_FRAME:AddMessage(string.format("HLBG: LastLive ts=%s rows=%d", tostring(dump.ts or "?"), tonumber(dump.rows and #dump.rows or 0) or 0))
    if dump.rows and type(dump.rows) == "table" then
        for i,row in ipairs(dump.rows) do
            local name = row.name or row[3] or row[1] or "?"
            local score = row.score or row[5] or row[2] or 0
            DEFAULT_CHAT_FRAME:AddMessage(string.format("%d: %s = %s", i, tostring(name), tostring(score)))
        end
    end
end

-- In-game JSON decoder test runner. Run with /hlbgjsontest to exercise the addon's json_decode implementation
function HLBG.RunJsonDecodeTests()
    if not DEFAULT_CHAT_FRAME or not DEFAULT_CHAT_FRAME.AddMessage then return end

    -- prepare a few expanded tests: unicode escapes, malformed JSON, and a large array
    local largeN = 200
    local parts = {}
    for i=1,largeN do parts[#parts+1] = tostring(i) end
    local largeArrayStr = "[" .. table.concat(parts, ",") .. "]"

    local tests = {
        { name = 'null', input = 'null', expectError = false, expected = nil },
        { name = 'true', input = 'true', expectError = false, expected = true },
        { name = 'false', input = 'false', expectError = false, expected = false },
        { name = 'number', input = '123', expectError = false, expected = 123 },
        { name = 'string', input = '"hello"', expectError = false, expected = 'hello' },
        { name = 'array_small', input = '[1,2,3]', expectError = false, expected = {1,2,3} },
        { name = 'object', input = '{"a":1,"b":"x"}', expectError = false, expected = { a=1, b='x' } },
        { name = 'nested', input = '{"nested":{"k":true}}', expectError = false, expected = { nested = { k = true } } },
        { name = 'unicode_latin1', input = '"caf\\u00e9"', expectError = false, expected = 'café' },
        { name = 'unicode_euro', input = '"price\\u20ac"', expectError = false, expected = 'price€' },
        { name = 'malformed_trailing_comma', input = '{"a":1,}', expectError = true },
        { name = 'malformed_missing_comma', input = '{"a":1 "b":2}', expectError = true },
        { name = 'malformed_unclosed_string', input = '"unclosed', expectError = true },
        { name = 'large_array', input = largeArrayStr, expectError = false, expectedLen = largeN },
    }

    local function deepEqual(a,b)
        if type(a) ~= type(b) then return false end
        if type(a) ~= 'table' then return a == b end
        local ka = {}; for k,_ in pairs(a) do ka[#ka+1]=k end
        local kb = {}; for k,_ in pairs(b) do kb[#kb+1]=k end
        table.sort(ka); table.sort(kb)
        if #ka ~= #kb then return false end
        for i=1,#ka do if ka[i] ~= kb[i] then return false end end
        for k,_ in pairs(a) do if not deepEqual(a[k], b[k]) then return false end end
        return true
    end

    local function shortRepr(v)
        local t = type(v)
        if t == 'nil' then return 'nil' end
        if t == 'string' then return string.format('"%s"', tostring(v)) end
        if t == 'number' or t == 'boolean' then return tostring(v) end
        if t == 'table' then
            if #v and #v > 0 then return string.format('<array len=%d>', #v) end
            return '<object>'
        end
        return '<'..t..'>'
    end

    -- saved variable container for persisted test results
    HinterlandAffixHUD_JsonTestResults = HinterlandAffixHUD_JsonTestResults or {}
    local run = { ts = time(), results = {} }

    local passed = 0
    for i, t in ipairs(tests) do
        local res, err = json_decode(t.input)
        local ok
        if t.expectError then
            ok = (err ~= nil)
        else
            if err ~= nil then ok = false else
                if t.expectedLen then
                    ok = (type(res) == 'table' and #res == t.expectedLen)
                else
                    ok = deepEqual(res, t.expected)
                end
            end
        end
        if ok then passed = passed + 1 end
        local out = shortRepr(res)
        table.insert(run.results, { name = t.name, pass = ok, error = err and tostring(err) or nil, output = out, expected = t.expectedLen and ('len='..t.expectedLen) or (t.expected ~= nil and shortRepr(t.expected) or nil) })
        DEFAULT_CHAT_FRAME:AddMessage(string.format('HLBG JSON Test %d (%s): %s', i, t.name, ok and 'PASS' or ('FAIL'..(err and (': '..tostring(err)) or ''))))
    end

    run.summary = string.format('%d/%d', passed, #tests)
    table.insert(HinterlandAffixHUD_JsonTestResults, 1, run)
    -- keep last 20 runs
    while #HinterlandAffixHUD_JsonTestResults > 20 do table.remove(HinterlandAffixHUD_JsonTestResults) end

    DEFAULT_CHAT_FRAME:AddMessage(string.format('HLBG JSON tests finished: %s passed (saved to HinterlandAffixHUD_JsonTestResults)', run.summary))
end

SLASH_HLBGJSONTEST1 = "/hlbgjsontest"
SlashCmdList["HLBGJSONTEST"] = function() pcall(HLBG.RunJsonDecodeTests) end

-- Print saved JSON test run(s) to chat. Usage: /hlbgjsontestrun [n]
function HLBG.PrintJsonTestRun(n)
    n = tonumber(n) or 1
    if not HinterlandAffixHUD_JsonTestResults or #HinterlandAffixHUD_JsonTestResults == 0 then
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage("HLBG JSON tests: no saved runs found") end
        return
    end
    if n < 1 then n = 1 end
    if n > #HinterlandAffixHUD_JsonTestResults then n = #HinterlandAffixHUD_JsonTestResults end
    local run = HinterlandAffixHUD_JsonTestResults[n]
    if not run then
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage("HLBG JSON tests: run not found") end
        return
    end
    local when = (type(date) == 'function' and date("%Y-%m-%d %H:%M:%S", run.ts)) or tostring(run.ts)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("HLBG JSON Test Run #%d - %s (summary: %s)", n, when, run.summary or ""))
        for i, r in ipairs(run.results or {}) do
            local ok = r.pass and "PASS" or "FAIL"
            local info = string.format("%d) %s: %s", i, r.name or "?", ok)
            if r.error then info = info .. " - error: " .. tostring(r.error) end
            if r.output then info = info .. " - output: " .. tostring(r.output) end
            if r.expected then info = info .. " - expected: " .. tostring(r.expected) end
            DEFAULT_CHAT_FRAME:AddMessage(info)
        end
    end
end

SLASH_HLBGJSONTestrun1 = "/hlbgjsontestrun"
SlashCmdList["HLBGJSONTestrun"] = function(msg) pcall(HLBG.PrintJsonTestRun, (msg and msg:match("%d+")) and tonumber(msg:match("%d+")) or 1) end

