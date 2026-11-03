-- ============================================================
-- DC-QoS: Graphics+ Module
-- ============================================================
-- Extended graphics limits, a page of the game's Video window (UI/VideoOptions.lua).
-- The page edits a copy of the settings, and Okay or Apply write it back and apply it,
-- like the stock pages: the client preloads behind a loading screen whenever farclip
-- grows by more than 10 yards, so nothing may apply while a slider is moving.

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
        },
    },
}

-- Doodad size categories as bucketed by the client (bounding radius
-- < 1/4/15/100/100000); vanilla is each category's stock draw distance and
-- the native lift-only floor, so it doubles as the slider minimum.
local DOODAD_CATEGORIES = {
    { key = "doodadTiny", label = "Tiny", vanilla = 30 },
    { key = "doodadSmall", label = "Small", vanilla = 100 },
    { key = "doodadMedium", label = "Medium", vanilla = 200 },
    { key = "doodadLarge", label = "Large", vanilla = 750 },
    { key = "doodadHuge", label = "Huge", vanilla = 1250 },
}

-- The effective doodad distance is base x environmentDetail, and every doodad in range
-- is a draw call on the render thread. Balanced keeps the horizon for large and huge
-- doodads and stops small ones where they are sub-pixel anyway (effective at 1.5:
-- ~300 / 600 / 1050 / 1500 / 1875 yd). 1250 for every size at 2.0 drew grass tufts and
-- pebbles, vanilla 30 yd, out to ~2500 yd.
local PRESETS = {
    {
        label = "Performance",
        values = {
            farclip = 1400,
            cameraDistance = 70,
            horizonScale = 4.5,
            environmentDetail = 1.2,
            grassDistance = 100,
            doodadFade = 220,
            doodadFadeCategories = { 220, 220, 220, 750, 1250 },
            applyQualityPreset = false,
        },
    },
    {
        label = "Balanced",
        values = {
            farclip = 1800,
            cameraDistance = 120,
            horizonScale = 6.0,
            environmentDetail = 1.5,
            grassDistance = 200,
            doodadFade = 1250,
            doodadFadeCategories = { 200, 400, 700, 1000, 1250 },
            applyQualityPreset = true,
        },
    },
    {
        label = "Ultra",
        values = {
            farclip = 3831,
            cameraDistance = 500,
            horizonScale = 12.0,
            environmentDetail = 6.0,
            grassDistance = 280,
            doodadFade = 2560,
            doodadFadeCategories = { 2560, 2560, 2560, 2560, 2560 },
            applyQualityPreset = true,
        },
    },
}

local BALANCED = PRESETS[2].values

for key, value in pairs(BALANCED) do
    GraphicsPlus.defaults.graphicsPlus[key] = addon:DeepCopy(value)
end

local function Whole(value)
    return string.format("%d", value)
end

local function Tenths(value)
    return string.format("%.1f", value)
end

local LIMIT_SLIDERS = {
    { key = "farclip", label = "Farclip", min = 100, max = 3831, step = 25, format = Whole },
    { key = "cameraDistance", label = "Camera Distance", min = 1, max = 500, step = 5, format = Whole },
    { key = "horizonScale", label = "Horizon Scale", min = 1, max = 12, step = 0.5, format = Tenths },
    { key = "environmentDetail", label = "Environment Detail", min = 0.5, max = 6, step = 0.1, format = Tenths },
    { key = "grassDistance", label = "Grass Distance", min = 70, max = 280, step = 10, format = Whole },
}

local OPTION_BOXES = {
    { key = "applyQualityPreset", label = "Apply built-in texture and render quality preset" },
    { key = "enabled", label = "Enable Graphics+ auto-apply" },
    { key = "autoApplyOnLogin", label = "Apply on login / entering world" },
    { key = "autoApplyOnZoneChange", label = "Reapply on zone change" },
    { key = "showChatFeedback", label = "Show chat feedback when settings are applied" },
}

