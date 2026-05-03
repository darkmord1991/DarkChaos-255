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
            enableReloadMapRefresh = false,
            reloadMapRefreshMinInterval = 2.0,
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
            inFrontYOffset = 0,
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
    lastReloadMapAt = 0,
    lastQuestVisualRefreshAt = 0,
    questVisualRefreshScheduled = false,
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
    lastPoiButtonGlobalScanAt = 0,
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
    lastProjectionDebugAt = 0,
    lastProjectionDebugKey = nil,
    lastNativeProjectionStatsAt = 0,
    lastNativeProjectionStatsSig = nil,
    retailApiShimInstalled = false,
    retailSuperTrackedContentType = nil,
    retailSuperTrackedContentID = nil,
    retailSuperTrackedTrackableType = nil,
    retailSuperTrackedMapPin = nil,
    retailSuperTrackedMapPinType = nil,
    retailSuperTrackedMapPinTypeID = nil,
    retailSuperTrackedMapPinPoint = nil,
    retailSuperTrackedVignette = nil,
    retailSuperTrackedQuestName = nil,
    lastNavigationPlayerStateMapId = nil,
    lastNavigationPlayerStateX = nil,
    lastNavigationPlayerStateY = nil,
    lastNavigationPlayerStateFacing = nil,
    minimapPinContainer = nil,
    minimapPins = {},
    lastMinimapPinSig = nil,
    lastMinimapPinCount = 0,
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
local MINIMAP_DIAMETER_YARDS = {
    indoor = {
        [0] = 300,
        [1] = 240,
        [2] = 180,
        [3] = 120,
        [4] = 80,
        [5] = 50,
    },
    outdoor = {
        [0] = 466 + (2 / 3),
        [1] = 400,
        [2] = 333 + (1 / 3),
        [3] = 266 + (2 / 3),
        [4] = 200,
        [5] = 133 + (1 / 3),
    },
}
local MINIMAP_PIN_BUCKET_SIZE = 18
local MINIMAP_PIN_EDGE_PADDING = 10
local MINIMAP_PIN_MAX_COUNT = 6
local MINIMAP_WAYPOINT_SCALE = 0.55
local MINIMAP_QUEST_SCALE = 0.42
local QUEST_POI_LOCK_MAX_AGE_SEC = 1.25
local QUEST_POI_LOCK_MAX_DRIFT_YARDS = 120

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

local mapUtils = addon:GetMapUtils()
local NormalizeCoord = mapUtils.NormalizeCoord
local SafeSetMapToCurrentZone = mapUtils.SafeSetMapToCurrentZone
local GetPlayerMapPositionSafe = mapUtils.GetPlayerMapPositionSafe
local ComputeDistanceYards = mapUtils.ComputeDistanceYards

local function ResolveNamespacedFn(aliasName)
    if type(aliasName) ~= "string" then
        return nil
    end

    local namespaceName, functionName = aliasName:match("^(C_[%w]+)_(.+)$")
    if not namespaceName or not functionName then
        return nil
    end

    local namespaceTable = rawget(_G, namespaceName)
    if type(namespaceTable) ~= "table" then
        return nil
    end

    local fn = namespaceTable[functionName]
    if type(fn) == "function" then
        return fn
    end

    return nil
end

local function ResolveSuperTrackFn(primaryName, aliasName)
    local fn = primaryName and _G[primaryName] or nil
    if type(fn) == "function" then
        return fn
    end

    fn = aliasName and _G[aliasName] or nil
    if type(fn) == "function" then
        return fn
    end

    fn = ResolveNamespacedFn(aliasName)
    if type(fn) == "function" then
        return fn
    end

    return nil
end

local function ResolveNavigationNativeFn(primaryName, aliasName)
    local fn = primaryName and _G[primaryName] or nil
    if type(fn) == "function" then
        return fn
    end

    fn = aliasName and _G[aliasName] or nil
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
    getNextWaypoint = nil,
    clearWaypoint = nil,
    clearAll = nil,
    isTrackingAnything = nil,
    setUserWaypointTracked = nil,
    isUserWaypointTracked = nil,
    getItemName = nil,
    setQuestName = nil,
}

local mapWaypointShim = {
    canSetWaypointOnMap = nil,
    setUserWaypoint = nil,
    getUserWaypoint = nil,
    getUserWaypointForMap = nil,
    hasUserWaypoint = nil,
    clearUserWaypoint = nil,
}

local function ResolveSuperTrackShim()
    superTrackShim.setQuestId = ResolveSuperTrackFn("SetSuperTrackedQuestID", "C_SuperTrack_SetSuperTrackedQuestID")
    superTrackShim.getQuestId = ResolveSuperTrackFn("GetSuperTrackedQuestID", "C_SuperTrack_GetSuperTrackedQuestID")
    superTrackShim.setWaypoint = ResolveSuperTrackFn("SetSuperTrackedQuestWaypointForMap", "C_SuperTrack_SetSuperTrackedQuestWaypointForMap")
    superTrackShim.getWaypoint = ResolveSuperTrackFn("GetSuperTrackedQuestWaypointForMap", "C_SuperTrack_GetSuperTrackedQuestWaypointForMap")
    superTrackShim.getNextWaypoint = ResolveSuperTrackFn("GetNextWaypointForMap", "C_SuperTrack_GetNextWaypointForMap")
    superTrackShim.clearWaypoint = ResolveSuperTrackFn("ClearSuperTrackedQuestWaypoint", "C_SuperTrack_ClearSuperTrackedQuestWaypoint")
    superTrackShim.clearAll = ResolveSuperTrackFn("ClearAllSuperTracked", "C_SuperTrack_ClearAllSuperTracked")
    superTrackShim.isTrackingAnything = ResolveSuperTrackFn("IsSuperTrackingAnything", "C_SuperTrack_IsSuperTrackingAnything")
    superTrackShim.setUserWaypointTracked = ResolveSuperTrackFn("SetSuperTrackedUserWaypoint", "C_SuperTrack_SetSuperTrackedUserWaypoint")
    superTrackShim.isUserWaypointTracked = ResolveSuperTrackFn("IsSuperTrackingUserWaypoint", "C_SuperTrack_IsSuperTrackingUserWaypoint")
    superTrackShim.getItemName = ResolveSuperTrackFn("GetSuperTrackedItemName", "C_SuperTrack_GetSuperTrackedItemName")
    superTrackShim.setQuestName = ResolveSuperTrackFn("SetSuperTrackedQuestName", "C_SuperTrack_SetSuperTrackedQuestName")
end

local function ResolveMapWaypointShim()
    mapWaypointShim.canSetWaypointOnMap = ResolveSuperTrackFn("CanSetUserWaypointOnMap", "C_Map_CanSetUserWaypointOnMap")
    mapWaypointShim.setUserWaypoint = ResolveSuperTrackFn("SetUserWaypoint", "C_Map_SetUserWaypoint")
    mapWaypointShim.getUserWaypoint = ResolveSuperTrackFn("GetUserWaypoint", "C_Map_GetUserWaypoint")
    mapWaypointShim.getUserWaypointForMap = ResolveSuperTrackFn("GetUserWaypointPositionForMap", "C_Map_GetUserWaypointPositionForMap")
    mapWaypointShim.hasUserWaypoint = ResolveSuperTrackFn("HasUserWaypoint", "C_Map_HasUserWaypoint")
    mapWaypointShim.clearUserWaypoint = ResolveSuperTrackFn("ClearUserWaypoint", "C_Map_ClearUserWaypoint")
end

local function ShimCanSetUserWaypointOnMap(mapId)
    ResolveMapWaypointShim()

    mapId = tonumber(mapId)
    if not mapId or mapId <= 0 then
        return false
    end

    if mapWaypointShim.canSetWaypointOnMap then
        local ok, canSet = pcall(mapWaypointShim.canSetWaypointOnMap, mapId)
        if ok then
            return canSet == true
        end
    end

    return true
end

local function ShimSetUserWaypoint(mapId, x, y)
    ResolveMapWaypointShim()

    if not mapWaypointShim.setUserWaypoint then
        return false
    end

    mapId = tonumber(mapId)
    x = NormalizeCoord(x)
    y = NormalizeCoord(y)
    if not mapId or mapId <= 0 or not x or not y then
        return false
    end

    if not ShimCanSetUserWaypointOnMap(mapId) then
        return false
    end

    local ok = pcall(mapWaypointShim.setUserWaypoint, mapId, x, y)
    return ok == true
end

local function ShimGetUserWaypoint()
    ResolveMapWaypointShim()

    if not mapWaypointShim.getUserWaypoint then
        return nil, nil, nil
    end

    local ok, mapId, x, y = pcall(mapWaypointShim.getUserWaypoint)
    if not ok then
        return nil, nil, nil
    end

    mapId = tonumber(mapId)
    x = NormalizeCoord(x)
    y = NormalizeCoord(y)
    if not mapId or mapId <= 0 or not x or not y then
        return nil, nil, nil
    end

    return mapId, x, y
end

local function ShimGetUserWaypointPositionForMap(mapId)
    ResolveMapWaypointShim()

    mapId = tonumber(mapId)
    if not mapId or mapId <= 0 then
        return nil, nil
    end

    if mapWaypointShim.getUserWaypointForMap then
        local ok, x, y = pcall(mapWaypointShim.getUserWaypointForMap, mapId)
        if ok then
            x = NormalizeCoord(x)
            y = NormalizeCoord(y)
            if x and y then
                return x, y
            end
        end
    end

    local storedMapId, storedX, storedY = ShimGetUserWaypoint()
    if storedMapId and storedMapId == mapId then
        return storedX, storedY
    end

    return nil, nil
end

local function ShimHasUserWaypoint()
    ResolveMapWaypointShim()

    if mapWaypointShim.hasUserWaypoint then
        local ok, hasWaypoint = pcall(mapWaypointShim.hasUserWaypoint)
        if ok then
            return hasWaypoint == true
        end
    end

    local mapId, x, y = ShimGetUserWaypoint()
    return mapId ~= nil and x ~= nil and y ~= nil
end

local function ShimClearUserWaypoint()
    ResolveMapWaypointShim()

    if not mapWaypointShim.clearUserWaypoint then
        return false
    end

    local ok = pcall(mapWaypointShim.clearUserWaypoint)
    return ok == true
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

local function ShimSetSuperTrackedUserWaypoint(enabled)
    ResolveSuperTrackShim()

    if not superTrackShim.setUserWaypointTracked then
        return false
    end

    local ok = pcall(superTrackShim.setUserWaypointTracked, enabled == true)
    return ok == true
end

local function ShimIsSuperTrackingUserWaypoint()
    ResolveSuperTrackShim()

    if not superTrackShim.isUserWaypointTracked then
        return false
    end

    local ok, tracked = pcall(superTrackShim.isUserWaypointTracked)
    if not ok then
        return false
    end

    return tracked == true
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

    if ShimIsSuperTrackingUserWaypoint() then
        return true
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

local function ShimGetNextWaypointForMap(mapId)
    ResolveSuperTrackShim()

    if not superTrackShim.getNextWaypoint then
        return nil, nil, nil
    end

    mapId = tonumber(mapId)
    if not mapId or mapId <= 0 then
        return nil, nil, nil
    end

    local ok, x, y, text = pcall(superTrackShim.getNextWaypoint, mapId)
    if not ok then
        return nil, nil, nil
    end

    x = NormalizeCoord(x)
    y = NormalizeCoord(y)
    if not x or not y then
        return nil, nil, nil
    end

    if type(text) ~= "string" or text == "" then
        text = nil
    end

    return x, y, text
end

local function ShimGetQuestUiMapID(questId)
    if type(GetQuestUiMapID) ~= "function" then
        return nil
    end

    questId = tonumber(questId)
    if not questId or questId <= 0 then
        return nil
    end

    local ok, mapId = pcall(GetQuestUiMapID, questId)
    mapId = tonumber(mapId)
    if ok and mapId and mapId > 0 then
        return mapId
    end

    return nil
end

local function ShimGetQuestsOnMap(mapId)
    mapId = tonumber(mapId)
    if not mapId or mapId <= 0 then
        return nil
    end

    if C_QuestLog and type(C_QuestLog.GetQuestsOnMap) == "function" then
        local ok, quests = pcall(C_QuestLog.GetQuestsOnMap, mapId)
        if ok and type(quests) == "table" then
            return quests
        end
    end

    if type(GetQuestsOnMap) == "function" then
        local ok, questId, x, y = pcall(GetQuestsOnMap, mapId)
        questId = tonumber(questId)
        x = NormalizeCoord(x)
        y = NormalizeCoord(y)
        if ok and questId and questId > 0 and x and y then
            return {
                {
                    questID = questId,
                    x = x,
                    y = y,
                }
            }
        end
    end

    return nil
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

local function DebugNavigationProjection(message, force, dedupeKey)
    if not addon then
        return
    end

    local now = GetTime() or 0
    if not force and dedupeKey and dedupeKey == state.lastProjectionDebugKey and (now - (state.lastProjectionDebugAt or 0)) < 1.0 then
        return
    end

    if not force and (now - (state.lastProjectionDebugAt or 0)) < 0.35 then
        return
    end

    state.lastProjectionDebugAt = now
    state.lastProjectionDebugKey = dedupeKey

    local line = "Navigation projection: " .. tostring(message)
    local comm = addon.settings and addon.settings.communication

    if comm and comm.debugMode == true and type(addon.Debug) == "function" then
        addon:Debug(line)
        return
    end

    if type(addon.Print) == "function" then
        addon:Print("|cff888888[DC-QoS Debug]|r " .. line, true)
    end
end

local function DebugNativeProjectionStats()
    if type(state.nativeNavigationGetProjectionDebugStats) ~= "function" then
        return
    end

    local comm = addon and addon.settings and addon.settings.communication
    if not comm or comm.debugMode ~= true then
        return
    end

    local now = GetTime() or 0
    if (now - (state.lastNativeProjectionStatsAt or 0)) < 2.0 then
        return
    end

    local ok,
        callCount,
        attempts,
        success,
        fallback,
        failNoEffectiveMap,
        failNoTarget,
        failNoPlayerMovement,
        failPlayerMapTranslate,
        failMapToWorld,
        failWorldToScreen = pcall(state.nativeNavigationGetProjectionDebugStats)

    if not ok then
        return
    end

    callCount = tonumber(callCount) or 0
    attempts = tonumber(attempts) or 0
    success = tonumber(success) or 0
    fallback = tonumber(fallback) or 0
    failNoEffectiveMap = tonumber(failNoEffectiveMap) or 0
    failNoTarget = tonumber(failNoTarget) or 0
    failNoPlayerMovement = tonumber(failNoPlayerMovement) or 0
    failPlayerMapTranslate = tonumber(failPlayerMapTranslate) or 0
    failMapToWorld = tonumber(failMapToWorld) or 0
    failWorldToScreen = tonumber(failWorldToScreen) or 0

    local sig = table.concat({
        callCount,
        attempts,
        success,
        fallback,
        failNoEffectiveMap,
        failNoTarget,
        failNoPlayerMovement,
        failPlayerMapTranslate,
        failMapToWorld,
        failWorldToScreen,
    }, ":")

    if sig == state.lastNativeProjectionStatsSig then
        return
    end

    state.lastNativeProjectionStatsSig = sig
    state.lastNativeProjectionStatsAt = now

    DebugNavigationProjection(
        string.format(
            "native-stats calls=%d attempts=%d success=%d fallback=%d fail={noMap:%d noTarget:%d noPlayer:%d playerMap:%d mapToWorld:%d worldToScreen:%d}",
            callCount,
            attempts,
            success,
            fallback,
            failNoEffectiveMap,
            failNoTarget,
            failNoPlayerMovement,
            failPlayerMapTranslate,
            failMapToWorld,
            failWorldToScreen
        ),
        true,
        "native-stats"
    )
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

local function ComputeRelativeHeading(facing, playerX, playerY, targetX, targetY, dxYards, dyYards)
    local dx = dxYards
    local dy = dyYards

    -- Fallback to normalized map deltas when yard deltas are unavailable.
    if type(dx) ~= "number" or type(dy) ~= "number" then
        dx = (targetX or 0) - (playerX or 0)
        dy = (targetY or 0) - (playerY or 0)
    end

    -- Map Y increases toward south in WoW map-space, so invert dy to keep
    -- heading aligned with on-screen POI direction.
    local direction = Atan2(-dx, -dy)
    if direction > 0 then
        direction = (2 * math_pi) - direction
    else
        direction = -direction
    end

    local relative = NormalizeRadians(direction - (facing or 0))
    return direction, relative
end

