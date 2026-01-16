-- ============================================================
-- DC-QoS: Minimap Module
-- ============================================================

local addon = DCQOS

local MinimapModule = {
    displayName = "Minimap",
    settingKey = "minimap",
    icon = "Interface\\Icons\\INV_Misc_Map_01",
}

local function EnsureDcMinimapFrame()
    if Minimap.DCQOSFrame then
        return Minimap.DCQOSFrame
    end

    local parent = MinimapCluster or (Minimap and Minimap:GetParent()) or UIParent
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -5, 5)
    f:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", 5, -5)
    f:SetFrameStrata(Minimap:GetFrameStrata() or "MEDIUM")
    local mmLevel = Minimap:GetFrameLevel() or 1
    f:SetFrameLevel(math.max(0, mmLevel - 1))

    f:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    -- Fill the square area behind the round minimap (corners) with black.
    f:SetBackdropColor(0, 0, 0, 0.85)
    f:SetBackdropBorderColor(1, 1, 1, 1)

    Minimap.DCQOSFrame = f
    return f
end

local function PositionLeftMinimapButtons(container)
    if not container then return end

    local buttons = {
        MiniMapTracking,
        MiniMapBattlefieldFrame,
        MiniMapWorldMapButton,
        GameTimeFrame,
        MiniMapMailFrame,
        MinimapZoomIn,
        MinimapZoomOut,
    }

    local x = 8
    local y = -32
    local step = 26

    for _, b in ipairs(buttons) do
        if b and b.ClearAllPoints and b.SetPoint then
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", container, "TOPLEFT", x, y)
            y = y - step
        end
    end

    -- Keep the clock where Blizzard expects (bottom). Only re-anchor if it's floating.
    if TimeManagerClockButton and TimeManagerClockButton.ClearAllPoints and TimeManagerClockButton.SetPoint then
        -- If the user prefers the clock centered under the minimap, leave it.
        -- We avoid forcing it into the left column.
    end
end

