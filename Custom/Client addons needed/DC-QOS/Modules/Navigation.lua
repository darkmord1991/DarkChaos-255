-- ============================================================
-- DC-QoS: Navigation Module
-- ============================================================
-- 3.3.5a-friendly quest navigation marker using QuestPOI data.
-- This emulates retail super-tracked behavior as closely as possible
-- without C_Navigation/C_SuperTrack client APIs.
-- ============================================================

local addon = DCQOS

local Navigation = {
    displayName = "Navigation",
    settingKey = "navigation",
    icon = "Interface\\Icons\\INV_Misc_Map_01",
    defaults = {
        navigation = {
            enabled = true,
            useQuestWatch = true,
            useQuestLogFallback = true,
            followQuestFromTracker = true,
            autoSuperTrackWhenIdle = true,
            preferNearestQuest = true,
            showDistance = true,
            showEta = true,
            showWaypointText = true,
            colorizeArrow = true,
            pulseOnArrival = true,
            playArrivalSound = false,
            markerScale = 1.0,
            ringRadius = 240,
            distanceScreenScale = 0.45,
            frontArcDegrees = 40,
            inFrontYOffset = -120,
            arrivalDistanceYards = 8,
            autoClearManualOnReach = true,
            clearManualOnQuestSelect = true,
            updateInterval = 0.15,
            manual = {
                active = false,
                mapId = 0,
                x = 0,
                y = 0,
                label = "Waypoint",
            },
        },
    },
}

local state = {
    frame = nil,
    ticker = nil,
    eventFrame = nil,
    elapsed = 0,
    dirty = true,
    target = nil,
    lastDistance = nil,
    questContextMenuFrame = nil,
    reachedMessageAt = 0,
    lastMapSyncAt = 0,
    lastContextMenuQuestLogIndex = nil,
    lastContextMenuAt = 0,
    lastFollowClickQuestLogIndex = nil,
    lastFollowClickAt = 0,
    lastAutoSuperTrackQuestId = nil,
    lastAutoSuperTrackAt = 0,
    followedQuestLogIndex = nil,
    followedQuestId = nil,
    followedQuestTitle = nil,
    selectionSyncInProgress = false,
    selectionHooksInstalled = false,
    watchFrameHooksInstalled = false,
    poiDisplayHookInstalled = false,
    questPoiButtons = {},
    questPoiCache = {},
    questPoiLocks = {},
    lastFacing = nil,
    lastDirection = nil,
    lastRelative = nil,
    lastPoiSource = nil,
    lastProjectedRadius = nil,
    lastClamped = nil,
    lastTargetKey = nil,
    lastVisualTargetKey = nil,
    transparentUntil = nil,
    lastNavState = nil,
    lastAlpha = nil,
    lastSampleAt = nil,
    lastSampleDistance = nil,
    speedYardsPerSec = nil,
    etaSeconds = nil,
    arrivalAlertedAt = nil,
}

local NAVIGATION_TRACKED_ICON_ATLAS = "Navigation-Tracked-Icon"
local NAVIGATION_TRACKED_ARROW_ATLAS = "Navigation-Tracked-Arrow"
local TEXTURE_ATLAS = "Interface\\AddOns\\DC-QOS\\Textures\\Navigation\\ingamenavigationui"
local ICON_TEXCOORD = { 0.453125, 0.8125, 0.015625, 0.5625 }
local ARROW_TEXCOORD = { 0.015625, 0.359375, 0.5625, 0.84375 }
local ICON_WIDTH = 23
local ICON_HEIGHT = 35
local ARROW_WIDTH = 22
local ARROW_HEIGHT = 18
local ARROW_ANCHOR_Y = 60
local RUN_TRAVEL_SPEED_YARDS_PER_SEC = 7.0

local NAV_STATE_INVALID = 0
local NAV_STATE_OCCLUDED = 1
local NAV_STATE_IN_RANGE = 2
local NAV_STATE_DISABLED = 3

local NAV_TARGET_ALPHA_BY_STATE = {
    [NAV_STATE_INVALID] = 0.0,
    [NAV_STATE_OCCLUDED] = 0.6,
    [NAV_STATE_IN_RANGE] = 1.0,
    [NAV_STATE_DISABLED] = 0.0,
}

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

local mapDataLib
local NormalizeCoord

local function ResolveSuperTrackFn(primaryName, aliasName)
    local fn = _G[primaryName]
    if type(fn) == "function" then
        return fn
    end

    fn = _G[aliasName]
    if type(fn) == "function" then
        return fn
    end

    return nil
end

local superTrackShim = {
    setQuestId = nil,
    getQuestId = nil,
    setWaypoint = nil,
    getWaypoint = nil,
    clearWaypoint = nil,
    clearAll = nil,
    isTrackingAnything = nil,
    getItemName = nil,
    setQuestName = nil,
}

local function ResolveSuperTrackShim()
    superTrackShim.setQuestId = ResolveSuperTrackFn("SetSuperTrackedQuestID", "C_SuperTrack_SetSuperTrackedQuestID")
    superTrackShim.getQuestId = ResolveSuperTrackFn("GetSuperTrackedQuestID", "C_SuperTrack_GetSuperTrackedQuestID")
    superTrackShim.setWaypoint = ResolveSuperTrackFn("SetSuperTrackedQuestWaypointForMap", "C_SuperTrack_SetSuperTrackedQuestWaypointForMap")
    superTrackShim.getWaypoint = ResolveSuperTrackFn("GetSuperTrackedQuestWaypointForMap", "C_SuperTrack_GetSuperTrackedQuestWaypointForMap")
    superTrackShim.clearWaypoint = ResolveSuperTrackFn("ClearSuperTrackedQuestWaypoint", "C_SuperTrack_ClearSuperTrackedQuestWaypoint")
    superTrackShim.clearAll = ResolveSuperTrackFn("ClearAllSuperTracked", "C_SuperTrack_ClearAllSuperTracked")
    superTrackShim.isTrackingAnything = ResolveSuperTrackFn("IsSuperTrackingAnything", "C_SuperTrack_IsSuperTrackingAnything")
    superTrackShim.getItemName = ResolveSuperTrackFn("GetSuperTrackedItemName", "C_SuperTrack_GetSuperTrackedItemName")
    superTrackShim.setQuestName = ResolveSuperTrackFn("SetSuperTrackedQuestName", "C_SuperTrack_SetSuperTrackedQuestName")
end

local function ShimGetSuperTrackedQuestID()
    ResolveSuperTrackShim()

    if not superTrackShim.getQuestId then
        return nil
    end

    local ok, questId = pcall(superTrackShim.getQuestId)
    if not ok then
        return nil
    end

    questId = tonumber(questId)
    if questId and questId > 0 then
        return questId
    end

    return nil
end

local function ShimSetSuperTrackedQuestID(questId)
    ResolveSuperTrackShim()

    if not superTrackShim.setQuestId then
        return false
    end

    questId = tonumber(questId) or 0
    local ok = pcall(superTrackShim.setQuestId, questId)
    if not ok then
        return false
    end

    if questId <= 0 and superTrackShim.clearWaypoint then
        pcall(superTrackShim.clearWaypoint)
    end

    return true
end

local function ShimSetSuperTrackedQuestName(name)
    ResolveSuperTrackShim()

    if not superTrackShim.setQuestName then
        return false
    end

    local ok = pcall(superTrackShim.setQuestName, name)
    return ok == true
end

local function ShimClearAllSuperTracked()
    ResolveSuperTrackShim()

    if superTrackShim.clearAll then
        local ok = pcall(superTrackShim.clearAll)
        if ok then
            return true
        end
    end

    local anyCleared = false
    if superTrackShim.setQuestId then
        pcall(superTrackShim.setQuestId, 0)
        anyCleared = true
    end
    if superTrackShim.clearWaypoint then
        pcall(superTrackShim.clearWaypoint)
        anyCleared = true
    end

    local userWaypointToggle = ResolveSuperTrackFn("SetSuperTrackedUserWaypoint", "C_SuperTrack_SetSuperTrackedUserWaypoint")
    if userWaypointToggle then
        pcall(userWaypointToggle, false)
        anyCleared = true
    end

    return anyCleared
end

local function ShimIsSuperTrackingAnything()
    ResolveSuperTrackShim()

    if superTrackShim.isTrackingAnything then
        local ok, tracked = pcall(superTrackShim.isTrackingAnything)
        if ok then
            return tracked == true
        end
    end

    if ShimGetSuperTrackedQuestID() then
        return true
    end

    local isUserTrackedFn = ResolveSuperTrackFn("IsSuperTrackingUserWaypoint", "C_SuperTrack_IsSuperTrackingUserWaypoint")
    if isUserTrackedFn then
        local ok, tracked = pcall(isUserTrackedFn)
        if ok and tracked then
            return true
        end
    end

    return false
end

local function ShimGetSuperTrackedItemName()
    ResolveSuperTrackShim()

    if not superTrackShim.getItemName then
        return nil, nil
    end

    local ok, name, description = pcall(superTrackShim.getItemName)
    if not ok or type(name) ~= "string" or name == "" then
        return nil, nil
    end

    if type(description) ~= "string" or description == "" then
        description = nil
    end

    return name, description
end

local function ShimSetSuperTrackedQuestWaypointForMap(mapId, x, y)
    ResolveSuperTrackShim()

    if not superTrackShim.setWaypoint then
        return false
    end

    mapId = tonumber(mapId)
    x = NormalizeCoord(x)
    y = NormalizeCoord(y)
    if not mapId or mapId <= 0 or not x or not y then
        return false
    end

    local ok = pcall(superTrackShim.setWaypoint, mapId, x, y)
    return ok == true
end

local function ShimGetSuperTrackedQuestWaypointForMap(mapId)
    ResolveSuperTrackShim()

    if not superTrackShim.getWaypoint then
        return nil, nil
    end

    mapId = tonumber(mapId)
    if not mapId or mapId <= 0 then
        return nil, nil
    end

    local ok, x, y = pcall(superTrackShim.getWaypoint, mapId)
    if not ok then
        return nil, nil
    end

    x = NormalizeCoord(x)
    y = NormalizeCoord(y)
    if not x or not y then
        return nil, nil
    end

    return x, y
end

local function GetMapDataLib()
    if mapDataLib ~= nil then
        return mapDataLib
    end

    if LibStub then
        mapDataLib = LibStub("LibMapData-1.0", true)
    else
        mapDataLib = false
    end

    return mapDataLib or nil
end

NormalizeCoord = function(v)
    if not v then return nil end
    local n = tonumber(v)
    if not n then return nil end
    if n > 1 then
        n = n / 100
    end
    if n < 0 or n > 1 then
        return nil
    end
    return n
end

local function NormalizeRadians(a)
    while a > math_pi do
        a = a - (2 * math_pi)
    end
    while a < -math_pi do
        a = a + (2 * math_pi)
    end
    return a
end

local function ColorGradient(perc, ...)
    if perc <= 0 then
        return select(1, ...), select(2, ...), select(3, ...)
    end

    local num = select("#", ...)
    if perc >= 1 then
        return select(num - 2, ...), select(num - 1, ...), select(num, ...)
    end

    num = num / 3

    local segment, relperc = math.modf(perc * (num - 1))
    local r1, g1, b1 = select((segment * 3) + 1, ...), select((segment * 3) + 2, ...), select((segment * 3) + 3, ...)
    local r2, g2, b2 = select((segment * 3) + 4, ...), select((segment * 3) + 5, ...), select((segment * 3) + 6, ...)

    if not r2 or not g2 or not b2 then
        return r1, g1, b1
    end

    return r1 + (r2 - r1) * relperc,
        g1 + (g2 - g1) * relperc,
        b1 + (b2 - b1) * relperc
end

local function GetHeadingColor(relative)
    local perc = math_abs((math_pi - math_abs(relative or 0)) / math_pi)
    if perc > 1 then
        perc = 2 - perc
    end
    return ColorGradient(perc, 1, 0, 0, 1, 1, 0, 0, 1, 0)
end

local function LerpNumber(current, target, t)
    if current == nil then
        return target
    end
    return current + (target - current) * t
end

local function GetBlizzlikeEllipseRadii(settings)
    local scale = (settings.ringRadius or 240) / 240
    if scale < 0.5 then
        scale = 0.5
    elseif scale > 2.0 then
        scale = 2.0
    end

    local majorAxis = 500 * scale
    local minorAxis = 200 * scale

    if UIParent and type(UIParent.GetWidth) == "function" and type(UIParent.GetHeight) == "function" then
        local uiWidth = UIParent:GetWidth() or 0
        local uiHeight = UIParent:GetHeight() or 0
        if uiWidth > 0 and uiHeight > 0 then
            local safeMajor = math_max(120, (uiWidth * 0.5) - 56)
            local safeMinor = math_max(80, (uiHeight * 0.5) - 56)
            majorAxis = math_min(majorAxis, safeMajor)
            minorAxis = math_min(minorAxis, safeMinor)
        end
    end

    return majorAxis, minorAxis
end

local function ClampPointToEllipse(x, y, majorAxis, minorAxis)
    if not x or not y or not majorAxis or not minorAxis or majorAxis <= 0 or minorAxis <= 0 then
        return x, y, false
    end

    local majorSquared = majorAxis * majorAxis
    local minorSquared = minorAxis * minorAxis
    local outside = ((x * x) / majorSquared) + ((y * y) / minorSquared) > 1

    if not outside then
        return x, y, false
    end

    local denominator = math_sqrt((majorSquared * y * y) + (minorSquared * x * x))
    if denominator == 0 then
        return x, y, false
    end

    local ratio = (majorAxis * minorAxis) / denominator
    return x * ratio, y * ratio, true
end

local function GetEmulatedNavigationAlpha(frame, navState, isClamped, now)
    local targetAlpha = NAV_TARGET_ALPHA_BY_STATE[navState] or 0
    if targetAlpha > 0 and isClamped then
        targetAlpha = 1
    end

    if state.transparentUntil and state.transparentUntil > now then
        targetAlpha = 0
    else
        state.transparentUntil = nil
    end

    local currentAlpha = (frame and type(frame.GetAlpha) == "function") and (frame:GetAlpha() or 0) or 0
    return LerpNumber(currentAlpha, targetAlpha, 0.1)
end

local function GetNavStateName(navState)
    if navState == NAV_STATE_INVALID then
        return "invalid"
    elseif navState == NAV_STATE_OCCLUDED then
        return "occluded"
    elseif navState == NAV_STATE_IN_RANGE then
        return "in-range"
    elseif navState == NAV_STATE_DISABLED then
        return "disabled"
    end

    return tostring(navState or "n/a")
end

local function BuildTargetKey(target)
    if not target then
        return nil
    end

    return string.format(
        "%s:%s:%.4f:%.4f",
        tostring(target.source or "unknown"),
        tostring(target.questId or target.title or "none"),
        tonumber(target.x) or 0,
        tonumber(target.y) or 0
    )
