-- DC-Housing Edit Mode: retail-like decoration editor.
-- Ctrl+Click selects a placed decoration (cursor world pick -> server
-- ownership check). "Grab" / "Place at cursor" show a client-side ghost
-- model following the cursor's world hit; one server commit per click -
-- no live server dragging (each committed move costs DB writes and a
-- despawn/respawn, see GOMove).
local DC = DCHousing
local L = DCHousingLocale

DC.EditMode = DC.EditMode or {}
local EditMode = DC.EditMode

local active = false
local selection = nil  -- { lowguid, entry, name, x, y, z, o, scale, guidHex }

-- ============================================================
-- Snapping (Noggit-style grid + angle snap)
-- ============================================================
-- Both default to off; the toolbar cycles them. Snapping is applied at commit
-- time (and echoed client-side via the live-drag natives) so the in-world
-- gizmo stays smooth while dragging but lands on the grid when released.
EditMode.snapGrid = 0      -- world units per step; 0 = free
EditMode.snapAngle = 0     -- radians per step; 0 = free
EditMode.SNAP_GRID_CYCLE = { 0, 0.25, 0.5, 1.0, 2.0 }
EditMode.SNAP_ANGLE_CYCLE = { 0, math.rad(15), math.rad(45), math.rad(90) }

local function SnapCoord(v)
    local g = EditMode.snapGrid
    if g and g > 0 and type(v) == "number" then
        return math.floor(v / g + 0.5) * g
    end
    return v
end

local function SnapYaw(v)
    local a = EditMode.snapAngle
    if a and a > 0 and type(v) == "number" then
        return math.floor(v / a + 0.5) * a
    end
    return v
end

-- Resolved DLL natives (pcall-guarded, PingSystem pattern).
local function ResolveNative(...)
    for i = 1, select("#", ...) do
        local fn = _G[select(i, ...)]
        if type(fn) == "function" then
            return fn
        end
    end
    return nil
end

local getCursorWorldTarget = nil
local getViewportCursorCoords = nil
local convertToScreenSpace = nil
local setGobPosition = nil
local setGobFacing = nil
local getGobPosition = nil
local gizmoSetTarget = nil
local gizmoClear = nil
local gizmoUpdateCursor = nil
local gizmoBeginDrag = nil
local gizmoEndDrag = nil

local function EnsureNatives()
    if not getCursorWorldTarget then
        getCursorWorldTarget = ResolveNative("GetCursorWorldPingTarget",
            "C_Ping_GetCursorWorldTarget", "C_Ping_GetTargetWorldPing")
        getViewportCursorCoords = ResolveNative("GetViewportCursorCoords")
        if not getViewportCursorCoords then
            -- This DLL build does not export GetViewportCursorCoords, so derive
            -- the viewport-normalized cursor (0..1, top-left origin) in Lua from
            -- GetCursorPosition (physical px, bottom-left origin). Without this
            -- the world pick falls back to the stale last-click cache (cursor
            -- placement ignores the mouse) and the gizmo never gets hover/drag
            -- input (renders but cannot be grabbed).
            -- Formula mirrors DC-QOS PingSystem's proven GetViewportCursorCoords
            -- (the working ping feature uses it for GetCursorWorldPingTarget),
            -- so the convention matches the native exactly.
            getViewportCursorCoords = function()
                if type(GetCursorPosition) ~= "function" or not UIParent then
                    return nil
                end
                local cx, cy = GetCursorPosition()
                if type(cx) ~= "number" or type(cy) ~= "number" then
                    return nil
                end
                local scale = UIParent:GetEffectiveScale()
                if type(scale) ~= "number" or scale <= 0 then
                    return nil
                end
                cx = cx / scale
                cy = cy / scale
                local sw = UIParent:GetWidth()
                local sh = UIParent:GetHeight()
                if type(sw) ~= "number" or type(sh) ~= "number"
                    or sw <= 0 or sh <= 0 then
                    return nil
                end
                -- normX from left; normY flipped to top-origin (D3D9).
                return cx / sw, (sh - cy) / sh
            end
        end
        convertToScreenSpace = ResolveNative("ConvertCoordsToScreenSpace",
            "C_Ping_ConvertCoordsToScreenSpace")
        -- Live-drag natives (dusk-tswow port); when present the real
        -- object follows the cursor client-side instead of a ghost model.
        setGobPosition = ResolveNative("SetGobPositionByGUID",
            "C_Housing_SetGobPosition")
        setGobFacing = ResolveNative("SetGobFacingByGUID",
            "C_Housing_SetGobFacing")
        getGobPosition = ResolveNative("GetGobPositionByGUID",
            "C_Housing_GetGobPosition")
        -- In-world 3-axis gizmo (dusk-tswow Editor port).
        gizmoSetTarget = ResolveNative("HousingGizmoSetTarget")
        gizmoClear = ResolveNative("HousingGizmoClear")
        gizmoUpdateCursor = ResolveNative("HousingGizmoUpdateCursor")
        gizmoBeginDrag = ResolveNative("HousingGizmoBeginDrag")
        gizmoEndDrag = ResolveNative("HousingGizmoEndDrag")
    end
    return getCursorWorldTarget ~= nil
