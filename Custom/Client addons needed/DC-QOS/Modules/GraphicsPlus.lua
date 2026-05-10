-- ============================================================
-- DC-QoS: Graphics+ Module
-- ============================================================

local addon = DCQOS

local GraphicsPlus = {
    displayName = "Graphics+",
    settingKey = "graphicsPlus",
    icon = "Interface\\Icons\\Spell_Nature_Farsight",
    defaults = {
        graphicsPlus = {
            enabled = true,
            autoApplyOnLogin = true,
            autoApplyOnZoneChange = true,
            showChatFeedback = false,
            farclip = 2200,
            cameraDistance = 120,
            horizonScale = 8.0,
            environmentDetail = 2.0,
            fogOverride = false,
            applyQualityPreset = true,
        },
    },
}

local eventFrame
local applyGeneration = 0

local function GetSliderRoundedValue(slider)
    if not slider or type(slider.GetValue) ~= "function" then
        return 0
    end

    return slider:GetValue()
end

local function GetSettings()
    return addon.settings.graphicsPlus
end

local function HasNativeGraphicsApi()
    return type(SetExtendedFarclip) == "function"
        and type(SetExtendedCameraDistance) == "function"
        and type(SetHorizonScale) == "function"
        and type(SetEnvironmentDetail) == "function"
        and type(SetTextureQuality) == "function"
        and type(SetRenderFlags) == "function"
        and type(SetFogDistance) == "function"
end

local function CallNative(func, ...)
    if type(func) ~= "function" then
        return false
    end

    local ok, result = pcall(func, ...)
    if not ok then
        return false
    end

    return result ~= false
end

local function ApplyGraphicsSettings(reason)
    local settings = GetSettings()
    if not settings or not settings.enabled then
        return false, "disabled"
    end

    if not HasNativeGraphicsApi() then
        return false, "missing-api"
    end

    local applied = true

    applied = CallNative(SetExtendedFarclip, settings.farclip) and applied
    applied = CallNative(SetExtendedCameraDistance, settings.cameraDistance) and applied
    applied = CallNative(SetHorizonScale, settings.horizonScale) and applied
    applied = CallNative(SetEnvironmentDetail, settings.environmentDetail) and applied

    if settings.applyQualityPreset then
        applied = CallNative(SetRenderFlags, true, true, true, false, 0) and applied
        applied = CallNative(SetTextureQuality, 0, -0.5, 8, 256) and applied
    end

    if settings.fogOverride then
        applied = CallNative(SetFogDistance, -10000, 10000) and applied
    end

    if settings.showChatFeedback and reason and reason ~= "slider" then
        addon:Print("Graphics+ applied (" .. tostring(reason) .. ").", true)
    end

    return applied, applied and "ok" or "call-failed"
end

local function ScheduleApply(reason, delay)
    applyGeneration = applyGeneration + 1
    local generation = applyGeneration

    local function ExecuteApply()
        if generation ~= applyGeneration then
            return
        end

        ApplyGraphicsSettings(reason)
    end

    if addon.DelayedCall then
        addon:DelayedCall(delay or 0, ExecuteApply)
    else
        ExecuteApply()
    end
end

local function EnsureEventFrame()
    if eventFrame then
        return eventFrame
    end

    eventFrame = CreateFrame("Frame")
    eventFrame:SetScript("OnEvent", function(_, event)
        local settings = GetSettings()
        if not settings or not settings.enabled then
            return
        end

        if event == "PLAYER_ENTERING_WORLD" and settings.autoApplyOnLogin then
            ScheduleApply("login", 1.0)
        elseif event == "ZONE_CHANGED_NEW_AREA" and settings.autoApplyOnZoneChange then
            ScheduleApply("zone change", 0.75)
        end
    end)

    return eventFrame
end

local function SetPreset(values)
    for key, value in pairs(values) do
        addon:SetSetting("graphicsPlus." .. key, value)
    end
end

function GraphicsPlus.OnInitialize()
    addon:Debug("Graphics+ module initializing")
