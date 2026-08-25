dofile("wowsim.lua")
local ROOT = [[K:\Dark-Chaos\DarkChaos-255-Master\Custom\Client addons needed\]]
local pass, fail = 0, 0
local function ok(c, m) if c then pass=pass+1; print("  PASS "..m) else fail=fail+1; print("  FAIL "..m) end end

-- capture chat output
local chat = {}
_G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) chat[#chat+1] = m end }

print("== Scenario A: real load order, DC-AddonProtocol present ==")
dofile(ROOT..[[DC-AddonProtocol\DCCompat.lua]])
ok(type(C_Timer.After)=="function",     "C_Timer.After present")
ok(type(C_Timer.NewTimer)=="function",  "C_Timer.NewTimer present")
ok(type(C_Timer.NewTicker)=="function", "C_Timer.NewTicker present  <-- was nil in production")

-- HinterlandBG's stub now runs against a complete C_Timer
_G.HLBG_RecordFileLoad = function(f) _G._recorded = f end
chat = {}
dofile(ROOT..[[DC-HinterlandBG\HLBG_TimerCompat.lua]])
ok(_G._recorded == "HLBG_TimerCompat.lua", "HLBG load-diagnostic hook still fires")
local warned = false
for _,m in ipairs(chat) do if m:find("unavailable") then warned = true end end
ok(not warned, "no dependency warning when DCCompat loaded")

-- the exact call that was dead in production
local refreshes = 0
local ticker
if C_Timer and C_Timer.NewTicker then
    ticker = C_Timer.NewTicker(5, function() refreshes = refreshes + 1 end)
end
ok(ticker ~= nil, "HLBG_Queue_Client's guarded NewTicker call now takes the live branch")
advance(5.1); advance(5.1); advance(5.1)
ok(refreshes == 3, "queue auto-refresh actually ticks (got "..refreshes..")")

-- widget polyfills consolidated
local probe = CreateFrame("Frame")
ok(type(probe.SetShown)=="function" or type(getmetatable(probe).__index.SetShown)=="function",
   "SetShown polyfill installed once, centrally")

print("== Scenario B: DC-AddonProtocol missing (defensive path) ==")
C_Timer = nil
DCCompat = nil
chat = {}
dofile(ROOT..[[DC-HinterlandBG\HLBG_TimerCompat.lua]])
local loud = false
for _,m in ipairs(chat) do if m:find("unavailable") then loud = true end end
ok(loud, "missing dependency now fails LOUDLY instead of silently")

print(string.format("\nRESULT: %d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
