--[[
    DC-ItemUpgrade - Random Enchants panel

    Reroll one DC random enchant line, reroll every line, or add a line to an empty slot of
    the item selected in the upgrade window. The server decides everything (the lines, the
    prices, the balance) and this panel only draws its answer. Every action carries the lines
    the panel showed when the player clicked, so a stale click (a second click queued behind
    the first, a line that changed meanwhile) is refused by the server instead of charged.

    Wire (module UPG; the server side is dc_addon_enchant_reroll.cpp):
        CMSG 0x22  GET_ENCHANT_INFO   { bag, slot }
        CMSG 0x23  DO_ENCHANT_REROLL  { bag, slot, action, line, expected }
        SMSG 0x33  ENCHANT_INFO       lines, eligibility, prices, reroll count, balance
        SMSG 0x34  ENCHANT_RESULT     success / error, the lines before and after
    `line` is 0-based on the wire; rows here are 1-based.
]]

DarkChaos_ItemUpgrade = DarkChaos_ItemUpgrade or {};
local DC = DarkChaos_ItemUpgrade;

local MODULE = "UPG";
local CMSG_GET_ENCHANT_INFO = 0x22;
local CMSG_DO_ENCHANT_REROLL = 0x23;
local SMSG_ENCHANT_INFO = 0x33;
local SMSG_ENCHANT_RESULT = 0x34;

local MAX_LINES = 3;
local REQUEST_TIMEOUT = 6;      -- seconds without an answer before the panel stops waiting
local FLASH_SECONDS = 1.6;      -- how long a changed line glows
local SELECTION_POLL = 0.25;    -- how often the open panel checks the upgrade window's selection
local REFRESH_DELAY = 1.0;      -- bag / money changes are batched into one refresh this late
local STATUS_SECONDS = 10;      -- how long a result or a warning stays above the footer

local FRAME_WIDTH = 330;
local FRAME_HEIGHT = 404;
local ROW_HEIGHT = 58;
local ROW_GAP = 4;

local BG_FELLEATHER = "Interface\\DC\\Shared\\FelLeather_512.tga";
local POPUP = "DC_ITEMUPGRADE_ENCHANT_REROLL";

local Panel = {
    info = nil,             -- the last ENCHANT_INFO for the selected item, normalised
    infoKey = nil,          -- the selection that info describes
    requestedKey = nil,     -- the selection the last info request was for
    infoRequestedAt = nil,  -- GetTime() of an unanswered info request
    pending = nil,          -- { request, sentAt } of an unanswered action
    status = nil,           -- { text, r, g, b } shown above the footer
    flash = {},             -- row -> seconds of glow left
    restoreAfter = nil,     -- the browser that pushed the panel aside, if any
    refreshAt = nil,        -- GetTime() at which a batched refresh is due
};
DC.EnchantReroll = Panel;

-- ============================================================================
-- Selection and protocol
-- ============================================================================

local function GetProtocol()
    local protocol = rawget(_G, "DCAddonProtocol");
    if type(protocol) == "table" and type(protocol.Request) == "function" then
        return protocol;
    end
    return nil;
end

-- The item selected in the upgrade window and its location as every UPG request names it.
local function GetSelection()
    local item = DC.currentItem;
    if type(item) ~= "table" or not item.link then
        return nil;
    end

    local bag, slot = item.serverBag, item.serverSlot;
    if (bag == nil or slot == nil) and item.bag ~= nil and item.slot ~= nil
            and DC.GetServerBagFromClient and DC.GetServerSlotFromClient then
        bag = DC.GetServerBagFromClient(item.bag);
        slot = DC.GetServerSlotFromClient(item.bag, item.slot);
    end
    if bag == nil or slot == nil then
        return nil;
    end

    return item, tonumber(bag), tonumber(slot);
end

local function LocationKey(bag, slot)
    return tostring(bag) .. ":" .. tostring(slot);
end

-- Changes whenever the panel needs new data: another item, another location, or another
-- item now sitting at the same location.
local function SelectionKey()
    local item, bag, slot = GetSelection();
    if not item then
        return nil;
    end
    return LocationKey(bag, slot) .. "|" .. tostring(item.link);
end

