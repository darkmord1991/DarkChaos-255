local addonName = "DC-MythicPlus"
local namespace = _G.DCMythicPlusHUD or {}
_G.DCMythicPlusHUD = namespace

-- This file implements the Mythic+ Token Vendor UI via DCAddonProtocol (module MPLUS).
-- Server sends: SMSG_TOKEN_VENDOR_OPEN (0x80), SMSG_TOKEN_VENDOR_CHOICES (0x82), SMSG_TOKEN_VENDOR_RESULT (0x84), SMSG_TOKEN_VENDOR_STATE (0x86)
-- Client sends: CMSG_TOKEN_VENDOR_CHOICES (0x81), CMSG_TOKEN_VENDOR_BUY (0x83), CMSG_TOKEN_VENDOR_EXCHANGE (0x85)

local DC
local didWarnMissingProtocol = false
local handlersRegistered = false

local function EnsureProtocol()
    if DC then
        return true
    end

    DC = rawget(_G, "DCAddonProtocol")
    if DC then
        return true
    end

    if not didWarnMissingProtocol and DEFAULT_CHAT_FRAME then
        didWarnMissingProtocol = true
        DEFAULT_CHAT_FRAME:AddMessage("DC-MythicPlus: DC-AddonProtocol is not loaded. Token Vendor UI requires DC-AddonProtocol.")
    end
    return false
end

local MPLUS = "MPLUS"

namespace.TokenVendorUI = namespace.TokenVendorUI or {}
local UI = namespace.TokenVendorUI

local frame
local state = {
    tokens = 0,
    essence = 0,
    armorType = "",
    tiers = {},
    selectedTier = nil, -- itemLevel
    selectedSlot = nil, -- numeric token slot
    choices = nil,
    filteredChoices = nil,
}

local function trim(str)
    return (str and str:match("^%s*(.-)%s*$")) or str
end

local function getPlayerClassNames()
    local localized, classFile = UnitClass("player")
    local names = {}
    if localized and localized ~= "" then
        names[localized] = true
    end
    if classFile and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classFile] then
        names[LOCALIZED_CLASS_NAMES_MALE[classFile]] = true
    end
    if classFile and LOCALIZED_CLASS_NAMES_FEMALE and LOCALIZED_CLASS_NAMES_FEMALE[classFile] then
        names[LOCALIZED_CLASS_NAMES_FEMALE[classFile]] = true
    end
    return names, localized, classFile
end

local function getTalentSummary()
    local names, localized, classFile = getPlayerClassNames()
    local numTabs = (type(GetNumTalentTabs) == "function") and GetNumTalentTabs() or 0

    local bestTab = nil
    local bestPoints = -1
    local bestName = nil
    local tabs = {}

    for tab = 1, numTabs do
        local name, _, pointsSpent = GetTalentTabInfo(tab)
        pointsSpent = tonumber(pointsSpent) or 0
        tabs[tab] = { name = name, points = pointsSpent }
        if pointsSpent > bestPoints then
            bestPoints = pointsSpent
            bestTab = tab
            bestName = name
        end
    end

    return {
        classNames = names,
        classLocalized = localized,
        classFile = classFile,
        bestTab = bestTab,
        bestTabName = bestName,
        bestPoints = bestPoints,
        tabs = tabs,
    }
end

local function getRoleHintFromClassAndTab(classFile, tabIndex)
    if not classFile or not tabIndex then
        return nil
    end
    -- WotLK talent tree order is fixed per class.
    local map = {
        ROGUE = { "melee_agi", "melee_agi", "melee_agi" },
        HUNTER = { "ranged_agi", "ranged_agi", "ranged_agi" },
        MAGE = { "caster_int", "caster_int", "caster_int" },
        WARLOCK = { "caster_int", "caster_int", "caster_int" },
        PRIEST = { "healer_int", "healer_int", "caster_int" },
        DRUID = { "caster_int", "melee_agi", "healer_int" },
        SHAMAN = { "caster_int", "melee_agi", "healer_int" },
        PALADIN = { "healer_int", "tank_str", "melee_str" },
        WARRIOR = { "melee_str", "melee_str", "tank_str" },
        DEATHKNIGHT = { "tank_str", "melee_str", "melee_str" },
    }
    local t = map[classFile]
    return t and t[tabIndex] or nil
end

