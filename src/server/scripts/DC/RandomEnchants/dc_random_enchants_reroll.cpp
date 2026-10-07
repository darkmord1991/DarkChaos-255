/*
 * DarkChaos Random Enchants - reroll service
 *
 * Pay to reroll one rolled line, reroll every line at once, or add a line to an empty slot.
 * The price is paid in the item's upgrade currency (or the one DC.RandomEnchants.Reroll.Currency
 * names), scaled by item quality, and a line gets dearer with every reroll the item has had.
 * The window lives in DC-ItemUpgrade (EnchantReroll.lua), the wire handlers in
 * AddonExtension/dc_addon_enchant_reroll.cpp.
 *
 * Characters DB:
 *   dc_item_random_enchant_rerolls - reroll count per item, which drives the escalation
 *   dc_item_random_enchant_log     - one row per paid action, every line before and after
 * The lines themselves are ordinary item enchantments and save with the item.
 */

#include "dc_random_enchants.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "DC/AddonExtension/dc_addon_namespace.h"
#include "DC/ItemUpgrades/ItemUpgradeManager.h"
#include "Item.h"
#include "Log.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "StringConvert.h"
#include "StringFormat.h"
#include "Tokenize.h"

#include <algorithm>
#include <limits>
#include <mutex>
#include <unordered_map>
#include <vector>

namespace
{
    using namespace DarkChaos::RandomEnchants;
    using namespace DarkChaos::RandomEnchants::Reroll;

    struct RerollConfig
    {
        bool enabled = true;
        bool allowAdd = true;
        bool allowRerollAll = true;
        bool blockInCombat = true;

        // 0 = the item's upgrade currency (Upgrade Tokens for tiers 1/2, Emberwood Sap for the
        // Hyjal tiers); 1/2/3 = Upgrade Tokens / Artifact Essence / Emberwood Sap for every item.
        uint32 currency = 0;

        uint32 rerollCost = 2;      // first reroll of a line
        uint32 costIncrease = 1;    // added for every earlier reroll on the same item
        uint32 maxCost = 20;        // per line, before the quality factor; 0 = no cap
        uint32 addCost = 5;         // times the lines the item holds once the add is done
        uint32 rerollMoney = 0;     // copper per rerolled line
        uint32 addMoney = 0;        // copper per added line

        // Price factor per item quality, poor .. legendary.
        std::array<uint32, ITEM_QUALITY_LEGENDARY + 1> qualityFactor = { 1, 1, 1, 2, 3, 4 };

        void Load()
        {
            enabled = sConfigMgr->GetOption<bool>("DC.RandomEnchants.Reroll.Enable", true);
            allowAdd = sConfigMgr->GetOption<bool>("DC.RandomEnchants.Reroll.AllowAdd", true);
            allowRerollAll = sConfigMgr->GetOption<bool>("DC.RandomEnchants.Reroll.AllowRerollAll", true);
            blockInCombat = sConfigMgr->GetOption<bool>("DC.RandomEnchants.Reroll.BlockInCombat", true);
            currency = sConfigMgr->GetOption<uint32>("DC.RandomEnchants.Reroll.Currency", 0);
            rerollCost = sConfigMgr->GetOption<uint32>("DC.RandomEnchants.Reroll.Cost", 2);
            costIncrease = sConfigMgr->GetOption<uint32>("DC.RandomEnchants.Reroll.CostIncrease", 1);
            maxCost = sConfigMgr->GetOption<uint32>("DC.RandomEnchants.Reroll.MaxCost", 20);
            addCost = sConfigMgr->GetOption<uint32>("DC.RandomEnchants.Reroll.AddCost", 5);
            rerollMoney = sConfigMgr->GetOption<uint32>("DC.RandomEnchants.Reroll.MoneyCost", 0);
            addMoney = sConfigMgr->GetOption<uint32>("DC.RandomEnchants.Reroll.AddMoneyCost", 0);

            if (currency > DarkChaos::ItemUpgrade::CURRENCY_FRONTIER_SAP)
            {
                LOG_WARN("scripts.dc", "DC-RandomEnchants: DC.RandomEnchants.Reroll.Currency = {} is not a "
                    "currency (0-3); using the item's upgrade currency", currency);
                currency = 0;
            }

            std::string const factors = sConfigMgr->GetOption<std::string>(
                "DC.RandomEnchants.Reroll.QualityCostFactor", "1 1 1 2 3 4");
            LoadQualityFactors(factors);
        }

