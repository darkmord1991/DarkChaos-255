--[[
    DC-Welcome WelcomeFrame.lua
    Main welcome popup frame with tabbed interface
    
    Tabs:
    - What's New: Season info, recent updates
    - Getting Started: New player guide
    - Features: DC system overviews
    - FAQ: Common questions
    - Community: Discord, website links
    
    Author: DarkChaos-255
    Date: January 2025
]]

local addonName = "DC-Welcome"
DCWelcome = DCWelcome or {}
local L = DCWelcome.L

-- =============================================================================
-- Frame Dimensions
-- =============================================================================

local FRAME_WIDTH = 700
local FRAME_HEIGHT = 500
local TAB_HEIGHT = 30
local CONTENT_PADDING = 15
local SCROLL_WIDTH = 630
local SCROLL_HEIGHT = 380

-- =============================================================================
-- Local Variables
-- =============================================================================

local frame = nil
local contentFrames = {}
local currentTab = "whatsnew"

-- =============================================================================
-- Utility Functions
-- =============================================================================

local function CreateTexture(parent, r, g, b, a)
    local tex = parent:CreateTexture(nil, "BACKGROUND")
    tex:SetAllPoints()
    tex:SetTexture(r, g, b, a or 1)  -- 3.3.5 uses SetTexture with RGBA
    return tex
end

