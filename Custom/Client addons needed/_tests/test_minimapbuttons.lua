-- DC-QOS minimap button ring (DC-QOS/Modules/Minimap.lua, ButtonRing).
--
-- Laid out against a geometry model of the real screen: a 1024x768 UIParent,
-- DC-InfoBar along the top, MinimapCluster in the top-right corner under it and
-- the stock 3.3.5 zone text and clock frames. The starting angles are the ones
-- found in a live SavedVariables file (WeakAuras 195.5, AzerothAdmin 213,
-- queue eye 218, BugSack 235.5, DC-Welcome 166.6, GOMove at its default) on the
-- square DC frame -- the layout that put four buttons on top of each other.
--
-- Pins: no two buttons overlap, nothing covers the zone text, the clock or the
-- info bar, nothing leaves the screen or drops below the cluster into the quest
-- tracker, every owner's saved angle reproduces the spot the ring chose, a
-- settled layout is stable, a newcomer moves instead of the buttons already on
-- screen, a dropped button snaps to a free spot without shoving its neighbours,
-- a full ring spills onto the outer track rather than overlapping, the instance
-- difficulty badge hangs inside the map's top-left corner (a full left edge
-- used to push it out onto an outer track) and a button in its way steps aside
-- only while it shows, and turning the module off puts the stock buttons and the
-- badge back on their original anchors.

dofile("wowsim.lua")
local ROOT = [[K:\Dark-Chaos\DarkChaos-255-Master\Custom\Client addons needed\]]
local pass, fail = 0, 0
local function ok(c, m) if c then pass = pass + 1; print("  PASS " .. m) else fail = fail + 1; print("  FAIL " .. m) end end

local unpack = table.unpack or unpack

-- ------------------------------------------------------------------
-- Geometry frames: single-point anchors resolve to real coordinates.
-- ------------------------------------------------------------------
local Geo = {}
Geo.__index = Geo

local function newFrame(name, w, h, parent, center, ftype)
    local f = setmetatable({
        _name = name, _w = w, _h = h, _shown = true, _alpha = 1,
        _points = {}, _hooks = {}, _scripts = {}, _children = {},
        _parent = parent, _type = ftype or "Button", _fixed = center,
    }, Geo)
    if parent then table.insert(parent._children, f) end
    if name then _G[name] = f end
    return f
end

function Geo:GetName() return self._name end
function Geo:GetObjectType() return self._type end
function Geo:GetWidth() return self._w end
function Geo:GetHeight() return self._h end
function Geo:GetParent() return self._parent end
function Geo:GetChildren() return unpack(self._children) end
function Geo:GetEffectiveScale() return 1 end
function Geo:IsShown() return self._shown end
function Geo:IsVisible()
    local f = self
    while f do
        if not f._shown then return false end
        f = f._parent
    end
    return true
end
function Geo:_fire(script)
    for _, fn in ipairs(self._hooks[script] or {}) do fn(self) end
end
function Geo:Show() if not self._shown then self._shown = true; self:_fire("OnShow") end end
function Geo:Hide() if self._shown then self._shown = false; self:_fire("OnHide") end end
function Geo:HookScript(script, fn)
    self._hooks[script] = self._hooks[script] or {}
    table.insert(self._hooks[script], fn)
end
function Geo:SetScript(script, fn) self._scripts[script] = fn end
function Geo:GetScript(script) return self._scripts[script] end
function Geo:RegisterForDrag(...) self._drag = { ... } end
function Geo:SetAlpha(a) self._alpha = a end
function Geo:GetAlpha() return self._alpha end
function Geo:ClearAllPoints() self._points = {} end
function Geo:SetPoint(point, rel, relPoint, x, y)
    table.insert(self._points, { point, rel, relPoint, x or 0, y or 0 })
end
function Geo:GetNumPoints() return #self._points end
function Geo:GetPoint(i)
    local p = self._points[i]
    if p then return unpack(p) end
