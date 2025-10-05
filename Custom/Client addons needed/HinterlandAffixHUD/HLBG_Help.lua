-- HLBG_Help.lua - Help documentation for Hinterland Battleground AddOn
-- This file provides help and command documentation for the addon

-- Initialize our addon namespace if needed
if not HLBG then HLBG = {} end

-- Command documentation
HLBG.Commands = {
    {
        command = "/hlbg",
        args = "",
        description = "Open the main Hinterland Battleground interface"
    },
    {
        command = "/hlbg",
        args = "queue join",
        description = "Join the battleground queue"
    },
    {
        command = "/hlbg",
        args = "queue leave",
        description = "Leave the battleground queue"
    },
    {
        command = "/hlbg",
        args = "status",
        description = "Show current battleground status"
    },
    {
        command = "/hlbg",
        args = "debug [on|off]",
        description = "Enable or disable debug mode"
    },
    {
        command = "/hlbg",
        args = "season <n>",
        description = "Set the season filter (0 = all/current)"
    },
    {
        command = "/hlbgconfig",
        args = "",
        description = "Open the addon settings panel"
    },
    {
        command = "/hinterland",
        args = "",
        description = "Alias for /hlbg"
    }
}

-- FAQ content
HLBG.FAQ = {
    {
        question = "How do I join a Hinterland Battleground match?",
        answer = "You can join the queue by clicking the 'Queue' tab in the main interface and then clicking 'Join Queue', or by typing /hlbg queue join in the chat."
    },
    {
        question = "What are affixes?",
        answer = "Affixes are special modifiers that change the gameplay mechanics in each battleground match. Each match features one random affix that significantly alters how the battle plays out. You can see details about all possible affixes in the 'Affixes' tab."
    },
    {
        question = "How do I view my battleground statistics?",
        answer = "Open the main interface with /hlbg and click on the 'Stats' tab to see your win/loss statistics, win rates, and other performance metrics."
    },
    {
        question = "How do I earn resources in the battleground?",
        answer = "Resources can be earned by controlling capture points on the map and by defeating enemy players. The specific mechanics may vary based on the current affix."
    },
    {
        question = "The HUD is too large/small. How do I resize it?",
        answer = "You can adjust the HUD scale in the Settings tab. Open the interface with /hlbg and click on the 'Settings' tab, then use the 'HUD Scale' slider."
    },
    {
        question = "Can I see what happened in my previous matches?",
        answer = "Yes, the 'History' tab shows your recent battleground matches, including the winners, duration, and which affix was active."
    },
    {
        question = "How long do battleground matches last?",
        answer = "Matches typically last 15-25 minutes, but the actual duration can vary based on gameplay and the active affix."
    }
}

-- Update help panel with current help content
function HLBG.UpdateHelp()
    -- Make sure the UI is loaded
    if not HLBG._ensureUI('Help') then return end
    
    local help = HLBG.UI.Help
    
    -- Clear existing content
    if help.Content.children then
        for _, child in ipairs(help.Content.children) do
            child:Hide()
        end
    else
        help.Content.children = {}
    end
    
    -- Create title
    local title = help.Content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", help.Content, "TOP", 0, -10)
    title:SetText("Hinterland Battleground Help")
    table.insert(help.Content.children, title)
    
    -- Create tabs
    help.ContentTabs = help.ContentTabs or {}
    local tabNames = {"Commands", "FAQ"}
    local tabWidth = 100
    local tabHeight = 24
    local tabOffsetY = -40
    
    -- Create or update tab buttons
    for i, tabName in ipairs(tabNames) do
        local tab = help.ContentTabs[tabName]
        if not tab then
            tab = CreateFrame("Button", nil, help.Content, "UIPanelButtonTemplate")
            tab:SetSize(tabWidth, tabHeight)
            tab:SetPoint("TOPLEFT", help.Content, "TOPLEFT", (i-1)*tabWidth + 20, tabOffsetY)
            tab:SetText(tabName)
            tab:SetScript("OnClick", function(self)
                HLBG.SwitchHelpTab(tabName)
            end)
            help.ContentTabs[tabName] = tab
        end
        table.insert(help.Content.children, tab)
    end
    
    -- Create tab content frame
    if not help.TabContent then
        help.TabContent = CreateFrame("Frame", nil, help.Content)
        help.TabContent:SetPoint("TOPLEFT", help.Content, "TOPLEFT", 20, tabOffsetY - tabHeight - 10)
        help.TabContent:SetPoint("BOTTOMRIGHT", help.Content, "BOTTOMRIGHT", -20, 20)
    end
    table.insert(help.Content.children, help.TabContent)
    
    -- Default to Commands tab if none selected
    if not help.CurrentTab then
        HLBG.SwitchHelpTab("Commands")
    else
        HLBG.SwitchHelpTab(help.CurrentTab)
    end
    
    -- Show the tab
    help:Show()
end

-- Switch between help tabs
function HLBG.SwitchHelpTab(tabName)
    -- Make sure the UI is loaded
    if not HLBG._ensureUI('Help') or not HLBG.UI.Help.TabContent then return end
    
    local help = HLBG.UI.Help
    help.CurrentTab = tabName
    
    -- Highlight active tab
    for name, tab in pairs(help.ContentTabs) do
        if name == tabName then
            tab:LockHighlight()
        else
            tab:UnlockHighlight()
        end
    end
    
    -- Clear tab content
    local content = help.TabContent
    for i = 1, content:GetNumChildren() do
        local child = select(i, content:GetChildren())
        child:Hide()
    end
    
    -- Fill with appropriate content
    if tabName == "Commands" then
        HLBG.ShowCommandsTab(content)
    elseif tabName == "FAQ" then
        HLBG.ShowFAQTab(content)
    end
