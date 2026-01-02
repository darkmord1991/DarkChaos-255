-- ============================================================
-- DC-QoS: Settings Panel with Tabs
-- ============================================================
-- Tabbed Interface Options panel for DC-QoS settings
-- Each module gets its own tab for organized settings
-- ============================================================

local addon = DCQOS

-- ============================================================
-- Panel References
-- ============================================================
addon.settingsPanel = nil
addon.tabFrames = {}
addon.tabButtons = {}
addon.currentTab = nil

-- ============================================================
-- Tab Configuration
-- ============================================================
local TAB_WIDTH = 70
local TAB_HEIGHT = 24
local PANEL_PADDING = 10

-- Tab definitions (order matters)
local tabOrder = {
    "Tooltips",
    "Automation",
    "Chat",
    "Interface",
    "ExtendedStats",
    "GTFO",
    "ItemScore",
    "Bags",
    "Cooldowns",
    "Mail",
    "Communication",
}

-- ============================================================
-- Helper Functions
-- ============================================================

-- Create a tab button
local function CreateTabButton(parent, x, y, name, displayName)
    local button = CreateFrame("Button", "DCQoSTab" .. name, parent)
    button:SetSize(TAB_WIDTH, TAB_HEIGHT)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    
    -- Background textures
    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetAllPoints()
    button.bg:SetTexture("Interface\\Buttons\\UI-Panel-Button-Up")
    button.bg:SetTexCoord(0, 0.625, 0, 0.6875)
    
    button.bgHighlight = button:CreateTexture(nil, "BACKGROUND")
    button.bgHighlight:SetAllPoints()
    button.bgHighlight:SetTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
    button.bgHighlight:SetTexCoord(0, 0.625, 0, 0.6875)
    button.bgHighlight:SetBlendMode("ADD")
    button.bgHighlight:Hide()
    
    -- Text
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.text:SetPoint("CENTER", 0, 1)
    button.text:SetText(displayName)
    
    -- Tab name for reference
    button.tabName = name
    
    -- Hover effects
    button:SetScript("OnEnter", function(self)
        if addon.currentTab ~= self.tabName then
            self.bgHighlight:Show()
        end
    end)
    
    button:SetScript("OnLeave", function(self)
        self.bgHighlight:Hide()
    end)
    
    -- Click handler
    button:SetScript("OnClick", function(self)
        addon:ShowTab(self.tabName)
    end)
    
    return button
end

-- Create a tab content frame
local function CreateTabFrame(parent, name)
    local frame = CreateFrame("Frame", "DCQoSTabFrame" .. name, parent)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", PANEL_PADDING, -90)
    frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -PANEL_PADDING, PANEL_PADDING)
    frame:Hide()
    
    -- Background for content area
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetTexture(0, 0, 0, 0.3)

    -- Scrollable content area so settings never render outside the frame.
    -- NOTE: UIPanelScrollFrameTemplate relies on a named frame (self:GetName())
    -- in 3.3.5a's UIPanelTemplates.lua ScrollFrame_OnLoad.
    local safeName = tostring(name or "")
    safeName = safeName:gsub("[^%w_]", "")
    if safeName == "" then
        safeName = tostring(GetTime()):gsub("%.", "")
    end
    local scroll = CreateFrame("ScrollFrame", "DCQoSTabScrollFrame" .. safeName, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 6)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)

    frame.scrollFrame = scroll
    frame.content = content

    -- Keep content width synced (prevents widgets from overflowing horizontally).
    frame:SetScript("OnSizeChanged", function(self)
        if not self.content or not self.scrollFrame then return end
        local w = self.scrollFrame:GetWidth()
        if w and w > 0 then
            self.content:SetWidth(w)
        end
    end)
    
    return frame
end

-- Update tab button appearance
local function UpdateTabAppearance(selectedTab)
    for name, button in pairs(addon.tabButtons) do
        if name == selectedTab then
            button.text:SetTextColor(1, 0.82, 0)  -- Gold for selected
            button.bg:SetVertexColor(0.2, 0.4, 0.6)  -- Darker blue for selected
        else
            button.text:SetTextColor(1, 1, 1)  -- White for unselected
            button.bg:SetVertexColor(0.4, 0.4, 0.4)  -- Gray for unselected
        end
    end
end