end

local function HasLiveDragNatives()
    return setGobPosition ~= nil and setGobFacing ~= nil
end

local function HasGizmoNatives()
    return gizmoSetTarget ~= nil and gizmoUpdateCursor ~= nil
        and gizmoBeginDrag ~= nil and gizmoEndDrag ~= nil
end

-- Returns guid, targetType, worldX, worldY, worldZ (or nil).
local function PickCursorWorld()
    if not EnsureNatives() then
        return nil
    end

    local normX, normY
    if getViewportCursorCoords then
        local ok, nx, ny = pcall(getViewportCursorCoords)
        if ok then
            normX, normY = nx, ny
        end
    end

    local ok, guid, targetType, _, _, _, worldX, worldY, worldZ =
        pcall(getCursorWorldTarget, normX, normY)
    if not ok or type(worldX) ~= "number" then
        return nil
    end
    return guid, targetType, worldX, worldY, worldZ
end

-- ============================================================
-- Ghost placement / move
-- ============================================================
local ghost = {
    mode = nil,        -- "place" or "move"
    entry = nil,
    lowguid = nil,
    liveGuid = nil,    -- hex GUID when live-dragging the real object
    origin = nil,      -- { x, y, z, o } to restore on cancel
    facing = 0,
    zOffset = 0,
    worldX = nil, worldY = nil, worldZ = nil,
}

local captureFrame
local ghostModel

local function EndGhost(cancelled)
    if cancelled and ghost.liveGuid and ghost.origin then
        pcall(setGobPosition, ghost.liveGuid, ghost.origin.x,
            ghost.origin.y, ghost.origin.z)
        pcall(setGobFacing, ghost.liveGuid, ghost.origin.o or 0)
    end

    ghost.mode = nil
    ghost.liveGuid = nil
    ghost.origin = nil
    if captureFrame then
        captureFrame:Hide()
    end
    if ghostModel then
        ghostModel:Hide()
    end

    -- Restore the catalog's 3D preview that StartGhostPlacement hid.
    if DC.Catalog and DC.Catalog.OnPlacementEnded then
        DC.Catalog:OnPlacementEnded()
    end
end

local function CommitGhost()
    if not ghost.worldX then
        return
    end

    local z = ghost.worldZ + ghost.zOffset
    if ghost.mode == "place" and ghost.entry then
        DC.Protocol:Place(ghost.entry, ghost.worldX, ghost.worldY, z,
            ghost.facing)
    elseif ghost.mode == "move" and ghost.lowguid then
        DC.Protocol:MoveTo(ghost.lowguid, ghost.worldX, ghost.worldY, z,
            ghost.facing)
    end
    EndGhost(false)
end

