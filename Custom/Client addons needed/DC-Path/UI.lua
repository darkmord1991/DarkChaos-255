--[[
    DC-Path UI.lua
    ==============

    The Path of Chaos window: categories on the left, the selected category's tasks on the
    right, the Shop Points balance and overall progress above them. Built the first time it is
    opened. Rows are pooled, so moving between categories allocates nothing once each has
    been seen.

    Dressed as the other DC windows are: DC-Leaderboards' leather, tint and dialog border, gold
    headings, fel green for what is selected or done. The client ignores CreateTexture's sublevel
    and the texture created last wins within a layer, so draw order here is layers and creation
    order alone.
]]

local Path = DCPath

local WINDOW_WIDTH, WINDOW_HEIGHT = 860, 580
-- Clear of the dialog border, which is 32 wide and draws about 12 of that.
local MARGIN = 18
local LEFT_WIDTH = 224
local PANEL_LEFT = MARGIN + LEFT_WIDTH + 12
local SCROLLBAR_WIDTH = 26
local LIST_WIDTH = WINDOW_WIDTH - PANEL_LEFT - MARGIN - SCROLLBAR_WIDTH
local HEADER_BOTTOM = 68
local CATEGORY_TOP = 90
local CATEGORY_WIDTH = LEFT_WIDTH - 8
local CATEGORY_HEIGHT = 50
local CATEGORY_GAP = 2
local CATEGORY_TEXT_LEFT = 46
local ROW_HEIGHT = 70
local ROW_GAP = 4
local ROW_TEXT_LEFT = 66
-- Task text stops short of the reward and the Claim button. The book's longest description
-- measures 384 in the client's font, and one line is all a row has.
local ROW_TEXT_WIDTH = LIST_WIDTH - ROW_TEXT_LEFT - 94
-- A FontString with both a width and a height cuts long text instead of wrapping it. This is the
-- height of one line of GameFontNormal.
local NAME_HEIGHT = 16
local SMALL_LINE_HEIGHT = 14

local ICON_PATH = "Interface\\Icons\\"
local FALLBACK_ICON = "INV_Misc_QuestionMark"
local PORTRAIT_ICON = ICON_PATH .. "Spell_Fire_FelFlameRing"
local POINTS_ICON = ICON_PATH .. "INV_Misc_Coin_16"
local BAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local READY_TEXTURE = "Interface\\RaidFrame\\ReadyCheck-Ready"
local BG_FELLEATHER = "Interface\\DC\\Shared\\FelLeather_512.tga"
local BG_TINT_ALPHA = 0.60

local GOLD = { 1, 0.82, 0 }
local WHITE = { 1, 1, 1 }
local GREY = { 0.6, 0.6, 0.6 }
local FEL_GREEN = { 0.2, 0.7, 0.2 }

local frame
local selectedCategory

local function IconPath(icon)
    return ICON_PATH .. ((icon and icon ~= "") and icon or FALLBACK_ICON)
end

local function SetColor(region, color)
    region:SetTextColor(color[1], color[2], color[3])
end

