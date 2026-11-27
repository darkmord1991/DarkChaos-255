-- DC-LabProbe: a server request (LABP|16) comes back as base64 answer slices
-- (LABP|1), each one addon frame, paced behind the protocol's send queue; only
-- the read-only commands answer, the account CVars are never reported.
--
-- Usage: lua test_labprobe.lua   (run from this directory; DC_ADDON_ROOT overrides the addon root)
dofile("wowsim.lua")
local ROOT = os.getenv("DC_ADDON_ROOT") or "../"
local pass, fail = 0, 0
local function ok(c, m)
    if c then pass = pass + 1; print("  PASS " .. m) else fail = fail + 1; print("  FAIL " .. m) end
end

_G.unpack = _G.unpack or table.unpack
_G.time = os.time
_G.SlashCmdList = {}
_G.UnitName = function() return "Labby" end
_G.GetBuildInfo = function() return "3.3.5", "12340" end
_G.GetLocale = function() return "enUS" end
_G.UnitLevel = function() return 80 end
_G.UnitClass = function() return "Mage", "MAGE" end
_G.UnitRace = function() return "Human", "Human" end
_G.GetRealZoneText = function() return "Dalaran" end
_G.GetSubZoneText = function() return "Krasus' Landing" end
_G.GetPlayerMapPosition = function() return 0.5, 0.25 end
_G.GetCVar = function(name) return name == "gxResolution" and "1920x1080" or "secret" end
_G.UnitExists = function(unit) return unit == "player" or unit == "target" end
_G.UnitAura = function(unit, i, filter)
    if unit == "player" and filter == "HELPFUL" and i == 1 then
        return "Arcane Intellect", "Rank 7", "icon", 1, nil, 3600, GetTime() + 1800, "player", nil, nil, 42995
    end
    return nil
end

