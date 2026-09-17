-- DC-DangerZone / Core.lua ----------------------------------------------------
-- Ground-AoE danger-zone telegraphs for the DarkChaos client.
--
-- The WotLKExtensions DLL watches spell-launch packets and, for casts that match
-- a DangerZoneVisualProfile row, buffers a zone {spellId, x, y, z, radius, r, g,
-- b, a, remaining}.  This addon polls GetActiveDangerZones() and draws each zone
-- on the ground in pure Lua by projecting world points to screen with the same
-- ConvertCoordsToScreenSpace native the ping system uses.
--
-- Core.lua owns settings, the profile lookup, zone bookkeeping (fade-in, total
-- duration, test zones), the player-inside warning and the slash command.
-- Render.lua draws; Options.lua is the Interface Options panel.
--------------------------------------------------------------------------------

DCDangerZone = DCDangerZone or {}
local addon = DCDangerZone

addon.name = "DC-DangerZone"
addon.version = "2.0.0"

-- Shipped textures live here.  Every .blp in this folder is a retail spell decal
-- re-padded so the visible circle fills exactly [MARGIN, 1-MARGIN] of the
-- texture (see Custom/Documentation/DangerZone_Telegraphs.md, "Textures").
addon.TEXTURE_ROOT = "Interface\\AddOns\\DC-DangerZone\\Textures\\"
addon.TEXTURE_MARGIN = 0.15

addon.FILL_TEXTURES = {
    glow = addon.TEXTURE_ROOT .. "dz_glow",
    disc = addon.TEXTURE_ROOT .. "dz_disc",
}
addon.EDGE_TEXTURES = {
    ring = addon.TEXTURE_ROOT .. "dz_ring",
    double = addon.TEXTURE_ROOT .. "dz_ring_double",
}
addon.SPINNER_TEXTURES = {
    reticle = addon.TEXTURE_ROOT .. "dz_reticle",
    swirl = addon.TEXTURE_ROOT .. "dz_swirl",
}
addon.DOT_TEXTURE = addon.TEXTURE_ROOT .. "ring_dot"

addon.defaults = {
    enabled = true,
    style = "retail",        -- "retail" (textured decal) | "classic" (dotted ring) | "both"
    fillTexture = "glow",    -- key into FILL_TEXTURES, or "none"
    edgeTexture = "ring",    -- key into EDGE_TEXTURES, or "none"
    spinner = "reticle",     -- key into SPINNER_TEXTURES, or "none"
    spinSpeed = 0.8,         -- radians per second
    fillOpacity = 0.55,
    edgeOpacity = 0.9,
    spinnerOpacity = 0.45,
    additive = false,        -- ADD blend (glowy) instead of alpha blend
    quality = 2,             -- 1 = 6 strips, 2 = 10, 3 = 16 (perspective accuracy)
    maxZones = 6,
    showTimer = true,        -- remaining seconds at the zone centre
    showProgress = true,     -- inner disc that grows as the zone runs out
    warnInside = true,       -- flash + sound while the player stands in a zone
    warnSound = true,
    warnFlash = true,
    fadeSeconds = 1.5,       -- fade-out over the last N seconds
    fadeInSeconds = 0.25,
}

addon.STRIPS_BY_QUALITY = { [1] = 6, [2] = 10, [3] = 16 }

addon.settings = nil
addon.testZones = {}
addon.seen = {}              -- zone key -> { firstSeen, total, lastSeen }
addon.profilesBySpell = nil  -- spellId -> DangerZoneVisualProfile row
addon.lastWarnSound = 0
addon.playerInside = false
addon.active = false

local floor, max, min, sqrt = math.floor, math.max, math.min, math.sqrt

--------------------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------------------

function addon:InitSettings()
    if self.settings then
        return self.settings
    end
    local db = rawget(_G, "DCDangerZoneDB")
    if type(db) ~= "table" then
        db = {}
        _G.DCDangerZoneDB = db
    end
    for k, v in pairs(self.defaults) do
        if db[k] == nil then
            db[k] = v
        end
    end
    self.settings = db
    return db
end

function addon:Set(key, value)
    local db = self:InitSettings()
    db[key] = value
    if self.Render and self.Render.OnSettingsChanged then
        self.Render:OnSettingsChanged(db)
    end
    if self.Options and self.Options.Refresh then
        self.Options:Refresh()
    end
end

function addon:Print(msg)
    print("|cffff4444DC-DangerZone|r: " .. tostring(msg))
end

--------------------------------------------------------------------------------
-- Natives (resolved late so a missing DLL just means "nothing to draw")
--------------------------------------------------------------------------------

