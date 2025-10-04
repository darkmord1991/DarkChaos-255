-- HLBG_UI_Info.lua - Enhanced Info tab for Hinterland Battleground

-- Ensure HLBG namespace exists
HLBG = HLBG or {}

-- Info page handler
function HLBG.ShowInfo()
    HLBG._ensureUI('Info')
    local i = HLBG.UI and HLBG.UI.InfoPane
    if not i then return end
    
    -- Initialize UI components if needed
    if not i.initialized then
        -- Create scrollable frame for content
        i.ScrollFrame = CreateFrame("ScrollFrame", "HLBG_InfoScrollFrame", i, "UIPanelScrollFrameTemplate")
        i.ScrollFrame:SetPoint("TOPLEFT", i, "TOPLEFT", 10, -10)
        i.ScrollFrame:SetPoint("BOTTOMRIGHT", i, "BOTTOMRIGHT", -30, 10)
        
        i.Content = CreateFrame("Frame", "HLBG_InfoScrollContent", i.ScrollFrame)
        i.Content:SetSize(i:GetWidth() - 40, 800)  -- Make it tall enough for all content
        i.ScrollFrame:SetScrollChild(i.Content)
        
        -- Main title
        i.Title = i.Content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        i.Title:SetPoint("TOPLEFT", i.Content, "TOPLEFT", 5, -5)
        i.Title:SetPoint("RIGHT", i.Content, "RIGHT", -5, 0)
        i.Title:SetJustifyH("CENTER")
        i.Title:SetText("Hinterland Battleground")
        
        -- Introduction section
        i.IntroTitle = i.Content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        i.IntroTitle:SetPoint("TOPLEFT", i.Title, "BOTTOMLEFT", 0, -20)
        i.IntroTitle:SetText("Introduction")
        i.IntroTitle:SetTextColor(1, 0.82, 0)
        
        i.Intro = i.Content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        i.Intro:SetPoint("TOPLEFT", i.IntroTitle, "BOTTOMLEFT", 5, -5)
        i.Intro:SetPoint("RIGHT", i.Content, "RIGHT", -5, 0)
        i.Intro:SetJustifyH("LEFT")
        i.Intro:SetText(
            "The Hinterland Battleground is a special PvP area located in The Hinterlands. "..
            "It features unique gameplay mechanics and special affix modifiers that change the battleground experience. "..
            "Two teams of players, Alliance and Horde, compete for resources and victory in this dynamic environment."
        )
        
        -- How to Join section
        i.JoinTitle = i.Content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        i.JoinTitle:SetPoint("TOPLEFT", i.Intro, "BOTTOMLEFT", -5, -15)
        i.JoinTitle:SetText("How to Join")
        i.JoinTitle:SetTextColor(1, 0.82, 0)
        
        i.Join = i.Content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        i.Join:SetPoint("TOPLEFT", i.JoinTitle, "BOTTOMLEFT", 5, -5)
        i.Join:SetPoint("RIGHT", i.Content, "RIGHT", -5, 0)
        i.Join:SetJustifyH("LEFT")
        i.Join:SetText(
            "To join the Hinterland Battleground:\n"..
            "1. Use the Queue tab in this window, or\n"..
            "2. Type /hlbg queue join in chat, or\n"..
            "3. Use the server command .hlbg join\n\n"..
            "You can also check the current queue status in the Queue tab."
        )
        
        -- Affixes section
        i.AffixTitle = i.Content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        i.AffixTitle:SetPoint("TOPLEFT", i.Join, "BOTTOMLEFT", -5, -15)
        i.AffixTitle:SetText("Affixes")
        i.AffixTitle:SetTextColor(1, 0.82, 0)
        
        i.Affix = i.Content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        i.Affix:SetPoint("TOPLEFT", i.AffixTitle, "BOTTOMLEFT", 5, -5)
        i.Affix:SetPoint("RIGHT", i.Content, "RIGHT", -5, 0)
        i.Affix:SetJustifyH("LEFT")
        i.Affix:SetText(
            "Each battleground match features a special affix that modifies gameplay:\n\n"..
            "• Different affixes provide unique modifiers to gameplay\n"..
            "• Affixes can affect resources, abilities, or environmental factors\n"..
            "• The current affix is displayed at the top of your screen while in the battleground\n"..
            "• View detailed information about all affixes in the Affixes tab\n\n"..
            "Some popular affixes include: Stormy (lightning strikes), Zeal (increased resource gain), "..
            "Volcanic (eruptions damage players), and many more."
        )
        
        -- Resources section
        i.ResourceTitle = i.Content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        i.ResourceTitle:SetPoint("TOPLEFT", i.Affix, "BOTTOMLEFT", -5, -15)
        i.ResourceTitle:SetText("Resources & Victory")
        i.ResourceTitle:SetTextColor(1, 0.82, 0)
        
        i.Resource = i.Content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        i.Resource:SetPoint("TOPLEFT", i.ResourceTitle, "BOTTOMLEFT", 5, -5)
        i.Resource:SetPoint("RIGHT", i.Content, "RIGHT", -5, 0)
        i.Resource:SetJustifyH("LEFT")
        i.Resource:SetText(
            "The battleground is based on resource gathering:\n\n"..
            "• Each team collects resources from special nodes or by defeating opponents\n"..
            "• The first team to reach 1000 resources wins\n"..
            "• If the time limit is reached, the team with the most resources wins\n"..
            "• A match can end in a draw if both teams have equal resources when time expires\n\n"..
            "Resource gain and other aspects may be modified by the active affix."
        )
        
        -- Addon Features section
        i.AddonTitle = i.Content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        i.AddonTitle:SetPoint("TOPLEFT", i.Resource, "BOTTOMLEFT", -5, -15)
        i.AddonTitle:SetText("About This Addon")
        i.AddonTitle:SetTextColor(1, 0.82, 0)
        
        i.Addon = i.Content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        i.Addon:SetPoint("TOPLEFT", i.AddonTitle, "BOTTOMLEFT", 5, -5)
        i.Addon:SetPoint("RIGHT", i.Content, "RIGHT", -5, 0)
        i.Addon:SetJustifyH("LEFT")
        i.Addon:SetText(
            "The Hinterland Affix HUD addon provides enhanced features for the battleground:\n\n"..
            "• Live - Shows current match information\n"..
            "• History - View past match results\n"..
            "• Stats - Statistics about battleground outcomes\n"..
            "• Queue - Join or leave the battleground queue\n"..
            "• Info - This information page\n"..
            "• Results - Detailed match results\n"..
            "• Settings - Configure addon appearance and behavior\n\n"..
            "Use /hlbg or /hinterland commands to open this window at any time."
        )
        
        -- Commands section
        i.CommandTitle = i.Content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        i.CommandTitle:SetPoint("TOPLEFT", i.Addon, "BOTTOMLEFT", -5, -15)
        i.CommandTitle:SetText("Useful Commands")
        i.CommandTitle:SetTextColor(1, 0.82, 0)
        
        i.Command = i.Content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        i.Command:SetPoint("TOPLEFT", i.CommandTitle, "BOTTOMLEFT", 5, -5)
        i.Command:SetPoint("RIGHT", i.Content, "RIGHT", -5, 0)
        i.Command:SetJustifyH("LEFT")
        i.Command:SetText(
            "/hlbg - Open this window\n"..
            "/hlbg queue join - Join the queue\n"..
            "/hlbg queue leave - Leave the queue\n"..
            "/hlaffix - Configure the affix display\n"..
            "/hlbg season <number> - View stats for a specific season\n"..
            "/hlbg devmode on|off - Enable/disable developer mode\n\n"..
            "For server commands, use:\n"..
            ".hlbg join - Join the queue\n"..
            ".hlbg leave - Leave the queue\n"..
            ".hlbg status - Check your queue status"
        )
        
        -- Credits section
        i.CreditsTitle = i.Content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        i.CreditsTitle:SetPoint("TOPLEFT", i.Command, "BOTTOMLEFT", -5, -15)
        i.CreditsTitle:SetText("Credits")
        i.CreditsTitle:SetTextColor(1, 0.82, 0)
        
        i.Credits = i.Content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        i.Credits:SetPoint("TOPLEFT", i.CreditsTitle, "BOTTOMLEFT", 5, -5)
        i.Credits:SetPoint("RIGHT", i.Content, "RIGHT", -5, 0)
        i.Credits:SetJustifyH("LEFT")
        i.Credits:SetText(
            "Hinterland Battleground developed by DC-255 team.\n"..
            "Affix HUD Addon version: 1.5.0"
        )
        
        -- Calculate total content height for scrolling
        local function updateHeight()
            local totalHeight = i.Title:GetHeight() + 20 +
                i.IntroTitle:GetHeight() + 5 + i.Intro:GetStringHeight() + 15 +
                i.JoinTitle:GetHeight() + 5 + i.Join:GetStringHeight() + 15 +
                i.AffixTitle:GetHeight() + 5 + i.Affix:GetStringHeight() + 15 +
                i.ResourceTitle:GetHeight() + 5 + i.Resource:GetStringHeight() + 15 +
                i.AddonTitle:GetHeight() + 5 + i.Addon:GetStringHeight() + 15 +
                i.CommandTitle:GetHeight() + 5 + i.Command:GetStringHeight() + 15 +
                i.CreditsTitle:GetHeight() + 5 + i.Credits:GetStringHeight() + 20
            
            i.Content:SetHeight(math.max(400, totalHeight))
        end
        
        -- Update height - use our custom timer implementation
        C_Timer.After(0.1, updateHeight)
        
        i.initialized = true
    end
    
    -- Show the UI
    if HLBG.UI and HLBG.UI.Frame and type(ShowTab) == "function" then
        HLBG.UI.Frame:Show()
        ShowTab(5)  -- Show Info tab
    end
end

-- Register this function to be called when Info tab is selected
if not HLBG._tabHandlers then HLBG._tabHandlers = {} end
HLBG._tabHandlers[5] = HLBG.ShowInfo