-- Minimal JSON encoder standing in for DCAddonProtocol's.
local function encode(v)
    local t = type(v)
    if t == "nil" then return "null" end
    if t == "boolean" then return v and "true" or "false" end
    if t == "number" then
        if v == math.floor(v) then return string.format("%d", v) end
        return tostring(v)
    end
    if t == "string" then
        return '"' .. v:gsub('[%c"\\]', function(c)
            if c == '"' then return '\\"' elseif c == "\\" then return "\\\\" end
            return string.format("\\u%04x", c:byte())
        end) .. '"'
    end
    local n = #v
    local isArray = n > 0 or next(v) == nil
    if isArray then
        for k in pairs(v) do
            if type(k) ~= "number" then isArray = false break end
        end
    end
    local parts = {}
    if isArray then
        for i = 1, n do parts[#parts + 1] = encode(v[i]) end
        return "[" .. table.concat(parts, ",") .. "]"
    end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    for _, k in ipairs(keys) do parts[#parts + 1] = encode(k) .. ":" .. encode(v[k]) end
    return "{" .. table.concat(parts, ",") .. "}"
end

local sent, handlers = {}, {}
_G.DCAddonProtocol = {
    _throttle = { queue = {} },
    _connected = true,
    _serverCaps = 5,
    EncodeJSON = function(_, v) return encode(v) end,
    SendChunked = function(_, msg) sent[#sent + 1] = msg end,
    RegisterJSONHandler = function(_, module, opcode, fn) handlers[module .. "_" .. opcode] = fn end,
    GetNativeExtensionBuildFingerprint = function() return "dc-test-fp" end,
    GetNativeExtensionCapabilities = function() return 67108864 end,
}

dofile(ROOT .. "DC-LabProbe/LabProbe.lua")
local P = _G.DCLabProbe

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function unbase64(s)
    local out = {}
    for i = 1, #s, 4 do
        local n, pad = 0, 0
        for j = 0, 3 do
            local ch = s:sub(i + j, i + j)
            local v = 0
            if ch == "=" then pad = pad + 1 else v = B64:find(ch, 1, true) - 1 end
            n = n * 64 + v
        end
        local bytes = string.char(math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256)
        out[#out + 1] = bytes:sub(1, 3 - pad)
    end
    return table.concat(out)
end

-- Reassemble every answer in `sent` by id; returns { [id] = { text, frames, maxLen, total } }.
local function answers()
    local byId = {}
    for _, msg in ipairs(sent) do
        local body = msg:match("^LABP|1|J|(.*)$")
        if body then
            local id = body:match('"id":"(%x+)"')
            local i = tonumber(body:match('"i":(%d+)'))
            local n = tonumber(body:match('"n":(%d+)'))
            local d = body:match('"d":"([^"]*)"')
            local a = byId[id] or { parts = {}, frames = 0, maxLen = 0 }
            a.parts[i] = unbase64(d)
            a.total = n
            a.frames = a.frames + 1
            a.maxLen = math.max(a.maxLen, #msg)
            byId[id] = a
        end
    end
    for _, a in pairs(byId) do
        local complete = true
        for i = 1, a.total do if not a.parts[i] then complete = false end end
        a.complete = complete
        a.text = complete and table.concat(a.parts) or nil
    end
    return byId
end

local function request(id, req)
    handlers["LABP_16"]({ id = id, req = req })
    for _ = 1, 400 do advance(0.05) end
end

ok(type(handlers["LABP_16"]) == "function", "registers the LABP request handler")
ok(P.Base64("Man") == "TWFu" and P.Base64("Ma") == "TWE=" and P.Base64("M") == "TQ==", "base64 encoder")

request("000000000a", { cmd = "ping" })
local a = answers()["000000000a"]
ok(a and a.complete and a.text:find('"pong":true', 1, true) ~= nil, "ping answers with pong")
ok(a and a.text:find('"character":"Labby"', 1, true) and a.text:find('"ok":true', 1, true), "answer carries character and ok")

request("000000000b", { cmd = "eval", name = "x" })
a = answers()["000000000b"]
ok(a and a.text:find('"error":"unknown command"', 1, true) and a.text:find('"ok":false', 1, true), "unknown command refused")

local before = #sent
handlers["LABP_16"]({ id = "not-hex!!!", req = { cmd = "ping" } })
handlers["LABP_16"]({ id = "0123", req = { cmd = "ping" } })
for _ = 1, 10 do advance(0.05) end
ok(#sent == before, "malformed request ids are ignored")

_G.PlayerFrame = CreateFrame("Frame")
PlayerFrame:Show()
request("000000000c", { cmd = "frame", names = { "PlayerFrame", "NoSuchFrame" } })
a = answers()["000000000c"]
ok(a and a.text:find('"name":"PlayerFrame"', 1, true) and a.text:find('"shown":true', 1, true), "frame state read")
ok(a and a.text:find('{"exists":false,"name":"NoSuchFrame"}', 1, true), "missing frame reported as absent")

request("000000000d", { cmd = "cvars", names = { "gxResolution", "accountName" } })
a = answers()["000000000d"]
ok(a and a.text:find('"v":"1920x1080"', 1, true), "cvar value read")
ok(a and a.text:find('{"denied":true,"n":"accountName"}', 1, true) and not a.text:find("secret", 1, true),
    "accountName is never reported")

request("000000000e", { cmd = "auras", unit = "player" })
a = answers()["000000000e"]
ok(a and a.text:find('"id":42995', 1, true) and a.text:find('"n":"Arcane Intellect"', 1, true), "auras read")
request("000000000f", { cmd = "auras", unit = "RunScript" })
a = answers()["000000000f"]
ok(a and a.text:find('"ok":false', 1, true), "non-unit token refused")

_G.BugGrabber = {
    GetSessionId = function() return 3 end,
    GetDB = function() return {
        { message = "old error", session = 2, counter = 1, time = "t1" },
        { message = { "part one ", "part two" }, session = 3, counter = 4, time = "t2" },
    } end,
}
request("0000000010", { cmd = "errors", max = 5 })
a = answers()["0000000010"]
ok(a and a.text:find('"m":"part one part two"', 1, true) and a.text:find('"current":true', 1, true), "BugGrabber errors")

-- A large answer: many slices, every frame within one addon message, paced by the queue.
local addonNames = {}
for i = 1, 120 do addonNames[i] = "SomeAddon_" .. i end
_G.GetNumAddOns = function() return #addonNames end
_G.GetAddOnInfo = function(i) return addonNames[i], addonNames[i], "", 1 end
_G.GetAddOnMetadata = function(i) return "1.0." .. i end
_G.IsAddOnLoaded = function() return true end

DCAddonProtocol._throttle.queue = { 1, 2, 3, 4, 5, 6, 7, 8 }
before = #sent
handlers["LABP_16"]({ id = "0000000011", req = { cmd = "addons" } })
for _ = 1, 20 do advance(0.05) end
ok(#sent == before, "nothing is sent while the protocol queue is full")
DCAddonProtocol._throttle.queue = {}
for _ = 1, 400 do advance(0.05) end
a = answers()["0000000011"]
ok(a and a.complete and a.total > 10 and a.total <= 128, "large answer arrives complete in " .. tostring(a and a.total) .. " slices")
ok(a and a.maxLen <= 255, "every slice fits one addon message (max " .. tostring(a and a.maxLen) .. " bytes)")
ok(a and a.text:find('"n":"SomeAddon_120"', 1, true), "last addon present after reassembly")

-- Too large for 128 slices: replaced by a short error answer.
local long = string.rep("v", 390)
_G.GetAddOnMetadata = function() return long end
request("0000000012", { cmd = "addons" })
a = answers()["0000000012"]
ok(a and a.total == 1 and a.text:find('"error":"answer too large"', 1, true), "oversized answer replaced by an error")

-- /labprobe off: answered with a refusal.
SlashCmdList["DCLABPROBE"]("off")
request("0000000013", { cmd = "ping" })
a = answers()["0000000013"]
ok(a and a.text:find("switched off", 1, true) and not a.text:find("pong", 1, true), "/labprobe off refuses")
SlashCmdList["DCLABPROBE"]("on")
request("0000000014", { cmd = "ping" })
a = answers()["0000000014"]
ok(a and a.text:find('"pong":true', 1, true), "/labprobe on answers again")

print(string.format("RESULT %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
