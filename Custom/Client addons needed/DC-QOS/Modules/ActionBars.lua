-- ============================================================
-- DC-QoS: Action Bars Module
-- ============================================================

local addon = DCQOS

local ActionBars = {
    displayName = "Action Bars",
    settingKey = "actionBars",
    icon = "Interface\\Icons\\Ability_Warrior_BattleShout",
}

local function GetSetting()
    return addon.settings.actionBars or {}
end

local function ApplyButtonLayout(prefix, parent, anchorPoint, relPoint, startX, startY, size, spacing, columns, rows)
    local index = 1
    for r = 1, rows do
        for c = 1, columns do
            local btn = _G[prefix .. index]
            if btn then
                btn:SetParent(parent)
                btn:ClearAllPoints()
                btn:SetSize(size, size)
                local x = startX + (c - 1) * (size + spacing)
                local y = startY - (r - 1) * (size + spacing)
                btn:SetPoint(anchorPoint, parent, relPoint, x, y)
                btn:Show()
            end
            index = index + 1
        end
    end
end

local function HideMainMenuArt()
    if MainMenuBarArtFrame then MainMenuBarArtFrame:Hide() end
    if MainMenuBarLeftEndCap then MainMenuBarLeftEndCap:Hide() end
    if MainMenuBarRightEndCap then MainMenuBarRightEndCap:Hide() end
    if MainMenuBarLeftEndCap and MainMenuBarRightEndCap then
        MainMenuBarLeftEndCap:Hide()
        MainMenuBarRightEndCap:Hide()
    end
end

local function ApplyBlizzardMode()
    local s = GetSetting()
    if not s.enabled then return end

    local scale = s.scale or 1
    MainMenuBar:SetScale(scale)

    local buttons = {
        "ActionButton",
        "MultiBarBottomLeftButton",
        "MultiBarBottomRightButton",
        "MultiBarRightButton",
        "MultiBarLeftButton",
    }

    for _, prefix in ipairs(buttons) do
        for i = 1, 12 do
            local btn = _G[prefix .. i]
            if btn then
                btn:SetScale(scale)
            end
        end
    end

    if s.showMainBar == false then MainMenuBar:Hide() else MainMenuBar:Show() end
    if s.showBottomLeft == false and MultiBarBottomLeft then MultiBarBottomLeft:Hide() else if MultiBarBottomLeft then MultiBarBottomLeft:Show() end end
    if s.showBottomRight == false and MultiBarBottomRight then MultiBarBottomRight:Hide() else if MultiBarBottomRight then MultiBarBottomRight:Show() end end
    if s.showRightBar1 == false and MultiBarRight then MultiBarRight:Hide() else if MultiBarRight then MultiBarRight:Show() end end
    if s.showRightBar2 == false and MultiBarLeft then MultiBarLeft:Hide() else if MultiBarLeft then MultiBarLeft:Show() end end
end