end

local function ResetTravelMetrics()
    state.lastSampleAt = nil
    state.lastSampleDistance = nil
    state.speedYardsPerSec = nil
    state.etaSeconds = nil
end

local function UpdateTravelMetrics(distanceYards, targetKey)
    if state.lastTargetKey ~= targetKey then
        state.lastTargetKey = targetKey
        ResetTravelMetrics()
    end

    if not distanceYards then
        state.speedYardsPerSec = nil
        state.etaSeconds = nil
        return nil, nil
    end

    -- Use a fixed running-speed estimate so ETA remains stable even while idle.
    state.speedYardsPerSec = RUN_TRAVEL_SPEED_YARDS_PER_SEC
    if state.speedYardsPerSec and state.speedYardsPerSec > 0 then
        state.etaSeconds = distanceYards / state.speedYardsPerSec
    else
        state.etaSeconds = nil
    end

    if state.etaSeconds and (state.etaSeconds ~= state.etaSeconds or state.etaSeconds == math.huge or state.etaSeconds < 0) then
        state.etaSeconds = nil
    end

    state.lastSampleAt = nil
    state.lastSampleDistance = nil

    return state.speedYardsPerSec, state.etaSeconds
end

local function FormatEta(seconds)
    if not seconds or seconds ~= seconds or seconds == math.huge or seconds < 1 then
        return nil
    end

    local total = math_floor(seconds + 0.5)
    local mins = math_floor(total / 60)
    local secs = total % 60

    if mins >= 60 then
        local hours = math_floor(mins / 60)
        mins = mins % 60
        return string.format("%dh %02dm ETA", hours, mins)
    end

    return string.format("%d:%02d ETA", mins, secs)
end

local function TrySetTrackedIconAtlas(texture)
    if not texture or type(texture.SetAtlas) ~= "function" then
        return false
    end

    local ok = pcall(texture.SetAtlas, texture, NAVIGATION_TRACKED_ICON_ATLAS, true)
    return ok == true
end

local function TrySetTrackedArrowAtlas(texture)
    if not texture or type(texture.SetAtlas) ~= "function" then
        return false
    end

    local ok = pcall(texture.SetAtlas, texture, NAVIGATION_TRACKED_ARROW_ATLAS, true)
    return ok == true
end

local function GetWrongDirectionClampRadius(defaultRadius)
    local radius = defaultRadius or 240

    if radius < 500 then
        radius = 500
    end

    if UIParent and type(UIParent.GetWidth) == "function" and type(UIParent.GetHeight) == "function" then
        local uiWidth = UIParent:GetWidth() or 0
        local uiHeight = UIParent:GetHeight() or 0

        if uiWidth > 0 and uiHeight > 0 then
            local safeRadius = math_min((uiWidth * 0.5) - 56, (uiHeight * 0.5) - 56)
            radius = math_min(radius, math_max(120, safeRadius))
        end
    end

    return radius
end

local function ComputeRelativeHeading(facing, playerX, playerY, targetX, targetY, dxYards, dyYards)
    local dx = dxYards
    local dy = dyYards

    -- Fallback to normalized map deltas when yard deltas are unavailable.
    if type(dx) ~= "number" or type(dy) ~= "number" then
        dx = (targetX or 0) - (playerX or 0)
        dy = (targetY or 0) - (playerY or 0)
    end

    -- Invert map deltas for heading so marker guidance matches travel direction.
    local direction = Atan2(-dx, dy)
    if direction > 0 then
        direction = (2 * math_pi) - direction
    else
        direction = -direction
    end

    local relative = NormalizeRadians(direction - (facing or 0))
    local dist = math_sqrt((dx * dx) + (dy * dy))

    -- Local screen-space axes used by projection code below.
    local rightYards = -math_sin(relative) * dist
    local forwardYards = -math_cos(relative) * dist

    return direction, relative, rightYards, forwardYards
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

local function MaybeSyncCurrentZoneMap(force)
    local now = GetTime() or 0
    if not force and (now - (state.lastMapSyncAt or 0)) < 0.75 then
        return
    end

    SafeSetMapToCurrentZone()
    state.lastMapSyncAt = now
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

local function GetQuestIdFromLogIndex(questLogIndex)
    if type(GetQuestLink) == "function" then
        local questLink = GetQuestLink(questLogIndex)
        if type(questLink) == "string" then
            local linkQuestId = tonumber(questLink:match("|Hquest:(%d+):"))
            if linkQuestId and linkQuestId > 0 then
                return linkQuestId
            end
        end
    end

    if type(GetQuestLogTitle) ~= "function" then
        return questLogIndex
    end

    local _, _, _, _, _, _, _, r8, r9, r10 = GetQuestLogTitle(questLogIndex)
    if type(r10) == "number" and r10 > 0 then
        return r10
    end
    if type(r9) == "number" and r9 > 0 then
        return r9
    end
    if type(r8) == "number" and r8 > 1000 then
        return r8
    end

    return questLogIndex
end

local function ParseQuestPoiCoords(...)
    local function ReadPair(xRaw, yRaw, allowSmallIntegerX)
        local x = NormalizeCoord(xRaw)
        local y = NormalizeCoord(yRaw)
        if not x or not y then
            return nil, nil
        end

        if not allowSmallIntegerX
            and type(xRaw) == "number"
            and xRaw >= 1
            and xRaw <= 12
            and xRaw == math_floor(xRaw) then
            return nil, nil
        end

        return x, y
    end

    local x, y = ReadPair(select(2, ...), select(3, ...), true)
    if x and y then
        return x, y
    end

    x, y = ReadPair(select(3, ...), select(4, ...), true)
    if x and y then
        return x, y
    end

    x, y = ReadPair(select(4, ...), select(5, ...), true)
    if x and y then
        return x, y
    end

    x, y = ReadPair(select(1, ...), select(2, ...), false)
    if x and y then
        return x, y
    end

    return nil, nil
end

local function EnsureQuestPoiCompatibilityShim()
    if type(QuestPOIGetIconInfo) == "function" then
        return
    end

    _G.QuestPOIGetIconInfo = function(questValue)
        local questId = tonumber(questValue)
        if not questId or questId <= 0 then
            return nil, nil, nil
        end

        if type(GetNumQuestLogEntries) == "function" and type(GetQuestLogTitle) == "function" then
            local numEntries = GetNumQuestLogEntries() or 0
            if questId <= numEntries then
                local title, _, _, _, isHeader = GetQuestLogTitle(questId)
                if title and not isHeader then
                    questId = GetQuestIdFromLogIndex(questId) or questId
                end
            end
        end

        -- Prefer quest waypoint from the client shim when the quest is currently super-tracked.
        local trackedQuestId = ShimGetSuperTrackedQuestID()
        if trackedQuestId and trackedQuestId == questId then
            local mapId = (type(GetCurrentMapAreaID) == "function") and GetCurrentMapAreaID() or nil
            if mapId then
                local wx, wy = ShimGetSuperTrackedQuestWaypointForMap(mapId)
                if wx and wy then
                    return nil, wx, wy
                end
            end
        end

        -- Fallback to cached POI display points if available.
        local cached = state.questPoiCache and state.questPoiCache[questId]
        if cached and cached.points and #cached.points > 0 then
            local point = cached.points[1]
            if point and point.x and point.y then
                return nil, point.x, point.y
            end
        end

        local completed = nil
        if type(C_QuestLog.IsComplete) == "function" then
            completed = C_QuestLog.IsComplete(questId)
        end

        if C_QuestLog and type(C_QuestLog.GetQuestsOnMap) == "function" and type(GetQuestUiMapID) == "function" then
            local mapId = GetQuestUiMapID(questId)
            if mapId and mapId > 0 then
                local quests = C_QuestLog.GetQuestsOnMap(mapId)
                if quests then
                    for _, info in pairs(quests) do
                        if info and info.questID == questId then
                            return completed, info.x, info.y
                        end
                    end
                end
            end
        end

        return completed, nil, nil
    end
end

local function EnsureQuestWatchCompatibilityShim()
    if type(GetQuestWatchInfo) == "function" then
        return
    end

    _G.GetQuestWatchInfo = function(watchIndex)
        watchIndex = tonumber(watchIndex)
        if not watchIndex or watchIndex <= 0 then
            return nil
        end

        local questLogIndex = nil
        if type(GetQuestIndexForWatch) == "function" then
            questLogIndex = tonumber(GetQuestIndexForWatch(watchIndex))
            if questLogIndex and questLogIndex <= 0 then
                questLogIndex = nil
            end
        end

        local questId = nil
        if C_QuestLog and type(C_QuestLog.GetQuestIDForQuestWatchIndex) == "function" then
            questId = tonumber(C_QuestLog.GetQuestIDForQuestWatchIndex(watchIndex))
            if questId and questId <= 0 then
                questId = nil
            end
        end

        if (not questLogIndex or questLogIndex <= 0) and questId and type(GetNumQuestLogEntries) == "function" and type(GetQuestLogTitle) == "function" then
            local numEntries = GetNumQuestLogEntries() or 0
            for i = 1, numEntries do
                local _, _, _, _, isHeader = GetQuestLogTitle(i)
                if not isHeader and GetQuestIdFromLogIndex(i) == questId then
                    questLogIndex = i
                    break
                end
            end
        end

        if not questLogIndex or questLogIndex <= 0 then
            return nil
        end

        -- Return shape keeps legacy first-value quest-log-index behavior.
        return questLogIndex, nil, nil, nil, nil, nil, nil, questId
    end
end

local function ClearQuestPoiCache()
    state.questPoiCache = {}
    state.questPoiLocks = {}
end

local function ClearQuestPoiCacheKeepLocks()
    state.questPoiCache = {}
end

local function ClearQuestPoiCacheForQuest(questId)
    questId = tonumber(questId)
    if not questId or questId <= 0 then
        return
    end

    if state.questPoiCache then
        state.questPoiCache[questId] = nil
    end

    if state.questPoiLocks then
        state.questPoiLocks[questId] = nil
    end
end

local function ClearQuestPoiCacheForQuestKeepLock(questId)
    questId = tonumber(questId)
    if not questId or questId <= 0 then
        return
    end

    if state.questPoiCache then
        state.questPoiCache[questId] = nil
    end
end

local function SetQuestPoiLock(questId, x, y, mapId, source)
    questId = tonumber(questId)
    if not questId or questId <= 0 then
        return
    end

    x = NormalizeCoord(x)
    y = NormalizeCoord(y)
    if not x or not y then
        return
    end

    if not state.questPoiLocks then
        state.questPoiLocks = {}
    end

    state.questPoiLocks[questId] = {
        x = x,
        y = y,
        mapId = mapId,
        source = source,
        updatedAt = GetTime() or 0,
    }
end

local function GetQuestPoiLock(questId, mapId)
    questId = tonumber(questId)
    if not questId or questId <= 0 then
        return nil, nil, nil
    end

    local lock = state.questPoiLocks and state.questPoiLocks[questId]
    if not lock then
        return nil, nil, nil
    end

    if mapId and lock.mapId and lock.mapId ~= mapId then
        return nil, nil, nil
    end

    return lock.x, lock.y, lock.source
end

local function AddQuestPoiCachePoint(questId, x, y, mapId, source)
    questId = tonumber(questId)
    if not questId or questId <= 0 then
        return
    end

    x = NormalizeCoord(x)
    y = NormalizeCoord(y)
    if not x or not y then
        return
    end

    if not state.questPoiCache then
        state.questPoiCache = {}
    end

    local bucket = state.questPoiCache[questId]
    if not bucket then
        bucket = {
            points = {},
            keys = {},
            updatedAt = 0,
        }
        state.questPoiCache[questId] = bucket
    end

    local key = string.format("%s:%.4f:%.4f", tostring(mapId or "n/a"), x, y)
    if bucket.keys[key] then
        return
    end

    bucket.keys[key] = true
    table.insert(bucket.points, {
        x = x,
        y = y,
        mapId = mapId,
        source = source,
    })
    bucket.updatedAt = GetTime() or 0
end

local function GetPoiCoordsFromButtonAnchor(button)
    if not button
        or type(button.GetPoint) ~= "function"
        or not WorldMapDetailFrame
        or type(WorldMapDetailFrame.GetWidth) ~= "function"
        or type(WorldMapDetailFrame.GetHeight) ~= "function" then
        return nil, nil
    end

    local width = WorldMapDetailFrame:GetWidth()
    local height = WorldMapDetailFrame:GetHeight()
    if not width or width <= 0 or not height or height <= 0 then
        return nil, nil
    end

    local _, _, _, x, y = button:GetPoint()
    if type(x) ~= "number" or type(y) ~= "number" then
        return nil, nil
    end

    local detailScale = (type(WorldMapDetailFrame.GetScale) == "function") and WorldMapDetailFrame:GetScale() or 1
    local buttonScale = (type(button.GetScale) == "function") and button:GetScale() or 1
    if not buttonScale or buttonScale == 0 then
        buttonScale = 1
    end

    local scale = detailScale / buttonScale
    local cx = (x / scale) / width
    local cy = (-y / scale) / height
    return NormalizeCoord(cx), NormalizeCoord(cy)
end

local FindQuestLogIndexByQuestId

local function CacheQuestPoiDisplayEntry(parentName, buttonType, buttonIndex, questId)
    local qid = tonumber(questId)
    if not qid or qid <= 0 then
        return
    end

    local mapId = (type(GetCurrentMapAreaID) == "function") and GetCurrentMapAreaID() or nil

    if type(QuestPOIGetIconInfo) == "function" then
        local x, y = ParseQuestPoiCoords(QuestPOIGetIconInfo(buttonIndex))
        if x and y then
            AddQuestPoiCachePoint(qid, x, y, mapId, "display-index")
        end
    end

    local buttonName = "poi" .. tostring(parentName or "") .. tostring(buttonType or "") .. "_" .. tostring(buttonIndex or "")
    local poiButton = _G and _G[buttonName] or nil
    if not state.questPoiButtons then
        state.questPoiButtons = {}
    end
    state.questPoiButtons[buttonName] = { questId = qid }
    if poiButton then
        local questLogIndex = FindQuestLogIndexByQuestId(qid)
        state.questPoiButtons[buttonName].questLogIndex = questLogIndex
        if poiButton.GetName then
            local actualName = poiButton:GetName()
            if actualName and actualName ~= "" then
                state.questPoiButtons[actualName] = {
                    questId = qid,
                    questLogIndex = questLogIndex,
                }
            end
        end
        poiButton.questId = qid
        poiButton.questID = qid
        poiButton.questLogIndex = questLogIndex
        poiButton.questIndex = questLogIndex
        if poiButton.GetChildren then
            local children = { poiButton:GetChildren() }
            for i = 1, #children do
                local child = children[i]
                child.questId = qid
                child.questID = qid
                child.questLogIndex = questLogIndex
                child.questIndex = questLogIndex
            end
        end
    end
    local ax, ay = GetPoiCoordsFromButtonAnchor(poiButton)
    if ax and ay then
        AddQuestPoiCachePoint(qid, ax, ay, mapId, "display-anchor")
    end
