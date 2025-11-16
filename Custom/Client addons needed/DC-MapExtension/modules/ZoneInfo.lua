local Addon = LibStub("AceAddon-3.0"):GetAddon("DC-MapExtension")
local Module = Addon:NewModule("ZoneInfo", "AceEvent-3.0")

function Module:OnInitialize()
    self.customOverrides = {}
    self.aliases = {}
end

function Module:OnEnable()
    self.zoneTable = _G.zones or {}
    self:ApplyDefaultOverrides()
end

function Module:ApplyDefaultOverrides()
    -- Treat Azshara Crater as a full 1-80 leveling zone.
    self:SetCustomZoneRange("Azshara Crater", 1, 80, "C")
    -- Hyjal content is extended to 130; expose it under Hyjal Summit to avoid collisions.
    self:SetCustomZoneRange("Hyjal Summit", 80, 130, "C")

    -- Ensure the base ZoneLevelInfo table reflects our custom entries when available.
    if self.zoneTable then
        self.zoneTable["Azshara Crater"] = self.zoneTable["Azshara Crater"] or {1, 80, "C"}
        self.zoneTable["Hyjal Summit"] = self.zoneTable["Hyjal Summit"] or {80, 130, "C"}
        self.zoneTable["Hyjal"] = self.zoneTable["Hyjal Summit"]
    end

    -- Alias "Hyjal" or "Mount Hyjal" queries to the renamed zone.
    self.aliases["Hyjal"] = "Hyjal Summit"
    self.aliases["Mount Hyjal"] = "Hyjal Summit"
end

function Module:NormalizeZoneName(zoneName)
    if not zoneName then
        return zoneName
    end
    return self.aliases[zoneName] or zoneName
end

function Module:SetCustomZoneRange(zoneName, minLevel, maxLevel, faction)
    if not zoneName then
        return
    end
    self.customOverrides[zoneName] = {
        min = minLevel,
        max = maxLevel,
        faction = faction,
    }
end

function Module:GetZoneRange(zoneName)
    zoneName = self:NormalizeZoneName(zoneName)
    if not zoneName then
        return nil
    end

    if self.customOverrides[zoneName] then
        local override = self.customOverrides[zoneName]
        return override.min, override.max, override.faction
    end

    local data = self.zoneTable[zoneName]
    if data then
        return data[1], data[2], data[3]
    end
end

Addon.ZoneInfo = Module
