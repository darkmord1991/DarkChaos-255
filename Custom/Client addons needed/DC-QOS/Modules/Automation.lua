-- ============================================================
-- DC-QoS: Automation Module
-- ============================================================
-- Automated quality-of-life features
-- Adapted from Leatrix Plus for WoW 3.3.5a compatibility
-- ============================================================

local addon = DCQOS

-- ============================================================
-- Module Configuration
-- ============================================================
local Automation = {
    displayName = "Automation",
    settingKey = "automation",
    icon = "Interface\\Icons\\Ability_Repair",
}

-- ============================================================
-- Auto Repair
-- ============================================================
local function SetupAutoRepair()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("MERCHANT_SHOW")
    frame:SetScript("OnEvent", function(self, event)
        local settings = addon.settings.automation
        if not settings.enabled or not settings.autoRepair then return end
        
        if CanMerchantRepair() then
            local repairCost, canRepair = GetRepairAllCost()
            if canRepair and repairCost > 0 then
                local guildRepair = settings.autoRepairGuild and CanGuildBankRepair()
                
                if guildRepair then
                    RepairAllItems(true)  -- Use guild funds
                    addon:Print("Repaired all items using guild funds (" .. GetCoinTextureString(repairCost) .. ")")
                else
                    RepairAllItems(false) -- Use personal funds
                    addon:Print("Repaired all items (" .. GetCoinTextureString(repairCost) .. ")")
                end
            end
        end
    end)
end

-- ============================================================
-- Auto Sell Junk
-- ============================================================
local function SetupAutoSellJunk()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("MERCHANT_SHOW")
    frame:SetScript("OnEvent", function(self, event)
        local settings = addon.settings.automation
        if not settings.enabled or not settings.autoSellJunk then return end
        
        local totalPrice = 0
        local itemCount = 0
        
        -- Iterate through all bags
        for bag = 0, 4 do
            local numSlots = GetContainerNumSlots(bag)
            for slot = 1, numSlots do
                local itemLink = GetContainerItemLink(bag, slot)
                if itemLink then
                    local _, _, quality = GetItemInfo(itemLink)
                    if quality == 0 then  -- Poor quality (grey)
                        local _, count = GetContainerItemInfo(bag, slot)
                        local price = select(11, GetItemInfo(itemLink))
                        if price and price > 0 then
                            totalPrice = totalPrice + (price * (count or 1))
                            itemCount = itemCount + (count or 1)
                            UseContainerItem(bag, slot)
                        end
                    end
                end
            end
        end
        
        if itemCount > 0 then
            addon:Print("Sold " .. itemCount .. " junk items for " .. GetCoinTextureString(totalPrice))
        end
    end)
end

-- ============================================================
-- Auto Dismount
-- ============================================================
local function SetupAutoDismount()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("UI_ERROR_MESSAGE")
    frame:SetScript("OnEvent", function(self, event, errorType, message)
        local settings = addon.settings.automation
        if not settings.enabled or not settings.autoDismount then return end
        
        -- Check for mount-related error messages
        if message == SPELL_FAILED_NOT_STANDING 
           or message == ERR_ATTACK_MOUNTED 
           or message == ERR_NOT_WHILE_MOUNTED then
            Dismount()
        end
    end)
end

-- ============================================================
-- Auto Accept Summon
-- ============================================================
local function SetupAutoAcceptSummon()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("CONFIRM_SUMMON")
    frame:SetScript("OnEvent", function(self, event)
        local settings = addon.settings.automation
        if not settings.enabled or not settings.autoAcceptSummon then return end
        
        local summoner = GetSummonConfirmSummoner()
        local area = GetSummonConfirmAreaName()
        
        if summoner and area then
            ConfirmSummon()
            StaticPopup_Hide("CONFIRM_SUMMON")
            addon:Print("Auto-accepted summon from " .. summoner .. " to " .. area)
        end
    end)
end

