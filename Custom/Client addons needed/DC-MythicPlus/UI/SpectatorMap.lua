-- DC-MythicPlus/UI/SpectatorMap.lua
-- Where the run's members are while spectating a Mythic+ run: class-coloured
-- blips on the minimap, dots on the dungeon map and a roster on the spectator
-- bar. A spectator is not in the group, so the client draws none of its usual
-- party blips; instead the server puts every member (name, GUID, world
-- position, floor), the spectator's own position and the dungeon's floor
-- bounds into each live snapshot (SMSG_SPECTATE_DATA "players", "me" and
-- "floors" - dc_mythicplus_spectator.cpp AppendPositions).
--
-- Positions come from three sources, best first:
--   1. WotLKExtensions' ResolveEntityPositionByGUID: the client's own movement
--      info for any unit it has loaded - the spectator and every member in
--      view - read every tick. Exact and smooth.
--   2. The server's positions, a second old at worst, for members out of view
--      (or a client without the extension).
--   3. The dungeon map places a world position with the floor bounds from
--      DungeonMap.dbc (the map's horizontal axis is world Y with west on the
--      left, its vertical axis is world X with north on top; the spectator's
--      own dot is checked against GetPlayerMapPosition once per floor and an
--      axis is mirrored if the client disagrees). Only a map without floor data
--      uses the extension's world-to-map translation: that works from the
--      WorldMapArea rectangle, which is 0/0/0/0 for every dungeon, so on a
--      dungeon floor it answers NaN or a value clamped to an edge - and a NaN
--      silently hid every dot.
--
-- The minimap blips are anchored to the spectator's LIVE position (source 1),
-- not the snapshot's: the minimap scrolls with the player continuously, and a
-- blip anchored to a second-old centre travels along with the player until the
-- next snapshot, then jumps.
--
-- Clicking a dot or a roster row locks the camera to that member
-- (".spectate watch"); clicking the watched one again releases it
-- (".spectate free"). Both are chat commands, which the server parses before
-- the spectator chat mute applies. /dcspecmap prints what the overlay sees.

local namespace = _G.DCMythicPlusHUD or {}
_G.DCMythicPlusHUD = namespace
namespace.GroupFinder = namespace.GroupFinder or {}
local GF = namespace.GroupFinder

local SpectatorMap = {}
GF.SpectatorMap = SpectatorMap

local BLIP_SIZE = 12
local DOT_SIZE = 14
local ROSTER_ROW_HEIGHT = 13
local HUD_BASE_HEIGHT = 120
-- A white disc with a round alpha mask; tinted per class.
local DISC_TEXTURE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
-- Any farther than this from the client's own reading and the axis is mirrored.
local CALIBRATION_TOLERANCE = 0.04
local REFRESH_INTERVAL = 0.1

-- Visible minimap diameter in yards per zoom step (0-5), the tables Astrolabe,
-- GatherMate and DC-QoS all use.
local MINIMAP_DIAMETER_YARDS = {
    indoor = { [0] = 300, [1] = 240, [2] = 180, [3] = 120, [4] = 80, [5] = 50 },
    outdoor = { [0] = 466 + 2 / 3, [1] = 400, [2] = 333 + 1 / 3, [3] = 266 + 2 / 3, [4] = 200, [5] = 133 + 1 / 3 },
}

local CLASS_TOKENS = {
    [1] = "WARRIOR", [2] = "PALADIN", [3] = "HUNTER", [4] = "ROGUE", [5] = "PRIEST",
    [6] = "DEATHKNIGHT", [7] = "SHAMAN", [8] = "MAGE", [9] = "WARLOCK", [11] = "DRUID",
}

local state = {
    players = nil,        -- members from the last snapshot
    me = nil,             -- the spectator's own position from the same snapshot
    floors = {},          -- [floorIndex] = bounds
    mapId = nil,
    homeMapName = nil,    -- GetMapInfo() of the run's dungeon map
    homeMapAreaId = nil,  -- GetCurrentMapAreaID() of the same
    homeValidated = false,-- captured while the client placed the spectator on it
    homeMapId = nil,      -- the game map the home was read for
    flips = {},           -- [floorIndex] = { x = bool, y = bool } once calibrated
    lastReason = nil,     -- why the dungeon map shows nothing (for /dcspecmap)
}
SpectatorMap.state = state