end

local function GetCachedQuestPoiCoords(questId, playerX, playerY, mapId)
    questId = tonumber(questId)
    if not questId or questId <= 0 then
        return nil, nil, nil
    end

    local bucket = state.questPoiCache and state.questPoiCache[questId]
    if not bucket or not bucket.points or #bucket.points == 0 then
        return nil, nil, nil
    end

    local currentMapId = mapId
    if not currentMapId and type(GetCurrentMapAreaID) == "function" then
        currentMapId = GetCurrentMapAreaID()
    end

    local bestX, bestY, bestMetric
    local pointsOnMap = 0

    local function ConsiderPoint(point, fallbackMetric)
        local metric
        if playerX and playerY then
            local dx = point.x - playerX
            local dy = point.y - playerY
            metric = (dx * dx) + (dy * dy)
        else
            metric = fallbackMetric
        end

        if not bestMetric or metric < bestMetric then
            bestMetric = metric
            bestX = point.x
            bestY = point.y
        end
    end

    for i = 1, #bucket.points do
        local point = bucket.points[i]
        if not currentMapId or not point.mapId or point.mapId == currentMapId then
            pointsOnMap = pointsOnMap + 1
            ConsiderPoint(point, i)
        end
    end

    if pointsOnMap > 0 then
        return bestX, bestY, pointsOnMap
    end

    -- Do not reuse POIs from different maps; normalized coords are map-local.
    return nil, nil, 0
end

local function GetQuestPoiCoordsFromLogIndex(questLogIndex, playerX, playerY, mapId, options)
    options = options or {}
    local bypassCache = options.bypassCache == true
    local bypassLock = options.bypassLock == true or bypassCache

    local questId = GetQuestIdFromLogIndex(questLogIndex)
    local activeMapId = mapId or ((type(GetCurrentMapAreaID) == "function") and GetCurrentMapAreaID() or nil)

    if options.clearQuestCache == true then
        ClearQuestPoiCacheForQuest(questId)
    end

    if not bypassLock then
        local lockX, lockY = GetQuestPoiLock(questId, activeMapId)
        if lockX and lockY then
            return lockX, lockY, questId, "poi-lock"
        end
    end

    if not bypassCache then
        local cachedX, cachedY, cachedCount = GetCachedQuestPoiCoords(questId, playerX, playerY, mapId)
        if cachedX and cachedY then
            SetQuestPoiLock(questId, cachedX, cachedY, activeMapId, "cache")
            if cachedCount and cachedCount > 1 then
                return cachedX, cachedY, questId, "poi-cache-multi"
            end
            return cachedX, cachedY, questId, "poi-cache"
        end
    end

    if type(QuestPOIGetIconInfo) == "function" then
        -- Prefer quest-log-index lookup first for 3.3.5 tracker-selected quests.
        local qx, qy = ParseQuestPoiCoords(QuestPOIGetIconInfo(questLogIndex))
        if qx and qy then
            AddQuestPoiCachePoint(questId, qx, qy, activeMapId, "log-index")
            SetQuestPoiLock(questId, qx, qy, activeMapId, "log-index")
            return qx, qy, questId, "log-index"
        end

        if questId ~= questLogIndex then
            qx, qy = ParseQuestPoiCoords(QuestPOIGetIconInfo(questId))
            if qx and qy then
                AddQuestPoiCachePoint(questId, qx, qy, activeMapId, "quest-id")
                SetQuestPoiLock(questId, qx, qy, activeMapId, "quest-id")
                return qx, qy, questId, "quest-id"
            end
        end
    end

    return nil, nil, questId, nil
end

local function IsQuestLogIndexCandidate(value)
    if type(value) ~= "number" then
        return false, nil
    end
    if value <= 0 or value ~= math_floor(value) then
        return false, nil
    end

    local questLogIndex = value

    if type(GetQuestLogTitle) ~= "function" then
        return true, questLogIndex
    end

    local title, _, _, _, isHeader = GetQuestLogTitle(questLogIndex)
    if title and not isHeader then
        return true, questLogIndex
    end

    return false, nil
end

local function ResolveQuestLogIndexFromWatchInfo(watchIndex)
    if type(GetQuestWatchInfo) ~= "function" then
        return nil
    end

    local a, b, c, d, e, f, g, h = GetQuestWatchInfo(watchIndex)
    local candidates = { a, b, c, d, e, f, g, h }

    for i = 1, 8 do
        local ok, questLogIndex = IsQuestLogIndexCandidate(candidates[i])
        if ok then
            return questLogIndex
        end
    end

    return nil
end

local function ResolveQuestLogIndexFromWatchIndex(watchIndex)
    if type(GetQuestIndexForWatch) == "function" then
        local watchQuestLogIndex = GetQuestIndexForWatch(watchIndex)
        local ok, questLogIndex = IsQuestLogIndexCandidate(watchQuestLogIndex)
        if ok then
            return questLogIndex
        end
    end

    return ResolveQuestLogIndexFromWatchInfo(watchIndex)
end

local function ScoreQuestTarget(playerX, playerY, qx, qy, fallback)
    if playerX and playerY then
        local dx = qx - playerX
        local dy = qy - playerY
        return (dx * dx) + (dy * dy)
    end

    return fallback or 0
end

local function GetQuestTitleFromLogIndex(questLogIndex)
    if type(GetQuestLogTitle) ~= "function" then
        return "Quest " .. tostring(questLogIndex), false
    end

    local title, _, _, _, isHeader = GetQuestLogTitle(questLogIndex)
    return title, isHeader
end

local function IsQuestLogIndexCompleted(questLogIndex)
    if type(GetQuestLogTitle) ~= "function" then
        return false
    end

    local _, _, _, _, isHeader, isCollapsed, isComplete = GetQuestLogTitle(questLogIndex)
    if isHeader then
        return false
    end

    local completion = isComplete
    if completion == nil and type(isCollapsed) == "number" then
        completion = isCollapsed
    end

    if type(completion) == "number" then
        return completion > 0
    end

    if type(completion) == "boolean" then
        return completion
    end

    if type(completion) == "string" then
        local lower = string.lower(completion)
        return lower == "1" or lower == "true" or lower:find("complete", 1, true) ~= nil
    end

    return false
end

FindQuestLogIndexByQuestId = function(questId)
    if not questId or questId <= 0 then
        return nil
    end
    if type(GetNumQuestLogEntries) ~= "function" or type(GetQuestLogTitle) ~= "function" then
        return nil
    end

    local numEntries = GetNumQuestLogEntries() or 0
    for i = 1, numEntries do
        local _, _, _, _, isHeader = GetQuestLogTitle(i)
        if not isHeader and GetQuestIdFromLogIndex(i) == questId then
            return i
        end
    end

    return nil
end

local function SyncFollowStateFromShim()
    ResolveSuperTrackShim()

    local shimQuestId = ShimGetSuperTrackedQuestID()
    if not shimQuestId or shimQuestId <= 0 then
        return
    end

    if state.followedQuestId == shimQuestId then
        return
    end

    state.followedQuestId = shimQuestId
    state.followedQuestLogIndex = FindQuestLogIndexByQuestId(shimQuestId)

    if state.followedQuestLogIndex then
        local title, isHeader = GetQuestTitleFromLogIndex(state.followedQuestLogIndex)
        if title and not isHeader then
            state.followedQuestTitle = title
            return
        end
    end

    local itemName = select(1, ShimGetSuperTrackedItemName())
    if itemName then
        state.followedQuestTitle = itemName
        return
    end

    state.followedQuestTitle = "Quest " .. tostring(shimQuestId)
end

local function GetFollowedQuestTarget(playerX, playerY, mapId)
    if not addon.settings.navigation.followQuestFromTracker then
        return nil
    end

    ResolveSuperTrackShim()

    local shimQuestId = ShimGetSuperTrackedQuestID()
    if shimQuestId and shimQuestId > 0 and shimQuestId ~= state.followedQuestId then
        state.followedQuestId = shimQuestId
        state.followedQuestLogIndex = FindQuestLogIndexByQuestId(shimQuestId)
        state.followedQuestTitle = nil
    end

    local questLogIndex = state.followedQuestLogIndex
    if (not questLogIndex or questLogIndex <= 0) and state.followedQuestId then
        questLogIndex = FindQuestLogIndexByQuestId(state.followedQuestId)
        state.followedQuestLogIndex = questLogIndex
    end

    if state.followedQuestId and mapId then
        local shimX, shimY = ShimGetSuperTrackedQuestWaypointForMap(mapId)
        if shimX and shimY then
            local title = state.followedQuestTitle
            if questLogIndex and questLogIndex > 0 then
                local selectedTitle, isHeader = GetQuestTitleFromLogIndex(questLogIndex)
                if selectedTitle and not isHeader then
                    title = selectedTitle
                end
            end

            if not title then
                title = select(1, ShimGetSuperTrackedItemName())
            end

            return {
                source = "quest-selected",
                questId = state.followedQuestId,
                poiSource = "shim-waypoint",
                title = title or ("Quest " .. tostring(state.followedQuestId)),
                x = shimX,
                y = shimY,
                metric = ScoreQuestTarget(playerX, playerY, shimX, shimY, questLogIndex),
            }
        end
    end

    if not questLogIndex or questLogIndex <= 0 then
        return nil
    end

    local title, isHeader = GetQuestTitleFromLogIndex(questLogIndex)
    if isHeader then
        state.followedQuestLogIndex = nil
        return nil
    end

    local isCompleted = IsQuestLogIndexCompleted(questLogIndex)
    local poiOptions = isCompleted and { bypassCache = true, clearQuestCache = true } or nil

    local qx, qy, questId, poiSource = GetQuestPoiCoordsFromLogIndex(questLogIndex, playerX, playerY, mapId, poiOptions)
    if (not qx or not qy) and state.followedQuestId then
        local byIdIndex = FindQuestLogIndexByQuestId(state.followedQuestId)
        if byIdIndex and byIdIndex ~= questLogIndex then
            questLogIndex = byIdIndex
            title, isHeader = GetQuestTitleFromLogIndex(questLogIndex)
            if not isHeader then
                isCompleted = IsQuestLogIndexCompleted(questLogIndex)
                poiOptions = isCompleted and { bypassCache = true, clearQuestCache = true } or nil
                qx, qy, questId, poiSource = GetQuestPoiCoordsFromLogIndex(questLogIndex, playerX, playerY, mapId, poiOptions)
            end
        end
    end

    if not qx or not qy then
        return nil
    end

    state.followedQuestLogIndex = questLogIndex
    state.followedQuestId = questId
    state.followedQuestTitle = title or state.followedQuestTitle

    if qx and qy and mapId then
        ShimSetSuperTrackedQuestWaypointForMap(mapId, qx, qy)
    end

    return {
        source = "quest-selected",
        questId = questId,
        poiSource = poiSource,
        title = title or ("Quest " .. tostring(questId)),
        x = qx,
        y = qy,
        metric = ScoreQuestTarget(playerX, playerY, qx, qy, questLogIndex),
    }
end

local function GetFocusedQuestTarget(playerX, playerY, mapId)
    if type(GetQuestLogSelection) ~= "function" then
        return nil
    end

    local questLogIndex = GetQuestLogSelection()
    if not questLogIndex or questLogIndex <= 0 then
        return nil
    end

    local title, isHeader = GetQuestTitleFromLogIndex(questLogIndex)
    if isHeader then
        return nil
    end

    local qx, qy, questId, poiSource = GetQuestPoiCoordsFromLogIndex(questLogIndex, playerX, playerY, mapId)
    if not qx or not qy then
        return nil
    end

    return {
        source = "quest-focused",
        questId = questId,
        poiSource = poiSource,
        title = title or ("Quest " .. tostring(questId)),
        x = qx,
        y = qy,
        metric = ScoreQuestTarget(playerX, playerY, qx, qy, questLogIndex),
    }
end

local function GetWatchedQuestTarget(playerX, playerY, mapId)
    if not addon.settings.navigation.useQuestWatch then
        return nil
    end

    if type(GetNumQuestWatches) ~= "function"
        or type(GetQuestWatchInfo) ~= "function"
        or type(QuestPOIGetIconInfo) ~= "function" then
        return nil
    end

    local best
    local bestMetric
    local numWatches = GetNumQuestWatches() or 0

    MaybeSyncCurrentZoneMap(false)

    for i = 1, numWatches do
        local questLogIndex = ResolveQuestLogIndexFromWatchIndex(i)
        if questLogIndex and questLogIndex > 0 then
            local qx, qy, questId, poiSource = GetQuestPoiCoordsFromLogIndex(questLogIndex, playerX, playerY, mapId)
            local title = (type(GetQuestLogTitle) == "function") and GetQuestLogTitle(questLogIndex) or ("Quest " .. tostring(questId))

            if qx and qy then
                local metric = ScoreQuestTarget(playerX, playerY, qx, qy, i)

                if not best or addon.settings.navigation.preferNearestQuest and metric < bestMetric then
                    best = {
                        source = "quest",
                        questId = questId,
                        poiSource = poiSource,
                        title = title or ("Quest " .. tostring(questId)),
                        x = qx,
                        y = qy,
                    }
                    bestMetric = metric
                end

                if best and not addon.settings.navigation.preferNearestQuest then
                    break
                end
            end
        end
    end

    return best
end

local function GetQuestLogTarget(playerX, playerY, mapId)
    if not addon.settings.navigation.useQuestLogFallback then
        return nil
    end

    if type(GetNumQuestLogEntries) ~= "function"
        or type(GetQuestLogTitle) ~= "function"
        or type(QuestPOIGetIconInfo) ~= "function" then
        return nil
    end

    local best
    local bestMetric
    local numEntries = GetNumQuestLogEntries() or 0

    MaybeSyncCurrentZoneMap(false)

    for questLogIndex = 1, numEntries do
        local title, _, _, _, isHeader = GetQuestLogTitle(questLogIndex)
        if not isHeader then
            local qx, qy, questId, poiSource = GetQuestPoiCoordsFromLogIndex(questLogIndex, playerX, playerY, mapId)
            if qx and qy then
                local metric = ScoreQuestTarget(playerX, playerY, qx, qy, questLogIndex)

                if not best or addon.settings.navigation.preferNearestQuest and metric < bestMetric then
                    best = {
                        source = "quest",
                        questId = questId,
                        poiSource = poiSource,
                        title = title or ("Quest " .. tostring(questId)),
                        x = qx,
                        y = qy,
                    }
                    bestMetric = metric
                end

                if best and not addon.settings.navigation.preferNearestQuest then
                    break
                end
            end
        end
    end

    return best
