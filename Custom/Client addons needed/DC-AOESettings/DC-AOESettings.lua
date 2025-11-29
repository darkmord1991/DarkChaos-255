-- ============================================================
-- DarkChaos AoE Loot Settings Addon
-- ============================================================
-- A lightweight WoW 3.3.5a addon for managing AoE loot settings
-- Integrates with Interface -> AddOns menu
-- Uses DCAddonProtocol for server communication (with fallback)
-- ============================================================

-- Create the addon namespace
DCAoELootSettings = DCAoELootSettings or {}
local addon = DCAoELootSettings

-- Addon info
addon.name = "DC-AOESettings"
addon.version = "1.1.0"
addon.prefix = "DCAOE"  -- Legacy prefix (fallback)

-- DCAddonProtocol integration
local DC = rawget(_G, "DCAddonProtocol")
addon.useDCProtocol = (DC ~= nil)

-- Helper function to clamp a value within a range (defined early for use throughout)
local function Clamp(value, minVal, maxVal)
    if value == nil then return minVal end
    if value < minVal then return minVal end
    if value > maxVal then return maxVal end
    return value
end

-- Settings defaults
addon.defaults = {
    enabled = true,
    showMessages = true, -- Toggle for debug/info messages
    minQuality = 0,      -- 0=Poor, 1=Common, 2=Uncommon, 3=Rare, 4=Epic, 5=Legendary
    autoSkin = true,
    smartLoot = true,
    autoVendorPoor = false,
    -- Note: Range is controlled by server config, not per-player
}

-- Current settings (loaded from SavedVariables)
addon.settings = {}

-- Quality names for display
addon.qualityNames = {
    [0] = "|cff9d9d9dPoor|r",
    [1] = "|cffffffffCommon|r",
    [2] = "|cff1eff00Uncommon|r",
    [3] = "|cff0070ddRare|r",
    [4] = "|cffa335eeEpic|r",
    [5] = "|cffff8000Legendary|r",
}

-- UI elements
addon.frame = nil
addon.checkboxes = {}
addon.optionsPanel = nil -- For Interface Options

-- Message helper - respects showMessages setting
function addon:Print(msg, forceShow)
    if forceShow or self.settings.showMessages then
        print("|cff00ff00[DC AoE Loot]|r " .. msg)
    end
end

-- Confirmation message helper - always shows for user actions
function addon:Confirm(settingName, value)
    local valueStr
    if type(value) == "boolean" then
        valueStr = value and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r"
    elseif type(value) == "number" then
        valueStr = "|cffffd700" .. value .. "|r"
    else
        valueStr = "|cffffd700" .. tostring(value) .. "|r"
    end
    print("|cff00ff00[DC AoE Loot]|r " .. settingName .. " set to " .. valueStr)
end

-- ============================================================
-- 3.3.5a Compatibility - Timer replacement
-- ============================================================
local function DelayedCall(delay, func)
    local frame = CreateFrame("Frame")
    local elapsed = 0
    frame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed >= delay then
            self:SetScript("OnUpdate", nil)
            func()
        end
    end)
end

-- ============================================================
-- SavedVariables Management
-- ============================================================
function addon:LoadSettings()
    -- Load from SavedVariables or use defaults
    if DCAoELootSettingsDB then
        for k, v in pairs(self.defaults) do
            if DCAoELootSettingsDB[k] ~= nil then
                self.settings[k] = DCAoELootSettingsDB[k]
            else
                self.settings[k] = v
            end
        end
    else
        for k, v in pairs(self.defaults) do
            self.settings[k] = v
        end
    end
    
    -- Validate loaded settings to ensure they're within valid ranges
    self.settings.minQuality = Clamp(self.settings.minQuality or 0, 0, 5)
end

function addon:SaveSettingsLocal()
    -- Save to SavedVariables
    if not DCAoELootSettingsDB then
        DCAoELootSettingsDB = {}
    end
    for k, v in pairs(self.settings) do
        DCAoELootSettingsDB[k] = v
    end
end