        // "1 1 1 2 3 4": one factor per quality from poor up. A short list repeats its last
        // value for the qualities it leaves out; an unreadable one keeps the defaults.
        void LoadQualityFactors(std::string const& text)
        {
            std::array<uint32, ITEM_QUALITY_LEGENDARY + 1> parsed{};
            std::size_t count = 0;
            for (std::string_view token : Acore::Tokenize(text, ' ', false))
            {
                if (count == parsed.size())
                    break;

                Optional<uint32> value = Acore::StringTo<uint32>(token);
                if (!value)
                {
                    LOG_WARN("scripts.dc", "DC-RandomEnchants: DC.RandomEnchants.Reroll.QualityCostFactor "
                        "\"{}\" is not a list of numbers; keeping the defaults", text);
                    return;
                }

                parsed[count++] = *value;
            }

            if (!count)
                return;

            for (std::size_t i = count; i < parsed.size(); ++i)
                parsed[i] = parsed[count - 1];

            qualityFactor = parsed;
        }
    };

    RerollConfig sRerollConfig;

    // Reroll counts already read from (or written to) dc_item_random_enchant_rerolls, by item
    // guid. Requests can arrive off the world thread, so it is locked.
    std::mutex s_CountMutex;
    std::unordered_map<uint32, uint32> s_RerollCounts;

    bool TryGetCachedCount(uint32 itemGuidLow, uint32& count)
    {
        std::lock_guard<std::mutex> lock(s_CountMutex);
        auto itr = s_RerollCounts.find(itemGuidLow);
        if (itr == s_RerollCounts.end())
            return false;

        count = itr->second;
        return true;
    }

    // Files a count read from the DB unless a newer one is cached already (a reroll that
    // finished while the read was in flight) and returns whichever is cached.
    uint32 RememberLoadedCount(uint32 itemGuidLow, uint32 loaded)
    {
        std::lock_guard<std::mutex> lock(s_CountMutex);
        return s_RerollCounts.emplace(itemGuidLow, loaded).first->second;
    }

    void StoreCount(uint32 itemGuidLow, uint32 count)
    {
        std::lock_guard<std::mutex> lock(s_CountMutex);
        s_RerollCounts[itemGuidLow] = count;
    }

    uint32 ClampToUInt32(uint64 value)
    {
        return static_cast<uint32>(std::min<uint64>(value, std::numeric_limits<uint32>::max()));
    }

    uint32 QualityFactor(Item const* item)
    {
        ItemTemplate const* proto = item->GetTemplate();
        uint32 const quality = proto ? proto->Quality : uint32(ITEM_QUALITY_NORMAL);
        return sRerollConfig.qualityFactor[std::min<uint32>(quality, ITEM_QUALITY_LEGENDARY)];
    }

    DarkChaos::ItemUpgrade::CurrencyType ResolveCurrency(Item const* item)
    {
        using namespace DarkChaos::ItemUpgrade;

        if (sRerollConfig.currency != 0)
            return static_cast<CurrencyType>(sRerollConfig.currency);

        // Same tier lookup the upgrade window prices with, so a Hyjal item asks for the sap it
        // is upgraded with. An item outside every tier falls through to Upgrade Tokens.
        uint8 tier = TIER_INVALID;
        if (UpgradeManager* mgr = GetUpgradeManager())
            tier = mgr->GetItemTier(item->GetEntry());

        return GetTierCurrency(tier);
    }

