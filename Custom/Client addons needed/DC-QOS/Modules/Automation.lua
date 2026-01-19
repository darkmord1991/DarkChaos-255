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
    defaults = {
        automation = {
            enabled = true,
            autoRepair = true,
            autoRepairGuild = false,
            autoSellJunk = true,
            autoDismount = false,
            autoAcceptSummon = false,
            autoAcceptResurrect = false,
            autoDeclineDuels = false,
            autoDeclineGuildInvites = false,
            autoAcceptPartyInvites = false,
            autoAcceptQuests = false,
            autoTurnInQuests = false,
            -- New features
            autoStand = true,
            autoGossipSkip = false,
            autoReleaseInBG = false,
            autoConfirmBop = false,
            fasterLoot = true,
            skipCinematics = false,
        },
    },
}

-- Use shared utility for default merging
addon:MergeModuleDefaults(Automation.defaults)

-- Event frames storage for cleanup
local eventFrames = {}

-- ============================================================
-- Auto Repair
-- ============================================================
local function SetupAutoRepair()
    local frame = CreateFrame("Frame")
    table.insert(eventFrames, frame)
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
-- Auto Quest (Accept/Turn-in)
-- ============================================================
local function SetupAutoQuest()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("QUEST_DETAIL")
    frame:RegisterEvent("QUEST_ACCEPT_CONFIRM")
    frame:RegisterEvent("QUEST_PROGRESS")
    frame:RegisterEvent("QUEST_COMPLETE")
    
    frame:SetScript("OnEvent", function(self, event)
        local settings = addon.settings.automation
        if not settings.enabled then return end
        
        -- Don't automate if holding Shift
        if IsShiftKeyDown() then return end
        
        if (event == "QUEST_DETAIL" or event == "QUEST_ACCEPT_CONFIRM") and settings.autoAcceptQuests then
            AcceptQuest()
        elseif event == "QUEST_PROGRESS" and settings.autoTurnInQuests then
            if IsQuestCompletable() then
                CompleteQuest()
            end
        elseif event == "QUEST_COMPLETE" and settings.autoTurnInQuests then
            if GetNumQuestChoices() <= 1 then
                GetQuestReward(1)
            end
        end
    end)
end

-- ============================================================
-- Auto Stand (when eating/drinking interrupted)
-- ============================================================
local function SetupAutoStand()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("UNIT_AURA")
    
    local wasEatingDrinking = false
    
    frame:SetScript("OnEvent", function(self, event, unit)
        local settings = addon.settings.automation
        if not settings.enabled or not settings.autoStand then return end
        if unit ~= "player" then return end
        
        -- Check if currently eating or drinking
        local isEatingDrinking = false
        for i = 1, 40 do
            local name = UnitBuff("player", i)
            if not name then break end
            if name == "Food" or name == "Drink" or name == "Refreshment" then
                isEatingDrinking = true
                break
            end
        end
        
        -- If was eating/drinking but now not, and sitting, stand up
        if wasEatingDrinking and not isEatingDrinking then
            -- DoEmote("stand") -- Stand up if needed
        end
        
        wasEatingDrinking = isEatingDrinking
    end)
end

-- ============================================================
-- Auto Gossip Skip (trainers, flight masters, banks)
-- ============================================================
local function SetupAutoGossipSkip()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("GOSSIP_SHOW")
    
    frame:SetScript("OnEvent", function(self, event)
        local settings = addon.settings.automation
        if not settings.enabled or not settings.autoGossipSkip then return end
        
        -- Don't skip if holding Shift
        if IsShiftKeyDown() then return end
        
        -- Check if only one gossip option
        local numOptions = GetNumGossipOptions()
        local numQuests = GetNumGossipActiveQuests() + GetNumGossipAvailableQuests()
        
        if numOptions == 1 and numQuests == 0 then
            -- Check if it's a simple NPC (trainer, flight master, banker)
            local gossipOptions = { GetGossipOptions() }
            if gossipOptions[2] then
                local optionType = gossipOptions[2]
                if optionType == "trainer" or optionType == "taxi" or optionType == "banker" 
                   or optionType == "vendor" or optionType == "battlemaster" then
                    SelectGossipOption(1)
                end
            end
        end
    end)
end

-- ============================================================
-- Auto Release in Battlegrounds
-- ============================================================
local function SetupAutoReleaseInBG()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_DEAD")
    
    frame:SetScript("OnEvent", function(self, event)
        local settings = addon.settings.automation
        if not settings.enabled or not settings.autoReleaseInBG then return end
        
        -- Check if in a battleground
        local _, instanceType = IsInInstance()
        if instanceType == "pvp" or instanceType == "arena" then
            -- Small delay before releasing
            addon:DelayedCall(0.5, function()
                if UnitIsDead("player") then
                    RepopMe()
                end
            end)
        end
    end)
end