local blips = {}      -- minimap frames, one per member index
local dots = {}       -- dungeon map buttons
local rosterRows = {} -- spectator bar rows
SpectatorMap.blips = blips
SpectatorMap.dots = dots
SpectatorMap.rosterRows = rosterRows

-- ---------------------------------------------------------------------------
-- Pure maths (covered by _tests/test_spectatormap.lua)
-- ---------------------------------------------------------------------------

function SpectatorMap.ClassColor(classId)
    local token = CLASS_TOKENS[tonumber(classId) or 0]
    local colors = rawget(_G, "RAID_CLASS_COLORS")
    local color = token and colors and colors[token]
    if color then
        return color.r, color.g, color.b
    end
    return 0.8, 0.8, 0.8
end

-- Fraction of the floor map (0..1 from the left edge, 0..1 from the top) for a
-- world position. Nil when the floor has no usable bounds.
function SpectatorMap.FloorFraction(floor, worldX, worldY, flipX, flipY)
    if type(floor) ~= "table" or not tonumber(worldX) or not tonumber(worldY) then
        return nil
    end
    local minX, maxX = tonumber(floor.minX) or 0, tonumber(floor.maxX) or 0
    local minY, maxY = tonumber(floor.minY) or 0, tonumber(floor.maxY) or 0
    local spanX, spanY = maxX - minX, maxY - minY
    if spanX <= 0 or spanY <= 0 then
        return nil
    end

    local fx = (maxX - worldY) / spanX
    local fy = (maxY - worldX) / spanY
    if flipX then fx = 1 - fx end
    if flipY then fy = 1 - fy end
    return fx, fy
end

-- Compares the unflipped answer for the spectator's own position with what the
-- client reports for it. Returns flipX, flipY - or nil when neither reading of
-- an axis matches (the map is showing another floor, or something else).
function SpectatorMap.Calibrate(floor, worldX, worldY, mapX, mapY)
    local fx, fy = SpectatorMap.FloorFraction(floor, worldX, worldY)
    if not fx or not tonumber(mapX) or not tonumber(mapY) then
        return nil
    end

    local function axis(value, expected)
        if math.abs(value - expected) <= CALIBRATION_TOLERANCE then
            return false
        end
        if math.abs((1 - value) - expected) <= CALIBRATION_TOLERANCE then
            return true
        end
        return nil
    end

    local flipX, flipY = axis(fx, mapX), axis(fy, mapY)
    if flipX == nil or flipY == nil then
        return nil
    end
    return flipX, flipY
end

-- Pixel offset from the minimap centre for a member, the distance in yards and
-- whether the point had to be clamped onto the ring. Screen up is north
-- (+world X), screen right is east (-world Y). With `facing` (the minimap is
-- rotating) the world vector is turned into the frame where the player's
-- facing points up; GetPlayerFacing grows counter-clockwise from north.
function SpectatorMap.ProjectMinimap(me, target, radiusPx, diameterYards, facing)
    radiusPx, diameterYards = tonumber(radiusPx), tonumber(diameterYards)
    if type(me) ~= "table" or type(target) ~= "table" or not radiusPx or radiusPx <= 0
        or not diameterYards or diameterYards <= 0 then
        return nil
    end
    local meX, meY = tonumber(me.x), tonumber(me.y)
    local targetX, targetY = tonumber(target.x), tonumber(target.y)
    if not meX or not meY or not targetX or not targetY then
        return nil
    end

    local north = targetX - meX
    local east = -(targetY - meY)
    local distance = math.sqrt((north * north) + (east * east))

    local px, py = east, north
    if facing then
        local cosF, sinF = math.cos(facing), math.sin(facing)
        px, py = (east * cosF) + (north * sinF), (north * cosF) - (east * sinF)
    end

    local scale = radiusPx / (diameterYards * 0.5)
    px, py = px * scale, py * scale

    local projected = distance * scale
    local clamped = projected > radiusPx
    if clamped and projected > 0 then
        local shrink = radiusPx / projected
        px, py = px * shrink, py * shrink
    end
    return px, py, distance, clamped
