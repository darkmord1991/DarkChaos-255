-- ============================================================
-- DC-QoS: Post-Processing Module
-- ============================================================
-- A page of the game's Video window (UI/VideoOptions.lua) for the native client's
-- world effects. The values are the client's own CVars, saved in Config.wtf. The page
-- applies as its controls move, like the stock gamma slider, so that an effect can be
-- judged while tuning it, and Cancel puts back what it found. The old client has none
-- of these CVars and never gets the page.

local addon = DCQOS

local PostProcessing = {
    displayName = "Post-Processing",
}

local SMAA_LEVELS = { [0] = "Off", "Low", "Medium", "High", "Ultra" }
local GTAO_LEVELS = { [0] = "Off", "Low", "Medium", "High" }

local function Level(names)
    return function(value)
        return names[value] or tostring(value)
    end
end

local function Yards(value)
    return string.format("%.1f yards", value)
end

local function WholeYards(value)
    return string.format("%d yards", value)
end

local function Percent(value)
    return string.format("%d%%", value * 100 + 0.5)
end

local function WholePercent(value)
    return string.format("%d%%", value)
end

local function SignedPercent(value)
    return string.format("%+d%%", math.floor(value * 100 + 0.5))
end

local function Stops(value)
    return string.format("%+.1f stops", value)
end

local function Degrees(value)
    return string.format("%d degrees", value + 0.5)
end

local function FineDegrees(value)
    return string.format("%.2f degrees", value)
end

local function Dither(value)
    if value <= 0 then
        return "Off"
    end
    return string.format("%.1f", value)
end

-- dcShadowSunHeight: 1 the sun's real height, 5 the original steep light
local function SunHeight(value)
    if value <= 1 then
        return "Real sun"
    elseif value >= 5 then
        return "Original"
    end
    return string.format("%.1fx steeper", value)
end

local function Warmth(value)
    if value > 0 then
        return string.format("%d%% warmer", value * 100 + 0.5)
    elseif value < 0 then
        return string.format("%d%% cooler", -value * 100 + 0.5)
    end
    return "neutral"
end

local SMAA_SLIDER = {
    key = "dcSmaa", label = "Quality", min = 0, max = 4, step = 1, format = Level(SMAA_LEVELS),
}

local GTAO_SLIDER = {
    key = "dcGtao", label = "Quality", min = 0, max = 3, step = 1, format = Level(GTAO_LEVELS),
}

local GTAO_DETAIL_SLIDERS = {
    { key = "dcGtaoRadius", label = "Radius", min = 0.5, max = 5, step = 0.1, format = Yards },
    { key = "dcGtaoStrength", label = "Strength", min = 0, max = 1, step = 0.05, format = Percent },
    { key = "dcGtaoDistance", label = "Fade distance", min = 40, max = 400, step = 10, format = WholeYards },
}

local UPSCALERS = { [1] = "FSR 1", [2] = "FSR 3.1" }

local UPSCALER_SLIDER = {
    key = "dcUpscaler", label = "Upscaler", min = 1, max = 2, step = 1, format = Level(UPSCALERS),
}

local RENDER_SCALE_SLIDER = {
    key = "dcRenderScale", label = "Render scale", min = 50, max = 100, step = 5, format = WholePercent,
}

local SHARPNESS_SLIDER = {
    key = "dcFsrSharpness", label = "Sharpness", min = 0, max = 1, step = 0.05, format = Percent,
}

-- The effects added after GTAO, each an on/off box with its detail sliders. The ranges are
-- the ones the client clamps to (DarkChaosSunRays, DarkChaosContactShadows, DarkChaosBloom,
-- DarkChaosGrade, DarkChaos_SurfaceLight). "depth" marks the ones that read the world's
-- depth, which the device may not hand a shader (see UpdateAvailability).
local SUN_RAYS = {
    key = "dcSunRays", label = "Rays of light from the sun across the sky", depth = true,
    sliders = {
        { key = "dcSunRaysStrength", label = "Strength", min = 0, max = 2, step = 0.05, format = Percent },
    },
}

local CONTACT_SHADOWS = {
    key = "dcContactShadows", label = "Contact shadows on small details", depth = true,
    sliders = {
        { key = "dcContactShadowsLength", label = "Length", min = 0.1, max = 4, step = 0.1, format = Yards },
        { key = "dcContactShadowsStrength", label = "Strength", min = 0, max = 1, step = 0.05, format = Percent },
    },
}

