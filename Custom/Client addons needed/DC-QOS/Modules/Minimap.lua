-- ============================================================
-- DC-QoS: Minimap Module
-- ============================================================

local addon = DCQOS

local MinimapModule = {
    displayName = "Minimap",
    settingKey = "minimap",
    icon = "Interface\\Icons\\INV_Misc_Map_01",
}

local function ApplyMinimapSkin()
    local s = addon.settings.minimap
    if not s.enabled then return end

    local size = s.size or 160
    Minimap:SetSize(size, size)
    Minimap:ClearAllPoints()
    Minimap:SetPoint(s.point or "TOPRIGHT", UIParent, s.relPoint or "TOPRIGHT", s.x or -20, s.y or -20)

    if s.style == "square" then
        Minimap:SetMaskTexture("Interface\\ChatFrame\\ChatFrameBackground")
    else
        Minimap:SetMaskTexture("Textures\\MinimapMask")
    end

    if MinimapBorder then
        MinimapBorder:ClearAllPoints()
        MinimapBorder:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
        MinimapBorder:SetSize(size + 14, size + 14)
    end
    if MinimapBorderTop then
        MinimapBorderTop:ClearAllPoints()
        MinimapBorderTop:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
        MinimapBorderTop:SetSize(size + 14, size + 14)
    end

    if s.mouseWheelZoom then
        Minimap:EnableMouseWheel(true)
        Minimap:SetScript("OnMouseWheel", function(self, delta)
            if delta > 0 then
                if MinimapZoomIn then MinimapZoomIn:Click() end
            else
                if MinimapZoomOut then MinimapZoomOut:Click() end
            end
        end)
    end

    if s.hideZoom then
        if MinimapZoomIn then MinimapZoomIn:Hide() end
        if MinimapZoomOut then MinimapZoomOut:Hide() end
    end

    if s.hideTracking and MiniMapTracking then
        MiniMapTracking:Hide()
    end

    if s.hideClock and TimeManagerClockButton then
        TimeManagerClockButton:Hide()
    end

    if s.hideCalendar and GameTimeFrame then
        GameTimeFrame:Hide()
    end

    if s.hideWorldMapButton and MiniMapWorldMapButton then
        MiniMapWorldMapButton:Hide()
    end

    -- Re-apply mask after sizing to avoid ring drift in some UIs
    addon:DelayedCall(0.05, function()
        if s.style == "square" then
            Minimap:SetMaskTexture("Interface\\ChatFrame\\ChatFrameBackground")
        else
            Minimap:SetMaskTexture("Textures\\MinimapMask")
        end
    end)
end

function MinimapModule.OnInitialize()
    addon:Debug("Minimap module initializing")
end

function MinimapModule.OnEnable()
    addon:Debug("Minimap module enabling")
    ApplyMinimapSkin()
end

function MinimapModule.OnDisable()
    addon:Debug("Minimap module disabling")
end

function MinimapModule.CreateSettings(parent)
    local settings = addon.settings.minimap

    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Minimap")

    local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText("Configure minimap style, position, and visibility of elements.")
    desc:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    desc:SetJustifyH("LEFT")

    local yOffset = -70

    local enabledCb = addon:CreateCheckbox(parent)
    enabledCb:SetPoint("TOPLEFT", 16, yOffset)
    enabledCb.Text:SetText("Enable Minimap module")
    enabledCb:SetChecked(settings.enabled)
    enabledCb:SetScript("OnClick", function(self)
        addon:SetSetting("minimap.enabled", self:GetChecked())
        addon:PromptReloadUI()
    end)
    yOffset = yOffset - 30

    local styleLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    styleLabel:SetPoint("TOPLEFT", 16, yOffset)
    styleLabel:SetText("Style: round or square")
    yOffset = yOffset - 22

    local styleInput = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    styleInput:SetPoint("TOPLEFT", 16, yOffset)
    styleInput:SetSize(140, 20)
    styleInput:SetAutoFocus(false)
    styleInput:SetText(settings.style or "round")
    styleInput:SetScript("OnEnterPressed", function(self)
        addon:SetSetting("minimap.style", self:GetText())
        self:ClearFocus()
        addon:PromptReloadUI()
    end)
    yOffset = yOffset - 30

    local sizeSlider = addon:CreateSlider(parent)
    sizeSlider:SetPoint("TOPLEFT", 16, yOffset)
    sizeSlider:SetWidth(200)
    sizeSlider:SetMinMaxValues(120, 220)
    sizeSlider:SetValueStep(2)
    sizeSlider.Text:SetText("Size")
    sizeSlider.Low:SetText("120")
    sizeSlider.High:SetText("220")
    sizeSlider:SetValue(settings.size or 160)
    sizeSlider:SetScript("OnValueChanged", function(self, value)
        addon:SetSetting("minimap.size", math.floor(value + 0.5))
    end)
    yOffset = yOffset - 50

    local hideZoomCb = addon:CreateCheckbox(parent)
    hideZoomCb:SetPoint("TOPLEFT", 16, yOffset)
    hideZoomCb.Text:SetText("Hide zoom buttons")
    hideZoomCb:SetChecked(settings.hideZoom)
    hideZoomCb:SetScript("OnClick", function(self)
        addon:SetSetting("minimap.hideZoom", self:GetChecked())
        addon:PromptReloadUI()
    end)
    yOffset = yOffset - 22

    local hideTrackingCb = addon:CreateCheckbox(parent)
    hideTrackingCb:SetPoint("TOPLEFT", 16, yOffset)
    hideTrackingCb.Text:SetText("Hide tracking button")
    hideTrackingCb:SetChecked(settings.hideTracking)
    hideTrackingCb:SetScript("OnClick", function(self)
        addon:SetSetting("minimap.hideTracking", self:GetChecked())
        addon:PromptReloadUI()
    end)
    yOffset = yOffset - 22

    local hideClockCb = addon:CreateCheckbox(parent)
    hideClockCb:SetPoint("TOPLEFT", 16, yOffset)
    hideClockCb.Text:SetText("Hide clock")
    hideClockCb:SetChecked(settings.hideClock)
    hideClockCb:SetScript("OnClick", function(self)
        addon:SetSetting("minimap.hideClock", self:GetChecked())
        addon:PromptReloadUI()
    end)
    yOffset = yOffset - 22

    local hideCalendarCb = addon:CreateCheckbox(parent)
    hideCalendarCb:SetPoint("TOPLEFT", 16, yOffset)
    hideCalendarCb.Text:SetText("Hide calendar")
    hideCalendarCb:SetChecked(settings.hideCalendar)
    hideCalendarCb:SetScript("OnClick", function(self)
        addon:SetSetting("minimap.hideCalendar", self:GetChecked())
        addon:PromptReloadUI()
    end)
    yOffset = yOffset - 22

    local hideMapCb = addon:CreateCheckbox(parent)
    hideMapCb:SetPoint("TOPLEFT", 16, yOffset)
    hideMapCb.Text:SetText("Hide world map button")
    hideMapCb:SetChecked(settings.hideWorldMapButton)
    hideMapCb:SetScript("OnClick", function(self)
        addon:SetSetting("minimap.hideWorldMapButton", self:GetChecked())
        addon:PromptReloadUI()
    end)
end

addon:RegisterModule("Minimap", MinimapModule)
