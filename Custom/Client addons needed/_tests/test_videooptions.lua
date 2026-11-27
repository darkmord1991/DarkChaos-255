--[[
    The DC-QOS pages in the game's Video window (UI/VideoOptions.lua, Modules/GraphicsPlus.lua,
    Modules/PostProcessing.lua, Modules/FogAndWater.lua, Modules/RaidGraphics.lua) on the strict 3.3.5a client. The window's own code is the real
    FrameXML (OptionsFrameTemplates, OptionsPanelTemplates, VideoOptionsFrame, VideoOptionsPanels),
    so Okay, Cancel, Apply and Defaults run as they do in game; only the XML frames are stand-ins.
    test_videooptions_old.lua runs the old client's side of this file: no Post-Processing page, no Fog & Water.

    Run from this directory:  lua test_videooptions.lua        (-v prints every check)
]]

dofile("talents_sim.lua")
dofile("talents_client.lua")
local T = dofile("talents_testlib.lua")
local CLIENT = SIM.client
local ok, section, noNewErrors = T.ok, T.section, T.noNewErrors

-- ----------------------------------------------------------------------------
-- The native client
-- ----------------------------------------------------------------------------

local POST_DEFAULTS = {
    dcSmaa = "0",
    dcGtao = "0",
    dcGtaoRadius = "1.5",
    dcGtaoStrength = "0.7",
    dcGtaoDistance = "120",
    dcGtaoDebug = "0",
    dcRenderScale = "100",
    dcFsrSharpness = "0.5",
    -- the client's defaults for the effects of 2026-11-03 and 11-11 (DarkChaosSunRays, DarkChaosContactShadows,
    -- DarkChaosBloom, DarkChaosGrade, DarkChaos_SurfaceLight)
    dcSunRays = "1",
    dcSunRaysStrength = "0.6",
    dcContactShadows = "1",
    dcContactShadowsLength = "0.8",
    dcContactShadowsStrength = "0.5",
    dcBloom = "1",
    dcBloomStrength = "1",
    dcBloomThreshold = "0.6",
    dcGrade = "1",
    dcGradeExposure = "0",
    dcGradeContrast = "0.15",
    dcGradeSaturation = "1.05",
    dcGradeWarmth = "0",
    dcPixelLights = "1",
    dcShadowSunOnly = "1",
    dcLightWrap = "0.2",
    -- the sky, sun path, shadow map and lamp light CVars of 2026-11-03 (DayNightRender, DayNight, World, ShadowQuery,
    -- ShadowCache, DarkChaosLampLights)
    dcSky = "1",
    dcSkyGlow = "0.35",
    dcSkyGlowHorizon = "0.8",
    dcSkyGlowSize = "50",
    dcSkyCloudSun = "1",
    dcSkyDither = "1",
    dcSunPath = "1",
    dcDayNightSmooth = "1",
    dcSunGlareDim = "0",
    dcShadowSunHeight = "1",
    dcShadowSunMin = "15",
    dcShadowSunCache = "1",
    dcShadowSunRefresh = "0.5",
    dcShadowTexelSnap = "1",
    dcShadowCasterFade = "1",
    dcShadowBillboard = "1",
    dcShadowBandStagger = "1",
    dcLampLights = "1",
    dcLampLightsIntensity = "1",
    dcLampLightsRange = "8",
    dcLampLightsObjects = "0",
    -- the volumetric fog and the water of 2026-11-21 (DarkChaosVolumetricFog, DarkChaos_Water), on their own page
    dcVolumetricFog = "0",
    dcVolumetricFogDensity = "1",
    dcVolumetricFogMist = "1",
    dcVolumetricFogSun = "1",
    dcVolumetricFogLights = "1",
    dcVolumetricFogShafts = "1",
    dcVolumetricFogTemporal = "0.85",
    dcVolumetricFogDistance = "400",
    dcVolumetricFogForever = "1",
    dcForeverLight = "1",
    dcVolumetricFogForeverBrightness = "0.85",
    dcWater = "0",
    dcWaterWaves = "1",
    dcWaterFoam = "1",
    dcWaterReflections = "1",
    dcWaterWakes = "1",
    dcWaterPbr = "1",
    dcWaterPbrBrightness = "1",
    dcWaterPbrMirror = "1",
    dcWaterPbrShore = "2",
    dcWaterLamps = "1",
    dcLiquidMagma = "1",
}

-- test_videooptions_olderexe.lua: a native exe older than the addon, which lacks these CVars
local MISSING = rawget(_G, "MISSING_CVARS") or {}
local hasContact = not MISSING.dcContactShadows
local hasFog = not MISSING.dcVolumetricFog and not MISSING.dcWater

-- The raid graphics profile (2026-11-21): raidGraphics, and a <setting>Raid CVar for each setting the client swaps
-- in raids and battlegrounds, in GetRaidGraphicsSettings' order. The old client and an exe without it
-- (test_videooptions_olderexe.lua) have none of this, and get no Raid Profile page.
local RAID_SETTINGS = { "farclip", "horizonFarclipScale", "environmentDetail", "groundEffectDensity", "groundEffectDist",
    "particleDensity", "spellEffectLevel", "extShadowQuality", "projectedTextures", "dcGtao", "dcSunRays" }