end
-- Anchor points as fractions of a frame's size, measured from its centre.
local POINT_OFFSETS = {
    CENTER = { 0, 0 }, TOP = { 0, 0.5 }, BOTTOM = { 0, -0.5 }, LEFT = { -0.5, 0 }, RIGHT = { 0.5, 0 },
    TOPLEFT = { -0.5, 0.5 }, TOPRIGHT = { 0.5, 0.5 }, BOTTOMLEFT = { -0.5, -0.5 }, BOTTOMRIGHT = { 0.5, -0.5 },
}

function Geo:GetCenter()
    if self._fixed then return self._fixed[1], self._fixed[2] end
    local p = self._points[1]
    if p and #self._points == 1 then
        local own, rel = POINT_OFFSETS[p[1]], POINT_OFFSETS[p[3]]
        local rx, ry = p[2]:GetCenter()
        if own and rel and rx then
            return rx + rel[1] * p[2]._w + p[4] - own[1] * self._w,
                ry + rel[2] * p[2]._h + p[5] - own[2] * self._h
        end
    end
    return nil
end
function Geo:GetLeft() local x = self:GetCenter(); return x and x - self._w / 2 end
function Geo:GetRight() local x = self:GetCenter(); return x and x + self._w / 2 end
function Geo:GetBottom() local _, y = self:GetCenter(); return y and y - self._h / 2 end
function Geo:GetTop() local _, y = self:GetCenter(); return y and y + self._h / 2 end

function _G.hooksecurefunc(tbl, name, hook)
    if type(tbl) == "string" then
        tbl, name, hook = _G, tbl, name
    end
    local orig = tbl[name]
    tbl[name] = function(...)
        local results = table.pack(orig(...))
        hook(...)
        return unpack(results, 1, results.n)
    end
end

-- ------------------------------------------------------------------
-- The screen
-- ------------------------------------------------------------------
_G.UIParent = newFrame("UIParent", 1024, 768, nil, { 512, 384 }, "Frame")
-- 22px info bar across the top.
newFrame("DCInfoBarFrame", 1024, 22, UIParent, { 512, 757 }, "Frame")
-- Cluster TOPRIGHT at (-2, -22): right edge 1022, top edge 746.
_G.MinimapCluster = newFrame("MinimapCluster", 192, 192, UIParent, { 926, 650 }, "Frame")
-- Minimap: CENTER on the cluster's TOP, offset (9, -92).
_G.Minimap = newFrame("Minimap", 140, 140, MinimapCluster, { 935, 654 }, "Minimap")
-- Zone text: CENTER on the cluster centre, offset (7, 83), 150x12.
newFrame("MinimapZoneTextButton", 150, 12, MinimapCluster, { 933, 733 })
-- Clock: CENTER on the minimap centre, offset (0, -68), 60x28.
newFrame("TimeManagerClockButton", 60, 28, Minimap, { 935, 586 })
_G.MinimapBackdrop = newFrame("MinimapBackdrop", 192, 192, Minimap, { 926, 630 }, "Frame")

-- Map pins share the Minimap parent and must never be pulled onto the ring.
for i = 1, 3 do
    newFrame("DCMapupgradesEntityMinimapPin" .. i, 16, 16, Minimap, { 900 + i, 650 })
end

local shape = "SQUARE"
_G.GetMinimapShape = function() return shape end
_G.GameTooltip = { IsOwned = function() return false end, Hide = function() end }
_G.GetCursorPosition = function() return 0, 0 end

-- LibDBIcon r21's own placement, verbatim math, for "where would the owner put it".
local function ownerOffset(angle, radius)
    radius = radius or 80
    local rad = math.rad(angle)
    local x, y = math.cos(rad), math.sin(rad)
    if shape == "ROUND" then
        return x * radius, y * radius
    end
    local diag = math.sqrt(2 * radius * radius) - 10
    return math.max(-radius, math.min(x * diag, radius)), math.max(-radius, math.min(y * diag, radius))
