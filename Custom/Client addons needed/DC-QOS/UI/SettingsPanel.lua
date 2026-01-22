-- ============================================================
-- DC-QoS: Settings Panel (Dashboard Layout)
-- ============================================================
-- Hub & Spoke interface: Main dashboard with buttons -> Module settings
-- ============================================================

local addon = DCQOS

-- ============================================================
-- Panel References
-- ============================================================
addon.settingsPanel = nil
addon.moduleFrames = {}   -- Content frames for each module
addon.dashboardFrame = nil -- Main dashboard frame
addon.backButton = nil
addon.currentView = "Dashboard"

-- ============================================================
-- Module lists (Organized for Dashboard)
-- ============================================================
local moduleCategories = {
    {
        name = "Core & Automation",
        modules = { "Automation", "Interface", "Chat", "Tooltips", "DruidFix" }
    },
    {
        name = "Combat",
        modules = { "NameplatesPlus", "CombatLog", "GTFO" }
    },
    {
        name = "Items & Inventory",
        modules = { "Bags", "VendorPlus", "ItemScore" }
    },
    {
        name = "UI Customization",
        modules = { "FrameMover", "Cooldowns", "ExtendedStats", "ActionBars", "Minimap", "Keybinds", "WeakAuras" }
    },
    {
        name = "Character",
        modules = { "TalentManager" }
    },
    {
        name = "Social & System",
        modules = { "SocialEnhancements", "Mail", "Communication", "Profiles" }
    }
}

-- Display names for buttons
local moduleDisplayNames = {
    ["Automation"] = "Automation",
    ["Interface"] = "Interface",
    ["Chat"] = "Chat Enhancements",
    ["Tooltips"] = "Tooltip Info",
    ["DruidFix"] = "Druid Fix",
    ["NameplatesPlus"] = "Nameplates",
    ["CombatLog"] = "Combat Log",
    ["GTFO"] = "GTFO Alerts",
    ["Bags"] = "Bag & Bank",
    ["VendorPlus"] = "Vendor",
    ["ItemScore"] = "Item Score / Pawn",
    ["FrameMover"] = "Move Frames",
    ["WeakAuras"] = "WeakAuras",
    ["Cooldowns"] = "Cooldown Text",
    ["ExtendedStats"] = "Extended Stats",
    ["ActionBars"] = "Action Bars",
    ["Minimap"] = "Minimap",
    ["Keybinds"] = "Keybinds",
    ["SocialEnhancements"] = "Social",
    ["Mail"] = "Mail",
    ["Communication"] = "Sync & Server",
    ["Profiles"] = "Profiles",
    ["TalentManager"] = "Talent Manager",
}

-- Icons for buttons (standard WoW icons)
local moduleIcons = {
    ["Automation"] = "Interface\\Icons\\Inv_Gizmo_02",
    ["Interface"] = "Interface\\Icons\\Inv_Misc_Book_09",
    ["Chat"] = "Interface\\Icons\\Spell_Holy_Dizzy",
    ["Tooltips"] = "Interface\\Icons\\Inv_Misc_Note_02",
    ["DruidFix"] = "Interface\\Icons\\Ability_Druid_TwilightsWrath",
    ["NameplatesPlus"] = "Interface\\Icons\\Ability_Creature_Cursed_01",
    ["CombatLog"] = "Interface\\Icons\\Ability_Warrior_OffensiveStance",
    ["GTFO"] = "Interface\\Icons\\Spell_Fire_Fire",
    ["Bags"] = "Interface\\Icons\\Inv_Misc_Bag_10",
    ["VendorPlus"] = "Interface\\Icons\\Inv_Misc_Coin_02",
    ["ItemScore"] = "Interface\\Icons\\Inv_Sword_04",
    ["FrameMover"] = "Interface\\Icons\\Inv_Misc_Map_01",
    ["WeakAuras"] = "Interface\\Icons\\Spell_Nature_WispSplode",
    ["Cooldowns"] = "Interface\\Icons\\Spell_Nature_TimeStop",
    ["ExtendedStats"] = "Interface\\Icons\\Spell_Holy_PowerWordShield",
    ["ActionBars"] = "Interface\\Icons\\Ability_Warrior_BattleShout",
    ["Minimap"] = "Interface\\Icons\\INV_Misc_Map_01",
    ["Keybinds"] = "Interface\\Icons\\INV_Misc_Key_14",
    ["SocialEnhancements"] = "Interface\\Icons\\Spell_Holy_Stoicism",
    ["Mail"] = "Interface\\Icons\\Inv_Letter_02",
    ["Communication"] = "Interface\\Icons\\Spell_Holy_DivineProvidence",
    ["Profiles"] = "Interface\\Icons\\INV_Misc_Note_02",
    ["TalentManager"] = "Interface\\Icons\\Ability_Marksmanship",
}