-- ============================================================
-- Server Command Helpers (send settings via chat commands)
-- ============================================================
function addon:SendServerCommand(cmd)
    -- Execute the command as if the player typed it in chat
    -- This works for server commands starting with . in WoW 3.3.5a
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox then
        local editBox = DEFAULT_CHAT_FRAME.editBox
        local oldText = editBox:GetText() or ""
        editBox:SetText(cmd)
        ChatEdit_SendText(editBox)
        editBox:SetText(oldText)
    else
        -- Fallback: Try to use ChatFrameEditBox directly
        if ChatFrameEditBox then
            local oldText = ChatFrameEditBox:GetText() or ""
            ChatFrameEditBox:SetText(cmd)
            ChatEdit_SendText(ChatFrameEditBox)
            ChatFrameEditBox:SetText(oldText)
        end
    end
end

function addon:SyncSettingToServer(settingKey, value)
    -- Use DCAddonProtocol if available
    if self.useDCProtocol and DC then
        if settingKey == "enabled" then
            DC.AOE.Toggle(value)
        elseif settingKey == "minQuality" then
            DC.AOE.SetQuality(value)
        elseif settingKey == "autoSkin" then
            DC.AOE.SetAutoSkin(value)
        elseif settingKey == "showMessages" then
            -- TODO: Add showMessages to protocol
            self:SendServerCommand(value and ".lp msg 1" or ".lp msg 0")
        elseif settingKey == "smartLoot" then
            -- TODO: Add smartLoot to protocol
            self:SendServerCommand(value and ".lp smartset 1" or ".lp smartset 0")
        end
        return
    end
    
    -- Fallback: Map settings to server commands that directly set the state (not toggles)
    if settingKey == "enabled" then
        if value then
            self:SendServerCommand(".lp enable")
        else
            self:SendServerCommand(".lp disable")
        end
    elseif settingKey == "showMessages" then
        if value then
            self:SendServerCommand(".lp msg 1")
        else
            self:SendServerCommand(".lp msg 0")
        end
    elseif settingKey == "minQuality" then
        self:SendServerCommand(".lp quality " .. tostring(value))
    elseif settingKey == "autoSkin" then
        if value then
            self:SendServerCommand(".lp skinset 1")
        else
            self:SendServerCommand(".lp skinset 0")
        end
    elseif settingKey == "smartLoot" then
        if value then
            self:SendServerCommand(".lp smartset 1")
        else
            self:SendServerCommand(".lp smartset 0")
        end
    end
end

-- ============================================================
-- Initialization
-- ============================================================
function addon:Initialize()
    -- Load settings from SavedVariables
    self:LoadSettings()
    
    -- Note: In 3.3.5a, RegisterAddonMessagePrefix doesn't exist
    -- Addon messages work without pre-registration in this client version
    
    -- Create main frame (standalone panel)
    self:CreateMainFrame()
    
    -- Create Interface Options panel
    self:CreateOptionsPanel()
    
    -- Register events
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("CHAT_MSG_ADDON")
    self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.eventFrame:RegisterEvent("PLAYER_LOGOUT")
    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
        addon:OnEvent(event, ...)
    end)
    
    -- Request settings from server on load (delayed)
    DelayedCall(2, function()
        addon:RequestSettings()
    end)
    
    self:Print("Settings addon loaded. Type /aoeloot to open or find in Interface → AddOns.", true)
end

-- ============================================================
-- Event Handler
-- ============================================================
function addon:OnEvent(event, ...)
    if event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        -- Handle legacy prefix
        if prefix == self.prefix then
            self:HandleServerMessage(message)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Load settings and request from server
        self:LoadSettings()
        self:UpdateUI()
        DelayedCall(2, function()
            addon:RequestSettings()
        end)
    elseif event == "PLAYER_LOGOUT" then
        -- Save settings on logout
        self:SaveSettingsLocal()
    end
end

