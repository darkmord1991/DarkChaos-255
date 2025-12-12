--[[
    DC-InfoBar Options Panel
    Interface > AddOns settings with tabs for:
    - General Settings
    - Plugin Configuration  
    - Position/Display Settings
    - Communication/Debug
]]

local addonName = "DC-InfoBar"
local DCInfoBar = DCInfoBar or {}

-- ============================================================================
-- Options Panel Creation
-- ============================================================================

function DCInfoBar:CreateOptionsPanel()
    if self.optionsPanel then
        return self.optionsPanel
    end

    -- Ensure saved vars are available before building UI.
    if not self.db and self.InitializeDB then
        pcall(function() self:InitializeDB() end)
    end

    -- Main panel for Interface Options
    local panel = CreateFrame("Frame", "DCInfoBarOptionsPanel", UIParent)
    panel.name = "DC-InfoBar"
    panel:Hide()
    
    -- Title
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("DC-InfoBar Settings")
    
    -- Version
    local version = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    version:SetText("Version " .. (DCInfoBar.VERSION or "1.0.0"))
    version:SetTextColor(0.5, 0.5, 0.5)
    
    -- Tab container
    local tabContainer = CreateFrame("Frame", nil, panel)
    tabContainer:SetPoint("TOPLEFT", 16, -60)
    tabContainer:SetPoint("BOTTOMRIGHT", -16, 16)
    
    -- Create tabs
    local tabs = {}
    local tabNames = { "General", "Plugins", "Position", "Communication" }
    local currentTab = 1
    
    -- Tab content frames
    local tabFrames = {}
    
    for i, tabName in ipairs(tabNames) do
        -- Tab button
        local tab = CreateFrame("Button", nil, panel)
        tab:SetSize(100, 24)
        tab:SetPoint("TOPLEFT", 16 + (i-1) * 105, -55)
        
        tab.bg = tab:CreateTexture(nil, "BACKGROUND")
        tab.bg:SetAllPoints()
        tab.bg:SetColorTexture(0.15, 0.15, 0.18, 0.8)
        
        tab.text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        tab.text:SetPoint("CENTER")
        tab.text:SetText(tabName)
        
        tab:SetScript("OnClick", function()
            currentTab = i
            DCInfoBar:RefreshTabDisplay(tabFrames, i, tabs)
        end)
        
        tab:SetScript("OnEnter", function(self)
            self.bg:SetColorTexture(0.25, 0.25, 0.3, 0.9)
        end)
        
        tab:SetScript("OnLeave", function(self)
            if currentTab ~= i then
                self.bg:SetColorTexture(0.15, 0.15, 0.18, 0.8)
            end
        end)
        
        tabs[i] = tab
        
        -- Tab content frame
        local content = CreateFrame("Frame", nil, tabContainer)
        content:SetPoint("TOPLEFT", 0, -30)
        content:SetPoint("BOTTOMRIGHT", 0, 0)
        content:Hide()
        
        tabFrames[i] = content
    end
    
    -- Create tab contents (guarded so options still register even if a tab errors)
    local ok, err = pcall(function()
        self:CreateGeneralTab(tabFrames[1])
        self:CreatePluginsTab(tabFrames[2])
        self:CreatePositionTab(tabFrames[3])
        self:CreateCommunicationTab(tabFrames[4])
    end)
    if not ok then
        if self.Print then
            self:Print("Options UI build error: " .. tostring(err))
        end
    end
    
    -- Show first tab
    self:RefreshTabDisplay(tabFrames, 1, tabs)
    
    -- Register with Interface Options
    -- On some 3.3.5a clients, Blizzard_InterfaceOptions may not be loaded yet at login.
    if not InterfaceOptions_AddCategory and UIParentLoadAddOn then
        pcall(UIParentLoadAddOn, "Blizzard_InterfaceOptions")
    end

    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    else
        -- Defer until the Blizzard options addon is loaded.
        local reg = CreateFrame("Frame")
        reg:RegisterEvent("ADDON_LOADED")
        reg:SetScript("OnEvent", function(self, _, name)
            if name == "Blizzard_InterfaceOptions" and InterfaceOptions_AddCategory then
                InterfaceOptions_AddCategory(panel)
                self:UnregisterEvent("ADDON_LOADED")
                self:SetScript("OnEvent", nil)
            end
        end)
    end
    
    self.optionsPanel = panel
    return panel
