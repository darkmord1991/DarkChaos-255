-- DC-Housing Catalog: retail-style decoration browser with 3D M2 preview.
local DC = DCHousing
local L = DCHousingLocale

DC.Catalog = DC.Catalog or {}
local Catalog = DC.Catalog

local ROW_COUNT = 14      -- placed-decoration list (manage mode)
local ROW_HEIGHT = 20

-- Catalog grid, after retail's HousingCatalogEntry tiles: a thumbnail per
-- decor (Blizzard's pre-rendered one) or, when there is none, a live model.
local GRID_COLUMNS = 5
local GRID_ROWS = 4
local TILE_SIZE = 62
local TILE_STEP = 66       -- tile + gap
local TILE_INSET = 4

-- Preview camera. Retail's default scene (UiModelScene 1317) orbits 30 degrees
-- off the model's front at zoom distance 3.5; BASE_SCALE / radius frames a
-- model at that distance, and other scenes scale it by 3.5 / their zoom.
local DEFAULT_FACING = 0.52
local DEFAULT_ZOOM = 3.5
local BASE_SCALE = 0.22
-- Sign that makes a positive scene pitch show the model's top (retail's
-- camera looking down). The widget's camera faces the model's front (+X) and
-- SetModelPitch turns +X toward the top for positive angles; flip this if
-- rugs come up showing their underside.
local PITCH_SIGN = 1

local frame
local state = {
    mode = "catalog",    -- "catalog" or "placed"
    category = nil,      -- Blizzard category; nil = all
    subcategory = nil,   -- Blizzard subcategory within it; nil = whole category
    filters = {},        -- [tag group] = { [value] = true }
    search = "",
    entries = {},
    selectedEntry = nil,
    placedSel = nil,     -- selected placed lowguid (manage mode)
    placedSelEntry = nil,
    previewItem = nil,
    previewFacing = DEFAULT_FACING,
    previewPitch = 0,
}

local function Clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

-- Frame an arbitrary GO model. Mirrors the WORKING DC-GM gameobject preview
-- (Commands_GO.lua ShowGobModel) exactly: SetSequence(0) for a static pose,
-- SetCamera(2) (camera 0 framed nothing for doodads), SetLight (a bare Model
-- frame is unlit = black without it), SetModelScale for zoom (the widget
-- auto-frames the bounding sphere, so scale is the real zoom — NOT a large
-- SetPosition depth, which pushed the model out of view), and a small centred
-- SetPosition. view = { scale, vertical, facing, pitch }.
local function ApplyModelView(m, view)
    -- Centre offset in the frame's normalised half-dimensions, as DC-GM does.
    local uiScale = UIParent:GetEffectiveScale()
    local hyp = ((GetScreenWidth() * uiScale) ^ 2
        + (GetScreenHeight() * uiScale) ^ 2) ^ 0.5
    local coordX, coordY = 0, 0
    if hyp > 0 and m:GetRight() and m:GetLeft() and m:GetTop()
        and m:GetBottom() then
        coordX = (m:GetRight() - m:GetLeft()) / hyp / 2
        coordY = (m:GetTop() - m:GetBottom()) / hyp / 2
    end

    pcall(m.SetSequence, m, 0)
    pcall(m.SetCamera, m, 2)
    pcall(m.SetLight, m, 1, 0, 0, -0.707, -0.707, 0.7,
        1.0, 1.0, 1.0, 0.8, 1.0, 1.0, 0.8)
    pcall(m.SetModelScale, m, view.scale or 0.5)
    pcall(m.SetPosition, m, coordX, coordY, view.vertical or 0)
    pcall(m.SetFacing, m, view.facing or DEFAULT_FACING)
    -- WXL native: tumble about the view's horizontal axis (the stock widget
    -- has no pitch, so flat items like rugs sit edge-on without this).
    -- Pitch 0 clears the native's per-widget state; safe unconditionally.
    if type(SetModelPitch) == "function" then
        pcall(SetModelPitch, m, view.pitch or 0)
    end
