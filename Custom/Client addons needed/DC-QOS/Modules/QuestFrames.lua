-- ============================================================
-- DC-QoS: Quest Frames Module
-- ============================================================
-- Retail-inspired quest frame styling and follow controls for
-- the DarkChaos 3.3.5-compatible client.
-- ============================================================

local addon = DCQOS
local questTrackingUtils = type(addon.GetQuestTrackingUtils) == "function" and addon:GetQuestTrackingUtils() or nil

local QuestFrames = {
    displayName = "QuestFrames",
    settingKey = "questFrames",
    icon = "Interface\\Icons\\INV_Misc_Note_01",
    defaults = {
        questFrames = {
            enabled = true,
            retailSkin = true,
            showQuestIds = true,
            showQuestLevels = true,
            showFollowButton = true,
            decorateRewards = true,
            accentTrackedQuest = true,
        },
    },
}

local ASSET_ROOT = "Interface\\AddOns\\DC-QOS\\Textures\\QuestFrame\\"
local DC_ADDON_BACKGROUND_TEXTURE = "Interface\\AddOns\\DC-QOS\\Textures\\Backgrounds\\FelLeather_512.tga"
local QUEST_BACKGROUND_TEXTURE = ASSET_ROOT .. "questbookbg"
local QUEST_LOG_BACKGROUND_TEXTURE = ASSET_ROOT .. "questlogbackground"
local QUEST_LOG_FRAME_TEXTURE = ASSET_ROOT .. "questlogframe"
local QUEST_LOG_DUAL_LEFT_TEXTURE = ASSET_ROOT .. "ui-questlogdualpane-left"
local QUEST_LOG_DUAL_RIGHT_TEXTURE = ASSET_ROOT .. "ui-questlogdualpane-right"
local QUEST_LOG_TOPLEFT_TEXTURE = ASSET_ROOT .. "ui-questlog-topleft"
local QUEST_LOG_TOPRIGHT_TEXTURE = ASSET_ROOT .. "ui-questlog-topright"
local QUEST_LOG_BOTTOMLEFT_TEXTURE = ASSET_ROOT .. "ui-questlog-botleft"
local QUEST_LOG_BOTTOMRIGHT_TEXTURE = ASSET_ROOT .. "ui-questlog-botright"
local QUEST_DIVIDER_TEXTURE = ASSET_ROOT .. "ui-horizontalbreak"
local QUEST_PORTRAIT_TEXTURE = ASSET_ROOT .. "questportrait"
local QUEST_DETAILS_TOPLEFT_TEXTURE = ASSET_ROOT .. "ui-questdetails-topleft"
local QUEST_DETAILS_TOPRIGHT_TEXTURE = ASSET_ROOT .. "ui-questdetails-topright"
local QUEST_DETAILS_BOTTOMLEFT_TEXTURE = ASSET_ROOT .. "ui-questdetails-botleft-buttons"
local QUEST_DETAILS_BOTTOMRIGHT_TEXTURE = ASSET_ROOT .. "ui-questdetails-botright-buttons"
local QUEST_GREETING_TOPLEFT_TEXTURE = ASSET_ROOT .. "ui-questgreeting-topleft"
local QUEST_GREETING_TOPRIGHT_TEXTURE = ASSET_ROOT .. "ui-questgreeting-topright"
local QUEST_GREETING_BOTTOMLEFT_TEXTURE = ASSET_ROOT .. "ui-questgreeting-botleft"
local QUEST_GREETING_BOTTOMRIGHT_TEXTURE = ASSET_ROOT .. "ui-questgreeting-botright"
local QUEST_ITEM_HIGHLIGHT_TEXTURE = ASSET_ROOT .. "ui-questitemhighlight"
local QUEST_ITEM_NAMEFRAME_TEXTURE = ASSET_ROOT .. "ui-questitemnameframe"
local QUEST_LOG_TITLE_HIGHLIGHT_TEXTURE = ASSET_ROOT .. "ui-questlogtitlehighlight"
local QUEST_TITLE_HIGHLIGHT_TEXTURE = ASSET_ROOT .. "ui-questtitlehighlight"
local QUEST_AVAILABLE_ICON_TEXTURE = ASSET_ROOT .. "availablequesticon"
local QUEST_ACTIVE_ICON_TEXTURE = ASSET_ROOT .. "activequesticon"
local QUEST_DAILY_ICON_TEXTURE = ASSET_ROOT .. "dailyquesticon"
local QUEST_DAILY_ACTIVE_ICON_TEXTURE = ASSET_ROOT .. "dailyactivequesticon"
local QUEST_INCOMPLETE_ICON_TEXTURE = ASSET_ROOT .. "incompletequesticon"

local HEADER_LAYOUT = {
    QuestFrame = { left = 80, right = -54, top = -18 },
    GreetingFrame = { left = 26, right = -48, top = -16 },
    QuestLogDetailFrame = { left = 24, right = -48, top = -16 },
}

local ROOT_FRAME_NAMES = {
    "QuestFrame",
    "GreetingFrame",
    "QuestLogDetailFrame",
}

local WORLD_MAP_PANEL_LAYOUTS = {
    WorldMapQuestScrollFrame = {
        texture = QUEST_LOG_BACKGROUND_TEXTURE,
        left = 0,
        right = 1,
        top = 0,
        bottom = 1,
        tint = { 0.10, 0.07, 0.02, 0.22 },
    },
    WorldMapQuestDetailScrollFrame = {
        texture = QUEST_BACKGROUND_TEXTURE,
        left = 0.08,
        right = 0.92,
        top = 0.06,
        bottom = 0.94,
        tint = { 0.18, 0.11, 0.03, 0.14 },
    },
    WorldMapQuestRewardScrollFrame = {
        texture = QUEST_BACKGROUND_TEXTURE,
        left = 0.08,
        right = 0.92,
        top = 0.06,
        bottom = 0.94,
        tint = { 0.18, 0.11, 0.03, 0.14 },
    },
}

local COMBINED_WORLD_MAP_LAYOUT = {
    rightInset = 12,
    topInset = 38,
    bottomInset = 32,
    shellWidth = 316,
    panelInset = 14,
    headerHeight = 54,
    headerGap = 14,
    contentBottomInset = 14,
    panelShadeInset = 8,
    panelGap = 6,
    listRatio = 0.34,
    minShellHeight = 620,
    minListHeight = 176,
    minDetailHeight = 192,
    rewardHeight = 132,
    trackButtonHeight = 22,
}

local COMBINED_WORLD_MAP_FRAME_WIDTH = 900
local COMBINED_WORLD_MAP_FRAME_HEIGHT = 640

local TITLE_TEXT_NAMES = {
    "QuestInfoTitleHeader",
    "QuestProgressTitleText",
}

local BODY_TEXT_NAMES = {
    "QuestInfoDescriptionText",
    "QuestInfoObjectivesText",
    "QuestInfoRewardText",
    "QuestProgressText",
    "QuestRewardText",
    "GreetingText",
}

local SECTION_TEXT_NAMES = {
    "QuestInfoDescriptionHeader",
    "QuestInfoObjectivesHeader",
    "QuestProgressRequiredItemsText",
    "CurrentQuestsText",
    "AvailableQuestsText",
}

local ACTION_BUTTON_NAMES = {
    "QuestFrameAcceptButton",
    "QuestFrameDeclineButton",
    "QuestFrameCompleteButton",
    "QuestFrameCompleteQuestButton",
    "QuestFrameGoodbyeButton",
    "QuestFrameCancelButton",
    "QuestRewardCancelButton",
}

local ITEM_BUTTON_GROUPS = {
    { prefix = "QuestInfoItem", count = 15 },
    { prefix = "QuestRewardItem", count = 15 },
    { prefix = "QuestProgressItem", count = 6 },
}

local SHARED_ITEM_HIGHLIGHT_NAMES = {
    "QuestInfoItemHighlight",
    "QuestRewardItemHighlight",
}

local MOVABLE_FRAME_LAYOUTS = {
    QuestLogFrame = { left = 48, right = -94, top = -4, height = 28 },
    QuestFrame = { left = 72, right = -56, top = -6, height = 28 },
    GreetingFrame = { left = 28, right = -48, top = -6, height = 24 },
    QuestLogDetailFrame = { left = 26, right = -48, top = -6, height = 24 },
}

local state = {
    eventFrame = nil,
    refreshQueued = {},
    hooksInstalled = false,
    worldMapHooksInstalled = false,
    worldMapLayoutApplying = false,
    lastWorldMapRefreshRequestAt = 0,
    movableHandles = {},
    questRegionLookup = nil,
    worldMapHoverQuestId = nil,
}

local ApplyFontStyle
local GetSelectedWorldMapQuestFrame

local function EnsureSharedWorldMapRefreshDebounce()
    if type(addon.QueueWorldMapRefreshCycle) == "function" then
        return
    end

    function addon:QueueWorldMapRefreshCycle(callback)
        local bucket = self.__dcqosWorldMapRefreshCycle
        if type(bucket) ~= "table" then
            bucket = {
                pending = false,
                callbacks = {},
            }
            self.__dcqosWorldMapRefreshCycle = bucket
        end

        if type(callback) == "function" then
            table.insert(bucket.callbacks, callback)
        end

        if bucket.pending then
            return
        end

        bucket.pending = true

        local function Flush()
            bucket.pending = false

            local callbacks = bucket.callbacks
            bucket.callbacks = {}

            for i = 1, #callbacks do
                pcall(callbacks[i])
            end
        end

        if type(self.DelayedCall) == "function" then
            self:DelayedCall(0, Flush)
        else
            Flush()
        end
    end
end

local function QueueSharedWorldMapRefreshCycle(callback)
    EnsureSharedWorldMapRefreshDebounce()

    if type(addon.QueueWorldMapRefreshCycle) == "function" then
        addon:QueueWorldMapRefreshCycle(callback)
    elseif type(callback) == "function" then
        callback()
    end
end

local function GetSettings()
    return addon.settings and addon.settings.questFrames or addon.defaults.questFrames
end

local function UseModernQuestWindowCompatibility()
    return type(addon.IsModernQuestWindowActive) == "function"
        and addon:IsModernQuestWindowActive()
end

local function IsShownWithText(region)
    if not region or type(region.IsShown) ~= "function" or not region:IsShown() then
        return false
    end

    local text = type(region.GetText) == "function" and region:GetText() or nil
    return type(text) == "string" and text ~= ""
end

local function IsShownFrame(frame)
    return frame and type(frame.IsShown) == "function" and frame:IsShown()
end

local function ShouldPreferStockQuestChrome(frame)
    if not frame then
        return false
    end

    local frameName = frame.GetName and frame:GetName() or nil
    if frameName == "QuestFrame" then
        if IsShownFrame(QuestFrameGreetingPanel) then
            return IsShownWithText(GreetingText)
        end

        if IsShownFrame(QuestFrameDetailPanel)
            or IsShownFrame(QuestFrameProgressPanel)
            or IsShownFrame(QuestFrameRewardPanel) then
            return IsShownWithText(QuestInfoTitleHeader)
                or IsShownWithText(QuestProgressTitleText)
        end

        return false
    end

    if frameName == "GreetingFrame" then
        return IsShownWithText(GreetingText)
    end

    if frameName == "QuestLogDetailFrame" then
        return IsShownWithText(QuestInfoTitleHeader)
    end

    return false
end

local function SetFrameShown(frame, shown)
    if not frame then
        return
    end

    if shown then
        frame:Show()
    else
        frame:Hide()
    end
end

local function QueueRefresh(delaySeconds)
    local key = tostring(delaySeconds or 0)
    if state.refreshQueued[key] then
        return
    end

    state.refreshQueued[key] = true
    addon:DelayedCall(delaySeconds or 0, function()
        state.refreshQueued[key] = nil
        QuestFrames:Refresh()
    end)
end

local function SetWorldMapHoverQuestId(questId)
    questId = tonumber(questId)
    if not questId or questId <= 0 then
        questId = nil
    end

    if state.worldMapHoverQuestId == questId then
        return
    end

    state.worldMapHoverQuestId = questId
    QueueRefresh(0)
end

local ParseQuestIdFromLink = questTrackingUtils and questTrackingUtils.ParseQuestIdFromLink or function()
    return nil
end

local function ParseItemIdFromLink(link)
    if type(link) ~= "string" then
        return nil
    end

    local itemId = tonumber(link:match("item:(%d+):"))
    if itemId and itemId > 0 then
        return itemId
    end

    itemId = tonumber(link:match("item:(%d+)"))
    if itemId and itemId > 0 then
        return itemId
    end

    return nil
end

local function NormalizeItemTexturePath(texturePath)
    if type(texturePath) ~= "string" then
        return nil
    end

    texturePath = texturePath:gsub("^%s+", ""):gsub("%s+$", "")
    if texturePath == "" then
        return nil
    end

    return texturePath
end

local function IsPlaceholderItemTexture(texturePath)
    texturePath = NormalizeItemTexturePath(texturePath)
    if not texturePath then
        return true
    end

    local lowered = string.lower(texturePath)
    return lowered:find("quickslot", 1, true)
        or lowered:find("emptyslot", 1, true)
        or lowered:find("ui%-empty", 1, true)
end

local function StripQuestLevelPrefix(text)
    if type(text) ~= "string" then
        return text
    end

    return (text:gsub("^%[%d+%]%s*", ""))
end

local function BuildQuestDisplayTitle(title, level)
    title = StripQuestLevelPrefix(title or "")
    if title == "" then
        return title
    end

    if GetSettings().showQuestLevels and level and level > 0 then
        return string.format("[%d] %s", level, title)
    end

    return title
end

local function GetRecurringQuestType(questId, title)
    local lookup = addon and addon.QuestRecurringLookup or nil
    if not lookup or type(lookup.Resolve) ~= "function" then
        return nil
    end

    local recurrenceType = lookup.Resolve(questId, title)
    if recurrenceType == "daily" or recurrenceType == "weekly" then
        return recurrenceType
    end

    return nil
end

local function GetRecurringQuestFlags(questId, title, stockIsDaily)
    local recurrenceType = GetRecurringQuestType(questId, title)
    if not recurrenceType and stockIsDaily then
        recurrenceType = "daily"
    end

    local isWeekly = recurrenceType == "weekly"
    local isRecurring = recurrenceType == "daily" or isWeekly
    local isDaily = stockIsDaily or isRecurring

    return recurrenceType, isRecurring, isDaily, isWeekly
end

local GetQuestIdFromLogIndex = questTrackingUtils and questTrackingUtils.GetQuestIdFromLogIndex or function()
    return nil
end

local function BuildQuestRegionLookup()
    if state.questRegionLookup then
        return state.questRegionLookup
    end

    local lookup = {}
    if type(GetNumQuestLogEntries) ~= "function" or type(GetQuestLogTitle) ~= "function" then
        state.questRegionLookup = lookup
        return lookup
    end

    local currentRegion
    local regionOrder = 0
    local regionQuestOrder = 0
    local numEntries = GetNumQuestLogEntries() or 0

    for questLogIndex = 1, numEntries do
        local title, _, _, _, isHeader = GetQuestLogTitle(questLogIndex)
        if title then
            if isHeader then
                currentRegion = title
                regionOrder = regionOrder + 1
                regionQuestOrder = 0
            else
                regionQuestOrder = regionQuestOrder + 1
                lookup[questLogIndex] = {
                    regionName = currentRegion,
                    regionOrder = regionOrder > 0 and regionOrder or questLogIndex,
                    regionQuestOrder = regionQuestOrder,
                }
            end
        end
    end

    state.questRegionLookup = lookup
    return lookup
end

local function GetQuestRegionInfo(questLogIndex)
    questLogIndex = tonumber(questLogIndex)
    if not questLogIndex or questLogIndex <= 0 then
        return nil
    end

    return BuildQuestRegionLookup()[questLogIndex]
end

local function GetQuestLogInfo(questLogIndex)
    questLogIndex = tonumber(questLogIndex)
    if not questLogIndex or questLogIndex <= 0 or type(GetQuestLogTitle) ~= "function" then
        return nil
    end

    local title, level, tag, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questIdFromApi = GetQuestLogTitle(questLogIndex)
    if not title or isHeader then
        return nil
    end

    local questId = tonumber(questIdFromApi)
    if not questId or questId <= 0 then
        questId = GetQuestIdFromLogIndex(questLogIndex)
    end

    local regionInfo = GetQuestRegionInfo(questLogIndex)

    local stockIsDaily = (frequency == true or frequency == 1)
    local recurrenceType, isRecurring, isDaily, isWeekly = GetRecurringQuestFlags(questId, title, stockIsDaily)

    return {
        questLogIndex = questLogIndex,
        title = title,
        level = tonumber(level),
        tag = tag,
        suggestedGroup = tonumber(suggestedGroup),
        isComplete = (isComplete == true or isComplete == 1),
        isDaily = isDaily,
        isWeekly = isWeekly,
        isRecurring = isRecurring,
        recurrenceType = recurrenceType,
        questId = questId,
        regionName = regionInfo and regionInfo.regionName or nil,
        regionOrder = regionInfo and regionInfo.regionOrder or questLogIndex,
        regionQuestOrder = regionInfo and regionInfo.regionQuestOrder or questLogIndex,
    }