end

local function GetManualTarget(mapId)
    local manual = addon.settings.navigation.manual
    if not manual or not manual.active then
        return nil
    end

    if not mapId or manual.mapId ~= mapId then
        return nil
    end

    local x = NormalizeCoord(manual.x)
    local y = NormalizeCoord(manual.y)
    if not x or not y then
        return nil
    end

    return {
        source = "manual",
        title = manual.label or "Waypoint",
        x = x,
        y = y,
    }
end

local function TryAutoSuperTrackQuestTarget(target, mapId)
    if not target or not target.questId or target.questId <= 0 then
        return false
    end
    if not addon.settings.navigation.autoSuperTrackWhenIdle then
        return false
    end
    if state.followedQuestId and state.followedQuestId > 0 then
        return false
    end

    local manual = addon.settings.navigation.manual
    if manual and manual.active then
        return false
    end

    if ShimIsSuperTrackingAnything() then
        return false
    end

    local now = GetTime() or 0
    if state.lastAutoSuperTrackQuestId == target.questId and (now - (state.lastAutoSuperTrackAt or 0)) < 1.0 then
        return false
    end

    local questLogIndex = FindQuestLogIndexByQuestId(target.questId)
    if questLogIndex and questLogIndex > 0 then
        local ok = Navigation:SetFollowQuestByLogIndex(questLogIndex, true)
        if ok then
            state.lastAutoSuperTrackQuestId = target.questId
            state.lastAutoSuperTrackAt = now
            return true
        end
    end

    if not ShimSetSuperTrackedQuestID(target.questId) then
        return false
    end

    if target.title then
        ShimSetSuperTrackedQuestName(target.title)
    end

    if mapId and target.x and target.y then
        ShimSetSuperTrackedQuestWaypointForMap(mapId, target.x, target.y)
    end

    state.followedQuestId = target.questId
    state.followedQuestTitle = target.title
    state.lastAutoSuperTrackQuestId = target.questId
    state.lastAutoSuperTrackAt = now

    return true
end

local function SelectTarget(playerX, playerY, mapId)
    local followedTarget = GetFollowedQuestTarget(playerX, playerY, mapId)
    if followedTarget then
        return followedTarget
    end

    local manualTarget = GetManualTarget(mapId)
    if manualTarget then
        return manualTarget
    end

    local focusedTarget = GetFocusedQuestTarget(playerX, playerY, mapId)
    if focusedTarget then
        if TryAutoSuperTrackQuestTarget(focusedTarget, mapId) then
            local autoTarget = GetFollowedQuestTarget(playerX, playerY, mapId)
            if autoTarget then
                return autoTarget
            end
        end
        return focusedTarget
    end

    local watchedTarget = GetWatchedQuestTarget(playerX, playerY, mapId)
    if watchedTarget then
        if TryAutoSuperTrackQuestTarget(watchedTarget, mapId) then
            local autoTarget = GetFollowedQuestTarget(playerX, playerY, mapId)
            if autoTarget then
                return autoTarget
            end
        end
        return watchedTarget
    end

    local questLogTarget = GetQuestLogTarget(playerX, playerY, mapId)
    if questLogTarget and TryAutoSuperTrackQuestTarget(questLogTarget, mapId) then
        local autoTarget = GetFollowedQuestTarget(playerX, playerY, mapId)
        if autoTarget then
            return autoTarget
        end
    end

    return questLogTarget
end

local function EnsureFrame()
    if state.frame then
        return state.frame
    end

    local frame = CreateFrame("Frame", "DCQOSNavigationFrame", UIParent)
    frame:SetSize(120, 120)
    frame:SetFrameStrata("BACKGROUND")
    frame:SetFrameLevel(5)
    frame:EnableMouse(false)
    frame:Hide()

    frame.Icon = frame:CreateTexture(nil, "ARTWORK")
    if TrySetTrackedIconAtlas(frame.Icon) then
        frame.iconBaseWidth = frame.Icon:GetWidth()
        frame.iconBaseHeight = frame.Icon:GetHeight()

        if not frame.iconBaseWidth or frame.iconBaseWidth <= 0 or not frame.iconBaseHeight or frame.iconBaseHeight <= 0 then
            frame.iconBaseWidth = ICON_WIDTH
            frame.iconBaseHeight = ICON_HEIGHT
            frame.Icon:SetSize(frame.iconBaseWidth, frame.iconBaseHeight)
        end
    else
        frame.Icon:SetTexture(TEXTURE_ATLAS)
        frame.Icon:SetTexCoord(unpack(ICON_TEXCOORD))
        frame.iconBaseWidth = ICON_WIDTH
        frame.iconBaseHeight = ICON_HEIGHT
        frame.Icon:SetSize(frame.iconBaseWidth, frame.iconBaseHeight)
    end
    frame.Icon:SetPoint("CENTER", frame, "CENTER", 0, 0)

    frame.Arrow = frame:CreateTexture(nil, "OVERLAY")
    if TrySetTrackedArrowAtlas(frame.Arrow) then
        frame.arrowBaseWidth = frame.Arrow:GetWidth()
        frame.arrowBaseHeight = frame.Arrow:GetHeight()

        if not frame.arrowBaseWidth or frame.arrowBaseWidth <= 0 or not frame.arrowBaseHeight or frame.arrowBaseHeight <= 0 then
            frame.arrowBaseWidth = ARROW_WIDTH
            frame.arrowBaseHeight = ARROW_HEIGHT
            frame.Arrow:SetSize(frame.arrowBaseWidth, frame.arrowBaseHeight)
        end
    else
        frame.Arrow:SetTexture(TEXTURE_ATLAS)
        frame.Arrow:SetTexCoord(unpack(ARROW_TEXCOORD))
        frame.arrowBaseWidth = ARROW_WIDTH
        frame.arrowBaseHeight = ARROW_HEIGHT
        frame.Arrow:SetSize(frame.arrowBaseWidth, frame.arrowBaseHeight)
    end
    frame.Arrow:SetPoint("CENTER", frame, "CENTER", 0, ARROW_ANCHOR_Y)
    frame.Arrow:Hide()

    frame.DistanceText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.DistanceText:SetPoint("TOP", frame.Icon, "BOTTOM", 0, -8)
    frame.DistanceText:SetTextColor(1.0, 0.82, 0.0)
    frame.DistanceText:SetText("")

    frame.EtaText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.EtaText:SetPoint("TOP", frame.DistanceText, "BOTTOM", 0, -2)
    frame.EtaText:SetTextColor(0.75, 0.88, 1.0)
    frame.EtaText:SetText("")
    frame.EtaText:Hide()

    frame.WaypointText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.WaypointText:SetPoint("TOP", frame.EtaText, "BOTTOM", 0, -2)
    frame.WaypointText:SetTextColor(0.85, 0.95, 1.0)
    frame.WaypointText:SetText("")
    frame.WaypointText:Hide()

    state.frame = frame
    return frame
end

local function ClearMarker()
    local frame = EnsureFrame()
    frame:Hide()
    frame:SetAlpha(1)
    frame.Icon:SetSize(frame.iconBaseWidth or ICON_WIDTH, frame.iconBaseHeight or ICON_HEIGHT)
    frame.Icon:SetVertexColor(1, 1, 1)
    frame.Arrow:SetSize(frame.arrowBaseWidth or ARROW_WIDTH, frame.arrowBaseHeight or ARROW_HEIGHT)
    frame.Arrow:SetVertexColor(1, 1, 1)
    frame.Arrow:ClearAllPoints()
    frame.Arrow:SetPoint("CENTER", frame, "CENTER", 0, ARROW_ANCHOR_Y)
    frame.Arrow:Hide()
    frame.DistanceText:SetText("")
    frame.EtaText:SetText("")
    frame.EtaText:Hide()
    if frame.WaypointText then
        frame.WaypointText:SetText("")
        frame.WaypointText:Hide()
    end
    state.target = nil
    state.lastDistance = nil
    state.lastFacing = nil
    state.lastDirection = nil
    state.lastRelative = nil
    state.lastPoiSource = nil
    state.lastProjectedRadius = nil
    state.lastClamped = nil
    state.arrivalAlertedAt = nil
    state.lastTargetKey = nil
    state.lastVisualTargetKey = nil
    state.transparentUntil = nil
    state.lastNavState = nil
    state.lastAlpha = nil
    ResetTravelMetrics()
end

local function MaybeClearManualOnArrival(target, distanceYards)
    local settings = addon.settings.navigation
    if not settings.autoClearManualOnReach then
        return
    end
    if not target or target.source ~= "manual" then
        return
    end
    if not distanceYards or distanceYards > (settings.arrivalDistanceYards or 8) then
        return
    end

    local now = GetTime() or 0
    if now - (state.reachedMessageAt or 0) < 1.5 then
        return
    end

    settings.manual.active = false
    addon:SaveSettings()
    state.reachedMessageAt = now
    if addon.Notify then
        addon:Notify("Navigation destination reached.", "success", { title = "Navigation" })
    else
        addon:Print("Navigation: destination reached.", true)
    end
end

local function GetTargetWaypointText(target, mapId)
    if not target then
        return nil
    end

    local text = nil

    if type(GetNextWaypointForMap) == "function" and mapId then
        local ok, wx, wy, waypointText = pcall(GetNextWaypointForMap, mapId)
        wx = NormalizeCoord(wx)
        wy = NormalizeCoord(wy)

        if ok and type(waypointText) == "string" and waypointText ~= "" then
            if target.x and target.y and wx and wy then
                local dx = math_abs(target.x - wx)
                local dy = math_abs(target.y - wy)
                if dx <= 0.005 and dy <= 0.005 then
                    text = waypointText
                end
            else
                text = waypointText
            end
        end
    end

    if (not text or text == "") and target.source == "manual" and target.title then
        text = target.title
    end

    if (not text or text == "") and target.questId and state.followedQuestId == target.questId and state.followedQuestTitle then
        text = state.followedQuestTitle
    end

    if not text or text == "" then
        text = target.title
    end

    if type(text) ~= "string" or text == "" then
        return nil
    end

    if string.len(text) > 72 then
        text = string.sub(text, 1, 69) .. "..."
    end

    return text
end

local function UpdateMarker()
    local settings = addon.settings.navigation
    if not settings.enabled then
        ClearMarker()
        return
    end

    MaybeSyncCurrentZoneMap(false)

    local playerX, playerY, mapId = GetPlayerMapPositionSafe()
    if not playerX or not playerY or not mapId then
        ClearMarker()
        return
    end

    local target = SelectTarget(playerX, playerY, mapId)
    if not target then
        ClearMarker()
        return
    end

    local frame = EnsureFrame()
    frame:SetScale(settings.markerScale or 1.0)

    local distanceYards, dxYards, dyYards = ComputeDistanceYards(mapId, playerX, playerY, target.x, target.y)
    state.target = target
    state.lastDistance = distanceYards

    local targetKey = BuildTargetKey(target)
    UpdateTravelMetrics(distanceYards, targetKey)

    MaybeClearManualOnArrival(target, distanceYards)

    local facing = (type(GetPlayerFacing) == "function") and (GetPlayerFacing() or 0) or 0
    local direction, relative, rightYards, forwardYards = ComputeRelativeHeading(
        facing,
        playerX,
        playerY,
        target.x,
        target.y,
        dxYards,
        dyYards
    )

    -- Damp tiny heading noise so the marker stays visually fixed when aligned.
    local headingDeadzone = math_rad(1.25)
    if math_abs(relative) < headingDeadzone then
        relative = 0
    end

    state.lastFacing = facing
    state.lastDirection = direction
    state.lastRelative = relative

    local arrivalDistance = settings.arrivalDistanceYards or 8
    local arrived = distanceYards and distanceYards <= arrivalDistance
    local now = GetTime() or 0
    local frontArc = math_rad(settings.frontArcDegrees or 40)
    local inFront = math_abs(relative) <= frontArc

    local iconBaseWidth = frame.iconBaseWidth or ICON_WIDTH
    local iconBaseHeight = frame.iconBaseHeight or ICON_HEIGHT
    local arrowBaseWidth = frame.arrowBaseWidth or ARROW_WIDTH
    local arrowBaseHeight = frame.arrowBaseHeight or ARROW_HEIGHT

    frame.Icon:SetSize(iconBaseWidth, iconBaseHeight)
    frame.Icon:SetVertexColor(1, 1, 1)
    frame.Arrow:SetSize(arrowBaseWidth, arrowBaseHeight)
    frame.Arrow:SetVertexColor(1, 1, 1)

    if arrived then
        frame.Icon:SetVertexColor(0.15, 1.0, 0.25)
        if settings.pulseOnArrival then
            local pulse = 1 + (0.12 * math_abs(math_sin(now * 7.5)))
            frame.Icon:SetSize(iconBaseWidth * pulse, iconBaseHeight * pulse)
        end
        if settings.playArrivalSound
            and type(PlaySound) == "function"
            and ((not state.arrivalAlertedAt) or (now - state.arrivalAlertedAt) > 2) then
            pcall(PlaySound, "MapPing")
            state.arrivalAlertedAt = now
        end
    else
        state.arrivalAlertedAt = nil
    end

    local projectionScale = settings.distanceScreenScale or 0.45
    if projectionScale < 0.05 then
        projectionScale = 0.05
    end

    local configuredYOffset = settings.inFrontYOffset
    local anchorYOffset
    if configuredYOffset == nil then
        anchorYOffset = -120
    elseif configuredYOffset == 130 then
        -- Migrate legacy default so the marker does not stick to top-of-screen.
        anchorYOffset = 0
    else
        anchorYOffset = configuredYOffset
    end
    if anchorYOffset > 120 then
        anchorYOffset = 120
    elseif anchorYOffset < -260 then
        anchorYOffset = -260
    end

    local ellipseMajorAxis, ellipseMinorAxis = GetBlizzlikeEllipseRadii(settings)
    local projectedX
    local projectedY
    local clampedToEllipse

    if inFront then
        -- Keep the icon on a stable "horizon" row for forward headings to avoid orbiting.
        local normalizedHeading = 0
        if frontArc > 0 then
            normalizedHeading = relative / frontArc
        end
        if normalizedHeading < -1 then
            normalizedHeading = -1
        elseif normalizedHeading > 1 then
            normalizedHeading = 1
        end

        local horizontalRadius = ellipseMajorAxis * math_max(0.25, math_min(1.0, projectionScale * 2.0))
        projectedX = normalizedHeading * horizontalRadius
        projectedY = anchorYOffset - (ellipseMinorAxis * 0.6)
        clampedToEllipse = false
    else
        -- For off-screen directions, project by heading and clamp to the nav ellipse.
        local rawX = -math_sin(relative) * ellipseMajorAxis * 2
        local rawY = (-math_cos(relative) * ellipseMinorAxis * 2) + anchorYOffset
        projectedX, projectedY, clampedToEllipse = ClampPointToEllipse(rawX, rawY, ellipseMajorAxis, ellipseMinorAxis)
        if not clampedToEllipse then
            clampedToEllipse = true
        end
    end

    local projectedRadius = math_sqrt((projectedX * projectedX) + (projectedY * projectedY))

    state.lastPoiSource = target.poiSource
    state.lastProjectedRadius = projectedRadius
    state.lastClamped = clampedToEllipse

    if state.lastVisualTargetKey ~= targetKey then
        state.lastVisualTargetKey = targetKey
        state.transparentUntil = now + 0.2
        frame:SetAlpha(0)
    end

    local navState
    if not distanceYards then
        navState = NAV_STATE_INVALID
    elseif clampedToEllipse then
        navState = NAV_STATE_OCCLUDED
    else
        navState = NAV_STATE_IN_RANGE
    end

    local alpha = GetEmulatedNavigationAlpha(frame, navState, clampedToEllipse, now)
    frame:SetAlpha(alpha)
    state.lastNavState = navState
    state.lastAlpha = alpha

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", projectedX, projectedY)

    if settings.colorizeArrow and not arrived then
        local r, g, b = GetHeadingColor(relative)
        frame.Arrow:SetVertexColor(r, g, b)
    else
        frame.Arrow:SetVertexColor(1, 1, 1)
    end

    if clampedToEllipse then
        local length = math_sqrt((projectedX * projectedX) + (projectedY * projectedY))
        if length > 0 then
            local toArrowX = projectedX / length
            local toArrowY = projectedY / length
            local angle = Atan2(toArrowX, toArrowY)

            if frame.Arrow.SetRotation then
                frame.Arrow:SetRotation(-angle)
            end

            local navFrameRadius = math_max(frame.Icon:GetWidth() or iconBaseWidth, frame.Icon:GetHeight() or iconBaseHeight)
            frame.Arrow:ClearAllPoints()
            frame.Arrow:SetPoint("CENTER", frame, "CENTER", toArrowX * navFrameRadius, toArrowY * navFrameRadius)
        else
            frame.Arrow:ClearAllPoints()
            frame.Arrow:SetPoint("CENTER", frame, "CENTER", 0, ARROW_ANCHOR_Y)
        end
        frame.Arrow:Show()
    else
        frame.Arrow:ClearAllPoints()
        frame.Arrow:SetPoint("CENTER", frame, "CENTER", 0, ARROW_ANCHOR_Y)
        frame.Arrow:Hide()
    end

    local waypointText = nil
    if settings.showWaypointText then
        waypointText = GetTargetWaypointText(target, mapId)
    end

    if (not clampedToEllipse) and settings.showDistance and distanceYards then
        if arrived then
            frame.DistanceText:SetText("Arrived")
            frame.DistanceText:SetTextColor(0.2, 1.0, 0.35)
        else
            frame.DistanceText:SetText(string.format("%d yd", math_floor(distanceYards + 0.5)))
            frame.DistanceText:SetTextColor(1.0, 0.82, 0.0)
        end
        frame.DistanceText:Show()

        local etaText = (settings.showEta and not arrived) and FormatEta(state.etaSeconds) or nil
        if etaText then
            frame.EtaText:SetText(etaText)
            frame.EtaText:Show()
        else
            frame.EtaText:SetText("")
            frame.EtaText:Hide()
        end
    else
        frame.DistanceText:SetText("")
        frame.DistanceText:Hide()
        frame.EtaText:SetText("")
        frame.EtaText:Hide()
    end

    if (not clampedToEllipse) and waypointText then
        local anchorFrame = frame.Icon
        local yOffset = -8

        if frame.EtaText:IsShown() then
            anchorFrame = frame.EtaText
            yOffset = -2
        elseif frame.DistanceText:IsShown() then
            anchorFrame = frame.DistanceText
            yOffset = -2
        end

        frame.WaypointText:ClearAllPoints()
        frame.WaypointText:SetPoint("TOP", anchorFrame, "BOTTOM", 0, yOffset)
        frame.WaypointText:SetText(waypointText)
        frame.WaypointText:Show()
    else
        frame.WaypointText:SetText("")
        frame.WaypointText:Hide()
    end

    frame:Show()
