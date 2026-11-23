/*
 * Worldforged pickups (maps 750 / 751) - one loot per account, ported from Ascension CoA.
 *
 * The pickups are data: non-consumable chests (gameobject_template ScriptName
 * 'go_dc_worldforged_pickup', Data3 = 0) whose loot table holds exactly one item, spawned in guid
 * block 6900001+ by Custom/Documentation/scripts/worldforged/gen_worldforged_750_751.py. This
 * script adds the rule the data cannot express: each account may loot each pickup once, for good. A
 * prestige fresh start does not hand them back (decided 2026-11-21).
 *
 *  - Claims are per ACCOUNT (decided 2026-11-21): per character, every alt that reached 750/751 could take
 *    the whole set again, about 9,200 g of vendor value each. They live in characters.dc_worldforged_claims
 *    (one row per account and spawn), all loaded at startup.
 *  - In memory each account has one bit per spawn (bit = spawn guid - WorldforgedGuidFirst). Every character
 *    of the account shares those words, and playerbots log in several characters of one account at once, on
 *    different map threads, so the words are atomics. A spawn lives on exactly one map, so two threads never
 *    race for the same bit, only for different bits of one word.
 *  - A new claim is written with the character's next save (PLAYERHOOK_ON_SAVE), the same moment its
 *    inventory is saved, so a crash loses the item and the claim together rather than one of them.
 *  - Until 2026-11-21 claims were per character, in the "dc-worldforged" character_settings words. A
 *    character's login moves those into its account and clears them.
 *  - A claimed pickup is invisible to the account's characters (CanBeSeen), refuses to open (GossipHello)
 *    and withholds its item (OnAllowedForPlayerLootCheck). The last closes the race where two characters
 *    share one chest's loot object. GMs still see every pickup.
 *  - Unclaimed pickups sparkle through the core's lootable-chest sparkle
 *    (Visibility.ObjectSparkles.Lootables), and a looted chest returns to GO_READY with a visibility
 *    update, which is what hides it from the character who just claimed it.
 *  - Playerbots loot pickups like players. mod-playerbots skips loot a bot cannot see
 *    (LootObject::IsLootPossible), so a claimed pickup drops off that bot's loot list.
 *  - Without the table (its SQL not applied yet) claims still hold account-wide while the server runs, and
 *    persist per character in the old settings words; the next start with the table moves them over.
 */

#include "dc_worldforged_pickups.h"
#include "Chat.h"
#include "DC/CrossSystem/CrossSystemDbSchema.h"
#include "DC/CrossSystem/EventBus.h"
#include "DataMap.h"
#include "DatabaseEnv.h"
#include "GameObject.h"
#include "GameObjectAI.h"
#include "GameObjectScript.h"
#include "GameTime.h"
#include "GlobalScript.h"
#include "Item.h"
#include "Log.h"
#include "Map.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "PlayerScript.h"
#include "World.h"
#include "WorldScript.h"
#include "WorldSession.h"

#include <algorithm>
#include <atomic>
#include <bit>
#include <memory>
#include <mutex>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

namespace
{
    constexpr char const* WorldforgedScriptName = "go_dc_worldforged_pickup";
    constexpr char const* ClaimsTable = "dc_worldforged_claims";
    constexpr char const* PlayerStateKey = "dc_worldforged_claims";
    // The per-character claim words used until 2026-11-21; moved into the account at login.
    std::string const WorldforgedSettingSource = "dc-worldforged";

    // The spawn guid is the claim key: the generator allocates these append-only and never renumbers.
    constexpr ObjectGuid::LowType WorldforgedGuidFirst = 6900001;
    constexpr ObjectGuid::LowType WorldforgedGuidLast = 6999999;

    bool IsWorldforgedSpawn(ObjectGuid::LowType spawnId)
    {
        return spawnId >= WorldforgedGuidFirst && spawnId <= WorldforgedGuidLast;
    }

