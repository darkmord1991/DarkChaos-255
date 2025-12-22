--[[
    DC-Collection Modules/ToyModule.lua
    ====================================
    
    Toy collection handling - filtering, display, usage.
    
    Author: DarkChaos-255
    Version: 1.0.0
]]

local DC = DCCollection
local L = DC.L

-- ============================================================================
-- TOY MODULE
-- ============================================================================

local ToyModule = {}
DC.ToyModule = ToyModule

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function ToyModule:Init()
    DC:Debug("ToyModule initialized")
end

-- ============================================================================
-- TOY COLLECTION ACCESS
-- ============================================================================

function ToyModule:GetToys()
    return DC.collections.toys or {}
end

function ToyModule:GetToyDefinitions()
    return DC.definitions.toys or {}
end

function ToyModule:GetToy(itemId)
    return DC.collections.toys and DC.collections.toys[itemId]
end

function ToyModule:GetToyDefinition(itemId)
    return DC.definitions.toys and DC.definitions.toys[itemId]
end

function ToyModule:IsToyCollected(itemId)
    return DC.collections.toys and DC.collections.toys[itemId] ~= nil
end

-- ============================================================================
-- FILTERING
-- ============================================================================

function ToyModule:GetFilteredToys(filters)
    filters = filters or {}
    local results = {}
    
    local definitions = self:GetToyDefinitions()
    local collection = self:GetToys()
    
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
        
        if filters.source and filters.source ~= "" then
            local sourceText = DC:FormatSource(def.source)
            if sourceText ~= filters.source then
                include = false
            end
        end
        
        -- Cooldown filter (only usable)
        if filters.usableOnly then
            if collData and collData.lastUsed then
                local cooldown = def.cooldown or 0
                local remaining = (collData.lastUsed + cooldown) - time()
                if remaining > 0 then
                    include = false
                end
            end
        end
        
        if include then
            table.insert(results, {
                id = itemId,
                name = def.name,
                icon = def.icon,
                rarity = def.rarity,
                source = def.source,
                cooldown = def.cooldown,
                collected = collected,
                is_favorite = collData and collData.is_favorite,
                lastUsed = collData and collData.lastUsed,
                definition = def,
            })
        end
    end
    
    return results
end

-- ============================================================================
-- TOY ACTIONS
-- ============================================================================

function ToyModule:UseToy(itemId)
    if not itemId then
        DC:Print(L["ERR_NO_TOY"] or "No toy specified")
        return
    end
    
    if not self:IsToyCollected(itemId) then
        DC:Print(L["ERR_NOT_OWNED"])
        return
    end
    
    -- Check cooldown
    local collData = self:GetToy(itemId)
    local def = self:GetToyDefinition(itemId)
    
    if collData and collData.lastUsed and def and def.cooldown then
        local remaining = (collData.lastUsed + def.cooldown) - time()
        if remaining > 0 then
            DC:Print(string.format(L["ERR_ON_COOLDOWN"], math.ceil(remaining)))
            return
        end
    end
    
    DC:RequestUseToy(itemId)
end

function ToyModule:UseRandomToy()
    local toys = self:GetFilteredToys({ collected = true, usableOnly = true })
    
    if #toys == 0 then
        DC:Print(L["ERR_NO_USABLE_TOYS"] or "No usable toys available")
        return
    end
    
    local toy = toys[math.random(#toys)]
    self:UseToy(toy.id)
end

function ToyModule:GetCooldownRemaining(itemId)
    local collData = self:GetToy(itemId)
    local def = self:GetToyDefinition(itemId)
    
    if not collData or not def or not def.cooldown then
        return 0
    end
    
    if not collData.lastUsed then
        return 0
    end
    
    local remaining = (collData.lastUsed + def.cooldown) - time()
    return math.max(0, remaining)
end

-- ============================================================================
-- FAVORITES
-- ============================================================================

function ToyModule:ToggleFavorite(itemId)
    DC:RequestToggleFavorite("toys", itemId)
end

function ToyModule:GetFavorites()
    return self:GetFilteredToys({ favoritesOnly = true })
end

-- ============================================================================
-- STATISTICS
-- ============================================================================

function ToyModule:GetStats()
    local owned = 0
    local total = 0
    
    local definitions = self:GetToyDefinitions()
    local collection = self:GetToys()
    
    for itemId, def in pairs(definitions) do
        total = total + 1
        if collection[itemId] then
            owned = owned + 1
        end
    end
    
    return {
        owned = owned,
        total = total,
        percentage = total > 0 and math.floor((owned / total) * 100) or 0,
    }
end
