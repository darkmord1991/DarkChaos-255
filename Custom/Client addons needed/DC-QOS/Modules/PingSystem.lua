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
            entityTrackRefreshSec = 0.10,
            entityUnitWorldZOffset = 2.25,
            entityGameObjectWorldZOffset = 1.25,
            entityObjectWorldZOffset = 1.75,
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
    relayStateRequestPending = false,
    relayStateRefreshQueued = false,
    relayStateQueuedReason = nil,
    relayStateRequestGeneration = 0,
    relayStateLastCompletedGeneration = 0,
    relayStateLastRequestAt = nil,
    relayStateLastRequestReason = nil,
    relayStateLastFailure = nil,
    relayStateLastResponseAt = nil,
    relayStateLastResponseSource = nil,
    serverRelayState = nil,
    settingsStatusUpdater = nil,
    settingsRefreshButton = nil,
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
    retailApiShimInstalled = false,
    securePingCallbacks = {},
    nextSecurePingFrameId = 1,
    securePingBridgeInstalled = false,
    pingListenerEnabled = true,
    recentRemotePings = {},
    recentLocalRelaySequences = {},
}

local NATIVE_PING_RELAY_CAPABILITY = 0x00008000
local NATIVE_PING_RELAY_POLL_INTERVAL = 0.10
local lastNativePingRelayRevision = 0
local nativePingRelayPollFrame
local PING_STATE_FEATURE = "ping_state"

local HandleProtocolFeatureData
local RefreshSettingsStatusText
local RequestCurrentPingRelayState
local SchedulePingRelayStateRequest

local SECURE_PING_EVENT_RADIAL_CREATED = "radialCreated"
local SECURE_PING_EVENT_PENDING_OFFSCREEN = "pendingOffscreen"
local SECURE_PING_EVENT_TOGGLE_LISTENER = "toggleListener"
local SECURE_PING_EVENT_COOLDOWN_STARTED = "cooldownStarted"
local SECURE_PING_EVENT_PIN_ADDED = "pinFrameAdded"
local SECURE_PING_EVENT_PIN_REMOVED = "pinFrameRemoved"
local SECURE_PING_EVENT_PIN_CLAMP_UPDATED = "pinFrameClampStateUpdated"
local SECURE_PING_EVENT_SEND_MACRO = "sendMacro"

local PING_SECURE_EXPECTED_METHODS = {
    "CreateFrame",
    "DisplayError",
    "ClearPendingPingInfo",
    "GetTargetWorldPing",
    "GetTargetWorldPingAndSend",
    "SendPing",
    "GetTargetPingReceiver",
    "SetPingRadialWheelCreatedCallback",
    "SetPendingPingOffScreenCallback",
    "SetTogglePingListenerCallback",
    "SetPingCooldownStartedCallback",
    "SetPingPinFrameAddedCallback",
    "SetPingPinFrameRemovedCallback",
    "SetPingPinFrameScreenClampStateUpdatedCallback",
    "SetSendMacroPingCallback",
    "GetCallbackState",
}

local mapUtils = addon:GetMapUtils()
local NormalizeCoord = mapUtils.NormalizeCoord
local SafeSetMapToCurrentZone = mapUtils.SafeSetMapToCurrentZone
local GetPlayerMapPositionSafe = mapUtils.GetPlayerMapPositionSafe
local ComputeDistanceYards = mapUtils.ComputeDistanceYards
local GetMapAreaYards = mapUtils.GetMapAreaYards

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

local function HasCapabilityBit(mask, capability)
    mask = tonumber(mask) or 0
    capability = tonumber(capability) or 0

    if capability <= 0 then
        return false
    end

    if bit and bit.band then
        return bit.band(mask, capability) ~= 0
    end

    return (mask % (capability * 2)) >= capability
end

local function GetClientCapabilityMask()
    local DC = rawget(_G, "DCAddonProtocol")
    if DC and type(DC.GetClientCapabilities) == "function" then
        local ok, capabilities = pcall(DC.GetClientCapabilities, DC)
        if ok then
            return tonumber(capabilities) or 0
        end
    end

    return 0
end

local function GetProtocolCapabilitySnapshot()
    local DC = rawget(_G, "DCAddonProtocol")
    if not DC or type(DC.GetCapabilitySnapshot) ~= "function" then
        return nil
    end

    local ok, snapshot = pcall(DC.GetCapabilitySnapshot, DC)
    if not ok or type(snapshot) ~= "table" then
        return nil
    end

    return snapshot
end

local function IsCapabilityNegotiated(capability)
    local snapshot = GetProtocolCapabilitySnapshot()
    if not snapshot or not snapshot.connected then
        return false
    end

    return HasCapabilityBit(tonumber(snapshot.negotiatedCaps) or 0,
        capability)
end

local function HasNativePingRelayBridge()
    if type(RequestNativePingRelay) ~= "function"
        or type(GetNativePingRelaySnapshot) ~= "function" then
        return false
    end

    local capabilities = GetClientCapabilityMask()
    if capabilities > 0 then
        return HasCapabilityBit(capabilities, NATIVE_PING_RELAY_CAPABILITY)
    end

    return true
end

local function ShouldUseNativePingRelayBridge()
    return HasNativePingRelayBridge()
        and IsCapabilityNegotiated(NATIVE_PING_RELAY_CAPABILITY)
end

local function DecodeNativePingRelayEnvelope(payload)
    if type(payload) == "table" then
        return payload
    end

    if type(payload) ~= "string" or payload == "" then
        return nil
    end

    local DC = rawget(_G, "DCAddonProtocol")
    if not DC or type(DC.DecodeJSON) ~= "function" then
        return nil
    end

    local ok, decoded = pcall(DC.DecodeJSON, DC, payload)
    if not ok or type(decoded) ~= "table" then
        return nil
    end

    return decoded
end

local function ConsumeNativePingRelaySnapshot()
    if not ShouldUseNativePingRelayBridge() then
        return false
    end

    local ok, revision, payload = pcall(GetNativePingRelaySnapshot)
    if not ok or revision == nil then
        return false
    end

    revision = tonumber(revision) or 0
    if revision <= 0 or revision == lastNativePingRelayRevision then
        return false
    end

    lastNativePingRelayRevision = revision

    local decoded = DecodeNativePingRelayEnvelope(payload)
    if type(decoded) ~= "table" then
        return false
    end

    HandleProtocolFeatureData(decoded)
    return true
end

local function EnsureNativePingRelayPollFrame()
    if nativePingRelayPollFrame then
        return
    end

    nativePingRelayPollFrame = CreateFrame("Frame")
    nativePingRelayPollFrame.elapsed = 0
    nativePingRelayPollFrame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed < NATIVE_PING_RELAY_POLL_INTERVAL then
            return
        end

        self.elapsed = 0
        ConsumeNativePingRelaySnapshot()
    end)
end

local RAID_ICON_TEXTURE = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local PING_ATLAS_TEXTURE_SHEET = "Interface\\AddOns\\DC-QOS\\Textures\\PingSystem\\Blizzard\\RadialWheel\\uipingsystem.blp"

local function BuildRaidIconAtlas(iconIndex)
    iconIndex = tonumber(iconIndex) or 1
    if iconIndex < 1 then
        iconIndex = 1
    elseif iconIndex > 8 then
        iconIndex = 8
    end

    local col = (iconIndex - 1) % 4
    local row = math_floor((iconIndex - 1) / 4)
    local left = col * 0.25
    local right = left + 0.25
    local top = row * 0.25
    local bottom = top + 0.25

    return {
        texture = RAID_ICON_TEXTURE,
        left = left,
        right = right,
        top = top,
        bottom = bottom,
    }
end

local function PingAtlas(l, r, t, b)
    return {
        texture = PING_ATLAS_TEXTURE_SHEET,
        left = l,
        right = r,
        top = t,
        bottom = b,
    }
end

local PING_ATLASES = {
    ["Ping_Marker_Icon_Assist"] = PingAtlas(0.668945, 0.703125, 0.446289, 0.480469),
    ["Ping_Marker_Icon_Attack"] = PingAtlas(0.744141, 0.778320, 0.446289, 0.480469),
    ["Ping_Marker_Icon_NonThreat"] = PingAtlas(0.289062, 0.323242, 0.867188, 0.901367),
    ["Ping_Marker_Icon_OnMyWay"] = PingAtlas(0.325195, 0.359375, 0.903320, 0.937500),
    ["Ping_Marker_Icon_Threat"] = PingAtlas(0.325195, 0.359375, 0.939453, 0.973633),
    ["Ping_Marker_Icon_Warning"] = PingAtlas(0.363281, 0.397461, 0.752930, 0.787109),
    ["Ping_Marker_FlipBook_Assist"] = PingAtlas(0.000977, 0.475586, 0.295898, 0.483398),
    ["Ping_Marker_FlipBook_Attack"] = PingAtlas(0.000977, 0.323242, 0.485352, 0.758789),
    ["Ping_Marker_FlipBook_NonThreat"] = PingAtlas(0.000977, 0.381836, 0.000977, 0.293945),
    ["Ping_Marker_FlipBook_OnMyWay"] = PingAtlas(0.325195, 0.618164, 0.485352, 0.750977),
    ["Ping_Marker_FlipBook_Threat"] = PingAtlas(0.383789, 0.764648, 0.000977, 0.293945),
    ["Ping_Marker_FlipBook_Warning"] = PingAtlas(0.620117, 0.807617, 0.485352, 0.799805),
    ["Ping_GroundMarker_BG_Assist"] = PingAtlas(0.766602, 0.823242, 0.229492, 0.286133),
    ["Ping_GroundMarker_BG_Attack"] = PingAtlas(0.842773, 0.899414, 0.229492, 0.286133),
    ["Ping_GroundMarker_BG_NonThreat"] = PingAtlas(0.918945, 0.975586, 0.229492, 0.286133),
    ["Ping_GroundMarker_BG_OnMyWay"] = PingAtlas(0.780273, 0.836914, 0.371094, 0.427734),
    ["Ping_GroundMarker_BG_Threat"] = PingAtlas(0.059570, 0.116211, 0.936523, 0.993164),
    ["Ping_GroundMarker_BG_Warning"] = PingAtlas(0.855469, 0.912109, 0.295898, 0.352539),
    ["Ping_GroundMarker_Pin_Assist"] = PingAtlas(0.399414, 0.403320, 0.752930, 0.864258),
    ["Ping_GroundMarker_Pin_Attack"] = PingAtlas(0.399414, 0.403320, 0.866211, 0.977539),
    ["Ping_GroundMarker_Pin_NonThreat"] = PingAtlas(0.405273, 0.409180, 0.752930, 0.864258),
    ["Ping_GroundMarker_Pin_OnMyWay"] = PingAtlas(0.405273, 0.409180, 0.866211, 0.977539),
    ["Ping_GroundMarker_Pin_Threat"] = PingAtlas(0.411133, 0.415039, 0.866211, 0.977539),
    ["Ping_GroundMarker_Pin_Warning"] = PingAtlas(0.411133, 0.415039, 0.752930, 0.864258),
    ["Ping_GroundMarker_Stroke_Assist"] = PingAtlas(0.914062, 0.970703, 0.295898, 0.352539),
    ["Ping_GroundMarker_Stroke_Attack"] = PingAtlas(0.855469, 0.912109, 0.354492, 0.411133),
    ["Ping_GroundMarker_Stroke_NonThreat"] = PingAtlas(0.855469, 0.912109, 0.413086, 0.469727),
    ["Ping_GroundMarker_Stroke_OnMyWay"] = PingAtlas(0.914062, 0.970703, 0.354492, 0.411133),
    ["Ping_GroundMarker_Stroke_Threat"] = PingAtlas(0.118164, 0.174805, 0.760742, 0.817383),
    ["Ping_GroundMarker_Stroke_Warning"] = PingAtlas(0.914062, 0.970703, 0.413086, 0.469727),
    ["Ping_OVMarker_Pointer_Assist"] = PingAtlas(0.553711, 0.626953, 0.372070, 0.445312),
    ["Ping_OVMarker_Pointer_Attack"] = PingAtlas(0.629883, 0.703125, 0.295898, 0.369141),
    ["Ping_OVMarker_Pointer_NonThreat"] = PingAtlas(0.629883, 0.703125, 0.371094, 0.444336),
    ["Ping_OVMarker_Pointer_OnMyWay"] = PingAtlas(0.705078, 0.778320, 0.295898, 0.369141),
    ["Ping_OVMarker_Pointer_Threat"] = PingAtlas(0.705078, 0.778320, 0.371094, 0.444336),
    ["Ping_OVMarker_Pointer_Warning"] = PingAtlas(0.780273, 0.853516, 0.295898, 0.369141),
    ["Ping_OVMarker_Pointer_BG"] = PingAtlas(0.171875, 0.217773, 0.819336, 0.865234),
    ["Ping_SpotGlw_Assist_In"] = PingAtlas(0.553711, 0.589844, 0.447266, 0.483398),
    ["Ping_SpotGlw_Attack_In"] = PingAtlas(0.591797, 0.627930, 0.447266, 0.483398),
    ["Ping_SpotGlw_NonThreat_In"] = PingAtlas(0.250000, 0.286133, 0.906250, 0.942383),
    ["Ping_SpotGlw_OnMyWay_In"] = PingAtlas(0.250000, 0.286133, 0.944336, 0.980469),
    ["Ping_SpotGlw_Threat_In"] = PingAtlas(0.325195, 0.361328, 0.752930, 0.789062),
    ["Ping_SpotGlw_Warning_In"] = PingAtlas(0.325195, 0.361328, 0.791016, 0.827148),
    ["Ping_SpotGlw_Assist_Out"] = PingAtlas(0.780273, 0.832031, 0.429688, 0.481445),
    ["Ping_SpotGlw_Attack_Out"] = PingAtlas(0.176758, 0.228516, 0.760742, 0.812500),
    ["Ping_SpotGlw_NonThreat_Out"] = PingAtlas(0.230469, 0.282227, 0.760742, 0.812500),
    ["Ping_SpotGlw_OnMyWay_Out"] = PingAtlas(0.118164, 0.169922, 0.819336, 0.871094),
    ["Ping_SpotGlw_Threat_Out"] = PingAtlas(0.118164, 0.169922, 0.873047, 0.924805),
    ["Ping_SpotGlw_Warning_Out"] = PingAtlas(0.118164, 0.169922, 0.926758, 0.978516),
    ["Ping_UnitMarker_BG_Assist"] = PingAtlas(0.000977, 0.057617, 0.819336, 0.875977),
    ["Ping_UnitMarker_BG_Attack"] = PingAtlas(0.000977, 0.057617, 0.877930, 0.934570),
    ["Ping_UnitMarker_BG_NonThreat"] = PingAtlas(0.000977, 0.057617, 0.936523, 0.993164),
    ["Ping_UnitMarker_BG_OnMyWay"] = PingAtlas(0.059570, 0.116211, 0.760742, 0.817383),
    ["Ping_UnitMarker_BG_Threat"] = PingAtlas(0.059570, 0.116211, 0.819336, 0.875977),
    ["Ping_UnitMarker_BG_Warning"] = PingAtlas(0.059570, 0.116211, 0.877930, 0.934570),
    ["Ping_Wheel_Icon_Assist"] = PingAtlas(0.766602, 0.840820, 0.000977, 0.075195),
    ["Ping_Wheel_Icon_Attack"] = PingAtlas(0.766602, 0.840820, 0.077148, 0.151367),
    ["Ping_Wheel_Icon_OnMyWay"] = PingAtlas(0.918945, 0.993164, 0.077148, 0.151367),
    ["Ping_Wheel_Icon_Warning"] = PingAtlas(0.477539, 0.551758, 0.295898, 0.370117),

    -- Backward-compatible aliases used elsewhere in this module.
    ["Ping_Marker_Icon_Danger"] = PingAtlas(0.325195, 0.359375, 0.939453, 0.973633),
    ["Ping_Marker_Icon_Info"] = PingAtlas(0.289062, 0.323242, 0.867188, 0.901367),
    ["Ping_Marker_Flipbook_Default"] = PingAtlas(0.000977, 0.381836, 0.000977, 0.293945),
    ["Ping_GroundMarker_BG_Default"] = PingAtlas(0.918945, 0.975586, 0.229492, 0.286133),
    ["Ping_GroundMarker_Pin_Default"] = PingAtlas(0.405273, 0.409180, 0.752930, 0.864258),
    ["Ping_GroundMarker_Stroke_Default"] = PingAtlas(0.855469, 0.912109, 0.413086, 0.469727),
    ["Ping_UnitMarker_BG_Default"] = PingAtlas(0.000977, 0.057617, 0.936523, 0.993164),
    ["Ping_OVMarker_Pointer_Default"] = PingAtlas(0.629883, 0.703125, 0.371094, 0.444336),
    ["Ping_SpotGlw_Default_In"] = PingAtlas(0.250000, 0.286133, 0.906250, 0.942383),
    ["Ping_SpotGlw_Default_Out"] = PingAtlas(0.230469, 0.282227, 0.760742, 0.812500),
    ["Ping_Wheel_Icon_Default"] = PingAtlas(0.477539, 0.551758, 0.295898, 0.370117),
    ["Ping_Wheel_Backdrop_Default"] = { texture = "Interface\\Buttons\\WHITE8x8" },
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
        iconAtlas = "Ping_Marker_Icon_Threat",
        sound = "RaidWarning",
    },
    info = {
        label = "Ping",
        r = 1.00,
        g = 1.00,
        b = 1.00,
        iconAtlas = "Ping_Marker_Icon_NonThreat",
        sound = "MapPing",
    },
}

