-- Minimal defensive HotspotDisplay replacement
-- Listens for HOTSPOT addon messages and system fallback HOTSPOT_ADDON|...

local ADDON_NAME = "HotspotDisplaySafe"
local ADDON_VERSION = "1.0"

local hotspots = {} -- [id] = {map, zone, x, y, expire, icon}
-- Saved settings (SavedVariables compatibility)
HotspotDisplaySafeDB = HotspotDisplaySafeDB or {
    userIcon = "Interface\\Icons\\INV_Misc_Map_01",
    userSize = 20,
    keepAcrossZones = false,
    serverAnnounce = false, -- if true, send a SAY message to the server announcing the addon; default OFF to avoid spamming logs
    debugUI = false, -- enable to show local debug messages about missing UI frames (Minimap/WorldMap)
    hotspotIcon = "Interface\\Icons\\INV_Misc_Map_01", -- default icon for hotspots when payload doesn't provide a texture
    minimapRadius = 0.5, -- normalized distance threshold for showing pins on minimap
    showTransport = false, -- show visible traces for whether data came via ADDON or SYSTEM
}

local db = HotspotDisplaySafeDB

-- Optional map libraries (Astrolabe/LibMap) detection
-- Optional map libraries (Astrolabe/LibMap) detection
local MapLib = nil
local MapLibSource = "none"
-- Prefer LibStub-installed libraries
if type(LibStub) == "function" then
    MapLib = LibStub("LibMap-1.0", true) or LibStub("Astrolabe-1.0", true)
    if MapLib then MapLibSource = "LibStub" end
end
-- Fallback: if Astrolabe is present as a global (DongleStub-style), use it
if not MapLib and type(Astrolabe) == "table" then
    MapLib = Astrolabe
    MapLibSource = "DongleStub/global Astrolabe"
end
-- If we detected something useful, inform the user; otherwise print a hint about installation
if MapLib then
    -- Attempt to query version/detail from the detected library for debug purposes
    local verMsg = ""
    local ok, a, b = pcall(function()
        if type(MapLib.GetVersion) == "function" then
            return MapLib:GetVersion()
        elseif type(MapLib.GetLibraryVersion) == "function" then
            return MapLib:GetLibraryVersion()
        end
        return nil
    end)
    if ok and a then
        if type(a) == "string" and b == nil then
            verMsg = string.format(" version=%s", tostring(a))
        elseif type(a) == "string" and b then
            verMsg = string.format(" version=%s/%s", tostring(a), tostring(b))
        elseif type(a) == "number" then
            verMsg = string.format(" version=%s", tostring(a))
        end
    end
    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFFD700[HotspotDisplaySafe]|r Map library detected (%s)%s: using for improved pin placement.", MapLibSource, verMsg))
else
    -- Friendly hint: the addon works without the library, but placement will be best-effort
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[HotspotDisplaySafe]|r No map library detected (LibStub/Astrolabe). Pins will use best-effort placement. To improve accuracy, install Astrolabe or LibMap in the " .. "\"Custom\\Client addons needed\\!Astrolabe\" folder or alongside the addon.")
end

-- C_Timer compatibility shim for clients that don't expose C_Timer
if not C_Timer then
    local _timers = {}
    local _frame = CreateFrame("Frame")
    _frame:SetScript("OnUpdate", function(self, elapsed)
        for i = #_timers, 1, -1 do
            local t = _timers[i]
            t._time = t._time - elapsed
            if t._time <= 0 then
                -- safe pcall
                pcall(t._func)
                if t._type == "ticker" then
                    t._time = t._interval
                else
                    table.remove(_timers, i)
                end
            end
        end
    end)

    C_Timer = {}
    function C_Timer.NewTicker(interval, func)
        local t = { _time = interval, _interval = interval, _func = func, _type = "ticker" }
        table.insert(_timers, t)
        return {
            Cancel = function()
                for i = #_timers, 1, -1 do if _timers[i] == t then table.remove(_timers, i); break end end
            end
        }
    end

    function C_Timer.After(delay, func)
        local t = { _time = delay, _func = func, _type = "after" }
        table.insert(_timers, t)
        return {
            Cancel = function()
                for i = #_timers, 1, -1 do if _timers[i] == t then table.remove(_timers, i); break end end
            end
        }
    end
end

-- Forward declarations for functions that may be referenced earlier in the file
local UpdateMinimap, UpdateWorldmapPins, GetPlayerNormalizedPosition, ToggleOverlay


local function parsePayload(payload)
    -- payload expected like: HOTSPOT_ADDON|map:1|zone:141|x:123.45|y:67.89|z:..|id:3|dur:3600|icon:23768|nx:0.5|ny:0.5
    local data = {}
    if not payload then return data end
    local s = tostring(payload)

    -- Normalize known prefixes: if payload is prefixed like "HOTSPOT...|rest", remove up to the first '|'
    local pipe = s:find("|")
    if pipe then
        local prefix = s:sub(1, pipe-1)
        if type(prefix) == "string" and prefix:match("^HOTSPOT") then
            s = s:sub(pipe+1)
        end
    end

    -- split by '|'
    for token in string.gmatch(s, "[^|]+") do
        local k,v = string.match(token, "([^:]+):(.+)")
        if k and v then data[k]=v end
    end

    return data
end

