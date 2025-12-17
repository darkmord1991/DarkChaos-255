local addonName = ...
local namespace = _G.DCMythicPlusHUD or {}
_G.DCMythicPlusHUD = namespace

local GV = {}
namespace.GreatVault = GV

local frame
local itemPrefetchTooltip
local itemRetryCounts = {}
local pendingRefresh = {}

local POPUP_KEY = "DCMPLUS_CONFIRM_VAULT_CLAIM"

local function EnsureTooltip()
    if itemPrefetchTooltip then return end
    itemPrefetchTooltip = CreateFrame("GameTooltip", "DCMythicPlusVaultScanTooltip", UIParent, "GameTooltipTemplate")
    itemPrefetchTooltip:SetOwner(UIParent, "ANCHOR_NONE")
end

local function PrefetchItem(itemId)
    if not itemId then return end
    EnsureTooltip()
    itemPrefetchTooltip:SetHyperlink("item:" .. itemId)
end

local function QueueSlotRefresh(slotIndex)
    if not slotIndex then return end
    if pendingRefresh[slotIndex] then return end
    pendingRefresh[slotIndex] = true
    C_Timer.After(0.35, function()
        pendingRefresh[slotIndex] = nil
        if GV.RefreshSlot then
            GV:RefreshSlot(slotIndex)
        end
    end)
end

local function EnsurePopupDefined()
    if StaticPopupDialogs[POPUP_KEY] then
        return
    end
    StaticPopupDialogs[POPUP_KEY] = {
        text = "Are you sure you want to claim this reward?",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            if GV._pendingSlot and GV._pendingItemId then
                if namespace.ClaimVaultReward then
                    namespace.ClaimVaultReward(GV._pendingSlot, GV._pendingItemId)
                end
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

-- Constants
local TRACK_COUNT = 3
local SLOTS_PER_TRACK = 3
local SLOT_WIDTH = 230
local SLOT_HEIGHT = 120
local PADDING_X = 5
local PADDING_Y = 5

function GV:CreateFrame()
    if frame then return frame end

    frame = CreateFrame("Frame", "DCMythicPlusGreatVaultFrame", UIParent, "UIPanelDialogTemplate")
    frame:SetSize(740, 540)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")

    if frame.TitleText then
        frame.TitleText:SetText("The Great Vault")
    end
    if frame.portrait then
        SetPortraitToTexture(frame.portrait, "Interface\\Icons\\INV_Box_04")
    end
    if frame.CloseButton then
        frame.CloseButton:SetScript("OnClick", function() frame:Hide() end)
    end

    -- Subtitle
    frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.subtitle:SetPoint("TOP", 0, -52)
    frame.subtitle:SetText("Earn rewards from Raid, Mythic+, and PvP")

    frame.tracks = {}
    frame.slotByGlobalId = {}

    local trackTitles = { "Raid", "Mythic+", "PvP" }
    for trackIndex = 1, TRACK_COUNT do
        local track = CreateFrame("Frame", nil, frame)
        track:SetSize(3 * SLOT_WIDTH + 2 * PADDING_X, SLOT_HEIGHT + 30)
        track:SetPoint(
            "TOPLEFT",
            20,
            -60 - (trackIndex - 1) * (SLOT_HEIGHT + 35)
        )

        track.title = track:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        track.title:SetPoint("TOPLEFT", 5, 0)
        track.title:SetText(trackTitles[trackIndex] or "Track")

        track.slots = {}
        for row = 1, SLOTS_PER_TRACK do
            local slot = CreateFrame("Frame", nil, track)
            slot:SetSize(SLOT_WIDTH, SLOT_HEIGHT)
            slot:SetPoint("TOPLEFT", (row - 1) * (SLOT_WIDTH + PADDING_X), -25)

            slot.bg = slot:CreateTexture(nil, "BACKGROUND")
            slot.bg:SetAllPoints()
            slot.bg:SetColorTexture(0.12, 0.12, 0.12, 0.65)

            slot.border = CreateFrame("Frame", nil, slot)
            slot.border:SetAllPoints()
            slot.border:SetBackdrop({
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 12,
            })

            slot.title = slot:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            slot.title:SetPoint("TOPLEFT", 10, -10)
            slot.title:SetText("Reward " .. row)

            slot.req = slot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            slot.req:SetPoint("TOPLEFT", slot.title, "BOTTOMLEFT", 0, -4)
            slot.req:SetText("Locked")

            slot.iconFrame = CreateFrame("Frame", nil, slot)
            slot.iconFrame:SetSize(40, 40)
            slot.iconFrame:SetPoint("LEFT", 12, 0)

            slot.icon = slot.iconFrame:CreateTexture(nil, "ARTWORK")
            slot.icon:SetAllPoints()
            slot.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

            slot.status = slot:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            slot.status:SetPoint("LEFT", slot.iconFrame, "RIGHT", 10, 0)
            slot.status:SetJustifyH("LEFT")
            slot.status:SetText("Locked")

            slot.button = CreateFrame("Button", nil, slot, "UIPanelButtonTemplate")
            slot.button:SetSize(120, 24)
            slot.button:SetPoint("BOTTOM", 0, 10)
            slot.button:SetText("Select")
            slot.button:Disable()

            slot.iconFrame:SetScript("OnEnter", function(self)
                if slot.itemLink then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetHyperlink(slot.itemLink)
                    GameTooltip:Show()
                end
            end)
            slot.iconFrame:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)

            track.slots[row] = slot
        end

        frame.tracks[trackIndex] = track
    end
    
    frame:Hide()
    return frame
