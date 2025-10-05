-- HLBG_Integration_Enhanced.lua - Enhanced integration and fixes for all HLBG components

local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

-- ===== ADDON INITIALIZATION =====
local function InitializeEnhancedHLBG()
    print("|cFF00EEFF[HLBG Enhanced]|r Loading enhanced features...")
    
    -- Initialize settings with defaults
    HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
    
    -- HUD Settings
    if HinterlandAffixHUDDB.hudEnabled == nil then HinterlandAffixHUDDB.hudEnabled = true end
    if HinterlandAffixHUDDB.hudScale == nil then HinterlandAffixHUDDB.hudScale = 1.0 end
    if HinterlandAffixHUDDB.hudAlpha == nil then HinterlandAffixHUDDB.hudAlpha = 0.9 end
    if HinterlandAffixHUDDB.showHudEverywhere == nil then HinterlandAffixHUDDB.showHudEverywhere = false end
    if HinterlandAffixHUDDB.showHudInWarmup == nil then HinterlandAffixHUDDB.showHudInWarmup = true end
    if HinterlandAffixHUDDB.hudLocked == nil then HinterlandAffixHUDDB.hudLocked = false end
    if HinterlandAffixHUDDB.fontSize == nil then HinterlandAffixHUDDB.fontSize = "Normal" end
    
    -- Alert Settings
    if HinterlandAffixHUDDB.enableAlerts == nil then HinterlandAffixHUDDB.enableAlerts = true end
    if HinterlandAffixHUDDB.queuePopSound == nil then HinterlandAffixHUDDB.queuePopSound = true end
    if HinterlandAffixHUDDB.matchStartSound == nil then HinterlandAffixHUDDB.matchStartSound = true end
    if HinterlandAffixHUDDB.endGameSound == nil then HinterlandAffixHUDDB.endGameSound = true end
    if HinterlandAffixHUDDB.chatMessages == nil then HinterlandAffixHUDDB.chatMessages = true end
    if HinterlandAffixHUDDB.flashScreen == nil then HinterlandAffixHUDDB.flashScreen = false end
    
    -- Telemetry Settings
    if HinterlandAffixHUDDB.enableTelemetry == nil then HinterlandAffixHUDDB.enableTelemetry = true end
    if HinterlandAffixHUDDB.detailedTelemetry == nil then HinterlandAffixHUDDB.detailedTelemetry = false end
    if HinterlandAffixHUDDB.keepPerfHistory == nil then HinterlandAffixHUDDB.keepPerfHistory = false end
    
    -- Scoreboard Settings
    if HinterlandAffixHUDDB.modernScoreboard == nil then HinterlandAffixHUDDB.modernScoreboard = true end
    if HinterlandAffixHUDDB.compactScoreboard == nil then HinterlandAffixHUDDB.compactScoreboard = false end
    if HinterlandAffixHUDDB.useClassColors == nil then HinterlandAffixHUDDB.useClassColors = true end
    if HinterlandAffixHUDDB.autoSortScoreboard == nil then HinterlandAffixHUDDB.autoSortScoreboard = true end
    if HinterlandAffixHUDDB.scoreboardUpdateRate == nil then HinterlandAffixHUDDB.scoreboardUpdateRate = 3 end
    
    -- Advanced Settings
    if HinterlandAffixHUDDB.devMode == nil then HinterlandAffixHUDDB.devMode = false end
    if HinterlandAffixHUDDB.debugLevel == nil then HinterlandAffixHUDDB.debugLevel = 0 end
    if HinterlandAffixHUDDB.autoJoinQueue == nil then HinterlandAffixHUDDB.autoJoinQueue = false end
    if HinterlandAffixHUDDB.autoTeleport == nil then HinterlandAffixHUDDB.autoTeleport = true end
    if HinterlandAffixHUDDB.allowDataCollection == nil then HinterlandAffixHUDDB.allowDataCollection = false end
    
    print("|cFF00EEFF[HLBG Enhanced]|r Settings initialized with defaults")
end