end

local function FindQuestLogIndexByQuestId(questId)
    questId = tonumber(questId)
    if not questId or questId <= 0 or type(GetNumQuestLogEntries) ~= "function" then
        return nil
    end

    local numEntries = GetNumQuestLogEntries() or 0
    for questLogIndex = 1, numEntries do
        local info = GetQuestLogInfo(questLogIndex)
        if info and info.questId == questId then
            return questLogIndex, info
        end
    end

    return nil
end

local function FindQuestLogInfoByTitle(title)
    title = StripQuestLevelPrefix(title)
    if type(title) ~= "string" or title == "" or type(GetNumQuestLogEntries) ~= "function" then
        return nil
    end

    local numEntries = GetNumQuestLogEntries() or 0
    for questLogIndex = 1, numEntries do
        local info = GetQuestLogInfo(questLogIndex)
        if info and StripQuestLevelPrefix(info.title) == title then
            return questLogIndex, info
        end
    end

    return nil
end

local GetSuperTrackedQuestId = questTrackingUtils and questTrackingUtils.GetSuperTrackedQuestId or function()
    return nil
end

local function DecorateQuestTitle(title, questId)
    if type(title) ~= "string" or title == "" then
        return title
    end

    if type(QuestUtils_DecorateQuestText) == "function" and questId and questId > 0 then
        local ok, decorated = pcall(QuestUtils_DecorateQuestText, questId, title, true)
        if ok and type(decorated) == "string" and decorated ~= "" then
            return decorated
        end
    end

    return title
end

local function BuildGreetingStatus()
    local parts = {}
    if type(GetNumActiveQuests) == "function" then
        table.insert(parts, string.format("%d Active", GetNumActiveQuests() or 0))
    end
    if type(GetNumAvailableQuests) == "function" then
        table.insert(parts, string.format("%d Available", GetNumAvailableQuests() or 0))
    end

    return table.concat(parts, "  |  ")
end

local function GetQuestFrameContext(ownerFrame)
    local isGreeting = false
    if QuestFrameGreetingPanel and QuestFrameGreetingPanel.IsShown and QuestFrameGreetingPanel:IsShown() then
        isGreeting = true
    elseif GreetingFrame and GreetingFrame.IsShown and GreetingFrame:IsShown() then
        isGreeting = true
    end

    if isGreeting then
        local npcName = type(UnitName) == "function" and UnitName("questnpc") or nil
        if not npcName or npcName == "" then
            npcName = QUESTS_LABEL or "Quests"
        end

        return {
            ownerFrame = ownerFrame,
            title = npcName,
            meta = BuildGreetingStatus(),
            showFollow = false,
            isGreeting = true,
        }
    end

    local title = type(GetTitleText) == "function" and GetTitleText() or nil
    local questId = type(GetQuestID) == "function" and tonumber(GetQuestID()) or nil
    local questLogIndex
    local info

    if questId and questId > 0 then
        questLogIndex, info = FindQuestLogIndexByQuestId(questId)
    end

    if info then
        title = info.title or title
    elseif title and type(GetQuestLogSelection) == "function" then
        local selectedIndex = tonumber(GetQuestLogSelection())
        if selectedIndex and selectedIndex > 0 then
            local selectedInfo = GetQuestLogInfo(selectedIndex)
            if selectedInfo and selectedInfo.title == title then
                info = selectedInfo
                questLogIndex = selectedInfo.questLogIndex
                questId = selectedInfo.questId or questId
            end
        end
    end

    local recurrenceType = info and info.recurrenceType or GetRecurringQuestType(questId, title)
    local isWeekly = info and info.isWeekly or recurrenceType == "weekly"
    local isRecurring = info and info.isRecurring or recurrenceType == "daily" or isWeekly
    local isDaily = info and info.isDaily or isRecurring

    return {
        ownerFrame = ownerFrame,
        title = title,
        questId = questId,
        questLogIndex = questLogIndex,
        level = info and info.level or nil,
        tag = info and info.tag or nil,
        suggestedGroup = info and info.suggestedGroup or nil,
        isDaily = isDaily,
        isWeekly = isWeekly,
        isRecurring = isRecurring,
        recurrenceType = recurrenceType,
        isComplete = info and info.isComplete or false,
        showFollow = questLogIndex and questLogIndex > 0,
    }
end

local function GetQuestLogDetailContext(ownerFrame)
    local questLogIndex = type(GetQuestLogSelection) == "function" and tonumber(GetQuestLogSelection()) or nil
    local info = questLogIndex and GetQuestLogInfo(questLogIndex) or nil
    if not info then
        return {
            ownerFrame = ownerFrame,
            title = QUESTS_LABEL or "Quest Details",
            meta = "Quest details",
            showFollow = false,
        }
    end

    return {
        ownerFrame = ownerFrame,
        title = info.title,
        questId = info.questId,
        questLogIndex = info.questLogIndex,
        level = info.level,
        tag = info.tag,
        suggestedGroup = info.suggestedGroup,
        isDaily = info.isDaily,
        isWeekly = info.isWeekly,
        isRecurring = info.isRecurring,
        recurrenceType = info.recurrenceType,
        isComplete = info.isComplete,
        showFollow = true,
    }
end

local function ResolveQuestContext(ownerFrame)
    if not ownerFrame then
        return nil
    end

    local name = ownerFrame.GetName and ownerFrame:GetName() or nil
    if name == "QuestLogDetailFrame" then
        return GetQuestLogDetailContext(ownerFrame)
    end

    return GetQuestFrameContext(ownerFrame)
end

local function IsQuestTracked(context)
    if not context then
        return false
    end

    local trackedQuestId = GetSuperTrackedQuestId()
    if trackedQuestId and context.questId and trackedQuestId == context.questId then
        return true
    end

    if context.questLogIndex and type(GetQuestWatchIndex) == "function" then
        return GetQuestWatchIndex(context.questLogIndex) ~= nil
    end

    return false
end

local function BuildQuestMeta(context)
    if not context then
        return ""
    end

    if context.meta then
        return context.meta
    end

    local settings = GetSettings()
    local parts = {}

    if type(context.regionName) == "string" and context.regionName ~= "" then
        table.insert(parts, context.regionName)
    end

    if settings.showQuestLevels and context.level and context.level > 0 then
        table.insert(parts, string.format("Level %d", context.level))
    end

    if settings.showQuestIds and context.questId and context.questId > 0 then
        table.insert(parts, "#" .. tostring(context.questId))
    end

    if type(context.tag) == "string" and context.tag ~= "" then
        table.insert(parts, context.tag)
    end

    if context.recurrenceType == "daily" then
        table.insert(parts, DAILY or "Daily")
    elseif context.recurrenceType == "weekly" then
        table.insert(parts, WEEKLY or "Weekly")
    elseif context.isDaily then
        table.insert(parts, DAILY or "Daily")
    end

    if context.suggestedGroup and context.suggestedGroup > 0 then
        table.insert(parts, string.format("Group %d", context.suggestedGroup))
    end

    if context.isComplete then
        table.insert(parts, COMPLETE or "Complete")
    end

    if IsQuestTracked(context) then
        table.insert(parts, "Tracked")
    end

    return table.concat(parts, "  |  ")
end

local function LayoutHeader(header, showFollow)
    header.title:ClearAllPoints()
    header.meta:ClearAllPoints()

    header.title:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
    header.meta:SetPoint("TOPLEFT", header.title, "BOTTOMLEFT", 0, -2)

    if showFollow then
        header.title:SetPoint("RIGHT", header.follow, "LEFT", -10, 0)
        header.meta:SetPoint("RIGHT", header.follow, "LEFT", -10, 0)
    else
        header.title:SetPoint("RIGHT", header, "RIGHT", 0, 0)
        header.meta:SetPoint("RIGHT", header, "RIGHT", 0, 0)
    end
end

local function ToggleFollowForFrame(ownerFrame)
    local navigation = addon:GetModule("Navigation")
    if not navigation then
        return
    end

    local context = ResolveQuestContext(ownerFrame)
    if not context or not context.questLogIndex or context.questLogIndex <= 0 then
        return
    end

    if IsQuestTracked(context) and navigation.ClearFollowQuest then
        navigation:ClearFollowQuest()
    elseif navigation.SetFollowQuestByLogIndex then
        navigation:SetFollowQuestByLogIndex(context.questLogIndex)
    end

    QueueRefresh(0)
    QueueRefresh(0.05)
end

local function EnsureFrameSkin(frame)
    if not frame or frame.__dcqosQuestSkin then
        return frame and frame.__dcqosQuestSkin or nil
    end

    local frameName = frame.GetName and frame:GetName() or nil
    local backgroundTexture = QUEST_BACKGROUND_TEXTURE
    local left, right, top, bottom = 0.08, 0.92, 0.06, 0.94
    if frameName == "QuestLogDetailFrame" then
        backgroundTexture = QUEST_LOG_BACKGROUND_TEXTURE
        left, right, top, bottom = 0, 1, 0, 1
    end

    local skin = CreateFrame("Frame", nil, frame)
    skin:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -24)
    skin:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)
    skin:SetFrameStrata(frame:GetFrameStrata())
    skin:SetFrameLevel(math.max(frame:GetFrameLevel() - 1, 0))
    skin:EnableMouse(false)

    local bg = skin:CreateTexture(nil, "BORDER")
    bg:SetAllPoints(skin)
    bg:SetTexture(backgroundTexture)
    bg:SetTexCoord(left, right, top, bottom)
    bg:SetAlpha(0.98)
    skin.bg = bg

    local shadow = skin:CreateTexture(nil, "BORDER")
    shadow:SetAllPoints(skin)
    shadow:SetTexture("Interface\\Buttons\\WHITE8x8")
    shadow:SetVertexColor(0.02, 0.02, 0.02, 0.18)
    skin.shadow = shadow

    local border = skin:CreateTexture(nil, "ARTWORK")
    border:SetPoint("TOPLEFT", skin, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", skin, "BOTTOMRIGHT", 1, -1)
    border:SetTexture("Interface\\Buttons\\WHITE8x8")
    border:SetVertexColor(0.24, 0.18, 0.08, 0.92)
    skin.border = border

    local topTint = skin:CreateTexture(nil, "ARTWORK")
    topTint:SetPoint("TOPLEFT", skin, "TOPLEFT", 0, 0)
    topTint:SetPoint("TOPRIGHT", skin, "TOPRIGHT", 0, 0)
    topTint:SetHeight(74)
    topTint:SetTexture("Interface\\Buttons\\WHITE8x8")
    topTint:SetVertexColor(0.30, 0.18, 0.04, 0.16)
    skin.topTint = topTint

    local shellTopLeft = skin:CreateTexture(nil, "OVERLAY")
    shellTopLeft:SetPoint("TOPLEFT", skin, "TOPLEFT", 0, 0)
    shellTopLeft:SetPoint("TOPRIGHT", skin, "TOP", 0, 0)
    shellTopLeft:SetHeight(104)
    shellTopLeft:SetAlpha(0.92)
    skin.shellTopLeft = shellTopLeft

    local shellTopRight = skin:CreateTexture(nil, "OVERLAY")
    shellTopRight:SetPoint("TOPLEFT", skin, "TOP", 0, 0)
    shellTopRight:SetPoint("TOPRIGHT", skin, "TOPRIGHT", 0, 0)
    shellTopRight:SetHeight(104)
    shellTopRight:SetAlpha(0.92)
    skin.shellTopRight = shellTopRight

    local shellBottomLeft = skin:CreateTexture(nil, "OVERLAY")
    shellBottomLeft:SetPoint("BOTTOMLEFT", skin, "BOTTOMLEFT", 0, 0)
    shellBottomLeft:SetPoint("BOTTOMRIGHT", skin, "BOTTOM", 0, 0)
    shellBottomLeft:SetHeight(120)
    shellBottomLeft:SetAlpha(0.94)
    skin.shellBottomLeft = shellBottomLeft

    local shellBottomRight = skin:CreateTexture(nil, "OVERLAY")
    shellBottomRight:SetPoint("BOTTOMLEFT", skin, "BOTTOM", 0, 0)
    shellBottomRight:SetPoint("BOTTOMRIGHT", skin, "BOTTOMRIGHT", 0, 0)
    shellBottomRight:SetHeight(120)
    shellBottomRight:SetAlpha(0.94)
    skin.shellBottomRight = shellBottomRight

    frame.__dcqosQuestSkin = skin
    return skin
end

local function GetFrameShellLayout(frame)
    if not frame then
        return nil
    end

    local frameName = frame.GetName and frame:GetName() or nil
    if frameName == "QuestLogDetailFrame" then
        return {
            topLeft = QUEST_LOG_TOPLEFT_TEXTURE,
            topRight = QUEST_LOG_TOPRIGHT_TEXTURE,
            bottomLeft = QUEST_LOG_BOTTOMLEFT_TEXTURE,
            bottomRight = QUEST_LOG_BOTTOMRIGHT_TEXTURE,
            topHeight = 88,
            bottomHeight = 106,
        }
    end

    if frameName == "GreetingFrame"
        or (frameName == "QuestFrame"
            and QuestFrameGreetingPanel
            and QuestFrameGreetingPanel.IsShown
            and QuestFrameGreetingPanel:IsShown()) then
        return {
            topLeft = QUEST_GREETING_TOPLEFT_TEXTURE,
            topRight = QUEST_GREETING_TOPRIGHT_TEXTURE,
            bottomLeft = QUEST_GREETING_BOTTOMLEFT_TEXTURE,
            bottomRight = QUEST_GREETING_BOTTOMRIGHT_TEXTURE,
            topHeight = 96,
            bottomHeight = 116,
        }
    end

    return {
        topLeft = QUEST_DETAILS_TOPLEFT_TEXTURE,
        topRight = QUEST_DETAILS_TOPRIGHT_TEXTURE,
        bottomLeft = QUEST_DETAILS_BOTTOMLEFT_TEXTURE,
        bottomRight = QUEST_DETAILS_BOTTOMRIGHT_TEXTURE,
        topHeight = 96,
        bottomHeight = 128,
    }
end

local function UpdateFrameShell(frame, skin)
    if not frame or not skin then
        return
    end

    local settings = GetSettings()
    local layout = settings.retailSkin and GetFrameShellLayout(frame) or nil
    local showShell = layout ~= nil and frame.IsShown and frame:IsShown()

    SetFrameShown(skin.shellTopLeft, showShell)
    SetFrameShown(skin.shellTopRight, showShell)
    SetFrameShown(skin.shellBottomLeft, showShell)
    SetFrameShown(skin.shellBottomRight, showShell)

    if not showShell then
        return
    end

    skin.shellTopLeft:SetTexture(layout.topLeft)
    skin.shellTopRight:SetTexture(layout.topRight)
    skin.shellBottomLeft:SetTexture(layout.bottomLeft)
    skin.shellBottomRight:SetTexture(layout.bottomRight)

    skin.shellTopLeft:SetHeight(layout.topHeight)
    skin.shellTopRight:SetHeight(layout.topHeight)
    skin.shellBottomLeft:SetHeight(layout.bottomHeight)
    skin.shellBottomRight:SetHeight(layout.bottomHeight)
end

local function EnsureHeader(frame)
    if not frame then
        return nil
    end

    if frame.__dcqosQuestHeader then
        return frame.__dcqosQuestHeader
    end

    local layout = HEADER_LAYOUT[frame:GetName()] or HEADER_LAYOUT.QuestLogDetailFrame
    local header = CreateFrame("Frame", nil, frame)
    header.ownerFrame = frame
    header:SetHeight(36)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", layout.left, layout.top)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", layout.right, layout.top)

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    title:SetJustifyH("LEFT")
    title:SetTextColor(1.0, 0.88, 0.36)
    title:SetShadowOffset(1, -1)
    title:SetShadowColor(0, 0, 0, 0.8)
    header.title = title

    local meta = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    meta:SetJustifyH("LEFT")
    meta:SetTextColor(0.88, 0.78, 0.48)
    header.meta = meta

    local divider = header:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", header, "BOTTOMLEFT", -10, -2)
    divider:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 10, -2)
    divider:SetHeight(18)
    divider:SetTexture(QUEST_DIVIDER_TEXTURE)
    divider:SetAlpha(0.85)
    header.divider = divider

    local follow = addon:CreateActionButton(header, "Follow", 94, 22)
    follow:SetPoint("TOPRIGHT", header, "TOPRIGHT", 0, 1)
    follow:SetScript("OnClick", function(self)
        ToggleFollowForFrame(self:GetParent().ownerFrame)
    end)
    header.follow = follow

    LayoutHeader(header, true)

    frame.__dcqosQuestHeader = header
    addon:RegisterScalableFrame(header)
    return header
