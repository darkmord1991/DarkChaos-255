-- HLBG_HUD_Modern.lua - Modern HUD implementation with fixes and enhancements
local HLBG = _G.HLBG or {}; _G.HLBG = HLBG
-- Initialize HUD settings with defaults (telemetry disabled by default to prevent blinking)
-- migrate to a DC-prefixed saved vars table so addon appears as "DC HLBG Addon"
DCHLBGDB = DCHLBGDB or {}
if DCHLBGDB.hudEnabled == nil then DCHLBGDB.hudEnabled = true end
if DCHLBGDB.hudScale == nil then DCHLBGDB.hudScale = 1.0 end
if DCHLBGDB.hudAlpha == nil then DCHLBGDB.hudAlpha = 0.9 end
if DCHLBGDB.showHudInWarmup == nil then DCHLBGDB.showHudInWarmup = true end
if DCHLBGDB.showHudEverywhere == nil then DCHLBGDB.showHudEverywhere = false end
if DCHLBGDB.enableTelemetry == nil then DCHLBGDB.enableTelemetry = false end -- Disabled by default
HLBG.UI = HLBG.UI or {}
-- Use a single canonical frame name so reloads don't create multiple HUDs
if not HLBG.UI.ModernHUD or not _G['HLBG_ModernHUD'] then
    HLBG.UI.ModernHUD = CreateFrame("Frame", "HLBG_ModernHUD", UIParent)
end
local HUD = HLBG.UI.ModernHUD

-- Shared zone predicate for Hinterlands / HLBG instance.
local function IsInHLBGZone()
    local zone = (type(GetRealZoneText) == "function" and GetRealZoneText()) or ""
    local subzone = (type(GetSubZoneText) == "function" and GetSubZoneText()) or ""

    -- Normalize to lowercase for robust matching (handles "Hinterland Defence" and subzones like "Aerie Peak").
    local z = tostring(zone or ""):lower()
    local sz = tostring(subzone or ""):lower()

    if z == "the hinterlands" then
        return true
    end
    if z:find("hinterland", 1, true) then
        return true
    end
    if sz:find("hinterland", 1, true) or sz:find("azshara crater", 1, true) then
        return true
    end
    return false
end

-- Canonical visibility decision used by both UpdateHUDVisibility and UpdateHUD.
function HLBG.ShouldShowHUD()
    if not HUD or not DCHLBGDB or not DCHLBGDB.hudEnabled then
        return false
    end

    if DCHLBGDB.showHudEverywhere then
        return true
    end

    local inZone = IsInHLBGZone()
    local inBattleground = false

    -- Only consider battlefield activity while we're already in-zone.
    if inZone and type(GetBattlefieldStatus) == "function" then
        for i = 1, 4 do
            local status = GetBattlefieldStatus(i)
            if status == "active" then
                inBattleground = true
                break
            end
        end
    end

    return inZone or inBattleground
end

-- Warmup payload handler (chat/addon messages). Accepts either a plain number of seconds
-- or a string containing a number; updates HUD state without printing to chat.
function HLBG.Warmup(payload)
    local s = tostring(payload or "")
    local n = tonumber(s:match("(%d+)") or s)
    if not n then return end

    HLBG._lastStatus = HLBG._lastStatus or {}
    HLBG._lastStatus.phase = "WARMUP"
    HLBG._lastStatus.DURATION = n
    HLBG._timeLeft = n

    if type(HLBG.UpdateHUD) == 'function' then
        pcall(HLBG.UpdateHUD)
    end
end
-- Simple debug print helper (only prints when devMode is enabled in saved vars)
local function DebugPrint(msg)
    local enabled = (DCHLBGDB and DCHLBGDB.devMode) or HLBG.devMode
    if not enabled then return end
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, msg)
    end
end
-- HUD Setup
HUD:SetSize(400, 120)
HUD:SetPoint("TOP", UIParent, "TOP", 0, -100)
HUD:SetMovable(true)
HUD:EnableMouse(true)
HUD:RegisterForDrag("LeftButton")
HUD:SetFrameStrata("MEDIUM")
HUD:SetFrameLevel(100)
-- Modern backdrop
HUD:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
HUD:SetBackdropColor(0, 0, 0, 0.8)
HUD:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
-- Drag functionality
HUD:SetScript("OnDragStart", function(self)
    if not DCHLBGDB.hudLocked then
        self:StartMoving()
    end
end)
HUD:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    -- Save position
    local point, _, relativePoint, x, y = self:GetPoint()
    DCHLBGDB.hudPosition = {
        point = point,
        relativePoint = relativePoint,
        x = x,
        y = y
    }
