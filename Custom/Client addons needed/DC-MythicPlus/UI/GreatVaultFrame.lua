local addonName = ...
local namespace = _G.DCMythicPlusHUD or {}
_G.DCMythicPlusHUD = namespace

local GV = {}
namespace.GreatVault = GV

-- The retail Great Vault (Blizzard_WeeklyRewards, "evergreen" art) rebuilt for
-- 3.3.5. The art is repacked into two 1024px sheets by
-- tools/build_greatvault_retail_atlas.py; VAULT_ATLAS mirrors the rect table
-- that script prints. Offsets below are the retail XML's, so the panel lines up
-- with its art at 1:1.

local frame
local scanTooltip
local primedItems = {}

local POPUP_KEY = "DCMPLUS_CONFIRM_VAULT_CLAIM"
local FRAME_NAME = "DCMythicPlusGreatVaultFrame"

local ATLAS_ROOT = "Interface\\AddOns\\DC-MythicPlus\\Textures\\RetailAtlas\\"
local SHEET_SIZE = 1024
local QUESTION_MARK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local CHECKMARK_TEXTURE = "Interface\\RAIDFRAME\\ReadyCheck-Ready"
local FANCY_FONT = "Fonts\\MORPHEUS.TTF"

-- name -> { sheet, x, y, packed width, packed height, retail width, retail height }
-- The retail size differs from the packed one only where a member was scaled
-- down to fit its sheet.
local VAULT_ATLAS = {
    ["frame-back"] = { "GreatVaultFrame", 0, 0, 1024, 643, 1134, 712 },
    ["category-raids"] = { "GreatVaultFrame", 0, 646, 405, 172, 405, 172 },
    ["category-dungeons"] = { "GreatVaultFrame", 408, 646, 422, 177, 422, 177 },
    ["category-pvp"] = { "GreatVaultFrame", 0, 826, 421, 152, 421, 152 },
    ["frame-topdecor"] = { "GreatVaultFrame", 424, 826, 229, 103, 229, 103 },
    ["frame-selectbutton"] = { "GreatVaultFrame", 656, 826, 209, 31, 209, 31 },
    ["frame"] = { "GreatVaultCards", 0, 0, 1024, 577, 1175, 662 },
    ["reward-locked"] = { "GreatVaultCards", 0, 580, 218, 125, 218, 125 },
    ["reward-unlocked"] = { "GreatVaultCards", 221, 580, 218, 125, 218, 125 },
    ["reward-selected"] = { "GreatVaultCards", 442, 580, 214, 121, 214, 121 },
    ["reward-unselected"] = { "GreatVaultCards", 659, 580, 215, 122, 215, 122 },
    ["reward-selected-sideglow"] = { "GreatVaultCards", 0, 708, 260, 163, 260, 163 },
    ["reward-selected-outerglow"] = { "GreatVaultCards", 263, 708, 234, 141, 234, 141 },
    ["reward-fx-backglow"] = { "GreatVaultCards", 500, 708, 168, 115, 168, 115 },
    ["reward-itemframe"] = { "GreatVaultCards", 671, 708, 156, 51, 156, 51 },
    ["header"] = { "GreatVaultCards", 0, 874, 735, 15, 735, 15 },
    ["divider"] = { "GreatVaultCards", 0, 892, 1020, 7, 1057, 7 },
}

local FRAME_WIDTH = 1165
-- Retail is 657 tall; the extra strip at the bottom holds the view tabs.
local FRAME_HEIGHT = 717
local FRAME_LEVEL = 10

local ROW_Y = { -149, -307, -470 }
local DIVIDER_Y = { -291, -446 }
local CARDS_PER_ROW = 3

local TRACK_STYLE = {
    raid = { atlas = "category-raids", name = "Raids" },
    mplus = { atlas = "category-dungeons", name = "Mythic+" },
    pvp = { atlas = "category-pvp", name = "PvP" },
    history = { atlas = "category-dungeons", name = "Latest Runs" },
}

local VIEW_TABS = {
    { view = "claim", label = "Rewards" },
    { view = "progress", label = "This Week" },
    { view = "history", label = "Run History" },
}
local TAB_WIDTH = 150
local TAB_HEIGHT = 26
local TAB_GAP = 12

local QUALITY_HEX = {
    [0] = "9d9d9d", [1] = "ffffff", [2] = "1eff00", [3] = "0070dd",
    [4] = "a335ee", [5] = "ff8000", [6] = "e6cc80", [7] = "00ccff",
}

local UNLOCK_ORDINAL = { "a", "a second", "a third" }

local SECONDS_PER_WEEK = 7 * 24 * 60 * 60

local function SetShown(region, shown)
    if shown then
        region:Show()
    else
        region:Hide()
    end
