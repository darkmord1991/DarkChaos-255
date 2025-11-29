-- HLBG_Settings.lua - Settings panel for Hinterland Battleground AddOn
-- This file provides configuration options for the addon
-- Initialize our addon namespace if needed
if not HLBG then HLBG = {} end
local floor = math.floor
-- Default settings
HLBG.DefaultSettings = {
    chatUpdates = true,          -- Show chat messages for BG status updates
    showKillWhispers = true,     -- Show whispers for player kills affecting resources
    showResourceUpdates = true,  -- Show resource updates in chat
    hudEnabled = true,           -- Enable the HUD overlay
    hudScale = 1.0,              -- Scale of the HUD
    hudPosition = "TOP",         -- Position of the HUD on screen
    autoTeleport = true,         -- Auto-teleport when match is ready
    notifyMatchStart = true,     -- Show notification when match starts
    notifyMatchEnd = true,       -- Show notification when match ends
    devMode = false,             -- Developer mode for debugging
    debugLogging = false,        -- Verbose debug logging in chat
    season = 0                   -- Season filter (0 = all/current)
}
-- Load saved settings or apply defaults
function HLBG.LoadSettings()
    -- Initialize saved variables if needed
    if not DCHLBGDB then
        DCHLBGDB = {}
    end
    -- Apply defaults for any missing settings
    for setting, defaultValue in pairs(HLBG.DefaultSettings) do
        if DCHLBGDB[setting] == nil then
            DCHLBGDB[setting] = defaultValue
        end
    end
    -- Apply loaded settings to the addon
    for setting, value in pairs(DCHLBGDB) do
        HLBG[setting] = value
    end
    -- Log settings loaded if in dev mode
    if HLBG.devMode and HLBG.Debug then
        HLBG.Debug("Settings loaded", DCHLBGDB)
    end
end
-- Save a setting
function HLBG.SaveSetting(setting, value)
    -- Update saved variables
    if not DCHLBGDB then DCHLBGDB = {} end
    DCHLBGDB[setting] = value
    -- Update current settings
    HLBG[setting] = value
    -- Log if in dev mode
    if HLBG.devMode and HLBG.Debug then
        HLBG.Debug("Setting saved: " .. setting, value)
    end
    -- Update UI if open
    if HLBG.UI and HLBG.UI.Settings and HLBG.UI.Settings:IsVisible() then
        HLBG.UpdateSettings()
    end
    -- Apply setting changes
    HLBG.ApplySettings()
    return value
end
-- Apply settings to the addon components
function HLBG.ApplySettings()
    -- Apply HUD settings
    if HLBG.HUD and HLBG.HUD.frame then
        if HLBG.hudEnabled then
            HLBG.HUD.frame:Show()
        else
            HLBG.HUD.frame:Hide()
        end
        -- Scale and position
        if HLBG.HUD.frame.SetScale then
            HLBG.HUD.frame:SetScale(HLBG.hudScale or 1.0)
        end
        -- Additional HUD settings can be applied here
    elseif HLBG.UI and HLBG.UI.ModernHUD then
        -- Fallback to ModernHUD directly
        if HLBG.hudEnabled then
            HLBG.UI.ModernHUD:Show()
        else
            HLBG.UI.ModernHUD:Hide()
        end
        if HLBG.UI.ModernHUD.SetScale then
            HLBG.UI.ModernHUD:SetScale(HLBG.hudScale or 1.0)
        end
    end
    -- Apply debug mode
    if HLBG.devMode and HLBG.Debug then
        HLBG.Debug("Dev mode enabled")
    end
    -- Additional settings applications can be added here
end
-- Create a checkbox control
function HLBG.CreateCheckbox(parent, text, setting, description, yOffset)
    local checkbox = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
    checkbox:SetChecked(DCHLBGDB[setting])
    checkbox.setting = setting
    -- Set text
    local label = checkbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", checkbox, "RIGHT", 5, 0)
    label:SetText(text)
    checkbox.label = label
    -- Add description if provided
    if description then
        local desc = checkbox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        desc:SetPoint("TOPLEFT", checkbox, "BOTTOMLEFT", 20, -2)
        desc:SetPoint("RIGHT", parent, "RIGHT", -20, 0)
        desc:SetJustifyH("LEFT")
        desc:SetText(description)
        desc:SetTextColor(0.8, 0.8, 0.8)
        checkbox.description = desc
    end
    -- Set click handler
    checkbox:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        PlaySound(checked and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff")
        HLBG.SaveSetting(self.setting, checked)
    end)
    return checkbox