local function UpdateGhost()
    local _, _, worldX, worldY, worldZ = PickCursorWorld()
    if not worldX then
        ghostModel:Hide()
        ghost.worldX = nil
        return
    end

    ghost.worldX, ghost.worldY, ghost.worldZ = worldX, worldY, worldZ

    -- Live mode: relocate the real gameobject client-side (dusk port);
    -- the server commit on click makes it authoritative.
    if ghost.liveGuid then
        pcall(setGobPosition, ghost.liveGuid, worldX, worldY,
            worldZ + ghost.zOffset)
        pcall(setGobFacing, ghost.liveGuid, ghost.facing)
        return
    end

    if not convertToScreenSpace then
        return
    end

    local ok, screenX, screenY = pcall(convertToScreenSpace, worldX, worldY,
        worldZ + ghost.zOffset)
    if not ok or type(screenX) ~= "number" then
        ghostModel:Hide()
        return
    end

    local scale = UIParent:GetEffectiveScale()
    ghostModel:ClearAllPoints()
    ghostModel:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
        screenX / scale, screenY / scale)
    ghostModel:Show()
    pcall(ghostModel.SetFacing, ghostModel, ghost.facing)
end

local function CreateGhostFrames()
    captureFrame = CreateFrame("Frame", "DCHousingGhostCapture", UIParent)
    captureFrame:SetFrameStrata("FULLSCREEN")
    captureFrame:SetAllPoints(UIParent)
    captureFrame:EnableMouse(true)
    captureFrame:EnableMouseWheel(true)
    captureFrame:Hide()

    captureFrame.hint = captureFrame:CreateFontString(nil, "OVERLAY",
        "GameFontNormal")
    captureFrame.hint:SetPoint("TOP", 0, -120)
    captureFrame.hint:SetText(L.GHOST_HINT)

    captureFrame:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            CommitGhost()
        else
            EndGhost(true)
        end
    end)
    captureFrame:SetScript("OnMouseWheel", function(_, delta)
        if IsShiftKeyDown() then
            ghost.zOffset = ghost.zOffset + delta * 0.25
        else
            ghost.facing = ghost.facing + delta * 0.1963 -- ~11.25 degrees
        end
    end)
    captureFrame:SetScript("OnUpdate", function(self, elapsed)
        self._throttle = (self._throttle or 0) + (elapsed or 0)
        if self._throttle < 0.03 then
            return
        end
        self._throttle = 0
        UpdateGhost()
    end)

    ghostModel = CreateFrame("Model", "DCHousingGhostModel", captureFrame)
    ghostModel:SetWidth(220)
    ghostModel:SetHeight(220)
    ghostModel:SetAlpha(0.65)
    ghostModel:Hide()
end

local function StartGhost(mode, entry, lowguid, initialFacing, liveGuid)
    if not EnsureNatives() then
        DC:Print("|cffff0000Cursor world picking unavailable (DLL too old).|r")
        return
    end

    if not captureFrame then
        CreateGhostFrames()
    end

    local item = entry and DC:GetItem(entry)
    if item and not item.enabled then
        DC:Print(L.NOT_ENABLED)
        return
    end

    ghost.mode = mode
    ghost.entry = entry
    ghost.lowguid = lowguid
    ghost.facing = initialFacing or 0
    ghost.zOffset = 0
    ghost.worldX = nil
    ghost.liveGuid = nil
    ghost.origin = nil

    -- Prefer live drag of the real object when moving and the DLL natives
    -- exist; fall back to the screen-projected ghost model otherwise.
    if mode == "move" and liveGuid and HasLiveDragNatives() then
        local origin
        if getGobPosition then
            local ok, x, y, z, o = pcall(getGobPosition, liveGuid)
            if ok and type(x) == "number" then
                origin = { x = x, y = y, z = z, o = o }
            end
        end
        if not origin and selection and selection.x then
            origin = { x = selection.x, y = selection.y, z = selection.z,
                o = selection.o }
        end
        if origin then
            ghost.liveGuid = liveGuid
            ghost.origin = origin
            ghost.facing = origin.o or initialFacing or 0
        end
    end

    ghostModel:ClearModel()
    if item and not ghost.liveGuid then
        pcall(ghostModel.SetModel, ghostModel, item.path)
    end

    -- Hide the catalog's redundant 3D preview now that a ghost is truly
    -- starting (restored by EndGhost -> Catalog:OnPlacementEnded). Doing it
    -- here, after every early-return above, avoids leaving the preview stuck
    -- hidden when StartGhost bails (no cursor natives / disabled item).
    if DC.Catalog and DC.Catalog.HidePreview then
        DC.Catalog:HidePreview()
    end
    captureFrame:Show()