local function AddHotspotFromData(data)
    if not data or not data.id then return end
    local id = tonumber(data.id) or nil
    if not id then return end
    local dur = tonumber(data.dur) or 0
    local map = tonumber(data.map) or nil
    local zone = data.zone or nil
    local x = tonumber(data.x) or 0
    local y = tonumber(data.y) or 0
    local icon = tonumber(data.icon) or nil
    local nx = tonumber(data.nx) or nil
    local ny = tonumber(data.ny) or nil
    -- ensure normalized coords are numbers when available
    if nx then nx = tonumber(nx) end
    if ny then ny = tonumber(ny) end
    local tex = data.tex or nil
    local texid = tonumber(data.texid) or nil
    local now = time()
    local cappedDur = math.max(0, math.min(dur or 0, 60*24*7)) -- cap to a week to avoid absurd values
    hotspots[id] = {
        map = map, zone = zone, x = x, y = y,
        nx = nx, ny = ny,
        tex = tex, texid = texid,
        expire = now + cappedDur,
        icon = icon,
        bonus = tonumber(data.bonus) or nil,
    }
    local posStr = tostring(x)..","..tostring(y)
    if nx and ny then posStr = string.format("nx=%.3f,ny=%.3f", nx, ny) end
    if hotspots[id].bonus then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFFD700[HotspotDisplaySafe]|r Hotspot #%d registered at %s - XP Bonus: +%d%%", id, posStr, hotspots[id].bonus))
    else
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFFD700[HotspotDisplaySafe]|r Hotspot #%d registered at %s", id, posStr))
    end
    -- Update minimap and world map immediately when a new hotspot arrives
    if nx and ny then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFFD700[HotspotDisplaySafe]|r Parsed hotspot coords nx=%.4f ny=%.4f", nx, ny))
    end
    UpdateMinimap()
    UpdateWorldmapPins()
end

-- Helper: choose a best hotspot for quick tooltip display (nearest or first)
local function GetBestHotspot()
    local now = time()
    local bestId, best, bestDist
    local px, py = GetPlayerNormalizedPosition()
    for id,h in pairs(hotspots) do
        if h.expire and h.expire <= now then hotspots[id]=nil else
            if px and py and h.nx and h.ny then
                local dx = px - tonumber(h.nx)
                local dy = py - tonumber(h.ny)
                local d2 = dx*dx + dy*dy
                if not bestDist or d2 < bestDist then bestDist = d2; bestId = id; best = h end
            elseif not best then
                bestId = id; best = h
            end
        end
    end
    return bestId, best
end

local f = CreateFrame("Frame")
f:RegisterEvent("CHAT_MSG_ADDON")
f:RegisterEvent("CHAT_MSG_SYSTEM")

f:SetScript("OnEvent", function(self, event, ...)
    if event == "CHAT_MSG_ADDON" then
        local prefix, message = ...
        if prefix and type(prefix) == "string" and prefix:upper():find("HOTSPOT") and message then
            -- Visible trace: received via addon channel (honor saved setting)
            if db.showTransport then DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[HotspotDisplaySafe]|r Received HOTSPOT via ADDON channel") end
            if db.debugUI then
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[HotspotDisplaySafe]|r (debug) ADDON prefix='"..tostring(prefix).."' payloadlen="..tostring(#message))
            end
            local data = parsePayload(message)
            pcall(function() AddHotspotFromData(data) end)
        end
        return
    elseif event == "CHAT_MSG_SYSTEM" then
        local msg = ...
        if msg and type(msg) == "string" and msg:find("HOTSPOT") then
            -- Visible trace: received via system text fallback (honor saved setting)
            if db.showTransport then DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[HotspotDisplaySafe]|r Received HOTSPOT via SYSTEM chat fallback") end
            if db.debugUI then
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[HotspotDisplaySafe]|r (debug) SYSTEM payloadlen="..tostring(#msg))
            end
            local data = parsePayload(msg)
            pcall(function() AddHotspotFromData(data) end)
        end
        return
    end
end)

-- Register the addon message prefix so CHAT_MSG_ADDON will be delivered (where API exists)
pcall(function()
    if type(RegisterAddonMessagePrefix) == "function" then
        pcall(RegisterAddonMessagePrefix, "HOTSPOT")
    end
    if type(C_ChatInfo) == "table" and type(C_ChatInfo.RegisterAddonMessagePrefix) == "function" then
        pcall(C_ChatInfo.RegisterAddonMessagePrefix, "HOTSPOT")
    end
end)

-- If registration APIs are available, print a confirmation so users/operators can see the client
pcall(function()
    local registered = false
    if type(C_ChatInfo) == "table" and type(C_ChatInfo.RegisterAddonMessagePrefix) == "function" then
        -- modern API doesn't provide a query method; assume success if no error
        registered = true
    elseif type(RegisterAddonMessagePrefix) == "function" then
        registered = true
    end
    if registered then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[HotspotDisplaySafe]|r Registered addon prefix 'HOTSPOT' for CHAT_MSG_ADDON handling (if supported by client).")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[HotspotDisplaySafe]|r Could not register addon prefix API not present; will parse system chat fallback messages instead.")
    end
end)