local function NormalizeInfo(data)
    local info = {
        success = data.success ~= false,
        error = type(data.error) == "string" and data.error or "",
        enabled = data.enabled ~= false,
        eligible = data.eligible == true,
        reason = type(data.reason) == "string" and data.reason or "",
        maxLines = math.max(0, math.min(MAX_LINES, tonumber(data.maxLines) or MAX_LINES)),
        rerollCount = tonumber(data.rerollCount) or 0,
        costIncrease = tonumber(data.costIncrease) or 0,
        allowAdd = data.allowAdd == true,
        allowRerollAll = data.allowRerollAll == true,
        money = tonumber(data.money) or 0,
        itemEntry = tonumber(data.itemEntry),
        lines = {},
        prices = {},
    };

    for index = 1, MAX_LINES do
        info.lines[index] = { enchantId = 0, tier = 0, text = "" };
    end
    if type(data.lines) == "table" then
        for _, row in ipairs(data.lines) do
            local index = type(row) == "table" and (tonumber(row.line) or -1) + 1 or 0;
            if index >= 1 and index <= MAX_LINES then
                info.lines[index] = {
                    enchantId = tonumber(row.enchantId) or 0,
                    tier = tonumber(row.tier) or 0,
                    text = type(row.text) == "string" and row.text or "",
                };
            end
        end
    end

    local prices = type(data.prices) == "table" and data.prices or {};
    for _, action in ipairs({ "reroll", "add", "rerollAll" }) do
        local price = prices[action];
        if type(price) == "table" then
            info.prices[action] = { amount = tonumber(price.amount) or 0, money = tonumber(price.money) or 0 };
        end
    end

    local currency = type(data.currency) == "table" and data.currency or {};
    info.currency = {
        itemId = tonumber(currency.itemId) or 0,
        name = type(currency.name) == "string" and currency.name or "",
        balance = tonumber(currency.balance) or 0,
    };

    return info;
end

-- ============================================================================
-- Lines, prices and text
-- ============================================================================

local function FilledLines(info)
    local count = 0;
    for index = 1, info.maxLines do
        if info.lines[index].enchantId > 0 then
            count = count + 1;
        end
    end
    return count;
end

local function FirstFreeLine(info)
    for index = 1, info.maxLines do
        if info.lines[index].enchantId == 0 then
            return index;
        end
    end
    return nil;
end

local function ExpectedLines(info)
    local expected = {};
    for index = 1, MAX_LINES do
        expected[index] = info.lines[index].enchantId;
    end
    return expected;
end

