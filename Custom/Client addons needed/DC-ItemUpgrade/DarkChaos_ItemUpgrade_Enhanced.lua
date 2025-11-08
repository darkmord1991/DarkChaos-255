-- ═══════════════════════════════════════════════════════════════════════════════
-- DarkChaos Item Upgrade Addon - ENHANCED VERSION
-- Features:
-- 1. Display upgrade info on equipped items
-- 2. Show stat breakdown with calculations
-- 3. Proper tier assignment (Tier 1: max 6, Tier 2: max 15)
-- 4. Green text for upgrade info
-- ═══════════════════════════════════════════════════════════════════════════════

local DC_ItemUpgrade = {}
DC_ItemUpgrade.VERSION = "2.1"
DC_ItemUpgrade.TIER_1_MAX_LEVEL = 6
DC_ItemUpgrade.TIER_2_MAX_LEVEL = 15
DC_ItemUpgrade.TIER_NAMES = {
    [1] = "|cffff7f3fTier 1 - Starter|r",
    [2] = "|cff0070ddTier 2 - Advanced|r",
    [3] = "|cffa335eeTier 3 - Rare|r",
    [4] = "|cffffb100Tier 4 - Epic|r",
    [5] = "|cffff8000Tier 5 - Artifact|r"
}

-- ───────────────────────────────────────────────────────────────────────────────
-- TIER LIMITS TABLE - Based on upgrade tier
-- ───────────────────────────────────────────────────────────────────────────────
DC_ItemUpgrade.TIER_MAX_LEVELS = {
    [1] = 6,   -- Tier 1: Common items, max level 6
    [2] = 15,  -- Tier 2: Uncommon+ items, max level 15
    [3] = 15,  -- Tier 3: Reserved
    [4] = 15,  -- Tier 4: Reserved
    [5] = 15   -- Tier 5: Artifact
}

-- ───────────────────────────────────────────────────────────────────────────────
-- TIER COST MULTIPLIERS
-- ───────────────────────────────────────────────────────────────────────────────
DC_ItemUpgrade.TIER_COSTS = {
    [1] = {
        tokens = {10, 15, 20, 25, 30, 40},  -- Tier 1: 6 levels
        essence = {10, 15, 20, 25, 30, 40}
    },
    [2] = {
        tokens = {40, 50, 60, 70, 80, 90, 100, 120, 140, 160, 180, 200, 240, 280, 320},  -- Tier 2: 15 levels
        essence = {40, 50, 60, 70, 80, 90, 100, 120, 140, 160, 180, 200, 240, 280, 320}
    }
}

-- ───────────────────────────────────────────────────────────────────────────────
-- STAT CALCULATION FUNCTIONS
-- ───────────────────────────────────────────────────────────────────────────────

-- Calculate stat multiplier based on upgrade level and tier
function DC_ItemUpgrade:GetStatMultiplier(upgradeLevel, tier)
    if not upgradeLevel or upgradeLevel == 0 then
        return 1.0
    end
    
    tier = tier or 1
    
    -- Tier 1: +2.25% per level (6 levels max = +13.5%)
    -- Tier 2: +3.5% per level (15 levels max = +52.5%)
    local percent_per_level = (tier == 2) and 0.035 or 0.0225
    local total_bonus_percent = upgradeLevel * percent_per_level
    local multiplier = 1.0 + total_bonus_percent
    
    return multiplier
end

-- Get bonus percentage (rounded whole number)
function DC_ItemUpgrade:GetBonusPercent(upgradeLevel, tier)
    if not upgradeLevel or upgradeLevel == 0 then
        return 0
    end
    
    local multiplier = self:GetStatMultiplier(upgradeLevel, tier)
    local bonus_percent = (multiplier - 1.0) * 100.0
    
    -- Round to nearest whole number
    return math.floor(bonus_percent + 0.5)
end

-- Calculate individual stat bonuses
function DC_ItemUpgrade:CalculateStatBonuses(baseStats, upgradeLevel, tier)
    local multiplier = self:GetStatMultiplier(upgradeLevel, tier)
    
    return {
        strength = math.floor((baseStats.strength or 0) * multiplier),
        agility = math.floor((baseStats.agility or 0) * multiplier),
        stamina = math.floor((baseStats.stamina or 0) * multiplier),
        intellect = math.floor((baseStats.intellect or 0) * multiplier),
        spirit = math.floor((baseStats.spirit or 0) * multiplier),
        crit = math.floor((baseStats.crit or 0) * multiplier),
        haste = math.floor((baseStats.haste or 0) * multiplier),
        hit = math.floor((baseStats.hit or 0) * multiplier),
        armor = math.floor((baseStats.armor or 0) * multiplier),
        weapon_damage = math.floor((baseStats.weapon_damage or 0) * multiplier),
        spell_power = math.floor((baseStats.spell_power or 0) * multiplier)
    }