end)
-- Title Bar
HUD.titleBar = CreateFrame("Frame", nil, HUD)
HUD.titleBar:SetPoint("TOPLEFT", HUD, "TOPLEFT", 0, 0)
HUD.titleBar:SetPoint("TOPRIGHT", HUD, "TOPRIGHT", 0, 0)
HUD.titleBar:SetHeight(24)
HUD.titleBar:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    tile = true,
    tileSize = 16
})
HUD.titleBar:SetBackdropColor(0.1, 0.3, 0.5, 0.9)
-- Title text
HUD.title = HUD.titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
HUD.title:SetPoint("LEFT", HUD.titleBar, "LEFT", 8, 0)
HUD.title:SetText("DC HLBG Addon")
HUD.title:SetTextColor(1, 1, 1, 1)
-- Phase indicator (Warmup/Live/Ended)
HUD.phaseText = HUD.titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
HUD.phaseText:SetPoint("RIGHT", HUD.titleBar, "RIGHT", -8, 0)
HUD.phaseText:SetText("WARMUP")
HUD.phaseText:SetTextColor(1, 0.8, 0, 1)
-- Main content area
HUD.content = CreateFrame("Frame", nil, HUD)
HUD.content:SetPoint("TOPLEFT", HUD.titleBar, "BOTTOMLEFT", 8, -4)
HUD.content:SetPoint("BOTTOMRIGHT", HUD, "BOTTOMRIGHT", -8, 8)
-- Alliance section
HUD.allianceFrame = CreateFrame("Frame", nil, HUD.content)
HUD.allianceFrame:SetPoint("TOPLEFT", HUD.content, "TOPLEFT", 0, 0)
HUD.allianceFrame:SetSize(180, 35)
-- Alliance icon
HUD.allianceIcon = HUD.allianceFrame:CreateTexture(nil, "ARTWORK")
HUD.allianceIcon:SetSize(28, 28)
HUD.allianceIcon:SetPoint("LEFT", HUD.allianceFrame, "LEFT", 0, 0)
HUD.allianceIcon:SetTexture("Interface\\TargetingFrame\\UI-PVP-Alliance")
-- Alliance text
HUD.allianceText = HUD.allianceFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
HUD.allianceText:SetPoint("LEFT", HUD.allianceIcon, "RIGHT", 4, 0)
HUD.allianceText:SetText("Alliance: 0")
HUD.allianceText:SetTextColor(0.12, 0.56, 1, 1) -- Alliance blue
-- Alliance player count
HUD.alliancePlayers = HUD.allianceFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
HUD.alliancePlayers:SetPoint("TOPLEFT", HUD.allianceText, "BOTTOMLEFT", 0, -2)
HUD.alliancePlayers:SetText("Players: 0")
HUD.alliancePlayers:SetTextColor(0.8, 0.8, 0.8, 1)
-- Horde section
HUD.hordeFrame = CreateFrame("Frame", nil, HUD.content)
HUD.hordeFrame:SetPoint("TOPRIGHT", HUD.content, "TOPRIGHT", 0, 0)
HUD.hordeFrame:SetSize(180, 35)
-- Horde icon
HUD.hordeIcon = HUD.hordeFrame:CreateTexture(nil, "ARTWORK")
HUD.hordeIcon:SetSize(28, 28)
HUD.hordeIcon:SetPoint("RIGHT", HUD.hordeFrame, "RIGHT", 0, 0)
HUD.hordeIcon:SetTexture("Interface\\TargetingFrame\\UI-PVP-Horde")
-- Horde text
HUD.hordeText = HUD.hordeFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
HUD.hordeText:SetPoint("RIGHT", HUD.hordeIcon, "LEFT", -4, 0)
HUD.hordeText:SetText("Horde: 0")
HUD.hordeText:SetTextColor(1, 0, 0, 1) -- Horde red
HUD.hordeText:SetJustifyH("RIGHT")
-- Horde player count
HUD.hordePlayers = HUD.hordeFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
HUD.hordePlayers:SetPoint("TOPRIGHT", HUD.hordeText, "BOTTOMRIGHT", 0, -2)
HUD.hordePlayers:SetText("Players: 0")
HUD.hordePlayers:SetTextColor(0.8, 0.8, 0.8, 1)
HUD.hordePlayers:SetJustifyH("RIGHT")
-- Timer section (center bottom)
HUD.timerFrame = CreateFrame("Frame", nil, HUD.content)
HUD.timerFrame:SetPoint("BOTTOM", HUD.content, "BOTTOM", 0, 0)
HUD.timerFrame:SetSize(200, 40)
HUD.timerText = HUD.timerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
HUD.timerText:SetPoint("TOP", HUD.timerFrame, "TOP", 0, -5)
HUD.timerText:SetText("Time: 0:00")
HUD.timerText:SetTextColor(1, 1, 1, 1)
HUD.timerText:SetJustifyH("CENTER")
-- Affix section
HUD.affixText = HUD.timerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
HUD.affixText:SetPoint("TOP", HUD.timerText, "BOTTOM", 0, -2)
HUD.affixText:SetText("Affix: None")
HUD.affixText:SetTextColor(1, 0.82, 0, 1) -- Gold color
HUD.affixText:SetJustifyH("CENTER")
-- Telemetry section (bottom right corner when enabled)
HUD.telemetryFrame = CreateFrame("Frame", nil, HUD)
HUD.telemetryFrame:SetPoint("BOTTOMRIGHT", HUD, "BOTTOMRIGHT", -4, 4)
HUD.telemetryFrame:SetSize(80, 20)
HUD.pingText = HUD.telemetryFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
HUD.pingText:SetPoint("TOPRIGHT", HUD.telemetryFrame, "TOPRIGHT", 0, 0)
HUD.pingText:SetText("Ping: 0ms")
HUD.pingText:SetTextColor(0.6, 0.8, 0.6, 1)
HUD.pingText:SetJustifyH("RIGHT")
HUD.fpsText = HUD.telemetryFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
HUD.fpsText:SetPoint("BOTTOMRIGHT", HUD.telemetryFrame, "BOTTOMRIGHT", 0, 0)
HUD.fpsText:SetText("FPS: 0")
HUD.fpsText:SetTextColor(0.6, 0.8, 0.6, 1)
HUD.fpsText:SetJustifyH("RIGHT")
-- Format time function
local function formatTime(seconds)
    seconds = tonumber(seconds) or 0
    if seconds < 0 then seconds = 0 end
    if seconds >= 3600 then
        local h = math.floor(seconds / 3600)
        local m = math.floor((seconds % 3600) / 60)
        local s = seconds % 60
        return string.format("%d:%02d:%02d", h, m, s)
    else
        local m = math.floor(seconds / 60)
        local s = seconds % 60
        return string.format("%d:%02d", m, s)
    end
