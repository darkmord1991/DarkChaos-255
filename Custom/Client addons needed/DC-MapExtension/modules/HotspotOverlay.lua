local Addon = LibStub("AceAddon-3.0"):GetAddon("DC-MapExtension")
local Module = Addon:NewModule("HotspotOverlay", "AceEvent-3.0")

Module.prefix = "HOTSPOT_ADDON"

function Module:OnInitialize()
    self.trackedHotspots = {}
end

function Module:OnEnable()
    if RegisterAddonMessagePrefix then
        RegisterAddonMessagePrefix(self.prefix)
    end
    self:RegisterEvent("CHAT_MSG_ADDON", "HandleAddonMessage")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "RequestSync")
end

function Module:RequestSync()
    Addon:Debug("HotspotOverlay ready for server hotspot broadcast")
end

function Module:HandleAddonMessage(_, prefix, message, channel, sender)
    if prefix ~= self.prefix then
        return
    end
    self:ProcessPayload(message, sender, channel)
end

function Module:ProcessPayload(payload, sender)
    if not payload or payload == "" then
        return
    end
    Addon:Debug("Hotspot payload from", sender or "server", payload)
    -- TODO: Parse payload once server format is finalized.
end

Addon.HotspotOverlay = Module