-- Simple minimap dot implementation (non-Astrolabe): shows a single icon for latest hotspot near player
local minimapPin = nil
local function EnsureMinimapPin()
    if minimapPin then return end
    if not Minimap then return end -- Minimap may not exist in some contexts
    minimapPin = CreateFrame("Frame", "HotspotDisplaySafe_MinimapPin", Minimap)
    minimapPin:SetSize(16,16)
    minimapPin.texture = minimapPin:CreateTexture(nil, "OVERLAY")
    minimapPin.texture:SetAllPoints()
    minimapPin.texture:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
    minimapPin:SetFrameStrata("MEDIUM")
    minimapPin:Hide()
    -- Tooltip when hovering minimap pin
    minimapPin:SetScript("OnEnter", function(self)
        local id, h = GetBestHotspot()
        if not h then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine(string.format("Hotspot #%s", tostring(id)))
        if h.bonus then GameTooltip:AddLine(string.format("XP Bonus: +%d%%", tonumber(h.bonus)), 1,1,0) end
        if h.expire then
            local remaining = math.max(0, h.expire - time())
            GameTooltip:AddLine(string.format("Expires in %d sec", remaining))
        end
        GameTooltip:Show()
    end)
    minimapPin:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

UpdateMinimap = function()
    -- skip minimap updates if Minimap is unavailable
    if not Minimap then return end
    EnsureMinimapPin()
    -- choose nearest hotspot in same map (best-effort using zone id)
    local bestId, best = nil, nil
    local now = time()
    local playerMap = GetCurrentMapAreaID and GetCurrentMapAreaID() or nil
    -- prefer normalized coords if available (nx, ny)
    for id,h in pairs(hotspots) do
        if h.expire and h.expire <= now then
            hotspots[id]=nil
        else
            -- prefer a hotspot that has normalized coords
            if h.nx and h.ny then
                bestId = id; best = h; break
            end
            -- otherwise pick the first available as fallback
            if not best then
                bestId = id; best = h
            end
        end
    end

    if not best then
        if minimapPin then minimapPin:Hide() end
        return
    end

    -- If nx/ny present, position pin relative to minimap using Minimap:GetHitRect and SetPoint.
    if best.nx and best.ny then
        local nx = tonumber(best.nx)
        local ny = tonumber(best.ny)
        if nx and ny then
            if minimapPin and minimapPin.texture then minimapPin.texture:Show() end
            -- Try using MapLib (Astrolabe/LibMap) for more accurate placement when available
            if MapLib and minimapPin then
                local ok, err = pcall(function()
                    if type(MapLib.PlaceIconOnMinimap) == "function" then
                        MapLib:PlaceIconOnMinimap(minimapPin, best.map or 0, nx, ny)
                    elseif type(MapLib.PlaceIcon) == "function" then
                        MapLib:PlaceIcon(minimapPin, best.map or 0, nx, ny)
                    else
                        error("MapLib has no placement API")
                    end
                end)
                if ok then
                    if db.debugUI then DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[HotspotDisplaySafe]|r MapLib placed minimap pin (debug)") end
                    return
                end
            end
            -- compute distance to player in normalized coords; hide pin if beyond radius
            local px, py = GetPlayerNormalizedPosition()
            local radius = tonumber(db.minimapRadius) or 0.5
            if px and py and (math.abs(nx - px) > radius or math.abs(ny - py) > radius) then
                if minimapPin then minimapPin:Hide() end
                return
            end
            -- convert normalized coordinates to minimap pixel offset relative to player position.
            -- This places the icon at the correct location around the player's minimap center.
            local offsetX, offsetY
            if px and py then
                offsetX = (nx - px) * (Minimap:GetWidth())
                offsetY = (ny - py) * (Minimap:GetHeight())
            else
                -- fallback: center-based placement
                offsetX = (nx - 0.5) * (Minimap:GetWidth())
                offsetY = (ny - 0.5) * (Minimap:GetHeight())
            end
            if db.debugUI then DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFFD700[HotspotDisplaySafe]|r Minimap coords px=%.4f,py=%.4f nx=%.4f,ny=%.4f offset=(%.2f,%.2f)", tonumber(px) or 0, tonumber(py) or 0, tonumber(nx) or 0, tonumber(ny) or 0, offsetX, offsetY)) end
            if minimapPin then
                minimapPin:ClearAllPoints()
                minimapPin:SetPoint("CENTER", Minimap, "CENTER", offsetX, offsetY)
                minimapPin:Show()
            end
            return
        end
    end

    -- Fallback: just show a generic pin
    if minimapPin and minimapPin.texture then minimapPin.texture:Show(); minimapPin:Show() end
end

-- World map pins (show all active hotspots on world map)
local worldmapPins = {}
local function ClearWorldmapPins()
    for _,pin in pairs(worldmapPins) do
        if pin then pin:Hide(); pin:SetScript("OnUpdate", nil) end
    end
    wipe(worldmapPins)
end

local function EnsureWorldMapContainer()
    if not WorldMapFrame then return nil end
    -- prefer ScrollContainer canvas if available; guard calls with pcall where necessary
    local container = nil
    if WorldMapFrame.ScrollContainer then
        if type(WorldMapFrame.ScrollContainer.GetCanvas) == "function" then
            container = WorldMapFrame.ScrollContainer:GetCanvas()
        else
            container = WorldMapFrame.ScrollContainer
        end
    else
        container = WorldMapFrame
    end
    return container
end

