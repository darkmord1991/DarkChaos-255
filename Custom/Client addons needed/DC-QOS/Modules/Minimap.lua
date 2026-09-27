-- ============================================================
-- DC-QoS: Minimap Module
-- ============================================================

local addon = DCQOS

local MinimapModule = {
    displayName = "Minimap",
    settingKey = "minimap",
    icon = "Interface\\Icons\\INV_Misc_Map_01",
}

local runtimeState = {
    captured = false,
}

-- Forward declaration: the capture/restore helpers below hand the button ring
-- over to (and back from) stock, and the ring is defined further down.
local ButtonRing

local function RefreshLibDBIcons()
    if not LibStub then
        return
    end
    local iconLib = LibStub("LibDBIcon-1.0", true)
    if not iconLib or not iconLib.Refresh or not iconLib.objects then
        return
    end
    -- Refresh(name) without a db shows the button unconditionally, which brought
    -- back every launcher the player had hidden. Hand each button its own db so
    -- a hidden one stays hidden.
    for name, button in pairs(iconLib.objects) do
        iconLib:Refresh(name, button.db)
    end
end

local function CapturePoints(frame)
    if not frame or type(frame.GetNumPoints) ~= "function" then
        return nil
    end

    local points = {}
    local count = frame:GetNumPoints() or 0
    for i = 1, count do
        local point, relativeTo, relativePoint, x, y = frame:GetPoint(i)
        points[i] = {
            point = point,
            relativeTo = relativeTo,
            relativePoint = relativePoint,
            x = x or 0,
            y = y or 0,
        }
    end

    return points
end

local function RestorePoints(frame, points)
    if not frame then
        return
    end

    if type(frame.ClearAllPoints) == "function" then
        frame:ClearAllPoints()
    end

    if not points or #points == 0 or type(frame.SetPoint) ~= "function" then
        return
    end

    for i = 1, #points do
        local p = points[i]
        frame:SetPoint(p.point, p.relativeTo, p.relativePoint, p.x or 0, p.y or 0)
    end
end

local function CaptureShown(frame)
    if frame and type(frame.IsShown) == "function" then
        return frame:IsShown()
    end
    return nil
end

local function CaptureAlpha(frame)
    if frame and type(frame.GetAlpha) == "function" then
        return frame:GetAlpha()
    end
    return nil
end

local function RestoreShown(frame, shown)
    if not frame or shown == nil then
        return
    end
    if shown then
        frame:Show()
    else
        frame:Hide()
    end
end

local function RestoreAlpha(frame, alpha)
    if frame and alpha ~= nil then
        frame:SetAlpha(alpha)
    end
end

local function CaptureOriginalState()
    if runtimeState.captured then
        return
    end

    runtimeState.captured = true
    runtimeState.originalGetMinimapShape = _G.GetMinimapShape

    if type(GetCVar) == "function" then
        runtimeState.originalRotateMinimap = GetCVar("rotateMinimap")
    end

    if Minimap then
        if type(Minimap.GetMaskTexture) == "function" then
            runtimeState.originalMaskTexture = Minimap:GetMaskTexture()
        end
        if type(Minimap.IsMouseWheelEnabled) == "function" then
            runtimeState.originalMouseWheelEnabled = Minimap:IsMouseWheelEnabled()
        end
        if type(Minimap.GetScript) == "function" then
            runtimeState.originalOnMouseWheel = Minimap:GetScript("OnMouseWheel")
        end
    end

    if MinimapCluster then
        runtimeState.originalClusterPoints = CapturePoints(MinimapCluster)
        if type(MinimapCluster.GetScale) == "function" then
            runtimeState.originalClusterScale = MinimapCluster:GetScale()
        end
    end

    runtimeState.originalTrackingShown = CaptureShown(MiniMapTracking)
    runtimeState.originalZoomInShown = CaptureShown(MinimapZoomIn)
    runtimeState.originalZoomOutShown = CaptureShown(MinimapZoomOut)
    runtimeState.originalClockShown = CaptureShown(TimeManagerClockButton)
    runtimeState.originalCalendarShown = CaptureShown(GameTimeFrame)
    runtimeState.originalWorldMapShown = CaptureShown(MiniMapWorldMapButton)
    runtimeState.originalWorldMapAlpha = CaptureAlpha(MiniMapWorldMapButton)
    if MiniMapWorldMapButton
        and type(MiniMapWorldMapButton.IsMouseEnabled) == "function" then
        runtimeState.originalWorldMapMouseEnabled = MiniMapWorldMapButton:IsMouseEnabled()
    end
    runtimeState.originalMinimapBorderShown = CaptureShown(MinimapBorder)
    runtimeState.originalMinimapBorderTopShown = CaptureShown(MinimapBorderTop)
    runtimeState.originalMinimapBackdropShown = CaptureShown(MinimapBackdrop)
    runtimeState.originalNorthTagAlpha = CaptureAlpha(MinimapNorthTag)
    runtimeState.originalCompassAlpha = CaptureAlpha(MinimapCompassTexture)
end

local function RestoreOriginalState()
    if not runtimeState.captured then
        return
    end

    ButtonRing:Deactivate()

    if Minimap then
        local maskTexture = runtimeState.originalMaskTexture
            or "Textures\\MinimapMask"
        Minimap:SetMaskTexture(maskTexture)

        if runtimeState.originalMouseWheelEnabled ~= nil
            and type(Minimap.EnableMouseWheel) == "function" then
            Minimap:EnableMouseWheel(runtimeState.originalMouseWheelEnabled)
        end

        if type(Minimap.SetScript) == "function" then
            Minimap:SetScript("OnMouseWheel", runtimeState.originalOnMouseWheel)
        end
    end

    if MinimapCluster then
        RestorePoints(MinimapCluster, runtimeState.originalClusterPoints)
        if runtimeState.originalClusterScale
            and type(MinimapCluster.SetScale) == "function" then
            MinimapCluster:SetScale(runtimeState.originalClusterScale)
        end
    end

    RestoreShown(MiniMapTracking, runtimeState.originalTrackingShown)
    RestoreShown(MinimapZoomIn, runtimeState.originalZoomInShown)
    RestoreShown(MinimapZoomOut, runtimeState.originalZoomOutShown)
    RestoreShown(TimeManagerClockButton, runtimeState.originalClockShown)
    RestoreShown(GameTimeFrame, runtimeState.originalCalendarShown)

    if MiniMapWorldMapButton then
        if runtimeState.originalWorldMapMouseEnabled ~= nil
            and type(MiniMapWorldMapButton.EnableMouse) == "function" then
            MiniMapWorldMapButton:EnableMouse(
                runtimeState.originalWorldMapMouseEnabled)
        end
        RestoreAlpha(MiniMapWorldMapButton, runtimeState.originalWorldMapAlpha)
        RestoreShown(MiniMapWorldMapButton, runtimeState.originalWorldMapShown)
    end

    RestoreShown(MinimapBorder, runtimeState.originalMinimapBorderShown)
    RestoreShown(MinimapBorderTop, runtimeState.originalMinimapBorderTopShown)
    RestoreShown(MinimapBackdrop, runtimeState.originalMinimapBackdropShown)
    RestoreAlpha(MinimapNorthTag, runtimeState.originalNorthTagAlpha)
    RestoreAlpha(MinimapCompassTexture, runtimeState.originalCompassAlpha)

    if Minimap.DCQOSFrame then
        Minimap.DCQOSFrame:Hide()
    end

    _G.GetMinimapShape = runtimeState.originalGetMinimapShape

    if runtimeState.originalRotateMinimap ~= nil
        and type(SetCVar) == "function" then
        pcall(SetCVar, "rotateMinimap", runtimeState.originalRotateMinimap)
    end

    RefreshLibDBIcons()
    ButtonRing:ReturnButtonsToOwners()

    for key in pairs(runtimeState) do
        runtimeState[key] = nil
    end
    runtimeState.captured = false