end

function DCInfoBar:RefreshTabDisplay(tabFrames, activeIndex, tabs)
    for i, frame in ipairs(tabFrames) do
        if i == activeIndex then
            frame:Show()
            if tabs[i] then
                tabs[i].bg:SetColorTexture(0.3, 0.5, 0.8, 0.9)
            end
        else
            frame:Hide()
            if tabs[i] then
                tabs[i].bg:SetColorTexture(0.15, 0.15, 0.18, 0.8)
            end
        end
    end
end

-- ============================================================================
-- General Tab
-- ============================================================================

function DCInfoBar:CreateGeneralTab(parent)
    local yOffset = 0
    
    -- Enable/Disable
    local enableCB = self:CreateCheckbox(parent, "Enable DC-InfoBar", 0, yOffset, function(checked)
        self.db.global.enabled = checked
        if self.bar then
            self.bar:SetShown(checked)
        end
    end, self.db and self.db.global and self.db.global.enabled)
    yOffset = yOffset - 30
    
    -- Hide in combat
    local combatCB = self:CreateCheckbox(parent, "Hide in combat", 0, yOffset, function(checked)
        self.db.global.hideInCombat = checked
    end, self.db and self.db.global and self.db.global.hideInCombat)
    yOffset = yOffset - 30
    
    -- Hide in instance
    local instanceCB = self:CreateCheckbox(parent, "Hide in instances", 0, yOffset, function(checked)
        self.db.global.hideInInstance = checked
    end, self.db and self.db.global and self.db.global.hideInInstance)
    yOffset = yOffset - 30
    
    -- Show labels
    local labelsCB = self:CreateCheckbox(parent, "Show plugin labels", 0, yOffset, function(checked)
        self.db.global.showLabels = checked
        self:RefreshAllPlugins()
    end, self.db and self.db.global and self.db.global.showLabels)
    yOffset = yOffset - 30
    
    -- Show icons
    local iconsCB = self:CreateCheckbox(parent, "Show plugin icons", 0, yOffset, function(checked)
        self.db.global.showIcons = checked
        self:RefreshAllPlugins()
    end, self.db and self.db.global and self.db.global.showIcons)
    yOffset = yOffset - 50
    
    -- Reset button
    local resetBtn = self:CreateButton(parent, "Reset to Defaults", 0, yOffset, 150, function()
        StaticPopup_Show("DCINFOBAR_RESET_CONFIRM")
    end)
    
    -- Confirmation popup
    StaticPopupDialogs["DCINFOBAR_RESET_CONFIRM"] = {
        text = "Are you sure you want to reset DC-InfoBar settings to defaults?",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            DCInfoBar:ResetToDefaults()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
end

-- ============================================================================
-- Plugins Tab
-- ============================================================================

function DCInfoBar:CreatePluginsTab(parent)
    -- Scrollable list of plugins
    -- NOTE: UIPanelScrollFrameTemplate requires a named frame in WotLK 3.3.5a
    local scrollFrame = CreateFrame("ScrollFrame", "DCInfoBarPluginsScrollFrame", parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 0)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(scrollFrame:GetWidth(), 600)
    scrollFrame:SetScrollChild(scrollChild)
    
    local yOffset = 0
    
    -- Header
    local header = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", 0, yOffset)
    header:SetText("Configure individual plugins:")
    yOffset = yOffset - 25
    
    -- Plugin list
    local pluginOrder = {
        -- Left side
        { id = "DCInfoBar_Season", name = "Season Info", category = "Server Data" },
        { id = "DCInfoBar_Keystone", name = "Keystone", category = "Server Data" },
        { id = "DCInfoBar_Affixes", name = "Weekly Affixes", category = "Server Data" },
        { id = "DCInfoBar_WorldBoss", name = "World Boss Timers", category = "Server Data" },
        { id = "DCInfoBar_Events", name = "Zone Events", category = "Server Data" },
        { id = "DCInfoBar_Location", name = "Location", category = "Character" },
        -- Right side
        { id = "DCInfoBar_Gold", name = "Gold", category = "Character" },
        { id = "DCInfoBar_Durability", name = "Durability", category = "Character" },
        { id = "DCInfoBar_Bags", name = "Bag Space", category = "Character" },
        { id = "DCInfoBar_Performance", name = "FPS/Latency", category = "Misc" },
        { id = "DCInfoBar_Clock", name = "Clock", category = "Misc" },
    }
    
    local currentCategory = nil
    
    for _, pluginInfo in ipairs(pluginOrder) do
        -- Category header
        if pluginInfo.category ~= currentCategory then
            currentCategory = pluginInfo.category
            yOffset = yOffset - 10
            local catHeader = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            catHeader:SetPoint("TOPLEFT", 0, yOffset)
            catHeader:SetText("|cff32c4ff" .. currentCategory .. "|r")
            yOffset = yOffset - 20
        end
        
        -- Plugin row
        local row = CreateFrame("Frame", nil, scrollChild)
        row:SetSize(400, 24)
        row:SetPoint("TOPLEFT", 10, yOffset)
        
        -- Enable checkbox
        local enabled = self:GetPluginSetting(pluginInfo.id, "enabled") ~= false
        local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        cb:SetPoint("LEFT", 0, 0)
        cb:SetChecked(enabled)
        cb:SetScript("OnClick", function(self)
            local checked = self:GetChecked()
            DCInfoBar:SetPluginSetting(pluginInfo.id, "enabled", checked)
            if checked then
                DCInfoBar:ActivatePlugin(pluginInfo.id)
            else
                DCInfoBar:DeactivatePlugin(pluginInfo.id)
            end
        end)
        
        -- Plugin name
        local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        name:SetPoint("LEFT", cb, "RIGHT", 5, 0)
        name:SetText(pluginInfo.name)
        
        -- Side dropdown
        local sideDropdown = self:CreateDropdown(row, 200, {"Left", "Right"}, function(value)
            DCInfoBar:SetPluginSetting(pluginInfo.id, "side", value:lower())
            DCInfoBar:RefreshAllPlugins()
        end)
        sideDropdown:SetPoint("LEFT", name, "LEFT", 150, 0)
        
        local currentSide = self:GetPluginSetting(pluginInfo.id, "side") or "left"
        sideDropdown.text:SetText(currentSide == "left" and "Left" or "Right")
        
        -- Settings button (plugin-specific)
        local settingsBtn = CreateFrame("Button", nil, row)
        settingsBtn:SetSize(60, 20)
        settingsBtn:SetPoint("LEFT", sideDropdown, "RIGHT", 10, 0)
        
        settingsBtn.bg = settingsBtn:CreateTexture(nil, "BACKGROUND")
        settingsBtn.bg:SetAllPoints()
        settingsBtn.bg:SetColorTexture(0.2, 0.2, 0.25, 0.8)
        
        settingsBtn.text = settingsBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        settingsBtn.text:SetPoint("CENTER")
        settingsBtn.text:SetText("Options")
        
        settingsBtn:SetScript("OnClick", function()
            DCInfoBar:ShowPluginOptions(pluginInfo.id)
        end)
        
        settingsBtn:SetScript("OnEnter", function(self)
            self.bg:SetColorTexture(0.3, 0.3, 0.35, 0.9)
        end)
        settingsBtn:SetScript("OnLeave", function(self)
            self.bg:SetColorTexture(0.2, 0.2, 0.25, 0.8)
        end)
        
        yOffset = yOffset - 28
    end
    
    scrollChild:SetHeight(math.abs(yOffset) + 20)
end

-- ============================================================================
-- Position Tab
-- ============================================================================

function DCInfoBar:CreatePositionTab(parent)
    local yOffset = 0
    
    -- Bar position
    local posLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    posLabel:SetPoint("TOPLEFT", 0, yOffset)
    posLabel:SetText("Bar Position:")
    yOffset = yOffset - 25
    
    -- Top/Bottom radio buttons
    local topBtn = self:CreateRadioButton(parent, "Top of screen", 20, yOffset, function()
        self:SetBarSetting("position", "top")
        if self.bar then
            self.bar:RefreshSettings()
        end
    end, self:GetBarSetting("position") == "top")
    yOffset = yOffset - 25
    
    local bottomBtn = self:CreateRadioButton(parent, "Bottom of screen", 20, yOffset, function()
        self:SetBarSetting("position", "bottom")
        if self.bar then
            self.bar:RefreshSettings()
        end
    end, self:GetBarSetting("position") == "bottom")
    yOffset = yOffset - 40
    
    -- Background settings
    local bgLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bgLabel:SetPoint("TOPLEFT", 0, yOffset)
    bgLabel:SetText("Background:")
    yOffset = yOffset - 25
    
    -- Show background
    local showBgCB = self:CreateCheckbox(parent, "Show background", 20, yOffset, function(checked)
        self:SetBarSetting("showBackground", checked)
        if self.bar then
            self.bar.bg:SetShown(checked)
        end
    end, self:GetBarSetting("showBackground") ~= false)
    yOffset = yOffset - 30
    
    -- Background opacity slider
    local opacityLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    opacityLabel:SetPoint("TOPLEFT", 20, yOffset)
    opacityLabel:SetText("Background Opacity:")
    
    local currentBgColor = self:GetBarSetting("backgroundColor") or { 0.04, 0.04, 0.05, 0.85 }
    local opacitySlider = self:CreateSlider(parent, 150, yOffset, 0, 100, currentBgColor[4] * 100, function(value)
        local bgColor = self:GetBarSetting("backgroundColor") or { 0.04, 0.04, 0.05, 0.85 }
        bgColor[4] = value / 100
        self:SetBarSetting("backgroundColor", bgColor)
        if self.bar and self.bar.bg then
            self.bar.bg:SetColorTexture(unpack(bgColor))
        end
    end)
    opacitySlider:SetPoint("LEFT", opacityLabel, "RIGHT", 20, 0)
    yOffset = yOffset - 40
    
    -- Bar height slider
    local heightLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    heightLabel:SetPoint("TOPLEFT", 20, yOffset)
    heightLabel:SetText("Bar Height:")
    
    local heightSlider = self:CreateSlider(parent, 150, yOffset, 18, 32, self:GetBarSetting("height") or 22, function(value)
        self:SetBarSetting("height", value)
        if self.bar then
            self.bar:SetHeight(value)
        end
    end)
    heightSlider:SetPoint("LEFT", heightLabel, "RIGHT", 40, 0)
end

-- ============================================================================
-- Communication Tab
-- ============================================================================

function DCInfoBar:CreateCommunicationTab(parent)
    local yOffset = 0
    
    -- Header
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", 0, yOffset)
    header:SetText("|cff32c4ffServer Communication|r")
    yOffset = yOffset - 25
    
    -- Description
    local desc = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    desc:SetPoint("TOPLEFT", 0, yOffset)
    desc:SetText("DC-InfoBar communicates with the server via DCAddonProtocol")
    desc:SetTextColor(0.7, 0.7, 0.7)
    yOffset = yOffset - 30
    
    -- Connection status
    local statusLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusLabel:SetPoint("TOPLEFT", 0, yOffset)
    
    local DC = rawget(_G, "DCAddonProtocol")
    if DC then
        statusLabel:SetText("Status: |cff50ff7aConnected to DCAddonProtocol|r")
    else
        statusLabel:SetText("Status: |cffff5050DCAddonProtocol not found|r")
    end
    yOffset = yOffset - 30
    
    -- Debug options
    local debugHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    debugHeader:SetPoint("TOPLEFT", 0, yOffset)
    debugHeader:SetText("|cff32c4ffDebug Options|r")
    yOffset = yOffset - 25
    
    -- Show debug messages
    local debugCB = self:CreateCheckbox(parent, "Show debug messages in chat", 0, yOffset, function(checked)
        self.db.communication.showDebugMessages = checked
        self.db.debug = checked
    end, self.db and self.db.communication and self.db.communication.showDebugMessages)
    yOffset = yOffset - 30
    
    -- Log requests
    local logReqCB = self:CreateCheckbox(parent, "Log server requests", 0, yOffset, function(checked)
        self.db.communication.logRequests = checked
    end, self.db and self.db.communication and self.db.communication.logRequests)
    yOffset = yOffset - 30
    
    -- Log responses
    local logRespCB = self:CreateCheckbox(parent, "Log server responses", 0, yOffset, function(checked)
        self.db.communication.logResponses = checked
    end, self.db and self.db.communication and self.db.communication.logResponses)
    yOffset = yOffset - 30
    
    -- Test mode
    local testCB = self:CreateCheckbox(parent, "Use test/mock data (no server required)", 0, yOffset, function(checked)
        self.db.communication.testMode = checked
        if checked then
            self:LoadTestData()
        end
    end, self.db and self.db.communication and self.db.communication.testMode)
    yOffset = yOffset - 40
    
    -- Manual refresh button
    local refreshBtn = self:CreateButton(parent, "Refresh Server Data", 0, yOffset, 150, function()
        DCInfoBar:RequestServerData()
        DCInfoBar:Print("Requesting server data...")
    end)
    yOffset = yOffset - 40
    
    -- Data display
    local dataHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dataHeader:SetPoint("TOPLEFT", 0, yOffset)
    dataHeader:SetText("|cff32c4ffCurrent Server Data|r")
    yOffset = yOffset - 25
    
    -- Scrollable data display
    local dataFrame = CreateFrame("Frame", nil, parent)
    dataFrame:SetPoint("TOPLEFT", 0, yOffset)
    dataFrame:SetSize(400, 150)
    
    dataFrame.bg = dataFrame:CreateTexture(nil, "BACKGROUND")
    dataFrame.bg:SetAllPoints()
    dataFrame.bg:SetColorTexture(0.1, 0.1, 0.12, 0.8)
    
    dataFrame.text = dataFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dataFrame.text:SetPoint("TOPLEFT", 8, -8)
    dataFrame.text:SetPoint("TOPRIGHT", -8, -8)
    dataFrame.text:SetJustifyH("LEFT")
    dataFrame.text:SetJustifyV("TOP")
    dataFrame.text:SetSpacing(2)
    
    -- Update data display on show
    parent:SetScript("OnShow", function()
        local dataText = ""
        
        -- Season
        dataText = dataText .. "|cff32c4ffSeason:|r\n"
        dataText = dataText .. "  Name: " .. (self.serverData.season.name or "Unknown") .. "\n"
        dataText = dataText .. "  Tokens: " .. (self.serverData.season.weeklyTokens or 0) .. "/" .. (self.serverData.season.weeklyCap or 500) .. "\n"
        
        -- Keystone
        dataText = dataText .. "|cff32c4ffKeystone:|r\n"
        if self.serverData.keystone.hasKey then
            dataText = dataText .. "  +" .. self.serverData.keystone.level .. " " .. self.serverData.keystone.dungeonName .. "\n"
        else
            dataText = dataText .. "  No keystone\n"
        end
        
        -- Affixes
        dataText = dataText .. "|cff32c4ffAffixes:|r\n"
        if self.serverData.affixes.names and #self.serverData.affixes.names > 0 then
            dataText = dataText .. "  " .. table.concat(self.serverData.affixes.names, ", ") .. "\n"
        else
            dataText = dataText .. "  No data\n"
        end
        
        dataFrame.text:SetText(dataText)
    end)
end

-- ============================================================================
-- Test Data
-- ============================================================================

function DCInfoBar:LoadTestData()
    self.serverData.season = {
        id = 3,
        name = "Primal Fury",
        weeklyTokens = 127,
        weeklyCap = 500,
        weeklyEssence = 45,
        essenceCap = 200,
        totalTokens = 2450,
        endsIn = 1209600,  -- 14 days
        weeklyReset = 259200,  -- 3 days
    }
    
    self.serverData.keystone = {
        hasKey = true,
        dungeonId = 285,
        dungeonName = "Utgarde Keep",
        dungeonAbbrev = "UK",
        level = 15,
        depleted = false,
        weeklyBest = 16,
        seasonBest = 22,
    }
    
    self.serverData.affixes = {
        ids = { 10, 11, 12 },
        names = { "Fortified", "Bursting", "Storming" },
        descriptions = {
            "Non-boss enemies have 20% more health and deal 30% more damage.",
            "When slain, non-boss enemies explode, dealing damage equal to 10% max HP.",
            "Enemies periodically create damaging whirlwinds that move around."
        },
        resetIn = 259200,
    }
    
    self:Print("Loaded test data.")
end

-- ============================================================================
-- UI Helper Functions
-- ============================================================================

function DCInfoBar:CreateCheckbox(parent, text, x, y, onClick, initialValue)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    cb:SetChecked(initialValue or false)
    
    local label = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", cb, "RIGHT", 5, 0)
    label:SetText(text)
    
    cb:SetScript("OnClick", function(self)
        if onClick then
            onClick(self:GetChecked())
        end
    end)
    
    return cb
end

function DCInfoBar:CreateButton(parent, text, x, y, width, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width or 120, 24)
    btn:SetPoint("TOPLEFT", x, y)
    
    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.bg:SetColorTexture(0.2, 0.2, 0.25, 0.9)
    
    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.text:SetPoint("CENTER")
    btn.text:SetText(text)
    
    btn:SetScript("OnClick", onClick)
    
    btn:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(0.3, 0.3, 0.35, 1)
    end)
    btn:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(0.2, 0.2, 0.25, 0.9)
    end)
    
    return btn
