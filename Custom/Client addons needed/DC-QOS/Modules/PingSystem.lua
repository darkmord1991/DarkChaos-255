-- ============================================================
-- DC-QoS: Ping System Module
-- ============================================================
-- On-screen player-display ping markers.
-- This module is intentionally separate from map entities such
-- as death markers and hotspot pins.
-- ============================================================

local addon = DCQOS

local PingSystem = {
    displayName = "Ping System",
    settingKey = "pingSystem",
    icon = "Interface\\Icons\\Ability_Hunter_MasterMarksman",
    defaults = {
        pingSystem = {
            enabled = true,
            allowProtocolPings = true,
            enableKeybinds = true,
            enableRadialMenu = true,
            showSource = true,
            showDistance = true,
            playSound = true,
            markerScale = 1.0,
            lifetimeSeconds = 3.0,
            ringRadius = 210,
            distanceProjection = 0.30,
            quickPingDistance = 700,
            radialMenuSize = 220,
            radialMenuDeadzone = 28,
            radialHoldDelay = 0.15,
            centerYOffset = -96,
            maxActivePings = 6,
            throttleMs = 120,
        },
    },
}

local state = {
    root = nil,
    pool = {},
    active = {},
    lastPingAt = 0,
    protocolHooked = false,
    protocolModule = nil,
    protocolOpcode = nil,
    protocolHandler = nil,
    slashRegistered = false,
    featureEventBridgeInstalled = false,
    menuFrame = nil,
    menuWheel = nil,
    menuEntries = nil,
    menuSelectionType = nil,
    menuHoldTimer = nil,
}

local mapDataLib = nil

local math_abs = math.abs
local math_atan2 = math.atan2
local math_cos = math.cos
local math_deg = math.deg
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_pi = math.pi
local math_rad = math.rad
local math_sin = math.sin
local math_sqrt = math.sqrt

local PING_TEXTURE_ROOT = "Interface\\AddOns\\DC-QOS\\Textures\\PingSystem\\Atlas"

local PING_ATLASES = {
    ["Ping_Marker_Icon_Attack"] = { texture = PING_TEXTURE_ROOT .. "\\Ping_Marker_Icon_Attack" },
    ["Ping_Marker_Icon_Warning"] = { texture = PING_TEXTURE_ROOT .. "\\Ping_Marker_Icon_Warning" },
    ["Ping_Marker_Icon_Assist"] = { texture = PING_TEXTURE_ROOT .. "\\Ping_Marker_Icon_Assist" },
    ["Ping_Marker_Icon_OnMyWay"] = { texture = PING_TEXTURE_ROOT .. "\\Ping_Marker_Icon_OnMyWay" },
    ["Ping_Marker_Icon_Danger"] = { texture = PING_TEXTURE_ROOT .. "\\Ping_Marker_Icon_Danger" },
    ["Ping_Marker_Icon_Info"] = { texture = PING_TEXTURE_ROOT .. "\\Ping_Marker_Icon_Info" },
    ["Ping_Marker_Flipbook_Default"] = { texture = PING_TEXTURE_ROOT .. "\\Ping_Marker_Flipbook_Default" },
    ["Ping_GroundMarker_BG_Default"] = { texture = PING_TEXTURE_ROOT .. "\\Ping_GroundMarker_BG_Default" },
    ["Ping_GroundMarker_Pin_Default"] = { texture = PING_TEXTURE_ROOT .. "\\Ping_GroundMarker_Pin_Default" },
    ["Ping_GroundMarker_Stroke_Default"] = { texture = PING_TEXTURE_ROOT .. "\\Ping_GroundMarker_Stroke_Default" },
    ["Ping_UnitMarker_BG_Default"] = { texture = PING_TEXTURE_ROOT .. "\\Ping_UnitMarker_BG_Default" },
    ["Ping_OVMarker_Pointer_Default"] = { texture = PING_TEXTURE_ROOT .. "\\Ping_OVMarker_Pointer_Default" },
    ["Ping_OVMarker_Pointer_BG"] = { texture = PING_TEXTURE_ROOT .. "\\Ping_OVMarker_Pointer_BG" },
    ["Ping_SpotGlw_Default_In"] = { texture = PING_TEXTURE_ROOT .. "\\Ping_SpotGlw_Default_In" },
    ["Ping_SpotGlw_Default_Out"] = { texture = PING_TEXTURE_ROOT .. "\\Ping_SpotGlw_Default_Out" },
    ["Ping_Wheel_Icon_Default"] = { texture = PING_TEXTURE_ROOT .. "\\Ping_Wheel_Icon_Default" },
}

local PING_STYLES = {
    attack = {
        label = "Attack",
        r = 1.00,
        g = 0.25,
        b = 0.25,
        iconAtlas = "Ping_Marker_Icon_Attack",
        sound = "RaidWarning",
    },
    warning = {
        label = "Warning",
        r = 1.00,
        g = 0.82,
        b = 0.15,
        iconAtlas = "Ping_Marker_Icon_Warning",
        sound = "RaidWarning",
    },
    assist = {
        label = "Assist",
        r = 0.25,
        g = 0.85,
        b = 1.00,
        iconAtlas = "Ping_Marker_Icon_Assist",
        sound = "MapPing",
    },
    onmyway = {
        label = "On My Way",
        r = 0.25,
        g = 1.00,
        b = 0.25,
        iconAtlas = "Ping_Marker_Icon_OnMyWay",
        sound = "MapPing",
    },
    danger = {
        label = "Danger",
        r = 1.00,
        g = 0.20,
        b = 0.20,
        iconAtlas = "Ping_Marker_Icon_Danger",
        sound = "RaidWarning",
    },
    info = {
        label = "Ping",
        r = 1.00,
        g = 1.00,
        b = 1.00,
        iconAtlas = "Ping_Marker_Icon_Info",
        sound = "MapPing",
    },
}

local RADIAL_MENU_OPTIONS = {
    { type = "assist", angle = 90, offsetX = 0, offsetY = 74, label = "Assist" },
    { type = "danger", angle = 35, offsetX = 62, offsetY = 48, label = "Danger" },
    { type = "attack", angle = 0, offsetX = 76, offsetY = 0, label = "Attack" },
    { type = "warning", angle = -90, offsetX = 0, offsetY = -78, label = "Warning" },
    { type = "onmyway", angle = 180, offsetX = -76, offsetY = 0, label = "On My Way" },
}

local function ApplyAtlasTexture(texture, atlasName)
    local atlas = atlasName and PING_ATLASES[atlasName]
    if not atlas then
        return false
    end

    texture:SetTexture(atlas.texture)
    texture:SetTexCoord(atlas.left or 0, atlas.right or 1, atlas.top or 0, atlas.bottom or 1)
    return true
end

local function TrimWhitespace(text)
    if not text then
        return ""
    end

    text = tostring(text)
    text = text:gsub("^%s+", "")
    text = text:gsub("%s+$", "")
    return text
end

local function GetSettings()
    if addon and addon.settings and addon.settings.pingSystem then
        return addon.settings.pingSystem
    end

    return PingSystem.defaults.pingSystem
end

local function ExecuteBoundPingAction(action, pingType)
    if not addon or not addon.PingSystem then
        return
    end

    local settings = GetSettings()
    if settings and settings.enableKeybinds == false then
        return
    end

    if action == "clear" then
        addon.PingSystem:Clear()
        return
    end

    if action == "test" then
        addon.PingSystem:PushTestPing()
        return
    end

    addon.PingSystem:PushQuickPing(pingType or "warning")
end

_G.DCQOS_PING_TEST = function()
    ExecuteBoundPingAction("test")
end

_G.DCQOS_PING_CLEAR = function()
    ExecuteBoundPingAction("clear")
end

_G.DCQOS_PING_WARNING = function()
    ExecuteBoundPingAction("quick", "warning")
end

_G.DCQOS_PING_ATTACK = function()
    ExecuteBoundPingAction("quick", "attack")
end

_G.DCQOS_PING_ASSIST = function()
    ExecuteBoundPingAction("quick", "assist")
end

_G.DCQOS_PING_ONMYWAY = function()
    ExecuteBoundPingAction("quick", "onmyway")
end

_G.DCQOS_PING_DANGER = function()
    ExecuteBoundPingAction("quick", "danger")
end

_G.DCQOS_PING_INFO = function()
    ExecuteBoundPingAction("quick", "info")
end

local function CancelMenuHoldTimer()
    if not state.menuHoldTimer then
        return false
    end

    state.menuHoldTimer:Cancel()
    state.menuHoldTimer = nil
    return true
end

local function DetermineContextualQuickPingType()
    if type(UnitExists) ~= "function" or not UnitExists("mouseover") then
        return "warning"
    end

    if type(UnitIsUnit) == "function" and UnitIsUnit("mouseover", "player") then
        return "onmyway"
    end

    if type(UnitCanAttack) == "function" and UnitCanAttack("player", "mouseover") then
        return "attack"
    end

    if type(UnitIsFriend) == "function" and UnitIsFriend("player", "mouseover") then
        return "assist"
    end

    return "warning"
end

