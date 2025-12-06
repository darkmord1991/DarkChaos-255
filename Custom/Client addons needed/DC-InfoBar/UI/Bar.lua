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

-- ============================================================================
-- Bar Creation
-- ============================================================================

function DCInfoBar:CreateBar()
    local bar = CreateFrame("Frame", "DCInfoBarFrame", UIParent)
    
    -- Get settings
    local barSettings = self.db and self.db.bar or {}
    local position = barSettings.position or "top"
    local height = barSettings.height or BAR_HEIGHT
    local bgColor = barSettings.backgroundColor or { 0.04, 0.04, 0.05, 0.85 }
    local borderColor = barSettings.borderColor or { 0.2, 0.5, 0.8, 0.5 }
    
    bar:SetHeight(height)
    bar:SetFrameStrata(barSettings.strata or "HIGH")
    bar:SetClampedToScreen(true)
    
    -- Position based on settings
    if position == "top" then
        bar:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
        bar:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0)
    else
        bar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
        bar:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
    end
    
    -- Background
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.bg:SetColorTexture(unpack(bgColor))
    
    -- Border line (on opposite side of screen edge)
    bar.border = bar:CreateTexture(nil, "ARTWORK")
    if position == "top" then
        bar.border:SetPoint("BOTTOMLEFT", 0, 0)
        bar.border:SetPoint("BOTTOMRIGHT", 0, 0)
    else
        bar.border:SetPoint("TOPLEFT", 0, 0)
        bar.border:SetPoint("TOPRIGHT", 0, 0)
    end
    bar.border:SetHeight(1)
    bar.border:SetColorTexture(unpack(borderColor))
    
    -- Left container (for left-side plugins)
    bar.leftContainer = CreateFrame("Frame", nil, bar)
    bar.leftContainer:SetPoint("LEFT", bar, "LEFT", 4, 0)
    bar.leftContainer:SetHeight(height)
    bar.leftContainer:SetWidth(1)  -- Will grow as plugins added
    
    -- Right container (for right-side plugins)
    bar.rightContainer = CreateFrame("Frame", nil, bar)
    bar.rightContainer:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    bar.rightContainer:SetHeight(height)
    bar.rightContainer:SetWidth(1)  -- Will grow as plugins added
    
    -- Store reference
    bar.pluginButtons = {}
    
    -- Add methods
    bar.CreatePluginButton = function(self, plugin)
        DCInfoBar:CreatePluginButton(self, plugin)
    end
    bar.UpdatePluginText = function(self, plugin, label, value, color)
        DCInfoBar:UpdatePluginText(plugin, label, value, color)
    end
    bar.RefreshLayout = function(self)
        DCInfoBar:RefreshBarLayout(self)
    end
    bar.RefreshSettings = function(self)
        DCInfoBar:RefreshBarSettings(self)
    end
    
    self.bar = bar
    return bar
end

-- ============================================================================
-- Plugin Button Creation
-- ============================================================================

function DCInfoBar:CreatePluginButton(bar, plugin)
    if not bar or not plugin then return end
    
    -- Check if button already exists
    if plugin.button then
        plugin.button:Show()
        return
    end
    
    local side = plugin.side or "left"
    local container = (side == "left") and bar.leftContainer or bar.rightContainer
    
    local button = CreateFrame("Button", plugin.id .. "Button", container)
    button:SetHeight(BAR_HEIGHT - 4)
    button.plugin = plugin
    
    -- Background (hover highlight)
    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetAllPoints()
    button.bg:SetColorTexture(0.1, 0.1, 0.12, 0)
    
    -- Icon (if enabled)
    local showIcon = self:GetPluginSetting(plugin.id, "showIcon")
    if showIcon ~= false and plugin.icon then
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetSize(ICON_SIZE, ICON_SIZE)
        button.icon:SetPoint("LEFT", 4, 0)
        button.icon:SetTexture(plugin.icon)
    end
    
    -- Text
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    if button.icon then
        button.text:SetPoint("LEFT", button.icon, "RIGHT", 4, 0)
    else
        button.text:SetPoint("LEFT", 6, 0)
    end
    button.text:SetJustifyH("LEFT")
    
    -- Separator line
    button.separator = button:CreateTexture(nil, "ARTWORK")
    button.separator:SetSize(SEPARATOR_WIDTH, ICON_SIZE)
    button.separator:SetPoint("RIGHT", 0, 0)
    button.separator:SetColorTexture(0.2, 0.2, 0.25, 0.5)
    
    -- Event handlers
    button:EnableMouse(true)
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
    
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    
    plugin.button = button
    bar.pluginButtons[plugin.id] = button
    
    -- Set initial width
    button:SetWidth(50)  -- Will be resized on first update
    
    return button
end

-- ============================================================================
-- Plugin Text Update
-- ============================================================================

