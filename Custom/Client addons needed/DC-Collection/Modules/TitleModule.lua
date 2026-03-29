--[[
    DC-Collection Modules/TitleModule.lua
    =====================================
    
    Title collection handling - display and activation.
    
    Author: DarkChaos-255
    Version: 1.0.0
]]

local DC = DCCollection
local L = DC.L

-- ============================================================================
-- TITLE MODULE
-- ============================================================================

local TitleModule = {}
DC.TitleModule = TitleModule

local function NormalizeTitleName(name)
    if type(name) ~= "string" then
        return ""
    end

    local normalized = string.lower(name)
    normalized = string.gsub(normalized, "%%s", "")
    normalized = string.gsub(normalized, "|c%x%x%x%x%x%x%x%x", "")
    normalized = string.gsub(normalized, "|r", "")
    normalized = string.gsub(normalized, "^%s+", "")
    normalized = string.gsub(normalized, "%s+$", "")
    normalized = string.gsub(normalized, "%s+", " ")

    return normalized
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function TitleModule:Init()
    DC:Debug("TitleModule initialized")
    
    -- Seed known titles from client if server definitions are empty
    DC.After(0.5, function()
        self:SeedFromClientKnownTitles()
    end)
end

-- ============================================================================
-- SEED FROM CLIENT KNOWN TITLES
-- ============================================================================

function TitleModule:SeedFromClientKnownTitles()
    DC.definitions = DC.definitions or {}
    DC.definitions.titles = DC.definitions.titles or {}
    DC.collections = DC.collections or {}
    DC.collections.titles = DC.collections.titles or {}

    local defsByName = {}
    for defId, def in pairs(DC.definitions.titles) do
        local key = NormalizeTitleName(def and (def.displayName or def.name))
        if key ~= "" and defsByName[key] == nil then
            defsByName[key] = defId
        end
    end
    
    local titles = self:ScanKnownTitles()
    local added = 0
    
    for knownIndex, data in pairs(titles) do
        local titleKey = NormalizeTitleName(data and data.name)
        local titleId = defsByName[titleKey] or knownIndex

        -- Add to definitions if not present
        if not DC.definitions.titles[titleId] then
            DC.definitions.titles[titleId] = {
                id = titleId,
                name = data.name,
                displayName = data.name,
                icon = "Interface\\Icons\\INV_Scroll_11",
                rarity = 1,
            }
            added = added + 1
        end
        
        -- Mark as collected
        if not DC.collections.titles[titleId] then
            DC.collections.titles[titleId] = {
                obtained_date = time(),
                is_favorite = false,
                is_active = false,
            }
        end
    end
    
    if added > 0 then
        DC:Debug("Seeded " .. added .. " titles from client")
    end

    self:RefreshStatsCache()
    
    return added > 0
end

-- ============================================================================
-- TITLE COLLECTION ACCESS
-- ============================================================================

function TitleModule:GetTitles()
    return DC.collections.titles or {}
end

function TitleModule:GetTitleDefinitions()
    return DC.definitions.titles or {}
end

function TitleModule:GetTitle(titleId)
    return DC.collections.titles and DC.collections.titles[titleId]
end

function TitleModule:GetTitleDefinition(titleId)
    return DC.definitions.titles and DC.definitions.titles[titleId]
end

function TitleModule:BuildKnownTitleLookup()
    local knownByIndex = {}
    local indexByName = {}

    if type(GetNumTitles) ~= "function" or
        type(GetTitleName) ~= "function" or
        type(IsTitleKnown) ~= "function" then
        return knownByIndex, indexByName
    end

    local titleCount = tonumber(GetNumTitles()) or 0
    for i = 1, titleCount do
        local name = GetTitleName(i)
        if name then
            local key = NormalizeTitleName(name)
            if key ~= "" and indexByName[key] == nil then
                indexByName[key] = i
            end
        end

        if IsTitleKnown(i) then
            knownByIndex[i] = true
        end
    end

    return knownByIndex, indexByName
end

