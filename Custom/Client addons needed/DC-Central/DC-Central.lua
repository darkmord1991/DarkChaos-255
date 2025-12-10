-- DC-Central: shared constants and utilities for DC addons
local DCCentral = DCCentral or {}
_G.DCCentral = DCCentral

-- Keystone item IDs (M+2 through M+20): mirror server constants
DCCentral.KEYSTONE_ITEM_IDS = {
    [300313] = true, [300314] = true, [300315] = true, [300316] = true, [300317] = true,
    [300318] = true, [300319] = true, [300320] = true, [300321] = true, [300322] = true,
    [300323] = true, [300324] = true, [300325] = true, [300326] = true, [300327] = true,
    [300328] = true, [300329] = true, [300330] = true, [300331] = true,
}

-- Create a single shared tooltip for item scanning; created on PLAYER_LOGIN
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event)
    if not DCCentral.scanTooltip then
        DCCentral.scanTooltip = CreateFrame("GameTooltip", "DCScanTooltip", nil, "GameTooltipTemplate")
        DCCentral.scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    end
    -- Set a global alias for other code that expects a global tooltip name (for convenience)
    rawset(_G, "DCScanTooltip", DCCentral.scanTooltip)
    -- If DCAddonProtocol is present, copy mapping and shared tooltip
    local DC = rawget(_G, "DCAddonProtocol")
    if DC then
        DC.KEYSTONE_ITEM_IDS = DCCentral.KEYSTONE_ITEM_IDS
        DC.ScanTooltip = DCCentral.scanTooltip
    end
end)

return DCCentral