-- Register DCAddonProtocol handlers if available
if DC then
    -- Handle settings sync from server (opcode 0x11 = SMSG_SETTINGS_SYNC)
    DC:RegisterHandler("AOE", 0x11, function(enabled, showMessages, minQuality, autoSkin, smartLoot, autoVendorPoor)
        addon.settings.enabled = enabled
        addon.settings.showMessages = showMessages
        addon.settings.minQuality = Clamp(minQuality or 0, 0, 5)
        addon.settings.autoSkin = autoSkin
        addon.settings.smartLoot = smartLoot
        addon.settings.autoVendorPoor = autoVendorPoor or false
        
        addon:SaveSettingsLocal()
        addon:UpdateUI()
        addon:Print("Settings synced from server.", true)
    end)
    
    -- Handle stats response (opcode 0x10 = SMSG_STATS)
    DC:RegisterHandler("AOE", 0x10, function(totalItems, totalGold, vendorGold, upgrades)
        addon:ShowStats(totalItems, totalGold, vendorGold, upgrades)
    end)
    
    -- Handle loot result notification (opcode 0x12 = SMSG_LOOT_RESULT)
    DC:RegisterHandler("AOE", 0x12, function(itemCount, quality)
        if addon.settings.showMessages then
            addon:Print("Looted " .. itemCount .. " items", false)
        end
    end)
    
    -- Handle gold collected notification (opcode 0x13 = SMSG_GOLD_COLLECTED)
    DC:RegisterHandler("AOE", 0x13, function(copperAmount)
        if addon.settings.showMessages and copperAmount > 0 then
            local goldStr = GetCoinTextureString(copperAmount)
            addon:Print("Collected " .. goldStr, false)
        end
    end)
end

-- ============================================================
-- Server Communication (DCAddonProtocol + Legacy fallback)
-- ============================================================

-- Send message using DCAddonProtocol if available, otherwise legacy
function addon:SendToServer(messageType, data)
    if self.useDCProtocol and DC then
        -- Use new protocol: DC|AOE|opcode|data...
        local opcode = 0x06  -- CMSG_GET_SETTINGS default
        if messageType == "GET_SETTINGS" then
            opcode = 0x06
            DC.AOE.GetSettings()
            return
        elseif messageType == "SAVE_SETTINGS" then
            -- Parse data and send individual settings via protocol
            if data then
                local enabled, showMessages, minQuality, autoSkin, smartLoot, autoVendorPoor = strsplit(",", data)
                -- The new protocol handles individual setting changes
                -- For bulk save, we'll send each setting
                DC.AOE.Toggle(tonumber(enabled) == 1)
                DC.AOE.SetQuality(tonumber(minQuality) or 0)
                DC.AOE.SetAutoSkin(tonumber(autoSkin) == 1)
            end
            return
        elseif messageType == "GET_STATS" then
            opcode = 0x03
            DC.AOE.GetStats()
            return
        end
    end
    
    -- Legacy fallback: use old prefix
    local message = messageType
    if data then
        message = message .. ":" .. data
    end
    SendAddonMessage(self.prefix, message, "WHISPER", UnitName("player"))
end

function addon:RequestSettings()
    if self.useDCProtocol and DC then
        DC.AOE.GetSettings()
    else
        self:SendToServer("GET_SETTINGS")
    end
end

function addon:SaveSettings()
    -- Validate and clamp settings before saving
    self.settings.minQuality = Clamp(self.settings.minQuality or 0, 0, 5)
    
    -- Save locally first
    self:SaveSettingsLocal()
    
    -- Then send to server with validated values
    local data = string.format("%d,%d,%d,%d,%d,%d",
        self.settings.enabled and 1 or 0,
        self.settings.showMessages and 1 or 0,
        self.settings.minQuality,
        self.settings.autoSkin and 1 or 0,
        self.settings.smartLoot and 1 or 0,
        self.settings.autoVendorPoor and 1 or 0
    )
    self:SendToServer("SAVE_SETTINGS", data)
    self:Print("Settings saved!", true)
end

