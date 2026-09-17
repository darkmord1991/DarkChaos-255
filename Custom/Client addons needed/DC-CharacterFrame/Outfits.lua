--[[
    DC-CharacterFrame / Outfits.lua
    ===============================
    Retail-style outfit dropdown (WardrobeOutfitDropdown) above the character
    model, backed by the account-wide outfits DC-Collection stores on the
    server. Replaces the old "Collection" icon button on the frame.

      * dropdown lists every saved outfit (icon + name), ticks the one that
        matches the currently applied transmog, and applies on click
      * hover arrow -> Apply / Overwrite with current look / Rename / Delete
      * "New Outfit..." saves the current look under a new name
      * Save button next to the dropdown overwrites the selected outfit once
        the applied look drifts from it (retail behaviour)

    All data goes through DC-Collection's own protocol calls; this file only
    hooks the reply handlers (OnMsg_SavedOutfits / HandleTransmogState) to keep
    its list and the dropdown text current.
]]

local DCCF = DCCharacterFrame

local PAGE_SIZE = 50            -- server clamps CMSG_GET_SAVED_OUTFITS to 50
local REFRESH_INTERVAL = 120    -- seconds before a shown panel re-fetches

local function Collection()
    return rawget(_G, "DCCollection")
end

local function Wardrobe()
    local dc = Collection()
    return dc and dc.Wardrobe or nil
end

local Outfits = { list = {}, byId = {}, loaded = false, fetching = false, lastRequest = 0 }
DCCF.Outfits = Outfits

local NONE_TEXT = GRAY_FONT_COLOR_CODE .. "No Outfit" .. FONT_COLOR_CODE_CLOSE
local DEFAULT_ICON = "Interface\\Icons\\INV_Chest_Cloth_17"

-- ---------------------------------------------------------------------------
-- Data
-- ---------------------------------------------------------------------------

local function CopyOutfit(raw)
    local copy = {
        id = tonumber(raw.id) or 0,
        name = tostring(raw.name or "Outfit"),
        icon = raw.icon or DEFAULT_ICON,
        slots = {},
    }
    local slots = raw.slots
    if type(slots) == "string" then
        for k, v in slots:gmatch('"?([^":,{}]+)"?%s*:%s*(%d+)') do
            copy.slots[k] = tonumber(v)
        end
    elseif type(slots) == "table" then
        for k, v in pairs(slots) do
            copy.slots[k] = tonumber(v) or 0
        end
    end
    return copy
end

function Outfits:Rebuild()
    local list = {}
    for _, outfit in pairs(self.byId) do
        table.insert(list, outfit)
    end
    table.sort(list, function(a, b)
        return string.lower(a.name) < string.lower(b.name)
    end)
    self.list = list
end

function Outfits:Count()
    local n = 0
    for _ in pairs(self.byId) do
        n = n + 1
    end
    return n
end

function Outfits:RequestPage(offset)
    local dc = Collection()
    if not (dc and dc.Protocol and type(dc.Protocol.RequestSavedOutfitsPage) == "function") then
        return false
    end
    self.pendingOffset = offset
    self.fetching = true
    self.lastRequest = GetTime()
    dc.Protocol:RequestSavedOutfitsPage(offset, PAGE_SIZE)
    return true
end

function Outfits:RequestAll(force)
    local dc = Collection()
    if not dc then
        return
    end
    if type(dc.IsProtocolReady) == "function" and not dc:IsProtocolReady() then
        return
    end
    local now = GetTime()
    if self.fetching and (now - self.lastRequest) < 10 then
        return
    end
    if not force and self.loaded and (now - self.lastRequest) < REFRESH_INTERVAL then
        return
    end
    self:RequestPage(0)
end

-- Post-hook on DCCollection:OnMsg_SavedOutfits - the page it just decoded is
-- in DCCollection.db (outfits / outfitsOffset / outfitsLimit / outfitsTotal).
function Outfits:OnSavedOutfits()
    local dc = Collection()
    local db = dc and dc.db
    if not db then
        return
    end
    local page = db.outfits or {}
    local offset = tonumber(db.outfitsOffset) or 0
    local limit = tonumber(db.outfitsLimit) or 6
    local total = tonumber(db.outfitsTotal)

    -- Our own full listing starts over; the wardrobe's 6-per-page requests are
    -- merged on top so renames done there show up without a re-fetch.
    if offset == 0 and limit > 6 then
        self.byId = {}
    end
    for _, raw in ipairs(page) do
        local outfit = CopyOutfit(raw)
        if outfit.id > 0 then
            self.byId[outfit.id] = outfit
        end
    end

    if self.fetching and offset == self.pendingOffset then
        local nextOffset = offset + #page
        if total and #page > 0 and nextOffset < total then
            self:RequestPage(nextOffset)
        else
            self.fetching = false
            self.loaded = true
        end
    end
    -- Deleted elsewhere (wardrobe window): the total shrinks below what we hold.
    if not self.fetching and total and total < self:Count() and (GetTime() - self.lastRequest) > 5 then
        self:RequestPage(0)
    end

    self:Rebuild()

    if self.pendingSelectName then
        for _, outfit in ipairs(self.list) do
            if outfit.name == self.pendingSelectName then
                DCCF.db.selectedOutfitId = outfit.id
                self.pendingSelectName = nil
                break
            end
        end
    end
    DCCF:RefreshOutfits()
