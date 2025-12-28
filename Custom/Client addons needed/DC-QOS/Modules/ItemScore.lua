-- ============================================================
-- DC-QoS: ItemScore Module (Pawn-style)
-- ============================================================
-- Shows upgrade arrows and item scores in tooltips
-- Integrates with DC-ItemUpgrade for tier information
-- ============================================================

local addon = DCQOS

-- ============================================================
-- Module Configuration
-- ============================================================
local ItemScore = {
    displayName = "Item Score",
    settingKey = "itemScore",
    icon = "Interface\\Icons\\INV_Misc_Gem_Variety_02",
}

-- ============================================================
-- Default Settings
-- ============================================================
local defaults = {
    itemScore = {
        enabled = true,
        showUpgradeArrows = true,
        showScore = true,
        showStatWeights = false,
        showComparison = true,
        arrowColor = { r = 0.0, g = 1.0, b = 0.0 },
        downgradeColor = { r = 1.0, g = 0.0, b = 0.0 },
        sideGradeColor = { r = 1.0, g = 1.0, b = 0.0 },
    },
}

-- Merge defaults
for k, v in pairs(defaults) do
    addon.defaults[k] = v
end

-- ============================================================
-- Stat Weights by Class/Spec
-- ============================================================
-- These are baseline weights; server can override per-character
local StatWeights = {
    -- Weights per class (1 = worst, 3 = best for primary stat)
    WARRIOR = {
        STRENGTH = 2.5,
        AGILITY = 1.0,
        STAMINA = 1.5,
        INTELLECT = 0.0,
        SPIRIT = 0.0,
        ATTACKPOWER = 1.0,
        CRIT = 1.8,
        HIT = 2.0,
        EXPERTISE = 2.0,
        HASTE = 1.2,
        ARMOR_PENETRATION = 1.5,
        RESILIENCE = 0.5,
        DEFENSE = 1.0,
        DODGE = 1.0,
        PARRY = 1.0,
        BLOCK = 0.8,
    },
    PALADIN = {
        STRENGTH = 2.5,
        AGILITY = 0.5,
        STAMINA = 1.5,
        INTELLECT = 1.5,
        SPIRIT = 0.5,
        ATTACKPOWER = 1.0,
        SPELLPOWER = 1.5,
        CRIT = 1.5,
        HIT = 2.0,
        HASTE = 1.2,
        MANA_PER_5 = 1.0,
        DEFENSE = 1.0,
        DODGE = 1.0,
        PARRY = 1.0,
        BLOCK = 0.8,
    },
    HUNTER = {
        STRENGTH = 0.5,
        AGILITY = 2.5,
        STAMINA = 1.0,
        INTELLECT = 0.5,
        SPIRIT = 0.0,
        ATTACKPOWER = 1.0,
        RANGED_ATTACKPOWER = 1.2,
        CRIT = 2.0,
        HIT = 2.5,
        HASTE = 1.5,
        ARMOR_PENETRATION = 1.8,
    },
    ROGUE = {
        STRENGTH = 0.5,
        AGILITY = 2.5,
        STAMINA = 1.0,
        INTELLECT = 0.0,
        SPIRIT = 0.0,
        ATTACKPOWER = 1.0,
        CRIT = 2.0,
        HIT = 2.5,
        EXPERTISE = 2.0,
        HASTE = 1.5,
        ARMOR_PENETRATION = 2.0,
    },
    PRIEST = {
        STRENGTH = 0.0,
        AGILITY = 0.0,
        STAMINA = 0.8,
        INTELLECT = 2.5,
        SPIRIT = 2.0,
        SPELLPOWER = 1.5,
        CRIT = 1.5,
        HIT = 1.8,
        HASTE = 2.0,
        MANA_PER_5 = 1.2,
    },
    DEATHKNIGHT = {
        STRENGTH = 2.5,
        AGILITY = 0.5,
        STAMINA = 1.5,
        INTELLECT = 0.0,
        SPIRIT = 0.0,
        ATTACKPOWER = 1.0,
        CRIT = 1.5,
        HIT = 2.0,
        EXPERTISE = 2.0,
        HASTE = 1.2,
        ARMOR_PENETRATION = 1.5,
        DEFENSE = 1.0,
        DODGE = 1.0,
        PARRY = 1.0,
    },
    SHAMAN = {
        STRENGTH = 0.5,
        AGILITY = 2.0,
        STAMINA = 1.0,
        INTELLECT = 2.5,
        SPIRIT = 1.0,
        ATTACKPOWER = 1.0,
        SPELLPOWER = 1.5,
        CRIT = 1.8,
        HIT = 2.0,
        HASTE = 1.5,
        MANA_PER_5 = 1.2,
    },
    MAGE = {
        STRENGTH = 0.0,
        AGILITY = 0.0,
        STAMINA = 0.5,
        INTELLECT = 2.5,
        SPIRIT = 1.5,
        SPELLPOWER = 2.0,
        CRIT = 1.8,
        HIT = 2.5,
        HASTE = 2.0,
    },
    WARLOCK = {
        STRENGTH = 0.0,
        AGILITY = 0.0,
        STAMINA = 0.8,
        INTELLECT = 2.5,
        SPIRIT = 1.5,
        SPELLPOWER = 2.0,
        CRIT = 1.5,
        HIT = 2.5,
        HASTE = 2.0,
    },
    DRUID = {
        STRENGTH = 1.0,
        AGILITY = 2.0,
        STAMINA = 1.5,
        INTELLECT = 2.0,
        SPIRIT = 1.5,
        ATTACKPOWER = 1.0,
        SPELLPOWER = 1.5,
        CRIT = 1.5,
        HIT = 2.0,
        HASTE = 1.5,
        ARMOR_PENETRATION = 1.2,
        DEFENSE = 1.0,
        DODGE = 1.2,
    },
}