end

-- One roster line: class-coloured name, leader / watching tags, health, floor.
function SpectatorMap.DescribeMember(player)
    local r, g, b = SpectatorMap.ClassColor(player.class)
    local name = string.format("|cff%02x%02x%02x%s|r",
        math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5), tostring(player.name or "?"))
    local tags = ""
    if player.leader then tags = tags .. " |cffffd100(leader)|r" end
    if player.watched then tags = tags .. " |cffffffff[watching]|r" end
    local status
    if player.alive == false then
        status = "|cff808080dead|r"
    else
        status = string.format("%d%%", math.floor(tonumber(player.health) or 0))
    end
    local floor = tonumber(player.floor) or 0
    local floorText = floor > 0 and string.format("  F%d", floor) or ""
    return name .. tags .. "  " .. status .. floorText
end

-- ---------------------------------------------------------------------------
-- Client extension natives (optional)
-- ---------------------------------------------------------------------------

-- worldX, worldY, worldZ, mapX, mapY for a unit the client has loaded; mapX/Y
-- are that position on the world map view the client is currently showing.
local function NativeUnitPosition(guid)
    local fn = rawget(_G, "ResolveEntityPositionByGUID") or rawget(_G, "C_Ping_ResolveEntityPositionByGUID")
    if type(fn) ~= "function" or type(guid) ~= "string" or guid == "" then
        return nil
    end
    local ok, _, kind, _, mapX, mapY, worldX, worldY, worldZ = pcall(fn, guid)
    if not ok or kind ~= "unit" then
        return nil
    end
    worldX, worldY = tonumber(worldX), tonumber(worldY)
    if not worldX or not worldY or (worldX == 0 and worldY == 0) then
        return nil
    end
    return worldX, worldY, tonumber(worldZ), tonumber(mapX), tonumber(mapY)
end

-- A world position on the world map view the client is showing, as the client
-- itself would place a party member.
local function NativeWorldToCurrentMap(x, y, z)
    local fn = rawget(_G, "TranslateWorldPositionToCurrentMap") or rawget(_G, "C_Ping_TranslateWorldPositionToCurrentMap")
    if type(fn) ~= "function" or not tonumber(x) or not tonumber(y) then
        return nil
    end
    local ok, _, mapX, mapY = pcall(fn, x, y, tonumber(z) or 0)
    if not ok then
        return nil
    end
    mapX, mapY = tonumber(mapX), tonumber(mapY)
    if not mapX or not mapY then
        return nil
    end
    return mapX, mapY
end

-- A usable map fraction: two real numbers inside the map (NaN fails every
-- comparison), and not the (0,0) corner a failed translation clamps to.
local function ValidFraction(fx, fy)
    fx, fy = tonumber(fx), tonumber(fy)
    if not fx or not fy or fx ~= fx or fy ~= fy then
        return nil
    end
    if fx < 0 or fx > 1 or fy < 0 or fy > 1 or (fx == 0 and fy == 0) then
        return nil
    end
    return fx, fy
end
SpectatorMap.ValidFraction = ValidFraction

local playerGuid = nil
local function PlayerGuid()
    if playerGuid then
        return playerGuid
    end
    if type(UnitGUID) ~= "function" then
        return nil
    end
    local ok, guid = pcall(UnitGUID, "player")
    if ok and type(guid) == "string" and guid ~= "" and guid ~= "0x0000000000000000" then
        playerGuid = guid
    end
    return playerGuid
end

-- The spectator's own position: live from the client when the extension is
-- there, else the snapshot's. Returns the table used as the minimap centre.
local function OwnPosition()
    local x, y, z = NativeUnitPosition(PlayerGuid())
    if x then
        local me = state.me
        return { x = x, y = y, z = z, floor = me and me.floor or nil, live = true }
    end
    return state.me
end

-- A member's position: live when in view, else the snapshot's.
local function MemberPosition(player)
    local x, y, z, mapX, mapY = NativeUnitPosition(player.guid)
    if x then
        return x, y, z, mapX, mapY, true
    end
    return tonumber(player.x), tonumber(player.y), tonumber(player.z), nil, nil, false
