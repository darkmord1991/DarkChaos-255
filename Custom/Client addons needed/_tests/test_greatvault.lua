-- Retail-style Great Vault (DC-MythicPlus/UI/GreatVaultFrame.lua). Pins that a
-- reward's icon resolves without the client item cache (GetItemIcon for stock
-- items, the server-shipped icon for custom ones), that a card is selected and
-- claimed through the Select Reward button, that the progress view carries the
-- forecast item level and key level, and that the history view shows one row.

dofile("wowsim.lua")
local ROOT = [[K:\Dark-Chaos\DarkChaos-255-Master\Custom\Client addons needed\]]
local pass, fail = 0, 0
local function ok(c, m) if c then pass=pass+1; print("  PASS "..m) else fail=fail+1; print("  FAIL "..m) end end

_G.UIParent = CreateFrame("Frame")
_G.GameTooltip = CreateFrame("GameTooltip")
_G.UISpecialFrames = {}
_G.StaticPopupDialogs = {}
_G.date = os.date

local shownPopup
_G.StaticPopup_Show = function(key, text) shownPopup = { key = key, text = text } end
_G.StaticPopup_Hide = function() end

-- Nothing is in the item cache, like a fresh client.
local hyperlinks = {}
_G.GetItemInfo = function() return nil end
_G.GetItemIcon = function(itemId)
    if itemId == 40243 then return "Interface\\Icons\\INV_Boots_Cloth_02" end
    return nil
end
local scan = CreateFrame("GameTooltip")
function scan:SetHyperlink(link) table.insert(hyperlinks, link) end
local realCreateFrame = CreateFrame
_G.CreateFrame = function(ftype, name, ...)
    if name == "DCMythicPlusVaultScanTooltip" then return scan end
    return realCreateFrame(ftype, name, ...)
end

local claims = {}
local namespace = {
    ClaimVaultReward = function(slot, itemId) table.insert(claims, { slot = slot, itemId = itemId }) end,
    RequestVaultInfo = function() end,
}
_G.DCMythicPlusHUD = namespace

dofile(ROOT..[[DC-MythicPlus\UI\GreatVaultFrame.lua]])
local GV = namespace.GreatVault

print("GreatVault")

local function locked(globalId, id, threshold, progress)
    return { globalId = globalId, id = id, threshold = threshold, progress = progress, status = "locked" }
end

local payload = {
    defaultView = "claim",
    open = true,
    claimed = false,
    tracks = {
        { id = "raid", slots = {
            { globalId = 1, id = 1, threshold = 2, progress = 2, status = "unlocked",
              rewards = { { itemId = 900001, ilvl = 264, itemName = "Custom Relic", quality = 4, icon = "INV_Custom_Relic" } } },
            locked(2, 2, 4, 2), locked(3, 3, 6, 2) } },
        { id = "mplus", slots = {
            { globalId = 4, id = 1, threshold = 1, progress = 1, status = "unlocked",
              rewards = { { itemId = 40243, ilvl = 213, itemName = "Footwraps of Vile Deceit", quality = 4 } } },
            locked(5, 2, 4, 1), locked(6, 3, 8, 1) } },
        { id = "pvp", slots = {
            { globalId = 7, id = 1, threshold = 1, progress = 1, status = "unlocked",
              rewards = { { itemId = 900002, ilvl = 200, quality = 3 } } },
            locked(8, 2, 4, 1), locked(9, 3, 8, 1) } },
    },
    progressTracks = {
        { id = "raid", slots = { locked(1, 1, 2, 0), locked(2, 2, 4, 0), locked(3, 3, 6, 0) } },
        { id = "mplus", slots = {
            { globalId = 4, id = 1, threshold = 1, progress = 5, status = "unlocked", rewards = {} },
            { globalId = 5, id = 2, threshold = 4, progress = 5, status = "unlocked", rewards = {} },
            locked(6, 3, 8, 5) } },
        { id = "pvp", slots = { locked(7, 1, 1, 0), locked(8, 2, 4, 0), locked(9, 3, 8, 0) } },
    },
    nextWeekTracks = {
        { id = "mplus", slots = {
            { globalId = 4, status = "forecast", forecastIlvl = 264, sourceKeyLevel = 12 },
            { globalId = 5, status = "forecast", forecastIlvl = 252, sourceKeyLevel = 8 } } },
    },
    historyTracks = {
        { id = "history", slots = {
            { globalId = 1, id = 1, status = "history", mapName = "Utgarde Keep", keystoneLevel = 12,
              completionTime = 1421, success = true, completedAt = 1757900000 },
            { globalId = 2, id = 2, status = "empty" },
            { globalId = 3, id = 3, status = "empty" } } },
    },
}

GV:Update(payload)
local f = GV.frame
local function card(row, column) return f.rows[row].cards[column] end
local function iconOf(c) return c.ItemFrame.Icon._tex and c.ItemFrame.Icon._tex[1] end

-- 1. Icons resolve without the item cache.
ok(f:IsShown(), "an open payload shows the vault")
ok(iconOf(card(2, 1)) == "Interface\\Icons\\INV_Boots_Cloth_02",
    "a stock reward takes its icon from GetItemIcon while GetItemInfo is still nil")
ok(iconOf(card(1, 1)) == "Interface\\Icons\\INV_Custom_Relic",
    "a custom reward unknown to Item.dbc uses the server-shipped icon")
ok(iconOf(card(3, 1)) == "Interface\\Icons\\INV_Misc_QuestionMark",
    "a reward with no icon anywhere falls back to the question mark")