-- ============================================================
-- Auto Accept Resurrect
-- ============================================================
local function SetupAutoAcceptResurrect()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("RESURRECT_REQUEST")
    frame:SetScript("OnEvent", function(self, event, resser)
        local settings = addon.settings.automation
        if not settings.enabled or not settings.autoAcceptResurrect then return end
        
        -- Don't auto-accept in combat
        if UnitAffectingCombat("player") then return end
        
        AcceptResurrect()
        StaticPopup_Hide("RESURRECT_NO_TIMER")
        StaticPopup_Hide("RESURRECT_NO_SICKNESS")
        addon:Print("Auto-accepted resurrection from " .. (resser or "unknown"))
    end)
end

-- ============================================================
-- Auto Decline Duels
-- ============================================================
local function SetupAutoDeclineDuels()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("DUEL_REQUESTED")
    frame:SetScript("OnEvent", function(self, event, challenger)
        local settings = addon.settings.automation
        if not settings.enabled or not settings.autoDeclineDuels then return end
        
        CancelDuel()
        StaticPopup_Hide("DUEL_REQUESTED")
        addon:Debug("Auto-declined duel from " .. (challenger or "unknown"))
    end)
end

-- ============================================================
-- Auto Decline Guild Invites
-- ============================================================
local function SetupAutoDeclineGuildInvites()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("GUILD_INVITE_REQUEST")
    frame:SetScript("OnEvent", function(self, event, inviter, guildName)
        local settings = addon.settings.automation
        if not settings.enabled or not settings.autoDeclineGuildInvites then return end
        
        DeclineGuild()
        StaticPopup_Hide("GUILD_INVITE")
        addon:Debug("Auto-declined guild invite to " .. (guildName or "unknown"))
    end)
end

-- ============================================================
-- Auto Accept Party Invites
-- ============================================================
local function SetupAutoAcceptPartyInvites()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PARTY_INVITE_REQUEST")
    frame:SetScript("OnEvent", function(self, event, inviter)
        local settings = addon.settings.automation
        if not settings.enabled or not settings.autoAcceptPartyInvites then return end
        
        -- Only auto-accept from friends or guild members
        local isFriend = false
        local isGuild = false
        
        -- Check friends list
        for i = 1, GetNumFriends() do
            local name = GetFriendInfo(i)
            if name and name == inviter then
                isFriend = true
                break
            end
        end
        
        -- Check if in same guild
        if IsInGuild() then
            for i = 1, GetNumGuildMembers() do
                local name = GetGuildRosterInfo(i)
                if name and name == inviter then
                    isGuild = true
                    break
                end
            end
        end
        
        if isFriend or isGuild then
            AcceptGroup()
            StaticPopup_Hide("PARTY_INVITE")
            addon:Print("Auto-accepted party invite from " .. inviter)
        end
    end)
end

-- ============================================================
-- Module Callbacks
-- ============================================================
function Automation.OnInitialize()
    addon:Debug("Automation module initializing")
end

function Automation.OnEnable()
    addon:Debug("Automation module enabling")
    
    SetupAutoRepair()
    SetupAutoSellJunk()
    SetupAutoDismount()
    SetupAutoAcceptSummon()
    SetupAutoAcceptResurrect()
    SetupAutoDeclineDuels()
    SetupAutoDeclineGuildInvites()
    SetupAutoAcceptPartyInvites()
end

function Automation.OnDisable()
    addon:Debug("Automation module disabling")
    -- Note: Event frames remain registered but check enabled state
end