_G.DCQOS_PING_MENU = function(keyState)
    if not addon or not addon.PingSystem then
        return
    end

    local settings = GetSettings()
    if settings.enableKeybinds == false then
        return
    end

    if keyState == "up" then
        if CancelMenuHoldTimer() then
            addon.PingSystem:PushQuickPing(DetermineContextualQuickPingType(), {
                ignoreThrottle = false,
            })
            return
        end

        addon.PingSystem:CloseRadialMenu(true)
        return
    end

    CancelMenuHoldTimer()

    local holdDelay = tonumber(settings.radialHoldDelay) or 0.15
    if holdDelay < 0.05 then
        holdDelay = 0.05
    elseif holdDelay > 0.75 then
        holdDelay = 0.75
    end

    if not C_Timer or type(C_Timer.NewTimer) ~= "function" then
        addon.PingSystem:OpenRadialMenu()
        return
    end

    state.menuHoldTimer = C_Timer.NewTimer(holdDelay, function()
        state.menuHoldTimer = nil
        addon.PingSystem:OpenRadialMenu()
    end)

end

local function Clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function NormalizeRadians(angle)
    while angle > math_pi do
        angle = angle - (2 * math_pi)
    end
    while angle < -math_pi do
        angle = angle + (2 * math_pi)
    end
    return angle
end

local function Atan2(y, x)
    if math_atan2 then
        return math_atan2(y, x)
    end

    if x > 0 then
        return math.atan(y / x)
    end
    if x < 0 and y >= 0 then
        return math.atan(y / x) + math_pi
    end
    if x < 0 and y < 0 then
        return math.atan(y / x) - math_pi
    end
    if x == 0 and y > 0 then
        return math_pi * 0.5
    end
    if x == 0 and y < 0 then
        return -math_pi * 0.5
    end

    return 0
end

local function NormalizeCoord(value)
    if value == nil then
        return nil
    end

    local n = tonumber(value)
    if not n then
        return nil
    end

    if n > 1 then
        n = n / 100
    end

    if n < 0 or n > 1 then
        return nil
    end

    return n
end

local function SafeSetMapToCurrentZone()
    if type(SetMapToCurrentZone) ~= "function" then
        return
    end

    local worldMapShown = WorldMapFrame and WorldMapFrame.IsShown and WorldMapFrame:IsShown()
    if not worldMapShown then
        pcall(SetMapToCurrentZone)
    end
end

local function GetPlayerMapPositionSafe()
    local mapId

    if C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition then
        mapId = C_Map.GetBestMapForUnit("player")
        if mapId then
            local pos = C_Map.GetPlayerMapPosition(mapId, "player")
            if pos and pos.x and pos.y and pos.x > 0 and pos.y > 0 then
                return pos.x, pos.y, mapId
            end
        end
    end

    if type(GetPlayerMapPosition) == "function" then
        local x, y = GetPlayerMapPosition("player")
        if (not x or not y or x <= 0 or y <= 0) then
            SafeSetMapToCurrentZone()
            x, y = GetPlayerMapPosition("player")
        end

        if x and y and x > 0 and y > 0 then
            mapId = (type(GetCurrentMapAreaID) == "function") and GetCurrentMapAreaID() or nil
            return x, y, mapId
        end
    end

    return nil, nil, nil
end

local function GetCursorScreenOffsets()
    if type(GetCursorPosition) ~= "function" or not UIParent then
        return nil, nil
    end

    local cursorX, cursorY = GetCursorPosition()
    if not cursorX or not cursorY then
        return nil, nil
    end

    local scale = UIParent:GetEffectiveScale()
    if not scale or scale == 0 then
        return nil, nil
    end

    cursorX = cursorX / scale
    cursorY = cursorY / scale

    local centerX, centerY = UIParent:GetCenter()
    if not centerX or not centerY then
        centerX = (UIParent:GetWidth() or 0) * 0.5
        centerY = (UIParent:GetHeight() or 0) * 0.5
    end

    return cursorX - centerX, cursorY - centerY
end

local function GetMapDataLib()
    if mapDataLib ~= nil then
        return mapDataLib or nil
    end

    if type(LibStub) == "function" then
        mapDataLib = LibStub("LibMapData-1.0", true)
    else
        mapDataLib = false
    end

    return mapDataLib or nil
end

local function ComputeDistanceYards(mapId, x1, y1, x2, y2)
    local mapLib = GetMapDataLib()
    if mapLib and mapId and mapLib.MapArea then
        local floor = (type(GetCurrentMapDungeonLevel) == "function") and GetCurrentMapDungeonLevel() or 0
        local ok, width, height = pcall(mapLib.MapArea, mapLib, mapId, floor)
        if ok and width and height and width > 0 and height > 0 then
            local dx = (x2 - x1) * width
            local dy = (y2 - y1) * height
            return math_sqrt((dx * dx) + (dy * dy)), dx, dy
        end
    end

    -- Fallback approximation when map yard data is unavailable.
    local dx = (x2 - x1) * 10000
    local dy = (y2 - y1) * 10000
    return math_sqrt((dx * dx) + (dy * dy)), dx, dy
end

local function GetMapAreaYards(mapId)
    local mapLib = GetMapDataLib()
    if mapLib and mapId and mapLib.MapArea then
        local floor = (type(GetCurrentMapDungeonLevel) == "function") and GetCurrentMapDungeonLevel() or 0
        local ok, width, height = pcall(mapLib.MapArea, mapLib, mapId, floor)
        if ok and width and height and width > 0 and height > 0 then
            return width, height
        end
    end

    return 10000, 10000
end

local function ComputeRelativeHeading(facing, playerX, playerY, targetX, targetY, dxYards, dyYards)
    local dx = dxYards
    local dy = dyYards

    if type(dx) ~= "number" or type(dy) ~= "number" then
        dx = (targetX or 0) - (playerX or 0)
        dy = (targetY or 0) - (playerY or 0)
    end

    local direction = Atan2(-dx, dy)
    if direction > 0 then
        direction = (2 * math_pi) - direction
    else
        direction = -direction
    end

    local relative = NormalizeRadians(direction - (facing or 0))
    return relative
end

local function GetStyleForPingType(pingType)
    return PING_STYLES[pingType] or PING_STYLES.info
end

local function ApplyStyleIcon(texture, pingType)
    local style = GetStyleForPingType(pingType)
    if not ApplyAtlasTexture(texture, style.iconAtlas) then
        ApplyAtlasTexture(texture, "Ping_Marker_Icon_Info")
    end
end

local function NormalizePingType(value)
    local normalized = TrimWhitespace(value):lower()
    normalized = normalized:gsub("[%s_%-%./]", "")

    if normalized == "attack" then
        return "attack"
    end
    if normalized == "warning" then
        return "warning"
    end
    if normalized == "assist" or normalized == "help" then
        return "assist"
    end
    if normalized == "onmyway" or normalized == "omw" then
        return "onmyway"
    end
    if normalized == "danger" or normalized == "alertthreat" or normalized == "threat" then
        return "danger"
    end
    if normalized == "alertnotthreat" or normalized == "nothreat" or normalized == "info" or normalized == "ping" then
        return "info"
    end

    return "info"
end

local function NormalizePayload(payload)
    if type(payload) ~= "table" then
        return nil
    end

    local normalized = {}
    normalized.type = NormalizePingType(payload.type or payload.pingType or payload.kind or payload.subjectType)
    normalized.text = payload.text or payload.label or payload.message
    normalized.source = payload.source or payload.sender or payload.player or payload.author
    normalized.targetName = payload.targetName
    normalized.targetGuid = TrimWhitespace(payload.targetGuid or payload.targetGUID or payload.guid)
    normalized.targetType = TrimWhitespace(payload.targetType or payload.targetKind or payload.objectType):lower()
    normalized.duration = tonumber(payload.duration or payload.ttl or payload.timeToLive)
    normalized.mapId = tonumber(payload.mapId or payload.mapID or payload.uiMapID)
    normalized.x = NormalizeCoord(payload.x or payload.mapX or payload.nx)
    normalized.y = NormalizeCoord(payload.y or payload.mapY or payload.ny)
    normalized.relativeDegrees = tonumber(payload.relativeDegrees or payload.relativeDeg)
    normalized.relativeRadians = tonumber(payload.relativeRadians)
    normalized.bearingDegrees = tonumber(payload.bearingDegrees or payload.bearing)
    normalized.screenX = tonumber(payload.screenX or payload.screenOffsetX)
    normalized.screenY = tonumber(payload.screenY or payload.screenOffsetY)
    normalized.distance = tonumber(payload.distance or payload.distanceYards)
    normalized.worldX = tonumber(payload.worldX)
    normalized.worldY = tonumber(payload.worldY)
    normalized.worldZ = tonumber(payload.worldZ)
    normalized.sound = payload.sound

    if normalized.targetGuid == "" then
        normalized.targetGuid = nil
    end

    if normalized.targetType == "" then
        normalized.targetType = nil
    end

    return normalized
end

