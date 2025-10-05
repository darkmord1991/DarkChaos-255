-- HLBG_DedupeHUD.lua
-- Fix duplicate HUD displays in Hinterland Battleground AddOn

local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

-- Function to detect and manage duplicate HUDs
function HLBG.DedupHUDs()
    -- Find all frames that might be HUDs
    local potentialHUDs = {}
    local mainHUD = nil
    
    -- Local helper function to check if a frame looks like a HUD
    local function isLikelyHUD(frame)
        -- Check if frame has "Affix" or "Time" text in children
        if not frame:GetChildren() then return false end
        
        for _, child in pairs({frame:GetChildren()}) do
            if child:GetObjectType() == "FontString" then
                local text = child:GetText() or ""
                if text:find("Affix:") or text:find("Time:") or text:find("Alliance:") or text:find("Horde:") then
                    return true
                end
            elseif child:GetObjectType() == "Frame" then
                for _, subchild in pairs({child:GetChildren()}) do
                    if subchild:GetObjectType() == "FontString" then
                        local text = subchild:GetText() or ""
                        if text:find("Affix:") or text:find("Time:") or text:find("Alliance:") or text:find("Horde:") then
                            return true
                        end
                    end
                end
            end
        end
        
        -- Also check by name pattern
        local name = frame:GetName() or ""
        return name:find("HUD") or name:find("HLBG") or name:find("Hinterland")
    end
    
    -- Collect all likely HUD frames
    for i = 1, WorldFrame:GetNumChildren() do
        local frame = select(i, WorldFrame:GetChildren())
        if frame and frame:IsShown() and isLikelyHUD(frame) then
            table.insert(potentialHUDs, frame)
        end
    end
    
    -- If HLBG.UI.HUD exists, consider it the main HUD
    if HLBG.UI and HLBG.UI.HUD then
        mainHUD = HLBG.UI.HUD
        
        -- Force it to be visible
        mainHUD:Show()
    end
    
    -- If we found exactly one HUD, make it the main one
    if #potentialHUDs == 1 and not mainHUD then
        mainHUD = potentialHUDs[1]
    end
    
    -- Handle special case of background affix HUD
    local backgroundAffixHUD = nil
    for i, frame in ipairs(potentialHUDs) do
        local name = frame:GetName() or ""
        if name:find("AffixHUD") and frame ~= mainHUD then
            backgroundAffixHUD = frame
            break
        end
    end
    
    -- If we found a background affix HUD but it's not the main one, hide it
    if backgroundAffixHUD and backgroundAffixHUD ~= mainHUD then
        backgroundAffixHUD:Hide()
        print("|cFF33FF99HLBG:|r Hiding duplicate affix HUD")
    end
    
    -- Move affix info from background HUD to main HUD if needed
    if mainHUD and backgroundAffixHUD then
        local function findAffixText(frame)
            for _, child in pairs({frame:GetChildren()}) do
                if child:GetObjectType() == "FontString" then
                    local text = child:GetText() or ""
                    if text:find("Affix:") then
                        return text, child
                    end
                end
            end
            return nil, nil
        end
        
        local affixText, _ = findAffixText(backgroundAffixHUD)
        if affixText then
            -- Extract just the affix name
            local affixName = affixText:match("Affix: ([^%s]+)")
            if affixName and mainHUD and HLBG.UI and HLBG.UI.HUD then
                -- Update the main HUD to display this affix
                HLBG._affixText = affixName
                if type(HLBG.UpdateLiveFromStatus) == 'function' then
                    pcall(HLBG.UpdateLiveFromStatus)
                end
            end
        end
    end
    
    return #potentialHUDs
end

