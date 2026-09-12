-- ============================================================
-- DC-QoS: World Map Continent / Zone dropdowns
-- ============================================================
-- The stock Continent and Zone dropdowns are driven entirely by
-- WorldMapArea.dbc, and on this realm that data cannot say what a player expects:
--
--  * The Continent list is every AreaID-0 WorldMapArea row, in id order. Custom
--    instance and battleground maps carry such a row too (Karazhan Crypts,
--    Naxxramas 2921, both Hinterland BG maps, the empty "Level Zones" test map
--    1451), so they turn up as continents.
--  * A zone whose game map has no AreaID-0 row of its own -- Azshara Crater (map
--    37), The Molten Front (861), Isles of Giants (1405) -- reports continent 0,
--    and stock WorldMapContinentsDropDown_Update / WorldMapZoneDropDown_Update
--    then CLEAR both dropdowns. A continent cannot span several game maps, so
--    no WorldMapArea row can fix that.
--
-- So the continent list is curated here: the four stock continents, the
-- multi-zone custom continents, and a "Dark Chaos" entry that gathers the
-- single-zone custom maps. Both _Update functions are POST-hooked
-- (hooksecurefunc; nothing stock is replaced):
--  * the Continent dropdown always gets the curated list and selection;
--  * the Zone dropdown is taken over only while a Dark Chaos map is displayed.
--    Everywhere else it stays stock, where GetMapZones already works --
--    custom continents 750/751/870 included.
--
-- Every stock _Update call re-runs UIDropDownMenu_Initialize with the stock
-- initializer (which also closes any open list), so writing .initialize and
-- the selection after it is enough; the list itself is built only when the
-- player opens the dropdown.
--
-- Id spaces: GetCurrentMapAreaID() is WorldMapArea.ID + 1, SetMapByID takes the
-- RAW WorldMapArea.ID. Every `wma` below is RAW.

local addon = DCQOS
if not addon then
    return
end

local WorldMapDropdowns = {
    displayName = "World Map Dropdowns",
    settingKey = "worldMapDropdowns",
    icon = "Interface\\Icons\\INV_Misc_Map02",
    defaults = {
        worldMapDropdowns = {
            enabled = true,
        },
    },
}

local DARK_CHAOS = "Dark Chaos"

-- Continent dropdown, in display order.
-- native = stock continent index. 1-4 never move: their AreaID-0 rows (13, 14,
--          466, 485) are the lowest WorldMapArea ids, so every custom row sorts
--          after them.
-- wma    = the custom continent's AreaID-0 row, opened with SetMapByID.
-- name   = label. For custom continents it is spelled exactly like Map.dbc
--          MapName, because that is what GetMapContinents() returns and the
--          name is the fallback route to the native continent index.
local CONTINENTS = {
    { map = 1,   native = 1, name = "Kalimdor" },
    { map = 0,   native = 2, name = "Eastern Kingdoms" },
    { map = 530, native = 3, name = "Outland" },
    { map = 571, native = 4, name = "Northrend" },
    { map = 750, wma = 1262, name = "Mount Hyjal (80-130)" },
    { map = 751, wma = 1267, name = "Plaguelands" },
    { map = 870, wma = 1205, name = "Pandaria" },
    { darkChaos = true, name = DARK_CHAOS },
}

