-- ============================================================
-- DC-QoS: Fog & Water Module
-- ============================================================
-- A page of the game's Video window (UI/VideoOptions.lua) for the native client's volumetric fog
-- (DarkChaosVolumetricFog, DarkChaos_Atmosphere) and water (DarkChaos_Water). They sat at the bottom
-- of the long Post-Processing page, where they were easy to miss. As there, the values are the
-- client's own CVars, saved in Config.wtf; the page applies as its controls move, and Cancel puts
-- back what it found. A client without these CVars (the old client, an exe older than them) never
-- gets the page.

local addon = DCQOS

local FogAndWater = {
    displayName = "Fog & Water",
}

local FOG_LEVELS = { [0] = "Off", "Low", "Medium", "High" }

local function FogLevel(value)
    return FOG_LEVELS[value] or tostring(value)
end

local function WholeYards(value)
    return string.format("%d yards", value)
end

local function Yards(value)
    return string.format("%.1f yards", value)
end

local function Percent(value)
    return string.format("%d%%", value * 100 + 0.5)
end

-- Volumetric fog: a quality, like the ambient occlusion, and its details while it is on. It reads the
-- world's depth. The ranges are the ones the client clamps to.
local FOG_SLIDER = {
    key = "dcVolumetricFog", label = "Quality", min = 0, max = 3, step = 1, format = FogLevel,
}
local FOG_DETAIL_SLIDERS = {
    { key = "dcVolumetricFogDensity", label = "Density", min = 0, max = 4, step = 0.05, format = Percent },
    { key = "dcVolumetricFogMist", label = "Ground mist", min = 0, max = 4, step = 0.05, format = Percent },
    { key = "dcVolumetricFogSun", label = "Sunlight in the fog", min = 0, max = 4, step = 0.05, format = Percent },
    { key = "dcVolumetricFogLights", label = "Lamplight in the fog", min = 0, max = 4, step = 0.05, format = Percent },
    { key = "dcVolumetricFogDistance", label = "Reach", min = 50, max = 1500, step = 50, format = WholeYards },
    { key = "dcVolumetricFogTemporal", label = "Smoothing over frames", min = 0, max = 0.95, step = 0.05, format = Percent },
    -- WoW Forever's fog light is authored for HDR; this takes it down where it clips to white
    { key = "dcVolumetricFogForeverBrightness", label = "Brightness", min = 0.3, max = 1.5, step = 0.05, format = Percent },
}
local FOG_SHAFTS_CVAR = "dcVolumetricFogShafts"
-- WoW Forever's fog model (1, the default) or the earlier haze and ground mist (0); the reach is WoW Forever's own
-- under its model, so the Reach slider only matters for the haze
local FOG_FOREVER_CVAR = "dcVolumetricFogForever"
local FOG_REACH_CVAR = "dcVolumetricFogDistance"
-- WoW Forever's sun, ambient and sky colours for the zones of map 751 (the native client overrides its light tables)
local LIGHT_CVAR = "dcForeverLight"

-- Water: waves, reflections, foam and wakes on lakes, rivers and the sea; an on/off box and its sliders, and whether it
-- is drawn as WoW Forever's PBR water where that can run
local WATER_CVAR = "dcWater"
local WATER_PBR_CVAR = "dcWaterPbr"
-- Cataclysm's lava and slime: three moving layers over a drifting noise, in place of the 3.3.5 ones
local MAGMA_CVAR = "dcLiquidMagma"
local WATER_SLIDERS = {
    { key = "dcWaterWaves", label = "Wave height", min = 0, max = 2, step = 0.05, format = Percent },
    { key = "dcWaterReflections", label = "Reflections", min = 0, max = 2, step = 0.05, format = Percent },
    { key = "dcWaterFoam", label = "Foam", min = 0, max = 2, step = 0.05, format = Percent },
    { key = "dcWaterWakes", label = "Wakes", min = 0, max = 2, step = 0.05, format = Percent },
    -- WoW Forever's water only: its scattered and reflected light
    { key = "dcWaterPbrBrightness", label = "Brightness", min = 0.2, max = 1.5, step = 0.05, format = Percent },
    { key = "dcWaterPbrMirror", label = "Sky mirrored far out", min = 0, max = 1, step = 0.05, format = Percent },
    { key = "dcWaterPbrShore", label = "Shore fade", min = 0.5, max = 6, step = 0.5, format = Yards },
    -- Lamps, torches and fires nearby: their reflections in the water and their light on its foam
    { key = "dcWaterLamps", label = "Lamps and fires", min = 0, max = 2, step = 0.05, format = Percent },
}

