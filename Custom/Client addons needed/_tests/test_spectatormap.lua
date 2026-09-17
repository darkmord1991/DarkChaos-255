-- Run member positions while spectating (DC-MythicPlus/UI/SpectatorMap.lua).
-- The server sends each member's GUID, world position and floor, the
-- spectator's own position and the dungeon's floor bounds in every Mythic+
-- snapshot; this pins the world-to-map maths, the minimap projection, the
-- self-calibrating axis flip, which dots show on which floor, the roster on
-- the spectator bar, the watch / free commands behind a click - and that with
-- the client extension's natives the blips follow the spectator's LIVE
-- position and members in view are placed by the client itself.

dofile("wowsim.lua")
local ROOT = [[K:\Dark-Chaos\DarkChaos-255-Master\Custom\Client addons needed\]]
local pass, fail = 0, 0
local function ok(c, m) if c then pass=pass+1; print("  PASS "..m) else fail=fail+1; print("  FAIL "..m) end end
local function near(a, b, tol) return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (tol or 0.01) end
local function has(text, needle) return type(text) == "string" and text:find(needle, 1, true) ~= nil end
local function shownCount(frames)
    local n = 0
    for _, f in ipairs(frames) do if f:IsShown() then n = n + 1 end end
    return n
end

_G.UIParent = CreateFrame("Frame")
_G.Minimap = CreateFrame("Frame")
Minimap.GetWidth = function() return 140 end
Minimap.GetZoom = function() return 2 end
-- Inside a dungeon the minimap runs on its inside zoom, so the live zoom (2)
-- matches minimapInsideZoom and the indoor scale (180 yards at zoom 2) applies.
local cvars = { minimapZoom = "1", minimapInsideZoom = "2", rotateMinimap = "0" }
_G.GetCVar = function(k) return cvars[k] end
_G.WorldMapFrame = CreateFrame("Frame")
_G.WorldMapButton = CreateFrame("Frame", nil, WorldMapFrame)   -- 300 x 100 in wowsim
_G.RAID_CLASS_COLORS = {
    WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
    PRIEST = { r = 1, g = 1, b = 1 },
    MAGE = { r = 0.41, g = 0.8, b = 0.94 },
}
local sent = {}
_G.SendChatMessage = function(text) table.insert(sent, text) end
_G.GameTooltip = CreateFrame("Frame")
_G.SlashCmdList = {}
-- The client's world map state: which map it shows, the floor, and whether it
-- can place the player on it.
local view = { areaId = 0, name = "HowlingFjord", level = 1, playerPos = { 0, 0 } }
_G.GetCurrentMapAreaID = function() return view.areaId end
_G.GetMapInfo = function() return view.name, 668, 1002 end
_G.GetCurrentMapDungeonLevel = function() return view.level end
_G.GetPlayerMapPosition = function() return view.playerPos[1], view.playerPos[2] end
_G.SetMapToCurrentZone = function() view.areaId = 523; view.name = "UtgardeKeep" end

local namespace = { GroupFinder = {} }
_G.DCMythicPlusHUD = namespace
local GF = namespace.GroupFinder
GF.spectatorHUD = CreateFrame("Frame")
GF.spectatorHUD.progressText = GF.spectatorHUD:CreateFontString()

dofile(ROOT..[[DC-MythicPlus\UI\SpectatorMap.lua]])
local SM = GF.SpectatorMap

print("SpectatorMap")

-- Utgarde Keep floor 1 straight from DungeonMap.dbc; the entrance and Prince
-- Keleseth from the world DB.
local UK1 = { index = 1, minX = -310.406, maxX = 424.175, minY = 25.6665, maxY = 515.388 }
local UK2 = { index = 2, minX = -238.156, maxX = 242.925, minY = -16.3333, maxY = 304.387 }
local ENTRANCE = { x = 153.8, y = -86.5 }
local KELESETH = { x = 193.1, y = 197.5 }

-- 1. World position -> floor fraction.
local ex, ey = SM.FloorFraction(UK1, ENTRANCE.x, ENTRANCE.y)
ok(near(ex, (424.175 + 86.5) / (424.175 + 310.406), 0.001) and near(ey, (515.388 - 153.8) / (515.388 - 25.6665), 0.001),
    "the entrance maps to (maxX - worldY) / span horizontally and (maxY - worldX) / span vertically")
