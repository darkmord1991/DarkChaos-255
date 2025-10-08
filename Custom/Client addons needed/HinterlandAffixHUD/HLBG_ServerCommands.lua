-- HLBG Direct Server Commands
-- Bypass AIO and use direct server commands for immediate testing

SLASH_HLBGSTATSUI1 = '/hlbgstatsui'
function SlashCmdList.HLBGSTATSUI(msg)
    DEFAULT_CHAT_FRAME:AddMessage('|cFFFF9900=== Requesting Stats UI ===|r')
    SendChatMessage('.hlbg statsui', 'GUILD')
end

SLASH_HLBGHISTUI1 = '/hlbghistui' 
function SlashCmdList.HLBGHISTUI(msg)
    DEFAULT_CHAT_FRAME:AddMessage('|cFFFF9900=== Requesting History UI ===|r')
    SendChatMessage('.hlbg historyui', 'GUILD')
end

SLASH_HLBGSTATUS1 = '/hlbgstatus'
function SlashCmdList.HLBGSTATUS(msg)
    DEFAULT_CHAT_FRAME:AddMessage('|cFFFF9900=== Requesting Status ===|r')
    SendChatMessage('.hlbg status', 'GUILD')
end

-- Enhanced force test with manual data entry and comprehensive debugging
SLASH_HLBGTESTDATA1 = '/hlbgtestdata'
function SlashCmdList.HLBGTESTDATA(msg)
    DEFAULT_CHAT_FRAME:AddMessage('|cFF00FFFF=== Testing with Manual Data ===|r')
    
    -- Enable test mode to prevent worldstate overwrites
    HLBG._testDataActive = true
    
    -- Test data matching what server shows (.hlbg status: Alliance=450, Horde=450)
    local testData = {
        allianceResources = 450,
        hordeResources = 450, 
        timeLeft = 2243, -- 37:23 in seconds
        phase = "IN_PROGRESS",
        affixName = "None"
    }
    
    DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99Test Data:|r Alliance=450, Horde=450, Time=37:23, Phase=IN_PROGRESS')
    DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99Test Mode:|r Enabled - worldstate updates disabled for 30 seconds')
    
    -- Method 1: Direct Modern HUD update
    if HLBG.UpdateModernHUD then
        pcall(function()
            HLBG.UpdateModernHUD(testData)
            DEFAULT_CHAT_FRAME:AddMessage('|cFF00FF00HLBG:|r Method 1 - UpdateModernHUD called')
        end)
    else
        DEFAULT_CHAT_FRAME:AddMessage('|cFFFF5555HLBG:|r Method 1 - UpdateModernHUD not found')
    end
    
    -- Method 2: Manual HUD element update with enhanced debugging
    if HLBG.UI and HLBG.UI.ModernHUD and HLBG.UI.ModernHUD.UpdateWithData then
        pcall(function()
            HLBG.UI.ModernHUD.UpdateWithData(testData)
            DEFAULT_CHAT_FRAME:AddMessage('|cFF00FF00HLBG:|r Method 2 - UpdateWithData called')
        end)
    else
        DEFAULT_CHAT_FRAME:AddMessage('|cFFFF5555HLBG:|r Method 2 - UpdateWithData not found')
    end
    
    -- Method 3: Direct element access
    if HLBG.UI and HLBG.UI.ModernHUD then
        local HUD = HLBG.UI.ModernHUD
        pcall(function()
            if HUD.allianceText then 
                HUD.allianceText:SetText("Alliance: 450")
                DEFAULT_CHAT_FRAME:AddMessage('|cFF00FF00HLBG:|r Method 3a - Alliance text set directly')
            end
            if HUD.hordeText then 
                HUD.hordeText:SetText("Horde: 450") 
                DEFAULT_CHAT_FRAME:AddMessage('|cFF00FF00HLBG:|r Method 3b - Horde text set directly')
            end
            if HUD.timerText then 
                HUD.timerText:SetText("Time: 37:23")
                DEFAULT_CHAT_FRAME:AddMessage('|cFF00FF00HLBG:|r Method 3c - Timer text set directly')
            end
            if HUD.phaseText then 
                HUD.phaseText:SetText("IN_PROGRESS")
                DEFAULT_CHAT_FRAME:AddMessage('|cFF00FF00HLBG:|r Method 3d - Phase text set directly')
            end
            
            -- Force visibility and positioning
            HUD:Show()
            HUD:SetAlpha(1.0)
            HUD:SetFrameStrata("HIGH")
            HUD:SetFrameLevel(1000)
            
            DEFAULT_CHAT_FRAME:AddMessage('|cFF00FF00HLBG:|r Method 3 - HUD forced visible and positioned')
        end)
    else
        DEFAULT_CHAT_FRAME:AddMessage('|cFFFF5555HLBG:|r Method 3 - Modern HUD not found')
    end
    
    -- Method 4: Update global RES data
    _G.RES = _G.RES or {}
    _G.RES.A = 450
    _G.RES.H = 450
    _G.RES.END = time() + 2243
    DEFAULT_CHAT_FRAME:AddMessage('|cFF00FF00HLBG:|r Method 4 - Global RES updated')
    
    -- Method 5: Store in HLBG._lastStatus
    HLBG._lastStatus = {
        A = 450,
        H = 450,
        DURATION = 2243,
        phase = "IN_PROGRESS",
        affixName = "None"
    }
    DEFAULT_CHAT_FRAME:AddMessage('|cFF00FF00HLBG:|r Method 5 - HLBG._lastStatus updated')
    
    -- Method 6: Force old HUD visible for comparison
    if _G["HinterlandAffixHUD"] then
        pcall(function()
            _G["HinterlandAffixHUD"]:Show()
            DEFAULT_CHAT_FRAME:AddMessage('|cFF00FF00HLBG:|r Method 6 - Old HUD forced visible')
        end)
    end
    
    -- Verification: Check what's actually displayed
    C_Timer.After(1, function()
        DEFAULT_CHAT_FRAME:AddMessage('|cFF00FFFF=== VERIFICATION (1 second later) ===|r')
        if HLBG.UI and HLBG.UI.ModernHUD then
            local HUD = HLBG.UI.ModernHUD
            local allianceText = HUD.allianceText and HUD.allianceText:GetText() or 'NOT FOUND'
            local hordeText = HUD.hordeText and HUD.hordeText:GetText() or 'NOT FOUND'
            local timerText = HUD.timerText and HUD.timerText:GetText() or 'NOT FOUND'
            local phaseText = HUD.phaseText and HUD.phaseText:GetText() or 'NOT FOUND'
            
            DEFAULT_CHAT_FRAME:AddMessage('Current HUD Display:')
            DEFAULT_CHAT_FRAME:AddMessage('  ' .. allianceText)
            DEFAULT_CHAT_FRAME:AddMessage('  ' .. hordeText)
            DEFAULT_CHAT_FRAME:AddMessage('  ' .. timerText)
            DEFAULT_CHAT_FRAME:AddMessage('  Phase: ' .. phaseText)
            DEFAULT_CHAT_FRAME:AddMessage('  Visible: ' .. (HUD:IsVisible() and 'YES' or 'NO'))
        else
            DEFAULT_CHAT_FRAME:AddMessage('|cFFFF5555VERIFICATION FAILED:|r Modern HUD not found')
        end
    end)
    
    -- Auto-disable test mode after 30 seconds to allow normal worldstate updates
    C_Timer.After(30, function()
        HLBG._testDataActive = false
        DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99Test Mode:|r Disabled - normal worldstate updates resumed')
    end)
end

-- Manual test mode control
SLASH_HLBGTESTMODE1 = '/hlbgtestmode'
function SlashCmdList.HLBGTESTMODE(msg)
    if msg == "on" then
        HLBG._testDataActive = true
        DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99Test Mode:|r Enabled - worldstate updates disabled')
    elseif msg == "off" then
        HLBG._testDataActive = false
        DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99Test Mode:|r Disabled - normal worldstate updates resumed')
    else
        local status = HLBG._testDataActive and "ENABLED" or "DISABLED"
        DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99Test Mode:|r Currently ' .. status)
        DEFAULT_CHAT_FRAME:AddMessage('Usage: /hlbgtestmode on|off')
    end
end