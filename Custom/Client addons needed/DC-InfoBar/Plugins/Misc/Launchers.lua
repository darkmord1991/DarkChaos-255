--[[
    DC-InfoBar Launchers Plugin
    Small icon row to open commonly-used DC addons/settings.

    Left-click an icon to open its addon.
]]

local addonName = "DC-InfoBar"
local DCInfoBar = DCInfoBar or {}

local LaunchersPlugin = {
    id = "DCInfoBar_Launchers",
    name = "Addons",
    category = "misc",
    type = "custom",
    side = "right",
    priority = 940,
    -- We render our own icon row (addon icons + settings icon) inside the plugin button.
    icon = nil,
    updateInterval = 60,

    leftClickHint = "Open settings menu",
    rightClickHint = nil,
}

local function EnsureInterfaceOptionsLoaded()
    if InterfaceOptionsFrame_OpenToCategory then
        return true
    end
    if UIParentLoadAddOn then
        pcall(UIParentLoadAddOn, "Blizzard_InterfaceOptions")
    end
    return InterfaceOptionsFrame_OpenToCategory ~= nil
end

local function OpenOptionsCategory(categoryName)
    if not categoryName then return end
    if not EnsureInterfaceOptionsLoaded() then return end

    -- WotLK quirk: often requires calling twice to correctly scroll.
    pcall(InterfaceOptionsFrame_OpenToCategory, categoryName)
    pcall(InterfaceOptionsFrame_OpenToCategory, categoryName)
end

local function RunSlashCommand(cmd)
    if type(cmd) ~= "string" or cmd == "" then return end

    if ChatFrame1EditBox and ChatEdit_SendText then
        ChatFrame1EditBox:SetText(cmd)
        ChatEdit_SendText(ChatFrame1EditBox)
        return
    end

    -- Fallback: try to use DEFAULT_CHAT_FRAME editbox
    local eb = DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox
    if eb and ChatEdit_SendText then
        eb:SetText(cmd)
        ChatEdit_SendText(eb)
    end
end

local function OpenItemUpgrade(subcmd)
    if SlashCmdList and type(SlashCmdList["DCUPGRADE"]) == "function" then
        SlashCmdList["DCUPGRADE"](subcmd or "")
        return
    end

    local cmd = "/dcu"
    if subcmd and subcmd ~= "" then
        cmd = cmd .. " " .. subcmd
    end
    RunSlashCommand(cmd)
end

local function ApplyIconStyle(icon)
    if not icon then return end
    -- Crop default icon borders to keep a consistent look.
    if icon.SetTexCoord then
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
end