function DCInfoBar:UpdatePluginText(plugin, label, value, color)
    if not plugin or not plugin.button then return end
    
    local button = plugin.button
    local showLabel = self:GetPluginSetting(plugin.id, "showLabel")
    
    local text = ""
    
    -- Add label if enabled
    if label and showLabel ~= false then
        text = "|cff888888" .. label .. "|r "
    end
    
    -- Add value with optional color
    if value then
        if color then
            local hex = self.Colors[color] or color
            text = text .. "|cff" .. hex .. value .. "|r"
        else
            text = text .. "|cffffffff" .. value .. "|r"
        end
    end
    
    button.text:SetText(text)
    
    -- Auto-size button based on content
    local textWidth = button.text:GetStringWidth()
    local width = textWidth + PLUGIN_PADDING * 2 + SEPARATOR_WIDTH
    if button.icon then
        width = width + ICON_SIZE + 4
    end
    
    button:SetWidth(math.max(width, 30))
    
    -- Refresh layout after resize
    self:RefreshBarLayout(self.bar)
end

-- ============================================================================
-- Bar Layout
-- ============================================================================

function DCInfoBar:RefreshBarLayout(bar)
    if not bar then return end
    
    -- Layout left-side plugins
    local leftOffset = 0
    for _, plugin in ipairs(self.activePlugins.left) do
        if plugin.button and plugin.button:IsShown() then
            plugin.button:ClearAllPoints()
            plugin.button:SetPoint("LEFT", bar.leftContainer, "LEFT", leftOffset, 0)
            leftOffset = leftOffset + plugin.button:GetWidth()
        end
    end
    bar.leftContainer:SetWidth(leftOffset)
    
    -- Layout right-side plugins (right to left)
    local rightOffset = 0
    for i = #self.activePlugins.right, 1, -1 do
        local plugin = self.activePlugins.right[i]
        if plugin.button and plugin.button:IsShown() then
            plugin.button:ClearAllPoints()
            plugin.button:SetPoint("RIGHT", bar.rightContainer, "RIGHT", -rightOffset, 0)
            rightOffset = rightOffset + plugin.button:GetWidth()
            
            -- Hide separator on rightmost plugin
            if i == #self.activePlugins.right then
                plugin.button.separator:Hide()
            else
                plugin.button.separator:Show()
            end
        end
    end
    bar.rightContainer:SetWidth(rightOffset)
end

-- ============================================================================
-- Bar Settings Refresh
-- ============================================================================

function DCInfoBar:RefreshBarSettings(bar)
    if not bar or not self.db then return end
    
    local barSettings = self.db.bar
    local position = barSettings.position or "top"
    local bgColor = barSettings.backgroundColor or { 0.04, 0.04, 0.05, 0.85 }
    local borderColor = barSettings.borderColor or { 0.2, 0.5, 0.8, 0.5 }
    
    -- Update background
    bar.bg:SetColorTexture(unpack(bgColor))
    
    -- Update border
    bar.border:SetColorTexture(unpack(borderColor))
    
    -- Reposition if needed
    bar:ClearAllPoints()
    if position == "top" then
        bar:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
        bar:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0)
        bar.border:ClearAllPoints()
        bar.border:SetPoint("BOTTOMLEFT", 0, 0)
        bar.border:SetPoint("BOTTOMRIGHT", 0, 0)
    else
        bar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
        bar:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
        bar.border:ClearAllPoints()
        bar.border:SetPoint("TOPLEFT", 0, 0)
        bar.border:SetPoint("TOPRIGHT", 0, 0)
    end
    
    -- Update visibility
    bar:SetShown(self.db.global.enabled)
    
    -- Refresh layout
    self:RefreshBarLayout(bar)
end

-- ============================================================================
-- Tooltip System
-- ============================================================================

function DCInfoBar:ShowPluginTooltip(plugin)
    if not plugin then return end
    
    GameTooltip:SetOwner(plugin.button, "ANCHOR_BOTTOMRIGHT")
    
    -- Title
    GameTooltip:AddLine(plugin.name or plugin.id, 1, 1, 1)
    GameTooltip:AddLine(" ")
    
    -- Plugin-specific tooltip
    if plugin.OnTooltip then
        plugin:OnTooltip(GameTooltip)
    end
    
    -- Click hints
    if plugin.OnClick then
        GameTooltip:AddLine(" ")
        if plugin.leftClickHint then
            GameTooltip:AddLine("|cff00ff00Left-Click:|r " .. plugin.leftClickHint, 1, 1, 1)
        end
        if plugin.rightClickHint then
            GameTooltip:AddLine("|cff00ff00Right-Click:|r " .. plugin.rightClickHint, 1, 1, 1)
        end
    end
    
    GameTooltip:Show()
end
