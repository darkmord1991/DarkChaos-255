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

KUI.currentState = KUI.STATE.IDLE
KUI.keystoneData = nil
KUI.readyStates = {}
KUI.countdownValue = 10

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
    
    -- Dark background
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(0.02, 0.02, 0.05, 0.98)
    
    -- Glowing border (mythic+ theme)
    local border = CreateFrame("Frame", nil, frame, "BackdropTemplate" or nil)
    border:SetPoint("TOPLEFT", -3, 3)
    border:SetPoint("BOTTOMRIGHT", 3, -3)
    if border.SetBackdrop then
        border:SetBackdrop({
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 16,
        })
        border:SetBackdropBorderColor(0.2, 0.6, 1.0, 0.9)
    end
    
    -- Top decorative bar
    local topBar = frame:CreateTexture(nil, "ARTWORK")
    topBar:SetPoint("TOPLEFT", 2, -2)
    topBar:SetPoint("TOPRIGHT", -2, -2)
    topBar:SetHeight(4)
    topBar:SetColorTexture(0.2, 0.6, 1.0, 0.8)
    
    -- Title: "MYTHIC KEYSTONE"
    local title = frame:CreateFontString(nil, "OVERLAY")
    title:SetFont("Fonts\\FRIZQT__.TTF", 20, "OUTLINE")
    title:SetPoint("TOP", 0, -20)
    title:SetText("|cff32c4ffMYTHIC KEYSTONE|r")
    frame.title = title
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function()
        KUI:CancelActivation()
    end)
    
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
    iconBorder:SetSize(88, 88)
    iconBorder:SetPoint("CENTER", keystoneIcon, "CENTER")
    iconBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    iconBorder:SetBlendMode("ADD")
    iconBorder:SetVertexColor(0.2, 0.6, 1.0, 0.8)
    
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
    
    -- Affix icons container
    frame.affixIcons = {}
    for i = 1, 4 do
        local affixFrame = CreateFrame("Frame", nil, affixSection)
        affixFrame:SetSize(36, 36)
        affixFrame:SetPoint("LEFT", 20 + ((i - 1) * 50), -25)
        
        local icon = affixFrame:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        affixFrame.icon = icon
        
        local border = affixFrame:CreateTexture(nil, "OVERLAY")
        border:SetSize(42, 42)
        border:SetPoint("CENTER")
        border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        border:SetBlendMode("ADD")
        
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
        slot.bg:SetColorTexture(0.1, 0.1, 0.15, 0.9)
        
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
    
    -- Ready button (for party members)
    local readyBtn = CreateFrame("Button", nil, buttonSection, "UIPanelButtonTemplate")
    readyBtn:SetSize(120, 30)
    readyBtn:SetPoint("LEFT", 40, 0)
    readyBtn:SetText("Ready!")
    readyBtn:SetScript("OnClick", function()
        KUI:SendReady()
    end)
    frame.readyBtn = readyBtn
    
    -- Start button (for leader only)
    local startBtn = CreateFrame("Button", nil, buttonSection, "UIPanelButtonTemplate")
    startBtn:SetSize(150, 30)
    startBtn:SetPoint("CENTER")
    startBtn:SetText("Activate Keystone")
    startBtn:Disable()
    startBtn:SetScript("OnClick", function()
        KUI:StartActivation()
    end)
    frame.startBtn = startBtn
    
    -- Cancel button
    local cancelBtn = CreateFrame("Button", nil, buttonSection, "UIPanelButtonTemplate")
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
                affixFrame.icon:SetTexture(self.AFFIX_ICONS[affix.id] or "Interface\\Icons\\INV_Misc_QuestionMark")
                affixFrame.affixName = affix.name
                affixFrame.affixDesc = affix.description
                affixFrame:Show()
            end
        end
        -- Hide unused affix slots
        for i = #data.affixes + 1, 4 do
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
