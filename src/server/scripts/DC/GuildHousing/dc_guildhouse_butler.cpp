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
#include "dc_guildhouse.h"

#include <optional>

namespace
{
    int32 s_guildHouseCostInnkeeper = 0;
    int32 s_guildHouseCostBank = 0;
    int32 s_guildHouseCostMailbox = 0;
    int32 s_guildHouseCostAuctioneer = 0;
    int32 s_guildHouseCostVendor = 0;
    int32 s_guildHouseCostObject = 0;
    int32 s_guildHouseCostPortal = 0;
    int32 s_guildHouseCostSpirit = 0;
    int32 s_guildHouseCostProfession = 0;
    int32 s_guildHouseBuyRank = 0;
}

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
            me->SetNpcFlag(UNIT_NPC_FLAG_GOSSIP);
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

            if (!memberMe->IsRankNotLower(s_guildHouseBuyRank))
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
        AddGossipItemFor(player, GOSSIP_ICON_TALK, "Spawn Innkeeper", GOSSIP_SENDER_MAIN, 800001, "Add an Innkeeper?", s_guildHouseCostInnkeeper, false);
        AddGossipItemFor(player, GOSSIP_ICON_TALK, "Spawn Mailbox", GOSSIP_SENDER_MAIN, 184137, "Spawn a Mailbox?", s_guildHouseCostMailbox, false);
        AddGossipItemFor(player, GOSSIP_ICON_TALK, "Spawn Stable Master", GOSSIP_SENDER_MAIN, 28690, "Spawn a Stable Master?", s_guildHouseCostVendor, false);
        AddGossipItemFor(player, GOSSIP_ICON_TALK, "Spawn Vendor", GOSSIP_SENDER_MAIN, 3);
        AddGossipItemFor(player, GOSSIP_ICON_TALK, "Spawn Objects", GOSSIP_SENDER_MAIN, 4);
        AddGossipItemFor(player, GOSSIP_ICON_MONEY_BAG, "Spawn Bank", GOSSIP_SENDER_MAIN, 30605, "Spawn a Banker?", s_guildHouseCostBank, false);
        AddGossipItemFor(player, GOSSIP_ICON_MONEY_BAG, "Spawn Auctioneer", GOSSIP_SENDER_MAIN, 6, "Spawn an Auctioneer?", s_guildHouseCostAuctioneer, false);
        AddGossipItemFor(player, GOSSIP_ICON_MONEY_BAG, "Spawn Neutral Auctioneer", GOSSIP_SENDER_MAIN, 9858, "Spawn a Neutral Auctioneer?", s_guildHouseCostAuctioneer, false);
        AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "Spawn Primary Profession Trainers", GOSSIP_SENDER_MAIN, 7);
        AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "Spawn Secondary Profession Trainers", GOSSIP_SENDER_MAIN, 8);
        AddGossipItemFor(player, GOSSIP_ICON_TALK, "Spawn Spirit Healer", GOSSIP_SENDER_MAIN, 6491, "Spawn a Spirit Healer?", s_guildHouseCostSpirit, false);

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
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Mythic NPC (190004)", GOSSIP_SENDER_MAIN, 190004, "Spawn Mythic NPC (190004)?", s_guildHouseCostVendor, false);
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Mythic NPC (100050)", GOSSIP_SENDER_MAIN, 100050, "Spawn Mythic NPC (100050)?", s_guildHouseCostVendor, false);
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Mythic NPC (100051)", GOSSIP_SENDER_MAIN, 100051, "Spawn Mythic NPC (100051)?", s_guildHouseCostVendor, false);
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Mythic NPC (100101)", GOSSIP_SENDER_MAIN, 100101, "Spawn Mythic NPC (100101)?", s_guildHouseCostVendor, false);
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Mythic NPC (100100)", GOSSIP_SENDER_MAIN, 100100, "Spawn Mythic NPC (100100)?", s_guildHouseCostVendor, false);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Go Back!", GOSSIP_SENDER_MAIN, ACTION_BACK);
            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
            break;

        case 21: // Seasonal
            ClearGossipMenuFor(player);
            AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "Seasonal Trader", GOSSIP_SENDER_MAIN, 95100, "Spawn Seasonal Trader?", s_guildHouseCostVendor, false);
            AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "Holiday Ambassador", GOSSIP_SENDER_MAIN, 95101, "Spawn Holiday Ambassador?", s_guildHouseCostVendor, false);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Go Back!", GOSSIP_SENDER_MAIN, 9);
            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
            break;
        case 22: // Special
            ClearGossipMenuFor(player);
            AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "Omni-Crafter", GOSSIP_SENDER_MAIN, 95102, "Spawn Omni-Crafter?", s_guildHouseCostVendor, false);
            AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "Services NPC", GOSSIP_SENDER_MAIN, 55002, "Spawn Services NPC?", s_guildHouseCostVendor, false);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Go Back!", GOSSIP_SENDER_MAIN, 9);
            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
            break;
        case 3: // Vendors
            ClearGossipMenuFor(player);
            AddGossipItemFor(player, GOSSIP_ICON_TALK, "Trade Supplies", GOSSIP_SENDER_MAIN, 28692, "Spawn Trade Supplies?", s_guildHouseCostVendor, false);
            AddGossipItemFor(player, GOSSIP_ICON_TALK, "Tabard Vendor", GOSSIP_SENDER_MAIN, 28776, "Spawn Tabard Vendor?", s_guildHouseCostVendor, false);
            AddGossipItemFor(player, GOSSIP_ICON_TALK, "Food & Drink Vendor", GOSSIP_SENDER_MAIN, 19572, "Spawn Food & Drink Vendor?", s_guildHouseCostVendor, false);
            AddGossipItemFor(player, GOSSIP_ICON_TALK, "Reagent Vendor", GOSSIP_SENDER_MAIN, 29636, "Spawn Reagent Vendor?", s_guildHouseCostVendor, false);
            AddGossipItemFor(player, GOSSIP_ICON_TALK, "Ammo & Repair Vendor", GOSSIP_SENDER_MAIN, 29493, "Spawn Ammo & Repair Vendor?", s_guildHouseCostVendor, false);
            AddGossipItemFor(player, GOSSIP_ICON_TALK, "Poisons Vendor", GOSSIP_SENDER_MAIN, 2622, "Spawn Poisons Vendor?", s_guildHouseCostVendor, false);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Go Back!", GOSSIP_SENDER_MAIN, 9);
            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
            break;
        case 4: // Objects (Portals Removed)
            ClearGossipMenuFor(player);
            AddGossipItemFor(player, GOSSIP_ICON_TALK, "Forge", GOSSIP_SENDER_MAIN, 1685, "Add a forge?", s_guildHouseCostObject, false);
            AddGossipItemFor(player, GOSSIP_ICON_TALK, "Anvil", GOSSIP_SENDER_MAIN, 4087, "Add an Anvil?", s_guildHouseCostObject, false);
            AddGossipItemFor(player, GOSSIP_ICON_MONEY_BAG, "Guild Vault", GOSSIP_SENDER_MAIN, 187293, "Add Guild Vault?", s_guildHouseCostObject, false);
            AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1, "Barber Chair", GOSSIP_SENDER_MAIN, 191028, "Add a Barber Chair?", s_guildHouseCostObject, false);

            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Go Back!", GOSSIP_SENDER_MAIN, 9);
            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
            break;
        case 6: // Auctioneer
        {
            uint32 auctioneer = 0;
            auctioneer = player->GetTeamId() == TEAM_ALLIANCE ? 8719 : 9856;
            SpawnNPC(auctioneer, player, s_guildHouseCostAuctioneer, true, true);
            break;
        }
        case 9858: // Neutral Auctioneer
            SpawnNPC(action, player, s_guildHouseCostAuctioneer, true, true);
            break;
        case 7: // Spawn Profession Trainers
            ClearGossipMenuFor(player);
            // Custom profession trainers (see worlddb/Trainers/npc_trainer_new.sql)
            AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "Alchemy Trainer", GOSSIP_SENDER_MAIN, 95001, "Spawn Alchemy Trainer?", s_guildHouseCostProfession, false);
            AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "Blacksmithing Trainer", GOSSIP_SENDER_MAIN, 95002, "Spawn Blacksmithing Trainer?", s_guildHouseCostProfession, false);
            AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "Enchanting Trainer", GOSSIP_SENDER_MAIN, 95003, "Spawn Enchanting Trainer?", s_guildHouseCostProfession, false);
            AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "Engineering Trainer", GOSSIP_SENDER_MAIN, 95004, "Spawn Engineering Trainer?", s_guildHouseCostProfession, false);
            AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "Herbalism Trainer", GOSSIP_SENDER_MAIN, 95005, "Spawn Herbalism Trainer?", s_guildHouseCostProfession, false);
            AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "Inscription Trainer", GOSSIP_SENDER_MAIN, 95006, "Spawn Inscription Trainer?", s_guildHouseCostProfession, false);
            AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "Jewelcrafting Trainer", GOSSIP_SENDER_MAIN, 95007, "Spawn Jewelcrafting Trainer?", s_guildHouseCostProfession, false);
            AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "Leatherworking Trainer", GOSSIP_SENDER_MAIN, 95008, "Spawn Leatherworking Trainer?", s_guildHouseCostProfession, false);
            AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "Mining Trainer", GOSSIP_SENDER_MAIN, 95009, "Spawn Mining Trainer?", s_guildHouseCostProfession, false);
            AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "Skinning Trainer", GOSSIP_SENDER_MAIN, 95010, "Spawn Skinning Trainer?", s_guildHouseCostProfession, false);
            AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "Tailoring Trainer", GOSSIP_SENDER_MAIN, 95011, "Spawn Tailoring Trainer?", s_guildHouseCostProfession, false);

            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Go Back!", GOSSIP_SENDER_MAIN, ACTION_BACK);
            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
            break;
        case 8: // Secondary Profession Trainers
            ClearGossipMenuFor(player);
            AddGossipItemFor(player, GOSSIP_ICON_MONEY_BAG, "First Aid Trainer", GOSSIP_SENDER_MAIN, 95013, "Spawn First Aid Trainer?", s_guildHouseCostProfession, false);
            AddGossipItemFor(player, GOSSIP_ICON_MONEY_BAG, "Fishing Trainer", GOSSIP_SENDER_MAIN, 95014, "Spawn Fishing Trainer?", s_guildHouseCostProfession, false);
            AddGossipItemFor(player, GOSSIP_ICON_MONEY_BAG, "Cooking Trainer", GOSSIP_SENDER_MAIN, 95012, "Spawn Cooking Trainer?", s_guildHouseCostProfession, false);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Go Back!", GOSSIP_SENDER_MAIN, 9);
            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
            break;
        case ACTION_BACK: // Go back!
            OnGossipHello(player, creature);
            break;
        case 10: // PVP toggle
            break;
        case 30605: // Banker
            SpawnNPC(action, player, s_guildHouseCostBank, true, true);
            break;
        case 800001: // Innkeeper
            SpawnNPC(action, player, s_guildHouseCostInnkeeper, true, true);
            break;
        case 95001: // Alchemy
        case 95002: // Blacksmithing
        case 95003: // Enchanting
        case 95004: // Engineering
        case 95005: // Herbalism
        case 95006: // Inscription
        case 95007: // Jewelcrafting
        case 95008: // Leatherworking
        case 95009: // Mining
        case 95010: // Skinning
        case 95011: // Tailoring
        case 95012: // Cooking
        case 95013: // First Aid
        case 95014: // Fishing
        case 95025: // Weapon Trainer
        case 95026: // Riding Trainer
            SpawnNPC(action, player, s_guildHouseCostProfession, true, true);
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
        case 95100: // Seasonal Trader
        case 95101: // Holiday Ambassador
        case 95102: // Omni-Crafter
        case 55002: // Services NPC
            SpawnNPC(action, player, s_guildHouseCostVendor, true, true);
            break;
        //
        // Objects
        //
        case 184137: // Mailbox
            SpawnObject(action, player, s_guildHouseCostMailbox, true, true);
            break;
        case 6491: // Spirit Healer
            SpawnNPC(action, player, s_guildHouseCostSpirit, true, true);
            break;
        case 1685:   // Forge
        case 4087:   // Anvil
        case 187293: // Guild Vault
        case 191028: // Barber Chair
            SpawnObject(action, player, s_guildHouseCostObject, true, true);
            break;
        case GetGameObjectEntry(1): // Darnassus Portal
        case GetGameObjectEntry(2): // Exodar Portal
        case GetGameObjectEntry(3): // Ironforge Portal
        case GetGameObjectEntry(5): // Silvermoon Portal
        case GetGameObjectEntry(6): // Thunder Bluff Portal
        case GetGameObjectEntry(7): // Undercity Portal
        case GetGameObjectEntry(8): // Shattrath Portal
        case GetGameObjectEntry(9): // Dalaran Portal
            SpawnObject(action, player, s_guildHouseCostPortal, true, true);
            break;
        }
        return true;
    }

    void SpawnNPC(uint32 entry, Player* player, uint32 spawnCost, bool chargePlayer, bool doBroadcast)
    {
        // Permission Check
        Guild* guild = player->GetGuild();
        if (!guild) return;

        // Use configured rank or default to Officer+?
        // User asked for "Add Permission System".
        // Let's use GuildHouseSellRank for now as "Management Rank", or add a new one.
        // User said: "you can implement: ... Add Permission System"
        // I will use `GuildHouseSpawnRank` from config if available (need to add getter) or default.
        // Since I can't easily edit Config.h/cpp instantly to add new valid config options without recompile issues if strict,
        // I'll stick to using the existing `GuildHouseSellRank` or a hardcoded sane default (Officer) if Config not present.
        // For now, let's assume `GuildHouseSellRank` is "Manage Guild House" rank.

        int32 requiredRank = sConfigMgr->GetOption<int32>("GuildHouseSellRank", 0);
        if (!guild->GetMember(player->GetGUID())->IsRankNotLower(requiredRank))
        {
             ChatHandler(player->GetSession()).PSendSysMessage("You do not have permission to spawn NPCs.");
             CloseGossipMenuFor(player);
             return;
        }

        // Global Existence Check
        // Use current map and phase
        if (GuildHouseManager::HasSpawn(player->GetMapId(), GetGuildPhase(player), entry, false))
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
        Guild* guild = player->GetGuild();
        if (!guild) return;

        int32 requiredRank = sConfigMgr->GetOption<int32>("GuildHouseSellRank", 0);
        if (!guild->GetMember(player->GetGUID())->IsRankNotLower(requiredRank))
        {
             ChatHandler(player->GetSession()).PSendSysMessage("You do not have permission to spawn objects.");
             CloseGossipMenuFor(player);
             return;
        }

        if (GuildHouseManager::HasSpawn(player->GetMapId(), GetGuildPhase(player), entry, true))
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
        SpawnNPC(95001, player, 0, false, doBroadcastEach); // Alchemy
        SpawnNPC(95002, player, 0, false, doBroadcastEach); // Blacksmithing
        SpawnNPC(95003, player, 0, false, doBroadcastEach); // Enchanting
        SpawnNPC(95004, player, 0, false, doBroadcastEach); // Engineering
        SpawnNPC(95005, player, 0, false, doBroadcastEach); // Herbalism
        SpawnNPC(95006, player, 0, false, doBroadcastEach); // Inscription
        SpawnNPC(95007, player, 0, false, doBroadcastEach); // Jewelcrafting
        SpawnNPC(95008, player, 0, false, doBroadcastEach); // Leatherworking
        SpawnNPC(95009, player, 0, false, doBroadcastEach); // Mining
        SpawnNPC(95010, player, 0, false, doBroadcastEach); // Skinning
        SpawnNPC(95011, player, 0, false, doBroadcastEach); // Tailoring

        // Secondary professions
        SpawnNPC(95013, player, 0, false, doBroadcastEach); // First Aid
        SpawnNPC(95014, player, 0, false, doBroadcastEach); // Fishing
        SpawnNPC(95012, player, 0, false, doBroadcastEach); // Cooking

        // Weapon & riding trainers
        SpawnNPC(95025, player, 0, false, doBroadcastEach);
        SpawnNPC(95026, player, 0, false, doBroadcastEach);

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

        uint32 removedCreatures = 0;
        uint32 removedGameObjects = 0;

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

                // Prefer deleting the live object (works for dynamically spawned creatures).
                // Use the per-map spawnId store, since ObjectGuid(entry, spawnId) can miss loaded objects.
                Creature* creature = nullptr;
                {
                    auto bounds = map->GetCreatureBySpawnIdStore().equal_range(lowguid);
                    if (bounds.first != bounds.second)
                        creature = bounds.first->second;
                }

                if (creature)
                {
                    creature->CombatStop(true);
                    creature->DeleteFromDB();
                    creature->AddObjectToRemoveList();
                    ++removedCreatures;
                }
                else
                {
                    // Fallback: ensure DB cleanup even if the creature isn't loaded.
                    WorldDatabase.Execute("DELETE FROM `creature` WHERE `guid` = {}", lowguid);
                    WorldDatabase.Execute("DELETE FROM `creature_addon` WHERE `guid` = {}", lowguid);
                    ++removedCreatures;
                }

                // Clean cached spawn data if present.
                sObjectMgr->DeleteCreatureData(lowguid);
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

                GameObject* gobject = nullptr;
                {
                    auto bounds = map->GetGameObjectBySpawnIdStore().equal_range(lowguid);
                    if (bounds.first != bounds.second)
                        gobject = bounds.first->second;
                }

                if (gobject)
                {
                    gobject->SetRespawnTime(0);
                    gobject->Delete();
                    gobject->DeleteFromDB();
                    ++removedGameObjects;
                }
                else
                {
                    WorldDatabase.Execute("DELETE FROM `gameobject` WHERE `guid` = {}", lowguid);
                    WorldDatabase.Execute("DELETE FROM `gameobject_addon` WHERE `guid` = {}", lowguid);
                    ++removedGameObjects;
                }

                sObjectMgr->DeleteGOData(lowguid);

            } while (gameobjResult->NextRow());
        }

        ChatHandler(player->GetSession()).PSendSysMessage(
            "GM: Despawned {} creatures and {} gameobjects on map {} phase {}.",
            removedCreatures, removedGameObjects, mapId, guildPhase);

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
        s_guildHouseCostInnkeeper = sConfigMgr->GetOption<int32>("GuildHouseInnKeeper", 1000000);
        s_guildHouseCostBank = sConfigMgr->GetOption<int32>("GuildHouseBank", 1000000);
        s_guildHouseCostMailbox = sConfigMgr->GetOption<int32>("GuildHouseMailbox", 500000);
        s_guildHouseCostAuctioneer = sConfigMgr->GetOption<int32>("GuildHouseAuctioneer", 500000);
        s_guildHouseCostVendor = sConfigMgr->GetOption<int32>("GuildHouseVendor", 500000);
        s_guildHouseCostObject = sConfigMgr->GetOption<int32>("GuildHouseObject", 500000);
        s_guildHouseCostPortal = sConfigMgr->GetOption<int32>("GuildHousePortal", 500000);
        s_guildHouseCostProfession = sConfigMgr->GetOption<int32>("GuildHouseProf", 500000);
        s_guildHouseCostSpirit = sConfigMgr->GetOption<int32>("GuildHouseSpirit", 100000);
        s_guildHouseBuyRank = sConfigMgr->GetOption<int32>("GuildHouseBuyRank", 4);
    }
};

void AddGuildHouseButlerScripts()
{
    new GuildHouseSpawner();
    new GuildHouseButlerConf();
}
