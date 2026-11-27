-- DC-QOS /dcbug: the report payload (client fingerprint, addon versions, this
-- session's BugGrabber errors), local validation, the in-flight guard, the
-- queue wait, the answer and the timeout.
--
-- Usage: lua test_bugreport.lua   (run from this directory; DC_ADDON_ROOT overrides the addon root)
dofile("wowsim.lua")
local ROOT = os.getenv("DC_ADDON_ROOT") or "../"
local pass, fail = 0, 0
local function ok(c, m)
    if c then pass = pass + 1; print("  PASS " .. m) else fail = fail + 1; print("  FAIL " .. m) end
end

_G.unpack = _G.unpack or table.unpack
_G.SlashCmdList = {}
_G.UISpecialFrames = {}
_G.UIParent = CreateFrame("Frame")
_G.GetBuildInfo = function() return "3.3.5", "12340" end
_G.GetLocale = function() return "enUS" end
_G.GetRealZoneText = function() return "Dalaran" end
_G.GetSubZoneText = function() return "" end

local addonList = { { "Skada", "1.8" }, { "DC-QOS", "1.3.1" }, { "DC-AddonProtocol", "2.0" }, { "Unloaded", "9" } }
_G.GetNumAddOns = function() return #addonList end
_G.GetAddOnInfo = function(i) return addonList[i][1] end
_G.GetAddOnMetadata = function(i) return addonList[i][2] end
_G.IsAddOnLoaded = function(i) return addonList[i][1] ~= "Unloaded" end

_G.BugGrabber = {
    GetSessionId = function() return 9 end,
    GetDB = function() return {
        { message = "previous session error", session = 8, counter = 1 },
        { message = "Interface\\AddOns\\DC-QOS\\Core.lua:10: boom", session = 9, counter = 2 },
    } end,
}

-- Stand-in encoder: only the size matters here, so a rough serialisation will do.
local function encode(v)
    if type(v) == "table" then
        local parts = {}
        for k, x in pairs(v) do parts[#parts + 1] = tostring(k) .. ":" .. encode(x) end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return '"' .. tostring(v) .. '"'
end

local sent, handlers, errorHandlers = {}, {}, {}
_G.DCAddonProtocol = {
    _throttle = { queue = {} },
    EncodeJSON = function(_, v) return encode(v) end,
    SendJSON = function(_, module, opcode, data) sent[#sent + 1] = { module = module, opcode = opcode, data = data } end,
    RegisterJSONHandler = function(_, module, opcode, fn) handlers[module .. "_" .. opcode] = fn end,
    RegisterErrorHandler = function(_, module, fn) errorHandlers[module] = fn end,
    GetNativeExtensionBuildFingerprint = function() return "darkclient335-abc123" end,
    GetNativeExtensionCapabilities = function() return 67108864 end,
}

dofile(ROOT .. "DC-QOS/Modules/BugReport.lua")
local B = _G.DCQoSBugReport

ok(type(handlers["BUGR_16"]) == "function" and type(errorHandlers["BUGR"]) == "function", "registers result and error handlers")
ok(type(SlashCmdList["DCQOSBUGREPORT"]) == "function" and SLASH_DCQOSBUGREPORT1 == "/dcbug", "/dcbug registered")

local okShort, errShort = B.Submit("ab", "long enough body text", "bug", true)
ok(not okShort and errShort:find("title", 1, true), "short title refused locally")
local okBody, errBody = B.Submit("A title", "short", "bug", true)
ok(not okBody and errBody:find("describe", 1, true), "short body refused locally")
ok(#sent == 0, "nothing sent for invalid input")

ok(B.Submit("  Quest giver missing  ", "Talked to the NPC in Dalaran, nothing happens.", "quest", true), "valid report submitted")
local msg = sent[1]
ok(msg and msg.module == "BUGR" and msg.opcode == 1, "sent as BUGR opcode 1")
local d = msg and msg.data or {}
ok(d.title == "Quest giver missing" and d.category == "quest", "title trimmed, category kept")
ok(d.client and d.client.fingerprint == "darkclient335-abc123" and d.client.build == "3.3.5 (12340)"
    and d.client.zoneText == "Dalaran" and d.client.caps == "67108864", "client fingerprint, build, caps and zone")
ok(d.addons and d.addons[1].n == "DC-QOS" and d.addons[2].n == "DC-AddonProtocol" and d.addons[3].n == "Skada"
    and #d.addons == 3, "loaded addons, DC first, unloaded skipped")
ok(d.errors and #d.errors == 1 and d.errors[1].m:find("boom", 1, true) and d.errors[1].c == 2,
    "only this session's BugGrabber errors")
ok(d.account == nil and d.character == nil and d.name == nil, "no account or character fields")

local okBusy, errBusy = B.Submit("Second title", "Second report body text", "bug", false)
ok(not okBusy and errBusy:find("already", 1, true), "second report refused while one is in flight")

handlers["BUGR_16"]({ ok = true, id = "6740a1b2-1-0001" })
ok(B.Submit("Second title", "Second report body text", "bug", false), "accepted answer clears the in-flight guard")
ok(sent[2] and #sent[2].data.errors == 0, "errors left out when unticked")
handlers["BUGR_16"]({ ok = false, error = "You sent a report recently. Please wait 60 seconds.", retryIn = 60 })

-- The protocol queue is busy: the report waits, then goes out.
DCAddonProtocol._throttle.queue = {}
for i = 1, 30 do DCAddonProtocol._throttle.queue[i] = i end
ok(B.Submit("Queued title", "Queued report body text", "ui", false), "report accepted while the queue is busy")
ok(#sent == 2, "not sent while the queue is busy")
DCAddonProtocol._throttle.queue = {}
advance(0.1)
ok(#sent == 3 and sent[3].data.title == "Queued title", "sent once the queue drains")

-- No answer: the guard lifts after the timeout.
for _ = 1, 25 do advance(1) end
ok(B.Submit("After timeout", "Report body after a timeout", "bug", false), "timeout lifts the in-flight guard")
errorHandlers["BUGR"](3, "Module is disabled on server", 1)
ok(B.Submit("After error", "Report body after a module error", "bug", false), "module error lifts the in-flight guard")

-- Oversized errors are dropped before the report is refused.
handlers["BUGR_16"]({ ok = true, id = "x" })
local big = string.rep("x", 600)
_G.BugGrabber.GetDB = function()
    local db = {}
    for i = 1, 5 do db[i] = { message = big .. i, session = 9, counter = 1 } end
    return db
end
addonList = {}
for i = 1, 60 do addonList[i] = { "DC-Addon" .. i, string.rep("9", 48) } end
local payload, json = B.BuildPayload("Title", string.rep("b", 2000), "bug", true)
ok(#payload.errors < 5 and #json <= 6000, "errors trimmed first to fit the payload cap ("
    .. #payload.errors .. " kept, " .. #json .. " bytes)")
ok(#payload.addons == 48, "addon list capped at 48")

local opened, openErr = pcall(SlashCmdList["DCQOSBUGREPORT"], "Typed title")
ok(opened, "dialog opens from the slash command " .. tostring(openErr or ""))

print(string.format("RESULT %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
