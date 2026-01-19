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
    
    local titles = self:ScanKnownTitles()
    local added = 0
    
    for titleId, data in pairs(titles) do
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

function TitleModule:IsTitleCollected(titleId)
    return DC.collections.titles and DC.collections.titles[titleId] ~= nil
end

-- ============================================================================
-- FILTERING
-- ============================================================================

function TitleModule:GetFilteredTitles(filters)
    filters = filters or {}
    local results = {}
    
    local definitions = self:GetTitleDefinitions()
    local collection = self:GetTitles()
    
    for titleId, def in pairs(definitions) do
        local collected = collection[titleId] ~= nil
        local collData = collection[titleId]
        
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
    
    if not self:IsTitleCollected(titleId) then
        DC:Print(L["ERR_NOT_OWNED"])
        return
    end
    
    DC:RequestSetTitle(titleId)
end

function TitleModule:ClearTitle()
    DC:RequestSetTitle(0)  -- 0 = no title
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
    local collection = self:GetTitles()
    
    for titleId, def in pairs(definitions) do
        total = total + 1
        if collection[titleId] then
            owned = owned + 1
        end
    end
    
    return {
        owned = owned,
        total = total,
        percentage = total > 0 and math.floor((owned / total) * 100) or 0,
    }
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

function TitleModule:OnTitleEarned(titleId)
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
    end
end

-- Listen for title changes
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("KNOWN_TITLES_UPDATE")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "KNOWN_TITLES_UPDATE" then
        local titles = TitleModule:ScanKnownTitles()
        for titleId, data in pairs(titles) do
            TitleModule:OnTitleEarned(titleId)
        end
    end
end)