end

-- ---------------------------------------------------------------------------
-- Current look vs. saved outfit
-- ---------------------------------------------------------------------------

local function CurrentSlots()
    local dc, wardrobe = Collection(), Wardrobe()
    local current = {}
    local state = dc and dc.transmogState
    if type(state) ~= "table" or not wardrobe or type(wardrobe.EQUIPMENT_SLOTS) ~= "table" then
        return current
    end
    for _, def in ipairs(wardrobe.EQUIPMENT_SLOTS) do
        local invSlot = GetInventorySlotInfo(def.key)
        if invSlot and (GetInventoryItemID("player", invSlot) or GetInventoryItemTexture("player", invSlot)) then
            local eqSlot = invSlot - 1
            local value = tonumber(state[tostring(eqSlot)] or state[eqSlot]) or 0
            if value > 0 then
                current[def.key] = value
            end
        end
    end
    return current
end

local function SameLook(outfitSlots, current)
    local n = 0
    for key, value in pairs(outfitSlots) do
        value = tonumber(value) or 0
        if value > 0 then
            n = n + 1
            if current[key] ~= value then
                return false
            end
        end
    end
    local m = 0
    for _ in pairs(current) do
        m = m + 1
    end
    return n == m
end

function Outfits:FindMatching()
    local current = CurrentSlots()
    if next(current) == nil then
        return nil
    end
    for _, outfit in ipairs(self.list) do
        if SameLook(outfit.slots, current) then
            return outfit
        end
    end
    return nil
end

function Outfits:GetSelected()
    local id = tonumber(DCCF.db.selectedOutfitId) or 0
    if id > 0 then
        return self.byId[id]
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Actions
-- ---------------------------------------------------------------------------

function Outfits:Apply(id)
    local outfit = self.byId[id]
    local wardrobe = Wardrobe()
    if not outfit or not wardrobe or type(wardrobe.LoadOutfit) ~= "function" then
        return
    end
    DCCF.db.selectedOutfitId = id
    wardrobe:LoadOutfit(outfit)
    DCCF:RefreshOutfits()
end

function Outfits:Overwrite(id)
    local outfit = self.byId[id]
    local wardrobe = Wardrobe()
    if not outfit or not wardrobe or type(wardrobe.SaveCurrentOutfit) ~= "function" then
        return
    end
    DCCF.db.selectedOutfitId = id
    wardrobe:SaveCurrentOutfit(outfit.name, outfit.id)
    self:RequestAll(true)
end

function Outfits:SaveNew(name)
    local wardrobe = Wardrobe()
    if not wardrobe or type(wardrobe.SaveCurrentOutfit) ~= "function" then
        return
    end
    for _, outfit in ipairs(self.list) do
        if outfit.name == name then
            DCCF:Print("An outfit called '" .. name .. "' already exists.")
            return
        end
    end
    self.pendingSelectName = name
    wardrobe:SaveCurrentOutfit(name)
    self:RequestAll(true)
end

function Outfits:Rename(id, newName)
    local outfit = self.byId[id]
    local dc = Collection()
    if not outfit or not (dc and dc.Protocol and type(dc.Protocol.SaveOutfit) == "function") then
        return
    end
    dc.Protocol:SaveOutfit(outfit.id, newName, outfit.icon, outfit.slots)
    outfit.name = newName
    self:Rebuild()
    DCCF:RefreshOutfits()
    self:RequestAll(true)
end

function Outfits:Delete(id)
    local outfit = self.byId[id]
    local dc = Collection()
    if not outfit or not (dc and dc.Protocol and type(dc.Protocol.DeleteOutfit) == "function") then
        return
    end
    dc.Protocol:DeleteOutfit(outfit.id)
    self.byId[id] = nil
    if tonumber(DCCF.db.selectedOutfitId) == id then
        DCCF.db.selectedOutfitId = 0
    end
    self:Rebuild()
    DCCF:RefreshOutfits()
    self:RequestAll(true)
end