-- ============================================================
-- Slot Mapping
-- ============================================================
local INVTYPE_TO_SLOT = {
    INVTYPE_HEAD = 1,
    INVTYPE_NECK = 2,
    INVTYPE_SHOULDER = 3,
    INVTYPE_CHEST = 5,
    INVTYPE_ROBE = 5,
    INVTYPE_WAIST = 6,
    INVTYPE_LEGS = 7,
    INVTYPE_FEET = 8,
    INVTYPE_WRIST = 9,
    INVTYPE_HAND = 10,
    INVTYPE_FINGER = 11,  -- or 12
    INVTYPE_TRINKET = 13, -- or 14
    INVTYPE_CLOAK = 15,
    INVTYPE_WEAPON = 16,  -- or 17 for offhand
    INVTYPE_2HWEAPON = 16,
    INVTYPE_WEAPONMAINHAND = 16,
    INVTYPE_WEAPONOFFHAND = 17,
    INVTYPE_HOLDABLE = 17,
    INVTYPE_SHIELD = 17,
    INVTYPE_RANGED = 18,
    INVTYPE_THROWN = 18,
    INVTYPE_RANGEDRIGHT = 18,
    INVTYPE_RELIC = 18,
}

-- ============================================================
-- Stat Extraction from Tooltip
-- ============================================================
local STAT_PATTERNS = {
    -- English patterns for 3.3.5a
    { pattern = "%+(%d+) Strength", stat = "STRENGTH" },
    { pattern = "%+(%d+) Agility", stat = "AGILITY" },
    { pattern = "%+(%d+) Stamina", stat = "STAMINA" },
    { pattern = "%+(%d+) Intellect", stat = "INTELLECT" },
    { pattern = "%+(%d+) Spirit", stat = "SPIRIT" },
    { pattern = "%+(%d+) Attack Power", stat = "ATTACKPOWER" },
    { pattern = "%+(%d+) Spell Power", stat = "SPELLPOWER" },
    { pattern = "%+(%d+) Critical Strike", stat = "CRIT" },
    { pattern = "%+(%d+) Hit Rating", stat = "HIT" },
    { pattern = "%+(%d+) Expertise Rating", stat = "EXPERTISE" },
    { pattern = "%+(%d+) Haste Rating", stat = "HASTE" },
    { pattern = "%+(%d+) Armor Penetration", stat = "ARMOR_PENETRATION" },
    { pattern = "%+(%d+) Resilience", stat = "RESILIENCE" },
    { pattern = "%+(%d+) Defense Rating", stat = "DEFENSE" },
    { pattern = "%+(%d+) Dodge Rating", stat = "DODGE" },
    { pattern = "%+(%d+) Parry Rating", stat = "PARRY" },
    { pattern = "%+(%d+) Block Rating", stat = "BLOCK" },
    { pattern = "(%d+) Armor", stat = "ARMOR", onlyFirst = true },
    { pattern = "Restores (%d+) mana per 5", stat = "MANA_PER_5" },
}