local function ResolveCursorWorldPingTarget()
    local resolver = nil

    if type(GetCursorWorldPingTarget) == "function" then
        resolver = GetCursorWorldPingTarget
    elseif type(C_Ping_GetCursorWorldTarget) == "function" then
        resolver = C_Ping_GetCursorWorldTarget
    elseif type(C_Ping_GetTargetWorldPing) == "function" then
        resolver = C_Ping_GetTargetWorldPing
    end

    if not resolver then
        return nil
    end

    local ok, guid, targetType, mapId, mapX, mapY, worldX, worldY, worldZ = pcall(resolver)
    if not ok then
        return nil
    end

    local cleanedGuid = TrimWhitespace(guid)
    if cleanedGuid == "" then
        cleanedGuid = nil
    end

    local cleanedType = TrimWhitespace(targetType):lower()
    if cleanedType == "" then
        cleanedType = cleanedGuid and "object" or "ground"
    end

    local resolved = {
        targetGuid = cleanedGuid,
        targetType = cleanedType,
        mapId = tonumber(mapId),
        x = NormalizeCoord(mapX),
        y = NormalizeCoord(mapY),
        worldX = tonumber(worldX),
        worldY = tonumber(worldY),
        worldZ = tonumber(worldZ),
    }

    if resolved.targetType == "ground" and not resolved.mapId and not (resolved.worldX and resolved.worldY and resolved.worldZ) then
        return nil
    end

    return resolved
end

local function ResolveMouseoverPingTarget()
    local resolver = nil
    if type(GetMouseoverPingTarget) == "function" then
        resolver = GetMouseoverPingTarget
    elseif type(C_Ping_GetMouseoverTarget) == "function" then
        resolver = C_Ping_GetMouseoverTarget
    end

    if not resolver then
        return nil
    end

    local ok, guid, targetType, mapId, mapX, mapY, worldX, worldY, worldZ = pcall(resolver)
    if not ok or not guid then
        return nil
    end

    guid = TrimWhitespace(guid)
    if guid == "" then
        return nil
    end

    local resolved = {
        targetGuid = guid,
        targetType = TrimWhitespace(targetType):lower(),
        mapId = tonumber(mapId),
        x = NormalizeCoord(mapX),
        y = NormalizeCoord(mapY),
        worldX = tonumber(worldX),
        worldY = tonumber(worldY),
        worldZ = tonumber(worldZ),
    }

    if resolved.targetType == "" then
        resolved.targetType = "object"
    end

    return resolved
end

local function ResolveRadialSelectionType(dx, dy)
    local settings = GetSettings()
    local deadzone = tonumber(settings.radialMenuDeadzone) or 28
    deadzone = Clamp(deadzone, 6, 120)

    local distSquared = (dx * dx) + (dy * dy)
    if distSquared <= (deadzone * deadzone) then
        return nil
    end

    local angle = math_deg(Atan2(dy, dx))

    local bestType = nil
    local bestDiff = nil

    for i = 1, #RADIAL_MENU_OPTIONS do
        local option = RADIAL_MENU_OPTIONS[i]
        local diff = math_abs(((angle - option.angle + 540) % 360) - 180)
        if not bestDiff or diff < bestDiff then
            bestDiff = diff
            bestType = option.type
        end
    end

    if bestDiff and bestDiff <= 72 then
        return bestType
    end

    return nil
end

local function UpdateRadialMenuVisuals()
    if not state.menuEntries then
        return
    end

    for i = 1, #state.menuEntries do
        local entry = state.menuEntries[i]
        local style = PING_STYLES[entry.pingType] or PING_STYLES.info
        local selected = (entry.pingType == state.menuSelectionType)

        if entry.Ring then
            entry.Ring:SetVertexColor(style.r, style.g, style.b, selected and 0.60 or 0.25)
        end
        if entry.Icon then
            ApplyStyleIcon(entry.Icon, entry.pingType)
            entry.Icon:SetVertexColor(style.r, style.g, style.b, selected and 1.0 or 0.85)
        end
        if entry.Label then
            if selected then
                entry.Label:SetTextColor(1.0, 1.0, 1.0)
            else
                entry.Label:SetTextColor(0.80, 0.82, 0.85)
            end
        end

        entry:SetScale(selected and 1.15 or 1.0)
    end

    if state.menuWheel and state.menuWheel.Instruction then
        if state.menuSelectionType and PING_STYLES[state.menuSelectionType] then
            state.menuWheel.Instruction:SetText("Release to ping: " .. tostring(PING_STYLES[state.menuSelectionType].label))
        else
            state.menuWheel.Instruction:SetText("Move cursor to choose a ping. Release key to confirm.")
        end
    end
end

local function UpdateRadialSelectionFromCursor()
    if not state.menuFrame or not state.menuFrame:IsShown() then
        return
    end
    if not state.menuWheel then
        return
    end

    local centerX, centerY = state.menuWheel:GetCenter()
    if not centerX or not centerY then
        return
    end

    local cursorX, cursorY = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    cursorX = cursorX / scale
    cursorY = cursorY / scale

    local selectedType = ResolveRadialSelectionType(cursorX - centerX, cursorY - centerY)
    if selectedType ~= state.menuSelectionType then
        state.menuSelectionType = selectedType
        UpdateRadialMenuVisuals()
    end
end

local function EnsureRadialMenuFrame()
    if state.menuFrame then
        return state.menuFrame
    end

    local frame = CreateFrame("Frame", "DCQOSPingRadialMenu", UIParent)
    frame:SetAllPoints(UIParent)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(40)
    frame:EnableMouse(true)
    frame:EnableKeyboard(true)
    if frame.SetPropagateKeyboardInput then
        frame:SetPropagateKeyboardInput(false)
    end
    frame:Hide()

    frame.Dim = frame:CreateTexture(nil, "BACKGROUND")
    frame.Dim:SetAllPoints(frame)
    frame.Dim:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    frame.Dim:SetVertexColor(0, 0, 0, 0.16)

    local wheel = CreateFrame("Frame", nil, frame)
    wheel:SetSize(220, 220)
    wheel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

    wheel.OuterRing = wheel:CreateTexture(nil, "ARTWORK")
    wheel.OuterRing:SetAllPoints()
    if not ApplyAtlasTexture(wheel.OuterRing, "Ping_Wheel_Icon_Default") then
        wheel.OuterRing:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    end
    wheel.OuterRing:SetVertexColor(0.08, 0.08, 0.08, 0.95)

    wheel.CenterRing = wheel:CreateTexture(nil, "OVERLAY")
    wheel.CenterRing:SetSize(56, 56)
    wheel.CenterRing:SetPoint("CENTER", wheel, "CENTER", 0, 0)
    wheel.CenterRing:SetTexture("Interface\\Buttons\\UI-Quickslot")
    wheel.CenterRing:SetVertexColor(0.60, 0.60, 0.60, 0.90)

    wheel.CancelIcon = wheel:CreateTexture(nil, "OVERLAY")
    wheel.CancelIcon:SetSize(18, 18)
    wheel.CancelIcon:SetPoint("CENTER", wheel, "CENTER", 0, 0)
    wheel.CancelIcon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    wheel.CancelIcon:SetVertexColor(0.95, 0.95, 0.95, 0.95)

    wheel.Instruction = wheel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    wheel.Instruction:SetPoint("TOP", wheel, "BOTTOM", 0, -8)
    wheel.Instruction:SetText("Move cursor to choose a ping. Release key to confirm.")

    local menuEntries = {}
    for i = 1, #RADIAL_MENU_OPTIONS do
        local option = RADIAL_MENU_OPTIONS[i]
        local entry = CreateFrame("Frame", nil, wheel)
        entry:SetSize(44, 44)
        entry:SetPoint("CENTER", wheel, "CENTER", option.offsetX, option.offsetY)
        entry.pingType = option.type
        entry.offsetX = option.offsetX
        entry.offsetY = option.offsetY

        entry.Ring = entry:CreateTexture(nil, "ARTWORK")
        entry.Ring:SetAllPoints()
        entry.Ring:SetTexture("Interface\\Buttons\\UI-Quickslot")

        entry.Icon = entry:CreateTexture(nil, "OVERLAY")
        entry.Icon:SetSize(26, 26)
        entry.Icon:SetPoint("CENTER", entry, "CENTER", 0, 0)
        ApplyStyleIcon(entry.Icon, option.type)

        entry.Label = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        entry.Label:SetPoint("TOP", entry, "BOTTOM", 0, -2)
        entry.Label:SetText(option.label)

        menuEntries[#menuEntries + 1] = entry
    end

    frame:SetScript("OnHide", function(self)
        self:SetScript("OnUpdate", nil)
        state.menuSelectionType = nil
    end)

    frame:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then
            PingSystem:CloseRadialMenu(false)
            return
        end

        PingSystem:CloseRadialMenu(button == "LeftButton")
    end)

    frame:SetScript("OnKeyUp", function(_, key)
        if key == "ESCAPE" then
            PingSystem:CloseRadialMenu(false)
            return
        end

        if key == "ENTER" then
            PingSystem:CloseRadialMenu(true)
        end
    end)

    state.menuFrame = frame
    state.menuWheel = wheel
    state.menuEntries = menuEntries

    UpdateRadialMenuVisuals()
    return frame
end

