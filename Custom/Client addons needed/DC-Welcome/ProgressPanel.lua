--[[
    DC-Welcome ProgressPanel.lua
    Unified progress view for M+ rating, Prestige, Season rank
    
    Features:
    - Stat boxes for key progression metrics
    - Progress bars for current goals
    - Integration with DC-MythicPlus, Prestige, Seasons
    - Auto-refresh from server and loaded addons
    
    Author: DarkChaos-255
    Date: December 2025
]]

local addonName = "DC-Welcome"
DCWelcome = DCWelcome or {}
local L = DCWelcome.L

-- =============================================================================
-- Constants
-- =============================================================================

local PANEL_PADDING = 15
local STAT_BOX_WIDTH = 130
local STAT_BOX_HEIGHT = 70
local BAR_WIDTH = 280
local BAR_HEIGHT = 16

-- =============================================================================
-- C_Timer Polyfill reference
-- =============================================================================

local C_Timer_After = DCWelcome.After or function(delay, callback)
    local frame = CreateFrame("Frame")
    frame.elapsed = 0
    frame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed >= delay then
            self:SetScript("OnUpdate", nil)
            callback()
        end
    end)
end

-- =============================================================================
-- Utility
-- =============================================================================

local function CreateTexture(parent, r, g, b, a)
    local tex = parent:CreateTexture(nil, "BACKGROUND")
    tex:SetAllPoints()
    tex:SetTexture(r, g, b, a or 1)
    return tex
end

-- =============================================================================
-- Stat Box Creation
-- =============================================================================

