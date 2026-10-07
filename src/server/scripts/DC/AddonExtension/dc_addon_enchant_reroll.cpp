/*
 * Dark Chaos - Random Enchant Reroll Addon Handler
 * ================================================
 *
 * DC|UPG|... messages for the "Random Enchants" panel of DC-ItemUpgrade (EnchantReroll.lua).
 * The rules live in RandomEnchants/dc_random_enchants_reroll.cpp; this file reads the requests
 * and writes the answers.
 *
 *   CMSG_GET_ENCHANT_INFO  (0x22)  { bag, slot }
 *   CMSG_DO_ENCHANT_REROLL (0x23)  { bag, slot, action = "reroll" | "add" | "rerollAll", line,
 *                                    expected = [id, id, id] }
 *   SMSG_ENCHANT_INFO      (0x33)  the item's lines (id, tier, text), whether and why it can hold
 *                                  them, the price of every action, the reroll count, the balance
 *   SMSG_ENCHANT_RESULT    (0x34)  success / errorCode / error, the lines before and after, what
 *                                  was paid; followed by a fresh SMSG_ENCHANT_INFO
 *
 * bag/slot are the addon coordinates every UPG request uses (TranslateAddonBagSlot). `expected`
 * is the lines the window showed when the player clicked: if they no longer match, nothing is
 * charged and the window is redrawn.
 */

#include "dc_addon_namespace.h"
#include "dc_addon_transmutation.h"
#include "Chat.h"
#include "DBCStores.h"
#include "DC/ItemUpgrades/ItemUpgradeManager.h"
#include "DC/ItemUpgrades/ItemUpgradeProcScaling.h"
#include "DC/ItemUpgrades/ItemUpgradeUIHelpers.h"
#include "DC/RandomEnchants/dc_random_enchants.h"
#include "Item.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "StringFormat.h"

#include <algorithm>
#include <string>
#include <vector>

namespace DCAddon
{
namespace EnchantReroll
{
    namespace
    {
        namespace RE = DarkChaos::RandomEnchants;
        namespace RR = DarkChaos::RandomEnchants::Reroll;

        struct ItemLocation
        {
            uint32 extBag = 0;
            uint32 extSlot = 0;
        };

        bool ReadUInt(JsonValue const& data, char const* key, uint32& out)
        {
            if (!data.IsObject() || !data.HasKey(key))
                return false;

            JsonValue const& value = data[key];
            if (!value.IsNumber() || value.AsNumber() < 0.0 || value.AsNumber() > 4294967295.0)
                return false;

            out = value.AsUInt32();
            return true;
        }

        bool ParseAction(JsonValue const& data, RR::Action& out)
        {
            if (!data.IsObject() || !data.HasKey("action"))
                return false;

            JsonValue const& value = data["action"];
            if (value.IsString())
            {
                std::string const& token = value.AsString();
                if (token == "reroll")
                    out = RR::Action::RerollLine;
                else if (token == "add")
                    out = RR::Action::AddLine;
                else if (token == "rerollAll")
                    out = RR::Action::RerollAll;
                else
                    return false;

                return true;
            }

            uint32 numeric = 0;
            if (!ReadUInt(data, "action", numeric) || numeric < uint32(RR::Action::RerollLine)
                || numeric > uint32(RR::Action::RerollAll))
                return false;

            out = static_cast<RR::Action>(numeric);
            return true;
        }

        char const* ActionToken(RR::Action action)
        {
            switch (action)
            {
                case RR::Action::RerollLine:
                    return "reroll";
                case RR::Action::AddLine:
                    return "add";
                case RR::Action::RerollAll:
                    return "rerollAll";
            }

            return "";
        }

        // The item at the addon's bag/slot when that is somewhere the player keeps items:
        // equipped, carried or in the bank. Buyback slots are not.
        Item* ResolveItem(Player* player, ItemLocation const& location)
        {
            uint8 bag = 0;
            uint8 slot = 0;
            if (!DarkChaos::ItemUpgrade::UI::TranslateAddonBagSlot(location.extBag, location.extSlot, bag, slot))
                return nullptr;

            if (!Player::IsEquipmentPos(bag, slot) && !Player::IsInventoryPos(bag, slot)
                && !Player::IsBankPos(bag, slot))
                return nullptr;

            return player->GetItemByPos(bag, slot);
        }

