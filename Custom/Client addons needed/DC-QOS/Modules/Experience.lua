-- ============================================================
-- DC-QoS: Experience Shell Module
-- ============================================================

local addon = DCQOS

local Experience = {
    displayName = "Experience",
    settingKey = "experience",
    icon = "Interface\\Icons\\Ability_Hunter_MasterMarksman",
    defaults = {
        experience = {
            enabled = true,
        },
    },
}

addon:MergeModuleDefaults(Experience.defaults)

addon:RegisterSettingsKeywords("Experience", {
    "settings",
    "dashboard",
    "search",
    "widgets",
    "edit mode",
    "notifications",
    "toasts",
    "accessibility",
    "tooltip readability",
    "quest text",
})

function Experience.OnInitialize()
    addon:Debug("Experience module initializing")
end

function Experience.OnEnable()
    addon:Debug("Experience module enabling")
    addon:ApplyAccessibility()
end

function Experience.CreateSettings(parent)
    local editSettings = addon.settings.editMode or {}
    local notificationSettings = addon.settings.notifications or {}
    local accessibility = addon.settings.accessibility or {}

    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Experience Shell")

    local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    desc:SetJustifyH("LEFT")
    desc:SetText("Shared settings, search, edit mode, notifications, and readability controls for the whole DC-QoS experience.")

    local yOffset = -74

    local editHeader = addon:CreateSectionHeader(parent, "Unified Edit Mode")
    editHeader:SetPoint("TOPLEFT", 16, yOffset)
    yOffset = yOffset - 28

    local enterBtn = addon:CreateActionButton(parent, "Toggle Edit Mode", 150, 24)
    enterBtn:SetPoint("TOPLEFT", 16, yOffset)
    enterBtn:SetScript("OnClick", function()
        addon:ToggleEditMode()
    end)

    local barsBtn = addon:CreateActionButton(parent, "Action Bars", 120, 24)
    barsBtn:SetPoint("LEFT", enterBtn, "RIGHT", 8, 0)
    barsBtn:SetScript("OnClick", function()
        addon:OpenSettingsModule("ActionBars")
    end)

    local navBtn = addon:CreateActionButton(parent, "Navigation", 120, 24)
    navBtn:SetPoint("LEFT", barsBtn, "RIGHT", 8, 0)
    navBtn:SetScript("OnClick", function()
        addon:OpenSettingsModule("Navigation")
    end)
    yOffset = yOffset - 34

    local autoUnlockCb = addon:CreateCheckbox(parent)
    autoUnlockCb:SetPoint("TOPLEFT", 16, yOffset)
    autoUnlockCb.Text:SetText("Auto-unlock frames when edit mode starts")
    autoUnlockCb:SetChecked(editSettings.autoUnlockFrames ~= false)
    autoUnlockCb:SetScript("OnClick", function(self)
        addon:SetSetting("editMode.autoUnlockFrames", self:GetChecked())
    end)
    yOffset = yOffset - 24

    local autoBindCb = addon:CreateCheckbox(parent)
    autoBindCb:SetPoint("TOPLEFT", 16, yOffset)
    autoBindCb.Text:SetText("Auto-enable hover keybind mode while editing")
    autoBindCb:SetChecked(editSettings.autoEnableKeybinds ~= false)
    autoBindCb:SetScript("OnClick", function(self)
        addon:SetSetting("editMode.autoEnableKeybinds", self:GetChecked())
    end)
    yOffset = yOffset - 24

    local toolbarCb = addon:CreateCheckbox(parent)
    toolbarCb:SetPoint("TOPLEFT", 16, yOffset)
    toolbarCb.Text:SetText("Show unified edit toolbar")
    toolbarCb:SetChecked(editSettings.showToolbar ~= false)
    toolbarCb:SetScript("OnClick", function(self)
        addon:SetSetting("editMode.showToolbar", self:GetChecked())
    end)
    yOffset = yOffset - 24

    local gridCb = addon:CreateCheckbox(parent)
    gridCb:SetPoint("TOPLEFT", 16, yOffset)
    gridCb.Text:SetText("Show grid while edit mode is active")
    gridCb:SetChecked(editSettings.showGridWhileEditing ~= false)
    gridCb:SetScript("OnClick", function(self)
        addon:SetSetting("editMode.showGridWhileEditing", self:GetChecked())
    end)
    yOffset = yOffset - 24

    local routeCb = addon:CreateCheckbox(parent)
    routeCb:SetPoint("TOPLEFT", 16, yOffset)
    routeCb.Text:SetText("Enable navigation preview button in edit toolbar")
    routeCb:SetChecked(editSettings.useNavigationPreview ~= false)
    routeCb:SetScript("OnClick", function(self)
        addon:SetSetting("editMode.useNavigationPreview", self:GetChecked())
    end)
    yOffset = yOffset - 36

    local toastHeader = addon:CreateSectionHeader(parent, "Toast Notifications")
    toastHeader:SetPoint("TOPLEFT", 16, yOffset)
    yOffset = yOffset - 28

    local toastEnabledCb = addon:CreateCheckbox(parent)
    toastEnabledCb:SetPoint("TOPLEFT", 16, yOffset)
    toastEnabledCb.Text:SetText("Enable reusable toast notifications")
    toastEnabledCb:SetChecked(notificationSettings.enabled ~= false)
    toastEnabledCb:SetScript("OnClick", function(self)
        addon:SetSetting("notifications.enabled", self:GetChecked())
    end)
    yOffset = yOffset - 24

    local chatFallbackCb = addon:CreateCheckbox(parent)
    chatFallbackCb:SetPoint("TOPLEFT", 16, yOffset)
    chatFallbackCb.Text:SetText("Also mirror toasts to chat")
    chatFallbackCb:SetChecked(notificationSettings.chatFallback ~= false)
    chatFallbackCb:SetScript("OnClick", function(self)
        addon:SetSetting("notifications.chatFallback", self:GetChecked())
    end)
    yOffset = yOffset - 32

    local durationSlider = addon:CreateSlider(parent)
    durationSlider:SetPoint("TOPLEFT", 16, yOffset)
    durationSlider:SetWidth(220)
    durationSlider:SetMinMaxValues(2.0, 8.0)
    durationSlider:SetValueStep(0.5)
    durationSlider:SetValue(notificationSettings.duration or 3.5)
    durationSlider.Low:SetText("2.0")
    durationSlider.High:SetText("8.0")
    durationSlider.Text:SetText(string.format("Toast Duration: %.1f sec", notificationSettings.duration or 3.5))
    durationSlider:SetScript("OnValueChanged", function(self, value)
        local rounded = math.floor((value * 2) + 0.5) / 2
        self.Text:SetText(string.format("Toast Duration: %.1f sec", rounded))
        addon:SetSetting("notifications.duration", rounded)
    end)
    yOffset = yOffset - 54

    local visibleSlider = addon:CreateSlider(parent)
    visibleSlider:SetPoint("TOPLEFT", 16, yOffset)
    visibleSlider:SetWidth(220)
    visibleSlider:SetMinMaxValues(1, 5)
    visibleSlider:SetValueStep(1)
    visibleSlider:SetValue(notificationSettings.maxVisible or 3)
    visibleSlider.Low:SetText("1")
    visibleSlider.High:SetText("5")
    visibleSlider.Text:SetText("Visible Toasts: " .. tostring(notificationSettings.maxVisible or 3))
    visibleSlider:SetScript("OnValueChanged", function(self, value)
        local rounded = math.floor(value + 0.5)
        self.Text:SetText("Visible Toasts: " .. tostring(rounded))
        addon:SetSetting("notifications.maxVisible", rounded)
    end)
    yOffset = yOffset - 54

    local toastScaleSlider = addon:CreateSlider(parent)
    toastScaleSlider:SetPoint("TOPLEFT", 16, yOffset)
    toastScaleSlider:SetWidth(220)
    toastScaleSlider:SetMinMaxValues(0.8, 1.4)
    toastScaleSlider:SetValueStep(0.05)
    toastScaleSlider:SetValue(notificationSettings.scale or 1.0)
    toastScaleSlider.Low:SetText("0.80")
    toastScaleSlider.High:SetText("1.40")
    toastScaleSlider.Text:SetText(string.format("Toast Scale: %.2f", notificationSettings.scale or 1.0))
    toastScaleSlider:SetScript("OnValueChanged", function(self, value)
        local rounded = math.floor((value * 20) + 0.5) / 20
        self.Text:SetText(string.format("Toast Scale: %.2f", rounded))
        addon:SetSetting("notifications.scale", rounded)
    end)

    local testToastBtn = addon:CreateActionButton(parent, "Show Test Toast", 150, 24)
    testToastBtn:SetPoint("LEFT", durationSlider, "RIGHT", 16, 10)
    testToastBtn:SetScript("OnClick", function()
        addon:Notify("DC-QoS toast notifications are active.", "success", { title = "Test Toast" })
    end)
    yOffset = yOffset - 40

    local accessibilityHeader = addon:CreateSectionHeader(parent, "Accessibility / Readability")
    accessibilityHeader:SetPoint("TOPLEFT", 16, yOffset)
    yOffset = yOffset - 28

    local accessibilityEnabledCb = addon:CreateCheckbox(parent)
    accessibilityEnabledCb:SetPoint("TOPLEFT", 16, yOffset)
    accessibilityEnabledCb.Text:SetText("Enable accessibility enhancements")
    accessibilityEnabledCb:SetChecked(accessibility.enabled ~= false)
    accessibilityEnabledCb:SetScript("OnClick", function(self)
        addon:SetSetting("accessibility.enabled", self:GetChecked())
    end)
    yOffset = yOffset - 32

    local fontScaleSlider = addon:CreateSlider(parent)
    fontScaleSlider:SetPoint("TOPLEFT", 16, yOffset)
    fontScaleSlider:SetWidth(220)
    fontScaleSlider:SetMinMaxValues(0.9, 1.4)
    fontScaleSlider:SetValueStep(0.05)
    fontScaleSlider:SetValue(accessibility.fontScale or 1.0)
    fontScaleSlider.Low:SetText("0.90")
    fontScaleSlider.High:SetText("1.40")
    fontScaleSlider.Text:SetText(string.format("UI Font Scale: %.2f", accessibility.fontScale or 1.0))
    fontScaleSlider:SetScript("OnValueChanged", function(self, value)
        local rounded = math.floor((value * 20) + 0.5) / 20
        self.Text:SetText(string.format("UI Font Scale: %.2f", rounded))
        addon:SetSetting("accessibility.fontScale", rounded)
    end)
    yOffset = yOffset - 54

    local tooltipScaleSlider = addon:CreateSlider(parent)
    tooltipScaleSlider:SetPoint("TOPLEFT", 16, yOffset)
    tooltipScaleSlider:SetWidth(220)
    tooltipScaleSlider:SetMinMaxValues(0.8, 1.6)
    tooltipScaleSlider:SetValueStep(0.05)
    tooltipScaleSlider:SetValue(accessibility.tooltipScale or 1.0)
    tooltipScaleSlider.Low:SetText("0.80")
    tooltipScaleSlider.High:SetText("1.60")
    tooltipScaleSlider.Text:SetText(string.format("Tooltip Readability Scale: %.2f", accessibility.tooltipScale or 1.0))
    tooltipScaleSlider:SetScript("OnValueChanged", function(self, value)
        local rounded = math.floor((value * 20) + 0.5) / 20
        self.Text:SetText(string.format("Tooltip Readability Scale: %.2f", rounded))
        addon:SetSetting("accessibility.tooltipScale", rounded)
    end)
    yOffset = yOffset - 54

    local contrastCb = addon:CreateCheckbox(parent)
    contrastCb:SetPoint("TOPLEFT", 16, yOffset)
    contrastCb.Text:SetText("Use higher-contrast shells for tooltips and quest panels")
    contrastCb:SetChecked(accessibility.highContrast == true)
    contrastCb:SetScript("OnClick", function(self)
        addon:SetSetting("accessibility.highContrast", self:GetChecked())
    end)
    yOffset = yOffset - 24

    local cleanerTooltipsCb = addon:CreateCheckbox(parent)
    cleanerTooltipsCb:SetPoint("TOPLEFT", 16, yOffset)
    cleanerTooltipsCb.Text:SetText("Apply cleaner tooltip presentation")
    cleanerTooltipsCb:SetChecked(accessibility.cleanerTooltips ~= false)
    cleanerTooltipsCb:SetScript("OnClick", function(self)
        addon:SetSetting("accessibility.cleanerTooltips", self:GetChecked())
    end)
    yOffset = yOffset - 24

    local questContrastCb = addon:CreateCheckbox(parent)
    questContrastCb:SetPoint("TOPLEFT", 16, yOffset)
    questContrastCb.Text:SetText("Improve quest text contrast")
    questContrastCb:SetChecked(accessibility.questTextContrast ~= false)
    questContrastCb:SetScript("OnClick", function(self)
        addon:SetSetting("accessibility.questTextContrast", self:GetChecked())
    end)
    yOffset = yOffset - 24

    local largerQuestTextCb = addon:CreateCheckbox(parent)
    largerQuestTextCb:SetPoint("TOPLEFT", 16, yOffset)
    largerQuestTextCb.Text:SetText("Use slightly larger quest text")
    largerQuestTextCb:SetChecked(accessibility.largerQuestText ~= false)
    largerQuestTextCb:SetScript("OnClick", function(self)
        addon:SetSetting("accessibility.largerQuestText", self:GetChecked())
    end)
    yOffset = yOffset - 34

    local info = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", 16, yOffset)
    info:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    info:SetJustifyH("LEFT")
    info:SetText("This is the first shell pass: it unifies search, edit mode entry, toast delivery, and readability controls before deeper module rewrites.")

    return yOffset - 50
end

addon:RegisterModule("Experience", Experience)