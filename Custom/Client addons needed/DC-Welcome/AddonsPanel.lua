--[[
    DC-Welcome AddonsPanel.lua
    Addons Hub - Shows all DC addons with Open and Settings buttons
    
    Features:
    - Lists all registered DC addons
    - Open button to launch the addon
    - Settings button to open addon settings
    - Status indicators for installed/loaded addons
    
    Author: DarkChaos-255
    Date: December 2025
]]

local addonName = "DC-Welcome"
DCWelcome = DCWelcome or {}
local L = DCWelcome.L

-- =============================================================================
-- DC Addon Registry
-- =============================================================================
-- Each addon entry defines how to open it and its settings

DCWelcome.RegisteredAddons = {
    -- =========================================================================
    -- Only addons that actually exist in: Custom\Client addons needed\
    -- DC-MythicPlus, DC-Leaderboards, DC-Hotspot, DC-ItemUpgrade,
    -- DC-AOESettings, DC-HinterlandBG, DC-AddonProtocol
    -- 
    -- VERIFIED globals and slash commands:
    -- - DCMythicPlusHUD + SlashCmdList["DCM"] (/dcm) + SlashCmdList["DCGF"] (/dcgf)
    -- - DarkChaos_ItemUpgrade + SlashCmdList["DCUPGRADE"] (/dcu, /upgrade)
    -- - DCAoELootSettings + SlashCmdList["DCAOELOOT"] (/aoeloot, /dcaoe)
    -- - DCHotspot + SlashCmdList["DCHOTSPOT"] (/dchotspot, /dchs)
    -- - HLBG + SlashCmdList["HLBGSHOW"] (/hlbgshow) + SlashCmdList["HLBGCONFIG"] (/hlbgconfig)
    -- =========================================================================
    {
        id = "dc-mythicplus",
        name = "Mythic+ Suite",
        description = "HUD, Group Finder, Live Runs Spectator, Keystone Activation, and Scheduled Events",
        icon = DCWelcome.ADDON_PATH .. "Textures\\Icons\\MythicPlus_64.tga",
        color = {0.2, 0.8, 1.0},  -- Cyan
        category = "Dungeons",
        minLevel = 1,
        openButtonIcon = DCWelcome.ADDON_PATH .. "Textures\\Icons\\MythicPlus_64.tga",
        openCommand = "/dcgf",
        settingsCommand = "/dcm settings",
        openFunc = function()
            -- Open Group Finder
            if DCMythicPlusHUD and DCMythicPlusHUD.GroupFinder and DCMythicPlusHUD.GroupFinder.Toggle then
                DCMythicPlusHUD.GroupFinder:Toggle()
            elseif SlashCmdList["DCGF"] then
                SlashCmdList["DCGF"]("")
            else
                DCWelcome.Print("Mythic+ addon not loaded. Try /dcm or /dcgf")
            end
        end,
        settingsFunc = function()
            -- Open Interface Options panel for Mythic+ settings
            local panel = _G["DCMythicPlus_InterfaceOptions"]
            if panel then
                InterfaceOptionsFrame_OpenToCategory(panel)
                InterfaceOptionsFrame_OpenToCategory(panel)  -- Call twice for WoW bug
            elseif SlashCmdList["DCM"] then
                SlashCmdList["DCM"]("help")
            else
                DCWelcome.Print("Mythic+ addon not loaded")
            end
        end,
        isLoaded = function()
            return DCMythicPlusHUD ~= nil or SlashCmdList["DCM"] ~= nil or SlashCmdList["DCGF"] ~= nil
        end,
        -- Great Vault Button
        hasSecondButton = true,
        secondButtonName = "Great Vault",
        secondButtonIcon = DCWelcome.ADDON_PATH .. "Textures\\Icons\\MythicPlus_64.tga",
        secondButtonFunc = function()
            if DCMythicPlusHUD and DCMythicPlusHUD.GreatVault and DCMythicPlusHUD.GreatVault.Toggle then
                DCMythicPlusHUD.GreatVault:Toggle()
            elseif SlashCmdList["DCM"] then
                SlashCmdList["DCM"]("vault")
            else
                DCWelcome.Print("Great Vault UI not available")
            end
        end,
    },
    {
        id = "dc-leaderboards",
        name = "Leaderboards",
        description = "M+, PvP, and seasonal rankings browser",
        icon = DCWelcome.ADDON_PATH .. "Textures\\Icons\\Leaderboards_64.tga",
        color = {1, 0.84, 0},  -- Gold
        category = "Competition",
        minLevel = 1,
        openCommand = "/dcboard",
        settingsCommand = nil,
        openFunc = function()
            if DCLeaderboards and DCLeaderboards.Toggle then
                DCLeaderboards:Toggle()
            elseif SlashCmdList["DCBOARD"] then
                SlashCmdList["DCBOARD"]("")
            else
                DCWelcome.Print("Leaderboards addon not loaded")
            end
        end,
        settingsFunc = nil,  -- No settings panel
        isLoaded = function()
            return DCLeaderboards ~= nil or SlashCmdList["DCBOARD"] ~= nil
        end,
    },
    {
        id = "dc-hotspot",
        name = "Hotspot Map",
        description = "Shows dynamic XP zones on the world map. Type /dchotspot for options.",
        icon = DCWelcome.ADDON_PATH .. "Textures\\Icons\\Mapupgrades_64.tga",
        color = {0, 0.8, 1},  -- Cyan
        category = "World",
        minLevel = 1,
        infoOnly = true,  -- No open button, integrated into world map
        openCommand = nil,
        settingsCommand = "/dchotspot options",
        openFunc = nil,
        settingsFunc = function()
            -- /dchotspot options opens the settings panel
            if SlashCmdList["DCHOTSPOT"] then
                SlashCmdList["DCHOTSPOT"]("options")
            else
                DCWelcome.Print("Hotspot addon not loaded")
            end
        end,
        isLoaded = function()
            return SlashCmdList["DCHOTSPOT"] ~= nil
        end,
    },
    {
        id = "dc-itemupgrade",
        name = "Item Upgrades",
        description = "Upgrade gear with tokens from M+ and raids",
        icon = DCWelcome.ADDON_PATH .. "Textures\\Icons\\ItemUpgrade_64.tga",
        color = {0, 0.44, 0.87},  -- Blue
        category = "Gear",
        minLevel = 1,
        openButtonIcon = DCWelcome.ADDON_PATH .. "Textures\\Icons\\ItemUpgrade_64.tga",
        openCommand = "/dcu",
        settingsCommand = "/dcu settings",
        hasSecondButton = true,  -- Special: has heirloom button
        secondButtonName = "Heirlooms",
        secondButtonIcon = DCWelcome.ADDON_PATH .. "Textures\\Icons\\HeirloomUpgrade_64.tga",
        secondButtonFunc = function()
            -- /dcu heirloom opens heirloom upgrade window
            if DarkChaos_ItemUpgrade then
                DarkChaos_ItemUpgrade.uiMode = "HEIRLOOM"
                if DarkChaos_ItemUpgradeFrame then
                    DarkChaos_ItemUpgradeFrame:Show()
                    if DarkChaos_ItemUpgradeFrame.TitleText then
                        DarkChaos_ItemUpgradeFrame.TitleText:SetText("Heirloom Upgrade")
                    end
                end
            elseif SlashCmdList["DCUPGRADE"] then
                SlashCmdList["DCUPGRADE"]("heirloom")
            else
                DCWelcome.Print("Item Upgrade addon not loaded")
            end
        end,
        openFunc = function()
            -- Open the standard upgrade window directly
            if DarkChaos_ItemUpgrade then
                DarkChaos_ItemUpgrade.uiMode = "STANDARD"
                if DarkChaos_ItemUpgradeFrame then
                    if DarkChaos_ItemUpgradeFrame:IsShown() then
                        DarkChaos_ItemUpgradeFrame:Hide()
                    else
                        DarkChaos_ItemUpgradeFrame:Show()
                        if DarkChaos_ItemUpgradeFrame.TitleText then
                            DarkChaos_ItemUpgradeFrame.TitleText:SetText("Item Upgrade")
                        end
                    end
                end
            elseif SlashCmdList["DCUPGRADE"] then
                -- This shows help, but let's try to open the frame anyway
                if _G["DarkChaos_ItemUpgradeFrame"] then
                    _G["DarkChaos_ItemUpgradeFrame"]:Show()
                else
                    SlashCmdList["DCUPGRADE"]("")
                end
            else
                DCWelcome.Print("Item Upgrade addon not loaded")
            end
        end,
        settingsFunc = function()
            -- /dcu settings opens settings panel
            if SlashCmdList["DCUPGRADE"] then
                SlashCmdList["DCUPGRADE"]("settings")
            elseif DarkChaos_ItemUpgrade and DarkChaos_ItemUpgrade.OpenSettingsPanel then
                DarkChaos_ItemUpgrade.OpenSettingsPanel()
            else
                DCWelcome.Print("Item Upgrade addon not loaded")
            end
        end,
        isLoaded = function()
            return DarkChaos_ItemUpgrade ~= nil or SlashCmdList["DCUPGRADE"] ~= nil
        end,
    },
    {
        id = "dc-aoesettings",
        name = "AOE Loot Settings",
        description = "Configure mass looting, filters, and auto-sell",
        icon = DCWelcome.ADDON_PATH .. "Textures\\Icons\\AOESettings_64.tga",
        color = {0, 1, 0},  -- Green
        category = "Settings",
        minLevel = 1,
        settingsOnly = true,  -- Only has settings button, no open button
        openCommand = nil,
        settingsCommand = "/aoeloot config",
        openFunc = nil,
        settingsFunc = function()
            -- /aoeloot config opens Interface Options panel
            if SlashCmdList["DCAOELOOT"] then
                SlashCmdList["DCAOELOOT"]("config")
            elseif DCAoELootSettings and DCAoELootSettings.optionsPanel then
                InterfaceOptionsFrame_OpenToCategory(DCAoELootSettings.optionsPanel)
                InterfaceOptionsFrame_OpenToCategory(DCAoELootSettings.optionsPanel)
            else
                DCWelcome.Print("AOE Settings addon not loaded")
            end
        end,
        isLoaded = function()
            return DCAoELootSettings ~= nil or SlashCmdList["DCAOELOOT"] ~= nil
        end,
    },
    {
        id = "dc-infobar",
        name = "Info Bar",
        description = "Top/Bottom info bar (season, keystone, events, character stats).",
        icon = DCWelcome.ADDON_PATH .. "Textures\\Icons\\InfoBar_64.tga",
        color = {0.2, 0.8, 1.0},
        category = "UI",
        minLevel = 1,
        openCommand = "/infobar toggle",
        settingsCommand = "/infobar",
        openFunc = function()
            if SlashCmdList["DCINFOBAR"] then
                SlashCmdList["DCINFOBAR"]("toggle")
            elseif DCInfoBar and DCInfoBar.bar then
                DCInfoBar.bar:SetShown(not DCInfoBar.bar:IsShown())
            else
                DCWelcome.Print("DC-InfoBar not loaded")
            end
        end,
        settingsFunc = function()
            if SlashCmdList["DCINFOBAR"] then
                SlashCmdList["DCINFOBAR"]("")
            elseif DCInfoBar and DCInfoBar.OpenOptions then
                DCInfoBar:OpenOptions()
            else
                DCWelcome.Print("DC-InfoBar settings not available")
            end
        end,
        isLoaded = function()
            return DCInfoBar ~= nil or SlashCmdList["DCINFOBAR"] ~= nil
        end,
    },
    {
        id = "dc-collection",
        name = "Collections",
        description = "Mounts, Pets, Toys, and Appearances interface.",
        icon = DCWelcome.ADDON_PATH .. "Textures\\Icons\\Collection_64.tga",
        color = {0.1, 0.8, 0.2},  -- Fel Green
        category = "World",
        minLevel = 1,
        openCommand = "/dcc",
        settingsCommand = nil,
        openFunc = function()
            if DCCollection and DCCollection.Toggle then
                DCCollection:Toggle()
            elseif SlashCmdList["DCCOLLECTION"] then
                SlashCmdList["DCCOLLECTION"]("")
            else
                DCWelcome.Print("Collections addon not loaded")
            end
        end,
        isLoaded = function()
            return DCCollection ~= nil or SlashCmdList["DCCOLLECTION"] ~= nil
        end,
    },
    {
        id = "dc-qos",
        name = "Quality of Service",
        description = "QoL features: Auto-Quest, Cooldown Text, Auto-Repair, Auto-Sell, and Mail Collection.",
        icon = DCWelcome.ADDON_PATH .. "Textures\\Icons\\QOS_64.tga",
        color = {1.0, 0.82, 0.0},  -- Gold
        category = "Settings",
        minLevel = 1,
        openCommand = nil,
        settingsCommand = "/dcqos",
        openFunc = nil,  -- No main window, just settings
        settingsFunc = function()
            if DCQOS and DCQOS.ToggleSettings then
                DCQOS:ToggleSettings()
            elseif SlashCmdList["DCQOS"] then
                SlashCmdList["DCQOS"]("")
            else
                DCWelcome.Print("DC-QoS addon not loaded")
            end
        end,
        isLoaded = function()
            return DCQOS ~= nil or SlashCmdList["DCQOS"] ~= nil
        end,
    },
    {
        id = "dc-hinterlandbg",
        name = "Hinterland BG",
        description = "Open-world PvP battleground in The Hinterlands zone.",
        icon = DCWelcome.ADDON_PATH .. "Textures\\Icons\\HinterlandBG_64.tga",
        color = {1, 0, 0},  -- Red
        category = "PvP",
        minLevel = 80,
        openCommand = "/hlbgshow",
        settingsCommand = "/hlbgconfig",
        openFunc = function()
            -- Match the behavior of the PVP frame HLBG button
            if HLBG and HLBG.UI and HLBG.UI.Frame then
                -- Temporarily re-parent to UIParent so it's visible without PVP frame
                -- Store original parent to restore later if needed
                local frame = HLBG.UI.Frame
                local pvpFrame = _G["PVPParentFrame"] or _G["PVPFrame"]
                
                -- If parent is PVP frame and it's not visible, re-parent to UIParent
                if frame:GetParent() == pvpFrame and pvpFrame and not pvpFrame:IsShown() then
                    frame:SetParent(UIParent)
                    frame:SetFrameStrata("DIALOG")
                    frame:ClearAllPoints()
                    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
                end
                
                -- Show the HLBG frame
                frame:Show()
                
                -- Show the first tab (History) by default
                if HLBG.UI.Tabs and HLBG.UI.Tabs[1] then
                    local tabIdx = (DCHLBGDB and DCHLBGDB.lastInnerTab) or 1
                    -- Try to click the tab
                    local tab = HLBG.UI.Tabs[tabIdx]
                    if tab and tab:GetScript("OnClick") then
                        tab:GetScript("OnClick")(tab)
                    end
                end
                -- Prime data (prefers DCAddonProtocol -> AIO -> dot-command)
                local season = (HLBG._getSeason and HLBG._getSeason()) or 0
                if type(HLBG.RequestHistoryUI) == 'function' then
                    HLBG.RequestHistoryUI(1, 20, season, 'id', 'DESC')
                elseif type(HLBG.RequestHistory) == 'function' then
                    HLBG.RequestHistory()
                end
                if type(HLBG.RequestStats) == 'function' then
                    if season and season > 0 then
                        HLBG.RequestStats(season)
                    else
                        HLBG.RequestStats()
                    end
                end
            elseif SlashCmdList["HLBGSHOW"] then
                SlashCmdList["HLBGSHOW"]("")
            else
                DCWelcome.Print("Hinterland BG UI not available")
            end
        end,
        settingsFunc = function()
            -- Open Interface Options panel for HLBG settings
            local panel = _G["DCHLBG_InterfaceOptions"]
            if panel then
                InterfaceOptionsFrame_OpenToCategory(panel)
                InterfaceOptionsFrame_OpenToCategory(panel)  -- Call twice for WoW bug
            elseif HLBG and HLBG.UI and HLBG.UI.Settings then
                HLBG.UI.Settings:Show()
            else
                DCWelcome.Print("HLBG settings not available. Use Interface > AddOns > DC HLBG Addon")
            end
        end,
        isLoaded = function()
            return HLBG ~= nil or SlashCmdList["HLBGSHOW"] ~= nil
        end,
    },
}