end

-- ---------------------------------------------------------------------------
-- Client state
-- ---------------------------------------------------------------------------

local function MinimapDiameterYards()
    local dcqos = rawget(_G, "DCQOS")
    if dcqos and type(dcqos.GetMapUtils) == "function" then
        local ok, utils = pcall(dcqos.GetMapUtils, dcqos)
        if ok and type(utils) == "table" and type(utils.GetMinimapDiameterYards) == "function" then
            local okYards, yards = pcall(utils.GetMinimapDiameterYards)
            if okYards and tonumber(yards) and yards > 0 then
                return yards
            end
        end
    end

    local minimap = rawget(_G, "Minimap")
    if not minimap or type(minimap.GetZoom) ~= "function" then
        return MINIMAP_DIAMETER_YARDS.indoor[1]
    end
    local zoom = tonumber(minimap:GetZoom()) or 1
    -- Minimap:SetZoom writes to whichever zoom CVar is in effect, so the CVar
    -- matching the live zoom says which scale the minimap draws at. When both
    -- CVars agree the read is ambiguous; a spectator stands in a dungeon, so
    -- indoors is the better guess.
    local outdoors = false
    if type(GetCVar) == "function" then
        local outside, inside = GetCVar("minimapZoom"), GetCVar("minimapInsideZoom")
        outdoors = outside ~= inside and tonumber(outside) == zoom
    end
    local scale = outdoors and MINIMAP_DIAMETER_YARDS.outdoor or MINIMAP_DIAMETER_YARDS.indoor
    return scale[zoom] or scale[1]
end

local function MinimapFacing()
    if type(GetCVar) == "function" and GetCVar("rotateMinimap") == "1" and type(GetPlayerFacing) == "function" then
        return GetPlayerFacing() or 0
    end
    return nil
end

local function WorldMapShown()
    local frame = rawget(_G, "WorldMapFrame")
    return frame ~= nil and type(frame.IsShown) == "function" and frame:IsShown() == true
end

local function WorldMapParent()
    return rawget(_G, "WorldMapButton") or rawget(_G, "WorldMapDetailFrame") or rawget(_G, "WorldMapFrame")
end

local function CurrentMapAreaId()
    if type(GetCurrentMapAreaID) ~= "function" then
        return nil
    end
    local ok, id = pcall(GetCurrentMapAreaID)
    return ok and tonumber(id) or nil
end

local function CurrentMapName()
    if type(GetMapInfo) ~= "function" then
        return nil
    end
    local ok, name = pcall(GetMapInfo)
    return ok and type(name) == "string" and name or nil
end

local function CurrentDungeonLevel()
    if type(GetCurrentMapDungeonLevel) ~= "function" then
        return 0
    end
    local ok, level = pcall(GetCurrentMapDungeonLevel)
    return ok and tonumber(level) or 0
end

local function OwnMapPosition()
    if type(GetPlayerMapPosition) ~= "function" then
        return nil
    end
    local ok, x, y = pcall(GetPlayerMapPosition, "player")
    if not ok or not tonumber(x) or not tonumber(y) or (x == 0 and y == 0) then
        return nil
    end
    return x, y
end

-- Which world map is the run's dungeon: what the client shows for the
-- spectator's own zone, read while the map is closed so the spectator's own
-- browsing is never reset. A read taken while the client actually places the
-- spectator on that map (GetPlayerMapPosition answers) is final; one taken
-- earlier - the first snapshot can land before the teleport does - is kept
-- only until a validated one replaces it.
local function CaptureHomeMap()
    if state.homeValidated and state.homeMapId == state.mapId then
        return
    end
    if WorldMapShown() or type(SetMapToCurrentZone) ~= "function" then
        return
    end
    pcall(SetMapToCurrentZone)

    local placed = OwnMapPosition() ~= nil
    if not placed and state.homeMapName and state.homeMapId == state.mapId then
        return
    end
    if not placed and not state.me then
        return -- not even inside the run yet
    end

    state.homeMapName = CurrentMapName()
    state.homeMapAreaId = CurrentMapAreaId()
    state.homeValidated = placed
    state.homeMapId = state.mapId
end