ok(card(2, 1).ItemFrame.Name:GetText() == "Footwraps of Vile Deceit", "the reward is named from the payload")
ok(card(3, 1).ItemFrame.Name:GetText() == "Item #900002", "a reward with no name still says which item it is")
ok(#hyperlinks == 3, "each uncached reward is queried from the server once")
GV:Render()
ok(#hyperlinks == 3, "re-rendering does not re-query items already asked for")

-- 2. Selecting and claiming.
ok(f.SelectRewardButton:IsShown() and not f.SelectRewardButton:IsEnabled(),
    "Select Reward is offered but disabled until a card is chosen")
ok(card(2, 1).Progress:GetText() == "Item Level 213", "an unlocked reward shows its item level")
ok(card(2, 2).Progress:GetText() == "", "a locked slot hides its progress while rewards are claimable")
card(2, 2)._scripts.OnMouseUp(card(2, 2), "LeftButton")
ok(GV.selectedCard == nil, "a locked slot cannot be selected")
card(2, 1)._scripts.OnMouseUp(card(2, 1), "LeftButton")
ok(GV.selectedCard == card(2, 1), "clicking an unlocked reward selects it")
ok(card(2, 1).SelectedTexture:IsShown() and card(1, 1).UnselectedFrame:IsShown(),
    "the selected card is highlighted and the other rewards are dimmed")
ok(f.SelectRewardButton:IsEnabled(), "Select Reward enables once a card is chosen")
GV:Render()
ok(GV.selectedCard == card(2, 1), "a server refresh keeps the selection")
f.SelectRewardButton._scripts.OnClick(f.SelectRewardButton)
ok(shownPopup and shownPopup.text:find("Footwraps of Vile Deceit", 1, true) ~= nil,
    "the confirmation names the chosen item")
StaticPopupDialogs[shownPopup.key].OnAccept()
ok(#claims == 1 and claims[1].slot == 4 and claims[1].itemId == 40243, "accepting claims that slot and item")

-- 3. Claimed state.
payload.claimed = true
payload.tracks[2].slots[1].status = "claimed"
GV:Update(payload)
ok(not f.SelectRewardButton:IsShown(), "no Select Reward once the week is claimed")
ok(card(2, 1).Progress:GetText() == "Claimed" and card(2, 1).ItemFrame:IsShown(),
    "the claimed slot still shows the item that was taken")
card(1, 1)._scripts.OnMouseUp(card(1, 1), "LeftButton")
ok(GV.selectedCard == nil, "nothing is selectable after claiming")

-- 4. This week's progress carries the forecast.
GV:SetView("progress")
ok(card(2, 1).Progress:GetText() == "Mythic+ 12", "an unlocked Mythic+ slot shows the key level it is based on")
ok(card(2, 2).forecastIlvl == 252, "the forecast item level is attached for the tooltip")
ok(card(2, 3).Progress:GetText() == "5/8", "a locked slot shows progress towards its threshold")
ok(not card(2, 1).ItemFrame:IsShown(), "progress slots show no item")
ok(f.rows[3]:IsShown() and f.dividers[2]:IsShown(), "all three rows are shown")

-- 5. Run history.
GV:SetView("history")
ok(f.rows[1]:IsShown() and not f.rows[2]:IsShown() and not f.rows[3]:IsShown(), "history uses a single row")
ok(not f.dividers[1]:IsShown(), "row dividers hide with the rows")
ok(f.rows[1].Name:GetText() == "Latest Runs", "the history row is titled")
ok(card(1, 1).Threshold:GetText() == "Utgarde Keep" and card(1, 1).Progress:GetText() == "+12",
    "a run card names the dungeon and key level")
ok(card(1, 2).Threshold:GetText() == "No run recorded", "an empty history slot says so")

-- 6. A legacy "next" view request lands on the progress view.
GV:SetView("next")
ok(GV._activeView == "progress", "the retired forecast view opens This Week")

-- 7. A tooltip opened on an uncached item fills in once the item arrives.
function GameTooltip:SetOwner(owner) self._owner = owner end
function GameTooltip:GetOwner() return self._owner end
function GameTooltip:Hide() self._owner = nil; self._shown = false end
local tooltipLinks = {}
function GameTooltip:SetHyperlink(link) table.insert(tooltipLinks, link) end
local cached = {}
_G.GetItemInfo = function(itemId)
    if cached[itemId] then return "Footwraps of Vile Deceit", "item:40243", 4 end
end

GV:SetView("claim")
local itemFrame = card(2, 1).ItemFrame
itemFrame._scripts.OnEnter(itemFrame)
ok(#tooltipLinks == 1 and itemFrame._scripts.OnUpdate ~= nil, "hovering an uncached item waits for it to arrive")
advance(0.3)
ok(#tooltipLinks == 1, "nothing is redrawn while the item is still missing")
cached[40243] = true
advance(0.3)
ok(#tooltipLinks == 2 and itemFrame._scripts.OnUpdate == nil,
    "the tooltip is set again once the item is cached, and the wait stops")

cached[40243] = nil
card(2, 1)._scripts.OnEnter(card(2, 1))
ok(GameTooltip._owner == itemFrame and itemFrame._scripts.OnUpdate ~= nil,
    "hovering the card shows its reward's tooltip and waits the same way")
card(2, 1)._scripts.OnLeave(card(2, 1))
ok(GameTooltip._owner == nil and itemFrame._scripts.OnUpdate == nil, "leaving the card stops the wait")

print(("RESULT: %d passed, %d failed"):format(pass, fail))
if fail > 0 then os.exit(1) end
