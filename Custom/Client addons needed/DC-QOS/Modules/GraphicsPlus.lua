-- ============================================================
-- DC-QoS: Graphics+ Module
-- ============================================================

local addon = DCQOS

local GraphicsPlus = {
    displayName = "Graphics+",
    settingKey = "graphicsPlus",
    icon = "Interface\\Icons\\Spell_Nature_Farsight",
    defaults = {
        graphicsPlus = {
            enabled = true,
            autoApplyOnLogin = true,
            autoApplyOnZoneChange = true,
            showChatFeedback = false,
            farclip = 2200,
            cameraDistance = 120,
            horizonScale = 8.0,
            environmentDetail = 2.0,
            fogOverride = false,
            applyQualityPreset = true,
        },
    },
}

local eventFrame
local applyGeneration = 0
local state = {
    protocolHooked = false,
    protocolModule = nil,
    protocolOpcode = nil,
    protocolHandler = nil,
    nativeFeatureHandler = nil,
    nativeStateFeatureHandler = nil,
    nativeFeatureHandlerRegistered = false,
    activeServerProfile = nil,
    activeServerRevision = 0,
    activeServerContext = nil,
    serverProfileState = nil,
    profileStateRequestPending = false,
    profileStateRefreshQueued = false,
    profileStateQueuedReason = nil,
    profileStateRequestGeneration = 0,
    profileStateLastRequestAt = nil,
    profileStateLastRequestReason = nil,
    profileStateLastResponseAt = nil,
    profileStateLastResponseSource = nil,
    profileStateLastCompletedGeneration = 0,
    profileStateLastFailure = nil,
    settingsStatusUpdater = nil,
}

local NATIVE_ENVELOPE_CAPABILITY = 0x00100000
local SERVER_PROFILE_FEATURE = "graphics_profile"
local SERVER_PROFILE_STATE_FEATURE = "graphics_profile_state"
local GetProfileStateTimestamp
local RefreshSettingsStatusText
local RequestCurrentServerProfileState
local ScheduleProfileStateRequest

local SERVER_PROFILE_PRESETS = {
    SAFE = {
        farclip = 1400,
        cameraDistance = 70,
        horizonScale = 4.5,
        environmentDetail = 1.2,
        fogOverride = false,
        applyQualityPreset = false,
        nameplateDistance = 20,
    },
    WORLD = {
        farclip = 2200,
        cameraDistance = 120,
        horizonScale = 8.0,
        environmentDetail = 2.0,
        fogOverride = false,
        applyQualityPreset = true,
        nameplateDistance = 41,
    },
    RAID = {
        farclip = 1800,
        cameraDistance = 95,
        horizonScale = 6.0,
        environmentDetail = 1.5,
        fogOverride = false,
        applyQualityPreset = true,
        nameplateDistance = 35,
    },
    BATTLEGROUND = {
        farclip = 2600,
        cameraDistance = 150,
        horizonScale = 7.0,
        environmentDetail = 2.4,
        fogOverride = false,
        applyQualityPreset = true,
        nameplateDistance = 41,
    },
}

local function GetSliderRoundedValue(slider)
    if not slider or type(slider.GetValue) ~= "function" then
        return 0
    end

    return slider:GetValue()
end

local function GetSettings()
    return addon.settings.graphicsPlus
end

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

local function HasNativeEnvelopeBridge()
    if type(PollDCNativeEnvelope) ~= "function" then
        return false
    end

    local capabilities = GetClientCapabilityMask()
    if capabilities > 0 then
        return HasCapabilityBit(capabilities, NATIVE_ENVELOPE_CAPABILITY)
    end

    return true
end

local function ShouldUseNativeEnvelopeBridge()
    return HasNativeEnvelopeBridge()
        and IsCapabilityNegotiated(NATIVE_ENVELOPE_CAPABILITY)
end

local function HasNativeGraphicsApi()
    return type(SetExtendedFarclip) == "function"
        and type(SetExtendedCameraDistance) == "function"
        and type(SetHorizonScale) == "function"
        and type(SetEnvironmentDetail) == "function"
        and type(SetTextureQuality) == "function"
        and type(SetRenderFlags) == "function"
        and type(SetFogDistance) == "function"
end

local function CallNative(func, ...)
    if type(func) ~= "function" then
        return false
    end

    local ok, result = pcall(func, ...)
    if not ok then
        return false
    end

    return result ~= false
end