end

-- ───────────────────────────────────────────────────────────────────────────────
-- TOOLTIP GENERATION
-- ───────────────────────────────────────────────────────────────────────────────

-- Generate upgrade information for tooltip
function DC_ItemUpgrade:GenerateUpgradeTooltip(upgradeLevel, tier, baseItemLevel, upgradedItemLevel)
    local lines = {}
    
    if not upgradeLevel or upgradeLevel == 0 then
        table.insert(lines, " ")
        table.insert(lines, "|cffffd700===== Item Upgrade Status =====|r")
        table.insert(lines, "|cff00ff00Upgrade Level: 0/" .. self.TIER_MAX_LEVELS[tier or 1] .. " (New)|r")
        table.insert(lines, "|cff00ff00Stat Bonus: +0%|r")
        table.insert(lines, "|cff00ff00Item Level: " .. (baseItemLevel or 0) .. "|r")
        return table.concat(lines, "\n")
    end
    
    tier = tier or 1
    local bonusPercent = self:GetBonusPercent(upgradeLevel, tier)
    local maxLevel = self.TIER_MAX_LEVELS[tier]
    
    table.insert(lines, " ")
    table.insert(lines, "|cffffd700===== Item Upgrade Status =====|r")
    table.insert(lines, string.format("|cff00ff00Upgrade Level: %d/%d|r", upgradeLevel, maxLevel))
    table.insert(lines, string.format("|cff00ff00Stat Bonus: +%d%%|r", bonusPercent))
    table.insert(lines, string.format("|cff00ff00Item Level: %d (Base %d)|r", upgradedItemLevel or baseItemLevel, baseItemLevel))
    
    -- Show tier name
    table.insert(lines, string.format("|cff00ff00%s|r", self.TIER_NAMES[tier] or "Unknown Tier"))
    
    -- Show maximum upgrade level for this tier
    if upgradeLevel < maxLevel then
        table.insert(lines, string.format("|cff00ff00Can upgrade to level %d|r", maxLevel))
    else
        table.insert(lines, "|cffff0000⭐ FULLY UPGRADED ⭐|r")
    end
    
    return table.concat(lines, "\n")
end

-- ───────────────────────────────────────────────────────────────────────────────
-- TOOLTIP HOOK FOR BOTH EQUIPPED AND BAG ITEMS
-- ───────────────────────────────────────────────────────────────────────────────

-- Cache for upgrade data
DC_ItemUpgrade.upgradeCache = {}

-- Parse server response and cache upgrade data
function DC_ItemUpgrade:ParseUpgradeQuery(response)
    -- Format: DCUPGRADE_QUERY:item_guid:bag:tier:base_level:upgraded_level:multiplier
    local parts = {}
    for part in string.gmatch(response, "[^:]+") do
        table.insert(parts, part)
    end
    
    if parts[1] ~= "DCUPGRADE_QUERY" then
        return nil
    end
    
    local item_guid = parts[2]
    local tier = tonumber(parts[4]) or 1
    local base_item_level = tonumber(parts[5]) or 1
    local upgraded_item_level = tonumber(parts[6]) or 1
    local multiplier = tonumber(parts[7]) or 1.0
    
    -- Calculate upgrade level from multiplier
    local percent_per_level = (tier == 2) and 0.035 or 0.0225
    local total_bonus_percent = (multiplier - 1.0) * 100.0
    local upgrade_level = math.floor(total_bonus_percent / (percent_per_level * 100) + 0.5)
    
    -- Cache the data
    self.upgradeCache[item_guid] = {
        tier = tier,
        base_item_level = base_item_level,
        upgraded_item_level = upgraded_item_level,
        multiplier = multiplier,
        upgrade_level = upgrade_level,
        bonus_percent = math.floor(total_bonus_percent + 0.5)
    }
    
    return self.upgradeCache[item_guid]
end

-- Hook into equipped item tooltips
if GameTooltip then
    local originalSetInventoryItem = GameTooltip.SetInventoryItem
    function GameTooltip:SetInventoryItem(unit, slot, ...)
        originalSetInventoryItem(self, unit, slot, ...)
        
        -- Get item link
        local itemLink = GetInventoryItemLink(unit, slot)
        if itemLink then
            DC_ItemUpgrade:AddUpgradeInfoToTooltip(self, itemLink)
        end
    end
    
    local originalSetBagItem = GameTooltip.SetBagItem
    function GameTooltip:SetBagItem(bag, slot, ...)
        originalSetBagItem(self, bag, slot, ...)
        
        -- Get item link
        local itemLink = GetBagItemLink(bag, slot)
        if itemLink then
            DC_ItemUpgrade:AddUpgradeInfoToTooltip(self, itemLink)
        end
    end
