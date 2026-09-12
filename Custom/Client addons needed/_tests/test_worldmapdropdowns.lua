dofile("wowsim.lua")
local ROOT = [[K:\Dark-Chaos\DarkChaos-255-Master\Custom\Client addons needed\]]
local pass, fail = 0, 0
local function ok(c, m) if c then pass=pass+1; print("  PASS "..m) else fail=fail+1; print("  FAIL "..m) end end

_G.unpack = _G.unpack or table.unpack

-- ------------------------------------------------------------------
-- A client world map, modelled on the 3.3.5 behaviour measured in-game:
--  * continents = AreaID-0 WorldMapArea rows in id order (index is the rank);
--  * GetCurrentMapContinent() = that rank for the displayed row's game map, 0
--    when the map has no AreaID-0 row;
--  * GetMapZones(c) = AreaID~=0 rows on the continent's map, alphabetical;
--  * GetCurrentMapAreaID() = WorldMapArea.ID + 1, SetMapByID takes the raw id.
-- Rows are copied from Custom/CSV DBC/WorldMapArea.csv; continent names are
-- Map.dbc MapName.
-- ------------------------------------------------------------------
local ROWS = {
    { id = 4,    map = 1,    area = 14,    name = "Durotar" },
    { id = 13,   map = 1,    area = 0,     name = "Kalimdor" },
    { id = 14,   map = 0,    area = 0,     name = "Azeroth" },
    { id = 466,  map = 530,  area = 0,     name = "Expansion01" },
    { id = 485,  map = 571,  area = 0,     name = "Northrend" },
    { id = 613,  map = 37,   area = 268,   name = "Azshara Crater (1-80)" },
    { id = 640,  map = 646,  area = 0,     name = "Deepholm" },
    { id = 1100, map = 1405, area = 5006,  name = "Isles of Giants" },
    { id = 1101, map = 745,  area = 5019,  name = "The Jade Forest" },
    { id = 1203, map = 1411, area = 0,     name = "HinterlandBattleground" },
    { id = 1204, map = 2706, area = 0,     name = "Undermine" },
    { id = 1205, map = 870,  area = 0,     name = "Pandaria" },
    { id = 1206, map = 870,  area = 5785,  name = "The Jade Forest" },
    { id = 1207, map = 870,  area = 5805,  name = "Valley of the Four Winds" },
    { id = 1215, map = 646,  area = 4922,  name = "Deepholm" },
    { id = 1216, map = 750,  area = 4923,  name = "Hyjal Frontier (113-130)" },
    { id = 1217, map = 751,  area = 4924,  name = "Eastern Plaguelands (152-158)" },
    { id = 1222, map = 2875, area = 0,     name = "KarazhanCrypts" },
    { id = 1223, map = 2921, area = 0,     name = "Naxxramas" },
    { id = 1250, map = 1451, area = 0,     name = "AzsharaCrater" },
    { id = 1251, map = 1451, area = 268,   name = "Azshara Crater (1-80)" },
    { id = 1254, map = 1412, area = 0,     name = "HinterlandBattleground" },
    { id = 1255, map = 861,  area = 4925,  name = "The Molten Front" },
    { id = 1256, map = 750,  area = 4926,  name = "Winterspring (104-115)" },
    { id = 1262, map = 750,  area = 0,     name = "Kalimdor" },
    { id = 1264, map = 820,  area = 16103, name = "Blackfathom Deeps (92-96)", degenerate = true },
    { id = 1267, map = 751,  area = 0,     name = "Plaguelands" },
    { id = 1279, map = 745,  area = 0,     name = "JadeForest" },
}
local MAP_NAMES = {
    [1] = "Kalimdor", [0] = "Eastern Kingdoms", [530] = "Outland", [571] = "Northrend",
    [646] = "Deepholm", [1411] = "HinterlandBG - New", [2706] = "Undermine", [870] = "Pandaria",
    [2875] = "Karazhan Crypts", [2921] = "Naxxramas", [1451] = "Level Zones",
    [1412] = "HinterlandBG - Copy", [750] = "Mount Hyjal (80-130)", [751] = "Plaguelands",
    [745] = "Jade Forest",
}
local ROW = {}
for _, r in ipairs(ROWS) do ROW[r.id] = r end
table.sort(ROWS, function(a, b) return a.id < b.id end)
local CONTINENT_ROWS = {}
for _, r in ipairs(ROWS) do
    if r.area == 0 then CONTINENT_ROWS[#CONTINENT_ROWS + 1] = r end
end

local displayed      -- row id, or "world"
local setMapByIdWorks = true
local boundsExport = true
local zoomCalls = {}

local function ZonesFor(continent)
    local c = CONTINENT_ROWS[continent]
    if not c then return {} end
    local zones = {}
    for _, r in ipairs(ROWS) do
        if r.map == c.map and r.area ~= 0 then zones[#zones + 1] = r end
    end
    table.sort(zones, function(a, b) return a.name < b.name end)
    return zones
end

local fireWorldMapUpdate
_G.GetMapInfo = function()
    if displayed == "world" then return nil end
    return ROW[displayed].name
end
_G.GetCurrentMapAreaID = function()
    if displayed == "world" then return 0 end
    return displayed + 1
end
_G.GetCurrentMapContinent = function()
    if displayed == "world" then return 0 end
    for i, c in ipairs(CONTINENT_ROWS) do
        if c.map == ROW[displayed].map then return i end
    end
    return 0
end
_G.GetCurrentMapZone = function()
    if displayed == "world" or ROW[displayed].area == 0 then return 0 end
    for i, z in ipairs(ZonesFor(GetCurrentMapContinent())) do
        if z.id == displayed then return i end
    end
    return 0
end
_G.GetMapContinents = function()
    local names = {}
    for i, c in ipairs(CONTINENT_ROWS) do names[i] = MAP_NAMES[c.map] end
    return unpack(names)
end
_G.GetMapZones = function(continent)
    local names = {}
    for i, z in ipairs(ZonesFor(continent)) do names[i] = z.name end
    return unpack(names)
end
_G.SetMapZoom = function(continent, zone)
    zoomCalls[#zoomCalls + 1] = { continent, zone }
    local c = CONTINENT_ROWS[continent]
    if not c then displayed = "world" fireWorldMapUpdate() return end
    displayed = zone and ZonesFor(continent)[zone].id or c.id
    fireWorldMapUpdate()
end
_G.SetMapByID = function(wma)
    if not setMapByIdWorks or not ROW[wma] then return end
    displayed = wma
    fireWorldMapUpdate()
end

-- ------------------------------------------------------------------
-- UIDropDownMenu, reduced to the parts the world-map dropdowns depend on.
-- Buttons persist between builds (like DropDownList1ButtonN), so stale text
-- from a longer list is still there, hidden, as in the client.
-- ------------------------------------------------------------------
local listButtons, numButtons, initMenu = {}, 0, nil
_G.UIDropDownMenu_CreateInfo = function() return {} end
_G.UIDropDownMenu_Initialize = function(frame, fn)
    numButtons = 0
    initMenu = frame
    frame.initialize = fn
    fn()
end
_G.UIDropDownMenu_AddButton = function(info)
    numButtons = numButtons + 1
    local b = listButtons[numButtons] or { id = numButtons, GetID = function(self) return self.id end }
    listButtons[numButtons] = b
    b.text, b.func, b.arg1 = info.text, info.func, info.arg1
    b.checked = info.checked or (initMenu.selectedID == b.id) or nil
end
_G.UIDropDownMenu_SetText = function(frame, text) frame.text = text end
_G.UIDropDownMenu_SetWidth = function() end
_G.UIDropDownMenu_ClearAll = function(frame)
    frame.selectedID, frame.selectedName, frame.selectedValue = nil, nil, nil
    frame.text = ""
end
_G.UIDropDownMenu_SetSelectedID = function(frame, id)
    frame.selectedID, frame.selectedName, frame.selectedValue = id, nil, nil
    for _, b in ipairs(listButtons) do
        if b.id == id then frame.text = b.text end
    end
end

-- The player opens a dropdown: ToggleDropDownMenu rebuilds it from .initialize.
local function OpenList(dropDown)
    UIDropDownMenu_Initialize(dropDown, dropDown.initialize)
    local out = {}
    for i = 1, numButtons do out[i] = listButtons[i] end
    return out
end
local function Names(list)
    local n = {}
    for i, b in ipairs(list) do n[i] = b.text end
    return n
end
local function Has(list, text)
    for _, b in ipairs(list) do if b.text == text then return true end end
    return false
end
local function Checked(list)
    for _, b in ipairs(list) do if b.checked then return b.text end end
    return nil
end
local function Click(dropDown, text)
    for _, b in ipairs(OpenList(dropDown)) do
        if b.text == text then b.func(b, b.arg1) return true end
    end
    return false
end

_G.hooksecurefunc = function(name, hook)
    local orig = _G[name]
    _G[name] = function(...)
        local r = { orig(...) }
        hook(...)
        return unpack(r)
    end
end

-- ------------------------------------------------------------------
-- Stock FrameXML, verbatim (WorldMapFrame.lua, 3.3.5a).
-- ------------------------------------------------------------------
_G.WORLDMAP_COSMIC_ID = -1
_G.WorldMapFrame = CreateFrame("Frame")
WorldMapFrame:Show()
_G.WorldMapContinentDropDown = CreateFrame("Frame")
_G.WorldMapZoneDropDown = CreateFrame("Frame")

function WorldMapContinentsDropDown_Update()
    UIDropDownMenu_Initialize(WorldMapContinentDropDown, WorldMapContinentsDropDown_Initialize);
    UIDropDownMenu_SetWidth(WorldMapContinentDropDown, 130);

    if ( (GetCurrentMapContinent() == 0) or (GetCurrentMapContinent() == WORLDMAP_COSMIC_ID) ) then
        UIDropDownMenu_ClearAll(WorldMapContinentDropDown);
    else
        UIDropDownMenu_SetSelectedID(WorldMapContinentDropDown,GetCurrentMapContinent());
    end
end

function WorldMapContinentsDropDown_Initialize()
    WorldMapFrame_LoadContinents(GetMapContinents());
end

function WorldMapFrame_LoadContinents(...)
    local info = UIDropDownMenu_CreateInfo();
    for i=1, select("#", ...), 1 do
        info.text = select(i, ...);
        info.func = WorldMapContinentButton_OnClick;
        info.checked = nil;
        UIDropDownMenu_AddButton(info);
    end
end

function WorldMapZoneDropDown_Update()
    UIDropDownMenu_Initialize(WorldMapZoneDropDown, WorldMapZoneDropDown_Initialize);
    UIDropDownMenu_SetWidth(WorldMapZoneDropDown, 130);

    if ( (GetCurrentMapContinent() == 0) or (GetCurrentMapContinent() == WORLDMAP_COSMIC_ID) ) then
        UIDropDownMenu_ClearAll(WorldMapZoneDropDown);
    else
        UIDropDownMenu_SetSelectedID(WorldMapZoneDropDown, GetCurrentMapZone());
    end
end

function WorldMapZoneDropDown_Initialize()
    WorldMapFrame_LoadZones(GetMapZones(GetCurrentMapContinent()));
end

function WorldMapFrame_LoadZones(...)
    local info = UIDropDownMenu_CreateInfo();
    for i=1, select("#", ...), 1 do
        info.text = select(i, ...);
        info.func = WorldMapZoneButton_OnClick;
        info.checked = nil;
        UIDropDownMenu_AddButton(info);
    end
end

function WorldMapContinentButton_OnClick(self)
    UIDropDownMenu_SetSelectedID(WorldMapContinentDropDown, self:GetID());
    SetMapZoom(self:GetID());
end

function WorldMapZoneButton_OnClick(self)
    UIDropDownMenu_SetSelectedID(WorldMapZoneDropDown, self:GetID());
    SetMapZoom(GetCurrentMapContinent(), self:GetID());
end

-- WorldMapFrame_OnEvent, WORLD_MAP_UPDATE branch.
fireWorldMapUpdate = function()
    if WorldMapFrame:IsShown() then
        WorldMapContinentsDropDown_Update()
        WorldMapZoneDropDown_Update()
    end
end

local function Show(wma)
    displayed = wma
    fireWorldMapUpdate()
end

-- ------------------------------------------------------------------
-- The bug, reproduced against stock alone.
-- ------------------------------------------------------------------
print("stock (no module)")
Show(613)
ok(WorldMapContinentDropDown.text == "" and WorldMapZoneDropDown.text == "",
   "Azshara Crater (map 37, no AreaID-0 row): stock clears Continent AND Zone")
local stockContinents = OpenList(WorldMapContinentDropDown)
ok(Has(stockContinents, "Naxxramas") and Has(stockContinents, "Karazhan Crypts")
   and Has(stockContinents, "HinterlandBG - New") and Has(stockContinents, "Level Zones"),
   "stock continent list carries the raid, dungeon, battleground and test maps")

-- ------------------------------------------------------------------
-- Minimal DCQOS core: only what the module touches.
-- ------------------------------------------------------------------
_G.DCQOS = { defaults = {}, settings = {}, modules = {}, moduleOrder = {} }
function DCQOS:RegisterModule(name, config) self.modules[name] = config end
function DCQOS:GetMapUtils()
    return {
        GetMapAreaBounds = function(uiMapId)
            local r = ROW[uiMapId - 1]
            if not boundsExport or not r or r.degenerate then return nil end
            return r.map, 1, -1, 1, -1, r.area
        end,
    }
end

local leaked = {}
setmetatable(_G, { __newindex = function(t, k, v) leaked[#leaked + 1] = k rawset(t, k, v) end })
dofile(ROOT .. [[DC-QOS\Modules\WorldMapDropdowns.lua]])
setmetatable(_G, nil)
ok(#leaked == 0, "loading the module creates no globals (" .. table.concat(leaked, ",") .. ")")

local M = DCQOS.modules.WorldMapDropdowns
ok(M ~= nil and M.settingKey == "worldMapDropdowns", "module registered under its setting key")
M.OnInitialize()
M.OnEnable()

-- ------------------------------------------------------------------
-- The fix.
-- ------------------------------------------------------------------
print("continent list")
Show(613)
ok(WorldMapContinentDropDown.text == "Dark Chaos", "Azshara Crater: Continent = Dark Chaos")
ok(WorldMapZoneDropDown.text == "Azshara Crater (1-80)", "Azshara Crater: Zone = Azshara Crater (1-80)")

local continents = OpenList(WorldMapContinentDropDown)
local expected = { "Kalimdor", "Eastern Kingdoms", "Outland", "Northrend",
                   "Mount Hyjal (80-130)", "Plaguelands", "Pandaria", "Dark Chaos" }
ok(table.concat(Names(continents), "|") == table.concat(expected, "|"),
   "continent list is exactly the curated one: " .. table.concat(Names(continents), ", "))
ok(Checked(continents) == "Dark Chaos", "and Dark Chaos is the checked entry")
for _, junk in ipairs({ "Naxxramas", "Karazhan Crypts", "HinterlandBG - New", "HinterlandBG - Copy",
                        "Level Zones", "Deepholm", "Jade Forest", "Undermine" }) do
    ok(not Has(continents, junk), "no '" .. junk .. "' continent")
end

print("Dark Chaos zones")
local zones = OpenList(WorldMapZoneDropDown)
ok(table.concat(Names(zones), "|") == "Azshara Crater (1-80)|Deepholm|Isles of Giants|The Jade Forest|The Molten Front|Undermine",
   "zone list is the Dark Chaos zones: " .. table.concat(Names(zones), ", "))
ok(Checked(zones) == "Azshara Crater (1-80)", "the displayed zone is checked")

ok(Click(WorldMapZoneDropDown, "The Molten Front") and displayed == 1255, "picking The Molten Front opens WMA 1255")
ok(WorldMapContinentDropDown.text == "Dark Chaos" and WorldMapZoneDropDown.text == "The Molten Front",
   "and both dropdowns follow")

Show(640)
ok(WorldMapContinentDropDown.text == "Dark Chaos" and WorldMapZoneDropDown.text == "Deepholm",
   "Deepholm's own continent overview (native continent 5) reads Dark Chaos / Deepholm")
Show(1251)
ok(WorldMapZoneDropDown.text == "Azshara Crater (1-80)", "the Level Zones copy of Azshara Crater resolves to Azshara Crater")

print("custom continents stay native")
ok(Click(WorldMapContinentDropDown, "Mount Hyjal (80-130)") and displayed == 1262, "picking Mount Hyjal opens its continent row 1262")
ok(WorldMapContinentDropDown.text == "Mount Hyjal (80-130)" and WorldMapZoneDropDown.text == "",
   "continent overview: Continent = Mount Hyjal, Zone empty (as stock)")
ok(WorldMapZoneDropDown.initialize == WorldMapZoneDropDown_Initialize, "the zone dropdown is left to stock there")
ok(Click(WorldMapZoneDropDown, "Winterspring (104-115)") and displayed == 1256, "the stock zone list still navigates")
ok(WorldMapContinentDropDown.text == "Mount Hyjal (80-130)" and WorldMapZoneDropDown.text == "Winterspring (104-115)",
   "Mount Hyjal / Winterspring")
ok(Checked(OpenList(WorldMapContinentDropDown)) == "Mount Hyjal (80-130)",
   "the curated position (5) is checked, not the native index (13)")

zoomCalls = {}
ok(Click(WorldMapContinentDropDown, "Kalimdor") and displayed == 13 and zoomCalls[1] and zoomCalls[1][1] == 1,
   "picking Kalimdor goes through SetMapZoom(1)")
Show(4)
ok(WorldMapContinentDropDown.text == "Kalimdor" and WorldMapZoneDropDown.text == "Durotar", "stock zone: Kalimdor / Durotar")

print("instances and odd rows")
Show(1223)
ok(WorldMapContinentDropDown.text == "Dark Chaos" and WorldMapZoneDropDown.text == "Naxxramas",
   "Naxxramas (2921) is no longer a continent: Dark Chaos / Naxxramas")
ok(Checked(OpenList(WorldMapZoneDropDown)) == nil, "and it is not offered or checked in the zone list")
Show(1264)
ok(WorldMapContinentDropDown.text == "Dark Chaos" and WorldMapZoneDropDown.text == "Blackfathom Deeps (92-96)",
   "BFD 820 (zero-size row, no bounds) still resolves")
Show("world")
ok(WorldMapContinentDropDown.text == "" and WorldMapZoneDropDown.text == "", "World overview clears both, as stock")

print("fallbacks")
boundsExport = false
Show(1256)
ok(WorldMapContinentDropDown.text == "Mount Hyjal (80-130)", "without the bounds export, Mount Hyjal is found by native continent name")
Show(1215)
ok(WorldMapContinentDropDown.text == "Dark Chaos" and WorldMapZoneDropDown.text == "Deepholm",
   "and Deepholm by its native continent name")
boundsExport = true

setMapByIdWorks = false
Show(613)
ok(Click(WorldMapContinentDropDown, "Pandaria") and displayed == 1205, "SetMapByID failing: Pandaria is reached via SetMapZoom by name")
Show(1205)
ok(Click(WorldMapContinentDropDown, "Dark Chaos"), "Dark Chaos is clickable from a native continent")
ok(displayed == 1205, "Azshara Crater has no native route, so without SetMapByID nothing moves")
Show(613)
ok(Click(WorldMapZoneDropDown, "Deepholm") and displayed == 1215, "Deepholm is reached via its native continent + zone index")
setMapByIdWorks = true

ok(Click(WorldMapContinentDropDown, "Dark Chaos") and displayed == 1215, "Dark Chaos stays on the Dark Chaos zone already shown")
Show(1205)
ok(Click(WorldMapContinentDropDown, "Dark Chaos") and displayed == 613, "from elsewhere it opens the first Dark Chaos zone")

print("disable")
M.OnDisable()
Show(1223)
ok(WorldMapContinentDropDown.text == "Naxxramas" and WorldMapContinentDropDown.initialize == WorldMapContinentsDropDown_Initialize,
   "disabled: the next stock update puts the stock dropdowns back")

print(string.format("RESULT: %d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