local function SameLines(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then
        return false;
    end
    for index = 1, MAX_LINES do
        if (tonumber(a[index]) or 0) ~= (tonumber(b[index]) or 0) then
            return false;
        end
    end
    return true;
end

local function PriceFor(info, action)
    if action == "reroll" then
        return info.prices.reroll;
    elseif action == "add" then
        return info.prices.add;
    elseif action == "rerollAll" then
        return info.prices.rerollAll;
    end
    return nil;
end

local function CurrencyLabel(info, amount)
    local itemId = info.currency.itemId;
    local icon = itemId > 0 and GetItemIcon and GetItemIcon(itemId);
    if icon then
        return string.format("%d |T%s:14:14:0:0|t", amount, icon);
    end
    return string.format("%d %s", amount, info.currency.name ~= "" and info.currency.name or "currency");
end

local function MoneyLabel(copper)
    if GetCoinTextureString then
        return GetCoinTextureString(copper);
    end
    return string.format("%dg %ds %dc", math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100);
end

local function FormatPrice(info, price)
    if not price then
        return "";
    end

    local parts = {};
    if price.amount > 0 then
        parts[#parts + 1] = CurrencyLabel(info, price.amount);
    end
    if price.money > 0 then
        parts[#parts + 1] = MoneyLabel(price.money);
    end
    if #parts == 0 then
        return "Free";
    end
    return table.concat(parts, "  ");
end

local function PlayerMoney(info)
    if GetMoney then
        return GetMoney();
    end
    return info.money;
end

local function CanAfford(info, price)
    return price ~= nil and info.currency.balance >= price.amount and PlayerMoney(info) >= price.money;
end

-- Why nothing can be bought right now, or nil. The second value is true for the standing
-- reasons (no protocol, switched off, combat), which outrank a result message: they are what
-- the greyed-out buttons are telling the player.
local function BlockedReason(info)
    if not GetProtocol() then
        return "The Random Enchants panel needs DC-AddonProtocol.", true;
    end
    if not info.enabled then
        return "Enchant rerolling is switched off on this realm.", true;
    end
    if UnitAffectingCombat and UnitAffectingCombat("player") then
        return "You cannot reroll enchants in combat.", true;
    end
    if Panel.pending then
        return "Waiting for the server...", false;
    end
    return nil, false;
end

local function ItemLabel(item)
    local name = item.name or "the item";
    local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[item.quality or 1];
    if color and color.hex then
        return color.hex .. name .. "|r";
    end
    return name;
end

local function ConfirmText(action, index, item, info)
    local cost = FormatPrice(info, PriceFor(info, action));
    if action == "add" then
        return string.format("Add a random enchant to %s?\n\nCost: %s", ItemLabel(item), cost);
    elseif action == "rerollAll" then
        return string.format("Reroll every enchant line of %s?\n\nAll %d lines are replaced.\n\nCost: %s",
            ItemLabel(item), FilledLines(info), cost);
    end

    local text = info.lines[index].text;
    return string.format("Reroll line %d of %s?\n\n|cff20ff20%s|r\nis replaced by a new random enchant.\n\nCost: %s",
        index, ItemLabel(item), text ~= "" and text or "This enchant", cost);
end

local function HideTooltip()
    GameTooltip:Hide();
end

local function PlayPanelSound(sound)
    if DC.PlaySound then
        DC.PlaySound(sound);
    elseif PlaySound then
        PlaySound(sound);
    end
end

-- After a paid change the upgrade window's own enchant preview (procLines) is stale.
local function RefreshUpgradeWindow()
    local item, bag, slot = GetSelection();
    if item and type(DarkChaos_ItemUpgrade_QueueQuery) == "function" then
        DarkChaos_ItemUpgrade_QueueQuery(bag, slot, {
            type = "selection",
            locationKey = item.locationKey or LocationKey(bag, slot),
        });
    end
end

-- ============================================================================
-- Frame
-- ============================================================================

local function ApplyPanelStyle(frame)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    });
    frame:SetBackdropColor(0, 0, 0, 0);

    -- The dark leather the item and tier browsers use.
    local background = frame:CreateTexture(nil, "BACKGROUND", nil, -8);
    background:SetAllPoints();
    background:SetTexture(BG_FELLEATHER);

    local tint = frame:CreateTexture(nil, "BACKGROUND", nil, -7);
    tint:SetAllPoints(background);
    tint:SetTexture(0, 0, 0, 0.60);
end

local function CreateRow(frame, index)
    local row = CreateFrame("Frame", "DarkChaos_EnchantRerollFrameLine" .. index, frame);
    row:SetWidth(FRAME_WIDTH - 36);
    row:SetHeight(ROW_HEIGHT);
    row:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -92 - (index - 1) * (ROW_HEIGHT + ROW_GAP));

    row.background = row:CreateTexture(nil, "BACKGROUND");
    row.background:SetAllPoints();
    row.background:SetTexture(0, 0, 0, 0.45);

    row.glow = row:CreateTexture(nil, "BORDER");
    row.glow:SetAllPoints();
    row.glow:SetTexture(1.0, 0.82, 0.0, 1.0);
    row.glow:SetBlendMode("ADD");
    row.glow:SetAlpha(0);

    row.number = row:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge");
    row.number:SetPoint("TOPLEFT", row, "TOPLEFT", 12, -8);
    row.number:SetText(tostring(index));

    row.tier = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall");
    row.tier:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 8, 7);

    row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight");
    row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 46, -8);
    row.text:SetWidth(144);
    row.text:SetJustifyH("LEFT");
    row.text:SetJustifyV("TOP");

    row.button = CreateFrame("Button", row:GetName() .. "Button", row, "UIPanelButtonTemplate");
    row.button:SetWidth(86);
    row.button:SetHeight(22);
    row.button:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -7);
    row.button:SetScript("OnClick", function()
        Panel:OnActionClicked(row.action, index);
    end);
    row.button:SetScript("OnEnter", function(button)
        Panel:ShowActionTooltip(button, row.action, index);
    end);
    row.button:SetScript("OnLeave", HideTooltip);

    row.cost = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall");
    row.cost:SetPoint("TOPRIGHT", row.button, "BOTTOMRIGHT", 0, -5);
    row.cost:SetJustifyH("RIGHT");

    return row;
end