end

local function EnsureDcMinimapFrame()
    if Minimap.DCQOSFrame then
        return Minimap.DCQOSFrame
    end

    local parent = MinimapCluster or (Minimap and Minimap:GetParent()) or UIParent
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -5, 5)
    f:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", 5, -5)
    f:SetFrameStrata(Minimap:GetFrameStrata() or "MEDIUM")
    local mmLevel = Minimap:GetFrameLevel() or 1
    f:SetFrameLevel(math.max(0, mmLevel - 1))

    f:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    -- Fill the square area behind the round minimap (corners) with black.
    f:SetBackdropColor(0, 0, 0, 0.85)
    f:SetBackdropBorderColor(1, 1, 1, 1)

    Minimap.DCQOSFrame = f
    return f
end

-- ============================================================
-- Cluster placement
-- ============================================================

-- Same inset Modules/Interface.lua hangs the buff frames off, so the minimap
-- and the auras beside it stay level under DC-InfoBar.
local function GetTopBarInset()
    if type(addon.GetTopBarInset) == "function" then
        return addon.GetTopBarInset()
    end
    return -22
end

-- FrameMover can take the cluster over; once the player has placed it there,
-- re-anchoring it here on every login would undo that.
local function FrameMoverOwnsCluster()
    local mover = addon.settings.frameMover
    return type(mover) == "table" and mover.enabled
        and type(mover.frames) == "table" and mover.frames.MinimapCluster ~= nil
end

local function ApplyClusterPlacement()
    local s = addon.settings.minimap
    if not s.enabled or not MinimapCluster or not Minimap then
        return
    end

    local size = s.size or 160
    local baseSize = Minimap:GetWidth() or 140
    if baseSize <= 0 then
        baseSize = 140
    end
    local scale = size / baseSize
    if not scale or scale ~= scale or scale <= 0 then
        scale = 1
    end

    if not FrameMoverOwnsCluster() then
        MinimapCluster:ClearAllPoints()
        if s.useBlizzardPosition ~= false then
            -- Nudge closer to the screen edge when using legacy/default offsets.
            local posX = s.x
            if posX == nil or posX == -20 or posX == -4 then
                posX = -2
            end

            -- The cluster's top edge sits directly on DC-InfoBar's bottom edge
            -- (its border art is opaque from the first pixel row, so any
            -- smaller offset slides it under the bar). SetPoint offsets are in
            -- the cluster's own scaled units, hence the division.
            local posY = GetTopBarInset() / scale

            MinimapCluster:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", posX, posY)
        else
            MinimapCluster:SetPoint(s.point or "TOPRIGHT", UIParent, s.relPoint or "TOPRIGHT", s.x or -20, s.y or -20)
        end
    end
    MinimapCluster:SetScale(scale)
end

local clusterPlacementPending = false

local function RequestClusterPlacement()
    if not runtimeState.captured or clusterPlacementPending then
        return
    end
    clusterPlacementPending = true
    addon:DelayedCall(0, function()
        clusterPlacementPending = false
        if runtimeState.captured then
            ApplyClusterPlacement()
            ButtonRing:MarkDirty()
        end
    end)
end

-- DC-InfoBar can be resized, hidden, or docked to the bottom at runtime.
local function HookInfoBar()
    local bar = _G.DCInfoBarFrame
    if not bar or bar._dcqosMinimapHooked then
        return
    end
    bar._dcqosMinimapHooked = true

    bar:HookScript("OnShow", RequestClusterPlacement)
    bar:HookScript("OnHide", RequestClusterPlacement)
    bar:HookScript("OnSizeChanged", RequestClusterPlacement)
    hooksecurefunc(bar, "SetPoint", RequestClusterPlacement)
end

-- ============================================================
-- Button ring
-- ============================================================
-- Every button on the minimap edge rides one shared track and can be dragged
-- along it: the stock status buttons (mail, battleground and LFG queues,
-- tracking, world map, calendar, zoom), LibDBIcon launchers (BugSack,
-- WeakAuras, AzerothAdmin) and the DC addons' own buttons (DC-Welcome, the
-- Group Finder queue eye, GOMove).
--
-- Each owner keeps its own saved angle; the ring only resolves collisions. A
-- button whose spot is taken -- by another button, the zone text, the clock,
-- DC-InfoBar, the screen edge or the quest tracker below the cluster -- slides
-- to the nearest free spot, and that spot is written back to the owner so the
-- layout survives a reload. Buttons already on screen keep their place: the
-- newcomer (a mail icon that just appeared, or the button the player just
-- dropped) is the one that moves.
--
-- The instance difficulty badge is the exception. It hangs on the map itself,
-- and a button in its way steps aside only while it is shown, keeping its
-- saved angle (see DockBadge).
--
-- The track is LibDBIcon's: radius 80 from the map centre, pulled onto a
-- bevelled square when GetMinimapShape() is SQUARE. DC-Welcome, the queue eye
-- and GOMove use the same math, so an owner repositioning its own button
-- (LibDBIcon:Refresh, a queue update) lands it exactly where the ring put it.

local RING_RADIUS = 80
-- Outer tracks, used only when every spot further in is taken. With the map in
-- the top-right corner the first track has room for about seven buttons: the
-- screen edge, the zone text and the clock block the rest of it.
local RING_TRACK_STEP = 36
local RING_TRACKS = 4
local RING_SEARCH_STEP = 2
-- MiniMap-TrackingBorder's visible ring measures ~30px on every 31-33px button.
local RING_BUTTON_DIAMETER = 30
local RING_DEFAULT_GAP = 4
local RING_MOVE_TOLERANCE = 1
local RING_SCAN_INTERVAL = 1
local RING_FULL_SCAN_INTERVAL = 5