end

-- Add upgrade information to any tooltip
function DC_ItemUpgrade:AddUpgradeInfoToTooltip(tooltip, itemLink)
    if not tooltip or not itemLink then
        return
    end
    
    -- Extract item ID from item link
    local itemId = tonumber(itemLink:match("item:(%d+)"))
    if not itemId then
        return
    end
    
    -- For now, check if we have cached data
    -- In production, this would query the server
    for guid, data in pairs(self.upgradeCache) do
        if data.base_item_level and data.base_item_level > 0 then
            -- Add upgrade info to tooltip
            local upgradeTip = self:GenerateUpgradeTooltip(
                data.upgrade_level,
                data.tier,
                data.base_item_level,
                data.upgraded_item_level
            )
            
            if upgradeTip and upgradeTip ~= "" then
                tooltip:AddLine(" ")
                for line in string.gmatch(upgradeTip, "[^\n]+") do
                    tooltip:AddLine(line, 1, 1, 1)
                end
            end
            break
        end
    end
    
    tooltip:Show()
end

-- ───────────────────────────────────────────────────────────────────────────────
-- EVENT HANDLING
-- ───────────────────────────────────────────────────────────────────────────────

if not DarkChaosItemUpgradeFrame then
    DarkChaosItemUpgradeFrame = CreateFrame("Frame")
end

-- Event handler for addon messages
function DarkChaosItemUpgradeFrame:OnAddonMessage(prefix, message, channel, sender)
    if prefix == "DC_ItemUpgrade" then
        DC_ItemUpgrade:ParseUpgradeQuery(message)
    end
end

-- Register for addon messages
DarkChaosItemUpgradeFrame:RegisterEvent("CHAT_MSG_ADDON")
DarkChaosItemUpgradeFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        self:OnAddonMessage(prefix, message, channel, sender)
    end
end)

-- Register for addon communication prefix
if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    C_ChatInfo:RegisterAddonMessagePrefix("DC_ItemUpgrade")
end

-- ───────────────────────────────────────────────────────────────────────────────
-- TIER RESTRICTION VALIDATION
-- ───────────────────────────────────────────────────────────────────────────────

-- Validate that target upgrade level doesn't exceed tier max
function DC_ItemUpgrade:ValidateUpgradeLevel(targetLevel, tier)
    local maxLevel = self.TIER_MAX_LEVELS[tier or 1] or 15
    
    if targetLevel > maxLevel then
        print(string.format("|cffff0000Tier %d items can only upgrade to level %d (tried to set %d)|r", 
            tier or 1, maxLevel, targetLevel))
        return maxLevel
    end
    
    return targetLevel
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- Debug/Test Functions
-- ═══════════════════════════════════════════════════════════════════════════════

-- Test function: Display stat calculations
function DC_ItemUpgrade:TestStatCalculations()
    print("|cffffd700=== Item Upgrade Addon v" .. self.VERSION .. " ===|r")
    print("|cff00ff00Tier 1 (Max Level 6):|r")
    for level = 1, 6 do
        local bonus = self:GetBonusPercent(level, 1)
        print(string.format("  Level %d: +%d%%", level, bonus))
    end
    
    print("|cff00ff00Tier 2 (Max Level 15):|r")
    for level = 1, 15 do
        local bonus = self:GetBonusPercent(level, 2)
        print(string.format("  Level %d: +%d%%", level, bonus))
    end
end

-- Print debug info
function DC_ItemUpgrade:Debug()
    print("|cffffd700=== DC_ItemUpgrade Debug ===|r")
    print(string.format("|cff00ff00Cached upgrades: %d|r", table.getn(self.upgradeCache)))
    for guid, data in pairs(self.upgradeCache) do
        print(string.format("  %s: Tier %d, Level %d, Bonus +%d%%", 
            guid:sub(1, 20) .. "...", data.tier, data.upgrade_level, data.bonus_percent))
    end
end

-- Export for global access
_G.DC_ItemUpgrade = DC_ItemUpgrade

-- ═══════════════════════════════════════════════════════════════════════════════
-- End of Enhanced Addon Code
-- ═══════════════════════════════════════════════════════════════════════════════