-- ============================================================
-- Auto Confirm Bind on Pickup
-- ============================================================
local function SetupAutoConfirmBop()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("LOOT_BIND_CONFIRM")
    frame:RegisterEvent("EQUIP_BIND_CONFIRM")
    frame:RegisterEvent("AUTOEQUIP_BIND_CONFIRM")
    frame:RegisterEvent("MAIL_LOCK_SEND_ITEMS")
    
    frame:SetScript("OnEvent", function(self, event, ...)
        local settings = addon.settings.automation
        if not settings.enabled or not settings.autoConfirmBop then return end
        
        if event == "LOOT_BIND_CONFIRM" then
            local slot = ...
            if slot then
                ConfirmLootSlot(slot)
            end
        elseif event == "EQUIP_BIND_CONFIRM" then
            local slot = ...
            if slot then
                EquipPendingItem(slot)
            end
        elseif event == "AUTOEQUIP_BIND_CONFIRM" then
            EquipPendingItem(0)
        elseif event == "MAIL_LOCK_SEND_ITEMS" then
            -- Auto-confirm mail with BoP items
            StaticPopup_Hide("MAIL_LOCK_SEND_ITEMS")
        end
    end)
end

-- ============================================================
-- Faster Loot (3.3.5a compatible)
-- ============================================================
local function SetupFasterLoot()
    local frame = CreateFrame("Frame")
    -- Note: LOOT_READY doesn't exist in 3.3.5a, use LOOT_OPENED instead
    frame:RegisterEvent("LOOT_OPENED")
    
    frame:SetScript("OnEvent", function(self, event, autoLoot)
        local settings = addon.settings.automation
        if not settings.enabled or not settings.fasterLoot then return end
        
        -- Only process with auto-loot enabled (check CVar or passed autoLoot)
        local isAutoLoot = autoLoot or (GetCVar("autoLootDefault") == "1")
        if not isAutoLoot then return end
        
        -- Loot all items quickly
        local numItems = GetNumLootItems()
        if numItems > 0 then
            for i = numItems, 1, -1 do
                LootSlot(i)
            end
        end
    end)
end

-- ============================================================
-- Skip Cinematics (3.3.5a compatible)
-- ============================================================
local function SetupSkipCinematics()
    -- Hook MovieFrame to auto-close
    if MovieFrame then
        MovieFrame:HookScript("OnShow", function(self)
            local settings = addon.settings.automation
            if not settings.enabled or not settings.skipCinematics then return end
            
            -- Stop and hide the movie
            if MovieFrame.StopMovie then
                MovieFrame:StopMovie()
            end
            MovieFrame:Hide()
        end)
    end
    
    -- Hook CinematicFrame to auto-close
    if CinematicFrame then
        CinematicFrame:HookScript("OnShow", function(self)
            local settings = addon.settings.automation
            if not settings.enabled or not settings.skipCinematics then return end
            
            -- Safely cancel cinematic (function may not exist in all 3.3.5a builds)
            if CinematicFrame_CancelCinematic then
                CinematicFrame_CancelCinematic()
            else
                -- Fallback: just hide the frame
                CinematicFrame:Hide()
            end
        end)
    end
end

-- ============================================================
-- Module Callbacks
-- ============================================================
function Automation.OnInitialize()
    addon:Debug("Automation module initializing")
end

function Automation.OnEnable()
    addon:Debug("Automation module enabling")
    
    -- Original features
    SetupAutoRepair()
    SetupAutoSellJunk()
    SetupAutoDismount()
    SetupAutoAcceptSummon()
    SetupAutoAcceptResurrect()
    SetupAutoDeclineDuels()
    SetupAutoDeclineGuildInvites()
    SetupAutoAcceptPartyInvites()
    SetupAutoQuest()
    
    -- New features
    SetupAutoStand()
    SetupAutoGossipSkip()
    SetupAutoReleaseInBG()
    SetupAutoConfirmBop()
    SetupFasterLoot()
    SetupSkipCinematics()
end

