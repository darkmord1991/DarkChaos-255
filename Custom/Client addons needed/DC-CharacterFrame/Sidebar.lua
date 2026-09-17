--[[
    DC-CharacterFrame / Sidebar.lua
    ===============================
    The retail sidebar: a tab strip above the right inset (PaperDollSidebarTabs
    art) and one pane per registered sidebar. Also defines the Titles pane and
    the Equipment Sets pane (retail PaperDollTitlesPane / EquipmentManagerPane
    on top of the 3.3.5 title and equipment-set APIs).
]]

local DCCF = DCCharacterFrame
local Tex = DCCF.Tex

local TAB_W, TAB_H = 33, 35
local LIST_ROW_W = 185
DCCF.LIST_ROW_W = LIST_ROW_W

-- ---------------------------------------------------------------------------
-- Tab strip
-- ---------------------------------------------------------------------------

local function CreateSidebarTab(strip, index, def)
    local tab = CreateFrame("Button", "DCCharacterSidebarTab" .. index, strip)
    tab:SetWidth(TAB_W)
    tab:SetHeight(TAB_H)
    tab:SetID(index)
    local S = DCCF.SIDEBAR

    local bg = Tex(tab, "BACKGROUND", DCCF.TEX_SIDEBAR, S.TabInactive)
    bg:SetPoint("BOTTOMLEFT", -9, -2)
    tab.TabBg = bg

    local icon = tab:CreateTexture(nil, "ARTWORK")
    if def.portrait then
        icon:SetWidth(29)
        icon:SetHeight(31)
        icon:SetPoint("BOTTOM", 1, 0)
        icon:SetTexCoord(0.109375, 0.890625, 0.09375, 0.90625)
        SetPortraitTexture(icon, "player")
        tab.isPortrait = true
    elseif def.atlasIcon then
        local piece = S[def.atlasIcon]
        icon:SetTexture(DCCF.TEX_SIDEBAR)
        icon:SetWidth(piece[1])
        icon:SetHeight(piece[2])
        icon:SetTexCoord(piece[3], piece[4], piece[5], piece[6])
        icon:SetPoint("BOTTOM", 1, -2)
    else
        icon:SetTexture(def.icon)
        icon:SetWidth(26)
        icon:SetHeight(26)
        icon:SetPoint("BOTTOM", 1, 3)
    end
    tab.Icon = icon

    local hider = Tex(tab, "OVERLAY", DCCF.TEX_SIDEBAR, S.Hider)
    hider:SetPoint("BOTTOM")
    tab.Hider = hider

    local hl = Tex(tab, "HIGHLIGHT", DCCF.TEX_SIDEBAR, S.Highlight)
    hl:SetPoint("TOPLEFT", 2, -3)
    tab.Highlight = hl

    tab:SetScript("OnClick", function(self)
        DCCF:SelectSidebar(self:GetID())
    end)
    tab:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(def.name, 1, 1, 1)
        if not self:IsEnabled() and def.disabledTooltip then
            local reason = def.disabledTooltip
            if type(reason) == "function" then
                reason = reason()
            end
            if reason then
                GameTooltip:AddLine(reason, 1, 0.1, 0.1, true)
            end
        end
        GameTooltip:Show()
    end)
    tab:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    return tab
end

function DCCF:BuildSidebar()
    local right = self.insetRight
    local strip = CreateFrame("Frame", "DCCharacterSidebarTabs", right)
    strip:SetWidth(200)
    strip:SetHeight(TAB_H)
    strip:SetPoint("BOTTOMRIGHT", right, "TOPRIGHT", -6, -1)
    strip:SetFrameLevel(right:GetFrameLevel() + 3)
    self.sidebarStrip = strip

    local decorL = Tex(strip, "ARTWORK", self.TEX_SIDEBAR, self.SIDEBAR.DecorLeft)
    decorL:SetPoint("BOTTOMLEFT")
    local decorR = Tex(strip, "ARTWORK", self.TEX_SIDEBAR, self.SIDEBAR.DecorRight)
    decorR:SetPoint("BOTTOMRIGHT")

    self.sidebarTabs = {}
    self.sidebarPanes = {}
    local prev
    for index = #self.sidebars, 1, -1 do
        local def = self.sidebars[index]
        local tab = CreateSidebarTab(strip, index, def)
        if prev then
            tab:SetPoint("RIGHT", prev, "LEFT", -4, 0)
        else
            tab:SetPoint("BOTTOMRIGHT", strip, "BOTTOMRIGHT", -30, 0)
        end
        self.sidebarTabs[index] = tab
        prev = tab

        local pane = def.build(right)
        pane:Hide()
        self.sidebarPanes[index] = pane
    end

    self:SelectSidebar(self.db.sidebar or 1, true)