-- The Effects page's sliders for the same values, which end at the stock limits
local EFFECTS_SLIDERS = {
    { control = "VideoOptionsEffectsPanelViewDistance", key = "farclip" },
    { control = "VideoOptionsEffectsPanelEnvironmentDetail", key = "environmentDetail" },
    { control = "VideoOptionsEffectsPanelClutterRadius", key = "grassDistance" },
}

local eventFrame
local applyGeneration = 0
local pending
local RefreshControls

-- Until 2026-10-30 the server picked a profile for every map and that replaced these
-- settings, so what they hold was never seen in game and can be far heavier than what
-- was (doodads at 2560 yards). Every character starts from what was: its WORLD profile,
-- now the Balanced preset.
local function AdoptServerProfileValues(settings)
    for key, value in pairs(BALANCED) do
        settings[key] = addon:DeepCopy(value)
    end
    settings.fogOverride = nil
    settings.localValues = true
    addon:SaveSettings()
end

local function GetSettings()
    local settings = addon.settings.graphicsPlus
    if settings and not settings.localValues then
        AdoptServerProfileValues(settings)
    end
    return settings
end

local function HasNativeGraphicsApi()
    return type(SetExtendedFarclip) == "function"
        and type(SetExtendedCameraDistance) == "function"
        and type(SetHorizonScale) == "function"
        and type(SetEnvironmentDetail) == "function"
        and type(SetTextureQuality) == "function"
        and type(SetRenderFlags) == "function"
end

-- The native client only: the old one stops at the stock 140 yards, which the Effects page covers.
local function HasGrassDistanceApi()
    return type(SetGrassDistance) == "function"
end

-- Newer DLL builds only; checked separately so older DLLs keep the rest
-- of the panel working.
local function HasDoodadFadeApi()
    return type(SetDoodadFadeDistance) == "function"
end

local function HasDoodadFadeCategoryApi()
    return type(SetDoodadFadeCategoryDistance) == "function"
end

-- Per-category distances with fallbacks: stored category value, else the
-- master doodadFade value, never below the category's vanilla distance.
local function GetDoodadCategoryValues(settings)
    local stored = settings and settings.doodadFadeCategories
    local master = tonumber(settings and settings.doodadFade) or 2560
    local values = {}

    for index, category in ipairs(DOODAD_CATEGORIES) do
        local value
        if type(stored) == "table" then
            value = tonumber(stored[index])
        end
        value = value or master
        if value < category.vanilla then
            value = category.vanilla
        end
        values[index] = value
    end

    return values
end

local function CallNative(func, ...)
    if type(func) == "function" then
        pcall(func, ...)
    end
end

-- Raise gxTextureCacheSize to a floor and never lower it, so a player who chose a bigger cache keeps it.
-- 0 is left alone: its meaning is engine-defined, not "too small".
local TEXTURE_CACHE_FLOOR_MB = 1024
local function EnsureTextureCacheFloor()
    if type(GetCVar) ~= "function" or type(SetCVar) ~= "function" then
        return
    end
    local ok, value = pcall(GetCVar, "gxTextureCacheSize")
    local current = ok and tonumber(value) or nil
    if current and current > 0 and current < TEXTURE_CACHE_FLOOR_MB then
        pcall(SetCVar, "gxTextureCacheSize", tostring(TEXTURE_CACHE_FLOOR_MB))
    end
end

local function ApplyGraphicsSettings(reason)
    local settings = GetSettings()
    if not settings or not settings.enabled or not HasNativeGraphicsApi() then
        return
    end

    CallNative(SetExtendedFarclip, settings.farclip)
    CallNative(SetExtendedCameraDistance, settings.cameraDistance)
    CallNative(SetHorizonScale, settings.horizonScale)
    CallNative(SetEnvironmentDetail, settings.environmentDetail)
    CallNative(SetGrassDistance, settings.grassDistance)

    if HasDoodadFadeCategoryApi() then
        local categories = GetDoodadCategoryValues(settings)
        for index = 1, #DOODAD_CATEGORIES do
            CallNative(SetDoodadFadeCategoryDistance, index - 1, categories[index])
        end
    elseif HasDoodadFadeApi() then
        CallNative(SetDoodadFadeDistance, settings.doodadFade)
    end

    if settings.applyQualityPreset then
        CallNative(SetRenderFlags, true, true, true, false, 0)
        -- Texture cache deliberately NOT passed. The preset used to force gxTextureCacheSize to 256 on
        -- every login and zone change, overwriting the player's own value. With full-resolution textures
        -- (baseMip 0, texLodBias -0.5) and this client's HD art, 256 MB fills during normal play and
        -- lazily loaded textures stop resolving -- minimap tiles went black in the Hinterland BG. The
        -- native also clamps the size to 512, so it could never go higher here.
        CallNative(SetTextureQuality, 0, -0.5, 8)
        EnsureTextureCacheFloor()
    end

    if settings.showChatFeedback then
        addon:Print("Graphics+ applied (" .. tostring(reason) .. ").", true)
    end