end

local function EnsurePortraitAccent()
    if not QuestFramePortrait then
        return
    end

    if not QuestFramePortrait.__dcqosPortraitAccent then
        local ring = QuestFramePortrait:GetParent():CreateTexture(nil, "OVERLAY")
        ring:SetPoint("CENTER", QuestFramePortrait, "CENTER", 0, 0)
        ring:SetTexture(QUEST_PORTRAIT_TEXTURE)
        ring:SetAlpha(0.90)
        QuestFramePortrait.__dcqosPortraitAccent = ring
    end

    if QuestFramePortrait.SetTexCoord then
        QuestFramePortrait:SetTexCoord(0, 1, 0, 1)
    end

    local size = math.max(QuestFramePortrait:GetWidth() or 0, QuestFramePortrait:GetHeight() or 0) + 26
    QuestFramePortrait.__dcqosPortraitAccent:SetWidth(size)
    QuestFramePortrait.__dcqosPortraitAccent:SetHeight(size)
end

local function EnsureQuestLogChrome()
    if not QuestLogFrame then
        return nil
    end

    if QuestLogFrame.__dcqosQuestLogChrome then
        return QuestLogFrame.__dcqosQuestLogChrome
    end

    local chrome = CreateFrame("Frame", nil, QuestLogFrame)
    chrome:SetPoint("TOPLEFT", QuestLogFrame, "TOPLEFT", 10, -24)
    chrome:SetPoint("BOTTOMRIGHT", QuestLogFrame, "BOTTOMRIGHT", -10, 10)
    chrome:SetFrameStrata(QuestLogFrame:GetFrameStrata())
    chrome:SetFrameLevel(math.max(QuestLogFrame:GetFrameLevel() - 1, 0))
    chrome:EnableMouse(false)

    local bg = chrome:CreateTexture(nil, "BORDER")
    bg:SetAllPoints(chrome)
    bg:SetTexture(QUEST_LOG_BACKGROUND_TEXTURE)
    bg:SetAlpha(0.96)
    chrome.bg = bg

    local leftPane = chrome:CreateTexture(nil, "ARTWORK")
    leftPane:SetPoint("TOPLEFT", chrome, "TOPLEFT", 6, -4)
    leftPane:SetPoint("BOTTOM", chrome, "BOTTOM", -3, 4)
    leftPane:SetTexture(QUEST_LOG_DUAL_LEFT_TEXTURE)
    leftPane:SetAlpha(0.30)
    chrome.leftPane = leftPane

    local rightPane = chrome:CreateTexture(nil, "ARTWORK")
    rightPane:SetPoint("TOP", chrome, "TOP", 3, -4)
    rightPane:SetPoint("BOTTOMRIGHT", chrome, "BOTTOMRIGHT", -6, 4)
    rightPane:SetTexture(QUEST_LOG_DUAL_RIGHT_TEXTURE)
    rightPane:SetAlpha(0.30)
    chrome.rightPane = rightPane

    local frameArt = chrome:CreateTexture(nil, "OVERLAY")
    frameArt:SetAllPoints(chrome)
    frameArt:SetTexture(QUEST_LOG_FRAME_TEXTURE)
    frameArt:SetAlpha(0.94)
    chrome.frameArt = frameArt

    QuestLogFrame.__dcqosQuestLogChrome = chrome
    return chrome
end

local function UpdateQuestLogChrome()
    local chrome = EnsureQuestLogChrome()
    if not chrome then
        return
    end

    local settings = GetSettings()
    local isShown = settings.retailSkin and QuestLogFrame and QuestLogFrame.IsShown and QuestLogFrame:IsShown()
    SetFrameShown(chrome, isShown and true or false)
end

local function GetButtonFontString(button)
    if not button then
        return nil
    end

    if type(button.GetFontString) == "function" then
        local fontString = button:GetFontString()
        if fontString then
            return fontString
        end
    end

    if button.Text then
        return button.Text
    end

    if type(button.GetRegions) == "function" then
        local regions = { button:GetRegions() }
        for i = 1, #regions do
            local region = regions[i]
            if region and type(region.GetObjectType) == "function" and region:GetObjectType() == "FontString" then
                return region
            end
        end
    end

    return nil
end

local function GetButtonFontStrings(button)
    if not button then
        return {}
    end

    local fontStrings = {}
    local seen = {}

    local function Add(fontString)
        if fontString and not seen[fontString] then
            seen[fontString] = true
            table.insert(fontStrings, fontString)
        end
    end

    Add(GetButtonFontString(button))

    if button.Text then
        Add(button.Text)
    end
    if button.Name then
        Add(button.Name)
    end

    if type(button.GetRegions) == "function" then
        local regions = { button:GetRegions() }
        for i = 1, #regions do
            local region = regions[i]
            if region and type(region.GetObjectType) == "function" and region:GetObjectType() == "FontString" then
                Add(region)
            end
        end
    end

    return fontStrings
end

local function GetQuestItemNameLabel(button)
    if not button then
        return nil
    end

    local buttonName = button.GetName and button:GetName() or nil
    if buttonName and _G[buttonName .. "Name"] then
        return _G[buttonName .. "Name"]
    end

    if button.Name then
        return button.Name
    end

    local fontStrings = GetButtonFontStrings(button)
    for i = 1, #fontStrings do
        local fontString = fontStrings[i]
        local text = fontString.GetText and fontString:GetText() or nil
        if text and text ~= "" then
            return fontString
        end
    end

    return fontStrings[1]
end

local function ButtonLooksLikeQuestItem(button)
    if not button or (button.IsShown and not button:IsShown()) then
        return false
    end

    local buttonName = button.GetName and button:GetName() or nil
    if type(buttonName) == "string" then
        local lower = string.lower(buttonName)
        if lower:find("quest", 1, true) and lower:find("item", 1, true) then
            return true
        end
    end

    local nameLabel = GetQuestItemNameLabel(button)
    local text = nameLabel and nameLabel.GetText and nameLabel:GetText() or nil
    if type(text) == "string" and text ~= "" then
        if button.Icon or button.icon or button.IconTexture or button.iconTexture then
            return true
        end

        if buttonName and (_G[buttonName .. "IconTexture"] or _G[buttonName .. "Icon"]) then
            return true
        end
    end

    return false
end

local function ResolveTextureRegion(object)
    if not object then
        return nil
    end

    if type(object.SetTexture) == "function" then
        return object
    end

    if type(object.GetHighlightTexture) == "function" then
        local highlightTexture = object:GetHighlightTexture()
        if highlightTexture and type(highlightTexture.SetTexture) == "function" then
            return highlightTexture
        end
    end

    if object.HighlightTexture and type(object.HighlightTexture.SetTexture) == "function" then
        return object.HighlightTexture
    end

    if type(object.GetRegions) == "function" then
        local regions = { object:GetRegions() }
        for i = 1, #regions do
            local region = regions[i]
            if region
                and type(region.GetObjectType) == "function"
                and region:GetObjectType() == "Texture"
                and type(region.SetTexture) == "function" then
                return region
            end
        end
    end

    return nil
end

local function CollectQuestItemIconRegions(button)
    if not button then
        return {}
    end

    local buttonName = button.GetName and button:GetName() or nil
    local iconCandidates = {
        button.IconTexture,
        button.iconTexture,
        button.Icon,
        button.icon,
    }
    local fallbackCandidates = {}

    local function AddCandidate(list, region)
        if region then
            table.insert(list, region)
        end
    end

    if buttonName then
        AddCandidate(iconCandidates, _G[buttonName .. "IconTexture"])
        AddCandidate(iconCandidates, _G[buttonName .. "Icon"])
    end

    if type(button.GetNormalTexture) == "function" then
        AddCandidate(fallbackCandidates, button:GetNormalTexture())
    end
    if type(button.GetPushedTexture) == "function" then
        AddCandidate(fallbackCandidates, button:GetPushedTexture())
    end

    local regions = {}
    local seen = {}

    local function AddRegion(region)
        if region
            and not seen[region]
            and type(region.GetObjectType) == "function"
            and region:GetObjectType() == "Texture"
            and type(region.SetTexture) == "function" then
            seen[region] = true
            table.insert(regions, region)
        end
    end

    for i = 1, #iconCandidates do
        AddRegion(iconCandidates[i])
    end

    if #regions == 0 then
        for i = 1, #fallbackCandidates do
            AddRegion(fallbackCandidates[i])
        end
    end

    return regions
end

local function GetQuestItemIconRegion(button)
    local regions = CollectQuestItemIconRegions(button)
    return regions[1]
end

local function ResolveQuestItemTexture(button)
    if not button then
        return nil
    end

    local itemType = button.type
    if type(itemType) == "string" then
        itemType = string.lower(itemType)
    end

    local itemIndex = button.GetID and tonumber(button:GetID()) or nil
    local texture = nil

    if itemType == "choice" and itemIndex and itemIndex > 0 then
        if type(GetQuestLogChoiceInfo) == "function" then
            local _, tex = GetQuestLogChoiceInfo(itemIndex)
            texture = NormalizeItemTexturePath(tex) or texture
        end
        if not texture and type(GetQuestItemInfo) == "function" then
            local _, tex = GetQuestItemInfo(itemType, itemIndex)
            texture = NormalizeItemTexturePath(tex) or texture
        end
    elseif itemType == "reward" and itemIndex and itemIndex > 0 then
        if type(GetQuestLogRewardInfo) == "function" then
            local _, tex = GetQuestLogRewardInfo(itemIndex)
            texture = NormalizeItemTexturePath(tex) or texture
        end
        if not texture and type(GetQuestItemInfo) == "function" then
            local _, tex = GetQuestItemInfo(itemType, itemIndex)
            texture = NormalizeItemTexturePath(tex) or texture
        end
    elseif itemType == "spell" then
        if type(GetQuestLogRewardSpell) == "function" then
            local tex = GetQuestLogRewardSpell()
            texture = NormalizeItemTexturePath(tex) or texture
        end
    elseif itemType and itemIndex and itemIndex > 0 and type(GetQuestItemInfo) == "function" then
        local _, tex = GetQuestItemInfo(itemType, itemIndex)
        texture = NormalizeItemTexturePath(tex) or texture
    end

    if texture and not IsPlaceholderItemTexture(texture) then
        return texture
    end

    local link = nil
    if itemType and itemIndex and itemIndex > 0 and type(GetQuestLogItemLink) == "function" then
        local ok, value = pcall(GetQuestLogItemLink, itemType, itemIndex)
        if ok and type(value) == "string" and value ~= "" then
            link = value
        end
    end
    if (not link or link == "") and itemType and itemIndex and itemIndex > 0 and type(GetQuestItemLink) == "function" then
        local ok, value = pcall(GetQuestItemLink, itemType, itemIndex)
        if ok and type(value) == "string" and value ~= "" then
            link = value
        end
    end

    if link and type(GetItemIcon) == "function" then
        local ok, icon = pcall(GetItemIcon, link)
        icon = NormalizeItemTexturePath(icon)
        if ok and icon and not IsPlaceholderItemTexture(icon) then
            return icon
        end

        local itemId = ParseItemIdFromLink(link)
        if itemId and itemId > 0 then
            ok, icon = pcall(GetItemIcon, itemId)
            icon = NormalizeItemTexturePath(icon)
            if ok and icon and not IsPlaceholderItemTexture(icon) then
                return icon
            end
        end
    end

    if texture and not IsPlaceholderItemTexture(texture) then
        return texture
    end

    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function ApplyQuestItemTexture(button, iconRegion, iconRegions)
    if not button then
        return
    end

    local regions = iconRegions
    if type(regions) ~= "table" then
        regions = CollectQuestItemIconRegions(button)
    end
    if iconRegion and #regions == 0 then
        table.insert(regions, iconRegion)
    end

    local texture = ResolveQuestItemTexture(button)
    if not texture or IsPlaceholderItemTexture(texture) then
        texture = "Interface\\Icons\\INV_Misc_QuestionMark"
    end

    if type(SetItemButtonTexture) == "function" then
        pcall(SetItemButtonTexture, button, texture)
    end

    for i = 1, #regions do
        local region = regions[i]
        if region and region.SetTexture then
            region:SetTexture(texture)
        end
        if region and region.SetVertexColor then
            region:SetVertexColor(1, 1, 1)
        end
        if region and region.SetBlendMode then
            region:SetBlendMode("BLEND")
        end
    end

    if type(SetItemButtonTextureVertexColor) == "function" then
        pcall(SetItemButtonTextureVertexColor, button, 1.0, 1.0, 1.0)
    end
    if type(SetItemButtonNameFrameVertexColor) == "function" then
        pcall(SetItemButtonNameFrameVertexColor, button, 1.0, 1.0, 1.0)
    end

    if button.GetNormalTexture then
        local normalTexture = button:GetNormalTexture()
        if normalTexture and normalTexture.SetVertexColor then
            normalTexture:SetVertexColor(1, 1, 1)
        end
    end
    if button.GetPushedTexture then
        local pushedTexture = button:GetPushedTexture()
        if pushedTexture and pushedTexture.SetVertexColor then
            pushedTexture:SetVertexColor(1, 1, 1)
        end
    end
end

local function GetQuestItemNameFrameRegion(button)
    if not button then
        return nil
    end

    local buttonName = button.GetName and button:GetName() or nil
    local candidates = {
        button.NameFrame,
        button.nameFrame,
        button.__dcqosQuestItemNameFrame,
    }

    if buttonName then
        table.insert(candidates, _G[buttonName .. "NameFrame"])
    end

    for i = 1, #candidates do
        local region = candidates[i]
        if region and type(region.GetObjectType) == "function" then
            local objType = region:GetObjectType()
            local isHideable = type(region.Hide) == "function" or type(region.SetAlpha) == "function"
            if (objType == "Texture" or objType == "Frame" or objType == "Button") and isHideable then
                return region
            end
        end
    end

    return nil
end

local function EnsureMovableFrame(frame)
    if not frame then
        return nil
    end

    local frameName = frame.GetName and frame:GetName() or nil
    local layout = MOVABLE_FRAME_LAYOUTS[frameName]
    if not layout then
        return nil
    end

    if frame.__dcqosQuestMoveHandle then
        if frame.__dcqosQuestMoveHandle.SetHighlightTexture then
            frame.__dcqosQuestMoveHandle:SetHighlightTexture(nil)
        end
        return frame.__dcqosQuestMoveHandle
    end

    if frame.SetMovable then
        frame:SetMovable(true)
    end
    if frame.SetClampedToScreen then
        frame:SetClampedToScreen(true)
    end

    local handle = CreateFrame("Button", nil, frame)
    handle:SetPoint("TOPLEFT", frame, "TOPLEFT", layout.left, layout.top)
    handle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", layout.right, layout.top)
    handle:SetHeight(layout.height)
    handle:RegisterForDrag("LeftButton")
    handle:SetFrameStrata(frame:GetFrameStrata())
    handle:SetFrameLevel((frame.GetFrameLevel and frame:GetFrameLevel() or 0) + 20)
    handle:EnableMouse(true)
    if handle.SetHighlightTexture then
        handle:SetHighlightTexture(nil)
    end
    if handle.SetHitRectInsets then
        handle:SetHitRectInsets(0, 0, 0, 0)
    end
    handle:SetScript("OnDragStart", function(self)
        local parent = self:GetParent()
        if not parent then
            return
        end
        if InCombatLockdown and InCombatLockdown() then
            return
        end
        parent:StartMoving()
    end)
    handle:SetScript("OnDragStop", function(self)
        local parent = self:GetParent()
        if not parent then
            return
        end
        parent:StopMovingOrSizing()
        if parent.SetUserPlaced then
            parent:SetUserPlaced(true)
        end
    end)
    handle:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then
            return
        end

        local parent = self:GetParent()
        if not parent then
            return
        end
        if InCombatLockdown and InCombatLockdown() then
            return
        end

        parent:StartMoving()
    end)
    handle:SetScript("OnMouseUp", function(self, button)
        if button ~= "LeftButton" then
            return
        end

        local parent = self:GetParent()
        if not parent then
            return
        end

        parent:StopMovingOrSizing()
        if parent.SetUserPlaced then
            parent:SetUserPlaced(true)
        end
    end)

    frame.__dcqosQuestMoveHandle = handle
    state.movableHandles[frameName] = handle
    return handle
