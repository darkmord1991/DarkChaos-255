-- DC-MapExtension: Clean implementation for WoW 3.3.5a
-- Adds custom zone maps for Azshara Crater and Hyjal to the standard world map

----------------------------------------------
-- Constants
----------------------------------------------
local AZSHARA_CRATER_MAP_ID = 38  -- Corrected from 37 based on actual game detection
local AZSHARA_CRATER_ZONE_ID = 268
local HYJAL_MAP_ID = 1  -- Kalimdor continent
local HYJAL_ZONE_ID = 616

local TILE_COLS = 4
local TILE_ROWS = 3

----------------------------------------------
-- Saved Variables
----------------------------------------------
DCMapExtensionDB = DCMapExtensionDB or {}

-- Default settings
local function InitDefaults()
    if DCMapExtensionDB.enabled == nil then DCMapExtensionDB.enabled = true end
    if DCMapExtensionDB.showPlayerDot == nil then DCMapExtensionDB.showPlayerDot = true end  -- Enabled by default for custom zones
    if DCMapExtensionDB.debug == nil then DCMapExtensionDB.debug = false end
    -- Force disable debug on first load to prevent spam
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
-- Coordinates from ac_guard_npc.cpp converted to map coordinates (0-1 range)
-- Map 38 (Azshara Crater) dimensions: roughly -1000 to 500 in X, -500 to 1500 in Y
local poi_data = {
    azshara = {
        {name = "Startcamp", x = 0.754, y = 0.493},
        {name = "Flight Master", x = 0.718, y = 0.533},
        {name = "Innkeeper", x = 0.734, y = 0.481},
        {name = "Auctionhouse", x = 0.745, y = 0.474},
        {name = "Stable Master", x = 0.730, y = 0.486},
        {name = "Transmog", x = 0.766, y = 0.500},
        {name = "Riding Trainer", x = 0.747, y = 0.523},
        {name = "Profession Trainers", x = 0.696, y = 0.414},
        {name = "Weapon Trainer", x = 0.734, y = 0.498},
        {name = "Violet Temple", x = 0.284, y = 0.604},
        {name = "Dragon Statues", x = 0.616, y = 0.520}
    },
    hyjal = {
        {name = "Nordrassil (World Tree)", x = 0.50, y = 0.50},
        {name = "Shrine of Aviana", x = 0.35, y = 0.30},
        {name = "Sanctuary of Malorne", x = 0.65, y = 0.40},
        {name = "Gates of Sothann", x = 0.50, y = 0.70},
        {name = "Tortolla's Retreat", x = 0.25, y = 0.55}
    }
}

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
-- Map bounds based on actual zone data
-- These convert world X,Y coordinates to normalized 0-1 map coordinates
local mapBounds = {
    [37] = {  -- Azshara Crater (Map ID 37, Zone ID 268)
        minX = -1000,
        maxX = 500,
        minY = -500,
        maxY = 1500
    },
    [1] = {  -- Hyjal (Map ID 1, Zone ID 616) - these are placeholder values
        minX = -5000,
        maxX = 5000,
        minY = -5000,
        maxY = 5000
    }
}

local function WorldToNormalized(mapId, worldX, worldY)
    local bounds = mapBounds[mapId]
    if not bounds then return nil, nil end
    
    local nx = (worldX - bounds.minX) / (bounds.maxX - bounds.minX)
    local ny = (worldY - bounds.minY) / (bounds.maxY - bounds.minY)
    
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
    -- Check if player is PHYSICALLY in Azshara Crater zone
    local zoneName, subZone = GetPlayerZoneInfo()
    local zoneCheck = zoneName:lower()
    local subCheck = subZone:lower()
    
    if zoneCheck:find("azshara crater") or zoneCheck:find("azshara%-krater") or
       subCheck:find("azshara crater") or subCheck:find("azshara%-krater") then
        return true
    end
    
    return false
end

local function IsPlayerInHyjal()
    -- Check if player is PHYSICALLY in Hyjal zone
    local zoneName, subZone = GetPlayerZoneInfo()
    local zoneCheck = zoneName:lower()
    local subCheck = subZone:lower()
    
    if zoneCheck:find("hyjal") or subCheck:find("hyjal") then
        return true
    end
    
    return false
end