-- Is the world map showing the run's dungeon (any floor)?
local function ViewingRunMap()
    local name = CurrentMapName()
    if state.homeMapName and name and name == state.homeMapName then
        return true
    end
    local areaId = CurrentMapAreaId()
    if state.homeMapAreaId and areaId and areaId == state.homeMapAreaId then
        return true
    end
    return false
end

local function CalibrateFloor(floorIndex)
    local floor, me = state.floors[floorIndex], state.me
    if not floor or not me or state.flips[floorIndex] then
        return
    end
    local meFloor = tonumber(me.floor) or 0
    if meFloor ~= 0 and meFloor ~= floorIndex then
        return
    end
    local mapX, mapY = OwnMapPosition()
    if not mapX then
        return
    end
    local flipX, flipY = SpectatorMap.Calibrate(floor, me.x, me.y, mapX, mapY)
    if flipX == nil then
        return
    end
    state.flips[floorIndex] = { x = flipX, y = flipY }
end

local function SendSpectateCommand(text)
    if type(SendChatMessage) == "function" then
        pcall(SendChatMessage, text, "SAY")
    end
end

function SpectatorMap.ToggleWatch(player)
    if type(player) ~= "table" or not player.name then
        return
    end
    if player.watched then
        SendSpectateCommand(".spectate free")
    else
        SendSpectateCommand(".spectate watch " .. tostring(player.name))
    end
end

-- ---------------------------------------------------------------------------
-- Frames
-- ---------------------------------------------------------------------------

local function HideAll(frames)
    for _, frame in ipairs(frames) do
        frame:Hide()
    end
end

local function ShowMemberTooltip(frame, player)
    local tooltip = rawget(_G, "GameTooltip")
    if not tooltip or type(player) ~= "table" then
        return
    end
    tooltip:SetOwner(frame, "ANCHOR_RIGHT")
    local r, g, b = SpectatorMap.ClassColor(player.class)
    tooltip:AddLine(tostring(player.name or "?"), r, g, b)
    if player.alive == false then
        tooltip:AddLine("Dead", 0.6, 0.6, 0.6)
    else
        tooltip:AddLine(string.format("Health: %d%%", math.floor(tonumber(player.health) or 0)), 1, 1, 1)
    end
    local floor = tonumber(player.floor) or 0
    if floor > 0 then
        tooltip:AddLine("Floor " .. floor, 0.7, 0.7, 0.9)
    end
    tooltip:AddLine(player.watched and "Click: release the camera and stand here"
        or "Click: watch through this player", 0.5, 0.8, 1)
    tooltip:Show()
end

local function StyleDisc(frame, size)
    frame:SetSize(size, size)
    frame.ring = frame:CreateTexture(nil, "BACKGROUND")
    frame.ring:SetTexture(DISC_TEXTURE)
    frame.ring:SetPoint("CENTER")
    frame.ring:SetSize(size, size)
    frame.disc = frame:CreateTexture(nil, "ARTWORK")
    frame.disc:SetTexture(DISC_TEXTURE)
    frame.disc:SetPoint("CENTER")
    frame.disc:SetSize(size - 4, size - 4)
end

-- Disc by class, ring by role: white for the member whose eyes the spectator
-- is looking through, gold for the leader, black otherwise. Dead members grey.
local function PaintDisc(frame, player)
    local r, g, b = SpectatorMap.ClassColor(player.class)
    if player.alive == false then
        r, g, b = 0.5, 0.5, 0.5
    end
    frame.disc:SetVertexColor(r, g, b)
    if player.watched then
        frame.ring:SetVertexColor(1, 1, 1)
    elseif player.leader then
        frame.ring:SetVertexColor(1, 0.82, 0)
    else
        frame.ring:SetVertexColor(0, 0, 0)
    end
end

local function AcquireBlip(index)
    local blip = blips[index]
    if blip then
        return blip
    end
    local minimap = rawget(_G, "Minimap")
    if not minimap then
        return nil
    end
    blip = CreateFrame("Frame", nil, minimap)
    blip:SetFrameLevel((minimap:GetFrameLevel() or 0) + 5)
    StyleDisc(blip, BLIP_SIZE)
    blip:Hide()
    blips[index] = blip
    return blip