local kx, ky = SM.FloorFraction(UK1, KELESETH.x, KELESETH.y)
ok(kx < ex and ky < ey, "Keleseth, west and north of the entrance, lands left of and above it")
ok(SM.FloorFraction({ index = 1, minX = 0, maxX = 0, minY = 0, maxY = 0 }, 1, 1) == nil, "a floor without bounds gives nothing")
local mx, my = SM.FloorFraction(UK1, ENTRANCE.x, ENTRANCE.y, true, false)
ok(near(mx, 1 - ex) and near(my, ey), "a flipped axis mirrors that axis only")

-- 2. Calibration against the client's own reading.
local cx, cy = SM.Calibrate(UK1, ENTRANCE.x, ENTRANCE.y, ex, ey)
ok(cx == false and cy == false, "a client that agrees needs no flip")
cx, cy = SM.Calibrate(UK1, ENTRANCE.x, ENTRANCE.y, 1 - ex, ey)
ok(cx == true and cy == false, "a mirrored horizontal reading flips the horizontal axis")
ok(SM.Calibrate(UK1, ENTRANCE.x, ENTRANCE.y, 0.5, 0.1) == nil, "a reading that matches neither way is ignored")

-- 3. Minimap projection (radius 64 px, 180 yards across => 0.7111 px per yard).
local me = { x = 100, y = 100 }
local px, py, dist, clamped = SM.ProjectMinimap(me, { x = 150, y = 100 }, 64, 180, nil)
ok(near(px, 0) and near(py, 50 * 64 / 90) and near(dist, 50) and not clamped, "50 yards north is straight up")
px, py = SM.ProjectMinimap(me, { x = 100, y = 50 }, 64, 180, nil)
ok(px > 0 and near(py, 0), "east (-Y) is to the right")
px, py = SM.ProjectMinimap(me, { x = 150, y = 100 }, 64, 180, math.pi / 2)
ok(near(px, 50 * 64 / 90) and near(py, 0), "facing west on a rotating minimap puts north on the right")
px, py, dist, clamped = SM.ProjectMinimap(me, { x = 1100, y = 100 }, 64, 180, nil)
ok(clamped and near(py, 64) and near(px, 0), "a member off the minimap is clamped onto the ring")
ok(SM.ProjectMinimap(nil, me, 64, 180) == nil and SM.ProjectMinimap(me, me, 0, 180) == nil, "missing inputs give nothing")

-- 4. A snapshot without the client extension: blips, roster, home map.
local snapshot = {
    system = "mplus", mapId = 574, floors = { UK1, UK2 },
    me = { x = ENTRANCE.x, y = ENTRANCE.y, z = 12.5, floor = 1 },
    players = {
        { name = "Laridina", guid = "0x0000000000000A01", class = 1, x = 160, y = -80, z = 12, floor = 1, health = 100, alive = true, leader = true },
        { name = "Kitlu", guid = "0x0000000000000A02", class = 5, x = 120, y = -30, z = 118, floor = 2, health = 70, alive = true },
        { name = "Lenele", guid = "0x0000000000000A03", class = 8, x = 150, y = -90, z = 12, floor = 1, health = 0, alive = false },
    },
}
GF:UpdateSpectatorMap(snapshot)
ok(shownCount(SM.blips) == 3, "one minimap blip per member")
ok(SM.blips[1].py > 0 and SM.blips[1].px < 0 and not SM.blips[1].live, "a member north-west of the spectator sits up and to the left (snapshot position)")
ok(SM.blips[2].px and not SM.blips[2].clamped, "a member on another floor still gets a blip")
ok(SM.state.homeMapName == "UtgardeKeep" and SM.state.homeMapAreaId == 523 and not SM.state.homeValidated,
    "the run's map is read from the client while the world map is closed; unvalidated until the client places the spectator")
