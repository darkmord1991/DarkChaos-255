-- DC-MapExtension: Clean implementation for WoW 3.3.5a
-- Adds custom zone maps for Azshara Crater and Hyjal to the standard world map
-- NOW USES STANDARD WOW MAP API for full compatibility with existing addons

----------------------------------------------
-- Constants
----------------------------------------------
local AZSHARA_CRATER_MAP_ID = 37  -- Custom map ID for Azshara Crater
local AZSHARA_CRATER_ZONE_ID = 268
local HYJAL_MAP_ID = 1  -- Hyjal is on map 1 (Kalimdor continent)
local HYJAL_ZONE_ID = 616  -- Hyjal's zone ID

local TILE_COLS = 4
local TILE_ROWS = 3

----------------------------------------------
-- Saved Variables
----------------------------------------------
DCMapExtensionDB = DCMapExtensionDB or {}

-- Default settings
local function InitDefaults()
    if DCMapExtensionDB.enabled == nil then DCMapExtensionDB.enabled = true end
    if DCMapExtensionDB.showPlayerDot == nil then DCMapExtensionDB.showPlayerDot = true end
    if DCMapExtensionDB.debug == nil then DCMapExtensionDB.debug = false end
    if not DCMapExtensionDB.initialized then
        DCMapExtensionDB.debug = false
        DCMapExtensionDB.initialized = true
    end
end

----------------------------------------------
-- Addon State
----------------------------------------------
local addon = {
    stitchFrame = nil,
    playerDot = nil,
    poiMarkers = {},
    hotspotMarkers = {},
    currentMap = nil,
    forcedMap = nil,
    initialized = false,
    lastDebugMap = nil,
    lastDebugTime = 0,
    lastPlayerPosDebug = 0,
    -- GPS data from server
    gpsData = {
        mapId = 0,
        zoneId = 0,
        x = 0,
        y = 0,
        z = 0,
        nx = 0,  -- normalized x (0-1)
        ny = 0,  -- normalized y (0-1)
        lastUpdate = 0
    }
}

local MAP_TYPES = {
    azshara = { mapId = 37, zoneId = 268, worldMapAreaId = 613 },
    hyjal = { mapId = 1, zoneId = 616, altMapIds = { 616 }, worldMapAreaId = 614 }
}

local function ContainsValue(tbl, value)
    if not tbl or value == nil then
        return false
    end
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

local NATIVE_MAP_AREA_IDS = {
    azshara = 613,
    hyjal = 614
}

local function Clamp01(value)
    if value == nil then return nil end
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

local function NormalizeMapCoords(mapType, nx, ny)
    if nx == nil or ny == nil then
        return nil, nil
    end

    -- Custom map specific adjustments
    if mapType == "azshara" then
        nx = 1 - nx
    end

    -- Convert to WoW's top-left origin (0 = top)
    ny = 1 - ny

    return Clamp01(nx), Clamp01(ny)
end

local function ResolveMapType(mapId, zoneId)
    if addon.currentMap then
        return addon.currentMap
    end

    for mapType, info in pairs(MAP_TYPES) do
        if info.mapId == mapId or info.zoneId == zoneId or ContainsValue(info.altMapIds, mapId) then
            return mapType
        end
    end

    return nil
end

----------------------------------------------
-- Texture Paths
----------------------------------------------
local texturePaths = {
    azshara = {
        "Interface\\WorldMap\\AzsharaCrater\\AzsharaCrater1",
        "Interface\\WorldMap\\AzsharaCrater\\AzsharaCrater2",
        "Interface\\WorldMap\\AzsharaCrater\\AzsharaCrater3",
        "Interface\\WorldMap\\AzsharaCrater\\AzsharaCrater4",
        "Interface\\WorldMap\\AzsharaCrater\\AzsharaCrater5",
        "Interface\\WorldMap\\AzsharaCrater\\AzsharaCrater6",
        "Interface\\WorldMap\\AzsharaCrater\\AzsharaCrater7",
        "Interface\\WorldMap\\AzsharaCrater\\AzsharaCrater8",
        "Interface\\WorldMap\\AzsharaCrater\\AzsharaCrater9",
        "Interface\\WorldMap\\AzsharaCrater\\AzsharaCrater10",
        "Interface\\WorldMap\\AzsharaCrater\\AzsharaCrater11",
        "Interface\\WorldMap\\AzsharaCrater\\AzsharaCrater12",
    },
    hyjal = {
        "Interface\\WorldMap\\Hyjal\\Hyjal1",
        "Interface\\WorldMap\\Hyjal\\Hyjal2",
        "Interface\\WorldMap\\Hyjal\\Hyjal3",
        "Interface\\WorldMap\\Hyjal\\Hyjal4",
        "Interface\\WorldMap\\Hyjal\\Hyjal5",
        "Interface\\WorldMap\\Hyjal\\Hyjal6",
        "Interface\\WorldMap\\Hyjal\\Hyjal7",
        "Interface\\WorldMap\\Hyjal\\Hyjal8",
        "Interface\\WorldMap\\Hyjal\\Hyjal9",
        "Interface\\WorldMap\\Hyjal\\Hyjal10",
        "Interface\\WorldMap\\Hyjal\\Hyjal11",
        "Interface\\WorldMap\\Hyjal\\Hyjal12",
    }
}

----------------------------------------------
-- POI (Points of Interest) Data
----------------------------------------------
-- RESTORED: POIs now use normalized coordinates (0-1) that match GPS system
-- These will be converted to pixel positions on the map display
local poi_data = {
    azshara = {
        -- INSTRUCTIONS: Visit each location, type /dcmap poi, and paste the output here
        -- The coordinates below are PLACEHOLDERS and WRONG - they need GPS calibration!
        -- 
        -- {name = "Startcamp", x = 0.754, y = 0.493},  -- PLACEHOLDER - needs GPS coords
        -- {name = "Flight Master", x = 0.718, y = 0.533},  -- PLACEHOLDER
        -- {name = "Innkeeper", x = 0.734, y = 0.481},  -- PLACEHOLDER
        -- {name = "Auctionhouse", x = 0.745, y = 0.474},  -- PLACEHOLDER
        -- {name = "Stable Master", x = 0.730, y = 0.486},  -- PLACEHOLDER
        -- {name = "Transmog", x = 0.766, y = 0.500},  -- PLACEHOLDER
        -- {name = "Riding Trainer", x = 0.747, y = 0.523},  -- PLACEHOLDER
        -- {name = "Profession Trainers", x = 0.696, y = 0.414},  -- PLACEHOLDER
        -- {name = "Weapon Trainer", x = 0.734, y = 0.498},  -- PLACEHOLDER
        -- {name = "Violet Temple", x = 0.284, y = 0.604},  -- PLACEHOLDER
        -- {name = "Dragon Statues", x = 0.616, y = 0.520}  -- PLACEHOLDER
    },
    hyjal = {
        -- INSTRUCTIONS: Visit each location, type /dcmap poi, and paste the output here
        -- {name = "Nordrassil", x = 0.50, y = 0.50},  -- PLACEHOLDER
        -- {name = "Shrine of Aviana", x = 0.35, y = 0.30},  -- PLACEHOLDER
        -- {name = "Sanctuary of Malorne", x = 0.65, y = 0.40},  -- PLACEHOLDER
        -- {name = "Gates of Sothann", x = 0.50, y = 0.70},  -- PLACEHOLDER
        -- {name = "Tortolla's Retreat", x = 0.25, y = 0.55}  -- PLACEHOLDER
    }
}

----------------------------------------------
-- Helper: Delayed function call (3.3.5 compatible replacement for C_Timer.After)
----------------------------------------------
local delayedCalls = {}
local delayFrame = CreateFrame("Frame")
delayFrame:SetScript("OnUpdate", function(self, elapsed)
    local now = GetTime()
    for i = #delayedCalls, 1, -1 do
        local call = delayedCalls[i]
        if now >= call.time then
            call.func()
            table.remove(delayedCalls, i)
        end
    end
end)

local function DelayedCall(delay, func)
    table.insert(delayedCalls, {
        time = GetTime() + delay,
        func = func
    })
end

----------------------------------------------
-- Debug Helper
----------------------------------------------
local function Debug(...)
    if not DCMapExtensionDB.debug then return end
    local msg = strjoin(" ", "[DC-MapExt]", tostringall(...))
    DEFAULT_CHAT_FRAME:AddMessage(msg, 0.2, 1, 0.2)
end

----------------------------------------------
-- World Coordinate Conversion
----------------------------------------------
-- Map bounds based on actual zone data (.gps corner measurements)
-- These convert world X,Y coordinates to normalized 0-1 map coordinates
-- NOTE: Server GPS provides normalized coords, these are fallback only
local mapBounds = {
    [37] = {  -- Azshara Crater (Map ID 37, Zone ID 268)
        -- Bounds sourced from WorldMapArea.csv (entry 613)
        minX = -1884.0,
        maxX = 2427.0,
        minY = -1116.0,
        maxY = 1756.0
    },
    [616] = {  -- Mount Hyjal custom zone (Zone ID 616)
        -- Bounds sourced from WorldMapArea.csv (entry 614)
        minX = -5175.0,
        maxX = -929.1666,
        minY = 3364.583,
        maxY = 6195.833
    },
    [1] = {  -- Kalimdor fallback (used when Hyjal data missing)
        minX = -5000,
        maxX = 5000,
        minY = -5000,
        maxY = 5000
    }
}

local function GetActiveMapCanvas()
    if addon.nativeMapActive then
        return WorldMapButton
    end
    return addon.stitchFrame
end

local function WorldToNormalized(mapId, worldX, worldY)
    local bounds = mapBounds[mapId]
    if not bounds then return nil, nil end
    
    local nx, ny
    
    -- Map 37 (Azshara Crater): X axis is flipped, Y axis is normal
    -- X=0,Y=0 appears at 60.2%, 50.0% (verified in-game)
    if mapId == 37 then
        nx = (bounds.maxX - worldX) / (bounds.maxX - bounds.minX)  -- Flip X
        ny = (worldY - bounds.minY) / (bounds.maxY - bounds.minY)  -- Normal Y
    else
        -- Normal calculation for other maps
        nx = (worldX - bounds.minX) / (bounds.maxX - bounds.minX)
        ny = (worldY - bounds.minY) / (bounds.maxY - bounds.minY)
    end
    
    -- Clamp to 0-1 range
    nx = math.max(0, math.min(1, nx))
    ny = math.max(0, math.min(1, ny))
    
    return nx, ny
