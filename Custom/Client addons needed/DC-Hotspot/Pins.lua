local addonName, addonTable = ...
addonTable = addonTable or {}
local Pins = {}
addonTable.Pins = Pins

local Astrolabe = _G.HotspotDisplay_Astrolabe
local Debug = _G.DC_DebugUtils
local DEBUG_FLAG = false

local function DebugPrint(...)
    if Debug and Debug.PrintMulti then
        -- Check state for debug flag
        local enabled = DEBUG_FLAG
        if Pins.state and Pins.state.db and Pins.state.db.debug then
            enabled = true
        end
        Debug:PrintMulti("DC-Hotspot", enabled, ...)
    elseif DEBUG_FLAG and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[DC-Hotspot]|r " .. table.concat({...}, " "))
    end
end

local function ActiveWorldMapId()
    if WorldMapFrame then
        if WorldMapFrame.GetMapID then
            local ok, mapId = pcall(WorldMapFrame.GetMapID, WorldMapFrame)
            if ok and mapId and mapId ~= 0 then
                return mapId
            end
        end
        if WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.GetMapID then
            local ok, mapId = pcall(WorldMapFrame.ScrollContainer.GetMapID, WorldMapFrame.ScrollContainer)
            if ok and mapId and mapId ~= 0 then
                return mapId
            end
        end
        if WorldMapFrame.mapID and WorldMapFrame.mapID ~= 0 then
            return WorldMapFrame.mapID
        end
    end
    if GetCurrentMapAreaID then
        local mapId = GetCurrentMapAreaID()
        if mapId and mapId ~= 0 then
            return mapId
        end
    end
    return nil
end

-- Custom zone map ID to zone ID mapping
-- Some custom zones report different map IDs than their zone IDs
-- IMPORTANT: Must be defined before HotspotMatchesMap function
local CUSTOM_ZONE_MAPPING = {
    [614] = 268,  -- Azshara Crater: WoW reports map 614, but zone is 268
    -- Add more custom zones here as needed
}