function Panel:Create()
    if self.frame then
        return self.frame;
    end

    local main = rawget(_G, "DarkChaos_ItemUpgradeFrame");
    local frame = CreateFrame("Frame", "DarkChaos_EnchantRerollFrame", UIParent);
    frame:SetWidth(FRAME_WIDTH);
    frame:SetHeight(FRAME_HEIGHT);
    if main then
        -- Docked where the item and tier browsers dock; they take turns.
        frame:SetPoint("LEFT", main, "RIGHT", 10, 0);
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0);
    end
    frame:SetToplevel(true);
    frame:SetClampedToScreen(true);
    frame:EnableMouse(true);
    frame:Hide();
    ApplyPanelStyle(frame);
    self.frame = frame;

    frame.title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge");
    frame.title:SetPoint("TOP", frame, "TOP", 0, -16);
    frame.title:SetText("Random Enchants");

    frame.closeButton = CreateFrame("Button", "DarkChaos_EnchantRerollFrameCloseButton", frame, "UIPanelCloseButton");
    frame.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, -3);
    frame.closeButton:SetScript("OnClick", function()
        Panel:Close();
    end);

    frame.itemButton = CreateFrame("Button", "DarkChaos_EnchantRerollFrameItem", frame);
    frame.itemButton:SetWidth(36);
    frame.itemButton:SetHeight(36);
    frame.itemButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -44);
    frame.itemIcon = frame.itemButton:CreateTexture(nil, "ARTWORK");
    frame.itemIcon:SetAllPoints();
    frame.itemButton:SetScript("OnEnter", function(button)
        Panel:ShowItemTooltip(button);
    end);
    frame.itemButton:SetScript("OnLeave", HideTooltip);

    frame.itemName = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal");
    frame.itemName:SetPoint("TOPLEFT", frame.itemButton, "TOPRIGHT", 10, -2);
    frame.itemName:SetWidth(FRAME_WIDTH - 100);
    frame.itemName:SetJustifyH("LEFT");

    frame.itemDetail = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall");
    frame.itemDetail:SetPoint("TOPLEFT", frame.itemName, "BOTTOMLEFT", 0, -4);
    frame.itemDetail:SetWidth(FRAME_WIDTH - 100);
    frame.itemDetail:SetJustifyH("LEFT");

    frame.rows = {};
    for index = 1, MAX_LINES do
        frame.rows[index] = CreateRow(frame, index);
    end

    frame.message = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight");
    frame.message:SetPoint("TOP", frame, "TOP", 0, -132);
    frame.message:SetWidth(FRAME_WIDTH - 60);

    frame.status = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall");
    frame.status:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 94);
    frame.status:SetWidth(FRAME_WIDTH - 44);
    frame.status:SetJustifyH("LEFT");

    frame.rerollAll = CreateFrame("Button", "DarkChaos_EnchantRerollFrameRerollAllButton", frame,
        "UIPanelButtonTemplate");
    frame.rerollAll:SetWidth(120);
    frame.rerollAll:SetHeight(24);
    frame.rerollAll:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 62);
    frame.rerollAll:SetText("Reroll All");
    frame.rerollAll:SetScript("OnClick", function()
        Panel:OnActionClicked("rerollAll");
    end);
    frame.rerollAll:SetScript("OnEnter", function(button)
        Panel:ShowActionTooltip(button, "rerollAll");
    end);
    frame.rerollAll:SetScript("OnLeave", HideTooltip);

    frame.rerollAllCost = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall");
    frame.rerollAllCost:SetPoint("LEFT", frame.rerollAll, "RIGHT", 10, 0);

    frame.hint = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall");
    frame.hint:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 44);
    frame.hint:SetWidth(FRAME_WIDTH - 44);
    frame.hint:SetJustifyH("LEFT");

    frame.balance = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall");
    frame.balance:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 24);
    frame.balance:SetWidth(FRAME_WIDTH - 44);
    frame.balance:SetJustifyH("LEFT");

    frame:SetScript("OnShow", function()
        Panel:OnShow();
    end);
    frame:SetScript("OnHide", function()
        Panel:OnHide();
    end);
    frame:SetScript("OnUpdate", function(_, elapsed)
        Panel:OnUpdate(elapsed);
    end);
    frame:SetScript("OnEvent", function(_, event)
        Panel:OnEvent(event);
    end);
    frame:RegisterEvent("PLAYER_REGEN_DISABLED");
    frame:RegisterEvent("PLAYER_REGEN_ENABLED");
    frame:RegisterEvent("PLAYER_MONEY");
    frame:RegisterEvent("BAG_UPDATE");

    if UISpecialFrames then
        tinsert(UISpecialFrames, frame:GetName());
    end

    return frame;
end

-- ============================================================================
-- Rendering
-- ============================================================================

function Panel:SetStatus(text, r, g, b)
    if text then
        self.status = { text = text, r = r or 1, g = g or 0.82, b = b or 0, expires = GetTime() + STATUS_SECONDS };
    else
        self.status = nil;
    end
end

function Panel:ApplyGlow()
    local frame = self.frame;
    if not frame then
        return;
    end
    for index = 1, MAX_LINES do
        local remaining = self.flash[index];
        frame.rows[index].glow:SetAlpha(remaining and 0.35 * remaining / FLASH_SECONDS or 0);
    end
end

function Panel:RenderHeader(item, info)
    local frame = self.frame;
    if not item then
        frame.itemIcon:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot");
        frame.itemName:SetText("No item selected");
        frame.itemName:SetTextColor(0.6, 0.6, 0.6);
        frame.itemDetail:SetText("");
        return;
    end

    frame.itemIcon:SetTexture(item.texture or "Interface\\Icons\\INV_Misc_QuestionMark");
    frame.itemName:SetText(item.name or item.link);
    local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[item.quality or 1];
    if color then
        frame.itemName:SetTextColor(color.r, color.g, color.b);
    else
        frame.itemName:SetTextColor(1, 1, 1);
    end

    if info and info.success and info.eligible then
        frame.itemDetail:SetText(string.format("%d of %d enchant lines", FilledLines(info), info.maxLines));
    else
        frame.itemDetail:SetText("");
    end