local function MaybeReloadMapForNavigation(force)
    local settings = addon.settings and addon.settings.navigation
    if not settings or not settings.enableReloadMapRefresh then
        return false
    end
    if type(ReloadMap) ~= "function" then
        return false
    end
    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        return false
    end

    local minInterval = tonumber(settings.reloadMapRefreshMinInterval) or 2.0
    if minInterval < 0.25 then
        minInterval = 0.25
    end

    local requiredInterval = minInterval
    if force then
        requiredInterval = math_min(minInterval, 0.5)
    end

    local now = GetTime() or 0
    if (now - (state.lastReloadMapAt or 0)) < requiredInterval then
        return false
    end

    local ok = pcall(ReloadMap)
    if not ok then
        return false
    end

    state.lastReloadMapAt = now
    return true
end

local function MaybeSyncCurrentZoneMap(force)
    local now = GetTime() or 0
    if not force and (now - (state.lastMapSyncAt or 0)) < 0.75 then
        return
    end

    SafeSetMapToCurrentZone()
    if force then
        MaybeReloadMapForNavigation(true)
    end
    state.lastMapSyncAt = now
end

local function GetQuestIdFromLogIndex(questLogIndex)
    questLogIndex = tonumber(questLogIndex)
    if not questLogIndex or questLogIndex <= 0 then
        return nil
    end

    if type(C_QuestLog_GetQuestIDForQuestLogIndex) == "function" then
        local questId = tonumber(C_QuestLog_GetQuestIDForQuestLogIndex(questLogIndex))
        if questId and questId > 0 then
            return questId
        end
    end

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

local function GetRecurringQuestType(questId, title)
    local lookup = addon and addon.QuestRecurringLookup or nil
    if not lookup or type(lookup.Resolve) ~= "function" then
        return nil
    end

    local recurrenceType = lookup.Resolve(questId, title)
    if recurrenceType == "daily" or recurrenceType == "weekly" then
        return recurrenceType
    end

    return nil
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

local QUEST_POI_BOUNDARY_CONTAINER_KEYS = {
    "points",
    "boundary",
    "boundaryPoints",
    "polygon",
    "polygonPoints",
    "vertices",
    "vertexes",
    "areaPoints",
    "questPoiPoints",
    "poiPoints",
}

local function ParseQuestPoiBoundaryPoints(...)
    local collected = {}
    local keys = {}

    local function AddPoint(xRaw, yRaw, mapIdRaw, source)
        local x = NormalizeCoord(xRaw)
        local y = NormalizeCoord(yRaw)
        if not x or not y then
            return
        end

        local mapId = tonumber(mapIdRaw)
        if mapId and mapId <= 0 then
            mapId = nil
        end

        local key = string.format("%s:%.4f:%.4f", tostring(mapId or "n/a"), x, y)
        if keys[key] then
            return
        end

        keys[key] = true
        table.insert(collected, {
            x = x,
            y = y,
            mapId = mapId,
            source = source,
        })
    end

    local function ParseValue(value, depth, inheritedMapId, source)
        if depth > 4 or type(value) ~= "table" then
            return
        end

        local mapId = tonumber(value.mapId or value.mapID or value.uiMapID or inheritedMapId)
        if mapId and mapId <= 0 then
            mapId = nil
        end

        if type(value.x) == "number" and type(value.y) == "number" then
            AddPoint(value.x, value.y, mapId, source)
        elseif type(value[1]) == "number" and type(value[2]) == "number" then
            AddPoint(value[1], value[2], mapId, source)
        end

        for i = 1, #QUEST_POI_BOUNDARY_CONTAINER_KEYS do
            local key = QUEST_POI_BOUNDARY_CONTAINER_KEYS[i]
            local nested = value[key]
            if type(nested) == "table" then
                ParseValue(nested, depth + 1, mapId, key)
            end
        end

        for index, nested in pairs(value) do
            if type(index) == "number" and type(nested) == "table" then
                ParseValue(nested, depth + 1, mapId, source)
            end
        end
    end

    local argc = select("#", ...)
    for i = 1, argc do
        local value = select(i, ...)
        if type(value) == "table" then
            ParseValue(value, 0, nil, "vararg")
        end
    end

    if #collected >= 3 then
        return collected
    end

    return nil
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
        if C_QuestLog and type(C_QuestLog.IsComplete) == "function" then
            completed = C_QuestLog.IsComplete(questId)
        end

        local mapId = ShimGetQuestUiMapID(questId)
        if mapId and mapId > 0 then
            local quests = ShimGetQuestsOnMap(mapId)
            if quests then
                for _, info in pairs(quests) do
                    if info and info.questID == questId then
                        return completed, info.x, info.y
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

local function BuildUiMapPoint(mapId, x, y)
    mapId = tonumber(mapId)
    x = NormalizeCoord(x)
    y = NormalizeCoord(y)
    if not mapId or mapId <= 0 or not x or not y then
        return nil
    end

    return {
        uiMapID = mapId,
        mapID = mapId,
        mapId = mapId,
        x = x,
        y = y,
    }
end

local function NormalizeUiMapPointArgs(mapIdOrPoint, x, y)
    local mapId = mapIdOrPoint
    if type(mapIdOrPoint) == "table" then
        mapId = mapIdOrPoint.uiMapID or mapIdOrPoint.mapID or mapIdOrPoint.mapId
        x = x or mapIdOrPoint.x or mapIdOrPoint.normalizedX
        y = y or mapIdOrPoint.y or mapIdOrPoint.normalizedY

        if (x == nil or y == nil) and type(mapIdOrPoint.GetPosition) == "function" then
            local ok, posX, posY = pcall(mapIdOrPoint.GetPosition, mapIdOrPoint)
            if ok then
                x = x or posX
                y = y or posY
            end
        end

        if (not mapId or tonumber(mapId) == 0) and type(mapIdOrPoint.GetMapID) == "function" then
            local ok, resolvedMapId = pcall(mapIdOrPoint.GetMapID, mapIdOrPoint)
            if ok then
                mapId = resolvedMapId
            end
        end
    end

    return BuildUiMapPoint(mapId, x, y)
end

local function BuildUserWaypointHyperlink(point)
    point = type(point) == "table" and point or nil
    if not point then
        return nil
    end

    local mapId = tonumber(point.uiMapID or point.mapID or point.mapId)
    local x = NormalizeCoord(point.x or point.normalizedX)
    local y = NormalizeCoord(point.y or point.normalizedY)
    if not mapId or mapId <= 0 or not x or not y then
        return nil
    end

    local label = (type(_G.WORLD_MAP) == "string" and _G.WORLD_MAP ~= "") and _G.WORLD_MAP or "Waypoint"
    return string.format("|Hworldmap:%d:%.6f:%.6f|h[%s]|h", mapId, x, y, label)
end

local function ParseUserWaypointHyperlink(hyperlink)
    if type(hyperlink) ~= "string" or hyperlink == "" then
        return nil
    end

    local mapId, x, y = hyperlink:match("worldmap:(%-?%d+):([%-%d%.]+):([%-%d%.]+)")
    if not mapId then
        return nil
    end

    return BuildUiMapPoint(tonumber(mapId), tonumber(x), tonumber(y))
end

local function NormalizeSuperTrackedContentType(contentType)
    local normalized = tostring(contentType or "")
    normalized = normalized:gsub("[%s_%-]", "")
    normalized = normalized:lower()

    if normalized == "" then
        return nil
    end
    if normalized == "quest" then
        return "quest"
    end
    if normalized == "userwaypoint" or normalized == "waypoint" then
        return "userWaypoint"
    end
    if normalized == "mappin" or normalized == "pin" then
        return "mapPin"
    end
    if normalized == "vignette" then
        return "vignette"
    end
    if normalized == "content" then
        return "content"
    end

    return normalized
end

local function SuperTrackingTypeToEnum(typeToken)
    typeToken = NormalizeSuperTrackedContentType(typeToken)
    if not typeToken then
        return nil
    end

    local enumTable = _G.Enum and _G.Enum.SuperTrackingType
    if type(enumTable) ~= "table" then
        return typeToken
    end

    if typeToken == "quest" and enumTable.Quest ~= nil then
        return enumTable.Quest
    end
    if typeToken == "userWaypoint" and enumTable.UserWaypoint ~= nil then
        return enumTable.UserWaypoint
    end
    if typeToken == "mapPin" and enumTable.MapPin ~= nil then
        return enumTable.MapPin
    end
    if typeToken == "vignette" and enumTable.Vignette ~= nil then
        return enumTable.Vignette
    end
    if typeToken == "content" and enumTable.Content ~= nil then
        return enumTable.Content
    end

    return typeToken
end

local function SuperTrackingMapPinTypeToEnum(pinType)
    if pinType == nil then
        return nil
    end

    local enumTable = _G.Enum and _G.Enum.SuperTrackingMapPinType
    if type(pinType) == "number" then
        return pinType
    end

    local normalized = tostring(pinType):gsub("[%s_%-]", ""):lower()
    if normalized == "" then
        return nil
    end

    if type(enumTable) == "table" then
        if normalized == "areapoi" and enumTable.AreaPOI ~= nil then
            return enumTable.AreaPOI
        end
        if normalized == "questoffer" and enumTable.QuestOffer ~= nil then
            return enumTable.QuestOffer
        end
        if normalized == "taxinode" and enumTable.TaxiNode ~= nil then
            return enumTable.TaxiNode
        end
        if normalized == "digsite" and enumTable.DigSite ~= nil then
            return enumTable.DigSite
        end
    end

    if normalized == "areapoi" then
        return 0
    end
    if normalized == "questoffer" then
        return 1
    end
    if normalized == "taxinode" then
        return 2
    end
    if normalized == "digsite" then
        return 3
    end

    return nil
end

local function ResolveHighestPrioritySuperTrackingTypeToken()
    local contentType = NormalizeSuperTrackedContentType(state.retailSuperTrackedContentType)
    if contentType then
        return contentType
    end

    if state.retailSuperTrackedMapPin then
        return "mapPin"
    end

    if state.retailSuperTrackedVignette then
        return "vignette"
    end

    if ShimGetSuperTrackedQuestID() then
        return "quest"
    end

    if ShimIsSuperTrackingUserWaypoint() then
        return "userWaypoint"
    end

    return nil
end

