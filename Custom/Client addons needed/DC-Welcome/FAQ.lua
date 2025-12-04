--[[
    DC-Welcome FAQ.lua
    Expandable FAQ system with search and categories
    
    Features:
    - Collapsible FAQ entries
    - Search/filter functionality
    - Category organization
    - Server-synced FAQ updates
    
    Author: DarkChaos-255
    Date: January 2025
]]

local addonName = "DC-Welcome"
DCWelcome = DCWelcome or {}
local L = DCWelcome.L

-- =============================================================================
-- FAQ Data Extension
-- =============================================================================

-- Categories for organizing FAQ entries
DCWelcome.FAQCategories = {
    { id = "general", name = "General", icon = "Interface\\Icons\\INV_Misc_QuestionMark" },
    { id = "mythicplus", name = "Mythic+", icon = "Interface\\Icons\\Achievement_challengemode_gold" },
    { id = "prestige", name = "Prestige", icon = "Interface\\Icons\\Achievement_level_80" },
    { id = "systems", name = "Server Systems", icon = "Interface\\Icons\\Trade_Engineering" },
    { id = "community", name = "Community", icon = "Interface\\Icons\\Achievement_guildperk_everybodysfriend" },
}

-- Extended FAQ entries with categories
DCWelcome.ExtendedFAQ = {
    -- General
    {
        id = 1,
        category = "general",
        question = "What makes DarkChaos-255 different from other servers?",
        answer = "DarkChaos-255 is a custom WotLK server featuring Mythic+ dungeons, a Prestige system, dynamic Hotspots, item upgrades, and seasonal content. We focus on end-game progression with multiple paths to gear up.",
    },
    {
        id = 2,
        category = "general",
        question = "Is this server pay-to-win?",
        answer = "No. All gear and power progression can be achieved through gameplay. Our shop offers cosmetics and convenience items only. Donate to support the server, not to gain advantage.",
    },
    {
        id = 3,
        category = "general",
        question = "What's the server's max level?",
        answer = "The max level is 80, same as retail WotLK. However, our Prestige system allows you to reset and gain permanent account-wide bonuses.",
    },
    
    -- Mythic+
    {
        id = 10,
        category = "mythicplus",
        question = "How do I get my first keystone?",
        answer = "Complete any heroic dungeon at level 80. A level 2 keystone will appear in your bags. Higher keys drop from completing M+ runs within the timer.",
    },
    {
        id = 11,
        category = "mythicplus",
        question = "What are affixes?",
        answer = "Affixes are modifiers that add difficulty to M+ runs. They rotate weekly. Examples: Fortified (stronger trash), Tyrannical (stronger bosses), Bolstering (enemies buff nearby mobs on death).",
    },
    {
        id = 12,
        category = "mythicplus",
        question = "How does the timer work?",
        answer = "Each dungeon has a par time. Beat it to upgrade your key (+1 level, or +2/+3 for very fast runs). Fail and your key depletes (lowered by 1 level).",
    },
    {
        id = 13,
        category = "mythicplus",
        question = "Can I do M+ solo?",
        answer = "Technically yes, but it's designed for groups. Mobs scale to 5 players. Use /lfg or the Group Finder NPC to find parties.",
    },
    
    -- Prestige
    {
        id = 20,
        category = "prestige",
        question = "What is the Prestige system?",
        answer = "At level 80, you can 'prestige' to reset your character to level 1. In exchange, you gain permanent account-wide bonuses that apply to ALL your characters.",
    },
    {
        id = 21,
        category = "prestige",
        question = "What bonuses does Prestige give?",
        answer = "Each prestige level grants: +5% XP rate, +3% gold find, +2% drop rate, and unlocks cosmetic rewards like titles and mounts.",
    },
    {
        id = 22,
        category = "prestige",
        question = "Do I lose my gear when I prestige?",
        answer = "Your gear is stored in a special 'Prestige Vault' accessible at level 80. You don't lose items, but you can't equip high-level gear until you level up again.",
    },
    {
        id = 23,
        category = "prestige",
        question = "Is there a max Prestige level?",
        answer = "Currently Prestige 10 is the maximum. Each level takes progressively more effort but gives better rewards.",
    },
    
    -- Server Systems
    {
        id = 30,
        category = "systems",
        question = "How do Hotspots work?",
        answer = "Hotspots are zones that rotate every few hours with active bonuses. Check /hotspot to see current zones. Bonuses include +50% XP, +25% drops, rare mob spawns, and world events.",
    },
    {
        id = 31,
        category = "systems",
        question = "How do Item Upgrades work?",
        answer = "Visit the Upgrade NPC in Dalaran with upgrade tokens. Each upgrade increases item level by 6. Tokens drop from M+ and raids, with higher content dropping better tokens.",
    },
    {
        id = 32,
        category = "systems",
        question = "What are Seasonal rewards?",
        answer = "Each 3-month season has unique rewards: mounts, titles, transmog. Compete on leaderboards or complete seasonal challenges to earn them before they're gone!",
    },
    {
        id = 33,
        category = "systems",
        question = "How does AOE Looting work?",
        answer = "Kill enemies, then loot one corpse to collect from all nearby corpses. Configure settings with /aoe or in DC-Central addon: quality filter, auto-skin, loot range.",
    },
    
    -- Community
    {
        id = 40,
        category = "community",
        question = "How do I report a bug?",
        answer = "Use /bug in-game or post in #bug-reports on Discord. Include: what happened, where you were, and steps to reproduce.",
    },
    {
        id = 41,
        category = "community",
        question = "Where can I find a guild?",
        answer = "Check #guild-recruitment on Discord, or use /gf (Guild Finder) in-game. Many guilds recruit for M+ and raids.",
    },
    {
        id = 42,
        category = "community",
        question = "How do I become a tester/helper?",
        answer = "Active community members may be invited to help test new features. Participate in Discord, report bugs constructively, and help other players.",
    },
}

