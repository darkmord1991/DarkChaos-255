-- HLBG_Info.lua - Info panel for Hinterland Battleground AddOn
-- This file provides updated info about the battleground
-- Initialize our addon namespace if needed
if not HLBG then HLBG = {} end

-- Store server config data
HLBG.ServerConfig = HLBG.ServerConfig or {}

-- Parse CONFIG_INFO protocol message from server
-- Format: "CONFIG_INFO|MATCH_DURATION=1800|MIN_LEVEL=1|RESOURCES_ALLIANCE=500|..."
function HLBG.ParseConfigInfo(message)
    if not message or not message:find("CONFIG_INFO") then return end
    HLBG.DebugPrint("Parsing CONFIG_INFO: " .. message)
    
    -- Split by pipe delimiter
    for param in message:gmatch("[^|]+") do
        if param ~= "CONFIG_INFO" then
            local key, value = param:match("([^=]+)=([^=]+)")
            if key and value then
                -- Convert numeric values
                if tonumber(value) then
                    HLBG.ServerConfig[key] = tonumber(value)
                else
                    HLBG.ServerConfig[key] = value
                end
            end
        end
    end
    
    HLBG.DebugPrint("Server config updated: " .. table.getn(HLBG.ServerConfig) .. " parameters")
    
    -- Refresh Info panel if it's currently visible
    if HLBG.UI and HLBG.UI.Info and HLBG.UI.Info:IsShown() then
        HLBG.UpdateInfo()
    end
end

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
    
    local yOffset = -60
    
    -- Show server configuration if available
    if next(HLBG.ServerConfig) then
        local configTitle = info.Content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        configTitle:SetPoint("TOPLEFT", info.Content, "TOPLEFT", 20, yOffset)
        configTitle:SetText("Server Configuration")
        table.insert(info.Content.children, configTitle)
        yOffset = yOffset - 25
        
        -- Display configuration parameters
        local configText = ""
        local matchDuration = HLBG.ServerConfig.MATCH_DURATION or 0
        local warmupDuration = HLBG.ServerConfig.WARMUP_DURATION or 0
        local minLevel = HLBG.ServerConfig.MIN_LEVEL or 1
        local resourcesAlliance = HLBG.ServerConfig.RESOURCES_ALLIANCE or 0
        local resourcesHorde = HLBG.ServerConfig.RESOURCES_HORDE or 0
        local season = HLBG.ServerConfig.SEASON or 1
        local affixEnabled = HLBG.ServerConfig.AFFIX_ENABLED or 0
        local rewardHonor = HLBG.ServerConfig.REWARD_HONOR or 0
        local rewardHonorDepletion = HLBG.ServerConfig.REWARD_HONOR_DEPLETION or 0
        
        configText = string.format(
            "Match Duration: %d minutes\n" ..
            "Warmup Duration: %d seconds\n" ..
            "Minimum Level: %d\n" ..
            "Starting Resources: Alliance %d | Horde %d\n" ..
            "Current Season: %d\n" ..
            "Affix System: %s\n" ..
            "Honor Rewards: Match %d | Depletion %d",
            math.floor(matchDuration / 60),
            warmupDuration,
            minLevel,
            resourcesAlliance,
            resourcesHorde,
            season,
            affixEnabled == 1 and "Enabled" or "Disabled",
            rewardHonor,
            rewardHonorDepletion
        )
        
        local configDisplay = info.Content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        configDisplay:SetPoint("TOPLEFT", info.Content, "TOPLEFT", 30, yOffset)
        configDisplay:SetPoint("RIGHT", info.Content, "RIGHT", -20, 0)
        configDisplay:SetJustifyH("LEFT")
        configDisplay:SetText(configText)
        table.insert(info.Content.children, configDisplay)
        yOffset = yOffset - 160
    end
    
    -- Create description
    local description = info.Content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    description:SetPoint("TOPLEFT", info.Content, "TOPLEFT", 20, yOffset)
    description:SetPoint("TOPRIGHT", info.Content, "TOPRIGHT", -20, yOffset)
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
    yOffset = yOffset - 120
    
    -- Create sections title
    local sectionsTitle = info.Content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    sectionsTitle:SetPoint("TOPLEFT", info.Content, "TOPLEFT", 20, yOffset)
    sectionsTitle:SetText("Battleground Features")
    table.insert(info.Content.children, sectionsTitle)
    yOffset = yOffset - 25
    
    -- Create sections with icons
    local icons = {
        {title = "History", text = "View past battleground results with details on winners, affixes, and durations"},
        {title = "Statistics", text = "See overall win/loss statistics for each faction and affix"},
        {title = "Affixes", text = "Browse all possible affixes and their effects"},
        {title = "Queue", text = "Join the battleground queue and see estimated wait times"},
        {title = "Live Battle", text = "Monitor resources and player counts during an active battle"},
        {title = "Settings", text = "Configure HUD display options and addon behavior"}
    }
    
    for i, icon in ipairs(icons) do
        local frame = CreateFrame("Frame", nil, info.Content)
        frame:SetSize(450, 40)
        frame:SetPoint("TOPLEFT", info.Content, "TOPLEFT", 20, yOffset)
        local iconTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        iconTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        iconTitle:SetText(icon.title)
        local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetPoint("TOPLEFT", iconTitle, "BOTTOMLEFT", 10, -2)
        text:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
        text:SetJustifyH("LEFT")
        text:SetText(icon.text)
        table.insert(info.Content.children, frame)
        yOffset = yOffset - 50
    end
    
    -- Create commands title
    local commandsTitle = info.Content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    commandsTitle:SetPoint("TOPLEFT", info.Content, "TOPLEFT", 20, yOffset)
    commandsTitle:SetText("Slash Commands")
    table.insert(info.Content.children, commandsTitle)
    yOffset = yOffset - 25
    
    -- Create commands list
    local commands = info.Content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    commands:SetPoint("TOPLEFT", info.Content, "TOPLEFT", 30, yOffset)
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
    yOffset = yOffset - 120
    
    -- Set content height
    info.Content:SetHeight(math.abs(yOffset) + 100)
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