-- WoW 3.3.5 Map ID to Zone ID mapping
-- WoW's internal map IDs (GetCurrentMapAreaID) don't match server zone IDs
-- This maps WoW map IDs -> server zone IDs
-- NOTE: In WoW 3.3.5, GetCurrentMapAreaID returns the MapAreaID which is 
-- NOT the same as AreaID/ZoneID that the server uses!
local MAP_TO_ZONE = {
    -- Kalimdor (MapAreaID -> AreaID)
    [41] = 141,   -- Teldrassil (MapAreaID 41 -> AreaID 141)
    [42] = 148,   -- Darkshore
    [43] = 331,   -- Ashenvale  
    [61] = 405,   -- Desolace
    [81] = 400,   -- Thousand Needles
    [101] = 15,   -- Dustwallow Marsh
    [181] = 215,  -- Mulgore
    [321] = 493,  -- Moonglade
    [141] = 16,   -- Azshara
    [161] = 14,   -- Durotar
    [362] = 17,   -- The Barrens (MapAreaID might be different)
    [11] = 17,    -- The Barrens alternate
    [12] = 17,    -- The Barrens (you saw map 12 in logs)
    [14] = 33,    -- Stranglethorn Vale (you saw map 14 in logs)
    [182] = 1637, -- Orgrimmar
    [201] = 357,  -- Feralas
    [241] = 490,  -- Un'Goro Crater
    [261] = 361,  -- Felwood
    [281] = 1377, -- Silithus
    [301] = 440,  -- Tanaris
    [341] = 618,  -- Winterspring
    [381] = 1657, -- Darnassus
    [382] = 406,  -- Stonetalon Mountains
    [9] = 1638,   -- Thunder Bluff
    
    -- Eastern Kingdoms (MapAreaID -> AreaID)
    [1] = 1,      -- Dun Morogh
    [2] = 1537,   -- Ironforge
    [4] = 12,     -- Elwynn Forest
    [5] = 1519,   -- Stormwind City
    [19] = 38,    -- Loch Modan
    [15] = 44,    -- Redridge Mountains
    [13] = 10,    -- Duskwood
    [16] = 40,    -- Westfall
    [17] = 11,    -- Wetlands
    [20] = 85,    -- Tirisfal Glades
    [21] = 130,   -- Silverpine Forest
    [22] = 36,    -- Alterac Mountains
    [23] = 267,   -- Hillsbrad Foothills
    [24] = 47,    -- The Hinterlands
    [26] = 45,    -- Arathi Highlands
    [27] = 3,     -- Badlands
    [28] = 8,     -- Swamp of Sorrows
    [29] = 51,    -- Searing Gorge
    [30] = 46,    -- Burning Steppes
    [32] = 4,     -- Blasted Lands
    [34] = 28,    -- Western Plaguelands
    [35] = 139,   -- Eastern Plaguelands
    [36] = 41,    -- Deadwind Pass
    [37] = 1497,  -- Undercity
    [39] = 1584,  -- Blackrock Mountain
    
    -- Blood Elf / Draenei starting zones
    [462] = 3430, -- Eversong Woods
    [463] = 3433, -- Ghostlands
    [464] = 3487, -- Silvermoon City
    [465] = 3525, -- Bloodmyst Isle
    [466] = 3524, -- Azuremyst Isle
    [467] = 3557, -- The Exodar
    
    -- Outland (MapAreaID -> AreaID)
    [465] = 3483, -- Hellfire Peninsula
    [467] = 3518, -- Nagrand
    [478] = 3519, -- Terokkar Forest
    [473] = 3520, -- Shadowmoon Valley
    [466] = 3521, -- Zangarmarsh
    [475] = 3522, -- Blade's Edge Mountains
    [479] = 3523, -- Netherstorm
    [481] = 3703, -- Shattrath City
    
    -- Northrend (MapAreaID -> AreaID)
    [486] = 3537, -- Borean Tundra
    [488] = 65,   -- Dragonblight
    [490] = 394,  -- Grizzly Hills
    [491] = 495,  -- Howling Fjord
    [492] = 210,  -- Icecrown
    [493] = 3711, -- Sholazar Basin
    [495] = 67,   -- Storm Peaks
    [496] = 66,   -- Zul'Drak
    [504] = 4395, -- Dalaran
    [541] = 4197, -- Wintergrasp
    
    -- Azshara Crater (custom)
    [614] = 268,  -- Azshara Crater
}

-- Reverse mapping: Server zone ID -> WoW map ID (for lookup)
local ZONE_TO_MAP = {}
for mapId, zoneId in pairs(MAP_TO_ZONE) do
    ZONE_TO_MAP[zoneId] = mapId
end

-- Continent map IDs in WoW 3.3.5 (these are the MapAreaIDs for continent-level views)
-- IMPORTANT: GetCurrentMapAreaID returns different IDs than server continent IDs!
-- When viewing the world map at continent level (zoomed out), these are the MapAreaIDs:
local CONTINENT_MAP_IDS = {
    -- WoW 3.3.5 continent view MapAreaIDs
    [-1] = true,   -- Cosmic/World view
    [0] = true,    -- Azeroth (if used)
    [13] = true,   -- Kalimdor continent view (GetCurrentMapAreaID when zoomed out)
    [14] = true,   -- Eastern Kingdoms continent view
    [466] = true,  -- Outland continent view
    [485] = true,  -- Northrend continent view
    -- Also include raw server continent IDs as fallback
    [1] = true,    -- Kalimdor server ID
    [530] = true,  -- Outland server ID  
    [571] = true,  -- Northrend server ID
}