UpdateWorldmapPins = function()
    ClearWorldmapPins()
    local container = EnsureWorldMapContainer()
    if not container then return end

    local now = time()
    local added = 0
    for id,h in pairs(hotspots) do
        if h.expire and h.expire <= now then
            hotspots[id] = nil
        else
            local nx = tonumber(h.nx)
            local ny = tonumber(h.ny)
            if nx and ny then
                added = added + 1
                local pin = CreateFrame("Frame", "HotspotDisplaySafe_Pin_"..tostring(id), container)
                pin:SetSize((db.userSize or 20) + 8, (db.userSize or 20) + 8)
                pin.texture = pin:CreateTexture(nil, "OVERLAY")
                pin.texture:SetAllPoints()
                local tex = h.tex and h.tex or (h.icon and ("Interface\\Icons\\INV_Misc_Map_01") )
                -- prefer hotspot texture if available (payload tex > payload icon > db.hotspotIcon > db.userIcon)
                local chosenTex = tex or (h.icon and ("Interface\\Icons\\INV_Misc_Map_01")) or db.hotspotIcon or db.userIcon
                pin.texture:SetTexture(chosenTex)
                pin:SetFrameStrata("HIGH")

                local function UpdatePin()
                    if not nx or not ny then return end
                    -- Try to use MapLib for world map placement when available
                    if MapLib then
                        local ok = pcall(function()
                            if type(MapLib.PlaceIconOnWorldMap) == "function" then
                                MapLib:PlaceIconOnWorldMap(pin, h.map or 0, nx, ny)
                            elseif type(MapLib.PlaceIcon) == "function" then
                                MapLib:PlaceIcon(pin, h.map or 0, nx, ny)
                            else
                                error("MapLib has no worldmap placement API")
                            end
                        end)
                        if ok then
                            if db.debugUI then DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFFD700[HotspotDisplaySafe]|r MapLib placed worldmap pin #%d (debug)", id)) end
                            return
                        end
                    end
                    if type(container.GetWidth) ~= "function" or type(container.GetHeight) ~= "function" then return end
                    local w = container:GetWidth()
                    local hgt = container:GetHeight()
                    -- Treat container as canvas; place pins relative to canvas TOPLEFT
                    local canvas = container
                    local canvasW = canvas:GetWidth()
                    local canvasH = canvas:GetHeight()
                    local pinW, pinH = pin:GetWidth() or ((db.userSize or 20) + 8), pin:GetHeight() or ((db.userSize or 20) + 8)
                    local x = nx * canvasW - (pinW / 2)
                    local y = ny * canvasH - (pinH / 2)
                    local ok = pcall(function()
                        pin:ClearAllPoints()
                        pin:SetPoint("TOPLEFT", canvas, "TOPLEFT", x, -y)
                        pin:Show()
                    end)
                    if ok then
                        if db.debugUI then DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFFD700[HotspotDisplaySafe]|r WorldMap pin #%d placed on canvas TOPLEFT (debug) pos=(%.2f,%.2f) canvas=(%.0f,%.0f)", id, x, y, canvasW, canvasH)) end
                    else
                        pin:Hide()
                    end
                end

                pin:SetScript("OnUpdate", UpdatePin)
                UpdatePin()
                worldmapPins[id] = pin
                -- tooltip for world map pin
                pin:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                    GameTooltip:ClearLines()
                    GameTooltip:AddLine(string.format("Hotspot #%s", tostring(id)))
                    if h.bonus then GameTooltip:AddLine(string.format("XP Bonus: +%d%%", tonumber(h.bonus)), 1,1,0) end
                    if h.expire then
                        local remaining = math.max(0, h.expire - time())
                        GameTooltip:AddLine(string.format("Expires in %d sec", remaining))
                    end
                    GameTooltip:Show()
                end)
                pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
            end
        end
    end
end

-- Periodic cleanup
C_Timer.NewTicker(5, function()
    local now = time()
    local removed = false
    for id,h in pairs(hotspots) do
        if h.expire and h.expire <= now then hotspots[id]=nil; removed = true end
    end
    if removed then UpdateMinimap() end
end)

DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFFD700[HotspotDisplaySafe]|r Loaded v%s", ADDON_VERSION))
-- One-time server-visible debug message so operators can see the client addon is active
-- Note: this sends a normal SAY chat message which will be visible in server logs.
local function AnnounceAddonToServer()
    local msg = string.format("[HOTSPOT_CLIENT_LOADED] %s v%s", ADDON_NAME, ADDON_VERSION)
    -- Only announce to server if user explicitly enabled it in saved vars; otherwise print locally
    if db.serverAnnounce then
        -- Safe guard: pcall in case the API is unavailable in some clients
        pcall(function() SendChatMessage(msg, "SAY") end)
    else
        -- local-only notification so the player knows the addon loaded without spamming the server
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFFD700[HotspotDisplaySafe]|r (local) %s", msg))
    end
end

-- Announce once after a short delay to allow player login to complete
C_Timer.After(1.5, AnnounceAddonToServer)

-- Deferred retry: some clients create UI frames after addons run; retry pin setup for a short while
local function StartDeferredPinRetry()
    local tries = 0
    local maxTries = 12 -- try for ~12 seconds
    local ticker = nil
    local minimapReported = false
    local worldmapReported = false
    ticker = C_Timer.NewTicker(1, function()
        tries = tries + 1
        -- report missing frames one-time if debug enabled
        if not minimapReported and not Minimap then
            minimapReported = true
            if db.debugUI then DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[HotspotDisplaySafe]|r Debug: Minimap not available yet; retrying...") end
        end
        local container = EnsureWorldMapContainer()
        if not worldmapReported and not container then
            worldmapReported = true
            if db.debugUI then DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[HotspotDisplaySafe]|r Debug: WorldMap container not available yet; retrying...") end
        end
        -- attempt to ensure minimap pin and worldmap pins (no-ops if frames are missing)
        pcall(function()
            if not minimapPin and Minimap then EnsureMinimapPin() end
            -- if user placed a personal pin earlier but Minimap was missing, recreate it from saved settings
            if userMinimapPin == nil and db.userIcon and Minimap then
                -- Do not automatically create a user pin unless the user explicitly used the command; keep no auto-creation
            end
            -- Try updating worldmap pins if the container is now available
            UpdateWorldmapPins()
        end)

        if (minimapPin and (next(hotspots) ~= nil or userMinimapPin)) or tries >= maxTries then
            if db.debugUI then DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[HotspotDisplaySafe]|r Debug: Deferred pin retry finished (success or timeout).") end
            ticker:Cancel()
        end
    end)
