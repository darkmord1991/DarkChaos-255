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
-- stays on the world map only -- flight masters do, because the engine already
-- draws its own green taxi boot for them here.
--
-- Positioning uses the shared mapUtils.ProjectToMinimap helper, which honours
-- minimap rotation and zoom. Like the client's own minimap POI blips, a pin is
-- drawn only while it falls inside the visible minimap ring; beyond that it is
-- hidden rather than piled onto the edge.
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
        },
    },
}

local UPDATE_INTERVAL_SECONDS = 0.2
local EDGE_PADDING_PIXELS = 10
local MIN_PIN_SIZE = 10
local MAX_PIN_SIZE = 28

local state = {
    container = nil,
    pins = {},
    elapsed = 0,
    driver = nil,
    eventFrame = nil,
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
            pin.poiData = nil
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

    pin:SetScript("OnEnter", OnPinEnter)
    pin:SetScript("OnLeave", OnPinLeave)

    state.pins[index] = pin
    return pin
end

-- Apply the type's minimap icon. Paths are validated when a type is added to
-- MapPOIData.TYPES, not here: the client draws nothing for an unknown texture
-- and reports no error, so there is nothing meaningful to detect at runtime.
local function ApplyPinIcon(pin, typeInfo)
    local desired = typeInfo and (typeInfo.minimapIcon or typeInfo.worldIcon)
    if not desired then
        return
    end
    if pin.appliedIcon == desired then
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

    pin.appliedIcon = desired
end

function MapPOIMinimap:Refresh()
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
        or type(mapUtils.ProjectToMinimap) ~= "function"
        or type(mapUtils.WorldToMapPosition) ~= "function" then
        HidePinsFrom(1)
        return
    end

    local playerX, playerY, uiMapId = mapUtils.GetPlayerMapPositionSafe()
    if not playerX or not playerY or not uiMapId then
        HidePinsFrom(1)
        return
    end

    local radiusPx = (math.min(Minimap:GetWidth() or 0, Minimap:GetHeight() or 0) * 0.5)
        - EDGE_PADDING_PIXELS
    if radiusPx <= 0 then
        HidePinsFrom(1)
        return
    end

    local container = EnsureContainer()
    if not container then
        return
    end

    local pinSize = GetPinSize()
    local mouseEnabled = settings.showTooltips ~= false
    local shown = 0

    local typeKeys = poiData:GetTypeKeys()
    for keyIndex = 1, #typeKeys do
        local poiType = typeKeys[keyIndex]
        local typeInfo = poiData:GetTypeInfo(poiType)
        local pois = poiData:GetPOIsByType(poiType)

        if typeInfo and type(pois) == "table"
            and IsTypeOnMinimap(poiData, poiType) and poiData:IsTypeEnabled(poiType) then
            for i = 1, #pois do
                local poi = pois[i]
                -- WorldToMapPosition rejects points that are not on the map area
                -- currently under the player, so this doubles as the map filter.
                local normX, normY = mapUtils.WorldToMapPosition(uiMapId, poi.map, poi.x, poi.y, true)
                if normX and normY then
                    local pixelX, pixelY, distanceYards, isClamped =
                        mapUtils.ProjectToMinimap(uiMapId, playerX, playerY, normX, normY, radiusPx)

                    if pixelX and pixelY and not isClamped then
                        shown = shown + 1
                        local pin = AcquirePin(shown)
                        if pin then
                            pin.poiData = {
                                name = poi.name,
                                label = typeInfo.label,
                                distanceYards = distanceYards,
                            }
                            ApplyPinIcon(pin, typeInfo)
                            pin:SetSize(pinSize, pinSize)
                            pin:EnableMouse(mouseEnabled)
                            pin:ClearAllPoints()
                            pin:SetPoint("CENTER", container, "CENTER", pixelX, pixelY)
                            pin:Show()
                        end
                    end
                end
            end
        end
    end

    HidePinsFrom(shown + 1)
end

local function EnsureDriver()
    if state.driver then
        return state.driver
    end

    local driver = CreateFrame("Frame")
    driver:SetScript("OnUpdate", function(_, elapsed)
        state.elapsed = state.elapsed + (elapsed or 0)
        if state.elapsed < UPDATE_INTERVAL_SECONDS then
            return
        end
        state.elapsed = 0
        MapPOIMinimap:Refresh()
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
        state.eventFrame:SetScript("OnEvent", function()
            if addon.MapPOIData and type(addon.MapPOIData.EnsureRequested) == "function" then
                addon.MapPOIData:EnsureRequested()
            end
            MapPOIMinimap:Refresh()
        end)
    end

    state.eventFrame:UnregisterAllEvents()
    state.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    state.eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

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
    desc:SetText("Shows server-provided map markers (innkeepers, mailboxes, teleporters) on the minimap, following minimap rotation and zoom. Flight masters are world-map only -- the client already blips those on the minimap itself.")

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