end

local function ScheduleApply(reason)
    applyGeneration = applyGeneration + 1
    local generation = applyGeneration

    addon:DelayedCall(0, function()
        if generation == applyGeneration then
            ApplyGraphicsSettings(reason)
        end
    end)
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
            ScheduleApply("login")
        elseif event == "PLAYER_ENTERING_WORLD" and settings.autoApplyOnLogin then
            ScheduleApply("zone transition")
        elseif event == "ZONE_CHANGED_NEW_AREA" and settings.autoApplyOnZoneChange then
            ScheduleApply("zone change")
        end
    end)

    return eventFrame
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

    -- The addon initializes after the first frame, which can be after those events
    local settings = GetSettings()
    if settings and settings.autoApplyOnLogin then
        ScheduleApply("login")
    end
end

function GraphicsPlus.OnDisable()
    addon:Debug("Graphics+ module disabling")

    if eventFrame then
        eventFrame:UnregisterAllEvents()
    end
end

local function MarkChanged()
    VideoOptionsFrameApply:Enable()
end

local function CreatePresetButtons(parent, y)
    for index, preset in ipairs(PRESETS) do
        local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        button:SetSize(112, 22)
        button:SetPoint("TOPLEFT", 12 + (index - 1) * 118, y)
        button:SetText(preset.label)
        button:SetScript("OnClick", function()
            PlaySound("igMainMenuOptionCheckBoxOn")
            for key, value in pairs(preset.values) do
                pending[key] = addon:DeepCopy(value)
            end
            RefreshControls()
            MarkChanged()
        end)
    end
end