end

local function SetEnabled(button, enabled)
    if enabled then
        button:Enable()
    else
        button:Disable()
    end
end

local function PlaySoundSafe(sound)
    if PlaySound then
        PlaySound(sound)
    end
end

local function IsTruthy(value)
    return value == true or value == 1 or value == "1"
end

local function Plural(count, one, many)
    if count == 1 then
        return one
    end
    return many
end

local function SetAtlas(texture, name, useAtlasSize)
    local entry = VAULT_ATLAS[name]
    texture:SetTexture(ATLAS_ROOT .. entry[1] .. ".blp")
    texture:SetTexCoord(entry[2] / SHEET_SIZE, (entry[2] + entry[4]) / SHEET_SIZE,
        entry[3] / SHEET_SIZE, (entry[3] + entry[5]) / SHEET_SIZE)
    if useAtlasSize then
        texture:SetSize(entry[6], entry[7])
    end
end

local function FormatWeekRange(weekStart)
    weekStart = tonumber(weekStart or 0) or 0
    if weekStart <= 0 then
        return "Unknown"
    end
    return date("%Y-%m-%d", weekStart) .. " - " .. date("%Y-%m-%d", weekStart + SECONDS_PER_WEEK)
end

local function FormatDateTime(ts)
    ts = tonumber(ts or 0) or 0
    if ts <= 0 then
        return "Unknown"
    end
    return date("%Y-%m-%d %H:%M", ts)
end

local function FormatRunDuration(seconds)
    seconds = tonumber(seconds or 0) or 0
    if seconds <= 0 then
        return "--:--"
    end
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

-- ---------------------------------------------------------------------------
-- Items
-- ---------------------------------------------------------------------------

-- GetItemInfo() is nil until the client has cached the item, and nothing here
-- fetched it reliably, so the slot fell back to a question mark even for stock
-- items. GetItemIcon() reads the client's Item.dbc and needs no cache; the
-- server-shipped icon covers custom entries that Item.dbc does not know.
local function ResolveRewardIcon(reward, itemId)
    local icon = GetItemIcon and GetItemIcon(itemId)
    if icon and icon ~= "" then
        return icon
    end

    if type(reward.icon) == "string" and reward.icon ~= "" then
        if reward.icon:find("\\", 1, true) then
            return reward.icon
        end
        return "Interface\\Icons\\" .. reward.icon
    end

    return select(10, GetItemInfo(itemId)) or QUESTION_MARK_ICON
end

local function ResolveRewardName(reward, itemId)
    local name, _, quality = GetItemInfo(itemId)
    name = name or reward.itemName
    if not name or name == "" then
        name = "Item #" .. itemId
    end
    return name, quality or tonumber(reward.quality or -1)
end

local function QualityColor(quality)
    local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if color then
        return color.r, color.g, color.b
    end
    return 1, 1, 1
end

local function ColoredName(reward)
    local itemId = tonumber(reward.itemId)
    local name, quality = ResolveRewardName(reward, itemId)
    local hex = QUALITY_HEX[quality]
    if hex then
        return "|cff" .. hex .. name .. "|r"
    end
    return name
end

local function BuildItemLink(itemId, reward)
    local link = select(2, GetItemInfo(itemId))
    if link then
        return link
    end
    local name, quality = ResolveRewardName(reward, itemId)
    return string.format("|cff%s|Hitem:%d:0:0:0:0:0:0:0:0|h[%s]|h|r", QUALITY_HEX[quality] or "ffffff", itemId, name)
end

-- Ask the server for the item so tooltips and links resolve. SetHyperlink only
-- sends the query while the tooltip has an owner, and hiding a tooltip clears
-- it, so the owner is set on every call.
local function PrimeItem(itemId)
    if primedItems[itemId] or GetItemInfo(itemId) then
        return
    end
    primedItems[itemId] = true

    -- The protocol batches every row of the vault into one prefetch request.
    local protocol = rawget(_G, "DCAddonProtocol")
    if protocol and type(protocol.PrefetchItems) == "function" then
        protocol:PrefetchItems({ itemId })
        return
    end

    if not scanTooltip then
        scanTooltip = CreateFrame("GameTooltip", "DCMythicPlusVaultScanTooltip", UIParent, "GameTooltipTemplate")
    end
    scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    scanTooltip:SetHyperlink("item:" .. itemId)
    scanTooltip:Hide()
end

local ItemOnEnter