end

local function AcquireDot(index)
    local dot = dots[index]
    if dot then
        return dot
    end
    local parent = WorldMapParent()
    if not parent then
        return nil
    end
    dot = CreateFrame("Button", nil, parent)
    -- Strata and level follow the map frame on every refresh (RefreshWorldMap):
    -- the stock WorldMapFrame is FULLSCREEN, above any fixed "HIGH".
    StyleDisc(dot, DOT_SIZE)
    dot:EnableMouse(true)
    dot:RegisterForClicks("LeftButtonUp")
    dot:SetScript("OnEnter", function(self) ShowMemberTooltip(self, self.player) end)
    dot:SetScript("OnLeave", function()
        local tooltip = rawget(_G, "GameTooltip")
        if tooltip then tooltip:Hide() end
    end)
    dot:SetScript("OnClick", function(self) SpectatorMap.ToggleWatch(self.player) end)
    dot:Hide()
    dots[index] = dot
    return dot
end

local function AcquireRosterRow(index, hud)
    local row = rosterRows[index]
    if row then
        return row
    end
    row = CreateFrame("Button", nil, hud)
    row:SetSize(276, ROSTER_ROW_HEIGHT)
    row:RegisterForClicks("LeftButtonUp")
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", 4, 0)
    row.text:SetPoint("RIGHT", -4, 0)
    row.text:SetJustifyH("LEFT")
    row:SetScript("OnEnter", function(self) ShowMemberTooltip(self, self.player) end)
    row:SetScript("OnLeave", function()
        local tooltip = rawget(_G, "GameTooltip")
        if tooltip then tooltip:Hide() end
    end)
    row:SetScript("OnClick", function(self) SpectatorMap.ToggleWatch(self.player) end)
    row:Hide()
    rosterRows[index] = row
    return row
end

-- ---------------------------------------------------------------------------
-- Refresh
-- ---------------------------------------------------------------------------

function SpectatorMap.RefreshMinimap()
    local players = state.players
    local minimap = rawget(_G, "Minimap")
    local me = players and OwnPosition() or nil
    if not players or not me or not minimap then
        HideAll(blips)
        return
    end
    state.lastOwn = me

    local radius = ((minimap:GetWidth() or 140) / 2) - (BLIP_SIZE / 2)
    local diameter = MinimapDiameterYards()
    local facing = MinimapFacing()
    local meFloor = tonumber(me.floor) or 0

    for index, player in ipairs(players) do
        local blip = AcquireBlip(index)
        if blip then
            local x, y, _, _, _, live = MemberPosition(player)
            local px, py, _, clamped = SpectatorMap.ProjectMinimap(me, { x = x, y = y }, radius, diameter, facing)
            if px then
                PaintDisc(blip, player)
                local playerFloor = tonumber(player.floor) or 0
                local otherFloor = meFloor ~= 0 and playerFloor ~= 0 and playerFloor ~= meFloor
                blip:SetAlpha(clamped and 0.5 or (otherFloor and 0.6 or 1))
                blip.px, blip.py, blip.clamped, blip.live = px, py, clamped, live
                blip:ClearAllPoints()
                blip:SetPoint("CENTER", minimap, "CENTER", px, py)
                blip:Show()
            else
                blip:Hide()
            end
        end
    end
    for index = #players + 1, #blips do
        blips[index]:Hide()
    end
end

