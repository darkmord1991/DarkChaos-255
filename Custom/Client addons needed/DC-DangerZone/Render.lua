-- DC-DangerZone / Render.lua --------------------------------------------------
-- Draws danger zones on the ground without touching the render engine.
--
-- "Retail" style: a textured ground decal.  A UI texture is always an
-- axis-aligned rectangle on screen, so a ground square seen in perspective (a
-- trapezoid) cannot be drawn with one texture.  It CAN be drawn as a stack of
-- thin strips: the ground square is oriented to the camera (one axis along
-- camera-right, the other along camera-forward), then cut into K strips across
-- the forward axis.  Points along camera-right lie at the same depth, so a
-- strip's near and far edges are exactly horizontal on screen and its bounding
-- box is a plain rectangle.  The 8-argument SetTexCoord maps the texture onto
-- that rectangle so that the strip's four projected corners land on the right
-- texels (exact at the corners; the error inside a thin strip is negligible).
-- Texture corners that fall outside the strip sample the texture's transparent
-- margin, which is why the shipped textures are padded (see Core.lua).
--
-- "Classic" style: the original projected dotted ring (48 glow dots).
--------------------------------------------------------------------------------

local addon = DCDangerZone
local Render = {}
addon.Render = Render

local cos, sin, sqrt = math.cos, math.sin, math.sqrt
-- 3.3.5 is Lua 5.1 (math.atan2); the test runner may be 5.4 (two-argument math.atan).
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
local min, max, abs, floor = math.min, math.max, math.abs, math.floor
local TWO_PI = 2 * math.pi

local RING_POINTS = 48
local DOT_MIN, DOT_MAX = 8, 44
local MAX_STRIP_PIXELS = 8192

--------------------------------------------------------------------------------
-- Frames and pools.  One frame per layer; frame level gives the draw order.
--------------------------------------------------------------------------------

local container = CreateFrame("Frame", "DCDangerZoneFrame", UIParent)
container:SetAllPoints(UIParent)
container:SetFrameStrata("BACKGROUND")
Render.container = container

local LAYERS = { "fill", "progress", "edge", "spinner", "dots", "label" }
local layerFrames = {}
for i, name in ipairs(LAYERS) do
    local f = CreateFrame("Frame", nil, container)
    f:SetAllPoints(container)
    f:SetFrameStrata("BACKGROUND")
    f:SetFrameLevel(i)
    layerFrames[name] = f
end

local pools = {}
local used = {}
Render._pools = pools -- read by the regression test; not part of the API

local function Acquire(layer)
    local pool = pools[layer]
    if not pool then
        pool = {}
        pools[layer] = pool
    end
    local n = (used[layer] or 0) + 1
    used[layer] = n
    local obj = pool[n]
    if not obj then
        local parent = layerFrames[layer]
        if layer == "label" then
            obj = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        else
            obj = parent:CreateTexture(nil, "ARTWORK")
        end
        pool[n] = obj
    end
    return obj
end

local function HideUnused()
    for layer, pool in pairs(pools) do
        for i = (used[layer] or 0) + 1, #pool do
            pool[i]:Hide()
        end
    end
end

function Render:HideAll()
    for layer in pairs(pools) do
        used[layer] = 0
    end
    HideUnused()
    self:SetFlash(false, 0)
end