local function HotspotMatchesMap(hotspot, mapId, showAll)
    if not hotspot then return false end
    
    -- If no valid map ID, don't show any pins
    if not mapId or mapId == 0 then
        DebugPrint("No valid mapId - hiding hotspot")
        return false
    end
    
    -- IMPORTANT: Hide pins when viewing continent map (zoomed out)
    -- This check is here as a safety backup - main check is in UpdateWorldPinsInternal
    if CONTINENT_MAP_IDS[mapId] then
        return false
    end
    
    -- If showAll is enabled and we're in a zone view, show all hotspots
    if showAll then
        DebugPrint("Showing hotspot - showAll enabled")
        return true
    end
    
    -- Check if hotspot has data
    local hotspotZone = tonumber(hotspot.zoneId)  -- Zone ID from server
    local hotspotContinent = tonumber(hotspot.map) -- Continent ID from server (0, 1, 530, 571, 37)
    
    if not hotspotZone then
        DebugPrint("Hotspot has no zone data - hiding")
        return false
    end
    
    -- Strategy 1: Convert WoW map ID to zone ID and compare
    local expectedZone = MAP_TO_ZONE[mapId]
    if expectedZone and expectedZone == hotspotZone then
        DebugPrint("Match via MAP_TO_ZONE: map", mapId, "-> zone", expectedZone)
        return true
    end
    
    -- Strategy 2: Check custom zone mappings (for special zones like Azshara Crater)
    local resolvedZoneId = CUSTOM_ZONE_MAPPING[mapId] or mapId
    if hotspotZone == resolvedZoneId then
        DebugPrint("Match via custom mapping: map", mapId, "-> zone", resolvedZoneId)
        return true
    end
    
    -- Strategy 3: Direct match (fallback - some zones might use same ID)
    if hotspotZone == mapId then
        DebugPrint("Direct match: map", mapId, "== zone", hotspotZone)
        return true
    end
    
    -- Don't show pins that don't match - removed the aggressive continent matching
    -- that was showing pins everywhere
    return false
end

local function ResolveTexture(state, hotspot)
    local db = state and state.db
    local style = db and db.pinIconStyle or "xp"
    local custom = db and db.customIconTexture
    if style == "custom" and custom and custom ~= "" then
        return custom
    end
    if style == "xp" then
        -- Experience/bonus themed icons
        return "Interface\\Icons\\Spell_Holy_SurgeOfLight"  -- Golden glowing orb
    elseif style == "star" then
        return "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_1"  -- Yellow star
    elseif style == "diamond" then
        return "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_3"  -- Purple diamond
    elseif style == "circle" then
        return "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_2"  -- Orange circle
    elseif style == "treasure" then
        return "Interface\\Icons\\INV_Misc_Bag_10"  -- Treasure bag
    elseif style == "flame" then
        return "Interface\\Icons\\Spell_Fire_Fire"  -- Fire icon
    elseif style == "arcane" then
        return "Interface\\Icons\\Spell_Arcane_Arcane01"  -- Arcane energy
    elseif style == "target" then
        return "Interface\\Minimap\\Minimap-target"
    elseif style == "skull" then
        return "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_8"
    elseif style == "map" then
        return "Interface\\Icons\\INV_Misc_Map_01"
    elseif style == "quest" then
        return "Interface\\Icons\\INV_Misc_Note_01"  -- Quest note
    end
    if hotspot.tex and hotspot.tex ~= "" then
        return hotspot.tex
    end
    if hotspot.texid and GetSpellTexture then
        local tex = GetSpellTexture(hotspot.texid)
        if tex then return tex end
    end
    if hotspot.icon and GetSpellTexture then
        local tex = GetSpellTexture(hotspot.icon)
        if tex then return tex end
    end
    return "Interface\\Icons\\Spell_Holy_SurgeOfLight"  -- Default to golden orb
end

local function CopyTable(tbl)
    local copy = {}
    for k,v in pairs(tbl) do copy[k] = v end
    return copy
end

