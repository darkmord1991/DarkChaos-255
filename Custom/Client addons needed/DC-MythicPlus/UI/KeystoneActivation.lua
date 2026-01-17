-- DC-MythicPlus/UI/KeystoneActivation.lua
-- Retail-style Keystone Activation UI with group ready check
-- Clones the retail WoW interface when inserting a keystone into Font of Power

local addonName = "DC-MythicPlus"
local namespace = _G.DCMythicPlusHUD or {}
_G.DCMythicPlusHUD = namespace

namespace.KeystoneUI = namespace.KeystoneUI or {}
local KUI = namespace.KeystoneUI

-- =====================================================================
-- Constants
-- =====================================================================

KUI.STATE = {
    IDLE = 0,
    INSERTED = 1,
    READY_CHECK = 2,
    COUNTDOWN = 3,
    STARTING = 4,
}

KUI.AFFIX_ICONS = {
    -- Placeholder affix icons - will be replaced with actual textures
    [1] = "Interface\\Icons\\Spell_Nature_Earthquake",    -- Fortified
    [2] = "Interface\\Icons\\Ability_Warrior_BattleShout", -- Tyrannical
    [3] = "Interface\\Icons\\Spell_Fire_Immolation",      -- Bolstering
    [4] = "Interface\\Icons\\Spell_Shadow_SoulGem",       -- Raging
    [5] = "Interface\\Icons\\Spell_Nature_Thorns",        -- Sanguine
    [6] = "Interface\\Icons\\Spell_Frost_ChillingBlast",  -- Necrotic
    [7] = "Interface\\Icons\\Spell_Shadow_AnimateDead",   -- Explosive
    [8] = "Interface\\Icons\\Ability_Rogue_Disguise",     -- Quaking
    [9] = "Interface\\Icons\\Spell_Nature_NatureGuardian", -- Grievous
    [10] = "Interface\\Icons\\Inv_Misc_Volatilefire",     -- Volcanic
    [11] = "Interface\\Icons\\Spell_Nature_MagicImmunity", -- Spiteful
    [12] = "Interface\\Icons\\Spell_Nature_CorrosiveBreath", -- Bursting
}

local function ResolveAffixInfo(affix)
    if type(affix) == "table" then
        local id = affix.id or affix.spellId or affix.spellID or affix.affixId
        local name = affix.name or affix.affixName or affix.spellName
        local desc = affix.description or affix.desc or affix.affixDesc
        local icon = affix.icon
        if not icon and id and type(GetSpellTexture) == "function" then
            icon = GetSpellTexture(id)
        end
        if not name and id and type(GetSpellInfo) == "function" then
            name = GetSpellInfo(id)
        end
        return id, name, desc, icon
    end
    if type(affix) == "number" then
        local name = type(GetSpellInfo) == "function" and GetSpellInfo(affix) or nil
        local icon = type(GetSpellTexture) == "function" and GetSpellTexture(affix) or nil
        return affix, name, nil, icon
    end
    if type(affix) == "string" then
        local num = tonumber(affix)
        if num then
            local name = type(GetSpellInfo) == "function" and GetSpellInfo(num) or nil
            local icon = type(GetSpellTexture) == "function" and GetSpellTexture(num) or nil
            return num, name or affix, nil, icon
        end
        return nil, affix, nil, nil
    end
    return nil, nil, nil, nil
end

KUI.currentState = KUI.STATE.IDLE
KUI.keystoneData = nil
KUI.readyStates = {}
KUI.countdownValue = 10

-- Match DC-Leaderboards UI style across DC addons
local BG_FELLEATHER = "Interface\\AddOns\\DC-MythicPlus\\Textures\\Backgrounds\\FelLeather_512.tga"
local BG_TINT_ALPHA = 0.60

local function ApplyLeaderboardsStyle(frame)
    if not frame or frame.__dcLeaderboardsStyle then return end
    frame.__dcLeaderboardsStyle = true

    if frame.SetBackdropColor then
        frame:SetBackdropColor(0, 0, 0, 0)
    end

    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
    bg:SetAllPoints()
    bg:SetTexture(BG_FELLEATHER)
    if bg.SetHorizTile then bg:SetHorizTile(false) end
    if bg.SetVertTile then bg:SetVertTile(false) end

    local tint = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    tint:SetAllPoints()
    tint:SetTexture(0, 0, 0, BG_TINT_ALPHA)

    frame.__dcBg = bg
    frame.__dcTint = tint