local function BuildLauncherList()
    local launchers = {}

    -- Welcome
    if IsAddOnLoaded and IsAddOnLoaded("DC-Welcome") then
        table.insert(launchers, {
            key = "welcome",
            name = "Welcome",
            icon = "Interface\\AddOns\\DC-Welcome\\Textures\\Icons\\Welcome_64.tga",
            hint = "Open Welcome",
            onClick = function()
                -- Toggle the welcome screen
                RunSlashCommand("/welcome")
            end,
        })
    end

    -- Leaderboards
    if IsAddOnLoaded and IsAddOnLoaded("DC-Leaderboards") then
        table.insert(launchers, {
            key = "leaderboards",
            name = "Leaderboards",
            icon = "Interface\\AddOns\\DC-Welcome\\Textures\\Icons\\Leaderboards_64.tga",
            hint = "Open Leaderboards",
            onClick = function()
                -- Toggle the main leaderboard window
                RunSlashCommand("/lb")
            end,
        })
    end

    -- ItemUpgrade
    if IsAddOnLoaded and IsAddOnLoaded("DC-ItemUpgrade") then
        table.insert(launchers, {
            key = "itemupgrade",
            name = "ItemUpgrade",
            icon = "Interface\\AddOns\\DC-ItemUpgrade\\Textures\\Icons\\ItemUpgrade_64.tga",
            hint = "Choose Item or Heirloom",
            onClick = function(launcherButton)
                -- Dropdown (Item / Heirloom)
                if DCInfoBar and DCInfoBar.plugins and DCInfoBar.plugins[LaunchersPlugin.id] then
                    DCInfoBar.plugins[LaunchersPlugin.id]:ToggleItemUpgradeMenu(launcherButton)
                else
                    -- Fallback: open the standard Item Upgrade window directly.
                    OpenItemUpgrade("")
                end
            end,
        })
    end

    -- Collection
    if IsAddOnLoaded and IsAddOnLoaded("DC-Collection") then
        table.insert(launchers, {
            key = "collection",
            name = "Collection",
            icon = "Interface\\AddOns\\DC-Collection\\Textures\\Icons\\Collection_64.tga",
            hint = "Open Collection",
            onClick = function()
                -- Toggle the main collection window
                RunSlashCommand("/collection")
            end,
        })
    end

    -- HinterlandBG
    if IsAddOnLoaded and IsAddOnLoaded("DC-HinterlandBG") then
        table.insert(launchers, {
            key = "hinterlandbg",
            name = "HinterlandBG",
            icon = "Interface\\AddOns\\DC-Welcome\\Textures\\Icons\\HinterlandBG_64.tga",
            hint = "Open HinterlandBG",
            onClick = function()
                local HLBG = rawget(_G, "HLBG")

                if HLBG and HLBG.UI and HLBG.UI.Frame then
                    local frame = HLBG.UI.Frame

                    -- HLBG historically parents its frame to PvP UI; reparent so it can be shown from anywhere.
                    if frame.GetParent and frame:GetParent() ~= UIParent and frame.SetParent then
                        frame:SetParent(UIParent)
                        frame:ClearAllPoints()
                        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
                    end

                    if frame.IsShown and frame:IsShown() then
                        frame:Hide()
                    else
                        frame:Show()
                        if frame.Raise then frame:Raise() end
                    end
                    return
                end

                -- Fallbacks
                if _G.SlashCmdList and type(_G.SlashCmdList["HLBGSHOWUI"]) == "function" then
                    _G.SlashCmdList["HLBGSHOWUI"]("")
                elseif _G.SlashCmdList and type(_G.SlashCmdList["HLBGSHOW"]) == "function" then
                    _G.SlashCmdList["HLBGSHOW"]("")
                else
                    RunSlashCommand("/hlbgshow")
                end
            end,
        })
    end

    -- GroupFinder (part of DC-MythicPlus)
    if IsAddOnLoaded and IsAddOnLoaded("DC-MythicPlus") then
        table.insert(launchers, {
            key = "groupfinder",
            name = "GroupFinder",
            icon = "Interface\\Icons\\INV_Misc_GroupLooking",
            hint = "Open GroupFinder",
            onClick = function()
                RunSlashCommand("/groupfinder")
            end,
        })
    end

    -- DC-QoS (settings are the primary UI)
    if IsAddOnLoaded and IsAddOnLoaded("DC-QOS") then
        table.insert(launchers, {
            key = "qos",
            name = "QoS",
            icon = "Interface\\AddOns\\DC-Welcome\\Textures\\Icons\\QOS_64.tga",
            hint = "Choose CombatLog or Settings",
            onClick = function(anchorButton)
                if DCInfoBar and DCInfoBar.plugins and DCInfoBar.plugins[LaunchersPlugin.id] then
                    DCInfoBar.plugins[LaunchersPlugin.id]:ToggleQoSMenu(anchorButton)
                end
            end,
        })
    end

    return launchers
end

