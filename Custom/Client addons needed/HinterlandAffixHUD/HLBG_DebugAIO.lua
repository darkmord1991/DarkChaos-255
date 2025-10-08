-- HLBG Debug AIO Flow
-- Test AIO connectivity and data flow

SLASH_HLBGAIO1 = '/hlbgaio'
function SlashCmdList.HLBGAIO(msg)
    DEFAULT_CHAT_FRAME:AddMessage('|cFFFF9900=== AIO Flow Debug ===|r')
    
    -- Check AIO registration
    if _G.AIO then
        DEFAULT_CHAT_FRAME:AddMessage('AIO Global: EXISTS')
        DEFAULT_CHAT_FRAME:AddMessage('AIO.Handle: ' .. ((_G.AIO.Handle and 'EXISTS') or 'MISSING'))
        DEFAULT_CHAT_FRAME:AddMessage('AIO.AddHandlers: ' .. ((_G.AIO.AddHandlers and 'EXISTS') or 'MISSING'))
    else
        DEFAULT_CHAT_FRAME:AddMessage('AIO Global: MISSING')
        return
    end
    
    -- Check if our handlers are registered
    if HLBG and HLBG._aioHandlersRegistered then
        DEFAULT_CHAT_FRAME:AddMessage('HLBG AIO Handlers: REGISTERED (flag set)')
    elseif HLBG and HLBG._aioHandlers then
        DEFAULT_CHAT_FRAME:AddMessage('HLBG AIO Handlers: REGISTERED (table exists)')
        for name, handler in pairs(HLBG._aioHandlers) do
            DEFAULT_CHAT_FRAME:AddMessage('  Handler: ' .. name .. ' = ' .. type(handler))
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage('HLBG AIO Handlers: NOT REGISTERED')
        DEFAULT_CHAT_FRAME:AddMessage('HLBG._aioHandlersRegistered: ' .. tostring(HLBG and HLBG._aioHandlersRegistered))
        DEFAULT_CHAT_FRAME:AddMessage('HLBG._aioHandlers: ' .. tostring(HLBG and HLBG._aioHandlers))
    end
    
    -- Test direct AIO call
    DEFAULT_CHAT_FRAME:AddMessage('Testing direct AIO calls...')
    if _G.AIO and _G.AIO.Handle then
        -- Test simple server call
        pcall(function()
            _G.AIO.Handle("HLBG", "Test", "ping")
            DEFAULT_CHAT_FRAME:AddMessage('AIO Test call sent: ping')
        end)
        
        -- Test data requests
        pcall(function()
            _G.AIO.Handle("HLBG", "Request", "STATUS")
            DEFAULT_CHAT_FRAME:AddMessage('AIO Request sent: STATUS')
        end)
    else
        DEFAULT_CHAT_FRAME:AddMessage('AIO.Handle not available for testing')
    end
    
    -- Check handler functions
    DEFAULT_CHAT_FRAME:AddMessage('Handler Functions:')
    DEFAULT_CHAT_FRAME:AddMessage('  HLBG.HandleAIOCommand: ' .. ((HLBG and type(HLBG.HandleAIOCommand)) or 'nil'))
    DEFAULT_CHAT_FRAME:AddMessage('  HLBG.History: ' .. ((HLBG and type(HLBG.History)) or 'nil'))
    DEFAULT_CHAT_FRAME:AddMessage('  HLBG.Stats: ' .. ((HLBG and type(HLBG.Stats)) or 'nil'))
    
    -- Check initialization state
    if HLBG and HLBG.InitState then
        DEFAULT_CHAT_FRAME:AddMessage('HLBG Init State:')
        for k, v in pairs(HLBG.InitState) do
            DEFAULT_CHAT_FRAME:AddMessage('  ' .. k .. ': ' .. tostring(v))
        end
    end
end

SLASH_HLBGOLDHUD1 = '/hlbgoldhud'
function SlashCmdList.HLBGOLDHUD(msg)
    DEFAULT_CHAT_FRAME:AddMessage('|cFFFF9900=== Old HUD Debug ===|r')
    
    -- Check old HUD frame
    if _G.HinterlandAffixHUD then
        DEFAULT_CHAT_FRAME:AddMessage('Old HUD Frame: EXISTS')
        DEFAULT_CHAT_FRAME:AddMessage('Old HUD Visible: ' .. (_G.HinterlandAffixHUD:IsShown() and 'YES' or 'NO'))
        
        if _G.HinterlandAffixHUD.text then
            local text = _G.HinterlandAffixHUD.text:GetText()
            DEFAULT_CHAT_FRAME:AddMessage('Old HUD Text: "' .. (text or 'EMPTY') .. '"')
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage('Old HUD Frame: MISSING')
    end
    
    -- Check for any other HUD frames
    for i = 1, 10 do
        local frameName = 'HLBG_HUD' .. (i > 1 and i or '')
        local frame = _G[frameName]
        if frame then
            DEFAULT_CHAT_FRAME:AddMessage('Found frame: ' .. frameName .. ' (visible: ' .. (frame:IsShown() and 'YES' or 'NO') .. ')')
        end
    end
end