-- The leather, tint and border every DC window shares. The border is its own frame so that the
-- leather, which fills the whole window, cannot draw over it.
local function ApplyLeaderboardsStyle(window)
    window.bg = window:CreateTexture(nil, "BACKGROUND")
    window.bg:SetAllPoints()
    window.bg:SetTexture(BG_FELLEATHER)

    window.bgTint = window:CreateTexture(nil, "BACKGROUND")
    window.bgTint:SetAllPoints()
    window.bgTint:SetTexture(0, 0, 0, BG_TINT_ALPHA)

    window.border = CreateFrame("Frame", nil, window)
    window.border:SetAllPoints()
    window.border:SetBackdrop({
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
end

-- An icon without the bevel stock icons carry, on a black edge. Returns the edge to anchor by.
local function CreateIcon(parent, size)
    local edge = parent:CreateTexture(nil, "BORDER")
    edge:SetSize(size + 2, size + 2)
    edge:SetTexture(0, 0, 0, 1)

    local icon = parent:CreateTexture(nil, "ARTWORK")
    icon:SetSize(size, size)
    icon:SetPoint("CENTER", edge, "CENTER", 0, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    return icon, edge
end

local function CreateProgressBar(parent)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetStatusBarTexture(BAR_TEXTURE)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)

    bar.background = bar:CreateTexture(nil, "BACKGROUND")
    bar.background:SetAllPoints()
    bar.background:SetTexture(0, 0, 0, 0.6)

    bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.text:SetPoint("CENTER", bar, "CENTER", 0, 0)

    return bar
end

-- 1234567 -> 1,234,567
local function FormatNumber(value)
    local text = tostring(math.floor(value or 0))
    local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (formatted:gsub("^,", ""))
end

-- ============================================================================
-- Task rows
-- ============================================================================

local function RewardText(task)
    local parts = {}
    if (task.points or 0) > 0 then
        parts[#parts + 1] = FormatNumber(task.points) .. " pts"
    end
    if task.itemId then
        parts[#parts + 1] = "item"
    end
    if task.collectionType then
        parts[#parts + 1] = "collectible"
    end
    return table.concat(parts, " + ")
end

local function ShowRowTooltip(row)
    local task = row.task
    if not task then
        return
    end

    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(task.name, 1, 0.82, 0)
    GameTooltip:AddLine(task.description, 1, 1, 1, true)

    if Path:IsLocked(task) then
        local prev = Path.taskById[task.prev]
        GameTooltip:AddLine("Requires: " .. prev.name, 1, 0.3, 0.3, true)
    end

    GameTooltip:Show()
end

local function CreateRow(index)
    local row = CreateFrame("Frame", nil, frame.listChild)
    row:SetSize(LIST_WIDTH, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", frame.listChild, "TOPLEFT", 0, -((index - 1) * (ROW_HEIGHT + ROW_GAP)))
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        self.hover:Show()
        ShowRowTooltip(self)
    end)
    row:SetScript("OnLeave", function(self)
        self.hover:Hide()
        GameTooltip:Hide()
    end)

    row.background = row:CreateTexture(nil, "BACKGROUND")
    row.background:SetAllPoints()

    -- A warm wash on a row with something to collect.
    row.glow = row:CreateTexture(nil, "BORDER")
    row.glow:SetAllPoints()
    row.glow:SetTexture(GOLD[1], GOLD[2], GOLD[3], 0.10)
    row.glow:SetBlendMode("ADD")

    row.hover = row:CreateTexture(nil, "BORDER")
    row.hover:SetAllPoints()
    row.hover:SetTexture(1, 1, 1, 0.05)
    row.hover:Hide()

    -- The state stripe DC-Collection's toasts wear down their left edge.
    row.stripe = row:CreateTexture(nil, "ARTWORK")
    row.stripe:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.stripe:SetPoint("BOTTOMRIGHT", row, "BOTTOMLEFT", 3, 0)

    local iconEdge
    row.icon, iconEdge = CreateIcon(row, 46)
    iconEdge:SetPoint("LEFT", row, "LEFT", 10, 0)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("TOPLEFT", row, "TOPLEFT", ROW_TEXT_LEFT, -8)
    row.name:SetSize(ROW_TEXT_WIDTH, NAME_HEIGHT)
    row.name:SetJustifyH("LEFT")

    row.description = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.description:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -1)
    row.description:SetSize(ROW_TEXT_WIDTH, SMALL_LINE_HEIGHT)
    row.description:SetJustifyH("LEFT")

    row.bar = CreateProgressBar(row)
    row.bar:SetSize(ROW_TEXT_WIDTH, 12)
    row.bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", ROW_TEXT_LEFT, 10)
    row.barText = row.bar.text

    row.reward = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.reward:SetPoint("TOPRIGHT", row, "TOPRIGHT", -12, -10)
    row.reward:SetJustifyH("RIGHT")

    row.claim = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.claim:SetSize(78, 22)
    row.claim:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -10, 8)
    row.claim:SetText("Claim")
    row.claim:SetScript("OnClick", function(button)
        if row.task then
            button:Disable()
            Path:Claim(row.task.id)
        end
    end)

    row.status = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.status:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -12, 10)
    row.status:SetJustifyH("RIGHT")

    row.check = row:CreateTexture(nil, "OVERLAY")
    row.check:SetSize(16, 16)
    row.check:SetPoint("RIGHT", row.status, "LEFT", -3, 0)
    row.check:SetTexture(READY_TEXTURE)

    return row
end

local function UpdateRow(row, task)
    row.task = task

    local claimed = Path:IsClaimed(task.id)
    local completed = Path:IsCompleted(task.id)
    local locked = Path:IsLocked(task)
    local canClaim = Path:CanClaim(task)
    local progress, target = Path:GetProgress(task)

    row.icon:SetTexture(IconPath(task.icon))
    row.icon:SetDesaturated(locked and 1 or nil)
    row.name:SetText(task.name)
    row.description:SetText(task.description)
    row.reward:SetText(RewardText(task))

    SetColor(row.name, locked and GREY or GOLD)
    SetColor(row.description, locked and GREY or WHITE)

    local barColor = completed and FEL_GREEN or GOLD
    row.bar:SetMinMaxValues(0, target)
    row.bar:SetValue(progress)
    row.bar:SetStatusBarColor(barColor[1], barColor[2], barColor[3])
    row.barText:SetText(("%s / %s"):format(FormatNumber(progress), FormatNumber(target)))

    row.claim:Hide()
    row.check:Hide()
    row.glow:Hide()
    row.stripe:Hide()
    row.status:SetText("")

    if canClaim then
        row.background:SetTexture(0, 0, 0, 0.45)
        row.glow:Show()
        row.stripe:SetTexture(GOLD[1], GOLD[2], GOLD[3], 1)
        row.stripe:Show()
        row.claim:Show()
        row.claim:Enable()
    elseif claimed then
        row.background:SetTexture(0.04, 0.16, 0.04, 0.55)
        row.stripe:SetTexture(FEL_GREEN[1], FEL_GREEN[2], FEL_GREEN[3], 1)
        row.stripe:Show()
        row.check:Show()
        row.status:SetText("Collected")
    else
        row.background:SetTexture(0, 0, 0, 0.45)
        if locked then
            row.status:SetText("Locked")
        end
    end

    row:Show()
end

local function DrawTasks()
    local tasks = Path.tasksByCategory[selectedCategory] or {}

    for index, task in ipairs(tasks) do
        local row = frame.rows[index]
        if not row then
            row = CreateRow(index)
            frame.rows[index] = row
        end
        UpdateRow(row, task)
    end

    for index = #tasks + 1, #frame.rows do
        frame.rows[index].task = nil
        frame.rows[index]:Hide()
    end

    frame.listChild:SetHeight(math.max(1, #tasks * (ROW_HEIGHT + ROW_GAP)))
end

-- ============================================================================
-- Category buttons
-- ============================================================================

local function SelectCategory(categoryId)
    selectedCategory = categoryId
    frame.list:SetVerticalScroll(0)
    Path:NotifyChanged()
end

local function CreateCategoryButton(index)
    local button = CreateFrame("Button", nil, frame)
    button:SetSize(CATEGORY_WIDTH, CATEGORY_HEIGHT)
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", MARGIN + 4,
        -CATEGORY_TOP - ((index - 1) * (CATEGORY_HEIGHT + CATEGORY_GAP)))

    button.background = button:CreateTexture(nil, "BACKGROUND")
    button.background:SetAllPoints()

    button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
    button.highlight:SetAllPoints()
    button.highlight:SetTexture(1, 1, 1, 0.08)

    local iconEdge
    button.icon, iconEdge = CreateIcon(button, 32)
    iconEdge:SetPoint("LEFT", button, "LEFT", 5, 0)

    button.name = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.name:SetPoint("TOPLEFT", button, "TOPLEFT", CATEGORY_TEXT_LEFT, -8)
    button.name:SetSize(CATEGORY_WIDTH - CATEGORY_TEXT_LEFT - 8, NAME_HEIGHT)
    button.name:SetJustifyH("LEFT")

    button.count = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.count:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", CATEGORY_TEXT_LEFT, 9)

    button.pending = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.pending:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -8, 9)
    button.pending:SetJustifyH("RIGHT")

    button:SetScript("OnClick", function(self)
        SelectCategory(self.categoryId)
    end)

    return button
end

local function DrawCategories()
    for index, category in ipairs(Path.categories) do
        local button = frame.categoryButtons[index]
        if not button then
            button = CreateCategoryButton(index)
            frame.categoryButtons[index] = button
        end

        local claimed, total, claimable = Path:GetCategoryProgress(category.id)
        button.categoryId = category.id
        button.icon:SetTexture(IconPath(category.icon))
        button.name:SetText(category.name)
        button.count:SetText(("%d / %d"):format(claimed, total))
        button.pending:SetText(claimable > 0 and (claimable .. " to claim") or "")

        if category.id == selectedCategory then
            button.background:SetTexture(0.3, 0.5, 0.3, 0.8)
        else
            button.background:SetTexture(0.2, 0.2, 0.2, 0.8)
        end

        button:Show()
    end

    for index = #Path.categories + 1, #frame.categoryButtons do
        frame.categoryButtons[index]:Hide()
    end
end

-- ============================================================================
-- Window
-- ============================================================================

local function OpenShop()
    local collection = rawget(_G, "DCCollection")
    if collection and type(collection.ShowMainFrame) == "function" then
        collection:ShowMainFrame()
        if type(collection.SelectTab) == "function" then
            collection:SelectTab("shop")
        end
    else
        Path.Print("The Collection addon is not loaded.")
    end
end

local function CreateWindow()
    frame = CreateFrame("Frame", "DCPathFrame", UIParent)
    frame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    frame:SetFrameStrata("HIGH")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    -- Closes with Escape, as the stock panels do.
    tinsert(UISpecialFrames, "DCPathFrame")

    frame.rows = {}
    frame.categoryButtons = {}

    ApplyLeaderboardsStyle(frame)

    local titleBar = frame:CreateTexture(nil, "BORDER")
    titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -12)
    titleBar:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -12, -38)
    titleBar:SetTexture(0.15, 0.15, 0.15, 0.5)

    local sidebar = frame:CreateTexture(nil, "BORDER")
    sidebar:SetPoint("TOPLEFT", frame, "TOPLEFT", MARGIN, -HEADER_BOTTOM)
    sidebar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", MARGIN + LEFT_WIDTH, 14)
    sidebar:SetTexture(0, 0, 0, 0.3)

    -- Portrait, as DC-Collection wears it: an icon in the tracking ring, drawn over the icon so
    -- that the ring hides its corners.
    local portrait = frame:CreateTexture(nil, "ARTWORK")
    portrait:SetSize(30, 30)
    portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", 21, -20)
    portrait:SetTexture(PORTRAIT_ICON)
    portrait:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local portraitRing = frame:CreateTexture(nil, "OVERLAY")
    portraitRing:SetSize(52, 52)
    portraitRing:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10)
    portraitRing:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    portraitRing:SetTexCoord(0, 0.50, 0, 0.50)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -17)
    title:SetText("Path of Chaos")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

    -- Overall progress, beside the portrait.
    frame.total = CreateProgressBar(frame)
    frame.total:SetSize(MARGIN + LEFT_WIDTH - 70, 16)
    frame.total:SetPoint("TOPLEFT", frame, "TOPLEFT", 70, -45)
    frame.total:SetStatusBarColor(GOLD[1], GOLD[2], GOLD[3])
    frame.totalText = frame.total.text

    -- Shop Points
    local pointsIcon, pointsEdge = CreateIcon(frame, 20)
    pointsEdge:SetPoint("TOPLEFT", frame, "TOPLEFT", PANEL_LEFT, -44)
    pointsIcon:SetTexture(POINTS_ICON)

    frame.points = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.points:SetPoint("LEFT", pointsEdge, "RIGHT", 6, 0)

    frame.shopButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.shopButton:SetSize(96, 22)
    frame.shopButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -MARGIN, -43)
    frame.shopButton:SetText("Open Shop")
    frame.shopButton:SetScript("OnClick", OpenShop)

    frame.claimAll = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.claimAll:SetSize(96, 22)
    frame.claimAll:SetPoint("RIGHT", frame.shopButton, "LEFT", -6, 0)
    frame.claimAll:SetText("Claim All")
    frame.claimAll:SetScript("OnClick", function(button)
        button:Disable()
        Path:ClaimAll()
    end)

    local categoriesTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    categoriesTitle:SetPoint("TOP", frame, "TOPLEFT", MARGIN + LEFT_WIDTH / 2, -73)
    categoriesTitle:SetText("Categories")

    -- Selected category
    frame.categoryName = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.categoryName:SetPoint("TOPLEFT", frame, "TOPLEFT", PANEL_LEFT, -72)

    frame.categoryDescription = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.categoryDescription:SetPoint("TOPLEFT", frame.categoryName, "BOTTOMLEFT", 0, -3)

    local rule = frame:CreateTexture(nil, "ARTWORK")
    rule:SetPoint("TOPLEFT", frame, "TOPLEFT", PANEL_LEFT, -107)
    rule:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -MARGIN, -108)
    rule:SetTexture(GOLD[1], GOLD[2], GOLD[3], 0.35)

    frame.list = CreateFrame("ScrollFrame", "DCPathTaskList", frame, "UIPanelScrollFrameTemplate")
    frame.list:SetPoint("TOPLEFT", frame, "TOPLEFT", PANEL_LEFT, -112)
    frame.list:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(MARGIN + SCROLLBAR_WIDTH), 14)

    frame.listChild = CreateFrame("Frame", nil, frame.list)
    frame.listChild:SetSize(LIST_WIDTH, 1)
    frame.list:SetScrollChild(frame.listChild)

    frame.empty = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.empty:SetPoint("CENTER", frame.list, "CENTER", 0, 0)
    frame.empty:SetWidth(LIST_WIDTH - 40)

    frame:SetScript("OnShow", function()
        Path:RequestState()
        if #Path.tasks == 0 then
            Path:RequestCatalog()
        end
        Path:NotifyChanged()
    end)
