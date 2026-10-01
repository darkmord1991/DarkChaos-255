-- DC-Housing catalog on Blizzard's player-housing taxonomy (DC-Housing/Core.lua,
-- UI/CatalogFrame.lua, generated Data/*.lua).
--
-- The catalog used to be split into 15 home-made keyword categories. It now
-- follows retail housing: DecorCategory -> DecorSubcategory (an item Blizzard
-- files under several subcategories is listed under each), a placement surface
-- and DataTag facets (Size, Culture, Expansion, Style, Theme, Color, Holiday)
-- that filter OR within a group and AND across groups. Loads the real generated
-- data and pins the data contract the generators must keep, the category tree,
-- the filter semantics, keyword search, and the two menus the catalog frame
-- builds from them.

dofile("wowsim.lua")
local ROOT = [[K:\Dark-Chaos\DarkChaos-255-Master\Custom\Client addons needed\DC-Housing\]]

local pass, fail = 0, 0
local function ok(c, m)
    if c then pass = pass + 1; print("  PASS " .. m)
    else fail = fail + 1; print("  FAIL " .. m) end
end

-- ------------------------------------------------------------------ stub client
local FrameMethods = getmetatable(CreateFrame("Frame")).__index
function FrameMethods:GetFrameLevel() return self._level or 1 end
function FrameMethods:SetFrameLevel(l) self._level = l end
-- Model widget calls the tiles and the preview make, recorded per widget.
function FrameMethods:SetModel(path) self._model = path end
function FrameMethods:ClearModel() self._model = nil end
function FrameMethods:SetModelScale(s) self._scale = s end
function FrameMethods:SetFacing(f) self._facing = f end
function FrameMethods:SetAlpha(a) self._alpha = a end
local TextureMethods = getmetatable(CreateFrame("Frame"):CreateTexture()).__index
function TextureMethods:SetDesaturated(d) self._desat = d end
function TextureMethods:SetAlpha(a) self._alpha = a end
_G.SetModelPitch = function(widget, pitch) widget._pitch = pitch; return 1 end

local tooltipLines = {}
_G.GameTooltip = {
    SetOwner = function() tooltipLines = {} end,
    AddLine = function(_, text) tooltipLines[#tooltipLines + 1] = text end,
    AddDoubleLine = function(_, left) tooltipLines[#tooltipLines + 1] = left end,
    SetText = function(_, text) tooltipLines = { text } end,
    Show = function() end,
    Hide = function() end,
}

-- 3.3.5's FauxScrollFrameTemplate names its bar "$parentScrollBar" and has no
-- ScrollBar key; without this the simulator's verb-prefix fallback ("Scroll...")
-- would hand the addon a function for that field.
local createFrame = CreateFrame
_G.CreateFrame = function(ftype, name, parent, tmpl)
    local f = createFrame(ftype, name, parent, tmpl)
    if tmpl == "FauxScrollFrameTemplate" then f.ScrollBar = false end
    return f
end

_G.SlashCmdList = {}
_G.UISpecialFrames = {}
_G.StaticPopupDialogs = {}
_G.tinsert = table.insert
_G.YES, _G.NO = "Yes", "No"
_G.UIParent = CreateFrame("Frame")
function UIParent:GetEffectiveScale() return 1 end
_G.GetScreenWidth = function() return 1024 end
_G.GetScreenHeight = function() return 768 end
_G.GetCursorPosition = function() return 0, 0 end
_G.IsShiftKeyDown = function() return false end
_G.FauxScrollFrame_GetOffset = function() return 0 end
_G.FauxScrollFrame_Update = function() end
_G.FauxScrollFrame_SetOffset = function() end
_G.FauxScrollFrame_OnVerticalScroll = function() end

local menuButtons = {}
_G.UIDropDownMenu_CreateInfo = function() return {} end
_G.UIDropDownMenu_AddButton = function(info, level)
    table.insert(menuButtons, { info = info, level = level })
end
_G.UIDropDownMenu_Initialize = function(frame, fn) frame._init = fn end
_G.UIDropDownMenu_SetWidth = function() end
_G.UIDropDownMenu_SetText = function(frame, text) frame._ddtext = text end
_G.CloseDropDownMenus = function() end
local toggled
_G.ToggleDropDownMenu = function(level, value, menu, anchor) toggled = { menu = menu, anchor = anchor } end

-- Load the addon's own files in TOC order, so every generated catalog tier the
-- TOC ships (HousingModels*.lua) is covered by the data-contract checks.
local tocFiles = {}
for line in io.lines(ROOT .. "DC-Housing.toc") do
    line = line:gsub("\r", "")
    if line ~= "" and not line:find("^##") then tocFiles[#tocFiles + 1] = line end
end
local dataFiles = 0
for _, file in ipairs(tocFiles) do
    if file:find("^UI\\") and file ~= [[UI\CatalogFrame.lua]] then
        -- EditMode/SocialButton need the full client; not under test here
    else
        dofile(ROOT .. file)
        if file:find("^Data\\HousingModels") then dataFiles = dataFiles + 1 end
    end
end

local DC = DCHousing
DC.Protocol = { RequestBudget = function() end, RequestList = function() end }
local DATA = DCHousingModelData
local CAT = DCHousingCategoryData

local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
local function hasTag(item, tag)
    for _, t in ipairs(item.tags) do if t == tag then return true end end
    return false
end

-- ------------------------------------------------------------ data contract
print("-- generated data follows Blizzard's taxonomy")
local parent, knownGroup = {}, {}
for _, c in ipairs(CAT.categories) do
    for _, s in ipairs(c.subcategories) do parent[s] = c.name end
end
for _, g in ipairs(CAT.filterGroups) do knownGroup[g] = true end

ok(CAT.categories[1].name == "Furnishings" and CAT.categories[2].name == "Accents",
    "categories are in Blizzard's menu order (Furnishings, Accents, ...)")
ok(dataFiles >= 3 and count(DATA) >= 1675, "the whole catalog loads (" .. count(DATA)
    .. " items from " .. dataFiles .. " HousingModels*.lua files)")

local bad = {}
for entry, item in pairs(DATA) do
    local problem
    if not (item.subcategories and #item.subcategories > 0) then
        problem = "no subcategories"
    elseif item.subcategories[1] ~= item.subcategory then
        problem = "subcategory is not the first of subcategories"
    elseif parent[item.subcategory] ~= item.category then
        problem = "category " .. tostring(item.category) .. " does not own " .. tostring(item.subcategory)
    elseif not (item.placement and item.placement >= 1 and item.placement <= 4) then
        problem = "placement " .. tostring(item.placement)
    else
        local sizes = 0
        for _, s in ipairs(item.subcategories) do
            if not parent[s] then problem = "unknown subcategory " .. s end
        end
        for _, tag in ipairs(item.tags or {}) do
            local group = tag:match("^([^:]+):.+$")
            if not knownGroup[group] then problem = "unknown tag " .. tag end
            if group == "Size" then sizes = sizes + 1 end
        end
        if sizes > 1 then problem = "several Size tags" end
    end
    if problem then bad[#bad + 1] = entry .. ": " .. problem end
end
ok(#bad == 0, "every item has a Blizzard category/subcategory, placement and known tags"
    .. (#bad > 0 and (" - e.g. " .. bad[1]) or ""))

local thumbs, badThumb, scenes, badScene = 0, nil, 0, nil
for entry, item in pairs(DATA) do
    if item.thumb then
        thumbs = thumbs + 1
        if not item.thumb:find("^Interface\\DCHousing\\Thumbs\\%d+$") then badThumb = entry end
    end
    if item.scene then
        scenes = scenes + 1
        if not CAT.scenes[item.scene] then badScene = entry end
    end
end
ok(thumbs >= 1200 and not badThumb, "Blizzard thumbnails are wired as client texture paths ("
    .. thumbs .. " items)" .. (badThumb and (" - bad on " .. badThumb) or ""))
ok(scenes > 0 and not badScene, "every per-decor scene override has its camera in the data ("
    .. scenes .. " items)")
local presetsComplete = true
for _, name in ipairs({ "Default", "Flat", "Tiny", "Small", "Medium", "Large", "Huge",
        "Ceiling", "Wall" }) do
    if not (CAT.scenePresets[name] and CAT.scenes[CAT.scenePresets[name]]) then
        presetsComplete = false
    end
end
ok(presetsComplete, "all nine retail preview presets have a camera")

-- --------------------------------------------------------------- category tree
print("-- category tree")
local tree = DC:GetCategoryTree()
local order = {}
for i, c in ipairs(CAT.categories) do order[c.name] = i end
local ordered, countsRight = true, true
for i, node in ipairs(tree) do
    if i > 1 and order[node.name] < order[tree[i - 1].name] then ordered = false end
    local n = 0
    for _, item in pairs(DATA) do
        if item.enabled then
            for _, s in ipairs(item.subcategories) do
                if parent[s] == node.name then n = n + 1 break end
            end
        end
    end
    if n ~= node.count then countsRight = false end
end
ok(#tree >= 6 and ordered, "populated categories keep Blizzard's order")
ok(countsRight, "category counts count each item once, across all its subcategories")

-- ------------------------------------------------------------------- filtering
print("-- filters and search")
local function results(query)
    local set = {}
    for _, e in ipairs(DC:GetFilteredEntries(query)) do set[e] = true end
    return set
end
local function expected(pred)
    local set = {}
    for e, item in pairs(DATA) do if item.enabled and pred(item) then set[e] = true end end
    return set
end
local function same(a, b)
    for k in pairs(a) do if not b[k] then return false end end
    for k in pairs(b) do if not a[k] then return false end end
    return true
end

local medium = results({ filters = { Size = { Medium = true } } })
ok(count(medium) > 0 and same(medium, expected(function(i) return hasTag(i, "Size:Medium") end)),
    "Size:Medium keeps exactly the medium items (" .. count(medium) .. ")")
ok(same(results({ filters = { Size = { Tiny = true, Huge = true } } }),
    expected(function(i) return hasTag(i, "Size:Tiny") or hasTag(i, "Size:Huge") end)),
    "values of one group combine with OR")
ok(same(results({ filters = { Size = { Medium = true }, Culture = { Elven = true } } }),
    expected(function(i) return hasTag(i, "Size:Medium") and hasTag(i, "Culture:Elven") end)),
    "groups combine with AND")
ok(same(results({ filters = { Size = {} } }), results({})),
    "an emptied group filters nothing")

local lighting = results({ category = "Lighting" })
ok(count(lighting) > 0 and same(lighting, expected(function(i)
    for _, s in ipairs(i.subcategories) do if parent[s] == "Lighting" then return true end end
    return false
end)), "a category lists every item filed under any of its subcategories")

local multi
for e, item in pairs(DATA) do
    if item.enabled and #item.subcategories > 1 then multi = e break end
end
ok(multi ~= nil and results({ subcategory = DATA[multi].subcategories[1] })[multi]
    and results({ subcategory = DATA[multi].subcategories[2] })[multi],
    "an item Blizzard files under two subcategories is listed under both")

local keywordHit
for e, item in pairs(DATA) do
    if item.enabled and item.keywords then
        for word in item.keywords:gmatch("%a%a%a%a+") do
            if not item.name:lower():find(word, 1, true) then keywordHit = { e, word } break end
        end
    end
    if keywordHit then break end
end
ok(keywordHit ~= nil and results({ search = keywordHit[2]:upper() })[keywordHit[1]],
    "search matches Blizzard's keyword tags, case-insensitively"
    .. (keywordHit and (" ('" .. keywordHit[2] .. "')") or ""))

local anyEntry = next(DATA)
DATA[anyEntry].enabled = false
DC._tree, DC._filterGroups = nil, nil
ok(not results({})[anyEntry], "disabled items (model not shipped) stay out of the list")
DATA[anyEntry].enabled = true
DC._tree, DC._filterGroups = nil, nil

local groups = DC:GetFilterGroups()
local sizeValues = groups[1] and groups[1].name == "Size" and table.concat(groups[1].values, ",")
ok(sizeValues == "Tiny,Small,Medium,Large,Huge", "Size values keep Blizzard's order")

-- ------------------------------------------------------------------ the menus
print("-- catalog frame menus")
DC.Catalog:Show()
local catDrop, filterMenu
-- The frame is module-local; reach it through the menu frames it created.
for _, child in ipairs(UIParent._children) do
    for _, c in ipairs(child._children or {}) do
        if c._init and not catDrop then catDrop = c elseif c._init then filterMenu = c end
    end
end
ok(catDrop ~= nil and filterMenu ~= nil, "the catalog builds a category menu and a filter menu")

menuButtons = {}
catDrop._init(catDrop, 1)
ok(menuButtons[1].info.text == "All categories"
    and menuButtons[2].info.text:find("^Furnishings %(%d+%)")
    and menuButtons[2].info.hasArrow and menuButtons[2].info.icon,
    "level 1: All categories, then Blizzard's categories with counts, icons and arrows")

menuButtons = {}
_G.UIDROPDOWNMENU_MENU_VALUE = "Lighting"
catDrop._init(catDrop, 2)
ok(menuButtons[1].info.text == "All Lighting" and menuButtons[2].info.text:find("^Large Lights"),
    "level 2: the whole category first, then its subcategories")
local wallLights
for _, b in ipairs(menuButtons) do
    if b.info.text:find("^Wall Lights") then wallLights = b end
end
wallLights.info.func()
ok(catDrop._ddtext == "Wall Lights", "picking a subcategory labels the dropdown with it")
local catalogFrame
for _, child in ipairs(UIParent._children) do if child.rows then catalogFrame = child end end
local expectedRows = DC:GetFilteredEntries({ subcategory = "Wall Lights" })
local shown, tilesRight = 0, true
for i, tile in ipairs(catalogFrame.tiles) do
    if tile.entry then
        shown = shown + 1
        if tile.entry ~= expectedRows[i] or not tile:IsShown() then tilesRight = false end
    elseif tile:IsShown() then
        tilesRight = false
    end
end
ok(shown == math.min(#expectedRows, #catalogFrame.tiles) and tilesRight,
    "the grid shows that subcategory's items in order (" .. shown .. " of "
    .. #expectedRows .. " on the first page)")
local rowsHidden = true
for _, row in ipairs(catalogFrame.rows) do if row:IsShown() then rowsHidden = false end end
ok(rowsHidden, "the text rows stay hidden in catalog mode (they list placed decorations)")

menuButtons = {}
filterMenu._init(filterMenu, 1)
ok(menuButtons[1].info.text == "Size" and menuButtons[1].info.hasArrow
    and menuButtons[#menuButtons].info.text == "Clear filters"
    and menuButtons[#menuButtons].info.disabled,
    "filter menu: one submenu per tag group, Clear filters disabled while nothing is set")

menuButtons = {}
_G.UIDROPDOWNMENU_MENU_VALUE = "Size"
filterMenu._init(filterMenu, 2)
local mediumButton
for _, b in ipairs(menuButtons) do if b.info.text == "Medium" then mediumButton = b end end
ok(mediumButton and mediumButton.info.keepShownOnClick and not mediumButton.info.checked,
    "filter values are toggles that keep the menu open")
mediumButton.info.func()
local allMedium, anyTile = true, false
for _, tile in ipairs(catalogFrame.tiles) do
    if tile.entry then
        anyTile = true
        if not (hasTag(DATA[tile.entry], "Size:Medium")
            and results({ subcategory = "Wall Lights" })[tile.entry]) then
            allMedium = false
        end
    end
end
ok(anyTile and allMedium, "the filter narrows the current subcategory's grid")

menuButtons = {}
filterMenu._init(filterMenu, 1)
ok(menuButtons[1].info.text == "Size (1)" and not menuButtons[#menuButtons].info.disabled,
    "an active value shows on its group and enables Clear filters")
menuButtons = {}
filterMenu._init(filterMenu, 2)
for _, b in ipairs(menuButtons) do if b.info.text == "Medium" then mediumButton = b end end
ok(mediumButton.info.checked == true, "the chosen value is checked when the menu reopens")

menuButtons = {}
filterMenu._init(filterMenu, 1)
menuButtons[#menuButtons].info.func()
menuButtons = {}
filterMenu._init(filterMenu, 1)
ok(menuButtons[1].info.text == "Size" and menuButtons[#menuButtons].info.disabled,
    "Clear filters resets every group")

-- ------------------------------------------------------------- grid tiles
print("-- catalog grid tiles")
local function find(pred)
    for e, item in pairs(DATA) do if item.enabled and pred(item) then return e end end
end
local withThumb = find(function(i) return i.thumb ~= nil end)
local withoutThumb = find(function(i) return i.thumb == nil end)
local tile = catalogFrame.tiles[1]
DC.Catalog:UpdateTile(tile, withThumb)
ok(tile:IsShown() and tile.icon:IsShown() and tile.icon._tex[1] == DATA[withThumb].thumb
    and not tile.model:IsShown(), "a decor with a Blizzard thumbnail shows it on its tile")
DC.Catalog:UpdateTile(tile, withoutThumb)
ok(tile.model:IsShown() and tile.model._model == DATA[withoutThumb].path
    and not tile.icon:IsShown(), "a decor without one gets a live model tile (retail's fallback)")
tile.model._model = "sentinel"
DC.Catalog:UpdateTile(tile, withoutThumb)
ok(tile.model._model == "sentinel", "showing the same item again does not reload the tile's model")
DC.Catalog:UpdateTile(tile, nil)
ok(not tile:IsShown(), "a tile past the end of the list hides")

local heavy = find(function(i)
    return i.thumb and (i.weight or 1) >= 2 and (i.minLevel or 1) <= 1
end)
DC.budget.houseLevel, DC.budget.cap, DC.budget.used = 1, 100, 99
DC.Catalog:UpdateTile(tile, heavy)
ok(tile.icon._desat == true and tile.icon._alpha == 0.5,
    "an item over the remaining budget is greyed out, as retail greys unplaceable decor")
tile:GetScript("OnEnter")(tile)
local saysWhy = false
for _, line in ipairs(tooltipLines) do
    if line == DCHousingLocale.OVER_BUDGET then saysWhy = true end
end
ok(tooltipLines[1] == DATA[heavy].name and saysWhy, "the tile tooltip names the item and says why")
DC.budget.houseLevel, DC.budget.cap, DC.budget.used = 0, 0, 0
DC.Catalog:UpdateTile(tile, heavy)
ok(tile.icon._desat == false and tile.icon._alpha == 1, "without budget data nothing is greyed")

-- --------------------------------------------------------- preview camera
print("-- preview camera presets")
local function near(a, b) return math.abs(a - b) < 1e-3 end
local p, z, s = DC:GetPreviewCamera({ placement = 4, tags = { "Size:Medium" } })
ok(near(p, 0.4189) and near(z, 2.0), "rugs use the Flat preset: 24 degrees down, zoom 2")
p = DC:GetPreviewCamera({ placement = 3, tags = {} })
ok(near(p, -0.2967), "ceiling pieces are seen from 17 degrees below")
p, z = DC:GetPreviewCamera({ placement = 1, tags = { "Size:Tiny" } })
ok(near(p, 0.2094) and near(z, 5.0), "tiny floor items use the Tiny preset")
p, z = DC:GetPreviewCamera({ placement = 2, tags = { "Size:Huge" } })
ok(near(p, 0) and near(z, 3.5), "the placement preset wins over Size (a huge wall piece uses Wall)")
p, z, s = DC:GetPreviewCamera({ placement = 4, scene = 1554, tags = {} })
ok(near(p, 0.2094) and near(z, 1.0) and near(s, 0.4), "a decor's own scene overrides the presets")
p, z = DC:GetPreviewCamera({ placement = 1, tags = {} })
ok(near(p, 0) and near(z, 3.5), "anything else uses the default scene")

local rug = find(function(i) return i.placement == 4 end)
DC.Catalog:UpdateTile(tile, rug)
tile:GetScript("OnClick")(tile)
local preview = catalogFrame.preview
ok(near(preview._pitch, (DC:GetPreviewCamera(DATA[rug]))) and near(preview._facing, 0.52)
    and preview._model == DATA[rug].path,
    "selecting a rug loads it tilted to its scene's pitch, 30 degrees off front")

local s0 = preview._scale
catalogFrame.previewControls.zoomIn:GetScript("OnClick")()
ok(near(preview._scale, s0 * 1.2), "zoom in enlarges the preview")
catalogFrame.previewControls.reset:GetScript("OnClick")()
ok(near(preview._scale, s0) and near(preview._pitch, (DC:GetPreviewCamera(DATA[rug]))),
    "reset returns to the scene's framing")
local f0 = preview._facing
catalogFrame.previewControls.rotateLeft:GetScript("OnMouseDown")()
preview:GetScript("OnUpdate")(preview, 0.2)
local f1 = preview._facing
catalogFrame.previewControls.rotateLeft:GetScript("OnMouseUp")()
preview:GetScript("OnUpdate")(preview, 0.2)
ok(f1 > f0 and preview._facing == f1, "holding rotate-left spins the model; releasing stops it")

DC.Catalog:SetMode("placed")
local gridShown = false
for _, t in ipairs(catalogFrame.tiles) do if t:IsShown() then gridShown = true end end
ok(not gridShown, "manage-placed mode hides the grid")
DC.Catalog:SetMode("catalog")

print(string.format("RESULT %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