end

function DCCF:UpdateSidebarTabs()
    if not self.sidebarTabs then
        return
    end
    local current = self.currentSidebar or 1
    for index, def in ipairs(self.sidebars) do
        local tab = self.sidebarTabs[index]
        local active = (index == current)
        local piece = active and self.SIDEBAR.TabActive or self.SIDEBAR.TabInactive
        tab.TabBg:SetTexCoord(piece[3], piece[4], piece[5], piece[6])
        if active then
            tab.Hider:Hide()
            tab.Highlight:Hide()
            tab:Enable()
            tab:SetAlpha(1)
            tab.Icon:SetDesaturated(false)
        else
            tab.Hider:Show()
            tab.Highlight:Show()
            local usable = (not def.IsActive) or def.IsActive()
            if usable then
                tab:Enable()
                tab:SetAlpha(1)
                tab.Icon:SetDesaturated(false)
            else
                tab:Disable()
                tab:SetAlpha(0.5)
                tab.Icon:SetDesaturated(true)
            end
        end
    end
end

function DCCF:SelectSidebar(index, silent)
    local def = self.sidebars[index]
    if not def or not self.sidebarPanes then
        return
    end
    if def.IsActive and not def.IsActive() and index ~= 1 then
        index = 1
        def = self.sidebars[1]
    end
    for i, pane in pairs(self.sidebarPanes) do
        if i ~= index then
            pane:Hide()
        end
    end
    self.currentSidebar = index
    self.db.sidebar = index
    self.sidebarPanes[index]:Show()
    if not silent then
        PlaySound("igMainMenuOptionCheckBoxOff")
    end
    self:UpdateSidebarTabs()
    if def.onShow then
        def.onShow(self.sidebarPanes[index])
    end
end

function DCCF:RefreshSidebar()
    local def = self.sidebars[self.currentSidebar or 1]
    if def and def.onShow and self.sidebarPanes then
        def.onShow(self.sidebarPanes[self.currentSidebar or 1])
    end
end

-- ---------------------------------------------------------------------------
-- Generic scrolling list (FauxScrollFrame + fixed row pool)
--   opts = { name, rowHeight, numRows, createRow(pane, i), updateRow(row, index),
--            getCount() }
-- ---------------------------------------------------------------------------

function DCCF.CreateListPane(parent, opts)
    local pane = CreateFrame("Frame", opts.name, parent)
    pane:SetFrameLevel(parent:GetFrameLevel() + 1)

    local scroll = CreateFrame("ScrollFrame", opts.name .. "ScrollFrame", pane, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -20, 0)
    pane.scroll = scroll

    pane.rows = {}
    for i = 1, opts.numRows do
        local row = opts.createRow(pane, i)
        row:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, -(i - 1) * opts.rowHeight)
        -- Rows sit above the scroll frame, so forward the wheel to it.
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", function(_, delta)
            ScrollFrameTemplate_OnMouseWheel(scroll, delta)
        end)
        pane.rows[i] = row
    end

    function pane.Update()
        local total = opts.getCount()
        local offset = FauxScrollFrame_GetOffset(scroll)
        local visible = math.min(opts.numRows, pane.visibleRows or opts.numRows)
        FauxScrollFrame_Update(scroll, total, visible, opts.rowHeight)
        for i = 1, opts.numRows do
            local index = offset + i
            local row = pane.rows[i]
            if i <= visible and index <= total then
                opts.updateRow(row, index)
                row:Show()
            else
                row:Hide()
            end
        end
    end
    scroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, opts.rowHeight, pane.Update)
    end)
    return pane
end

