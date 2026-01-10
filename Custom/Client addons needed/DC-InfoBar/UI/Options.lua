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

local BG_FELLEATHER = "Interface\\AddOns\\DC-InfoBar\\Textures\\Backgrounds\\FelLeather_512.tga"
local BG_TINT_ALPHA = 0.60

local function ApplyLeaderboardsStyle(frame)
    if not frame or frame.__dcLeaderboardsStyled then
        return
    end
    frame.__dcLeaderboardsStyled = true

    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
    end
    if frame.SetBackdropColor then
        frame:SetBackdropColor(0, 0, 0, 0)
    end

    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints()
    bg:SetTexture(BG_FELLEATHER)

    local tint = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    tint:SetAllPoints(bg)
    tint:SetTexture(0, 0, 0, BG_TINT_ALPHA)
end

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

    -- Parent panel
    local root = CreateFrame("Frame", "DCInfoBarOptionsPanel", UIParent)
    root.name = "DC-InfoBar"
    root:Hide()

    local title = root:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("DC-InfoBar Settings")

    local version = root:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    version:SetText("Version " .. (DCInfoBar.VERSION or "1.0.0"))
    version:SetTextColor(0.5, 0.5, 0.5)

    local hint = root:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    hint:SetPoint("TOPLEFT", version, "BOTTOMLEFT", 0, -12)
    hint:SetWidth(560)
    hint:SetJustifyH("LEFT")
    hint:SetText("Use the sub-categories on the left (General / Plugins / Position / Communication).")

    -- Child panels (match other DC addons: Interface Options subcategories)
    local function CreateChildPanel(suffix, displayName)
        local p = CreateFrame("Frame", "DCInfoBarOptionsPanel_" .. suffix, UIParent)
        p.name = displayName
        p.parent = root.name
        p:Hide()
        return p
    end

    local general = CreateChildPanel("General", "General")
    local plugins = CreateChildPanel("Plugins", "Plugins")
    local position = CreateChildPanel("Position", "Position")
    local comm = CreateChildPanel("Communication", "Communication")

    local function SafeBuild(label, fn)
        local ok, err = xpcall(fn, function(e)
            local trace = ""
            if debugstack then
                trace = debugstack(2, 8, 8)
            end
            return tostring(e) .. (trace ~= "" and (" | " .. trace) or "")
        end)
        if not ok and self.Print then
            self:Print("Options UI build error (" .. label .. "): " .. tostring(err))
        end
    end

    SafeBuild("General", function() self:CreateGeneralTab(general) end)
    SafeBuild("Plugins", function() self:CreatePluginsTab(plugins) end)
    SafeBuild("Position", function() self:CreatePositionTab(position) end)
    SafeBuild("Communication", function() self:CreateCommunicationTab(comm) end)

    -- Register with Interface Options
    if not InterfaceOptions_AddCategory and UIParentLoadAddOn then
        pcall(UIParentLoadAddOn, "Blizzard_InterfaceOptions")
    end

    local function RegisterAll()
        if not InterfaceOptions_AddCategory then return false end
        InterfaceOptions_AddCategory(root)
        InterfaceOptions_AddCategory(general)
        InterfaceOptions_AddCategory(plugins)
        InterfaceOptions_AddCategory(position)
        InterfaceOptions_AddCategory(comm)
        return true
    end

    if not RegisterAll() then
        local reg = CreateFrame("Frame")
        reg:RegisterEvent("ADDON_LOADED")
        reg:SetScript("OnEvent", function(self, _, name)
            if name == "Blizzard_InterfaceOptions" then
                if RegisterAll() then
                    self:UnregisterEvent("ADDON_LOADED")
                    self:SetScript("OnEvent", nil)
                end
            end
        end)
    end

    self.optionsPanel = root
    self.optionsChildPanels = { general = general, plugins = plugins, position = position, communication = comm }
    return root
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
            if checked then self.bar:Show() else self.bar:Hide() end
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
    -- scrollFrame:GetWidth() can be 0 during initial creation; use a sane default.
    scrollChild:SetSize(450, 600)
    scrollFrame:SetScrollChild(scrollChild)

    -- Ensure the scroll child width matches the scroll frame once laid out.
    scrollFrame:SetScript("OnShow", function()
        local w = scrollFrame:GetWidth()
        if w and w > 1 then
            scrollChild:SetWidth(w)
        end
    end)
    
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
        { id = "DCInfoBar_Launchers", name = "Addons", category = "Misc" },
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
        sideDropdown:ClearAllPoints()
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
    local positionGroup = {}
    local topBtn = self:CreateRadioButton(parent, "Top of screen", 20, yOffset, function()
        self:SetBarSetting("position", "top")
        if self.bar then
            self.bar:RefreshSettings()
        end
    end, self:GetBarSetting("position") == "top", positionGroup)
    yOffset = yOffset - 25
    
    local bottomBtn = self:CreateRadioButton(parent, "Bottom of screen", 20, yOffset, function()
        self:SetBarSetting("position", "bottom")
        if self.bar then
            self.bar:RefreshSettings()
        end
    end, self:GetBarSetting("position") == "bottom", positionGroup)
    yOffset = yOffset - 40
    
    -- Background settings
    local bgLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bgLabel:SetPoint("TOPLEFT", 0, yOffset)
    bgLabel:SetText("Background:")
    yOffset = yOffset - 25
    
    -- Show background
    local showBgCB = self:CreateCheckbox(parent, "Show background", 20, yOffset, function(checked)
        self:SetBarSetting("showBackground", checked)
        if self.bar and self.bar.bg then
            if checked then self.bar.bg:Show() else self.bar.bg:Hide() end
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
            -- Apply alpha via SetAlpha for 3.3.5a consistency.
            self.bar.bg:SetColorTexture(bgColor[1] or 0, bgColor[2] or 0, bgColor[3] or 0, 1)
            self.bar.bg:SetAlpha(bgColor[4] or 1)
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
    -- Scrollable content (communication tab is taller than the panel on 3.3.5a)
    local scrollFrame = CreateFrame("ScrollFrame", "DCInfoBarCommunicationScrollFrame", parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 0)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(450, 600)
    scrollFrame:SetScrollChild(scrollChild)

    scrollFrame:SetScript("OnShow", function()
        local w = scrollFrame:GetWidth()
        if w and w > 1 then
            scrollChild:SetWidth(w)
        end
    end)

    local yOffset = 0
    
    -- Header
    local header = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", 0, yOffset)
    header:SetText("|cff32c4ffServer Communication|r")
    yOffset = yOffset - 25
    
    -- Description
    local desc = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    desc:SetPoint("TOPLEFT", 0, yOffset)
    desc:SetText("DC-InfoBar communicates with the server via DCAddonProtocol")
    desc:SetTextColor(0.7, 0.7, 0.7)
    yOffset = yOffset - 30
    
    -- Connection status
    local statusLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusLabel:SetPoint("TOPLEFT", 0, yOffset)
    
    local DC = rawget(_G, "DCAddonProtocol")
    if DC then
        statusLabel:SetText("Status: |cff50ff7aConnected to DCAddonProtocol|r")
    else
        statusLabel:SetText("Status: |cffff5050DCAddonProtocol not found|r")
    end
    yOffset = yOffset - 30
    
    -- Debug options
    local debugHeader = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    debugHeader:SetPoint("TOPLEFT", 0, yOffset)
    debugHeader:SetText("|cff32c4ffDebug Options|r")
    yOffset = yOffset - 25
    
    -- Show debug messages
    local debugCB = self:CreateCheckbox(scrollChild, "Show debug messages in chat", 0, yOffset, function(checked)
        self.db.communication.showDebugMessages = checked
        self.db.debug = checked
    end, self.db and self.db.communication and self.db.communication.showDebugMessages)
    yOffset = yOffset - 30
    
    -- Log requests
    local logReqCB = self:CreateCheckbox(scrollChild, "Log server requests", 0, yOffset, function(checked)
        self.db.communication.logRequests = checked
    end, self.db and self.db.communication and self.db.communication.logRequests)
    yOffset = yOffset - 30
    
    -- Log responses
    local logRespCB = self:CreateCheckbox(scrollChild, "Log server responses", 0, yOffset, function(checked)
        self.db.communication.logResponses = checked
    end, self.db and self.db.communication and self.db.communication.logResponses)
    yOffset = yOffset - 30
    
    -- Test mode
    local testCB = self:CreateCheckbox(scrollChild, "Use test/mock data (no server required)", 0, yOffset, function(checked)
        self.db.communication.testMode = checked
        if checked then
            self:LoadTestData()
        end
    end, self.db and self.db.communication and self.db.communication.testMode)
    yOffset = yOffset - 40
    
    -- Manual refresh button
    local refreshBtn = self:CreateButton(scrollChild, "Refresh Server Data", 0, yOffset, 150, function()
        DCInfoBar:RequestServerData()
        DCInfoBar:Print("Requesting server data...")
    end)
    yOffset = yOffset - 40
    
    -- Data display
    local dataHeader = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dataHeader:SetPoint("TOPLEFT", 0, yOffset)
    dataHeader:SetText("|cff32c4ffCurrent Server Data|r")
    yOffset = yOffset - 25
    
    -- Scrollable data display
    local dataFrame = CreateFrame("Frame", nil, scrollChild)
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

    yOffset = yOffset - 160
    scrollChild:SetHeight(math.abs(yOffset) + 20)
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

function DCInfoBar:CreateRadioButton(parent, text, x, y, onClick, initialValue, group)
    local btn = CreateFrame("CheckButton", nil, parent, "UIRadioButtonTemplate")
    btn:SetPoint("TOPLEFT", x, y)
    btn:SetChecked(initialValue or false)

    if type(group) == "table" then
        table.insert(group, btn)
    end
    
    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", btn, "RIGHT", 5, 0)
    label:SetText(text)
    
    btn:SetScript("OnClick", function(self)
        -- Radio behavior: always end up with one selected within a group.
        if type(group) == "table" then
            for _, other in ipairs(group) do
                if other ~= self then
                    other:SetChecked(false)
                end
            end
            self:SetChecked(true)
        end
        if onClick then
            onClick()
        end
    end)
    
    return btn
end

local sliderCounter = 0
function DCInfoBar:CreateSlider(parent, x, y, minVal, maxVal, currentVal, onChange)
    sliderCounter = sliderCounter + 1
    local name = "DCInfoBarSlider" .. sliderCounter
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", x, y)
    slider:SetSize(150, 20)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValue(currentVal)
    slider:SetValueStep(1)
    
    if _G[name.."Low"] then _G[name.."Low"]:SetText(minVal) end
    if _G[name.."High"] then _G[name.."High"]:SetText(maxVal) end
    if _G[name.."Text"] then _G[name.."Text"]:SetText(currentVal) end
    
    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        if _G[name.."Text"] then _G[name.."Text"]:SetText(value) end
        if onChange then
            onChange(value)
        end
    end)
    
    return slider
end

function DCInfoBar:CreateDropdown(parent, x, options, onChange)
    local dropdown = CreateFrame("Frame", nil, parent)
    dropdown:SetSize(100, 24)
    -- Caller should position the dropdown; avoid anchoring here.
    
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

    ApplyLeaderboardsStyle(popup)
    
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
