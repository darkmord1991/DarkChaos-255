-- DC-Journal boss tracker (DC-Journal/Interface/FrameXML/DCBossTracker/DCBossTracker.lua)
-- against the stock quest tracker, WatchFrame.
--
-- The DENC block claims the top of the objective-tracker column and WatchFrame
-- hangs below it. A right-drag on the block's header used to save a position of
-- its own (DCBossTrackerDB.pos), which switched that claim off: WatchFrame snapped
-- back to its stock spot under the minimap - where the block still sat - and
-- "Raid (1/7)" was drawn across "Objectives (1)". Separately, the stock manager
-- sets WatchFrame's BOTTOMRIGHT stretch anchor AFTER the TOPRIGHT the tracker
-- answers, so the shifted copy was overwritten on every pass and WatchFrame was
-- left with two right edges 20px apart.
--
-- Laid out against a geometry model: a 1365x768 UIParent, MinimapCluster in the
-- top-right corner, WatchFrame as WatchFrame.xml declares it (306 wide, the wider
-- tracker option), both right-hand action bars shown, and the WatchFrame tail of
-- FramePositionDelegate:UIParentManageFramePositions copied verbatim from the
-- 3.3.5a (12340) UIParent.lua. Scenario A starts from the saved variables that
-- produced the report.
--
-- Pins: the block and the quest list never overlap - after login with that
-- stale position, after every manager pass, as the boss list grows, shrinks and
-- collapses, in Mythic+ mode, and while DC-QOS FrameMover moves the quest tracker
-- (the block stacks on top of it) or resets it (the block docks again); the stale
-- position is dropped; the header is not a drag handle; WatchFrame never has two
-- right edges; leaving the instance hands WatchFrame back to the stock spot; and
-- a mover re-applying an anchor on the block neither leaves the two anchored to
-- each other (block shown or hidden) nor strands the quest list under the
-- parked block when it lands at login.
--
-- Point DC_BOSSTRACKER_FILE at an older copy to reproduce the bug.
dofile("wowsim.lua")
local ROOT = os.getenv("DC_JOURNAL_ROOT") or [[K:\Dark-Chaos\DarkChaos-255-Master\Custom\Client addons needed\]]
local FILE = os.getenv("DC_BOSSTRACKER_FILE")
    or (ROOT .. [[DC-Journal\Interface\FrameXML\DCBossTracker\DCBossTracker.lua]])
local pass, fail = 0, 0
local function ok(c, m) if c then pass = pass + 1; print("  PASS " .. m) else fail = fail + 1; print("  FAIL " .. m) end end

-- ------------------------------------------------------------------
-- Geometry: anchors are recorded and a frame's rect is resolved from them the
-- way the client does. An edge that two anchors put in different places is
-- recorded as a conflict - what the client draws then is undefined.
-- ------------------------------------------------------------------
local Methods = getmetatable(CreateFrame("Frame")).__index
local SCREEN_W, SCREEN_H = 1365, 768
local ORDER = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
local FRAC = {
    TOPLEFT = { 0, 1 }, TOP = { 0.5, 1 }, TOPRIGHT = { 1, 1 },
    LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 }, RIGHT = { 1, 0.5 },
    BOTTOMLEFT = { 0, 0 }, BOTTOM = { 0.5, 0 }, BOTTOMRIGHT = { 1, 0 },
}

function Methods:SetPoint(point, rel, relPoint, x, y)
    if type(rel) == "number" then rel, relPoint, x, y = nil, nil, rel, relPoint end
    if type(rel) == "string" then rel = assert(_G[rel], "SetPoint relative to unknown frame " .. rel) end
    self._pts = self._pts or {}
    self._pts[point] = { rel = rel or self._parent, relPoint = relPoint or point, x = x or 0, y = y or 0 }
end
function Methods:ClearAllPoints() self._pts = {} end
function Methods:GetNumPoints()
    local n = 0
    for _ in pairs(self._pts or {}) do n = n + 1 end
    return n
end
function Methods:GetPoint(index)
    local n = 0
    for _, p in ipairs(ORDER) do
        local a = self._pts and self._pts[p]
        if a then
            n = n + 1
            if n == (index or 1) then return p, a.rel, a.relPoint, a.x, a.y end
        end
    end