-- Shared row skin: Char-Stat-Top / -Bottom caps, tiled middle, stripe,
-- highlight bars (PlayerTitleButtonTemplate / GearSetButtonTemplate).
function DCCF.SkinListRow(row, middleHeight)
    local P = DCCF.PARTS
    local top = Tex(row, "BACKGROUND", DCCF.TEX_PARTS, P.StatTop)
    top:SetPoint("TOPLEFT", 0, 1)
    local bottom = Tex(row, "BACKGROUND", DCCF.TEX_PARTS, P.StatTop)
    bottom:SetPoint("BOTTOMLEFT", 0, -4)
    bottom:SetTexCoord(P.StatTop[4], P.StatTop[3], P.StatTop[6], P.StatTop[5])
    local middle = row:CreateTexture(nil, "BACKGROUND")
    middle:SetTexture(DCCF.TEX_STATMID)
    middle:SetWidth(LIST_ROW_W)
    middle:SetHeight(middleHeight)
    middle:SetPoint("LEFT", 1, 0)
    middle:SetTexCoord(0.00390625, 0.66406250, 0, 1)

    local stripe = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    stripe:SetTexture(0.9, 0.9, 1, 1)
    stripe:SetAlpha(0.1)
    stripe:SetPoint("TOPLEFT", 1, 0)
    stripe:SetPoint("BOTTOMRIGHT", 0, 0)
    row.Stripe = stripe

    local selected = row:CreateTexture(nil, "OVERLAY")
    selected:SetTexture("Interface\\FriendsFrame\\UI-FriendsFrame-HighlightBar")
    selected:SetBlendMode("ADD")
    selected:SetAlpha(0.4)
    selected:SetAllPoints(row)
    selected:Hide()
    row.SelectedBar = selected

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface\\FriendsFrame\\UI-FriendsFrame-HighlightBar-Blue")
    hl:SetBlendMode("ADD")
    hl:SetAllPoints(row)
end

-- ---------------------------------------------------------------------------
-- Titles pane
-- ---------------------------------------------------------------------------

local function GetKnownTitles()
    local titles = { { name = PLAYER_TITLE_NONE or "None", id = -1 } }
    for i = 1, GetNumTitles() do
        if IsTitleKnown(i) and IsTitleKnown(i) ~= 0 then
            local name = GetTitleName(i)
            -- Custom titles can be known but missing from the client DBC.
            if name and strtrim(name) ~= "" then
                table.insert(titles, { name = strtrim(name), id = i })
            end
        end
    end
    local first = table.remove(titles, 1)
    table.sort(titles, function(a, b) return a.name < b.name end)
    table.insert(titles, 1, first)
    return titles
end

local function BuildTitlesPane(parent)
    local pane = DCCF.CreateListPane(parent, {
        name = "DCCharacterTitlesPane",
        rowHeight = 22,
        numRows = 16,
        createRow = function(listPane, i)
            local row = CreateFrame("Button", nil, listPane)
            row:SetWidth(LIST_ROW_W)
            row:SetHeight(22)
            DCCF.SkinListRow(row, 8)
            local check = row:CreateTexture(nil, "BORDER")
            check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
            check:SetWidth(16)
            check:SetHeight(16)
            check:SetPoint("LEFT", 8, 0)
            check:Hide()
            row.Check = check
            local text = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            text:SetPoint("LEFT", check, "RIGHT", 3, 0)
            text:SetPoint("RIGHT", row, "RIGHT", -3, 0)
            text:SetJustifyH("LEFT")
            row.Text = text
            row:SetScript("OnClick", function(self)
                if self.titleId then
                    PlaySound("igMainMenuOptionCheckBoxOff")
                    SetCurrentTitle(self.titleId)
                end
            end)
            return row
        end,
        updateRow = function(row, index)
            local pane = row:GetParent()
            local title = pane.titles[index]
            row.titleId = title.id
            row.Text:SetText(title.name)
            local selected = (pane.selected == title.id)
            if selected then
                row.Check:Show()
                row.SelectedBar:Show()
            else
                row.Check:Hide()
                row.SelectedBar:Hide()
            end
            if index % 2 == 0 then
                row.Stripe:Show()
            else
                row.Stripe:Hide()
            end
        end,
        getCount = function()
            return #(DCCF.titlesPane.titles or {})
        end,
    })
    pane:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -4)
    pane:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -4, 4)
    pane.titles = {}
    DCCF.titlesPane = pane

    function pane.Refresh()
        pane.titles = GetKnownTitles()
        local current = GetCurrentTitle()
        pane.selected = -1
        if current and current > 0 and IsTitleKnown(current) and IsTitleKnown(current) ~= 0 then
            pane.selected = current
        end
        pane.Update()
    end
    pane:SetScript("OnShow", pane.Refresh)
    pane:RegisterEvent("KNOWN_TITLES_UPDATE")
    pane:RegisterEvent("UNIT_NAME_UPDATE")
    pane:SetScript("OnEvent", function(self, event, unit)
        if event == "UNIT_NAME_UPDATE" and unit ~= "player" then
            return
        end
        if self:IsVisible() then
            self.Refresh()
        end
        DCCF:UpdateSidebarTabs()
    end)
    return pane
