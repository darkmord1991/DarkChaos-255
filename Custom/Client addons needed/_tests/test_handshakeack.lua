-- DCAddonProtocol CORE 0x10 handshake ACK, fed through the library's own
-- CHAT_MSG_ADDON handling (no mocked snapshot).
--
-- The server writes the ACK as BuildVersionString(serverVersion) + compatible +
-- negotiatedCaps + metadata, and BuildVersionString is "major.minor.patch|caps",
-- so the wire has five fields: version|serverCaps|compatible|negotiated|meta
-- (dc_addon_protocol_log id 4515081). The handler used to read the metadata from
-- the 4th field (the negotiated caps), so the server's data policy (the stale
-- CDBC guard DC-Collection reads) was dropped on every login.
--
-- Usage: lua test_handshakeack.lua [path-to-DCAddonProtocol.lua]
-- (the optional path lets an older copy be checked for the regression).
dofile("wowsim.lua")
local ROOT = [[K:\Dark-Chaos\DarkChaos-255-Master\Custom\Client addons needed\]]
local PROTOCOL_FILE = (arg and arg[1]) or (ROOT .. [[DC-AddonProtocol\DCAddonProtocol.lua]])
local pass, fail = 0, 0
local function ok(c, m)
    if c then pass = pass + 1; print("  PASS " .. m) else fail = fail + 1; print("  FAIL " .. m) end
end

-- Lua 5.1 globals the protocol uses that a newer interpreter lacks.
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
_G.GetItemInfo = function() return nil end