local function BuildSettingsList()
    local list = BuildLauncherList()
    -- Copy entries but open settings instead of toggles.
    local out = {}
    for _, e in ipairs(list) do
        local entry = {
            key = e.key,
            name = e.name,
            icon = e.icon,
            onClick = e.onClick,
        }

        if e.key == "leaderboards" then
            entry.onClick = function()
                OpenOptionsCategory("DC-Leaderboards")
                RunSlashCommand("/lb settings")
            end
        elseif e.key == "itemupgrade" then
            entry.onClick = function()
                OpenOptionsCategory("DC ItemUpgrade")
                RunSlashCommand("/dcu settings")
            end
        elseif e.key == "collection" then
            entry.onClick = function()
                OpenOptionsCategory("DC-Collection")
                RunSlashCommand("/collection settings")
            end
        elseif e.key == "welcome" then
            entry.onClick = function()
                OpenOptionsCategory("DC-Welcome")
                RunSlashCommand("/welcomesettings")
            end
        elseif e.key == "hinterlandbg" then
            entry.onClick = function()
                OpenOptionsCategory("DC HLBG Addon")
                RunSlashCommand("/hlbgconfig")
            end
        elseif e.key == "groupfinder" then
            entry.onClick = function()
                OpenOptionsCategory("DC Mythic+")
            end
        elseif e.key == "qos" then
            entry.onClick = function()
                RunSlashCommand("/dcqos")
            end
        end

        table.insert(out, entry)
    end

    -- AOE Loot Settings (client addon)
    local hasAoeLootSettings = (IsAddOnLoaded and IsAddOnLoaded("DC-AOESettings"))
        or (rawget(_G, "DCAoELootSettings") ~= nil)
        or (_G.SlashCmdList and type(_G.SlashCmdList["DCAOELOOT"]) == "function")

    if hasAoeLootSettings then
        local aoeEntry = {
            key = "aoeloot",
            name = "AOE Loot Settings",
            icon = "Interface\\AddOns\\DC-Welcome\\Textures\\Icons\\AOESettings_64.tga",
            onClick = function()
                if _G.SlashCmdList and type(_G.SlashCmdList["DCAOELOOT"]) == "function" then
                    _G.SlashCmdList["DCAOELOOT"]("config")
                else
                    RunSlashCommand("/aoeloot config")
                end
            end,
        }

        local inserted = false
        for i, e in ipairs(out) do
            if e.key == "welcome" then
                table.insert(out, i + 1, aoeEntry)
                inserted = true
                break
            end
        end
        if not inserted then
            table.insert(out, 1, aoeEntry)
        end
    end

    return out
end