-- Scan hidden tooltip for stats
local scanTooltip = nil

local function CreateScanTooltip()
    if scanTooltip then return scanTooltip end
    
    scanTooltip = CreateFrame("GameTooltip", "DCQoSItemScoreScanTooltip", nil, "GameTooltipTemplate")
    scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    
    return scanTooltip
end

local function GetItemStats(itemLink)
    if not itemLink then return nil end
    
    local tooltip = CreateScanTooltip()
    tooltip:ClearLines()
    tooltip:SetHyperlink(itemLink)
    
    local stats = {}
    local numLines = tooltip:NumLines()
    
    for i = 2, numLines do  -- Skip first line (item name)
        local leftText = _G[tooltip:GetName() .. "TextLeft" .. i]
        if leftText then
            local text = leftText:GetText()
            if text then
                for _, patternInfo in ipairs(STAT_PATTERNS) do
                    local value = tonumber(text:match(patternInfo.pattern))
                    if value then
                        if patternInfo.onlyFirst and stats[patternInfo.stat] then
                            -- Skip if already found (e.g., base armor)
                        else
                            stats[patternInfo.stat] = (stats[patternInfo.stat] or 0) + value
                        end
                    end
                end
            end
        end
    end
    
    return stats
end

-- ============================================================
-- Score Calculation
-- ============================================================
local function GetPlayerWeights()
    local _, class = UnitClass("player")
    return StatWeights[class] or StatWeights.WARRIOR
end

local function CalculateScore(itemStats)
    if not itemStats then return 0 end
    
    local weights = GetPlayerWeights()
    local score = 0
    
    for stat, value in pairs(itemStats) do
        local weight = weights[stat] or 0
        score = score + (value * weight)
    end
    
    return math.floor(score * 10) / 10  -- Round to 1 decimal
end

local function GetEquippedScore(slot)
    local itemLink = GetInventoryItemLink("player", slot)
    if not itemLink then return 0 end
    
    local stats = GetItemStats(itemLink)
    return CalculateScore(stats)
end

-- ============================================================
-- Upgrade Detection
-- ============================================================
local function GetUpgradeStatus(itemLink)
    -- Returns: "upgrade", "downgrade", "sidegrade", or nil
    if not itemLink then return nil end
    
    -- Get item info
    local itemName, _, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, 
          itemStackCount, itemEquipLoc = GetItemInfo(itemLink)
    
    if not itemEquipLoc or itemEquipLoc == "" then
        return nil  -- Not equippable
    end
    
    local slot = INVTYPE_TO_SLOT[itemEquipLoc]
    if not slot then return nil end
    
    -- Handle rings/trinkets (two slots)
    local slots = { slot }
    if itemEquipLoc == "INVTYPE_FINGER" then
        slots = { 11, 12 }
    elseif itemEquipLoc == "INVTYPE_TRINKET" then
        slots = { 13, 14 }
    end
    
    -- Calculate new item score
    local newStats = GetItemStats(itemLink)
    local newScore = CalculateScore(newStats)
    
    if newScore == 0 then return nil end  -- No meaningful stats
    
    -- Compare with equipped items
    local bestEquippedScore = 0
    local worstEquippedScore = 999999
    
    for _, s in ipairs(slots) do
        local equippedScore = GetEquippedScore(s)
        if equippedScore > bestEquippedScore then
            bestEquippedScore = equippedScore
        end
        if equippedScore < worstEquippedScore then
            worstEquippedScore = equippedScore
        end
    end
    
    -- Compare
    local scoreDiff = newScore - worstEquippedScore
    local percentDiff = 0
    if worstEquippedScore > 0 then
        percentDiff = (scoreDiff / worstEquippedScore) * 100
    elseif newScore > 0 then
        percentDiff = 100  -- Upgrading from nothing
    end
    
    if percentDiff > 5 then
        return "upgrade", newScore, scoreDiff, percentDiff
    elseif percentDiff < -5 then
        return "downgrade", newScore, scoreDiff, percentDiff
    else
        return "sidegrade", newScore, scoreDiff, percentDiff
    end