-- ============================================================
-- Helper Functions
-- ============================================================

local function CreateDashboardButton(parent, moduleName, x, y)
    local displayName = moduleDisplayNames[moduleName] or moduleName
    local iconPath = moduleIcons[moduleName] or "Interface\\Icons\\Inv_Misc_QuestionMark"
    
    local button = CreateFrame("Button", "DCQoSBtn_" .. moduleName, parent, "UIPanelButtonTemplate")
    button:SetSize(150, 26)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    
    -- Icon
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(20, 20)
    button.icon:SetPoint("LEFT", 4, 0)
    button.icon:SetTexture(iconPath)
    
    -- Text
    button.text = button:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    button.text:SetPoint("LEFT", button.icon, "RIGHT", 6, 0)
    button.text:SetPoint("RIGHT", -5, 0)
    button.text:SetText(displayName)
    button.text:SetJustifyH("LEFT")
    
    button:SetScript("OnClick", function()
        addon:ShowModule(moduleName)
    end)
    
    return button
end

local function CreateModuleFrame(parent, name)
    local frame = CreateFrame("Frame", "DCQoSFrame_" .. name, parent)
    -- Position: Below title/back button area
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -50)
    frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, 10)
    frame:Hide()
    
    -- Background for content area
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetTexture(0, 0, 0, 0.3)
    
    -- Scroll Frame
    local safeName = tostring(name or ""):gsub("[^%w_]", "")
    local scroll = CreateFrame("ScrollFrame", "DCQoSScroll_" .. safeName, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 6)
    
    local content = CreateFrame("Frame", nil, scroll)
    content:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
    content:SetSize(1, 1) -- Autosize later
    scroll:SetScrollChild(content)
    
    frame.scrollFrame = scroll
    frame.content = content

    local function SyncContentWidth()
        if not frame.content or not frame.scrollFrame then return end
        local w = frame.scrollFrame:GetWidth()
        if w and w > 0 then
            frame.content:SetWidth(w)
        end
    end
    
    frame:SetScript("OnSizeChanged", function(self)
        if not self.content or not self.scrollFrame then return end
        local w = self.scrollFrame:GetWidth()
        if w and w > 0 then
            self.content:SetWidth(w)
        end
    end)

    if scroll and scroll.HookScript then
        scroll:HookScript("OnSizeChanged", SyncContentWidth)
    end
    if frame and frame.HookScript then
        frame:HookScript("OnShow", SyncContentWidth)
    end
    
    return frame
end

