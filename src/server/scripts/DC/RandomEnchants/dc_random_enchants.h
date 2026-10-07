/*
 * DarkChaos Random Enchants - shared interface
 *
 * The rolled lines live in PROP_ENCHANTMENT_SLOT_0 .. PROP_ENCHANTMENT_SLOT_0 + MAX_LINES - 1 of
 * an item whose random property id is 0. Everything outside the acquisition hooks that reads or
 * changes them (the reroll service, the item upgrade window) goes through this header, so the
 * enchant pools, the eligibility gate and the tier roll exist exactly once.
 */

#ifndef DC_RANDOM_ENCHANTS_H
#define DC_RANDOM_ENCHANTS_H

#include "Define.h"

#include <array>
#include <functional>
#include <string>
#include <unordered_set>

class Item;
class Player;

namespace DarkChaos::RandomEnchants
{
    // Lines an item can hold; also the cap of DC.RandomEnchants.MaxEnchantsPerItem.
    constexpr uint8 MAX_LINES = 3;

    // Enchant id per line, 0 for an empty line.
    using Lines = std::array<uint32, MAX_LINES>;

    enum class Eligibility : uint8
    {
        Eligible,
        SystemDisabled,     // DC.RandomEnchants.Enable = 0, or no enchant pool is loaded
        NotWeaponOrArmor,   // not a weapon or armor piece, or that class is switched off
        QualityOutOfRange,  // outside DC.RandomEnchants.MinQuality .. MaxQuality
        HasRandomProperty,  // a stock random property / suffix owns the property slots
    };

    // The subsystem is switched on and its enchant pool is loaded.
    bool IsEnabled();

    // DC.RandomEnchants.MaxEnchantsPerItem (1 - MAX_LINES).
    uint8 GetMaxLines();

    Eligibility GetEligibility(Item const* item);
    std::string DescribeEligibility(Eligibility eligibility);

    Lines GetLines(Item const* item);

    // Pool tier (1 - 5) of a rolled enchant; 0 when the enchant is not in the pool.
    uint8 GetEnchantTier(uint32 enchantId);

    // One fresh roll for `item`: a tier from its quality, then an enchant from that tier's pool
    // for the item's class that is not in `exclude`. 0 when the pool has nothing left to offer.
    uint32 RollLine(Item const* item, std::unordered_set<uint32> const& exclude);

    // Writes `enchantId` into line `index` (0 clears it). On an equipped item the old line's
    // effects come off and the new line's go on, so stats, auras and the upgrade scaling of the
    // property slots stay in step.
    void SetLine(Player* player, Item* item, uint8 index, uint32 enchantId);
}

// ---------------------------------------------------------------------------------------------
// Reroll service (DC.RandomEnchants.Reroll.*): pay to reroll one line, reroll every line, or
// add a line to an empty slot. Driven by the item upgrade window over the UPG addon module
// (dc_addon_enchant_reroll.cpp); implemented in dc_random_enchants_reroll.cpp.
// ---------------------------------------------------------------------------------------------
namespace DarkChaos::RandomEnchants::Reroll
{
    enum class Action : uint8
    {
        RerollLine = 1,  // replace one filled line
        AddLine    = 2,  // fill the first empty line
        RerollAll  = 3,  // replace every filled line
    };

    // Wire values: the addon shows its own text per code, so never renumber.
    enum class Error : uint8
    {
        None              = 0,
        Disabled          = 1,   // rerolling or the random enchant system is switched off
        InCombat          = 2,
        ItemNotFound      = 3,
        NotEligible       = 4,
        ActionDisabled    = 5,   // DC.RandomEnchants.Reroll.AllowAdd / AllowRerollAll = 0
        InvalidLine       = 6,
        ItemChanged       = 7,   // the client priced an older state of the item
        NothingToReroll   = 8,
        NoFreeLine        = 9,
        NoCandidate       = 10,  // the pool has no other enchant for this item
        NotEnoughCurrency = 11,
        NotEnoughMoney    = 12,
        InTrade           = 13,  // the other side of a trade already saw the old lines
    };

    struct Price
    {
        uint8 currency = 0;         // DarkChaos::ItemUpgrade::CurrencyType
        uint32 currencyItemId = 0;
        uint32 amount = 0;          // currency items
        uint32 money = 0;           // copper
    };

    struct Request
    {
        Action action = Action::RerollLine;
        uint8 line = 0;             // the line a RerollLine / AddLine targets
        bool hasExpected = false;
        Lines expected{};           // the lines the client saw when it priced the action
    };

    struct Outcome
    {
        Error error = Error::None;
        Lines before{};
        Lines after{};
        Price price;
        uint32 rerollCount = 0;     // the item's reroll count after the action
    };

    bool IsEnabled();
    bool IsActionAllowed(Action action);
    bool IsBlockedByCombat(Player* player);

    // DC.RandomEnchants.Reroll.CostIncrease: what every earlier reroll adds to a line's price.
    uint32 GetCostIncrease();

    // What `action` costs on `item` right now, given its reroll count. RerollAll prices every
    // filled line, each one a step further up the escalation.
    Price Quote(Item const* item, Action action, uint32 rerollCount);

    // Runs `continuation` with the item's reroll count: at once on a cache hit, otherwise on the
    // world thread once dc_item_random_enchant_rerolls answered. The player and the item are
    // re-resolved by guid before it runs; the item is null when it left the inventory meanwhile.
    void WithRerollCount(Player* player, Item* item,
        std::function<void(Player*, Item*, uint32)> continuation);

    // Validates, charges and applies `request`. Every new line is rolled before anything is
    // charged; on success the reroll count, the audit log and the item's tooltip revision are
    // updated.
    Outcome Execute(Player* player, Item* item, Request const& request, uint32 rerollCount);

    char const* DescribeError(Error error);
}

#endif // DC_RANDOM_ENCHANTS_H