end

local function EnsureWorldMapPanelSkin(frame, layout)
    if not frame or not layout then
        return nil
    end

    if frame.__dcqosWorldMapQuestSkin then
        return frame.__dcqosWorldMapQuestSkin
    end

    local skin = CreateFrame("Frame", nil, frame)
    skin:SetAllPoints(frame)
    skin:SetFrameStrata(frame:GetFrameStrata())
    skin:SetFrameLevel(math.max(frame:GetFrameLevel() - 1, 0))
    skin:EnableMouse(false)

    local bg = skin:CreateTexture(nil, "BORDER")
    bg:SetAllPoints(skin)
    bg:SetTexture(layout.texture)
    bg:SetTexCoord(layout.left or 0, layout.right or 1, layout.top or 0, layout.bottom or 1)
    bg:SetAlpha(0.96)
    skin.bg = bg

    local tint = skin:CreateTexture(nil, "ARTWORK")
    tint:SetAllPoints(skin)
    tint:SetTexture("Interface\\Buttons\\WHITE8x8")
    local tintColor = layout.tint or { 0.12, 0.08, 0.02, 0.18 }
    tint:SetVertexColor(tintColor[1], tintColor[2], tintColor[3], tintColor[4])
    skin.tint = tint

    local border = skin:CreateTexture(nil, "OVERLAY")
    border:SetPoint("TOPLEFT", skin, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", skin, "BOTTOMRIGHT", 1, -1)
    border:SetTexture("Interface\\Buttons\\WHITE8x8")
    border:SetVertexColor(0.22, 0.17, 0.08, 0.72)
    skin.border = border

    frame.__dcqosWorldMapQuestSkin = skin
    return skin
end

local function CreateCombinedWorldMapSectionChrome(parent)
    local chrome = CreateFrame("Frame", nil, parent)
    chrome:EnableMouse(false)
    chrome:SetBackdrop({
        bgFile = DC_ADDON_BACKGROUND_TEXTURE,
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = true,
        tileSize = 32,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    chrome:SetBackdropColor(0.05, 0.04, 0.02, 0.74)
    chrome:SetBackdropBorderColor(0.28, 0.20, 0.10, 0.28)

    local tint = chrome:CreateTexture(nil, "BACKGROUND")
    tint:SetAllPoints(chrome)
    tint:SetTexture("Interface\\Buttons\\WHITE8x8")
    tint:SetVertexColor(0.52, 0.34, 0.08, 0.06)
    chrome.tint = tint

    local glow = chrome:CreateTexture(nil, "ARTWORK")
    glow:SetAllPoints(chrome)
    glow:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0.08)
    chrome.glow = glow

    local accent = chrome:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", chrome, "TOPLEFT", 0, 0)
    accent:SetPoint("BOTTOMLEFT", chrome, "BOTTOMLEFT", 0, 0)
    accent:SetWidth(3)
    accent:SetTexture("Interface\\Buttons\\WHITE8x8")
    accent:SetVertexColor(0.90, 0.74, 0.28, 1)
    accent:SetAlpha(0.42)
    chrome.accent = accent

    return chrome
end

local function UpdateCombinedWorldMapSectionChrome(chrome, targetFrame, shown, r, g, b, emphasized)
    if not chrome then
        return
    end

    if not shown or not targetFrame then
        chrome:Hide()
        return
    end

    local inset = COMBINED_WORLD_MAP_LAYOUT.panelShadeInset + 2
    chrome:SetFrameStrata(targetFrame:GetFrameStrata())
    chrome:SetFrameLevel(math.max((targetFrame.GetFrameLevel and targetFrame:GetFrameLevel() or 1) - 1, 0))
    chrome:ClearAllPoints()
    chrome:SetPoint("TOPLEFT", targetFrame, "TOPLEFT", -inset, inset)
    chrome:SetPoint("BOTTOMRIGHT", targetFrame, "BOTTOMRIGHT", inset, -inset)
    chrome:SetBackdropColor(0.05, 0.04, 0.02, emphasized and 0.82 or 0.74)
    chrome:SetBackdropBorderColor(r, g, b, emphasized and 0.54 or 0.30)
    chrome.tint:SetVertexColor(r, g, b, emphasized and 0.10 or 0.06)
    chrome.glow:SetVertexColor(r, g, b, 1)
    chrome.glow:SetAlpha(emphasized and 0.18 or 0.08)
    chrome.accent:SetVertexColor(r, g, b, 1)
    chrome.accent:SetAlpha(emphasized and 0.76 or 0.42)
    chrome:Show()
end

local function EnsureCombinedWorldMapShell()
    if not WorldMapFrame then
        return nil
    end

    if WorldMapFrame.__dcqosCombinedQuestShell then
        return WorldMapFrame.__dcqosCombinedQuestShell
    end

    local shell = CreateFrame("Frame", nil, WorldMapFrame)
    shell:SetFrameStrata(WorldMapFrame:GetFrameStrata())

    local worldMapLevel = WorldMapFrame.GetFrameLevel and WorldMapFrame:GetFrameLevel() or 0
    local questFrameLevel = WorldMapQuestScrollFrame and WorldMapQuestScrollFrame.GetFrameLevel and WorldMapQuestScrollFrame:GetFrameLevel() or (worldMapLevel + 3)
    shell:SetFrameLevel(math.max(worldMapLevel + 1, questFrameLevel - 2))
    shell:EnableMouse(false)

    local leatherBg = shell:CreateTexture(nil, "BACKGROUND")
    leatherBg:SetAllPoints(shell)
    leatherBg:SetTexture(DC_ADDON_BACKGROUND_TEXTURE)
    if leatherBg.SetHorizTile then
        leatherBg:SetHorizTile(true)
    end
    if leatherBg.SetVertTile then
        leatherBg:SetVertTile(true)
    end
    shell.leatherBg = leatherBg

    shell:SetScript("OnSizeChanged", function(self, width, height)
        if not width or not height then
            return
        end

        local texRight = math.max(width, 1) / 512
        local texBottom = math.max(height, 1) / 512
        self.leatherBg:SetTexCoord(0, texRight, 0, texBottom)
    end)

    local bg = shell:CreateTexture(nil, "BORDER")
    bg:SetAllPoints(shell)
    bg:SetTexture(QUEST_LOG_BACKGROUND_TEXTURE)
    bg:SetAlpha(0.76)
    shell.bg = bg

    local topTint = shell:CreateTexture(nil, "ARTWORK")
    topTint:SetPoint("TOPLEFT", shell, "TOPLEFT", 0, 0)
    topTint:SetPoint("TOPRIGHT", shell, "TOPRIGHT", 0, 0)
    topTint:SetHeight(84)
    topTint:SetTexture("Interface\\Buttons\\WHITE8x8")
    topTint:SetVertexColor(0.30, 0.18, 0.04, 0.10)
    shell.topTint = topTint

    local border = shell:CreateTexture(nil, "OVERLAY")
    border:SetPoint("TOPLEFT", shell, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", shell, "BOTTOMRIGHT", 1, -1)
    border:SetTexture("Interface\\Buttons\\WHITE8x8")
    border:SetVertexColor(0.24, 0.18, 0.08, 0.74)
    shell.border = border

    local topLeft = shell:CreateTexture(nil, "OVERLAY")
    topLeft:SetPoint("TOPLEFT", shell, "TOPLEFT", 0, 0)
    topLeft:SetPoint("TOPRIGHT", shell, "TOP", 0, 0)
    topLeft:SetHeight(88)
    topLeft:SetTexture(QUEST_LOG_TOPLEFT_TEXTURE)
    topLeft:SetAlpha(0.92)
    shell.topLeft = topLeft

    local topRight = shell:CreateTexture(nil, "OVERLAY")
    topRight:SetPoint("TOPLEFT", shell, "TOP", 0, 0)
    topRight:SetPoint("TOPRIGHT", shell, "TOPRIGHT", 0, 0)
    topRight:SetHeight(88)
    topRight:SetTexture(QUEST_LOG_TOPRIGHT_TEXTURE)
    topRight:SetAlpha(0.92)
    shell.topRight = topRight

    local bottomLeft = shell:CreateTexture(nil, "OVERLAY")
    bottomLeft:SetPoint("BOTTOMLEFT", shell, "BOTTOMLEFT", 0, 0)
    bottomLeft:SetPoint("BOTTOMRIGHT", shell, "BOTTOM", 0, 0)
    bottomLeft:SetHeight(106)
    bottomLeft:SetTexture(QUEST_LOG_BOTTOMLEFT_TEXTURE)
    bottomLeft:SetAlpha(0.94)
    shell.bottomLeft = bottomLeft

    local bottomRight = shell:CreateTexture(nil, "OVERLAY")
    bottomRight:SetPoint("BOTTOMLEFT", shell, "BOTTOM", 0, 0)
    bottomRight:SetPoint("BOTTOMRIGHT", shell, "BOTTOMRIGHT", 0, 0)
    bottomRight:SetHeight(106)
    bottomRight:SetTexture(QUEST_LOG_BOTTOMRIGHT_TEXTURE)
    bottomRight:SetAlpha(0.94)
    shell.bottomRight = bottomRight

    local icon = shell:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", shell, "TOPLEFT", 12, -8)
    icon:SetSize(38, 38)
    icon:SetTexture("Interface\\QuestFrame\\UI-QuestLog-BookIcon")
    icon:SetAlpha(0.95)
    shell.icon = icon

    local title = shell:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 6, -2)
    title:SetPoint("RIGHT", shell, "RIGHT", -16, 0)
    title:SetJustifyH("LEFT")
    title:SetTextColor(1.0, 0.88, 0.36)
    title:SetShadowOffset(1, -1)
    title:SetShadowColor(0, 0, 0, 0.8)
    shell.title = title

    local meta = shell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    meta:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    meta:SetPoint("RIGHT", shell, "RIGHT", -16, 0)
    meta:SetJustifyH("LEFT")
    meta:SetTextColor(0.88, 0.80, 0.62)
    shell.meta = meta

    local divider = shell:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(18)
    divider:SetTexture(QUEST_DIVIDER_TEXTURE)
    divider:SetAlpha(0.82)
    shell.divider = divider

    local listFill = shell:CreateTexture(nil, "BACKGROUND")
    listFill:SetTexture(QUEST_LOG_BACKGROUND_TEXTURE)
    listFill:SetAlpha(0.24)
    shell.listFill = listFill

    local detailFill = shell:CreateTexture(nil, "BACKGROUND")
    detailFill:SetTexture(QUEST_BACKGROUND_TEXTURE)
    detailFill:SetTexCoord(0.08, 0.92, 0.06, 0.94)
    detailFill:SetAlpha(0.18)
    shell.detailFill = detailFill

    local rewardFill = shell:CreateTexture(nil, "BACKGROUND")
    rewardFill:SetTexture(QUEST_BACKGROUND_TEXTURE)
    rewardFill:SetTexCoord(0.08, 0.92, 0.06, 0.94)
    rewardFill:SetAlpha(0.16)
    shell.rewardFill = rewardFill

    shell.listChrome = CreateCombinedWorldMapSectionChrome(shell)
    shell.detailChrome = CreateCombinedWorldMapSectionChrome(shell)
    shell.rewardChrome = CreateCombinedWorldMapSectionChrome(shell)

    local detailDivider = shell:CreateTexture(nil, "ARTWORK")
    detailDivider:SetHeight(14)
    detailDivider:SetTexture(QUEST_DIVIDER_TEXTURE)
    detailDivider:SetAlpha(0.64)
    shell.detailDivider = detailDivider

    local rewardDivider = shell:CreateTexture(nil, "ARTWORK")
    rewardDivider:SetHeight(14)
    rewardDivider:SetTexture(QUEST_DIVIDER_TEXTURE)
    rewardDivider:SetAlpha(0.58)
    shell.rewardDivider = rewardDivider

    WorldMapFrame.__dcqosCombinedQuestShell = shell
    return shell
end

local function GetSelectedWorldMapQuestInfo()
    local selectedQuest = GetSelectedWorldMapQuestFrame()
    if not selectedQuest then
        return nil
    end

    local questLogIndex = tonumber(selectedQuest.questLogIndex or selectedQuest.questIndex)
    local info = questLogIndex and GetQuestLogInfo(questLogIndex) or nil
    local questId = tonumber(selectedQuest.questId or (info and info.questId))

    if not info and questId and questId > 0 then
        local resolvedIndex, resolvedInfo = FindQuestLogIndexByQuestId(questId)
        if resolvedInfo then
            questLogIndex = resolvedIndex
            info = resolvedInfo
        end
    end

    if info then
        return info
    end

    local titleFont = GetButtonFontString(selectedQuest)
    local title = titleFont and titleFont.GetText and StripQuestLevelPrefix(titleFont:GetText() or "") or nil
    if title and title ~= "" then
        return {
            title = title,
            questId = questId,
            questLogIndex = questLogIndex,
        }
    end

    return nil
end

local function GetWorldMapQuestCount()
    local numQuests = tonumber(WorldMapFrame and WorldMapFrame.numQuests) or 0
    if numQuests > 0 then
        return numQuests
    end

    if WorldMapQuestScrollChildFrame and type(WorldMapQuestScrollChildFrame.GetChildren) == "function" then
        local total = 0
        local children = { WorldMapQuestScrollChildFrame:GetChildren() }
        for i = 1, #children do
            local child = children[i]
            if child and tonumber(child.questId or child.questID) then
                total = total + 1
            end
        end
        return total
    end

    return 0
end

local function GetCombinedWorldMapRewardHeight()
    local minHeight = COMBINED_WORLD_MAP_LAYOUT.rewardHeight
    local maxHeight = 248
    local scrollChild = WorldMapQuestRewardScrollChildFrame
    if not scrollChild or type(scrollChild.GetHeight) ~= "function" then
        return minHeight
    end

    local contentHeight = math.ceil(scrollChild:GetHeight() or 0)
    if contentHeight <= 0 then
        return minHeight
    end

    local preferredHeight = contentHeight + 18
    if preferredHeight < minHeight then
        return minHeight
    end
    if preferredHeight > maxHeight then
        return maxHeight
    end

    return preferredHeight
end

local function UpdateCombinedWorldMapShell(shell, selectedQuestInfo)
    if not shell then
        return
    end

    local questCount = GetWorldMapQuestCount()
    local titleText = QUESTS_LABEL or "Quest Log"
    local metaText

    if selectedQuestInfo and selectedQuestInfo.title then
        titleText = BuildQuestDisplayTitle(selectedQuestInfo.title, selectedQuestInfo.level)
        titleText = DecorateQuestTitle(titleText, selectedQuestInfo.questId)
        metaText = BuildQuestMeta(selectedQuestInfo)
    end

    if not metaText or metaText == "" then
        if questCount > 0 then
            metaText = string.format("%d quest%s on this map", questCount, questCount == 1 and "" or "s")
        else
            metaText = "Select a quest to view details and rewards."
        end
    end

    shell.title:SetText(titleText or (QUESTS_LABEL or "Quest Log"))
    shell.meta:SetText(metaText)

    shell.divider:ClearAllPoints()
    shell.divider:SetPoint("TOPLEFT", shell, "TOPLEFT", 12, -(COMBINED_WORLD_MAP_LAYOUT.headerHeight + 2))
    shell.divider:SetPoint("TOPRIGHT", shell, "TOPRIGHT", -12, -(COMBINED_WORLD_MAP_LAYOUT.headerHeight + 2))
end

local function UpdateCombinedWorldMapShellSections(shell, hasSelection)
    if not shell or not WorldMapQuestScrollFrame then
        return
    end

    local selectedQuestInfo = hasSelection
    if selectedQuestInfo == true then
        selectedQuestInfo = GetSelectedWorldMapQuestInfo()
    end

    local hasSelectedQuest = selectedQuestInfo and true or false
    local detailR, detailG, detailB = 0.90, 0.72, 0.28
    if selectedQuestInfo then
        if selectedQuestInfo.isComplete then
            detailR, detailG, detailB = 0.56, 0.82, 0.40
        elseif IsQuestTracked(selectedQuestInfo) then
            detailR, detailG, detailB = 0.95, 0.78, 0.26
        end
    end

    local inset = COMBINED_WORLD_MAP_LAYOUT.panelShadeInset

    shell.listFill:ClearAllPoints()
    shell.listFill:SetPoint("TOPLEFT", WorldMapQuestScrollFrame, "TOPLEFT", -inset, inset)
    shell.listFill:SetPoint("BOTTOMRIGHT", WorldMapQuestScrollFrame, "BOTTOMRIGHT", inset, -inset)
    shell.listFill:Show()
    UpdateCombinedWorldMapSectionChrome(shell.listChrome, WorldMapQuestScrollFrame, true, 0.70, 0.58, 0.28, false)

    if hasSelectedQuest and WorldMapQuestDetailScrollFrame and WorldMapQuestRewardScrollFrame then
        shell.detailFill:ClearAllPoints()
        shell.detailFill:SetPoint("TOPLEFT", WorldMapQuestDetailScrollFrame, "TOPLEFT", -inset, inset)
        shell.detailFill:SetPoint("BOTTOMRIGHT", WorldMapQuestDetailScrollFrame, "BOTTOMRIGHT", inset, -inset)
        shell.detailFill:Show()
        UpdateCombinedWorldMapSectionChrome(shell.detailChrome, WorldMapQuestDetailScrollFrame, true, detailR, detailG, detailB, true)

        shell.rewardFill:ClearAllPoints()
        shell.rewardFill:SetPoint("TOPLEFT", WorldMapQuestRewardScrollFrame, "TOPLEFT", -inset, inset)
        shell.rewardFill:SetPoint("BOTTOMRIGHT", WorldMapQuestRewardScrollFrame, "BOTTOMRIGHT", inset, -inset)
        shell.rewardFill:Show()
        UpdateCombinedWorldMapSectionChrome(shell.rewardChrome, WorldMapQuestRewardScrollFrame, true, detailR, detailG, detailB, false)

        shell.detailDivider:ClearAllPoints()
        shell.detailDivider:SetPoint("BOTTOMLEFT", WorldMapQuestDetailScrollFrame, "TOPLEFT", 0, 4)
        shell.detailDivider:SetPoint("BOTTOMRIGHT", WorldMapQuestDetailScrollFrame, "TOPRIGHT", 0, 4)
        shell.detailDivider:Show()

        shell.rewardDivider:ClearAllPoints()
        shell.rewardDivider:SetPoint("BOTTOMLEFT", WorldMapQuestRewardScrollFrame, "TOPLEFT", 0, 4)
        shell.rewardDivider:SetPoint("BOTTOMRIGHT", WorldMapQuestRewardScrollFrame, "TOPRIGHT", 0, 4)
        shell.rewardDivider:Show()
    else
        shell.detailFill:Hide()
        shell.rewardFill:Hide()
        shell.detailDivider:Hide()
        shell.rewardDivider:Hide()
        UpdateCombinedWorldMapSectionChrome(shell.detailChrome, nil, false, 0, 0, 0, false)
        UpdateCombinedWorldMapSectionChrome(shell.rewardChrome, nil, false, 0, 0, 0, false)
    end
end

GetSelectedWorldMapQuestFrame = function()
    if WorldMapQuestScrollChildFrame and WorldMapQuestScrollChildFrame.selected then
        return WorldMapQuestScrollChildFrame.selected
    end

    if WORLDMAP_SETTINGS then
        return WORLDMAP_SETTINGS.selectedQuest
    end

    return nil
end

local function ShouldApplyCombinedWorldMapLayout()
    -- Interface.lua now owns world map geometry and pane layout. Keep QuestFrames
    -- focused on styling text/buttons to avoid conflicting re-anchors.
    return false
end

local function EnsureCombinedWorldMapObjectiveDisplay()
    local changed = false

    if WatchFrame and WatchFrame.showObjectives == false then
        WatchFrame.showObjectives = true
        changed = true
    end

    if WorldMapQuestShowObjectives and type(WorldMapQuestShowObjectives.GetChecked) == "function"
        and type(WorldMapQuestShowObjectives.SetChecked) == "function"
        and not WorldMapQuestShowObjectives:GetChecked() then
        WorldMapQuestShowObjectives:SetChecked(true)
        changed = true
    end

    if changed and type(WorldMapQuestShowObjectives_Toggle) == "function" then
        pcall(WorldMapQuestShowObjectives_Toggle)
    end
end

local function EnsureCombinedWorldMapQuestView()
    local questListScale = tonumber(WORLDMAP_QUESTLIST_SIZE) or 1

    EnsureCombinedWorldMapObjectiveDisplay()

    if type(WorldMapFrame_SetQuestMapView) == "function" then
        pcall(WorldMapFrame_SetQuestMapView)
    end

    if WORLDMAP_SETTINGS then
        WORLDMAP_SETTINGS.size = questListScale
    end
end

local function EnforceCombinedWorldMapWindowGeometry()
    if not WorldMapFrame then
        return
    end

    if WorldMapFrame.SetScale then
        WorldMapFrame:SetScale(1)
    end
    if WorldMapFrame.SetWidth then
        WorldMapFrame:SetWidth(COMBINED_WORLD_MAP_FRAME_WIDTH)
    end
    if WorldMapFrame.SetHeight then
        WorldMapFrame:SetHeight(COMBINED_WORLD_MAP_FRAME_HEIGHT)
    end

    if WorldMapPositioningGuide
        and WorldMapPositioningGuide.ClearAllPoints
        and WorldMapPositioningGuide.SetAllPoints then
        WorldMapPositioningGuide:ClearAllPoints()
        WorldMapPositioningGuide:SetAllPoints(WorldMapFrame)
    end

    if not WorldMapFrame.__dcqosCombinedMapPlaced
        and WorldMapFrame.ClearAllPoints
        and WorldMapFrame.SetPoint then
        WorldMapFrame:ClearAllPoints()
        WorldMapFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        WorldMapFrame.__dcqosCombinedMapPlaced = true
    end
end

local function CloseStandaloneQuestLogPanelsForCombinedMap()
    if not ShouldApplyCombinedWorldMapLayout() then
        return
    end

    for _, frame in ipairs({ QuestLogDetailFrame, QuestLogFrame }) do
        if frame and frame.IsShown and frame:IsShown() then
            if type(HideUIPanel) == "function" then
                pcall(HideUIPanel, frame)
            else
                frame:Hide()
            end
        end
    end
end

local function ApplyCombinedWorldMapLayout()
    local shell = WorldMapFrame and WorldMapFrame.__dcqosCombinedQuestShell or nil
    if not ShouldApplyCombinedWorldMapLayout() then
        if shell then
            shell:Hide()
        end
        return
    end

    if not WorldMapPositioningGuide
        or not WorldMapQuestScrollFrame
        or not WorldMapQuestDetailScrollFrame
        or not WorldMapQuestRewardScrollFrame
        or not WorldMapTrackQuest then
        return
    end

    shell = EnsureCombinedWorldMapShell()
    if not shell then
        return
    end

    CloseStandaloneQuestLogPanelsForCombinedMap()

    local selectedQuest = GetSelectedWorldMapQuestFrame()
    local hasSelectedQuest = selectedQuest and true or false
    local selectedQuestInfo = GetSelectedWorldMapQuestInfo()
    local objectiveQuestLogIndex = selectedQuestInfo and tonumber(selectedQuestInfo.questLogIndex) or nil

    if (not objectiveQuestLogIndex or objectiveQuestLogIndex <= 0)
        and type(GetQuestLogSelection) == "function" then
        local selectedLogIndex = tonumber(GetQuestLogSelection())
        if selectedLogIndex and selectedLogIndex > 0 then
            objectiveQuestLogIndex = selectedLogIndex
        end
    end

    state.worldMapLayoutApplying = true
    state.worldMapLayoutApplyingAt = GetTime and GetTime() or 0

    EnsureCombinedWorldMapQuestView()
    EnforceCombinedWorldMapWindowGeometry()

    if addon and addon.DelayedCall then
        addon:DelayedCall(0, function()
            EnsureCombinedWorldMapQuestView()
            EnforceCombinedWorldMapWindowGeometry()
        end)
        addon:DelayedCall(0.05, function()
            EnsureCombinedWorldMapQuestView()
            EnforceCombinedWorldMapWindowGeometry()
        end)
        addon:DelayedCall(0.15, function()
            EnsureCombinedWorldMapQuestView()
            EnforceCombinedWorldMapWindowGeometry()
        end)
    end

    local blobScale = tonumber(WORLDMAP_SETTINGS and WORLDMAP_SETTINGS.size)
        or tonumber(WORLDMAP_QUESTLIST_SIZE)
        or tonumber(WORLDMAP_FULLMAP_SIZE)
        or 1
    if WorldMapBlobFrame and blobScale then
        WorldMapBlobFrame:SetScale(blobScale)
        WorldMapBlobFrame.xRatio = nil
        if type(WorldMapBlobFrame_CalculateHitTranslations) == "function" then
            pcall(WorldMapBlobFrame_CalculateHitTranslations)
        end
    end

    if type(WorldMapFrame_SetPOIMaxBounds) == "function" then
        pcall(WorldMapFrame_SetPOIMaxBounds)
    end
    if type(WorldMapFrame_UpdateQuests) == "function" then
        pcall(WorldMapFrame_UpdateQuests)
    end

    local guideHeight = WorldMapPositioningGuide.GetHeight and WorldMapPositioningGuide:GetHeight() or nil
    if not guideHeight or guideHeight <= 0 then
        guideHeight = (WorldMapFrame and WorldMapFrame.GetHeight and WorldMapFrame:GetHeight()) or 768
    end

    local shellHeight = math.max(
        guideHeight - COMBINED_WORLD_MAP_LAYOUT.topInset - COMBINED_WORLD_MAP_LAYOUT.bottomInset,
        COMBINED_WORLD_MAP_LAYOUT.minShellHeight
    )
    local contentHeight = shellHeight
        - COMBINED_WORLD_MAP_LAYOUT.headerHeight
        - COMBINED_WORLD_MAP_LAYOUT.headerGap
        - COMBINED_WORLD_MAP_LAYOUT.contentBottomInset
    local contentWidth = COMBINED_WORLD_MAP_LAYOUT.shellWidth - (COMBINED_WORLD_MAP_LAYOUT.panelInset * 2)

    local listHeight = contentHeight
    local detailHeight = 0
    local rewardHeight = 0

    if hasSelectedQuest then
        rewardHeight = GetCombinedWorldMapRewardHeight()
        local dynamicHeight = contentHeight
            - rewardHeight
            - COMBINED_WORLD_MAP_LAYOUT.trackButtonHeight
            - (COMBINED_WORLD_MAP_LAYOUT.panelGap * 3)

        listHeight = math.max(
            COMBINED_WORLD_MAP_LAYOUT.minListHeight,
            math.floor(dynamicHeight * COMBINED_WORLD_MAP_LAYOUT.listRatio)
        )
        detailHeight = math.max(
            COMBINED_WORLD_MAP_LAYOUT.minDetailHeight,
            dynamicHeight - listHeight
        )

        local overflow = (listHeight + detailHeight) - dynamicHeight
        if overflow > 0 then
            listHeight = math.max(COMBINED_WORLD_MAP_LAYOUT.minListHeight, listHeight - overflow)
            detailHeight = math.max(COMBINED_WORLD_MAP_LAYOUT.minDetailHeight, dynamicHeight - listHeight)
        end
    end

    shell:Show()
    shell:ClearAllPoints()
    shell:SetPoint(
        "TOPRIGHT",
        WorldMapPositioningGuide,
        "TOPRIGHT",
        -COMBINED_WORLD_MAP_LAYOUT.rightInset,
        -COMBINED_WORLD_MAP_LAYOUT.topInset
    )
    shell:SetWidth(COMBINED_WORLD_MAP_LAYOUT.shellWidth)
    shell:SetHeight(shellHeight)

    UpdateCombinedWorldMapShell(shell, selectedQuestInfo)

    WorldMapQuestScrollFrame:Show()
    WorldMapQuestScrollFrame:ClearAllPoints()
    WorldMapQuestScrollFrame:SetPoint(
        "TOPLEFT",
        shell,
        "TOPLEFT",
        COMBINED_WORLD_MAP_LAYOUT.panelInset,
        -(COMBINED_WORLD_MAP_LAYOUT.headerHeight + COMBINED_WORLD_MAP_LAYOUT.headerGap)
    )
    WorldMapQuestScrollFrame:SetWidth(contentWidth)
    WorldMapQuestScrollFrame:SetHeight(listHeight)

    if WorldMapQuestScrollChildFrame and WorldMapQuestScrollChildFrame.SetWidth then
        WorldMapQuestScrollChildFrame:SetWidth(contentWidth - 20)
    end
    if WorldMapQuestDetailScrollChildFrame and WorldMapQuestDetailScrollChildFrame.SetWidth then
        WorldMapQuestDetailScrollChildFrame:SetWidth(contentWidth - 20)
    end
    if WorldMapQuestRewardScrollChildFrame and WorldMapQuestRewardScrollChildFrame.SetWidth then
        WorldMapQuestRewardScrollChildFrame:SetWidth(contentWidth - 20)
    end

    if hasSelectedQuest then
        WorldMapQuestDetailScrollFrame:Show()
        WorldMapQuestDetailScrollFrame:ClearAllPoints()
        WorldMapQuestDetailScrollFrame:SetPoint(
            "TOPLEFT",
            WorldMapQuestScrollFrame,
            "BOTTOMLEFT",
            0,
            -COMBINED_WORLD_MAP_LAYOUT.panelGap
        )
        WorldMapQuestDetailScrollFrame:SetWidth(contentWidth)
        WorldMapQuestDetailScrollFrame:SetHeight(detailHeight)

        WorldMapQuestRewardScrollFrame:Show()
        WorldMapQuestRewardScrollFrame:ClearAllPoints()
        WorldMapQuestRewardScrollFrame:SetPoint(
            "TOPLEFT",
            WorldMapQuestDetailScrollFrame,
            "BOTTOMLEFT",
            0,
            -COMBINED_WORLD_MAP_LAYOUT.panelGap
        )
        WorldMapQuestRewardScrollFrame:SetWidth(contentWidth)
        WorldMapQuestRewardScrollFrame:SetHeight(rewardHeight)

        WorldMapTrackQuest:Show()
        WorldMapTrackQuest:ClearAllPoints()
        WorldMapTrackQuest:SetPoint("TOPLEFT", WorldMapQuestRewardScrollFrame, "BOTTOMLEFT", 2, -COMBINED_WORLD_MAP_LAYOUT.panelGap)
    else
        WorldMapQuestDetailScrollFrame:Hide()
        WorldMapQuestRewardScrollFrame:Hide()
        WorldMapTrackQuest:Hide()
    end

    UpdateCombinedWorldMapShellSections(shell, selectedQuestInfo)

    if objectiveQuestLogIndex and objectiveQuestLogIndex > 0 then
        local now = GetTime and GetTime() or 0
        local isSameObjective = state.lastWorldMapObjectiveQuestLogIndex == objectiveQuestLogIndex
        local lastRefreshAt = state.lastWorldMapObjectiveRefreshAt or 0
        local shouldRefreshObjective = (not isSameObjective) or ((now - lastRefreshAt) > 0.25)

        if shouldRefreshObjective and type(WorldMapQuestShowObjectives) == "function" then
            state.lastWorldMapObjectiveQuestLogIndex = objectiveQuestLogIndex
            state.lastWorldMapObjectiveRefreshAt = now
            pcall(WorldMapQuestShowObjectives, objectiveQuestLogIndex)
            if addon and addon.DelayedCall then
                addon:DelayedCall(0, function()
                    pcall(WorldMapQuestShowObjectives, objectiveQuestLogIndex)
                end)
                addon:DelayedCall(0.05, function()
                    pcall(WorldMapQuestShowObjectives, objectiveQuestLogIndex)
                end)
            end
        end
    else
        state.lastWorldMapObjectiveQuestLogIndex = nil
        state.lastWorldMapObjectiveRefreshAt = nil
    end

    state.worldMapLayoutApplying = false
    state.worldMapLayoutApplyingAt = nil
end

local function InstallWorldMapHooks()
    if state.worldMapHooksInstalled then
        return
    end
    if type(hooksecurefunc) ~= "function" then
        return
    end

    local function RequestRefresh()
        if state.worldMapLayoutApplying then
            local startedAt = state.worldMapLayoutApplyingAt or 0
            local now = GetTime and GetTime() or 0
            if (now - startedAt) < 1.0 then
                return
            end

            state.worldMapLayoutApplying = false
            state.worldMapLayoutApplyingAt = nil
        end

        CloseStandaloneQuestLogPanelsForCombinedMap()

        local now = (type(GetTime) == "function" and GetTime()) or 0
        if (now - (state.lastWorldMapRefreshRequestAt or 0)) < 0.08 then
            return
        end

        state.lastWorldMapRefreshRequestAt = now
        QueueSharedWorldMapRefreshCycle(function()
            QueueRefresh(0.02)
            QueueRefresh(0.08)
        end)
    end

    local hookNames = {
        "WorldMapFrame_DisplayQuests",
        "WorldMapFrame_DisplayQuestPOI",
        "WorldMapFrame_UpdateQuests",
        "WorldMapFrame_SelectQuestFrame",
    }

    for _, name in ipairs(hookNames) do
        if type(_G[name]) == "function" then
            hooksecurefunc(name, RequestRefresh)
        end
    end

    if WorldMapFrame and type(WorldMapFrame.HookScript) == "function" then
        WorldMapFrame:HookScript("OnShow", RequestRefresh)
    end
    if WorldMapFrameSizeUpButton and type(WorldMapFrameSizeUpButton.HookScript) == "function" then
        WorldMapFrameSizeUpButton:HookScript("OnClick", RequestRefresh)
    end
    if WorldMapFrameSizeDownButton and type(WorldMapFrameSizeDownButton.HookScript) == "function" then
        WorldMapFrameSizeDownButton:HookScript("OnClick", RequestRefresh)
    end
    if WorldMapQuestShowObjectives and type(WorldMapQuestShowObjectives.HookScript) == "function" then
        WorldMapQuestShowObjectives:HookScript("OnClick", RequestRefresh)
    end

    state.worldMapHooksInstalled = true
end

local function ApplyFontStyleRecursive(root, depth, titlePattern)
    if not root or depth > 4 then
        return
    end

    if root.GetObjectType and root:GetObjectType() == "FontString" then
        local text = root.GetText and root:GetText() or nil
        if type(text) == "string" and text ~= "" then
            if titlePattern and titlePattern(text) then
                ApplyFontStyle(root, 12, 1, 1.0, 0.86, 0.28)
            else
                ApplyFontStyle(root, 11, 1, 0.96, 0.90, 0.76)
            end
        end
    end

    if type(root.GetRegions) == "function" then
        local regions = { root:GetRegions() }
        for i = 1, #regions do
            ApplyFontStyleRecursive(regions[i], depth + 1, titlePattern)
        end
    end

    if type(root.GetChildren) == "function" then
        local children = { root:GetChildren() }
        for i = 1, #children do
            ApplyFontStyleRecursive(children[i], depth + 1, titlePattern)
        end
    end
end

local function UpdateMovableFrames()
    local questLogHandle = EnsureMovableFrame(QuestLogFrame)
    if questLogHandle then
        SetFrameShown(questLogHandle, QuestLogFrame and QuestLogFrame.IsShown and QuestLogFrame:IsShown())
    end

    for _, frameName in ipairs(ROOT_FRAME_NAMES) do
        local frame = _G[frameName]
        local handle = EnsureMovableFrame(frame)
        if handle then
            SetFrameShown(handle, frame and frame.IsShown and frame:IsShown())
        end
    end
end

local function GetQuestRowIconRegion(button)
    if not button or not button.__dcqosQuestRow then
        return nil
    end

    local kind = button.__dcqosQuestRow.kind
    local buttonName = button.GetName and button:GetName() or nil
    if kind == "greeting" then
        return button.QuestIcon or (buttonName and _G[buttonName .. "QuestIcon"]) or nil
    end

    return button.check or (buttonName and _G[buttonName .. "Check"]) or nil
end

local function GetGreetingQuestButtonInfo(button)
    if not button then
        return nil
    end

    local questIndex = tonumber(button:GetID())
    if not questIndex or questIndex <= 0 then
        return nil
    end

    local isActive = button.isActive == 1
    local title
    if isActive and type(GetActiveTitle) == "function" then
        title = GetActiveTitle(questIndex)
    elseif not isActive and type(GetAvailableTitle) == "function" then
        title = GetAvailableTitle(questIndex)
    end

    if not title or title == "" then
        local fontString = GetButtonFontString(button)
        title = fontString and fontString.GetText and fontString:GetText() or nil
        title = StripQuestLevelPrefix(title)
    end

    if not title or title == "" then
        return nil
    end

    local questLogIndex, info = FindQuestLogInfoByTitle(title)
    local recurrenceType = info and info.recurrenceType or GetRecurringQuestType(nil, title)
    local isWeekly = info and info.isWeekly or recurrenceType == "weekly"
    local isRecurring = info and info.isRecurring or recurrenceType == "daily" or isWeekly

    return {
        title = title,
        isActive = isActive,
        isComplete = info and info.isComplete or false,
        isRecurring = isRecurring,
        recurrenceType = recurrenceType,
        questLogIndex = questLogIndex,
        questId = info and info.questId or nil,
    }
end

local function EnsureQuestRowButton(button, highlightTexture, kind)
    if not button then
        return
    end

    if button.__dcqosQuestRow == nil then
        button.__dcqosQuestRow = { kind = kind }

        local fontString = GetButtonFontString(button)

        local highlight = button:CreateTexture(nil, "BACKGROUND")
        highlight:SetTexture(highlightTexture)
        highlight:SetBlendMode("ADD")
        highlight:SetAlpha(0)
        if fontString then
            highlight:SetPoint("TOPLEFT", fontString, "TOPLEFT", -16, 6)
            highlight:SetPoint("BOTTOMRIGHT", fontString, "BOTTOMRIGHT", 18, -6)
        else
            highlight:SetAllPoints(button)
        end
        button.__dcqosQuestRowHighlight = highlight

        local accent = button:CreateTexture(nil, "ARTWORK")
        accent:SetTexture("Interface\\Buttons\\WHITE8x8")
        if fontString then
            accent:SetPoint("TOPLEFT", fontString, "TOPLEFT", -10, 2)
            accent:SetPoint("BOTTOMLEFT", fontString, "BOTTOMLEFT", -10, -2)
        else
            accent:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -4)
            accent:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 4, 4)
        end
        accent:SetWidth(3)
        accent:SetVertexColor(0.95, 0.78, 0.26, 1)
        accent:SetAlpha(0)
        button.__dcqosQuestRowAccent = accent

        if type(button.HookScript) == "function" then
            button:HookScript("OnEnter", function(self)
                QueueRefresh(0)
            end)
            button:HookScript("OnLeave", function(self)
                QueueRefresh(0)
            end)
            button:HookScript("OnShow", function(self)
                QueueRefresh(0)
            end)
        end
    end

    button.__dcqosQuestRow.kind = kind
