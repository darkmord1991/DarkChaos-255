-- HLBG_HUD_Modern.lua - Modern HUD implementation with fixes and enhancements
local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

-- Initialize HUD settings with defaults
HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
if HinterlandAffixHUDDB.hudEnabled == nil then HinterlandAffixHUDDB.hudEnabled = true end
if HinterlandAffixHUDDB.hudScale == nil then HinterlandAffixHUDDB.hudScale = 1.0 end
if HinterlandAffixHUDDB.hudAlpha == nil then HinterlandAffixHUDDB.hudAlpha = 0.9 end
if HinterlandAffixHUDDB.showHudInWarmup == nil then HinterlandAffixHUDDB.showHudInWarmup = true end
if HinterlandAffixHUDDB.showHudEverywhere == nil then HinterlandAffixHUDDB.showHudEverywhere = false end
if HinterlandAffixHUDDB.enableTelemetry == nil then HinterlandAffixHUDDB.enableTelemetry = true end

HLBG.UI = HLBG.UI or {}
-- Use a single canonical frame name so reloads don't create multiple HUDs
if not HLBG.UI.ModernHUD or not _G['HLBG_ModernHUD'] then
    HLBG.UI.ModernHUD = CreateFrame("Frame", "HLBG_ModernHUD", UIParent)
end
local HUD = HLBG.UI.ModernHUD

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
    if not HinterlandAffixHUDDB.hudLocked then
        self:StartMoving()
    end
end)

HUD:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    -- Save position
    local point, _, relativePoint, x, y = self:GetPoint()
    HinterlandAffixHUDDB.hudPosition = {
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
HUD.title:SetText("Hinterland Battleground")
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

-- Update HUD data
function HLBG.UpdateModernHUD(data)
    if not HUD or not HUD:IsVisible() then return end
    
    data = data or {}
    
    -- Update resources
    local allianceRes = tonumber(data.allianceResources or data.A or 0) or 0
    local hordeRes = tonumber(data.hordeResources or data.H or 0) or 0
    
    HUD.allianceText:SetText("Alliance: " .. allianceRes)
    HUD.hordeText:SetText("Horde: " .. hordeRes)
    
    -- Update player counts
    local alliancePlayers = tonumber(data.alliancePlayers or data.APC or 0) or 0
    local hordePlayers = tonumber(data.hordePlayers or data.HPC or 0) or 0
    
    HUD.alliancePlayers:SetText("Players: " .. alliancePlayers)
    HUD.hordePlayers:SetText("Players: " .. hordePlayers)
    
    -- Update timer
    local timeLeft = tonumber(data.timeLeft or data.END or 0) or 0
    HUD.timerText:SetText("Time: " .. formatTime(timeLeft))
    
    -- Update phase
    local phase = data.phase or "UNKNOWN"
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
    
    -- Update affix
    local affixName = data.affixName or data.affix or "None"
    if type(HLBG.GetAffixName) == "function" and data.affixId then
        affixName = HLBG.GetAffixName(data.affixId)
    end
    HUD.affixText:SetText("Affix: " .. affixName)
    
    -- Update telemetry if enabled
    if HinterlandAffixHUDDB.enableTelemetry then
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
    HUD:SetScale(HinterlandAffixHUDDB.hudScale or 1.0)
    
    -- Apply alpha
    HUD:SetAlpha(HinterlandAffixHUDDB.hudAlpha or 0.9)
    
    -- Apply position
    if HinterlandAffixHUDDB.hudPosition then
        local pos = HinterlandAffixHUDDB.hudPosition
        HUD:ClearAllPoints()
        HUD:SetPoint(pos.point or "TOP", UIParent, pos.relativePoint or "TOP", pos.x or 0, pos.y or -100)
    end
    
    -- Apply font size
    local fontSize = HinterlandAffixHUDDB.fontSize or "Normal"
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
    if not HinterlandAffixHUDDB.hudEnabled then
        HUD:Hide()
        return
    end
    
    -- Check location restrictions
    local shouldShow = false
    
    if HinterlandAffixHUDDB.showHudEverywhere then
        shouldShow = true
    else
        -- Only show in specific zones/instances
        local inHinterlands = false
        local inBattleground = false
        
        -- Check zone
        if type(GetRealZoneText) == "function" then
            local zone = GetRealZoneText()
            inHinterlands = (zone == "The Hinterlands")
        end
        
        -- Check if in battleground instance
        if type(GetBattlefieldStatus) == "function" then
            for i = 1, GetMaxBattlefieldID() do
                local status = GetBattlefieldStatus(i)
                if status == "active" then
                    inBattleground = true
                    break
                end
            end
        end
        
        shouldShow = inHinterlands or inBattleground
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
    
    -- Set up regular telemetry updates
    if HinterlandAffixHUDDB.enableTelemetry then
        local telemetryFrame = CreateFrame("Frame")
        telemetryFrame:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = (self.elapsed or 0) + elapsed
            if self.elapsed >= 1 then -- Update every second
                self.elapsed = 0
                if HUD:IsVisible() then
                    HLBG.UpdateModernHUD() -- Update telemetry portion
                end
            end
        end)
    end
    
    -- Initial visibility check
    HLBG.UpdateHUDVisibility()
    
    -- Show initial data
    HLBG.UpdateModernHUD()
end

-- Legacy compatibility - hook into old HUD update functions
local oldUpdateHUD = HLBG.UpdateHUD
HLBG.UpdateHUD = function()
    -- Call old function for compatibility
    if oldUpdateHUD then
        pcall(oldUpdateHUD)
    end
    
    -- Extract data from legacy RES global
    local res = _G.RES or {}
    local status = HLBG._lastStatus or {}
    
    local data = {
        allianceResources = res.A or 0,
        hordeResources = res.H or 0,
        timeLeft = HLBG._timeLeft or res.END or 0,
        alliancePlayers = status.APlayers or status.APC or 0,
        hordePlayers = status.HPlayers or status.HPC or 0,
        affixName = HLBG._affixText or "None",
        phase = status.phase or "IDLE"
    }
    
    HLBG.UpdateModernHUD(data)
end

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
    end
    local legacy = _G["HinterlandAffixHUD"]
    if legacy and legacy.Hide then legacy:Hide() end
    local worldstate = _G["WorldStateAlwaysUpFrame"]
    if worldstate and worldstate.Hide then worldstate:Hide() end
end)