function addon:HandleServerMessage(message)
    local msgType, data = strsplit(":", message, 2)
    
    if msgType == "SETTINGS" and data then
        -- Parse settings: enabled,showMessages,minQuality,autoSkin,smartLoot,autoVendorPoor
        local enabled, showMessages, minQuality, autoSkin, smartLoot, autoVendorPoor = strsplit(",", data)
        
        self.settings.enabled = tonumber(enabled) == 1
        self.settings.showMessages = tonumber(showMessages) == 1 or (showMessages == nil)
        -- Clamp minQuality to valid range 0-5 (Poor to Legendary)
        self.settings.minQuality = Clamp(tonumber(minQuality) or 0, 0, 5)
        self.settings.autoSkin = tonumber(autoSkin) == 1
        self.settings.smartLoot = tonumber(smartLoot) == 1
        self.settings.autoVendorPoor = tonumber(autoVendorPoor) == 1
        
        self:SaveSettingsLocal()
        self:UpdateUI()
        self:Print("Settings synced from server.", true)
        
    elseif msgType == "SAVED" then
        self:Print("Settings saved to server!", true)
        
    elseif msgType == "STATS" and data then
        -- Parse stats: totalItems,totalGold,vendorGold,upgrades
        local totalItems, totalGold, vendorGold, upgrades = strsplit(",", data)
        self:ShowStats(tonumber(totalItems), tonumber(totalGold), tonumber(vendorGold), tonumber(upgrades))
        
    elseif msgType == "ERROR" then
        print("|cffff0000[DC AoE Loot]|r Error: " .. (data or "Unknown error"))
    end
end

-- ============================================================
-- Interface Options Panel (appears in Interface -> AddOns)
-- ============================================================
function addon:CreateOptionsPanel()
    local panel = CreateFrame("Frame", "DCAoELootOptionsPanel", UIParent)
    panel.name = "DC AoE Loot"
    
    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cff00ff00DarkChaos|r AoE Loot Settings")
    
    -- Version
    local version = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    version:SetText("Version " .. self.version)
    
    local yPos = -60
    local xPos = 20
    
    -- Enable AoE Loot checkbox
    local enableCB = self:CreateOptionsCheckbox(panel, "Enable AoE Loot", 
        "Disable to loot only the corpse you click (no nearby corpse merging).",
        xPos, yPos, "enabled")
    yPos = yPos - 30
    
    -- Show Messages checkbox
    local messagesCB = self:CreateOptionsCheckbox(panel, "Show Messages", 
        "Show info messages like 'merged X corpses'. Disable to hide spam.",
        xPos, yPos, "showMessages")
    yPos = yPos - 30
    
    -- Auto Skin checkbox
    local skinCB = self:CreateOptionsCheckbox(panel, "Auto-Skin/Mine/Herb", 
        "Automatically skin, mine, or herb corpses when looting.",
        xPos, yPos, "autoSkin")
    yPos = yPos - 30
    
    -- Smart Loot checkbox
    local smartCB = self:CreateOptionsCheckbox(panel, "Smart Loot (Upgrade Detection)", 
        "Prioritize gear upgrades when looting.",
        xPos, yPos, "smartLoot")
    yPos = yPos - 30
    
    -- Auto Vendor Poor checkbox
    local vendorCB = self:CreateOptionsCheckbox(panel, "Auto-Vendor Poor Items", 
        "Automatically vendor gray/poor quality items.",
        xPos, yPos, "autoVendorPoor")
    yPos = yPos - 40
    
    -- Minimum Quality Label
    local qualityLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    qualityLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", xPos, yPos)
    qualityLabel:SetText("Minimum Quality to Loot:")
    yPos = yPos - 20
    
    -- Quality buttons for Interface Options panel
    self.optionQualityButtons = {}
    for i = 0, 5 do
        local btn = CreateFrame("Button", "DCAoELootOptQuality" .. i, panel)
        btn:SetWidth(75)
        btn:SetHeight(18)
        btn:SetPoint("TOPLEFT", panel, "TOPLEFT", xPos + (i % 3) * 80, yPos - math.floor(i / 3) * 20)
        
        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.text:SetAllPoints()
        btn.text:SetText(self.qualityNames[i])
        
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.bg:SetTexture(0.2, 0.2, 0.2, 0.8)
        
        btn.quality = i
        btn:SetScript("OnClick", function()
            local quality = Clamp(i, 0, 5)
            self.settings.minQuality = quality
            self:UpdateOptionsQualityButtons()
            self:UpdateQualityButtons()
            self:Confirm("Minimum Quality", self.qualityNames[quality])
            self:SaveSettingsLocal()
            self:SyncSettingToServer("minQuality", quality)
        end)
        btn:SetScript("OnEnter", function()
            btn.bg:SetTexture(0.4, 0.4, 0.4, 0.8)
        end)
        btn:SetScript("OnLeave", function()
            if self.settings.minQuality == i then
                btn.bg:SetTexture(0, 0.5, 0, 0.8)
            else
                btn.bg:SetTexture(0.2, 0.2, 0.2, 0.8)
            end
        end)
        
        self.optionQualityButtons[i] = btn
    end
    yPos = yPos - 50
    
    -- Note about server override
    local note = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    note:SetPoint("TOPLEFT", panel, "TOPLEFT", xPos, yPos)
    note:SetWidth(350)
    note:SetJustifyH("LEFT")
    note:SetText("|cffff8800Note:|r Disabling AoE Loot will make you loot only the clicked corpse. The server must be recompiled for this to take effect.")
    yPos = yPos - 50
    
    -- Open Full Panel button
    local openBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    openBtn:SetWidth(200)
    openBtn:SetHeight(25)
    openBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", xPos, yPos)
    openBtn:SetText("Open Full Settings Panel")
    openBtn:SetScript("OnClick", function()
        InterfaceOptionsFrame:Hide()
        addon:Toggle()
    end)
    
    -- Register with Interface Options
    InterfaceOptions_AddCategory(panel)
    self.optionsPanel = panel
