-- ============================================================
-- DC-QoS: SocialEnhancements Module
-- ============================================================
-- Enhanced friend list, /who, guild roster, and social features
-- Inspired by Friend & Ignore Share, AddFriend, and Chatter
-- ============================================================

local addon = DCQOS

-- ============================================================
-- Module Configuration
-- ============================================================
local SocialEnhancements = {
    displayName = "Social Enhancements",
    settingKey = "socialEnhancements",
    icon = "Interface\\Icons\\INV_Misc_GroupLooking",
    defaults = {
        socialEnhancements = {
            enabled = true,
            -- Friend List
            showClass = true,
            showLevel = true,
            showLocation = true,
            colorByClass = true,
            -- /who
            enhanceWho = true,
            whoColorByClass = true,
            -- Guild
            showGuildNote = true,
            colorGuildByClass = true,
            -- Auto-invite
            autoInviteEnabled = false,
            autoInviteKeyword = "inv",
            -- Chat
            showLevelInChat = false,
            showGuildRankInChat = false,
        },
    },
}

-- Merge defaults
for k, v in pairs(SocialEnhancements.defaults) do
    addon.defaults[k] = v
end

-- ============================================================
-- Class Colors Reference
-- ============================================================
local CLASS_COLORS = RAID_CLASS_COLORS or {
    ["WARRIOR"]     = { r = 0.78, g = 0.61, b = 0.43 },
    ["PALADIN"]     = { r = 0.96, g = 0.55, b = 0.73 },
    ["HUNTER"]      = { r = 0.67, g = 0.83, b = 0.45 },
    ["ROGUE"]       = { r = 1.00, g = 0.96, b = 0.41 },
    ["PRIEST"]      = { r = 1.00, g = 1.00, b = 1.00 },
    ["DEATHKNIGHT"] = { r = 0.77, g = 0.12, b = 0.23 },
    ["SHAMAN"]      = { r = 0.00, g = 0.44, b = 0.87 },
    ["MAGE"]        = { r = 0.41, g = 0.80, b = 0.94 },
    ["WARLOCK"]     = { r = 0.58, g = 0.51, b = 0.79 },
    ["DRUID"]       = { r = 1.00, g = 0.49, b = 0.04 },
}

-- Localized class names to tokens (for reverse lookup)
local CLASS_TOKEN_LOOKUP = {}
for class, _ in pairs(CLASS_COLORS) do
    local localizedName = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]
    if localizedName then
        CLASS_TOKEN_LOOKUP[localizedName] = class
    end
    local localizedNameF = LOCALIZED_CLASS_NAMES_FEMALE and LOCALIZED_CLASS_NAMES_FEMALE[class]
    if localizedNameF then
        CLASS_TOKEN_LOOKUP[localizedNameF] = class
    end
end

-- Fallback for English
local ENGLISH_CLASS_LOOKUP = {
    ["Warrior"] = "WARRIOR",
    ["Paladin"] = "PALADIN",
    ["Hunter"] = "HUNTER",
    ["Rogue"] = "ROGUE",
    ["Priest"] = "PRIEST",
    ["Death Knight"] = "DEATHKNIGHT",
    ["Shaman"] = "SHAMAN",
    ["Mage"] = "MAGE",
    ["Warlock"] = "WARLOCK",
    ["Druid"] = "DRUID",
}

local function GetClassToken(className)
    return CLASS_TOKEN_LOOKUP[className] or ENGLISH_CLASS_LOOKUP[className]
end

