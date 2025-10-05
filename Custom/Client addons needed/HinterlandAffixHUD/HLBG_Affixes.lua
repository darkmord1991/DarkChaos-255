-- HLBG_Affixes.lua - Affixes tab for Hinterland Battleground UI
local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

-- Ensure we have the UI namespace
HLBG.UI = HLBG.UI or {}

-- Create basic affix name lookup table if not available
if not HLBG._affixNames then
    HLBG._affixNames = {
        ["0"] = "None",
        ["1"] = "Double Resources",
        ["2"] = "Resilience",
        ["3"] = "Resource Drain",
        ["4"] = "Stamina",
        ["5"] = "Berserker",
        ["6"] = "Power Surge",
        ["7"] = "Veteran",
        ["8"] = "Bloodlust",
        ["9"] = "Reinforcements",
        ["10"] = "Savage"
    }
end

-- Affix descriptions - add detailed information about each affix
HLBG._affixDescriptions = {
    ["0"] = "No active affix.",
    ["1"] = "Double Resources: All resource gains are doubled for both factions.",
    ["2"] = "Resilience: Players gain increased resilience while in combat.",
    ["3"] = "Resource Drain: Both factions periodically lose resources.",
    ["4"] = "Stamina: Players have increased health but reduced movement speed.",
    ["5"] = "Berserker: Players deal increased damage but take more damage as well.",
    ["6"] = "Power Surge: Abilities cost less mana/energy/rage but have increased cooldowns.",
    ["7"] = "Veteran: Honorable kills grant bonus resources.",
    ["8"] = "Bloodlust: Players periodically gain Bloodlust/Heroism while in combat.",
    ["9"] = "Reinforcements: Additional NPCs spawn to aid both factions.",
    ["10"] = "Savage: Critical hits deal additional damage."
}