        // The upgrade multiplier the item's lines are applied with, so the window prints the
        // numbers the character actually gets. Cache-only: the window is opened on an item the
        // upgrade frame has already loaded, and a miss just shows base values.
        float CurrentMultiplier(Item* item)
        {
            DarkChaos::ItemUpgrade::UpgradeManager* mgr = DarkChaos::ItemUpgrade::GetUpgradeManager();
            if (!mgr)
                return 1.0f;

            DarkChaos::ItemUpgrade::ItemUpgradeState* state =
                mgr->GetCachedItemUpgradeState(item->GetGUID().GetCounter());
            if (!state || state->upgrade_level == 0 || state->stat_multiplier <= 1.0f)
                return 1.0f;

            return state->stat_multiplier;
        }

        // A line as the item tooltip prints it, its effects joined with ", ".
        std::string LineText(Item* item, uint8 line, float multiplier)
        {
            std::string text;
            for (std::string const& part : DarkChaos::ItemUpgrade::BuildRandomEnchantLineText(item, line, multiplier))
            {
                if (!text.empty())
                    text += ", ";
                text += part;
            }

            if (!text.empty())
                return text;

            // An enchant the tooltip builder cannot phrase still has its DBC name.
            uint32 const enchantId = item->GetEnchantmentId(EnchantmentSlot(PROP_ENCHANTMENT_SLOT_0 + line));
            SpellItemEnchantmentEntry const* enchant = sSpellItemEnchantmentStore.LookupEntry(enchantId);
            if (enchant && enchant->description[0])
                return enchant->description[0];

            return "";
        }

        std::string ItemName(Item const* item)
        {
            ItemTemplate const* proto = item->GetTemplate();
            if (!proto)
                return "item";

            uint32 const color = ItemQualityColors[std::min<uint32>(proto->Quality, MAX_ITEM_QUALITY - 1)];
            return Acore::StringFormat("|c{:08x}[{}]|r", color, proto->Name1);
        }

        std::string CurrencyName(uint32 itemId, uint32 amount)
        {
            ItemTemplate const* proto = sObjectMgr->GetItemTemplate(itemId);
            std::string const name = proto ? proto->Name1 : "currency";
            return Acore::StringFormat("{} {}", amount, name);
        }

        JsonValue PriceJson(RR::Price const& price)
        {
            JsonValue json;
            json.SetObject();
            json.Set("amount", JsonValue(price.amount));
            json.Set("money", JsonValue(price.money));
            return json;
        }

        JsonValue LinesJson(RE::Lines const& lines)
        {
            JsonValue json;
            json.SetArray(lines.size());
            for (uint32 enchantId : lines)
                json.Push(JsonValue(enchantId));
            return json;
        }

        void SendInfoError(Player* player, std::string const& requestId, ItemLocation const& location,
            char const* error)
        {
            JsonMessage(Module::UPGRADE, Opcode::Upgrade::SMSG_ENCHANT_INFO)
                .SetRequestId(requestId)
                .Set("success", false)
                .Set("bag", location.extBag)
                .Set("slot", location.extSlot)
                .Set("error", error)
                .Send(player);
        }