end

function Navigation:SetManualWaypoint(x, y, mapId, label)
    x = NormalizeCoord(x)
    y = NormalizeCoord(y)
    if not x or not y then
        return false, "Coordinates must be between 0 and 1, or 0 and 100."
    end

    if not mapId then
        SafeSetMapToCurrentZone()
        mapId = (type(GetCurrentMapAreaID) == "function") and GetCurrentMapAreaID() or nil
    end

    if not mapId or mapId <= 0 then
        return false, "Unable to determine current map."
    end

    local manual = addon.settings.navigation.manual
    manual.active = true
    manual.mapId = mapId
    manual.x = x
    manual.y = y
    manual.label = (label and label ~= "") and tostring(label) or "Waypoint"

    addon:SaveSettings()
    state.dirty = true

    return true
end

function Navigation:HasManualWaypoint()
    local manual = addon.settings.navigation.manual
    return manual and manual.active == true
end

function Navigation:ClearManualWaypoint()
    local manual = addon.settings.navigation.manual
    if not manual then
        return
    end

    manual.active = false
    addon:SaveSettings()
    state.dirty = true
end

function Navigation:SetEditPreviewWaypoint()
    local playerX, playerY, mapId = GetPlayerMapPositionSafe()
    if not playerX or not playerY or not mapId or mapId <= 0 then
        return false, "Unable to determine your current map position."
    end

    local xOffset = playerX > 0.84 and -0.08 or 0.08
    local yOffset = playerY > 0.85 and -0.04 or 0.04
    local previewX = math.max(0.02, math.min(0.98, playerX + xOffset))
    local previewY = math.max(0.02, math.min(0.98, playerY + yOffset))

    return self:SetManualWaypoint(previewX, previewY, mapId, "Edit Preview")
end

local function EnsureQuestIsWatched(questLogIndex)
    if type(questLogIndex) ~= "number" or questLogIndex <= 0 then
        return false
    end

    if type(IsQuestWatched) == "function" and IsQuestWatched(questLogIndex) then
        return true
    end

    if type(AddQuestWatch) ~= "function" then
        return false
    end

    local beforeCount = (type(GetNumQuestWatches) == "function") and (GetNumQuestWatches() or 0) or nil
    local ok = pcall(AddQuestWatch, questLogIndex)
    if not ok then
        return false
    end

    if type(IsQuestWatched) == "function" then
        return IsQuestWatched(questLogIndex) == true
    end

    local afterCount = (type(GetNumQuestWatches) == "function") and (GetNumQuestWatches() or 0) or nil
    if beforeCount and afterCount then
        return afterCount >= beforeCount
    end

    return true
end

local function EnsureQuestSelectionFocused(questLogIndex, writeQuestLogSelection)
    if type(questLogIndex) ~= "number" or questLogIndex <= 0 then
        return false
    end

    local selected = false

    if writeQuestLogSelection and type(QuestLog_SetSelection) == "function" then
        state.selectionSyncInProgress = true
        pcall(QuestLog_SetSelection, questLogIndex)
        state.selectionSyncInProgress = false
        selected = true
    end

    if type(WorldMapQuestShowObjectives) == "function" then
        pcall(WorldMapQuestShowObjectives, questLogIndex)
    end

    return selected
end

local function GetWorldMapObjectiveQuestLogIndex()
    local selectedQuest = nil

    if WorldMapQuestScrollChildFrame and WorldMapQuestScrollChildFrame.selected then
        selectedQuest = WorldMapQuestScrollChildFrame.selected
    elseif WORLDMAP_SETTINGS then
        selectedQuest = WORLDMAP_SETTINGS.selectedQuest
    end

    if selectedQuest then
        local questLogIndex = tonumber(selectedQuest.questLogIndex or selectedQuest.questIndex)
        if questLogIndex and questLogIndex > 0 then
            return questLogIndex
        end

        local questId = tonumber(selectedQuest.questId)
        if questId and questId > 0 then
            questLogIndex = FindQuestLogIndexByQuestId(questId)
            if questLogIndex and questLogIndex > 0 then
                return questLogIndex
            end
        end
    end

    if state.followedQuestLogIndex and state.followedQuestLogIndex > 0 then
        return state.followedQuestLogIndex
    end

    return nil
end

local function RefreshQuestTrackingVisuals()
    if type(QuestLog_Update) == "function" then
        pcall(QuestLog_Update)
    end
    if type(QuestWatch_Update) == "function" then
        pcall(QuestWatch_Update)
    end
    if type(WatchFrame_Update) == "function" then
        pcall(WatchFrame_Update)
    end

    if WorldMapFrame and type(WorldMapFrame.IsShown) == "function" and WorldMapFrame:IsShown() then
        local objectiveQuestLogIndex = GetWorldMapObjectiveQuestLogIndex()

        if type(WorldMapFrame_Update) == "function" then
            pcall(WorldMapFrame_Update)
        end
        if type(WorldMapFrame_UpdateQuests) == "function" then
            pcall(WorldMapFrame_UpdateQuests)
        end
        if type(WorldMapQuestShowObjectives) == "function" then
            if objectiveQuestLogIndex and objectiveQuestLogIndex > 0 then
                pcall(WorldMapQuestShowObjectives, objectiveQuestLogIndex)
            end
        end
        if type(QuestMapUpdateAllQuests) == "function" then
            pcall(QuestMapUpdateAllQuests)
        end
    end
end

function Navigation:SetFollowQuestByLogIndex(questLogIndex, silent)
    questLogIndex = tonumber(questLogIndex)
    if not questLogIndex or questLogIndex <= 0 then
        return false, "Invalid quest index."
    end

    local title, isHeader = GetQuestTitleFromLogIndex(questLogIndex)
    if isHeader then
        return false, "Cannot follow a quest category header."
    end

    local playerX, playerY, mapId = GetPlayerMapPositionSafe()
    local isCompleted = IsQuestLogIndexCompleted(questLogIndex)
    local poiOptions = isCompleted and { bypassCache = true, clearQuestCache = true } or nil
    local qx, qy, questId = GetQuestPoiCoordsFromLogIndex(questLogIndex, playerX, playerY, mapId, poiOptions)
    if not qx or not qy then
        MaybeSyncCurrentZoneMap(true)
        playerX, playerY, mapId = GetPlayerMapPositionSafe()
        qx, qy, questId = GetQuestPoiCoordsFromLogIndex(questLogIndex, playerX, playerY, mapId, poiOptions)
    end

    local hasPoiOnCurrentMap = qx and qy

    state.followedQuestLogIndex = questLogIndex
    state.followedQuestId = questId
    state.followedQuestTitle = title or ("Quest " .. tostring(questId or questLogIndex))

    if questId and questId > 0 then
        ShimSetSuperTrackedQuestID(questId)
        ShimSetSuperTrackedQuestName(state.followedQuestTitle)
        if hasPoiOnCurrentMap and mapId and qx and qy then
            ShimSetSuperTrackedQuestWaypointForMap(mapId, qx, qy)
        end
    end

    EnsureQuestSelectionFocused(questLogIndex, false)

    local watchSynced = EnsureQuestIsWatched(questLogIndex)
    if watchSynced then
        MaybeSyncCurrentZoneMap(true)
    end

    local minimapTrackingSynced = false
    if addon.EnsureQuestMinimapTrackingEnabled then
        minimapTrackingSynced = addon:EnsureQuestMinimapTrackingEnabled()
    end
    if minimapTrackingSynced then
        MaybeSyncCurrentZoneMap(true)
    end

    if addon.settings.navigation.clearManualOnQuestSelect then
        local manual = addon.settings.navigation.manual
        if manual and manual.active then
            manual.active = false
            addon:SaveSettings()
        end
    end

    RefreshQuestTrackingVisuals()
    if addon and addon.DelayedCall then
        addon:DelayedCall(0, RefreshQuestTrackingVisuals)
        addon:DelayedCall(0.05, RefreshQuestTrackingVisuals)
        addon:DelayedCall(0.15, RefreshQuestTrackingVisuals)
    end

    if not hasPoiOnCurrentMap then
        MaybeSyncCurrentZoneMap(true)
        playerX, playerY, mapId = GetPlayerMapPositionSafe()
        qx, qy, questId = GetQuestPoiCoordsFromLogIndex(questLogIndex, playerX, playerY, mapId, poiOptions)
        hasPoiOnCurrentMap = qx and qy

        if questId and questId > 0 then
            state.followedQuestId = questId
        end

        if hasPoiOnCurrentMap and mapId and qx and qy then
            ShimSetSuperTrackedQuestWaypointForMap(mapId, qx, qy)
        end
    end

    state.dirty = true
    if not silent then
        if hasPoiOnCurrentMap then
            if addon.Notify then
                addon:Notify("Following quest '" .. state.followedQuestTitle .. "'.", "info", { title = "Navigation" })
            else
                addon:Print("Navigation: following quest '" .. state.followedQuestTitle .. "'.", true)
            end
        else
            if addon.Notify then
                addon:Notify("Following quest '" .. state.followedQuestTitle .. "' with no POI on the current map yet.", "warning", { title = "Navigation" })
            else
                addon:Print("Navigation: following quest '" .. state.followedQuestTitle .. "' (no POI on current map yet).", true)
            end
        end
    end

    return true
end

function Navigation:ClearFollowQuest(silent)
    ShimSetSuperTrackedQuestID(0)
    ShimSetSuperTrackedQuestName(nil)

    state.followedQuestLogIndex = nil
    state.followedQuestId = nil
    state.followedQuestTitle = nil
    state.dirty = true

    if not silent then
        if addon.Notify then
            addon:Notify("Followed quest cleared.", "info", { title = "Navigation", chatFallback = false })
        else
            addon:Print("Navigation: followed quest cleared.", true)
        end
    end
end

local function TrySetFollowFromQuestLogSelection(bypassSetting)
    if not bypassSetting and not addon.settings.navigation.followQuestFromTracker then
        return false
    end
    if type(GetQuestLogSelection) ~= "function" then
        return false
    end

    local questLogIndex = GetQuestLogSelection()
    if questLogIndex and questLogIndex > 0 then
        Navigation:SetFollowQuestByLogIndex(questLogIndex, true)
        return true
    end

    return false
end

local function TrySetFollowFromWorldMapObjectiveSelection(bypassSetting)
    if not bypassSetting and not addon.settings.navigation.followQuestFromTracker then
        return false
    end

    local questLogIndex = GetWorldMapObjectiveQuestLogIndex()
    if questLogIndex and questLogIndex > 0 then
        Navigation:SetFollowQuestByLogIndex(questLogIndex, true)
        return true
    end

    return false
