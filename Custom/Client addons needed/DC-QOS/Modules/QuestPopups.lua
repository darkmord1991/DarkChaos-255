-- ============================================================
-- DC-QoS: Auto-Quest Popups (retail-style quest flow)
-- ============================================================
-- Ascension-inspired modern quest UX: the server (module QPOP,
-- dc_addon_questflow.cpp) pushes "quest available" popups on zone entry and
-- "ready to turn in" popups when a remote-completable quest's objectives
-- finish. Accepting/completing happens remotely over the DC addon protocol -
-- no questgiver visit. Popups stack under the minimap/tracker area.
-- ============================================================

local addon = DCQOS
if not addon then
    return
end

local QuestPopups = {
    displayName = "QuestPopups",
    settingKey = "questPopups",
    icon = "Interface\\Icons\\INV_Misc_Note_02",
    defaults = {
        questPopups = {
            enabled = true,
            playSounds = true,
        },
    },
}

local LEATHER_TEXTURE = "Interface\\DC\\Shared\\FelLeather_512.tga"
local MAX_POPUPS = 3
local POPUP_WIDTH = 260
local POPUP_HEIGHT = 64

local state = {
    popups = {},          -- active popup frames (stacked top to bottom)
    pool = {},            -- reusable frames
    handlersRegistered = false,
    eventFrame = nil,
}

local function GetSettings()
    return addon.settings and addon.settings.questPopups or QuestPopups.defaults.questPopups
end

local function GetDC()
    return rawget(_G, "DCAddonProtocol")
end

local function PlayPopupSound(name)
    if GetSettings().playSounds and type(PlaySound) == "function" then
        pcall(PlaySound, name)
    end
end

local function LayoutPopups()
    local anchorY = -180
    for i, popup in ipairs(state.popups) do
        popup:ClearAllPoints()
        popup:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, anchorY - ((i - 1) * (POPUP_HEIGHT + 8)))
    end
end

