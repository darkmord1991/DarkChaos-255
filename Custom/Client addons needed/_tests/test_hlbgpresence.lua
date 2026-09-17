-- HLBG map-presence tracking across loading screens (DC-HinterlandBG/HLBG_Utils.lua).
--
-- The server adds a player to the battleground on the worldport ack, so the first
-- status packet reaches the client while the loading screen is still up and the
-- zone text still names the zone being left. Capturing that stale zone made the
-- first zone event after arrival read as "left the battleground", which hid the
-- HUD until the next server broadcast a few seconds later.
dofile("wowsim.lua")
local ROOT = os.getenv("HLBG_UTILS_ROOT") or [[K:\Dark-Chaos\DarkChaos-255-Master\Custom\Client addons needed\]]
local UTILS = os.getenv("HLBG_UTILS_FILE") or (ROOT .. [[DC-HinterlandBG\HLBG_Utils.lua]])
local pass, fail = 0, 0
local function ok(c, m) if c then pass=pass+1; print("  PASS "..m) else fail=fail+1; print("  FAIL "..m) end end

local zone = "Dalaran"
_G.GetRealZoneText = function() return zone end
_G.DEFAULT_CHAT_FRAME = _G.DEFAULT_CHAT_FRAME or { AddMessage = function() end }

local created = {}
local realCreateFrame = CreateFrame
_G.CreateFrame = function(...)
    local f = realCreateFrame(...)
    created[#created + 1] = f
    return f
end

dofile(UTILS)
local HLBG = _G.HLBG

local transit
for _, f in ipairs(created) do
    if f._scripts and f._scripts.OnEvent then transit = f end
end

local function fire(event)
    if transit then transit._scripts.OnEvent(transit, event) end
end

local function status(code, mapId)
    HLBG.TrackStatusSignal(code, mapId)
    HLBG._lastStatusTime = GetTime()
end

HLBG.UI = { ModernHUD = realCreateFrame("Frame") }

print("== Scenario A: status lands during the loading screen (the reported bug) ==")
ok(transit ~= nil, "HLBG_Utils registers a loading-screen event frame")
HLBG.UI.ModernHUD:Show()
fire("PLAYER_LEAVING_WORLD")
ok(HLBG._inTransit == true, "PLAYER_LEAVING_WORLD marks the client in transit")
ok(not HLBG.UI.ModernHUD:IsShown(), "HUD is hidden when the loading screen starts")
status(2, 1411)
ok(HLBG.HasRecentMapPresence(60), "presence holds while still loading")
zone = "Hinterland Battleground"
fire("PLAYER_ENTERING_WORLD")
ok(HLBG._inTransit == false, "PLAYER_ENTERING_WORLD clears the transit flag")
ok(HLBG.HasRecentMapPresence(60), "presence holds after arriving  <-- was false: HUD hid until next broadcast")
advance(2)
ok(HLBG.HasRecentMapPresence(60), "presence still holds on the arrival zone")

print("== Scenario B: zone text still stale when the loading screen ends ==")
zone = "Dalaran"
status(0, 0)
fire("PLAYER_LEAVING_WORLD")
status(2, 1412)
fire("PLAYER_ENTERING_WORLD")
ok(HLBG.HasRecentMapPresence(60), "presence holds at PLAYER_ENTERING_WORLD with the old zone text")
advance(1)
zone = "Hinterland Battleground"
ok(HLBG.HasRecentMapPresence(60), "ZONE_CHANGED_NEW_AREA right after arrival adopts the new zone")
advance(10)
ok(HLBG.HasRecentMapPresence(60), "adopted zone keeps presence afterwards")

print("== Scenario C: a real departure is still detected ==")
advance(10)
status(3, 1412)
zone = "Stormwind City"
ok(not HLBG.HasRecentMapPresence(60), "leaving the zone with no STATUS_NONE (dropped packet) drops presence")

print("== Scenario D: STATUS_NONE clears presence ==")
zone = "Hinterland Battleground"
status(3, 1411)
ok(HLBG.HasRecentMapPresence(60), "in-match status gives presence")
status(0, 0)
ok(not HLBG.HasRecentMapPresence(60), "STATUS_NONE with map 0 removes presence")
ok(not HLBG._presenceZonePending, "no pending capture left behind")

print(string.format("\nRESULT: %d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