-- An uncached item opens as "Retrieving item information", and the client does
-- not redraw the tooltip when the query answer arrives. Poll while the tooltip
-- is still ours and set it again once the item is in the cache.
local function ItemTooltipOnUpdate(self, elapsed)
    self.tooltipElapsed = (self.tooltipElapsed or 0) + elapsed
    if self.tooltipElapsed < 0.2 then
        return
    end
    self.tooltipElapsed = 0

    if GameTooltip:GetOwner() ~= self or not self.itemId then
        self:SetScript("OnUpdate", nil)
    elseif GetItemInfo(self.itemId) then
        ItemOnEnter(self)
    end
end

function ItemOnEnter(self)
    if not self.itemId then
        return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT", -3, -6)
    GameTooltip:SetHyperlink("item:" .. self.itemId)
    GameTooltip:Show()

    if GetItemInfo(self.itemId) then
        self:SetScript("OnUpdate", nil)
    else
        self.tooltipElapsed = 0
        self:SetScript("OnUpdate", ItemTooltipOnUpdate)
    end
end

local function ItemOnLeave(self)
    self:SetScript("OnUpdate", nil)
    GameTooltip:Hide()
end

local function ItemOnClick(self)
    if self.itemId and IsModifiedClick and IsModifiedClick() and HandleModifiedItemClick then
        HandleModifiedItemClick(BuildItemLink(self.itemId, self.reward))
        return
    end
    GV:SelectCard(self:GetParent())
end

local function SetItem(itemFrame, reward)
    local itemId = tonumber(reward.itemId)
    PrimeItem(itemId)

    itemFrame.itemId = itemId
    itemFrame.reward = reward
    itemFrame.Icon:SetTexture(ResolveRewardIcon(reward, itemId))

    local name, quality = ResolveRewardName(reward, itemId)
    itemFrame.Name:SetText(name)
    itemFrame.Name:SetTextColor(QualityColor(quality))
    itemFrame:Show()
end

-- ---------------------------------------------------------------------------
-- Popup
-- ---------------------------------------------------------------------------

local function EnsurePopupDefined()
    if StaticPopupDialogs[POPUP_KEY] then
        return
    end
    StaticPopupDialogs[POPUP_KEY] = {
        text = "You will be unable to change this reward once it is selected.\n\nAre you sure you wish to select %s?",
        button1 = YES or "Yes",
        button2 = CANCEL or "Cancel",
        OnAccept = function()
            if GV._pendingSlot and GV._pendingItemId and namespace.ClaimVaultReward then
                PlaySoundSafe("LOOTWINDOWCOINSOUND")
                namespace.ClaimVaultReward(GV._pendingSlot, GV._pendingItemId)
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        showAlert = true,
        preferredIndex = 3,
    }
end

-- ---------------------------------------------------------------------------
-- Frame construction
-- ---------------------------------------------------------------------------