-- Zones listed under Dark Chaos: open-world custom maps without a multi-zone
-- continent. Alphabetical, like GetMapZones().
-- wma           = the row SetMapByID opens.
-- name          = AreaTable name of the zone (level range included, matching
--                 how the custom continents' zones read).
-- continentName = Map.dbc name of the map's own AreaID-0 row, when it has one.
--                 Only a fallback route; those rows are why Deepholm, Jade
--                 Forest and Undermine used to be "continents".
-- alsoMaps      = other game maps that display this zone. Map 1451 ("Level
--                 Zones") is an empty test map whose only zone row shows
--                 Azshara Crater.
local DARK_CHAOS_ZONES = {
    { map = 37,   wma = 613,  name = "Azshara Crater (1-80)", alsoMaps = { 1451 } },
    { map = 646,  wma = 1215, name = "Deepholm", continentName = "Deepholm" },
    { map = 1405, wma = 1100, name = "Isles of Giants" },
    { map = 745,  wma = 1101, name = "The Jade Forest", continentName = "Jade Forest" },
    { map = 861,  wma = 1255, name = "The Molten Front" },
    { map = 2706, wma = 1204, name = "Undermine", continentName = "Undermine" },
}

-- Custom maps that are not browsable zones -- instances, battlegrounds, maps
-- with no live content. Displaying one still fills Continent = Dark Chaos and
-- Zone = this name, but they are not offered in the Zone list (stock never
-- lists instances either, and several have no map art to land on).
local DARK_CHAOS_OTHER = {
    [669]  = "Blackwing Descent",
    [819]  = "Timbermaw Hold",
    [820]  = "Blackfathom Deeps (92-96)",
    [821]  = "Stratholme",
    [822]  = "Scholomance",
    [823]  = "Crescent Grove",
    [824]  = "Emerald Sanctum",
    [825]  = "Shadowfang Keep",
    [850]  = "Stratholme Valley",
    [1409] = "Guild House",
    [1410] = "Hyjal Frontier",
    [1411] = "Hinterland Battleground",
    [1412] = "Hinterland Battleground",
    [1413] = "Guild House",
    [2296] = "Castle Nathria",
    [2875] = "Karazhan Crypts",
    [2921] = "Naxxramas",
}

-- Rows with a zero-size rectangle, for which GetWorldMapAreaBounds reports
-- nothing, so their game map has to be named here.
local GAME_MAP_BY_WMA = {
    [1264] = 820, -- Blackfathom Deeps (Ashenvale)
}

local CONTINENT_POS_BY_MAP = {}
local CONTINENT_POS_BY_NATIVE = {}
local DARK_CHAOS_POS
for pos, entry in ipairs(CONTINENTS) do
    if entry.darkChaos then
        DARK_CHAOS_POS = pos
    else
        CONTINENT_POS_BY_MAP[entry.map] = pos
    end
    if entry.native then
        CONTINENT_POS_BY_NATIVE[entry.native] = pos
    end
end

local ZONE_POS_BY_MAP = {}
for pos, zone in ipairs(DARK_CHAOS_ZONES) do
    ZONE_POS_BY_MAP[zone.map] = pos
    for _, alias in ipairs(zone.alsoMaps or {}) do
        ZONE_POS_BY_MAP[alias] = pos
    end
end

local state = {
    active = false,
    hooksInstalled = false,
}

-- ------------------------------------------------------------------ resolve

local function GetNativeContinentNames()
    if type(GetMapContinents) ~= "function" then
        return {}
    end
    return { GetMapContinents() }
end

local function ContinentLabel(entry)
    if entry.native then
        local nativeName = GetNativeContinentNames()[entry.native]
        if nativeName and nativeName ~= "" then
            return nativeName
        end
    end
    return entry.name
end

-- Game map of the displayed WorldMapArea row, read live from the client's DBC.
local function GetDisplayedGameMap()
    if type(GetCurrentMapAreaID) ~= "function" then
        return nil
    end
    local uiMapId = tonumber(GetCurrentMapAreaID())
    if not uiMapId or uiMapId <= 0 then
        return nil
    end

    local override = GAME_MAP_BY_WMA[uiMapId - 1]
    if override then
        return override
    end

    local mapUtils = addon.GetMapUtils and addon:GetMapUtils()
    if mapUtils and mapUtils.GetMapAreaBounds then
        return (mapUtils.GetMapAreaBounds(uiMapId))
    end
    return nil
end

local function DarkChaosZoneContext(pos)
    local zone = DARK_CHAOS_ZONES[pos]
    return { continentPos = DARK_CHAOS_POS, darkChaos = true, zonePos = pos, zoneName = zone.name }
end

-- Without a game map (old WotLKExtensions.dll, or a zero-size row) the native
-- continent index is all there is. 1-4 are fixed; anything else is matched by
-- its Map.dbc name.
local function ContextFromNativeContinent()
    if type(GetCurrentMapContinent) ~= "function" then
        return {}
    end
    local native = tonumber(GetCurrentMapContinent())
    if not native or native <= 0 then
        return {}
    end
    if CONTINENT_POS_BY_NATIVE[native] then
        return { continentPos = CONTINENT_POS_BY_NATIVE[native] }
    end

    local nativeName = GetNativeContinentNames()[native]
    if not nativeName then
        return {}
    end
    for pos, entry in ipairs(CONTINENTS) do
        if not entry.darkChaos and entry.name == nativeName then
            return { continentPos = pos }
        end
    end
    for pos, zone in ipairs(DARK_CHAOS_ZONES) do
        if zone.continentName == nativeName then
            return DarkChaosZoneContext(pos)
        end
    end
    return {}
end

-- What the dropdowns should show for the displayed map:
--   continentPos  index into CONTINENTS (nil = clear, as stock does)
--   darkChaos     the Zone dropdown belongs to this module
--   zonePos       index into DARK_CHAOS_ZONES (nil for DARK_CHAOS_OTHER maps)
--   zoneName      Zone dropdown text
local function Resolve()
    -- The World and Cosmic overviews have no map file; stock clears both
    -- dropdowns there and so do we.
    if type(GetMapInfo) ~= "function" or not GetMapInfo() then
        return {}
    end

    local gameMapId = GetDisplayedGameMap()
    if gameMapId then
        if ZONE_POS_BY_MAP[gameMapId] then
            return DarkChaosZoneContext(ZONE_POS_BY_MAP[gameMapId])
        end
        if DARK_CHAOS_OTHER[gameMapId] then
            return { continentPos = DARK_CHAOS_POS, darkChaos = true, zoneName = DARK_CHAOS_OTHER[gameMapId] }
        end
        if CONTINENT_POS_BY_MAP[gameMapId] then
            return { continentPos = CONTINENT_POS_BY_MAP[gameMapId] }
        end
    end
    return ContextFromNativeContinent()
end

-- --------------------------------------------------------------- navigation

local function OpenWorldMapArea(wma)
    if not wma or type(SetMapByID) ~= "function" then
        return false
    end
    local ok = pcall(SetMapByID, wma)
    return ok and type(GetCurrentMapAreaID) == "function" and GetCurrentMapAreaID() == wma + 1
end

local function FindNativeContinent(name)
    if not name then
        return nil
    end
    local names = GetNativeContinentNames()
    for i = 1, #names do
        if names[i] == name then
            return i
        end
    end
    return nil
end

local function OpenDarkChaosZone(pos)
    local zone = DARK_CHAOS_ZONES[pos]
    if not zone or OpenWorldMapArea(zone.wma) then
        return
    end

    local index = FindNativeContinent(zone.continentName)
    if not index or type(SetMapZoom) ~= "function" then
        return
    end
    local zones = type(GetMapZones) == "function" and { GetMapZones(index) } or {}
    for i = 1, #zones do
        if zones[i] == zone.name then
            SetMapZoom(index, i)
            return
        end
    end
    SetMapZoom(index)
end

local function OnContinentClick(_, pos)
    local entry = CONTINENTS[pos]
    if not entry then
        return
    end

    if entry.darkChaos then
        -- There is no Dark Chaos overview to zoom to: stay on the Dark Chaos zone
        -- already shown, otherwise open the first one.
        OpenDarkChaosZone(Resolve().zonePos or 1)
        return
    end

    if entry.native then
        if type(SetMapZoom) == "function" then
            SetMapZoom(entry.native)
        end
        return
    end

    if OpenWorldMapArea(entry.wma) then
        return
    end
    local index = FindNativeContinent(entry.name)
    if index and type(SetMapZoom) == "function" then
        SetMapZoom(index)
    end
end

local function OnDarkChaosZoneClick(_, pos)
    OpenDarkChaosZone(pos)
end

-- ---------------------------------------------------------------- dropdowns

local function InitializeContinentList()
    local info = UIDropDownMenu_CreateInfo()
    for pos, entry in ipairs(CONTINENTS) do
        info.text = ContinentLabel(entry)
        info.func = OnContinentClick
        info.arg1 = pos
        info.checked = nil
        UIDropDownMenu_AddButton(info)
    end
end

local function InitializeDarkChaosZoneList()
    local info = UIDropDownMenu_CreateInfo()
    for pos, zone in ipairs(DARK_CHAOS_ZONES) do
        info.text = zone.name
        info.func = OnDarkChaosZoneClick
        info.arg1 = pos
        info.checked = nil
        UIDropDownMenu_AddButton(info)
    end
end

-- Not UIDropDownMenu_SetSelectedID: its Refresh matches button ids across ALL
-- DropDownList1 buttons, including hidden ones still holding another menu's
-- text, and at this point the list holds the stock entries, not ours.
-- UIDropDownMenu_AddButton checks the matching entry by selectedID once the
-- player opens the list.
local function SetSelection(dropDown, selectedId, text)
    dropDown.selectedID = selectedId
    dropDown.selectedName = nil
    dropDown.selectedValue = nil
    UIDropDownMenu_SetText(dropDown, text or "")
end

local function ApplyContinentDropDown()
    local dropDown = _G.WorldMapContinentDropDown
    if not state.active or not dropDown then
        return
    end

    local ctx = Resolve()
    dropDown.initialize = InitializeContinentList
    if ctx.continentPos then
        SetSelection(dropDown, ctx.continentPos, ContinentLabel(CONTINENTS[ctx.continentPos]))
    else
        SetSelection(dropDown, nil, "")
    end
end

local function ApplyZoneDropDown()
    local dropDown = _G.WorldMapZoneDropDown
    if not state.active or not dropDown then
        return
    end

    local ctx = Resolve()
    if not ctx.darkChaos then
        -- Stock selects zone 0 on a continent overview, which matches no list
        -- button, so UIDropDownMenu_Refresh leaves whatever text was there --
        -- after a Dark Chaos zone, "The Molten Front" under Mount Hyjal.
        if type(GetCurrentMapZone) == "function" and GetCurrentMapZone() == 0 then
            SetSelection(dropDown, nil, "")
        end
        return
    end
    dropDown.initialize = InitializeDarkChaosZoneList
    SetSelection(dropDown, ctx.zonePos, ctx.zoneName)
end

local function ApplyIfShown()
    if WorldMapFrame and WorldMapFrame.IsShown and WorldMapFrame:IsShown() then
        ApplyContinentDropDown()
        ApplyZoneDropDown()
    end
end

local function InstallHooks()
    if state.hooksInstalled or type(hooksecurefunc) ~= "function" then
        return
    end
    if type(_G.WorldMapContinentsDropDown_Update) == "function" then
        hooksecurefunc("WorldMapContinentsDropDown_Update", ApplyContinentDropDown)
    end
    if type(_G.WorldMapZoneDropDown_Update) == "function" then
        hooksecurefunc("WorldMapZoneDropDown_Update", ApplyZoneDropDown)
    end
    state.hooksInstalled = true
end

-- Core calls these as PLAIN functions (module.OnEnable()), so no colon.
function WorldMapDropdowns.OnInitialize()
    InstallHooks()
end

function WorldMapDropdowns.OnEnable()
    InstallHooks()
    state.active = true
    ApplyIfShown()
end

-- The hooks cannot be removed; they go inert, and the next stock _Update puts
-- the stock initializers and selection back.
function WorldMapDropdowns.OnDisable()
    state.active = false
end

-- Exposed for the regression test.
WorldMapDropdowns._Resolve = Resolve
WorldMapDropdowns._CONTINENTS = CONTINENTS
WorldMapDropdowns._DARK_CHAOS_ZONES = DARK_CHAOS_ZONES

addon:RegisterModule("WorldMapDropdowns", WorldMapDropdowns)