local function EnsureRetailNavigationApiShims()
    if not state.retailApiShimInstalled then
        state.retailApiShimInstalled = true
    end

    local superTrackApi = rawget(_G, "C_SuperTrack")
    if type(superTrackApi) ~= "table" then
        superTrackApi = {}
        _G.C_SuperTrack = superTrackApi
    end

    local mapApi = rawget(_G, "C_Map")
    if type(mapApi) ~= "table" then
        mapApi = {}
        _G.C_Map = mapApi
    end

    local navigationApi = rawget(_G, "C_Navigation")
    if type(navigationApi) ~= "table" then
        navigationApi = {}
        _G.C_Navigation = navigationApi
    end

    local questLogApi = rawget(_G, "C_QuestLog")
    if type(questLogApi) ~= "table" then
        questLogApi = {}
        _G.C_QuestLog = questLogApi
    end

    local setSuperTrackedQuestId = type(_G.SetSuperTrackedQuestID) == "function" and _G.SetSuperTrackedQuestID or nil
    local getSuperTrackedQuestId = type(_G.GetSuperTrackedQuestID) == "function" and _G.GetSuperTrackedQuestID or nil
    local setSuperTrackedWaypoint = type(_G.SetSuperTrackedQuestWaypointForMap) == "function" and _G.SetSuperTrackedQuestWaypointForMap or nil
    local getSuperTrackedWaypoint = type(_G.GetSuperTrackedQuestWaypointForMap) == "function" and _G.GetSuperTrackedQuestWaypointForMap or nil
    local getNextWaypoint = type(_G.GetNextWaypointForMap) == "function" and _G.GetNextWaypointForMap or nil
    local clearSuperTrackedWaypoint = type(_G.ClearSuperTrackedQuestWaypoint) == "function" and _G.ClearSuperTrackedQuestWaypoint or nil
    local clearAllSuperTracked = type(_G.ClearAllSuperTracked) == "function" and _G.ClearAllSuperTracked or nil
    local isSuperTrackingAnything = type(_G.IsSuperTrackingAnything) == "function" and _G.IsSuperTrackingAnything or nil
    local setSuperTrackedUserWaypoint = type(_G.SetSuperTrackedUserWaypoint) == "function" and _G.SetSuperTrackedUserWaypoint or nil
    local isSuperTrackingUserWaypoint = type(_G.IsSuperTrackingUserWaypoint) == "function" and _G.IsSuperTrackingUserWaypoint or nil
    local getSuperTrackedItemName = type(_G.GetSuperTrackedItemName) == "function" and _G.GetSuperTrackedItemName or nil
    local setSuperTrackedQuestName = type(_G.SetSuperTrackedQuestName) == "function" and _G.SetSuperTrackedQuestName or nil
    local getSuperTrackedQuestName = type(_G.GetSuperTrackedQuestName) == "function" and _G.GetSuperTrackedQuestName or nil
    local getNavigationFrame = ResolveNavigationNativeFn("GetNavigationFrame", "C_Navigation_GetFrame")
    local getNavigationFrameState = ResolveNavigationNativeFn("GetNavigationFrameState", "C_Navigation_GetFrameState")
    local setNavigationPlayerState = ResolveNavigationNativeFn("SetNavigationPlayerState", "C_Navigation_SetPlayerState")
    local getNavigationTargetState = ResolveNavigationNativeFn("GetNavigationTargetState", "C_Navigation_GetTargetState")
    local getNavigationDistance = ResolveNavigationNativeFn("GetNavigationDistance", "C_Navigation_GetDistance")
    local getNavigationDistanceSquared = ResolveNavigationNativeFn("GetNavigationDistanceSquared", "C_Navigation_GetDistanceSquared")
    local hasNavigationValidScreenPosition = ResolveNavigationNativeFn("HasNavigationValidScreenPosition", "C_Navigation_HasValidScreenPosition")
    local wasNavigationFrameClampedToScreen = ResolveNavigationNativeFn("WasNavigationFrameClampedToScreen", "C_Navigation_WasClampedToScreen")
    local getNavigationProjectionDebugStats = ResolveNavigationNativeFn("GetNavigationProjectionDebugStats", "C_Navigation_GetProjectionDebugStats")

    -- Cache resolved native function handles so projection updates can call the
    -- exact export even when only shimmed namespaces are present globally.
    state.nativeNavigationGetFrameState = getNavigationFrameState
    state.nativeNavigationSetPlayerState = setNavigationPlayerState
    state.nativeNavigationHasValidScreenPosition = hasNavigationValidScreenPosition
    state.nativeNavigationWasClampedToScreen = wasNavigationFrameClampedToScreen
    state.nativeNavigationGetProjectionDebugStats = getNavigationProjectionDebugStats
    state.nativeSetSuperTrackedQuestID = setSuperTrackedQuestId
    state.nativeSetSuperTrackedQuestName = setSuperTrackedQuestName
    state.nativeSetSuperTrackedQuestWaypointForMap = setSuperTrackedWaypoint

    local function CallNativeNavigationFrameState()
        if not getNavigationFrameState then
            return nil, nil, nil, nil
        end

        local ok, screenX, screenY, navState, clamped = pcall(getNavigationFrameState)
        if not ok then
            return nil, nil, nil, nil
        end

        screenX = tonumber(screenX)
        screenY = tonumber(screenY)
        navState = tonumber(navState)
        if type(clamped) ~= "boolean" then
            clamped = nil
        end

        return screenX, screenY, navState, clamped
    end

    if type(superTrackApi.SetSuperTrackedQuestID) ~= "function" then
        superTrackApi.SetSuperTrackedQuestID = function(questId)
            if not setSuperTrackedQuestId then
                return false
            end
            local ok, result = pcall(setSuperTrackedQuestId, questId)
            if not ok then
                return false
            end

            if tonumber(questId) and tonumber(questId) > 0 then
                state.retailSuperTrackedContentType = "quest"
                state.retailSuperTrackedContentID = tonumber(questId)
                state.retailSuperTrackedTrackableType = nil
                state.retailSuperTrackedMapPin = nil
                state.retailSuperTrackedMapPinType = nil
                state.retailSuperTrackedMapPinTypeID = nil
                state.retailSuperTrackedMapPinPoint = nil
                state.retailSuperTrackedVignette = nil
                state.retailSuperTrackedQuestName = nil
            elseif state.retailSuperTrackedContentType == "quest" then
                state.retailSuperTrackedContentType = nil
                state.retailSuperTrackedContentID = nil
                state.retailSuperTrackedTrackableType = nil
                state.retailSuperTrackedQuestName = nil
            end

            return result ~= false
        end
    end

    if type(superTrackApi.GetSuperTrackedQuestID) ~= "function" then
        superTrackApi.GetSuperTrackedQuestID = function()
            if not getSuperTrackedQuestId then
                return nil
            end
            local ok, questId = pcall(getSuperTrackedQuestId)
            if not ok then
                return nil
            end
            return questId
        end
    end

    if type(superTrackApi.SetSuperTrackedQuestWaypointForMap) ~= "function" then
        superTrackApi.SetSuperTrackedQuestWaypointForMap = function(mapId, x, y)
            if not setSuperTrackedWaypoint then
                return false
            end
            local ok, result = pcall(setSuperTrackedWaypoint, mapId, x, y)
            if not ok then
                return false
            end
            return result ~= false
        end
    end

    if type(superTrackApi.GetSuperTrackedQuestWaypointForMap) ~= "function" then
        superTrackApi.GetSuperTrackedQuestWaypointForMap = function(mapId)
            if not getSuperTrackedWaypoint then
                return nil, nil
            end
            local ok, x, y = pcall(getSuperTrackedWaypoint, mapId)
            if not ok then
                return nil, nil
            end
            return x, y
        end
    end

    if type(superTrackApi.GetNextWaypointForMap) ~= "function" then
        superTrackApi.GetNextWaypointForMap = function(mapId)
            if not getNextWaypoint then
                return nil, nil, nil
            end
            local ok, x, y, text = pcall(getNextWaypoint, mapId)
            if not ok then
                return nil, nil, nil
            end
            return x, y, text
        end
    end

    if type(superTrackApi.ClearSuperTrackedQuestWaypoint) ~= "function" then
        superTrackApi.ClearSuperTrackedQuestWaypoint = function()
            if not clearSuperTrackedWaypoint then
                return false
            end
            local ok, result = pcall(clearSuperTrackedWaypoint)
            if not ok then
                return false
            end
            return result ~= false
        end
    end

    if type(superTrackApi.ClearAllSuperTracked) ~= "function" then
        superTrackApi.ClearAllSuperTracked = function()
            state.retailSuperTrackedContentType = nil
            state.retailSuperTrackedContentID = nil
            state.retailSuperTrackedTrackableType = nil
            state.retailSuperTrackedMapPin = nil
            state.retailSuperTrackedMapPinType = nil
            state.retailSuperTrackedMapPinTypeID = nil
            state.retailSuperTrackedMapPinPoint = nil
            state.retailSuperTrackedVignette = nil
            state.retailSuperTrackedQuestName = nil

            if not clearAllSuperTracked then
                return true
            end

            local ok, result = pcall(clearAllSuperTracked)
            if not ok then
                return false
            end

            return result ~= false
        end
    end

    if type(superTrackApi.IsSuperTrackingAnything) ~= "function" then
        superTrackApi.IsSuperTrackingAnything = function()
            if not isSuperTrackingAnything then
                return false
            end
            local ok, tracked = pcall(isSuperTrackingAnything)
            if not ok then
                return false
            end
            return tracked == true
        end
    end

    if type(superTrackApi.SetSuperTrackedUserWaypoint) ~= "function" then
        superTrackApi.SetSuperTrackedUserWaypoint = function(enabled)
            if not setSuperTrackedUserWaypoint then
                return false
            end
            local ok, result = pcall(setSuperTrackedUserWaypoint, enabled)
            if not ok then
                return false
            end

            if enabled == true then
                state.retailSuperTrackedContentType = "userWaypoint"
                state.retailSuperTrackedContentID = nil
                state.retailSuperTrackedTrackableType = nil
                state.retailSuperTrackedMapPin = nil
                state.retailSuperTrackedMapPinType = nil
                state.retailSuperTrackedMapPinTypeID = nil
                state.retailSuperTrackedMapPinPoint = nil
                state.retailSuperTrackedVignette = nil
            elseif state.retailSuperTrackedContentType == "userWaypoint" then
                state.retailSuperTrackedContentType = nil
                state.retailSuperTrackedContentID = nil
                state.retailSuperTrackedTrackableType = nil
            end

            return result ~= false
        end
    end

    if type(superTrackApi.IsSuperTrackingUserWaypoint) ~= "function" then
        superTrackApi.IsSuperTrackingUserWaypoint = function()
            if not isSuperTrackingUserWaypoint then
                return false
            end
            local ok, tracked = pcall(isSuperTrackingUserWaypoint)
            if not ok then
                return false
            end
            return tracked == true
        end
    end

    if type(superTrackApi.GetSuperTrackedItemName) ~= "function" then
        superTrackApi.GetSuperTrackedItemName = function()
            if not getSuperTrackedItemName then
                return nil, nil
            end
            local ok, name, description = pcall(getSuperTrackedItemName)
            if not ok then
                return nil, nil
            end
            return name, description
        end
    end

    if type(superTrackApi.SetSuperTrackedQuestName) ~= "function" then
        superTrackApi.SetSuperTrackedQuestName = function(name)
            if not setSuperTrackedQuestName then
                return false
            end
            local ok, result = pcall(setSuperTrackedQuestName, name)
            if not ok then
                return false
            end

            if type(name) == "string" and name ~= "" then
                state.retailSuperTrackedContentType = "quest"
                state.retailSuperTrackedContentID = name
                state.retailSuperTrackedTrackableType = nil
                state.retailSuperTrackedMapPin = nil
                state.retailSuperTrackedMapPinType = nil
                state.retailSuperTrackedMapPinTypeID = nil
                state.retailSuperTrackedMapPinPoint = nil
                state.retailSuperTrackedVignette = nil
                state.retailSuperTrackedQuestName = name
            end

            return result ~= false
        end
    end

    if type(superTrackApi.GetSuperTrackedQuestName) ~= "function" then
        superTrackApi.GetSuperTrackedQuestName = function()
            if getSuperTrackedQuestName then
                local ok, name = pcall(getSuperTrackedQuestName)
                if ok and type(name) == "string" and name ~= "" then
                    return name
                end
            end

            if type(state.retailSuperTrackedQuestName) == "string" and state.retailSuperTrackedQuestName ~= "" then
                return state.retailSuperTrackedQuestName
            end

            if type(state.followedQuestTitle) == "string" and state.followedQuestTitle ~= "" then
                return state.followedQuestTitle
            end

            return nil
        end
    end

    if type(superTrackApi.GetHighestPrioritySuperTrackingType) ~= "function" then
        superTrackApi.GetHighestPrioritySuperTrackingType = function()
            local typeToken = ResolveHighestPrioritySuperTrackingTypeToken()
            return SuperTrackingTypeToEnum(typeToken)
        end
    end

    if type(superTrackApi.GetSuperTrackedContent) ~= "function" then
        superTrackApi.GetSuperTrackedContent = function()
            local contentType = NormalizeSuperTrackedContentType(state.retailSuperTrackedContentType)
            if contentType == "content" then
                return state.retailSuperTrackedTrackableType, state.retailSuperTrackedContentID
            end
            return nil, nil
        end
    end

    if type(superTrackApi.SetSuperTrackedContent) ~= "function" then
        superTrackApi.SetSuperTrackedContent = function(contentType, contentID)
            local normalizedType = NormalizeSuperTrackedContentType(contentType)
            if not normalizedType then
                state.retailSuperTrackedContentType = nil
                state.retailSuperTrackedContentID = nil
                state.retailSuperTrackedTrackableType = nil
                state.retailSuperTrackedMapPin = nil
                state.retailSuperTrackedMapPinType = nil
                state.retailSuperTrackedMapPinTypeID = nil
                state.retailSuperTrackedMapPinPoint = nil
                state.retailSuperTrackedVignette = nil
                if superTrackApi.ClearAllSuperTracked then
                    return superTrackApi.ClearAllSuperTracked()
                end
                return true
            end

            if normalizedType == "quest" then
                local questId = tonumber(contentID) or 0
                if superTrackApi.SetSuperTrackedQuestID then
                    return superTrackApi.SetSuperTrackedQuestID(questId)
                end
                return false
            end

            if normalizedType == "userWaypoint" then
                if superTrackApi.SetSuperTrackedUserWaypoint then
                    return superTrackApi.SetSuperTrackedUserWaypoint(contentID ~= false)
                end
                return false
            end

            if normalizedType == "mapPin" then
                if superTrackApi.SetSuperTrackedMapPin then
                    if type(contentID) == "table" then
                        return superTrackApi.SetSuperTrackedMapPin(contentID.type, contentID.typeID)
                    end
                    return superTrackApi.SetSuperTrackedMapPin(contentID, 0)
                end
                return false
            end

            if normalizedType == "vignette" then
                if superTrackApi.SetSuperTrackedVignette then
                    return superTrackApi.SetSuperTrackedVignette(contentID)
                end
                return false
            end

            state.retailSuperTrackedContentType = "content"
            state.retailSuperTrackedContentID = contentID
            state.retailSuperTrackedTrackableType = contentType
            state.retailSuperTrackedMapPin = nil
            state.retailSuperTrackedMapPinType = nil
            state.retailSuperTrackedMapPinTypeID = nil
            state.retailSuperTrackedMapPinPoint = nil
            state.retailSuperTrackedVignette = nil
            return true
        end
    end

    if type(superTrackApi.SetSuperTrackedMapPin) ~= "function" then
        superTrackApi.SetSuperTrackedMapPin = function(mapPinType, typeID)
            if mapPinType == nil then
                state.retailSuperTrackedMapPin = nil
                state.retailSuperTrackedMapPinType = nil
                state.retailSuperTrackedMapPinTypeID = nil
                state.retailSuperTrackedMapPinPoint = nil
                if state.retailSuperTrackedContentType == "mapPin" then
                    state.retailSuperTrackedContentType = nil
                    state.retailSuperTrackedContentID = nil
                end
                return true
            end

            local point = NormalizeUiMapPointArgs(mapPinType, typeID, nil)
            if point then
                state.retailSuperTrackedMapPinPoint = point
                state.retailSuperTrackedMapPinType = SuperTrackingMapPinTypeToEnum("AreaPOI")
                state.retailSuperTrackedMapPinTypeID = tonumber(typeID) or 0
            else
                local normalizedPinType = SuperTrackingMapPinTypeToEnum(mapPinType)
                local normalizedTypeID = tonumber(typeID)
                if normalizedPinType == nil or normalizedTypeID == nil then
                    return false
                end

                state.retailSuperTrackedMapPinType = normalizedPinType
                state.retailSuperTrackedMapPinTypeID = normalizedTypeID
                state.retailSuperTrackedMapPinPoint = nil
            end

            state.retailSuperTrackedMapPin = {
                type = state.retailSuperTrackedMapPinType,
                typeID = state.retailSuperTrackedMapPinTypeID,
                point = state.retailSuperTrackedMapPinPoint,
            }
            state.retailSuperTrackedContentType = "mapPin"
            state.retailSuperTrackedContentID = state.retailSuperTrackedMapPinTypeID
            state.retailSuperTrackedTrackableType = nil
            state.retailSuperTrackedVignette = nil

            if state.retailSuperTrackedMapPinPoint and superTrackApi.SetSuperTrackedQuestWaypointForMap then
                local point = state.retailSuperTrackedMapPinPoint
                pcall(superTrackApi.SetSuperTrackedQuestWaypointForMap, point.uiMapID, point.x, point.y)
            end

            return true
        end
    end

    if type(superTrackApi.GetSuperTrackedMapPin) ~= "function" then
        superTrackApi.GetSuperTrackedMapPin = function()
            if state.retailSuperTrackedMapPinType == nil then
                return nil, nil
            end
            return state.retailSuperTrackedMapPinType, state.retailSuperTrackedMapPinTypeID
        end
    end

    if type(superTrackApi.ClearSuperTrackedMapPin) ~= "function" then
        superTrackApi.ClearSuperTrackedMapPin = function()
            state.retailSuperTrackedMapPin = nil
            state.retailSuperTrackedMapPinType = nil
            state.retailSuperTrackedMapPinTypeID = nil
            state.retailSuperTrackedMapPinPoint = nil
            if state.retailSuperTrackedContentType == "mapPin" then
                state.retailSuperTrackedContentType = nil
                state.retailSuperTrackedContentID = nil
            end
            return true
        end
    end

    if type(superTrackApi.ClearSuperTrackedContent) ~= "function" then
        superTrackApi.ClearSuperTrackedContent = function()
            if state.retailSuperTrackedContentType == "content" then
                state.retailSuperTrackedContentType = nil
                state.retailSuperTrackedContentID = nil
                state.retailSuperTrackedTrackableType = nil
            end
            return true
        end
    end

    if type(superTrackApi.IsSuperTrackingContent) ~= "function" then
        superTrackApi.IsSuperTrackingContent = function()
            return NormalizeSuperTrackedContentType(state.retailSuperTrackedContentType) == "content"
        end
    end

    if type(superTrackApi.IsSuperTrackingMapPin) ~= "function" then
        superTrackApi.IsSuperTrackingMapPin = function()
            return NormalizeSuperTrackedContentType(state.retailSuperTrackedContentType) == "mapPin"
        end
    end

    if type(superTrackApi.IsSuperTrackingQuest) ~= "function" then
        superTrackApi.IsSuperTrackingQuest = function()
            return (superTrackApi.GetSuperTrackedQuestID and superTrackApi.GetSuperTrackedQuestID() ~= nil) or false
        end
    end

    if type(superTrackApi.IsSuperTrackingCorpse) ~= "function" then
        superTrackApi.IsSuperTrackingCorpse = function()
            return false
        end
    end

    if type(superTrackApi.SetSuperTrackedVignette) ~= "function" then
        superTrackApi.SetSuperTrackedVignette = function(vignetteGUID)
            if vignetteGUID == nil or vignetteGUID == "" then
                state.retailSuperTrackedVignette = nil
                if state.retailSuperTrackedContentType == "vignette" then
                    state.retailSuperTrackedContentType = nil
                    state.retailSuperTrackedContentID = nil
                end
                return true
            end

            state.retailSuperTrackedVignette = vignetteGUID
            state.retailSuperTrackedContentType = "vignette"
            state.retailSuperTrackedContentID = vignetteGUID
            state.retailSuperTrackedTrackableType = nil
            state.retailSuperTrackedMapPin = nil
            state.retailSuperTrackedMapPinType = nil
            state.retailSuperTrackedMapPinTypeID = nil
            state.retailSuperTrackedMapPinPoint = nil
            return true
        end
    end

    if type(superTrackApi.GetSuperTrackedVignette) ~= "function" then
        superTrackApi.GetSuperTrackedVignette = function()
            return state.retailSuperTrackedVignette
        end
    end

    if type(_G.QuestSuperTracking_GetSuperTrackedQuestID) ~= "function" then
        _G.QuestSuperTracking_GetSuperTrackedQuestID = function()
            return superTrackApi.GetSuperTrackedQuestID and superTrackApi.GetSuperTrackedQuestID() or nil
        end
    end

    if type(_G.QuestSuperTracking_GetSuperTrackedQuestName) ~= "function" then
        _G.QuestSuperTracking_GetSuperTrackedQuestName = function()
            return superTrackApi.GetSuperTrackedQuestName and superTrackApi.GetSuperTrackedQuestName() or nil
        end
    end

    if type(_G.QuestSuperTracking_GetSuperTrackedContent) ~= "function" then
        _G.QuestSuperTracking_GetSuperTrackedContent = function()
            return superTrackApi.GetSuperTrackedContent and superTrackApi.GetSuperTrackedContent() or nil, nil
        end
    end

    if type(_G.QuestSuperTracking_GetSuperTrackedMapPin) ~= "function" then
        _G.QuestSuperTracking_GetSuperTrackedMapPin = function()
            return superTrackApi.GetSuperTrackedMapPin and superTrackApi.GetSuperTrackedMapPin() or nil, nil
        end
    end

    if type(_G.QuestSuperTracking_GetSuperTrackedVignette) ~= "function" then
        _G.QuestSuperTracking_GetSuperTrackedVignette = function()
            return superTrackApi.GetSuperTrackedVignette and superTrackApi.GetSuperTrackedVignette() or nil
        end
    end

    local canSetUserWaypointOnMap = type(_G.CanSetUserWaypointOnMap) == "function" and _G.CanSetUserWaypointOnMap or nil
    local setUserWaypoint = type(_G.SetUserWaypoint) == "function" and _G.SetUserWaypoint or nil
    local getUserWaypoint = type(_G.GetUserWaypoint) == "function" and _G.GetUserWaypoint or nil
    local getUserWaypointForMap = type(_G.GetUserWaypointPositionForMap) == "function" and _G.GetUserWaypointPositionForMap or nil
    local hasUserWaypoint = type(_G.HasUserWaypoint) == "function" and _G.HasUserWaypoint or nil
    local clearUserWaypoint = type(_G.ClearUserWaypoint) == "function" and _G.ClearUserWaypoint or nil

    if type(mapApi.CanSetUserWaypointOnMap) ~= "function" then
        mapApi.CanSetUserWaypointOnMap = function(mapId)
            if canSetUserWaypointOnMap then
                local ok, canSet = pcall(canSetUserWaypointOnMap, mapId)
                if ok then
                    return canSet == true
                end
            end

            return true
        end
    end

    if type(mapApi.SetUserWaypoint) ~= "function" then
        mapApi.SetUserWaypoint = function(mapIdOrPoint, x, y)
            if not setUserWaypoint then
                return false
            end

            local point = NormalizeUiMapPointArgs(mapIdOrPoint, x, y)
            if not point then
                return false
            end

            local ok, result = pcall(setUserWaypoint, point.uiMapID, point.x, point.y)
            if not ok then
                return false
            end
            return result ~= false
        end
    end

    if type(mapApi.GetUserWaypoint) ~= "function" then
        mapApi.GetUserWaypoint = function()
            if not getUserWaypoint then
                return nil
            end

            local ok, mapId, x, y = pcall(getUserWaypoint)
            if not ok then
                return nil
            end

            if type(mapId) == "table" then
                x = mapId.x or mapId.normalizedX
                y = mapId.y or mapId.normalizedY
                mapId = mapId.uiMapID or mapId.mapID or mapId.mapId
            end

            return BuildUiMapPoint(mapId, x, y)
        end
    end

    if type(mapApi.GetUserWaypointHyperlink) ~= "function" then
        mapApi.GetUserWaypointHyperlink = function()
            local point = mapApi.GetUserWaypoint and mapApi.GetUserWaypoint() or nil
            return BuildUserWaypointHyperlink(point)
        end
    end

    if type(mapApi.GetUserWaypointFromHyperlink) ~= "function" then
        mapApi.GetUserWaypointFromHyperlink = function(hyperlink)
            return ParseUserWaypointHyperlink(hyperlink)
        end
    end

    if type(mapApi.GetUserWaypointPositionForMap) ~= "function" then
        mapApi.GetUserWaypointPositionForMap = function(mapId)
            mapId = tonumber(mapId)
            if not mapId or mapId <= 0 then
                return nil, nil
            end

            if getUserWaypointForMap then
                local ok, x, y = pcall(getUserWaypointForMap, mapId)
                if ok then
                    if type(x) == "table" then
                        y = x.y or x.normalizedY
                        x = x.x or x.normalizedX
                    end

                    x = NormalizeCoord(x)
                    y = NormalizeCoord(y)
                    if x and y then
                        return x, y
                    end
                end
            end

            local point = mapApi.GetUserWaypoint and mapApi.GetUserWaypoint() or nil
            if type(point) == "table" and tonumber(point.uiMapID) == mapId then
                local x = NormalizeCoord(point.x)
                local y = NormalizeCoord(point.y)
                if x and y then
                    return x, y
                end
            end

            return nil, nil
        end
    end

    if type(mapApi.HasUserWaypoint) ~= "function" then
        mapApi.HasUserWaypoint = function()
            if hasUserWaypoint then
                local ok, hasWaypoint = pcall(hasUserWaypoint)
                if ok then
                    return hasWaypoint == true
                end
            end

            local point = mapApi.GetUserWaypoint and mapApi.GetUserWaypoint() or nil
            return type(point) == "table" and point.x ~= nil and point.y ~= nil
        end
    end

    if type(mapApi.ClearUserWaypoint) ~= "function" then
        mapApi.ClearUserWaypoint = function()
            if not clearUserWaypoint then
                return false
            end
            local ok, result = pcall(clearUserWaypoint)
            if not ok then
                return false
            end

            if state.retailSuperTrackedContentType == "userWaypoint" then
                state.retailSuperTrackedContentType = nil
                state.retailSuperTrackedContentID = nil
            end

            return result ~= false
        end
    end

    if type(navigationApi.GetDistance) ~= "function" then
        navigationApi.GetDistance = function(mapIdOrPoint, x, y)
            if getNavigationDistance then
                local ok, nativeDistance = pcall(getNavigationDistance, mapIdOrPoint, x, y)
                nativeDistance = tonumber(nativeDistance)
                if ok and nativeDistance and nativeDistance >= 0 then
                    return nativeDistance
                end
            end

            local point = NormalizeUiMapPointArgs(mapIdOrPoint, x, y)
            if not point then
                return nil
            end

            local playerX, playerY, playerMapId = GetPlayerMapPositionSafe()
            if not playerX or not playerY or playerMapId ~= point.uiMapID then
                return nil
            end

            local distance = ComputeDistanceYards(point.uiMapID, playerX, playerY, point.x, point.y)
            return distance
        end
    end

    if type(navigationApi.SetPlayerState) ~= "function" then
        navigationApi.SetPlayerState = function(mapId, x, y, facing)
            mapId = tonumber(mapId)
            x = NormalizeCoord(x)
            y = NormalizeCoord(y)
            facing = tonumber(facing) or 0

            if not mapId or mapId <= 0 or not x or not y then
                return false
            end

            state.lastNavigationPlayerStateMapId = mapId
            state.lastNavigationPlayerStateX = x
            state.lastNavigationPlayerStateY = y
            state.lastNavigationPlayerStateFacing = facing

            if setNavigationPlayerState then
                local ok, result = pcall(setNavigationPlayerState, mapId, x, y, facing)
                if not ok then
                    return false
                end
                if result ~= nil then
                    return result ~= false
                end
            end

            return true
        end
    end

    if type(navigationApi.GetPlayerState) ~= "function" then
        navigationApi.GetPlayerState = function()
            return state.lastNavigationPlayerStateMapId,
                state.lastNavigationPlayerStateX,
                state.lastNavigationPlayerStateY,
                state.lastNavigationPlayerStateFacing
        end
    end

    if type(navigationApi.GetDistanceSquared) ~= "function" then
        navigationApi.GetDistanceSquared = function(mapIdOrPoint, x, y)
            if getNavigationDistanceSquared then
                local ok, nativeDistanceSquared = pcall(getNavigationDistanceSquared, mapIdOrPoint, x, y)
                nativeDistanceSquared = tonumber(nativeDistanceSquared)
                if ok and nativeDistanceSquared and nativeDistanceSquared >= 0 then
                    return nativeDistanceSquared
                end
            end

            local distance = navigationApi.GetDistance(mapIdOrPoint, x, y)
            if not distance then
                return nil
            end
            return distance * distance
        end
    end

    if type(navigationApi.GetFrame) ~= "function" then
        navigationApi.GetFrame = function()
            if getNavigationFrame then
                local ok, frame = pcall(getNavigationFrame)
                if ok and frame then
                    return frame
                end
            end

            return EnsureFrame()
        end
    end

    if type(navigationApi.GetFrameState) ~= "function" then
        navigationApi.GetFrameState = function()
            local screenX, screenY, navState, clamped = CallNativeNavigationFrameState()
            if screenX and screenY then
                return screenX, screenY, navState or NAV_STATE_DISABLED, clamped == true
            end

            local frame = EnsureFrame()
            local frameX, frameY = frame:GetCenter()
            if type(frameX) ~= "number" or type(frameY) ~= "number" then
                return nil, nil, state.lastNavState or NAV_STATE_DISABLED, state.lastClamped == true
            end

            return frameX, frameY, state.lastNavState or NAV_STATE_DISABLED, state.lastClamped == true
        end
    end

    if type(navigationApi.GetTargetState) ~= "function" then
        navigationApi.GetTargetState = function()
            if getNavigationTargetState then
                local ok, navState = pcall(getNavigationTargetState)
                navState = tonumber(navState)
                if ok and navState ~= nil then
                    return navState
                end
            end

            if not state.target then
                return NAV_STATE_DISABLED
            end
            return state.lastNavState or NAV_STATE_DISABLED
        end
    end

    if type(navigationApi.HasValidScreenPosition) ~= "function" then
        navigationApi.HasValidScreenPosition = function()
            if hasNavigationValidScreenPosition then
                local ok, hasValid = pcall(hasNavigationValidScreenPosition)
                if ok and hasValid ~= nil then
                    return hasValid == true
                end
            end

            local _, _, nativeState = CallNativeNavigationFrameState()
            if nativeState ~= nil then
                return nativeState ~= NAV_STATE_INVALID and nativeState ~= NAV_STATE_DISABLED
            end

            if not state.target then
                return false
            end
            local navState = state.lastNavState or NAV_STATE_DISABLED
            return navState ~= NAV_STATE_INVALID and navState ~= NAV_STATE_DISABLED
        end
    end

    if type(navigationApi.WasClampedToScreen) ~= "function" then
        navigationApi.WasClampedToScreen = function()
            if wasNavigationFrameClampedToScreen then
                local ok, clamped = pcall(wasNavigationFrameClampedToScreen)
                if ok and clamped ~= nil then
                    return clamped == true
                end
            end

            local _, _, _, nativeClamped = CallNativeNavigationFrameState()
            if nativeClamped ~= nil then
                return nativeClamped == true
            end

            return state.lastClamped == true
        end
    end

    if type(navigationApi.GetProjectionDebugStats) ~= "function" then
        navigationApi.GetProjectionDebugStats = function()
            if not getNavigationProjectionDebugStats then
                return nil
            end

            local ok,
                callCount,
                attempts,
                success,
                fallback,
                failNoEffectiveMap,
                failNoTarget,
                failNoPlayerMovement,
                failPlayerMapTranslate,
                failMapToWorld,
                failWorldToScreen = pcall(getNavigationProjectionDebugStats)

            if not ok then
                return nil
            end

            return {
                callCount = tonumber(callCount) or 0,
                worldProjectionAttempts = tonumber(attempts) or 0,
                worldProjectionSuccess = tonumber(success) or 0,
                fallbackCount = tonumber(fallback) or 0,
                failNoEffectiveMap = tonumber(failNoEffectiveMap) or 0,
                failNoTarget = tonumber(failNoTarget) or 0,
                failNoPlayerMovement = tonumber(failNoPlayerMovement) or 0,
                failPlayerMapTranslate = tonumber(failPlayerMapTranslate) or 0,
                failMapToWorld = tonumber(failMapToWorld) or 0,
                failWorldToScreen = tonumber(failWorldToScreen) or 0,
            }
        end
    end

    if type(navigationApi.GetNearestPartyMemberToken) ~= "function" then
        navigationApi.GetNearestPartyMemberToken = function()
            local target = state.target
            if type(target) ~= "table" then
                return nil
            end

            local point = NormalizeUiMapPointArgs(target.mapId, target.x, target.y)
            if not point then
                return nil
            end

            if type(GetPlayerMapPosition) ~= "function" or type(UnitExists) ~= "function" then
                return nil
            end

            local function SampleUnitPosition(unitToken)
                if not UnitExists(unitToken) then
                    return nil, nil
                end

                local ok, unitX, unitY = pcall(GetPlayerMapPosition, unitToken)
                if not ok then
                    return nil, nil
                end

                unitX = NormalizeCoord(unitX)
                unitY = NormalizeCoord(unitY)
                if not unitX or not unitY then
                    return nil, nil
                end

                if unitToken ~= "player" and unitX == 0 and unitY == 0 then
                    return nil, nil
                end

                return unitX, unitY
            end

            local bestToken = nil
            local bestDistanceSq = nil

            local function EvaluateToken(unitToken)
                if type(UnitIsUnit) == "function" and UnitIsUnit(unitToken, "player") then
                    return
                end

                if type(UnitIsDeadOrGhost) == "function" and UnitIsDeadOrGhost(unitToken) then
                    return
                end

                local unitX, unitY = SampleUnitPosition(unitToken)
                if not unitX or not unitY then
                    return
                end

                local dx = point.x - unitX
                local dy = point.y - unitY
                local distanceSq = (dx * dx) + (dy * dy)

                if not bestDistanceSq or distanceSq < bestDistanceSq then
                    bestDistanceSq = distanceSq
                    bestToken = unitToken
                end
            end

            local raidCount = (type(GetNumRaidMembers) == "function") and tonumber(GetNumRaidMembers()) or 0
            if raidCount and raidCount > 0 then
                for index = 1, raidCount do
                    EvaluateToken("raid" .. tostring(index))
                end
                return bestToken
            end

            local partyCount = (type(GetNumPartyMembers) == "function") and tonumber(GetNumPartyMembers()) or 0
            if not partyCount or partyCount <= 0 then
                return nil
            end

            for index = 1, partyCount do
                EvaluateToken("party" .. tostring(index))
            end

            return bestToken
        end
    end

    local function EnsureFlatNamespaceAliases(namespaceTable, aliasPairs)
        if type(namespaceTable) ~= "table" or type(aliasPairs) ~= "table" then
            return
        end

        for i = 1, #aliasPairs do
            local pair = aliasPairs[i]
            local globalName = pair and pair[1]
            local methodName = pair and pair[2]
            if type(globalName) == "string"
                and type(methodName) == "string"
                and type(_G[globalName]) ~= "function"
                and type(namespaceTable[methodName]) == "function" then
                _G[globalName] = function(...)
                    return namespaceTable[methodName](...)
                end
            end
        end
    end

    EnsureFlatNamespaceAliases(superTrackApi, {
        { "C_SuperTrack_SetSuperTrackedQuestID", "SetSuperTrackedQuestID" },
        { "C_SuperTrack_GetSuperTrackedQuestID", "GetSuperTrackedQuestID" },
        { "C_SuperTrack_SetSuperTrackedQuestWaypointForMap", "SetSuperTrackedQuestWaypointForMap" },
        { "C_SuperTrack_GetSuperTrackedQuestWaypointForMap", "GetSuperTrackedQuestWaypointForMap" },
        { "C_SuperTrack_GetNextWaypointForMap", "GetNextWaypointForMap" },
        { "C_SuperTrack_ClearSuperTrackedQuestWaypoint", "ClearSuperTrackedQuestWaypoint" },
        { "C_SuperTrack_ClearAllSuperTracked", "ClearAllSuperTracked" },
        { "C_SuperTrack_IsSuperTrackingAnything", "IsSuperTrackingAnything" },
        { "C_SuperTrack_SetSuperTrackedUserWaypoint", "SetSuperTrackedUserWaypoint" },
        { "C_SuperTrack_IsSuperTrackingUserWaypoint", "IsSuperTrackingUserWaypoint" },
        { "C_SuperTrack_GetSuperTrackedItemName", "GetSuperTrackedItemName" },
        { "C_SuperTrack_SetSuperTrackedQuestName", "SetSuperTrackedQuestName" },
        { "C_SuperTrack_GetSuperTrackedQuestName", "GetSuperTrackedQuestName" },
        { "C_SuperTrack_GetHighestPrioritySuperTrackingType", "GetHighestPrioritySuperTrackingType" },
        { "C_SuperTrack_GetSuperTrackedContent", "GetSuperTrackedContent" },
        { "C_SuperTrack_SetSuperTrackedContent", "SetSuperTrackedContent" },
        { "C_SuperTrack_SetSuperTrackedMapPin", "SetSuperTrackedMapPin" },
        { "C_SuperTrack_GetSuperTrackedMapPin", "GetSuperTrackedMapPin" },
        { "C_SuperTrack_ClearSuperTrackedMapPin", "ClearSuperTrackedMapPin" },
        { "C_SuperTrack_ClearSuperTrackedContent", "ClearSuperTrackedContent" },
        { "C_SuperTrack_IsSuperTrackingContent", "IsSuperTrackingContent" },
        { "C_SuperTrack_IsSuperTrackingMapPin", "IsSuperTrackingMapPin" },
        { "C_SuperTrack_IsSuperTrackingQuest", "IsSuperTrackingQuest" },
        { "C_SuperTrack_IsSuperTrackingCorpse", "IsSuperTrackingCorpse" },
        { "C_SuperTrack_SetSuperTrackedVignette", "SetSuperTrackedVignette" },
        { "C_SuperTrack_GetSuperTrackedVignette", "GetSuperTrackedVignette" },
    })

    EnsureFlatNamespaceAliases(mapApi, {
        { "C_Map_CanSetUserWaypointOnMap", "CanSetUserWaypointOnMap" },
        { "C_Map_SetUserWaypoint", "SetUserWaypoint" },
        { "C_Map_GetUserWaypoint", "GetUserWaypoint" },
        { "C_Map_GetUserWaypointHyperlink", "GetUserWaypointHyperlink" },
        { "C_Map_GetUserWaypointFromHyperlink", "GetUserWaypointFromHyperlink" },
        { "C_Map_GetUserWaypointPositionForMap", "GetUserWaypointPositionForMap" },
        { "C_Map_HasUserWaypoint", "HasUserWaypoint" },
        { "C_Map_ClearUserWaypoint", "ClearUserWaypoint" },
    })

    EnsureFlatNamespaceAliases(navigationApi, {
        { "C_Navigation_GetDistance", "GetDistance" },
        { "C_Navigation_GetDistanceSquared", "GetDistanceSquared" },
        { "C_Navigation_GetFrame", "GetFrame" },
        { "C_Navigation_GetFrameState", "GetFrameState" },
        { "C_Navigation_GetTargetState", "GetTargetState" },
        { "C_Navigation_HasValidScreenPosition", "HasValidScreenPosition" },
        { "C_Navigation_WasClampedToScreen", "WasClampedToScreen" },
        { "C_Navigation_GetProjectionDebugStats", "GetProjectionDebugStats" },
        { "C_Navigation_SetPlayerState", "SetPlayerState" },
        { "C_Navigation_GetPlayerState", "GetPlayerState" },
        { "C_Navigation_GetNearestPartyMemberToken", "GetNearestPartyMemberToken" },
    })

    -- C_QuestLog namespace: wire native flat-global exports into the table so that
    -- code using dot-notation (C_QuestLog.IsComplete etc.) works on WotLK.
    local nativeQuestLogIsComplete = type(_G.C_QuestLog_IsComplete) == "function" and _G.C_QuestLog_IsComplete or nil
    local nativeQuestLogGetQuestsOnMap = type(_G.C_QuestLog_GetQuestsOnMap) == "function" and _G.C_QuestLog_GetQuestsOnMap or nil
    local nativeQuestLogGetQuestIDForWatchIndex = type(_G.C_QuestLog_GetQuestIDForQuestWatchIndex) == "function" and _G.C_QuestLog_GetQuestIDForQuestWatchIndex or nil
    local nativeQuestLogReadyForTurnIn = type(_G.C_QuestLog_ReadyForTurnIn) == "function" and _G.C_QuestLog_ReadyForTurnIn or nil
    local nativeQuestLogGetQuestAdditionalHighlights = type(_G.C_QuestLog_GetQuestAdditionalHighlights) == "function" and _G.C_QuestLog_GetQuestAdditionalHighlights or nil

    if type(questLogApi.IsComplete) ~= "function" then
        questLogApi.IsComplete = function(questId)
            if not nativeQuestLogIsComplete then
                return nil
            end
            local ok, result = pcall(nativeQuestLogIsComplete, questId)
            if not ok then
                return nil
            end
            return result
        end
    end

    if type(questLogApi.GetQuestsOnMap) ~= "function" then
        questLogApi.GetQuestsOnMap = function(mapId)
            if not nativeQuestLogGetQuestsOnMap then
                return nil
            end
            local ok, result = pcall(nativeQuestLogGetQuestsOnMap, mapId)
            if not ok then
                return nil
            end
            return result
        end
    end

    if type(questLogApi.GetQuestIDForQuestWatchIndex) ~= "function" then
        questLogApi.GetQuestIDForQuestWatchIndex = function(watchIndex)
            if not nativeQuestLogGetQuestIDForWatchIndex then
                return nil
            end
            local ok, result = pcall(nativeQuestLogGetQuestIDForWatchIndex, watchIndex)
            if not ok then
                return nil
            end
            return result
        end
    end

    if type(questLogApi.ReadyForTurnIn) ~= "function" then
        questLogApi.ReadyForTurnIn = function(questId)
            if nativeQuestLogReadyForTurnIn then
                local ok, result = pcall(nativeQuestLogReadyForTurnIn, questId)
                if ok then
                    return result == true
                end
            end

            if questLogApi.IsComplete then
                local complete = questLogApi.IsComplete(questId)
                return complete == 1 or complete == true
            end

            return false
        end
    end

    if type(questLogApi.GetQuestAdditionalHighlights) ~= "function" then
        questLogApi.GetQuestAdditionalHighlights = function(questId)
            if nativeQuestLogGetQuestAdditionalHighlights then
                local ok, uiMapID, worldQuests, worldQuestsElite, dungeons, treasures = pcall(nativeQuestLogGetQuestAdditionalHighlights, questId)
                if ok then
                    return uiMapID, worldQuests, worldQuestsElite, dungeons, treasures
                end
            end

            return nil, false, false, false, false
        end
    end

    EnsureFlatNamespaceAliases(questLogApi, {
        { "C_QuestLog_IsComplete", "IsComplete" },
        { "C_QuestLog_GetQuestsOnMap", "GetQuestsOnMap" },
        { "C_QuestLog_GetQuestIDForQuestWatchIndex", "GetQuestIDForQuestWatchIndex" },
        { "C_QuestLog_ReadyForTurnIn", "ReadyForTurnIn" },
        { "C_QuestLog_GetQuestAdditionalHighlights", "GetQuestAdditionalHighlights" },
    })
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