function TitleModule:GetCollectionDataForTitle(titleId, titleDef, knownByName)
    local collection = self:GetTitles()
    local numericId = tonumber(titleId)

    local collData = collection[titleId]
    if not collData and numericId then
        collData = collection[numericId]
    end
    if not collData then
        collData = collection[tostring(titleId)]
    end
    if collData then
        return collData, numericId
    end

    local resolvedIndex = nil
    if numericId and type(GetTitleName) == "function" then
        local apiName = GetTitleName(numericId)
        if apiName then
            if not titleDef or
                NormalizeTitleName(apiName) == NormalizeTitleName(titleDef.displayName or titleDef.name) then
                resolvedIndex = numericId
            end
        end
    end

    if not resolvedIndex and titleDef then
        knownByName = knownByName or select(2, self:BuildKnownTitleLookup())
        local key = NormalizeTitleName(titleDef.displayName or titleDef.name)
        resolvedIndex = knownByName[key]
    end

    if resolvedIndex then
        collData = collection[resolvedIndex] or collection[tostring(resolvedIndex)]
    end

    return collData, resolvedIndex
end

function TitleModule:IsTitleCollected(titleId, titleDef, knownByIndex, knownByName)
    local collData, knownIndex = self:GetCollectionDataForTitle(titleId, titleDef,
        knownByName)
    if collData then
        return true
    end

    knownByIndex = knownByIndex or select(1, self:BuildKnownTitleLookup())
    local numericId = tonumber(titleId)

    if numericId and knownByIndex[numericId] then
        return true
    end

    if knownIndex and knownByIndex[knownIndex] then
        return true
    end

    return false
end

-- ============================================================================
-- FILTERING
-- ============================================================================

function TitleModule:GetFilteredTitles(filters)
    filters = filters or {}
    local results = {}
    
    local definitions = self:GetTitleDefinitions()
    local knownByIndex, knownByName = self:BuildKnownTitleLookup()
    
    for titleId, def in pairs(definitions) do
        local collData = self:GetCollectionDataForTitle(titleId, def, knownByName)
        local collected = self:IsTitleCollected(titleId, def, knownByIndex, knownByName)
        
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
            local displayLower = string.lower(def.displayName or "")
            if not string.find(nameLower, searchLower, 1, true) and 
               not string.find(displayLower, searchLower, 1, true) then
                include = false
            end
        end
        
        if filters.source and filters.source ~= "" then
            local sourceText = DC:FormatSource(def.source)
            if sourceText ~= filters.source then
                include = false
            end
        end
        
        if include then
            table.insert(results, {
                id = titleId,
                name = def.name,
                displayName = def.displayName,
                icon = def.icon or "Interface\\Icons\\INV_Scroll_11",
                rarity = def.rarity,
                source = def.source,
                isPrefix = def.isPrefix,
                collected = collected,
                is_favorite = collData and collData.is_favorite,
                is_active = collData and collData.is_active,
                definition = def,
            })
        end
    end
    
    return results
end

-- ============================================================================
-- TITLE ACTIONS
-- ============================================================================

function TitleModule:SetTitle(titleId)
    if not titleId then
        DC:Print(L["ERR_NO_TITLE"] or "No title specified")
        return
    end
    
    local def = self:GetTitleDefinition(titleId)
    local knownByIndex, knownByName = self:BuildKnownTitleLookup()

    if not self:IsTitleCollected(titleId, def, knownByIndex, knownByName) then
        DC:Print(L["ERR_NOT_OWNED"])
        return
    end

    local requestId = tonumber(titleId)

    -- Always try server-side apply first so the character learns/activates account titles
    -- even when client cache keys are stale or mismatched.
    if requestId and requestId > 0 and type(DC.RequestSetTitle) == "function" then
        DC:RequestSetTitle(requestId)
    end

    -- Fallback to native title API for ID/index mismatches (common with custom title packs).
    local _, knownIndex = self:GetCollectionDataForTitle(titleId, def, knownByName)
    if not knownIndex and knownByName and def then
        knownIndex = knownByName[NormalizeTitleName(def.displayName or def.name)]
    end

    -- Extra server fallback for environments where titles are stored by index-like keys.
    if knownIndex and knownIndex ~= requestId and
        type(DC.RequestSetTitle) == "function" then
        DC:RequestSetTitle(knownIndex)
    end

    if knownIndex and type(SetCurrentTitle) == "function" then
        pcall(SetCurrentTitle, knownIndex)
    end
end

