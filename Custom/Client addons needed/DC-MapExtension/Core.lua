-- DC-MapExtension: Clean implementation for WoW 3.3.5a
-- Adds custom zone maps for Azshara Crater and Hyjal to the standard world map

----------------------------------------------
-- Constants
----------------------------------------------
local AZSHARA_CRATER_MAP_ID = 37
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
    if DCMapExtensionDB.showPlayerDot == nil then DCMapExtensionDB.showPlayerDot = false end  -- Disabled by default to avoid performance issues
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
    currentMap = nil,
    initialized = false,
    lastDebugMap = nil,
    lastDebugTime = 0,
    lastPlayerPosDebug = 0
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
-- Debug Helper
----------------------------------------------
local function Debug(...)
    if not DCMapExtensionDB.debug then return end
    local msg = strjoin(" ", "[DC-MapExt]", tostringall(...))
    DEFAULT_CHAT_FRAME:AddMessage(msg, 0.2, 1, 0.2)
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
    SetMapToCurrentZone()
    local mapID = GetCurrentMapAreaID and GetCurrentMapAreaID() or 0
    local zoneName = GetRealZoneText and GetRealZoneText() or GetZoneText and GetZoneText() or ""
    
    return mapID, zoneName
end

local function IsAzsharaCrater()
    -- Check the currently viewed map
    local mapID = GetCurrentMapAreaID and GetCurrentMapAreaID() or 0
    
    -- Azshara Crater has Map ID 37 (original custom map ID was 9001 but Mapster remaps to 37)
    if mapID == AZSHARA_CRATER_MAP_ID then
        if DCMapExtensionDB.debug then
            Debug("Azshara detected via map ID:", mapID)
        end
        return true
    end
    
    -- Also check by zone name (case insensitive)
    local zoneName = GetZoneText and GetZoneText() or ""
    local zoneCheck = zoneName:lower()
    
    if zoneCheck:find("azshara crater") or zoneCheck:find("azshara%-krater") then
        if DCMapExtensionDB.debug then
            Debug("Azshara detected via zone name:", zoneName)
        end
        return true
    end
    
    return false
end

local function IsHyjal()
    -- Check the currently viewed map
    local mapID = GetCurrentMapAreaID and GetCurrentMapAreaID() or 0
    
    -- Hyjal can have Map ID 14, 534, 614, 616, or 9002
    -- Map ID 614 is "Hyjal 2" according to WorldMapArea.csv
    if mapID == 14 or mapID == 534 or mapID == 614 or mapID == 616 or mapID == 9002 then
        if DCMapExtensionDB.debug then
            Debug("Hyjal detected via map ID:", mapID)
        end
        return true
    end
    
    -- Also check zone names (case insensitive)
    local zoneName = GetZoneText and GetZoneText() or ""
    local zoneCheck = zoneName:lower()
    
    if zoneCheck:find("hyjal") then
        if DCMapExtensionDB.debug then
            Debug("Hyjal detected via zone name:", zoneName)
        end
        return true
    end
    
    return false
end

local function GetCustomMapType()
    local mapType = nil
    
    if IsAzsharaCrater() then
        mapType = "azshara"
    elseif IsHyjal() then
        mapType = "hyjal"
    end
    
    -- Don't log here - this function is called frequently
    -- The detection functions (IsAzsharaCrater/IsHyjal) already log when debug is enabled
    
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
    
    local frame = addon.stitchFrame
    if not frame then return nil end
    
    local dot = CreateFrame("Frame", "DCMap_PlayerDot", frame)
    dot:SetWidth(12)
    dot:SetHeight(12)
    dot:SetFrameLevel(frame:GetFrameLevel() + 10)
    
    local tex = dot:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints()
    tex:SetTexture("Interface\\Minimap\\MinimapArrow")
    dot.texture = tex
    
    dot:Hide()
    
    addon.playerDot = dot
    Debug("Player dot created")
    return dot
end

----------------------------------------------
-- Texture Loading
----------------------------------------------
local function ClearTiles()
    -- Restore WorldMapButton alpha (show continent background again)
    if WorldMapButton then
        WorldMapButton:SetAlpha(1)
        Debug("Restored WorldMapButton alpha to 1")
    end
    
    -- Restore original Blizzard tiles
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
    Debug("Tiles cleared")
end

