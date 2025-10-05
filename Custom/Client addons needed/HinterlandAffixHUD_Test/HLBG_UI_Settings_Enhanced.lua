-- HLBG_UI_Settings_Enhanced.lua - Enhanced Settings interface for Hinterland Battleground

-- Ensure HLBG namespace exists
HLBG = HLBG or {}

-- Enhanced Settings page handler
function HLBG.ShowEnhancedSettings()
    HLBG._ensureUI('Settings')
    local s = HLBG.UI and HLBG.UI.SettingsPane
    if not s then return end
    
    -- Initialize UI components if needed
    if not s.enhancedInitialized then
        -- Create scrollable frame for settings
        s.ScrollFrame = CreateFrame("ScrollFrame", "HLBG_EnhancedSettingsScrollFrame", s, "UIPanelScrollFrameTemplate")
        s.ScrollFrame:SetPoint("TOPLEFT", s, "TOPLEFT", 10, -10)
        s.ScrollFrame:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", -30, 10)
        
        s.Content = CreateFrame("Frame", "HLBG_EnhancedSettingsScrollContent", s.ScrollFrame)
        s.Content:SetSize(s:GetWidth() - 40, 800)  -- Make it tall enough for all settings
        s.ScrollFrame:SetScrollChild(s.Content)
        
        -- Title
        s.Title = s.Content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        s.Title:SetPoint("TOPLEFT", s.Content, "TOPLEFT", 5, -5)
        s.Title:SetPoint("RIGHT", s.Content, "RIGHT", -5, 0)
        s.Title:SetJustifyH("CENTER")
        s.Title:SetText("Hinterland Battleground Settings")
        
        -- Local function to create section headers
        local function CreateHeader(text, anchor, yOffset)
            local header = s.Content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            header:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset)
            header:SetText(text)
            header:SetTextColor(1, 0.82, 0)
            return header
        end
        
        -- Local function to create checkboxes
        local function CreateCheckbox(text, anchor, yOffset, savedVarName, defaultValue, callback)
            local checkbox = CreateFrame("CheckButton", nil, s.Content, "UICheckButtonTemplate")
            checkbox:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 5, yOffset)
            checkbox.text:SetText(text)
            
            -- Set initial state from saved variable
            HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
            checkbox:SetChecked(HinterlandAffixHUDDB[savedVarName] ~= nil and HinterlandAffixHUDDB[savedVarName] or defaultValue)
            
            -- OnClick handler
            checkbox:SetScript("OnClick", function(self)
                HinterlandAffixHUDDB[savedVarName] = self:GetChecked()
                if type(callback) == "function" then
                    callback(self:GetChecked())
                end
            end)
            
            return checkbox
        end
        
        -- Local function to create sliders
        local function CreateSlider(text, anchor, yOffset, min, max, step, savedVarName, defaultValue, formatter, callback)
            local sliderText = s.Content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            sliderText:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 10, yOffset)
            sliderText:SetText(text)
            
            local slider = CreateFrame("Slider", nil, s.Content, "OptionsSliderTemplate")
            slider:SetPoint("TOPLEFT", sliderText, "BOTTOMLEFT", 5, -5)
            slider:SetWidth(200)
            slider:SetMinMaxValues(min, max)
            slider:SetValueStep(step)
            
            -- Set initial value from saved variable
            HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
            local value = HinterlandAffixHUDDB[savedVarName] ~= nil and HinterlandAffixHUDDB[savedVarName] or defaultValue
            slider:SetValue(value)
            
            -- Set slider labels
            getglobal(slider:GetName().."Low"):SetText(formatter(min))
            getglobal(slider:GetName().."High"):SetText(formatter(max))
            getglobal(slider:GetName().."Text"):SetText(formatter(value))
            
            -- OnValueChanged handler
            slider:SetScript("OnValueChanged", function(self, value)
                -- Round to step precision if needed
                if step == math.floor(step) then
                    value = math.floor(value + 0.5)
                else
                    -- Round to nearest step
                    value = math.floor((value / step) + 0.5) * step
                end
                
                getglobal(self:GetName().."Text"):SetText(formatter(value))
                HinterlandAffixHUDDB[savedVarName] = value
                
                if type(callback) == "function" then
                    callback(value)
                end
            end)
            
            return slider, sliderText
        end
        
        -- Local function to create dropdown menus
        local function CreateDropdown(text, anchor, yOffset, options, savedVarName, defaultValue, callback)
            local dropdownText = s.Content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            dropdownText:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 10, yOffset)
            dropdownText:SetText(text)
            
            local dropdown = CreateFrame("Frame", nil, s.Content, "UIDropDownMenuTemplate")
            dropdown:SetPoint("TOPLEFT", dropdownText, "BOTTOMLEFT", -15, -5)
            
            -- Initialize dropdown
            UIDropDownMenu_SetWidth(dropdown, 120)
            
            local function DropdownOnClick(self)
                UIDropDownMenu_SetSelectedID(dropdown, self:GetID())
                HinterlandAffixHUDDB[savedVarName] = self.value
                if type(callback) == "function" then
                    callback(self.value)
                end
            end
            
            local function DropdownInitialize(self, level)
                local info = UIDropDownMenu_CreateInfo()
                for i, option in ipairs(options) do
                    info = UIDropDownMenu_CreateInfo()
                    info.text = option.text
                    info.value = option.value
                    info.func = DropdownOnClick
                    UIDropDownMenu_AddButton(info, level)
                end
            end
            
            UIDropDownMenu_Initialize(dropdown, DropdownInitialize)
            
            -- Set initial value
            HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
            local initialValue = HinterlandAffixHUDDB[savedVarName] or defaultValue
            for i, option in ipairs(options) do
                if option.value == initialValue then
                    UIDropDownMenu_SetSelectedID(dropdown, i)
                    break
                end
            end
            
            return dropdown, dropdownText
        end
        
        -- Local function to create buttons
        local function CreateButton(text, anchor, yOffset, width, height, callback)
            local button = CreateFrame("Button", nil, s.Content, "UIPanelButtonTemplate")
            button:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 10, yOffset)
            button:SetSize(width, height)
            button:SetText(text)
            
            button:SetScript("OnClick", callback)
            
            return button
        end
        
        -- ===== HUD SETTINGS SECTION =====
        s.HUDHeader = CreateHeader("HUD Settings", s.Title, -30)
        
        -- Enable HUD
        s.EnableHUD = CreateCheckbox(
            "Enable HUD", 
            s.HUDHeader, 
            -10, 
            "hudEnabled", 
            true,
            function(checked)
                if HLBG.UpdateHUDVisibility then
                    HLBG.UpdateHUDVisibility()
                end
            end
        )
        
        -- Show HUD Everywhere
        s.ShowEverywhere = CreateCheckbox(
            "Show HUD Everywhere (not just in Hinterlands)", 
            s.EnableHUD, 
            -10, 
            "showHudEverywhere", 
            false,
            function(checked)
                if HLBG.UpdateHUDVisibility then
                    HLBG.UpdateHUDVisibility()
                end
            end
        )
        
        -- Show HUD in Warmup
        s.ShowWarmup = CreateCheckbox(
            "Show HUD During Warmup Phase", 
            s.ShowEverywhere, 
            -10, 
            "showHudInWarmup", 
            true,
            nil
        )
        
        -- Lock HUD Position
        s.LockHUD = CreateCheckbox(
            "Lock HUD Position", 
            s.ShowWarmup, 
            -10, 
            "hudLocked", 
            false,
            nil
        )
        
        -- HUD Scale slider
        s.HUDScaleSlider, s.HUDScaleText = CreateSlider(
            "HUD Scale:", 
            s.LockHUD, 
            -15, 
            0.5, 2.0, 0.05, 
            "hudScale", 1.0, 
            function(val) return string.format("%.2f", val) end,
            function(val) 
                if HLBG.ApplyHUDSettings then
                    HLBG.ApplyHUDSettings()
                end
            end
        )
        
        -- HUD Alpha slider
        s.HUDAlphaSlider, s.HUDAlphaText = CreateSlider(
            "HUD Transparency:", 
            s.HUDScaleSlider, 
            -25, 
            0.1, 1.0, 0.05, 
            "hudAlpha", 0.9, 
            function(val) return string.format("%.0f%%", val * 100) end,
            function(val) 
                if HLBG.ApplyHUDSettings then
                    HLBG.ApplyHUDSettings()
                end
            end
        )
        
        -- Font Size dropdown
        s.FontSizeDropdown, s.FontSizeText = CreateDropdown(
            "Font Size:",
            s.HUDAlphaSlider,
            -25,
            {
                {text = "Small", value = "Small"},
                {text = "Normal", value = "Normal"},
                {text = "Large", value = "Large"}
            },
            "fontSize",
            "Normal",
            function(value)
                if HLBG.ApplyHUDSettings then
                    HLBG.ApplyHUDSettings()
                end
            end
        )
        
        -- Reset HUD Position Button
        s.ResetHUDButton = CreateButton(
            "Reset HUD Position", 
            s.FontSizeDropdown, 
            -15, 
            150, 22,
            function()
                HinterlandAffixHUDDB.hudPosition = nil
                if HLBG.ApplyHUDSettings then
                    HLBG.ApplyHUDSettings()
                end
            end
        )
        
        -- ===== ALERTS AND NOTIFICATIONS =====
        s.AlertsHeader = CreateHeader("Alerts & Notifications", s.ResetHUDButton, -30)
        
        -- Enable Alerts
        s.EnableAlerts = CreateCheckbox(
            "Enable Alert Sounds", 
            s.AlertsHeader, 
            -10, 
            "enableAlerts", 
            true,
            nil
        )
        
        -- Queue Pop Sound
        s.QueuePopAlert = CreateCheckbox(
            "Play Sound on Queue Pop", 
            s.EnableAlerts, 
            -10, 
            "queuePopSound", 
            true,
            nil
        )
        
        -- Match Start Sound
        s.MatchStartAlert = CreateCheckbox(
            "Play Sound on Match Start", 
            s.QueuePopAlert, 
            -10, 
            "matchStartSound", 
            true,
            nil
        )
        
        -- Victory/Defeat Sound
        s.EndGameAlert = CreateCheckbox(
            "Play Sound on Match End", 
            s.MatchStartAlert, 
            -10, 
            "endGameSound", 
            true,
            nil
        )
        
        -- Chat Messages
        s.ChatMessages = CreateCheckbox(
            "Show Messages in Chat Frame", 
            s.EndGameAlert, 
            -10, 
            "chatMessages", 
            true,
            nil
        )
        
        -- Flash Screen on Important Events
        s.FlashScreen = CreateCheckbox(
            "Flash Screen on Important Events", 
            s.ChatMessages, 
            -10, 
            "flashScreen", 
            false,
            nil
        )
        
        -- ===== TELEMETRY SETTINGS =====
        s.TelemetryHeader = CreateHeader("Performance Monitoring", s.FlashScreen, -30)
        
        -- Enable Telemetry
        s.EnableTelemetry = CreateCheckbox(
            "Enable Ping and FPS Display", 
            s.TelemetryHeader, 
            -10, 
            "enableTelemetry", 
            true,
            function(checked)
                if HLBG.ApplyHUDSettings then
                    HLBG.ApplyHUDSettings()
                end
            end
        )
        
        -- Detailed Performance Stats
        s.DetailedStats = CreateCheckbox(
            "Show Detailed Performance Stats", 
            s.EnableTelemetry, 
            -10, 
            "detailedTelemetry", 
            false,
            nil
        )
        
        -- Performance History
        s.PerformanceHistory = CreateCheckbox(
            "Keep Performance History (for debugging)", 
            s.DetailedStats, 
            -10, 
            "keepPerfHistory", 
            false,
            nil
        )
        
        -- ===== SCOREBOARD SETTINGS =====
        s.ScoreboardHeader = CreateHeader("Scoreboard Settings", s.PerformanceHistory, -30)
        
        -- Modern Scoreboard
        s.ModernScoreboard = CreateCheckbox(
            "Use Modern Scoreboard Design", 
            s.ScoreboardHeader, 
            -10, 
            "modernScoreboard", 
            true,
            function(checked)
                if HLBG.RefreshScoreboard then
                    HLBG.RefreshScoreboard()
                end
            end
        )
        
        -- Compact View
        s.CompactScoreboard = CreateCheckbox(
            "Compact Scoreboard View", 
            s.ModernScoreboard, 
            -10, 
            "compactScoreboard", 
            false,
            nil
        )
        
        -- Show Class Colors
        s.ClassColors = CreateCheckbox(
            "Show Player Names in Class Colors", 
            s.CompactScoreboard, 
            -10, 
            "useClassColors", 
            true,
            nil
        )
        
        -- Auto-Sort Scoreboard
        s.AutoSort = CreateCheckbox(
            "Auto-Sort Scoreboard by Score", 
            s.ClassColors, 
            -10, 
            "autoSortScoreboard", 
            true,
            nil
        )
        
        -- Scoreboard Update Rate
        s.UpdateRateSlider, s.UpdateRateText = CreateSlider(
            "Scoreboard Update Rate:", 
            s.AutoSort, 
            -15, 
            1, 10, 1, 
            "scoreboardUpdateRate", 3, 
            function(val) return string.format("%.0f seconds", val) end,
            nil
        )
        
        -- ===== ADVANCED SETTINGS =====
        s.AdvancedHeader = CreateHeader("Advanced Settings", s.UpdateRateSlider, -30)
        
        -- Developer Mode
        s.DevMode = CreateCheckbox(
            "Developer Mode (Extra Debug Info)", 
            s.AdvancedHeader, 
            -10, 
            "devMode", 
            false,
            function(checked)
                HLBG._devMode = checked
            end
        )
        
        -- Debug Level
        s.DebugLevelSlider, s.DebugLevelText = CreateSlider(
            "Debug Level:", 
            s.DevMode, 
            -15, 
            0, 5, 1, 
            "debugLevel", 0, 
            function(val) return tostring(val) end,
            nil
        )
        
        -- Auto-Join Queue
        s.AutoJoin = CreateCheckbox(
            "Auto-Join Queue When Available", 
            s.DebugLevelSlider, 
            -25, 
            "autoJoinQueue", 
            false,
            nil
        )
        
        -- Auto-Teleport
        s.AutoTeleport = CreateCheckbox(
            "Auto-Teleport When Match Starts", 
            s.AutoJoin, 
            -10, 
            "autoTeleport", 
            true,
            function(checked)
                -- Send preference to server if AIO is available
                if _G.AIO and _G.AIO.Handle then
                    _G.AIO.Handle("HLBG", "SetPreference", "autoTeleport", checked and "1" or "0")
                end
            end
        )
        
        -- Data Collection
        s.DataCollection = CreateCheckbox(
            "Allow Anonymous Usage Data Collection", 
            s.AutoTeleport, 
            -10, 
            "allowDataCollection", 
            false,
            nil
        )
        
        -- ===== RESET AND INFO =====
        s.ResetHeader = CreateHeader("Reset & Information", s.DataCollection, -30)
        
        -- Reset All Settings Button
        s.ResetAllButton = CreateButton(
            "Reset All Settings", 
            s.ResetHeader, 
            -15, 
            150, 22,
            function()
                StaticPopup_Show("HLBG_RESET_SETTINGS")
            end
        )
        
        -- Export Settings Button
        s.ExportButton = CreateButton(
            "Export Settings", 
            s.ResetAllButton, 
            0, 
            120, 22,
            function()
                HLBG.ExportSettings()
            end
        )
        
        -- Import Settings Button
        s.ImportButton = CreateButton(
            "Import Settings", 
            s.ExportButton, 
            0, 
            120, 22,
            function()
                HLBG.ShowImportDialog()
            end
        )
        
        -- Version information
        s.VersionText = s.Content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        s.VersionText:SetPoint("BOTTOMRIGHT", s.Content, "BOTTOMRIGHT", -10, 10)
        s.VersionText:SetText("HinterlandAffixHUD v" .. (HLAFFIXHUD_VERSION or "2.0.0"))
        
        -- Calculate total height needed for scrolling
        local function updateHeight()
            local totalHeight = 600 -- Conservative estimate
            s.Content:SetHeight(totalHeight)
        end
        
        -- Update height after all elements have rendered
        C_Timer.After(0.1, updateHeight)
        
        s.enhancedInitialized = true
    end
    
    -- Show the UI
    if HLBG.UI and HLBG.UI.Frame and type(ShowTab) == "function" then
        HLBG.UI.Frame:Show()
        ShowTab(6)  -- Show Settings tab
    end