local CVARS = { FOG_SLIDER.key, FOG_SHAFTS_CVAR, FOG_FOREVER_CVAR, LIGHT_CVAR, WATER_CVAR, WATER_PBR_CVAR, MAGMA_CVAR }
for _, list in ipairs({ FOG_DETAIL_SLIDERS, WATER_SLIDERS }) do
    for _, info in ipairs(list) do
        table.insert(CVARS, info.key)
    end
end

local sliders = {}          -- cvar -> slider
local boxes = {}            -- cvar -> check box
local fogSlider, fogNote
local fogDetails = {}       -- the fog's sliders and its shafts box, usable while it is on
local waterDetails = {}     -- the water's sliders, usable while it is on
local saved = {}

local function ReadNumber(cvar)
    return tonumber(GetCVar(cvar)) or 0
end

-- GetCVar answers nil for a CVar the client does not know, and SetCVar throws on one, so a control
-- whose CVar is missing is left out and Cancel and Defaults pass it by.
local function Exists(cvar)
    return GetCVar(cvar) ~= nil
end

local function RememberValues()
    for _, cvar in ipairs(CVARS) do
        saved[cvar] = GetCVar(cvar)
    end
end

local function UpdateAvailability()
    if fogSlider then
        local available = IsAmbientOcclusionAvailable()
        local fogOn = available and ReadNumber(FOG_SLIDER.key) > 0
        addon:SetVideoControlEnabled(fogSlider, available)
        for _, control in ipairs(fogDetails) do
            addon:SetVideoControlEnabled(control, fogOn)
        end
        if sliders[FOG_REACH_CVAR] and Exists(FOG_FOREVER_CVAR) then
            addon:SetVideoControlEnabled(sliders[FOG_REACH_CVAR], fogOn and ReadNumber(FOG_FOREVER_CVAR) == 0)
        end
        if available then
            fogNote:SetText("Mist along the ground and haze in the distance, lit by the zone's fog colour, the sun (with shafts where the sun's shadows fall) and nearby lamps.")
        else
            fogNote:SetText("|cffff8080Unavailable on this device: the fog needs the world's depth. If multisampling is on, turn it off on the Resolution page and reopen this window.|r")
        end
    end

    local waterOn = ReadNumber(WATER_CVAR) ~= 0
    for _, slider in ipairs(waterDetails) do
        addon:SetVideoControlEnabled(slider, waterOn)
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

-- Sliders two to a row after the first `column - 1` places, leaving out the ones this client lacks.
-- Each lands in `into`; returns the y below the last row.
local function CreateSliderRows(parent, y, column, list, into)
    for _, info in ipairs(list) do
        if Exists(info.key) then
            table.insert(into, CreateCVarSlider(parent, column, y, info))
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

-- The native client: IsAmbientOcclusionAvailable, and at least one of the two effects
function FogAndWater.IsAvailable()
    return type(IsAmbientOcclusionAvailable) == "function" and (Exists(FOG_SLIDER.key) or Exists(WATER_CVAR))
end