end
-- Update HUD data with throttling to prevent blinking
function HLBG.UpdateModernHUD(data)
    -- Debug: Log function entry (only when devMode enabled)
    DebugPrint(string.format("|cFFFF00FF[UpdateModernHUD]|r FUNCTION CALLED! HUD=%s data=%s", tostring(HUD ~= nil), tostring(data ~= nil)))
    if not HUD then
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[UpdateModernHUD ERROR]|r HUD frame is nil!")
        end
        return
    end
    -- Emergency freeze check - can be enabled via /hlbgdebug freezehud
    if HLBG._freezeHUD then return end
    -- Check if this is manual test data (bypass throttling for test data)
    local isTestData = data and (data.allianceResources == 450 and data.hordeResources == 450 and data.timeLeft == 2243)
    -- Debug: After freeze check
    DebugPrint("|cFFFF00FF[UpdateModernHUD]|r After freeze check, isTestData=" .. tostring(isTestData))
    -- CRITICAL FIX: REMOVED internal throttle - UpdateHUD already throttles!
    -- This was causing the HUD to never update because UpdateHUD throttles at 1s
    -- and UpdateModernHUD was throttling at 2s, so updates were blocked forever
    DebugPrint("|cFFFF00FF[UpdateModernHUD]|r Internal throttle removed, proceeding with update")
    -- allow updates even when HUD hidden so telemetry and internal state stay consistent
    data = data or {}
    DebugPrint("|cFFFF00FF[UpdateModernHUD]|r Data initialized")
    -- Prefer authoritative worldstate when available
    local auth = nil
    if type(HLBG.GetAuthoritativeStatus) == 'function' then
        pcall(function() auth = HLBG.GetAuthoritativeStatus() end)
    end
    if auth and type(auth) == 'table' then
        -- prefer auth values but allow explicit data to override when provided
        for k,v in pairs(auth) do if data[k] == nil then data[k] = v end end
    end
    DebugPrint("|cFFFF00FF[UpdateModernHUD]|r After auth check")
    -- Update resources
    local allianceRes = tonumber(data.allianceResources or data.A or 0) or 0
    local hordeRes = tonumber(data.hordeResources or data.H or 0) or 0
    DebugPrint(string.format("|cFFFFAA00[UpdateModernHUD]|r Input: A=%s H=%s allianceRes=%d hordeRes=%d",
            tostring(data.A), tostring(data.allianceResources), allianceRes, hordeRes))
    -- Clamp resources to sane bounds to avoid occasional spikes from malformed input
    local function clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi else return v end end
    allianceRes = clamp(math.floor(allianceRes), 0, 500)
    hordeRes = clamp(math.floor(hordeRes), 0, 500)
    -- Check HUD text elements exist; report only if devMode enabled
    if not HUD.allianceText or not HUD.hordeText then
        DebugPrint(string.format("|cFFFF0000[UpdateModernHUD ERROR]|r HUD elements missing! allianceText=%s hordeText=%s",
            tostring(HUD.allianceText ~= nil), tostring(HUD.hordeText ~= nil)))
        return
    end
    HUD.allianceText:SetText("Alliance: " .. allianceRes)
    HUD.hordeText:SetText("Horde: " .. hordeRes)
    DebugPrint(string.format("|cFF00FF00[UpdateModernHUD]|r Set text: Alliance=%s Horde=%s",
            HUD.allianceText:GetText(), HUD.hordeText:GetText()))
        -- Update player counts (optional). If not provided, show '-' instead of 0.
        local alliancePlayers = tonumber(data.alliancePlayers or data.APC or "")
        local hordePlayers = tonumber(data.hordePlayers or data.HPC or "")
        HUD.alliancePlayers:SetText("Players: " .. (alliancePlayers ~= nil and tostring(alliancePlayers) or "-"))
        HUD.hordePlayers:SetText("Players: " .. (hordePlayers ~= nil and tostring(hordePlayers) or "-"))
        DebugPrint(string.format("|cFF00FF00[UpdateModernHUD]|r Players: Alliance=%s Horde=%s (APC=%s HPC=%s)",
            tostring(alliancePlayers), tostring(hordePlayers), tostring(data.APC), tostring(data.HPC)))

        local totalPlayers = (alliancePlayers or 0) + (hordePlayers or 0)
    local phase = data.phase or "UNKNOWN"
        local hasPlayerCounts = (alliancePlayers ~= nil) or (hordePlayers ~= nil)
    local suppressActivePhase = hasPlayerCounts and (totalPlayers <= 0) and (phase == "WARMUP" or phase == "BATTLE" or phase == "LIVE")
    if suppressActivePhase then
        phase = "IDLE"
    end
    -- Update timer - CRITICAL FIX: END is epoch timestamp, convert to remaining seconds
    -- Timer sync: Store server END timestamp and sync every 30s to prevent client drift
    if not HLBG._timerSync then
        HLBG._timerSync = { lastServerEnd = 0, lastSyncTime = 0, clientOffset = 0 }
    end
    local currentTime = time()  -- Current epoch time
    local rawTime = tonumber((not suppressActivePhase and (data.END or data.timeLeft)) or 0) or 0

    -- Accept either:
    -- - END as an epoch timestamp (preferred)
    -- - timeLeft as remaining seconds (common from worldstate readers)
    local endTime = rawTime
    if rawTime > 0 and rawTime < 1000000000 then
        endTime = currentTime + rawTime
    end
    -- If we have a new END timestamp from server, resync
    if endTime > 0 and endTime ~= HLBG._timerSync.lastServerEnd then
        HLBG._timerSync.lastServerEnd = endTime
        HLBG._timerSync.lastSyncTime = currentTime
        HLBG._timerSync.clientOffset = 0 -- Reset offset on fresh server data
    end
    -- Calculate remaining time with drift compensation
    local timeLeft = endTime - currentTime + HLBG._timerSync.clientOffset
    -- Periodic sync check (every 30 seconds) - auto-correct drift
    local timeSinceSync = currentTime - HLBG._timerSync.lastSyncTime
    if timeSinceSync >= 30 and endTime > 0 then
        -- Recompute expected vs actual
        local expected = HLBG._timerSync.lastServerEnd - currentTime
        local actual = timeLeft
        local drift = expected - actual
        if math.abs(drift) > 2 then -- More than 2 second drift
            HLBG._timerSync.clientOffset = drift
            timeLeft = expected
            DebugPrint(string.format("|cFFFFAA00[Timer Sync]|r Corrected %+.1fs drift", drift))
        end
        HLBG._timerSync.lastSyncTime = currentTime
    end
    -- Clamp to sane values
    if timeLeft < 0 then timeLeft = 0 end
    local MAX_TIME = 2 * 3600 -- 2 hours maximum
    if timeLeft > MAX_TIME then timeLeft = MAX_TIME end
    if (not HLBG._lastTimerDebug or (currentTime - HLBG._lastTimerDebug) >= 10) then
        DebugPrint(string.format("|cFF00FF00[UpdateModernHUD]|r Timer: END=%d current=%d remaining=%d offset=%+.1f",
            endTime, currentTime, timeLeft, HLBG._timerSync.clientOffset))
        HLBG._lastTimerDebug = currentTime
    end
    HUD.timerText:SetText("Time: " .. formatTime(timeLeft))
    -- Update phase
    if phase == "WARMUP" then
        HUD.phaseText:SetText("WARMUP")
        HUD.phaseText:SetTextColor(1, 0.8, 0, 1) -- Yellow
    elseif phase == "BATTLE" or phase == "LIVE" then
        HUD.phaseText:SetText("BATTLE")
        HUD.phaseText:SetTextColor(1, 0.2, 0.2, 1) -- Red
    elseif phase == "ENDED" then
        HUD.phaseText:SetText("ENDED")
        HUD.phaseText:SetTextColor(0.6, 0.6, 0.6, 1) -- Gray
    else
        HUD.phaseText:SetText("IDLE")
        HUD.phaseText:SetTextColor(0.8, 0.8, 0.8, 1) -- Light gray
    end
    -- Update affix (prefer explicit name, then authoritative affixName, then affixId -> name)
    local affixName = data.affixName or data.affix or nil
    if affixName ~= nil then
        local affixNum = tonumber(affixName)
        if affixNum and type(HLBG.GetAffixName) == "function" then
            local ok, res = pcall(function() return HLBG.GetAffixName(affixNum) end)
            if ok and res then affixName = res end
        end
    end
    if not affixName and data.affixId then
        if type(HLBG.GetAffixName) == "function" then
            local ok, res = pcall(function() return HLBG.GetAffixName(data.affixId) end)
            if ok and res then affixName = res end
        else
            affixName = tostring(data.affixId)
        end
    end
    if not affixName and auth and auth.affixName then affixName = auth.affixName end
    if not affixName then affixName = "None" end
    HUD.affixText:SetText("Affix: " .. affixName)
    -- Update telemetry if enabled
    if DCHLBGDB.enableTelemetry then
        HUD.telemetryFrame:Show()
        -- Get ping
        local _, _, lagHome, lagWorld = GetNetStats()
        local ping = lagWorld or lagHome or 0
        HUD.pingText:SetText(string.format("Ping: %dms", ping))
        -- Color code ping
        if ping < 50 then
            HUD.pingText:SetTextColor(0.2, 1, 0.2, 1) -- Green
        elseif ping < 100 then
            HUD.pingText:SetTextColor(1, 1, 0.2, 1) -- Yellow
        else
            HUD.pingText:SetTextColor(1, 0.2, 0.2, 1) -- Red
        end
        -- Get FPS
        local fps = GetFramerate()
        HUD.fpsText:SetText(string.format("FPS: %d", fps))
        -- Color code FPS
        if fps >= 60 then
            HUD.fpsText:SetTextColor(0.2, 1, 0.2, 1) -- Green
        elseif fps >= 30 then
            HUD.fpsText:SetTextColor(1, 1, 0.2, 1) -- Yellow
        else
            HUD.fpsText:SetTextColor(1, 0.2, 0.2, 1) -- Red
        end
    else
        HUD.telemetryFrame:Hide()
    end