end

function GV:IsShown()
    return frame and frame:IsShown()
end

function GV:RefreshSlot(slotIndex)
    if not frame then return end
    local slotFrame = frame.slotByGlobalId and frame.slotByGlobalId[slotIndex]
    if not slotFrame or not slotFrame.itemId then return end

    local _, link, _, _, _, _, _, _, _, icon = GetItemInfo(slotFrame.itemId)
    if icon then
        slotFrame.icon:SetTexture(icon)
        slotFrame.icon:SetDesaturated(false)
        slotFrame.itemLink = link or slotFrame.itemLink
        itemRetryCounts[slotFrame.itemId] = nil
        return
    end

    local tries = (itemRetryCounts[slotFrame.itemId] or 0) + 1
    itemRetryCounts[slotFrame.itemId] = tries
    if tries <= 6 then
        PrefetchItem(slotFrame.itemId)
        QueueSlotRefresh(slotIndex)
    end
end

function GV:Show()
    local f = self:CreateFrame()
    f:Show()
    if namespace.RequestVaultInfo then
        namespace.RequestVaultInfo()
    end
end

function GV:Hide()
    if frame then frame:Hide() end
end

function GV:Toggle()
    if frame and frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function GV:Update(data)
    if not frame then
        self:CreateFrame()
    end

    if data.open then
        frame:Show()
    end

    local tracks = data.tracks
    if type(tracks) ~= "table" then
        return
    end

    -- Reset mapping each update
    frame.slotByGlobalId = {}

    for trackIndex, trackData in ipairs(tracks) do
        local trackFrame = frame.tracks[trackIndex]
        if trackFrame and trackData.name then
            trackFrame.title:SetText(trackData.name)
        end

        local slots = trackData.slots or {}
        for row, slotData in ipairs(slots) do
            local slotFrame = trackFrame and trackFrame.slots and trackFrame.slots[row]
            if slotFrame then
                local globalId = slotData.globalId
                slotFrame.globalId = globalId
                if globalId then
                    frame.slotByGlobalId[globalId] = slotFrame
                end

                slotFrame.itemLink = nil
                slotFrame.itemId = nil

                local status = slotData.status
                local threshold = tonumber(slotData.threshold or 0) or 0
                local progress = tonumber(slotData.progress or 0) or 0

                local progressLabel = "Progress"
                if trackData.id == "raid" then
                    progressLabel = "Bosses"
                elseif trackData.id == "mplus" then
                    progressLabel = "Runs"
                elseif trackData.id == "pvp" then
                    progressLabel = "Wins"
                end

                slotFrame.title:SetText("Reward " .. row)

                if status == "claimed" then
                    slotFrame.status:SetText("Claimed")
                    slotFrame.status:SetTextColor(0.5, 0.5, 0.5)
                    slotFrame.icon:SetTexture("Interface\\Icons\\INV_Box_01")
                    slotFrame.icon:SetDesaturated(true)
                    slotFrame.button:SetText("Claimed")
                    slotFrame.button:Disable()
                    slotFrame.req:SetText("Reward Claimed")
                elseif status == "unlocked" then
                    local rewards = slotData.rewards
                    if rewards and #rewards > 0 then
                        local reward = rewards[1]
                        local itemId = reward.itemId
                        local ilvl = reward.ilvl

                        slotFrame.itemId = itemId

                        local _, link, _, _, _, _, _, _, _, icon = GetItemInfo(itemId)
                        if icon then
                            slotFrame.icon:SetTexture(icon)
                        else
                            slotFrame.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                            PrefetchItem(itemId)
                            if globalId then
                                QueueSlotRefresh(globalId)
                            end
                        end

                        slotFrame.icon:SetDesaturated(false)
                        slotFrame.itemLink = link or ("item:" .. itemId)

                        slotFrame.status:SetText("iLvl " .. tostring(ilvl))
                        slotFrame.status:SetTextColor(0, 1, 0)
                        slotFrame.button:SetText("Select")
                        slotFrame.button:Enable()
                        slotFrame.req:SetText(string.format("Unlocked (%s %d/%d)", progressLabel, progress, threshold))

                        slotFrame.button:SetScript("OnClick", function()
                            if globalId then
                                GV:SelectReward(globalId)
                            end
                        end)
                    else
                        slotFrame.status:SetText("Unavailable")
                        slotFrame.status:SetTextColor(1, 0.5, 0)
                        slotFrame.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                        slotFrame.icon:SetDesaturated(true)
                        slotFrame.button:SetText("Select")
                        slotFrame.button:Disable()
                        slotFrame.req:SetText("Waiting for rewards")
                    end
                else
                    slotFrame.status:SetText("Locked")
                    slotFrame.status:SetTextColor(1, 0, 0)
                    slotFrame.icon:SetTexture("Interface\\Icons\\INV_Misc_Lock_01")
                    slotFrame.icon:SetDesaturated(false)
                    slotFrame.button:SetText("Locked")
                    slotFrame.button:Disable()
                    slotFrame.req:SetText(string.format("Complete %d %s (%d/%d)", threshold, progressLabel, progress, threshold))
                end
            end
        end
    end
end

function GV:SelectReward(slotIndex)
    local slotFrame = frame.slotByGlobalId and frame.slotByGlobalId[slotIndex]
    if not slotFrame or not slotFrame.itemId then return end

    GV._pendingSlot = slotIndex
    GV._pendingItemId = slotFrame.itemId
    EnsurePopupDefined()
    StaticPopup_Show(POPUP_KEY)
end
