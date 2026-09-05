-- ============================================================
-- DC-QoS: Map POI Minimap Pins
-- ============================================================
-- Minimap counterpart to the world-map POI layer in QuestMapPins. Renders the
-- server-fed POIs from MapPOIData as minimap blips with a name tooltip, so a
-- service NPC can be spotted from the minimap the same way quest markers are --
-- which matters most on the custom maps (Azshara Crater, DC Hyjal, DC
-- Plaguelands, Hyjal Frontier).
--
-- Icons and labels come from MapPOIData.TYPES, so a new POI kind shows up here
-- automatically once it is registered there. A type that sets `minimap = false`
-- stays on the world map only; a type that sets `requiresDiscovery` (flight
-- masters) waits until the player has discovered the flight point, so the pin
-- never stacks on the client's own undiscovered-flight-point marker.
--
-- Positioning works in WORLD coordinates: both the player (from
-- mapUtils.GetPlayerPosition, which reads the client's movement info) and the
-- server-fed POIs are world positions, and world coordinates are already yards,
-- so mapUtils.ProjectWorldToMinimap turns the difference into pixels with no
-- WorldMapArea rectangle in the path -- nothing to normalize and nothing that
-- depends on which zone the world map happens to be showing. Minimap rotation
-- and zoom are honoured. Like the client's own minimap POI blips, a pin is drawn
-- only while it falls inside the visible minimap ring; beyond that it is hidden
-- rather than piled onto the edge.
--
-- The normalized path (mapUtils.ProjectToMinimap) is kept only as a fallback for
-- a client whose WotLKExtensions build predates the native world position. It
-- reads GetPlayerMapPosition, which answers 0,0 whenever the world map is not on
-- the player's own zone; a pin projected from the last good answer holds a fixed
-- offset from the minimap centre -- and the centre IS the player -- so it rides
-- along until a fresh read arrives. That is what the world path removes.
--
-- The scan/draw split matters: the POI scan is throttled but drawing runs every
-- frame, because doing both at the scan rate is what made pins visibly step and
-- lurch as the player moved or the minimap rotated.
-- ============================================================

local addon = DCQOS
if not addon then
    return
end

local MapPOIMinimap = {
    displayName = "MapPOIMinimap",
    settingKey = "mapPoiMinimap",
    icon = "Interface\\Icons\\Ability_Mount_Wyvern_01",
    defaults = {
        mapPoiMinimap = {
            enabled = true,
            showTooltips = true,
            pinSize = 16,
        },
        -- Shared with the world-map layer (QuestMapPins): one toggle per
        -- marker type drives both surfaces.
        mapPoiTypes = {
            flight = true,
            inn = true,
            mail = true,
            teleporter = true,
            dungeon = true,
            raid = true,
        },
    },
}

-- How often the POI set is re-scanned. Scanning walks every POI the server sent
-- (hundreds), so it stays throttled -- but the pins themselves are re-placed
-- EVERY frame from that cached set, which is what keeps them still. Placing at
-- the scan rate instead made pins step ~5 times a second while the player moved,
-- and with a rotating minimap they lurched around the ring, because the heading
-- was only recomputed at the same 5 Hz.
local RESCAN_INTERVAL_SECONDS = 0.2
local EDGE_PADDING_PIXELS = 10
local MIN_PIN_SIZE = 10
local MAX_PIN_SIZE = 28

-- A pin exactly on the ring boundary would otherwise flip between shown and
-- hidden on consecutive frames as the player moves. Once visible it stays
-- visible slightly past the edge.
local CLAMP_HYSTERESIS = 0.08

-- Legacy path only (a client without the native world position). See
-- GetPinAnchor: the world-map read reports nothing while the world map is open
-- on another zone, and without a grace window every pin blinked out for those
-- frames. Kept deliberately short -- a pin drawn from a stale player position is
-- a pin that travels with the player.
local POSITION_GRACE_SECONDS = 0.35

-- How far past the visible ring the throttled scan collects POIs, as a multiple
-- of the minimap's radius in yards. The surplus is what lets the scan stay on
-- its 0.2s throttle while the player keeps moving: anything that could enter the
-- ring before the next scan is already in the candidate list.
local SCAN_RADIUS_MULTIPLIER = 2.0

local state = {
    container = nil,
    pins = {},
    -- Cached scan output: reused tables, so a rescan allocates nothing.
    candidates = {},
    candidateCount = 0,
    candidateMapId = nil,
    candidateMode = nil,
    candidatesStale = true,
    -- Where the last scan was taken from, and how far the player may travel
    -- from it before the collected set could be missing something (world mode).
    scanX = nil,
    scanY = nil,
    scanSlackYards = 0,
    rescanElapsed = 0,
    driver = nil,
    eventFrame = nil,
    lastPlayerX = nil,
    lastPlayerY = nil,
    lastPlayerMapId = nil,
    lastPlayerTime = 0,
}

local function GetSettings()
    return addon.settings and addon.settings.mapPoiMinimap or addon.defaults.mapPoiMinimap
end

local function GetMapUtils()
    return type(addon.GetMapUtils) == "function" and addon:GetMapUtils() or nil
end

local function GetPinSize()
    local size = tonumber(GetSettings().pinSize) or 16
    if size < MIN_PIN_SIZE then
        size = MIN_PIN_SIZE
    elseif size > MAX_PIN_SIZE then
        size = MAX_PIN_SIZE
    end
    return size
end

-- A type can opt out of the minimap (MapPOIData.TYPES[t].minimap == false) when
-- the client already blips it there itself -- flight masters get a green taxi
-- boot from the engine, so they stay world-map only.
local function IsTypeOnMinimap(poiData, poiType)
    if type(poiData.IsTypeOnMinimap) ~= "function" then
        return true
    end
    return poiData:IsTypeOnMinimap(poiType)
end

local function HidePinsFrom(startIndex)
    for index = startIndex, #state.pins do
        local pin = state.pins[index]
        if pin then
            -- poiData is a scratch table the pin OWNS for its lifetime (see
            -- AcquirePin), so clear its fields rather than the table itself --
            -- dropping the table would leave the next Reposition that reuses
            -- this pin writing into a nil.
            local poiInfo = pin.poiData
            if poiInfo then
                poiInfo.name = nil
                poiInfo.label = nil
                poiInfo.distanceYards = nil
            end
            pin:Hide()
        end
    end
end

local function EnsureContainer()
    if state.container then
        return state.container
    end
    if not Minimap then
        return nil
    end

    local container = CreateFrame("Frame", nil, Minimap)
    container:SetAllPoints(Minimap)
    container:SetFrameStrata(Minimap:GetFrameStrata() or "MEDIUM")
    container:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 10)
    container:EnableMouse(false)

    state.container = container
    return container
