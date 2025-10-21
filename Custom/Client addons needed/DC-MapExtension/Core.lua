-- DC-MapExtension (clean)
-- World of Warcraft 3.3.5a addon to display custom worldmap backgrounds and POIs

local addonName = "DC-MapExtension"
local addon = {}

local MAP_ID_AZSHARA_CRATER = 37

-- texture filenames (BLP preferred for classic clients)
local BLP_TEXTURE = "Interface\\AddOns\\DC-MapExtension\\Textures\\azshara_crater.blp"
local PNG_TEXTURE = "Interface\\AddOns\\DC-MapExtension\\Textures\\azshara_crater.png"

-- DC-MapExtension (clean single-file)
-- World of Warcraft 3.3.5a addon to display custom worldmap backgrounds and POIs

local addonName = "DC-MapExtension"
local addon = {}

local MAP_ID_AZSHARA_CRATER = 37

-- texture filenames (BLP preferred for classic clients)
local BLP_TEXTURE = "Interface\\AddOns\\DC-MapExtension\\Textures\\azshara_crater.blp"
local PNG_TEXTURE = "Interface\\AddOns\\DC-MapExtension\\Textures\\azshara_crater.png"

-- Saved hotspots: persisted between sessions if the client's savedvariables is enabled
DCMap_HotspotsSaved = DCMap_HotspotsSaved or {}

local function FileExists(path)
    -- Try to load the texture; if successful, the file exists for the client
    local created = false
    local tex = addon.bgTex
    if not tex and WorldMapDetailFrame then
        tex = WorldMapDetailFrame:CreateTexture()
        created = true
    end
    local ok = pcall(tex.SetTexture, tex, path)
    if created then tex:SetTexture(nil) end
    return ok
end

local function ChooseBestTexture()
    if FileExists(BLP_TEXTURE) then return BLP_TEXTURE end
    if FileExists(PNG_TEXTURE) then return PNG_TEXTURE end
    return "Interface\\Icons\\INV_Misc_Map_01"
end

local function EnsureMapBackgroundFrame()
    if not addon.background then
        addon.background = CreateFrame("Frame", "DCMap_BackgroundFrame", WorldMapDetailFrame)
        addon.background:SetAllPoints(WorldMapDetailFrame)
        addon.bgTex = addon.background:CreateTexture(nil, "BACKGROUND")
        addon.bgTex:SetAllPoints(addon.background)
        addon.background:Hide()
    end
    local tex = ChooseBestTexture()
    addon.bgTex:SetTexture(tex)
end

local function ShowMapBackgroundIfNeeded(mapId)
    EnsureMapBackgroundFrame()
    if mapId == MAP_ID_AZSHARA_CRATER then
        addon.background:Show()
    else
        addon.background:Hide()
    end
end

addon.poiFrames = addon.poiFrames or {}

local function CreatePOI(mapFrame, nx, ny, label, id)
    if not nx or not ny or not mapFrame then return end
    local w = mapFrame:GetWidth() or 512
    local h = mapFrame:GetHeight() or 512
    local x = nx * w
    local y = ny * h

    local name = "DCMap_POI_" .. tostring(id)
    local poi = CreateFrame("Frame", name, mapFrame)
    poi:SetSize(20, 20)
    poi.tex = poi:CreateTexture(nil, "OVERLAY")
    poi.tex:SetAllPoints(poi)
    poi.tex:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
    poi:SetPoint("TOPLEFT", mapFrame, "TOPLEFT", x, -y)
    if label then
        poi.label = poi:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        poi.label:SetPoint("TOP", poi, "BOTTOM", 0, -2)
        poi.label:SetText(label)
    end
    return poi
end

local function ClearAllPOIs()
    for id, frame in pairs(addon.poiFrames) do
        if frame and frame.Hide then frame:Hide() end
        addon.poiFrames[id] = nil
    end
end

local function RenderHotspotsForMap(mapId)
    ClearAllPOIs()
    if not DCMap_HotspotsSaved[mapId] then return end
    for _, hs in ipairs(DCMap_HotspotsSaved[mapId]) do
        if hs.nx and hs.ny then
            local label = hs.label or ("Hotspot #" .. tostring(hs.id))
            local poi = CreatePOI(WorldMapDetailFrame, hs.nx, hs.ny, label, hs.id)
            if poi then addon.poiFrames[hs.id] = poi end
        end
    end
