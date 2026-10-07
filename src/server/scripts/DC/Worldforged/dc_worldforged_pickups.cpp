/*
 * Worldforged pickups (maps 750 / 751) - one loot per character, ported from Ascension CoA.
 *
 * The pickups are data: non-consumable chests (gameobject_template ScriptName
 * 'go_dc_worldforged_pickup', Data3 = 0) whose loot table holds exactly one item, spawned in guid
 * block 6900001+ by Custom/Documentation/scripts/worldforged/gen_worldforged_750_751.py. This
 * script adds the rule the data cannot express: each character may loot each pickup once, ever.
 *
 *  - A claim is one bit per spawn in the character's "dc-worldforged" character_settings row
 *    (bit = spawn guid - WorldforgedGuidFirst). Player settings load with the login query holder
 *    and save in the same transaction as the inventory, so the item and its claim persist together.
 *  - A claimed pickup is invisible to that character (CanBeSeen), refuses to open (GossipHello) and
 *    withholds its item (OnAllowedForPlayerLootCheck). The last closes the race where two characters
 *    share one chest's loot object. GMs still see every pickup.
 *  - Unclaimed pickups sparkle through the core's lootable-chest sparkle
 *    (Visibility.ObjectSparkles.Lootables), and a looted chest returns to GO_READY with a visibility
 *    update, which is what hides it from the character who just claimed it.
 *  - Playerbots loot pickups like players, one claim per bot character. mod-playerbots skips loot a bot
 *    cannot see (LootObject::IsLootPossible), so a claimed pickup drops off that bot's loot list.
 */

#include "Chat.h"
#include "GameObject.h"
#include "GameObjectAI.h"
#include "GameObjectScript.h"
#include "GlobalScript.h"
#include "Item.h"
#include "Log.h"
#include "Map.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "PlayerScript.h"
#include "World.h"
#include "WorldScript.h"

#include <string>

namespace
{
    constexpr char const* WorldforgedScriptName = "go_dc_worldforged_pickup";
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

    // Player settings are only ever touched on the owning player's map thread: visibility, loot and
    // the loot hooks all run there.
    bool HasClaimed(Player* player, ObjectGuid::LowType spawnId)
    {
        uint32 const offset = spawnId - WorldforgedGuidFirst;
        return player->GetPlayerSetting(WorldforgedSettingSource, offset / 32).HasFlag(1u << (offset % 32));
    }

    void Claim(Player* player, ObjectGuid::LowType spawnId)
    {
        uint32 const offset = spawnId - WorldforgedGuidFirst;
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
                ChatHandler(player->GetSession()).SendSysMessage("You have already taken what was left here.");
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
    dc_worldforged_pickup_claims() : PlayerScript("dc_worldforged_pickup_claims", { PLAYERHOOK_ON_LOOT_ITEM }) { }

    void OnPlayerLootItem(Player* player, Item* item, uint32 /*count*/, ObjectGuid lootguid) override
    {
        if (!player || !item || !lootguid.IsGameObject())
            return;

        GameObject* go = player->GetMap()->GetGameObject(lootguid);
        if (!IsWorldforgedPickup(go))
            return;

        Claim(player, go->GetSpawnId());
        LOG_DEBUG("scripts.dc", "Worldforged: {} claimed pickup {} (item {})", player->GetName(), go->GetSpawnId(),
            item->GetEntry());
    }
};

class dc_worldforged_pickup_startup : public WorldScript
{
public:
    dc_worldforged_pickup_startup() : WorldScript("dc_worldforged_pickup_startup", { WORLDHOOK_ON_STARTUP }) { }

    void OnStartup() override
    {
        if (sWorld->getBoolConfig(CONFIG_PLAYER_SETTINGS_ENABLED))
            return;

        LOG_ERROR("scripts.dc", "Worldforged pickups: EnablePlayerSettings = 0, so claims are not saved and "
            "every pickup can be looted again after a relog. Set EnablePlayerSettings = 1.");
    }
};

void AddSC_dc_worldforged_pickups()
{
    new go_dc_worldforged_pickup();
    new dc_worldforged_pickup_loot_veto();
    new dc_worldforged_pickup_claims();
    new dc_worldforged_pickup_startup();
}
