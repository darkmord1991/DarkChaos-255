-- ============================================================
-- DC-QoS: World Map Zoom (mouse wheel + drag to pan)
-- ============================================================
-- Zooms the custom continent overviews of map 750 (Mount Hyjal) and map 751
-- (Plaguelands). Map 750's overview borrows the whole stock Kalimdor art, so its
-- seven zones and every pin on them sit in the northern quarter of the canvas;
-- map 751 packs eight zones into one picture. Mouse wheel zooms at the cursor,
-- left-drag pans. Leaving the map (a zone label, Zoom Out, closing it) or
-- entering combat returns to the stock view.
--
-- 3.3.5 has no map canvas, so one is built only while zoomed and taken apart
-- again at zoom 1. Unzoomed, nothing here touches the stock map.
--
--   * Clipping. WorldMapDetailFrame, WorldMapBlobFrame, WorldMapButton and
--     WorldMapPOIFrame move into a ScrollFrame laid over the map's own
--     rectangle. A 3.3.5 ScrollFrame clips the drawing AND the mouse hit test
--     of everything under it, whatever strata a pin uses
--     (CSimpleScrollFrame::RenderScrollChild, CSimpleFrame::TestHitRect in the
--     decompiled client), so pins scrolled out of view neither show over the
--     quest list nor catch its clicks.
--   * Zoom ENLARGES the canvas (width/height) instead of scaling it. Every pin
--     layer, stock and DC, places pins at fraction * GetWidth(), so pins spread
--     apart and keep their size. Only the 12 base tiles and the explored-area
--     overlays have fixed pixel sizes; they are resized here.
--   * Pan is the detail frame's offset inside the scroll child. The scroll
--     offsets themselves stay 0: the engine keeps them in unscaled units, the
--     offset of a SetPoint is in the frame's own units, so this avoids a unit
--     conversion nobody can see going wrong.
--   * Stock code re-anchors and re-scales the detail frame on every quest-log
--     update (WorldMapFrame_DisplayQuests flips between the full and the quest
--     view, WorldMapWindow flips it back). While zoomed, those writes are
--     redirected to the viewport through hooks on the detail frame's own
--     SetPoint/ClearAllPoints/SetScale, so the zoom survives them.
--   * Pin layers that do not refresh on a size change (DC-Mapupgrades,
--     DeathPins, GatherMate) are kept in place by rescaling every pin anchored
--     to the canvas's TOPLEFT by the zoom ratio, before the resize, so a layer
--     that does refresh simply writes the same value again.
--   * The native player arrow is not part of the canvas and cannot be clipped;
--     it is hidden while the player is outside the visible part.
--
-- The same page also sizes the player arrow on every world map
-- (ApplyPlayerArrowSize, default 1.5x the stock model scale).
-- ============================================================

local addon = DCQOS
if not addon then
    return
end

local WorldMapZoom = {
    displayName = "World Map Zoom",
    settingKey = "worldMapZoom",
    icon = "Interface\\Icons\\INV_Misc_Spyglass_03",
    defaults = {
        worldMapZoom = {
            enabled = true,
            maxZoom = 4,
            playerArrowScale = 1.5,
        },
    },
}

-- Game maps whose continent overview can be zoomed.
local ZOOMABLE_GAME_MAPS = {
    [750] = true, -- Mount Hyjal (80-130), continent WorldMapArea 1262
    [751] = true, -- Plaguelands, continent WorldMapArea 1267
}

-- Only used when the client lacks the GetWorldMapAreaBounds export: the UI map
-- ids (WorldMapArea.ID + 1) of the two overviews above.
local FALLBACK_UI_MAP_IDS = {
    [1263] = true,
    [1268] = true,
}

local ZOOM_STEP = 1.25         -- per wheel notch
local MIN_KEPT_ZOOM = 1.1      -- zooming out below this returns to the stock map
local MAX_ZOOM_LIMIT = 8
local DRAG_THRESHOLD = 4       -- cursor units before a press becomes a pan

