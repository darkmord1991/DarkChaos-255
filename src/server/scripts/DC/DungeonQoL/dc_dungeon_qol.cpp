/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * Dungeon QoL: shared config snapshot, combat helpers and the single script
 * entry point AddSC_dc_dungeon_qol().
 */

#include "dc_dungeon_qol.h"
#include "Config.h"
#include "InstanceScript.h"
#include "Log.h"
#include "Map.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "StringConvert.h"
#include "Tokenize.h"

#include <algorithm>
#include <cctype>
#include <mutex>
#include <string>
#include <string_view>

namespace
{
    // The DC custom raids (Map.dbc InstanceType 2): Blackwing Descent, Timbermaw Hold,
    // Emerald Sanctum, Castle Nathria, Naxxramas 40.
    constexpr char const* DEFAULT_RAID_MAPS = "669,819,824,2296,2921";

    // The DC 5-player dungeons with no DungeonEncounter.dbc rows: Stratholme 821 (Baron Rivendare,
    // and Balnazzar - Dathrohan becomes stock entry 10813 mid-fight), Scholomance 822 (Darkmaster
    // Gandling), Shadowfang Keep Cata 825 (Lord Godfrey).
    constexpr char const* DEFAULT_FINAL_BOSSES = "821:5500038,821:10813,822:5700000,825:5046964";

    std::mutex g_settingsLock;
    std::shared_ptr<DC::DungeonQoL::Settings const> g_settings;

    std::string_view TrimToken(std::string_view token)
    {
        while (!token.empty() && std::isspace(static_cast<unsigned char>(token.front())))
            token.remove_prefix(1);

        while (!token.empty() && std::isspace(static_cast<unsigned char>(token.back())))
            token.remove_suffix(1);

        return token;
    }

    std::unordered_set<uint32> ParseMapList(std::string const& text, char const* key)
    {
        std::unordered_set<uint32> maps;
        for (std::string_view token : Acore::Tokenize(text, ',', false))
        {
            token = TrimToken(token);
            if (token.empty())
                continue;

            if (Optional<uint32> mapId = Acore::StringTo<uint32>(token))
                maps.insert(*mapId);
            else
                LOG_ERROR("scripts.dc", "{}: '{}' is not a map id, ignored.", key, token);
        }

        return maps;
    }

    // "map:creatureEntry" pairs, comma-separated.
    std::unordered_set<uint64> ParseBossList(std::string const& text, char const* key)
    {
        std::unordered_set<uint64> bosses;
        for (std::string_view token : Acore::Tokenize(text, ',', false))
        {
            token = TrimToken(token);
            if (token.empty())
                continue;

            Optional<uint32> mapId;
            Optional<uint32> entry;
            std::size_t const colon = token.find(':');
            if (colon != std::string_view::npos)
            {
                mapId = Acore::StringTo<uint32>(TrimToken(token.substr(0, colon)));
                entry = Acore::StringTo<uint32>(TrimToken(token.substr(colon + 1)));
            }

            if (mapId && entry)
                bosses.insert(DC::DungeonQoL::FinalBossKey(*mapId, *entry));
            else
                LOG_ERROR("scripts.dc", "{}: '{}' is not a map:creature pair, ignored.", key, token);
        }

        return bosses;
    }

    class dc_dungeon_qol_world : public WorldScript
    {
    public:
        dc_dungeon_qol_world() : WorldScript("dc_dungeon_qol_world", { WORLDHOOK_ON_AFTER_CONFIG_LOAD }) { }

        void OnAfterConfigLoad(bool /*reload*/) override
        {
            DC::DungeonQoL::LoadSettings();
        }
    };
}

namespace DC::DungeonQoL
{
    void LoadSettings()
    {
        auto settings = std::make_shared<Settings>();
        settings->battleResEnable = sConfigMgr->GetOption<bool>("DC.BattleRes.Enable", true);
        settings->battleResRechargeMinutes =
            sConfigMgr->GetOption<uint32>("DC.BattleRes.MythicPlusRechargeMinutes", 10);
        settings->battleResRaidMaps = ParseMapList(
            sConfigMgr->GetOption<std::string>("DC.BattleRes.RaidMaps", DEFAULT_RAID_MAPS), "DC.BattleRes.RaidMaps");
        settings->checkpointMaps = ParseMapList(
            sConfigMgr->GetOption<std::string>("DC.CheckpointRelease.Maps", ""), "DC.CheckpointRelease.Maps");
        settings->checkpointMythicPlus = sConfigMgr->GetOption<bool>("DC.CheckpointRelease.MythicPlus", true);
        settings->finalBossReviveEnable = sConfigMgr->GetOption<bool>("DC.FinalBossRevive.Enable", true);
        uint32 const restorePct =
            std::clamp<uint32>(sConfigMgr->GetOption<uint32>("DC.FinalBossRevive.RestorePct", 100), 1, 100);
        settings->finalBossReviveRestore = restorePct / 100.0f;
        settings->finalBossReviveExtraBosses = ParseBossList(
            sConfigMgr->GetOption<std::string>("DC.FinalBossRevive.ExtraBosses", DEFAULT_FINAL_BOSSES),
            "DC.FinalBossRevive.ExtraBosses");

        LOG_INFO("scripts.dc", "Dungeon QoL: battle res {} ({} raid maps, Mythic+ recharge {} min), "
            "checkpoint release on {} listed maps, Mythic+ checkpoints {}, "
            "final boss revive {} ({}%, {} extra bosses).",
            settings->battleResEnable ? "on" : "off", settings->battleResRaidMaps.size(),
            settings->battleResRechargeMinutes, settings->checkpointMaps.size(),
            settings->checkpointMythicPlus ? "on" : "off", settings->finalBossReviveEnable ? "on" : "off",
            restorePct, settings->finalBossReviveExtraBosses.size());

        std::lock_guard<std::mutex> guard(g_settingsLock);
        g_settings = std::move(settings);
    }

    std::shared_ptr<Settings const> GetSettings()
    {
        {
            std::lock_guard<std::mutex> guard(g_settingsLock);
            if (g_settings)
                return g_settings;
        }

        // Only reached if a hook fires before the first OnAfterConfigLoad.
        LoadSettings();
        std::lock_guard<std::mutex> guard(g_settingsLock);
        return g_settings;
    }

    bool IsEncounterInProgress(Map* map)
    {
        InstanceMap* instanceMap = map ? map->ToInstanceMap() : nullptr;
        InstanceScript* script = instanceMap ? instanceMap->GetInstanceScript() : nullptr;
        return script && script->IsEncounterInProgress();
    }

    bool IsAnyPlayerInCombat(Map* map)
    {
        if (!map)
            return false;

        for (auto const& ref : map->GetPlayers())
        {
            Player* player = ref.GetSource();
            if (player && player->IsAlive() && !player->IsGameMaster() && player->IsInCombat())
                return true;
        }

        return false;
    }

    bool IsInstanceInCombat(Map* map)
    {
        return IsEncounterInProgress(map) || IsAnyPlayerInCombat(map);
    }
}

void AddSC_dc_dungeon_qol()
{
    new dc_dungeon_qol_world();
    DC::DungeonQoL::RegisterBattleResurrectionScripts();
    DC::DungeonQoL::RegisterCheckpointReleaseScripts();
    DC::DungeonQoL::RegisterFinalBossReviveScripts();
}
