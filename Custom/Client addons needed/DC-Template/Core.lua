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
    
    -- DCAddonProtocol integration
    -- Note: DCAddonProtocol uses a shared addon-message prefix (usually "DC")
    -- and routes messages by MODULE/OPCODE. It does not require per-addon prefix registration.
    local DC = rawget(_G, "DCAddonProtocol")
    if DC then
        -- 3.3.5a requires prefixes be registered before SendAddonMessage/CHAT_MSG_ADDON works.
        if type(RegisterAddonMessagePrefix) == "function" then
            pcall(RegisterAddonMessagePrefix, DC.PREFIX or "DC")
        end
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
