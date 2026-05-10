-- ============================================================
-- DC-QoS: Quest Map Pins Module
-- ============================================================

local addon = DCQOS
local questTrackingUtils = type(addon.GetQuestTrackingUtils) == "function" and addon:GetQuestTrackingUtils() or nil

local QuestMapPins = {
    displayName = "QuestMapPins",
    settingKey = "questMapPins",
    icon = "Interface\\Icons\\INV_Misc_Map_01",
    defaults = {
        questMapPins = {
            enabled = true,
            showAvailable = true,
            showTurnIns = true,
            showObjectives = true,
            hideTrivialStarts = true,
        },
    },
}

local LEATHER_TEXTURE = "Interface\\AddOns\\DC-QOS\\Textures\\Backgrounds\\FelLeather_512.tga"
local QUEST_TEXTURE_ROOT = "Interface\\AddOns\\DC-QOS\\Textures\\QuestFrame\\"
local AVAILABLE_ICON_TEXTURE = QUEST_TEXTURE_ROOT .. "availablequesticon"
local ACTIVE_ICON_TEXTURE = QUEST_TEXTURE_ROOT .. "activequesticon"
local DAILY_ICON_TEXTURE = QUEST_TEXTURE_ROOT .. "dailyquesticon"
local DAILY_ACTIVE_ICON_TEXTURE = QUEST_TEXTURE_ROOT .. "dailyactivequesticon"
local OBJECTIVE_ICON_TEXTURE = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_3"
local GLOW_TEXTURE = "Interface\\Minimap\\UI-Minimap-Ping"

local state = {
    overlay = nil,
    buttons = {},
    hooksInstalled = false,
    refreshQueued = {},
    eventFrame = nil,
    availableByMap = nil,
}

local function GetSettings()
    return addon.settings and addon.settings.questMapPins or addon.defaults.questMapPins
end

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

local function QueueRefresh(delaySeconds)
    local delay = tonumber(delaySeconds) or 0
    local key = string.format("%.2f", delay)
    if state.refreshQueued[key] then
        return
    end
    state.refreshQueued[key] = true

    if type(addon.DelayedCall) == "function" then
        addon:DelayedCall(delay, function()
            state.refreshQueued[key] = nil
            QuestMapPins:Refresh()
        end)
    else
        state.refreshQueued[key] = nil
        QuestMapPins:Refresh()
    end
end

local function GetDisplayedWorldMapId()
    if type(GetCurrentMapAreaID) ~= "function" then
        return nil
    end

    local mapId = tonumber(GetCurrentMapAreaID())
    if mapId and mapId > 0 then
        return mapId
    end

    return nil
end

local function GetQuestIdFromLogIndex(questLogIndex)
    if questTrackingUtils and type(questTrackingUtils.GetQuestIdFromLogIndex) == "function" then
        return questTrackingUtils.GetQuestIdFromLogIndex(questLogIndex, { allowQuestLogIndexFallback = true })
    end

    return nil
end

local function GetTrackedQuestId()
    if questTrackingUtils and type(questTrackingUtils.GetSuperTrackedQuestId) == "function" then
        return questTrackingUtils.GetSuperTrackedQuestId()
    end

    return nil
end

local function GetRecurringQuestType(questId)
    local lookup = addon and addon.QuestRecurringLookup or nil
    local byQuestId = lookup and lookup.byQuestId or nil
    if not byQuestId then
        return nil
    end

    return byQuestId[questId]
end

local function FormatQuestLabel(title, level)
    if type(level) == "number" and level > 0 then
        return string.format("[%d] %s", level, title or "Quest")
    end

    return title or "Quest"
end

local function GetActiveQuestLookup()
    local lookup = {}
    if type(GetNumQuestLogEntries) ~= "function" or type(GetQuestLogTitle) ~= "function" then
        return lookup
    end

    local numEntries = GetNumQuestLogEntries() or 0
    for questLogIndex = 1, numEntries do
        local title, level, _, _, isHeader, _, isComplete = GetQuestLogTitle(questLogIndex)
        if not isHeader then
            local questId = tonumber(GetQuestIdFromLogIndex(questLogIndex))
            if questId and questId > 0 then
                lookup[questId] = {
                    questId = questId,
                    questLogIndex = questLogIndex,
                    title = title,
                    level = tonumber(level) or 0,
                    isComplete = (isComplete == true or isComplete == 1),
                }
            end
        end
    end

    return lookup
