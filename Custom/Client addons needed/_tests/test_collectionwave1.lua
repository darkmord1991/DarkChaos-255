-- DC-Collection's native wave1 channel (DC-Collection/Protocol.lua) against a client bridge double that keeps the
-- native client's contract: replies queue in arrival order and GetNativeCollectionWave1Snapshot pops the oldest;
-- a saved-outfits reply is also kept as a snapshot, and GetNativeCollectionSavedOutfitsSnapshot([lastRevision])
-- returns its revision and payload, the revision alone only when the caller passes the current one.
--   * The login handshake leaves as an addon message while the wave1 capability is still unnegotiated, and the
--     server answers it natively. Nothing drained that reply (no "Handshake acknowledged", the sync timed out),
--     because the drain only started with a native wave1 request. It now runs from load and waits for the
--     negotiation.
--   * A native saved-outfits request is answered from the snapshot, and the background sync stops asking.
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
local CAPS_BEFORE_WAVE1 = 0x0C000083
local CAPS_NEGOTIATED = 0x3FFFFF83

print("== the login handshake, answered natively before the wave1 bridge is negotiated ==")
local handlers = P._nativeDataHandlers and P._nativeDataHandlers.COLL_WAVE1
ok(type(handlers) == "table" and #handlers >= 1, "loading Protocol.lua subscribes a wave1 drain")
P._connected = true
P._serverCaps = CAPS_BEFORE_WAVE1
DC:InitializeProtocol()
DC:RequestHandshake()
ok(client.sent[1] == "addon COLL 1", "the handshake leaves as an addon message (" .. tostring(client.sent[1]) .. ")")
Reply(0x40, '{"serverHash":7}')
Signal("COLL_WAVE1")
advance(1.2)
ok(#client.queue == 1 and not DC._handshakeAcked, "the reply waits in the queue while the bridge is not negotiated")
P._serverCaps = CAPS_NEGOTIATED
advance(1.2)
ok(DC._handshakeAcked == true, "once negotiated, the drain hands the reply to HandleHandshakeAck")
ok(#client.queue == 0, "and the queue is empty")

print("== saved outfits over the native bridge ==")
client.sent = {}
ok(DC.Protocol:RequestSavedOutfitsPage(0, 6) == true and client.sent[1] == "outfits 0 6",
    "a page request goes out natively (" .. tostring(client.sent[1]) .. ")")
Reply(0x4C, '{"outfits":[{"id":7,"name":"Test","icon":"INV_Chest_Cloth_17","items":"{\\"ChestSlot\\":48691}"}],"offset":0,"limit":6,"total":1}')
Signal("COLL_WAVE1")
advance(1.2)
ok(type(DC.db) == "table" and type(DC.db.outfits) == "table" and #DC.db.outfits == 1,
    "the reply is applied (the background sync stops asking once DC.db.outfits is set)")
ok(DC.db.outfits[1] and type(DC.db.outfits[1].slots) == "table" and DC.db.outfits[1].slots.ChestSlot == 48691,
    "with its items parsed from the JSON string")
ok(#client.queue == 0, "the queued copy is left to the snapshot consumer, not dispatched twice")

print("== a server refusal reaches the chat frame ==")
-- DCAddon::SendError sends plain fields. A JSON handler never sees them, so every refusal used to vanish.
local printed = {}
_G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) printed[#printed + 1] = text end }
P:_DispatchNativeMessage("COLL", 0x7F, "2|That mount requires Riding 150")
ok(#printed == 1 and printed[1]:find("That mount requires Riding 150", 1, true) ~= nil,
    "a plain SMSG_ERROR prints its message once (" .. tostring(printed[1]) .. ")")
printed = {}
P:_DispatchNativeMessage("COLL", 0x7F, 'J|{"error":"From JSON","code":3}')
ok(printed[1] and printed[1]:find("From JSON", 1, true) ~= nil, "a JSON SMSG_ERROR still prints too")

print("== a shared error reaches the player once, and the net log ==")
local logged
local realLogNetEvent = P.LogNetEvent
P.LogNetEvent = function(self, level, tag, message, extra)
    if tag == "server" then logged = message end
    return realLogNetEvent(self, level, tag, message, extra)
end
printed = {}
P:_DispatchNativeMessage("GRVY", 0x1F, "1|You must release your spirit first.")
ok(#printed == 1 and printed[1]:find("[DC] Error:", 1, true) ~= nil and logged ~= nil,
    "with no module handler the library prints it, and the native path logs it (" .. tostring(logged) .. ")")
P:RegisterErrorHandler("GOMV", function(_, message) printed[#printed + 1] = "[GOMove] " .. message end)
printed = {}
P:_DispatchNativeMessage("GOMV", 0x1F, "1|Missing command id")
ok(#printed == 1 and printed[1] == "[GOMove] Missing command id",
    "a module with its own handler shows it alone (" .. tostring(printed[1]) .. ", lines " .. #printed .. ")")

print(string.format("RESULT: %d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