    // One line's reroll price before the quality factor, `rerollCount` rerolls in.
    uint64 LinePrice(uint32 rerollCount)
    {
        uint64 price = uint64(sRerollConfig.rerollCost) + uint64(rerollCount) * sRerollConfig.costIncrease;
        if (sRerollConfig.maxCost)
            price = std::min<uint64>(price, sRerollConfig.maxCost);

        return price;
    }

    // Lines below the configured maximum that hold an enchant. Lines above it (left behind
    // when MaxEnchantsPerItem was lowered) are kept but not offered.
    std::vector<uint8> FilledLines(Lines const& lines)
    {
        std::vector<uint8> filled;
        uint8 const maxLines = GetMaxLines();
        for (uint8 line = 0; line < maxLines; ++line)
        {
            if (lines[line])
                filled.push_back(line);
        }

        return filled;
    }

    uint8 FirstFreeLine(Lines const& lines)
    {
        uint8 const maxLines = GetMaxLines();
        for (uint8 line = 0; line < maxLines; ++line)
        {
            if (!lines[line])
                return line;
        }

        return MAX_LINES;
    }

    char const* ActionName(Action action)
    {
        switch (action)
        {
            case Action::RerollLine:
                return "reroll";
            case Action::AddLine:
                return "add";
            case Action::RerollAll:
                return "rerollAll";
        }

        return "unknown";
    }

    class DCRandomEnchantsRerollWorldScript : public WorldScript
    {
    public:
        DCRandomEnchantsRerollWorldScript() : WorldScript("DCRandomEnchantsRerollWorldScript",
            { WORLDHOOK_ON_AFTER_CONFIG_LOAD }) {}

        void OnAfterConfigLoad(bool /*reload*/) override
        {
            sRerollConfig.Load();
        }
    };
}

namespace DarkChaos::RandomEnchants::Reroll
{
    bool IsEnabled()
    {
        return sRerollConfig.enabled && DarkChaos::RandomEnchants::IsEnabled();
    }

    bool IsActionAllowed(Action action)
    {
        switch (action)
        {
            case Action::RerollLine:
                return true;
            case Action::AddLine:
                return sRerollConfig.allowAdd;
            case Action::RerollAll:
                return sRerollConfig.allowRerollAll;
        }

        return false;
    }

    bool IsBlockedByCombat(Player* player)
    {
        // GM mode bypasses the gate, as for upgrades, so rerolls stay testable in combat.
        if (!player || player->IsGameMaster() || !sRerollConfig.blockInCombat)
            return false;

        return player->IsInCombat();
    }

    uint32 GetCostIncrease()
    {
        return sRerollConfig.costIncrease;
    }

    Price Quote(Item const* item, Action action, uint32 rerollCount)
    {
        Price price;
        if (!item)
            return price;

        DarkChaos::ItemUpgrade::CurrencyType const currency = ResolveCurrency(item);
        price.currency = static_cast<uint8>(currency);
        price.currencyItemId = DarkChaos::ItemUpgrade::GetCurrencyItemId(currency);

        std::size_t const filled = FilledLines(GetLines(item)).size();
        uint64 amount = 0;
        uint64 money = 0;

        switch (action)
        {
            case Action::RerollLine:
                amount = LinePrice(rerollCount);
                money = sRerollConfig.rerollMoney;
                break;
            case Action::RerollAll:
                // Priced like rerolling the lines one after another.
                for (std::size_t i = 0; i < filled; ++i)
                    amount += LinePrice(rerollCount + static_cast<uint32>(i));
                money = uint64(sRerollConfig.rerollMoney) * filled;
                break;
            case Action::AddLine:
                amount = uint64(sRerollConfig.addCost) * (filled + 1);
                money = sRerollConfig.addMoney;
                break;
        }

        price.amount = ClampToUInt32(amount * QualityFactor(item));
        price.money = static_cast<uint32>(std::min<uint64>(money, MAX_MONEY_AMOUNT));
        return price;
    }

