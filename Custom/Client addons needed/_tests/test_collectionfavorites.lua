-- DC-Collection favorites (DC-Collection/Protocol.lua, "FAVORITES"), through the real
-- message handlers. Favorites used to be write-only: the server never sent them back
-- and nothing on the client set is_favorite, so Favorite / Unfavorite did nothing and
-- the context menu always offered "Favorite".
--   * A toggle updates the cache at once and sends CMSG_SET_FAVORITE with the new state.
--   * SMSG_DELTA_SYNC "favorites" confirms or reverts it; "favoriteError" is shown.
--   * SMSG_COLLECTION carries is_favorite per entry; with "favoritesIncluded" those
--     flags are the truth, without it (an older server) the cached flags are kept.
--   * SMSG_FULL_COLLECTION carries a "favorites" id list per type, the same rule.
dofile("wowsim.lua")
local ROOT = [[K:\Dark-Chaos\DarkChaos-255-Master\Custom\Client addons needed\]]
local pass, fail = 0, 0
local function ok(c, m)
    if c then pass = pass + 1; print("  PASS " .. m) else fail = fail + 1; print("  FAIL " .. m) end
end

-- Lua 5.1 globals the addons use that a newer interpreter lacks.
_G.unpack = _G.unpack or table.unpack
math.pow = math.pow or function(a, b) return a ^ b end

_G.UIParent = CreateFrame("Frame")
_G.SlashCmdList = {}
_G.time = os.time
_G.date = os.date
_G.GetLocale = function() return "enUS" end
_G.UnitName = function() return "Tester" end
_G.UnitGUID = function() return "0x123" end
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
_G.hooksecurefunc = function() end
_G.SendAddonMessage = function() end
_G.GetItemInfo = function() return nil end
_G.InCombatLockdown = function() return false end
_G.UnitAffectingCombat = function() return false end
_G.UnitClass = function() return "Mage", "MAGE" end
_G.UnitRace = function() return "Human", "Human" end
_G.UnitLevel = function() return 80 end
_G.UnitFactionGroup = function() return "Alliance" end
_G.GetNumCompanions = function() return 0 end

dofile(ROOT .. [[DC-AddonProtocol\DCCompat.lua]])
dofile(ROOT .. [[DC-AddonProtocol\DCAddonProtocol.lua]])
dofile(ROOT .. [[DC-AddonProtocol\DCOpcodes.lua]])
for _, file in ipairs({ "Localization.lua", "Core.lua", "Cache.lua", "Protocol.lua" }) do
    dofile(ROOT .. [[DC-Collection\]] .. file)
end
local DC = _G.DCCollection