local function ApplyCustomMode()
    local s = GetSetting()
    if not s.enabled then return end

    local size = s.buttonSize or 32
    local spacing = s.spacing or 4

    if not ActionBars.customFrames then
        ActionBars.customFrames = {}
    end

    local anchor = s.customAnchor or { point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = 40 }

    if not ActionBars.customFrames.main then
        ActionBars.customFrames.main = CreateFrame("Frame", "DCQOS_CustomBar_Main", UIParent)
    end
    local main = ActionBars.customFrames.main
    main:SetPoint(anchor.point, UIParent, anchor.relPoint, anchor.x, anchor.y)

    HideMainMenuArt()

    if s.showMainBar ~= false then
        ApplyButtonLayout("ActionButton", main, "BOTTOMLEFT", "BOTTOMLEFT", 0, 0, size, spacing, 12, 1)
        main:Show()
    else
        main:Hide()
    end

    if not ActionBars.customFrames.bottomLeft then
        ActionBars.customFrames.bottomLeft = CreateFrame("Frame", "DCQOS_CustomBar_BottomLeft", UIParent)
    end
    local bottomLeft = ActionBars.customFrames.bottomLeft
    bottomLeft:SetPoint("TOPLEFT", main, "BOTTOMLEFT", 0, -spacing)

    if s.showBottomLeft ~= false then
        ApplyButtonLayout("MultiBarBottomLeftButton", bottomLeft, "BOTTOMLEFT", "BOTTOMLEFT", 0, 0, size, spacing, 12, 1)
        bottomLeft:Show()
    else
        bottomLeft:Hide()
    end

    if not ActionBars.customFrames.bottomRight then
        ActionBars.customFrames.bottomRight = CreateFrame("Frame", "DCQOS_CustomBar_BottomRight", UIParent)
    end
    local bottomRight = ActionBars.customFrames.bottomRight
    bottomRight:SetPoint("TOPLEFT", bottomLeft, "BOTTOMLEFT", 0, -spacing)

    if s.showBottomRight ~= false then
        ApplyButtonLayout("MultiBarBottomRightButton", bottomRight, "BOTTOMLEFT", "BOTTOMLEFT", 0, 0, size, spacing, 12, 1)
        bottomRight:Show()
    else
        bottomRight:Hide()
    end

    if not ActionBars.customFrames.right1 then
        ActionBars.customFrames.right1 = CreateFrame("Frame", "DCQOS_CustomBar_Right1", UIParent)
    end
    local right1 = ActionBars.customFrames.right1
    right1:SetPoint("RIGHT", UIParent, "RIGHT", -10, 0)

    if s.showRightBar1 ~= false then
        ApplyButtonLayout("MultiBarRightButton", right1, "TOPLEFT", "TOPLEFT", 0, 0, size, spacing, 1, 12)
        right1:Show()
    else
        right1:Hide()
    end

    if not ActionBars.customFrames.right2 then
        ActionBars.customFrames.right2 = CreateFrame("Frame", "DCQOS_CustomBar_Right2", UIParent)
    end
    local right2 = ActionBars.customFrames.right2
    right2:SetPoint("RIGHT", right1, "LEFT", -(size + spacing), 0)

    if s.showRightBar2 ~= false then
        ApplyButtonLayout("MultiBarLeftButton", right2, "TOPLEFT", "TOPLEFT", 0, 0, size, spacing, 1, 12)
        right2:Show()
    else
        right2:Hide()
    end
end

local function ApplyActionBars()
    local s = GetSetting()
    if not s.enabled then return end
    if s.mode == "custom" then
        ApplyCustomMode()
    else
        ApplyBlizzardMode()
    end
end

function ActionBars.OnInitialize()
    addon:Debug("ActionBars module initializing")
end

function ActionBars.OnEnable()
    addon:Debug("ActionBars module enabling")
    ApplyActionBars()

    if not ActionBars.eventFrame then
        local ev = CreateFrame("Frame")
        ev:RegisterEvent("PLAYER_ENTERING_WORLD")
        ev:RegisterEvent("UNIT_ENTERED_VEHICLE")
        ev:RegisterEvent("UNIT_EXITED_VEHICLE")
        ev:RegisterEvent("ACTIONBAR_UPDATE_STATE")
        ev:RegisterEvent("ACTIONBAR_UPDATE_USABLE")
        ev:SetScript("OnEvent", function(_, event, unit)
            if unit and unit ~= "player" then return end
            addon:DelayedCall(0.2, function()
                ApplyActionBars()
            end)
        end)
        ActionBars.eventFrame = ev
    end
end

function ActionBars.OnDisable()
    addon:Debug("ActionBars module disabling")
end

