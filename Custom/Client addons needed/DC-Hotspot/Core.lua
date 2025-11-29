local addonName, addonTable = ...
addonTable = addonTable or {}

local Pins = addonTable.Pins or {}
local UI = addonTable.UI or {}
local Debug = _G.DC_DebugUtils

-- Protocol detection with fallback chain: DCAddonProtocol → AIO → Chat
local DC = rawget(_G, "DCAddonProtocol")
local AIO = rawget(_G, "AIO")

local Core = {}
addonTable.Core = Core

-- Protocol availability flags
Core.useDCProtocol = (DC ~= nil)
Core.useAIO = (AIO ~= nil)
Core.protocolMode = (DC and "DCAddonProtocol") or (AIO and "AIO") or "Chat"

local state = {
    addonName = addonName,
    hotspots = {},
    config = {
        experienceBonus = 100,
    },
    sessionStart = GetTime(),
    lastPlayerPos = nil,
    suppressAnnouncements = true,  -- Suppress announcements during initial load
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
    useDCProtocolJSON = true,  -- Use JSON format when available
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

local function ResolveZoneName(zoneId, serverZoneName)
    -- Prefer server-provided zone name (from DBC on server side)
    if serverZoneName and serverZoneName ~= "" and serverZoneName ~= "Unknown" then
        return serverZoneName
    end
    
    if not zoneId or zoneId == 0 then
        return "Unknown Zone"
    end
    
    -- WotLK 3.3.5 doesn't have C_Map.GetAreaInfo, but try anyway for forward compat
    if C_Map and C_Map.GetAreaInfo then
        local name = C_Map.GetAreaInfo(zoneId)
        if name and name ~= "" then
            return name
        end
    end
    
    -- GetMapNameByID is for map IDs, not zone IDs - usually doesn't work here
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
    local zoneId = NormalizeNumber(payload.zone)
    local record = {
        id = id,
        map = NormalizeNumber(payload.map),
        zoneId = zoneId,
        zone = ResolveZoneName(zoneId, payload.zonename),
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
        -- Only announce if not during initial load and not restored from cache
        local shouldAnnounce = not state.suppressAnnouncements and not record.restoredFromCache
        UI:OnHotspotSpawn(record.id, record, shouldAnnounce)
    elseif UI and UI.OnHotspotsChanged then
        UI:OnHotspotsChanged()
    end
    DebugPrint("Updated hotspot", record.id, existing and "(update)" or "(new)")
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
            restored.restoredFromCache = true  -- Mark as restored, not new
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
    DebugPrint("Restored", revived, "cached hotspots")
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
    
    -- Track this ID as part of current list response
    if self.pendingListIds then
        self.pendingListIds[record.id] = true
    end
    
    self:UpsertHotspot(record)
end

-- Handle the "Active Hotspots: X" header to start tracking a new list
function Core:HandleListHeader(count)
    DebugPrint("List header received, expecting", count, "hotspots")
    
    -- Start tracking which IDs we receive in this list
    self.pendingListIds = {}
    self.expectedListCount = count
    self.receivedListCount = 0
    
    -- Set a timer to finalize the list after all entries are received
    -- (in case some messages are delayed or count is 0)
    if self.listFinalizeFrame then
        self.listFinalizeFrame:SetScript("OnUpdate", nil)
    end
    
    self.listFinalizeFrame = self.listFinalizeFrame or CreateFrame("Frame")
    self.listFinalizeFrame.elapsed = 0
    self.listFinalizeFrame:SetScript("OnUpdate", function(frame, elapsed)
        frame.elapsed = frame.elapsed + elapsed
        if frame.elapsed >= 2 then  -- Wait 2 seconds after header for all entries
            frame:SetScript("OnUpdate", nil)
            Core:FinalizeListResponse()
        end
    end)
end

-- Finalize list response - remove hotspots not in the new list
function Core:FinalizeListResponse()
    if not self.pendingListIds then return end
    
    local toRemove = {}
    for id in pairs(state.hotspots) do
        if not self.pendingListIds[id] then
            table.insert(toRemove, id)
        end
    end
    
    for _, id in ipairs(toRemove) do
        DebugPrint("Removing stale hotspot", id, "(not in server list)")
        self:RemoveHotspot(id, "server_removed")
    end
    
    self.pendingListIds = nil
    self.expectedListCount = nil
    self.receivedListCount = nil
end

function Core:CHAT_MSG_SYSTEM(message)
    if not IsHotspotPayloadCandidate(message) then
        return
    end
    
    -- Check for list header "Active Hotspots: X"
    local count = message:match("Active Hotspots:%s*(%d+)")
    if count then
        self:HandleListHeader(tonumber(count))
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

    -- Re-check protocol availability after all addons loaded
    DC = rawget(_G, "DCAddonProtocol")
    AIO = rawget(_G, "AIO")
    Core.useDCProtocol = (DC ~= nil)
    Core.useAIO = (AIO ~= nil)
    Core.protocolMode = (DC and "DCAddonProtocol") or (AIO and "AIO") or "Chat"

    if Pins and Pins.Init then
        Pins:Init(state)
    end
    if UI and UI.Init then
        UI:Init(state)
    end
    if addonTable.Options and addonTable.Options.Init then
        addonTable.Options:Init(state)
        -- Create Communication sub-panel
        if addonTable.Options.CreateCommPanel then
            addonTable.Options:CreateCommPanel()
        end
    end

    -- Register DCAddonProtocol handlers if available
    self:RegisterProtocolHandlers()

    self:RestoreCachedHotspots()
    DebugPrint("Addon loaded, protocol mode:", Core.protocolMode)
end

function Core:PLAYER_LOGIN()
    -- Re-check DC availability (DC-AddonProtocol may have loaded after us)
    DC = rawget(_G, "DCAddonProtocol")
    Core.useDCProtocol = (DC ~= nil)
    Core.protocolMode = (DC and "DCAddonProtocol") or (AIO and "AIO") or "Chat"
    
    -- Re-register protocol handlers if DC is now available
    if DC and not Core._handlersRegistered then
        self:RegisterProtocolHandlers()
    end
    
    DebugPrint("PLAYER_LOGIN - Protocol mode:", Core.protocolMode, "DC available:", tostring(DC ~= nil))
    
    if state.db and state.db.showListOnLogin and UI and UI.listFrame then
        UI.listFrame:Show()
        if UI.RefreshList then
            UI:RefreshList()
        end
    end
    
    -- Hook world map for auto-refresh
    self:HookWorldMap()
    
    -- Automatically request hotspot list on login (after a short delay for server connection)
    -- Use a slightly longer delay to ensure connection is established
    local loginFrame = CreateFrame("Frame")
    loginFrame.elapsed = 0
    loginFrame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed >= 3 then  -- 3 second delay for server connection
            self:SetScript("OnUpdate", nil)
            DebugPrint("Auto-requesting hotspot list...")
            Core:RequestHotspotList()
        end
    end)
end

-- Request hotspot list from server using protocol fallback chain (JSON standard)
function Core:RequestHotspotList()
    self.lastHotspotRequest = GetTime()
    DebugPrint("Requesting hotspot list from server via", Core.protocolMode, "(JSON)")
    
    -- Protocol fallback chain: DCAddonProtocol → AIO → Chat
    if Core.useDCProtocol and DC then
        -- Primary: DCAddonProtocol with JSON format (standard)
        DC:Request("SPOT", 0x01, { action = "list" })
    elseif Core.useAIO and AIO and AIO.Handle then
        -- Secondary: AIO/Eluna
        AIO.Handle("HOTSPOT", "Request", "LIST")
    else
        -- Tertiary: Chat command fallback
        SendChatMessage(".hotspot list", "SAY")
    end
    
    -- Enable announcements after initial list load completes (with delay)
    if state.suppressAnnouncements then
        local enableFrame = CreateFrame("Frame")
        enableFrame.elapsed = 0
        enableFrame:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = self.elapsed + elapsed
            if self.elapsed >= 5 then  -- Wait 5 seconds after first request
                self:SetScript("OnUpdate", nil)
                state.suppressAnnouncements = false
                DebugPrint("Announcements enabled")
            end
        end)
    end
