-- HLBG_Telemetry.lua - Performance monitoring and telemetry system for Hinterland Battleground

local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

-- Initialize telemetry settings
HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
if HinterlandAffixHUDDB.enableTelemetry == nil then HinterlandAffixHUDDB.enableTelemetry = true end
if HinterlandAffixHUDDB.detailedTelemetry == nil then HinterlandAffixHUDDB.detailedTelemetry = false end
if HinterlandAffixHUDDB.keepPerfHistory == nil then HinterlandAffixHUDDB.keepPerfHistory = false end

-- Telemetry data storage
HLBG.Telemetry = {
    -- Current metrics
    currentPing = 0,
    currentFPS = 0,
    currentMemory = 0,
    
    -- Performance history (if enabled)
    pingHistory = {},
    fpsHistory = {},
    memoryHistory = {},
    
    -- Statistics
    stats = {
        avgPing = 0,
        minPing = 999,
        maxPing = 0,
        avgFPS = 0,
        minFPS = 999,
        maxFPS = 0,
        memoryUsage = 0,
        addonMemory = 0,
        
        -- Session data
        sessionStart = 0,
        totalPackets = 0,
        droppedPackets = 0,
        lagSpikes = 0,
        frameDrops = 0
    },
    
    -- Update intervals
    updateInterval = 1.0, -- Update every second
    historyMaxSize = 300, -- Keep 5 minutes of history at 1 second intervals
}

-- Initialize telemetry system
function HLBG.InitializeTelemetry()
    if not HinterlandAffixHUDDB.enableTelemetry then return end
    
    -- Reset session stats
    HLBG.Telemetry.stats.sessionStart = time()
    
    -- Create update frame
    if not HLBG.TelemetryFrame then
        HLBG.TelemetryFrame = CreateFrame("Frame")
        
        -- Performance monitoring update loop
        HLBG.TelemetryFrame:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = (self.elapsed or 0) + elapsed
            
            if self.elapsed >= HLBG.Telemetry.updateInterval then
                self.elapsed = 0
                HLBG.UpdateTelemetryData()
            end
        end)
    end
    
    -- Create telemetry display frame
    if HinterlandAffixHUDDB.detailedTelemetry and not HLBG.TelemetryDisplay then
        HLBG.CreateTelemetryDisplay()
    end
end

-- Update telemetry data
function HLBG.UpdateTelemetryData()
    if not HinterlandAffixHUDDB.enableTelemetry then return end
    
    local telemetry = HLBG.Telemetry
    local stats = telemetry.stats
    
    -- Get network statistics
    local _, _, lagHome, lagWorld = GetNetStats()
    local currentPing = lagWorld or lagHome or 0
    telemetry.currentPing = currentPing
    
    -- Get framerate
    local currentFPS = math.floor(GetFramerate())
    telemetry.currentFPS = currentFPS
    
    -- Get memory usage
    local totalMemory, addonMemory = 0, 0
    if type(GetAddOnMemoryUsage) == "function" then
        UpdateAddOnMemoryUsage()
        
        -- Calculate total addon memory
        for i = 1, GetNumAddOns() do
            totalMemory = totalMemory + GetAddOnMemoryUsage(i)
        end
        
        -- Get our addon's memory usage
        addonMemory = GetAddOnMemoryUsage("HinterlandAffixHUD") or 0
    end
    telemetry.currentMemory = totalMemory
    
    -- Update statistics
    HLBG.UpdateTelemetryStats(currentPing, currentFPS, totalMemory, addonMemory)
    
    -- Store history if enabled
    if HinterlandAffixHUDDB.keepPerfHistory then
        HLBG.StorePerformanceHistory(currentPing, currentFPS, totalMemory)
    end
    
    -- Check for performance issues
    HLBG.CheckPerformanceIssues(currentPing, currentFPS)
    
    -- Update displays
    HLBG.UpdateTelemetryDisplays()
end