end

local function ScheduleFollowFromQuestLogSelection()
    TrySetFollowFromQuestLogSelection()

    if addon and addon.DelayedCall then
        addon:DelayedCall(0, TrySetFollowFromQuestLogSelection)
        addon:DelayedCall(0.05, TrySetFollowFromQuestLogSelection)
        addon:DelayedCall(0.15, TrySetFollowFromQuestLogSelection)
    end
end

local function PrimeQuestPoiButtonCacheFromVisibleButtons()
    if not _G then
        return
    end

    if not state.questPoiButtons then
        state.questPoiButtons = {}
    end

    for globalName, frame in pairs(_G) do
        if type(globalName) == "string"
            and string.sub(globalName, 1, 3) == "poi"
            and type(frame) == "table"
            and (type(frame.GetName) == "function" or type(frame.GetParent) == "function") then
            local questId = tonumber(frame.questId or frame.questID)
            if (not questId or questId <= 0) and frame.GetParent then
                local parent = frame:GetParent()
                if parent then
                    questId = tonumber(parent.questId or parent.questID)
                end
            end

            if questId and questId > 0 then
                local questLogIndex = FindQuestLogIndexByQuestId(questId)
                state.questPoiButtons[globalName] = {
                    questId = questId,
                    questLogIndex = questLogIndex,
                }
                frame.questId = questId
                frame.questID = questId
                frame.questLogIndex = questLogIndex
                frame.questIndex = questLogIndex
            end
        end
    end
end

local function ResolveWatchIndexFromClickFrame(frame)
    if not frame then
        return nil
    end

    local watchIndex = frame.watchIndex or frame.questWatchIndex or frame.watchId or frame.watchID
    watchIndex = tonumber(watchIndex)
    if watchIndex and watchIndex > 0 then
        return watchIndex
    end

    local id = frame.id or (frame.GetID and frame:GetID()) or nil
    id = tonumber(id)
    if id and id > 0 and type(GetQuestIndexForWatch) == "function" then
        local watchQuestLogIndex = tonumber(GetQuestIndexForWatch(id))
        if watchQuestLogIndex and watchQuestLogIndex > 0 then
            return id
        end
    end

    local frameName = frame.GetName and frame:GetName() or nil
    if type(frameName) == "string" then
        local nameWatchIndex = tonumber(frameName:match("WatchFrameItem(%d+)"))
        if nameWatchIndex and nameWatchIndex > 0 then
            return nameWatchIndex
        end
    end

    if frame.GetParent then
        local parent = frame:GetParent()
        if parent and parent ~= frame then
            return ResolveWatchIndexFromClickFrame(parent)
        end
    end

    return nil
end

local function TagFrameTreeWithQuestData(root, questLogIndex, questId, watchIndex, depth)
    if not root or depth > 4 then
        return
    end

    if questLogIndex and questLogIndex > 0 then
        root.questLogIndex = questLogIndex
        root.questIndex = questLogIndex
    end
    if questId and questId > 0 then
        root.questId = questId
        root.questID = questId
    end
    if watchIndex and watchIndex > 0 then
        root.watchIndex = watchIndex
        root.questWatchIndex = watchIndex
    end

    if type(root.GetChildren) ~= "function" then
        return
    end

    local children = { root:GetChildren() }
    for i = 1, #children do
        TagFrameTreeWithQuestData(children[i], questLogIndex, questId, watchIndex, depth + 1)
    end
end

local function AnnotateWatchFrameQuestIndices()
    if not WatchFrame then
        return
    end
    if type(GetNumQuestWatches) ~= "function" then
        return
    end

    local numWatches = GetNumQuestWatches() or 0
    for watchIndex = 1, numWatches do
        local watchRoot = _G and _G["WatchFrameItem" .. tostring(watchIndex)] or nil
        if watchRoot then
            local questLogIndex = ResolveQuestLogIndexFromWatchIndex(watchIndex)
            if questLogIndex and questLogIndex > 0 then
                local questId = GetQuestIdFromLogIndex(questLogIndex)
                TagFrameTreeWithQuestData(watchRoot, questLogIndex, questId, watchIndex, 0)
            end
        end
    end
end

local function ResolveQuestLogIndexFromClickFrame(frame)
    if not frame then
        return nil
    end

    local questLogIndex

    local frameName = frame.GetName and frame:GetName() or nil
    if frameName and state.questPoiButtons and state.questPoiButtons[frameName] then
        local poiEntry = state.questPoiButtons[frameName]
        questLogIndex = tonumber(poiEntry.questLogIndex)
        if (not questLogIndex or questLogIndex <= 0) and tonumber(poiEntry.questId) then
            questLogIndex = FindQuestLogIndexByQuestId(tonumber(poiEntry.questId))
        end
        if questLogIndex and questLogIndex > 0 then
            frame.questLogIndex = questLogIndex
            frame.questIndex = questLogIndex
        end
    end

    if frame.questLogIndex and frame.questLogIndex > 0 then
        questLogIndex = frame.questLogIndex
    elseif frame.questIndex and frame.questIndex > 0 then
        questLogIndex = frame.questIndex
    else
        local watchIndex = ResolveWatchIndexFromClickFrame(frame)
        if watchIndex and watchIndex > 0 then
            questLogIndex = ResolveQuestLogIndexFromWatchIndex(watchIndex)
        end

        local id = frame.id or (frame.GetID and frame:GetID()) or nil
        if (not questLogIndex or questLogIndex <= 0) and id and id > 0 then
            if type(GetQuestIndexForWatch) == "function" then
                local watchQuestLogIndex = GetQuestIndexForWatch(id)
                if watchQuestLogIndex and watchQuestLogIndex > 0 then
                    questLogIndex = watchQuestLogIndex
                end
            end

            if not questLogIndex and type(GetQuestLogTitle) == "function" then
                local _, _, _, _, isHeader = GetQuestLogTitle(id)
                if not isHeader then
                    questLogIndex = id
                end
            end
        end
    end

    local frameQuestId = frame.questId or frame.questID
    if (not questLogIndex or questLogIndex <= 0) and frameQuestId and frameQuestId > 0 then
        questLogIndex = FindQuestLogIndexByQuestId(frameQuestId)
    end

    if (not questLogIndex or questLogIndex <= 0) and frame.GetParent then
        local parent = frame:GetParent()
        if parent and parent ~= frame then
            questLogIndex = ResolveQuestLogIndexFromClickFrame(parent)
        end
    end

    return questLogIndex
end

local function WithQuestLogSelection(questLogIndex, callback)
    if type(callback) ~= "function" then
        return nil
    end

    if type(QuestLog_SetSelection) ~= "function" then
        local ok, result = pcall(callback)
        if ok then
            return result
        end
        return nil
    end

    local previousSelection = (type(GetQuestLogSelection) == "function") and GetQuestLogSelection() or nil

    state.selectionSyncInProgress = true
    pcall(QuestLog_SetSelection, questLogIndex)
    state.selectionSyncInProgress = false

    local ok, result = pcall(callback)

    if previousSelection and previousSelection > 0 then
        state.selectionSyncInProgress = true
        pcall(QuestLog_SetSelection, previousSelection)
        state.selectionSyncInProgress = false
    end

    if ok then
        return result
    end

    return nil
end

local function CanShareQuestByLogIndex(questLogIndex)
    if type(IsInGroup) ~= "function" or not IsInGroup() then
        return false
    end
    if type(QuestLogPushQuest) ~= "function" then
        return false
    end
    if type(GetQuestLogPushable) ~= "function" then
        return true
    end

    local pushable = WithQuestLogSelection(questLogIndex, function()
        local okWithArg, valueWithArg = pcall(GetQuestLogPushable, questLogIndex)
        if okWithArg and valueWithArg ~= nil then
            return valueWithArg
        end

        local okNoArg, valueNoArg = pcall(GetQuestLogPushable)
        if okNoArg then
            return valueNoArg
        end

        return nil
    end)

    if type(pushable) == "boolean" then
        return pushable
    end

    return tonumber(pushable) == 1
end

local function ShareQuestByLogIndex(questLogIndex)
    if not CanShareQuestByLogIndex(questLogIndex) then
        return false
    end

    local shared = WithQuestLogSelection(questLogIndex, function()
        local ok = pcall(QuestLogPushQuest)
        return ok == true
    end)

    return shared == true
end

local function CanAbandonQuestByLogIndex(questLogIndex)
    if type(SetAbandonQuest) ~= "function" or type(AbandonQuest) ~= "function" then
        return false
    end

    if type(GetQuestLogTitle) ~= "function" then
        return true
    end

    local _, _, _, _, isHeader = GetQuestLogTitle(questLogIndex)
    return not isHeader
end

local function AbandonQuestByLogIndex(questLogIndex)
    if not CanAbandonQuestByLogIndex(questLogIndex) then
        return false
    end

    local abandoned = WithQuestLogSelection(questLogIndex, function()
        local okSet = pcall(SetAbandonQuest)
        if not okSet then
            return false
        end

        local okAbandon = pcall(AbandonQuest)
        return okAbandon == true
    end)

    return abandoned == true
end

local function EnsureQuestContextMenuFrame()
    if state.questContextMenuFrame then
        return state.questContextMenuFrame
    end

    state.questContextMenuFrame = CreateFrame("Frame", "DCQoS_NavigationQuestContextMenu", UIParent, "UIDropDownMenuTemplate")
    return state.questContextMenuFrame
end

local function ShowQuestContextMenu(questLogIndex, frame)
    if type(EasyMenu) ~= "function" then
        return false
    end

    local title, isHeader = GetQuestTitleFromLogIndex(questLogIndex)
    if isHeader then
        return false
    end

    local questId = GetQuestIdFromLogIndex(questLogIndex)
    local trackedQuestId = ShimGetSuperTrackedQuestID() or state.followedQuestId
    local isSuperTrackedQuest = trackedQuestId and questId and trackedQuestId == questId
    local canStopTracking = type(RemoveQuestWatch) == "function"
    local canShare = CanShareQuestByLogIndex(questLogIndex)
    local canAbandon = CanAbandonQuestByLogIndex(questLogIndex)

    local menu = {
        { text = title or ("Quest " .. tostring(questId or questLogIndex)), isTitle = true, notCheckable = true },
        {
            text = isSuperTrackedQuest and "Stop Super Tracking" or "Super Track Quest",
            notCheckable = true,
            func = function()
                if isSuperTrackedQuest then
                    Navigation:ClearFollowQuest(true)
                else
                    Navigation:SetFollowQuestByLogIndex(questLogIndex, true)
                end
                RefreshQuestTrackingVisuals()
                state.dirty = true
            end,
        },
        {
            text = "View In Quest Log",
            notCheckable = true,
            func = function()
                EnsureQuestSelectionFocused(questLogIndex, true)
                state.dirty = true
            end,
        },
        {
            text = "Show Quest On Map",
            notCheckable = true,
            func = function()
                EnsureQuestSelectionFocused(questLogIndex, false)
                if type(WorldMapQuestShowObjectives) == "function" then
                    pcall(WorldMapQuestShowObjectives, questLogIndex)
                end
                MaybeSyncCurrentZoneMap(true)
                state.dirty = true
            end,
        },
        {
            text = "Stop Tracking",
            notCheckable = true,
            disabled = not canStopTracking,
            func = function()
                if canStopTracking then
                    pcall(RemoveQuestWatch, questLogIndex)
                    -- Keep follow/supertrack state independent from watch-list toggles.
                    RefreshQuestTrackingVisuals()
                    state.dirty = true
                end
            end,
        },
        {
            text = "Share Quest",
            notCheckable = true,
            disabled = not canShare,
            func = function()
                ShareQuestByLogIndex(questLogIndex)
            end,
        },
        {
            text = "Abandon Quest",
            notCheckable = true,
            disabled = not canAbandon,
            func = function()
                if AbandonQuestByLogIndex(questLogIndex) then
                    if questId and state.followedQuestId == questId then
                        Navigation:ClearFollowQuest(true)
                    end
                    RefreshQuestTrackingVisuals()
                    state.dirty = true
                end
            end,
        },
    }

    local menuFrame = EnsureQuestContextMenuFrame()
    EasyMenu(menu, menuFrame, frame or "cursor", 0, 0, "MENU")

    return true
end

local function TryShowQuestContextMenu(frame, button)
    if button ~= "RightButton" then
        return false
    end

    local questLogIndex = ResolveQuestLogIndexFromClickFrame(frame)
    if not questLogIndex or questLogIndex <= 0 then
        return false
    end

    local now = GetTime() or 0
    if state.lastContextMenuQuestLogIndex == questLogIndex and (now - (state.lastContextMenuAt or 0)) < 0.1 then
        return true
    end

    if not ShowQuestContextMenu(questLogIndex, frame) then
        return false
    end

    state.lastContextMenuQuestLogIndex = questLogIndex
    state.lastContextMenuAt = now
    return true
end

local function ShouldSuppressDuplicateFollowClick(questLogIndex)
    local now = GetTime() or 0

    if state.lastFollowClickQuestLogIndex == questLogIndex and (now - (state.lastFollowClickAt or 0)) < 0.1 then
        return true
    end

    state.lastFollowClickQuestLogIndex = questLogIndex
    state.lastFollowClickAt = now
    return false
end

local function TrySetFollowFromTrackerClickFrame(frame, silent, bypassSetting)
    if not bypassSetting and not addon.settings.navigation.followQuestFromTracker then
        return false
    end

    local questLogIndex = ResolveQuestLogIndexFromClickFrame(frame)
    if (not questLogIndex or questLogIndex <= 0) and WatchFrame then
        AnnotateWatchFrameQuestIndices()
        questLogIndex = ResolveQuestLogIndexFromClickFrame(frame)
    end
    if (not questLogIndex or questLogIndex <= 0) then
        PrimeQuestPoiButtonCacheFromVisibleButtons()
        questLogIndex = ResolveQuestLogIndexFromClickFrame(frame)
    end
    if questLogIndex and questLogIndex > 0 then
        if ShouldSuppressDuplicateFollowClick(questLogIndex) then
            return true
        end
        Navigation:SetFollowQuestByLogIndex(questLogIndex, silent)
        return true
    end

    if TrySetFollowFromWorldMapObjectiveSelection(bypassSetting) then
        return true
    end

    return false
end

