--[[
    DC-Collection Modules/TransmogModule.lua
    ========================================
    
    Transmog appearance collection handling.
    Note: Requires mod_transmog or similar transmogrification module.
    
    Author: DarkChaos-255
    Version: 1.0.0
]]

local DC = DCCollection
local L = DC.L

-- ============================================================================
-- TRANSMOG MODULE
-- ============================================================================

local TransmogModule = {}
DC.TransmogModule = TransmogModule

-- ============================================================================
-- SLOT CONSTANTS
-- ============================================================================

DC.TRANSMOG_SLOTS = {
    HEAD = 1,
    SHOULDER = 3,
    SHIRT = 4,
    CHEST = 5,
    WAIST = 6,
    LEGS = 7,
    FEET = 8,
    WRIST = 9,
    HANDS = 10,
    BACK = 15,
    MAIN_HAND = 16,
    OFF_HAND = 17,
    RANGED = 18,
    TABARD = 19,
}

local SLOT_NAMES = {
    [1] = "Head",
    [3] = "Shoulder",
    [4] = "Shirt",
    [5] = "Chest",
    [6] = "Waist",
    [7] = "Legs",
    [8] = "Feet",
    [9] = "Wrist",
    [10] = "Hands",
    [15] = "Back",
    [16] = "Main Hand",
    [17] = "Off Hand",
    [18] = "Ranged",
    [19] = "Tabard",
}

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function TransmogModule:Init()
    DC:Debug("TransmogModule initialized")
end

-- ============================================================================
-- TRANSMOG COLLECTION ACCESS
-- ============================================================================

function TransmogModule:GetAppearances()
    return DC.collections.transmog or {}
end

function TransmogModule:GetAppearanceDefinitions()
    return DC.definitions.transmog or {}
end

function TransmogModule:GetAppearance(appearanceId)
    return DC.collections.transmog and DC.collections.transmog[appearanceId]
end

function TransmogModule:GetAppearanceDefinition(appearanceId)
    return DC.definitions.transmog and DC.definitions.transmog[appearanceId]
end

function TransmogModule:IsAppearanceCollected(appearanceId)
    return DC.collections.transmog and DC.collections.transmog[appearanceId] ~= nil
end

-- ============================================================================
-- FILTERING
-- ============================================================================

function TransmogModule:GetFilteredAppearances(filters)
    filters = filters or {}
    local results = {}
    
    local definitions = self:GetAppearanceDefinitions()
    local collection = self:GetAppearances()
    
    for appearanceId, def in pairs(definitions) do
        local collected = collection[appearanceId] ~= nil
        local collData = collection[appearanceId]
        
        local include = true
        
        if filters.collected ~= nil then
            if filters.collected and not collected then include = false end
            if not filters.collected and collected then include = false end
        end
        
        if filters.slot and def.inventoryType ~= filters.slot then
            include = false
        end
        
        if filters.armorType and def.armorType ~= filters.armorType then
            include = false
        end
        
        if filters.weaponType and def.weaponType ~= filters.weaponType then
            include = false
        end
        
        if filters.rarity and def.rarity ~= filters.rarity then
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
                id = appearanceId,
                itemId = def.itemId,
                name = def.name,
                icon = def.icon,
                rarity = def.rarity,
                slot = def.inventoryType,
                armorType = def.armorType,
                weaponType = def.weaponType,
                source = def.source,
                collected = collected,
                is_favorite = collData and collData.is_favorite,
                definition = def,
            })
        end
    end
    
    return results
end

-- ============================================================================
-- FAVORITES
-- ============================================================================

function TransmogModule:ToggleFavorite(appearanceId)
    DC:RequestToggleFavorite("transmog", appearanceId)
end

function TransmogModule:GetFavorites()
    return self:GetFilteredAppearances({ favoritesOnly = true })
end

-- ============================================================================
-- STATISTICS
-- ============================================================================

function TransmogModule:GetStats()
    local owned = 0
    local total = 0
    local bySlot = {}
    
    local definitions = self:GetAppearanceDefinitions()
    local collection = self:GetAppearances()
    
    for appearanceId, def in pairs(definitions) do
        total = total + 1
        
        local slot = def.inventoryType or 0
        bySlot[slot] = bySlot[slot] or { owned = 0, total = 0 }
        bySlot[slot].total = bySlot[slot].total + 1
        
        if collection[appearanceId] then
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
-- SLOT UTILITIES
-- ============================================================================

function TransmogModule:GetSlotName(slotId)
    return SLOT_NAMES[slotId] or "Unknown"
end

function TransmogModule:GetSlots()
    return DC.TRANSMOG_SLOTS
end

-- ============================================================================
-- ITEM SOURCES FOR APPEARANCES
-- ============================================================================

function TransmogModule:GetSourceItems(appearanceId)
    local def = self:GetAppearanceDefinition(appearanceId)
    if def and def.sourceItems then
        return def.sourceItems
    end
    return {}
end

-- Returns the primary item that unlocks this appearance
function TransmogModule:GetPrimarySourceItem(appearanceId)
    local def = self:GetAppearanceDefinition(appearanceId)
    return def and def.itemId
end