end

-- Kick off a deferred retry after login and on zone changes where frames may arrive late
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("ZONE_CHANGED")
f:RegisterEvent("ZONE_CHANGED_INDOORS")
f:HookScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" or event:find("ZONE_CHANGED") then
        -- start retrying pin setup shortly after zone changes
        C_Timer.After(0.5, StartDeferredPinRetry)
    end
end)

-- Debug command: spawn a test hotspot at player's current position
SLASH_HOTSPOTDEBUG1 = "/hotspotdebug"
SlashCmdList["HOTSPOTDEBUG"] = function(msg)
    local nx, ny = GetPlayerNormalizedPosition()
    if not nx or not ny then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[HotspotDisplaySafe]|r Could not get your map position.")
        return
    end
    local id = math.random(100000,999999)
    local data = { id = tostring(id), nx = tostring(nx), ny = tostring(ny), dur = "600", bonus = "100", tex = db.userIcon }
    AddHotspotFromData(data)
    UpdateWorldmapPins()
    UpdateMinimap()
    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFFD700[HotspotDisplaySafe]|r Debug hotspot #%d created at (%.3f, %.3f). Open your map (M) to see it.", id, nx, ny))
end

-- Notify when the world map is opened that HotspotDisplay is active
if WorldMapFrame then
    WorldMapFrame:HookScript("OnShow", function()
        -- small on-map notification
        if HOTSPOT_DISPLAY_MAP_NOTICE == nil then
            HOTSPOT_DISPLAY_MAP_NOTICE = CreateFrame("Frame", nil, WorldMapFrame)
            HOTSPOT_DISPLAY_MAP_NOTICE:SetSize(300,24)
            HOTSPOT_DISPLAY_MAP_NOTICE.text = HOTSPOT_DISPLAY_MAP_NOTICE:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            HOTSPOT_DISPLAY_MAP_NOTICE.text:SetPoint("TOP", WorldMapFrame, "TOP", 0, -20)
        end
        HOTSPOT_DISPLAY_MAP_NOTICE.text:SetText("Hotspot Display Active")
        C_Timer.After(3, function() if HOTSPOT_DISPLAY_MAP_NOTICE and HOTSPOT_DISPLAY_MAP_NOTICE.text then HOTSPOT_DISPLAY_MAP_NOTICE.text:SetText("") end end)
        -- ensure pins are up-to-date
        UpdateWorldmapPins()
    end)
end

-- Personal hotspot icon (toggle) placed at player's current location
local userMinimapPin = nil
local userWorldmapPin = nil

local function RemoveUserPins()
    if userMinimapPin then
        userMinimapPin:Hide()
        userMinimapPin:SetScript("OnUpdate", nil)
        userMinimapPin = nil
    end
    if userWorldmapPin then
        userWorldmapPin:Hide()
        userWorldmapPin:SetScript("OnUpdate", nil)
        userWorldmapPin = nil
    end
end

