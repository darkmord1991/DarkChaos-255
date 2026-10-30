--[[
    DC-Path Core.lua
    ================

    Client side of the Path of Chaos (server module PATH, DC/Progression/Path): the book of
    tasks and milestones, this account's progress, and the claims that pay Shop Points.

    The server decides everything. This file keeps a copy of what it was told and works out
    what to draw; a claim only ever asks.

    The book is static data, cached in saved variables by revision, so a login normally costs
    one short exchange. Progress is account-wide and is asked for fresh every login.
]]

DCPath = DCPath or {}
local Path = DCPath
local Protocol = DCAddonProtocol
local MODULE = Protocol.Module.PATH
local Op = Protocol.Opcode.Path

local FLAG_COMPLETED, FLAG_CLAIMED = 1, 2

-- How long after entering the world to ask: the protocol's handshake goes first.
local LOGIN_REQUEST_DELAY = 2
-- A login credits every milestone at once, one server update per objective. Everything that
-- lands inside this window becomes one toast.
local TOAST_GATHER_SECONDS = 0.5
local TOAST_SECONDS = 5

Path.enabled = true
Path.categories = {}
Path.tasks = {}
Path.taskById = {}
Path.tasksByCategory = {}
Path.state = {}
Path.points = 0
Path.earned = 0
Path.revision = 0
Path.stateLoaded = false

