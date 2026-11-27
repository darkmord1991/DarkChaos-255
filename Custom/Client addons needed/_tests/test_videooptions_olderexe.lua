-- test_videooptions.lua on a native exe older than the addon: it lacks the contact shadows' CVars (the 5768784c build
-- never registered them, 2026-11-11), so their controls must be left out and nothing may touch them. It has no raid
-- graphics profile either (no GetRaidGraphicsSettings, no raidGraphics CVars), so it gets no Raid Profile page, and
-- predates the volumetric fog and the water, so it gets no Fog & Water page.
MISSING_CVARS = { dcContactShadows = true, dcContactShadowsLength = true, dcContactShadowsStrength = true,
    raidGraphics = true,
    dcVolumetricFog = true, dcVolumetricFogDensity = true, dcVolumetricFogMist = true, dcVolumetricFogSun = true,
    dcVolumetricFogLights = true, dcVolumetricFogShafts = true, dcVolumetricFogTemporal = true,
    dcVolumetricFogDistance = true, dcVolumetricFogForever = true, dcForeverLight = true, dcVolumetricFogForeverBrightness = true,
    dcWater = true, dcWaterWaves = true, dcWaterFoam = true, dcWaterReflections = true, dcWaterWakes = true,
    dcWaterPbr = true, dcWaterPbrBrightness = true, dcWaterPbrMirror = true,
    dcWaterPbrShore = true, dcWaterLamps = true, dcLiquidMagma = true }
dofile("test_videooptions.lua")
