--[[
    DC-ItemUpgrade - Transmutation UI
    Handles the client-side logic for the Transmutation system.
    
    Author: DarkChaos Development Team
    Date: November 2025
]]

-- Namespace
DarkChaos_ItemUpgrade = DarkChaos_ItemUpgrade or {};
local DC = DarkChaos_ItemUpgrade;

-- Constants
local MODULE = "UPG";
local OPCODE_CMSG_GET_TRANSMUTE_INFO = 0x20;
local OPCODE_CMSG_DO_TRANSMUTE       = 0x21;

local OPCODE_SMSG_TRANSMUTE_INFO     = 0x30;
local OPCODE_SMSG_TRANSMUTE_RESULT   = 0x31;
local OPCODE_SMSG_OPEN_TRANSMUTE_UI  = 0x32;

-- Currency ids -- must match CurrencyType in ItemUpgradeManager.h.
local CURRENCY_TOKEN   = 1;
local CURRENCY_ESSENCE = 2;
local CURRENCY_SAP     = 3;

local CURRENCY_NAME = {
    [CURRENCY_TOKEN]   = "Upgrade Tokens",
    [CURRENCY_ESSENCE] = "Artifact Essence",
    [CURRENCY_SAP]     = "Emberwood Sap",
};

local CURRENCY_COLOR = {
    [CURRENCY_TOKEN]   = "|cffffffff",
    [CURRENCY_ESSENCE] = "|cff00ccff",
    [CURRENCY_SAP]     = "|cffff8800",
};

-- Order the dropdowns list currencies in.
local CURRENCY_ORDER = { CURRENCY_TOKEN, CURRENCY_ESSENCE, CURRENCY_SAP };

-- Variables
-- Rate rows straight from the server: { from, to, give, get }. The UI never
-- invents a rate; a pair with no row here is not offered, so what the window
-- quotes is always what the server will charge.
local exchangeRates = {};
local balances = { [CURRENCY_TOKEN] = 0, [CURRENCY_ESSENCE] = 0, [CURRENCY_SAP] = 0 };
local selectedFrom = CURRENCY_TOKEN;
local selectedTo = CURRENCY_ESSENCE;
local currentStatus = {};

local BG_FELLEATHER = "Interface\\DC\\Shared\\FelLeather_512.tga";
local BG_TINT_ALPHA = 0.60;

-- Refresh `balances` from the best source available, in priority order:
-- the server's own SMSG_TRANSMUTE_INFO figures (already stored by ParseInfo),
-- then the shared DCAddonProtocol balance, then DC-ItemUpgrade's own cache.
-- Sap has no entry in the shared protocol getter, so it comes from the payload
-- or from the upgrade tab's DC.playerSap.
local function RefreshCurrencyBalances()
    local tokens, essence
    local central = rawget(_G, "DCAddonProtocol")
    if central then
        local tokenItemId = tonumber(central.TOKEN_ITEM_ID) or 0
        local essenceItemId = tonumber(central.ESSENCE_ITEM_ID) or 0
        local getter = central.GetServerCurrencyBalance or central.GetCurrencyBalance or central.GetCurrencyBalances
        if type(getter) == "function" then
            local ok, a, b = pcall(getter, central)
            if ok then
                if type(a) == "table" then
                    local byItem = a.byItemId or a.by_item_id
                    tokens = a.tokens or a.token or (tokenItemId > 0 and byItem and byItem[tokenItemId])
                    essence = a.emblems or a.essence or (essenceItemId > 0 and byItem and byItem[essenceItemId])
                else
                    tokens = a
                    essence = b
                end
            end
        end
    end

    -- balances[] already holds the server payload when one has arrived; only
    -- overwrite an entry we have nothing authoritative for.
    if balances[CURRENCY_TOKEN] == 0 then
        balances[CURRENCY_TOKEN] = tonumber(tokens) or DC.playerTokens or 0;
    end
    if balances[CURRENCY_ESSENCE] == 0 then
        balances[CURRENCY_ESSENCE] = tonumber(essence) or DC.playerEssence or 0;
    end
    if balances[CURRENCY_SAP] == 0 then
        balances[CURRENCY_SAP] = tonumber(DC.playerSap) or 0;
    end
end

-- The give/get row for a pair, or nil when the server does not offer it.
local function FindRate(from, to)
    for _, rate in ipairs(exchangeRates) do
        if rate.from == from and rate.to == to then
            return rate;
        end
    end
    return nil;
