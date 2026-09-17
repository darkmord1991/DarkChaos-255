--[[
    DC-InfoBar Bar UI
    Main bar frame and plugin button management
]]

local addonName = "DC-InfoBar"
local DCInfoBar = DCInfoBar or {}

-- ============================================================================
-- Bar Configuration
-- ============================================================================

local BAR_HEIGHT = 22
local PLUGIN_PADDING = 6
local SEPARATOR_WIDTH = 1
local ICON_SIZE = 16
local RESTART_GAUGE_LEFT_INSET = 60
local RESTART_GAUGE_RIGHT_INSET = 40
local RESTART_GAUGE_MAX_WIDTH = 320

local function ApplyIconStyle(icon)
    if icon and icon.SetTexCoord then
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
end

local function GetBarHeight()
    local settings = DCInfoBar.db and DCInfoBar.db.bar
    return (settings and tonumber(settings.height)) or BAR_HEIGHT
end

local function ApplyBarAnchors(bar, position)
    bar:ClearAllPoints()
    bar.border:ClearAllPoints()
    if position == "bottom" then
        bar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
        bar:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
        bar.border:SetPoint("TOPLEFT", 0, 0)
        bar.border:SetPoint("TOPRIGHT", 0, 0)
    else
        bar:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
        bar:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0)
        bar.border:SetPoint("BOTTOMLEFT", 0, 0)
        bar.border:SetPoint("BOTTOMRIGHT", 0, 0)
    end
end

-- ============================================================================
-- Bar Creation
-- ============================================================================

function DCInfoBar:CreateBar()
    local bar = CreateFrame("Frame", "DCInfoBarFrame", UIParent)

    local barSettings = self.db and self.db.bar or {}
    local height = GetBarHeight()

    bar:SetHeight(height)
    bar:SetFrameStrata(barSettings.strata or "HIGH")
    bar:SetClampedToScreen(true)

    -- Background: some 3.3.5a clients don't apply alpha consistently via
    -- SetColorTexture, so set RGB there and alpha via SetAlpha.
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()

    -- Border line (on the side facing away from the screen edge)
    bar.border = bar:CreateTexture(nil, "ARTWORK")
    bar.border:SetHeight(1)

    bar.leftContainer = CreateFrame("Frame", nil, bar)
    bar.leftContainer:SetPoint("LEFT", bar, "LEFT", 4, 0)
    bar.leftContainer:SetHeight(height)
    bar.leftContainer:SetWidth(1)

    bar.rightContainer = CreateFrame("Frame", nil, bar)
    bar.rightContainer:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    bar.rightContainer:SetHeight(height)
    bar.rightContainer:SetWidth(1)

    -- Restart/Shutdown gauge (overlay in the free space between both sides)
    bar.restartGauge = CreateFrame("StatusBar", nil, bar)
    bar.restartGauge:SetHeight(height)
    bar.restartGauge:SetPoint("LEFT", bar.leftContainer, "RIGHT", RESTART_GAUGE_LEFT_INSET, 0)
    bar.restartGauge:SetWidth(220)
    bar.restartGauge:SetMinMaxValues(0, 1)
    bar.restartGauge:SetValue(0)
    bar.restartGauge:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
    bar.restartGauge:SetFrameLevel(bar:GetFrameLevel() + 2)

    bar.restartGauge.bg = bar.restartGauge:CreateTexture(nil, "BACKGROUND")
    bar.restartGauge.bg:SetAllPoints()
    bar.restartGauge.bg:SetColorTexture(0, 0, 0, 0.35)

    bar.restartGauge.text = bar.restartGauge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bar.restartGauge.text:SetPoint("CENTER", 0, 0)
    bar.restartGauge.text:SetText("")

    bar.restartGauge:EnableMouse(true)
    bar.restartGauge:SetScript("OnEnter", function(self)
        DCInfoBar:ShowRestartGaugeTooltip(self)
    end)
    bar.restartGauge:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    bar.restartGauge:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then
            DCInfoBar:CancelServerCountdown()
        end
    end)
    bar.restartGauge:Hide()

    bar.pluginButtons = {}

    bar.CreatePluginButton = function(_, plugin)
        return DCInfoBar:CreatePluginButton(bar, plugin)
    end
    bar.UpdatePluginText = function(_, plugin, label, value, color)
        DCInfoBar:UpdatePluginText(plugin, label, value, color)
    end
    bar.RefreshLayout = function()
        DCInfoBar:RefreshBarLayout(bar)
    end
    bar.RefreshSettings = function()
        DCInfoBar:RefreshBarSettings(bar)
    end

    self.bar = bar
    self:RefreshBarSettings(bar)
    return bar
end

-- ============================================================================
-- Plugin Buttons
-- ============================================================================