-- Fix duplicate Next/Previous buttons in History tab
function HLBG.FixHistoryButtons()
    if not HLBG.UI or not HLBG.UI.History then return end
    
    local h = HLBG.UI.History
    
    -- Check for duplicate buttons
    local nextButtons = {}
    local prevButtons = {}
    
    -- Collect all buttons in the history frame
    for _, child in pairs({h:GetChildren()}) do
        if child:GetObjectType() == "Button" then
            local text = child:GetText() or ""
            if text == "Next" or text == "Next>" then
                table.insert(nextButtons, child)
            elseif text == "Previous" or text == "<Previous" then
                table.insert(prevButtons, child)
            end
        end
    end
    
    -- Hide duplicate buttons
    if #nextButtons > 1 then
        for i = 2, #nextButtons do
            nextButtons[i]:Hide()
        end
        print("|cFF33FF99HLBG:|r Hiding duplicate Next buttons in History tab")
    end
    
    if #prevButtons > 1 then
        for i = 2, #prevButtons do
            prevButtons[i]:Hide()
        end
        print("|cFF33FF99HLBG:|r Hiding duplicate Previous buttons in History tab")
    end
end

-- Function to ensure stats display correctly
function HLBG.FixStatsDisplay()
    if not HLBG.UI or not HLBG.UI.Stats or not HLBG.UI.Stats.Text then return end
    
    -- Check if stats are empty
    local text = HLBG.UI.Stats.Text:GetText() or ""
    if text == "" or text == "0" then
        -- Set default stats text
        HLBG.UI.Stats.Text:SetText("Alliance: 0  Horde: 0  Draws: 0  Avg: 0 min\n\nClick the Stats tab to refresh data.")
        
        -- Request stats update
        if _G.AIO and _G.AIO.Handle then
            _G.AIO.Handle("HLBG", "Request", "STATS")
        end
        
        print("|cFF33FF99HLBG:|r Requesting stats update")
    end
end

-- Main function to fix all UI issues
function HLBG.FixAllUIIssues()
    -- Fix duplicate HUDs
    HLBG.DedupHUDs()
    
    -- Fix history buttons
    HLBG.FixHistoryButtons()
    
    -- Fix stats display
    HLBG.FixStatsDisplay()
    
    print("|cFF33FF99HLBG:|r UI fixes applied")
end

-- Function to force update the HUD
function HLBG.ForceUpdateHUD()
    -- If we have an explicit UpdateHUD function, call it
    if type(HLBG.UpdateHUD) == 'function' then
        pcall(HLBG.UpdateHUD)
    end
    
    -- If we have the generic update function, call it
    if type(HLBG.UpdateLiveFromStatus) == 'function' then
        pcall(HLBG.UpdateLiveFromStatus)
    end
    
    -- Request a STATUS update
    if _G.AIO and _G.AIO.Handle then
        _G.AIO.Handle("HLBG", "Request", "STATUS")
    end
    
    print("|cFF33FF99HLBG:|r Forced HUD update")
end

-- Register this to run periodically
local fixFrame = CreateFrame("Frame")
fixFrame:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed > 5 then -- Run every 5 seconds
        self.elapsed = 0
        HLBG.FixAllUIIssues()
    end
end)

-- Run once immediately
C_Timer.After(1.0, function()
    HLBG.FixAllUIIssues()
    HLBG.ForceUpdateHUD()
end)

-- Register a command to manually update the HUD
if type(HLBG.safeRegisterSlash) == 'function' then
    HLBG.safeRegisterSlash('HLBGUPDATEHUD', '/hlbgupdatehud', function()
        print("|cFF33FF99HLBG:|r Updating HUD...")
        HLBG.ForceUpdateHUD()
    end)
else
    -- Fallback registration
    _G["SLASH_HLBGUPDATEHUD1"] = "/hlbgupdatehud"
    SlashCmdList["HLBGUPDATEHUD"] = function()
        print("|cFF33FF99HLBG:|r Updating HUD...")
        HLBG.ForceUpdateHUD()
    end
end

-- Register a command to manually trigger fixes
if type(HLBG.safeRegisterSlash) == 'function' then
    HLBG.safeRegisterSlash('HLBGFIXUI', '/hlbgfixui', function()
        print("|cFF33FF99HLBG:|r Running UI fixes...")
        HLBG.FixAllUIIssues()
    end)
else
    -- Fallback registration
    _G["SLASH_HLBGFIXUI1"] = "/hlbgfixui"
    SlashCmdList["HLBGFIXUI"] = function()
        print("|cFF33FF99HLBG:|r Running UI fixes...")
        HLBG.FixAllUIIssues()
    end
end

print("|cFF33FF99HLBG:|r HUD deduplication module loaded")