-- ===== HUD VISIBILITY FIX =====
function HLBG.FixHUDVisibility()
    -- This fixes the main issue where HUD was not showing
    if not HinterlandAffixHUDDB.hudEnabled then return end
    
    -- Ensure modern HUD is visible and old HUD is hidden
    if HLBG.UI and HLBG.UI.ModernHUD then
        HLBG.UI.ModernHUD:Show()
        print("|cFF00EEFF[HLBG Enhanced]|r Modern HUD is now visible")
        
        -- Apply saved settings
        if HLBG.ApplyHUDSettings then
            HLBG.ApplyHUDSettings()
        end
    end
    
    -- Hide old HUD to prevent conflicts
    if HLBG.UI and HLBG.UI.HUD and HLBG.UI.HUD ~= HLBG.UI.ModernHUD then
        HLBG.UI.HUD:Hide()
    end
    
    -- Hide legacy addon frame if it exists
    local legacyFrame = _G["HinterlandAffixHUD"]
    if legacyFrame and legacyFrame.Hide then
        legacyFrame:Hide()
    end
end

-- ===== ENHANCED TAB SYSTEM =====
function HLBG.SetupEnhancedTabs()
    if not HLBG.UI or not HLBG.UI.Frame then return end
    
    -- Ensure we have all the enhanced tabs
    local tabConfig = {
        {1, "Live", HLBG.ModernLive or HLBG.Live},
        {2, "History", HLBG.History},
        {3, "Stats", HLBG.Stats},
        {4, "Results", HLBG.Results},
        {5, "Affixes", HLBG.Affixes},
        {6, "Settings", HLBG.ShowEnhancedSettings or HLBG.ShowSettings},
        {7, "Info", HLBG.ShowEnhancedInfo or HLBG.ShowInfo}
    }
    
    -- Create tabs if they don't exist
    HLBG.UI.Tabs = HLBG.UI.Tabs or {}
    
    for _, config in ipairs(tabConfig) do
        local id, name, handler = config[1], config[2], config[3]
        
        if not HLBG.UI.Tabs[id] then
            local tab = CreateFrame("Button", HLBG.UI.Frame:GetName().."Tab"..id, HLBG.UI.Frame, "OptionsFrameTabButtonTemplate")
            tab:SetText(name)
            tab:SetID(id)
            
            if id == 1 then
                tab:SetPoint("BOTTOMLEFT", HLBG.UI.Frame, "BOTTOMLEFT", 5, -30)
            else
                tab:SetPoint("LEFT", HLBG.UI.Tabs[id-1], "RIGHT", -15, 0)
            end
            
            HLBG.UI.Tabs[id] = tab
        end
        
        -- Register handler
        if handler and type(handler) == "function" then
            HLBG._tabHandlers = HLBG._tabHandlers or {}
            HLBG._tabHandlers[id] = handler
        end
    end
    
    print("|cFF00EEFF[HLBG Enhanced]|r Enhanced tab system initialized")
end

-- ===== IMPROVED UPDATE SYSTEM =====
function HLBG.EnhancedUpdate()
    -- This replaces the old update system with better data handling
    
    -- Update HUD with current data
    if HLBG.UpdateModernHUD and HinterlandAffixHUDDB.hudEnabled then
        local data = {
            allianceResources = (_G.RES and _G.RES.A) or 0,
            hordeResources = (_G.RES and _G.RES.H) or 0,
            timeLeft = HLBG._timeLeft or (_G.RES and _G.RES.END) or 0,
            alliancePlayers = (HLBG._lastStatus and HLBG._lastStatus.APlayers) or 0,
            hordePlayers = (HLBG._lastStatus and HLBG._lastStatus.HPlayers) or 0,
            affixName = HLBG._affixText or "None",
            affixId = (HLBG._lastStatus and HLBG._lastStatus.affix) or 0,
            phase = (HLBG._lastStatus and HLBG._lastStatus.phase) or "IDLE"
        }
        
        HLBG.UpdateModernHUD(data)
    end
    
    -- Update live scoreboard if modern version is enabled
    if HLBG.ModernLive and HinterlandAffixHUDDB.modernScoreboard then
        -- Let the modern system handle its own updates
        if HLBG.UI.Live and HLBG.UI.Live.lastRows then
            HLBG.ProcessPlayerData(HLBG.UI.Live.lastRows)
        end
    end
end