-- Update telemetry statistics
function HLBG.UpdateTelemetryStats(ping, fps, memory, addonMemory)
    local stats = HLBG.Telemetry.stats
    local sessionTime = time() - stats.sessionStart
    
    -- Ping statistics
    if ping > 0 then
        stats.minPing = math.min(stats.minPing, ping)
        stats.maxPing = math.max(stats.maxPing, ping)
        
        -- Rolling average for ping
        if stats.avgPing == 0 then
            stats.avgPing = ping
        else
            stats.avgPing = (stats.avgPing * 0.9) + (ping * 0.1)
        end
        
        -- Count lag spikes (>200ms)
        if ping > 200 then
            stats.lagSpikes = stats.lagSpikes + 1
        end
    end
    
    -- FPS statistics
    if fps > 0 then
        stats.minFPS = math.min(stats.minFPS, fps)
        stats.maxFPS = math.max(stats.maxFPS, fps)
        
        -- Rolling average for FPS
        if stats.avgFPS == 0 then
            stats.avgFPS = fps
        else
            stats.avgFPS = (stats.avgFPS * 0.9) + (fps * 0.1)
        end
        
        -- Count frame drops (<30 FPS)
        if fps < 30 then
            stats.frameDrops = stats.frameDrops + 1
        end
    end
    
    -- Memory usage
    stats.memoryUsage = memory
    stats.addonMemory = addonMemory
    
    -- Packet statistics (estimated)
    stats.totalPackets = stats.totalPackets + 1
end

-- Store performance history
function HLBG.StorePerformanceHistory(ping, fps, memory)
    local telemetry = HLBG.Telemetry
    local timestamp = time()
    
    -- Store ping history
    table.insert(telemetry.pingHistory, {timestamp, ping})
    if #telemetry.pingHistory > telemetry.historyMaxSize then
        table.remove(telemetry.pingHistory, 1)
    end
    
    -- Store FPS history
    table.insert(telemetry.fpsHistory, {timestamp, fps})
    if #telemetry.fpsHistory > telemetry.historyMaxSize then
        table.remove(telemetry.fpsHistory, 1)
    end
    
    -- Store memory history
    table.insert(telemetry.memoryHistory, {timestamp, memory})
    if #telemetry.memoryHistory > telemetry.historyMaxSize then
        table.remove(telemetry.memoryHistory, 1)
    end
end

-- Check for performance issues and alert if necessary
function HLBG.CheckPerformanceIssues(ping, fps)
    -- High ping warning
    if ping > 300 and HinterlandAffixHUDDB.enableAlerts then
        HLBG.ShowPerformanceAlert("HIGH_PING", string.format("High ping detected: %dms", ping))
    end
    
    -- Low FPS warning
    if fps < 20 and HinterlandAffixHUDDB.enableAlerts then
        HLBG.ShowPerformanceAlert("LOW_FPS", string.format("Low FPS detected: %d", fps))
    end
    
    -- Memory usage warning (>100MB total addons)
    local memory = HLBG.Telemetry.currentMemory
    if memory > 102400 and HinterlandAffixHUDDB.enableAlerts then -- 100MB in KB
        HLBG.ShowPerformanceAlert("HIGH_MEMORY", string.format("High addon memory usage: %.1fMB", memory / 1024))
    end
end

-- Show performance alert
function HLBG.ShowPerformanceAlert(alertType, message)
    -- Throttle alerts (don't spam)
    if not HLBG.lastAlert then HLBG.lastAlert = {} end
    local now = time()
    
    if HLBG.lastAlert[alertType] and (now - HLBG.lastAlert[alertType]) < 30 then
        return -- Don't show same alert more than once per 30 seconds
    end
    
    HLBG.lastAlert[alertType] = now
    
    -- Show in chat if enabled
    if HinterlandAffixHUDDB.chatMessages then
        print("|cFFFF6600[HLBG Performance]|r " .. message)
    end
    
    -- Play warning sound if enabled
    if HinterlandAffixHUDDB.enableAlerts and type(PlaySound) == "function" then
        PlaySound("RaidWarning", "Master")
    end
    
    -- Flash screen if enabled
    if HinterlandAffixHUDDB.flashScreen then
        HLBG.FlashScreen(1, 0.5, 0, 0.3) -- Orange flash
    end
end

-- Flash screen effect
function HLBG.FlashScreen(r, g, b, alpha)
    local flash = UIParent:CreateTexture(nil, "FULLSCREEN_DIALOG")
    flash:SetAllPoints(UIParent)
    flash:SetTexture("Interface/FullScreenTextures/LowHealth")
    flash:SetVertexColor(r or 1, g or 0, b or 0, alpha or 0.3)
    
    -- Fade out animation
    local fadeFrame = CreateFrame("Frame")
    local elapsed = 0
    local duration = 1.0
    
    fadeFrame:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        local progress = elapsed / duration
        
        if progress >= 1 then
            flash:SetAlpha(0)
            flash:Hide()
            self:SetScript("OnUpdate", nil)
        else
            flash:SetAlpha((alpha or 0.3) * (1 - progress))
        end
    end)
