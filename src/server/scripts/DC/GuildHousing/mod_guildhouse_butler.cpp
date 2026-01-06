#include "ScriptMgr.h"
#include "Player.h"
#include "Chat.h"
#include "ScriptedCreature.h"
#include "ScriptedGossip.h"
#include "Configuration/Config.h"
#include "Creature.h"
#include "Guild.h"
#include "GuildMgr.h"
#include "Define.h"
#include "GossipDef.h"
#include "DataMap.h"
#include "GameObject.h"
#include "Transport.h"
#include "CreatureAI.h"
#include "guildhouse.h"

#include <optional>

int cost, GuildHouseInnKeeper, GuildHouseBank, GuildHouseMailBox, GuildHouseAuctioneer, GuildHouseTrainer, GuildHouseVendor, GuildHouseObject, GuildHousePortal, GuildHouseSpirit, GuildHouseProf, GuildHouseBuyRank, GuildHouseCurrency;

class GuildHouseSpawner : public CreatureScript
{

public:
    GuildHouseSpawner() : CreatureScript("GuildHouseSpawner") {}

    static constexpr uint32 ACTION_BACK = 9;
    static constexpr uint32 ACTION_GM_MENU = 9000000;
    static constexpr uint32 ACTION_GM_SPAWN_ALL = 9000001;
    static constexpr uint32 ACTION_GM_DESPAWN_ALL = 9000002;

    static bool ShouldKeepCreatureEntryOnDespawnAll(uint32 entry)
    {
        // Keep core management NPCs so the guild house remains usable.
        return entry == 95103 /*manager*/ || entry == 95104 /*butler*/ || entry == 800002 /*teleporter*/;
    }
    
    static bool SpawnPresetsHaveMapColumn()
    {
        static std::optional<bool> cached;
        if (cached.has_value())
            return cached.value();

        QueryResult result = WorldDatabase.Query(
            "SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'dc_guild_house_spawns' AND COLUMN_NAME = 'map'");

        if (!result)
        {
            cached = false;
            return false;
        }

        Field* fields = result->Fetch();
        cached = (fields[0].Get<uint64>() > 0);
        return cached.value();
    }

    struct GuildHouseSpawnerAI : public ScriptedAI
    {
        GuildHouseSpawnerAI(Creature* creature) : ScriptedAI(creature) {}

        void UpdateAI(uint32 /*diff*/) override
        {
            me->SetFlag(UNIT_NPC_FLAGS, UNIT_NPC_FLAG_GOSSIP);
        }
    };

    CreatureAI* GetAI(Creature *creature) const override
    {
        return new GuildHouseSpawnerAI(creature);
    }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (player->GetGuild())
        {
            Guild* guild = sGuildMgr->GetGuildById(player->GetGuildId());
            Guild::Member const* memberMe = guild->GetMember(player->GetGUID());

            if (!memberMe->IsRankNotLower(GuildHouseBuyRank))
            {
                ChatHandler(player->GetSession()).PSendSysMessage("You are not authorized to make Guild House purchases.");
                return false;
            }
        }
        else
        {
            ChatHandler(player->GetSession()).PSendSysMessage("You are not in a guild!");
            return false;
        }

