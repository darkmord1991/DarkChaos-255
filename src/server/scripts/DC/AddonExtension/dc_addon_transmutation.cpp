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
    static int32 JsonGetInt(JsonValue const& json, std::string const& key, int32 defaultVal = 0)
    {
        if (!json.IsObject() || !json.HasKey(key))
            return defaultVal;
        JsonValue const& v = json[key];
        if (v.IsNumber())
            return v.AsInt32();
        if (v.IsString())
            return std::atoi(v.AsString().c_str());
        return defaultVal;
    }

    static std::string JsonGetString(JsonValue const& json, std::string const& key, std::string const& defaultVal = "")
    {
        if (!json.IsObject() || !json.HasKey(key))
            return defaultVal;
        JsonValue const& v = json[key];
        if (v.IsString())
            return v.AsString();
        return defaultVal;
    }

    static void CacheContext(Player* player)
    {
        if (player)
            DarkChaos::ItemUpgrade::CachePlayerMapContext(player);
    }

    static char const* CurrencyDisplayName(DarkChaos::ItemUpgrade::CurrencyType currency)
    {
        using namespace DarkChaos::ItemUpgrade;
        switch (currency)
        {
            case CURRENCY_ARTIFACT_ESSENCE: return "Artifact Essence";
            case CURRENCY_FRONTIER_SAP:     return "Emberwood Sap";
            case CURRENCY_UPGRADE_TOKEN:    return "Upgrade Tokens";
            default:                        return "currency";
        }
    }

    // Send Open UI Signal
    void SendOpenTransmutationUI(Player* player)
    {
        Message(Module::UPGRADE, Opcode::Upgrade::SMSG_OPEN_TRANSMUTE_UI).Send(player);
    }

    // Send Currency Exchange Info (Rates, Status)
    static void SendTransmutationInfo(Player* player)
    {
        CacheContext(player);
        using namespace DarkChaos::ItemUpgrade;

        TransmutationManager* transMgr = GetTransmutationManager();

        // 1. Get Exchange Rates
        std::vector<CurrencyExchangeRate> rateTable = transMgr->GetExchangeRateTable();

        // 2. Get Transmutation Status
        TransmutationSession session = transMgr->GetTransmutationStatus(player->GetGUID().GetCounter());

        JsonValue exchange;
        exchange.SetObject();

        // Every supported (from, to) pair as a give/get ratio. The client drives
        // its dropdowns off this list, so a pair the server does not offer is
        // not selectable and the displayed cost always matches what is charged.
        JsonValue ratesArray;
        ratesArray.SetArray(rateTable.size());
        for (auto const& rate : rateTable)
        {
            JsonValue row;
            row.SetObject();
            row.Set("from", JsonValue(static_cast<uint32>(rate.from)));
            row.Set("to", JsonValue(static_cast<uint32>(rate.to)));
            row.Set("give", JsonValue(rate.from_units));
            row.Set("get", JsonValue(rate.to_units));
            ratesArray.Push(std::move(row));
        }
        exchange.Set("rates", std::move(ratesArray));

        // Balances for all three currencies, so the window does not have to
        // guess at the sap balance the upgrade tab already knows.
        JsonValue balances;
        balances.SetObject();
        balances.Set("tokens", JsonValue(GetPlayerTokens(player)));
        balances.Set("essence", JsonValue(GetPlayerEssence(player)));
        balances.Set("sap", JsonValue(GetPlayerFrontierSap(player)));
        exchange.Set("balances", std::move(balances));

        // Item ids so the client can resolve icons and names for each currency.
        JsonValue itemIds;
        itemIds.SetObject();
        itemIds.Set("tokens", JsonValue(GetCurrencyItemId(CURRENCY_UPGRADE_TOKEN)));
        itemIds.Set("essence", JsonValue(GetCurrencyItemId(CURRENCY_ARTIFACT_ESSENCE)));
        itemIds.Set("sap", JsonValue(GetCurrencyItemId(CURRENCY_FRONTIER_SAP)));
        exchange.Set("itemIds", std::move(itemIds));

        // Legacy scalars for an addon that predates the rate table. Derived from
        // the table rather than restated, so an un-updated client shows the real
        // token<->essence rates instead of its 100/80 placeholder defaults.
        for (auto const& rate : rateTable)
        {
            if (rate.from == CURRENCY_UPGRADE_TOKEN && rate.to == CURRENCY_ARTIFACT_ESSENCE)
                exchange.Set("tokensToEssence", JsonValue(rate.from_units));
            else if (rate.from == CURRENCY_ARTIFACT_ESSENCE && rate.to == CURRENCY_UPGRADE_TOKEN)
                exchange.Set("essenceToTokens", JsonValue(rate.to_units));
        }

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

    static void HandleGetTransmuteInfo(Player* player, ParsedMessage const& /*msg*/)
    {
        CacheContext(player);
        SendTransmutationInfo(player);
    }

    static void HandleDoTransmute(Player* player, ParsedMessage const& msg)
    {
        CacheContext(player);
        // Format: Type|Arg1|Arg2...
        // Type 1: Tier Conversion (ItemGUID, TargetTier) - Not implemented
        // Type 2: Currency Exchange (from, to, amount -- amount is SOURCE units)
        // Type 3: Synthesis - REMOVED

        LOG_DEBUG("scripts.dc", "HandleDoTransmute called for player {} with {} data fields",
                  player->GetGUID().GetCounter(), msg.GetDataCount());

        using namespace DarkChaos::ItemUpgrade;

        uint32 type = msg.GetUInt32(0);
        uint32 exchangeType = msg.GetUInt32(1);
        uint32 amount = msg.GetUInt32(2);

        // Explicit currency pair (rate-table era). Zero means "not supplied",
        // in which case exchangeType still carries the legacy 1/2 direction.
        uint32 fromCurrency = 0;
        uint32 toCurrency = 0;

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
                fromCurrency = static_cast<uint32>(JsonGetInt(json, "from", 0));
                toCurrency = static_cast<uint32>(JsonGetInt(json, "to", 0));
                LOG_DEBUG("scripts.dc", "HandleDoTransmute exchange: type={} exchangeType={} from={} to={} amount={}",
                          type, exchangeType, fromCurrency, toCurrency, amount);
            }
            else if (action == "synthesis")
            {
                type = 3;
                amount = static_cast<uint32>(JsonGetInt(json, "recipeId", 0));
            }
        }

        if (type == 1) // Tier Conversion
        {
            // Not fully implemented in this snippet, requires ItemGUID parsing
        }
        else if (type == 2) // Currency Exchange
        {
            TransmutationManager* transMgr = GetTransmutationManager();
            bool success = false;

            // An addon that predates the rate table sends only the legacy
            // direction flag: 1 = tokens->essence, 2 = essence->tokens. Map it
            // onto the currency pair so both client generations share one path.
            if (fromCurrency == 0 && toCurrency == 0)
            {
                if (exchangeType == 1)
                {
                    fromCurrency = CURRENCY_UPGRADE_TOKEN;
                    toCurrency = CURRENCY_ARTIFACT_ESSENCE;
                }
                else if (exchangeType == 2)
                {
                    fromCurrency = CURRENCY_ARTIFACT_ESSENCE;
                    toCurrency = CURRENCY_UPGRADE_TOKEN;
                }
            }

            LOG_DEBUG("scripts.dc", "HandleDoTransmute currency exchange: transMgr={} from={} to={} amount={}",
                      (transMgr != nullptr), fromCurrency, toCurrency, amount);

            bool validPair = fromCurrency >= CURRENCY_UPGRADE_TOKEN
                && fromCurrency <= CURRENCY_FRONTIER_SAP
                && toCurrency >= CURRENCY_UPGRADE_TOKEN
                && toCurrency <= CURRENCY_FRONTIER_SAP
                && fromCurrency != toCurrency;

            if (!transMgr || !validPair || amount == 0)
            {
                LOG_WARN("scripts.dc", "HandleDoTransmute invalid params: transMgr={} from={} to={} amount={}",
                         (transMgr != nullptr), fromCurrency, toCurrency, amount);
                JsonMessage(Module::UPGRADE, Opcode::Upgrade::SMSG_TRANSMUTE_RESULT)
                    .Set("success", false)
                    .Set("type", static_cast<int32>(type))
                    .Set("message", "Invalid exchange request")
                    .Send(player);
                return;
            }

            // Use the manager's ExchangeCurrency interface. The manager owns the
            // rate lookup, so an unsupported pair is rejected there, not here.
            success = transMgr->ExchangeCurrency(player->GetGUID().GetCounter(),
                static_cast<CurrencyType>(fromCurrency),
                static_cast<CurrencyType>(toCurrency), amount);

            JsonMessage(Module::UPGRADE, Opcode::Upgrade::SMSG_TRANSMUTE_RESULT)
                .Set("success", success)
                .Set("type", static_cast<int32>(type))
                .Set("message", success ? "Exchange complete" : "Exchange failed")
                .Send(player);

            if (success)
            {
                // Name the pair rather than restating amounts. The manager floors
                // the request to whole trades and adds the fee, so any figure
                // recomputed here would be a second copy of the rate maths and
                // would drift from what was actually charged. The currency
                // update that follows carries the real balances.
                ChatHandler(player->GetSession()).PSendSysMessage(
                    "|cFF00FF00[Exchange]|r Converted {} to {}.",
                    CurrencyDisplayName(static_cast<CurrencyType>(fromCurrency)),
                    CurrencyDisplayName(static_cast<CurrencyType>(toCurrency)));

                SendCurrencyUpdate(player);
                SendTransmutationInfo(player);
            }
            else
            {
                ChatHandler(player->GetSession()).PSendSysMessage("|cFFFF0000[Exchange]|r Exchange failed - insufficient currency, or less than one full trade.");
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
