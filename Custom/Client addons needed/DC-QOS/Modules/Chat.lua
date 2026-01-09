-- ============================================================
-- DC-QoS: Chat Module
-- ============================================================
-- Chat enhancements and quality-of-life improvements
-- Inspired by Chatter, WIM, and Leatrix Plus for 3.3.5a
-- ============================================================

local addon = DCQOS

-- ============================================================
-- Module Configuration
-- ============================================================
local Chat = {
    displayName = "Chat",
    settingKey = "chat",
    icon = "Interface\\Icons\\INV_Letter_02",
    defaults = {
        chat = {
            enabled = true,
            -- Appearance
            hideChannelNames = true,
            hideSocialButtons = false,
            -- Timestamps
            showTimestamps = true,
            timestampFormat = "[%H:%M] ",
            -- Class Colors
            classColoredNames = true,
            -- URL Detection
            detectURLs = true,
            -- Sticky Channels
            stickyChannels = true,
            -- Copy Chat
            enableChatCopy = true,
            -- History
            maxLines = 1000,

            -- Spam Control
            suppressHotspotSpam = true,
            hotspotDebounceSeconds = 3,
            hotspotCooldownSeconds = 15,
        },
    },
}

-- Merge defaults
for k, v in pairs(Chat.defaults) do
    if addon.defaults[k] == nil then
        addon.defaults[k] = v
    else
        for k2, v2 in pairs(v) do
            if addon.defaults[k][k2] == nil then
                addon.defaults[k][k2] = v2
            end
        end
    end
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

-- Cache for player class lookups
local playerClassCache = {}