        ClearGossipMenuFor(player);
        AddGossipItemFor(player, GOSSIP_ICON_TALK, "Spawn Innkeeper", GOSSIP_SENDER_MAIN, 800001, "Add an Innkeeper?", GuildHouseInnKeeper, false);
        AddGossipItemFor(player, GOSSIP_ICON_TALK, "Spawn Mailbox", GOSSIP_SENDER_MAIN, 184137, "Spawn a Mailbox?", GuildHouseMailBox, false);
        AddGossipItemFor(player, GOSSIP_ICON_TALK, "Spawn Stable Master", GOSSIP_SENDER_MAIN, 28690, "Spawn a Stable Master?", GuildHouseVendor, false);
        AddGossipItemFor(player, GOSSIP_ICON_TALK, "Spawn Vendor", GOSSIP_SENDER_MAIN, 3);
        AddGossipItemFor(player, GOSSIP_ICON_TALK, "Spawn Objects", GOSSIP_SENDER_MAIN, 4);
        AddGossipItemFor(player, GOSSIP_ICON_MONEY_BAG, "Spawn Bank", GOSSIP_SENDER_MAIN, 30605, "Spawn a Banker?", GuildHouseBank, false);
        AddGossipItemFor(player, GOSSIP_ICON_MONEY_BAG, "Spawn Auctioneer", GOSSIP_SENDER_MAIN, 6, "Spawn an Auctioneer?", GuildHouseAuctioneer, false);
        AddGossipItemFor(player, GOSSIP_ICON_MONEY_BAG, "Spawn Neutral Auctioneer", GOSSIP_SENDER_MAIN, 9858, "Spawn a Neutral Auctioneer?", GuildHouseAuctioneer, false);
        AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "Spawn Primary Profession Trainers", GOSSIP_SENDER_MAIN, 7);
        AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "Spawn Secondary Profession Trainers", GOSSIP_SENDER_MAIN, 8);
        AddGossipItemFor(player, GOSSIP_ICON_TALK, "Spawn Sprirt Healer", GOSSIP_SENDER_MAIN, 6491, "Spawn a Spirit Healer?", GuildHouseSpirit, false);
        
        // DC Extensions
        AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Spawn Mythic+ NPCs", GOSSIP_SENDER_MAIN, 20);
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "Spawn Seasonal Vendors", GOSSIP_SENDER_MAIN, 21);
        AddGossipItemFor(player, GOSSIP_ICON_MONEY_BAG, "Spawn Special Vendors", GOSSIP_SENDER_MAIN, 22);

        if (player->IsGameMaster())
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "GM Menu", GOSSIP_SENDER_MAIN, ACTION_GM_MENU);

        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {

        if (action == ACTION_GM_MENU)
        {
            ClearGossipMenuFor(player);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "GM: Spawn everything (free)", GOSSIP_SENDER_MAIN, ACTION_GM_SPAWN_ALL);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "GM: Despawn everything", GOSSIP_SENDER_MAIN, ACTION_GM_DESPAWN_ALL);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Go Back!", GOSSIP_SENDER_MAIN, ACTION_BACK);
            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
            return true;
        }

        if (action == ACTION_GM_SPAWN_ALL)
        {
            SpawnAll(player, false);
            OnGossipHello(player, creature);
            return true;
        }

        if (action == ACTION_GM_DESPAWN_ALL)
        {
            DespawnAll(player);
            OnGossipHello(player, creature);
            return true;
        }

        switch (action)
        {
        case 20: // Mythic+
            ClearGossipMenuFor(player);
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Mythic NPC (190004)", GOSSIP_SENDER_MAIN, 190004, "Spawn Mythic NPC (190004)?", GuildHouseVendor, false);
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Mythic NPC (100050)", GOSSIP_SENDER_MAIN, 100050, "Spawn Mythic NPC (100050)?", GuildHouseVendor, false);
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Mythic NPC (100051)", GOSSIP_SENDER_MAIN, 100051, "Spawn Mythic NPC (100051)?", GuildHouseVendor, false);
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Mythic NPC (100101)", GOSSIP_SENDER_MAIN, 100101, "Spawn Mythic NPC (100101)?", GuildHouseVendor, false);
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Mythic NPC (100100)", GOSSIP_SENDER_MAIN, 100100, "Spawn Mythic NPC (100100)?", GuildHouseVendor, false);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Go Back!", GOSSIP_SENDER_MAIN, ACTION_BACK);
            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
            break;

        case 21: // Seasonal
            ClearGossipMenuFor(player);
            AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "Seasonal Trader", GOSSIP_SENDER_MAIN, 95100, "Spawn Seasonal Trader?", GuildHouseVendor, false);
            AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "Holiday Ambassador", GOSSIP_SENDER_MAIN, 95101, "Spawn Holiday Ambassador?", GuildHouseVendor, false);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Go Back!", GOSSIP_SENDER_MAIN, 9);
            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
            break;
        case 22: // Special
            ClearGossipMenuFor(player);
            AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "Omni-Crafter", GOSSIP_SENDER_MAIN, 95102, "Spawn Omni-Crafter?", GuildHouseVendor, false);
            AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "Services NPC", GOSSIP_SENDER_MAIN, 55002, "Spawn Services NPC?", GuildHouseVendor, false);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Go Back!", GOSSIP_SENDER_MAIN, 9);
            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
            break;
        case 3: // Vendors
            ClearGossipMenuFor(player);
            AddGossipItemFor(player, GOSSIP_ICON_TALK, "Trade Supplies", GOSSIP_SENDER_MAIN, 28692, "Spawn Trade Supplies?", GuildHouseVendor, false);
            AddGossipItemFor(player, GOSSIP_ICON_TALK, "Tabard Vendor", GOSSIP_SENDER_MAIN, 28776, "Spawn Tabard Vendor?", GuildHouseVendor, false);
            AddGossipItemFor(player, GOSSIP_ICON_TALK, "Food & Drink Vendor", GOSSIP_SENDER_MAIN, 19572, "Spawn Food & Drink Vendor?", GuildHouseVendor, false);
            AddGossipItemFor(player, GOSSIP_ICON_TALK, "Reagent Vendor", GOSSIP_SENDER_MAIN, 29636, "Spawn Reagent Vendor?", GuildHouseVendor, false);
            AddGossipItemFor(player, GOSSIP_ICON_TALK, "Ammo & Repair Vendor", GOSSIP_SENDER_MAIN, 29493, "Spawn Ammo & Repair Vendor?", GuildHouseVendor, false);
            AddGossipItemFor(player, GOSSIP_ICON_TALK, "Poisons Vendor", GOSSIP_SENDER_MAIN, 2622, "Spawn Poisons Vendor?", GuildHouseVendor, false);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Go Back!", GOSSIP_SENDER_MAIN, 9);
            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
            break;
        case 4: // Objects (Portals Removed)
            ClearGossipMenuFor(player);
            AddGossipItemFor(player, GOSSIP_ICON_TALK, "Forge", GOSSIP_SENDER_MAIN, 1685, "Add a forge?", GuildHouseObject, false);
            AddGossipItemFor(player, GOSSIP_ICON_TALK, "Anvil", GOSSIP_SENDER_MAIN, 4087, "Add an Anvil?", GuildHouseObject, false);
            AddGossipItemFor(player, GOSSIP_ICON_MONEY_BAG, "Guild Vault", GOSSIP_SENDER_MAIN, 187293, "Add Guild Vault?", GuildHouseObject, false);
            AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1, "Barber Chair", GOSSIP_SENDER_MAIN, 191028, "Add a Barber Chair?", GuildHouseObject, false);

            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Go Back!", GOSSIP_SENDER_MAIN, 9);
            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
            break;
        case 6: // Auctioneer
        {
            uint32 auctioneer = 0;
            auctioneer = player->GetTeamId() == TEAM_ALLIANCE ? 8719 : 9856;
            SpawnNPC(auctioneer, player, GuildHouseAuctioneer, true, true);
            break;
        }
        case 9858: // Neutral Auctioneer
            SpawnNPC(action, player, GuildHouseAuctioneer, true, true);
            break;
        case 7: // Spawn Profession Trainers
            ClearGossipMenuFor(player);
            AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "Alchemy Trainer", GOSSIP_SENDER_MAIN, 19052, "Spawn Alchemy Trainer?", GuildHouseProf, false);
            AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "Blacksmithing Trainer", GOSSIP_SENDER_MAIN, 2836, "Spawn Blacksmithing Trainer?", GuildHouseProf, false);
            AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "Enchanting Trainer", GOSSIP_SENDER_MAIN, (player->GetTeamId() == TEAM_ALLIANCE ? 18773 : 18753), "Spawn Enchanting Trainer?", GuildHouseProf, false);
            AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "Engineering Trainer", GOSSIP_SENDER_MAIN, 8736, "Spawn Engineering Trainer?", GuildHouseProf, false);
            AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "Herbalism Trainer", GOSSIP_SENDER_MAIN, 908, "Spawn Herbalism Trainer?", GuildHouseProf, false);
            AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "Inscription Trainer", GOSSIP_SENDER_MAIN, (player->GetTeamId() == TEAM_ALLIANCE ? 30721 : 30722), "Spawn Inscription Trainer?", GuildHouseProf, false);
            AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "Jewelcrafting Trainer", GOSSIP_SENDER_MAIN, (player->GetTeamId() == TEAM_ALLIANCE ? 18774 : 18751), "Spawn Jewelcrafting Trainer?", GuildHouseProf, false);
            AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "Leatherworking Trainer", GOSSIP_SENDER_MAIN, 19187, "Spawn Leatherworking Trainer?", GuildHouseProf, false);
            AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "Mining Trainer", GOSSIP_SENDER_MAIN, 8128, "Spawn Mining Trainer?", GuildHouseProf, false);
            AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "Skinning Trainer", GOSSIP_SENDER_MAIN, 19180, "Spawn Skinning Trainer?", GuildHouseProf, false);
            AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "Tailoring Trainer", GOSSIP_SENDER_MAIN, 2627, "Spawn Tailoring Trainer?", GuildHouseProf, false);
            
            // Faction check not needed for custom trainers if they are neutral, 
            // but the request implies global replacement. 
            // The SQL defines them as Neutral (Type 2, no faction req usually implied or handled by core).
            // Removing faction specific logic blocks since we use unified IDs now.



            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Go Back!", GOSSIP_SENDER_MAIN, ACTION_BACK);
            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
            break;
        case 8: // Secondary Profession Trainers
            ClearGossipMenuFor(player);
            AddGossipItemFor(player, GOSSIP_ICON_MONEY_BAG, "First Aid Trainer", GOSSIP_SENDER_MAIN, 19184, "Spawn First Aid Trainer?", GuildHouseProf, false);
            AddGossipItemFor(player, GOSSIP_ICON_MONEY_BAG, "Fishing Trainer", GOSSIP_SENDER_MAIN, 2834, "Spawn Fishing Trainer?", GuildHouseProf, false);
            AddGossipItemFor(player, GOSSIP_ICON_MONEY_BAG, "Cooking Trainer", GOSSIP_SENDER_MAIN, 19185, "Spawn Cooking Trainer?", GuildHouseProf, false);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Go Back!", GOSSIP_SENDER_MAIN, 9);
            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
            break;
        case ACTION_BACK: // Go back!
            OnGossipHello(player, creature);
            break;
        case 10: // PVP toggle
            break;
        case 30605: // Banker
            SpawnNPC(action, player, GuildHouseBank, true, true);
            break;
        case 800001: // Innkeeper
            SpawnNPC(action, player, GuildHouseInnKeeper, true, true);
            break;
        case 2836:  // Blacksmithing
        case 8128:  // Mining
        case 8736:  // Engineering
        case 18774: // Jewelcrafting (Alliance)
        case 18751: // Jewelcrafting (Horde)
        case 18773: // Enchanting (Alliance)
        case 18753: // Enchanting (Horde)
        case 30721: // Inscription (Alliance)
        case 30722: // Inscription (Horde)
        case 19187: // Leatherworking
        case 19180: // Skinning
        case 19052: // Alchemy
        case 908:   // Herbalism
        case 2627:  // Tailoring
        case 19185: // Cooking
        case 2834:  // Fishing
        case 19184: // First Aid
            SpawnNPC(action, player, GuildHouseProf, true, true);
            break;
        case 28692: // Trade Supplies
        case 28776: // Tabard Vendor
        case 19572:  // Food & Drink Vendor
        case 29636: // Reagent Vendor
        case 29493: // Ammo & Repair Vendor
        case 28690: // Stable Master
        case 2622:  // Poisons Vendor
        case 190004: // Mythic+ (custom)
        case 100050: // Mythic+ (custom)
        case 100051: // Mythic+ (custom)
        case 100101: // Mythic+ (custom)
        case 100100: // Mythic+ (custom)
        case 90004: // Seasonal Trader
        case 90005: // Holiday Ambassador
        case 90006: // Omni-Crafter
        case 90007: // Repair Bot
            SpawnNPC(action, player, GuildHouseVendor, true, true);
            break;
        //
        // Objects
        //
        case 184137: // Mailbox
            SpawnObject(action, player, GuildHouseMailBox, true, true);
            break;
        case 6491: // Spirit Healer
            SpawnNPC(action, player, GuildHouseSpirit, true, true);
            break;
        case 1685:   // Forge
        case 4087:   // Anvil
        case 187293: // Guild Vault
        case 191028: // Barber Chair
            SpawnObject(action, player, GuildHouseObject, true, true);
            break;
        case GetGameObjectEntry(1): // Darnassus Portal
        case GetGameObjectEntry(2): // Exodar Portal
        case GetGameObjectEntry(3): // Ironforge Portal
        case GetGameObjectEntry(5): // Silvermoon Portal
        case GetGameObjectEntry(6): // Thunder Bluff Portal
        case GetGameObjectEntry(7): // Undercity Portal
        case GetGameObjectEntry(8): // Shattrath Portal
        case GetGameObjectEntry(9): // Dalaran Portal
            SpawnObject(action, player, GuildHousePortal, true, true);
            break;
        }
        return true;
    }

    uint32 GetGuildPhase(Player* player)
    {
        return ::GetGuildPhase(player);
    }

    void SpawnNPC(uint32 entry, Player* player, uint32 spawnCost, bool chargePlayer, bool doBroadcast)
    {
        if (player->FindNearestCreature(entry, VISIBILITY_RANGE, true))
        {
            ChatHandler(player->GetSession()).PSendSysMessage("You already have this creature!");
            CloseGossipMenuFor(player);
            return;
        }

        float posX;
        float posY;
        float posZ;
        float ori;

        QueryResult result;
        if (SpawnPresetsHaveMapColumn())
        {
            // Map-aware spawn presets (supports multiple guildhouse locations on different maps)
            result = WorldDatabase.Query(
                "SELECT `posX`, `posY`, `posZ`, `orientation` FROM `dc_guild_house_spawns` WHERE `map`={} AND `entry`={}",
                player->GetMapId(), entry);
        }
        else
        {
            // Backward compatible with old schema (no `map` column)
            result = WorldDatabase.Query(
                "SELECT `posX`, `posY`, `posZ`, `orientation` FROM `dc_guild_house_spawns` WHERE `entry`={}",
                entry);
        }

        if (!result)
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "No spawn preset found for entry {} (map {}). Check `dc_guild_house_spawns`.", entry, player->GetMapId());
            return;
        }

        do
        {
            Field* fields = result->Fetch();
            posX = fields[0].Get<float>();
            posY = fields[1].Get<float>();
            posZ = fields[2].Get<float>();
            ori = fields[3].Get<float>();

        } while (result->NextRow());

        Creature* creature = new Creature();

        if (!creature->Create(player->GetMap()->GenerateLowGuid<HighGuid::Unit>(), player->GetMap(), GetGuildPhase(player), entry, 0, posX, posY, posZ, ori))
        {
            delete creature;
            return;
        }
        creature->SaveToDB(player->GetMapId(), (1 << player->GetMap()->GetSpawnMode()), GetGuildPhase(player));
        uint32 db_guid = creature->GetSpawnId();

        creature->CleanupsBeforeDelete();
        delete creature;
        creature = new Creature();
        if (!creature->LoadCreatureFromDB(db_guid, player->GetMap()))
        {
            delete creature;
            return;
        }

        sObjectMgr->AddCreatureToGrid(db_guid, sObjectMgr->GetCreatureData(db_guid));

        if (Guild* guild = player->GetGuild())
        {
            std::string spawnedName = std::to_string(entry);
            if (CreatureTemplate const* creatureTemplate = sObjectMgr->GetCreatureTemplate(entry))
                spawnedName = creatureTemplate->Name;

            std::string safePlayerName = player->GetName();
            CharacterDatabase.EscapeString(safePlayerName);
            std::string safeSpawnedName = spawnedName;
            CharacterDatabase.EscapeString(safeSpawnedName);

            CharacterDatabase.Execute(
                "INSERT INTO `dc_guild_house_purchase_log` (`created_at`, `guild_id`, `player_guid`, `player_name`, `map`, `phaseMask`, `spawn_type`, `entry`, `template_name`, `cost`) "
                "VALUES (UNIX_TIMESTAMP(), {}, {}, '{}', {}, {}, 'CREATURE', {}, '{}', {})",
                guild->GetId(), player->GetGUID().GetRawValue(), safePlayerName, player->GetMapId(), GetGuildPhase(player), entry, safeSpawnedName, spawnCost);

            if (doBroadcast)
            {
                guild->BroadcastToGuild(player->GetSession(), false,
                    "Guild House: " + std::string(player->GetName()) + " spawned " + spawnedName + ".",
                    LANG_UNIVERSAL);
            }
        }

        if (chargePlayer && spawnCost)
            player->ModifyMoney(-static_cast<int64>(spawnCost));
        CloseGossipMenuFor(player);
    }

    void SpawnObject(uint32 entry, Player* player, uint32 spawnCost, bool chargePlayer, bool doBroadcast)
    {
        if (player->FindNearestGameObject(entry, VISIBLE_RANGE))
        {
            ChatHandler(player->GetSession()).PSendSysMessage("You already have this object!");
            CloseGossipMenuFor(player);
            return;
        }

        float posX;
        float posY;
        float posZ;
        float ori;

        QueryResult result;
        if (SpawnPresetsHaveMapColumn())
        {
            // Map-aware spawn presets (supports multiple guildhouse locations on different maps)
            result = WorldDatabase.Query(
                "SELECT `posX`, `posY`, `posZ`, `orientation` FROM `dc_guild_house_spawns` WHERE `map`={} AND `entry`={}",
                player->GetMapId(), entry);
        }
        else
        {
            // Backward compatible with old schema (no `map` column)
            result = WorldDatabase.Query(
                "SELECT `posX`, `posY`, `posZ`, `orientation` FROM `dc_guild_house_spawns` WHERE `entry`={}",
                entry);
        }

        if (!result)
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "No spawn preset found for entry {} (map {}). Check `dc_guild_house_spawns`.", entry, player->GetMapId());
            return;
        }

        do
        {
            Field* fields = result->Fetch();
            posX = fields[0].Get<float>();
            posY = fields[1].Get<float>();
            posZ = fields[2].Get<float>();
            ori = fields[3].Get<float>();

        } while (result->NextRow());

        uint32 objectId = entry;
        if (!objectId)
            return;

        const GameObjectTemplate* objectInfo = sObjectMgr->GetGameObjectTemplate(objectId);

        if (!objectInfo)
            return;

        if (objectInfo->displayId && !sGameObjectDisplayInfoStore.LookupEntry(objectInfo->displayId))
            return;

        GameObject* object = sObjectMgr->IsGameObjectStaticTransport(objectInfo->entry) ? new StaticTransport() : new GameObject();
        ObjectGuid::LowType guidLow = player->GetMap()->GenerateLowGuid<HighGuid::GameObject>();

        if (!object->Create(guidLow, objectInfo->entry, player->GetMap(), GetGuildPhase(player), posX, posY, posZ, ori, G3D::Quat(), 0, GO_STATE_READY))
        {
            delete object;
            return;
        }

        // fill the gameobject data and save to the db
        object->SaveToDB(player->GetMapId(), (1 << player->GetMap()->GetSpawnMode()), GetGuildPhase(player));
        guidLow = object->GetSpawnId();
        // delete the old object and do a clean load from DB with a fresh new GameObject instance.
        // this is required to avoid weird behavior and memory leaks
        delete object;

        object = sObjectMgr->IsGameObjectStaticTransport(objectInfo->entry) ? new StaticTransport() : new GameObject();
        // this will generate a new guid if the object is in an instance
        if (!object->LoadGameObjectFromDB(guidLow, player->GetMap(), true))
        {
            delete object;
            return;
        }

        // TODO: is it really necessary to add both the real and DB table guid here ?
        sObjectMgr->AddGameobjectToGrid(guidLow, sObjectMgr->GetGameObjectData(guidLow));

        if (Guild* guild = player->GetGuild())
        {
            std::string spawnedName = std::to_string(entry);
            if (GameObjectTemplate const* objectTemplate = sObjectMgr->GetGameObjectTemplate(entry))
                spawnedName = objectTemplate->name;

            std::string safePlayerName = player->GetName();
            CharacterDatabase.EscapeString(safePlayerName);
            std::string safeSpawnedName = spawnedName;
            CharacterDatabase.EscapeString(safeSpawnedName);

            CharacterDatabase.Execute(
                "INSERT INTO `dc_guild_house_purchase_log` (`created_at`, `guild_id`, `player_guid`, `player_name`, `map`, `phaseMask`, `spawn_type`, `entry`, `template_name`, `cost`) "
                "VALUES (UNIX_TIMESTAMP(), {}, {}, '{}', {}, {}, 'GAMEOBJECT', {}, '{}', {})",
                guild->GetId(), player->GetGUID().GetRawValue(), safePlayerName, player->GetMapId(), GetGuildPhase(player), entry, safeSpawnedName, spawnCost);

            if (doBroadcast)
            {
                guild->BroadcastToGuild(player->GetSession(), false,
                    "Guild House: " + std::string(player->GetName()) + " spawned " + spawnedName + ".",
                    LANG_UNIVERSAL);
            }
        }

        if (chargePlayer && spawnCost)
            player->ModifyMoney(-static_cast<int64>(spawnCost));
        CloseGossipMenuFor(player);
    }

    void SpawnAll(Player* player, bool doBroadcastEach)
    {
        if (!player || !player->GetGuild())
            return;

        // Core services
        SpawnNPC(800001, player, 0, false, doBroadcastEach); // Innkeeper
        SpawnObject(184137, player, 0, false, doBroadcastEach); // Mailbox
        SpawnNPC(28690, player, 0, false, doBroadcastEach); // Stable Master
        SpawnNPC(30605, player, 0, false, doBroadcastEach); // Banker
        SpawnNPC(8719, player, 0, false, doBroadcastEach);  // Alliance Auctioneer
        SpawnNPC(9856, player, 0, false, doBroadcastEach);  // Horde Auctioneer
        SpawnNPC(9858, player, 0, false, doBroadcastEach);  // Neutral Auctioneer
        SpawnNPC(6491, player, 0, false, doBroadcastEach);  // Spirit Healer

        // Vendors
        SpawnNPC(28692, player, 0, false, doBroadcastEach);
        SpawnNPC(28776, player, 0, false, doBroadcastEach);
        SpawnNPC(19572, player, 0, false, doBroadcastEach);
        SpawnNPC(29636, player, 0, false, doBroadcastEach);
        SpawnNPC(29493, player, 0, false, doBroadcastEach);
        SpawnNPC(2622, player, 0, false, doBroadcastEach);

        // Primary professions (team-based where applicable)
        SpawnNPC(19052, player, 0, false, doBroadcastEach); // Alchemy
        SpawnNPC(2836, player, 0, false, doBroadcastEach);  // Blacksmithing
        SpawnNPC(player->GetTeamId() == TEAM_ALLIANCE ? 18773 : 18753, player, 0, false, doBroadcastEach); // Enchanting
        SpawnNPC(8736, player, 0, false, doBroadcastEach);  // Engineering
        SpawnNPC(908, player, 0, false, doBroadcastEach);   // Herbalism
        SpawnNPC(player->GetTeamId() == TEAM_ALLIANCE ? 30721 : 30722, player, 0, false, doBroadcastEach); // Inscription
        SpawnNPC(player->GetTeamId() == TEAM_ALLIANCE ? 18774 : 18751, player, 0, false, doBroadcastEach); // Jewelcrafting
        SpawnNPC(19187, player, 0, false, doBroadcastEach); // Leatherworking
        SpawnNPC(8128, player, 0, false, doBroadcastEach);  // Mining
        SpawnNPC(19180, player, 0, false, doBroadcastEach); // Skinning
        SpawnNPC(2627, player, 0, false, doBroadcastEach);  // Tailoring

        // Secondary professions
        SpawnNPC(19184, player, 0, false, doBroadcastEach);
        SpawnNPC(2834, player, 0, false, doBroadcastEach);
        SpawnNPC(19185, player, 0, false, doBroadcastEach);

        // Objects
        SpawnObject(1685, player, 0, false, doBroadcastEach);
        SpawnObject(4087, player, 0, false, doBroadcastEach);
        SpawnObject(187293, player, 0, false, doBroadcastEach);
        SpawnObject(191028, player, 0, false, doBroadcastEach);

        // DC vendors
        SpawnNPC(95100, player, 0, false, doBroadcastEach);
        SpawnNPC(95101, player, 0, false, doBroadcastEach);
        SpawnNPC(95102, player, 0, false, doBroadcastEach);
        SpawnNPC(55002, player, 0, false, doBroadcastEach);

        // Mythic+ NPCs
        SpawnNPC(190004, player, 0, false, doBroadcastEach);
        SpawnNPC(100050, player, 0, false, doBroadcastEach);
        SpawnNPC(100051, player, 0, false, doBroadcastEach);
        SpawnNPC(100101, player, 0, false, doBroadcastEach);
        SpawnNPC(100100, player, 0, false, doBroadcastEach);

        if (Guild* guild = player->GetGuild())
        {
            guild->BroadcastToGuild(player->GetSession(), false,
                "GM: " + std::string(player->GetName()) + " spawned all Guild House upgrades.",
                LANG_UNIVERSAL);
        }
    }

    void DespawnAll(Player* player)
    {
        if (!player || !player->GetGuild())
            return;

        uint32 guildPhase = GetGuildPhase(player);
        uint32 mapId = player->GetMapId();
        Map* map = player->GetMap();
        if (!map)
            return;

        QueryResult creatureResult = WorldDatabase.Query(
            "SELECT `guid`, `id1` FROM `creature` WHERE `map` = {} AND `phaseMask` = {}",
            mapId, guildPhase);

        if (creatureResult)
        {
            do
            {
                Field* fields = creatureResult->Fetch();
                uint32 lowguid = fields[0].Get<uint32>();
                uint32 entry = fields[1].Get<uint32>();
                if (ShouldKeepCreatureEntryOnDespawnAll(entry))
                    continue;

                if (CreatureData const* crData = sObjectMgr->GetCreatureData(lowguid))
                {
                    if (Creature* creature = map->GetCreature(ObjectGuid::Create<HighGuid::Unit>(crData->id1, lowguid)))
                    {
                        creature->CombatStop();
                        creature->DeleteFromDB();
                        creature->AddObjectToRemoveList();
                    }
                }
            } while (creatureResult->NextRow());
        }

        QueryResult gameobjResult = WorldDatabase.Query(
            "SELECT `guid` FROM `gameobject` WHERE `map` = {} AND `phaseMask` = {}",
            mapId, guildPhase);

        if (gameobjResult)
        {
            do
            {
                Field* fields = gameobjResult->Fetch();
                uint32 lowguid = fields[0].Get<uint32>();

                if (GameObjectData const* goData = sObjectMgr->GetGameObjectData(lowguid))
                {
                    if (GameObject* gobject = map->GetGameObject(ObjectGuid::Create<HighGuid::GameObject>(goData->id, lowguid)))
                    {
                        gobject->SetRespawnTime(0);
                        gobject->Delete();
                        gobject->DeleteFromDB();
                        gobject->CleanupsBeforeDelete();
                    }
                }

            } while (gameobjResult->NextRow());
        }

        if (Guild* guild = player->GetGuild())
        {
            guild->BroadcastToGuild(player->GetSession(), false,
                "GM: " + std::string(player->GetName()) + " despawned all Guild House upgrades.",
                LANG_UNIVERSAL);
        }
    }
};