end

local function Now()
    return (type(GetTime) == "function" and GetTime()) or 0
end

-- What the pins are measured from, resolved fresh every frame.
--
-- Returns mode, a, b, mapId:
--   "world" -> a,b are the player's WORLD x/y and mapId is the game map id.
--              POI positions are world coordinates too, so nothing has to be
--              normalized, no WorldMapArea rectangle is involved, and the read
--              cannot fail or go stale.
--   "map"   -> a,b are normalized map coordinates and mapId is a UI map id.
--              Legacy fallback for a client whose WotLKExtensions build has no
--              native world position.
--
-- The world path is what stops pins from travelling with the player. The map
-- path reads GetPlayerMapPosition, which answers 0,0 whenever the world map is
-- showing something other than the player's zone -- and a pin projected from the
-- last good answer holds a fixed offset from the minimap centre, which is the
-- player, so it rides along until a fresh read arrives.
local function GetPinAnchor(mapUtils)
    local normX, normY, uiMapId, worldX, worldY, gameMapId = mapUtils.GetPlayerPosition()

    if worldX and worldY and gameMapId then
        return "world", worldX, worldY, gameMapId
    end

    if normX and normY and uiMapId then
        state.lastPlayerX, state.lastPlayerY, state.lastPlayerMapId = normX, normY, uiMapId
        state.lastPlayerTime = Now()
        return "map", normX, normY, uiMapId
    end

    if state.lastPlayerX and (Now() - state.lastPlayerTime) <= POSITION_GRACE_SECONDS then
        return "map", state.lastPlayerX, state.lastPlayerY, state.lastPlayerMapId
    end

    return nil
