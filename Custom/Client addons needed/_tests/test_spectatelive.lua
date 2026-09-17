-- Unified spectator UI (DC-MythicPlus/UI/LiveRunsTab.lua). The Group Finder
-- live list merges the server's Mythic+ "runs" with its "sessions" (Hinterland
-- BG matches, phased duels); a Watch request carries the entry's system; and
-- the spectator bar renders each system's snapshot shape, opening on
-- SMSG_SPECTATE_STARTED and closing on SMSG_SPECTATE_ENDED.

dofile("wowsim.lua")
local ROOT = [[K:\Dark-Chaos\DarkChaos-255-Master\Custom\Client addons needed\]]
local pass, fail = 0, 0
local function ok(c, m) if c then pass=pass+1; print("  PASS "..m) else fail=fail+1; print("  FAIL "..m) end end
local function has(text, needle) return type(text) == "string" and text:find(needle, 1, true) ~= nil end

_G.UIParent = CreateFrame("Frame")
_G.C_Timer = { After = function() end }

-- Every request the UI sends, in order.
local requests = {}
_G.DCAddonProtocol = {
    GroupFinderOpcodes = {},
    GroupFinder = {
        StartSpectate = function(runId) table.insert(requests, { system = "mplus", id = runId }) end,
        StartSpectateSession = function(system, id) table.insert(requests, { system = system, id = id }) end,
        StopSpectate = function() table.insert(requests, { system = "stop" }) end,
    },
}
local function lastRequest() return requests[#requests] or {} end

local namespace = { GroupFinder = {} }
_G.DCMythicPlusHUD = namespace
local GF = namespace.GroupFinder
GF.Print = function() end

dofile(ROOT..[[DC-MythicPlus\UI\LiveRunsTab.lua]])

print("SpectateLive")

-- 1. One list from both halves of SMSG_SPECTATE_LIST.
local runs = { { runId = 7, dungeon = "Utgarde Keep", level = 12, timer = "21:30", leader = "Tanky" } }
local sessions = {
    { system = "hlbg", id = 18, name = "Hinterland Battleground", status = "in_progress",
      timeRemaining = 754, allianceResources = 1200, hordeResources = 900, spectators = 2 },
    { system = "duel", id = 4, name = "Alice vs Bob", duration = 65 },
    { id = 99 },
}
local merged = GF:MergeLiveEntries(runs, sessions)
ok(#merged == 3, "runs and sessions merge; an entry without a system is dropped")
ok(merged[1].system == "mplus" and merged[1].id == 7, "a Mythic+ run is tagged mplus with its run id")
ok(merged[2].system == "hlbg" and merged[3].system == "duel", "sessions keep their order and system")
ok(#GF:MergeLiveEntries(runs, nil) == 1, "an older server that sends no sessions still lists its runs")

-- 2. Row text per system.
local title, detail, meta, watching = GF.DescribeLiveEntry(merged[2])
ok(title == "Hinterland Battleground", "HLBG row is titled after the battleground")
ok(has(detail, "Alliance 1200") and has(detail, "Horde 900"), "HLBG row shows both resource pools")
ok(meta == "12:34 left", "HLBG row shows the time left")
ok(watching == "2 watching", "HLBG row shows the watcher count")
ok(select(3, GF.DescribeLiveEntry({ system = "hlbg", status = "warmup" })) == "Warmup",
    "HLBG row in warmup says so instead of a clock")

title, detail, meta, watching = GF.DescribeLiveEntry(merged[3])
ok(title == "Duel" and detail == "Alice vs Bob", "duel row names both duelists")
ok(meta == "1:05" and watching == "", "duel row shows its duration and no watchers")

title, detail, meta = GF.DescribeLiveEntry(merged[1])
ok(title == "Utgarde Keep" and detail == "Tanky", "Mythic+ row keeps dungeon and leader")
ok(has(meta, "+12") and has(meta, "21:30"), "Mythic+ row keeps key level and timer")

-- 3. The compact Group Finder receives the merged list.
local rendered
GF.compactMode = true
GF.CompactPopulateLiveRuns = function(_, entries) rendered = entries end
GF:PopulateLiveRuns(runs, sessions)
ok(rendered and #rendered == 3, "compact live view renders every system")

-- 4. Watch requests carry the system.
GF:RequestSpectate(18, nil, "hlbg")
ok(lastRequest().system == "hlbg" and lastRequest().id == 18, "HLBG watch goes through StartSpectateSession")
GF:RequestSpectate(nil, nil, "hlbg")
ok(lastRequest().system == "hlbg" and lastRequest().id == 0, "HLBG watch without an id lets the server pick")
GF:RequestSpectate(4, nil, "duel")
ok(lastRequest().system == "duel" and lastRequest().id == 4, "duel watch goes through StartSpectateSession")
GF:RequestSpectate(7, "Tanky")
ok(lastRequest().system == "mplus" and lastRequest().id == 7, "Mythic+ watch keeps the run-id start request")

-- 5. Spectator bar, Hinterland BG session.
GF:BeginSpectateSession({ system = "hlbg", id = 18 })
local hud = GF.spectatorHUD
ok(hud ~= nil and hud:IsShown(), "bar opens as soon as the session starts")
ok(hud.timerText:GetText() == "Joining...", "bar shows a placeholder until the first snapshot")
ok(GF._spectatorSystem == "hlbg", "the session remembers its system")

GF:UpdateSpectatorHUD({ system = "hlbg", status = 3, timeRemaining = 600, A = 1500, H = 1400, APC = 10, HPC = 9 })
ok(hud.dungeonText:GetText() == "Hinterland Battleground", "HLBG snapshot titles the bar")
ok(hud.timerText:GetText() == "Time left: 10:00", "HLBG snapshot shows the time left")
ok(has(hud.progressText:GetText(), "Alliance 1500") and has(hud.progressText:GetText(), "(10)")
    and has(hud.progressText:GetText(), "Horde 1400"), "HLBG snapshot shows resources and team sizes")
ok(has(hud.badge:GetText(), "Hinterland BG"), "badge names the system")

GF:UpdateSpectatorHUD({ system = "hlbg", status = 2, timeRemaining = 900, A = 2500, H = 2600 })
ok(hud.timerText:GetText() == "Warmup", "HLBG warmup shows no countdown")

-- 6. SMSG_SPECTATE_ENDED closes the bar.
GF:EndSpectateSession({ system = "hlbg" })
ok(not hud:IsShown() and GF._spectatorSystem == nil, "ending the session closes the bar and forgets the system")

-- 7. Duel session.
GF:BeginSpectateSession({ system = "duel", id = 4 })
GF:UpdateSpectatorHUD({ system = "duel", player1Name = "Alice", player2Name = "Bob", duration = 65,
    player1Hp = 50, player1MaxHp = 100, player2Hp = 100, player2MaxHp = 100 })
ok(hud.dungeonText:GetText() == "Alice vs Bob", "duel snapshot names both duelists")
ok(hud.timerText:GetText() == "Duration: 1:05", "duel snapshot shows the duration")
ok(hud.progressText:GetText() == "Health: 50%  -  100%", "duel snapshot shows both health bars")

-- 8. Leave sends the stop request and closes the bar.
GF:LeaveSpectate()
ok(lastRequest().system == "stop" and not hud:IsShown(), "Leave sends the stop request and closes the bar")

-- 9. A start and snapshot without "system" (pre-unification server) is a run.
GF:BeginSpectateSession({ runId = 7 })
ok(GF._spectatorSystem == "mplus", "a start without a system is a Mythic+ session")
GF:UpdateSpectatorHUD({ dungeon = "Utgarde Keep", level = 12, timer = "21:30", progress = "1/3 bosses", deaths = 2 })
ok(has(hud.dungeonText:GetText(), "Utgarde Keep") and has(hud.dungeonText:GetText(), "+12"),
    "Mythic+ snapshot titles the bar with dungeon and key level")
ok(has(hud.progressText:GetText(), "1/3 bosses") and has(hud.progressText:GetText(), "Deaths: 2"),
    "Mythic+ snapshot shows progress and deaths")

-- 10. The Group Finder's Spectate tab: list cache, system filter, session id.
local repaints = 0
GF.RefreshSpectatePanel = function() repaints = repaints + 1 end
GF.compactMode = false
GF:PopulateLiveRuns(runs, sessions)
ok(#GF.liveEntries == 3 and repaints == 1, "a list update caches every entry and repaints the Spectate tab")
local hlbgOnly = GF:FilterLiveEntries(GF.liveEntries, "hlbg")
ok(#hlbgOnly == 1 and hlbgOnly[1].id == 18, "the Hinterland filter keeps only HLBG matches")
ok(#GF:FilterLiveEntries(GF.liveEntries, "all") == 3 and #GF:FilterLiveEntries(GF.liveEntries, "duel") == 1,
    "All keeps every entry; Duels keeps the duel")
ok(#GF:FilterLiveEntries(GF.liveEntries, "mplus") == 1, "Mythic+ keeps the run that arrived without a system")
ok(#GF:FilterLiveEntries(nil, "mplus") == 0, "no list yet filters to nothing")

GF:EndSpectateSession()
repaints = 0
GF:BeginSpectateSession({ system = "hlbg", id = 18 })
ok(GF._spectatorSessionId == 18 and repaints == 1, "starting a session records its id and repaints the tab")
GF:EndSpectateSession({ system = "hlbg" })
ok(GF._spectatorSessionId == nil and repaints == 2, "ending it clears the id and repaints the tab")

-- 11. A dungeon run without a keystone (the bots' Normal/Heroic runs): the
-- Mythic+ list with key level 0, the instance difficulty and the elapsed time.
local keyless = { runId = 4242, instanceId = 4242, dungeon = "Utgarde Keep", level = 0, keyLevel = 0,
    difficulty = 1, timer = "12:34", elapsed = 754, progress = "1/3 bosses", leader = "BOT Laridina", spectators = 1 }
local dungeonRuns = GF:MergeLiveEntries({ { runId = 7, dungeon = "Utgarde Keep", level = 12, timer = "21:30",
    leader = "Tanky" }, keyless }, nil)
ok(#dungeonRuns == 2 and dungeonRuns[2].system == "mplus" and dungeonRuns[2].id == 4242,
    "a run without a keystone arrives in the Mythic+ list under its instance id")
ok(GF.IsKeylessLiveEntry(dungeonRuns[2]) and not GF.IsKeylessLiveEntry(dungeonRuns[1]),
    "key level 0 with a difficulty marks a run without a keystone")
ok(not GF.IsKeylessLiveEntry({ system = "mplus", level = 0 }),
    "a level-0 run from an older server without a difficulty is not mistaken for one")
title, detail, meta, watching = GF.DescribeLiveEntry(dungeonRuns[2])
ok(title == "Utgarde Keep" and detail == "BOT Laridina", "its row keeps dungeon and bot leader")
ok(meta == "Heroic  12:34" and watching == "1 watching",
    "its row shows the difficulty and the time since the start instead of a key level")
ok(#GF:FilterLiveEntries(dungeonRuns, "mplus") == 2, "the Dungeons filter keeps keystone runs and runs without one")
GF:RequestSpectate(4242, "BOT Laridina", "mplus")
ok(lastRequest().system == "mplus" and lastRequest().id == 4242, "watching it uses the run-id start request")

GF:BeginSpectateSession({ system = "mplus", id = 4242 })
GF:UpdateSpectatorHUD({ system = "mplus", dungeon = "Utgarde Keep", level = 0, difficulty = 1, timer = "12:34",
    elapsed = 754, progress = "1/3 bosses", deaths = 0 })
ok(has(hud.dungeonText:GetText(), "Utgarde Keep") and has(hud.dungeonText:GetText(), "Heroic")
    and not has(hud.dungeonText:GetText(), "+0"), "the bar titles it with its difficulty, not +0")
ok(hud.timerText:GetText() == "Time: 12:34", "the bar shows the time since the start")
ok(hud.progressText:GetText() == "Progress: 1/3 bosses", "the bar shows boss progress and no death count")
ok(has(hud.badge:GetText(), "Dungeon") and GF._spectatorLabel == "Dungeon", "badge and session strip call it a dungeon")
GF:UpdateSpectatorHUD({ system = "mplus", dungeon = "Utgarde Keep", level = 12, timer = "21:30", progress = "1/3 bosses" })
ok(GF._spectatorLabel == nil and has(hud.dungeonText:GetText(), "+12"), "a keystone snapshot drops the dungeon label again")
GF:EndSpectateSession()
ok(GF._spectatorLabel == nil, "ending the session forgets the label")

print(string.format("RESULT: %d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