end

-- The view retail's scene gives an item: its pitch, and a scale that fits
-- the model's radius at the scene's zoom distance.
local function SceneView(item)
    local pitch, zoom, actorScale = DC:GetPreviewCamera(item)
    local radius = math.max(item.radius or 1.0, 0.4)
    return {
        scale = Clamp(BASE_SCALE / radius * (DEFAULT_ZOOM / zoom) * actorScale,
            0.03, 1.0),
        vertical = 0,
        facing = DEFAULT_FACING,
        pitch = pitch * PITCH_SIGN,
    }
end

-- Retail greys out catalog entries that cannot be placed right now.
local function CanPlaceItem(item)
    local b = DC.budget
    if (b.houseLevel or 0) > 0 and (item.minLevel or 1) > b.houseLevel then
        return false, string.format(L.NEEDS_HOUSE_LEVEL, item.minLevel)
    end
    if (b.cap or 0) > 0 and (b.used or 0) + (item.weight or 1) > b.cap then
        return false, L.OVER_BUDGET
    end
    return true
end

local function UpdateList()
    if state.mode == "placed" then
        Catalog:RefreshRows()
        return
    end
    state.entries = DC:GetFilteredEntries({
        category = state.category,
        subcategory = state.subcategory,
        filters = state.filters,
        search = state.search,
    })
    Catalog:RefreshRows()
end

local function ActiveFilterCount()
    local count = 0
    for _, values in pairs(state.filters) do
        for _ in pairs(values) do
            count = count + 1
        end
    end
    return count
end

local function ResetScroll()
    FauxScrollFrame_SetOffset(frame.scroll, 0)
    local bar = frame.scroll.ScrollBar
        or _G[(frame.scroll:GetName() or "") .. "ScrollBar"]
    if bar then
        bar:SetValue(0)
    end
end

local function UpdateFilterButton()
    if frame and frame.filterButton then
        local count = ActiveFilterCount()
        frame.filterButton:SetText(count > 0
            and string.format(L.FILTERS_ACTIVE, count) or L.FILTERS)
    end
end

-- Category / subcategory picker: Blizzard's categories on level 1 (click one
-- for the whole category, hover for its subcategories on level 2).
local function SelectCategory(category, subcategory)
    state.category = category
    state.subcategory = subcategory
    UIDropDownMenu_SetText(frame.categoryDropDown,
        subcategory or category or L.ALL_CATEGORIES)
    CloseDropDownMenus()
    ResetScroll()
    UpdateList()
end

function Catalog:InitCategoryMenu(level)
    level = level or 1
    local info
    if level == 1 then
        info = UIDropDownMenu_CreateInfo()
        info.text = L.ALL_CATEGORIES
        info.checked = state.category == nil
        info.func = function() SelectCategory(nil, nil) end
        UIDropDownMenu_AddButton(info, level)

        for _, node in ipairs(DC:GetCategoryTree()) do
            local name = node.name
            info = UIDropDownMenu_CreateInfo()
            info.text = string.format("%s (%d)", name, node.count)
            info.icon = node.icon
            info.value = name
            info.hasArrow = true
            info.checked = state.category == name
            info.func = function() SelectCategory(name, nil) end
            UIDropDownMenu_AddButton(info, level)
        end
    elseif level == 2 then
        local category = UIDROPDOWNMENU_MENU_VALUE
        for _, node in ipairs(DC:GetCategoryTree()) do
            if node.name == category then
                info = UIDropDownMenu_CreateInfo()
                info.text = string.format(L.ALL_IN_CATEGORY, category)
                info.checked = state.category == category
                    and state.subcategory == nil
                info.func = function() SelectCategory(category, nil) end
                UIDropDownMenu_AddButton(info, level)

                for _, sub in ipairs(node.subcategories) do
                    local subName = sub.name
                    info = UIDropDownMenu_CreateInfo()
                    info.text = string.format("%s (%d)", subName, sub.count)
                    info.checked = state.subcategory == subName
                    info.func = function()
                        SelectCategory(category, subName)
                    end
                    UIDropDownMenu_AddButton(info, level)
                end
            end
        end
    end
