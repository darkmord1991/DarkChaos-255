/*
 * Dark Chaos - Item Upgrade Currency Exchange Addon Handler
 * =========================================================
 *
 * Handles DC|UPG|... messages for the Currency Exchange system.
 * (Renamed from Transmutation, Jan 2026)
 *
 * Copyright (C) 2025-2026 Dark Chaos Development Team
 */

#include "Common.h"
#include "dc_addon_namespace.h"
#include "dc_addon_transmutation.h"
#include "ScriptMgr.h"
#include "Player.h"
#include "Item.h"
#include "Chat.h"
#include "DC/ItemUpgrades/ItemUpgradeExchange.h"
#include "DC/ItemUpgrades/ItemUpgradeManager.h"

namespace DCAddon
{
namespace Upgrade
{
    static int32 JsonGetInt(const JsonValue& json, const std::string& key, int32 defaultVal = 0)
    {
        if (!json.IsObject() || !json.HasKey(key))
            return defaultVal;
        const JsonValue& v = json[key];
        if (v.IsNumber())
            return v.AsInt32();
        if (v.IsString())
            return std::atoi(v.AsString().c_str());
        return defaultVal;
    }

    static std::string JsonGetString(const JsonValue& json, const std::string& key, const std::string& defaultVal = "")
    {
        if (!json.IsObject() || !json.HasKey(key))
            return defaultVal;
        const JsonValue& v = json[key];
        if (v.IsString())
            return v.AsString();
        return defaultVal;
    }

    // Send Open UI Signal
    void SendOpenTransmutationUI(Player* player)
    {
        Message(Module::UPGRADE, Opcode::Upgrade::SMSG_OPEN_TRANSMUTE_UI).Send(player);
    }

    // Send Currency Exchange Info (Rates, Status)
    static void SendTransmutationInfo(Player* player)
    {
        using namespace DarkChaos::ItemUpgrade;

        TransmutationManager* transMgr = GetTransmutationManager();

        // 1. Get Exchange Rates
        uint32 tokensToEssence, essenceToTokens;
        transMgr->GetExchangeRates(tokensToEssence, essenceToTokens);

        // 2. Get Transmutation Status
        TransmutationSession session = transMgr->GetTransmutationStatus(player->GetGUID().GetCounter());

        JsonValue exchange;
        exchange.SetObject();
        exchange.Set("tokensToEssence", JsonValue(tokensToEssence));
        exchange.Set("essenceToTokens", JsonValue(essenceToTokens));

        bool sessionActive = (session.player_guid != 0 && !session.completed);
        JsonValue sessionObj;
        sessionObj.SetObject();
        sessionObj.Set("active", JsonValue(sessionActive));
        sessionObj.Set("completed", JsonValue(session.completed));
        sessionObj.Set("recipeId", JsonValue(session.recipe_id));
        sessionObj.Set("success", JsonValue(session.success));
        sessionObj.Set("startTime", JsonValue(static_cast<double>(session.start_time)));
        sessionObj.Set("endTime", JsonValue(static_cast<double>(session.end_time)));

        // Empty recipes array - Synthesis system removed
        JsonValue recipesArray;
        recipesArray.SetArray();

        JsonMessage(Module::UPGRADE, Opcode::Upgrade::SMSG_TRANSMUTE_INFO)
            .Set("exchange", exchange)
            .Set("session", sessionObj)
            .Set("recipes", recipesArray)
            .Send(player);
    }

    static void HandleGetTransmuteInfo(Player* player, const ParsedMessage& /*msg*/)
    {
        SendTransmutationInfo(player);
    }