-- ============================================================
-- Show a specific tab
-- ============================================================
function addon:ShowTab(tabName)
    -- Hide all tab frames
    for name, frame in pairs(self.tabFrames) do
        frame:Hide()
    end
    
    -- Show selected tab frame
    if self.tabFrames[tabName] then
        self.tabFrames[tabName]:Show()
    end
    
    self.currentTab = tabName
    UpdateTabAppearance(tabName)
end

-- ============================================================
-- Create Communication Tab (Special - settings for server sync)
-- ============================================================
local function CreateCommunicationSettings(parent)
    local settings = addon.settings.communication or {}
    
    -- Title
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Communication Settings")
    
    -- Description
    local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText("Configure server communication and synchronization options.")
    desc:SetWidth(parent:GetWidth() - 32)
    desc:SetJustifyH("LEFT")
    
    local yOffset = -70
    
    -- ============================================================
    -- Server Sync Section
    -- ============================================================
    local syncHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    syncHeader:SetPoint("TOPLEFT", 16, yOffset)
    syncHeader:SetText("Server Synchronization")
    yOffset = yOffset - 25
    
    -- Auto Sync Settings
    local autoSyncCb = addon:CreateCheckbox(parent, "DCQoSAutoSync")
    autoSyncCb:SetPoint("TOPLEFT", 16, yOffset)
    autoSyncCb.Text:SetText("Auto-sync Settings with Server")
    autoSyncCb:SetChecked(settings.autoSync ~= false)
    autoSyncCb:SetScript("OnClick", function(self)
        addon:SetSetting("communication.autoSync", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    -- Manual sync button
    local syncButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    syncButton:SetSize(120, 24)
    syncButton:SetPoint("TOPLEFT", 16, yOffset)
    syncButton:SetText("Sync Now")
    syncButton:SetScript("OnClick", function()
        if addon:SyncWithServer() then
            addon:Print("Requesting settings sync from server...", true)
        else
            addon:Print("Not connected to server", true)
        end
    end)
    yOffset = yOffset - 40
    
    -- ============================================================
    -- Debug Section
    -- ============================================================
    local debugHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    debugHeader:SetPoint("TOPLEFT", 16, yOffset)
    debugHeader:SetText("Debugging")
    yOffset = yOffset - 25
    
    -- Debug Mode
    local debugCb = addon:CreateCheckbox(parent, "DCQoSDebugMode")
    debugCb:SetPoint("TOPLEFT", 16, yOffset)
    debugCb.Text:SetText("Enable Debug Mode")
    debugCb:SetChecked(settings.debugMode)
    debugCb:SetScript("OnClick", function(self)
        addon:SetSetting("communication.debugMode", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    -- Show Protocol Messages
    local protocolCb = addon:CreateCheckbox(parent, "DCQoSProtocolMsgs")
    protocolCb:SetPoint("TOPLEFT", 16, yOffset)
    protocolCb.Text:SetText("Show Protocol Messages")
    protocolCb:SetChecked(settings.showProtocolMessages)
    protocolCb:SetScript("OnClick", function(self)
        addon:SetSetting("communication.showProtocolMessages", self:GetChecked())
    end)
    yOffset = yOffset - 40
    
    -- ============================================================
    -- Status Section
    -- ============================================================
    local statusHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    statusHeader:SetPoint("TOPLEFT", 16, yOffset)
    statusHeader:SetText("Connection Status")
    yOffset = yOffset - 25
    
    -- Connection status
    local statusText = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    statusText:SetPoint("TOPLEFT", 16, yOffset)
    
    local function UpdateStatus()
        if addon.protocol and addon.protocol.connected then
            statusText:SetText("|cff00ff00Connected|r to DCAddonProtocol (Module: " .. addon.protocol.MODULE_ID .. ")")
        else
            statusText:SetText("|cffff0000Not Connected|r - DCAddonProtocol not available")
        end
    end
    UpdateStatus()
    
    -- Refresh status button
    yOffset = yOffset - 30
    local refreshButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    refreshButton:SetSize(100, 22)
    refreshButton:SetPoint("TOPLEFT", 16, yOffset)
    refreshButton:SetText("Refresh")
    refreshButton:SetScript("OnClick", function()
        UpdateStatus()
    end)
    
    return yOffset - 50
end

-- ============================================================
-- Create Main Settings Panel
-- ============================================================
function addon:CreateSettingsPanel()
    if self.settingsPanel then return end
    
    -- Create main panel
    local panel = CreateFrame("Frame", "DCQoSSettingsPanel", InterfaceOptionsFramePanelContainer)
    panel.name = "DC-QoS"
    panel:Hide()
    
    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cff00ff00DC|r-QoS: Quality of Service")
    
    -- Version
    local version = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    version:SetText("Version " .. self.version .. " | DarkChaos-255")
    version:SetTextColor(0.7, 0.7, 0.7)
    
    -- Description
    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", version, "BOTTOMLEFT", 0, -8)
    desc:SetText("Comprehensive Quality of Life improvements for your gameplay experience.")
    desc:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    desc:SetJustifyH("LEFT")
    
    -- Create tab buttons and frames
    -- Tab display name overrides for modules that register with different names
    local tabDisplayNames = {
        ["Tooltips"] = "Tooltips",
        ["Automation"] = "Automation",
        ["Chat"] = "Chat",
        ["Interface"] = "Interface",
        ["ExtendedStats"] = "Stats",
        ["GTFO"] = "GTFO",
        ["ItemScore"] = "Pawn",
        ["Bags"] = "Bags",
        ["BagEnhancements"] = "Bags",
        ["Communication"] = "Sync",
    }
    
    local MAX_WIDTH = 550
    local currentX = PANEL_PADDING
    local currentY = -60

    for i, tabName in ipairs(tabOrder) do
        local module = self.modules[tabName]
        -- For "Bags" tab, try BagEnhancements module
        if not module and tabName == "Bags" then
            module = self.modules["BagEnhancements"]
        end
        
        local displayName = tabDisplayNames[tabName] or (module and module.displayName) or tabName
        
        -- Wrap logic
        if currentX + TAB_WIDTH > MAX_WIDTH then
            currentX = PANEL_PADDING
            currentY = currentY - TAB_HEIGHT - 4
        end

        -- Create tab button
        self.tabButtons[tabName] = CreateTabButton(panel, currentX, currentY, tabName, displayName)
        
        -- Create tab content frame
        self.tabFrames[tabName] = CreateTabFrame(panel, tabName)

        -- Advance X
        currentX = currentX + TAB_WIDTH + 4
        
        -- Populate tab with module settings
        if module and module.CreateSettings then
            local y = module.CreateSettings(self.tabFrames[tabName].content)
            if type(y) == "number" then
                self.tabFrames[tabName].content:SetHeight(math.max(1, -y + 30))
            end
        elseif tabName == "Communication" then
            local y = CreateCommunicationSettings(self.tabFrames[tabName].content)
            if type(y) == "number" then
                self.tabFrames[tabName].content:SetHeight(math.max(1, -y + 30))
            end
        end
    end

    -- Update all tab frames anchors to account for button rows
    local contentTopY = currentY - TAB_HEIGHT - 10
    for _, frame in pairs(self.tabFrames) do
        frame:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_PADDING, contentTopY)
    end
    
    -- Show first tab by default
    self:ShowTab(tabOrder[1])
    
    -- Register with Interface Options
    InterfaceOptions_AddCategory(panel)
    
    self.settingsPanel = panel
    
    -- Also create sub-panels for each module (optional)
    self:CreateSubPanels()
end

-- ============================================================
-- Create Sub-Panels for Each Module (Alternative view)
-- ============================================================
function addon:CreateSubPanels()
    for _, tabName in ipairs(tabOrder) do
        local module = self.modules[tabName]
        if module then
            local subPanel = CreateFrame("Frame", "DCQoSSubPanel" .. tabName, InterfaceOptionsFramePanelContainer)
            subPanel.name = module.displayName or tabName
            subPanel.parent = "DC-QoS"
            
            if module.CreateSettings then
                module.CreateSettings(subPanel)
            elseif tabName == "Communication" then
                CreateCommunicationSettings(subPanel)
            end
            
            InterfaceOptions_AddCategory(subPanel)
        end
    end
end

-- ============================================================
-- Toggle Settings Panel
-- ============================================================
function addon:ToggleSettings()
    if not self.settingsPanel then
        self:CreateSettingsPanel()
    end
    
    -- Open to our panel
    InterfaceOptionsFrame_OpenToCategory("DC-QoS")
    InterfaceOptionsFrame_OpenToCategory("DC-QoS")  -- Called twice to ensure it opens
end

-- ============================================================
-- Initialize Panel on Addon Load
-- ============================================================
addon:RegisterEvent("PLAYER_LOGIN", function()
    addon:DelayedCall(1, function()
        addon:CreateSettingsPanel()
    end)
end)

-- ============================================================
-- Hook Escape Key to Close Panel
-- ============================================================
-- (Interface Options already handles ESC)