local function CreateUserMinimapPin(nx, ny, tex)
    if not Minimap then return end
    EnsureMinimapPin()
    -- create or reuse a dedicated pin frame for the user
    if userMinimapPin then userMinimapPin:Hide(); userMinimapPin:SetScript("OnUpdate", nil) end
    userMinimapPin = CreateFrame("Frame", "HotspotDisplaySafe_UserMinimapPin", Minimap)
    userMinimapPin:SetSize(db.userSize or 20, db.userSize or 20)
    userMinimapPin.texture = userMinimapPin:CreateTexture(nil, "OVERLAY")
    userMinimapPin.texture:SetAllPoints()
    userMinimapPin.texture:SetTexture(tex or db.userIcon or "Interface\\Icons\\INV_Misc_Map_01")
    userMinimapPin:SetFrameStrata("HIGH")

    local function UpdatePin()
        if not nx or not ny or not Minimap then return end
        -- Try MapLib if available
        if MapLib and userMinimapPin then
            local ok = pcall(function()
                if type(MapLib.PlaceIconOnMinimap) == "function" then
                    MapLib:PlaceIconOnMinimap(userMinimapPin, nil, nx, ny)
                elseif type(MapLib.PlaceIcon) == "function" then
                    MapLib:PlaceIcon(userMinimapPin, nil, nx, ny)
                else
                    error("MapLib has no placement API")
                end
            end)
            if ok then
                if db.debugUI then DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[HotspotDisplaySafe]|r MapLib placed personal minimap pin (debug)") end
                return
            end
        end
        local px, py = GetPlayerNormalizedPosition()
        local offsetX, offsetY
        if px and py then
            offsetX = (nx - px) * (Minimap:GetWidth())
            offsetY = (ny - py) * (Minimap:GetHeight())
        else
            offsetX = (nx - 0.5) * (Minimap:GetWidth())
            offsetY = (ny - 0.5) * (Minimap:GetHeight())
        end
        if userMinimapPin then
            userMinimapPin:ClearAllPoints()
            userMinimapPin:SetPoint("CENTER", Minimap, "CENTER", offsetX, offsetY)
            userMinimapPin:Show()
        end
    end

    userMinimapPin:SetScript("OnUpdate", UpdatePin)
    UpdatePin()
    -- tooltip for personal minimap pin
    userMinimapPin:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Personal Hotspot Icon")
        GameTooltip:AddLine(string.format("Coords: %.3f, %.3f", nx or 0, ny or 0))
        GameTooltip:Show()
    end)
    userMinimapPin:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function CreateUserWorldmapPin(nx, ny, tex)
    -- Only create if we can anchor to WorldMapFrame; otherwise create and wait for map to open
    if not WorldMapFrame then return end
    if userWorldmapPin then userWorldmapPin:Hide(); userWorldmapPin:SetScript("OnUpdate", nil) end
    userWorldmapPin = CreateFrame("Frame", "HotspotDisplaySafe_UserWorldmapPin", WorldMapFrame)
    userWorldmapPin:SetSize((db.userSize or 20) + 4, (db.userSize or 20) + 4)
    userWorldmapPin.texture = userWorldmapPin:CreateTexture(nil, "OVERLAY")
    userWorldmapPin.texture:SetAllPoints()
    userWorldmapPin.texture:SetTexture(tex or db.userIcon or "Interface\\Icons\\INV_Misc_Map_01")
    userWorldmapPin:SetFrameStrata("HIGH")

    local function UpdatePin()
        if not nx or not ny then return end
        local container = WorldMapFrame.ScrollContainer or WorldMapFrame
        local w = container:GetWidth()
        local h = container:GetHeight()
        local offsetX = (nx - 0.5) * w
        local offsetY = (ny - 0.5) * h
        userWorldmapPin:ClearAllPoints()
        userWorldmapPin:SetPoint("CENTER", container, "CENTER", offsetX, offsetY)
        userWorldmapPin:Show()
    end

    userWorldmapPin:SetScript("OnUpdate", UpdatePin)
    UpdatePin()

    -- ensure the pin updates when the world map is opened or changed
    if WorldMapFrame then
        WorldMapFrame:HookScript("OnShow", function() if userWorldmapPin then userWorldmapPin:SetScript("OnUpdate", UpdatePin) end end)
    end
end

-- Helper: try multiple APIs to get player's normalized position on current map
GetPlayerNormalizedPosition = function()
    -- Try C_Map API first
    local ok, mapID = pcall(function()
        if C_Map and C_Map.GetBestMapForUnit then return C_Map.GetBestMapForUnit("player") end
        return nil
    end)
    if not ok then mapID = nil end

    local nx, ny = nil, nil
    if mapID and C_Map and C_Map.GetPlayerMapPosition then
        local pos = C_Map.GetPlayerMapPosition(mapID, "player")
        if pos then nx, ny = pos.x, pos.y end
    end

    -- Fallback to legacy API
    if (not nx or not ny) and GetPlayerMapPosition then
        local x,y = GetPlayerMapPosition("player")
        if x and y and (x > 0 or y > 0) then nx, ny = x, y end
    end

    return nx, ny
end

-- Remove personal pins on zone change unless user asked to keep them
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("ZONE_CHANGED")
f:RegisterEvent("ZONE_CHANGED_INDOORS")

f:HookScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" or event:find("ZONE_CHANGED") then
        if not db.keepAcrossZones then
            RemoveUserPins()
        end
    end
end)

-- Slash command to toggle a personal hotspot icon at player's current location
SLASH_HOTSPOTICON1 = "/hotspoticon"
SLASH_HOTSPOTICON2 = "/hsicon"
SlashCmdList["HOTSPOTICON"] = function(msg)
    -- toggle: remove if exists
    if userMinimapPin or userWorldmapPin then
        RemoveUserPins()
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[HotspotDisplaySafe]|r Personal hotspot icon removed.")
        return
    end

    -- Determine normalized position
    local nx, ny = GetPlayerNormalizedPosition()
    if not nx or not ny then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[HotspotDisplaySafe]|r Could not determine your map position. Open your map or try again.")
        return
    end

    -- create minimap and worldmap pins
    CreateUserMinimapPin(nx, ny)
    CreateUserWorldmapPin(nx, ny)

    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFFD700[HotspotDisplaySafe]|r Placed personal hotspot icon at (%.2f, %.2f) on your map.", nx, ny))
end

