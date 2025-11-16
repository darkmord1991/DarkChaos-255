local Addon = LibStub("AceAddon-3.0"):GetAddon("DC-MapExtension")
local Module = Addon:NewModule("TextureController", "AceEvent-3.0")

function Module:OnInitialize()
    self.customMaps = {}
end

function Module:OnEnable()
    self:RefreshCustomMaps()
    Addon:Debug("TextureController online. Registered maps:", self:GetCustomMapCount())
end

function Module:RefreshCustomMaps()
    self.customMaps = Addon:GetDataSet("CustomMaps") or {}
end

function Module:GetCustomMapEntries()
    return self.customMaps
end

function Module:GetCustomMapByID(mapID)
    for _, info in pairs(self.customMaps) do
        if info.mapID == mapID then
            return info
        end
    end
end

function Module:GetCustomMapCount()
    local count = 0
    for _ in pairs(self.customMaps) do
        count = count + 1
    end
    return count
end

function Module:GetTexturesForKey(key)
    local entry = self.customMaps[key]
    return entry and entry.textures or nil
end

Addon.TextureController = Module