end

-- Every currency the selected source can be converted into.
local function GetValidTargets(from)
    local targets = {};
    for _, currency in ipairs(CURRENCY_ORDER) do
        if currency ~= from and FindRate(from, currency) then
            table.insert(targets, currency);
        end
    end
    return targets;
end

-- What `sourceAmount` actually buys. Mirrors the server exactly: whole trades
-- only, no fee. Returns spend, receive.
local function ComputeExchange(from, to, sourceAmount)
    local rate = FindRate(from, to);
    if not rate or rate.give <= 0 or sourceAmount <= 0 then
        return 0, 0;
    end

    local trades = math.floor(sourceAmount / rate.give);
    if trades <= 0 then
        return 0, 0;
    end

    return trades * rate.give, trades * rate.get;
end

local function ApplyLeaderboardsStyle(frame)
    if not frame or frame.__dcLeaderboardsStyled then
        return
    end
    frame.__dcLeaderboardsStyled = true

    if frame.SetBackdropColor then
        frame:SetBackdropColor(0, 0, 0, 0)
    end

    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints()
    bg:SetTexture(BG_FELLEATHER)

    local tint = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    tint:SetAllPoints(bg)
    tint:SetTexture(0, 0, 0, BG_TINT_ALPHA)
end

-- ============================================================================
-- Initialization
-- ============================================================================

function DarkChaos_Transmutation_OnLoad(self)
    self:RegisterForDrag("LeftButton");

    ApplyLeaderboardsStyle(self);
    
    -- Register with DCAddonProtocol if available
    local DCProtocol = rawget(_G, "DCAddonProtocol");
    if DCProtocol then
        DCProtocol:RegisterHandler(MODULE, OPCODE_SMSG_OPEN_TRANSMUTE_UI, function(data)
            DarkChaos_Transmutation_Show();
        end);
        
        DCProtocol:RegisterHandler(MODULE, OPCODE_SMSG_TRANSMUTE_INFO, function(data)
            DarkChaos_Transmutation_ParseInfo(data);
        end);
        
        DCProtocol:RegisterHandler(MODULE, OPCODE_SMSG_TRANSMUTE_RESULT, function(data)
            DarkChaos_Transmutation_ParseResult(data);
        end);
    end
    
    DarkChaos_Transmutation_InitDropdowns();
    DarkChaos_Transmutation_ShowTab(1);
end

-- ============================================================================
-- Currency dropdowns
-- ============================================================================

-- Keep the pair legal: if the current target is not reachable from the current
-- source, drop to the first one that is. Called after every selection and after
-- every rate refresh, since the server can retire a pair at any time.
function DarkChaos_Transmutation_NormalizeSelection()
    if selectedFrom == selectedTo or not FindRate(selectedFrom, selectedTo) then
        local targets = GetValidTargets(selectedFrom);
        selectedTo = targets[1];
    end
end

function DarkChaos_Transmutation_InitDropdowns()
    local frame = DarkChaos_TransmutationFrame.ExchangeFrame;

    UIDropDownMenu_SetWidth(frame.FromDropdown, 130);
    UIDropDownMenu_Initialize(frame.FromDropdown, function()
        for _, currency in ipairs(CURRENCY_ORDER) do
            -- Only offer a source that can actually go somewhere.
            if # GetValidTargets(currency) > 0 then
                local info = UIDropDownMenu_CreateInfo();
                info.text = CURRENCY_NAME[currency];
                info.value = currency;
                info.notCheckable = true;
                info.func = function()
                    selectedFrom = currency;
                    DarkChaos_Transmutation_NormalizeSelection();
                    CloseDropDownMenus();
                    DarkChaos_Transmutation_UpdateExchangeTab();
                end;
                UIDropDownMenu_AddButton(info);
            end
        end
    end);

    UIDropDownMenu_SetWidth(frame.ToDropdown, 130);
    UIDropDownMenu_Initialize(frame.ToDropdown, function()
        for _, currency in ipairs(GetValidTargets(selectedFrom)) do
            local info = UIDropDownMenu_CreateInfo();
            info.text = CURRENCY_NAME[currency];
            info.value = currency;
            info.notCheckable = true;
            info.func = function()
                selectedTo = currency;
                CloseDropDownMenus();
                DarkChaos_Transmutation_UpdateExchangeTab();
            end;
            UIDropDownMenu_AddButton(info);
        end
    end);
end