function SpectatorMap.RefreshWorldMap()
    local players = state.players
    local parent = WorldMapParent()
    if not players or not parent or not WorldMapShown() then
        state.lastReason = "map closed"
        HideAll(dots)
        return
    end
    if not ViewingRunMap() then
        state.lastReason = "viewing another map"
        HideAll(dots)
        return
    end

    -- 0 on a map without floor buttons: then nothing is filtered by floor.
    local level = CurrentDungeonLevel()
    local floor = state.floors[level]
    if not floor and level == 0 then
        local onlyIndex, count = nil, 0
        for index in pairs(state.floors) do
            onlyIndex, count = index, count + 1
        end
        floor = count == 1 and state.floors[onlyIndex] or nil
    end
    if floor then
        CalibrateFloor(level)
    end
    local flips = state.flips[level]
    local width, height = parent:GetWidth() or 0, parent:GetHeight() or 0
    local strata = parent.GetFrameStrata and parent:GetFrameStrata() or nil
    local frameLevel = (parent.GetFrameLevel and parent:GetFrameLevel() or 0) + 20
    state.lastReason = nil
    state.dotNotes = {}

    for index, player in ipairs(players) do
        local dot = AcquireDot(index)
        if dot then
            local playerFloor = tonumber(player.floor) or 0
            local onFloor = level == 0 or playerFloor == 0 or playerFloor == level
            local x, y, z, mapX, mapY, live = MemberPosition(player)
            local fx, fy
            if floor then
                fx, fy = ValidFraction(SpectatorMap.FloorFraction(floor, x, y, flips and flips.x, flips and flips.y))
            else
                fx, fy = ValidFraction(mapX, mapY)
                if not fx then
                    fx, fy = ValidFraction(NativeWorldToCurrentMap(x, y, z))
                end
            end

            local name = tostring(player.name or index)
            if not onFloor then
                dot:Hide()
                table.insert(state.dotNotes, string.format("%s: floor %d, map shows %d", name, playerFloor, level))
            elseif not fx then
                dot:Hide()
                table.insert(state.dotNotes, string.format("%s: no map position (%s)", name,
                    floor and "outside the floor bounds" or "no floor data, no client translation"))
            else
                dot.player = player
                dot.fx, dot.fy, dot.live = fx, fy, live
                if strata then
                    dot:SetFrameStrata(strata)
                end
                dot:SetFrameLevel(frameLevel)
                PaintDisc(dot, player)
                dot:ClearAllPoints()
                dot:SetPoint("CENTER", parent, "TOPLEFT", fx * width, -fy * height)
                dot:Show()
                table.insert(state.dotNotes, string.format("%s: %.2f,%.2f", name, fx, fy))
            end
        end
    end
    for index = #players + 1, #dots do
        dots[index]:Hide()
    end
end

function SpectatorMap.RefreshRoster()
    local hud = GF.spectatorHUD
    if not hud or not hud.progressText then
        return
    end
    local players = state.players or {}

    for index, player in ipairs(players) do
        local row = AcquireRosterRow(index, hud)
        row:ClearAllPoints()
        if index == 1 then
            row:SetPoint("TOP", hud.progressText, "BOTTOM", 0, -6)
        else
            row:SetPoint("TOP", rosterRows[index - 1], "BOTTOM", 0, 0)
        end
        row.player = player
        row.text:SetText(SpectatorMap.DescribeMember(player))
        row:Show()
    end
    for index = #players + 1, #rosterRows do
        rosterRows[index]:Hide()
    end

    local extra = #players > 0 and ((#players * ROSTER_ROW_HEIGHT) + 6) or 0
    hud:SetHeight(HUD_BASE_HEIGHT + extra)
end

function SpectatorMap.Clear()
    state.players = nil
    state.me = nil
    state.lastOwn = nil
    HideAll(blips)
    HideAll(dots)
    HideAll(rosterRows)
    if GF.spectatorHUD then
        GF.spectatorHUD:SetHeight(HUD_BASE_HEIGHT)
    end
end

-- ---------------------------------------------------------------------------
-- Entry points (LiveRunsTab.lua calls these from the spectator bar)
-- ---------------------------------------------------------------------------

-- Every live snapshot. Only a Mythic+ snapshot carries positions; anything
-- else (Hinterland, duels, an older server) clears the overlay.
function GF:UpdateSpectatorMap(data)
    if type(data) ~= "table" then
        return
    end
    local system = data.system or self._spectatorSystem or "mplus"
    if system ~= "mplus" or type(data.players) ~= "table" then
        SpectatorMap.Clear()
        return
    end

    state.players = data.players
    state.me = type(data.me) == "table" and data.me or nil
    state.mapId = tonumber(data.mapId)

    local floors = {}
    for _, floor in ipairs(type(data.floors) == "table" and data.floors or {}) do
        local index = tonumber(floor.index)
        if index then
            floors[index] = floor
        end
    end
    state.floors = floors
    if state.homeMapId ~= state.mapId then
        state.flips = {}
    end

    CaptureHomeMap()
    SpectatorMap.RefreshMinimap()
    SpectatorMap.RefreshWorldMap()
    SpectatorMap.RefreshRoster()