end

function EditMode:StartGhostPlacement(entry)
    StartGhost("place", entry, nil, 0)
end

-- Exposed so other modules (Protocol place result) can avoid toggling edit
-- mode off when it is already on.
function EditMode:IsActive()
    return active
end

-- Auto-select a just-placed object by its (server-provided) full client GUID,
-- routing through the existing Select -> OnSelectResult path so the toolbar and
-- in-world gizmo appear without the player having to Ctrl+Click it.
--
-- SMSG_PLACE_RESULT can arrive before the client has loaded the new gameobject
-- (its spawn packet may still be in flight), so a single Select can miss
-- server-side resolve or client-side gizmo attach. Retry on a short OnUpdate
-- timer (3.3.5a has no C_Timer) until the selection lands or we give up.
-- _pendingGuidHex must be re-armed before every Select because OnSelectResult
-- consumes it and the select result never echoes the guid back.
local selectRetry
function EditMode:AutoSelect(guidHex)
    if not guidHex then
        return
    end
    if not selectRetry then
        selectRetry = CreateFrame("Frame")
        selectRetry:Hide()
        selectRetry:SetScript("OnUpdate", function(self, elapsed)
            self._t = (self._t or 0) + (elapsed or 0)
            if self._t < 0.25 then -- ~250ms between tries
                return
            end
            self._t = 0
            -- Success: a live selection now matches the target guid.
            if selection and selection.guidHex == self._guid then
                self:Hide()
                return
            end
            self._tries = (self._tries or 0) + 1
            if self._tries > 8 then -- ~2s budget, then give up
                self:Hide()
                return
            end
            EditMode._pendingGuidHex = self._guid
            DC.Protocol:Select(self._guid)
        end)
    end
    selectRetry._guid = guidHex
    selectRetry._t = 0
    selectRetry._tries = 0
    -- Fire one attempt immediately; the ticker retries if it did not land.
    EditMode._pendingGuidHex = guidHex
    DC.Protocol:Select(guidHex)
    selectRetry:Show()
end

-- ============================================================
-- In-world gizmo (3-axis arrows + rotation rings, native render)
-- ============================================================
local gizmo = {
    active = false,
    hoverAxis = nil,
    dragging = false,
}

local gizmoTicker

local function StopGizmo()
    gizmo.active = false
    gizmo.hoverAxis = nil
    gizmo.dragging = false
    if gizmoClear then
        pcall(gizmoClear)
    end
    if gizmoTicker then
        gizmoTicker:Hide()
    end
end

local function StartGizmo(guidHex)
    -- The auto-select-after-place path reaches here without ever going through
    -- PickCursorWorld/StartGhost, which are the only other callers that resolve
    -- the DLL natives. Resolve them here too (idempotent) so HasGizmoNatives()
    -- reports correctly instead of falsely claiming the client lacks them.
    EnsureNatives()
    if not HasGizmoNatives() or not guidHex then
        return false
    end

    local ok, shown = pcall(gizmoSetTarget, guidHex)
    if not ok or not shown then
        return false
    end

    if not gizmoTicker then
        gizmoTicker = CreateFrame("Frame")
        gizmoTicker:SetScript("OnUpdate", function(self, elapsed)
            self._throttle = (self._throttle or 0) + (elapsed or 0)
            if self._throttle < 0.02 then
                return
            end
            self._throttle = 0

            if not gizmo.active then
                return
            end

            local normX, normY
            if getViewportCursorCoords then
                local okCursor, nx, ny = pcall(getViewportCursorCoords)
                if okCursor then
                    normX, normY = nx, ny
                end
            end
            if not normX then
                return
            end

            local okUpdate, state, axis = pcall(gizmoUpdateCursor,
                normX, normY)
            if okUpdate then
                gizmo.hoverAxis = (state == "hover" or state == "drag")
                    and axis or nil
            end
        end)
    end

    gizmo.active = true
    gizmo.hoverAxis = nil
    gizmo.dragging = false
    gizmoTicker:Show()
    return true
end