-- Affix tab implementation
if not HLBG.Affixes then
function HLBG.Affixes(affixes)
    -- Ensure UI is created
    HLBG._ensureUI('Affixes')
    
    -- Store the affixes data
    HLBG._affixesData = affixes or {}
    
    -- Create main content area if it doesn't exist
    if not HLBG.UI.Affixes.Content then
        HLBG.UI.Affixes.Scroll = CreateFrame("ScrollFrame", "HLBG_AffixesScroll", HLBG.UI.Affixes, "UIPanelScrollFrameTemplate")
        HLBG.UI.Affixes.Scroll:SetPoint("TOPLEFT", 16, -40)
        HLBG.UI.Affixes.Scroll:SetPoint("BOTTOMRIGHT", -36, 16)
        
        HLBG.UI.Affixes.Content = CreateFrame("Frame", nil, HLBG.UI.Affixes.Scroll)
        HLBG.UI.Affixes.Content:SetSize(460, 300)
        if HLBG.UI.Affixes.Content.SetFrameStrata then 
            HLBG.UI.Affixes.Content:SetFrameStrata("DIALOG") 
        end
        
        HLBG.UI.Affixes.Scroll:SetScrollChild(HLBG.UI.Affixes.Content)
    end
    
    -- Clear existing content
    for _, child in ipairs(HLBG.UI.Affixes.Content.children or {}) do
        if child and child.Hide then
            child:Hide()
        end
    end
    
    -- Initialize children table
    HLBG.UI.Affixes.Content.children = {}
    
    -- Title and explanation
    local header = HLBG.UI.Affixes.Content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", HLBG.UI.Affixes.Content, "TOPLEFT", 0, 0)
    header:SetText("Battleground Affixes")
    table.insert(HLBG.UI.Affixes.Content.children, header)
    
    local explanation = HLBG.UI.Affixes.Content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    explanation:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -10)
    explanation:SetWidth(440)
    explanation:SetJustifyH("LEFT")
    explanation:SetText("Affixes modify the battleground gameplay. A new affix is chosen for each battle.")
    table.insert(HLBG.UI.Affixes.Content.children, explanation)
    
    -- Current affix display
    local currentHeader = HLBG.UI.Affixes.Content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    currentHeader:SetPoint("TOPLEFT", explanation, "BOTTOMLEFT", 0, -20)
    currentHeader:SetText("Current Affix")
    table.insert(HLBG.UI.Affixes.Content.children, currentHeader)
    
    local currentAffix = HLBG.UI.Affixes.Content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    currentAffix:SetPoint("TOPLEFT", currentHeader, "BOTTOMLEFT", 10, -10)
    currentAffix:SetWidth(430)
    currentAffix:SetJustifyH("LEFT")
    
    -- Get current affix
    local affixCode = tostring(HLBG._affixText or "0")
    local affixName = HLBG.GetAffixName and HLBG.GetAffixName(affixCode) or HLBG._affixNames[affixCode] or "Unknown"
    local affixDesc = HLBG._affixDescriptions[affixCode] or "No description available."
    
    currentAffix:SetText(affixName .. ": " .. affixDesc)
    table.insert(HLBG.UI.Affixes.Content.children, currentAffix)
    
    -- List all available affixes
    local allAffixesHeader = HLBG.UI.Affixes.Content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    allAffixesHeader:SetPoint("TOPLEFT", currentAffix, "BOTTOMLEFT", -10, -20)
    allAffixesHeader:SetText("All Affixes")
    table.insert(HLBG.UI.Affixes.Content.children, allAffixesHeader)
    
    local y = -30
    for code, name in pairs(HLBG._affixNames) do
        if code ~= "0" then -- Skip "None"
            local affixRow = CreateFrame("Frame", nil, HLBG.UI.Affixes.Content)
            affixRow:SetPoint("TOPLEFT", allAffixesHeader, "BOTTOMLEFT", 0, y)
            affixRow:SetSize(440, 40)
            
            local affixName = affixRow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            affixName:SetPoint("TOPLEFT", 10, 0)
            affixName:SetWidth(430)
            affixName:SetJustifyH("LEFT")
            affixName:SetText(name)
            
            local affixDesc = affixRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            affixDesc:SetPoint("TOPLEFT", affixName, "BOTTOMLEFT", 10, -2)
            affixDesc:SetWidth(420)
            affixDesc:SetJustifyH("LEFT")
            affixDesc:SetText(HLBG._affixDescriptions[code] or "No description available.")
            
            table.insert(HLBG.UI.Affixes.Content.children, affixRow)
            y = y - 50
        end
    end
    
    -- Update content height to fit all elements
    HLBG.UI.Affixes.Content:SetHeight(math.abs(y) + 50)
    
    -- Make the tab visible
    if HLBG.UI and HLBG.UI.Frame then
        HLBG.UI.Frame:Show()
        ShowTab(5) -- Affixes is tab 5
    end
end
end

-- Add Affix tab to UI if not present
if not HLBG.UI.Affixes then
    HLBG.UI.Affixes = CreateFrame("Frame", nil, HLBG.UI.Frame)
    HLBG.UI.Affixes:SetAllPoints(HLBG.UI.Frame)
    HLBG.UI.Affixes:Hide()
    
    -- Add title text
    HLBG.UI.Affixes.Text = HLBG.UI.Affixes:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    HLBG.UI.Affixes.Text:SetPoint("TOPLEFT", 16, -16)
    HLBG.UI.Affixes.Text:SetText("Hinterland Battleground Affixes")
    
    -- Set up to request affixes when shown
    HLBG.UI.Affixes:SetScript("OnShow", function()
        -- Request affix data from server if available
        if type(HLBG.RequestAffixes) == "function" then
            HLBG.RequestAffixes()
        end
        
        -- If we don't have data yet, show what we know locally
        if not HLBG._affixesData or not next(HLBG._affixesData) then
            HLBG.Affixes({})
        end
    end)
end

-- Update GetAffixName function to use our local data if server doesn't provide names
if not HLBG.GetAffixName then
function HLBG.GetAffixName(code)
    -- Convert to string for table lookup
    local affixCode = tostring(code or "0")
    
    -- Try to get from server data
    if HLBG._affixData and HLBG._affixData[affixCode] then
        return HLBG._affixData[affixCode].name or HLBG._affixNames[affixCode] or affixCode
    end
    
    -- Fallback to local data
    return HLBG._affixNames[affixCode] or affixCode
end
end

_G.HLBG = HLBG