end

function GF:HideSpectatorMap()
    SpectatorMap.Clear()
    state.homeMapName = nil
    state.homeMapAreaId = nil
    state.homeValidated = false
    state.homeMapId = nil
    state.floors = {}
    state.flips = {}
end

-- What the overlay sees, for a bug report.
function SpectatorMap.Describe()
    local players = state.players or {}
    local shownBlips, liveBlips, shownDots = 0, 0, 0
    for _, blip in ipairs(blips) do
        if blip:IsShown() then
            shownBlips = shownBlips + 1
            if blip.live then liveBlips = liveBlips + 1 end
        end
    end
    for _, dot in ipairs(dots) do
        if dot:IsShown() then shownDots = shownDots + 1 end
    end
    local own = state.lastOwn
    local floors = 0
    for _ in pairs(state.floors) do floors = floors + 1 end
    return string.format(
        "SpectatorMap: members=%d blips=%d (%d live) dots=%d | own=%s | map=%s/%s level=%s | home=%s/%s%s | floors=%d | %s",
        #players, shownBlips, liveBlips, shownDots,
        own and string.format("%.1f,%.1f%s", own.x or 0, own.y or 0, own.live and " live" or " snapshot") or "none",
        tostring(CurrentMapName()), tostring(CurrentMapAreaId()), tostring(CurrentDungeonLevel()),
        tostring(state.homeMapName), tostring(state.homeMapAreaId), state.homeValidated and " validated" or "",
        floors, state.lastReason or "dots shown")
end

-- One line per member from the last dungeon-map refresh: where its dot went,
-- or why it has none.
function SpectatorMap.DescribeDots()
    if state.lastReason or type(state.dotNotes) ~= "table" or #state.dotNotes == 0 then
        return nil
    end
    return "SpectatorMap dots: " .. table.concat(state.dotNotes, " | ")
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("MINIMAP_UPDATE_ZOOM")
watcher:RegisterEvent("WORLD_MAP_UPDATE")
watcher:RegisterEvent("ZONE_CHANGED_NEW_AREA")
watcher:SetScript("OnEvent", function(_, event)
    if not state.players then
        return
    end
    if event == "MINIMAP_UPDATE_ZOOM" then
        SpectatorMap.RefreshMinimap()
    elseif event == "WORLD_MAP_UPDATE" then
        SpectatorMap.RefreshWorldMap()
    else
        -- Landed in the run (or somewhere else): re-read which map is home.
        state.homeValidated = false
        CaptureHomeMap()
    end
end)

local worldMapFrame = rawget(_G, "WorldMapFrame")
if worldMapFrame and type(worldMapFrame.HookScript) == "function" then
    worldMapFrame:HookScript("OnShow", function() SpectatorMap.RefreshWorldMap() end)
    worldMapFrame:HookScript("OnHide", function() HideAll(dots) end)
end

-- Live positions: the spectator moves, members in view move, the minimap
-- may rotate. Ten times a second is plenty for a dozen small frames.
local ticker = CreateFrame("Frame")
ticker.elapsed = 0
ticker:SetScript("OnUpdate", function(self, elapsed)
    if not state.players then
        return
    end
    self.elapsed = self.elapsed + (elapsed or 0)
    if self.elapsed < REFRESH_INTERVAL then
        return
    end
    self.elapsed = 0
    if not state.homeValidated then
        CaptureHomeMap()
    end
    SpectatorMap.RefreshMinimap()
    if WorldMapShown() then
        SpectatorMap.RefreshWorldMap()
    end
end)

SLASH_DCSPECMAP1 = "/dcspecmap"
SlashCmdList["DCSPECMAP"] = function()
    local frame = rawget(_G, "DEFAULT_CHAT_FRAME")
    if frame and frame.AddMessage then
        frame:AddMessage(SpectatorMap.Describe())
        local dots = SpectatorMap.DescribeDots()
        if dots then
            frame:AddMessage(dots)
        end
    end
end
