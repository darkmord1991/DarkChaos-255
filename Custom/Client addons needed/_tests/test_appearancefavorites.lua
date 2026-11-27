-- Transmog appearance favorites (collection type 6), end to end on the client:
-- DC-Collection/Protocol.lua ("Appearance favorites"), Modules/TransmogModule.lua and
-- the Wardrobe grid (UI/Wardrobe/WardrobeItems.lua, WardrobeUI.lua). The server
-- refused type 6 and nothing in the Wardrobe offered favoriting, so
-- TransmogModule:ToggleFavorite had no callers.
--   * Favorites are keyed by display id. The full collection lists them under
--     favorites.transmog, usually before the owned appearances arrive; they wait
--     until the collected-appearances reply builds collections.transmog, and every
--     rebuild of that table keeps the flags.
--   * A toggle goes out as CMSG_SET_FAVORITE type 6 with the display id and is
--     confirmed or put back by SMSG_DELTA_SYNC, like the other types.
--   * The Wardrobe's right-click menu offers Favorite / Unfavorite on collected
--     appearances, tiles show a star, and the Filter menu's "Favorites only"
--     narrows the grid (with the other filters still applied) on both the Lua
--     catalog and the native catalog, which is then looked up by display id.
dofile("wowsim.lua")
local ROOT = [[K:\Dark-Chaos\DarkChaos-255-Master\Custom\Client addons needed\]]
local pass, fail = 0, 0
local function ok(c, m)
    if c then pass = pass + 1; print("  PASS " .. m) else fail = fail + 1; print("  FAIL " .. m) end
end

-- Lua 5.1 globals the addons use that a newer interpreter lacks.
_G.unpack = _G.unpack or table.unpack
_G.loadstring = _G.loadstring or load
math.pow = math.pow or function(a, b) return a ^ b end

