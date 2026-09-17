--[[
    DC-InfoBar Bags Plugin
    Shows free bag space
    
    Data Source: WoW API (GetContainerNumFreeSlots, GetContainerNumSlots)
]]

local addonName = "DC-InfoBar"
local DCInfoBar = DCInfoBar or {}

local BagsPlugin = {
    id = "DCInfoBar_Bags",
    name = "Bag Space",
    category = "character",
    type = "combo",
    side = "right",
    priority = 920,
    icon = "Interface\\Icons\\INV_Misc_Bag_08",
    updateInterval = 2.0,
    
    leftClickHint = "Open all bags",
    rightClickHint = "Print free space",
    
    _freeSlots = 0,
    _totalSlots = 0,
    _bags = {},
}

-- Bag family names for GetContainerNumFreeSlots' bagType bitmask (3.3.5).
local BAG_FAMILY_NAMES = {
    [1] = "Quiver", [2] = "Ammo Pouch", [4] = "Soul Bag", [8] = "Leatherworking Bag",
    [16] = "Inscription Bag", [32] = "Herb Bag", [64] = "Enchanting Bag",
    [128] = "Engineering Bag", [512] = "Gem Bag", [1024] = "Mining Bag",
}

function BagsPlugin:OnUpdate(elapsed)
    local totalFree, totalSlots = 0, 0
    self._bags = {}

    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        if numSlots and numSlots > 0 then
            local numFree, bagType = GetContainerNumFreeSlots(bag)
            numFree = numFree or 0
            bagType = bagType or 0

            -- Profession/ammo bag space can't hold regular loot, so it isn't
            -- counted as free space.
            if bagType == 0 then
                totalSlots = totalSlots + numSlots
                totalFree = totalFree + numFree
            end

            local name = (bag == 0) and "Backpack" or (GetBagName(bag) or ("Bag " .. bag))
            self._bags[bag] = { free = numFree, total = numSlots, name = name, bagType = bagType }
        end
    end

    self._freeSlots = totalFree
    self._totalSlots = totalSlots

    local percentFree = totalSlots > 0 and (totalFree / totalSlots * 100) or 100
    local color = "green"
    if percentFree <= 10 then
        color = "red"
    elseif percentFree <= 25 then
        color = "yellow"
    end

    local text
    if DCInfoBar:GetPluginSetting(self.id, "showAsPercent") then
        text = math.floor(percentFree) .. "% free"
    else
        text = totalFree .. "/" .. totalSlots
    end

    if DCInfoBar:GetPluginSetting(self.id, "warnWhenFull") ~= false and totalFree <= 5
        and math.floor(GetTime() * 2) % 2 == 0 then
        text = text .. " |cffff5050!|r"
    end

    return "", text, color
end

local function FreeColor(free, total)
    local percent = total > 0 and (free / total * 100) or 100
    if percent <= 10 then
        return 1, 0.3, 0.3
    elseif percent <= 25 then
        return 1, 0.82, 0
    end
    return 0.3, 1, 0.5
end

function BagsPlugin:OnTooltip(tooltip)
    tooltip:AddLine("Bag Space", 1, 0.82, 0)
    DCInfoBar:AddTooltipSeparator(tooltip)

    local special = {}
    for bag = 0, 4 do
        local data = self._bags[bag]
        if data then
            if data.bagType == 0 then
                local r, g, b = FreeColor(data.free, data.total)
                tooltip:AddDoubleLine(data.name .. ":", string.format("%d/%d free", data.free, data.total),
                    0.7, 0.7, 0.7, r, g, b)
            else
                table.insert(special, data)
            end
        end
    end

    tooltip:AddLine(" ")
    local r, g, b = FreeColor(self._freeSlots, self._totalSlots)
    tooltip:AddDoubleLine("Total:", string.format("%d/%d slots free", self._freeSlots, self._totalSlots),
        0.7, 0.7, 0.7, r, g, b)

    if #special > 0 then
        tooltip:AddLine(" ")
        tooltip:AddLine("|cff32c4ffSpecial Bags|r")
        for _, data in ipairs(special) do
            local family = BAG_FAMILY_NAMES[data.bagType] or "Special"
            tooltip:AddDoubleLine("  " .. data.name .. " (" .. family .. ")",
                string.format("%d/%d free", data.free, data.total), 0.7, 0.7, 0.7, 0.8, 0.8, 0.8)
        end
    end

    if self._freeSlots <= 5 then
        tooltip:AddLine(" ")
        tooltip:AddLine("|cffff5050Bags almost full!|r")
    end
end

function BagsPlugin:OnClick(button)
    if button == "LeftButton" then
        -- Open all bags
        OpenAllBags()
    elseif button == "RightButton" then
        DCInfoBar:Print("Bag Space: " .. self._freeSlots .. "/" .. self._totalSlots .. " free")
    end
end

function BagsPlugin:OnCreateOptions(parent, yOffset)
    local percentCB = DCInfoBar:CreateCheckbox(parent, "Show as percentage", 20, yOffset, function(checked)
        DCInfoBar:SetPluginSetting(self.id, "showAsPercent", checked)
    end, DCInfoBar:GetPluginSetting(self.id, "showAsPercent"))
    yOffset = yOffset - 30
    
    local warnCB = DCInfoBar:CreateCheckbox(parent, "Warn when almost full", 20, yOffset, function(checked)
        DCInfoBar:SetPluginSetting(self.id, "warnWhenFull", checked)
    end, DCInfoBar:GetPluginSetting(self.id, "warnWhenFull") ~= false)
    
    return yOffset - 30
end

-- Register plugin
DCInfoBar:RegisterPlugin(BagsPlugin)