end
-- Apply HUD settings
function HLBG.ApplyHUDSettings()
    if not HUD then return end
    -- Apply scale
    HUD:SetScale(DCHLBGDB.hudScale or 1.0)
    -- Apply alpha
    HUD:SetAlpha(DCHLBGDB.hudAlpha or 0.9)
    -- Apply position
    if DCHLBGDB.hudPosition then
        local pos = DCHLBGDB.hudPosition
        HUD:ClearAllPoints()
        HUD:SetPoint(pos.point or "TOP", UIParent, pos.relativePoint or "TOP", pos.x or 0, pos.y or -100)
    end
    -- Apply font size
    local fontSize = DCHLBGDB.fontSize or "Normal"
    local fontTemplate = "GameFontHighlight"
    if fontSize == "Small" then
        fontTemplate = "GameFontHighlightSmall"
    elseif fontSize == "Large" then
        fontTemplate = "GameFontHighlightLarge"
    end
    -- Update font templates (simplified approach)
    if HUD.allianceText then
        HUD.allianceText:SetFontObject(fontTemplate)
    end
    if HUD.hordeText then
        HUD.hordeText:SetFontObject(fontTemplate)
    end
end
-- Show/Hide HUD based on settings and conditions
function HLBG.UpdateHUDVisibility()
    if not HUD then return end
    -- Check if HUD is enabled
    if not DCHLBGDB.hudEnabled then
        HUD:Hide()
        return
    end
    -- Check location restrictions
    local shouldShow = (type(HLBG.ShouldShowHUD) == 'function') and HLBG.ShouldShowHUD() or false

    -- DEBUG: Log visibility decision (dev only)
    if DCHLBGDB and DCHLBGDB.devMode and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        local zone = GetRealZoneText and GetRealZoneText() or "unknown"
        local sub = GetSubZoneText and GetSubZoneText() or ""
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFFAA00[HUD Visibility]|r Zone=%s Sub=%s shouldShow=%s",
            tostring(zone), tostring(sub), tostring(shouldShow)))
    end
    if shouldShow then
        HUD:Show()
    else
        HUD:Hide()
    end