-- LibDBIcon-1.0 r21's table: which quadrants of the track stay round for each
-- GetMinimapShape() value (1 = bottom-right, 2 = bottom-left, 3 = top-right,
-- 4 = top-left).
local MINIMAP_SHAPES = {
    ["ROUND"] = { true, true, true, true },
    ["SQUARE"] = { false, false, false, false },
    ["CORNER-TOPLEFT"] = { true, false, false, false },
    ["CORNER-TOPRIGHT"] = { false, false, true, false },
    ["CORNER-BOTTOMLEFT"] = { false, true, false, false },
    ["CORNER-BOTTOMRIGHT"] = { false, false, false, true },
    ["SIDE-LEFT"] = { true, true, false, false },
    ["SIDE-RIGHT"] = { false, false, true, true },
    ["SIDE-TOP"] = { true, false, true, false },
    ["SIDE-BOTTOM"] = { false, true, false, true },
    ["TRICORNER-TOPLEFT"] = { true, true, true, false },
    ["TRICORNER-TOPRIGHT"] = { true, false, true, true },
    ["TRICORNER-BOTTOMLEFT"] = { true, true, false, true },
    ["TRICORNER-BOTTOMRIGHT"] = { false, true, true, true },
}

-- Stock 3.3.5 buttons the ring owns outright; their angles are saved in
-- minimap.buttonAngles. The zoom buttons, tracking, world map button and LFG
-- eye are children of MinimapBackdrop, which is why the DC frame keeps that
-- frame shown and only fades its ring art.
local STOCK_RING_BUTTONS = {
    { name = "MiniMapMailFrame", angle = 330 },
    { name = "MiniMapBattlefieldFrame", angle = 240 },
    { name = "MiniMapLFGFrame", angle = 225 },
    { name = "MiniMapVoiceChatFrame", angle = 200 },
    { name = "MiniMapTracking", angle = 170, handle = "MiniMapTrackingButton", hiddenBy = "hideTracking" },
    { name = "MiniMapWorldMapButton", angle = 150, hiddenBy = "hideWorldMapButton" },
    { name = "GameTimeFrame", angle = 20, hiddenBy = "hideCalendar", diameter = 34 },
    { name = "MinimapZoomIn", angle = 310, hiddenBy = "hideZoom" },
    { name = "MinimapZoomOut", angle = 290, hiddenBy = "hideZoom" },
}

-- DC buttons that save their own angle and position themselves on the same
-- track when DC-QOS is not running.
local ADDON_RING_BUTTONS = {
    {
        name = "DCWelcomeMinimapButton",
        angle = 225,
        get = function()
            local db = _G.DCWelcomeDB
            return type(db) == "table" and type(db.minimapButton) == "table"
                and db.minimapButton.angle or nil
        end,
        set = function(angle)
            if type(_G.DCWelcomeDB) ~= "table" then
                return
            end
            DCWelcomeDB.minimapButton = DCWelcomeDB.minimapButton or {}
            DCWelcomeDB.minimapButton.angle = angle
        end,
        restore = function()
            if _G.DCWelcome and type(DCWelcome.UpdateMinimapButtonPosition) == "function" then
                DCWelcome:UpdateMinimapButtonPosition()
            end
        end,
    },
    {
        name = "DCMatchmakingQueueEye",
        angle = 218,
        get = function()
            local db = _G.DCMythicPlusHUDDB
            return type(db) == "table" and type(db.minimapQueue) == "table"
                and db.minimapQueue.angle or nil
        end,
        set = function(angle)
            local db = _G.DCMythicPlusHUDDB
            if type(db) == "table" and type(db.minimapQueue) == "table" then
                db.minimapQueue.angle = angle
            end
        end,
        restore = function()
            local hud = _G.DCMythicPlusHUD
            local finder = hud and hud.GroupFinder
            if finder and type(finder.PositionMinimapQueueEye) == "function" then
                finder:PositionMinimapQueueEye()
            end
        end,
    },
    {
        name = "GOMove_UI_MapButton",
        angle = 190,
        get = function()
            return type(_G.GOMoveSV) == "table" and tonumber(GOMoveSV.MinimapAngle) or nil
        end,
        set = function(angle)
            if type(_G.GOMoveSV) == "table" then
                GOMoveSV.MinimapAngle = angle
            end
        end,
        restore = function()
            if _G.GOMove and type(GOMove.UpdateMapButtonPosition) == "function" then
                GOMove:UpdateMapButtonPosition()
            end
        end,
    },
}

-- Frames the ring routes around instead of moving.
local RING_RESERVED_FRAMES = {
    "MinimapZoneTextButton",
    "TimeManagerClockButton",
    "DCInfoBarFrame",
}

-- The dungeon/raid difficulty banner. Its top-left corner is pinned this far
-- from the map's top-left corner. 2 up puts the banner's hanging bar on the DC
-- frame's top border. 9 in keeps it clear of the buttons on the left edge of
-- the square track: centred 80 out, radius up to 17 (the calendar), plus half
-- the default gap.
local DIFFICULTY_BADGE = "MiniMapInstanceDifficulty"
local BADGE_DOCK_X = 9
local BADGE_DOCK_Y = 2

local KNOWN_RING_FRAMES = {}
for _, def in ipairs(STOCK_RING_BUTTONS) do
    KNOWN_RING_FRAMES[def.name] = true
    if def.handle then
        KNOWN_RING_FRAMES[def.handle] = true
    end
end
for _, def in ipairs(ADDON_RING_BUTTONS) do
    KNOWN_RING_FRAMES[def.name] = true
end

ButtonRing = {
    active = false,
    applying = false,
    dirty = false,
    rescanPending = false,
    items = {},
    order = {},
    lastPlaced = {},
    dragItem = nil,
}
MinimapModule.ButtonRing = ButtonRing

local function RingSettings()
    return addon.settings.minimap
end

local function StockAngleStore()
    local s = RingSettings()
    if type(s.buttonAngles) ~= "table" then
        s.buttonAngles = {}
    end
    return s.buttonAngles
end

local function RingGap()
    local gap = tonumber(RingSettings().buttonGap)
    if not gap or gap < 0 then
        return RING_DEFAULT_GAP
    end
    return gap
end

local function NormalizeAngle(angle)
    return (tonumber(angle) or 0) % 360
end

local function AngleDelta(a, b)
    local delta = (a - b) % 360
    if delta > 180 then
        delta = delta - 360
    end
    return delta
end

local function ShapeQuadrants()
    local shape = type(GetMinimapShape) == "function" and GetMinimapShape() or "ROUND"
    return MINIMAP_SHAPES[shape] or MINIMAP_SHAPES.ROUND
end

local function RingOffset(angle, track, quadrants)
    local radius = RING_RADIUS + (track or 0) * RING_TRACK_STEP
    local rad = math.rad(angle)
    local x, y = math.cos(rad), math.sin(rad)
    local q = 1
    if x < 0 then
        q = q + 1
    end
    if y > 0 then
        q = q + 2
    end
    if (quadrants or ShapeQuadrants())[q] then
        return x * radius, y * radius
    end
    local diagRadius = math.sqrt(2 * radius * radius) - 10
    return math.max(-radius, math.min(x * diagRadius, radius)),
        math.max(-radius, math.min(y * diagRadius, radius))
end
ButtonRing.Offset = RingOffset

local function PlaceOnMinimap(frame, x, y)
    ButtonRing.applying = true
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", Minimap, "CENTER", x, y)
    ButtonRing.applying = false
end

