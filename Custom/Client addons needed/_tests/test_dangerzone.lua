-- DC-DangerZone v2: retail-style ground decals drawn as camera-aligned strips.
--
-- Loads the real addon files in TOC order against a fake top-down projection
-- (screen x = world y * 10, screen y = world x * 8, always in front of the
-- camera) and pins the geometry the renderer must produce: the strips of a
-- zone tile its projected square exactly, texcoords stay inside the padded
-- texture, pools are reused, the inside-zone warning fires, partial projection
-- failure degrades per strip instead of dropping the zone, and the profile's
-- modelPath/maxDurationMs feed the fill texture and the progress disc.
dofile("wowsim.lua")
local ROOT = os.getenv("DC_ADDON_ROOT") or [[K:\Dark-Chaos\DarkChaos-255-Master\Custom\Client addons needed\]]
local pass, fail = 0, 0
local function ok(c, m) if c then pass = pass + 1; print("  PASS " .. m) else fail = fail + 1; print("  FAIL " .. m) end end
local function near(a, b, eps) return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (eps or 1e-6) end

-- ---------------------------------------------------------------- stubs --
_G.UIParent = CreateFrame("Frame")
UIParent.GetEffectiveScale = function() return 1 end
UIParent.GetCenter = function() return 512, 384 end
UIParent.GetWidth = function() return 1024 end
UIParent.GetHeight = function() return 768 end
_G.SlashCmdList = {}
_G.UnitGUID = function() return "0x0000000000000001" end

local player = { x = 50, y = 50, z = 0 }
_G.ResolveEntityPositionByGUID = function()
    return "0x1", "unit", nil, nil, nil, player.x, player.y, player.z
end

local failAboveX = nil
_G.ConvertCoordsToScreenSpace = function(x, y, z)
    if failAboveX and x > failAboveX then return 0, 0, 0 end
    return 512 + y * 10, 384 + x * 8, 1
end

local nativeZones = {}
_G.GetActiveDangerZones = function() return nativeZones end
local profiles = {}
_G.GetDangerZoneVisualProfiles = function() return profiles end

local sounds = 0
_G.PlaySound = function() sounds = sounds + 1 end

_G.DCDangerZoneDB = nil

for _, f in ipairs({ "Core.lua", "Render.lua", "Options.lua" }) do
    dofile(ROOT .. [[DC-DangerZone\]] .. f)
end
local addon = _G.DCDangerZone
local Render = addon.Render
local driver = addon.driver

local function tick() advance(0.2) end
-- a freshly seen zone fades in over 0.25 s; settle past that before asserting on alpha
local function settle() tick(); tick(); tick() end
local function stats(layer)
    local s = Render:GetPoolStats()[layer]
    return s and s.used or 0, s and s.allocated or 0
end
-- The textures in use this frame, in Acquire order.
local function pool(layer)
    local out = {}
    for i = 1, stats(layer) do out[i] = Render._pools[layer][i] end
    return out
end

print("== 1. idle: nothing allocated, driver stays on the slow poll ==")
driver._scripts.OnEvent(driver, "PLAYER_LOGIN")
ok(driver:IsShown(), "driver frame is shown")
tick()
ok(addon.active == false, "no zones -> inactive")
ok(next(Render:GetPoolStats()) == nil, "no textures allocated while idle")