end

local function HideLines(frame)
    for index = 1, MAX_LINES do
        frame.rows[index]:Hide();
        frame.rows[index].action = nil;
    end
    frame.rerollAll:Hide();
    frame.rerollAllCost:Hide();
    frame.hint:SetText("");
end

local function SetButtonState(button, costText, info, price, blocked)
    local affordable = CanAfford(info, price);
    costText:SetText(FormatPrice(info, price));
    if price and not affordable then
        costText:SetTextColor(1.0, 0.25, 0.25);
    else
        costText:SetTextColor(1.0, 1.0, 1.0);
    end

    if blocked or not affordable then
        button:Disable();
    else
        button:Enable();
    end
end

function Panel:RenderLines(info)
    local frame = self.frame;
    local blocked, standing = BlockedReason(info);
    local freeLine = FirstFreeLine(info);

    for index = 1, MAX_LINES do
        local row = frame.rows[index];
        local line = info.lines[index];
        local filled = line.enchantId > 0;

        -- A line past MaxEnchantsPerItem is shown while it still holds an enchant (the limit
        -- was lowered after it was rolled) but offers nothing.
        if index > info.maxLines and not filled then
            row:Hide();
            row.action = nil;
        else
            row:Show();
            if filled then
                row.text:SetText(line.text ~= "" and line.text or ("Enchant #" .. line.enchantId));
                row.text:SetTextColor(0.12, 1.0, 0.12);
                row.tier:SetText(line.tier > 0 and ("Tier " .. line.tier) or "");
            else
                row.text:SetText("Empty");
                row.text:SetTextColor(0.5, 0.5, 0.5);
                row.tier:SetText("");
            end

            local action;
            if filled and index <= info.maxLines then
                action = "reroll";
            elseif not filled and index == freeLine and info.allowAdd then
                action = "add";
            end

            row.action = action;
            if action and PriceFor(info, action) then
                row.button:SetText(action == "add" and "Add" or "Reroll");
                row.button:Show();
                row.cost:Show();
                SetButtonState(row.button, row.cost, info, PriceFor(info, action), blocked);
            else
                row.button:Hide();
                row.cost:Hide();
            end
        end
    end

    local allPrice = info.prices.rerollAll;
    if info.allowRerollAll and allPrice and FilledLines(info) >= 2 then
        frame.rerollAll:Show();
        frame.rerollAllCost:Show();
        SetButtonState(frame.rerollAll, frame.rerollAllCost, info, allPrice, blocked);
    else
        frame.rerollAll:Hide();
        frame.rerollAllCost:Hide();
    end

    if info.costIncrease > 0 and info.rerollCount > 0 then
        frame.hint:SetText(string.format("Rerolled %d time%s. Every reroll makes the next one on this item dearer.",
            info.rerollCount, info.rerollCount == 1 and "" or "s"));
    elseif info.costIncrease > 0 then
        frame.hint:SetText("Every reroll makes the next one on this item dearer.");
    else
        frame.hint:SetText("");
    end

    return blocked, standing;
end

function Panel:Render()
    local frame = self.frame;
    if not frame or not frame:IsShown() then
        return;
    end

    local item = GetSelection();
    local info = self.info;
    self:RenderHeader(item, info);

    local message;
    if not GetProtocol() then
        message = "The Random Enchants panel needs DC-AddonProtocol.";
    elseif not item then
        message = "Select an item in the upgrade window to see its random enchants.";
    elseif not info then
        message = self.infoRequestedAt and "Loading enchant lines..."
            or "No answer from the server. Select the item again to retry.";
    elseif not info.success then
        message = info.error ~= "" and info.error or "This item could not be read.";
    elseif not info.eligible then
        message = info.reason ~= "" and info.reason or "This item cannot hold random enchants.";
    end

    local blocked, standing;
    if message then
        HideLines(frame);
        frame.message:SetText(message);
        frame.message:Show();
    else
        frame.message:Hide();
        blocked, standing = self:RenderLines(info);
    end

    if info and info.success and info.eligible then
        local balance = "You have " .. CurrencyLabel(info, info.currency.balance);
        for _, price in pairs(info.prices) do
            if price.money > 0 then
                balance = balance .. "  " .. MoneyLabel(PlayerMoney(info));
                break;
            end
        end
        frame.balance:SetText(balance);
    else
        frame.balance:SetText("");
    end

    -- Why the buttons are grey right now comes first, then the last result or warning, then
    -- the wait for an answer.
    local status = self.status;
    if blocked and standing then
        frame.status:SetText(blocked);
        frame.status:SetTextColor(1.0, 0.82, 0.0);
    elseif status then
        frame.status:SetText(status.text);
        frame.status:SetTextColor(status.r, status.g, status.b);
    elseif blocked then
        frame.status:SetText(blocked);
        frame.status:SetTextColor(1.0, 0.82, 0.0);
    else
        frame.status:SetText("");
    end

    if self.button then
        self.button:LockHighlight();
    end
