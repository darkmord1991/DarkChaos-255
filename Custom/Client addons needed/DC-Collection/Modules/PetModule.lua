--[[
    DC-Collection Modules/PetModule.lua
    ====================================
    
    Companion pet collection handling - filtering, display, summoning.
    
    Author: DarkChaos-255
    Version: 1.0.0
]]

local DC = DCCollection
local L = DC.L

-- ============================================================================
-- PET MODULE
-- ============================================================================

local PetModule = {}
DC.PetModule = PetModule

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function PetModule:Init()
    DC:Debug("PetModule initialized")
end

-- ============================================================================
-- PET COLLECTION ACCESS
-- ============================================================================

function PetModule:GetPets()
    return DC.collections.pets or {}
end

function PetModule:GetPetDefinitions()
    return DC.definitions.pets or {}
end

function PetModule:GetPet(spellId)
    return DC.collections.pets and DC.collections.pets[spellId]
end

function PetModule:GetPetDefinition(spellId)
    return DC.definitions.pets and DC.definitions.pets[spellId]
end

function PetModule:IsPetCollected(spellId)
    return DC.collections.pets and DC.collections.pets[spellId] ~= nil
end

-- ============================================================================
-- FILTERING
-- ============================================================================

function PetModule:GetFilteredPets(filters)
    filters = filters or {}
    local results = {}
    
    local definitions = self:GetPetDefinitions()
    local collection = self:GetPets()
    
    for spellId, def in pairs(definitions) do
        local collected = collection[spellId] ~= nil
        local collData = collection[spellId]
        
        local include = true
        
        -- Collected filter
        if filters.collected ~= nil then
            if filters.collected and not collected then include = false end
            if not filters.collected and collected then include = false end
        end
        
        -- Rarity filter
        if filters.rarity and def.rarity ~= filters.rarity then
            include = false
        end
        
        -- Favorites only
        if filters.favoritesOnly and (not collData or not collData.is_favorite) then
            include = false
        end
        
        -- Search filter
        if filters.search and filters.search ~= "" then
            local searchLower = string.lower(filters.search)
            local nameLower = string.lower(def.name or "")
            if not string.find(nameLower, searchLower, 1, true) then
                include = false
            end
        end
        
        -- Source filter
        if filters.source and filters.source ~= "" then
            local sourceText = DC:FormatSource(def.source)
            if sourceText ~= filters.source then
                include = false
            end
        end
        
        if include then
            table.insert(results, {
                id = spellId,
                name = def.name,
                icon = def.icon,
                rarity = def.rarity,
                source = def.source,
                collected = collected,
                is_favorite = collData and collData.is_favorite,
                times_used = collData and collData.times_used or 0,
                definition = def,
            })
        end
    end
    
    return results
end

-- ============================================================================
-- PET ACTIONS
-- ============================================================================

function PetModule:SummonPet(spellId)
    if not spellId then
        DC:Print(L["ERR_NO_PET"] or "No pet specified")
        return
    end
    
    if not self:IsPetCollected(spellId) then
        DC:Print(L["ERR_NOT_OWNED"])
        return
    end
    
    DC:RequestSummonPet(spellId, false)
end

function PetModule:SummonRandomPet()
    DC:RequestSummonPet(nil, true)
end

function PetModule:SummonRandomFavoritePet()
    local favorites = self:GetFilteredPets({ favoritesOnly = true })
    
    if #favorites == 0 then
        DC:Print(L["ERR_NO_FAVORITES"])
        return
    end
    
    local pet = favorites[math.random(#favorites)]
    self:SummonPet(pet.id)
end

function PetModule:DismissPet()
    -- Dismiss current companion
    DismissCompanion("CRITTER")
end

-- ============================================================================
-- FAVORITES
-- ============================================================================

function PetModule:ToggleFavorite(spellId)
    DC:RequestToggleFavorite("pets", spellId)
end

function PetModule:GetFavorites()
    return self:GetFilteredPets({ favoritesOnly = true })
end

-- ============================================================================
-- STATISTICS
-- ============================================================================

function PetModule:GetStats()
    local owned = 0
    local total = 0
    local byRarity = {}
    
    local definitions = self:GetPetDefinitions()
    local collection = self:GetPets()
    
    for spellId, def in pairs(definitions) do
        total = total + 1
        
        if collection[spellId] then
            owned = owned + 1
        end
        
        local rarity = def.rarity or 1
        byRarity[rarity] = byRarity[rarity] or { owned = 0, total = 0 }
        byRarity[rarity].total = byRarity[rarity].total + 1
        if collection[spellId] then
            byRarity[rarity].owned = byRarity[rarity].owned + 1
        end
    end
    
    return {
        owned = owned,
        total = total,
        percentage = total > 0 and math.floor((owned / total) * 100) or 0,
        byRarity = byRarity,
    }
end

-- ============================================================================
-- CLIENT PET DETECTION
-- ============================================================================

function PetModule:ScanKnownPets()
    local knownPets = {}
    
    local numPets = GetNumCompanions("CRITTER")
    for i = 1, numPets do
        local creatureID, creatureName, spellID, icon, active = GetCompanionInfo("CRITTER", i)
        if spellID then
            knownPets[spellID] = {
                name = creatureName,
                icon = icon,
                spellId = spellID,
                creatureId = creatureID,
            }
        end
    end
    
    return knownPets
end

-- When the server has no pet definitions table (or returns an empty set),
-- fall back to the client spellbook companion list so the Pets tab isn't empty.
function PetModule:SeedFromClientKnownPets()
    local pets = self:ScanKnownPets()
    if not pets or next(pets) == nil then
        return false
    end

    DC.definitions.pets = DC.definitions.pets or {}
    DC.collections.pets = DC.collections.pets or {}

    local changed = false
    for spellId, data in pairs(pets) do
        if spellId then
            if not DC.definitions.pets[spellId] then
                DC.definitions.pets[spellId] = {
                    name = data.name,
                    icon = data.icon,
                }
                changed = true
            end
            if not DC.collections.pets[spellId] then
                DC.collections.pets[spellId] = { owned = true }
                changed = true
            end
        end
    end

    if changed then
        if DC.stats and DC.stats.pets then
            if type(DC.CountDefinitions) == "function" then
                DC.stats.pets.total = DC:CountDefinitions("pets")
            end
            if type(DC.CountCollection) == "function" then
                DC.stats.pets.owned = DC:CountCollection("pets")
            end
        end
        if type(DC.SaveCache) == "function" then
            DC:SaveCache()
        end
    end

    return changed
end

-- ============================================================================
-- INTEGRATION
-- ============================================================================

function PetModule:OnPetLearned(spellId)
    if not DC.collections.pets[spellId] then
        DC.collections.pets[spellId] = {
            obtained_date = time(),
            is_favorite = false,
            times_used = 0,
        }
        DC:Debug("Pet learned: " .. spellId)
        
        if not DC.definitions.pets[spellId] then
            DC:RequestDefinitions("pets")
        end
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("COMPANION_LEARNED")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "COMPANION_LEARNED" then
        local pets = PetModule:ScanKnownPets()
        for spellId, data in pairs(pets) do
            PetModule:OnPetLearned(spellId)
        end
    end
end)