local function ApplyNameplateDistance(distance)
    distance = tonumber(distance)
    if not distance or distance <= 0 then
        return true
    end

    local applied = true

    if type(SetNameplateDistance) == "function" then
        applied = CallNative(SetNameplateDistance, distance) and applied
    end

    if type(SetCVar) == "function" then
        local ok = pcall(SetCVar, "nameplateMaxDistance", tostring(distance))
        applied = ok and applied
    end

    return applied
end

local function ApplyGraphicsSettings(reason, overrideSettings)
    local settings = overrideSettings or GetSettings()
    if not settings then
        return false, "missing-settings"
    end

    if not overrideSettings and state.activeServerProfile then
        return false, "server-profile-active"
    end

    if not overrideSettings and not settings.enabled then
        return false, "disabled"
    end

    if not HasNativeGraphicsApi() then
        return false, "missing-api"
    end

    local applied = true

    applied = CallNative(SetExtendedFarclip, settings.farclip) and applied
    applied = CallNative(SetExtendedCameraDistance, settings.cameraDistance) and applied
    applied = CallNative(SetHorizonScale, settings.horizonScale) and applied
    applied = CallNative(SetEnvironmentDetail, settings.environmentDetail) and applied

    if settings.applyQualityPreset then
        applied = CallNative(SetRenderFlags, true, true, true, false, 0) and applied
        applied = CallNative(SetTextureQuality, 0, -0.5, 8, 256) and applied
    end

    if settings.fogOverride then
        applied = CallNative(SetFogDistance, -10000, 10000) and applied
    end

    if settings.nameplateDistance then
        applied = ApplyNameplateDistance(settings.nameplateDistance) and applied
    end

    local localSettings = GetSettings()
    if localSettings and localSettings.showChatFeedback and reason
        and reason ~= "slider" then
        addon:Print("Graphics+ applied (" .. tostring(reason) .. ").", true)
    end

    return applied, applied and "ok" or "call-failed"
end

local function ScheduleLocalReapply(reason, delay)
    local function Reapply()
        if state.activeServerProfile then
            return
        end

        ApplyGraphicsSettings(reason)
    end

    if addon.DelayedCall then
        addon:DelayedCall(delay or 0, Reapply)
    else
        Reapply()
    end
end

local function ScheduleApply(reason, delay)
    applyGeneration = applyGeneration + 1
    local generation = applyGeneration

    local function ExecuteApply()
        if generation ~= applyGeneration then
            return
        end

        ApplyGraphicsSettings(reason)
    end

    if addon.DelayedCall then
        addon:DelayedCall(delay or 0, ExecuteApply)
    else
        ExecuteApply()
    end
end

local function RequestCurrentServerProfile(reason)
    local request = {
        reason = reason or "client-request",
    }

    if type(addon.RequestFeature) == "function" then
        return addon:RequestFeature(SERVER_PROFILE_FEATURE, request)
    end

    if not addon.protocol or type(addon.protocol.RequestFeature) ~= "function" then
        return false
    end

    return addon.protocol:RequestFeature(SERVER_PROFILE_FEATURE, request)
end

RequestCurrentServerProfileState = function(reason)
    local requestReason = reason or "client-request"

    if state.profileStateRequestPending then
        state.profileStateRefreshQueued = true
        state.profileStateQueuedReason = requestReason
        addon:Debug("Graphics+ server profile state refresh queued: reason="
            .. tostring(requestReason))
        RefreshSettingsStatusText()
        return true
    end

    local request = {
        reason = requestReason,
    }
    local sent = false

    state.profileStateRequestPending = true
    state.profileStateRequestGeneration = state.profileStateRequestGeneration + 1
    state.profileStateLastRequestAt = GetProfileStateTimestamp()
    state.profileStateLastRequestReason = requestReason
    state.profileStateLastFailure = nil
    RefreshSettingsStatusText()

    if type(addon.RequestFeature) == "function" then
        sent = addon:RequestFeature(SERVER_PROFILE_STATE_FEATURE, request)
    elseif addon.protocol and type(addon.protocol.RequestFeature) == "function" then
        sent = addon.protocol:RequestFeature(SERVER_PROFILE_STATE_FEATURE, request)
    end

    if sent then
        addon:Debug("Graphics+ server profile state requested: reason="
            .. tostring(requestReason) .. " request="
            .. tostring(state.profileStateRequestGeneration))
        return true
    end

    local queuedReason = state.profileStateRefreshQueued
        and (state.profileStateQueuedReason or requestReason) or nil
    state.profileStateRefreshQueued = false
    state.profileStateQueuedReason = nil
    state.profileStateRequestPending = false
    state.profileStateLastFailure = string.format("request failed at %s",
        GetProfileStateTimestamp())
    RefreshSettingsStatusText()

    addon:Debug("Graphics+ server profile state request failed: reason="
        .. tostring(requestReason))

    if queuedReason then
        ScheduleProfileStateRequest(queuedReason, 0.25)
    end

    return false
