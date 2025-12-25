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

    self._initialized = true

    -- Ensure tables exist.
    DC.definitions = DC.definitions or {}
    DC.collections = DC.collections or {}
    DC.definitions.pets = DC.definitions.pets or {}
    DC.collections.pets = DC.collections.pets or {}

    -- Cache the player's known companions so collected/not-collected works even
    -- when the server doesn't provide (or hasn't yet synced) collection data.
    self:RefreshKnownPetsCache()

    -- If server definitions are missing/empty, seed from client so the Pets UI
    -- isn't empty and owned pets are correctly marked.
    if not next(DC.definitions.pets) then
        -- 1) Try seeding a broad list of companion items (if configured)
        -- 2) Always seed from the player's actually-known companions
        self:SeedFromCompanionItemSeeds()
        self:SeedFromClientKnownPets()
    else
        -- Even with server definitions, make sure client-owned pets are marked owned.
        self:SeedFromClientKnownPets()
    end
end

function PetModule:RefreshKnownPetsCache()
    self._knownPets = self:ScanKnownPets() or {}
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

function PetModule:GetPet(petId)
    return DC.collections.pets and DC.collections.pets[petId]
end

function PetModule:GetPetDefinition(petId)
    return DC.definitions.pets and DC.definitions.pets[petId]
end

local function _num(x)
    if x == nil then return nil end
    if type(x) == "number" then return x end
    if type(x) == "string" then
        local n = tonumber(x)
        return n
    end
    return nil
end

function PetModule:_ResolveSpellIdForDef(def)
    if type(def) ~= "table" then
        return nil
    end

    local existing = _num(def.spellId or def.spell_id)
    if existing then
        return existing
    end

    local itemId = _num(def.itemId or def.item_id)
    if not itemId or type(GetItemSpell) ~= "function" then
        return nil
    end

    -- Cache the result on the definition to avoid repeated lookups during filtering.
    if def._dcResolvedSpellId ~= nil then
        return _num(def._dcResolvedSpellId)
    end

    local _, spellId = GetItemSpell(itemId)
    spellId = _num(spellId)
    def._dcResolvedSpellId = spellId or false

    if spellId then
        def.spellId = def.spellId or spellId
    end

    return spellId
end

function PetModule:_GetCollectionEntryByKey(key)
    if key == nil or not (DC.collections and DC.collections.pets) then
        return nil
    end

    local coll = DC.collections.pets
    if coll[key] ~= nil then
        return coll[key]
    end

    local n = _num(key)
    if n ~= nil and coll[n] ~= nil then
        return coll[n]
    end

    local s = tostring(key)
    if s ~= nil and coll[s] ~= nil then
        return coll[s]
    end

    return nil
end

function PetModule:GetCollectionEntryForPet(petId, def)
    -- Collections may be keyed by itemId, spellId, or creatureId depending on server schema.
    -- Try the common identifiers (and normalize string/number keys).
    local entry = self:_GetCollectionEntryByKey(petId)
    if entry ~= nil then
        return entry
    end

    def = def or self:GetPetDefinition(petId)
    if def then
        entry = self:_GetCollectionEntryByKey(def.itemId or def.item_id)
        if entry ~= nil then return entry end

        -- Prefer explicit spellId; if missing, resolve from itemId if possible.
        entry = self:_GetCollectionEntryByKey(def.spellId or def.spell_id)
        if entry ~= nil then return entry end

        local resolvedSpellId = self:_ResolveSpellIdForDef(def)
        if resolvedSpellId then
            entry = self:_GetCollectionEntryByKey(resolvedSpellId)
            if entry ~= nil then return entry end
        end

        entry = self:_GetCollectionEntryByKey(def.creatureId or def.creature_id)
        if entry ~= nil then return entry end
    end

    return nil
end

function PetModule:IsPetCollected(petId)
    -- 1) If server collection is present, match by any supported key.
    local def = self:GetPetDefinition(petId)
    if self:GetCollectionEntryForPet(petId, def) ~= nil then
        return true
    end

    -- 2) Fallback: detect via client companion list (covers missing/unsynced server collection).
    if def then
        local creatureId = def.creatureId or def.creature_id
        local spellId = def.spellId or def.spell_id

        local creatureN = _num(creatureId)
        local spellN = _num(spellId)
        if not spellN then
            spellN = self:_ResolveSpellIdForDef(def)
        end

        if creatureN and self._knownPetsByCreatureId and self._knownPetsByCreatureId[creatureN] then
            return true
        end
        if spellN and self._knownPetsBySpellId and self._knownPetsBySpellId[spellN] then
            return true
        end
    end

    local petN = _num(petId)
    if petN and self._knownPetsByCreatureId and self._knownPetsByCreatureId[petN] then
        return true
    end
    if petN and self._knownPetsBySpellId and self._knownPetsBySpellId[petN] then
        return true
    end

    return false