local RADIAL_MENU_OPTIONS = {
    { type = "assist", angle = 90, label = "Assist" },
    { type = "danger", angle = 18, label = "Danger" },
    { type = "attack", angle = -54, label = "Attack" },
    { type = "warning", angle = -126, label = "Warning" },
    { type = "onmyway", angle = 162, label = "On My Way" },
}

local DEFAULT_PING_ORDER = {
    "assist",
    "danger",
    "attack",
    "warning",
    "onmyway",
    "info",
}

local PING_TEXTURE_KIT_BY_TYPE = {
    attack = "Attack",
    warning = "Warning",
    assist = "Assist",
    onmyway = "OnMyWay",
    danger = "Threat",
    info = "NonThreat",
}

local PING_TYPE_BY_SUBJECT_ENUM_KEY = {
    Assist = "assist",
    Attack = "attack",
    OnMyWay = "onmyway",
    Warning = "warning",
    Threat = "danger",
    NonThreat = "info",
}

local PING_TYPE_BY_SUBJECT_ENUM_VALUE = {
    [1] = "assist",
    [2] = "attack",
    [3] = "onmyway",
    [4] = "warning",
    [5] = "danger",
    [6] = "info",
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

local function IsLikelyInvalidGuid(guid)
    local value = TrimWhitespace(guid):upper()
    if value == "" then
        return true
    end

    if value == "0" or value == "0X0" then
        return true
    end

    if value == "0XFFFFFFFFFFFFFFFF" or value == "0XFFFFFFFFFFFFFFFE" then
        return true
    end

    if value:match("^0XF+$") then
        return true
    end

    return false
end

local function GetSettings()
    if addon and addon.settings and addon.settings.pingSystem then
        return addon.settings.pingSystem
    end

    return PingSystem.defaults.pingSystem
end

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

    addon.PingSystem:PushQuickPing(pingType or "warning", {
        allowScreenFallback = true,
    })
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
                allowScreenFallback = true,
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

local function GetUiParentCenter()
    if not UIParent then
        return nil, nil
    end

    local centerX, centerY = UIParent:GetCenter()
    if centerX and centerY then
        return centerX, centerY
    end

    local width = UIParent:GetWidth()
    local height = UIParent:GetHeight()
    if width and height and width > 0 and height > 0 then
        return width * 0.5, height * 0.5
    end

    return nil, nil
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

    local centerX, centerY = GetUiParentCenter()
    if not centerX or not centerY then
        return nil, nil
    end

    return cursorX - centerX, cursorY - centerY
end

local function ClampScreenOffsetsToViewport(offsetX, offsetY, margin)
    if type(offsetX) ~= "number" or type(offsetY) ~= "number" or not UIParent then
        return offsetX, offsetY
    end

    local width = UIParent:GetWidth()
    local height = UIParent:GetHeight()
    if type(width) ~= "number" or type(height) ~= "number" or width <= 0 or height <= 0 then
        return offsetX, offsetY
    end

    margin = tonumber(margin) or 48
    if margin < 0 then
        margin = 0
    end

    local maxX = (width * 0.5) - margin
    local maxY = (height * 0.5) - margin
    if maxX < 0 then
        maxX = 0
    end
    if maxY < 0 then
        maxY = 0
    end

    return Clamp(offsetX, -maxX, maxX), Clamp(offsetY, -maxY, maxY)
end

local function ComputeRelativeHeading(facing, playerX, playerY, targetX, targetY, dxYards, dyYards)
    local dx = dxYards
    local dy = dyYards

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

local NormalizePingType

local function GetPingTextureSuffix(pingType)
    local normalized = NormalizePingType(pingType)
    if normalized == "assist" then
        return "Assist"
    end
    if normalized == "attack" then
        return "Attack"
    end
    if normalized == "onmyway" then
        return "OnMyWay"
    end
    if normalized == "warning" then
        return "Warning"
    end
    if normalized == "danger" then
        return "Threat"
    end
    return "NonThreat"
end

local PIN_FLIP_BOOK_INFO = {
    ["Assist"] = { sizeX = 81, sizeY = 48, anchorX = -17.5, anchorY = 4 },
    ["Attack"] = { sizeX = 55, sizeY = 70, anchorX = -12.2, anchorY = -14 },
    ["OnMyWay"] = { sizeX = 50, sizeY = 68, anchorX = 0, anchorY = 10.5 },
    ["Warning"] = { sizeX = 32, sizeY = 80.5, anchorX = 0, anchorY = 1.5 },
    ["NonThreat"] = { sizeX = 65, sizeY = 75, anchorX = 0.3, anchorY = 0.9 },
    ["Threat"] = { sizeX = 65, sizeY = 75, anchorX = 0.5, anchorY = 0.9 },
}

local function GetPinFlipBookInfo(uiTextureKit)
    return PIN_FLIP_BOOK_INFO[uiTextureKit]
end

local function ResolveTypeAtlasName(prefix, pingType, fallbackName)
    local suffix = GetPingTextureSuffix(pingType)
    local candidate = prefix .. suffix
    if PING_ATLASES[candidate] then
        return candidate
    end
    return fallbackName
end

local function ResolveTypeAtlasNameWithVariant(prefix, pingType, variant, fallbackName)
    local suffix = GetPingTextureSuffix(pingType)
    local candidate = prefix .. suffix .. variant
    if PING_ATLASES[candidate] then
        return candidate
    end
    return fallbackName
end

NormalizePingType = function(value)
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

local function EnsurePingEnums()
    if type(_G.Enum) ~= "table" then
        _G.Enum = {}
    end

    if type(_G.Enum.PingSubjectType) ~= "table" then
        _G.Enum.PingSubjectType = {
            Assist = 1,
            Attack = 2,
            OnMyWay = 3,
            Warning = 4,
            Threat = 5,
            NonThreat = 6,
        }
    end

    if type(_G.Enum.PingMode) ~= "table" then
        _G.Enum.PingMode = {
            PressAndDrag = 0,
            KeyDown = 1,
        }
    end
end

local function ResolvePingTypeFromApiValue(value)
    if type(value) == "number" then
        local subjects = _G.Enum and _G.Enum.PingSubjectType
        if type(subjects) == "table" then
            for enumKey, enumValue in pairs(subjects) do
                if enumValue == value then
                    return NormalizePingType(PING_TYPE_BY_SUBJECT_ENUM_KEY[enumKey] or enumKey)
                end
            end
        end

        return NormalizePingType(PING_TYPE_BY_SUBJECT_ENUM_VALUE[value] or "info")
    end

    return NormalizePingType(value)
end

local function PingTypeToSubjectEnum(pingType)
    pingType = NormalizePingType(pingType)
    local subjects = _G.Enum and _G.Enum.PingSubjectType
    if type(subjects) ~= "table" then
        return pingType
    end

    if pingType == "assist" then
        return subjects.Assist
    end
    if pingType == "attack" then
        return subjects.Attack
    end
    if pingType == "onmyway" then
        return subjects.OnMyWay
    end
    if pingType == "warning" then
        return subjects.Warning
    end
    if pingType == "danger" then
        return subjects.Threat or subjects.Warning
    end
    if pingType == "info" then
        return subjects.NonThreat or subjects.Warning
    end

    return subjects.Warning
end

local function BuildDefaultPingOptions()
    EnsurePingEnums()

    local options = {}
    for index = 1, #DEFAULT_PING_ORDER do
        local pingType = DEFAULT_PING_ORDER[index]
        options[#options + 1] = {
            type = PingTypeToSubjectEnum(pingType),
            orderIndex = index,
            uiTextureKitID = PING_TEXTURE_KIT_BY_TYPE[pingType] or "NonThreat",
        }
    end

    return options
end

local function BuildPingCooldownInfo()
    local settings = GetSettings()
    local throttleMs = tonumber(settings.throttleMs) or 0
    if throttleMs <= 0 then
        return nil
    end

    local startTimeMs = math_floor(((tonumber(state.lastPingAt) or 0) * 1000) + 0.5)
    if startTimeMs <= 0 then
        return nil
    end

    local endTimeMs = startTimeMs + throttleMs
    local nowMs = math_floor(((GetTime() or 0) * 1000) + 0.5)
    if nowMs >= endTimeMs then
        return nil
    end

    return {
        startTimeMs = startTimeMs,
        endTimeMs = endTimeMs,
        durationMs = throttleMs,
        remainingMs = endTimeMs - nowMs,
    }
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
    normalized.cursorHitX = tonumber(payload.cursorHitX)
    normalized.cursorHitY = tonumber(payload.cursorHitY)
    normalized.sound = payload.sound

    if normalized.targetGuid == "" then
        normalized.targetGuid = nil
    end

    if normalized.targetType == "" then
        normalized.targetType = nil
    end

    return normalized
end

local function ResolvePingFn(primaryName, aliasName)
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

local function TranslateWorldPositionToCurrentMap(worldX, worldY, worldZ)
    local translateFn = ResolvePingFn(
        "TranslateWorldPositionToCurrentMap",
        "C_Ping_TranslateWorldPositionToCurrentMap"
    )
    if not translateFn then
        return nil, nil, nil
    end

    local ok, mapId, mapX, mapY = pcall(translateFn, worldX, worldY, worldZ)
    mapId = tonumber(mapId)
    mapX = NormalizeCoord(mapX)
    mapY = NormalizeCoord(mapY)
    if ok and mapId and mapId > 0 and mapX and mapY then
        return mapId, mapX, mapY
    end

    return nil, nil, nil
end

local function BuildResolvedPingTargetFromValues(guid, targetType, mapId, mapX, mapY, worldX, worldY, worldZ, targetName)
    local cleanedGuid = TrimWhitespace(guid)
    if IsLikelyInvalidGuid(cleanedGuid) then
        cleanedGuid = nil
    end

    local cleanedType = TrimWhitespace(targetType):lower()
    if cleanedType == "" then
        cleanedType = cleanedGuid and "object" or "ground"
    end

    local cleanedName = TrimWhitespace(targetName)
    if cleanedName == "" then
        cleanedName = nil
    end

    local resolved = {
        targetGuid = cleanedGuid,
        targetType = cleanedType,
        targetName = cleanedName,
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

local function ResolveWorldScreenOffsets(worldX, worldY, worldZ, worldZOffset)
    worldX = tonumber(worldX)
    worldY = tonumber(worldY)
    worldZ = tonumber(worldZ)
    if not worldX or not worldY or not worldZ then
        return nil, nil
    end

    worldZ = worldZ + (tonumber(worldZOffset) or 0)

    local convertFn = ResolvePingFn("ConvertCoordsToScreenSpace", "C_Ping_ConvertCoordsToScreenSpace")
    if not convertFn then
        return nil, nil
    end

    local ok, screenX, screenY = pcall(convertFn, worldX, worldY, worldZ)
    if not ok or type(screenX) ~= "number" or type(screenY) ~= "number" then
        return nil, nil
    end

    if UIParent then
        local scale = UIParent:GetEffectiveScale()
        if scale and scale ~= 0 then
            screenX = screenX / scale
            screenY = screenY / scale
        end
    end

    local centerX, centerY = GetUiParentCenter()
    if not centerX or not centerY then
        return nil, nil
    end

    return screenX - centerX, screenY - centerY
end

local function GetEntityWorldZOffset(payload, settings)
    local targetType = TrimWhitespace(payload and payload.targetType):lower()

    if targetType == "unit" then
        return tonumber(settings.entityUnitWorldZOffset) or 2.25
    end
    if targetType == "gameobject" then
        return tonumber(settings.entityGameObjectWorldZOffset) or 1.25
    end
    if targetType == "object" then
        return tonumber(settings.entityObjectWorldZOffset) or 1.75
    end

    return 0
end

local function IsValidPingEntityTargetType(targetType)
    local lowered = TrimWhitespace(targetType):lower()
    return lowered == "unit"
        or lowered == "object"
        or lowered == "gameobject"
end

-- Forward declaration so early helpers can call this before its body is defined.
local DebugQuickPing

-- Returns the cursor position as viewport-normalised [0,1] coordinates with (0,0) at the
-- top-left of the screen (Win32/D3D9 convention).  This is the format that
-- CGWorldFrame::HitTestPoint (sWorldFrameHitTestPoint) expects — it is the same format as
-- CSimpleTopView::mousePosition which is populated from WM_MOUSEMOVE pixel coords (y from top)
-- divided by the window dimensions.
--
-- GetCursorPosition() in WoW Lua delivers physical screen pixels with Y=0 at the BOTTOM of the
-- window.  We normalise and flip Y to match the D3D viewport convention.
local function GetViewportCursorCoords()
    if type(GetCursorPosition) ~= "function" or not UIParent then
        return nil, nil
    end

    local cx, cy = GetCursorPosition()
    if type(cx) ~= "number" or type(cy) ~= "number" then
        return nil, nil
    end

    local scale = UIParent:GetEffectiveScale()
    if type(scale) ~= "number" or scale <= 0 then
        return nil, nil
    end

    cx = cx / scale
    cy = cy / scale

    local sw = UIParent:GetWidth()
    local sh = UIParent:GetHeight()
    if type(sw) ~= "number" or type(sh) ~= "number" or sw <= 0 or sh <= 0 then
        return nil, nil
    end

    -- normX: [0,1] from left  (identical in WoW Lua and Win32 conventions)
    -- normY: [0,1] from TOP   (flip WoW's bottom-origin Y to D3D's top-origin)
    return cx / sw, (sh - cy) / sh
end

local function ResolveCursorWorldPingTarget(preNormX, preNormY)
    local resolver = ResolvePingFn("GetCursorWorldPingTarget", "C_Ping_GetCursorWorldTarget")
    if not resolver then
        resolver = ResolvePingFn(nil, "C_Ping_GetTargetWorldPing")
    end

    if not resolver then
        return nil
    end

    -- Pass viewport-normalised [0,1] cursor coordinates (x from left, y from top / D3D9
    -- convention) as optional args so the C++ side can retry the world hit-test with the
    -- explicit cursor position if the WorldFrame's internal simpleTop tracker is unavailable
    -- (happens on keybind pings when no mouse event has set simpleTop->mousePosition).
    local normX = tonumber(preNormX)
    local normY = tonumber(preNormY)
    if type(normX) ~= "number" or type(normY) ~= "number" then
        normX, normY = GetViewportCursorCoords()
    end

    DebugQuickPing(string.format(
        "cursor hit-test coords hitX=%s hitY=%s",
        normX and string.format("%.3f", normX) or "nil",
        normY and string.format("%.3f", normY) or "nil"
    ))

    local ok, guid, targetType, mapId, mapX, mapY, worldX, worldY, worldZ, targetName
    if normX and normY then
        ok, guid, targetType, mapId, mapX, mapY, worldX, worldY, worldZ, targetName = pcall(resolver, normX, normY)
    else
        ok, guid, targetType, mapId, mapX, mapY, worldX, worldY, worldZ, targetName = pcall(resolver)
    end

    if ok then
        local resolved = BuildResolvedPingTargetFromValues(guid, targetType, mapId, mapX, mapY, worldX, worldY, worldZ, targetName)
        if resolved then
            return resolved
        end
    end

    -- Extra fallback path: use last tracked mouse world position when direct resolver fails.
    local mouseWorldFn = rawget(_G, "GetMouseWorldPosition")
    if type(mouseWorldFn) == "function" then
        local okMouse, mx, my, mz
        if normX and normY then
            okMouse, mx, my, mz = pcall(mouseWorldFn, normX, normY)
        else
            okMouse, mx, my, mz = pcall(mouseWorldFn)
        end
        if okMouse and type(mx) == "number" and type(my) == "number" and type(mz) == "number" then
            local hasWorldValue = (math_abs(mx) + math_abs(my) + math_abs(mz)) > 0.001
            if hasWorldValue then
                local mapIdFallback, mapXFallback, mapYFallback = TranslateWorldPositionToCurrentMap(mx, my, mz)

                DebugQuickPing(string.format(
                    "cursor fallback: using GetMouseWorldPosition map=%s x=%s y=%s",
                    tostring(mapIdFallback or "nil"),
                    mapXFallback and string.format("%.4f", mapXFallback) or "nil",
                    mapYFallback and string.format("%.4f", mapYFallback) or "nil"
                ))
                return BuildResolvedPingTargetFromValues(nil, "ground", mapIdFallback, mapXFallback, mapYFallback, mx, my, mz, nil)
            end
        end
    end

    return nil
end

local function ResolveMouseoverPingTarget()
    local resolver = ResolvePingFn("GetMouseoverPingTarget", "C_Ping_GetMouseoverTarget")

    if not resolver then
        return nil
    end

    local ok, guid, targetType, mapId, mapX, mapY, worldX, worldY, worldZ, targetName = pcall(resolver)
    if not ok then
        return nil
    end

    local resolved = BuildResolvedPingTargetFromValues(guid, targetType, mapId, mapX, mapY, worldX, worldY, worldZ, targetName)
    if not resolved or not resolved.targetGuid then
        return nil
    end

    if resolved.targetType == "ground" then
        resolved.targetType = "object"
    end

    return resolved
end

local function ResolveTargetPingReceiver()
    local resolver = ResolvePingFn("GetTargetPingReceiver", "C_Ping_GetTargetPingReceiver")
    if not resolver then
        return nil
    end

    local ok, guid, targetType, mapId, mapX, mapY, worldX, worldY, worldZ, targetName = pcall(resolver)
    if not ok then
        return nil
    end

    local resolved = BuildResolvedPingTargetFromValues(guid, targetType, mapId, mapX, mapY, worldX, worldY, worldZ, targetName)
    if not resolved or not resolved.targetGuid then
        return nil
    end

    if resolved.targetType == "ground" then
        resolved.targetType = "object"
    end

    return resolved
end

local function ResolveEntityPositionByGuid(targetGuid)
    targetGuid = TrimWhitespace(targetGuid)
    if targetGuid == "" then
        return nil
    end

    local resolver = ResolvePingFn("ResolveEntityPositionByGUID", "C_Ping_ResolveEntityPositionByGUID")
    if not resolver then
        return nil
    end

    local ok, guid, targetType, mapId, mapX, mapY, worldX, worldY, worldZ, targetName = pcall(resolver, targetGuid)
    if not ok then
        return nil
    end

    local resolved = BuildResolvedPingTargetFromValues(guid, targetType, mapId, mapX, mapY, worldX, worldY, worldZ, targetName)
    if not resolved then
        return nil
    end

    if not resolved.targetGuid then
        resolved.targetGuid = targetGuid
    end

    if resolved.targetType == "ground" then
        resolved.targetType = "unit"
    end

    return resolved
end

local function HasTargetMapCoordinates(target)
    if type(target) ~= "table" then
        return false
    end

    local mapId = tonumber(target.mapId)
    if not mapId or mapId <= 0 then
        return false
    end

    return target.x ~= nil and target.y ~= nil
end

local function HasTargetWorldCoordinates(target)
    if type(target) ~= "table" then
        return false
    end

    return target.worldX ~= nil
        and target.worldY ~= nil
        and target.worldZ ~= nil
end

local function FormatPingTargetDebug(target)
    if type(target) ~= "table" then
        return "nil"
    end

    local guid = TrimWhitespace(target.targetGuid)
    if guid == "" then
        guid = "nil"
    end

    local targetType = TrimWhitespace(target.targetType):lower()
    if targetType == "" then
        targetType = "nil"
    end

    local mapId = tonumber(target.mapId)
    local mapX = tonumber(target.x)
    local mapY = tonumber(target.y)
    local worldX = tonumber(target.worldX)
    local worldY = tonumber(target.worldY)
    local worldZ = tonumber(target.worldZ)

    return string.format(
        "type=%s guid=%s map=%s x=%s y=%s wx=%s wy=%s wz=%s",
        tostring(targetType),
        tostring(guid),
        tostring(mapId or "nil"),
        mapX and string.format("%.4f", mapX) or "nil",
        mapY and string.format("%.4f", mapY) or "nil",
        worldX and string.format("%.2f", worldX) or "nil",
        worldY and string.format("%.2f", worldY) or "nil",
        worldZ and string.format("%.2f", worldZ) or "nil"
    )
end

DebugQuickPing = function(message)
    if type(message) ~= "string" or message == "" then
        return
    end

    if not addon then
        return
    end

    local line = "Ping quick: " .. message
    local comm = addon.settings and addon.settings.communication

    if comm and comm.debugMode == true and type(addon.Debug) == "function" then
        addon:Debug(line)
        return
    end

    if type(addon.Print) == "function" then
        addon:Print("|cff888888[DC-QoS Debug]|r " .. line, true)
    end
end

local function CopyTargetIdentity(payload, target)
    if type(payload) ~= "table" or type(target) ~= "table" then
        return
    end

    local guid = TrimWhitespace(target.targetGuid)
    if guid ~= "" then
        payload.targetGuid = guid
    end

    local targetType = TrimWhitespace(target.targetType):lower()
    if targetType ~= "" then
        payload.targetType = targetType
    end

    if target.targetName and target.targetName ~= "" then
        payload.targetName = target.targetName
    end
end

local function CopyTargetLocation(payload, target)
    if type(payload) ~= "table" or type(target) ~= "table" then
        return
    end

    local mapId = tonumber(target.mapId)
    local mapX = NormalizeCoord(target.x)
    local mapY = NormalizeCoord(target.y)
    if mapId and mapId > 0 and mapX ~= nil and mapY ~= nil then
        payload.mapId = mapId
        payload.x = mapX
        payload.y = mapY
    end

    local worldX = tonumber(target.worldX)
    local worldY = tonumber(target.worldY)
    local worldZ = tonumber(target.worldZ)
    if worldX ~= nil and worldY ~= nil and worldZ ~= nil then
        payload.worldX = worldX
        payload.worldY = worldY
        payload.worldZ = worldZ
    end
end

local function ResolveUnitTokenFallbackTarget(unitToken)
    if type(unitToken) ~= "string" or type(UnitExists) ~= "function" or not UnitExists(unitToken) then
        return nil
    end

    local target = {
        targetType = "unit",
    }

    if type(UnitGUID) == "function" then
        local guid = TrimWhitespace(UnitGUID(unitToken))
        if guid ~= "" then
            target.targetGuid = guid
        end
    end

    if type(UnitName) == "function" then
        target.targetName = UnitName(unitToken)
    end

    if type(GetPlayerMapPosition) == "function" then
        local function ResolveTokenMapPosition()
            local ok, nx, ny = pcall(GetPlayerMapPosition, unitToken)
            if not ok then
                return nil, nil
            end

            nx = NormalizeCoord(nx)
            ny = NormalizeCoord(ny)
            if not nx or not ny then
                return nil, nil
            end

            if unitToken ~= "player" and nx == 0 and ny == 0 then
                return nil, nil
            end

            return nx, ny
        end

        local nx, ny = ResolveTokenMapPosition()
        if not nx and not ny and type(SafeSetMapToCurrentZone) == "function" then
            SafeSetMapToCurrentZone()
            nx, ny = ResolveTokenMapPosition()
        end

        if nx and ny then
            local mapId = (type(GetCurrentMapAreaID) == "function") and tonumber(GetCurrentMapAreaID()) or nil
            if (not mapId or mapId <= 0) and type(GetPlayerMapPositionSafe) == "function" then
                local _, _, playerMapId = GetPlayerMapPositionSafe()
                mapId = tonumber(playerMapId)
            end

            if mapId and mapId > 0 then
                target.mapId = mapId
                target.x = nx
                target.y = ny
            end
        end
    end

    if not target.targetGuid and not target.mapId then
        return nil
    end

    return target
end

local function ResolveAnyUnitTokenFallback()
    local mouseoverTarget = ResolveUnitTokenFallbackTarget("mouseover")
    if mouseoverTarget then
        return mouseoverTarget
    end

    local targetTarget = ResolveUnitTokenFallbackTarget("target")
    if targetTarget then
        return targetTarget
    end

    return ResolveUnitTokenFallbackTarget("focus")
end

local function NormalizeUnitNameForMatch(name)
    name = TrimWhitespace(name)
    if name == "" then
        return nil
    end

    name = name:gsub("%-.*$", "")
    name = name:lower()
    if name == "" then
        return nil
    end

    return name
end

local function AddUniqueUnitTokenCandidate(candidates, seen, token)
    token = TrimWhitespace(token)
    if token == "" or seen[token] then
        return
    end

    seen[token] = true
    candidates[#candidates + 1] = token
end

local function BuildStrictEntityRecoveryTokenList()
    local candidates = {}
    local seen = {}

    AddUniqueUnitTokenCandidate(candidates, seen, "mouseover")
    AddUniqueUnitTokenCandidate(candidates, seen, "target")
    AddUniqueUnitTokenCandidate(candidates, seen, "focus")
    AddUniqueUnitTokenCandidate(candidates, seen, "targettarget")
    AddUniqueUnitTokenCandidate(candidates, seen, "focustarget")
    AddUniqueUnitTokenCandidate(candidates, seen, "mouseovertarget")

    local partyCount = (type(GetNumPartyMembers) == "function") and (tonumber(GetNumPartyMembers()) or 0) or 0
    partyCount = math_max(0, math_min(4, partyCount))
    for i = 1, partyCount do
        AddUniqueUnitTokenCandidate(candidates, seen, "party" .. i)
        AddUniqueUnitTokenCandidate(candidates, seen, "party" .. i .. "target")
        AddUniqueUnitTokenCandidate(candidates, seen, "party" .. i .. "pet")
    end

    local raidCount = (type(GetNumRaidMembers) == "function") and (tonumber(GetNumRaidMembers()) or 0) or 0
    raidCount = math_max(0, math_min(40, raidCount))
    for i = 1, raidCount do
        AddUniqueUnitTokenCandidate(candidates, seen, "raid" .. i)
        AddUniqueUnitTokenCandidate(candidates, seen, "raid" .. i .. "target")
        AddUniqueUnitTokenCandidate(candidates, seen, "raid" .. i .. "pet")
    end

    return candidates
end

local function DoesUnitTokenMatchEntityIdentity(unitToken, targetGuid, targetNameNormalized)
    if type(unitToken) ~= "string" or type(UnitExists) ~= "function" or not UnitExists(unitToken) then
        return false, nil
    end

    if targetGuid and targetGuid ~= "" and type(UnitGUID) == "function" then
        local tokenGuid = TrimWhitespace(UnitGUID(unitToken))
        if tokenGuid ~= "" and tokenGuid == targetGuid then
            return true, "guid"
        end
    end

    if targetNameNormalized and type(UnitName) == "function" then
        local tokenName = NormalizeUnitNameForMatch(UnitName(unitToken))
        if tokenName and tokenName == targetNameNormalized then
            return true, "name"
        end
    end

    return false, nil
end

local function TryRecoverEntityTargetLocation(targetGuid, targetName)
    targetGuid = TrimWhitespace(targetGuid)
    if targetGuid == "" then
        targetGuid = nil
    end

    local targetNameNormalized = NormalizeUnitNameForMatch(targetName)
    if not targetGuid and not targetNameNormalized then
        return nil, nil, nil
    end

    if targetGuid then
        local recoveredByGuid = ResolveEntityPositionByGuid(targetGuid)
        if recoveredByGuid and (HasTargetMapCoordinates(recoveredByGuid) or HasTargetWorldCoordinates(recoveredByGuid)) then
            return recoveredByGuid, "guid-export", "guid"
        end
    end

    local candidates = BuildStrictEntityRecoveryTokenList()
    for i = 1, #candidates do
        local token = candidates[i]
        local matched, matchKind = DoesUnitTokenMatchEntityIdentity(token, targetGuid, targetNameNormalized)
        if matched then
            local recoveredTarget = ResolveUnitTokenFallbackTarget(token)
            if recoveredTarget and (HasTargetMapCoordinates(recoveredTarget) or HasTargetWorldCoordinates(recoveredTarget)) then
                return recoveredTarget, token, matchKind
            end
        end
    end

    return nil, nil, nil
end

local function ResolveContextualPingTypeForUnit(unitToken)
    if type(unitToken) == "string" and type(UnitExists) == "function" and UnitExists(unitToken) then
        if type(UnitIsUnit) == "function" and UnitIsUnit(unitToken, "player") then
            return "onmyway"
        end

        if type(UnitCanAttack) == "function" and UnitCanAttack("player", unitToken) then
            return "attack"
        end

        if type(UnitIsFriend) == "function" and UnitIsFriend("player", unitToken) then
            return "assist"
        end
    end

    return "warning"
end

local FindPingFrameBySecureId
local ApplyFramePinTargetStyle
local ApplyFrameClampVisual
local DispatchSecurePingEvent
local AllocateSecurePingFrameId

local function EnsureRetailPingApiShims()
    if not state.retailApiShimInstalled then
        state.retailApiShimInstalled = true
    end

    EnsurePingEnums()

    local pingApi = rawget(_G, "C_Ping")
    if type(pingApi) ~= "table" then
        pingApi = {}
        _G.C_Ping = pingApi
    end

    local mapApi = rawget(_G, "C_Map")
    if type(mapApi) ~= "table" then
        mapApi = {}
        _G.C_Map = mapApi
    end

    local function InstallPingPassthrough(methodName, globalName)
        if type(pingApi[methodName]) ~= "function" and type(_G[globalName]) == "function" then
            pingApi[methodName] = _G[globalName]
        end
    end

    InstallPingPassthrough("ConvertCoordsToScreenSpace", "ConvertCoordsToScreenSpace")
    InstallPingPassthrough("GetSyncDistribution", "GetPingSyncDistribution")
    InstallPingPassthrough("EncodeProtocolPayload", "EncodePingSyncProtocolPayload")
    InstallPingPassthrough("DecodeProtocolPayload", "DecodePingSyncProtocolPayload")
    InstallPingPassthrough("EncodeSyncPayload", "EncodePingSyncPayload")
    InstallPingPassthrough("DecodeSyncPayload", "DecodePingSyncPayload")
    InstallPingPassthrough("GetCursorWorldTarget", "GetCursorWorldPingTarget")
    InstallPingPassthrough("GetMouseoverTarget", "GetMouseoverPingTarget")
    InstallPingPassthrough("GetTargetPingReceiver", "GetTargetPingReceiver")
    InstallPingPassthrough("ResolveEntityPositionByGUID", "ResolveEntityPositionByGUID")

    InstallPingPassthrough("GetSyncDistribution", "C_Ping_GetSyncDistribution")
    InstallPingPassthrough("EncodeProtocolPayload", "C_Ping_EncodeProtocolPayload")
    InstallPingPassthrough("DecodeProtocolPayload", "C_Ping_DecodeProtocolPayload")
    InstallPingPassthrough("EncodeSyncPayload", "C_Ping_EncodeSyncPayload")
    InstallPingPassthrough("DecodeSyncPayload", "C_Ping_DecodeSyncPayload")
    InstallPingPassthrough("ConvertCoordsToScreenSpace", "C_Ping_ConvertCoordsToScreenSpace")
    InstallPingPassthrough("GetCursorWorldTarget", "C_Ping_GetCursorWorldTarget")
    InstallPingPassthrough("GetCursorWorldTarget", "C_Ping_GetTargetWorldPing")
    InstallPingPassthrough("GetMouseoverTarget", "C_Ping_GetMouseoverTarget")
    InstallPingPassthrough("GetTargetPingReceiver", "C_Ping_GetTargetPingReceiver")
    InstallPingPassthrough("ResolveEntityPositionByGUID", "C_Ping_ResolveEntityPositionByGUID")

    if type(mapApi.TranslateToMapCoords) ~= "function" and type(_G.TranslateToMapCoords) == "function" then
        mapApi.TranslateToMapCoords = _G.TranslateToMapCoords
    end

    if type(mapApi.TranslateToMapCoords) ~= "function" and type(_G.C_Map_TranslateToMapCoords) == "function" then
        mapApi.TranslateToMapCoords = _G.C_Map_TranslateToMapCoords
    end

    if type(pingApi.GetTextureKitForType) ~= "function" then
        pingApi.GetTextureKitForType = function(pingType)
            local normalized = ResolvePingTypeFromApiValue(pingType)
            return PING_TEXTURE_KIT_BY_TYPE[normalized] or "NonThreat"
        end
    end

    if type(pingApi.GetDefaultPingOptions) ~= "function" then
        pingApi.GetDefaultPingOptions = function()
            return BuildDefaultPingOptions()
        end
    end

    if type(pingApi.GetCooldownInfo) ~= "function" then
        pingApi.GetCooldownInfo = function()
            return BuildPingCooldownInfo()
        end
    end

    if type(pingApi.GetContextualPingTypeForUnit) ~= "function" then
        pingApi.GetContextualPingTypeForUnit = function(unitToken)
            return PingTypeToSubjectEnum(ResolveContextualPingTypeForUnit(unitToken))
        end
    end

    if type(pingApi.TogglePingListener) ~= "function" then
        pingApi.TogglePingListener = function(enabled)
            state.pingListenerEnabled = (enabled == true)
            DispatchSecurePingEvent(SECURE_PING_EVENT_TOGGLE_LISTENER, state.pingListenerEnabled)
            return state.pingListenerEnabled
        end
    end

    if type(pingApi.SendMacroPing) ~= "function" then
        pingApi.SendMacroPing = function(pingType, targetUnitToken)
            local resolvedType = ResolvePingTypeFromApiValue(pingType)
            DispatchSecurePingEvent(SECURE_PING_EVENT_SEND_MACRO, resolvedType, targetUnitToken)
            if type(targetUnitToken) == "string" and type(UnitExists) == "function" and UnitExists(targetUnitToken) then
                local payload = {
                    type = resolvedType,
                    targetType = "unit",
                    ignoreThrottle = false,
                }

                if type(UnitGUID) == "function" then
                    payload.targetGuid = TrimWhitespace(UnitGUID(targetUnitToken))
                    if payload.targetGuid == "" then
                        payload.targetGuid = nil
                    end
                end

                if type(UnitName) == "function" then
                    payload.targetName = UnitName(targetUnitToken)
                    payload.text = payload.targetName
                end

                return PingSystem:Push(payload)
            end

            if resolvedType == "info" then
                resolvedType = ResolveContextualPingTypeForUnit("target")
            end

            return PingSystem:PushQuickPing(resolvedType, {
                ignoreThrottle = false,
                allowScreenFallback = true,
            })
        end
    end

    if type(_G.GetPingMode) ~= "function" then
        _G.GetPingMode = function()
            local pingMode = (type(GetCVar) == "function") and tonumber(GetCVar("pingMode")) or nil
            if pingMode ~= nil then
                return pingMode
            end

            local enumMode = _G.Enum and _G.Enum.PingMode
            if type(enumMode) == "table" then
                return enumMode.KeyDown or enumMode.PressAndDrag or 1
            end

            return 1
        end
    end

    if type(_G.IsPingModeAvailable) ~= "function" then
        _G.IsPingModeAvailable = function()
            return true
        end
    end

    if type(_G.IsPingingMinimap) ~= "function" then
        _G.IsPingingMinimap = function()
            return false
        end
    end

    if type(_G.IsPingingWorld) ~= "function" then
        _G.IsPingingWorld = function()
            local settings = GetSettings()
            return settings.enabled ~= false
        end
    end

    local function BuildCurrentPingTargetSnapshot()
        local target = ResolveCursorWorldPingTarget() or ResolveMouseoverPingTarget()
        if type(target) ~= "table" then
            return nil
        end

        return {
            targetGuid = target.targetGuid,
            targetType = target.targetType,
            mapId = target.mapId,
            x = target.x,
            y = target.y,
            worldX = target.worldX,
            worldY = target.worldY,
            worldZ = target.worldZ,
        }
    end

    if type(_G.GetPingType) ~= "function" then
        _G.GetPingType = function(value)
            return ResolvePingTypeFromApiValue(value)
        end
    end

    if type(_G.GetPingSubjectType) ~= "function" then
        _G.GetPingSubjectType = function(value)
            return PingTypeToSubjectEnum(ResolvePingTypeFromApiValue(value))
        end
    end

    if type(_G.GetPingTarget) ~= "function" then
        _G.GetPingTarget = function()
            local target = BuildCurrentPingTargetSnapshot()
            if not target then
                return nil
            end

            return target.targetGuid, target.targetType, target.mapId, target.x, target.y, target.worldX, target.worldY, target.worldZ, target
        end
    end

    if type(_G.GetPingInfo) ~= "function" then
        _G.GetPingInfo = function()
            return {
                mode = _G.GetPingMode and _G.GetPingMode() or nil,
                cooldown = pingApi.GetCooldownInfo and pingApi.GetCooldownInfo() or nil,
                target = BuildCurrentPingTargetSnapshot(),
                listenerEnabled = (state.pingListenerEnabled == true),
            }
        end
    end

    if type(_G.GetPingCooldownInfo) ~= "function" then
        _G.GetPingCooldownInfo = function()
            return pingApi.GetCooldownInfo and pingApi.GetCooldownInfo() or nil
        end
    end

    if type(_G.GetPingTextures) ~= "function" then
        _G.GetPingTextures = function()
            local options = pingApi.GetDefaultPingOptions and pingApi.GetDefaultPingOptions() or {}
            local textures = {}
            for i = 1, #options do
                local option = options[i]
                textures[i] = option and option.uiTextureKitID or "NonThreat"
            end
            return textures
        end
    end

    if type(_G.GetPingCategories) ~= "function" then
        _G.GetPingCategories = function()
            return {
                {
                    categoryID = 1,
                    title = "Default",
                },
            }
        end
    end

    if type(_G.GetPingCategoryInfo) ~= "function" then
        _G.GetPingCategoryInfo = function(categoryId)
            categoryId = tonumber(categoryId) or 1
            return {
                categoryID = categoryId,
                title = "Default",
                options = pingApi.GetDefaultPingOptions and pingApi.GetDefaultPingOptions() or {},
            }
        end
    end

    if type(_G.TriggerPing) ~= "function" then
        _G.TriggerPing = function(pingType, targetUnitToken)
            if pingApi.SendMacroPing then
                return pingApi.SendMacroPing(pingType, targetUnitToken)
            end
            return PingSystem:PushQuickPing(ResolvePingTypeFromApiValue(pingType), {
                ignoreThrottle = false,
                allowScreenFallback = true,
            })
        end
    end

    if type(_G.RemovePings) ~= "function" then
        _G.RemovePings = function()
            PingSystem:Clear()
            return true
        end
    end

    local pingSecureApi = rawget(_G, "C_PingSecure")
    if type(pingSecureApi) ~= "table" then
        pingSecureApi = {}
        _G.C_PingSecure = pingSecureApi
    end

    local function InstallSecurePassthrough(methodName, globalName)
        if type(pingSecureApi[methodName]) ~= "function" and type(_G[globalName]) == "function" then
            pingSecureApi[methodName] = _G[globalName]
        end
    end

    InstallSecurePassthrough("CreateFrame", "C_PingSecure_CreateFrame")
    InstallSecurePassthrough("DisplayError", "C_PingSecure_DisplayError")
    InstallSecurePassthrough("ClearPendingPingInfo", "C_PingSecure_ClearPendingPingInfo")
    InstallSecurePassthrough("GetTargetPingReceiver", "C_PingSecure_GetTargetPingReceiver")

    local function BindSecureCallback(methodName, globalName, eventName)
        if type(pingSecureApi[methodName]) ~= "function" then
            pingSecureApi[methodName] = function(callback)
                if type(callback) == "function" then
                    state.securePingCallbacks[eventName] = callback
                else
                    state.securePingCallbacks[eventName] = nil
                end

                if type(_G[globalName]) == "function" then
                    return _G[globalName](callback)
                end

                return true
            end
        end
    end

    BindSecureCallback("SetPingRadialWheelCreatedCallback", "C_PingSecure_SetPingRadialWheelCreatedCallback", SECURE_PING_EVENT_RADIAL_CREATED)
    BindSecureCallback("SetPendingPingOffScreenCallback", "C_PingSecure_SetPendingPingOffScreenCallback", SECURE_PING_EVENT_PENDING_OFFSCREEN)
    BindSecureCallback("SetTogglePingListenerCallback", "C_PingSecure_SetTogglePingListenerCallback", SECURE_PING_EVENT_TOGGLE_LISTENER)
    BindSecureCallback("SetPingCooldownStartedCallback", "C_PingSecure_SetPingCooldownStartedCallback", SECURE_PING_EVENT_COOLDOWN_STARTED)
    BindSecureCallback("SetPingPinFrameAddedCallback", "C_PingSecure_SetPingPinFrameAddedCallback", SECURE_PING_EVENT_PIN_ADDED)
    BindSecureCallback("SetPingPinFrameRemovedCallback", "C_PingSecure_SetPingPinFrameRemovedCallback", SECURE_PING_EVENT_PIN_REMOVED)
    BindSecureCallback("SetPingPinFrameScreenClampStateUpdatedCallback", "C_PingSecure_SetPingPinFrameScreenClampStateUpdatedCallback", SECURE_PING_EVENT_PIN_CLAMP_UPDATED)
    BindSecureCallback("SetSendMacroPingCallback", "C_PingSecure_SetSendMacroPingCallback", SECURE_PING_EVENT_SEND_MACRO)

    if type(pingSecureApi.CreateFrame) ~= "function" then
        pingSecureApi.CreateFrame = function()
            return true
        end
    end

    if type(pingSecureApi.DisplayError) ~= "function" then
        pingSecureApi.DisplayError = function(message)
            if type(UIErrorsFrame) == "table" and type(UIErrorsFrame.AddMessage) == "function" then
                UIErrorsFrame:AddMessage(tostring(message or "PING_FAILED_GENERIC"), 1, 0.1, 0.1)
            elseif type(addon.Print) == "function" then
                addon:Print(tostring(message or "PING_FAILED_GENERIC"), true)
            end
            return true
        end
    end

    if type(pingSecureApi.ClearPendingPingInfo) ~= "function" then
        pingSecureApi.ClearPendingPingInfo = function()
            return true
        end
    end

    if type(pingSecureApi.GetTargetWorldPing) ~= "function" then
        pingSecureApi.GetTargetWorldPing = function(...)
            local native = rawget(_G, "C_PingSecure_GetTargetWorldPing")
            if type(native) == "function" then
                local ok, found, guid, targetType, mapId, mapX, mapY, worldX, worldY, worldZ, targetName = pcall(native, ...)
                if ok then
                    if found == true then
                        return true, guid, targetType, mapId, mapX, mapY, worldX, worldY, worldZ, targetName
                    end

                    if type(found) == "string" or type(found) == "number" then
                        return true, found, guid, targetType, mapId, mapX, mapY, worldX, worldY, worldZ
                    end
                end
            end

            local target = ResolveCursorWorldPingTarget()
            if not target then
                return false
            end

            return true,
                target.targetGuid,
                target.targetType,
                target.mapId,
                target.x,
                target.y,
                target.worldX,
                target.worldY,
                target.worldZ,
                target.targetName
        end
    end

    if type(pingSecureApi.GetTargetPingReceiver) ~= "function" then
        pingSecureApi.GetTargetPingReceiver = function()
            local target = ResolveTargetPingReceiver()
            if not target then
                return nil
            end

            return target.targetGuid,
                target.targetType,
                target.mapId,
                target.x,
                target.y,
                target.worldX,
                target.worldY,
                target.worldZ,
                target.targetName
        end
    end

    if type(pingSecureApi.SendPing) ~= "function" then
        pingSecureApi.SendPing = function(pingType, overrideTargetGUID)
            local native = rawget(_G, "C_PingSecure_SendPing")
            if type(native) == "function" then
                local ok, result = pcall(native, pingType, overrideTargetGUID)
                if ok and type(result) == "number" then
                    return result
                end
            end

            local resolvedType = ResolvePingTypeFromApiValue(pingType)
            local payload = {
                type = resolvedType,
                ignoreThrottle = false,
            }

            local targetGuid = TrimWhitespace(overrideTargetGUID)
            if targetGuid ~= "" then
                payload.targetGuid = targetGuid
                local resolved = ResolveEntityPositionByGuid(targetGuid)
                if resolved then
                    CopyTargetIdentity(payload, resolved)
                    CopyTargetLocation(payload, resolved)
                end
            else
                local target = ResolveCursorWorldPingTarget() or ResolveMouseoverPingTarget() or ResolveTargetPingReceiver()
                if target then
                    CopyTargetIdentity(payload, target)
                    CopyTargetLocation(payload, target)
                end
            end

            local ok = PingSystem:Push(payload)
            return ok and 0 or 1
        end
    end

    if type(pingSecureApi.GetTargetWorldPingAndSend) ~= "function" then
        pingSecureApi.GetTargetWorldPingAndSend = function()
            local native = rawget(_G, "C_PingSecure_GetTargetWorldPingAndSend")
            if type(native) == "function" then
                local ok, result = pcall(native)
                if ok then
                    if type(result) == "table" then
                        return result
                    end

                    return {
                        result = tonumber(result) or 1,
                    }
                end
            end

            local target = ResolveCursorWorldPingTarget()
            if not target then
                return {
                    result = 1,
                }
            end

            local ok = PingSystem:Push({
                type = "warning",
                ignoreThrottle = false,
                targetGuid = target.targetGuid,
                targetType = target.targetType,
                targetName = target.targetName,
                mapId = target.mapId,
                x = target.x,
                y = target.y,
                worldX = target.worldX,
                worldY = target.worldY,
                worldZ = target.worldZ,
            })

            return {
                result = ok and 0 or 1,
                targetGuid = target.targetGuid,
                targetType = target.targetType,
                mapId = target.mapId,
                x = target.x,
                y = target.y,
                worldX = target.worldX,
                worldY = target.worldY,
                worldZ = target.worldZ,
            }
        end
    end

    if type(pingSecureApi.GetCallbackState) ~= "function" and type(_G.C_PingSecure_GetCallbackState) == "function" then
        pingSecureApi.GetCallbackState = _G.C_PingSecure_GetCallbackState
    end

    if state.securePingBridgeInstalled ~= true then
        state.securePingBridgeInstalled = true

        if type(pingSecureApi.SetPingPinFrameAddedCallback) == "function" then
            pingSecureApi.SetPingPinFrameAddedCallback(function(frameId, uiTextureKit, isWorldPoint)
                local frame = FindPingFrameBySecureId(frameId)
                if not frame then
                    return
                end

                frame.__dcqosUiTextureKit = uiTextureKit
                ApplyFramePinTargetStyle(frame, isWorldPoint == true)

                -- WotLK client path does not have retail flipbook playback here.
                -- Showing the atlas directly can render several frames at once,
                -- so keep the static icon visible only.
                if frame.Icon then
                    frame.Icon:Show()
                end
                if frame.IconFlipbook then
                    frame.IconFlipbook:Hide()
                end
            end)
        end

        if type(pingSecureApi.SetPingPinFrameRemovedCallback) == "function" then
            pingSecureApi.SetPingPinFrameRemovedCallback(function(frameId)
                local frame = FindPingFrameBySecureId(frameId)
                if frame and frame.IconFlipbook then
                    frame.IconFlipbook:Hide()
                    if frame.Icon then
                        frame.Icon:Show()
                    end
                end
            end)
        end

        if type(pingSecureApi.SetPingPinFrameScreenClampStateUpdatedCallback) == "function" then
            pingSecureApi.SetPingPinFrameScreenClampStateUpdatedCallback(function(frameId, isClamped)
                local frame = FindPingFrameBySecureId(frameId)
                if not frame then
                    return
                end

                ApplyFrameClampVisual(frame, isClamped == true)
            end)
        end
    end
end

local function RunPingSecureRuntimeSelfTest()
    local secureApi = rawget(_G, "C_PingSecure")
    if type(secureApi) ~= "table" then
        addon:Debug("Ping Secure self-test: C_PingSecure table missing")
        return
    end

    local present = {}
    local missing = {}

    for i = 1, #PING_SECURE_EXPECTED_METHODS do
        local methodName = PING_SECURE_EXPECTED_METHODS[i]
        if type(secureApi[methodName]) == "function" then
            present[#present + 1] = methodName
        else
            missing[#missing + 1] = methodName
        end
    end

    addon:Debug(string.format(
        "Ping Secure self-test: %d/%d methods available",
        #present,
        #PING_SECURE_EXPECTED_METHODS
    ))

    if #missing > 0 then
        addon:Debug("Ping Secure self-test missing: " .. table.concat(missing, ", "))
    else
        addon:Debug("Ping Secure self-test all methods available")
    end
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

    if bestDiff and bestDiff <= 62 then
        return bestType
    end

    return nil
end

local function UpdateRadialMenuVisuals()
    if not state.menuEntries then
        return
    end

    local selectedStyle = state.menuSelectionType and PING_STYLES[state.menuSelectionType] or nil

    for i = 1, #state.menuEntries do
        local entry = state.menuEntries[i]
        local style = PING_STYLES[entry.pingType] or PING_STYLES.info
        local selected = (entry.pingType == state.menuSelectionType)

        if entry.Background then
            entry.Background:SetVertexColor(
                (style.r * 0.34) + 0.10,
                (style.g * 0.34) + 0.10,
                (style.b * 0.34) + 0.10,
                selected and 0.34 or 0.14
            )
        end

        if entry.Ring then
            entry.Ring:SetVertexColor(style.r, style.g, style.b, selected and 0.68 or 0.32)
        end

        if entry.Highlight then
            entry.Highlight:SetAlpha(1)
            entry.Highlight:SetVertexColor(style.r, style.g, style.b, selected and 0.24 or 0.0)
        end

        if entry.IconPlate then
            entry.IconPlate:SetVertexColor(
                (style.r * 0.14) + 0.08,
                (style.g * 0.14) + 0.08,
                (style.b * 0.14) + 0.08,
                selected and 0.34 or 0.18
            )
        end

        if entry.Icon then
            ApplyStyleIcon(entry.Icon, entry.pingType)
            if selected then
                entry.Icon:SetVertexColor(1.0, 1.0, 1.0, 1.0)
            else
                entry.Icon:SetVertexColor(style.r, style.g, style.b, 0.92)
            end
        end

        if entry.Label then
            if selected then
                entry.Label:SetTextColor(1.0, 1.0, 1.0)
            else
                entry.Label:SetTextColor(0.86, 0.89, 0.94)
            end
        end

        entry:SetScale(selected and 1.08 or 1.0)
    end

    if state.menuWheel and state.menuWheel.CenterRing then
        if selectedStyle then
            state.menuWheel.CenterRing:SetVertexColor(
                (selectedStyle.r * 0.48) + 0.30,
                (selectedStyle.g * 0.48) + 0.30,
                (selectedStyle.b * 0.48) + 0.30,
                0.72
            )
        else
            state.menuWheel.CenterRing:SetVertexColor(0.30, 0.34, 0.40, 0.66)
        end
    end

    if state.menuWheel and state.menuWheel.CancelIcon then
        state.menuWheel.CancelIcon:SetAlpha(state.menuSelectionType and 0.68 or 0.95)
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
    if not ApplyAtlasTexture(frame.Dim, "Ping_Wheel_Backdrop_Default") then
        frame.Dim:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    end
    frame.Dim:SetVertexColor(0, 0, 0, 0.04)

    local wheel = CreateFrame("Frame", nil, frame)
    wheel:SetSize(220, 220)
    wheel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

    wheel.Backing = wheel:CreateTexture(nil, "ARTWORK")
    wheel.Backing:SetAllPoints()
    if not ApplyAtlasTexture(wheel.Backing, "Ping_Wheel_Icon_Default") then
        wheel.Backing:SetTexture("Interface\\Minimap\\UI-Minimap-Ping-Expand")
    end
    wheel.Backing:SetVertexColor(0.18, 0.22, 0.28, 0.32)

    wheel.OuterRing = wheel:CreateTexture(nil, "OVERLAY")
    wheel.OuterRing:SetAllPoints()
    if not ApplyAtlasTexture(wheel.OuterRing, "Ping_SpotGlw_Default_Out") then
        wheel.OuterRing:SetTexture("Interface\\Minimap\\UI-Minimap-Ping-Rotate")
    end
    wheel.OuterRing:SetBlendMode("ADD")
    wheel.OuterRing:SetVertexColor(0.70, 0.76, 0.86, 0.24)

    wheel.InnerRing = wheel:CreateTexture(nil, "OVERLAY")
    wheel.InnerRing:SetSize(136, 136)
    wheel.InnerRing:SetPoint("CENTER", wheel, "CENTER", 0, 0)
    if not ApplyAtlasTexture(wheel.InnerRing, "Ping_SpotGlw_Default_In") then
        wheel.InnerRing:SetTexture("Interface\\Minimap\\UI-Minimap-Ping-Expand")
    end
    wheel.InnerRing:SetVertexColor(0.56, 0.64, 0.80, 0.16)

    wheel.CenterRing = wheel:CreateTexture(nil, "OVERLAY")
    wheel.CenterRing:SetSize(64, 64)
    wheel.CenterRing:SetPoint("CENTER", wheel, "CENTER", 0, 0)
    if not ApplyAtlasTexture(wheel.CenterRing, "Ping_Wheel_Icon_Default") then
        wheel.CenterRing:SetTexture("Interface\\Minimap\\UI-Minimap-Ping-Expand")
    end
    wheel.CenterRing:SetVertexColor(0.30, 0.34, 0.40, 0.66)

    wheel.CenterGlow = wheel:CreateTexture(nil, "OVERLAY")
    wheel.CenterGlow:SetSize(44, 44)
    wheel.CenterGlow:SetPoint("CENTER", wheel, "CENTER", 0, 0)
    if not ApplyAtlasTexture(wheel.CenterGlow, "Ping_SpotGlw_Default_In") then
        wheel.CenterGlow:SetTexture("Interface\\Minimap\\UI-Minimap-Ping-Expand")
    end
    wheel.CenterGlow:SetBlendMode("ADD")
    wheel.CenterGlow:SetVertexColor(0.86, 0.90, 0.96, 0.16)

    wheel.CancelIcon = wheel:CreateTexture(nil, "OVERLAY")
    wheel.CancelIcon:SetSize(16, 16)
    wheel.CancelIcon:SetPoint("CENTER", wheel, "CENTER", 0, 0)
    wheel.CancelIcon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    wheel.CancelIcon:SetVertexColor(0.95, 0.95, 0.95, 0.95)

    wheel.Instruction = wheel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    wheel.Instruction:SetPoint("TOP", wheel, "BOTTOM", 0, -8)
    wheel.Instruction:SetTextColor(0.82, 0.86, 0.92)
    wheel.Instruction:SetText("Move cursor to choose a ping. Release key to confirm.")

    local menuEntries = {}
    for i = 1, #RADIAL_MENU_OPTIONS do
        local option = RADIAL_MENU_OPTIONS[i]
        local entry = CreateFrame("Frame", nil, wheel)
        entry:SetSize(50, 50)
        entry:SetPoint("CENTER", wheel, "CENTER", 0, 0)
        entry.pingType = option.type
        entry.baseAngle = option.angle
        entry.baseRadiusScale = option.radiusScale or 0.42

        entry.Background = entry:CreateTexture(nil, "ARTWORK")
        entry.Background:SetAllPoints()
        if not ApplyAtlasTexture(entry.Background, "Ping_SpotGlw_Default_Out") then
            entry.Background:SetTexture("Interface\\Minimap\\UI-Minimap-Ping-Rotate")
        end
        entry.Background:SetBlendMode("ADD")

        entry.Ring = entry:CreateTexture(nil, "ARTWORK")
        entry.Ring:SetAllPoints()
        if not ApplyAtlasTexture(entry.Ring, "Ping_SpotGlw_Default_In") then
            entry.Ring:SetTexture("Interface\\Minimap\\UI-Minimap-Ping-Expand")
        end
        entry.Ring:SetBlendMode("ADD")

        entry.Highlight = entry:CreateTexture(nil, "OVERLAY")
        entry.Highlight:SetAllPoints()
        if not ApplyAtlasTexture(entry.Highlight, "Ping_SpotGlw_Default_In") then
            entry.Highlight:SetTexture("Interface\\Minimap\\UI-Minimap-Ping-Expand")
        end
        entry.Highlight:SetBlendMode("ADD")
        entry.Highlight:SetAlpha(1)

        entry.IconPlate = entry:CreateTexture(nil, "OVERLAY")
        entry.IconPlate:SetSize(30, 30)
        entry.IconPlate:SetPoint("CENTER", entry, "CENTER", 0, 0)
        if not ApplyAtlasTexture(entry.IconPlate, "Ping_SpotGlw_Default_In") then
            entry.IconPlate:SetTexture("Interface\\Minimap\\UI-Minimap-Ping-Expand")
        end
        entry.IconPlate:SetVertexColor(0.12, 0.14, 0.18, 0.20)

        entry.Icon = entry:CreateTexture(nil, "OVERLAY")
        entry.Icon:SetSize(22, 22)
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

    for i = 1, #state.menuEntries do
        local entry = state.menuEntries[i]
        local angle = math_rad(entry.baseAngle or 0)
        local radius = size * (entry.baseRadiusScale or 0.42)
        local offsetX = math_cos(angle) * radius
        local offsetY = math_sin(angle) * radius

        entry:ClearAllPoints()
        entry:SetPoint("CENTER", state.menuWheel, "CENTER", offsetX, offsetY)
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

    -- Capture the world target NOW, while the cursor is still over the terrain / WorldFrame.
    -- By the time CloseRadialMenu fires the cursor will be over the radial UI, so
    -- m_actionHitTest will be stale and ResolveCursorWorldPingTarget() would return the
    -- wrong position.  We store the resolved target and pass it through to PushQuickPing.
    local capturedHitX, capturedHitY = GetViewportCursorCoords()
    state.capturedRadialHitX = capturedHitX
    state.capturedRadialHitY = capturedHitY
    state.capturedRadialTarget = ResolveCursorWorldPingTarget(capturedHitX, capturedHitY)
    state.capturedRadialScreenX, state.capturedRadialScreenY = GetCursorScreenOffsets()

    state.menuSelectionType = nil
    UpdateRadialMenuVisuals()

    menu:SetScript("OnUpdate", function()
        UpdateRadialSelectionFromCursor()
    end)

    menu:Show()
    DispatchSecurePingEvent(SECURE_PING_EVENT_RADIAL_CREATED)
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
    frame:SetSize(200, 200)
    frame:Hide()

    frame.GroundPin = CreateFrame("Frame", nil, frame)
    frame.GroundPin:SetSize(200, 200)
    frame.GroundPin:SetPoint("CENTER")

    frame.Stem = frame.GroundPin:CreateTexture(nil, "BACKGROUND", nil, 1)
    frame.Stem:SetSize(4, 114)
    frame.Stem:SetPoint("BOTTOM", frame.GroundPin, "CENTER", 0, 0)

    frame.GroundBackground = frame.GroundPin:CreateTexture(nil, "BACKGROUND", nil, 2)
    frame.GroundBackground:SetSize(58, 58)
    frame.GroundBackground:SetPoint("BOTTOM", frame.Stem, "TOP", 0, -8)

    frame.GroundHighlight = frame.GroundPin:CreateTexture(nil, "BACKGROUND", nil, 3)
    frame.GroundHighlight:SetSize(58, 58)
    frame.GroundHighlight:SetPoint("BOTTOM", frame.Stem, "TOP", 0, -8)
    frame.GroundHighlight:SetAlpha(0)

    frame.GroundMarker = frame.GroundPin:CreateTexture(nil, "BACKGROUND", nil, 3)
    frame.GroundMarker:SetSize(58, 58)
    frame.GroundMarker:SetPoint("BOTTOM", frame.Stem, "TOP", 0, -8)
    frame.GroundMarker:SetAlpha(0)

    frame.Stroke = frame.GroundPin:CreateTexture(nil, "BACKGROUND", nil, 4)
    frame.Stroke:SetSize(58, 58)
    frame.Stroke:SetPoint("BOTTOM", frame.Stem, "TOP", 0, -8)
    frame.Stroke:SetAlpha(0)

    frame.UnitPin = CreateFrame("Frame", nil, frame)
    frame.UnitPin:SetSize(200, 200)
    frame.UnitPin:SetPoint("CENTER")
    frame.UnitBackground = frame.UnitPin:CreateTexture(nil, "BACKGROUND")
    frame.UnitBackground:SetSize(58, 58)
    frame.UnitBackground:SetPoint("BOTTOM", frame.UnitPin, "CENTER", 0, 0)

    frame.ClampedPin = CreateFrame("Frame", nil, frame)
    frame.ClampedPin:SetSize(200, 200)
    frame.ClampedPin:SetPoint("CENTER")
    frame.__dcqosIsWorldPoint = (isWorldPoint == true)
    frame.__dcqosUiTextureKit = uiTextureKit
    frame.ClampedPin:Hide()

    frame.PointerBG = frame.ClampedPin:CreateTexture(nil, "BACKGROUND")
    frame.PointerBG:SetSize(47, 47)
    frame.PointerBG:SetPoint("CENTER")
    if not ApplyAtlasTexture(frame.PointerBG, "Ping_OVMarker_Pointer_BG") then
        frame.PointerBG:SetTexture("Interface\\Minimap\\UI-Minimap-Ping-Rotate")
    end

    frame.Pointer = frame.ClampedPin:CreateTexture(nil, "OVERLAY")
    frame.Pointer:SetSize(75, 75)
    frame.Pointer:SetPoint("CENTER")

    frame.Icon = frame:CreateTexture(nil, "ARTWORK", nil, 1)
    frame.Icon:SetSize(35, 35)
    frame.Icon:SetPoint("CENTER", frame.GroundBackground, "CENTER", 0, 0)

    frame.IconFlipbook = frame:CreateTexture(nil, "ARTWORK", nil, 2)
    frame.IconFlipbook:Hide()

    frame.DistanceText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.DistanceText:SetPoint("BOTTOM", frame, "TOP", 0, -26)
    frame.DistanceText:SetText("")

    frame.CaptionText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.CaptionText:SetPoint("TOP", frame, "BOTTOM", 0, 28)
    frame.CaptionText:SetWidth(220)
    frame.CaptionText:SetJustifyH("CENTER")
    frame.CaptionText:SetText("")

    frame.Ring = frame.GroundBackground

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
    local frameId = AllocateSecurePingFrameId(frame)
    DispatchSecurePingEvent(SECURE_PING_EVENT_PIN_REMOVED, frameId)

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

    local screenX = nil
    local screenY = nil
    local relative = nil
    local distance = payload.distance
    local targetMapId = payload.mapId
    local mapMismatch = false
    local hasScreenOffset = type(payload.screenX) == "number" and type(payload.screenY) == "number"
    local isEntityTarget = IsValidPingEntityTargetType(payload.targetType)

    if hasScreenOffset and not (payload.x and payload.y) and not (payload.worldX and payload.worldY and payload.worldZ) then
        local clampedX, clampedY = ClampScreenOffsetsToViewport(payload.screenX, payload.screenY, 52)
        return clampedX, clampedY, distance, false, targetMapId
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

    -- Prefer world-space projection whenever world coordinates are available.
    -- This keeps ground pings anchored to the world instead of player-relative
    -- ring math when both map and world data are present.
    if payload.worldX and payload.worldY and payload.worldZ then
        local worldOffsetX, worldOffsetY = ResolveWorldScreenOffsets(
            payload.worldX,
            payload.worldY,
            payload.worldZ,
            isEntityTarget and GetEntityWorldZOffset(payload, settings) or 0
        )
        if worldOffsetX and worldOffsetY then
            return worldOffsetX, worldOffsetY, distance, mapMismatch, targetMapId
        end
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

    if not relative and hasScreenOffset then
        local clampedX, clampedY = ClampScreenOffsetsToViewport(payload.screenX, payload.screenY, 52)
        return clampedX, clampedY, distance, mapMismatch, targetMapId
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

    if type(screenX) == "number" and type(screenY) == "number" then
        return screenX, screenY, distance, mapMismatch, targetMapId
    end

    return nil, nil, distance, mapMismatch, targetMapId
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

DispatchSecurePingEvent = function(eventName, ...)
    local cb = state.securePingCallbacks and state.securePingCallbacks[eventName]
    if type(cb) ~= "function" then
        return
    end

    local ok, err = pcall(cb, ...)
    if not ok and type(addon.Debug) == "function" then
        addon:Debug("Ping secure callback error [" .. tostring(eventName) .. "]: " .. tostring(err))
    end
end

local function IsProjectedPointClamped(offsetX, offsetY, margin)
    if type(offsetX) ~= "number" or type(offsetY) ~= "number" or not UIParent then
        return false
    end

    local width = UIParent:GetWidth()
    local height = UIParent:GetHeight()
    if type(width) ~= "number" or type(height) ~= "number" or width <= 0 or height <= 0 then
        return false
    end

    margin = tonumber(margin) or 48
    if margin < 0 then
        margin = 0
    end

    local maxX = (width * 0.5) - margin
    local maxY = (height * 0.5) - margin
    if maxX < 0 then
        maxX = 0
    end
    if maxY < 0 then
        maxY = 0
    end

    return math_abs(offsetX) >= maxX or math_abs(offsetY) >= maxY
end

AllocateSecurePingFrameId = function(frame)
    if type(frame) ~= "table" then
        return nil
    end

    if frame.__dcqosSecurePingFrameId then
        return frame.__dcqosSecurePingFrameId
    end

    local nextId = tonumber(state.nextSecurePingFrameId) or 1
    frame.__dcqosSecurePingFrameId = nextId
    state.nextSecurePingFrameId = nextId + 1
    return frame.__dcqosSecurePingFrameId
end

local function UpdateSecureClampState(entry, isClamped)
    if type(entry) ~= "table" or type(entry.frame) ~= "table" then
        return
    end

    if entry.lastClampState == isClamped then
        return
    end

    entry.lastClampState = isClamped
    local frameId = AllocateSecurePingFrameId(entry.frame)
    DispatchSecurePingEvent(SECURE_PING_EVENT_PIN_CLAMP_UPDATED, frameId, isClamped and true or false)
end

FindPingFrameBySecureId = function(frameId)
    frameId = tonumber(frameId)
    if not frameId then
        return nil
    end

    for i = 1, #state.active do
        local entry = state.active[i]
        if entry and entry.frame and entry.frame.__dcqosSecurePingFrameId == frameId then
            return entry.frame
        end
    end

    for i = 1, #state.pool do
        local frame = state.pool[i]
        if frame and frame.__dcqosSecurePingFrameId == frameId then
            return frame
        end
    end

    return nil
end

ApplyFramePinTargetStyle = function(frame, isWorldPoint)
    if type(frame) ~= "table" then
        return
    end

    frame.__dcqosIsWorldPoint = (isWorldPoint == true)
    if frame.__dcqosIsWorldPoint then
        if frame.Icon and frame.GroundBackground then
            frame.Icon:ClearAllPoints()
            frame.Icon:SetPoint("CENTER", frame.GroundBackground, "CENTER", 0, 0)
        end
        if frame.GroundPin then
            frame.GroundPin:Show()
        end
        if frame.UnitPin then
            frame.UnitPin:Hide()
        end
    else
        if frame.Icon and frame.UnitBackground then
            frame.Icon:ClearAllPoints()
            frame.Icon:SetPoint("CENTER", frame.UnitBackground, "CENTER", 0, 3)
        end
        if frame.GroundPin then
            frame.GroundPin:Hide()
        end
        if frame.UnitPin then
            frame.UnitPin:Show()
        end
    end
end

ApplyFrameClampVisual = function(frame, isClamped)
    if type(frame) ~= "table" then
        return
    end

    if frame.ClampedPin then
        frame.ClampedPin:SetShown(isClamped == true)
    end

    if isClamped == true then
        if frame.GroundPin then
            frame.GroundPin:Hide()
        end
        if frame.UnitPin then
            frame.UnitPin:Hide()
        end
        if frame.Icon and frame.PointerBG then
            frame.Icon:ClearAllPoints()
            frame.Icon:SetPoint("CENTER", frame.PointerBG, "CENTER", 0, 0)
        end
    else
        ApplyFramePinTargetStyle(frame, frame.__dcqosIsWorldPoint == true)
    end
end
local function UpdateActivePings(_, elapsed)
    local now = GetTime() or 0
    local settings = GetSettings()
    local refreshSec = tonumber(settings.entityTrackRefreshSec) or 0.10
    if refreshSec < 0.03 then
        refreshSec = 0.03
    elseif refreshSec > 0.50 then
        refreshSec = 0.50
    end

    for i = #state.active, 1, -1 do
        local entry = state.active[i]
        entry.remaining = entry.remaining - elapsed

        if entry.remaining <= 0 then
            ReleasePingAtIndex(i)
        else
            if type(entry.projectionPayload) == "table" then
                local x, y, distance, mapMismatch, targetMapId = ResolveProjection(entry.projectionPayload)
                if type(x) == "number" and type(y) == "number" then
                    entry.frame:ClearAllPoints()
                    entry.frame:SetPoint("CENTER", EnsureRootFrame(), "CENTER", x, y)

                    local isClamped = IsProjectedPointClamped(x, y, 52)
                    UpdateSecureClampState(entry, isClamped)

                    if settings.showDistance and entry.frame.DistanceText then
                        if distance and distance > 0 then
                            entry.frame.DistanceText:SetText(string.format("%d yd", math_floor(distance + 0.5)))
                        elseif mapMismatch and targetMapId then
                            entry.frame.DistanceText:SetText("Map " .. tostring(targetMapId))
                        else
                            entry.frame.DistanceText:SetText("")
                        end
                    end
                end
            end

            if type(entry.targetGuid) == "string"
                and entry.targetGuid ~= ""
                and IsValidPingEntityTargetType(entry.targetType)
                and now >= (entry.nextTrackRefreshAt or 0) then
                local resolved = ResolveEntityPositionByGuid(entry.targetGuid)
                if resolved then
                    if not resolved.targetType or resolved.targetType == "ground" then
                        resolved.targetType = entry.targetType
                    end

                    local x, y, distance, mapMismatch, targetMapId = ResolveProjection(resolved)
                    if type(x) == "number" and type(y) == "number" then
                        entry.projectionPayload = {
                            mapId = resolved.mapId,
                            x = resolved.x,
                            y = resolved.y,
                            worldX = resolved.worldX,
                            worldY = resolved.worldY,
                            worldZ = resolved.worldZ,
                            screenX = resolved.screenX,
                            screenY = resolved.screenY,
                            relativeRadians = resolved.relativeRadians,
                            relativeDegrees = resolved.relativeDegrees,
                            bearingDegrees = resolved.bearingDegrees,
                            distance = distance,
                            targetType = resolved.targetType,
                        }

                        entry.frame:ClearAllPoints()
                        entry.frame:SetPoint("CENTER", EnsureRootFrame(), "CENTER", x, y)
                        local isClamped = IsProjectedPointClamped(x, y, 52)
                        UpdateSecureClampState(entry, isClamped)

                        if settings.showDistance and entry.frame.DistanceText then
                            if distance and distance > 0 then
                                entry.frame.DistanceText:SetText(string.format("%d yd", math_floor(distance + 0.5)))
                            elseif mapMismatch and targetMapId then
                                entry.frame.DistanceText:SetText("Map " .. tostring(targetMapId))
                            else
                                entry.frame.DistanceText:SetText("")
                            end
                        end
                    end
                end

                entry.nextTrackRefreshAt = now + refreshSec
            end

            local progress = entry.remaining / entry.duration
            entry.frame:SetScale(entry.baseScale)
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
    local distributionFn = ResolvePingFn("GetPingSyncDistribution", "C_Ping_GetSyncDistribution")
    if distributionFn then
        local ok, distribution = pcall(distributionFn)
        if ok then
            local resolved = NormalizeRelayDistribution(distribution)
            if resolved == "AUTO" then
                return nil
            end

            return resolved
        end
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

    if (not mapX or not mapY)
        and type(normalized.worldX) == "number"
        and type(normalized.worldY) == "number"
        and type(normalized.worldZ) == "number" then
        local translateFn = ResolvePingFn("TranslateToMapCoords", "C_Map_TranslateToMapCoords")
        local sourceMapId = mapId

        local function TryTranslateToMap(targetMapId)
            if not translateFn or not targetMapId or targetMapId <= 0 then
                return nil, nil
            end

            local ok, translatedX, translatedY = pcall(
                translateFn,
                targetMapId,
                normalized.worldX,
                normalized.worldY,
                normalized.worldZ
            )

            translatedX = NormalizeCoord(translatedX)
            translatedY = NormalizeCoord(translatedY)
            if ok and translatedX and translatedY then
                return translatedX, translatedY
            end

            return nil, nil
        end

        if not sourceMapId then
            local translatedMapId, translatedX, translatedY = TranslateWorldPositionToCurrentMap(
                normalized.worldX,
                normalized.worldY,
                normalized.worldZ
            )
            if translatedMapId and translatedX and translatedY then
                sourceMapId = translatedMapId
                mapId = translatedMapId
                mapX = translatedX
                mapY = translatedY
            end
        end

        if translateFn and sourceMapId and sourceMapId > 0 and (not mapX or not mapY) then
            local translatedX, translatedY = TryTranslateToMap(sourceMapId)
            if (not translatedX or not translatedY) and playerMapId and playerMapId ~= sourceMapId then
                local playerTranslatedX, playerTranslatedY = TryTranslateToMap(playerMapId)
                if playerTranslatedX and playerTranslatedY then
                    sourceMapId = playerMapId
                    translatedX = playerTranslatedX
                    translatedY = playerTranslatedY
                end
            end

            if translatedX and translatedY then
                mapId = sourceMapId
                mapX = translatedX
                mapY = translatedY
            end
        end
    end

    if mapId and mapX and mapY then
        return mapId, Clamp(mapX, 0, 1), Clamp(mapY, 0, 1)
    end

    if not mapId or not playerX or not playerY then
        return nil, nil, nil
    end

    if playerMapId and mapId and mapId ~= playerMapId then
        mapId = playerMapId
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
    local encodeProtocolFn = ResolvePingFn("EncodePingSyncProtocolPayload", "C_Ping_EncodeProtocolPayload")
    local encodeSyncFn = ResolvePingFn("EncodePingSyncPayload", "C_Ping_EncodeSyncPayload")
    if not encodeProtocolFn and not encodeSyncFn then
        return nil, "Ping payload encoder unavailable."
    end

    local distribution = ResolveRelayDistribution(normalized)
    if not distribution then
        return nil, "Not in party or raid."
    end

    local targetType = TrimWhitespace(normalized.targetType):lower()
    if targetType == "ground"
        and not (type(normalized.worldX) == "number" and type(normalized.worldY) == "number" and type(normalized.worldZ) == "number") then
        local cursorTarget = nil
        if type(normalized.cursorHitX) == "number" and type(normalized.cursorHitY) == "number" then
            cursorTarget = ResolveCursorWorldPingTarget(normalized.cursorHitX, normalized.cursorHitY)
        else
            cursorTarget = ResolveCursorWorldPingTarget()
        end
        if cursorTarget and HasTargetWorldCoordinates(cursorTarget) then
            normalized.worldX = cursorTarget.worldX
            normalized.worldY = cursorTarget.worldY
            normalized.worldZ = cursorTarget.worldZ

            if not HasTargetMapCoordinates(normalized) and HasTargetMapCoordinates(cursorTarget) then
                normalized.mapId = cursorTarget.mapId
                normalized.x = cursorTarget.x
                normalized.y = cursorTarget.y
            end
        end
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

    local ok
    local encodedPayload
    if encodeProtocolFn then
        ok, encodedPayload = pcall(
            encodeProtocolFn,
            normalized.type or "info",
            mapId,
            mapX,
            mapY,
            flags,
            sequence
        )

        if (not ok or type(encodedPayload) ~= "string" or encodedPayload == "") and distribution then
            ok, encodedPayload = pcall(
                encodeProtocolFn,
                normalized.type or "info",
                mapId,
                mapX,
                mapY,
                flags,
                sequence,
                distribution
            )
        end

        if (not ok or type(encodedPayload) ~= "string" or encodedPayload == "") and distribution then
            ok, encodedPayload = pcall(
                encodeProtocolFn,
                distribution,
                normalized.type or "info",
                mapId,
                mapX,
                mapY,
                flags,
                sequence
            )
        end
    else
        ok, encodedPayload = pcall(
            encodeSyncFn,
            normalized.type or "info",
            mapId,
            mapX,
            mapY,
            flags,
            sequence
        )
    end

    if not ok or type(encodedPayload) ~= "string" or encodedPayload == "" then
        return nil, "Failed to encode relay payload."
    end

    return {
        feature = "ping",
        action = "relay",
        distribution = distribution,
        sequence = sequence,
        type = normalized.type,
        mapId = mapId,
        x = mapX,
        y = mapY,
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

local function SendRelayRequestDirect(moduleId, opcode, request)
    local DC = rawget(_G, "DCAddonProtocol")
    if not DC then
        return false, "DCAddonProtocol unavailable."
    end

    if type(DC.EnsureConnected) == "function" then
        pcall(DC.EnsureConnected, DC)
    end

    if type(DC.SendJSON) == "function" then
        local ok, sent = pcall(DC.SendJSON, DC, moduleId, opcode, request)
        if ok and sent ~= false then
            return true
        end
    end

    if type(DC.SendJson) == "function" then
        local ok, sent = pcall(DC.SendJson, DC, moduleId, opcode, request)
        if ok and sent ~= false then
            return true
        end
    end

    if type(DC.Request) == "function" then
        local ok, sent = pcall(DC.Request, DC, moduleId, opcode, request)
        if ok and sent ~= false then
            return true
        end
    end

    return false, "DCAddonProtocol send failed."
end

local function GetRelayStateTimestamp()
    if type(GetTime) == "function" then
        return tonumber(GetTime()) or 0
    end

    return 0
end

local function NormalizeRelayStatePayload(rawPayload)
    if type(rawPayload) ~= "table" then
        return nil
    end

    local payload = rawPayload
    if type(rawPayload.data) == "table" then
        payload = {}
        for key, value in pairs(rawPayload.data) do
            payload[key] = value
        end

        if not payload.feature and rawPayload.feature then
            payload.feature = rawPayload.feature
        end
        if payload.action == nil and rawPayload.action ~= nil then
            payload.action = rawPayload.action
        end
        if payload.revision == nil and rawPayload.revision ~= nil then
            payload.revision = rawPayload.revision
        end
        if payload.context == nil and rawPayload.context ~= nil then
            payload.context = rawPayload.context
        end
        if payload.transport == nil and rawPayload.transport ~= nil then
            payload.transport = rawPayload.transport
        end
    end

    return payload
end

local function FormatRelayStateValue(value, fallback)
    if value == nil then
        return fallback or "unknown"
    end

    local text = tostring(value)
    if text == "" then
        return fallback or "unknown"
    end

    return text
end

local function BuildClientRelayDistributionLabel()
    local distribution = ResolveRelayDistribution({})
    if distribution == "PARTY" or distribution == "RAID" then
        return distribution
    end

    return "not in party/raid"
end

local function BuildServerRelayStateText()
    local snapshot = state.serverRelayState
    local clientDistribution = BuildClientRelayDistributionLabel()

    if type(snapshot) ~= "table" then
        return string.format(
            "|cffccccccRelay Snapshot: client=%s, server reply pending or not received yet.|r",
            clientDistribution)
    end

    local relayLane = snapshot.nativePingRelayTransport and "native"
        or "addon"
    local featureLane = snapshot.nativeEnvelopeTransport
        and "native envelope" or "addon fallback"
    local responseSummary

    if snapshot.canRelay then
        local recipientCount = tonumber(snapshot.recipientCount) or 0
        local recipientSuffix = recipientCount == 1 and "" or "s"
        local scopeText = snapshot.subGroupScoped and ", subgroup only" or ""

        responseSummary = string.format("%s (%d recipient%s%s)",
            FormatRelayStateValue(snapshot.resolvedDistribution,
                FormatRelayStateValue(snapshot.requestedDistribution, "AUTO")),
            math_floor(recipientCount), recipientSuffix, scopeText)
    else
        responseSummary = FormatRelayStateValue(snapshot.error, "unavailable")
    end

    return string.format(
        "Relay Snapshot: client=%s, server=%s, connected=%s, relay=%s, feature=%s",
        clientDistribution,
        responseSummary,
        FormatRelayStateValue(snapshot.connectedMemberCount, "0"),
        relayLane,
        featureLane)
end

local function BuildRelayRefreshText()
    local requestId = tostring(state.relayStateRequestGeneration or 0)
    local requestReason = FormatRelayStateValue(
        state.relayStateLastRequestReason, "client-request")

    if state.relayStateRequestPending then
        local pendingSuffix = state.relayStateRefreshQueued
            and ", queued refresh" or ""
        return string.format(
            "|cffffff00Refresh: pending|r (#%s reason=%s%s)",
            requestId,
            requestReason,
            pendingSuffix)
    end

    if state.relayStateLastFailure then
        return string.format(
            "|cffff5555Refresh: %s|r (reason=%s)",
            state.relayStateLastFailure,
            requestReason)
    end

    if state.relayStateLastResponseAt then
        local ageSeconds = GetRelayStateTimestamp()
            - (tonumber(state.relayStateLastResponseAt) or 0)
        if ageSeconds < 0 then
            ageSeconds = 0
        end

        return string.format(
            "|cff00ff00Refresh: updated|r (#%s %.1fs ago via %s, context=%s)",
            tostring(state.relayStateLastCompletedGeneration or requestId),
            ageSeconds,
            FormatRelayStateValue(state.relayStateLastResponseSource,
                "unknown"),
            FormatRelayStateValue(state.serverRelayState
                and state.serverRelayState.context, "feature-request"))
    end

    return "|cffccccccRefresh: no request sent yet.|r"
end

RefreshSettingsStatusText = function()
    if type(state.settingsStatusUpdater) == "function" then
        state.settingsStatusUpdater()
    end

    if state.settingsRefreshButton then
        if state.relayStateRequestPending then
            state.settingsRefreshButton:Disable()
        elseif type(state.settingsRefreshButton.Enable) == "function" then
            state.settingsRefreshButton:Enable()
        elseif type(state.settingsRefreshButton.SetEnabled) == "function" then
            state.settingsRefreshButton:SetEnabled(true)
        else
            state.settingsRefreshButton:Disable()
        end

        if state.relayStateRequestPending then
            state.settingsRefreshButton:SetText("Refreshing...")
        else
            state.settingsRefreshButton:SetText("Refresh Relay State")
        end
    end
end

local function HandlePingRelayStateResponse(rawPayload, source)
    local payload = NormalizeRelayStatePayload(rawPayload)
    if not payload or payload.feature ~= PING_STATE_FEATURE then
        return
    end

    local action = tostring(payload.action or "response")
    if action == "invalidate" then
        local refreshReason = "server-invalidate"
        if payload.context then
            refreshReason = refreshReason .. ":" .. tostring(payload.context)
        end

        addon:Debug("Ping System relay state invalidated: source="
            .. tostring(source) .. " context="
            .. tostring(payload.context))

        RequestCurrentPingRelayState(refreshReason)
        return
    end

    if action ~= "response" then
        return
    end

    local queuedReason = state.relayStateRefreshQueued
        and (state.relayStateQueuedReason or "queued-refresh") or nil
    state.relayStateRefreshQueued = false
    state.relayStateQueuedReason = nil
    state.relayStateRequestPending = false
    state.relayStateLastResponseAt = GetRelayStateTimestamp()
    state.relayStateLastResponseSource = source
    state.relayStateLastCompletedGeneration =
        state.relayStateRequestGeneration

    state.serverRelayState = {
        revision = tonumber(payload.revision) or 0,
        requestedDistribution = tostring(
            payload.requestedDistribution or "AUTO"),
        resolvedDistribution = tostring(payload.resolvedDistribution or ""),
        canRelay = payload.canRelay == true,
        inGroup = payload.inGroup == true,
        inRaidGroup = payload.inRaidGroup == true,
        recipientCount = math_max(0,
            math_floor(tonumber(payload.recipientCount) or 0)),
        connectedMemberCount = math_max(0,
            math_floor(tonumber(payload.connectedMemberCount) or 0)),
        subGroupScoped = payload.subGroupScoped == true,
        senderSubGroup = tonumber(payload.senderSubGroup),
        nativePingRelayTransport = payload.nativePingRelayTransport == true,
        nativeEnvelopeTransport = payload.nativeEnvelopeTransport == true,
        error = payload.error,
        context = payload.context,
        source = source,
    }

    addon:Debug("Ping System relay state received: canRelay="
        .. tostring(state.serverRelayState.canRelay)
        .. " requested="
        .. tostring(state.serverRelayState.requestedDistribution)
        .. " resolved="
        .. tostring(state.serverRelayState.resolvedDistribution)
        .. " recipients="
        .. tostring(state.serverRelayState.recipientCount)
        .. " connected="
        .. tostring(state.serverRelayState.connectedMemberCount)
        .. " source=" .. tostring(source)
        .. " context=" .. tostring(payload.context))

    RefreshSettingsStatusText()

    if queuedReason then
        RequestCurrentPingRelayState(queuedReason)
    end
end

RequestCurrentPingRelayState = function(reason)
    local requestReason = reason or "client-request"

    if state.relayStateRequestPending then
        state.relayStateRefreshQueued = true
        state.relayStateQueuedReason = requestReason
        addon:Debug("Ping System relay state refresh queued: reason="
            .. tostring(requestReason))
        RefreshSettingsStatusText()
        return true
    end

    local request = {
        distribution = ResolveRelayDistribution({}) or "AUTO",
        reason = requestReason,
    }
    local sent = false

    state.relayStateRequestPending = true
    state.relayStateRequestGeneration = state.relayStateRequestGeneration + 1
    state.relayStateLastRequestAt = GetRelayStateTimestamp()
    state.relayStateLastRequestReason = requestReason
    state.relayStateLastFailure = nil
    RefreshSettingsStatusText()

    if type(addon.RequestFeature) == "function" then
        sent = addon:RequestFeature(PING_STATE_FEATURE, request)
    elseif addon.protocol and type(addon.protocol.RequestFeature) == "function" then
        sent = addon.protocol:RequestFeature(PING_STATE_FEATURE, request)
    end

    if sent then
        addon:Debug("Ping System relay state requested: reason="
            .. tostring(requestReason) .. " request="
            .. tostring(state.relayStateRequestGeneration)
            .. " distribution=" .. tostring(request.distribution))
        return true
    end

    local queuedReason = state.relayStateRefreshQueued
        and (state.relayStateQueuedReason or requestReason) or nil
    state.relayStateRefreshQueued = false
    state.relayStateQueuedReason = nil
    state.relayStateRequestPending = false
    state.relayStateLastFailure = "request failed"
    RefreshSettingsStatusText()

    addon:Debug("Ping System relay state request failed: reason="
        .. tostring(requestReason))

    if queuedReason then
        SchedulePingRelayStateRequest(queuedReason, 0.25)
    end

    return false
end

SchedulePingRelayStateRequest = function(reason, delay)
    local function ExecuteRequest()
        RequestCurrentPingRelayState(reason)
    end

    if addon.DelayedCall then
        addon:DelayedCall(delay or 0, ExecuteRequest)
    else
        ExecuteRequest()
    end
end

local function RememberLocalRelaySequence(sequence, request)
    sequence = tonumber(sequence)
    if not sequence then
        return
    end

    local now = GetTime() or 0
    for key, record in pairs(state.recentLocalRelaySequences) do
        local timestamp = type(record) == "table" and tonumber(record.at) or tonumber(record)
        if not timestamp or (now - timestamp) > 2.0 then
            state.recentLocalRelaySequences[key] = nil
        end
    end

    state.recentLocalRelaySequences[tostring(sequence)] = {
        at = now,
        type = request and request.type,
        mapId = request and request.mapId,
        x = request and request.x,
        y = request and request.y,
    }
end

local function SendLocalPingRelay(normalized)
    local request, err = BuildRelayRequest(normalized)
    if not request then
        return false, err
    end

    if ShouldUseNativePingRelayBridge() then
        EnsureNativePingRelayPollFrame()

        local nativeOk, nativeSent = pcall(RequestNativePingRelay,
            request.distribution or "AUTO",
            request.payload or request.syncPayload or "")
        if nativeOk and nativeSent ~= false then
            RememberLocalRelaySequence(request.sequence, request)
            return true
        end

        if not nativeOk then
            addon:Debug("Native ping relay request failed: "
                .. tostring(nativeSent))
        end
    end

    local protocol = addon and addon.protocol
    local opcodes = (type(protocol) == "table" and protocol.Opcodes) or nil
    local requestOpcode = (opcodes and opcodes.CMSG_REQUEST_FEATURE) or 0x06
    if not requestOpcode then
        return false, "Missing CMSG_REQUEST_FEATURE opcode."
    end

    local moduleId = (type(protocol) == "table" and protocol.MODULE_ID) or "QOS"

    if type(protocol) == "table" and type(protocol.SendJson) == "function" then
        if not protocol.connected and type(protocol.Initialize) == "function" then
            pcall(function()
                protocol:Initialize()
            end)
        end

        if protocol:SendJson(requestOpcode, request) then
            RememberLocalRelaySequence(request.sequence, request)
            return true
        end
    end

    local directOk, directErr = SendRelayRequestDirect(moduleId, requestOpcode, request)
    if directOk then
        RememberLocalRelaySequence(request.sequence, request)
        return true
    end

    return false, directErr or "Ping relay request failed."
end

local function DecodeRelayEnvelopePayload(payload)
    if type(payload) ~= "table" then
        return payload
    end

    local encoded = payload.payload or payload.syncPayload
    if type(encoded) ~= "string" or encoded == "" then
        return payload
    end

    local decodeProtocolFn = ResolvePingFn("DecodePingSyncProtocolPayload", "C_Ping_DecodeProtocolPayload")
    local decodeSyncFn = ResolvePingFn("DecodePingSyncPayload", "C_Ping_DecodeSyncPayload")
    if not decodeProtocolFn and not decodeSyncFn then
        return payload
    end

    local ok
    local distribution
    local pingType
    local mapId
    local mapX
    local mapY
    local relayFlags
    local sequence

    if decodeProtocolFn then
        local r1
        local r2
        local r3
        local r4
        local r5
        local r6
        local r7

        ok, r1, r2, r3, r4, r5, r6, r7 = pcall(decodeProtocolFn, encoded)
        if not ok then
            return payload
        end

        local maybeDistribution = NormalizeRelayDistribution(r1)
        local firstToken = TrimWhitespace(r1):upper()

        if (firstToken == "AUTO" or maybeDistribution ~= "AUTO") and type(r2) == "string" then
            distribution = maybeDistribution
            pingType = r2
            mapId = r3
            mapX = r4
            mapY = r5
            relayFlags = r6
            sequence = r7
        else
            distribution = NormalizeRelayDistribution(payload.distribution)
            pingType = r1
            mapId = r2
            mapX = r3
            mapY = r4
            relayFlags = r5
            sequence = r6
        end

        if not pingType then
            return payload
        end
    else
        ok, pingType, mapId, mapX, mapY, relayFlags, sequence = pcall(decodeSyncFn, encoded)
        if not ok or not pingType then
            return payload
        end
        distribution = "AUTO"
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

local function BuildInboundPingDedupKey(payload)
    if type(payload) ~= "table" then
        return nil
    end

    local source = TrimWhitespace(payload.source):lower()
    local pingType = NormalizePingType(payload.type)
    local mapId = tonumber(payload.mapId or payload.mapID or payload.uiMapID) or 0
    local x = NormalizeCoord(payload.x or payload.mapX)
    local y = NormalizeCoord(payload.y or payload.mapY)
    local quantizedX
    local quantizedY
    if x and y then
        quantizedX = math_floor((x * 10000) + 0.5)
        quantizedY = math_floor((y * 10000) + 0.5)
    end

    local sequence = tonumber(payload.sequence)
    if sequence then
        if quantizedX and quantizedY then
            return string.format("seq:%s:%d:%s:%d:%d:%d", source, sequence, pingType, mapId, quantizedX, quantizedY)
        end
        return string.format("seq:%s:%d:%s", source, sequence, pingType)
    end

    if x and y then
        return string.format("coord:%s:%s:%d:%d:%d", source, pingType, mapId, quantizedX, quantizedY)
    end

    local text = TrimWhitespace(payload.text):lower()
    if text ~= "" then
        return string.format("text:%s:%s:%s", source, pingType, text)
    end

    return nil
end

local function ShouldSuppressInboundPing(payload)
    if type(payload) ~= "table" then
        return true
    end

    local now = GetTime() or 0

    for key, record in pairs(state.recentLocalRelaySequences) do
        local timestamp = type(record) == "table" and tonumber(record.at) or tonumber(record)
        if not timestamp or (now - timestamp) > 2.0 then
            state.recentLocalRelaySequences[key] = nil
        end
    end

    for key, timestamp in pairs(state.recentRemotePings) do
        if (now - timestamp) > 1.0 then
            state.recentRemotePings[key] = nil
        end
    end

    local sequence = tonumber(payload.sequence)
    if sequence then
        local localRecord = state.recentLocalRelaySequences[tostring(sequence)]
        local localTimestamp = type(localRecord) == "table" and tonumber(localRecord.at) or tonumber(localRecord)
        if localTimestamp and (now - localTimestamp) <= 1.0 then
            local source = TrimWhitespace(payload.source):lower()
            local playerName = (type(UnitName) == "function") and TrimWhitespace(UnitName("player")):lower() or ""
            local sourceMatchesPlayer = (source ~= "" and playerName ~= "" and source == playerName)

            local payloadType = NormalizePingType(payload.type)
            local payloadMapId = tonumber(payload.mapId or payload.mapID or payload.uiMapID)
            local payloadX = NormalizeCoord(payload.x or payload.mapX)
            local payloadY = NormalizeCoord(payload.y or payload.mapY)

            local localType = NormalizePingType(type(localRecord) == "table" and localRecord.type or nil)
            local localMapId = tonumber(type(localRecord) == "table" and localRecord.mapId or nil)
            local localX = NormalizeCoord(type(localRecord) == "table" and localRecord.x or nil)
            local localY = NormalizeCoord(type(localRecord) == "table" and localRecord.y or nil)

            local sameType = (payloadType == localType)
            local sameMap = (payloadMapId and localMapId and payloadMapId == localMapId)
            local closeCoords = false
            if payloadX and payloadY and localX and localY then
                closeCoords = math_abs(payloadX - localX) <= 0.0025 and math_abs(payloadY - localY) <= 0.0025
            end

            if sourceMatchesPlayer or (sameType and sameMap and closeCoords) then
                return true
            end
        end
    end

    local dedupKey = BuildInboundPingDedupKey(payload)
    if not dedupKey then
        return false
    end

    local seenAt = state.recentRemotePings[dedupKey]
    if seenAt and (now - seenAt) <= 0.35 then
        return true
    end

    state.recentRemotePings[dedupKey] = now
    return false
end

HandleProtocolFeatureData = function(rawPayload)
    local settings = GetSettings()
    if not settings.allowProtocolPings then
        return
    end

    if state.pingListenerEnabled == false then
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

    if ShouldSuppressInboundPing(payload) then
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
        if feature == PING_STATE_FEATURE then
            if type(payload) ~= "table" then
                payload = {}
            end

            if not payload.feature then
                payload.feature = feature
            end

            HandlePingRelayStateResponse(payload, "feature-event")
            return
        end

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

        HandleProtocolFeatureData(payload)
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

    local hasEntityTargetForRecovery = IsValidPingEntityTargetType(normalized.targetType)
        and type(normalized.targetGuid) == "string"
        and TrimWhitespace(normalized.targetGuid) ~= ""
    if hasEntityTargetForRecovery and not HasTargetMapCoordinates(normalized) and not HasTargetWorldCoordinates(normalized) then
        local recoveredTarget, recoveredToken, recoveredMatch = TryRecoverEntityTargetLocation(normalized.targetGuid, normalized.targetName)
        if recoveredTarget then
            CopyTargetLocation(normalized, recoveredTarget)
            DebugQuickPing(
                string.format(
                    "push entity recovery token=%s match=%s %s",
                    tostring(recoveredToken or "nil"),
                    tostring(recoveredMatch or "nil"),
                    FormatPingTargetDebug(recoveredTarget)
                )
            )
        end
    end

    while #state.active >= (settings.maxActivePings or 6) do
        ReleasePingAtIndex(1)
    end

    local frame = AcquirePingFrame()
    local x, y, distance, mapMismatch, targetMapId = ResolveProjection(normalized)

    local hasEntityOnlyTargetWithoutPosition = IsValidPingEntityTargetType(normalized.targetType)
        and type(normalized.targetGuid) == "string"
        and normalized.targetGuid ~= ""
        and not (type(normalized.mapId) == "number"
            and normalized.mapId > 0
            and type(normalized.x) == "number"
            and type(normalized.y) == "number")
        and not (type(normalized.worldX) == "number"
            and type(normalized.worldY) == "number"
            and type(normalized.worldZ) == "number")
        and not (type(normalized.screenX) == "number"
            and type(normalized.screenY) == "number")

    if type(x) ~= "number" or type(y) ~= "number" then
        if hasEntityOnlyTargetWithoutPosition then
            DebugQuickPing(string.format(
                "projection unavailable for entity-only ping guid=%s type=%s; skipping local marker render",
                tostring(normalized.targetGuid),
                tostring(normalized.targetType)
            ))
            PlayPingSound(normalized, style)
            addon:FireEvent("PING_SYSTEM_PING_ADDED", normalized)
            return true
        end

        DebugQuickPing("reject: invalid projection coordinates x=" .. tostring(x) .. " y=" .. tostring(y))
        return false, "Unable to project ping marker to screen."
    end

    DebugQuickPing(
        string.format(
            "projected x=%.1f y=%.1f map=%s nx=%s ny=%s sx=%s sy=%s",
            x,
            y,
            tostring(normalized.mapId or "nil"),
            normalized.x and string.format("%.4f", normalized.x) or "nil",
            normalized.y and string.format("%.4f", normalized.y) or "nil",
            normalized.screenX and string.format("%.1f", normalized.screenX) or "nil",
            normalized.screenY and string.format("%.1f", normalized.screenY) or "nil"
        )
    )

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", EnsureRootFrame(), "CENTER", x, y)

        local normalizedTargetType = TrimWhitespace(normalized.targetType):lower()
    local isWorldPoint = not (
        normalizedTargetType == "unit"
        or normalizedTargetType == "gameobject"
        or normalizedTargetType == "object"
    )

    local uiTextureKit = GetPingTextureSuffix(normalized.type)

    local iconAtlas = "Ping_Marker_Icon_" .. uiTextureKit
    if not ApplyAtlasTexture(frame.Icon, iconAtlas) then
        ApplyAtlasTexture(frame.Icon, "Ping_Marker_Icon_Info")
    end
    frame.Icon:SetSize(35, 35)
    frame.Icon:SetVertexColor(1, 1, 1, 1)

    local flipbookAtlas = "Ping_Marker_FlipBook_" .. uiTextureKit
    if not ApplyAtlasTexture(frame.IconFlipbook, flipbookAtlas) then
        ApplyAtlasTexture(frame.IconFlipbook, "Ping_Marker_Flipbook_Default")
    end

    local flipBookInfo = GetPinFlipBookInfo(uiTextureKit)
    if flipBookInfo then
        frame.IconFlipbook:ClearAllPoints()
        frame.IconFlipbook:SetSize(flipBookInfo.sizeX, flipBookInfo.sizeY)
        frame.IconFlipbook:SetPoint("CENTER", frame.Icon, "CENTER", flipBookInfo.anchorX, flipBookInfo.anchorY)
    else
        frame.IconFlipbook:SetSize(1, 1)
        frame.IconFlipbook:SetPoint("CENTER", frame.Icon, "CENTER", 0, 0)
    end
    frame.IconFlipbook:Hide()

    if not ApplyAtlasTexture(frame.PointerBG, "Ping_OVMarker_Pointer_BG") then
        frame.PointerBG:SetTexture("Interface\\Minimap\\UI-Minimap-Ping-Rotate")
    end

    local pointerAtlas = "Ping_OVMarker_Pointer_" .. uiTextureKit
    if not ApplyAtlasTexture(frame.Pointer, pointerAtlas) then
        ApplyAtlasTexture(frame.Pointer, "Ping_OVMarker_Pointer_Default")
    end

    if isWorldPoint then
        local bgAtlas = "Ping_GroundMarker_BG_" .. uiTextureKit
        local stemAtlas = "Ping_GroundMarker_Pin_" .. uiTextureKit
        local strokeAtlas = "Ping_GroundMarker_Stroke_" .. uiTextureKit

        if not ApplyAtlasTexture(frame.GroundBackground, bgAtlas) then
            ApplyAtlasTexture(frame.GroundBackground, "Ping_GroundMarker_BG_Default")
        end
        if not ApplyAtlasTexture(frame.GroundHighlight, bgAtlas) then
            ApplyAtlasTexture(frame.GroundHighlight, "Ping_GroundMarker_BG_Default")
        end
        if not ApplyAtlasTexture(frame.Stem, stemAtlas) then
            ApplyAtlasTexture(frame.Stem, "Ping_GroundMarker_Pin_Default")
        end
        if not ApplyAtlasTexture(frame.Stroke, strokeAtlas) then
            ApplyAtlasTexture(frame.Stroke, "Ping_GroundMarker_Stroke_Default")
        end

        frame.Icon:ClearAllPoints()
        frame.Icon:SetPoint("CENTER", frame.GroundBackground, "CENTER", 0, 0)
        frame.GroundPin:Show()
        frame.UnitPin:Hide()
    else
        local unitAtlas = "Ping_UnitMarker_BG_" .. uiTextureKit
        if not ApplyAtlasTexture(frame.UnitBackground, unitAtlas) then
            ApplyAtlasTexture(frame.UnitBackground, "Ping_UnitMarker_BG_Default")
        end

        frame.Icon:ClearAllPoints()
        frame.Icon:SetPoint("CENTER", frame.UnitBackground, "CENTER", 0, 3)
        frame.GroundPin:Hide()
        frame.UnitPin:Show()
    end

    frame.__dcqosIsWorldPoint = (isWorldPoint == true)
    frame.__dcqosUiTextureKit = uiTextureKit
    frame.ClampedPin:Hide()

    frame.GroundBackground:SetVertexColor(1, 1, 1, 1)
    frame.GroundHighlight:SetVertexColor(1, 1, 1, 1)
    frame.GroundMarker:SetVertexColor(1, 1, 1, 1)
    frame.Stem:SetVertexColor(1, 1, 1, 1)
    frame.Stroke:SetVertexColor(1, 1, 1, 1)
    frame.UnitBackground:SetVertexColor(1, 1, 1, 1)
    frame.PointerBG:SetVertexColor(1, 1, 1, 1)
    frame.Pointer:SetVertexColor(1, 1, 1, 1)

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
        targetGuid = normalized.targetGuid,
        targetType = normalized.targetType,
        nextTrackRefreshAt = now,
        projectionPayload = {
            mapId = normalized.mapId,
            x = normalized.x,
            y = normalized.y,
            worldX = normalized.worldX,
            worldY = normalized.worldY,
            worldZ = normalized.worldZ,
            screenX = normalized.screenX,
            screenY = normalized.screenY,
            relativeRadians = normalized.relativeRadians,
            relativeDegrees = normalized.relativeDegrees,
            bearingDegrees = normalized.bearingDegrees,
            distance = distance,
            targetType = normalized.targetType,
        },
        lastClampState = IsProjectedPointClamped(x, y, 52),
    })

    local frameId = AllocateSecurePingFrameId(frame)
    DispatchSecurePingEvent(SECURE_PING_EVENT_PIN_ADDED, frameId, uiTextureKit, isWorldPoint and true or false)
    DispatchSecurePingEvent(SECURE_PING_EVENT_PIN_CLAMP_UPDATED, frameId, IsProjectedPointClamped(x, y, 52) and true or false)
    DispatchSecurePingEvent(SECURE_PING_EVENT_COOLDOWN_STARTED, BuildPingCooldownInfo())

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

    local ignoreThrottle = (options.ignoreThrottle ~= false)
    local allowScreenFallback = (options.allowScreenFallback == true)
    local allowUnitTokenFallback = (options.allowUnitTokenFallback == true)

    local payload = {
        type = pingType or "warning",
        ignoreThrottle = ignoreThrottle,
    }

    DebugQuickPing(
        string.format(
            "resolvers cursorFn=%s mouseoverFn=%s secureFn=%s guidFn=%s",
            tostring(
                type(GetCursorWorldPingTarget) == "function"
                    or type(C_Ping_GetCursorWorldTarget) == "function"
                    or type(C_Ping_GetTargetWorldPing) == "function"
            ),
            tostring(
                type(GetMouseoverPingTarget) == "function"
                    or type(C_Ping_GetMouseoverTarget) == "function"
            ),
            tostring(
                type(GetTargetPingReceiver) == "function"
                    or type(C_Ping_GetTargetPingReceiver) == "function"
                    or (type(C_Ping) == "table" and type(C_Ping.GetTargetPingReceiver) == "function")
            ),
            tostring(
                type(ResolveEntityPositionByGUID) == "function"
                    or type(C_Ping_ResolveEntityPositionByGUID) == "function"
                    or (type(C_Ping) == "table" and type(C_Ping.ResolveEntityPositionByGUID) == "function")
            )
        )
    )

    local capturedHitX = tonumber(options.preResolvedHitX)
    local capturedHitY = tonumber(options.preResolvedHitY)
    local usePreResolvedCursor = (options.forcePreResolvedCursorTarget == true)

    local cursorTarget = nil
    if usePreResolvedCursor then
        cursorTarget = options.preResolvedCursorTarget
        if not cursorTarget and capturedHitX and capturedHitY then
            cursorTarget = ResolveCursorWorldPingTarget(capturedHitX, capturedHitY)
        end
    else
        cursorTarget = options.preResolvedCursorTarget or ResolveCursorWorldPingTarget(capturedHitX, capturedHitY)
    end
    local mouseoverTarget = ResolveMouseoverPingTarget()
    local secureReceiverTarget = ResolveTargetPingReceiver()
    local unitTokenTarget = allowUnitTokenFallback and ResolveAnyUnitTokenFallback() or nil
    DebugQuickPing("start type=" .. tostring(payload.type))
    DebugQuickPing("cursor " .. FormatPingTargetDebug(cursorTarget))
    DebugQuickPing("mouseover " .. FormatPingTargetDebug(mouseoverTarget))
    DebugQuickPing("secure " .. FormatPingTargetDebug(secureReceiverTarget))

    local entityTarget = nil
    local entityTargetSource = nil
    if mouseoverTarget and IsValidPingEntityTargetType(mouseoverTarget.targetType) then
        entityTarget = mouseoverTarget
        entityTargetSource = "mouseover"
    elseif cursorTarget and IsValidPingEntityTargetType(cursorTarget.targetType) then
        entityTarget = cursorTarget
        entityTargetSource = "cursor"
    elseif secureReceiverTarget and IsValidPingEntityTargetType(secureReceiverTarget.targetType) then
        entityTarget = secureReceiverTarget
        entityTargetSource = "secure-receiver"
    elseif unitTokenTarget and IsValidPingEntityTargetType(unitTokenTarget.targetType) then
        entityTarget = unitTokenTarget
        entityTargetSource = "unit-token"
    end

    local locationTarget = nil
    local locationTargetSource = nil
    if cursorTarget and (HasTargetMapCoordinates(cursorTarget) or HasTargetWorldCoordinates(cursorTarget)) then
        locationTarget = cursorTarget
        locationTargetSource = "cursor"
    elseif mouseoverTarget and (HasTargetMapCoordinates(mouseoverTarget) or HasTargetWorldCoordinates(mouseoverTarget)) then
        locationTarget = mouseoverTarget
        locationTargetSource = "mouseover"
    elseif secureReceiverTarget and (HasTargetMapCoordinates(secureReceiverTarget) or HasTargetWorldCoordinates(secureReceiverTarget)) then
        locationTarget = secureReceiverTarget
        locationTargetSource = "secure-receiver"
    elseif unitTokenTarget and HasTargetMapCoordinates(unitTokenTarget) then
        locationTarget = unitTokenTarget
        locationTargetSource = "unit-token"
    end

    -- If cursor and secure both resolve entity targets but disagree on GUID, trust secure.
    -- Cursor hits can be stale/misdirected during fast keybind pings without recent mouse click.
    if cursorTarget
        and secureReceiverTarget
        and IsValidPingEntityTargetType(cursorTarget.targetType)
        and IsValidPingEntityTargetType(secureReceiverTarget.targetType)
        and type(cursorTarget.targetGuid) == "string"
        and type(secureReceiverTarget.targetGuid) == "string"
        and cursorTarget.targetGuid ~= ""
        and secureReceiverTarget.targetGuid ~= ""
        and cursorTarget.targetGuid ~= secureReceiverTarget.targetGuid
    then
        entityTarget = secureReceiverTarget
        entityTargetSource = "secure-receiver"

        if HasTargetMapCoordinates(secureReceiverTarget) or HasTargetWorldCoordinates(secureReceiverTarget) then
            locationTarget = secureReceiverTarget
            locationTargetSource = "secure-receiver"
        end

        DebugQuickPing(
            "entity arbitration: secure override on guid mismatch cursor="
                .. tostring(cursorTarget.targetGuid)
                .. " secure="
                .. tostring(secureReceiverTarget.targetGuid)
        )
    end

    if locationTarget then
        CopyTargetLocation(payload, locationTarget)

        local locationType = TrimWhitespace(locationTarget.targetType):lower()
        if payload.targetType == nil and locationType ~= "" then
            payload.targetType = locationType
        end
    end

    if entityTarget then
        local applyEntityIdentity = false

        if not locationTarget then
            applyEntityIdentity = true
        elseif locationTargetSource == "cursor" or locationTargetSource == "mouseover" then
            applyEntityIdentity = IsValidPingEntityTargetType(locationTarget.targetType)
        else
            applyEntityIdentity = true
        end

        if applyEntityIdentity then
            CopyTargetIdentity(payload, entityTarget)
        else
            DebugQuickPing("identity skip: preserving cursor-ground location over non-cursor entity fallback")
        end
    end

    DebugQuickPing("selected entity=" .. tostring(entityTargetSource or "none") .. " location=" .. tostring(locationTargetSource or "none"))

    if type(UnitName) == "function" and type(UnitExists) == "function" and UnitExists("mouseover") then
        payload.targetName = UnitName("mouseover")
    elseif entityTarget and entityTarget.targetName and entityTarget.targetName ~= "" then
        payload.targetName = entityTarget.targetName
    end

    if payload.targetName and payload.targetName ~= "" then
        payload.text = payload.targetName
    end

    local hasMapCoords = HasTargetMapCoordinates(payload)
    local hasWorldCoords = HasTargetWorldCoordinates(payload)
    local hasEntityTarget = type(payload.targetGuid) == "string"
        and payload.targetGuid ~= ""
        and IsValidPingEntityTargetType(payload.targetType)

    if hasEntityTarget and not hasMapCoords and not hasWorldCoords then
        local recoveredTarget, recoveredToken, recoveredMatch = TryRecoverEntityTargetLocation(payload.targetGuid, payload.targetName)
        if recoveredTarget then
            CopyTargetLocation(payload, recoveredTarget)
            hasMapCoords = HasTargetMapCoordinates(payload)
            hasWorldCoords = HasTargetWorldCoordinates(payload)
            DebugQuickPing(
                string.format(
                    "entity recovery token=%s match=%s %s",
                    tostring(recoveredToken or "nil"),
                    tostring(recoveredMatch or "nil"),
                    FormatPingTargetDebug(recoveredTarget)
                )
            )
        else
            DebugQuickPing("entity recovery: no coordinates from strict unit-token matching")
        end
    end

    if not hasMapCoords and not hasWorldCoords then
        if hasEntityTarget then
            payload.noRelay = true
            DebugQuickPing("entity-only: no location coordinates resolved; keeping entity target metadata and disabling relay")
        elseif allowScreenFallback then
            DebugQuickPing("reject: unresolved ground ping would fall back to camera-relative screen offsets")
            return false, "No stable ground location resolved for ping."
        else
            DebugQuickPing("reject: no resolved target or ground coordinates")
            return false, "No target or ground location resolved for ping."
        end
    end

    if capturedHitX and capturedHitY then
        payload.cursorHitX = capturedHitX
        payload.cursorHitY = capturedHitY
    end

    if payload.targetType and payload.targetType ~= "ground" and not hasEntityTarget then
        DebugQuickPing("downgrade: invalid entity target metadata type=" .. tostring(payload.targetType) .. ", forcing ground")
        payload.targetType = "ground"
    end

    local finalSource = locationTargetSource or entityTargetSource or "none"
    if finalSource == "cursor" and not IsValidPingEntityTargetType(payload.targetType) then
        finalSource = "cursor-ground"
    elseif finalSource == "secure-receiver" then
        finalSource = "secure"
    elseif finalSource ~= "unit-token" and finalSource ~= "cursor-ground" and finalSource ~= "secure" then
        finalSource = tostring(finalSource)
    end
    DebugQuickPing("selection winner=" .. finalSource)

    DebugQuickPing(
        string.format(
            "push type=%s targetType=%s map=%s x=%s y=%s wx=%s wy=%s wz=%s sx=%s sy=%s guid=%s",
            tostring(payload.type),
            tostring(payload.targetType or "nil"),
            tostring(payload.mapId or "nil"),
            payload.x and string.format("%.4f", payload.x) or "nil",
            payload.y and string.format("%.4f", payload.y) or "nil",
            payload.worldX and string.format("%.2f", payload.worldX) or "nil",
            payload.worldY and string.format("%.2f", payload.worldY) or "nil",
            payload.worldZ and string.format("%.2f", payload.worldZ) or "nil",
            payload.screenX and string.format("%.1f", payload.screenX) or "nil",
            payload.screenY and string.format("%.1f", payload.screenY) or "nil",
            tostring(payload.targetGuid or "nil")
        )
    )

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
        local captured = state.capturedRadialTarget
        local capturedScreenX = state.capturedRadialScreenX
        local capturedScreenY = state.capturedRadialScreenY
        local capturedHitX = state.capturedRadialHitX
        local capturedHitY = state.capturedRadialHitY
        state.capturedRadialTarget = nil
        state.capturedRadialScreenX = nil
        state.capturedRadialScreenY = nil
        state.capturedRadialHitX = nil
        state.capturedRadialHitY = nil
        self:PushQuickPing(selectedType, {
            ignoreThrottle = false,
            allowScreenFallback = true,
            forcePreResolvedCursorTarget = true,
            preResolvedCursorTarget = captured,
            preResolvedScreenX = capturedScreenX,
            preResolvedScreenY = capturedScreenY,
            preResolvedHitX = capturedHitX,
            preResolvedHitY = capturedHitY,
        })
    else
        state.capturedRadialTarget = nil
        state.capturedRadialScreenX = nil
        state.capturedRadialScreenY = nil
        state.capturedRadialHitX = nil
        state.capturedRadialHitY = nil
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
    EnsureRetailPingApiShims()
    RunPingSecureRuntimeSelfTest()
    EnsureRootFrame()
    EnsureSlashCommand()
    EnsureFeatureEventBridge()
    if HasNativePingRelayBridge() then
        EnsureNativePingRelayPollFrame()
    end

    addon.PingSystem = PingSystem
    addon.PushScreenPing = function(_, payload)
        return PingSystem:Push(payload)
    end
end

function PingSystem.OnEnable()
    addon:Debug("Ping System module enabling")

    EnsureRetailPingApiShims()
    EnsureRootFrame()
    EnsureSlashCommand()
    EnsureFeatureEventBridge()
    if HasNativePingRelayBridge() then
        EnsureNativePingRelayPollFrame()
    end

    if not InstallProtocolHandler() and addon.DelayedCall then
        addon:DelayedCall(2.0, function()
            if IsEnabled() then
                InstallProtocolHandler()
            end
        end)
    end

    SchedulePingRelayStateRequest("enable", 1.25)
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

    local relayStateText = parent:CreateFontString(nil, "ARTWORK",
        "GameFontHighlightSmall")
    relayStateText:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -10)
    relayStateText:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    relayStateText:SetJustifyH("LEFT")
    relayStateText:SetText(BuildServerRelayStateText() .. "\n"
        .. BuildRelayRefreshText())

    local relayRefreshBtn = CreateFrame("Button", nil, parent,
        "UIPanelButtonTemplate")
    relayRefreshBtn:SetSize(140, 22)
    relayRefreshBtn:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -56)
    relayRefreshBtn:SetText("Refresh Relay State")
    relayRefreshBtn:SetScript("OnClick", function()
        if not RequestCurrentPingRelayState("settings-refresh") then
            addon:Print("Ping System: failed to request relay state.", true)
        end
    end)

    state.settingsRefreshButton = relayRefreshBtn
    state.settingsStatusUpdater = function()
        relayStateText:SetText(BuildServerRelayStateText() .. "\n"
            .. BuildRelayRefreshText())
    end

    parent:HookScript("OnShow", function()
        RefreshSettingsStatusText()
        RequestCurrentPingRelayState("settings-open")
    end)

    RefreshSettingsStatusText()

    local yOffset = -146

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