function LaunchersPlugin:Rebuild()
    if not self.button then return end

    local button = self.button
    local iconSize = tonumber(DCInfoBar:GetPluginSetting(self.id, "iconSize")) or 16
    local iconPadding = tonumber(DCInfoBar:GetPluginSetting(self.id, "iconPadding")) or 2
    local globalShowIcons = DCInfoBar.db and DCInfoBar.db.global and DCInfoBar.db.global.showIcons
    local pluginShowIcon = DCInfoBar:GetPluginSetting(self.id, "showIcon")

    local iconsAllowed = (globalShowIcons ~= false) and (pluginShowIcon ~= false)

    -- Hide the built-in icon/text usage (we draw our own contents).
    if button.icon then
        button.icon:Hide()
    end
    if button.text then
        button.text:SetText("")
    end

    if not iconsAllowed then
        if button.text then
            button.text:SetText("|cff888888Addons|r")
        end
        button:SetWidth(70)
        if DCInfoBar.bar and DCInfoBar.bar.RefreshLayout then
            DCInfoBar.bar:RefreshLayout()
        end
        return
    end

    button.__launchers = BuildLauncherList()
    button.__launcherButtons = button.__launcherButtons or {}

    if not button.launcherContainer then
        local c = CreateFrame("Frame", nil, button)
        c:SetPoint("LEFT", 4, 0)
        c:SetHeight(iconSize)
        button.launcherContainer = c
    end

    local container = button.launcherContainer
    container:SetHeight(iconSize)

    local shown = 0
    for _, launcher in ipairs(button.__launchers) do
        shown = shown + 1
        local b = button.__launcherButtons[shown]
        if not b then
            b = CreateFrame("Button", nil, container)
            b:RegisterForClicks("LeftButtonUp", "RightButtonUp")

            b.icon = b:CreateTexture(nil, "ARTWORK")
            b.icon:SetAllPoints()
            ApplyIconStyle(b.icon)

            b:SetScript("OnClick", function(self)
                local l = self.launcher
                if l and l.onClick then
                    l.onClick(self)
                end
            end)

            b:SetScript("OnEnter", function(self)
                local l = self.launcher or {}
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:AddLine(l.name or "Addon", 1, 0.82, 0)
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Left-click: " .. (l.hint or "open"), 0.7, 0.7, 0.7)
                GameTooltip:Show()
            end)

            b:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)

            button.__launcherButtons[shown] = b
        end

        b.launcher = launcher
        b:ClearAllPoints()
        if shown == 1 then
            b:SetPoint("LEFT", container, "LEFT", 0, 0)
        else
            b:SetPoint("LEFT", button.__launcherButtons[shown - 1], "RIGHT", iconPadding, 0)
        end
        b:SetSize(iconSize, iconSize)
        b.icon:SetTexture(launcher.icon)
        ApplyIconStyle(b.icon)
        b:Show()
    end

    -- Settings icon at end
    local settingsLauncher = {
        key = "settings",
        name = "Settings",
        icon = "Interface\\AddOns\\DC-Welcome\\Textures\\Icons\\AOESettings_64.tga",
        onClick = function()
            self:ToggleMenu()
        end,
    }

    shown = shown + 1
    local gearBtn = button.__launcherButtons[shown]
    if not gearBtn then
        gearBtn = CreateFrame("Button", nil, container)
        gearBtn:RegisterForClicks("LeftButtonUp")

        gearBtn.icon = gearBtn:CreateTexture(nil, "ARTWORK")
        gearBtn.icon:SetAllPoints()
        ApplyIconStyle(gearBtn.icon)

        gearBtn:SetScript("OnClick", function(self)
            local l = self.launcher
            if l and l.onClick then
                l.onClick()
            end
        end)

        gearBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine("Settings", 1, 0.82, 0)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Open settings menu", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        gearBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        button.__launcherButtons[shown] = gearBtn
    end

    gearBtn.launcher = settingsLauncher
    gearBtn:ClearAllPoints()
    if shown == 1 then
        gearBtn:SetPoint("LEFT", container, "LEFT", 0, 0)
    else
        gearBtn:SetPoint("LEFT", button.__launcherButtons[shown - 1], "RIGHT", iconPadding, 0)
    end
    gearBtn:SetSize(iconSize, iconSize)
    gearBtn.icon:SetTexture(settingsLauncher.icon)
    ApplyIconStyle(gearBtn.icon)
    gearBtn:Show()

    -- Hide extras
    for i = shown + 1, #button.__launcherButtons do
        local b = button.__launcherButtons[i]
        if b then b:Hide() end
    end

    local contentWidth = (shown * iconSize) + ((shown - 1) * iconPadding)
    container:SetWidth(contentWidth)
    button:SetWidth(contentWidth + 10)

    if DCInfoBar.bar and DCInfoBar.bar.RefreshLayout then
        DCInfoBar.bar:RefreshLayout()
    end
end

function LaunchersPlugin:OnActivate()
    self:Rebuild()
end

function LaunchersPlugin:OnSettingChanged(key, _)
    if key == "iconSize" or key == "showIcon" or key == "showLabel" then
        self:Rebuild()
    end
end

function LaunchersPlugin:OnCreateOptions(parent, yOffset)
    local sizeLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sizeLabel:SetPoint("TOPLEFT", 20, yOffset)
    sizeLabel:SetText("Menu Icon Size")
    yOffset = yOffset - 20

    DCInfoBar:CreateSlider(parent, 20, yOffset, 12, 22,
        tonumber(DCInfoBar:GetPluginSetting(self.id, "iconSize")) or 16,
        function(value)
            DCInfoBar:SetPluginSetting(self.id, "iconSize", value)
            self:Rebuild()
        end)
    yOffset = yOffset - 40

    return yOffset
