-- DC-MapExtension
-- Clean, single-file addon: show a background texture for Azshara Crater (map id 37) and render simple POI hotspots.
-- This version is deliberately small and defensive: it prefers PNG (1024 POT) -> PNG -> BLP -> fallback icon

local MAP_ID_AZSHARA_CRATER = 37

local BLP_TEXTURE = "Interface\\AddOns\\DC-MapExtension\\Textures\\azshara_crater.blp"
local PNG_TEXTURE = "Interface\\AddOns\\DC-MapExtension\\Textures\\azshara_crater.png"
local PNG_POT_TEXTURE = "Interface\\AddOns\\DC-MapExtension\\Textures\\azshara_crater_1024.png"

DCMap_HotspotsSaved = DCMap_HotspotsSaved or {}

local addon = {}
addon.forcedTexture = addon.forcedTexture or "auto" -- "auto", "png", "blp"

local function FileExists(path)
    if not WorldMapDetailFrame then return false end
    local created = false
    local tex = addon.bgTex
    if not tex then tex = WorldMapDetailFrame:CreateTexture(); created = true end
    local ok = false
    if tex and tex.SetTexture then ok = pcall(tex.SetTexture, tex, path) end
    if created and tex then tex:SetTexture(nil) end
    return ok
end

local function ChooseBestTexture()
    if addon.forcedTexture == "png" then
        if FileExists(PNG_POT_TEXTURE) then return PNG_POT_TEXTURE end
        if FileExists(PNG_TEXTURE) then return PNG_TEXTURE end
    elseif addon.forcedTexture == "blp" then
        if FileExists(BLP_TEXTURE) then return BLP_TEXTURE end
    else
        if FileExists(PNG_POT_TEXTURE) then return PNG_POT_TEXTURE end
        if FileExists(PNG_TEXTURE) then return PNG_TEXTURE end
        if FileExists(BLP_TEXTURE) then return BLP_TEXTURE end
    end
    return "Interface\\Icons\\INV_Misc_Map_01"
end

local function EnsureMapBackgroundFrame()
    if not addon.background and WorldMapDetailFrame then
        addon.background = CreateFrame("Frame", "DCMap_BackgroundFrame", WorldMapDetailFrame)
        addon.background:SetAllPoints(WorldMapDetailFrame)
        addon.bgTex = addon.background:CreateTexture(nil, "BACKGROUND")
        addon.bgTex:SetAllPoints(addon.background)
        addon.background:Hide()
        addon.background:SetFrameStrata("MEDIUM")
        local parentLevel = WorldMapDetailFrame and WorldMapDetailFrame:GetFrameLevel() or 0
        addon.background:SetFrameLevel(parentLevel + 10)
        addon.bgTex:SetBlendMode("BLEND")
        addon.bgTex:SetDrawLayer("ARTWORK", 0)
        addon.bgTex:SetTexCoord(0, 1, 0, 1)
    end
    if addon.bgTex then
        local chosen = ChooseBestTexture()
        pcall(addon.bgTex.SetTexture, addon.bgTex, chosen)
        -- Log selection to chat when possible (helps in-game debugging to see which path was used)
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "DC-MapExtension: using texture -> "..tostring(chosen))
        end
    end
end

local function ClearDetailTextures()
    addon._savedDetailTextures = addon._savedDetailTextures or {}
    if WorldMapDetailFrame then
        local i = 1
        for _, region in ipairs({WorldMapDetailFrame:GetRegions()}) do
            if region and region.GetObjectType and region:GetObjectType() == "Texture" then
                if not addon._savedDetailTextures[i] then
                    local ok, tex = pcall(region.GetTexture, region)
                    addon._savedDetailTextures[i] = ok and tex or nil
                end
                pcall(region.SetTexture, region, nil)
            end
            i = i + 1
        end
    end
end

local function RestoreDetailTextures()
    if addon._savedDetailTextures and WorldMapDetailFrame then
        local i = 1
        for _, region in ipairs({WorldMapDetailFrame:GetRegions()}) do
            if region and region.GetObjectType and region:GetObjectType() == "Texture" then
                local tex = addon._savedDetailTextures[i]
                if tex then pcall(region.SetTexture, region, tex) end
            end
            i = i + 1
        end
    end
    addon._savedDetailTextures = nil