local BLOOM = {
    key = "dcBloom", label = "Bloom (replaces the original glow)",
    sliders = {
        { key = "dcBloomStrength", label = "Strength", min = 0, max = 2, step = 0.05, format = Percent },
        { key = "dcBloomThreshold", label = "From brightness", min = 0, max = 1, step = 0.05, format = Percent },
    },
}

local GRADE = {
    key = "dcGrade", label = "Colour grading",
    sliders = {
        { key = "dcGradeExposure", label = "Exposure", min = -2, max = 2, step = 0.1, format = Stops },
        { key = "dcGradeContrast", label = "Contrast", min = -1, max = 1, step = 0.05, format = SignedPercent },
        { key = "dcGradeSaturation", label = "Saturation", min = 0, max = 2, step = 0.05, format = Percent },
        { key = "dcGradeWarmth", label = "Warmth", min = -1, max = 1, step = 0.05, format = Warmth },
    },
}

local PIXEL_LIGHTS_CVAR = "dcPixelLights"
local LIGHTING_SLIDERS = {
    { key = "dcShadowSunOnly", label = "Shade keeps colour", min = 0, max = 1, step = 0.05, format = Percent },
    { key = "dcLightWrap", label = "Soft light edge", min = 0, max = 1, step = 0.05, format = Percent },
}

-- The sky, the sun's path, the shadow maps and the added lamp lights (DayNightRender, DayNight,
-- ShadowQuery, ShadowCache, DarkChaosLampLights). Ranges are the client's clamps again.
local SKY = {
    key = "dcSky", label = "Glow around the sun and moon, and sunlight through thin cloud",
    sliders = {
        { key = "dcSkyGlow", label = "Glow", min = 0, max = 4, step = 0.05, format = Percent },
        { key = "dcSkyGlowHorizon", label = "Glow at the horizon", min = 0, max = 4, step = 0.05, format = Percent },
        { key = "dcSkyGlowSize", label = "Glow size", min = 1, max = 179, step = 1, format = Degrees },
        { key = "dcSkyCloudSun", label = "Sun through cloud", min = 0, max = 8, step = 0.1, format = Percent },
        { key = "dcSkyDither", label = "Dither against banding", min = 0, max = 8, step = 0.5, format = Dither },
    },
}

local SUN_PATH = {
    key = "dcSunPath", label = "By day the sun stands where the world's light comes from", sliders = {},
}

local DAY_NIGHT = {
    key = "dcDayNightSmooth", label = "Day and night colours change continuously, not in half-minute steps", sliders = {},
}

local GLARE_SLIDER = {
    key = "dcSunGlareDim", label = "Sun glare darkens the world", min = 0, max = 1, step = 0.05, format = Percent,
}

local SHADOW_SUN_SLIDERS = {
    { key = "dcShadowSunHeight", label = "Shadow light", min = 1, max = 5, step = 0.1, format = SunHeight },
    { key = "dcShadowSunMin", label = "Lowest shadow sun", min = 0, max = 45, step = 1, format = Degrees },
}

local SHADOW_CACHE = {
    key = "dcShadowSunCache", label = "Cached shadows keep the sun direction they were drawn with (no sliding)",
    sliders = {
        { key = "dcShadowSunRefresh", label = "Redraw after the sun turns", min = 0.05, max = 5, step = 0.05, format = FineDegrees },
    },
}

local SHADOW_BOXES = {
    { key = "dcShadowTexelSnap", label = "Shadow edges hold still as the camera moves (no crawling)" },
    { key = "dcShadowCasterFade", label = "Shadow casters fade by distance from the shadow's centre (no blinking)" },
    { key = "dcShadowBillboard", label = "Tree leaf cards face the sun in the shadows" },
    { key = "dcShadowBandStagger", label = "At the highest shadow qualities, redraw the far shadows every few frames while the view holds still" },
}

local LAMPS = {
    key = "dcLampLights", label = "Night lights for lamps, lanterns, torches and braziers that have none",
    sliders = {
        { key = "dcLampLightsIntensity", label = "Brightness", min = 0, max = 4, step = 0.1, format = Percent },
        { key = "dcLampLightsRange", label = "Reach", min = 2, max = 30, step = 1, format = WholeYards },
    },
}