end

local function ParseHotspotPayload(payload)
    local result = {}
    if not payload then return result end
    local start = payload:find("HOTSPOT_ADDON")
    if start then payload = payload:sub(start) end
    if payload:sub(1,13) == "HOTSPOT_ADDON|" then payload = payload:sub(14) end
    for token in payload:gmatch("([^|]+)") do
        local k, v = token:match("^([^:]+):(.+)$")
        if k and v then result[k] = v end
    end
    if result.map then result.map = tonumber(result.map) end
    if result.zone then result.zone = tonumber(result.zone) end
    if result.x then result.x = tonumber(result.x) end
    if result.y then result.y = tonumber(result.y) end
    if result.z then result.z = tonumber(result.z) end
    if result.id then result.id = tonumber(result.id) end
    if result.dur then result.dur = tonumber(result.dur) end
    if result.nx then result.nx = tonumber(result.nx) end
    if result.ny then result.ny = tonumber(result.ny) end
    return result
end

local function HandleIncomingHotspot(rawPayload)
    if not rawPayload then return end
    local payload = tostring(rawPayload)
    local start = payload:find("HOTSPOT_ADDON")
    if start then payload = payload:sub(start) end
    local parsed = ParseHotspotPayload(payload)
    if not parsed or not parsed.map or not parsed.id then return end
    DCMap_HotspotsSaved[parsed.map] = DCMap_HotspotsSaved[parsed.map] or {}
    local found = false
    for i, hs in ipairs(DCMap_HotspotsSaved[parsed.map]) do
        if hs.id == parsed.id then
            DCMap_HotspotsSaved[parsed.map][i] = parsed
            found = true
            break
        end
    end
    if not found then table.insert(DCMap_HotspotsSaved[parsed.map], parsed) end
    local currentMapID = GetCurrentMapAreaID() or 0
    if currentMapID == parsed.map then RenderHotspotsForMap(parsed.map) end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("WORLD_MAP_UPDATE")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("CHAT_MSG_SYSTEM")

eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2, arg3, arg4, arg5)
    if event == "PLAYER_LOGIN" then
        EnsureMapBackgroundFrame()
    elseif event == "WORLD_MAP_UPDATE" then
        local currentMapID = GetCurrentMapAreaID() or 0
        ShowMapBackgroundIfNeeded(currentMapID)
        RenderHotspotsForMap(currentMapID)
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message = arg1, arg2
        if message == nil and prefix ~= nil then message = prefix; prefix = nil end
        if (prefix == "HOTSPOT" or (message and message:find("HOTSPOT_ADDON"))) then
            HandleIncomingHotspot(message)
        end
    elseif event == "CHAT_MSG_SYSTEM" then
        local message = arg1
        if message and message:find("HOTSPOT_ADDON") then HandleIncomingHotspot(message) end
    end
end)

SlashCmdList["DCMAP"] = function(msg)
    msg = msg and msg:lower() or ""
    if msg == "debug" then
        -- Try to switch the world map to Azshara Crater and show our background/POIs.
        EnsureMapBackgroundFrame()
        if type(SetMapByID) == "function" then
            pcall(SetMapByID, MAP_ID_AZSHARA_CRATER)
        elseif type(SetMapToMapID) == "function" then
            pcall(SetMapToMapID, MAP_ID_AZSHARA_CRATER)
        end
        if ShowUIPanel then pcall(ShowUIPanel, WorldMapFrame) end
        DCMap_HotspotsSaved[MAP_ID_AZSHARA_CRATER] = DCMap_HotspotsSaved[MAP_ID_AZSHARA_CRATER] or {}
        table.insert(DCMap_HotspotsSaved[MAP_ID_AZSHARA_CRATER], { id = 99999, nx = 0.5, ny = 0.5, label = "TEST HOTSPOT" })
        RenderHotspotsForMap(MAP_ID_AZSHARA_CRATER)
        DEFAULT_CHAT_FRAME:AddMessage("DC-MapExtension: debug - opened map and placed test hotspot")
    elseif msg == "show" then
        EnsureMapBackgroundFrame(); addon.background:Show()
    elseif msg == "hide" then
        EnsureMapBackgroundFrame(); addon.background:Hide()
    elseif msg == "clear" then
        DCMap_HotspotsSaved = {}
        ClearAllPOIs()
        DEFAULT_CHAT_FRAME:AddMessage("DC-MapExtension: cleared stored hotspots")
    else
        DEFAULT_CHAT_FRAME:AddMessage("DC-MapExtension: /dcmap debug|show|hide|clear")
    end