    bool IsWorldforgedPickup(GameObject const* go)
    {
        return go && go->GetGoType() == GAMEOBJECT_TYPE_CHEST && IsWorldforgedSpawn(go->GetSpawnId())
            && sObjectMgr->GetScriptName(go->GetScriptId()) == WorldforgedScriptName;
    }

    // The claim words in use: one per 32 spawns, up to the highest pickup spawned. Pickups only arrive
    // through a world DB update, so this is fixed for the server's lifetime.
    uint32 ClaimWordCount()
    {
        static uint32 const words = []
        {
            ObjectGuid::LowType last = 0;
            for (auto const& spawn : sObjectMgr->GetAllGOData())
                if (IsWorldforgedSpawn(spawn.first))
                    last = std::max(last, spawn.first);

            return last ? (last - WorldforgedGuidFirst) / 32 + 1 : 0;
        }();
        return words;
    }

    struct AccountClaims
    {
        explicit AccountClaims(uint32 words) : bits(std::make_unique<std::atomic<uint32>[]>(words)), wordCount(words) { }

        bool Has(uint32 offset) const
        {
            return offset / 32 < wordCount
                && (bits[offset / 32].load(std::memory_order_relaxed) & (1u << (offset % 32)));
        }

        // Returns false when the bit was already set.
        bool Set(uint32 offset)
        {
            if (offset / 32 >= wordCount)
                return false;

            uint32 const bit = 1u << (offset % 32);
            return !(bits[offset / 32].fetch_or(bit, std::memory_order_relaxed) & bit);
        }

        std::unique_ptr<std::atomic<uint32>[]> bits;
        uint32 const wordCount;
    };

    std::mutex sRegistryMutex;
    std::unordered_map<uint32, std::shared_ptr<AccountClaims>> sRegistry;
    // Set at startup when dc_worldforged_claims exists; until then claims persist in the old settings words.
    std::atomic<bool> sTableReady{ false };

    std::shared_ptr<AccountClaims> GetOrCreateAccount(uint32 accountId)
    {
        std::lock_guard<std::mutex> lock(sRegistryMutex);
        std::shared_ptr<AccountClaims>& entry = sRegistry[accountId];
        if (!entry)
            entry = std::make_shared<AccountClaims>(ClaimWordCount());

        return entry;
    }

    // Per character: its account's claims, and what it has claimed since its last save. Only touched on the
    // character's own map thread (visibility, loot, autosave) or by the world thread while no map updates run
    // (login, logout save).
    struct PlayerClaimState : public DataMap::Base
    {
        std::shared_ptr<AccountClaims> account;
        std::vector<ObjectGuid::LowType> unsaved;   // spawn guids
    };

    PlayerClaimState& GetState(Player* player)
    {
        PlayerClaimState* state = player->CustomData.GetDefault<PlayerClaimState>(PlayerStateKey);
        if (!state->account)
            state->account = GetOrCreateAccount(player->GetSession()->GetAccountId());

        return *state;
    }

    bool HasClaimed(Player* player, ObjectGuid::LowType spawnId)
    {
        return GetState(player).account->Has(spawnId - WorldforgedGuidFirst);
    }

    void Claim(Player* player, ObjectGuid::LowType spawnId)
    {
        uint32 const offset = spawnId - WorldforgedGuidFirst;
        PlayerClaimState& state = GetState(player);
        if (!state.account->Set(offset))
            return;

        if (sTableReady.load(std::memory_order_relaxed))
        {
            state.unsaved.push_back(spawnId);
            return;
        }

        // No table yet: keep the claim with the character, as before 2026-11-21
        PlayerSetting setting = player->GetPlayerSetting(WorldforgedSettingSource, offset / 32);
        setting.AddFlag(1u << (offset % 32));
        player->UpdatePlayerSetting(WorldforgedSettingSource, offset / 32, setting.value);
    }
}

class go_dc_worldforged_pickup : public GameObjectScript
{
public:
    go_dc_worldforged_pickup() : GameObjectScript(WorldforgedScriptName) { }

    struct go_dc_worldforged_pickupAI : public GameObjectAI
    {
        explicit go_dc_worldforged_pickupAI(GameObject* go) : GameObjectAI(go) { }