local function PlayerNormalizedPosition(state)
    local mapId
    if C_Map and C_Map.GetBestMapForUnit then
        mapId = C_Map.GetBestMapForUnit("player")
        if mapId and C_Map.GetPlayerMapPosition then
            local pos = C_Map.GetPlayerMapPosition(mapId, "player")
            if pos then
                local x, y = pos.x, pos.y
                if x and y and x > 0 and y > 0 then
                    return x, y, mapId
                end
            end
        end
    end
    if GetPlayerMapPosition then
        local worldMapShown = WorldMapFrame and WorldMapFrame:IsShown()
        local lockMap = true
        if state and state.db and state.db.lockWorldMap ~= nil then
            lockMap = state.db.lockWorldMap
        end
        local previousMapId
        local shouldRestore = false
        if SetMapToCurrentZone and (not worldMapShown or not lockMap) then
            if worldMapShown and GetCurrentMapAreaID then
                previousMapId = GetCurrentMapAreaID()
                shouldRestore = true
            end
            SetMapToCurrentZone()
        end
        local x, y = GetPlayerMapPosition("player")
        if shouldRestore and previousMapId and SetMapByID then
            SetMapByID(previousMapId)
        end
        if x and y and x > 0 and y > 0 then
            if GetCurrentMapAreaID then mapId = GetCurrentMapAreaID() end
            if state then state.lastPlayerPos = { x = x, y = y, mapId = mapId } end
            return x, y, mapId
        elseif state and state.lastPlayerPos then
            return state.lastPlayerPos.x, state.lastPlayerPos.y, state.lastPlayerPos.mapId
        end
    end
    return nil
end

local function NormalizeCoords(data)
    -- Lazy-load Astrolabe (might not be loaded when this file loads)
    local Astrolabe = _G.HotspotDisplay_Astrolabe
    
    -- Debug: Check Astrolabe status once
    if not _G.DC_HOTSPOT_ASTRO_CHECK then
        print("|cff00ffff[DC-Hotspot] NormalizeCoords called|r")
        print("  Astrolabe exists: " .. tostring(Astrolabe ~= nil))
        if Astrolabe then
            print("  WorldCoordsToNormalized: " .. tostring(Astrolabe.WorldCoordsToNormalized ~= nil))
            print("  MapBounds: " .. tostring(Astrolabe.MapBounds ~= nil))
            if Astrolabe.MapBounds then
                local count = 0
                for _ in pairs(Astrolabe.MapBounds) do count = count + 1 end
                print("  MapBounds entries: " .. count)
            end
        end
        if data then
            print("  data.map: " .. tostring(data.map))
            print("  data.x: " .. tostring(data.x))
            print("  data.y: " .. tostring(data.y))
        end
        _G.DC_HOTSPOT_ASTRO_CHECK = true
    end
    
    -- Priority 1: Use pre-normalized coordinates if available
    if data.nx and data.ny then
        local nx, ny = tonumber(data.nx), tonumber(data.ny)
        if nx and ny then
            -- Handle percentages (0-100) vs normalized (0-1)
            if nx > 1 then nx = nx / 100 end
            if ny > 1 then ny = ny / 100 end
            return nx, ny
        end
    end
    
    -- Priority 2: Convert world coordinates using Astrolabe
    if data.x and data.y then
        local x = tonumber(data.x)
        local y = tonumber(data.y)
        
        if x and y then
            -- Try Astrolabe conversion with CONTINENT map ID (not zone ID!)
            -- Astrolabe bounds are defined for continents (0, 1, 530, 571, 37)
            if Astrolabe and Astrolabe.WorldCoordsToNormalized and Astrolabe.MapBounds and data.map then
                local mapId = tonumber(data.map)
                if mapId then
                    -- Check if bounds exist for this mapId
                    if not Astrolabe.MapBounds[mapId] then
                        DebugPrint("No map bounds for continent", mapId)
                        -- List what bounds ARE available (once only)
                        if not _G.DC_HOTSPOT_BOUNDS_LOGGED then
                            local available = {}
                            for mid in pairs(Astrolabe.MapBounds) do
                                table.insert(available, tostring(mid))
                            end
                            if #available > 0 then
                                print("|cffff00ff[DC-Hotspot] Available continents: " .. table.concat(available, ", ") .. "|r")
                            else
                                print("|cffff0000[DC-Hotspot] MapBounds table is EMPTY!|r")
                            end
                            _G.DC_HOTSPOT_BOUNDS_LOGGED = true
                        end
                    else
                        local nx, ny = Astrolabe.WorldCoordsToNormalized(mapId, x, y)
                        if nx and ny then
                            return nx, ny
                        else
                            DebugPrint("Astrolabe returned nil for map", mapId, "coords", x, y)
                        end
                    end
                end
            end
            
            -- Fallback: treat as percentage if in reasonable range
            if x > 1 and x <= 100 and y > 1 and y <= 100 then
                return x / 100, y / 100
            end
            
            -- Fallback: already normalized (0-1)
            if x >= 0 and x <= 1 and y >= 0 and y <= 1 then
                return x, y
            end
            
            -- Cannot convert without map bounds
            DebugPrint("Cannot normalize: map=", data.map, "zone=", data.zoneId, "x=", x, "y=", y)
        end
    end
    
    return nil
