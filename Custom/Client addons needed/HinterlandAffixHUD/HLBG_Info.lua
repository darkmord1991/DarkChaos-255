-- HLBG_Info.lua - Info panel for Hinterland Battleground AddOn
-- This file provides updated info about the battleground

-- Initialize our addon namespace if needed
if not HLBG then HLBG = {} end

-- Update info panel with current version and features
function HLBG.UpdateInfo()
    -- Make sure the UI is loaded
    if not HLBG._ensureUI('Info') then return end
    
    local info = HLBG.UI.Info
    
    -- Clear existing content
    if info.Content.children then
        for _, child in ipairs(info.Content.children) do
            child:Hide()
        end
    else
        info.Content.children = {}
    end
    
    -- Create title
    local title = info.Content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", info.Content, "TOP", 0, -10)
    title:SetText("Hinterland Battleground")
    table.insert(info.Content.children, title)
    
    -- Create subtitle
    local version = info.Content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    version:SetPoint("TOP", title, "BOTTOM", 0, -5)
    version:SetText("Version 1.4.0")
    table.insert(info.Content.children, version)
    
    -- Create description
    local description = info.Content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    description:SetPoint("TOPLEFT", info.Content, "TOPLEFT", 20, -60)
    description:SetPoint("TOPRIGHT", info.Content, "TOPRIGHT", -20, -60)
    description:SetJustifyH("LEFT")
    description:SetText(
        "The Hinterland Battleground is a 25 vs 25 player PvP battleground featuring random affixes " ..
        "that change the gameplay mechanics. Players compete to collect resources by controlling " ..
        "capture points and defeating enemy players.\n\n" ..
        "Each battleground match features a different affix that significantly changes the " ..
        "gameplay mechanics. Some affixes boost damage, others change movement speed, " ..
        "or provide unique buffs and debuffs to players."
    )
    table.insert(info.Content.children, description)
    
    -- Create sections title
    local sectionsTitle = info.Content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    sectionsTitle:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -20)
    sectionsTitle:SetText("Battleground Features")
    table.insert(info.Content.children, sectionsTitle)
    
    -- Create sections with icons
    local icons = {
        {title = "History", text = "View past battleground results with details on winners, affixes, and durations"},
        {title = "Statistics", text = "See overall win/loss statistics for each faction and affix"},
        {title = "Affixes", text = "Browse all possible affixes and their effects"},
        {title = "Queue", text = "Join the battleground queue and see estimated wait times"},
        {title = "Live Battle", text = "Monitor resources and player counts during an active battle"},
        {title = "Settings", text = "Configure HUD display options and addon behavior"}
    }
    
    local y = -200
    for i, icon in ipairs(icons) do
        local frame = CreateFrame("Frame", nil, info.Content)
        frame:SetSize(450, 40)
        frame:SetPoint("TOPLEFT", info.Content, "TOPLEFT", 20, y)
        
        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        title:SetText(icon.title)
        
        local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 10, -2)
        text:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
        text:SetJustifyH("LEFT")
        text:SetText(icon.text)
        
        table.insert(info.Content.children, frame)
        y = y - 50
    end
    
    -- Create commands title
    local commandsTitle = info.Content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    commandsTitle:SetPoint("TOPLEFT", info.Content, "TOPLEFT", 20, y - 20)
    commandsTitle:SetText("Slash Commands")
    table.insert(info.Content.children, commandsTitle)
    
    -- Create commands list
    local commands = info.Content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    commands:SetPoint("TOPLEFT", commandsTitle, "BOTTOMLEFT", 10, -10)
    commands:SetPoint("RIGHT", info.Content, "RIGHT", -20, 0)
    commands:SetJustifyH("LEFT")
    commands:SetText(
        "/hlbg - Open main window\n" ..
        "/hlbg queue join - Join battleground queue\n" ..
        "/hlbg queue leave - Leave battleground queue\n" ..
        "/hlbg devmode on|off - Enable/disable debug mode\n" ..
        "/hlbg season <n> - Set season filter (0 = all/current)"
    )
    table.insert(info.Content.children, commands)
    
    -- Set content height
    info.Content:SetHeight(math.abs(y) + 200)
    
    -- Show the tab
    info:Show()
end

-- Hook this to the OpenUI function
HLBG._oldInfoEnsure = HLBG._ensureUI
function HLBG._ensureUI(what)
    local result = HLBG._oldInfoEnsure and HLBG._oldInfoEnsure(what) or true
    
    -- If Info tab is requested, update its content
    if what == "Info" and result and HLBG.UI and HLBG.UI.Info then
        HLBG.UpdateInfo()
    end
    
    return result
end
