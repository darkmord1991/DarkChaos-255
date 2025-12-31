--[[
    DC-Collection Bonuses.lua
    ==========================
    
    Mount speed bonuses and other collection-based passive bonuses.
    
    Author: DarkChaos-255
    Version: 1.0.0
]]

local DC = DCCollection
local L = DC.L

-- ============================================================================
-- MOUNT SPEED BONUS SYSTEM
-- ============================================================================

--[[
    Mount speed bonuses are granted based on collection milestones:
    
    Thresholds:
    - 25 mounts:  +2% mount speed (Spell 300510)
    - 50 mounts:  +3% mount speed (Spell 300511)
    - 100 mounts: +3% mount speed (Spell 300512)
    - 150 mounts: +2% mount speed (Spell 300513)
    
    Total: +10% at 150+ mounts
    
    Additional bonuses can be purchased from the shop.
]]

-- ============================================================================
-- BONUS THRESHOLDS
-- ============================================================================

DC.MOUNT_SPEED_THRESHOLDS = {
    { count = 25,  bonus = 2, spellId = 300510 },
    { count = 50,  bonus = 3, spellId = 300511 },
    { count = 100, bonus = 3, spellId = 300512 },
    { count = 150, bonus = 2, spellId = 300513 },
}

-- ============================================================================
-- BONUS DISPLAY
-- ============================================================================

function DC:GetMountSpeedBreakdown()
    local breakdown = {}
    local mountCount = self.stats.mounts and self.stats.mounts.owned or 0
    
    -- Natural bonuses from collection
    local naturalBonus = 0
    for _, threshold in ipairs(self.MOUNT_SPEED_THRESHOLDS) do
        local earned = mountCount >= threshold.count
        table.insert(breakdown, {
            source = string.format("%d Mounts", threshold.count),
            bonus = threshold.bonus,
            earned = earned,
            current = mountCount,
            required = threshold.count,
        })
        if earned then
            naturalBonus = naturalBonus + threshold.bonus
        end
    end
    
    -- Shop-purchased bonuses
    local purchasedBonus = 0
    if self.purchasedMountSpeedBonus then
        purchasedBonus = self.purchasedMountSpeedBonus
        table.insert(breakdown, {
            source = L["SHOP_PURCHASED"] or "Shop Purchased",
            bonus = purchasedBonus,
            earned = true,
            isPurchased = true,
        })
    end
    
    return {
        breakdown = breakdown,
        naturalBonus = naturalBonus,
        purchasedBonus = purchasedBonus,
        totalBonus = naturalBonus + purchasedBonus,
    }
end

function DC:GetTotalMountSpeedBonus()
    return self.mountSpeedBonus or 0
end

-- ============================================================================
-- BONUS UI TOOLTIP
-- ============================================================================

function DC:ShowMountSpeedTooltip(anchor)
    GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L["MOUNT_SPEED_BONUS"] or "Mount Speed Bonus", 1, 1, 1)
    GameTooltip:AddLine(" ")
    
    local data = self:GetMountSpeedBreakdown()
    
    for _, entry in ipairs(data.breakdown) do
        local statusText
        if entry.isPurchased then
            statusText = "|cff00ff00" .. L["PURCHASED"] or "Purchased" .. "|r"
        elseif entry.earned then
            statusText = "|cff00ff00" .. L["EARNED"] or "Earned" .. "|r"
        else
            statusText = string.format("|cffff9900%d/%d|r", entry.current or 0, entry.required)
        end
        
        local bonusColor = entry.earned and "|cff00ff00" or "|cff888888"
        GameTooltip:AddDoubleLine(
            entry.source,
            bonusColor .. "+" .. entry.bonus .. "%" .. "|r  " .. statusText
        )
    end
    
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine(
        L["TOTAL"] or "Total:",
        "|cff00ff00+" .. data.totalBonus .. "%|r",
        1, 1, 1
    )
    
    if data.totalBonus < 10 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["COLLECT_MORE_MOUNTS"] or "Collect more mounts to earn additional speed bonuses!", 0.5, 0.5, 0.5, true)
    end
    
    GameTooltip:Show()
end

-- ============================================================================
-- OTHER COLLECTION BONUSES
-- ============================================================================

--[[
    Future expansion: Other bonuses could include:
    - Pet collection bonuses (cosmetic effects?)
    - Toy collection achievements
    - Title count achievements
    - Transmog completion percentage rewards
]]

function DC:GetCollectionBonuses()
    local bonuses = {}
    
    -- Mount speed
    if self.mountSpeedBonus and self.mountSpeedBonus > 0 then
        table.insert(bonuses, {
            type = "mount_speed",
            name = L["MOUNT_SPEED_BONUS"] or "Mount Speed",
            value = "+" .. self.mountSpeedBonus .. "%",
            icon = "Interface\\Icons\\Ability_Mount_RidingHorse",
        })
    end
    
    return bonuses
end

-- ============================================================================
-- BONUS CALCULATION (for display only - server handles actual bonuses)
-- ============================================================================

function DC:CalculateExpectedMountSpeedBonus()
    local mountCount = self.stats.mounts and self.stats.mounts.owned or 0
    local bonus = 0
    
    for _, threshold in ipairs(self.MOUNT_SPEED_THRESHOLDS) do
        if mountCount >= threshold.count then
            bonus = bonus + threshold.bonus
        end
    end
    
    return bonus
end

-- ============================================================================
-- BONUS STATUS DISPLAY
-- ============================================================================

function DC:CreateBonusStatusFrame(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(200, 30)
    
    -- Mount speed icon
    frame.speedIcon = frame:CreateTexture(nil, "ARTWORK")
    frame.speedIcon:SetSize(24, 24)
    frame.speedIcon:SetPoint("LEFT", frame, "LEFT", 0, 0)
    frame.speedIcon:SetTexture("Interface\\Icons\\Ability_Mount_RidingHorse")
    
    -- Speed text
    frame.speedText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.speedText:SetPoint("LEFT", frame.speedIcon, "RIGHT", 5, 0)
    frame.speedText:SetText("+0% Mount Speed")
    
    -- Tooltip on hover
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        DC:ShowMountSpeedTooltip(self)
    end)
    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    return frame
end

function DC:UpdateBonusStatusFrame(frame)
    if not frame then return end
    
    local bonus = self:GetTotalMountSpeedBonus()
    if bonus > 0 then
        frame.speedText:SetText(string.format("|cff00ff00+%d%%|r %s", bonus, L["MOUNT_SPEED"] or "Mount Speed"))
        frame:Show()
    else
        frame:Hide()
    end
end

-- ============================================================================
-- BONUS APPLICATION (CLIENT -> SERVER TRIGGER)
-- ============================================================================

-- Called on PLAYER_LOGIN from Core.lua.
-- In this project, bonuses are applied server-side; the client triggers the
-- server to refresh/apply them by requesting stats/bonuses.
function DC:ApplyMountSpeedBonus()
    if type(self.IsProtocolReady) ~= "function" or not self:IsProtocolReady() then
        return
    end

    if type(self.RequestStats) == "function" then
        self:RequestStats()
    end
    if type(self.RequestBonuses) == "function" then
        self:RequestBonuses()
    end
end
