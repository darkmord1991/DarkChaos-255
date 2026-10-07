--[[
    The Random Enchants panel of DC-ItemUpgrade (EnchantReroll.lua) on the strict 3.3.5a client
    (talents_sim.lua + talents_client.lua), against a fake UPG server module and a stand-in for the
    upgrade window it docks to.

    Run from this directory:  lua test_enchantreroll.lua        (-v prints every check)
]]

dofile("talents_sim.lua")
dofile("talents_client.lua")
local T = dofile("talents_testlib.lua")
local CLIENT = SIM.client
local ok, section, noNewErrors = T.ok, T.section, T.noNewErrors

local POPUP = "DC_ITEMUPGRADE_ENCHANT_REROLL";
local SMSG_ENCHANT_INFO, SMSG_ENCHANT_RESULT = 0x33, 0x34;
local CMSG_GET_ENCHANT_INFO, CMSG_DO_ENCHANT_REROLL = 0x22, 0x23;

-- ----------------------------------------------------------------------------
-- The 3.3.5 item and money API the simulator does not model
-- ----------------------------------------------------------------------------

local TOKEN_ICON = "Interface\\Icons\\INV_Misc_Token_ArgentDawn";
function GetItemIcon(itemId)
    return itemId == 300311 and TOKEN_ICON or nil;
end

local playerMoney = 50000;
function GetMoney()
    return playerMoney;
end

function GetCoinTextureString(copper)
    return ("%d copper"):format(copper);
end

ITEM_QUALITY_COLORS = ITEM_QUALITY_COLORS or {
    [1] = { r = 1, g = 1, b = 1, hex = "|cffffffff" },
    [2] = { r = 0.12, g = 1, b = 0, hex = "|cff1eff00" },
    [3] = { r = 0, g = 0.44, b = 0.87, hex = "|cff0070dd" },
    [4] = { r = 0.64, g = 0.21, b = 0.93, hex = "|cffa335ee" },
    [7] = { r = 0, g = 0.8, b = 1, hex = "|cff00ccff" },
};

-- ----------------------------------------------------------------------------
-- Fake DCAddonProtocol: records requests, hands answers to the registered handlers
-- ----------------------------------------------------------------------------