-- Tooltip scanner for class restrictions + basic stat presence.
local scanTooltip
local scanPrefix
local function ensureScanTooltip()
    if scanTooltip then
        return
    end
    scanTooltip = CreateFrame("GameTooltip", "DCMP_TokenVendorScanTooltip", UIParent, "GameTooltipTemplate")
    scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    if type(ITEM_CLASSES_ALLOWED) == "string" then
        scanPrefix = ITEM_CLASSES_ALLOWED:match("^(.-)%%s")
    end
    if not scanPrefix or scanPrefix == "" then
        scanPrefix = "Classes: "
    end
end

local function getItemTooltipLines(itemLink)
    ensureScanTooltip()
    scanTooltip:ClearLines()
    scanTooltip:SetHyperlink(itemLink)
    local lines = {}
    for i = 1, 30 do
        local left = _G["DCMP_TokenVendorScanTooltipTextLeft" .. i]
        if left then
            local t = left:GetText()
            if t and t ~= "" then
                lines[#lines + 1] = t
            end
        end
    end
    return lines
end

local function itemPassesClassRestriction(itemId, classNames)
    if not itemId then
        return false
    end
    local link = "item:" .. tostring(itemId) .. ":0:0:0:0:0:0:0"

    if type(IsUsableItem) == "function" then
        local usable = IsUsableItem(link)
        if usable == false then
            -- Often catches class restriction / missing proficiencies.
            return false
        end
    end

    local lines = getItemTooltipLines(link)
    for _, line in ipairs(lines) do
        if type(line) == "string" and line:sub(1, #scanPrefix) == scanPrefix then
            local list = trim(line:sub(#scanPrefix + 1))
            if not list or list == "" then
                return true
            end
            for entry in string.gmatch(list, "[^,]+") do
                entry = trim(entry)
                if entry and classNames and classNames[entry] then
                    return true
                end
            end
            return false
        end
    end

    -- No explicit class line => allow.
    return true
end

local function itemStatHint(itemId)
    local link = "item:" .. tostring(itemId) .. ":0:0:0:0:0:0:0"
    local lines = getItemTooltipLines(link)
    local hint = {
        hasInt = false,
        hasSpi = false,
        hasStr = false,
        hasAgi = false,
        hasSpell = false,
        hasHeal = false,
        hasAP = false,
        hasDef = false,
    }

    for _, line in ipairs(lines) do
        if type(line) == "string" then
            if line:find(ITEM_MOD_INTELLECT_SHORT or "Intellect") then hint.hasInt = true end
            if line:find(ITEM_MOD_SPIRIT_SHORT or "Spirit") then hint.hasSpi = true end
            if line:find(ITEM_MOD_STRENGTH_SHORT or "Strength") then hint.hasStr = true end
            if line:find(ITEM_MOD_AGILITY_SHORT or "Agility") then hint.hasAgi = true end
            if line:lower():find("spell") and line:lower():find("power") then hint.hasSpell = true end
            if line:lower():find("healing") then hint.hasHeal = true end
            if line:lower():find("attack power") then hint.hasAP = true end
            if line:lower():find("defense") then hint.hasDef = true end
        end
    end
    return hint
end

local function itemPassesRoleFit(itemId, roleHint)
    if not roleHint then
        return true
    end
    local hint = itemStatHint(itemId)

    if roleHint == "melee_agi" or roleHint == "ranged_agi" then
        -- Reject obvious caster/healer items for agi specs.
        if hint.hasInt or hint.hasSpell or hint.hasHeal or hint.hasSpi then
            return false
        end
        return true
    end
    if roleHint == "melee_str" then
        if hint.hasInt or hint.hasSpell or hint.hasHeal or hint.hasSpi then
            return false
        end
        return true
    end
    if roleHint == "caster_int" or roleHint == "healer_int" then
        -- Reject obvious physical items for caster/healer.
        if hint.hasAgi or hint.hasStr or hint.hasAP then
            -- Allow caster staves etc that still show STR/AGI? very rare; keep strict.
            return false
        end
        return true
    end
    if roleHint == "tank_str" then
        if hint.hasInt or hint.hasSpell or hint.hasHeal then
            return false
        end
        return true
    end
    return true
end

local SLOT_LABELS = {
    [1] = "Head",
    [2] = "Neck",
    [3] = "Shoulders",
    [4] = "Back",
    [5] = "Chest",
    [6] = "Wrists",
    [7] = "Hands",
    [8] = "Waist",
    [9] = "Legs",
    [10] = "Feet",
    [11] = "Finger",
    [12] = "Trinket",
    [13] = "Weapon",
    [14] = "Off-hand",
}

local function fmtNumber(n)
    if type(n) ~= "number" then return tostring(n or "") end
    return string.format("%d", n)
end

local function colorizeByQuality(text, quality)
    if type(text) ~= "string" then
        text = tostring(text or "")
    end
    if type(quality) ~= "number" then
        return text
    end
    if ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] and ITEM_QUALITY_COLORS[quality].hex then
        local hex = tostring(ITEM_QUALITY_COLORS[quality].hex or "")
        -- Some addons/clients store hex as "ffRRGGBB", others as "|cffRRGGBB" or "cffRRGGBB".
        if hex:sub(1, 2) == "|c" then
            return hex .. text .. "|r"
        end
        if hex:sub(1, 3) == "cff" then
            return "|" .. hex .. text .. "|r"
        end
        if #hex == 8 then
            return "|c" .. hex .. text .. "|r"
        end
        -- Fallback: try to use it as-is.
        return "|c" .. hex .. text .. "|r"
    end
    return text
end

local function safeItemTexture(itemId)
    if not itemId then
        return "Interface\\Icons\\INV_Misc_QuestionMark"
    end
    local name, link, quality, level, minLevel, itemType, itemSubType, stackCount, equipLoc, texture = GetItemInfo(itemId)
    if texture then
        return texture
    end
    if type(GetItemIcon) == "function" then
        local t = GetItemIcon(itemId)
        if t then
            return t
        end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function CreateDisplayFrame(parent, iconPath, tooltipTitle, tooltipText)
    local f = CreateFrame("Button", nil, parent)
    f:SetSize(120, 24)
    
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(20, 20)
    f.icon:SetPoint("LEFT", 0, 0)
    f.icon:SetTexture(iconPath)
    
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.text:SetPoint("LEFT", f.icon, "RIGHT", 5, 0)
    f.text:SetText("0")
    
    f:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(tooltipTitle, 1, 1, 1)
        GameTooltip:AddLine(tooltipText, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    return f
end

local function ensureFrame()
    if frame then return frame end

    frame = CreateFrame("Frame", "DCMP_TokenVendorFrame", UIParent)
    frame:SetSize(600, 450)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    frame:SetScript("OnEvent", function(self, event, ...)
        if event == "GET_ITEM_INFO_RECEIVED" then
            UI:Refresh()
        end
    end)

    -- Background (WotLK/Retail style)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(0, 0, 0, 1) -- Black background

    -- Title
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOP", 0, -15)
    frame.title:SetText("Mythic+ Token Vendor")
    frame.title:SetTextColor(1, 0.82, 0, 1)

    -- Close Button
    frame.close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.close:SetPoint("TOPRIGHT", -5, -5)
    frame.close:SetScript("OnClick", function() frame:Hide() end)

    -- Top Info Bar (Tokens, Essence, Spec)
    frame.tokenDisplay = CreateDisplayFrame(frame, "Interface\\Icons\\INV_Misc_Coin_02", "Mythic Tokens", "Currency used to purchase Mythic+ gear.")
    frame.tokenDisplay:SetPoint("TOPLEFT", 20, -40)
    frame.tokenDisplay.text:SetTextColor(1, 0.82, 0, 1)

    frame.essenceDisplay = CreateDisplayFrame(frame, "Interface\\Icons\\INV_Enchant_EssenceEternalLarge", "Artifact Essence", "Currency used for upgrading items.")
    frame.essenceDisplay:SetPoint("LEFT", frame.tokenDisplay, "RIGHT", 10, 0)
    frame.essenceDisplay.text:SetTextColor(1, 0.82, 0, 1)

    frame.specInfo = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.specInfo:SetPoint("TOPRIGHT", -20, -45)
    frame.specInfo:SetJustifyH("RIGHT")
    frame.specInfo:SetText("Class: ?")
    frame.specInfo:SetTextColor(1, 0.82, 0, 1)

    -- Separator
    local sep1 = frame:CreateTexture(nil, "ARTWORK")
    sep1:SetHeight(1)
    sep1:SetWidth(560)
    sep1:SetPoint("TOP", 0, -70)
    sep1:SetColorTexture(0.3, 0.3, 0.3, 1)

    -- Tier Selection
    frame.tierLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.tierLabel:SetPoint("TOPLEFT", 20, -80)
    frame.tierLabel:SetText("Select Item Level Tier:")
    frame.tierLabel:SetTextColor(1, 0.82, 0, 1)

    frame.tierButtons = {}
    for i = 1, 5 do
        local b = CreateFrame("Button", nil, frame)
        b:SetSize(100, 30)
        b:SetPoint("TOPLEFT", 20 + (i - 1) * 110, -100)
        
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
        b.bg:SetColorTexture(0.2, 0.2, 0.2, 1)
        
        b.border = {}
        b.border.T = b:CreateTexture(nil, "BORDER"); b.border.T:SetPoint("TOPLEFT"); b.border.T:SetPoint("TOPRIGHT"); b.border.T:SetHeight(1); b.border.T:SetColorTexture(0.3, 0.3, 0.3, 1)
        b.border.B = b:CreateTexture(nil, "BORDER"); b.border.B:SetPoint("BOTTOMLEFT"); b.border.B:SetPoint("BOTTOMRIGHT"); b.border.B:SetHeight(1); b.border.B:SetColorTexture(0.3, 0.3, 0.3, 1)
        b.border.L = b:CreateTexture(nil, "BORDER"); b.border.L:SetPoint("TOPLEFT"); b.border.L:SetPoint("BOTTOMLEFT"); b.border.L:SetWidth(1); b.border.L:SetColorTexture(0.3, 0.3, 0.3, 1)
        b.border.R = b:CreateTexture(nil, "BORDER"); b.border.R:SetPoint("TOPRIGHT"); b.border.R:SetPoint("BOTTOMRIGHT"); b.border.R:SetWidth(1); b.border.R:SetColorTexture(0.3, 0.3, 0.3, 1)

        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.text:SetPoint("CENTER")
        b.text:SetText("-")
        b.text:SetTextColor(1, 1, 1, 1)

        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Item Level Tier " .. i)
            if self.cost then
                GameTooltip:AddLine("Cost: " .. self.cost .. " Tokens", 1, 1, 1)
            end
            GameTooltip:Show()
            for _, t in pairs(self.border) do t:SetColorTexture(1, 1, 1, 1) end
        end)
        b:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
            if state.selectedTier == self.itemLevel then
                for _, t in pairs(self.border) do t:SetColorTexture(1, 0.82, 0, 1) end
            else
                for _, t in pairs(self.border) do t:SetColorTexture(0.3, 0.3, 0.3, 1) end
            end
        end)

        b:SetScript("OnClick", function(self)
            if not state.tiers[i] then return end
            state.selectedTier = state.tiers[i].itemLevel
            UI:RequestChoices()
            UI:Refresh()
        end)
        frame.tierButtons[i] = b
    end

    -- Slot Selection
    frame.slotLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.slotLabel:SetPoint("TOPLEFT", 20, -145)
    frame.slotLabel:SetText("Select Equipment Slot:")
    frame.slotLabel:SetTextColor(1, 0.82, 0, 1)

    frame.slotDrop = CreateFrame("Frame", "DCMP_TokenVendorSlotDrop", frame, "UIDropDownMenuTemplate")
    frame.slotDrop:SetPoint("TOPLEFT", 5, -165)
    UIDropDownMenu_SetWidth(frame.slotDrop, 180)
    UIDropDownMenu_SetText(frame.slotDrop, "Select a slot")
    UIDropDownMenu_Initialize(frame.slotDrop, function(self, level)
        for slotId, label in pairs(SLOT_LABELS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = label
            info.func = function()
                state.selectedSlot = slotId
                UIDropDownMenu_SetText(frame.slotDrop, label)
                UI:RequestChoices()
                UI:Refresh()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    -- Choices Area
    frame.choiceLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    frame.choiceLabel:SetPoint("TOPLEFT", 20, -210)
    frame.choiceLabel:SetText("Available Items")
    frame.choiceLabel:SetTextColor(1, 0.82, 0, 1)

    frame.choiceButtons = {}
    for i = 1, 3 do
        local b = CreateFrame("Button", nil, frame)
        b:SetSize(560, 50)
        b:SetPoint("TOP", 0, -240 - (i - 1) * 55)

        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
        b.bg:SetColorTexture(0, 0, 0, 0.3) -- Darker, more transparent background
        
        b.border = {}
        b.border.T = b:CreateTexture(nil, "BORDER"); b.border.T:SetPoint("TOPLEFT"); b.border.T:SetPoint("TOPRIGHT"); b.border.T:SetHeight(1); b.border.T:SetColorTexture(0.3, 0.3, 0.3, 1)
        b.border.B = b:CreateTexture(nil, "BORDER"); b.border.B:SetPoint("BOTTOMLEFT"); b.border.B:SetPoint("BOTTOMRIGHT"); b.border.B:SetHeight(1); b.border.B:SetColorTexture(0.3, 0.3, 0.3, 1)
        b.border.L = b:CreateTexture(nil, "BORDER"); b.border.L:SetPoint("TOPLEFT"); b.border.L:SetPoint("BOTTOMLEFT"); b.border.L:SetWidth(1); b.border.L:SetColorTexture(0.3, 0.3, 0.3, 1)
        b.border.R = b:CreateTexture(nil, "BORDER"); b.border.R:SetPoint("TOPRIGHT"); b.border.R:SetPoint("BOTTOMRIGHT"); b.border.R:SetWidth(1); b.border.R:SetColorTexture(0.3, 0.3, 0.3, 1)
        
        -- bInner removed
        -- local bInner = b:CreateTexture(nil, "BACKGROUND", nil, 1) ...

        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(40, 40)
        b.icon:SetPoint("LEFT", 6, 0)
        b.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        
        -- Icon Border
        b.iconBorder = b:CreateTexture(nil, "BORDER")
        b.iconBorder:SetPoint("CENTER", b.icon, "CENTER")
        b.iconBorder:SetSize(42, 42)
        b.iconBorder:SetColorTexture(0.3, 0.3, 0.3, 1)

        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        b.text:SetPoint("LEFT", b.icon, "RIGHT", 15, 5)
        b.text:SetJustifyH("LEFT")
        b.text:SetText("-")
        b.text:SetTextColor(1, 0.82, 0, 1)

        b.subtext = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.subtext:SetPoint("TOPLEFT", b.text, "BOTTOMLEFT", 0, -2)
        b.subtext:SetText("")
        b.subtext:SetTextColor(0.7, 0.7, 0.7, 1)

        b.highlight = b:CreateTexture(nil, "HIGHLIGHT")
        b.highlight:SetAllPoints(b)
        b.highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        b.highlight:SetBlendMode("ADD")
        b.highlight:SetAlpha(0.3)

        b:SetScript("OnClick", function()
            if not state.filteredChoices or not state.filteredChoices[i] then return end
            local it = state.filteredChoices[i]
            if not state.selectedTier or not state.selectedSlot then return end
            DC:Request(MPLUS, 0x83, { itemId = it.itemId, itemLevel = state.selectedTier, slot = state.selectedSlot })
        end)
        b:SetScript("OnEnter", function(self)
            for _, t in pairs(self.border) do t:SetColorTexture(1, 0.82, 0, 1) end
            if not self.itemId then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink("item:" .. tostring(self.itemId) .. ":0:0:0:0:0:0:0")
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function(self)
            for _, t in pairs(self.border) do t:SetColorTexture(0.3, 0.3, 0.3, 1) end
            GameTooltip:Hide()
        end)
        frame.choiceButtons[i] = b
    end

    frame.result = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.result:SetPoint("BOTTOM", 0, 15)
    frame.result:SetText("")
    frame.result:SetTextColor(1, 0.82, 0, 1)

    return frame
end

function UI:Show()
    ensureFrame():Show()
    UI:Refresh()
end

function UI:Hide()
    if frame then frame:Hide() end
end

function UI:Refresh()
    if not frame or not frame:IsShown() then return end

    local talents = getTalentSummary()
    local specText = "Unknown"
    if talents and talents.classLocalized then
        specText = talents.classLocalized
        if talents.bestTabName then
            specText = specText .. " - " .. talents.bestTabName
        end
    end
    frame.specInfo:SetText(specText)

    frame.tokenDisplay.text:SetText(fmtNumber(state.tokens))
    frame.essenceDisplay.text:SetText(fmtNumber(state.essence))

    for i = 1, 5 do
        local tier = state.tiers[i]
        local b = frame.tierButtons[i]
        if tier then
            b.itemLevel = tier.itemLevel
            b.cost = tier.cost
            b.text:SetText("iLvl " .. (tier.itemLevel or 0))
            if state.selectedTier == tier.itemLevel then
                b.bg:SetColorTexture(0.4, 0.4, 0.4, 1)
                for _, t in pairs(b.border) do t:SetColorTexture(1, 0.8, 0, 1) end
            else
                b.bg:SetColorTexture(0.2, 0.2, 0.2, 1)
                for _, t in pairs(b.border) do t:SetColorTexture(0.6, 0.6, 0.6, 1) end
            end
            b:Enable()
        else
            b.itemLevel = nil
            b.cost = nil
            b.text:SetText("-")
            b.bg:SetColorTexture(0.1, 0.1, 0.1, 1)
            for _, t in pairs(b.border) do t:SetColorTexture(0.3, 0.3, 0.3, 1) end
            b:Disable()
        end
    end

    local cost = state.choices and state.choices.cost or nil
    if cost and state.selectedTier and state.selectedSlot then
        frame.choiceLabel:SetText(string.format("Available Items (Cost: %d Tokens)", cost))
    else
        frame.choiceLabel:SetText("Available Items")
    end

    local roleHint = getRoleHintFromClassAndTab(talents and talents.classFile, talents and talents.bestTab)
    local filtered = {}
    local raw = state.choices and state.choices.items or nil
    if type(raw) == "table" then
        for _, it in ipairs(raw) do
            if it and it.itemId then
                if itemPassesClassRestriction(it.itemId, talents and talents.classNames) and itemPassesRoleFit(it.itemId, roleHint) then
                    filtered[#filtered + 1] = it
                end
            end
        end
    end
    state.filteredChoices = filtered

    for i = 1, 3 do
        local b = frame.choiceButtons[i]
        local it = filtered[i]
        if it then
            b.itemId = it.itemId
            b.icon:SetTexture(safeItemTexture(it.itemId))

            local name = tostring(it.name or ("Item #" .. tostring(it.itemId)))
            name = colorizeByQuality(name, tonumber(it.quality))
            local ilvl = tonumber(it.itemLevel) or 0
            
            b.text:SetText(name)
            b.subtext:SetText("Item Level " .. ilvl)
            b:Enable()
            b:Show()
        else
            b.itemId = nil
            b:Hide()
        end
    end

    if state.choices and raw and #raw > 0 and #filtered == 0 then
        frame.result:SetText("No compatible items found for your spec.")
    else
        frame.result:SetText("")
    end
end

function UI:RequestChoices()
    if not state.selectedTier or not state.selectedSlot then
        return
    end
    if not EnsureProtocol() then
        return
    end
    DC:Request(MPLUS, 0x81, { itemLevel = state.selectedTier, slot = state.selectedSlot })
end

local function RegisterProtocolHandlers()
    if handlersRegistered or not EnsureProtocol() then
        return
    end
    handlersRegistered = true

    -- Handlers
    DC:RegisterHandler(MPLUS, 0x80, function(payload)
    if type(payload) ~= "table" then return end

    state.tokens = payload.tokens or 0
    state.essence = payload.essence or 0
    state.armorType = payload.armorType or ""
    state.tiers = payload.tiers or {}

    -- Default selections
    if not state.selectedTier and state.tiers[1] and state.tiers[1].itemLevel then
        state.selectedTier = state.tiers[1].itemLevel
    end

    ensureFrame()
    UI:Show()
    end)

    DC:RegisterHandler(MPLUS, 0x82, function(payload)
    if type(payload) ~= "table" then return end
    state.choices = payload
    UI:Refresh()
    end)

    DC:RegisterHandler(MPLUS, 0x84, function(payload)
    if type(payload) == "table" then
        if payload.message then
            ensureFrame()
            frame.result:SetText(tostring(payload.message))
        end
    end
    end)

    DC:RegisterHandler(MPLUS, 0x86, function(payload)
    if type(payload) ~= "table" then return end
    state.tokens = payload.tokens or state.tokens
    state.essence = payload.essence or state.essence
    UI:Refresh()
    end)
end

-- Attempt registration immediately, but also retry in case DC-AddonProtocol loads later.
RegisterProtocolHandlers()
do
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function()
        RegisterProtocolHandlers()
        if handlersRegistered then
            f:UnregisterAllEvents()
            f:SetScript("OnEvent", nil)
        end
    end)
end

-- Debug/manual open: lets you verify the UI loads even if the server isn't sending OPEN packets.
SLASH_DCMPVENDOR1 = "/dcmvendor"
SLASH_DCMPVENDOR2 = "/dcmpvendor"
SlashCmdList["DCMPVENDOR"] = function()
    ensureFrame()
    UI:Show()

    if not EnsureProtocol() then
        return
    end

    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("DC-MythicPlus: Token Vendor UI opened locally (waiting for server data).")
    end
end