local function CommitGizmoDrag()
    if not gizmo.dragging then
        return
    end
    gizmo.dragging = false

    local ok, wasDragging, x, y, z, yaw = pcall(gizmoEndDrag)
    if ok and wasDragging and selection and type(x) == "number" then
        -- Snap the released transform to the grid/angle when enabled, and echo
        -- it client-side so the object visibly lands on the grid before the
        -- server's authoritative move arrives.
        if EditMode.snapGrid > 0 or EditMode.snapAngle > 0 then
            x, y, z, yaw = SnapCoord(x), SnapCoord(y), SnapCoord(z),
                SnapYaw(yaw)
            if selection.guidHex and setGobPosition then
                pcall(setGobPosition, selection.guidHex, x, y, z)
                pcall(setGobFacing, selection.guidHex, yaw or 0)
            end
        end
        -- A plain click on an axis (no real drag) still reports wasDragging,
        -- but nothing moved. Skip those no-op commits so clicking the gizmo
        -- doesn't spam the server's move rate limit; only persist real moves.
        -- BUT only suppress when we actually have a baseline: SMSG_SELECT_RESULT
        -- omits x/y/z/o when the server could not resolve the GO on the grid
        -- (e.g. the auto-select-after-place race), leaving selection.* nil --
        -- in that case always send, or the first real drag would be dropped.
        local hasBaseline = selection.x and selection.y and selection.z
            and selection.o
        local moved = (not hasBaseline)
            or math.abs(x - selection.x) > 0.05
            or math.abs(y - selection.y) > 0.05
            or math.abs(z - selection.z) > 0.05
            or math.abs((yaw or 0) - selection.o) > 0.01
        if moved then
            DC.Protocol:MoveTo(selection.lowguid, x, y, z, yaw)
            -- Track the new position so the next commit compares correctly
            -- and a rejected/coalesced server move stays consistent.
            selection.x, selection.y, selection.z, selection.o =
                x, y, z, (yaw or 0)
            EditMode:RefreshPanel()
        end
    end
end

-- Re-attach the gizmo after a server move respawned the object under a new
-- GUID (GOMove deletes + recreates it, so the old target is dead). Updates the
-- live selection's guid and re-arms the native gizmo, retrying because the new
-- object's client-side spawn packet may still be in flight.
local retargetTicker
function EditMode:OnMoved(lowguid, guidHex)
    if not selection or not guidHex then
        return
    end
    if selection.lowguid ~= lowguid then
        return  -- a different object moved (e.g. catalog manage UI)
    end
    if guidHex == selection.guidHex then
        return  -- GUID unchanged; nothing to re-attach
    end

    selection.guidHex = guidHex

    -- One immediate attempt; succeed -> done, else retry on a short ticker.
    StopGizmo()
    if StartGizmo(guidHex) then
        return
    end

    if not retargetTicker then
        retargetTicker = CreateFrame("Frame")
        retargetTicker:Hide()
        retargetTicker:SetScript("OnUpdate", function(self, elapsed)
            self._t = (self._t or 0) + (elapsed or 0)
            if self._t < 0.1 then
                return
            end
            self._t = 0
            StopGizmo()
            if StartGizmo(self._guid) then
                self:Hide()
                return
            end
            self._tries = (self._tries or 0) + 1
            if self._tries > 20 then  -- ~2s budget, then give up
                self:Hide()
            end
        end)
    end
    retargetTicker._guid = guidHex
    retargetTicker._t = 0
    retargetTicker._tries = 0
    retargetTicker:Show()
end

-- Select a placed decoration by spawn id (the manage list knows the lowguid,
-- not the live client GUID). Ensures edit mode is on so the gizmo's world
-- input hooks are live; the server returns the GUID and OnSelectResult arms
-- the gizmo.
function EditMode:SelectPlaced(lowguid)
    if not lowguid then
        return
    end
    if self.IsActive and not self:IsActive() then
        self:Toggle()
    end
    self._pendingGuidHex = nil
    DC.Protocol:SelectByLowguid(lowguid)
end