-- =============================================================================
-- Addon Card Creation
-- =============================================================================

local CARD_WIDTH = 560
local CARD_HEIGHT = 70
local BUTTON_SIZE = 28

local function CreateAddonCard(parent, addonInfo, yOffset)
    local card = CreateFrame("Frame", "DCWelcome_Addon_" .. addonInfo.id, parent)
    card:SetSize(CARD_WIDTH, CARD_HEIGHT)
    card:SetPoint("TOPLEFT", 10, yOffset)
    card.addonInfo = addonInfo
    
    -- Background
    local bg = card:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(0.08, 0.08, 0.12, 0.95)
    card.bg = bg
    
    -- Left color bar (accent)
    local colorBar = card:CreateTexture(nil, "ARTWORK")
    colorBar:SetWidth(4)
    colorBar:SetPoint("TOPLEFT", 5, -5)
    colorBar:SetPoint("BOTTOMLEFT", 5, 5)
    local r, g, b = 0.5, 0.5, 1  -- Default blue
    if addonInfo.color then
        r, g, b = unpack(addonInfo.color)
    end
    colorBar:SetTexture(r, g, b, 1)
    card.colorBar = colorBar
    
    -- Icon (left side)
    local icon = card:CreateTexture(nil, "ARTWORK")
    icon:SetSize(40, 40)
    icon:SetPoint("LEFT", 20, 0)
    icon:SetTexture(addonInfo.icon)
    card.icon = icon
    
    -- Addon name
    local name = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, -5)
    name:SetText(addonInfo.name)
    name:SetTextColor(1, 1, 1)
    card.nameText = name
    
    -- Description
    local desc = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
    desc:SetWidth(CARD_WIDTH - 200)
    desc:SetJustifyH("LEFT")
    desc:SetText("|cff888888" .. addonInfo.description .. "|r")
    card.descText = desc
    
    -- Category badge (below description, no status text stacking)
    local categoryBadge = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    categoryBadge:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 12, 5)
    categoryBadge:SetText("|cff666666[" .. addonInfo.category .. "]|r")
    card.categoryBadge = categoryBadge
    
    -- Determine button layout based on addon type
    local hasOpenButton = not addonInfo.settingsOnly and not addonInfo.infoOnly and addonInfo.openFunc
    local hasSettingsButton = addonInfo.settingsFunc ~= nil or addonInfo.settingsCommand ~= nil
    local hasSecondButton = addonInfo.hasSecondButton and addonInfo.secondButtonFunc
    
    -- Calculate button positions (right-aligned)
    local rightOffset = -15
    local buttonSpacing = BUTTON_SIZE + 8
    
    -- =============================================================================
    -- SETTINGS BUTTON (Gear icon) - Always rightmost if exists
    -- =============================================================================
    if hasSettingsButton then
        local settingsBtn = CreateFrame("Button", nil, card)
        settingsBtn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
        settingsBtn:SetPoint("RIGHT", rightOffset, 0)
        
        local settingsBg = settingsBtn:CreateTexture(nil, "BACKGROUND")
        settingsBg:SetAllPoints()
        settingsBg:SetTexture(0.3, 0.3, 0.4, 0.9)
        settingsBtn.bg = settingsBg
        
        local settingsIcon = settingsBtn:CreateTexture(nil, "ARTWORK")
        settingsIcon:SetSize(20, 20)
        settingsIcon:SetPoint("CENTER", 0, 0)
        settingsIcon:SetTexture("Interface\\Icons\\Trade_Engineering")
        settingsBtn.icon = settingsIcon
        
        settingsBtn:SetScript("OnEnter", function(self)
            self.bg:SetTexture(0.4, 0.4, 0.5, 1)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Settings", 1, 1, 1)
            if addonInfo.settingsCommand then
                GameTooltip:AddLine("Command: " .. addonInfo.settingsCommand, 0.7, 0.7, 0.7)
            end
            GameTooltip:Show()
        end)
        
        settingsBtn:SetScript("OnLeave", function(self)
            self.bg:SetTexture(0.3, 0.3, 0.4, 0.9)
            GameTooltip:Hide()
        end)
        
        settingsBtn:SetScript("OnClick", function()
            if addonInfo.settingsFunc then
                -- Close welcome window when opening addon settings
                DCWelcome:HideWelcome()
                addonInfo.settingsFunc()
            end
        end)
        
        card.settingsBtn = settingsBtn
        rightOffset = rightOffset - buttonSpacing
    end
    
    -- =============================================================================
    -- SECOND BUTTON (e.g., Heirlooms for Item Upgrade)
    -- =============================================================================
    if hasSecondButton then
        local secondBtn = CreateFrame("Button", nil, card)
        secondBtn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
        secondBtn:SetPoint("RIGHT", rightOffset, 0)
        
        local secondBg = secondBtn:CreateTexture(nil, "BACKGROUND")
        secondBg:SetAllPoints()
        secondBg:SetTexture(0.4, 0.3, 0.15, 0.9)  -- Bronze/gold color
        secondBtn.bg = secondBg
        
        local secondIcon = secondBtn:CreateTexture(nil, "ARTWORK")
        secondIcon:SetSize(22, 22)
        secondIcon:SetPoint("CENTER", 0, 0)
        secondIcon:SetTexture(addonInfo.secondButtonIcon or "Interface\\Icons\\INV_Chest_Plate16")
        secondBtn.icon = secondIcon
        
        secondBtn:SetScript("OnEnter", function(self)
            self.bg:SetTexture(0.5, 0.4, 0.2, 1)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(addonInfo.secondButtonName or "Heirlooms", 1, 0.84, 0)
            GameTooltip:Show()
        end)
        
        secondBtn:SetScript("OnLeave", function(self)
            self.bg:SetTexture(0.4, 0.3, 0.15, 0.9)
            GameTooltip:Hide()
        end)
        
        secondBtn:SetScript("OnClick", function()
            if addonInfo.secondButtonFunc then
                -- Close welcome window when opening addon feature
                DCWelcome:HideWelcome()
                addonInfo.secondButtonFunc()
            end
        end)
        
        card.secondBtn = secondBtn
        rightOffset = rightOffset - buttonSpacing
    end
    
    -- =============================================================================
    -- OPEN BUTTON (Play icon) - Only if not settingsOnly/infoOnly
    -- =============================================================================
    if hasOpenButton then
        local openBtn = CreateFrame("Button", nil, card)
        openBtn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
        openBtn:SetPoint("RIGHT", rightOffset, 0)
        
        local openBg = openBtn:CreateTexture(nil, "BACKGROUND")
        openBg:SetAllPoints()
        openBg:SetTexture(0.15, 0.4, 0.15, 0.9)
        openBtn.bg = openBg
        
        local openIcon = openBtn:CreateTexture(nil, "ARTWORK")
        openIcon:SetSize(20, 20)
        openIcon:SetPoint("CENTER", 0, 0)
        local openTex = addonInfo.openButtonIcon or addonInfo.icon
        if openTex then
            openIcon:SetTexture(openTex)
            openIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        else
            openIcon:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
        end
        openBtn.icon = openIcon
        
        openBtn:SetScript("OnEnter", function(self)
            self.bg:SetTexture(0.2, 0.5, 0.2, 1)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Open " .. addonInfo.name, 1, 1, 1)
            if addonInfo.openCommand then
                GameTooltip:AddLine("Command: " .. addonInfo.openCommand, 0.7, 0.7, 0.7)
            end
            GameTooltip:Show()
        end)
        
        openBtn:SetScript("OnLeave", function(self)
            self.bg:SetTexture(0.15, 0.4, 0.15, 0.9)
            GameTooltip:Hide()
        end)
        
        openBtn:SetScript("OnClick", function()
            if addonInfo.openFunc then
                -- Close welcome window when opening addon
                DCWelcome:HideWelcome()
                addonInfo.openFunc()
            end
        end)
        
        card.openBtn = openBtn
    end
    
    -- =============================================================================
    -- INFO LABEL for infoOnly addons (no buttons except settings)
    -- =============================================================================
    if addonInfo.infoOnly then
        local infoLabel = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        infoLabel:SetPoint("RIGHT", rightOffset, 0)
        infoLabel:SetText("|cff888888Auto|r")
        card.infoLabel = infoLabel
    end
    
    -- =============================================================================
    -- Update Status (simplified - no status text stacking issue)
    -- =============================================================================
    function card:UpdateStatus()
        local isLoaded = self.addonInfo.isLoaded and self.addonInfo.isLoaded() or false
        
        -- Update open button appearance if it exists
        if self.openBtn then
            if isLoaded then
                self.openBtn.bg:SetTexture(0.15, 0.4, 0.15, 0.9)
                self.openBtn.icon:SetVertexColor(1, 1, 1)
                self.openBtn:Enable()
            else
                self.openBtn.bg:SetTexture(0.2, 0.2, 0.2, 0.5)
                self.openBtn.icon:SetVertexColor(0.5, 0.5, 0.5)
            end
        end
        
        -- Update color bar based on loaded status
        if isLoaded then
            local r, g, b = 0.5, 0.5, 1
            if self.addonInfo.color then
                r, g, b = unpack(self.addonInfo.color)
            end
            self.colorBar:SetTexture(r, g, b, 1)
        else
            self.colorBar:SetTexture(0.3, 0.3, 0.3, 0.5)
        end
    end
    
    -- Hover effect for card
    card:EnableMouse(true)
    card:SetScript("OnEnter", function(self)
        self.bg:SetTexture(0.12, 0.12, 0.18, 0.98)
    end)
    
    card:SetScript("OnLeave", function(self)
        self.bg:SetTexture(0.08, 0.08, 0.12, 0.95)
    end)
    
    -- Initial status update
    card:UpdateStatus()
    
    return card