end

local function placeByOwner(frame, angle)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", Minimap, "CENTER", ownerOffset(angle))
end

-- ------------------------------------------------------------------
-- The buttons, at the angles from the live SavedVariables
-- ------------------------------------------------------------------
local lib = { objects = {} }
function lib:Register() end
function lib:Show() end
_G.LibStub = setmetatable({}, { __call = function(_, name) if name == "LibDBIcon-1.0" then return lib end end })

local function addLauncher(name, angle)
    local button = newFrame("LibDBIcon10_" .. name, 31, 31, Minimap)
    button.db = { minimapPos = angle }
    lib.objects[name] = button
    placeByOwner(button, angle)
    return button
end

local weakAuras = addLauncher("WeakAuras", 195.5484298679096)
local azerothAdmin = addLauncher("AzerothAdmin", 212.9774448635424)
local bugSack = addLauncher("BugSack", 235.4693618181772)

_G.DCWelcomeDB = { minimapButton = { angle = 166.6044284887666 } }
local welcome = newFrame("DCWelcomeMinimapButton", 31, 31, Minimap)
placeByOwner(welcome, DCWelcomeDB.minimapButton.angle)

_G.DCMythicPlusHUDDB = { minimapQueue = { enabled = true, angle = 218 } }
local eye = newFrame("DCMatchmakingQueueEye", 33, 33, Minimap)
placeByOwner(eye, 218)

_G.GOMoveSV = {}
local goMove = newFrame("GOMove_UI_MapButton", 27, 27, Minimap)
goMove:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -25, -60)

-- Stock buttons: mail not up yet; the world map button shown but faded out.
local mail = newFrame("MiniMapMailFrame", 33, 33, Minimap, nil, "Frame")
mail:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", 21, -53)
mail._shown = false
local worldMap = newFrame("MiniMapWorldMapButton", 33, 33, MinimapBackdrop)
worldMap:SetPoint("TOPRIGHT", MinimapBackdrop, "TOPRIGHT", -21, -1)
worldMap:SetAlpha(0)
-- The instance difficulty badge, on its stock anchor; it only shows inside instances.
local badge = newFrame("MiniMapInstanceDifficulty", 38, 46, MinimapCluster, nil, "Frame")
badge:SetPoint("TOPLEFT", MinimapCluster, "TOPLEFT", 22, -17)
badge._shown = false

-- ------------------------------------------------------------------
-- DC-QOS
-- ------------------------------------------------------------------
_G.DCQOS = {
    settings = {
        minimap = { enabled = true, buttonGap = 4, hideWorldMapButton = true,
            hideZoom = true, hideTracking = true, hideCalendar = true },
        frameMover = { enabled = true, frames = {} },
    },
    modules = {},
    fired = {},
}
function DCQOS:RegisterModule(name, module) self.modules[name] = module end
function DCQOS:DelayedCall() end
function DCQOS:SaveSettings() end
function DCQOS:Debug() end
function DCQOS:RegisterEvent() end
function DCQOS:FireEvent(event) self.fired[event] = (self.fired[event] or 0) + 1 end

dofile(ROOT .. [[DC-QOS\Modules\Minimap.lua]])
local ring = DCQOS.modules.Minimap.ButtonRing

-- ------------------------------------------------------------------
-- Checks
-- ------------------------------------------------------------------
local GAP = 4
local ringFrames = { weakAuras, azerothAdmin, bugSack, welcome, eye, goMove, mail }

local function offsetOf(frame)
    local x, y = frame:GetCenter()
    local mx, my = Minimap:GetCenter()
    return x - mx, y - my
end