end

-- ============================================================================
-- Tooltips
-- ============================================================================

function Panel:ShowItemTooltip(owner)
    local item = GetSelection();
    if not item then
        return;
    end

    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT");
    if item.isEquipped and item.slot then
        GameTooltip:SetInventoryItem("player", item.slot);
    elseif item.bag ~= nil and item.slot ~= nil and item.bag >= 0 then
        GameTooltip:SetBagItem(item.bag, item.slot);
    else
        GameTooltip:SetHyperlink(item.link);
    end
    GameTooltip:Show();
end

function Panel:ShowActionTooltip(owner, action, index)
    local info = self.info;
    if not info or not action then
        return;
    end

    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT");
    if action == "add" then
        GameTooltip:SetText("Add an enchant line", 1, 1, 1);
        GameTooltip:AddLine("Rolls a new random enchant into this empty line.", 0.8, 0.8, 0.8, true);
    elseif action == "rerollAll" then
        GameTooltip:SetText("Reroll every line", 1, 1, 1);
        GameTooltip:AddLine("Replaces every enchant line of this item at once.", 0.8, 0.8, 0.8, true);
    else
        GameTooltip:SetText("Reroll line " .. tostring(index), 1, 1, 1);
        GameTooltip:AddLine("Replaces this enchant with a new random one of the same tier. "
            .. "The other lines are kept.", 0.8, 0.8, 0.8, true);
    end

    local price = PriceFor(info, action);
    GameTooltip:AddLine("Cost: " .. FormatPrice(info, price), 1, 1, 1);
    if price and not CanAfford(info, price) then
        GameTooltip:AddLine("You cannot afford this.", 1.0, 0.25, 0.25);
    end
    GameTooltip:AddLine("Shift-click to skip the confirmation.", 0.5, 0.5, 0.5);
    GameTooltip:Show();
end

-- ============================================================================
-- Actions
-- ============================================================================

function Panel:OnActionClicked(action, index)
    local info = self.info;
    local item, bag, slot = GetSelection();
    if not action or not info or not item or not PriceFor(info, action) or BlockedReason(info) then
        return;
    end

    local request = {
        action = action,
        line = action == "rerollAll" and 0 or (index or 1) - 1,
        bag = bag,
        slot = slot,
        expected = ExpectedLines(info),
    };

    if IsShiftKeyDown and IsShiftKeyDown() then
        self:Send(request);
        return;
    end

    StaticPopup_Show(POPUP, ConfirmText(action, index, item, info), nil, request);
end

function Panel:Send(request)
    local protocol = GetProtocol();
    if not protocol or type(request) ~= "table" or self.pending then
        return;
    end

    -- The confirmation may have stayed open while new lines arrived.
    local item, bag, slot = GetSelection();
    if not item or not self.info or LocationKey(bag, slot) ~= LocationKey(request.bag, request.slot)
            or not SameLines(ExpectedLines(self.info), request.expected) then
        self:SetStatus("The item changed. Check its lines and try again.");
        self:Render();
        return;
    end

    self.pending = { request = request, sentAt = GetTime() };
    self:SetStatus(nil);
    protocol:Request(MODULE, CMSG_DO_ENCHANT_REROLL, {
        bag = request.bag,
        slot = request.slot,
        action = request.action,
        line = request.line,
        expected = request.expected,
    });
    self:Render();
end

function Panel:RequestInfo()
    local key = SelectionKey();
    if key ~= self.infoKey then
        -- Another item: nothing shown so far belongs to it.
        self.info = nil;
        self.infoKey = nil;
        self.flash = {};
        self:SetStatus(nil);
    end
    self.requestedKey = key;
    self.refreshAt = nil;

    local item, bag, slot = GetSelection();
    local protocol = GetProtocol();
    if item and protocol then
        self.infoRequestedAt = GetTime();
        protocol:Request(MODULE, CMSG_GET_ENCHANT_INFO, { bag = bag, slot = slot });
    else
        self.infoRequestedAt = nil;
    end
    self:Render();
end

function Panel:OnInfo(data)
    if type(data) ~= "table" then
        return;
    end

    local item, bag, slot = GetSelection();
    if not item or LocationKey(tonumber(data.bag), tonumber(data.slot)) ~= LocationKey(bag, slot) then
        return; -- about an item the window no longer shows
    end

    self.infoRequestedAt = nil;
    local entry = tonumber(data.itemEntry);
    local selectedEntry = tonumber(item.itemEntry or item.itemID);
    if data.success ~= false and entry and selectedEntry and entry ~= selectedEntry then
        self.info = NormalizeInfo({
            success = false,
            error = "Another item is in that slot now. Select the item again.",
        });
    else
        self.info = NormalizeInfo(data);
    end
    self.infoKey = SelectionKey();
    self:Render();