end
-- Initialize HUD
function HLBG.InitializeModernHUD()
    -- Apply saved settings
    HLBG.ApplyHUDSettings()
    -- Set up event handlers
    HUD:RegisterEvent("PLAYER_ENTERING_WORLD")
    HUD:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    HUD:SetScript("OnEvent", function(self, event, ...)
        if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
            C_Timer.After(1, HLBG.UpdateHUDVisibility)
        end
    end)
    -- Telemetry refresh: prefer ticker over OnUpdate (avoid per-frame overhead)
    if DCHLBGDB.enableTelemetry then
        if C_Timer and type(C_Timer.NewTicker) == 'function' then
            -- Cancel any previous ticker (e.g., /reload)
            if HLBG._telemetryTicker and HLBG._telemetryTicker.Cancel then
                pcall(function() HLBG._telemetryTicker:Cancel() end)
            end
            HLBG._telemetryTicker = C_Timer.NewTicker(5, function()
                if HUD and HUD.IsVisible and HUD:IsVisible() then
                    HLBG.UpdateModernHUD() -- Update telemetry portion
                end
            end)
        else
            -- Fallback: older clients without ticker
            local telemetryFrame = CreateFrame("Frame")
            telemetryFrame:SetScript("OnUpdate", function(self, elapsed)
                self.elapsed = (self.elapsed or 0) + (elapsed or 0)
                if self.elapsed >= 5 then
                    self.elapsed = 0
                    if HUD and HUD.IsVisible and HUD:IsVisible() then
                        HLBG.UpdateModernHUD()
                    end
                end
            end)
        end
    end
    -- Initial visibility check
    HLBG.UpdateHUDVisibility()
    -- Show initial data
    HLBG.UpdateModernHUD()