end

-- =====================================================================
-- Print Helper
-- =====================================================================

local function Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff32c4ffKeystone:|r " .. (msg or ""))
    end
end
KUI.Print = Print

-- =====================================================================
-- Main Keystone Activation Frame
-- =====================================================================

function KUI:CreateActivationFrame()
    if self.frame then return self.frame end

    local frame = CreateFrame("Frame", "DCKeystoneActivationFrame", UIParent)
    frame:SetSize(500, 400)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    -- Background (WotLK/Retail style)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    ApplyLeaderboardsStyle(frame)

    if frame.TitleText then
        frame.TitleText:SetText("Dungeon Finder")
    end
    
    -- Close Button
    frame.CloseButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.CloseButton:SetPoint("TOPRIGHT", -8, -8)
    frame.CloseButton:SetScript("OnClick", function()
        KUI:CancelActivation()
    end)

    -- Title: "MYTHIC KEYSTONE"
    local title = frame:CreateFontString(nil, "OVERLAY")
    title:SetFont("Fonts\\FRIZQT__.TTF", 18, "OUTLINE")
    title:SetPoint("TOP", 0, -20)
    title:SetText("MYTHIC KEYSTONE")
    title:SetTextColor(1, 0.82, 0, 1)
    frame.title = title
    
    -- =====================================================
    -- Keystone Display Section (top half)
    -- =====================================================
    
    local keystoneSection = CreateFrame("Frame", nil, frame)
    keystoneSection:SetPoint("TOPLEFT", 20, -50)
    keystoneSection:SetPoint("TOPRIGHT", -20, -50)
    keystoneSection:SetHeight(150)
    
    -- Keystone icon (large)
    local keystoneIcon = keystoneSection:CreateTexture(nil, "ARTWORK")
    keystoneIcon:SetSize(80, 80)
    keystoneIcon:SetPoint("LEFT", 20, 0)
    keystoneIcon:SetTexture("Interface\\Icons\\INV_Relics_Hourglass") -- Keystone placeholder
    frame.keystoneIcon = keystoneIcon
    
    -- Keystone icon border
    local iconBorder = keystoneSection:CreateTexture(nil, "OVERLAY")
    iconBorder:SetSize(82, 82)
    iconBorder:SetPoint("CENTER", keystoneIcon, "CENTER")
    iconBorder:SetColorTexture(0.3, 0.3, 0.3, 1)
    iconBorder:SetDrawLayer("OVERLAY", -1)
    
    -- Dungeon name
    local dungeonName = keystoneSection:CreateFontString(nil, "OVERLAY")
    dungeonName:SetFont("Fonts\\FRIZQT__.TTF", 18, "OUTLINE")
    dungeonName:SetPoint("TOPLEFT", keystoneIcon, "TOPRIGHT", 20, -5)
    dungeonName:SetText("Dungeon Name")
    dungeonName:SetTextColor(1, 0.82, 0)
    frame.dungeonName = dungeonName
    
    -- Keystone level
    local keystoneLevel = keystoneSection:CreateFontString(nil, "OVERLAY")
    keystoneLevel:SetFont("Fonts\\FRIZQT__.TTF", 24, "OUTLINE")
    keystoneLevel:SetPoint("TOPLEFT", dungeonName, "BOTTOMLEFT", 0, -8)
    keystoneLevel:SetText("|cff32c4ff+15|r")
    frame.keystoneLevel = keystoneLevel
    
    -- Time limit
    local timeLimit = keystoneSection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    timeLimit:SetPoint("TOPLEFT", keystoneLevel, "BOTTOMLEFT", 0, -10)
    timeLimit:SetText("Time Limit: 30:00")
    timeLimit:SetTextColor(0.7, 0.7, 0.7)
    frame.timeLimit = timeLimit
    
    -- =====================================================
    -- Affixes Section
    -- =====================================================
    
    local affixSection = CreateFrame("Frame", nil, frame)
    affixSection:SetPoint("TOPLEFT", keystoneSection, "BOTTOMLEFT", 0, -10)
    affixSection:SetPoint("TOPRIGHT", keystoneSection, "BOTTOMRIGHT", 0, -10)
    affixSection:SetHeight(50)
    
    local affixLabel = affixSection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    affixLabel:SetPoint("TOPLEFT", 20, -5)
    affixLabel:SetText("Active Affixes:")
    affixLabel:SetTextColor(1, 0.82, 0, 1)
    
    -- Affix icons container
    frame.affixIcons = {}
    for i = 1, 4 do
        local affixFrame = CreateFrame("Frame", nil, affixSection)
        affixFrame:SetSize(36, 36)
        affixFrame:SetPoint("LEFT", 20 + ((i - 1) * 50), -25)
        
        local icon = affixFrame:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", -1, 1)
        icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        affixFrame.icon = icon
        
        local border = affixFrame:CreateTexture(nil, "BACKGROUND")
        border:SetAllPoints()
        border:SetColorTexture(0.3, 0.3, 0.3, 1)
        
        -- Tooltip
        affixFrame:EnableMouse(true)
        affixFrame:SetScript("OnEnter", function(self)
            if self.affixName then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.affixName, 1, 1, 1)
                if self.affixDesc then
                    GameTooltip:AddLine(self.affixDesc, 1, 0.82, 0, true)
                end
                GameTooltip:Show()
            end
        end)
        affixFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
        
        affixFrame:Hide()
        frame.affixIcons[i] = affixFrame
    end
    
    -- =====================================================
    -- Party Ready Section
    -- =====================================================
    
    local readySection = CreateFrame("Frame", nil, frame)
    readySection:SetPoint("TOPLEFT", affixSection, "BOTTOMLEFT", 0, -10)
    readySection:SetPoint("TOPRIGHT", affixSection, "BOTTOMRIGHT", 0, -10)
    readySection:SetHeight(100)
    
    local readyLabel = readySection:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    readyLabel:SetPoint("TOP", 0, -5)
    readyLabel:SetText("Party Ready Check")
    readyLabel:SetTextColor(1, 0.82, 0, 1)
    frame.readyLabel = readyLabel
    
    -- Party member slots
    frame.partySlots = {}
    local slotWidth = 80
    local startX = (500 - (slotWidth * 5)) / 2
    
    for i = 1, 5 do
        local slot = CreateFrame("Frame", nil, readySection)
        slot:SetSize(slotWidth - 6, 50)
        slot:SetPoint("TOPLEFT", startX + ((i - 1) * slotWidth), -30)
        
        slot.bg = slot:CreateTexture(nil, "BACKGROUND")
        slot.bg:SetAllPoints()
        slot.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
        
        slot.border = slot:CreateTexture(nil, "BORDER")
        slot.border:SetAllPoints()
        slot.border:SetColorTexture(0.3, 0.3, 0.3, 1)
        slot.border:SetDrawLayer("BORDER", -1)
        
        local slotInner = slot:CreateTexture(nil, "BACKGROUND", nil, 1)
        slotInner:SetPoint("TOPLEFT", 1, -1)
        slotInner:SetPoint("BOTTOMRIGHT", -1, 1)
        slotInner:SetColorTexture(0.1, 0.1, 0.1, 0.8)
        
        -- Role icon
        slot.roleIcon = slot:CreateTexture(nil, "ARTWORK")
        slot.roleIcon:SetSize(20, 20)
        slot.roleIcon:SetPoint("TOP", 0, -5)
        slot.roleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
        slot.roleIcon:SetTexCoord(0, 0.296875, 0.34375, 0.640625) -- Tank
        
        -- Name
        slot.nameText = slot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        slot.nameText:SetPoint("TOP", slot.roleIcon, "BOTTOM", 0, -2)
        slot.nameText:SetText("Player " .. i)
        slot.nameText:SetWidth(slotWidth - 10)
        slot.nameText:SetTextColor(1, 1, 1, 1)
        
        -- Ready status icon
        slot.statusIcon = slot:CreateTexture(nil, "OVERLAY")
        slot.statusIcon:SetSize(16, 16)
        slot.statusIcon:SetPoint("BOTTOM", 0, 5)
        slot.statusIcon:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Waiting")
        
        slot:Hide()
        frame.partySlots[i] = slot
    end
    
    -- =====================================================
    -- Countdown Section
    -- =====================================================
    
    local countdownSection = CreateFrame("Frame", nil, frame)
    countdownSection:SetPoint("TOPLEFT", readySection, "BOTTOMLEFT", 0, 0)
    countdownSection:SetPoint("TOPRIGHT", readySection, "BOTTOMRIGHT", 0, 0)
    countdownSection:SetHeight(50)
    
    frame.countdownText = countdownSection:CreateFontString(nil, "OVERLAY")
    frame.countdownText:SetFont("Fonts\\FRIZQT__.TTF", 36, "OUTLINE")
    frame.countdownText:SetPoint("CENTER")
    frame.countdownText:SetText("")
    frame.countdownText:Hide()
    
    -- =====================================================
    -- Buttons Section
    -- =====================================================
    
    local buttonSection = CreateFrame("Frame", nil, frame)
    buttonSection:SetPoint("BOTTOMLEFT", 20, 20)
    buttonSection:SetPoint("BOTTOMRIGHT", -20, 20)
    buttonSection:SetHeight(40)
    
    local function CreateStyledButton(parent, text, width)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(width, 30)
        
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.bg:SetColorTexture(0.2, 0.2, 0.2, 1)
        
        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        btn.text:SetPoint("CENTER")
        btn.text:SetText(text)
        btn:SetFontString(btn.text)
        
        btn:SetScript("OnEnter", function(self)
            if self:IsEnabled() then
                self.bg:SetColorTexture(0.3, 0.3, 0.3, 1)
            end
        end)
        btn:SetScript("OnLeave", function(self)
            if self:IsEnabled() then
                self.bg:SetColorTexture(0.2, 0.2, 0.2, 1)
            else
                self.bg:SetColorTexture(0.1, 0.1, 0.1, 1)
            end
        end)
        btn:SetScript("OnEnable", function(self)
            self.bg:SetColorTexture(0.2, 0.2, 0.2, 1)
            self.text:SetTextColor(1, 1, 1, 1)
        end)
        btn:SetScript("OnDisable", function(self)
            self.bg:SetColorTexture(0.1, 0.1, 0.1, 1)
            self.text:SetTextColor(0.5, 0.5, 0.5, 1)
        end)
        
        return btn
    end
    
    -- Ready button (for party members)
    local readyBtn = CreateStyledButton(buttonSection, "Ready!", 120)
    readyBtn:SetPoint("LEFT", 40, 0)
    readyBtn:SetScript("OnClick", function()
        KUI:SendReady()
    end)
    frame.readyBtn = readyBtn
    
    -- Start button (for leader only)
    local startBtn = CreateStyledButton(buttonSection, "Activate Keystone", 150)
    startBtn:SetPoint("CENTER")
    startBtn:Disable()
    startBtn:SetScript("OnClick", function()
        KUI:StartActivation()
    end)
    frame.startBtn = startBtn
    
    -- Cancel button
    local cancelBtn = CreateStyledButton(buttonSection, "Cancel", 100)
    cancelBtn:SetSize(100, 30)
    cancelBtn:SetPoint("RIGHT", -40, 0)
    cancelBtn:SetText("Cancel")
    cancelBtn:SetScript("OnClick", function()
        KUI:CancelActivation()
    end)
    frame.cancelBtn = cancelBtn
    
    -- Status text
    frame.statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.statusText:SetPoint("BOTTOM", buttonSection, "TOP", 0, 5)
    frame.statusText:SetText("Waiting for party...")
    frame.statusText:SetTextColor(0.7, 0.7, 0.7)
    
    self.frame = frame
    tinsert(UISpecialFrames, "DCKeystoneActivationFrame")
    
    return frame
