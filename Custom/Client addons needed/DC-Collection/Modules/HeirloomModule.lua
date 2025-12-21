--[[
    DC-Collection Modules/HeirloomModule.lua
    ========================================
    
    Heirloom collection handling - filtering, display, summoning to bags.
    
    Author: DarkChaos-255
    Version: 1.0.0
]]

local DC = DCCollection
local L = DC.L

-- ============================================================================
-- HEIRLOOM MODULE
-- ============================================================================

local HeirloomModule = {}
DC.HeirloomModule = HeirloomModule

-- ============================================================================
-- SLOT TYPE CONSTANTS
-- ============================================================================

DC.HEIRLOOM_SLOTS = {
    HEAD = 1,
    SHOULDER = 2,
    CHEST = 3,
    LEGS = 4,
    BACK = 5,
    WEAPON = 6,
    TRINKET = 7,
}

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function HeirloomModule:Init()
    DC:Debug("HeirloomModule initialized")
end

-- ============================================================================
-- HEIRLOOM COLLECTION ACCESS
-- ============================================================================

function HeirloomModule:GetHeirlooms()
    return DC.collections.heirlooms or {}
end

function HeirloomModule:GetHeirloomDefinitions()
    return DC.definitions.heirlooms or {}
end

function HeirloomModule:GetHeirloom(itemId)
    return DC.collections.heirlooms and DC.collections.heirlooms[itemId]
end

function HeirloomModule:GetHeirloomDefinition(itemId)
    return DC.definitions.heirlooms and DC.definitions.heirlooms[itemId]
end

function HeirloomModule:IsHeirloomCollected(itemId)
    return DC.collections.heirlooms and DC.collections.heirlooms[itemId] ~= nil
end

-- ============================================================================
-- FILTERING
-- ============================================================================

function HeirloomModule:GetFilteredHeirlooms(filters)
    filters = filters or {}
    local results = {}
    
    local definitions = self:GetHeirloomDefinitions()
    local collection = self:GetHeirlooms()
    
    for itemId, def in pairs(definitions) do
        local collected = collection[itemId] ~= nil
        local collData = collection[itemId]
        
        local include = true
        
        if filters.collected ~= nil then
            if filters.collected and not collected then include = false end
            if not filters.collected and collected then include = false end
        end
        
        if filters.rarity and def.rarity ~= filters.rarity then
            include = false
        end
        
        if filters.slotType and def.slotType ~= filters.slotType then
            include = false
        end
        
        if filters.favoritesOnly and (not collData or not collData.is_favorite) then
            include = false
        end
        
        if filters.search and filters.search ~= "" then
            local searchLower = string.lower(filters.search)
            local nameLower = string.lower(def.name or "")
            if not string.find(nameLower, searchLower, 1, true) then
                include = false
            end
        end
        
        if include then
            table.insert(results, {
                id = itemId,
                name = def.name,
                icon = def.icon,
                rarity = def.rarity,
                slotType = def.slotType,
                source = def.source,
                collected = collected,
                is_favorite = collData and collData.is_favorite,
                upgrade_level = collData and collData.upgrade_level or 0,
                definition = def,
            })
        end
    end
    
    return results
end

-- ============================================================================
-- HEIRLOOM ACTIONS
-- ============================================================================

function HeirloomModule:SummonHeirloom(itemId)
    if not itemId then
        DC:Print(L["ERR_NO_HEIRLOOM"] or "No heirloom specified")
        return
    end
    
    if not self:IsHeirloomCollected(itemId) then
        DC:Print(L["ERR_NOT_OWNED"])
        return
    end
    
    DC:RequestSummonHeirloom(itemId)
end

-- ============================================================================
-- FAVORITES
-- ============================================================================

function HeirloomModule:ToggleFavorite(itemId)
    DC:RequestToggleFavorite("heirlooms", itemId)
end

function HeirloomModule:GetFavorites()
    return self:GetFilteredHeirlooms({ favoritesOnly = true })
end

-- ============================================================================
-- STATISTICS
-- ============================================================================

function HeirloomModule:GetStats()
    local owned = 0
    local total = 0
    local bySlot = {}
    
    local definitions = self:GetHeirloomDefinitions()
    local collection = self:GetHeirlooms()
    
    for itemId, def in pairs(definitions) do
        total = total + 1
        
        local slot = def.slotType or 0
        bySlot[slot] = bySlot[slot] or { owned = 0, total = 0 }
        bySlot[slot].total = bySlot[slot].total + 1
        
        if collection[itemId] then
            owned = owned + 1
            bySlot[slot].owned = bySlot[slot].owned + 1
        end
    end
    
    return {
        owned = owned,
        total = total,
        percentage = total > 0 and math.floor((owned / total) * 100) or 0,
        bySlot = bySlot,
    }
end

-- ============================================================================
-- UPGRADE LEVELS
-- ============================================================================

function HeirloomModule:GetUpgradeLevel(itemId)
    local collData = self:GetHeirloom(itemId)
    return collData and collData.upgrade_level or 0
end

function HeirloomModule:GetMaxLevel(itemId)
    local def = self:GetHeirloomDefinition(itemId)
    return def and def.maxLevel or 80
end