end

-- ============================================================
-- Tooltip Enhancement
-- ============================================================
local function AddItemScore(tooltip, itemLink)
    local settings = addon.settings.itemScore
    if not settings.enabled then return end
    if not itemLink then return end
    
    local status, score, scoreDiff, percentDiff = GetUpgradeStatus(itemLink)
    if not status then return end
    
    tooltip:AddLine(" ")
    
    -- Show upgrade arrow
    if settings.showUpgradeArrows then
        local arrow, color
        if status == "upgrade" then
            arrow = "|TInterface\\Buttons\\UI-MicroStream-Green:0|t"
            color = settings.arrowColor
        elseif status == "downgrade" then
            arrow = "|TInterface\\Buttons\\UI-MicroStream-Red:0|t"
            color = settings.downgradeColor
        else
            arrow = "|TInterface\\Buttons\\UI-MicroStream-Yellow:0|t"
            color = settings.sideGradeColor
        end
        
        local statusText = status:sub(1, 1):upper() .. status:sub(2)
        local colorCode = string.format("|cff%02x%02x%02x", 
            math.floor(color.r * 255), 
            math.floor(color.g * 255), 
            math.floor(color.b * 255))
        
        if percentDiff then
            local sign = percentDiff >= 0 and "+" or ""
            tooltip:AddDoubleLine(
                arrow .. " " .. colorCode .. statusText .. "|r",
                colorCode .. sign .. string.format("%.1f%%", percentDiff) .. "|r",
                1, 1, 1, 1, 1, 1
            )
        else
            tooltip:AddLine(arrow .. " " .. colorCode .. statusText .. "|r")
        end
    end
    
    -- Show score
    if settings.showScore and score then
        tooltip:AddDoubleLine(
            "Score:",
            "|cffffffff" .. string.format("%.1f", score) .. "|r",
            0.5, 0.5, 0.5
        )
        
        if settings.showComparison and scoreDiff then
            local sign = scoreDiff >= 0 and "+" or ""
            local diffColor = scoreDiff >= 0 and "|cff00ff00" or "|cffff0000"
            tooltip:AddDoubleLine(
                "vs Equipped:",
                diffColor .. sign .. string.format("%.1f", scoreDiff) .. "|r",
                0.5, 0.5, 0.5
            )
        end
    end
    
    -- Show stat weights breakdown (if enabled)
    if settings.showStatWeights then
        local stats = GetItemStats(itemLink)
        if stats then
            tooltip:AddLine(" ")
            tooltip:AddLine("|cff888888Stat Weights:|r")
            local weights = GetPlayerWeights()
            for stat, value in pairs(stats) do
                local weight = weights[stat] or 0
                if weight > 0 then
                    local contribution = value * weight
                    tooltip:AddDoubleLine(
                        "|cffaaaaaa" .. stat .. ":|r",
                        "|cffffffff" .. value .. " x " .. weight .. " = " .. string.format("%.1f", contribution) .. "|r",
                        1, 1, 1, 1, 1, 1
                    )
                end
            end
        end
    end
end

-- ============================================================
-- Hook into Tooltips module
-- ============================================================
local function HookTooltips()
    -- Hook into item tooltip methods
    local tooltipsToHook = {
        GameTooltip,
        ItemRefTooltip,
        ShoppingTooltip1,
        ShoppingTooltip2,
    }
    
    for _, tooltip in ipairs(tooltipsToHook) do
        if tooltip then
            tooltip:HookScript("OnTooltipSetItem", function(self)
                local _, itemLink = self:GetItem()
                if itemLink then
                    AddItemScore(self, itemLink)
                    self:Show()
                end
            end)
        end
    end
    
    addon:Debug("ItemScore tooltip hooks installed")
end

-- ============================================================
-- Server Integration
-- ============================================================
-- Server can send custom stat weights per character
function ItemScore:SetCustomWeights(class, weights)
    if class and weights then
        StatWeights[class] = weights
    end
end

-- ============================================================
-- Module Callbacks
-- ============================================================
function ItemScore.OnInitialize()
    addon:Debug("ItemScore module initializing")
    CreateScanTooltip()