end

local function ShowMapBackgroundIfNeeded(mapId)
    EnsureMapBackgroundFrame()
    if not addon.background then return end
    if mapId == MAP_ID_AZSHARA_CRATER or (type(GetMapInfo) == "function" and (GetMapInfo() or ""):lower():find("azshara")) then
        addon.background:Show()
        ClearDetailTextures()
    else
        addon.background:Hide()
        RestoreDetailTextures()
    end
end

-- POI simple rendering (keeps minimal feature parity)
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
    for id, frame in pairs(addon.poiFrames) do if frame and frame.Hide then frame:Hide() end; addon.poiFrames[id] = nil end
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
    if result.nx then result.nx = tonumber(result.nx) end
    if result.ny then result.ny = tonumber(result.ny) end
    if result.id then result.id = tonumber(result.id) end
    return result
end

local function HandleIncomingHotspot(rawPayload)
    if not rawPayload then return end
    local parsed = ParseHotspotPayload(tostring(rawPayload))
    if not parsed or not parsed.map or not parsed.id then return end
    DCMap_HotspotsSaved[parsed.map] = DCMap_HotspotsSaved[parsed.map] or {}
    local found = false
    for i, hs in ipairs(DCMap_HotspotsSaved[parsed.map]) do
        if hs.id == parsed.id then DCMap_HotspotsSaved[parsed.map][i] = parsed; found = true; break end
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
eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "PLAYER_LOGIN" then EnsureMapBackgroundFrame()
    elseif event == "WORLD_MAP_UPDATE" then
        local currentMapID = GetCurrentMapAreaID() or 0
        ShowMapBackgroundIfNeeded(currentMapID)
        RenderHotspotsForMap(currentMapID)
    elseif event == "CHAT_MSG_ADDON" then
        local prefix = arg1; local message = arg2
        if message == nil and prefix ~= nil then message = prefix; prefix = nil end
        if (prefix == "HOTSPOT" or (message and message:find("HOTSPOT_ADDON"))) then HandleIncomingHotspot(message) end
    elseif event == "CHAT_MSG_SYSTEM" then
        local message = arg1
        if message and message:find("HOTSPOT_ADDON") then HandleIncomingHotspot(message) end
    end
end)

SLASH_DCMAP1 = "/dcmap"
SlashCmdList["DCMAP"] = function(msg)
    msg = msg and msg:lower() or ""
    if msg == "debug" then
        EnsureMapBackgroundFrame(); if type(SetMapByID) == "function" then pcall(SetMapByID, MAP_ID_AZSHARA_CRATER) elseif type(SetMapToMapID) == "function" then pcall(SetMapToMapID, MAP_ID_AZSHARA_CRATER) end; if ShowUIPanel then pcall(ShowUIPanel, WorldMapFrame) end
        DCMap_HotspotsSaved[MAP_ID_AZSHARA_CRATER] = DCMap_HotspotsSaved[MAP_ID_AZSHARA_CRATER] or {}
        table.insert(DCMap_HotspotsSaved[MAP_ID_AZSHARA_CRATER], { id = 99999, nx = 0.5, ny = 0.5, label = "TEST HOTSPOT" })
        RenderHotspotsForMap(MAP_ID_AZSHARA_CRATER)
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "DC-MapExtension: debug - opened map and placed test hotspot") end
    elseif msg == "show" then EnsureMapBackgroundFrame(); if addon.background then addon.background:Show() end
    elseif msg == "hide" then EnsureMapBackgroundFrame(); if addon.background then addon.background:Hide() end
    elseif msg == "clear" then DCMap_HotspotsSaved = {}; ClearAllPOIs(); if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "DC-MapExtension: cleared stored hotspots") end
    else if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "DC-MapExtension: /dcmap debug|show|hide|clear") end end
end

if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "DC-MapExtension loaded") end
                    local start = payload:find("HOTSPOT_ADDON")

                    if start then payload = payload:sub(start) end
