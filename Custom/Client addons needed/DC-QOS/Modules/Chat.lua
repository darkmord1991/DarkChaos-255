-- ============================================================
-- DC-QoS: Chat Module
-- ============================================================
-- Chat enhancements and quality-of-life improvements
-- Adapted from Leatrix Plus for WoW 3.3.5a compatibility
-- ============================================================

local addon = DCQOS

-- ============================================================
-- Module Configuration
-- ============================================================
local Chat = {
    displayName = "Chat",
    settingKey = "chat",
    icon = "Interface\\Icons\\INV_Letter_02",
}

-- ============================================================
-- Hide Channel Names
-- ============================================================
local channelReplacements = {
    ["Общий"] = "О",
    ["Торговля"] = "Т",
    ["LocalDefense"] = "LD",
    ["LookingForGroup"] = "LFG",
    ["General"] = "G",
    ["Trade"] = "T",
    ["WorldDefense"] = "WD",
    ["GuildRecruitment"] = "GR",
}

local function SetupHideChannelNames()
    local settings = addon.settings.chat
    if not settings.enabled or not settings.hideChannelNames then return end
    
    -- Hook AddMessage to shorten channel names
    for i = 1, NUM_CHAT_WINDOWS do
        local chatFrame = _G["ChatFrame" .. i]
        if chatFrame then
            local origAddMessage = chatFrame.AddMessage
            chatFrame.AddMessage = function(self, msg, ...)
                if msg then
                    -- Replace channel names with short versions
                    for long, short in pairs(channelReplacements) do
                        msg = msg:gsub("%[" .. long .. "%]", "[" .. short .. "]")
                        msg = msg:gsub("%[(%d+)%. " .. long .. "%]", "[%1]")
                    end
                end
                return origAddMessage(self, msg, ...)
            end
        end
    end
end

-- ============================================================
-- Sticky Chat Channels
-- ============================================================
local function SetupStickyChannels()
    local settings = addon.settings.chat
    if not settings.enabled or not settings.stickyChannels then return end
    
    -- Make all channel types sticky
    ChatTypeInfo["WHISPER"].sticky = 1
    ChatTypeInfo["CHANNEL"].sticky = 1
    ChatTypeInfo["SAY"].sticky = 1
    ChatTypeInfo["YELL"].sticky = 1
    ChatTypeInfo["PARTY"].sticky = 1
    ChatTypeInfo["RAID"].sticky = 1
    ChatTypeInfo["BATTLEGROUND"].sticky = 1
    ChatTypeInfo["GUILD"].sticky = 1
    ChatTypeInfo["OFFICER"].sticky = 1
end

-- ============================================================
-- Hide Social Buttons
-- ============================================================
local function SetupHideSocialButtons()
    local settings = addon.settings.chat
    if not settings.enabled or not settings.hideSocialButtons then return end
    
    -- Hide the social/friend button near chat
    if FriendsMicroButton then
        FriendsMicroButton:Hide()
        FriendsMicroButton:SetScript("OnShow", function(self) self:Hide() end)
    end
    
    -- Hide chat buttons on the side
    if ChatFrameMenuButton then
        ChatFrameMenuButton:Hide()
        ChatFrameMenuButton:SetScript("OnShow", function(self) self:Hide() end)
    end
end

-- ============================================================
-- Shorten Class Names in Chat
-- ============================================================
local shortClassNames = {
    ["Warrior"] = "War",
    ["Paladin"] = "Pal",
    ["Hunter"] = "Hun",
    ["Rogue"] = "Rog",
    ["Priest"] = "Pri",
    ["Death Knight"] = "DK",
    ["Shaman"] = "Sha",
    ["Mage"] = "Mag",
    ["Warlock"] = "Wlk",
    ["Druid"] = "Dru",
}