end

-- Tag filters (Blizzard's DataTag groups): one submenu per group, values
-- toggle in place and combine OR within a group, AND across groups.
function Catalog:InitFilterMenu(level)
    level = level or 1
    local info
    if level == 1 then
        for _, group in ipairs(DC:GetFilterGroups()) do
            local selected = 0
            for _ in pairs(state.filters[group.name] or {}) do
                selected = selected + 1
            end
            info = UIDropDownMenu_CreateInfo()
            info.text = selected > 0
                and string.format("%s (%d)", group.name, selected) or group.name
            info.value = group.name
            info.hasArrow = true
            info.notCheckable = true
            UIDropDownMenu_AddButton(info, level)
        end

        info = UIDropDownMenu_CreateInfo()
        info.text = L.CLEAR_FILTERS
        info.notCheckable = true
        info.disabled = ActiveFilterCount() == 0
        info.func = function()
            state.filters = {}
            UpdateFilterButton()
            ResetScroll()
            UpdateList()
        end
        UIDropDownMenu_AddButton(info, level)
    elseif level == 2 then
        local groupName = UIDROPDOWNMENU_MENU_VALUE
        for _, group in ipairs(DC:GetFilterGroups()) do
            if group.name == groupName then
                for _, value in ipairs(group.values) do
                    info = UIDropDownMenu_CreateInfo()
                    info.text = value
                    info.keepShownOnClick = 1
                    info.checked = state.filters[groupName] ~= nil
                        and state.filters[groupName][value] == true
                    info.func = function()
                        local values = state.filters[groupName] or {}
                        values[value] = not values[value] or nil
                        state.filters[groupName] = next(values) and values or nil
                        UpdateFilterButton()
                        ResetScroll()
                        UpdateList()
                    end
                    UIDropDownMenu_AddButton(info, level)
                end
            end
        end
    end
end

-- Load a model into the preview pane and frame it (shared by catalog
-- selection and placed-object selection).
function Catalog:LoadPreviewModel(item)
    if not frame or not item then
        return
    end
    local m = frame.preview
    m:ClearModel()
    -- Frame the view (camera/light/scale/position) THEN load the model last —
    -- the exact call order proven to work by the DC-GM gameobject preview.
    -- Re-apply after SetModel as well in case loading resets the transform.
    Catalog:ResetPreviewView(item)
    pcall(m.SetModel, m, item.path)
    Catalog:ApplyPreviewTransform()
end

-- Retail's scene camera for the item: facing, pitch preset (rugs seen from
-- above, ceiling pieces from below) and a scale that fits the model.
function Catalog:ResetPreviewView(item)
    item = item or state.previewItem
    if not item then
        return
    end
    state.previewItem = item
    local view = SceneView(item)
    state.previewScale = view.scale
    state.previewVertical = view.vertical
    state.previewFacing = view.facing
    state.previewPitch = view.pitch
    Catalog:ApplyPreviewTransform()
end

-- Rotate/zoom controls on the preview (retail ModelSceneControls).
function Catalog:ZoomPreview(factor)
    state.previewScale = Clamp((state.previewScale or 0.5) * factor, 0.02, 3.0)
    Catalog:ApplyPreviewTransform()
end

local function SetPreview(entry)
    state.selectedEntry = entry
    local item = DC:GetItem(entry)
    if not item then
        return
    end

    frame.previewName:SetText(item.name)
    frame.previewInfo:SetText(string.format(
        "%s / %s  -  |cffffd700%dg|r  -  weight %d",
        item.category or "?", item.subcategory or "?",
        math.floor(item.cost / 10000), item.weight))
    Catalog:SetPreviewTags(item)

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
    Catalog:SetPreviewTags(model)
    if model then
        Catalog:LoadPreviewModel(model)
    end
    if frame.manageButtons then
        for _, b in ipairs(frame.manageButtons) do
            b:Enable()
        end
    end

    -- Also bring up the in-world gizmo for this placed object so it can be
    -- dragged directly (selects by spawn id; the server resolves and returns
    -- its live GUID).
    if DC.EditMode and DC.EditMode.SelectPlaced then
        DC.EditMode:SelectPlaced(item.lowguid)
    end