end

-- =============================================================================
-- Populate Addons Tab
-- =============================================================================

function DCWelcome:PopulateAddonsPanel(scrollChild)
    local yOffset = -5
    
    -- Header
    local header = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOP", 0, yOffset)
    header:SetText("|cff00ccffDC Addons Hub|r")
    yOffset = yOffset - 25
    
    -- Intro text
    local intro = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    intro:SetPoint("TOP", 0, yOffset)
    intro:SetText("|cff888888Click the green button to open, gear icon for settings|r")
    yOffset = yOffset - 25
    
    -- Category grouping
    local categories = {
        { name = "Dungeons", addons = {} },
        { name = "Progression", addons = {} },
        { name = "Gear", addons = {} },
        { name = "World", addons = {} },
        { name = "PvP", addons = {} },
        { name = "Competition", addons = {} },
        { name = "Settings", addons = {} },
    }
    
    -- Group addons by category
    for _, addon in ipairs(DCWelcome.RegisteredAddons) do
        for _, cat in ipairs(categories) do
            if addon.category == cat.name then
                table.insert(cat.addons, addon)
                break
            end
        end
    end
    
    -- Store cards for updates
    scrollChild.addonCards = {}
    
    -- Create cards by category
    for _, cat in ipairs(categories) do
        if #cat.addons > 0 then
            -- Category header
            local catHeader = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            catHeader:SetPoint("TOPLEFT", 15, yOffset)
            catHeader:SetText("|cffffd700" .. cat.name .. "|r")
            yOffset = yOffset - 20
            
            -- Addon cards in this category
            for _, addon in ipairs(cat.addons) do
                local card = CreateAddonCard(scrollChild, addon, yOffset)
                table.insert(scrollChild.addonCards, card)
                yOffset = yOffset - CARD_HEIGHT - 8
            end
            
            yOffset = yOffset - 10  -- Extra space between categories
        end
    end
    
    scrollChild:SetHeight(math.abs(yOffset) + 30)
end

-- =============================================================================
-- Refresh All Addon Status
-- =============================================================================

function DCWelcome:RefreshAddonStatus()
    local contentFrame = DCWelcome.contentFrames and DCWelcome.contentFrames.addons
    if not contentFrame or not contentFrame.scrollChild then return end
    
    local scrollChild = contentFrame.scrollChild
    if scrollChild.addonCards then
        for _, card in ipairs(scrollChild.addonCards) do
            if card.UpdateStatus then
                card:UpdateStatus()
            end
        end
    end
end

-- =============================================================================
-- Register External Addon (API for other addons)
-- =============================================================================

function DCWelcome:RegisterAddon(addonInfo)
    -- Allow external addons to register themselves
    -- addonInfo should have: id, name, description, icon, category, openFunc, settingsFunc
    if not addonInfo or not addonInfo.id then
        return false
    end
    
    -- Check if already registered
    for i, existing in ipairs(self.RegisteredAddons) do
        if existing.id == addonInfo.id then
            -- Update existing entry
            self.RegisteredAddons[i] = addonInfo
            return true
        end
    end
    
    -- Add new entry
    table.insert(self.RegisteredAddons, addonInfo)
    
    -- Refresh display if already shown
    self:RefreshAddonStatus()
    
    return true
end