end

function addon:CreateOptionsCheckbox(parent, label, tooltip, x, y, settingKey)
    -- Need a unique name for 3.3.5a template to work properly
    local cbName = "DCAoELootOptCB_" .. settingKey
    local cb = CreateFrame("CheckButton", cbName, parent, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    
    -- In 3.3.5a, the text is accessed via global name pattern, not .Text
    local textObj = _G[cbName .. "Text"]
    if textObj then
        textObj:SetText(label)
    end
    
    cb.tooltipText = tooltip
    
    -- Set initial value
    cb:SetChecked(self.settings[settingKey])
    
    cb:SetScript("OnClick", function(self)
        local checked = self:GetChecked() and true or false
        addon.settings[settingKey] = checked
        addon:Confirm(label, checked)
        addon:SaveSettingsLocal()
        addon:SyncSettingToServer(settingKey, checked)
        addon:UpdateUI()
    end)
    
    -- Store reference for updating
    if not self.optionCheckboxes then self.optionCheckboxes = {} end
    self.optionCheckboxes[settingKey] = cb
    
    return cb
end

-- ============================================================
-- UI Creation (3.3.5a Compatible) - Standalone Panel
-- ============================================================
function addon:CreateMainFrame()
    -- Create base frame without template (3.3.5a doesn't have BasicFrameTemplateWithInset)
    local frame = CreateFrame("Frame", "DCAoELootSettingsFrame", UIParent)
    frame:SetWidth(320)
    frame:SetHeight(340)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    
    -- Create background
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(0, 0, 0, 1)
    
    -- Create close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    
    -- Title
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("TOP", frame, "TOP", 0, -15)
    frame.title:SetText("|cff00ff00DarkChaos|r AoE Loot Settings")
    
    self.frame = frame
    
    local yPos = -45
    local xPos = 20
    
    -- Enable checkbox
    self.checkboxes.enabled = self:CreateCheckbox(frame, "Enable AoE Loot", xPos, yPos, 
        function(checked) 
            self.settings.enabled = checked 
            self:Confirm("Enable AoE Loot", checked)
            self:SaveSettingsLocal()
            self:SyncSettingToServer("enabled", checked)
        end)
    yPos = yPos - 30
    
    -- Show Messages checkbox (NEW)
    self.checkboxes.showMessages = self:CreateCheckbox(frame, "Show Messages (debug output)", xPos, yPos,
        function(checked) 
            self.settings.showMessages = checked 
            self:Confirm("Show Messages", checked)
            self:SaveSettingsLocal()
            self:SyncSettingToServer("showMessages", checked)
        end)
    yPos = yPos - 30
    
    -- Auto Skin checkbox
    self.checkboxes.autoSkin = self:CreateCheckbox(frame, "Auto-Skin/Mine/Herb", xPos, yPos,
        function(checked) 
            self.settings.autoSkin = checked 
            self:Confirm("Auto-Skin/Mine/Herb", checked)
            self:SaveSettingsLocal()
            self:SyncSettingToServer("autoSkin", checked)
        end)
    yPos = yPos - 30
    
    -- Smart Loot checkbox
    self.checkboxes.smartLoot = self:CreateCheckbox(frame, "Smart Loot (Upgrade Detection)", xPos, yPos,
        function(checked) 
            self.settings.smartLoot = checked 
            self:Confirm("Smart Loot", checked)
            self:SaveSettingsLocal()
            self:SyncSettingToServer("smartLoot", checked)
        end)
    yPos = yPos - 30
    
    -- Auto Vendor Poor checkbox
    self.checkboxes.autoVendorPoor = self:CreateCheckbox(frame, "Auto-Vendor Poor Items", xPos, yPos,
        function(checked) 
            self.settings.autoVendorPoor = checked 
            self:Confirm("Auto-Vendor Poor Items", checked)
            self:SaveSettingsLocal()
        end)
    yPos = yPos - 40
    
    -- Minimum Quality dropdown label
    local qualityLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    qualityLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", xPos, yPos)
    qualityLabel:SetText("Minimum Quality to Loot:")
    yPos = yPos - 25
    
    -- Quality buttons (radio-style)
    self.qualityButtons = {}
    for i = 0, 5 do
        local btn = CreateFrame("Button", nil, frame)
        btn:SetWidth(80)
        btn:SetHeight(20)
        btn:SetPoint("TOPLEFT", frame, "TOPLEFT", xPos + (i % 3) * 90, yPos - math.floor(i / 3) * 22)
        
        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.text:SetAllPoints()
        btn.text:SetText(self.qualityNames[i])
        
        -- Use SetTexture instead of SetColorTexture (3.3.5a compatible)
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.bg:SetTexture(0.2, 0.2, 0.2, 0.8)
        
        btn.quality = i
        btn:SetScript("OnClick", function()
            -- Clamp quality to valid range 0-5
            local quality = Clamp(i, 0, 5)
            self.settings.minQuality = quality
            self:UpdateQualityButtons()
            self:Confirm("Minimum Quality", self.qualityNames[quality])
            self:SaveSettingsLocal()
            self:SyncSettingToServer("minQuality", quality)
        end)
        btn:SetScript("OnEnter", function()
            btn.bg:SetTexture(0.4, 0.4, 0.4, 0.8)
        end)
        btn:SetScript("OnLeave", function()
            if self.settings.minQuality == i then
                btn.bg:SetTexture(0, 0.5, 0, 0.8)
            else
                btn.bg:SetTexture(0.2, 0.2, 0.2, 0.8)
            end
        end)
        
        self.qualityButtons[i] = btn
    end
    yPos = yPos - 60
    
    -- Info label about server-controlled range
    local rangeInfo = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rangeInfo:SetPoint("TOPLEFT", frame, "TOPLEFT", xPos, yPos)
    rangeInfo:SetWidth(280)
    rangeInfo:SetJustifyH("LEFT")
    rangeInfo:SetText("|cff888888Note: Loot range is controlled by server (default: 30 yards)|r")
    yPos = yPos - 30
    
    -- Save button
    local saveBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    saveBtn:SetWidth(120)
    saveBtn:SetHeight(25)
    saveBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 15)
    saveBtn:SetText("Save Settings")
    saveBtn:SetScript("OnClick", function()
        self:SaveSettings()
    end)
    
    -- Stats button
    local statsBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    statsBtn:SetWidth(120)
    statsBtn:SetHeight(25)
    statsBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 15)
    statsBtn:SetText("Show Stats")
    statsBtn:SetScript("OnClick", function()
        -- Try server command first (more reliable than addon message)
        SendChatMessage(".lp stats", "SAY")
    end)