end

SLASH_DCMAP1 = "/dcmap"

print("DC-MapExtension loaded")

local function EnsureMapBackgroundFrame()
    if not addon.background then
        addon.background = CreateFrame("Frame", "DCMap_BackgroundFrame", WorldMapDetailFrame)
        addon.background:SetAllPoints(WorldMapDetailFrame)
        addon.bgTex = addon.background:CreateTexture(nil, "BACKGROUND")
        addon.bgTex:SetPoint("CENTER", WorldMapDetailFrame, "CENTER")
        addon.bgTex:SetSize(WorldMapDetailFrame:GetWidth(), WorldMapDetailFrame:GetHeight())
        -- Fallback uses the included PNG. Replace with BLP named azshara_crater.blp for 3.3.5a clients.
        addon.bgTex:SetTexture("Interface\\AddOns\\DC-MapExtension\\Textures\\azshara_crater.png")
        addon.background:Hide()
    end
end

local function ShowMapBackgroundIfNeeded(mapId)
    EnsureMapBackgroundFrame()
    if mapId == MAP_ID_AZSHARA_CRATER then
        addon.background:Show()
    else
        addon.background:Hide()
    end
end

-- Table of active POI frames keyed by hotspot id
addon.poiFrames = addon.poiFrames or {}

local function CreatePOI(mapFrame, nx, ny, label, id)
    -- nx/ny are normalized 0..1 coordinates relative to the map texture
    if not nx or not ny then return end
    local w = mapFrame:GetWidth()
    local h = mapFrame:GetHeight()
    local x = nx * w
    local y = ny * h

    local poi = CreateFrame("Frame", "DCMap_POI_" .. tostring(id), mapFrame)
    poi:SetSize(20, 20)
    poi.tex = poi:CreateTexture(nil, "OVERLAY")
    poi.tex:SetAllPoints(poi)
    poi.tex:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
    -- anchor TOPLEFT offset: y must be negative because UI coordinates go down
    poi:SetPoint("TOPLEFT", mapFrame, "TOPLEFT", x, -y)
    if label then
        poi.label = poi:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        poi.label:SetPoint("TOP", poi, "BOTTOM", 0, -2)
        poi.label:SetText(label)
    end
    return poi
end

local function ClearAllPOIs()
    for id, frame in pairs(addon.poiFrames) do
        if frame and frame:IsShown() then
            frame:Hide()
            frame:SetParent(nil)
        end
        addon.poiFrames[id] = nil
    end
end

local function RenderHotspotsForMap(mapId)
    -- Render stored hotspots for given mapId onto WorldMapDetailFrame
    ClearAllPOIs()
    if not DCMap_HotspotsSaved[mapId] then return end
    local entries = DCMap_HotspotsSaved[mapId]
    for _, hs in ipairs(entries) do
        -- prefer normalized coords nx/ny if available
        if hs.nx and hs.ny then
            local label = hs.label or ("Hotspot #" .. tostring(hs.id))
            local poi = CreatePOI(WorldMapDetailFrame, hs.nx, hs.ny, label, hs.id)
            if poi then
                addon.poiFrames[hs.id] = poi
            end
        end
    end
end