ok(shownCount(SM.rosterRows) == 3, "one roster row per member")
local row1 = SM.rosterRows[1].text:GetText()
ok(has(row1, "Laridina") and has(row1, "(leader)") and has(row1, "100%"), "the leader's row names him, tags him and shows his health")
ok(has(SM.rosterRows[3].text:GetText(), "dead"), "a dead member's row says so")
ok(shownCount(SM.dots) == 0 and SM.state.lastReason == "map closed", "no dungeon-map dots while the world map is closed")

-- 5. Dungeon map dots follow the displayed floor, matched by the map's name.
view.playerPos = { ex, ey }
GF:UpdateSpectatorMap(snapshot)
ok(SM.state.homeValidated, "once the client places the spectator on the map, the home read is final")
WorldMapFrame:Show()
SM.RefreshWorldMap()
ok(SM.dots[1]:IsShown() and SM.dots[3]:IsShown() and not SM.dots[2]:IsShown(), "members on the displayed floor get a dot, the one upstairs does not")
local lx, ly = SM.FloorFraction(UK1, 160, -80)
ok(near(SM.dots[1].fx, lx) and near(SM.dots[1].fy, ly), "without the extension a dot sits at its member's floor fraction")
ok(SM.state.flips[1] and SM.state.flips[1].x == false and SM.state.flips[1].y == false, "the spectator's own reading calibrated floor 1 with no flip")
view.level = 2
SM.RefreshWorldMap()
ok(SM.dots[2]:IsShown() and not SM.dots[1]:IsShown(), "switching the map to floor 2 shows the member upstairs instead")
view.level = 0
SM.RefreshWorldMap()
ok(shownCount(SM.dots) == 0, "a floor the plan does not know shows nothing rather than guessing")
view.level = 1
view.areaId, view.name = 491, "HowlingFjord"
SM.RefreshWorldMap()
ok(shownCount(SM.dots) == 0 and SM.state.lastReason == "viewing another map", "looking at another map hides every dot")
view.areaId, view.name = 9999, "UtgardeKeep"
SM.RefreshWorldMap()
ok(shownCount(SM.dots) == 2, "the map's name alone identifies the run's dungeon, whatever id the client reports")

-- 6. A mirrored client reading flips the axis for that floor.
view.areaId = 523
SM.state.flips = {}
view.playerPos = { 1 - ex, ey }
SM.RefreshWorldMap()
ok(SM.state.flips[1] and SM.state.flips[1].x == true, "a mirrored horizontal reading is detected")
ok(near(SM.dots[1].fx, 1 - lx) and near(SM.dots[1].fy, ly), "and every dot on that floor is mirrored with it")
view.playerPos = { ex, ey }
SM.state.flips = {}