local function OpenRadialMenuInternal()
    local menu = EnsureRadialMenuFrame()
    local settings = GetSettings()

    local size = tonumber(settings.radialMenuSize) or 220
    size = Clamp(size, 140, 360)
    state.menuWheel:SetSize(size, size)

    local iconDistanceScale = size / 220
    for i = 1, #state.menuEntries do
        local entry = state.menuEntries[i]
        entry:ClearAllPoints()
        entry:SetPoint("CENTER", state.menuWheel, "CENTER", entry.offsetX * iconDistanceScale, entry.offsetY * iconDistanceScale)
    end

    local cursorX, cursorY = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    cursorX = cursorX / scale
    cursorY = cursorY / scale

    local halfSize = (size * 0.5) + 14
    local maxX = UIParent:GetWidth() - halfSize
    local maxY = UIParent:GetHeight() - halfSize
    cursorX = Clamp(cursorX, halfSize, maxX)
    cursorY = Clamp(cursorY, halfSize, maxY)

    state.menuWheel:ClearAllPoints()
    state.menuWheel:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cursorX, cursorY)

    state.menuSelectionType = nil
    UpdateRadialMenuVisuals()

    menu:SetScript("OnUpdate", function()
        UpdateRadialSelectionFromCursor()
    end)

    menu:Show()
end

local function EnsureRootFrame()
    if state.root then
        return state.root
    end

    local root = CreateFrame("Frame", "DCQOSPingRootFrame", UIParent)
    root:SetAllPoints(UIParent)
    root:SetFrameStrata("FULLSCREEN_DIALOG")
    root:SetFrameLevel(5)
    root:EnableMouse(false)
    root:Hide()

    state.root = root
    return root
end

local function CreatePingFrame()
    local root = EnsureRootFrame()
    local frame = CreateFrame("Frame", nil, root)
    frame:SetSize(56, 56)
    frame:Hide()

    frame.Ring = frame:CreateTexture(nil, "BACKGROUND")
    frame.Ring:SetAllPoints()
    if not ApplyAtlasTexture(frame.Ring, "Ping_GroundMarker_BG_Default") then
        frame.Ring:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    end
    frame.Ring:SetVertexColor(0.1, 0.1, 0.1, 0.75)

    frame.Stem = frame:CreateTexture(nil, "BORDER")
    frame.Stem:SetAllPoints()
    if not ApplyAtlasTexture(frame.Stem, "Ping_GroundMarker_Pin_Default") then
        frame.Stem:SetTexture("Interface\\Buttons\\UI-Quickslot")
    end
    frame.Stem:SetVertexColor(0.12, 0.12, 0.12, 0.82)

    frame.Stroke = frame:CreateTexture(nil, "BORDER")
    frame.Stroke:SetAllPoints()
    if not ApplyAtlasTexture(frame.Stroke, "Ping_GroundMarker_Stroke_Default") then
        frame.Stroke:SetTexture("Interface\\Buttons\\UI-Quickslot")
    end
    frame.Stroke:SetVertexColor(0.8, 0.8, 0.8, 0.55)

    frame.PointerBG = frame:CreateTexture(nil, "ARTWORK")
    frame.PointerBG:SetAllPoints()
    if not ApplyAtlasTexture(frame.PointerBG, "Ping_OVMarker_Pointer_BG") then
        frame.PointerBG:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    end
    frame.PointerBG:SetVertexColor(0.08, 0.08, 0.08, 0.45)

    frame.Pointer = frame:CreateTexture(nil, "ARTWORK")
    frame.Pointer:SetAllPoints()
    if not ApplyAtlasTexture(frame.Pointer, "Ping_OVMarker_Pointer_Default") then
        frame.Pointer:SetTexture("Interface\\Buttons\\UI-Quickslot")
    end
    frame.Pointer:SetVertexColor(0.8, 0.8, 0.8, 0.7)

    frame.Icon = frame:CreateTexture(nil, "ARTWORK")
    frame.Icon:SetSize(30, 30)
    frame.Icon:SetPoint("CENTER", frame, "CENTER", 0, 0)
    ApplyStyleIcon(frame.Icon, "info")

    frame.IconFlipbook = frame:CreateTexture(nil, "OVERLAY")
    frame.IconFlipbook:SetSize(34, 34)
    frame.IconFlipbook:SetPoint("CENTER", frame, "CENTER", 0, 0)
    if not ApplyAtlasTexture(frame.IconFlipbook, "Ping_Marker_Flipbook_Default") then
        frame.IconFlipbook:SetTexture("Interface\\Buttons\\UI-QuickslotRed")
    end
    frame.IconFlipbook:SetBlendMode("ADD")
    frame.IconFlipbook:SetAlpha(0.18)

    frame.GlowIn = frame:CreateTexture(nil, "OVERLAY")
    frame.GlowIn:SetAllPoints()
    if not ApplyAtlasTexture(frame.GlowIn, "Ping_SpotGlw_Default_In") then
        frame.GlowIn:SetTexture("Interface\\Minimap\\UI-Minimap-Ping-Expand")
    end
    frame.GlowIn:SetBlendMode("ADD")
    frame.GlowIn:SetAlpha(0.30)

    frame.GlowOut = frame:CreateTexture(nil, "OVERLAY")
    frame.GlowOut:SetAllPoints()
    if not ApplyAtlasTexture(frame.GlowOut, "Ping_SpotGlw_Default_Out") then
        frame.GlowOut:SetTexture("Interface\\Minimap\\UI-Minimap-Ping-Rotate")
    end
    frame.GlowOut:SetBlendMode("ADD")
    frame.GlowOut:SetAlpha(0.22)

    frame.DistanceText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.DistanceText:SetPoint("BOTTOM", frame, "TOP", 0, 1)
    frame.DistanceText:SetText("")

    frame.CaptionText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.CaptionText:SetPoint("TOP", frame, "BOTTOM", 0, -1)
    frame.CaptionText:SetWidth(220)
    frame.CaptionText:SetJustifyH("CENTER")
    frame.CaptionText:SetText("")

    return frame
end

local function AcquirePingFrame()
    local frame = table.remove(state.pool)
    if not frame then
        frame = CreatePingFrame()
    end
    return frame
end

local function ReleasePingAtIndex(index)
    local entry = state.active[index]
    if not entry then
        return
    end

    table.remove(state.active, index)

    local frame = entry.frame
    frame:Hide()
    frame:ClearAllPoints()
    frame:SetScale(1)
    frame:SetAlpha(1)
    frame.DistanceText:SetText("")
    frame.CaptionText:SetText("")
    table.insert(state.pool, frame)

    if #state.active == 0 and state.root then
        state.root:SetScript("OnUpdate", nil)
        state.root:Hide()
    end
end

local function BuildCaption(payload, style)
    local settings = GetSettings()
    local caption = payload.text
    if not caption or caption == "" then
        caption = style.label or "Ping"
    end

    if settings.showSource and payload.source and payload.source ~= "" then
        caption = caption .. " - " .. tostring(payload.source)
    end

    if string.len(caption) > 56 then
        caption = string.sub(caption, 1, 53) .. "..."
    end

    return caption
end

local function ResolveProjection(payload)
    local settings = GetSettings()
    local centerYOffset = settings.centerYOffset or -96

    local screenX = 0
    local screenY = centerYOffset
    local relative = nil
    local distance = payload.distance
    local targetMapId = payload.mapId
    local mapMismatch = false

    if type(payload.screenX) == "number" and type(payload.screenY) == "number" and not (payload.x and payload.y) then
        return payload.screenX, payload.screenY, distance, false, targetMapId
    end

    if payload.relativeRadians then
        relative = payload.relativeRadians
    elseif payload.relativeDegrees then
        relative = math_rad(payload.relativeDegrees)
    end

    if not relative and payload.bearingDegrees then
        local facing = (type(GetPlayerFacing) == "function") and (GetPlayerFacing() or 0) or 0
        relative = NormalizeRadians(math_rad(payload.bearingDegrees) - facing)
    end

    if not relative and payload.x and payload.y then
        local playerX, playerY, playerMapId = GetPlayerMapPositionSafe()
        if playerMapId and targetMapId and targetMapId ~= playerMapId then
            mapMismatch = true
        end

        if payload.x and payload.y and playerX and playerY and (not targetMapId or targetMapId == playerMapId) then
            local dist, dx, dy = ComputeDistanceYards(playerMapId, playerX, playerY, payload.x, payload.y)
            distance = distance or dist
            local facing = (type(GetPlayerFacing) == "function") and (GetPlayerFacing() or 0) or 0
            relative = ComputeRelativeHeading(facing, playerX, playerY, payload.x, payload.y, dx, dy)
        end
    end

    if relative then
        local radius = settings.ringRadius or 210

        if distance then
            local projection = settings.distanceProjection or 0.30
            local projected = distance * projection
            radius = math_min(radius, math_max(60, projected))
        end

        screenX = -math_sin(relative) * radius
        screenY = -math_cos(relative) * radius + centerYOffset
    end

    return screenX, screenY, distance, mapMismatch, targetMapId
end

local function PlayPingSound(payload, style)
    local settings = GetSettings()
    if not settings.playSound then
        return
    end
    if type(PlaySound) ~= "function" then
        return
    end

    local soundName = payload.sound or style.sound or "MapPing"
    local ok = pcall(PlaySound, soundName)
    if not ok and soundName ~= "MapPing" then
        pcall(PlaySound, "MapPing")
    end
end

