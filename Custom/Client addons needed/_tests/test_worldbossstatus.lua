-- World boss status in DC-InfoBar (Core.lua HandleWorldContent / HandleWorldUpdate and
-- Plugins/Server/WorldBoss.lua), through the real handlers and the bar text.
--   * The server's death push carries status "spawning" plus spawnIn
--     (CrossSystemWorldBossMgr.cpp BroadcastBossUpdate "death"). The update handler
--     overwrote that with "inactive" because of the action, and the bar, tooltip and
--     Group Finder world tab then read "Not today" for the whole respawn window.
--   * "inactive" is the snapshot's status for a boss the rotation has off today and
--     must read "Not today", not "Unknown".
--   * A push without a status (older server) still gets one from its action.
dofile("wowsim.lua")
local ROOT = [[K:\Dark-Chaos\DarkChaos-255-Master\Custom\Client addons needed\]]
local pass, fail = 0, 0
local function ok(c, m)
    if c then pass = pass + 1; print("  PASS " .. m) else fail = fail + 1; print("  FAIL " .. m) end
end

_G.unpack = _G.unpack or table.unpack
_G.UIParent = CreateFrame("Frame")
_G.SlashCmdList = {}
_G.time = os.time
_G.date = os.date
_G.GetLocale = function() return "enUS" end
_G.UnitName = function() return "Tester" end
_G.GetRealmName = function() return "DC" end
_G.GetBuildInfo = function() return "3.3.5", "12340", "date", 30300 end
_G.GetAddOnMetadata = function() return "1.0" end
_G.IsAddOnLoaded = function() return false end
_G.InterfaceOptions_AddCategory = function() end
_G.GameTooltip = CreateFrame("Frame")
_G.tinsert, _G.tremove = table.insert, table.remove
_G.strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
_G.strlower = string.lower
_G.hooksecurefunc = function() end
_G.SendAddonMessage = function() end
_G.DCAddonProtocol = nil

for _, file in ipairs({ "Utils.lua", "Settings.lua", "Core.lua", [[Plugins\Server\WorldBoss.lua]] }) do
    dofile(ROOT .. [[DC-InfoBar\]] .. file)
end
local IB = _G.DCInfoBar
local plugin = IB.plugins and IB.plugins.DCInfoBar_WorldBoss
if not plugin and type(IB.plugins) == "table" then
    for _, p in pairs(IB.plugins) do
        if type(p) == "table" and p.id == "DCInfoBar_WorldBoss" then plugin = p end
    end
end
ok(plugin ~= nil, "the World Boss plugin registers")
IB.serverData = IB.serverData or {}
IB.serverData.worldBosses = IB.serverData.worldBosses or {}
IB.serverData._lastWRLDContentAt = GetTime()

local OONDASTA, THOK, NALAK = 400100, 400101, 400102

local function record(entry)
    for _, b in ipairs(IB.serverData.worldBosses) do
        if tonumber(b.entry) == entry then return b end
    end
end

-- The bar text for one boss: point the cycle at it (no boss is active, so the
-- plugin does not jump to an active one).
local function barText(entry)
    for i, b in ipairs(IB.serverData.worldBosses) do
        if tonumber(b.entry) == entry then
            plugin._currentBossIndex = i
            plugin._cycleTimer = 0
            plugin._snapshotRetries = 99
            local _, text = plugin:OnUpdate(0)
            return tostring(text)
        end
    end
    return "<missing>"
end

print("== the snapshot ==")
IB:HandleWorldContent({ bosses = {
    { entry = OONDASTA, spawnId = 9000190, name = "Oondasta, King of Dinosaurs", active = true, status = "active" },
    { entry = THOK, spawnId = 9000189, name = "Thok the Bloodthirsty", active = false, status = "inactive" },
    { entry = NALAK, spawnId = 9000191, name = "Nalak the Storm Lord", active = false, status = "spawning", spawnIn = 600 },
} })
ok(record(THOK).status == "inactive", "Thok is off the rotation today")
ok(record(NALAK).status == "spawning" and tonumber(record(NALAK).spawnIn) == 600, "Nalak is on a timer")

print("== Oondasta dies: the server's death push ==")
IB:HandleWorldUpdate({ bosses = {
    { entry = OONDASTA, spawnId = 9000190, name = "Oondasta, King of Dinosaurs", active = false,
      action = "death", hpPct = 0, spawnIn = 300, status = "spawning" },
} })
local oondasta = record(OONDASTA)
ok(oondasta.status == "spawning", "the record keeps the server's status (" .. tostring(oondasta.status) .. ")")
ok(tonumber(oondasta.spawnIn) == 300 and oondasta.spawnAt ~= nil, "the respawn timer is stamped")
ok(oondasta.justSpawnedUntil == nil, "it is no longer just spawned")
local text = barText(OONDASTA)
ok(text:find("5m", 1, true) ~= nil and not text:find("Not today", 1, true),
    "the bar shows the respawn timer, not Not today (" .. text .. ")")
-- No boss is up now, so the bar cycles through each record.
ok(barText(THOK):find("Not today", 1, true) ~= nil, "Thok reads Not today (" .. barText(THOK) .. ")")
ok(barText(NALAK):find("10m", 1, true) ~= nil, "Nalak reads its timer (" .. barText(NALAK) .. ")")
advance(65)
IB:TickServerTimers()
text = barText(OONDASTA)
ok(text:find("3m", 1, true) ~= nil, "and the timer counts down (" .. text .. ")")

print("== it respawns ==")
IB:HandleWorldUpdate({ bosses = {
    { entry = OONDASTA, spawnId = 9000190, name = "Oondasta, King of Dinosaurs", active = true,
      action = "spawn", hpPct = 100, status = "active" },
} })
ok(record(OONDASTA).status == "active" and record(OONDASTA).justSpawnedUntil ~= nil, "active and just spawned")

print("== pushes without a status (older server) ==")
IB:HandleWorldUpdate({ bosses = {
    { entry = OONDASTA, spawnId = 9000190, name = "Oondasta, King of Dinosaurs", active = false,
      action = "death", hpPct = 0, spawnIn = 300 },
} })
ok(record(OONDASTA).status == "spawning", "a death with a timer is spawning")
ok(record(OONDASTA).justSpawnedUntil == nil, "and clears just spawned")
IB:HandleWorldUpdate({ bosses = {
    { entry = OONDASTA, spawnId = 9000190, name = "Oondasta, King of Dinosaurs", active = false, action = "despawn" },
} })
ok(record(OONDASTA).status == "inactive", "a despawn without a timer is inactive")
ok(barText(OONDASTA):find("Not today", 1, true) ~= nil, "and reads Not today")
IB:HandleWorldUpdate({ bosses = {
    { entry = OONDASTA, spawnId = 9000190, name = "Oondasta, King of Dinosaurs", active = true, action = "engage" },
} })
ok(record(OONDASTA).status == "active", "an engage is active")

print("== a snapshot without a status ==")
IB:HandleWorldContent({ bosses = {
    { entry = NALAK, spawnId = 9000191, name = "Nalak the Storm Lord", active = false, spawnIn = 120 },
    { entry = THOK, spawnId = 9000189, name = "Thok the Bloodthirsty", active = false },
} })
ok(record(NALAK).status == "spawning", "down with a timer is spawning")
ok(record(THOK).status == "inactive", "down without one is inactive")

print(string.format("RESULT %d passed, %d failed", pass, fail))
if fail > 0 then
    os.exit(1)
end
