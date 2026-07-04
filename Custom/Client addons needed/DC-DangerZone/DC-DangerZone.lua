-- DC-DangerZone -------------------------------------------------------------
-- Draws a ground ring at each active danger zone reported by the WotLKExtensions
-- GetActiveDangerZones() native (populated by the DANGERZONE_PATCH spell-packet
-- reader). Pure Lua: it projects the AoE circle's WORLD circumference points to
-- screen with the proven ConvertCoordsToScreenSpace native (same one the ping
-- system uses) and lays soft glow dots along the ring, sized to overlap into a
-- continuous circle. Perspective-anchored to the ground; no render-engine calls.
--
-- Note: a true FILLED ground decal (like retail's AoE zones) is engine-rendered
-- and not achievable in pure Lua; this is the projected-ring outline.
----------------------------------------------------------------------------------

local RING_POINTS     = 48     -- samples around the world circle
local MAX_ZONES       = 4      -- rings drawn at once
local UPDATE_INTERVAL = 0.03   -- ~33 Hz
local FADE_SECONDS    = 1.5    -- fade out over the last N seconds
local DOT_MIN, DOT_MAX = 8, 44 -- adaptive dot size clamp (px)
local DOT_TEXTURE     = "Interface\\AddOns\\DC-DangerZone\\ring_dot"

local cos, sin, sqrt = math.cos, math.sin, math.sqrt
local min, max = math.min, math.max
local TWO_PI = 2 * math.pi

local function ResolveConvert()
    return rawget(_G, "ConvertCoordsToScreenSpace")
        or rawget(_G, "C_Ping_ConvertCoordsToScreenSpace")
end
local function ResolveGetZones()
    return rawget(_G, "GetActiveDangerZones")
end

local container = CreateFrame("Frame", "DCDangerZoneFrame", UIParent)
container:SetAllPoints(UIParent)
container:SetFrameStrata("BACKGROUND")

local dots = {}
local function AcquireDot(i)
    local d = dots[i]
    if not d then
        d = container:CreateTexture(nil, "OVERLAY")
        d:SetTexture(DOT_TEXTURE)
        d:SetBlendMode("ADD")
        dots[i] = d
    end
    return d
end

local function HideDotsFrom(startIndex)
    for i = startIndex, #dots do
        dots[i]:Hide()
    end
end

-- Reused per-frame projection buffers (avoid GC churn).
local pX, pY, pOK = {}, {}, {}

-- World (x,y,z) -> UIParent-center-relative offset, mirroring PingSystem's
-- ResolveWorldScreenOffsets. Returns nil when behind the camera / unprojectable.
local function WorldToScreenOffset(convertFn, wx, wy, wz)
    local ok, sx, sy, sz = pcall(convertFn, wx, wy, wz)
    if not ok or type(sx) ~= "number" or type(sy) ~= "number" then
        return nil
    end
    if type(sz) == "number" and sz <= 0 then
        return nil
    end
    local scale = UIParent:GetEffectiveScale()
    if scale and scale ~= 0 then
        sx = sx / scale
        sy = sy / scale
    end
    local cx, cy = UIParent:GetCenter()
    if not cx or not cy then
        return nil
    end
    return sx - cx, sy - cy
end

local accum = 0
local function OnUpdate(self, elapsed)
    accum = accum + elapsed
    if accum < UPDATE_INTERVAL then
        return
    end
    accum = 0

    local db = DCDangerZoneDB
    if db and db.enabled == false then
        HideDotsFrom(1)
        return
    end

    local convertFn = ResolveConvert()
    local getZones = ResolveGetZones()
    if type(convertFn) ~= "function" or type(getZones) ~= "function" then
        HideDotsFrom(1)
        return
    end

    local ok, zones = pcall(getZones)
    if not ok or type(zones) ~= "table" or #zones == 0 then
        HideDotsFrom(1)
        return
    end

    local dotIndex = 0
    local zoneCount = min(#zones, MAX_ZONES)
    for zi = 1, zoneCount do
        local z = zones[zi]
        if type(z) == "table" and z.x and z.y and z.z and z.radius then
            local remaining = tonumber(z.remaining) or 999
            local fade = min(1, max(0, remaining / FADE_SECONDS))
            local alpha = min(1, (tonumber(z.a) or 0.6)) * fade
            local r = tonumber(z.r) or 1
            local g = tonumber(z.g) or 0
            local b = tonumber(z.b) or 0

            if alpha > 0.01 then
                -- Project the circle's circumference.
                for p = 1, RING_POINTS do
                    local ang = ((p - 1) / RING_POINTS) * TWO_PI
                    local ox, oy = WorldToScreenOffset(convertFn,
                        z.x + z.radius * cos(ang),
                        z.y + z.radius * sin(ang),
                        z.z)
                    if ox then
                        pX[p], pY[p], pOK[p] = ox, oy, true
                    else
                        pOK[p] = false
                    end
                end

                -- Size dots to ~1.7x the mean on-screen segment so they overlap
                -- into a continuous ring regardless of camera distance.
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

                for p = 1, RING_POINTS do
                    if pOK[p] then
                        dotIndex = dotIndex + 1
                        local d = AcquireDot(dotIndex)
                        d:SetSize(dotSize, dotSize)
                        d:ClearAllPoints()
                        d:SetPoint("CENTER", container, "CENTER", pX[p], pY[p])
                        d:SetVertexColor(r, g, b, alpha)
                        d:Show()
                    end
                end
            end
        end
    end

    HideDotsFrom(dotIndex + 1)
end

container:SetScript("OnUpdate", OnUpdate)

-- Minimal control: /dz on|off|status
SLASH_DCDANGERZONE1 = "/dz"
SlashCmdList["DCDANGERZONE"] = function(msg)
    DCDangerZoneDB = DCDangerZoneDB or { enabled = true }
    local arg = string.lower(tostring(msg or "")):match("^%s*(%S*)")
    if arg == "off" then
        DCDangerZoneDB.enabled = false
        HideDotsFrom(1)
        print("|cffff4444DC-DangerZone|r: disabled")
    elseif arg == "on" then
        DCDangerZoneDB.enabled = true
        print("|cff44ff44DC-DangerZone|r: enabled")
    else
        local getZones = ResolveGetZones()
        local n = 0
        if type(getZones) == "function" then
            local ok, zones = pcall(getZones)
            if ok and type(zones) == "table" then n = #zones end
        end
        print(string.format("DC-DangerZone: enabled=%s  native=%s  activeZones=%d",
            tostring(DCDangerZoneDB.enabled ~= false),
            (ResolveConvert() and ResolveGetZones()) and "yes" or "no", n))
    end
end
