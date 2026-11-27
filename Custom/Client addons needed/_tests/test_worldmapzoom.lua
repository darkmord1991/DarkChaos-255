--[[
    Mouse-wheel zoom and drag-pan on the custom continent overviews (DC-QOS/Modules/WorldMapZoom.lua)
    on the strict 3.3.5a client. The map frames are stand-ins laid out the way WorldMapWindow leaves
    them (quest view: the 1002x668 detail frame at 0.691 under the positioning guide, the quest list
    hanging off its TOPRIGHT, the zone-name frame on WorldMapButton's top edge); the stock functions
    that move them are copied from the live FrameXML (patch-enGB-3 WorldMapFrame.lua).

    Pins come in the three kinds the DC addons use: one that never refreshes on its own
    (DC-Mapupgrades, DeathPins, GatherMate), one inside a full-canvas container (QuestMapPins), and the
    stock landmark POI that WorldMapFrame_Update places.

    Run from this directory:  lua test_worldmapzoom.lua        (-v prints every check)
]]

dofile("talents_sim.lua")
dofile("talents_client.lua")
local T = dofile("talents_testlib.lua")
local ok, section, noNewErrors = T.ok, T.section, T.noNewErrors
local CLIENT = SIM.client

local EPS = 1e-6

local function near(a, b, eps)
    return a and b and math.abs(a - b) <= (eps or EPS)
end

local function center(frame)
    local L, B, R, T2 = SIM.Rect(frame)
    if not L then
        return nil
    end
    return (L + R) / 2, (B + T2) / 2
end

local function rect(frame)
    return { SIM.Rect(frame) }
end

local function sameRect(a, b, eps)
    if #a ~= 4 or #b ~= 4 then
        return false
    end
    for i = 1, 4 do
        if not near(a[i], b[i], eps) then
            return false
        end
    end
    return true
end

-- ----------------------------------------------------------------------------
-- The client's map API
-- ----------------------------------------------------------------------------

-- UI map id = WorldMapArea.ID + 1. zone 0 = continent overview.
local MAPS = {
    [14] = { zone = 0, game = 1, area = 0 },        -- Kalimdor (WMA 13)
    [1263] = { zone = 0, game = 750, area = 0 },    -- The Sundered Wilds (80-130) overview (WMA 1262)
    [1268] = { zone = 0, game = 751, area = 0 },    -- Plaguelands overview (WMA 1267)
    [1217] = { zone = 3, game = 750, area = 4923 }, -- Hyjal Frontier (WMA 1216)
}
local displayed = 14
local boundsExport = true

function GetCurrentMapAreaID()
    return displayed
end

function GetCurrentMapZone()
    return MAPS[displayed].zone
end

local cursorX, cursorY = 0, 0
function GetCursorPosition()
    return cursorX, cursorY
end

local leftDown = false
function IsMouseButtonDown(button)
    return button == "LeftButton" and leftDown
end

local playerX, playerY = 0, 0
function GetPlayerMapPosition()
    return playerX, playerY
end

local arrow = { shown = nil, calls = 0 }
function ShowWorldMapArrowFrame(show)
    arrow.shown = show
    arrow.calls = arrow.calls + 1
end

function PositionWorldMapArrowFrame()
end

-- ----------------------------------------------------------------------------
-- The world map frames, as WorldMapWindow leaves them
-- ----------------------------------------------------------------------------

WORLDMAP_QUESTLIST_SIZE = 0.691
WORLDMAP_FULLMAP_SIZE = 1.0
WORLDMAP_SETTINGS = { size = WORLDMAP_QUESTLIST_SIZE }
WORLDMAP_POI_FRAMELEVEL = 100
NUM_WORLDMAP_DETAIL_TILES = 12
NUM_WORLDMAP_OVERLAYS = 1

WorldMapFrame = CreateFrame("Frame", "WorldMapFrame", UIParent)
WorldMapFrame:SetWidth(1024)
WorldMapFrame:SetHeight(768)
WorldMapFrame:SetScale(0.7)
WorldMapFrame:SetPoint("TOP", UIParent, "TOP", 0, -40)
WorldMapFrame:SetFrameLevel(WORLDMAP_POI_FRAMELEVEL - 13)

WorldMapPositioningGuide = CreateFrame("Frame", "WorldMapPositioningGuide", WorldMapFrame)
WorldMapPositioningGuide:SetWidth(1024)
WorldMapPositioningGuide:SetHeight(768)
WorldMapPositioningGuide:SetPoint("CENTER")

WorldMapDetailFrame = CreateFrame("Frame", "WorldMapDetailFrame", WorldMapFrame)
WorldMapDetailFrame:SetWidth(1002)
WorldMapDetailFrame:SetHeight(668)
WorldMapDetailFrame:SetScale(WORLDMAP_QUESTLIST_SIZE)
WorldMapDetailFrame:SetPoint("TOPLEFT", WorldMapPositioningGuide, "TOP", -726, -99)
WorldMapDetailFrame:SetFrameLevel(WORLDMAP_POI_FRAMELEVEL - 12)

-- The tile grid, edge tiles cropped to the 1002x668 canvas (WorldMapWindow.CropDetailTilePadding).
for i = 1, 12 do
    local tile = WorldMapDetailFrame:CreateTexture("WorldMapDetailTile" .. i, "BACKGROUND")
    tile:SetWidth((i % 4 == 0) and 234 or 256)
    tile:SetHeight((i > 8) and 156 or 256)
    if i == 1 then
        tile:SetPoint("TOPLEFT")
    elseif (i - 1) % 4 == 0 then
        tile:SetPoint("TOPLEFT", _G["WorldMapDetailTile" .. (i - 4)], "BOTTOMLEFT")
    else
        tile:SetPoint("TOPLEFT", _G["WorldMapDetailTile" .. (i - 1)], "TOPRIGHT")
    end
end

local overlay = WorldMapDetailFrame:CreateTexture("WorldMapOverlay1", "ARTWORK")

WorldMapBlobFrame = CreateFrame("QuestPOIFrame", "WorldMapBlobFrame", WorldMapFrame)
WorldMapBlobFrame:SetWidth(1002)
WorldMapBlobFrame:SetHeight(668)
WorldMapBlobFrame:SetScale(WORLDMAP_QUESTLIST_SIZE)
WorldMapBlobFrame:SetPoint("TOPLEFT", WorldMapDetailFrame)
WorldMapBlobFrame:SetFrameLevel(WORLDMAP_POI_FRAMELEVEL - 11)

WorldMapButton = CreateFrame("Button", "WorldMapButton", WorldMapFrame)
WorldMapButton:SetWidth(1002)
WorldMapButton:SetHeight(668)
WorldMapButton:SetScale(WORLDMAP_QUESTLIST_SIZE)
WorldMapButton:SetPoint("TOPLEFT", WorldMapDetailFrame)
WorldMapButton:SetFrameLevel(WORLDMAP_POI_FRAMELEVEL - 10)

local clicks = {}
WorldMapButton:SetScript("OnMouseUp", function(_, button)
    clicks[#clicks + 1] = button
end)

WorldMapPlayer = CreateFrame("Frame", "WorldMapPlayer", WorldMapButton)
WorldMapPlayer:SetWidth(16)
WorldMapPlayer:SetHeight(16)
WorldMapPlayer:SetPoint("CENTER")

-- The native arrow models (CGWorldMap::CreateArrowFrame): SetModelScale stores the value as is.
local ARROW_STOCK_SCALE = 0.8
for _, name in ipairs({ "PlayerArrowFrame", "PlayerArrowEffectFrame" }) do
    local model = CreateFrame("Model", name, WorldMapFrame)
    model.modelScale = ARROW_STOCK_SCALE
    model.GetModelScale = function(self)
        return self.modelScale
    end
    model.SetModelScale = function(self, scale)
        self.modelScale = scale
    end
end

-- WorldMapButton_OnUpdate, the player half
WorldMapButton:SetScript("OnUpdate", function()
    local x, y = GetPlayerMapPosition("player")
    if x == 0 and y == 0 then
        ShowWorldMapArrowFrame(nil)
        return
    end
    x = x * WorldMapDetailFrame:GetWidth()
    y = -y * WorldMapDetailFrame:GetHeight()
    PositionWorldMapArrowFrame("CENTER", "WorldMapDetailFrame", "TOPLEFT", x * WORLDMAP_SETTINGS.size, y * WORLDMAP_SETTINGS.size)
    ShowWorldMapArrowFrame(1)
    WorldMapPlayer:SetPoint("CENTER", "WorldMapDetailFrame", "TOPLEFT", x, y)
end)

WorldMapFrameAreaFrame = CreateFrame("Frame", "WorldMapFrameAreaFrame", WorldMapButton)
WorldMapFrameAreaFrame:SetWidth(400)
WorldMapFrameAreaFrame:SetHeight(128)
WorldMapFrameAreaFrame:SetPoint("TOP", 0, -10)
WorldMapFrameAreaFrame:SetScale(WORLDMAP_QUESTLIST_SIZE)

WorldMapPOIFrame = CreateFrame("Frame", "WorldMapPOIFrame", WorldMapFrame)
WorldMapPOIFrame:SetWidth(1002)
WorldMapPOIFrame:SetHeight(668)
WorldMapPOIFrame:SetPoint("TOPLEFT", WorldMapDetailFrame)
WorldMapPOIFrame:SetFrameLevel(WORLDMAP_POI_FRAMELEVEL)

WorldMapQuestScrollFrame = CreateFrame("ScrollFrame", "WorldMapQuestScrollFrame", WorldMapFrame)
WorldMapQuestScrollFrame:SetWidth(283)
WorldMapQuestScrollFrame:SetHeight(670)
WorldMapQuestScrollFrame:SetPoint("TOPLEFT", WorldMapDetailFrame, "TOPRIGHT", 6, 0)

local landmark = CreateFrame("Button", "WorldMapFramePOI1", WorldMapButton)
landmark:SetWidth(32)
landmark:SetHeight(32)

-- A quest POI number, placed the way WorldMapFrame_DisplayQuestPOI does.
local questPOI = CreateFrame("Button", "poiWorldMapPOIFrame1_1", WorldMapPOIFrame)
questPOI:SetWidth(24)
questPOI:SetHeight(24)
questPOI:SetPoint("CENTER", WorldMapPOIFrame, "TOPLEFT",
    0.40 * 1002 * WORLDMAP_QUESTLIST_SIZE, -0.60 * 668 * WORLDMAP_QUESTLIST_SIZE)

-- DC-Mapupgrades-style pin: placed once, HIGH strata, no refresh on a size change.
local rarePin = CreateFrame("Button", "TestRarePin", WorldMapButton)
rarePin:SetWidth(22)
rarePin:SetHeight(22)
rarePin:SetFrameStrata("HIGH")
rarePin:SetPoint("CENTER", WorldMapButton, "TOPLEFT", 0.50 * 1002, -0.45 * 668)

-- QuestMapPins-style: a full-canvas container with its pins anchored to the container.
local container = CreateFrame("Frame", "TestPinOverlay", WorldMapButton)
container:SetAllPoints(WorldMapButton)
local questPin = CreateFrame("Button", "TestQuestPin", container)
questPin:SetWidth(18)
questPin:SetHeight(18)
questPin:SetPoint("CENTER", container, "TOPLEFT", 0.58 * 1002, -0.25 * 668)

-- ----------------------------------------------------------------------------
-- Stock functions (live FrameXML), and WorldMapWindow's hook
-- ----------------------------------------------------------------------------

function WorldMapFrame_SetQuestMapView()
    WORLDMAP_SETTINGS.size = WORLDMAP_QUESTLIST_SIZE
    WorldMapDetailFrame:SetScale(WORLDMAP_QUESTLIST_SIZE)
    WorldMapButton:SetScale(WORLDMAP_QUESTLIST_SIZE)
    WorldMapFrameAreaFrame:SetScale(WORLDMAP_QUESTLIST_SIZE)
    WorldMapDetailFrame:SetPoint("TOPLEFT", WorldMapPositioningGuide, "TOP", -726, -99)
end

function WorldMapFrame_SetFullMapView()
    WORLDMAP_SETTINGS.size = WORLDMAP_FULLMAP_SIZE
    WorldMapDetailFrame:SetScale(WORLDMAP_FULLMAP_SIZE)
    WorldMapButton:SetScale(WORLDMAP_FULLMAP_SIZE)
    WorldMapFrameAreaFrame:SetScale(WORLDMAP_FULLMAP_SIZE)
    WorldMapDetailFrame:SetPoint("TOPLEFT", WorldMapPositioningGuide, "TOP", -502, -69)
end

function WorldMapFrame_SetPOIMaxBounds()
    WORLDMAP_POI_MAX_Y = WorldMapDetailFrame:GetHeight() * -WORLDMAP_SETTINGS.size + 12
    WORLDMAP_POI_MAX_X = WorldMapDetailFrame:GetWidth() * WORLDMAP_SETTINGS.size + 12
end

-- No quests on a continent overview: stock drops to the full view, the window puts the quest view back.
function WorldMapFrame_DisplayQuests()
    if WORLDMAP_SETTINGS.size == WORLDMAP_QUESTLIST_SIZE then
        WorldMapFrame_SetFullMapView()
    end
    WorldMapBlobFrame:Hide()
    WorldMapPOIFrame:Hide()
end

local windowActive = true
-- WorldMapWindow.ApplyQuestView, run from its hook on the view switches
hooksecurefunc("WorldMapFrame_SetFullMapView", function()
    if not windowActive then
        return
    end
    WORLDMAP_SETTINGS.size = WORLDMAP_QUESTLIST_SIZE
    WorldMapDetailFrame:SetScale(WORLDMAP_QUESTLIST_SIZE)
    WorldMapDetailFrame:ClearAllPoints()
    WorldMapDetailFrame:SetPoint("TOPLEFT", WorldMapPositioningGuide, "TOP", -726, -99)
    WorldMapButton:SetScale(WORLDMAP_QUESTLIST_SIZE)
    WorldMapFrameAreaFrame:SetScale(WORLDMAP_QUESTLIST_SIZE)
    WorldMapBlobFrame:SetScale(WORLDMAP_QUESTLIST_SIZE)
    WorldMapBlobFrame.xRatio = nil
    WorldMapFrame_SetPOIMaxBounds()
end)

-- WorldMapFrame_Update: the landmark POI and the overlays, in base units every time.
local overlayShown = true
function WorldMapFrame_Update()
    landmark:SetPoint("CENTER", "WorldMapButton", "TOPLEFT", 0.55 * WorldMapButton:GetWidth(), -0.30 * WorldMapButton:GetHeight())
    if overlayShown then
        overlay:SetWidth(200)
        overlay:SetHeight(150)
        overlay:SetPoint("TOPLEFT", 300, -100)
        overlay:Show()
    else
        overlay:Hide()
    end
end

-- WORLD_MAP_UPDATE -> WorldMapFrame_UpdateMap -> WorldMapFrame_Update
local function ShowMap(uiMapId)
    displayed = uiMapId
    WorldMapFrame_Update()
end

-- ----------------------------------------------------------------------------
-- DC-QOS
-- ----------------------------------------------------------------------------

DCQOS = {
    settings = { worldMapZoom = { enabled = true, maxZoom = 4 } },
    modules = {},
}

function DCQOS:RegisterModule(name, module)
    self.modules[name] = module
end

local mapUtils = {
    GetMapAreaBounds = function(uiMapId)
        local map = boundsExport and MAPS[uiMapId]
        if not map then
            return nil
        end
        return map.game, -1000, 1000, 1000, -1000, map.area
    end,
}

function DCQOS:GetMapUtils()
    return mapUtils
end

-- DC_WORLDMAPZOOM_FILE points the test at another copy of the module.
SIM.LoadFile(os.getenv("DC_WORLDMAPZOOM_FILE") or (SIM.ADDONS_DIR .. "DC-QOS/Modules/WorldMapZoom.lua"), "DC-QOS", {})
local Zoom = DCQOS.modules.WorldMapZoom

local function wheel(delta)
    SIM.CallScript(WorldMapButton, "OnMouseWheel", delta)
end

local function zoomState()
    return Zoom.GetZoom()
end

-- Everything the zoom may touch, to compare with after it lets go.
local function snapshot()
    local s = { rects = {}, centers = {}, parents = {}, levels = {} }
    local frames = {
        WorldMapDetailFrame, WorldMapBlobFrame, WorldMapButton, WorldMapPOIFrame,
        WorldMapQuestScrollFrame, WorldMapFrameAreaFrame, container,
    }
    for i = 1, 12 do
        frames[#frames + 1] = _G["WorldMapDetailTile" .. i]
    end
    frames[#frames + 1] = overlay
    for _, f in ipairs(frames) do
        s.rects[f] = rect(f)
    end
    for _, f in ipairs({ rarePin, questPin, landmark, questPOI }) do
        s.centers[f] = { center(f) }
    end
    for _, f in ipairs({ WorldMapDetailFrame, WorldMapBlobFrame, WorldMapButton, WorldMapPOIFrame }) do
        s.parents[f] = f:GetParent()
        s.levels[f] = f:GetFrameLevel()
    end
    s.maxX, s.maxY = WORLDMAP_POI_MAX_X, WORLDMAP_POI_MAX_Y
    return s
end

local function restoredTo(base, label)
    local now = snapshot()
    local okRects, okCenters, okParents = true, true, true
    for f, r in pairs(base.rects) do
        if not sameRect(r, now.rects[f], 1e-4) then
            okRects = false
            T.out("    moved: " .. tostring(f:GetName()))
        end
    end
    for f, c in pairs(base.centers) do
        if not (near(c[1], now.centers[f][1], 1e-4) and near(c[2], now.centers[f][2], 1e-4)) then
            okCenters = false
            T.out("    pin moved: " .. tostring(f:GetName()))
        end
    end
    for f, p in pairs(base.parents) do
        if now.parents[f] ~= p or now.levels[f] ~= base.levels[f] then
            okParents = false
            T.out("    parent/level changed: " .. tostring(f:GetName()))
        end
    end
    ok(okRects, label .. ": every map frame, tile and overlay is back on its stock rectangle")
    ok(okCenters, label .. ": every pin is back where it was")
    ok(okParents, label .. ": the canvas frames are WorldMapFrame's children again, on their own levels")
    ok(near(now.maxX, base.maxX, 1e-4) and near(now.maxY, base.maxY, 1e-4), label .. ": quest POI bounds are the stock ones")
    ok(not Zoom.IsEngaged(), label .. ": the zoom let go")
end

-- ----------------------------------------------------------------------------
section("Only the custom continent overviews zoom")
-- ----------------------------------------------------------------------------

Zoom.OnEnable()
ShowMap(14)
WorldMapFrame_SetPOIMaxBounds()
ok(not WorldMapButton:IsMouseWheelEnabled(), "Kalimdor: the wheel stays off the map (the camera keeps it)")
wheel(1)
ok(not Zoom.IsEngaged(), "Kalimdor: the wheel does nothing")

ShowMap(1217)
ok(not WorldMapButton:IsMouseWheelEnabled(), "a zone map of map 750 does not zoom")

ShowMap(1268)
ok(WorldMapButton:IsMouseWheelEnabled(), "the Plaguelands overview (751) takes the wheel")

boundsExport = false
ShowMap(14)
ok(not WorldMapButton:IsMouseWheelEnabled(), "without the bounds export Kalimdor still does not zoom")
ShowMap(1263)
ok(WorldMapButton:IsMouseWheelEnabled(), "without the bounds export the Mount Hyjal overview is known by its UI map id")
boundsExport = true

ShowMap(1263)
ok(WorldMapButton:IsMouseWheelEnabled(), "the Mount Hyjal overview (750) takes the wheel")
noNewErrors("eligibility")

-- ----------------------------------------------------------------------------
section("The player arrow size")
-- ----------------------------------------------------------------------------

local function arrowScales()
    return PlayerArrowFrame:GetModelScale(), PlayerArrowEffectFrame:GetModelScale()
end

local a1, a2 = arrowScales()
ok(near(a1, ARROW_STOCK_SCALE * 1.5) and near(a2, ARROW_STOCK_SCALE * 1.5), "the arrow and its effect are 1.5x by default")
ok(near(WorldMapPlayer:GetWidth(), 24) and near(WorldMapPlayer:GetHeight(), 24), "its tooltip area grows with it")
WorldMapFrame:Hide()
WorldMapFrame:Show()
WorldMapFrame:Hide()
WorldMapFrame:Show()
a1 = arrowScales()
ok(near(a1, ARROW_STOCK_SCALE * 1.5), "opening the map again does not grow it further")
DCQOS.settings.worldMapZoom.playerArrowScale = 2
WorldMapFrame:Hide()
WorldMapFrame:Show()
a1 = arrowScales()
ok(near(a1, ARROW_STOCK_SCALE * 2) and near(WorldMapPlayer:GetWidth(), 32), "a new size is taken from the stock size, not stacked")
DCQOS.settings.worldMapZoom.playerArrowScale = 50
WorldMapFrame:Hide()
WorldMapFrame:Show()
a1 = arrowScales()
ok(near(a1, ARROW_STOCK_SCALE * 3), "the size is capped at 3x")
DCQOS.settings.worldMapZoom.playerArrowScale = nil
WorldMapFrame:Hide()
WorldMapFrame:Show()
ShowMap(1263)
noNewErrors("arrow size")

-- ----------------------------------------------------------------------------
section("Zooming at the cursor")
-- ----------------------------------------------------------------------------

local base = snapshot()
local viewRect = rect(WorldMapDetailFrame)

cursorX, cursorY = center(rarePin)
local q0x, q0y = center(questPin)
local l0x, l0y = center(landmark)
local pinW = select(3, SIM.Rect(rarePin)) - SIM.Rect(rarePin)

wheel(1)
local zoom = zoomState()
ok(Zoom.IsEngaged() and near(zoom, 1.25), "one notch zooms in to 1.25")
ok(sameRect(rect(DCQOSWorldMapZoomFrame), viewRect, 1e-4), "the viewport covers the map's stock rectangle")
ok(WorldMapDetailFrame:GetParent() == DCQOSWorldMapZoomCanvas and WorldMapButton:GetParent() == DCQOSWorldMapZoomCanvas,
    "the canvas frames live in the clipping scroll frame")
ok(near(WorldMapButton:GetWidth(), 1002 * 1.25, 1e-4) and near(WorldMapDetailFrame:GetHeight(), 668 * 1.25, 1e-4),
    "the canvas grows instead of scaling")
ok(near(WorldMapDetailFrame:GetScale(), WORLDMAP_QUESTLIST_SIZE) and near(WorldMapButton:GetScale(), WORLDMAP_QUESTLIST_SIZE),
    "frame scales stay stock (other code reads them)")
ok(near(WorldMapDetailTile1:GetWidth(), 256 * 1.25) and near(WorldMapDetailTile12:GetWidth(), 234 * 1.25)
    and near(WorldMapDetailTile12:GetHeight(), 156 * 1.25), "tiles grow with it, cropped edges included")

local cx, cy = center(rarePin)
ok(near(cx, cursorX, 1e-4) and near(cy, cursorY, 1e-4), "the pin under the cursor stays under the cursor")
local qx, qy = center(questPin)
ok(near(qx, cursorX + (q0x - cursorX) * 1.25, 1e-4) and near(qy, cursorY + (q0y - cursorY) * 1.25, 1e-4),
    "a pin in a full-canvas container spreads out by the zoom")
local lx, ly = center(landmark)
ok(near(lx, cursorX + (l0x - cursorX) * 1.25, 1e-4) and near(ly, cursorY + (l0y - cursorY) * 1.25, 1e-4),
    "the stock landmark POI spreads out by the zoom")
local newPinW = select(3, SIM.Rect(rarePin)) - SIM.Rect(rarePin)
ok(near(newPinW, pinW, 1e-6), "pins keep their size")
ok(sameRect(rect(WorldMapQuestScrollFrame), base.rects[WorldMapQuestScrollFrame], 1e-4), "the quest list does not move")
ok(sameRect(rect(WorldMapFrameAreaFrame), base.rects[WorldMapFrameAreaFrame], 1e-4), "the zone name stays on the visible map's top edge")
ok(near(WORLDMAP_POI_MAX_X, 1002 * 1.25 * WORLDMAP_QUESTLIST_SIZE + 12, 1e-4), "quest POIs are clamped to the grown canvas")

-- Stock writes the overlays in base units on every map update.
local _, _, _, ox, oy = overlay:GetPoint(1)
ok(near(overlay:GetWidth(), 250) and near(ox, 375) and near(oy, -125), "explored-area overlays are scaled")
WorldMapFrame_Update()
_, _, _, ox, oy = overlay:GetPoint(1)
ok(Zoom.IsEngaged() and near(overlay:GetWidth(), 250) and near(ox, 375) and near(oy, -125),
    "a map update on the same map keeps the zoom and rescales what it rewrote")

for _ = 1, 12 do
    wheel(1)
end
ok(near(zoomState(), 4), "zoom stops at the maximum (4)")
cx, cy = center(rarePin)
ok(near(cx, cursorX, 1e-3) and near(cy, cursorY, 1e-3), "the pin is still under the cursor at full zoom")
noNewErrors("zooming")

-- ----------------------------------------------------------------------------
section("Stock moving the detail frame while zoomed")
-- ----------------------------------------------------------------------------

-- Every quest-log update on a map without quests: full view, then WorldMapWindow's quest view.
local before = { center(rarePin) }
WorldMapFrame_DisplayQuests()
ok(Zoom.IsEngaged() and near(zoomState(), 4), "the view flip of a quest-log update keeps the zoom")
ok(sameRect(rect(DCQOSWorldMapZoomFrame), viewRect, 1e-4), "the viewport ends where the window put the map")
local after = { center(rarePin) }
ok(near(before[1], after[1], 1e-4) and near(before[2], after[2], 1e-4), "pins have not moved")
ok(WorldMapDetailFrame:GetParent() == DCQOSWorldMapZoomCanvas, "the detail frame is still in the canvas")

-- Without the window: the full view stays, and the viewport takes the full view's rectangle.
windowActive = false
local reference = CreateFrame("Frame", nil, WorldMapFrame)
reference:SetWidth(1002)
reference:SetHeight(668)
reference:SetScale(WORLDMAP_FULLMAP_SIZE)
reference:SetPoint("TOPLEFT", WorldMapPositioningGuide, "TOP", -502, -69)
WorldMapFrame_SetFullMapView()
ok(sameRect(rect(DCQOSWorldMapZoomFrame), rect(reference), 1e-4), "full map view: the viewport moves and grows to the full view")
ok(Zoom.IsEngaged() and near(zoomState(), 4), "full map view: still zoomed")
WorldMapFrame_SetQuestMapView()
ok(sameRect(rect(DCQOSWorldMapZoomFrame), viewRect, 1e-4), "back to the quest view: the viewport follows")
windowActive = true
noNewErrors("view switches")

-- ----------------------------------------------------------------------------
section("Panning")
-- ----------------------------------------------------------------------------

before = { center(rarePin) }
leftDown = true
SIM.CallScript(WorldMapButton, "OnMouseDown", "LeftButton")
cursorX, cursorY = cursorX + 2, cursorY + 1
SIM.Tick()
local mid = { center(rarePin) }
ok(near(mid[1], before[1], 1e-6) and near(mid[2], before[2], 1e-6), "a press that moves less than the threshold is not a pan")
cursorX, cursorY = cursorX + 58, cursorY - 31
SIM.Tick()
after = { center(rarePin) }
ok(near(after[1], before[1] + 60, 1e-4) and near(after[2], before[2] - 30, 1e-4), "the map follows the cursor")
leftDown = false
SIM.CallScript(WorldMapButton, "OnMouseUp", "LeftButton")
cursorX, cursorY = cursorX + 40, cursorY + 40
SIM.Tick()
local released = { center(rarePin) }
ok(near(released[1], after[1], 1e-6) and near(released[2], after[2], 1e-6), "releasing ends the pan")
ok(clicks[#clicks] == "LeftButton", "the stock click handler still runs (it is not wrapped)")

-- Drag far past the edge: the canvas stops at it.
leftDown = true
SIM.CallScript(WorldMapButton, "OnMouseDown", "LeftButton")
cursorX = cursorX + 5000
SIM.Tick()
local _, pX = zoomState()
ok(near(pX, 0, 1e-6), "panning stops at the map's left edge")
local dL = SIM.Rect(WorldMapDetailFrame)
ok(near(dL, viewRect[1], 1e-4), "the canvas edge lines up with the viewport edge")
-- Released off the map: no OnMouseUp reaches WorldMapButton.
leftDown = false
SIM.Tick()
before = { center(rarePin) }
cursorX, cursorY = cursorX - 300, cursorY - 200
SIM.Tick()
after = { center(rarePin) }
ok(near(before[1], after[1], 1e-6) and near(before[2], after[2], 1e-6),
    "a release OnMouseUp did not see still ends the pan on the next frame")
noNewErrors("panning")

-- ----------------------------------------------------------------------------
section("The player arrow")
-- ----------------------------------------------------------------------------

-- Left edge in view now; the player far to the east is out of it.
playerX, playerY = 0.95, 0.5
SIM.Tick()
ok(arrow.shown == nil, "the native arrow (not clippable) hides while the player is off the visible map")
playerX, playerY = 0.05, 0.5
SIM.Tick()
ok(arrow.shown == 1, "and shows when the player is on it")
playerX, playerY = 0, 0
noNewErrors("arrow")

-- ----------------------------------------------------------------------------
section("Zooming back out")
-- ----------------------------------------------------------------------------

local notches = 0
while Zoom.IsEngaged() and notches < 20 do
    wheel(-1)
    notches = notches + 1
end
ok(notches == 6, "six notches from 4x return to the stock map (got " .. notches .. ")")
restoredTo(base, "wheel out")
ok(WorldMapButton:IsMouseWheelEnabled(), "the overview keeps the wheel")
noNewErrors("zoom out")

-- ----------------------------------------------------------------------------
section("Leaving the overview resets the zoom")
-- ----------------------------------------------------------------------------

cursorX, cursorY = center(rarePin)
wheel(1)
wheel(1)
ok(Zoom.IsEngaged(), "zoomed in again")
ShowMap(1217)
restoredTo(base, "zone label / map change")
ok(not WorldMapButton:IsMouseWheelEnabled(), "the zone map hands the wheel back")

ShowMap(1263)
wheel(1)
ok(Zoom.IsEngaged(), "zoomed in again")
WorldMapFrame:Hide()
restoredTo(base, "map closed")
WorldMapFrame:Show()
ShowMap(1263)

wheel(1)
ok(Zoom.IsEngaged(), "zoomed in again")
CLIENT.player.inCombat = true
SIM.FireEvent("PLAYER_REGEN_DISABLED")
restoredTo(base, "combat")
wheel(1)
ok(not Zoom.IsEngaged(), "no zoom in combat")
CLIENT.player.inCombat = false

-- Overlays hidden on the next map: nothing of the old map's sizes leaks onto it.
wheel(1)
overlayShown = false
ShowMap(1268)
ok(Zoom.IsEngaged() == false, "switching overviews resets the zoom")
overlayShown = true
ShowMap(1263)
restoredTo(base, "overview switch")

Zoom.OnDisable()
ok(not WorldMapButton:IsMouseWheelEnabled(), "disabling the module hands the wheel back")
a1, a2 = arrowScales()
ok(near(a1, ARROW_STOCK_SCALE) and near(a2, ARROW_STOCK_SCALE) and near(WorldMapPlayer:GetWidth(), 16),
    "disabling the module gives the arrow its stock size back")
wheel(1)
ok(not Zoom.IsEngaged(), "disabled: the wheel does nothing")
noNewErrors("resets")

T.out(("RESULT %d passed, %d failed"):format(T.pass, T.fail))
os.exit(T.fail == 0 and 0 or 1)