local state = {
    active = false,        -- module enabled
    installed = false,     -- hooks installed (they stay; they are no-ops unless engaged)
    engaged = false,       -- canvas frames live in the viewport
    mapKey = nil,          -- UI map id the zoom belongs to
    zoom = 1,
    panX = 0,              -- canvas units (detail frame units) of the viewport's top-left
    panY = 0,
    writing = false,       -- our own writes to the detail frame; hooks ignore them
    viewport = nil,        -- ScrollFrame over the map rectangle
    holder = nil,          -- its scroll child
    saved = nil,           -- what Engage changed, for Disengage
    intended = nil,        -- anchors stock asked for the detail frame while engaged
    overlayBase = {},      -- [overlay texture] = { w, h, x, y } as stock last wrote them
    drag = nil,
    wheelOwned = false,    -- we enabled the wheel on WorldMapButton
    eventFrame = nil,
}

local function GetSettings()
    return (addon.settings and addon.settings.worldMapZoom) or WorldMapZoom.defaults.worldMapZoom
end

local function GetMaxZoom()
    local value = tonumber(GetSettings().maxZoom) or 4
    if value < 1.5 then
        value = 1.5
    elseif value > MAX_ZOOM_LIMIT then
        value = MAX_ZOOM_LIMIT
    end
    return value
end

local function InCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown() and true or false
end

-- ------------------------------------------------------------ player arrow

local ARROW_SCALE_MIN, ARROW_SCALE_MAX = 1, 3
local arrowBase = {}   -- [model or "player"] = stock size, read once per UI session

local function GetArrowScale()
    local value = tonumber(GetSettings().playerArrowScale) or 1.5
    return math.max(ARROW_SCALE_MIN, math.min(value, ARROW_SCALE_MAX))
end

-- The world-map player arrow on every map. It is a native model
-- (CGWorldMap::CreateArrowFrame, created by WorldMapFrame_OnLoad): its size is
-- the model scale, which SetModelScale stores as is and nothing resets per
-- frame (UpdateWorldMapArrowFrames only re-centres it and sets the facing).
-- The frames are destroyed on every UI reload and recreated at the stock scale,
-- so the stock value read here once per session is the real one.
-- WorldMapPlayer is the invisible frame that gives the arrow its tooltip.
local function ApplyPlayerArrowSize()
    local factor = state.active and GetArrowScale() or 1
    for _, name in ipairs({ "PlayerArrowFrame", "PlayerArrowEffectFrame" }) do
        local model = rawget(_G, name)
        if type(model) == "table" and type(model.GetModelScale) == "function"
            and type(model.SetModelScale) == "function" then
            if arrowBase[model] == nil then
                local base = tonumber(model:GetModelScale())
                arrowBase[model] = (base and base > 0) and base or false
            end
            if arrowBase[model] then
                model:SetModelScale(arrowBase[model] * factor)
            end
        end
    end
    local hit = rawget(_G, "WorldMapPlayer")
    if hit and hit.GetWidth then
        if not arrowBase.player then
            arrowBase.player = { hit:GetWidth(), hit:GetHeight() }
        end
        hit:SetWidth(arrowBase.player[1] * factor)
        hit:SetHeight(arrowBase.player[2] * factor)
    end
end

-- ------------------------------------------------------------ eligibility

-- The UI map id of the displayed map when it is a zoomable continent overview,
-- else nil. GetCurrentMapZone() == 0 is the overview marker; the game map comes
-- from the client's own WorldMapArea rows (areaId 0 = the continent row).
local function CurrentZoomableMap()
    if type(GetCurrentMapZone) ~= "function" or type(GetCurrentMapAreaID) ~= "function" then
        return nil
    end
    if GetCurrentMapZone() ~= 0 then
        return nil
    end
    local uiMapId = tonumber(GetCurrentMapAreaID())
    if not uiMapId or uiMapId <= 0 then
        return nil
    end

    local mapUtils = addon.GetMapUtils and addon:GetMapUtils()
    if mapUtils and mapUtils.GetMapAreaBounds then
        local gameMapId, _, _, _, _, areaId = mapUtils.GetMapAreaBounds(uiMapId)
        if gameMapId and gameMapId >= 0 then
            if ZOOMABLE_GAME_MAPS[gameMapId] and (areaId or 0) == 0 then
                return uiMapId
            end
            return nil
        end
    end
    if FALLBACK_UI_MAP_IDS[uiMapId] then
        return uiMapId
    end
    return nil
