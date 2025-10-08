-- HLBG HUD Debug Commands
local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

-- Debug command to check HUD state
SLASH_HLBGHUD1 = '/hlbghud'
function SlashCmdList.HLBGHUD(msg)
    DEFAULT_CHAT_FRAME:AddMessage('|cFF00FF00=== HLBG HUD Debug ===|r')
    
    -- Check if HUD exists
    local hud = HLBG.UI and HLBG.UI.ModernHUD
    DEFAULT_CHAT_FRAME:AddMessage('ModernHUD exists: ' .. (hud and 'YES' or 'NO'))
    
    if hud then
        DEFAULT_CHAT_FRAME:AddMessage('HUD shown: ' .. (hud:IsShown() and 'YES' or 'NO'))
        DEFAULT_CHAT_FRAME:AddMessage('HUD size: ' .. hud:GetWidth() .. 'x' .. hud:GetHeight())
        
        -- Check settings
        DEFAULT_CHAT_FRAME:AddMessage('hudEnabled: ' .. tostring(HinterlandAffixHUDDB.hudEnabled))
        DEFAULT_CHAT_FRAME:AddMessage('showHudEverywhere: ' .. tostring(HinterlandAffixHUDDB.showHudEverywhere))
        DEFAULT_CHAT_FRAME:AddMessage('showHudInWarmup: ' .. tostring(HinterlandAffixHUDDB.showHudInWarmup))
        
        -- Check zone
        local zone = GetRealZoneText and GetRealZoneText() or "Unknown"
        DEFAULT_CHAT_FRAME:AddMessage('Current zone: ' .. zone)
        
        -- Check battleground status
        local inBG = false
        if GetMaxBattlefieldID then
            for i = 1, GetMaxBattlefieldID() do
                local status = GetBattlefieldStatus(i)
                if status == "active" then
                    inBG = true
                    break
                end
            end
        end
        DEFAULT_CHAT_FRAME:AddMessage('In battleground: ' .. (inBG and 'YES' or 'NO'))
    end
    
    DEFAULT_CHAT_FRAME:AddMessage('========================')
end

-- Command to force show HUD for testing
SLASH_HLBGSHOWH1 = '/hlbgshow'
function SlashCmdList.HLBGSHOWH(msg)
    local hud = HLBG.UI and HLBG.UI.ModernHUD
    if hud then
        -- Force enable settings
        HinterlandAffixHUDDB.hudEnabled = true
        HinterlandAffixHUDDB.showHudEverywhere = true
        
        hud:Show()
        DEFAULT_CHAT_FRAME:AddMessage('|cFF00FF00HLBG:|r HUD force shown!')
        
        -- Update with some test data
        if HLBG.UpdateHUD then
            HLBG.UpdateHUD()
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage('|cFFFF0000HLBG:|r HUD not found!')
    end
end