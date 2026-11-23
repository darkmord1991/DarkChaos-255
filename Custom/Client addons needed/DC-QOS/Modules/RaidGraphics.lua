-- ============================================================
-- DC-QoS: Raid Profile Module
-- ============================================================
-- A page of the game's Video window (UI/VideoOptions.lua) for the native client's raid graphics
-- profile: lighter settings the client switches to before a raid or battleground map loads, and
-- back from before the next map loads. The values are the client's own CVars: raidGraphics, and
-- <setting>Raid for each setting GetRaidGraphicsSettings lists, where an empty value leaves that
-- setting at its normal value. Like Graphics+, the page edits a copy and Okay or Apply write what
-- changed: inside a raid a changed value applies at once, and a farther farclip loads behind a
-- loading screen, so nothing may apply while a slider moves. The old client has none of this and
-- never gets the page.

local addon = DCQOS

local RaidGraphics = {
    displayName = "Raid Profile",
}

local ENABLE_CVAR = "raidGraphics"
local SUFFIX = "Raid"

-- The client's defaults, for a client whose GetCVarDefault does not answer
local DEFAULTS = {
    raidGraphics = "0",
    farclipRaid = "1000",
    horizonFarclipScaleRaid = "4",
    environmentDetailRaid = "1",
    groundEffectDensityRaid = "32",
    groundEffectDistRaid = "70",
    particleDensityRaid = "0.6",
    spellEffectLevelRaid = "",
    extShadowQualityRaid = "2",
    projectedTexturesRaid = "1",
    dcGtaoRaid = "0",
    dcSunRaysRaid = "",
}

local function Whole(value)
    return string.format("%d", value)
end

local function Tenths(value)
    return string.format("%.1f", value)
end

local function Percent(value)
    return string.format("%d%%", value * 100 + 0.5)
end

local GTAO_LEVELS = { [0] = "Off", "Low", "Medium", "High" }
local function GtaoLevel(value)
    return GTAO_LEVELS[value] or tostring(value)
end

-- A control for each setting the client can swap. The sliders take Graphics+'s range where it has
-- the setting, the Effects page's where it does not, and Post-Processing's for ambient occlusion.
-- A setting this list lacks (a newer client) gets no control and is left alone.
local CONTROLS = {
    farclip = { label = "Farclip", min = 100, max = 3831, step = 25, format = Whole },
    horizonFarclipScale = { label = "Horizon Scale", min = 1, max = 12, step = 0.5, format = Tenths },
    environmentDetail = { label = "Environment Detail", min = 0.5, max = 6, step = 0.1, format = Tenths },
    groundEffectDensity = { label = "Ground Clutter Density", min = 16, max = 64, step = 8, format = Whole },
    groundEffectDist = { label = "Grass Distance", min = 70, max = 280, step = 10, format = Whole },
    particleDensity = { label = "Particle Density", min = 0.1, max = 1, step = 0.1, format = Percent },
    spellEffectLevel = { label = "Spell Detail", min = 0, max = 9, step = 1, format = Whole },
    extShadowQuality = { label = "Shadow Quality", min = 0, max = 4, step = 1, format = Whole },
    projectedTextures = { label = "Projected Textures", checkbox = true },
    dcGtao = { label = "Ambient Occlusion", min = 0, max = 3, step = 1, format = GtaoLevel },
    dcSunRays = { label = "Sun Rays", checkbox = true },
}

local rows = {}       -- { base, cvar, info, control, keep } in the client's order
local opened = {}     -- cvar -> value when the page last read it
local pending = {}    -- cvar -> value Okay writes ("" = keep the normal value)
local shown = {}      -- cvar -> what the control shows (number, or boolean for a box)
local enableBox, statusText

local function Exists(cvar)
    return GetCVar(cvar) ~= nil
end

local function Same(a, b)
    if a == b then
        return true
    end
    local x, y = tonumber(a), tonumber(b)
    return x ~= nil and x == y
end

local function DefaultFor(cvar)
    if type(GetCVarDefault) == "function" then
        local ok, value = pcall(GetCVarDefault, cvar)
        if ok and type(value) == "string" then
            return value
        end
    end
    return DEFAULTS[cvar]
end

local function IsActive()
    return type(IsRaidGraphicsActive) == "function" and IsRaidGraphicsActive() and true or false
end

local function MarkChanged()
    VideoOptionsFrameApply:Enable()
end

-- The highest shadow quality this device takes, as the client reports it
local function SliderMax(base, info)
    if base == "extShadowQuality" and type(GetCVarMax) == "function" then
        local ok, value = pcall(GetCVarMax, base)
        if ok and tonumber(value) then
            return tonumber(value)
        end
    end
    return info.max
end

-- What a control shows for a value: the raid value, or for "keep normal" the normal value, which
-- the setting's own CVar holds whenever the profile does not swap it.
local function ValueToShow(row, value)
    if value == "" then
        value = GetCVar(row.base)
    end
    local number = tonumber(value)
    if row.info.checkbox then
        return number ~= nil and number ~= 0
    end
    return number or row.info.min
end

local function ShowRow(row)
    local keep = pending[row.cvar] == ""
    local value = ValueToShow(row, pending[row.cvar])
    shown[row.cvar] = value
    if row.info.checkbox then
        row.control:SetChecked(value)
    else
        row.control:ShowStored(value)
    end
    row.keep:SetChecked(keep)
    addon:SetVideoControlEnabled(row.control, not keep)
end