end
-- Improved worldstate reader to fix 0 values and blinking
function HLBG.ReadWorldstateData()
    local data = {}
    -- Read all worldstates and map known IDs
    if type(GetNumWorldStateUI) == 'function' and type(GetWorldStateUIInfo) == 'function' then
        local numWS = GetNumWorldStateUI()
        for i = 1, numWS do
            local wsType, state, text, icon, dynamicIcon, tooltip, dynamicTooltip, extendedUI, extendedUIState1, extendedUIState2, extendedUIState3 = GetWorldStateUIInfo(i)
            -- Map known worldstate IDs for HLBG (using correct server worldstate IDs)
            if wsType then
                if wsType == 3680 then -- Alliance Resources (WORLD_STATE_BATTLEFIELD_WG_VEHICLE_A)
                    data.allianceResources = tonumber(state) or tonumber(text) or data.allianceResources or 0
                elseif wsType == 3490 then -- Horde Resources (WORLD_STATE_BATTLEFIELD_WG_VEHICLE_H)
                    data.hordeResources = tonumber(state) or tonumber(text) or data.hordeResources or 0
                elseif wsType == 3681 then -- Alliance Players (estimated based on pattern)
                    data.alliancePlayers = tonumber(state) or tonumber(text) or data.alliancePlayers or 0
                elseif wsType == 3491 then -- Horde Players (estimated based on pattern)
                    data.hordePlayers = tonumber(state) or tonumber(text) or data.hordePlayers or 0
                elseif wsType == 3781 then -- Time Left (WORLD_STATE_BATTLEFIELD_WG_CLOCK)
                    -- This is epoch time, convert to remaining seconds
                    local currentTime = time()
                    local endTime = tonumber(state) or tonumber(text) or currentTime
                    data.timeLeft = math.max(0, endTime - currentTime)
                elseif wsType == 4354 then -- Clock text (WORLD_STATE_BATTLEFIELD_WG_CLOCK_TEXTS)
                    -- Alternative time source
                    local currentTime = time()
                    local endTime = tonumber(state) or tonumber(text) or currentTime
                    data.timeLeft = math.max(0, endTime - currentTime)
                elseif wsType == 3695 then -- Custom affix worldstate (if implemented)
                    data.affixId = tonumber(state) or tonumber(text) or data.affixId
                elseif wsType == 3674 then -- WG Active state (can indicate phase)
                    local v = tonumber(state) or tonumber(text)
                    -- Server seeds WG_ACTIVE=0 during wartime (active battle).
                    data.phase = (v == 0 and "BATTLE") or "IDLE"
                end
            end
        end
    end
    -- Fallback to global RES table if worldstates are empty
    if not data.allianceResources and _G.RES then
        data.allianceResources = tonumber(_G.RES.A) or 0
        data.hordeResources = tonumber(_G.RES.H) or 0
    end
    -- Store last known good data to prevent showing 0s
    HLBG._lastKnownData = HLBG._lastKnownData or {}
    for k, v in pairs(data) do
        if v and v ~= 0 and v ~= "" then
            HLBG._lastKnownData[k] = v
        end
    end
    -- Use last known good values if current values are 0/empty
    for k, v in pairs(HLBG._lastKnownData) do
        if not data[k] or data[k] == 0 or data[k] == "" then
            data[k] = v
        end
    end
    return data