end

-- Request teleport to a hotspot using protocol fallback chain (JSON standard)
function Core:RequestTeleport(hotspotId)
    DebugPrint("Requesting teleport to hotspot", hotspotId, "via", Core.protocolMode, "(JSON)")
    
    if Core.useDCProtocol and DC then
        DC:Request("SPOT", 0x03, { action = "teleport", id = hotspotId })
    elseif Core.useAIO and AIO and AIO.Handle then
        AIO.Handle("HOTSPOT", "Request", "TELEPORT", hotspotId)
    else
        SendChatMessage(".hotspot tp " .. hotspotId, "SAY")
    end
end

-- Request info for a specific hotspot (JSON standard)
function Core:RequestHotspotInfo(hotspotId)
    DebugPrint("Requesting info for hotspot", hotspotId, "(JSON)")
    
    if Core.useDCProtocol and DC then
        DC:Request("SPOT", 0x02, { action = "info", id = hotspotId })
    elseif Core.useAIO and AIO and AIO.Handle then
        AIO.Handle("HOTSPOT", "Request", "INFO", hotspotId)
    else
        SendChatMessage(".hotspot info " .. hotspotId, "SAY")
    end
end

-- Track zone changes to refresh hotspots
function Core:ZONE_CHANGED_NEW_AREA()
    -- Only request if we have no hotspots cached OR it's been a while since last request
    local now = GetTime()
    local lastRequest = self.lastHotspotRequest or 0
    local timeSinceRequest = now - lastRequest
    
    -- Don't spam - wait at least 60 seconds between zone-change requests
    if timeSinceRequest < 60 then
        return
    end
    
    -- Use a small delay to avoid spamming
    if self.zoneChangeTimer then return end
    
    self.zoneChangeTimer = true
    local zoneFrame = CreateFrame("Frame")
    zoneFrame.elapsed = 0
    zoneFrame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed >= 1 then
            self:SetScript("OnUpdate", nil)
            Core.zoneChangeTimer = nil
            Core:RequestHotspotList()
        end
    end)