end

-- ---------------------------------------------------------------- anchors

local function CapturePoints(frame)
    local points = {}
    for i = 1, frame:GetNumPoints() do
        local point, rel, relPoint, x, y = frame:GetPoint(i)
        points[#points + 1] = { point, rel, relPoint, x or 0, y or 0 }
    end
    return points
end

local function ApplyPoints(frame, points, scale)
    scale = scale or 1
    frame:ClearAllPoints()
    for _, p in ipairs(points) do
        frame:SetPoint(p[1], p[2], p[3], p[4] * scale, p[5] * scale)
    end
end

-- SetPoint's argument forms: (point), (point, x, y), (point, rel),
-- (point, rel, x, y), (point, rel, relPoint[, x, y]). A missing relative
-- region means the parent, which for the stock caller is WorldMapFrame.
local function ParsePoint(point, a, b, c, d)
    local rel, relPoint, x, y
    if type(a) == "number" then
        x, y = a, b
    elseif type(b) == "number" then
        rel, x, y = a, b, c
    else
        rel, relPoint, x, y = a, b, c, d
    end
    if type(rel) == "string" then
        rel = _G[rel]
    end
    point = tostring(point):upper()
    return { point, rel or WorldMapFrame, relPoint and tostring(relPoint):upper() or point, x or 0, y or 0 }
end

-- ---------------------------------------------------------------- geometry

local function EnsureFrames()
    if state.viewport then
        return true
    end
    if type(CreateFrame) ~= "function" or not WorldMapFrame then
        return false
    end
    local viewport = CreateFrame("ScrollFrame", "DCQOSWorldMapZoomFrame", WorldMapFrame)
    viewport:Hide()
    viewport:EnableMouse(false)
    local holder = CreateFrame("Frame", "DCQOSWorldMapZoomCanvas", viewport)
    holder:SetWidth(1)
    holder:SetHeight(1)
    viewport:SetScrollChild(holder)
    -- The engine anchors a scroll child to the scroll frame's TOPLEFT itself;
    -- saying so explicitly costs nothing and does not depend on when it does.
    holder:ClearAllPoints()
    holder:SetPoint("TOPLEFT", viewport, "TOPLEFT", 0, 0)
    state.viewport, state.holder = viewport, holder
    return true
end

-- The viewport stands exactly where stock wants the detail frame: the same
-- anchors, with offsets converted from detail units to WorldMapFrame units.
local function PlaceViewport()
    local saved, viewport = state.saved, state.viewport
    local scale = WorldMapDetailFrame:GetScale()
    if not saved or not scale or scale <= 0 then
        return
    end
    viewport:SetWidth(saved.detailW * scale)
    viewport:SetHeight(saved.detailH * scale)
    state.holder:SetWidth(saved.detailW * scale)
    state.holder:SetHeight(saved.detailH * scale)
    if state.intended and #state.intended > 0 then
        ApplyPoints(viewport, state.intended, scale)
    end
end

local function ClampPan()
    local saved = state.saved
    local maxX = saved.detailW * (state.zoom - 1)
    local maxY = saved.detailH * (state.zoom - 1)
    state.panX = math.max(0, math.min(state.panX, maxX))
    state.panY = math.max(0, math.min(state.panY, maxY))
end

local function PlaceCanvas()
    state.writing = true
    WorldMapDetailFrame:ClearAllPoints()
    WorldMapDetailFrame:SetPoint("TOPLEFT", state.holder, "TOPLEFT", -state.panX, state.panY)
    state.writing = false
end

-- Overlays (explored-area art) are rewritten by WorldMapFrame_Update in base
-- units every time; remember what it wrote, then scale from that.
local function CaptureOverlayBases()
    local base = state.overlayBase
    for key in pairs(base) do
        base[key] = nil
    end
    for i = 1, (tonumber(NUM_WORLDMAP_OVERLAYS) or 0) do
        local texture = _G["WorldMapOverlay" .. i]
        if texture and texture:IsShown() and texture:GetNumPoints() > 0 then
            local _, _, _, x, y = texture:GetPoint(1)
            base[texture] = { texture:GetWidth(), texture:GetHeight(), x or 0, y or 0 }
        end
    end
end

local function ScaleOverlays(zoom)
    for texture, b in pairs(state.overlayBase) do
        texture:SetWidth(b[1] * zoom)
        texture:SetHeight(b[2] * zoom)
        texture:SetPoint("TOPLEFT", b[3] * zoom, b[4] * zoom)
    end
end

local function ResizeCanvas()
    local saved, zoom = state.saved, state.zoom
    WorldMapDetailFrame:SetWidth(saved.detailW * zoom)
    WorldMapDetailFrame:SetHeight(saved.detailH * zoom)
    for tile, size in pairs(saved.tiles) do
        tile:SetWidth(size[1] * zoom)
        tile:SetHeight(size[2] * zoom)
    end
    WorldMapButton:SetWidth(saved.buttonW * zoom)
    WorldMapButton:SetHeight(saved.buttonH * zoom)
    if saved.blobW then
        WorldMapBlobFrame:SetWidth(saved.blobW * zoom)
        WorldMapBlobFrame:SetHeight(saved.blobH * zoom)
    end
    if WorldMapBlobFrame then
        WorldMapBlobFrame.xRatio = nil -- stock recomputes its hit translation from this
    end
    ScaleOverlays(zoom)
end

-- Move every pin anchored to the canvas's TOPLEFT by the zoom ratio. Pins are
-- children of WorldMapButton / WorldMapPOIFrame / WorldMapDetailFrame, or of a
-- full-canvas container on WorldMapButton (QuestMapPins' overlay). Must run
-- BEFORE the resize: containers are recognised by matching its current size.
local function RescalePins(ratio)
    if not ratio or math.abs(ratio - 1) < 1e-6 then
        return
    end
    local button = WorldMapButton
    local canvas = { [button] = true, [WorldMapDetailFrame] = true }
    local parents = { button, WorldMapDetailFrame }
    if WorldMapPOIFrame then
        canvas[WorldMapPOIFrame] = true
        parents[#parents + 1] = WorldMapPOIFrame
    end
    local bw, bh = button:GetWidth(), button:GetHeight()
    for _, child in ipairs({ button:GetChildren() }) do
        if child:GetNumPoints() >= 2
            and math.abs((child:GetWidth() or 0) - bw) < 1
            and math.abs((child:GetHeight() or 0) - bh) < 1 then
            canvas[child] = true
            parents[#parents + 1] = child
        end
    end

    for _, parent in ipairs(parents) do
        for _, frame in ipairs({ parent:GetChildren() }) do
            if not canvas[frame] and frame ~= WorldMapFrameAreaFrame then
                for i = 1, frame:GetNumPoints() do
                    local point, rel, relPoint, x, y = frame:GetPoint(i)
                    if canvas[rel] and relPoint == "TOPLEFT" and ((x or 0) ~= 0 or (y or 0) ~= 0) then
                        frame:SetPoint(point, rel, relPoint, x * ratio, y * ratio)
                    end
                end
            end
        end
    end
end

-- Frames anchored to the detail frame that are NOT canvas (the quest list
-- hangs off its TOPRIGHT) would ride along with pan and zoom; point them at
-- the viewport, which has the detail frame's stock rectangle. The zone-name
-- label rides on WorldMapButton's top edge, which a zoomed canvas moves away.
local function RedirectAnchors()
    local detail, viewport = WorldMapDetailFrame, state.viewport
    local skip = { [viewport] = true }
    for _, record in ipairs(state.saved.reparented) do
        skip[record[1]] = true
    end
    local moved = {}

    local function redirect(frame, from)
        for i = 1, frame:GetNumPoints() do
            local point, rel, relPoint, x, y = frame:GetPoint(i)
            if rel == from then
                moved[#moved + 1] = { frame, point, relPoint, x or 0, y or 0, from }
                frame:SetPoint(point, viewport, relPoint, x or 0, y or 0)
            end
        end
    end

    local function visit(frame, depth)
        if skip[frame] then
            return
        end
        redirect(frame, detail)
        if depth < 2 then
            for _, child in ipairs({ frame:GetChildren() }) do
                visit(child, depth + 1)
            end
        end
    end
    for _, child in ipairs({ WorldMapFrame:GetChildren() }) do
        visit(child, 1)
    end
    if WorldMapFrameAreaFrame then
        redirect(WorldMapFrameAreaFrame, WorldMapButton)
    end
    state.saved.redirected = moved
end

local function RestoreAnchors()
    local viewport = state.viewport
    for _, m in ipairs(state.saved.redirected or {}) do
        local frame, point, relPoint, x, y, original = m[1], m[2], m[3], m[4], m[5], m[6]
        -- Only if it is still ours: something may have re-anchored it since.
        for i = 1, frame:GetNumPoints() do
            local p, rel = frame:GetPoint(i)
            if p == point and rel == viewport then
                frame:SetPoint(point, original, relPoint, x, y)
                break
            end
        end
    end
end

-- Cursor position on the visible part of the canvas, in canvas units.
local function CursorOnView()
    local viewport, saved = state.viewport, state.saved
    if type(GetCursorPosition) ~= "function" then
        return nil
    end
    local left, top = viewport:GetLeft(), viewport:GetTop()
    local eff = viewport:GetEffectiveScale()
    local scale = WorldMapDetailFrame:GetScale()
    if not (left and top and eff and eff > 0 and scale and scale > 0) then
        return nil
    end
    local x, y = GetCursorPosition()
    local cx = (x / eff - left) / scale
    local cy = (top - y / eff) / scale
    cx = math.max(0, math.min(cx, saved.detailW))
    cy = math.max(0, math.min(cy, saved.detailH))
    return cx, cy
end

-- ---------------------------------------------------------- engage/release

-- Quest blobs are baked into screen space when drawn and only follow the canvas
-- on stock's next redraw (any quest-log update). Not forced from here: that
-- would mean calling WorldMapFrame_DisplayQuests from addon code, which taints
-- the WORLDMAP_SETTINGS state the quest tracker reads. A continent overview
-- lists no quests, so the zoomable maps draw no blobs anyway.
local function AfterViewChange()
    if WorldMapBlobFrame then
        WorldMapBlobFrame.xRatio = nil
    end
    if type(WorldMapFrame_SetPOIMaxBounds) == "function" then
        pcall(WorldMapFrame_SetPOIMaxBounds)
    end
end

local function Engage(mapKey)
    if state.engaged then
        return true
    end
    local detail, button = WorldMapDetailFrame, WorldMapButton
    if not (WorldMapFrame and detail and button) or InCombat() then
        return false
    end
    if detail:GetParent() ~= WorldMapFrame or button:GetParent() ~= WorldMapFrame then
        return false
    end
    local scale = detail:GetScale()
    local w, h = detail:GetWidth(), detail:GetHeight()
    if not (scale and scale > 0 and w and w > 0 and h and h > 0) then
        return false
    end
    if not EnsureFrames() then
        return false
    end

    local saved = {
        detailW = w,
        detailH = h,
        buttonW = button:GetWidth(),
        buttonH = button:GetHeight(),
        detailPoints = CapturePoints(detail),
        tiles = {},
        reparented = {},
    }
    for i = 1, (tonumber(NUM_WORLDMAP_DETAIL_TILES) or 12) do
        local tile = _G["WorldMapDetailTile" .. i]
        if tile then
            saved.tiles[tile] = { tile:GetWidth(), tile:GetHeight() }
        end
    end
    state.saved = saved
    state.intended = CapturePoints(detail)
    state.zoom, state.panX, state.panY = 1, 0, 0
    state.mapKey = mapKey
    CaptureOverlayBases()

    local viewport, holder = state.viewport, state.holder
    viewport:SetFrameLevel(detail:GetFrameLevel())
    PlaceViewport()
    viewport:Show()

    -- Into the scroll child in stock draw order: inside a scroll frame, frames
    -- draw in child-list order, not by frame level. Levels are put back so
    -- mouse priority is unchanged (SetParent resets them).
    state.writing = true
    local function adopt(frame)
        if not frame or frame:GetParent() ~= WorldMapFrame then
            return false
        end
        local level = frame:GetFrameLevel()
        saved.reparented[#saved.reparented + 1] = { frame, level }
        frame:SetParent(holder)
        frame:SetFrameLevel(level)
        return true
    end
    adopt(detail)
    if adopt(WorldMapBlobFrame) then
        saved.blobW, saved.blobH = WorldMapBlobFrame:GetWidth(), WorldMapBlobFrame:GetHeight()
    end
    adopt(button)
    adopt(WorldMapPOIFrame)
    state.writing = false

    RedirectAnchors()
    PlaceCanvas()
    state.engaged = true
    return true
end

local function Disengage()
    if not state.engaged then
        return
    end
    local saved = state.saved
    local oldZoom = state.zoom
    state.zoom, state.panX, state.panY = 1, 0, 0
    state.drag = nil
    RescalePins(1 / oldZoom)
    ResizeCanvas()

    state.writing = true
    for i = #saved.reparented, 1, -1 do
        local frame, level = saved.reparented[i][1], saved.reparented[i][2]
        if frame:GetParent() == state.holder then
            frame:SetParent(WorldMapFrame)
            frame:SetFrameLevel(level)
        end
    end
    -- Stock's latest wish for the detail frame (it may have switched views
    -- while we were zoomed), or the anchors it had before.
    local points = (state.intended and #state.intended > 0) and state.intended or saved.detailPoints
    ApplyPoints(WorldMapDetailFrame, points)
    state.writing = false

    RestoreAnchors()
    state.viewport:Hide()
    state.engaged = false
    state.saved, state.intended, state.mapKey = nil, nil, nil
    AfterViewChange()
end

-- ------------------------------------------------------------------- zoom

local function SetZoom(newZoom, aroundCenter)
    local oldZoom = state.zoom
    if math.abs(newZoom - oldZoom) < 1e-6 then
        return
    end
    local saved = state.saved
    local cx, cy
    if not aroundCenter then
        cx, cy = CursorOnView()
    end
    if not cx then
        cx, cy = saved.detailW / 2, saved.detailH / 2
    end
    -- Keep the canvas point under the cursor where it is.
    local fx = (state.panX + cx) / oldZoom
    local fy = (state.panY + cy) / oldZoom
    RescalePins(newZoom / oldZoom)
    state.zoom = newZoom
    state.panX = fx * newZoom - cx
    state.panY = fy * newZoom - cy
    ResizeCanvas()
    ClampPan()
    PlaceCanvas()
    AfterViewChange()
end

local function OnMouseWheel(_, delta)
    if not state.active or InCombat() then
        return
    end
    local mapKey = state.engaged and state.mapKey or CurrentZoomableMap()
    if not mapKey then
        return
    end
    local newZoom = math.min(GetMaxZoom(), state.zoom * (ZOOM_STEP ^ (tonumber(delta) or 0)))
    if newZoom < MIN_KEPT_ZOOM then
        Disengage()
        return
    end
    if not state.engaged and not Engage(mapKey) then
        return
    end
    SetZoom(newZoom)
end

-- --------------------------------------------------------------------- pan

local function OnMouseDown(_, mouseButton)
    if mouseButton ~= "LeftButton" or not state.engaged or type(GetCursorPosition) ~= "function" then
        state.drag = nil
        return
    end
    local x, y = GetCursorPosition()
    state.drag = { x = x, y = y, panX = state.panX, panY = state.panY, moved = false }
end

local function UpdateDrag()
    local drag = state.drag
    if not drag then
        return
    end
    -- Released somewhere OnMouseUp did not see.
    if type(IsMouseButtonDown) == "function" and not IsMouseButtonDown("LeftButton") then
        state.drag = nil
        if drag.moved then
            AfterViewChange()
        end
        return
    end
    local x, y = GetCursorPosition()
    local dx, dy = x - drag.x, y - drag.y
    if not drag.moved then
        if math.abs(dx) < DRAG_THRESHOLD and math.abs(dy) < DRAG_THRESHOLD then
            return
        end
        drag.moved = true
    end
    local eff = WorldMapDetailFrame:GetEffectiveScale()
    if not eff or eff <= 0 then
        return
    end
    state.panX = drag.panX - dx / eff
    state.panY = drag.panY + dy / eff
    ClampPan()
    PlaceCanvas()
end

-- Runs after the stock click handler (WorldMapButton's OnMouseUp), which stays
-- untouched: wrapping it would run every map click from addon code. A pan's
-- release therefore also "clicks", which is harmless on the zoomable maps: the
-- engine's zone hit test is dead on custom continents (ProcessMapClick does
-- nothing there), and ZoneLabels' buttons are what navigate.
local function OnMouseUp(_, mouseButton)
    if mouseButton ~= "LeftButton" then
        return
    end
    local drag = state.drag
    state.drag = nil
    if drag and drag.moved then
        AfterViewChange()
    end
end

local function HideArrowOutsideView()
    if type(GetPlayerMapPosition) ~= "function" or type(ShowWorldMapArrowFrame) ~= "function" then
        return
    end
    local px, py = GetPlayerMapPosition("player")
    if not px or (px == 0 and py == 0) then
        return
    end
    local saved = state.saved
    local x = px * saved.detailW * state.zoom - state.panX
    local y = py * saved.detailH * state.zoom - state.panY
    if x < 0 or y < 0 or x > saved.detailW or y > saved.detailH then
        ShowWorldMapArrowFrame(nil)
    end
end

-- -------------------------------------------------------------------- hooks

local function UpdateWheel()
    local button = WorldMapButton
    if not button or type(button.EnableMouseWheel) ~= "function" then
        return
    end
    local want = state.active and (state.engaged or CurrentZoomableMap() ~= nil)
    if want then
        if not button:IsMouseWheelEnabled() then
            button:EnableMouseWheel(true)
            state.wheelOwned = true
        end
    elseif state.wheelOwned then
        -- Only take back what we turned on; another addon may want the wheel.
        button:EnableMouseWheel(false)
        state.wheelOwned = false
    end
end

local function OnWorldMapUpdate()
    CaptureOverlayBases()
    if state.engaged then
        if CurrentZoomableMap() ~= state.mapKey then
            Disengage()
        else
            ScaleOverlays(state.zoom)
        end
    end
    UpdateWheel()
end

-- While zoomed, stock writes meant for the detail frame land on the viewport.
local function OnDetailSetPoint(_, point, a, b, c, d)
    if not state.engaged or state.writing then
        return
    end
    local p = ParsePoint(point, a, b, c, d)
    local replaced = false
    for i, q in ipairs(state.intended) do
        if q[1] == p[1] then
            state.intended[i] = p
            replaced = true
            break
        end
    end
    if not replaced then
        state.intended[#state.intended + 1] = p
    end
    PlaceCanvas()
    PlaceViewport()
end

local function OnDetailClearAllPoints()
    if not state.engaged or state.writing then
        return
    end
    state.intended = {}
    PlaceCanvas()
end

local function OnDetailSetAllPoints(_, rel)
    if not state.engaged or state.writing then
        return
    end
    if type(rel) == "string" then
        rel = _G[rel]
    end
    rel = rel or WorldMapFrame
    state.intended = { { "TOPLEFT", rel, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", rel, "BOTTOMRIGHT", 0, 0 } }
    -- A detail frame sized by someone else's rectangle cannot be zoomed.
    Disengage()
end

local function OnDetailSetScale()
    if not state.engaged or state.writing then
        return
    end
    PlaceViewport()
end

local function InstallHooks()
    if state.installed then
        return true
    end
    local detail, button = WorldMapDetailFrame, WorldMapButton
    if not (WorldMapFrame and detail and button) or type(hooksecurefunc) ~= "function" then
        return false
    end

    hooksecurefunc(detail, "SetPoint", OnDetailSetPoint)
    hooksecurefunc(detail, "ClearAllPoints", OnDetailClearAllPoints)
    hooksecurefunc(detail, "SetAllPoints", OnDetailSetAllPoints)
    hooksecurefunc(detail, "SetScale", OnDetailSetScale)
    if type(WorldMapFrame_Update) == "function" then
        hooksecurefunc("WorldMapFrame_Update", OnWorldMapUpdate)
    end

    WorldMapFrame:HookScript("OnShow", function()
        UpdateWheel()
        ApplyPlayerArrowSize()
    end)
    WorldMapFrame:HookScript("OnHide", Disengage)

    button:HookScript("OnUpdate", function()
        if state.engaged then
            UpdateDrag()
            HideArrowOutsideView()
        end
    end)
    button:HookScript("OnMouseDown", OnMouseDown)
    button:HookScript("OnMouseUp", OnMouseUp)
    if button:GetScript("OnMouseWheel") then
        button:HookScript("OnMouseWheel", OnMouseWheel)
    else
        button:SetScript("OnMouseWheel", OnMouseWheel)
    end

    -- No reparenting in combat (WorldMapWindow parks the blob frame then).
    state.eventFrame = CreateFrame("Frame")
    state.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    state.eventFrame:SetScript("OnEvent", Disengage)

    state.installed = true
    return true
end

-- ---------------------------------------------------------------- lifecycle

function WorldMapZoom.OnEnable()
    if GetSettings().enabled == false then
        return
    end
    if not InstallHooks() then
        return
    end
    state.active = true
    ApplyPlayerArrowSize()
    if WorldMapFrame and WorldMapFrame:IsShown() then
        UpdateWheel()
    end
end

function WorldMapZoom.OnDisable()
    Disengage()
    state.active = false
    UpdateWheel()
    ApplyPlayerArrowSize()
end

function WorldMapZoom.CreateSettings(parent)
    local settings = GetSettings()

    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("World Map Zoom")

    local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetWidth(460)
    desc:SetJustifyH("LEFT")
    desc:SetText("Mouse wheel zooms the Mount Hyjal and Plaguelands continent maps at the cursor. "
        .. "Drag with the left mouse button to pan; wheel back out to see the whole map. "
        .. "Not available in combat. The player arrow size applies to every world map.")

    local yOffset = -76
    local enabledCb = addon:CreateCheckbox(parent)
    enabledCb:SetPoint("TOPLEFT", 16, yOffset)
    enabledCb.Text:SetText("Enable zoom on the custom continent maps")
    enabledCb:SetChecked(settings.enabled ~= false)
    enabledCb:SetScript("OnClick", function(self)
        addon:SetSetting("worldMapZoom.enabled", self:GetChecked() and true or false)
    end)
    yOffset = yOffset - 50

    local maxSlider = addon:CreateSlider(parent)
    maxSlider:SetPoint("TOPLEFT", 16, yOffset)
    maxSlider:SetWidth(200)
    maxSlider:SetMinMaxValues(2, MAX_ZOOM_LIMIT)
    maxSlider:SetValueStep(0.5)
    maxSlider.Text:SetText("Maximum zoom")
    maxSlider.Low:SetText("2x")
    maxSlider.High:SetText(MAX_ZOOM_LIMIT .. "x")
    maxSlider:SetValue(GetMaxZoom())
    if maxSlider.Value then
        maxSlider.Value:SetText(string.format("%.1fx", GetMaxZoom()))
    end
    maxSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value * 2 + 0.5) / 2
        addon:SetSetting("worldMapZoom.maxZoom", value)
        if self.Value then
            self.Value:SetText(string.format("%.1fx", value))
        end
        if state.engaged and state.zoom > value then
            SetZoom(value, true)
        end
    end)
    yOffset = yOffset - 50

    local arrowSlider = addon:CreateSlider(parent)
    arrowSlider:SetPoint("TOPLEFT", 16, yOffset)
    arrowSlider:SetWidth(200)
    arrowSlider:SetMinMaxValues(ARROW_SCALE_MIN, ARROW_SCALE_MAX)
    arrowSlider:SetValueStep(0.25)
    arrowSlider.Text:SetText("Player arrow size (all maps)")
    arrowSlider.Low:SetText(ARROW_SCALE_MIN .. "x")
    arrowSlider.High:SetText(ARROW_SCALE_MAX .. "x")
    arrowSlider:SetValue(GetArrowScale())
    if arrowSlider.Value then
        arrowSlider.Value:SetText(string.format("%.2fx", GetArrowScale()))
    end
    arrowSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value * 4 + 0.5) / 4
        addon:SetSetting("worldMapZoom.playerArrowScale", value)
        if self.Value then
            self.Value:SetText(string.format("%.2fx", value))
        end
        ApplyPlayerArrowSize()
    end)

    return yOffset - 50
end

WorldMapZoom.IsEngaged = function()
    return state.engaged
end
WorldMapZoom.GetZoom = function()
    return state.zoom, state.panX, state.panY
end

addon:RegisterModule("WorldMapZoom", WorldMapZoom)
