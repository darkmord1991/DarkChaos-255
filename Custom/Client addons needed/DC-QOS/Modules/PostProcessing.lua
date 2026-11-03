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

local GTAO_DEBUG_CVAR = "dcGtaoDebug"
local CVARS = { "dcSmaa", "dcGtao", "dcGtaoRadius", "dcGtaoStrength", "dcGtaoDistance", GTAO_DEBUG_CVAR,
    "dcUpscaler", "dcRenderScale", "dcFsrSharpness" }

local sliders = {}
local gtaoSlider, gtaoNote, debugBox
local gtaoDetails = {}
local saved = {}

local function ReadNumber(cvar)
    return tonumber(GetCVar(cvar)) or 0
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
    else
        gtaoNote:SetText("|cffff8080Unavailable on this device. If multisampling is on, turn it off on the Resolution page and reopen this window.|r")
    end

    addon:SetVideoControlEnabled(gtaoSlider, available)
    for _, slider in ipairs(gtaoDetails) do
        addon:SetVideoControlEnabled(slider, active)
    end
    addon:SetVideoControlEnabled(debugBox, active)
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

-- A client without this function has none of these CVars either
function PostProcessing.IsAvailable()
    return type(IsAmbientOcclusionAvailable) == "function"
end

function PostProcessing.CreateSettings(parent)
    addon:CreateVideoPageTitle(parent, "Post-Processing",
        "Effects on the rendered world, not on the interface. They apply as you move the controls, and Cancel puts the old values back.")

    local y = -74
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

    PostProcessing.VideoOptionsRefresh()
    return y - 34
end

function PostProcessing.VideoOptionsRefresh()
    RememberValues()

    for cvar, slider in pairs(sliders) do
        slider:ShowStored(ReadNumber(cvar))
    end
    debugBox:SetChecked(ReadNumber(GTAO_DEBUG_CVAR) ~= 0)
    UpdateAvailability()
end

function PostProcessing.VideoOptionsOkay()
    RememberValues()
end

function PostProcessing.VideoOptionsCancel()
    for _, cvar in ipairs(CVARS) do
        SetCVar(cvar, saved[cvar])
    end
end

function PostProcessing.VideoOptionsDefault()
    for _, cvar in ipairs(CVARS) do
        SetCVar(cvar, GetCVarDefault(cvar))
    end
    RememberValues()
end

addon:RegisterModule("PostProcessing", PostProcessing)
