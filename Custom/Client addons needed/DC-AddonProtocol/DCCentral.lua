--[[
    DC-Central: Token/Essence Information and Shared Utilities
    
    Contains centralized functions for token/essence currency management,
    shared tooltip frame, and keystone item registry.
    
    This module extends DCAddonProtocol with token information functions.
    It is automatically loaded as part of the DC-AddonProtocol addon.
    
    Version: 1.0.0
    Date: December 2025
]]

-- Ensure DCAddonProtocol is loaded first
if not DCAddonProtocol then
    error("DCCentral: DCAddonProtocol must be loaded first")
    return
end

local DC = DCAddonProtocol

-- ============================================================================
-- Token and Essence Information (Seasonal Currency)
-- ============================================================================

--- Token item ID: Upgrade Token for item upgrade UI
DC.TOKEN_ITEM_ID = 300311

--- Essence item ID: Upgrade Essence for heirloom upgrades
DC.ESSENCE_ITEM_ID = 300312

--- Token information lookup table
DC.TokenInfo = {
    [300311] = {
        id = 300311,
        name = "Upgrade Token",
        icon = "Interface\\Icons\\INV_Misc_Token_ArgentCrusade",
        rarity = 2,  -- Uncommon (green)
        type = "upgrade_token",
        description = "Used to upgrade regular items"
    },
    [300312] = {
        id = 300312,
        name = "Upgrade Essence",
        icon = "Interface\\Icons\\INV_Misc_Herb_Draenethisle",
        rarity = 3,  -- Rare (blue)
        type = "upgrade_essence",
        description = "Used to upgrade heirloom items"
    }
}

--- Keystone item IDs (M+2 through M+20): mirror server constants
DC.KEYSTONE_ITEM_IDS = {
    [300313] = true, [300314] = true, [300315] = true, [300316] = true, [300317] = true,
    [300318] = true, [300319] = true, [300320] = true, [300321] = true, [300322] = true,
    [300323] = true, [300324] = true, [300325] = true, [300326] = true, [300327] = true,
    [300328] = true, [300329] = true, [300330] = true, [300331] = true,
}

-- ============================================================================
-- Optional server-reported currency balance
-- ============================================================================

-- Some addons (e.g. DC-Collection) receive currency from the server via addon
-- messages rather than actual item counts. Store that here so UIs can display
-- consistent values.
DC.ServerCurrencyBalance = DC.ServerCurrencyBalance or {
    tokens = 0,
    emblems = 0,
    byItemId = {},
    updatedAt = nil,
}

--- Update currency balances as reported by the server.
--- @param tokens number
--- @param emblems number
function DC:SetServerCurrencyBalance(tokens, emblems)
    tokens = tonumber(tokens) or 0
    emblems = tonumber(emblems) or 0

    self.ServerCurrencyBalance.tokens = tokens
    self.ServerCurrencyBalance.emblems = emblems
    self.ServerCurrencyBalance.byItemId[self.TOKEN_ITEM_ID] = tokens
    self.ServerCurrencyBalance.byItemId[self.ESSENCE_ITEM_ID] = emblems
    self.ServerCurrencyBalance.updatedAt = time and time() or nil
end

--- Get last server-reported currency balances.
--- @return table
function DC:GetServerCurrencyBalance()
    return self.ServerCurrencyBalance
end

-- ============================================================================
-- Token and Essence Functions
-- ============================================================================

--- Get token/essence information by item ID
--- @param itemID number Item ID to look up
--- @return table|nil Token info table or nil if not found
function DC:GetTokenInfo(itemID)
    return self.TokenInfo[itemID] or nil
end

--- Check if an item is a token or essence
--- @param itemID number Item ID to check
--- @return boolean True if item is a token/essence
function DC:IsTokenItem(itemID)
    return self.TokenInfo[itemID] ~= nil
end

--- Get the name of a token item
--- @param itemID number Item ID
--- @return string|nil Token name or nil
function DC:GetTokenName(itemID)
    local info = self:GetTokenInfo(itemID)
    return info and info.name or nil
end

--- Get the icon path for a token item
--- @param itemID number Item ID
--- @return string|nil Icon path or nil
function DC:GetTokenIcon(itemID)
    local info = self:GetTokenInfo(itemID)
    return info and info.icon or nil
end

--- Get all token item IDs
--- @return table Array of token item IDs
function DC:GetTokenItemIDs()
    local ids = {}
    for id in pairs(self.TokenInfo) do
        table.insert(ids, id)
    end
    return ids
end

--- Get player's total token count
--- @param itemID number|nil Specific token ID, or nil for all tokens
--- @return number Total count
function DC:GetPlayerTokenCount(itemID)
    if itemID then
        local bal = self.ServerCurrencyBalance
        if bal and bal.byItemId and bal.byItemId[itemID] ~= nil then
            return bal.byItemId[itemID] or 0
        end
        return GetItemCount(itemID) or 0
    else
        local total = 0
        for id in pairs(self.TokenInfo) do
            total = total + (self:GetPlayerTokenCount(id) or 0)
        end
        return total
    end
end

--- Create a formatted token display string
--- @param itemID number Token item ID
--- @param count number Token count
--- @param colorCode string|nil Color code prefix (e.g., "|cffff8000")
--- @return string Formatted display string
function DC:FormatTokenDisplay(itemID, count, colorCode)
    local info = self:GetTokenInfo(itemID)
    if not info then return "" end
    
    colorCode = colorCode or "|cffffffff"  -- White default
    local endColor = "|r"
    
    return colorCode .. (count or 0) .. " " .. info.name .. endColor
end

--- Create an inline token icon with count
--- @param itemID number Token item ID
--- @param count number|nil Token count (optional)
--- @return string Formatted string with icon and optional count
function DC:FormatTokenWithIcon(itemID, count)
    local info = self:GetTokenInfo(itemID)
    if not info then return "" end
    
    local iconStr = "\124T" .. info.icon .. ":16:16:0:0:64:64:4:60:4:60\124t"
    if count then
        return iconStr .. " " .. count
    else
        return iconStr
    end
end

--- Get token info for both regular and essence tokens
--- @return table Object with token and essence info
function DC:GetCurrencyInfo()
    return {
        token = {
            id = self.TOKEN_ITEM_ID,
            info = self:GetTokenInfo(self.TOKEN_ITEM_ID),
            count = self:GetPlayerTokenCount(self.TOKEN_ITEM_ID)
        },
        essence = {
            id = self.ESSENCE_ITEM_ID,
            info = self:GetTokenInfo(self.ESSENCE_ITEM_ID),
            count = self:GetPlayerTokenCount(self.ESSENCE_ITEM_ID)
        }
    }
end

-- ============================================================================
-- Shared Tooltip Support
-- ============================================================================

-- Create a single shared tooltip for item scanning; created on PLAYER_LOGIN
local tooltipFrame = CreateFrame("Frame")
tooltipFrame:RegisterEvent("PLAYER_LOGIN")
tooltipFrame:SetScript("OnEvent", function(self, event)
    if not DC.scanTooltip then
        DC.scanTooltip = CreateFrame("GameTooltip", "DCScanTooltip", nil, "GameTooltipTemplate")
        DC.scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    end
    -- Set a global alias for backward compatibility
    rawset(_G, "DCScanTooltip", DC.scanTooltip)
end)