local function CreateCard(row, level)
    local card = CreateFrame("Frame", nil, row)
    card:SetSize(219, 126)
    card:SetFrameLevel(level)
    card:EnableMouse(true)

    card.Background = card:CreateTexture(nil, "BACKGROUND")
    card.Background:SetPoint("BOTTOMRIGHT")

    card.UncollectedGlow = card:CreateTexture(nil, "BORDER")
    SetAtlas(card.UncollectedGlow, "reward-fx-backglow", true)
    card.UncollectedGlow:SetPoint("BOTTOMLEFT", 2, 2)
    card.UncollectedGlow:SetBlendMode("ADD")
    card.UncollectedGlow:Hide()

    card.Threshold = card:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    card.Threshold:SetPoint("TOPLEFT", 36, -16)
    card.Threshold:SetWidth(172)
    card.Threshold:SetJustifyH("LEFT")

    card.Detail = card:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    card.Detail:SetPoint("TOPLEFT", card.Threshold, "BOTTOMLEFT", 0, -6)
    card.Detail:SetWidth(172)
    card.Detail:SetJustifyH("LEFT")

    card.Progress = card:CreateFontString(nil, "ARTWORK", "GameFontGreen")
    card.Progress:SetPoint("BOTTOMRIGHT", -15, 15)

    card.CompletedIcon = card:CreateTexture(nil, "ARTWORK")
    card.CompletedIcon:SetSize(20, 20)
    card.CompletedIcon:SetPoint("TOPLEFT", 10, -12)
    card.CompletedIcon:SetTexture(CHECKMARK_TEXTURE)

    card.SelectedTexture = card:CreateTexture(nil, "OVERLAY")
    SetAtlas(card.SelectedTexture, "reward-selected", true)
    card.SelectedTexture:SetPoint("CENTER")
    card.SelectedTexture:Hide()

    -- Retail spins a masked edge glow here; 3.3.5 has no mask textures, so the
    -- outer and side glows just pulse.
    local glow = CreateFrame("Frame", nil, row)
    glow:SetSize(260, 163)
    glow:SetPoint("CENTER", card)
    glow:SetFrameLevel(level - 1)
    local outerGlow = glow:CreateTexture(nil, "ARTWORK")
    SetAtlas(outerGlow, "reward-selected-outerglow", true)
    outerGlow:SetPoint("CENTER")
    local sideGlow = glow:CreateTexture(nil, "ARTWORK", nil, 1)
    SetAtlas(sideGlow, "reward-selected-sideglow", true)
    sideGlow:SetPoint("CENTER")
    glow:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        self:SetAlpha(0.875 + 0.125 * math.cos(self.elapsed * math.pi))
    end)
    glow:Hide()
    card.SelectionGlow = glow

    local item = CreateFrame("Button", nil, card)
    item:SetSize(155, 49)
    item:SetPoint("CENTER", 2, -7)
    item:SetFrameLevel(level + 2)
    item.Icon = item:CreateTexture(nil, "BACKGROUND")
    item.Icon:SetSize(37, 37)
    item.Icon:SetPoint("LEFT", 3, 2)
    item.Border = item:CreateTexture(nil, "BORDER")
    SetAtlas(item.Border, "reward-itemframe", true)
    item.Border:SetPoint("CENTER")
    item.Name = item:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    item.Name:SetPoint("LEFT", 51, 0)
    item.Name:SetSize(92, 44)
    item.Name:SetJustifyH("LEFT")
    item.Name:SetJustifyV("MIDDLE")
    item:SetScript("OnEnter", ItemOnEnter)
    item:SetScript("OnLeave", ItemOnLeave)
    item:SetScript("OnClick", ItemOnClick)
    item:Hide()
    card.ItemFrame = item

    local dim = CreateFrame("Frame", nil, card)
    dim:SetAllPoints()
    dim:SetFrameLevel(level + 5)
    local dimTexture = dim:CreateTexture(nil, "OVERLAY")
    SetAtlas(dimTexture, "reward-unselected", true)
    dimTexture:SetPoint("CENTER")
    dim:Hide()
    card.UnselectedFrame = dim

    card:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            GV:SelectCard(self)
        end
    end)
    card:SetScript("OnEnter", function(self)
        GV:ShowCardTooltip(self)
    end)
    card:SetScript("OnLeave", function(self)
        -- The card shows its reward's tooltip, so stop that item's wait too.
        ItemOnLeave(self.ItemFrame)
    end)

    return card
end

local function CreateTab(info, xOffset)
    local tab = CreateFrame("Button", nil, frame)
    tab:SetSize(TAB_WIDTH, TAB_HEIGHT)
    tab:SetPoint("BOTTOM", frame, "BOTTOM", xOffset, 40)
    tab:SetFrameLevel(FRAME_LEVEL + 25)
    tab.view = info.view

    tab.Background = tab:CreateTexture(nil, "BACKGROUND")
    SetAtlas(tab.Background, "frame-selectbutton")
    tab.Background:SetAllPoints()

    tab.Text = tab:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    tab.Text:SetPoint("CENTER", 0, 1)
    tab.Text:SetText(info.label)

    tab:SetScript("OnClick", function(self)
        PlaySoundSafe("igMainMenuOptionCheckBoxOn")
        GV:SetView(self.view)
    end)
    tab:SetScript("OnEnter", function(self)
        self.Text:SetTextColor(1, 1, 1)
    end)
    tab:SetScript("OnLeave", function()
        GV:UpdateTabs()
    end)
    return tab
end

local function FitToScreen(self)
    local width = UIParent:GetWidth() or FRAME_WIDTH
    local height = UIParent:GetHeight() or FRAME_HEIGHT
    self:SetScale(math.min(1, (width - 40) / FRAME_WIDTH, (height - 40) / FRAME_HEIGHT))
end

