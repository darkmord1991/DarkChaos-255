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
local currentRecipes = {};
local currentExchangeRates = { tokensToEssence = 100, essenceToTokens = 80 };
local currentStatus = {};
local selectedRecipeId = 0;

-- ============================================================================
-- Initialization
-- ============================================================================

function DarkChaos_Transmutation_OnLoad(self)
    self:RegisterForDrag("LeftButton");
    
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
    PanelTemplates_SetNumTabs(DarkChaos_TransmutationFrame, 3);
    PanelTemplates_SetTab(DarkChaos_TransmutationFrame, 1);
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
    
    -- Parse Recipes
    if data.recipes then
        currentRecipes = data.recipes;
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
    frame.ConversionFrame:Hide();
    frame.ExchangeFrame:Hide();
    frame.SynthesisFrame:Hide();
    
    if tabId == 1 then
        frame.ConversionFrame:Show();
    elseif tabId == 2 then
        frame.ExchangeFrame:Show();
        DarkChaos_Transmutation_UpdateExchangeTab();
    elseif tabId == 3 then
        frame.SynthesisFrame:Show();
        DarkChaos_Transmutation_UpdateSynthesisList();
    end
end

function DarkChaos_Transmutation_UpdateUI()
    if DarkChaos_TransmutationFrame.ExchangeFrame:IsShown() then
        DarkChaos_Transmutation_UpdateExchangeTab();
    end
    if DarkChaos_TransmutationFrame.SynthesisFrame:IsShown() then
        DarkChaos_Transmutation_UpdateSynthesisList();
    end
end

-- Conversion Tab
function DarkChaos_Transmutation_ConversionSlot_OnClick(self, button)
    if button == "LeftButton" then
        local type, _, link = GetCursorInfo();
        if type == "item" then
            -- Place item in slot
            self.itemLink = link;
            SetItemButtonTexture(self, GetItemIcon(link));
            ClearCursor();
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
            GameTooltip:SetHyperlink(link);
            GameTooltip:Show();
        else
            -- Clear slot
            self.itemLink = nil;
            SetItemButtonTexture(self, nil);
            GameTooltip:Hide();
        end
    end
end

function DarkChaos_Transmutation_DoConversion()
    local slot = DarkChaos_TransmutationFrame.ConversionFrame.ItemSlot;
    if not slot.itemLink then
        UIErrorsFrame:AddMessage("No item selected.", 1.0, 0.0, 0.0, 1.0, UIERRORS_HOLD_TIME);
        return;
    end
    
    -- TODO: Implement conversion logic (sending item GUID and target tier)
    -- For now, just a placeholder as the backend expects specific opcodes for conversion
    -- which might be different from the generic DO_TRANSMUTE
    print("Conversion not yet fully implemented in UI.");
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
end

function DarkChaos_Transmutation_DoExchange(type)
    -- Type 1: Tokens -> Essence
    -- Type 2: Essence -> Tokens
    
    local DCProtocol = rawget(_G, "DCAddonProtocol");
    if DCProtocol then
        -- Send JSON payload
        local payload = string.format("{\"action\":\"exchange\",\"type\":%d,\"amount\":1}", type);
        DCProtocol:Send(MODULE, OPCODE_CMSG_DO_TRANSMUTE, payload);
    end
end

-- Synthesis Tab
function DarkChaos_Transmutation_UpdateSynthesisList()
    local scrollFrame = DarkChaos_TransmutationFrame.SynthesisFrame.Scroll;
    local offset = FauxScrollFrame_GetOffset(scrollFrame);
    local numRecipes = #currentRecipes;
    
    -- Update scroll frame
    FauxScrollFrame_Update(scrollFrame, numRecipes, 5, 20);
    
    -- Update buttons
    for i = 1, 5 do
        local button = getglobal("DarkChaos_TransmutationFrameSynthesisFrameButton"..i);
        if button then
            local index = offset + i;
            if index <= numRecipes then
                local recipe = currentRecipes[index];
                button:SetText(recipe.name or "Unknown Recipe");
                button:Show();
                
                button:SetScript("OnClick", function()
                    selectedRecipeId = recipe.id;
                    DarkChaos_Transmutation_DoSynthesis(recipe.id);
                end);
            else
                button:Hide();
            end
        end
    end
end

function DarkChaos_Transmutation_DoSynthesis(recipeId)
    local DCProtocol = rawget(_G, "DCAddonProtocol");
    if DCProtocol then
        local payload = string.format("{\"action\":\"synthesis\",\"recipeId\":%d}", recipeId);
        DCProtocol:Send(MODULE, OPCODE_CMSG_DO_TRANSMUTE, payload);
    end
end

function DarkChaos_Transmutation_Show()
    DarkChaos_TransmutationFrame:Show();
    DarkChaos_Transmutation_RequestInfo();
end
