/*
 * Dark Chaos - Item Upgrade Transmutation Addon Handler
 * =====================================================
 *
 * Handles DC|UPG|... messages for the Transmutation system.
 *
 * Copyright (C) 2025 Dark Chaos Development Team
 */

#include "DCAddonNamespace.h"
#include "DCAddonTransmutation.h"
#include "ScriptMgr.h"
#include "Player.h"
#include "Item.h"
#include "DC/ItemUpgrades/ItemUpgradeTransmutation.h"
#include "DC/ItemUpgrades/ItemUpgradeManager.h"

namespace DCAddon
{
namespace Upgrade
{
    // Forward declaration
    void SendCurrencyUpdate(Player* player);

    // Send Open UI Signal
    void SendOpenTransmutationUI(Player* player)
    {
        Message(Module::UPGRADE, Opcode::Upgrade::SMSG_OPEN_TRANSMUTE_UI).Send(player);
    }

    // Send Transmutation Info (Recipes, Rates, Status)
    static void SendTransmutationInfo(Player* player)
    {
        using namespace DarkChaos::ItemUpgrade;

        TransmutationManager* transMgr = GetTransmutationManager();
        SynthesisManager* synthMgr = GetSynthesisManager();

        // 1. Get Exchange Rates
        uint32 tokensToEssence, essenceToTokens;
        transMgr->GetExchangeRates(tokensToEssence, essenceToTokens);

        // 2. Get Transmutation Status
        TransmutationSession session = transMgr->GetTransmutationStatus(player->GetGUID().GetCounter());

        // 3. Get Synthesis Recipes
        auto recipes = synthMgr->GetSynthesisRecipes(player->GetGUID().GetCounter());

        // Build JSON response
        std::ostringstream json;
        json << "{";

        // Exchange Rates
        json << "\"exchange\":{"
             << "\"tokensToEssence\":" << tokensToEssence << ","
             << "\"essenceToTokens\":" << essenceToTokens
             << "},";

        // Session Status
        bool sessionActive = (session.player_guid != 0 && !session.completed);
        json << "\"session\":{"
             << "\"active\":" << (sessionActive ? "true" : "false") << ","
             << "\"completed\":" << (session.completed ? "true" : "false") << ","
             << "\"recipeId\":" << session.recipe_id << ","
             << "\"success\":" << (session.success ? "true" : "false") << ","
             << "\"startTime\":" << session.start_time << ","
             << "\"endTime\":" << session.end_time
             << "},";

        // Recipes
        json << "\"recipes\":[";
        bool first = true;
        for (auto const& recipe : recipes)
        {
            if (!first) json << ",";
            first = false;

            json << "{"
                 << "\"id\":" << recipe.recipe_id << ","
                 << "\"name\":\"" << recipe.name << "\"," // Should escape quotes
                 << "\"desc\":\"" << recipe.description << "\","
                 << "\"reqTier\":" << (int)recipe.required_tier << ","
                 << "\"inEssence\":" << recipe.input_essence << ","
                 << "\"inTokens\":" << recipe.input_tokens << ","
                 << "\"successRate\":" << recipe.success_rate_base
                 << "}";
        }
        json << "]";

        json << "}";

        JsonMessage(Module::UPGRADE, Opcode::Upgrade::SMSG_TRANSMUTE_INFO)
            .Set("data", json.str()) // Nested JSON string for now, or could structure it directly
            .Send(player);
    }

    static void HandleGetTransmuteInfo(Player* player, const ParsedMessage& /*msg*/)
    {
        SendTransmutationInfo(player);
    }

    static void HandleDoTransmute(Player* player, const ParsedMessage& msg)
    {
        // Format: Type|Arg1|Arg2...
        // Type 1: Tier Conversion (ItemGUID, TargetTier)
        // Type 2: Currency Exchange (Type, Amount)
        // Type 3: Synthesis (RecipeID)

        uint32 type = msg.GetUInt32(0);

        using namespace DarkChaos::ItemUpgrade;

        if (type == 1) // Tier Conversion
        {
            // Not fully implemented in this snippet, requires ItemGUID parsing
        }
        else if (type == 2) // Currency Exchange
        {
            uint32 exchangeType = msg.GetUInt32(1); // 1=Token->Essence, 2=Essence->Token
            // Amount logic would go here

            TransmutationManager* transMgr = GetTransmutationManager();
            bool success = false;

            // Use the manager's ExchangeCurrency interface
            success = transMgr->ExchangeCurrency(player->GetGUID().GetCounter(), exchangeType == 1, 1);

            Message(Module::UPGRADE, Opcode::Upgrade::SMSG_TRANSMUTE_RESULT)
                .Add(success)
                .Add(type)
                .Send(player);

            if (success)
                SendCurrencyUpdate(player); // Defined in dc_addon_upgrade.cpp, need to link or duplicate
        }
        else if (type == 3) // Synthesis
        {
            // Need to gather input items from player inventory... complex logic
            // For now, just send error
            Message(Module::UPGRADE, Opcode::Upgrade::SMSG_TRANSMUTE_RESULT)
                .Add(0)
                .Add(type)
                .Add("Not implemented via addon yet")
                .Send(player);
        }
    }

    void RegisterTransmutationHandlers()
    {
        // Ensure module enabled via config if desired; using DC_REGISTER_HANDLER macro
        DC_REGISTER_HANDLER(Module::UPGRADE, Opcode::Upgrade::CMSG_GET_TRANSMUTE_INFO, HandleGetTransmuteInfo);
        DC_REGISTER_HANDLER(Module::UPGRADE, Opcode::Upgrade::CMSG_DO_TRANSMUTE, HandleDoTransmute);
    }

} // namespace Upgrade
} // namespace DCAddon

void AddSC_dc_addon_transmutation()
{
    DCAddon::Upgrade::RegisterTransmutationHandlers();
}
