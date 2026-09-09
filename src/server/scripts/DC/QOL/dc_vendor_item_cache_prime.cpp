/*
 * DarkChaos QoL - Vendor item cache priming
 *
 * The 3.3.5 client resolves a vendor row's name, icon and tooltip from its own
 * item cache. Anything not in that cache costs a CMSG_ITEM_QUERY_SINGLE round
 * trip, and that opcode is PROCESS_THREADSAFE - it is answered inside
 * Map::Update, so its latency is the map tick. Under a heavy bot population the
 * tick is long enough that vendor rows sit nameless and tooltips stay empty for
 * seconds.
 *
 * DC realms make this worse than stock: most vendor stock is custom (Mythic+
 * tokens, Frontier gear, upgrade tiers), so a client is guaranteed to miss on
 * it the first time regardless of how long it has been playing.
 *
 * This pushes SMSG_ITEM_QUERY_SINGLE_RESPONSE for the vendor's stock from the
 * OnPlayerSendListInventory hook, i.e. before SMSG_LIST_INVENTORY reaches the
 * wire. The client accepts unsolicited responses and files them in the same
 * cache, so the merchant frame draws complete on its first update and the
 * round trip never happens.
 *
 * The alternate-currency items referenced by a row's extended cost are primed
 * the same way, so token / sap prices render with their icon and count instead
 * of a blank.
 *
 * Cost is bounded: each entry is pushed at most once per session (the client
 * keeps it for the rest of the session either way), so re-opening a vendor or
 * visiting a vendor that shares stock is free.
 */

#include "ScriptMgr.h"
#include "Config.h"
#include "Creature.h"
#include "DBCStores.h"
#include "Log.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "WorldSession.h"

#include <mutex>
#include <unordered_map>
#include <unordered_set>

namespace
{

struct VendorPrimeConfig
{
    bool enabled = true;
    uint32 maxPerOpen = 250;
    uint32 maxTrackedPerSession = 8192;

    void Load()
    {
        enabled = sConfigMgr->GetOption<bool>("DC.Vendor.PrimeItemCache.Enable", true);
        maxPerOpen = sConfigMgr->GetOption<uint32>("DC.Vendor.PrimeItemCache.MaxPerOpen", 250);
        maxTrackedPerSession =
            sConfigMgr->GetOption<uint32>("DC.Vendor.PrimeItemCache.MaxTrackedPerSession", 8192);
    }
};

VendorPrimeConfig sVendorPrimeConfig;

// guid -> entries already pushed to that session. Cleared on logout.
std::unordered_map<ObjectGuid, std::unordered_set<uint32>> sPrimedEntries;
std::mutex sPrimedEntriesMutex;

} // namespace

class DCVendorItemCachePrimeWorldScript : public WorldScript
{
public:
    DCVendorItemCachePrimeWorldScript()
        : WorldScript("DCVendorItemCachePrimeWorldScript", { WORLDHOOK_ON_AFTER_CONFIG_LOAD }) { }

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        sVendorPrimeConfig.Load();
    }
};

class DCVendorItemCachePrimePlayerScript : public PlayerScript
{
public:
    DCVendorItemCachePrimePlayerScript()
        : PlayerScript("DCVendorItemCachePrimePlayerScript",
        {
            PLAYERHOOK_ON_SEND_LIST_INVENTORY, PLAYERHOOK_ON_LOGOUT
        }) { }

    void OnPlayerLogout(Player* player) override
    {
        if (!player)
            return;

        std::lock_guard<std::mutex> lock(sPrimedEntriesMutex);
        sPrimedEntries.erase(player->GetGUID());
    }

    void OnPlayerSendListInventory(Player* player, ObjectGuid vendorGuid, uint32& vendorEntry) override
    {
        if (!sVendorPrimeConfig.enabled || !player)
            return;

        WorldSession* session = player->GetSession();
        // Bots have no client and therefore no item cache to prime; pushing at
        // them is pure waste (see DCAddon::IsBotRecipient for the same gate on
        // the addon protocol).
        if (!session || session->IsBot())
            return;

        Creature* vendor = player->GetNPCIfCanInteractWith(vendorGuid, UNIT_NPC_FLAG_VENDOR);
        if (!vendor)
            return;

        VendorItemData const* items =
            vendorEntry ? sObjectMgr->GetNpcVendorItemList(vendorEntry) : vendor->GetVendorItems();
        if (!items)
            return;

        std::lock_guard<std::mutex> lock(sPrimedEntriesMutex);
        std::unordered_set<uint32>& primed = sPrimedEntries[player->GetGUID()];

        uint32 pushed = 0;
        uint8 const itemCount = items->GetItemCount();

        // Returns false only when the push budget is spent, i.e. "stop walking the
        // list"; a skipped entry still returns true.
        auto prime = [&](uint32 entry) -> bool
        {
            if (pushed >= sVendorPrimeConfig.maxPerOpen)
                return false;

            if (!entry)
                return true;

            // A missing template is dropped by SendListInventory anyway, and the
            // "unknown item" response would only poison the client's cache.
            if (!sObjectMgr->GetItemTemplate(entry))
                return true;

            if (!primed.insert(entry).second)
                return true;

            if (primed.size() > sVendorPrimeConfig.maxTrackedPerSession)
            {
                // Session has seen an implausible amount of distinct stock; stop
                // tracking rather than growing without bound. Later opens fall
                // back to the client's own query, which still works.
                primed.clear();
                return false;
            }

            session->SendItemQueryResponse(entry);
            ++pushed;
            return true;
        };

        for (uint8 slot = 0; slot < itemCount; ++slot)
        {
            VendorItem const* item = items->GetItem(slot);
            if (!item)
                continue;

            if (!prime(item->item))
                break;

            // Rows priced in an alternate currency draw that currency's icon and
            // count in the vendor row and in the tooltip's cost line, so the
            // client needs those item entries cached too. On a token vendor they
            // are the same handful of entries on every row, so the de-dup set
            // makes this nearly free.
            if (!item->ExtendedCost)
                continue;

            ItemExtendedCostEntry const* cost = sItemExtendedCostStore.LookupEntry(item->ExtendedCost);
            if (!cost)
                continue;

            for (uint8 i = 0; i < MAX_ITEM_EXTENDED_COST_REQUIREMENTS; ++i)
            {
                if (!cost->reqitem[i])
                    continue;

                if (!prime(cost->reqitem[i]))
                    break;
            }
        }

        if (pushed)
        {
            LOG_DEBUG("scripts.dc", "VendorItemCachePrime: pushed {} item responses to {} for vendor {}",
                pushed, player->GetName(), vendor->GetEntry());
        }
    }
};

void AddSC_dc_vendor_item_cache_prime_qol()
{
    new DCVendorItemCachePrimeWorldScript();
    new DCVendorItemCachePrimePlayerScript();
}