end

-- Show commands tab content
function HLBG.ShowCommandsTab(parent)
    -- Create title
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    title:SetText("Available Commands")
    title:Show()
    
    -- Create header
    local headerFrame = CreateFrame("Frame", nil, parent)
    headerFrame:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    headerFrame:SetSize(parent:GetWidth(), 25)
    headerFrame:Show()
    
    local cmdHeader = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cmdHeader:SetPoint("TOPLEFT", headerFrame, "TOPLEFT", 0, 0)
    cmdHeader:SetWidth(120)
    cmdHeader:SetJustifyH("LEFT")
    cmdHeader:SetText("Command")
    cmdHeader:Show()
    
    local argsHeader = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    argsHeader:SetPoint("TOPLEFT", cmdHeader, "TOPRIGHT", 10, 0)
    argsHeader:SetWidth(120)
    argsHeader:SetJustifyH("LEFT")
    argsHeader:SetText("Arguments")
    argsHeader:Show()
    
    local descHeader = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    descHeader:SetPoint("TOPLEFT", argsHeader, "TOPRIGHT", 10, 0)
    descHeader:SetWidth(300)
    descHeader:SetJustifyH("LEFT")
    descHeader:SetText("Description")
    descHeader:Show()
    
    -- Create separator line
    local line = parent:CreateTexture(nil, "BACKGROUND")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, -2)
    line:SetPoint("RIGHT", parent, "RIGHT", -10, 0)
    line:SetColorTexture(0.5, 0.5, 0.5, 0.5)
    line:Show()
    
    -- Create scrollframe for commands
    local scrollFrame = CreateFrame("ScrollFrame", "HLBG_HelpCommandsScrollFrame", parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", line, "BOTTOMLEFT", 0, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -30, 0)
    scrollFrame:Show()
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollFrame:SetScrollChild(scrollChild)
    scrollChild:SetWidth(scrollFrame:GetWidth())
    scrollChild:Show()
    
    -- Add commands to scroll frame
    local yOffset = 0
    local height = 0
    
    for i, cmd in ipairs(HLBG.Commands) do
        local cmdFrame = CreateFrame("Frame", nil, scrollChild)
        cmdFrame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yOffset)
        cmdFrame:SetSize(scrollChild:GetWidth(), 30)
        cmdFrame:Show()
        
        local cmdText = cmdFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        cmdText:SetPoint("TOPLEFT", cmdFrame, "TOPLEFT", 0, 0)
        cmdText:SetWidth(120)
        cmdText:SetJustifyH("LEFT")
        cmdText:SetText(cmd.command)
        cmdText:Show()
        
        local argsText = cmdFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        argsText:SetPoint("TOPLEFT", cmdText, "TOPRIGHT", 10, 0)
        argsText:SetWidth(120)
        argsText:SetJustifyH("LEFT")
        argsText:SetText(cmd.args)
        argsText:Show()
        
        local descText = cmdFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        descText:SetPoint("TOPLEFT", argsText, "TOPRIGHT", 10, 0)
        descText:SetWidth(300)
        descText:SetJustifyH("LEFT")
        descText:SetText(cmd.description)
        descText:Show()
        
        yOffset = yOffset + 30
        height = height + 30
    end
    
    scrollChild:SetHeight(height)
end

-- Show FAQ tab content
function HLBG.ShowFAQTab(parent)
    -- Create title
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    title:SetText("Frequently Asked Questions")
    title:Show()
    
    -- Create scrollframe for FAQ
    local scrollFrame = CreateFrame("ScrollFrame", "HLBG_HelpFAQScrollFrame", parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -30, 0)
    scrollFrame:Show()
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollFrame:SetScrollChild(scrollChild)
    scrollChild:SetWidth(scrollFrame:GetWidth())
    scrollChild:Show()
    
    -- Add FAQ items to scroll frame
    local yOffset = 0
    local height = 0
    
    for i, item in ipairs(HLBG.FAQ) do
        local questionText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        questionText:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yOffset)
        questionText:SetWidth(scrollChild:GetWidth())
        questionText:SetJustifyH("LEFT")
        questionText:SetText("Q: " .. item.question)
        questionText:Show()
        
        local questionHeight = questionText:GetHeight() or 20
        yOffset = yOffset + questionHeight + 5
        height = height + questionHeight + 5
        
        local answerText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        answerText:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 15, -yOffset)
        answerText:SetWidth(scrollChild:GetWidth() - 15)
        answerText:SetJustifyH("LEFT")
        answerText:SetText("A: " .. item.answer)
        answerText:Show()
        
        local answerHeight = answerText:GetHeight() or 20
        yOffset = yOffset + answerHeight + 15
        height = height + answerHeight + 15
    end
    
    scrollChild:SetHeight(height)
end

-- Hook help to the OpenUI function
HLBG._oldHelpEnsure = HLBG._ensureUI
function HLBG._ensureUI(what)
    local result = HLBG._oldHelpEnsure and HLBG._oldHelpEnsure(what) or true
    
    -- If Help tab is requested, update its content
    if what == "Help" and result and HLBG.UI and HLBG.UI.Help then
        HLBG.UpdateHelp()
    end
    
    return result
end