function ActionBars.CreateSettings(parent)
    local settings = addon.settings.actionBars

    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Action Bars")

    local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText("Configure action bar layout and styling. Changes may require /reload.")
    desc:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    desc:SetJustifyH("LEFT")

    local yOffset = -70

    local enabledCb = addon:CreateCheckbox(parent)
    enabledCb:SetPoint("TOPLEFT", 16, yOffset)
    enabledCb.Text:SetText("Enable Action Bars module")
    enabledCb:SetChecked(settings.enabled)
    enabledCb:SetScript("OnClick", function(self)
        addon:SetSetting("actionBars.enabled", self:GetChecked())
        addon:PromptReloadUI()
    end)
    yOffset = yOffset - 30

    local modeLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    modeLabel:SetPoint("TOPLEFT", 16, yOffset)
    modeLabel:SetText("Mode: Blizzard or Custom")
    yOffset = yOffset - 22

    local modeInput = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    modeInput:SetPoint("TOPLEFT", 16, yOffset)
    modeInput:SetSize(140, 20)
    modeInput:SetAutoFocus(false)
    modeInput:SetText(settings.mode or "blizzard")
    modeInput:SetScript("OnEnterPressed", function(self)
        addon:SetSetting("actionBars.mode", self:GetText())
        self:ClearFocus()
        addon:PromptReloadUI()
    end)
    yOffset = yOffset - 30

    local sizeSlider = addon:CreateSlider(parent)
    sizeSlider:SetPoint("TOPLEFT", 16, yOffset)
    sizeSlider:SetWidth(200)
    sizeSlider:SetMinMaxValues(20, 48)
    sizeSlider:SetValueStep(1)
    sizeSlider.Text:SetText("Button Size")
    sizeSlider.Low:SetText("20")
    sizeSlider.High:SetText("48")
    sizeSlider:SetValue(settings.buttonSize or 32)
    sizeSlider:SetScript("OnValueChanged", function(self, value)
        addon:SetSetting("actionBars.buttonSize", math.floor(value + 0.5))
    end)
    yOffset = yOffset - 50

    local spacingSlider = addon:CreateSlider(parent)
    spacingSlider:SetPoint("TOPLEFT", 16, yOffset)
    spacingSlider:SetWidth(200)
    spacingSlider:SetMinMaxValues(0, 12)
    spacingSlider:SetValueStep(1)
    spacingSlider.Text:SetText("Spacing")
    spacingSlider.Low:SetText("0")
    spacingSlider.High:SetText("12")
    spacingSlider:SetValue(settings.spacing or 4)
    spacingSlider:SetScript("OnValueChanged", function(self, value)
        addon:SetSetting("actionBars.spacing", math.floor(value + 0.5))
    end)
    yOffset = yOffset - 50

    local scaleSlider = addon:CreateSlider(parent)
    scaleSlider:SetPoint("TOPLEFT", 16, yOffset)
    scaleSlider:SetWidth(200)
    scaleSlider:SetMinMaxValues(0.7, 1.5)
    scaleSlider:SetValueStep(0.05)
    scaleSlider.Text:SetText("Bar Scale")
    scaleSlider.Low:SetText("0.7")
    scaleSlider.High:SetText("1.5")
    scaleSlider:SetValue(settings.scale or 1.0)
    scaleSlider:SetScript("OnValueChanged", function(self, value)
        addon:SetSetting("actionBars.scale", value)
    end)
    yOffset = yOffset - 50

    local showMain = addon:CreateCheckbox(parent)
    showMain:SetPoint("TOPLEFT", 16, yOffset)
    showMain.Text:SetText("Show Main Bar")
    showMain:SetChecked(settings.showMainBar ~= false)
    showMain:SetScript("OnClick", function(self)
        addon:SetSetting("actionBars.showMainBar", self:GetChecked())
    end)
    yOffset = yOffset - 22

    local showBL = addon:CreateCheckbox(parent)
    showBL:SetPoint("TOPLEFT", 16, yOffset)
    showBL.Text:SetText("Show Bottom Left Bar")
    showBL:SetChecked(settings.showBottomLeft ~= false)
    showBL:SetScript("OnClick", function(self)
        addon:SetSetting("actionBars.showBottomLeft", self:GetChecked())
    end)
    yOffset = yOffset - 22

    local showBR = addon:CreateCheckbox(parent)
    showBR:SetPoint("TOPLEFT", 16, yOffset)
    showBR.Text:SetText("Show Bottom Right Bar")
    showBR:SetChecked(settings.showBottomRight ~= false)
    showBR:SetScript("OnClick", function(self)
        addon:SetSetting("actionBars.showBottomRight", self:GetChecked())
    end)
    yOffset = yOffset - 22

    local showR1 = addon:CreateCheckbox(parent)
    showR1:SetPoint("TOPLEFT", 16, yOffset)
    showR1.Text:SetText("Show Right Bar 1")
    showR1:SetChecked(settings.showRightBar1 ~= false)
    showR1:SetScript("OnClick", function(self)
        addon:SetSetting("actionBars.showRightBar1", self:GetChecked())
    end)
    yOffset = yOffset - 22

    local showR2 = addon:CreateCheckbox(parent)
    showR2:SetPoint("TOPLEFT", 16, yOffset)
    showR2.Text:SetText("Show Right Bar 2")
    showR2:SetChecked(settings.showRightBar2 ~= false)
    showR2:SetScript("OnClick", function(self)
        addon:SetSetting("actionBars.showRightBar2", self:GetChecked())
    end)
end

addon:RegisterModule("ActionBars", ActionBars)