function TitleModule:ClearTitle()
    if type(DC.RequestSetTitle) == "function" then
        DC:RequestSetTitle(0)  -- 0 = no title
    end
    if type(SetCurrentTitle) == "function" then
        pcall(SetCurrentTitle, 0)
    end
end

function TitleModule:GetActiveTitle()
    local collection = self:GetTitles()
    for titleId, data in pairs(collection) do
        if data.is_active then
            return titleId
        end
    end
    return nil
end

-- ============================================================================
-- TITLE DISPLAY
-- ============================================================================

function TitleModule:FormatName(playerName, titleId)
    local def = self:GetTitleDefinition(titleId)
    if not def then
        return playerName
    end
    
    local titleName = def.displayName or def.name
    if def.isPrefix then
        return titleName .. " " .. playerName
    else
        return playerName .. " " .. titleName
    end
end

function TitleModule:GetPreview(titleId)
    local playerName = UnitName("player")
    return self:FormatName(playerName, titleId)
end

-- ============================================================================
-- FAVORITES
-- ============================================================================

function TitleModule:ToggleFavorite(titleId)
    DC:RequestToggleFavorite("titles", titleId)
end

function TitleModule:GetFavorites()
    return self:GetFilteredTitles({ favoritesOnly = true })
end

-- ============================================================================
-- STATISTICS
-- ============================================================================

function TitleModule:GetStats()
    local owned = 0
    local total = 0
    
    local definitions = self:GetTitleDefinitions()
    local knownByIndex, knownByName = self:BuildKnownTitleLookup()
    
    for titleId, def in pairs(definitions) do
        total = total + 1
        if self:IsTitleCollected(titleId, def, knownByIndex, knownByName) then
            owned = owned + 1
        end
    end
    
    return {
        owned = owned,
        total = total,
        percentage = total > 0 and math.floor((owned / total) * 100) or 0,
    }
end

function TitleModule:RefreshStatsCache()
    local stats = self:GetStats()

    DC.stats = DC.stats or {}
    DC.stats.titles = DC.stats.titles or { owned = 0, total = 0 }
    if stats.owned > (DC.stats.titles.owned or 0) then
        DC.stats.titles.owned = stats.owned
    end
    if stats.total > (DC.stats.titles.total or 0) then
        DC.stats.titles.total = stats.total
    end

    DC.collectionStats = DC.collectionStats or {}
    local titleStats = DC.collectionStats.titles or { collected = 0, total = 0 }
    if stats.owned > (titleStats.collected or 0) then
        titleStats.collected = stats.owned
    end
    if stats.total > (titleStats.total or 0) then
        titleStats.total = stats.total
    end
    DC.collectionStats.titles = titleStats

    if DC.MainFrame and DC.MainFrame:IsShown() and
        type(DC.UpdateHeader) == "function" then
        DC:UpdateHeader()
    end
    if DC.MyCollection and type(DC.MyCollection.Update) == "function" then
        DC.MyCollection:Update()
    end
end

-- ============================================================================
-- NATIVE TITLE SCAN
-- ============================================================================

-- Scan titles the player has earned natively
function TitleModule:ScanKnownTitles()
    local knownTitles = {}
    
    -- Check all known titles (up to title bit mask limit)
    for i = 1, GetNumTitles() do
        if IsTitleKnown(i) then
            local name = GetTitleName(i)
            if name then
                knownTitles[i] = {
                    id = i,
                    name = name,
                }
            end
        end
    end
    
    return knownTitles
end

-- ============================================================================
-- INTEGRATION
-- ============================================================================

function TitleModule:OnTitleEarned(titleId, skipRefresh)
    if not DC.collections.titles[titleId] then
        DC.collections.titles[titleId] = {
            obtained_date = time(),
            is_favorite = false,
            is_active = false,
        }
        DC:Debug("Title earned: " .. titleId)
        
        if not DC.definitions.titles[titleId] then
            DC:RequestDefinitions("titles")
        end

        if not skipRefresh then
            self:RefreshStatsCache()
        end

        return true
    end

    return false
end

-- Listen for title changes
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("KNOWN_TITLES_UPDATE")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "KNOWN_TITLES_UPDATE" then
        TitleModule:SeedFromClientKnownTitles()
        if DC and type(DC.RequestCollection) == "function" then
            DC:RequestCollection("titles")
        end
    end
end)
