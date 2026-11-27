-- DC-Collection re-applies the last outfit at login (Core.lua MaybeApplyLastOutfitOnLogin). Slots the server
-- refuses (code 1002 with per-slot reasons) used to stay in the saved outfit, so every login sent them again and
-- printed "Transmog apply partial". HandleError now drops the refused slots from the saved outfit when the reply
-- answers the login re-apply, prints one plain note instead of an error, and leaves later refusals alone.
-- Setup copied from test_collectionwave1.lua.
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

-- The client shows a frame CreateFrame makes, so its OnUpdate runs; the simulator does not.
local FrameMethods = getmetatable(CreateFrame("Frame")).__index
function FrameMethods:RegisterEvent(e) self._events = self._events or {}; self._events[e] = true end
local created = {}
local simCreateFrame = _G.CreateFrame
_G.CreateFrame = function(...)
    local f = simCreateFrame(...)
    f._shown = true
    created[#created + 1] = f
    return f
end

-- The native client's bridge.
local client = { sent = {}, queue = {}, revision = 0, saved = { revision = 0 } }
_G.GetDCClientCapabilities = function() return 0x1FFFFF00 end
_G.RequestNativeDcMessage = function(module, op)
    client.sent[#client.sent + 1] = "addon " .. tostring(module) .. " " .. tostring(op)
    return true
end
_G.GetNativeDcMessage = function() return nil end
_G.RequestNativeCollectionWave1 = function(op)
    client.sent[#client.sent + 1] = "wave1 " .. tostring(op)
    return true
end
_G.GetNativeCollectionWave1Snapshot = function()
    local reply = table.remove(client.queue, 1)
    if not reply then return nil end
    return reply.revision, reply.op, reply.payload
end
_G.RequestNativeCollectionSavedOutfits = function(offset, limit)
    client.sent[#client.sent + 1] = "outfits " .. tostring(offset) .. " " .. tostring(limit)
end
_G.GetNativeCollectionSavedOutfitsSnapshot = function(lastRevision)
    if not client.saved.payload then return nil end
    if tonumber(lastRevision) == client.saved.revision then return client.saved.revision end
    return client.saved.revision, client.saved.payload
end
_G.RequestNativeCollectionCommunity = function() return true end
_G.GetNativeCollectionCommunitySnapshot = function() return nil end

-- SMSG_COLLECTION_WAVE1 as the client keeps it.
local function Reply(op, payload)
    client.revision = client.revision + 1
    client.queue[#client.queue + 1] = { revision = client.revision, op = op, payload = payload }
    if op == 0x4C then
        client.saved.revision = client.saved.revision + 1
        client.saved.payload = payload
    end
end

dofile(ROOT .. [[DC-AddonProtocol\DCCompat.lua]])
local before = #created
dofile(ROOT .. [[DC-AddonProtocol\DCAddonProtocol.lua]])
dofile(ROOT .. [[DC-AddonProtocol\DCOpcodes.lua]])
local main
for i = before + 1, #created do
    if created[i]._events and created[i]._events.PLAYER_LEAVING_WORLD then main = created[i] end
end
local P = _G.DCAddonProtocol

local function Signal(channel)
    _G.event, _G.arg1 = "DC_NATIVE_DATA", channel
    main._scripts.OnEvent(main, "DC_NATIVE_DATA", channel)
end

for _, file in ipairs({ "Localization.lua", "Core.lua", "Cache.lua", "Protocol.lua" }) do
    dofile(ROOT .. [[DC-Collection\]] .. file)
end
local DC = _G.DCCollection

local clock = 100
_G.GetTime = function() return clock end
_G.GetInventoryItemID = function() return 12345 end

local printed = {}
DC.Print = function(_, msg) printed[#printed + 1] = tostring(msg) end
DC.IsProtocolReady = function() return true end
DC.Wardrobe = nil
local batches = {}
DC.ApplyTransmogBatchByEquipmentSlot = function(_, entries) batches[#batches + 1] = entries end

local function LoginReapply(slots)
    DCCollectionCharDB = { lastAppliedOutfit = { name = "test", source = "wardrobe", slots = slots } }
    DC.transmogState = {}
    DC._pendingLoginOutfitApply = true
    DC._loginOutfitApplied = nil
    DC._loginOutfitApplyExpiresAt = clock + 30
    DC:MaybeApplyLastOutfitOnLogin({})
end

local function Saved()
    return DCCollectionCharDB.lastAppliedOutfit.slots
end

print("== the server refuses three slots of the login re-apply ==")
LoginReapply({ ["0"] = 64429, ["3"] = 3265, ["5"] = 2125306, ["8"] = 2125356, ["16"] = 64480 })
ok(#batches == 1 and #batches[1] == 5, "the saved outfit goes out as one batch of five slots")
clock = clock + 1
DC:HandleError({ error = "Transmog apply partial 2/5", code = 1002, perSlot = {
    ["0"] = "applied", ["3"] = "no_compatible_variant", ["5"] = "not_unlocked", ["8"] = "no_compatible_variant",
    ["16"] = "applied",
} })
local s = Saved()
ok(s["0"] == 64429 and s["16"] == 64480, "applied slots stay in the saved outfit")
ok(s["3"] == nil and s["5"] == nil and s["8"] == nil, "refused slots leave the saved outfit")
ok(#printed == 1 and printed[1]:find("3 slot", 1, true) ~= nil, "one plain note names the count (" .. tostring(printed[1]) .. ")")
ok(not printed[1]:find("Error", 1, true), "the login re-apply prints no error")

print("== the next login sends only what still applies ==")
batches, printed = {}, {}
DC.transmogState = {}
DC._pendingLoginOutfitApply = true
DC._loginOutfitApplied = nil
DC._loginOutfitApplyExpiresAt = clock + 30
DC:MaybeApplyLastOutfitOnLogin({})
ok(#batches == 1 and #batches[1] == 2, "two slots are sent (" .. tostring(batches[1] and #batches[1]) .. ")")

print("== the same state as saved sends nothing ==")
batches = {}
DC._pendingLoginOutfitApply = true
DC._loginOutfitApplied = nil
DC._loginOutfitApplySentAt = nil
DC:MaybeApplyLastOutfitOnLogin({ ["0"] = 64429, ["16"] = 64480 })
ok(#batches == 0, "a matching transmog state skips the re-apply")

print("== an unrelated error in between does not use up the login marker ==")
LoginReapply({ ["0"] = 1, ["3"] = 2 })
clock = clock + 1
DC:HandleError({ error = "Something else", code = 7 })
DC:HandleError({ error = "Transmog apply partial 1/2", code = 1002, perSlot = { ["0"] = "applied", ["3"] = "no_compatible_variant" } })
ok(Saved()["3"] == nil, "the refusal that follows still prunes slot 3")

print("== a refusal the player causes afterwards is left alone ==")
printed = {}
DC:HandleError({ error = "Transmog apply partial 0/1", code = 1002, perSlot = { ["0"] = "no_compatible_variant" } })
ok(Saved()["0"] == 1, "the marker is spent: slot 0 stays")
ok(#printed == 1 and printed[1]:find("Error", 1, true) ~= nil, "it prints the normal error")

print("== a reply after the login window prunes nothing ==")
LoginReapply({ ["0"] = 1, ["3"] = 2 })
clock = clock + 20
printed = {}
DC:HandleError({ error = "Transmog apply partial 1/2", code = 1002, perSlot = { ["3"] = "no_compatible_variant" } })
ok(Saved()["3"] == 2, "slot 3 stays when the reply comes 20 s later")

print(string.format("RESULT: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