local function UpdateActivePings(_, elapsed)
    local now = GetTime() or 0

    for i = #state.active, 1, -1 do
        local entry = state.active[i]
        entry.remaining = entry.remaining - elapsed

        if entry.remaining <= 0 then
            ReleasePingAtIndex(i)
        else
            local progress = entry.remaining / entry.duration
            local pulse = 1 + (0.08 * math_abs(math_sin((now * 10) + entry.phase)))
            entry.frame:SetScale(entry.baseScale * pulse)
            entry.frame:SetAlpha(Clamp(0.2 + (0.8 * progress), 0.2, 1.0))
        end
    end
end

local function IsEnabled()
    local settings = GetSettings()
    return settings and settings.enabled ~= false
end

local function IsLikelyPingFeature(feature)
    local name = TrimWhitespace(feature):lower()
    return name == "ping"
        or name == "screen_ping"
        or name == "display_ping"
        or name == "danger_ping"
        or name == "combat_ping"
end

local function NormalizeRelayDistribution(value)
    local distribution = TrimWhitespace(value):upper()

    if distribution == "RAID" or distribution == "PARTY" then
        return distribution
    end

    return "AUTO"
end

local function ResolveRelayDistribution(normalized)
    if type(GetPingSyncDistribution) == "function" then
        local resolved = NormalizeRelayDistribution(GetPingSyncDistribution())
        if resolved == "AUTO" then
            return nil
        end

        return resolved
    end

    if normalized and normalized.distribution then
        return NormalizeRelayDistribution(normalized.distribution)
    end

    return "AUTO"
end

local function ResolveRelayMapPosition(normalized)
    local mapId = tonumber(normalized.mapId)
    local mapX = normalized.x
    local mapY = normalized.y

    if mapId and mapX and mapY then
        return mapId, Clamp(mapX, 0, 1), Clamp(mapY, 0, 1)
    end

    local playerX, playerY, playerMapId = GetPlayerMapPositionSafe()
    if not mapId then
        mapId = playerMapId
    end

    if mapId and mapX and mapY then
        return mapId, Clamp(mapX, 0, 1), Clamp(mapY, 0, 1)
    end

    if not mapId or not playerX or not playerY then
        return nil, nil, nil
    end

    if playerMapId and mapId ~= playerMapId then
        return nil, nil, nil
    end

    local relative = normalized.relativeRadians
    if not relative and normalized.relativeDegrees then
        relative = math_rad(normalized.relativeDegrees)
    end

    if not relative and normalized.bearingDegrees then
        local facing = (type(GetPlayerFacing) == "function") and (GetPlayerFacing() or 0) or 0
        relative = NormalizeRadians(math_rad(normalized.bearingDegrees) - facing)
    end

    if not relative and type(normalized.screenX) == "number" and type(normalized.screenY) == "number" then
        local centerYOffset = tonumber(GetSettings().centerYOffset) or -96
        local offsetX = normalized.screenX
        local offsetY = normalized.screenY - centerYOffset
        if ((offsetX * offsetX) + (offsetY * offsetY)) > 1 then
            relative = Atan2(-offsetX, -offsetY)
        end
    end

    if not relative then
        return mapId, Clamp(playerX, 0, 1), Clamp(playerY, 0, 1)
    end

    local distanceYards = tonumber(normalized.distance)
    if not distanceYards or distanceYards <= 0 then
        distanceYards = tonumber(GetSettings().quickPingDistance) or 700
    end
    distanceYards = Clamp(distanceYards, 1, 5000)

    local facing = (type(GetPlayerFacing) == "function") and (GetPlayerFacing() or 0) or 0
    local direction = NormalizeRadians(facing + relative)
    local deltaX = math_sin(direction) * distanceYards
    local deltaY = math_cos(direction) * distanceYards

    local mapWidth, mapHeight = GetMapAreaYards(mapId)
    mapX = Clamp(playerX + (deltaX / mapWidth), 0, 1)
    mapY = Clamp(playerY + (deltaY / mapHeight), 0, 1)

    return mapId, mapX, mapY
end

local function BuildRelayRequest(normalized)
    if type(EncodePingSyncProtocolPayload) ~= "function" then
        return nil, "EncodePingSyncProtocolPayload unavailable."
    end

    local distribution = ResolveRelayDistribution(normalized)
    if not distribution then
        return nil, "Not in party or raid."
    end

    local mapId, mapX, mapY = ResolveRelayMapPosition(normalized)
    if not mapId or mapX == nil or mapY == nil then
        return nil, "Unable to resolve relay map coordinates."
    end

    local flags = tonumber(normalized.relayFlags) or 0
    local sequence = tonumber(normalized.sequence)
    if not sequence then
        local now = GetTime()
        sequence = now and math_floor((now * 1000) + 0.5) or 0
    end

    local ok, encodedPayload = pcall(
        EncodePingSyncProtocolPayload,
        normalized.type or "info",
        mapId,
        mapX,
        mapY,
        flags,
        sequence,
        distribution
    )

    if not ok or type(encodedPayload) ~= "string" or encodedPayload == "" then
        return nil, "Failed to encode relay payload."
    end

    return {
        feature = "ping",
        action = "relay",
        distribution = distribution,
        payload = encodedPayload,
        syncPayload = encodedPayload,
        text = normalized.text,
        targetName = normalized.targetName,
        targetGuid = normalized.targetGuid,
        targetType = normalized.targetType,
        worldX = normalized.worldX,
        worldY = normalized.worldY,
        worldZ = normalized.worldZ,
    }
end

local function SendLocalPingRelay(normalized)
    local protocol = addon and addon.protocol
    if type(protocol) ~= "table" or type(protocol.SendJson) ~= "function" then
        return false, "Protocol sender unavailable."
    end

    local opcodes = protocol.Opcodes
    local requestOpcode = opcodes and opcodes.CMSG_REQUEST_FEATURE
    if not requestOpcode then
        return false, "Missing CMSG_REQUEST_FEATURE opcode."
    end

    if not protocol.connected and type(protocol.Initialize) == "function" then
        pcall(function()
            protocol:Initialize()
        end)
    end

    if not protocol.connected then
        return false, "Protocol not connected."
    end

    local request, err = BuildRelayRequest(normalized)
    if not request then
        return false, err
    end

    if protocol:SendJson(requestOpcode, request) then
        return true
    end

    return false, "Ping relay request failed."
end

local function DecodeRelayEnvelopePayload(payload)
    if type(payload) ~= "table" then
        return payload
    end

    local encoded = payload.payload or payload.syncPayload
    if type(encoded) ~= "string" or encoded == "" then
        return payload
    end

    if type(DecodePingSyncProtocolPayload) ~= "function" then
        return payload
    end

    local ok, distribution, pingType, mapId, mapX, mapY, relayFlags, sequence = pcall(DecodePingSyncProtocolPayload, encoded)
    if not ok or not pingType then
        return payload
    end

    return {
        feature = payload.feature,
        type = pingType,
        mapId = mapId,
        x = mapX,
        y = mapY,
        source = payload.source,
        text = payload.text,
        targetName = payload.targetName,
        targetGuid = payload.targetGuid,
        targetType = payload.targetType,
        worldX = payload.worldX,
        worldY = payload.worldY,
        worldZ = payload.worldZ,
        distribution = distribution,
        relayFlags = relayFlags,
        sequence = sequence,
    }
end

local function IsRenderablePingPayload(payload)
    if type(payload) ~= "table" then
        return false
    end

    return payload.type ~= nil
        or payload.x ~= nil
        or payload.y ~= nil
        or payload.screenX ~= nil
        or payload.screenY ~= nil
        or payload.relativeDegrees ~= nil
end

local function HandleProtocolFeatureData(rawPayload)
    local settings = GetSettings()
    if not settings.allowProtocolPings then
        return
    end

    if type(rawPayload) ~= "table" then
        return
    end

    local feature = rawPayload.feature
    local payload = rawPayload

    if type(rawPayload.data) == "table" then
        payload = rawPayload.data
        if not payload.feature and feature then
            payload.feature = feature
        end
    end

    feature = payload.feature or feature
    if not IsLikelyPingFeature(feature) then
        return
    end

    if payload.action == "relay_ack" then
        return
    end

    payload = DecodeRelayEnvelopePayload(payload)
    if not IsRenderablePingPayload(payload) then
        return
    end

    payload.__dcqosRemote = true
    PingSystem:Push(payload)
end

local function InstallProtocolHandler()
    if state.protocolHooked then
        return true
    end

    local DC = rawget(_G, "DCAddonProtocol")
    if not DC or type(DC.RegisterHandler) ~= "function" then
        return false
    end

    local moduleId = (addon.protocol and addon.protocol.MODULE_ID) or "QOS"
    local opcode = (addon.protocol and addon.protocol.Opcodes and addon.protocol.Opcodes.SMSG_FEATURE_DATA) or 0x15

    state.protocolHandler = function(...)
        local payload = select(1, ...)
        HandleProtocolFeatureData(payload)
    end

    DC:RegisterHandler(moduleId, opcode, state.protocolHandler)
    state.protocolHooked = true
    state.protocolModule = moduleId
    state.protocolOpcode = opcode

    addon:Debug("Ping System protocol hook registered: " .. tostring(moduleId) .. " op=" .. tostring(opcode))
    return true