end

function DCInfoBar:CreateRadioButton(parent, text, x, y, onClick, initialValue)
    local btn = CreateFrame("CheckButton", nil, parent, "UIRadioButtonTemplate")
    btn:SetPoint("TOPLEFT", x, y)
    btn:SetChecked(initialValue or false)
    
    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", btn, "RIGHT", 5, 0)
    label:SetText(text)
    
    btn:SetScript("OnClick", function(self)
        if onClick then
            onClick()
        end
    end)
    
    return btn
end

function DCInfoBar:CreateSlider(parent, x, y, minVal, maxVal, currentVal, onChange)
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", x, y)
    slider:SetSize(150, 20)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValue(currentVal)
    slider:SetValueStep(1)
    
    slider.Low:SetText(minVal)
    slider.High:SetText(maxVal)
    slider.Text:SetText(currentVal)
    
    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        self.Text:SetText(value)
        if onChange then
            onChange(value)
        end
    end)
    
    return slider
end

function DCInfoBar:CreateDropdown(parent, x, options, onChange)
    local dropdown = CreateFrame("Frame", nil, parent)
    dropdown:SetSize(100, 24)
    dropdown:SetPoint("TOPLEFT", x, 0)
    
    dropdown.bg = dropdown:CreateTexture(nil, "BACKGROUND")
    dropdown.bg:SetAllPoints()
    dropdown.bg:SetColorTexture(0.15, 0.15, 0.18, 0.9)
    
    dropdown.text = dropdown:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dropdown.text:SetPoint("LEFT", 8, 0)
    dropdown.text:SetText(options[1] or "")
    
    dropdown.arrow = dropdown:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dropdown.arrow:SetPoint("RIGHT", -8, 0)
    dropdown.arrow:SetText("▼")
    
    dropdown:EnableMouse(true)
    dropdown:SetScript("OnMouseDown", function(self)
        -- Toggle dropdown menu
        if self.menu and self.menu:IsShown() then
            self.menu:Hide()
        else
            DCInfoBar:ShowDropdownMenu(self, options, onChange)
        end
    end)
    
    return dropdown