end

function Pins:Init(state)
    self.state = state
    self.worldPins = {}
    self.minimapPins = {}
    self.minimapUpdate = 0
    self.worldPinUpdate = 0  -- Debounce for world pins
    self.pendingWorldUpdate = false  -- Flag for pending update
    self.lastMapId = nil  -- Track last map to avoid redundant updates
    
    -- Check Astrolabe status
    local Astrolabe = _G.HotspotDisplay_Astrolabe
    if Astrolabe then
        print("|cff00ff00[DC-Hotspot] Astrolabe loaded|r")
        if Astrolabe.MapBounds then
            local count = 0
            for mapId in pairs(Astrolabe.MapBounds) do
                count = count + 1
            end
            print(string.format("|cff00ff00[DC-Hotspot] Map bounds defined for %d continents|r", count))
        else
            print("|cffff0000[DC-Hotspot] ERROR: Astrolabe.MapBounds is nil!|r")
        end
    else
        print("|cffff0000[DC-Hotspot] ERROR: Astrolabe not loaded!|r")
    end

    if WorldMapFrame then
        WorldMapFrame:HookScript("OnShow", function() self:ScheduleWorldPinUpdate() end)
        WorldMapFrame:HookScript("OnSizeChanged", function() self:ScheduleWorldPinUpdate() end)
    end

    self.worldMapWatcher = CreateFrame("Frame")
    self.worldMapWatcher:RegisterEvent("WORLD_MAP_UPDATE")
    self.worldMapWatcher:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    self.worldMapWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.worldMapWatcher:SetScript("OnEvent", function(_, event)
        DebugPrint("Event:", event)
        self:ScheduleWorldPinUpdate()
    end)

    -- Single update frame for both minimap and world map debouncing
    local ticker = CreateFrame("Frame")
    ticker:SetScript("OnUpdate", function(_, elapsed)
        -- Minimap updates
        self.minimapUpdate = self.minimapUpdate + elapsed
        if self.minimapUpdate >= 0.3 then
            self.minimapUpdate = 0
            self:UpdateMinimapPins()
        end
        
        -- World pin debounced updates
        if self.pendingWorldUpdate then
            self.worldPinUpdate = self.worldPinUpdate + elapsed
            if self.worldPinUpdate >= 0.1 then  -- 100ms debounce
                self.worldPinUpdate = 0
                self.pendingWorldUpdate = false
                self:UpdateWorldPinsInternal()
            end
        end
    end)
end

-- Schedule a world pin update with debouncing
function Pins:ScheduleWorldPinUpdate()
    self.pendingWorldUpdate = true
    self.worldPinUpdate = 0  -- Reset timer
end

-- Public method that schedules update (for external calls)
function Pins:UpdateWorldPins()
    self:ScheduleWorldPinUpdate()
end

function Pins:Refresh()
    self.forceUpdate = true  -- Force update even if map hasn't changed
    self.lastMapId = nil  -- Clear cached map ID
    self:ScheduleWorldPinUpdate()
    self:UpdateMinimapPins()
end

function Pins:CountHotspots()
    local count = 0
    if self.state and self.state.hotspots then
        for _ in pairs(self.state.hotspots) do
            count = count + 1
        end
    end
    return count