end

local function OnPinEnter(self)
    local poi = self.poiData
    if not poi or not GameTooltip then
        return
    end

    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(poi.name or poi.label or "Point of Interest", 1.0, 0.84, 0.22)
    if poi.label then
        GameTooltip:AddLine(poi.label, 0.88, 0.88, 0.88)
    end
    if poi.distanceYards then
        GameTooltip:AddLine(string.format("%d yards away", math.floor(poi.distanceYards + 0.5)),
            0.66, 0.78, 0.66)
    end
    GameTooltip:Show()
end

local function OnPinLeave()
    if GameTooltip then
        GameTooltip:Hide()
    end
end

local function AcquirePin(index)
    local pin = state.pins[index]
    if pin then
        return pin
    end

    local container = EnsureContainer()
    if not container then
        return nil
    end

    pin = CreateFrame("Button", nil, container)
    pin:SetFrameLevel(container:GetFrameLevel() + 4)
    pin:Hide()

    pin.Icon = pin:CreateTexture(nil, "ARTWORK")
    pin.Icon:SetAllPoints(pin)

    -- Written in place every frame; a fresh table per pin per frame was pure
    -- garbage for the collector.
    pin.poiData = {}

    pin:SetScript("OnEnter", OnPinEnter)
    pin:SetScript("OnLeave", OnPinLeave)

    state.pins[index] = pin
    return pin
end

-- Apply the type's minimap icon. Paths are validated when a type is added to
-- MapPOIData.TYPES, not here: the client draws nothing for an unknown texture
-- and reports no error, so there is nothing meaningful to detect at runtime.
--
-- Keyed on the TYPE, not on the texture path: teleporter, dungeon and raid all
-- draw the same portal art and differ only in tint, so keying on the path let a
-- recycled pin keep the previous type's colour -- a dungeon entrance rendered in
-- teleporter purple.
local function ApplyPinIcon(pin, poiType, typeInfo)
    local desired = typeInfo and (typeInfo.minimapIcon or typeInfo.worldIcon)
    if not desired then
        return
    end
    if pin.appliedIcon == poiType then
        return
    end

    pin.Icon:SetTexture(desired)

    local texCoord = typeInfo.texCoord
    if type(texCoord) == "table" then
        pin.Icon:SetTexCoord(texCoord[1] or 0, texCoord[2] or 1, texCoord[3] or 0, texCoord[4] or 1)
    else
        pin.Icon:SetTexCoord(0, 1, 0, 1)
    end

    local color = typeInfo.iconColor
    if type(color) == "table" then
        pin.Icon:SetVertexColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
    else
        pin.Icon:SetVertexColor(1, 1, 1, 1)
    end

    pin.appliedIcon = poiType
end

-- Whether a POI may show on the minimap right now. Static type opt-outs are
-- handled by IsTypeOnMinimap; this is the per-POI, changes-over-time part
-- (flight masters wait for their flight point to be discovered).
local function IsPOIVisibleNow(poiData, poi)
    if type(poiData.IsMinimapVisibleNow) ~= "function" then
        return true
    end
    return poiData:IsMinimapVisibleNow(poi)
end