end

local function DrawEmpty()
    local message
    if not Path.enabled then
        message = "The Path of Chaos is not available on this server right now."
    elseif #Path.tasks == 0 then
        message = "Loading the Path of Chaos..."
    end

    frame.empty:SetText(message or "")
    if message then
        frame.empty:Show()
    else
        frame.empty:Hide()
    end
    return message ~= nil
end

-- Opens on the first category with something to collect, or the first of all.
local function DefaultCategory()
    for _, category in ipairs(Path.categories) do
        local _, _, claimable = Path:GetCategoryProgress(category.id)
        if claimable > 0 then
            return category.id
        end
    end
    return Path.categories[1] and Path.categories[1].id
end

local function SelectedCategoryExists()
    for _, category in ipairs(Path.categories) do
        if category.id == selectedCategory then
            return category
        end
    end
    return nil
end

function Path:NotifyChanged()
    if not frame or not frame:IsShown() then
        return
    end

    DrawEmpty()

    if not SelectedCategoryExists() then
        selectedCategory = DefaultCategory()
    end

    local claimed, total, claimable = self:GetTotals()
    frame.total:SetMinMaxValues(0, math.max(total, 1))
    frame.total:SetValue(claimed)
    frame.totalText:SetText(("%d / %d"):format(claimed, total))
    frame.points:SetText(FormatNumber(self.points) .. " Shop Points")

    if claimable > 0 then
        frame.claimAll:Enable()
    else
        frame.claimAll:Disable()
    end

    local category = SelectedCategoryExists()
    frame.categoryName:SetText(category and category.name or "")
    frame.categoryDescription:SetText(category and category.description or "")

    DrawCategories()
    DrawTasks()