end

local function UpdateQuestRowButton(button)
    if not button or not button.__dcqosQuestRow then
        return
    end

    local kind = button.__dcqosQuestRow.kind
    local fontString = GetButtonFontString(button)
    local highlight = button.__dcqosQuestRowHighlight
    local accent = button.__dcqosQuestRowAccent

    local selected = false
    local tracked = false
    local completed = false
    local isHeader = false
    local level
    local recurrenceType
    local titleText
    local textVisible = fontString and fontString.GetText and fontString:GetText()
    local greetingInfo

    if kind == "log" then
        local questLogIndex = tonumber(button:GetID())
        if questLogIndex and questLogIndex > 0 and type(GetQuestLogTitle) == "function" then
            local title, levelValue, _, _, headerFlag, _, completeFlag = GetQuestLogTitle(questLogIndex)
            level = tonumber(levelValue)
            titleText = title
            isHeader = (headerFlag == true or headerFlag == 1)
            completed = (completeFlag == true or completeFlag == 1)
            selected = not isHeader and type(GetQuestLogSelection) == "function" and tonumber(GetQuestLogSelection()) == questLogIndex
            if not isHeader then
                local info = GetQuestLogInfo(questLogIndex)
                tracked = info and IsQuestTracked(info) or false
                recurrenceType = info and info.recurrenceType or nil
            end
            if not textVisible or textVisible == "" then
                textVisible = title
            end
        end
    else
        greetingInfo = GetGreetingQuestButtonInfo(button)
        if greetingInfo then
            titleText = greetingInfo.title or titleText
            completed = greetingInfo.isComplete
            recurrenceType = greetingInfo.recurrenceType
        end
        tracked = false
    end

    local hover = type(button.IsMouseOver) == "function" and button:IsMouseOver() or false
    local alpha = 0
    if selected then
        alpha = 0.88
    elseif tracked then
        alpha = 0.45
    elseif hover then
        alpha = 0.30
    end

    if highlight then
        highlight:SetAlpha((textVisible and textVisible ~= "") and alpha or 0)
    end

    if accent then
        accent:SetAlpha((selected or tracked) and 1 or 0)
    end

    local icon = GetQuestRowIconRegion(button)
    if icon and icon.SetTexture then
        local texturePath
        if kind == "log" then
            if not isHeader and textVisible and textVisible ~= "" then
                if recurrenceType then
                    texturePath = QUEST_DAILY_ACTIVE_ICON_TEXTURE
                elseif completed then
                    texturePath = QUEST_ACTIVE_ICON_TEXTURE
                else
                    texturePath = QUEST_INCOMPLETE_ICON_TEXTURE
                end
            end
        elseif greetingInfo then
            if greetingInfo.isActive then
                if greetingInfo.isRecurring then
                    texturePath = QUEST_DAILY_ACTIVE_ICON_TEXTURE
                elseif greetingInfo.isComplete then
                    texturePath = QUEST_ACTIVE_ICON_TEXTURE
                else
                    texturePath = QUEST_INCOMPLETE_ICON_TEXTURE
                end
            else
                texturePath = greetingInfo.isRecurring and QUEST_DAILY_ICON_TEXTURE or QUEST_AVAILABLE_ICON_TEXTURE
            end
        end

        if texturePath then
            icon:SetTexture(texturePath)
            if icon.SetTexCoord then
                icon:SetTexCoord(0, 1, 0, 1)
            end
            if icon.SetVertexColor then
                icon:SetVertexColor(1, 1, 1, 1)
            end
            if icon.Show then
                icon:Show()
            end
        elseif icon.Hide then
            icon:Hide()
        end
    end

    if fontString then
        if kind == "log" and not isHeader then
            local displayText = BuildQuestDisplayTitle(textVisible or titleText or "", level)
            if displayText and displayText ~= "" and fontString:GetText() ~= displayText then
                fontString:SetText(displayText)
                textVisible = displayText
            end
        end

        if isHeader then
            ApplyFontStyle(fontString, 11, 1, 0.94, 0.80, 0.32)
        elseif selected then
            ApplyFontStyle(fontString, 11, 1, 1.00, 0.90, 0.42)
        elseif tracked then
            ApplyFontStyle(fontString, 11, 1, 0.98, 0.92, 0.66)
        elseif completed then
            ApplyFontStyle(fontString, 11, 1, 0.74, 0.88, 0.60)
        else
            ApplyFontStyle(fontString, 11, 1, 0.92, 0.84, 0.60)
        end
    end