        void SendInfo(Player* player, Item* item, ItemLocation const& location, uint32 rerollCount,
            std::string const& requestId)
        {
            RE::Eligibility const eligibility = RE::GetEligibility(item);
            bool const eligible = eligibility == RE::Eligibility::Eligible;
            float const multiplier = CurrentMultiplier(item);
            RE::Lines const lines = RE::GetLines(item);

            // An ineligible item's property slots may hold a stock suffix, which is not a line of
            // ours: only an eligible item's lines are described.
            JsonValue lineArray;
            lineArray.SetArray(RE::MAX_LINES);
            for (uint8 line = 0; line < RE::MAX_LINES; ++line)
            {
                uint32 const enchantId = eligible ? lines[line] : 0;

                JsonValue row;
                row.SetObject();
                row.Set("line", JsonValue(uint32(line)));
                row.Set("enchantId", JsonValue(enchantId));
                row.Set("tier", JsonValue(uint32(enchantId ? RE::GetEnchantTier(enchantId) : 0)));
                row.Set("text", JsonValue(enchantId ? LineText(item, line, multiplier) : std::string()));
                lineArray.Push(std::move(row));
            }

            JsonValue prices;
            prices.SetObject();
            if (eligible)
            {
                prices.Set("reroll", PriceJson(RR::Quote(item, RR::Action::RerollLine, rerollCount)));
                prices.Set("add", PriceJson(RR::Quote(item, RR::Action::AddLine, rerollCount)));
                prices.Set("rerollAll", PriceJson(RR::Quote(item, RR::Action::RerollAll, rerollCount)));
            }

            // Every action on an item is paid in the same currency.
            RR::Price const basis = RR::Quote(item, RR::Action::RerollLine, rerollCount);
            ItemTemplate const* currencyProto = sObjectMgr->GetItemTemplate(basis.currencyItemId);

            JsonValue currency;
            currency.SetObject();
            currency.Set("type", JsonValue(uint32(basis.currency)));
            currency.Set("itemId", JsonValue(basis.currencyItemId));
            currency.Set("name", JsonValue(currencyProto ? currencyProto->Name1 : std::string()));
            currency.Set("balance", JsonValue(player->GetItemCount(basis.currencyItemId)));

            JsonMessage(Module::UPGRADE, Opcode::Upgrade::SMSG_ENCHANT_INFO)
                .SetRequestId(requestId)
                .Set("success", true)
                .Set("bag", location.extBag)
                .Set("slot", location.extSlot)
                .Set("itemGuid", item->GetGUID().GetCounter())
                .Set("itemEntry", item->GetEntry())
                .Set("enabled", RR::IsEnabled())
                .Set("eligible", eligible)
                .Set("reason", RE::DescribeEligibility(eligibility))
                .Set("maxLines", uint32(RE::GetMaxLines()))
                .Set("lines", std::move(lineArray))
                .Set("rerollCount", rerollCount)
                .Set("costIncrease", RR::GetCostIncrease())
                .Set("allowAdd", RR::IsActionAllowed(RR::Action::AddLine))
                .Set("allowRerollAll", RR::IsActionAllowed(RR::Action::RerollAll))
                .Set("prices", std::move(prices))
                .Set("currency", std::move(currency))
                .Set("money", player->GetMoney())
                .Send(player);
        }

        void SendResult(Player* player, std::string const& requestId, ItemLocation const& location,
            RR::Request const& request, RR::Outcome const& outcome)
        {
            JsonValue cost;
            cost.SetObject();
            cost.Set("currencyType", JsonValue(uint32(outcome.price.currency)));
            cost.Set("currencyItemId", JsonValue(outcome.price.currencyItemId));
            cost.Set("amount", JsonValue(outcome.price.amount));
            cost.Set("money", JsonValue(outcome.price.money));

            JsonMessage(Module::UPGRADE, Opcode::Upgrade::SMSG_ENCHANT_RESULT)
                .SetRequestId(requestId)
                .Set("success", outcome.error == RR::Error::None)
                .Set("errorCode", uint32(outcome.error))
                .Set("error", RR::DescribeError(outcome.error))
                .Set("action", ActionToken(request.action))
                .Set("line", uint32(request.line))
                .Set("bag", location.extBag)
                .Set("slot", location.extSlot)
                .Set("before", LinesJson(outcome.before))
                .Set("after", LinesJson(outcome.after))
                .Set("cost", std::move(cost))
                .Set("rerollCount", outcome.rerollCount)
                .Send(player);
        }

        // The chat record of a paid action, which outlives the window.
        void AnnounceResult(Player* player, Item* item, RR::Request const& request, RR::Outcome const& outcome)
        {
            float const multiplier = CurrentMultiplier(item);
            std::string changes;
            for (uint8 line = 0; line < RE::MAX_LINES; ++line)
            {
                if (outcome.before[line] == outcome.after[line])
                    continue;

                if (!changes.empty())
                    changes += "; ";
                changes += Acore::StringFormat("line {} is now {}", line + 1, LineText(item, line, multiplier));
            }

            std::string paid = CurrencyName(outcome.price.currencyItemId, outcome.price.amount);
            if (!outcome.price.amount)
                paid.clear();
            if (outcome.price.money)
            {
                if (!paid.empty())
                    paid += " and ";
                paid += Acore::StringFormat("{}g {}s {}c", outcome.price.money / 10000,
                    (outcome.price.money / 100) % 100, outcome.price.money % 100);
            }

            char const* verb = request.action == RR::Action::AddLine ? "Added a line to" : "Rerolled";
            ChatHandler(player->GetSession()).PSendSysMessage("|cff00ff00[Random Enchants]|r {} {}: {}{}.",
                verb, ItemName(item), changes, paid.empty() ? std::string() : " (paid " + paid + ")");
        }
    }