-- ===== EVENT HANDLERS =====
function HLBG.HandleBattlePhaseChange(newPhase)
    -- Handle different battle phases
    if HinterlandAffixHUDDB.chatMessages then
        if newPhase == "WARMUP" then
            print("|cFF00EEFF[HLBG]|r Warmup phase started. Prepare for battle!")
            
            -- Show HUD during warmup if enabled
            if HinterlandAffixHUDDB.showHudInWarmup then
                HLBG.FixHUDVisibility()
            end
            
        elseif newPhase == "BATTLE" or newPhase == "LIVE" then
            print("|cFF00EEFF[HLBG]|r Battle phase started! Good luck!")
            
            -- Play sound if enabled
            if HinterlandAffixHUDDB.matchStartSound and HinterlandAffixHUDDB.enableAlerts then
                if type(PlaySound) == "function" then
                    PlaySound("PVPTHROUGHQUEUE", "Master")
                end
            end
            
            -- Flash screen if enabled
            if HinterlandAffixHUDDB.flashScreen then
                HLBG.FlashScreen(0, 1, 0, 0.3) -- Green flash for battle start
            end
            
            -- Ensure HUD is visible during battle
            HLBG.FixHUDVisibility()
            
        elseif newPhase == "ENDED" then
            print("|cFF00EEFF[HLBG]|r Battle ended!")
            
            -- Play end game sound if enabled
            if HinterlandAffixHUDDB.endGameSound and HinterlandAffixHUDDB.enableAlerts then
                if type(PlaySound) == "function" then
                    PlaySound("PVPVICTORY", "Master")
                end
            end
        end
    end
    
    -- Update phase tracking
    HLBG._currentPhase = newPhase
    
    -- Refresh displays
    HLBG.EnhancedUpdate()
end

function HLBG.HandleQueuePop()
    -- Handle queue pop events
    if HinterlandAffixHUDDB.chatMessages then
        print("|cFF00EEFF[HLBG]|r Queue popped! Battle is starting soon.")
    end
    
    -- Play queue pop sound if enabled
    if HinterlandAffixHUDDB.queuePopSound and HinterlandAffixHUDDB.enableAlerts then
        if type(PlaySound) == "function" then
            PlaySound("ReadyCheck", "Master")
        end
    end
    
    -- Auto-teleport if enabled
    if HinterlandAffixHUDDB.autoTeleport then
        -- This would normally send a command to the server
        if type(SendChatMessage) == "function" then
            SendChatMessage(".hlbg teleport", "GUILD") -- Or appropriate channel
        end
    end
end

-- ===== SLASH COMMAND ENHANCEMENTS =====
SLASH_HLBGENHANCED1 = "/hlbg"
SLASH_HLBGENHANCED2 = "/hinterlandbg"
SlashCmdList["HLBGENHANCED"] = function(msg)
    local cmd = msg:lower():trim()
    
    if cmd == "hud" then
        HLBG.FixHUDVisibility()
        print("|cFF00EEFF[HLBG]|r HUD visibility refreshed")
        
    elseif cmd == "settings" or cmd == "config" then
        if HLBG.ShowEnhancedSettings then
            HLBG.ShowEnhancedSettings()
        elseif HLBG.ShowSettings then
            HLBG.ShowSettings()
        else
            print("|cFF00EEFF[HLBG]|r Settings not available")
        end
        
    elseif cmd == "reset" then
        HinterlandAffixHUDDB = {}
        InitializeEnhancedHLBG()
        HLBG.FixHUDVisibility()
        print("|cFF00EEFF[HLBG]|r All settings reset to defaults")
        
    elseif cmd == "reload" then
        ReloadUI()
        
    elseif cmd == "debug" then
        HinterlandAffixHUDDB.devMode = not HinterlandAffixHUDDB.devMode
        HLBG._devMode = HinterlandAffixHUDDB.devMode
        print("|cFF00EEFF[HLBG]|r Debug mode: " .. (HinterlandAffixHUDDB.devMode and "ON" or "OFF"))
        
    elseif cmd == "status" then
        print("|cFF00EEFF[HLBG Enhanced Status]|r")
        print("HUD Enabled: " .. (HinterlandAffixHUDDB.hudEnabled and "YES" or "NO"))
        print("Modern Scoreboard: " .. (HinterlandAffixHUDDB.modernScoreboard and "YES" or "NO"))
        print("Telemetry: " .. (HinterlandAffixHUDDB.enableTelemetry and "YES" or "NO"))
        print("Current Phase: " .. (HLBG._currentPhase or "UNKNOWN"))
        print("Version: " .. (HLAFFIXHUD_VERSION or "2.0.0"))
        
    elseif cmd == "" then
        -- Show main UI
        if HLBG.UI and HLBG.UI.Frame then
            HLBG.UI.Frame:Show()
        else
            print("|cFF00EEFF[HLBG]|r Main UI not available")
        end
        
    else
        print("|cFF00EEFF[HLBG Enhanced Commands]|r")
        print("/hlbg - Show main interface")
        print("/hlbg hud - Refresh HUD visibility")
        print("/hlbg settings - Open settings panel")
        print("/hlbg reset - Reset all settings")
        print("/hlbg status - Show current status")
        print("/hlbg debug - Toggle debug mode")
        print("/hlbg reload - Reload UI")
    end