end

local function EnsureWorldMapQuestRowChrome(button)
    local markers = addon and addon.QuestTrackerMarkers or nil
    if not markers or type(markers.EnsureWorldMapQuestRowChrome) ~= "function" then
        return nil
    end

    return markers.EnsureWorldMapQuestRowChrome(button, {
        getTitleFontString = GetButtonFontString,
        setHoverQuestId = SetWorldMapHoverQuestId,
        getHoverQuestId = function()
            return state.worldMapHoverQuestId
        end,
        queueRefresh = QueueRefresh,
    })
end

local function EnsureWorldMapQuestPoiChrome(button)
    local markers = addon and addon.QuestTrackerMarkers or nil
    if not markers or type(markers.EnsureWorldMapQuestPoiChrome) ~= "function" then
        return nil
    end

    return markers.EnsureWorldMapQuestPoiChrome(button, {
        setHoverQuestId = SetWorldMapHoverQuestId,
        getHoverQuestId = function()
            return state.worldMapHoverQuestId
        end,
        selectQuest = function(ownerButton)
            if not ownerButton then
                return
            end

            local questLogIndex = tonumber(ownerButton.questLogIndex or ownerButton.questIndex)
            local questId = tonumber(ownerButton.questId or ownerButton.questID)

            if (not questLogIndex or questLogIndex <= 0) and questId and questId > 0 then
                questLogIndex = FindQuestLogIndexByQuestId(questId)
            end

            if questLogIndex and questLogIndex > 0 and type(QuestLog_SetSelection) == "function" then
                pcall(QuestLog_SetSelection, questLogIndex)
            end

            if type(WorldMapFrame_SelectQuestFrame) == "function" then
                pcall(WorldMapFrame_SelectQuestFrame, ownerButton)
            end

            QueueRefresh(0)
        end,
    })
end

local function UpdateWorldMapQuestPoi(button, isTracked, isSelected, isWatched, isComplete, isHover, isDaily)
    local markers = addon and addon.QuestTrackerMarkers or nil
    if not markers or type(markers.UpdateWorldMapQuestPoi) ~= "function" then
        return
    end

    markers.UpdateWorldMapQuestPoi(button, {
        isTracked = isTracked,
        isSelected = isSelected,
        isWatched = isWatched,
        isComplete = isComplete,
        isHover = isHover,
        isDaily = isDaily,
        setHoverQuestId = SetWorldMapHoverQuestId,
        getHoverQuestId = function()
            return state.worldMapHoverQuestId
        end,
        selectQuest = function(ownerButton)
            if not ownerButton then
                return
            end

            local questLogIndex = tonumber(ownerButton.questLogIndex or ownerButton.questIndex)
            local questId = tonumber(ownerButton.questId or ownerButton.questID)

            if (not questLogIndex or questLogIndex <= 0) and questId and questId > 0 then
                questLogIndex = FindQuestLogIndexByQuestId(questId)
            end

            if questLogIndex and questLogIndex > 0 and type(QuestLog_SetSelection) == "function" then
                pcall(QuestLog_SetSelection, questLogIndex)
            end

            if type(WorldMapFrame_SelectQuestFrame) == "function" then
                pcall(WorldMapFrame_SelectQuestFrame, ownerButton)
            end

            QueueRefresh(0)
        end,
        resolveTextureRegion = ResolveTextureRegion,
    })
end

local function UpdateWorldMapQuestBlobState(selectedQuestId, hoveredQuestId, trackedQuestId)
    if not WorldMapBlobFrame or type(WorldMapBlobFrame.DrawQuestBlob) ~= "function" then
        return
    end

    local primaryQuestId = hoveredQuestId or selectedQuestId or trackedQuestId
    if (not primaryQuestId or primaryQuestId <= 0) and type(GetQuestLogSelection) == "function" then
        local selectedQuestLogIndex = tonumber(GetQuestLogSelection())
        if selectedQuestLogIndex and selectedQuestLogIndex > 0 then
            primaryQuestId = GetQuestIdFromLogIndex(selectedQuestLogIndex)
        end
    end

    if not primaryQuestId or primaryQuestId <= 0 then
        return
    end

    if selectedQuestId and selectedQuestId > 0 and selectedQuestId ~= primaryQuestId then
        pcall(WorldMapBlobFrame.DrawQuestBlob, WorldMapBlobFrame, selectedQuestId, true)
    end

    if trackedQuestId and trackedQuestId > 0 and trackedQuestId ~= primaryQuestId and trackedQuestId ~= selectedQuestId then
        pcall(WorldMapBlobFrame.DrawQuestBlob, WorldMapBlobFrame, trackedQuestId, true)
    end

    local emphasizePrimary = (hoveredQuestId == primaryQuestId)
        or (selectedQuestId == primaryQuestId)
        or (trackedQuestId == primaryQuestId)

    pcall(WorldMapBlobFrame.DrawQuestBlob, WorldMapBlobFrame, primaryQuestId, emphasizePrimary)
end

local function IsWorldMapQuestSectionHeaderText(text)
    if type(text) ~= "string" then
        return false
    end

    local trimmed = text:gsub("^%s+", ""):gsub("%s+$", "")
    if trimmed == "" then
        return false
    end

    local lowered = string.lower(trimmed)
    if lowered == "description" or lowered == "objectives" or lowered == "rewards" or lowered == "experience:" then
        return true
    end

    return trimmed:find(":$") ~= nil and trimmed:find("^%d") == nil
end

