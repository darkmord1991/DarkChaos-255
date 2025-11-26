local addonName, addonTable = ...
addonTable = addonTable or {}

local Pins = addonTable.Pins or {}
local UI = addonTable.UI or {}
local Debug = _G.DC_DebugUtils

local Core = {}
addonTable.Core = Core

local state = {
    addonName = addonName,
    hotspots = {},
    config = {
        experienceBonus = 100,
    },
    sessionStart = GetTime(),
    lastPlayerPos = nil,
}
addonTable.state = state
Core.state = state

local function DebugPrint(...)
    if Debug and Debug.PrintMulti then
        Debug:PrintMulti("DC-Hotspot", (state.db and state.db.debug) or false, ...)
    elseif state.db and state.db.debug and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[DC-Hotspot]|r " .. table.concat({...}, " "))
    end
end

local defaults = {
    version = 1,
    showMinimapPins = true,
    showWorldPins = true,
    showWorldLabels = true,
    showPopup = true,
    popupDuration = 4,
    announce = true,
    announceExpire = true,
    showListOnLogin = false,
    spawnSound = nil,
    expireSound = nil,
    debug = false,
    cache = {},
    lockWorldMap = true,
    pinIconStyle = "xp",  -- Default to golden orb (XP themed)
    customIconTexture = "",
}

local function NowEpoch()
    if GetServerTime then
        return GetServerTime()
    end
    return time()
end

local function CopyInto(src, dest)
    for k, v in pairs(src) do
        if type(v) == "table" then
            dest[k] = dest[k] or {}
            CopyInto(v, dest[k])
        elseif dest[k] == nil then
            dest[k] = v
        end
    end
end

local function CloneTable(tbl)
    local copy = {}
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            copy[k] = CloneTable(v)
        else
            copy[k] = v
        end
    end
    return copy
end

local function ResolveZoneName(zoneId)
    if not zoneId or zoneId == 0 then
        return nil
    end
    if C_Map and C_Map.GetAreaInfo then
        local name = C_Map.GetAreaInfo(zoneId)
        if name and name ~= "" then
            return name
        end
    end
    if GetMapNameByID then
        local name = GetMapNameByID(zoneId)
        if name and name ~= "" then
            return name
        end
    end
    return string.format("Zone %s", tostring(zoneId))
end

local function NormalizeNumber(value)
    if not value then return nil end
    return tonumber(value)
end

local function BuildHotspotRecord(payload)
    local id = NormalizeNumber(payload.id)
    if not id then return nil end

    local dur = NormalizeNumber(payload.dur) or 0
    local nowSession = GetTime()
    local nowEpoch = NowEpoch()
    local record = {
        id = id,
        map = NormalizeNumber(payload.map),
        zoneId = NormalizeNumber(payload.zone),
        zone = ResolveZoneName(NormalizeNumber(payload.zone)),
        x = NormalizeNumber(payload.x),
        y = NormalizeNumber(payload.y),
        z = NormalizeNumber(payload.z),
        nx = NormalizeNumber(payload.nx),
        ny = NormalizeNumber(payload.ny),
        bonus = NormalizeNumber(payload.bonus) or state.config.experienceBonus,
        icon = NormalizeNumber(payload.icon),
        tex = payload.tex,
        texid = NormalizeNumber(payload.texid),
        expire = nowSession + dur,
        expireEpoch = nowEpoch + dur,
        raw = payload.raw,
    }

    -- carry normalized coordinates if server sent percentages instead of 0..1
    if record.nx and record.nx > 1 then
        record.nx = record.nx / 100
    end
    if record.ny and record.ny > 1 then
        record.ny = record.ny / 100
    end

    return record
end

local function SerializeForCache(record)
    if not record or not record.id then return nil end
    return {
        id = record.id,
        map = record.map,
        zoneId = record.zoneId,
        zone = record.zone,
        x = record.x,
        y = record.y,
        z = record.z,
        nx = record.nx,
        ny = record.ny,
        bonus = record.bonus,
        icon = record.icon,
        tex = record.tex,
        texid = record.texid,
        expireEpoch = record.expireEpoch,
    }
end

function Core:PersistHotspot(record)
    if not state.db then return end
    state.db.cache = state.db.cache or {}
    if record.expireEpoch and record.expireEpoch > NowEpoch() then
        state.db.cache[record.id] = SerializeForCache(record)
    else
        state.db.cache[record.id] = nil
    end
end

