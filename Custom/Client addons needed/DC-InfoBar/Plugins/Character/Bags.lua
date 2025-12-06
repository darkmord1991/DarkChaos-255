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
    rightClickHint = "Show bag breakdown",
    
    _freeSlots = 0,
    _totalSlots = 0,
    _bags = {},
}

function BagsPlugin:OnUpdate(elapsed)
    local totalFree = 0
    local totalSlots = 0
    self._bags = {}
    
    -- Bags 0-4 (backpack + 4 bag slots)
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        local numFree = GetContainerNumFreeSlots(bag)
        
        if numSlots and numSlots > 0 then
            totalSlots = totalSlots + numSlots
            totalFree = totalFree + (numFree or 0)
            
            self._bags[bag] = {
                free = numFree or 0,
                total = numSlots,
                name = bag == 0 and "Backpack" or ("Bag " .. bag),
            }
        end
    end
    
    self._freeSlots = totalFree
    self._totalSlots = totalSlots
    
    -- Determine color
    local color = "green"
    local percentFree = totalSlots > 0 and (totalFree / totalSlots * 100) or 100
    
    if percentFree <= 10 then
        color = "red"
    elseif percentFree <= 25 then
        color = "yellow"
    end
    
    -- Warning if almost full
    local warnWhenFull = DCInfoBar:GetPluginSetting(self.id, "warnWhenFull")
    if warnWhenFull and totalFree <= 5 then
        if math.floor(GetTime() * 2) % 2 == 0 then
            return "", totalFree .. "/" .. totalSlots .. " |cffff5050!|r", color
        end
    end
    
    -- Display format
    local showAsPercent = DCInfoBar:GetPluginSetting(self.id, "showAsPercent")
    if showAsPercent then
        return "", math.floor(percentFree) .. "% free", color
    else
        return "", totalFree .. "/" .. totalSlots, color
    end
end

function BagsPlugin:OnTooltip(tooltip)
    tooltip:AddLine("Bag Space", 1, 0.82, 0)
    DCInfoBar:AddTooltipSeparator(tooltip)
    
    -- Per-bag breakdown
    for bag = 0, 4 do
        local data = self._bags[bag]
        if data then
            local percent = data.total > 0 and (data.free / data.total * 100) or 100
            local r, g, b = 0.3, 1, 0.5
            
            if percent <= 10 then
                r, g, b = 1, 0.3, 0.3
            elseif percent <= 25 then
                r, g, b = 1, 0.82, 0
            end
            
            tooltip:AddDoubleLine(
                data.name .. ":",
                string.format("%d/%d free", data.free, data.total),
                0.7, 0.7, 0.7, r, g, b
            )
        end
    end
    
    -- Total
    tooltip:AddLine(" ")
    
    local percentFree = self._totalSlots > 0 and (self._freeSlots / self._totalSlots * 100) or 100
    local r, g, b = 0.3, 1, 0.5
    if percentFree <= 10 then
        r, g, b = 1, 0.3, 0.3
    elseif percentFree <= 25 then
        r, g, b = 1, 0.82, 0
    end
    
    tooltip:AddDoubleLine("Total:",
        string.format("%d/%d slots free", self._freeSlots, self._totalSlots),
        0.7, 0.7, 0.7, r, g, b)
    
    -- Special bags (ammo, herb, etc.)
    tooltip:AddLine(" ")
    tooltip:AddLine("|cff32c4ffSpecial Bags|r")
    
    -- Check for ammo (bag -1 in 3.3.5a doesn't work like this, but check slots 0-4 bag type)
    local hasSpecialBags = false
    for bag = 1, 4 do
        local bagType = GetBagSlotItemInfo and GetBagSlotItemInfo(bag)
        if bagType then
            hasSpecialBags = true
            -- Would show special bag type here
        end
    end
    
    if not hasSpecialBags then
        tooltip:AddLine("  None equipped", 0.5, 0.5, 0.5)
    end
    
    -- Warning
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
        -- Sort bags (if available)
        if SortBags then
            SortBags()
            DCInfoBar:Print("Sorting bags...")
        else
            -- Print breakdown
            DCInfoBar:Print("Bag Space: " .. self._freeSlots .. "/" .. self._totalSlots .. " free")
        end
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