local LAMP_OBJECTS_CVAR = "dcLampLightsObjects"

-- The volumetric fog and the water have their own page (Modules/FogAndWater.lua); these CVars tell
-- whether this client has it, for the pointer under the title
local FOG_AND_WATER_CVARS = { "dcVolumetricFog", "dcWater" }

local EFFECTS = { SUN_RAYS, CONTACT_SHADOWS, BLOOM, GRADE, SKY, SUN_PATH, DAY_NIGHT, SHADOW_CACHE, LAMPS }

local GTAO_DEBUG_CVAR = "dcGtaoDebug"
local CVARS = { "dcSmaa", "dcGtao", "dcGtaoRadius", "dcGtaoStrength", "dcGtaoDistance", GTAO_DEBUG_CVAR,
    "dcUpscaler", "dcRenderScale", "dcFsrSharpness", PIXEL_LIGHTS_CVAR, GLARE_SLIDER.key, LAMP_OBJECTS_CVAR }
for _, effect in ipairs(EFFECTS) do
    table.insert(CVARS, effect.key)
    for _, info in ipairs(effect.sliders) do
        table.insert(CVARS, info.key)
    end
end
for _, list in ipairs({ LIGHTING_SLIDERS, SHADOW_SUN_SLIDERS, SHADOW_BOXES }) do
    for _, info in ipairs(list) do
        table.insert(CVARS, info.key)
    end
end

local sliders = {}
local boxes = {}            -- cvar -> check box, for every on/off CVar on the page
local gtaoSlider, gtaoNote, debugBox, depthNote
local gtaoDetails = {}
local effectControls = {}   -- effect -> { box, sliders }
local saved = {}

local function ReadNumber(cvar)
    return tonumber(GetCVar(cvar)) or 0
end

-- GetCVar answers nil for a CVar the client does not know, and SetCVar throws on one. An addon
-- newer than the exe would otherwise break the whole window, so a control whose CVar is
-- missing is left out and Cancel and Defaults pass it by.
local function Exists(cvar)
    return GetCVar(cvar) ~= nil
end

local function RememberValues()
    for _, cvar in ipairs(CVARS) do
        saved[cvar] = GetCVar(cvar)
    end
end

local function UpdateAvailability()
    local available = IsAmbientOcclusionAvailable()
    local active = available and ReadNumber(GTAO_SLIDER.key) > 0

    if available then
        gtaoNote:SetText("Darkens the creases and corners where surfaces meet.")
        depthNote:SetText("The sun's rays and the contact shadows read the world's depth, like the ambient occlusion above.")
    else
        gtaoNote:SetText("|cffff8080Unavailable on this device. If multisampling is on, turn it off on the Resolution page and reopen this window.|r")
        depthNote:SetText("|cffff8080The sun's rays and the contact shadows need the world's depth, which this device cannot read right now (see the ambient occlusion above).|r")
    end

    addon:SetVideoControlEnabled(gtaoSlider, available)
    for _, slider in ipairs(gtaoDetails) do
        addon:SetVideoControlEnabled(slider, active)
    end
    addon:SetVideoControlEnabled(debugBox, active)

    -- An effect's box is usable where the effect can run; its sliders only while it is on
    for effect, controls in pairs(effectControls) do
        local usable = available or not effect.depth
        addon:SetVideoControlEnabled(controls.box, usable)
        for _, slider in ipairs(controls.sliders) do
            addon:SetVideoControlEnabled(slider, usable and ReadNumber(effect.key) ~= 0)
        end
    end
end

local function WriteCVar(cvar, value)
    SetCVar(cvar, tostring(value))
    UpdateAvailability()
    VideoOptionsFrameApply:Enable()
end

local function CreateCVarSlider(parent, column, y, info)
    local slider = addon:CreateVideoSlider(parent, column, y, info, function(value)
        WriteCVar(info.key, value)
    end)
    sliders[info.key] = slider
    return slider
end

local function CreateCVarCheckbox(parent, y, cvar, label)
    local box = addon:CreateVideoCheckbox(parent, y, cvar, label, function(checked)
        WriteCVar(cvar, checked and 1 or 0)
    end)
    boxes[cvar] = box
    return box
end