-- Exposed for tests / diagnostics.
function Render:GetPoolStats()
    local stats = {}
    for layer, pool in pairs(pools) do
        stats[layer] = { allocated = #pool, used = used[layer] or 0 }
    end
    return stats
end

--------------------------------------------------------------------------------
-- Full-screen warning flash
--------------------------------------------------------------------------------

local flash = CreateFrame("Frame", "DCDangerZoneFlash", UIParent)
flash:SetAllPoints(UIParent)
flash:SetFrameStrata("BACKGROUND")
flash:SetFrameLevel(20)
local flashTex = flash:CreateTexture(nil, "ARTWORK")
flashTex:SetAllPoints(flash)
flashTex:SetTexture("Interface\\FullScreenTextures\\LowHealth")
flashTex:SetBlendMode("ADD")
flashTex:SetVertexColor(1, 0.2, 0.1, 1)
flash:Hide()
Render.flash = flash

function Render:SetFlash(shown, alpha)
    if shown then
        flash:SetAlpha(alpha or 0.3)
        flash:Show()
    else
        flash:Hide()
    end
end

--------------------------------------------------------------------------------
-- Projection
--------------------------------------------------------------------------------

local convertFn = nil
local uiScale, centerX, centerY = 1, 0, 0

-- World (x,y,z) -> offset from the container centre in UI units; nil when the
-- point is behind the camera or cannot be projected.
local function Project(wx, wy, wz)
    local ok, sx, sy, sz = pcall(convertFn, wx, wy, wz)
    if not ok or type(sx) ~= "number" or type(sy) ~= "number" then
        return nil
    end
    if type(sz) == "number" and sz <= 0 then
        return nil
    end
    return sx / uiScale - centerX, sy / uiScale - centerY
end
Render.Project = Project

-- Camera-aligned ground basis at a zone centre.  r = world direction that
-- projects horizontally (camera-right), f = perpendicular (camera-forward),
-- psi = world angle of r (used to keep textures world-fixed while the camera
-- turns).  nil when the centre does not project.
local basis = {}
local function ComputeBasis(cx, cy, cz)
    local px, py = Project(cx, cy, cz)
    if not px then
        return nil
    end
    local exx, exy = Project(cx + 1, cy, cz)
    local eyx, eyy = Project(cx, cy + 1, cz)
    if not exx or not eyx then
        return nil
    end
    exx, exy = exx - px, exy - py
    eyx, eyy = eyx - px, eyy - py

    -- direction d = (rx, ry) with  rx*exy + ry*eyy == 0
    local rx, ry = eyy, -exy
    local len = sqrt(rx * rx + ry * ry)
    if len < 1e-6 then
        rx, ry = 1, 0
    else
        rx, ry = rx / len, ry / len
    end
    if exx * rx + eyx * ry < 0 then      -- make r point to screen +x
        rx, ry = -rx, -ry
    end
    local fx, fy = -ry, rx
    if exy * fx + eyy * fy < 0 then      -- make f point to screen +y
        fx, fy = -fx, -fy
    end

    basis.px, basis.py = px, py
    basis.rx, basis.ry, basis.fx, basis.fy = rx, ry, fx, fy
    basis.psi = atan2(ry, rx)
    return basis
end
Render.ComputeBasis = ComputeBasis

--------------------------------------------------------------------------------
-- Strip decal
--------------------------------------------------------------------------------

local function ApplyTexture(tex, path, blend)
    if tex._path ~= path then
        tex:SetTexture(path)
        tex._path = path
    end
    if tex._blend ~= blend then
        tex:SetBlendMode(blend)
        tex._blend = blend
    end
end

-- (a,b) in the camera-aligned unit square -> (u,v) texcoords.  Rotates by the
-- (ca,sa) angle first, then maps [-1,1] onto [margin, 1-margin]; anything that
-- lands outside the texture is clamped (it only ever hits transparent margin).
local function Coord(a, b, ca, sa, margin, span)
    local ta = a * ca - b * sa
    local tb = a * sa + b * ca
    local u = margin + span * (ta + 1) * 0.5
    local v = margin + span * (1 - tb) * 0.5
    if u < 0 then u = 0 elseif u > 1 then u = 1 end
    if v < 0 then v = 0 elseif v > 1 then v = 1 end
    return u, v
end

-- Draws one textured decal of world radius `radius` at (cx,cy,cz) using the
-- basis from ComputeBasis.  `theta` rotates the texture (radians, world-fixed
-- when it equals -basis.psi).  Returns the number of strips drawn.
local function DrawDecal(layer, b, cx, cy, cz, radius, path, margin, r, g, bl, alpha, theta, blend, strips, screenW, screenH)
    local rx, ry, fx, fy = b.rx, b.ry, b.fx, b.fy
    local ca, sa = cos(theta), sin(theta)
    local span = 1 - 2 * margin
    local drawn = 0
    local limitX, limitY = screenW * 0.75, screenH * 0.75

    for j = 0, strips - 1 do
        local b0 = -1 + 2 * j / strips
        local b1 = b0 + 2 / strips
        local nlx, nly = Project(cx + radius * (-rx + b0 * fx), cy + radius * (-ry + b0 * fy), cz)
        local nrx, nry = Project(cx + radius * (rx + b0 * fx), cy + radius * (ry + b0 * fy), cz)
        local flx, fly = Project(cx + radius * (-rx + b1 * fx), cy + radius * (-ry + b1 * fy), cz)
        local frx, fry = Project(cx + radius * (rx + b1 * fx), cy + radius * (ry + b1 * fy), cz)
        if nlx and nrx and flx and frx then
            local yN = (nly + nry) * 0.5
            local yF = (fly + fry) * 0.5
            local top, bottom = max(yN, yF), min(yN, yF)
            local left, right = min(nlx, flx), max(nrx, frx)
            local wN, wF = nrx - nlx, frx - flx
            local width, height = right - left, top - bottom
            if width >= 0.5 and height >= 0.5 and wN > 0.25 and wF > 0.25
                and width < MAX_STRIP_PIXELS and height < MAX_STRIP_PIXELS
                and right > -limitX and left < limitX and top > -limitY and bottom < limitY then

                -- Texcoords of the rectangle's corners: the top edge is the
                -- near edge when yN >= yF, otherwise the far edge.
                local ulu, ulv, uru, urv, llu, llv, lru, lrv
                if yN >= yF then
                    ulu, ulv = Coord(-1 + 2 * (left - nlx) / wN, b0, ca, sa, margin, span)
                    uru, urv = Coord(-1 + 2 * (right - nlx) / wN, b0, ca, sa, margin, span)
                    llu, llv = Coord(-1 + 2 * (left - flx) / wF, b1, ca, sa, margin, span)
                    lru, lrv = Coord(-1 + 2 * (right - flx) / wF, b1, ca, sa, margin, span)
                else
                    ulu, ulv = Coord(-1 + 2 * (left - flx) / wF, b1, ca, sa, margin, span)
                    uru, urv = Coord(-1 + 2 * (right - flx) / wF, b1, ca, sa, margin, span)
                    llu, llv = Coord(-1 + 2 * (left - nlx) / wN, b0, ca, sa, margin, span)
                    lru, lrv = Coord(-1 + 2 * (right - nlx) / wN, b0, ca, sa, margin, span)
                end

                local tex = Acquire(layer)
                ApplyTexture(tex, path, blend)
                tex:SetVertexColor(r, g, bl, alpha)
                tex:SetTexCoord(ulu, ulv, llu, llv, uru, urv, lru, lrv)
                tex:ClearAllPoints()
                tex:SetPoint("BOTTOMLEFT", container, "CENTER", left, bottom)
                tex:SetSize(width, height)
                tex:Show()
                drawn = drawn + 1
            end
        end
    end
    return drawn
end
Render.DrawDecal = DrawDecal

--------------------------------------------------------------------------------
-- Classic dotted ring
--------------------------------------------------------------------------------

local pX, pY, pOK = {}, {}, {}

local function DrawDots(cx, cy, cz, radius, r, g, b, alpha)
    for p = 1, RING_POINTS do
        local ang = ((p - 1) / RING_POINTS) * TWO_PI
        local ox, oy = Project(cx + radius * cos(ang), cy + radius * sin(ang), cz)
        if ox then
            pX[p], pY[p], pOK[p] = ox, oy, true
        else
            pOK[p] = false
        end
    end

    local sumLen, cntLen = 0, 0
    for p = 1, RING_POINTS do
        local q = (p % RING_POINTS) + 1
        if pOK[p] and pOK[q] then
            local dx, dy = pX[q] - pX[p], pY[q] - pY[p]
            sumLen = sumLen + sqrt(dx * dx + dy * dy)
            cntLen = cntLen + 1
        end
    end
    local dotSize = cntLen > 0 and (sumLen / cntLen) * 1.7 or 12
    dotSize = max(DOT_MIN, min(DOT_MAX, dotSize))

    local drawn = 0
    for p = 1, RING_POINTS do
        if pOK[p] then
            local d = Acquire("dots")
            ApplyTexture(d, addon.DOT_TEXTURE, "ADD")
            d:SetSize(dotSize, dotSize)
            d:ClearAllPoints()
            d:SetPoint("CENTER", container, "CENTER", pX[p], pY[p])
            d:SetVertexColor(r, g, b, alpha)
            d:Show()
            drawn = drawn + 1
        end
    end
    return drawn
end
Render.DrawDots = DrawDots

--------------------------------------------------------------------------------
-- Per-frame API used by Core.lua
--------------------------------------------------------------------------------

local ctx = {}

function Render:OnSettingsChanged()
    -- nothing cached across settings yet; textures are re-applied per frame
end

function Render:Begin(db, now)
    for layer in pairs(pools) do
        used[layer] = 0
    end
    convertFn = addon.ResolveConvert()
    uiScale = UIParent:GetEffectiveScale() or 1
    if uiScale == 0 then
        uiScale = 1
    end
    centerX, centerY = UIParent:GetCenter()
    centerX, centerY = centerX or 0, centerY or 0
    ctx.db = db
    ctx.now = now
    ctx.strips = addon.STRIPS_BY_QUALITY[db.quality] or 10
    ctx.blend = db.additive and "ADD" or "BLEND"
    ctx.screenW = (UIParent.GetWidth and UIParent:GetWidth()) or 4096
    ctx.screenH = (UIParent.GetHeight and UIParent:GetHeight()) or 4096
    if not ctx.screenW or ctx.screenW < 64 then ctx.screenW = 4096 end
    if not ctx.screenH or ctx.screenH < 64 then ctx.screenH = 4096 end
end

function Render:End()
    HideUnused()
end

local function Brighten(c)
    return min(1, c * 0.5 + 0.5)
end

function Render:DrawZone(zone)
    local db = ctx.db
    if not convertFn then
        return
    end
    local style = db.style
    local cx, cy, cz, radius = zone.x, zone.y, zone.z, zone.radius
    local r, g, b, alpha = zone.r, zone.g, zone.b, zone.alpha
    local inside = zone.inside
    local pulse = inside and (0.8 + 0.2 * sin(ctx.now * 10)) or 1

    local drewDecal = false
    if style == "retail" or style == "both" then
        local bs = ComputeBasis(cx, cy, cz)
        if bs then
            local worldFixed = -bs.psi
            local strips, blend = ctx.strips, ctx.blend
            local sw, sh = ctx.screenW, ctx.screenH

            -- fill (profile texture override wins)
            local fillPath, fillMargin = addon:ResolveProfileTexture(zone.profile)
            if not fillPath then
                fillPath = addon.FILL_TEXTURES[db.fillTexture]
                fillMargin = addon.TEXTURE_MARGIN
            end
            if fillPath and db.fillOpacity > 0 then
                local n = DrawDecal("fill", bs, cx, cy, cz, radius, fillPath, fillMargin,
                    r, g, b, alpha * db.fillOpacity, worldFixed, blend, strips, sw, sh)
                drewDecal = drewDecal or n > 0

                -- progress disc: grows from the centre as the zone runs out
                if db.showProgress and zone.total and zone.total >= 0.5 then
                    local progress = 1 - zone.remaining / zone.total
                    if progress > 0.04 and progress < 1 then
                        DrawDecal("progress", bs, cx, cy, cz, radius * progress, fillPath, fillMargin,
                            Brighten(r), Brighten(g), Brighten(b), alpha * db.fillOpacity * 0.9,
                            worldFixed, blend, strips, sw, sh)
                    end
                end
            end

            local edgePath = addon.EDGE_TEXTURES[db.edgeTexture]
            if edgePath and db.edgeOpacity > 0 then
                local n = DrawDecal("edge", bs, cx, cy, cz, radius, edgePath, addon.TEXTURE_MARGIN,
                    Brighten(r), Brighten(g), Brighten(b), alpha * db.edgeOpacity * pulse,
                    worldFixed, "BLEND", strips, sw, sh)
                drewDecal = drewDecal or n > 0
            end

            local spinPath = addon.SPINNER_TEXTURES[db.spinner]
            if spinPath and db.spinnerOpacity > 0 then
                local spin = (ctx.now - (zone.firstSeen or ctx.now)) * db.spinSpeed
                DrawDecal("spinner", bs, cx, cy, cz, radius, spinPath, addon.TEXTURE_MARGIN,
                    Brighten(r), Brighten(g), Brighten(b), alpha * db.spinnerOpacity,
                    worldFixed + spin, "ADD", strips, sw, sh)
            end
        end
    end

    if style == "classic" or style == "both" or (style == "retail" and not drewDecal) then
        DrawDots(cx, cy, cz, radius, r, g, b, alpha * pulse)
    end

    if db.showTimer and zone.remaining and zone.remaining < 60 then
        local px, py = Project(cx, cy, cz)
        if px then
            local label = Acquire("label")
            local remaining = zone.remaining
            if remaining < 3 then
                label:SetText(string.format("%.1f", remaining))
            else
                label:SetText(tostring(floor(remaining + 0.5)))
            end
            label:SetTextColor(1, 1, 1, min(1, alpha + 0.2))
            label:ClearAllPoints()
            label:SetPoint("CENTER", container, "CENTER", px, py)
            label:Show()
        end
    end
end