-- ============================================================
-- Settings Panel Creation
-- ============================================================
function Automation.CreateSettings(parent)
    local settings = addon.settings.automation
    
    -- Title
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Automation Settings")
    
    -- Description
    local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText("Configure automatic actions to streamline gameplay.")
    desc:SetWidth(parent:GetWidth() - 32)
    desc:SetJustifyH("LEFT")
    
    local yOffset = -70
    
    -- ============================================================
    -- Merchant Section
    -- ============================================================
    local merchantHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    merchantHeader:SetPoint("TOPLEFT", 16, yOffset)
    merchantHeader:SetText("Merchant Automation")
    yOffset = yOffset - 25
    
    -- Auto Repair
    local repairCb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    repairCb:SetPoint("TOPLEFT", 16, yOffset)
    repairCb.Text:SetText("Auto Repair")
    repairCb:SetChecked(settings.autoRepair)
    repairCb:SetScript("OnClick", function(self)
        addon:SetSetting("automation.autoRepair", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    -- Use Guild Funds
    local guildRepairCb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    guildRepairCb:SetPoint("TOPLEFT", 36, yOffset)
    guildRepairCb.Text:SetText("Use Guild Funds when available")
    guildRepairCb:SetChecked(settings.autoRepairGuild)
    guildRepairCb:SetScript("OnClick", function(self)
        addon:SetSetting("automation.autoRepairGuild", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    -- Auto Sell Junk
    local sellJunkCb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    sellJunkCb:SetPoint("TOPLEFT", 16, yOffset)
    sellJunkCb.Text:SetText("Auto Sell Junk (Grey Items)")
    sellJunkCb:SetChecked(settings.autoSellJunk)
    sellJunkCb:SetScript("OnClick", function(self)
        addon:SetSetting("automation.autoSellJunk", self:GetChecked())
    end)
    yOffset = yOffset - 35
    
    -- ============================================================
    -- Social Section
    -- ============================================================
    local socialHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    socialHeader:SetPoint("TOPLEFT", 16, yOffset)
    socialHeader:SetText("Social Automation")
    yOffset = yOffset - 25
    
    -- Auto Accept Summon
    local summonCb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    summonCb:SetPoint("TOPLEFT", 16, yOffset)
    summonCb.Text:SetText("Auto Accept Summons")
    summonCb:SetChecked(settings.autoAcceptSummon)
    summonCb:SetScript("OnClick", function(self)
        addon:SetSetting("automation.autoAcceptSummon", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    -- Auto Accept Resurrect
    local resCb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    resCb:SetPoint("TOPLEFT", 16, yOffset)
    resCb.Text:SetText("Auto Accept Resurrections (out of combat)")
    resCb:SetChecked(settings.autoAcceptResurrect)
    resCb:SetScript("OnClick", function(self)
        addon:SetSetting("automation.autoAcceptResurrect", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    -- Auto Accept Party (Friends/Guild)
    local partyCb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    partyCb:SetPoint("TOPLEFT", 16, yOffset)
    partyCb.Text:SetText("Auto Accept Party Invites (Friends/Guild only)")
    partyCb:SetChecked(settings.autoAcceptPartyInvites)
    partyCb:SetScript("OnClick", function(self)
        addon:SetSetting("automation.autoAcceptPartyInvites", self:GetChecked())
    end)
    yOffset = yOffset - 35
    
    -- ============================================================
    -- Decline Section
    -- ============================================================
    local declineHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    declineHeader:SetPoint("TOPLEFT", 16, yOffset)
    declineHeader:SetText("Auto Decline")
    yOffset = yOffset - 25
    
    -- Auto Decline Duels
    local duelCb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    duelCb:SetPoint("TOPLEFT", 16, yOffset)
    duelCb.Text:SetText("Auto Decline Duels")
    duelCb:SetChecked(settings.autoDeclineDuels)
    duelCb:SetScript("OnClick", function(self)
        addon:SetSetting("automation.autoDeclineDuels", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    -- Auto Decline Guild Invites
    local guildInvCb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    guildInvCb:SetPoint("TOPLEFT", 16, yOffset)
    guildInvCb.Text:SetText("Auto Decline Guild Invites")
    guildInvCb:SetChecked(settings.autoDeclineGuildInvites)
    guildInvCb:SetScript("OnClick", function(self)
        addon:SetSetting("automation.autoDeclineGuildInvites", self:GetChecked())
    end)
    yOffset = yOffset - 35
    
    -- ============================================================
    -- Misc Section
    -- ============================================================
    local miscHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    miscHeader:SetPoint("TOPLEFT", 16, yOffset)
    miscHeader:SetText("Miscellaneous")
    yOffset = yOffset - 25
    
    -- Auto Dismount
    local dismountCb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    dismountCb:SetPoint("TOPLEFT", 16, yOffset)
    dismountCb.Text:SetText("Auto Dismount on action")
    dismountCb:SetChecked(settings.autoDismount)
    dismountCb:SetScript("OnClick", function(self)
        addon:SetSetting("automation.autoDismount", self:GetChecked())
    end)
    
    return yOffset - 50
end

-- ============================================================
-- Register Module
-- ============================================================
addon:RegisterModule("Automation", Automation)