end

function addon:CreateCheckbox(parent, label, x, y, onChange)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cb.text:SetPoint("LEFT", cb, "RIGHT", 5, 0)
    cb.text:SetText(label)
    cb:SetScript("OnClick", function()
        if onChange then onChange(cb:GetChecked()) end
    end)
    return cb
end

function addon:UpdateUI()
    if not self.frame then return end
    
    if self.checkboxes.enabled then
        self.checkboxes.enabled:SetChecked(self.settings.enabled)
    end
    if self.checkboxes.showMessages then
        self.checkboxes.showMessages:SetChecked(self.settings.showMessages)
    end
    if self.checkboxes.autoSkin then
        self.checkboxes.autoSkin:SetChecked(self.settings.autoSkin)
    end
    if self.checkboxes.smartLoot then
        self.checkboxes.smartLoot:SetChecked(self.settings.smartLoot)
    end
    if self.checkboxes.autoVendorPoor then
        self.checkboxes.autoVendorPoor:SetChecked(self.settings.autoVendorPoor)
    end
    
    self:UpdateQualityButtons()
    self:UpdateOptionsQualityButtons()
    
    -- Also update options panel checkboxes if they exist
    if self.optionCheckboxes then
        for key, cb in pairs(self.optionCheckboxes) do
            if self.settings[key] ~= nil then
                cb:SetChecked(self.settings[key])
            end
        end
    end