function Outfits:OpenWardrobe()
    local dc = Collection()
    if not dc then
        return
    end
    if type(dc.ShowMainFrame) == "function" then
        dc:ShowMainFrame()
    end
    if type(dc.SelectTab) == "function" then
        dc:SelectTab("wardrobe")
    end
end

-- ---------------------------------------------------------------------------
-- Popups
-- ---------------------------------------------------------------------------

StaticPopupDialogs["DCCF_OUTFIT_NAME"] = {
    text = "%s",
    button1 = ACCEPT,
    button2 = CANCEL,
    hasEditBox = 1,
    maxLetters = 32,
    OnShow = function(dialog)
        local editBox = _G[dialog:GetName() .. "EditBox"]
        editBox:SetText(dialog.data and dialog.data.initial or "")
        editBox:HighlightText()
        editBox:SetFocus()
    end,
    OnAccept = function(dialog)
        local editBox = _G[dialog:GetName() .. "EditBox"]
        local name = strtrim(editBox:GetText() or "")
        if name ~= "" and dialog.data and dialog.data.callback then
            dialog.data.callback(name)
        end
    end,
    EditBoxOnEnterPressed = function(editBox)
        local dialog = editBox:GetParent()
        StaticPopupDialogs["DCCF_OUTFIT_NAME"].OnAccept(dialog)
        dialog:Hide()
    end,
    EditBoxOnEscapePressed = function(editBox)
        editBox:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
}

StaticPopupDialogs["DCCF_OUTFIT_DELETE"] = {
    text = "Delete the outfit \"%s\"?",
    button1 = DELETE,
    button2 = CANCEL,
    OnAccept = function(dialog)
        if dialog.data then
            Outfits:Delete(dialog.data)
        end
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    showAlert = 1,
}

function Outfits:PromptNew()
    StaticPopup_Show("DCCF_OUTFIT_NAME", "Save your current look as a new outfit:", nil,
        { initial = "", callback = function(name) Outfits:SaveNew(name) end })
end

function Outfits:PromptRename(id)
    local outfit = self.byId[id]
    if not outfit then
        return
    end
    StaticPopup_Show("DCCF_OUTFIT_NAME", "Rename \"" .. outfit.name .. "\" to:", nil,
        { initial = outfit.name, callback = function(name) Outfits:Rename(id, name) end })
end

function Outfits:PromptDelete(id)
    local outfit = self.byId[id]
    if not outfit then
        return
    end
    StaticPopup_Show("DCCF_OUTFIT_DELETE", outfit.name, nil, id)
end

-- ---------------------------------------------------------------------------
-- Dropdown menu
-- ---------------------------------------------------------------------------

local function AddButton(info, level)
    UIDropDownMenu_AddButton(info, level)
end

function Outfits:InitMenu(frame, level)
    level = level or 1
    local info
    if level == 1 then
        local matching = self:FindMatching()
        if #self.list == 0 then
            info = UIDropDownMenu_CreateInfo()
            info.text = self.loaded and "No saved outfits" or "Loading outfits..."
            info.disabled = 1
            info.notCheckable = 1
            AddButton(info, level)
        end
        for _, outfit in ipairs(self.list) do
            info = UIDropDownMenu_CreateInfo()
            info.text = outfit.name
            info.value = outfit.id
            info.icon = outfit.icon
            info.checked = (matching ~= nil and matching.id == outfit.id) or nil
            info.hasArrow = 1
            info.func = function() Outfits:Apply(outfit.id) end
            info.tooltipTitle = outfit.name
            info.tooltipText = "Click to apply this outfit.\nHover the arrow for more options."
            AddButton(info, level)
        end
        info = UIDropDownMenu_CreateInfo()
        info.text = GREEN_FONT_COLOR_CODE .. "New Outfit..." .. FONT_COLOR_CODE_CLOSE
        info.icon = DCCF.TEX_PLUS
        info.notCheckable = 1
        info.func = function() Outfits:PromptNew() end
        info.tooltipTitle = "New Outfit"
        info.tooltipText = "Save the transmog look you are wearing right now."
        AddButton(info, level)
        info = UIDropDownMenu_CreateInfo()
        info.text = "Open Wardrobe"
        info.notCheckable = 1
        info.func = function() Outfits:OpenWardrobe() end
        AddButton(info, level)
    elseif level == 2 then
        local id = UIDROPDOWNMENU_MENU_VALUE
        local outfit = self.byId[id]
        if not outfit then
            return
        end
        info = UIDropDownMenu_CreateInfo()
        info.text = outfit.name
        info.isTitle = 1
        info.notCheckable = 1
        AddButton(info, level)
        info = UIDropDownMenu_CreateInfo()
        info.text = "Apply"
        info.notCheckable = 1
        info.func = function() Outfits:Apply(id) end
        AddButton(info, level)
        info = UIDropDownMenu_CreateInfo()
        info.text = "Overwrite with current look"
        info.notCheckable = 1
        info.func = function() Outfits:Overwrite(id) end
        AddButton(info, level)
        info = UIDropDownMenu_CreateInfo()
        info.text = "Rename..."
        info.notCheckable = 1
        info.func = function() Outfits:PromptRename(id) end
        AddButton(info, level)
        info = UIDropDownMenu_CreateInfo()
        info.text = RED_FONT_COLOR_CODE .. "Delete" .. FONT_COLOR_CODE_CLOSE
        info.notCheckable = 1
        info.func = function() Outfits:PromptDelete(id) end
        AddButton(info, level)
    end