-- Re-scan every POI for the ones that could be on the minimap, so the per-frame
-- pass walks a handful of entries instead of the whole server list. Throttled;
-- see RESCAN_INTERVAL_SECONDS.
--
-- In world mode the entry keeps no position of its own: the POI's world x/y is
-- already what the projection wants, so there is nothing to cache and nothing to
-- invalidate. In the legacy map mode the normalized position is cached, because
-- deriving it costs a bounds lookup per POI.
--
-- The cached order is what pins are keyed by, so a pin keeps showing the same
-- POI for the life of the scan. Assigning pins by "how many are visible right
-- now" instead made every pin after a POI that left the ring shift down a slot
-- and swap icon with its neighbour.
local function RebuildCandidates(poiData, mapUtils, mode, anchorA, anchorB, mapId, scanRadiusYards)
    local candidates = state.candidates
    local count = 0

    local typeKeys = poiData:GetTypeKeys()
    for keyIndex = 1, #typeKeys do
        local poiType = typeKeys[keyIndex]
        local typeInfo = poiData:GetTypeInfo(poiType)
        local pois = poiData:GetPOIsByType(poiType)

        if typeInfo and type(pois) == "table"
            and IsTypeOnMinimap(poiData, poiType) and poiData:IsTypeEnabled(poiType) then
            for i = 1, #pois do
                local poi = pois[i]
                if IsPOIVisibleNow(poiData, poi) then
                    local keep, normX, normY

                    if mode == "world" then
                        -- Same game map, and near enough that it could be on the
                        -- minimap before the next scan. A box test, not a circle:
                        -- two comparisons per POI, and the surplus corners cost
                        -- nothing because the per-frame projection hides anything
                        -- outside the ring anyway.
                        --
                        -- Note there is no map-AREA test here. The zone rectangle
                        -- a POI falls in is a world-map concern; the minimap only
                        -- cares how far away it is, so a flight master fifty yards
                        -- outside the city's rectangle still gets a pin.
                        keep = poi.map == mapId
                            and math.abs(poi.x - anchorA) <= scanRadiusYards
                            and math.abs(poi.y - anchorB) <= scanRadiusYards
                    else
                        -- Legacy path: WorldToMapPosition rejects points that are
                        -- not on the map area currently under the player, so this
                        -- doubles as the map filter.
                        normX, normY = mapUtils.WorldToMapPosition(mapId, poi.map, poi.x, poi.y, true)
                        keep = normX and normY
                    end

                    if keep then
                        count = count + 1
                        local entry = candidates[count]
                        if not entry then
                            entry = {}
                            candidates[count] = entry
                        end
                        entry.poi = poi
                        entry.poiType = poiType
                        entry.typeInfo = typeInfo
                        entry.normX = normX
                        entry.normY = normY
                    end
                end
            end
        end
    end

    state.candidateCount = count
    state.candidateMapId = mapId
    state.candidateMode = mode
    state.candidatesStale = false

    if mode == "world" then
        state.scanX, state.scanY = anchorA, anchorB
    else
        state.scanX, state.scanY = nil, nil
    end
end