end

-- ===== INITIALIZATION SEQUENCE =====
local function PerformEnhancedInit()
    -- Step 1: Initialize settings
    InitializeEnhancedHLBG()
    
    -- Step 2: Set up enhanced components
    C_Timer.After(0.5, function()
        HLBG.SetupEnhancedTabs()
    end)
    
    -- Step 3: Fix HUD visibility
    C_Timer.After(1.0, function()
        HLBG.FixHUDVisibility()
    end)
    
    -- Step 4: Initialize telemetry
    C_Timer.After(1.5, function()
        if HinterlandAffixHUDDB.enableTelemetry and HLBG.InitializeTelemetry then
            HLBG.InitializeTelemetry()
        end
    end)
    
    -- Step 5: Set up update system
    C_Timer.After(2.0, function()
        -- Create enhanced update loop
        local updateFrame = CreateFrame("Frame")
        updateFrame:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = (self.elapsed or 0) + elapsed
            
            -- Update every 2 seconds for performance
            if self.elapsed >= 2.0 then
                self.elapsed = 0
                HLBG.EnhancedUpdate()
            end
        end)
        
        print("|cFF00EEFF[HLBG Enhanced]|r Initialization complete!")
    end)
end

-- ===== EVENT REGISTRATION =====
local enhancedFrame = CreateFrame("Frame")
enhancedFrame:RegisterEvent("ADDON_LOADED")
enhancedFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
enhancedFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

enhancedFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "HinterlandAffixHUD" or addonName:match("HLBG") then
            PerformEnhancedInit()
        end
        
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(3, function()
            HLBG.FixHUDVisibility()
            
            if HinterlandAffixHUDDB.chatMessages then
                print("|cFF00EEFF[HLBG Enhanced]|r Enhanced features loaded! Type /hlbg for commands.")
            end
        end)
        
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        C_Timer.After(1, function()
            if HLBG.UpdateHUDVisibility then
                HLBG.UpdateHUDVisibility()
            else
                HLBG.FixHUDVisibility()
            end
        end)
    end
end)

-- ===== LEGACY COMPATIBILITY =====
-- Hook into existing update functions for compatibility
if HLBG.UpdateHUD and not HLBG._originalUpdateHUD then
    HLBG._originalUpdateHUD = HLBG.UpdateHUD
    HLBG.UpdateHUD = function(...)
        -- Call original function
        if HLBG._originalUpdateHUD then
            pcall(HLBG._originalUpdateHUD, ...)
        end
        
        -- Call enhanced update
        pcall(HLBG.EnhancedUpdate)
    end
end

-- Hook into status updates
if HLBG.Status and not HLBG._originalStatus then
    HLBG._originalStatus = HLBG.Status
    HLBG.Status = function(status, ...)
        -- Call original function
        if HLBG._originalStatus then
            pcall(HLBG._originalStatus, status, ...)
        end
        
        -- Handle phase changes
        if status and status.phase and status.phase ~= HLBG._currentPhase then
            HLBG.HandleBattlePhaseChange(status.phase)
        end
    end
end

-- Global reference
_G.HLBG = HLBG

print("|cFF00EEFF[HLBG Enhanced Integration]|r Loaded successfully")