end

local function ScheduleProfileRequest(reason, delay)
    local function ExecuteRequest()
        RequestCurrentServerProfile(reason)
    end

    if addon.DelayedCall then
        addon:DelayedCall(delay or 0, ExecuteRequest)
    else
        ExecuteRequest()
    end
end

ScheduleProfileStateRequest = function(reason, delay)
    local function ExecuteRequest()
        RequestCurrentServerProfileState(reason)
    end

    if addon.DelayedCall then
        addon:DelayedCall(delay or 0, ExecuteRequest)
    else
        ExecuteRequest()
    end
end

local function FormatStatusValue(value, fallback)
    if value == nil then
        return fallback or "?"
    end

    local text = tostring(value)
    if text == "" then
        return fallback or "?"
    end

    return text
end

GetProfileStateTimestamp = function()
    if type(date) == "function" then
        return date("%H:%M:%S")
    end

    if type(GetTime) == "function" then
        return string.format("%.1fs", GetTime())
    end

    return "now"
end

local function GetProfileStateGroupLabel(snapshot)
    if type(snapshot) ~= "table" then
        return "unknown"
    end

    if snapshot.inRaidGroup == true then
        return "raid"
    end

    if snapshot.inGroup == true then
        return "party"
    end

    return "solo"
end

local function BuildActiveServerProfileStatusText()
    if state.activeServerProfile then
        return string.format(
            "|cff00ff00Server Override: %s|r (rev=%s, context=%s)",
            FormatStatusValue(state.activeServerProfile, "?"),
            FormatStatusValue(state.activeServerRevision, "0"),
            FormatStatusValue(state.activeServerContext, "unknown"))
    end

    if (tonumber(state.activeServerRevision) or 0) > 0 then
        return string.format(
            "|cffffff00Server Override: none|r (last rev=%s, context=%s)",
            FormatStatusValue(state.activeServerRevision, "0"),
            FormatStatusValue(state.activeServerContext, "unknown"))
    end

    return "|cffccccccServer Override: no active server profile seen yet.|r"
end

local function BuildServerProfileStateText()
    local snapshot = state.serverProfileState
    if type(snapshot) ~= "table" then
        return "|cffccccccServer Snapshot: request pending or not received yet.|r"
    end

    local mapSummary = snapshot.hasMap and string.format(
        "map=%s zone=%s area=%s",
        FormatStatusValue(snapshot.mapId, "?"),
        FormatStatusValue(snapshot.zoneId, "?"),
        FormatStatusValue(snapshot.areaId, "?")) or "no map"

    return string.format(
        "Server Snapshot: %s/%s, %s, group=%s, response=%s, rev=%s",
        FormatStatusValue(snapshot.profile, "?"),
        FormatStatusValue(snapshot.profileContext, "?"),
        mapSummary,
        GetProfileStateGroupLabel(snapshot),
        FormatStatusValue(snapshot.context, "feature-request"),
        FormatStatusValue(snapshot.revision, "0"))
end

local function BuildServerProfileRefreshText()
    local requestId = tostring(state.profileStateRequestGeneration or 0)
    local requestReason = FormatStatusValue(state.profileStateLastRequestReason,
        "client-request")

    if state.profileStateRequestPending then
        local pendingSuffix = state.profileStateRefreshQueued
            and ", queued refresh" or ""
        return string.format(
            "|cffffff00State Refresh: pending|r (#%s at %s, reason=%s%s)",
            requestId,
            FormatStatusValue(state.profileStateLastRequestAt, "now"),
            requestReason,
            pendingSuffix)
    end

    if state.profileStateLastFailure then
        return string.format(
            "|cffff5555State Refresh: %s|r (reason=%s)",
            state.profileStateLastFailure,
            requestReason)
    end

    if state.profileStateLastResponseAt then
        return string.format(
            "|cff00ff00State Refresh: updated|r (#%s at %s via %s, reason=%s)",
            tostring(state.profileStateLastCompletedGeneration or requestId),
            FormatStatusValue(state.profileStateLastResponseAt, "?"),
            FormatStatusValue(state.profileStateLastResponseSource, "unknown"),
            requestReason)
    end

    return "|cffccccccState Refresh: no request sent yet.|r"
end

RefreshSettingsStatusText = function()
    if type(state.settingsStatusUpdater) == "function" then
        state.settingsStatusUpdater()
    end
end