-- Manually (re)attach the in-world gizmo to the current selection. Bound to the
-- toolbar's "Gizmo" button so it can always be brought back if it was dropped
-- (e.g. after a respawn the auto-retarget missed, or the user wants it back).
function EditMode:ArmGizmo()
    if not selection or not selection.guidHex then
        DC:Print("Select a decoration first (Ctrl+Click it, or pick it in "
            .. "the manage list).")
        return
    end
    if self.IsActive and not self:IsActive() then
        self:Toggle()
    end
    StopGizmo()
    if not StartGizmo(selection.guidHex) then
        DC:Print("|cffffcc00Gizmo could not attach to this object.|r")
    end
end

-- ============================================================
-- Selection toolbar
-- ============================================================
local toolbar

-- Cycle a snap setting to the next value in its list (wraps).
local function NextSnap(list, current)
    for i, val in ipairs(list) do
        if math.abs(val - current) < 1e-6 then
            return list[(i % #list) + 1]
        end
    end
    return list[1]
end

local function GridLabel()
    local v = EditMode.snapGrid
    return v > 0 and ("Grid: " .. tostring(v)) or "Grid: Off"
end

local function AngleLabel()
    local v = EditMode.snapAngle
    return v > 0 and string.format("Angle: %d\194\176",
        math.floor(math.deg(v) + 0.5)) or "Angle: Off"
end

-- Push a new scale to the server and reflect it locally (clamped to the same
-- 0.2..5.0 range the server enforces).
local function ApplyScale(newScale)
    if not selection then
        return
    end
    newScale = math.max(0.2, math.min(5.0, newScale))
    selection.scale = newScale
    DC.Protocol:Scale(selection.lowguid, newScale)
    EditMode:RefreshPanel()
end

local function CreateToolbar()
    toolbar = CreateFrame("Frame", "DCHousingEditToolbar", UIParent)
    toolbar:SetWidth(280)
    toolbar:SetHeight(286)
    toolbar:SetPoint("RIGHT", -40, 60)
    toolbar:SetMovable(true)
    toolbar:EnableMouse(true)
    toolbar:RegisterForDrag("LeftButton")
    toolbar:SetScript("OnDragStart", toolbar.StartMoving)
    toolbar:SetScript("OnDragStop", toolbar.StopMovingOrSizing)
    toolbar:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    toolbar:Hide()

    toolbar.name = toolbar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    toolbar.name:SetPoint("TOP", 0, -10)
    toolbar.name:SetWidth(260)

    local function MakeButton(text, width, x, y, onClick)
        local button = CreateFrame("Button", nil, toolbar,
            "UIPanelButtonTemplate")
        button:SetWidth(width)
        button:SetHeight(20)
        button:SetPoint("TOPLEFT", toolbar, "TOPLEFT", x, y)
        button:SetText(text)
        button:SetScript("OnClick", onClick)
        return button
    end

    MakeButton(L.GRAB, 80, 12, -30, function()
        if selection then
            StartGhost("move", selection.entry, selection.lowguid,
                selection.o or 0, selection.guidHex)
        end
    end)
    MakeButton(L.ROTATE, 170, 98, -30, function()
        if selection then
            DC.Protocol:Rotate(selection.lowguid)
        end
    end)

    -- Nudge grid (GOMove-style precise adjustments)
    local nudges = {
        { "X+", 0.5, 0, 0, 0 }, { "X-", -0.5, 0, 0, 0 },
        { "Y+", 0, 0.5, 0, 0 }, { "Y-", 0, -0.5, 0, 0 },
        { "Z+", 0, 0, 0.5, 0 }, { "Z-", 0, 0, -0.5, 0 },
        { "R+", 0, 0, 0, 0.2618 }, { "R-", 0, 0, 0, -0.2618 },
    }
    for i, n in ipairs(nudges) do
        local col = math.fmod(i - 1, 4)
        local rowIndex = math.floor((i - 1) / 4)
        MakeButton(n[1], 58, 12 + col * 64, -56 - rowIndex * 24,
            function()
                if selection then
                    DC.Protocol:Nudge(selection.lowguid, n[2], n[3], n[4],
                        n[5])
                end
            end)
    end

    -- Snap toggles (apply to the in-world gizmo's released transform).
    toolbar.snapGridBtn = MakeButton(GridLabel(), 124, 12, -106, function()
        EditMode.snapGrid = NextSnap(EditMode.SNAP_GRID_CYCLE,
            EditMode.snapGrid)
        toolbar.snapGridBtn:SetText(GridLabel())
    end)
    toolbar.snapAngleBtn = MakeButton(AngleLabel(), 124, 144, -106, function()
        EditMode.snapAngle = NextSnap(EditMode.SNAP_ANGLE_CYCLE,
            EditMode.snapAngle)
        toolbar.snapAngleBtn:SetText(AngleLabel())
    end)

    -- Scale row: [-] value [+]
    local scaleLabel = toolbar:CreateFontString(nil, "OVERLAY",
        "GameFontNormalSmall")
    scaleLabel:SetPoint("TOPLEFT", 12, -134)
    scaleLabel:SetText("Scale")
    MakeButton("-", 24, 60, -132, function()
        if selection then
            ApplyScale((selection.scale or 1) - 0.1)
        end
    end)
    toolbar.scaleValue = toolbar:CreateFontString(nil, "OVERLAY",
        "GameFontHighlight")
    toolbar.scaleValue:SetPoint("LEFT", toolbar, "TOPLEFT", 88, -142)
    toolbar.scaleValue:SetWidth(80)
    toolbar.scaleValue:SetText("1.00")
    MakeButton("+", 24, 172, -132, function()
        if selection then
            ApplyScale((selection.scale or 1) + 0.1)
        end
    end)
    MakeButton("Reset", 60, 200, -132, function()
        if selection then
            ApplyScale(1.0)
        end
    end)

    -- Numeric position/yaw entry. Editing is opt-in: typing then Enter (or
    -- "Set") commits an exact transform; values otherwise just mirror the live
    -- selection.
    local fieldLabels = { "X", "Y", "Z", "Yaw" }
    toolbar.fields = {}
    for i, lbl in ipairs(fieldLabels) do
        local x = 12 + (i - 1) * 64
        local cap = toolbar:CreateFontString(nil, "OVERLAY",
            "GameFontNormalSmall")
        cap:SetPoint("TOPLEFT", x + 2, -162)
        cap:SetText(lbl)

        local edit = CreateFrame("EditBox", nil, toolbar, "InputBoxTemplate")
        edit:SetWidth(54)
        edit:SetHeight(18)
        edit:SetPoint("TOPLEFT", x + 6, -176)
        edit:SetAutoFocus(false)
        edit:SetNumeric(false)
        edit:SetScript("OnEnterPressed", function(self)
            EditMode:ApplyNumericEntry()
            self:ClearFocus()
        end)
        edit:SetScript("OnEscapePressed", function(self)
            EditMode:RefreshPanel()
            self:ClearFocus()
        end)
        toolbar.fields[i] = edit
    end

    MakeButton("Set", 70, 12, -204, function()
        EditMode:ApplyNumericEntry()
    end)
    MakeButton("Gizmo", 64, 88, -204, function()
        EditMode:ArmGizmo()
    end)
    MakeButton(L.REMOVE, 88, 158, -204, function()
        if selection then
            StaticPopup_Show("DCHOUSING_REMOVE", selection.name or "?")
        end
    end)

    StaticPopupDialogs["DCHOUSING_REMOVE"] = {
        text = L.CONFIRM_REMOVE,
        button1 = YES,
        button2 = NO,
        OnAccept = function()
            if selection then
                DC.Protocol:Remove(selection.lowguid)
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
end

-- Repopulate the numeric/scale panel from the live selection.
function EditMode:RefreshPanel()
    if not toolbar or not selection then
        return
    end
    if toolbar.scaleValue then
        toolbar.scaleValue:SetText(string.format("%.2f",
            selection.scale or 1))
    end
    if toolbar.fields then
        local vals = { selection.x, selection.y, selection.z, selection.o }
        for i, edit in ipairs(toolbar.fields) do
            -- Don't stomp a value the user is actively typing.
            if not edit:HasFocus() then
                local v = vals[i]
                edit:SetText(type(v) == "number"
                    and string.format("%.3f", v) or "")
            end
        end
    end
end

-- Commit the numeric edit boxes as an exact move (snapping still applies).
function EditMode:ApplyNumericEntry()
    if not selection or not toolbar or not toolbar.fields then
        return
    end
    local x = tonumber(toolbar.fields[1]:GetText())
    local y = tonumber(toolbar.fields[2]:GetText())
    local z = tonumber(toolbar.fields[3]:GetText())
    local o = tonumber(toolbar.fields[4]:GetText())
    if not (x and y and z) then
        DC:Print("|cffff0000Enter valid numbers for X, Y and Z.|r")
        return
    end
    o = o or selection.o or 0
    x, y, z, o = SnapCoord(x), SnapCoord(y), SnapCoord(z), SnapYaw(o)

    if selection.guidHex and setGobPosition then
        pcall(setGobPosition, selection.guidHex, x, y, z)
        pcall(setGobFacing, selection.guidHex, o)
    end
    DC.Protocol:MoveTo(selection.lowguid, x, y, z, o)
    selection.x, selection.y, selection.z, selection.o = x, y, z, o
    self:RefreshPanel()
end

function EditMode:OnSelectResult(data)
    if not data.success then
        DC:Print("|cffff0000"
            .. (data.error or "Selection failed.") .. "|r")
        return
    end

    selection = {
        lowguid = tonumber(data.lowguid),
        entry = tonumber(data.entry),
        name = data.name or ("Entry " .. tostring(data.entry)),
        x = tonumber(data.x), y = tonumber(data.y), z = tonumber(data.z),
        o = tonumber(data.o),
        scale = tonumber(data.scale) or 1,
        -- Prefer the server-echoed GUID (always present now); fall back to the
        -- cursor-pick GUID the client armed the request with.
        guidHex = data.guid or self._pendingGuidHex,
    }
    self._pendingGuidHex = nil

    if not toolbar then
        CreateToolbar()
    end
    toolbar.name:SetText(selection.name)
    toolbar:Show()
    self:RefreshPanel()

    -- Show the in-world gizmo around the selection (drag arrows to move,
    -- rings to rotate; one server commit per released drag). The arrows are
    -- drawn by a DLL world-render hook (HousingGizmo* natives), so if the
    -- running client DLL predates them the gizmo silently won't appear — tell
    -- the user once so it isn't mistaken for a broken selection.
    StopGizmo()
    local gizmoShown = StartGizmo(selection.guidHex)
    if not gizmoShown and not self._gizmoWarned then
        self._gizmoWarned = true
        if not HasGizmoNatives() then
            DC:Print("|cffffcc00In-world gizmo unavailable|r - your client "
                .. "lacks the HousingGizmo natives (rebuild/redeploy "
                .. "WotLKExtensions.dll). Use the toolbar's Grab / Nudge / "
                .. "Rotate buttons instead.")
        else
            DC:Print("|cffffcc00Gizmo could not attach to this object.|r "
                .. "Use the toolbar instead.")
        end
    end
end

function EditMode:ClearSelection()
    selection = nil
    StopGizmo()
    if toolbar then
        toolbar:Hide()
    end
end

-- ============================================================
-- Edit mode toggle + Ctrl+Click selection
-- ============================================================
local hooked = false

local function OnWorldMouseDown()
    if not active then
        return
    end

    -- Plain click on a hovered gizmo axis starts a native drag.
    if gizmo.active and gizmo.hoverAxis and not IsControlKeyDown() then
        local ok, started = pcall(gizmoBeginDrag)
        if ok and started then
            gizmo.dragging = true
        end
        return
    end

    if not IsControlKeyDown() then
        return
    end

    local guid, targetType = PickCursorWorld()
    if guid and targetType == "gameobject" then
        EditMode._pendingGuidHex = guid
        DC.Protocol:Select(guid)
    end
end

function EditMode:Toggle()
    active = not active

    if active then
        if not hooked then
            WorldFrame:HookScript("OnMouseDown", function(_, button)
                if button == "LeftButton" then
                    OnWorldMouseDown()
                end
            end)
            WorldFrame:HookScript("OnMouseUp", function(_, button)
                if button == "LeftButton" then
                    CommitGizmoDrag()
                end
            end)
            hooked = true
        end
        DC:Print(L.SELECT_HINT)
    else
        self:ClearSelection()
        EndGhost(true)
        DC:Print(L.EDIT_MODE .. ": off")
    end
end