local function GetCustomMapType()
    -- IMPORTANT: Only show custom maps if player is PHYSICALLY in the zone
    -- Don't show custom maps just because they selected it from dropdown
    local mapType = nil
    
    if IsPlayerInAzsharaCrater() then
        mapType = "azshara"
    elseif IsPlayerInHyjal() then
        mapType = "hyjal"
    end
    
    return mapType
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

local function CreatePlayerDot()
    if addon.playerDot then
        return addon.playerDot
    end
    
    -- Wait for stitchFrame to exist
    if not addon.stitchFrame then 
        Debug("Cannot create player dot - stitchFrame doesn't exist yet")
        return nil 
    end
    
    local dot = CreateFrame("Frame", "DCMap_PlayerDot", addon.stitchFrame)
    dot:SetWidth(16)  -- Increased from 12 for better visibility
    dot:SetHeight(16)
    dot:SetFrameLevel(addon.stitchFrame:GetFrameLevel() + 10)
    
    local tex = dot:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints()
    tex:SetTexture("Interface\\Minimap\\MinimapArrow")
    tex:SetVertexColor(0.2, 0.5, 1.0)  -- Blue tint for visibility
    dot.texture = tex
    
    dot:Hide()
    
    addon.playerDot = dot
    Debug("Player dot created on stitchFrame")
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
            playerText:SetText(string.format("Player: %.1f, %.1f", addon.gpsData.nx * 100, addon.gpsData.ny * 100))
        elseif px and py and (px > 0 or py > 0) then
            -- Use client-side coordinates (works for standard zones)
            playerText:SetText(string.format("Player: %.1f, %.1f", px * 100, py * 100))
        else
            -- No valid position data
            playerText:SetText("Player: Not in zone")
        end
        
        -- Update cursor coordinates relative to the stitched map frame
        local parent = addon.stitchFrame or WorldMapDetailFrame
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
    return {}
end

local function ConvertWorldToMapCoords(worldX, worldY, mapType)
    -- Convert world coordinates to map coordinates (0-1 range)
    -- Azshara Crater (map 38) coordinate conversion
    -- Based on known bounds: X roughly -1000 to 500, Y roughly -500 to 1500
    if mapType == "azshara" then
        -- Normalize coordinates
        local minX, maxX = -1000, 500
        local minY, maxY = -500, 1500
        local mapX = (worldX - minX) / (maxX - minX)
        local mapY = (worldY - minY) / (maxY - minY)
        return mapX, mapY
    elseif mapType == "hyjal" then
        -- Hyjal coordinate conversion (adjust as needed)
        local minX, maxX = -5000, -3000
        local minY, maxY = -2000, 0
        local mapX = (worldX - minX) / (maxX - minX)
        local mapY = (worldY - minY) / (maxY - minY)
        return mapX, mapY
    end
    return 0.5, 0.5  -- Center fallback
end

local function CreateHotspotMarkers(mapType)
    if not addon.stitchFrame then return end
    
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
    
    local parent = WorldMapDetailFrame or addon.stitchFrame
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
        
        if showHotspot and hotspot.x and hotspot.y then
            -- Convert world coordinates to map coordinates
            local mapX, mapY = ConvertWorldToMapCoords(hotspot.x, hotspot.y, mapType)
            
            -- Create hotspot marker frame
            local marker = CreateFrame("Frame", "DCMap_Hotspot_" .. id, parent)
            marker:SetWidth(24)
            marker:SetHeight(24)
            marker:SetFrameLevel(parent:GetFrameLevel() + 6)
            
            -- Hotspot icon texture - use a glowing effect
            local tex = marker:CreateTexture(nil, "OVERLAY")
            tex:SetAllPoints()
            tex:SetTexture("Interface\\AddOns\\DCHotspotXP\\textures\\hotspot_icon")  -- Try custom icon
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
                GameTooltip:AddLine(string.format("Position: %.1f, %.1f", hotspot.x, hotspot.y), 0.7, 0.7, 0.7)
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
    
    Debug("Created", markerCount, "hotspot markers for", mapType)
end