function GV:CreateFrame()
    if frame then
        return frame
    end

    frame = CreateFrame("Frame", FRAME_NAME, UIParent)
    GV.frame = frame
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(FRAME_LEVEL)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetScript("OnShow", function(self)
        FitToScreen(self)
        PlaySoundSafe("igCharacterInfoOpen")
    end)
    frame:SetScript("OnHide", function()
        GV.selectedCard = nil
        if StaticPopup_Hide then
            StaticPopup_Hide(POPUP_KEY)
        end
        PlaySoundSafe("igCharacterInfoClose")
    end)
    if UISpecialFrames then
        table.insert(UISpecialFrames, FRAME_NAME)
    end

    local back = frame:CreateTexture(nil, "BACKGROUND")
    SetAtlas(back, "frame-back")
    back:SetPoint("TOPLEFT", 10, -8)
    back:SetPoint("BOTTOMRIGHT", -10, 8)

    frame.HeaderText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    frame.HeaderText:SetPoint("CENTER", frame, "TOP", 0, -92)
    frame.HeaderText:SetWidth(1000)
    frame.HeaderText:SetJustifyH("CENTER")
    frame.HeaderText:SetSpacing(2)

    local headerDivider = frame:CreateTexture(nil, "ARTWORK")
    SetAtlas(headerDivider, "header", true)
    headerDivider:SetPoint("TOP", frame.HeaderText, "BOTTOM", 0, -8)

    frame.dividers = {}
    for index, y in ipairs(DIVIDER_Y) do
        local divider = frame:CreateTexture(nil, "BORDER")
        SetAtlas(divider, "divider", true)
        divider:SetPoint("TOP", 0, y)
        frame.dividers[index] = divider
    end

    frame.rows = {}
    for rowIndex, y in ipairs(ROW_Y) do
        local row = CreateFrame("Frame", nil, frame)
        row:SetSize(326, 131)
        row:SetPoint("TOPLEFT", 68, y)
        row:SetFrameLevel(FRAME_LEVEL + 1)

        row.Background = row:CreateTexture(nil, "BACKGROUND")
        row.Background:SetPoint("CENTER")

        row.Name = row:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
        row.Name:SetFont(FANCY_FONT, 24)
        row.Name:SetTextColor(1, 0.82, 0)
        row.Name:SetShadowOffset(1, -1)
        row.Name:SetPoint("TOPLEFT", 28, -18)

        row.cards = {}
        local previous
        for column = 1, CARDS_PER_ROW do
            local card = CreateCard(row, FRAME_LEVEL + 5)
            if previous then
                card:SetPoint("LEFT", previous, "RIGHT", 9, 0)
            else
                card:SetPoint("LEFT", row, "RIGHT", 44, 3)
            end
            row.cards[column] = card
            previous = card
        end
        frame.rows[rowIndex] = row
    end

    local borderFrame = CreateFrame("Frame", nil, frame)
    borderFrame:SetAllPoints()
    borderFrame:SetFrameLevel(FRAME_LEVEL + 20)
    local border = borderFrame:CreateTexture(nil, "OVERLAY")
    SetAtlas(border, "frame")
    border:SetPoint("TOPLEFT", -2, 4)
    border:SetPoint("BOTTOMRIGHT", 2, -4)
    local topDecor = borderFrame:CreateTexture(nil, "OVERLAY", nil, 1)
    SetAtlas(topDecor, "frame-topdecor", true)
    topDecor:SetPoint("CENTER", frame, "TOP", 0, -16)

    frame.CloseButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.CloseButton:SetPoint("CENTER", frame, "TOPRIGHT", -16, -21)
    frame.CloseButton:SetFrameLevel(FRAME_LEVEL + 25)
    frame.CloseButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    frame.WeekText = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    frame.WeekText:SetPoint("BOTTOM", 0, 76)

    frame.tabs = {}
    local tabsWidth = #VIEW_TABS * TAB_WIDTH + (#VIEW_TABS - 1) * TAB_GAP
    for index, info in ipairs(VIEW_TABS) do
        local xOffset = -tabsWidth / 2 + TAB_WIDTH / 2 + (index - 1) * (TAB_WIDTH + TAB_GAP)
        frame.tabs[index] = CreateTab(info, xOffset)
    end

    local selectButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    selectButton:SetSize(182, 23)
    selectButton:SetPoint("BOTTOM", 0, 3)
    selectButton:SetFrameLevel(FRAME_LEVEL + 25)
    selectButton:SetText("Select Reward")
    local selectBackground = selectButton:CreateTexture(nil, "BACKGROUND", nil, -1)
    SetAtlas(selectBackground, "frame-selectbutton", true)
    selectBackground:SetPoint("CENTER")
    selectButton:SetScript("OnClick", function()
        GV:ConfirmSelection()
    end)
    selectButton:Hide()
    frame.SelectRewardButton = selectButton

    frame:Hide()
    return frame
end

-- ---------------------------------------------------------------------------
-- Rendering
-- ---------------------------------------------------------------------------

local function HasClaimableReward(tracks)
    if type(tracks) ~= "table" then
        return false
    end
    for _, track in ipairs(tracks) do
        for _, slot in ipairs(type(track.slots) == "table" and track.slots or {}) do
            if slot.status == "unlocked" and type(slot.rewards) == "table" and slot.rewards[1] then
                return true
            end
        end
    end
    return false
end

local function IndexSlots(tracks)
    local byId = {}
    if type(tracks) ~= "table" then
        return byId
    end
    for _, track in ipairs(tracks) do
        for _, slot in ipairs(type(track.slots) == "table" and track.slots or {}) do
            if slot.globalId then
                byId[tonumber(slot.globalId)] = slot
            end
        end
    end
    return byId