end

-- =====================================================================
-- Update Functions
-- =====================================================================

function KUI:SetKeystoneData(data)
    self.keystoneData = data
    
    if not self.frame then return end
    
    -- Update display
    if data.dungeon then
        self.frame.dungeonName:SetText(data.dungeon)
    end
    
    if data.level then
        self.frame.keystoneLevel:SetText(string.format("|cff32c4ff+%d|r", data.level))
    end
    
    if data.timeLimit then
        local mins = math.floor(data.timeLimit / 60)
        local secs = data.timeLimit % 60
        self.frame.timeLimit:SetText(string.format("Time Limit: %d:%02d", mins, secs))
    end
    
    -- Update affixes
    if data.affixes then
        for i, affix in ipairs(data.affixes) do
            local affixFrame = self.frame.affixIcons[i]
            if affixFrame then
                local id, name, desc, icon = ResolveAffixInfo(affix)
                affixFrame.icon:SetTexture(self.AFFIX_ICONS[id] or icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                affixFrame.affixName = name
                affixFrame.affixDesc = desc
                affixFrame:Show()
            end
        end
        -- Hide unused affix slots
        for i = #data.affixes + 1, 4 do
            if self.frame.affixIcons[i] then
                self.frame.affixIcons[i]:Hide()
            end
        end
    else
        for i = 1, 4 do
            if self.frame.affixIcons[i] then
                self.frame.affixIcons[i]:Hide()
            end
        end
    end
end

function KUI:SetPartyMembers(members)
    if not self.frame then return end
    
    for i, slot in ipairs(self.frame.partySlots) do
        if members and members[i] then
            local member = members[i]
            slot.nameText:SetText(member.name or ("Player " .. i))
            
            -- Set role icon
            if member.role == "TANK" then
                slot.roleIcon:SetTexCoord(0, 0.296875, 0.34375, 0.640625)
            elseif member.role == "HEALER" then
                slot.roleIcon:SetTexCoord(0.296875, 0.59375, 0, 0.296875)
            else
                slot.roleIcon:SetTexCoord(0.296875, 0.59375, 0.34375, 0.640625)
            end
            
            -- Set ready status
            if member.ready then
                slot.statusIcon:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready")
            elseif member.declined then
                slot.statusIcon:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-NotReady")
            else
                slot.statusIcon:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Waiting")
            end
            
            slot:Show()
        else
            slot:Hide()
        end
    end
end

function KUI:UpdateReadyState(playerName, isReady)
    self.readyStates[playerName] = isReady
    
    -- Update party slots
    if self.frame then
        for i, slot in ipairs(self.frame.partySlots) do
            if slot:IsShown() and slot.nameText:GetText() == playerName then
                if isReady then
                    slot.statusIcon:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready")
                else
                    slot.statusIcon:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-NotReady")
                end
            end
        end
    end
    
    -- Check if all ready
    self:CheckAllReady()
end

function KUI:CheckAllReady()
    if not self.frame then return end
    
    local allReady = true
    for i, slot in ipairs(self.frame.partySlots) do
        if slot:IsShown() then
            local playerName = slot.nameText:GetText()
            if not self.readyStates[playerName] then
                allReady = false
                break
            end
        end
    end
    
    -- Enable start button if leader and all ready
    if allReady and self.isLeader then
        self.frame.startBtn:Enable()
        self.frame.statusText:SetText("|cff00ff00All players ready!|r")
    else
        self.frame.startBtn:Disable()
        local readyCount = 0
        local totalCount = 0
        for i, slot in ipairs(self.frame.partySlots) do
            if slot:IsShown() then
                totalCount = totalCount + 1
                if self.readyStates[slot.nameText:GetText()] then
                    readyCount = readyCount + 1
                end
            end
        end
        self.frame.statusText:SetText(string.format("Ready: %d/%d", readyCount, totalCount))
    end
end

-- =====================================================================
-- State Management
-- =====================================================================

function KUI:Show(keystoneData, isLeader)
    if not self.frame then
        self:CreateActivationFrame()
    end
    
    self.currentState = self.STATE.INSERTED
    self.isLeader = isLeader
    self.readyStates = {}
    
    if keystoneData then
        self:SetKeystoneData(keystoneData)
    end
    
    -- Show/hide leader-specific elements
    if isLeader then
        self.frame.startBtn:Show()
        self.frame.readyBtn:Hide()
    else
        self.frame.startBtn:Hide()
        self.frame.readyBtn:Show()
    end
    
    self.frame.countdownText:Hide()
    self.frame:Show()
    
    Print("Keystone activation window opened")
end

function KUI:SendReady()
    Print("Sending ready status...")
    local DC = rawget(_G, "DCAddonProtocol")
    if DC then
        DC:Request("MPLUS", 0x42, { ready = true })
    end
    
    -- Update local UI
    local playerName = UnitName("player")
    self:UpdateReadyState(playerName, true)
    
    -- Disable ready button
    if self.frame then
        self.frame.readyBtn:Disable()
        self.frame.readyBtn:SetText("Ready!")
    end
end

function KUI:StartActivation()
    if not self.isLeader then
        Print("|cffff0000Only the party leader can start the keystone!|r")
        return
    end
    
    Print("Starting keystone activation...")
    local DC = rawget(_G, "DCAddonProtocol")
    if DC then
        DC:Request("MPLUS", 0x40, { action = "activate" })
    end
end

function KUI:StartCountdown(seconds)
    self.currentState = self.STATE.COUNTDOWN
    self.countdownValue = seconds or 10
    
    if not self.frame then return end
    
    self.frame.countdownText:Show()
    self.frame.statusText:SetText("|cff00ff00Starting...|r")
    self.frame.startBtn:Disable()
    self.frame.readyBtn:Disable()
    
    -- Countdown timer
    self.countdownFrame = self.countdownFrame or CreateFrame("Frame")
    self.countdownFrame.elapsed = 0
    self.countdownFrame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed >= 1 then
            self.elapsed = 0
            KUI.countdownValue = KUI.countdownValue - 1
            
            if KUI.countdownValue > 0 then
                KUI.frame.countdownText:SetText(string.format("|cff%s%d|r",
                    KUI.countdownValue <= 3 and "ff4444" or "ffff00",
                    KUI.countdownValue))
                -- Play sound
                PlaySound(8960) -- RAID_WARNING
            else
                KUI.countdownFrame:SetScript("OnUpdate", nil)
                KUI.frame.countdownText:SetText("|cff00ff00GO!|r")
                KUI.currentState = KUI.STATE.STARTING
                
                -- Hide after brief delay
                C_Timer.After(1.5, function()
                    if KUI.frame then
                        KUI.frame:Hide()
                    end
                end)
            end
        end
    end)
    
    -- Show initial countdown
    self.frame.countdownText:SetText(string.format("|cffffcc00%d|r", self.countdownValue))