-- ============================================================
-- Create Communication Settings (Legacy helper)
-- ============================================================
local function CreateCommunicationSettings(parent)
    local settings = addon.settings.communication or {}
    
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Communication Settings")
    
    local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText("Configure server communication and synchronization options.")
    
    local yOffset = -70
    
    -- Auto Sync
    local autoSyncCb = addon:CreateCheckbox(parent, "DCQoSAutoSync")
    autoSyncCb:SetPoint("TOPLEFT", 16, yOffset)
    autoSyncCb.Text:SetText("Auto-sync Settings with Server")
    autoSyncCb:SetChecked(settings.autoSync ~= false)
    autoSyncCb:SetScript("OnClick", function(self)
        addon:SetSetting("communication.autoSync", self:GetChecked())
    end)
    yOffset = yOffset - 25

    -- Debug mode
    local debugModeCb = addon:CreateCheckbox(parent, "DCQoSDebugMode")
    debugModeCb:SetPoint("TOPLEFT", 16, yOffset)
    debugModeCb.Text:SetText("Enable debug mode")
    debugModeCb:SetChecked(settings.debugMode == true)
    debugModeCb:SetScript("OnClick", function(self)
        addon:SetSetting("communication.debugMode", self:GetChecked())
    end)
    yOffset = yOffset - 25

    -- Route DC debug to its own chat tab
    local routeDebugCb = addon:CreateCheckbox(parent, "DCQoSRouteDebugToTab")
    routeDebugCb:SetPoint("TOPLEFT", 16, yOffset)
    routeDebugCb.Text:SetText("Send DC debug messages to 'DCDebug' chat tab")
    routeDebugCb:SetChecked(settings.routeDcDebugToTab == true)
    routeDebugCb:SetScript("OnClick", function(self)
        local enabled = self:GetChecked()
        addon:SetSetting("communication.routeDcDebugToTab", enabled)
        if enabled then
            addon:EnsureChatWindow((addon.settings.communication and addon.settings.communication.dcDebugTabName) or "DCDebug")
            addon:Print("DC debug tab enabled (chat tab: DCDebug)", true)
        end
    end)
    yOffset = yOffset - 25

    -- Capture other DC addon debug messages too
    local captureOtherCb = addon:CreateCheckbox(parent, "DCQoSCaptureOtherDcDebug")
    captureOtherCb:SetPoint("TOPLEFT", 34, yOffset)
    captureOtherCb.Text:SetText("Also capture other DC addons' debug lines ([Debug]/[DEBUG]/Protocol/DC_DebugUtils)")
    captureOtherCb:SetChecked(settings.captureDcDebugFromOtherAddons ~= false)
    captureOtherCb:SetScript("OnClick", function(self)
        addon:SetSetting("communication.captureDcDebugFromOtherAddons", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    -- Sync Now
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
    
    -- Connection status
    local statusText = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    statusText:SetPoint("TOPLEFT", 16, yOffset)
    
    local function UpdateStatus()
        if addon.protocol and addon.protocol.connected then
            statusText:SetText("|cff00ff00Connected|r to DCAddonProtocol")
        else
            statusText:SetText("|cffff0000Not Connected|r")
        end
    end
    UpdateStatus()
    yOffset = yOffset - 40
    
    return yOffset - 50
end

-- ============================================================
-- Navigation
-- ============================================================

function addon:ShowDashboard()
    -- Hide all modules
    for _, frame in pairs(self.moduleFrames) do
        frame:Hide()
    end
    
    -- Show dashboard
    if self.dashboardFrame then
        self.dashboardFrame:Show()
    end
    
    -- Hide back button
    if self.backButton then
        self.backButton:Hide()
    end
    
    self.currentView = "Dashboard"
end

function addon:ShowModule(moduleName)
    -- Hide dashboard
    if self.dashboardFrame then
        self.dashboardFrame:Hide()
    end
    
    -- Hide all other modules
    for name, frame in pairs(self.moduleFrames) do
        if name == moduleName then
            frame:Show()
        else
            frame:Hide()
        end
    end
    
    -- Show back button
    if self.backButton then
        self.backButton:Show()
    end
    
    self.currentView = moduleName
end

-- ============================================================
-- Construction
-- ============================================================

function addon:CreateSettingsPanel()
    if self.settingsPanel then return end

    -- Ensure Interface Options frame is enlarged for better layout space
    if InterfaceOptionsFrame and not InterfaceOptionsFrame.__dcQoSResized then
        InterfaceOptionsFrame.__dcQoSResized = true
        InterfaceOptionsFrame:SetWidth(900)
        InterfaceOptionsFrame:SetHeight(660)

        if InterfaceOptionsFrameCategories then
            InterfaceOptionsFrameCategories:SetHeight(InterfaceOptionsFrame:GetHeight() - 100)
        end

        if InterfaceOptionsFramePanelContainer then
            InterfaceOptionsFramePanelContainer:ClearAllPoints()
            if InterfaceOptionsFrameCategories then
                InterfaceOptionsFramePanelContainer:SetPoint("TOPLEFT", InterfaceOptionsFrameCategories, "TOPRIGHT", 8, -8)
            else
                InterfaceOptionsFramePanelContainer:SetPoint("TOPLEFT", InterfaceOptionsFrame, "TOPLEFT", 160, -72)
            end
            InterfaceOptionsFramePanelContainer:SetPoint("BOTTOMRIGHT", InterfaceOptionsFrame, "BOTTOMRIGHT", -28, 32)

            local leftWidth = InterfaceOptionsFrameCategories and InterfaceOptionsFrameCategories:GetWidth() or 150
            InterfaceOptionsFramePanelContainer:SetWidth(InterfaceOptionsFrame:GetWidth() - leftWidth - 40)
            InterfaceOptionsFramePanelContainer:SetHeight(InterfaceOptionsFrame:GetHeight() - 100)
        end
    end
    
    -- Main Panel
    local panel = CreateFrame("Frame", "DCQoSSettingsPanel", InterfaceOptionsFramePanelContainer)
    panel.name = "DC-QoS"
    panel:Hide()
    
    -- Header
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cff00ff00DC|r-QoS Dashboard")
    
    -- Back Button (Hidden initially)
    local backBtn = CreateFrame("Button", "DCQoSBackBtn", panel, "UIPanelButtonTemplate")
    backBtn:SetSize(80, 22)
    backBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -16)
    backBtn:SetText("< Back")
    backBtn:Hide()
    backBtn:SetScript("OnClick", function()
        addon:ShowDashboard()
    end)
    self.backButton = backBtn
    
    -- Description (Dashboard only)
    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText("Version " .. self.version .. " - Select a module to configure.")
    
    self.settingsPanel = panel
    InterfaceOptions_AddCategory(panel)

    -- 1. Create Dashboard Frame
    local dashboard = CreateFrame("Frame", "DCQoSDashboard", panel)
    dashboard:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -50)
    dashboard:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -10, 10)
    self.dashboardFrame = dashboard
    
    -- Populate Dashboard Buttons
    -- Populate Dashboard Buttons
    local startX = 10
    local startY = -4
    local colWidth = 155
    local rowHeight = 30
    
    local currentY = startY
    
    for _, category in ipairs(moduleCategories) do
        -- Category Header
        local catHeader = dashboard:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        catHeader:SetPoint("TOPLEFT", startX, currentY)
        catHeader:SetText(category.name)
        catHeader:SetTextColor(1, 0.82, 0) -- Gold
        
        currentY = currentY - 18
        
        -- Buttons Grid (3 columns)
        local col = 0
        
        for _, modName in ipairs(category.modules) do
            CreateDashboardButton(dashboard, modName, startX + (col * colWidth), currentY)
            
            col = col + 1
            if col >= 3 then
                col = 0
                currentY = currentY - rowHeight
            end
        end
        
        if col > 0 then
            currentY = currentY - rowHeight
        end
        currentY = currentY - 8 -- spacer
    end

    -- 2. Create Frames for ALL known modules
    -- (We iterate category lists to find them all easily)
    for _, category in ipairs(moduleCategories) do
        for _, modName in ipairs(category.modules) do
            local frame = CreateModuleFrame(panel, modName)
            self.moduleFrames[modName] = frame
            
            local module = self.modules[modName]
            -- Special case for Bags using BagEnhancements
            if not module and modName == "Bags" then module = self.modules["BagEnhancements"] end

            if module and module.CreateSettings then
                local y = module.CreateSettings(frame.content)
                if type(y) == "number" then
                    frame.content:SetHeight(math.max(1, -y + 30))
                end
            elseif modName == "Communication" then
                local y = CreateCommunicationSettings(frame.content)
                if type(y) == "number" then
                    frame.content:SetHeight(math.max(1, -y + 30))
                end
            end
        end
    end
    
    -- 3. Show Dashboard initially
    self:ShowDashboard()
end

-- ============================================================
-- Toggle
-- ============================================================
function addon:ToggleSettings()
    if not self.settingsPanel then
        self:CreateSettingsPanel()
    end
    InterfaceOptionsFrame_OpenToCategory("DC-QoS")
    InterfaceOptionsFrame_OpenToCategory("DC-QoS")
end

-- ============================================================
-- Init
-- ============================================================
addon:RegisterEvent("PLAYER_LOGIN", function()
    addon:DelayedCall(1, function()
        addon:CreateSettingsPanel()
    end)
end)
