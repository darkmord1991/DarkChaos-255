--[[
    DC-Collection Modules/MountModule.lua
    =====================================
    
    Mount collection handling - filtering, display, summoning.
    
    Author: DarkChaos-255
    Version: 1.0.0
]]

local DC = DCCollection
local L = DC.L

-- ============================================================================
-- MOUNT TYPE CONSTANTS
-- ============================================================================

DC.MOUNT_TYPES = {
    GROUND = 1,
    FLYING = 2,
    AQUATIC = 3,
}

local MOUNT_TYPE_NAMES = {
    [1] = "Ground",
    [2] = "Flying", 
    [3] = "Aquatic",
}

-- ============================================================================
-- MOUNT MODULE
-- ============================================================================

local MountModule = {}
DC.MountModule = MountModule

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function MountModule:Init()
    -- Initialize mount-specific data
    DC:Debug("MountModule initialized")
end

-- ============================================================================
-- MOUNT COLLECTION ACCESS
-- ============================================================================

function MountModule:GetMounts()
    return DC.collections.mounts or {}
end

function MountModule:GetMountDefinitions()
    return DC.definitions.mounts or {}
end

function MountModule:GetMount(spellId)
    return DC.collections.mounts and DC.collections.mounts[spellId]
end

function MountModule:GetMountDefinition(spellId)
    return DC.definitions.mounts and DC.definitions.mounts[spellId]
end

function MountModule:IsMountCollected(spellId)
    return DC.collections.mounts and DC.collections.mounts[spellId] ~= nil
end

-- ============================================================================
-- FILTERING
-- ============================================================================

function MountModule:GetFilteredMounts(filters)
    filters = filters or {}
    local results = {}
    
    local definitions = self:GetMountDefinitions()
    local collection = self:GetMounts()
    
    for spellId, def in pairs(definitions) do
        local collected = collection[spellId] ~= nil
        local collData = collection[spellId]
        
        -- Apply filters
        local include = true
        
        -- Collected filter
        if filters.collected ~= nil then
            if filters.collected and not collected then include = false end
            if not filters.collected and collected then include = false end
        end
        
        -- Mount type filter
        if filters.mountType and def.mountType ~= filters.mountType then
            include = false
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
        if filters.source and def.source ~= filters.source then
            include = false
        end
        
        if include then
            table.insert(results, {
                id = spellId,
                name = def.name,
                icon = def.icon,
                rarity = def.rarity,
                mountType = def.mountType,
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
-- MOUNT ACTIONS
-- ============================================================================

function MountModule:SummonMount(spellId)
    if not spellId then
        DC:Print(L["ERR_NO_MOUNT"])
        return
    end
    
    if not self:IsMountCollected(spellId) then
        DC:Print(L["ERR_NOT_OWNED"])
        return
    end
    
    DC:RequestSummonMount(spellId, false)
end

function MountModule:SummonRandomMount(mountType)
    DC:RequestSummonMount(nil, true)
end

function MountModule:SummonRandomFavoriteMount()
    -- Get favorite mounts
    local favorites = self:GetFilteredMounts({ favoritesOnly = true })
    
    if #favorites == 0 then
        DC:Print(L["ERR_NO_FAVORITES"])
        return
    end
    
    -- Pick random
    local mount = favorites[math.random(#favorites)]
    self:SummonMount(mount.id)
end

function MountModule:DismissMount()
    -- In 3.3.5a, dismissing is done by recasting or right-clicking buff
    -- Server will handle dismount when a new mount is summoned
end

-- ============================================================================
-- FAVORITES
-- ============================================================================

function MountModule:ToggleFavorite(spellId)
    DC:RequestToggleFavorite("mounts", spellId)
end

function MountModule:GetFavorites()
    return self:GetFilteredMounts({ favoritesOnly = true })
end

-- ============================================================================
-- STATISTICS
-- ============================================================================

function MountModule:GetStats()
    local owned = 0
    local total = 0
    local byType = { [1] = 0, [2] = 0, [3] = 0 }
    local byRarity = {}
    
    local definitions = self:GetMountDefinitions()
    local collection = self:GetMounts()
    
    for spellId, def in pairs(definitions) do
        total = total + 1
        
        if collection[spellId] then
            owned = owned + 1
            
            local mType = def.mountType or 1
            byType[mType] = (byType[mType] or 0) + 1
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
        byType = byType,
        byRarity = byRarity,
    }
end

-- ============================================================================
-- MOUNT SOURCES
-- ============================================================================

function MountModule:GetSources()
    local sources = {}
    local definitions = self:GetMountDefinitions()
    
    for _, def in pairs(definitions) do
        if def.source and not sources[def.source] then
            sources[def.source] = true
        end
    end
    
    local result = {}
    for source in pairs(sources) do
        table.insert(result, source)
    end
    table.sort(result)
    
    return result
end

-- ============================================================================
-- MOUNT SPEED BONUS
-- ============================================================================

function MountModule:GetSpeedBonus()
    return DC.mountSpeedBonus or 0
end

function MountModule:CalculateEffectiveSpeed(baseSpeed)
    local bonus = self:GetSpeedBonus()
    return baseSpeed * (1 + bonus / 100)
end

-- ============================================================================
-- CLIENT MOUNT DETECTION
-- ============================================================================

-- Detect mounts the player knows natively (via spellbook)
-- Used for initial population before server sync
function MountModule:ScanKnownMounts()
    local knownMounts = {}
    
    -- Check companion mount spells
    local numMounts = GetNumCompanions("MOUNT")
    for i = 1, numMounts do
        local creatureID, creatureName, spellID, icon, active = GetCompanionInfo("MOUNT", i)
        if spellID then
            knownMounts[spellID] = {
                name = creatureName,
                icon = icon,
                spellId = spellID,
                creatureId = creatureID,
            }
        end
    end
    
    return knownMounts
end

-- ============================================================================
-- INTEGRATION
-- ============================================================================

-- Called when a mount is learned (from COMPANION_LEARNED event)
function MountModule:OnMountLearned(spellId)
    -- Update local cache
    if not DC.collections.mounts[spellId] then
        DC.collections.mounts[spellId] = {
            obtained_date = time(),
            is_favorite = false,
            times_used = 0,
        }
        DC:Debug("Mount learned: " .. spellId)
        
        -- Request full definition from server if not cached
        if not DC.definitions.mounts[spellId] then
            DC:RequestDefinitions("mounts")
        end
    end
end

-- Register for mount-related events
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("COMPANION_LEARNED")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "COMPANION_LEARNED" then
        -- Scan for new mounts
        local mounts = MountModule:ScanKnownMounts()
        for spellId, data in pairs(mounts) do
            MountModule:OnMountLearned(spellId)
        end
    end
end)