end

function PetModule:UsesItemIdKeys()
    local defs = self:GetPetDefinitions()
    for k, def in pairs(defs) do
        local itemId = def and (def.itemId or def.item_id)
        if itemId and tostring(k) == tostring(itemId) then
            return true
        end
    end
    return false
end

-- ============================================================================
-- FILTERING
-- ============================================================================

function PetModule:GetFilteredPets(filters)
    filters = filters or {}
    local results = {}
    
    local definitions = self:GetPetDefinitions()
    local collection = self:GetPets()
    
    local count = 0
    for _ in pairs(definitions) do count = count + 1 end
    -- DC:Debug("GetFilteredPets: definitions count = " .. count)

    for petId, def in pairs(definitions) do
        local collected = self:IsPetCollected(petId)
        local collData = self:GetCollectionEntryForPet(petId, def)
        
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
                id = petId,
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
    
    -- DC:Debug("GetFilteredPets: results count = " .. #results)
    return results
end

-- ============================================================================
-- PET ACTIONS
-- ============================================================================

function PetModule:SummonPet(petId)
    if not petId then
        DC:Print(L["ERR_NO_PET"] or "No pet specified")
        return
    end
    
    if not self:IsPetCollected(petId) then
        DC:Print(L["ERR_NOT_OWNED"])
        return
    end

    -- Prefer client-side summoning on 3.3.5a: the server handler may not support PET use.
    local def = self:GetPetDefinition(petId) or {}
    local spellId = def.spellId or def.spell_id
    local creatureId = def.creatureId or def.creature_id

    if spellId or creatureId then
        local num = GetNumCompanions("CRITTER")
        for i = 1, num do
            local cID, _, sID = GetCompanionInfo("CRITTER", i)
            if (spellId and sID == spellId) or (creatureId and cID == creatureId) then
                CallCompanion("CRITTER", i)
                return
            end
        end
    end

    -- Fallback: try the server request path.
    if DC and DC.RequestSummonPet then
        DC:RequestSummonPet(petId, false)
    end
end

function PetModule:SummonRandomPet()
    local num = GetNumCompanions and GetNumCompanions("CRITTER") or 0
    if num and num > 0 and CallCompanion then
        CallCompanion("CRITTER", math.random(1, num))
        return
    end

    if DC and DC.RequestSummonPet then
        DC:RequestSummonPet(nil, true)
    end
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
    -- Server schemas vary: collections often key pets by spellId even when definitions are keyed by itemId.
    -- Accept either petId or spellId here; prefer definition spellId when available.
    local petId = spellId
    local def = self:GetPetDefinition(petId)
    local key = (def and (_num(def.spellId or def.spell_id))) or _num(petId) or petId
    DC:RequestToggleFavorite("pets", key)
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
    
    for petId, def in pairs(definitions) do
        total = total + 1

        if self:IsPetCollected(petId) then
            owned = owned + 1
        end
        
        local rarity = def.rarity or 1
        byRarity[rarity] = byRarity[rarity] or { owned = 0, total = 0 }
        byRarity[rarity].total = byRarity[rarity].total + 1
        if self:IsPetCollected(petId) then
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
    local knownByCreature = {}
    local knownBySpell = {}
    
    local numPets = GetNumCompanions("CRITTER")
    for i = 1, numPets do
        local creatureID, creatureName, spellID, icon, active = GetCompanionInfo("CRITTER", i)
        if creatureID then
            knownPets[creatureID] = {
                name = creatureName,
                icon = icon,
                spellId = spellID,
                creatureId = creatureID,
            }
            knownByCreature[creatureID] = true
            if spellID then
                knownBySpell[spellID] = true
            end
        end
    end

    self._knownPetsByCreatureId = knownByCreature
    self._knownPetsBySpellId = knownBySpell
    
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

    -- If server definitions are keyed by teaching itemId, prefer marking collected using that key.
    if self:UsesItemIdKeys() then
        for petId, def in pairs(DC.definitions.pets) do
            local creatureId = def and (def.creatureId or def.creature_id)
            local spellId = def and (def.spellId or def.spell_id)
            local known = false

            if creatureId and self._knownPetsByCreatureId and self._knownPetsByCreatureId[creatureId] then
                known = true
            elseif spellId and self._knownPetsBySpellId and self._knownPetsBySpellId[spellId] then
                known = true
            else
                -- Many servers only provide itemId/name/icon; resolve spellId from the teaching item.
                local resolvedSpellId = self:_ResolveSpellIdForDef(def)
                if resolvedSpellId and self._knownPetsBySpellId and self._knownPetsBySpellId[resolvedSpellId] then
                    known = true
                end
            end

            if known and not DC.collections.pets[petId] then
                DC.collections.pets[petId] = { owned = true }
                changed = true
            end
        end
    else
        -- Legacy fallback: seed by creatureId.
        for creatureId, data in pairs(pets) do
            if creatureId then
                if not DC.definitions.pets[creatureId] then
                    DC.definitions.pets[creatureId] = {
                        name = data.name,
                        icon = data.icon,
                        creatureId = data.creatureId,
                        spellId = data.spellId,
                    }
                    changed = true
                end
                if not DC.collections.pets[creatureId] then
                    DC.collections.pets[creatureId] = { owned = true }
                    changed = true
                end
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

-- Optional broad fallback: seed companion definitions from a configured list of
-- companion *item IDs* (WotLK Misc -> Companions). This is useful when:
-- - server pet definitions are missing
-- - the character has 0 learned companions
--
-- This does NOT attempt to guess creature display IDs; instead it resolves the
-- teaching spell via GetItemSpell(itemId) when possible.
function PetModule:SeedFromCompanionItemSeeds()
    local seedList = (DCCollectionDB and DCCollectionDB.companionItemSeeds) or DC.COMPANION_ITEM_SEEDS
    if type(seedList) ~= "table" or #seedList == 0 then
        return false
    end

    DC.definitions.pets = DC.definitions.pets or {}
    DC.collections.pets = DC.collections.pets or {}

    local changed = false

    for _, itemId in ipairs(seedList) do
        itemId = tonumber(itemId)
        if itemId then
            if not DC.definitions.pets[itemId] then
                local name, _, quality, _, reqLevel, class, subclass, _, _, texture = GetItemInfo(itemId)
                local spellName, spellId = nil, nil
                if type(GetItemSpell) == "function" then
                    spellName, spellId = GetItemSpell(itemId)
                end

                DC.definitions.pets[itemId] = {
                    itemId = itemId,
                    name = name or spellName or ("Item " .. tostring(itemId)),
                    icon = texture or "Interface\\Icons\\INV_Box_PetCarrier_01",
                    rarity = quality,
                    spellId = spellId,
                    source = "seed",
                }
                changed = true
            end

            -- If the player already knows the companion (by spellId), mark it owned.
            local def = DC.definitions.pets[itemId]
            local spellId = def and (def.spellId or def.spell_id)
            if spellId and self._knownPetsBySpellId and self._knownPetsBySpellId[spellId] and not DC.collections.pets[itemId] then
                DC.collections.pets[itemId] = { owned = true }
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
    -- In the current schema, pets are keyed by teaching itemId on the server.
    -- Avoid inserting creatureId-keyed entries client-side; just request a resync.
    if self:UsesItemIdKeys() then
        if DC and DC.RequestDefinitions then
            DC:RequestDefinitions("pets")
        end
        if DC and DC.RequestCollection then
            DC:RequestCollection("pets")
        end
        return
    end

    -- Legacy fallback: keep old behavior when definitions are keyed by creatureId.
    local creatureId = nil
    if spellId then
        for i = 1, GetNumCompanions("CRITTER") do
            local cID, _, sID = GetCompanionInfo("CRITTER", i)
            if sID == spellId then
                creatureId = cID
                break
            end
        end
    end
    creatureId = creatureId or spellId

    if creatureId and not DC.collections.pets[creatureId] then
        DC.collections.pets[creatureId] = { obtained_date = time(), is_favorite = false, times_used = 0 }
        DC:Debug("Pet learned (legacy): " .. tostring(creatureId))
        if not DC.definitions.pets[creatureId] and DC and DC.RequestDefinitions then
            DC:RequestDefinitions("pets")
        end
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("COMPANION_LEARNED")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "COMPANION_LEARNED" then
        PetModule:RefreshKnownPetsCache()
        local spellId = ...
        PetModule:OnPetLearned(spellId)
    end
end)