end

local function ThresholdText(trackId, threshold)
    if trackId == "raid" then
        return string.format("Defeat %d Raid %s", threshold, Plural(threshold, "Boss", "Bosses"))
    elseif trackId == "pvp" then
        return string.format("Win %d PvP %s", threshold, Plural(threshold, "Match", "Matches"))
    end
    return string.format("Complete %d Mythic+ %s", threshold, Plural(threshold, "Dungeon", "Dungeons"))
end

local function HeaderText(view, data, claimAvailable)
    if view == "history" then
        return "Your latest Mythic+ runs"
    elseif view == "progress" then
        return "Add items to the Great Vault by completing activities each week.\n"
            .. "Once per week you may select a single reward."
    elseif IsTruthy(data.claimed) then
        return "You have claimed your Great Vault reward.\nCome back after the weekly reset for the next one."
    elseif claimAvailable then
        return "You may only select ONE reward from the Great Vault."
    end
    return "The Great Vault earned nothing last week.\nComplete activities this week to fill it for next week."
end

local function WeekText(view, data)
    local progressStart = tonumber(data.progressWeekStart or 0) or 0
    local nextReset = progressStart > 0 and FormatDateTime(progressStart + SECONDS_PER_WEEK) or "Unknown"
    if view == "history" then
        return "Newest runs first"
    elseif view == "progress" then
        return "Progress week: " .. FormatWeekRange(data.progressWeekStart) .. "   |   Next reset: " .. nextReset
    end
    return "Reward week: " .. FormatWeekRange(data.claimWeekStart) .. "   |   Expires: " .. nextReset
end

local function ResetCard(card)
    card.slot = nil
    card.reward = nil
    card.hasRewards = false
    card.unlocked = false
    card.forecastIlvl = nil
    card.keyLevel = nil
    card.ItemFrame:Hide()
    card.ItemFrame.itemId = nil
    card.UncollectedGlow:Hide()
    card.Detail:SetText("")
    card.Progress:SetText("")
end

local function RenderHistoryCard(card, slot)
    if slot.status ~= "history" then
        SetAtlas(card.Background, "reward-locked", true)
        card.CompletedIcon:Hide()
        card.Threshold:SetText("No run recorded")
        card.Threshold:SetTextColor(0.5, 0.5, 0.5)
        return
    end

    local success = IsTruthy(slot.success)
    SetAtlas(card.Background, "reward-unlocked", true)
    SetShown(card.CompletedIcon, success)
    card.Threshold:SetText(tostring(slot.mapName or "Unknown"))
    card.Threshold:SetTextColor(1, 0.82, 0)
    card.Detail:SetText((success and "Completed" or "Failed") .. " in " .. FormatRunDuration(slot.completionTime)
        .. "\n" .. FormatDateTime(slot.completedAt))
    card.Progress:SetText("+" .. (tonumber(slot.keystoneLevel or 0) or 0))
    if success then
        card.Progress:SetTextColor(0.1, 1, 0.1)
    else
        card.Progress:SetTextColor(1, 0.35, 0.35)
    end
end

local function RenderCard(card, trackId, slot, view, forecast)
    ResetCard(card)
    card.slot = slot
    card.trackId = trackId
    card.globalId = tonumber(slot.globalId)
    card.index = tonumber(slot.id) or 1

    if view == "history" then
        RenderHistoryCard(card, slot)
        return
    end

    card.threshold = tonumber(slot.threshold or 0) or 0
    card.progress = tonumber(slot.progress or 0) or 0
    card.Threshold:SetText(ThresholdText(trackId, card.threshold))

    local reward = type(slot.rewards) == "table" and slot.rewards[1] or nil
    card.unlocked = slot.status == "unlocked" or slot.status == "claimed"

    if not card.unlocked then
        SetAtlas(card.Background, "reward-locked", true)
        card.CompletedIcon:Hide()
        card.Threshold:SetTextColor(0.5, 0.5, 0.5)
        card.Progress:SetTextColor(0.5, 0.5, 0.5)
        -- Retail hides progress on incomplete slots while rewards are up for grabs.
        if view ~= "claim" then
            card.Progress:SetText(string.format("%d/%d", math.min(card.progress, card.threshold), card.threshold))
        end
        return
    end

    SetAtlas(card.Background, "reward-unlocked", true)
    card.CompletedIcon:Show()
    card.Threshold:SetTextColor(1, 0.82, 0)
    card.Progress:SetTextColor(0.1, 1, 0.1)

    if reward and tonumber(reward.itemId) then
        card.reward = reward
        card.hasRewards = slot.status == "unlocked"
        SetItem(card.ItemFrame, reward)
        if slot.status == "claimed" then
            card.Progress:SetText("Claimed")
        else
            card.Progress:SetText(string.format("Item Level %d", tonumber(reward.ilvl or 0) or 0))
        end
        return
    end

    if slot.status == "claimed" then
        card.Progress:SetText("Claimed")
        return
    end

    if view == "claim" then
        card.Progress:SetText("Unavailable")
        card.Progress:SetTextColor(1, 0.5, 0)
        return
    end

    card.UncollectedGlow:Show()
    local projected = forecast and forecast[card.globalId]
    card.forecastIlvl = projected and tonumber(projected.forecastIlvl or 0) or 0
    card.keyLevel = projected and tonumber(projected.sourceKeyLevel or 0) or 0
    if trackId == "mplus" and card.keyLevel > 0 then
        card.Progress:SetText(string.format("Mythic+ %d", card.keyLevel))
    elseif card.forecastIlvl > 0 then
        card.Progress:SetText(string.format("Item Level %d", card.forecastIlvl))
    else
        card.Progress:SetText("Unlocked")
    end