local function EnsureWatchFrameHooks()
    if not addon.settings.navigation.followQuestFromTracker then
        return
    end
    if not WatchFrame or type(WatchFrame.GetChildren) ~= "function" then
        return
    end

    local function TryHookFrame(frame)
        if not frame or frame._dcqosNavClickHooked or type(frame.HookScript) ~= "function" then
            return
        end

        local hooked = false

        local okClick = pcall(frame.HookScript, frame, "OnClick", function(self, button)
            if TryShowQuestContextMenu(self, button) then
                return
            end
            if not TrySetFollowFromTrackerClickFrame(self, false) then
                ScheduleFollowFromQuestLogSelection()
            end
        end)
        if okClick then
            hooked = true
        end

        local okMouse = pcall(frame.HookScript, frame, "OnMouseUp", function(self, button)
            if TryShowQuestContextMenu(self, button) then
                return
            end
            if not TrySetFollowFromTrackerClickFrame(self, false) then
                ScheduleFollowFromQuestLogSelection()
            end
        end)
        if okMouse then
            hooked = true
        end

        if hooked then
            frame._dcqosNavClickHooked = true
        end
    end

    local function HookFrameTree(root, depth)
        if not root or depth > 3 then
            return
        end

        TryHookFrame(root)

        if type(root.GetChildren) ~= "function" then
            return
        end

        local children = { root:GetChildren() }
        for i = 1, #children do
            HookFrameTree(children[i], depth + 1)
        end
    end

    HookFrameTree(WatchFrame, 0)
    AnnotateWatchFrameQuestIndices()
    state.watchFrameHooksInstalled = true
end

local function EnsureSelectionHooks()
    if state.selectionHooksInstalled then
        return
    end
    if type(hooksecurefunc) ~= "function" then
        return
    end

    local hookedAny = false

    if type(WatchFrameItem_OnClick) == "function" then
        hooksecurefunc("WatchFrameItem_OnClick", function(frame, button)
            if TryShowQuestContextMenu(frame, button) then
                return
            end
            if not TrySetFollowFromTrackerClickFrame(frame, false) then
                ScheduleFollowFromQuestLogSelection()
            end
        end)
        hookedAny = true
    end

    if type(QuestPOIButton_OnClick) == "function" then
        hooksecurefunc("QuestPOIButton_OnClick", function(frame, button)
            if TryShowQuestContextMenu(frame, button) then
                return
            end
            if not TrySetFollowFromTrackerClickFrame(frame, false) then
                ScheduleFollowFromQuestLogSelection()
            end
        end)
        hookedAny = true
    end

    if type(WorldMapQuestPOI_OnClick) == "function" then
        hooksecurefunc("WorldMapQuestPOI_OnClick", function(frame, button)
            if TryShowQuestContextMenu(frame, button) then
                return
            end
            if not TrySetFollowFromTrackerClickFrame(frame, false) then
                ScheduleFollowFromQuestLogSelection()
            end
        end)
        hookedAny = true
    end

    if type(QuestLogTitleButton_OnClick) == "function" then
        hooksecurefunc("QuestLogTitleButton_OnClick", function(frame, button)
            if TryShowQuestContextMenu(frame, button) then
                return
            end
            if not TrySetFollowFromTrackerClickFrame(frame, false) then
                ScheduleFollowFromQuestLogSelection()
            end
        end)
        hookedAny = true
    end

    state.selectionHooksInstalled = hookedAny
end

local function EnsurePoiDisplayHook()
    if state.poiDisplayHookInstalled then
        return
    end
    if type(hooksecurefunc) ~= "function" then
        return
    end

    local hooked = false

    if type(QuestPOI_DisplayButton) == "function" then
        hooksecurefunc("QuestPOI_DisplayButton", function(parentName, buttonType, buttonIndex, questId)
            CacheQuestPoiDisplayEntry(parentName, buttonType, buttonIndex, questId)
        end)
        hooked = true
    end

    if type(WorldMapFrame_DisplayQuestPOI) == "function" then
        hooksecurefunc("WorldMapFrame_DisplayQuestPOI", function()
            PrimeQuestPoiButtonCacheFromVisibleButtons()
        end)
        hooked = true
    end

    state.poiDisplayHookInstalled = hooked
end

local function EnsureSlashCommand()
    if SlashCmdList["DCQOSNAV"] then
        return
    end

    SLASH_DCQOSNAV1 = "/dcnav"
    SlashCmdList["DCQOSNAV"] = function(msg)
        local text = msg and tostring(msg) or ""
        text = text:gsub("^%s+", ""):gsub("%s+$", "")

        if text == "" then
            addon:Print("Usage: /dcnav <x> <y> | /dcnav follow [questLogIndex] | /dcnav status | /dcnav poi [questLogIndex] | /dcnav clear", true)
            return
        end

        if text == "clear" or text == "off" then
            Navigation:ClearManualWaypoint()
            Navigation:ClearFollowQuest(true)
            ShimClearAllSuperTracked()
            if addon.Notify then
                addon:Notify("Manual waypoint and followed quest cleared.", "info", { title = "Navigation" })
            else
                addon:Print("Navigation: manual waypoint and followed quest cleared.", true)
            end
            return
        end

        if text == "clearfollow" then
            Navigation:ClearFollowQuest(false)
            return
        end

        local poiIndexArg = text:match("^poi%s+(%d+)$")
        if text == "poi" or poiIndexArg then
            local hasQuestPoiIconInfo = type(QuestPOIGetIconInfo) == "function"

            if not hasQuestPoiIconInfo then
                addon:Print("Navigation: QuestPOIGetIconInfo is unavailable, showing cache-only data.", true)
            end

            local idx = tonumber(poiIndexArg) or state.followedQuestLogIndex
            if (not idx or idx <= 0) and type(GetQuestLogSelection) == "function" then
                idx = GetQuestLogSelection()
            end

            if not idx or idx <= 0 then
                addon:Print("Navigation: no quest index available. Use /dcnav poi <questLogIndex>.", true)
                return
            end

            local questId = GetQuestIdFromLogIndex(idx)
            local i1, i2, i3, i4, i5
            local iX, iY
            local q1, q2, q3, q4, q5
            local qX, qY

            if hasQuestPoiIconInfo then
                i1, i2, i3, i4, i5 = QuestPOIGetIconInfo(idx)
                iX, iY = ParseQuestPoiCoords(i1, i2, i3, i4, i5)

                q1, q2, q3, q4, q5 = QuestPOIGetIconInfo(questId)
                qX, qY = ParseQuestPoiCoords(q1, q2, q3, q4, q5)
            end

            local playerX, playerY, mapId = GetPlayerMapPositionSafe()
            local cX, cY, cCount = GetCachedQuestPoiCoords(questId, playerX, playerY, mapId)

            local function F(v)
                if v == nil then
                    return "nil"
                end
                if type(v) == "number" then
                    return string.format("%.3f", v)
                end
                return tostring(v)
            end

            addon:Print(
                string.format(
                    "Navigation POI: idx=%s questId=%s idxRaw=[%s,%s,%s,%s,%s] idxParsed=%s,%s idRaw=[%s,%s,%s,%s,%s] idParsed=%s,%s cacheCount=%s cacheBest=%s,%s",
                    tostring(idx),
                    tostring(questId),
                    F(i1), F(i2), F(i3), F(i4), F(i5),
                    F(iX), F(iY),
                    F(q1), F(q2), F(q3), F(q4), F(q5),
                    F(qX), F(qY),
                    tostring(cCount or 0),
                    F(cX), F(cY)
                ),
                true
            )
            return
        end

        if text == "status" then
            local playerX, playerY, mapId = GetPlayerMapPositionSafe()
            local target = state.target

            local function FmtNumber(v, fmt)
                if type(v) ~= "number" then
                    return "n/a"
                end
                return string.format(fmt, v)
            end

            local targetText
            if target then
                targetText = string.format(
                    "%s q=%s %.3f, %.3f",
                    tostring(target.source or "unknown"),
                    tostring(target.questId or "n/a"),
                    target.x or 0,
                    target.y or 0
                )
            else
                targetText = "none"
            end

            addon:Print(
                string.format(
                    "Navigation status: map=%s player=%s,%s followedIndex=%s followedQuestId=%s followedTitle=%s target=%s poiSrc=%s dist=%s speed=%s eta=%s facing=%s dir=%s rel=%s proj=%s clamp=%s navState=%s alpha=%s",
                    tostring(mapId or "n/a"),
                    FmtNumber(playerX, "%.3f"),
                    FmtNumber(playerY, "%.3f"),
                    tostring(state.followedQuestLogIndex or "none"),
                    tostring(state.followedQuestId or "none"),
                    tostring(state.followedQuestTitle or "none"),
                    targetText,
                    tostring(state.lastPoiSource or (target and target.poiSource) or "n/a"),
                    FmtNumber(state.lastDistance, "%.1f yd"),
                    FmtNumber(state.speedYardsPerSec, "%.1f yd/s"),
                    FmtNumber(state.etaSeconds, "%.1f s"),
                    FmtNumber(state.lastFacing and math_deg(state.lastFacing), "%.1f deg"),
                    FmtNumber(state.lastDirection and math_deg(state.lastDirection), "%.1f deg"),
                    FmtNumber(state.lastRelative and math_deg(state.lastRelative), "%.1f deg"),
                    FmtNumber(state.lastProjectedRadius, "%.1f px"),
                    tostring(state.lastClamped and "yes" or "no"),
                    GetNavStateName(state.lastNavState),
                    FmtNumber(state.lastAlpha, "%.2f")
                ),
                true
            )
            return
        end

        local followIndex = text:match("^follow%s+(%d+)$")
        if followIndex then
            local ok, err = Navigation:SetFollowQuestByLogIndex(tonumber(followIndex), false)
            if not ok then
                addon:Print("Navigation: " .. tostring(err), true)
            end
            return
        end

        if text == "follow" then
            if type(GetQuestLogSelection) ~= "function" then
                addon:Print("Navigation: quest selection API is unavailable.", true)
                return
            end

            local selected = GetQuestLogSelection()
            if not selected or selected <= 0 then
                addon:Print("Navigation: no quest selected. Click a quest in Objectives first.", true)
                return
            end

            local ok, err = Navigation:SetFollowQuestByLogIndex(selected, false)
            if not ok then
                addon:Print("Navigation: " .. tostring(err), true)
            end
            return
        end

        local xStr, yStr = text:match("^(%-?[%d%.]+)%s+(%-?[%d%.]+)$")
        if not xStr or not yStr then
            addon:Print("Usage: /dcnav <x> <y> | /dcnav follow [questLogIndex] | /dcnav status | /dcnav poi [questLogIndex] | /dcnav clear", true)
            return
        end

        local ok, err = Navigation:SetManualWaypoint(tonumber(xStr), tonumber(yStr))
        if ok then
            if addon.Notify then
                addon:Notify(string.format("Manual waypoint set to %.1f, %.1f", tonumber(xStr), tonumber(yStr)), "success", { title = "Navigation" })
            else
                addon:Print(string.format("Navigation: manual waypoint set to %.1f, %.1f", tonumber(xStr), tonumber(yStr)), true)
            end
        else
            addon:Print("Navigation: " .. tostring(err), true)
        end
    end
end

function Navigation.OnInitialize()
    addon:Debug("Navigation module initializing")

    EnsureQuestPoiCompatibilityShim()
    EnsureQuestWatchCompatibilityShim()
    ResolveSuperTrackShim()
    SyncFollowStateFromShim()

    EnsureFrame()
    EnsureSlashCommand()
    EnsureSelectionHooks()
    EnsurePoiDisplayHook()
    EnsureWatchFrameHooks()

    addon.Navigation = Navigation
end

function Navigation.OnEnable()
    addon:Debug("Navigation module enabling")

    EnsureQuestPoiCompatibilityShim()
    EnsureQuestWatchCompatibilityShim()
    ResolveSuperTrackShim()
    SyncFollowStateFromShim()

    EnsureSelectionHooks()
    EnsurePoiDisplayHook()
    EnsureWatchFrameHooks()

    if not state.eventFrame then
        state.eventFrame = CreateFrame("Frame")
        state.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        state.eventFrame:RegisterEvent("ZONE_CHANGED")
        state.eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
        state.eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        state.eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
        state.eventFrame:RegisterEvent("QUEST_WATCH_UPDATE")
        if type(state.eventFrame.RegisterEvent) == "function" then
            pcall(state.eventFrame.RegisterEvent, state.eventFrame, "QUEST_POI_UPDATE")
        end
        state.eventFrame:SetScript("OnEvent", function(_, event)
            EnsureWatchFrameHooks()
            EnsurePoiDisplayHook()
            AnnotateWatchFrameQuestIndices()
            if event == "PLAYER_ENTERING_WORLD"
                or event == "ZONE_CHANGED"
                or event == "ZONE_CHANGED_INDOORS"
                or event == "ZONE_CHANGED_NEW_AREA" then
                ClearQuestPoiCache()
            end

            if event == "QUEST_POI_UPDATE" then
                if state.followedQuestId then
                    -- Keep the current POI lock to avoid target hopping between POIs.
                    ClearQuestPoiCacheForQuestKeepLock(state.followedQuestId)
                else
                    ClearQuestPoiCacheKeepLocks()
                end
            end

            if event == "QUEST_LOG_UPDATE" and state.followedQuestId then
                -- QUEST_LOG_UPDATE is noisy in 3.3.5a; only drop lock when quest is no longer in log.
                local followedIndex = FindQuestLogIndexByQuestId(state.followedQuestId)
                if not followedIndex then
                    ClearQuestPoiCacheForQuest(state.followedQuestId)
                    ShimSetSuperTrackedQuestID(0)
                    state.followedQuestId = nil
                    state.followedQuestLogIndex = nil
                    state.followedQuestTitle = nil
                else
                    ClearQuestPoiCacheForQuestKeepLock(state.followedQuestId)
                end
            end

            if event == "QUEST_LOG_UPDATE"
                or event == "QUEST_WATCH_UPDATE"
                or event == "QUEST_POI_UPDATE" then
                RefreshQuestTrackingVisuals()
                if addon and addon.DelayedCall then
                    addon:DelayedCall(0.05, RefreshQuestTrackingVisuals)
                end
            end

            state.dirty = true
        end)
    end

    if not state.ticker then
        state.ticker = CreateFrame("Frame")
    end

    state.ticker:SetScript("OnUpdate", function(_, elapsed)
        local settings = addon.settings.navigation
        local interval = settings.updateInterval or 0.15

        state.elapsed = state.elapsed + elapsed
        if state.elapsed < interval and not state.dirty then
            return
        end

        state.elapsed = 0
        state.dirty = false
        UpdateMarker()
    end)

    state.dirty = true
end

function Navigation.OnDisable()
    addon:Debug("Navigation module disabling")

    if state.ticker then
        state.ticker:SetScript("OnUpdate", nil)
    end

    if state.eventFrame then
        state.eventFrame:UnregisterAllEvents()
        state.eventFrame:SetScript("OnEvent", nil)
        state.eventFrame = nil
    end

    ClearQuestPoiCache()

    ClearMarker()
end