function Automation.OnDisable()
    addon:Debug("Automation module disabling")
    -- Unregister all event frames to clean up
    for _, frame in ipairs(eventFrames) do
        if frame and frame.UnregisterAllEvents then
            frame:UnregisterAllEvents()
            frame:SetScript("OnEvent", nil)
        end
    end
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
    desc:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    desc:SetJustifyH("LEFT")
    
    local yOffset = -70
    
    -- ============================================================
    -- Merchant Section
    -- ============================================================
    local merchantHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    merchantHeader:SetPoint("TOPLEFT", 16, yOffset)
    merchantHeader:SetText("Merchant Automation")
    yOffset = yOffset - 25

    -- Auto Accept Quests
    local questAcceptCb = addon:CreateCheckbox(parent)
    questAcceptCb:SetPoint("TOPLEFT", 16, yOffset)
    questAcceptCb.Text:SetText("Auto Accept Quests")
    questAcceptCb:SetChecked(settings.autoAcceptQuests)
    questAcceptCb:SetScript("OnClick", function(self)
        addon:SetSetting("automation.autoAcceptQuests", self:GetChecked())
    end)
    yOffset = yOffset - 25

    -- Auto Turn-In Quests
    local questTurnInCb = addon:CreateCheckbox(parent)
    questTurnInCb:SetPoint("TOPLEFT", 16, yOffset)
    questTurnInCb.Text:SetText("Auto Turn-In Quests")
    questTurnInCb:SetChecked(settings.autoTurnInQuests)
    questTurnInCb:SetScript("OnClick", function(self)
        addon:SetSetting("automation.autoTurnInQuests", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    -- Auto Repair
    local repairCb = addon:CreateCheckbox(parent)
    repairCb:SetPoint("TOPLEFT", 16, yOffset)
    repairCb.Text:SetText("Auto Repair")
    repairCb:SetChecked(settings.autoRepair)
    repairCb:SetScript("OnClick", function(self)
        addon:SetSetting("automation.autoRepair", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    -- Use Guild Funds
    local guildRepairCb = addon:CreateCheckbox(parent)
    guildRepairCb:SetPoint("TOPLEFT", 36, yOffset)
    guildRepairCb.Text:SetText("Use Guild Funds when available")
    guildRepairCb:SetChecked(settings.autoRepairGuild)
    guildRepairCb:SetScript("OnClick", function(self)
        addon:SetSetting("automation.autoRepairGuild", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    -- Auto Sell Junk
    local sellJunkCb = addon:CreateCheckbox(parent)
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
    local summonCb = addon:CreateCheckbox(parent)
    summonCb:SetPoint("TOPLEFT", 16, yOffset)
    summonCb.Text:SetText("Auto Accept Summons")
    summonCb:SetChecked(settings.autoAcceptSummon)
    summonCb:SetScript("OnClick", function(self)
        addon:SetSetting("automation.autoAcceptSummon", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    -- Auto Accept Resurrect
    local resCb = addon:CreateCheckbox(parent)
    resCb:SetPoint("TOPLEFT", 16, yOffset)
    resCb.Text:SetText("Auto Accept Resurrections (out of combat)")
    resCb:SetChecked(settings.autoAcceptResurrect)
    resCb:SetScript("OnClick", function(self)
        addon:SetSetting("automation.autoAcceptResurrect", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    -- Auto Accept Party (Friends/Guild)
    local partyCb = addon:CreateCheckbox(parent)
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
    local duelCb = addon:CreateCheckbox(parent)
    duelCb:SetPoint("TOPLEFT", 16, yOffset)
    duelCb.Text:SetText("Auto Decline Duels")
    duelCb:SetChecked(settings.autoDeclineDuels)
    duelCb:SetScript("OnClick", function(self)
        addon:SetSetting("automation.autoDeclineDuels", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    -- Auto Decline Guild Invites
    local guildInvCb = addon:CreateCheckbox(parent)
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
    local dismountCb = addon:CreateCheckbox(parent)
    dismountCb:SetPoint("TOPLEFT", 16, yOffset)
    dismountCb.Text:SetText("Auto Dismount on action")
    dismountCb:SetChecked(settings.autoDismount)
    dismountCb:SetScript("OnClick", function(self)
        addon:SetSetting("automation.autoDismount", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    -- Auto Gossip Skip
    local gossipCb = addon:CreateCheckbox(parent)
    gossipCb:SetPoint("TOPLEFT", 16, yOffset)
    gossipCb.Text:SetText("Auto-skip gossip (trainers, flight masters)")
    gossipCb:SetChecked(settings.autoGossipSkip)
    gossipCb:SetScript("OnClick", function(self)
        addon:SetSetting("automation.autoGossipSkip", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    -- Faster Loot
    local fasterLootCb = addon:CreateCheckbox(parent)
    fasterLootCb:SetPoint("TOPLEFT", 16, yOffset)
    fasterLootCb.Text:SetText("Faster auto-loot")
    fasterLootCb:SetChecked(settings.fasterLoot)
    fasterLootCb:SetScript("OnClick", function(self)
        addon:SetSetting("automation.fasterLoot", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    -- Auto Confirm BoP
    local bopCb = addon:CreateCheckbox(parent)
    bopCb:SetPoint("TOPLEFT", 16, yOffset)
    bopCb.Text:SetText("Auto-confirm Bind on Pickup dialogs")
    bopCb:SetChecked(settings.autoConfirmBop)
    bopCb:SetScript("OnClick", function(self)
        addon:SetSetting("automation.autoConfirmBop", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    -- Auto Release in BG
    local releaseBgCb = addon:CreateCheckbox(parent)
    releaseBgCb:SetPoint("TOPLEFT", 16, yOffset)
    releaseBgCb.Text:SetText("Auto-release in Battlegrounds")
    releaseBgCb:SetChecked(settings.autoReleaseInBG)
    releaseBgCb:SetScript("OnClick", function(self)
        addon:SetSetting("automation.autoReleaseInBG", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    -- Skip Cinematics
    local cinematicsCb = addon:CreateCheckbox(parent)
    cinematicsCb:SetPoint("TOPLEFT", 16, yOffset)
    cinematicsCb.Text:SetText("Skip cinematics and movies")
    cinematicsCb:SetChecked(settings.skipCinematics)
    cinematicsCb:SetScript("OnClick", function(self)
        addon:SetSetting("automation.skipCinematics", self:GetChecked())
    end)
    
    return yOffset - 50
end

-- ============================================================
-- Register Module
-- ============================================================
addon:RegisterModule("Automation", Automation)
