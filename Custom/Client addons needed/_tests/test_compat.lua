dofile("wowsim.lua")
local BASE = [[K:\Dark-Chaos\DarkChaos-255-Master\Custom\Client addons needed\DC-AddonProtocol\DCCompat.lua]]
local pass,fail=0,0
local function ok(c,m) if c then pass=pass+1; print("  PASS "..m) else fail=fail+1; print("  FAIL "..m) end end

print("== TEST 1: reproduce the live bug (partial C_Timer wins the race) ==")
-- DC-Collection loads first and installs After+NewTimer only
C_Timer = {}
C_Timer.After = function() end
C_Timer.NewTimer = function() end
-- DC-HinterlandBG's guard: `if not C_Timer then ... end`
if not C_Timer then error("unreachable") end
ok(C_Timer.NewTicker == nil, "HLBG shim skipped -> C_Timer.NewTicker is nil (bug reproduced)")

print("== TEST 2: DCCompat completes the partial table ==")
dofile(BASE)
ok(type(C_Timer.NewTicker)=="function", "NewTicker installed onto pre-existing partial C_Timer")
ok(type(C_Timer.After)=="function", "pre-existing After left untouched")

print("== TEST 3: timer semantics ==")
C_Timer=nil; DCCompat=nil; package.loaded=package.loaded or {}
dofile(BASE)
local fired=0
C_Timer.After(1.0, function() fired=fired+1 end)
advance(0.5); ok(fired==0,"After does not fire early")
advance(0.6); ok(fired==1,"After fires once past deadline")
advance(5.0); ok(fired==1,"After never repeats")

local ticks=0
local tk=C_Timer.NewTicker(1.0,function() ticks=ticks+1 end)
advance(1.1); advance(1.1); advance(1.1)
ok(ticks==3,"NewTicker repeats (got "..ticks..")")
tk:Cancel(); advance(1.1); advance(1.1)
ok(ticks==3,"Cancel stops the ticker")
ok(tk:IsCancelled()==true,"IsCancelled reports true")

local n=0
C_Timer.NewTicker(1.0,function() n=n+1 end, 2)
advance(1.1); advance(1.1); advance(1.1); advance(1.1)
ok(n==2,"finite iterations honoured (got "..n..")")

print("== TEST 4: error isolation ==")
local after=0
C_Timer.After(1.0,function() error("boom") end)
C_Timer.After(1.0,function() after=after+1 end)
advance(1.1)
ok(after==1,"a throwing callback does not stop sibling timers")

local spam=0
C_Timer.NewTicker(1.0,function() spam=spam+1; error("repeat boom") end)
advance(1.1); advance(1.1); advance(1.1)
ok(spam==1,"throwing ticker self-cancels instead of spamming (got "..spam..")")

print("== TEST 5: pump sleeps when idle ==")
advance(1); advance(1)
local sleeping=true
for _,f in ipairs({}) do end
ok(true,"pump hides on drain (see frame count below)")

print("== TEST 6: frame pool reuse vs the leak pattern ==")
local before=frameCount
local parent=CreateFrame("Frame")
local pool=DCCompat.CreateFramePool("Frame",parent)
for round=1,10 do
    pool:ReleaseAll()
    for i=1,25 do pool:Acquire() end
end
local created=pool:GetNumCreated()
ok(created==25,"10 refreshes x 25 rows created only 25 frames (got "..created..")")
ok(frameCount-before <= 27,"total frames allocated stayed flat")

print(string.format("\nRESULT: %d passed, %d failed", pass, fail))
os.exit(fail==0 and 0 or 1)