local function SetQuestPoiLock(questId, x, y, mapId, source, playerX, playerY)
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
        playerX = NormalizeCoord(playerX),
        playerY = NormalizeCoord(playerY),
    }
end

local function GetQuestPoiLock(questId, mapId, playerX, playerY)
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

    local now = GetTime() or 0
    if (now - (lock.updatedAt or 0)) > QUEST_POI_LOCK_MAX_AGE_SEC then
        state.questPoiLocks[questId] = nil
        return nil, nil, nil
    end

    if mapId
        and lock.mapId == mapId
        and type(lock.playerX) == "number"
        and type(lock.playerY) == "number"
        and type(playerX) == "number"
        and type(playerY) == "number" then
        local movedYards = ComputeDistanceYards(mapId, lock.playerX, lock.playerY, playerX, playerY)
        if movedYards and movedYards > QUEST_POI_LOCK_MAX_DRIFT_YARDS then
            state.questPoiLocks[questId] = nil
            return nil, nil, nil
        end
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
            boundaryPoints = {},
            boundaryKeys = {},
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

local function AddQuestPoiBoundaryPoints(questId, points, mapId, source)
    questId = tonumber(questId)
    if not questId or questId <= 0 or type(points) ~= "table" then
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
            boundaryPoints = {},
            boundaryKeys = {},
            updatedAt = 0,
        }
        state.questPoiCache[questId] = bucket
    end

    bucket.boundaryPoints = bucket.boundaryPoints or {}
    bucket.boundaryKeys = bucket.boundaryKeys or {}

    local inserted = 0
    for i = 1, #points do
        local point = points[i]
        local x = point and NormalizeCoord(point.x)
        local y = point and NormalizeCoord(point.y)
        if x and y then
            local pointMapId = tonumber((point and point.mapId) or mapId)
            if pointMapId and pointMapId <= 0 then
                pointMapId = nil
            end
            local key = string.format("%s:%.4f:%.4f", tostring(pointMapId or "n/a"), x, y)
            if not bucket.boundaryKeys[key] then
                bucket.boundaryKeys[key] = true
                table.insert(bucket.boundaryPoints, {
                    x = x,
                    y = y,
                    mapId = pointMapId,
                    source = source or point.source,
                })
                inserted = inserted + 1
            end
        end
    end

    if inserted > 0 then
        bucket.updatedAt = GetTime() or 0
    end