local function CreateFontString(parent, fontObject, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", fontObject or "GameFontNormal")
    if text then fs:SetText(text) end
    return fs
end

-- =============================================================================
-- Tab Button Creation
-- =============================================================================

local function CreateTabButton(parent, id, label, icon, xOffset)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(100, TAB_HEIGHT - 2)
    btn:SetPoint("TOPLEFT", xOffset, 0)
    btn.id = id
    
    -- Background
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(0.15, 0.15, 0.15, 1) -- Solid color
    btn.bg = bg
    
    -- Active Accent (Bottom Line)
    local accent = btn:CreateTexture(nil, "ARTWORK")
    accent:SetHeight(3)
    accent:SetPoint("BOTTOMLEFT", 0, 0)
    accent:SetPoint("BOTTOMRIGHT", 0, 0)
    accent:SetTexture(1, 0.8, 0, 1) -- Gold
    accent:Hide()
    btn.accent = accent
    
    -- Icon
    if icon then
        local ico = btn:CreateTexture(nil, "ARTWORK")
        ico:SetSize(16, 16)
        ico:SetPoint("LEFT", 8, 0)
        ico:SetTexture(icon)
        btn.icon = ico
    end
    
    -- Label
    local txt = CreateFontString(btn, "GameFontNormalSmall", label)
    if icon then
        txt:SetPoint("LEFT", btn.icon, "RIGHT", 5, 0)
    else
        txt:SetPoint("CENTER", 0, 0)
    end
    txt:SetTextColor(0.7, 0.7, 0.7)
    btn.text = txt
    
    -- Highlight
    btn:SetScript("OnEnter", function(self)
        if currentTab ~= self.id then
            self.bg:SetTexture(0.25, 0.25, 0.25, 1)
            self.text:SetTextColor(1, 1, 1)
        end
    end)
    
    btn:SetScript("OnLeave", function(self)
        if currentTab ~= self.id then
            self.bg:SetTexture(0.15, 0.15, 0.15, 1)
            self.text:SetTextColor(0.7, 0.7, 0.7)
        end
    end)
    
    btn:SetScript("OnClick", function(self)
        frame:SelectTab(self.id)
    end)
    
    return btn
end

-- =============================================================================
-- Content Frame Creation
-- =============================================================================

local function CreateScrollableContent(parent, id)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(SCROLL_WIDTH + 20, SCROLL_HEIGHT)
    -- Position below title bar (50) + tabs (TAB_HEIGHT) + padding
    container:SetPoint("TOP", 0, -90)
    container:Hide()
    container.id = id
    
    -- Scroll frame with clipping
    local scrollFrame = CreateFrame("ScrollFrame", "DCWelcome_Scroll_" .. id, container, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(SCROLL_WIDTH, SCROLL_HEIGHT - 10)
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    
    -- Scroll child
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(SCROLL_WIDTH - 20, 1)  -- Height set dynamically
    scrollFrame:SetScrollChild(scrollChild)
    container.scrollChild = scrollChild
    
    return container
end

-- =============================================================================
-- What's New Tab
-- =============================================================================

local function PopulateWhatsNew(scrollChild)
    local yOffset = -10
    
    -- Season header
    local season = DCWelcome:GetCurrentSeason()
    local header = CreateFontString(scrollChild, "GameFontNormalLarge")
    header:SetPoint("TOP", 0, yOffset)
    header:SetText(string.format(L["WHATS_NEW_HEADER"], season.id or 1))
    header:SetTextColor(1, 0.82, 0)
    yOffset = yOffset - 30
    
    -- Intro text
    local intro = CreateFontString(scrollChild, "GameFontHighlight")
    intro:SetPoint("TOPLEFT", 10, yOffset)
    intro:SetWidth(SCROLL_WIDTH - 40)
    intro:SetJustifyH("LEFT")
    intro:SetText(L["WHATS_NEW_INTRO"])
    yOffset = yOffset - intro:GetStringHeight() - 20
    
    -- Features list
    local featuresHeader = CreateFontString(scrollChild, "GameFontNormal")
    featuresHeader:SetPoint("TOPLEFT", 10, yOffset)
    featuresHeader:SetText("|cffffd700Server Features:|r")
    yOffset = yOffset - 25
    
    for _, feature in ipairs(L["WHATS_NEW_FEATURES"]) do
        local bullet = CreateFontString(scrollChild, "GameFontHighlight")
        bullet:SetPoint("TOPLEFT", 20, yOffset)
        bullet:SetWidth(SCROLL_WIDTH - 60)
        bullet:SetJustifyH("LEFT")
        bullet:SetText("• " .. feature)
        yOffset = yOffset - bullet:GetStringHeight() - 8
    end
    
    -- Server info (if available)
    local info = DCWelcome:GetServerInfo()
    if info.name or info.maxLevel then
        yOffset = yOffset - 15
        
        local infoHeader = CreateFontString(scrollChild, "GameFontNormal")
        infoHeader:SetPoint("TOPLEFT", 10, yOffset)
        infoHeader:SetText("|cffffd700Server Info:|r")
        yOffset = yOffset - 20
        
        if info.maxLevel then
            local levelText = CreateFontString(scrollChild, "GameFontHighlight")
            levelText:SetPoint("TOPLEFT", 20, yOffset)
            levelText:SetText("• Max Level: |cff00ff00" .. info.maxLevel .. "|r")
            yOffset = yOffset - 18
        end
    end
    
    -- Set scroll child height
    scrollChild:SetHeight(math.abs(yOffset) + 20)
end

-- =============================================================================
-- Getting Started Tab
-- =============================================================================

local function PopulateGettingStarted(scrollChild)
    local yOffset = -10
    
    -- Header
    local header = CreateFontString(scrollChild, "GameFontNormalLarge")
    header:SetPoint("TOP", 0, yOffset)
    header:SetText(L["GETTING_STARTED_HEADER"])
    header:SetTextColor(1, 0.82, 0) -- Gold
    yOffset = yOffset - 35
    
    -- Steps
    for i, step in ipairs(L["GETTING_STARTED_STEPS"]) do
        -- Step title
        local title = CreateFontString(scrollChild, "GameFontNormal")
        title:SetPoint("TOPLEFT", 10, yOffset)
        title:SetWidth(SCROLL_WIDTH - 40)
        title:SetJustifyH("LEFT")
        title:SetText(step.title)
        yOffset = yOffset - 22
        
        -- Step text
        local text = CreateFontString(scrollChild, "GameFontHighlight")
        text:SetPoint("TOPLEFT", 25, yOffset)
        text:SetWidth(SCROLL_WIDTH - 60)
        text:SetJustifyH("LEFT")
        text:SetText(step.text)
        yOffset = yOffset - text:GetStringHeight() - 20
    end
    
    -- Helpful commands section
    yOffset = yOffset - 10
    local cmdHeader = CreateFontString(scrollChild, "GameFontNormal")
    cmdHeader:SetPoint("TOPLEFT", 10, yOffset)
    cmdHeader:SetText("|cffffd700Helpful Commands:|r")
    yOffset = yOffset - 22
    
    local commands = {
        { cmd = "/welcome", desc = "Open this welcome screen" },
        { cmd = "/faq", desc = "Open FAQ section" },
        { cmd = "/hotspot", desc = "View current hotspot zones" },
        { cmd = "/mplus", desc = "Mythic+ HUD controls" },
        { cmd = "/discord", desc = "Get Discord invite link" },
        { cmd = "/help", desc = "Full command list" },
    }
    
    for _, cmdInfo in ipairs(commands) do
        local cmdText = CreateFontString(scrollChild, "GameFontHighlight")
        cmdText:SetPoint("TOPLEFT", 25, yOffset)
        cmdText:SetText("|cfffff000" .. cmdInfo.cmd .. "|r - " .. cmdInfo.desc)
        yOffset = yOffset - 18
    end
    
    scrollChild:SetHeight(math.abs(yOffset) + 20)
end

-- =============================================================================
-- Features Tab (Expandable Cards)
-- =============================================================================

-- Track expanded state for each feature card
local expandedFeatures = {}

local function CreateExpandableFeatureCard(parent, feature, yOffset, index)
    local CARD_WIDTH = SCROLL_WIDTH - 30
    local HEADER_HEIGHT = 60
    local featureId = feature.id or ("feature_" .. index)
    
    -- Main card container - starts at header height, grows when expanded
    local card = CreateFrame("Button", "DCWelcome_Feature_" .. featureId, parent)
    card:SetSize(CARD_WIDTH, HEADER_HEIGHT)
    card:SetPoint("TOPLEFT", 10, yOffset)
    card.featureId = featureId
    card.isExpanded = expandedFeatures[featureId] or false
    
    -- Background for entire card
    local bg = CreateTexture(card, 0.15, 0.15, 0.15, 0.95)
    card.bg = bg
    
    -- Left color bar (accent) - anchored to full card height
    local colorBar = card:CreateTexture(nil, "ARTWORK")
    colorBar:SetWidth(4)
    colorBar:SetPoint("TOPLEFT", 5, -5)
    colorBar:SetPoint("BOTTOMLEFT", 5, 5)
    local r, g, b = 0.5, 0.5, 1  -- Default blue
    if feature.color then
        r, g, b = unpack(feature.color)
    end
    colorBar:SetTexture(r, g, b, 1)
    card.colorBar = colorBar
    
    -- =========================================================================
    -- HEADER SECTION (always visible)
    -- =========================================================================
    local headerFrame = CreateFrame("Frame", nil, card)
    headerFrame:SetSize(CARD_WIDTH - 20, HEADER_HEIGHT)
    headerFrame:SetPoint("TOPLEFT", 15, 0)
    
    -- Icon (left side of header)
    local icon = headerFrame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(40, 40)
    icon:SetPoint("LEFT", 5, 0)
    icon:SetTexture(feature.icon)
    card.icon = icon
    
    -- Feature name (next to icon)
    local name = CreateFontString(headerFrame, "GameFontNormalLarge")
    name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -5)
    name:SetText(feature.name)
    card.nameText = name
    
    -- Short description (below name)
    local shortDesc = CreateFontString(headerFrame, "GameFontHighlight")
    shortDesc:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
    shortDesc:SetWidth(CARD_WIDTH - 130)
    shortDesc:SetJustifyH("LEFT")
    shortDesc:SetText(feature.shortDesc or "")
    card.shortDesc = shortDesc
    
    -- Expand/collapse indicator (right side)
    local expandIcon = headerFrame:CreateTexture(nil, "OVERLAY")
    expandIcon:SetSize(16, 16)
    expandIcon:SetPoint("RIGHT", -5, 0)
    expandIcon:SetTexture("Interface\\Buttons\\UI-PlusButton-Up")
    card.expandIcon = expandIcon
    
    -- =========================================================================
    -- EXPANDED CONTENT SECTION (hidden by default)
    -- =========================================================================
    local expandedFrame = CreateFrame("Frame", nil, card)
    expandedFrame:SetSize(CARD_WIDTH - 30, 1)  -- Height set dynamically
    expandedFrame:SetPoint("TOPLEFT", 20, -HEADER_HEIGHT)
    expandedFrame:Hide()
    card.expandedFrame = expandedFrame
    
    -- Build expanded content
    local expYOffset = -8
    
    -- Full description
    if feature.fullDesc then
        local fullDescText = CreateFontString(expandedFrame, "GameFontHighlight")
        fullDescText:SetPoint("TOPLEFT", 0, expYOffset)
        fullDescText:SetWidth(CARD_WIDTH - 60)
        fullDescText:SetJustifyH("LEFT")
        fullDescText:SetText(feature.fullDesc)
        expYOffset = expYOffset - fullDescText:GetStringHeight() - 10
    end
    
    -- How to access
    if feature.howTo then
        local howToLabel = CreateFontString(expandedFrame, "GameFontNormal")
        howToLabel:SetPoint("TOPLEFT", 0, expYOffset)
        howToLabel:SetText("|cffffd700How to Access:|r")
        expYOffset = expYOffset - 16
        
        local howToText = CreateFontString(expandedFrame, "GameFontHighlight")
        howToText:SetPoint("TOPLEFT", 10, expYOffset)
        howToText:SetWidth(CARD_WIDTH - 70)
        howToText:SetJustifyH("LEFT")
        howToText:SetText(feature.howTo)
        expYOffset = expYOffset - howToText:GetStringHeight() - 10
    end
    
    -- Key features/bullets
    if feature.bullets and #feature.bullets > 0 then
        local bulletsLabel = CreateFontString(expandedFrame, "GameFontNormal")
        bulletsLabel:SetPoint("TOPLEFT", 0, expYOffset)
        bulletsLabel:SetText("|cffffd700Key Features:|r")
        expYOffset = expYOffset - 16
        
        for _, bullet in ipairs(feature.bullets) do
            local bulletText = CreateFontString(expandedFrame, "GameFontHighlight")
            bulletText:SetPoint("TOPLEFT", 10, expYOffset)
            bulletText:SetWidth(CARD_WIDTH - 70)
            bulletText:SetJustifyH("LEFT")
            bulletText:SetText("• " .. bullet)
            expYOffset = expYOffset - bulletText:GetStringHeight() - 3
        end
        expYOffset = expYOffset - 5
    end
    
    -- Unlock requirement
    if feature.unlock then
        local unlockText = CreateFontString(expandedFrame, "GameFontNormalSmall")
        unlockText:SetPoint("TOPLEFT", 0, expYOffset)
        unlockText:SetText("|cff888888" .. feature.unlock .. "|r")
        expYOffset = expYOffset - 16
    end
    
    -- Commands
    if feature.commands and #feature.commands > 0 then
        local cmdLabel = CreateFontString(expandedFrame, "GameFontNormal")
        cmdLabel:SetPoint("TOPLEFT", 0, expYOffset)
        cmdLabel:SetText("|cffffd700Commands:|r")
        expYOffset = expYOffset - 16
        
        for _, cmd in ipairs(feature.commands) do
            local cmdText = CreateFontString(expandedFrame, "GameFontHighlight")
            cmdText:SetPoint("TOPLEFT", 10, expYOffset)
            cmdText:SetText("|cfffff000" .. cmd.cmd .. "|r - " .. cmd.desc)
            expYOffset = expYOffset - 14
        end
    end
    
    -- Calculate and store expanded height
    local expandedHeight = math.abs(expYOffset) + 5
    expandedFrame:SetHeight(expandedHeight)
    card.expandedHeight = expandedHeight
    card.headerHeight = HEADER_HEIGHT
    
    -- =========================================================================
    -- CLICK HANDLER - Expand/Collapse
    -- =========================================================================
    card:SetScript("OnClick", function(self)
        self.isExpanded = not self.isExpanded
        expandedFeatures[self.featureId] = self.isExpanded
        
        if self.isExpanded then
            -- Show expanded content, grow card
            self.expandedFrame:Show()
            self.expandIcon:SetTexture("Interface\\Buttons\\UI-MinusButton-Up")
            self:SetHeight(self.headerHeight + self.expandedHeight)
        else
            -- Hide expanded content, shrink card
            self.expandedFrame:Hide()
            self.expandIcon:SetTexture("Interface\\Buttons\\UI-PlusButton-Up")
            self:SetHeight(self.headerHeight)
        end
        
        -- Trigger layout refresh to reposition cards below this one
        DCWelcome:RefreshFeaturesLayout()
    end)
    
    -- Hover effects
    card:SetScript("OnEnter", function(self)
        self.bg:SetTexture(0.2, 0.2, 0.2, 0.98)
    end)
    
    card:SetScript("OnLeave", function(self)
        self.bg:SetTexture(0.15, 0.15, 0.15, 0.95)
    end)
    
    -- Return card and its current height
    return card, HEADER_HEIGHT
end

local function PopulateFeatures(scrollChild)
    local yOffset = -5
    
    -- Compact intro text (header moved to tab already)
    local intro = CreateFontString(scrollChild, "GameFontHighlight")
    intro:SetPoint("TOP", 0, yOffset)
    intro:SetText("|cff888888Click any feature card to expand details|r")
    yOffset = yOffset - 20
    
    -- Store intro height for layout refresh
    scrollChild.introHeight = 25
    
    -- Feature cards with extended data
    local features = {
        {
            id = "mythicplus",
            name = L["FEATURE_MYTHIC"].name,
            icon = L["FEATURE_MYTHIC"].icon,
            color = {1, 0.5, 0},  -- Orange
            shortDesc = "Scale dungeon difficulty with keystones for better rewards!",
            fullDesc = L["FEATURE_MYTHIC"].desc,
            howTo = "Complete any level 80 Heroic dungeon to receive your first Keystone. Use the Keystone at the Font of Power inside the dungeon to activate Mythic+ mode.",
            bullets = {
                "Keystones level 2-30+ with increasing difficulty",
                "Beat the timer to upgrade your keystone",
                "Weekly affixes add unique challenges",
                "Better loot and upgrade tokens at higher levels",
                "Compete on seasonal leaderboards",
            },
            unlock = L["FEATURE_MYTHIC"].unlock,
            commands = {
                { cmd = "/mplus", desc = "Toggle Mythic+ HUD" },
                { cmd = "/keystone", desc = "View your current keystone" },
            },
        },
        {
            id = "prestige",
            name = L["FEATURE_PRESTIGE"].name,
            icon = L["FEATURE_PRESTIGE"].icon,
            color = {0.64, 0.21, 0.93},  -- Purple
            shortDesc = "Reset to level 1 for permanent account-wide bonuses!",
            fullDesc = L["FEATURE_PRESTIGE"].desc,
            howTo = "At max level, visit the Prestige NPC in your capital city. Choose to Prestige and you'll restart at level 1 with permanent bonuses applied to all characters.",
            bullets = {
                "+5% XP per prestige level (stacks!)",
                "+5% gold find per prestige level",
                "Exclusive prestige titles and mounts",
                "Account-wide bonuses affect all characters",
                "Prestige challenges for extra rewards",
            },
            unlock = L["FEATURE_PRESTIGE"].unlock,
            commands = {
                { cmd = "/prestige", desc = "View prestige status" },
            },
        },
        {
            id = "hotspots",
            name = L["FEATURE_HOTSPOTS"].name,
            icon = L["FEATURE_HOTSPOTS"].icon,
            color = {0, 0.8, 1},  -- Cyan
            shortDesc = "Rotating world zones with bonus XP and special events!",
            fullDesc = L["FEATURE_HOTSPOTS"].desc,
            howTo = "Hotspots rotate every few hours. Use /hotspot to see the current active zone, then travel there for bonus rewards!",
            bullets = {
                "Bonus XP in hotspot zones (up to +50%)",
                "Increased drop rates for items",
                "Rare mob spawns with special loot",
                "Zone-specific events and challenges",
                "Hotspot addon shows active zones on map",
            },
            unlock = L["FEATURE_HOTSPOTS"].unlock,
            commands = {
                { cmd = "/hotspot", desc = "Show current hotspot zones" },
                { cmd = "/dchotspot", desc = "Toggle hotspot overlay" },
            },
        },
        {
            id = "itemupgrade",
            name = L["FEATURE_UPGRADE"].name,
            icon = L["FEATURE_UPGRADE"].icon,
            color = {0, 0.44, 0.87},  -- Blue
            shortDesc = "Enhance your gear beyond normal item level limits!",
            fullDesc = L["FEATURE_UPGRADE"].desc,
            howTo = "Collect Upgrade Tokens from Mythic+ dungeons and raids. Visit the Upgrade NPC in Dalaran to enhance your equipped items.",
            bullets = {
                "Upgrade items up to +10 levels",
                "Each upgrade increases stats proportionally",
                "Higher M+ keys drop better tokens",
                "Seasonal tokens for limited-time upgrades",
                "Artifact system for ultimate gear enhancement",
            },
            unlock = L["FEATURE_UPGRADE"].unlock,
            commands = {
                { cmd = "/upgrade", desc = "Open upgrade interface" },
            },
        },
        {
            id = "seasons",
            name = L["FEATURE_SEASONS"].name,
            icon = L["FEATURE_SEASONS"].icon,
            color = {1, 0.84, 0},  -- Gold
            shortDesc = "Competitive seasons with exclusive rewards and leaderboards!",
            fullDesc = L["FEATURE_SEASONS"].desc,
            howTo = "Seasons run for several months. Earn Season Points by completing M+ runs, raids, and PvP. Climb the leaderboards for exclusive titles!",
            bullets = {
                "Seasonal leaderboards for M+, PvP, and more",
                "Exclusive seasonal mounts and titles",
                "Season Pass with progressive rewards",
                "End-of-season rewards based on ranking",
                "Fresh competition each season",
            },
            unlock = L["FEATURE_SEASONS"].unlock,
            commands = {
                { cmd = "/season", desc = "View current season info" },
                { cmd = "/leaderboard", desc = "Open leaderboards" },
            },
        },
        {
            id = "aoeloot",
            name = L["FEATURE_AOE_LOOT"].name,
            icon = L["FEATURE_AOE_LOOT"].icon,
            color = {0, 1, 0},  -- Green
            shortDesc = "Loot multiple corpses at once with smart filtering!",
            fullDesc = L["FEATURE_AOE_LOOT"].desc,
            howTo = "AOE Looting is enabled by default. Open the settings with /aoeloot to configure quality filters, auto-skinning, and vendor options.",
            bullets = {
                "Loot all nearby corpses with one click",
                "Filter by item quality (white, green, blue, etc.)",
                "Auto-skin beasts after looting",
                "Auto-vendor poor quality items",
                "Gold-only mode for speed farming",
            },
            unlock = L["FEATURE_AOE_LOOT"].unlock,
            commands = {
                { cmd = "/aoeloot", desc = "Open AOE Loot settings" },
                { cmd = "/aoe", desc = "Toggle AOE loot on/off" },
            },
        },
        {
            id = "hlbg",
            name = L["FEATURE_HLBG"] and L["FEATURE_HLBG"].name or "|cffff0000Hinterland Battleground|r",
            icon = L["FEATURE_HLBG"] and L["FEATURE_HLBG"].icon or "Interface\\Icons\\Achievement_bg_winAB",
            color = {1, 0, 0},  -- Red
            shortDesc = "Open-world PvP with objectives and raid-style gameplay!",
            fullDesc = L["FEATURE_HLBG"] and L["FEATURE_HLBG"].desc or "Open-world PvP zone with objective-based gameplay.",
            howTo = "Travel to the Hinterlands and enter the PvP zone. The addon will automatically form raid groups and display objective HUD.",
            bullets = {
                "Capture and hold strategic objectives",
                "Auto raid group formation",
                "Modern HUD with minimap integration",
                "Seasonal rewards and rankings",
                "Class-based tactical gameplay",
            },
            unlock = L["FEATURE_HLBG"] and L["FEATURE_HLBG"].unlock or "Unlocks at level 80",
            commands = {
                { cmd = "/hlbg", desc = "Toggle HLBG HUD" },
                { cmd = "/hlbg join", desc = "Queue for battleground" },
            },
        },
        {
            id = "challenge",
            name = L["FEATURE_CHALLENGE"] and L["FEATURE_CHALLENGE"].name or "|cffff6600Challenge Modes|r",
            icon = L["FEATURE_CHALLENGE"] and L["FEATURE_CHALLENGE"].icon or "Interface\\Icons\\Spell_Shadow_DeathScream",
            color = {1, 0.4, 0},  -- Orange-red
            shortDesc = "Hardcore, Iron Man, and Self-Crafted character modes!",
            fullDesc = L["FEATURE_CHALLENGE"] and L["FEATURE_CHALLENGE"].desc or "Hardcore, Semi-Hardcore, Iron Man, and Self-Crafted modes.",
            howTo = "Select your challenge mode during character creation. Each mode has different restrictions and exclusive rewards!",
            bullets = {
                "Hardcore: Permadeath - one death = gone forever!",
                "Semi-Hardcore: Limited lives per session",
                "Iron Man: Solo play, no trading or AH",
                "Self-Crafted: Only use self-made gear",
                "Exclusive titles and achievements per mode",
            },
            unlock = L["FEATURE_CHALLENGE"] and L["FEATURE_CHALLENGE"].unlock or "Available at character creation",
            commands = {
                { cmd = "/challenge", desc = "View challenge mode status" },
            },
        },
        {
            id = "dungeonquests",
            name = L["FEATURE_DUNGEON_QUESTS"] and L["FEATURE_DUNGEON_QUESTS"].name or "|cff00ff99Dungeon Quest System|r",
            icon = L["FEATURE_DUNGEON_QUESTS"] and L["FEATURE_DUNGEON_QUESTS"].icon or "Interface\\Icons\\INV_Scroll_03",
            color = {0, 1, 0.6},  -- Teal-green
            shortDesc = "Daily and weekly dungeon quests with token rewards!",
            fullDesc = L["FEATURE_DUNGEON_QUESTS"] and L["FEATURE_DUNGEON_QUESTS"].desc or "Daily and weekly dungeon objectives.",
            howTo = "Personal quest NPCs appear when you enter dungeons. Accept quests for bonus tokens and rewards upon completion.",
            bullets = {
                "Daily rotating dungeon objectives",
                "Weekly challenges for raid and special content",
                "Token currency for the upgrade system",
                "Personal quest giver NPCs in dungeons",
                "Bonus rewards for completing on higher difficulties",
            },
            unlock = L["FEATURE_DUNGEON_QUESTS"] and L["FEATURE_DUNGEON_QUESTS"].unlock or "Unlocks at level 80",
            commands = {
                { cmd = "/dq", desc = "View active dungeon quests" },
            },
        },
        {
            id = "vault",
            name = L["FEATURE_VAULT"] and L["FEATURE_VAULT"].name or "|cffa335eeItem Vault|r",
            icon = L["FEATURE_VAULT"] and L["FEATURE_VAULT"].icon or "Interface\\Icons\\INV_Misc_Bag_CoreFelcloth",
            color = {0.64, 0.21, 0.93},  -- Purple
            shortDesc = "Weekly reward caches based on your activity!",
            fullDesc = L["FEATURE_VAULT"] and L["FEATURE_VAULT"].desc or "Weekly reward caches from M+ and raids.",
            howTo = "Complete Mythic+ runs and raid bosses throughout the week. On reset, visit the Vault NPC to claim rewards based on your activity!",
            bullets = {
                "Mythic+ Vault: Rewards based on M+ runs",
                "Raid Vault: Rewards based on boss kills",
                "More activity = more loot choices",
                "Best rewards from highest content completed",
                "Seasonal resets with fresh vault options",
            },
            unlock = L["FEATURE_VAULT"] and L["FEATURE_VAULT"].unlock or "Unlocks at level 80",
            commands = {
                { cmd = "/vault", desc = "View vault progress" },
            },
        },
    }
    
    -- Store cards for layout refresh
    scrollChild.featureCards = {}
    
    for i, feature in ipairs(features) do
        local card, cardHeight = CreateExpandableFeatureCard(scrollChild, feature, yOffset, i)
        table.insert(scrollChild.featureCards, card)
        yOffset = yOffset - cardHeight - 8
    end
    
    scrollChild:SetHeight(math.abs(yOffset) + 20)
    scrollChild.baseYOffset = yOffset
    scrollChild.introHeight = 25  -- Height of intro text area
end

-- Refresh layout when cards expand/collapse
function DCWelcome:RefreshFeaturesLayout()
    local scrollChild = contentFrames and contentFrames.features and contentFrames.features.scrollChild
    if not scrollChild or not scrollChild.featureCards then return end
    
    -- Start below intro text
    local yOffset = -(scrollChild.introHeight or 25)
    
    for _, card in ipairs(scrollChild.featureCards) do
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", 10, yOffset)
        local height = card:GetHeight()
        yOffset = yOffset - height - 6
    end
    
    scrollChild:SetHeight(math.abs(yOffset) + 20)
end

-- =============================================================================
-- FAQ Tab
-- =============================================================================

local function CreateFAQEntry(parent, entry, yOffset, index)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(SCROLL_WIDTH - 30, 20)  -- Height set dynamically
    container:SetPoint("TOPLEFT", 10, yOffset)
    
    -- Question (collapsible header)
    local question = CreateFrame("Button", nil, container)
    question:SetSize(SCROLL_WIDTH - 30, 24)
    question:SetPoint("TOPLEFT", 0, 0)
    
    local qBg = CreateTexture(question, 0.15, 0.15, 0.15, 0.8)
    
    local qText = CreateFontString(question, "GameFontNormal")
    qText:SetPoint("LEFT", 10, 0)
    qText:SetText("|cffffd700Q:|r " .. entry.question)
    
    -- Answer (always visible for simplicity)
    local answer = CreateFontString(container, "GameFontHighlight")
    answer:SetPoint("TOPLEFT", 15, -30)
    answer:SetWidth(SCROLL_WIDTH - 60)
    answer:SetJustifyH("LEFT")
    answer:SetText("|cff888888A:|r " .. entry.answer)
    
    local totalHeight = 30 + answer:GetStringHeight() + 10
    container:SetHeight(totalHeight)
    
    return totalHeight
end

local function PopulateFAQ(scrollChild)
    local yOffset = -10
    
    -- Header
    local header = CreateFontString(scrollChild, "GameFontNormalLarge")
    header:SetPoint("TOP", 0, yOffset)
    header:SetText(L["FAQ_HEADER"])
    header:SetTextColor(1, 0.82, 0) -- Gold
    yOffset = yOffset - 35
    
    -- FAQ entries
    for i, entry in ipairs(L["FAQ_ENTRIES"]) do
        local height = CreateFAQEntry(scrollChild, entry, yOffset, i)
        yOffset = yOffset - height - 10
    end
    
    scrollChild:SetHeight(math.abs(yOffset) + 20)
end

-- =============================================================================
-- Community/Links Tab
-- =============================================================================

local function CreateLinkCard(parent, linkInfo, yOffset)
    local card = CreateFrame("Button", nil, parent)
    card:SetSize(SCROLL_WIDTH - 30, 60)
    card:SetPoint("TOPLEFT", 10, yOffset)
    
    -- Background
    local bg = CreateTexture(card, 0.15, 0.15, 0.15, 0.9)
    card.bg = bg
    
    -- Icon
    local icon = card:CreateTexture(nil, "ARTWORK")
    icon:SetSize(40, 40)
    icon:SetPoint("LEFT", 15, 0)
    icon:SetTexture(linkInfo.icon)
    
    -- Name
    local name = CreateFontString(card, "GameFontNormal")
    name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 15, -5)
    name:SetText("|cff00ccff" .. linkInfo.name .. "|r")
    
    -- URL
    local url = CreateFontString(card, "GameFontHighlight")
    url:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
    url:SetText("|cfffff000" .. linkInfo.url .. "|r")
    
    -- Description
    local desc = CreateFontString(card, "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", url, "BOTTOMLEFT", 0, -3)
    desc:SetText("|cff888888" .. linkInfo.desc .. "|r")
    
    -- Hover effect
    card:SetScript("OnEnter", function(self)
        self.bg:SetTexture(0.2, 0.2, 0.2, 0.95)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Click to copy: " .. linkInfo.url, 1, 1, 1)
        GameTooltip:Show()
    end)
    
    card:SetScript("OnLeave", function(self)
        self.bg:SetTexture(0.15, 0.15, 0.15, 0.9)
        GameTooltip:Hide()
    end)
    
    -- Click to copy
    card:SetScript("OnClick", function()
        if ChatFrame1EditBox then
            ChatFrame1EditBox:SetText(linkInfo.url)
            ChatFrame1EditBox:Show()
            ChatFrame1EditBox:SetFocus()
            ChatFrame1EditBox:HighlightText()
        end
        DCWelcome.Print(L["MSG_LINK_COPIED"])
    end)
    
    return card