end

-- Hook world map to refresh hotspots when opened
function Core:HookWorldMap()
    if self.worldMapHooked then return end
    self.worldMapHooked = true
    
    if WorldMapFrame then
        WorldMapFrame:HookScript("OnShow", function()
            -- Only request if it's been a while since last request (30 sec cooldown)
            local now = GetTime()
            local lastRequest = Core.lastHotspotRequest or 0
            if (now - lastRequest) >= 30 then
                Core:RequestHotspotList()
            end
        end)
        DebugPrint("WorldMap OnShow hook installed")
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
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

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
    
    -- Periodic refresh: re-request hotspot list every 3 minutes to catch server-side removals
    Core.refreshElapsed = (Core.refreshElapsed or 0) + 1
    if Core.refreshElapsed >= 180 then  -- 180 seconds = 3 minutes
        Core.refreshElapsed = 0
        Core:RequestHotspotList()
    end
end)

-- =====================================================================
-- DC ADDON PROTOCOL HANDLERS
-- =====================================================================

-- Simple JSON parser for WotLK (no native JSON support)
local function ParseJSON(str)
    if not str or str == "" then return nil end
    
    -- Very basic JSON parsing for simple objects
    local result = {}
    
    -- Remove outer braces
    str = str:match("^%s*{(.+)}%s*$")
    if not str then return nil end
    
    -- Parse key-value pairs
    for key, value in str:gmatch('"([^"]+)"%s*:%s*([^,}]+)') do
        -- Remove quotes from string values
        local strVal = value:match('^"(.+)"$')
        if strVal then
            result[key] = strVal
        elseif value == "true" then
            result[key] = true
        elseif value == "false" then
            result[key] = false
        elseif value == "null" then
            result[key] = nil
        else
            result[key] = tonumber(value) or value
        end
    end
    
    return result
end