-- Offset of a frame's centre from the minimap centre, in minimap units.
local function CurrentOffset(frame)
    if frame:GetNumPoints() == 1 then
        local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
        if point == "CENTER" and relativePoint == "CENTER" and relativeTo == Minimap then
            return x or 0, y or 0
        end
    end

    local fx, fy = frame:GetCenter()
    local mx, my = Minimap:GetCenter()
    if not (fx and fy and mx and my) then
        return nil
    end
    local k = frame:GetEffectiveScale() / Minimap:GetEffectiveScale()
    return fx * k - mx, fy * k - my
end

local function IsRingDragging(frame)
    return frame.isMoving or frame.isDragging or frame._dcqosRingDragging
end

local function IsRingItemVisible(item)
    local frame = item.frame
    if not frame or not frame:IsVisible() then
        return false
    end
    if item.hiddenBy and RingSettings()[item.hiddenBy] then
        return false
    end
    return true
end

local function MarkRingDirty()
    if ButtonRing.active and not ButtonRing.applying then
        ButtonRing.dirty = true
    end
end

local function HookRingFrame(frame)
    if frame._dcqosRingHooked then
        return
    end
    frame._dcqosRingHooked = true
    frame:HookScript("OnShow", MarkRingDirty)
    frame:HookScript("OnHide", MarkRingDirty)
    hooksecurefunc(frame, "SetPoint", MarkRingDirty)
end

-- ------------------------------------------------------------
-- Dragging the stock buttons (LibDBIcon and the DC buttons drag themselves)
-- ------------------------------------------------------------

local function CursorAngle()
    local mx, my = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    if not mx or not my or not scale or scale <= 0 then
        return nil
    end
    local cx, cy = GetCursorPosition()
    return NormalizeAngle(math.deg(math.atan2(cy / scale - my, cx / scale - mx)))
end

function ButtonRing:FollowCursor()
    local item = self.dragItem
    local angle = item and CursorAngle()
    if not angle then
        return
    end
    item.setAngle(angle)
    PlaceOnMinimap(item.frame, RingOffset(angle, 0))
end

local function InstallStockDrag(item)
    local handle = item.handle or item.frame
    if handle._dcqosRingDrag or type(handle.RegisterForDrag) ~= "function" then
        return
    end
    handle._dcqosRingDrag = true
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart", function()
        if not ButtonRing.active then
            return
        end
        if GameTooltip and GameTooltip:IsOwned(handle) then
            GameTooltip:Hide()
        end
        item.frame._dcqosRingDragging = true
        ButtonRing.dragItem = item
    end)
    handle:SetScript("OnDragStop", function()
        item.frame._dcqosRingDragging = nil
        if ButtonRing.dragItem == item then
            ButtonRing.dragItem = nil
        end
        MarkRingDirty()
    end)
end

local function RemoveStockDrag(item)
    local handle = item.handle or item.frame
    if not handle._dcqosRingDrag then
        return
    end
    handle._dcqosRingDrag = nil
    handle:RegisterForDrag()
    handle:SetScript("OnDragStart", nil)
    handle:SetScript("OnDragStop", nil)
    item.frame._dcqosRingDragging = nil
end

-- ------------------------------------------------------------
-- Discovery
-- ------------------------------------------------------------

local function IsAddonMinimapButton(button)
    if not button or not button.GetObjectType or button:GetObjectType() ~= "Button" then
        return false
    end

    local name = button.GetName and button:GetName() or ""
    if name == "" or KNOWN_RING_FRAMES[name] or name:find("^LibDBIcon10_") then
        return false
    end

    local parent = button.GetParent and button:GetParent() or nil
    if parent ~= Minimap and parent ~= MinimapCluster then
        return false
    end

    local w = button.GetWidth and button:GetWidth() or 0
    local h = button.GetHeight and button:GetHeight() or 0
    if w > 0 and (w < 16 or w > 48) then
        return false
    end
    if h > 0 and (h < 16 or h > 48) then
        return false
    end

    -- Name-matched only: Minimap also parents hundreds of map pins (GatherMate,
    -- DC-Mapupgrades, quest POIs), none of which belong on the edge.
    return name:find("MinimapButton", 1, true)
        or name:find("MiniMapButton", 1, true)
        or name:find("MinimapIcon", 1, true)
        or name:find("MiniMapIcon", 1, true)
        or false
end

function ButtonRing:AddItem(key, frame, def)
    local item = self.items[key]
    if item then
        item.frame = frame
        return item
    end

    item = {
        key = key,
        frame = frame,
        diameter = def.diameter or RING_BUTTON_DIAMETER,
        defaultAngle = def.angle,
        getAngle = def.get,
        setAngle = def.set,
        restore = def.restore,
        hiddenBy = def.hiddenBy,
        stock = def.stock,
        generic = def.generic,
        handle = def.handle,
    }
    if item.stock then
        item.originalPoints = CapturePoints(frame)
    end

    self.items[key] = item
    table.insert(self.order, key)
    HookRingFrame(frame)
    return item
end

function ButtonRing:Rescan(full)
    for _, def in ipairs(STOCK_RING_BUTTONS) do
        local frame = _G[def.name]
        if frame then
            local name = def.name
            local item = self:AddItem(name, frame, {
                angle = def.angle,
                diameter = def.diameter,
                hiddenBy = def.hiddenBy,
                stock = true,
                handle = def.handle and _G[def.handle] or nil,
                get = function()
                    return StockAngleStore()[name]
                end,
                set = function(angle)
                    StockAngleStore()[name] = angle
                end,
            })
            InstallStockDrag(item)
        end
    end

    for _, def in ipairs(ADDON_RING_BUTTONS) do
        local frame = _G[def.name]
        if frame then
            self:AddItem(def.name, frame, def)
        end
    end

    local lib = LibStub and LibStub("LibDBIcon-1.0", true)
    if lib and type(lib.objects) == "table" then
        for _, button in pairs(lib.objects) do
            local name = button.GetName and button:GetName()
            if name then
                self:AddItem(name, button, {
                    angle = 225,
                    get = function()
                        if button.db then
                            return button.db.minimapPos
                        end
                        return button.minimapPos
                    end,
                    set = function(angle)
                        if button.db then
                            button.db.minimapPos = angle
                        else
                            button.minimapPos = angle
                        end
                    end,
                })
            end
        end

        if not lib._dcqosRingHooked then
            lib._dcqosRingHooked = true
            local function requestRescan()
                ButtonRing:RequestRescan()
            end
            if type(lib.Register) == "function" then
                hooksecurefunc(lib, "Register", requestRescan)
            end
            -- Show() is what creates a button that was registered hidden.
            if type(lib.Show) == "function" then
                hooksecurefunc(lib, "Show", requestRescan)
            end
        end
    end

    if full then
        for _, parent in ipairs({ Minimap, MinimapCluster }) do
            if parent and parent.GetChildren then
                local children = { parent:GetChildren() }
                for i = 1, #children do
                    local child = children[i]
                    if IsAddonMinimapButton(child) then
                        local name = child:GetName()
                        self:AddItem(name, child, {
                            generic = true,
                            get = function()
                                return StockAngleStore()[name]
                            end,
                            set = function(angle)
                                StockAngleStore()[name] = angle
                            end,
                        })
                    end
                end
            end
        end
    end