local function GetClassColorCode(classToken)
    local color = CLASS_COLORS[classToken]
    if color then
        return string.format("|cff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
    end
    return "|cffffffff"
end

-- ============================================================
-- Channel Name Shortening
-- ============================================================
local channelReplacements = {
    -- English
    ["General"] = "G",
    ["Trade"] = "T",
    ["LocalDefense"] = "LD",
    ["LookingForGroup"] = "LFG",
    ["WorldDefense"] = "WD",
    ["GuildRecruitment"] = "GR",
    -- Russian
    ["Общий"] = "О",
    ["Торговля"] = "Т",
}

-- ============================================================
-- URL Detection Patterns
-- ============================================================
local URL_PATTERNS = {
    -- http/https URLs
    "(https?://[%w%.%-_/&?=%%+#@:]+)",
    -- www URLs
    "(www%.[%w%.%-_/&?=%%+#@:]+)",
    -- IP addresses with port
    "(%d+%.%d+%.%d+%.%d+:%d+)",
    -- IP addresses
    "(%d+%.%d+%.%d+%.%d+)",
    -- Common domains
    "([%w%-_]+%.com[/%w%.%-_?=&]*)",
    "([%w%-_]+%.org[/%w%.%-_?=&]*)",
    "([%w%-_]+%.net[/%w%.%-_?=&]*)",
    "([%w%-_]+%.io[/%w%.%-_?=&]*)",
    "([%w%-_]+%.gg[/%w%.%-_?=&]*)",
}

-- ============================================================
-- Timestamp Formatting
-- ============================================================
local function GetTimestamp(format)
    return date(format or "[%H:%M] ")
end

-- ============================================================
-- URL Highlighting
-- ============================================================
local function HighlightURLs(msg)
    if not msg then return msg end
    
    for _, pattern in ipairs(URL_PATTERNS) do
        msg = msg:gsub(pattern, "|cff00ffff|Hurl:%1|h[%1]|h|r")
    end
    
    return msg
end

-- URL Click Handler
local function SetupURLHandler()
    -- Hook SetItemRef to handle our custom url links
    local origSetItemRef = SetItemRef
    SetItemRef = function(link, text, button, chatFrame)
        if link:sub(1, 4) == "url:" then
            local url = link:sub(5)
            -- Show copy dialog
            addon:ShowCopyBox(url)
            return
        end
        return origSetItemRef(link, text, button, chatFrame)
    end
end

-- ============================================================
-- Class-Colored Player Names
-- ============================================================
local function ColorPlayerName(msg, playerName, ...)
    if not msg or not playerName then return msg end
    
    local settings = addon.settings.chat
    if not settings.classColoredNames then return msg end
    
    -- Try to get cached class
    local classToken = playerClassCache[playerName]
    
    if not classToken then
        -- Try to get from guild/friends/raid/party
        if UnitExists(playerName) then
            local _, class = UnitClass(playerName)
            classToken = class
        end
        
        -- Cache it (even nil to avoid repeated lookups)
        playerClassCache[playerName] = classToken or false
    end
    
    if classToken and classToken ~= false then
        local colorCode = GetClassColorCode(classToken)
        -- Replace player name with colored version
        msg = msg:gsub("|Hplayer:" .. playerName .. "(.-)|h%[(.-)%]|h", 
            "|Hplayer:" .. playerName .. "%1|h[" .. colorCode .. "%2|r]|h")
    end
    
    return msg
end

-- Update class cache from events
local function SetupClassCaching()
    local frame = CreateFrame("Frame")
    
    -- Cache guild members
    frame:RegisterEvent("GUILD_ROSTER_UPDATE")
    -- Cache party/raid members
    frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
    frame:RegisterEvent("RAID_ROSTER_UPDATE")
    -- Cache friends
    frame:RegisterEvent("FRIENDLIST_UPDATE")
    -- Cache from who results
    frame:RegisterEvent("WHO_LIST_UPDATE")
    
    frame:SetScript("OnEvent", function(self, event)
        if event == "GUILD_ROSTER_UPDATE" then
            for i = 1, GetNumGuildMembers() do
                local name, _, _, _, _, _, _, _, _, _, classToken = GetGuildRosterInfo(i)
                if name and classToken then
                    playerClassCache[name:match("([^%-]+)")] = classToken
                end
            end
        elseif event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
            local maxMembers = GetNumRaidMembers() > 0 and GetNumRaidMembers() or GetNumPartyMembers()
            local prefix = GetNumRaidMembers() > 0 and "raid" or "party"
            for i = 1, maxMembers do
                local unit = prefix .. i
                if UnitExists(unit) then
                    local name = UnitName(unit)
                    local _, classToken = UnitClass(unit)
                    if name and classToken then
                        playerClassCache[name] = classToken
                    end
                end
            end
        elseif event == "FRIENDLIST_UPDATE" then
            for i = 1, GetNumFriends() do
                local name, _, class = GetFriendInfo(i)
                if name and class then
                    -- Convert localized class name to token
                    for token, info in pairs(CLASS_COLORS) do
                        local localizedName = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[token]
                        if localizedName == class then
                            playerClassCache[name] = token
                            break
                        end
                    end
                end
            end
        elseif event == "WHO_LIST_UPDATE" then
            for i = 1, GetNumWhoResults() do
                local name, _, _, _, _, _, classToken = GetWhoInfo(i)
                if name and classToken then
                    playerClassCache[name] = classToken
                end
            end
        end
    end)
end

-- ============================================================
-- Chat Frame Message Hook
-- ============================================================
local function SetupChatFrameHooks()
    local settings = addon.settings.chat

    local function IsDcDebugLine(msg)
        if type(msg) ~= "string" then return false end

        -- DC addon informational spam (non-[Debug] lines)
        if msg:find("%[DC AoE Loot%]", 1, false) then
            return true
        end
        if msg:find("^Mythic%+ HUD:") then
            return true
        end

        -- DC-Hotspot diagnostics (often multi-line, not always tagged as Debug)
        if msg:find("%[DC%-Hotspot%]") then
            return true
        end

        -- Common pattern: [DC-Anything Debug]
        if msg:find("%[DC[^%]]* Debug%]") then
            return true
        end

        -- DCAddonProtocol debug: [DC Debug]
        if msg:find("%[DC Debug%]") then
            return true
        end

        -- DC-Welcome / DC-Collection style: [DC-Addon] ... [Debug] ...
        if (msg:find("%[DC[^%]]*%]") or msg:find("%[DC%-[^%]]*%]")) and msg:find("%[Debug%]") then
            return true
        end

        -- DC-Collection protocol debug sometimes uses [DEBUG] (upper) in the message
        if (msg:find("%[DC[^%]]*%]") or msg:find("%[DC%-[^%]]*%]")) and msg:find("%[DEBUG%]") then
            return true
        end

        -- DC-Mapupgrades / HLBG can use shared DC_DebugUtils: |cff33ff99[AddonName]|r ...
        local tag = msg:match("^|cff33ff99%[([^%]]+)%]|r")
        if tag and (tag:find("^DC") or tag:find("^DC%-") or tag == "HLBG") then
            return true
        end

        -- HLBG sometimes embeds explicit markers
        if msg:find("HLBG Debug") or msg:find("HLBG Debug:") then
            return true
        end

        -- Protocol/diagnostic debug tags used by some DC addons
        if msg:find("%[DC[^%]]* Protocol%]") then
            return true
        end

        return false
    end

    local dcDebugCaptureUntil = 0
    local function IsDcDebugContinuationLine(msg)
        if type(msg) ~= "string" then return false end
        if GetTime and GetTime() > (dcDebugCaptureUntil or 0) then
            return false
        end

        -- Continuation lines often look like:
        -- [15:23]   Key: value
        -- or just:  Key: value
        local stripped = msg
        stripped = stripped:gsub("^|cff%x%x%x%x%x%x", "")
        stripped = stripped:gsub("^%[\d\d:%d\d%]%s+", "")

        if stripped:find("^%s%s+%S") then
            return true
        end

        return false
    end

    -- ============================================================
    -- Hotspot spam suppression (debounce + cooldown)
    -- ============================================================
    local hotspotPending = nil
    local hotspotPendingDueAt = 0
    local hotspotLastShownAt = 0
    local hotspotFlushInProgress = false

    local function GetHotspotKind(msg)
        if type(msg) ~= "string" then return nil end
        if not msg:find("%[Hotspot", 1, false) then
            return nil
        end

        if msg:find("%[Hotspot%]", 1, true) and msg:find("entered an XP Hotspot", 1, true) then
            return "enter"
        end
        if (msg:find("%[Hotspot Notice%]", 1, true) or msg:find("%[Hotspot%]", 1, true)) and msg:find("left the XP Hotspot", 1, true) then
            return "leave"
        end
        if msg:find("%[Hotspot Results%]", 1, true) then
            return "results"
        end

        return "other"
    end

    local function IsOppositeHotspotKind(a, b)
        return (a == "enter" and b == "leave") or (a == "leave" and b == "enter")
    end

    local hotspotThrottleFrame = _G["DCQoS_HotspotThrottleFrame"]
    if not hotspotThrottleFrame then
        hotspotThrottleFrame = CreateFrame("Frame", "DCQoS_HotspotThrottleFrame", UIParent)
        hotspotThrottleFrame:Hide()
    end

    hotspotThrottleFrame:SetScript("OnUpdate", function()
        if not hotspotPending or hotspotPendingDueAt <= 0 then
            return
        end

        local now = (GetTime and GetTime()) or 0
        if now < hotspotPendingDueAt then
            return
        end

        local cooldown = tonumber(addon.settings.chat.hotspotCooldownSeconds) or 6
        if cooldown < 0 then cooldown = 0 end
        if (now - (hotspotLastShownAt or 0)) < cooldown then
            hotspotPending = nil
            hotspotPendingDueAt = 0
            return
        end

        local targetFrame = hotspotPending.frame or DEFAULT_CHAT_FRAME
        if targetFrame and targetFrame.AddMessage then
            hotspotFlushInProgress = true
            targetFrame:AddMessage(hotspotPending.msg, hotspotPending.r, hotspotPending.g, hotspotPending.b, unpack(hotspotPending.extra or {}))
            hotspotFlushInProgress = false
        end

        hotspotLastShownAt = now
        hotspotPending = nil
        hotspotPendingDueAt = 0
    end)

    local function MaybeDebounceHotspotMessage(frame, msg, r, g, b, ...)
        local s = addon.settings.chat
        if not s.enabled or not s.suppressHotspotSpam then
            return false
        end
        if hotspotFlushInProgress then
            return false
        end

        local kind = GetHotspotKind(msg)
        if not kind then
            return false
        end

        local now = (GetTime and GetTime()) or 0
        local debounce = tonumber(s.hotspotDebounceSeconds) or 3
        if debounce < 0 then debounce = 0 end

        if debounce == 0 then
            -- No debounce; rely on cooldown only (handled by flush frame when delaying). Let it through.
            hotspotLastShownAt = now
            return false
        end

        if hotspotPending and hotspotPending.kind then
            -- If we immediately flip state while moving, drop both.
            if IsOppositeHotspotKind(hotspotPending.kind, kind) then
                hotspotPending = nil
                hotspotPendingDueAt = 0
                return true
            end

            -- Duplicate while pending; suppress.
            if hotspotPending.kind == kind then
                return true
            end
        end

        hotspotPending = {
            frame = frame,
            kind = kind,
            msg = msg,
            r = r,
            g = g,
            b = b,
            extra = { ... },
        }
        hotspotPendingDueAt = now + debounce
        return true
    end
    
    for i = 1, NUM_CHAT_WINDOWS do
        local chatFrame = _G["ChatFrame" .. i]
        if chatFrame and not chatFrame.dcHooked then
            chatFrame.dcHooked = true
            
            local origAddMessage = chatFrame.AddMessage
            chatFrame._dcOrigAddMessage = origAddMessage
            chatFrame.AddMessage = function(self, msg, r, g, b, ...)
                if msg then
                    -- Optional: capture DC-related debug spam into a dedicated chat tab
                    local comm = addon.settings and addon.settings.communication
                    if comm and comm.routeDcDebugToTab and comm.captureDcDebugFromOtherAddons and type(msg) == "string" then
                        if IsDcDebugLine(msg) then
                            -- Open a short window to capture follow-up lines that don't repeat the prefix.
                            if GetTime then
                                dcDebugCaptureUntil = GetTime() + 2.0
                            else
                                dcDebugCaptureUntil = 0
                            end
                            local debugFrame = addon:EnsureChatWindow(comm.dcDebugTabName or "DCDebug")
                            if debugFrame and debugFrame ~= self and debugFrame.AddMessage then
                                debugFrame:AddMessage(msg, r, g, b, ...)
                                return
                            end
                        elseif IsDcDebugContinuationLine(msg) then
                            local debugFrame = addon:EnsureChatWindow(comm.dcDebugTabName or "DCDebug")
                            if debugFrame and debugFrame ~= self and debugFrame.AddMessage then
                                debugFrame:AddMessage(msg, r, g, b, ...)
                                return
                            end
                        end
                    end

                    -- Debounce XP Hotspot enter/leave spam while running around.
                    if type(msg) == "string" and MaybeDebounceHotspotMessage(self, msg, r, g, b, ...) then
                        return
                    end

                    local settings = addon.settings.chat
                    if not settings.enabled then
                        return origAddMessage(self, msg, r, g, b, ...)
                    end
                    
                    -- Add timestamps
                    if settings.showTimestamps then
                        local timestamp = GetTimestamp(settings.timestampFormat)
                        if not msg:find("^|cff%x%x%x%x%x%x%[%d%d:%d%d") then  -- Don't double-timestamp
                            msg = "|cff888888" .. timestamp .. "|r" .. msg
                        end
                    end
                    
                    -- Shorten channel names
                    if settings.hideChannelNames then
                        for long, short in pairs(channelReplacements) do
                            msg = msg:gsub("%[" .. long .. "%]", "[" .. short .. "]")
                            msg = msg:gsub("%[(%d+)%. " .. long .. "%]", "[%1]")
                        end
                    end
                    
                    -- Highlight URLs
                    if settings.detectURLs then
                        msg = HighlightURLs(msg)
                    end
                end
                
                return origAddMessage(self, msg, r, g, b, ...)
            end
        end
    end
end

-- ============================================================
-- Class Colors via Chat Filter
-- ============================================================
local function SetupClassColorFilter()
    local settings = addon.settings.chat
    if not settings.classColoredNames then return end
    
    -- Chat event filter for class coloring
    local function ClassColorFilter(self, event, msg, author, ...)
        if not addon.settings.chat.classColoredNames then
            return false, msg, author, ...
        end
        
        local playerName = author:match("([^%-]+)")
        local classToken = playerClassCache[playerName]
        
        if classToken then
            local colorCode = GetClassColorCode(classToken)
            -- The chat frame will handle the player link coloring
        end
        
        return false, msg, author, ...
    end
    
    -- Register filter for various chat types
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", ClassColorFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_YELL", ClassColorFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY", ClassColorFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY_LEADER", ClassColorFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID", ClassColorFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_LEADER", ClassColorFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_WARNING", ClassColorFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD", ClassColorFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_OFFICER", ClassColorFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", ClassColorFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", ClassColorFilter)
end

-- ============================================================
-- Sticky Chat Channels
-- ============================================================
local function SetupStickyChannels()
    local settings = addon.settings.chat
    if not settings.enabled or not settings.stickyChannels then return end
    
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
-- Max Chat Lines
-- ============================================================
local function SetupChatLines()
    local settings = addon.settings.chat
    local maxLines = tonumber(settings.maxLines) or 1000
    
    for i = 1, NUM_CHAT_WINDOWS do
        local chatFrame = _G["ChatFrame" .. i]
        if chatFrame then
            chatFrame:SetMaxLines(maxLines)
        end
    end
end

-- ============================================================
-- Hide Social Buttons
-- ============================================================
local function SetupHideSocialButtons()
    local settings = addon.settings.chat
    if not settings.enabled or not settings.hideSocialButtons then return end
    
    if FriendsMicroButton then
        FriendsMicroButton:Hide()
        FriendsMicroButton:SetScript("OnShow", function(self) self:Hide() end)
    end
    
    if ChatFrameMenuButton then
        ChatFrameMenuButton:Hide()
        ChatFrameMenuButton:SetScript("OnShow", function(self) self:Hide() end)
    end
end

-- ============================================================
-- Chat Copy Feature
-- ============================================================
local copyFrame = nil
local copyEditBox = nil

local function CreateCopyFrame()
    if copyFrame then return end
    
    -- Main frame
    copyFrame = CreateFrame("Frame", "DCQoS_ChatCopyFrame", UIParent)
    copyFrame:SetSize(500, 300)
    copyFrame:SetPoint("CENTER")
    copyFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
    copyFrame:SetBackdropColor(0, 0, 0, 0.9)
    copyFrame:SetMovable(true)
    copyFrame:EnableMouse(true)
    copyFrame:RegisterForDrag("LeftButton")
    copyFrame:SetScript("OnDragStart", copyFrame.StartMoving)
    copyFrame:SetScript("OnDragStop", copyFrame.StopMovingOrSizing)
    copyFrame:SetFrameStrata("DIALOG")
    copyFrame:Hide()
    
    -- Title
    local title = copyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -15)
    title:SetText("Chat Copy")
    
    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", "DCQoS_ChatCopyScroll", copyFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 12, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 45)
    
    -- Edit box for copying
    copyEditBox = CreateFrame("EditBox", "DCQoS_ChatCopyEdit", scrollFrame)
    copyEditBox:SetMultiLine(true)
    copyEditBox:SetAutoFocus(false)
    copyEditBox:SetFontObject(ChatFontNormal)
    copyEditBox:SetWidth(450)
    copyEditBox:SetScript("OnEscapePressed", function(self)
        copyFrame:Hide()
    end)
    
    scrollFrame:SetScrollChild(copyEditBox)
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, copyFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    
    -- Select All button
    local selectBtn = CreateFrame("Button", nil, copyFrame, "UIPanelButtonTemplate")
    selectBtn:SetSize(100, 22)
    selectBtn:SetPoint("BOTTOMLEFT", 15, 12)
    selectBtn:SetText("Select All")
    selectBtn:SetScript("OnClick", function()
        copyEditBox:HighlightText()
        copyEditBox:SetFocus()
    end)
    
    -- Close button
    local closeButton = CreateFrame("Button", nil, copyFrame, "UIPanelButtonTemplate")
    closeButton:SetSize(80, 22)
    closeButton:SetPoint("BOTTOMRIGHT", -15, 12)
    closeButton:SetText("Close")
    closeButton:SetScript("OnClick", function()
        copyFrame:Hide()
    end)