end

function Pins:DestroyPin(collection, id)
    local pin = collection[id]
    if pin then
        pin:Hide()
        pin:SetScript("OnEnter", nil)
        pin:SetScript("OnLeave", nil)
        pin:SetParent(nil)
        collection[id] = nil
    end
end

function Pins:AcquireWorldPin(id, data)
    local pin = self.worldPins[id]
    if pin then return pin end
    if not WorldMapFrame then return nil end
    local parent = WorldMapButton or (WorldMapFrame and WorldMapFrame.ScrollContainer) or WorldMapFrame
    pin = CreateFrame("Button", "DCHotspotWorldPin" .. id, parent)
    pin:SetSize(26, 26)
    pin.texture = pin:CreateTexture(nil, "OVERLAY")
    pin.texture:SetAllPoints()
    pin:SetFrameStrata("HIGH")
    pin:Hide()
    pin.hotspotId = id
    pin:SetScript("OnEnter", function(self)
        if not Pins.state or not Pins.state.hotspots then return end
        local hs = Pins.state.hotspots[self.hotspotId]
        if not hs then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(string.format("Hotspot #%d", self.hotspotId))
        if hs.zone then GameTooltip:AddLine(hs.zone, 1, 1, 1) end
        if hs.x and hs.y then
            GameTooltip:AddLine(string.format("Coords: %.1f, %.1f", hs.x, hs.y))
        end
        if hs.bonus then
            GameTooltip:AddLine(string.format("XP Bonus: +%d%%", hs.bonus), 0, 1, 0)
        end
        if hs.expire then
            local remain = math.max(0, math.floor(hs.expire - GetTime()))
            GameTooltip:AddLine(string.format("Expires in %ds", remain), 1, 0.82, 0)
        end
        GameTooltip:Show()
    end)
    pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.worldPins[id] = pin
    return pin
end

function Pins:AcquireMinimapPin(id, data)
    local pin = self.minimapPins[id]
    if pin then return pin end
    if not Minimap then return nil end
    pin = CreateFrame("Frame", "DCHotspotMinimapPin" .. id, Minimap)
    pin:SetSize(18, 18)
    pin.texture = pin:CreateTexture(nil, "OVERLAY")
    pin.texture:SetAllPoints()
    pin:SetFrameStrata("HIGH")
    pin:Hide()
    pin.hotspotId = id
    pin:SetScript("OnEnter", function(self)
        if not Pins.state or not Pins.state.hotspots then return end
        local hs = Pins.state.hotspots[self.hotspotId]
        if not hs then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(string.format("Hotspot #%d", self.hotspotId))
        if hs.zone then GameTooltip:AddLine(hs.zone, 1, 1, 1) end
        GameTooltip:Show()
    end)
    pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.minimapPins[id] = pin
    return pin
end