end

function GV:ResolveTracks(data)
    local view = self._view
    if view == "next" then
        -- The forecast now lives on the progress view.
        view = "progress"
    end

    local byView = {
        claim = data.tracks,
        progress = data.progressTracks,
        history = data.historyTracks,
    }
    if type(byView[view]) == "table" then
        return byView[view], view
    end
    for _, info in ipairs(VIEW_TABS) do
        if type(byView[info.view]) == "table" then
            return byView[info.view], info.view
        end
    end
    return nil, view
end

function GV:UpdateTabs()
    if not frame then
        return
    end
    for _, tab in ipairs(frame.tabs) do
        if tab.view == self._activeView then
            tab.Text:SetTextColor(1, 1, 1)
            tab.Background:SetVertexColor(1, 1, 1)
        else
            tab.Text:SetTextColor(1, 0.82, 0)
            tab.Background:SetVertexColor(0.6, 0.6, 0.6)
        end
    end
end

function GV:Render()
    local data = self._lastPayload
    if not frame or type(data) ~= "table" then
        return
    end

    local tracks, view = self:ResolveTracks(data)
    self._activeView = view
    self:UpdateTabs()

    self.claimAvailable = view == "claim" and not IsTruthy(data.claimed) and HasClaimableReward(data.tracks)
    frame.HeaderText:SetText(HeaderText(view, data, self.claimAvailable))
    frame.WeekText:SetText(WeekText(view, data))

    local forecast = view == "progress" and IndexSlots(data.nextWeekTracks) or nil
    local selectedId = self.selectedCard and self.selectedCard.globalId
    self.selectedCard = nil

    for rowIndex, row in ipairs(frame.rows) do
        local track = type(tracks) == "table" and tracks[rowIndex] or nil
        SetShown(row, track ~= nil)
        if track then
            local style = TRACK_STYLE[track.id] or TRACK_STYLE.mplus
            SetAtlas(row.Background, style.atlas, true)
            row.Name:SetText(style.name or track.name)

            local slots = type(track.slots) == "table" and track.slots or {}
            for column, card in ipairs(row.cards) do
                local slot = slots[column]
                SetShown(card, slot ~= nil)
                if slot then
                    RenderCard(card, track.id, slot, view, forecast)
                    if self.claimAvailable and card.hasRewards and card.globalId == selectedId then
                        self.selectedCard = card
                    end
                end
            end
        end
    end

    for index, divider in ipairs(frame.dividers) do
        SetShown(divider, type(tracks) == "table" and tracks[index + 1] ~= nil)
    end

    self:UpdateSelection()
end

function GV:UpdateSelection()
    local selected = self.selectedCard
    for _, row in ipairs(frame.rows) do
        for _, card in ipairs(row.cards) do
            local isSelected = card == selected
            SetShown(card.SelectedTexture, isSelected)
            SetShown(card.SelectionGlow, isSelected)
            SetShown(card.UnselectedFrame, selected ~= nil and card.hasRewards and not isSelected)
        end
    end
    SetShown(frame.SelectRewardButton, self.claimAvailable)
    SetEnabled(frame.SelectRewardButton, selected ~= nil)
end

-- ---------------------------------------------------------------------------
-- Tooltips
-- ---------------------------------------------------------------------------

local function IncompleteText(card)
    local remaining = math.max(0, card.threshold - card.progress)
    if card.trackId == "raid" then
        return string.format("Defeat %d more raid %s this week to unlock this reward.",
            remaining, Plural(remaining, "boss", "bosses"))
    elseif card.trackId == "pvp" then
        return string.format("Win %d more PvP %s this week to unlock this reward.",
            remaining, Plural(remaining, "match", "matches"))
    end
    return string.format("Complete %d more Mythic+ %s this week to unlock %s Great Vault reward.\n\n"
        .. "The item level of your reward will be based on your top runs this week.",
        remaining, Plural(remaining, "dungeon", "dungeons"), UNLOCK_ORDINAL[card.index] or "another")
