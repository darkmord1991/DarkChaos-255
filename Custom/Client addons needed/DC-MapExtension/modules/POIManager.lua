local Addon = LibStub("AceAddon-3.0"):GetAddon("DC-MapExtension")
local Module = Addon:NewModule("POIManager", "AceEvent-3.0")

function Module:OnInitialize()
    self.layers = {}
end

function Module:OnEnable()
    self:SeedStaticLayers()
end

function Module:SeedStaticLayers()
    local poiData = Addon:GetPOIData()
    if not poiData or not poiData.layers then
        return
    end
    for key, definition in pairs(poiData.layers) do
        self:RegisterLayer(key, definition)
    end

    local external = Addon:GetModule("ExternalPOIProvider", true)
    if external and external.GetLayerDefinitions then
        for key, definition in external:GetLayerDefinitions() do
            self:RegisterLayer(key, definition)
        end
    end
end

function Module:RegisterLayer(key, definition)
    if not key or type(definition) ~= "table" then
        return
    end
    self.layers[key] = self.layers[key] or {}
    for k, v in pairs(definition) do
        self.layers[key][k] = v
    end
    if Addon.db and Addon.db.profile and Addon.db.profile.layers[key] == nil then
        Addon.db.profile.layers[key] = true
    end
    Addon:SendMessage("DCMAP_LAYER_UPDATED", key, self.layers[key])
end

function Module:IterateLayers()
    return next, self.layers, nil
end

function Module:GetLayer(key)
    return self.layers[key]
end

function Module:GetLayerState(key)
    if not Addon.db then
        return true
    end
    local state = Addon.db.profile.layers[key]
    if state == nil then
        state = true
        Addon.db.profile.layers[key] = state
    end
    return state
end

function Module:SetLayerState(key, enabled)
    if not Addon.db then
        return
    end
    Addon.db.profile.layers[key] = enabled and true or false
    Addon:SendMessage("DCMAP_LAYER_TOGGLED", key, Addon.db.profile.layers[key])
end

Addon.POIManager = Module

-- Lightweight wrapper that can be replaced by a true library importer later.
local ExternalProvider = Addon:NewModule("ExternalPOIProvider")
function ExternalProvider:GetLayerDefinitions()
    local noop = function()
        return function()
            return nil
        end
    end
    return noop
end