end

DCCF:RegisterSidebar({
    key = "titles",
    name = PAPERDOLL_SIDEBAR_TITLES or "Titles",
    atlasIcon = "IconTitles",
    build = BuildTitlesPane,
    IsActive = function() return #GetKnownTitles() > 1 end,
    disabledTooltip = "You have not earned any titles yet.",
    onShow = function(pane) pane.Refresh() end,
})

-- ---------------------------------------------------------------------------
-- Equipment Sets pane
-- ---------------------------------------------------------------------------

local function ShowSaveSetPopup(pane)
    local popup = GearManagerDialogPopup
    if popup and GearManagerDialog then
        -- Reuse the stock name + icon picker; it reads the selection from
        -- GearManagerDialog.selectedSet (name + icon texture object).
        if pane.selectedName then
            local row = pane.selectedRow
            GearManagerDialog.selectedSet = { name = pane.selectedName, icon = row and row.Icon or nil }
        else
            GearManagerDialog.selectedSet = nil
        end
        popup:SetParent(CharacterFrame)
        popup:SetFrameStrata("HIGH")
        popup:SetFrameLevel(CharacterFrame:GetFrameLevel() + 20)
        popup:ClearAllPoints()
        popup:SetPoint("TOPLEFT", CharacterFrame, "TOPRIGHT", 0, -10)
        if popup:IsShown() then
            GearManagerDialogPopup_Update()
        else
            popup:Show()
        end
        return
    end
    -- Fallback without the stock popup: name only, default icon.
    StaticPopupDialogs["DCCF_SAVE_EQUIPMENT_SET"] = StaticPopupDialogs["DCCF_SAVE_EQUIPMENT_SET"] or {
        text = "Save the currently equipped items as:",
        button1 = SAVE or "Save",
        button2 = CANCEL or "Cancel",
        hasEditBox = 1,
        maxLetters = 16,
        OnAccept = function(dialog)
            local name = _G[dialog:GetName() .. "EditBox"]:GetText()
            if name and name ~= "" then
                SaveEquipmentSet(name, 1)
            end
        end,
        EditBoxOnEnterPressed = function(editBox)
            local dialog = editBox:GetParent()
            StaticPopupDialogs["DCCF_SAVE_EQUIPMENT_SET"].OnAccept(dialog)
            dialog:Hide()
        end,
        EditBoxOnEscapePressed = function(editBox)
            editBox:GetParent():Hide()
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
    }
    StaticPopup_Show("DCCF_SAVE_EQUIPMENT_SET")
end

local SET_ROW_H, OUTFIT_ROW_H, MAX_SET_ROWS, MAX_OUTFIT_ROWS = 44, 32, 3, 8