end

----------------------------------------------
-- Map Detection
----------------------------------------------
local function GetCurrentMapInfo()
    local mapID = GetCurrentMapAreaID and GetCurrentMapAreaID() or 0
    local continent = GetCurrentMapContinent and GetCurrentMapContinent() or 0
    local zoneName = GetZoneText and GetZoneText() or ""
    local subZone = GetSubZoneText and GetSubZoneText() or ""
    
    return mapID, continent, zoneName, subZone
end

local function GetPlayerZoneInfo()
    -- Get player's actual zone (not what's shown on map)
    local playerZoneName = GetRealZoneText and GetRealZoneText() or GetZoneText and GetZoneText() or ""
    local playerSubZone = GetSubZoneText and GetSubZoneText() or ""
    
    return playerZoneName, playerSubZone
end

local function IsPlayerInAzsharaCrater()
    -- First check GPS data (most reliable - from server)
    if addon.gpsData and addon.gpsData.mapId and addon.gpsData.zoneId then
        if addon.gpsData.mapId == 37 or addon.gpsData.zoneId == 268 then
            return true
        end
    end
    
    -- Fallback: Check zone name if GPS not available
    local zoneName, subZone = GetPlayerZoneInfo()
    local zoneCheck = zoneName:lower()
    local subCheck = subZone:lower()
    
    -- Debug zone names
    if DCMapExtensionDB.debug then
        local now = GetTime()
        if not addon.lastZoneDebug or (now - addon.lastZoneDebug) > 10 then
            addon.lastZoneDebug = now
            Debug("Zone detection: zoneName='" .. tostring(zoneName) .. "' subZone='" .. tostring(subZone) .. "'")
        end
    end
    
    if zoneCheck:find("azshara") or zoneCheck:find("crater") or
       subCheck:find("azshara") or subCheck:find("crater") then
        return true
    end
    
    return false
end

local function IsPlayerInHyjal()
    -- First check GPS data (most reliable - from server)
    if addon.gpsData and addon.gpsData.mapId and addon.gpsData.zoneId then
        if addon.gpsData.zoneId == 616 then
            return true
        end
    end
    
    -- Fallback: Check zone name if GPS not available
    local zoneName, subZone = GetPlayerZoneInfo()
    local zoneCheck = zoneName:lower()
    local subCheck = subZone:lower()
    
    if zoneCheck:find("hyjal") or subCheck:find("hyjal") then
        return true
    end
    
    return false
end

local function GetCustomMapType()
    -- Check for forced map first (from Mapster or manual selection)
    if addon.forcedMap then
        return addon.forcedMap
    end
    
    -- Otherwise, only show custom maps if player is PHYSICALLY in the zone
    local mapType = nil
    
    if IsPlayerInAzsharaCrater() then
        mapType = "azshara"
    elseif IsPlayerInHyjal() then
        mapType = "hyjal"
    end
    
    return mapType
end

local function TryUseNativeMap(mapType)
    local areaId = NATIVE_MAP_AREA_IDS[mapType]
    if not areaId or not SetMapByID then
        return false
    end

    local ok = pcall(SetMapByID, areaId)
    if not ok then
        Debug("SetMapByID failed for native map", mapType, areaId)
        return false
    end

    if WorldMapFrame_Update then
        WorldMapFrame_Update()
    end

    local tile = _G["WorldMapDetailTile1"]
    if tile then
        local tex = tile:GetTexture()
        if tex and tex ~= "" then
            local expected = (mapType == "azshara") and "azsharacrater" or "hyjal"
            if tex:lower():find(expected) then
                addon.nativeMapActive = true
                addon.nativeMapAreaId = areaId
                Debug("Using native map tiles for", mapType)
                return true
            end
        end
    end

    addon.nativeMapActive = false
    return false
end

----------------------------------------------
-- Frame Management
----------------------------------------------
local function CreateStitchFrame()
    if addon.stitchFrame then
        return addon.stitchFrame
    end
    
    -- Parent to WorldMapDetailFrame for proper integration
    local parent = WorldMapDetailFrame or UIParent
    local frame = CreateFrame("Frame", "DCMap_StitchFrame", parent)
    frame:SetAllPoints(parent)
    frame:SetFrameLevel((parent:GetFrameLevel() or 0) + 1)
    frame:EnableMouse(false)  -- Allow mouse clicks to pass through to WorldMapDetailFrame
    frame:EnableMouseWheel(false)
    frame:Hide()
    
    frame.tiles = {}
    
    addon.stitchFrame = frame
    Debug("Stitch frame created")
    return frame
end

-- Ensure a solid backdrop sits between Blizzard's world textures and our custom tiles
local function EnsureBackgroundMask()
    if not WorldMapDetailFrame then
        return
    end

    if not addon.backgroundMask then
        local mask = CreateFrame("Frame", "DCMap_BackgroundMask", WorldMapDetailFrame)
        mask:SetFrameLevel(WorldMapDetailFrame:GetFrameLevel() + 1) -- Ensure it's above the parent's base level
        mask:SetAllPoints(WorldMapDetailFrame)
        
        -- Create a texture for the mask
        local tex = mask:CreateTexture(nil, "BACKGROUND")
        tex:SetAllPoints(mask)
        tex:SetColorTexture(0.05, 0.04, 0.03, 1) -- Dark charcoal color
        mask.texture = tex

        addon.backgroundMask = mask
        Debug("Created background mask")
    end

    if addon.backgroundMask then
        addon.backgroundMask:SetDrawLayer("BACKGROUND", 7)
        addon.backgroundMask:Show()
    end
end

local function CreatePlayerDot()
    if addon.playerDot then
        return addon.playerDot
    end
    
    -- Parent to WorldMapButton (standard for all map icons in WoW)
    if not WorldMapButton then 
        Debug("Cannot create player dot - WorldMapButton doesn't exist")
        return nil 
    end
    
    local dot = CreateFrame("Frame", "DCMap_PlayerDot", WorldMapButton)
    dot:SetWidth(24)
    dot:SetHeight(24)
    dot:SetFrameStrata("TOOLTIP")
    dot:SetFrameLevel(WorldMapButton:GetFrameLevel() + 10)
    
    -- Create the player arrow texture
    local tex = dot:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints()
    tex:SetTexture("Interface\\Minimap\\POIIcons")
    tex:SetTexCoord(0.5, 0.625, 0.5, 0.625)  -- Player icon coordinates
    tex:SetVertexColor(1.0, 1.0, 1.0, 1.0)
    dot.texture = tex
    
    dot:Hide()
    
    addon.playerDot = dot
    Debug("Player dot created on WorldMapButton")
    return dot
end

----------------------------------------------
-- Coordinate Display System (Adapted from Mapster Coords)
----------------------------------------------
local function CreateCoordinateDisplay()
    if addon.coordFrame then
        return addon.coordFrame
    end
    
    -- Create main coordinate frame parented to WorldMapFrame (not DetailFrame which we hide)
    local frame = CreateFrame("Frame", "DCMap_CoordsFrame", WorldMapFrame)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetFrameLevel(100)
    frame:SetAllPoints(WorldMapFrame)
    
    -- Player coordinates text (top-left for better visibility)
    local playerText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    playerText:SetPoint("TOPLEFT", WorldMapFrame, "TOPLEFT", 15, -75)
    playerText:SetTextColor(1, 0.82, 0)  -- Gold color
    playerText:SetJustifyH("LEFT")
    playerText:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    frame.playerText = playerText
    
    -- Cursor coordinates text  
    local cursorText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cursorText:SetPoint("TOPLEFT", playerText, "BOTTOMLEFT", 0, -2)
    cursorText:SetTextColor(0.5, 1, 0.5)  -- Light green
    cursorText:SetJustifyH("LEFT")
    cursorText:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    frame.cursorText = cursorText
    
    -- Update function
    frame.lastUpdate = 0
    frame:SetScript("OnUpdate", function(self, elapsed)
        self.lastUpdate = self.lastUpdate + elapsed
        if self.lastUpdate < 0.1 then return end  -- Update 10 times per second
        self.lastUpdate = 0
        
        -- Only show if custom map is active
        if not addon.currentMap then
            playerText:SetText("")
            cursorText:SetText("")
            return
        end
        
        -- Update player coordinates
        local px, py = GetPlayerMapPosition("player")
        
        -- Try to use server GPS data if available and recent (within last 3 seconds)
        local now = GetTime()
        local gpsAge = now - addon.gpsData.lastUpdate
        local hasValidGPS = (gpsAge < 3) and (addon.gpsData.nx > 0 or addon.gpsData.ny > 0)
        
        -- Debug: Log what we're getting
        if DCMapExtensionDB.debug then
            local debugMsg = string.format("GPS: age=%.1fs nx=%.3f ny=%.3f | ClientPos: px=%s py=%s", 
                gpsAge, addon.gpsData.nx or 0, addon.gpsData.ny or 0, tostring(px), tostring(py))
            if not addon.lastCoordDebug or (now - addon.lastCoordDebug) > 5 then
                addon.lastCoordDebug = now
                Debug(debugMsg)
            end
        end
        
        if hasValidGPS then
            -- Use server-provided GPS coordinates (accurate for custom zones)
            local mapType = addon.currentMap or ResolveMapType(addon.gpsData.mapId, addon.gpsData.zoneId)
            local dispX, dispY = NormalizeMapCoords(mapType, addon.gpsData.nx, addon.gpsData.ny)

            if (not dispX or not dispY) and addon.gpsData.x and addon.gpsData.y then
                dispX, dispY = ConvertWorldToMapCoords(addon.gpsData.x, addon.gpsData.y, mapType)
            end

            if dispX and dispY then
                playerText:SetText(string.format("Player: %.1f, %.1f", dispX * 100, dispY * 100))
            else
                playerText:SetText("Player: --.--, --.--")
            end
        elseif px and py and (px > 0 or py > 0) then
            -- Use client-side coordinates (works for standard zones)
            playerText:SetText(string.format("Player: %.1f, %.1f", px * 100, py * 100))
        elseif addon.playerDot and addon.playerDot:IsShown() then
            -- Fallback: Calculate from player dot position on stitched map
            local parent = GetActiveMapCanvas() or WorldMapDetailFrame
            if parent then
                local dotX = addon.playerDot:GetLeft()
                local dotY = addon.playerDot:GetTop()
                local parentLeft = parent:GetLeft()
                local parentTop = parent:GetTop()
                local parentWidth = parent:GetWidth()
                local parentHeight = parent:GetHeight()
                
                if dotX and dotY and parentLeft and parentTop and parentWidth and parentHeight and parentWidth > 0 and parentHeight > 0 then
                    local relX = (dotX - parentLeft) / parentWidth
                    local relY = (parentTop - dotY) / parentHeight
                    if relX >= 0 and relX <= 1 and relY >= 0 and relY <= 1 then
                        playerText:SetText(string.format("Player: %.1f, %.1f", relX * 100, relY * 100))
                    else
                        playerText:SetText("Player: Not in zone")
                    end
                else
                    playerText:SetText("Player: Not in zone")
                end
            else
                playerText:SetText("Player: Not in zone")
            end
        else
            -- No valid position data
            playerText:SetText("Player: Not in zone")
        end
        
        -- Update cursor coordinates relative to the stitched map frame
    local parent = GetActiveMapCanvas() or WorldMapDetailFrame
        if not parent or not parent:IsShown() then
            cursorText:SetText("Cursor: --.--, --.--")
            return
        end
        
        local cx, cy = GetCursorPosition()
        local scale = parent:GetEffectiveScale()
        local left = parent:GetLeft()
        local top = parent:GetTop()
        local width = parent:GetWidth()
        local height = parent:GetHeight()
        
        if left and top and width and height and scale and scale > 0 then
            cx = (cx / scale - left) / width
            cy = (top - cy / scale) / height
            
            if cx >= 0 and cx <= 1 and cy >= 0 and cy <= 1 then
                cursorText:SetText(string.format("Cursor: %.1f, %.1f", cx * 100, cy * 100))
            else
                cursorText:SetText("Cursor: Out of bounds")
            end
        else
            cursorText:SetText("Cursor: --.--, --.--")
        end
    end)
    
    frame:Show()
    addon.coordFrame = frame
    Debug("Coordinate display created")
    return frame
