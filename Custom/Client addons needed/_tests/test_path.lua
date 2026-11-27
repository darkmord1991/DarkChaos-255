--[[
    The Path of Chaos (DC-Path) on the strict 3.3.5a client (talents_sim.lua + talents_client.lua),
    against a fake PATH server module, plus the Shop Points side of DC-Collection's shop.

    The wire contract is read from the server's own header, so an opcode that drifts between the
    two fails here rather than as a silent dead button.

    Run from this directory:  lua test_path.lua        (-v prints every check)
]]

dofile("talents_sim.lua")
dofile("talents_client.lua")
local T = dofile("talents_testlib.lua")
local ok, section, noNewErrors = T.ok, T.section, T.noNewErrors

-- ----------------------------------------------------------------------------
-- The real opcode tables, behind a fake transport
-- ----------------------------------------------------------------------------

local sent, handlers = {}, {}
DCAddonProtocol = {
    Request = function(_, module, opcode, data)
        sent[#sent + 1] = { module = module, opcode = opcode, data = data }
    end,
    RegisterHandler = function(_, module, opcode, handler)
        handlers[module .. "_" .. opcode] = handler
    end,
}

SIM.LoadFile(SIM.ADDONS_DIR .. "DC-AddonProtocol/DCOpcodes.lua", "DC-AddonProtocol", {})
local Op = DCAddonProtocol.Opcode.Path

local function Deliver(opcode, data)
    handlers["PATH_" .. opcode](data)
end

local function SentSince(mark, opcode)
    local list = {}
    for index = mark + 1, #sent do
        if sent[index].opcode == opcode then
            list[#list + 1] = sent[index]
        end
    end
    return list
end

-- ----------------------------------------------------------------------------
-- The wire contract against the server header
-- ----------------------------------------------------------------------------

section("contract")

local header = assert(io.open("../../../src/server/scripts/DC/AddonExtension/dc_addon_namespace.h", "r"))
local source = header:read("*a")
header:close()

ok(source:find('PATH%s*=%s*"PATH"') ~= nil, "the server names the module PATH")
ok(DCAddonProtocol.Module.PATH == "PATH", "and so does the client")

-- Up to the namespace's own closing brace: the opcode comments contain braces of their own.
local block = source:match("namespace Path%s*{(.-)\n%s*}\n")
ok(block ~= nil, "the server header has a Path opcode block")
local checked = 0
for name, value in (block or ""):gmatch("constexpr uint8 ([%u_]+)%s*=%s*(0x%x+)") do
    ok(Op[name] == tonumber(value), ("%s is %s on both sides"):format(name, value))
    checked = checked + 1
end
local clientCount = 0
for _ in pairs(Op) do
    clientCount = clientCount + 1
end
ok(checked == 9 and clientCount == checked, "both sides list the same nine opcodes")

-- Progress travels as nested arrays, a shape no other module sends, so it goes through the
-- protocol's real decoder here. The fake transport below hands over decoded tables.
do
    local file = assert(io.open("../DC-AddonProtocol/DCAddonProtocol.lua", "r"))
    local protocolSource = file:read("*a")
    file:close()

    local first = protocolSource:find("local _jstr, _jpos, _jlen", 1, true)
    local last = protocolSource:find("local function JsonDeepEqual", 1, true)
    ok(first ~= nil and last ~= nil, "the protocol's JSON decoder can be lifted out")

    local decoder = assert(load("local DC = ...\n" .. protocolSource:sub(first, last - 1) .. "\nreturn DC", "decoder"))
    local decode = decoder({ LogNetEvent = function() end })

    local data = decode:_DecodeJSONLua('{"points":250,"u":[[101,1,3],[202,12,0]]}')
    ok(data and data.points == 250, "an update decodes")
    ok(data and #data.u == 2 and data.u[1][1] == 101 and data.u[2][2] == 12 and data.u[1][3] == 3,
        "and its nested progress rows arrive as { id, progress, flags }")

    local empty = decode:_DecodeJSONLua('{"points":250,"u":[]}')
    ok(empty and type(empty.u) == "table" and #empty.u == 0, "a balance-only update has an empty list")
end

-- ----------------------------------------------------------------------------
-- Load
-- ----------------------------------------------------------------------------

section("load")

ITEM_QUALITY_COLORS = ITEM_QUALITY_COLORS or {}
DCPathDB = nil

local ns = SIM.LoadAddon("DC-Path")
noNewErrors("the addon loads in TOC order")

local Path = DCPath
ok(type(Path) == "table", "DCPath exists")
ok(type(SlashCmdList["DCPATH"]) == "function" and SLASH_DCPATH1 == "/path", "/path is registered")
ok(rawget(_G, "DCPathFrame") == nil, "the window is not built at load")

for _, name in ipairs({ "SMSG_CATALOG", "SMSG_CATALOG_CURRENT", "SMSG_STATE", "SMSG_TASK_UPDATE", "SMSG_CLAIM_RESULT" }) do
    ok(handlers["PATH_" .. Op[name]] ~= nil, name .. " has a handler")
end

SIM.FireEvent("ADDON_LOADED", "DC-Path")
SIM.FireEvent("PLAYER_ENTERING_WORLD")
ok(#sent == 0, "nothing is sent before the handshake had time to finish")
SIM.Run(3)
ok(#SentSince(0, Op.CMSG_GET_CATALOG) == 1 and sent[1].data.rev == 0, "the first login asks for the book at revision 0")
ok(#SentSince(0, Op.CMSG_GET_STATE) == 1, "and for the account's state")

SIM.FireEvent("PLAYER_ENTERING_WORLD")
SIM.Run(3)
ok(#SentSince(2, Op.CMSG_GET_CATALOG) == 0, "a later loading screen asks for nothing")

-- ----------------------------------------------------------------------------
-- The book, in pages
-- ----------------------------------------------------------------------------

section("catalog")

local REV = 123456

local function RawTask(id, category, name, objective, target, prev, points)
    return { i = id, c = category, n = name, d = name .. " description", k = "INV_Misc_Coin_16", y = objective,
        g = target, v = prev, p = points }
end

local page1 = {
    rev = REV, page = 1, pages = 2,
    c = {
        { i = 1, n = "First Steps", d = "Learn your way around.", k = "INV_Misc_Map_01" },
        { i = 2, n = "Levels", d = "The climb.", k = "Achievement_Level_80" },
    },
    t = {
        RawTask(101, 1, "Welcome", 10, 1, 0, 25),
        RawTask(102, 1, "Second Welcome", 10, 1, 101, 25),
        RawTask(201, 2, "Level 10", 1, 10, 0, 50),
    },
}
local page2 = {
    rev = REV, page = 2, pages = 2,
    t = {
        RawTask(202, 2, "Level 20", 1, 20, 201, 75),
        RawTask(203, 2, "Level 40", 1, 40, 202, 1250),
    },
}

Deliver(Op.SMSG_CATALOG, page1)
ok(#Path.tasks == 0, "a book in transfer is not used yet")
Deliver(Op.SMSG_CATALOG, page2)
ok(#Path.tasks == 5 and #Path.categories == 2, "both pages make the book")
ok(Path.revision == REV, "the revision is kept")
ok(DCPathDB and DCPathDB.catalog and DCPathDB.catalog.revision == REV, "and saved for the next login")
ok(Path.taskById[202].prev == 201 and Path.taskById[203].points == 1250, "the short wire keys are read")

-- A restarted transfer must not leave the old pages in the book.
Deliver(Op.SMSG_CATALOG, page1)
Deliver(Op.SMSG_CATALOG, page1)
Deliver(Op.SMSG_CATALOG, page2)
ok(#Path.tasks == 5, "a transfer restarted at page 1 starts clean")

-- ----------------------------------------------------------------------------
-- State rules
-- ----------------------------------------------------------------------------

section("state")

local chatLines = {}
local realAddMessage = DEFAULT_CHAT_FRAME.AddMessage
DEFAULT_CHAT_FRAME.AddMessage = function(self, text, ...)
    chatLines[#chatLines + 1] = text
    return realAddMessage(self, text, ...)
end

Deliver(Op.SMSG_STATE, {
    enabled = true,
    points = 300,
    earned = 500,
    t = {
        { 101, 1, 3 },     -- complete and claimed
        { 102, 1, 1 },     -- complete, its prerequisite too
        { 201, 10, 1 },    -- complete
        { 202, 12, 0 },    -- in progress
        { 203, 40, 1 },    -- complete, but its prerequisite is not
    },
})

ok(Path.points == 300 and Path.earned == 500, "the balance is read")
ok(Path:IsClaimed(101) and not Path:CanClaim(Path.taskById[101]), "a claimed task cannot be claimed again")
ok(Path:CanClaim(Path.taskById[102]), "a completed task whose prerequisite is done can be claimed")
ok(not Path:IsLocked(Path.taskById[202]) and not Path:CanClaim(Path.taskById[202]), "an open task is not claimable yet")
ok(Path:IsLocked(Path.taskById[203]) and not Path:CanClaim(Path.taskById[203]),
    "a completed task stays locked behind an unfinished prerequisite, as the server refuses it")
local p, g = Path:GetProgress(Path.taskById[202])
ok(p == 12 and g == 20, "progress reads against the target")

local claimed, total, claimable = Path:GetTotals()
ok(claimed == 1 and total == 5 and claimable == 2, "the totals count one claimed and two claimable")
local cClaimed, cTotal, cClaimable = Path:GetCategoryProgress(2)
ok(cClaimed == 0 and cTotal == 3 and cClaimable == 1, "and per category")
ok(chatLines[#chatLines]:find("2 rewards are ready", 1, true) ~= nil, "the first state says what is waiting")

local before = #chatLines
Deliver(Op.SMSG_STATE, { enabled = true, points = 300, earned = 500, t = {
    { 101, 1, 3 }, { 102, 1, 1 }, { 201, 10, 1 }, { 202, 12, 0 }, { 203, 40, 1 },
} })
ok(#chatLines == before, "a later state does not repeat it")

-- ----------------------------------------------------------------------------
-- The window
-- ----------------------------------------------------------------------------

section("window")

local mark = #sent
SlashCmdList["DCPATH"]("")
noNewErrors("the window opens")

local frame = rawget(_G, "DCPathFrame")
ok(frame and frame:IsShown(), "/path opens the window")
ok(tContains(UISpecialFrames, "DCPathFrame"), "Escape closes it")
ok(#SentSince(mark, Op.CMSG_GET_STATE) == 1, "opening asks for fresh state, which recounts the collection")
ok(#SentSince(mark, Op.CMSG_GET_CATALOG) == 0, "and does not ask for a book it already has")

local function Row(taskId)
    for _, row in ipairs(frame.rows) do
        if row.task and row.task.id == taskId and row:IsShown() then
            return row
        end
    end
end

ok(frame.categoryName:GetText() == "First Steps", "it opens on the first category with something to collect")
ok(frame.points:GetText() == "300 Shop Points", "the balance is shown")
ok(frame.totalText:GetText() == "1 / 5", "overall progress is shown")
ok(frame.claimAll:IsEnabled() == 1, "Claim All is on while something can be claimed")

local row101, row102 = Row(101), Row(102)
ok(row101 and row102, "the category's tasks are drawn")
ok(row101.check:IsShown() and not row101.claim:IsShown() and row101.status:GetText() == "Collected",
    "a claimed task shows as collected")
ok(row102.claim:IsShown() and row102.claim:IsEnabled() == 1, "a claimable task has a Claim button")
ok(row102.reward:GetText() == "25 pts", "and names what it pays")

local rowCount = #frame.rows
frame.categoryButtons[2]:Click()
noNewErrors("switching category")
ok(frame.categoryName:GetText() == "Levels", "a category button switches the list")
ok(Row(101) == nil, "the other category's rows are gone")
ok(Row(203).status:GetText() == "Locked" and not Row(203).claim:IsShown(), "a locked task has no Claim button")
ok(Row(202).barText:GetText() == "12 / 20", "progress is drawn")
ok(frame.categoryButtons[2].pending:GetText() == "1 to claim", "the category button counts what can be claimed")

frame.categoryButtons[1]:Click()
ok(Row(203) == nil, "a shorter category leaves no row of the longer one behind")
frame.categoryButtons[2]:Click()
ok(#frame.rows == math.max(rowCount, 3), "going back and forth allocates no new rows")

-- A number longer than three digits.
ok(Row(203).reward:GetText() == "1,250 pts", "large rewards are grouped")

-- ----------------------------------------------------------------------------
-- The look, and what fits where
-- ----------------------------------------------------------------------------

section("look")

local function IndexOfRegion(owner, region)
    for index, candidate in ipairs({ owner:GetRegions() }) do
        if candidate == region then
            return index
        end
    end
end

ok(frame.bg:GetTexture() == "Interface\\DC\\Shared\\FelLeather_512.tga", "the window wears the DC leather")
ok(frame.bgTint:GetTexture() == "Color-0,0,0,0.6", "under the DC tint")
ok(IndexOfRegion(frame, frame.bg) < IndexOfRegion(frame, frame.bgTint),
    "the tint is created second, since the last texture created wins within a layer")
ok(frame.border:GetParent() == frame
    and frame.border:GetBackdrop().edgeFile == "Interface\\DialogFrame\\UI-DialogBox-Border",
    "the dialog border is its own frame, so the leather cannot cover it")

-- Measured in the client's own font: the book's longest category name and task description. Text
-- wider than its column wraps onto the line below it, which is how this window first shipped.
local LONGEST_CATEGORY_NAME, LONGEST_DESCRIPTION = 134, 384

-- The client places a scroll child itself; the rows hang off it, so here it needs an anchor to have a
-- rectangle at all.
frame.listChild:SetPoint("TOPLEFT", frame.list, "TOPLEFT", 0, 0)

local function HasNoText(region)
    return region:GetObjectType() == "FontString" and (region:GetText() or "") == ""
end

local function Overlaps(a, b)
    -- An empty FontString has no width, so no rectangle, and covers nothing.
    if HasNoText(a) or HasNoText(b) then
        return false
    end

    local aLeft, aBottom, aRight, aTop = SIM.Rect(a)
    local bLeft, bBottom, bRight, bTop = SIM.Rect(b)
    -- Without this a region that failed to resolve would read as clear of everything.
    assert(aLeft and bLeft, "a region has no rectangle: " .. SIM.Describe(aLeft and b or a))
    return aLeft < bRight and bLeft < aRight and aBottom < bTop and bBottom < aTop
end

local readyRow, openRow, lockedRow = Row(201), Row(202), Row(203)

for _, button in ipairs(frame.categoryButtons) do
    ok(button.name:GetWidth() >= LONGEST_CATEGORY_NAME, "the longest category name fits its column")
    ok(button.name:GetHeight() == 16, "and a longer one is cut to one line")
    ok(not Overlaps(button.name, button.count) and not Overlaps(button.name, button.pending)
        and not Overlaps(button.count, button.pending), "a category's name, count and badge stay apart")
end

for _, row in ipairs({ readyRow, openRow, lockedRow }) do
    ok(row.description:GetWidth() >= LONGEST_DESCRIPTION, "the longest description fits its row")
    ok(row.name:GetHeight() == 16 and row.description:GetHeight() == 14, "and longer text is cut to one line")
    ok(not Overlaps(row.name, row.description) and not Overlaps(row.description, row.bar),
        "a row's name, description and bar stay apart")
    ok(not Overlaps(row.description, row.claim) and not Overlaps(row.bar, row.claim)
        and not Overlaps(row.reward, row.claim), "and clear of its Claim button")
    ok(not Overlaps(row.description, row.reward) and not Overlaps(row.bar, row.status),
        "and of its reward and status")
end

ok(readyRow.glow:IsShown() and readyRow.stripe:IsShown(), "a task ready to claim is lit")
ok(readyRow.stripe:GetTexture() == "Color-1,0.82,0,1", "in gold")
ok(not openRow.glow:IsShown() and not openRow.stripe:IsShown(), "an open task is not, though the row was reused")
ok(lockedRow.icon:IsDesaturated() == 1 and lockedRow.name:GetTextColor() == 0.6, "a locked task is greyed out")
ok(openRow.icon:IsDesaturated() == nil and openRow.name:GetTextColor() == 1, "an open one is not")

-- Finishing what locks a row must take the grey back off, and the row is the same frame.
Path.state[202] = { progress = 20, flags = 1 }
Path:NotifyChanged()
ok(Row(203) == lockedRow and lockedRow.icon:IsDesaturated() == nil and lockedRow.name:GetTextColor() == 1,
    "an unlocked task loses the grey")
Path.state[202] = { progress = 12, flags = 0 }
Path:NotifyChanged()

SIM.CallScript(openRow, "OnEnter")
ok(openRow.hover:IsShown(), "the row under the mouse lifts")
SIM.CallScript(openRow, "OnLeave")
ok(not openRow.hover:IsShown(), "and settles when the mouse leaves")

local iconLeft = readyRow.icon:GetTexCoord()
ok(iconLeft == 0.08, "task icons lose the bevel stock icons carry")
ok(frame.categoryButtons[2].background:GetTexture() ~= frame.categoryButtons[1].background:GetTexture(),
    "the selected category stands out")
noNewErrors("the look")

-- ----------------------------------------------------------------------------
-- Claims
-- ----------------------------------------------------------------------------

section("claims")

frame.categoryButtons[1]:Click()
mark = #sent
local rowClaim = Row(102)
rowClaim.claim:Click()
local claims = SentSince(mark, Op.CMSG_CLAIM)
ok(#claims == 1 and claims[1].data.id == 102, "Claim asks the server for that task")
ok(rowClaim.claim:IsEnabled() ~= 1, "and the button waits for the answer")
ok(not Path:IsClaimed(102), "nothing is marked claimed until the server says so")

Deliver(Op.SMSG_CLAIM_RESULT, { ok = true, msg = "", points = 325, paid = 25, ids = { 102 } })
ok(Path:IsClaimed(102) and Path.points == 325, "the answer marks it and updates the balance")
ok(frame.points:GetText() == "325 Shop Points", "the window follows")
ok(Row(102).check:IsShown(), "the row turns collected")
ok(chatLines[#chatLines]:find("25", 1, true) ~= nil, "the chat names the payout")

Deliver(Op.SMSG_CLAIM_RESULT, { ok = false, msg = "That reward has already been collected.", points = 325, paid = 0, ids = {} })
ok(chatLines[#chatLines]:find("already been collected", 1, true) ~= nil, "a refusal is shown as the server worded it")
noNewErrors("claims")

mark = #sent
frame.claimAll:Click()
ok(#SentSince(mark, Op.CMSG_CLAIM_ALL) == 1, "Claim All sends one request")
Deliver(Op.SMSG_CLAIM_RESULT, { ok = true, msg = "", points = 375, paid = 50, ids = { 201 } })
ok(Path:IsClaimed(201), "and takes the ids from the answer")
local _, _, left = Path:GetTotals()
ok(left == 0 and frame.claimAll:IsEnabled() ~= 1, "Claim All turns off when nothing is left")

-- ----------------------------------------------------------------------------
-- Live updates
-- ----------------------------------------------------------------------------

section("updates")

Deliver(Op.SMSG_TASK_UPDATE, { points = 375, u = { { 202, 15, 0 } } })
ok(select(1, Path:GetProgress(Path.taskById[202])) == 15, "a push moves progress")
SIM.Run(1)
ok(rawget(_G, "DCPathToast") == nil, "progress alone raises no toast")

Deliver(Op.SMSG_TASK_UPDATE, { points = 375, u = { { 202, 20, 1 } } })
SIM.Run(1)
local toast = rawget(_G, "DCPathToast")
ok(toast and toast:IsShown() and toast.text:GetText() == "Level 20", "completing a task raises a toast naming it")
ok(toast:GetBackdrop().bgFile == "Interface\\DC\\Shared\\FelLeather_512.tga", "cut from the same leather as the window")
SIM.Run(6)
ok(not toast:IsShown(), "the toast goes away by itself")
noNewErrors("the toast")

Deliver(Op.SMSG_TASK_UPDATE, { points = 375, u = { { 202, 20, 1 } } })
SIM.Run(1)
ok(not toast:IsShown(), "a task already complete raises no second toast")

-- A login credits every milestone at once, in one update per objective.
Path.state[101] = nil
Path.state[102] = nil
Deliver(Op.SMSG_TASK_UPDATE, { points = 375, u = { { 101, 1, 1 } } })
Deliver(Op.SMSG_TASK_UPDATE, { points = 375, u = { { 102, 1, 1 } } })
SIM.Run(1)
ok(toast:IsShown() and toast.text:GetText() == "2 tasks complete", "a burst becomes one toast")
noNewErrors("updates")

Deliver(Op.SMSG_TASK_UPDATE, { points = 9000, u = {} })
ok(Path.points == 9000 and frame.points:GetText() == "9,000 Shop Points", "a balance-only push updates the window")

-- ----------------------------------------------------------------------------
-- Second login: the saved book
-- ----------------------------------------------------------------------------

section("second login")

ok(DCPathDB.catalog.tasks[1].id == 101, "the saved book is in the readable form")

-- A task whose prerequisite left the book must not stay locked: the server opens it too.
Path:UseCatalog(REV, Path.categories, {
    { id = 300, category = 1, name = "Orphan", description = "", icon = "", target = 1, prev = 999, points = 5 },
})
Path.state[300] = { progress = 1, flags = 1 }
ok(not Path:IsLocked(Path.taskById[300]) and Path:CanClaim(Path.taskById[300]), "a missing prerequisite locks nothing")

-- ----------------------------------------------------------------------------
-- Disabled on the server
-- ----------------------------------------------------------------------------

section("disabled")

Path:UseCatalog(0, {}, {})
Deliver(Op.SMSG_STATE, { enabled = false, points = 0, earned = 0, t = {} })
noNewErrors("an empty, disabled book draws")
ok(frame.empty:IsShown() and frame.empty:GetText():find("not available", 1, true) ~= nil, "the window says so")

-- ----------------------------------------------------------------------------
-- The shop: Shop Points as a second way to pay
-- ----------------------------------------------------------------------------

section("shop")

local bought = {}
DCCollection = {
    L = {},
    currency = { tokens = 1000, emblems = 1000, points = 1500 },
    collections = {},
    RarityColors = {},
    Print = function() end,
    Debug = function() end,
    NormalizeTexturePath = function(_, texture, fallback)
        return texture or fallback
    end,
    RequestShopPurchase = function(_, shopId, payWithPoints)
        bought[#bought + 1] = { shopId = shopId, payWithPoints = payWithPoints }
    end,
    GetCurrencyBalances = function(self)
        return self.currency.tokens, self.currency.emblems
    end,
}

SIM.LoadFile(SIM.ADDONS_DIR .. "DC-Collection/Shop/ShopModule.lua", "DC-Collection", {})
SIM.LoadFile(SIM.ADDONS_DIR .. "DC-Collection/Shop/ShopUI.lua", "DC-Collection", {})
noNewErrors("the shop files load")

local Shop = DCCollection.ShopModule
local both = { id = 1, name = "Mount", costTokens = 500, costEmblems = 500, costPoints = 1500 }
local pointsOnly = { id = 2, name = "Exclusive", costTokens = 0, costEmblems = 0, costPoints = 2000 }
local tokensOnly = { id = 3, name = "Old Row", costTokens = 500, costEmblems = 500, costPoints = 0 }
local free = { id = 4, name = "Gift", costTokens = 0, costEmblems = 0, costPoints = 0 }
DCCollection.shopItems = { both, pointsOnly, tokensOnly, free }

ok(Shop:GetPoints() == 1500, "the balance comes from the collection's currency state")
ok(Shop:CanAfford(both) and Shop:CanAffordPoints(both), "a row can take both")
ok(Shop:IsPointsOnly(pointsOnly) and not Shop:IsPointsOnly(both), "a row with no other price is points-only")
ok(not Shop:CanAfford(pointsOnly), "a points-only row is out of reach below its price, however many tokens")
ok(not Shop:CanAffordPoints(tokensOnly), "a row without a points price cannot be paid in points")
ok(not Shop:IsPointsOnly(free) and Shop:CanAfford(free), "a free row stays free, not points-only")
ok(Shop:FormatCost(both) == "500 Tokens + 500 Emblems or 1500 Shop Points", "the cost reads as a choice")

Shop:Purchase(1)
ok(bought[1].shopId == 1 and not bought[1].payWithPoints, "Buy pays with tokens and essence")
Shop:Purchase(1, true)
ok(bought[2].shopId == 1 and bought[2].payWithPoints == true, "the points button pays with points")

DCCollection.currency.points = 2000
Shop:Purchase(2)
ok(bought[3].shopId == 2 and bought[3].payWithPoints == true, "a points-only row is always paid in points")

DCCollection.currency.points = 100
Shop:Purchase(1, true)
ok(#bought == 3, "the client does not ask for what it knows the balance cannot pay")

local shopParent = CreateFrame("Frame", nil, UIParent)
shopParent:SetSize(640, 400)
local item = DCCollection:CreateShopItemFrame(shopParent, 1)
noNewErrors("a shop row builds")

DCCollection.currency.points = 1500
DCCollection:UpdateShopItemFrame(item, both)
noNewErrors("a shop row with both prices draws")
ok(item.buyBtn:IsShown() and item.buyPointsBtn:IsShown(), "a row with both prices has both buttons")
ok(item.costPointsText:GetText() == "1500", "and shows the points price")
ok(item.buyPointsBtn:IsEnabled() == 1, "the points button is on when the balance covers it")

DCCollection.currency.points = 100
DCCollection:UpdateShopItemFrame(item, both)
ok(item.buyPointsBtn:IsEnabled() ~= 1 and item.buyBtn:IsEnabled() == 1, "short of points only that button turns off")

DCCollection:UpdateShopItemFrame(item, tokensOnly)
ok(item.buyBtn:IsShown() and not item.buyPointsBtn:IsShown() and not item.costPointsText:IsShown(),
    "a row without a points price looks as it always did")

DCCollection:UpdateShopItemFrame(item, pointsOnly)
ok(item.buyBtn:IsShown() and not item.buyPointsBtn:IsShown() and item.costPointsText:IsShown(),
    "a points-only row has one button and shows its price")

both.purchased = true
DCCollection:UpdateShopItemFrame(item, both)
ok(not item.buyBtn:IsShown() and not item.buyPointsBtn:IsShown() and item.purchasedText:IsShown(),
    "an owned row offers neither way to pay")
noNewErrors("the shop rows")

Deliver(Op.SMSG_TASK_UPDATE, { points = 777, u = {} })
ok(DCCollection.currency.points == 777, "a new balance reaches an open shop")
Deliver(Op.SMSG_CLAIM_RESULT, { ok = true, msg = "", points = 800, paid = 0, ids = {} })
ok(DCCollection.currency.points == 800, "and so does a claim")
ok(chatLines[#chatLines]:find("Reward collected", 1, true) ~= nil, "a reward without points does not claim 0 were earned")
noNewErrors("the balance sync")

T.Finish()