end

-- Placement surface and Blizzard tags, overlaid along the preview's bottom
-- edge: "Wall  -  Medium, Elven, Midnight, Elegant".
function Catalog:SetPreviewTags(item)
    if not frame or not frame.previewTags then
        return
    end
    if not item then
        frame.previewTags:SetText("")
        return
    end
    local values = {}
    for _, tag in ipairs(item.tags or {}) do
        local value = string.match(tag, "^[^:]+:(.+)$")
        if value then
            table.insert(values, value)
        end
    end
    local placement = DC:GetPlacementName(item) or ""
    frame.previewTags:SetText(placement
        .. (#values > 0 and ("  -  " .. table.concat(values, ", ")) or ""))
end

-- Zoom = mouse wheel / controls (previewScale), vertical pan = shift+wheel.
function Catalog:ApplyPreviewTransform()
    if not frame or not frame.preview then
        return
    end
    ApplyModelView(frame.preview, {
        scale = state.previewScale,
        vertical = state.previewVertical,
        facing = state.previewFacing,
        pitch = state.previewPitch,
    })
end

function Catalog:RefreshRows()
    if state.mode == "placed" then
        for _, tile in ipairs(frame.tiles) do
            tile:Hide()
        end
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

    for i = 1, ROW_COUNT do
        frame.rows[i].entry = nil
        frame.rows[i].placed = nil
        frame.rows[i]:Hide()
    end
    Catalog:RefreshGrid()
end

-- One page of the catalog grid; the scroll offset counts grid rows.
function Catalog:RefreshGrid()
    FauxScrollFrame_Update(frame.scroll,
        math.ceil(#state.entries / GRID_COLUMNS), GRID_ROWS, TILE_STEP)
    local first = FauxScrollFrame_GetOffset(frame.scroll) * GRID_COLUMNS
    for i, tile in ipairs(frame.tiles) do
        Catalog:UpdateTile(tile, state.entries[first + i])
    end
end

-- A tile shows the decor's thumbnail, or a live model of it when there is no
-- thumbnail (retail's own fallback), greyed out when it cannot be placed.
function Catalog:UpdateTile(tile, entry)
    local item = entry and DC:GetItem(entry)
    tile.entry = entry
    if not item then
        tile:Hide()
        return
    end

    local placeable = CanPlaceItem(item)
    if item.thumb then
        tile.model:Hide()
        tile.icon:SetTexture(item.thumb)
        tile.icon:SetDesaturated(not placeable)
        tile.icon:SetAlpha(placeable and 1 or 0.5)
        tile.icon:Show()
    else
        tile.icon:Hide()
        tile.model:Show()
        -- A tile keeps its model while it shows the same item, so paging back
        -- and forth does not reload models.
        if tile.modelPath ~= item.path then
            tile.modelPath = item.path
            local view = SceneView(item)
            ApplyModelView(tile.model, view)
            pcall(tile.model.SetModel, tile.model, item.path)
            ApplyModelView(tile.model, view)
        end
        tile.model:SetAlpha(placeable and 1 or 0.5)
    end
    if entry == state.selectedEntry then
        tile.selected:Show()
    else
        tile.selected:Hide()
    end
    tile:Show()
end

function Catalog:ShowTileTooltip(tile)
    local item = tile.entry and DC:GetItem(tile.entry)
    if not item then
        return
    end
    GameTooltip:SetOwner(tile, "ANCHOR_RIGHT")
    GameTooltip:AddLine(item.name, 1, 0.82, 0)
    GameTooltip:AddLine(string.format("%s / %s", item.category or "?",
        item.subcategory or "?"), 0.8, 0.8, 0.8)
    GameTooltip:AddDoubleLine(string.format("%dg", math.floor(item.cost / 10000)),
        "weight " .. tostring(item.weight), 1, 1, 1, 0.7, 0.7, 0.7)
    local placeable, reason = CanPlaceItem(item)
    if not placeable and reason then
        GameTooltip:AddLine(reason, 1, 0.25, 0.25)
    end
    GameTooltip:Show()
end

-- Mouse wheel over a tile scrolls the grid by rows (tiles sit above the
-- scroll frame, so they forward the wheel themselves).
local function ScrollGrid(delta)
    local bar = frame.scroll.ScrollBar
        or _G[(frame.scroll:GetName() or "") .. "ScrollBar"]
    if bar then
        bar:SetValue(bar:GetValue() - delta * TILE_STEP)
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
    -- Tiles grey out what the new budget/house level no longer allows.
    if state.mode == "catalog" and frame.tiles then
        Catalog:RefreshGrid()
    end
    -- Only refresh the place buttons' enabled state; re-calling SetPreview
    -- here reloaded the 3D preview (resetting facing/zoom) on every budget
    -- push the server sends.
    if state.selectedEntry then
        if b.canSpawn then
            frame.placeButton:Enable()
            frame.placeCursorButton:Enable()
        else
            frame.placeButton:Disable()
            frame.placeCursorButton:Disable()
        end
    end
end

-- Called by Protocol on a successful remove: drop a now-dead placed-list
-- selection and re-request the list when the manage UI is on screen.
function Catalog:OnDecorationRemoved(lowguid)
    if lowguid and state.placedSel
        and tonumber(state.placedSel) == tonumber(lowguid) then
        state.placedSel = nil
        state.placedSelEntry = nil
        if frame and frame.manageButtons and state.mode == "placed" then
            for _, b in ipairs(frame.manageButtons) do
                b:Disable()
            end
        end
    end
    if frame and frame:IsShown() and state.mode == "placed" then
        DC.Protocol:RequestList()
    end
end

-- Called by Protocol on a successful move: the server has now really applied
-- it (the request may have sat in the move coalescer), so this is the safe
-- moment to refresh the placed list's positions.
function Catalog:OnDecorationMoved()
    if frame and frame:IsShown() and state.mode == "placed" then
        DC.Protocol:RequestList()
    end
end

local function CreateCatalogFrame()
    frame = CreateFrame("Frame", "DCHousingCatalogFrame", UIParent)
    frame:SetFrameStrata("HIGH")
    frame:SetWidth(720)
    frame:SetHeight(470)
    -- Docked to the left edge (not centred) so the world stays visible to the
    -- right while you place/position decorations. Still movable + clamped.
    frame:SetPoint("LEFT", 24, 0)
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

    -- Category dropdown (Blizzard categories -> subcategories)
    local dropdown = CreateFrame("Frame", "DCHousingCategoryDropDown", frame,
        "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", 52, -38)
    UIDropDownMenu_SetWidth(dropdown, 150)
    UIDropDownMenu_Initialize(dropdown, function(_, level)
        Catalog:InitCategoryMenu(level)
    end)
    UIDropDownMenu_SetText(dropdown, L.ALL_CATEGORIES)
    frame.categoryDropDown = dropdown

    -- Tag filters (Size, Culture, Expansion, Style, Theme, Color, Holiday)
    local filterMenu = CreateFrame("Frame", "DCHousingFilterMenu", frame,
        "UIDropDownMenuTemplate")
    UIDropDownMenu_Initialize(filterMenu, function(_, level)
        Catalog:InitFilterMenu(level)
    end, "MENU")
    frame.filterMenu = filterMenu

    local filterButton = CreateFrame("Button", "DCHousingFilterButton", frame,
        "UIPanelButtonTemplate")
    filterButton:SetWidth(96)
    filterButton:SetHeight(22)
    filterButton:SetPoint("TOPLEFT", 400, -42)
    filterButton:SetScript("OnClick", function(self)
        ToggleDropDownMenu(1, nil, filterMenu, self, 0, 0)
    end)
    frame.filterButton = filterButton
    UpdateFilterButton()

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
        -- the catalog grid scrolls by tile rows, the placed list by text rows
        local step = state.mode == "placed" and ROW_HEIGHT or TILE_STEP
        FauxScrollFrame_OnVerticalScroll(self, value, step,
            function() Catalog:RefreshRows() end)
    end)
    frame.scroll = scroll

    -- Catalog grid tiles. The model and the selection glow sit on child
    -- frames so they draw above the tile's own background.
    frame.tiles = {}
    for i = 1, GRID_COLUMNS * GRID_ROWS do
        local tile = CreateFrame("Button", nil, frame)
        tile:SetWidth(TILE_SIZE)
        tile:SetHeight(TILE_SIZE)
        tile:SetPoint("TOPLEFT", listAnchor, "TOPLEFT",
            ((i - 1) % GRID_COLUMNS) * TILE_STEP,
            -math.floor((i - 1) / GRID_COLUMNS) * TILE_STEP)
        tile:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        tile:SetBackdropColor(0.10, 0.10, 0.13, 0.9)
        tile:SetBackdropBorderColor(0.45, 0.45, 0.5, 1)

        tile.icon = tile:CreateTexture(nil, "ARTWORK")
        tile.icon:SetPoint("TOPLEFT", TILE_INSET, -TILE_INSET)
        tile.icon:SetPoint("BOTTOMRIGHT", -TILE_INSET, TILE_INSET)

        tile.model = CreateFrame("Model", nil, tile)
        tile.model:SetPoint("TOPLEFT", TILE_INSET, -TILE_INSET)
        tile.model:SetPoint("BOTTOMRIGHT", -TILE_INSET, TILE_INSET)
        tile.model:Hide()

        local overlay = CreateFrame("Frame", nil, tile)
        overlay:SetAllPoints(tile)
        overlay:SetFrameLevel(tile.model:GetFrameLevel() + 1)
        tile.selected = overlay:CreateTexture(nil, "OVERLAY")
        tile.selected:SetTexture("Interface\\Buttons\\CheckButtonHilight")
        tile.selected:SetBlendMode("ADD")
        tile.selected:SetAllPoints(overlay)
        tile.selected:Hide()
        tile.hover = overlay:CreateTexture(nil, "OVERLAY")
        tile.hover:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        tile.hover:SetBlendMode("ADD")
        tile.hover:SetAllPoints(overlay)
        tile.hover:Hide()

        tile:EnableMouseWheel(true)
        tile:SetScript("OnMouseWheel", function(_, delta)
            ScrollGrid(delta)
        end)
        tile:SetScript("OnEnter", function(self)
            self.hover:Show()
            Catalog:ShowTileTooltip(self)
        end)
        tile:SetScript("OnLeave", function(self)
            self.hover:Hide()
            GameTooltip:Hide()
        end)
        tile:SetScript("OnClick", function(self)
            if self.entry then
                SetPreview(self.entry)
                Catalog:RefreshRows()
            end
        end)
        tile:Hide()
        frame.tiles[i] = tile
    end

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
            if self.placed then
                SetPlacedSelection(self.placed)
                Catalog:RefreshRows()
            end
        end)
        row:Hide()
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
        local x, y = GetCursorPosition()
        self.lastX, self.lastY = x, y
    end)
    preview:SetScript("OnMouseUp", function(self)
        self.rotating = false
    end)
    preview:SetScript("OnMouseWheel", function(_, delta)
        if IsShiftKeyDown() then
            -- vertical pan
            state.previewVertical = (state.previewVertical or 0)
                + delta * 0.05
        else
            -- zoom: wheel up = larger (the widget auto-frames, so apparent
            -- size is driven by SetModelScale, not camera depth). The low floor
            -- lets big buildings be pulled right back.
            local s = (state.previewScale or 0.5) + delta * 0.05
            if s < 0.02 then s = 0.02 end
            if s > 3.0 then s = 3.0 end
            state.previewScale = s
        end
        Catalog:ApplyPreviewTransform()
    end)
    preview:SetScript("OnUpdate", function(self, elapsed)
        -- a held rotate button spins the model
        if self.spin then
            state.previewFacing = (state.previewFacing or DEFAULT_FACING)
                + self.spin * (elapsed or 0) * 2.5
            Catalog:ApplyPreviewTransform()
        end
        if self.rotating then
            local x, y = GetCursorPosition()
            local dx = x - (self.lastX or x)
            local dy = y - (self.lastY or y)
            self.lastX, self.lastY = x, y
            -- Horizontal drag spins the model (yaw). Vertical drag tumbles it
            -- (pitch) via the WXL SetModelPitch native, giving full rotation;
            -- without the DLL it falls back to raising/lowering the model so
            -- the top and underside can still be peeked at.
            state.previewFacing = (state.previewFacing or DEFAULT_FACING) + dx * 0.02
            if type(SetModelPitch) == "function" then
                state.previewPitch = (state.previewPitch or 0) - dy * 0.02
            else
                local v = (state.previewVertical or 0) + dy * 0.004
                if v < -2 then v = -2 end
                if v > 2 then v = 2 end
                state.previewVertical = v
            end
            Catalog:ApplyPreviewTransform()
        end
    end)
    frame.preview = preview
    frame.previewBg = previewBg

    -- Tag line drawn over the model: a child frame above the Model widget,
    -- since the model would cover regions of previewBg itself.
    local tagHolder = CreateFrame("Frame", nil, previewBg)
    tagHolder:SetAllPoints(previewBg)
    tagHolder:SetFrameLevel(preview:GetFrameLevel() + 2)
    frame.previewTags = tagHolder:CreateFontString(nil, "OVERLAY",
        "GameFontHighlightSmall")
    frame.previewTags:SetPoint("BOTTOMLEFT", 8, 7)
    frame.previewTags:SetPoint("BOTTOMRIGHT", -8, 7)
    frame.previewTags:SetJustifyH("LEFT")

    -- Rotate / zoom / reset controls (retail ModelSceneControls), top right.
    frame.previewControls = {}
    local function Control(key, size, textures, tooltip)
        local b = CreateFrame("Button", nil, tagHolder)
        b:SetWidth(size)
        b:SetHeight(size)
        b:SetNormalTexture(textures[1])
        if textures[2] then
            b:SetPushedTexture(textures[2])
        end
        b:SetHighlightTexture(textures[3], "ADD")
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(tooltip)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        local count = #frame.previewControls
        b:SetPoint("TOPRIGHT", tagHolder, "TOPRIGHT", -6 - count * 26, -6)
        frame.previewControls[#frame.previewControls + 1] = b
        frame.previewControls[key] = b
        return b
    end
    local reset = Control("reset", 22, { "Interface\\Buttons\\UI-RefreshButton",
        nil, "Interface\\Buttons\\ButtonHilight-Round" }, L.RESET_VIEW)
    reset:SetScript("OnClick", function() Catalog:ResetPreviewView() end)
    local zoomIn = Control("zoomIn", 22, { "Interface\\Buttons\\UI-PlusButton-Up",
        "Interface\\Buttons\\UI-PlusButton-Down",
        "Interface\\Buttons\\UI-PlusButton-Hilight" }, L.ZOOM_IN)
    zoomIn:SetScript("OnClick", function() Catalog:ZoomPreview(1.2) end)
    local zoomOut = Control("zoomOut", 22, { "Interface\\Buttons\\UI-MinusButton-Up",
        "Interface\\Buttons\\UI-MinusButton-Down",
        "Interface\\Buttons\\UI-PlusButton-Hilight" }, L.ZOOM_OUT)
    zoomOut:SetScript("OnClick", function() Catalog:ZoomPreview(1 / 1.2) end)
    -- laid out right to left: [rotate left][rotate right][-][+][reset]
    for _, spec in ipairs({
        { "rotateRight", "UI-RotationRight-Button", -1, L.ROTATE_RIGHT },
        { "rotateLeft", "UI-RotationLeft-Button", 1, L.ROTATE_LEFT },
    }) do
        local b = Control(spec[1], 24, { "Interface\\Buttons\\" .. spec[2] .. "-Up",
            "Interface\\Buttons\\" .. spec[2] .. "-Down",
            "Interface\\Buttons\\ButtonHilight-Round" }, spec[4])
        b:SetScript("OnMouseDown", function() preview.spin = spec[3] end)
        b:SetScript("OnMouseUp", function() preview.spin = nil end)
        b:SetScript("OnHide", function() preview.spin = nil end)
    end

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
            -- Keep the catalog docked on the left so you can keep placing the
            -- same item. StartGhost hides the 3D preview only once the ghost
            -- actually starts, and EndGhost restores it.
            DC.EditMode:StartGhostPlacement(state.selectedEntry)
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
                -- No list refresh here: SMSG_MOVE_RESULT triggers it once the
                -- server has actually applied the (possibly queued) op.
                onClick(state.placedSel)
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

    -- "Remove All" button — no selection required; shown only in placed mode.
    -- Anchored to the left side below the decoration list so it never
    -- overlaps the right-side manage buttons.
    local resetAllBtn = CreateFrame("Button", nil, frame,
        "UIPanelButtonTemplate")
    resetAllBtn:SetWidth(190)
    resetAllBtn:SetHeight(22)
    resetAllBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 42)
    resetAllBtn:SetText("Remove All Decorations")
    resetAllBtn:SetScript("OnClick", function()
        StaticPopup_Show("DCHOUSING_RESET_ALL")
    end)
    resetAllBtn:Hide()
    frame.resetAllButton = resetAllBtn

    StaticPopupDialogs["DCHOUSING_RESET_ALL"] = {
        text = L.CONFIRM_RESET_ALL,
        button1 = YES,
        button2 = NO,
        OnAccept = function()
            DC.Protocol:ResetAll()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }

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

-- Hide the in-catalog 3D preview while a placement/move ghost is active in the
-- world: the live ghost (and the real object) IS the preview, so the pane is
-- redundant and only steals screen space. Restored via ShowPreview when the
-- ghost ends (EditMode calls Catalog:OnPlacementEnded).
function Catalog:HidePreview()
    if not frame then
        return
    end
    if frame.previewBg then frame.previewBg:Hide() end
    if frame.previewName then frame.previewName:Hide() end
    if frame.previewInfo then frame.previewInfo:Hide() end
end

function Catalog:ShowPreview()
    if not frame then
        return
    end
    if frame.previewBg then frame.previewBg:Show() end
    if frame.previewName then frame.previewName:Show() end
    if frame.previewInfo then frame.previewInfo:Show() end
end

-- Called by EditMode when a ghost placement/move finishes (commit or cancel).
function Catalog:OnPlacementEnded()
    self:ShowPreview()
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
    if frame.resetAllButton then
        if placed then
            frame.resetAllButton:Show()
        else
            frame.resetAllButton:Hide()
        end
    end

    if placed then
        state.placedSel = nil
        state.placedSelEntry = nil
        frame.previewName:SetText("Placed Decorations")
        frame.previewInfo:SetText(
            "Select an object, then Move Here / Rotate / Remove.")
        Catalog:SetPreviewTags(nil)
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
    -- Reopening while in manage mode: the placed list may have changed since
    -- the frame was hidden, so re-request it instead of showing stale rows.
    if state.mode == "placed" then
        DC.Protocol:RequestList()
    end
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