end

local function AddCurrentRewardLines(card)
    local ilvl = card.forecastIlvl or 0
    if ilvl > 0 then
        local line
        if card.trackId == "mplus" and (card.keyLevel or 0) > 0 then
            line = string.format("Item Level %d - Mythic+ (Level %d)", ilvl, card.keyLevel)
        elseif card.trackId == "pvp" then
            line = string.format("Item Level %d - PvP", ilvl)
        else
            line = string.format("Item Level %d - Raid", ilvl)
        end
        GameTooltip:AddLine(line, 1, 0.82, 0)
    end
    if card.trackId == "mplus" and card.threshold > 1 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(string.format("The reward is based on the lowest level of your top %d runs.",
            card.threshold), 1, 1, 1, true)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Your reward can be selected from the Great Vault after the weekly reset.", 0.1, 1, 0.1, true)
end

function GV:ShowCardTooltip(card)
    local slot = card.slot
    if not slot then
        return
    end

    if card.reward then
        ItemOnEnter(card.ItemFrame)
        return
    end

    GameTooltip:SetOwner(card, "ANCHOR_RIGHT", -7, -11)
    if slot.status == "history" then
        GameTooltip:AddLine(tostring(slot.mapName or "Unknown"), 1, 1, 1)
        GameTooltip:AddLine(string.format("Mythic+ %d", tonumber(slot.keystoneLevel or 0) or 0), 1, 0.82, 0)
        GameTooltip:AddLine(FormatDateTime(slot.completedAt), 0.8, 0.8, 0.8)
    elseif slot.status == "empty" then
        GameTooltip:AddLine("No run recorded", 0.5, 0.5, 0.5)
    elseif card.unlocked and self._activeView == "claim" then
        GameTooltip:AddLine("Reward Unavailable", 1, 1, 1)
        GameTooltip:AddLine("This slot was unlocked but no reward was generated for it.", 1, 0.82, 0, true)
    elseif card.unlocked then
        GameTooltip:AddLine("Current Reward", 1, 1, 1)
        AddCurrentRewardLines(card)
    elseif self._activeView == "claim" then
        GameTooltip:AddLine("Reward Locked", 1, 1, 1)
        GameTooltip:AddLine("This reward was not unlocked last week.", 1, 0.82, 0, true)
    else
        GameTooltip:AddLine("Unlock Reward", 1, 1, 1)
        GameTooltip:AddLine(IncompleteText(card), 1, 0.82, 0, true)
    end
    GameTooltip:Show()
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

function GV:SetView(view)
    self._view = view
    self.selectedCard = nil
    self:Render()
end

function GV:IsShown()
    return frame and frame:IsShown()
end

function GV:Show()
    self:CreateFrame():Show()
    if namespace.RequestVaultInfo then
        namespace.RequestVaultInfo()
    end
end

function GV:Hide()
    if frame then
        frame:Hide()
    end
end

function GV:Toggle()
    if frame and frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function GV:Update(data)
    if type(data) ~= "table" then
        return
    end
    self:CreateFrame()
    self._lastPayload = data

    if not self._view and type(data.defaultView) == "string" then
        self._view = data.defaultView
    end
    if data.open then
        frame:Show()
    end

    self:Render()
end

function GV:SelectCard(card)
    if not card or not card.hasRewards or not self.claimAvailable then
        return
    end
    PlaySoundSafe("igMainMenuOptionCheckBoxOn")
    if self.selectedCard == card then
        self.selectedCard = nil
    else
        self.selectedCard = card
    end
    if StaticPopup_Hide then
        StaticPopup_Hide(POPUP_KEY)
    end
    self:UpdateSelection()
end

function GV:ConfirmSelection()
    local card = self.selectedCard
    if not card or not card.reward then
        return
    end
    self._pendingSlot = card.globalId
    self._pendingItemId = tonumber(card.reward.itemId)
    EnsurePopupDefined()
    StaticPopup_Show(POPUP_KEY, ColoredName(card.reward))
end

-- Select the reward in a global slot and open the confirmation.
function GV:SelectReward(slotIndex)
    if not frame then
        return
    end
    for _, row in ipairs(frame.rows) do
        for _, card in ipairs(row.cards) do
            if card.hasRewards and card.globalId == tonumber(slotIndex) then
                self.selectedCard = card
                self:UpdateSelection()
                self:ConfirmSelection()
                return
            end
        end
    end
end
