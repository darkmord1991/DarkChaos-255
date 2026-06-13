-- DC-Housing Catalog: retail-style decoration browser with 3D M2 preview.
local DC = DCHousing
local L = DCHousingLocale

DC.Catalog = DC.Catalog or {}
local Catalog = DC.Catalog

local ROW_COUNT = 14
local ROW_HEIGHT = 20

local frame
local state = {
    mode = "catalog",    -- "catalog" or "placed"
    category = nil,      -- nil = all
    search = "",
    entries = {},
    selectedEntry = nil,
    placedSel = nil,     -- selected placed lowguid (manage mode)
    placedSelEntry = nil,
    previewFacing = 0.6,
}

local function UpdateList()
    if state.mode == "placed" then
        Catalog:RefreshRows()
        return
    end
    state.entries = DC:GetFilteredEntries(state.category, state.search)
    Catalog:RefreshRows()
end

-- Load a model into the preview pane and frame it (shared by catalog
-- selection and placed-object selection).
function Catalog:LoadPreviewModel(item)
    if not frame or not item then
        return
    end
    frame.preview:ClearModel()
    state.previewFacing = 0.6
    state.previewRadius = math.max(item.radius or 1.0, 0.2)
    state.previewDepth = state.previewRadius * 2.2
    state.previewVertical = 0
    if pcall(frame.preview.SetModel, frame.preview, item.path) then
        Catalog:ApplyPreviewTransform()
    end
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

    Catalog:LoadPreviewModel(item)

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

-- Select a placed decoration (manage mode): preview its model + enable the
-- management buttons.
local function SetPlacedSelection(item)
    if not item then
        return
    end
    state.placedSel = item.lowguid
    state.placedSelEntry = item.entry
    local model = DC:GetItem(item.entry)
    frame.previewName:SetText(model and model.name or ("Entry "
        .. tostring(item.entry)))
    frame.previewInfo:SetText("Placed - select an action below")
    if model then
        Catalog:LoadPreviewModel(model)
    end
    if frame.manageButtons then
        for _, b in ipairs(frame.manageButtons) do
            b:Enable()
        end
    end
end

-- Frame an arbitrary GO model. On the 3.3.5 Model widget the camera is
-- fixed; SetPosition(x, y, z) moves the MODEL relative to it where +x is
-- DEPTH (distance from the camera - bigger = farther/smaller) and z is
-- vertical. SetModelScale barely changes apparent size because the widget
-- auto-frames the (scaled) bounding sphere, so depth is the real zoom.
-- previewDepth/previewVertical are seeded from the model's bounding radius
-- and adjustable with the mouse wheel (zoom) and shift+wheel (pan).
function Catalog:ApplyPreviewTransform()
    if not frame or not frame.preview then
        return
    end
    local m = frame.preview
    pcall(m.SetModelScale, m, 1.0)
    if m.SetCamera then
        pcall(m.SetCamera, m, 0)
    end
    pcall(m.SetPosition, m, state.previewDepth or 1.5, 0,
        state.previewVertical or 0)
    pcall(m.SetFacing, m, state.previewFacing or 0.6)
end

