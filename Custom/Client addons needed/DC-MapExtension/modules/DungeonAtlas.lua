local Addon = LibStub("AceAddon-3.0"):GetAddon("DC-MapExtension")
local Module = Addon:NewModule("DungeonAtlas", "AceEvent-3.0")

function Module:OnInitialize()
    self.sources = {}
end

function Module:OnEnable()
    self:DiscoverExternalSources()
    Addon:Debug("DungeonAtlas detected", #self.sources, "sources")
end

function Module:DiscoverExternalSources()
    wipe(self.sources)
    if WDM then
        table.insert(self.sources, "WDM")
    end
    if AtlasLoot then
        table.insert(self.sources, "AtlasLoot")
    end
    if AtlasData then
        table.insert(self.sources, "Atlas")
    end
end

function Module:GetSources()
    return self.sources
end

Addon.DungeonAtlas = Module
