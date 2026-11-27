-- DC-MythicPlus legacy HUD (Core.lua): enemy forces and the death time penalty.
--
-- The server (MythicPlusRunManager) now gates completion on enemy forces and
-- takes MythicPlus.DeathTimePenaltySeconds off the par timer per death. The HUD
-- snapshot carries "forces"/"forcesRequired" only when forces gate the run, and
-- "timePenalty" as the seconds taken so far ("duration" stays the full par,
-- "remaining" already counts the penalty). Pins that the HUD shows
-- "Forces x/y (z%)" when the fields are there and keeps the old enemy count when
-- they are not (old server), and that the timer counts down to the penalised
-- par instead of the full one.
-- DC_MYTHIC_CORE_FILE=<old copy> runs it against another Core.lua.

dofile("wowsim.lua")
local ROOT = [[K:\Dark-Chaos\DarkChaos-255-Master\Custom\Client addons needed\]]
local CORE = os.getenv("DC_MYTHIC_CORE_FILE") or (ROOT .. [[DC-MythicPlus\Core.lua]])
local pass, fail = 0, 0
local function ok(c, m) if c then pass=pass+1; print("  PASS "..m) else fail=fail+1; print("  FAIL "..m) end end

-- The same minimal client test_mythicbadge.lua loads Core.lua into.
_G.IsInInstance = function() return false end
_G.GetInstanceInfo = function() return nil end
_G.UIParent = CreateFrame("Frame")
_G.Minimap = CreateFrame("Frame")
_G.hooksecurefunc = function(name, hook)
    local original = _G[name]
    _G[name] = function(...)
        if original then original(...) end
        hook(...)
    end
end
_G.UnitName = function() return "Tester" end
_G.UnitGUID = function() return "0x1" end
_G.GetRealmName = function() return "DC" end
_G.SlashCmdList = {}
_G.C_Timer = { After = function() end }
_G.tinsert, _G.tremove = table.insert, table.remove
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end

dofile(CORE)
local hud = _G.DCMythicPlusHUD
ok(type(hud) == "table", "Core.lua loaded")

print("Enemy forces line")
local format = hud.FormatForcesLine
ok(type(format) == "function", "FormatForcesLine is exported")
if type(format) == "function" then
    ok(format({ enemiesKilled = 40 }) == nil, "old server payload (no forces fields): no forces line")
    ok(format({ forces = 0, forcesRequired = 0 }) == nil, "forcesRequired 0 (forces off / exempt bot run): no forces line")
    local line, done = format({ forces = 30, forcesRequired = 58 })
    ok(line == "Forces 30/58 (51%)" and done == false, "30 of 58: 'Forces 30/58 (51%)', not met (got " .. tostring(line) .. ")")
    line, done = format({ forces = 58, forcesRequired = 58 })
    ok(line == "Forces 58/58 (100%)" and done == true, "58 of 58: met")
    line, done = format({ forces = 70, forcesRequired = 58 })
    ok(line == "Forces 70/58 (100%)" and done == true, "past the requirement: percent stops at 100")
    line = format({ forcesRequired = 10 })
    ok(line == "Forces 0/10 (0%)", "requirement without a count yet: 0%")
end

print("Death time penalty")
local effective = hud.GetEffectiveTimerMax
ok(type(effective) == "function", "GetEffectiveTimerMax is exported")
if type(effective) == "function" then
    ok(effective({ duration = 1800 }) == 1800, "old server (no timePenalty): the full par")
    ok(effective({ duration = 1800, timePenalty = 25 }) == 1775, "five 5s deaths: par 1775")
    ok(effective({ duration = 30, timePenalty = 60 }) == 0, "never below zero")
    ok(effective({ timeLimit = 900, timePenalty = 10 }) == 890, "legacy timeLimit field honoured too")
end

local timerLine = hud.BuildTimerLine
ok(type(timerLine) == "function", "BuildTimerLine is exported")
if type(timerLine) == "function" then
    local line = timerLine({ elapsed = 600, remaining = 1175, duration = 1800, timePenalty = 25, completed = 1 })
    ok(line:find("10:00", 1, true) and line:find("29:35", 1, true),
        "timer shows elapsed against the penalised par 29:35 (got " .. line .. ")")
    ok(line:find("(-25s deaths)", 1, true) ~= nil, "the penalty is shown on the timer line")
    line = timerLine({ elapsed = 600, remaining = 1200, duration = 1800, completed = 1 })
    ok(line:find("30:00", 1, true) and not line:find("deaths)", 1, true), "no penalty: full par, no penalty tag")
end

print(string.format("RESULT: %d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