end

function Panel:OnResult(data)
    if type(data) ~= "table" then
        return;
    end

    self.pending = nil;
    local _, bag, slot = GetSelection();
    local sameItem = bag ~= nil and LocationKey(tonumber(data.bag), tonumber(data.slot)) == LocationKey(bag, slot);

    if data.success then
        PlayPanelSound("LootWindowCoinSound");
        self:SetStatus(nil);
        if sameItem and type(data.before) == "table" and type(data.after) == "table" then
            for index = 1, MAX_LINES do
                if (tonumber(data.before[index]) or 0) ~= (tonumber(data.after[index]) or 0) then
                    self.flash[index] = FLASH_SECONDS;
                end
            end
            self:ApplyGlow();
            RefreshUpgradeWindow();
        end
    else
        local text = type(data.error) == "string" and data.error ~= "" and data.error or "The reroll failed.";
        PlayPanelSound("igQuestFailed");
        self:SetStatus(text, 1.0, 0.25, 0.25);
        if UIErrorsFrame then
            UIErrorsFrame:AddMessage(text, 1.0, 0.1, 0.1, 1.0, UIERRORS_HOLD_TIME);
        end
    end

    -- The server follows every result with a fresh ENCHANT_INFO.
    self:Render();
end

-- ============================================================================
-- Show / hide and updates
-- ============================================================================