function DarkChaos_Transmutation_OnShow()
    PlaySound("AuctionWindowOpen");
    DarkChaos_Transmutation_RequestInfo();
end

function DarkChaos_Transmutation_RequestInfo()
    local DCProtocol = rawget(_G, "DCAddonProtocol");
    if DCProtocol then
        DCProtocol:Request(MODULE, OPCODE_CMSG_GET_TRANSMUTE_INFO, {});
    end
end

-- ============================================================================
-- Data Parsing
-- ============================================================================

function DarkChaos_Transmutation_ParseInfo(data)
    if type(data) ~= "table" then return; end

    if data.exchange then
        local ex = data.exchange;

        -- Rate table. Rebuilt wholesale rather than merged: a pair the server
        -- has stopped offering must disappear from the dropdowns too.
        if type(ex.rates) == "table" then
            exchangeRates = {};
            for _, row in ipairs(ex.rates) do
                local from = tonumber(row.from);
                local to = tonumber(row.to);
                local give = tonumber(row.give);
                local get = tonumber(row.get);
                if from and to and give and get and give > 0 and get > 0 then
                    table.insert(exchangeRates, { from = from, to = to, give = give, get = get });
                end
            end
        elseif ex.tokensToEssence or ex.essenceToTokens then
            -- Server predates the rate table: synthesise the two legacy pairs so
            -- the window still works instead of showing an empty dropdown.
            exchangeRates = {
                { from = CURRENCY_TOKEN, to = CURRENCY_ESSENCE, give = tonumber(ex.tokensToEssence) or 2, get = 1 },
                { from = CURRENCY_ESSENCE, to = CURRENCY_TOKEN, give = 1, get = tonumber(ex.essenceToTokens) or 1 },
            };
        end

        if type(ex.balances) == "table" then
            balances[CURRENCY_TOKEN] = tonumber(ex.balances.tokens) or 0;
            balances[CURRENCY_ESSENCE] = tonumber(ex.balances.essence) or 0;
            balances[CURRENCY_SAP] = tonumber(ex.balances.sap) or 0;
        end
    end

    -- Parse Status
    if data.session then
        currentStatus = data.session;
    end

    DarkChaos_Transmutation_NormalizeSelection();
    DarkChaos_Transmutation_UpdateUI();
end

function DarkChaos_Transmutation_ParseResult(data)
    if type(data) ~= "table" then return; end
    
    local success = data.success;
    local message = data.message or "";
    
    if success then
        PlaySound("LootWindowCoinSound");
        UIErrorsFrame:AddMessage(message, 0.0, 1.0, 0.0, 1.0, UIERRORS_HOLD_TIME);
    else
        PlaySound("igQuestFailed");
        UIErrorsFrame:AddMessage(message, 1.0, 0.0, 0.0, 1.0, UIERRORS_HOLD_TIME);
    end
    
    -- Refresh info
    DarkChaos_Transmutation_RequestInfo();
end

-- ============================================================================
-- UI Logic
-- ============================================================================

function DarkChaos_Transmutation_ShowTab(tabId)
    local frame = DarkChaos_TransmutationFrame;
    frame.ExchangeFrame:Show();
    -- frame.SynthesisFrame:Hide();
    
    if tabId == 1 then
        frame.ExchangeFrame:Show();
        DarkChaos_Transmutation_UpdateExchangeTab();
    end
end

function DarkChaos_Transmutation_UpdateUI()
    if DarkChaos_TransmutationFrame.ExchangeFrame:IsShown() then
        DarkChaos_Transmutation_UpdateExchangeTab();
    end
end

function DarkChaos_Transmutation_UpdateExchangeCalculations()
    local frame = DarkChaos_TransmutationFrame.ExchangeFrame;
    local amount = tonumber(frame.AmountInput:GetText()) or 0;

    if not selectedTo then
        frame.PreviewText:SetText("|cffff4444No conversion available for that currency.|r");
        frame.ExchangeBtn:Disable();
        return;
    end

    local spend, receive = ComputeExchange(selectedFrom, selectedTo, amount);
    local rate = FindRate(selectedFrom, selectedTo);

    if spend <= 0 then
        frame.PreviewText:SetText(string.format(
            "|cffff4444Enter at least %d %s.|r",
            rate and rate.give or 1, CURRENCY_NAME[selectedFrom] or "?"));
        frame.ExchangeBtn:Disable();
        return;
    end

    local affordable = (balances[selectedFrom] or 0) >= spend;

    local remainder = amount - spend;
    local remainderText = "";
    if remainder > 0 then
        remainderText = string.format("\n|cff888888%d %s left over -- trades are whole units of %d.|r",
            remainder, CURRENCY_NAME[selectedFrom] or "?", rate.give);
    end

    frame.PreviewText:SetText(string.format("%s%d %s|r  |cffffd700->|r  %s%d %s|r%s",
        affordable and (CURRENCY_COLOR[selectedFrom] or "|cffffffff") or "|cffff4444",
        spend, CURRENCY_NAME[selectedFrom] or "?",
        CURRENCY_COLOR[selectedTo] or "|cffffffff",
        receive, CURRENCY_NAME[selectedTo] or "?",
        remainderText));

    if affordable then
        frame.ExchangeBtn:Enable();
    else
        frame.ExchangeBtn:Disable();
    end