-- Icon visibility, text anchor, height and parent container. Safe to call any
-- time a setting changes; it forces the next text update to re-measure.
function DCInfoBar:ApplyPluginButtonStyle(plugin)
    local button = plugin and plugin.button
    if not button or not self.bar then
        return
    end

    local container = (plugin.side == "right") and self.bar.rightContainer or self.bar.leftContainer
    if button:GetParent() ~= container then
        button:SetParent(container)
    end

    button:SetHeight(GetBarHeight() - 4)

    local globalIcons = not (self.db and self.db.global and self.db.global.showIcons == false)
    local showIcon = plugin.icon and globalIcons and self:GetPluginSetting(plugin.id, "showIcon") ~= false

    button.text:ClearAllPoints()
    if showIcon then
        button.icon:SetTexture(plugin.icon)
        button.icon:Show()
        button.text:SetPoint("LEFT", button.icon, "RIGHT", 4, 0)
    else
        button.icon:Hide()
        button.text:SetPoint("LEFT", 6, 0)
    end
    button._showIcon = showIcon and true or false

    -- Invalidate caches so the next UpdatePluginText re-renders and re-measures.
    button._lastText = nil
    button._lastWidth = nil
end

function DCInfoBar:CreatePluginButton(bar, plugin)
    if not bar or not plugin then return end

    if plugin.button then
        self:ApplyPluginButtonStyle(plugin)
        plugin.button:Show()
        return plugin.button
    end

    local container = (plugin.side == "right") and bar.rightContainer or bar.leftContainer
    local button = CreateFrame("Button", plugin.id .. "Button", container)
    button.plugin = plugin

    -- Background (hover highlight)
    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetAllPoints()
    button.bg:SetColorTexture(0.1, 0.1, 0.12, 0)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(ICON_SIZE, ICON_SIZE)
    button.icon:SetPoint("LEFT", 4, 0)
    ApplyIconStyle(button.icon)

    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.text:SetJustifyH("LEFT")

    button.separator = button:CreateTexture(nil, "ARTWORK")
    button.separator:SetSize(SEPARATOR_WIDTH, ICON_SIZE)
    button.separator:SetPoint("RIGHT", 0, 0)
    button.separator:SetColorTexture(0.2, 0.2, 0.25, 0.5)

    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")

    button:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(0.15, 0.15, 0.18, 0.8)
        DCInfoBar:ShowPluginTooltip(self.plugin)
    end)
    button:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(0.1, 0.1, 0.12, 0)
        GameTooltip:Hide()
    end)
    button:SetScript("OnClick", function(self, btn)
        if self.plugin.OnClick then
            self.plugin:OnClick(btn)
        end
    end)

    -- A plugin hiding/showing its own button (Events: hideWhenNone) must reflow the bar.
    -- (Skipped while the whole bar is hidden: children get OnShow/OnHide then too.)
    local function Reflow()
        local b = DCInfoBar.bar
        if b and b:IsShown() then
            DCInfoBar:RefreshBarLayout(b)
        end
    end
    button:SetScript("OnShow", Reflow)
    button:SetScript("OnHide", Reflow)

    plugin.button = button
    bar.pluginButtons[plugin.id] = button
    button:SetWidth(50)  -- resized on first text update

    self:ApplyPluginButtonStyle(plugin)
    return button
end

-- ============================================================================
-- Plugin Text Update
-- ============================================================================

function DCInfoBar:UpdatePluginText(plugin, label, value, color)
    if not plugin or not plugin.button then return end

    local button = plugin.button
    local globalLabels = not (self.db and self.db.global and self.db.global.showLabels == false)

    local text = ""
    if label and label ~= "" and globalLabels and self:GetPluginSetting(plugin.id, "showLabel") ~= false then
        text = "|cff888888" .. label .. "|r "
    end
    if value then
        local hex = color and (self.Colors[color] or color) or "ffffff"
        text = text .. "|cff" .. hex .. value .. "|r"
    end

    -- Most plugins return identical text most ticks: skip SetText, measuring
    -- and the full-bar layout pass when nothing changed.
    if text == button._lastText then
        return
    end
    button._lastText = text
    button.text:SetText(text)

    local width = button.text:GetStringWidth() + PLUGIN_PADDING * 2 + SEPARATOR_WIDTH
    if button._showIcon then
        width = width + ICON_SIZE + 4
    end
    width = math.max(math.floor(width + 0.5), 30)

    if width ~= button._lastWidth then
        button._lastWidth = width
        button:SetWidth(width)
        self:RefreshBarLayout(self.bar)
    end
end

-- ============================================================================
-- Bar Layout
-- ============================================================================