end

local function PopulateCommunity(scrollChild)
    local yOffset = -10
    
    -- Server Logo (if exists)
    -- Note: Logo file should be placed at: Interface\AddOns\DC-Welcome\Textures\ServerLogo.tga
    -- Convert PNG to TGA (32-bit) or BLP format for WoW 3.3.5a compatibility
    local logoPath = "Interface\\AddOns\\DC-Welcome\\Textures\\ServerLogo"
    local hasLogo = true  -- Assume logo exists; WoW will show blank if not
    
    if hasLogo then
        local logo = scrollChild:CreateTexture(nil, "ARTWORK")
        logo:SetSize(200, 200)  -- Adjust size as needed
        logo:SetPoint("TOP", 0, yOffset)
        logo:SetTexture(logoPath)
        yOffset = yOffset - 210
    end
    
    -- Header
    local header = CreateFontString(scrollChild, "GameFontNormalLarge")
    header:SetPoint("TOP", 0, yOffset)
    header:SetText(L["LINKS_HEADER"])
    header:SetTextColor(1, 0.82, 0) -- Gold
    yOffset = yOffset - 25
    
    -- Intro
    local intro = CreateFontString(scrollChild, "GameFontHighlight")
    intro:SetPoint("TOP", 0, yOffset)
    intro:SetText(L["LINKS_INTRO"])
    yOffset = yOffset - 30
    
    -- Link cards
    local links = {
        L["LINK_DISCORD"],
        L["LINK_WEBSITE"],
        L["LINK_WIKI"],
        L["LINK_DONATE"],
    }
    
    for _, linkInfo in ipairs(links) do
        CreateLinkCard(scrollChild, linkInfo, yOffset)
        yOffset = yOffset - 70
    end
    
    scrollChild:SetHeight(math.abs(yOffset) + 20)