local function HandleServerProfileApply(profileKey, revision, context, source)
    local preset = SERVER_PROFILE_PRESETS[profileKey]
    if type(preset) ~= "table" then
        return
    end

    revision = tonumber(revision) or 0
    if state.activeServerProfile == profileKey
        and revision > 0
        and revision <= (state.activeServerRevision or 0) then
        return
    end

    state.activeServerProfile = profileKey
    state.activeServerRevision = revision
    state.activeServerContext = context

    ApplyGraphicsSettings("server profile " .. tostring(profileKey), preset)

    addon:Debug("Graphics+ server profile applied: " .. tostring(profileKey)
        .. " source=" .. tostring(source)
        .. " context=" .. tostring(context))

    RefreshSettingsStatusText()
end

local function HandleServerProfileInvalidate(context, revision, source)
    state.activeServerProfile = nil
    state.activeServerRevision = tonumber(revision) or 0
    state.activeServerContext = context

    addon:Debug("Graphics+ server profile invalidated: source="
        .. tostring(source) .. " context=" .. tostring(context))

    RefreshSettingsStatusText()
    ScheduleLocalReapply("server invalidate", 0.05)
end

local function NormalizeFeaturePayload(rawPayload)
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

local function HandleServerProfileStateResponse(payload, source)
    payload = NormalizeFeaturePayload(payload)
    if not payload or payload.feature ~= SERVER_PROFILE_STATE_FEATURE then
        return
    end

    local action = tostring(payload.action or "response")
    if action == "invalidate" then
        local refreshReason = "server-invalidate"
        if payload.context then
            refreshReason = refreshReason .. ":" .. tostring(payload.context)
        end

        addon:Debug("Graphics+ server profile state invalidated: source="
            .. tostring(source) .. " context="
            .. tostring(payload.context))

        RequestCurrentServerProfileState(refreshReason)
        return
    end

    if action ~= "response" then
        return
    end

    local queuedReason = state.profileStateRefreshQueued
        and (state.profileStateQueuedReason or "queued-refresh") or nil
    state.profileStateRefreshQueued = false
    state.profileStateQueuedReason = nil
    state.profileStateRequestPending = false
    state.profileStateLastResponseAt = GetProfileStateTimestamp()
    state.profileStateLastResponseSource = source
    state.profileStateLastCompletedGeneration =
        state.profileStateRequestGeneration

    state.serverProfileState = {
        revision = tonumber(payload.revision) or 0,
        profile = payload.profile,
        profileContext = payload.profileContext,
        mapId = payload.mapId,
        zoneId = payload.zoneId,
        areaId = payload.areaId,
        inGroup = payload.inGroup,
        inRaidGroup = payload.inRaidGroup,
        hasMap = payload.hasMap,
        context = payload.context,
        source = source,
    }

    addon:Debug("Graphics+ server profile state received: profile="
        .. tostring(payload.profile) .. " profileContext="
        .. tostring(payload.profileContext) .. " mapId="
        .. tostring(payload.mapId) .. " zoneId="
        .. tostring(payload.zoneId) .. " areaId="
        .. tostring(payload.areaId) .. " group="
        .. GetProfileStateGroupLabel(payload) .. " source="
        .. tostring(source) .. " context=" .. tostring(payload.context))

    RefreshSettingsStatusText()

    if queuedReason then
        RequestCurrentServerProfileState(queuedReason)
    end
end

local function HandleProfileMessage(payload, source)
    payload = NormalizeFeaturePayload(payload)
    if not payload then
        return
    end

    if payload.feature == SERVER_PROFILE_STATE_FEATURE then
        HandleServerProfileStateResponse(payload, source)
        return
    end

    if payload.feature ~= SERVER_PROFILE_FEATURE then
        return
    end

    local action = tostring(payload.action or "")
    if action == "apply" then
        HandleServerProfileApply(
            tostring(payload.profile or payload.payload or ""),
            payload.revision, payload.context, source)
    elseif action == "invalidate" then
        HandleServerProfileInvalidate(payload.context, payload.revision,
            source)
    end
end