end

function ButtonRing:RequestRescan()
    if self.active then
        self.rescanPending = true
        self.dirty = true
    end
end

function ButtonRing:MarkDirty()
    if self.active then
        self.dirty = true
    end
end

-- ------------------------------------------------------------
-- Layout
-- ------------------------------------------------------------

local function PreferredAngle(item, fromPosition)
    if not fromPosition then
        local saved = item.getAngle and tonumber(item.getAngle())
        if saved then
            return NormalizeAngle(saved)
        end
        if item.defaultAngle then
            return NormalizeAngle(item.defaultAngle)
        end
    end

    local x, y = CurrentOffset(item.frame)
    if x and (x ~= 0 or y ~= 0) then
        return NormalizeAngle(math.deg(math.atan2(y, x)))
    end
    return NormalizeAngle(item.defaultAngle or 225)
end

function ButtonRing:BuildEnvironment(mx, my)
    local env = {
        gap = RingGap(),
        quadrants = ShapeQuadrants(),
        rects = {},
    }

    local mScale = Minimap:GetEffectiveScale()
    if not mScale or mScale <= 0 then
        return env
    end

    local function rectOf(frame)
        if not frame or not frame:IsVisible() then
            return nil
        end
        local l, r, b, t = frame:GetLeft(), frame:GetRight(), frame:GetBottom(), frame:GetTop()
        if not (l and r and b and t) then
            return nil
        end
        local k = frame:GetEffectiveScale() / mScale
        return { l = l * k - mx, r = r * k - mx, b = b * k - my, t = t * k - my }
    end

    -- Buttons stay on screen, and above the cluster's bottom edge: WatchFrame,
    -- DurabilityFrame and the capture bars all hang off that edge.
    env.bounds = rectOf(UIParent)
    local cluster = rectOf(MinimapCluster)
    if env.bounds and cluster then
        env.bounds.b = math.max(env.bounds.b, cluster.b)
    end

    for _, name in ipairs(RING_RESERVED_FRAMES) do
        local rect = rectOf(_G[name])
        if rect then
            table.insert(env.rects, rect)
        end
    end

    -- The badge comes and goes with instances, so Layout lets a button step
    -- aside for it without giving up its spot.
    local badge = rectOf(_G[DIFFICULTY_BADGE])
    if badge then
        badge.transient = true
        table.insert(env.rects, badge)
    end

    return env
end

-- ignoreTransient: whether the spot would be free if the badge were hidden.
local function SpotIsFree(x, y, radius, placed, env, ignoreTransient)
    local bounds = env.bounds
    if bounds and (x - radius < bounds.l or x + radius > bounds.r
        or y - radius < bounds.b or y + radius > bounds.t) then
        return false
    end

    local pad = radius + env.gap / 2
    for i = 1, #env.rects do
        local rect = env.rects[i]
        if not (ignoreTransient and rect.transient) then
            local dx = x - math.max(rect.l, math.min(x, rect.r))
            local dy = y - math.max(rect.b, math.min(y, rect.t))
            if dx * dx + dy * dy < pad * pad then
                return false
            end
        end
    end

    for i = 1, #placed do
        local other = placed[i]
        local need = radius + other.radius + env.gap
        local dx, dy = x - other.x, y - other.y
        if dx * dx + dy * dy < need * need then
            return false
        end
    end

    return true
end

-- Nearest free angle to `preferred`, searching outward in both directions on
-- the first track before trying the next one out.
local function FindSpot(preferred, radius, placed, env)
    for track = 0, RING_TRACKS - 1 do
        for step = 0, 180, RING_SEARCH_STEP do
            local angle = NormalizeAngle(preferred + step)
            local x, y = RingOffset(angle, track, env.quadrants)
            if SpotIsFree(x, y, radius, placed, env) then
                return angle, x, y
            end
            if step > 0 and step < 180 then
                angle = NormalizeAngle(preferred - step)
                x, y = RingOffset(angle, track, env.quadrants)
                if SpotIsFree(x, y, radius, placed, env) then
                    return angle, x, y
                end
            end
        end
    end
    return nil
end

local function ByPreferredAngle(a, b)
    if a.preferred ~= b.preferred then
        return a.preferred < b.preferred
    end
    return a.item.key < b.item.key
end

function ButtonRing:Layout()
    if not self.active or not Minimap or not Minimap:IsVisible() then
        self.dirty = false
        return
    end

    local mx, my = Minimap:GetCenter()
    if not (mx and my) then
        -- Not laid out yet: stay dirty and try again next frame.
        return
    end

    self.dirty = false
    if self.rescanPending then
        self.rescanPending = false
        self:Rescan(true)
    end

    -- Who yields is decided in two passes. First every button tries its own
    -- spot -- where it already sits if it has not moved, otherwise its saved
    -- angle -- and keeps it if nothing placed so far is in the way. Only then
    -- do the buttons that lost their spot search for the nearest free one.
    -- Searching in the same pass would let a displaced button take a spot that
    -- belongs to one placed after it and shuffle the whole ring along.
    --
    -- Within each pass: buttons that were already sitting still, then buttons
    -- that just appeared, and last whatever was just moved (dropped by the
    -- player, or put back on its own angle by its owner).
    local env = self:BuildEnvironment(mx, my)
    local settled, arrivals, moved = {}, {}, {}
    for _, key in ipairs(self.order) do
        local item = self.items[key]
        if IsRingItemVisible(item) then
            local last = self.lastPlaced[key]
            local x, y = CurrentOffset(item.frame)
            local wasMoved = last and (not x
                or math.abs(x - last.x) > RING_MOVE_TOLERANCE
                or math.abs(y - last.y) > RING_MOVE_TOLERANCE)
            -- A generic addon button saves its angle somewhere the ring cannot
            -- see, so after its own drag the only truth is where it now sits.
            local entry = {
                item = item,
                preferred = PreferredAngle(item, wasMoved and item.generic),
            }
            if last and not wasMoved then
                if last.homeX then
                    -- Standing aside for the badge: back home once it is gone,
                    -- and until then stay where it is.
                    entry.x, entry.y = last.homeX, last.homeY
                    entry.asideX, entry.asideY = last.x, last.y
                else
                    -- Possibly on an outer track, which no saved angle can express.
                    entry.x, entry.y = last.x, last.y
                end
                table.insert(settled, entry)
            else
                entry.x, entry.y = RingOffset(entry.preferred, 0, env.quadrants)
                table.insert(last and moved or arrivals, entry)
            end
        end
    end
    table.sort(settled, ByPreferredAngle)
    table.sort(arrivals, ByPreferredAngle)
    table.sort(moved, ByPreferredAngle)

    local placed, nextPlaced = {}, {}
    local changed = false

    local function commit(entry, angle, x, y)
        local item = entry.item
        local cx, cy = CurrentOffset(item.frame)
        if not cx or math.abs(cx - x) > 0.01 or math.abs(cy - y) > 0.01 then
            PlaceOnMinimap(item.frame, x, y)
        end

        table.insert(placed, { x = x, y = y, radius = item.diameter / 2 })
        nextPlaced[item.key] = { x = x, y = y, homeX = entry.homeX, homeY = entry.homeY }

        local last = self.lastPlaced[item.key]
        if not last or last.x ~= x or last.y ~= y then
            changed = true
        end
        -- A button standing aside for the badge keeps its saved angle: that
        -- is where it goes back to.
        if item.setAngle and not entry.homeX
            and math.abs(AngleDelta(angle, entry.preferred)) >= 0.5 then
            item.setAngle(angle)
        end
    end

    local function search(entry)
        local preferred = entry.preferred
        local angle, x, y = FindSpot(preferred, entry.item.diameter / 2, placed, env)
        if not angle then
            -- Every track is full: overlapping beats vanishing.
            angle = preferred
            x, y = RingOffset(preferred, 0, env.quadrants)
        end
        commit(entry, angle, x, y)
    end

    local displaced = {}
    for _, group in ipairs({ settled, arrivals, moved }) do
        for i = 1, #group do
            local entry = group[i]
            local radius = entry.item.diameter / 2
            if SpotIsFree(entry.x, entry.y, radius, placed, env) then
                commit(entry, entry.preferred, entry.x, entry.y)
            else
                if SpotIsFree(entry.x, entry.y, radius, placed, env, true) then
                    -- Only the badge is in the way: this stays the button's spot.
                    entry.homeX, entry.homeY = entry.x, entry.y
                end
                if entry.homeX and entry.asideX
                    and SpotIsFree(entry.asideX, entry.asideY, radius, placed, env) then
                    commit(entry, entry.preferred, entry.asideX, entry.asideY)
                else
                    table.insert(displaced, entry)
                end
            end
        end
    end

    for i = 1, #displaced do
        search(displaced[i])
    end

    if not changed then
        for key in pairs(self.lastPlaced) do
            if not nextPlaced[key] then
                changed = true
                break
            end
        end
    end
    self.lastPlaced = nextPlaced

    if changed then
        addon:FireEvent("MINIMAP_BUTTONS_LAYOUT")
    end
