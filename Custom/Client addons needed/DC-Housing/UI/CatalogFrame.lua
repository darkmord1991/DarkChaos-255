-- DC-Housing Catalog: retail-style decoration browser with 3D M2 preview.
local DC = DCHousing
local L = DCHousingLocale

DC.Catalog = DC.Catalog or {}
local Catalog = DC.Catalog

local ROW_COUNT = 14
local ROW_HEIGHT = 20

local frame
local state = {
    category = nil,      -- nil = all
    search = "",
    entries = {},
    selectedEntry = nil,
    previewFacing = 0.6,
}

local function UpdateList()
    state.entries = DC:GetFilteredEntries(state.category, state.search)
    Catalog:RefreshRows()
end

local function SetPreview(entry)
    state.selectedEntry = entry
    local item = DC:GetItem(entry)
    if not item then
        return
    end

    frame.previewName:SetText(item.name)
    frame.previewInfo:SetText(string.format(
        "%s  -  |cffffd700%dg|r  -  weight %d",
        item.category, math.floor(item.cost / 10000), item.weight))

    frame.preview:ClearModel()
    state.previewFacing = 0.6
    local ok = pcall(frame.preview.SetModel, frame.preview, item.path)
    if ok then
        pcall(frame.preview.SetFacing, frame.preview, state.previewFacing)
    end

    local canPlace = DC.budget.canSpawn
    frame.placeButton:SetText(L.PLACE)
    if canPlace then
        frame.placeButton:Enable()
        frame.placeCursorButton:Enable()
    else
        frame.placeButton:Disable()
        frame.placeCursorButton:Disable()
    end
end

function Catalog:RefreshRows()
    local offset = FauxScrollFrame_GetOffset(frame.scroll)
    FauxScrollFrame_Update(frame.scroll, #state.entries, ROW_COUNT,
        ROW_HEIGHT)

    for i = 1, ROW_COUNT do
        local row = frame.rows[i]
        local entry = state.entries[i + offset]
        if entry then
            local item = DC:GetItem(entry)
            row.entry = entry
            row.text:SetText(item.name)
            row.cost:SetText(math.floor(item.cost / 10000) .. "g")
            if entry == state.selectedEntry then
                row:LockHighlight()
            else
                row:UnlockHighlight()
            end
            row:Show()
        else
            row.entry = nil
            row:Hide()
        end
    end
end

function Catalog:OnBudgetUpdate()
    if not frame then
        return
    end
    local b = DC.budget
    frame.budgetBar:SetMinMaxValues(0, math.max(1, b.cap))
    frame.budgetBar:SetValue(b.used)
    frame.budgetText:SetText(string.format(L.BUDGET, b.used, b.cap))
    if state.selectedEntry then
        SetPreview(state.selectedEntry)
    end
end

