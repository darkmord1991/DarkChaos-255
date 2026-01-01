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

-- Match DC-Leaderboards UI style across DC addons
local BG_FELLEATHER = "Interface\\AddOns\\DC-MythicPlus\\Textures\\Backgrounds\\FelLeather_512.tga"
local BG_TINT_ALPHA = 0.60

local function ApplyLeaderboardsStyle(frame)
    if not frame or frame.__dcLeaderboardsStyle then return end
    frame.__dcLeaderboardsStyle = true

    if frame.SetBackdropColor then
        frame:SetBackdropColor(0, 0, 0, 0)
    end

    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
    bg:SetAllPoints()
    bg:SetTexture(BG_FELLEATHER)
    if bg.SetHorizTile then bg:SetHorizTile(false) end
    if bg.SetVertTile then bg:SetVertTile(false) end

    local tint = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    tint:SetAllPoints()
    tint:SetTexture(0, 0, 0, BG_TINT_ALPHA)

    frame.__dcBg = bg
    frame.__dcTint = tint
end

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

    frame = CreateFrame("Frame", "DCMythicPlusGreatVaultFrame", UIParent)
    frame:SetSize(740, 600) -- Increased height to fit separators
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")

    -- Background (WotLK/Retail style)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    ApplyLeaderboardsStyle(frame)

    -- Title
    frame.TitleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.TitleText:SetPoint("TOP", 0, -15)
    frame.TitleText:SetText("The Great Vault")
    frame.TitleText:SetTextColor(1, 0.82, 0, 1)

    -- Close Button
    frame.CloseButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.CloseButton:SetPoint("TOPRIGHT", -5, -5)
    frame.CloseButton:SetScript("OnClick", function() frame:Hide() end)

    -- Subtitle
    frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.subtitle:SetPoint("TOP", 0, -40)
    frame.subtitle:SetText("Earn rewards from Raid, Mythic+, and PvP")
    frame.subtitle:SetTextColor(1, 0.82, 0, 1)

    frame.tracks = {}
    frame.slotByGlobalId = {}

    local trackTitles = { "Raid", "Mythic+", "PvP" }
    for trackIndex = 1, TRACK_COUNT do
        local track = CreateFrame("Frame", nil, frame)
        track:SetSize(3 * SLOT_WIDTH + 2 * PADDING_X + 20, SLOT_HEIGHT + 45)
        track:SetPoint(
            "TOPLEFT",
            10,
            -60 - (trackIndex - 1) * (SLOT_HEIGHT + 50)
        )

        -- Track Background/Separator
        track.bg = track:CreateTexture(nil, "BACKGROUND")
        track.bg:SetAllPoints()
        track.bg:SetColorTexture(0.25, 0.25, 0.25, 0.5)

        track.border = {}
        track.border.T = track:CreateTexture(nil, "BORDER"); track.border.T:SetPoint("TOPLEFT"); track.border.T:SetPoint("TOPRIGHT"); track.border.T:SetHeight(1); track.border.T:SetColorTexture(0.5, 0.5, 0.5, 1)
        track.border.B = track:CreateTexture(nil, "BORDER"); track.border.B:SetPoint("BOTTOMLEFT"); track.border.B:SetPoint("BOTTOMRIGHT"); track.border.B:SetHeight(1); track.border.B:SetColorTexture(0.5, 0.5, 0.5, 1)
        track.border.L = track:CreateTexture(nil, "BORDER"); track.border.L:SetPoint("TOPLEFT"); track.border.L:SetPoint("BOTTOMLEFT"); track.border.L:SetWidth(1); track.border.L:SetColorTexture(0.5, 0.5, 0.5, 1)
        track.border.R = track:CreateTexture(nil, "BORDER"); track.border.R:SetPoint("TOPRIGHT"); track.border.R:SetPoint("BOTTOMRIGHT"); track.border.R:SetWidth(1); track.border.R:SetColorTexture(0.5, 0.5, 0.5, 1)

        track.title = track:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        track.title:SetPoint("TOPLEFT", 10, -8)
        track.title:SetText(trackTitles[trackIndex] or "Track")
        track.title:SetTextColor(1, 0.82, 0, 1)

        track.slots = {}
        for row = 1, SLOTS_PER_TRACK do
            local slot = CreateFrame("Frame", nil, track)
            slot:SetSize(SLOT_WIDTH, SLOT_HEIGHT)
            slot:SetPoint("TOPLEFT", 10 + (row - 1) * (SLOT_WIDTH + PADDING_X), -35)

            slot.bg = slot:CreateTexture(nil, "BACKGROUND")
            slot.bg:SetAllPoints()
            slot.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)

            slot.border = {}
            slot.border.T = slot:CreateTexture(nil, "BORDER"); slot.border.T:SetPoint("TOPLEFT"); slot.border.T:SetPoint("TOPRIGHT"); slot.border.T:SetHeight(1); slot.border.T:SetColorTexture(0.3, 0.3, 0.3, 1)
            slot.border.B = slot:CreateTexture(nil, "BORDER"); slot.border.B:SetPoint("BOTTOMLEFT"); slot.border.B:SetPoint("BOTTOMRIGHT"); slot.border.B:SetHeight(1); slot.border.B:SetColorTexture(0.3, 0.3, 0.3, 1)
            slot.border.L = slot:CreateTexture(nil, "BORDER"); slot.border.L:SetPoint("TOPLEFT"); slot.border.L:SetPoint("BOTTOMLEFT"); slot.border.L:SetWidth(1); slot.border.L:SetColorTexture(0.3, 0.3, 0.3, 1)
            slot.border.R = slot:CreateTexture(nil, "BORDER"); slot.border.R:SetPoint("TOPRIGHT"); slot.border.R:SetPoint("BOTTOMRIGHT"); slot.border.R:SetWidth(1); slot.border.R:SetColorTexture(0.3, 0.3, 0.3, 1)
            
            -- slotInner removed as it's redundant with the border lines approach
            -- local slotInner = slot:CreateTexture(nil, "BACKGROUND", nil, 1) ...

            slot.title = slot:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            slot.title:SetPoint("TOPLEFT", 10, -10)
            slot.title:SetText("Reward " .. row)
            slot.title:SetTextColor(1, 0.82, 0, 1)

            slot.req = slot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            slot.req:SetPoint("TOPLEFT", slot.title, "BOTTOMLEFT", 0, -4)
            slot.req:SetText("Locked")

            slot.iconFrame = CreateFrame("Frame", nil, slot)
            slot.iconFrame:SetSize(40, 40)
            slot.iconFrame:SetPoint("LEFT", 12, 0)
            
            slot.iconFrame.border = slot.iconFrame:CreateTexture(nil, "BACKGROUND")
            slot.iconFrame.border:SetAllPoints()
            slot.iconFrame.border:SetColorTexture(0.3, 0.3, 0.3, 1)

            slot.icon = slot.iconFrame:CreateTexture(nil, "ARTWORK")
            slot.icon:SetPoint("TOPLEFT", 1, -1)
            slot.icon:SetPoint("BOTTOMRIGHT", -1, 1)
            slot.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

            slot.status = slot:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            slot.status:SetPoint("LEFT", slot.iconFrame, "RIGHT", 10, 0)
            slot.status:SetJustifyH("LEFT")
            slot.status:SetText("Locked")

            slot.button = CreateFrame("Button", nil, slot)
            slot.button:SetSize(120, 24)
            slot.button:SetPoint("BOTTOM", 0, 10)
            
            slot.button.bg = slot.button:CreateTexture(nil, "BACKGROUND")
            slot.button.bg:SetAllPoints()
            slot.button.bg:SetColorTexture(0.2, 0.2, 0.2, 1)
            
            slot.button.text = slot.button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            slot.button.text:SetPoint("CENTER")
            slot.button.text:SetText("Select")
            slot.button:SetFontString(slot.button.text)
            
            slot.button:SetScript("OnEnter", function(self)
                if self:IsEnabled() then
                    self.bg:SetColorTexture(0.3, 0.3, 0.3, 1)
                end
            end)
            slot.button:SetScript("OnLeave", function(self)
                if self:IsEnabled() then
                    self.bg:SetColorTexture(0.2, 0.2, 0.2, 1)
                else
                    self.bg:SetColorTexture(0.1, 0.1, 0.1, 1)
                end
            end)
            slot.button:SetScript("OnEnable", function(self)
                self.bg:SetColorTexture(0.2, 0.2, 0.2, 1)
                self.text:SetTextColor(1, 1, 1, 1)
            end)
            slot.button:SetScript("OnDisable", function(self)
                self.bg:SetColorTexture(0.1, 0.1, 0.1, 1)
                self.text:SetTextColor(0.5, 0.5, 0.5, 1)
            end)
            
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
