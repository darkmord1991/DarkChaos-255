local Addon = LibStub("AceAddon-3.0"):GetAddon("DC-MapExtension")
local Module = Addon:NewModule("AtlasManager", "AceEvent-3.0")

local function GetActiveMapID()
    if WorldMapFrame and WorldMapFrame.GetMapID then
        return WorldMapFrame:GetMapID()
    end
    if GetCurrentMapAreaID then
        return GetCurrentMapAreaID()
    end
end

function Module:OnInitialize()
    self.activeMapID = nil
end

function Module:OnEnable()
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "HandleZoneUpdate")
    self:RegisterEvent("WORLD_MAP_UPDATE", "HandleZoneUpdate")
    if WorldMapFrame then
        self:HookWorldMap()
    end
    Addon:Debug("AtlasManager enabled")
end

function Module:HookWorldMap()
    if self.hooked or not WorldMapFrame then
        return
    end
    WorldMapFrame:HookScript("OnShow", function()
        self:HandleZoneUpdate()
    end)
    self.hooked = true
end

function Module:HandleZoneUpdate()
    local mapID = GetActiveMapID()
    if mapID and mapID ~= self.activeMapID then
        self.activeMapID = mapID
        Addon.charDB.profile.lastMapID = mapID
        Addon:SendMessage("DCMAP_MAP_CHANGED", mapID)
        Addon:Debug("Active map changed to", mapID)
    end
end

function Module:GetActiveMapID()
    return self.activeMapID or Addon.charDB.profile.lastMapID
end

Addon.AtlasManager = Module