local function overlappingPairs(frames)
    local pairs_ = {}
    for i = 1, #frames do
        for j = i + 1, #frames do
            local a, b = frames[i], frames[j]
            if a:IsVisible() and b:IsVisible() and a:GetCenter() and b:GetCenter() then
                local ax, ay = a:GetCenter()
                local bx, by = b:GetCenter()
                local d = math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
                if d < 30 + GAP - 0.01 then
                    table.insert(pairs_, a:GetName() .. " x " .. b:GetName() .. string.format(" (%.1f)", d))
                end
            end
        end
    end
    return pairs_
end

local function circleHitsRect(frame, rectFrame)
    local x, y = frame:GetCenter()
    local cx = math.max(rectFrame:GetLeft(), math.min(x, rectFrame:GetRight()))
    local cy = math.max(rectFrame:GetBottom(), math.min(y, rectFrame:GetTop()))
    local r = 15 + GAP / 2
    return (x - cx) ^ 2 + (y - cy) ^ 2 < r * r
end

local function blockedReasons(frames)
    local out = {}
    for _, f in ipairs(frames) do
        if f:IsVisible() then
            local x, y = f:GetCenter()
            for _, name in ipairs({ "MinimapZoneTextButton", "TimeManagerClockButton", "DCInfoBarFrame" }) do
                if circleHitsRect(f, _G[name]) then
                    table.insert(out, f:GetName() .. " covers " .. name)
                end
            end
            if x + 15 > 1024 or x - 15 < 0 or y + 15 > 768 then
                table.insert(out, f:GetName() .. " leaves the screen")
            end
            if y - 15 < MinimapCluster:GetBottom() then
                table.insert(out, f:GetName() .. " hangs below the cluster")
            end
        end
    end
    return out
end

local function snapshot(frames)
    local s = {}
    for _, f in ipairs(frames) do
        if f:IsVisible() then
            local x, y = offsetOf(f)
            s[f:GetName()] = { x, y }
        end
    end
    return s
end

local function samePlace(a, b)
    return a and b and math.abs(a[1] - b[1]) < 0.01 and math.abs(a[2] - b[2]) < 0.01
end

print("MinimapButtons")

-- 1. Reproduce: the owners' own placement of those saved angles overlaps.
ok(#overlappingPairs({ weakAuras, azerothAdmin, bugSack, welcome, eye }) > 0,
    "saved angles overlap on the owners' own placement (the bug)")