local function ParseHotspotPayload(payload)
    -- payload example: HOTSPOT_ADDON|map:37|zone:268|x:123.45|y:678.90|z:...|id:5|dur:3600|icon:800001|bonus:100|nx:0.5123|ny:0.4123
    local result = {}
    if not payload then return result end
    -- optionally trim leading token
    if payload:sub(1,13) == "HOTSPOT_ADDON|" then
        payload = payload:sub(14)
    end
    for token in payload:gmatch("([^
SLASH_DCMAP1 = "/dcmap"
        local k, v = token:match("^([^:]+):(.+)$")
        if k and v then
            result[k] = v
        end
    end
    -- convert numeric fields
    if result.map then result.map = tonumber(result.map) end
    if result.zone then result.zone = tonumber(result.zone) end
    if result.x then result.x = tonumber(result.x) end
    if result.y then result.y = tonumber(result.y) end
    if result.z then result.z = tonumber(result.z) end
    if result.id then result.id = tonumber(result.id) end
    if result.dur then result.dur = tonumber(result.dur) end
    if result.nx then result.nx = tonumber(result.nx) end
    if result.ny then result.ny = tonumber(result.ny) end
    return result
end

local function HandleIncomingHotspot(rawPayload)
    if not rawPayload then return end
    -- Server sometimes prefixes payload with "HOTSPOT\t" when sent as CHAT_MSG_ADDON
    -- or sends the canonical payload as a system message. Try to extract the canonical part.
    local payload = rawPayload
    -- If payload contains the token separator and 'HOTSPOT_ADDON' token, extract from that point
    local start = payload:find("HOTSPOT_ADDON")
    if start then payload = payload:sub(start) end

    local parsed = ParseHotspotPayload(payload)
    if not parsed or not parsed.map or not parsed.id then return end

    -- store in saved table per map
    DCMap_HotspotsSaved[parsed.map] = DCMap_HotspotsSaved[parsed.map] or {}
    -- dedupe by id
    local found = false
    for i, hs in ipairs(DCMap_HotspotsSaved[parsed.map]) do
        if hs.id == parsed.id then
            DCMap_HotspotsSaved[parsed.map][i] = parsed
            found = true
            break
        end
    end
    if not found then table.insert(DCMap_HotspotsSaved[parsed.map], parsed) end

    -- If the world map is currently showing this map id, render immediately
    local currentMapID = GetCurrentMapAreaID() or 0
    if currentMapID == parsed.map then
        RenderHotspotsForMap(parsed.map)
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("WORLD_MAP_UPDATE")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("CHAT_MSG_SYSTEM")

eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2, arg3, arg4, arg5)
    if event == "PLAYER_LOGIN" then
        -- ensure background exists
        EnsureMapBackgroundFrame()
    elseif event == "WORLD_MAP_UPDATE" then
        local currentMapID = GetCurrentMapAreaID() or 0
        ShowMapBackgroundIfNeeded(currentMapID)
        -- render saved hotspots for this map
        RenderHotspotsForMap(currentMapID)
    elseif event == "CHAT_MSG_ADDON" then
        local prefix = arg1
        local message = arg2
        -- Some clients populate args in different order; try both
        if message == nil and prefix ~= nil then message = prefix; prefix = nil end
        if (prefix == "HOTSPOT" or (message and message:find("HOTSPOT_ADDON"))) then
            HandleIncomingHotspot(message)
        end
    elseif event == "CHAT_MSG_SYSTEM" then
        local message = arg1
        if message and message:find("HOTSPOT_ADDON") then
            HandleIncomingHotspot(message)
        end
    end
end)

SlashCmdList["DCMAP"] = function(msg)
    msg = msg and msg:lower() or ""
    if msg == "debug" then
        DEFAULT_CHAT_FRAME:AddMessage("DC-MapExtension: debug message")
    elseif msg == "show" then
        EnsureMapBackgroundFrame(); addon.background:Show()
    elseif msg == "hide" then
        EnsureMapBackgroundFrame(); addon.background:Hide()
    elseif msg == "clear" then
        DCMap_HotspotsSaved = {}
        ClearAllPOIs()
        DEFAULT_CHAT_FRAME:AddMessage("DC-MapExtension: cleared stored hotspots")
    else
        DEFAULT_CHAT_FRAME:AddMessage("DC-MapExtension: /dcmap debug|show|hide|clear")
    end
end

SLASH_DCMAP1 = "/dcmap"

-- Return to satisfy loader expectations
return
SlashCmdList["DCMAP"] = function(msg)
    if msg == "debug" then
        -- open map and show texture
        ShowWorldMapTextureIfNeeded()
        ShowUIPanel(WorldMapFrame)
        print("DC-MapExtension: debug show (mapId="..tostring(GetCurrentMapAreaID())..")")
    elseif msg == "show" then
        HotspotFrame:Show()
    elseif msg == "hide" then
        HotspotFrame:Hide()
    else
        print("DC-MapExtension commands: debug | show | hide")
    end
end

print("DC-MapExtension loaded")