function Catalog:RefreshRows()
    if state.mode == "placed" then
        local placed = DC.placed or {}
        local offset = FauxScrollFrame_GetOffset(frame.scroll)
        FauxScrollFrame_Update(frame.scroll, #placed, ROW_COUNT, ROW_HEIGHT)
        for i = 1, ROW_COUNT do
            local row = frame.rows[i]
            local item = placed[i + offset]
            if item then
                row.entry = nil
                row.placed = item
                row.text:SetText(item.name and item.name ~= "" and item.name
                    or ("Entry " .. tostring(item.entry)))
                row.cost:SetText("")
                if item.lowguid == state.placedSel then
                    row:LockHighlight()
                else
                    row:UnlockHighlight()
                end
                row:Show()
            else
                row.entry = nil
                row.placed = nil
                row:Hide()
            end
        end
        return
    end

    local offset = FauxScrollFrame_GetOffset(frame.scroll)
    FauxScrollFrame_Update(frame.scroll, #state.entries, ROW_COUNT,
        ROW_HEIGHT)

    for i = 1, ROW_COUNT do
        local row = frame.rows[i]
        local entry = state.entries[i + offset]
        if entry then
            local item = DC:GetItem(entry)
            row.entry = entry
            row.placed = nil
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
            row.placed = nil
            row:Hide()
        end
    end
end

-- Refresh after a SMSG_LIST arrives.
function Catalog:OnPlacedUpdate()
    if frame and state.mode == "placed" then
        Catalog:RefreshRows()
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
    frame:SetFrameStrata("HIGH")
    frame:SetWidth(720)
    frame:SetHeight(470)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    tinsert(UISpecialFrames, "DCHousingCatalogFrame")

    -- DC house style (matches DC-Collection / DC-Leaderboards):
    -- leather background + dark tint + dialog border + portrait ring.
    frame.bg = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
    frame.bg:SetAllPoints()
    frame.bg:SetTexture("Interface\\DC\\Shared\\FelLeather_512.tga")
    if frame.bg.SetHorizTile then frame.bg:SetHorizTile(false) end
    if frame.bg.SetVertTile then frame.bg:SetVertTile(false) end

    frame.bgTint = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    frame.bgTint:SetAllPoints()
    frame.bgTint:SetTexture(0, 0, 0, 0.60)

    frame.border = CreateFrame("Frame", nil, frame)
    frame.border:SetAllPoints()
    frame.border:SetBackdrop({
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })

    local portraitRing = frame:CreateTexture(nil, "OVERLAY")
    portraitRing:SetWidth(52)
    portraitRing:SetHeight(52)
    portraitRing:SetPoint("TOPLEFT", 10, -10)
    portraitRing:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    portraitRing:SetTexCoord(0, 0.50, 0, 0.50)

    local portrait = frame:CreateTexture(nil, "ARTWORK")
    portrait:SetWidth(34)
    portrait:SetHeight(34)
    portrait:SetPoint("CENTER", portraitRing, "CENTER", 0, -1)
    portrait:SetTexture("Interface\\Icons\\INV_Misc_Lantern_01")
    portrait:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local title = frame:CreateFontString(nil, "OVERLAY",
        "GameFontHighlightLarge")
    title:SetPoint("TOP", 0, -14)
    title:SetText("|cffFFCC00DC|r " .. L.TITLE)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)

    -- Category dropdown
    local dropdown = CreateFrame("Frame", "DCHousingCategoryDropDown", frame,
        "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", 52, -38)
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
    search:SetPoint("TOPLEFT", 248, -44)
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
    listAnchor:SetPoint("TOPLEFT", 18, -78)
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
            if state.mode == "placed" then
                if self.placed then
                    SetPlacedSelection(self.placed)
                    Catalog:RefreshRows()
                end
            elseif self.entry then
                SetPreview(self.entry)
                Catalog:RefreshRows()
            end
        end)
        frame.rows[i] = row
    end

    -- Preview pane
    local previewBg = CreateFrame("Frame", nil, frame)
    previewBg:SetPoint("TOPLEFT", 370, -78)
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
    preview:EnableMouseWheel(true)
    preview:SetScript("OnMouseDown", function(self)
        self.rotating = true
        self.lastX = GetCursorPosition()
    end)
    preview:SetScript("OnMouseUp", function(self)
        self.rotating = false
    end)
    preview:SetScript("OnMouseWheel", function(_, delta)
        local radius = state.previewRadius or 1.0
        local step = math.max(radius * 0.25, 0.15)
        if IsShiftKeyDown() then
            -- vertical pan
            state.previewVertical = (state.previewVertical or 0)
                + delta * step
        else
            -- zoom: wheel up = closer (smaller depth)
            local d = (state.previewDepth or radius * 2.2) - delta * step
            if d < 0.2 then d = 0.2 end
            if d > radius * 12 then d = radius * 12 end
            state.previewDepth = d
        end
        Catalog:ApplyPreviewTransform()
    end)
    preview:SetScript("OnUpdate", function(self)
        if self.rotating then
            local x = GetCursorPosition()
            state.previewFacing = (state.previewFacing or 0.6)
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
    frame.catalogButtons = { place, placeCursor, edit }

    -- ---- Manage-placed action buttons (shown only in "placed" mode) ----
    frame.manageButtons = {}
    local function ManageBtn(text, width, anchorTo, x, y, onClick)
        local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        b:SetWidth(width)
        b:SetHeight(22)
        b:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", x, y)
        b:SetText(text)
        b:SetScript("OnClick", function()
            if state.placedSel then
                onClick(state.placedSel)
                -- refresh positions shortly after the server applies it
                DC.Protocol:RequestList()
            end
        end)
        b:Hide()
        table.insert(frame.manageButtons, b)
        return b
    end

    -- Row 1: Move Here / Rotate / Remove
    ManageBtn("Move Here", 100, previewBg, 0, -44, function(g)
        DC.Protocol:MoveHere(g)
    end)
    ManageBtn("Rotate", 90, previewBg, 106, -44, function(g)
        DC.Protocol:Rotate(g)
    end)
    local removeBtn = ManageBtn("Remove", 90, previewBg, 202, -44,
        function(g)
            StaticPopup_Show("DCHOUSING_REMOVE_PLACED")
            return
        end)
    removeBtn:SetScript("OnClick", function()
        if state.placedSel then
            StaticPopup_Show("DCHOUSING_REMOVE_PLACED")
        end
    end)

    -- Row 2: nudge grid (precise position/rotation tweaks)
    local nudges = {
        { "X+", 80, 0, -72, 0.5, 0, 0, 0 },
        { "X-", 80, 84, -72, -0.5, 0, 0, 0 },
        { "Y+", 80, 168, -72, 0, 0.5, 0, 0 },
        { "Y-", 80, 252, -72, 0, -0.5, 0, 0 },
        { "Z+", 80, 0, -98, 0, 0, 0.5, 0 },
        { "Z-", 80, 84, -98, 0, 0, -0.5, 0 },
        { "Turn +", 80, 168, -98, 0, 0, 0, 0.3927 },
        { "Turn -", 80, 252, -98, 0, 0, 0, -0.3927 },
    }
    for _, n in ipairs(nudges) do
        ManageBtn(n[1], n[2], previewBg, n[3], n[4], function(g)
            DC.Protocol:Nudge(g, n[5], n[6], n[7], n[8])
        end)
    end

    StaticPopupDialogs["DCHOUSING_REMOVE_PLACED"] = {
        text = "Remove this decoration? You get a partial refund.",
        button1 = YES,
        button2 = NO,
        OnAccept = function()
            if state.placedSel then
                DC.Protocol:Remove(state.placedSel)
                state.placedSel = nil
                DC.Protocol:RequestList()
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }

    -- ---- Mode toggle (Browse Catalog <-> Manage Placed) ----
    local modeToggle = CreateFrame("Button", nil, frame,
        "UIPanelButtonTemplate")
    modeToggle:SetWidth(150)
    modeToggle:SetHeight(22)
    modeToggle:SetPoint("TOPRIGHT", -42, -40)
    modeToggle:SetScript("OnClick", function()
        Catalog:SetMode(state.mode == "catalog" and "placed" or "catalog")
    end)
    frame.modeToggle = modeToggle

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

    Catalog:SetMode("catalog")
    Catalog:OnBudgetUpdate()
end

-- Switch between browsing the catalog and managing placed decorations.
function Catalog:SetMode(mode)
    state.mode = mode
    local placed = (mode == "placed")

    for _, b in ipairs(frame.catalogButtons or {}) do
        if placed then b:Hide() else b:Show() end
    end
    for _, b in ipairs(frame.manageButtons or {}) do
        if placed then
            b:Show()
            if state.placedSel then b:Enable() else b:Disable() end
        else
            b:Hide()
        end
    end

    if frame.modeToggle then
        frame.modeToggle:SetText(placed and "Browse Catalog"
            or "Manage Placed")
    end

    if placed then
        state.placedSel = nil
        state.placedSelEntry = nil
        frame.previewName:SetText("Placed Decorations")
        frame.previewInfo:SetText(
            "Select an object, then Move Here / Rotate / Remove.")
        frame.preview:ClearModel()
        DC.Protocol:RequestList()
    end

    -- Reset scroll to top when switching modes.
    FauxScrollFrame_SetOffset(frame.scroll, 0)
    if frame.scroll.ScrollBar then
        frame.scroll.ScrollBar:SetValue(0)
    end
    UpdateList()
end

function Catalog:Show()
    if not frame then
        CreateCatalogFrame()
    end
    DC.Protocol:RequestBudget()
    UpdateList()
    frame:Show()
end

function Catalog:Toggle()
    if frame and frame:IsShown() then
        frame:Hide()
    else
        self:Show()
    end
end