function FogAndWater.CreateSettings(parent)
    addon:CreateVideoPageTitle(parent, "Fog & Water",
        "The world's fog and water. They apply as you move the controls, and Cancel puts the old values back.")

    local y = -74
    if Exists(FOG_SLIDER.key) then
        addon:CreateVideoHeader(parent, y, "Volumetric fog")
        y = y - 16
        fogNote = addon:CreateVideoNote(parent, y, "")
        y = y - 44
        fogSlider = CreateCVarSlider(parent, 1, y, FOG_SLIDER)
        y = CreateSliderRows(parent, y, 2, FOG_DETAIL_SLIDERS, fogDetails)
        if Exists(FOG_SHAFTS_CVAR) then
            table.insert(fogDetails, CreateCVarCheckbox(parent, y + 6, FOG_SHAFTS_CVAR, "Sun shafts through the fog, where the sun's shadows fall"))
            y = y - 34
        end
        if Exists(FOG_FOREVER_CVAR) then
            table.insert(fogDetails, CreateCVarCheckbox(parent, y + 6, FOG_FOREVER_CVAR, "WoW Forever's fog where the zone has it"))
            y = y - 30
            addon:CreateVideoNote(parent, y + 6, "Its sun haze, horizon and near fog for each zone and time of day. Off: the earlier haze and ground mist, whose reach the Reach slider sets.")
            y = y - 34
        end
        y = y - 10
    end

    if Exists(LIGHT_CVAR) then
        addon:CreateVideoHeader(parent, y, "Zone lighting")
        y = y - 24
        CreateCVarCheckbox(parent, y, LIGHT_CVAR, "WoW Forever's sun, ambient and sky colours in the Plaguelands map's zones")
        y = y - 40
    end

    if Exists(WATER_CVAR) then
        addon:CreateVideoHeader(parent, y, "Water")
        y = y - 16
        addon:CreateVideoNote(parent, y, "Waves that move on the sea and ripple on lakes, the sky and the sun mirrored in the water, foam on crests and shores, and wakes behind you and those swimming near you. Turned off, the water is the original.")
        y = y - 44
        CreateCVarCheckbox(parent, y, WATER_CVAR, "Water with moving waves, sky reflections, foam and wakes")
        y = y - 40
        y = CreateSliderRows(parent, y, 1, WATER_SLIDERS, waterDetails)
        if Exists(WATER_PBR_CVAR) then
            table.insert(waterDetails, CreateCVarCheckbox(parent, y + 6, WATER_PBR_CVAR, "WoW Forever's water where it can run"))
            y = y - 30
            addon:CreateVideoNote(parent, y + 6, "Each lake, river and sea in WoW Forever's style, with its foam and the ground seen through the water. Under water, or with multisampling on, the water above draws instead.")
            y = y - 34
        end
    end

    -- Its own box: lava and slime are not the water, and do not wait on its switch
    if Exists(MAGMA_CVAR) then
        CreateCVarCheckbox(parent, y + 6, MAGMA_CVAR, "Cataclysm's lava and slime")
        y = y - 30
        addon:CreateVideoNote(parent, y + 6, "Three layers that move over each other, the way Cataclysm draws them. Off: the single scrolling texture of 3.3.5.")
        y = y - 34
    end

    FogAndWater.VideoOptionsRefresh()
    return y
end

function FogAndWater.VideoOptionsRefresh()
    RememberValues()

    for cvar, slider in pairs(sliders) do
        slider:ShowStored(ReadNumber(cvar))
    end
    for cvar, box in pairs(boxes) do
        box:SetChecked(ReadNumber(cvar) ~= 0)
    end
    UpdateAvailability()
end

function FogAndWater.VideoOptionsOkay()
    RememberValues()
end

function FogAndWater.VideoOptionsCancel()
    for _, cvar in ipairs(CVARS) do
        if saved[cvar] ~= nil then
            SetCVar(cvar, saved[cvar])
        end
    end
end

function FogAndWater.VideoOptionsDefault()
    for _, cvar in ipairs(CVARS) do
        if Exists(cvar) then
            SetCVar(cvar, GetCVarDefault(cvar))
        end
    end
    RememberValues()
end

addon:RegisterModule("FogAndWater", FogAndWater)