end

----------------------------------------------
-- POI (Points of Interest) Management
----------------------------------------------
local function GetHotspotData()
    -- Access DCHotspotXP addon's activeHotspots table if available
    if _G.activeHotspots then
        return _G.activeHotspots
    end
    
    -- Fallback: check minimap pins if DCHotspotXP is loaded
    if _G.hotspotMinimapPins then
        local discoveredHotspots = {}
        for id, pin in pairs(_G.hotspotMinimapPins) do
            if pin and pin.hotspotData then
                discoveredHotspots[id] = pin.hotspotData
            end
        end
        return discoveredHotspots
    end
    
    return {}
end

local function ConvertWorldToMapCoords(worldX, worldY, mapType)
    local mapInfo = MAP_TYPES[mapType]
    local mapId = mapInfo and mapInfo.mapId or addon.gpsData.mapId

    if not mapId then
        return 0.5, 0.5
    end

    local nx, ny = WorldToNormalized(mapId, worldX, worldY)
    if not nx or not ny then
        return 0.5, 0.5
    end

    return NormalizeMapCoords(mapType, nx, ny)
end

local function CreateHotspotMarkers(mapType)
    local parent = GetActiveMapCanvas()
    if not parent then return end

    -- Clear existing hotspot markers
    if addon.hotspotMarkers then
        for _, marker in ipairs(addon.hotspotMarkers) do
            marker:Hide()
            marker:SetParent(nil)
        end
    end
    addon.hotspotMarkers = {}
    
    local hotspots = GetHotspotData()
    local hotspotCount = 0
    
    -- Check if we have any hotspots
    for _ in pairs(hotspots) do
        hotspotCount = hotspotCount + 1
    end
    
    if hotspotCount == 0 then
        -- Don't spam debug messages
        return
    end
    
    local frameWidth = parent:GetWidth()
    local frameHeight = parent:GetHeight()
    
    if not frameWidth or not frameHeight or frameWidth == 0 or frameHeight == 0 then
        Debug("Invalid frame dimensions for hotspots")
        return
    end
    
    local markerCount = 0
    for id, hotspot in pairs(hotspots) do
        -- Check if hotspot is in the current zone
        -- Map 38 is Azshara Crater (corrected from 37)
        local hotspotMap = hotspot.map or 0
        
        -- Only show hotspots that match the current custom map
        local showHotspot = false
        if mapType == "azshara" and hotspotMap == 38 then
            showHotspot = true
        elseif mapType == "hyjal" and (hotspotMap == 534 or hotspotMap == 616) then
            showHotspot = true
        end
        
        if showHotspot and (hotspot.x or hotspot.nx) and (hotspot.y or hotspot.ny) then
            local mapX, mapY
            if hotspot.nx and hotspot.ny then
                mapX, mapY = NormalizeMapCoords(mapType, hotspot.nx, hotspot.ny)
            else
                mapX, mapY = ConvertWorldToMapCoords(hotspot.x, hotspot.y, mapType)
            end

            mapX = Clamp01(mapX)
            mapY = Clamp01(mapY)

            if mapX and mapY then
                -- Create hotspot marker frame
                local marker = CreateFrame("Frame", "DCMap_Hotspot_" .. id, parent)
                marker:SetWidth(24)
                marker:SetHeight(24)
                local baseLevel = parent.GetFrameLevel and parent:GetFrameLevel() or 0
                marker:SetFrameLevel(baseLevel + 6)
                
                -- Hotspot icon texture - use a glowing effect
                local tex = marker:CreateTexture(nil, "OVERLAY")
                tex:SetAllPoints()
                tex:SetTexture("Interface\\AddOns\\DC-HotspotXP\\textures\\hotspot_icon")  -- Try custom icon
                if not tex:GetTexture() or tex:GetTexture() == "" then
                    -- Fallback to standard icons
                    tex:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
                    tex:SetVertexColor(1, 0.84, 0)  -- Gold color
                end
                marker.texture = tex
                
                -- Add pulsing animation
                local animGroup = marker:CreateAnimationGroup()
                local scale1 = animGroup:CreateAnimation("Scale")
                scale1:SetScale(1.2, 1.2)
                scale1:SetDuration(0.8)
                scale1:SetOrder(1)
                
                local scale2 = animGroup:CreateAnimation("Scale")
                scale2:SetScale(0.833, 0.833)  -- Back to 1.0 (1/1.2)
                scale2:SetDuration(0.8)
                scale2:SetOrder(2)
                
                animGroup:SetLooping("REPEAT")
                animGroup:Play()
                marker.animation = animGroup
                
                -- Position the hotspot
                local pixelX = mapX * frameWidth
                local pixelY = -mapY * frameHeight
                marker:ClearAllPoints()
                marker:SetPoint("CENTER", parent, "TOPLEFT", pixelX, pixelY)
                
                -- Calculate time remaining
                local timeLeft = 0
                if hotspot.expire and type(hotspot.expire) == "number" then
                    timeLeft = hotspot.expire - GetTime()
                    if timeLeft < 0 then timeLeft = 0 end
                end
                
                -- Tooltip on mouseover
                marker:EnableMouse(true)
                marker:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:AddLine("XP Hotspot", 1, 0.84, 0)
                    if hotspot.zone then
                        GameTooltip:AddLine("Zone: " .. hotspot.zone, 1, 1, 1)
                    end
                    GameTooltip:AddLine(string.format("Position: %.1f, %.1f", hotspot.x or 0, hotspot.y or 0), 0.7, 0.7, 0.7)
                    if timeLeft > 0 then
                        local minutes = math.floor(timeLeft / 60)
                        local seconds = math.floor(timeLeft % 60)
                        GameTooltip:AddLine(string.format("Time left: %d:%02d", minutes, seconds), 0.5, 1, 0.5)
                    end
                    GameTooltip:Show()
                end)
                marker:SetScript("OnLeave", function(self)
                    GameTooltip:Hide()
                end)
                
                marker:Show()
                table.insert(addon.hotspotMarkers, marker)
                markerCount = markerCount + 1
                Debug("Created hotspot marker:", id, "at", mapX, mapY, "time left:", math.floor(timeLeft))
            end
        end
    end
    
    Debug("Created", markerCount, "hotspot markers for", mapType)
end