local function ParsePayloadString(payload)
    if not payload or payload == "" then
        return nil
    end
    
    -- Format 1: HOTSPOT_ADDON|id:31|map:0|zone:10|x:-4739.6|y:-2212.5|dur:1800
    if string.find(payload, "HOTSPOT_ADDON", 1, true) then
        local data = { raw = payload }
        for token in string.gmatch(payload, "[^|]+") do
            if token == "HOTSPOT_ADDON" then
                data.tag = token
            else
                local key, value = token:match("^(%w+):(.*)$")
                if key then
                    data[key] = value
                end
            end
        end
        if data.tag == "HOTSPOT_ADDON" then
            return data
        end
    end
    
    -- Format 2: Teleport confirmation message
    -- "Teleported to Hotspot ID 45 on map 1 (zone Ashenvale) at (-2892.9, -4884.0, -53.8)"
    local teleportId, teleportMap, teleportZone, teleportX, teleportY, teleportZ = 
        payload:match("Teleported to Hotspot ID (%d+) on map (%d+) %(zone ([^%)]+)%) at %(([%-%d%.]+), ([%-%d%.]+), ([%-%d%.]+)%)")
    if teleportId then
        local data = {
            raw = payload,
            id = teleportId,
            map = teleportMap,
            zone = teleportZone, -- This is the zone name, not ID - may need lookup
            x = teleportX,
            y = teleportY,
            z = teleportZ,
            teleported = true -- Mark this as a teleport confirmation
        }
        return data
    end
    
    -- Format 3: "ID: 31 | Map: 0 | Zone: Duskwood (10) | Pos: (-4739.6, -2212.5, 534.1) | Time Left: 30m"
    -- This is the list format from your server
    local id = payload:match("ID:%s*(%d+)")
    if id then
        local data = { raw = payload }
        data.id = id
        
        -- Extract map
        local map = payload:match("Map:%s*(%d+)")
        if map then data.map = map end
        
        -- Extract zone from "Zone: Name (ID)"
        local zoneName, zoneId = payload:match("Zone:%s*([^%(]+)%s*%((%d+)%)")
        if zoneId then data.zone = zoneId end
        
        -- Extract coordinates from "Pos: (x, y, z)"
        local x, y, z = payload:match("Pos:%s*%(([%-%d%.]+),%s*([%-%d%.]+),%s*([%-%d%.]+)%)")
        if x then data.x = x end
        if y then data.y = y end
        if z then data.z = z end
        
        -- Extract time left and convert to duration in seconds
        local timeValue, timeUnit = payload:match("Time Left:%s*(%d+)(%w+)")
        if timeValue then
            local dur = tonumber(timeValue)
            if dur then
                if timeUnit == "m" or timeUnit == "min" then
                    dur = dur * 60
                elseif timeUnit == "h" or timeUnit == "hr" then
                    dur = dur * 3600
                elseif timeUnit == "s" or timeUnit == "sec" then
                    -- already in seconds
                end
                data.dur = tostring(dur)
            end
        end
        
        return data
    end
    
    -- Format 3: Header message "Active Hotspots: 4" - ignore
    if payload:match("Active Hotspots:%s*%d+") then
        return nil
    end
    
    -- Format 4: Ignore upgrade token messages "+X Upgrade Tokens"
    if payload:match("^%+?%d+%s+[Uu]pgrade%s+[Tt]okens") then
        return nil
    end
    
    -- Format 5: Ignore messages with % placeholders like "+%u Upgrade Tokens"
    if payload:match("%%[ud]") then
        return nil
    end
    
    return nil
end

local function IsHotspotPayloadCandidate(payload)
    if not payload or payload == "" then
        return false
    end

    if payload:find("HOTSPOT", 1, true) or payload:find("Hotspot", 1, true) then
        return true
    end

    if payload:find("ID:", 1, true) and payload:find("Zone:", 1, true) and payload:find("Pos:", 1, true) then
        return true
    end

    if payload:match("Active Hotspots:%s*%d+") then
        return true
    end

    if payload:match("Hotspot%s+%d+") then
        return true
    end

    return false
end

function Core:UpsertHotspot(record)
    if not record or not record.id then return end
    local existing = state.hotspots[record.id]
    if record.bonus then
        state.config.experienceBonus = record.bonus
    end
    state.hotspots[record.id] = record
    self:PersistHotspot(record)
    if Pins and Pins.Refresh then
        Pins:Refresh()
    end
    if UI and UI.OnHotspotSpawn and not existing then
        UI:OnHotspotSpawn(record.id, record)
    elseif UI and UI.OnHotspotsChanged then
        UI:OnHotspotsChanged()
    end
    DebugPrint("Updated hotspot", record.id)