end
function Methods:SetWidth(w) self._w = w end
function Methods:SetHeight(h) self._h = h end
function Methods:SetUserPlaced(v) self._userPlaced = v and true or false end
function Methods:IsUserPlaced() return self._userPlaced == true end
function Methods:RegisterForDrag(...) self._drag = { ... } end
function Methods:GetName() return self._name end

-- Two frames anchored to each other resolve to { loop = true } (no edges), so a
-- test on an older copy reports that instead of dying mid-run.
local function resolve(f, depth)
    if f._screen then return { l = 0, r = SCREEN_W, t = SCREEN_H, b = 0, conflicts = {} } end
    depth = (depth or 0) + 1
    if depth > 30 then return { loop = true, conflicts = {} } end
    local e, conflicts = {}, {}
    local function set(key, v, what)
        if e[key] == nil then
            e[key] = v
        elseif math.abs(e[key] - v) > 0.01 then
            conflicts[#conflicts + 1] = string.format("%s (%.0f vs %.0f)", what, e[key], v)
        end
    end
    for _, p in ipairs(ORDER) do
        local a = f._pts and f._pts[p]
        if a then
            local r = resolve(a.rel, depth)
            if r.loop then return r end
            local ax = r.l + (r.r - r.l) * FRAC[a.relPoint][1] + a.x
            local ay = r.b + (r.t - r.b) * FRAC[a.relPoint][2] + a.y
            local fx, fy = FRAC[p][1], FRAC[p][2]
            if fx == 0 then set("l", ax, "left") elseif fx == 1 then set("r", ax, "right") else set("cx", ax, "centre") end
            if fy == 1 then set("t", ay, "top") elseif fy == 0 then set("b", ay, "bottom") else set("cy", ay, "middle") end
        end
    end
    local w, h = f._w or 0, f._h or 0
    local l, r, t, b = e.l, e.r, e.t, e.b
    if not (l and r) then
        if l then r = l + w elseif r then l = r - w elseif e.cx then l, r = e.cx - w / 2, e.cx + w / 2 end
    end
    if not (t and b) then
        if t then b = t - h elseif b then t = b + h elseif e.cy then b, t = e.cy - h / 2, e.cy + h / 2 end
    end
    return { l = l, r = r, t = t, b = b, conflicts = conflicts }
end

function Methods:GetLeft() return resolve(self).l end
function Methods:GetRight() return resolve(self).r end
function Methods:GetTop() return resolve(self).t end
function Methods:GetBottom() return resolve(self).b end
function Methods:GetWidth()
    local r = resolve(self)
    return (r.l and r.r) and (r.r - r.l) or (self._w or 0)
end
function Methods:GetHeight()
    local r = resolve(self)
    return (r.t and r.b) and (r.t - r.b) or (self._h or 0)
end

_G.hooksecurefunc = function(tbl, name, hook)
    if type(tbl) == "string" then tbl, name, hook = _G, tbl, name end
    local orig = tbl[name]
    tbl[name] = function(...) orig(...); hook(...) end
end

local simCreateFrame = CreateFrame
local created = {}
_G.CreateFrame = function(ftype, name, parent, tmpl)
    local f = simCreateFrame(ftype, name, parent, tmpl)
    f._shown = true -- the client creates frames shown; wowsim starts them hidden
    f._name = name
    if name then _G[name] = f end
    created[#created + 1] = f
    return f
end

-- ------------------------------------------------------------------
-- Stock client: FrameXML/UIParent.lua (3.3.5a 12340), the WatchFrame tail of
-- FramePositionDelegate:UIParentManageFramePositions, verbatim. anchorY stays 0
-- with no capture bar, vehicle seat, boss frames or durability frame above.
-- ------------------------------------------------------------------
CONTAINER_OFFSET_X = 93 -- 2*actionBarOffset+3: both right-hand bars shown
CONTAINER_OFFSET_Y = 85
function GetNumArenaOpponents() return 0 end

function UIParent_ManageFramePositions()
    local anchorY = 0;
    local numArenaOpponents = GetNumArenaOpponents();
    if ( not WatchFrame:IsUserPlaced() and ArenaEnemyFrames and ArenaEnemyFrames:IsShown() and (numArenaOpponents > 0) ) then
        WatchFrame:ClearAllPoints();
        WatchFrame:SetPoint("TOPRIGHT", "ArenaEnemyFrame"..numArenaOpponents, "BOTTOMRIGHT", 2, -35);
    elseif ( not WatchFrame:IsUserPlaced() ) then -- We're using Simple Quest Tracking, automagically size and position!
        WatchFrame:ClearAllPoints();
        -- move up if only the minimap cluster is above, move down a little otherwise
        if ( anchorY == 0 ) then
            anchorY = 20;
        end
        WatchFrame:SetPoint("TOPRIGHT", "MinimapCluster", "BOTTOMRIGHT", -CONTAINER_OFFSET_X, anchorY);
        -- OnSizeChanged for WatchFrame handles its redraw
    end

    WatchFrame:SetPoint("BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", -CONTAINER_OFFSET_X, CONTAINER_OFFSET_Y);
end

-- Where the manager puts WatchFrame's top-right corner, and so where the docked
-- block's top edge belongs (its right edge sits COLUMN_OFFSET_X further left).
local STOCK_TOP = SCREEN_H - 192 + 20
local STOCK_RIGHT = SCREEN_W - CONTAINER_OFFSET_X

-- DC-QOS FrameMover (Modules/FrameMover.lua) as it treats WatchFrame:
-- ApplyFramePosition with lockPoints on (its default) and "Reset Position".
local fm = {}
local function frameMoverApply(pos)
    local frame = WatchFrame
    fm.saved = pos
    if not frame._dcqosPointHooked then
        frame._dcqosPointHooked = true
        hooksecurefunc(frame, "SetPoint", function(self)
            if self._dcqosLockPoint and not self._dcqosRepositioning and fm.saved then
                self._dcqosRepositioning = true
                frameMoverApply(fm.saved)
                self._dcqosRepositioning = false
            end
        end)
    end
    frame:SetUserPlaced(true)
    frame._dcqosLockPoint = true
    frame._dcqosRepositioning = true
    frame:ClearAllPoints()
    frame:SetPoint(pos.point, _G[pos.relativeTo] or UIParent, pos.relativePoint, pos.x, pos.y)
    frame._dcqosRepositioning = false
end
local function frameMoverReset(origPos)
    frameMoverApply(origPos)
    fm.saved = nil                  -- settings.frames[name] = nil
    WatchFrame:SetUserPlaced(false) -- RestoreFrameState: the original userPlaced
    WatchFrame._dcqosLockPoint = nil
end

-- DC-AddonProtocol: handlers are all the tracker needs from it.
local handlers = {}
local function push(opcode, data) handlers[opcode](data) end

local TIMBERMAW = {
    m = 819, d = 0, r = 1, p = 20, n = "Timbermaw Hold",
    b = {
        { e = 1218, t = "Gatewarden Mor'thak", k = 0 },
        { e = 1219, t = "The Sundered Chieftain", k = 1 },
        { e = 1220, t = "Den Mother Ursara", k = 0 },
        { e = 1221, t = "Xanthir the Defiler", k = 0 },
        { e = 1222, t = "The Nightmare Given Root", k = 0 },
        { e = 1223, t = "Ursol", k = 0 },
        { e = 1224, t = "Ursoc", k = 0 },
    },
}
local UTGARDE = {
    m = 574, d = 1, r = 0, p = 5, n = "Utgarde Keep",
    b = {
        { e = 575, t = "Prince Keleseth", k = 1 },
        { e = 576, t = "Skarvald the Constructor", k = 0 },
        { e = 577, t = "Ingvar the Plunderer", k = 0 },
    },
}

-- Fresh client: stock frames, one stock manager pass (it runs during login),
-- the addon file, then the events it waits for.
local function boot(savedVars)
    created = {}
    fm.saved = nil
    UIParent = CreateFrame("Frame", "UIParent")
    UIParent._screen = true
    MinimapCluster = CreateFrame("Frame", "MinimapCluster", UIParent)
    MinimapCluster:SetWidth(192)
    MinimapCluster:SetHeight(192)
    MinimapCluster:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0)
    WatchFrame = CreateFrame("Frame", "WatchFrame", UIParent)
    WatchFrame:SetWidth(306)
    WatchFrame:SetHeight(140)
    WatchFrame:SetPoint("TOPRIGHT", MinimapCluster, "BOTTOMRIGHT", 0, 0)
    UIParent_ManageFramePositions()

    DCBossTrackerDB = savedVars
    SlashCmdList = {}
    DCAddonProtocol = {
        RegisterHandler = function(_, module, opcode, fn) if module == "DENC" then handlers[opcode] = fn end end,
        Send = function() end,
    }

    local first = #created + 1
    dofile(FILE)
    for i = first, #created do
        local f = created[i]
        if f._scripts.OnEvent then
            f._scripts.OnEvent(f, "ADDON_LOADED", "DC-Journal")
            f._scripts.OnEvent(f, "PLAYER_ENTERING_WORLD")
        end
    end
    return DCBossTracker
end

local function rightAnchorOf(f)
    for i = 1, f:GetNumPoints() do
        local p, rel, relPoint, x, y = f:GetPoint(i)
        if p == "TOPRIGHT" then return rel, relPoint, x, y end
    end
end

local function overlaps(a, b)
    return a.l < b.r - 0.01 and b.l < a.r - 0.01 and a.b < b.t - 0.01 and b.b < a.t - 0.01
end

local function near(a, b) return a and b and math.abs(a - b) < 0.01 end

-- The block and the quest list share the screen without painting over each other.
local function clearOk(T, label)
    local block, watch = resolve(T.frame), resolve(WatchFrame)
    ok(T.frame:IsShown(), label .. ": block shown")
    if block.loop or watch.loop then
        ok(false, label .. ": block and quest tracker are anchored to each other")
        return false
    end
    ok(not overlaps(block, watch), string.format(
        "%s: block (top %.0f, bottom %.0f, right %.0f) clear of the quest tracker (top %.0f, right %.0f)",
        label, block.t, block.b, block.r, watch.t, watch.r))
    ok(#watch.conflicts == 0, label .. ": WatchFrame has one right edge"
        .. (#watch.conflicts > 0 and ("  <-- conflicting " .. table.concat(watch.conflicts, ", ")) or ""))
    return true
end

-- Docked: the block holds the manager's spot and WatchFrame hangs 6 below it.
local function dockedOk(T, label)
    if not clearOk(T, label) then return end
    local block, watch = resolve(T.frame), resolve(WatchFrame)
    ok(rightAnchorOf(WatchFrame) == T.frame and near(watch.t, block.b - 6) and near(watch.r, block.r),
        label .. ": quest list hangs right under the block, right edges aligned")
    ok(near(block.t, STOCK_TOP) and near(block.r, STOCK_RIGHT + T.COLUMN_OFFSET_X),
        string.format("%s: block holds the column top (top %.0f, right %.0f)", label, block.t, block.r))
end

-- Stacked: WatchFrame belongs to a mover, the block sits 6 above it.
local function stackedOk(T, label)
    if not clearOk(T, label) then return end
    local block, watch = resolve(T.frame), resolve(WatchFrame)
    ok(near(block.b, watch.t + 6) and near(block.r, watch.r),
        label .. ": block sits on top of the moved quest tracker, right edges aligned")
end

print("== Scenario A: login with the saved variables that produced the report ==")
local T = boot({
    collapsed = false,
    pos = { y = 112.6774418057076, relPoint = "RIGHT", point = "RIGHT", x = -117.8141397593084 },
})
push(0x10, TIMBERMAW)
dockedOk(T, "Timbermaw Hold, 7 bosses")
ok(DCBossTrackerDB.pos == nil, "the stale drag position is dropped from DCBossTrackerDB")

print("== Scenario B: the header no longer detaches the block ==")
ok(T.frame.header._drag == nil and T.frame.header._scripts.OnDragStart == nil,
    "the header is not a drag handle (a camera right-drag cannot move it)")

print("== Scenario C: fresh login, stock manager passes ==")
T = boot({})
push(0x10, TIMBERMAW)
dockedOk(T, "after the list arrives")
for _ = 1, 3 do UIParent_ManageFramePositions() end
dockedOk(T, "after three more manager passes")

print("== Scenario D: the list changes size ==")
push(0x10, UTGARDE)
dockedOk(T, "3-boss dungeon")
push(0x11, { m = 574, d = 1, e = 576, k = 1 })
dockedOk(T, "after a kill")
T.ToggleCollapsed()
dockedOk(T, "collapsed")
T.ToggleCollapsed()
push(0x10, TIMBERMAW)
dockedOk(T, "back to 7 bosses")
for _, f in ipairs(created) do
    if f._scripts.OnEvent then f._scripts.OnEvent(f, "PLAYER_ENTERING_WORLD") end
end
UIParent_ManageFramePositions()
dockedOk(T, "zoning again (PLAYER_ENTERING_WORLD without a reload)")

print("== Scenario E: Mythic+ mode ==")
T.SetMythicPlus({
    mapName = "Utgarde Keep", keystone = 12, duration = 1800, remaining = 1500, deaths = 2,
    affixes = { { name = "Tyrannical" }, { name = "Bolstering" } }, enemiesKilled = 40,
    bosses = {
        { name = "Prince Keleseth", killed = 1, at = 300 },
        { name = "Skarvald the Constructor", killed = 0 },
        { name = "Ingvar the Plunderer", killed = 0 },
    },
})
dockedOk(T, "challenge-mode block")
T.ClearMythicPlus()
dockedOk(T, "back to the dungeon list")

print("== Scenario F: DC-QOS FrameMover moves the quest tracker, then resets it ==")
local origPos = { point = "TOPRIGHT", relativeTo = "MinimapCluster", relativePoint = "BOTTOMRIGHT",
    x = -CONTAINER_OFFSET_X, y = 20 } -- what FrameMover captured at login, before the block docked
frameMoverApply({ point = "TOPRIGHT", relativeTo = "UIParent", relativePoint = "TOPRIGHT", x = -60, y = -300 })
stackedOk(T, "quest tracker nudged down-right")
UIParent_ManageFramePositions()
stackedOk(T, "after a manager pass (it only re-sets the stretch anchor now)")
push(0x10, UTGARDE)
stackedOk(T, "list shrinks while stacked")
frameMoverReset(origPos)
dockedOk(T, "FrameMover Reset Position")

print("== Scenario G: leaving the instance ==")
push(0x12, {})
ok(not T.frame:IsShown(), "block hidden")
local rel, relPoint, x, y = rightAnchorOf(WatchFrame)
local watch = resolve(WatchFrame)
ok(rel == MinimapCluster and relPoint == "BOTTOMRIGHT" and x == -CONTAINER_OFFSET_X and y == 20
    and near(watch.r, STOCK_RIGHT) and near(watch.t, STOCK_TOP) and #watch.conflicts == 0,
    "WatchFrame is back on the stock spot with one right edge")

-- FrameMover saves a frame's FIRST anchor (mouse-wheel scaling, its Scale menu);
-- captured while docked, WatchFrame's first anchor is the block.
local ON_BLOCK = { point = "TOPRIGHT", relativeTo = "DCBossTrackerFrame", relativePoint = "BOTTOMRIGHT", x = 0, y = -6 }
local LEFT_SIDE = { point = "TOPLEFT", relativeTo = "UIParent", relativePoint = "TOPLEFT", x = 40, y = -250 }
local function applyOnBlock(T, label)
    local applied = pcall(frameMoverApply, ON_BLOCK)
    local _, blockRel = T.frame:GetPoint(1)
    ok(applied and blockRel ~= WatchFrame and not resolve(WatchFrame).loop,
        label .. ": block and quest tracker are not anchored to each other")
end

print("== Scenario H: a mover's anchor on the block is re-applied while the block sits on WatchFrame ==")
T = boot({})
push(0x10, TIMBERMAW)
frameMoverApply(LEFT_SIDE)
stackedOk(T, "quest tracker moved to the left side")
applyOnBlock(T, "block shown")
dockedOk(T, "after the re-apply")
frameMoverApply(LEFT_SIDE)
push(0x12, {})
applyOnBlock(T, "block hidden (instance left while stacked)")

print("== Scenario I: a mover's anchor on the block is applied at login, before the list arrives ==")
T = boot({})
applyOnBlock(T, "block still parked")
push(0x10, TIMBERMAW)
dockedOk(T, "list arrives")
UIParent_ManageFramePositions()
dockedOk(T, "after a manager pass")

print(string.format("\nRESULT: %d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