end

function ButtonRing:AnyDragging()
    if self.dragItem then
        return true
    end

    local mouseDown = type(IsMouseButtonDown) == "function"
        and (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton"))

    for _, key in ipairs(self.order) do
        local item = self.items[key]
        local frame = item.frame
        if frame and IsRingDragging(frame) then
            return true
        end
        -- Unknown addons flag nothing while they drag; a held mouse button over
        -- one of their buttons is the best available signal.
        if mouseDown and item.generic and frame and frame:IsVisible()
            and type(MouseIsOver) == "function" and MouseIsOver(frame) then
            return true
        end
    end
    return false
end

function ButtonRing:VisibleSetChanged()
    local visible = 0
    for _, key in ipairs(self.order) do
        if IsRingItemVisible(self.items[key]) then
            if not self.lastPlaced[key] then
                return true
            end
            visible = visible + 1
        end
    end
    for _ in pairs(self.lastPlaced) do
        visible = visible - 1
    end
    return visible ~= 0
end

local ringDriver = CreateFrame("Frame")
ringDriver:Hide()
ringDriver.scanElapsed = 0
ringDriver.fullScanElapsed = 0
ringDriver:SetScript("OnUpdate", function(self, elapsed)
    local ring = ButtonRing
    if ring.dragItem then
        ring:FollowCursor()
    end

    self.scanElapsed = self.scanElapsed + elapsed
    if self.scanElapsed >= RING_SCAN_INTERVAL then
        self.scanElapsed = 0
        self.fullScanElapsed = self.fullScanElapsed + RING_SCAN_INTERVAL
        if self.fullScanElapsed >= RING_FULL_SCAN_INTERVAL then
            self.fullScanElapsed = 0
            ring.rescanPending = true
        end
        if ring.rescanPending or ring:VisibleSetChanged() then
            ring.dirty = true
        end
    end

    if ring.dirty and not ring:AnyDragging() then
        ring:Layout()
    end
end)
ringDriver:SetScript("OnEvent", function()
    ButtonRing:MarkDirty()
end)
ringDriver:RegisterEvent("UI_SCALE_CHANGED")
ringDriver:RegisterEvent("DISPLAY_SIZE_CHANGED")

-- The badge is too big for the track's free spots: the left edge is usually
-- full, and the zone text, the screen edge and the cluster's bottom close the
-- others. As a ring newcomer it was pushed onto an outer track, away from the
-- map. So it hangs inside the map's top-left corner instead, and the ring
-- routes around it (BuildEnvironment). Stock never moves it again; if another
-- addon does, the ring routes around it wherever it ends up.
function ButtonRing:DockBadge()
    local badge = _G[DIFFICULTY_BADGE]
    if not badge or not Minimap then
        return
    end
    if not self.badgePoints then
        self.badgePoints = CapturePoints(badge)
    end
    HookRingFrame(badge)
    self.applying = true
    badge:ClearAllPoints()
    badge:SetPoint("TOPLEFT", Minimap, "TOPLEFT", BADGE_DOCK_X, BADGE_DOCK_Y)
    self.applying = false
end

function ButtonRing:Activate()
    self.active = true
    self:Rescan(true)
    self:DockBadge()
    if Minimap and not Minimap._dcqosRingHooked then
        Minimap._dcqosRingHooked = true
        Minimap:HookScript("OnShow", MarkRingDirty)
    end
    self.dirty = true
    ringDriver:Show()
end

function ButtonRing:Deactivate()
    if not self.active then
        return
    end
    self.active = false
    self.dirty = false
    self.dragItem = nil
    self.lastPlaced = {}
    ringDriver:Hide()

    for _, key in ipairs(self.order) do
        local item = self.items[key]
        if item.stock then
            RemoveStockDrag(item)
            if item.originalPoints then
                RestorePoints(item.frame, item.originalPoints)
            end
        end
    end

    local badge = _G[DIFFICULTY_BADGE]
    if badge and self.badgePoints then
        RestorePoints(badge, self.badgePoints)
    end
    self.badgePoints = nil
end

-- With the ring gone, let each addon put its button back on its own math
-- (GetMinimapShape has just been handed back to stock).
function ButtonRing:ReturnButtonsToOwners()
    for _, def in ipairs(ADDON_RING_BUTTONS) do
        if def.restore then
            pcall(def.restore)
        end
    end
end

-- Stock buttons go back to their default angles; every addon button is pulled
-- to the bottom-left of the map, where the ring lines them up one after another.
function ButtonRing:ResetPositions()
    RingSettings().buttonAngles = {}

    for _, def in ipairs(ADDON_RING_BUTTONS) do
        def.set(def.angle)
    end

    local lib = LibStub and LibStub("LibDBIcon-1.0", true)
    if lib and type(lib.objects) == "table" then
        for _, button in pairs(lib.objects) do
            if button.db then
                button.db.minimapPos = 225
            else
                button.minimapPos = 225
            end
        end
    end

    addon:SaveSettings()
    self.lastPlaced = {}
    self:RequestRescan()
end

-- ============================================================
-- Skin
-- ============================================================

-- The DC frame replaces the stock ring art. MinimapBackdrop itself stays shown:
-- it is the parent of the zoom, tracking, world map and LFG buttons, and hiding
-- it silently hid all of them regardless of their settings.
local function SetStockRingArtShown(shown)
    local alpha = shown and 1 or 0
    if MinimapBackdrop then
        MinimapBackdrop:Show()
    end
    if MinimapBorder then
        if shown then
            MinimapBorder:SetAlpha(1)
            MinimapBorder:Show()
        else
            MinimapBorder:Hide()
        end
    end
    -- Minimap_UpdateRotationSetting toggles these two with Show/Hide whenever
    -- rotateMinimap changes, so fade them instead.
    if MinimapNorthTag then
        MinimapNorthTag:SetAlpha(alpha)
    end
    if MinimapCompassTexture then
        MinimapCompassTexture:SetAlpha(alpha)
    end
end

local function MigrateMinimapSettings(s)
    -- v2: hiding MinimapBackdrop hid the zoom buttons with it, so nobody on the
    -- DC frame ever saw them even with "Hide zoom buttons" off. Now that the
    -- backdrop stays shown, keep what those players have been looking at.
    if (s.buttonLayoutVersion or 1) < 2 then
        s.buttonLayoutVersion = 2
        if s.useDcFrame ~= false then
            s.hideZoom = true
        end
        addon:SaveSettings()
    end
end

local function ApplyMinimapSkin()
    local s = addon.settings.minimap
    if not s.enabled then return end

    MigrateMinimapSettings(s)
    CaptureOriginalState()

    local useDcFrame = (s.useDcFrame ~= false)
    local fillFrame = useDcFrame and (s.fillFrame ~= false)
    local disableRotate = (s.disableRotate ~= false)

    ApplyClusterPlacement()
    HookInfoBar()

    -- Rotating minimap + square mask looks like the entire map is spinning/tilting (diamond effect).
    -- If desired, force north-up while our framed minimap is enabled.
    if disableRotate and SetCVar and GetCVar then
        if GetCVar("rotateMinimap") == "1" then
            SetCVar("rotateMinimap", "0")
        end
    end

    -- Important: avoid re-anchoring/resizing Minimap itself. The Blizzard UI (and many addons)
    -- assume Minimap stays positioned inside MinimapCluster. We only move/scale MinimapCluster.

    if fillFrame or s.style == "square" then
        Minimap:SetMaskTexture("Interface\\ChatFrame\\ChatFrameBackground")
    else
        Minimap:SetMaskTexture("Textures\\MinimapMask")
    end

    if useDcFrame then
        EnsureDcMinimapFrame():Show()
        SetStockRingArtShown(false)
    elseif Minimap.DCQOSFrame then
        Minimap.DCQOSFrame:Hide()
    end

    -- Keep the zone text frame visible in every style.
    if MinimapBorderTop then MinimapBorderTop:Show() end

    if s.style == "round" and not fillFrame then
        if not useDcFrame then
            SetStockRingArtShown(true)
        end
        -- Ensure addons that query shape behave correctly.
        _G.GetMinimapShape = function() return "ROUND" end
    else
        if not useDcFrame then
            if MinimapBackdrop then MinimapBackdrop:Show() end
            if MinimapBorder then MinimapBorder:Hide() end
        end
        _G.GetMinimapShape = function() return "SQUARE" end
    end
    RefreshLibDBIcons()

    if s.mouseWheelZoom then
        Minimap:EnableMouseWheel(true)
        Minimap:SetScript("OnMouseWheel", function(self, delta)
            if delta > 0 then
                if MinimapZoomIn then MinimapZoomIn:Click() end
            else
                if MinimapZoomOut then MinimapZoomOut:Click() end
            end
        end)
    end

    if s.hideZoom then
        if MinimapZoomIn then MinimapZoomIn:Hide() end
        if MinimapZoomOut then MinimapZoomOut:Hide() end
    else
        if MinimapZoomIn then MinimapZoomIn:Show() end
        if MinimapZoomOut then MinimapZoomOut:Show() end
    end

    if s.hideTracking and MiniMapTracking then
        MiniMapTracking:Hide()
        if addon.EnsureQuestMinimapTrackingEnabled then
            addon:EnsureQuestMinimapTrackingEnabled()
        end
    elseif MiniMapTracking then
        MiniMapTracking:Show()
    end

    if s.hideClock and TimeManagerClockButton then
        TimeManagerClockButton:Hide()
    end

    if s.hideCalendar and GameTimeFrame then
        GameTimeFrame:Hide()
    end

    if MiniMapWorldMapButton then
        -- Stays shown in both cases for compatibility with quest/minimap POI
        -- updates; "hidden" means faded out and click-through.
        MiniMapWorldMapButton:Show()
        if MiniMapWorldMapButton.EnableMouse then
            MiniMapWorldMapButton:EnableMouse(not s.hideWorldMapButton)
        end
        MiniMapWorldMapButton:SetAlpha(s.hideWorldMapButton and 0 or 1)
    end

    ButtonRing:Activate()

    -- Re-apply mask after sizing to avoid ring drift in some UIs
    addon:DelayedCall(0.05, function()
        if not runtimeState.captured then
            return
        end

        if fillFrame or s.style == "square" then
            Minimap:SetMaskTexture("Interface\\ChatFrame\\ChatFrameBackground")
        else
            Minimap:SetMaskTexture("Textures\\MinimapMask")
        end

        RefreshLibDBIcons()
        ButtonRing:RequestRescan()

        if s.hideTracking then
            if addon.EnsureQuestMinimapTrackingEnabled then
                addon:EnsureQuestMinimapTrackingEnabled()
            end
        end
    end)

    -- DC-InfoBar and addon minimap buttons can finish setting up after this
    -- runs; pick both up once more.
    addon:DelayedCall(1.0, function()
        if not runtimeState.captured then
            return
        end

        HookInfoBar()
        ApplyClusterPlacement()
        ButtonRing:RequestRescan()

        if s.hideTracking then
            if addon.EnsureQuestMinimapTrackingEnabled then
                addon:EnsureQuestMinimapTrackingEnabled()
            end
        end
    end)
end

local settingHookRegistered = false

function MinimapModule.OnInitialize()
    addon:Debug("Minimap module initializing")
end

function MinimapModule.OnEnable()
    addon:Debug("Minimap module enabling")
    ApplyMinimapSkin()

    if not settingHookRegistered then
        settingHookRegistered = true
        addon:RegisterEvent("SETTING_CHANGED", function(path)
            if not runtimeState.captured then
                return
            end
            if path == "minimap.size" then
                ApplyClusterPlacement()
                ButtonRing:MarkDirty()
            elseif path == "minimap.buttonGap" then
                ButtonRing:MarkDirty()
            end
        end)
    end
end

function MinimapModule.OnDisable()
    addon:Debug("Minimap module disabling")
    RestoreOriginalState()
end

function MinimapModule.CreateSettings(parent)
    local settings = addon.settings.minimap

    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Minimap")

    local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText("Configure minimap style, position, and visibility of elements. Drag any minimap button to move it around the map.")
    desc:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    desc:SetJustifyH("LEFT")

    local yOffset = -70

    local enabledCb = addon:CreateCheckbox(parent)
    enabledCb:SetPoint("TOPLEFT", 16, yOffset)
    enabledCb.Text:SetText("Enable Minimap module")
    enabledCb:SetChecked(settings.enabled)
    enabledCb:SetScript("OnClick", function(self)
        addon:SetSetting("minimap.enabled", self:GetChecked())
        addon:PromptReloadUI()
    end)
    yOffset = yOffset - 30

    local squareStyleCb = addon:CreateCheckbox(parent)
    squareStyleCb:SetPoint("TOPLEFT", 16, yOffset)
    squareStyleCb.Text:SetText("Square minimap style")
    squareStyleCb:SetChecked(settings.style == "square")
    squareStyleCb:SetScript("OnClick", function(self)
        addon:SetSetting("minimap.style", self:GetChecked() and "square" or "round")
        addon:PromptReloadUI()
    end)
    yOffset = yOffset - 30

    local fillCb = addon:CreateCheckbox(parent)
    fillCb:SetPoint("TOPLEFT", 16, yOffset)
    fillCb.Text:SetText("Fill the frame (square minimap)")
    fillCb:SetChecked(settings.fillFrame ~= false)
    fillCb:SetScript("OnClick", function(self)
        addon:SetSetting("minimap.fillFrame", self:GetChecked())
        addon:PromptReloadUI()
    end)
    yOffset = yOffset - 22

    local rotateCb = addon:CreateCheckbox(parent)
    rotateCb:SetPoint("TOPLEFT", 16, yOffset)
    rotateCb.Text:SetText("Disable rotating minimap (north-up)")
    rotateCb:SetChecked(settings.disableRotate ~= false)
    rotateCb:SetScript("OnClick", function(self)
        addon:SetSetting("minimap.disableRotate", self:GetChecked())
        addon:PromptReloadUI()
    end)
    yOffset = yOffset - 22

    local sizeSlider = addon:CreateSlider(parent)
    sizeSlider:SetPoint("TOPLEFT", 16, yOffset)
    sizeSlider:SetWidth(200)
    sizeSlider:SetMinMaxValues(120, 220)
    sizeSlider:SetValueStep(2)
    sizeSlider.Text:SetText("Size")
    sizeSlider.Low:SetText("120")
    sizeSlider.High:SetText("220")
    sizeSlider:SetValue(settings.size or 160)
    sizeSlider:SetScript("OnValueChanged", function(self, value)
        addon:SetSetting("minimap.size", math.floor(value + 0.5))
    end)
    yOffset = yOffset - 50

    local hideZoomCb = addon:CreateCheckbox(parent)
    hideZoomCb:SetPoint("TOPLEFT", 16, yOffset)
    hideZoomCb.Text:SetText("Hide zoom buttons")
    hideZoomCb:SetChecked(settings.hideZoom)
    hideZoomCb:SetScript("OnClick", function(self)
        addon:SetSetting("minimap.hideZoom", self:GetChecked())
        addon:PromptReloadUI()
    end)
    yOffset = yOffset - 22

    local hideTrackingCb = addon:CreateCheckbox(parent)
    hideTrackingCb:SetPoint("TOPLEFT", 16, yOffset)
    hideTrackingCb.Text:SetText("Hide tracking button")
    hideTrackingCb:SetChecked(settings.hideTracking)
    hideTrackingCb:SetScript("OnClick", function(self)
        addon:SetSetting("minimap.hideTracking", self:GetChecked())
        addon:PromptReloadUI()
    end)
    yOffset = yOffset - 22

    local hideClockCb = addon:CreateCheckbox(parent)
    hideClockCb:SetPoint("TOPLEFT", 16, yOffset)
    hideClockCb.Text:SetText("Hide clock")
    hideClockCb:SetChecked(settings.hideClock)
    hideClockCb:SetScript("OnClick", function(self)
        addon:SetSetting("minimap.hideClock", self:GetChecked())
        addon:PromptReloadUI()
    end)
    yOffset = yOffset - 22

    local hideCalendarCb = addon:CreateCheckbox(parent)
    hideCalendarCb:SetPoint("TOPLEFT", 16, yOffset)
    hideCalendarCb.Text:SetText("Hide calendar")
    hideCalendarCb:SetChecked(settings.hideCalendar)
    hideCalendarCb:SetScript("OnClick", function(self)
        addon:SetSetting("minimap.hideCalendar", self:GetChecked())
        addon:PromptReloadUI()
    end)
    yOffset = yOffset - 22

    local hideMapCb = addon:CreateCheckbox(parent)
    hideMapCb:SetPoint("TOPLEFT", 16, yOffset)
    hideMapCb.Text:SetText("Hide world map button")
    hideMapCb:SetChecked(settings.hideWorldMapButton)
    hideMapCb:SetScript("OnClick", function(self)
        addon:SetSetting("minimap.hideWorldMapButton", self:GetChecked())
        addon:PromptReloadUI()
    end)
    yOffset = yOffset - 22

    local blizzPosCb = addon:CreateCheckbox(parent)
    blizzPosCb:SetPoint("TOPLEFT", 16, yOffset)
    blizzPosCb.Text:SetText("Use Blizzard position (top-right, under the info bar)")
    blizzPosCb:SetChecked(settings.useBlizzardPosition ~= false)
    blizzPosCb:SetScript("OnClick", function(self)
        addon:SetSetting("minimap.useBlizzardPosition", self:GetChecked())
        addon:PromptReloadUI()
    end)
    yOffset = yOffset - 40

    local gapSlider = addon:CreateSlider(parent)
    gapSlider:SetPoint("TOPLEFT", 16, yOffset)
    gapSlider:SetWidth(200)
    gapSlider:SetMinMaxValues(0, 12)
    gapSlider:SetValueStep(1)
    gapSlider.Text:SetText("Gap between minimap buttons")
    gapSlider.Low:SetText("0")
    gapSlider.High:SetText("12")
    gapSlider:SetValue(tonumber(settings.buttonGap) or RING_DEFAULT_GAP)
    gapSlider:SetScript("OnValueChanged", function(self, value)
        addon:SetSetting("minimap.buttonGap", math.floor(value + 0.5))
    end)

    local resetButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    resetButton:SetPoint("LEFT", gapSlider, "RIGHT", 24, 0)
    resetButton:SetWidth(170)
    resetButton:SetHeight(22)
    resetButton:SetText("Reset button positions")
    resetButton:SetScript("OnClick", function()
        ButtonRing:ResetPositions()
    end)
end

addon:RegisterModule("Minimap", MinimapModule)