function GraphicsPlus.CreateSettings(parent)
    local description = "Limits beyond the stock ones. Farclip, Environment Detail and Grass Distance are the same values as View Distance, Environment Detail and Ground Clutter Radius on the Effects page, which stop at the stock maximums."
    if not HasNativeGraphicsApi() then
        description = "|cffff5555This client has no Graphics+ support, so these settings do nothing.|r"
    end
    addon:CreateVideoPageTitle(parent, "Graphics+", description)

    local y = -78
    CreatePresetButtons(parent, y)
    y = y - 46

    local limitSliders = {}
    for index, info in ipairs(LIMIT_SLIDERS) do
        local column = index % 2 == 1 and 1 or 2
        limitSliders[info.key] = addon:CreateVideoSlider(parent, column, y, info, function(value)
            pending[info.key] = value
            MarkChanged()
        end)
        if column == 2 or index == #LIMIT_SLIDERS then
            y = y - 46
        end
    end

    if not HasGrassDistanceApi() then
        limitSliders.grassDistance:Hide()
    end

    y = y + 2
    addon:CreateVideoHeader(parent, y, "Doodad Distance")
    y = y - 16
    addon:CreateVideoNote(parent, y, "How far clutter draws, whatever Farclip is. Each size stays at or above its stock distance.")
    y = y - 44

    local categorySliders = {}

    local masterSlider = addon:CreateVideoSlider(parent, 1, y, {
        key = "doodadFade",
        label = HasDoodadFadeApi() and "All Sizes" or "All Sizes (DLL update required)",
        min = 30, max = 2560, step = 10, format = Whole,
    }, function(value)
        pending.doodadFade = value
        pending.doodadFadeCategories = {}
        for index, category in ipairs(DOODAD_CATEGORIES) do
            local target = math.max(value, category.vanilla)
            pending.doodadFadeCategories[index] = target
            categorySliders[index]:ShowStored(target)
        end
        MarkChanged()
    end)
    addon:SetVideoControlEnabled(masterSlider, HasDoodadFadeApi())

    -- Two to a row, the first beside the master slider
    for index, category in ipairs(DOODAD_CATEGORIES) do
        local column = index % 2 == 1 and 2 or 1
        if column == 1 then
            y = y - 46
        end
        categorySliders[index] = addon:CreateVideoSlider(parent, column, y, {
            key = category.key,
            label = HasDoodadFadeCategoryApi() and category.label or (category.label .. " (DLL update required)"),
            min = category.vanilla, max = 2560, step = 10, format = Whole,
        }, function(value)
            pending.doodadFadeCategories = GetDoodadCategoryValues(pending)
            pending.doodadFadeCategories[index] = value
            MarkChanged()
        end)
        addon:SetVideoControlEnabled(categorySliders[index], HasDoodadFadeCategoryApi())
    end
    y = y - 34

    local optionBoxes = {}
    for _, info in ipairs(OPTION_BOXES) do
        optionBoxes[info.key] = addon:CreateVideoCheckbox(parent, y, info.key, info.label, function(checked)
            pending[info.key] = checked
            MarkChanged()
        end)
        y = y - 24
    end

    y = y - 6
    addon:CreateVideoNote(parent, y, "DC-QOS Interface camera zoom factor still stacks on top of Camera Distance, so very high combinations can be extreme.")

    RefreshControls = function()
        for key, slider in pairs(limitSliders) do
            slider:ShowStored(pending[key])
        end

        masterSlider:ShowStored(pending.doodadFade)
        local categories = GetDoodadCategoryValues(pending)
        for index, slider in ipairs(categorySliders) do
            slider:ShowStored(categories[index])
        end

        for key, box in pairs(optionBoxes) do
            box:SetChecked(pending[key])
        end
    end

    GraphicsPlus.VideoOptionsRefresh()
    return y - 40
end

function GraphicsPlus.VideoOptionsRefresh()
    pending = addon:DeepCopy(GetSettings())
    RefreshControls()

    -- This runs after the Effects page's refresh. Its sliders stop at the stock limits, so
    -- that refresh left them holding the smaller value as a change, and its Okay would
    -- write it over the CVar: growing farclip back would show a loading screen.
    for _, link in ipairs(EFFECTS_SLIDERS) do
        local control = _G[link.control]
        if control then
            control.newValue = nil
            link.opened = control.value
        end
    end
end

local function SaveAndApply(settings, wasEnabled, reason)
    addon:SaveSettings()
    if settings.enabled and not wasEnabled then
        addon:EnableModule("GraphicsPlus")
    end
    ApplyGraphicsSettings(reason)
end

function GraphicsPlus.VideoOptionsOkay()
    local settings = GetSettings()

    -- The Effects page's Okay ran first. A slider that moved there sets the same value as
    -- one here, and unless this page changed it too, that is the player's newest choice.
    for _, link in ipairs(EFFECTS_SLIDERS) do
        local control = _G[link.control]
        if control and control.value ~= link.opened then
            if pending[link.key] == settings[link.key] then
                pending[link.key] = control.value
            end
            link.opened = control.value
        end
    end

    local wasEnabled = settings.enabled
    for key, value in pairs(pending) do
        settings[key] = value
    end
    pending = addon:DeepCopy(settings)

    SaveAndApply(settings, wasEnabled, "video options")
    RefreshControls()
end

-- Nothing on this page applies before Okay, and opening the window reads the settings again
function GraphicsPlus.VideoOptionsCancel()
end

function GraphicsPlus.VideoOptionsDefault()
    local settings = GetSettings()
    local wasEnabled = settings.enabled
    for key, value in pairs(GraphicsPlus.defaults.graphicsPlus) do
        settings[key] = addon:DeepCopy(value)
    end

    SaveAndApply(settings, wasEnabled, "defaults")
end

addon:RegisterModule("GraphicsPlus", GraphicsPlus)
