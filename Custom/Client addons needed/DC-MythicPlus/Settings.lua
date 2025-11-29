-- DC-MythicPlus Settings.lua
-- Settings panel with Interface Options integration and Communication test buttons

local addonName = "DC-MythicPlus"
local namespace = _G.DCMythicPlusHUD or {}
_G.DCMythicPlusHUD = namespace

-- Default settings
namespace.DefaultSettings = {
    locked = false,
    hidden = false,
    hudScale = 1.0,
    useDCProtocolJSON = true,
    devMode = false,
    showTimerAlerts = true,
    showDeathCounter = true,
    showBossProgress = true,
    showEnemyCount = true,
    position = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 120 }
}

-- Load saved settings or apply defaults
function namespace.LoadSettings()
    DCMythicPlusHUDDB = DCMythicPlusHUDDB or {}
    for setting, defaultValue in pairs(namespace.DefaultSettings) do
        if DCMythicPlusHUDDB[setting] == nil then
            DCMythicPlusHUDDB[setting] = defaultValue
        end
    end
end

-- Save a setting
function namespace.SaveSetting(setting, value)
    DCMythicPlusHUDDB = DCMythicPlusHUDDB or {}
    DCMythicPlusHUDDB[setting] = value
    return value
end

-- Print helper
local function Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff32c4ffMythic+ HUD:|r " .. (msg or ""))
    end
end

-- =====================================================================
-- Interface Options Panel
-- =====================================================================