end

local function ShowChatCopy(chatFrame)
    CreateCopyFrame()
    
    -- Get chat messages
    local numMessages = chatFrame:GetNumMessages()
    local text = ""
    
    for i = 1, numMessages do
        local line = chatFrame:GetMessageInfo(i)
        if line then
            -- Strip color codes for cleaner copy
            line = line:gsub("|c%x%x%x%x%x%x%x%x", "")
            line = line:gsub("|r", "")
            line = line:gsub("|H.-|h", "")
            line = line:gsub("|h", "")
            text = text .. line .. "\n"
        end
    end
    
    copyEditBox:SetText(text)
    copyFrame:Show()
    copyEditBox:HighlightText()
    copyEditBox:SetFocus()
end

-- Simple URL copy box
local function SetupSimpleCopyBox()
    local copyBox = CreateFrame("Frame", "DCQoS_URLCopy", UIParent)
    copyBox:SetSize(400, 60)
    copyBox:SetPoint("CENTER")
    copyBox:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    copyBox:SetBackdropColor(0, 0, 0, 0.9)
    copyBox:SetFrameStrata("DIALOG")
    copyBox:Hide()
    
    local urlEdit = CreateFrame("EditBox", nil, copyBox, "InputBoxTemplate")
    urlEdit:SetSize(370, 20)
    urlEdit:SetPoint("CENTER", 0, 5)
    urlEdit:SetAutoFocus(false)
    urlEdit:SetScript("OnEscapePressed", function() copyBox:Hide() end)
    urlEdit:SetScript("OnEnterPressed", function() copyBox:Hide() end)
    
    local label = copyBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("BOTTOM", urlEdit, "TOP", 0, 5)
    label:SetText("Press Ctrl+C to copy, then Escape to close")
    
    copyBox.editBox = urlEdit
    
    -- Global function to show URL copy
    addon.ShowCopyBox = function(self, text)
        copyBox.editBox:SetText(text or "")
        copyBox:Show()
        copyBox.editBox:SetFocus()
        copyBox.editBox:HighlightText()
    end