    void WithRerollCount(Player* player, Item* item, std::function<void(Player*, Item*, uint32)> continuation)
    {
        if (!player || !item || !continuation)
            return;

        uint32 const itemGuidLow = item->GetGUID().GetCounter();
        uint32 cached = 0;
        if (TryGetCachedCount(itemGuidLow, cached))
        {
            continuation(player, item, cached);
            return;
        }

        ObjectGuid const playerGuid = player->GetGUID();
        ObjectGuid const itemGuid = item->GetGUID();
        DCAddon::EnqueueQueryCallback(CharacterDatabase.AsyncQuery(Acore::StringFormat(
            "SELECT reroll_count FROM dc_item_random_enchant_rerolls WHERE item_guid = {}", itemGuidLow))
            .WithCallback([playerGuid, itemGuid, continuation](QueryResult result)
        {
            uint32 const count = RememberLoadedCount(itemGuid.GetCounter(),
                result ? (*result)[0].Get<uint32>() : 0);

            Player* owner = ObjectAccessor::FindPlayer(playerGuid);
            if (!owner || !owner->GetSession())
                return;

            continuation(owner, owner->GetItemByGuid(itemGuid), count);
        }));
    }

    Outcome Execute(Player* player, Item* item, Request const& request, uint32 rerollCount)
    {
        Outcome outcome;
        outcome.rerollCount = rerollCount;

        auto fail = [&outcome](Error error)
        {
            outcome.error = error;
            return outcome;
        };

        if (!IsEnabled())
            return fail(Error::Disabled);

        if (!player || !item)
            return fail(Error::ItemNotFound);

        if (IsBlockedByCombat(player))
            return fail(Error::InCombat);

        if (item->IsInTrade())
            return fail(Error::InTrade);

        if (GetEligibility(item) != Eligibility::Eligible)
            return fail(Error::NotEligible);

        if (!IsActionAllowed(request.action))
            return fail(Error::ActionDisabled);

        Lines const before = GetLines(item);
        outcome.before = before;
        outcome.after = before;

        // The window quotes a price for the lines it shows. If they moved since (a second click
        // queued behind the first, another window), charging now would buy something the player
        // never saw.
        if (request.hasExpected && request.expected != before)
            return fail(Error::ItemChanged);

        std::vector<uint8> targets;
        switch (request.action)
        {
            case Action::RerollLine:
                if (request.line >= GetMaxLines())
                    return fail(Error::InvalidLine);
                if (!before[request.line])
                    return fail(Error::NothingToReroll);
                targets.push_back(request.line);
                break;
            case Action::AddLine:
            {
                uint8 const freeLine = FirstFreeLine(before);
                if (freeLine >= MAX_LINES)
                    return fail(Error::NoFreeLine);
                if (request.line != freeLine)
                    return fail(Error::InvalidLine);
                targets.push_back(freeLine);
                break;
            }
            case Action::RerollAll:
                targets = FilledLines(before);
                if (targets.empty())
                    return fail(Error::NothingToReroll);
                break;
        }

        // Every new line is rolled before anything is charged, so a pool that runs dry costs
        // nothing. A new line never repeats an enchant the item holds or held a moment ago.
        std::unordered_set<uint32> exclude;
        for (uint32 enchantId : before)
        {
            if (enchantId)
                exclude.insert(enchantId);
        }

        Lines after = before;
        for (uint8 line : targets)
        {
            uint32 const enchantId = RollLine(item, exclude);
            if (!enchantId)
                return fail(Error::NoCandidate);

            after[line] = enchantId;
            exclude.insert(enchantId);
        }

        Price const price = Quote(item, request.action, rerollCount);
        outcome.price = price;

        if (price.amount && player->GetItemCount(price.currencyItemId) < price.amount)
            return fail(Error::NotEnoughCurrency);

        if (price.money && !player->HasEnoughMoney(price.money))
            return fail(Error::NotEnoughMoney);

        if (price.amount)
            player->DestroyItemCount(price.currencyItemId, price.amount, true);

        if (price.money)
            player->ModifyMoney(-static_cast<int32>(price.money));

        for (uint8 line : targets)
            SetLine(player, item, line, after[line]);

        outcome.after = after;

        // Adding a line is not a reroll: it does not push the reroll price up.
        uint32 const rerolled = request.action == Action::AddLine ? 0 : static_cast<uint32>(targets.size());
        outcome.rerollCount = rerollCount + rerolled;

        uint32 const itemGuidLow = item->GetGUID().GetCounter();
        if (rerolled)
            StoreCount(itemGuidLow, outcome.rerollCount);

        // The spent currency, the gold and the new enchants go to the DB in one transaction with
        // the count and the log row, the way trade and mail save, so a crash before the next
        // character save cannot hand the currency back and keep the new lines (or the reverse).
        CharacterDatabaseTransaction trans = CharacterDatabase.BeginTransaction();
        player->SaveInventoryAndGoldToDB(trans);
        if (rerolled)
        {
            trans->Append("REPLACE INTO dc_item_random_enchant_rerolls (item_guid, reroll_count) VALUES ({}, {})",
                itemGuidLow, outcome.rerollCount);
        }
        trans->Append("INSERT INTO dc_item_random_enchant_log (player_guid, item_guid, item_entry, `action`, "
            "old_line_1, old_line_2, old_line_3, new_line_1, new_line_2, new_line_3, "
            "currency_type, currency_amount, money) VALUES ({}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {})",
            player->GetGUID().GetCounter(), itemGuidLow, item->GetEntry(), static_cast<uint32>(request.action),
            before[0], before[1], before[2], after[0], after[1], after[2],
            static_cast<uint32>(price.currency), price.amount, price.money);
        CharacterDatabase.CommitTransaction(trans);

        // The native tooltip caches a snapshot per item revision; without the bump it keeps
        // drawing the old lines.
        if (DarkChaos::ItemUpgrade::UpgradeManager* mgr = DarkChaos::ItemUpgrade::GetUpgradeManager())
            mgr->InvalidateTooltipSnapshot(itemGuidLow);

        LOG_INFO("scripts.dc", "DC-RandomEnchants: {} {} on item {} (entry {}): [{}, {}, {}] -> [{}, {}, {}], "
            "paid {} x item {} + {} copper, reroll count {}",
            player->GetName(), ActionName(request.action), itemGuidLow, item->GetEntry(),
            before[0], before[1], before[2], after[0], after[1], after[2],
            price.amount, price.currencyItemId, price.money, outcome.rerollCount);

        return outcome;
    }

    char const* DescribeError(Error error)
    {
        switch (error)
        {
            case Error::None:
                return "";
            case Error::Disabled:
                return "Enchant rerolling is switched off on this realm.";
            case Error::InCombat:
                return "You cannot reroll enchants in combat.";
            case Error::ItemNotFound:
                return "That item is no longer in your inventory.";
            case Error::NotEligible:
                return "This item cannot hold random enchants.";
            case Error::ActionDisabled:
                return "That option is switched off on this realm.";
            case Error::InvalidLine:
                return "That enchant line does not exist.";
            case Error::ItemChanged:
                return "The item changed since the window was drawn. Check the new lines and try again.";
            case Error::NothingToReroll:
                return "There is no enchant on that line to reroll.";
            case Error::NoFreeLine:
                return "Every enchant line on this item is already filled.";
            case Error::NoCandidate:
                return "No other enchant is available for this item.";
            case Error::NotEnoughCurrency:
                return "You cannot afford that.";
            case Error::NotEnoughMoney:
                return "You do not have enough gold.";
            case Error::InTrade:
                return "Take the item out of the trade window first.";
        }

        return "Unknown error.";
    }
}

void AddSC_dc_random_enchants_reroll()
{
    new DCRandomEnchantsRerollWorldScript();
}