        bool CanBeSeen(Player const* seer) override
        {
            if (!seer || seer->IsGameMaster() || !IsWorldforgedSpawn(me->GetSpawnId()))
                return true;

            return !HasClaimed(const_cast<Player*>(seer), me->GetSpawnId());
        }

        // GameObject::Use asks this before Player::SendLoot; returning true stops the chest opening.
        bool GossipHello(Player* player, bool /*reportUse*/) override
        {
            if (!player || !IsWorldforgedSpawn(me->GetSpawnId()))
                return false;

            if (HasClaimed(player, me->GetSpawnId()))
            {
                ChatHandler(player->GetSession()).SendSysMessage(
                    "Someone on your account has already taken what was left here.");
                return true;
            }

            // A pickup whose item was taken under a loot window that was never released stays GO_ACTIVATED
            // with empty loot, and SendLoot only fills a GO_READY chest, so this character would get an empty
            // window. Hand it a fresh roll; the loot veto keeps that old window from taking a second copy.
            if (me->getLootState() == GO_ACTIVATED && me->loot.isLooted())
            {
                me->loot.clear();
                me->SetLootState(GO_READY);
            }

            return false;
        }
    };

    GameObjectAI* GetAI(GameObject* go) const override
    {
        return new go_dc_worldforged_pickupAI(go);
    }
};

// Asked per loot slot at the moment of the award, for every way an item can leave a loot window.
// CALL_ENABLED_BOOLEAN_HOOKS reads backwards: returning true WITHHOLDS the item.
class dc_worldforged_pickup_loot_veto : public GlobalScript
{
public:
    dc_worldforged_pickup_loot_veto() : GlobalScript("dc_worldforged_pickup_loot_veto",
        { GLOBALHOOK_ON_ALLOWED_FOR_PLAYER_LOOT_CHECK }) { }

    bool OnAllowedForPlayerLootCheck(Player const* player, ObjectGuid source) override
    {
        if (!player || !source.IsGameObject() || !player->IsInWorld())
            return false;

        GameObject* go = player->GetMap()->GetGameObject(source);
        if (!IsWorldforgedPickup(go))
            return false;

        return HasClaimed(const_cast<Player*>(player), go->GetSpawnId());
    }
};

class dc_worldforged_pickup_claims : public PlayerScript
{
public:
    dc_worldforged_pickup_claims() : PlayerScript("dc_worldforged_pickup_claims",
        { PLAYERHOOK_ON_LOOT_ITEM, PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_SAVE }) { }

    void OnPlayerLootItem(Player* player, Item* item, uint32 /*count*/, ObjectGuid lootguid) override
    {
        if (!player || !item || !lootguid.IsGameObject())
            return;

        GameObject* go = player->GetMap()->GetGameObject(lootguid);
        if (!IsWorldforgedPickup(go))
            return;

        Claim(player, go->GetSpawnId());
        LOG_DEBUG("scripts.dc", "Worldforged: {} (account {}) claimed pickup {} (item {})", player->GetName(),
            player->GetSession()->GetAccountId(), go->GetSpawnId(), item->GetEntry());

        DarkChaos::CrossSystem::EventBus::instance()->PublishFeatureUsed(player,
            DarkChaos::CrossSystem::FeatureKind::WorldforgedPickup, go->GetSpawnId());
    }

