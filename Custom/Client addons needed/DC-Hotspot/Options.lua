local addonName, addonTable = ...
addonTable = addonTable or {}

local Options = {}
addonTable.Options = Options

local ICON_CHOICES = {
    { value = "xp",      label = "Golden Orb (XP Bonus)" },
    { value = "star",    label = "Yellow Star" },
    { value = "diamond", label = "Purple Diamond" },
    { value = "circle",  label = "Orange Circle" },
    { value = "flame",   label = "Fire" },
    { value = "arcane",  label = "Arcane Energy" },
    { value = "treasure",label = "Treasure Bag" },
    { value = "quest",   label = "Quest Note" },
    { value = "map",     label = "Classic Map Icon" },
    { value = "target",  label = "Target Reticle" },
    { value = "skull",   label = "Raid Skull" },
    { value = "spell",   label = "Server/Spell Texture" },
    { value = "custom",  label = "Custom Texture Path" },
}

local CHECKBOXES = {
    { key = "showMinimapPins", label = "Show minimap pins", desc = "Display hotspot markers on the minimap." },
    { key = "showWorldPins", label = "Show world map pins", desc = "Display hotspot markers on the world map." },
    { key = "showWorldLabels", label = "Show world pin labels", desc = "Render bonus text beneath each world map pin." },
    { key = "showPopup", label = "Show spawn popup", desc = "Play the banner + sound when a hotspot is announced." },
    { key = "announce", label = "Announce in chat", desc = "Print chat messages when hotspots spawn." },
    { key = "announceExpire", label = "Announce expiry", desc = "Print chat messages when hotspots expire." },
    { key = "lockWorldMap", label = "Prevent world map hijack", desc = "Do not auto-switch the world map back to your current zone while it is open." },
    { key = "showAllMaps", label = "Show all hotspots on any map", desc = "Ignore map matching and show all hotspots on every map (useful for testing)." },
    { key = "debug", label = "Debug mode", desc = "Show diagnostic messages in chat to help troubleshoot issues." },
}

local function PlayCheckboxSound(checked)
    if PlaySound then
        local sound = checked and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff"
        PlaySound(sound)
    end
end

function Options:Init(state)
    self.state = state
    if not InterfaceOptions_AddCategory then
        return
    end
    if self.panel then
        return
    end

    local container = InterfaceOptionsFramePanelContainer or UIParent
    local panel = CreateFrame("Frame", "DCHotspotOptionsPanel", container)
    panel.name = "DC Hotspot"
    panel:Hide()

    panel:SetScript("OnShow", function(frame)
        if not frame.initialized then
            Options:Build(frame)
            frame.initialized = true
        end
        Options:RefreshWidgets()
    end)

    self.panel = panel
    InterfaceOptions_AddCategory(panel)
end

