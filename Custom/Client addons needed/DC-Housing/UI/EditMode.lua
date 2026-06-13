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
local selection = nil  -- { lowguid, entry, name, x, y, z, o }

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
    captureFrame:Show()
end

function EditMode:StartGhostPlacement(entry)
    StartGhost("place", entry, nil, 0)
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
        DC.Protocol:MoveTo(selection.lowguid, x, y, z, yaw)
    end
end

-- ============================================================
-- Selection toolbar
-- ============================================================
local toolbar

local function CreateToolbar()
    toolbar = CreateFrame("Frame", "DCHousingEditToolbar", UIParent)
    toolbar:SetWidth(260)
    toolbar:SetHeight(150)
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
    toolbar.name:SetWidth(240)

    local function MakeButton(text, width, anchor, x, y, onClick)
        local button = CreateFrame("Button", nil, toolbar,
            "UIPanelButtonTemplate")
        button:SetWidth(width)
        button:SetHeight(20)
        button:SetPoint("TOPLEFT", anchor or toolbar, "TOPLEFT", x, y)
        button:SetText(text)
        button:SetScript("OnClick", onClick)
        return button
    end

    MakeButton(L.GRAB, 70, nil, 12, -30, function()
        if selection then
            StartGhost("move", selection.entry, selection.lowguid,
                selection.o or 0, selection.guidHex)
        end
    end)
    MakeButton(L.ROTATE, 160, nil, 88, -30, function()
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
        MakeButton(n[1], 52, nil, 12 + col * 58, -56 - rowIndex * 24,
            function()
                if selection then
                    DC.Protocol:Nudge(selection.lowguid, n[2], n[3], n[4],
                        n[5])
                end
            end)
    end

    MakeButton(L.REMOVE, 100, nil, 12, -110, function()
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
        guidHex = self._pendingGuidHex,
    }
    self._pendingGuidHex = nil

    if not toolbar then
        CreateToolbar()
    end
    toolbar.name:SetText(selection.name)
    toolbar:Show()

    -- Show the in-world gizmo around the selection (drag arrows to move,
    -- rings to rotate; one server commit per released drag).
    StopGizmo()
    StartGizmo(selection.guidHex)
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