print("== 2. one zone at (10,20) r=10: strips tile the projected square ==")
nativeZones[1] = { spellId = 1, x = 10, y = 20, z = 0, radius = 10, r = 1, g = 0, b = 0, a = 0.6, remaining = 5 }
settle()
ok(addon.active == true, "zone present -> active")
local fillUsed = stats("fill")
ok(fillUsed == 10, "medium quality draws 10 fill strips (got " .. fillUsed .. ")")
ok(stats("edge") == 10, "10 edge strips")
ok(stats("spinner") == 10, "10 spinner strips")
ok(stats("progress") == 0, "no progress disc at 0% elapsed")
ok(stats("dots") == 0, "retail style draws no dots when the decal projected")
local labels = pool("label")
ok(#labels == 1 and labels[1]._text == "5", "countdown label shows whole seconds (" .. tostring(labels[1] and labels[1]._text) .. ")")

local fills = pool("fill")
local sumH, minB, maxT, minL, maxR = 0, math.huge, -math.huge, math.huge, -math.huge
local minU, maxU, minV, maxV = math.huge, -math.huge, math.huge, -math.huge
for _, t in ipairs(fills) do
    sumH = sumH + t._h
    local left, bottom = t._point[4], t._point[5]
    minB = math.min(minB, bottom); maxT = math.max(maxT, bottom + t._h)
    minL = math.min(minL, left); maxR = math.max(maxR, left + t._w)
    for i, c in ipairs(t._texcoord) do
        if i % 2 == 1 then minU = math.min(minU, c); maxU = math.max(maxU, c)
        else minV = math.min(minV, c); maxV = math.max(maxV, c) end
    end
end
ok(fills[1]._tex[1] == addon.FILL_TEXTURES.glow, "fill strip uses the padded glow texture")
ok(fills[1]._vc[1] == 1 and fills[1]._vc[2] == 0 and fills[1]._vc[3] == 0, "fill strip tinted with the zone colour")
ok(near(fills[1]._vc[4], 0.6 * 0.55, 1e-6), "fill alpha = zone alpha * fill opacity")
ok(near(sumH, 160, 0.5), "strip heights sum to the projected square height 160 (got " .. sumH .. ")")
ok(near(minB, 0, 0.5) and near(maxT, 160, 0.5), "strips span screen y 0..160 (world x 0..20)")
ok(near(minL, 100, 0.5) and near(maxR, 300, 0.5), "strips span screen x 100..300 (world y 10..30)")
-- The texture is world-fixed (rotated by the camera yaw), so individual corners
-- swap u/v depending on the view; the union of all strip corners must still
-- cover exactly the padded content square [margin, 1-margin]^2 and never leave
-- the texture.
local m = addon.TEXTURE_MARGIN
ok(near(minU, m, 1e-3) and near(maxU, 1 - m, 1e-3), "u spans margin..1-margin over the whole decal")
ok(near(minV, m, 1e-3) and near(maxV, 1 - m, 1e-3), "v spans margin..1-margin over the whole decal")
ok(minU >= 0 and maxU <= 1 and minV >= 0 and maxV <= 1, "every texcoord stays inside [0,1]")

print("== 3. pools are reused ==")
local _, allocFill = stats("fill")
tick()
local _, allocFill2 = stats("fill")
ok(allocFill2 == allocFill, "second frame allocates no new fill textures")

print("== 4. standing inside the zone warns ==")
ok(not Render.flash:IsShown(), "flash hidden while outside")
player.x, player.y = 12, 22
tick()
ok(addon.playerInside == true, "player inside detected from ResolveEntityPositionByGUID")
ok(Render.flash:IsShown(), "screen flash shown while inside")
ok(sounds == 1, "warning sound played once on entry")
tick()
ok(sounds == 1, "no repeat inside the cooldown")
player.x, player.y = 50, 50
tick()
ok(not Render.flash:IsShown(), "flash hidden after leaving")
addon:Set("warnInside", false)
player.x, player.y = 12, 22
tick()
ok(not Render.flash:IsShown() and sounds == 1, "warnInside=false suppresses flash and sound")
addon:Set("warnInside", true)
player.x, player.y = 50, 50
tick()

print("== 5. fade-out and progress disc ==")
nativeZones[1].remaining = 1.0
settle()
fills = pool("fill")
ok(near(fills[1]._vc[4], 0.6 * (1.0 / 1.5) * 0.55, 1e-6), "alpha fades over the last 1.5 s")
local prog = pool("progress")
local progH = 0
for _, t in ipairs(prog) do progH = progH + t._h end
ok(#prog == 10 and near(progH, 160 * 0.8, 0.5), "progress disc at 80% elapsed covers 80% of the height (got " .. progH .. ")")

print("== 6. zone gone -> everything hidden ==")
nativeZones[1] = nil
tick()
ok(stats("fill") == 0 and stats("edge") == 0 and stats("label") == 0, "no strips used after the zone expired")
local hiddenAll = true
for _, t in ipairs(Render._pools.fill) do if t:IsShown() then hiddenAll = false end end
ok(hiddenAll, "pooled fill textures are hidden, not leaked on screen")
ok(addon.active == false, "driver drops back to idle polling")

print("== 7. classic style and disabled ==")
nativeZones[1] = { spellId = 1, x = 10, y = 20, z = 0, radius = 10, r = 0, g = 1, b = 0, a = 0.6, remaining = 5 }
addon:HandleSlash("style classic")
tick()
ok(stats("dots") == 48 and stats("fill") == 0, "classic style draws the 48-dot ring only")
addon:HandleSlash("style both")
tick()
ok(stats("dots") == 48 and stats("fill") == 10, "both = dots + decal")
addon:HandleSlash("off")
tick()
ok(stats("dots") == 0 and stats("fill") == 0, "/dz off draws nothing")
addon:HandleSlash("on")
addon:HandleSlash("style retail")

print("== 8. partial projection failure degrades per strip ==")
failAboveX = 15
tick()
ok(stats("fill") == 7, "strips whose far corners are behind the camera are skipped (7 of 10 drawn, got " .. stats("fill") .. ")")
ok(stats("dots") == 0, "no dot fallback while some strips still project")
failAboveX = -100
tick()
ok(stats("fill") == 0 and stats("dots") == 0, "nothing projects -> nothing drawn, no error")
failAboveX = nil

print("== 9. profile modelPath and maxDurationMs ==")
profiles[1] = { id = 1, debugSpellId = 42938, maxDurationMs = 8000,
    modelPath = "Interface\\AddOns\\DC-DangerZone\\Textures\\dz_disc.blp" }
addon:LoadProfiles(true)
nativeZones[1] = { spellId = 42938, x = 10, y = 20, z = 0, radius = 10, r = 0.3, g = 0.6, b = 1, a = 0.55, remaining = 4 }
settle()
fills = pool("fill")
ok(fills[1]._tex[1] == addon.TEXTURE_ROOT .. "dz_disc", "profile modelPath overrides the fill texture")
prog = pool("progress")
progH = 0
for _, t in ipairs(prog) do progH = progH + t._h end
ok(near(progH, 80, 0.5), "total from maxDurationMs (8 s) -> 4 s remaining = 50% progress (got " .. progH .. ")")

print("== 10. slash test zone ==")
nativeZones[1] = nil
player.x, player.y = 30, 40
addon:HandleSlash("test 6 4")
ok(#addon.testZones == 1 and addon.testZones[1].radius == 6, "/dz test spawns a test zone at the player")
settle()
ok(stats("fill") == 10, "test zone renders like a native one")
advance(4.5)
ok(#addon.testZones == 0, "test zone expires")
addon:HandleSlash("status")
addon:HandleSlash("clear")

print(string.format("RESULT: %d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