local function CreateStatBox(parent, data)
    local box = CreateFrame("Frame", nil, parent)
    box:SetSize(STAT_BOX_WIDTH, STAT_BOX_HEIGHT)
    
    -- Background
    local bg = CreateTexture(box, 0.08, 0.1, 0.08, 0.95)
    box.bg = bg
    
    -- Accent border (top)
    local accent = box:CreateTexture(nil, "BORDER")
    accent:SetPoint("TOPLEFT", 0, 0)
    accent:SetPoint("TOPRIGHT", 0, 0)
    accent:SetHeight(3)
    accent:SetTexture(data.color.r or 0.2, data.color.g or 0.8, data.color.b or 0.2, 1)
    box.accent = accent
    
    -- Icon
    local icon = box:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOP", 0, -10)
    icon:SetSize(24, 24)
    icon:SetTexture(data.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    box.icon = icon
    
    -- Value
    local valueText = box:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    valueText:SetPoint("TOP", icon, "BOTTOM", 0, -3)
    valueText:SetText("|cff00ff00" .. tostring(data.value or "---") .. "|r")
    box.valueText = valueText
    
    -- Label
    local labelText = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    labelText:SetPoint("TOP", valueText, "BOTTOM", 0, -2)
    labelText:SetText(data.label or "")
    box.labelText = labelText
    
    -- Update function
    function box:SetValue(newValue)
        self.valueText:SetText("|cff00ff00" .. tostring(newValue or "---") .. "|r")
    end
    
    function box:SetColor(r, g, b)
        self.accent:SetTexture(r, g, b, 1)
    end
    
    return box
end

-- =============================================================================
-- Progress Bar Creation
-- =============================================================================

local function CreateProgressBar(parent, data)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(data.width or BAR_WIDTH, 40)
    
    -- Label
    local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", 0, 0)
    label:SetText(data.label or "Progress")
    container.label = label
    
    -- Value text (right side)
    local valueText = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    valueText:SetPoint("TOPRIGHT", 0, 0)
    valueText:SetText(tostring(data.current or 0) .. " / " .. tostring(data.max or 100))
    container.valueText = valueText
    
    -- Bar background
    local barBg = container:CreateTexture(nil, "BACKGROUND")
    barBg:SetPoint("TOPLEFT", 0, -16)
    barBg:SetSize(data.width or BAR_WIDTH, BAR_HEIGHT)
    barBg:SetTexture(0.1, 0.1, 0.1, 0.9)
    container.barBg = barBg
    
    -- Bar fill
    local barFill = container:CreateTexture(nil, "ARTWORK")
    barFill:SetPoint("TOPLEFT", barBg, "TOPLEFT", 1, -1)
    barFill:SetHeight(BAR_HEIGHT - 2)
    
    local pct = (data.max or 100) > 0 and ((data.current or 0) / (data.max or 100)) or 0
    barFill:SetWidth(math.max(1, ((data.width or BAR_WIDTH) - 2) * pct))
    barFill:SetTexture(data.color.r or 0.2, data.color.g or 0.8, data.color.b or 0.2, 1)
    container.barFill = barFill
    
    -- Percentage overlay
    local pctText = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pctText:SetPoint("CENTER", barBg, "CENTER")
    pctText:SetText(string.format("%.0f%%", pct * 100))
    container.pctText = pctText
    
    -- Update function
    function container:SetProgress(current, max)
        max = max or 100
        current = current or 0
        local pct = max > 0 and (current / max) or 0
        
        self.valueText:SetText(tostring(current) .. " / " .. tostring(max))
        self.barFill:SetWidth(math.max(1, (self.barBg:GetWidth() - 2) * pct))
        self.pctText:SetText(string.format("%.0f%%", pct * 100))
    end
    
    function container:SetColor(r, g, b)
        self.barFill:SetTexture(r, g, b, 1)
    end
    
    return container
end

-- =============================================================================
-- Progress Panel Population
-- =============================================================================

function DCWelcome:PopulateProgressPanel(scrollChild)
    local yOffset = -10
    local L = self.L or {}
    
    -- Header
    local header = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOP", 0, yOffset)
    header:SetText("|cffffd700Your Progress|r")
    yOffset = yOffset - 25
    
    -- Subtitle
    local subtitle = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOP", 0, yOffset)
    subtitle:SetText("|cff888888Track your progression across all DarkChaos systems|r")
    yOffset = yOffset - 30
    
    -- Player info
    local playerName = UnitName("player")
    local _, classFile = UnitClass("player")
    local classColor = RAID_CLASS_COLORS[classFile] or { r = 1, g = 1, b = 1 }
    local playerLevel = UnitLevel("player")
    
    local playerText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    playerText:SetPoint("TOPLEFT", 20, yOffset)
    playerText:SetText(string.format("|cff%02x%02x%02x%s|r - Level %d", 
        classColor.r * 255, classColor.g * 255, classColor.b * 255,
        playerName, playerLevel))
    yOffset = yOffset - 35
    
    -- ==========================================================================
    -- Stat Boxes Row 1 (M+ Rating, Prestige, Season Rank, Achievements)
    -- ==========================================================================
    
    local statBoxes = {}
    local xStart = 20
    local boxSpacing = STAT_BOX_WIDTH + 15
    
    -- M+ Rating
    statBoxes.mythicRating = CreateStatBox(scrollChild, {
        label = "M+ Rating",
        value = "---",
        icon = "Interface\\Icons\\Achievement_challengemode_gold",
        color = { r = 1, g = 0.5, b = 0 }
    })
    statBoxes.mythicRating:SetPoint("TOPLEFT", xStart, yOffset)
    
    -- Prestige Level
    statBoxes.prestige = CreateStatBox(scrollChild, {
        label = "Prestige",
        value = "---",
        icon = "Interface\\Icons\\Achievement_level_80",
        color = { r = 0.64, g = 0.21, b = 0.93 }
    })
    statBoxes.prestige:SetPoint("TOPLEFT", xStart + boxSpacing, yOffset)
    
    -- Season Rank
    statBoxes.seasonRank = CreateStatBox(scrollChild, {
        label = "Season Rank",
        value = "---",
        icon = "Interface\\Icons\\Achievement_arena_2v2_7",
        color = { r = 0, g = 0.8, b = 1 }
    })
    statBoxes.seasonRank:SetPoint("TOPLEFT", xStart + boxSpacing * 2, yOffset)
    
    -- Achievement Points
    statBoxes.achievements = CreateStatBox(scrollChild, {
        label = "Achievements",
        value = GetTotalAchievementPoints and GetTotalAchievementPoints() or "---",
        icon = "Interface\\Icons\\Achievement_guildperk_workingovertime",
        color = { r = 1, g = 0.84, b = 0 }
    })
    statBoxes.achievements:SetPoint("TOPLEFT", xStart + boxSpacing * 3, yOffset)
    
    yOffset = yOffset - STAT_BOX_HEIGHT - 10
    
    -- ==========================================================================
    -- Stat Boxes Row 2 (Alt Bonus Level - centered)
    -- ==========================================================================
    
    -- Alt Bonus Level (XP bonus from max-level alts)
    statBoxes.altBonus = CreateStatBox(scrollChild, {
        label = "Alt Bonus",
        value = "---",
        icon = "Interface\\Icons\\Spell_Holy_BlessingOfStrength",
        color = { r = 0.2, g = 0.8, b = 0.4 }
    })
    -- Center the alt bonus box
    statBoxes.altBonus:SetPoint("TOPLEFT", xStart + boxSpacing * 1.5, yOffset)
    
    -- Add tooltip for alt bonus
    statBoxes.altBonus:EnableMouse(true)
    statBoxes.altBonus:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("|cffffd700Prestige Alt Bonus|r", 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Earn +5% XP bonus for each max-level", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("character on your account (max 25%).", 0.8, 0.8, 0.8)
        GameTooltip:AddLine(" ")
        local altLevel = DCWelcome.ProgressCache and DCWelcome.ProgressCache.altBonusLevel or 0
        local altPercent = DCWelcome.ProgressCache and DCWelcome.ProgressCache.altBonusPercent or 0
        GameTooltip:AddDoubleLine("Max-Level Alts:", tostring(altLevel) .. " / 5", 1, 1, 1, 0.2, 0.8, 0.4)
        GameTooltip:AddDoubleLine("Current Bonus:", "+" .. tostring(altPercent) .. "% XP", 1, 1, 1, 0.2, 0.8, 0.4)
        GameTooltip:Show()
    end)
    statBoxes.altBonus:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    scrollChild.statBoxes = statBoxes
    yOffset = yOffset - STAT_BOX_HEIGHT - 20
    
    -- ==========================================================================
    -- Divider
    -- ==========================================================================
    
    local divider = scrollChild:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", 20, yOffset)
    divider:SetSize(540, 1)
    divider:SetTexture(0.3, 0.3, 0.3, 0.8)
    yOffset = yOffset - 20
    
    -- ==========================================================================
    -- Progress Bars Section
    -- ==========================================================================
    
    local barsHeader = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    barsHeader:SetPoint("TOPLEFT", 20, yOffset)
    barsHeader:SetText("|cff88ff88Current Season Progress|r")
    yOffset = yOffset - 30
    
    local progressBars = {}
    
    -- Weekly Vault Progress
    progressBars.vault = CreateProgressBar(scrollChild, {
        label = "Weekly Vault",
        current = 0,
        max = 3,
        width = 260,
        color = { r = 0.8, g = 0.6, b = 0.2 }
    })
    progressBars.vault:SetPoint("TOPLEFT", 20, yOffset)
    
    -- Season Points
    progressBars.seasonPoints = CreateProgressBar(scrollChild, {
        label = "Season Points",
        current = 0,
        max = 1000,
        width = 260,
        color = { r = 0, g = 0.7, b = 0.9 }
    })
    progressBars.seasonPoints:SetPoint("TOPLEFT", 300, yOffset)
    
    yOffset = yOffset - 55
    
    -- Prestige XP
    progressBars.prestigeXP = CreateProgressBar(scrollChild, {
        label = "Prestige XP",
        current = 0,
        max = 100,
        width = 260,
        color = { r = 0.7, g = 0.3, b = 0.9 }
    })
    progressBars.prestigeXP:SetPoint("TOPLEFT", 20, yOffset)
    
    -- M+ Keys Completed This Week
    progressBars.keysWeek = CreateProgressBar(scrollChild, {
        label = "M+ Keys This Week",
        current = 0,
        max = 10,
        width = 260,
        color = { r = 1, g = 0.5, b = 0 }
    })
    progressBars.keysWeek:SetPoint("TOPLEFT", 300, yOffset)
    
    scrollChild.progressBars = progressBars
    yOffset = yOffset - 70
    
    -- ==========================================================================
    -- Info Text
    -- ==========================================================================
    
    local infoText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    infoText:SetPoint("TOPLEFT", 20, yOffset)
    infoText:SetWidth(540)
    infoText:SetJustifyH("LEFT")
    infoText:SetText("|cff888888Progress data syncs from server and loaded addons. Values showing '---' are loading or unavailable.|r")
    yOffset = yOffset - 40
    
    -- ==========================================================================
    -- Refresh Button
    -- ==========================================================================
    
    local refreshBtn = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
    refreshBtn:SetSize(100, 25)
    refreshBtn:SetPoint("TOPLEFT", 20, yOffset)
    refreshBtn:SetText("Refresh")
    refreshBtn:SetScript("OnClick", function()
        DCWelcome:RequestProgressData()  -- Request from server (includes alt bonus)
        scrollChild:Refresh()
        
        if DCWelcomeDB and DCWelcomeDB.enableSounds then
            PlaySound("igMainMenuOptionCheckBoxOn")
        end
    end)
    
    yOffset = yOffset - 40
    
    -- Set scroll child height
    scrollChild:SetHeight(math.abs(yOffset) + 20)
    
    -- ==========================================================================
    -- Refresh Function
    -- ==========================================================================
    
    function scrollChild:Refresh()
        local progress = DCWelcome:GetProgress()
        
        -- Update stat boxes
        if self.statBoxes then
            if progress.mythicRating then
                self.statBoxes.mythicRating:SetValue(progress.mythicRating)
            end
            if progress.prestigeLevel then
                self.statBoxes.prestige:SetValue(progress.prestigeLevel)
            end
            if progress.seasonRank then
                self.statBoxes.seasonRank:SetValue(progress.seasonRank)
            end
            if progress.achievementPoints then
                self.statBoxes.achievements:SetValue(progress.achievementPoints)
            end
            
            -- Alt Bonus Level - show as "Level X (+Y%)"
            if progress.altBonusLevel ~= nil then
                local altLevel = progress.altBonusLevel or 0
                local altPercent = progress.altBonusPercent or (altLevel * 5)
                if altLevel > 0 then
                    self.statBoxes.altBonus:SetValue(string.format("%d |cff88ff88(+%d%%)|r", altLevel, altPercent))
                else
                    self.statBoxes.altBonus:SetValue("|cff8888880|r")
                end
            end
        end
        
        -- Update progress bars
        if self.progressBars then
            if progress.weeklyVaultProgress ~= nil then
                self.progressBars.vault:SetProgress(progress.weeklyVaultProgress, 3)
            end
            if progress.seasonPoints ~= nil then
                -- Season points max defaults to 1000 but can be overridden
                local maxPoints = progress.seasonPointsMax or 1000
                self.progressBars.seasonPoints:SetProgress(progress.seasonPoints, maxPoints)
            end
            if progress.prestigeXP ~= nil then
                -- Prestige XP max defaults to 100 but can be overridden from server
                local maxXP = progress.prestigeXPMax or 100
                self.progressBars.prestigeXP:SetProgress(progress.prestigeXP, maxXP)
            end
            if progress.keysThisWeek ~= nil then
                self.progressBars.keysWeek:SetProgress(progress.keysThisWeek, 10)
            end
        end
    end
    
    -- Initial refresh - request data from server
    C_Timer_After(0.5, function()
        DCWelcome:RequestProgressData()  -- Request from server (includes alt bonus)
        scrollChild:Refresh()
    end)
    
    -- Subscribe to progress updates
    DCWelcome.EventBus:On("PROGRESS_UPDATED", function(progress)
        scrollChild:Refresh()
    end)
end