    static void HandleDoTransmute(Player* player, const ParsedMessage& msg)
    {
        // Format: Type|Arg1|Arg2...
        // Type 1: Tier Conversion (ItemGUID, TargetTier) - Not implemented
        // Type 2: Currency Exchange (Type, Amount)
        // Type 3: Synthesis - REMOVED

        LOG_DEBUG("scripts.dc", "HandleDoTransmute called for player {} with {} data fields",
                  player->GetGUID().GetCounter(), msg.GetDataCount());

        uint32 type = msg.GetUInt32(0);
        uint32 exchangeType = msg.GetUInt32(1);
        uint32 amount = msg.GetUInt32(2);

        JsonValue json;
        if (IsJsonMessage(msg))
        {
            json = GetJsonData(msg);
        }
        else if (msg.GetDataCount() >= 1)
        {
            std::string raw = msg.GetString(0);
            if (!raw.empty() && raw.front() == '{')
                json = JsonParser::Parse(raw);
        }

        if (json.IsObject())
        {
            std::string action = JsonGetString(json, "action", "");
            LOG_DEBUG("scripts.dc", "HandleDoTransmute JSON parsed: action={}", action);
            if (action == "exchange")
            {
                type = 2;
                exchangeType = static_cast<uint32>(JsonGetInt(json, "type", 0));
                amount = static_cast<uint32>(JsonGetInt(json, "amount", 0));
                LOG_DEBUG("scripts.dc", "HandleDoTransmute exchange: type={} exchangeType={} amount={}",
                          type, exchangeType, amount);
            }
            else if (action == "synthesis")
            {
                type = 3;
                amount = static_cast<uint32>(JsonGetInt(json, "recipeId", 0));
            }
        }

        using namespace DarkChaos::ItemUpgrade;

        if (type == 1) // Tier Conversion
        {
            // Not fully implemented in this snippet, requires ItemGUID parsing
        }
        else if (type == 2) // Currency Exchange
        {
            TransmutationManager* transMgr = GetTransmutationManager();
            bool success = false;

            LOG_DEBUG("scripts.dc", "HandleDoTransmute currency exchange: transMgr={} exchangeType={} amount={}",
                      (transMgr != nullptr), exchangeType, amount);

            if (!transMgr || exchangeType < 1 || exchangeType > 2 || amount == 0)
            {
                LOG_WARN("scripts.dc", "HandleDoTransmute invalid params: transMgr={} exchangeType={} amount={}",
                         (transMgr != nullptr), exchangeType, amount);
                JsonMessage(Module::UPGRADE, Opcode::Upgrade::SMSG_TRANSMUTE_RESULT)
                    .Set("success", false)
                    .Set("type", static_cast<int32>(type))
                    .Set("message", "Invalid exchange request")
                    .Send(player);
                return;
            }

            // Use the manager's ExchangeCurrency interface
            success = transMgr->ExchangeCurrency(player->GetGUID().GetCounter(), exchangeType == 1, amount);

            JsonMessage(Module::UPGRADE, Opcode::Upgrade::SMSG_TRANSMUTE_RESULT)
                .Set("success", success)
                .Set("type", static_cast<int32>(type))
                .Set("message", success ? "Exchange complete" : "Exchange failed")
                .Send(player);

            if (success)
            {
                // Send chat confirmation
                if (exchangeType == 1)
                    ChatHandler(player->GetSession()).PSendSysMessage("|cFF00FF00[Transmutation]|r Exchanged {} tokens for {} essence.", amount * 2, amount);
                else
                    ChatHandler(player->GetSession()).PSendSysMessage("|cFF00FF00[Transmutation]|r Exchanged {} essence for {} tokens.", amount, amount);

                SendCurrencyUpdate(player);
                SendTransmutationInfo(player);
            }
            else
            {
                ChatHandler(player->GetSession()).PSendSysMessage("|cFFFF0000[Transmutation]|r Exchange failed - insufficient currency.");
            }
        }
        else if (type == 3) // Synthesis
        {
            // Need to gather input items from player inventory... complex logic
            // For now, just send error
            JsonMessage(Module::UPGRADE, Opcode::Upgrade::SMSG_TRANSMUTE_RESULT)
                .Set("success", false)
                .Set("type", static_cast<int32>(type))
                .Set("message", "Not implemented via addon yet")
                .Send(player);
        }
        else
        {
            JsonMessage(Module::UPGRADE, Opcode::Upgrade::SMSG_TRANSMUTE_RESULT)
                .Set("success", false)
                .Set("type", static_cast<int32>(type))
                .Set("message", "Unknown transmutation request")
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
