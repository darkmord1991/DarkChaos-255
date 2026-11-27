-- DC-MythicPlus minimap difficulty badge (Core.lua), driven through the real
-- hook on MiniMapInstanceDifficulty_OnEvent. Difficulty 3 is DC's Mythic slot on
-- a dungeon but plain 10 Heroic on a raid, so the badge must not read "M0" there.
-- DC_MYTHIC_CORE_FILE=<old copy> runs it against another Core.lua.

dofile("wowsim.lua")
local ROOT = [[K:\Dark-Chaos\DarkChaos-255-Master\Custom\Client addons needed\]]
local CORE = os.getenv("DC_MYTHIC_CORE_FILE") or (ROOT .. [[DC-MythicPlus\Core.lua]])
local pass, fail = 0, 0
local function ok(c, m) if c then pass=pass+1; print("  PASS "..m) else fail=fail+1; print("  FAIL "..m) end end

-- What the client reports for the current instance, and what Blizzard's own
-- handler would put on the badge there.
local instance = {}
_G.IsInInstance = function() return true, instance.kind end
_G.GetInstanceInfo = function() return instance.name, instance.kind, instance.id, instance.label, instance.players end

_G.UIParent = CreateFrame("Frame")
_G.Minimap = CreateFrame("Frame")
local badge = CreateFrame("Frame")
local text = badge:CreateFontString()
_G.MiniMapInstanceDifficulty = badge
_G.MiniMapInstanceDifficultyText = text
_G.MiniMapInstanceDifficulty_OnEvent = function() text:SetText(instance.stock) end
_G.hooksecurefunc = function(name, hook)
    local original = _G[name]
    _G[name] = function(...)
        original(...)
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

-- Several frames in Core.lua listen for PLAYER_LOGIN, one of them the loader that
-- installs the hook, so every listener gets the event as it would in the client.
local listeners = {}
local createFrame = _G.CreateFrame
_G.CreateFrame = function(...)
    local frame = createFrame(...)
    local register = frame.RegisterEvent
    frame.RegisterEvent = function(self, event)
        if event == "PLAYER_LOGIN" then listeners[#listeners + 1] = self end
        return register(self, event)
    end
    return frame
end

local stockHandler = _G.MiniMapInstanceDifficulty_OnEvent
dofile(CORE)
ok(#listeners > 0, "Core.lua loaded and listens for PLAYER_LOGIN")

-- The loader installs the hook first; whatever it does after that needs far more
-- of the client than a badge test should stub.
for _, frame in ipairs(listeners) do
    local script = frame:GetScript("OnEvent")
    if script then pcall(script, frame, "PLAYER_LOGIN") end
end
ok(_G.MiniMapInstanceDifficulty_OnEvent ~= stockHandler, "the badge hook is installed")

local function shown(values)
    instance = values
    _G.MiniMapInstanceDifficulty_OnEvent(badge, "PLAYER_DIFFICULTY_CHANGED")
    return text:GetText()
end

print("Plain raids keep Blizzard's badge")
ok(shown({ name = "Castle Nathria", kind = "raid", id = 3, label = "10 Player", players = 10, stock = "10" }) == "10", "Castle Nathria 10 Heroic")
ok(shown({ name = "Icecrown Citadel", kind = "raid", id = 3, label = "10 Player", players = 10, stock = "10" }) == "10", "ICC 10 Heroic")
ok(shown({ name = "Icecrown Citadel", kind = "raid", id = 4, label = "25 Player", players = 25, stock = "25" }) == "25", "ICC 25 Heroic")
ok(shown({ name = "Icecrown Citadel", kind = "raid", id = 1, label = "10 Player", players = 10, stock = "10" }) == "10", "ICC 10 Normal")
ok(shown({ name = "Naxxramas", kind = "raid", id = 3, label = "40 Player", players = 40, stock = "40" }) == "40", "vanilla Naxxramas, 40 players")

print("DC Mythic still reads M0")
ok(shown({ name = "Timbermaw Hold", kind = "raid", id = 3, label = "20 Player", players = 20, stock = "20" }) == "M0", "Timbermaw Hold Mythic, 20 players")
ok(shown({ name = "Emerald Sanctum", kind = "raid", id = 3, label = "20 Player", players = 20, stock = "20" }) == "M0", "Emerald Sanctum Mythic, 20 players")
ok(shown({ name = "Utgarde Keep", kind = "party", id = 3, label = "5 Player", players = 5, stock = "5" }) == "M0", "5-man Mythic")
ok(shown({ name = "Utgarde Keep", kind = "party", id = 2, label = "5 Player", players = 5, stock = "5" }) == "5", "5-man Heroic is not Mythic")

print("Leaving Mythic gives the badge back")
ok(shown({ name = "Utgarde Keep", kind = "party", id = 3, label = "5 Player", players = 5, stock = "5" }) == "M0", "in a Mythic dungeon")
ok(shown({ name = "Castle Nathria", kind = "raid", id = 3, label = "10 Player", players = 10, stock = "10" }) == "10", "then a 10 Heroic raid")

print("A keystone run outranks the difficulty")
_G.DCMythicPlusHUD._badgeKeyLevel = 9
_G.DCMythicPlusHUD._badgeInstanceName = "Utgarde Keep"
ok(shown({ name = "Utgarde Keep", kind = "party", id = 3, label = "5 Player", players = 5, stock = "5" }) == "M+9", "M+9 in the keyed dungeon")

print(string.format("RESULT: %d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