function addon.ResolveConvert()
    local fn = rawget(_G, "ConvertCoordsToScreenSpace") or rawget(_G, "C_Ping_ConvertCoordsToScreenSpace")
    if type(fn) == "function" then
        return fn
    end
    return nil
end

function addon.ResolveGetZones()
    local fn = rawget(_G, "GetActiveDangerZones")
    if type(fn) == "function" then
        return fn
    end
    return nil
end

function addon.ResolveEntityPosition()
    local fn = rawget(_G, "ResolveEntityPositionByGUID") or rawget(_G, "C_Ping_ResolveEntityPositionByGUID")
    if type(fn) == "function" then
        return fn
    end
    return nil
end

function addon:HasNatives()
    return self.ResolveConvert() ~= nil and self.ResolveGetZones() ~= nil
end

-- World position of the player's own unit, or nil.  Goes through the DLL's
-- entity resolver (the same one the ping system uses for unit pings).
function addon:GetPlayerWorldPosition()
    local resolver = self.ResolveEntityPosition()
    local unitGuid = rawget(_G, "UnitGUID")
    if not resolver or type(unitGuid) ~= "function" then
        return nil
    end
    local ok, guid = pcall(unitGuid, "player")
    if not ok or type(guid) ~= "string" or guid == "" then
        return nil
    end
    local ok2, _, _, _, _, _, wx, wy, wz = pcall(resolver, guid)
    if not ok2 or type(wx) ~= "number" or type(wy) ~= "number" then
        return nil
    end
    return wx, wy, tonumber(wz) or 0
end

--------------------------------------------------------------------------------
-- Profiles (DangerZoneVisualProfile.cdbc rows, keyed by debugSpellId)
--------------------------------------------------------------------------------

function addon:LoadProfiles(force)
    if self.profilesBySpell and not force then
        return self.profilesBySpell
    end
    local map = {}
    local getter = rawget(_G, "GetDangerZoneVisualProfiles")
    if type(getter) == "function" then
        local ok, rows = pcall(getter)
        if ok and type(rows) == "table" then
            for _, row in ipairs(rows) do
                local spellId = tonumber(row.debugSpellId)
                if spellId and spellId > 0 then
                    map[spellId] = row
                end
            end
        end
    end
    self.profilesBySpell = map
    return map
end

function addon:GetProfile(spellId)
    local map = self:LoadProfiles(false)
    return map[tonumber(spellId) or 0]
end

-- A profile's modelPath may name a 2D texture instead of an M2.  Only our own
-- Textures folder follows the padded-margin convention; anything else is used
-- edge-to-edge.
function addon:ResolveProfileTexture(profile)
    if type(profile) ~= "table" then
        return nil
    end
    local path = profile.modelPath
    if type(path) ~= "string" or path == "" then
        return nil
    end
    local lower = string.lower(path)
    if not (string.find(lower, "%.blp$") or string.find(lower, "%.tga$")) then
        return nil
    end
    path = string.gsub(path, "%.[bB][lL][pP]$", "")
    path = string.gsub(path, "%.[tT][gG][aA]$", "")
    local margin = 0
    if string.find(lower, "interface\\addons\\dc%-dangerzone\\", 1) then
        margin = self.TEXTURE_MARGIN
    end
    return path, margin
end

--------------------------------------------------------------------------------
-- Zones
--------------------------------------------------------------------------------

local function ZoneKey(spellId, x, y)
    return (tonumber(spellId) or 0) .. ":" .. floor(x * 2 + 0.5) .. ":" .. floor(y * 2 + 0.5)
end