local function CreatePOIMarkers(mapType)
    local parent = GetActiveMapCanvas()
    if not parent then return end

    -- Clear existing POI markers
    if addon.poiMarkers then
        for _, marker in ipairs(addon.poiMarkers) do
            marker:Hide()
            marker:SetParent(nil)
        end
    end
    addon.poiMarkers = {}
    
    local pois = poi_data[mapType]
    if not pois or #pois == 0 then
        Debug("No POIs defined for", mapType)
        return
    end
    
    local frameWidth = parent:GetWidth()
    local frameHeight = parent:GetHeight()
    
    if not frameWidth or not frameHeight or frameWidth == 0 or frameHeight == 0 then
        Debug("Invalid frame dimensions for POIs")
        return
    end
    
    for i, poi in ipairs(pois) do
        local nx = Clamp01(poi.x)
        local ny = Clamp01(poi.y)
        if not nx or not ny then
            Debug("Skipping POI with invalid coordinates", tostring(poi.name))
            nx, ny = 0.5, 0.5
        end

        -- Create POI marker frame
        local marker = CreateFrame("Frame", "DCMap_POI_" .. i, parent)
        marker:SetWidth(16)
        marker:SetHeight(16)
        marker:SetFrameStrata("TOOLTIP")
        local baseLevel = parent.GetFrameLevel and parent:GetFrameLevel() or 0
        marker:SetFrameLevel(baseLevel + 5)
        
        -- POI icon texture
        local tex = marker:CreateTexture(nil, "OVERLAY")
        tex:SetAllPoints()
        tex:SetTexture("Interface\\Minimap\\POIIcons")
        tex:SetTexCoord(0.5, 0.625, 0, 0.125)  -- Gold star icon
        marker.texture = tex
        
        -- Position the POI
        local pixelX = nx * frameWidth
        local pixelY = -ny * frameHeight
        marker:ClearAllPoints()
        marker:SetPoint("CENTER", parent, "TOPLEFT", pixelX, pixelY)
        
        -- Tooltip on mouseover
        marker:EnableMouse(true)
        marker:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(poi.name, 1, 1, 1)
            GameTooltip:Show()
        end)
        marker:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
        
        marker:Show()
        table.insert(addon.poiMarkers, marker)
        Debug("Created POI marker:", poi.name, "at", pixelX, pixelY)
    end

    Debug("Created", #addon.poiMarkers, "POI markers for", mapType)
end----------------------------------------------
-- Texture Loading
----------------------------------------------
local function ClearTiles()
    -- Restore WorldMapDetailFrame
    if WorldMapDetailFrame then
        WorldMapDetailFrame:SetAlpha(1)
        Debug("Restored WorldMapDetailFrame alpha to 1")
    end

    if addon.backgroundMask then
        addon.backgroundMask:Hide()
    end
    
    -- Clear POI markers
    if addon.poiMarkers then
        for _, marker in ipairs(addon.poiMarkers) do
            marker:Hide()
            marker:SetParent(nil)
        end
        addon.poiMarkers = {}
        Debug("Cleared POI markers")
    end
    
    -- Clear hotspot markers
    if addon.hotspotMarkers then
        for _, marker in ipairs(addon.hotspotMarkers) do
            if marker.animation then
                marker.animation:Stop()
            end
            marker:Hide()
            marker:SetParent(nil)
        end
        addon.hotspotMarkers = {}
        Debug("Cleared hotspot markers")
    end
    
    -- Restore Blizzard's native detail tiles
    for i = 1, NUM_WORLDMAP_DETAIL_TILES or 0 do
        local tile = _G["WorldMapDetailTile" .. i]
        if tile then
            tile:Show()
            tile:SetAlpha(1)  -- Restore alpha
            -- Reset to default texture (will be set by Blizzard)
            if addon.originalTextures and addon.originalTextures[i] then
                tile:SetTexture(addon.originalTextures[i])
            end
        end
    end
    
    local frame = addon.stitchFrame
    if frame and frame.tiles then
        for _, tile in ipairs(frame.tiles) do
            if tile then
                tile:Hide()
                tile:SetTexture(nil)
            end
        end
        frame.tiles = {}
    end
    Debug("Tiles cleared and native map restored")
end

local function LoadTiles(mapType)
    local paths = texturePaths[mapType]
    if not paths then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[DC-MapExt] ERROR: No texture paths for map type: " .. tostring(mapType) .. "|r")
        return false
    end
    
    Debug("=== Loading tiles for", mapType, "===")
    Debug("NUM_WORLDMAP_DETAIL_TILES:", NUM_WORLDMAP_DETAIL_TILES or "UNDEFINED")
    
    -- Don't hide WorldMapDetailFrame - the tiles are its children!
    -- Instead, we'll just replace the tile textures
    if WorldMapDetailFrame then
        WorldMapDetailFrame:SetAlpha(1)  -- Keep it visible so our custom tiles show
        Debug("Set WorldMapDetailFrame alpha to 1 (visible)")
    end
    
    -- Hook the WorldMap texture update function to prevent Blizzard from overriding our textures
    if not addon.hookedTileUpdate then
        if WorldMapFrame_UpdateDetailTiles then
            local originalUpdateWorldMapDetailTiles = WorldMapFrame_UpdateDetailTiles
            WorldMapFrame_UpdateDetailTiles = function()
                -- If we're showing a custom map, don't let Blizzard reset the tiles
                if addon.currentMap then
                    Debug("Blocked Blizzard tile update while showing custom map:", addon.currentMap)
                    return
                end
                -- Otherwise, call original function
                if originalUpdateWorldMapDetailTiles then
                    originalUpdateWorldMapDetailTiles()
                end
            end
            addon.hookedTileUpdate = true
            Debug("Hooked WorldMapFrame_UpdateDetailTiles to prevent override")
        else
            Debug("WorldMapFrame_UpdateDetailTiles not found")
            addon.hookedTileUpdate = true
        end
        
        -- Also hook SetMapByID to prevent zone changes from resetting our tiles
        if SetMapByID then
            local originalSetMapByID = SetMapByID
            SetMapByID = function(mapID)
                if addon.currentMap then
                    Debug("Blocked SetMapByID(" .. tostring(mapID) .. ") while showing custom map:", addon.currentMap)
                    return
                end
                return originalSetMapByID(mapID)
            end
            Debug("Hooked SetMapByID to prevent override")
        end
        
        -- Hook SetMapZoom too
        if SetMapZoom then
            local originalSetMapZoom = SetMapZoom
            SetMapZoom = function(continent, zone)
                if addon.currentMap then
                    Debug("Blocked SetMapZoom while showing custom map:", addon.currentMap)
                    return
                end
                return originalSetMapZoom(continent, zone)
            end
            Debug("Hooked SetMapZoom to prevent override")
        end
    end
    
    -- Save and prepare to replace Blizzard's native detail tiles
    for i = 1, NUM_WORLDMAP_DETAIL_TILES or 0 do
        local tile = _G["WorldMapDetailTile" .. i]
        if tile then
            -- Store original texture if not already stored
            if not addon.originalTextures then
                addon.originalTextures = {}
            end
            if tile.GetTexture and not addon.originalTextures[i] then
                addon.originalTextures[i] = tile:GetTexture()
            end
            -- Don't hide the tile - we're going to replace its texture
        end
    end
    Debug("Saved", (addon.originalTextures and #addon.originalTextures or 0), "original tile textures")
    
    -- Use Blizzard's built-in detail tiles
    local successCount = 0
    local errorCount = 0
    
    -- CRITICAL: Clear WorldMapDetailFrame's own background texture
    if WorldMapDetailFrame and WorldMapDetailFrame.SetTexture then
        WorldMapDetailFrame:SetTexture(nil)
        Debug("Cleared WorldMapDetailFrame background texture")
    end
    
    -- Also clear any textures ON WorldMapDetailFrame itself
    if WorldMapDetailFrame then
        for i = 1, WorldMapDetailFrame:GetNumRegions() do
            local region = select(i, WorldMapDetailFrame:GetRegions())
            if region and region.GetObjectType and region:GetObjectType() == "Texture" then
                if region.SetTexture then
                    region:SetTexture(nil)
                    Debug("Cleared WorldMapDetailFrame region texture", i)
                end
            end
        end
    end
    
    -- First, hide ALL tiles to prevent mixing
    for i = 1, NUM_WORLDMAP_DETAIL_TILES or 16 do
        local tile = _G["WorldMapDetailTile" .. i]
        if tile then
            tile:Hide()
            tile:SetTexture(nil)  -- Clear any existing texture
        end
    end
    Debug("Hid all", NUM_WORLDMAP_DETAIL_TILES or 16, "tiles to prevent mixing")
    
    -- Now load ONLY our tiles
    for i = 1, math.min(#paths, NUM_WORLDMAP_DETAIL_TILES or 16) do
        local tile = _G["WorldMapDetailTile" .. i]
        local texturePath = paths[i]
        
        if not tile then
            Debug("ERROR: WorldMapDetailTile" .. i, "doesn't exist!")
            errorCount = errorCount + 1
        else
            -- WorldMapDetailTile objects are TEXTURES, not frames
            -- So we can call SetTexture directly on them
            local success, err = pcall(function()
                -- Set our BLP texture directly
                tile:SetTexture(texturePath)
                tile:SetTexCoord(0, 1, 0, 1)
                tile:SetAlpha(1)
                tile:SetVertexColor(1, 1, 1, 1)
                
                -- For textures, we use SetDrawLayer, not SetFrameLevel
                -- OVERLAY with high sublevel to be on top
                tile:SetDrawLayer("OVERLAY", 7)
                
                -- Show the texture
                tile:Show()
                
                -- Store that this tile is ours (custom property)
                tile._DCMapCustom = true
                tile._DCMapType = mapType
            end)
            
            if success then
                -- Verify the texture actually loaded
                local actualTexture = tile:GetTexture()
                
                if actualTexture and actualTexture ~= "" then
                    -- Check if it matches what we expect
                    local expectedName = texturePath:match("[^\\]+$")
                    if actualTexture:lower():find(expectedName:lower()) then
                        successCount = successCount + 1
                        Debug("SUCCESS Tile", i, "->", expectedName, "| Verified")
                    else
                        -- Wrong texture loaded
                        tile:Hide()
                        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00[DC-MapExt] WARNING: Tile " .. i .. " texture mismatch|r")
                        DEFAULT_CHAT_FRAME:AddMessage("  Expected: " .. texturePath)
                        DEFAULT_CHAT_FRAME:AddMessage("  Got: " .. tostring(actualTexture))
                        errorCount = errorCount + 1
                    end
                else
                    -- Texture is NONE/empty - file doesn't exist or can't be loaded
                    tile:Hide()
                    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[DC-MapExt] ERROR: Tile " .. i .. " has NO TEXTURE after SetTexture!|r")
                    DEFAULT_CHAT_FRAME:AddMessage("  Attempted path: " .. texturePath)
                    DEFAULT_CHAT_FRAME:AddMessage("  Make sure .blp files exist in WoW client folder")
                    errorCount = errorCount + 1
                end
            else
                -- Error setting texture
                tile:Hide()
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[DC-MapExt] ERROR: Tile " .. i .. " SetTexture failed: " .. tostring(err) .. "|r")
                errorCount = errorCount + 1
            end
        end
    end
    
    Debug("=== Load complete: Success=" .. successCount .. " Errors=" .. errorCount .. " ===")
    
    -- Store which map type we loaded for watchdog
    addon.loadedMapType = mapType
    addon.loadedTextures = paths
    
    if successCount == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[DC-MapExt] ERROR: No tiles loaded! Check if files exist in Interface\\WorldMap\\" .. (mapType == "azshara" and "AzsharaCrater" or "Hyjal") .. "\\|r")
        return false
    elseif errorCount > 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffff00[DC-MapExt] Loaded " .. successCount .. "/" .. #paths .. " tiles for " .. mapType .. "|r")
        return true
    else
        if DCMapExtensionDB.debug then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC-MapExt] Successfully loaded " .. successCount .. " tiles for " .. mapType .. "|r")
        end
        return true
    end
end

----------------------------------------------
-- Core Hooks
----------------------------------------------
-- Hook the main map update function to ensure we are on the right continent
-- before it tries to render the world overview.
local original_WorldMapFrame_Update = WorldMapFrame_Update
function WorldMapFrame_Update(...)
    local customMapType = GetCustomMapType()
    if customMapType then
        local currentMapId = GetCurrentMapAreaID()
        -- If we are in a custom zone but the map is trying to show the world overview (ID 0),
        -- force it to Kalimdor (ID 1) first.
        if currentMapId == 0 then
            SetMapByID(1)
        end
    end
    
    -- Call the original function
    return original_WorldMapFrame_Update(...)
end


----------------------------------------------
-- Tile Watchdog - Prevents Blizzard from overriding our tiles
----------------------------------------------
local function CheckAndFixTiles()
    if not addon.currentMap or not addon.loadedTextures then return end
    
    -- Check if any of our custom tiles have been overridden
    local needsReload = false
    for i = 1, math.min(#addon.loadedTextures, NUM_WORLDMAP_DETAIL_TILES or 12) do
        local tile = _G["WorldMapDetailTile" .. i]
        if tile then
            local currentTexture = tile:GetTexture()
            local expectedTexture = addon.loadedTextures[i]
            
            -- Check if texture was changed
            if currentTexture and expectedTexture and not currentTexture:find(expectedTexture:match("[^\\]+$")) then
                needsReload = true
                Debug("Detected tile override - tile " .. i .. " changed from", expectedTexture, "to", currentTexture)
                break
            end
        end
    end
    
    if needsReload then
        Debug("Detected tile override - reapplying custom tiles for", addon.currentMap)
        LoadTiles(addon.currentMap)
    end
end

----------------------------------------------
-- Player Position
----------------------------------------------
local function UpdatePlayerPosition()
    if not DCMapExtensionDB.showPlayerDot then return end
    if not addon.playerDot then
        return
    end

    local canvas = GetActiveMapCanvas()
    if not canvas or not canvas:IsShown() then
        addon.playerDot:Hide()
        return
    end

    local nx, ny = GetPlayerMapPosition("player")

    if addon.nativeMapActive then
        if not nx or not ny then
            addon.playerDot:Hide()
            return
        end
    else
        -- Fallback normalization when we render stitched tiles on Kalimdor
        local mapInfo = MAP_TYPES[addon.currentMap or "azshara"]
        local mapId = mapInfo and mapInfo.mapId or AZSHARA_CRATER_MAP_ID

        if mapId == HYJAL_MAP_ID then
            local kalimdorX, kalimdorY = GetPlayerMapPosition("player")
            local hyjalLeft = 0.35
            local hyjalRight = 0.6
            local hyjalTop = 0.05
            local hyjalBottom = 0.25
            nx = (kalimdorX - hyjalLeft) / (hyjalRight - hyjalLeft)
            ny = (kalimdorY - hyjalTop) / (hyjalBottom - hyjalTop)
        elseif mapId == AZSHARA_CRATER_MAP_ID then
            local kalimdorX, kalimdorY = GetPlayerMapPosition("player")
            local acLeft = 0.55
            local acRight = 0.85
            local acTop = 0.25
            local acBottom = 0.45
            nx = (kalimdorX - acLeft) / (acRight - acLeft)
            ny = (kalimdorY - acTop) / (acBottom - acTop)
        end
    end

    if nx and ny and nx >= 0 and nx <= 1 and ny >= 0 and ny <= 1 then
        addon.playerDot:ClearAllPoints()
        addon.playerDot:SetPoint("CENTER", canvas, "TOPLEFT", nx * canvas:GetWidth(), -ny * canvas:GetHeight())
        addon.playerDot:Show()
    else
        addon.playerDot:Hide()
    end
end

----------------------------------------------
-- Coordinate Display
----------------------------------------------
-- No changes in this section
----------------------------------------------
-- POI (Points of Interest) Management
----------------------------------------------
-- No changes in this section
----------------------------------------------
-- Texture Loading
----------------------------------------------
-- No changes in this section
----------------------------------------------
-- Tile Watchdog - Prevents Blizzard from overriding our tiles
----------------------------------------------
-- No changes in this section
----------------------------------------------
-- Player Position
----------------------------------------------
-- No changes in this section
----------------------------------------------
-- Map Update
----------------------------------------------
local function HideNativeDetailTiles()
    -- DON'T clear tiles - LoadTiles() handles replacing them!
    -- Just ensure the detail frame is ready
    if WorldMapDetailFrame then
        WorldMapDetailFrame:SetAlpha(1)
        Debug("WorldMapDetailFrame ready to be replaced by custom tiles")
    end
    
    Debug("Native detail tiles ready to be replaced by custom tiles")
end

local function ShowNativeDetailTiles()
    -- Restore Blizzard's default map tiles by reloading them
    if WorldMapFrame_UpdateDetailTiles then
        WorldMapFrame_UpdateDetailTiles()
        Debug("Restored native tiles via WorldMapFrame_UpdateDetailTiles")
    end
    
    -- Ensure WorldMapDetailFrame is visible
    if WorldMapDetailFrame then
        WorldMapDetailFrame:SetAlpha(1)
        Debug("WorldMapDetailFrame set to visible (alpha=1)")
    end
end

-- Hide Blizzard's POI system when showing custom maps
local function HideBlizzardPOIs()
    -- Hide world map POIs that Blizzard adds
    if WorldMapFrame then
        -- CRITICAL: Hide ALL background elements
        if WorldMapContinentsDropDown then
            WorldMapContinentsDropDown:Hide()
        end
        
        -- Hide the detail scrollframe that contains continent textures
        if WorldMapDetailScrollFrame then
            WorldMapDetailScrollFrame:SetAlpha(0)
            WorldMapDetailScrollFrame:Hide()
        end
        
        -- Hide the scroll child that contains zone textures
        if WorldMapDetailScrollChild then
            WorldMapDetailScrollChild:SetAlpha(0)
        end
        
        -- Hide the background texture frame
        if WorldMapButton then
            -- Keep button enabled for clicking, but hide background textures
            for i = 1, WorldMapButton:GetNumRegions() do
                local region = select(i, WorldMapButton:GetRegions())
                if region and region.GetObjectType and region:GetObjectType() == "Texture" then
                    local texture = region:GetTexture()
                    -- Only hide if it's NOT one of our custom textures
                    if texture and not texture:find("AzsharaCrater") and not texture:find("Hyjal") then
                        region:SetAlpha(0)
                    end
                end
            end
        end
        
        -- Hide the parchment/continent background textures so only our tiles remain
        if not addon.originalFrameTextures then
            addon.originalFrameTextures = {}
        end
        for i = 1, 12 do
            local tex = _G["WorldMapFrameTexture" .. i]
            if tex then
                if not addon.originalFrameTextures[i] then
                    addon.originalFrameTextures[i] = tex:GetTexture()
                end
                tex:SetTexture(nil)
                tex:Hide()
            end
        end

        -- Hide POI buttons (quest givers, etc)
        for i = 1, NUM_WORLDMAP_POIS or 0 do
            local poi = _G["WorldMapFramePOI" .. i]
            if poi then
                poi:Hide()
            end
        end
        
        -- Hide boss POIs
        for i = 1, NUM_WORLDMAP_OVERLAYS or 0 do
            local overlay = _G["WorldMapOverlay" .. i]
            if overlay then
                overlay:Hide()
            end
        end
        
        -- Hide party member icons
        if WorldMapPartyUnit1 then WorldMapPartyUnit1:Hide() end
        if WorldMapPartyUnit2 then WorldMapPartyUnit2:Hide() end
        if WorldMapPartyUnit3 then WorldMapPartyUnit3:Hide() end
        if WorldMapPartyUnit4 then WorldMapPartyUnit4:Hide() end
        
        -- Hide raid member icons  
        if WorldMapRaidUnit1 then WorldMapRaidUnit1:Hide() end
        
        -- Hide zone name highlights/tooltips
        if WorldMapHighlight then
            WorldMapHighlight:Hide()
        end
        
        -- Disable mouse interaction on WorldMapButton (prevents zone name tooltips)
        if WorldMapButton then
            WorldMapButton:EnableMouse(false)
        end
        
        -- Hide Mapster POIs if present
        if Mapster and Mapster.pins then
            for _, pin in pairs(Mapster.pins) do
                if pin and pin.Hide then
                    pin:Hide()
                end
            end
        end
        
        -- Hide Cartographer POIs if present
        if Cartographer_POI then
            local frame = _G["Cartographer_POI"]
            if frame and frame.Hide then
                frame:Hide()
            end
        end
        
        -- Hide generic POI frames that might exist
        local commonPOIFrames = {
            "WorldMapPOIFrame",
            "WorldMapTooltip",
            "WorldMapBlobFrame",
            "WorldMapArchaeologyDigSites",
        }
        
        for _, frameName in ipairs(commonPOIFrames) do
            local frame = _G[frameName]
            if frame and frame.Hide then
                frame:Hide()
            end
        end
        
        Debug("Hid Blizzard and addon POI frames + continent overlay")
    end
end

local function ShowBlizzardPOIs()
    -- Restore Blizzard's POI system
    if WorldMapFrame then
        -- Restore continent dropdown
        if WorldMapContinentsDropDown then
            WorldMapContinentsDropDown:Show()
        end
        
        -- Restore detail scrollframe
        if WorldMapDetailScrollFrame then
            WorldMapDetailScrollFrame:SetAlpha(1)
        end
        
        -- Re-enable mouse on WorldMapButton
        if WorldMapButton then
            WorldMapButton:EnableMouse(true)
        end

        -- Restore the parchment/continent textures
        if addon.originalFrameTextures then
            for i = 1, 12 do
                local tex = _G["WorldMapFrameTexture" .. i]
                if tex then
                    local original = addon.originalFrameTextures[i]
                    tex:SetTexture(original)
                    tex:SetAlpha(1)
                    tex:Show()
                end
            end
        end
        
        -- The POIs will automatically re-show on next map update
        -- Just make sure the frames are re-enabled
        for i = 1, NUM_WORLDMAP_POIS or 0 do
            local poi = _G["WorldMapFramePOI" .. i]
            if poi then
                poi:Show()
            end
        end
        
        Debug("Restored Blizzard POI frames + continent overlay")
    end
end

-- Store in addon table so global functions can access them
function addon:ShowCustomMap(mapType)
    Debug("ShowCustomMap called for:", mapType)
    
    if not mapType or (mapType ~= "azshara" and mapType ~= "hyjal") then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[DC-MapExt] Invalid map type: " .. tostring(mapType) .. "|r")
        return false
    end

    -- Set current map BEFORE creating frames so OnUpdate can reference it
    self.currentMap = mapType

    -- First try to leverage native client support (requires patched DBCs)
    if TryUseNativeMap(mapType) then
        self.loadedMapType = mapType
        self.loadedTextures = nil
        if self.stitchFrame then
            self.stitchFrame:Hide()
        end
        if addon.backgroundMask then
            addon.backgroundMask:Hide()
        end
        CreatePlayerDot()
        CreateCoordinateDisplay()
        CreatePOIMarkers(mapType)
        CreateHotspotMarkers(mapType)
        UpdatePlayerPosition()
        ShowBlizzardPOIs()
        return true
    end

    -- Native tiles not available yet – fall back to stitched textures
    addon.nativeMapActive = false

    if GetCurrentMapContinent() ~= 1 then
        SetMapToCurrentZone()
    end
    if GetCurrentMapAreaID() ~= 1 then
        Debug("Forcing map to Kalimdor (UiMapID 1) to display custom tiles.")
        SetMapByID(1)
    end

    CreateStitchFrame()
    CreatePlayerDot()
    CreateCoordinateDisplay()
    EnsureBackgroundMask()

    if self.loadedMapType == mapType and self.stitchFrame then
        Debug("Reusing already-loaded tiles for", mapType)
        self.stitchFrame:Show()
        if self.playerDot then self.playerDot:Show() end
        HideNativeDetailTiles()
        HideBlizzardPOIs()
        CreatePOIMarkers(mapType)
        CreateHotspotMarkers(mapType)
        return true
    end

    if LoadTiles(mapType) then
        Debug("Tiles loaded successfully for", mapType)
        self.stitchFrame:Show()
        CreatePOIMarkers(mapType)
        CreateHotspotMarkers(mapType)
        HideNativeDetailTiles()
        HideBlizzardPOIs()
        return true
    end

    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[DC-MapExt] Failed to load tiles for " .. tostring(mapType) .. "|r")
    self.currentMap = nil
    return false
end

function addon:HideCustomMap()
    Debug("HideCustomMap called")
    local wasNative = self.nativeMapActive
    self.nativeMapActive = false

    -- Hide custom frames if we were using stitched tiles
    if not wasNative and self.stitchFrame then
        self.stitchFrame:Hide()
    end
    if not wasNative and addon.backgroundMask then
        addon.backgroundMask:Hide()
    end
    if self.playerDot then
        self.playerDot:Hide()
    end
    if self.coordFrame then
        self.coordFrame:Hide()
        if self.coordFrame.playerText then
            self.coordFrame.playerText:SetText("")
        end
        if self.coordFrame.cursorText then
            self.coordFrame.cursorText:SetText("")
        end
    end
    
    -- Clear POI and hotspot markers
    if self.poiMarkers then
        for _, marker in ipairs(self.poiMarkers) do
            marker:Hide()
            marker:SetParent(nil)
        end
        self.poiMarkers = {}
    end
    
    if self.hotspotMarkers then
        for _, marker in ipairs(self.hotspotMarkers) do
            if marker.animation then
                marker.animation:Stop()
            end
            marker:Hide()
            marker:SetParent(nil)
        end
        self.hotspotMarkers = {}
    end
    
    if not wasNative then
        -- Restore Blizzard's native detail tiles
        ClearTiles()
        ShowNativeDetailTiles()
    end

    -- Restore Blizzard's POI system (safe to call for both modes)
    ShowBlizzardPOIs()
    
    -- Trigger Blizzard to reload the current map
    if WorldMapFrame and WorldMapFrame:IsShown() then
        -- Call Blizzard's update function to restore normal map tiles
        if WorldMapFrame_UpdateMap then
            WorldMapFrame_UpdateMap()
        end
    end
    
    -- Clear current map state
    self.currentMap = nil
    self.loadedMapType = nil
    
    Debug("Custom map hidden and Blizzard map restored")
end

local function UpdateMap()
    if not DCMapExtensionDB.enabled then
        addon:HideCustomMap()
        addon.currentMap = nil
        return
    end
    
    -- Don't do anything if WorldMapFrame isn't shown
    if not WorldMapFrame or not WorldMapFrame:IsShown() then
        return
    end
    
    local mapType = GetCustomMapType()  -- Uses GPS data or forced map
    local mapID = GetCurrentMapAreaID and GetCurrentMapAreaID() or 0
    local continent = GetCurrentMapContinent and GetCurrentMapContinent() or 0
    local zoneName = GetZoneText and GetZoneText() or "unknown"
    
    -- Debug current state
    if DCMapExtensionDB.debug and mapType then
        local gpsMap = addon.gpsData.mapId or 0
        local gpsZone = addon.gpsData.zoneId or 0
        Debug("UpdateMap: DisplayedMapID=" .. mapID .. " GPSMap=" .. gpsMap .. " GPSZone=" .. gpsZone .. 
              " Zone=" .. zoneName .. " Type=" .. tostring(mapType) .. " Forced=" .. tostring(addon.forcedMap ~= nil))
    end
    
    -- Throttle debug messages for non-custom zones
    if DCMapExtensionDB.debug and not mapType and (addon.lastDebugMap ~= mapID or GetTime() - addon.lastDebugTime > 5) then
        Debug("UpdateMap check - MapID:", mapID, "Zone:", zoneName, "No custom map type detected")
        addon.lastDebugMap = mapID
        addon.lastDebugTime = GetTime()
    end
    
    if not mapType then
        -- Player not in a custom zone AND no forced map
        if addon.currentMap then
            addon:HideCustomMap()
            -- DON'T clear forcedMap here - let user manually switch maps
            -- addon.forcedMap = nil
            if DCMapExtensionDB.debug then
                Debug("Player not in custom zone - hiding custom map")
            end
        end
        return
    end
    
    -- Player IS in a custom zone (or forced map is set)
    -- Show the custom map regardless of what map is currently displayed
    if addon.currentMap ~= mapType then
        -- Map changed, reload tiles
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[DC-MapExt] Loading custom map: " .. tostring(mapType) .. "|r")
        
        if addon:ShowCustomMap(mapType) then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[DC-MapExt] Custom map loaded successfully|r")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[DC-MapExt] Failed to load custom map|r")
        end
    else
        if addon.nativeMapActive then
            UpdatePlayerPosition()
        else
            if addon.stitchFrame and not addon.stitchFrame:IsShown() then
                Debug("Refreshing custom map:", mapType)
                addon:ShowCustomMap(mapType)
            end
            CheckAndFixTiles()
            UpdatePlayerPosition()
        end
    end
end

----------------------------------------------
-- Events
----------------------------------------------
local eventFrame = CreateFrame("Frame")

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("WORLD_MAP_UPDATE")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

-- Hook WorldMapFrame show/hide to force reload
local function OnWorldMapShow()
    Debug("WorldMapFrame shown - forcing update")
    UpdateMap()
end

local function OnWorldMapHide()
    Debug("WorldMapFrame hidden")
    -- Save current map state
    if addon.currentMap then
        addon.lastKnownMap = addon.currentMap
    end
end

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "DC-MapExtension" then
            InitDefaults()
            
            -- IMPORTANT: Completely reset addon state to force fresh initialization
            addon.currentMap = nil
            addon.stitchFrame = nil
            addon.playerDot = nil
            addon.coordFrame = nil
            addon.poiMarkers = {}
            addon.hotspotMarkers = {}
            addon.initialized = false
            
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[DC-MapExt] DC-MapExtension loaded - addon state completely reset|r")
            
            -- Hook WorldMapFrame show/hide events
            if WorldMapFrame then
                WorldMapFrame:HookScript("OnShow", OnWorldMapShow)
                WorldMapFrame:HookScript("OnHide", OnWorldMapHide)
                Debug("Hooked WorldMapFrame show/hide events")
            end
            
            -- Hook Zoom Out button to return to Kalimdor continent
            if WorldMapZoomOutButton then
                WorldMapZoomOutButton:SetScript("OnClick", function()
                    if addon.currentMap then
                        Debug("Zoom Out clicked - returning to Kalimdor")
                        addon:HideCustomMap()
                        -- Use the proper Blizzard function to set continent view
                        C_Timer.After(0.1, function()
                            if SetMapToCurrentZone then
                                SetMapToCurrentZone()
                            elseif SetMapZoom then
                                SetMapZoom(1)  -- 1 = Kalimdor continent
                            end
                        end)
                    end
                end)
                Debug("Hooked WorldMapZoomOutButton for custom map zoom out")
            end
            
            -- Hook right-click on the map to zoom out
            if WorldMapButton then
                WorldMapButton:HookScript("OnMouseUp", function(self, button)
                    if button == "RightButton" and addon.currentMap then
                        Debug("Right-click on map - returning to Kalimdor")
                        addon:HideCustomMap()
                        -- Use the proper Blizzard function to set continent view
                        C_Timer.After(0.1, function()
                            if SetMapToCurrentZone then
                                SetMapToCurrentZone()
                            elseif SetMapZoom then
                                SetMapZoom(1)  -- 1 = Kalimdor continent
                            end
                        end)
                    end
                end)
                Debug("Hooked WorldMapButton right-click for zoom out")
            end
        end
    elseif event == "PLAYER_LOGIN" then
        addon.initialized = true
        Debug("Player logged in")
        
        -- Hook WorldMapFrame if not done yet
        if WorldMapFrame and not addon.hookedWorldMap then
            WorldMapFrame:HookScript("OnShow", OnWorldMapShow)
            WorldMapFrame:HookScript("OnHide", OnWorldMapHide)
            addon.hookedWorldMap = true
            Debug("Hooked WorldMapFrame show/hide events (on login)")
        end
        
        UpdateMap()
    elseif event == "WORLD_MAP_UPDATE" then
        if addon.initialized then
            Debug("WORLD_MAP_UPDATE event fired")
            
            -- Don't process map updates if WorldMapFrame isn't shown
            if not WorldMapFrame or not WorldMapFrame:IsShown() then
                Debug("WorldMapFrame not shown, ignoring WORLD_MAP_UPDATE")
                return
            end
            
            -- Check if player is PHYSICALLY in a custom zone
            local mapType = GetCustomMapType()
            Debug("GetCustomMapType returned:", tostring(mapType), "Current map:", tostring(addon.currentMap))
            
            if mapType and addon.currentMap == mapType then
                -- We're already showing the custom map - check if tiles are still valid
                local tile1 = _G["WorldMapDetailTile1"]
                if tile1 then
                    local currentTexture = tile1:GetTexture()
                    local expectedPath = texturePaths[mapType] and texturePaths[mapType][1]
                    -- Only reapply if texture was lost (check if it's not our custom texture)
                    if currentTexture and expectedPath and not currentTexture:find(mapType == "azshara" and "AzsharaCrater" or "Hyjal") then
                        Debug("Detected tile override - reapplying custom tiles for", mapType)
                        DelayedCall(0.05, function()
                            if addon.currentMap == mapType then
                                LoadTiles(mapType)
                            end
                        end)
                    else
                        Debug("Tiles still valid, no reload needed")
                    end
                else
                    Debug("WorldMapDetailTile1 doesn't exist")
                end
            elseif mapType then
                -- Player IS in a custom zone but map not showing yet - trigger update
                Debug("Player in custom zone but map not showing - triggering UpdateMap")
                DelayedCall(0.1, UpdateMap)
            else
                -- Player is NOT in a custom zone
                -- Clear any custom map overlay to show normal map
                if addon.currentMap then
                    ClearTiles()
                    if addon.stitchFrame then addon.stitchFrame:Hide() end
                    if addon.playerDot then addon.playerDot:Hide() end
                    addon.currentMap = nil
                    Debug("Player not in custom zone - showing normal map")
                end
            end
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        if addon.initialized then
            UpdateMap()
        end
    end
end)

-- Update player position periodically (only when enabled and map is shown)
local updateTimer = 0
local hotspotUpdateTimer = 0
local tileWatchdogTimer = 0
eventFrame:SetScript("OnUpdate", function(self, elapsed)
    -- Skip entirely if not initialized
    if not addon.initialized then return end
    local canvas = GetActiveMapCanvas()
    if not canvas or not canvas:IsShown() then return end
    
    -- TILE WATCHDOG: Continuously hide non-custom tiles that Blizzard adds
    if not addon.nativeMapActive then
        tileWatchdogTimer = tileWatchdogTimer + elapsed
        if tileWatchdogTimer >= 0.1 then -- Check 10 times per second
            tileWatchdogTimer = 0

            if addon.currentMap and addon.loadedTextures then
                local expectedType = addon.currentMap
                local maxTiles = NUM_WORLDMAP_DETAIL_TILES or 16

                for i = 1, maxTiles do
                    local tile = _G["WorldMapDetailTile" .. i]
                    if tile then
                        if i <= #addon.loadedTextures then
                            if not tile._DCMapCustom or tile._DCMapType ~= expectedType then
                                tile:Hide()
                                if DCMapExtensionDB.debug and math.random() < 0.01 then -- 1% chance to log
                                    Debug("Watchdog: Hiding non-custom tile", i)
                                end
                            elseif not tile:IsShown() then
                                tile:Show()
                            end
                        elseif tile:IsShown() then
                            tile:Hide()
                        end
                    end
                end
            end

            -- AGGRESSIVE: Hide any unknown children of WorldMapDetailFrame
            -- that aren't our tiles or DC-MapExtension frames
            if WorldMapDetailFrame then
                for i = 1, WorldMapDetailFrame:GetNumChildren() do
                    local child = select(i, WorldMapDetailFrame:GetChildren())
                    if child and child:IsShown() then
                        local name = child:GetName() or ""
                        if not name:find("DCMap_") and
                           not name:find("WorldMapDetailTile") and
                           not name:find("WorldMapButton") then
                            child:Hide()
                            if DCMapExtensionDB.debug and math.random() < 0.05 then
                                Debug("Watchdog: Hiding unknown child:", name or "Unnamed")
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Update player position
    if DCMapExtensionDB.showPlayerDot then
        updateTimer = updateTimer + elapsed
        if updateTimer >= 0.5 then  -- Update 2 times per second
            updateTimer = 0
            UpdatePlayerPosition()
        end
    end
    
    -- Update hotspot markers (check for new/expired hotspots every 2 seconds)
    hotspotUpdateTimer = hotspotUpdateTimer + elapsed
    if hotspotUpdateTimer >= 2.0 then
        hotspotUpdateTimer = 0
        if addon.currentMap then
            -- Refresh hotspot markers
            CreateHotspotMarkers(addon.currentMap)
        end
    end
end

----------------------------------------------
-- Interface Options
----------------------------------------------
local function CreateOptionsPanel()
    local panel = CreateFrame("Frame", "DCMapExtensionOptionsPanel", UIParent)
    panel.name = "DC-MapExtension"
    
    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("DC-MapExtension")
    
    -- Subtitle
    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Custom zone maps for Azshara Crater and Hyjal")
    
    -- Enable checkbox
    local enableCheckbox = CreateFrame("CheckButton", "DCMapExtensionEnableCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
    enableCheckbox:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -16)
    _G[enableCheckbox:GetName() .. "Text"]:SetText("Enable Custom Maps")
    enableCheckbox:SetChecked(DCMapExtensionDB.enabled)
    enableCheckbox:SetScript("OnClick", function(self)
        DCMapExtensionDB.enabled = self:GetChecked()
        UpdateMap()
    end)
    
    -- Show player dot checkbox
    local playerDotCheckbox = CreateFrame("CheckButton", "DCMapExtensionPlayerDotCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
    playerDotCheckbox:SetPoint("TOPLEFT", enableCheckbox, "BOTTOMLEFT", 0, -8)
    _G[playerDotCheckbox:GetName() .. "Text"]:SetText("Show Player Position")
    playerDotCheckbox:SetChecked(DCMapExtensionDB.showPlayerDot)
    playerDotCheckbox:SetScript("OnClick", function(self)
        DCMapExtensionDB.showPlayerDot = self:GetChecked()
        if self:GetChecked() then
            UpdatePlayerPosition()
        else
            if addon.playerDot then
                addon.playerDot:Hide()
            end
        end
    end)
    
    -- Debug checkbox
    local debugCheckbox = CreateFrame("CheckButton", "DCMapExtensionDebugCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
    debugCheckbox:SetPoint("TOPLEFT", playerDotCheckbox, "BOTTOMLEFT", 0, -8)
    _G[debugCheckbox:GetName() .. "Text"]:SetText("Debug Mode")
    debugCheckbox:SetChecked(DCMapExtensionDB.debug)
    debugCheckbox:SetScript("OnClick", function(self)
        DCMapExtensionDB.debug = self:GetChecked()
        Debug("Debug mode", self:GetChecked() and "enabled" or "disabled")
    end)
    
    -- Info text
    local info = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    info:SetPoint("TOPLEFT", debugCheckbox, "BOTTOMLEFT", 0, -24)
    info:SetWidth(550)
    info:SetJustifyH("LEFT")
    info:SetText("This addon adds custom zone maps for:\n\n" ..
                  "• Azshara Crater (Map ID: 37, Zone ID: 268)\n" ..
                  "• Hyjal 2 (Map ID: 1, Zone ID: 616)\n\n" ..
                  "The maps work like standard WoW maps, showing POIs and your character position.\n" ..
                  "Changes take effect immediately without needing to reload.")
    
    InterfaceOptions_AddCategory(panel)
    
    Debug("Options panel created")
end

-- Create options panel on load
CreateOptionsPanel()

----------------------------------------------
-- Slash Commands
----------------------------------------------
SLASH_DCMAP1 = "/dcmap"
SlashCmdList["DCMAP"] = function(msg)
    msg = string.lower(msg or "")
    
    if msg == "show" or msg == "on" then
        DCMapExtensionDB.enabled = true
        UpdateMap()
        print("|cff33ff99[DC-MapExt]|r Custom maps enabled")
    elseif msg == "hide" or msg == "off" then
        DCMapExtensionDB.enabled = false
        UpdateMap()
        print("|cff33ff99[DC-MapExt]|r Custom maps disabled")
    elseif msg == "debug" then
        DCMapExtensionDB.debug = not DCMapExtensionDB.debug
        print("|cff33ff99[DC-MapExt]|r Debug mode:", DCMapExtensionDB.debug and "ON" or "OFF")
    elseif msg == "blptest" then
        -- Test if BLP files can be loaded
        print("|cff33ff99[DC-MapExt]|r Testing BLP file loading...")
        local testFrame = CreateFrame("Frame")
        local testTex = testFrame:CreateTexture()
        
        local testFiles = {
            "Interface\\AddOns\\DC-MapExtension\\Textures\\AzsharaCrater\\AzsharaCrater1.tga",
            "Interface\\AddOns\\DC-MapExtension\\Textures\\Hyjal\\Hyjal1.tga",
            "Interface\\WorldMap\\Azeroth\\Azeroth1",  -- Known good texture
        }
        
        for _, path in ipairs(testFiles) do
            testTex:SetTexture(nil)
            local success = pcall(function() testTex:SetTexture(path) end)
            local loaded = testTex:GetTexture()
            local status = (loaded and loaded ~= "") and "|cff00ff00LOADED|r" or "|cffff0000FAILED|r"
            print("  " .. status .. " - " .. path:match("[^\\]+$"))
        end
    elseif msg == "status" then
        local mapID = GetCurrentMapAreaID and GetCurrentMapAreaID() or 0
        local zoneName = GetZoneText and GetZoneText() or "unknown"
        local realZone = GetRealZoneText and GetRealZoneText() or "unknown"
        local subZone = GetSubZoneText and GetSubZoneText() or "unknown"
        local continent = GetCurrentMapContinent and GetCurrentMapContinent() or 0
        local mapType = GetCustomMapType()
        
        print("|cff33ff99[DC-MapExt]|r Status:")
        print("  Enabled:", DCMapExtensionDB.enabled)
        print("  Current Map ID:", mapID)
        print("  Zone Name:", zoneName)
        print("  Real Zone:", realZone)
        print("  SubZone:", subZone)
        print("  Continent:", continent)
        print("  Custom Map Detected:", mapType or "None")
        print("  Stitch Frame:", addon.stitchFrame and (addon.stitchFrame:IsShown() and "Visible" or "Hidden") or "Not created")
        print("  Current Map Type:", addon.currentMap or "None")
        print("  Player Dot:", addon.playerDot and (addon.playerDot:IsShown() and "Visible" or "Hidden") or "Not created")
    elseif msg == "zone" then
        -- Detailed zone information for debugging
        local mapID = GetCurrentMapAreaID and GetCurrentMapAreaID() or 0
        local zoneName = GetZoneText and GetZoneText() or ""
        local realZone = GetRealZoneText and GetRealZoneText() or ""
        local subZone = GetSubZoneText and GetSubZoneText() or ""
        local miniZone = GetMinimapZoneText and GetMinimapZoneText() or ""
        local continent = GetCurrentMapContinent and GetCurrentMapContinent() or 0
        local zone = GetCurrentMapZone and GetCurrentMapZone() or 0
        
        print("|cff33ff99[DC-MapExt]|r Zone Information:")
        print("  Map ID:", mapID)
        print("  Zone Text:", '"' .. zoneName .. '"')
        print("  Real Zone Text:", '"' .. realZone .. '"')
        print("  SubZone Text:", '"' .. subZone .. '"')
        print("  Minimap Zone:", '"' .. miniZone .. '"')
        print("  Continent:", continent)
        print("  Zone Index:", zone)
        print("")
        print("  Zone (lowercase):", '"' .. zoneName:lower() .. '"')
        print("  Real (lowercase):", '"' .. realZone:lower() .. '"')
        print("  SubZone (lowercase):", '"' .. subZone:lower() .. '"')
    elseif msg == "reload" then
        addon.currentMap = nil
        UpdateMap()
        print("|cff33ff99[DC-MapExt]|r Map reloaded")
    elseif msg == "resetdot" then
        -- Force recreate the player dot
        if addon.playerDot then
            addon.playerDot:Hide()
            addon.playerDot:SetParent(nil)
            addon.playerDot = nil
        end
        CreatePlayerDot()
        print("|cff33ff99[DC-MapExt]|r Player dot recreated - should see red background + blue icon")
    elseif msg == "gps" then
        -- Show GPS data and send a test request to the server
        print("|cff33ff99[DC-MapExt]|r GPS Status:")
        print("  Map ID:", addon.gpsData.mapId or 0)
        print("  Zone ID:", addon.gpsData.zoneId or 0)
        print("  World Coords:", string.format("%.2f, %.2f, %.2f", 
            addon.gpsData.x or 0, addon.gpsData.y or 0, addon.gpsData.z or 0))
        print("  Normalized Coords:", string.format("%.3f, %.3f (%.1f%%, %.1f%%)", 
            addon.gpsData.nx or 0, addon.gpsData.ny or 0, 
            (addon.gpsData.nx or 0) * 100, (addon.gpsData.ny or 0) * 100))
        
        local now = GetTime()
        local gpsAge = now - addon.gpsData.lastUpdate
        if addon.gpsData.lastUpdate > 0 then
            print("  Last Update:", string.format("%.1f seconds ago", gpsAge))
            if gpsAge > 5 then
                print("  |cFFFF0000WARNING:|r GPS data is stale! Server may not be sending updates.")
            end
        else
            print("  |cFFFF0000WARNING:|r No GPS data received yet!")
        end
        
        -- Send a test message to server (if AIO is available)
        if AIO then
            print("  Sending GPS request to server...")
            AIO.Handle("DCMapGPS", "RequestUpdate")
        else
            print("  |cFFFF0000ERROR:|r AIO not available - cannot request GPS data")
        end
    else
        print("|cff33ff99[DC-MapExt]|r Commands:")
        print("  /dcmap show - Enable custom maps")
        print("  /dcmap hide - Disable custom maps")
        print("  /dcmap debug - Toggle debug mode")
        print("  /dcmap status - Show current status")
        print("  /dcmap zone - Show detailed zone info")
        print("  /dcmap reload - Reload current map")
        print("  /dcmap gps - Show GPS status and request update")
        print("  Or use Interface -> Addons -> DC-MapExtension")
    end
end

----------------------------------------------
-- Global API for Mapster Integration
----------------------------------------------
-- These functions allow Mapster to trigger custom maps manually
function DCMapExtension_ShowStitchedMap(mapType)
    if not DCMapExtensionDB.enabled then 
        Debug("DCMapExtension_ShowStitchedMap called but addon disabled")
        return 
    end
    
    Debug("=== DCMapExtension_ShowStitchedMap called with mapType:", tostring(mapType), "===")
    
    if mapType == "azshara" or mapType == "hyjal" then
        Debug("Mapster/Manual requested custom map:", mapType)
        
        -- Clear any existing custom map first to avoid mixing
        if addon.currentMap and addon.currentMap ~= mapType then
            Debug("Clearing previous map:", addon.currentMap)
            ClearTiles()
        end
        
        addon.forcedMap = mapType  -- Set forced map override
        
        if WorldMapFrame and WorldMapFrame:IsShown() then
            -- Immediately show the custom map
            if addon:ShowCustomMap(mapType) then
                Debug("Custom map shown successfully")
                -- Ensure player dot is visible
                UpdatePlayerPosition()
            else
                Debug("Failed to show custom map")
            end
        else
            Debug("WorldMapFrame not open - map will show when opened")
        end
    else
        Debug("Unknown map type requested:", tostring(mapType))
    end
end

function DCMapExtension_ClearForcedMap()
    if addon.forcedMap then
        Debug("Clearing forced map:", addon.forcedMap)
        addon.forcedMap = nil  -- Clear forced map override
    end
    if addon.currentMap then
        addon:HideCustomMap()
    end
    
    -- Force Blizzard to reload the normal map for current location
    if WorldMapFrame and WorldMapFrame:IsShown() then
        if WorldMapFrame_UpdateMap then
            WorldMapFrame_UpdateMap()
        end
    end
    
    Debug("Forced map cleared and normal map restored")
end

----------------------------------------------
-- GPS Data Getter Function (for debugging)
----------------------------------------------
function DCMapExtension_GetGPSData()
    return addon.gpsData
end

----------------------------------------------
-- Hook GetPlayerMapPosition for Custom Zones
-- THIS IS THE KEY: Makes custom zones work with ALL existing addons!
----------------------------------------------
local OriginalGetPlayerMapPosition = GetPlayerMapPosition

-- Override GetPlayerMapPosition to return GPS coordinates for custom zones
GetPlayerMapPosition = function(unit)
    -- Call original function first
    local origX, origY = OriginalGetPlayerMapPosition(unit)
    
    -- If this is the player and we have recent GPS data (within 3 seconds)
    if unit == "player" and addon.gpsData then
        local now = GetTime()
        local gpsAge = now - (addon.gpsData.lastUpdate or 0)
        
        if gpsAge < 3 then
            local gpsMapId = addon.gpsData.mapId or 0
            local gpsZoneId = addon.gpsData.zoneId or 0
            local mapType = ResolveMapType(gpsMapId, gpsZoneId)

            if mapType and addon.gpsData.nx and addon.gpsData.ny then
                local nx, ny = NormalizeMapCoords(mapType, addon.gpsData.nx, addon.gpsData.ny)

                if (not nx or not ny) and addon.gpsData.x and addon.gpsData.y then
                    nx, ny = ConvertWorldToMapCoords(addon.gpsData.x, addon.gpsData.y, mapType)
                end

                if nx and ny then
                    if DCMapExtensionDB.debug then
                        if not addon.lastGPSHookLog or (now - addon.lastGPSHookLog) > 5 then
                            addon.lastGPSHookLog = now
                            Debug("GetPlayerMapPosition returning corrected GPS coords:", string.format("%.3f, %.3f", nx, ny))
                        end
                    end
                    return nx, ny
                end
            end
        end
    end
    
    -- Default: return original coordinates
    return origX, origY
end

-- Debug log
if DCMapExtensionDB and DCMapExtensionDB.debug then
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[DC-MapExt] Hooked GetPlayerMapPosition for custom zone support|r")
end

----------------------------------------------
-- GPS Data Update Function (called by server via Lua)
----------------------------------------------
function DCMapExtension_UpdateGPS(mapId, zoneId, x, y, z, nx, ny)
    -- Update GPS data directly - server now handles axis corrections
    addon.gpsData.mapId = mapId
    addon.gpsData.zoneId = zoneId
    addon.gpsData.x = x
    addon.gpsData.y = y
    addon.gpsData.z = z
    addon.gpsData.nx = nx
    addon.gpsData.ny = ny
    addon.gpsData.lastUpdate = GetTime()
    
    -- Debug output (throttled)
    if DCMapExtensionDB.debug then
        local now = GetTime()
        if not addon.lastGPSDebug or (now - addon.lastGPSDebug) > 5 then
            addon.lastGPSDebug = now
            Debug("GPS Update: Map=" .. mapId .. " Zone=" .. zoneId .. 
                  " Pos=(" .. string.format("%.1f", x) .. "," .. string.format("%.1f", y) .. "," .. string.format("%.1f", z) .. ")" ..
                  " Normalized=(" .. string.format("%.3f", nx) .. "," .. string.format("%.3f", ny) .. ")")
        end
    end
    
    -- Trigger map update if GPS zone changed (player entered/left custom zone)
    local prevGPSMap = addon.lastGPSMap or 0
    local prevGPSZone = addon.lastGPSZone or 0
    if mapId ~= prevGPSMap or zoneId ~= prevGPSZone then
        addon.lastGPSMap = mapId
        addon.lastGPSZone = zoneId
        if WorldMapFrame and WorldMapFrame:IsShown() then
            Debug("GPS zone changed - triggering map update")
            UpdateMap()
        end
    end
end

----------------------------------------------
-- AIO GPS Handler (Legacy - keeping for compatibility)
----------------------------------------------
if AIO then
    AIO.AddHandlers("DCMapGPS", {
        Update = function(player, data)
            -- Parse GPS data from server
            -- Expected format: {"mapId":37,"zoneId":268,"x":123.4,"y":456.7,"z":89.0,"nx":0.524,"ny":0.673}
            if type(data) == "string" then
                Debug("Received GPS data:", data)
                
                -- Simple JSON parsing for our specific format
                local mapId = tonumber(data:match('"mapId"%s*:%s*(%d+)'))
                local zoneId = tonumber(data:match('"zoneId"%s*:%s*(%d+)'))
                local x = tonumber(data:match('"x"%s*:%s*([%-%.%d]+)'))
                local y = tonumber(data:match('"y"%s*:%s*([%-%.%d]+)'))
                local z = tonumber(data:match('"z"%s*:%s*([%-%.%d]+)'))
                local nx = tonumber(data:match('"nx"%s*:%s*([%-%.%d]+)'))
                local ny = tonumber(data:match('"ny"%s*:%s*([%-%.%d]+)'))
                
                if mapId and zoneId and x and y and z and nx and ny then
                    DCMapExtension_UpdateGPS(mapId, zoneId, x, y, z, nx, ny)
                else
                    Debug("GPS parse failed - mapId:", tostring(mapId), "zoneId:", tostring(zoneId), 
                          "x:", tostring(x), "y:", tostring(y), "z:", tostring(z),
                          "nx:", tostring(nx), "ny:", tostring(ny))
                end
            end
        end
    })
    
    Debug("AIO GPS handler registered successfully")
else
    Debug("WARNING: AIO not available - using Lua script GPS updates")
end

-- Expose addon table globally for debugging
_G.DCMapExtension = addon

print("|cff33ff99[DC-MapExtension]|r Loaded. Type /dcmap for help or use Interface -> Addons")