local function Print(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cffFFCC00Path of Chaos:|r " .. text)
end
Path.Print = Print

-- ============================================================================
-- The book
-- ============================================================================

local function ReadCategory(raw)
    return {
        id = raw.i,
        name = raw.n,
        description = raw.d,
        icon = raw.k,
    }
end

local function ReadTask(raw)
    return {
        id = raw.i,
        category = raw.c,
        name = raw.n,
        description = raw.d,
        icon = raw.k,
        objective = raw.y,
        target = raw.g,
        prev = raw.v,
        points = raw.p,
        itemId = raw.ri,
        itemCount = raw.rn,
        collectionType = raw.ct,
        collectionEntry = raw.ce,
    }
end

function Path:UseCatalog(revision, categories, tasks)
    self.revision = revision
    self.categories = categories
    self.tasks = tasks
    self.taskById = {}
    self.tasksByCategory = {}

    for _, category in ipairs(categories) do
        self.tasksByCategory[category.id] = {}
    end

    for _, task in ipairs(tasks) do
        self.taskById[task.id] = task
        local list = self.tasksByCategory[task.category]
        if list then
            list[#list + 1] = task
        end
    end
end

local function SaveCatalog()
    DCPathDB = DCPathDB or {}
    DCPathDB.catalog = {
        revision = Path.revision,
        categories = Path.categories,
        tasks = Path.tasks,
    }
end

local function LoadSavedCatalog()
    local saved = DCPathDB and DCPathDB.catalog
    if type(saved) == "table" and type(saved.tasks) == "table" and type(saved.categories) == "table" then
        Path:UseCatalog(saved.revision or 0, saved.categories, saved.tasks)
    end
end

-- ============================================================================
-- Reading the state
-- ============================================================================

local function FlagsOf(taskId)
    local entry = Path.state[taskId]
    return entry and entry.flags or 0
end

function Path:IsCompleted(taskId)
    return bit.band(FlagsOf(taskId), FLAG_COMPLETED) ~= 0
end

function Path:IsClaimed(taskId)
    return bit.band(FlagsOf(taskId), FLAG_CLAIMED) ~= 0
end

function Path:GetProgress(task)
    local entry = self.state[task.id]
    local progress = entry and entry.progress or 0
    if self:IsCompleted(task.id) then
        progress = task.target
    end
    return math.min(progress, task.target), task.target
end

-- A task opens once the one before it is complete. A prerequisite the book no longer has
-- locks nothing; the server reads it the same way.
function Path:IsLocked(task)
    local prev = task.prev
    return prev ~= nil and prev ~= 0 and self.taskById[prev] ~= nil and not self:IsCompleted(prev)
end

function Path:CanClaim(task)
    return self:IsCompleted(task.id) and not self:IsClaimed(task.id) and not self:IsLocked(task)
end

function Path:GetCategoryProgress(categoryId)
    local claimed, claimable = 0, 0
    local tasks = self.tasksByCategory[categoryId] or {}
    for _, task in ipairs(tasks) do
        if self:IsClaimed(task.id) then
            claimed = claimed + 1
        elseif self:CanClaim(task) then
            claimable = claimable + 1
        end
    end
    return claimed, #tasks, claimable
end

function Path:GetTotals()
    local claimed, claimable = 0, 0
    for _, task in ipairs(self.tasks) do
        if self:IsClaimed(task.id) then
            claimed = claimed + 1
        elseif self:CanClaim(task) then
            claimable = claimable + 1
        end
    end
    return claimed, #self.tasks, claimable
end

-- ============================================================================
-- Requests
-- ============================================================================

function Path:RequestCatalog()
    Protocol:Request(MODULE, Op.CMSG_GET_CATALOG, { rev = self.revision })
end

function Path:RequestState()
    Protocol:Request(MODULE, Op.CMSG_GET_STATE, {})
end

function Path:Claim(taskId)
    Protocol:Request(MODULE, Op.CMSG_CLAIM, { id = taskId })
end

function Path:ClaimAll()
    Protocol:Request(MODULE, Op.CMSG_CLAIM_ALL, {})
end

-- ============================================================================
-- Toasts
-- ============================================================================

local pendingToast = {}

local function ShowPendingToast()
    local count = #pendingToast
    if count == 0 then
        return
    end

    local title, text, icon
    if count == 1 then
        local task = pendingToast[1]
        title = "Path of Chaos: task complete"
        text = task.name
        icon = task.icon
    else
        title = "Path of Chaos"
        text = count .. " tasks complete"
        icon = "INV_Misc_Coin_16"
    end

    pendingToast = {}

    if Path.ShowToast then
        Path:ShowToast(title, text, icon)
    end
end

local toastTimer = CreateFrame("Frame")
toastTimer:Hide()
toastTimer:SetScript("OnUpdate", function(self, elapsed)
    self.remaining = self.remaining - elapsed
    if self.remaining <= 0 then
        self:Hide()
        ShowPendingToast()
    end
end)

local function QueueToast(task)
    pendingToast[#pendingToast + 1] = task
    toastTimer.remaining = TOAST_GATHER_SECONDS
    toastTimer:Show()
end

Path.TOAST_SECONDS = TOAST_SECONDS

-- ============================================================================
-- Server messages
-- ============================================================================

local catalogPages = nil

local function OnCatalog(data)
    -- The first page starts a fresh book, so an interrupted transfer cannot leave one half old.
    if data.page == 1 or not catalogPages or catalogPages.revision ~= data.rev then
        catalogPages = { revision = data.rev, categories = {}, tasks = {} }
    end

    for _, raw in ipairs(data.c or {}) do
        catalogPages.categories[#catalogPages.categories + 1] = ReadCategory(raw)
    end

    for _, raw in ipairs(data.t or {}) do
        catalogPages.tasks[#catalogPages.tasks + 1] = ReadTask(raw)
    end

    if data.page >= data.pages then
        Path:UseCatalog(catalogPages.revision, catalogPages.categories, catalogPages.tasks)
        catalogPages = nil
        SaveCatalog()
        Path:NotifyChanged()
    end
end

local function OnCatalogCurrent()
    Path:NotifyChanged()
end

local function ApplyEntry(row)
    Path.state[row[1]] = { progress = row[2], flags = row[3] }
end

-- The shop draws this balance too, and may be open while a reward is claimed.
local function SyncCollectionBalance()
    local collection = rawget(_G, "DCCollection")
    if not collection or type(collection.currency) ~= "table" then
        return
    end

    collection.currency.points = Path.points
    if type(collection.UpdateShopUI) == "function" then
        collection:UpdateShopUI()
    end
end

local function OnState(data)
    local firstState = not Path.stateLoaded

    Path.enabled = data.enabled ~= false
    Path.points = data.points or 0
    Path.earned = data.earned or 0
    Path.state = {}
    for _, row in ipairs(data.t or {}) do
        ApplyEntry(row)
    end
    Path.stateLoaded = true
    SyncCollectionBalance()

    if firstState and Path.enabled then
        local _, _, claimable = Path:GetTotals()
        if claimable == 1 then
            Print("1 reward is ready to collect. Type |cffffffff/path|r.")
        elseif claimable > 1 then
            Print(("%d rewards are ready to collect. Type |cffffffff/path|r."):format(claimable))
        end
    end

    Path:NotifyChanged()
end

local function OnTaskUpdate(data)
    Path.points = data.points or Path.points
    SyncCollectionBalance()

    for _, row in ipairs(data.u or {}) do
        local wasCompleted = Path:IsCompleted(row[1])
        ApplyEntry(row)

        local task = Path.taskById[row[1]]
        if task and not wasCompleted and Path:IsCompleted(row[1]) then
            QueueToast(task)
        end
    end

    Path:NotifyChanged()
end

local function OnClaimResult(data)
    Path.points = data.points or Path.points
    SyncCollectionBalance()

    for _, taskId in ipairs(data.ids or {}) do
        local entry = Path.state[taskId] or { progress = 0, flags = FLAG_COMPLETED }
        entry.flags = bit.bor(entry.flags, FLAG_COMPLETED, FLAG_CLAIMED)
        Path.state[taskId] = entry
    end

    if data.ok and (data.paid or 0) > 0 then
        Print(("You earned |cffffffff%d|r Shop Points."):format(data.paid))
    elseif data.ok then
        Print("Reward collected.")
    elseif data.msg and data.msg ~= "" then
        Print(data.msg)
    end

    Path:NotifyChanged()
end

Protocol:RegisterHandler(MODULE, Op.SMSG_CATALOG, OnCatalog)
Protocol:RegisterHandler(MODULE, Op.SMSG_CATALOG_CURRENT, OnCatalogCurrent)
Protocol:RegisterHandler(MODULE, Op.SMSG_STATE, OnState)
Protocol:RegisterHandler(MODULE, Op.SMSG_TASK_UPDATE, OnTaskUpdate)
Protocol:RegisterHandler(MODULE, Op.SMSG_CLAIM_RESULT, OnClaimResult)

-- UI.lua replaces this.
function Path:NotifyChanged()
end

-- ============================================================================
-- Login
-- ============================================================================

local loginTimer = CreateFrame("Frame")
loginTimer:RegisterEvent("ADDON_LOADED")
loginTimer:RegisterEvent("PLAYER_ENTERING_WORLD")
loginTimer:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" then
        if addonName == "DC-Path" then
            LoadSavedCatalog()
            self:UnregisterEvent("ADDON_LOADED")
        end
        return
    end

    -- Once: a loading screen changes nothing the server would not push on its own.
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    self.remaining = LOGIN_REQUEST_DELAY
    self:SetScript("OnUpdate", function(timer, elapsed)
        timer.remaining = timer.remaining - elapsed
        if timer.remaining <= 0 then
            timer:SetScript("OnUpdate", nil)
            Path:RequestCatalog()
            Path:RequestState()
        end
    end)
end)

-- ============================================================================
-- Slash command
-- ============================================================================

SLASH_DCPATH1 = "/path"
SLASH_DCPATH2 = "/dcpath"
SlashCmdList["DCPATH"] = function()
    Path:Toggle()
end