-- 7. Clicking watches, clicking the watched one frees.
SM.rosterRows[1]:GetScript("OnClick")(SM.rosterRows[1])
ok(sent[#sent] == ".spectate watch Laridina", "clicking a row asks to watch that member")
snapshot.players[1].watched = true
GF:UpdateSpectatorMap(snapshot)
ok(has(SM.rosterRows[1].text:GetText(), "[watching]"), "the watched member is tagged")
SM.dots[1]:GetScript("OnClick")(SM.dots[1])
ok(sent[#sent] == ".spectate free", "clicking the watched member releases the camera")
snapshot.players[1].watched = nil

-- 8. With the client extension: live positions for the spectator and members in view.
-- The extension translates against the WorldMapArea rectangle, which is 0/0/0/0
-- for every dungeon: on a dungeon floor its map coordinates come back NaN.
local NAN = 0 / 0
local units = {
    ["0x00000000000000AA"] = { x = ENTRANCE.x + 20, y = ENTRANCE.y - 10, z = 12.5 }, -- the spectator, walked on since the snapshot
    ["0x0000000000000A01"] = { x = 170, y = -70, z = 12, mapX = NAN, mapY = NAN },     -- Laridina, in view
}
_G.UnitGUID = function() return "0x00000000000000AA" end
_G.ResolveEntityPositionByGUID = function(guid)
    local unit = units[guid]
    if not unit then return nil end
    return guid, "unit", 574, unit.mapX, unit.mapY, unit.x, unit.y, unit.z
end
local translated = {}
local translateResult = function() return NAN, NAN end
_G.TranslateWorldPositionToCurrentMap = function(x, y, z)
    table.insert(translated, { x, y, z })
    local fx, fy = translateResult(x, y)
    return 574, fx, fy
end
GF:UpdateSpectatorMap(snapshot)
ok(SM.state.lastOwn and SM.state.lastOwn.live and near(SM.state.lastOwn.x, ENTRANCE.x + 20),
    "the minimap centre is the spectator's live position, not the snapshot's")
ok(SM.blips[1].live and not SM.blips[3].live, "a member in view is placed live, one out of view from the snapshot")
local livePx, livePy = SM.ProjectMinimap({ x = ENTRANCE.x + 20, y = ENTRANCE.y - 10 }, { x = 170, y = -70 }, 64, 180, nil)
ok(near(SM.blips[1].px, livePx) and near(SM.blips[1].py, livePy), "the live blip is projected from both live positions")
local lvx, lvy = SM.FloorFraction(UK1, 170, -70)
ok(SM.dots[1]:IsShown() and near(SM.dots[1].fx, lvx) and near(SM.dots[1].fy, lvy),
    "on a dungeon floor a member in view is placed from its live world position and the floor bounds, not the client's NaN")
local tx, ty = SM.FloorFraction(UK1, 150, -90)
ok(SM.dots[3]:IsShown() and near(SM.dots[3].fx, tx) and near(SM.dots[3].fy, ty) and #translated == 0,
    "a member out of view uses the floor bounds too; the client translation is not asked on a floor")
local dots = SM.DescribeDots()
ok(has(dots, "Laridina: ") and has(dots, "Kitlu: floor 2, map shows 1"), "/dcspecmap lists each dot or why it has none")

-- 8b. A map without floor data: the client's own translation, when it gives a real fraction.
ok(SM.ValidFraction(NAN, 0.5) == nil and SM.ValidFraction(0, 0) == nil and SM.ValidFraction(1.2, 0.5) == nil
    and SM.ValidFraction(0.25, 0.75) == 0.25, "only real, in-map fractions count; NaN, the (0,0) clamp and outside values do not")
local floorsBefore = snapshot.floors
snapshot.floors = {}
view.level = 0
units["0x0000000000000A01"].mapX, units["0x0000000000000A01"].mapY = 0.61, 0.70
translateResult = function() return 0.33, 0.44 end
GF:UpdateSpectatorMap(snapshot)
ok(SM.dots[1]:IsShown() and near(SM.dots[1].fx, 0.61) and near(SM.dots[1].fy, 0.70),
    "without floor data a member in view is placed by the client's map position")
ok(SM.dots[3]:IsShown() and near(SM.dots[3].fx, 0.33) and #translated > 0,
    "without floor data a member out of view goes through the client's translation")
translateResult = function() return NAN, NAN end
units["0x0000000000000A01"].mapX, units["0x0000000000000A01"].mapY = NAN, NAN
SM.RefreshWorldMap()
ok(not SM.dots[1]:IsShown() and not SM.dots[3]:IsShown() and has(SM.DescribeDots(), "no map position"),
    "a NaN answer hides the dot and says why")
snapshot.floors = floorsBefore
view.level = 1
_G.UnitGUID, _G.ResolveEntityPositionByGUID, _G.TranslateWorldPositionToCurrentMap = nil, nil, nil

-- 9. Fewer members, other systems, diagnostics, session end.
snapshot.players = { snapshot.players[1] }
GF:UpdateSpectatorMap(snapshot)
ok(shownCount(SM.blips) == 1 and shownCount(SM.rosterRows) == 1, "members that left take their blip and row with them")
ok(has(SM.Describe(), "members=1") and has(SM.Describe(), "home=UtgardeKeep/523 validated"), "/dcspecmap describes the overlay")
GF:UpdateSpectatorMap({ system = "hlbg", status = 1 })
ok(shownCount(SM.blips) == 0 and shownCount(SM.rosterRows) == 0, "a Hinterland snapshot clears the overlay")
GF:UpdateSpectatorMap(snapshot)
GF:HideSpectatorMap()
ok(shownCount(SM.blips) == 0 and shownCount(SM.dots) == 0 and SM.state.homeMapName == nil, "ending the session clears everything, home map included")

print(string.format("RESULT: %d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