-- Place the cached candidates. Cheap enough to run every frame, which is what
-- keeps pins gliding with the player and the minimap's rotation.
local function Reposition()
    local settings = GetSettings()
    if not settings.enabled then
        HidePinsFrom(1)
        return
    end

    if not Minimap or not Minimap.IsVisible or not Minimap:IsVisible() then
        HidePinsFrom(1)
        return
    end

    local poiData = addon.MapPOIData
    local mapUtils = GetMapUtils()
    if not poiData or not mapUtils
        or type(poiData.GetTypeKeys) ~= "function"
        or type(poiData.GetPOIsByType) ~= "function"
        or type(mapUtils.GetPlayerPosition) ~= "function"
        or type(mapUtils.ProjectWorldToMinimap) ~= "function"
        or type(mapUtils.ProjectToMinimap) ~= "function"
        or type(mapUtils.WorldToMapPosition) ~= "function" then
        HidePinsFrom(1)
        return
    end

    local mode, anchorA, anchorB, mapId = GetPinAnchor(mapUtils)
    if not mode then
        HidePinsFrom(1)
        return
    end

    -- The SCALE must use the minimap's full half-width, because that is the
    -- radius the zoom's yard diameter actually spans. Subtracting the edge
    -- padding here instead shrank every pin's distance by the padding's share of
    -- the radius (10 of 70 -- a seventh) on top of whatever the projection said.
    -- The padding belongs to the visibility test only, below.
    local radiusPx = math.min(Minimap:GetWidth() or 0, Minimap:GetHeight() or 0) * 0.5
    if radiusPx <= EDGE_PADDING_PIXELS then
        HidePinsFrom(1)
        return
    end

    local container = EnsureContainer()
    if not container then
        return
    end

    local halfDiameterYards = (mapUtils.GetMinimapDiameterYards() or 0) * 0.5
    if halfDiameterYards <= 0 then
        HidePinsFrom(1)
        return
    end

    local scanRadiusYards = halfDiameterYards * SCAN_RADIUS_MULTIPLIER

    -- Where a pin stops being drawn: the ring, pulled in by the edge padding so
    -- a pin on the boundary is not half-clipped by the minimap's border art.
    local ringYards = halfDiameterYards * ((radiusPx - EDGE_PADDING_PIXELS) / radiusPx)

    local rescan = state.candidatesStale
        or state.candidateMapId ~= mapId
        or state.candidateMode ~= mode
    if not rescan and mode == "world" and state.scanX then
        -- A teleport, or simply the ring growing after a zoom out, can put the
        -- player further from the last scan point than its surplus covers before
        -- the throttle comes round again.
        local dx, dy = anchorA - state.scanX, anchorB - state.scanY
        local slack = scanRadiusYards - halfDiameterYards
        rescan = ((dx * dx) + (dy * dy)) > (slack * slack)
    end
    if rescan then
        RebuildCandidates(poiData, mapUtils, mode, anchorA, anchorB, mapId, scanRadiusYards)
    end

    local pinSize = GetPinSize()
    local mouseEnabled = settings.showTooltips ~= false

    for index = 1, state.candidateCount do
        local entry = state.candidates[index]
        local pin = AcquirePin(index)
        if pin then
            local pixelX, pixelY, distanceYards
            if mode == "world" then
                pixelX, pixelY, distanceYards = mapUtils.ProjectWorldToMinimap(
                    anchorA, anchorB, entry.poi.x, entry.poi.y, radiusPx)
            else
                pixelX, pixelY, distanceYards = mapUtils.ProjectToMinimap(
                    mapId, anchorA, anchorB, entry.normX, entry.normY, radiusPx)
            end

            -- A pin already on screen is allowed a little past the ring before
            -- it drops out, so a POI sitting on the boundary cannot strobe.
            local limit = pin:IsShown() and (1 + CLAMP_HYSTERESIS) or 1
            local withinRing = pixelX and distanceYards
                and (distanceYards / ringYards) <= limit

            if withinRing then
                local poiInfo = pin.poiData
                if not poiInfo then
                    poiInfo = {}
                    pin.poiData = poiInfo
                end
                poiInfo.name = entry.poi.name
                poiInfo.label = entry.typeInfo.label
                poiInfo.distanceYards = distanceYards

                ApplyPinIcon(pin, entry.poiType, entry.typeInfo)
                pin:SetSize(pinSize, pinSize)
                pin:EnableMouse(mouseEnabled)
                pin:ClearAllPoints()
                pin:SetPoint("CENTER", container, "CENTER", pixelX, pixelY)
                pin:Show()
            else
                pin:Hide()
            end
        end
    end

    HidePinsFrom(state.candidateCount + 1)
end

-- Forces a re-scan on the next frame. Called when the POI list, its settings or
-- the discovered flight points change.
function MapPOIMinimap:Refresh()
    state.candidatesStale = true
    Reposition()
end

local function EnsureDriver()
    if state.driver then
        return state.driver
    end

    local driver = CreateFrame("Frame")
    driver:SetScript("OnUpdate", function(_, elapsed)
        state.rescanElapsed = state.rescanElapsed + (elapsed or 0)
        if state.rescanElapsed >= RESCAN_INTERVAL_SECONDS then
            state.rescanElapsed = 0
            state.candidatesStale = true
        end
        Reposition()
    end)

    state.driver = driver
    return driver
end

function MapPOIMinimap.OnInitialize()
    addon:RegisterSettingsKeywords("MapPOIMinimap", {
        "minimap",
        "flight master",
        "flightmaster",
        "taxi",
        "map markers",
        "poi",
    })
end

function MapPOIMinimap.OnEnable()
    -- The minimap layer is visible without ever opening the world map, so it
    -- owns the initial sync of the POI list.
    if addon.MapPOIData and type(addon.MapPOIData.EnsureRequested) == "function" then
        addon.MapPOIData:EnsureRequested()
    end

    if not state.eventFrame then
        state.eventFrame = CreateFrame("Frame")
        state.eventFrame:SetScript("OnEvent", function(_, event)
            local poiData = addon.MapPOIData
            if poiData and type(poiData.EnsureRequested) == "function" then
                poiData:EnsureRequested()
            end

            -- A flight point is discovered by talking to its master, so the
            -- discovered set is re-pulled after any such conversation as well as
            -- on the usual login/zone boundaries. The core exposes no taxi
            -- discovery hook to push from.
            if event ~= "PLAYER_ENTERING_WORLD"
                and poiData and type(poiData.RefreshKnownTaxi) == "function" then
                poiData:RefreshKnownTaxi(event == "TAXIMAP_CLOSED")
            end

            MapPOIMinimap:Refresh()
        end)
    end

    state.eventFrame:UnregisterAllEvents()
    state.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    state.eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    state.eventFrame:RegisterEvent("TAXIMAP_CLOSED")
    state.eventFrame:RegisterEvent("GOSSIP_CLOSED")

    EnsureDriver():Show()
    MapPOIMinimap:Refresh()