end

-- Create detailed telemetry display window
function HLBG.CreateTelemetryDisplay()
    if HLBG.TelemetryDisplay then return end
    
    -- Main frame
    HLBG.TelemetryDisplay = CreateFrame("Frame", "HLBG_TelemetryDisplay", UIParent)
    local display = HLBG.TelemetryDisplay
    
    display:SetSize(300, 250)
    display:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -100)
    display:SetMovable(true)
    display:EnableMouse(true)
    display:RegisterForDrag("LeftButton")
    display:SetFrameStrata("HIGH")
    display:SetClampedToScreen(true)
    
    -- Background
    display:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltios/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    display:SetBackdropColor(0, 0, 0, 0.9)
    display:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    
    -- Drag functionality
    display:SetScript("OnDragStart", function(self) self:StartMoving() end)
    display:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    
    -- Title
    display.title = display:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    display.title:SetPoint("TOP", display, "TOP", 0, -10)
    display.title:SetText("Performance Monitor")
    display.title:SetTextColor(1, 1, 0, 1)
    
    -- Close button
    display.closeButton = CreateFrame("Button", nil, display, "UIPanelCloseButton")
    display.closeButton:SetPoint("TOPRIGHT", display, "TOPRIGHT", 2, 2)
    display.closeButton:SetScript("OnClick", function() display:Hide() end)
    
    -- Content area
    local yOffset = -35
    local lineHeight = 15
    
    -- Current metrics
    display.pingLabel = display:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    display.pingLabel:SetPoint("TOPLEFT", display, "TOPLEFT", 10, yOffset)
    display.pingLabel:SetText("Ping:")
    
    display.pingValue = display:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    display.pingValue:SetPoint("TOPRIGHT", display, "TOPRIGHT", -10, yOffset)
    display.pingValue:SetText("0ms")
    
    yOffset = yOffset - lineHeight
    display.fpsLabel = display:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    display.fpsLabel:SetPoint("TOPLEFT", display, "TOPLEFT", 10, yOffset)
    display.fpsLabel:SetText("FPS:")
    
    display.fpsValue = display:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    display.fpsValue:SetPoint("TOPRIGHT", display, "TOPRIGHT", -10, yOffset)
    display.fpsValue:SetText("0")
    
    yOffset = yOffset - lineHeight
    display.memoryLabel = display:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    display.memoryLabel:SetPoint("TOPLEFT", display, "TOPLEFT", 10, yOffset)
    display.memoryLabel:SetText("Memory:")
    
    display.memoryValue = display:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    display.memoryValue:SetPoint("TOPRIGHT", display, "TOPRIGHT", -10, yOffset)
    display.memoryValue:SetText("0MB")
    
    -- Separator
    yOffset = yOffset - 20
    display.separator = display:CreateTexture(nil, "ARTWORK")
    display.separator:SetPoint("TOPLEFT", display, "TOPLEFT", 10, yOffset)
    display.separator:SetPoint("TOPRIGHT", display, "TOPRIGHT", -10, yOffset)
    display.separator:SetHeight(1)
    display.separator:SetTexture("Interface/Tooltips/UI-Tooltip-Border")
    display.separator:SetVertexColor(0.5, 0.5, 0.5, 1)
    
    -- Statistics
    yOffset = yOffset - 15
    display.statsTitle = display:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    display.statsTitle:SetPoint("TOPLEFT", display, "TOPLEFT", 10, yOffset)
    display.statsTitle:SetText("Session Statistics")
    display.statsTitle:SetTextColor(1, 1, 0, 1)
    
    yOffset = yOffset - lineHeight
    display.avgPingLabel = display:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    display.avgPingLabel:SetPoint("TOPLEFT", display, "TOPLEFT", 15, yOffset)
    display.avgPingLabel:SetText("Avg Ping:")
    
    display.avgPingValue = display:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    display.avgPingValue:SetPoint("TOPRIGHT", display, "TOPRIGHT", -10, yOffset)
    display.avgPingValue:SetText("0ms")
    
    yOffset = yOffset - 12
    display.avgFPSLabel = display:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    display.avgFPSLabel:SetPoint("TOPLEFT", display, "TOPLEFT", 15, yOffset)
    display.avgFPSLabel:SetText("Avg FPS:")
    
    display.avgFPSValue = display:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    display.avgFPSValue:SetPoint("TOPRIGHT", display, "TOPRIGHT", -10, yOffset)
    display.avgFPSValue:SetText("0")
    
    yOffset = yOffset - 12
    display.lagSpikesLabel = display:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    display.lagSpikesLabel:SetPoint("TOPLEFT", display, "TOPLEFT", 15, yOffset)
    display.lagSpikesLabel:SetText("Lag Spikes:")
    
    display.lagSpikesValue = display:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    display.lagSpikesValue:SetPoint("TOPRIGHT", display, "TOPRIGHT", -10, yOffset)
    display.lagSpikesValue:SetText("0")
    
    yOffset = yOffset - 12
    display.frameDropsLabel = display:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    display.frameDropsLabel:SetPoint("TOPLEFT", display, "TOPLEFT", 15, yOffset)
    display.frameDropsLabel:SetText("Frame Drops:")
    
    display.frameDropsValue = display:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    display.frameDropsValue:SetPoint("TOPRIGHT", display, "TOPRIGHT", -10, yOffset)
    display.frameDropsValue:SetText("0")
    
    -- Reset button
    yOffset = yOffset - 20
    display.resetButton = CreateFrame("Button", nil, display, "UIPanelButtonTemplate")
    display.resetButton:SetPoint("BOTTOM", display, "BOTTOM", 0, 10)
    display.resetButton:SetSize(80, 20)
    display.resetButton:SetText("Reset")
    display.resetButton:SetScript("OnClick", function()
        HLBG.ResetTelemetryStats()
    end)
    
    -- Initially hidden
    display:Hide()