local function StyleWorldMapQuestDetailTextRecursive(root, depth, selectedTitle, isTracked, isComplete)
    if not root or depth > 4 then
        return
    end

    local titleR, titleG, titleB = 0.98, 0.90, 0.52
    local sectionR, sectionG, sectionB = 0.92, 0.78, 0.30
    local bodyR, bodyG, bodyB = 0.94, 0.88, 0.74
    local objectiveR, objectiveG, objectiveB = 0.96, 0.92, 0.80

    if isTracked then
        titleR, titleG, titleB = 1.0, 0.90, 0.42
        sectionR, sectionG, sectionB = 0.96, 0.82, 0.34
    elseif isComplete then
        titleR, titleG, titleB = 0.74, 0.88, 0.60
        sectionR, sectionG, sectionB = 0.72, 0.86, 0.58
        objectiveR, objectiveG, objectiveB = 0.80, 0.90, 0.76
    end

    if root.GetObjectType and root:GetObjectType() == "FontString" then
        local text = root.GetText and root:GetText() or nil
        if type(text) == "string" and text ~= "" then
            local strippedText = StripQuestLevelPrefix(text)
            if selectedTitle and strippedText == StripQuestLevelPrefix(selectedTitle) then
                ApplyFontStyle(root, 11, 1, titleR, titleG, titleB)
            elseif text:find("^%s*[%-%d]", 1) or text:find("^%s*%d+/%d+") then
                ApplyFontStyle(root, 10, 1, objectiveR, objectiveG, objectiveB)
            elseif IsWorldMapQuestSectionHeaderText(text) then
                ApplyFontStyle(root, 10, 1, sectionR, sectionG, sectionB)
            else
                ApplyFontStyle(root, 10, 1, bodyR, bodyG, bodyB)
            end
        end
    end

    if type(root.GetRegions) == "function" then
        local regions = { root:GetRegions() }
        for i = 1, #regions do
            StyleWorldMapQuestDetailTextRecursive(regions[i], depth + 1, selectedTitle, isTracked, isComplete)
        end
    end

    if type(root.GetChildren) == "function" then
        local children = { root:GetChildren() }
        for i = 1, #children do
            StyleWorldMapQuestDetailTextRecursive(children[i], depth + 1, selectedTitle, isTracked, isComplete)
        end
    end
end

local function StyleWorldMapQuestRows()
    local scrollChild = WorldMapQuestScrollChildFrame
    if not scrollChild or type(scrollChild.GetChildren) ~= "function" then
        return
    end

    local trackedQuestId = GetSuperTrackedQuestId()
    local hoveredQuestId = state.worldMapHoverQuestId
    local selectedQuest = GetSelectedWorldMapQuestFrame()
    local selectedQuestId = tonumber(selectedQuest and (selectedQuest.questId or selectedQuest.questID) or nil)
    local children = { scrollChild:GetChildren() }
    local entries = {}

    for i = 1, #children do
        local child = children[i]
        local questId = child and (child.questId or child.questID) or nil
        questId = tonumber(questId)
        if questId and questId > 0 then
            local questLogIndex, info = FindQuestLogIndexByQuestId(questId)
            table.insert(entries, {
                button = child,
                questId = questId,
                questLogIndex = questLogIndex,
                info = info,
                title = info and info.title or nil,
                level = info and info.level or nil,
            })
        end
    end

    for i = 1, #entries do
        local entry = entries[i]
        local child = entry.button
        local questId = entry.questId
        local questLogIndex = entry.questLogIndex
        local info = entry.info
        local title = entry.title
        local level = entry.level
        local isDaily = info and info.isDaily or false
        local isComplete = info and info.isComplete or false
        local isWatched = info and IsQuestTracked(info) or false
        local isTracked = trackedQuestId and trackedQuestId == questId or false
        local isSelected = child == selectedQuest
        local isHover = hoveredQuestId == questId
            or (type(child.IsMouseOver) == "function" and child:IsMouseOver() or false)
            or (child.poiIcon and type(child.poiIcon.IsMouseOver) == "function" and child.poiIcon:IsMouseOver() or false)
        local fontStrings = GetButtonFontStrings(child)
        local rowChrome = EnsureWorldMapQuestRowChrome(child)

        child.questId = questId
        child.questID = questId
        child.questLogIndex = questLogIndex
        child.questIndex = questLogIndex
        if child.poiIcon then
            child.poiIcon.questId = questId
            child.poiIcon.questID = questId
            child.poiIcon.questLogIndex = questLogIndex
            child.poiIcon.questIndex = questLogIndex
        end

        if rowChrome then
            local borderR, borderG, borderB, borderA = 0.28, 0.20, 0.10, 0.22
            local bgAlpha = 0.58
            local accentR, accentG, accentB, accentA = 0.72, 0.58, 0.28, 0.18
            local boxR, boxG, boxB, boxA = 0.72, 0.66, 0.50, 0.92
            local checkR, checkG, checkB, checkA = 0.90, 0.82, 0.48, 0
            local iconR, iconG, iconB, iconA = 0.92, 0.82, 0.46, 0.36
            local dotAlpha = 0
            local glowAlpha = 0
            local pulseAlpha = 0

            if isDaily then
                borderR, borderG, borderB, borderA = 0.28, 0.52, 0.86, 0.38
                accentR, accentG, accentB, accentA = 0.34, 0.68, 1.0, 0.32
                boxR, boxG, boxB, boxA = 0.42, 0.72, 1.0, 0.90
                checkR, checkG, checkB, checkA = 0.58, 0.84, 1.0, 0
                iconR, iconG, iconB, iconA = 0.54, 0.80, 1.0, 0.58
            end

            if isTracked then
                if isDaily then
                    borderR, borderG, borderB, borderA = 0.36, 0.70, 1.0, 0.88
                    accentR, accentG, accentB, accentA = 0.42, 0.76, 1.0, 1
                    boxR, boxG, boxB, boxA = 0.50, 0.80, 1.0, 1
                    checkR, checkG, checkB, checkA = 0.70, 0.90, 1.0, 1
                    iconR, iconG, iconB, iconA = 0.70, 0.90, 1.0, 1
                else
                    borderR, borderG, borderB, borderA = 0.95, 0.78, 0.26, 0.82
                    accentR, accentG, accentB, accentA = 0.95, 0.78, 0.26, 1
                    boxR, boxG, boxB, boxA = 0.98, 0.84, 0.36, 1
                    checkR, checkG, checkB, checkA = 0.98, 0.88, 0.36, 1
                    iconR, iconG, iconB, iconA = 0.98, 0.88, 0.36, 1
                end
                bgAlpha = 0.74
                glowAlpha = 0.46
                pulseAlpha = 0.84
            elseif isSelected then
                if isDaily then
                    borderR, borderG, borderB, borderA = 0.34, 0.66, 0.96, 0.72
                    accentR, accentG, accentB, accentA = 0.42, 0.72, 1.0, 0.84
                    boxR, boxG, boxB, boxA = 0.48, 0.78, 1.0, 1
                    checkR, checkG, checkB, checkA = 0.66, 0.88, 1.0, isWatched and 1 or 0
                    iconR, iconG, iconB, iconA = 0.66, 0.88, 1.0, 0.92
                else
                    borderR, borderG, borderB, borderA = 0.90, 0.72, 0.28, 0.64
                    accentR, accentG, accentB, accentA = 0.92, 0.76, 0.30, 0.84
                    boxR, boxG, boxB, boxA = 0.92, 0.78, 0.38, 1
                    checkR, checkG, checkB, checkA = 0.94, 0.84, 0.46, isWatched and 1 or 0
                    iconR, iconG, iconB, iconA = 0.96, 0.86, 0.48, 0.9
                end
                bgAlpha = 0.70
                glowAlpha = 0.28
                pulseAlpha = 0.42
            elseif isWatched then
                if isDaily then
                    borderR, borderG, borderB, borderA = 0.32, 0.62, 0.92, 0.56
                    accentR, accentG, accentB, accentA = 0.40, 0.70, 1.0, 0.70
                    boxR, boxG, boxB, boxA = 0.46, 0.78, 1.0, 1
                    checkR, checkG, checkB, checkA = 0.62, 0.86, 1.0, 1
                    iconR, iconG, iconB, iconA = 0.62, 0.84, 1.0, 0.84
                else
                    borderR, borderG, borderB, borderA = 0.74, 0.62, 0.32, 0.48
                    accentR, accentG, accentB, accentA = 0.86, 0.72, 0.34, 0.70
                    boxR, boxG, boxB, boxA = 0.88, 0.76, 0.40, 1
                    checkR, checkG, checkB, checkA = 0.90, 0.78, 0.40, 1
                    iconR, iconG, iconB, iconA = 0.92, 0.80, 0.44, 0.8
                end
                bgAlpha = 0.66
            elseif isComplete then
                borderR, borderG, borderB, borderA = 0.44, 0.62, 0.30, 0.52
                bgAlpha = 0.62
                accentR, accentG, accentB, accentA = 0.56, 0.82, 0.40, 0.62
                boxR, boxG, boxB, boxA = 0.58, 0.76, 0.42, 0.92
                iconR, iconG, iconB, iconA = 0.76, 0.92, 0.64, 0.72
                dotAlpha = 0.96
            elseif isHover then
                borderR, borderG, borderB, borderA = 0.54, 0.42, 0.20, 0.40
                bgAlpha = 0.64
                accentR, accentG, accentB, accentA = 0.82, 0.68, 0.30, 0.42
                iconR, iconG, iconB, iconA = 0.96, 0.86, 0.48, 0.54
                glowAlpha = 0.16
            end

            rowChrome:SetBackdropColor(0.05, 0.04, 0.02, bgAlpha)
            rowChrome:SetBackdropBorderColor(borderR, borderG, borderB, borderA)
            rowChrome.accent:SetVertexColor(accentR, accentG, accentB, 1)
            rowChrome.accent:SetAlpha(accentA)
            rowChrome.glow:SetAlpha(glowAlpha)
            rowChrome.trackBox:SetVertexColor(boxR, boxG, boxB, boxA)
            if rowChrome.trackIcon then
                rowChrome.trackIcon:SetVertexColor(iconR, iconG, iconB, iconA)
            end
            rowChrome.trackCheck:SetVertexColor(checkR, checkG, checkB, 1)
            rowChrome.trackCheck:SetAlpha(checkA)
            rowChrome.trackPulse:SetAlpha(pulseAlpha)
            rowChrome.completeDot:SetAlpha(dotAlpha)
        end

        UpdateWorldMapQuestPoi(child, isTracked, isSelected, isWatched, isComplete, isHover, isDaily)

        for j = 1, #fontStrings do
            local fontString = fontStrings[j]
            local text = fontString.GetText and fontString:GetText() or nil
            if type(text) == "string" and text ~= "" then
                if title and StripQuestLevelPrefix(text) == StripQuestLevelPrefix(title) then
                    local displayTitle = BuildQuestDisplayTitle(title, level)
                    if fontString:GetText() ~= displayTitle then
                        fontString:SetText(displayTitle)
                    end
                    if isTracked then
                        if isDaily then
                            ApplyFontStyle(fontString, 11, 1, 0.70, 0.90, 1.0)
                        else
                            ApplyFontStyle(fontString, 11, 1, 1.0, 0.90, 0.42)
                        end
                    elseif isSelected then
                        if isDaily then
                            ApplyFontStyle(fontString, 11, 1, 0.68, 0.88, 1.0)
                        else
                            ApplyFontStyle(fontString, 11, 1, 0.99, 0.90, 0.52)
                        end
                    elseif isWatched then
                        if isDaily then
                            ApplyFontStyle(fontString, 11, 1, 0.66, 0.86, 1.0)
                        else
                            ApplyFontStyle(fontString, 11, 1, 0.96, 0.90, 0.68)
                        end
                    elseif isComplete then
                        ApplyFontStyle(fontString, 11, 1, 0.74, 0.88, 0.60)
                    elseif isDaily then
                        ApplyFontStyle(fontString, 11, 1, 0.62, 0.84, 1.0)
                    else
                        ApplyFontStyle(fontString, 11, 1, 0.96, 0.88, 0.64)
                    end
                elseif text:find("^%s*[%-%d]", 1) then
                    if isTracked or isSelected then
                        ApplyFontStyle(fontString, 10, 1, 0.96, 0.92, 0.80)
                    elseif isComplete then
                        ApplyFontStyle(fontString, 10, 1, 0.78, 0.90, 0.72)
                    else
                        ApplyFontStyle(fontString, 10, 1, 0.92, 0.88, 0.74)
                    end
                end
            end
        end

        if child.__dcqosWorldQuestHighlight then
            child.__dcqosWorldQuestHighlight:Hide()
        end

        if child.__dcqosWorldQuestAccent then
            child.__dcqosWorldQuestAccent:Hide()
        end

        if questLogIndex and questLogIndex > 0 then
            child.questLogIndex = questLogIndex
            child.questIndex = questLogIndex
        end
    end

    UpdateWorldMapQuestBlobState(selectedQuestId, hoveredQuestId, trackedQuestId)
end

local function UpdateQuestInfoTitles()
    local questInfoContext
    if QuestFrame and QuestFrame.IsShown and QuestFrame:IsShown() then
        questInfoContext = GetQuestFrameContext(QuestFrame)
    else
        questInfoContext = GetQuestLogDetailContext(QuestLogDetailFrame or QuestLogFrame)
    end

    if QuestInfoTitleHeader and questInfoContext and questInfoContext.title then
        local displayTitle = BuildQuestDisplayTitle(questInfoContext.title, questInfoContext.level)
        displayTitle = DecorateQuestTitle(displayTitle, questInfoContext.questId)
        if displayTitle and displayTitle ~= "" and QuestInfoTitleHeader:GetText() ~= displayTitle then
            QuestInfoTitleHeader:SetText(displayTitle)
        end
    end

    if QuestProgressTitleText and QuestFrame and QuestFrame.IsShown and QuestFrame:IsShown() then
        local progressContext = GetQuestFrameContext(QuestFrame)
        if progressContext and progressContext.title then
            local progressTitle = BuildQuestDisplayTitle(progressContext.title, progressContext.level)
            if progressTitle and progressTitle ~= "" and QuestProgressTitleText:GetText() ~= progressTitle then
                QuestProgressTitleText:SetText(progressTitle)
            end
        end
    end
end

local function StyleWorldMapQuestPanels()
    ApplyCombinedWorldMapLayout()

    for frameName in pairs(WORLD_MAP_PANEL_LAYOUTS) do
        local frame = _G[frameName]
        if frame then
            local skin = frame.__dcqosWorldMapQuestSkin
            if skin then
                skin:Hide()
            end
        end
    end

    if WorldMapTrackQuest then
        addon:StyleActionButton(WorldMapTrackQuest)
    end

    StyleWorldMapQuestRows()

    local selectedQuestInfo = GetSelectedWorldMapQuestInfo()
    if selectedQuestInfo and selectedQuestInfo.title then
        local isTracked = IsQuestTracked(selectedQuestInfo)
        local isComplete = selectedQuestInfo.isComplete or false
        StyleWorldMapQuestDetailTextRecursive(WorldMapQuestDetailScrollFrame, 0, selectedQuestInfo.title, isTracked, isComplete)
        StyleWorldMapQuestDetailTextRecursive(WorldMapQuestRewardScrollFrame, 0, selectedQuestInfo.title, isTracked, isComplete)
    end
end

local function StyleQuestRowButtons()
    local misses = 0
    for index = 1, 64 do
        local button = _G["QuestLogTitle" .. index]
        if button then
            EnsureQuestRowButton(button, QUEST_LOG_TITLE_HIGHLIGHT_TEXTURE, "log")
            UpdateQuestRowButton(button)
            misses = 0
        else
            misses = misses + 1
            if misses >= 8 and index > 8 then
                break
            end
        end
    end

    misses = 0
    for index = 1, 64 do
        local button = _G["QuestTitleButton" .. index]
        if button then
            EnsureQuestRowButton(button, QUEST_TITLE_HIGHLIGHT_TEXTURE, "greeting")
            UpdateQuestRowButton(button)
            misses = 0
        else
            misses = misses + 1
            if misses >= 8 and index > 8 then
                break
            end
        end
    end
end

ApplyFontStyle = function(fontString, minSize, sizeDelta, r, g, b)
    if not fontString or not fontString.GetFont or not fontString.SetFont then
        return
    end

    local font, size, flags = fontString:GetFont()
    if not font or not size then
        return
    end

    if not fontString.__dcqosQuestFont then
        fontString.__dcqosQuestFont = {
            font = font,
            size = size,
            flags = flags,
        }
    end

    local original = fontString.__dcqosQuestFont
    fontString:SetFont(original.font, math.max(minSize, original.size + sizeDelta), original.flags)
    if fontString.SetTextColor then
        fontString:SetTextColor(r, g, b)
    end
end