end
-- Improved HUD update with worldstate-first approach (no more blinking)
local oldUpdateHUD = HLBG.UpdateHUD
HLBG.UpdateHUD = function()
    local dev = (HLBG and HLBG._devMode) or (DCHLBGDB and DCHLBGDB.devMode)
    if dev then DebugPrint("|cFFAA00FF[UpdateHUD]|r Called") end
    -- Throttle updates to prevent blinking (max once per 1 second - reduced from 3s)
    local now = GetTime()
    HLBG._lastHUDUpdate = HLBG._lastHUDUpdate or 0
    local timeSinceLastUpdate = now - HLBG._lastHUDUpdate
    if timeSinceLastUpdate < 1.0 then
        if dev then
            DebugPrint(string.format("|cFFFFAA00[UpdateHUD THROTTLED]|r Skipped (%.1fs since last update, need 1.0s)", timeSinceLastUpdate))
        end
        return -- Skip update to prevent blinking
    end
    HLBG._lastHUDUpdate = now
    if dev then DebugPrint("|cFF00FFAA[UpdateHUD]|r Proceeding (throttle passed)") end
    -- Primary: Use improved worldstate reader (server-driven, real-time)
    local hudData = HLBG.ReadWorldstateData()
    -- Secondary: Use HLBG._lastStatus as fallback and sync source
    local status = HLBG._lastStatus or {}
    local res = _G.RES or {}
    if dev then
        DebugPrint(string.format("|cFFAA00FF[UpdateHUD DATA]|r hudData.A=%s status.A=%s res.A=%s",
                tostring(hudData.allianceResources), tostring(status.A), tostring(res.A)))
    end
    -- Combine data with worldstates taking priority (server-authoritative)
    local finalData = {
        allianceResources = hudData.allianceResources or status.A or status.allianceResources or res.A or 450,
        hordeResources = hudData.hordeResources or status.H or status.hordeResources or res.H or 450,
        timeLeft = hudData.timeLeft or status.DURATION or status.timeLeft or HLBG._timeLeft or res.END or 1800,
        -- Player counts are optional; do not default to 0.
        alliancePlayers = hudData.alliancePlayers or status.APC or status.APlayers,
        hordePlayers = hudData.hordePlayers or status.HPC or status.HPlayers,
        affixName = hudData.affixName or status.AFF or status.affixName or HLBG._affixText or "None",
        -- Use a phase token UpdateModernHUD understands.
        phase = hudData.phase or status.phase or "BATTLE"
    }
    -- EXTENSIVE DEBUG: Log final combined data
    if dev then
        DebugPrint(string.format("|cFF00FFAA[UpdateHUD FINAL]|r A=%d H=%d Time=%d",
            finalData.allianceResources, finalData.hordeResources, finalData.timeLeft))
    end
    -- Update HLBG._lastStatus to keep status command in sync
    HLBG._lastStatus = HLBG._lastStatus or {}
    HLBG._lastStatus.A = finalData.allianceResources
    HLBG._lastStatus.H = finalData.hordeResources
    HLBG._lastStatus.DURATION = finalData.timeLeft
    if finalData.alliancePlayers ~= nil then HLBG._lastStatus.APC = finalData.alliancePlayers end
    if finalData.hordePlayers ~= nil then HLBG._lastStatus.HPC = finalData.hordePlayers end
    -- Update the HUD with stable, non-blinking data
    if type(HLBG.UpdateModernHUD) == 'function' then
        if dev then DebugPrint("|cFF00FFAA[UpdateHUD]|r Calling UpdateModernHUD with finalData") end
        
        -- ONLY show HUD if we should show it (zone check)
        if HUD then
            local shouldShowHUD = (type(HLBG.ShouldShowHUD) == 'function') and HLBG.ShouldShowHUD() or false
            if shouldShowHUD then
                HUD:Show()
                HUD:SetAlpha(DCHLBGDB.hudAlpha or 0.9)
                if dev then
                    DebugPrint(string.format("|cFFFFAA00[UpdateHUD]|r HUD shown (in Hinterlands) alpha=%.2f", HUD:GetAlpha()))
                end
            else
                HUD:Hide()
                if dev then DebugPrint("|cFFFFAA00[UpdateHUD]|r HUD hidden (not in Hinterlands)") end
                return -- Don't update HUD content if it's hidden
            end
        end
        
        -- Call UpdateModernHUD
        local success, err = pcall(function()
            HLBG.UpdateModernHUD(finalData)
        end)
        if not success then
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFF0000[UpdateHUD ERROR]|r UpdateModernHUD failed: %s", tostring(err)))
            end
        end
    else
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFF0000[UpdateHUD ERROR]|r UpdateModernHUD not found! Type: %s", type(HLBG.UpdateModernHUD)))
        end
    end
end
-- Event handler for worldstate updates (throttled to prevent blinking)
local wsFrame = CreateFrame("Frame")
wsFrame:RegisterEvent("UPDATE_WORLD_STATES")
wsFrame:RegisterEvent("WORLD_STATE_UI_TIMER_UPDATE")
wsFrame:SetScript("OnEvent", function(self, event)
    if event == "UPDATE_WORLD_STATES" or event == "WORLD_STATE_UI_TIMER_UPDATE" then
        -- Don't override test data - check if we're in test mode
        if HLBG._testDataActive then
            return -- Skip worldstate updates when test data is active
        end
        -- Coalesce bursts of worldstate events into one scheduled update.
        if HLBG.UpdateHUD then
            if HLBG._wsHudUpdatePending then return end
            HLBG._wsHudUpdatePending = true
            C_Timer.After(0.15, function()
                HLBG._wsHudUpdatePending = false
                if HLBG and HLBG.UpdateHUD then
                    HLBG.UpdateHUD()
                end
            end)
        end
    end
end)
-- Initialize when addon loads
if HLBG.UI and HLBG.UI.Frame then
    HLBG.InitializeModernHUD()
