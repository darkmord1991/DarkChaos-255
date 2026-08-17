/*
 * Heirloom Cache GameObjects Script
 *
 * Handles the world "cache" gameobjects for the Tier 3 heirloom set
 * (gameobject_template 1991001-1991048). Each cache grants exactly ONE heirloom -
 * the item listed in its gameobject_loot_template row - directly to the looter,
 * bypassing the loot window and any bind-confirmation dialogs.
 *
 * A cache is hidden (CanBeSeen = false) and refuses to open (OnGossipHello) for any
 * player who already owns that heirloom - either physically (inventory/bank) or as an
 * account-wide DC Collection unlock - so players never see or loot a duplicate.
 */

#include "GameObjectScript.h"
#include "GameObjectAI.h"
#include "Player.h"
#include "GameObject.h"
#include "ObjectMgr.h"
#include "Chat.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "DC/AddonExtension/dc_addon_collection.h"

#include <ctime>
#include <unordered_map>
#include <utility>

namespace
{
    // Resolve the single heirloom item a cache grants, from its chest lootId (Data1).
    // Cached per lootId after the first lookup so CanBeSeen never queries the DB on a
    // visibility tick (only once per distinct cache type, ever).
    uint32 ResolveCacheHeirloomItem(GameObject* go)
    {
        static std::unordered_map<uint32, uint32> s_lootItemCache;

        if (!go)
            return 0;

        uint32 const lootId = go->GetGOInfo()->GetLootId();
        if (!lootId)
            return 0;

        auto const cached = s_lootItemCache.find(lootId);
        if (cached != s_lootItemCache.end())
            return cached->second;

        uint32 itemId = 0;
        if (QueryResult result = WorldDatabase.Query(
                "SELECT `Item` FROM `gameobject_loot_template` WHERE `Entry` = {} ORDER BY `Chance` DESC LIMIT 1", lootId))
        {
            itemId = (*result)[0].Get<uint32>();
        }

        s_lootItemCache[lootId] = itemId;
        return itemId;
    }

    // True when the player already owns/collected the heirloom.
    // Physical possession is an in-memory check; the account-wide collection lookup is a
    // DB query cached per (account, item) for 60s so repeated visibility checks stay cheap.
    bool AlreadyHasHeirloom(Player* player, uint32 itemId)
    {
        if (!player || !itemId)
            return false;

        // Immediate, no DB: covers the item just looted (or otherwise held/banked).
        if (player->HasItemCount(itemId, 1, true))
            return true;

        WorldSession const* session = player->GetSession();
        if (!session)
            return false;

        uint32 const accountId = session->GetAccountId();
        if (!accountId)
            return false;

        static std::unordered_map<uint64, std::pair<time_t, bool>> s_ownedCache;
        uint64 const key = (static_cast<uint64>(accountId) << 32) | itemId;
        time_t const now = time(nullptr);

        auto const cached = s_ownedCache.find(key);
        if (cached != s_ownedCache.end() && (now - cached->second.first) < 60)
            return cached->second.second;

        bool const owned = DCCollection::HasCollectionItem(
            accountId, DCCollection::CollectionType::HEIRLOOM, itemId);
        s_ownedCache[key] = { now, owned };
        return owned;
    }
}

class go_heirloom_cache : public GameObjectScript
{
public:
    go_heirloom_cache() : GameObjectScript("go_heirloom_cache") { }

    struct go_heirloom_cacheAI : public GameObjectAI
    {
        explicit go_heirloom_cacheAI(GameObject* gameObject) : GameObjectAI(gameObject) { }

        bool CanBeSeen(Player const* seer) override
        {
            if (!seer)
                return false;

            if (seer->IsGameMaster())
                return true;

            uint32 const itemId = ResolveCacheHeirloomItem(me);
            if (!itemId)
                return true; // Misconfigured cache (no loot) - stay visible so it is noticed.

            // Hide the cache once the player owns/collected its heirloom.
            return !AlreadyHasHeirloom(const_cast<Player*>(seer), itemId);
        }
    };

    GameObjectAI* GetAI(GameObject* go) const override
    {
        return new go_heirloom_cacheAI(go);
    }

    bool OnGossipHello(Player* player, GameObject* go) override
    {
        if (!player || !go)
            return false;

        uint32 const itemId = ResolveCacheHeirloomItem(go);
        if (!itemId)
        {
            player->SendEquipError(EQUIP_ERR_ITEM_NOT_FOUND, nullptr, nullptr);
            return true;
        }

        // Keep interaction consistent with visibility: no duplicates.
        if (AlreadyHasHeirloom(player, itemId))
        {
            ChatHandler(player->GetSession()).PSendSysMessage("You have already collected this heirloom.");
            return true;
        }

        // Already looted / mid-despawn.
        if (go->getLootState() == GO_ACTIVATED || go->getLootState() == GO_JUST_DEACTIVATED)
            return false;

        if (!player->AddItem(itemId, 1))
        {
            player->SendEquipError(EQUIP_ERR_BAG_FULL, nullptr, nullptr);
            return true;
        }

        LOG_DEBUG("scripts.dc", "go_heirloom_cache: player {} looted heirloom {} from cache entry {}",
            player->GetName(), itemId, go->GetEntry());

        // Consume the cache (consumable=1 in gameobject_template -> despawns).
        go->SetLootState(GO_ACTIVATED, player);
        go->SetGoState(GO_STATE_ACTIVE);
        return true;
    }
};

// Add the script to the script loader
void AddSC_go_heirloom_cache()
{
    new go_heirloom_cache();
}