end

-- Update telemetry displays
function HLBG.UpdateTelemetryDisplays()
    local telemetry = HLBG.Telemetry
    local stats = telemetry.stats
    
    -- Update detailed display if visible
    if HLBG.TelemetryDisplay and HLBG.TelemetryDisplay:IsVisible() then
        local display = HLBG.TelemetryDisplay
        
        -- Current metrics
        display.pingValue:SetText(string.format("%dms", telemetry.currentPing))
        display.fpsValue:SetText(string.format("%d", telemetry.currentFPS))
        display.memoryValue:SetText(string.format("%.1fMB", telemetry.currentMemory / 1024))
        
        -- Color code based on performance
        -- Ping colors
        if telemetry.currentPing < 50 then
            display.pingValue:SetTextColor(0.2, 1, 0.2, 1) -- Green
        elseif telemetry.currentPing < 100 then
            display.pingValue:SetTextColor(1, 1, 0.2, 1) -- Yellow
        else
            display.pingValue:SetTextColor(1, 0.2, 0.2, 1) -- Red
        end
        
        -- FPS colors
        if telemetry.currentFPS >= 60 then
            display.fpsValue:SetTextColor(0.2, 1, 0.2, 1) -- Green
        elseif telemetry.currentFPS >= 30 then
            display.fpsValue:SetTextColor(1, 1, 0.2, 1) -- Yellow
        else
            display.fpsValue:SetTextColor(1, 0.2, 0.2, 1) -- Red
        end
        
        -- Statistics
        display.avgPingValue:SetText(string.format("%dms", math.floor(stats.avgPing)))
        display.avgFPSValue:SetText(string.format("%d", math.floor(stats.avgFPS)))
        display.lagSpikesValue:SetText(tostring(stats.lagSpikes))
        display.frameDropsValue:SetText(tostring(stats.frameDrops))
    end