local function RegisterNativeFeatureHandler()
    if state.nativeFeatureHandlerRegistered then
        return true
    end

    if not addon.protocol
        or type(addon.protocol.RegisterFeatureHandler) ~= "function" then
        return false
    end

    state.nativeFeatureHandler = function(payload)
        HandleProfileMessage(payload, "native")
    end

    state.nativeStateFeatureHandler = function(payload)
        HandleProfileMessage(payload, "native")
    end

    if not addon.protocol:RegisterFeatureHandler(SERVER_PROFILE_FEATURE,
            state.nativeFeatureHandler) then
        state.nativeFeatureHandler = nil
        return false
    end

    if not addon.protocol:RegisterFeatureHandler(SERVER_PROFILE_STATE_FEATURE,
            state.nativeStateFeatureHandler) then
        addon.protocol:UnregisterFeatureHandler(SERVER_PROFILE_FEATURE,
            state.nativeFeatureHandler)
        state.nativeFeatureHandler = nil
        state.nativeStateFeatureHandler = nil
        return false
    end

    state.nativeFeatureHandlerRegistered = true
    return true
end

local function UnregisterNativeFeatureHandler()
    if not state.nativeFeatureHandlerRegistered then
        return
    end

    if addon.protocol
        and type(addon.protocol.UnregisterFeatureHandler) == "function"
        and state.nativeFeatureHandler then
        addon.protocol:UnregisterFeatureHandler(SERVER_PROFILE_FEATURE,
            state.nativeFeatureHandler)
    end

    if addon.protocol
        and type(addon.protocol.UnregisterFeatureHandler) == "function"
        and state.nativeStateFeatureHandler then
        addon.protocol:UnregisterFeatureHandler(SERVER_PROFILE_STATE_FEATURE,
            state.nativeStateFeatureHandler)
    end

    state.nativeFeatureHandler = nil
    state.nativeStateFeatureHandler = nil
    state.nativeFeatureHandlerRegistered = false
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
        HandleProfileMessage(payload, "addon")
    end

    DC:RegisterHandler(moduleId, opcode, state.protocolHandler)
    state.protocolHooked = true
    state.protocolModule = moduleId
    state.protocolOpcode = opcode

    addon:Debug("Graphics+ protocol hook registered: "
        .. tostring(moduleId) .. " op=" .. tostring(opcode))
    return true
end

local function UninstallProtocolHandler()
    if not state.protocolHooked then
        return
    end

    local DC = rawget(_G, "DCAddonProtocol")
    if DC and type(DC.UnregisterHandler) == "function" and state.protocolHandler then
        pcall(DC.UnregisterHandler, DC, state.protocolModule,
            state.protocolOpcode, state.protocolHandler)
    end

    state.protocolHooked = false
    state.protocolModule = nil
    state.protocolOpcode = nil
    state.protocolHandler = nil
end

local function EnsureEventFrame()
    if eventFrame then
        return eventFrame
    end

    eventFrame = CreateFrame("Frame")
    eventFrame:SetScript("OnEvent", function(_, event)
        local settings = GetSettings()
        if not settings or not settings.enabled then
            return
        end

        if event == "PLAYER_LOGIN" and settings.autoApplyOnLogin then
            -- Apply before the world renders to prevent flicker
            ScheduleApply("login", 0)
            ScheduleProfileRequest("login", 0.5)
        elseif event == "PLAYER_ENTERING_WORLD" and settings.autoApplyOnLogin then
            -- Short fallback for portal/loading-screen transitions after login
            ScheduleApply("zone transition", 0.2)
            ScheduleProfileRequest("zone transition", 0.5)
        elseif event == "ZONE_CHANGED_NEW_AREA" and settings.autoApplyOnZoneChange then
            ScheduleApply("zone change", 0.75)
            ScheduleProfileRequest("zone change", 0.95)
        end
    end)

    return eventFrame
end

local function SetPreset(values)
    for key, value in pairs(values) do
        addon:SetSetting("graphicsPlus." .. key, value)
    end
end

function GraphicsPlus.OnInitialize()
    addon:Debug("Graphics+ module initializing")
end

function GraphicsPlus.OnEnable()
    addon:Debug("Graphics+ module enabling")

    local frame = EnsureEventFrame()
    frame:UnregisterAllEvents()
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

    if not RegisterNativeFeatureHandler() and addon.DelayedCall then
        addon:DelayedCall(1.0, function()
            if GraphicsPlus:IsEnabled() then
                RegisterNativeFeatureHandler()
            end
        end)
    end

    if not InstallProtocolHandler() and addon.DelayedCall then
        addon:DelayedCall(1.0, function()
            if GraphicsPlus:IsEnabled() then
                InstallProtocolHandler()
            end
        end)
    end

    ScheduleProfileStateRequest("startup", 1.0)
end

