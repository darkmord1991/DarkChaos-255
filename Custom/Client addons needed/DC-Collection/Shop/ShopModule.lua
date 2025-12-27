--[[
    DC-Collection Shop/ShopModule.lua
    ==================================
    
    Collection Shop system - browse and purchase items with collection currency.
    
    Author: DarkChaos-255
    Version: 1.0.0
]]

local DC = DCCollection
local L = DC.L

-- ============================================================================
-- SHOP MODULE
-- ============================================================================

local ShopModule = {}
DC.ShopModule = ShopModule

-- ============================================================================
-- SHOP ITEM TYPES
-- ============================================================================

DC.SHOP_ITEM_TYPES = {
    BONUS = 1,       -- Speed bonuses, passive effects
    MOUNT = 2,       -- Purchasable mounts
    PET = 3,         -- Purchasable pets
    HEIRLOOM = 5,    -- Purchasable heirlooms
    BUNDLE = 6,      -- Bundle of multiple items
    CONSUMABLE = 7,  -- One-time use items
}

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function ShopModule:Init()
    DC:Debug("ShopModule initialized")
end

-- ============================================================================
-- SHOP DATA ACCESS
-- ============================================================================

function ShopModule:GetShopItems()
    return DC.shopItems or {}
end

function ShopModule:GetShopItem(shopItemId)
    local items = self:GetShopItems()
    for _, item in ipairs(items) do
        if item.id == shopItemId then
            return item
        end
    end
    return nil
end

function ShopModule:RefreshShopItems()
    DC:RequestShopItems()
end

-- ============================================================================
-- FILTERING
-- ============================================================================

function ShopModule:GetFilteredShopItems(filters)
    filters = filters or {}
    local results = {}
    
    local items = self:GetShopItems()
    
    for _, item in ipairs(items) do
        local include = true
        
        -- Type filter
        if filters.itemType and item.itemType ~= filters.itemType then
            include = false
        end
        
        -- Affordability filter
        if filters.affordable then
            if not self:CanAfford(item) then
                include = false
            end
        end
        
        -- Already purchased filter (for one-time items)
        if filters.notPurchased and item.purchased then
            include = false
        end
        
        -- Search filter
        if filters.search and filters.search ~= "" then
            local searchLower = string.lower(filters.search)
            local nameLower = string.lower(item.name or "")
            if not string.find(nameLower, searchLower, 1, true) then
                include = false
            end
        end
        
        if include then
            table.insert(results, item)
        end
    end
    
    -- Sort by type, then by cost
    table.sort(results, function(a, b)
        if a.itemType ~= b.itemType then
            return a.itemType < b.itemType
        end
        return (a.costTokens or 0) < (b.costTokens or 0)
    end)
    
    return results
end

-- ============================================================================
-- CURRENCY
-- ============================================================================

function ShopModule:GetTokens()
    local tokens = (type(DC.GetCurrencyBalances) == "function") and select(1, DC:GetCurrencyBalances()) or nil
    return tonumber(tokens) or (DC.currency and DC.currency.tokens) or 0
end

function ShopModule:GetEmblems()
    local _, essence = (type(DC.GetCurrencyBalances) == "function") and DC:GetCurrencyBalances() or nil
    return tonumber(essence) or (DC.currency and DC.currency.emblems) or 0
end

function ShopModule:CanAfford(item)
    if not item then return false end
    
    local tokens = self:GetTokens()
    local emblems = self:GetEmblems()
    
    local costTokens = item.costTokens or 0
    local costEmblems = item.costEmblems or 0
    
    return tokens >= costTokens and emblems >= costEmblems
end

function ShopModule:RefreshCurrency()
    DC:RequestCurrency()
end

-- ============================================================================
-- PURCHASING
-- ============================================================================

function ShopModule:Purchase(shopItemId)
    local item = self:GetShopItem(shopItemId)
    if not item then
        DC:Print(L["ERR_ITEM_NOT_FOUND"] or "Item not found in shop")
        return false
    end
    
    if not self:CanAfford(item) then
        DC:Print(L["ERR_NOT_ENOUGH_CURRENCY"] or "Not enough currency")
        return false
    end
    
    if item.maxPurchases and item.purchaseCount >= item.maxPurchases then
        DC:Print(L["ERR_ALREADY_PURCHASED"] or "Already purchased maximum amount")
        return false
    end
    
    DC:RequestShopPurchase(shopItemId)
    return true
end

-- ============================================================================
-- SHOP ITEM INFO
-- ============================================================================

function ShopModule:GetItemTypeString(itemType)
    local typeStrings = {
        [1] = L["SHOP_TYPE_BONUS"] or "Bonus",
        [2] = L["SHOP_TYPE_MOUNT"] or "Mount",
        [3] = L["SHOP_TYPE_PET"] or "Pet",
        [5] = L["SHOP_TYPE_HEIRLOOM"] or "Heirloom",
        [6] = L["SHOP_TYPE_BUNDLE"] or "Bundle",
        [7] = L["SHOP_TYPE_CONSUMABLE"] or "Consumable",
    }
    return typeStrings[itemType] or "Unknown"
end

function ShopModule:FormatCost(item)
    local parts = {}
    
    if item.costTokens and item.costTokens > 0 then
        table.insert(parts, item.costTokens .. " " .. (L["TOKENS"] or "Tokens"))
    end
    
    if item.costEmblems and item.costEmblems > 0 then
        table.insert(parts, item.costEmblems .. " " .. (L["EMBLEMS"] or "Emblems"))
    end
    
    if #parts == 0 then
        return L["FREE"] or "Free"
    end
    
    return table.concat(parts, " + ")
end

-- ============================================================================
-- FEATURED/SALES
-- ============================================================================

function ShopModule:GetFeaturedItems()
    local items = self:GetShopItems()
    local featured = {}
    
    for _, item in ipairs(items) do
        if item.isFeatured then
            table.insert(featured, item)
        end
    end
    
    return featured
end

function ShopModule:GetSaleItems()
    local items = self:GetShopItems()
    local onSale = {}
    
    for _, item in ipairs(items) do
        if item.discount and item.discount > 0 then
            table.insert(onSale, item)
        end
    end
    
    return onSale
end

-- ============================================================================
-- PURCHASE HISTORY
-- ============================================================================

function ShopModule:GetPurchaseHistory()
    return DC.purchaseHistory or {}
end
