-- Mount and pet icons in DC-Collection (DC-Collection/Cache.lua "DEFINITION ICONS").
--
-- The local collection CDBC carries a full icon path for every mount and pet; the
-- server's definitions do not. dc_pet_definitions.icon is a bare file name, which
-- draws nothing, and dc_mount_definitions.icon is empty for every mount, so any
-- server definitions message used to leave pets blank and every mount on its
-- generic spell icon. Loads the real Cache.lua against a stubbed CDBC export and
-- handshake, and pins that the icons survive both routes to server data.

dofile("wowsim.lua")
local ROOT = [[K:\Dark-Chaos\DarkChaos-255-Master\Custom\Client addons needed\]]

local pass, fail = 0, 0
local function ok(c, m)
    if c then pass = pass + 1; print("  PASS " .. m)
    else fail = fail + 1; print("  FAIL " .. m) end
end

-- ------------------------------------------------------------------ stub client
_G.DCCollectionDB = {}
local logged = {}
_G.DCCollection = {
    L = {},
    definitions = {},
    collections = {},
    stats = { mounts = {}, pets = {}, heirlooms = {}, titles = {} },
    currency = {},
    CollectionType = { MOUNT = "mount", PET = "pet", HEIRLOOM = "heirloom", TRANSMOG = "transmog", TITLE = "title" },
    Debug = function() end,
    Print = function() end,
    LogNetEvent = function(_, level, tag, msg) logged[#logged + 1] = { level, tag, msg } end,
    COLLECTION_STATIC_MANIFEST = {
        types = { mounts = { requestSkip = true }, pets = { requestSkip = true } },
    },
}

-- Rows shaped like the WotLKExtensions CDBC export (entries from DCCollectionSource.csv).
_G.GetDCCollectionSources = function()
    return {
        { collectionType = 1, entryId = 300824, name = "Azure Riding Crane", spellId = 300824,
          displayId = 500824, icon = "Interface\\Icons\\ability_mount_cranemountblue" },
        { collectionType = 1, entryId = 458, name = "Brown Horse Bridle", spellId = 458, displayId = 2404 },
        { collectionType = 2, entryId = 304229, name = "Bat", itemId = 304229, displayId = 504729,
          icon = "Interface\\Icons\\ability_hunter_pet_bat" },
        { collectionType = 2, entryId = 302834, name = "Battery", itemId = 302834, displayId = 504234,
          icon = "Interface\\Icons\\inv_engineering_90_electrifiedether" },
    }
end

local sourcesState = "OK_NATIVE_DBC"
_G.DCAddonProtocol = {
    GetCapabilitySnapshot = function()
        return { serverDataFeatureStates = {
            collectionSources = { state = sourcesState, reason = "test", ir = 1, rr = 2 },
        } }
    end,
}

dofile(os.getenv("DC_CACHE_FILE") or (ROOT .. [[DC-Collection\Cache.lua]]))
local DC = _G.DCCollection

-- ----------------------------------------------------------------------- tests
print("== bare icon names become texture paths ==")
ok(DC:NormalizeIconPath("inv_pet_sleepywilly") == "Interface\\Icons\\inv_pet_sleepywilly", "bare name gets the Icons folder")
ok(DC:NormalizeIconPath("Interface\\Icons\\INV_Box_PetCarrier_01") == "Interface\\Icons\\INV_Box_PetCarrier_01",
   "a full path is left alone")
ok(DC:NormalizeIconPath("") == nil and DC:NormalizeIconPath(nil) == nil, "empty means no icon")

print("== the local catalog serves full paths ==")
DC:BootstrapLocalCollectionCDBC(true)
ok(DC.definitions.mounts[300824].icon == "Interface\\Icons\\ability_mount_cranemountblue", "downported mount icon from the CDBC")
ok(DC.definitions.mounts[458].icon == nil, "a stock mount without one keeps using its spell icon")
ok(DC:GetLocalCollectionIcon("pets", 304229) == "Interface\\Icons\\ability_hunter_pet_bat", "icon index lookup")

print("== server definitions merged over the catalog keep their icons ==")
-- The server's shapes: a pet icon as a bare name, a mount with no icon at all.
DC:CacheMergeDefinitions("pets", {
    [304229] = { name = "Bat", icon = "ability_hunter_pet_bat" },
    [302834] = { name = "Battery" },
})
DC:CacheMergeDefinitions("mounts", { [300824] = { name = "Azure Riding Crane", rarity = 4 } })
ok(DC.definitions.pets[304229].icon == "Interface\\Icons\\ability_hunter_pet_bat", "server pet icon made a path")
ok(DC.definitions.pets[302834].icon == "Interface\\Icons\\inv_engineering_90_electrifiedether",
   "pet without a server icon keeps the one it had")
ok(DC.definitions.mounts[300824].icon == "Interface\\Icons\\ability_mount_cranemountblue",
   "mount keeps its real icon instead of falling back to the spell's")
ok(logged[1] and logged[1][2] == "cdbc" and string.find(logged[1][3], "replaced the local catalog", 1, true) ~= nil,
   "the takeover is logged")

print("== a dropped catalog still supplies icons to the server data ==")
DC:BootstrapLocalCollectionCDBC(true)
logged = {}
sourcesState = "OK_RUNTIME_CACHE"
DC:ApplyCollectionDataFeaturePolicies()
ok(next(DC.definitions.mounts) == nil, "catalog definitions cleared by the runtime-cache policy")
ok(logged[1] and string.find(logged[1][3], "Local catalog dropped for", 1, true) ~= nil
   and string.find(logged[1][3], "OK_RUNTIME_CACHE", 1, true) ~= nil, "the drop is logged with the server state")
DC:CacheMergeDefinitions("mounts", { [300824] = { name = "Azure Riding Crane" } })
DC:CacheMergeDefinitions("pets", { [304229] = { name = "Bat" } })
ok(DC.definitions.mounts[300824].icon == "Interface\\Icons\\ability_mount_cranemountblue", "mount icon from the index")
ok(DC.definitions.pets[304229].icon == "Interface\\Icons\\ability_hunter_pet_bat", "pet icon from the index")

print("== a saved cache from before the fix loads with paths ==")
_G.DCCollectionDB = {
    cacheVersion = 1,
    definitionCache = { pets = { [9001] = { name = "Old", icon = "inv_pet_old" } } },
}
DC.definitions = {}
DC:LoadCache()
ok(DC.definitions.pets[9001].icon == "Interface\\Icons\\inv_pet_old", "cached bare name normalised on load")

print("")
print(string.format("RESULT: %d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