    // Adds the character's pre-2026-11-21 claim words to its account. With the table they move there: the
    // cleared words and the new rows are written together with its next save. Without it they stay where they
    // are and only join the account for this run.
    void OnPlayerLogin(Player* player) override
    {
        if (!player)
            return;

        bool const tableReady = sTableReady.load(std::memory_order_relaxed);
        PlayerClaimState& state = GetState(player);
        uint32 found = 0;

        for (uint32 word = 0; word < ClaimWordCount(); ++word)
        {
            uint32 claims = player->GetPlayerSetting(WorldforgedSettingSource, word).value;
            if (!claims)
                continue;

            found += std::popcount(claims);
            while (claims)
            {
                uint32 const bit = std::countr_zero(claims);
                claims &= claims - 1;

                uint32 const offset = word * 32 + bit;
                state.account->Set(offset);
                if (tableReady)
                    state.unsaved.push_back(WorldforgedGuidFirst + offset);
            }

            if (tableReady)
                player->UpdatePlayerSetting(WorldforgedSettingSource, word, 0);
        }

        if (!found)
            return;

        if (tableReady)
            LOG_INFO("scripts.dc", "Worldforged: moved {} claim(s) of {} into account {}", found, player->GetName(),
                player->GetSession()->GetAccountId());

        // Pickups this character saw before its claims joined the account
        player->UpdateObjectVisibility(false);
    }

    void OnPlayerSave(Player* player) override
    {
        if (!player || !sTableReady.load(std::memory_order_relaxed))
            return;

        PlayerClaimState* state = player->CustomData.Get<PlayerClaimState>(PlayerStateKey);
        if (!state || state->unsaved.empty())
            return;

        uint32 const accountId = player->GetSession()->GetAccountId();
        uint32 const characterGuid = player->GetGUID().GetCounter();
        uint32 const now = static_cast<uint32>(GameTime::GetGameTime().count());

        CharacterDatabaseTransaction trans = CharacterDatabase.BeginTransaction();
        for (ObjectGuid::LowType spawnId : state->unsaved)
            trans->Append("INSERT IGNORE INTO dc_worldforged_claims (account_id, spawn_guid, claimed_by, claimed_at) "
                "VALUES ({}, {}, {}, {})", accountId, spawnId, characterGuid, now);

        CharacterDatabase.CommitTransaction(trans);
        state->unsaved.clear();
    }
};

class dc_worldforged_pickup_startup : public WorldScript
{
public:
    dc_worldforged_pickup_startup() : WorldScript("dc_worldforged_pickup_startup", { WORLDHOOK_ON_STARTUP }) { }

    void OnStartup() override
    {
        if (!DC::DbSchema::CharacterTableExists(ClaimsTable))
        {
            LOG_ERROR("scripts.dc", "Worldforged pickups: table characters.{} is missing. Claims hold per account "
                "only until the next restart and are kept per character meanwhile; apply its SQL update.", ClaimsTable);

            if (!sWorld->getBoolConfig(CONFIG_PLAYER_SETTINGS_ENABLED))
                LOG_ERROR("scripts.dc", "Worldforged pickups: EnablePlayerSettings = 0 as well, so no claim survives "
                    "a restart.");
            return;
        }

        uint32 rows = 0;
        std::size_t accounts = 0;
        if (QueryResult result = CharacterDatabase.Query("SELECT account_id, spawn_guid FROM dc_worldforged_claims"))
        {
            std::unordered_map<uint32, std::shared_ptr<AccountClaims>> loaded;
            do
            {
                Field* fields = result->Fetch();
                uint32 const accountId = fields[0].Get<uint32>();
                ObjectGuid::LowType const spawnId = fields[1].Get<uint32>();
                if (!IsWorldforgedSpawn(spawnId))
                    continue;

                std::shared_ptr<AccountClaims>& entry = loaded[accountId];
                if (!entry)
                    entry = std::make_shared<AccountClaims>(ClaimWordCount());

                entry->Set(spawnId - WorldforgedGuidFirst);
                ++rows;
            } while (result->NextRow());

            accounts = loaded.size();
            std::lock_guard<std::mutex> lock(sRegistryMutex);
            sRegistry = std::move(loaded);
        }

        // The settings words still hold claims of characters that have not logged in since; they move at login
        sTableReady.store(true, std::memory_order_relaxed);
        LOG_INFO("server.loading", ">> Loaded {} worldforged pickup claim(s) of {} account(s)", rows, accounts);
    }
};

void AddSC_dc_worldforged_pickups()
{
    new go_dc_worldforged_pickup();
    new dc_worldforged_pickup_loot_veto();
    new dc_worldforged_pickup_claims();
    new dc_worldforged_pickup_startup();
}