-- Register protocol handlers (called after ADDON_LOADED)
function Core:RegisterProtocolHandlers()
    -- Re-check DC availability
    DC = rawget(_G, "DCAddonProtocol")
    if not DC then
        DebugPrint("DCAddonProtocol not available, using fallback")
        return
    end
    
    -- Prevent double registration
    if Core._handlersRegistered then
        DebugPrint("Protocol handlers already registered")
        return
    end
    Core._handlersRegistered = true
    
    DebugPrint("Registering DCAddonProtocol handlers...")
    
    local function DebugProtocol(...)
        if state.db and state.db.debug then
            print("|cff33ff99[DC-Hotspot Protocol]|r", ...)
        end
    end
    
    -- SMSG_LIST (0x10) - Hotspot list response
    -- Server sends: count (number), list (string with entries separated by ";")
    -- Each entry format: id:mapId:zoneId:zoneName:x:y:dur:bonus
    DC:RegisterHandler("SPOT", 0x10, function(firstArg, ...)
        local args = {firstArg, ...}
        
        -- Check if first arg is "J" (JSON marker)
        if firstArg == "J" then
            local jsonStr = args[2]
            DebugProtocol("Received JSON hotspot list:", jsonStr)
            local data = ParseJSON(jsonStr)
            if data and data.hotspots then
                -- JSON format: { hotspots: [...], count: N }
                for _, hs in ipairs(data.hotspots) do
                    Core:ProcessHotspotPayload(hs)
                end
            end
            return
        end
        
        -- Binary format: count (number) + list (semicolon-separated string)
        local count = tonumber(firstArg) or 0
        local listStr = args[2] or ""
        DebugProtocol("Received hotspot list, count:", count, "data:", listStr:sub(1, 100))
        
        if count == 0 or listStr == "" then
            DebugProtocol("No hotspots in list")
            return
        end
        
        -- Parse semicolon-separated entries
        for entry in listStr:gmatch("[^;]+") do
            -- Each entry format: id:mapId:zoneId:zoneName:x:y:dur:bonus
            local parts = {}
            for part in entry:gmatch("[^:]+") do
                table.insert(parts, part)
            end
            
            if #parts >= 7 then
                local payload = {
                    id = tonumber(parts[1]),
                    map = tonumber(parts[2]),
                    zoneId = tonumber(parts[3]),
                    zone = parts[4],  -- Zone name from DBC
                    x = tonumber(parts[5]),
                    y = tonumber(parts[6]),
                    dur = tonumber(parts[7]),
                    bonus = tonumber(parts[8]) or 100,
                }
                DebugProtocol("Parsed hotspot:", payload.id, "zone:", payload.zone, "map:", payload.map)
                Core:ProcessHotspotPayload(payload)
            else
                DebugProtocol("Invalid entry format, parts:", #parts, "raw:", entry)
            end
        end
        
        -- Refresh pins after processing all hotspots
        if Pins and Pins.Refresh then
            Pins:Refresh()
        end
    end)
    
    -- SMSG_NEW_HOTSPOT (0x11) - New hotspot spawned
    DC:RegisterHandler("SPOT", 0x11, function(firstArg, ...)
        if firstArg == "J" then
            local data = ParseJSON(select(1, ...))
            if data then
                DebugProtocol("New hotspot (JSON):", data.id)
                Core:ProcessHotspotPayload(data)
            end
            return
        end
        
        local id, mapId, zoneId, zoneName, x, y, bonus, duration = firstArg, ...
        DebugProtocol("New hotspot:", id)
        local payload = {
            id = id,
            map = mapId,
            zone = zoneId,
            zonename = zoneName,
            x = x,
            y = y,
            bonus = bonus,
            dur = duration,
        }
        Core:ProcessHotspotPayload(payload)
    end)
    
    -- SMSG_HOTSPOT_EXPIRED (0x12) - Hotspot expired/removed
    DC:RegisterHandler("SPOT", 0x12, function(hotspotId)
        DebugProtocol("Hotspot expired:", hotspotId)
        if hotspotId and state.hotspots[hotspotId] then
            local record = state.hotspots[hotspotId]
            state.hotspots[hotspotId] = nil
            
            if Pins and Pins.RemoveHotspot then
                Pins:RemoveHotspot(hotspotId)
            end
            
            if not state.suppressAnnouncements and state.db and state.db.announceExpire then
                print("|cffff8800[DC-Hotspot]|r Hotspot expired in " .. (record.zone or "unknown zone"))
            end
        end
    end)
    
    -- SMSG_TELEPORT_RESULT (0x13) - Teleport result
    DC:RegisterHandler("SPOT", 0x13, function(success, hotspotId, message)
        if success then
            print("|cff00ff00[DC-Hotspot]|r Teleported to hotspot #" .. (hotspotId or "?"))
        else
            print("|cffff0000[DC-Hotspot]|r Teleport failed: " .. (message or "Unknown error"))
        end
    end)
    
    -- SMSG_ENTERED_HOTSPOT (0x14) - Player entered a hotspot zone
    DC:RegisterHandler("SPOT", 0x14, function(hotspotId, bonus)
        print("|cff00ff00[DC-Hotspot]|r You entered an XP hotspot! (+" .. (bonus or 100) .. "% XP)")
    end)
    
    -- SMSG_LEFT_HOTSPOT (0x15) - Player left a hotspot zone
    DC:RegisterHandler("SPOT", 0x15, function(hotspotId)
        print("|cffffff00[DC-Hotspot]|r You left the XP hotspot zone.")
    end)
    
    -- SMSG_HOTSPOT_INFO (0x16) - Hotspot info response
    DC:RegisterHandler("SPOT", 0x16, function(firstArg, ...)
        if firstArg == "J" then
            local data = ParseJSON(select(1, ...))
            if data then
                DebugProtocol("Hotspot info (JSON):", data.id)
                Core:ProcessHotspotPayload(data)
            end
            return
        end
        
        local found, id, mapId, zoneId, zoneName, x, y, z, dur, bonus = firstArg, ...
        if found and found ~= 0 then
            DebugProtocol("Hotspot info:", id)
            local payload = {
                id = id,
                map = mapId,
                zone = zoneId,
                zonename = zoneName,
                x = x,
                y = y,
                z = z,
                dur = dur,
                bonus = bonus,
            }
            Core:ProcessHotspotPayload(payload)
        else
            print("|cffff8800[DC-Hotspot]|r Hotspot not found or expired")
        end
    end)
    
    DebugPrint("DCAddonProtocol handlers registered")
end

-- Process a hotspot payload (from any protocol)
function Core:ProcessHotspotPayload(payload)
    if not payload or not payload.id then return end
    
    local record = BuildHotspotRecord(payload)
    if record then
        self:UpsertHotspot(record)
    end
end

return Core