local function GetClassColor(classToken)
    local color = CLASS_COLORS[classToken]
    if color then
        return string.format("|cff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
    end
    return "|cffffffff"
end

-- ============================================================
-- Enhanced Friend List
-- ============================================================
local function EnhanceFriendList()
    -- Hook FriendsFrame friend button update
    if not FriendsList_Update then return end
    
    hooksecurefunc("FriendsList_Update", function()
        local settings = addon.settings.socialEnhancements
        if not settings.enabled then return end
        
        for i = 1, FRIENDS_TO_DISPLAY do
            local button = _G["FriendsFrameFriendsScrollFrameButton" .. i]
            if button then
                local nameText = button.name or _G[button:GetName() .. "Name"]
                local infoText = button.info or _G[button:GetName() .. "Info"]
                
                if nameText and infoText then
                    local friendIndex = button.index
                    if friendIndex then
                        local name, level, class, area, connected = GetFriendInfo(friendIndex)
                        
                        if name and connected then
                            local classToken = GetClassToken(class)
                            
                            -- Color by class
                            if settings.colorByClass and classToken then
                                local colorCode = GetClassColor(classToken)
                                nameText:SetText(colorCode .. name .. "|r")
                            end
                            
                            -- Enhanced info display
                            local infoStr = ""
                            if settings.showLevel and level then
                                infoStr = "Lv" .. level
                            end
                            if settings.showClass and class then
                                infoStr = infoStr .. (infoStr ~= "" and " " or "") .. class
                            end
                            if settings.showLocation and area and area ~= "" then
                                infoStr = infoStr .. (infoStr ~= "" and " - " or "") .. area
                            end
                            
                            if infoStr ~= "" then
                                infoText:SetText(infoStr)
                            end
                        end
                    end
                end
            end
        end
    end)
end

-- ============================================================
-- Enhanced /who Results
-- ============================================================
local function EnhanceWhoList()
    if not WhoList_Update then return end
    
    hooksecurefunc("WhoList_Update", function()
        local settings = addon.settings.socialEnhancements
        if not settings.enabled or not settings.enhanceWho then return end
        
        for i = 1, WHOS_TO_DISPLAY do
            local button = _G["WhoFrameButton" .. i]
            if button and button.whoIndex then
                local nameText = _G["WhoFrameButton" .. i .. "Name"]
                local classText = _G["WhoFrameButton" .. i .. "Class"]
                
                local info = C_FriendList and C_FriendList.GetWhoInfo and C_FriendList.GetWhoInfo(button.whoIndex)
                if not info then
                    -- Fallback for 3.3.5a
                    local name, guild, level, race, class, zone, classToken = GetWhoInfo(button.whoIndex)
                    info = { fullName = name, fullGuildName = guild, level = level, 
                             raceStr = race, classStr = class, area = zone, filename = classToken }
                end
                
                if info and nameText and settings.whoColorByClass then
                    local classToken = info.filename or GetClassToken(info.classStr)
                    if classToken then
                        local colorCode = GetClassColor(classToken)
                        local currentText = nameText:GetText()
                        if currentText and not currentText:find("^|cff") then
                            nameText:SetText(colorCode .. currentText .. "|r")
                        end
                    end
                end
            end
        end
    end)
end

-- ============================================================
-- Enhanced Guild Roster
-- ============================================================
local function EnhanceGuildRoster()
    if not GuildRoster_Update then return end
    
    hooksecurefunc("GuildRoster_Update", function()
        local settings = addon.settings.socialEnhancements
        if not settings.enabled then return end
        
        for i = 1, GUILDMEMBERS_TO_DISPLAY do
            local button = _G["GuildFrameButton" .. i]
            if button then
                local nameText = _G["GuildFrameButton" .. i .. "Name"]
                
                if nameText and button.guildIndex then
                    local name, rank, rankIndex, level, class, zone, note, 
                          officernote, online, status, classToken = GetGuildRosterInfo(button.guildIndex)
                    
                    if name and online and settings.colorGuildByClass then
                        local token = classToken or GetClassToken(class)
                        if token then
                            local colorCode = GetClassColor(token)
                            local displayName = name:match("([^%-]+)")  -- Remove server name
                            nameText:SetText(colorCode .. displayName .. "|r")
                        end
                    end
                    
                    -- Show note in tooltip if configured
                    if settings.showGuildNote and note and note ~= "" then
                        button.dcNote = note
                    end
                end
            end
        end
    end)
    
    -- Hook guild button tooltips to show note
    for i = 1, GUILDMEMBERS_TO_DISPLAY do
        local button = _G["GuildFrameButton" .. i]
        if button then
            button:HookScript("OnEnter", function(self)
                local settings = addon.settings.socialEnhancements
                if not settings.enabled or not settings.showGuildNote then return end
                
                if self.dcNote and self.dcNote ~= "" then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("Note: " .. self.dcNote, 1, 1, 0.5, true)
                    GameTooltip:Show()
                end
            end)
        end
    end
end

-- ============================================================
-- Auto-Invite by Keyword
-- ============================================================
local function SetupAutoInvite()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("CHAT_MSG_WHISPER")
    
    frame:SetScript("OnEvent", function(self, event, message, sender)
        local settings = addon.settings.socialEnhancements
        if not settings.enabled or not settings.autoInviteEnabled then return end
        
        local keyword = settings.autoInviteKeyword
        if not keyword or keyword == "" then return end
        
        -- Check if message matches keyword (case insensitive)
        if message:lower():match("^" .. keyword:lower() .. "$") or
           message:lower():match("^" .. keyword:lower() .. "%s") or
           message:lower():match("%s" .. keyword:lower() .. "$") then
            -- Invite the player
            InviteUnit(sender)
            addon:Debug("Auto-invited " .. sender .. " (keyword: " .. keyword .. ")")
        end
    end)
end

-- ============================================================
-- Quick Add Friend from Chat
-- ============================================================
local function SetupQuickAddFriend()
    -- Add right-click menu option to chat names
    if not UnitPopupMenus then return end
    
    -- Check if our option already exists
    local hasQuickAdd = false
    for _, item in ipairs(UnitPopupMenus["FRIEND"] or {}) do
        if item == "DC_QUICK_ADD" then
            hasQuickAdd = true
            break
        end
    end
    
    if not hasQuickAdd then
        -- We can't easily add to UnitPopupMenus in 3.3.5a without taint issues
        -- Instead, provide a slash command
        SLASH_DCADDFRIEND1 = "/dcfriend"
        SlashCmdList["DCADDFRIEND"] = function(name)
            if not name or name == "" then
                -- Try to get from target
                if UnitExists("target") and UnitIsPlayer("target") and not UnitIsUnit("player", "target") then
                    name = UnitName("target")
                else
                    addon:Print("Usage: /dcfriend <playername>", true)
                    return
                end
            end
            
            AddFriend(name)
            addon:Print("Added " .. name .. " to friends list.", true)
        end
    end
end

-- ============================================================
-- Ignore List Enhancement
-- ============================================================
local function EnhanceIgnoreList()
    -- Add count to ignore list header
    if not IgnoreList_Update then return end
    
    hooksecurefunc("IgnoreList_Update", function()
        local settings = addon.settings.socialEnhancements
        if not settings.enabled then return end
        
        local numIgnored = GetNumIgnores()
        if FriendsFrameIgnoreHeaderText then
            FriendsFrameIgnoreHeaderText:SetText("Ignore List (" .. numIgnored .. "/50)")
        end
    end)
end

-- ============================================================
-- Module Callbacks
-- ============================================================
function SocialEnhancements.OnInitialize()
    addon:Debug("SocialEnhancements module initializing")
end

function SocialEnhancements.OnEnable()
    addon:Debug("SocialEnhancements module enabling")
    
    local settings = addon.settings.socialEnhancements
    if not settings.enabled then return end
    
    -- Setup all enhancements
    EnhanceFriendList()
    EnhanceWhoList()
    EnhanceGuildRoster()
    SetupAutoInvite()
    SetupQuickAddFriend()
    EnhanceIgnoreList()
end

function SocialEnhancements.OnDisable()
    addon:Debug("SocialEnhancements module disabling")
    -- Note: Hooks remain but check enabled state
end

-- ============================================================
-- Settings Panel Creation
-- ============================================================
function SocialEnhancements.CreateSettings(parent)
    local settings = addon.settings.socialEnhancements
    
    -- Title
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Social Enhancements Settings")
    
    -- Description
    local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetWidth(450)
    desc:SetJustifyH("LEFT")
    desc:SetText("Enhanced friend list, /who results, and guild roster display.")
    
    local yOffset = -70
    
    -- ============================================================
    -- Friend List Section
    -- ============================================================
    local friendHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    friendHeader:SetPoint("TOPLEFT", 16, yOffset)
    friendHeader:SetText("Friend List")
    yOffset = yOffset - 25
    
    -- Color by Class
    local classColorCb = addon:CreateCheckbox(parent)
    classColorCb:SetPoint("TOPLEFT", 16, yOffset)
    classColorCb.Text:SetText("Color friend names by class")
    classColorCb:SetChecked(settings.colorByClass)
    classColorCb:SetScript("OnClick", function(self)
        addon:SetSetting("socialEnhancements.colorByClass", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    -- Show Level
    local levelCb = addon:CreateCheckbox(parent)
    levelCb:SetPoint("TOPLEFT", 16, yOffset)
    levelCb.Text:SetText("Show level in friend info")
    levelCb:SetChecked(settings.showLevel)
    levelCb:SetScript("OnClick", function(self)
        addon:SetSetting("socialEnhancements.showLevel", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    -- Show Class
    local showClassCb = addon:CreateCheckbox(parent)
    showClassCb:SetPoint("TOPLEFT", 16, yOffset)
    showClassCb.Text:SetText("Show class in friend info")
    showClassCb:SetChecked(settings.showClass)
    showClassCb:SetScript("OnClick", function(self)
        addon:SetSetting("socialEnhancements.showClass", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    -- Show Location
    local locationCb = addon:CreateCheckbox(parent)
    locationCb:SetPoint("TOPLEFT", 16, yOffset)
    locationCb.Text:SetText("Show location in friend info")
    locationCb:SetChecked(settings.showLocation)
    locationCb:SetScript("OnClick", function(self)
        addon:SetSetting("socialEnhancements.showLocation", self:GetChecked())
    end)
    yOffset = yOffset - 35
    
    -- ============================================================
    -- /who Section
    -- ============================================================
    local whoHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    whoHeader:SetPoint("TOPLEFT", 16, yOffset)
    whoHeader:SetText("/who Results")
    yOffset = yOffset - 25
    
    -- Enhance /who
    local whoCb = addon:CreateCheckbox(parent)
    whoCb:SetPoint("TOPLEFT", 16, yOffset)
    whoCb.Text:SetText("Enhance /who results display")
    whoCb:SetChecked(settings.enhanceWho)
    whoCb:SetScript("OnClick", function(self)
        addon:SetSetting("socialEnhancements.enhanceWho", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    -- /who Color by Class
    local whoColorCb = addon:CreateCheckbox(parent)
    whoColorCb:SetPoint("TOPLEFT", 36, yOffset)
    whoColorCb.Text:SetText("Color names by class")
    whoColorCb:SetChecked(settings.whoColorByClass)
    whoColorCb:SetScript("OnClick", function(self)
        addon:SetSetting("socialEnhancements.whoColorByClass", self:GetChecked())
    end)
    yOffset = yOffset - 35
    
    -- ============================================================
    -- Guild Section
    -- ============================================================
    local guildHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    guildHeader:SetPoint("TOPLEFT", 16, yOffset)
    guildHeader:SetText("Guild Roster")
    yOffset = yOffset - 25
    
    -- Guild Color by Class
    local guildColorCb = addon:CreateCheckbox(parent)
    guildColorCb:SetPoint("TOPLEFT", 16, yOffset)
    guildColorCb.Text:SetText("Color guild member names by class")
    guildColorCb:SetChecked(settings.colorGuildByClass)
    guildColorCb:SetScript("OnClick", function(self)
        addon:SetSetting("socialEnhancements.colorGuildByClass", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    -- Show Guild Note
    local guildNoteCb = addon:CreateCheckbox(parent)
    guildNoteCb:SetPoint("TOPLEFT", 16, yOffset)
    guildNoteCb.Text:SetText("Show notes in guild member tooltips")
    guildNoteCb:SetChecked(settings.showGuildNote)
    guildNoteCb:SetScript("OnClick", function(self)
        addon:SetSetting("socialEnhancements.showGuildNote", self:GetChecked())
    end)
    yOffset = yOffset - 35
    
    -- ============================================================
    -- Auto-Invite Section
    -- ============================================================
    local inviteHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    inviteHeader:SetPoint("TOPLEFT", 16, yOffset)
    inviteHeader:SetText("Auto-Invite")
    yOffset = yOffset - 25
    
    -- Auto-Invite Enable
    local autoInvCb = addon:CreateCheckbox(parent)
    autoInvCb:SetPoint("TOPLEFT", 16, yOffset)
    autoInvCb.Text:SetText("Auto-invite on whisper keyword")
    autoInvCb:SetChecked(settings.autoInviteEnabled)
    autoInvCb:SetScript("OnClick", function(self)
        addon:SetSetting("socialEnhancements.autoInviteEnabled", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    -- Keyword Input
    local keywordLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    keywordLabel:SetPoint("TOPLEFT", 36, yOffset + 2)
    keywordLabel:SetText("Keyword:")
    
    local keywordEdit = CreateFrame("EditBox", "DCQoS_AutoInvKeyword", parent, "InputBoxTemplate")
    keywordEdit:SetSize(80, 20)
    keywordEdit:SetPoint("LEFT", keywordLabel, "RIGHT", 10, 0)
    keywordEdit:SetAutoFocus(false)
    keywordEdit:SetText(settings.autoInviteKeyword or "inv")
    keywordEdit:SetScript("OnEnterPressed", function(self)
        addon:SetSetting("socialEnhancements.autoInviteKeyword", self:GetText())
        self:ClearFocus()
    end)
    keywordEdit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    yOffset = yOffset - 35
    
    -- Info
    local infoText = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    infoText:SetPoint("TOPLEFT", 16, yOffset)
    infoText:SetWidth(450)
    infoText:SetJustifyH("LEFT")
    infoText:SetTextColor(0.7, 0.7, 0.7)
    infoText:SetText("Tip: Use |cffffd700/dcfriend <name>|r to quickly add someone to your friends list.")
    
    return yOffset - 40
end

-- ============================================================
-- Register Module
-- ============================================================
addon:RegisterModule("SocialEnhancements", SocialEnhancements)