end

-- Exchange Tab
function DarkChaos_Transmutation_UpdateExchangeTab()
    local frame = DarkChaos_TransmutationFrame.ExchangeFrame;

    RefreshCurrencyBalances();
    DarkChaos_Transmutation_NormalizeSelection();

    frame.BalanceText:SetText(string.format("%s%d Tokens|r   %s%d Essence|r   %s%d Sap|r",
        CURRENCY_COLOR[CURRENCY_TOKEN], balances[CURRENCY_TOKEN] or 0,
        CURRENCY_COLOR[CURRENCY_ESSENCE], balances[CURRENCY_ESSENCE] or 0,
        CURRENCY_COLOR[CURRENCY_SAP], balances[CURRENCY_SAP] or 0));

    UIDropDownMenu_SetText(frame.FromDropdown, CURRENCY_NAME[selectedFrom] or "?");
    UIDropDownMenu_SetText(frame.ToDropdown, selectedTo and CURRENCY_NAME[selectedTo] or "--");

    -- Full rate list at the bottom, so the whole economy is visible without
    -- cycling both dropdowns.
    local lines = {};
    for _, rate in ipairs(exchangeRates) do
        table.insert(lines, string.format("%d %s = %d %s",
            rate.give, CURRENCY_NAME[rate.from] or "?",
            rate.get, CURRENCY_NAME[rate.to] or "?"));
    end
    frame.RateText:SetText(table.concat(lines, "\n"));

    DarkChaos_Transmutation_UpdateExchangeCalculations();
end

-- Fill the amount box with the largest whole number of trades the player can
-- afford.
function DarkChaos_Transmutation_FillMax()
    local rate = selectedTo and FindRate(selectedFrom, selectedTo);
    if not rate or rate.give <= 0 then return; end

    local trades = math.floor((balances[selectedFrom] or 0) / rate.give);
    DarkChaos_TransmutationFrame.ExchangeFrame.AmountInput:SetText(tostring(trades * rate.give));
end

function DarkChaos_Transmutation_DoExchange()
    local amountInput = DarkChaos_TransmutationFrame.ExchangeFrame.AmountInput;
    local amount = tonumber(amountInput:GetText()) or 0;

    if not selectedTo then
        UIErrorsFrame:AddMessage("Pick a currency to receive.", 1.0, 0.0, 0.0, 1.0, UIERRORS_HOLD_TIME);
        return;
    end

    local spend = ComputeExchange(selectedFrom, selectedTo, amount);
    if spend <= 0 then
        UIErrorsFrame:AddMessage("Please enter a valid amount.", 1.0, 0.0, 0.0, 1.0, UIERRORS_HOLD_TIME);
        return;
    end

    if (balances[selectedFrom] or 0) < spend then
        UIErrorsFrame:AddMessage("Not enough " .. (CURRENCY_NAME[selectedFrom] or "currency") .. ".",
            1.0, 0.0, 0.0, 1.0, UIERRORS_HOLD_TIME);
        return;
    end

    local DCProtocol = rawget(_G, "DCAddonProtocol");
    if DCProtocol then
        -- Send the floored spend, not the raw box contents, so the server sees
        -- exactly the trade the player was shown.
        DCProtocol:Request(MODULE, OPCODE_CMSG_DO_TRANSMUTE, {
            action = "exchange",
            from = selectedFrom,
            to = selectedTo,
            amount = spend,
        });
    end
end

function DarkChaos_Transmutation_Show()
    DarkChaos_TransmutationFrame:Show();
    DarkChaos_Transmutation_RequestInfo();
end
