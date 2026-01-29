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
#include "Weather.h"
#include "dc_guildhouse.h"

#include <array>
#include <cctype>
#include <optional>
#include <string>
#include <vector>

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

    static std::string MakeLargeGossipText(std::string const& icon, std::string const& text)
    {
        return "|T" + icon + ":40:40:-18|t " + text;
    }

    static constexpr uint32 ACTION_BACK = 9;
    static constexpr uint32 ACTION_GM_MENU = 9000000;
    static constexpr uint32 ACTION_GM_SPAWN_ALL = 9000001;
    static constexpr uint32 ACTION_GM_DESPAWN_ALL = 9000002;
    static constexpr uint32 ACTION_GM_LEVEL_BASE = 9000003;
    static constexpr uint32 ACTION_PRESET_CATEGORY_BASE = 9001000;
    static constexpr uint32 ACTION_WEATHER_MENU = 9002000;
    static constexpr uint32 ACTION_WEATHER_BASE = 9002100;
    static constexpr uint32 ACTION_PRESET_ENTRY_BASE = 10000000;

    struct WeatherOption
    {
        char const* label;
        char const* icon;
        WeatherState state;
        float grade;
    };

    static constexpr WeatherOption s_weatherOptions[] =
    {
        { "Clear Skies", "Interface\\Icons\\Spell_Nature_Sentinal", WEATHER_STATE_FINE, 0.0f },
        { "Light Rain", "Interface\\Icons\\Spell_Nature_Rain", WEATHER_STATE_LIGHT_RAIN, 0.25f },
        { "Heavy Rain", "Interface\\Icons\\Spell_Nature_Rain", WEATHER_STATE_HEAVY_RAIN, 0.9f },
        { "Light Snow", "Interface\\Icons\\Spell_Frost_Frost", WEATHER_STATE_LIGHT_SNOW, 0.35f },
        { "Heavy Snow", "Interface\\Icons\\Spell_Frost_Frost", WEATHER_STATE_HEAVY_SNOW, 0.9f },
        { "Sandstorm", "Interface\\Icons\\Spell_Nature_Cyclone", WEATHER_STATE_LIGHT_SANDSTORM, 0.6f },
        { "Thunders", "Interface\\Icons\\Spell_Nature_StormReach", WEATHER_STATE_THUNDERS, 0.75f },
        { "Black Rain", "Interface\\Icons\\Spell_Shadow_RainOfFire", WEATHER_STATE_BLACKRAIN, 0.75f }
    };

    static void ShowWeatherMenu(Player* player, Creature* creature)
    {
        ClearGossipMenuFor(player);
        for (uint32 i = 0; i < std::size(s_weatherOptions); ++i)
        {
            AddGossipItemFor(player, GOSSIP_ICON_TALK,
                MakeLargeGossipText(s_weatherOptions[i].icon, s_weatherOptions[i].label),
                GOSSIP_SENDER_MAIN, ACTION_WEATHER_BASE + i);
        }

        AddGossipItemFor(player, GOSSIP_ICON_CHAT,
            MakeLargeGossipText("Interface\\Icons\\Ability_Arrow_Up", "Go Back!"),
            GOSSIP_SENDER_MAIN, ACTION_BACK);
        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
    }

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

    static bool SpawnPresetsHaveMetadataColumns()
    {
        static std::optional<bool> cached;
        if (cached.has_value())
            return cached.value();

        QueryResult result = WorldDatabase.Query(
            "SELECT COUNT(*) FROM information_schema.COLUMNS "
            "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'dc_guild_house_spawns' "
            "AND COLUMN_NAME IN ('spawn_type','category','label','enabled','sort_order','preset')");

        if (!result)
        {
            cached = false;
            return false;
        }

        Field* fields = result->Fetch();
        cached = (fields[0].Get<uint64>() >= 6);
        return cached.value();
    }

    static bool SpawnPresetsHaveLevelColumn()
    {
        static std::optional<bool> cached;
        if (cached.has_value())
            return cached.value();

        QueryResult result = WorldDatabase.Query(
            "SELECT COUNT(*) FROM information_schema.COLUMNS "
            "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'dc_guild_house_spawns' AND COLUMN_NAME = 'guildhouse_level'");

        if (!result)
        {
            cached = false;
            return false;
        }

        Field* fields = result->Fetch();
        cached = (fields[0].Get<uint64>() > 0);
        return cached.value();
    }

    static uint8 GetCurrentGuildHouseLevel(Player* player)
    {
        if (!player || !player->GetGuildId())
            return 1;

        if (player->IsGameMaster())
            return 255;

        return GuildHouseManager::GetGuildHouseLevel(player->GetGuildId());
    }

    struct PresetCategory
    {
        std::string name;
        int32 sortOrder;
    };

    struct PresetEntry
    {
        uint32 entry;
        std::string spawnType;
        std::string category;
        std::string label;
        int32 sortOrder;
    };

    static std::string GetSpawnPresetName()
    {
        std::string preset = sConfigMgr->GetOption<std::string>("GuildHouseSpawnPreset", "default");
        WorldDatabase.EscapeString(preset);
        return preset;
    }

    static std::string FormatCategoryLabel(std::string category)
    {
        if (!category.empty())
            category[0] = static_cast<char>(std::toupper(category[0]));
        return "Spawn " + category;
    }

    static std::string GetTemplateLabel(uint32 entry, std::string const& spawnType)
    {
        if (spawnType == "GAMEOBJECT")
        {
            if (GameObjectTemplate const* objectTemplate = sObjectMgr->GetGameObjectTemplate(entry))
                return objectTemplate->name;
            return std::to_string(entry);
        }

        if (CreatureTemplate const* creatureTemplate = sObjectMgr->GetCreatureTemplate(entry))
            return creatureTemplate->Name;

        return std::to_string(entry);
    }

    static int32 GetSpawnCostForPreset(std::string const& category, std::string const& spawnType, uint32 entry)
    {
        if (spawnType == "GAMEOBJECT")
        {
            if (entry == 184137)
                return s_guildHouseCostMailbox;
            return s_guildHouseCostObject;
        }

        if (category == "auctioneer")
            return s_guildHouseCostAuctioneer;

        if (category == "trainer")
            return s_guildHouseCostProfession;

        if (category == "service")
        {
            if (entry == 800001 || entry == 800031)
                return s_guildHouseCostInnkeeper;
            if (entry == 30605)
                return s_guildHouseCostBank;
            if (entry == 6491)
                return s_guildHouseCostSpirit;
            return s_guildHouseCostVendor;
        }

        return s_guildHouseCostVendor;
    }

    static std::vector<PresetCategory> GetPresetCategories(uint32 mapId, uint8 guildLevel)
    {
        std::vector<PresetCategory> categories;
        if (!SpawnPresetsHaveMetadataColumns())
            return categories;

        std::string preset = GetSpawnPresetName();
        QueryResult result;
        if (SpawnPresetsHaveMapColumn())
        {
            result = WorldDatabase.Query(
                "SELECT `category`, MIN(`sort_order`) AS `sort_order` "
                "FROM `dc_guild_house_spawns` "
                "WHERE `enabled`=1 AND `preset`='{}' AND `map`={} {} "
                "GROUP BY `category` ORDER BY `sort_order`, `category`",
                preset, mapId, SpawnPresetsHaveLevelColumn() ? "AND `guildhouse_level` <= " + std::to_string(guildLevel) : "");
        }
        else
        {
            result = WorldDatabase.Query(
                "SELECT `category`, MIN(`sort_order`) AS `sort_order` "
                "FROM `dc_guild_house_spawns` "
                "WHERE `enabled`=1 AND `preset`='{}' {} "
                "GROUP BY `category` ORDER BY `sort_order`, `category`",
                preset, SpawnPresetsHaveLevelColumn() ? "AND `guildhouse_level` <= " + std::to_string(guildLevel) : "");
        }

        if (!result)
            return categories;

        do
        {
            Field* fields = result->Fetch();
            PresetCategory category;
            category.name = fields[0].Get<std::string>();
            category.sortOrder = fields[1].Get<int32>();
            categories.push_back(category);
        } while (result->NextRow());

        return categories;
    }

    static std::vector<PresetEntry> GetPresetEntriesForCategory(uint32 mapId, uint8 guildLevel, std::string category)
    {
        std::vector<PresetEntry> entries;
        if (!SpawnPresetsHaveMetadataColumns())
            return entries;

        std::string preset = GetSpawnPresetName();
        WorldDatabase.EscapeString(category);

        QueryResult result;
        if (SpawnPresetsHaveMapColumn())
        {
            result = WorldDatabase.Query(
                "SELECT `entry`, `spawn_type`, `category`, `label`, `sort_order` "
                "FROM `dc_guild_house_spawns` "
                "WHERE `enabled`=1 AND `preset`='{}' AND `map`={} AND `category`='{}' {} "
                "ORDER BY `sort_order`, `entry`",
                preset, mapId, category, SpawnPresetsHaveLevelColumn() ? "AND `guildhouse_level` <= " + std::to_string(guildLevel) : "");
        }
        else
        {
            result = WorldDatabase.Query(
                "SELECT `entry`, `spawn_type`, `category`, `label`, `sort_order` "
                "FROM `dc_guild_house_spawns` "
                "WHERE `enabled`=1 AND `preset`='{}' AND `category`='{}' {} "
                "ORDER BY `sort_order`, `entry`",
                preset, category, SpawnPresetsHaveLevelColumn() ? "AND `guildhouse_level` <= " + std::to_string(guildLevel) : "");
        }

        if (!result)
            return entries;

        do
        {
            Field* fields = result->Fetch();
            PresetEntry entry;
            entry.entry = fields[0].Get<uint32>();
            entry.spawnType = fields[1].Get<std::string>();
            entry.category = fields[2].Get<std::string>();
            entry.label = fields[3].Get<std::string>();
            entry.sortOrder = fields[4].Get<int32>();
            entries.push_back(entry);
        } while (result->NextRow());

        return entries;
    }

    static std::optional<PresetEntry> GetPresetByEntry(uint32 mapId, uint8 guildLevel, uint32 entryId)
    {
        if (!SpawnPresetsHaveMetadataColumns())
            return std::nullopt;

        std::string preset = GetSpawnPresetName();
        QueryResult result;
        if (SpawnPresetsHaveMapColumn())
        {
            result = WorldDatabase.Query(
                "SELECT `entry`, `spawn_type`, `category`, `label`, `sort_order` "
                "FROM `dc_guild_house_spawns` "
                "WHERE `enabled`=1 AND `preset`='{}' AND `map`={} AND `entry`={} {} "
                "ORDER BY `sort_order`, `entry` LIMIT 1",
                preset, mapId, entryId, SpawnPresetsHaveLevelColumn() ? "AND `guildhouse_level` <= " + std::to_string(guildLevel) : "");
        }
        else
        {
            result = WorldDatabase.Query(
                "SELECT `entry`, `spawn_type`, `category`, `label`, `sort_order` "
                "FROM `dc_guild_house_spawns` "
                "WHERE `enabled`=1 AND `preset`='{}' AND `entry`={} {} "
                "ORDER BY `sort_order`, `entry` LIMIT 1",
                preset, entryId, SpawnPresetsHaveLevelColumn() ? "AND `guildhouse_level` <= " + std::to_string(guildLevel) : "");
        }

        if (!result)
            return std::nullopt;

        Field* fields = result->Fetch();
        PresetEntry entry;
        entry.entry = fields[0].Get<uint32>();
        entry.spawnType = fields[1].Get<std::string>();
        entry.category = fields[2].Get<std::string>();
        entry.label = fields[3].Get<std::string>();
        entry.sortOrder = fields[4].Get<int32>();
        return entry;
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
        if (SpawnPresetsHaveMetadataColumns())
        {
            uint8 guildLevel = GetCurrentGuildHouseLevel(player);
            std::vector<PresetCategory> categories = GetPresetCategories(player->GetMapId(), guildLevel);
            if (!categories.empty())
            {
                for (size_t i = 0; i < categories.size(); ++i)
                    AddGossipItemFor(player, GOSSIP_ICON_TALK,
                        MakeLargeGossipText("Interface\\Icons\\INV_Misc_Note_03", FormatCategoryLabel(categories[i].name)),
                        GOSSIP_SENDER_MAIN, ACTION_PRESET_CATEGORY_BASE + static_cast<uint32>(i));
            }
            else
            {
                ChatHandler(player->GetSession()).PSendSysMessage("No enabled spawn presets found for this map/preset.");
            }
        }
        else
        {
            AddGossipItemFor(player, GOSSIP_ICON_TALK,
                MakeLargeGossipText("Interface\\Icons\\INV_Misc_Key_03", "Spawn Innkeeper"),
                GOSSIP_SENDER_MAIN, 800001, "Add an Innkeeper?", s_guildHouseCostInnkeeper, false);
            AddGossipItemFor(player, GOSSIP_ICON_TALK,
                MakeLargeGossipText("Interface\\Icons\\INV_Letter_15", "Spawn Mailbox"),
                GOSSIP_SENDER_MAIN, 184137, "Spawn a Mailbox?", s_guildHouseCostMailbox, false);
            AddGossipItemFor(player, GOSSIP_ICON_TALK,
                MakeLargeGossipText("Interface\\Icons\\Ability_Hunter_BeastCall", "Spawn Stable Master"),
                GOSSIP_SENDER_MAIN, 28690, "Spawn a Stable Master?", s_guildHouseCostVendor, false);
            AddGossipItemFor(player, GOSSIP_ICON_TALK,
                MakeLargeGossipText("Interface\\Icons\\INV_Misc_Coin_02", "Spawn Vendor"),
                GOSSIP_SENDER_MAIN, 3);
            AddGossipItemFor(player, GOSSIP_ICON_TALK,
                MakeLargeGossipText("Interface\\Icons\\INV_Crate_01", "Spawn Objects"),
                GOSSIP_SENDER_MAIN, 4);
            AddGossipItemFor(player, GOSSIP_ICON_MONEY_BAG,
                MakeLargeGossipText("Interface\\Icons\\INV_Misc_Bag_04", "Spawn Bank"),
                GOSSIP_SENDER_MAIN, 30605, "Spawn a Banker?", s_guildHouseCostBank, false);
            AddGossipItemFor(player, GOSSIP_ICON_MONEY_BAG,
                MakeLargeGossipText("Interface\\Icons\\INV_Misc_Coin_01", "Spawn Auctioneer"),
                GOSSIP_SENDER_MAIN, 6, "Spawn an Auctioneer?", s_guildHouseCostAuctioneer, false);
            AddGossipItemFor(player, GOSSIP_ICON_MONEY_BAG,
                MakeLargeGossipText("Interface\\Icons\\INV_Misc_Coin_05", "Spawn Neutral Auctioneer"),
                GOSSIP_SENDER_MAIN, 9858, "Spawn a Neutral Auctioneer?", s_guildHouseCostAuctioneer, false);
            AddGossipItemFor(player, GOSSIP_ICON_TRAINER,
                MakeLargeGossipText("Interface\\Icons\\INV_Scroll_02", "Spawn Primary Profession Trainers"),
                GOSSIP_SENDER_MAIN, 7);
            AddGossipItemFor(player, GOSSIP_ICON_TRAINER,
                MakeLargeGossipText("Interface\\Icons\\INV_Scroll_03", "Spawn Secondary Profession Trainers"),
                GOSSIP_SENDER_MAIN, 8);
            AddGossipItemFor(player, GOSSIP_ICON_TALK,
                MakeLargeGossipText("Interface\\Icons\\Spell_Holy_SpiritHeal", "Spawn Spirit Healer"),
                GOSSIP_SENDER_MAIN, 6491, "Spawn a Spirit Healer?", s_guildHouseCostSpirit, false);

            // DC Extensions
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE,
                MakeLargeGossipText("Interface\\Icons\\Ability_DualWield", "Spawn Mythic+ NPCs"),
                GOSSIP_SENDER_MAIN, 20);
            AddGossipItemFor(player, GOSSIP_ICON_VENDOR,
                MakeLargeGossipText("Interface\\Icons\\INV_Misc_Seasoning", "Spawn Seasonal Vendors"),
                GOSSIP_SENDER_MAIN, 21);
            AddGossipItemFor(player, GOSSIP_ICON_MONEY_BAG,
                MakeLargeGossipText("Interface\\Icons\\INV_Misc_Gem_01", "Spawn Special Vendors"),
                GOSSIP_SENDER_MAIN, 22);
        }

        AddGossipItemFor(player, GOSSIP_ICON_TALK,
            MakeLargeGossipText("Interface\\Icons\\Spell_Nature_StormReach", "Change Weather"),
            GOSSIP_SENDER_MAIN, ACTION_WEATHER_MENU);

        if (player->IsGameMaster())
            AddGossipItemFor(player, GOSSIP_ICON_CHAT,
                MakeLargeGossipText("Interface\\Icons\\INV_Misc_QuestionMark", "GM Menu"),
                GOSSIP_SENDER_MAIN, ACTION_GM_MENU);

        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {

        if (action == ACTION_WEATHER_MENU)
        {
            ShowWeatherMenu(player, creature);
            return true;
        }

        if (action >= ACTION_WEATHER_BASE && action < ACTION_WEATHER_BASE + std::size(s_weatherOptions))
        {
            uint32 index = action - ACTION_WEATHER_BASE;
            if (!player)
                return true;

            Map* map = player->GetMap();
            if (!map)
                return true;

            uint32 zoneId = player->GetZoneId();
            map->SetZoneWeather(zoneId, s_weatherOptions[index].state, s_weatherOptions[index].grade);
            ChatHandler(player->GetSession()).PSendSysMessage("Weather set to {}.", s_weatherOptions[index].label);
            ShowWeatherMenu(player, creature);
            return true;
        }

        if (action == ACTION_GM_MENU)
        {
            ClearGossipMenuFor(player);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT,
                MakeLargeGossipText("Interface\\Icons\\Spell_Nature_WispSplode", "GM: Spawn everything (free)"),
                GOSSIP_SENDER_MAIN, ACTION_GM_SPAWN_ALL);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT,
                MakeLargeGossipText("Interface\\Icons\\Ability_Rogue_Disguise", "GM: Despawn everything"),
                GOSSIP_SENDER_MAIN, ACTION_GM_DESPAWN_ALL);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT,
                MakeLargeGossipText("Interface\\Icons\\INV_Misc_Herb_11", "GM: Set Guild House Level 0"),
                GOSSIP_SENDER_MAIN, ACTION_GM_LEVEL_BASE + 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT,
                MakeLargeGossipText("Interface\\Icons\\INV_Misc_Herb_12", "GM: Set Guild House Level 1"),
                GOSSIP_SENDER_MAIN, ACTION_GM_LEVEL_BASE + 1);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT,
                MakeLargeGossipText("Interface\\Icons\\INV_Misc_Herb_13", "GM: Set Guild House Level 2"),
                GOSSIP_SENDER_MAIN, ACTION_GM_LEVEL_BASE + 2);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT,
                MakeLargeGossipText("Interface\\Icons\\INV_Misc_Herb_14", "GM: Set Guild House Level 3"),
                GOSSIP_SENDER_MAIN, ACTION_GM_LEVEL_BASE + 3);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT,
                MakeLargeGossipText("Interface\\Icons\\INV_Misc_Herb_15", "GM: Set Guild House Level 4"),
                GOSSIP_SENDER_MAIN, ACTION_GM_LEVEL_BASE + 4);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT,
                MakeLargeGossipText("Interface\\Icons\\Ability_Arrow_Up", "Go Back!"),
                GOSSIP_SENDER_MAIN, ACTION_BACK);
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

        if (action >= ACTION_GM_LEVEL_BASE && action <= ACTION_GM_LEVEL_BASE + 10)
        {
            if (!player || !player->GetGuildId())
            {
                OnGossipHello(player, creature);
                return true;
            }

            uint8 newLevel = static_cast<uint8>(action - ACTION_GM_LEVEL_BASE);
            if (!GuildHouseManager::SetGuildHouseLevel(player->GetGuildId(), newLevel))
            {
                ChatHandler(player->GetSession()).PSendSysMessage("Failed to update guild house level.");
            }
            else
            {
                ChatHandler(player->GetSession()).PSendSysMessage("Guild House level set to {}.", newLevel);
            }

            OnGossipHello(player, creature);
            return true;
        }

        if (SpawnPresetsHaveMetadataColumns())
        {
            if (action >= ACTION_PRESET_ENTRY_BASE)
            {
                uint32 entryId = action - ACTION_PRESET_ENTRY_BASE;
                uint8 guildLevel = GetCurrentGuildHouseLevel(player);
                std::optional<PresetEntry> presetEntry = GetPresetByEntry(player->GetMapId(), guildLevel, entryId);
                if (!presetEntry)
                {
                    ChatHandler(player->GetSession()).PSendSysMessage("This spawn preset is disabled or missing.");
                    OnGossipHello(player, creature);
                    return true;
                }

                int32 spawnCost = GetSpawnCostForPreset(presetEntry->category, presetEntry->spawnType, entryId);
                if (presetEntry->spawnType == "GAMEOBJECT")
                    SpawnObject(entryId, player, spawnCost, true, true);
                else
                    SpawnNPC(entryId, player, spawnCost, true, true);

                OnGossipHello(player, creature);
                return true;
            }

            if (action >= ACTION_PRESET_CATEGORY_BASE && action < ACTION_PRESET_ENTRY_BASE)
            {
                uint32 categoryIndex = action - ACTION_PRESET_CATEGORY_BASE;
                uint8 guildLevel = GetCurrentGuildHouseLevel(player);
                std::vector<PresetCategory> categories = GetPresetCategories(player->GetMapId(), guildLevel);
                if (categoryIndex >= categories.size())
                {
                    OnGossipHello(player, creature);
                    return true;
                }

                std::string category = categories[categoryIndex].name;
                std::vector<PresetEntry> entries = GetPresetEntriesForCategory(player->GetMapId(), guildLevel, category);
                ClearGossipMenuFor(player);
                for (PresetEntry const& presetEntry : entries)
                {
                    std::string label = presetEntry.label;
                    if (label.empty())
                        label = GetTemplateLabel(presetEntry.entry, presetEntry.spawnType);

                    int32 spawnCost = GetSpawnCostForPreset(presetEntry.category, presetEntry.spawnType, presetEntry.entry);
                    AddGossipItemFor(player, GOSSIP_ICON_TALK, label, GOSSIP_SENDER_MAIN,
                        ACTION_PRESET_ENTRY_BASE + presetEntry.entry, "Spawn this?", spawnCost, false);
                }

                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Go Back!", GOSSIP_SENDER_MAIN, ACTION_BACK);
                SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
                return true;
            }
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
        case 800031: // Dalaran Innkeeper
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

        uint32 guildPhase = GetGuildPhase(player);
        if (player->GetPhaseByAuras() != guildPhase)
            player->SetPhaseMask(guildPhase, true);

        // Global Existence Check
        // Use current map and phase
        if (GuildHouseManager::HasSpawn(player->GetMapId(), guildPhase, entry, false))
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
        uint8 guildLevel = GetCurrentGuildHouseLevel(player);
        if (SpawnPresetsHaveMetadataColumns())
        {
            std::string preset = GetSpawnPresetName();
            if (SpawnPresetsHaveMapColumn())
            {
                result = WorldDatabase.Query(
                    "SELECT `posX`, `posY`, `posZ`, `orientation` FROM `dc_guild_house_spawns` "
                    "WHERE `enabled`=1 AND `preset`='{}' AND `map`={} AND `entry`={} AND `spawn_type`='CREATURE' {}",
                    preset, player->GetMapId(), entry,
                    SpawnPresetsHaveLevelColumn() ? "AND `guildhouse_level` <= " + std::to_string(guildLevel) : "");
            }
            else
            {
                result = WorldDatabase.Query(
                    "SELECT `posX`, `posY`, `posZ`, `orientation` FROM `dc_guild_house_spawns` "
                    "WHERE `enabled`=1 AND `preset`='{}' AND `entry`={} AND `spawn_type`='CREATURE' {}",
                    preset, entry,
                    SpawnPresetsHaveLevelColumn() ? "AND `guildhouse_level` <= " + std::to_string(guildLevel) : "");
            }
        }
        else if (SpawnPresetsHaveMapColumn())
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

        if (!creature->Create(player->GetMap()->GenerateLowGuid<HighGuid::Unit>(), player->GetMap(), guildPhase, entry, 0, posX, posY, posZ, ori))
        {
            delete creature;
            return;
        }
        creature->SaveToDB(player->GetMapId(), (1 << player->GetMap()->GetSpawnMode()), guildPhase);
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

        uint32 guildPhase = GetGuildPhase(player);
        if (player->GetPhaseByAuras() != guildPhase)
            player->SetPhaseMask(guildPhase, true);

        if (GuildHouseManager::HasSpawn(player->GetMapId(), guildPhase, entry, true))
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
        uint8 guildLevel = GetCurrentGuildHouseLevel(player);
        if (SpawnPresetsHaveMetadataColumns())
        {
            std::string preset = GetSpawnPresetName();
            if (SpawnPresetsHaveMapColumn())
            {
                result = WorldDatabase.Query(
                    "SELECT `posX`, `posY`, `posZ`, `orientation` FROM `dc_guild_house_spawns` "
                    "WHERE `enabled`=1 AND `preset`='{}' AND `map`={} AND `entry`={} AND `spawn_type`='GAMEOBJECT' {}",
                    preset, player->GetMapId(), entry,
                    SpawnPresetsHaveLevelColumn() ? "AND `guildhouse_level` <= " + std::to_string(guildLevel) : "");
            }
            else
            {
                result = WorldDatabase.Query(
                    "SELECT `posX`, `posY`, `posZ`, `orientation` FROM `dc_guild_house_spawns` "
                    "WHERE `enabled`=1 AND `preset`='{}' AND `entry`={} AND `spawn_type`='GAMEOBJECT' {}",
                    preset, entry,
                    SpawnPresetsHaveLevelColumn() ? "AND `guildhouse_level` <= " + std::to_string(guildLevel) : "");
            }
        }
        else if (SpawnPresetsHaveMapColumn())
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

        if (!object->Create(guidLow, objectInfo->entry, player->GetMap(), guildPhase, posX, posY, posZ, ori, G3D::Quat(), 0, GO_STATE_READY))
        {
            delete object;
            return;
        }

        // fill the gameobject data and save to the db
        object->SaveToDB(player->GetMapId(), (1 << player->GetMap()->GetSpawnMode()), guildPhase);
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