local function ApplyMinimapSkin()
    local s = addon.settings.minimap
    if not s.enabled then return end

    local useDcFrame = (s.useDcFrame ~= false)
    local fillFrame = useDcFrame and (s.fillFrame ~= false)
    local disableRotate = (s.disableRotate ~= false)

    local size = s.size or 160
    local baseSize = Minimap:GetWidth() or 140
    local scale = size / baseSize

    if MinimapCluster then
        MinimapCluster:ClearAllPoints()
        if s.useBlizzardPosition ~= false then
            -- Nudge closer to the screen edge when using legacy/default offsets.
            local posX = s.x
            if posX == nil or posX == -20 or posX == -4 then
                posX = -2
            end

            local posY = s.y
            if posY == nil or posY == -20 then
                posY = -32
            end

            MinimapCluster:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", posX, posY)
        else
            MinimapCluster:SetPoint(s.point or "TOPRIGHT", UIParent, s.relPoint or "TOPRIGHT", s.x or -20, s.y or -20)
        end
        MinimapCluster:SetScale(scale)
    end

    -- Rotating minimap + square mask looks like the entire map is spinning/tilting (diamond effect).
    -- If desired, force north-up while our framed minimap is enabled.
    if disableRotate and SetCVar and GetCVar then
        if GetCVar("rotateMinimap") == "1" then
            SetCVar("rotateMinimap", "0")
        end
    end

    -- Important: avoid re-anchoring/resizing Minimap itself. The Blizzard UI (and many addons)
    -- assume Minimap stays positioned inside MinimapCluster. We only move/scale MinimapCluster.

    if fillFrame or s.style == "square" then
        Minimap:SetMaskTexture("Interface\\ChatFrame\\ChatFrameBackground")
    else
        Minimap:SetMaskTexture("Textures\\MinimapMask")
    end

    if s.style == "round" and not fillFrame then
        if MinimapBackdrop then MinimapBackdrop:Hide() end
        if useDcFrame then
            local frame = EnsureDcMinimapFrame()
            frame:Show()
            if MinimapBorder then MinimapBorder:Hide() end
            PositionLeftMinimapButtons(frame)
        else
            if Minimap.DCQOSFrame then Minimap.DCQOSFrame:Hide() end
            if MinimapBorder then
                MinimapBorder:SetAlpha(1)
                MinimapBorder:Show()
            end
        end
        -- Keep the default top border visible in round mode (zone text frame). We only ever hide it
        -- when switching to a square mask.
        if MinimapBorderTop then MinimapBorderTop:Show() end

        -- Ensure addons that query shape behave correctly.
        _G.GetMinimapShape = function() return "ROUND" end
    else
        if useDcFrame then
            local frame = EnsureDcMinimapFrame()
            frame:Show()
            PositionLeftMinimapButtons(frame)
        else
            if Minimap.DCQOSFrame then Minimap.DCQOSFrame:Hide() end
        end

        if MinimapBorder then MinimapBorder:Hide() end
        -- Keep zone text frame visible; the DC frame handles the border now.
        if MinimapBorderTop then MinimapBorderTop:Show() end
        if MinimapBackdrop then
            if useDcFrame then
                MinimapBackdrop:Hide()
            else
                MinimapBackdrop:Show()
            end
        end

        _G.GetMinimapShape = function() return "SQUARE" end
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
    else
        if MinimapZoomIn then MinimapZoomIn:Show() end
        if MinimapZoomOut then MinimapZoomOut:Show() end
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
        if MiniMapWorldMapButton.UnregisterAllEvents then
            MiniMapWorldMapButton:UnregisterAllEvents()
        end
    end

    -- Re-apply mask after sizing to avoid ring drift in some UIs
    addon:DelayedCall(0.05, function()
        if fillFrame or s.style == "square" then
            Minimap:SetMaskTexture("Interface\\ChatFrame\\ChatFrameBackground")
        else
            Minimap:SetMaskTexture("Textures\\MinimapMask")
        end

        if useDcFrame then
            local frame = EnsureDcMinimapFrame()
            frame:Show()
            PositionLeftMinimapButtons(frame)
        elseif Minimap.DCQOSFrame then
            Minimap.DCQOSFrame:Hide()
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

    local fillCb = addon:CreateCheckbox(parent)
    fillCb:SetPoint("TOPLEFT", 16, yOffset)
    fillCb.Text:SetText("Fill the frame (square minimap)")
    fillCb:SetChecked(settings.fillFrame ~= false)
    fillCb:SetScript("OnClick", function(self)
        addon:SetSetting("minimap.fillFrame", self:GetChecked())
        addon:PromptReloadUI()
    end)
    yOffset = yOffset - 22

    local rotateCb = addon:CreateCheckbox(parent)
    rotateCb:SetPoint("TOPLEFT", 16, yOffset)
    rotateCb.Text:SetText("Disable rotating minimap (north-up)")
    rotateCb:SetChecked(settings.disableRotate ~= false)
    rotateCb:SetScript("OnClick", function(self)
        addon:SetSetting("minimap.disableRotate", self:GetChecked())
        addon:PromptReloadUI()
    end)
    yOffset = yOffset - 22

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
    yOffset = yOffset - 22

    local blizzPosCb = addon:CreateCheckbox(parent)
    blizzPosCb:SetPoint("TOPLEFT", 16, yOffset)
    blizzPosCb.Text:SetText("Use Blizzard position (top-right)")
    blizzPosCb:SetChecked(settings.useBlizzardPosition ~= false)
    blizzPosCb:SetScript("OnClick", function(self)
        addon:SetSetting("minimap.useBlizzardPosition", self:GetChecked())
        addon:PromptReloadUI()
    end)
    yOffset = yOffset - 22

    local spacingSlider = addon:CreateSlider(parent)
    spacingSlider:SetPoint("TOPLEFT", 16, yOffset)
    spacingSlider:SetWidth(200)
    spacingSlider:SetMinMaxValues(16, 40)
    spacingSlider:SetValueStep(1)
    spacingSlider.Text:SetText("Button spacing")
    spacingSlider.Low:SetText("16")
    spacingSlider.High:SetText("40")
    spacingSlider:SetValue(settings.buttonSpacing or 22)
    spacingSlider:SetScript("OnValueChanged", function(self, value)
        addon:SetSetting("minimap.buttonSpacing", math.floor(value + 0.5))
    end)
end

addon:RegisterModule("Minimap", MinimapModule)