-- ============================================================
-- Copy Chat Link
-- ============================================================
local function SetupCopyChatLink()
    -- Create a hidden editbox for copying text
    local copyBox = CreateFrame("EditBox", "DCQoSCopyBox", UIParent, "InputBoxTemplate")
    copyBox:SetSize(300, 30)
    copyBox:SetPoint("CENTER")
    copyBox:SetAutoFocus(false)
    copyBox:Hide()
    copyBox:SetScript("OnEscapePressed", function(self)
        self:Hide()
    end)
    copyBox:SetScript("OnEnterPressed", function(self)
        self:Hide()
    end)
    
    -- Function to show copy box with text
    addon.ShowCopyBox = function(self, text)
        copyBox:SetText(text)
        copyBox:Show()
        copyBox:SetFocus()
        copyBox:HighlightText()
    end
end

-- ============================================================
-- Module Callbacks
-- ============================================================
function Chat.OnInitialize()
    addon:Debug("Chat module initializing")
end

function Chat.OnEnable()
    addon:Debug("Chat module enabling")
    
    SetupHideChannelNames()
    SetupStickyChannels()
    SetupHideSocialButtons()
    SetupCopyChatLink()
end

function Chat.OnDisable()
    addon:Debug("Chat module disabling")
end

-- ============================================================
-- Settings Panel Creation
-- ============================================================
function Chat.CreateSettings(parent)
    local settings = addon.settings.chat
    
    -- Title
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Chat Settings")
    
    -- Description
    local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText("Configure chat enhancements and appearance options.")
    desc:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    desc:SetJustifyH("LEFT")
    
    local yOffset = -70
    
    -- ============================================================
    -- Appearance Section
    -- ============================================================
    local appearanceHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    appearanceHeader:SetPoint("TOPLEFT", 16, yOffset)
    appearanceHeader:SetText("Appearance")
    yOffset = yOffset - 25
    
    -- Hide Channel Names
    local hideChannelsCb = addon:CreateCheckbox(parent)
    hideChannelsCb:SetPoint("TOPLEFT", 16, yOffset)
    hideChannelsCb.Text:SetText("Shorten Channel Names")
    hideChannelsCb:SetChecked(settings.hideChannelNames)
    hideChannelsCb:SetScript("OnClick", function(self)
        addon:SetSetting("chat.hideChannelNames", self:GetChecked())
        addon:Print("Requires /reload to take effect", true)
    end)
    yOffset = yOffset - 25
    
    -- Hide Social Buttons
    local hideSocialCb = addon:CreateCheckbox(parent)
    hideSocialCb:SetPoint("TOPLEFT", 16, yOffset)
    hideSocialCb.Text:SetText("Hide Social Buttons")
    hideSocialCb:SetChecked(settings.hideSocialButtons)
    hideSocialCb:SetScript("OnClick", function(self)
        addon:SetSetting("chat.hideSocialButtons", self:GetChecked())
        addon:Print("Requires /reload to take effect", true)
    end)
    yOffset = yOffset - 35
    
    -- ============================================================
    -- Behavior Section
    -- ============================================================
    local behaviorHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    behaviorHeader:SetPoint("TOPLEFT", 16, yOffset)
    behaviorHeader:SetText("Behavior")
    yOffset = yOffset - 25
    
    -- Sticky Channels
    local stickyCb = addon:CreateCheckbox(parent)
    stickyCb:SetPoint("TOPLEFT", 16, yOffset)
    stickyCb.Text:SetText("Sticky Chat Channels")
    stickyCb:SetChecked(settings.stickyChannels)
    stickyCb:SetScript("OnClick", function(self)
        addon:SetSetting("chat.stickyChannels", self:GetChecked())
        addon:Print("Requires /reload to take effect", true)
    end)
    
    -- Info text
    local stickyInfo = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    stickyInfo:SetPoint("TOPLEFT", stickyCb, "BOTTOMLEFT", 20, -2)
    stickyInfo:SetText("Remember the last used channel when typing")
    stickyInfo:SetTextColor(0.5, 0.5, 0.5)
    yOffset = yOffset - 45
    
    return yOffset - 50
end

-- ============================================================
-- Register Module
-- ============================================================
addon:RegisterModule("Chat", Chat)