end

local function UninstallProtocolHandler()
    if not state.protocolHooked then
        return
    end

    local DC = rawget(_G, "DCAddonProtocol")
    if DC and type(DC.UnregisterHandler) == "function" and state.protocolHandler then
        pcall(DC.UnregisterHandler, DC, state.protocolModule, state.protocolOpcode, state.protocolHandler)
    end

    state.protocolHooked = false
    state.protocolModule = nil
    state.protocolOpcode = nil
    state.protocolHandler = nil
end

local function EnsureFeatureEventBridge()
    if state.featureEventBridgeInstalled then
        return
    end

    addon:RegisterEvent("QOS_FEATURE_DATA_RECEIVED", function(feature, payload)
        if not IsEnabled() then
            return
        end
        if not IsLikelyPingFeature(feature) then
            return
        end

        if type(payload) ~= "table" then
            payload = {}
        end

        if not payload.feature then
            payload.feature = feature
        end

        payload.__dcqosRemote = true
        PingSystem:Push(payload)
    end)

    state.featureEventBridgeInstalled = true
end

local function EnsureSlashCommand()
    if state.slashRegistered or SlashCmdList["DCQOSPING"] then
        state.slashRegistered = true
        return
    end

    SLASH_DCQOSPING1 = "/dcping"
    SlashCmdList["DCQOSPING"] = function(msg)
        local text = TrimWhitespace(msg)
        local playerName = UnitName("player") or "player"

        if text == "" or text == "help" then
            addon:Print("Ping commands:", true)
            print("  /dcping test")
            print("  /dcping clear")
            print("  /dcping menu")
            print("  /dcping <type> <x> <y> [mapId] [label]")
            print("  /dcping bearing <degrees> [type] [label]")
            print("  Keybinds: Esc -> Key Bindings -> AddOns -> DC-QoS Ping (radial default: G)")
            print("Types: attack, warning, assist, onmyway, danger, info")
            return
        end

        if text == "clear" then
            PingSystem:Clear()
            addon:Print("Ping System: cleared active pings.", true)
            return
        end

        if text == "test" then
            local ok, err = PingSystem:PushTestPing()
            if not ok then
                addon:Print("Ping System: " .. tostring(err), true)
            end
            return
        end

        if text == "menu" or text == "wheel" then
            local ok, err = PingSystem:OpenRadialMenu()
            if not ok and err then
                addon:Print("Ping System: " .. tostring(err), true)
            end
            return
        end

        local tokens = {}
        for token in text:gmatch("%S+") do
            table.insert(tokens, token)
        end

        if tokens[1] == "bearing" and tokens[2] then
            local degrees = tonumber(tokens[2])
            if not degrees then
                addon:Print("Usage: /dcping bearing <degrees> [type] [label]", true)
                return
            end

            local pingType = tokens[3] or "warning"
            local label = nil
            if #tokens >= 4 then
                label = table.concat(tokens, " ", 4)
            end

            local ok, err = PingSystem:Push({
                type = pingType,
                relativeDegrees = degrees,
                source = playerName,
                text = label,
            })

            if not ok then
                addon:Print("Ping System: " .. tostring(err), true)
            end
            return
        end

        if #tokens >= 3 then
            local pingType = tokens[1]
            local x = tonumber(tokens[2])
            local y = tonumber(tokens[3])
            local mapId = tonumber(tokens[4])

            if not x or not y then
                addon:Print("Usage: /dcping <type> <x> <y> [mapId] [label]", true)
                return
            end

            local labelStart = mapId and 5 or 4
            local label = nil
            if #tokens >= labelStart then
                label = table.concat(tokens, " ", labelStart)
            end

            local ok, err = PingSystem:Push({
                type = pingType,
                x = x,
                y = y,
                mapId = mapId,
                source = playerName,
                text = label,
            })

            if not ok then
                addon:Print("Ping System: " .. tostring(err), true)
            end
            return
        end

        addon:Print("Usage: /dcping help", true)
    end

    state.slashRegistered = true
end

function PingSystem:Push(payload)
    if not IsEnabled() then
        return false, "Ping System is disabled."
    end

    local settings = GetSettings()
    local normalized = NormalizePayload(payload)
    if not normalized then
        return false, "Invalid ping payload."
    end

    local now = GetTime() or 0
    local throttleMs = tonumber(settings.throttleMs) or 0
    if not payload.ignoreThrottle and throttleMs > 0 then
        local diff = now - (state.lastPingAt or 0)
        if diff < (throttleMs / 1000) then
            return false, "Ping throttled."
        end
    end

    state.lastPingAt = now

    local style = GetStyleForPingType(normalized.type)
    local duration = tonumber(normalized.duration) or tonumber(settings.lifetimeSeconds) or 3.0
    duration = Clamp(duration, 0.5, 12.0)

    while #state.active >= (settings.maxActivePings or 6) do
        ReleasePingAtIndex(1)
    end

    local frame = AcquirePingFrame()
    local x, y, distance, mapMismatch, targetMapId = ResolveProjection(normalized)

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", EnsureRootFrame(), "CENTER", x, y)

    if normalized.targetType == "unit" then
        if not ApplyAtlasTexture(frame.Ring, "Ping_UnitMarker_BG_Default") then
            frame.Ring:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        end
    else
        if not ApplyAtlasTexture(frame.Ring, "Ping_GroundMarker_BG_Default") then
            frame.Ring:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        end
    end

    if not ApplyAtlasTexture(frame.Stem, "Ping_GroundMarker_Pin_Default") then
        frame.Stem:SetTexture("Interface\\Buttons\\UI-Quickslot")
    end
    if not ApplyAtlasTexture(frame.Stroke, "Ping_GroundMarker_Stroke_Default") then
        frame.Stroke:SetTexture("Interface\\Buttons\\UI-Quickslot")
    end
    if not ApplyAtlasTexture(frame.PointerBG, "Ping_OVMarker_Pointer_BG") then
        frame.PointerBG:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    end
    if not ApplyAtlasTexture(frame.Pointer, "Ping_OVMarker_Pointer_Default") then
        frame.Pointer:SetTexture("Interface\\Buttons\\UI-Quickslot")
    end

    ApplyStyleIcon(frame.Icon, normalized.type)
    if not ApplyAtlasTexture(frame.IconFlipbook, "Ping_Marker_Flipbook_Default") then
        frame.IconFlipbook:SetTexture("Interface\\Buttons\\UI-QuickslotRed")
    end
    if not ApplyAtlasTexture(frame.GlowIn, "Ping_SpotGlw_Default_In") then
        frame.GlowIn:SetTexture("Interface\\Minimap\\UI-Minimap-Ping-Expand")
    end
    if not ApplyAtlasTexture(frame.GlowOut, "Ping_SpotGlw_Default_Out") then
        frame.GlowOut:SetTexture("Interface\\Minimap\\UI-Minimap-Ping-Rotate")
    end

    frame.Icon:SetVertexColor(style.r, style.g, style.b, 1.0)
    frame.IconFlipbook:SetVertexColor(style.r, style.g, style.b, 0.25)
    frame.Stroke:SetVertexColor(style.r, style.g, style.b, 0.55)
    frame.Pointer:SetVertexColor(style.r, style.g, style.b, 0.70)
    frame.GlowIn:SetVertexColor(style.r, style.g, style.b, 0.30)
    frame.GlowOut:SetVertexColor(style.r, style.g, style.b, 0.24)

    frame.CaptionText:SetText(BuildCaption(normalized, style))

    if settings.showDistance then
        if distance and distance > 0 then
            frame.DistanceText:SetText(string.format("%d yd", math_floor(distance + 0.5)))
        elseif mapMismatch and targetMapId then
            frame.DistanceText:SetText("Map " .. tostring(targetMapId))
        else
            frame.DistanceText:SetText("")
        end
    else
        frame.DistanceText:SetText("")
    end

    frame:SetScale(settings.markerScale or 1.0)
    frame:SetAlpha(1)
    frame:Show()

    table.insert(state.active, {
        frame = frame,
        duration = duration,
        remaining = duration,
        baseScale = settings.markerScale or 1.0,
        phase = now * 3.0,
    })

    local root = EnsureRootFrame()
    root:Show()
    if not root:GetScript("OnUpdate") then
        root:SetScript("OnUpdate", UpdateActivePings)
    end

    PlayPingSound(normalized, style)
    addon:FireEvent("PING_SYSTEM_PING_ADDED", normalized)

    if type(payload) == "table" and not payload.__dcqosRemote and not payload.noRelay then
        local relayOk, relayErr = SendLocalPingRelay(normalized)
        if not relayOk and relayErr and relayErr ~= "Not in party or raid." then
            addon:Debug("Ping relay skipped: " .. tostring(relayErr))
        end
    end

    return true
end