end

function MapPOIMinimap.OnDisable()
    if state.eventFrame then
        state.eventFrame:UnregisterAllEvents()
    end
    if state.driver then
        state.driver:Hide()
    end
    HidePinsFrom(1)
end

function MapPOIMinimap.CreateSettings(parent)
    local settings = GetSettings()

    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Minimap Markers")

    local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetWidth(460)
    desc:SetJustifyH("LEFT")
    desc:SetText("Shows server-provided map markers (flight masters, innkeepers, mailboxes, teleporters) on the minimap, following minimap rotation and zoom. A flight master appears once you have discovered its flight point, so it does not stack on top of the client's own undiscovered-flight-point marker.")

    local yOffset = -76

    local enabledCb = addon:CreateCheckbox(parent)
    enabledCb:SetPoint("TOPLEFT", 16, yOffset)
    enabledCb.Text:SetText("Show map markers on the minimap")
    enabledCb:SetChecked(settings.enabled ~= false)
    enabledCb:SetScript("OnClick", function(self)
        addon:SetSetting("mapPoiMinimap.enabled", self:GetChecked())
        if self:GetChecked() and addon.MapPOIData
            and type(addon.MapPOIData.EnsureRequested) == "function" then
            addon.MapPOIData:EnsureRequested()
        end
        MapPOIMinimap:Refresh()
    end)
    yOffset = yOffset - 28

    local tooltipCb = addon:CreateCheckbox(parent)
    tooltipCb:SetPoint("TOPLEFT", 16, yOffset)
    tooltipCb.Text:SetText("Show a tooltip when hovering a minimap marker")
    tooltipCb:SetChecked(settings.showTooltips ~= false)
    tooltipCb:SetScript("OnClick", function(self)
        addon:SetSetting("mapPoiMinimap.showTooltips", self:GetChecked())
        MapPOIMinimap:Refresh()
    end)
    yOffset = yOffset - 36

    -- Per-type toggles, generated from the shared registry so a new marker type
    -- needs no settings work. These apply to the world map as well.
    local poiData = addon.MapPOIData
    if poiData and type(poiData.GetTypeKeys) == "function" then
        local heading = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        heading:SetPoint("TOPLEFT", 16, yOffset)
        heading:SetText("Marker types (world map and minimap)")
        yOffset = yOffset - 24

        local typeKeys = poiData:GetTypeKeys()
        for index = 1, #typeKeys do
            local poiType = typeKeys[index]
            local typeInfo = poiData:GetTypeInfo(poiType)
            local typeCb = addon:CreateCheckbox(parent)
            typeCb:SetPoint("TOPLEFT", 28, yOffset)
            local typeLabel = typeInfo and typeInfo.label or poiType
            if not IsTypeOnMinimap(poiData, poiType) then
                typeLabel = typeLabel .. " (world map only)"
            end
            typeCb.Text:SetText(typeLabel)
            typeCb:SetChecked(poiData:IsTypeEnabled(poiType))
            typeCb:SetScript("OnClick", function(self)
                addon:SetSetting("mapPoiTypes." .. poiType, self:GetChecked())
                MapPOIMinimap:Refresh()
                local worldMap = type(addon.GetModule) == "function"
                    and addon:GetModule("QuestMapPins") or nil
                if worldMap and type(worldMap.Refresh) == "function" then
                    worldMap:Refresh()
                end
            end)
            yOffset = yOffset - 26
        end
    end

    return yOffset - 40
end

addon:RegisterModule("MapPOIMinimap", MapPOIMinimap)
