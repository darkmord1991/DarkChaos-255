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
    { key = "showWorldBossPins", label = "Show world boss pins", desc = "Display world boss spawn markers on the maps." },
    { key = "showRarePins", label = "Show rare pins", desc = "Display rare mob spawn markers on the maps." },
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

local function Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[DC-Mapupgrades]|r " .. (msg or ""))
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
    local panel = CreateFrame("Frame", "DCMapupgradesOptionsPanel", container)
    panel.name = "DC Mapupgrades"
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
    title:SetText("DC Mapupgrades")

    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Configure XP hotspots and custom map pins (world bosses/rares).")

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

-- =====================================================================
-- Communication Sub-Panel
-- =====================================================================
function Options:CreateCommPanel()
    if not InterfaceOptions_AddCategory or not self.panel then return end
    if self.commPanel then return end
    
    local commPanel = CreateFrame('Frame', 'DCMapupgrades_CommOptions', self.panel)
    commPanel.name = 'Communication'
    commPanel.parent = self.panel.name
    commPanel:Hide()
    self.commPanel = commPanel
    
    local commTitle = commPanel:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
    commTitle:SetPoint('TOPLEFT', 16, -16)
    commTitle:SetText('Communication Settings')
    
    local commSubtitle = commPanel:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    commSubtitle:SetPoint('TOPLEFT', commTitle, 'BOTTOMLEFT', 0, -8)
    commSubtitle:SetText('Configure DCAddonProtocol communication for Hotspot tracking.')
    
    commPanel:SetScript('OnShow', function(panel)
        if panel._controlsCreated then return end
        panel._controlsCreated = true
        
        local y = -70
        local DC = rawget(_G, "DCAddonProtocol")
        local AIO = rawget(_G, "AIO")
        local db = Options.state and Options.state.db or {}
        
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
        y = y - 16
        
        local fallbackStatus = commPanel:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
        fallbackStatus:SetPoint('TOPLEFT', 24, y)
        local fallbackMode = (DC and "DCAddonProtocol") or (AIO and "AIO/Eluna") or "Chat Commands"
        fallbackStatus:SetText('Active Mode: |cFF00FFFF' .. fallbackMode .. '|r')
        y = y - 26
        
        -- JSON Toggle
        local jsonCheck = CreateFrame("CheckButton", "DCMapupgrades_Opt_JSONMode", commPanel, "InterfaceOptionsCheckButtonTemplate")
        jsonCheck:SetPoint("TOPLEFT", 16, y)
        jsonCheck:SetHitRectInsets(0, -200, 0, 0)
        _G["DCMapupgrades_Opt_JSONModeText"]:SetText("Use JSON Protocol (recommended)")
        jsonCheck:SetChecked(db.useDCProtocolJSON ~= false)
        jsonCheck:SetScript("OnClick", function(self)
            if Options.state and Options.state.db then
                Options.state.db.useDCProtocolJSON = self:GetChecked()
            end
            Print("JSON Protocol mode: " .. (self:GetChecked() and "ON" or "OFF"))
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
                Print("Testing: " .. text .. "...")
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
        makeTestButton("Request Hotspot List", "Send CMSG_GET_LIST (0x01) JSON", function()
            if addonTable.Core and addonTable.Core.RequestHotspotList then
                addonTable.Core:RequestHotspotList()
            elseif DC then
                DC:Request("SPOT", 0x01, {})
            else
                Print("|cFFFF0000No protocol available|r")
            end
        end, 1)
        makeTestButton("Request Hotspot Info", "Send CMSG_GET_INFO (0x02) JSON", function()
            if DC then DC:Request("SPOT", 0x02, { id = 1 }) else Print("|cFFFF0000DCAddonProtocol not available|r") end
        end, 2)
        btnRow = btnRow + 1
        
        -- Row 2
        makeTestButton("Request Teleport", "Send CMSG_TELEPORT (0x03) JSON", function()
            if DC then DC:Request("SPOT", 0x03, { id = 1 }) else Print("|cFFFF0000DCAddonProtocol not available|r") end
        end, 1)
        makeTestButton("Send Test JSON", "Send a test JSON message", function()
            if DC then
                DC:Request("SPOT", 0x00, { test = true, timestamp = time() })
                Print("Sent test JSON")
            else
                Print("|cFFFF0000DCAddonProtocol not available|r")
            end
        end, 2)
        btnRow = btnRow + 1
        
        -- Row 3
        makeTestButton("Ping Server", "Send CMSG_HANDSHAKE to test connectivity (JSON)", function()
            if DC then DC:Request("CORE", 0x01, { ping = true }); Print("Sent handshake (JSON)") else Print("|cFFFF0000DCAddonProtocol not available|r") end
        end, 1)
        makeTestButton("Chat Fallback Test", "Test .hotspot list command", function()
            -- Use the proper server command method
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox then
                local editBox = DEFAULT_CHAT_FRAME.editBox
                local oldText = editBox:GetText() or ""
                editBox:SetText(".hotspot list")
                ChatEdit_SendText(editBox)
                editBox:SetText(oldText)
            elseif ChatFrameEditBox then
                local oldText = ChatFrameEditBox:GetText() or ""
                ChatFrameEditBox:SetText(".hotspot list")
                ChatEdit_SendText(ChatFrameEditBox)
                ChatFrameEditBox:SetText(oldText)
            end
            Print("Sent .hotspot list via server command")
        end, 2)
        btnRow = btnRow + 1
        
        y = y - (btnRow * rowSpacing) - 20
        
        -- Results/Log Section
        local logHeader = commPanel:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
        logHeader:SetPoint('TOPLEFT', 16, y)
        logHeader:SetText('Protocol Fallback Chain')
        y = y - 20
        
        local fallbackDesc = commPanel:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
        fallbackDesc:SetPoint('TOPLEFT', 24, y)
        fallbackDesc:SetText('1. DCAddonProtocol (binary/JSON)')
        fallbackDesc:SetTextColor(0.8, 0.8, 0.8)
        y = y - 16
        
        local fallbackDesc2 = commPanel:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
        fallbackDesc2:SetPoint('TOPLEFT', 24, y)
        fallbackDesc2:SetText('2. AIO/Eluna (HOTSPOT_ADDON messages)')
        fallbackDesc2:SetTextColor(0.8, 0.8, 0.8)
        y = y - 16
        
        local fallbackDesc3 = commPanel:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
        fallbackDesc3:SetPoint('TOPLEFT', 24, y)
        fallbackDesc3:SetText('3. Chat Commands (.hotspot list)')
        fallbackDesc3:SetTextColor(0.8, 0.8, 0.8)
        y = y - 26
        
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
            local mode = (dc and "DCAddonProtocol") or (aio and "AIO/Eluna") or "Chat Commands"
            fallbackStatus:SetText('Active Mode: |cFF00FFFF' .. mode .. '|r')
            Print("Status refreshed")
        end)
    end)
    
    InterfaceOptions_AddCategory(commPanel)
end

return Options