-- Test zones are Lua-only and let visuals be tuned without a matched spell.
function addon:AddTestZone(x, y, z, radius, seconds, r, g, b)
    local now = GetTime()
    local zone = {
        spellId = 0,
        x = x, y = y, z = z,
        radius = radius or 8,
        r = r or 1, g = g or 0.25, b = b or 0.1, a = 0.6,
        expires = now + (seconds or 8),
        total = seconds or 8,
        test = true,
    }
    self.testZones[#self.testZones + 1] = zone
    return zone
end

function addon:ClearTestZones()
    for i = #self.testZones, 1, -1 do
        self.testZones[i] = nil
    end
end

-- Reused output buffer: one table per slot, refilled each tick.
local zoneBuffer = {}

local function FillZone(slot, spellId, x, y, z, radius, r, g, b, a, remaining, test)
    local zone = zoneBuffer[slot]
    if not zone then
        zone = {}
        zoneBuffer[slot] = zone
    end
    zone.spellId = spellId
    zone.x, zone.y, zone.z = x, y, z
    zone.radius = radius
    zone.r, zone.g, zone.b, zone.a = r, g, b, a
    zone.remaining = remaining
    zone.test = test or false
    zone.key = ZoneKey(spellId, x, y)
    zone.inside = false
    zone.distance = nil
    return zone
end

-- Gathers native + test zones into zoneBuffer and returns the count.  Updates
-- the per-key bookkeeping (first sighting, inferred total duration).
function addon:CollectZones(now)
    local count = 0
    local getZones = self.ResolveGetZones()
    if getZones then
        local ok, zones = pcall(getZones)
        if ok and type(zones) == "table" then
            for _, z in ipairs(zones) do
                if type(z) == "table" and z.x and z.y and z.z and z.radius then
                    count = count + 1
                    FillZone(count, tonumber(z.spellId) or 0, z.x, z.y, z.z, z.radius,
                        tonumber(z.r) or 1, tonumber(z.g) or 0, tonumber(z.b) or 0,
                        tonumber(z.a) or 0.6, tonumber(z.remaining) or 999, false)
                end
            end
        end
    end

    for i = #self.testZones, 1, -1 do
        local t = self.testZones[i]
        local remaining = t.expires - now
        if remaining <= 0 then
            table.remove(self.testZones, i)
        else
            count = count + 1
            FillZone(count, 0, t.x, t.y, t.z, t.radius, t.r, t.g, t.b, t.a, remaining, true)
        end
    end

    for i = 1, count do
        local zone = zoneBuffer[i]
        local seen = self.seen[zone.key]
        if not seen then
            seen = { firstSeen = now, total = zone.remaining }
            local profile = self:GetProfile(zone.spellId)
            if profile and tonumber(profile.maxDurationMs) and profile.maxDurationMs > 0 then
                seen.total = profile.maxDurationMs / 1000
            end
            self.seen[zone.key] = seen
        elseif zone.remaining > seen.total then
            -- the DLL refreshed the zone on a re-cast
            seen.total = zone.remaining
            seen.firstSeen = now
        end
        seen.lastSeen = now
        zone.firstSeen = seen.firstSeen
        zone.total = seen.total
        zone.profile = self:GetProfile(zone.spellId)
    end

    -- forget zones that have been gone for a while
    for key, seen in pairs(self.seen) do
        if now - (seen.lastSeen or 0) > 2 then
            self.seen[key] = nil
        end
    end

    return count, zoneBuffer
end

local function SortByPriority(a, b)
    if a.inside ~= b.inside then
        return a.inside
    end
    if a.distance and b.distance and a.distance ~= b.distance then
        return a.distance < b.distance
    end
    return a.remaining < b.remaining
end

local sortBuffer = {}

--------------------------------------------------------------------------------
-- Warning (flash + sound) while standing inside a zone
--------------------------------------------------------------------------------

function addon:UpdateWarning(now, inside)
    local db = self.settings
    local wasInside = self.playerInside
    self.playerInside = inside
    if not (db.warnInside and inside) then
        if self.Render then
            self.Render:SetFlash(false, 0)
        end
        return
    end
    if db.warnFlash and self.Render then
        local pulse = 0.22 + 0.13 * math.sin(now * 8)
        self.Render:SetFlash(true, pulse)
    elseif self.Render then
        self.Render:SetFlash(false, 0)
    end
    if db.warnSound and (not wasInside or now - self.lastWarnSound > 2.5) then
        self.lastWarnSound = now
        local playSound = rawget(_G, "PlaySound")
        if type(playSound) == "function" then
            pcall(playSound, "RaidWarning")
        end
    end
end

--------------------------------------------------------------------------------
-- Per-tick driver
--------------------------------------------------------------------------------

local IDLE_INTERVAL = 0.10
local ACTIVE_INTERVAL = 1 / 40

function addon:Tick(now)
    local db = self:InitSettings()
    local render = self.Render
    if not render then
        return false
    end

    if not db.enabled or not self.ResolveConvert() then
        render:HideAll()
        self:UpdateWarning(now, false)
        return false
    end

    local count, zones = self:CollectZones(now)
    if count == 0 then
        render:HideAll()
        self:UpdateWarning(now, false)
        return false
    end

    local px, py = self:GetPlayerWorldPosition()
    local anyInside = false
    for i = 1, count do
        local zone = zones[i]
        if px then
            local dx, dy = zone.x - px, zone.y - py
            zone.distance = sqrt(dx * dx + dy * dy)
            zone.inside = zone.distance <= zone.radius + 0.5
            if zone.inside then
                anyInside = true
            end
        end
        sortBuffer[i] = zone
    end
    for i = #sortBuffer, count + 1, -1 do
        sortBuffer[i] = nil
    end
    if count > 1 then
        table.sort(sortBuffer, SortByPriority)
    end

    render:Begin(db, now)
    local drawn = 0
    for i = 1, count do
        if drawn >= db.maxZones then
            break
        end
        local zone = sortBuffer[i]
        local fadeOut = min(1, max(0, zone.remaining / max(0.01, db.fadeSeconds)))
        local fadeIn = min(1, max(0, (now - zone.firstSeen) / max(0.01, db.fadeInSeconds)))
        zone.alpha = min(1, zone.a) * fadeOut * fadeIn
        if zone.alpha > 0.01 then
            render:DrawZone(zone)
            drawn = drawn + 1
        end
    end
    render:End()

    self:UpdateWarning(now, anyInside)
    return true
end

local driver = CreateFrame("Frame", "DCDangerZoneDriver", UIParent)
local accum = 0
driver:SetScript("OnUpdate", function(_, elapsed)
    accum = accum + elapsed
    local interval = addon.active and ACTIVE_INTERVAL or IDLE_INTERVAL
    if accum < interval then
        return
    end
    accum = 0
    local ok, active = pcall(addon.Tick, addon, GetTime())
    if ok then
        addon.active = active and true or false
    else
        addon.active = false
        if not addon._tickErrorShown then
            addon._tickErrorShown = true
            addon:Print("render error: " .. tostring(active))
        end
    end
end)
driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        addon:InitSettings()
        addon:LoadProfiles(true)
        if addon.Options and addon.Options.Build then
            addon.Options:Build()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        for key in pairs(addon.seen) do
            addon.seen[key] = nil
        end
        addon:ClearTestZones()
        if addon.Render then
            addon.Render:HideAll()
        end
    end
end)
driver:Show()
addon.driver = driver