local sent, handlers = {}, {};
DCAddonProtocol = {
    Request = function(_, module, opcode, data)
        sent[#sent + 1] = { module = module, opcode = opcode, data = data };
    end,
    RegisterHandler = function(_, module, opcode, handler)
        handlers[module .. "_" .. opcode] = handler;
    end,
};

local function Deliver(opcode, data)
    handlers["UPG_" .. opcode](data);
end

local function SentSince(mark, opcode)
    local list = {};
    for index = mark + 1, #sent do
        if sent[index].opcode == opcode then
            list[#list + 1] = sent[index];
        end
    end
    return list;
end

-- ----------------------------------------------------------------------------
-- The upgrade window the panel attaches to (geometry from DarkChaos_ItemUpgrade_Retail.xml/.lua)
-- ----------------------------------------------------------------------------

local main = CreateFrame("Frame", "DarkChaos_ItemUpgradeFrame", UIParent);
main:SetWidth(560);
main:SetHeight(540);
main:SetPoint("CENTER", UIParent, "CENTER", -200, 0);
main.BrowseButton = CreateFrame("Button", "DarkChaos_ItemUpgradeFrameBrowseButton", main, "UIPanelButtonTemplate");
main.BrowseButton:SetWidth(76);
main.BrowseButton:SetHeight(22);
main.BrowseButton:SetPoint("BOTTOMLEFT", main, "BOTTOMLEFT", 24, 20);
main.TierBrowseButton = CreateFrame("Button", "DarkChaos_ItemUpgradeFrameTierBrowseButton", main,
    "UIPanelButtonTemplate");
main.TierBrowseButton:SetWidth(76);
main.TierBrowseButton:SetHeight(22);
main.TierBrowseButton:SetPoint("LEFT", main.BrowseButton, "RIGHT", 4, 0);
-- ButtonFrame (inset 22, 30 from the bottom) centres the 168x32 Upgrade button 6 above its bottom.
local upgradeButton = CreateFrame("Button", "DarkChaos_ItemUpgradeFrameUpgradeButton", main);
upgradeButton:SetWidth(168);
upgradeButton:SetHeight(32);
upgradeButton:SetPoint("BOTTOM", main, "BOTTOM", 0, 36);
main:Hide();

local itemBrowser = CreateFrame("Frame", "DarkChaos_ItemBrowserFrame", UIParent);
itemBrowser:Hide();
local tierBrowser = CreateFrame("Frame", "DarkChaos_TierBrowserFrame", UIParent);
tierBrowser:Hide();

function DarkChaos_ItemUpgrade_BrowseButton_OnClick()
    if itemBrowser:IsShown() then
        itemBrowser:Hide();
    else
        tierBrowser:Hide();
        itemBrowser:Show();
    end
end

function DarkChaos_ItemUpgrade_TierBrowseButton_OnClick()
    if tierBrowser:IsShown() then
        tierBrowser:Hide();
    else
        itemBrowser:Hide();
        tierBrowser:Show();
    end
end

local queued = {};
function DarkChaos_ItemUpgrade_QueueQuery(serverBag, serverSlot, context)
    queued[#queued + 1] = { bag = serverBag, slot = serverSlot, context = context };
end

DarkChaos_ItemUpgrade = {
    GetServerBagFromClient = function(bag)
        return bag;
    end,
    GetServerSlotFromClient = function(_, slot)
        return slot - 1;
    end,
};
local DC = DarkChaos_ItemUpgrade;

-- What DarkChaos_ItemUpgrade_SelectItemBySlot leaves in DC.currentItem for a bag item.
local function Select(entry, name, quality, bag, slot)
    DC.currentItem = {
        link = ("|cff0070dd|Hitem:%d:0:0:0:0:0:0:0:80|h[%s]|h|r"):format(entry, name),
        name = name,
        quality = quality,
        itemID = entry,
        itemEntry = entry,
        bag = bag,
        slot = slot,
        serverBag = bag,
        serverSlot = slot - 1,
        locationKey = bag .. ":" .. (slot - 1),
        texture = "Interface\\Icons\\INV_Sword_04",
    };
end

local function Info(overrides)
    local data = {
        success = true,
        bag = 0,
        slot = 3,
        itemGuid = 777,
        itemEntry = 40001,
        enabled = true,
        eligible = true,
        reason = "",
        maxLines = 3,
        lines = {
            { line = 0, enchantId = 2803, tier = 3, text = "+12 Agility" },
            { line = 1, enchantId = 2804, tier = 3, text = "+15 Stamina, +10 Strength" },
            { line = 2, enchantId = 0, tier = 0, text = "" },
        },
        rerollCount = 2,
        costIncrease = 1,
        allowAdd = true,
        allowRerollAll = true,
        prices = {
            reroll = { amount = 8, money = 0 },
            add = { amount = 30, money = 0 },
            rerollAll = { amount = 17, money = 0 },
        },
        currency = { type = 1, itemId = 300311, name = "DC Item Upgrade Token", balance = 40 },
        money = 50000,
    };
    for key, value in pairs(overrides or {}) do
        data[key] = value;
    end
    return data;
end

-- ----------------------------------------------------------------------------
-- Load
-- ----------------------------------------------------------------------------

section("load");

SIM.LoadFile(SIM.ADDONS_DIR .. "DC-ItemUpgrade/EnchantReroll.lua", "DC-ItemUpgrade", {});
noNewErrors("EnchantReroll.lua loads after the upgrade window");

local Panel = DC.EnchantReroll;
local button = rawget(_G, "DarkChaos_ItemUpgradeFrameEnchantsButton");
ok(Panel ~= nil and button ~= nil, "the panel namespace and its footer button exist");
ok(handlers["UPG_" .. SMSG_ENCHANT_INFO] and handlers["UPG_" .. SMSG_ENCHANT_RESULT],
    "ENCHANT_INFO and ENCHANT_RESULT handlers are registered");
ok(rawget(_G, "DarkChaos_EnchantRerollFrame") == nil, "the panel itself is not built at load");
ok(button and button:GetParent() == main and button:GetText() == "Random Enchants",
    "the button sits on the upgrade window and reads Random Enchants");

main:Show();
do
    local bl, bb, br, bt = SIM.Rect(button);
    local il, _, _, it = SIM.Rect(main.BrowseButton);
    local _, _, tr = SIM.Rect(main.TierBrowseButton);
    local ul, ub, ur, ut = SIM.Rect(upgradeButton);
    ok(bl and math.abs(bl - il) < 0.01 and math.abs(br - tr) < 0.01,
        "the button spans the Items and Tiers buttons below it");
    ok(bb and bb >= it, "the button sits above Items / Tiers");
    ok(bl and (br <= ul or bl >= ur or bt <= ub or bb >= ut), "the button stays clear of the Upgrade button");
end

-- ----------------------------------------------------------------------------
-- Nothing selected
-- ----------------------------------------------------------------------------

section("nothing selected");

local mark = #sent;
button:Click();
local frame = rawget(_G, "DarkChaos_EnchantRerollFrame");
ok(frame and frame:IsShown(), "clicking the button opens the panel");
ok(frame and frame.message:IsShown() and frame.message:GetText():find("Select an item", 1, true) ~= nil,
    "with nothing selected the panel asks for an item");
ok(#SentSince(mark, CMSG_GET_ENCHANT_INFO) == 0, "and asks the server nothing");
ok(SIM.State(button).highlightLocked, "the button stays lit while the panel is open");
ok(tContains(UISpecialFrames, "DarkChaos_EnchantRerollFrame"), "Escape closes the panel");

-- ----------------------------------------------------------------------------
-- An item is selected
-- ----------------------------------------------------------------------------

section("info");

mark = #sent;
Select(40001, "Sharpened Blade", 3, 0, 4);
SIM.Run(0.4);
local requests = SentSince(mark, CMSG_GET_ENCHANT_INFO);
ok(#requests == 1 and requests[1].module == "UPG" and requests[1].data.bag == 0 and requests[1].data.slot == 3,
    "selecting an item asks for its lines at its server location (0:3)");
ok(frame.message:GetText():find("Loading", 1, true) ~= nil, "the panel says it is loading");

Deliver(SMSG_ENCHANT_INFO, Info({ bag = 1, slot = 3 }));
ok(frame.message:IsShown(), "an answer about another location is ignored");

Deliver(SMSG_ENCHANT_INFO, Info());
noNewErrors("rendering the item's lines");
local rows = frame.rows;
ok(not frame.message:IsShown(), "the lines replace the loading text");
ok(rows[1].text:GetText() == "+12 Agility" and rows[1].tier:GetText() == "Tier 3", "line 1 shows its enchant and tier");
ok(rows[2].text:GetText() == "+15 Stamina, +10 Strength", "line 2 shows a two-stat enchant");
ok(rows[1].button:IsShown() and rows[1].button:GetText() == "Reroll" and rows[1].button:IsEnabled(),
    "a filled line offers Reroll");
ok(rows[1].cost:GetText():find("8", 1, true) == 1 and rows[1].cost:GetText():find(TOKEN_ICON, 1, true) ~= nil,
    "the reroll price is shown with the currency's icon");
ok(rows[3].text:GetText() == "Empty" and rows[3].button:GetText() == "Add" and rows[3].button:IsEnabled(),
    "the first empty line offers Add");
ok(rows[3].cost:GetText():find("30", 1, true) == 1, "at the add price");
ok(frame.rerollAll:IsShown() and frame.rerollAll:IsEnabled() and frame.rerollAllCost:GetText():find("17", 1, true) == 1,
    "Reroll All is offered for two or more lines");
ok(frame.balance:GetText():find("40", 1, true) ~= nil, "the balance is shown");
ok(frame.hint:GetText():find("Rerolled 2 times", 1, true) ~= nil, "the escalation hint counts earlier rerolls");
ok(frame.itemName:GetText() == "Sharpened Blade" and frame.itemDetail:GetText() == "2 of 3 enchant lines",
    "the header names the item and how full it is");

-- ----------------------------------------------------------------------------
-- Rerolling a line, with the confirmation
-- ----------------------------------------------------------------------------

section("reroll");

mark = #sent;
rows[2].button:Click();
local popupName, popup = StaticPopup_Visible(POPUP);
ok(popup ~= nil, "Reroll asks for confirmation");
ok(popup and popup.text:GetText():find("Reroll line 2", 1, true) ~= nil
    and popup.text:GetText():find("+15 Stamina, +10 Strength", 1, true) ~= nil,
    "the confirmation names the line and the enchant it replaces");
ok(#SentSince(mark, CMSG_DO_ENCHANT_REROLL) == 0, "nothing is sent before it is accepted");

SIM.ClickPopup(POPUP, 1);
local actions = SentSince(mark, CMSG_DO_ENCHANT_REROLL);
local action = actions[1] and actions[1].data;
ok(#actions == 1 and action.action == "reroll" and action.line == 1 and action.bag == 0 and action.slot == 3,
    "accepting rerolls line 2 (0-based line 1) of the item at 0:3");
ok(action and action.expected[1] == 2803 and action.expected[2] == 2804 and action.expected[3] == 0,
    "the request carries the lines the player saw");
ok(not rows[1].button:IsEnabled() and not rows[3].button:IsEnabled() and not frame.rerollAll:IsEnabled(),
    "every action waits while the reroll is in flight");
ok(frame.status:GetText() == "Waiting for the server...", "the status says so");
rows[1].button:Click();
ok(#SentSince(mark, CMSG_DO_ENCHANT_REROLL) == 1, "a second click meanwhile sends nothing");

local queuedBefore = #queued;
Deliver(SMSG_ENCHANT_RESULT, {
    success = true, errorCode = 0, error = "", action = "reroll", line = 1, bag = 0, slot = 3,
    before = { 2803, 2804, 0 }, after = { 2803, 2901, 0 },
    cost = { currencyType = 1, currencyItemId = 300311, amount = 8, money = 0 }, rerollCount = 3,
});
noNewErrors("a successful result");
ok(SIM.State(rows[2].glow).alpha > 0 and SIM.State(rows[1].glow).alpha == 0,
    "the changed line glows, the other does not");
ok(#queued == queuedBefore + 1 and queued[#queued].bag == 0 and queued[#queued].slot == 3,
    "the upgrade window re-reads the item so its enchant preview is current");

local lines = Info().lines;
lines[2] = { line = 1, enchantId = 2901, tier = 3, text = "+20 Spirit" };
Deliver(SMSG_ENCHANT_INFO, Info({ lines = lines, rerollCount = 3 }));
ok(rows[2].text:GetText() == "+20 Spirit" and rows[1].button:IsEnabled(),
    "the fresh info shows the new line and frees the buttons");
SIM.Run(2);
ok(SIM.State(rows[2].glow).alpha == 0, "the glow fades out");

-- ----------------------------------------------------------------------------
-- Shift-click, refusals, stale confirmations
-- ----------------------------------------------------------------------------

section("shift-click and refusals");

mark = #sent;
SIM.keys.shift = true;
rows[3].button:Click();
SIM.keys.shift = false;
actions = SentSince(mark, CMSG_DO_ENCHANT_REROLL);
ok(#actions == 1 and actions[1].data.action == "add" and actions[1].data.line == 2,
    "shift-clicking Add sends at once (line 3 = wire line 2)");
ok(StaticPopup_Visible(POPUP) == nil, "without a confirmation");

local errorsBefore = #SIM.uiErrors;
Deliver(SMSG_ENCHANT_RESULT, {
    success = false, errorCode = 11, error = "You cannot afford that.", action = "add", line = 2, bag = 0, slot = 3,
    before = { 2803, 2901, 0 }, after = { 2803, 2901, 0 }, cost = {}, rerollCount = 3,
});
ok(frame.status:GetText() == "You cannot afford that." and select(2, frame.status:GetTextColor()) < 0.5,
    "a refusal is shown in red with the server's reason");
ok(#SIM.uiErrors == errorsBefore + 1, "and on the error frame");
ok(rows[1].button:IsEnabled(), "the buttons come back after a refusal");

mark = #sent;
rows[1].button:Click();
ok(StaticPopup_Visible(POPUP) ~= nil, "the confirmation is open");
lines = Info().lines;
lines[1] = { line = 0, enchantId = 3100, tier = 3, text = "+9 Haste Rating" };
lines[2] = { line = 1, enchantId = 2901, tier = 3, text = "+20 Spirit" };
Deliver(SMSG_ENCHANT_INFO, Info({ lines = lines, rerollCount = 4 }));
SIM.ClickPopup(POPUP, 1);
ok(#SentSince(mark, CMSG_DO_ENCHANT_REROLL) == 0, "a confirmation for lines that changed meanwhile sends nothing");
ok(frame.status:GetText():find("The item changed", 1, true) ~= nil, "and says the item changed");

-- ----------------------------------------------------------------------------
-- Prices the player cannot pay, combat
-- ----------------------------------------------------------------------------

section("affordability and combat");

Deliver(SMSG_ENCHANT_INFO, Info({
    currency = { type = 1, itemId = 300311, name = "DC Item Upgrade Token", balance = 5 },
}));
ok(not rows[1].button:IsEnabled() and not rows[3].button:IsEnabled() and not frame.rerollAll:IsEnabled(),
    "with 5 tokens nothing priced above 5 can be bought");
ok(select(2, rows[1].cost:GetTextColor()) < 0.5, "an unaffordable price is red");

Deliver(SMSG_ENCHANT_INFO, Info({ prices = {
    reroll = { amount = 8, money = 60000 }, add = { amount = 30, money = 0 }, rerollAll = { amount = 17, money = 0 },
} }));
ok(not rows[1].button:IsEnabled() and rows[3].button:IsEnabled(),
    "a gold price above the purse disables only that action");
ok(rows[1].cost:GetText():find("60000 copper", 1, true) ~= nil
    and frame.balance:GetText():find("50000 copper", 1, true) ~= nil,
    "gold prices and the purse are shown when gold is charged");

Deliver(SMSG_ENCHANT_INFO, Info());
CLIENT.player.inCombat = true;
SIM.FireEvent("PLAYER_REGEN_DISABLED");
ok(not rows[1].button:IsEnabled() and frame.status:GetText():find("combat", 1, true) ~= nil,
    "entering combat disables the actions and says why");
CLIENT.player.inCombat = false;
SIM.FireEvent("PLAYER_REGEN_ENABLED");
ok(rows[1].button:IsEnabled(), "leaving combat enables them again");

Deliver(SMSG_ENCHANT_INFO, Info({ enabled = false }));
ok(rows[1].text:GetText() == "+12 Agility" and not rows[1].button:IsEnabled()
    and frame.status:GetText():find("switched off", 1, true) ~= nil,
    "with rerolling switched off the lines are shown read-only");

-- ----------------------------------------------------------------------------
-- No answer
-- ----------------------------------------------------------------------------

section("timeouts");

Deliver(SMSG_ENCHANT_INFO, Info());
mark = #sent;
SIM.keys.shift = true;
rows[1].button:Click();
SIM.keys.shift = false;
SIM.Run(7);
ok(frame.status:GetText():find("No answer", 1, true) ~= nil and rows[1].button:IsEnabled(),
    "an action with no answer frees the buttons after the timeout");
ok(#SentSince(mark, CMSG_GET_ENCHANT_INFO) == 1, "and asks for the item's lines again");
Deliver(SMSG_ENCHANT_INFO, Info());
SIM.Run(11);
ok(frame.status:GetText() == "", "a result message clears itself after a while");

-- ----------------------------------------------------------------------------
-- Items that cannot hold lines, moved items, a lowered line limit
-- ----------------------------------------------------------------------------

section("other items");

mark = #sent;
Select(300365, "Heirloom Adventurer's Shirt", 7, 1, 2);
SIM.Run(0.4);
requests = SentSince(mark, CMSG_GET_ENCHANT_INFO);
ok(#requests == 1 and requests[1].data.bag == 1 and requests[1].data.slot == 1, "selecting another item asks about it");
ok(frame.message:GetText():find("Loading", 1, true) ~= nil and not rows[1]:IsShown(),
    "the previous item's lines are not shown for the new one");
Deliver(SMSG_ENCHANT_INFO, Info({
    bag = 1, slot = 1, itemEntry = 300365, eligible = false,
    reason = "This item's quality cannot carry random enchants.",
    lines = {}, prices = {},
}));
ok(frame.message:GetText() == "This item's quality cannot carry random enchants." and not frame.rerollAll:IsShown(),
    "an ineligible item shows the server's reason and no actions");
ok(frame.balance:GetText() == "", "and no balance");

Deliver(SMSG_ENCHANT_INFO, Info({ bag = 1, slot = 1, itemEntry = 40001 }));
ok(frame.message:GetText():find("Another item is in that slot", 1, true) ~= nil,
    "an answer for a different item at the same location is not shown as this item's");

Select(40001, "Sharpened Blade", 3, 0, 4);
SIM.Run(0.4);
lines = Info().lines;
lines[3] = { line = 2, enchantId = 3200, tier = 3, text = "+7 Spell Power" };
Deliver(SMSG_ENCHANT_INFO, Info({ maxLines = 2, lines = lines }));
ok(rows[3]:IsShown() and rows[3].text:GetText() == "+7 Spell Power" and not rows[3].button:IsShown(),
    "a line above a lowered MaxEnchantsPerItem is shown but offers nothing");
ok(frame.rerollAll:IsShown() and frame.itemDetail:GetText() == "2 of 2 enchant lines",
    "Reroll All and the header count only the lines within the limit");

-- ----------------------------------------------------------------------------
-- Sharing the dock with the item and tier browsers
-- ----------------------------------------------------------------------------

section("browsers");

Deliver(SMSG_ENCHANT_INFO, Info());
DarkChaos_ItemUpgrade_BrowseButton_OnClick();
ok(itemBrowser:IsShown() and not frame:IsShown(), "opening the item browser moves the panel aside");
mark = #sent;
itemBrowser:Hide();
ok(frame:IsShown(), "closing it brings the panel back");
ok(#SentSince(mark, CMSG_GET_ENCHANT_INFO) == 1, "and the panel re-reads the item");

tierBrowser:Show();
ok(not frame:IsShown(), "the tier browser moves the panel aside too");
button:Click();
ok(frame:IsShown() and not tierBrowser:IsShown(), "the button brings the panel back over the tier browser");

frame.closeButton:Click();
ok(not frame:IsShown() and not SIM.State(button).highlightLocked, "the close box closes the panel");
DarkChaos_ItemUpgrade_BrowseButton_OnClick();
itemBrowser:Hide();
ok(not frame:IsShown(), "a panel the player closed does not come back with a browser");

button:Click();
ok(frame:IsShown(), "the button reopens it");
main:Hide();
ok(not frame:IsShown(), "closing the upgrade window closes the panel");
main:Show();
ok(not frame:IsShown(), "and reopening the window does not reopen it");

main.TierBrowseButton:Hide();
ok(not button:IsShown(), "the button hides with Items / Tiers (heirloom package picker)");
main.TierBrowseButton:Show();
ok(button:IsShown(), "and returns with them");

-- ----------------------------------------------------------------------------
-- Slash command
-- ----------------------------------------------------------------------------

section("slash command");

main:Hide();
local toggled;
DC.ToggleUpgradeFrame = function(mode)
    toggled = mode;
    main:Show();
    return true;
end;
SlashCmdList["DCENCHANTS"]();
ok(toggled == "STANDARD" and main:IsShown() and frame:IsShown(), "/dcenchants opens the upgrade window and the panel");

noNewErrors("the whole run");
T.Finish();