end

-- Show/Hide telemetry display
function HLBG.ToggleTelemetryDisplay()
    if not HLBG.TelemetryDisplay then
        HLBG.CreateTelemetryDisplay()
    end
    
    if HLBG.TelemetryDisplay:IsVisible() then
        HLBG.TelemetryDisplay:Hide()
    else
        HLBG.TelemetryDisplay:Show()
    end
end

-- Reset telemetry statistics
function HLBG.ResetTelemetryStats()
    local stats = HLBG.Telemetry.stats
    
    stats.avgPing = 0
    stats.minPing = 999
    stats.maxPing = 0
    stats.avgFPS = 0
    stats.minFPS = 999
    stats.maxFPS = 0
    stats.sessionStart = time()
    stats.totalPackets = 0
    stats.droppedPackets = 0
    stats.lagSpikes = 0
    stats.frameDrops = 0
    
    -- Clear history
    HLBG.Telemetry.pingHistory = {}
    HLBG.Telemetry.fpsHistory = {}
    HLBG.Telemetry.memoryHistory = {}
    
    print("|cFF00FF00[HLBG]|r Telemetry statistics reset.")
end

-- Get telemetry summary for debugging
function HLBG.GetTelemetrySummary()
    local telemetry = HLBG.Telemetry
    local stats = telemetry.stats
    local sessionTime = time() - stats.sessionStart
    
    local summary = {
        current = {
            ping = telemetry.currentPing,
            fps = telemetry.currentFPS,
            memory = telemetry.currentMemory
        },
        session = {
            duration = sessionTime,
            avgPing = stats.avgPing,
            minPing = stats.minPing,
            maxPing = stats.maxPing,
            avgFPS = stats.avgFPS,
            minFPS = stats.minFPS,
            maxFPS = stats.maxFPS,
            lagSpikes = stats.lagSpikes,
            frameDrops = stats.frameDrops,
            memoryUsage = stats.memoryUsage,
            addonMemory = stats.addonMemory
        }
    }
    
    return summary
end

-- Slash command for telemetry
SLASH_HLBGTELEMETRY1 = "/hlbgperf"
SlashCmdList["HLBGTELEMETRY"] = function(msg)
    local cmd = msg:lower():trim()
    
    if cmd == "show" or cmd == "" then
        HLBG.ToggleTelemetryDisplay()
    elseif cmd == "reset" then
        HLBG.ResetTelemetryStats()
    elseif cmd == "summary" then
        local summary = HLBG.GetTelemetrySummary()
        print("|cFF00FF00[HLBG Performance Summary]|r")
        print(string.format("Current: %dms ping, %d FPS, %.1fMB memory", 
              summary.current.ping, summary.current.fps, summary.current.memory / 1024))
        print(string.format("Session: %.0fs, Avg %dms/%.0f FPS, %d spikes, %d drops",
              summary.session.duration, summary.session.avgPing, summary.session.avgFPS,
              summary.session.lagSpikes, summary.session.frameDrops))
    else
        print("|cFF00FF00[HLBG Performance]|r Commands:")
        print("  /hlbgperf show - Toggle performance display")
        print("  /hlbgperf reset - Reset statistics")
        print("  /hlbgperf summary - Show performance summary")
    end
end

-- Initialize telemetry when addon loads
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

initFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "HinterlandAffixHUD" or addonName:match("HLBG") then
            C_Timer.After(1, HLBG.InitializeTelemetry)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(2, function()
            if HinterlandAffixHUDDB.enableTelemetry then
                HLBG.InitializeTelemetry()
            end
        end)
    end
end)

_G.HLBG = HLBG