end

function LaunchersPlugin:OnTooltip(tooltip)
    tooltip:AddLine("Addons", 1, 0.82, 0)
    DCInfoBar:AddTooltipSeparator(tooltip)

    tooltip:AddLine("Left-click icons to open:", 0.9, 0.9, 0.9)
    local list = BuildLauncherList()
    for _, launcher in ipairs(list) do
        tooltip:AddLine("  " .. (launcher.name or "(unknown)"), 0.7, 0.7, 0.7)
    end
    tooltip:AddLine("  Settings", 0.7, 0.7, 0.7)
end

local function CreateMenu()
    local menu = CreateFrame("Frame", "DCInfoBarSettingsMenu", UIParent)
    menu:Hide()
    menu:SetFrameStrata("DIALOG")
    menu:SetFrameLevel(50)
    menu:EnableMouse(true)

    if menu.SetBackdrop then
        menu:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        menu:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
        menu:SetBackdropBorderColor(0.1, 0.8, 0.2, 0.8)
    end

    menu.rows = {}

    -- Click-catcher to close when clicking outside.
    local catcher = CreateFrame("Frame", nil, UIParent)
    catcher:Hide()
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("DIALOG")
    catcher:SetFrameLevel(40)
    catcher:EnableMouse(true)
    catcher:SetScript("OnMouseDown", function()
        menu:Hide()
    end)
    menu._catcher = catcher

    menu:SetScript("OnShow", function()
        menu._catcher:Show()
    end)
    menu:SetScript("OnHide", function()
        menu._catcher:Hide()
        GameTooltip:Hide()
    end)

    return menu
end

local function CreateNamedMenu(name)
    local menu = CreateFrame("Frame", name, UIParent)
    menu:Hide()
    menu:SetFrameStrata("DIALOG")
    menu:SetFrameLevel(50)
    menu:EnableMouse(true)

    if menu.SetBackdrop then
        menu:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        menu:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
        menu:SetBackdropBorderColor(0.1, 0.8, 0.2, 0.8)
    end

    menu.rows = {}

    local catcher = CreateFrame("Frame", nil, UIParent)
    catcher:Hide()
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("DIALOG")
    catcher:SetFrameLevel(40)
    catcher:EnableMouse(true)
    catcher:SetScript("OnMouseDown", function()
        menu:Hide()
    end)
    menu._catcher = catcher

    menu:SetScript("OnShow", function()
        menu._catcher:Show()
    end)
    menu:SetScript("OnHide", function()
        menu._catcher:Hide()
        GameTooltip:Hide()
    end)

    return menu
end