class GuildHouseButlerConf : public WorldScript
{
public:
    GuildHouseButlerConf() : WorldScript("GuildHouseButlerConf") {}

    void OnBeforeConfigLoad(bool /*reload*/) override
    {
        GuildHouseInnKeeper = sConfigMgr->GetOption<int32>("GuildHouseInnKeeper", 1000000);
        GuildHouseBank = sConfigMgr->GetOption<int32>("GuildHouseBank", 1000000);
        GuildHouseMailBox = sConfigMgr->GetOption<int32>("GuildHouseMailbox", 500000);
        GuildHouseAuctioneer = sConfigMgr->GetOption<int32>("GuildHouseAuctioneer", 500000);
        GuildHouseTrainer = sConfigMgr->GetOption<int32>("GuildHouseTrainerCost", 1000000);
        GuildHouseVendor = sConfigMgr->GetOption<int32>("GuildHouseVendor", 500000);
        GuildHouseObject = sConfigMgr->GetOption<int32>("GuildHouseObject", 500000);
        GuildHousePortal = sConfigMgr->GetOption<int32>("GuildHousePortal", 500000);
        GuildHouseProf = sConfigMgr->GetOption<int32>("GuildHouseProf", 500000);
        GuildHouseSpirit = sConfigMgr->GetOption<int32>("GuildHouseSpirit", 100000);
        GuildHouseSpirit = sConfigMgr->GetOption<int32>("GuildHouseSpirit", 100000);
        GuildHouseBuyRank = sConfigMgr->GetOption<int32>("GuildHouseBuyRank", 4);
        GuildHouseCurrency = sConfigMgr->GetOption<int32>("DarkChaos.Seasonal.TokenItemID", 0);
    }
};

void AddGuildHouseButlerScripts()
{
    new GuildHouseSpawner();
    new GuildHouseButlerConf();
}