local sent, printed = {}, {}
DC.SendMessage = function(_, opcode, payload)
    sent[#sent + 1] = { opcode = opcode, payload = payload }
    return true
end
DC.Print = function(_, msg) printed[#printed + 1] = tostring(msg) end

local function fav(typeName, id)
    local entry = DC.collections[typeName] and DC.collections[typeName][id]
    return entry and entry.is_favorite == true or false
end

print("== full collection with a favorites list ==")
DC:HandleFullCollection({
    collections = { mounts = { 101, 102, 103 }, pets = { 201 }, titles = { 5 } },
    favorites = { mounts = { 102 }, pets = {}, titles = { 5 } },
    hash = 1,
})
ok(fav("mounts", 102), "mount 102 is a favorite")
ok(not fav("mounts", 101) and not fav("mounts", 103), "mounts 101 and 103 are not")
ok(fav("titles", 5), "title 5 is a favorite")

print("== a toggle is applied at once and sent ==")
sent = {}
DC:RequestToggleFavorite("mounts", 101)
ok(fav("mounts", 101), "toggling mount 101 marks it at once")
ok(#sent == 1 and sent[1].opcode == DC.Opcodes.CMSG_SET_FAVORITE, "CMSG_SET_FAVORITE is sent")
ok(sent[1] and sent[1].payload.favorite == true and sent[1].payload.entryId == 101
    and sent[1].payload.type == 1, "with type 1, entry 101, favorite=true")
sent = {}
DC:RequestToggleFavorite("mounts", 102)
ok(not fav("mounts", 102), "toggling favorite mount 102 clears it")
ok(sent[1] and sent[1].payload.favorite == false, "and sends favorite=false (it used to send true every time)")

print("== the server's confirmation on SMSG_DELTA_SYNC ==")
printed = {}
DC:HandleDeltaSync({ favorites = { mounts = { ["101"] = false } }, favoriteError = "Only collected entries can be marked as favorites." })
ok(not fav("mounts", 101), "a refused favorite is put back")
ok(printed[1] == "Only collected entries can be marked as favorites.", "and the reason is shown")
DC:HandleDeltaSync({ favorites = { pets = { ["201"] = true } } })
ok(fav("pets", 201), "a confirmed favorite is set")
ok(DC.collections.mounts[103] ~= nil, "a favorite reply adds or removes nothing")

print("== SMSG_COLLECTION from a server that sends favorites ==")
DC.collections.mounts[103].is_favorite = true -- stale local flag
DC:HandleCollection({
    type = "mounts",
    favoritesIncluded = true,
    items = { ["101"] = { owned = true, is_favorite = true }, ["102"] = { owned = true }, ["103"] = { owned = true } },
})
ok(fav("mounts", 101), "is_favorite on an entry is kept")
ok(not fav("mounts", 103), "a flag the server does not send is cleared")
DC.collections.titles[5].is_favorite = true
DC:HandleCollection({ type = "titles", favoritesIncluded = true, items = { ["5"] = { owned = true }, ["6"] = { owned = true } } })
ok(not fav("titles", 5), "titles (merged, not replaced) follow the server too")
ok(DC.collections.titles[6] ~= nil, "and the new title is there")

print("== SMSG_COLLECTION from an older server (no favorites) ==")
DC.collections.mounts[102].is_favorite = true
DC:HandleCollection({ type = "mounts", items = { ["101"] = { owned = true }, ["102"] = { owned = true } } })
ok(fav("mounts", 102), "the cached flag survives the entry being replaced")
ok(fav("mounts", 101), "on every entry")

print("== full collection from an older server ==")
DC:HandleFullCollection({ collections = { mounts = { 101, 102, 103 } }, hash = 2 })
ok(fav("mounts", 101) and fav("mounts", 102), "cached flags survive SetCollection")
ok(not fav("mounts", 103), "and nothing else becomes a favorite")

print("== the favorites filter the modules use ==")
ok(DC:IsFavorite("mounts", 102) == true, "DC:IsFavorite reads the flag")

-- Favorites are outside the collection hash. A client whose owned ids match gets
-- no full collection, so the in-sync replies carry the lists (set elsewhere).
print("== upToDate full-collection ACK with favorites ==")
DC:HandleFullCollection({
    collections = {}, upToDate = true, hash = 2,
    favorites = { mounts = { 103 }, pets = {}, heirlooms = {}, titles = {}, transmog = {} },
})
ok(fav("mounts", 103), "a favorite set on another machine arrives")
ok(not fav("mounts", 101) and not fav("mounts", 102), "and one cleared there is cleared here")
ok(DC.collections.mounts[101] ~= nil, "the owned entries stay")

print("== handshake ACK without needsSync carries favorites ==")
DC.collections.titles[6].is_favorite = true
DC:HandleHandshakeAck({ serverHash = 2, needsSync = false, totalItems = 3,
    favorites = { mounts = { 101 }, pets = { 201 } } })
ok(fav("mounts", 101) and not fav("mounts", 103), "mount favorites follow the ACK")
ok(fav("pets", 201), "pets too")
ok(fav("titles", 6), "a type the ACK leaves out keeps its flags")

print("== an older server's in-sync replies (no favorites) keep the cache ==")
DC:HandleHandshakeAck({ serverHash = 2, needsSync = false, totalItems = 3 })
DC:HandleFullCollection({ collections = {}, upToDate = true, hash = 2 })
ok(fav("mounts", 101) and fav("pets", 201), "cached flags stay")

print(string.format("RESULT %d passed, %d failed", pass, fail))
if fail > 0 then
    os.exit(1)
end