end

function Path:Toggle()
    if not frame then
        CreateWindow()
    end

    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end

-- ============================================================================
-- Toast
-- ============================================================================

local toast

local function CreateToast()
    toast = CreateFrame("Button", "DCPathToast", UIParent)
    toast:SetSize(300, 64)
    toast:SetPoint("TOP", UIParent, "TOP", 0, -120)
    toast:SetFrameStrata("DIALOG")
    -- The small DC panel, as DC-QOS draws its quest popups: leather under a thin gold edge.
    toast:SetBackdrop({
        bgFile = BG_FELLEATHER,
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    toast:SetBackdropColor(0.4, 0.4, 0.4, 0.96)
    toast:SetBackdropBorderColor(0.92, 0.74, 0.24, 0.9)
    toast:Hide()

    local iconEdge
    toast.icon, iconEdge = CreateIcon(toast, 40)
    iconEdge:SetPoint("LEFT", toast, "LEFT", 11, 0)

    toast.title = toast:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    toast.title:SetPoint("TOPLEFT", iconEdge, "TOPRIGHT", 8, -3)
    toast.title:SetSize(230, SMALL_LINE_HEIGHT)
    toast.title:SetJustifyH("LEFT")

    toast.text = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    toast.text:SetPoint("BOTTOMLEFT", iconEdge, "BOTTOMRIGHT", 8, 4)
    toast.text:SetSize(230, NAME_HEIGHT)
    toast.text:SetJustifyH("LEFT")

    toast:SetScript("OnClick", function(self)
        self:Hide()
        if not frame or not frame:IsShown() then
            Path:Toggle()
        end
    end)

    toast:SetScript("OnUpdate", function(self, elapsed)
        self.remaining = self.remaining - elapsed
        if self.remaining <= 0 then
            self:Hide()
        end
    end)
end

function Path:ShowToast(title, text, icon)
    if not toast then
        CreateToast()
    end

    toast.icon:SetTexture(IconPath(icon))
    toast.title:SetText(title)
    toast.text:SetText(text)
    toast.remaining = self.TOAST_SECONDS
    toast:Show()

    PlaySound("igQuestListComplete")
end