end

function addon:UpdateQualityButtons()
    if not self.qualityButtons then return end
    for i, btn in pairs(self.qualityButtons) do
        if self.settings.minQuality == i then
            btn.bg:SetTexture(0, 0.5, 0, 0.8)
        else
            btn.bg:SetTexture(0.2, 0.2, 0.2, 0.8)
        end
    end
end

function addon:UpdateOptionsQualityButtons()
    if not self.optionQualityButtons then return end
    for i, btn in pairs(self.optionQualityButtons) do
        if self.settings.minQuality == i then
            btn.bg:SetTexture(0, 0.5, 0, 0.8)
        else
            btn.bg:SetTexture(0.2, 0.2, 0.2, 0.8)
        end
    end
end

function addon:ShowStats(totalItems, totalGold, vendorGold, upgrades)
    local goldStr = GetCoinTextureString(totalGold or 0)
    local vendorStr = GetCoinTextureString(vendorGold or 0)
    
    print("|cff00ff00========== AoE Loot Statistics ==========|r")
    print("|cffffd700Total Items Looted:|r " .. (totalItems or 0))
    print("|cffffd700Total Gold Looted:|r " .. goldStr)
    print("|cffffd700Gold from Auto-Vendor:|r " .. vendorStr)
    print("|cffffd700Gear Upgrades Found:|r " .. (upgrades or 0))
    print("|cff00ff00==========================================|r")
end

function addon:Toggle()
    -- Ensure frame exists before trying to use it
    if not self.frame then
        self:CreateMainFrame()
    end
    
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self:RequestSettings()
        self.frame:Show()
    end
end

-- ============================================================
-- Slash Commands
-- ============================================================
SLASH_DCAOELOOT1 = "/aoeloot"
SLASH_DCAOELOOT2 = "/dcaoe"
SlashCmdList["DCAOELOOT"] = function(msg)
    msg = strlower(msg or "")
    
    if msg == "stats" then
        -- Use server command instead of addon message
        SendChatMessage(".lp stats", "SAY")
    elseif msg == "reload" then
        DCAoELootSettings:RequestSettings()
    elseif msg == "config" or msg == "options" then
        InterfaceOptionsFrame_OpenToCategory(DCAoELootSettings.optionsPanel)
        InterfaceOptionsFrame_OpenToCategory(DCAoELootSettings.optionsPanel) -- Call twice for WoW bug
    elseif msg == "help" then
        print("|cff00ff00[DC AoE Loot] Commands:|r")
        print("  /aoeloot - Open settings panel")
        print("  /aoeloot config - Open Interface Options panel")
        print("  /aoeloot stats - Show loot statistics")
        print("  /aoeloot reload - Reload settings from server")
        print("  /aoeloot help - Show this help")
    else
        DCAoELootSettings:Toggle()
    end
end

-- Initialize on load
DCAoELootSettings:Initialize()