end

-- Create reset settings confirmation dialog
StaticPopupDialogs["HLBG_RESET_SETTINGS"] = {
    text = "Are you sure you want to reset all Hinterland Battleground settings to default?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function()
        -- Reset all settings
        HinterlandAffixHUDDB = {}
        
        -- Reinitialize with defaults
        if HinterlandAffixHUDDB.hudEnabled == nil then HinterlandAffixHUDDB.hudEnabled = true end
        if HinterlandAffixHUDDB.hudScale == nil then HinterlandAffixHUDDB.hudScale = 1.0 end
        if HinterlandAffixHUDDB.enableTelemetry == nil then HinterlandAffixHUDDB.enableTelemetry = true end
        
        -- Apply settings
        if HLBG.ApplyHUDSettings then
            HLBG.ApplyHUDSettings()
        end
        
        -- Refresh UI
        ReloadUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Export settings function
function HLBG.ExportSettings()
    local settings = ""
    for k, v in pairs(HinterlandAffixHUDDB or {}) do
        if type(v) == "boolean" then
            settings = settings .. k .. "=" .. (v and "true" or "false") .. "\n"
        elseif type(v) == "number" then
            settings = settings .. k .. "=" .. tostring(v) .. "\n"
        elseif type(v) == "string" then
            settings = settings .. k .. "=\"" .. v .. "\"\n"
        end
    end
    
    -- Show export dialog
    StaticPopup_Show("HLBG_EXPORT_SETTINGS", settings)
end

-- Create export dialog
StaticPopupDialogs["HLBG_EXPORT_SETTINGS"] = {
    text = "Copy your settings (Ctrl+C):\n%s",
    button1 = "Close",
    OnShow = function(self, data)
        self.editBox:SetText(data)
        self.editBox:HighlightText()
        self.editBox:SetFocus()
    end,
    hasEditBox = true,
    editBoxWidth = 300,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Import settings dialog
function HLBG.ShowImportDialog()
    StaticPopup_Show("HLBG_IMPORT_SETTINGS")
end

StaticPopupDialogs["HLBG_IMPORT_SETTINGS"] = {
    text = "Paste your settings:",
    button1 = "Import",
    button2 = "Cancel",
    OnAccept = function(self)
        local settings = self.editBox:GetText()
        -- Parse and apply settings
        for line in settings:gmatch("[^\r\n]+") do
            local key, value = line:match("(.+)=(.+)")
            if key and value then
                key = key:trim()
                value = value:trim()
                
                -- Parse value type
                if value == "true" then
                    HinterlandAffixHUDDB[key] = true
                elseif value == "false" then
                    HinterlandAffixHUDDB[key] = false
                elseif tonumber(value) then
                    HinterlandAffixHUDDB[key] = tonumber(value)
                else
                    -- Remove quotes if present
                    value = value:gsub("^\"(.-)\"$", "%1")
                    HinterlandAffixHUDDB[key] = value
                end
            end
        end
        
        -- Apply settings
        if HLBG.ApplyHUDSettings then
            HLBG.ApplyHUDSettings()
        end
        
        print("Settings imported successfully!")
    end,
    hasEditBox = true,
    editBoxWidth = 300,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Register enhanced settings handler
if not HLBG._tabHandlers then HLBG._tabHandlers = {} end
HLBG._tabHandlers[6] = HLBG.ShowEnhancedSettings

-- Override the original ShowSettings function
HLBG.ShowSettings = HLBG.ShowEnhancedSettings

_G.HLBG = HLBG