function PingSystem:PushQuickPing(pingType, options)
    options = options or {}

    local settings = GetSettings()
    local ignoreThrottle = (options.ignoreThrottle ~= false)

    local payload = {
        type = pingType or "warning",
        ignoreThrottle = ignoreThrottle,
    }

    local cursorTarget = ResolveCursorWorldPingTarget()
    if cursorTarget then
        payload.targetGuid = cursorTarget.targetGuid
        payload.targetType = cursorTarget.targetType
        payload.worldX = cursorTarget.worldX
        payload.worldY = cursorTarget.worldY
        payload.worldZ = cursorTarget.worldZ

        if cursorTarget.mapId and cursorTarget.x and cursorTarget.y then
            payload.mapId = cursorTarget.mapId
            payload.x = cursorTarget.x
            payload.y = cursorTarget.y
        end
    end

    local mouseoverTarget = ResolveMouseoverPingTarget()
    if mouseoverTarget then
        if (not payload.targetGuid) or (mouseoverTarget.targetGuid and mouseoverTarget.targetGuid == payload.targetGuid) then
            payload.targetGuid = mouseoverTarget.targetGuid or payload.targetGuid
            payload.targetType = mouseoverTarget.targetType or payload.targetType
        end

        if not payload.worldX and mouseoverTarget.worldX then
            payload.worldX = mouseoverTarget.worldX
            payload.worldY = mouseoverTarget.worldY
            payload.worldZ = mouseoverTarget.worldZ
        end

        if (not payload.mapId or payload.x == nil or payload.y == nil) and mouseoverTarget.mapId and mouseoverTarget.x and mouseoverTarget.y then
            payload.mapId = mouseoverTarget.mapId
            payload.x = mouseoverTarget.x
            payload.y = mouseoverTarget.y
        end

        if type(UnitName) == "function" and type(UnitExists) == "function" and UnitExists("mouseover") then
            payload.targetName = UnitName("mouseover")
            if payload.targetName and payload.targetName ~= "" then
                payload.text = payload.targetName
            end
        end
    end

    if not (payload.x and payload.y) then
        local screenX, screenY = GetCursorScreenOffsets()
        if screenX and screenY then
            payload.screenX = screenX
            payload.screenY = screenY
        else
            payload.distance = tonumber(settings.quickPingDistance) or 700
            payload.relativeDegrees = 0
        end
    end

    return self:Push(payload)
end

function PingSystem:OpenRadialMenu()
    if not IsEnabled() then
        return false, "Ping System is disabled."
    end

    local settings = GetSettings()
    if settings.enableRadialMenu == false then
        return false, "Radial ping menu is disabled."
    end

    if state.menuFrame and state.menuFrame:IsShown() then
        return true
    end

    OpenRadialMenuInternal()
    return true
end

function PingSystem:CloseRadialMenu(commitSelection)
    CancelMenuHoldTimer()

    if not state.menuFrame or not state.menuFrame:IsShown() then
        return false
    end

    local selectedType = state.menuSelectionType
    state.menuSelectionType = nil

    state.menuFrame:Hide()

    if commitSelection and selectedType then
        self:PushQuickPing(selectedType, {
            ignoreThrottle = false,
        })
    end

    return true
end

function PingSystem:PushTestPing()
    -- Keep test pings deterministic and clearly away from the player model.
    local settings = GetSettings()

    return self:Push({
        type = "warning",
        text = "Test Ping",
        relativeDegrees = 35,
        distance = tonumber(settings.quickPingDistance) or 700,
        ignoreThrottle = true,
    })
end

function PingSystem:Clear()
    self:CloseRadialMenu(false)

    for i = #state.active, 1, -1 do
        ReleasePingAtIndex(i)
    end
end

function PingSystem:PushMapPing(pingType, x, y, mapId, source, text)
    return self:Push({
        type = pingType,
        x = x,
        y = y,
        mapId = mapId,
        source = source,
        text = text,
    })
end

function PingSystem.OnInitialize()
    addon:Debug("Ping System module initializing")
    EnsureRootFrame()
    EnsureSlashCommand()
    EnsureFeatureEventBridge()

    addon.PingSystem = PingSystem
    addon.PushScreenPing = function(_, payload)
        return PingSystem:Push(payload)
    end
end

function PingSystem.OnEnable()
    addon:Debug("Ping System module enabling")

    EnsureRootFrame()
    EnsureSlashCommand()
    EnsureFeatureEventBridge()

    if not InstallProtocolHandler() and addon.DelayedCall then
        addon:DelayedCall(2.0, function()
            if IsEnabled() then
                InstallProtocolHandler()
            end
        end)
    end
end

function PingSystem.OnDisable()
    addon:Debug("Ping System module disabling")
    UninstallProtocolHandler()
    PingSystem:CloseRadialMenu(false)
    PingSystem:Clear()
end