end

-- Add copy button to chat frames
local function SetupChatCopyButtons()
    local settings = addon.settings.chat
    if not settings.enableChatCopy then return end
    
    for i = 1, NUM_CHAT_WINDOWS do
        local chatFrame = _G["ChatFrame" .. i]
        local chatTab = _G["ChatFrame" .. i .. "Tab"]
        
        if chatFrame and chatTab and not chatFrame.dcCopyBtn then
            local copyBtn = CreateFrame("Button", nil, chatFrame)
            copyBtn:SetSize(20, 20)
            copyBtn:SetPoint("TOPRIGHT", chatFrame, "TOPRIGHT", 0, 0)
            copyBtn:SetNormalTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
            copyBtn:SetHighlightTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
            copyBtn:SetAlpha(0.5)
            copyBtn:SetScript("OnEnter", function(self)
                self:SetAlpha(1)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Copy Chat", 1, 1, 1)
                GameTooltip:AddLine("Click to copy chat history", 0.8, 0.8, 0.8)
                GameTooltip:Show()
            end)
            copyBtn:SetScript("OnLeave", function(self)
                self:SetAlpha(0.5)
                GameTooltip:Hide()
            end)
            copyBtn:SetScript("OnClick", function()
                ShowChatCopy(chatFrame)
            end)
            
            chatFrame.dcCopyBtn = copyBtn
        end
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
    
    -- Setup all features
    SetupChatFrameHooks()
    SetupURLHandler()
    SetupClassCaching()
    SetupClassColorFilter()
    SetupStickyChannels()
    SetupChatLines()
    SetupHideSocialButtons()
    SetupSimpleCopyBox()
    SetupChatCopyButtons()
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
    desc:SetWidth(450)
    desc:SetJustifyH("LEFT")
    desc:SetText("Enhanced chat with timestamps, class colors, URL detection, and copy features.")
    
    local yOffset = -70
    
    -- ============================================================
    -- Timestamps Section
    -- ============================================================
    local timestampHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    timestampHeader:SetPoint("TOPLEFT", 16, yOffset)
    timestampHeader:SetText("Timestamps")
    yOffset = yOffset - 25
    
    -- Show Timestamps
    local timestampCb = addon:CreateCheckbox(parent)
    timestampCb:SetPoint("TOPLEFT", 16, yOffset)
    timestampCb.Text:SetText("Show timestamps in chat")
    timestampCb:SetChecked(settings.showTimestamps)
    timestampCb:SetScript("OnClick", function(self)
        addon:SetSetting("chat.showTimestamps", self:GetChecked())
    end)
    yOffset = yOffset - 35
    
    -- ============================================================
    -- Player Names Section
    -- ============================================================
    local namesHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    namesHeader:SetPoint("TOPLEFT", 16, yOffset)
    namesHeader:SetText("Player Names")
    yOffset = yOffset - 25

    -- Max Lines Slider
    local linesSlider = addon:CreateSlider(parent)
    linesSlider:SetPoint("TOPLEFT", 200, yOffset + 25) -- Place to the right of Player Names header area
    linesSlider.Text:SetText("Max Chat Lines: " .. settings.maxLines)
    linesSlider:SetMinMaxValues(100, 5000)
    linesSlider:SetValueStep(100)
    linesSlider:SetValue(settings.maxLines)
    linesSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        self.Text:SetText("Max Chat Lines: " .. value)
        addon:SetSetting("chat.maxLines", value)
    end)
    linesSlider:SetScript("OnMouseUp", function(self)
        -- Apply immediately
        SetupChatLines()
    end)
    
    
    -- Class-Colored Names
    local classColorCb = addon:CreateCheckbox(parent)
    classColorCb:SetPoint("TOPLEFT", 16, yOffset)
    classColorCb.Text:SetText("Color player names by class")
    classColorCb:SetChecked(settings.classColoredNames)
    classColorCb:SetScript("OnClick", function(self)
        addon:SetSetting("chat.classColoredNames", self:GetChecked())
        addon:Print("Requires /reload to take effect", true)
    end)
    yOffset = yOffset - 35
    
    -- ============================================================
    -- URLs Section
    -- ============================================================
    local urlHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    urlHeader:SetPoint("TOPLEFT", 16, yOffset)
    urlHeader:SetText("URL Detection")
    yOffset = yOffset - 25
    
    -- Detect URLs
    local urlCb = addon:CreateCheckbox(parent)
    urlCb:SetPoint("TOPLEFT", 16, yOffset)
    urlCb.Text:SetText("Highlight and make URLs clickable")
    urlCb:SetChecked(settings.detectURLs)
    urlCb:SetScript("OnClick", function(self)
        addon:SetSetting("chat.detectURLs", self:GetChecked())
    end)
    
    local urlInfo = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    urlInfo:SetPoint("TOPLEFT", urlCb, "BOTTOMLEFT", 20, -2)
    urlInfo:SetText("Click URLs in chat to copy them")
    urlInfo:SetTextColor(0.5, 0.5, 0.5)
    yOffset = yOffset - 45
    
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
    hideChannelsCb.Text:SetText("Shorten channel names")
    hideChannelsCb:SetChecked(settings.hideChannelNames)
    hideChannelsCb:SetScript("OnClick", function(self)
        addon:SetSetting("chat.hideChannelNames", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    -- Hide Social Buttons
    local hideSocialCb = addon:CreateCheckbox(parent)
    hideSocialCb:SetPoint("TOPLEFT", 16, yOffset)
    hideSocialCb.Text:SetText("Hide social/menu buttons")
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
    stickyCb.Text:SetText("Sticky chat channels")
    stickyCb:SetChecked(settings.stickyChannels)
    stickyCb:SetScript("OnClick", function(self)
        addon:SetSetting("chat.stickyChannels", self:GetChecked())
        addon:Print("Requires /reload to take effect", true)
    end)
    
    local stickyInfo = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    stickyInfo:SetPoint("TOPLEFT", stickyCb, "BOTTOMLEFT", 20, -2)
    stickyInfo:SetText("Remember the last used channel when typing")
    stickyInfo:SetTextColor(0.5, 0.5, 0.5)
    yOffset = yOffset - 45

    -- ============================================================
    -- Spam Control Section
    -- ============================================================
    local spamHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    spamHeader:SetPoint("TOPLEFT", 16, yOffset)
    spamHeader:SetText("Spam Control")
    yOffset = yOffset - 25

    local hotspotCb = addon:CreateCheckbox(parent)
    hotspotCb:SetPoint("TOPLEFT", 16, yOffset)
    hotspotCb.Text:SetText("Debounce XP Hotspot enter/leave messages")
    hotspotCb:SetChecked(settings.suppressHotspotSpam)
    hotspotCb:SetScript("OnClick", function(self)
        addon:SetSetting("chat.suppressHotspotSpam", self:GetChecked())
    end)
    yOffset = yOffset - 35

    local debounceSlider = addon:CreateSlider(parent)
    debounceSlider:SetPoint("TOPLEFT", 16, yOffset)
    debounceSlider.Text:SetText("Hotspot debounce: " .. (settings.hotspotDebounceSeconds or 3) .. "s")
    debounceSlider:SetMinMaxValues(0, 10)
    debounceSlider:SetValueStep(1)
    debounceSlider:SetValue(settings.hotspotDebounceSeconds or 3)
    debounceSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        self.Text:SetText("Hotspot debounce: " .. value .. "s")
        addon:SetSetting("chat.hotspotDebounceSeconds", value)
    end)
    yOffset = yOffset - 45

    local cooldownSlider = addon:CreateSlider(parent)
    cooldownSlider:SetPoint("TOPLEFT", 16, yOffset)
    cooldownSlider.Text:SetText("Hotspot cooldown: " .. (settings.hotspotCooldownSeconds or 6) .. "s")
    cooldownSlider:SetMinMaxValues(0, 30)
    cooldownSlider:SetValueStep(1)
    cooldownSlider:SetValue(settings.hotspotCooldownSeconds or 6)
    cooldownSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        self.Text:SetText("Hotspot cooldown: " .. value .. "s")
        addon:SetSetting("chat.hotspotCooldownSeconds", value)
    end)
    yOffset = yOffset - 55
    
    -- ============================================================
    -- Copy Section
    -- ============================================================
    local copyHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    copyHeader:SetPoint("TOPLEFT", 16, yOffset)
    copyHeader:SetText("Chat Copy")
    yOffset = yOffset - 25
    
    -- Enable Chat Copy
    local copyCb = addon:CreateCheckbox(parent)
    copyCb:SetPoint("TOPLEFT", 16, yOffset)
    copyCb.Text:SetText("Show copy button on chat frames")
    copyCb:SetChecked(settings.enableChatCopy)
    copyCb:SetScript("OnClick", function(self)
        addon:SetSetting("chat.enableChatCopy", self:GetChecked())
        addon:Print("Requires /reload to take effect", true)
    end)
    
    return yOffset - 50
end

-- ============================================================
-- Register Module
-- ============================================================
addon:RegisterModule("Chat", Chat)