local chatOut = {}
_G.SendAddonMessage = function(_, msg) chatOut[#chatOut + 1] = msg end

-- Frames record the events they register, so the test can find the frame that
-- receives CHAT_MSG_ADDON.
local FrameMethods = getmetatable(CreateFrame("Frame")).__index
function FrameMethods:RegisterEvent(e) self._events = self._events or {}; self._events[e] = true end
local created = {}
local simCreateFrame = _G.CreateFrame
_G.CreateFrame = function(...) local f = simCreateFrame(...); created[#created + 1] = f; return f end

dofile(ROOT .. [[DC-AddonProtocol\DCCompat.lua]])
_G.DCAddonProtocol = nil
local before = #created
dofile(PROTOCOL_FILE)
dofile(ROOT .. [[DC-AddonProtocol\DCOpcodes.lua]])

local chatFrame
for i = before + 1, #created do
    local f = created[i]
    if f._events and f._events.CHAT_MSG_ADDON and f._scripts and f._scripts.OnEvent then
        chatFrame = f
        break
    end
end
local DC = _G.DCAddonProtocol
ok(DC ~= nil and chatFrame ~= nil, "protocol loaded and its CHAT_MSG_ADDON frame found")

-- Sends a handshake (an ACK is only accepted while one is pending), then
-- delivers the ACK exactly as the client receives a server whisper.
local function deliverAck(ack)
    DC._lastHandshakeSentAt = nil
    DC:SendHandshake("manual-test")
    DC._serverHandshakeMetadata = nil
    DC._serverDataFeatureStates = nil
    DC._lastHandshakeAck = nil
    _G.event, _G.arg1, _G.arg2, _G.arg3, _G.arg4 = "CHAT_MSG_ADDON", "DC", ack, "WHISPER", "Tester"
    chatFrame._scripts.OnEvent(chatFrame, "CHAT_MSG_ADDON", "DC", ack, "WHISPER", "Tester")
    return DC._lastHandshakeAck or {}
end

-- The live ACK. The first 256 bytes are the logged row 4515081 verbatim; the
-- rest follows the server's builder (dc_addon_protocol.cpp, keys in the order
-- the encoder writes them), with collectionSources made stale so the policy
-- has something to say.
local META = '{"dataFeatureStates":{"collectionCategories":{"fallbackAllowed":false,'
    .. '"installedRevision":1684590543,"reason":"revision-match","requiredRevision":1684590543,'
    .. '"state":"OK_NATIVE_DBC"},"collectionSets":{"fallbackAllowed":true,"reason":"virtual-sets",'
    .. '"requiredRevision":0,"state":"OK_RUNTIME_CACHE"},"collectionShop":{"fallbackAllowed":true,'
    .. '"installedRevision":77,"reason":"revision-match","requiredRevision":77,"state":"OK_NATIVE_DBC"},'
    .. '"collectionSources":{"fallbackAllowed":true,"installedRevision":4,"reason":"revision-mismatch",'
    .. '"requiredRevision":5,"state":"STALE_REVISION"},"collectionTransmog":{"fallbackAllowed":true,'
    .. '"installedRevision":9,"reason":"revision-match","requiredRevision":9,"state":"OK_NATIVE_DBC"}},"v":1}'
local LIVE_ACK = "CORE|16|RID:1793533324-0-1|2.0.0|2147483523|1|2147483523|" .. META

print("== live five-field ACK ==")
local ack = deliverAck(LIVE_ACK)
ok(ack.parserMode == "pipe-new-servercaps", "parser mode is pipe-new-servercaps (" .. tostring(ack.parserMode) .. ")")
ok(DC._connected == true, "handshake completes")
ok(tonumber(DC._serverCaps) == 2147483523, "negotiated caps come from the 4th field")
ok(type(DC._serverHandshakeMetadata) == "table", "metadata is parsed from the 5th field")
local states = DC._serverDataFeatureStates
ok(type(states) == "table", "server data feature states are stored")
ok(states and states.collectionSources and states.collectionSources.state == "STALE_REVISION",
    "collectionSources reports STALE_REVISION")
ok(states and states.collectionSources and states.collectionSources.requiredRevision == 5
    and states.collectionSources.installedRevision == 4, "revisions of the stale feature survive")
ok(states and states.collectionSets and states.collectionSets.state == "OK_RUNTIME_CACHE",
    "collectionSets reports OK_RUNTIME_CACHE")
ok(states and states.collectionCategories and states.collectionCategories.state == "OK_NATIVE_DBC",
    "collectionCategories reports OK_NATIVE_DBC")
local snapshot = DC:GetCapabilitySnapshot()
ok(type(snapshot.serverDataFeatureStates) == "table"
    and snapshot.serverDataFeatureStates.collectionSources ~= nil,
    "GetCapabilitySnapshot hands the policy to DC-Collection")

print("== metadata containing a pipe ==")
local pipeMeta = '{"dataFeatureStates":{"collectionShop":{"state":"STALE_REVISION",'
    .. '"requiredRevision":3,"installedRevision":2,"fallbackAllowed":true,"reason":"a|b"}},"v":1}'
ack = deliverAck("CORE|16|RID:1-0-2|2.0.0|2147483523|1|2147483523|" .. pipeMeta)
states = DC._serverDataFeatureStates
ok(states and states.collectionShop and states.collectionShop.reason == "a|b",
    "fields after the 5th are joined back into the JSON")

print("== servercaps ACK without metadata (older server) ==")
ack = deliverAck("CORE|16|RID:1-0-3|2.0.0|2147483523|1|2147483523")
ok(ack.parserMode == "pipe-new-servercaps", "parser mode is pipe-new-servercaps")
ok(tonumber(DC._serverCaps) == 2147483523, "negotiated caps parsed")
ok(DC._serverHandshakeMetadata == nil, "no metadata, no policy")

print("== four-field pipe-new ACK (version|compatible|negotiated|meta) ==")
ack = deliverAck("CORE|16|RID:1-0-4|2.0.0|1|2147483523|" .. META)
ok(ack.parserMode == "pipe-new", "parser mode is pipe-new (" .. tostring(ack.parserMode) .. ")")
ok(tonumber(DC._serverCaps) == 2147483523, "negotiated caps from the 3rd field")
ok(DC._serverDataFeatureStates and DC._serverDataFeatureStates.collectionSources ~= nil,
    "metadata from the 4th field")

print("== pipe-new ACK whose negotiated caps read like a flag ==")
ack = deliverAck("CORE|16|RID:1-0-5|2.0.0|1|1|" .. META)
ok(ack.parserMode == "pipe-new", "JSON in the 4th field is not taken for negotiated caps ("
    .. tostring(ack.parserMode) .. ")")
ok(tonumber(DC._serverCaps) == 1, "negotiated caps 1")
ok(DC._serverDataFeatureStates and DC._serverDataFeatureStates.collectionSources ~= nil,
    "metadata still parsed")

print(string.format("RESULT %d passed, %d failed", pass, fail))
if fail > 0 then
    os.exit(1)
end