local function CreateCatalogFrame()
    frame = CreateFrame("Frame", "DCHousingCatalogFrame", UIParent)
    frame:SetWidth(720)
    frame:SetHeight(460)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    frame:Hide()
    tinsert(UISpecialFrames, "DCHousingCatalogFrame")

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText(L.TITLE)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -8)

    -- Category dropdown
    local dropdown = CreateFrame("Frame", "DCHousingCategoryDropDown", frame,
        "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", 4, -36)
    UIDropDownMenu_SetWidth(dropdown, 150)
    UIDropDownMenu_Initialize(dropdown, function()
        local info = UIDropDownMenu_CreateInfo()
        info.text = L.ALL_CATEGORIES
        info.func = function()
            state.category = nil
            UIDropDownMenu_SetText(dropdown, L.ALL_CATEGORIES)
            UpdateList()
        end
        UIDropDownMenu_AddButton(info)

        for _, category in ipairs(DC:GetCategories()) do
            info = UIDropDownMenu_CreateInfo()
            info.text = category
            info.func = function()
                state.category = category
                UIDropDownMenu_SetText(dropdown, category)
                UpdateList()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetText(dropdown, L.ALL_CATEGORIES)

    -- Search box
    local search = CreateFrame("EditBox", "DCHousingSearchBox", frame,
        "InputBoxTemplate")
    search:SetWidth(140)
    search:SetHeight(20)
    search:SetPoint("TOPLEFT", 200, -42)
    search:SetAutoFocus(false)
    search:SetScript("OnTextChanged", function(self)
        state.search = self:GetText() or ""
        UpdateList()
    end)
    search:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    -- Item list rows + scroll
    frame.rows = {}
    local listAnchor = CreateFrame("Frame", nil, frame)
    listAnchor:SetPoint("TOPLEFT", 18, -72)
    listAnchor:SetWidth(330)
    listAnchor:SetHeight(ROW_COUNT * ROW_HEIGHT)

    local scroll = CreateFrame("ScrollFrame", "DCHousingCatalogScroll",
        frame, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", listAnchor)
    scroll:SetPoint("BOTTOMRIGHT", listAnchor)
    scroll:SetScript("OnVerticalScroll", function(self, value)
        FauxScrollFrame_OnVerticalScroll(self, value, ROW_HEIGHT,
            function() Catalog:RefreshRows() end)
    end)
    frame.scroll = scroll

    for i = 1, ROW_COUNT do
        local row = CreateFrame("Button", nil, frame)
        row:SetWidth(330)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", listAnchor, "TOPLEFT", 0,
            -(i - 1) * ROW_HEIGHT)
        row:SetHighlightTexture(
            "Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.text:SetPoint("LEFT", 4, 0)
        row.text:SetWidth(270)
        row.text:SetJustifyH("LEFT")

        row.cost = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.cost:SetPoint("RIGHT", -4, 0)

        row:SetScript("OnClick", function(self)
            if self.entry then
                SetPreview(self.entry)
                Catalog:RefreshRows()
            end
        end)
        frame.rows[i] = row
    end

    -- Preview pane
    local previewBg = CreateFrame("Frame", nil, frame)
    previewBg:SetPoint("TOPLEFT", 370, -72)
    previewBg:SetWidth(330)
    previewBg:SetHeight(250)
    previewBg:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    previewBg:SetBackdropColor(0, 0, 0, 0.6)

    local preview = CreateFrame("Model", "DCHousingPreviewModel", previewBg)
    preview:SetPoint("TOPLEFT", 4, -4)
    preview:SetPoint("BOTTOMRIGHT", -4, 4)
    preview:EnableMouse(true)
    preview:SetScript("OnMouseDown", function(self)
        self.rotating = true
        self.lastX = GetCursorPosition()
    end)
    preview:SetScript("OnMouseUp", function(self)
        self.rotating = false
    end)
    preview:SetScript("OnUpdate", function(self)
        if self.rotating then
            local x = GetCursorPosition()
            state.previewFacing = state.previewFacing
                + (x - (self.lastX or x)) * 0.02
            self.lastX = x
            pcall(self.SetFacing, self, state.previewFacing)
        end
    end)
    frame.preview = preview

    frame.previewName = frame:CreateFontString(nil, "OVERLAY",
        "GameFontNormal")
    frame.previewName:SetPoint("TOPLEFT", previewBg, "BOTTOMLEFT", 2, -6)
    frame.previewName:SetWidth(330)
    frame.previewName:SetJustifyH("LEFT")

    frame.previewInfo = frame:CreateFontString(nil, "OVERLAY",
        "GameFontHighlightSmall")
    frame.previewInfo:SetPoint("TOPLEFT", frame.previewName, "BOTTOMLEFT",
        0, -4)
    frame.previewInfo:SetWidth(330)
    frame.previewInfo:SetJustifyH("LEFT")

    -- Action buttons
    local place = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    place:SetWidth(100)
    place:SetHeight(22)
    place:SetPoint("TOPLEFT", previewBg, "BOTTOMLEFT", 0, -44)
    place:SetText(L.PLACE)
    place:SetScript("OnClick", function()
        if state.selectedEntry then
            DC.Protocol:Place(state.selectedEntry)
        end
    end)
    frame.placeButton = place

    local placeCursor = CreateFrame("Button", nil, frame,
        "UIPanelButtonTemplate")
    placeCursor:SetWidth(130)
    placeCursor:SetHeight(22)
    placeCursor:SetPoint("LEFT", place, "RIGHT", 6, 0)
    placeCursor:SetText(L.PLACE_AT_CURSOR)
    placeCursor:SetScript("OnClick", function()
        if state.selectedEntry then
            DC.EditMode:StartGhostPlacement(state.selectedEntry)
            frame:Hide()
        end
    end)
    frame.placeCursorButton = placeCursor

    local edit = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    edit:SetWidth(90)
    edit:SetHeight(22)
    edit:SetPoint("LEFT", placeCursor, "RIGHT", 6, 0)
    edit:SetText(L.EDIT_MODE)
    edit:SetScript("OnClick", function()
        DC.EditMode:Toggle()
    end)

    -- Budget bar
    local bar = CreateFrame("StatusBar", nil, frame)
    bar:SetPoint("BOTTOMLEFT", 18, 18)
    bar:SetWidth(330)
    bar:SetHeight(16)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.2, 0.7, 0.2)
    local barBg = bar:CreateTexture(nil, "BACKGROUND")
    barBg:SetAllPoints()
    barBg:SetTexture(0, 0, 0, 0.5)
    frame.budgetBar = bar

    frame.budgetText = bar:CreateFontString(nil, "OVERLAY",
        "GameFontHighlightSmall")
    frame.budgetText:SetPoint("CENTER")

    UpdateList()
    Catalog:OnBudgetUpdate()
end

function Catalog:Toggle()
    if not frame then
        CreateCatalogFrame()
    end
    if frame:IsShown() then
        frame:Hide()
    else
        DC.Protocol:RequestBudget()
        UpdateList()
        frame:Show()
    end
end
