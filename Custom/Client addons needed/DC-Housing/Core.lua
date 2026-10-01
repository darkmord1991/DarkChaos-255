-- DC-Housing Core: addon namespace, init, slash commands.
DCHousing = DCHousing or {}
local DC = DCHousing
local L = DCHousingLocale

DC.MODULE_ID = "DECO"

-- Server-pushed state (refreshed via SMSG_BUDGET).
DC.budget = { used = 0, cap = 0, houseLevel = 0,
    canSpawn = false, canMove = false, canDelete = false }

function DC:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffFFCC00[DC-Housing]|r " .. tostring(msg))
end

-- Catalog data comes from the generated Data\HousingModels.lua; entries
-- flagged enabled=false exist server-side but their model has not shipped
-- in the client patch yet.
function DC:GetItem(entry)
    return DCHousingModelData and DCHousingModelData[entry]
end

-- Blizzard's player-housing taxonomy (generated Data\HousingCategories.lua):
-- categories and subcategories in retail menu order, placement names and the
-- tag groups the catalog filters on. Items carry `category`, `subcategory`,
-- `subcategories` (an item Blizzard files under several is listed under
-- each), `placement`, `tags` ("Group:Value") and search-only `keywords`.
local function CategoryData()
    return DCHousingCategoryData or {}
end

local subcategoryParent
local function ParentOf(subcategory)
    if not subcategoryParent then
        subcategoryParent = {}
        for _, category in ipairs(CategoryData().categories or {}) do
            for _, sub in ipairs(category.subcategories) do
                subcategoryParent[sub] = category.name
            end
        end
    end
    return subcategoryParent[subcategory]
end

local function Subcategories(item)
    return item.subcategories or { item.subcategory }
end

-- Tag set and search text, built once per item on first use.
local function Prepare(item)
    if item._tagset then
        return
    end
    local tagset = {}
    for _, tag in ipairs(item.tags or {}) do
        tagset[tag] = true
    end
    item._tagset = tagset
    item._search = string.lower(table.concat({ item.name or "",
        table.concat(Subcategories(item), " "), item.keywords or "" }, " "))
end

function DC:GetPlacementName(item)
    local placements = CategoryData().placements
    return placements and placements[item.placement or 1]
end

-- Retail's catalog preview camera (UiModelScene) for an item: the decor's own
-- scene when Blizzard names one, else the preset for its placement surface,
-- then for its Size. Returns pitch (radians, + = looking down on the model),
-- orbit zoom distance and the actor scale.
local PRESET_BY_PLACEMENT = { [2] = "Wall", [3] = "Ceiling", [4] = "Flat" }

function DC:GetPreviewCamera(item)
    local data = CategoryData()
    local scenes, presets = data.scenes or {}, data.scenePresets or {}
    local scene = item and item.scene and scenes[item.scene]
    if not scene and item then
        local preset = PRESET_BY_PLACEMENT[item.placement or 1]
        if not preset then
            for _, tag in ipairs(item.tags or {}) do
                preset = string.match(tag, "^Size:(.+)$")
                if preset then
                    break
                end
            end
        end
        scene = scenes[presets[preset or "Default"] or 0]
    end
    scene = scene or scenes[presets.Default or 0]
    if not scene then
        return 0, 3.5, 1
    end
    return scene.pitch or 0, scene.zoom or 3.5, scene.scale or 1
end

-- query = { category, subcategory, filters = { [group] = { [value] = true } },
-- search }. Filters are OR within a group and AND across groups, as retail.
function DC:ItemMatches(item, query)
    if not item.enabled then
        return false
    end
    Prepare(item)

    if query.subcategory or query.category then
        local found = false
        for _, sub in ipairs(Subcategories(item)) do
            if sub == query.subcategory
                or (not query.subcategory and ParentOf(sub) == query.category)
            then
                found = true
                break
            end
        end
        if not found then
            return false
        end
    end

    for group, values in pairs(query.filters or {}) do
        if next(values) then
            local found = false
            for value in pairs(values) do
                if item._tagset[group .. ":" .. value] then
                    found = true
                    break
                end
            end
            if not found then
                return false
            end
        end
    end

    local needle = query.search
    if needle and needle ~= "" then
        return string.find(item._search, string.lower(needle), 1, true) ~= nil
    end
    return true