-- The browsers that dock where the panel docks, with the button handler that toggles each
-- (it also keeps the footer button's highlight right).
local BROWSERS = {
    { frame = "DarkChaos_ItemBrowserFrame", toggle = "DarkChaos_ItemUpgrade_BrowseButton_OnClick" },
    { frame = "DarkChaos_TierBrowserFrame", toggle = "DarkChaos_ItemUpgrade_TierBrowseButton_OnClick" },
};

function Panel:Show()
    local frame = self:Create();
    for _, browser in ipairs(BROWSERS) do
        local browserFrame = rawget(_G, browser.frame);
        if browserFrame and browserFrame:IsShown() then
            local toggle = rawget(_G, browser.toggle);
            if type(toggle) == "function" then
                toggle();
            end
            if browserFrame:IsShown() then
                browserFrame:Hide();
            end
        end
    end
    frame:Show();
end

-- Closed by the player (button, close box): unlike being pushed aside by a browser, it does
-- not come back when that browser closes.
function Panel:Close()
    self.restoreAfter = nil;
    if self.frame then
        self.frame:Hide();
    end
end

function Panel:Toggle()
    if self.frame and self.frame:IsShown() then
        self:Close();
    else
        self.restoreAfter = nil;
        self:Show();
    end
end

function Panel:OnShow()
    PlayPanelSound("igCharacterInfoTab");
    self:RequestInfo();
    if self.button then
        self.button:LockHighlight();
    end
end

function Panel:OnHide()
    if StaticPopup_Hide then
        StaticPopup_Hide(POPUP);
    end
    self.flash = {};
    self:ApplyGlow();
    if self.button then
        self.button:UnlockHighlight();
    end
end

function Panel:OnBrowserShown(browserFrame)
    if self.frame and self.frame:IsShown() then
        self.restoreAfter = browserFrame;
        self.frame:Hide();
    end
end

function Panel:OnBrowserHidden(browserFrame)
    if self.restoreAfter ~= browserFrame then
        return;
    end
    self.restoreAfter = nil;
    local main = rawget(_G, "DarkChaos_ItemUpgradeFrame");
    if not main or main:IsShown() then
        self:Show();
    end
end

function Panel:OnEvent(event)
    if not self.frame or not self.frame:IsShown() then
        return;
    end

    if event == "BAG_UPDATE" or event == "PLAYER_MONEY" then
        -- Looting fires BAG_UPDATE in bursts; one refresh for the burst keeps the balance true.
        self.refreshAt = self.refreshAt or (GetTime() + REFRESH_DELAY);
    else
        self:Render();
    end
end

function Panel:OnUpdate(elapsed)
    local now = GetTime();

    if next(self.flash) then
        for index, remaining in pairs(self.flash) do
            self.flash[index] = remaining > elapsed and remaining - elapsed or nil;
        end
        self:ApplyGlow();
    end

    if self.status and now >= self.status.expires then
        self.status = nil;
        self:Render();
    end

    if self.pending and now - self.pending.sentAt > REQUEST_TIMEOUT then
        self.pending = nil;
        self:SetStatus("No answer from the server. Check the lines before trying again.", 1.0, 0.25, 0.25);
        self:RequestInfo();
        return;
    end

    if self.infoRequestedAt and now - self.infoRequestedAt > REQUEST_TIMEOUT then
        self.infoRequestedAt = nil;
        self:Render();
    end

    self.sinceSelectionCheck = (self.sinceSelectionCheck or 0) + elapsed;
    if self.sinceSelectionCheck >= SELECTION_POLL then
        self.sinceSelectionCheck = 0;
        if SelectionKey() ~= self.requestedKey then
            self:RequestInfo();
            return;
        end
    end

    if self.refreshAt and now >= self.refreshAt and not self.pending then
        self:RequestInfo();
    end
end

-- ============================================================================
-- Wiring
-- ============================================================================

function Panel:SyncButton()
    local button = self.button;
    if not button then
        return;
    end

    -- Shown with the Items / Tiers buttons: the heirloom package picker hides them all.
    local main = rawget(_G, "DarkChaos_ItemUpgradeFrame");
    local partner = main and main.TierBrowseButton;
    if not partner or partner:IsShown() then
        button:Show();
    else
        button:Hide();
    end
end

local function AttachToUpgradeFrame()
    local main = rawget(_G, "DarkChaos_ItemUpgradeFrame");
    if not main or Panel.button then
        return;
    end

    -- A third button beside Items / Tiers would run under the Upgrade button, so it takes
    -- the free strip above them, spanning both.
    local button = CreateFrame("Button", "DarkChaos_ItemUpgradeFrameEnchantsButton", main, "UIPanelButtonTemplate");
    button:SetHeight(22);
    local browse = main.BrowseButton;
    if browse then
        button:SetWidth(browse:GetWidth() * 2 + 4);
        button:SetPoint("BOTTOMLEFT", browse, "TOPLEFT", 0, 4);
    else
        button:SetWidth(156);
        button:SetPoint("BOTTOMLEFT", main, "BOTTOMLEFT", 24, 46);
    end
    button:SetFrameLevel(main:GetFrameLevel() + 6);
    button:SetText("Random Enchants");
    local label = button:GetFontString();
    if label then
        label:SetFontObject(GameFontHighlightSmall);
        label:SetTextColor(1, 1, 1);
    end
    button:SetScript("OnClick", function()
        Panel:Toggle();
    end);
    button:SetScript("OnEnter", function(widget)
        GameTooltip:SetOwner(widget, "ANCHOR_TOPLEFT");
        GameTooltip:SetText("Random Enchants", 1, 1, 1);
        GameTooltip:AddLine("Reroll or add random enchant lines on the selected item.", 0.8, 0.8, 0.8, true);
        GameTooltip:Show();
    end);
    button:SetScript("OnLeave", HideTooltip);
    Panel.button = button;

    main:HookScript("OnHide", function()
        Panel:Close();
    end);

    if main.TierBrowseButton then
        main.TierBrowseButton:HookScript("OnShow", function()
            Panel:SyncButton();
        end);
        main.TierBrowseButton:HookScript("OnHide", function()
            Panel:SyncButton();
        end);
    end

    for _, browser in ipairs(BROWSERS) do
        local browserFrame = rawget(_G, browser.frame);
        if browserFrame then
            browserFrame:HookScript("OnShow", function()
                Panel:OnBrowserShown(browserFrame);
            end);
            browserFrame:HookScript("OnHide", function()
                Panel:OnBrowserHidden(browserFrame);
            end);
        end
    end

    Panel:SyncButton();
end

local function RegisterProtocolHandlers()
    local protocol = GetProtocol();
    if not protocol or type(protocol.RegisterHandler) ~= "function" or Panel.handlersRegistered then
        return;
    end

    Panel.handlersRegistered = true;
    protocol:RegisterHandler(MODULE, SMSG_ENCHANT_INFO, function(data)
        Panel:OnInfo(data);
    end);
    protocol:RegisterHandler(MODULE, SMSG_ENCHANT_RESULT, function(data)
        Panel:OnResult(data);
    end);
end

if StaticPopupDialogs then
    StaticPopupDialogs[POPUP] = {
        text = "%s",
        button1 = ACCEPT or "Accept",
        button2 = CANCEL or "Cancel",
        OnAccept = function(_, request)
            Panel:Send(request);
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
    };
end

SLASH_DCENCHANTS1 = "/dcenchants";
SLASH_DCENCHANTS2 = "/dcreroll";
SlashCmdList["DCENCHANTS"] = function()
    local main = rawget(_G, "DarkChaos_ItemUpgradeFrame");
    if main and not main:IsShown() then
        if not DC.ToggleUpgradeFrame or not DC.ToggleUpgradeFrame("STANDARD") then
            return;
        end
    end
    Panel.restoreAfter = nil;
    Panel:Show();
end;

RegisterProtocolHandlers();
AttachToUpgradeFrame();