local function CreateSetRow(listPane)
    local row = CreateFrame("Button", nil, listPane)
    row:SetWidth(LIST_ROW_W)
    row:SetHeight(SET_ROW_H)
    DCCF.SkinListRow(row, 32)
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetWidth(36)
    icon:SetHeight(36)
    icon:SetPoint("LEFT", 4, 0)
    row.Icon = icon
    local text = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    text:SetPoint("LEFT", 44, 0)
    text:SetWidth(LIST_ROW_W - 74)
    text:SetHeight(38)
    text:SetJustifyH("LEFT")
    row.Text = text
    local check = row:CreateTexture(nil, "BORDER")
    check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    check:SetWidth(16)
    check:SetHeight(16)
    check:SetPoint("RIGHT", -8, 0)
    check:Hide()
    row.Check = check

    local del = CreateFrame("Button", nil, row)
    del:SetWidth(14)
    del:SetHeight(14)
    del:SetPoint("BOTTOMRIGHT", -2, 2)
    local delTex = del:CreateTexture(nil, "ARTWORK")
    delTex:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    delTex:SetAllPoints(del)
    delTex:SetAlpha(0.5)
    del.texture = delTex
    del:SetScript("OnEnter", function(self)
        self.texture:SetAlpha(1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(DELETE or "Delete")
        GameTooltip:Show()
    end)
    del:SetScript("OnLeave", function(self)
        self.texture:SetAlpha(0.5)
        GameTooltip:Hide()
    end)
    del:SetScript("OnClick", function(self)
        local name = self:GetParent().setName
        if name then
            local dialog = StaticPopup_Show("CONFIRM_DELETE_EQUIPMENT_SET", name)
            if dialog then
                dialog.data = name
            end
        end
    end)
    del:Hide()
    row.Delete = del

    row:SetScript("OnClick", function(self)
        if self.setName then
            PlaySound("igMainMenuOptionCheckBoxOn")
            DCCF.setsPane.selectedName = self.setName
            DCCF.setsPane.Refresh()
        end
    end)
    row:SetScript("OnDoubleClick", function(self)
        if self.setName then
            PlaySound("igCharacterInfoTab")
            EquipmentManager_EquipSet(self.setName)
        end
    end)
    row:SetScript("OnEnter", function(self)
        if self.setName then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetEquipmentSet(self.setName)
        end
    end)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    return row
end

local function UpdateSetRow(row, index)
    local pane = DCCF.setsPane
    local name, icon = GetEquipmentSetInfo(index)
    row.setName = name
    row.Text:SetText(name or "")
    row.Icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    local selected = (pane.selectedName ~= nil and pane.selectedName == name)
    if selected then
        row.Check:Show()
        row.SelectedBar:Show()
        row.Delete:Show()
        pane.selectedRow = row
    else
        row.Check:Hide()
        row.SelectedBar:Hide()
        row.Delete:Hide()
    end
    if index % 2 == 0 then
        row.Stripe:Show()
    else
        row.Stripe:Hide()
    end
end

local function CreateOutfitRow(listPane)
    local row = CreateFrame("Button", nil, listPane)
    row:SetWidth(LIST_ROW_W)
    row:SetHeight(OUTFIT_ROW_H)
    DCCF.SkinListRow(row, 20)
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetWidth(24)
    icon:SetHeight(24)
    icon:SetPoint("LEFT", 5, 0)
    row.Icon = icon
    local text = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    text:SetPoint("LEFT", icon, "RIGHT", 5, 0)
    text:SetPoint("RIGHT", row, "RIGHT", -42, 0)
    text:SetJustifyH("LEFT")
    row.Text = text
    local check = row:CreateTexture(nil, "BORDER")
    check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    check:SetWidth(16)
    check:SetHeight(16)
    check:SetPoint("RIGHT", -22, 0)
    check:Hide()
    row.Check = check

    local del = CreateFrame("Button", nil, row)
    del:SetWidth(13)
    del:SetHeight(13)
    del:SetPoint("RIGHT", -5, 0)
    local delTex = del:CreateTexture(nil, "ARTWORK")
    delTex:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    delTex:SetAllPoints(del)
    delTex:SetAlpha(0.5)
    del.texture = delTex
    del:SetScript("OnEnter", function(self)
        self.texture:SetAlpha(1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(DELETE or "Delete")
        GameTooltip:Show()
    end)
    del:SetScript("OnLeave", function(self)
        self.texture:SetAlpha(0.5)
        GameTooltip:Hide()
    end)
    del:SetScript("OnClick", function(self)
        local id = self:GetParent().outfitId
        if id and DCCF.Outfits then
            DCCF.Outfits:PromptDelete(id)
        end
    end)
    row.Delete = del

    row:SetScript("OnClick", function(self)
        if self.outfitId and DCCF.Outfits then
            PlaySound("igMainMenuOptionCheckBoxOn")
            DCCF.Outfits:Apply(self.outfitId)
        end
    end)
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.Text:GetText() or "", 1, 1, 1)
        if self.isCurrent then
            GameTooltip:AddLine("This is the transmog look you are wearing.", 0.8, 0.8, 0.8, true)
        else
            GameTooltip:AddLine("|cff00ff00Click|r to apply this outfit.", 0.8, 0.8, 0.8, true)
        end
        GameTooltip:AddLine("Rename and overwrite from the outfit dropdown above the model.", 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    return row
end

local function UpdateOutfitRow(row, index)
    local outfits = DCCF.Outfits
    local outfit = outfits.list[index]
    row.outfitId = outfit.id
    row.Text:SetText(outfit.name)
    row.Icon:SetTexture(outfit.icon or "Interface\\Icons\\INV_Chest_Cloth_17")
    local matching = outfits:FindMatching()
    row.isCurrent = (matching ~= nil and matching.id == outfit.id)
    if row.isCurrent then
        row.Check:Show()
        row.SelectedBar:Show()
    else
        row.Check:Hide()
        row.SelectedBar:Hide()
    end
    if index % 2 == 0 then
        row.Stripe:Show()
    else
        row.Stripe:Hide()
    end
end

local function BuildSetsPane(parent)
    local pane = CreateFrame("Frame", "DCCharacterSetsPane", parent)
    pane:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -31)
    pane:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -4, 4)
    pane:SetFrameLevel(parent:GetFrameLevel() + 1)
    DCCF.setsPane = pane

    -- Equipment sets (stock equipment manager API), up to three rows.
    local setsList = DCCF.CreateListPane(pane, {
        name = "DCCharacterSetsList",
        rowHeight = SET_ROW_H,
        numRows = MAX_SET_ROWS,
        createRow = CreateSetRow,
        updateRow = UpdateSetRow,
        getCount = function() return GetNumEquipmentSets() end,
    })
    setsList:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, 0)
    setsList:SetPoint("RIGHT", pane, "RIGHT", 0, 0)
    setsList:SetHeight(SET_ROW_H)
    pane.setsList = setsList
    local emptySets = setsList:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    emptySets:SetPoint("CENTER")
    emptySets:SetText("No equipment sets saved.")
    pane.emptySets = emptySets

    local equip = CreateFrame("Button", "DCCharacterSetsEquipButton", pane, "UIPanelButtonTemplate")
    equip:SetWidth(87)
    equip:SetHeight(22)
    equip:SetPoint("BOTTOMLEFT", pane, "TOPLEFT", 0, 4)
    equip:SetText(EQUIPSET_EQUIP or "Equip")
    equip:SetScript("OnClick", function()
        if pane.selectedName then
            PlaySound("igCharacterInfoTab")
            EquipmentManager_EquipSet(pane.selectedName)
        end
    end)
    pane.EquipButton = equip

    local save = CreateFrame("Button", "DCCharacterSetsSaveButton", pane, "UIPanelButtonTemplate")
    save:SetWidth(87)
    save:SetHeight(22)
    save:SetPoint("LEFT", equip, "RIGHT", 0, 0)
    save:SetText(SAVE or "Save")
    save:SetScript("OnClick", function()
        ShowSaveSetPopup(pane)
    end)
    save:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(SAVE or "Save", 1, 1, 1)
        GameTooltip:AddLine("Save your currently equipped items as a new set, or overwrite the selected one.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    save:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    pane.SaveButton = save

    -- Outfits header: DC-Collection transmog outfits (same list as the dropdown).
    local header = CreateFrame("Frame", nil, pane)
    header:SetHeight(20)
    header:SetPoint("TOPLEFT", setsList, "BOTTOMLEFT", 0, -6)
    header:SetPoint("RIGHT", pane, "RIGHT", 0, 0)
    local headerBg = Tex(header, "BACKGROUND", DCCF.TEX_PARTS, DCCF.PARTS.StatMinimized)
    headerBg:SetPoint("TOPLEFT", 0, -2)
    headerBg:SetPoint("BOTTOMRIGHT", -20, 2)
    local headerText = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    headerText:SetPoint("LEFT", 8, 0)
    headerText:SetText("Outfits")
    pane.outfitHeader = header

    local plus = CreateFrame("Button", "DCCharacterSetsNewOutfitButton", header)
    plus:SetWidth(18)
    plus:SetHeight(18)
    plus:SetPoint("RIGHT", headerBg, "RIGHT", -6, 0)
    local plusTex = plus:CreateTexture(nil, "ARTWORK")
    plusTex:SetTexture(DCCF.TEX_PLUS)
    plusTex:SetAllPoints(plus)
    plus:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    plus:SetScript("OnClick", function()
        if DCCF.Outfits then
            DCCF.Outfits:PromptNew()
        end
    end)
    plus:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("New Outfit", 0, 1, 0)
        GameTooltip:AddLine("Save the transmog look you are wearing right now.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    plus:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    pane.NewOutfitButton = plus

    local outfitList = DCCF.CreateListPane(pane, {
        name = "DCCharacterOutfitList",
        rowHeight = OUTFIT_ROW_H,
        numRows = MAX_OUTFIT_ROWS,
        createRow = CreateOutfitRow,
        updateRow = UpdateOutfitRow,
        getCount = function() return DCCF.Outfits and #DCCF.Outfits.list or 0 end,
    })
    outfitList:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    outfitList:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", 0, 0)
    pane.outfitList = outfitList
    local emptyOutfits = outfitList:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    emptyOutfits:SetPoint("TOP", 0, -12)
    pane.emptyOutfits = emptyOutfits

    function pane.Refresh()
        local numSets = GetNumEquipmentSets()
        if pane.selectedName and not GetEquipmentSetInfoByName(pane.selectedName) then
            pane.selectedName = nil
        end
        pane.selectedRow = nil

        local shown = math.max(1, math.min(MAX_SET_ROWS, numSets))
        setsList:SetHeight(SET_ROW_H * shown)
        setsList.visibleRows = shown
        setsList.Update()
        if numSets == 0 then
            emptySets:Show()
        else
            emptySets:Hide()
        end
        if pane.selectedName then
            equip:Enable()
        else
            equip:Disable()
        end
        if numSets >= (MAX_EQUIPMENT_SETS_PER_PLAYER or 10) and not pane.selectedName then
            save:Disable()
        else
            save:Enable()
        end

        -- Outfits fill whatever height the sets did not use.
        local total = pane:GetHeight()
        if not total or total < 200 then
            total = 325
        end
        local available = total - SET_ROW_H * shown - 6 - 20 - 2
        outfitList.visibleRows = math.max(1, math.min(MAX_OUTFIT_ROWS, math.floor(available / OUTFIT_ROW_H)))
        local outfits = DCCF.Outfits
        local hasCollection = rawget(_G, "DCCollection") ~= nil
        if hasCollection then
            plus:Show()
        else
            plus:Hide()
        end
        outfitList.Update()
        local count = outfits and #outfits.list or 0
        if count == 0 then
            if not hasCollection then
                emptyOutfits:SetText("DC-Collection is not loaded.")
            elseif outfits and outfits.loaded then
                emptyOutfits:SetText("No saved outfits. Click + to save your current look.")
            else
                emptyOutfits:SetText("Loading outfits...")
            end
            emptyOutfits:Show()
        else
            emptyOutfits:Hide()
        end
    end
    pane:SetScript("OnShow", pane.Refresh)
    pane:RegisterEvent("EQUIPMENT_SETS_CHANGED")
    pane:RegisterEvent("EQUIPMENT_SWAP_FINISHED")
    pane:SetScript("OnEvent", function(self, event, completed, setName)
        if event == "EQUIPMENT_SWAP_FINISHED" and completed and setName then
            self.selectedName = setName
        end
        if self:IsVisible() then
            self.Refresh()
        end
        DCCF:UpdateSidebarTabs()
    end)
    return pane
end

DCCF:RegisterSidebar({
    key = "sets",
    name = "Equipment Sets & Outfits",
    atlasIcon = "IconSets",
    build = BuildSetsPane,
    IsActive = function() return true end,
    onShow = function(pane) pane.Refresh() end,
})
