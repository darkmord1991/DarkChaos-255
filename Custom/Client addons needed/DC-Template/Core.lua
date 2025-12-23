local addonName, NS = ...
NS.addonName = addonName

-- Initialize
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        NS:OnLoad()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

function NS:OnLoad()
    print("|cffFFCC00" .. addonName .. "|r loaded.")
    
    -- Register Protocol
    if DCAddonProtocol then
        -- Register a unique prefix for this addon (max 16 chars)
        DCAddonProtocol:RegisterPrefix("DCTEMP") 
    end
    
    -- Initialize UI
    if NS.UI then
        NS.UI:Init()
    end
end

-- Slash Command
SLASH_DCTEMPLATE1 = "/dctemplate"
SlashCmdList["DCTEMPLATE"] = function(msg)
    if NS.UI then
        NS.UI:Toggle()
    end
end