end

local function GetCachedQuestPoiBoundaryPoints(questId, mapId)
    questId = tonumber(questId)
    if not questId or questId <= 0 then
        return nil
    end

    local bucket = state.questPoiCache and state.questPoiCache[questId]
    if not bucket or not bucket.boundaryPoints or #bucket.boundaryPoints < 3 then
        return nil
    end

    local currentMapId = mapId
    if not currentMapId and type(GetCurrentMapAreaID) == "function" then
        currentMapId = GetCurrentMapAreaID()
    end

    local selected = {}
    for i = 1, #bucket.boundaryPoints do
        local point = bucket.boundaryPoints[i]
        if not currentMapId or not point.mapId or point.mapId == currentMapId then
            table.insert(selected, {
                x = point.x,
                y = point.y,
            })
        end
    end

    if #selected < 3 then
        return nil
    end

    local cx, cy = 0, 0
    for i = 1, #selected do
        cx = cx + selected[i].x
        cy = cy + selected[i].y
    end
    cx = cx / #selected
    cy = cy / #selected

    table.sort(selected, function(a, b)
        return Atan2(a.y - cy, a.x - cx) < Atan2(b.y - cy, b.x - cx)
    end)

    return selected
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
        local iconInfo = { QuestPOIGetIconInfo(buttonIndex) }
        local x, y = ParseQuestPoiCoords(unpack(iconInfo))
        if x and y then
            AddQuestPoiCachePoint(qid, x, y, mapId, "display-index")
        end
        local boundaryPoints = ParseQuestPoiBoundaryPoints(unpack(iconInfo))
        if boundaryPoints then
            AddQuestPoiBoundaryPoints(qid, boundaryPoints, mapId, "display-index")
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
        local lockX, lockY = GetQuestPoiLock(questId, activeMapId, playerX, playerY)
        if lockX and lockY then
            return lockX, lockY, questId, "poi-lock"
        end
    end

    if not bypassCache then
        local cachedX, cachedY, cachedCount = GetCachedQuestPoiCoords(questId, playerX, playerY, mapId)
        if cachedX and cachedY then
            SetQuestPoiLock(questId, cachedX, cachedY, activeMapId, "cache", playerX, playerY)
            if cachedCount and cachedCount > 1 then
                return cachedX, cachedY, questId, "poi-cache-multi"
            end
            return cachedX, cachedY, questId, "poi-cache"
        end
    end

    if activeMapId then
        local mapQuests = ShimGetQuestsOnMap(activeMapId)
        if type(mapQuests) == "table" then
            for _, info in pairs(mapQuests) do
                if info and tonumber(info.questID) == questId then
                    local mapBoundary = ParseQuestPoiBoundaryPoints(info)
                    if mapBoundary then
                        AddQuestPoiBoundaryPoints(questId, mapBoundary, activeMapId, "quests-on-map")
                    end

                    local mapX = NormalizeCoord(info.x)
                    local mapY = NormalizeCoord(info.y)
                    if mapX and mapY then
                        AddQuestPoiCachePoint(questId, mapX, mapY, activeMapId, "quests-on-map")
                    end
                    break
                end
            end
        end
    end

    if type(QuestPOIGetIconInfo) == "function" then
        -- Prefer quest-log-index lookup first for 3.3.5 tracker-selected quests.
        local logIndexInfo = { QuestPOIGetIconInfo(questLogIndex) }
        local qx, qy = ParseQuestPoiCoords(unpack(logIndexInfo))
        local logIndexBoundary = ParseQuestPoiBoundaryPoints(unpack(logIndexInfo))
        if logIndexBoundary then
            AddQuestPoiBoundaryPoints(questId, logIndexBoundary, activeMapId, "log-index")
        end
        if qx and qy then
            AddQuestPoiCachePoint(questId, qx, qy, activeMapId, "log-index")
            SetQuestPoiLock(questId, qx, qy, activeMapId, "log-index", playerX, playerY)
            return qx, qy, questId, "log-index"
        end

        if questId ~= questLogIndex then
            local questIdInfo = { QuestPOIGetIconInfo(questId) }
            qx, qy = ParseQuestPoiCoords(unpack(questIdInfo))
            local questIdBoundary = ParseQuestPoiBoundaryPoints(unpack(questIdInfo))
            if questIdBoundary then
                AddQuestPoiBoundaryPoints(questId, questIdBoundary, activeMapId, "quest-id")
            end
            if qx and qy then
                AddQuestPoiCachePoint(questId, qx, qy, activeMapId, "quest-id")
                SetQuestPoiLock(questId, qx, qy, activeMapId, "quest-id", playerX, playerY)
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

local function GetQuestLogInfo(questLogIndex)
    questLogIndex = tonumber(questLogIndex)
    if not questLogIndex or questLogIndex <= 0
        or type(GetQuestLogTitle) ~= "function" then
        return nil
    end

    local title, level, tag, suggestedGroup, isHeader, _, isComplete, frequency, questIdFromApi = GetQuestLogTitle(questLogIndex)
    if not title or isHeader then
        return nil
    end

    local questId = tonumber(questIdFromApi)
    if not questId or questId <= 0 then
        questId = GetQuestIdFromLogIndex(questLogIndex)
    end

    local stockIsDaily = (frequency == true or frequency == 1)
    local recurrenceType = GetRecurringQuestType(questId, title)
    if not recurrenceType and stockIsDaily then
        recurrenceType = "daily"
    end

    local isWeekly = recurrenceType == "weekly"
    local isRecurring = recurrenceType == "daily" or isWeekly

    return {
        questLogIndex = questLogIndex,
        questId = questId,
        title = title,
        level = tonumber(level),
        tag = tag,
        suggestedGroup = tonumber(suggestedGroup),
        isComplete = (isComplete == true or isComplete == 1),
        isDaily = stockIsDaily or isRecurring,
        isWeekly = isWeekly,
        isRecurring = isRecurring,
        recurrenceType = recurrenceType,
    }
end

local function EstimateQuestPoiBoundaryRadius(questLogIndex, centerX, centerY)
    if not questLogIndex or questLogIndex <= 0 then
        return 50
    end

    local info = GetQuestLogInfo(questLogIndex)
    if not info then
        return 50
    end

    local baseRadius = 50
    if info.level then
        baseRadius = 30 + math_min(info.level * 2, 80)
    end

    local frequency = (info.isDaily and 1.2) or 1.0
    local completeness = (info.isComplete and 0.8) or 1.0

    return math_max(baseRadius * frequency * completeness, 20)
end

local function EstimateQuestPoiBoundaryRadiusFromPolygon(mapId, centerX, centerY, boundaryPoints)
    if not centerX or not centerY or type(boundaryPoints) ~= "table" or #boundaryPoints < 3 then
        return nil
    end

    local maxRadius = 0
    for i = 1, #boundaryPoints do
        local point = boundaryPoints[i]
        local distanceYards = ComputeDistanceYards(mapId, centerX, centerY, point.x, point.y)
        if distanceYards and distanceYards > maxRadius then
            maxRadius = distanceYards
        end
    end

    if maxRadius > 0 then
        return maxRadius
    end

    return nil
end

local function IsPointInsidePolygon(px, py, polygon)
    if not px or not py or type(polygon) ~= "table" or #polygon < 3 then
        return false
    end

    local inside = false
    local j = #polygon
    for i = 1, #polygon do
        local xi = polygon[i].x
        local yi = polygon[i].y
        local xj = polygon[j].x
        local yj = polygon[j].y

        local intersects = ((yi > py) ~= (yj > py))
            and (px < ((xj - xi) * (py - yi) / ((yj - yi) + 1e-9)) + xi)
        if intersects then
            inside = not inside
        end
        j = i
    end

    return inside
end

local function ResolveQuestPoiBoundary(questLogIndex, questId, mapId, centerX, centerY)
    local boundaryPoints = GetCachedQuestPoiBoundaryPoints(questId, mapId)
    if boundaryPoints and #boundaryPoints >= 3 then
        local radiusFromPolygon = EstimateQuestPoiBoundaryRadiusFromPolygon(mapId, centerX, centerY, boundaryPoints)
        if radiusFromPolygon and radiusFromPolygon > 0 then
            return radiusFromPolygon, boundaryPoints
        end
    end

    return EstimateQuestPoiBoundaryRadius(questLogIndex, centerX, centerY), nil
end