-- An on/off box, then its sliders two to a row; nothing for an effect this client lacks
local function CreateEffect(parent, y, effect)
    if not Exists(effect.key) then
        return y
    end

    local controls = { box = CreateCVarCheckbox(parent, y, effect.key, effect.label), sliders = {} }
    y = y - 40
    local present = {}
    for _, info in ipairs(effect.sliders) do
        if Exists(info.key) then
            table.insert(present, info)
        end
    end
    for index, info in ipairs(present) do
        local column = (index - 1) % 2 + 1
        table.insert(controls.sliders, CreateCVarSlider(parent, column, y, info))
        if column == 2 or index == #present then
            y = y - 46
        end
    end
    effectControls[effect] = controls
    return y
end

-- Sliders two to a row, leaving out the ones this client lacks
local function CreateSliders(parent, y, list)
    local column = 1
    for _, info in ipairs(list) do
        if Exists(info.key) then
            CreateCVarSlider(parent, column, y, info)
            if column == 2 then
                y = y - 46
                column = 1
            else
                column = 2
            end
        end
    end
    if column == 2 then
        y = y - 46
    end
    return y
end

-- On/off boxes one below the other, leaving out the ones this client lacks
local function CreateCheckboxes(parent, y, list)
    for _, info in ipairs(list) do
        if Exists(info.key) then
            CreateCVarCheckbox(parent, y, info.key, info.label)
            y = y - 30
        end
    end
    return y
end

-- A client without this function has none of these CVars either
function PostProcessing.IsAvailable()
    return type(IsAmbientOcclusionAvailable) == "function"
end

