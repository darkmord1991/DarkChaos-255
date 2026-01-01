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

-- Variables
local currentExchangeRates = { tokensToEssence = 100, essenceToTokens = 80 };
local currentStatus = {};

local BG_FELLEATHER = "Interface\\AddOns\\DC-ItemUpgrade\\Textures\\Backgrounds\\FelLeather_512.tga";
local BG_TINT_ALPHA = 0.60;

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
    
    -- Initialize Tabs
    -- PanelTemplates_SetNumTabs(DarkChaos_TransmutationFrame, 2);
    -- PanelTemplates_SetTab(DarkChaos_TransmutationFrame, 1);
    DarkChaos_Transmutation_ShowTab(1);
end

function DarkChaos_Transmutation_OnShow()
    PlaySound("AuctionWindowOpen");
    DarkChaos_Transmutation_RequestInfo();
end

function DarkChaos_Transmutation_RequestInfo()
    local DCProtocol = rawget(_G, "DCAddonProtocol");
    if DCProtocol then
        DCProtocol:Send(MODULE, OPCODE_CMSG_GET_TRANSMUTE_INFO, "");
    end
end

-- ============================================================================
-- Data Parsing
-- ============================================================================

function DarkChaos_Transmutation_ParseInfo(data)
    if type(data) ~= "table" then return; end
    
    -- Parse Exchange Rates
    if data.exchange then
        currentExchangeRates.tokensToEssence = data.exchange.tokensToEssence or 100;
        currentExchangeRates.essenceToTokens = data.exchange.essenceToTokens or 80;
    end
    
    -- Parse Status
    if data.session then
        currentStatus = data.session;
    end
    

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
    
    -- Calculate results
    -- Tokens -> Essence (Rate: tokensToEssence)
    local essenceResult = 0;
    if currentExchangeRates.tokensToEssence > 0 then
        essenceResult = math.floor(amount / currentExchangeRates.tokensToEssence);
    end
    
    -- Essence -> Tokens (Rate: essenceToTokens)
    local tokensResult = amount * currentExchangeRates.essenceToTokens;
    
    if frame.ToEssenceBtn then
        frame.ToEssenceBtn:SetText(string.format("Tokens -> Essence\n(Get %d)", essenceResult));
    end
    if frame.ToTokensBtn then
        frame.ToTokensBtn:SetText(string.format("Essence -> Tokens\n(Get %d)", tokensResult));
    end
end

-- Exchange Tab
function DarkChaos_Transmutation_UpdateExchangeTab()
    local frame = DarkChaos_TransmutationFrame.ExchangeFrame;
    
    -- Get player currency (from DC-ItemUpgrade global state)
    local essence = DC.playerEssence or 0;
    local tokens = DC.playerTokens or 0;
    
    frame.BalanceText:SetText(string.format("|cffffffffEssence:|r |cff00ff00%d|r   |cffffffffTokens:|r |cff00ff00%d|r", essence, tokens));
    
    frame.RateText:SetText(string.format("|cffffd700Exchange Rates:|r\n%d Tokens -> 1 Essence\n1 Essence -> %d Tokens", 
        currentExchangeRates.tokensToEssence, currentExchangeRates.essenceToTokens));
        
    DarkChaos_Transmutation_UpdateExchangeCalculations();
end

function DarkChaos_Transmutation_DoExchange(type)
    -- Type 1: Tokens -> Essence
    -- Type 2: Essence -> Tokens
    
    local amountInput = DarkChaos_TransmutationFrame.ExchangeFrame.AmountInput;
    local amount = tonumber(amountInput:GetText()) or 0;
    
    if amount <= 0 then
        UIErrorsFrame:AddMessage("Please enter a valid amount.", 1.0, 0.0, 0.0, 1.0, UIERRORS_HOLD_TIME);
        return;
    end

    local DCProtocol = rawget(_G, "DCAddonProtocol");
    if DCProtocol then
        -- Send JSON payload
        local payload = string.format("{\"action\":\"exchange\",\"type\":%d,\"amount\":%d}", type, amount);
        DCProtocol:Send(MODULE, OPCODE_CMSG_DO_TRANSMUTE, payload);
    end
end



function DarkChaos_Transmutation_Show()
    DarkChaos_TransmutationFrame:Show();
    DarkChaos_Transmutation_RequestInfo();
end