-- Internal function that actually updates the pins (called via debounce)
function Pins:UpdateWorldPinsInternal()
    local db = self.state.db
    if not db or not db.showWorldPins or not WorldMapFrame then
        -- Hide all pins if world pins are disabled
        for id, pin in pairs(self.worldPins) do
            pin:Hide()
        end
        return
    end

    local activeMapId = ActiveWorldMapId()
    
    -- Skip redundant updates if map hasn't changed
    if activeMapId == self.lastMapId and not self.forceUpdate then
        return
    end
    self.lastMapId = activeMapId
    self.forceUpdate = nil
    
    local seen = {}
    local visibleCount = 0
    local showAll = db and db.showAllMaps
    
    DebugPrint("UpdateWorldPins: Processing", self:CountHotspots(), "hotspots for map", activeMapId)
    
    -- Check if we're in continent view - hide all pins
    if CONTINENT_MAP_IDS[activeMapId] then
        DebugPrint("Continent view detected (mapId", activeMapId, ") - hiding all pins")
        for id, pin in pairs(self.worldPins) do
            pin:Hide()
        end
        return
    end
    
    for id, hotspot in pairs(self.state.hotspots) do
        local pin = self:AcquireWorldPin(id, hotspot)
        if pin then
            local matches = HotspotMatchesMap(hotspot, activeMapId, showAll)
            
            if not matches then
                pin:Hide()
            else
                local nx, ny = NormalizeCoords(hotspot)
                if nx and ny then
                    visibleCount = visibleCount + 1
                    DebugPrint("Showing hotspot", id, "on map", activeMapId, "- coords:", nx, ny)
                    local parent = WorldMapButton or (WorldMapFrame and WorldMapFrame.ScrollContainer) or WorldMapFrame
                    if parent then
                        local px, py
                        if Astrolabe and Astrolabe.WorldToMapPixels then
                            px, py = Astrolabe.WorldToMapPixels(parent, nx, ny)
                        else
                            local width = parent:GetWidth()
                            local height = parent:GetHeight()
                            px = nx * width
                            py = ny * height
                        end

                        pin:ClearAllPoints()
                        pin:SetPoint("CENTER", parent, "TOPLEFT", px, -py)

                        -- Set pin texture
                        local texture = ResolveTexture(self.state, hotspot)
                        pin.texture:SetTexture(texture)

                        if db.showWorldLabels and not pin.label then
                            pin.label = pin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                            pin.label:SetPoint("TOP", pin, "BOTTOM", 0, -2)
                            pin.label:SetTextColor(1, 0.84, 0)
                        end
                        if pin.label then
                            local bonusText = hotspot.bonus and ("+" .. hotspot.bonus .. "% XP") or "XP"
                            pin.label:SetText(bonusText)
                            if db.showWorldLabels then
                                pin.label:Show()
                            else
                                pin.label:Hide()
                            end
                        end

                        pin:Show()
                        seen[id] = true
                    else
                        pin:Hide()
                    end
                else
                    pin:Hide()
                end
            end
        end
    end

    DebugPrint("UpdateWorldPins: Map", activeMapId, "- Showing", visibleCount, "of", self:CountHotspots(), "pins")

    -- Hide or destroy pins for hotspots that no longer exist or don't match the map
    for id, pin in pairs(self.worldPins) do
        if not seen[id] then
            if not self.state.hotspots[id] then
                -- Hotspot was removed (expired), destroy the pin
                DebugPrint("Destroying world pin for removed hotspot", id)
                self:DestroyPin(self.worldPins, id)
            else
                -- Hotspot exists but doesn't match current map, just hide
                pin:Hide()
            end
        end
    end
end

function Pins:UpdateMinimapPins()
    local db = self.state.db
    if not db or not db.showMinimapPins or not Minimap then
        for id in pairs(self.minimapPins) do self:DestroyPin(self.minimapPins, id) end
        return
    end

    local px, py, playerMap = PlayerNormalizedPosition(self.state)
    if not px or not py then
        for _, pin in pairs(self.minimapPins) do pin:Hide() end
        return
    end

    local seen = {}
    for id, hotspot in pairs(self.state.hotspots) do
        if not playerMap or not hotspot.map or tonumber(hotspot.map) == tonumber(playerMap) then
            local targetNx, targetNy = NormalizeCoords(hotspot)
            if targetNx and targetNy then
                local offsetX, offsetY
                if Astrolabe and Astrolabe.WorldToMinimapOffset then
                    offsetX, offsetY = Astrolabe.WorldToMinimapOffset(Minimap, px, py, targetNx, targetNy)
                else
                    offsetX = (targetNx - px) * Minimap:GetWidth()
                    offsetY = (py - targetNy) * Minimap:GetHeight()
                end
                local pin = self:AcquireMinimapPin(id, hotspot)
                if pin then
                    pin.texture:SetTexture(ResolveTexture(self.state, hotspot))
                    pin:ClearAllPoints()
                    pin:SetPoint("CENTER", Minimap, "CENTER", offsetX, offsetY)
                    pin:Show()
                    seen[id] = true
                end
            end
        end
    end

    for id, pin in pairs(self.minimapPins) do
        if not seen[id] then pin:Hide() end
    end
end

return Pins