function Navigation.CreateSettings(parent)
    local settings = addon.settings.navigation

    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Navigation")

    local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    desc:SetJustifyH("LEFT")
    desc:SetText("Retail-style quest marker emulation for 3.3.5a. Left-clicking a quest in Objectives can set it as followed, right-click opens context actions; watched and quest-log POIs are used as fallback, with manual waypoints via /dcnav.")

    local yOffset = -78

    local enabledCb = addon:CreateCheckbox(parent)
    enabledCb:SetPoint("TOPLEFT", 16, yOffset)
    enabledCb.Text:SetText("Enable navigation marker")
    enabledCb:SetChecked(settings.enabled)
    enabledCb:SetScript("OnClick", function(self)
        addon:SetSetting("navigation.enabled", self:GetChecked())
        state.dirty = true
    end)
    yOffset = yOffset - 25

    local watchCb = addon:CreateCheckbox(parent)
    watchCb:SetPoint("TOPLEFT", 16, yOffset)
    watchCb.Text:SetText("Use watched quest POIs")
    watchCb:SetChecked(settings.useQuestWatch)
    watchCb:SetScript("OnClick", function(self)
        addon:SetSetting("navigation.useQuestWatch", self:GetChecked())
        state.dirty = true
    end)
    yOffset = yOffset - 25

    local logFallbackCb = addon:CreateCheckbox(parent)
    logFallbackCb:SetPoint("TOPLEFT", 16, yOffset)
    logFallbackCb.Text:SetText("Fallback to quest-log POIs when no watched quest POI is found")
    logFallbackCb:SetChecked(settings.useQuestLogFallback)
    logFallbackCb:SetScript("OnClick", function(self)
        addon:SetSetting("navigation.useQuestLogFallback", self:GetChecked())
        state.dirty = true
    end)
    yOffset = yOffset - 25

    local followTrackerCb = addon:CreateCheckbox(parent)
    followTrackerCb:SetPoint("TOPLEFT", 16, yOffset)
    followTrackerCb.Text:SetText("Clicking a quest in Objectives sets it as followed")
    followTrackerCb:SetChecked(settings.followQuestFromTracker)
    followTrackerCb:SetScript("OnClick", function(self)
        addon:SetSetting("navigation.followQuestFromTracker", self:GetChecked())
        state.dirty = true
    end)
    yOffset = yOffset - 25

    local autoSuperTrackCb = addon:CreateCheckbox(parent)
    autoSuperTrackCb:SetPoint("TOPLEFT", 16, yOffset)
    autoSuperTrackCb.Text:SetText("Auto-supertrack nearest/focused quest when nothing is tracked")
    autoSuperTrackCb:SetChecked(settings.autoSuperTrackWhenIdle)
    autoSuperTrackCb:SetScript("OnClick", function(self)
        addon:SetSetting("navigation.autoSuperTrackWhenIdle", self:GetChecked())
        state.dirty = true
    end)
    yOffset = yOffset - 25

    local clearManualOnQuestCb = addon:CreateCheckbox(parent)
    clearManualOnQuestCb:SetPoint("TOPLEFT", 16, yOffset)
    clearManualOnQuestCb.Text:SetText("Clear manual waypoint when a quest is explicitly followed")
    clearManualOnQuestCb:SetChecked(settings.clearManualOnQuestSelect)
    clearManualOnQuestCb:SetScript("OnClick", function(self)
        addon:SetSetting("navigation.clearManualOnQuestSelect", self:GetChecked())
    end)
    yOffset = yOffset - 25

    local nearestCb = addon:CreateCheckbox(parent)
    nearestCb:SetPoint("TOPLEFT", 16, yOffset)
    nearestCb.Text:SetText("Prefer nearest quest when no explicit followed quest")
    nearestCb:SetChecked(settings.preferNearestQuest)
    nearestCb:SetScript("OnClick", function(self)
        addon:SetSetting("navigation.preferNearestQuest", self:GetChecked())
        state.dirty = true
    end)
    yOffset = yOffset - 25

    local showDistCb = addon:CreateCheckbox(parent)
    showDistCb:SetPoint("TOPLEFT", 16, yOffset)
    showDistCb.Text:SetText("Show distance text when target is in front")
    showDistCb:SetChecked(settings.showDistance)
    showDistCb:SetScript("OnClick", function(self)
        addon:SetSetting("navigation.showDistance", self:GetChecked())
        state.dirty = true
    end)
    yOffset = yOffset - 25

    local showEtaCb = addon:CreateCheckbox(parent)
    showEtaCb:SetPoint("TOPLEFT", 16, yOffset)
    showEtaCb.Text:SetText("Show ETA text (running-speed estimate)")
    showEtaCb:SetChecked(settings.showEta)
    showEtaCb:SetScript("OnClick", function(self)
        addon:SetSetting("navigation.showEta", self:GetChecked())
        state.dirty = true
    end)
    yOffset = yOffset - 25

    local showWaypointTextCb = addon:CreateCheckbox(parent)
    showWaypointTextCb:SetPoint("TOPLEFT", 16, yOffset)
    showWaypointTextCb.Text:SetText("Show waypoint text under marker when unclamped")
    showWaypointTextCb:SetChecked(settings.showWaypointText)
    showWaypointTextCb:SetScript("OnClick", function(self)
        addon:SetSetting("navigation.showWaypointText", self:GetChecked())
        state.dirty = true
    end)
    yOffset = yOffset - 25

    local colorArrowCb = addon:CreateCheckbox(parent)
    colorArrowCb:SetPoint("TOPLEFT", 16, yOffset)
    colorArrowCb.Text:SetText("Color arrow by heading (red/yellow/green)")
    colorArrowCb:SetChecked(settings.colorizeArrow)
    colorArrowCb:SetScript("OnClick", function(self)
        addon:SetSetting("navigation.colorizeArrow", self:GetChecked())
        state.dirty = true
    end)
    yOffset = yOffset - 25

    local pulseArrivalCb = addon:CreateCheckbox(parent)
    pulseArrivalCb:SetPoint("TOPLEFT", 16, yOffset)
    pulseArrivalCb.Text:SetText("Pulse marker on arrival")
    pulseArrivalCb:SetChecked(settings.pulseOnArrival)
    pulseArrivalCb:SetScript("OnClick", function(self)
        addon:SetSetting("navigation.pulseOnArrival", self:GetChecked())
        state.dirty = true
    end)
    yOffset = yOffset - 25

    local arrivalSoundCb = addon:CreateCheckbox(parent)
    arrivalSoundCb:SetPoint("TOPLEFT", 16, yOffset)
    arrivalSoundCb.Text:SetText("Play arrival sound cue")
    arrivalSoundCb:SetChecked(settings.playArrivalSound)
    arrivalSoundCb:SetScript("OnClick", function(self)
        addon:SetSetting("navigation.playArrivalSound", self:GetChecked())
    end)
    yOffset = yOffset - 34

    local scaleSlider = addon:CreateSlider(parent)
    scaleSlider:SetPoint("TOPLEFT", 16, yOffset)
    scaleSlider:SetWidth(220)
    scaleSlider:SetMinMaxValues(0.5, 2.0)
    scaleSlider:SetValueStep(0.05)
    scaleSlider:SetValue(settings.markerScale or 1.0)
    scaleSlider.Text:SetText(string.format("Marker Scale: %.2f", settings.markerScale or 1.0))
    scaleSlider.Low:SetText("0.50")
    scaleSlider.High:SetText("2.00")
    scaleSlider:SetScript("OnValueChanged", function(self, value)
        local rounded = math_floor(value * 20 + 0.5) / 20
        self.Text:SetText(string.format("Marker Scale: %.2f", rounded))
        addon:SetSetting("navigation.markerScale", rounded)
        state.dirty = true
    end)
    yOffset = yOffset - 54

    local radiusSlider = addon:CreateSlider(parent)
    radiusSlider:SetPoint("TOPLEFT", 16, yOffset)
    radiusSlider:SetWidth(220)
    radiusSlider:SetMinMaxValues(120, 420)
    radiusSlider:SetValueStep(5)
    radiusSlider:SetValue(settings.ringRadius or 240)
    radiusSlider.Text:SetText("Max Marker Radius: " .. tostring(settings.ringRadius or 240))
    radiusSlider.Low:SetText("120")
    radiusSlider.High:SetText("420")
    radiusSlider:SetScript("OnValueChanged", function(self, value)
        local rounded = math_floor(value + 0.5)
        self.Text:SetText("Max Marker Radius: " .. tostring(rounded))
        addon:SetSetting("navigation.ringRadius", rounded)
        state.dirty = true
    end)
    yOffset = yOffset - 54

    local projectionSlider = addon:CreateSlider(parent)
    projectionSlider:SetPoint("TOPLEFT", 16, yOffset)
    projectionSlider:SetWidth(220)
    projectionSlider:SetMinMaxValues(0.10, 0.80)
    projectionSlider:SetValueStep(0.01)
    projectionSlider:SetValue(settings.distanceScreenScale or 0.45)
    projectionSlider.Text:SetText(string.format("Distance Projection: %.2f px/yd", settings.distanceScreenScale or 0.45))
    projectionSlider.Low:SetText("0.10")
    projectionSlider.High:SetText("0.80")
    projectionSlider:SetScript("OnValueChanged", function(self, value)
        local rounded = math_floor(value * 100 + 0.5) / 100
        self.Text:SetText(string.format("Distance Projection: %.2f px/yd", rounded))
        addon:SetSetting("navigation.distanceScreenScale", rounded)
        state.dirty = true
    end)
    yOffset = yOffset - 54

    local arcSlider = addon:CreateSlider(parent)
    arcSlider:SetPoint("TOPLEFT", 16, yOffset)
    arcSlider:SetWidth(220)
    arcSlider:SetMinMaxValues(10, 90)
    arcSlider:SetValueStep(1)
    arcSlider:SetValue(settings.frontArcDegrees or 40)
    arcSlider.Text:SetText("Front Arc: " .. tostring(settings.frontArcDegrees or 40) .. " degrees")
    arcSlider.Low:SetText("10")
    arcSlider.High:SetText("90")
    arcSlider:SetScript("OnValueChanged", function(self, value)
        local rounded = math_floor(value + 0.5)
        self.Text:SetText("Front Arc: " .. tostring(rounded) .. " degrees")
        addon:SetSetting("navigation.frontArcDegrees", rounded)
        state.dirty = true
    end)
    yOffset = yOffset - 54

    local frontOffsetSlider = addon:CreateSlider(parent)
    frontOffsetSlider:SetPoint("TOPLEFT", 16, yOffset)
    frontOffsetSlider:SetWidth(220)
    frontOffsetSlider:SetMinMaxValues(-260, 120)
    frontOffsetSlider:SetValueStep(2)
    frontOffsetSlider:SetValue(settings.inFrontYOffset or -120)
    frontOffsetSlider.Text:SetText("Screen Anchor Y Offset: " .. tostring(settings.inFrontYOffset or -120))
    frontOffsetSlider.Low:SetText("-260")
    frontOffsetSlider.High:SetText("120")
    frontOffsetSlider:SetScript("OnValueChanged", function(self, value)
        local rounded = math_floor(value + 0.5)
        self.Text:SetText("Screen Anchor Y Offset: " .. tostring(rounded))
        addon:SetSetting("navigation.inFrontYOffset", rounded)
        state.dirty = true
    end)
    yOffset = yOffset - 54

    local arrivalSlider = addon:CreateSlider(parent)
    arrivalSlider:SetPoint("TOPLEFT", 16, yOffset)
    arrivalSlider:SetWidth(220)
    arrivalSlider:SetMinMaxValues(2, 30)
    arrivalSlider:SetValueStep(1)
    arrivalSlider:SetValue(settings.arrivalDistanceYards or 8)
    arrivalSlider.Text:SetText("Arrival Distance: " .. tostring(settings.arrivalDistanceYards or 8) .. " yd")
    arrivalSlider.Low:SetText("2")
    arrivalSlider.High:SetText("30")
    arrivalSlider:SetScript("OnValueChanged", function(self, value)
        local rounded = math_floor(value + 0.5)
        self.Text:SetText("Arrival Distance: " .. tostring(rounded) .. " yd")
        addon:SetSetting("navigation.arrivalDistanceYards", rounded)
        state.dirty = true
    end)
    yOffset = yOffset - 54

    local clearOnReachCb = addon:CreateCheckbox(parent)
    clearOnReachCb:SetPoint("TOPLEFT", 16, yOffset)
    clearOnReachCb.Text:SetText("Auto-clear manual waypoint on arrival")
    clearOnReachCb:SetChecked(settings.autoClearManualOnReach)
    clearOnReachCb:SetScript("OnClick", function(self)
        addon:SetSetting("navigation.autoClearManualOnReach", self:GetChecked())
    end)
    yOffset = yOffset - 34

    local manualHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    manualHeader:SetPoint("TOPLEFT", 16, yOffset)
    manualHeader:SetText("Manual Waypoint")
    yOffset = yOffset - 24

    local xEdit = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    xEdit:SetSize(56, 20)
    xEdit:SetPoint("TOPLEFT", 16, yOffset)
    xEdit:SetAutoFocus(false)
    xEdit:SetText("")

    local yEdit = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    yEdit:SetSize(56, 20)
    yEdit:SetPoint("LEFT", xEdit, "RIGHT", 10, 0)
    yEdit:SetAutoFocus(false)
    yEdit:SetText("")

    local hint = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("LEFT", yEdit, "RIGHT", 10, 0)
    hint:SetText("x y (0-1 or 0-100)")

    yOffset = yOffset - 30

    local setBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    setBtn:SetSize(90, 22)
    setBtn:SetPoint("TOPLEFT", 16, yOffset)
    setBtn:SetText("Set Waypoint")
    setBtn:SetScript("OnClick", function()
        local x = tonumber(xEdit:GetText() or "")
        local y = tonumber(yEdit:GetText() or "")
        local ok, err = Navigation:SetManualWaypoint(x, y)
        if ok then
            addon:Print("Navigation: manual waypoint set.", true)
        else
            addon:Print("Navigation: " .. tostring(err), true)
        end
    end)

    local clearBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    clearBtn:SetSize(90, 22)
    clearBtn:SetPoint("LEFT", setBtn, "RIGHT", 10, 0)
    clearBtn:SetText("Clear")
    clearBtn:SetScript("OnClick", function()
        Navigation:ClearManualWaypoint()
        addon:Print("Navigation: manual waypoint cleared.", true)
    end)

    yOffset = yOffset - 30

    local slashHelp = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    slashHelp:SetPoint("TOPLEFT", 16, yOffset)
    slashHelp:SetText("Slash: /dcnav <x> <y>  |  /dcnav follow [questLogIndex]  |  /dcnav status  |  /dcnav poi [questLogIndex]  |  /dcnav clear")

    return yOffset - 40
end

addon:RegisterModule("Navigation", Navigation)
