-- HLBG_HUD.lua
local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

-- Minimal HUD wiring: ensure HLBG.UI table exists and provide UpdateHUD/Hide/Unhide helpers
HLBG.UI = HLBG.UI or {}
HLBG.UI.HUD = HLBG.UI.HUD or CreateFrame("Frame", "HLBG_HUD", UIParent)
HLBG.UI.HUD:SetSize(240, 92)
HLBG.UI.HUD:Hide()

function HLBG.UpdateHUD()
    if not HLBG.UI or not HLBG.UI.HUD then return end
    local RES = _G.RES or {A=0,H=0}
    HLBG.UI.HUD:Show()
end

function HLBG.HideBlizzHUDDeep()
    local w = _G["WorldStateAlwaysUpFrame"]
    if not w then return end
    w:Hide()
    if not w._hlbgHooked then
        w._hlbgHooked = true
        w:HookScript("OnShow", function(self)
            if HLBG and (HLBG.UI and HLBG.UI.useAddonHud) then self:Hide() end
        end)
    end
end

function HLBG.UnhideBlizzHUDDeep()
    local w = _G["WorldStateAlwaysUpFrame"]
    if w then w:Show() end
end

_G.HLBG = HLBG