end

local function IsQuestCompleted(questId)
    if type(IsQuestFlaggedCompleted) ~= "function" then
        return false
    end

    local ok, complete = pcall(IsQuestFlaggedCompleted, questId)
    return ok and complete == true
end

local function IsTrivialQuest(level)
    level = tonumber(level)
    if not level or level <= 0 then
        return false
    end

    local playerLevel = type(UnitLevel) == "function" and tonumber(UnitLevel("player")) or nil
    if not playerLevel or playerLevel <= 0 then
        return false
    end

    local greenRange = type(GetQuestGreenRange) == "function" and tonumber(GetQuestGreenRange()) or nil
    if not greenRange or greenRange <= 0 then
        greenRange = 6
    end

    return level < (playerLevel - greenRange)
end

local function EnsureAvailableIndex()
    if state.availableByMap then
        return state.availableByMap
    end

    local availableByMap = {}
    local data = addon and addon.QuestMapData and addon.QuestMapData.quests or nil
    if type(data) ~= "table" then
        state.availableByMap = availableByMap
        return availableByMap
    end

    for questId, quest in pairs(data) do
        local starts = quest.s
        if type(starts) == "table" then
            for i = 1, #starts do
                local marker = starts[i]
                local mapId = marker and tonumber(marker.m) or nil
                local x = marker and tonumber(marker.x) or nil
                local y = marker and tonumber(marker.y) or nil
                if mapId and mapId > 0 and x and y then
                    local bucket = availableByMap[mapId]
                    if not bucket then
                        bucket = {}
                        availableByMap[mapId] = bucket
                    end
                    bucket[#bucket + 1] = {
                        category = "start",
                        questId = tonumber(questId),
                        mapId = mapId,
                        x = x,
                        y = y,
                        level = tonumber(quest.l) or 0,
                        title = quest.t,
                        sourceKind = marker.k,
                    }
                end
            end
        end
    end

    for mapId, bucket in pairs(availableByMap) do
        table.sort(bucket, function(left, right)
            if left.y ~= right.y then
                return left.y < right.y
            end
            if left.x ~= right.x then
                return left.x < right.x
            end
            return tostring(left.title or "") < tostring(right.title or "")
        end)
        availableByMap[mapId] = bucket
    end

    state.availableByMap = availableByMap
    return availableByMap
end

