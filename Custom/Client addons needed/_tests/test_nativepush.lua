-- DCAddonProtocol native transport, against client-DLL doubles:
--   * the 10240-byte request guard (the server drops the connection past it)
--   * DLL push events (DC_NATIVE_DATA) replacing the per-frame poll
--   * the item prefetch client (QOS CMSG_PREFETCH_ITEMS / SMSG_PREFETCH_ITEMS_RESULT)
--   * the feature flags, which used to be stored by value instead of by name
dofile("wowsim.lua")
local ROOT = [[K:\Dark-Chaos\DarkChaos-255-Master\Custom\Client addons needed\]]
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

local chat = {}
_G.SendAddonMessage = function(_, msg) chat[#chat + 1] = msg end

local itemCache = {}
_G.GetItemInfo = function(id) return itemCache[id] end

-- Frames record the events they register, so the test can find the protocol's
-- frame and see whether it listens to DC_NATIVE_DATA.
local FrameMethods = getmetatable(CreateFrame("Frame")).__index
function FrameMethods:RegisterEvent(e) self._events = self._events or {}; self._events[e] = true end
local created = {}
local simCreateFrame = _G.CreateFrame
_G.CreateFrame = function(...) local f = simCreateFrame(...); created[#created + 1] = f; return f end

-- Client DLL doubles.
local dll = { caps = 0, sent = {}, requestResult = nil, queue = {} }
_G.GetDCClientCapabilities = function() return dll.caps end
_G.RequestNativeDcMessage = function(module, op, body)
    dll.sent[#dll.sent + 1] = { module = module, op = op, body = body }
    return dll.requestResult
end
_G.GetNativeDcMessage = function()
    local e = table.remove(dll.queue, 1)
    if not e then return nil end
    return e.rev, e.module, e.op, e.body
end

dofile(ROOT .. [[DC-AddonProtocol\DCCompat.lua]])

local function LoadProtocol()
    _G.DCAddonProtocol = nil
    local before = #created
    dofile(ROOT .. [[DC-AddonProtocol\DCAddonProtocol.lua]])
    dofile(ROOT .. [[DC-AddonProtocol\DCOpcodes.lua]])
    local main
    for i = before + 1, #created do
        local f = created[i]
        if f._events and f._events.PLAYER_LEAVING_WORLD then main = f end
    end
    main:Show()
    return _G.DCAddonProtocol, main
end

local function Fire(frame, ev, a1)
    _G.event, _G.arg1 = ev, a1
    frame._scripts.OnEvent(frame, ev, a1)
end

local CAP_GENERIC = 0x04000000
local CAP_LARGE = 0x08000000
local CAP_PUSH = 0x10000000
local CAP_PREFETCH = 0x20000000

print("== push-capable DLL ==")
dll.caps = CAP_GENERIC + CAP_LARGE + CAP_PUSH
local DC, main = LoadProtocol()
ok(main._events.DC_NATIVE_DATA == true, "the protocol frame registers DC_NATIVE_DATA")
ok(DC:HasNativePushEvents(), "HasNativePushEvents reports it")
ok(DC:HasClientCapability(DC.Capability.ITEM_PREFETCH), "the Lua library advertises ITEM_PREFETCH")
ok(DC:DescribeCapabilities(CAP_LARGE + CAP_PUSH + CAP_PREFETCH)
    == "LargeNativePayload, NativePushEvents, ItemPrefetch", "the new bits have names")
DC._connected = true
DC._serverCaps = CAP_GENERIC + CAP_PREFETCH

print("== request size guard ==")
dll.sent, chat = {}, {}
ok(DC:_TryNativeSendJSON("QOS", 1, string.rep("x", 200)) == true and #dll.sent == 1,
    "a small request goes native")
ok(DC:_TryNativeSendJSON("QOS", 1, string.rep("x", 12000)) == false and #dll.sent == 1,
    "a request the server would drop the connection for is not sent natively")
dll.requestResult = false
ok(DC:_TryNativeSendJSON("QOS", 1, "{}") == false, "a DLL that refuses the packet makes the caller fall back")
dll.requestResult = nil
dll.sent, chat = {}, {}
DC:SendJSON("QOS", 6, { blob = string.rep("y", 12000) })
ok(#dll.sent == 0 and #chat >= 20, "an oversized SendJSON goes out as chunked addon chat (" .. #chat .. " chunks sent)")
DC._throttle.queue = {}

print("== push delivery ==")
local got = {}
DC:RegisterHandler("GRPF", 0x20, function(data) got[#got + 1] = data end)
dll.queue = { { rev = 1, module = "GRPF", op = 0x20, body = 'J|{"a":1}' } }
Fire(main, "DC_NATIVE_DATA", "GENERIC")
ok(#got == 1 and got[1].a == 1, "a GENERIC signal dispatches the queued message at once")
dll.queue = { { rev = 2, module = "GRPF", op = 0x20, body = 'J|{"a":2}' } }
advance(0.5)
ok(#got == 1, "no per-frame poll while pushes are active")
advance(0.6)
ok(#got == 2, "the 1 s safety net still drains a message whose signal was missed")

local consumer = 0
DC:OnNativeData("MPLUS_HUD", function(channel) if channel == "MPLUS_HUD" then consumer = consumer + 1 end end)
Fire(main, "DC_NATIVE_DATA", "MPLUS_HUD")
ok(consumer == 1, "an OnNativeData handler runs on its channel, with the channel name")
Fire(main, "DC_NATIVE_DATA", "COLL_WAVE1")
ok(consumer == 1 and #got == 2, "other channels leave it (and the core queues) alone")
ok(DC:GetNativePollInterval(0.1) == 1.0 and DC:GetNativePollInterval(3) == 3,
    "consumer polls stretch to the 1 s safety net and never shrink")

print("== loading screens ==")
Fire(main, "PLAYER_LEAVING_WORLD")
dll.queue = { { rev = 3, module = "GRPF", op = 0x20, body = 'J|{"a":3}' } }
Fire(main, "DC_NATIVE_DATA", "GENERIC")
Fire(main, "DC_NATIVE_DATA", "MPLUS_HUD")
Fire(main, "DC_NATIVE_DATA", "MPLUS_HUD")
ok(#got == 2 and consumer == 1, "nothing is dispatched while the world is loading")
Fire(main, "PLAYER_ENTERING_WORLD")
ok(#got == 3 and consumer == 2, "every signalled channel is replayed once when the world is back")

print("== feature flags ==")
DC:_DispatchNativeMessage("CORE", 0x12, "1|0|1|1|1|1|1|1|1|1")
ok(DC:HasFeature("AOE") and not DC:HasFeature("SPEC") and DC:HasFeature("QOS"),
    "positional SMSG_FEATURE_LIST flags map to module codes")
ok(DC._features["1"] == nil and DC._features["0"] == nil, "flag values are no longer stored as feature names")
local changes = {}
DC:RegisterFeatureChangeHandler(function(code, enabled, was)
    changes[#changes + 1] = code .. ":" .. tostring(enabled) .. ":" .. tostring(was)
end)
DC:_DispatchNativeMessage("CORE", 0x14,
    'J|{"seasonId":3,"seasonName":"S3","phaseMask":1,"configRevision":2,"features":{"SPEC":true,"COLL":false}}')
ok(#changes == 1 and changes[1] == "SPEC:true:false",
    "a server context re-push reports real changes only (COLL is first seen, not changed)")
ok(DC:HasFeature("SPEC") and DC._features.COLL == false, "named flags from the server context apply")
ok(DC._serverContext.configRevision == 2 and DC._serverContext.seasonId == 3, "the context keeps the config revision")

print("== item prefetch, server with ITEM_PREFETCH ==")
local results = {}
local function cb(id, okv) results[id] = okv end
local primed = {}
DC._itemPrimerTooltip = {
    SetOwner = function() end,
    SetHyperlink = function(_, link) primed[#primed + 1] = link end,
    Hide = function() end,
}
itemCache[100] = "Cached"
local ids = { 100 }
for i = 1, 170 do ids[#ids + 1] = 1000 + i end
dll.sent = {}
ok(DC:PrefetchItems(ids, cb) == 170 and results[100] == true, "a cached id calls back at once, the rest queue")
ok(DC:PrefetchItems({ 1001, 1002 }, cb) == 0, "an id already queued is not queued twice")
advance(0.02)
local requests = {}
for _, s in ipairs(dll.sent) do
    if s.module == "QOS" and s.op == 0x09 then
        requests[#requests + 1] = DC:DecodeJSON(string.sub(s.body, 3)).ids
    end
end
ok(#requests == 3 and #requests[1] == 50 and #requests[3] == 50, "three requests of 50 go out in the first second")
dll.sent = {}
advance(0.5)
ok(#dll.sent == 0, "the fourth waits for the next second")
advance(0.6)
ok(#dll.sent == 1 and #DC:DecodeJSON(string.sub(dll.sent[1].body, 3)).ids == 20, "then the remaining 20 go out")

for i = 1, 50 do if i ~= 7 then itemCache[1000 + i] = "Item" .. i end end
DC:_DispatchNativeMessage("QOS", 0x18,
    "J|" .. DC:EncodeJSON({ ids = requests[1], sent = 49, missing = { 1007 } }))
ok(results[1001] == true and results[1050] == true and results[1007] == false,
    "the reply resolves the delivered ids and fails the missing one")
local late
DC:PrefetchItems({ 1007 }, function(_, okv) late = okv end)
ok(late == false, "a missing id is answered from memory afterwards")

DC:_DispatchNativeMessage("QOS", 0x18, "J|" .. DC:EncodeJSON({ ids = requests[2], throttled = true }))
ok(DC._itemPrefetch.queued[1051] == true and DC._itemPrefetch.queue[1] == 1051,
    "a throttled batch goes back to the front of the queue, in order")

itemCache[1101] = "Item101"
DC:_DispatchNativeMessage("QOS", 0x18, "J|" .. DC:EncodeJSON({ ids = requests[3], sent = 1, missing = {} }))
ok(results[1101] == true and results[1102] == nil, "an id the reply did not deliver keeps waiting")
primed = {}
advance(2.2)
local stockQueried = false
for _, link in ipairs(primed) do if link == "item:1102" then stockQueried = true end end
ok(stockQueried, "two seconds later it is queried the stock way")
advance(10.2)
ok(results[1102] == false, "and fails if that brings nothing either")

print("== item prefetch, older server ==")
DC._serverCaps = CAP_GENERIC
dll.sent, primed = {}, {}
DC:PrefetchItems({ 5001, 5002 }, cb)
advance(0.02)
ok(#dll.sent == 0 and #primed == 2, "without ITEM_PREFETCH each id is queried the stock way")
itemCache[5001] = "Item5001"
advance(0.2)
ok(results[5001] == true, "and resolves when the client's own query lands")

print("== older DLL ==")
main:Hide()
dll.caps = CAP_GENERIC
local DC2, main2 = LoadProtocol()
ok(not (main2._events and main2._events.DC_NATIVE_DATA), "DC_NATIVE_DATA is never registered")
ok(not DC2:HasNativePushEvents() and DC2:GetNativePollInterval(0.1) == 0.1, "consumer polls keep their interval")
DC2._connected = true
DC2._serverCaps = CAP_GENERIC
local got2 = {}
DC2:RegisterHandler("GRPF", 0x20, function(data) got2[#got2 + 1] = data end)
dll.queue = { { rev = 4, module = "GRPF", op = 0x20, body = 'J|{"a":4}' } }
advance(0.016)
ok(#got2 == 1, "the protocol still polls every frame")

print("== disconnected ==")
DC2._connected = false
DC2._handshakePending = true
dll.sent = {}
DC2._itemPrimerTooltip = DC._itemPrimerTooltip
primed = {}
DC2:PrefetchItems({ 6001 }, cb)
advance(1)
ok(#primed == 0 and #dll.sent == 0, "before the handshake ACK nothing is sent")
advance(4.2)
ok(#primed == 1, "after 5 s without one the id is queried the stock way")

print("")
print(string.format("RESULT: %d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