function GraphicsPlus.OnDisable()
    addon:Debug("Graphics+ module disabling")

    if eventFrame then
        eventFrame:UnregisterAllEvents()
    end

    UnregisterNativeFeatureHandler()
    UninstallProtocolHandler()
    state.activeServerProfile = nil
    state.activeServerRevision = 0
    state.activeServerContext = nil
    state.serverProfileState = nil
    state.profileStateRequestPending = false
    state.profileStateRefreshQueued = false
    state.profileStateQueuedReason = nil
    state.profileStateRequestGeneration = 0
    state.profileStateLastRequestAt = nil
    state.profileStateLastRequestReason = nil
    state.profileStateLastResponseAt = nil
    state.profileStateLastResponseSource = nil
    state.profileStateLastCompletedGeneration = 0
    state.profileStateLastFailure = nil
    RefreshSettingsStatusText()
end

function GraphicsPlus.CreateSettings(parent)
    local settings = GetSettings()

    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Graphics+")

    local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    desc:SetJustifyH("LEFT")
    desc:SetText("Applies extended graphics limits from the native WotLKExtensions patch and reapplies them on login or zone changes.")

    local status = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    status:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -10)
    status:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    status:SetJustifyH("LEFT")

    local serverStateStatus = parent:CreateFontString(nil, "ARTWORK",
        "GameFontHighlightSmall")
    serverStateStatus:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -8)
    serverStateStatus:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    serverStateStatus:SetJustifyH("LEFT")

    local refreshStateBtn = CreateFrame("Button", nil, parent,
        "UIPanelButtonTemplate")
    refreshStateBtn:SetSize(160, 22)
    refreshStateBtn:SetPoint("TOPLEFT", serverStateStatus, "BOTTOMLEFT", 0,
        -8)
    refreshStateBtn:SetText("Refresh Server State")

    local function UpdateStatusText()
        if HasNativeGraphicsApi() then
            status:SetText("|cff00ff00Native Graphics+ API detected.|r")
        else
            status:SetText("|cffff5555Native Graphics+ API missing. Build the client DLL with GRAPHICSENHANCED_PATCH and reload the game.|r")
        end
    end

    local function UpdateServerStateText()
        serverStateStatus:SetText(BuildActiveServerProfileStatusText()
            .. "\n" .. BuildServerProfileStateText()
            .. "\n" .. BuildServerProfileRefreshText())

        if HasNativeGraphicsApi() then
            refreshStateBtn:Enable()
        else
            refreshStateBtn:Disable()
        end
    end

    state.settingsStatusUpdater = function()
        UpdateStatusText()
        UpdateServerStateText()
    end

    refreshStateBtn:SetScript("OnClick", function()
        if not RequestCurrentServerProfileState("settings-refresh") then
            addon:Print("Graphics+ could not request the current server profile state.", true)
        end
    end)

    UpdateStatusText()
    UpdateServerStateText()

    parent:HookScript("OnShow", function()
        RefreshSettingsStatusText()
        ScheduleProfileStateRequest("settings-open", 0.05)
    end)

    local yOffset = -175

    local enabledCb = addon:CreateCheckbox(parent)
    enabledCb:SetPoint("TOPLEFT", 16, yOffset)
    enabledCb.Text:SetText("Enable Graphics+ auto-apply")
    enabledCb:SetChecked(settings.enabled)
    enabledCb:SetScript("OnClick", function(self)
        addon:SetSetting("graphicsPlus.enabled", self:GetChecked())
    end)
    yOffset = yOffset - 25

    local loginCb = addon:CreateCheckbox(parent)
    loginCb:SetPoint("TOPLEFT", 16, yOffset)
    loginCb.Text:SetText("Apply on login / entering world")
    loginCb:SetChecked(settings.autoApplyOnLogin ~= false)
    loginCb:SetScript("OnClick", function(self)
        addon:SetSetting("graphicsPlus.autoApplyOnLogin", self:GetChecked())
    end)
    yOffset = yOffset - 25

    local zoneCb = addon:CreateCheckbox(parent)
    zoneCb:SetPoint("TOPLEFT", 16, yOffset)
    zoneCb.Text:SetText("Reapply on zone change")
    zoneCb:SetChecked(settings.autoApplyOnZoneChange ~= false)
    zoneCb:SetScript("OnClick", function(self)
        addon:SetSetting("graphicsPlus.autoApplyOnZoneChange", self:GetChecked())
    end)
    yOffset = yOffset - 25

    local chatCb = addon:CreateCheckbox(parent)
    chatCb:SetPoint("TOPLEFT", 16, yOffset)
    chatCb.Text:SetText("Show chat feedback when settings are applied")
    chatCb:SetChecked(settings.showChatFeedback == true)
    chatCb:SetScript("OnClick", function(self)
        addon:SetSetting("graphicsPlus.showChatFeedback", self:GetChecked())
    end)
    yOffset = yOffset - 35

    local sliderHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    sliderHeader:SetPoint("TOPLEFT", 16, yOffset)
    sliderHeader:SetText("Extended Limits")
    yOffset = yOffset - 25

    local farclipSlider = addon:CreateSlider(parent)
    farclipSlider:SetPoint("TOPLEFT", 16, yOffset)
    farclipSlider:SetWidth(220)
    farclipSlider:SetMinMaxValues(100, 3831)
    farclipSlider:SetValueStep(25)
    farclipSlider.Text:SetText("Farclip: " .. tostring(settings.farclip or 2200))
    farclipSlider.Low:SetText("100")
    farclipSlider.High:SetText("3831")
    farclipSlider:SetValue(settings.farclip or 2200)
    farclipSlider:SetScript("OnValueChanged", function(self, value)
        local rounded = math.floor(value + 0.5)
        if self._dcqosLastValue == rounded then return end
        self._dcqosLastValue = rounded
        self.Text:SetText("Farclip: " .. tostring(rounded))
        addon:SetSetting("graphicsPlus.farclip", rounded)
        ScheduleApply("slider", 0.05)
    end)
    yOffset = yOffset - 54

    local cameraSlider = addon:CreateSlider(parent)
    cameraSlider:SetPoint("TOPLEFT", 16, yOffset)
    cameraSlider:SetWidth(220)
    cameraSlider:SetMinMaxValues(1, 500)
    cameraSlider:SetValueStep(5)
    cameraSlider.Text:SetText("Camera Distance: " .. tostring(settings.cameraDistance or 120))
    cameraSlider.Low:SetText("1")
    cameraSlider.High:SetText("500")
    cameraSlider:SetValue(settings.cameraDistance or 120)
    cameraSlider:SetScript("OnValueChanged", function(self, value)
        local rounded = math.floor(value + 0.5)
        if self._dcqosLastValue == rounded then return end
        self._dcqosLastValue = rounded
        self.Text:SetText("Camera Distance: " .. tostring(rounded))
        addon:SetSetting("graphicsPlus.cameraDistance", rounded)
        ScheduleApply("slider", 0.05)
    end)
    yOffset = yOffset - 54

    local horizonSlider = addon:CreateSlider(parent)
    horizonSlider:SetPoint("TOPLEFT", 16, yOffset)
    horizonSlider:SetWidth(220)
    horizonSlider:SetMinMaxValues(1.0, 12.0)
    horizonSlider:SetValueStep(0.5)
    horizonSlider.Text:SetText(string.format("Horizon Scale: %.1f", settings.horizonScale or 8.0))
    horizonSlider.Low:SetText("1.0")
    horizonSlider.High:SetText("12.0")
    horizonSlider:SetValue(settings.horizonScale or 8.0)
    horizonSlider:SetScript("OnValueChanged", function(self, value)
        local rounded = math.floor((value * 10) + 0.5) / 10
        if self._dcqosLastValue == rounded then return end
        self._dcqosLastValue = rounded
        self.Text:SetText(string.format("Horizon Scale: %.1f", rounded))
        addon:SetSetting("graphicsPlus.horizonScale", rounded)
        ScheduleApply("slider", 0.05)
    end)
    yOffset = yOffset - 54

    local environmentSlider = addon:CreateSlider(parent)
    environmentSlider:SetPoint("TOPLEFT", 16, yOffset)
    environmentSlider:SetWidth(220)
    environmentSlider:SetMinMaxValues(0.5, 6.0)
    environmentSlider:SetValueStep(0.1)
    environmentSlider.Text:SetText(string.format("Environment Detail: %.1f", settings.environmentDetail or 2.0))
    environmentSlider.Low:SetText("0.5")
    environmentSlider.High:SetText("6.0")
    environmentSlider:SetValue(settings.environmentDetail or 2.0)
    environmentSlider:SetScript("OnValueChanged", function(self, value)
        local rounded = math.floor((value * 10) + 0.5) / 10
        if self._dcqosLastValue == rounded then return end
        self._dcqosLastValue = rounded
        self.Text:SetText(string.format("Environment Detail: %.1f", rounded))
        addon:SetSetting("graphicsPlus.environmentDetail", rounded)
        ScheduleApply("slider", 0.05)
    end)
    yOffset = yOffset - 54

    local qualityHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    qualityHeader:SetPoint("TOPLEFT", 16, yOffset)
    qualityHeader:SetText("Overrides")
    yOffset = yOffset - 25

    local fogCb = addon:CreateCheckbox(parent)
    fogCb:SetPoint("TOPLEFT", 16, yOffset)
    fogCb.Text:SetText("Reduce blue fog wall aggressively")
    fogCb:SetChecked(settings.fogOverride == true)
    fogCb:SetScript("OnClick", function(self)
        addon:SetSetting("graphicsPlus.fogOverride", self:GetChecked())
        ScheduleApply("fog override", 0.05)
    end)
    yOffset = yOffset - 22

    local fogInfo = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    fogInfo:SetPoint("TOPLEFT", 34, yOffset)
    fogInfo:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    fogInfo:SetJustifyH("LEFT")
    fogInfo:SetText("Turning this off stops reapplying the override; the default zone fog comes back naturally after reload or zone transitions.")
    yOffset = yOffset - 34

    local qualityCb = addon:CreateCheckbox(parent)
    qualityCb:SetPoint("TOPLEFT", 16, yOffset)
    qualityCb.Text:SetText("Apply built-in texture and render quality preset")
    qualityCb:SetChecked(settings.applyQualityPreset ~= false)
    qualityCb:SetScript("OnClick", function(self)
        addon:SetSetting("graphicsPlus.applyQualityPreset", self:GetChecked())
        ScheduleApply("quality preset", 0.05)
    end)
    yOffset = yOffset - 34

    local presetHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    presetHeader:SetPoint("TOPLEFT", 16, yOffset)
    presetHeader:SetText("Presets")
    yOffset = yOffset - 28

    local function RefreshControls()
        local current = GetSettings()
        enabledCb:SetChecked(current.enabled)
        loginCb:SetChecked(current.autoApplyOnLogin ~= false)
        zoneCb:SetChecked(current.autoApplyOnZoneChange ~= false)
        chatCb:SetChecked(current.showChatFeedback == true)
        fogCb:SetChecked(current.fogOverride == true)
        qualityCb:SetChecked(current.applyQualityPreset ~= false)

        farclipSlider._dcqosLastValue = nil
        farclipSlider:SetValue(current.farclip or 2200)
        cameraSlider._dcqosLastValue = nil
        cameraSlider:SetValue(current.cameraDistance or 120)
        horizonSlider._dcqosLastValue = nil
        horizonSlider:SetValue(current.horizonScale or 8.0)
        environmentSlider._dcqosLastValue = nil
        environmentSlider:SetValue(current.environmentDetail or 2.0)
    end

    local balancedBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    balancedBtn:SetSize(120, 22)
    balancedBtn:SetPoint("TOPLEFT", 16, yOffset)
    balancedBtn:SetText("Balanced")
    balancedBtn:SetScript("OnClick", function()
        SetPreset({
            farclip = 2200,
            cameraDistance = 120,
            horizonScale = 8.0,
            environmentDetail = 2.0,
            fogOverride = false,
            applyQualityPreset = true,
        })
        RefreshControls()
        ScheduleApply("balanced preset", 0.05)
    end)

    local ultraBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    ultraBtn:SetSize(120, 22)
    ultraBtn:SetPoint("LEFT", balancedBtn, "RIGHT", 10, 0)
    ultraBtn:SetText("Ultra")
    ultraBtn:SetScript("OnClick", function()
        SetPreset({
            farclip = 3831,
            cameraDistance = 500,
            horizonScale = 12.0,
            environmentDetail = 6.0,
            fogOverride = true,
            applyQualityPreset = true,
        })
        RefreshControls()
        ScheduleApply("ultra preset", 0.05)
    end)

    local applyBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    applyBtn:SetSize(120, 22)
    applyBtn:SetPoint("LEFT", ultraBtn, "RIGHT", 10, 0)
    applyBtn:SetText("Apply Now")
    applyBtn:SetScript("OnClick", function()
        if not HasNativeGraphicsApi() then
            addon:Print("Graphics+ native API is not available in this client build.", true)
            return
        end

        local ok, reason = ApplyGraphicsSettings("manual")
        if not ok then
            if reason == "server-profile-active" then
                addon:Print("A server graphics profile is currently active. Wait for it to clear before applying local settings.", true)
            else
                addon:Print("Graphics+ apply failed. Check that the graphics patch is enabled in the client DLL.", true)
            end
        end
    end)

    yOffset = yOffset - 34

    local note = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", 16, yOffset)
    note:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    note:SetJustifyH("LEFT")
    note:SetText("Note: DC-QOS Interface camera zoom factor still stacks on top of Graphics+ camera distance, so very high combinations can be extreme.")

    RefreshControls()
    return yOffset - 40
end

addon:RegisterModule("GraphicsPlus", GraphicsPlus)