local RAID_DEFAULTS = {
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
local hasRaid = not OLD_CLIENT and not MISSING.raidGraphics

local STOCK_DEFAULTS = {
    farclip = "1277",
    environmentDetail = "1",
    groundEffectDist = "70",
    -- the other stock CVars the raid profile swaps
    horizonFarclipScale = "4",
    groundEffectDensity = "16",
    particleDensity = "1",
    spellEffectLevel = "9",
    extShadowQuality = "3",
    projectedTextures = "0",
}

for name, value in pairs(STOCK_DEFAULTS) do
    CLIENT.cvars[name] = value
end

function GetCVarDefault(name)
    return POST_DEFAULTS[name] or STOCK_DEFAULTS[name] or RAID_DEFAULTS[name]
end

-- Script_GetCVarMin and Script_GetCVarMax know farclip's stock range and the device's highest shadow quality
function GetCVarMin(name)
    return name == "farclip" and 177 or nil
end

function GetCVarMax(name)
    if name == "extShadowQuality" then
        return 5
    end
    return name == "farclip" and 1277 or nil
end

local stockSetCVar = SetCVar
local farclipWrites = {}
local raidWrites = {}

-- The client's raid profile: applied on entering a raid with raidGraphics on, restored on leaving. While it is
-- applied, a write to a swapped CVar is adopted into its <setting>Raid, and a write to <setting>Raid or raidGraphics
-- takes effect at once. raid.normal holds the normal value of each swapped setting.
local raid = { inside = false, active = false, normal = {} }
local RAID_BASE = {}
for _, base in ipairs(RAID_SETTINGS) do
    RAID_BASE[base .. "Raid"] = base
end

local function ApplyRaidProfile()
    for _, base in ipairs(RAID_SETTINGS) do
        local value = CLIENT.cvars[base .. "Raid"]
        if value ~= nil and value ~= "" then
            raid.normal[base] = CLIENT.cvars[base]
            stockSetCVar(base, value)
        end
    end
    raid.active = true
end

local function RestoreNormalProfile()
    for base, value in pairs(raid.normal) do
        stockSetCVar(base, value)
    end
    raid.normal = {}
    raid.active = false
end

local function RaidAfterSet(name, value)
    value = value ~= nil and tostring(value) or nil
    if name == "raidGraphics" then
        if raid.inside and value == "1" and not raid.active then
            ApplyRaidProfile()
        elseif raid.active and value ~= "1" then
            RestoreNormalProfile()
        end
    elseif RAID_BASE[name] and raid.active then
        local base = RAID_BASE[name]
        if value ~= "" then
            if raid.normal[base] == nil then
                raid.normal[base] = CLIENT.cvars[base]
            end
            stockSetCVar(base, value)
        elseif raid.normal[base] ~= nil then
            stockSetCVar(base, raid.normal[base])
            raid.normal[base] = nil
        end
    elseif raid.active and raid.normal[name] ~= nil then
        stockSetCVar(name .. "Raid", value)
    end
end

function SetCVar(name, value, ...)
    if name == "farclip" then
        farclipWrites[#farclipWrites + 1] = tonumber(value)
    end
    if OLD_CLIENT then
        -- The stock SetCVar throws on a name it does not know
        assert(POST_DEFAULTS[name] == nil and RAID_DEFAULTS[name] == nil, "Couldn't find CVar named '" .. tostring(name) .. "'")
    end
    if MISSING[name] or (MISSING.raidGraphics and RAID_DEFAULTS[name] ~= nil) then
        error("Couldn't find CVar named '" .. tostring(name) .. "'")
    end
    if RAID_DEFAULTS[name] ~= nil then
        raidWrites[#raidWrites + 1] = name .. "=" .. tostring(value)
    end
    local results = { stockSetCVar(name, value, ...) }
    if hasRaid then
        RaidAfterSet(name, value)
    end
    return unpack(results)
end

if hasRaid then
    for name, value in pairs(RAID_DEFAULTS) do
        CLIENT.cvars[name] = value
    end

    function IsRaidGraphicsActive()
        return raid.active
    end

    function GetRaidGraphicsSettings()
        local list = {}
        for index, base in ipairs(RAID_SETTINGS) do
            list[index] = base
        end
        return list
    end
end

-- The loading screen of a raid or battleground: the client applies the profile before the map loads
local function EnterRaid()
    raid.inside = true
    if CLIENT.cvars.raidGraphics == "1" then
        ApplyRaidProfile()
    end
    SIM.FireEvent("PLAYER_ENTERING_WORLD")
    SIM.FireEvent("ZONE_CHANGED_NEW_AREA")
    SIM.Run(1)
end

local function LeaveRaid()
    raid.inside = false
    if raid.active then
        RestoreNormalProfile()
    end
    SIM.FireEvent("PLAYER_ENTERING_WORLD")
    SIM.FireEvent("ZONE_CHANGED_NEW_AREA")
    SIM.Run(1)
end

local depthReadable = true
local native = {}

if not OLD_CLIENT then
    for name, value in pairs(POST_DEFAULTS) do
        if not MISSING[name] then
            CLIENT.cvars[name] = value
        end
    end

    function IsAmbientOcclusionAvailable()
        return depthReadable
    end

    function SetGrassDistance(value)
        native.grass = value
        return SetCVar("groundEffectDist", value)
    end
end

-- The natives the DLL and the native client share, which write these CVars
function SetExtendedFarclip(value)
    return SetCVar("farclip", value)
end

function SetEnvironmentDetail(value)
    return SetCVar("environmentDetail", value)
end

for _, name in ipairs({ "SetExtendedCameraDistance", "SetHorizonScale", "SetTextureQuality", "SetRenderFlags",
    "SetDoodadFadeDistance" }) do
    _G[name] = function(...)
        native[name] = { ... }
        return true
    end
end

function SetDoodadFadeCategoryDistance(index, value)
    native.doodads = native.doodads or {}
    native.doodads[index + 1] = value
    return true
end

function RestoreVideoEffectsDefaults()
    SetCVar("farclip", STOCK_DEFAULTS.farclip)
    SetCVar("environmentDetail", STOCK_DEFAULTS.environmentDetail)
    SetCVar("groundEffectDist", STOCK_DEFAULTS.groundEffectDist)
end

function StaticPopup_Show()
end

function RestartGx()
end

-- ----------------------------------------------------------------------------
-- The Video window: real FrameXML code on stand-ins for its XML
-- ----------------------------------------------------------------------------

InterfaceOptionsFramePanelContainer = CreateFrame("Frame", "InterfaceOptionsFramePanelContainer", UIParent)

function InterfaceOptions_AddCategory()
end

local window = CreateFrame("Frame", "VideoOptionsFrame", UIParent)
window:Hide()
window:CreateFontString("VideoOptionsFrameHeaderText", "ARTWORK", "GameFontNormal")

local categoryFrame = CreateFrame("Frame", "VideoOptionsFrameCategoryFrame", window)
categoryFrame.buttons = {}
categoryFrame.update = function(self)
    for index, element in ipairs(window.categoryList or {}) do
        self.buttons[index] = self.buttons[index] or CreateFrame("Button", "VideoCategoryButton" .. index, self)
        self.buttons[index].element = element
        self.buttons[index]:SetScript("OnClick", function(button)
            OptionsList_DisplayPanel(button.element)
        end)
    end
end

CreateFrame("Frame", "VideoOptionsFramePanelContainer", window)

for _, name in ipairs({ "Okay", "Cancel", "Apply", "Defaults" }) do
    CreateFrame("Button", "VideoOptionsFrame" .. name, window)
end

VideoOptionsFrameApply:SetScript("OnClick", function(self, button)
    VideoOptionsFrameOkay_OnClick(self, button, true)
    self:Disable()
end)
VideoOptionsFrameOkay:SetScript("OnClick", function(self, button)
    VideoOptionsFrameOkay_OnClick(self, button)
end)
VideoOptionsFrameCancel:SetScript("OnClick", function(self, button)
    VideoOptionsFrameCancel_OnClick(self, button)
end)

for _, file in ipairs({ "OptionsFrameTemplates.lua", "OptionsPanelTemplates.lua", "VideoOptionsFrame.lua",
    "VideoOptionsPanels.lua" }) do
    SIM.LoadFile(SIM.FRAMEXML .. file, "FrameXML", {})
end

VideoOptionsFrame_OnLoad(window)
window:SetScript("OnShow", OptionsFrame_OnShow)
window:SetScript("OnHide", VideoOptionsFrame_OnHide)
VideoOptionsFrameApply:SetScript("OnShow", function(self)
    self:Disable()
end)

-- The Effects page with the two sliders that share values with Graphics+, as its XML builds them
local effects = CreateFrame("Frame", "VideoOptionsEffectsPanel", VideoOptionsFramePanelContainer)
effects:Hide()
VideoOptionsEffectsPanelQualitySlider = {}
VideoOptionsEffectsPanel_UpdateVideoQuality = function()
end
VideoOptionsEffectsPanel_FixupQualityLevels = function()
end
IsPlayerResolutionAvailable = function()
    return true
end

local function StockSlider(name, cvar, low, high)
    local slider = CreateFrame("Slider", name, effects, "OptionsSliderTemplate")
    slider:SetMinMaxValues(low, high)
    slider.type = CONTROLTYPE_SLIDER
    slider.cvar = cvar
    slider.SetDisplayValue = slider.SetValue
    slider.SetValue = function(self, value)
        self:SetDisplayValue(value)
        BlizzardOptionsPanel_SetCVarSafe(self.cvar, value)
    end
    slider:SetScript("OnValueChanged", VideoOptionsEffectsPanelSlider_OnValueChanged)
    BlizzardOptionsPanel_RegisterControl(slider, effects)
    return slider
end

local viewDistance = StockSlider("VideoOptionsEffectsPanelViewDistance", "farclip", 177, 1277)
StockSlider("VideoOptionsEffectsPanelEnvironmentDetail", "environmentDetail", 0.5, 1.5)
local clutterRadius = StockSlider("VideoOptionsEffectsPanelClutterRadius", "groundEffectDist", 70, 140)
VideoOptionsEffectsPanel_OnLoad(effects)

-- ----------------------------------------------------------------------------
-- A saved profile from before the server's profiles went away
-- ----------------------------------------------------------------------------

DCQoSDB = {
    profiles = {
        Default = {
            graphicsPlus = {
                enabled = true,
                autoApplyOnLogin = true,
                autoApplyOnZoneChange = true,
                showChatFeedback = false,
                farclip = 2200,
                cameraDistance = 120,
                horizonScale = 8.0,
                environmentDetail = 2.0,
                doodadFade = 2560,
                doodadFadeCategories = { 2560, 2560, 2560, 2560, 2560 },
                fogOverride = true,
                applyQualityPreset = true,
            },
        },
    },
    activeProfile = "Default",
}

local function Boot()
    SIM.LoadFile(SIM.ADDONS_DIR .. "DC-AddonProtocol/DCCompat.lua", "DC-AddonProtocol", {})
    CLIENT.loadedAddons["DC-AddonProtocol"] = true
    -- The TOC also holds all of WeakAuras; the pages need these
    local ns = {}
    for _, file in ipairs({ "Core.lua", "UI/SharedShell.lua", "UI/SettingsPanel.lua", "UI/VideoOptions.lua",
        "Modules/GraphicsPlus.lua", "Modules/PostProcessing.lua", "Modules/FogAndWater.lua",
        "Modules/RaidGraphics.lua" }) do
        SIM.LoadFile(SIM.ADDONS_DIR .. "DC-QOS/" .. file, "DC-QOS", ns)
    end
    SIM.FireEvent("ADDON_LOADED", "DC-QOS")
    SIM.FireEvent("VARIABLES_LOADED")
    SIM.FireEvent("PLAYER_LOGIN")
    SIM.FireEvent("PLAYER_ENTERING_WORLD")
    SIM.Run(3)
end

local function Control(key)
    return _G["DCQoSVideo_" .. key]
end

local function Label(key)
    return Control(key).Text:GetText()
end

local function Page(moduleName)
    return DCQOS.videoOptionsPages[moduleName]
end

local function Open(moduleName)
    window:Show()
    OptionsList_DisplayPanel(Page(moduleName))
end

local function Close()
    window:Hide()
end

local function ClickButton(page, text)
    for _, child in ipairs({ page.content:GetChildren() }) do
        if child.GetText and child:GetText() == text then
            child:Click()
            return true
        end
    end
end

-- The client flips a check button before its OnClick; the simulator's Click leaves that to the caller
local function Tick(box)
    box:SetChecked(not box:GetChecked())
    box:Click()
end

local function Settings()
    return DCQOS.settings.graphicsPlus
end

local function Categories()
    local names = {}
    for _, element in ipairs(window.categoryList) do
        names[#names + 1] = element.name
    end
    return table.concat(names, ", ")
end

local function FarclipDrops()
    local drops = 0
    for index = 2, #farclipWrites do
        if farclipWrites[index] < farclipWrites[index - 1] then
            drops = drops + 1
        end
    end
    return drops
end

section("load")
Boot()
noNewErrors("DC-QOS loads and builds its pages")
ok(DCQOS.videoOptionsPages ~= nil, "the pages were built")
ok(rawget(_G, "DCQoSFrame_GraphicsPlus") == nil, "Graphics+ left the DC-QOS menu")
ok(rawget(_G, "DCQoSBtn_GraphicsPlus") == nil, "and its dashboard button")
ok(rawget(_G, "DCQoSBtn_PostProcessing") == nil, "Post-Processing is not there either")
ok(DCQOS.moduleFrames.FrameMover ~= nil, "the rest of the DC-QOS menu is")

section("the server's profile becomes the local settings")
ok(Settings().farclip == 1800, "farclip = " .. tostring(Settings().farclip))
ok(Settings().environmentDetail == 1.5, "environmentDetail = " .. tostring(Settings().environmentDetail))
ok(Settings().doodadFadeCategories[1] == 200 and Settings().doodadFadeCategories[5] == 1250, "the doodads trimmed by size")
ok(Settings().fogOverride == nil, "the dead fog option is gone")
ok(CLIENT.cvars.farclip + 0 == 1800, "and they applied: farclip " .. tostring(CLIENT.cvars.farclip))
ok(native.doodads and native.doodads[1] == 200, "doodad sizes applied")
Settings().farclip = 2000
Settings().localValues = true
DCQOS:FireEvent("noop")
ok(Settings().farclip == 2000, "a later change is the player's own")
Settings().farclip = 1800

if OLD_CLIENT then
    section("old client")
    ok(Settings().grassDistance == 200, "the saved value exists on either client")
    ok(CLIENT.cvars.groundEffectDist == "70", "the old client stays under the stock limit: " .. tostring(CLIENT.cvars.groundEffectDist))
    ok(not Control("grassDistance"):IsShown(), "and has no Grass Distance slider")
    Open("GraphicsPlus")
    Control("cameraDistance"):SetValue(200)
    VideoOptionsFrameOkay:Click()
    ok(CLIENT.cvars.groundEffectDist == "70", "Okay leaves it alone")
    ok(Categories() == "Effects, Graphics+", "the window has: " .. Categories())
    ok(Page("PostProcessing") == nil, "no Post-Processing page")
    ok(Page("FogAndWater") == nil, "no Fog & Water page")
    ok(Page("RaidGraphics") == nil, "no Raid Profile page")
    for name in pairs(POST_DEFAULTS) do
        ok(CLIENT.cvars[name] == nil, name .. " was not created")
    end
    for name in pairs(RAID_DEFAULTS) do
        ok(CLIENT.cvars[name] == nil, name .. " was not created")
    end
    noNewErrors("the old client's page ran")
    T.Finish()
end

section("the window")
ok(Categories() == "Effects, Graphics+, Post-Processing" .. (hasFog and ", Fog & Water" or "")
    .. (hasRaid and ", Raid Profile" or ""),
    "the window has: " .. Categories())
Open("GraphicsPlus")
ok(Page("GraphicsPlus"):IsVisible(), "Graphics+ opens")
ok(Label("farclip") == "Farclip: 1800", Label("farclip"))
ok(Label("environmentDetail") == "Environment Detail: 1.5", Label("environmentDetail"))
ok(Label("doodadFade") == "All Sizes: 1250", Label("doodadFade"))
ok(Label("doodadTiny") == "Tiny: 200", Label("doodadTiny"))
ok(Control("doodadHuge").Low:GetText() == "1250", "Huge's scale starts at its stock distance")
ok(Control("enabled"):GetChecked(), "auto-apply is ticked")
ok(not Control("showChatFeedback"):GetChecked(), "chat feedback is not")
Close()

section("Graphics+ waits for Okay")
farclipWrites = {}
Open("GraphicsPlus")
Control("farclip"):SetValue(2400)
Control("cameraDistance"):SetValue(200)
ok(Label("farclip") == "Farclip: 2400", Label("farclip"))
ok(#farclipWrites == 0, "moving the slider wrote nothing: a jump in farclip shows a loading screen")
ok(Settings().farclip == 1800, "and the setting is unchanged")
ok(VideoOptionsFrameApply:IsEnabled(), "Apply wakes up")
VideoOptionsFrameCancel:Click()
ok(Settings().farclip == 1800, "Cancel keeps the setting")
ok(#farclipWrites == 0 or FarclipDrops() == 0, "and did not touch farclip")
Open("GraphicsPlus")
ok(Label("farclip") == "Farclip: 1800", "reopening shows the stored value: " .. Label("farclip"))
Control("farclip"):SetValue(2400)
VideoOptionsFrameOkay:Click()
ok(Settings().farclip == 2400, "Okay stores it")
ok(CLIENT.cvars.farclip + 0 == 2400, "and applies it")
ok(not window:IsShown(), "and closes the window")

section("Apply keeps the window open")
Open("GraphicsPlus")
Control("horizonScale"):SetValue(7)
VideoOptionsFrameApply:Click()
ok(Settings().horizonScale == 7, "Apply stores it")
ok(native.SetHorizonScale and native.SetHorizonScale[1] == 7, "and applies it")
ok(window:IsShown(), "the window stays")
ok(not VideoOptionsFrameApply:IsEnabled(), "Apply goes back to sleep")
Close()

section("the Effects page cannot pull farclip down")
Settings().farclip = 1800
SetCVar("farclip", "1800")
viewDistance:SetDisplayValue(177)
farclipWrites = {}
Open("GraphicsPlus")
ok(viewDistance:GetValue() == 1277, "the stock slider stops at its limit")
ok(viewDistance.newValue == nil, "and does not count that as a change")
VideoOptionsFrameOkay:Click()
ok(CLIENT.cvars.farclip + 0 == 1800, "Okay leaves farclip alone: " .. tostring(CLIENT.cvars.farclip))
ok(FarclipDrops() == 0, "it never dipped, which would have shown a loading screen on the way back up")

section("a stock slider that moved is the newest choice")
Open("GraphicsPlus")
viewDistance:SetDisplayValue(777)
ok(viewDistance.newValue == 777, "the stock slider has a change")
VideoOptionsFrameOkay:Click()
ok(CLIENT.cvars.farclip + 0 == 777, "View Distance took: " .. tostring(CLIENT.cvars.farclip))
ok(Settings().farclip == 777, "and Graphics+ follows it instead of undoing it")
Settings().farclip = 1800
SetCVar("farclip", "1800")

section("grass distance")
ok(Settings().grassDistance == 200, "Balanced grass reaches past the stock limit: " .. tostring(Settings().grassDistance))
ok(CLIENT.cvars.groundEffectDist + 0 == 200, "and it applied: " .. tostring(CLIENT.cvars.groundEffectDist))
Open("GraphicsPlus")
ok(Label("grassDistance") == "Grass Distance: 200", Label("grassDistance"))
ok(Control("grassDistance"):IsShown(), "the slider is there")
ok(clutterRadius:GetValue() == 140, "the stock slider stops at its limit")
ok(clutterRadius.newValue == nil, "and does not count that as a change")
VideoOptionsFrameOkay:Click()
ok(CLIENT.cvars.groundEffectDist + 0 == 200, "Okay leaves the grass alone: " .. tostring(CLIENT.cvars.groundEffectDist))
Open("GraphicsPlus")
Control("grassDistance"):SetValue(250)
ok(CLIENT.cvars.groundEffectDist + 0 == 200, "a moved slider waits for Okay")
VideoOptionsFrameOkay:Click()
ok(Settings().grassDistance == 250 and native.grass == 250, "Okay stores and applies it")
Open("GraphicsPlus")
clutterRadius:SetDisplayValue(100)
VideoOptionsFrameOkay:Click()
ok(Settings().grassDistance == 100, "the stock slider moved, so it is the newest choice")
Settings().grassDistance = 200
SetCVar("groundEffectDist", "200")

section("presets")
Open("GraphicsPlus")
ok(ClickButton(Page("GraphicsPlus"), "Ultra"), "Ultra exists")
ok(Label("farclip") == "Farclip: 3831", Label("farclip"))
ok(Label("doodadTiny") == "Tiny: 2560", Label("doodadTiny"))
ok(Label("grassDistance") == "Grass Distance: 280", Label("grassDistance"))
ok(Settings().farclip == 1800, "a preset waits for Okay too")
ok(ClickButton(Page("GraphicsPlus"), "Performance"), "Performance exists")
ok(Label("farclip") == "Farclip: 1400", Label("farclip"))
ok(not Control("applyQualityPreset"):GetChecked(), "Performance leaves the quality preset off")
VideoOptionsFrameOkay:Click()
ok(Settings().cameraDistance == 70, "Okay stores the preset")
ok(native.doodads[5] == 1250, "and applies its doodads")

section("the doodad master")
Open("GraphicsPlus")
Control("doodadFade"):SetValue(150)
ok(Label("doodadTiny") == "Tiny: 150", Label("doodadTiny"))
ok(Label("doodadMedium") == "Medium: 200", "sizes stay at their stock floor: " .. Label("doodadMedium"))
Control("doodadHuge"):SetValue(1500)
VideoOptionsFrameOkay:Click()
ok(Settings().doodadFadeCategories[2] == 150, "the master set Small")
ok(Settings().doodadFadeCategories[5] == 1500, "Huge keeps its own value")

section("the options")
Open("GraphicsPlus")
Tick(Control("showChatFeedback"))
ok(Settings().showChatFeedback == false, "a box waits for Okay too")
VideoOptionsFrameOkay:Click()
ok(Settings().showChatFeedback == true, "and Okay stores it")
Open("GraphicsPlus")
Tick(Control("showChatFeedback"))
VideoOptionsFrameOkay:Click()

section("turning auto-apply off and on needs no reload")
Open("GraphicsPlus")
Tick(Control("enabled"))
Control("farclip"):SetValue(2000)
farclipWrites = {}
VideoOptionsFrameOkay:Click()
ok(Settings().enabled == false, "off")
ok(#farclipWrites == 0, "and Okay no longer applies")
Open("GraphicsPlus")
Tick(Control("enabled"))
VideoOptionsFrameOkay:Click()
SIM.Run(1)
ok(Settings().enabled == true, "on")
ok(CLIENT.cvars.farclip + 0 == 2000, "and it applies at once")

section("Graphics+ defaults")
Open("GraphicsPlus")
OptionsFrame_SetCurrentToDefaults(window)
ok(Settings().farclip == 1800 and Settings().environmentDetail == 1.5, "These Settings restores Balanced")
ok(Settings().grassDistance == 200, "grass too")
ok(Label("farclip") == "Farclip: 1800", "the controls follow: " .. Label("farclip"))
Close()

section("Post-Processing shows the CVars")
Open("PostProcessing")
ok(Page("PostProcessing"):IsVisible(), "Post-Processing opens")
ok(Label("dcSmaa") == "Quality: Off", Label("dcSmaa"))
ok(Label("dcGtao") == "Quality: Off", Label("dcGtao"))
ok(Label("dcGtaoRadius") == "Radius: 1.5 yards", Label("dcGtaoRadius"))
ok(Label("dcGtaoStrength") == "Strength: 70%", Label("dcGtaoStrength"))
ok(Label("dcGtaoDistance") == "Fade distance: 120 yards", Label("dcGtaoDistance"))
ok(Label("dcRenderScale") == "Render scale: 100%", Label("dcRenderScale"))
ok(Label("dcFsrSharpness") == "Sharpness: 50%", Label("dcFsrSharpness"))
ok(Control("dcSmaa").High:GetText() == "Ultra", "SMAA's scale ends at Ultra")
ok(Control("dcGtao").High:GetText() == "High", "GTAO's scale ends at High")
ok(CLIENT.cvars.dcGtaoStrength == "0.7", "opening it wrote nothing back")

section("Post-Processing applies as it moves")
Control("dcSmaa"):SetValue(3)
ok(CLIENT.cvars.dcSmaa == "3", "dcSmaa = " .. tostring(CLIENT.cvars.dcSmaa))
ok(Label("dcSmaa") == "Quality: High", Label("dcSmaa"))
Control("dcGtao"):SetValue(2)
ok(CLIENT.cvars.dcGtao == "2", "dcGtao = " .. tostring(CLIENT.cvars.dcGtao))
Control("dcGtaoRadius"):SetValue(2.34)
ok(CLIENT.cvars.dcGtaoRadius == "2.3", "dcGtaoRadius falls on the step: " .. tostring(CLIENT.cvars.dcGtaoRadius))
ok(Label("dcGtaoRadius") == "Radius: 2.3 yards", Label("dcGtaoRadius"))
Control("dcGtaoStrength"):SetValue(0.55)
ok(CLIENT.cvars.dcGtaoStrength == "0.55", "dcGtaoStrength = " .. tostring(CLIENT.cvars.dcGtaoStrength))
ok(Label("dcGtaoStrength") == "Strength: 55%", Label("dcGtaoStrength"))
Control("dcGtaoDistance"):SetValue(200)
ok(CLIENT.cvars.dcGtaoDistance == "200", "dcGtaoDistance = " .. tostring(CLIENT.cvars.dcGtaoDistance))
ok(VideoOptionsFrameApply:IsEnabled(), "Apply wakes up")

section("Cancel puts Post-Processing back")
VideoOptionsFrameCancel:Click()
ok(CLIENT.cvars.dcSmaa == "0", "dcSmaa = " .. tostring(CLIENT.cvars.dcSmaa))
ok(CLIENT.cvars.dcGtao == "0", "dcGtao = " .. tostring(CLIENT.cvars.dcGtao))
ok(CLIENT.cvars.dcGtaoRadius == "1.5", "dcGtaoRadius = " .. tostring(CLIENT.cvars.dcGtaoRadius))
ok(CLIENT.cvars.dcGtaoStrength == "0.7", "dcGtaoStrength = " .. tostring(CLIENT.cvars.dcGtaoStrength))

section("Okay and Apply keep it")
Open("PostProcessing")
Control("dcSmaa"):SetValue(3)
VideoOptionsFrameApply:Click()
Control("dcGtao"):SetValue(2)
VideoOptionsFrameCancel:Click()
ok(CLIENT.cvars.dcSmaa == "3", "Cancel stops at what Apply kept")
ok(CLIENT.cvars.dcGtao == "0", "and undoes what came after")
Open("PostProcessing")
Control("dcGtao"):SetValue(2)
VideoOptionsFrameOkay:Click()
ok(CLIENT.cvars.dcGtao == "2", "Okay keeps it")

section("the occlusion view")
Open("PostProcessing")
Tick(Control("dcGtaoDebug"))
ok(CLIENT.cvars.dcGtaoDebug == "1", "ticking turns it on at once")
Tick(Control("dcGtaoDebug"))
ok(CLIENT.cvars.dcGtaoDebug == "0", "unticking turns it off")

section("quality off greys out what depends on it")
ok(Control("dcGtaoRadius"):GetAlpha() == 1, "with occlusion on, the radius is live")
Control("dcGtao"):SetValue(0)
ok(Control("dcGtaoRadius"):GetAlpha() == 0.5 and Control("dcGtaoDistance"):GetAlpha() == 0.5, "the details grey out")
ok(not Control("dcGtaoRadius"):IsMouseEnabled(), "and take no input")
ok(Control("dcGtaoDebug"):GetAlpha() == 0.5, "the occlusion view too")
ok(Control("dcGtao"):GetAlpha() == 1 and Control("dcGtao"):IsMouseEnabled(), "the quality slider stays live")
Control("dcGtao"):SetValue(2)
ok(Control("dcGtaoRadius"):GetAlpha() == 1, "turning it back on restores them")
VideoOptionsFrameOkay:Click()

section("reopening reads what the console set")
CLIENT.cvars.dcSmaa = "1"
CLIENT.cvars.dcGtaoRadius = "1.55"
Open("PostProcessing")
ok(Label("dcSmaa") == "Quality: Low", Label("dcSmaa"))
ok(Control("dcSmaa"):GetValue() == 1, "the slider moved")
ok(CLIENT.cvars.dcGtaoRadius == "1.55", "a value between steps is left alone")
Close()

section("a device that cannot read depth")
local function NoteText()
    for _, region in ipairs({ Page("PostProcessing").content:GetRegions() }) do
        local text = region.GetText and region:GetText() or nil
        if text and (text:find("creases", 1, true) or text:find("Unavailable on this device", 1, true)) then
            return text
        end
    end
end

ok(NoteText():find("creases", 1, true), "normally the note says what the effect does")
depthReadable = false
Open("PostProcessing")
ok(NoteText():find("multisampling", 1, true), "it now names multisampling")
ok(Control("dcGtao"):GetAlpha() == 0.5 and not Control("dcGtao"):IsMouseEnabled(), "the quality slider greys out")
ok(Control("dcSmaa"):GetAlpha() == 1 and Control("dcSmaa"):IsMouseEnabled(), "SMAA stays live")
ok(CLIENT.cvars.dcGtao == "2", "the saved quality is kept for when multisampling goes off")
Close()
depthReadable = true
Open("PostProcessing")
ok(Control("dcGtao"):GetAlpha() == 1, "reopening after the change brings it back")
Close()

section("the sun, glow, colour and lighting controls")
Open("PostProcessing")
ok(Control("dcSunRays"):GetChecked(), "the sun's rays are ticked")
if hasContact then
    ok(Control("dcContactShadows"):GetChecked(), "contact shadows are ticked")
    ok(Label("dcContactShadowsLength") == "Length: 0.8 yards", Label("dcContactShadowsLength"))
else
    ok(Control("dcContactShadows") == nil and Control("dcContactShadowsLength") == nil,
        "an exe without contact shadows gets no controls for them")
end
ok(Control("dcBloom"):GetChecked() and Control("dcGrade"):GetChecked() and Control("dcPixelLights"):GetChecked(),
    "bloom, grading and per-pixel lamps are ticked")
ok(Label("dcSunRaysStrength") == "Strength: 60%", Label("dcSunRaysStrength"))
ok(Label("dcBloomThreshold") == "From brightness: 60%", Label("dcBloomThreshold"))
ok(Label("dcGradeExposure") == "Exposure: +0.0 stops", Label("dcGradeExposure"))
ok(Label("dcGradeContrast") == "Contrast: +15%", Label("dcGradeContrast"))
ok(Label("dcGradeSaturation") == "Saturation: 105%", Label("dcGradeSaturation"))
ok(Label("dcGradeWarmth") == "Warmth: neutral", Label("dcGradeWarmth"))
ok(Label("dcShadowSunOnly") == "Shade keeps colour: 100%", Label("dcShadowSunOnly"))
ok(Label("dcLightWrap") == "Soft light edge: 20%", Label("dcLightWrap"))
ok(Control("dcGradeWarmth").Low:GetText() == "100% cooler", "warmth's scale starts cooler")

Control("dcGradeWarmth"):SetValue(-0.3)
ok(CLIENT.cvars.dcGradeWarmth == "-0.3", "dcGradeWarmth = " .. tostring(CLIENT.cvars.dcGradeWarmth))
ok(Label("dcGradeWarmth") == "Warmth: 30% cooler", Label("dcGradeWarmth"))
if hasContact then
    Control("dcContactShadowsLength"):SetValue(1.26)
    ok(CLIENT.cvars.dcContactShadowsLength == "1.3", "the length falls on the step: " .. tostring(CLIENT.cvars.dcContactShadowsLength))
end

Tick(Control("dcBloom"))
ok(CLIENT.cvars.dcBloom == "0", "unticking bloom turns it off at once")
ok(Control("dcBloomStrength"):GetAlpha() == 0.5 and not Control("dcBloomStrength"):IsMouseEnabled(),
    "and greys out its sliders")
ok(Control("dcGradeContrast"):GetAlpha() == 1, "grading's sliders stay live")
Tick(Control("dcBloom"))
ok(CLIENT.cvars.dcBloom == "1" and Control("dcBloomStrength"):GetAlpha() == 1, "ticking brings them back")
Tick(Control("dcPixelLights"))
ok(CLIENT.cvars.dcPixelLights == "0", "per-pixel lamps can be turned off")

VideoOptionsFrameCancel:Click()
ok(CLIENT.cvars.dcGradeWarmth == "0" and CLIENT.cvars.dcPixelLights == "1", "Cancel puts them back")
ok(CLIENT.cvars.dcContactShadowsLength == (hasContact and "0.8" or nil), "and the contact shadows' length")

depthReadable = false
Open("PostProcessing")
ok(Control("dcSunRays"):GetAlpha() == 0.5 and Control("dcSunRaysStrength"):GetAlpha() == 0.5,
    "without readable depth the sun's rays grey out, their slider too")
if hasContact then
    ok(Control("dcContactShadows"):GetAlpha() == 0.5 and Control("dcContactShadowsStrength"):GetAlpha() == 0.5,
        "contact shadows too")
end
ok(Control("dcBloom"):GetAlpha() == 1 and Control("dcBloomStrength"):GetAlpha() == 1 and Control("dcGradeExposure"):GetAlpha() == 1,
    "bloom and grading read colour only and stay live")
ok(CLIENT.cvars.dcSunRays == "1", "the saved setting is kept")
Close()
depthReadable = true

section("the sky, shadow map and lamp controls")
Open("PostProcessing")
ok(Control("dcSky"):GetChecked() and Control("dcSunPath"):GetChecked() and Control("dcDayNightSmooth"):GetChecked(),
    "the sky, the sun's path and smooth day and night are ticked")
ok(Label("dcSkyGlow") == "Glow: 35%", Label("dcSkyGlow"))
ok(Label("dcSkyGlowSize") == "Glow size: 50 degrees", Label("dcSkyGlowSize"))
ok(Label("dcSkyDither") == "Dither against banding: 1.0", Label("dcSkyDither"))
ok(Control("dcSkyDither").Low:GetText() == "Off", "the dither's scale starts at Off")
ok(Label("dcSunGlareDim") == "Sun glare darkens the world: 0%", Label("dcSunGlareDim"))
ok(Label("dcShadowSunHeight") == "Shadow light: Real sun", Label("dcShadowSunHeight"))
ok(Control("dcShadowSunHeight").High:GetText() == "Original", "the shadow light's scale ends at the original")
ok(Label("dcShadowSunMin") == "Lowest shadow sun: 15 degrees", Label("dcShadowSunMin"))
ok(Label("dcShadowSunRefresh") == "Redraw after the sun turns: 0.50 degrees", Label("dcShadowSunRefresh"))
ok(Control("dcShadowSunCache"):GetChecked() and Control("dcShadowTexelSnap"):GetChecked()
    and Control("dcShadowCasterFade"):GetChecked() and Control("dcShadowBillboard"):GetChecked()
    and Control("dcShadowBandStagger"):GetChecked(), "the shadow map boxes are ticked")
ok(Control("dcLampLights"):GetChecked() and not Control("dcLampLightsObjects"):GetChecked(),
    "lamp lights are on, on other models off")
ok(Label("dcLampLightsIntensity") == "Brightness: 100%", Label("dcLampLightsIntensity"))
ok(Label("dcLampLightsRange") == "Reach: 8 yards", Label("dcLampLightsRange"))

Control("dcShadowSunHeight"):SetValue(2.54)
ok(CLIENT.cvars.dcShadowSunHeight == "2.5", "dcShadowSunHeight = " .. tostring(CLIENT.cvars.dcShadowSunHeight))
ok(Label("dcShadowSunHeight") == "Shadow light: 2.5x steeper", Label("dcShadowSunHeight"))
Tick(Control("dcSky"))
ok(CLIENT.cvars.dcSky == "0", "unticking the sky turns it off at once")
ok(Control("dcSkyGlow"):GetAlpha() == 0.5 and Control("dcSkyDither"):GetAlpha() == 0.5, "and greys out its sliders")
Tick(Control("dcShadowSunCache"))
ok(CLIENT.cvars.dcShadowSunCache == "0" and Control("dcShadowSunRefresh"):GetAlpha() == 0.5,
    "the cache's redraw slider follows its box")
Tick(Control("dcLampLightsObjects"))
ok(CLIENT.cvars.dcLampLightsObjects == "1", "lamp lights can reach other models")
Control("dcLampLightsRange"):SetValue(12)
ok(CLIENT.cvars.dcLampLightsRange == "12", "dcLampLightsRange = " .. tostring(CLIENT.cvars.dcLampLightsRange))

VideoOptionsFrameCancel:Click()
ok(CLIENT.cvars.dcSky == "1" and CLIENT.cvars.dcShadowSunHeight == "1" and CLIENT.cvars.dcShadowSunCache == "1"
    and CLIENT.cvars.dcLampLightsObjects == "0" and CLIENT.cvars.dcLampLightsRange == "8", "Cancel puts them all back")

local function PageText(moduleName, needle)
    for _, region in ipairs({ Page(moduleName).content:GetRegions() }) do
        local text = region.GetText and region:GetText() or nil
        if text and text:find(needle, 1, true) then
            return text
        end
    end
end

if hasFog then
    section("fog and water have their own page")
    ok(Control("dcVolumetricFog"):GetParent() == Page("FogAndWater").content, "the fog's controls are on Fog & Water")
    ok(Control("dcWater"):GetParent() == Page("FogAndWater").content, "and the water's")
    ok(PageText("PostProcessing", "Fog & Water") ~= nil, "Post-Processing points to it")
    Open("FogAndWater")
    ok(Page("FogAndWater"):IsVisible(), "Fog & Water opens")
    ok(Label("dcVolumetricFog") == "Quality: Off", Label("dcVolumetricFog"))
    ok(Control("dcVolumetricFog").High:GetText() == "High", "the fog's scale ends at High")
    ok(Label("dcVolumetricFogDensity") == "Density: 100%", Label("dcVolumetricFogDensity"))
    ok(Label("dcVolumetricFogMist") == "Ground mist: 100%", Label("dcVolumetricFogMist"))
    ok(Label("dcVolumetricFogDistance") == "Reach: 400 yards", Label("dcVolumetricFogDistance"))
    ok(Label("dcVolumetricFogTemporal") == "Smoothing over frames: 85%", Label("dcVolumetricFogTemporal"))
    ok(Label("dcVolumetricFogForeverBrightness") == "Brightness: 85%", Label("dcVolumetricFogForeverBrightness"))
    ok(Control("dcVolumetricFogShafts"):GetChecked(), "sun shafts are ticked")
    ok(Control("dcForeverLight"):GetChecked() and Control("dcForeverLight"):GetAlpha() == 1,
        "WoW Forever's zone lighting is ticked, and live with the fog off")
    ok(not Control("dcWater"):GetChecked(), "the water is off")
    ok(Label("dcWaterWaves") == "Wave height: 100%", Label("dcWaterWaves"))
    ok(Label("dcWaterWakes") == "Wakes: 100%", Label("dcWaterWakes"))
    ok(Label("dcWaterPbrBrightness") == "Brightness: 100%", Label("dcWaterPbrBrightness"))
    ok(Label("dcWaterPbrMirror") == "Sky mirrored far out: 100%", Label("dcWaterPbrMirror"))
    ok(Label("dcWaterPbrShore") == "Shore fade: 2.0 yards", Label("dcWaterPbrShore"))
    ok(Label("dcWaterLamps") == "Lamps and fires: 100%", Label("dcWaterLamps"))
    ok(Control("dcLiquidMagma"):GetChecked() and Control("dcLiquidMagma"):GetAlpha() == 1,
        "Cataclysm's lava and slime are ticked and live")
    ok(PageText("FogAndWater", "Mist along the ground") ~= nil, "the fog's note says what it does")
    ok(CLIENT.cvars.dcVolumetricFogTemporal == "0.85", "opening it wrote nothing back")

    section("fog quality off greys out its details")
    ok(Control("dcVolumetricFogDensity"):GetAlpha() == 0.5 and not Control("dcVolumetricFogDensity"):IsMouseEnabled(),
        "with the fog off, its sliders take no input")
    ok(Control("dcVolumetricFogShafts"):GetAlpha() == 0.5, "the shafts box too")
    ok(Control("dcVolumetricFog"):GetAlpha() == 1 and Control("dcVolumetricFog"):IsMouseEnabled(), "the quality stays live")
    Control("dcVolumetricFog"):SetValue(3)
    ok(CLIENT.cvars.dcVolumetricFog == "3", "it applies as it moves: " .. tostring(CLIENT.cvars.dcVolumetricFog))
    ok(Label("dcVolumetricFog") == "Quality: High", Label("dcVolumetricFog"))
    ok(Control("dcVolumetricFogDensity"):GetAlpha() == 1 and Control("dcVolumetricFogShafts"):GetAlpha() == 1,
        "turning it on wakes its details")
    Control("dcVolumetricFogMist"):SetValue(1.53)
    ok(CLIENT.cvars.dcVolumetricFogMist == "1.55", "the mist falls on the step: " .. tostring(CLIENT.cvars.dcVolumetricFogMist))
    Tick(Control("dcVolumetricFogShafts"))
    ok(CLIENT.cvars.dcVolumetricFogShafts == "0", "the shafts can be turned off")

    section("WoW Forever's fog model")
    ok(Control("dcVolumetricFogForever"):GetChecked(), "it is ticked by default")
    ok(Control("dcVolumetricFogForever"):GetAlpha() == 1, "and live while the fog is on")
    ok(Control("dcVolumetricFogDistance"):GetAlpha() == 0.5 and not Control("dcVolumetricFogDistance"):IsMouseEnabled(),
        "its own range makes the Reach slider moot")
    Tick(Control("dcVolumetricFogForever"))
    ok(CLIENT.cvars.dcVolumetricFogForever == "0", "unticking goes back to the haze and mist at once")
    ok(Control("dcVolumetricFogDistance"):GetAlpha() == 1, "and the Reach slider wakes")
    ok(PageText("FogAndWater", "earlier haze and ground mist") ~= nil, "the note says what off means")
    ok(VideoOptionsFrameApply:IsEnabled(), "Apply wakes up")

    section("the water box")
    ok(Control("dcWaterWaves"):GetAlpha() == 0.5 and not Control("dcWaterFoam"):IsMouseEnabled(),
        "with the water off, its sliders take no input")
    Tick(Control("dcWater"))
    ok(CLIENT.cvars.dcWater == "1", "ticking turns it on at once")
    ok(Control("dcWaterWaves"):GetAlpha() == 1 and Control("dcWaterWakes"):IsMouseEnabled(), "and wakes its sliders")
    Control("dcWaterReflections"):SetValue(0.5)
    ok(CLIENT.cvars.dcWaterReflections == "0.5", "dcWaterReflections = " .. tostring(CLIENT.cvars.dcWaterReflections))
    ok(Control("dcWaterPbr"):GetChecked() and Control("dcWaterPbr"):GetAlpha() == 1, "WoW Forever's water is ticked and live")
    Tick(Control("dcWaterPbr"))
    ok(CLIENT.cvars.dcWaterPbr == "0", "it can be turned off at once")
    ok(PageText("FogAndWater", "multisampling on") ~= nil, "its note says when the water above draws instead")

    section("Cancel puts Fog & Water back")
    VideoOptionsFrameCancel:Click()
    ok(CLIENT.cvars.dcVolumetricFog == "0" and CLIENT.cvars.dcVolumetricFogMist == "1"
        and CLIENT.cvars.dcVolumetricFogShafts == "1", "the fog is back: " .. tostring(CLIENT.cvars.dcVolumetricFog))
    ok(CLIENT.cvars.dcVolumetricFogForever == "1", "WoW Forever's model too")
    ok(CLIENT.cvars.dcWater == "0" and CLIENT.cvars.dcWaterReflections == "1" and CLIENT.cvars.dcWaterPbr == "1",
        "the water too")

    section("Okay keeps Fog & Water")
    Open("FogAndWater")
    Control("dcVolumetricFog"):SetValue(2)
    Tick(Control("dcWater"))
    VideoOptionsFrameOkay:Click()
    ok(CLIENT.cvars.dcVolumetricFog == "2" and CLIENT.cvars.dcWater == "1", "Okay keeps them")

    section("Fog & Water on a device that cannot read depth")
    depthReadable = false
    Open("FogAndWater")
    ok(Control("dcVolumetricFog"):GetAlpha() == 0.5 and not Control("dcVolumetricFog"):IsMouseEnabled(),
        "the fog's quality greys out")
    ok(Control("dcVolumetricFogDensity"):GetAlpha() == 0.5, "and its details")
    local note = PageText("FogAndWater", "Unavailable on this device")
    ok(note ~= nil and note:find("multisampling", 1, true) and note:find("Resolution", 1, true),
        "the note names multisampling and where to turn it off")
    ok(Control("dcWater"):GetAlpha() == 1 and Control("dcWaterWaves"):GetAlpha() == 1, "the water does not need depth")
    ok(CLIENT.cvars.dcVolumetricFog == "2", "the saved fog quality is kept")
    Close()
    depthReadable = true
    Open("FogAndWater")
    ok(Control("dcVolumetricFog"):GetAlpha() == 1 and Control("dcVolumetricFogDensity"):GetAlpha() == 1,
        "reopening after the change brings the fog back")
    Close()
else
    section("no Fog & Water page")
    ok(Page("FogAndWater") == nil, "an exe without fog and water gets no Fog & Water page")
    ok(Control("dcVolumetricFog") == nil and Control("dcWater") == nil, "and no controls for them")
    ok(PageText("PostProcessing", "Fog & Water") == nil, "Post-Processing does not point to a missing page")
end

section("Defaults, all pages")
Open("PostProcessing")
Control("dcGtaoRadius"):SetValue(3)
VideoOptionsFrame_SetAllToDefaults()
for name, value in pairs(POST_DEFAULTS) do
    local expected = not MISSING[name] and value or nil
    ok(CLIENT.cvars[name] == expected, name .. " = " .. tostring(CLIENT.cvars[name]))
end
ok(Settings().farclip == 1800, "Graphics+ is back on Balanced")
ok(Label("dcSmaa") == "Quality: Off" and Label("dcGtaoRadius") == "Radius: 1.5 yards", "the labels follow")
ok(not VideoOptionsFrameApply:IsEnabled(), "Apply goes to sleep")
VideoOptionsFrameCancel:Click()
ok(CLIENT.cvars.dcGtaoRadius == "1.5", "Cancel afterwards does not bring the old radius back")

if hasRaid then
    local function RaidStatus()
        for _, region in ipairs({ Page("RaidGraphics").content:GetRegions() }) do
            local text = region.GetText and region:GetText() or nil
            if text and (text:find("Active now", 1, true) or text:find("Not active", 1, true) or text:find("Off:", 1, true)) then
                return text
            end
        end
        return ""
    end

    -- Where Graphics+'s Balanced puts them; outside a raid these are the normal values
    SetCVar("farclip", "1800")
    SetCVar("environmentDetail", "1.5")
    SetCVar("groundEffectDist", "200")

    section("the Raid Profile page shows the CVars")
    raidWrites = {}
    Open("RaidGraphics")
    ok(Page("RaidGraphics"):IsVisible(), "Raid Profile opens")
    ok(not Control("raidGraphics"):GetChecked(), "the profile is off by default")
    ok(RaidStatus():find("Off:", 1, true), "and the page says so: " .. RaidStatus())
    ok(Label("farclipRaid") == "Farclip: 1000", Label("farclipRaid"))
    ok(Control("farclipRaid").High:GetText() == "3831", "farclip's scale is Graphics+'s")
    ok(Label("horizonFarclipScaleRaid") == "Horizon Scale: 4.0", Label("horizonFarclipScaleRaid"))
    ok(Label("environmentDetailRaid") == "Environment Detail: 1.0", Label("environmentDetailRaid"))
    ok(Label("groundEffectDensityRaid") == "Ground Clutter Density: 32", Label("groundEffectDensityRaid"))
    ok(Label("groundEffectDistRaid") == "Grass Distance: 70", Label("groundEffectDistRaid"))
    ok(Label("particleDensityRaid") == "Particle Density: 60%", Label("particleDensityRaid"))
    ok(Label("extShadowQualityRaid") == "Shadow Quality: 2", Label("extShadowQualityRaid"))
    ok(Control("extShadowQualityRaid").High:GetText() == "5", "the shadow scale ends at the device's highest quality")
    ok(Label("dcGtaoRaid") == "Ambient Occlusion: Off", Label("dcGtaoRaid"))
    ok(Control("projectedTexturesRaid"):GetChecked(), "projected textures are on in the profile")
    ok(Control("spellEffectLevelRaidKeep"):GetChecked(), "spell detail keeps the normal value")
    ok(Label("spellEffectLevelRaid") == "Spell Detail: 9", "and shows it: " .. Label("spellEffectLevelRaid"))
    ok(Control("spellEffectLevelRaid"):GetAlpha() == 0.5 and not Control("spellEffectLevelRaid"):IsMouseEnabled(),
        "greyed out")
    ok(Control("dcSunRaysRaidKeep"):GetChecked() and Control("dcSunRaysRaid"):GetChecked(),
        "the sun's rays keep the normal value, on")
    ok(not Control("farclipRaidKeep"):GetChecked() and Control("farclipRaid"):GetAlpha() == 1,
        "farclip has a value of its own")
    ok(#raidWrites == 0, "opening it wrote nothing")

    -- The window's stand-in frames have no size, so this reads the anchors on the scroll child
    local function Offset(frame)
        local _, _, _, x, y = frame:GetPoint(1)
        return x, y
    end
    local previousY, rowsInOrder = math.huge, true
    for _, base in ipairs(RAID_SETTINGS) do
        local control, keep = Control(base .. "Raid"), Control(base .. "RaidKeep")
        if not control or not keep then
            rowsInOrder = false
        else
            local controlX, controlY = Offset(control)
            local keepX = Offset(keep)
            if controlY >= previousY or keepX < controlX + control:GetWidth() then
                rowsInOrder = false
            end
            previousY = controlY
        end
    end
    ok(rowsInOrder, "a row per setting in the client's order, its keep-normal box beside the control")

    section("the Raid Profile waits for Okay and writes only what changed")
    Control("farclipRaid"):SetValue(1210)
    ok(Label("farclipRaid") == "Farclip: 1200", "the slider falls on its step: " .. Label("farclipRaid"))
    ok(#raidWrites == 0, "moving a slider wrote nothing")
    ok(VideoOptionsFrameApply:IsEnabled(), "Apply wakes up")
    VideoOptionsFrameCancel:Click()
    ok(CLIENT.cvars.farclipRaid == "1000" and #raidWrites == 0, "Cancel wrote nothing")
    Open("RaidGraphics")
    ok(Label("farclipRaid") == "Farclip: 1000", "reopening shows the stored value: " .. Label("farclipRaid"))
    Control("farclipRaid"):SetValue(1200)
    Tick(Control("particleDensityRaidKeep"))
    ok(Control("particleDensityRaid"):GetAlpha() == 0.5, "keep normal greys the slider out")
    ok(Label("particleDensityRaid") == "Particle Density: 60%", "and leaves its value in view")
    Tick(Control("spellEffectLevelRaidKeep"))
    ok(Control("spellEffectLevelRaid"):GetAlpha() == 1, "unticking gives the slider back")
    Control("spellEffectLevelRaid"):SetValue(3)
    Tick(Control("dcSunRaysRaidKeep"))
    Tick(Control("dcSunRaysRaid"))
    Tick(Control("raidGraphics"))
    Control("groundEffectDistRaid"):SetValue(100)
    Control("groundEffectDistRaid"):SetValue(70)
    VideoOptionsFrameOkay:Click()
    ok(CLIENT.cvars.farclipRaid == "1200", "farclipRaid = " .. tostring(CLIENT.cvars.farclipRaid))
    ok(CLIENT.cvars.particleDensityRaid == "", "keep normal is an empty value: " .. tostring(CLIENT.cvars.particleDensityRaid))
    ok(CLIENT.cvars.spellEffectLevelRaid == "3", "spellEffectLevelRaid = " .. tostring(CLIENT.cvars.spellEffectLevelRaid))
    ok(CLIENT.cvars.dcSunRaysRaid == "0", "the sun's rays are off in the profile: " .. tostring(CLIENT.cvars.dcSunRaysRaid))
    ok(CLIENT.cvars.raidGraphics == "1", "the profile is on")
    ok(#raidWrites == 5, "only the changes were written (a slider moved and back is none): " .. table.concat(raidWrites, ", "))
    ok(raidWrites[#raidWrites] == "raidGraphics=1", "switching on goes last")
    ok(CLIENT.cvars.farclip == "1800", "outside a raid the normal farclip stays: " .. tostring(CLIENT.cvars.farclip))
    Open("RaidGraphics")
    ok(RaidStatus():find("Not active", 1, true), "on, but not in a raid: " .. RaidStatus())
    Close()

    section("inside a raid the profile holds its settings against Graphics+")
    SetCVar("groundEffectDistRaid", "")
    raidWrites = {}
    farclipWrites = {}
    native.grass = nil
    native.SetHorizonScale = nil
    native.SetExtendedCameraDistance = nil
    EnterRaid()
    ok(IsRaidGraphicsActive(), "entering applied the profile")
    ok(CLIENT.cvars.farclip == "1200", "farclip is the profile's: " .. tostring(CLIENT.cvars.farclip))
    ok(#farclipWrites == 0, "Graphics+'s zone-in apply left farclip alone; the client would have adopted it into the profile")
    ok(CLIENT.cvars.farclipRaid == "1200", "so the profile kept it")
    ok(CLIENT.cvars.environmentDetail == "1" and CLIENT.cvars.environmentDetailRaid == "1", "environment detail too")
    ok(native.SetHorizonScale == nil, "and the horizon scale")
    ok(native.SetExtendedCameraDistance ~= nil, "a setting the profile does not swap still applied")
    ok(native.grass == 200 and CLIENT.cvars.groundEffectDist == "200", "grass distance, kept normal in the profile, applied")
    ok(CLIENT.cvars.groundEffectDistRaid == "" and #raidWrites == 0, "and no raid CVar changed")
    Open("RaidGraphics")
    ok(RaidStatus():find("Active now", 1, true), "the page says it is active: " .. RaidStatus())
    Close()

    section("while it is active, other pages' changes go into the profile")
    Open("GraphicsPlus")
    Control("farclip"):SetValue(2000)
    VideoOptionsFrameOkay:Click()
    ok(CLIENT.cvars.farclip + 0 == 2000, "Okay on Graphics+ applies at once: " .. tostring(CLIENT.cvars.farclip))
    ok(CLIENT.cvars.farclipRaid + 0 == 2000,
        "the client adopted it, and the Raid Profile page's Okay left it: " .. tostring(CLIENT.cvars.farclipRaid))
    ok(CLIENT.cvars.environmentDetail == "1", "an Okay for farclip left the profile's environment detail alone")
    ok(Settings().farclip == 2000, "Graphics+ stores it")
    Open("RaidGraphics")
    ok(Label("farclipRaid") == "Farclip: 2000", "the page shows the adopted value: " .. Label("farclipRaid"))
    Control("farclipRaid"):SetValue(1500)
    VideoOptionsFrameApply:Click()
    ok(CLIENT.cvars.farclip == "1500", "a profile value changed inside applies at once: " .. tostring(CLIENT.cvars.farclip))
    Close()

    section("leaving puts the normal settings back")
    LeaveRaid()
    ok(not IsRaidGraphicsActive(), "the profile is no longer applied")
    ok(CLIENT.cvars.environmentDetail + 0 == 1.5, "environment detail is normal again: " .. tostring(CLIENT.cvars.environmentDetail))
    -- the normal farclip held at entry came back, then Graphics+ applied its own, changed inside
    ok(CLIENT.cvars.farclip + 0 == 2000, "farclip is Graphics+'s: " .. tostring(CLIENT.cvars.farclip))
    ok(CLIENT.cvars.farclipRaid == "1500", "the profile keeps its own: " .. tostring(CLIENT.cvars.farclipRaid))

    section("switching it off inside a raid puts the normal settings back at once")
    EnterRaid()
    ok(CLIENT.cvars.farclip == "1500", "inside again, the profile's farclip: " .. tostring(CLIENT.cvars.farclip))
    Open("RaidGraphics")
    Tick(Control("raidGraphics"))
    Control("farclipRaid"):SetValue(1100)
    raidWrites = {}
    VideoOptionsFrameOkay:Click()
    ok(raidWrites[1] == "raidGraphics=0", "switching off goes first: " .. table.concat(raidWrites, ", "))
    ok(not IsRaidGraphicsActive() and CLIENT.cvars.farclip + 0 == 2000,
        "the normal farclip is back, without the new raid value in between: " .. tostring(CLIENT.cvars.farclip))
    ok(CLIENT.cvars.farclipRaid == "1100", "the new raid value waits for the next raid")
    LeaveRaid()

    section("Raid Profile defaults")
    Open("RaidGraphics")
    raidWrites = {}
    OptionsFrame_SetCurrentToDefaults(window)
    ok(CLIENT.cvars.farclipRaid == "1000" and CLIENT.cvars.particleDensityRaid == "0.6"
        and CLIENT.cvars.groundEffectDistRaid == "70", "the profile's values are the defaults")
    ok(CLIENT.cvars.spellEffectLevelRaid == "" and CLIENT.cvars.dcSunRaysRaid == "", "keep normal where that is the default")
    ok(CLIENT.cvars.raidGraphics == "0", "the profile is off, its default")
    ok(#raidWrites == 5, "only the changed CVars were written: " .. table.concat(raidWrites, ", "))
    ok(Label("farclipRaid") == "Farclip: 1000" and Control("spellEffectLevelRaidKeep"):GetChecked(), "the controls follow")
    Close()
    noNewErrors("the Raid Profile page ran")
else
    section("no raid graphics profile")
    ok(Page("RaidGraphics") == nil, "an exe without the raid profile gets no Raid Profile page")
    for name in pairs(RAID_DEFAULTS) do
        ok(CLIENT.cvars[name] == nil, name .. " was not created")
    end
end

section("opening a page directly")
DCQOS:OpenVideoOptionsPage("GraphicsPlus")
ok(window:IsShown() and Page("GraphicsPlus"):IsVisible(), "the InfoBar's launcher lands on Graphics+")
Close()
if hasFog then
    DCQOS:OpenVideoOptionsPage("FogAndWater")
    ok(window:IsShown() and Page("FogAndWater"):IsVisible(), "and its Fog & Water entry on Fog & Water")
    Close()
end

noNewErrors("the pages ran")
T.Finish()
