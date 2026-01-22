-- WeakAuras Archive - ensures saved variable is a table
-- Modified for DC-QOS integration
local addonName = ...
local loader = CreateFrame("FRAME")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, addon)
  -- Listen for DC-QOS or the original addon name
  if addon == addonName or addon == "DC-QOS" or addon == "WeakAurasArchive" then
    if type(WeakAurasArchive) ~= "table" then
      WeakAurasArchive = {}
    end
    self:UnregisterEvent("ADDON_LOADED")
  end
end)