-- 2. First layout clears every overlap and every reserved area.
ring:Activate()
ring:Layout()
local overlaps = overlappingPairs(ringFrames)
ok(#overlaps == 0, "no two buttons overlap after layout" .. (#overlaps > 0 and (": " .. table.concat(overlaps, ", ")) or ""))
local blocked = blockedReasons(ringFrames)
ok(#blocked == 0, "no button covers the zone text, clock, info bar, screen edge or tracker area"
    .. (#blocked > 0 and (": " .. table.concat(blocked, ", ")) or ""))
ok(goMove:GetNumPoints() == 1 and select(1, goMove:GetPoint(1)) == "CENTER", "GOMove's free-floating anchor is replaced by a ring anchor")
ok(DCMapupgradesEntityMinimapPin1:GetNumPoints() == 0, "map pins are never pulled onto the ring")
ok(ring.lastPlaced.MiniMapWorldMapButton == nil, "the faded-out world map button takes no ring spot")

-- 3. Every owner's saved angle reproduces the spot the ring picked, so the
--    owner re-placing its own button (LibDBIcon:Refresh, a queue update) is a
--    no-op. A button pushed onto an outer track sits at its saved angle there.
local function ownerAgrees(frame, angle)
    local x, y = offsetOf(frame)
    for track = 0, 3 do
        local ox, oy = ownerOffset(angle, 80 + 36 * track)
        if math.abs(x - ox) < 0.01 and math.abs(y - oy) < 0.01 then
            return true
        end
    end
    return false
end
ok(ownerAgrees(weakAuras, weakAuras.db.minimapPos), "WeakAuras' minimapPos matches its placement")
ok(ownerAgrees(azerothAdmin, azerothAdmin.db.minimapPos), "AzerothAdmin's minimapPos matches its placement")
ok(ownerAgrees(bugSack, bugSack.db.minimapPos), "BugSack's minimapPos matches its placement")
ok(ownerAgrees(welcome, DCWelcomeDB.minimapButton.angle), "DC-Welcome's saved angle matches its placement")
ok(ownerAgrees(eye, DCMythicPlusHUDDB.minimapQueue.angle), "queue eye's saved angle matches its placement")
ok(GOMoveSV.MinimapAngle == nil or ownerAgrees(goMove, GOMoveSV.MinimapAngle), "GOMove's saved angle matches its placement")

-- 4. Stable: a second pass (and an owner refresh) moves nothing and fires nothing.
local before = snapshot(ringFrames)
local firedBefore = DCQOS.fired.MINIMAP_BUTTONS_LAYOUT or 0
placeByOwner(bugSack, bugSack.db.minimapPos)
placeByOwner(eye, DCMythicPlusHUDDB.minimapQueue.angle)
ok(ring.dirty == true, "an owner's SetPoint marks the ring dirty")
ring:Layout()
local after = snapshot(ringFrames)
local stable = true
for name, pos in pairs(before) do
    if not samePlace(pos, after[name]) then stable = false end
end
ok(stable, "a settled layout does not move on the next pass")
ok((DCQOS.fired.MINIMAP_BUTTONS_LAYOUT or 0) == firedBefore, "no layout event when nothing moved")

-- 5. A newcomer yields: mail arrives on a spot that is taken.
DCQOS.settings.minimap.buttonAngles = { MiniMapMailFrame = DCWelcomeDB.minimapButton.angle }
before = snapshot(ringFrames)
mail:Show()
ok(ring.dirty == true, "mail showing up marks the ring dirty")
ring:Layout()
after = snapshot(ringFrames)
local othersKept = true
for name, pos in pairs(before) do
    if not samePlace(pos, after[name]) then othersKept = false end
end
ok(othersKept, "buttons already on screen keep their place when mail appears")
ok(#overlappingPairs(ringFrames) == 0, "mail is placed without overlapping")
ok((DCQOS.fired.MINIMAP_BUTTONS_LAYOUT or 0) > firedBefore, "layout event fires so the buffs re-measure")

-- 5b. The instance difficulty badge shows up inside a dungeon. The left edge is
--     full, so as a ring newcomer it used to land two tracks out, 80 units
--     left of the map. It hangs inside the map's top-left corner instead, and
--     on the square track nothing is in its way: no button moves or re-saves.
before = snapshot(ringFrames)
local savedBefore = { weakAuras.db.minimapPos, azerothAdmin.db.minimapPos, bugSack.db.minimapPos,
    DCWelcomeDB.minimapButton.angle, DCMythicPlusHUDDB.minimapQueue.angle }
badge:Show()
ok(ring.dirty == true, "the badge showing up marks the ring dirty")
ring:Layout()
after = snapshot(ringFrames)
othersKept = true
for name, pos in pairs(before) do
    if not samePlace(pos, after[name]) then othersKept = false end
end
ok(othersKept, "the difficulty badge does not displace a button")
ok(savedBefore[1] == weakAuras.db.minimapPos and savedBefore[2] == azerothAdmin.db.minimapPos
    and savedBefore[3] == bugSack.db.minimapPos and savedBefore[4] == DCWelcomeDB.minimapButton.angle
    and savedBefore[5] == DCMythicPlusHUDDB.minimapQueue.angle, "nobody's saved angle changes for the badge")
local mx0, my0 = Minimap:GetCenter()
local bl, br = badge:GetLeft() - mx0, badge:GetRight() - mx0
local bb, bt = badge:GetBottom() - my0, badge:GetTop() - my0
ok(bl >= -70 and bl <= -55 and bt >= 65 and bt <= 75 and br < 0 and bb > 0,
    string.format("the badge hangs inside the map's top-left corner (l %.0f r %.0f b %.0f t %.0f)", bl, br, bb, bt))
local badgeClear = true
for _, f in ipairs(ringFrames) do
    if f:IsVisible() and circleHitsRect(f, badge) then badgeClear = false end
end
ok(badgeClear, "the badge sits clear of every button")
ok(badge:GetScript("OnDragStart") == nil, "the badge is not draggable")
badge:Hide()
ring:Layout()

-- 6. A drop onto an occupied spot snaps to the nearest free one; neighbours stay.
before = snapshot(ringFrames)
local targetAngle = weakAuras.db.minimapPos
bugSack.isMoving = true
bugSack.db.minimapPos = targetAngle
placeByOwner(bugSack, targetAngle)
ok(ring:AnyDragging() == true, "the ring waits while a launcher is being dragged")
bugSack.isMoving = nil
ring:Layout()
after = snapshot(ringFrames)
local neighboursKept = true
for name, pos in pairs(before) do
    if name ~= bugSack:GetName() and not samePlace(pos, after[name]) then neighboursKept = false end
end
ok(neighboursKept, "dropping a button does not shove its neighbours")
ok(#overlappingPairs(ringFrames) == 0, "the dropped button lands on a free spot")
ok(ownerAgrees(bugSack, bugSack.db.minimapPos), "the snapped spot is saved back to the launcher")
local delta = math.abs(((bugSack.db.minimapPos - targetAngle) + 180) % 360 - 180)
ok(delta <= 90, string.format("the snap stays near where it was dropped (%.0f degrees away)", delta))

-- 7. A full ring spills onto the outer track instead of overlapping.
local crowd = {}
for i = 1, 10 do
    local extra = addLauncher("Crowd" .. i, 180)
    table.insert(crowd, extra)
end
ring:RequestRescan()
ring:Layout()
local everyone = {}
for _, f in ipairs(ringFrames) do table.insert(everyone, f) end
for _, f in ipairs(crowd) do table.insert(everyone, f) end
overlaps = overlappingPairs(everyone)
ok(#overlaps == 0, "17 buttons still do not overlap" .. (#overlaps > 0 and (": " .. table.concat(overlaps, ", ")) or ""))
blocked = blockedReasons(everyone)
ok(#blocked == 0, "overflow stays clear of reserved areas and on screen"
    .. (#blocked > 0 and (": " .. table.concat(blocked, ", ")) or ""))
local outer = 0
for _, f in ipairs(everyone) do
    local x, y = offsetOf(f)
    if math.max(math.abs(x), math.abs(y)) > 81 then outer = outer + 1 end
end
ok(outer > 0, "some buttons moved to the outer track")

-- 8. Round minimap, positions reset: all on circles, still no overlaps.
for _, f in ipairs(crowd) do f:Hide() end
shape = "ROUND"
ring:ResetPositions()
ring:Layout()
overlaps = overlappingPairs(ringFrames)
ok(#overlaps == 0, "round ring after reset has no overlaps" .. (#overlaps > 0 and (": " .. table.concat(overlaps, ", ")) or ""))
local onCircle = true
for _, f in ipairs(ringFrames) do
    if f:IsVisible() then
        local x, y = offsetOf(f)
        local r = math.sqrt(x * x + y * y)
        local track = (r - 80) / 36
        if math.abs(track - math.floor(track + 0.5)) > 0.001 then onCircle = false end
    end
end
ok(onCircle, "round layout puts every button on a circular track")
blocked = blockedReasons(ringFrames)
ok(#blocked == 0, "round layout avoids the zone text, clock and screen edge"
    .. (#blocked > 0 and (": " .. table.concat(blocked, ", ")) or ""))

-- 9. Dragging a stock button along the ring.
_G.GetCursorPosition = function()
    local mx, my = Minimap:GetCenter()
    return mx - 100, my + 10
end
local dragStart = mail:GetScript("OnDragStart")
ok(type(dragStart) == "function", "stock mail frame is draggable while the ring is active")
dragStart(mail)
ok(ring:AnyDragging(), "stock drag is tracked")
ring:FollowCursor()
local mx, my = offsetOf(mail)
ok(mx < -70 and math.abs(my) < 40, "mail follows the cursor to the left edge")
mail:GetScript("OnDragStop")(mail)
ring:Layout()
ok(#overlappingPairs(ringFrames) == 0, "stock drop snaps clear of the other buttons")
local saved = DCQOS.settings.minimap.buttonAngles.MiniMapMailFrame
ok(saved and ownerAgrees(mail, saved), "stock button angle is saved in minimap.buttonAngles")

-- 10. The round track crosses the badge's corner. A button standing there steps
--     aside while the badge shows, keeps its saved angle, and goes back when
--     the badge hides.
azerothAdmin.db.minimapPos = 140
placeByOwner(azerothAdmin, 140)
ring:Layout()
local home = { offsetOf(azerothAdmin) }
ok(azerothAdmin.db.minimapPos == 140 and ownerAgrees(azerothAdmin, 140), "AzerothAdmin sits at 140 degrees on the round ring")
ok(circleHitsRect(azerothAdmin, badge), "which is where the badge hangs")
before = snapshot(ringFrames)
firedBefore = DCQOS.fired.MINIMAP_BUTTONS_LAYOUT or 0
badge:Show()
ring:Layout()
after = snapshot(ringFrames)
ok(not circleHitsRect(azerothAdmin, badge), "AzerothAdmin steps aside for the badge")
ok(azerothAdmin.db.minimapPos == 140, "AzerothAdmin's saved angle is untouched while it stands aside")
ok(#overlappingPairs(ringFrames) == 0, "it stands aside on a free spot")
local othersStay = true
for name, pos in pairs(before) do
    if name ~= azerothAdmin:GetName() and not samePlace(pos, after[name]) then othersStay = false end
end
ok(othersStay, "no other button moves for the badge")
ok((DCQOS.fired.MINIMAP_BUTTONS_LAYOUT or 0) > firedBefore, "layout event fires when it steps aside")
local aside = { offsetOf(azerothAdmin) }
firedBefore = DCQOS.fired.MINIMAP_BUTTONS_LAYOUT or 0
ring:Layout()
ok(samePlace(aside, { offsetOf(azerothAdmin) }) and (DCQOS.fired.MINIMAP_BUTTONS_LAYOUT or 0) == firedBefore,
    "it stays aside on the next pass")
placeByOwner(azerothAdmin, 140)
ring:Layout()
ok(samePlace(aside, { offsetOf(azerothAdmin) }) and azerothAdmin.db.minimapPos == 140,
    "LibDBIcon putting it back on its saved angle does not win it the badge's spot")
badge:Hide()
ring:Layout()
ok(samePlace(home, { offsetOf(azerothAdmin) }), "AzerothAdmin goes back to its spot when the badge hides")
ok(azerothAdmin.db.minimapPos == 140 and ownerAgrees(azerothAdmin, 140), "and its saved angle still matches it")
ok(#overlappingPairs(ringFrames) == 0, "no overlaps once it is back")

-- 11. Turning the module off hands the stock buttons and the badge back.
ring:Deactivate()
local point, rel, relPoint, x, y = mail:GetPoint(1)
ok(point == "TOPRIGHT" and rel == Minimap and x == 21 and y == -53, "mail frame is back on its stock anchor")
ok(mail:GetScript("OnDragStart") == nil, "stock drag handlers are removed")
point, rel, relPoint, x, y = badge:GetPoint(1)
ok(badge:GetNumPoints() == 1 and point == "TOPLEFT" and rel == MinimapCluster and relPoint == "TOPLEFT"
    and x == 22 and y == -17, "the badge is back on its stock anchor")

print(string.format("RESULT: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