function PostProcessing.CreateSettings(parent)
    local intro = "Effects on the rendered world, not on the interface. They apply as you move the controls, and Cancel puts the old values back."
    local y = -74
    for _, cvar in ipairs(FOG_AND_WATER_CVARS) do
        if Exists(cvar) then
            intro = intro .. "\n|cffffd100Volumetric fog and water have their own page: Fog & Water.|r"
            y = -86
            break
        end
    end
    addon:CreateVideoPageTitle(parent, "Post-Processing", intro)

    addon:CreateVideoHeader(parent, y, "Anti-aliasing (SMAA)")
    y = y - 34
    CreateCVarSlider(parent, 1, y, SMAA_SLIDER)
    y = y - 46

    addon:CreateVideoHeader(parent, y, "Upscaling")
    y = y - 16
    addon:CreateVideoNote(parent, y, "Draws the world smaller and scales it up, so the frame rate rises; the interface stays sharp. FSR 3.1 builds detail up over frames and also smooths edges, so it replaces SMAA and is worth using at 100%. It needs multisampling off, and with multisampling on the world stays at full size.")
    y = y - 58
    CreateCVarSlider(parent, 1, y, UPSCALER_SLIDER)
    y = y - 46
    CreateCVarSlider(parent, 1, y, RENDER_SCALE_SLIDER)
    CreateCVarSlider(parent, 2, y, SHARPNESS_SLIDER)
    y = y - 46

    addon:CreateVideoHeader(parent, y, "Ambient occlusion (GTAO)")
    y = y - 16
    gtaoNote = addon:CreateVideoNote(parent, y, "")
    y = y - 44

    gtaoSlider = CreateCVarSlider(parent, 1, y, GTAO_SLIDER)
    table.insert(gtaoDetails, CreateCVarSlider(parent, 2, y, GTAO_DETAIL_SLIDERS[1]))
    y = y - 46
    table.insert(gtaoDetails, CreateCVarSlider(parent, 1, y, GTAO_DETAIL_SLIDERS[2]))
    table.insert(gtaoDetails, CreateCVarSlider(parent, 2, y, GTAO_DETAIL_SLIDERS[3]))
    y = y - 36

    debugBox = addon:CreateVideoCheckbox(parent, y, GTAO_DEBUG_CVAR, "Show only the occlusion, to judge these settings",
        function(checked)
            WriteCVar(GTAO_DEBUG_CVAR, checked and 1 or 0)
        end)
    y = y - 40

    addon:CreateVideoHeader(parent, y, "Sun and shadows")
    y = y - 16
    depthNote = addon:CreateVideoNote(parent, y, "")
    y = y - 34
    y = CreateEffect(parent, y, SUN_RAYS)
    if Exists(CONTACT_SHADOWS.key) then
        addon:CreateVideoNote(parent, y + 6, "Contact shadows add the short shadows the shadow maps miss: at feet, at the foot of grass and under small props.")
        y = y - 26
        y = CreateEffect(parent, y, CONTACT_SHADOWS)
    end

    addon:CreateVideoHeader(parent, y, "Glow and colour")
    y = y - 16
    addon:CreateVideoNote(parent, y, "Bloom lets bright light glow softly into its surroundings and takes the place of the game's original glow; turned off, the original glow comes back. Colour grading adjusts exposure, contrast, saturation and warmth of the world.")
    y = y - 44
    y = CreateEffect(parent, y, BLOOM)
    y = CreateEffect(parent, y, GRADE)

    addon:CreateVideoHeader(parent, y, "World lighting")
    y = y - 16
    addon:CreateVideoNote(parent, y, "How lamps and the sun light the ground, building walls and grass. Lamps lit per pixel cast round pools of light at night. The shade sliders let sun shadows take away only the sunlight, so shaded ground keeps its colour, and soften the edge where surfaces turn away from the sun.")
    y = y - 58
    if Exists(PIXEL_LIGHTS_CVAR) then
        CreateCVarCheckbox(parent, y, PIXEL_LIGHTS_CVAR, "Lamps and fires light the ground and walls per pixel")
        y = y - 40
    end
    y = CreateSliders(parent, y, LIGHTING_SLIDERS)

    if Exists(SKY.key) or Exists(SUN_PATH.key) or Exists(DAY_NIGHT.key) then
        addon:CreateVideoHeader(parent, y, "Sky and sun")
        y = y - 16
        addon:CreateVideoNote(parent, y, "The sky's glow around the sun and the moon, sunlight shining through thin cloud, where the sun stands and how the day's colours turn to night. Glare is how much looking into the sun darkens the world (100% is the original).")
        y = y - 44
        y = CreateEffect(parent, y, SKY)
        y = CreateEffect(parent, y, SUN_PATH)
        y = CreateEffect(parent, y, DAY_NIGHT)
        y = CreateSliders(parent, y, { GLARE_SLIDER })
    end

    if Exists(SHADOW_CACHE.key) or Exists(SHADOW_SUN_SLIDERS[1].key) then
        addon:CreateVideoHeader(parent, y, "Shadow maps")
        y = y - 16
        addon:CreateVideoNote(parent, y, "How the sun's shadows follow the sun and the camera. The shadow light at the real sun height gives long shadows at dawn and dusk; the original raised it steeply. The boxes stop shadows sliding, crawling at their edges and blinking.")
        y = y - 44
        y = CreateSliders(parent, y, SHADOW_SUN_SLIDERS)
        y = CreateEffect(parent, y, SHADOW_CACHE)
        y = CreateCheckboxes(parent, y, SHADOW_BOXES)
        y = y - 10
    end

    if Exists(LAMPS.key) then
        addon:CreateVideoHeader(parent, y, "Lamps at night")
        y = y - 16
        addon:CreateVideoNote(parent, y, "Adds the night light Blizzard left out of many lamps, lanterns, torches and braziers. Turning it on or off reaches lamps as they load, after a teleport or a reload; brightness and reach change at once.")
        y = y - 44
        y = CreateEffect(parent, y, LAMPS)
        y = CreateCheckboxes(parent, y, {
            { key = LAMP_OBJECTS_CVAR, label = "Also on game objects and other models that are not map decor" },
        })
    end

    PostProcessing.VideoOptionsRefresh()
    return y
end

function PostProcessing.VideoOptionsRefresh()
    RememberValues()

    for cvar, slider in pairs(sliders) do
        slider:ShowStored(ReadNumber(cvar))
    end
    for cvar, box in pairs(boxes) do
        box:SetChecked(ReadNumber(cvar) ~= 0)
    end
    debugBox:SetChecked(ReadNumber(GTAO_DEBUG_CVAR) ~= 0)
    UpdateAvailability()
end

function PostProcessing.VideoOptionsOkay()
    RememberValues()
end

function PostProcessing.VideoOptionsCancel()
    for _, cvar in ipairs(CVARS) do
        if saved[cvar] ~= nil then
            SetCVar(cvar, saved[cvar])
        end
    end
end

function PostProcessing.VideoOptionsDefault()
    for _, cvar in ipairs(CVARS) do
        if Exists(cvar) then
            SetCVar(cvar, GetCVarDefault(cvar))
        end
    end
    RememberValues()
end

addon:RegisterModule("PostProcessing", PostProcessing)