end

-- Sorted list of enabled entries matching the query.
function DC:GetFilteredEntries(query)
    query = query or {}
    local result = {}
    for entry, item in pairs(DCHousingModelData or {}) do
        if self:ItemMatches(item, query) then
            table.insert(result, entry)
        end
    end
    local data = DCHousingModelData
    table.sort(result, function(a, b)
        if data[a].name ~= data[b].name then
            return data[a].name < data[b].name
        end
        return a < b
    end)
    return result
end

-- Categories holding at least one enabled item, in Blizzard's order, each
-- with its populated subcategories and item counts.
function DC:GetCategoryTree()
    if self._tree then
        return self._tree
    end

    local categoryCount, subCount = {}, {}
    for _, item in pairs(DCHousingModelData or {}) do
        if item.enabled then
            local counted = {}
            for _, sub in ipairs(Subcategories(item)) do
                subCount[sub] = (subCount[sub] or 0) + 1
                local parent = ParentOf(sub)
                if parent and not counted[parent] then
                    counted[parent] = true
                    categoryCount[parent] = (categoryCount[parent] or 0) + 1
                end
            end
        end
    end

    local tree = {}
    for _, category in ipairs(CategoryData().categories or {}) do
        if categoryCount[category.name] then
            local node = { name = category.name, icon = category.icon,
                count = categoryCount[category.name], subcategories = {} }
            for _, sub in ipairs(category.subcategories) do
                if subCount[sub] then
                    table.insert(node.subcategories,
                        { name = sub, count = subCount[sub] })
                end
            end
            table.insert(tree, node)
        end
    end
    self._tree = tree
    return tree
end

-- Filter groups with the values the enabled catalog actually uses: Size and
-- Expansion in Blizzard's order, the rest alphabetical.
function DC:GetFilterGroups()
    if self._filterGroups then
        return self._filterGroups
    end

    local used = {}
    for _, item in pairs(DCHousingModelData or {}) do
        if item.enabled then
            for _, tag in ipairs(item.tags or {}) do
                local group, value = string.match(tag, "^([^:]+):(.+)$")
                if group then
                    used[group] = used[group] or {}
                    used[group][value] = true
                end
            end
        end
    end

    local data = CategoryData()
    local groups = {}
    for _, group in ipairs(data.filterGroups or {}) do
        local values = used[group]
        if values then
            local list = {}
            local order = data.valueOrder and data.valueOrder[group]
            for _, value in ipairs(order or {}) do
                if values[value] then
                    table.insert(list, value)
                    values[value] = nil
                end
            end
            local rest = {}
            for value in pairs(values) do
                table.insert(rest, value)
            end
            table.sort(rest)
            for _, value in ipairs(rest) do
                table.insert(list, value)
            end
            table.insert(groups, { name = group, values = list })
        end
    end
    self._filterGroups = groups
    return groups
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function()
    if not DCAddonProtocol then
        DC:Print("|cffff0000Error:|r DC-AddonProtocol not found.")
        return
    end
    DC.Protocol:Init()
end)

SLASH_DCHOUSING1 = "/dchousing"
SLASH_DCHOUSING2 = "/dch"
SlashCmdList.DCHOUSING = function(message)
    local command = string.lower(string.match(message or "", "^(%S*)") or "")
    if command == "edit" then
        DC.EditMode:Toggle()
    elseif command == "budget" then
        DC.Protocol:RequestBudget()
    else
        DC.Catalog:Toggle()
    end
end