else
    -- Wait for main UI to load
    local initFrame = CreateFrame("Frame")
    initFrame:RegisterEvent("ADDON_LOADED")
    initFrame:SetScript("OnEvent", function(self, event, addonName)
        if event == "ADDON_LOADED" then
            C_Timer.After(2, function()
                if HLBG.UI then
                    HLBG.InitializeModernHUD()
                    self:UnregisterEvent("ADDON_LOADED")
                end
            end)
        end
    end)
end
_G.HLBG = HLBG
-- Ensure only the modern HUD remains visible: hide legacy HUDs if present
pcall(function()
    if HLBG.UI and HLBG.UI.HUD and HLBG.UI.HUD ~= HLBG.UI.ModernHUD then
        HLBG.UI.HUD:Hide()
        HLBG.UI.HUD:SetScript('OnUpdate', nil)
    end
    -- legacy global reference removed; prefer the modern HUD and explicitly hide known legacy frames below
    local worldstate = _G["WorldStateAlwaysUpFrame"]
    if worldstate and worldstate.Hide then worldstate:Hide() end
    if _G['HLBG_HUD'] and type(_G['HLBG_HUD'].Hide) == 'function' then
        pcall(function() _G['HLBG_HUD']:Hide(); _G['HLBG_HUD']:SetScript('OnUpdate', nil) end)
    end
    if _G['HLBG_AffixChip'] and type(_G['HLBG_AffixChip'].Hide) == 'function' then
        pcall(function() _G['HLBG_AffixChip']:Hide(); _G['HLBG_AffixChip']:SetScript('OnUpdate', nil) end)
    end
    if HLBG.UI and HLBG.UI.Affix and type(HLBG.UI.Affix.Hide) == 'function' then pcall(function() HLBG.UI.Affix:Hide(); HLBG.UI.Affix:SetScript('OnUpdate', nil) end) end
end)
-- Create a reference so HLBG.HUD points to the modern HUD for compatibility
HLBG.HUD = {
    frame = HLBG.UI.ModernHUD,
    enabled = function() return DCHLBGDB and DCHLBGDB.hudEnabled end,
    Update = function() if HLBG.UI.ModernHUD and HLBG.UI.ModernHUD.Update then HLBG.UI.ModernHUD:Update() end end
}
-- Function to manually update HUD with provided data (for testing/debugging) - FIXED
function HLBG.UI.ModernHUD.UpdateWithData(data)
    if not HLBG.UI.ModernHUD or not data then
        DebugPrint("|cFFFF5555HLBG:|r UpdateWithData failed - no HUD or data")
        return
    end
    DebugPrint("|cFF33FF99HLBG Debug:|r UpdateWithData called with: Alliance=" .. (data.allianceResources or 'nil') .. ", Horde=" .. (data.hordeResources or 'nil') .. ", Time=" .. (data.timeLeft or 'nil'))
    -- Update Alliance resources using correct text element
    if HUD.allianceText and data.allianceResources then
        HUD.allianceText:SetText("Alliance: " .. tostring(data.allianceResources))
        DebugPrint("|cFF33FF99HLBG Debug:|r Set Alliance text to: " .. tostring(data.allianceResources))
    end
    -- Update Horde resources using correct text element
    if HUD.hordeText and data.hordeResources then
        HUD.hordeText:SetText("Horde: " .. tostring(data.hordeResources))
        DebugPrint("|cFF33FF99HLBG Debug:|r Set Horde text to: " .. tostring(data.hordeResources))
    end
    -- Update timer using correct text element
    if HUD.timerText and data.timeLeft then
        local minutes = math.floor(data.timeLeft / 60)
        local seconds = data.timeLeft % 60
        HUD.timerText:SetText(string.format("Time: %d:%02d", minutes, seconds))
        DebugPrint("|cFF33FF99HLBG Debug:|r Set timer to: " .. string.format("%d:%02d", minutes, seconds))
    end
    -- Update phase using correct text element
    if HUD.phaseText and data.phase then
        HUD.phaseText:SetText(data.phase)
        DebugPrint("|cFF33FF99HLBG Debug:|r Set phase to: " .. data.phase)
    end
    -- Update affix using correct text element
    if HUD.affixText and data.affixName then
        HUD.affixText:SetText("Affix: " .. data.affixName)
        DebugPrint("|cFF33FF99HLBG Debug:|r Set affix to: " .. data.affixName)
    end
    -- Force HUD visibility and proper settings
    HLBG.UI.ModernHUD:Show()
    HLBG.UI.ModernHUD:SetAlpha(1.0)
    HLBG.UI.ModernHUD:SetFrameStrata("HIGH")
    -- Also call the main update function to ensure consistency
    HLBG.UpdateModernHUD(data)
    DebugPrint("|cFF00FF00HLBG:|r HUD updated with manual data - should be visible now!")
end