--------------------------------------------------------------------------------
-- Slash command
--------------------------------------------------------------------------------

local function Status()
    local db = addon:InitSettings()
    local n = 0
    local getZones = addon.ResolveGetZones()
    if getZones then
        local ok, zones = pcall(getZones)
        if ok and type(zones) == "table" then
            n = #zones
        end
    end
    local profiles = 0
    for _ in pairs(addon:LoadProfiles(false)) do
        profiles = profiles + 1
    end
    addon:Print(string.format("enabled=%s style=%s native=%s profiles=%d activeZones=%d testZones=%d inside=%s",
        tostring(db.enabled), tostring(db.style), addon:HasNatives() and "yes" or "no",
        profiles, n, #addon.testZones, tostring(addon.playerInside)))
end

local function Usage()
    addon:Print("/dz on|off|status|config|reload")
    addon:Print("/dz test [radius] [seconds]  - spawn a test zone at your feet")
    addon:Print("/dz clear                   - remove test zones")
    addon:Print("/dz style retail|classic|both")
end

function addon:HandleSlash(msg)
    local db = self:InitSettings()
    msg = string.lower(tostring(msg or ""))
    local cmd, rest = string.match(msg, "^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd or ""
    if cmd == "off" then
        self:Set("enabled", false)
        if self.Render then
            self.Render:HideAll()
        end
        self:Print("disabled")
    elseif cmd == "on" then
        self:Set("enabled", true)
        self:Print("enabled")
    elseif cmd == "status" or cmd == "" then
        Status()
    elseif cmd == "reload" then
        self:LoadProfiles(true)
        Status()
    elseif cmd == "config" or cmd == "options" then
        if self.Options and self.Options.Open then
            self.Options:Open()
        else
            self:Print("options panel unavailable")
        end
    elseif cmd == "style" then
        if rest == "retail" or rest == "classic" or rest == "both" then
            self:Set("style", rest)
            self:Print("style = " .. rest)
        else
            Usage()
        end
    elseif cmd == "test" then
        local radius, seconds = string.match(rest, "^(%d+%.?%d*)%s*(%d*%.?%d*)")
        radius = tonumber(radius) or 8
        seconds = tonumber(seconds) or 8
        local px, py, pz = self:GetPlayerWorldPosition()
        if not px then
            self:Print("cannot resolve your world position (DLL native missing)")
            return
        end
        self:AddTestZone(px, py, pz, radius, seconds)
        self:Print(string.format("test zone: radius %.1f yd for %.1f s", radius, seconds))
    elseif cmd == "clear" then
        self:ClearTestZones()
        self:Print("test zones cleared")
    else
        Usage()
    end
end

SLASH_DCDANGERZONE1 = "/dz"
SLASH_DCDANGERZONE2 = "/dangerzone"
local cmdList = rawget(_G, "SlashCmdList")
if type(cmdList) == "table" then
    cmdList["DCDANGERZONE"] = function(msg)
        addon:HandleSlash(msg)
    end
end