function Options:Build(panel)
    self.widgets = self.widgets or {}

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    title:SetText("DC Hotspot")

    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Configure how hotspots render on your maps and announcements.")

    local anchorY = -60
    for _, entry in ipairs(CHECKBOXES) do
        local cb = CreateFrame("CheckButton", panel:GetName() .. entry.key .. "Check", panel, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, anchorY)
        local textWidget = cb.Text or _G[cb:GetName() .. "Text"]
        if not textWidget then
            textWidget = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            textWidget:SetPoint("LEFT", cb, "RIGHT", 0, 1)
        end
        textWidget:SetText(entry.label)
        cb.Text = textWidget
        cb.tooltipText = entry.desc
        cb:SetScript("OnClick", function(selfBtn)
            Options:SetBool(entry.key, selfBtn:GetChecked())
            PlayCheckboxSound(selfBtn:GetChecked())
        end)
        self.widgets[entry.key] = cb
        anchorY = anchorY - 30
    end

    local dropdown = CreateFrame("Frame", panel:GetName() .. "IconDropdown", panel, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", panel, "TOPLEFT", -14, anchorY - 10)
    UIDropDownMenu_SetWidth(dropdown, 220)
    dropdown.label = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    dropdown.label:SetPoint("BOTTOMLEFT", dropdown, "TOPLEFT", 16, 3)
    dropdown.label:SetText("Hotspot pin icon")

    UIDropDownMenu_Initialize(dropdown, function(frame, level)
        local info = UIDropDownMenu_CreateInfo()
        for _, option in ipairs(ICON_CHOICES) do
            info = UIDropDownMenu_CreateInfo()
            info.text = option.label
            info.value = option.value
            info.func = function(selfBtn)
                Options:SetIconStyle(option.value)
            end
            local db = Options.state and Options.state.db or {}
            info.checked = (db.pinIconStyle or "spell") == option.value
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    self.widgets.iconDropdown = dropdown

    local editBox = CreateFrame("EditBox", panel:GetName() .. "CustomIconInput", panel, "InputBoxTemplate")
    editBox:SetAutoFocus(false)
    editBox:SetSize(280, 20)
    editBox:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 25, -10)
    editBox:SetScript("OnEnterPressed", function(selfBox)
        Options:SetCustomIcon(selfBox:GetText())
        selfBox:ClearFocus()
    end)
    editBox:SetScript("OnEditFocusLost", function(selfBox)
        Options:SetCustomIcon(selfBox:GetText())
    end)
    editBox:SetScript("OnEscapePressed", function(selfBox)
        selfBox:ClearFocus()
        Options:RefreshWidgets()
    end)

    local editLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    editLabel:SetPoint("BOTTOMLEFT", editBox, "TOPLEFT", 0, 2)
    editLabel:SetText("Custom texture path (Interface\\...)")

    self.widgets.customIconBox = editBox
    self.widgets.customIconLabel = editLabel
end

function Options:SetBool(key, value)
    if not self.state or not self.state.db then return end
    self.state.db[key] = not not value
    self:OnSettingChanged()
end

function Options:SetIconStyle(value)
    if not self.state or not self.state.db then return end
    self.state.db.pinIconStyle = value or "spell"
    self:OnSettingChanged()
end

function Options:SetCustomIcon(value)
    if not self.state or not self.state.db then return end
    self.state.db.customIconTexture = value or ""
    self:OnSettingChanged()
end

function Options:OnSettingChanged()
    if addonTable.Core and addonTable.Core.RefreshVisuals then
        addonTable.Core:RefreshVisuals()
    elseif addonTable.Pins and addonTable.Pins.Refresh then
        addonTable.Pins:Refresh()
    end
    self:RefreshWidgets()
end

function Options:RefreshWidgets()
    if not self.state or not self.state.db or not self.widgets then
        return
    end
    local db = self.state.db
    for _, entry in ipairs(CHECKBOXES) do
        local widget = self.widgets[entry.key]
        if widget then
            widget:SetChecked(db[entry.key])
        end
    end
    if self.widgets.iconDropdown then
        local current = db.pinIconStyle or "spell"
        UIDropDownMenu_SetSelectedValue(self.widgets.iconDropdown, current)
        for _, option in ipairs(ICON_CHOICES) do
            if option.value == current then
                UIDropDownMenu_SetText(self.widgets.iconDropdown, option.label)
                break
            end
        end
    end
    if self.widgets.customIconBox then
        local enabled = (db.pinIconStyle == "custom")
        self.widgets.customIconBox:SetText(db.customIconTexture or "")
        if self.widgets.customIconBox.SetEnabled then
            self.widgets.customIconBox:SetEnabled(enabled)
        else
            self.widgets.customIconBox:EnableMouse(enabled)
            self.widgets.customIconBox:EnableKeyboard(enabled)
            self.widgets.customIconBox:SetAlpha(enabled and 1 or 0.5)
        end
        if self.widgets.customIconLabel then
            if enabled then
                self.widgets.customIconLabel:SetTextColor(1, 1, 1)
            else
                self.widgets.customIconLabel:SetTextColor(0.6, 0.6, 0.6)
            end
        end
    end
end

function Options:Open()
    if not self.panel or not InterfaceOptionsFrame_OpenToCategory then
        return
    end
    InterfaceOptionsFrame_OpenToCategory(self.panel)
    InterfaceOptionsFrame_OpenToCategory(self.panel)
end

return Options