local function GetVisibleMarkers(currentMapId)
    local settings = GetSettings()
    local markers = {}
    local activeQuestLookup = GetActiveQuestLookup()
    local trackedQuestId = tonumber(GetTrackedQuestId())
    local data = addon and addon.QuestMapData and addon.QuestMapData.quests or nil

    if settings.showAvailable then
        local availableByMap = EnsureAvailableIndex()
        local starts = availableByMap[currentMapId] or nil
        if starts then
            for i = 1, #starts do
                local marker = starts[i]
                local questId = marker.questId
                if questId and not activeQuestLookup[questId] and not IsQuestCompleted(questId) then
                    if not settings.hideTrivialStarts or not IsTrivialQuest(marker.level) then
                        marker.isTracked = trackedQuestId and trackedQuestId == questId or false
                        marker.recurrenceType = GetRecurringQuestType(questId)
                        markers[#markers + 1] = marker
                    end
                end
            end
        end
    end

    if type(data) == "table" then
        for questId, questState in pairs(activeQuestLookup) do
            local quest = data[questId]
            if quest then
                if questState.isComplete then
                    if settings.showTurnIns and type(quest.r) == "table" then
                        for i = 1, #quest.r do
                            local marker = quest.r[i]
                            if tonumber(marker.m) == currentMapId then
                                markers[#markers + 1] = {
                                    category = "turnin",
                                    questId = questId,
                                    questLogIndex = questState.questLogIndex,
                                    mapId = currentMapId,
                                    x = tonumber(marker.x),
                                    y = tonumber(marker.y),
                                    level = questState.level,
                                    title = questState.title or quest.t,
                                    isTracked = trackedQuestId and trackedQuestId == questId or false,
                                    recurrenceType = GetRecurringQuestType(questId),
                                    sourceKind = marker.k,
                                }
                            end
                        end
                    end
                elseif settings.showObjectives and type(quest.o) == "table" then
                    for i = 1, #quest.o do
                        local marker = quest.o[i]
                        if tonumber(marker.m) == currentMapId then
                            markers[#markers + 1] = {
                                category = "objective",
                                questId = questId,
                                questLogIndex = questState.questLogIndex,
                                mapId = currentMapId,
                                x = tonumber(marker.x),
                                y = tonumber(marker.y),
                                level = questState.level,
                                title = questState.title or quest.t,
                                isTracked = trackedQuestId and trackedQuestId == questId or false,
                                recurrenceType = GetRecurringQuestType(questId),
                                objectiveIndex = tonumber(marker.i) or 0,
                            }
                        end
                    end
                end
            end
        end
    end

    table.sort(markers, function(left, right)
        local function Priority(marker)
            if marker.isTracked then
                return 40
            end
            if marker.category == "turnin" then
                return 30
            end
            if marker.category == "objective" then
                return 20
            end
            return 10
        end

        local leftPriority = Priority(left)
        local rightPriority = Priority(right)
        if leftPriority ~= rightPriority then
            return leftPriority < rightPriority
        end
        if left.questId ~= right.questId then
            return (left.questId or 0) < (right.questId or 0)
        end
        if left.y ~= right.y then
            return (left.y or 0) < (right.y or 0)
        end
        return (left.x or 0) < (right.x or 0)
    end)

    return markers
end

local function GetOverlayParent()
    return WorldMapButton or WorldMapDetailFrame or nil
end

local function HideUnusedButtons(startIndex)
    for index = startIndex, #state.buttons do
        local button = state.buttons[index]
        if button then
            button.questMarkerData = nil
            button:Hide()
        end
    end
end

local function GetNavigationModule()
    return addon and type(addon.GetModule) == "function" and addon:GetModule("Navigation") or nil
end

local function CanSetWaypoint()
    local navigation = GetNavigationModule()
    return navigation and type(navigation.SetManualWaypoint) == "function"
end

local function GetMarkerKindLabel(marker)
    if marker.category == "start" then
        return "Quest start"
    end
    if marker.category == "turnin" then
        return "Turn-in"
    end
    if marker.category == "objective" then
        return string.format("Objective %d", (tonumber(marker.objectiveIndex) or 0) + 1)
    end
    return "Quest"
end

local function OnMarkerEnter(self)
    local marker = self.questMarkerData
    if not marker or not GameTooltip then
        return
    end

    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(FormatQuestLabel(marker.title, marker.level), 1.0, 0.84, 0.22)
    GameTooltip:AddLine(GetMarkerKindLabel(marker), 0.88, 0.88, 0.88)

    if marker.recurrenceType == "daily" then
        GameTooltip:AddLine("Recurring: Daily", 0.50, 0.78, 1.0)
    elseif marker.recurrenceType == "weekly" then
        GameTooltip:AddLine("Recurring: Weekly", 0.50, 0.78, 1.0)
    end

    if marker.isTracked then
        GameTooltip:AddLine("Currently followed by Navigation", 1.0, 0.90, 0.42)
    end

    if marker.questLogIndex then
        GameTooltip:AddLine("Left-click: follow quest", 0.72, 0.90, 1.0)
        if CanSetWaypoint() then
            GameTooltip:AddLine("Shift-click: set waypoint here", 0.72, 0.90, 1.0)
        end
    elseif CanSetWaypoint() then
        GameTooltip:AddLine("Left-click: set waypoint here", 0.72, 0.90, 1.0)
    end

    GameTooltip:Show()
end

local function OnMarkerLeave()
    if GameTooltip then
        GameTooltip:Hide()
    end
end

local function SelectQuestMarker(marker)
    if not marker then
        return
    end

    local navigation = GetNavigationModule()
    if not navigation then
        return
    end

    if marker.questLogIndex and type(navigation.SetFollowQuestByLogIndex) == "function" then
        local ok = navigation:SetFollowQuestByLogIndex(marker.questLogIndex, false)
        if ok ~= false and type(QuestLog_SetSelection) == "function" then
            pcall(QuestLog_SetSelection, marker.questLogIndex)
        end
        QueueRefresh(0)
        return
    end

    if type(navigation.SetManualWaypoint) == "function" then
        navigation:SetManualWaypoint(marker.x, marker.y, marker.mapId, marker.title)
    end
end

local function OnMarkerClick(self)
    local marker = self.questMarkerData
    if not marker then
        return
    end

    local navigation = GetNavigationModule()
    if not navigation then
        return
    end

    if IsShiftKeyDown() and type(navigation.SetManualWaypoint) == "function" then
        navigation:SetManualWaypoint(marker.x, marker.y, marker.mapId, marker.title)
        return
    end

    SelectQuestMarker(marker)
end

local function EnsureOverlay()
    local parent = GetOverlayParent()
    if not parent then
        return nil
    end

    if state.overlay and state.overlay:GetParent() ~= parent then
        state.overlay:SetParent(parent)
        state.overlay:ClearAllPoints()
        state.overlay:SetAllPoints(parent)
    end

    if state.overlay then
        return state.overlay
    end

    local overlay = CreateFrame("Frame", nil, parent)
    overlay:SetAllPoints(parent)
    overlay:SetFrameStrata(parent:GetFrameStrata())
    overlay:SetFrameLevel((parent.GetFrameLevel and parent:GetFrameLevel() or 1) + 8)
    overlay:EnableMouse(false)
    overlay:SetScript("OnSizeChanged", function()
        QueueRefresh(0)
    end)

    state.overlay = overlay
    return overlay
end

local function EnsureButton(index)
    local button = state.buttons[index]
    if button then
        return button
    end

    local overlay = EnsureOverlay()
    if not overlay then
        return nil
    end

    button = CreateFrame("Button", nil, overlay)
    button:RegisterForClicks("LeftButtonUp")
    button:SetFrameStrata(overlay:GetFrameStrata())
    button:SetScript("OnEnter", OnMarkerEnter)
    button:SetScript("OnLeave", OnMarkerLeave)
    button:SetScript("OnClick", OnMarkerClick)

    if type(button.SetBackdrop) == "function" then
        button:SetBackdrop({
            bgFile = LEATHER_TEXTURE,
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = true,
            tileSize = 32,
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
    end

    local shade = button:CreateTexture(nil, "BACKGROUND")
    shade:SetAllPoints(button)
    shade:SetTexture("Interface\\Buttons\\WHITE8x8")
    shade:SetVertexColor(0.06, 0.04, 0.02, 0.70)
    button.shade = shade

    local glow = button:CreateTexture(nil, "ARTWORK")
    glow:SetAllPoints(button)
    glow:SetTexture(GLOW_TEXTURE)
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0)
    button.glow = glow

    local icon = button:CreateTexture(nil, "OVERLAY")
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    button.icon = icon

    state.buttons[index] = button
    return button
end

local function ApplyMarkerStyle(button, marker, drawIndex)
    if not button or not marker then
        return
    end

    local recurrenceType = marker.recurrenceType
    local isTracked = marker.isTracked == true
    local baseSize = marker.category == "objective" and 15 or 20
    if isTracked then
        baseSize = baseSize + 4
    end

    button:SetSize(baseSize, baseSize)
    button:SetFrameLevel((state.overlay and state.overlay:GetFrameLevel() or button:GetFrameLevel()) + drawIndex)

    local borderR, borderG, borderB, borderA = 0.36, 0.25, 0.10, 0.40
    local iconR, iconG, iconB, iconA = 1.0, 1.0, 1.0, 1.0
    local glowAlpha = 0
    local texture = AVAILABLE_ICON_TEXTURE

    if marker.category == "turnin" then
        texture = recurrenceType == "daily" and DAILY_ACTIVE_ICON_TEXTURE or ACTIVE_ICON_TEXTURE
        borderR, borderG, borderB, borderA = 0.42, 0.66, 0.28, 0.60
        iconR, iconG, iconB, iconA = 0.98, 0.98, 0.88, 1.0
    elseif marker.category == "objective" then
        texture = OBJECTIVE_ICON_TEXTURE
        borderR, borderG, borderB, borderA = 0.76, 0.56, 0.16, 0.60
        iconR, iconG, iconB, iconA = 0.98, 0.84, 0.30, 1.0
    elseif recurrenceType == "daily" then
        texture = DAILY_ICON_TEXTURE
        borderR, borderG, borderB, borderA = 0.26, 0.48, 0.78, 0.58
        iconR, iconG, iconB, iconA = 0.72, 0.88, 1.0, 1.0
    end

    if isTracked then
        glowAlpha = 0.78
        borderR, borderG, borderB, borderA = 1.0, 0.82, 0.28, 0.84
        if marker.category == "objective" then
            iconR, iconG, iconB = 1.0, 0.90, 0.44
        end
    end

    if type(button.SetBackdropColor) == "function" then
        button:SetBackdropColor(0.05, 0.04, 0.02, 0.82)
    end
    if type(button.SetBackdropBorderColor) == "function" then
        button:SetBackdropBorderColor(borderR, borderG, borderB, borderA)
    end

    button.glow:SetAlpha(glowAlpha)
    button.icon:SetTexture(texture)
    button.icon:SetVertexColor(iconR, iconG, iconB, iconA)
    if marker.category == "objective" then
        button.icon:SetTexCoord(0, 1, 0, 1)
    else
        button.icon:SetTexCoord(0, 1, 0, 1)
    end
end

local function PositionButton(button, marker)
    local overlay = state.overlay
    if not button or not overlay or not marker then
        return
    end

    local width = overlay:GetWidth()
    local height = overlay:GetHeight()
    if not width or width <= 0 or not height or height <= 0 then
        button:Hide()
        return
    end

    button:ClearAllPoints()
    button:SetPoint("CENTER", overlay, "TOPLEFT", marker.x * width, -(marker.y * height))
end

local function InstallHooks()
    if state.hooksInstalled or type(hooksecurefunc) ~= "function" then
        return
    end

    local function RequestRefresh()
        QueueSharedWorldMapRefreshCycle(function()
            QueueRefresh(0)
            QueueRefresh(0.06)
        end)
    end

    local hookNames = {
        "WorldMapFrame_DisplayQuests",
        "WorldMapFrame_DisplayQuestPOI",
        "WorldMapFrame_UpdateQuests",
        "WorldMapFrame_SelectQuestFrame",
    }

    for i = 1, #hookNames do
        local name = hookNames[i]
        if type(_G[name]) == "function" then
            hooksecurefunc(name, RequestRefresh)
        end
    end

    if WorldMapFrame and type(WorldMapFrame.HookScript) == "function" then
        WorldMapFrame:HookScript("OnShow", RequestRefresh)
        WorldMapFrame:HookScript("OnHide", function()
            if state.overlay then
                state.overlay:Hide()
            end
            HideUnusedButtons(1)
        end)
    end

    if WorldMapButton and type(WorldMapButton.HookScript) == "function" then
        WorldMapButton:HookScript("OnShow", RequestRefresh)
        WorldMapButton:HookScript("OnSizeChanged", RequestRefresh)
    end

    state.hooksInstalled = true
end

function QuestMapPins:Refresh()
    local settings = GetSettings()
    if not settings.enabled then
        if state.overlay then
            state.overlay:Hide()
        end
        HideUnusedButtons(1)
        return
    end

    if not WorldMapFrame or not WorldMapFrame.IsShown or not WorldMapFrame:IsShown() then
        if state.overlay then
            state.overlay:Hide()
        end
        HideUnusedButtons(1)
        return
    end

    local currentMapId = GetDisplayedWorldMapId()
    if not currentMapId then
        if state.overlay then
            state.overlay:Hide()
        end
        HideUnusedButtons(1)
        return
    end

    local markers = GetVisibleMarkers(currentMapId)
    if #markers == 0 then
        if state.overlay then
            state.overlay:Hide()
        end
        HideUnusedButtons(1)
        return
    end

    local overlay = EnsureOverlay()
    if not overlay then
        return
    end
    overlay:Show()

    for index = 1, #markers do
        local marker = markers[index]
        local button = EnsureButton(index)
        if button and marker.x and marker.y then
            marker.mapId = currentMapId
            button.questMarkerData = marker
            ApplyMarkerStyle(button, marker, index)
            PositionButton(button, marker)
            button:Show()
        end
    end

    HideUnusedButtons(#markers + 1)
end

function QuestMapPins.OnInitialize()
    addon:RegisterSettingsKeywords("QuestMapPins", {
        "questie",
        "quest map",
        "world map",
        "quest markers",
        "quest starts",
        "kill markers",
        "turn in",
    })
end

function QuestMapPins.OnEnable()
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
    state.eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
    state.eventFrame:RegisterEvent("QUEST_WATCH_UPDATE")
    state.eventFrame:RegisterEvent("SUPER_TRACKING_CHANGED")

    QueueRefresh(0)
end

function QuestMapPins.OnDisable()
    if state.eventFrame then
        state.eventFrame:UnregisterAllEvents()
    end
    if state.overlay then
        state.overlay:Hide()
    end
    HideUnusedButtons(1)
end

function QuestMapPins.CreateSettings(parent)
    local settings = GetSettings()

    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Quest Map")

    local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetWidth(460)
    desc:SetJustifyH("LEFT")
    desc:SetText("Questie-style world-map pins for available quest starts plus active objective and turn-in markers, reusing DC-QOS Navigation for follow and waypoint clicks.")

    local yOffset = -76

    local enabledCb = addon:CreateCheckbox(parent)
    enabledCb:SetPoint("TOPLEFT", 16, yOffset)
    enabledCb.Text:SetText("Enable Questie-style world-map pins")
    enabledCb:SetChecked(settings.enabled ~= false)
    enabledCb:SetScript("OnClick", function(self)
        addon:SetSetting("questMapPins.enabled", self:GetChecked())
        QueueRefresh(0)
    end)
    yOffset = yOffset - 28

    local availableCb = addon:CreateCheckbox(parent)
    availableCb:SetPoint("TOPLEFT", 16, yOffset)
    availableCb.Text:SetText("Show available quest starts on the current map")
    availableCb:SetChecked(settings.showAvailable ~= false)
    availableCb:SetScript("OnClick", function(self)
        addon:SetSetting("questMapPins.showAvailable", self:GetChecked())
        QueueRefresh(0)
    end)
    yOffset = yOffset - 28

    local trivialCb = addon:CreateCheckbox(parent)
    trivialCb:SetPoint("TOPLEFT", 16, yOffset)
    trivialCb.Text:SetText("Hide trivial available starts")
    trivialCb:SetChecked(settings.hideTrivialStarts ~= false)
    trivialCb:SetScript("OnClick", function(self)
        addon:SetSetting("questMapPins.hideTrivialStarts", self:GetChecked())
        QueueRefresh(0)
    end)
    yOffset = yOffset - 28

    local objectivesCb = addon:CreateCheckbox(parent)
    objectivesCb:SetPoint("TOPLEFT", 16, yOffset)
    objectivesCb.Text:SetText("Show active quest objective markers")
    objectivesCb:SetChecked(settings.showObjectives ~= false)
    objectivesCb:SetScript("OnClick", function(self)
        addon:SetSetting("questMapPins.showObjectives", self:GetChecked())
        QueueRefresh(0)
    end)
    yOffset = yOffset - 28

    local turnInCb = addon:CreateCheckbox(parent)
    turnInCb:SetPoint("TOPLEFT", 16, yOffset)
    turnInCb.Text:SetText("Show turn-in markers for completed active quests")
    turnInCb:SetChecked(settings.showTurnIns ~= false)
    turnInCb:SetScript("OnClick", function(self)
        addon:SetSetting("questMapPins.showTurnIns", self:GetChecked())
        QueueRefresh(0)
    end)

    return yOffset - 50
end

addon:RegisterModule("QuestMapPins", QuestMapPins)