local function LoadTiles(mapType)
    local paths = texturePaths[mapType]
    if not paths then
        Debug("ERROR: No texture paths for map type:", mapType)
        return false
    end
    
    Debug("=== Loading tiles for", mapType, "===")
    Debug("NUM_WORLDMAP_DETAIL_TILES:", NUM_WORLDMAP_DETAIL_TILES or "UNDEFINED")
    
    -- Hide the continent/background map by making WorldMapButton invisible
    -- This is simpler than trying to find individual background textures
    if WorldMapButton then
        WorldMapButton:SetAlpha(0)
        Debug("Set WorldMapButton alpha to 0 (hiding continent background)")
    end
    
    -- Also try to hide any base textures on WorldMapDetailFrame
    if WorldMapDetailFrame then
        local baseTexture = WorldMapDetailFrame:GetRegions()
        if baseTexture and baseTexture.SetTexture then
            baseTexture:SetTexture(nil)
            Debug("Cleared WorldMapDetailFrame base texture")
        end
    end
    
    -- Save original Blizzard textures before replacing
    if not addon.originalTextures then
        addon.originalTextures = {}
        for i = 1, NUM_WORLDMAP_DETAIL_TILES or 0 do
            local tile = _G["WorldMapDetailTile" .. i]
            if tile and tile.GetTexture then
                addon.originalTextures[i] = tile:GetTexture()
            end
        end
        Debug("Saved", #addon.originalTextures, "original textures")
    end
    
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
    
    -- Get player position WITHOUT changing the viewed map
    -- This returns 0,0 if player is not in the zone currently being viewed
    local x, y = GetPlayerMapPosition("player")
    
    -- Throttle debug messages to once per 5 seconds
    local now = GetTime()
    local shouldDebug = DCMapExtensionDB.debug and (now - addon.lastPlayerPosDebug > 5)
    
    if not x or not y or (x == 0 and y == 0) then
        -- Player not in this zone or position unavailable - hide dot
        if shouldDebug then
            addon.lastPlayerPosDebug = now
            Debug("Player position unavailable or 0,0 - hiding dot")
        end
        addon.playerDot:Hide()
        return
    end
    
    -- Use WorldMapDetailFrame as parent for positioning
    local parent = WorldMapDetailFrame or addon.stitchFrame
    local frameWidth = parent:GetWidth()
    local frameHeight = parent:GetHeight()
    
    if not frameWidth or not frameHeight or frameWidth == 0 or frameHeight == 0 then
        addon.playerDot:Hide()
        return
    end
    
    local pixelX = x * frameWidth
    local pixelY = -y * frameHeight  -- Negative because WoW coordinates are inverted
    
    addon.playerDot:ClearAllPoints()
    addon.playerDot:SetPoint("CENTER", parent, "TOPLEFT", pixelX, pixelY)
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
end

local function ShowNativeDetailTiles()
    -- Restore Blizzard's default map tiles
    for i = 1, NUM_WORLDMAP_DETAIL_TILES or 0 do
        local tile = _G["WorldMapDetailTile" .. i]
        if tile then
            tile:Show()
        end
    end
end

local function UpdateMap()
    if not DCMapExtensionDB.enabled then
        if addon.stitchFrame then
            addon.stitchFrame:Hide()
        end
        if addon.playerDot then
            addon.playerDot:Hide()
        end
        ShowNativeDetailTiles()
        addon.currentMap = nil
        return
    end
    
    local mapType = GetCustomMapType()
    local mapID = GetCurrentMapAreaID and GetCurrentMapAreaID() or 0
    
    -- Throttle debug messages - only show when map actually changes
    if DCMapExtensionDB.debug and (addon.lastDebugMap ~= mapID or GetTime() - addon.lastDebugTime > 5) then
        local zoneName = GetZoneText and GetZoneText() or "unknown"
        local continent = GetCurrentMapContinent and GetCurrentMapContinent() or 0
        Debug("UpdateMap check - MapID:", mapID, "Zone:", zoneName, "Continent:", continent)
        addon.lastDebugMap = mapID
        addon.lastDebugTime = GetTime()
    end
    
    if not mapType then
        -- Not in a custom zone, restore original map
        if addon.stitchFrame then
            addon.stitchFrame:Hide()
        end
        if addon.playerDot then
            addon.playerDot:Hide()
        end
        
        -- Only restore once when leaving custom zone
        if addon.currentMap then
            ClearTiles()  -- This restores background textures and original tiles
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
        
        CreateStitchFrame()
        CreatePlayerDot()
        
        if LoadTiles(mapType) then
            -- Don't hide native tiles - we're using them!
            addon.stitchFrame:Show()
            Debug("Custom map shown:", mapType)
        else
            Debug("Failed to load tiles for:", mapType)
        end
    else
        -- Same map but ensure tiles are still loaded (in case map was closed/reopened)
        if LoadTiles(mapType) then
            addon.stitchFrame:Show()
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
            -- Only update if we're actually viewing a custom zone
            -- This prevents forcing back to custom map when user browses away
            local mapType = GetCustomMapType()
            if mapType then
                -- We're viewing a custom zone, update it
                C_Timer.After(0.1, UpdateMap)
            elseif addon.currentMap then
                -- We were showing a custom map but user navigated away
                -- Clear it properly
                ClearTiles()
                if addon.stitchFrame then addon.stitchFrame:Hide() end
                if addon.playerDot then addon.playerDot:Hide() end
                addon.currentMap = nil
                Debug("User navigated away from custom map")
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
eventFrame:SetScript("OnUpdate", function(self, elapsed)
    -- Skip entirely if player dot is disabled
    if not DCMapExtensionDB.showPlayerDot then return end
    if not addon.initialized then return end
    if not addon.stitchFrame or not addon.stitchFrame:IsShown() then return end
    
    updateTimer = updateTimer + elapsed
    if updateTimer >= 0.5 then  -- Update 2 times per second
        updateTimer = 0
        UpdatePlayerPosition()
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
    else
        print("|cff33ff99[DC-MapExt]|r Commands:")
        print("  /dcmap show - Enable custom maps")
        print("  /dcmap hide - Disable custom maps")
        print("  /dcmap debug - Toggle debug mode")
        print("  /dcmap status - Show current status")
        print("  /dcmap zone - Show detailed zone info")
        print("  /dcmap reload - Reload current map")
        print("  Or use Interface -> Addons -> DC-MapExtension")
    end
end

print("|cff33ff99[DC-MapExtension]|r Loaded. Type /dcmap for help or use Interface -> Addons")