-- Slash command to configure user icon and size
SLASH_HOTSPOTICONSET1 = "/hotspoticonset"
SlashCmdList["HOTSPOTICONSET"] = function(msg)
    if not msg or msg == "" then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFFD700[HotspotDisplaySafe]|r Current icon=%s size=%d keepAcrossZones=%s", db.userIcon, db.userSize, tostring(db.keepAcrossZones)))
        DEFAULT_CHAT_FRAME:AddMessage("Usage: /hotspoticonset <texturePath|iconId> [size] [keep]")
        DEFAULT_CHAT_FRAME:AddMessage("Example: /hotspoticonset Interface\\Icons\\INV_Misc_Map_01 22 true")
        return
    end

    local parts = {}
    for token in string.gmatch(msg, "%S+") do table.insert(parts, token) end
    -- support subcommands: 'hotspot <texture>' to set hotspot-specific icon
    if #parts >= 2 and string.lower(parts[1]) == "hotspot" then
        db.hotspotIcon = parts[2]
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFFD700[HotspotDisplaySafe]|r hotspot icon set to %s", tostring(db.hotspotIcon)))
        return
    end

    if #parts >= 1 then
        local icon = parts[1]
        -- allow numeric icon id to be formatted into a texture if desired; leave as-is otherwise
        db.userIcon = icon
    end
    if #parts >= 2 then
        local s = tonumber(parts[2])
        if s and s > 6 then db.userSize = s end
    end
    if #parts >= 3 then
        local keep = parts[3]
        for c in keep:gmatch(".") do keep = string.lower(keep) end
        db.keepAcrossZones = (keep == "true" or keep == "1" or keep == "yes")
    end

    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFFD700[HotspotDisplaySafe]|r Settings saved: icon=%s size=%d keepAcrossZones=%s", db.userIcon, db.userSize, tostring(db.keepAcrossZones)))
end

-- Slash to toggle server announcement (runtime)
SLASH_HOTSPOTANNOUNCE1 = "/hotspotannounce"
SlashCmdList["HOTSPOTANNOUNCE"] = function(msg)
    local a = msg and msg:match("%S+") or nil
    if not a or a == "" then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFFD700[HotspotDisplaySafe]|r serverAnnounce=%s (use '/hotspotannounce on' or 'off')", tostring(db.serverAnnounce)))
        return
    end
    a = string.lower(a)
    if a == "on" or a == "1" or a == "true" then
        db.serverAnnounce = true
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[HotspotDisplaySafe]|r serverAnnounce enabled (the addon will SAY on load).")
    elseif a == "off" or a == "0" or a == "false" then
        db.serverAnnounce = false
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[HotspotDisplaySafe]|r serverAnnounce disabled (local-only notification).")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[HotspotDisplaySafe]|r Usage: /hotspotannounce on|off")
    end
end

-- Slash to toggle UI debug reporting for the deferred retry
SLASH_HOTSPOTDEBUGUI1 = "/hotspotdebugui"
SlashCmdList["HOTSPOTDEBUGUI"] = function(msg)
    local a = msg and msg:match("%S+") or nil
    if not a or a == "" then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFFD700[HotspotDisplaySafe]|r debugUI=%s (use '/hotspotdebugui on' or 'off')", tostring(db.debugUI)))
        return
    end
    a = string.lower(a)
    if a == "on" or a == "1" or a == "true" then
        db.debugUI = true
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[HotspotDisplaySafe]|r debugUI enabled: deferred retry will report missing frames.")
    elseif a == "off" or a == "0" or a == "false" then
        db.debugUI = false
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[HotspotDisplaySafe]|r debugUI disabled.")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[HotspotDisplaySafe]|r Usage: /hotspotdebugui on|off")
    end
end

-- Slash to show current status and hotspot counts
SLASH_HOTSPOTSTATUS1 = "/hotspotstatus"
SlashCmdList["HOTSPOTSTATUS"] = function(msg)
    local hotspotCount = 0
    for _ in pairs(hotspots) do hotspotCount = hotspotCount + 1 end
    local worldPins = 0
    for _ in pairs(worldmapPins) do worldPins = worldPins + 1 end
    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFFD700[HotspotDisplaySafe]|r Status: serverAnnounce=%s debugUI=%s userIcon=%s size=%d keepAcrossZones=%s", tostring(db.serverAnnounce), tostring(db.debugUI), tostring(db.userIcon), tonumber(db.userSize) or 0, tostring(db.keepAcrossZones)))
    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFFD700[HotspotDisplaySafe]|r Active hotspots: %d  WorldMap pins: %d  Personal pins: %s", hotspotCount, worldPins, (userMinimapPin or userWorldmapPin) and "present" or "none"))
end

-- Slash to toggle the overlay
SLASH_HOTSPOTOVERLAY1 = "/hotspotoverlay"
SlashCmdList["HOTSPOTOVERLAY"] = function(msg)
    local a = msg and msg:match("%S+") or nil
    if not a or a == "" then
        ToggleOverlay(nil)
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFFD700[HotspotDisplaySafe]|r Overlay %s", overlayVisible and "enabled" or "disabled"))
        return
    end
    a = string.lower(a)
    if a == "on" or a == "1" or a == "true" then
        ToggleOverlay(true); DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[HotspotDisplaySafe]|r Overlay enabled")
    elseif a == "off" or a == "0" or a == "false" then
        ToggleOverlay(false); DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[HotspotDisplaySafe]|r Overlay disabled")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[HotspotDisplaySafe]|r Usage: /hotspotoverlay [on|off]")
    end
end

-- Slash to toggle transport traces (ADDON vs SYSTEM) visibility
SLASH_HOTSPOTTRANSPORT1 = "/hotspottransport"
SlashCmdList["HOTSPOTTRANSPORT"] = function(msg)
    local a = msg and msg:match("%S+") or nil
    if not a or a == "" then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFFD700[HotspotDisplaySafe]|r showTransport=%s (use '/hotspottransport on' or 'off')", tostring(db.showTransport)))
        return
    end
    a = string.lower(a)
    if a == "on" or a == "1" or a == "true" then
        db.showTransport = true
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[HotspotDisplaySafe]|r showTransport enabled")
    elseif a == "off" or a == "0" or a == "false" then
        db.showTransport = false
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[HotspotDisplaySafe]|r showTransport disabled")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[HotspotDisplaySafe]|r Usage: /hotspottransport on|off")
    end
