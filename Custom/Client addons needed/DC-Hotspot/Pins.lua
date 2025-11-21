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

local function HotspotMatchesMap(hotspot, mapId, showAll)
    if not hotspot then return false end
    
    -- Debug: Log matching logic (first time only)
    if not _G.DC_HOTSPOT_MATCH_LOGGED then
        print("|cffffff00[DC-Hotspot] HotspotMatchesMap check:|r")
        print("  Current mapId: " .. tostring(mapId))
        print("  showAll: " .. tostring(showAll))
        if hotspot then
            print("  Example hotspot.map (continent): " .. tostring(hotspot.map))
            print("  Example hotspot.zoneId: " .. tostring(hotspot.zoneId))
        end
        _G.DC_HOTSPOT_MATCH_LOGGED = true
    end
    
    -- If "show all" is enabled, always show
    if showAll then
        DebugPrint("Showing hotspot - showAll enabled")
        return true
    end
    
    -- If no valid map ID, don't show any pins
    if not mapId or mapId == 0 then
        DebugPrint("No valid mapId - hiding hotspot")
        return false
    end
    
    -- Resolve custom zone mappings
    -- Some zones report different map IDs than zone IDs (e.g., Azshara Crater = map 614, zone 268)
    local resolvedZoneId = CUSTOM_ZONE_MAPPING[mapId] or mapId
    
    -- Check if hotspot has data
    local hotspotMap = tonumber(hotspot.map)      -- Continent ID (0, 1, 530, 571, 37)
    local hotspotZone = tonumber(hotspot.zoneId)  -- Zone ID from server
    
    if not hotspotZone and not hotspotMap then
        DebugPrint("Hotspot has no zone/map data - hiding")
        return false
    end
    
    -- Strategy: Match by continent
    -- Since WoW map IDs ≠ zone IDs, show all hotspots from same continent
    if hotspotMap and hotspotMap == mapId then
        -- Direct continent match
        return true
    end
    
    -- Eastern Kingdoms (continent 0): map IDs 0-99
    if hotspotMap == 0 and mapId >= 0 and mapId < 100 then
        return true
    end
    
    -- Kalimdor (continent 1): map IDs 1-99
    if hotspotMap == 1 and mapId >= 1 and mapId < 100 then
        return true
    end
    
    -- Outland (continent 530): map IDs 465-480
    if hotspotMap == 530 and mapId >= 465 and mapId <= 480 then
        return true
    end
    
    -- Northrend (continent 571): map IDs 485-550
    if hotspotMap == 571 and mapId >= 485 and mapId <= 550 then
        return true
    end
    
    -- Azshara Crater (continent 37)
    if hotspotMap == 37 and (resolvedZoneId == 268 or mapId == 614) then
        return true
    end
    
    return false
end

-- Custom zone map ID to zone ID mapping
-- Some custom zones report different map IDs than their zone IDs
local CUSTOM_ZONE_MAPPING = {
    [614] = 268,  -- Azshara Crater: WoW reports map 614, but zone is 268
    -- Add more custom zones here as needed
}

local function ResolveTexture(state, hotspot)
    local db = state and state.db
    local style = db and db.pinIconStyle or "spell"
    local custom = db and db.customIconTexture
    if style == "custom" and custom and custom ~= "" then
        return custom
    end
    if style == "target" then
        return "Interface\\Minimap\\Minimap-target"
    elseif style == "skull" then
        return "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_8"
    elseif style == "map" then
        return "Interface\\Icons\\INV_Misc_Map_01"
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
    return "Interface\\Icons\\INV_Misc_Map_01"
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
        WorldMapFrame:HookScript("OnShow", function() self:UpdateWorldPins() end)
        WorldMapFrame:HookScript("OnSizeChanged", function() self:UpdateWorldPins() end)
    end

    self.worldMapWatcher = CreateFrame("Frame")
    self.worldMapWatcher:RegisterEvent("WORLD_MAP_UPDATE")
    self.worldMapWatcher:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    self.worldMapWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.worldMapWatcher:SetScript("OnEvent", function()
        self:UpdateWorldPins()
    end)

    local ticker = CreateFrame("Frame")
    ticker:SetScript("OnUpdate", function(_, elapsed)
        self.minimapUpdate = self.minimapUpdate + elapsed
        if self.minimapUpdate >= 0.3 then
            self.minimapUpdate = 0
            self:UpdateMinimapPins()
        end
    end)
end

function Pins:Refresh()
    self:UpdateWorldPins()
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

function Pins:UpdateWorldPins()
    local db = self.state.db
    if not db or not db.showWorldPins or not WorldMapFrame then
        for id in pairs(self.worldPins) do self:DestroyPin(self.worldPins, id) end
        return
    end

    local activeMapId = ActiveWorldMapId()
    local seen = {}
    local visibleCount = 0
    local showAll = db and db.showAllMaps
    
    if not _G.DC_HOTSPOT_SHOWALL_LOGGED then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff00ff[DC-Hotspot] UpdateWorldPins settings:|r")
        DEFAULT_CHAT_FRAME:AddMessage("  db.showAllMaps = " .. tostring(db and db.showAllMaps))
        DEFAULT_CHAT_FRAME:AddMessage("  showAll = " .. tostring(showAll))
        DEFAULT_CHAT_FRAME:AddMessage("  activeMapId = " .. tostring(activeMapId))
        _G.DC_HOTSPOT_SHOWALL_LOGGED = true
    end
    
    DebugPrint("UpdateWorldPins: Processing", self:CountHotspots(), "hotspots for map", activeMapId)
    
    for id, hotspot in pairs(self.state.hotspots) do
        local pin = self:AcquireWorldPin(id, hotspot)
        if pin then
            local matches = HotspotMatchesMap(hotspot, activeMapId, showAll)
            if not _G.DC_HOTSPOT_FIRST_MATCH_LOGGED then
                DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffff0000[DC-Hotspot] First match check: hotspot %s (zone %s) vs map %s = %s|r", 
                    tostring(id), tostring(hotspot.zoneId), tostring(activeMapId), tostring(matches)))
                _G.DC_HOTSPOT_FIRST_MATCH_LOGGED = true
            end
            
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