local function UpdateStatus()
    if IsActive() then
        statusText:SetText("|cff40ff40Active now:|r you are in a raid or battleground and these settings are in use.")
    elseif GetCVar(ENABLE_CVAR) == "1" then
        statusText:SetText("Not active now: the profile takes over when you next enter a raid or battleground.")
    else
        statusText:SetText("|cff999999Off:|r raids and battlegrounds use your normal settings.")
    end
end

-- Ticking keeps the setting at its normal value; the control keeps showing its value, greyed, so
-- that unticking takes that value back.
local function CreateKeepBox(parent, y, row)
    return addon:CreateVideoCheckbox(parent, y, row.cvar .. "Keep", "Keep normal", function(checked)
        if checked then
            pending[row.cvar] = ""
        elseif row.info.checkbox then
            pending[row.cvar] = shown[row.cvar] and "1" or "0"
        else
            pending[row.cvar] = tostring(shown[row.cvar])
        end
        addon:SetVideoControlEnabled(row.control, not checked)
        MarkChanged()
    end, 2)
end

local function CreateRow(parent, y, base, info)
    local row = { base = base, cvar = base .. SUFFIX, info = info }
    local cvar = row.cvar

    if info.checkbox then
        row.control = addon:CreateVideoCheckbox(parent, y, cvar, info.label, function(checked)
            pending[cvar] = checked and "1" or "0"
            shown[cvar] = checked
            MarkChanged()
        end)
        row.keep = CreateKeepBox(parent, y, row)
        y = y - 30
    else
        local sliderInfo = {
            key = cvar, label = info.label, min = info.min, max = SliderMax(base, info), step = info.step,
            format = info.format,
        }
        row.control = addon:CreateVideoSlider(parent, 1, y, sliderInfo, function(value)
            pending[cvar] = tostring(value)
            shown[cvar] = value
            MarkChanged()
        end)
        -- level with the slider's bar, below its label
        row.keep = CreateKeepBox(parent, y + 4, row)
        y = y - 46
    end

    table.insert(rows, row)
    return y
end

local function WriteIfChanged(cvar)
    if pending[cvar] ~= nil and not Same(pending[cvar], opened[cvar]) then
        SetCVar(cvar, pending[cvar])
    end
end

function RaidGraphics.IsAvailable()
    return type(GetRaidGraphicsSettings) == "function" and GetCVar(ENABLE_CVAR) ~= nil
end

function RaidGraphics.CreateSettings(parent)
    addon:CreateVideoPageTitle(parent, "Raid Profile",
        "Lighter settings for raids and battlegrounds. The client switches to them before a raid or battleground loads and back to your normal settings before the next map loads, and Config.wtf always keeps the normal values.")

    local y = -84
    enableBox = addon:CreateVideoCheckbox(parent, y, ENABLE_CVAR, "Use the raid profile in raids and battlegrounds",
        function(checked)
            pending[ENABLE_CVAR] = checked and "1" or "0"
            MarkChanged()
        end)
    y = y - 30
    statusText = addon:CreateVideoNote(parent, y, "")
    y = y - 30
    addon:CreateVideoNote(parent, y, "While the profile is active, a change to one of these settings on Graphics+, Effects or Post-Processing goes into the raid profile, and your normal settings come back when you leave.")
    y = y - 44

    addon:CreateVideoHeader(parent, y, "Settings")
    y = y - 16
    addon:CreateVideoNote(parent, y, "Keep normal leaves a setting at your normal value inside raids and battlegrounds.")
    y = y - 40

    for _, base in ipairs(GetRaidGraphicsSettings() or {}) do
        local info = CONTROLS[base]
        if info and Exists(base .. SUFFIX) and Exists(base) then
            y = CreateRow(parent, y, base, info)
        end
    end

    RaidGraphics.VideoOptionsRefresh()
    return y - 10
end

function RaidGraphics.VideoOptionsRefresh()
    opened = { [ENABLE_CVAR] = GetCVar(ENABLE_CVAR) }
    for _, row in ipairs(rows) do
        opened[row.cvar] = GetCVar(row.cvar)
    end
    pending = {}
    for cvar, value in pairs(opened) do
        pending[cvar] = value
    end

    enableBox:SetChecked(opened[ENABLE_CVAR] == "1")
    for _, row in ipairs(rows) do
        ShowRow(row)
    end
    UpdateStatus()
end

-- Only what changed on this page: while the profile is active, a change on another page was
-- adopted into these CVars after this page read them, and its Okay ran before this one.
-- Switching on goes last and switching off first, so that inside a raid the values apply once.
function RaidGraphics.VideoOptionsOkay()
    local turningOff = pending[ENABLE_CVAR] == "0"
    if turningOff then
        WriteIfChanged(ENABLE_CVAR)
    end
    for _, row in ipairs(rows) do
        WriteIfChanged(row.cvar)
    end
    if not turningOff then
        WriteIfChanged(ENABLE_CVAR)
    end
    RaidGraphics.VideoOptionsRefresh()
end

-- Nothing on this page applies before Okay, and opening the window reads the CVars again
function RaidGraphics.VideoOptionsCancel()
end

-- The defaults are written at once, like the other pages', the switch first: it is off by default.
function RaidGraphics.VideoOptionsDefault()
    local cvars = { ENABLE_CVAR }
    for _, row in ipairs(rows) do
        table.insert(cvars, row.cvar)
    end
    for _, cvar in ipairs(cvars) do
        local value = DefaultFor(cvar)
        if value ~= nil and not Same(GetCVar(cvar), value) then
            SetCVar(cvar, value)
        end
    end
    RaidGraphics.VideoOptionsRefresh()
end

addon:RegisterModule("RaidGraphics", RaidGraphics)
