--[[
    DC-InfoBar Durability Plugin
    Shows equipment durability and repair costs
    
    Data Source: WoW API (GetInventoryItemDurability)
]]

local addonName = "DC-InfoBar"
local DCInfoBar = DCInfoBar or {}

local DurabilityPlugin = {
    id = "DCInfoBar_Durability",
    name = "Durability",
    category = "character",
    type = "combo",
    side = "right",
    priority = 910,
    icon = "Interface\\Icons\\Trade_BlackSmithing",
    updateInterval = 5.0,
    
    leftClickHint = "Repair (if at vendor)",
    rightClickHint = "Show item breakdown",
    
    _lowestDura = 100,
    _repairCost = 0,
    _slots = {},
}

-- Equipment slot IDs
local SLOTS = {
    { id = 1, name = "Head" },
    { id = 3, name = "Shoulders" },
    { id = 5, name = "Chest" },
    { id = 6, name = "Waist" },
    { id = 7, name = "Legs" },
    { id = 8, name = "Feet" },
    { id = 9, name = "Wrists" },
    { id = 10, name = "Hands" },
    { id = 16, name = "Main Hand" },
    { id = 17, name = "Off Hand" },
    { id = 18, name = "Ranged" },
}

function DurabilityPlugin:OnUpdate(elapsed)
    local lowest = 100
    local totalCost = 0
    self._slots = {}
    
    for _, slot in ipairs(SLOTS) do
        local current, max = GetInventoryItemDurability(slot.id)
        if current and max and max > 0 then
            local percent = math.floor((current / max) * 100)
            self._slots[slot.id] = {
                name = slot.name,
                current = current,
                max = max,
                percent = percent,
            }
            
            if percent < lowest then
                lowest = percent
            end
        end
    end
    
    self._lowestDura = lowest

    -- Repair cost is only available while interacting with a repair-capable merchant.
    self._repairCost = 0
    if CanMerchantRepair and CanMerchantRepair() and GetRepairAllCost then
        local cost = GetRepairAllCost()
        self._repairCost = tonumber(cost) or 0
    end
    
    -- Determine color
    local color = "green"
    local lowThreshold = DCInfoBar:GetPluginSetting(self.id, "lowThreshold") or 25
    
    if lowest <= lowThreshold then
        color = "red"
    elseif lowest <= 50 then
        color = "yellow"
    end
    
    -- Flash effect for very low durability
    local flashOnLow = DCInfoBar:GetPluginSetting(self.id, "flashOnLow")
    if flashOnLow and lowest <= lowThreshold then
        -- Add flashing indicator
        if math.floor(GetTime() * 2) % 2 == 0 then
            return "", lowest .. "% |cffff5050!|r", color
        end
    end
    
    return "", lowest .. "%", color
end

function DurabilityPlugin:OnTooltip(tooltip)
    tooltip:AddLine("Equipment Durability", 1, 0.82, 0)
    DCInfoBar:AddTooltipSeparator(tooltip)
    
    -- Per-slot breakdown
    for _, slot in ipairs(SLOTS) do
        local data = self._slots[slot.id]
        if data then
            local percent = data.percent
            
            local r, g, b = 0.3, 1, 0.5  -- Green
            if percent <= 25 then
                r, g, b = 1, 0.3, 0.3  -- Red
            elseif percent <= 50 then
                r, g, b = 1, 0.82, 0  -- Yellow
            end
            
            tooltip:AddDoubleLine(
                data.name .. ":",
                string.format("%d%%", percent),
                0.7, 0.7, 0.7, r, g, b
            )
        end
    end
    
    -- Summary
    tooltip:AddLine(" ")
    
    local r, g, b = 0.3, 1, 0.5
    if self._lowestDura <= 25 then
        r, g, b = 1, 0.3, 0.3
    elseif self._lowestDura <= 50 then
        r, g, b = 1, 0.82, 0
    end
    
    tooltip:AddDoubleLine("Lowest:", self._lowestDura .. "%", 0.7, 0.7, 0.7, r, g, b)
    
    -- Repair cost (if available)
    local showRepairCost = DCInfoBar:GetPluginSetting(self.id, "showRepairCost")
    if showRepairCost then
        local canRepairHere = CanMerchantRepair and CanMerchantRepair() and GetRepairAllCost
        local valueText
        local vr, vg, vb

        if canRepairHere then
            valueText = DCInfoBar:FormatGold(self._repairCost)
            vr, vg, vb = 1, 0.82, 0
        else
            valueText = "N/A"
            vr, vg, vb = 0.7, 0.7, 0.7
        end

        tooltip:AddDoubleLine(
            "Repair Cost:",
            valueText,
            0.7, 0.7, 0.7, vr, vg, vb
        )
    end
    
    -- Warning if low
    if self._lowestDura <= 10 then
        tooltip:AddLine(" ")
        tooltip:AddLine("|cffff5050Equipment needs repair!|r")
    end
end

function DurabilityPlugin:OnClick(button)
    if button == "LeftButton" then
        -- Try to repair if at vendor
        if CanMerchantRepair() then
            RepairAllItems()
            DCInfoBar:Print("Equipment repaired!")
        else
            DCInfoBar:Print("Find a repair vendor to repair equipment.")
        end
    elseif button == "RightButton" then
        -- Print breakdown
        DCInfoBar:Print("Equipment Durability:")
        for _, slot in ipairs(SLOTS) do
            local data = self._slots[slot.id]
            if data then
                DCInfoBar:Print("  " .. data.name .. ": " .. data.percent .. "%")
            end
        end
    end
end

function DurabilityPlugin:OnCreateOptions(parent, yOffset)
    local flashCB = DCInfoBar:CreateCheckbox(parent, "Flash when durability is low", 20, yOffset, function(checked)
        DCInfoBar:SetPluginSetting(self.id, "flashOnLow", checked)
    end, DCInfoBar:GetPluginSetting(self.id, "flashOnLow") ~= false)
    yOffset = yOffset - 30
    
    local repairCB = DCInfoBar:CreateCheckbox(parent, "Show repair cost in tooltip", 20, yOffset, function(checked)
        DCInfoBar:SetPluginSetting(self.id, "showRepairCost", checked)
    end, DCInfoBar:GetPluginSetting(self.id, "showRepairCost"))
    
    return yOffset - 30
end

-- Register plugin
DCInfoBar:RegisterPlugin(DurabilityPlugin)