local function StyleQuestText()
    local tracked = IsQuestTracked(ResolveQuestContext(QuestFrame))
    local preferStockChrome = UseModernQuestWindowCompatibility()
        or ShouldPreferStockQuestChrome(QuestFrame)
        or ShouldPreferStockQuestChrome(QuestLogDetailFrame)
    local titleR, titleG, titleB = 1.0, 0.82, 0.08
    if GetSettings().accentTrackedQuest and tracked then
        titleR, titleG, titleB = 1.0, 0.90, 0.34
    end

    for _, name in ipairs(TITLE_TEXT_NAMES) do
        ApplyFontStyle(_G[name], 13, preferStockChrome and 0 or 2, titleR, titleG, titleB)
    end

    for _, name in ipairs(BODY_TEXT_NAMES) do
        ApplyFontStyle(_G[name], 12, preferStockChrome and 0 or 1, 0.98, 0.92, 0.78)
    end

    for _, name in ipairs(SECTION_TEXT_NAMES) do
        ApplyFontStyle(_G[name], 11, preferStockChrome and 0 or 1, 0.94, 0.80, 0.32)
    end

    UpdateQuestInfoTitles()
end

local function UpdateQuestItemNameFrame(button, nameLabel)
    if not button or not nameLabel then
        return
    end

    local nameFrame = GetQuestItemNameFrameRegion(button)
    if nameFrame then
        if nameFrame.SetAlpha then
            nameFrame:SetAlpha(0)
        end
        if nameFrame.Hide then
            nameFrame:Hide()
        end
    end
end

local function StyleQuestItemButton(button)
    if not button then
        return
    end

    if not ButtonLooksLikeQuestItem(button) then
        return
    end

    if not button.__dcqosQuestItem then
        button.__dcqosQuestItem = true

        local iconFrame = button:CreateTexture(nil, "BORDER")
        iconFrame:SetTexture(QUEST_ITEM_NAMEFRAME_TEXTURE)
        iconFrame:SetAlpha(0.96)
        iconFrame:Show()
        button.__dcqosQuestItemFrame = iconFrame

        -- Hover-only glow: kept on the OVERLAY layer so it never sits on top of
        -- the icon while idle. Alpha is forced to 0 here and only the OnEnter
        -- script raises it. The previous BACKGROUND-layer dark fill behind the
        -- icon was removed because some QuestProgressItem buttons render the
        -- icon at the BACKGROUND draw layer too, which made the fill cover the
        -- item art with a solid gold/brown block.
        local highlight = button:CreateTexture(nil, "OVERLAY")
        highlight:SetTexture(QUEST_ITEM_HIGHLIGHT_TEXTURE)
        highlight:SetBlendMode("ADD")
        highlight:SetAlpha(0)
        highlight:Hide()
        button.__dcqosQuestItemHighlight = highlight

        button:HookScript("OnEnter", function(self)
            if self.__dcqosQuestItemHighlight then
                self.__dcqosQuestItemHighlight:Show()
                self.__dcqosQuestItemHighlight:SetAlpha(0.6)
            end
        end)

        button:HookScript("OnLeave", function(self)
            if self.__dcqosQuestItemHighlight then
                self.__dcqosQuestItemHighlight:SetAlpha(0)
                self.__dcqosQuestItemHighlight:Hide()
            end
        end)
    end

    -- Make sure any legacy decoration we used to add no longer paints over the
    -- icon (older saved state may still hold a reference to the dark BG block).
    if button.__dcqosQuestItemBorder then
        if button.__dcqosQuestItemBorder.Hide then
            button.__dcqosQuestItemBorder:Hide()
        end
        if button.__dcqosQuestItemBorder.SetTexture then
            button.__dcqosQuestItemBorder:SetTexture(nil)
        end
    end

    if button.__dcqosQuestItemBg then
        button.__dcqosQuestItemBg:Hide()
    end

    local iconRegions = CollectQuestItemIconRegions(button)
    local iconRegion = iconRegions[1]
    if not iconRegion and type(button.GetNormalTexture) == "function" then
        iconRegion = button:GetNormalTexture()
        if iconRegion then
            table.insert(iconRegions, iconRegion)
        end
    end

    ApplyQuestItemTexture(button, iconRegion, iconRegions)

    local iconAnchor = iconRegion or button

    if iconRegion and iconRegion.SetAlpha then
        iconRegion:SetAlpha(1)
    end
    if iconRegion and iconRegion.Show then
        iconRegion:Show()
    end
    if button.__dcqosQuestItemHighlight then
        button.__dcqosQuestItemHighlight:ClearAllPoints()
        button.__dcqosQuestItemHighlight:SetPoint("TOPLEFT", iconAnchor, "TOPLEFT", -2, 2)
        button.__dcqosQuestItemHighlight:SetPoint("BOTTOMRIGHT", iconAnchor, "BOTTOMRIGHT", 2, -2)
    end
    if button.__dcqosQuestItemFrame then
        button.__dcqosQuestItemFrame:ClearAllPoints()
        button.__dcqosQuestItemFrame:SetPoint("TOPLEFT", iconAnchor, "TOPLEFT", -8, 8)
        button.__dcqosQuestItemFrame:SetPoint("BOTTOMRIGHT", iconAnchor, "BOTTOMRIGHT", 8, -8)
        button.__dcqosQuestItemFrame:SetDrawLayer("BORDER", 0)
        button.__dcqosQuestItemFrame:SetVertexColor(1, 1, 1, 1)
        button.__dcqosQuestItemFrame:Show()
    end
    if button.__dcqosQuestItemBorder and button.__dcqosQuestItemBorder.ClearAllPoints then
        -- Legacy decoration: keep it parked off the icon so saved references
        -- can never bleed gold back over the artwork.
        button.__dcqosQuestItemBorder:ClearAllPoints()
        if button.__dcqosQuestItemBorder.Hide then
            button.__dcqosQuestItemBorder:Hide()
        end
    end

    local nameLabel = GetQuestItemNameLabel(button)
    if nameLabel then
        UpdateQuestItemNameFrame(button, nameLabel)
        ApplyFontStyle(nameLabel, 11, 1, 0.98, 0.92, 0.78)
    end

    if iconRegion and iconRegion.SetTexCoord then
        iconRegion:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end
end

local function StyleQuestItems()
    if not GetSettings().decorateRewards then
        return
    end

    for _, group in ipairs(ITEM_BUTTON_GROUPS) do
        for index = 1, group.count do
            StyleQuestItemButton(_G[group.prefix .. index])
        end
    end

    for _, name in ipairs(SHARED_ITEM_HIGHLIGHT_NAMES) do
        local source = _G[name]
        local highlight = ResolveTextureRegion(source)
        if highlight and not highlight.__dcqosQuestItemSharedHighlight then
            highlight:SetTexture(QUEST_ITEM_HIGHLIGHT_TEXTURE)
            if highlight.SetBlendMode then
                highlight:SetBlendMode("ADD")
            end
            highlight.__dcqosQuestItemSharedHighlight = true
        end
    end

    local function StyleButtonsInFrame(root, depth)
        if not root or depth > 4 then
            return
        end

        if root.GetObjectType and root:GetObjectType() == "Button" then
            StyleQuestItemButton(root)
        end

        if type(root.GetChildren) ~= "function" then
            return
        end

        local children = { root:GetChildren() }
        for i = 1, #children do
            StyleButtonsInFrame(children[i], depth + 1)
        end
    end

    StyleButtonsInFrame(WorldMapQuestRewardScrollFrame, 0)
    StyleButtonsInFrame(WorldMapQuestDetailScrollFrame, 0)
end

local function StyleActionButtons()
    for _, name in ipairs(ACTION_BUTTON_NAMES) do
        local button = _G[name]
        if button then
            addon:StyleActionButton(button)
        end
    end
end

local function UpdateFrameHeader(frame)
    if not frame then
        return
    end

    local settings = GetSettings()
    local preferStockChrome = UseModernQuestWindowCompatibility()
        or ShouldPreferStockQuestChrome(frame)
    local skin = EnsureFrameSkin(frame)
    local header = EnsureHeader(frame)
    local isShown = frame.IsShown and frame:IsShown()

    if skin then
        local showSkin = settings.retailSkin and isShown and not preferStockChrome
        SetFrameShown(skin, showSkin)
        if showSkin then
            UpdateFrameShell(frame, skin)
        end
        if skin.border then
            skin.border:SetVertexColor(0.24, 0.18, 0.08, showSkin and 0.62 or 0.92)
        end
        if skin.topTint then
            skin.topTint:SetAlpha(showSkin and 0.08 or 0.16)
        end
    end

    if not isShown or preferStockChrome then
        header:Hide()
        return
    end

    local context = ResolveQuestContext(frame)
    header:Show()
    header.title:SetText(DecorateQuestTitle(context and context.title or (QUESTS_LABEL or "Quests"), context and context.questId or nil) or "")
    header.meta:SetText(BuildQuestMeta(context) or "")

    local showFollow = settings.showFollowButton and context and context.showFollow
    SetFrameShown(header.follow, showFollow and true or false)
    LayoutHeader(header, showFollow)

    if showFollow then
        if IsQuestTracked(context) then
            header.follow:SetText("Clear Follow")
        else
            header.follow:SetText("Follow")
        end
        if context.questLogIndex and context.questLogIndex > 0 and addon:GetModule("Navigation") then
            header.follow:Enable()
        else
            header.follow:Disable()
        end
    end

    SetFrameShown(header.divider, settings.retailSkin)
end

local function RefreshAllFrames()
    local preferStockChrome = UseModernQuestWindowCompatibility()
        or ShouldPreferStockQuestChrome(QuestFrame)
        or ShouldPreferStockQuestChrome(QuestLogDetailFrame)

    for _, name in ipairs(ROOT_FRAME_NAMES) do
        local frame = _G[name]
        if frame then
            UpdateFrameHeader(frame)
        end
    end

    UpdateQuestLogChrome()
    UpdateMovableFrames()
    EnsurePortraitAccent()
    if QuestFramePortrait and QuestFramePortrait.__dcqosPortraitAccent then
        local showPortrait = GetSettings().retailSkin
            and not preferStockChrome
            and QuestFrame
            and QuestFrame.IsShown
            and QuestFrame:IsShown()
        SetFrameShown(QuestFramePortrait.__dcqosPortraitAccent, showPortrait and true or false)
    end
end

local function InstallHooks()
    if state.hooksInstalled then
        return
    end

    local hookNames = {
        "QuestInfo_Display",
        "QuestInfo_ShowRewards",
        "QuestLog_Update",
        "QuestLog_UpdateQuestDetails",
        "QuestFrame_SetPortrait",
        "QuestFrameGreetingPanel_OnShow",
        "QuestFrameProgressPanel_OnShow",
        "QuestFrameRewardPanel_OnShow",
    }

    for _, name in ipairs(hookNames) do
        if type(_G[name]) == "function" then
            hooksecurefunc(name, function()
                QueueRefresh(0)
            end)
        end
    end

    for _, frame in ipairs({ QuestLogDetailFrame, QuestLogFrame }) do
        if frame and type(frame.HookScript) == "function" then
            frame:HookScript("OnShow", function()
                CloseStandaloneQuestLogPanelsForCombinedMap()
                if ShouldApplyCombinedWorldMapLayout() then
                    QueueRefresh(0)
                    QueueRefresh(0.05)
                    QueueRefresh(0.15)
                end
            end)
        end
    end

    InstallWorldMapHooks()
    state.hooksInstalled = true
end

function QuestFrames:Refresh()
    if not GetSettings().enabled then
        return
    end

    state.questRegionLookup = nil

    StyleQuestText()
    StyleQuestRowButtons()
    StyleActionButtons()
    StyleWorldMapQuestPanels()
    StyleQuestItems()
    RefreshAllFrames()
end

function QuestFrames.OnInitialize()
    addon:RegisterSettingsKeywords("QuestFrames", {
        "quest",
        "quest frame",
        "retail quest",
        "quest rewards",
        "follow quest",
        "quest greeting",
    })
end

function QuestFrames.OnEnable()
    InstallHooks()

    if not state.eventFrame then
        state.eventFrame = CreateFrame("Frame")
        state.eventFrame:SetScript("OnEvent", function()
            QueueRefresh(0)
            QueueRefresh(0.05)
        end)
    end

    state.eventFrame:UnregisterAllEvents()
    state.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    state.eventFrame:RegisterEvent("QUEST_GREETING")
    state.eventFrame:RegisterEvent("QUEST_DETAIL")
    state.eventFrame:RegisterEvent("QUEST_PROGRESS")
    state.eventFrame:RegisterEvent("QUEST_COMPLETE")
    state.eventFrame:RegisterEvent("QUEST_FINISHED")
    state.eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
    state.eventFrame:RegisterEvent("QUEST_WATCH_UPDATE")
    state.eventFrame:RegisterEvent("SUPER_TRACKING_CHANGED")

    QueueRefresh(0)
    QueueRefresh(0.10)
end

function QuestFrames.OnDisable()
    if state.eventFrame then
        state.eventFrame:UnregisterAllEvents()
    end

    if WorldMapFrame and WorldMapFrame.__dcqosCombinedQuestShell then
        WorldMapFrame.__dcqosCombinedQuestShell:Hide()
    end

    for _, name in ipairs(ROOT_FRAME_NAMES) do
        local frame = _G[name]
        if frame and frame.__dcqosQuestSkin then
            frame.__dcqosQuestSkin:Hide()
        end
        if frame and frame.__dcqosQuestHeader then
            frame.__dcqosQuestHeader:Hide()
        end
    end

    if QuestFramePortrait and QuestFramePortrait.__dcqosPortraitAccent then
        QuestFramePortrait.__dcqosPortraitAccent:Hide()
    end

    if QuestLogFrame and QuestLogFrame.__dcqosQuestLogChrome then
        QuestLogFrame.__dcqosQuestLogChrome:Hide()
    end

    for _, handle in pairs(state.movableHandles) do
        if handle then
            handle:Hide()
        end
    end
end

function QuestFrames.CreateSettings(parent)
    local settings = GetSettings()

    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Quest Frames")

    local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetWidth(420)
    desc:SetJustifyH("LEFT")
    desc:SetText("Retail-inspired skinning for the main quest, greeting, progress, reward, and quest-detail frames, plus direct follow controls that reuse DC-QOS Navigation.")

    local yOffset = -76

    local retailSkin = addon:CreateCheckbox(parent)
    retailSkin:SetPoint("TOPLEFT", 16, yOffset)
    retailSkin.Text:SetText("Use retail quest frame shell")
    retailSkin:SetChecked(settings.retailSkin)
    retailSkin:SetScript("OnClick", function(self)
        addon:SetSetting("questFrames.retailSkin", self:GetChecked())
        QueueRefresh(0)
    end)
    yOffset = yOffset - 28

    local showIds = addon:CreateCheckbox(parent)
    showIds:SetPoint("TOPLEFT", 16, yOffset)
    showIds.Text:SetText("Show quest IDs in quest headers")
    showIds:SetChecked(settings.showQuestIds)
    showIds:SetScript("OnClick", function(self)
        addon:SetSetting("questFrames.showQuestIds", self:GetChecked())
        QueueRefresh(0)
    end)
    yOffset = yOffset - 28

    local showLevels = addon:CreateCheckbox(parent)
    showLevels:SetPoint("TOPLEFT", 16, yOffset)
    showLevels.Text:SetText("Show quest levels in quest headers")
    showLevels:SetChecked(settings.showQuestLevels)
    showLevels:SetScript("OnClick", function(self)
        addon:SetSetting("questFrames.showQuestLevels", self:GetChecked())
        QueueRefresh(0)
    end)
    yOffset = yOffset - 28

    local showFollow = addon:CreateCheckbox(parent)
    showFollow:SetPoint("TOPLEFT", 16, yOffset)
    showFollow.Text:SetText("Show Follow button on quest detail views")
    showFollow:SetChecked(settings.showFollowButton)
    showFollow:SetScript("OnClick", function(self)
        addon:SetSetting("questFrames.showFollowButton", self:GetChecked())
        QueueRefresh(0)
    end)
    yOffset = yOffset - 28

    local decorateRewards = addon:CreateCheckbox(parent)
    decorateRewards:SetPoint("TOPLEFT", 16, yOffset)
    decorateRewards.Text:SetText("Retouch reward and required-item buttons")
    decorateRewards:SetChecked(settings.decorateRewards)
    decorateRewards:SetScript("OnClick", function(self)
        addon:SetSetting("questFrames.decorateRewards", self:GetChecked())
        QueueRefresh(0)
    end)
    yOffset = yOffset - 28

    local accentTracked = addon:CreateCheckbox(parent)
    accentTracked:SetPoint("TOPLEFT", 16, yOffset)
    accentTracked.Text:SetText("Accent the currently followed quest")
    accentTracked:SetChecked(settings.accentTrackedQuest)
    accentTracked:SetScript("OnClick", function(self)
        addon:SetSetting("questFrames.accentTrackedQuest", self:GetChecked())
        QueueRefresh(0)
    end)

    return yOffset - 50
end

addon:RegisterModule("QuestFrames", QuestFrames)