end

function ItemScore.OnEnable()
    addon:Debug("ItemScore module enabling")
    HookTooltips()
    
    -- Listen for server-sent weights
    addon:RegisterEvent("STAT_WEIGHTS_RECEIVED", function(data)
        if data and data.class and data.weights then
            ItemScore:SetCustomWeights(data.class, data.weights)
        end
    end)
end

function ItemScore.OnDisable()
    addon:Debug("ItemScore module disabling")
end

-- ============================================================
-- Settings Panel Creation
-- ============================================================
function ItemScore.CreateSettings(parent)
    local settings = addon.settings.itemScore
    
    -- Title
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Item Score Settings")
    
    -- Description
    local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText("Pawn-style item upgrade detection and scoring based on stat weights for your class.")
    desc:SetWidth(parent:GetWidth() - 32)
    desc:SetJustifyH("LEFT")
    
    local yOffset = -70
    
    -- ============================================================
    -- Enable Section
    -- ============================================================
    local enableCb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    enableCb:SetPoint("TOPLEFT", 16, yOffset)
    enableCb.Text:SetText("Enable Item Scoring")
    enableCb:SetChecked(settings.enabled)
    enableCb:SetScript("OnClick", function(self)
        addon:SetSetting("itemScore.enabled", self:GetChecked())
    end)
    yOffset = yOffset - 35
    
    -- ============================================================
    -- Display Options
    -- ============================================================
    local displayHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    displayHeader:SetPoint("TOPLEFT", 16, yOffset)
    displayHeader:SetText("Display Options")
    yOffset = yOffset - 25
    
    -- Show Upgrade Arrows
    local arrowsCb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    arrowsCb:SetPoint("TOPLEFT", 16, yOffset)
    arrowsCb.Text:SetText("Show Upgrade/Downgrade Arrows")
    arrowsCb:SetChecked(settings.showUpgradeArrows)
    arrowsCb:SetScript("OnClick", function(self)
        addon:SetSetting("itemScore.showUpgradeArrows", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    -- Show Score
    local scoreCb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    scoreCb:SetPoint("TOPLEFT", 16, yOffset)
    scoreCb.Text:SetText("Show Item Score")
    scoreCb:SetChecked(settings.showScore)
    scoreCb:SetScript("OnClick", function(self)
        addon:SetSetting("itemScore.showScore", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    -- Show Comparison
    local compCb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    compCb:SetPoint("TOPLEFT", 16, yOffset)
    compCb.Text:SetText("Show Comparison with Equipped")
    compCb:SetChecked(settings.showComparison)
    compCb:SetScript("OnClick", function(self)
        addon:SetSetting("itemScore.showComparison", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    -- Show Stat Weights
    local weightsCb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    weightsCb:SetPoint("TOPLEFT", 16, yOffset)
    weightsCb.Text:SetText("Show Stat Weight Breakdown (verbose)")
    weightsCb:SetChecked(settings.showStatWeights)
    weightsCb:SetScript("OnClick", function(self)
        addon:SetSetting("itemScore.showStatWeights", self:GetChecked())
    end)
    yOffset = yOffset - 35
    
    -- ============================================================
    -- Current Class Info
    -- ============================================================
    local classHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    classHeader:SetPoint("TOPLEFT", 16, yOffset)
    classHeader:SetText("Current Class Weights")
    yOffset = yOffset - 20
    
    local _, playerClass = UnitClass("player")
    local weights = StatWeights[playerClass] or {}
    
    local classInfo = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    classInfo:SetPoint("TOPLEFT", 16, yOffset)
    
    local weightText = "Class: " .. (playerClass or "Unknown") .. "\nPrimary Stats: "
    local primaryStats = {}
    for stat, weight in pairs(weights) do
        if weight >= 2.0 then
            table.insert(primaryStats, stat)
        end
    end
    weightText = weightText .. table.concat(primaryStats, ", ")
    
    classInfo:SetText(weightText)
    classInfo:SetWidth(parent:GetWidth() - 32)
    classInfo:SetJustifyH("LEFT")
    
    return yOffset - 60
end

-- ============================================================
-- Register Module
-- ============================================================
addon:RegisterModule("ItemScore", ItemScore)
