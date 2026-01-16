-- ============================================================
-- DC-QoS: Profiles Module
-- ============================================================

local addon = DCQOS

local Profiles = {
    displayName = "Profiles",
    settingKey = "profiles",
    icon = "Interface\\Icons\\INV_Misc_Note_02",
}

local function BuildProfileList()
    local names = {}
    if addon.db and addon.db.profiles then
        for name in pairs(addon.db.profiles) do
            table.insert(names, name)
        end
    end
    table.sort(names)
    return names
end

function Profiles.CreateSettings(parent)
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Profiles")

    local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText("Create, switch, export and import DC-QoS profiles.")
    desc:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    desc:SetJustifyH("LEFT")

    local yOffset = -70

    local currentLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    currentLabel:SetPoint("TOPLEFT", 16, yOffset)
    currentLabel:SetText("Active Profile: " .. (addon.activeProfile or "Default"))
    yOffset = yOffset - 30

    local nameLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    nameLabel:SetPoint("TOPLEFT", 16, yOffset)
    nameLabel:SetText("Profile Name")
    yOffset = yOffset - 20

    local nameInput = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    nameInput:SetPoint("TOPLEFT", 16, yOffset)
    nameInput:SetSize(180, 20)
    nameInput:SetAutoFocus(false)
    yOffset = yOffset - 30

    local createBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    createBtn:SetPoint("TOPLEFT", 16, yOffset)
    createBtn:SetSize(80, 22)
    createBtn:SetText("Create")
    createBtn:SetScript("OnClick", function()
        local name = nameInput:GetText()
        if addon:CreateProfile(name, addon.activeProfile) then
            currentLabel:SetText("Active Profile: " .. (addon.activeProfile or "Default"))
            addon:Print("Profile created: " .. name, true)
        else
            addon:Print("Profile already exists or invalid name.", true)
        end
    end)

    local deleteBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    deleteBtn:SetPoint("LEFT", createBtn, "RIGHT", 6, 0)
    deleteBtn:SetSize(80, 22)
    deleteBtn:SetText("Delete")
    deleteBtn:SetScript("OnClick", function()
        local name = nameInput:GetText()
        if addon:DeleteProfile(name) then
            currentLabel:SetText("Active Profile: " .. (addon.activeProfile or "Default"))
            addon:Print("Profile deleted: " .. name, true)
        else
            addon:Print("Unable to delete profile.", true)
        end
    end)

    local setCharBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    setCharBtn:SetPoint("LEFT", deleteBtn, "RIGHT", 6, 0)
    setCharBtn:SetSize(110, 22)
    setCharBtn:SetText("Set (Char)")
    setCharBtn:SetScript("OnClick", function()
        local name = nameInput:GetText()
        if name and name ~= "" then
            addon:SetActiveProfile(name, true)
            currentLabel:SetText("Active Profile: " .. (addon.activeProfile or "Default"))
        end
    end)

    local setGlobalBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    setGlobalBtn:SetPoint("LEFT", setCharBtn, "RIGHT", 6, 0)
    setGlobalBtn:SetSize(110, 22)
    setGlobalBtn:SetText("Set (Global)")
    setGlobalBtn:SetScript("OnClick", function()
        local name = nameInput:GetText()
        if name and name ~= "" then
            addon:SetActiveProfile(name, false)
            currentLabel:SetText("Active Profile: " .. (addon.activeProfile or "Default"))
        end
    end)

    yOffset = yOffset - 40

    local exportLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    exportLabel:SetPoint("TOPLEFT", 16, yOffset)
    exportLabel:SetText("Export / Import")
    yOffset = yOffset - 20

    local dataBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    dataBox:SetPoint("TOPLEFT", 16, yOffset)
    dataBox:SetSize(420, 24)
    dataBox:SetAutoFocus(false)
    dataBox:SetTextInsets(4, 4, 0, 0)
    dataBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)

    yOffset = yOffset - 30

    local exportBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    exportBtn:SetPoint("TOPLEFT", 16, yOffset)
    exportBtn:SetSize(80, 22)
    exportBtn:SetText("Export")
    exportBtn:SetScript("OnClick", function()
        local name = nameInput:GetText()
        if name and name ~= "" then
            local data = addon:ExportProfile(name)
            if data then
                dataBox:SetText(data)
                dataBox:HighlightText()
            end
        end
    end)

    local importBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    importBtn:SetPoint("LEFT", exportBtn, "RIGHT", 6, 0)
    importBtn:SetSize(80, 22)
    importBtn:SetText("Import")
    importBtn:SetScript("OnClick", function()
        local name = nameInput:GetText()
        local data = dataBox:GetText()
        if addon:ImportProfile(name, data) then
            addon:Print("Profile imported: " .. name, true)
        else
            addon:Print("Profile import failed.", true)
        end
    end)

    local listLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    listLabel:SetPoint("LEFT", importBtn, "RIGHT", 10, 0)
    listLabel:SetText("Profiles: " .. table.concat(BuildProfileList(), ", "))
end

addon:RegisterModule("Profiles", Profiles)