local function CreatePOIMarkers(mapType)
    if not addon.stitchFrame then return end
    
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
    
    local parent = WorldMapDetailFrame or addon.stitchFrame
    local frameWidth = parent:GetWidth()
    local frameHeight = parent:GetHeight()
    
    if not frameWidth or not frameHeight or frameWidth == 0 or frameHeight == 0 then
        Debug("Invalid frame dimensions for POIs")
        return
    end
    
    for i, poi in ipairs(pois) do
        -- Create POI marker frame
        local marker = CreateFrame("Frame", "DCMap_POI_" .. i, parent)
        marker:SetWidth(16)
        marker:SetHeight(16)
        marker:SetFrameLevel(parent:GetFrameLevel() + 5)
        
        -- POI icon texture
        local tex = marker:CreateTexture(nil, "OVERLAY")
        tex:SetAllPoints()
        tex:SetTexture("Interface\\Minimap\\POIIcons")  -- Use Blizzard POI icons
        tex:SetTexCoord(0.5, 0.625, 0, 0.125)  -- Gold star icon
        marker.texture = tex
        
        -- Position the POI
        local pixelX = poi.x * frameWidth
        local pixelY = -poi.y * frameHeight
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
        Debug("Created POI marker:", poi.name, "at", poi.x, poi.y)
    end
    
    Debug("Created", #addon.poiMarkers, "POI markers for", mapType)
end

----------------------------------------------
-- Texture Loading
----------------------------------------------
local function ClearTiles()
    -- Restore WorldMapDetailFrame alpha
    if WorldMapDetailFrame then
        WorldMapDetailFrame:SetAlpha(1)
        Debug("Restored WorldMapDetailFrame alpha to 1")
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
        Debug("ERROR: No texture paths for map type:", mapType)
        return false
    end
    
    Debug("=== Loading tiles for", mapType, "===")
    Debug("NUM_WORLDMAP_DETAIL_TILES:", NUM_WORLDMAP_DETAIL_TILES or "UNDEFINED")
    
    -- AGGRESSIVELY hide continent background
    -- WorldMapDetailFrame contains the base continent texture - hide it completely
    if WorldMapDetailFrame then
        WorldMapDetailFrame:SetAlpha(0)  -- Hide the entire detail frame background
        Debug("Set WorldMapDetailFrame alpha to 0")
    end
    
    -- Hide Blizzard's native detail tiles (the ones we'll be replacing)
    -- Don't hide other WorldMapDetailFrame elements
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
            -- Hide the tile - we'll replace it with our custom texture
            tile:Hide()
        end
    end
    Debug("Saved/hid", (addon.originalTextures and #addon.originalTextures or 0), "original tiles")
    
    -- Use Blizzard's built-in detail tiles
    local successCount = 0
    local errorCount = 0
    
    for i = 1, math.min(#paths, NUM_WORLDMAP_DETAIL_TILES or 16) do
        local tile = _G["WorldMapDetailTile" .. i]
        local texturePath = paths[i]
        
        if not tile then
            Debug("ERROR: WorldMapDetailTile" .. i, "doesn't exist!")
            errorCount = errorCount + 1
        else
            -- Try to set the texture
            local success, err = pcall(function()
                -- Clear existing texture first
                tile:SetTexture(nil)
                
                -- Now set our BLP
                tile:SetTexture(texturePath)
                tile:SetTexCoord(0, 1, 0, 1)
                tile:SetAlpha(1)
                tile:SetVertexColor(1, 1, 1, 1)
                tile:Show()
            end)
            
            if success then
                -- Verify the texture actually loaded
                local actualTexture = tile:GetTexture()
                if actualTexture and actualTexture ~= "" then
                    successCount = successCount + 1
                    Debug("SUCCESS Tile", i, "->", texturePath:match("[^\\]+$"))
                else
                    Debug("WARNING: Tile", i, "set but GetTexture() returned empty")
                    errorCount = errorCount + 1
                end
            else
                Debug("ERROR: Tile", i, "failed:", tostring(err))
                errorCount = errorCount + 1
                
                -- Try fallback to a known-good texture
                pcall(function()
                    tile:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                    tile:SetTexCoord(0, 1, 0, 1)
                    tile:SetVertexColor(1, 0, 0, 0.5)  -- Red tint to show error
                end)
            end
        end
    end
    
    Debug("=== Load complete: Success=" .. successCount .. " Errors=" .. errorCount .. " ===")
    
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
-- Player Position
----------------------------------------------
local function UpdatePlayerPosition()
    if not DCMapExtensionDB.showPlayerDot then return end
    if not addon.playerDot then 
        CreatePlayerDot()
        if not addon.playerDot then return end
    end
    
    -- Make sure we're viewing a custom zone
    if not addon.currentMap then
        addon.playerDot:Hide()
        return
    end
    
    -- Try to use server GPS data first (accurate for custom zones)
    local now = GetTime()
    local gpsAge = now - addon.gpsData.lastUpdate
    local hasValidGPS = (gpsAge < 3) and (addon.gpsData.nx > 0 or addon.gpsData.ny > 0)
    
    local x, y
    if hasValidGPS then
        -- Use server-provided normalized coordinates
        x, y = addon.gpsData.nx, addon.gpsData.ny
    else
        -- Fall back to client-side GetPlayerMapPosition (works for standard zones)
        x, y = GetPlayerMapPosition("player")
    end
    
    -- Throttle debug messages to once per 5 seconds
    local shouldDebug = DCMapExtensionDB.debug and (now - addon.lastPlayerPosDebug > 5)
    
    if not x or not y or (x == 0 and y == 0) then
        -- Player not in this zone or position unavailable - hide dot
        if shouldDebug then
            addon.lastPlayerPosDebug = now
            Debug("Player position unavailable or 0,0 - hiding dot (GPS age: " .. string.format("%.1f", gpsAge) .. "s)")
        end
        addon.playerDot:Hide()
        return
    end
    
    -- Use stitchFrame as parent for custom maps (not WorldMapDetailFrame which we hide)
    local parent = addon.stitchFrame
    if not parent then
        addon.playerDot:Hide()
        return
    end
    
    local frameWidth = parent:GetWidth()
    local frameHeight = parent:GetHeight()
    
    if not frameWidth or not frameHeight or frameWidth == 0 or frameHeight == 0 then
        addon.playerDot:Hide()
        return
    end
    
    local pixelX = x * frameWidth
    local pixelY = y * frameHeight  -- Direct conversion (normalized coords are already correct)
    
    addon.playerDot:ClearAllPoints()
    addon.playerDot:SetPoint("CENTER", parent, "TOPLEFT", pixelX, -pixelY)  -- Negate here for TOPLEFT anchor
    addon.playerDot:Show()
    
    if shouldDebug then
        addon.lastPlayerPosDebug = now
        Debug("Player pos: x=" .. string.format("%.3f", x) .. " y=" .. string.format("%.3f", y) .. 
              " -> " .. string.format("%.0f", pixelX) .. "," .. string.format("%.0f", pixelY))
    end
end

----------------------------------------------
-- Map Update
----------------------------------------------
local function HideNativeDetailTiles()
    -- Hide Blizzard's default map tiles
    for i = 1, NUM_WORLDMAP_DETAIL_TILES or 0 do
        local tile = _G["WorldMapDetailTile" .. i]
        if tile then
            tile:Hide()
        end
    end
    
    -- Also hide the WorldMapDetailFrame itself to prevent background showing through
    if WorldMapDetailFrame then
        WorldMapDetailFrame:SetAlpha(0)
    end
end

local function ShowNativeDetailTiles()
    -- Restore Blizzard's default map tiles
    for i = 1, NUM_WORLDMAP_DETAIL_TILES or 0 do
        local tile = _G["WorldMapDetailTile" .. i]
        if tile then
            tile:Show()
        end
    end
    
    -- Restore WorldMapDetailFrame visibility
    if WorldMapDetailFrame then
        WorldMapDetailFrame:SetAlpha(1)
    end
end

-- Store in addon table so global functions can access them
function addon:ShowCustomMap(mapType)
    Debug("ShowCustomMap called for:", mapType)
    
    if not mapType or (mapType ~= "azshara" and mapType ~= "hyjal") then
        Debug("Invalid map type:", tostring(mapType))
        return false
    end
    
    -- Set current map BEFORE creating frames so OnUpdate can reference it
    self.currentMap = mapType
    
    CreateStitchFrame()
    CreatePlayerDot()
    CreateCoordinateDisplay()
    
    if LoadTiles(mapType) then
        Debug("Tiles loaded successfully for", mapType)
        self.stitchFrame:Show()
        CreatePOIMarkers(mapType)
        CreateHotspotMarkers(mapType)
        
        -- Coordinate display is always shown, OnUpdate handles visibility
        
        HideNativeDetailTiles()
        return true
    else
        Debug("Failed to load tiles for", mapType)
        self.currentMap = nil
        return false
    end
end

function addon:HideCustomMap()
    Debug("HideCustomMap called")
    
    if self.stitchFrame then
        self.stitchFrame:Hide()
    end
    if self.playerDot then
        self.playerDot:Hide()
    end
    if self.coordFrame then
        -- Clear text instead of hiding frame so it doesn't interfere with other maps
        if self.coordFrame.playerText then
            self.coordFrame.playerText:SetText("")
        end
        if self.coordFrame.cursorText then
            self.coordFrame.cursorText:SetText("")
        end
    end
    
    ClearTiles()
    ShowNativeDetailTiles()
    
    self.currentMap = nil
end

local function UpdateMap()
    if not DCMapExtensionDB.enabled then
        addon:HideCustomMap()
        addon.currentMap = nil
        return
    end
    
    local mapType = GetCustomMapType()
    local mapID = GetCurrentMapAreaID and GetCurrentMapAreaID() or 0
    
    -- Throttle debug messages - only show when map actually changes
    if DCMapExtensionDB.debug and (addon.lastDebugMap ~= mapID or GetTime() - addon.lastDebugTime > 5) then
        local zoneName = GetZoneText and GetZoneText() or "unknown"
        local continent = GetCurrentMapContinent and GetCurrentMapContinent() or 0
        Debug("UpdateMap check - MapID:", mapID, "Zone:", zoneName, "Continent:", continent, "Detected type:", tostring(mapType))
        addon.lastDebugMap = mapID
        addon.lastDebugTime = GetTime()
    end
    
    if not mapType then
        -- Not in a custom zone, restore original map
        if addon.currentMap then
            addon:HideCustomMap()
            Debug("Not in custom zone, hiding overlay")
            addon.currentMap = nil
        end
        return
    end
    
    -- In a custom zone
    if addon.currentMap ~= mapType then
        -- Map changed, reload tiles
        Debug("Map changed from", tostring(addon.currentMap), "to", mapType)
        addon.currentMap = mapType
        
        if addon:ShowCustomMap(mapType) then
            Debug("Custom map shown:", mapType)
        else
            Debug("Failed to show custom map:", mapType)
        end
    else
        -- Same map but ensure it's still visible
        if addon.stitchFrame and not addon.stitchFrame:IsShown() then
            Debug("Refreshing custom map:", mapType)
            addon:ShowCustomMap(mapType)
        end
    end
    
    -- Update player position
    UpdatePlayerPosition()
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
            Debug("DC-MapExtension loaded")
            
            -- Hook WorldMapFrame show/hide events
            if WorldMapFrame then
                WorldMapFrame:HookScript("OnShow", OnWorldMapShow)
                WorldMapFrame:HookScript("OnHide", OnWorldMapHide)
                Debug("Hooked WorldMapFrame show/hide events")
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
            -- Check if player is PHYSICALLY in a custom zone
            local mapType = GetCustomMapType()
            
            if mapType then
                -- Player IS in a custom zone - show custom map
                C_Timer.After(0.1, UpdateMap)
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
eventFrame:SetScript("OnUpdate", function(self, elapsed)
    -- Skip entirely if not initialized
    if not addon.initialized then return end
    if not addon.stitchFrame or not addon.stitchFrame:IsShown() then return end
    
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
end)

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
        
        -- Additional checks
        print("  IsAzsharaCrater():", IsAzsharaCrater() and "YES" or "NO")
        print("  IsHyjal():", IsHyjal() and "YES" or "NO")
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
    if not DCMapExtensionDB.enabled then return end
    
    if mapType == "azshara" or mapType == "hyjal" then
        Debug("Mapster requested custom map:", mapType)
        addon.currentMap = mapType
        addon:ShowCustomMap(mapType)
    else
        Debug("Unknown map type requested:", tostring(mapType))
    end
end

function DCMapExtension_ClearForcedMap()
    if addon.currentMap then
        Debug("Clearing forced map")
        addon:HideCustomMap()
        addon.currentMap = nil
    end
end

----------------------------------------------
-- GPS Data Update Function (called by server via Lua)
----------------------------------------------
function DCMapExtension_UpdateGPS(mapId, zoneId, x, y, z, nx, ny)
    -- Update GPS data
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

print("|cff33ff99[DC-MapExtension]|r Loaded. Type /dcmap for help or use Interface -> Addons")