local function ReleasePopup(popup)
    for i, active in ipairs(state.popups) do
        if active == popup then
            table.remove(state.popups, i)
            break
        end
    end
    popup.questId = nil
    popup.kind = nil
    popup:Hide()
    state.pool[#state.pool + 1] = popup
    LayoutPopups()
end

local function FindPopup(questId, kind)
    for _, popup in ipairs(state.popups) do
        if popup.questId == questId and (not kind or popup.kind == kind) then
            return popup
        end
    end
    return nil
end

local function HideChoiceRow(popup)
    if popup.choiceButtons then
        for _, btn in ipairs(popup.choiceButtons) do
            btn:Hide()
        end
    end
    popup.awaitingChoice = nil
end

local function AcquirePopup()
    local popup = table.remove(state.pool)
    if popup then
        return popup
    end

    popup = CreateFrame("Button", nil, UIParent)
    popup:SetSize(POPUP_WIDTH, POPUP_HEIGHT)
    popup:SetFrameStrata("HIGH")
    popup:EnableMouse(true)
    popup:SetBackdrop({
        bgFile = LEATHER_TEXTURE,
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    popup:SetBackdropColor(0.09, 0.07, 0.04, 0.96)
    popup:SetBackdropBorderColor(0.92, 0.74, 0.24, 0.9)

    popup.icon = popup:CreateTexture(nil, "ARTWORK")
    popup.icon:SetSize(34, 34)
    popup.icon:SetPoint("LEFT", popup, "LEFT", 10, 6)

    popup.header = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    popup.header:SetPoint("TOPLEFT", popup, "TOPLEFT", 52, -8)
    popup.header:SetTextColor(0.92, 0.78, 0.30)

    popup.title = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    popup.title:SetPoint("TOPLEFT", popup.header, "BOTTOMLEFT", 0, -2)
    popup.title:SetWidth(POPUP_WIDTH - 96)
    popup.title:SetJustifyH("LEFT")
    popup.title:SetHeight(24)

    popup.action = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    popup.action:SetSize(74, 20)
    popup.action:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -26, 7)
    popup.action:SetScript("OnClick", function(self)
        QuestPopups.OnActionClick(self:GetParent())
    end)

    popup.close = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
    popup.close:SetSize(22, 22)
    popup.close:SetPoint("TOPRIGHT", popup, "TOPRIGHT", 0, 0)
    popup.close:SetScript("OnClick", function(self)
        ReleasePopup(self:GetParent())
    end)

    return popup
end

-- Reward-choice flyout: small icon buttons under the popup, one per choice item.
local function ShowChoiceRow(popup, choices)
    popup.choiceButtons = popup.choiceButtons or {}
    local shown = 0
    for i, itemId in ipairs(choices) do
        if i > 6 then
            break
        end
        local btn = popup.choiceButtons[i]
        if not btn then
            btn = CreateFrame("Button", nil, popup)
            btn:SetSize(28, 28)
            btn.icon = btn:CreateTexture(nil, "ARTWORK")
            btn.icon:SetAllPoints(btn)
            btn:SetBackdrop({
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })
            btn:SetBackdropBorderColor(0.92, 0.74, 0.24, 0.8)
            btn:SetScript("OnEnter", function(self)
                if self.itemId and GameTooltip then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetHyperlink("item:" .. self.itemId)
                    GameTooltip:Show()
                end
            end)
            btn:SetScript("OnLeave", function()
                if GameTooltip then
                    GameTooltip:Hide()
                end
            end)
            btn:SetScript("OnClick", function(self)
                local parent = self:GetParent()
                QuestPopups.SendComplete(parent, self.choiceIndex - 1)
            end)
            popup.choiceButtons[i] = btn
        end

        btn.itemId = itemId
        btn.choiceIndex = i
        local icon = (type(GetItemIcon) == "function" and GetItemIcon(itemId))
            or "Interface\\Icons\\INV_Misc_QuestionMark"
        btn.icon:SetTexture(icon)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", popup, "BOTTOMLEFT", 10 + (i - 1) * 32, -2)
        btn:Show()
        shown = shown + 1
    end
    popup.awaitingChoice = shown > 0
end

function QuestPopups.SendComplete(popup, choiceIndex)
    local DC = GetDC()
    if not DC or type(DC.Request) ~= "function" or not popup.questId then
        return
    end

    DC:Request("QPOP", 0x02, { q = popup.questId, c = choiceIndex or 0 })
    PlayPopupSound("QUESTCOMPLETED")
    HideChoiceRow(popup)
    ReleasePopup(popup)
end

function QuestPopups.OnActionClick(popup)
    local DC = GetDC()
    if not DC or type(DC.Request) ~= "function" or not popup.questId then
        return
    end

    if popup.kind == "offer" then
        DC:Request("QPOP", 0x01, { q = popup.questId })
        PlayPopupSound("igQuestListOpen")
        ReleasePopup(popup)
    elseif popup.kind == "complete" then
        local choices = popup.choices or {}
        if #choices > 1 then
            -- Multiple reward choices: reveal the icon row, pick one to finish.
            if popup.awaitingChoice then
                HideChoiceRow(popup)
            else
                ShowChoiceRow(popup, choices)
            end
        else
            QuestPopups.SendComplete(popup, 0)
        end
    end
end

local function ShowPopup(kind, questId, title, level, choices)
    if not GetSettings().enabled then
        return
    end
    if FindPopup(questId, kind) then
        return
    end

    -- A completion popup supersedes an offer popup for the same quest.
    local offer = FindPopup(questId, "offer")
    if offer and kind == "complete" then
        ReleasePopup(offer)
    end

    while #state.popups >= MAX_POPUPS do
        ReleasePopup(state.popups[1])
    end

    local popup = AcquirePopup()
    popup.questId = questId
    popup.kind = kind
    popup.choices = choices
    HideChoiceRow(popup)

    if kind == "offer" then
        popup.header:SetText("Quest Available")
        popup.icon:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
        popup.action:SetText("Accept")
        PlayPopupSound("igQuestListOpen")
    else
        popup.header:SetText("Ready to Turn In")
        popup.icon:SetTexture("Interface\\GossipFrame\\ActiveQuestIcon")
        popup.action:SetText("Complete")
        PlayPopupSound("QUESTADDED")
    end

    local titleText = tostring(title or ("Quest " .. tostring(questId)))
    if level and tonumber(level) and tonumber(level) > 0 then
        titleText = string.format("[%d] %s", tonumber(level), titleText)
    end
    popup.title:SetText(titleText)

    state.popups[#state.popups + 1] = popup
    popup:Show()
    LayoutPopups()
end

local function IsQuestInLog(questId)
    for i = 1, (type(GetNumQuestLogEntries) == "function" and GetNumQuestLogEntries() or 0) do
        local _, _, _, _, isHeader = GetQuestLogTitle(i)
        if not isHeader then
            local id = type(addon.GetQuestIdFromLogIndex) == "function"
                and addon:GetQuestIdFromLogIndex(i) or nil
            if not id and type(GetQuestLink) == "function" then
                local link = GetQuestLink(i)
                if link then
                    id = tonumber(link:match("quest:(%d+)"))
                end
            end
            if id == questId then
                return true
            end
        end
    end
    return false
end

local function PruneStalePopups()
    for i = #state.popups, 1, -1 do
        local popup = state.popups[i]
        if popup.kind == "offer" and IsQuestInLog(popup.questId) then
            ReleasePopup(popup) -- accepted through other means
        elseif popup.kind == "complete" and not IsQuestInLog(popup.questId) then
            ReleasePopup(popup) -- turned in / abandoned through other means
        end
    end
end

local function RegisterHandlers()
    if state.handlersRegistered then
        return
    end

    local DC = GetDC()
    if not DC or type(DC.RegisterHandler) ~= "function" then
        return
    end

    DC:RegisterHandler("QPOP", 0x10, function(data)
        if type(data) == "table" and data.q then
            ShowPopup("offer", tonumber(data.q), data.t, data.l)
        end
    end)

    DC:RegisterHandler("QPOP", 0x11, function(data)
        if type(data) == "table" and data.q then
            local choices = {}
            if type(data.ch) == "table" then
                for _, itemId in ipairs(data.ch) do
                    choices[#choices + 1] = tonumber(itemId)
                end
            end
            ShowPopup("complete", tonumber(data.q), data.t, nil, choices)
        end
    end)

    state.handlersRegistered = true
end

function QuestPopups.OnEnable()
    RegisterHandlers()

    if not state.eventFrame then
        state.eventFrame = CreateFrame("Frame")
        state.eventFrame:SetScript("OnEvent", function()
            if type(addon.DelayedCall) == "function" then
                addon:DelayedCall(0.1, PruneStalePopups)
            else
                PruneStalePopups()
            end
        end)
    end
    state.eventFrame:UnregisterAllEvents()
    state.eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
end

function QuestPopups.OnDisable()
    if state.eventFrame then
        state.eventFrame:UnregisterAllEvents()
    end
    for i = #state.popups, 1, -1 do
        ReleasePopup(state.popups[i])
    end
end

function QuestPopups.CreateSettings(parent)
    local settings = GetSettings()

    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Quest Popups")

    local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetWidth(460)
    desc:SetJustifyH("LEFT")
    desc:SetText("Retail-style quest flow: zone quest offers and remote turn-in popups pushed by the server.")

    local yOffset = -76

    local enabledCb = addon:CreateCheckbox(parent)
    enabledCb:SetPoint("TOPLEFT", 16, yOffset)
    enabledCb.Text:SetText("Enable auto-quest popups")
    enabledCb:SetChecked(settings.enabled ~= false)
    enabledCb:SetScript("OnClick", function(self)
        addon:SetSetting("questPopups.enabled", self:GetChecked())
    end)
    yOffset = yOffset - 28

    local soundCb = addon:CreateCheckbox(parent)
    soundCb:SetPoint("TOPLEFT", 16, yOffset)
    soundCb.Text:SetText("Play popup sounds")
    soundCb:SetChecked(settings.playSounds ~= false)
    soundCb:SetScript("OnClick", function(self)
        addon:SetSetting("questPopups.playSounds", self:GetChecked())
    end)

    return yOffset - 50
end

addon:RegisterModule("QuestPopups", QuestPopups)