_G.UIParent = CreateFrame("Frame")
_G.SlashCmdList = {}
_G.time = os.time
_G.date = os.date
_G.GetLocale = function() return "enUS" end
_G.UnitName = function() return "Tester" end
_G.UnitGUID = function() return "0x123" end
_G.UnitExists = function() return true end
_G.GetRealmName = function() return "DC" end
_G.GetBuildInfo = function() return "3.3.5", "12340", "date", 30300 end
_G.GetAddOnMetadata = function() return "2.0.0" end
_G.IsAddOnLoaded = function() return false end
_G.LoadAddOn = function() return false, 2 end
_G.RegisterAddonMessagePrefix = function() end
_G.InterfaceOptions_AddCategory = function() end
_G.GameTooltip = CreateFrame("Frame")
_G.tinsert, _G.tremove = table.insert, table.remove
_G.strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
_G.strlower = string.lower
_G.strsplit = function(sep, s)
    local out = {}
    for part in string.gmatch(s, "([^" .. sep .. "]+)") do out[#out + 1] = part end
    return unpack(out)
end
_G.hooksecurefunc = function() end
_G.SendAddonMessage = function() end
_G.GetItemInfo = function(id) return "Item " .. tostring(id), "link", 4, 200 end
_G.GetItemIcon = function() return "Interface\\Icons\\INV_Misc_QuestionMark" end
_G.GetInventorySlotInfo = function() return 1 end
_G.InCombatLockdown = function() return false end
_G.UnitAffectingCombat = function() return false end
_G.UnitClass = function() return "Mage", "MAGE" end
_G.UnitRace = function() return "Human", "Human" end
_G.UnitLevel = function() return 80 end
_G.UnitFactionGroup = function() return "Alliance" end
_G.GetNumCompanions = function() return 0 end
_G.IsShiftKeyDown = function() return false end
_G.IsAltKeyDown = function() return false end

local lastMenu
_G.EasyMenu = function(menu) lastMenu = menu end

dofile(ROOT .. [[DC-AddonProtocol\DCCompat.lua]])
dofile(ROOT .. [[DC-AddonProtocol\DCAddonProtocol.lua]])
dofile(ROOT .. [[DC-AddonProtocol\DCOpcodes.lua]])
for _, file in ipairs({ "Localization.lua", "Core.lua", "Cache.lua", "Protocol.lua",
    [[Modules\TransmogModule.lua]], [[UI\Wardrobe\WardrobeUI.lua]], [[UI\Wardrobe\WardrobeItems.lua]] }) do
    dofile(ROOT .. [[DC-Collection\]] .. file)
end
local DC = _G.DCCollection
local Wardrobe = DC.Wardrobe
_G.DCCollectionDB = _G.DCCollectionDB or {}
_G.DCCollectionCharDB = _G.DCCollectionCharDB or {}

local sent, printed = {}, {}
DC.SendMessage = function(_, opcode, payload)
    sent[#sent + 1] = { opcode = opcode, payload = payload }
    return true
end
DC.Print = function(_, msg) printed[#printed + 1] = tostring(msg) end

local function fav(id)
    local entry = DC.collections.transmog and DC.collections.transmog[id]
    return entry and entry.is_favorite == true or false
end

print("== favorites arrive with the full collection, before the owned appearances ==")
DC.collections.transmog = {}
DC:HandleFullCollection({
    collections = { mounts = { 101 } },
    favorites = { mounts = {}, transmog = { 1001, 1003 } },
    transmogDeferred = true,
    hash = 1,
})
ok(DC.collections.transmog[1001] == nil, "appearance 1001 is not owned yet")
DC:HandleCollectedAppearances({ appearances = { 1001, 1002, 1003, 1004 }, syncVersion = 7 })
ok(fav(1001) and fav(1003), "the collected-appearances reply gets favorites 1001 and 1003")
ok(not fav(1002) and not fav(1004), "and nothing else")
ok(DC._pendingAppearanceFavorites == nil, "nothing is left waiting")

print("== a rebuild of the owned appearances keeps the flags ==")
DC:HandleCollectedAppearances({ appearances = { 1001, 1002, 1003, 1004, 1005 }, syncVersion = 8 })
ok(fav(1001) and fav(1003) and not fav(1005), "flags survive the new appearance list")
DC:HandleCollectedAppearances({ upToDate = true, syncVersion = 8 })
ok(fav(1001) and fav(1003), "and the up-to-date reply")

print("== toggling through TransmogModule:ToggleFavorite ==")
sent = {}
DC.TransmogModule:ToggleFavorite(1002)
ok(fav(1002), "appearance 1002 is a favorite at once")
ok(#sent == 1 and sent[1].opcode == DC.Opcodes.CMSG_SET_FAVORITE, "CMSG_SET_FAVORITE is sent")
ok(sent[1] and sent[1].payload.type == 6 and sent[1].payload.entryId == 1002
    and sent[1].payload.favorite == true, "with type 6, display id 1002, favorite=true")
sent = {}
DC.TransmogModule:ToggleFavorite("1001")
ok(not fav(1001), "a string display id toggles the same entry off")
ok(sent[1] and sent[1].payload.entryId == 1001 and sent[1].payload.favorite == false,
    "and sends favorite=false for 1001")
ok(DC.TransmogModule:IsFavorite(1002) and not DC.TransmogModule:IsFavorite(1001), "TransmogModule:IsFavorite agrees")

print("== the server's reply on SMSG_DELTA_SYNC ==")
printed = {}
DC:HandleDeltaSync({ favorites = { transmog = { ["1002"] = true } } })
ok(fav(1002), "a confirmed favorite stays")
DC:RequestSetFavorite("transmog", 1004, true)
DC:HandleDeltaSync({ favorites = { transmog = { ["1004"] = false } },
    favoriteError = "Only collected entries can be marked as favorites." })
ok(not fav(1004), "a refused favorite is put back")
ok(printed[1] == "Only collected entries can be marked as favorites.", "and the reason is shown")
ok(DC.collections.transmog[1004] ~= nil, "the appearance itself stays collected")

print("== SMSG_COLLECTION for appearances ==")
DC:HandleCollection({
    type = "transmog",
    favoritesIncluded = true,
    items = { ["1001"] = { owned = true, is_favorite = true }, ["1002"] = { owned = true },
        ["1003"] = { owned = true }, ["1004"] = { owned = true }, ["1005"] = { owned = true } },
})
ok(fav(1001) and not fav(1002) and not fav(1003), "with favoritesIncluded the entry flags are the truth")
DC:HandleCollection({ type = "transmog", items = { ["1001"] = { owned = true }, ["1003"] = { owned = true } } })
ok(fav(1001), "an older server's payload keeps the cached flag")

print("== full collections, newer and older server ==")
DC:HandleFullCollection({ collections = { mounts = { 101 } }, hash = 2 })
ok(fav(1001), "no favorites list: cached appearance flags stay")
DC:HandleFullCollection({ collections = { mounts = { 101 } }, favorites = { mounts = {} }, hash = 3 })
ok(fav(1001), "a favorites list without transmog (server before this change) keeps them too")
DC:HandleFullCollection({ collections = { mounts = { 101 } }, favorites = { transmog = { 1003, 1005 } }, hash = 4 })
ok(not fav(1001) and fav(1003) and fav(1005), "a transmog list replaces the flags")
ok(DC._pendingAppearanceFavorites == nil, "all of them owned, so none wait")
local ids = DC:GetFavoriteAppearanceIds()
ok(#ids == 2 and ids[1] == 1003 and ids[2] == 1005, "GetFavoriteAppearanceIds is sorted")

print("== a favorite toggled while waiting is not undone by the rebuild ==")
DC:HandleFullCollection({ collections = { mounts = { 101 } }, favorites = { transmog = { 1003, 2000 } }, hash = 5 })
ok(DC._pendingAppearanceFavorites ~= nil, "favorite 2000 has no appearance yet, so the set waits")
DC:RequestSetFavorite("transmog", 1003, false)
DC:HandleCollectedAppearances({ appearances = { 1001, 1002, 1003, 1004, 1005, 2000 }, syncVersion = 9 })
ok(fav(2000), "the waiting favorite lands on its appearance")
ok(not fav(1003), "and the unfavorite made in between holds")

-- ---------------------------------------------------------------------------
-- Wardrobe grid
-- ---------------------------------------------------------------------------
local function newButton()
    local btn = CreateFrame("Button")
    btn.icon = btn:CreateTexture()
    btn.notCollected = btn:CreateTexture()
    btn.wishOverlay = btn:CreateTexture()
    btn.selected = btn:CreateTexture()
    return btn
end

local frame = CreateFrame("Frame")
frame.gridButtons = {}
for i = 1, 6 do frame.gridButtons[i] = newButton() end
frame.collectedFrame = CreateFrame("Frame")
frame.collectedFrame.text = frame.collectedFrame:CreateTexture()
frame.collectedFrame.bar = CreateFrame("StatusBar")
frame.pageText = frame:CreateTexture()
frame.prevBtn = CreateFrame("Button")
frame.nextBtn = CreateFrame("Button")
Wardrobe.frame = frame
Wardrobe.ITEMS_PER_PAGE = 6
Wardrobe.currentPage = 1
Wardrobe.currentTab = "items"
Wardrobe.showUncollected = true
Wardrobe.IsWishlistedTransmog = function() return false end
Wardrobe.GetSubtypeFilterArgs = function() return -1, "", nil end
Wardrobe.HasNativeSubtypeFilter = function() return false end

-- Lua catalog: item-keyed definitions, one appearance each.
local HEAD, CHEST = 1, 5
DC.definitions.transmog = {
    [5001] = { itemId = 5001, displayId = 1001, name = "Cowl of Ash", inventoryType = HEAD, quality = 4 },
    [5002] = { itemId = 5002, displayId = 1002, name = "Ember Robe", inventoryType = CHEST, quality = 3 },
    [5003] = { itemId = 5003, displayId = 1003, name = "Ash Hood", inventoryType = HEAD, quality = 3 },
    [5005] = { itemId = 5005, displayId = 1005, name = "Ember Vest", inventoryType = CHEST, quality = 4 },
    [5009] = { itemId = 5009, displayId = 1009, name = "Unowned Helm", inventoryType = HEAD, quality = 4 },
}
DC:HandleFullCollection({ collections = { mounts = { 101 } }, favorites = { transmog = { 1003, 1005 } }, hash = 6 })

local function shown()
    local out = {}
    for _, btn in ipairs(frame.gridButtons) do
        if btn:IsShown() and btn.itemData then out[#out + 1] = btn.itemData.displayId end
    end
    return out
end
local function starOn(displayId)
    for _, btn in ipairs(frame.gridButtons) do
        if btn:IsShown() and btn.itemData and btn.itemData.displayId == displayId then
            return btn.favoriteMark ~= nil and btn.favoriteMark:IsShown()
        end
    end
    return false
end

print("== the grid without the filter ==")
Wardrobe:RefreshGrid()
ok(#shown() == 5, "all five appearances are listed")
ok(starOn(1003) and starOn(1005), "favorites carry a star")
ok(not starOn(1001) and not starOn(1009), "others do not")

print("== the right-click menu ==")
local function menuEntry(label)
    for _, entry in ipairs(lastMenu or {}) do
        if entry.text == label then return entry end
    end
end
local function itemFor(displayId)
    for _, entry in ipairs(Wardrobe.appearanceList) do
        if entry.displayId == displayId then return entry end
    end
end
Wardrobe:ShowAppearanceContextMenu(itemFor(1001))
local favEntry = menuEntry("Favorite")
ok(favEntry ~= nil and menuEntry("Unfavorite") == nil, "a collected appearance offers Favorite")
sent = {}
favEntry.func()
ok(sent[1] and sent[1].payload.type == 6 and sent[1].payload.entryId == 1001 and sent[1].payload.favorite == true,
    "choosing it sends type 6 for display id 1001")
ok(fav(1001), "and marks it at once")
Wardrobe:ShowAppearanceContextMenu(itemFor(1003))
ok(menuEntry("Unfavorite") ~= nil and menuEntry("Favorite") == nil, "a favorite offers Unfavorite")
Wardrobe:ShowAppearanceContextMenu(itemFor(1009))
ok(menuEntry("Favorite") == nil and menuEntry("Unfavorite") == nil, "an uncollected appearance offers neither")
Wardrobe:ShowAppearanceContextMenu({ id = "hide", itemId = 0, displayId = 0, collected = true, isHideOption = true })
ok(menuEntry("Favorite") == nil, "nor does the Hide Slot cell")

print("== Favorites only, Lua catalog ==")
local filterBtn = CreateFrame("Button")
Wardrobe:ShowSlotFilterMenu(filterBtn)
local toggle = menuEntry("Favorites only")
ok(toggle ~= nil and toggle.checked == false and toggle.isNotRadio, "the Filter menu offers Favorites only, unchecked")
toggle.func()
ok(Wardrobe.showFavoritesOnly == true, "choosing it turns the filter on")
local list = shown()
table.sort(list)
ok(#list == 3 and list[1] == 1001 and list[2] == 1003 and list[3] == 1005, "the grid shows only favorites 1001, 1003, 1005")
ok(frame.collectedFrame.text._text == "Favorites: 3", "the counter reads Favorites: 3")
Wardrobe.selectedSlotFilter = { label = "Head", invTypes = { [HEAD] = true } }
Wardrobe:RefreshGrid()
list = shown()
table.sort(list)
ok(#list == 2 and list[1] == 1001 and list[2] == 1003, "with the Head slot only the head favorites")
Wardrobe.searchText = "hood"
Wardrobe:RefreshGrid()
list = shown()
ok(#list == 1 and list[1] == 1003, "and the search still applies")
Wardrobe.searchText = nil
Wardrobe.selectedSlotFilter = nil
DC:HandleDeltaSync({ favorites = { transmog = { ["1005"] = false } } })
Wardrobe:RefreshGrid()
list = shown()
table.sort(list)
ok(#list == 2 and list[1] == 1001 and list[2] == 1003, "an unfavorited appearance leaves the filtered grid")

print("== Favorites only, native catalog ==")
local nativeRows = {
    [1001] = { id = 1001, displayId = 1001, itemId = 5001, inventoryType = HEAD, quality = 4, name = "Cowl of Ash" },
    [1003] = { id = 1003, displayId = 1003, itemId = 5003, inventoryType = HEAD, quality = 3, name = "Ash Hood" },
}
local pagedQueries = 0
DC.HasNativeTransmogCatalog = function() return true end
_G.QueryDCCollectionTransmog = function() pagedQueries = pagedQueries + 1; return {}, 0, 0 end
_G.QueryDCCollectionTransmogEx = _G.QueryDCCollectionTransmog
_G.GetDCCollectionTransmogByDisplayId = function(displayId)
    local row = nativeRows[displayId]
    if not row then return nil end
    local copy = {}
    for k, v in pairs(row) do copy[k] = v end
    return copy
end
Wardrobe:RefreshGrid()
list = shown()
table.sort(list)
ok(#list == 2 and list[1] == 1001 and list[2] == 1003, "favorites are looked up by display id")
ok(pagedQueries == 0, "without paging the whole catalog")
ok(starOn(1001) and starOn(1003), "and both carry a star")
Wardrobe.selectedQualityFilter = 3
Wardrobe:RefreshGrid()
list = shown()
ok(#list == 1 and list[1] == 1003, "the quality filter applies to them")
Wardrobe.selectedQualityFilter = nil

print("== turning the filter off ==")
Wardrobe:ShowSlotFilterMenu(filterBtn)
toggle = menuEntry("Favorites only")
ok(toggle and toggle.checked == true, "the menu shows it checked")
toggle.func()
ok(Wardrobe.showFavoritesOnly == false, "choosing it again turns it off")
ok(pagedQueries > 0, "and the grid pages the catalog again")
Wardrobe.currentTab = "sets"
Wardrobe:ShowSlotFilterMenu(filterBtn)
ok(menuEntry("Favorites only") == nil, "the Sets tab's Filter menu does not offer it")

print(string.format("RESULT %d passed, %d failed", pass, fail))
if fail > 0 then
    os.exit(1)
end