if type(InterfaceOptions_AddCategory) == 'function' then
    local floor = math.floor
    
    -- Main panel
    local panel = CreateFrame('Frame', 'DCMythicPlus_InterfaceOptions', UIParent)
    panel.name = 'DC Mythic+ HUD'
    panel:Hide()
    
    local title = panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
    title:SetPoint('TOPLEFT', 16, -16)
    title:SetText('DC Mythic+ HUD Settings')
    
    local subtitle = panel:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    subtitle:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', 0, -8)
    subtitle:SetText('Configure the Mythic+ HUD display and communication settings.')
    
    -- Create controls on first show
    panel:SetScript('OnShow', function(self)
        namespace.LoadSettings()
        if self._controlsCreated then return end
        self._controlsCreated = true
        
        local y = -70
        
        -- Helper: create a checkbutton
        local function makeCheck(name, text, setting, tooltip)
            local cb = CreateFrame("CheckButton", name, panel, "InterfaceOptionsCheckButtonTemplate")
            cb:SetPoint("TOPLEFT", 16, y)
            cb:SetHitRectInsets(0, -200, 0, 0)
            _G[name .. "Text"]:SetText(text)
            cb:SetChecked(DCMythicPlusHUDDB and DCMythicPlusHUDDB[setting])
            cb:SetScript("OnClick", function(self)
                namespace.SaveSetting(setting, self:GetChecked())
            end)
            if tooltip then
                cb.tooltipText = tooltip
            end
            y = y - 28
            return cb
        end
        
        -- Section: Display
        local displayHeader = panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
        displayHeader:SetPoint('TOPLEFT', 16, y)
        displayHeader:SetText('Display Options')
        y = y - 24
        
        makeCheck("DCMPlus_Opt_TimerAlerts", "Show Timer Alerts", "showTimerAlerts",
            "Display alerts when timer reaches critical thresholds")
        makeCheck("DCMPlus_Opt_DeathCounter", "Show Death Counter", "showDeathCounter",
            "Display the death penalty counter on the HUD")
        makeCheck("DCMPlus_Opt_BossProgress", "Show Boss Progress", "showBossProgress",
            "Display boss kill progress on the HUD")
        makeCheck("DCMPlus_Opt_EnemyCount", "Show Enemy Count", "showEnemyCount",
            "Display enemy forces percentage on the HUD")
        
        -- HUD Scale slider
        y = y - 10
        local hudScale = CreateFrame("Slider", "DCMPlus_Opt_HUDScale", panel, "OptionsSliderTemplate")
        hudScale:SetPoint("TOPLEFT", 24, y)
        hudScale:SetWidth(220)
        hudScale:SetMinMaxValues(0.5, 2.0)
        hudScale:SetValueStep(0.1)
        hudScale:SetValue((DCMythicPlusHUDDB and DCMythicPlusHUDDB.hudScale) or 1.0)
        _G[hudScale:GetName().."Text"]:SetText("HUD Scale")
        _G[hudScale:GetName().."Low"]:SetText("0.5")
        _G[hudScale:GetName().."High"]:SetText("2.0")
        local hudScaleVal = hudScale:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        hudScaleVal:SetPoint("TOP", hudScale, "BOTTOM", 0, 0)
        hudScaleVal:SetText(string.format("%.1f", hudScale:GetValue()))
        hudScale:SetScript("OnValueChanged", function(self, value)
            value = floor(value * 10 + 0.5) / 10
            namespace.SaveSetting("hudScale", value)
            hudScaleVal:SetText(string.format("%.1f", value))
        end)
        y = y - 60
        
        -- Section: Advanced
        local advHeader = panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
        advHeader:SetPoint('TOPLEFT', 16, y)
        advHeader:SetText('Advanced')
        y = y - 24
        
        makeCheck("DCMPlus_Opt_DevMode", "Developer Mode", "devMode",
            "Enable developer tools and verbose logging")
    end)
    
    InterfaceOptions_AddCategory(panel)
    
    -- =====================================================================
    -- Communication Sub-Panel (Test Buttons)
    -- =====================================================================
    
    local commPanel = CreateFrame('Frame', 'DCMythicPlus_CommOptions', panel)
    commPanel.name = 'Communication'
    commPanel.parent = panel.name
    commPanel:Hide()
    
    local commTitle = commPanel:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
    commTitle:SetPoint('TOPLEFT', 16, -16)
    commTitle:SetText('Communication Settings')
    
    local commSubtitle = commPanel:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    commSubtitle:SetPoint('TOPLEFT', commTitle, 'BOTTOMLEFT', 0, -8)
    commSubtitle:SetText('Configure and test DCAddonProtocol communication.')
    
    commPanel:SetScript('OnShow', function(self)
        namespace.LoadSettings()
        if self._controlsCreated then return end
        self._controlsCreated = true
        
        local y = -70
        local DC = rawget(_G, "DCAddonProtocol")
        local AIO = rawget(_G, "AIO")
        
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
        y = y - 26
        
        -- JSON Toggle
        local jsonCheck = CreateFrame("CheckButton", "DCMPlus_Opt_JSONMode", commPanel, "InterfaceOptionsCheckButtonTemplate")
        jsonCheck:SetPoint("TOPLEFT", 16, y)
        jsonCheck:SetHitRectInsets(0, -200, 0, 0)
        _G["DCMPlus_Opt_JSONModeText"]:SetText("Use JSON Protocol (recommended)")
        jsonCheck:SetChecked(DCMythicPlusHUDDB and DCMythicPlusHUDDB.useDCProtocolJSON)
        jsonCheck:SetScript("OnClick", function(self)
            namespace.SaveSetting("useDCProtocolJSON", self:GetChecked())
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
        local btnWidth = 160
        local btnHeight = 24
        local colSpacing = 170
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
        makeTestButton("Request Keystone Info", "Send CMSG_GET_KEY_INFO (0x01)", function()
            if DC then DC:Send("MPLUS", 0x01) else Print("|cFFFF0000DCAddonProtocol not available|r") end
        end, 1)
        makeTestButton("Request Weekly Affixes", "Send CMSG_GET_AFFIXES (0x02)", function()
            if DC then DC:Send("MPLUS", 0x02) else Print("|cFFFF0000DCAddonProtocol not available|r") end
        end, 2)
        btnRow = btnRow + 1
        
        -- Row 2
        makeTestButton("Request Best Runs", "Send CMSG_GET_BEST_RUNS (0x03)", function()
            if DC then DC:Send("MPLUS", 0x03) else Print("|cFFFF0000DCAddonProtocol not available|r") end
        end, 1)
        makeTestButton("Send Test JSON", "Send a test JSON message", function()
            if DC then DC:Send("MPLUS", 0x00, "J", '{"test":true}'); Print("Sent test JSON") else Print("|cFFFF0000DCAddonProtocol not available|r") end
        end, 2)
        btnRow = btnRow + 1
        
        -- Row 3
        makeTestButton("Ping Server (Handshake)", "Send CMSG_HANDSHAKE to test connectivity", function()
            if DC then DC:Send("CORE", 0x01); Print("Sent handshake") else Print("|cFFFF0000DCAddonProtocol not available|r") end
        end, 1)
        btnRow = btnRow + 1
        
        y = y - (btnRow * rowSpacing) - 20
        
        -- Results/Log Section
        local logHeader = commPanel:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
        logHeader:SetPoint('TOPLEFT', 16, y)
        logHeader:SetText('Test Results')
        y = y - 18
        
        local logDesc = commPanel:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
        logDesc:SetPoint('TOPLEFT', 24, y)
        logDesc:SetText('Results will appear in the chat window. Enable Developer Mode for verbose output.')
        logDesc:SetTextColor(0.7, 0.7, 0.7)
        y = y - 28
        
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
            Print("Status refreshed")
        end)
    end)
    
    InterfaceOptions_AddCategory(commPanel)
end

-- Initialize settings on load
namespace.LoadSettings()