end

-- =============================================================================
-- Main Frame Creation
-- =============================================================================

function DCWelcome:CreateWelcomeFrame()
    if frame then return frame end
    
    -- Main frame
    frame = CreateFrame("Frame", "DCWelcomeFrame", UIParent)
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:Hide()
    
    -- Background
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(0, 0, 0, 1) -- Black background
    
    -- Title Header Background
    local titleBg = frame:CreateTexture(nil, "ARTWORK")
    titleBg:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    titleBg:SetWidth(350)
    titleBg:SetHeight(64)
    titleBg:SetPoint("TOP", 0, 12)
    
    -- Title text
    local title = CreateFontString(frame, "GameFontNormalLarge")
    title:SetPoint("TOP", titleBg, "TOP", 0, -14)
    title:SetText(L["WELCOME_TITLE"])
    title:SetTextColor(1, 0.82, 0) -- Gold
    
    -- Subtitle
    local subtitle = CreateFontString(frame, "GameFontHighlightSmall")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -2)
    subtitle:SetText(L["WELCOME_SUBTITLE"])
    subtitle:SetTextColor(0.7, 0.7, 0.7)
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
    
    -- Tab container
    local tabContainer = CreateFrame("Frame", nil, frame)
    tabContainer:SetSize(FRAME_WIDTH - 30, TAB_HEIGHT)
    tabContainer:SetPoint("TOP", 0, -55)
    
    -- Create tabs (7 tabs with adjusted width to fit)
    local tabs = {
        { id = "whatsnew", label = L["TAB_WHATS_NEW"], icon = "Interface\\Icons\\Spell_Holy_Restoration" },
        { id = "getstarted", label = L["TAB_GETTING_STARTED"], icon = "Interface\\Icons\\INV_Misc_Book_09" },
        { id = "features", label = L["TAB_FEATURES"], icon = "Interface\\Icons\\Spell_Nature_EnchantArmor" },
        { id = "addons", label = L["TAB_ADDONS"] or "Addons", icon = "Interface\\Icons\\Trade_Engineering" },
        { id = "progress", label = L["TAB_PROGRESS"] or "Progress", icon = "Interface\\Icons\\Achievement_challengemode_gold" },
        { id = "faq", label = L["TAB_FAQ"], icon = "Interface\\Icons\\INV_Misc_QuestionMark" },
        { id = "community", label = L["TAB_LINKS"], icon = "Interface\\Icons\\INV_Letter_15" },
    }
    
    frame.tabs = {}
    local tabX = 0
    local TAB_BUTTON_WIDTH = 95
    for _, tabInfo in ipairs(tabs) do
        local tab = CreateTabButton(tabContainer, tabInfo.id, tabInfo.label, tabInfo.icon, tabX)
        tab:SetWidth(TAB_BUTTON_WIDTH)
        frame.tabs[tabInfo.id] = tab
        tabX = tabX + TAB_BUTTON_WIDTH + 2
    end
    
    -- Create content frames
    contentFrames.whatsnew = CreateScrollableContent(frame, "whatsnew")
    contentFrames.getstarted = CreateScrollableContent(frame, "getstarted")
    contentFrames.features = CreateScrollableContent(frame, "features")
    contentFrames.addons = CreateScrollableContent(frame, "addons")
    contentFrames.progress = CreateScrollableContent(frame, "progress")
    contentFrames.faq = CreateScrollableContent(frame, "faq")
    contentFrames.community = CreateScrollableContent(frame, "community")
    
    -- Store content frames reference for other modules
    DCWelcome.contentFrames = contentFrames
    
    -- Populate content
    PopulateWhatsNew(contentFrames.whatsnew.scrollChild)
    PopulateGettingStarted(contentFrames.getstarted.scrollChild)
    PopulateFeatures(contentFrames.features.scrollChild)
    DCWelcome:PopulateAddonsPanel(contentFrames.addons.scrollChild)
    
    -- Populate progress panel if function exists
    if DCWelcome.PopulateProgressPanel then
        DCWelcome:PopulateProgressPanel(contentFrames.progress.scrollChild)
    end
    
    PopulateFAQ(contentFrames.faq.scrollChild)
    PopulateCommunity(contentFrames.community.scrollChild)
    
    -- Bottom buttons
    local bottomBtns = CreateFrame("Frame", nil, frame)
    bottomBtns:SetSize(FRAME_WIDTH - 30, 30)
    bottomBtns:SetPoint("BOTTOM", 0, 15)
    
    -- Close button
    local closeMainBtn = CreateFrame("Button", nil, bottomBtns, "UIPanelButtonTemplate")
    closeMainBtn:SetSize(100, 25)
    closeMainBtn:SetPoint("RIGHT", -10, 0)
    closeMainBtn:SetText(L["BTN_CLOSE"])
    closeMainBtn:SetScript("OnClick", function() frame:Hide() end)
    
    -- Don't show again checkbox
    local dontShowCheck = CreateFrame("CheckButton", nil, bottomBtns, "UICheckButtonTemplate")
    dontShowCheck:SetSize(24, 24)
    dontShowCheck:SetPoint("LEFT", 10, 0)
    dontShowCheck:SetChecked(DCWelcomeDB and DCWelcomeDB.dismissed)
    
    local dontShowText = CreateFontString(bottomBtns, "GameFontNormalSmall")
    dontShowText:SetPoint("LEFT", dontShowCheck, "RIGHT", 5, 0)
    dontShowText:SetText(L["BTN_DONT_SHOW"])
    
    dontShowCheck:SetScript("OnClick", function(self)
        if self:GetChecked() then
            DCWelcome:DismissWelcome()
        else
            DCWelcome.SaveSetting("dismissed", false)
        end
    end)
    
    -- Tab switching
    function frame:SelectTab(tabId)
        currentTab = tabId
        
        -- Update tab appearances
        for id, tab in pairs(frame.tabs) do
            if id == tabId then
                tab.bg:SetTexture(0.25, 0.25, 0.25, 1)
                tab.text:SetTextColor(1, 1, 1)
                tab.accent:Show()
            else
                tab.bg:SetTexture(0.15, 0.15, 0.15, 1)
                tab.text:SetTextColor(0.7, 0.7, 0.7)
                tab.accent:Hide()
            end
        end
        
        -- Show/hide content frames
        for id, content in pairs(contentFrames) do
            if id == tabId then
                content:Show()
            else
                content:Hide()
            end
        end
    end
    
    -- Update What's New content
    function frame:UpdateWhatsNew()
        -- Clear and repopulate What's New
        local scrollChild = contentFrames.whatsnew.scrollChild
        -- For now, just repopulate
        -- In a full implementation, we'd clear existing elements first
    end
    
    -- Make frame closable with Escape
    tinsert(UISpecialFrames, "DCWelcomeFrame")
    
    -- Select first tab
    frame:SelectTab("whatsnew")
    
    -- Store reference
    DCWelcome:SetWelcomeFrame(frame)
    
    return frame
end

-- Helper print function
DCWelcome.Print = function(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC-Welcome]|r " .. (msg or ""))
    end
end

DCWelcome.SaveSetting = function(key, value)
    DCWelcomeDB = DCWelcomeDB or {}
    DCWelcomeDB[key] = value
end