    static void HandleGetEnchantInfo(Player* player, ParsedMessage const& msg)
    {
        if (!player)
            return;

        JsonValue const data = GetJsonData(msg);
        std::string const requestId = msg.GetRequestId();

        ItemLocation location;
        if (!ReadUInt(data, "bag", location.extBag) || !ReadUInt(data, "slot", location.extSlot))
        {
            SendInfoError(player, requestId, location, "Invalid request.");
            return;
        }

        Item* item = ResolveItem(player, location);
        if (!item)
        {
            SendInfoError(player, requestId, location, RR::DescribeError(RR::Error::ItemNotFound));
            return;
        }

        // An item that cannot hold lines has nothing to price, so its count is never read.
        if (RE::GetEligibility(item) != RE::Eligibility::Eligible)
        {
            SendInfo(player, item, location, 0, requestId);
            return;
        }

        RR::WithRerollCount(player, item, [location, requestId](Player* owner, Item* current, uint32 count)
        {
            // An asynchronous count can land after the item moved; answer only for the item
            // that is still where the window asked about.
            if (!current || ResolveItem(owner, location) != current)
            {
                SendInfoError(owner, requestId, location, RR::DescribeError(RR::Error::ItemNotFound));
                return;
            }

            SendInfo(owner, current, location, count, requestId);
        });
    }

    static void HandleDoEnchantReroll(Player* player, ParsedMessage const& msg)
    {
        if (!player)
            return;

        JsonValue const data = GetJsonData(msg);
        std::string const requestId = msg.GetRequestId();

        ItemLocation location;
        RR::Request request;
        RR::Outcome refused;

        if (!ReadUInt(data, "bag", location.extBag) || !ReadUInt(data, "slot", location.extSlot))
        {
            refused.error = RR::Error::ItemNotFound;
            SendResult(player, requestId, location, request, refused);
            return;
        }

        if (!ParseAction(data, request.action))
        {
            refused.error = RR::Error::ActionDisabled;
            SendResult(player, requestId, location, request, refused);
            return;
        }

        uint32 line = 0;
        if (ReadUInt(data, "line", line))
            request.line = static_cast<uint8>(std::min<uint32>(line, RE::MAX_LINES));

        // The lines the window priced. Required: without them a repeated click would pay for a
        // second reroll the player never looked at.
        if (data.HasKey("expected") && data["expected"].IsArray() && data["expected"].Size() == RE::MAX_LINES)
        {
            JsonValue const& expected = data["expected"];
            request.hasExpected = true;
            for (uint8 i = 0; i < RE::MAX_LINES; ++i)
            {
                JsonValue const& value = expected[i];
                request.expected[i] = value.IsNumber() && value.AsNumber() >= 0.0 ? value.AsUInt32() : 0;
            }
        }

        Item* item = ResolveItem(player, location);
        if (!item || !request.hasExpected)
        {
            refused.error = item ? RR::Error::ItemChanged : RR::Error::ItemNotFound;
            refused.before = RE::GetLines(item);
            refused.after = refused.before;
            SendResult(player, requestId, location, request, refused);
            return;
        }

        RR::WithRerollCount(player, item, [location, request, requestId](Player* owner, Item* current, uint32 count)
        {
            RR::Outcome outcome;
            if (!current || ResolveItem(owner, location) != current)
            {
                outcome.error = RR::Error::ItemNotFound;
                SendResult(owner, requestId, location, request, outcome);
                return;
            }

            outcome = RR::Execute(owner, current, request, count);
            SendResult(owner, requestId, location, request, outcome);

            if (outcome.error == RR::Error::None)
            {
                AnnounceResult(owner, current, request, outcome);
                DCAddon::Upgrade::SendCurrencyUpdate(owner);
            }

            // A success changed the lines and the prices; a refusal may have been priced on a
            // stale window. Either way the window redraws from what is true now.
            SendInfo(owner, current, location, outcome.rerollCount, std::string());
        });
    }

    void RegisterHandlers()
    {
        DC_REGISTER_HANDLER(Module::UPGRADE, Opcode::Upgrade::CMSG_GET_ENCHANT_INFO, HandleGetEnchantInfo);
        DC_REGISTER_HANDLER(Module::UPGRADE, Opcode::Upgrade::CMSG_DO_ENCHANT_REROLL, HandleDoEnchantReroll);
    }
}  // namespace EnchantReroll
}  // namespace DCAddon

void AddSC_dc_addon_enchant_reroll()
{
    DCAddon::EnchantReroll::RegisterHandlers();
}
