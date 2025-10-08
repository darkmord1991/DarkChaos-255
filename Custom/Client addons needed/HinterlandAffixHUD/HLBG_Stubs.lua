-- HLBG_Stubs.lua - Missing function stubs for compatibility
local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

-- Stub UpdateHUD function (will be replaced by HLBG_HUD_Modern.lua)
if not HLBG.UpdateHUD then
    HLBG.UpdateHUD = function()
        -- Stub - will be replaced by modern HUD
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage('|cFFFFFF00HLBG Debug:|r UpdateHUD stub called (HUD not loaded)')
        end
    end
end

-- Stub affix name function
if not HLBG.GetAffixName then
    HLBG.GetAffixName = function(affixId)
        local names = {
            [0] = "None",
            [1] = "Fortified", 
            [2] = "Tyrannical",
            [3] = "Necrotic"
        }
        return names[tonumber(affixId) or 0] or ("Affix " .. tostring(affixId))
    end
end