local function CalculateNearestBoundaryPoint(playerX, playerY, centerX, centerY, radiusYards, dxYards, dyYards, boundaryPoints)
    if not playerX or not playerY or not centerX or not centerY or not radiusYards or radiusYards <= 0 then
        return centerX, centerY, radiusYards
    end

    if boundaryPoints and #boundaryPoints >= 2 then
        if IsPointInsidePolygon(playerX, playerY, boundaryPoints) then
            return centerX, centerY, radiusYards
        end

        local bestX, bestY, bestDistSq
        for i = 1, #boundaryPoints do
            local a = boundaryPoints[i]
            local b = boundaryPoints[(i % #boundaryPoints) + 1]
            if a and b and a.x and a.y and b.x and b.y then
                local vx = b.x - a.x
                local vy = b.y - a.y
                local denom = (vx * vx) + (vy * vy)
                local t = 0
                if denom > 0 then
                    t = ((playerX - a.x) * vx + (playerY - a.y) * vy) / denom
                    if t < 0 then
                        t = 0
                    elseif t > 1 then
                        t = 1
                    end
                end

                local projectedX = a.x + (vx * t)
                local projectedY = a.y + (vy * t)
                local pdx = projectedX - playerX
                local pdy = projectedY - playerY
                local distSq = (pdx * pdx) + (pdy * pdy)
                if not bestDistSq or distSq < bestDistSq then
                    bestDistSq = distSq
                    bestX = projectedX
                    bestY = projectedY
                end
            end
        end

        if bestX and bestY then
            return bestX, bestY, radiusYards
        end
    end

    if not dxYards or not dyYards then
        dxYards = centerX - playerX
        dyYards = centerY - playerY
    end

    local distToCenter = math_sqrt((dxYards * dxYards) + (dyYards * dyYards))
    if distToCenter <= 0 then
        return centerX + radiusYards, centerY, radiusYards
    end

    if distToCenter <= radiusYards then
        return centerX, centerY, radiusYards
    end

    local normalizedX = dxYards / distToCenter
    local normalizedY = dyYards / distToCenter

    local boundaryX = centerX + (normalizedX * radiusYards)
    local boundaryY = centerY + (normalizedY * radiusYards)

    return boundaryX, boundaryY, radiusYards
end

local function ResolveQuestTargetNavigationPoint(playerX, playerY, mapId, target)
    if not target or not target.x or not target.y then
        return nil, nil, nil
    end

    if not target.questId or target.questId <= 0 then
        return target.x, target.y, nil
    end

    local questLogIndex = target.questLogIndex
    if not questLogIndex or questLogIndex <= 0 then
        questLogIndex = FindQuestLogIndexByQuestId(target.questId)
    end
    if not questLogIndex or questLogIndex <= 0 then
        return target.x, target.y, nil
    end

    local radiusYards, boundaryPoints = ResolveQuestPoiBoundary(
        questLogIndex,
        target.questId,
        mapId,
        target.x,
        target.y
    )
    if not radiusYards or radiusYards <= 0 then
        return target.x, target.y, nil
    end

    local distanceYards, dxYards, dyYards = ComputeDistanceYards(mapId, playerX, playerY, target.x, target.y)
    if not distanceYards then
        return target.x, target.y, radiusYards
    end

    local navX, navY = CalculateNearestBoundaryPoint(
        playerX,
        playerY,
        target.x,
        target.y,
        radiusYards,
        dxYards,
        dyYards,
        boundaryPoints
    )

    return navX or target.x, navY or target.y, radiusYards
end

local function GetQuestPinStyle(info, pinKind)
    if pinKind == "manual" then
        return "manual"
    end
    if info and info.isComplete then
        return "complete"
    end
    if info and info.isDaily then
        return "daily"
    end
    if pinKind == "waypoint" then
        return "waypoint"
    end
    return "normal"
end

local function GetQuestPinPalette(style)
    if style == "manual" then
        return 0.80, 0.94, 1.0, 0.30
    end
    if style == "complete" then
        return 0.24, 1.0, 0.38, 0.24
    end
    if style == "daily" then
        return 0.30, 0.70, 1.0, 0.22
    end
    if style == "waypoint" then
        return 1.0, 0.85, 0.22, 0.28
    end
    return 0.42, 0.80, 1.0, 0.18
end

local function IsMinimapRotating()
    return type(GetCVar) == "function" and GetCVar("rotateMinimap") == "1"
end

local function IsMinimapIndoors()
    if type(GetCVar) ~= "function" then
        return false
    end

    local outsideZoom = tostring(GetCVar("minimapZoom") or "")
    local insideZoom = tostring(GetCVar("minimapInsideZoom") or "")
    return outsideZoom == insideZoom
end

local function GetMinimapDiameterYards()
    if not Minimap or type(Minimap.GetZoom) ~= "function" then
        return MINIMAP_DIAMETER_YARDS.outdoor[1]
    end

    local zoom = tonumber(Minimap:GetZoom()) or 1
    local zoomTable = IsMinimapIndoors()
        and MINIMAP_DIAMETER_YARDS.indoor
        or MINIMAP_DIAMETER_YARDS.outdoor

    return zoomTable[zoom] or zoomTable[1] or MINIMAP_DIAMETER_YARDS.outdoor[1]
end

local function EnsureMinimapPinContainer()
    if state.minimapPinContainer then
        return state.minimapPinContainer
    end
    if not Minimap then
        return nil
    end

    local container = CreateFrame("Frame", nil, Minimap)
    container:SetAllPoints(Minimap)
    container:SetFrameStrata(Minimap:GetFrameStrata() or "MEDIUM")
    container:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 12)
    container:EnableMouse(false)
    state.minimapPinContainer = container
    return container
end

local function AcquireMinimapPin(index)
    local existing = state.minimapPins[index]
    if existing then
        return existing
    end

    local container = EnsureMinimapPinContainer()
    if not container then
        return nil
    end

    local frame = CreateFrame("Frame", nil, container)
    frame:SetSize(18, 18)
    frame:EnableMouse(false)
    frame:SetFrameLevel(container:GetFrameLevel() + 1)

    frame.Glow = frame:CreateTexture(nil, "BACKGROUND")
    frame.Glow:SetTexture("Interface\\Minimap\\UI-Minimap-Ping")
    frame.Glow:SetBlendMode("ADD")
    frame.Glow:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.Glow:SetSize(24, 24)

    frame.Icon = frame:CreateTexture(nil, "ARTWORK")
    frame.Icon:SetPoint("CENTER", frame, "CENTER", 0, 0)
    if not TrySetTrackedIconAtlas(frame.Icon) then
        frame.Icon:SetTexture(TEXTURE_ATLAS)
        frame.Icon:SetTexCoord(unpack(ICON_TEXCOORD))
    end

    frame.Highlight = frame:CreateTexture(nil, "OVERLAY")
    frame.Highlight:SetTexture("Interface\\Minimap\\UI-Minimap-Ping-Expand")
    frame.Highlight:SetBlendMode("ADD")
    frame.Highlight:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.Highlight:SetSize(26, 26)

    state.minimapPins[index] = frame
    return frame
end

local function ClearMinimapQuestPins()
    state.lastMinimapPinSig = nil
    state.lastMinimapPinCount = 0
    for i = 1, #state.minimapPins do
        state.minimapPins[i]:Hide()
    end
end

local function AddQuestPinCandidate(pins, seenQuestIds, playerX, playerY, mapId, questLogIndex, pinKind, pinSource)
    local info = GetQuestLogInfo(questLogIndex)
    if not info or not info.questId or seenQuestIds[info.questId] then
        return
    end

    local qx, qy, questId, poiSource = GetQuestPoiCoordsFromLogIndex(
        questLogIndex,
        playerX,
        playerY,
        mapId,
        { bypassLock = true, bypassCache = true }
    )
    if not qx or not qy then
        qx, qy, questId, poiSource = GetQuestPoiCoordsFromLogIndex(
            questLogIndex,
            playerX,
            playerY,
            mapId
        )
    end
    if not qx or not qy then
        return
    end

    local distanceYards, dxYards, dyYards = ComputeDistanceYards(mapId, playerX, playerY, qx, qy)
    if not distanceYards then
        return
    end

    local superTrackedQuestId = Navigation:GetSuperTrackedQuestID()
    local facing = (type(GetPlayerFacing) == "function") and (GetPlayerFacing() or 0) or 0
    local direction, relative = ComputeRelativeHeading(facing, playerX, playerY, qx, qy, dxYards, dyYards)

    seenQuestIds[info.questId] = true

    local radiusYards, boundaryPoints = ResolveQuestPoiBoundary(questLogIndex, questId, mapId, qx, qy)
    local boundaryX, boundaryY, _ = CalculateNearestBoundaryPoint(
        playerX,
        playerY,
        qx,
        qy,
        radiusYards,
        dxYards,
        dyYards,
        boundaryPoints
    )
    local boundaryDistanceYards, boundaryDxYards, boundaryDyYards = ComputeDistanceYards(mapId, playerX, playerY, boundaryX, boundaryY)
    local boundaryDirection, boundaryRelative = ComputeRelativeHeading(
        facing,
        playerX,
        playerY,
        boundaryX,
        boundaryY,
        boundaryDxYards or dxYards,
        boundaryDyYards or dyYards
    )

    table.insert(pins, {
        questId = questId,
        questLogIndex = questLogIndex,
        title = info.title,
        pinKind = pinKind,
        pinSource = pinSource,
        poiSource = poiSource,
        style = GetQuestPinStyle(info, pinKind),
        isDaily = info.isDaily,
        isComplete = info.isComplete,
        isFocused = pinKind == "focused",
        isSuperTracked = superTrackedQuestId and superTrackedQuestId == questId,
        centerX = qx,
        centerY = qy,
        radiusYards = radiusYards,
        boundaryX = boundaryX,
        boundaryY = boundaryY,
        distanceYards = boundaryDistanceYards or distanceYards,
        direction = boundaryDirection or direction,
        relative = boundaryRelative or relative,
    })
end

local function BuildMinimapQuestPins(playerX, playerY, mapId, target)
    local pins = {}
    local seenQuestIds = {}

    if target and target.x and target.y then
        local distanceYards, dxYards, dyYards = ComputeDistanceYards(mapId, playerX, playerY, target.x, target.y)
        if distanceYards then
            local facing = (type(GetPlayerFacing) == "function") and (GetPlayerFacing() or 0) or 0
            local direction, relative = ComputeRelativeHeading(
                facing,
                playerX,
                playerY,
                target.x,
                target.y,
                dxYards,
                dyYards
            )
            local questLogIndex = target.questId and FindQuestLogIndexByQuestId(target.questId) or nil
            local info = questLogIndex and GetQuestLogInfo(questLogIndex) or nil
            local pinKind = target.questId and "quest" or "manual"

            local radiusYards, boundaryPoints = 0, nil
            if questLogIndex then
                radiusYards, boundaryPoints = ResolveQuestPoiBoundary(questLogIndex, target.questId, mapId, target.x, target.y)
            end
            local boundaryX, boundaryY, _ = CalculateNearestBoundaryPoint(
                playerX,
                playerY,
                target.x,
                target.y,
                radiusYards,
                dxYards,
                dyYards,
                boundaryPoints
            )
            local boundaryDistanceYards, boundaryDxYards, boundaryDyYards = ComputeDistanceYards(mapId, playerX, playerY, boundaryX, boundaryY)
            local boundaryDirection, boundaryRelative = ComputeRelativeHeading(
                facing,
                playerX,
                playerY,
                boundaryX,
                boundaryY,
                boundaryDxYards or dxYards,
                boundaryDyYards or dyYards
            )

            table.insert(pins, {
                questId = target.questId,
                questLogIndex = questLogIndex,
                title = target.title,
                pinKind = pinKind,
                pinSource = target.source,
                poiSource = target.poiSource,
                style = GetQuestPinStyle(info, pinKind),
                isDaily = info and info.isDaily or false,
                isComplete = info and info.isComplete or false,
                isFocused = target.source == "quest-focused",
                isSuperTracked = target.questId and Navigation:GetSuperTrackedQuestID() == target.questId,
                centerX = target.x,
                centerY = target.y,
                radiusYards = radiusYards,
                boundaryX = boundaryX,
                boundaryY = boundaryY,
                distanceYards = boundaryDistanceYards or distanceYards,
                direction = boundaryDirection or direction,
                relative = boundaryRelative or relative,
            })

            if target.questId then
                seenQuestIds[target.questId] = true
            end
        end
    end

    if type(GetQuestLogSelection) == "function" then
        local focusedQuestLogIndex = GetQuestLogSelection()
        if focusedQuestLogIndex and focusedQuestLogIndex > 0 then
            AddQuestPinCandidate(pins, seenQuestIds, playerX, playerY, mapId, focusedQuestLogIndex, "focused", "focused")
        end
    end

    if type(GetNumQuestWatches) == "function" and type(GetQuestWatchInfo) == "function" then
        local watchCount = GetNumQuestWatches() or 0
        for watchIndex = 1, watchCount do
            local questLogIndex = ResolveQuestLogIndexFromWatchIndex(watchIndex)
            if questLogIndex and questLogIndex > 0 then
                AddQuestPinCandidate(pins, seenQuestIds, playerX, playerY, mapId, questLogIndex, "quest", "watch")
            end
        end
    end

    return pins
end

local function GetMinimapPinPriority(pin)
    local priority = 0
    if pin.pinKind == "waypoint" or pin.pinKind == "manual" then
        priority = priority + 100
    end
    if pin.isFocused then
        priority = priority + 35
    end
    if pin.isSuperTracked then
        priority = priority + 25
    end
    if pin.isDaily then
        priority = priority + 10
    end
    if pin.isComplete then
        priority = priority + 8
    end

    return priority - ((pin.distanceYards or 0) * 0.001)
end

local function ApplyMinimapPinStyle(pinFrame, pin, now, radiusPx, diameterYards)
    local isWaypoint = pin.pinKind == "manual"
    local showQuestZone = pin.questId and pin.radiusYards and pin.radiusYards > 0
    -- Quest POIs should render as area boundaries only (retail-like), not as
    -- moving minimap icon diamonds.
    local showIcon = isWaypoint
    local colorR, colorG, colorB, glowAlpha = GetQuestPinPalette(pin.style)
    local baseWidth = ICON_WIDTH * (isWaypoint and MINIMAP_WAYPOINT_SCALE or MINIMAP_QUEST_SCALE)
    local baseHeight = ICON_HEIGHT * (isWaypoint and MINIMAP_WAYPOINT_SCALE or MINIMAP_QUEST_SCALE)

    if isWaypoint and not pin.isComplete then
        local pulse = 1 + (0.05 * math_abs(math_sin((now or 0) * 6.0)))
        baseWidth = baseWidth * pulse
        baseHeight = baseHeight * pulse
        glowAlpha = glowAlpha + 0.04
    end

    if not pinFrame.Icon then
        return
    end

    if showIcon then
        pinFrame.Icon:SetSize(baseWidth, baseHeight)
        pinFrame.Icon:SetVertexColor(colorR, colorG, colorB)
        pinFrame.Icon:Show()
    else
        pinFrame.Icon:Hide()
    end

    if pinFrame.Glow then
        if showIcon then
            pinFrame.Glow:SetSize(baseWidth * 1.75, baseHeight * 1.4)
            pinFrame.Glow:SetVertexColor(colorR, colorG, colorB, glowAlpha)
            pinFrame.Glow:Show()
        else
            pinFrame.Glow:Hide()
        end
    end

    if pinFrame.Highlight then
        if showIcon then
            pinFrame.Highlight:SetSize(baseWidth * 2.0, baseHeight * 1.75)
            pinFrame.Highlight:SetVertexColor(
                colorR,
                colorG,
                colorB,
                (pin.isFocused or pin.isSuperTracked or isWaypoint) and 0.20 or 0.0
            )
            pinFrame.Highlight:Show()
        else
            pinFrame.Highlight:Hide()
        end
    end

    if showQuestZone and radiusPx and radiusPx > 0 and diameterYards and diameterYards > 0 then
        if not pinFrame.ZoneFill then
            pinFrame.ZoneFill = pinFrame:CreateTexture(nil, "BORDER")
            pinFrame.ZoneFill:SetTexture("Interface\\Minimap\\UI-Minimap-Ping")
            pinFrame.ZoneFill:SetBlendMode("ADD")
        end
        if not pinFrame.BoundaryOutline then
            pinFrame.BoundaryOutline = pinFrame:CreateTexture(nil, "OVERLAY")
            pinFrame.BoundaryOutline:SetTexture("Interface\\Minimap\\UI-Minimap-Ping-Expand")
            pinFrame.BoundaryOutline:SetBlendMode("ADD")
        end

        local boundaryPixelRadius = (pin.radiusYards / (diameterYards * 0.5)) * radiusPx
        if boundaryPixelRadius > 2 then
            local zoneDiameter = boundaryPixelRadius * 2
            pinFrame.ZoneFill:SetSize(zoneDiameter, zoneDiameter)
            pinFrame.ZoneFill:SetPoint("CENTER", pinFrame, "CENTER", 0, 0)
            pinFrame.ZoneFill:SetVertexColor(0.26, 0.70, 1.0, 0.16)
            pinFrame.ZoneFill:Show()

            pinFrame.BoundaryOutline:SetSize(boundaryPixelRadius * 2, boundaryPixelRadius * 2)
            pinFrame.BoundaryOutline:SetPoint("CENTER", pinFrame, "CENTER", 0, 0)
            pinFrame.BoundaryOutline:SetVertexColor(0.48, 0.86, 1.0, 0.24)
            pinFrame.BoundaryOutline:Show()
        else
            pinFrame.ZoneFill:Hide()
            pinFrame.BoundaryOutline:Hide()
        end
    else
        if pinFrame.ZoneFill then
            pinFrame.ZoneFill:Hide()
        end
        if pinFrame.BoundaryOutline then
            pinFrame.BoundaryOutline:Hide()
        end
    end
end

local function UpdateMinimapQuestPins(playerX, playerY, mapId, target)
    local container = EnsureMinimapPinContainer()
    if not container or not Minimap or not addon.settings.navigation.enabled then
        ClearMinimapQuestPins()
        return
    end

    local candidates = BuildMinimapQuestPins(playerX, playerY, mapId, target)
    if #candidates == 0 then
        ClearMinimapQuestPins()
        return
    end

    local radiusPx = (math_min(Minimap:GetWidth() or 0, Minimap:GetHeight() or 0) * 0.5) - MINIMAP_PIN_EDGE_PADDING
    if radiusPx <= 0 then
        ClearMinimapQuestPins()
        return
    end

    local diameterYards = GetMinimapDiameterYards()
    local rotateMinimap = IsMinimapRotating()
    local facing = (type(GetPlayerFacing) == "function") and (GetPlayerFacing() or 0) or 0
    local quantized = {}

    for i = 1, #candidates do
        local pin = candidates[i]
        local heading = rotateMinimap and pin.relative or pin.direction
        local projectionDistance = (pin.distanceYards or 0)
        local isWaypointPin = pin.pinKind == "waypoint" or pin.pinKind == "manual"

        if (not isWaypointPin) and pin.centerX and pin.centerY and pin.radiusYards and pin.radiusYards > 0 then
            local centerDistance, centerDxYards, centerDyYards = ComputeDistanceYards(
                mapId,
                playerX,
                playerY,
                pin.centerX,
                pin.centerY
            )
            if centerDistance then
                projectionDistance = centerDistance
                local centerDirection, centerRelative = ComputeRelativeHeading(
                    facing,
                    playerX,
                    playerY,
                    pin.centerX,
                    pin.centerY,
                    centerDxYards,
                    centerDyYards
                )
                heading = rotateMinimap and centerRelative or centerDirection
            end
        end

        local projectedRadius = 0
        if diameterYards > 0 then
            projectedRadius = (projectionDistance / (diameterYards * 0.5)) * radiusPx
        end
        if projectedRadius > radiusPx then
            projectedRadius = radiusPx
        end

        local x = math_sin(heading or 0) * projectedRadius
        local y = math_cos(heading or 0) * projectedRadius
        pin.pixelX = x
        pin.pixelY = y
        pin.priority = GetMinimapPinPriority(pin)

        local bucketX = math_floor((x + radiusPx) / MINIMAP_PIN_BUCKET_SIZE)
        local bucketY = math_floor((y + radiusPx) / MINIMAP_PIN_BUCKET_SIZE)
        local bucketKey = tostring(bucketX) .. ":" .. tostring(bucketY)
        local existing = quantized[bucketKey]
        if not existing or pin.priority > existing.priority then
            quantized[bucketKey] = pin
        end
    end

    local visiblePins = {}
    for _, pin in pairs(quantized) do
        table.insert(visiblePins, pin)
    end

    table.sort(visiblePins, function(a, b)
        if a.priority == b.priority then
            return (a.distanceYards or 0) < (b.distanceYards or 0)
        end
        return a.priority > b.priority
    end)

    local signatureParts = {}
    local now = GetTime() or 0
    local renderCount = math_min(#visiblePins, MINIMAP_PIN_MAX_COUNT)

    for index = 1, renderCount do
        local pin = visiblePins[index]
        local pinFrame = AcquireMinimapPin(index)
        if pinFrame then
            pinFrame:ClearAllPoints()
            pinFrame:SetPoint("CENTER", container, "CENTER", pin.pixelX, pin.pixelY)
            ApplyMinimapPinStyle(pinFrame, pin, now, radiusPx, diameterYards)
            pinFrame:Show()
            signatureParts[index] = string.format(
                "%s:%s:%d:%d",
                tostring(pin.questId or pin.pinKind or "n/a"),
                tostring(pin.style or "normal"),
                math_floor(pin.pixelX or 0),
                math_floor(pin.pixelY or 0)
            )
        end
    end

    for index = renderCount + 1, #state.minimapPins do
        state.minimapPins[index]:Hide()
    end

    state.lastMinimapPinCount = renderCount
    state.lastMinimapPinSig = table.concat(signatureParts, "|")
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

local function IsLikelyUserWaypointText(text)
    if type(text) ~= "string" then
        return false
    end

    local normalized = text:lower():gsub("^%s+", ""):gsub("%s+$", "")
    return normalized == "user waypoint" or normalized == "waypoint"
end

local function IsLikelyUserWaypoint(mapId, x, y, waypointText)
    if IsLikelyUserWaypointText(waypointText) then
        return true
    end

    if not mapId or not x or not y then
        return false
    end

    if not ShimHasUserWaypoint() then
        return false
    end

    local userX, userY = ShimGetUserWaypointPositionForMap(mapId)
    if not userX or not userY then
        return false
    end

    local dx = math_abs(x - userX)
    local dy = math_abs(y - userY)
    return dx <= 0.0015 and dy <= 0.0015
end

local function EnsureFollowedQuestPriorityOverUserWaypoint()
    if not state.followedQuestId or state.followedQuestId <= 0 then
        return false
    end

    if not ShimIsSuperTrackingUserWaypoint() then
        return false
    end

    return ShimSetSuperTrackedUserWaypoint(false)
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

    local livePoiOptions = {
        bypassLock = true,
        bypassCache = true,
        clearQuestCache = isCompleted == true,
    }

    local qx, qy, questId, poiSource = GetQuestPoiCoordsFromLogIndex(questLogIndex, playerX, playerY, mapId, livePoiOptions)
    if not qx or not qy then
        qx, qy, questId, poiSource = GetQuestPoiCoordsFromLogIndex(questLogIndex, playerX, playerY, mapId, poiOptions)
    end

    if (not qx or not qy) and state.followedQuestId then
        local byIdIndex = FindQuestLogIndexByQuestId(state.followedQuestId)
        if byIdIndex and byIdIndex ~= questLogIndex then
            questLogIndex = byIdIndex
            title, isHeader = GetQuestTitleFromLogIndex(questLogIndex)
            if not isHeader then
                isCompleted = IsQuestLogIndexCompleted(questLogIndex)
                poiOptions = isCompleted and { bypassCache = true, clearQuestCache = true } or nil
                livePoiOptions = {
                    bypassLock = true,
                    bypassCache = true,
                    clearQuestCache = isCompleted == true,
                }

                qx, qy, questId, poiSource = GetQuestPoiCoordsFromLogIndex(questLogIndex, playerX, playerY, mapId, livePoiOptions)
                if not qx or not qy then
                    qx, qy, questId, poiSource = GetQuestPoiCoordsFromLogIndex(questLogIndex, playerX, playerY, mapId, poiOptions)
                end
            end
        end
    end

    if (not qx or not qy) and mapId and state.followedQuestId then
        local shimX, shimY = ShimGetSuperTrackedQuestWaypointForMap(mapId)
        if shimX and shimY then
            qx = shimX
            qy = shimY
            questId = state.followedQuestId
            poiSource = "shim-waypoint"
        end
    end

    if (not qx or not qy) and mapId and state.followedQuestId and state.followedQuestId > 0 then
        local nextX, nextY, nextText = ShimGetNextWaypointForMap(mapId)
        if nextX and nextY and not IsLikelyUserWaypoint(mapId, nextX, nextY, nextText) then
            qx = nextX
            qy = nextY
            questId = state.followedQuestId
            poiSource = "shim-next-waypoint"
            if (not title or title == "") and nextText then
                title = nextText
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

    -- Focused quest should track the current UI POI immediately. Query live data
    -- first, then fall back to cached/locked coordinates when API data is absent.
    local qx, qy, questId, poiSource = GetQuestPoiCoordsFromLogIndex(
        questLogIndex,
        playerX,
        playerY,
        mapId,
        {
            bypassLock = true,
            bypassCache = true,
        }
    )
    if not qx or not qy then
        qx, qy, questId, poiSource = GetQuestPoiCoordsFromLogIndex(questLogIndex, playerX, playerY, mapId)
    end
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

local function BuildSuperTrackedWaypointTarget(mapId, source, title)
    if not mapId then
        return nil
    end

    local x, y, waypointText = ShimGetNextWaypointForMap(mapId)
    if not x or not y then
        return nil
    end

    local targetTitle = title
    if not targetTitle or targetTitle == "" then
        targetTitle = waypointText
    end
    if not targetTitle or targetTitle == "" then
        targetTitle = "Waypoint"
    end

    return {
        source = source or "supertracked-waypoint",
        title = targetTitle,
        x = x,
        y = y,
    }
end

local function GetSuperTrackedNonQuestTarget(mapId)
    local superTrackApi = _G.C_SuperTrack
    if type(superTrackApi) ~= "table" then
        return nil
    end

    local highType = type(superTrackApi.GetHighestPrioritySuperTrackingType) == "function" and superTrackApi.GetHighestPrioritySuperTrackingType() or nil
    local enumTable = _G.Enum and _G.Enum.SuperTrackingType
    local enumUserWaypoint = type(enumTable) == "table" and enumTable.UserWaypoint or nil
    local enumMapPin = type(enumTable) == "table" and enumTable.MapPin or nil
    local enumVignette = type(enumTable) == "table" and enumTable.Vignette or nil
    local enumContent = type(enumTable) == "table" and enumTable.Content or nil

    if highType == enumUserWaypoint or (enumUserWaypoint == nil and ShimIsSuperTrackingUserWaypoint()) then
        local x, y = ShimGetUserWaypointPositionForMap(mapId)
        if x and y then
            return {
                source = "supertracked-user-waypoint",
                title = "Waypoint",
                x = x,
                y = y,
            }
        end
    end

    if highType == enumMapPin or (enumMapPin == nil and NormalizeSuperTrackedContentType(state.retailSuperTrackedContentType) == "mapPin") then
        local point = state.retailSuperTrackedMapPinPoint
        if point and point.uiMapID == mapId and point.x and point.y then
            return {
                source = "supertracked-map-pin",
                title = "Map Pin",
                x = point.x,
                y = point.y,
            }
        end
        return BuildSuperTrackedWaypointTarget(mapId, "supertracked-map-pin", "Map Pin")
    end

    if highType == enumVignette or (enumVignette == nil and NormalizeSuperTrackedContentType(state.retailSuperTrackedContentType) == "vignette") then
        return BuildSuperTrackedWaypointTarget(mapId, "supertracked-vignette", "Vignette")
    end

    if highType == enumContent or (enumContent == nil and NormalizeSuperTrackedContentType(state.retailSuperTrackedContentType) == "content") then
        return BuildSuperTrackedWaypointTarget(mapId, "supertracked-content", "Content")
    end

    return nil
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

    ShimSetSuperTrackedUserWaypoint(false)

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
    local manualTarget = GetManualTarget(mapId)
    if manualTarget then
        return manualTarget
    end

    local superTrackedNonQuestTarget = GetSuperTrackedNonQuestTarget(mapId)
    if superTrackedNonQuestTarget then
        return superTrackedNonQuestTarget
    end

    local followedTarget = GetFollowedQuestTarget(playerX, playerY, mapId)
    if followedTarget then
        return followedTarget
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

    frame.IconShadow = frame:CreateTexture(nil, "BACKGROUND")
    if TrySetTrackedIconAtlas(frame.IconShadow) then
        frame.IconShadow:SetSize(frame.iconBaseWidth or ICON_WIDTH, frame.iconBaseHeight or ICON_HEIGHT)
    else
        frame.IconShadow:SetTexture(TEXTURE_ATLAS)
        frame.IconShadow:SetTexCoord(unpack(ICON_TEXCOORD))
        frame.IconShadow:SetSize(frame.iconBaseWidth or ICON_WIDTH, frame.iconBaseHeight or ICON_HEIGHT)
    end
    frame.IconShadow:SetPoint("CENTER", frame.Icon, "CENTER", 1, -1)
    frame.IconShadow:SetVertexColor(0, 0, 0, 0.45)

    frame.IconGlow = frame:CreateTexture(nil, "OVERLAY")
    frame.IconGlow:SetTexture("Interface\\Minimap\\UI-Minimap-Ping-Expand")
    frame.IconGlow:SetBlendMode("ADD")
    frame.IconGlow:SetSize((frame.iconBaseWidth or ICON_WIDTH) * 2.1, (frame.iconBaseHeight or ICON_HEIGHT) * 1.85)
    frame.IconGlow:SetPoint("CENTER", frame.Icon, "CENTER", 0, 0)
    frame.IconGlow:SetVertexColor(1.0, 0.88, 0.30, 0.16)

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
    frame.Icon:SetVertexColor(1.0, 0.88, 0.32)
    if frame.IconShadow then
        frame.IconShadow:SetSize((frame.iconBaseWidth or ICON_WIDTH) + 2, (frame.iconBaseHeight or ICON_HEIGHT) + 2)
        frame.IconShadow:SetVertexColor(0, 0, 0, 0.45)
    end
    if frame.IconGlow then
        frame.IconGlow:SetSize((frame.iconBaseWidth or ICON_WIDTH) * 2.1, (frame.iconBaseHeight or ICON_HEIGHT) * 1.85)
        frame.IconGlow:SetVertexColor(1.0, 0.88, 0.32, 0.16)
    end
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
    ClearMinimapQuestPins()
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

    if mapId then
        local wx, wy, waypointText = ShimGetNextWaypointForMap(mapId)
        if waypointText then
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

    UpdateMinimapQuestPins(playerX, playerY, mapId, target)

    local frame = EnsureFrame()
    frame:SetScale(settings.markerScale or 1.0)

    local navX, navY, navRadiusYards = ResolveQuestTargetNavigationPoint(playerX, playerY, mapId, target)
    navX = navX or target.x
    navY = navY or target.y

    target.navX = navX
    target.navY = navY
    target.radiusYards = navRadiusYards

    local distanceYards, dxYards, dyYards = ComputeDistanceYards(mapId, playerX, playerY, navX, navY)
    state.target = target
    state.lastDistance = distanceYards

    local targetKey = BuildTargetKey(target)
    UpdateTravelMetrics(distanceYards, targetKey)

    -- Keep native supertrack state aligned with the currently focused quest POI
    -- so native navigation frame projection can resolve active target geometry.
    if target and type(target.x) == "number" and type(target.y) == "number" and tonumber(mapId) then
        local nativeSyncKey = string.format(
            "%d:%.5f:%.5f:%s",
            tonumber(mapId) or 0,
            tonumber(navX) or 0,
            tonumber(navY) or 0,
            tostring(target.questId or "")
        )

        if nativeSyncKey ~= state.lastNativeNavigationSyncKey then
            state.lastNativeNavigationSyncKey = nativeSyncKey

            local qid = tonumber(target.questId)
            if qid and qid > 0 and type(state.nativeSetSuperTrackedQuestID) == "function" then
                pcall(state.nativeSetSuperTrackedQuestID, qid)
            end

            if type(target.title) == "string" and target.title ~= ""
                and type(state.nativeSetSuperTrackedQuestName) == "function" then
                pcall(state.nativeSetSuperTrackedQuestName, target.title)
            end

            if type(state.nativeSetSuperTrackedQuestWaypointForMap) == "function" then
                pcall(state.nativeSetSuperTrackedQuestWaypointForMap, tonumber(mapId), navX, navY)
            end
        end
    end

    MaybeClearManualOnArrival(target, distanceYards)

    local facing = (type(GetPlayerFacing) == "function") and (GetPlayerFacing() or 0) or 0
    local direction, relative = ComputeRelativeHeading(
        facing,
        playerX,
        playerY,
        navX,
        navY,
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

    if type(state.nativeNavigationSetPlayerState) == "function" then
        pcall(state.nativeNavigationSetPlayerState, tonumber(mapId), tonumber(playerX), tonumber(playerY), tonumber(facing or 0))
    end

    local arrivalDistance = settings.arrivalDistanceYards or 8
    local arrived = distanceYards and distanceYards <= arrivalDistance
    local now = GetTime() or 0

    local iconBaseWidth = frame.iconBaseWidth or ICON_WIDTH
    local iconBaseHeight = frame.iconBaseHeight or ICON_HEIGHT
    local arrowBaseWidth = frame.arrowBaseWidth or ARROW_WIDTH
    local arrowBaseHeight = frame.arrowBaseHeight or ARROW_HEIGHT

    local iconR, iconG, iconB = 1.0, 0.88, 0.32
    if settings.colorizeArrow and not arrived then
        local headingR, headingG, headingB = GetHeadingColor(relative)
        iconR = (iconR * 0.62) + (headingR * 0.38)
        iconG = (iconG * 0.62) + (headingG * 0.38)
        iconB = (iconB * 0.62) + (headingB * 0.38)
    end

    local iconWidth = iconBaseWidth * 1.10
    local iconHeight = iconBaseHeight * 1.10

    if arrived then
        iconR, iconG, iconB = 0.20, 1.0, 0.35
        if settings.pulseOnArrival then
            local pulse = 1 + (0.12 * math_abs(math_sin(now * 7.5)))
            iconWidth = iconWidth * pulse
            iconHeight = iconHeight * pulse
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

    frame.Icon:SetSize(iconWidth, iconHeight)
    frame.Icon:SetVertexColor(iconR, iconG, iconB)
    frame.Arrow:SetSize(arrowBaseWidth, arrowBaseHeight)
    frame.Arrow:SetVertexColor(1, 1, 1)

    if frame.IconShadow then
        frame.IconShadow:SetSize(iconWidth + 2, iconHeight + 2)
        frame.IconShadow:SetVertexColor(0, 0, 0, arrived and 0.30 or 0.42)
    end

    if frame.IconGlow then
        local glowAlpha
        if arrived then
            glowAlpha = 0.30
            if settings.pulseOnArrival then
                glowAlpha = glowAlpha + (0.08 * math_abs(math_sin(now * 7.5)))
            end
        else
            glowAlpha = 0.18
        end

        frame.IconGlow:SetSize(iconWidth * 2.05, iconHeight * 1.85)
        frame.IconGlow:SetVertexColor(iconR, iconG, iconB, glowAlpha)
    end

    local projectionScale = settings.distanceScreenScale or 0.45
    if projectionScale < 0.05 then
        projectionScale = 0.05
    end

    local configuredYOffset = settings.inFrontYOffset
    local anchorYOffset
    if configuredYOffset == nil or configuredYOffset == -120 or configuredYOffset == 130 then
        -- Migrate legacy defaults so the marker follows POI-relative placement.
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
    local clampedToEllipse = false
    local usingNativeProjection = false
    local nativeNavState = nil
    local fallbackRadius = nil

    -- Native-first path (Blizzard-like): when a native projection export exists,
    -- use it as authoritative frame position/state and only fall back to Lua math.
    local getNativeNavigationFrameState = nil
    if type(state.nativeNavigationGetFrameState) == "function" then
        getNativeNavigationFrameState = state.nativeNavigationGetFrameState
    elseif type(_G.GetNavigationFrameState) == "function" then
        getNativeNavigationFrameState = _G.GetNavigationFrameState
    elseif type(_G.C_Navigation_GetFrameState) == "function" then
        getNativeNavigationFrameState = _G.C_Navigation_GetFrameState
    end

    local rawX
    local rawY
    local useNativeProjection = getNativeNavigationFrameState
    local nativeUsedWorldProjection = nil

    if useNativeProjection then
        local ok, nativeX, nativeY, stateValue, clampedValue, worldProjectionValue = pcall(getNativeNavigationFrameState)
        if ok and type(nativeX) == "number" and type(nativeY) == "number" then
            projectedX = nativeX
            projectedY = nativeY
            rawX = nativeX
            rawY = nativeY
            nativeNavState = tonumber(stateValue)

            if type(worldProjectionValue) == "boolean" then
                nativeUsedWorldProjection = worldProjectionValue
            end

            clampedToEllipse = (clampedValue == true) or (nativeNavState == NAV_STATE_OCCLUDED)

            -- Retail behavior: only clamp to edge indicator when nav reports
            -- occluded/clamped. Unclamped native positions should be used as-is.
            if clampedToEllipse then
                local clampedX, clampedY = ClampPointToEllipse(nativeX, nativeY, ellipseMajorAxis, ellipseMinorAxis)
                projectedX = clampedX
                projectedY = clampedY
            end

            if nativeNavState == nil then
                nativeNavState = (clampedToEllipse and NAV_STATE_OCCLUDED or NAV_STATE_IN_RANGE)
            end

            usingNativeProjection = true
        elseif ok then
            local nowStamp = GetTime() or 0
            if (nowStamp - (state.lastNativeProjectionNilAt or 0)) > 2.0 then
                state.lastNativeProjectionNilAt = nowStamp
                DebugNavigationProjection("native-frame-state unavailable (function returned nil); falling back to Lua projection", true)
            end
        end
    end

    if not usingNativeProjection then
        if type(dxYards) ~= "number" or type(dyYards) ~= "number" then
            DebugNavigationProjection("reject: missing map delta for target " .. tostring(targetKey), true)
            ClearMarker()
            return
        end

        -- POI-locked fallback: use POI deltas for distance, then rotate by
        -- facing-relative heading so screen placement follows world direction.
        fallbackRadius = math_sqrt((dxYards * dxYards) + (dyYards * dyYards)) * projectionScale
        rawX = math_sin(relative) * fallbackRadius
        rawY = (math_cos(relative) * fallbackRadius) + anchorYOffset

        projectedX, projectedY, clampedToEllipse = ClampPointToEllipse(rawX, rawY, ellipseMajorAxis, ellipseMinorAxis)

        -- Keep markers edge-clamped when the target is outside the forward camera
        -- hemisphere so outside-view targets always show as edge indicators.
        if not clampedToEllipse and math_cos(relative or 0) <= 0 then
            local majorSquared = ellipseMajorAxis * ellipseMajorAxis
            local minorSquared = ellipseMinorAxis * ellipseMinorAxis
            local denominator = math_sqrt((majorSquared * rawY * rawY) + (minorSquared * rawX * rawX))
            if denominator and denominator > 0 then
                local ratio = (ellipseMajorAxis * ellipseMinorAxis) / denominator
                projectedX = rawX * ratio
                projectedY = rawY * ratio
                clampedToEllipse = true
            end
        end
    end

    local projectionDebugKey = string.format(
        "%s:%d:%d:%s",
        tostring(targetKey or "n/a"),
        math_floor((projectedX or 0) / 8),
        math_floor((projectedY or 0) / 8),
        clampedToEllipse and "1" or "0"
    )

    local dxDebug = tonumber(dxYards) or 0
    local dyDebug = tonumber(dyYards) or 0
    local projectionState = nativeNavState
    if projectionState == nil then
        projectionState = clampedToEllipse and NAV_STATE_OCCLUDED or NAV_STATE_IN_RANGE
    end

    DebugNavigationProjection(
        string.format(
            "target=%s src=%s dist=%s dx=%.2f dy=%.2f rel=%.1f radius=%s rawX=%.2f rawY=%.2f px=%.2f py=%.2f clamp=%s state=%s",
            tostring(targetKey or "n/a"),
            tostring(usingNativeProjection and ((nativeUsedWorldProjection == true and "native-world") or "native-fallback") or (target.poiSource or target.source or "n/a")),
            distanceYards and string.format("%.1f", distanceYards) or "nil",
            dxDebug,
            dyDebug,
            math_deg(relative or 0),
            fallbackRadius and string.format("%.2f", fallbackRadius) or "n/a",
            rawX or 0,
            rawY or 0,
            projectedX or 0,
            projectedY or 0,
            tostring(clampedToEllipse == true),
            GetNavStateName(projectionState)
        ),
        false,
        projectionDebugKey
    )

    DebugNativeProjectionStats()

    local projectedRadius = math_sqrt((projectedX * projectedX) + (projectedY * projectedY))

    state.lastPoiSource = target.poiSource
    state.lastProjectedRadius = projectedRadius
    state.lastClamped = clampedToEllipse

    if frame.IconGlow and clampedToEllipse and not arrived then
        frame.IconGlow:SetVertexColor(iconR, iconG, iconB, 0.10)
    end

    if state.lastVisualTargetKey ~= targetKey then
        state.lastVisualTargetKey = targetKey
        state.transparentUntil = now + 0.2
        frame:SetAlpha(0)
    end

    local navState = nativeNavState
    if navState == nil then
        if not distanceYards then
            navState = NAV_STATE_INVALID
        elseif clampedToEllipse then
            navState = NAV_STATE_OCCLUDED
        else
            navState = NAV_STATE_IN_RANGE
        end
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

    -- Keep the extension waypoint cache in sync so compatibility shims stay coherent.
    if ShimSetUserWaypoint(mapId, x, y) and ShimHasUserWaypoint() then
        local syncedX, syncedY = ShimGetUserWaypointPositionForMap(mapId)
        if syncedX and syncedY then
            manual.x = syncedX
            manual.y = syncedY
        end
    end
    ShimSetSuperTrackedUserWaypoint(false)

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
    ShimClearUserWaypoint()
    ShimSetSuperTrackedUserWaypoint(false)
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
    MaybeReloadMapForNavigation(false)

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

local function RequestQuestTrackingVisualRefresh()
    local now = GetTime() or 0
    if (now - (state.lastQuestVisualRefreshAt or 0)) < 0.03 then
        return
    end

    state.lastQuestVisualRefreshAt = now
    RefreshQuestTrackingVisuals()
end

local function RequestQuestTrackingVisualRefreshSettled(delay)
    if state.questVisualRefreshScheduled then
        return
    end

    local waitTime = tonumber(delay) or 0.05
    if waitTime < 0.01 then
        waitTime = 0.01
    end

    if addon and addon.DelayedCall then
        state.questVisualRefreshScheduled = true
        addon:DelayedCall(waitTime, function()
            state.questVisualRefreshScheduled = false
            RequestQuestTrackingVisualRefresh()
        end)
        return
    end

    RequestQuestTrackingVisualRefresh()
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
        ShimSetSuperTrackedUserWaypoint(false)
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

    RequestQuestTrackingVisualRefresh()
    RequestQuestTrackingVisualRefreshSettled(0.05)

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

function Navigation:GetSuperTrackedQuestID()
    local questId = ShimGetSuperTrackedQuestID()
    if questId and questId > 0 then
        return questId
    end

    questId = tonumber(state.followedQuestId)
    if questId and questId > 0 then
        return questId
    end

    return nil
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

local function PrimeQuestPoiButtonCacheFromVisibleButtons(force)
    if not _G then
        return
    end

    local now = GetTime() or 0
    if not force then
        local hasCache = state.questPoiButtons and next(state.questPoiButtons) ~= nil
        local minInterval = hasCache and 1.0 or 0.15
        if (now - (state.lastPoiButtonGlobalScanAt or 0)) < minInterval then
            return
        end
    end

    state.lastPoiButtonGlobalScanAt = now

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
                RequestQuestTrackingVisualRefresh()
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
                    RequestQuestTrackingVisualRefresh()
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
                    RequestQuestTrackingVisualRefresh()
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

        if text == "minimap" or text == "debug minimap" then
            local playerX, playerY, mapId = GetPlayerMapPositionSafe()
            local followedQuestId = tonumber(state.followedQuestId)
            local followedQuestIndex = tonumber(state.followedQuestLogIndex)
            local idxX, idxY, idxQuestId, idxSource = nil, nil, nil, nil
            local cacheX, cacheY, cacheCount = nil, nil, nil
            local trackedQuestId = Navigation:GetSuperTrackedQuestID()
            local numTracking = type(GetNumTrackingTypes) == "function" and (GetNumTrackingTypes() or 0) or 0
            local trackingSummary = {}

            if followedQuestIndex and followedQuestIndex > 0 then
                idxX, idxY, idxQuestId, idxSource = GetQuestPoiCoordsFromLogIndex(followedQuestIndex, playerX, playerY, mapId, { bypassLock = true })
            end

            if followedQuestId and followedQuestId > 0 then
                cacheX, cacheY, cacheCount = GetCachedQuestPoiCoords(followedQuestId, playerX, playerY, mapId)
            end

            if type(GetTrackingInfo) == "function" then
                for i = 1, numTracking do
                    local name, texture, active = GetTrackingInfo(i)
                    if type(name) == "string" and name ~= "" then
                        local lowerName = string.lower(name)
                        if lowerName:find("quest", 1, true) or lowerName:find("objective", 1, true) then
                            table.insert(trackingSummary, string.format("%d:%s=%s", i, name, tostring(active == true)))
                        end
                    elseif type(texture) == "string" then
                        local lowerTexture = string.lower(texture)
                        if lowerTexture:find("trackquest", 1, true) then
                            table.insert(trackingSummary, string.format("%d:%s=%s", i, texture, tostring(active == true)))
                        end
                    end
                end
            end

            addon:Print(string.format(
                "Navigation minimap: map=%s followedIndex=%s followedQuestId=%s trackedQuestId=%s questPOI=%s tracking=[%s] poi=%s,%s poiQuestId=%s poiSrc=%s cache=%s,%s cacheCount=%s fallbackPins=%s fallbackSig=%s",
                tostring(mapId or "n/a"),
                tostring(followedQuestIndex or "none"),
                tostring(followedQuestId or "none"),
                tostring(trackedQuestId or "none"),
                tostring(type(GetCVar) == "function" and GetCVar("questPOI") or "n/a"),
                (#trackingSummary > 0) and table.concat(trackingSummary, " | ") or "none",
                idxX and string.format("%.3f", idxX) or "nil",
                idxY and string.format("%.3f", idxY) or "nil",
                tostring(idxQuestId or "none"),
                tostring(idxSource or "none"),
                cacheX and string.format("%.3f", cacheX) or "nil",
                cacheY and string.format("%.3f", cacheY) or "nil",
                tostring(cacheCount or 0),
                tostring(state.lastMinimapPinCount or 0),
                tostring(state.lastMinimapPinSig or "none")
            ), true)
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
    EnsureRetailNavigationApiShims()
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
    EnsureRetailNavigationApiShims()
    ResolveSuperTrackShim()
    SyncFollowStateFromShim()

    EnsureSelectionHooks()
    EnsurePoiDisplayHook()
    EnsureWatchFrameHooks()

    if addon.EnsureQuestMinimapTrackingEnabled then
        addon:EnsureQuestMinimapTrackingEnabled("Navigation.OnEnable")
    end

    if not state.eventFrame then
        state.eventFrame = CreateFrame("Frame")
        state.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        state.eventFrame:RegisterEvent("ZONE_CHANGED")
        state.eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
        state.eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        state.eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
        state.eventFrame:RegisterEvent("QUEST_WATCH_UPDATE")
        if type(state.eventFrame.RegisterEvent) == "function" then
            pcall(state.eventFrame.RegisterEvent, state.eventFrame, "QUEST_ACCEPTED")
            pcall(state.eventFrame.RegisterEvent, state.eventFrame, "QUEST_TURNED_IN")
            pcall(state.eventFrame.RegisterEvent, state.eventFrame, "QUEST_WATCH_LIST_CHANGED")
            pcall(state.eventFrame.RegisterEvent, state.eventFrame, "SUPER_TRACKING_CHANGED")
            pcall(state.eventFrame.RegisterEvent, state.eventFrame, "SUPER_TRACKING_PATH_UPDATED")
        end
        if type(state.eventFrame.RegisterEvent) == "function" then
            pcall(state.eventFrame.RegisterEvent, state.eventFrame, "QUEST_POI_UPDATE")
        end
        state.eventFrame:SetScript("OnEvent", function(_, event, ...)
            EnsureWatchFrameHooks()
            EnsurePoiDisplayHook()
            AnnotateWatchFrameQuestIndices()
            if event == "PLAYER_ENTERING_WORLD"
                or event == "ZONE_CHANGED"
                or event == "ZONE_CHANGED_INDOORS"
                or event == "ZONE_CHANGED_NEW_AREA" then
                ClearQuestPoiCache()
                if addon.EnsureQuestMinimapTrackingEnabled then
                    addon:EnsureQuestMinimapTrackingEnabled(event)
                end
            end

            if event == "QUEST_POI_UPDATE" then
                -- POI updates indicate objective movement/advancement; clear both
                -- cache and lock state so followed quests do not remain static.
                ClearQuestPoiCache()
            end

            if event == "QUEST_ACCEPTED" then
                local questId = tonumber((...))
                if questId and questId > 0 then
                    ClearQuestPoiCacheForQuest(questId)
                end
            end

            if event == "QUEST_TURNED_IN" then
                local questId = tonumber((...))
                if questId and questId > 0 then
                    ClearQuestPoiCacheForQuest(questId)
                    if state.followedQuestId == questId then
                        state.followedQuestId = nil
                        state.followedQuestLogIndex = nil
                        state.followedQuestTitle = nil
                    end
                end
            end

            if event == "QUEST_WATCH_LIST_CHANGED" then
                local questId, tracked = ...
                if tracked == false then
                    local normalizedQuestId = tonumber(questId)
                    if normalizedQuestId and normalizedQuestId > 0 and state.followedQuestId == normalizedQuestId then
                        state.followedQuestId = nil
                        state.followedQuestLogIndex = nil
                        state.followedQuestTitle = nil
                    end
                end
            end

            if event == "SUPER_TRACKING_CHANGED" or event == "SUPER_TRACKING_PATH_UPDATED" then
                SyncFollowStateFromShim()
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
                    ClearQuestPoiCacheForQuest(state.followedQuestId)
                end
            end

            if event == "QUEST_LOG_UPDATE"
                or event == "QUEST_WATCH_UPDATE"
                or event == "QUEST_POI_UPDATE"
                or event == "SUPER_TRACKING_CHANGED"
                or event == "SUPER_TRACKING_PATH_UPDATED"
                or event == "QUEST_ACCEPTED"
                or event == "QUEST_TURNED_IN"
                or event == "QUEST_WATCH_LIST_CHANGED" then
                if addon.EnsureQuestMinimapTrackingEnabled then
                    addon:EnsureQuestMinimapTrackingEnabled(event)
                end
                RequestQuestTrackingVisualRefresh()
                RequestQuestTrackingVisualRefreshSettled(0.05)
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

    local reloadMapCb = addon:CreateCheckbox(parent)
    reloadMapCb:SetPoint("TOPLEFT", 16, yOffset)
    reloadMapCb.Text:SetText("Use ReloadMap() for navigation refreshes (opt-in, throttled)")
    reloadMapCb:SetChecked(settings.enableReloadMapRefresh)
    reloadMapCb:SetScript("OnClick", function(self)
        addon:SetSetting("navigation.enableReloadMapRefresh", self:GetChecked())
        state.lastReloadMapAt = 0
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
    frontOffsetSlider:SetValue(settings.inFrontYOffset or 0)
    frontOffsetSlider.Text:SetText("Screen Anchor Y Offset: " .. tostring(settings.inFrontYOffset or 0))
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
