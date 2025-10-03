-- HLBG_Settings.lua - Settings panel for Hinterland Battleground AddOn
-- This file provides configuration options for the addon

-- Initialize our addon namespace if needed
if not HLBG then HLBG = {} end

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
    season = 0                   -- Season filter (0 = all/current)
}

-- Load saved settings or apply defaults
function HLBG.LoadSettings()
    -- Initialize saved variables if needed
    if not HinterlandAffixHUDDB then 
        HinterlandAffixHUDDB = {} 
    end
    
    -- Apply defaults for any missing settings
    for setting, defaultValue in pairs(HLBG.DefaultSettings) do
        if HinterlandAffixHUDDB[setting] == nil then
            HinterlandAffixHUDDB[setting] = defaultValue
        end
    end
    
    -- Apply loaded settings to the addon
    for setting, value in pairs(HinterlandAffixHUDDB) do
        HLBG[setting] = value
    end
    
    -- Log settings loaded if in dev mode
    if HLBG.devMode and HLBG.Debug then
        HLBG.Debug("Settings loaded", HinterlandAffixHUDDB)
    end
end

-- Save a setting
function HLBG.SaveSetting(setting, value)
    -- Update saved variables
    if not HinterlandAffixHUDDB then HinterlandAffixHUDDB = {} end
    HinterlandAffixHUDDB[setting] = value
    
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
    if HLBG.HUD then
        if HLBG.hudEnabled then
            HLBG.HUD:Show()
        else
            HLBG.HUD:Hide()
        end
        
        -- Scale and position
        if HLBG.HUD.SetScale then
            HLBG.HUD:SetScale(HLBG.hudScale or 1.0)
        end
        
        -- Additional HUD settings can be applied here
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
    checkbox:SetChecked(HinterlandAffixHUDDB[setting])
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
    slider:SetValue(HinterlandAffixHUDDB[setting])
    slider.setting = setting
    
    -- Set text
    slider.Text:SetText(text)
    slider.Low:SetText(min)
    slider.High:SetText(max)
    
    -- Set value text
    local valueText = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    valueText:SetPoint("TOP", slider, "BOTTOM", 0, 0)
    valueText:SetText(format("%.2f", HinterlandAffixHUDDB[setting]))
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
    local dropdown = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    dropdown.setting = setting
    
    -- Set text
    local label = dropdown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("BOTTOMLEFT", dropdown, "TOPLEFT", 20, 0)
    label:SetText(text)
    dropdown.label = label
    
    -- Initialize the dropdown
    UIDropDownMenu_SetWidth(dropdown, 180)
    UIDropDownMenu_SetText(dropdown, options[HinterlandAffixHUDDB[setting]])
    
    UIDropDownMenu_Initialize(dropdown, function(self)
        local info = UIDropDownMenu_CreateInfo()
        for value, name in pairs(options) do
            info.text = name
            info.value = value
            info.func = function(self)
                UIDropDownMenu_SetText(dropdown, self:GetText())
                HLBG.SaveSetting(dropdown.setting, self.value)
            end
            info.checked = (value == HinterlandAffixHUDDB[setting])
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
    title:SetText("Hinterland Battleground Settings")
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
                 desc = "Enable additional debug features and logging"}
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
                HinterlandAffixHUDDB = HLBG.DefaultSettings
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