function DCInfoBar:RefreshBarLayout(bar)
    if not bar or self._inBarLayout then return end
    self._inBarLayout = true

    local leftOffset = 0
    for _, plugin in ipairs(self.activePlugins.left) do
        local button = plugin.button
        if button and button:IsShown() then
            button:ClearAllPoints()
            button:SetPoint("LEFT", bar.leftContainer, "LEFT", leftOffset, 0)
            button.separator:Show()
            leftOffset = leftOffset + button:GetWidth()
        end
    end
    bar.leftContainer:SetWidth(math.max(leftOffset, 1))

    -- Right side is laid out right-to-left; the first shown button is the
    -- rightmost one and gets no separator.
    local rightOffset = 0
    local rightmost = true
    for i = #self.activePlugins.right, 1, -1 do
        local button = self.activePlugins.right[i].button
        if button and button:IsShown() then
            button:ClearAllPoints()
            button:SetPoint("RIGHT", bar.rightContainer, "RIGHT", -rightOffset, 0)
            if rightmost then
                button.separator:Hide()
                rightmost = false
            else
                button.separator:Show()
            end
            rightOffset = rightOffset + button:GetWidth()
        end
    end
    bar.rightContainer:SetWidth(math.max(rightOffset, 1))

    -- Fit restart gauge into the center free space
    if bar.restartGauge then
        local totalWidth = bar:GetWidth() or 0
        if totalWidth <= 0 then
            totalWidth = UIParent:GetWidth() or 0
        end
        if totalWidth > 0 then
            local available = totalWidth - leftOffset - rightOffset - RESTART_GAUGE_LEFT_INSET - RESTART_GAUGE_RIGHT_INSET
            bar.restartGauge:SetWidth(math.min(RESTART_GAUGE_MAX_WIDTH, math.max(0, math.floor(available))))
        end
    end

    self._inBarLayout = false
end

-- ============================================================================
-- Bar Settings Refresh
-- ============================================================================

function DCInfoBar:RefreshBarSettings(bar)
    if not bar or not self.db then return end

    local barSettings = self.db.bar
    local height = GetBarHeight()
    local bgColor = barSettings.backgroundColor or { 0.04, 0.04, 0.05, 0.85 }
    local borderColor = barSettings.borderColor or { 0.2, 0.5, 0.8, 0.5 }

    bar:SetHeight(height)
    bar:SetFrameStrata(barSettings.strata or "HIGH")
    bar.leftContainer:SetHeight(height)
    bar.rightContainer:SetHeight(height)
    bar.restartGauge:SetHeight(height)

    bar.bg:SetColorTexture(bgColor[1] or 0, bgColor[2] or 0, bgColor[3] or 0, 1)
    bar.bg:SetAlpha(bgColor[4] or 1)
    if barSettings.showBackground ~= false then
        bar.bg:Show()
    else
        bar.bg:Hide()
    end

    bar.border:SetColorTexture(borderColor[1] or 0, borderColor[2] or 0, borderColor[3] or 0, borderColor[4] or 1)
    ApplyBarAnchors(bar, barSettings.position)

    for _, plugin in pairs(self.plugins) do
        if plugin.button then
            self:ApplyPluginButtonStyle(plugin)
        end
    end

    self:UpdateVisibility(true)
    self:RefreshBarLayout(bar)
end

-- ============================================================================
-- Tooltip System
-- ============================================================================

function DCInfoBar:ShowPluginTooltip(plugin)
    if not plugin or not plugin.button then return end

    local anchor = (self.db and self.db.bar and self.db.bar.position == "bottom") and "ANCHOR_TOP" or "ANCHOR_BOTTOMRIGHT"
    GameTooltip:SetOwner(plugin.button, anchor)

    GameTooltip:AddLine(plugin.name or plugin.id, 1, 1, 1)
    GameTooltip:AddLine(" ")

    if plugin.OnTooltip then
        local ok, err = pcall(plugin.OnTooltip, plugin, GameTooltip)
        if not ok then
            self:Debug("Tooltip error in " .. tostring(plugin.id) .. ": " .. tostring(err))
        end
    end

    if plugin.leftClickHint or plugin.rightClickHint or plugin.middleClickHint then
        GameTooltip:AddLine(" ")
        if plugin.leftClickHint then
            GameTooltip:AddLine("|cff00ff00Left-Click:|r " .. plugin.leftClickHint, 1, 1, 1)
        end
        if plugin.rightClickHint then
            GameTooltip:AddLine("|cff00ff00Right-Click:|r " .. plugin.rightClickHint, 1, 1, 1)
        end
        if plugin.middleClickHint then
            GameTooltip:AddLine("|cff00ff00Middle-Click:|r " .. plugin.middleClickHint, 1, 1, 1)
        end
    end

    GameTooltip:Show()
end