end

function GraphicsPlus.OnEnable()
    addon:Debug("Graphics+ module enabling")

    local frame = EnsureEventFrame()
    frame:UnregisterAllEvents()
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

    ScheduleApply("startup", 1.0)
end

function GraphicsPlus.OnDisable()
    addon:Debug("Graphics+ module disabling")

    if eventFrame then
        eventFrame:UnregisterAllEvents()
    end
end

function GraphicsPlus.CreateSettings(parent)
    local settings = GetSettings()

    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Graphics+")

    local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    desc:SetJustifyH("LEFT")
    desc:SetText("Applies extended graphics limits from the native WotLKExtensions patch and reapplies them on login or zone changes.")

    local status = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    status:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -10)
    status:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    status:SetJustifyH("LEFT")

    local function UpdateStatusText()
        if HasNativeGraphicsApi() then
            status:SetText("|cff00ff00Native Graphics+ API detected.|r")
        else
            status:SetText("|cffff5555Native Graphics+ API missing. Build the client DLL with GRAPHICSENHANCED_PATCH and reload the game.|r")
        end
    end

    UpdateStatusText()

    local yOffset = -100

    local enabledCb = addon:CreateCheckbox(parent)
    enabledCb:SetPoint("TOPLEFT", 16, yOffset)
    enabledCb.Text:SetText("Enable Graphics+ auto-apply")
    enabledCb:SetChecked(settings.enabled)
    enabledCb:SetScript("OnClick", function(self)
        addon:SetSetting("graphicsPlus.enabled", self:GetChecked())
    end)
    yOffset = yOffset - 25

    local loginCb = addon:CreateCheckbox(parent)
    loginCb:SetPoint("TOPLEFT", 16, yOffset)
    loginCb.Text:SetText("Apply on login / entering world")
    loginCb:SetChecked(settings.autoApplyOnLogin ~= false)
    loginCb:SetScript("OnClick", function(self)
        addon:SetSetting("graphicsPlus.autoApplyOnLogin", self:GetChecked())
    end)
    yOffset = yOffset - 25

    local zoneCb = addon:CreateCheckbox(parent)
    zoneCb:SetPoint("TOPLEFT", 16, yOffset)
    zoneCb.Text:SetText("Reapply on zone change")
    zoneCb:SetChecked(settings.autoApplyOnZoneChange ~= false)
    zoneCb:SetScript("OnClick", function(self)
        addon:SetSetting("graphicsPlus.autoApplyOnZoneChange", self:GetChecked())
    end)
    yOffset = yOffset - 25

    local chatCb = addon:CreateCheckbox(parent)
    chatCb:SetPoint("TOPLEFT", 16, yOffset)
    chatCb.Text:SetText("Show chat feedback when settings are applied")
    chatCb:SetChecked(settings.showChatFeedback == true)
    chatCb:SetScript("OnClick", function(self)
        addon:SetSetting("graphicsPlus.showChatFeedback", self:GetChecked())
    end)
    yOffset = yOffset - 35

    local sliderHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    sliderHeader:SetPoint("TOPLEFT", 16, yOffset)
    sliderHeader:SetText("Extended Limits")
    yOffset = yOffset - 25

    local farclipSlider = addon:CreateSlider(parent)
    farclipSlider:SetPoint("TOPLEFT", 16, yOffset)
    farclipSlider:SetWidth(220)
    farclipSlider:SetMinMaxValues(100, 3831)
    farclipSlider:SetValueStep(25)
    farclipSlider.Text:SetText("Farclip: " .. tostring(settings.farclip or 2200))
    farclipSlider.Low:SetText("100")
    farclipSlider.High:SetText("3831")
    farclipSlider:SetValue(settings.farclip or 2200)
    farclipSlider:SetScript("OnValueChanged", function(self, value)
        local rounded = math.floor(value + 0.5)
        if self._dcqosLastValue == rounded then return end
        self._dcqosLastValue = rounded
        self.Text:SetText("Farclip: " .. tostring(rounded))
        addon:SetSetting("graphicsPlus.farclip", rounded)
        ScheduleApply("slider", 0.05)
    end)
    yOffset = yOffset - 54

    local cameraSlider = addon:CreateSlider(parent)
    cameraSlider:SetPoint("TOPLEFT", 16, yOffset)
    cameraSlider:SetWidth(220)
    cameraSlider:SetMinMaxValues(1, 500)
    cameraSlider:SetValueStep(5)
    cameraSlider.Text:SetText("Camera Distance: " .. tostring(settings.cameraDistance or 120))
    cameraSlider.Low:SetText("1")
    cameraSlider.High:SetText("500")
    cameraSlider:SetValue(settings.cameraDistance or 120)
    cameraSlider:SetScript("OnValueChanged", function(self, value)
        local rounded = math.floor(value + 0.5)
        if self._dcqosLastValue == rounded then return end
        self._dcqosLastValue = rounded
        self.Text:SetText("Camera Distance: " .. tostring(rounded))
        addon:SetSetting("graphicsPlus.cameraDistance", rounded)
        ScheduleApply("slider", 0.05)
    end)
    yOffset = yOffset - 54

    local horizonSlider = addon:CreateSlider(parent)
    horizonSlider:SetPoint("TOPLEFT", 16, yOffset)
    horizonSlider:SetWidth(220)
    horizonSlider:SetMinMaxValues(1.0, 12.0)
    horizonSlider:SetValueStep(0.5)
    horizonSlider.Text:SetText(string.format("Horizon Scale: %.1f", settings.horizonScale or 8.0))
    horizonSlider.Low:SetText("1.0")
    horizonSlider.High:SetText("12.0")
    horizonSlider:SetValue(settings.horizonScale or 8.0)
    horizonSlider:SetScript("OnValueChanged", function(self, value)
        local rounded = math.floor((value * 10) + 0.5) / 10
        if self._dcqosLastValue == rounded then return end
        self._dcqosLastValue = rounded
        self.Text:SetText(string.format("Horizon Scale: %.1f", rounded))
        addon:SetSetting("graphicsPlus.horizonScale", rounded)
        ScheduleApply("slider", 0.05)
    end)
    yOffset = yOffset - 54

    local environmentSlider = addon:CreateSlider(parent)
    environmentSlider:SetPoint("TOPLEFT", 16, yOffset)
    environmentSlider:SetWidth(220)
    environmentSlider:SetMinMaxValues(0.5, 6.0)
    environmentSlider:SetValueStep(0.1)
    environmentSlider.Text:SetText(string.format("Environment Detail: %.1f", settings.environmentDetail or 2.0))
    environmentSlider.Low:SetText("0.5")
    environmentSlider.High:SetText("6.0")
    environmentSlider:SetValue(settings.environmentDetail or 2.0)
    environmentSlider:SetScript("OnValueChanged", function(self, value)
        local rounded = math.floor((value * 10) + 0.5) / 10
        if self._dcqosLastValue == rounded then return end
        self._dcqosLastValue = rounded
        self.Text:SetText(string.format("Environment Detail: %.1f", rounded))
        addon:SetSetting("graphicsPlus.environmentDetail", rounded)
        ScheduleApply("slider", 0.05)
    end)
    yOffset = yOffset - 54

    local qualityHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    qualityHeader:SetPoint("TOPLEFT", 16, yOffset)
    qualityHeader:SetText("Overrides")
    yOffset = yOffset - 25

    local fogCb = addon:CreateCheckbox(parent)
    fogCb:SetPoint("TOPLEFT", 16, yOffset)
    fogCb.Text:SetText("Reduce blue fog wall aggressively")
    fogCb:SetChecked(settings.fogOverride == true)
    fogCb:SetScript("OnClick", function(self)
        addon:SetSetting("graphicsPlus.fogOverride", self:GetChecked())
        ScheduleApply("fog override", 0.05)
    end)
    yOffset = yOffset - 22

    local fogInfo = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    fogInfo:SetPoint("TOPLEFT", 34, yOffset)
    fogInfo:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    fogInfo:SetJustifyH("LEFT")
    fogInfo:SetText("Turning this off stops reapplying the override; the default zone fog comes back naturally after reload or zone transitions.")
    yOffset = yOffset - 34

    local qualityCb = addon:CreateCheckbox(parent)
    qualityCb:SetPoint("TOPLEFT", 16, yOffset)
    qualityCb.Text:SetText("Apply built-in texture and render quality preset")
    qualityCb:SetChecked(settings.applyQualityPreset ~= false)
    qualityCb:SetScript("OnClick", function(self)
        addon:SetSetting("graphicsPlus.applyQualityPreset", self:GetChecked())
        ScheduleApply("quality preset", 0.05)
    end)
    yOffset = yOffset - 34

    local presetHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    presetHeader:SetPoint("TOPLEFT", 16, yOffset)
    presetHeader:SetText("Presets")
    yOffset = yOffset - 28

    local function RefreshControls()
        local current = GetSettings()
        enabledCb:SetChecked(current.enabled)
        loginCb:SetChecked(current.autoApplyOnLogin ~= false)
        zoneCb:SetChecked(current.autoApplyOnZoneChange ~= false)
        chatCb:SetChecked(current.showChatFeedback == true)
        fogCb:SetChecked(current.fogOverride == true)
        qualityCb:SetChecked(current.applyQualityPreset ~= false)

        farclipSlider._dcqosLastValue = nil
        farclipSlider:SetValue(current.farclip or 2200)
        cameraSlider._dcqosLastValue = nil
        cameraSlider:SetValue(current.cameraDistance or 120)
        horizonSlider._dcqosLastValue = nil
        horizonSlider:SetValue(current.horizonScale or 8.0)
        environmentSlider._dcqosLastValue = nil
        environmentSlider:SetValue(current.environmentDetail or 2.0)
    end

    local balancedBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    balancedBtn:SetSize(120, 22)
    balancedBtn:SetPoint("TOPLEFT", 16, yOffset)
    balancedBtn:SetText("Balanced")
    balancedBtn:SetScript("OnClick", function()
        SetPreset({
            farclip = 2200,
            cameraDistance = 120,
            horizonScale = 8.0,
            environmentDetail = 2.0,
            fogOverride = false,
            applyQualityPreset = true,
        })
        RefreshControls()
        ScheduleApply("balanced preset", 0.05)
    end)

    local ultraBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    ultraBtn:SetSize(120, 22)
    ultraBtn:SetPoint("LEFT", balancedBtn, "RIGHT", 10, 0)
    ultraBtn:SetText("Ultra")
    ultraBtn:SetScript("OnClick", function()
        SetPreset({
            farclip = 3831,
            cameraDistance = 500,
            horizonScale = 12.0,
            environmentDetail = 6.0,
            fogOverride = true,
            applyQualityPreset = true,
        })
        RefreshControls()
        ScheduleApply("ultra preset", 0.05)
    end)

    local applyBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    applyBtn:SetSize(120, 22)
    applyBtn:SetPoint("LEFT", ultraBtn, "RIGHT", 10, 0)
    applyBtn:SetText("Apply Now")
    applyBtn:SetScript("OnClick", function()
        if not HasNativeGraphicsApi() then
            addon:Print("Graphics+ native API is not available in this client build.", true)
            return
        end

        local ok = ApplyGraphicsSettings("manual")
        if not ok then
            addon:Print("Graphics+ apply failed. Check that the graphics patch is enabled in the client DLL.", true)
        end
    end)

    yOffset = yOffset - 34

    local note = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", 16, yOffset)
    note:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    note:SetJustifyH("LEFT")
    note:SetText("Note: DC-QOS Interface camera zoom factor still stacks on top of Graphics+ camera distance, so very high combinations can be extreme.")

    RefreshControls()
    return yOffset - 40
end

addon:RegisterModule("GraphicsPlus", GraphicsPlus)