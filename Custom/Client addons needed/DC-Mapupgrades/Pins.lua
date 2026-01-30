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
        Debug:PrintMulti("DC-Mapupgrades", enabled, ...)
    elseif DEBUG_FLAG and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[DC-Mapupgrades]|r " .. table.concat({...}, " "))
    end
end


-- Custom zone map ID to zone ID mapping
-- Some custom zones report different map IDs than their zone IDs
-- IMPORTANT: Must be defined before HotspotMatchesMap function
local CUSTOM_ZONE_MAPPING = {
    [614] = 268,  -- Azshara Crater: WoW reports map 614, but zone is 268
    [1405] = 5006, -- Slippy Quagmire (custom): client MapAreaID 1405, server zoneId 5006
    -- Slippy Quagmire / Isles of Giants (custom): clients may report any of these map IDs depending on UI / floors
    [1100] = 5006,
    [1101] = 5006,
    [1102] = 5006,
    [745] = 745, -- Jade Forest (Explicit mapping to prevent incorrect learning)
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
-- NOTE: Do NOT include 0, 1, 530, 571 here - those are server continent IDs in hotspot.map,
--       NOT client MapAreaIDs returned by GetCurrentMapAreaID()
local CONTINENT_MAP_IDS = {
    -- WoW 3.3.5 continent view MapAreaIDs
    [-1] = true,   -- Cosmic/World view
    [13] = true,   -- Kalimdor continent view (GetCurrentMapAreaID when zoomed out)
    [14] = true,   -- Eastern Kingdoms continent view
    [466] = true,  -- Outland continent view
    [485] = true,  -- Northrend continent view
}

local function NowEpoch()
    if GetServerTime then
        return GetServerTime()
    end
    return time()
end

local function NormalizeZoneNameForMatch(name)
    if not name then return nil end
    name = tostring(name)
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then return nil end
    return name:lower()
end

local function CustomZoneForMap(mapId)
    local custom = CUSTOM_ZONE_MAPPING[mapId]
    if not custom then return nil end

    -- Avoid mapping Jade Forest client maps to Giant Isles zoneId.
    if mapId == 1100 or mapId == 1101 or mapId == 1102 then
        local zoneText = nil
        if GetRealZoneText then
            zoneText = GetRealZoneText()
        end
        if (not zoneText or zoneText == "") and GetZoneText then
            zoneText = GetZoneText()
        end
        local normZone = NormalizeZoneNameForMatch(zoneText)
        if normZone and string.find(normZone, "jade forest", 1, true) then
            return nil
        end

        if GetMapNameByID then
            local name = NormalizeZoneNameForMatch(GetMapNameByID(mapId))
            if name and string.find(name, "jade forest", 1, true) then
                return nil
            end
        end
    end

    return custom
end

-- Some custom maps can report inconsistent IDs; allow name-based blacklist checks.
local BOSS_BLACKLIST_MAP_NAMES = {
    ["jade forest"] = true,
}

local function MapNameIsBlacklisted(mapId)
    if not mapId or not GetMapNameByID then return false end
    local name = GetMapNameByID(mapId)
    local normalized = NormalizeZoneNameForMatch(name)
    return normalized and BOSS_BLACKLIST_MAP_NAMES[normalized] or false
end

local function IsBossBlacklistedMap(activeMapId)
    local db = Pins.state and Pins.state.db
    if not db or not db.bossBlacklistMaps then return false end

    if activeMapId and db.bossBlacklistMaps[activeMapId] then
        return true
    end
    if MapNameIsBlacklisted(activeMapId) then
        return true
    end

    if GetCurrentMapAreaID then
        local cur = GetCurrentMapAreaID()
        if cur and db.bossBlacklistMaps[cur] then
            return true
        end
        if MapNameIsBlacklisted(cur) then
            return true
        end
    end

    if WorldMapFrame then
        if WorldMapFrame.GetMapID then
            local ok, mapId = pcall(WorldMapFrame.GetMapID, WorldMapFrame)
            if ok and mapId then
                if db.bossBlacklistMaps[mapId] or MapNameIsBlacklisted(mapId) then
                    return true
                end
            end
        end
        if WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.GetMapID then
            local ok, mapId = pcall(WorldMapFrame.ScrollContainer.GetMapID, WorldMapFrame.ScrollContainer)
            if ok and mapId then
                if db.bossBlacklistMaps[mapId] or MapNameIsBlacklisted(mapId) then
                    return true
                end
            end
        end
        if WorldMapFrame.mapID then
            local mapId = WorldMapFrame.mapID
            if db.bossBlacklistMaps[mapId] or MapNameIsBlacklisted(mapId) then
                return true
            end
        end
    end

    return false
end

local function MaybeLearnZoneMapping(state, activeMapId, zoneId, zoneLabel)
    local db = state and state.db
    if not db or not activeMapId or not zoneId or not zoneLabel then return end
    if CONTINENT_MAP_IDS and CONTINENT_MAP_IDS[activeMapId] then return end

    db.customZoneMapping = db.customZoneMapping or {}
    if db.customZoneMapping[activeMapId] then return end

    -- Do not learn over static known mappings
    if CustomZoneForMap(activeMapId) then return end
    if MAP_TO_ZONE[activeMapId] then return end

    local curZone = (GetZoneText and GetZoneText()) or nil
    if not curZone or curZone == "" then return end

    if NormalizeZoneNameForMatch(curZone) == NormalizeZoneNameForMatch(zoneLabel) then
        db.customZoneMapping[activeMapId] = tonumber(zoneId)
        DebugPrint("Learned custom map mapping:", tostring(activeMapId), "->", tostring(zoneId), "(zone:", tostring(zoneLabel) .. ")")
    end
end

local function EntityTexture(kind)
    if kind == "boss" then
        return "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_8" -- Skull
    end
    if kind == "rare" then
        return "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_1" -- Star
    end
    if kind == "death" then
        return "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_7" -- X
    end
    return "Interface\\Icons\\INV_Misc_Map_01"
end

local function EntityIsActive(state, entityId)
    local db = state and state.db
    if not db or type(db.entityStatus) ~= "table" then
        return false
    end
    local st = db.entityStatus[entityId]
    if st and st.serverActive ~= nil then
        return st.serverActive == true
    end
    if not st or not st.activeUntil then
        return false
    end
    return tonumber(st.activeUntil) and tonumber(st.activeUntil) > NowEpoch()
end

local function FormatDuration(seconds)
    seconds = tonumber(seconds)
    if not seconds or seconds < 0 then
        return nil
    end
    local s = math.floor(seconds)
    local h = math.floor(s / 3600)
    local m = math.floor((s % 3600) / 60)
    local sec = math.floor(s % 60)
    if h > 0 then
        return string.format("%dh %dm %ds", h, m, sec)
    end
    if m > 0 then
        return string.format("%dm %ds", m, sec)
    end
    return string.format("%ds", sec)
end

local CLASS_ID_TO_NAME = {
    [1] = "Warrior",
    [2] = "Paladin",
    [3] = "Hunter",
    [4] = "Rogue",
    [5] = "Priest",
    [6] = "Death Knight",
    [7] = "Shaman",
    [8] = "Mage",
    [9] = "Warlock",
    [11] = "Druid",
}

local function SafeClassName(classId)
    classId = tonumber(classId)
    return (classId and CLASS_ID_TO_NAME[classId]) or (classId and ("Class " .. tostring(classId))) or "Unknown"
end

local function PlayerCanGainXP()
    if not UnitXPMax then
        return true
    end
    local xpMax = UnitXPMax("player")
    -- On some servers (e.g., custom max level 255), the client can report 0 max XP at
    -- cap, which would incorrectly hide all hotspot pins.
    if xpMax == 0 then
        return true
    end
    if IsXPUserDisabled and IsXPUserDisabled() then
        return false
    end
    return xpMax and xpMax > 0
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
    end
    if GetCurrentMapAreaID then
        local mapId = GetCurrentMapAreaID()
        if mapId and mapId ~= 0 then
            return mapId
        end
    end
    -- Some client builds expose WorldMapFrame.mapID but (depending on UI/mods)
    -- it can resolve to continent/world IDs (e.g. 1/571) even when zoomed into a zone.
    -- Only use it as a last resort.
    if WorldMapFrame and WorldMapFrame.mapID and WorldMapFrame.mapID ~= 0 then
        return WorldMapFrame.mapID
    end
    return nil
end


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
    local db = Pins.state and Pins.state.db
    local learned = db and db.customZoneMapping and db.customZoneMapping[mapId]
    local resolvedZoneId = learned or CustomZoneForMap(mapId) or mapId
    if hotspotZone == resolvedZoneId then
        DebugPrint("Match via custom mapping: map", mapId, "-> zone", resolvedZoneId)
        return true
    end
    
    -- Strategy 3: Direct match (fallback - some zones might use same ID)
    if hotspotZone == mapId then
        DebugPrint("Direct match: map", mapId, "== zone", hotspotZone)
        return true
    end

    -- Strategy 4: Name-based match (fallback)
    -- Some servers send zone IDs that don't line up with our MAP_TO_ZONE table.
    -- If the hotspot's resolved zone label matches the client map name for the
    -- currently viewed map, treat it as a match.
    if hotspot.zone and GetMapNameByID then
        local mapName = GetMapNameByID(mapId)
        if mapName and mapName ~= "" then
            local a = string.lower(tostring(hotspot.zone))
            local b = string.lower(tostring(mapName))
            if a == b then
                DebugPrint("Match via name: map", mapId, "name", mapName)
                return true
            end
        end
    end
    
    -- Don't show pins that don't match - removed the aggressive continent matching
    -- that was showing pins everywhere
    return false
end

local function EntityMatchesMap(entity, activeMapId, showAll)
    if not entity then return false end
    if not activeMapId or activeMapId == 0 then return false end
    if CONTINENT_MAP_IDS[activeMapId] then return false end
    
    -- Check blacklist for boss/death entities
    if (entity.kind == "boss" or entity.kind == "death") and IsBossBlacklistedMap(activeMapId) then
        return false
    end
    
    if showAll then return true end

    local entMapId = tonumber(entity.mapId)
    if not entMapId then return false end

    -- Server-provided entities (bosses/deaths) use server zone/area ID in mapId.
    if entity.kind == "boss" or entity.kind == "death" then
        local db = Pins.state and Pins.state.db
        -- Block by server map/zone id directly if blacklisted
        if db and db.bossBlacklistMaps and db.bossBlacklistMaps[entMapId] then
            return false
        end
        local learned = db and db.customZoneMapping and db.customZoneMapping[activeMapId]

        -- First check: Try to match via MAP_TO_ZONE lookup
        local expectedZone = MAP_TO_ZONE[activeMapId]
        if expectedZone and expectedZone == entMapId then
            return true
        end

        -- Second check: Try custom zone mapping (for non-standard maps like Azshara Crater)
        local customZone = CustomZoneForMap(activeMapId)
        if customZone and customZone == entMapId then
            return true
        end

        -- Third check: Try runtime learned mapping
        if learned and learned == entMapId then
            return true
        end

        -- Fourth check: Direct match only for unknown zones AND when zone name matches
        -- This prevents false positives when map IDs overlap unrelated zones.
        if not expectedZone and not customZone and entMapId == activeMapId then
            local mapName = (GetMapNameByID and GetMapNameByID(activeMapId))
            local zoneName = mapName or (GetZoneText and GetZoneText()) or nil
            if entity.zoneLabel and zoneName then
                if NormalizeZoneNameForMatch(entity.zoneLabel) == NormalizeZoneNameForMatch(zoneName) then
                    return true
                end
            else
                return true
            end
        end

        return false
    end

    -- Manual entities (e.g., rares) store client mapId directly.
    return entMapId == tonumber(activeMapId)
end

local function ResolveTexture(state, hotspot)
    local db = state and state.db
    local style = db and db.pinIconStyle or "xp"
    local custom = db and db.customIconTexture
    if style == "custom" and custom and custom ~= "" then
        return custom
    end
    if style == "xp" then
        -- Experience/bonus themed icon (default)
        -- Stored in this addon: Interface\AddOns\DC-Mapupgrades\Textures\MapIcons\Simple_XP\Icon_64.tga
        return "Interface\\AddOns\\DC-Mapupgrades\\Textures\\MapIcons\\Simple_XP\\Icon_64"
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
    return "Interface\\AddOns\\DC-Mapupgrades\\Textures\\MapIcons\\Simple_XP\\Icon_64"
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
        local previousMapId
        local shouldRestore = false
        -- Never change the viewed world map while it is open.
        -- In WoW 3.3.5, GetPlayerMapPosition() often requires the internal map state to be set
        -- to the player's current zone; we do that ONLY when the world map is closed.
        if SetMapToCurrentZone and not worldMapShown then
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
    self.entityWorldPins = {}
    self.entityMinimapPins = {}
    self.minimapUpdate = 0
    self.worldPinUpdate = 0  -- Debounce for world pins
    self.pendingWorldUpdate = false  -- Flag for pending update
    self.lastMapId = nil  -- Track last map to avoid redundant updates
    
    -- Check Astrolabe status
    local Astrolabe = _G.HotspotDisplay_Astrolabe
    if Astrolabe then
        print("|cff00ff00[DC-Mapupgrades] Astrolabe loaded|r")
        if Astrolabe.MapBounds then
            local count = 0
            for mapId in pairs(Astrolabe.MapBounds) do
                count = count + 1
            end
            print(string.format("|cff00ff00[DC-Mapupgrades] Map bounds defined for %d continents|r", count))
        else
            print("|cffff0000[DC-Mapupgrades] ERROR: Astrolabe.MapBounds is nil!|r")
        end
    else
        print("|cffff0000[DC-Mapupgrades] ERROR: Astrolabe not loaded!|r")
    end

    -- Retry logic for map open: sometimes MapID is not ready immediately (especially with Mapster/Carbonite)
    local function RetryMapCheck()
        if not WorldMapFrame:IsShown() then return end
        local mapId = ActiveWorldMapId()
        if mapId and mapId > 0 then
            Pins.forceUpdate = true
            Pins.lastMapId = nil
            Pins:ScheduleWorldPinUpdate()
        end
    end

    if WorldMapFrame then
        WorldMapFrame:HookScript("OnShow", function() 
            self.forceUpdate = true
            self.lastMapId = nil
            self:ScheduleWorldPinUpdate() 
            
            -- Check again in 0.2, 0.5, and 1.0 seconds to catch delayed initialization
            C_Timer.After(0.2, RetryMapCheck)
            C_Timer.After(0.5, RetryMapCheck)
            C_Timer.After(1.0, RetryMapCheck)
        end)
        WorldMapFrame:HookScript("OnSizeChanged", function() self:ScheduleWorldPinUpdate() end)
    end

    self.worldMapWatcher = CreateFrame("Frame")
    self.worldMapWatcher:RegisterEvent("WORLD_MAP_UPDATE")
    self.worldMapWatcher:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    self.worldMapWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.worldMapWatcher:RegisterEvent("PLAYER_LEVEL_UP")
    self.worldMapWatcher:RegisterEvent("PLAYER_XP_UPDATE")
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

function Pins:AcquireEntityWorldPin(id, entity)
    local pin = self.entityWorldPins[id]
    if pin then return pin end
    if not WorldMapFrame then return nil end
    local parent = WorldMapButton or (WorldMapFrame and WorldMapFrame.ScrollContainer) or WorldMapFrame
    pin = CreateFrame("Button", "DCMapupgradesEntityWorldPin" .. id, parent)
    pin:SetSize(22, 22)
    pin.texture = pin:CreateTexture(nil, "OVERLAY")
    pin.texture:SetAllPoints()
    pin:SetFrameStrata("HIGH")
    pin:Hide()
    pin.entityId = id
    pin:SetScript("OnEnter", function(self)
        local db = Pins.state and Pins.state.db
        local list = db and db.entities and db.entities.list
        if type(list) ~= "table" then return end
        local ent
        for _, e in ipairs(list) do
            if e and e.id == self.entityId then ent = e break end
        end
        if not ent then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        if ent.kind == "death" then
            GameTooltip:AddLine(ent.name or ("Death #" .. tostring(self.entityId)))
            GameTooltip:AddLine("Death Marker", 0.85, 0.7, 0.7)

            if ent.modeLabel and ent.modeLabel ~= "" then
                GameTooltip:AddLine("Mode: " .. tostring(ent.modeLabel), 0.9, 0.9, 0.9)
            end

            local victim = ent.victimName or "Unknown"
            local level = tonumber(ent.victimLevel)
            local className = SafeClassName(ent.victimClass)
            if level then
                GameTooltip:AddLine(string.format("Victim: %s (Lv %d %s)", tostring(victim), level, className), 1, 1, 1)
            else
                GameTooltip:AddLine(string.format("Victim: %s (%s)", tostring(victim), className), 1, 1, 1)
            end

            local kt = tostring(ent.killerType or "unknown")
            if kt == "creature" then
                local kName = ent.killerName or "Creature"
                if ent.killerEntry then
                    GameTooltip:AddLine(string.format("Killed by: %s (entry %s)", tostring(kName), tostring(ent.killerEntry)), 0.95, 0.95, 0.95)
                else
                    GameTooltip:AddLine("Killed by: " .. tostring(kName), 0.95, 0.95, 0.95)
                end
            elseif kt == "player" then
                local kName = ent.killerName or "Player"
                GameTooltip:AddLine("Killed by: " .. tostring(kName), 0.95, 0.95, 0.95)
            elseif kt == "environment" then
                GameTooltip:AddLine("Killed by: Environment", 0.95, 0.95, 0.95)
            else
                GameTooltip:AddLine("Killed by: Unknown", 0.95, 0.95, 0.95)
            end

            local now = NowEpoch()
            local diedAt = tonumber(ent.diedAt)
            local expiresAt = tonumber(ent.expiresAt)
            if diedAt then
                local ago = FormatDuration(now - diedAt)
                if ago then
                    GameTooltip:AddLine("Died: " .. ago .. " ago", 1, 0.82, 0)
                end
            end
            if expiresAt then
                local remaining = FormatDuration(expiresAt - now)
                if remaining then
                    GameTooltip:AddLine("Expires in: " .. remaining, 1, 0.82, 0)
                end
            end
        else
            local kindLabel = (ent.kind == "boss" and "World Boss") or (ent.kind == "rare" and "Rare") or "Entity"
            GameTooltip:AddLine(ent.name or (kindLabel .. " #" .. tostring(self.entityId)))
            GameTooltip:AddLine(kindLabel, 0.7, 0.7, 0.9)

            if ent.spawnId then
                GameTooltip:AddLine(string.format("spawnId: %s", tostring(ent.spawnId)), 0.9, 0.9, 0.9)
            end
            if ent.entry then
                GameTooltip:AddLine(string.format("entry: %s", tostring(ent.entry)), 0.9, 0.9, 0.9)
            end
            if ent.zoneLabel then
                GameTooltip:AddLine(string.format("zone: %s", tostring(ent.zoneLabel)), 0.9, 0.9, 0.9)
            end

            local st = Pins.state and Pins.state.db and Pins.state.db.entityStatus and Pins.state.db.entityStatus[self.entityId]
            if st and st.serverStatus and st.serverStatus ~= "" then
                local serverStatus = string.upper(tostring(st.serverStatus))
                if serverStatus == "ACTIVE" then
                    GameTooltip:AddLine("Status: ACTIVE", 0, 1, 0)
                elseif serverStatus == "SPAWNING" then
                    local durText = FormatDuration(st.serverSpawnIn)
                    if durText then
                        GameTooltip:AddLine("Status: SPAWNING", 1, 0.82, 0)
                        GameTooltip:AddLine("Respawn in: " .. durText, 1, 0.82, 0)
                    else
                        GameTooltip:AddLine("Status: SPAWNING", 1, 0.82, 0)
                    end
                else
                    GameTooltip:AddLine("Status: " .. serverStatus, 1, 0.82, 0)
                end
            else
                local active = EntityIsActive(Pins.state, self.entityId)
                if active then
                    GameTooltip:AddLine("Status: ACTIVE", 0, 1, 0)
                else
                    GameTooltip:AddLine("Status: inactive", 1, 0.82, 0)
                end
            end
        end
        local db2 = Pins.state and Pins.state.db
        if db2 and db2.debug and ent.mapId then
            GameTooltip:AddLine(string.format("MapId: %s", tostring(ent.mapId)), 0.75, 0.75, 0.75)
        end
        if ent.nx and ent.ny then
            GameTooltip:AddLine(string.format("Pos: %.3f, %.3f", ent.nx, ent.ny), 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.entityWorldPins[id] = pin
    return pin
end

function Pins:AcquireEntityMinimapPin(id, entity)
    local pin = self.entityMinimapPins[id]
    if pin then return pin end
    if not Minimap then return nil end
    pin = CreateFrame("Button", "DCMapupgradesEntityMinimapPin" .. id, Minimap)
    pin:SetSize(16, 16)
    pin.texture = pin:CreateTexture(nil, "OVERLAY")
    pin.texture:SetAllPoints()
    pin:SetFrameStrata("HIGH")
    pin:Hide()
    pin.entityId = id
    pin:EnableMouse(true)
    pin:SetScript("OnEnter", function(self)
        local db = Pins.state and Pins.state.db
        local list = db and db.entities and db.entities.list
        if type(list) ~= "table" then return end
        local ent
        for _, e in ipairs(list) do
            if e and e.id == self.entityId then ent = e break end
        end
        if not ent then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        if ent.kind == "death" then
            GameTooltip:AddLine(ent.name or ("Death #" .. tostring(self.entityId)))
            GameTooltip:AddLine("Death Marker", 0.85, 0.7, 0.7)
        else
            local kindLabel = (ent.kind == "boss" and "World Boss") or (ent.kind == "rare" and "Rare") or "Entity"
            GameTooltip:AddLine(ent.name or (kindLabel .. " #" .. tostring(self.entityId)))
            GameTooltip:AddLine(kindLabel, 0.7, 0.7, 0.9)
        end

        if ent.spawnId then
            GameTooltip:AddLine(string.format("spawnId: %s", tostring(ent.spawnId)), 0.9, 0.9, 0.9)
        end
        if ent.entry then
            GameTooltip:AddLine(string.format("entry: %s", tostring(ent.entry)), 0.9, 0.9, 0.9)
        end
        if ent.zoneLabel then
            GameTooltip:AddLine(string.format("zone: %s", tostring(ent.zoneLabel)), 0.9, 0.9, 0.9)
        end

        local st = Pins.state and Pins.state.db and Pins.state.db.entityStatus and Pins.state.db.entityStatus[self.entityId]
        if st and st.serverStatus and st.serverStatus ~= "" then
            local serverStatus = string.upper(tostring(st.serverStatus))
            if serverStatus == "ACTIVE" then
                GameTooltip:AddLine("Status: ACTIVE", 0, 1, 0)
            elseif serverStatus == "SPAWNING" then
                local durText = FormatDuration(st.serverSpawnIn)
                if durText then
                    GameTooltip:AddLine("Status: SPAWNING", 1, 0.82, 0)
                    GameTooltip:AddLine("Respawn in: " .. durText, 1, 0.82, 0)
                else
                    GameTooltip:AddLine("Status: SPAWNING", 1, 0.82, 0)
                end
            else
                GameTooltip:AddLine("Status: " .. serverStatus, 1, 0.82, 0)
            end
        end

        local db2 = Pins.state and Pins.state.db
        if db2 and db2.debug and ent.mapId then
            GameTooltip:AddLine(string.format("MapId: %s", tostring(ent.mapId)), 0.75, 0.75, 0.75)
        end
        if ent.nx and ent.ny then
            GameTooltip:AddLine(string.format("Pos: %.3f, %.3f", ent.nx, ent.ny), 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.entityMinimapPins[id] = pin
    return pin
end

function Pins:AcquireWorldPin(id, data)
    local pin = self.worldPins[id]
    if pin then return pin end
    if not WorldMapFrame then return nil end
    local parent = WorldMapButton or (WorldMapFrame and WorldMapFrame.ScrollContainer) or WorldMapFrame
    pin = CreateFrame("Button", "DCMapupgradesWorldPin" .. id, parent)
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
    pin = CreateFrame("Frame", "DCMapupgradesMinimapPin" .. id, Minimap)
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
    if not db or not db.showWorldPins or not WorldMapFrame or (WorldMapFrame.IsShown and not WorldMapFrame:IsShown()) then
        -- Hide all pins if world pins are disabled
        for id, pin in pairs(self.worldPins) do
            pin:Hide()
        end
        for id, pin in pairs(self.entityWorldPins) do
            pin:Hide()
        end
        return
    end

    local activeMapId = ActiveWorldMapId()
    
    -- Don't skip update if mapId is nil (map not ready yet) - wait for valid map
    if activeMapId and activeMapId == self.lastMapId and not self.forceUpdate then
        return
    end
    -- If no valid map ID yet, clear lastMapId so next update with valid ID will proceed
    if not activeMapId then
        self.lastMapId = nil
        return
    end
    self.lastMapId = activeMapId
    self.forceUpdate = nil
    
    local seen = {}
    local visibleCount = 0
    -- NOTE: showAllMaps is a debug/testing option intended for XP hotspots only.
    -- Applying it to entity pins (world bosses/rares) makes them show on unrelated maps.
    local showAllHotspots = db and db.showAllMaps

    local dbgNoMatch, dbgNoCoords, dbgNoParent, dbgGated = 0, 0, 0, 0
    local dbgSample
    local dbgNoMatchSample
    
    DebugPrint("UpdateWorldPins: Processing", self:CountHotspots(), "hotspots for map", activeMapId)
    
    -- Check if we're in continent view - hide all pins
    if CONTINENT_MAP_IDS[activeMapId] then
        DebugPrint("Continent view detected (mapId", activeMapId, ") - hiding all pins")
        for id, pin in pairs(self.worldPins) do
            pin:Hide()
        end
        for id, pin in pairs(self.entityWorldPins) do
            pin:Hide()
        end
        return
    end

    local canShowHotspots = PlayerCanGainXP()
    if db.debug and self._dbgXpGateMapId ~= activeMapId then
        self._dbgXpGateMapId = activeMapId
        local xpMax = UnitXPMax and UnitXPMax("player") or nil
        local xpDisabled = (IsXPUserDisabled and IsXPUserDisabled()) or false
        DebugPrint("Hotspot gate:", "xpMax=" .. tostring(xpMax), "xpDisabled=" .. tostring(xpDisabled), "canShowHotspots=" .. tostring(canShowHotspots))
    end
    
    for id, hotspot in pairs(self.state.hotspots) do
        local pin = self:AcquireWorldPin(id, hotspot)
        if pin then
            if not canShowHotspots then
                dbgGated = dbgGated + 1
                pin:Hide()
            else
                local matches = HotspotMatchesMap(hotspot, activeMapId, showAllHotspots)
            
                if not matches then
                    dbgNoMatch = dbgNoMatch + 1
                    if db.debug and not dbgNoMatchSample then
                        local expectedZone = MAP_TO_ZONE and MAP_TO_ZONE[activeMapId]
                        local learned = db and db.customZoneMapping and db.customZoneMapping[activeMapId]
                        local resolvedZoneId = learned or CUSTOM_ZONE_MAPPING[activeMapId] or activeMapId
                        local mapName = (GetMapNameByID and GetMapNameByID(activeMapId)) or nil
                        dbgNoMatchSample = {
                            id = id,
                            hotspotZoneId = hotspot and hotspot.zoneId,
                            hotspotMap = hotspot and hotspot.map,
                            hotspotZone = hotspot and hotspot.zone,
                            activeMapId = activeMapId,
                            activeMapName = mapName,
                            expectedZone = expectedZone,
                            resolvedZoneId = resolvedZoneId,
                        }
                    end
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
                            dbgNoParent = dbgNoParent + 1
                            pin:Hide()
                        end
                    else
                        dbgNoCoords = dbgNoCoords + 1
                        if db.debug and not dbgSample then
                            dbgSample = {
                                id = id,
                                zoneId = hotspot and hotspot.zoneId,
                                map = hotspot and hotspot.map,
                                x = hotspot and hotspot.x,
                                y = hotspot and hotspot.y,
                                nx = hotspot and hotspot.nx,
                                ny = hotspot and hotspot.ny,
                                zone = hotspot and hotspot.zone,
                            }
                        end
                        pin:Hide()
                    end
                end
            end
        end
    end

    -- Entities (world bosses / rares)
    if IsBossBlacklistedMap(activeMapId) then
        for id, pin in pairs(self.entityWorldPins) do
            pin:Hide()
        end
        DebugPrint("Entities: skipped due to boss blacklist map")
        DebugPrint("UpdateWorldPins: Map", activeMapId, "- Showing", visibleCount, "of", self:CountHotspots(), "pins")
        return
    end

    local entSeen = {}
    local list = db.entities and db.entities.list
    if type(list) == "table" then
        local parent = WorldMapButton or (WorldMapFrame and WorldMapFrame.ScrollContainer) or WorldMapFrame
        local totalEntities, missingPos = 0, 0
        local totalBoss, enabledBoss, matchedBoss, shownBoss = 0, 0, 0, 0
        local sampleBoss
        local dbgBossDetailsCount = 0
        local learnedActive = db and db.customZoneMapping and db.customZoneMapping[activeMapId]
        local resolvedZoneId = learnedActive or CustomZoneForMap(activeMapId) or MAP_TO_ZONE[activeMapId] or activeMapId
        for _, ent in ipairs(list) do
            if ent and ent.id then
                totalEntities = totalEntities + 1
            end
            if ent and ent.id and ent.mapId and ent.nx and ent.ny then
                local kind = ent.kind

                if (kind == "boss" or kind == "death") and ent.zoneLabel and activeMapId then
                    MaybeLearnZoneMapping(self.state, activeMapId, ent.mapId, ent.zoneLabel)
                    learnedActive = db and db.customZoneMapping and db.customZoneMapping[activeMapId]
                    resolvedZoneId = learnedActive or CustomZoneForMap(activeMapId) or MAP_TO_ZONE[activeMapId] or activeMapId
                end

                local enabled = (kind == "boss" and db.showWorldBossPins) or (kind == "rare" and db.showRarePins) or (kind == "death")
                if kind == "boss" then
                    totalBoss = totalBoss + 1
                    if enabled then
                        enabledBoss = enabledBoss + 1
                    end
                end

                if db.debug and kind == "boss" and dbgBossDetailsCount < 10 then
                    dbgBossDetailsCount = dbgBossDetailsCount + 1
                    local mapName = (GetMapNameByID and GetMapNameByID(activeMapId)) or "nil"
                    local curMap = GetCurrentMapAreaID and GetCurrentMapAreaID() or "nil"
                    local frameMap = WorldMapFrame and WorldMapFrame.mapID or "nil"
                    local frameMapId = "nil"
                    local scrollMapId = "nil"
                    if WorldMapFrame and WorldMapFrame.GetMapID then
                        local ok, mid = pcall(WorldMapFrame.GetMapID, WorldMapFrame)
                        if ok and mid then frameMapId = mid end
                    end
                    if WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.GetMapID then
                        local ok, mid = pcall(WorldMapFrame.ScrollContainer.GetMapID, WorldMapFrame.ScrollContainer)
                        if ok and mid then scrollMapId = mid end
                    end
                    local customZone = CustomZoneForMap(activeMapId)
                    local expectedZone = MAP_TO_ZONE[activeMapId]
                    DebugPrint("Boss dbg:",
                        "id=" .. tostring(ent.id),
                        "name=" .. tostring(ent.name),
                        "entMapId=" .. tostring(ent.mapId),
                        "activeMapId=" .. tostring(activeMapId),
                        "activeMapName=" .. tostring(mapName),
                        "curMapId=" .. tostring(curMap),
                        "frame.mapID=" .. tostring(frameMap),
                        "frame.GetMapID=" .. tostring(frameMapId),
                        "scroll.GetMapID=" .. tostring(scrollMapId),
                        "expectedZone=" .. tostring(expectedZone),
                        "customZone=" .. tostring(customZone),
                        "learnedZone=" .. tostring(learnedActive),
                        "zoneLabel=" .. tostring(ent.zoneLabel))
                end

                local matches = enabled and EntityMatchesMap(ent, activeMapId, false)
                if kind == "boss" and matches then
                    matchedBoss = matchedBoss + 1
                elseif kind == "boss" and (not sampleBoss) then
                    sampleBoss = {
                        id = ent.id,
                        entMapId = tonumber(ent.mapId),
                        activeMapId = tonumber(activeMapId),
                        resolvedZoneId = tonumber(resolvedZoneId),
                        showWorldBossPins = db.showWorldBossPins,
                    }
                end

                if matches then
                    local pin = self:AcquireEntityWorldPin(ent.id, ent)
                    if pin and parent then
                        local px, py
                        if Astrolabe and Astrolabe.WorldToMapPixels then
                            px, py = Astrolabe.WorldToMapPixels(parent, ent.nx, ent.ny)
                        else
                            px = ent.nx * parent:GetWidth()
                            py = ent.ny * parent:GetHeight()
                        end
                        pin:ClearAllPoints()
                        pin:SetPoint("CENTER", parent, "TOPLEFT", px, -py)

                        pin.texture:SetTexture(EntityTexture(kind))
                        if EntityIsActive(self.state, ent.id) then
                            pin.texture:SetVertexColor(1, 1, 1, 1)
                        else
                            pin.texture:SetVertexColor(0.7, 0.7, 0.7, 0.45)
                        end

                        pin:Show()
                        entSeen[ent.id] = true

                        if kind == "boss" then
                            shownBoss = shownBoss + 1
                        end
                    end
                end
            elseif ent and ent.id and (ent.kind == "boss" or ent.kind == "rare") then
                missingPos = missingPos + 1
            end
        end

        if db.debug then
            DebugPrint("Entities debug:",
                "activeMapId=" .. tostring(activeMapId),
                "resolvedZoneId=" .. tostring(resolvedZoneId),
                "bossTotal=" .. tostring(totalBoss),
                "bossEnabled=" .. tostring(enabledBoss),
                "bossMatched=" .. tostring(matchedBoss),
                "bossShown=" .. tostring(shownBoss))
            if sampleBoss then
                DebugPrint("Boss sample:",
                    "id=" .. tostring(sampleBoss.id),
                    "entMapId=" .. tostring(sampleBoss.entMapId),
                    "activeMapId=" .. tostring(sampleBoss.activeMapId),
                    "resolvedZoneId=" .. tostring(sampleBoss.resolvedZoneId),
                    "showWorldBossPins=" .. tostring(sampleBoss.showWorldBossPins))
            end
            if parent and parent.GetWidth then
                DebugPrint("WorldMap parent size:", tostring(parent:GetWidth()), tostring(parent:GetHeight()))
            end
        end

        if db.debug and totalEntities > 0 and missingPos > 0 then
            DebugPrint("Entities loaded:", totalEntities, "missing positions:", missingPos, "(pins require mapId+nx+ny)")
        end
    end

    DebugPrint("UpdateWorldPins: Map", activeMapId, "- Showing", visibleCount, "of", self:CountHotspots(), "pins")

    if db.debug then
        DebugPrint("Hotspot summary:",
            "total=" .. tostring(self:CountHotspots()),
            "shown=" .. tostring(visibleCount),
            "gated=" .. tostring(dbgGated),
            "noMatch=" .. tostring(dbgNoMatch),
            "noCoords=" .. tostring(dbgNoCoords),
            "noParent=" .. tostring(dbgNoParent))
        if dbgSample then
            DebugPrint("Hotspot sample:",
                "id=" .. tostring(dbgSample.id),
                "zoneId=" .. tostring(dbgSample.zoneId),
                "map=" .. tostring(dbgSample.map),
                "x=" .. tostring(dbgSample.x),
                "y=" .. tostring(dbgSample.y),
                "nx=" .. tostring(dbgSample.nx),
                "ny=" .. tostring(dbgSample.ny),
                "zone=" .. tostring(dbgSample.zone))
        end
        if dbgNoMatchSample then
            DebugPrint("NoMatch sample:",
                "id=" .. tostring(dbgNoMatchSample.id),
                "hs.zoneId=" .. tostring(dbgNoMatchSample.hotspotZoneId),
                "hs.map=" .. tostring(dbgNoMatchSample.hotspotMap),
                "hs.zone=" .. tostring(dbgNoMatchSample.hotspotZone),
                "activeMapId=" .. tostring(dbgNoMatchSample.activeMapId),
                "activeMapName=" .. tostring(dbgNoMatchSample.activeMapName),
                "expectedZone=" .. tostring(dbgNoMatchSample.expectedZone),
                "resolvedZoneId=" .. tostring(dbgNoMatchSample.resolvedZoneId))
        end
    end

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

    for id, pin in pairs(self.entityWorldPins) do
        if not entSeen[id] then
            pin:Hide()
        end
    end
end

function Pins:UpdateMinimapPins()
    local db = self.state.db
    if not db or not db.showMinimapPins or not Minimap then
        for id in pairs(self.minimapPins) do self:DestroyPin(self.minimapPins, id) end
        for id in pairs(self.entityMinimapPins) do self:DestroyPin(self.entityMinimapPins, id) end
        return
    end

    local px, py, playerMap = PlayerNormalizedPosition(self.state)
    if not px or not py then
        for _, pin in pairs(self.minimapPins) do pin:Hide() end
        return
    end

    local seen = {}
    local canShowHotspots = PlayerCanGainXP()
    if canShowHotspots then
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
    else
        for _, pin in pairs(self.minimapPins) do
            pin:Hide()
        end
    end

    -- Entities on minimap (only when on same map as player)
    local entSeen = {}
    local list = db.entities and db.entities.list
    if type(list) == "table" and playerMap then
        for _, ent in ipairs(list) do
            if ent and ent.id and ent.mapId and ent.nx and ent.ny and EntityMatchesMap(ent, playerMap, false) then
                local kind = ent.kind
                local enabled = (kind == "boss" and db.showMinimapBossPins and db.showWorldBossPins)
                    or (kind == "rare" and db.showRarePins)
                    or (kind == "death")
                if enabled then
                    local offsetX, offsetY
                    -- Use normalized delta math for entities.
                    -- Some Astrolabe builds expect world coords, which can yield (0,0) offsets with normalized inputs.
                    offsetX = (ent.nx - px) * Minimap:GetWidth()
                    offsetY = (py - ent.ny) * Minimap:GetHeight()
                    local pin = self:AcquireEntityMinimapPin(ent.id, ent)
                    if pin then
                        pin.texture:SetTexture(EntityTexture(kind))
                        if EntityIsActive(self.state, ent.id) then
                            pin.texture:SetVertexColor(1, 1, 1, 1)
                        else
                            pin.texture:SetVertexColor(0.7, 0.7, 0.7, 0.45)
                        end
                        pin:ClearAllPoints()
                        pin:SetPoint("CENTER", Minimap, "CENTER", offsetX, offsetY)
                        pin:Show()
                        entSeen[ent.id] = true
                    end
                end
            end
        end
    end

    for id, pin in pairs(self.minimapPins) do
        if not seen[id] then pin:Hide() end
    end

    for id, pin in pairs(self.entityMinimapPins) do
        if not entSeen[id] then pin:Hide() end
    end
end

return Pins