end

-- ---------------------------------------------------------------------------
-- UI
-- ---------------------------------------------------------------------------

function DCCF:BuildOutfits()
    local dc = Collection()
    if not dc then
        return
    end
    local pdf = PaperDollFrame
    local host = CreateFrame("Frame", "DCCharacterOutfitHost", pdf)
    host:SetPoint("TOPLEFT", self.modelBg, "TOPLEFT", 0, 0)
    host:SetWidth(231)
    host:SetHeight(34)
    host:SetFrameLevel(pdf:GetFrameLevel() + 4)
    self.outfitHost = host

    local dropdown = CreateFrame("Frame", "DCCharacterOutfitDropDown", host, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", host, "TOPLEFT", 6, 6)
    UIDropDownMenu_SetWidth(dropdown, 118)
    UIDropDownMenu_Initialize(dropdown, function(frame, level)
        Outfits:InitMenu(frame, level)
    end)
    UIDropDownMenu_SetText(dropdown, NONE_TEXT)
    self.outfitDropDown = dropdown

    local save = CreateFrame("Button", "DCCharacterOutfitSaveButton", host, "UIPanelButtonTemplate")
    save:SetWidth(46)
    save:SetHeight(20)
    save:SetPoint("LEFT", dropdown, "RIGHT", -12, 2)
    save:SetText(SAVE or "Save")
    save:SetScript("OnClick", function()
        local selected = Outfits:GetSelected()
        if selected then
            Outfits:Overwrite(selected.id)
        end
    end)
    save:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(SAVE or "Save", 1, 1, 1)
        local selected = Outfits:GetSelected()
        if selected then
            GameTooltip:AddLine("Overwrite \"" .. selected.name .. "\" with the look you are wearing now.", 0.8, 0.8, 0.8, true)
        else
            GameTooltip:AddLine("Select an outfit first, or use New Outfit... in the dropdown.", 0.8, 0.8, 0.8, true)
        end
        GameTooltip:Show()
    end)
    save:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    save:Disable()
    self.outfitSaveButton = save

    if type(dc.OnMsg_SavedOutfits) == "function" then
        hooksecurefunc(dc, "OnMsg_SavedOutfits", function()
            Outfits:OnSavedOutfits()
        end)
    end
    if type(dc.HandleTransmogState) == "function" then
        hooksecurefunc(dc, "HandleTransmogState", function()
            DCCF:RefreshOutfits()
        end)
    end
end

function DCCF:RefreshOutfits()
    local dropdown, save = self.outfitDropDown, self.outfitSaveButton
    if not dropdown then
        return
    end
    local dc = Collection()
    if PaperDollFrame:IsShown() then
        Outfits:RequestAll()
        if dc and type(dc.transmogState) == "table" and next(dc.transmogState) == nil
            and not Outfits.stateRequested and type(dc.RequestTransmogState) == "function"
            and (type(dc.IsProtocolReady) ~= "function" or dc:IsProtocolReady()) then
            Outfits.stateRequested = true
            dc:RequestTransmogState()
        end
    end

    local matching = Outfits:FindMatching()
    local selected = Outfits:GetSelected()
    if matching and (not selected or selected.id ~= matching.id) then
        self.db.selectedOutfitId = matching.id
        selected = matching
    end

    if selected then
        if matching and matching.id == selected.id then
            UIDropDownMenu_SetText(dropdown, selected.name)
        else
            UIDropDownMenu_SetText(dropdown, selected.name .. " |cffffd100*|r")
        end
    else
        UIDropDownMenu_SetText(dropdown, NONE_TEXT)
    end

    if selected and not (matching and matching.id == selected.id) and Wardrobe() then
        save:Enable()
    else
        save:Disable()
    end

    -- The Equipment Manager pane lists the same outfits.
    local sets = self.setsPane
    if sets and sets.Refresh and sets:IsVisible() then
        sets.Refresh()
    end
end