end

function DCInfoBar:ShowDropdownMenu(dropdown, options, onChange)
    if not dropdown.menu then
        dropdown.menu = CreateFrame("Frame", nil, dropdown)
        dropdown.menu:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, 0)
        dropdown.menu:SetSize(dropdown:GetWidth(), #options * 20)
        dropdown.menu:SetFrameStrata("DIALOG")
        
        dropdown.menu.bg = dropdown.menu:CreateTexture(nil, "BACKGROUND")
        dropdown.menu.bg:SetAllPoints()
        dropdown.menu.bg:SetColorTexture(0.1, 0.1, 0.12, 0.95)
        
        for i, option in ipairs(options) do
            local item = CreateFrame("Button", nil, dropdown.menu)
            item:SetSize(dropdown:GetWidth(), 20)
            item:SetPoint("TOPLEFT", 0, -(i-1) * 20)
            
            item.text = item:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            item.text:SetPoint("LEFT", 8, 0)
            item.text:SetText(option)
            
            item:SetScript("OnClick", function()
                dropdown.text:SetText(option)
                dropdown.menu:Hide()
                if onChange then
                    onChange(option)
                end
            end)
            
            item:SetScript("OnEnter", function(self)
                self.text:SetTextColor(0.2, 0.8, 1)
            end)
            item:SetScript("OnLeave", function(self)
                self.text:SetTextColor(1, 1, 1)
            end)
        end
    end
    
    dropdown.menu:Show()
end

function DCInfoBar:ShowPluginOptions(pluginId)
    -- Create a popup for plugin-specific options
    local plugin = self.plugins[pluginId]
    if not plugin then return end
    
    local pluginSettings = self.db.plugins[pluginId] or {}
    
    -- Simple popup dialog
    local popup = CreateFrame("Frame", "DCInfoBarPluginOptions", UIParent)
    popup:SetSize(300, 250)
    popup:SetPoint("CENTER")
    popup:SetFrameStrata("DIALOG")
    popup:EnableMouse(true)
    popup:SetMovable(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", popup.StartMoving)
    popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
    
    popup.bg = popup:CreateTexture(nil, "BACKGROUND")
    popup.bg:SetAllPoints()
    popup.bg:SetColorTexture(0.08, 0.08, 0.1, 0.95)
    
    -- Title
    local title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText((plugin.name or pluginId) .. " Options")
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, popup)
    closeBtn:SetSize(20, 20)
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    closeBtn.text = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    closeBtn.text:SetPoint("CENTER")
    closeBtn.text:SetText("X")
    closeBtn:SetScript("OnClick", function() popup:Hide() end)
    
    local yOffset = -40
    
    -- Show Label
    local labelCB = self:CreateCheckbox(popup, "Show Label", 20, yOffset, function(checked)
        self:SetPluginSetting(pluginId, "showLabel", checked)
    end, pluginSettings.showLabel ~= false)
    yOffset = yOffset - 30
    
    -- Show Icon  
    local iconCB = self:CreateCheckbox(popup, "Show Icon", 20, yOffset, function(checked)
        self:SetPluginSetting(pluginId, "showIcon", checked)
    end, pluginSettings.showIcon ~= false)
    yOffset = yOffset - 40
    
    -- Plugin-specific options would go here
    -- Each plugin can register additional options
    if plugin.OnCreateOptions then
        yOffset = plugin:OnCreateOptions(popup, yOffset)
    end
    
    -- Done button
    local doneBtn = self:CreateButton(popup, "Done", 90, -210, 120, function()
        popup:Hide()
        self:RefreshAllPlugins()
    end)
    
    popup:Show()
end

-- ============================================================================
-- Initialize Options on Load
-- ============================================================================

local optionsInitFrame = CreateFrame("Frame")
DCInfoBar._optionsInitFrame = optionsInitFrame
optionsInitFrame:RegisterEvent("PLAYER_LOGIN")
optionsInitFrame:SetScript("OnEvent", function()
    local delay = 1
    if C_Timer and C_Timer.After then
        C_Timer.After(delay, function()
            if DCInfoBar and DCInfoBar.CreateOptionsPanel and not DCInfoBar.optionsPanel then
                pcall(function()
                    DCInfoBar:CreateOptionsPanel()
                end)
            end
        end)
    else
        if DCInfoBar and DCInfoBar.CreateOptionsPanel and not DCInfoBar.optionsPanel then
            pcall(function()
                DCInfoBar:CreateOptionsPanel()
            end)
        end
    end
end)
