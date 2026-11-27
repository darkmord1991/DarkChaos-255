-- DC-HinterlandBG/HLBG_Handlers.lua chat fallback (security audit 2026-11-10).
--
-- The server sends its tagged HLBG payloads ([HLBG_STATUS], [HLBG_WARMUP], ...) only as SYSTEM
-- messages. The fallback used to listen to say/yell/whisper/party/raid/guild too, so any player
-- could whisper "[HLBG_STATUS] A=0 H=1500" or a fake history row: the line was parsed as server
-- protocol and hidden from chat. Only CHAT_MSG_SYSTEM may be parsed or filtered.
dofile("wowsim.lua")
local ROOT = os.getenv("DC_ADDON_ROOT") or [[K:\Dark-Chaos\DarkChaos-255-Master\Custom\Client addons needed\]]
local FILE = ROOT .. [[DC-HinterlandBG\HLBG_Handlers.lua]]
local pass, fail = 0, 0
local function ok(c, m)
    if c then pass = pass + 1; print("  PASS " .. m) else fail = fail + 1; print("  FAIL " .. m) end
end

-- Record every event registration and chat filter.
local Methods = getmetatable(CreateFrame("Frame")).__index
function Methods:RegisterEvent(ev)
    self._events = self._events or {}
    self._events[ev] = true
end
local filters = {}
_G.ChatFrame_AddMessageEventFilter = function(ev, fn) filters[ev] = fn end
_G.SlashCmdList = _G.SlashCmdList or {}
_G.hooksecurefunc = _G.hooksecurefunc or function() end
_G.UnitName = _G.UnitName or function() return "Tester" end

local created = {}
local simCreateFrame = CreateFrame
_G.CreateFrame = function(...)
    local f = simCreateFrame(...)
    created[#created + 1] = f
    return f
end

local okLoad, err = pcall(dofile, FILE)
ok(okLoad, "HLBG_Handlers.lua loads" .. (okLoad and "" or (": " .. tostring(err))))

local HLBG = _G.HLBG
local chatFrame
for _, f in ipairs(created) do
    if f._events and f._events.CHAT_MSG_SYSTEM then chatFrame = f end
end
ok(chatFrame ~= nil, "a frame listens to CHAT_MSG_SYSTEM")

local PLAYER_CHAT = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_GUILD", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_WHISPER", "CHAT_MSG_CHANNEL",
}
local anyPlayerEvent, anyPlayerFilter = false, false
for _, f in ipairs(created) do
    for _, ev in ipairs(PLAYER_CHAT) do
        if f._events and f._events[ev] then anyPlayerEvent = true end
    end
end
for _, ev in ipairs(PLAYER_CHAT) do
    if filters[ev] then anyPlayerFilter = true end
end
ok(not anyPlayerEvent, "no frame in HLBG_Handlers listens to player chat types")
ok(not anyPlayerFilter, "no chat filter hides player chat lines")
ok(filters.CHAT_MSG_SYSTEM ~= nil, "SYSTEM payload filter is still installed")
ok(filters.CHAT_MSG_SYSTEM and filters.CHAT_MSG_SYSTEM(nil, "CHAT_MSG_SYSTEM", "[HLBG_STATUS] A=1") == true,
    "SYSTEM [HLBG_ lines are still hidden")

-- The handler itself ignores anything that is not SYSTEM, even if registered elsewhere.
local onEvent = chatFrame and chatFrame._scripts.OnEvent
HLBG.UpdateHUD = function() end
HLBG.RES.A, HLBG.RES.H = 0, 0
if onEvent then
    onEvent(chatFrame, "CHAT_MSG_WHISPER", "[HLBG_STATUS] A=0 H=1500 END=99")
end
ok(HLBG.RES.H == 0, "a whispered [HLBG_STATUS] does not change the scores")

-- The server path still works.
if onEvent then
    onEvent(chatFrame, "CHAT_MSG_SYSTEM", "[HLBG_STATUS] A=120 H=340 END=99")
end
ok(HLBG.RES.A == 120 and HLBG.RES.H == 340, "a SYSTEM [HLBG_STATUS] still updates the scores")

local warm
HLBG.Warmup = function(v) warm = v end
if onEvent then
    onEvent(chatFrame, "CHAT_MSG_YELL", "[HLBG_WARMUP] 999")
end
ok(warm == nil, "a yelled [HLBG_WARMUP] is ignored")
if onEvent then
    onEvent(chatFrame, "CHAT_MSG_SYSTEM", "[HLBG_WARMUP] 30")
end
ok(warm == "30", "a SYSTEM [HLBG_WARMUP] still reaches HLBG.Warmup")

-- World chat (mod-world-chat) relays player text as SYSTEM lines behind a "[World][...]" prefix
-- (security audit 2026-11-18): they are player speech, never protocol.
local worldLine = "[World][][|cffC79C6E|Hplayer:Bob|hBob|h|r]: |cffFFFFFF[HLBG_STATUS] A=0 H=1500 END=99|r"
HLBG.RES.A, HLBG.RES.H = 7, 8
if onEvent then
    onEvent(chatFrame, "CHAT_MSG_SYSTEM", worldLine)
end
ok(HLBG.RES.A == 7 and HLBG.RES.H == 8, "a world-chat [HLBG_STATUS] does not change the scores")
ok(filters.CHAT_MSG_SYSTEM and filters.CHAT_MSG_SYSTEM(nil, "CHAT_MSG_SYSTEM", worldLine) == false,
    "a world-chat line carrying [HLBG_ stays visible")
warm = nil
if onEvent then
    onEvent(chatFrame, "CHAT_MSG_SYSTEM", "x [HLBG_WARMUP] 999")
end
ok(warm == nil, "an [HLBG_WARMUP] tag that does not start the line is ignored")

print(string.format("RESULT: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