-- =============================================================================
-- FAQ Search & Filter Functions
-- =============================================================================

function DCWelcome:SearchFAQ(query)
    if not query or query == "" then
        return self.ExtendedFAQ
    end
    
    query = string.lower(query)
    local results = {}
    
    for _, entry in ipairs(self.ExtendedFAQ) do
        local qLower = string.lower(entry.question)
        local aLower = string.lower(entry.answer)
        
        if string.find(qLower, query) or string.find(aLower, query) then
            table.insert(results, entry)
        end
    end
    
    return results
end

function DCWelcome:GetFAQByCategory(categoryId)
    if not categoryId or categoryId == "all" then
        return self.ExtendedFAQ
    end
    
    local results = {}
    for _, entry in ipairs(self.ExtendedFAQ) do
        if entry.category == categoryId then
            table.insert(results, entry)
        end
    end
    
    return results
end

function DCWelcome:GetFAQEntry(id)
    for _, entry in ipairs(self.ExtendedFAQ) do
        if entry.id == id then
            return entry
        end
    end
    return nil
end

-- =============================================================================
-- FAQ Panel Creation (Standalone Window)
-- =============================================================================

local faqFrame = nil

function DCWelcome:CreateFAQPanel()
    if faqFrame then return faqFrame end
    
    local PANEL_WIDTH = 500
    local PANEL_HEIGHT = 450
    
    faqFrame = CreateFrame("Frame", "DCWelcomeFAQPanel", UIParent)
    faqFrame:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    faqFrame:SetPoint("CENTER")
    faqFrame:SetFrameStrata("DIALOG")
    faqFrame:EnableMouse(true)
    faqFrame:SetMovable(true)
    faqFrame:SetClampedToScreen(true)
    faqFrame:RegisterForDrag("LeftButton")
    faqFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    faqFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    faqFrame:Hide()
    
    -- Background
    local bg = faqFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background")
    bg:SetVertexColor(0.06, 0.06, 0.08, 0.98)
    
    -- Border
    local border = CreateFrame("Frame", nil, faqFrame)
    border:SetAllPoints()
    border:SetBackdrop({
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    
    -- Title
    local title = faqFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -15)
    title:SetText("|cff00ccffFrequently Asked Questions|r")
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, faqFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    
    -- Search box
    local searchBox = CreateFrame("EditBox", "DCWelcomeFAQSearch", faqFrame, "InputBoxTemplate")
    searchBox:SetSize(200, 20)
    searchBox:SetPoint("TOPLEFT", 20, -45)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(50)
    
    local searchLabel = faqFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    searchLabel:SetPoint("BOTTOMLEFT", searchBox, "TOPLEFT", 0, 2)
    searchLabel:SetText("Search:")
    
    -- Category dropdown (3.3.5 compatible)
    local catDropdown = CreateFrame("Frame", "DCWelcomeFAQCategoryDropdown", faqFrame, "UIDropDownMenuTemplate")
    catDropdown:SetPoint("LEFT", searchBox, "RIGHT", 10, -2)
    UIDropDownMenu_SetWidth(catDropdown, 120)
    
    local selectedCategory = "all"
    -- Forward declare - will be assigned after PopulateFAQEntries is defined
    local OnCategorySelect
    
    local function InitCategoryDropdown(self, level)
        level = level or 1
        local info = UIDropDownMenu_CreateInfo()
        
        -- "All" option
        info.text = "All Categories"
        info.value = "all"
        info.func = function(self, arg1) OnCategorySelect(self, arg1) end
        info.arg1 = "all"
        info.checked = (selectedCategory == "all")
        UIDropDownMenu_AddButton(info, level)
        
        -- Category options
        for _, cat in ipairs(DCWelcome.FAQCategories) do
            info = UIDropDownMenu_CreateInfo()
            info.text = cat.name
            info.value = cat.id
            info.func = function(self, arg1) OnCategorySelect(self, arg1) end
            info.arg1 = cat.id
            info.checked = (selectedCategory == cat.id)
            info.icon = cat.icon
            UIDropDownMenu_AddButton(info, level)
        end
    end
    
    UIDropDownMenu_Initialize(catDropdown, InitCategoryDropdown)
    UIDropDownMenu_SetText(catDropdown, "All Categories")
    
    faqFrame.categoryDropdown = catDropdown
    faqFrame.selectedCategory = function() return selectedCategory end
    
    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", "DCWelcomeFAQScroll", faqFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(PANEL_WIDTH - 50, PANEL_HEIGHT - 110)
    scrollFrame:SetPoint("TOPLEFT", 15, -75)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(PANEL_WIDTH - 70, 1)
    scrollFrame:SetScrollChild(scrollChild)
    faqFrame.scrollChild = scrollChild
    
    -- Entry frames storage
    faqFrame.entryFrames = {}
    
    -- Populate FAQ (defined as local for dropdown callback reference)
    local function PopulateFAQEntries(entries)
        -- Clear existing
        for _, entryFrame in ipairs(faqFrame.entryFrames) do
            entryFrame:Hide()
            entryFrame:SetParent(nil)
        end
        faqFrame.entryFrames = {}
        
        local yOffset = 0
        
        for _, entry in ipairs(entries) do
            local entryHeight = DCWelcome:CreateCollapsibleFAQEntry(scrollChild, entry, yOffset)
            yOffset = yOffset - entryHeight - 5
        end
        
        scrollChild:SetHeight(math.max(1, math.abs(yOffset)))
    end
    
    -- Store reference for external access
    faqFrame.PopulateFAQEntries = PopulateFAQEntries
    
    -- Update OnCategorySelect to use the local function (now it's defined)
    OnCategorySelect = function(self, categoryId)
        selectedCategory = categoryId
        local catName = "All Categories"
        for _, cat in ipairs(DCWelcome.FAQCategories) do
            if cat.id == categoryId then
                catName = cat.name
                break
            end
        end
        UIDropDownMenu_SetText(catDropdown, catName)
        
        -- Apply filter combined with search
        local query = searchBox:GetText()
        local results
        if categoryId == "all" then
            results = DCWelcome:SearchFAQ(query)
        else
            local catResults = DCWelcome:GetFAQByCategory(categoryId)
            if query and query ~= "" then
                results = {}
                local queryLower = string.lower(query)
                for _, entry in ipairs(catResults) do
                    if string.find(string.lower(entry.question), queryLower) or 
                       string.find(string.lower(entry.answer), queryLower) then
                        table.insert(results, entry)
                    end
                end
            else
                results = catResults
            end
        end
        PopulateFAQEntries(results)
        CloseDropDownMenus()
    end
    
    -- Initial population
    PopulateFAQEntries(DCWelcome.ExtendedFAQ)
    
    -- Search handler (respects category filter)
    searchBox:SetScript("OnTextChanged", function(self)
        local query = self:GetText()
        local results
        if selectedCategory == "all" then
            results = DCWelcome:SearchFAQ(query)
        else
            local catResults = DCWelcome:GetFAQByCategory(selectedCategory)
            if query and query ~= "" then
                results = {}
                local queryLower = string.lower(query)
                for _, entry in ipairs(catResults) do
                    if string.find(string.lower(entry.question), queryLower) or 
                       string.find(string.lower(entry.answer), queryLower) then
                        table.insert(results, entry)
                    end
                end
            else
                results = catResults
            end
        end
        PopulateFAQEntries(results)
    end)
    
    tinsert(UISpecialFrames, "DCWelcomeFAQPanel")
    
    return faqFrame
end

function DCWelcome:CreateCollapsibleFAQEntry(parent, entry, yOffset)
    local ENTRY_WIDTH = 430
    
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(ENTRY_WIDTH, 60)  -- Height adjusted later
    container:SetPoint("TOPLEFT", 0, yOffset)
    table.insert(parent:GetParent():GetParent().entryFrames or {}, container)
    
    -- Question header (clickable)
    local header = CreateFrame("Button", nil, container)
    header:SetSize(ENTRY_WIDTH, 24)
    header:SetPoint("TOPLEFT", 0, 0)
    
    local headerBg = header:CreateTexture(nil, "BACKGROUND")
    headerBg:SetAllPoints()
    headerBg:SetTexture(0.12, 0.18, 0.12, 0.9)
    header.bg = headerBg
    
    -- Expand/collapse indicator
    local indicator = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    indicator:SetPoint("LEFT", 8, 0)
    indicator:SetText("|cffffd700▶|r")
    header.indicator = indicator
    
    -- Question text
    local qText = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    qText:SetPoint("LEFT", 25, 0)
    qText:SetWidth(ENTRY_WIDTH - 35)
    qText:SetJustifyH("LEFT")
    qText:SetText(entry.question)
    
    -- Answer text (initially hidden)
    local answerFrame = CreateFrame("Frame", nil, container)
    answerFrame:SetSize(ENTRY_WIDTH - 20, 20)
    answerFrame:SetPoint("TOPLEFT", 15, -28)
    answerFrame:Hide()
    
    local answerBg = answerFrame:CreateTexture(nil, "BACKGROUND")
    answerBg:SetAllPoints()
    answerBg:SetTexture(0.08, 0.08, 0.08, 0.7)
    
    local aText = answerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    aText:SetPoint("TOPLEFT", 10, -8)
    aText:SetWidth(ENTRY_WIDTH - 40)
    aText:SetJustifyH("LEFT")
    aText:SetText(entry.answer)
    
    -- Calculate answer height
    local answerHeight = aText:GetStringHeight() + 20
    answerFrame:SetHeight(answerHeight)
    
    -- State
    local isExpanded = false
    
    -- Toggle function
    local function ToggleAnswer()
        isExpanded = not isExpanded
        
        if isExpanded then
            answerFrame:Show()
            indicator:SetText("|cffffd700▼|r")
            headerBg:SetTexture(0.15, 0.22, 0.15, 0.95)
            container:SetHeight(28 + answerHeight + 5)
        else
            answerFrame:Hide()
            indicator:SetText("|cffffd700▶|r")
            headerBg:SetTexture(0.12, 0.18, 0.12, 0.9)
            container:SetHeight(28)
        end
    end
    
    header:SetScript("OnClick", ToggleAnswer)
    
    header:SetScript("OnEnter", function(self)
        self.bg:SetTexture(0.18, 0.25, 0.18, 0.95)
    end)
    
    header:SetScript("OnLeave", function(self)
        if isExpanded then
            self.bg:SetTexture(0.15, 0.22, 0.15, 0.95)
        else
            self.bg:SetTexture(0.12, 0.18, 0.12, 0.9)
        end
    end)
    
    -- Initial height (collapsed)
    container:SetHeight(28)
    
    return 28  -- Return collapsed height for layout
end

function DCWelcome:ShowFAQ()
    local panel = DCWelcome:CreateFAQPanel()
    if panel then
        panel:Show()
    end
end

-- =============================================================================
-- Enhanced /faq command
-- =============================================================================

-- Update existing slash command
local originalFaqHandler = SlashCmdList["DCFAQ"]
SlashCmdList["DCFAQ"] = function(msg)
    local args = {}
    for word in string.gmatch(msg or "", "%S+") do
        table.insert(args, string.lower(word))
    end
    
    local cmd = args[1] or ""
    
    if cmd == "search" then
        local query = table.concat(args, " ", 2)
        local results = DCWelcome:SearchFAQ(query)
        if #results > 0 then
            DCWelcome.Print("Found " .. #results .. " FAQ entries:")
            for i, entry in ipairs(results) do
                if i <= 5 then
                    DCWelcome.Print("  |cffffd700Q:|r " .. entry.question)
                end
            end
            if #results > 5 then
                DCWelcome.Print("  ... and " .. (#results - 5) .. " more. Use /faq panel to browse.")
            end
        else
            DCWelcome.Print("No FAQ entries found for: " .. query)
        end
    elseif cmd == "panel" or cmd == "browse" then
        DCWelcome:ShowFAQ()
    elseif cmd == "list" then
        DCWelcome.Print("FAQ Categories:")
        for _, cat in ipairs(DCWelcome.FAQCategories) do
            local count = #DCWelcome:GetFAQByCategory(cat.id)
            DCWelcome.Print("  |cff00ccff" .. cat.name .. "|r (" .. count .. " entries)")
        end
    else
        -- Default: show in welcome frame
        if originalFaqHandler then
            originalFaqHandler(msg)
        else
            DCWelcome:ShowWelcome(true)
            -- Try to switch to FAQ tab
            if DCWelcome.WelcomeFrame and DCWelcome.WelcomeFrame.SelectTab then
                DCWelcome.WelcomeFrame:SelectTab("faq")
            end
        end
    end
end