local function ShowMenu(menu, anchor, entries, iconSize)
    if not menu or not anchor then return end
    if menu:IsShown() then
        menu:Hide()
        return
    end

    iconSize = iconSize or 16
    local rowHeight = math.max(20, iconSize + 4)
    local width = 220
    local padding = 8
    local yStart = -padding

    menu:ClearAllPoints()
    menu:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -2)

    for i = 1, #entries do
        local entry = entries[i]
        local row = menu.rows[i]
        if not row then
            row = CreateFrame("Button", nil, menu)
            row:EnableMouse(true)

            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
            row.bg:SetColorTexture(0, 0, 0, 0)

            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetPoint("LEFT", 6, 0)
            ApplyIconStyle(row.icon)

            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.text:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
            row.text:SetJustifyH("LEFT")

            row:SetScript("OnEnter", function(self)
                self.bg:SetColorTexture(0.15, 0.15, 0.18, 0.8)
            end)
            row:SetScript("OnLeave", function(self)
                self.bg:SetColorTexture(0, 0, 0, 0)
            end)

            row:SetScript("OnClick", function(self)
                local e = self.entry
                menu:Hide()
                if e and e.onClick then
                    e.onClick()
                end
            end)

            menu.rows[i] = row
        end

        row.entry = entry
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", padding, yStart - ((i - 1) * rowHeight))
        row:SetPoint("TOPRIGHT", -padding, yStart - ((i - 1) * rowHeight))
        row:SetHeight(rowHeight)

        row.icon:SetSize(iconSize, iconSize)
        row.icon:SetTexture(entry.icon)
        ApplyIconStyle(row.icon)
        row.text:SetText(entry.name or "(unknown)")
        row:Show()
    end

    for i = #entries + 1, #menu.rows do
        if menu.rows[i] then
            menu.rows[i]:Hide()
        end
    end

    local height = (padding * 2) + (#entries * rowHeight)
    menu:SetSize(width, height)
    menu:Show()
end

function LaunchersPlugin:ToggleMenu()
    if not self.button then return end

    if not self._menu then
        self._menu = CreateMenu()
    end

    local iconSize = tonumber(DCInfoBar:GetPluginSetting(self.id, "iconSize")) or 16
    local entries = BuildSettingsList()
    ShowMenu(self._menu, self.button, entries, iconSize)
end

function LaunchersPlugin:ToggleItemUpgradeMenu(anchorButton)
    if not anchorButton then return end

    if not self._itemUpgradeMenu then
        self._itemUpgradeMenu = CreateNamedMenu("DCInfoBarItemUpgradeMenu")
    end

    local entries = {
        {
            name = "Item Upgrade",
            icon = "Interface\\AddOns\\DC-ItemUpgrade\\Textures\\Icons\\ItemUpgrade_64.tga",
            onClick = function()
                OpenItemUpgrade("")
            end,
        },
        {
            name = "Heirloom Upgrade",
            icon = "Interface\\AddOns\\DC-ItemUpgrade\\Textures\\Icons\\Heirloom_64.tga",
            onClick = function()
                OpenItemUpgrade("heirloom")
            end,
        },
    }

    local iconSize = tonumber(DCInfoBar:GetPluginSetting(self.id, "iconSize")) or 16
    ShowMenu(self._itemUpgradeMenu, anchorButton, entries, iconSize)
end

function LaunchersPlugin:ToggleQoSMenu(anchorButton)
    if not anchorButton then return end

    if not self._qosMenu then
        self._qosMenu = CreateNamedMenu("DCInfoBarQoSMenu")
    end

    local entries = {
        {
            name = "QoS Settings",
            icon = "Interface\\AddOns\\DC-Welcome\\Textures\\Icons\\QOS_64.tga",
            onClick = function()
                RunSlashCommand("/dcqos")
            end,
        },
        {
            name = "CombatLog Window",
            icon = "Interface\\Icons\\Ability_DualWield",
            onClick = function()
                -- Uses /dccombat (DC-QoS CombatLog module). /dcc is reserved by DC-Collection.
                RunSlashCommand("/dccombat")
            end,
        },
        {
            name = "Talent Manager",
            icon = "Interface\\Icons\\Ability_Marksmanship",
            onClick = function()
                local qos = rawget(_G, "DCQOS")
                local tm = qos and qos.GetModule and qos:GetModule("TalentManager")
                if tm and tm.Toggle then
                    tm:Toggle()
                else
                    -- Fallback: open DC-QoS settings if module isn't available yet.
                    RunSlashCommand("/dcqos")
                end
            end,
        },
    }

    local iconSize = tonumber(DCInfoBar:GetPluginSetting(self.id, "iconSize")) or 16
    ShowMenu(self._qosMenu, anchorButton, entries, iconSize)
end

function LaunchersPlugin:OnClick(button)
    -- Icon buttons handle clicks.
end

-- Register plugin
DCInfoBar:RegisterPlugin(LaunchersPlugin)