end

-- Texture picker UI for hotspot icon selection
local pickerFrame = nil
local pickerPresets = {
    "Interface\\Icons\\INV_Misc_Gift_01",
    "Interface\\Icons\\INV_Misc_Map_01",
    "Interface\\Icons\\INV_Misc_Coin_01",
    "Interface\\Icons\\INV_Misc_EngGizmos_08",
}

local function ShowPicker()
    if pickerFrame then pickerFrame:Show(); return end
    pickerFrame = CreateFrame("Frame", "HotspotDisplaySafe_Picker", UIParent, "BackdropTemplate")
    pickerFrame:SetSize(220, 60)
    pickerFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    pickerFrame:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "", tile = true, tileSize = 16})
    pickerFrame.title = pickerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    pickerFrame.title:SetPoint("TOP", pickerFrame, "TOP", 0, -6)
    pickerFrame.title:SetText("Hotspot Icon Picker")
    for i,tex in ipairs(pickerPresets) do
        local btn = CreateFrame("Button", nil, pickerFrame, "UIPanelButtonTemplate")
        btn:SetSize(40,40)
        btn:SetPoint("LEFT", pickerFrame, "LEFT", 10 + (i-1)*50, -20)
        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.icon:SetAllPoints()
        btn.icon:SetTexture(tex)
        btn:SetScript("OnClick", function()
            db.hotspotIcon = tex
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFFD700[HotspotDisplaySafe]|r hotspot icon set to %s", tostring(tex)))
            pickerFrame:Hide()
            UpdateWorldmapPins(); UpdateMinimap()
        end)
    end
    local close = CreateFrame("Button", nil, pickerFrame, "UIPanelButtonTemplate")
    close:SetSize(60,20)
    close:SetPoint("BOTTOMRIGHT", pickerFrame, "BOTTOMRIGHT", -8, 8)
    close:SetText("Close")
    close:SetScript("OnClick", function() pickerFrame:Hide() end)
end

SLASH_HOTSPOTPICKER1 = "/hotspotpicker"
SlashCmdList["HOTSPOTPICKER"] = function(msg)
    ShowPicker()
end

-- Automatically remove personal pin when a hotspot that matches location expires
local function CleanupExpiredHotspotPins()
    local now = time()
    local removed = false
    for id,h in pairs(hotspots) do
        if h.expire and h.expire <= now then
            hotspots[id] = nil
            removed = true
            -- if user pins were pointing to this hotspot coords, remove them
            -- compare by normalized coords if available
            local nx = tonumber(h.nx)
            local ny = tonumber(h.ny)
            if nx and ny and userMinimapPin then
                -- if distance small, remove
                local px, py = GetPlayerNormalizedPosition()
                if px and py then
                    local dx = px - nx
                    local dy = py - ny
                    if (dx*dx + dy*dy) < 0.0004 then -- ~0.02 distance
                        RemoveUserPins()
                    end
                end
            end
        end
    end
    if removed then UpdateMinimap() end
end

-- Small non-invasive overlay listing active hotspots
local overlayFrame = nil
local overlayVisible = false

local function UpdateOverlay()
    if not overlayVisible then return end
    if not overlayFrame then
        overlayFrame = CreateFrame("Frame", "HotspotDisplaySafe_Overlay", UIParent)
        overlayFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -100)
        overlayFrame:SetSize(220, 120)
        overlayFrame.bg = overlayFrame:CreateTexture(nil, "BACKGROUND")
        overlayFrame.bg:SetAllPoints()
        -- Use SetColorTexture if available (newer clients); otherwise fall back to SetTexture(r,g,b,a)
        if type(overlayFrame.bg.SetColorTexture) == "function" then
            overlayFrame.bg:SetColorTexture(0,0,0,0.5)
        else
            -- Older clients accept SetTexture(r,g,b,a)
            overlayFrame.bg:SetTexture(0,0,0,0.5)
        end
        overlayFrame.text = overlayFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        overlayFrame.text:SetPoint("TOPLEFT", overlayFrame, "TOPLEFT", 6, -6)
        overlayFrame.text:SetJustifyH("LEFT")
    end

    local lines = {}
    local now = time()
    for id,h in pairs(hotspots) do
        if h.expire and h.expire > now then
            local rem = math.max(0, h.expire - now)
            table.insert(lines, string.format("#%d  +%s%%  %ds", id, tostring(h.bonus or "0"), rem))
        end
    end
    table.sort(lines)
    if #lines == 0 then
        overlayFrame.text:SetText("Hotspots: none")
    else
        local txt = "Hotspots:\n"
        for i=1, math.min(5, #lines) do txt = txt .. lines[i] .. "\n" end
        overlayFrame.text:SetText(txt)
    end
    overlayFrame:Show()
end

ToggleOverlay = function(on)
    overlayVisible = (on == nil) and not overlayVisible or (on and true) or false
    if overlayVisible then UpdateOverlay() else if overlayFrame then overlayFrame:Hide() end end
end

-- ensure overlay updates when hotspots change/expire
local _orig_AddHotspotFromData = AddHotspotFromData
AddHotspotFromData = function(data)
    _orig_AddHotspotFromData(data)
    pcall(UpdateOverlay)
end

-- Run expiration cleanup frequently
C_Timer.NewTicker(5, CleanupExpiredHotspotPins)
