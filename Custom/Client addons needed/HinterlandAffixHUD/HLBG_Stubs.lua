local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

-- HLBG_Stubs.lua - Minimal compatibility stubs for older clients
-- These provide safe fallbacks for functions the addon expects to exist.

if not HLBG.UpdateHUD then
    function HLBG.UpdateHUD()
        -- No-op stub; real HUD will overwrite this when loaded.
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage('|cFFFFFF00HLBG Debug:|r UpdateHUD stub called (HUD not loaded)')
        end
    end
end

if not HLBG.GetAffixName then
    function HLBG.GetAffixName(affixId)
        local names = {
            [0] =  None,
            [1] = Fortified,
            [2] = Tyrannical,
            [3] = Necrotic,
        }
        return names[tonumber(affixId) or 0] or (Affix  .. tostring(affixId))
    end
end

-- Common small helpers
if not HLBG.PlayerName then
    HLBG.PlayerName = UnitName( player) or Unknown
end

if not HLBG.IsInGroup then
    function HLBG.IsInGroup()
        local num = GetNumGroupMembers and GetNumGroupMembers() or 0
        return (num or 0) > 0
    end
end

if not HLBG.SafePrint then
    function HLBG.SafePrint(...)
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage(table.concat({ ... },  ))
        end
    end
end

return HLBG