end

function KUI:CancelActivation()
    Print("Cancelling keystone activation...")
    
    if self.countdownFrame then
        self.countdownFrame:SetScript("OnUpdate", nil)
    end
    
    local DC = rawget(_G, "DCAddonProtocol")
    if DC then
        DC:Request("MPLUS", 0x44, { action = "cancel" })
    end
    
    self.currentState = self.STATE.IDLE
    if self.frame then
        self.frame:Hide()
    end
end

function KUI:Hide()
    if self.frame then
        self.frame:Hide()
    end
    self.currentState = self.STATE.IDLE
end

-- =====================================================================
-- Protocol Handlers
-- =====================================================================

-- Called when server sends keystone ready check data
function KUI:OnKeystoneReadyCheck(data)
    if data.keystoneInfo then
        self:SetKeystoneData(data.keystoneInfo)
    end
    if data.partyMembers then
        self:SetPartyMembers(data.partyMembers)
    end
    self:Show(data.keystoneInfo, data.isLeader)
end

-- Called when a player's ready state changes
function KUI:OnPlayerReadyUpdate(data)
    if data.playerName and data.ready ~= nil then
        self:UpdateReadyState(data.playerName, data.ready)
    end
end

-- Called when countdown starts
function KUI:OnCountdownStart(data)
    local seconds = data.seconds or 10
    self:StartCountdown(seconds)
end

-- Called when activation is cancelled
function KUI:OnActivationCancelled(data)
    Print(data.reason or "Keystone activation cancelled")
    self:Hide()
end

Print("Keystone Activation UI module loaded")