end
-- Create a slider control
function HLBG.CreateSlider(parent, text, setting, min, max, step, yOffset)
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
    slider:SetWidth(200)
    slider:SetHeight(20)
    slider:SetMinMaxValues(min, max)
    slider:SetValueStep(step)
    slider:SetValue(DCHLBGDB[setting])
    slider.setting = setting
    -- Set text
    slider.Text:SetText(text)
    slider.Low:SetText(min)
    slider.High:SetText(max)
    -- Set value text
    local valueText = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    valueText:SetPoint("TOP", slider, "BOTTOM", 0, 0)
    valueText:SetText(format("%.2f", DCHLBGDB[setting]))
    slider.valueText = valueText
    -- Set change handler
    slider:SetScript("OnValueChanged", function(self, value)
        value = floor(value / step + 0.5) * step -- Round to nearest step
        HLBG.SaveSetting(self.setting, value)
        self.valueText:SetText(format("%.2f", value))
    end)
    return slider
end
-- Create dropdown menu
function HLBG.CreateDropdown(parent, text, setting, options, yOffset)
    local dropdownName = "HLBG_Settings_" .. setting .. "DropDown"
    local dropdown = CreateFrame("Frame", dropdownName, parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    dropdown.setting = setting
    -- Set text
    local label = dropdown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("BOTTOMLEFT", dropdown, "TOPLEFT", 20, 0)
    label:SetText(text)
    dropdown.label = label
    -- Initialize the dropdown
    UIDropDownMenu_SetWidth(dropdown, 180)
    UIDropDownMenu_SetText(dropdown, options[DCHLBGDB[setting]])
    UIDropDownMenu_Initialize(dropdown, function(self)
        local info = UIDropDownMenu_CreateInfo()
        for value, name in pairs(options) do
            info.text = name
            info.value = value
            info.func = function(self)
                UIDropDownMenu_SetText(dropdown, self:GetText())
                HLBG.SaveSetting(dropdown.setting, self.value)
            end
            info.checked = (value == DCHLBGDB[setting])
            UIDropDownMenu_AddButton(info)
        end
    end)
    return dropdown
end
-- Update settings panel with current settings
function HLBG.UpdateSettings()
    -- Make sure the UI is loaded
    if not HLBG._ensureUI('Settings') then return end
    local settings = HLBG.UI.Settings
    -- Clear existing content
    if settings.Content.children then
        for _, child in ipairs(settings.Content.children) do
            child:Hide()
        end
    else
        settings.Content.children = {}
    end
    -- Create title
    local title = settings.Content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", settings.Content, "TOP", 0, -10)
    title:SetText("DC HLBG Addon Settings")
    table.insert(settings.Content.children, title)
    -- Create sections
    local sections = {
        {
            title = "Chat Notifications",
            options = {
                {type = "checkbox", text = "Show Chat Updates", setting = "chatUpdates",
                 desc = "Display BG status updates in the chat window"},
                {type = "checkbox", text = "Show Kill Whispers", setting = "showKillWhispers",
                 desc = "Display whispers when your kills affect resource counts"},
                {type = "checkbox", text = "Show Resource Updates", setting = "showResourceUpdates",
                 desc = "Show notifications when resources are gained or lost"}
            }
        },
        {
            title = "HUD Settings",
            options = {
                {type = "checkbox", text = "Enable HUD", setting = "hudEnabled",
                 desc = "Show the heads-up display during battleground matches"},
                {type = "slider", text = "HUD Scale", setting = "hudScale",
                 min = 0.5, max = 2.0, step = 0.1},
                {type = "dropdown", text = "HUD Position", setting = "hudPosition",
                 options = {["TOP"] = "Top", ["BOTTOM"] = "Bottom", ["TOPLEFT"] = "Top Left",
                           ["TOPRIGHT"] = "Top Right", ["BOTTOMLEFT"] = "Bottom Left",
                           ["BOTTOMRIGHT"] = "Bottom Right"}}
            }
        },
        {
            title = "Gameplay",
            options = {
                {type = "checkbox", text = "Auto-teleport When Ready", setting = "autoTeleport",
                 desc = "Automatically teleport to the battleground when the match is ready"},
                {type = "checkbox", text = "Match Start Notification", setting = "notifyMatchStart",
                 desc = "Show a notification when the match starts"},
                {type = "checkbox", text = "Match End Notification", setting = "notifyMatchEnd",
                 desc = "Show a notification when the match ends"}
            }
        },
        {
            title = "Advanced",
            options = {
                {type = "checkbox", text = "Developer Mode", setting = "devMode",
                 desc = "Enable experimental developer tools"},
                {type = "checkbox", text = "Verbose Debug Logging", setting = "debugLogging",
                 desc = "Print HLBG Debug details in the chat frame"}
            }
        }
    }
    -- Create the sections
    local y = -50
    for _, section in ipairs(sections) do
        -- Section title
        local sectionTitle = settings.Content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        sectionTitle:SetPoint("TOPLEFT", settings.Content, "TOPLEFT", 20, y)
        sectionTitle:SetText(section.title)
        table.insert(settings.Content.children, sectionTitle)
        y = y - 30
        -- Options
        for _, option in ipairs(section.options) do
            local control
            if option.type == "checkbox" then
                control = HLBG.CreateCheckbox(settings.Content, option.text, option.setting, option.desc, y)
                y = y - (option.desc and 40 or 25)
            elseif option.type == "slider" then
                control = HLBG.CreateSlider(settings.Content, option.text, option.setting,
                                            option.min, option.max, option.step, y)
                y = y - 45
            elseif option.type == "dropdown" then
                control = HLBG.CreateDropdown(settings.Content, option.text, option.setting, option.options, y)
                y = y - 50
            end
            if control then
                table.insert(settings.Content.children, control)
            end
        end
        y = y - 10
    end
    -- Reset button
    local resetButton = CreateFrame("Button", nil, settings.Content, "UIPanelButtonTemplate")
    resetButton:SetSize(120, 22)
    resetButton:SetPoint("TOPLEFT", settings.Content, "TOPLEFT", 20, y)
    resetButton:SetText("Reset to Defaults")
    resetButton:SetScript("OnClick", function()
        StaticPopupDialogs["HLBG_RESET_SETTINGS"] = {
            text = "Reset all settings to defaults?",
            button1 = "Yes",
            button2 = "No",
            OnAccept = function()
                DCHLBGDB = {}
                for k,v in pairs(HLBG.DefaultSettings) do DCHLBGDB[k] = v end
                HLBG.LoadSettings()
                HLBG.UpdateSettings()
                HLBG.ApplySettings()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3
        }
        StaticPopup_Show("HLBG_RESET_SETTINGS")
    end)
    table.insert(settings.Content.children, resetButton)
    -- Set content height
    settings.Content:SetHeight(math.abs(y) + 50)
    -- Show the tab
    settings:Show()
end
-- Hook settings to the OpenUI function
HLBG._oldSettingsEnsure = HLBG._ensureUI
function HLBG._ensureUI(what)
    local result = HLBG._oldSettingsEnsure and HLBG._oldSettingsEnsure(what) or true
    -- If Settings tab is requested, update its content
    if what == "Settings" and result and HLBG.UI and HLBG.UI.Settings then
        HLBG.UpdateSettings()
    end
    return result
end
-- Hook to load settings on init
if HLBG.OnLoad then
    local oldOnLoad = HLBG.OnLoad
    HLBG.OnLoad = function()
        oldOnLoad()
        HLBG.LoadSettings()
    end
else
    HLBG.OnLoad = function()
        HLBG.LoadSettings()
    end
end
-- Register slash command for settings
SLASH_HLBGCONFIG1 = "/hlbgconfig"
SlashCmdList["HLBGCONFIG"] = function(msg)
    HLBG.OpenUI("Settings")
end
-- Register a simple Interface -> AddOns panel so settings appear in the Blizzard options
if type(InterfaceOptions_AddCategory) == 'function' then
    local panel = CreateFrame('Frame', 'DCHLBG_InterfaceOptions', UIParent)
    panel.name = 'DC HLBG Addon'
    panel:Hide()
    panel:SetScript('OnShow', function(self)
        -- Ensure settings UI exists and update content
        HLBG.LoadSettings()
        if HLBG and HLBG.UpdateSettings then pcall(HLBG.UpdateSettings) end
    end)
    local title = panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
    title:SetPoint('TOPLEFT', 16, -16)
    title:SetText('DC HLBG Addon')
    -- Create native Interface Options controls (checkboxes, slider, dropdown)
    if not panel._nativeControlsCreated then
        panel._nativeControlsCreated = true
        local y = -48
        -- Helper: create a checkbutton using the Interface template
        local function makeCheck(name, text, setting)
            local cb = CreateFrame("CheckButton", name, panel, "InterfaceOptionsCheckButtonTemplate")
            cb:SetPoint("TOPLEFT", 16, y)
            cb:SetHitRectInsets(0, -100, 0, 0)
            _G[name .. "Text"]:SetText(text)
            cb:SetChecked(DCHLBGDB and DCHLBGDB[setting])
            cb:SetScript("OnClick", function(self)
                HLBG.SaveSetting(setting, self:GetChecked())
            end)
            y = y - 28
            return cb
        end
        -- HUD enabled
        makeCheck("DCHLBG_Opt_HUDEnabled", "Enable HUD", "hudEnabled")
        -- Chat updates
        makeCheck("DCHLBG_Opt_ChatUpdates", "Show Chat Updates", "chatUpdates")
        -- Developer mode
        makeCheck("DCHLBG_Opt_DevMode", "Developer Mode", "devMode")
        -- Debug logging toggle
        makeCheck("DCHLBG_Opt_DebugLogging", "Verbose Debug Logging", "debugLogging")
        -- HUD Scale slider
        local hudScale = CreateFrame("Slider", "DCHLBG_Opt_HUDScale", panel, "OptionsSliderTemplate")
        hudScale:SetPoint("TOPLEFT", 24, y)
        hudScale:SetWidth(220)
        hudScale:SetMinMaxValues(0.5, 2.0)
        hudScale:SetValueStep(0.1)
        hudScale:SetValue((DCHLBGDB and DCHLBGDB.hudScale) or 1.0)
        _G[hudScale:GetName().."Text"]:SetText("HUD Scale")
        _G[hudScale:GetName().."Low"]:SetText("0.5")
        _G[hudScale:GetName().."High"]:SetText("2.0")
        local hudScaleVal = hudScale:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        hudScaleVal:SetPoint("TOP", hudScale, "BOTTOM", 0, 0)
        hudScaleVal:SetText(format("%.1f", hudScale:GetValue()))
        hudScale:SetScript("OnValueChanged", function(self, value)
            value = floor(value * 10 + 0.5) / 10
            HLBG.SaveSetting("hudScale", value)
            hudScaleVal:SetText(format("%.1f", value))
        end)
        y = y - 50
        -- HUD Position dropdown
        local ddName = "DCHLBG_Opt_HUDPosition"
        local dd = CreateFrame("Frame", ddName, panel, "UIDropDownMenuTemplate")
        dd:SetPoint("TOPLEFT", 16, y)
        local posOptions = { ["TOP"] = "Top", ["BOTTOM"] = "Bottom", ["TOPLEFT"] = "Top Left", ["TOPRIGHT"] = "Top Right", ["BOTTOMLEFT"] = "Bottom Left", ["BOTTOMRIGHT"] = "Bottom Right" }
        UIDropDownMenu_SetWidth(dd, 180)
        UIDropDownMenu_SetText(dd, posOptions[(DCHLBGDB and DCHLBGDB.hudPosition) or "TOP"])
        UIDropDownMenu_Initialize(dd, function(self)
            local info = UIDropDownMenu_CreateInfo()
            for value, name in pairs(posOptions) do
                info.text = name
                info.value = value
                info.func = function(self)
                    UIDropDownMenu_SetText(dd, self:GetText())
                    HLBG.SaveSetting("hudPosition", self.value)
                end
                info.checked = (value == ((DCHLBGDB and DCHLBGDB.hudPosition) or "TOP"))
                UIDropDownMenu_AddButton(info)
            end
        end)
        y = y - 36
        -- Additional options mirroring the in-addon settings
        -- Chat-related toggles
        makeCheck("DCHLBG_Opt_KillWhispers", "Show Kill Whispers", "showKillWhispers")
        makeCheck("DCHLBG_Opt_ResourceUpdates", "Show Resource Updates", "showResourceUpdates")
        -- Gameplay toggles
        makeCheck("DCHLBG_Opt_AutoTeleport", "Auto-teleport When Ready", "autoTeleport")
        makeCheck("DCHLBG_Opt_NotifyStart", "Match Start Notification", "notifyMatchStart")
        makeCheck("DCHLBG_Opt_NotifyEnd", "Match End Notification", "notifyMatchEnd")
        -- Season dropdown (0 = current/all)
        local seasonOptions = { [0] = "Current/All", [1] = "Season 1", [2] = "Season 2", [3] = "Season 3" }
        local ddSeason = CreateFrame("Frame", "DCHLBG_Opt_Season", panel, "UIDropDownMenuTemplate")
        ddSeason:SetPoint("TOPLEFT", 16, y)
        UIDropDownMenu_SetWidth(ddSeason, 180)
        UIDropDownMenu_SetText(ddSeason, seasonOptions[(DCHLBGDB and DCHLBGDB.season) or 0])
        UIDropDownMenu_Initialize(ddSeason, function(self)
            local info = UIDropDownMenu_CreateInfo()
            for value, name in pairs(seasonOptions) do
                info.text = name
                info.value = value
                info.func = function(self)
                    UIDropDownMenu_SetText(ddSeason, self:GetText())
                    HLBG.SaveSetting("season", self.value)
                end
                info.checked = (value == ((DCHLBGDB and DCHLBGDB.season) or 0))
                UIDropDownMenu_AddButton(info)
            end
        end)
        y = y - 36
        -- Native Reset button for the Interface panel
        local nativeReset = CreateFrame("Button", "DCHLBG_Native_Reset", panel, "UIPanelButtonTemplate")
        nativeReset:SetSize(140, 24)
        nativeReset:SetPoint("TOPLEFT", 16, y)
        nativeReset:SetText("Reset to Defaults")
        nativeReset:SetScript("OnClick", function()
            StaticPopupDialogs["DCHLBG_NATIVE_RESET"] = {
                text = "Reset DC HLBG settings to defaults?",
                button1 = "Yes",
                button2 = "No",
                OnAccept = function()
                    DCHLBGDB = {}
                    for k,v in pairs(HLBG.DefaultSettings) do DCHLBGDB[k] = v end
                    HLBG.LoadSettings(); HLBG.ApplySettings()
                    if panel:IsShown() and HLBG.UpdateSettings then pcall(HLBG.UpdateSettings) end
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3
            }
            StaticPopup_Show("DCHLBG_NATIVE_RESET")
        end)
        y = y - 36
    end
    InterfaceOptions_AddCategory(panel)
    
    -- =====================================================================
    -- Communication Sub-Panel (Test Buttons)
    -- =====================================================================
    
    local commPanel = CreateFrame('Frame', 'DCHLBG_CommOptions', panel)
    commPanel.name = 'Communication'
    commPanel.parent = panel.name
    commPanel:Hide()
    
    local commTitle = commPanel:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
    commTitle:SetPoint('TOPLEFT', 16, -16)
    commTitle:SetText('Communication Settings')
    
    local commSubtitle = commPanel:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    commSubtitle:SetPoint('TOPLEFT', commTitle, 'BOTTOMLEFT', 0, -8)
    commSubtitle:SetText('Configure and test DCAddonProtocol communication for HLBG.')
    
    commPanel:SetScript('OnShow', function(self)
        HLBG.LoadSettings()
        if self._controlsCreated then return end
        self._controlsCreated = true
        
        local y = -70
        local DC = rawget(_G, "DCAddonProtocol")
        local AIO = rawget(_G, "AIO")
        
        local function HLBGPrint(msg)
            if DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99HLBG:|r " .. (msg or ""))
            end
        end
        
        -- Protocol Status
        local statusHeader = commPanel:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
        statusHeader:SetPoint('TOPLEFT', 16, y)
        statusHeader:SetText('Protocol Status')
        y = y - 22
        
        local dcStatus = commPanel:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
        dcStatus:SetPoint('TOPLEFT', 24, y)
        dcStatus:SetText('DCAddonProtocol: ' .. (DC and '|cFF00FF00Available|r' or '|cFFFF0000Not Loaded|r'))
        y = y - 16
        
        local aioStatus = commPanel:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
        aioStatus:SetPoint('TOPLEFT', 24, y)
        aioStatus:SetText('AIO (Eluna): ' .. (AIO and '|cFF00FF00Available|r' or '|cFFFF0000Not Loaded|r'))
        y = y - 26
        
        -- JSON Toggle
        local jsonCheck = CreateFrame("CheckButton", "DCHLBG_Opt_JSONMode", commPanel, "InterfaceOptionsCheckButtonTemplate")
        jsonCheck:SetPoint("TOPLEFT", 16, y)
        jsonCheck:SetHitRectInsets(0, -200, 0, 0)
        _G["DCHLBG_Opt_JSONModeText"]:SetText("Use JSON Protocol (recommended)")
        jsonCheck:SetChecked(DCHLBGDB and DCHLBGDB.useDCProtocolJSON)
        jsonCheck:SetScript("OnClick", function(self)
            HLBG.SaveSetting("useDCProtocolJSON", self:GetChecked())
            HLBGPrint("JSON Protocol mode: " .. (self:GetChecked() and "ON" or "OFF"))
        end)
        y = y - 32
        
        -- Test Buttons Section
        local testHeader = commPanel:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
        testHeader:SetPoint('TOPLEFT', 16, y)
        testHeader:SetText('Test Communication')
        
        local testDesc = commPanel:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
        testDesc:SetPoint('TOPLEFT', testHeader, 'TOPRIGHT', 10, 0)
        testDesc:SetText('(results appear in chat)')
        testDesc:SetTextColor(0.6, 0.6, 0.6)
        y = y - 26
        
        -- Button dimensions for 2-column layout
        local btnWidth = 150
        local btnHeight = 24
        local colSpacing = 160
        local rowSpacing = 28
        local col1X = 24
        local col2X = col1X + colSpacing
        local btnRow = 0
        
        -- Helper to create test buttons in 2 columns
        local function makeTestButton(text, tooltip, onClick, column)
            local btn = CreateFrame("Button", nil, commPanel, "UIPanelButtonTemplate")
            btn:SetSize(btnWidth, btnHeight)
            local xPos = (column == 2) and col2X or col1X
            local yPos = y - (btnRow * rowSpacing)
            btn:SetPoint("TOPLEFT", xPos, yPos)
            btn:SetText(text)
            btn:SetScript("OnClick", function()
                HLBGPrint("Testing: " .. text .. "...")
                onClick()
            end)
            btn.tooltipText = tooltip
            btn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.tooltipText or text, nil, nil, nil, nil, true)
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            return btn
        end
        
        -- Row 1
        makeTestButton("Request BG Status", "Send CMSG_REQUEST_STATUS (0x01) JSON", function()
            if DC then DC:Request("HLBG", 0x01, { action = "status" }) else HLBGPrint("|cFFFF0000DCAddonProtocol not available|r") end
        end, 1)
        makeTestButton("Request Resources", "Send CMSG_REQUEST_RESOURCES (0x02) JSON", function()
            if DC then DC:Request("HLBG", 0x02, { action = "resources" }) else HLBGPrint("|cFFFF0000DCAddonProtocol not available|r") end
        end, 2)
        btnRow = btnRow + 1
        
        -- Row 2
        makeTestButton("Quick Queue", "Send CMSG_QUICK_QUEUE (0x04) JSON", function()
            if DC then DC:Request("HLBG", 0x04, { action = "queue" }) else HLBGPrint("|cFFFF0000DCAddonProtocol not available|r") end
        end, 1)
        makeTestButton("Leave Queue", "Send CMSG_LEAVE_QUEUE (0x05) JSON", function()
            if DC then DC:Request("HLBG", 0x05, { action = "leave" }) else HLBGPrint("|cFFFF0000DCAddonProtocol not available|r") end
        end, 2)
        btnRow = btnRow + 1
        
        -- Row 3
        makeTestButton("Request Stats", "Send CMSG_REQUEST_STATS (0x06) JSON", function()
            if DC then DC:Request("HLBG", 0x06, { action = "stats" }) else HLBGPrint("|cFFFF0000DCAddonProtocol not available|r") end
        end, 1)
        makeTestButton("Send Test JSON", "Send a test JSON message", function()
            if DC then DC:Request("HLBG", 0x00, { test = true }); HLBGPrint("Sent test JSON") else HLBGPrint("|cFFFF0000DCAddonProtocol not available|r") end
        end, 2)
        btnRow = btnRow + 1
        
        -- Row 4
        makeTestButton("Ping Server", "Send CMSG_HANDSHAKE to test connectivity (JSON)", function()
            if DC then DC:Request("CORE", 0x01, { ping = true }); HLBGPrint("Sent handshake (JSON)") else HLBGPrint("|cFFFF0000DCAddonProtocol not available|r") end
        end, 1)
        btnRow = btnRow + 1
        
        y = y - (btnRow * rowSpacing) - 16
        
        -- AIO Fallback Tests (compact)
        local aioHeader = commPanel:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
        aioHeader:SetPoint('TOPLEFT', 16, y)
        aioHeader:SetText('AIO Fallback Tests')
        
        local aioDesc = commPanel:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
        aioDesc:SetPoint('TOPLEFT', aioHeader, 'TOPRIGHT', 10, 0)
        aioDesc:SetText('(requires AIO addon)')
        aioDesc:SetTextColor(0.6, 0.6, 0.6)
        y = y - 26
        btnRow = 0
        
        -- AIO Row 1
        makeTestButton("AIO: Request History", "Request battle history via AIO.Handle", function()
            if AIO and AIO.Handle then
                AIO.Handle("HLBG", "Request", "HISTORY", 1, 25, 0, "id", "DESC")
                HLBGPrint("Sent AIO history request")
            else HLBGPrint("|cFFFF0000AIO not available|r") end
        end, 1)
        makeTestButton("AIO: Request Stats", "Request stats via AIO.Handle", function()
            if AIO and AIO.Handle then
                AIO.Handle("HLBG", "Request", "STATS", 0)
                HLBGPrint("Sent AIO stats request")
            else HLBGPrint("|cFFFF0000AIO not available|r") end
        end, 2)
        btnRow = btnRow + 1
        
        y = y - (btnRow * rowSpacing) - 16
        
        -- Results/Log Section
        local logHeader = commPanel:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
        logHeader:SetPoint('TOPLEFT', 16, y)
        logHeader:SetText('Test Results')
        y = y - 18
        
        local logDesc = commPanel:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
        logDesc:SetPoint('TOPLEFT', 24, y)
        logDesc:SetText('Results will appear in the chat window. Enable Developer Mode for verbose output.')
        logDesc:SetTextColor(0.7, 0.7, 0.7)
        y = y - 28
        
        -- Refresh Status Button
        local refreshBtn = CreateFrame("Button", nil, commPanel, "UIPanelButtonTemplate")
        refreshBtn:SetSize(140, 24)
        refreshBtn:SetPoint("TOPLEFT", 24, y)
        refreshBtn:SetText("Refresh Status")
        refreshBtn:SetScript("OnClick", function()
            local dc = rawget(_G, "DCAddonProtocol")
            local aio = rawget(_G, "AIO")
            dcStatus:SetText('DCAddonProtocol: ' .. (dc and '|cFF00FF00Available|r' or '|cFFFF0000Not Loaded|r'))
            aioStatus:SetText('AIO (Eluna): ' .. (aio and '|cFF00FF00Available|r' or '|cFFFF0000Not Loaded|r'))
            HLBGPrint("Status refreshed")
        end)
    end)
    
    InterfaceOptions_AddCategory(commPanel)
end