function PingSystem.CreateSettings(parent)
    local settings = GetSettings()

    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Ping System")

    local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    desc:SetJustifyH("LEFT")
    desc:SetText("On-screen pings anchored to player view. This is separate from map-based hotspots and death markers.")

    local yOffset = -78

    local enabledCb = addon:CreateCheckbox(parent)
    enabledCb:SetPoint("TOPLEFT", 16, yOffset)
    enabledCb.Text:SetText("Enable ping display")
    enabledCb:SetChecked(settings.enabled)
    enabledCb:SetScript("OnClick", function(self)
        addon:SetSetting("pingSystem.enabled", self:GetChecked())
    end)
    yOffset = yOffset - 25

    local protocolCb = addon:CreateCheckbox(parent)
    protocolCb:SetPoint("TOPLEFT", 16, yOffset)
    protocolCb.Text:SetText("Allow protocol-driven screen pings")
    protocolCb:SetChecked(settings.allowProtocolPings)
    protocolCb:SetScript("OnClick", function(self)
        addon:SetSetting("pingSystem.allowProtocolPings", self:GetChecked())
    end)
    yOffset = yOffset - 25

    local keybindCb = addon:CreateCheckbox(parent)
    keybindCb:SetPoint("TOPLEFT", 16, yOffset)
    keybindCb.Text:SetText("Enable ping keybind actions")
    keybindCb:SetChecked(settings.enableKeybinds ~= false)
    keybindCb:SetScript("OnClick", function(self)
        addon:SetSetting("pingSystem.enableKeybinds", self:GetChecked())
    end)
    yOffset = yOffset - 25

    local radialMenuCb = addon:CreateCheckbox(parent)
    radialMenuCb:SetPoint("TOPLEFT", 16, yOffset)
    radialMenuCb.Text:SetText("Enable radial ping menu (default G keybind)")
    radialMenuCb:SetChecked(settings.enableRadialMenu ~= false)
    radialMenuCb:SetScript("OnClick", function(self)
        addon:SetSetting("pingSystem.enableRadialMenu", self:GetChecked())
    end)
    yOffset = yOffset - 25

    local sourceCb = addon:CreateCheckbox(parent)
    sourceCb:SetPoint("TOPLEFT", 16, yOffset)
    sourceCb.Text:SetText("Show ping source in label")
    sourceCb:SetChecked(settings.showSource)
    sourceCb:SetScript("OnClick", function(self)
        addon:SetSetting("pingSystem.showSource", self:GetChecked())
    end)
    yOffset = yOffset - 25

    local distanceCb = addon:CreateCheckbox(parent)
    distanceCb:SetPoint("TOPLEFT", 16, yOffset)
    distanceCb.Text:SetText("Show distance text")
    distanceCb:SetChecked(settings.showDistance)
    distanceCb:SetScript("OnClick", function(self)
        addon:SetSetting("pingSystem.showDistance", self:GetChecked())
    end)
    yOffset = yOffset - 25

    local soundCb = addon:CreateCheckbox(parent)
    soundCb:SetPoint("TOPLEFT", 16, yOffset)
    soundCb.Text:SetText("Play ping sound")
    soundCb:SetChecked(settings.playSound)
    soundCb:SetScript("OnClick", function(self)
        addon:SetSetting("pingSystem.playSound", self:GetChecked())
    end)
    yOffset = yOffset - 34

    local scaleSlider = addon:CreateSlider(parent)
    scaleSlider:SetPoint("TOPLEFT", 16, yOffset)
    scaleSlider:SetWidth(220)
    scaleSlider:SetMinMaxValues(0.50, 2.00)
    scaleSlider:SetValueStep(0.05)
    scaleSlider:SetValue(settings.markerScale or 1.0)
    scaleSlider.Text:SetText(string.format("Marker Scale: %.2f", settings.markerScale or 1.0))
    scaleSlider.Low:SetText("0.50")
    scaleSlider.High:SetText("2.00")
    scaleSlider:SetScript("OnValueChanged", function(self, value)
        local rounded = math_floor((value * 20) + 0.5) / 20
        self.Text:SetText(string.format("Marker Scale: %.2f", rounded))
        addon:SetSetting("pingSystem.markerScale", rounded)
    end)
    yOffset = yOffset - 54

    local lifetimeSlider = addon:CreateSlider(parent)
    lifetimeSlider:SetPoint("TOPLEFT", 16, yOffset)
    lifetimeSlider:SetWidth(220)
    lifetimeSlider:SetMinMaxValues(1.0, 8.0)
    lifetimeSlider:SetValueStep(0.1)
    lifetimeSlider:SetValue(settings.lifetimeSeconds or 3.0)
    lifetimeSlider.Text:SetText(string.format("Lifetime: %.1f sec", settings.lifetimeSeconds or 3.0))
    lifetimeSlider.Low:SetText("1.0")
    lifetimeSlider.High:SetText("8.0")
    lifetimeSlider:SetScript("OnValueChanged", function(self, value)
        local rounded = math_floor((value * 10) + 0.5) / 10
        self.Text:SetText(string.format("Lifetime: %.1f sec", rounded))
        addon:SetSetting("pingSystem.lifetimeSeconds", rounded)
    end)
    yOffset = yOffset - 54

    local radiusSlider = addon:CreateSlider(parent)
    radiusSlider:SetPoint("TOPLEFT", 16, yOffset)
    radiusSlider:SetWidth(220)
    radiusSlider:SetMinMaxValues(80, 360)
    radiusSlider:SetValueStep(2)
    radiusSlider:SetValue(settings.ringRadius or 210)
    radiusSlider.Text:SetText("Ring Radius: " .. tostring(settings.ringRadius or 210))
    radiusSlider.Low:SetText("80")
    radiusSlider.High:SetText("360")
    radiusSlider:SetScript("OnValueChanged", function(self, value)
        local rounded = math_floor(value + 0.5)
        self.Text:SetText("Ring Radius: " .. tostring(rounded))
        addon:SetSetting("pingSystem.ringRadius", rounded)
    end)
    yOffset = yOffset - 54

    local projectionSlider = addon:CreateSlider(parent)
    projectionSlider:SetPoint("TOPLEFT", 16, yOffset)
    projectionSlider:SetWidth(220)
    projectionSlider:SetMinMaxValues(0.05, 0.80)
    projectionSlider:SetValueStep(0.01)
    projectionSlider:SetValue(settings.distanceProjection or 0.30)
    projectionSlider.Text:SetText(string.format("Distance Projection: %.2f px/yd", settings.distanceProjection or 0.30))
    projectionSlider.Low:SetText("0.05")
    projectionSlider.High:SetText("0.80")
    projectionSlider:SetScript("OnValueChanged", function(self, value)
        local rounded = math_floor((value * 100) + 0.5) / 100
        self.Text:SetText(string.format("Distance Projection: %.2f px/yd", rounded))
        addon:SetSetting("pingSystem.distanceProjection", rounded)
    end)
    yOffset = yOffset - 54

    local offsetSlider = addon:CreateSlider(parent)
    offsetSlider:SetPoint("TOPLEFT", 16, yOffset)
    offsetSlider:SetWidth(220)
    offsetSlider:SetMinMaxValues(-260, 120)
    offsetSlider:SetValueStep(2)
    offsetSlider:SetValue(settings.centerYOffset or -96)
    offsetSlider.Text:SetText("Center Y Offset: " .. tostring(settings.centerYOffset or -96))
    offsetSlider.Low:SetText("-260")
    offsetSlider.High:SetText("120")
    offsetSlider:SetScript("OnValueChanged", function(self, value)
        local rounded = math_floor(value + 0.5)
        self.Text:SetText("Center Y Offset: " .. tostring(rounded))
        addon:SetSetting("pingSystem.centerYOffset", rounded)
    end)
    yOffset = yOffset - 54

    local throttleSlider = addon:CreateSlider(parent)
    throttleSlider:SetPoint("TOPLEFT", 16, yOffset)
    throttleSlider:SetWidth(220)
    throttleSlider:SetMinMaxValues(0, 600)
    throttleSlider:SetValueStep(10)
    throttleSlider:SetValue(settings.throttleMs or 120)
    throttleSlider.Text:SetText("Throttle: " .. tostring(settings.throttleMs or 120) .. " ms")
    throttleSlider.Low:SetText("0")
    throttleSlider.High:SetText("600")
    throttleSlider:SetScript("OnValueChanged", function(self, value)
        local rounded = math_floor(value + 0.5)
        self.Text:SetText("Throttle: " .. tostring(rounded) .. " ms")
        addon:SetSetting("pingSystem.throttleMs", rounded)
    end)
    yOffset = yOffset - 54

    local quickDistanceSlider = addon:CreateSlider(parent)
    quickDistanceSlider:SetPoint("TOPLEFT", 16, yOffset)
    quickDistanceSlider:SetWidth(220)
    quickDistanceSlider:SetMinMaxValues(150, 1500)
    quickDistanceSlider:SetValueStep(10)
    quickDistanceSlider:SetValue(settings.quickPingDistance or 700)
    quickDistanceSlider.Text:SetText("Quick Ping Distance: " .. tostring(settings.quickPingDistance or 700) .. " yd")
    quickDistanceSlider.Low:SetText("150")
    quickDistanceSlider.High:SetText("1500")
    quickDistanceSlider:SetScript("OnValueChanged", function(self, value)
        local rounded = math_floor(value + 0.5)
        self.Text:SetText("Quick Ping Distance: " .. tostring(rounded) .. " yd")
        addon:SetSetting("pingSystem.quickPingDistance", rounded)
    end)
    yOffset = yOffset - 54

    local radialSizeSlider = addon:CreateSlider(parent)
    radialSizeSlider:SetPoint("TOPLEFT", 16, yOffset)
    radialSizeSlider:SetWidth(220)
    radialSizeSlider:SetMinMaxValues(140, 360)
    radialSizeSlider:SetValueStep(2)
    radialSizeSlider:SetValue(settings.radialMenuSize or 220)
    radialSizeSlider.Text:SetText("Radial Menu Size: " .. tostring(settings.radialMenuSize or 220))
    radialSizeSlider.Low:SetText("140")
    radialSizeSlider.High:SetText("360")
    radialSizeSlider:SetScript("OnValueChanged", function(self, value)
        local rounded = math_floor(value + 0.5)
        self.Text:SetText("Radial Menu Size: " .. tostring(rounded))
        addon:SetSetting("pingSystem.radialMenuSize", rounded)
    end)
    yOffset = yOffset - 54

    local radialDeadzoneSlider = addon:CreateSlider(parent)
    radialDeadzoneSlider:SetPoint("TOPLEFT", 16, yOffset)
    radialDeadzoneSlider:SetWidth(220)
    radialDeadzoneSlider:SetMinMaxValues(6, 80)
    radialDeadzoneSlider:SetValueStep(1)
    radialDeadzoneSlider:SetValue(settings.radialMenuDeadzone or 28)
    radialDeadzoneSlider.Text:SetText("Radial Deadzone: " .. tostring(settings.radialMenuDeadzone or 28) .. " px")
    radialDeadzoneSlider.Low:SetText("6")
    radialDeadzoneSlider.High:SetText("80")
    radialDeadzoneSlider:SetScript("OnValueChanged", function(self, value)
        local rounded = math_floor(value + 0.5)
        self.Text:SetText("Radial Deadzone: " .. tostring(rounded) .. " px")
        addon:SetSetting("pingSystem.radialMenuDeadzone", rounded)
    end)
    yOffset = yOffset - 54

    local radialHoldDelaySlider = addon:CreateSlider(parent)
    radialHoldDelaySlider:SetPoint("TOPLEFT", 16, yOffset)
    radialHoldDelaySlider:SetWidth(220)
    radialHoldDelaySlider:SetMinMaxValues(0.05, 0.50)
    radialHoldDelaySlider:SetValueStep(0.01)
    radialHoldDelaySlider:SetValue(settings.radialHoldDelay or 0.15)
    radialHoldDelaySlider.Text:SetText(string.format("Radial Hold Delay: %.2f sec", settings.radialHoldDelay or 0.15))
    radialHoldDelaySlider.Low:SetText("0.05")
    radialHoldDelaySlider.High:SetText("0.50")
    radialHoldDelaySlider:SetScript("OnValueChanged", function(self, value)
        local rounded = math_floor((value * 100) + 0.5) / 100
        self.Text:SetText(string.format("Radial Hold Delay: %.2f sec", rounded))
        addon:SetSetting("pingSystem.radialHoldDelay", rounded)
    end)
    yOffset = yOffset - 54

    local testBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    testBtn:SetSize(100, 22)
    testBtn:SetPoint("TOPLEFT", 16, yOffset)
    testBtn:SetText("Test Ping")
    testBtn:SetScript("OnClick", function()
        local ok, err = PingSystem:PushTestPing()
        if not ok then
            addon:Print("Ping System: " .. tostring(err), true)
        end
    end)

    local clearBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    clearBtn:SetSize(100, 22)
    clearBtn:SetPoint("LEFT", testBtn, "RIGHT", 10, 0)
    clearBtn:SetText("Clear")
    clearBtn:SetScript("OnClick", function()
        PingSystem:Clear()
    end)

    yOffset = yOffset - 30

    local slashHelp = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    slashHelp:SetPoint("TOPLEFT", 16, yOffset)
    slashHelp:SetText("Slash: /dcping test | /dcping menu | /dcping <type> <x> <y> [mapId] [label] | /dcping bearing <degrees> [type] [label] | /dcping clear")

    yOffset = yOffset - 18

    local keybindHelp = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    keybindHelp:SetPoint("TOPLEFT", 16, yOffset)
    keybindHelp:SetText("Keybinds: Esc -> Key Bindings -> AddOns -> DC-QoS Ping (tap G = contextual ping, hold G = radial menu)")

    return yOffset - 40
end

addon:RegisterModule("PingSystem", PingSystem)
