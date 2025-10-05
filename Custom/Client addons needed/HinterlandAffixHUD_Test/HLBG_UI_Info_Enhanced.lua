-- HLBG_UI_Info_Enhanced.lua - Enhanced Info tab for Hinterland Battleground

local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

-- Enhanced Info page handler
function HLBG.ShowEnhancedInfo()
    HLBG._ensureUI('Info')
    local i = HLBG.UI and HLBG.UI.InfoPane
    if not i then return end
    
    -- Initialize UI components if needed
    if not i.enhancedInitialized then
        -- Create scrollable frame for content
        i.ScrollFrame = CreateFrame("ScrollFrame", "HLBG_EnhancedInfoScrollFrame", i, "UIPanelScrollFrameTemplate")
        i.ScrollFrame:SetPoint("TOPLEFT", i, "TOPLEFT", 10, -10)
        i.ScrollFrame:SetPoint("BOTTOMRIGHT", i, "BOTTOMRIGHT", -30, 10)
        
        i.Content = CreateFrame("Frame", "HLBG_EnhancedInfoScrollContent", i.ScrollFrame)
        i.Content:SetSize(i:GetWidth() - 40, 1200)  -- Make it tall enough for all content
        i.ScrollFrame:SetScrollChild(i.Content)
        
        -- Helper function to create headers
        local function CreateHeader(text, anchor, yOffset, size)
            local header = i.Content:CreateFontString(nil, "OVERLAY", size or "GameFontNormal")
            header:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset)
            header:SetPoint("RIGHT", i.Content, "RIGHT", -5, 0)
            header:SetJustifyH("LEFT")
            header:SetText(text)
            header:SetTextColor(1, 0.82, 0) -- Gold
            return header
        end
        
        -- Helper function to create text blocks
        local function CreateTextBlock(text, anchor, yOffset, fontObject)
            local textBlock = i.Content:CreateFontString(nil, "OVERLAY", fontObject or "GameFontHighlight")
            textBlock:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 5, yOffset)
            textBlock:SetPoint("RIGHT", i.Content, "RIGHT", -5, 0)
            textBlock:SetJustifyH("LEFT")
            textBlock:SetText(text)
            return textBlock
        end
        
        -- Main title
        i.MainTitle = i.Content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        i.MainTitle:SetPoint("TOPLEFT", i.Content, "TOPLEFT", 5, -5)
        i.MainTitle:SetPoint("RIGHT", i.Content, "RIGHT", -5, 0)
        i.MainTitle:SetJustifyH("CENTER")
        i.MainTitle:SetText("Hinterland Battleground Information")
        i.MainTitle:SetTextColor(1, 1, 1, 1)
        
        -- ===== OVERVIEW SECTION =====
        i.OverviewHeader = CreateHeader("Overview", i.MainTitle, -25, "GameFontNormalLarge")
        
        i.OverviewText = CreateTextBlock([[
The Hinterland Battleground is a unique PvP experience that combines resource management, strategic combat, and dynamic affixes. Located in The Hinterlands, this battleground supports up to 40 players and features multiple phases of gameplay.

Key Features:
• Dynamic affix system that changes gameplay each battle
• Resource-based victory conditions
• Multiple capture points and objectives
• Warmup phase for preparation and strategy
• Live scoreboard and performance tracking
• Cross-faction communication and coordination]], i.OverviewHeader, -10)
        
        -- ===== GAME MODES SECTION =====
        i.GameModesHeader = CreateHeader("Game Modes & Phases", i.OverviewText, -25, "GameFontNormalLarge")
        
        i.WarmupHeader = CreateHeader("Warmup Phase", i.GameModesHeader, -15)
        i.WarmupText = CreateTextBlock([[
Duration: Variable (typically 2-5 minutes)
Purpose: Team preparation and strategy discussion

During warmup:
• Players can join and prepare their characters
• Affix information is displayed for planning
• No combat or resource generation
• Teams can coordinate strategies
• Queue system manages player entry]], i.WarmupHeader, -10, "GameFontNormal")
        
        i.BattleHeader = CreateHeader("Battle Phase", i.WarmupText, -20)
        i.BattleText = CreateTextBlock([[
Duration: 15-30 minutes (depending on affix)
Objective: First team to reach the resource target wins

Battle mechanics:
• Capture and hold strategic points
• Generate resources through objectives
• Eliminate enemy players for bonus resources
• Adapt strategy based on active affix
• Monitor team performance and positioning]], i.BattleHeader, -10, "GameFontNormal")
        
        -- ===== OBJECTIVES SECTION =====
        i.ObjectivesHeader = CreateHeader("Objectives & Strategy", i.BattleText, -25, "GameFontNormalLarge")
        
        i.ResourcesHeader = CreateHeader("Resource Generation", i.ObjectivesHeader, -15)
        i.ResourcesText = CreateTextBlock([[
Primary Methods:
• Capture Points: Control key locations for steady resource income
• Honor Kills: Eliminate enemy players for immediate resources
• Objective Completion: Special tasks that provide resource bonuses
• Affix Bonuses: Additional methods based on active affix

Strategy Tips:
• Balance offense and defense
• Coordinate team movements
• Adapt to affix effects
• Monitor enemy resource generation
• Use terrain and positioning advantages]], i.ResourcesHeader, -10, "GameFontNormal")
        
        -- ===== AFFIX SYSTEM SECTION =====
        i.AffixSystemHeader = CreateHeader("Affix System", i.ResourcesText, -25, "GameFontNormalLarge")
        
        i.AffixInfoText = CreateTextBlock([[
Each battle features a unique affix that modifies gameplay mechanics. Affixes are randomly selected and affect both teams equally, requiring adaptive strategies.

Affix Categories:
• Resource Modifiers: Change how resources are gained or lost
• Combat Modifiers: Affect player abilities and damage
• Environmental Effects: Add new mechanics to the battlefield
• Tactical Modifiers: Change optimal strategies and positioning

The affix is announced during warmup, allowing teams to plan accordingly. Understanding affix effects is crucial for victory.]], i.AffixSystemHeader, -10)
        
        -- ===== ADDON FEATURES SECTION =====
        i.AddonFeaturesHeader = CreateHeader("Addon Features", i.AffixInfoText, -25, "GameFontNormalLarge")
        
        i.HUDHeader = CreateHeader("Heads-Up Display (HUD)", i.AddonFeaturesHeader, -15)
        i.HUDText = CreateTextBlock([[
• Real-time resource tracking for both teams
• Battle timer and phase indicator
• Current affix information
• Player count display
• Performance metrics (ping/FPS)
• Customizable position and appearance]], i.HUDHeader, -10, "GameFontNormal")
        
        i.ScoreboardHeader = CreateHeader("Live Scoreboard", i.HUDText, -20)
        i.ScoreboardText = CreateTextBlock([[
• Individual player statistics
• Honor kills and deaths tracking
• Team performance comparison
• Sortable columns for analysis
• Class-based color coding
• Real-time updates during battle]], i.ScoreboardHeader, -10, "GameFontNormal")
        
        i.StatsHeader = CreateHeader("Statistics & History", i.ScoreboardText, -20)
        i.StatsText = CreateTextBlock([[
• Detailed match history
• Personal performance tracking
• Season-based statistics
• Win/loss ratios by affix
• Performance trends analysis
• Exportable data for external analysis]], i.StatsHeader, -10, "GameFontNormal")
        
        i.PerformanceHeader = CreateHeader("Performance Monitoring", i.StatsText, -20)
        i.PerformanceText = CreateTextBlock([[
• Real-time ping and FPS display
• Network stability monitoring
• Memory usage tracking
• Performance issue alerts
• Historical performance data
• Optimization recommendations]], i.PerformanceHeader, -10, "GameFontNormal")
        
        -- ===== SETTINGS SECTION =====
        i.SettingsInfoHeader = CreateHeader("Customization Options", i.PerformanceText, -25, "GameFontNormalLarge")
        
        i.SettingsText = CreateTextBlock([[
The addon offers extensive customization options:

HUD Settings:
• Enable/disable HUD display
• Scale and transparency adjustment
• Font size selection
• Position locking/unlocking
• Show everywhere or zone-specific

Alerts & Notifications:
• Sound alerts for key events
• Chat message notifications
• Performance warnings
• Visual flash effects
• AFK warnings and auto-teleport

Display Options:
• Modern vs classic scoreboard
• Compact view modes
• Class color coding
• Auto-sorting preferences
• Update frequency control

Performance:
• Telemetry enabling/disabling
• Debug information levels
• Data collection preferences
• Memory optimization settings]], i.SettingsInfoHeader, -10)
        
        -- ===== TROUBLESHOOTING SECTION =====
        i.TroubleshootingHeader = CreateHeader("Troubleshooting", i.SettingsText, -25, "GameFontNormalLarge")
        
        i.CommonIssuesHeader = CreateHeader("Common Issues", i.TroubleshootingHeader, -15)
        i.CommonIssuesText = CreateTextBlock([[
HUD Not Visible:
• Check if HUD is enabled in settings
• Verify show location settings
• Try resetting HUD position
• Ensure addon is loaded properly

Performance Issues:
• Monitor ping and FPS in telemetry
• Reduce addon update frequency
• Disable detailed performance tracking
• Check for addon conflicts

Data Not Updating:
• Verify server connection
• Check if in correct zone
• Restart addon with /reload
• Ensure latest addon version

Commands:
• /hlbg - Main addon interface
• /hlbgperf - Performance monitoring
• /reload - Reload UI and addons]], i.CommonIssuesHeader, -10, "GameFontNormal")
        
        -- ===== CREDITS SECTION =====
        i.CreditsHeader = CreateHeader("Credits & Version", i.CommonIssuesText, -25, "GameFontNormalLarge")
        
        i.CreditsText = CreateTextBlock([[
Hinterland Battleground System:
• Developed by the DC-255 team
• Based on AzerothCore framework
• Custom battleground implementation
• Community-driven improvements

Addon Development:
• HinterlandAffixHUD version ]] .. (HLAFFIXHUD_VERSION or "2.0.0") .. [[

• Modern UI enhancements
• Performance monitoring system
• Enhanced user experience
• Comprehensive settings panel

Special Thanks:
• AzerothCore community
• World of Warcraft addon developers
• Beta testers and feedback providers
• DC-255 server community]], i.CreditsHeader, -10)
        
        -- Version and last update info
        i.VersionInfo = i.Content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        i.VersionInfo:SetPoint("BOTTOMRIGHT", i.Content, "BOTTOMRIGHT", -10, 10)
        i.VersionInfo:SetText("Last updated: " .. date("%Y-%m-%d"))
        i.VersionInfo:SetTextColor(0.6, 0.6, 0.6, 1)
        
        -- Calculate total height for scrolling
        local function updateHeight()
            local totalHeight = 1200 -- Conservative estimate based on content
            i.Content:SetHeight(totalHeight)
        end
        
        -- Update height after rendering
        C_Timer.After(0.1, updateHeight)
        
        i.enhancedInitialized = true
    end
    
    -- Show the UI
    if HLBG.UI and HLBG.UI.Frame and type(ShowTab) == "function" then
        HLBG.UI.Frame:Show()
        ShowTab(7)  -- Show Info tab (assuming it's tab 7)
    end
end

-- Register enhanced info handler
if not HLBG._tabHandlers then HLBG._tabHandlers = {} end
HLBG._tabHandlers[7] = HLBG.ShowEnhancedInfo

-- Override the original ShowInfo function
HLBG.ShowInfo = HLBG.ShowEnhancedInfo

_G.HLBG = HLBG