end

function Core:RemoveHotspot(id, reason)
    local existing = state.hotspots[id]
    if not existing then return end
    state.hotspots[id] = nil
    if state.db and state.db.cache then
        state.db.cache[id] = nil
    end
    if Pins and Pins.Refresh then
        Pins:Refresh()
    end
    if UI then
        if reason == "expire" and UI.OnHotspotExpire then
            UI:OnHotspotExpire(id)
        elseif UI.OnHotspotsChanged then
            UI:OnHotspotsChanged()
        end
    end
    DebugPrint("Removed hotspot", id, reason or "")
end

function Core:RefreshVisuals()
    if Pins and Pins.Refresh then
        Pins:Refresh()
    end
    if UI and UI.RefreshList then
        UI:RefreshList()
    end
end

function Core:RestoreCachedHotspots()
    if not state.db or not state.db.cache then return end
    local nowEpoch = NowEpoch()
    local revived = 0
    for id, data in pairs(state.db.cache) do
        if data.expireEpoch and data.expireEpoch > nowEpoch then
            local remain = data.expireEpoch - nowEpoch
            local restored = CloneTable(data)
            restored.expire = GetTime() + remain
            state.hotspots[id] = restored
            revived = revived + 1
        else
            state.db.cache[id] = nil
        end
    end
    if revived > 0 and Pins and Pins.Refresh then
        Pins:Refresh()
    end
    if revived > 0 and UI and UI.OnHotspotsChanged then
        UI:OnHotspotsChanged()
    end
end

function Core:PruneExpiredHotspots()
    local now = GetTime()
    for id, data in pairs(state.hotspots) do
        if data.expire and data.expire <= now then
            self:RemoveHotspot(id, "expire")
        end
    end
end

function Core:HandlePayloadString(payload)
    DebugPrint("Received message:", payload)
    local parsed = ParsePayloadString(payload)
    if not parsed then
        DebugPrint("  Failed to parse message")
        return
    end
    DebugPrint("  Parsed data:", parsed.id, parsed.map, parsed.zone, parsed.x, parsed.y)
    local record = BuildHotspotRecord(parsed)
    if not record then
        DebugPrint("  Failed to build hotspot record")
        return
    end
    DebugPrint("  Created hotspot record:", record.id)
    self:UpsertHotspot(record)
end

function Core:CHAT_MSG_SYSTEM(message)
    if not IsHotspotPayloadCandidate(message) then
        return
    end
    self:HandlePayloadString(message)
end

function Core:CHAT_MSG_ADDON(prefix, message)
    if prefix ~= "HOTSPOT" then
        return
    end
    if not IsHotspotPayloadCandidate(message) then
        return
    end
    self:HandlePayloadString(message)
end

function Core:ADDON_LOADED(name)
    if name ~= addonName then return end

    if type(DCHotspotDB) ~= "table" then
        DCHotspotDB = {}
    end
    CopyInto(defaults, DCHotspotDB)
    state.db = DCHotspotDB
    state.db.cache = state.db.cache or {}

    if RegisterAddonMessagePrefix then
        RegisterAddonMessagePrefix("HOTSPOT")
    end

    if Pins and Pins.Init then
        Pins:Init(state)
    end
    if UI and UI.Init then
        UI:Init(state)
    end
    if addonTable.Options and addonTable.Options.Init then
        addonTable.Options:Init(state)
    end

    self:RestoreCachedHotspots()
    DebugPrint("Addon loaded")
end

function Core:PLAYER_LOGIN()
    if state.db and state.db.showListOnLogin and UI and UI.listFrame then
        UI.listFrame:Show()
        if UI.RefreshList then
            UI:RefreshList()
        end
    end
end

function Core:PLAYER_LOGOUT()
    self:PruneExpiredHotspots()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if Core[event] then
        Core[event](Core, ...)
    elseif event == "CHAT_MSG_ADDON" then
        Core:CHAT_MSG_ADDON(...)
    elseif event == "CHAT_MSG_SYSTEM" then
        Core:CHAT_MSG_SYSTEM(...)
    end
end)

eventFrame:SetScript("OnUpdate", function(_, elapsed)
    Core.elapsed = (Core.elapsed or 0) + elapsed
    if Core.elapsed < 1 then
        return
    end
    Core.elapsed = 0
    Core:PruneExpiredHotspots()
end)

return Core
