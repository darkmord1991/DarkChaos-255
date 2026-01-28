/*
 * DarkChaos-WoW Universal Dungeon Quest Master NPC
 * Copyright (C) 2025-2026 DarkChaos-WoW
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2 of the License, or (at your
 * option) any later version.
 *
 * Universal Quest Master NPC (Entry 700100):
 * - Single NPC that dynamically shows quests based on current dungeon
 * - Thread-safe cached quest mappings for performance
 * - Dynamic DisplayId per dungeon theme (set on spawn, not on proximity)
 * - Handles both quest giving and quest completion
 * - Always includes global Daily/Weekly quests
 * - GM command: .reload dc_dungeon_quests
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Creature.h"
#include "Config.h"
#include "Chat.h"
#include "ObjectMgr.h"
#include "DatabaseEnv.h"
#include "World.h"
#include "Log.h"
#include "ScriptedGossip.h"
#include "QuestDef.h"
#include "ChatCommand.h"
#include "DungeonQuestConstants.h"
#include "DungeonQuestHelpers.h"
#include <mutex>

using namespace DungeonQuest;
using namespace DungeonQuestHelpers;
using namespace Acore::ChatCommands;

// =====================================================================
// THREAD-SAFE CACHE SYSTEM FOR QUEST-DUNGEON MAPPINGS
// =====================================================================

class UniversalQuestMasterCache
{
private:
    // Map: dungeon_id (map_id) -> vector of quest_ids for that dungeon
    static std::unordered_map<uint32, std::vector<uint32>> _dungeonQuests;
    // Map: dungeon_id (map_id) -> display_id for the NPC
    static std::unordered_map<uint32, uint32> _dungeonDisplayIds;
    // Daily quest IDs (always shown)
    static std::vector<uint32> _dailyQuests;
    // Weekly quest IDs (always shown)
    static std::vector<uint32> _weeklyQuests;
    static bool _cacheLoaded;
    // Thread safety mutex
    static std::mutex _cacheMutex;

public:
    static void LoadCache()
    {
        std::lock_guard<std::mutex> lock(_cacheMutex);
        
        if (_cacheLoaded)
            return;

        LoadCacheInternal();
    }

    static void ReloadCache()
    {
        std::lock_guard<std::mutex> lock(_cacheMutex);
        
        // Clear existing data
        _dungeonQuests.clear();
        _dungeonDisplayIds.clear();
        _dailyQuests.clear();
        _weeklyQuests.clear();
        _cacheLoaded = false;
        
        LoadCacheInternal();
        
        LOG_INFO("scripts.dc", "UniversalQuestMaster: Cache reloaded successfully");
    }

private:
    static void LoadCacheInternal()
    {
        uint32 totalMappings = 0;

        // Load dungeon -> quest mappings from dc_dungeon_quest_mapping
        QueryResult result = WorldDatabase.Query(
            "SELECT dungeon_id, quest_id FROM dc_dungeon_quest_mapping ORDER BY dungeon_id, quest_id"
        );
        if (result)
        {
            do
            {
                Field* fields = result->Fetch();
                uint32 dungeonId = fields[0].Get<uint32>();
                uint32 questId = fields[1].Get<uint32>();

                _dungeonQuests[dungeonId].push_back(questId);
                ++totalMappings;

            } while (result->NextRow());
        }
        LOG_INFO("scripts.dc", "UniversalQuestMaster: Loaded {} quest mappings for {} dungeons",
                 totalMappings, _dungeonQuests.size());

        // Load display IDs from dc_dungeon_npc_mapping
        result = WorldDatabase.Query(
            "SELECT map_id, display_id FROM dc_dungeon_npc_mapping WHERE display_id IS NOT NULL AND display_id > 0"
        );
        if (result)
        {
            do
            {
                Field* fields = result->Fetch();
                uint32 mapId = fields[0].Get<uint32>();
                uint32 displayId = fields[1].Get<uint32>();

                _dungeonDisplayIds[mapId] = displayId;

            } while (result->NextRow());
        }
        LOG_INFO("scripts.dc", "UniversalQuestMaster: Loaded {} display ID mappings", _dungeonDisplayIds.size());

        // Load daily quests (from quest_template in our range)
        result = WorldDatabase.Query(
            "SELECT ID FROM quest_template WHERE ID BETWEEN {} AND {}",
            QUEST_DAILY_MIN, QUEST_DAILY_MAX
        );
        if (result)
        {
            do
            {
                _dailyQuests.push_back((*result)[0].Get<uint32>());
            } while (result->NextRow());
        }
        LOG_INFO("scripts.dc", "UniversalQuestMaster: Loaded {} daily quests", _dailyQuests.size());

        // Load weekly quests
        result = WorldDatabase.Query(
            "SELECT ID FROM quest_template WHERE ID BETWEEN {} AND {}",
            QUEST_WEEKLY_MIN, QUEST_WEEKLY_MAX
        );
        if (result)
        {
            do
            {
                _weeklyQuests.push_back((*result)[0].Get<uint32>());
            } while (result->NextRow());
        }
        LOG_INFO("scripts.dc", "UniversalQuestMaster: Loaded {} weekly quests", _weeklyQuests.size());

        _cacheLoaded = true;
        LOG_INFO("scripts.dc", "UniversalQuestMaster: Cache loading complete");
    }

public:
    static std::vector<uint32> const& GetQuestsForDungeon(uint32 dungeonId)
    {
        // Note: Read access should be safe after initial load
        static std::vector<uint32> empty;
        auto it = _dungeonQuests.find(dungeonId);
        return (it != _dungeonQuests.end()) ? it->second : empty;
    }

    static uint32 GetDisplayIdForDungeon(uint32 dungeonId)
    {
        auto it = _dungeonDisplayIds.find(dungeonId);
        // Default display: Human Male Quest Giver (like standard NPCs)
        return (it != _dungeonDisplayIds.end()) ? it->second : 16466;
    }

    static std::vector<uint32> const& GetDailyQuests() { return _dailyQuests; }
    static std::vector<uint32> const& GetWeeklyQuests() { return _weeklyQuests; }
    static bool IsCacheLoaded() { return _cacheLoaded; }
    static uint32 GetTotalQuestMappings() { return static_cast<uint32>(_dungeonQuests.size()); }
    static uint32 GetTotalDisplayMappings() { return static_cast<uint32>(_dungeonDisplayIds.size()); }
};

// Static member definitions
std::unordered_map<uint32, std::vector<uint32>> UniversalQuestMasterCache::_dungeonQuests;
std::unordered_map<uint32, uint32> UniversalQuestMasterCache::_dungeonDisplayIds;
std::vector<uint32> UniversalQuestMasterCache::_dailyQuests;
std::vector<uint32> UniversalQuestMasterCache::_weeklyQuests;
bool UniversalQuestMasterCache::_cacheLoaded = false;
std::mutex UniversalQuestMasterCache::_cacheMutex;

// =====================================================================
// GOSSIP ACTIONS
// =====================================================================

enum UniversalQuestMasterActions
{
    ACTION_SHOW_DUNGEON_QUESTS   = 2000,
    ACTION_SHOW_DAILY_QUESTS     = 2001,
    ACTION_SHOW_WEEKLY_QUESTS    = 2002,
    ACTION_SHOW_COMPLETABLE      = 2003,
    ACTION_SHOW_IN_PROGRESS      = 2004,
    ACTION_SHOW_STATS            = 2005,
    ACTION_BACK_TO_MAIN          = 2006,
};

// =====================================================================
// UNIVERSAL QUEST MASTER CREATURE SCRIPT
// =====================================================================

class npc_universal_quest_master : public CreatureScript
{
public:
    npc_universal_quest_master() : CreatureScript("npc_universal_quest_master") { }

    struct npc_universal_quest_masterAI : public ScriptedAI
    {
        npc_universal_quest_masterAI(Creature* creature) : ScriptedAI(creature) 
        {
            // Set display immediately on creation
            InitializeDisplay();
        }

        void Reset() override
        {
            // Set phase mask to be visible in all dungeon phases
            me->SetPhaseMask(0xFFFFFFFE, true);
            
            // Set display on reset as well (handles .npc respawn cases)
            InitializeDisplay();
        }

        void InitializeDisplay()
        {
            // Use creature's map, not player's - this works immediately on spawn
            uint32 mapId = me->GetMapId();
            uint32 displayId = UniversalQuestMasterCache::GetDisplayIdForDungeon(mapId);
            
            if (me->GetDisplayId() != displayId)
            {
                me->SetDisplayId(displayId);
                LOG_DEBUG("scripts.dc", "UniversalQuestMaster: Set DisplayId to {} for map {} on spawn",
                          displayId, mapId);
            }
        }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_universal_quest_masterAI(creature);
    }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        ClearGossipMenuFor(player);

        uint32 currentMapId = player->GetMapId();

        // Count available quests for display
        uint32 dungeonQuestCount = 0;
        uint32 completableCount = 0;

        // Check dungeon quests
        auto const& dungeonQuests = UniversalQuestMasterCache::GetQuestsForDungeon(currentMapId);
        for (uint32 questId : dungeonQuests)
        {
            Quest const* quest = sObjectMgr->GetQuestTemplate(questId);
            if (!quest)
                continue;

            QuestStatus status = player->GetQuestStatus(questId);
            if (status == QUEST_STATUS_NONE && player->CanTakeQuest(quest, false))
                ++dungeonQuestCount;
            else if (status == QUEST_STATUS_COMPLETE)
                ++completableCount;
        }

        // Check daily/weekly completable
        for (uint32 questId : UniversalQuestMasterCache::GetDailyQuests())
        {
            if (player->GetQuestStatus(questId) == QUEST_STATUS_COMPLETE)
                ++completableCount;
        }
        for (uint32 questId : UniversalQuestMasterCache::GetWeeklyQuests())
        {
            if (player->GetQuestStatus(questId) == QUEST_STATUS_COMPLETE)
                ++completableCount;
        }

        // Build main menu
        std::ostringstream dungeonOption;
        dungeonOption << "Dungeon Quests (" << dungeonQuestCount << " available)";
        AddGossipItemFor(player, GOSSIP_ICON_BATTLE, dungeonOption.str(), GOSSIP_SENDER_MAIN, ACTION_SHOW_DUNGEON_QUESTS);

        if (completableCount > 0)
        {
            std::ostringstream completeOption;
            completeOption << "|cFF00FF00Complete Quests (" << completableCount << " ready)|r";
            AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1, completeOption.str(), GOSSIP_SENDER_MAIN, ACTION_SHOW_COMPLETABLE);
        }

        // Count in-progress quests
        uint32 inProgressCount = 0;
        for (uint32 questId : dungeonQuests)
        {
            if (player->GetQuestStatus(questId) == QUEST_STATUS_INCOMPLETE)
                ++inProgressCount;
        }

        if (inProgressCount > 0)
        {
            std::ostringstream inProgressOption;
            inProgressOption << "|cFFFFFF00In-Progress (" << inProgressCount << " active)|r";
            AddGossipItemFor(player, GOSSIP_ICON_INTERACT_2, inProgressOption.str(), GOSSIP_SENDER_MAIN, ACTION_SHOW_IN_PROGRESS);
        }

        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Daily Quests", GOSSIP_SENDER_MAIN, ACTION_SHOW_DAILY_QUESTS);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Weekly Quests", GOSSIP_SENDER_MAIN, ACTION_SHOW_WEEKLY_QUESTS);
        AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "View My Statistics", GOSSIP_SENDER_MAIN, ACTION_SHOW_STATS);

        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        ClearGossipMenuFor(player);

        switch (action)
        {
            case ACTION_SHOW_DUNGEON_QUESTS:
                ShowDungeonQuests(player, creature);
                break;

            case ACTION_SHOW_DAILY_QUESTS:
                ShowDailyQuests(player, creature);
                break;

            case ACTION_SHOW_WEEKLY_QUESTS:
                ShowWeeklyQuests(player, creature);
                break;

            case ACTION_SHOW_COMPLETABLE:
                ShowCompletableQuests(player, creature);
                break;

            case ACTION_SHOW_IN_PROGRESS:
                ShowInProgressQuests(player, creature);
                break;

            case ACTION_SHOW_STATS:
                ShowStatistics(player, creature);
                break;

            case ACTION_BACK_TO_MAIN:
                OnGossipHello(player, creature);
                return true;

            default:
                CloseGossipMenuFor(player);
                break;
        }

        return true;
    }

    bool OnQuestAccept(Player* player, Creature* /*creature*/, Quest const* quest) override
    {
        if (quest->GetQuestId() >= QUEST_DAILY_MIN && quest->GetQuestId() <= QUEST_DUNGEON_MAX)
        {
            ChatHandler(player->GetSession()).SendNotification(
                "Quest accepted! Complete all objectives to receive rewards."
            );
        }
        return true;
    }

    bool OnQuestReward(Player* /*player*/, Creature* /*creature*/, Quest const* /*quest*/, uint32 /*opt*/) override
    {
        // Rewards handled by DungeonQuestPlayerScript in DungeonQuestSystem.cpp
        return false;
    }

private:
    void ShowDungeonQuests(Player* player, Creature* creature)
    {
        uint32 currentMapId = player->GetMapId();
        auto const& dungeonQuests = UniversalQuestMasterCache::GetQuestsForDungeon(currentMapId);

        bool hasQuests = false;
        for (uint32 questId : dungeonQuests)
        {
            Quest const* quest = sObjectMgr->GetQuestTemplate(questId);
            if (!quest)
                continue;

            QuestStatus status = player->GetQuestStatus(questId);
            if (status == QUEST_STATUS_NONE && player->CanTakeQuest(quest, false))
            {
                // Add quest to gossip menu using AC's built-in quest menu
                player->PlayerTalkClass->GetQuestMenu().AddMenuItem(questId, 2); // 2 = Quest giver icon
                hasQuests = true;
            }
        }

        if (!hasQuests)
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "No dungeon quests available for this dungeon.", GOSSIP_SENDER_MAIN, ACTION_BACK_TO_MAIN);
        }

        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "<< Back to Main Menu", GOSSIP_SENDER_MAIN, ACTION_BACK_TO_MAIN);
        player->SendPreparedGossip(creature);
    }

    void ShowDailyQuests(Player* player, Creature* creature)
    {
        bool hasQuests = false;
        for (uint32 questId : UniversalQuestMasterCache::GetDailyQuests())
        {
            Quest const* quest = sObjectMgr->GetQuestTemplate(questId);
            if (!quest)
                continue;

            QuestStatus status = player->GetQuestStatus(questId);
            if (status == QUEST_STATUS_NONE && player->CanTakeQuest(quest, false))
            {
                player->PlayerTalkClass->GetQuestMenu().AddMenuItem(questId, 2);
                hasQuests = true;
            }
        }

        if (!hasQuests)
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "No daily quests available.", GOSSIP_SENDER_MAIN, ACTION_BACK_TO_MAIN);
        }

        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "<< Back to Main Menu", GOSSIP_SENDER_MAIN, ACTION_BACK_TO_MAIN);
        player->SendPreparedGossip(creature);
    }

    void ShowWeeklyQuests(Player* player, Creature* creature)
    {
        bool hasQuests = false;
        for (uint32 questId : UniversalQuestMasterCache::GetWeeklyQuests())
        {
            Quest const* quest = sObjectMgr->GetQuestTemplate(questId);
            if (!quest)
                continue;

            QuestStatus status = player->GetQuestStatus(questId);
            if (status == QUEST_STATUS_NONE && player->CanTakeQuest(quest, false))
            {
                player->PlayerTalkClass->GetQuestMenu().AddMenuItem(questId, 2);
                hasQuests = true;
            }
        }

        if (!hasQuests)
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "No weekly quests available.", GOSSIP_SENDER_MAIN, ACTION_BACK_TO_MAIN);
        }

        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "<< Back to Main Menu", GOSSIP_SENDER_MAIN, ACTION_BACK_TO_MAIN);
        player->SendPreparedGossip(creature);
    }

    void ShowCompletableQuests(Player* player, Creature* creature)
    {
        uint32 currentMapId = player->GetMapId();
        bool hasQuests = false;

        // Check dungeon quests
        auto const& dungeonQuests = UniversalQuestMasterCache::GetQuestsForDungeon(currentMapId);
        for (uint32 questId : dungeonQuests)
        {
            if (player->GetQuestStatus(questId) == QUEST_STATUS_COMPLETE)
            {
                player->PlayerTalkClass->GetQuestMenu().AddMenuItem(questId, 4); // 4 = Quest completer icon
                hasQuests = true;
            }
        }

        // Check daily quests
        for (uint32 questId : UniversalQuestMasterCache::GetDailyQuests())
        {
            if (player->GetQuestStatus(questId) == QUEST_STATUS_COMPLETE)
            {
                player->PlayerTalkClass->GetQuestMenu().AddMenuItem(questId, 4);
                hasQuests = true;
            }
        }

        // Check weekly quests
        for (uint32 questId : UniversalQuestMasterCache::GetWeeklyQuests())
        {
            if (player->GetQuestStatus(questId) == QUEST_STATUS_COMPLETE)
            {
                player->PlayerTalkClass->GetQuestMenu().AddMenuItem(questId, 4);
                hasQuests = true;
            }
        }

        if (!hasQuests)
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "No quests ready to complete.", GOSSIP_SENDER_MAIN, ACTION_BACK_TO_MAIN);
        }

        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "<< Back to Main Menu", GOSSIP_SENDER_MAIN, ACTION_BACK_TO_MAIN);
        player->SendPreparedGossip(creature);
    }

    void ShowInProgressQuests(Player* player, Creature* creature)
    {
        uint32 currentMapId = player->GetMapId();
        auto const& dungeonQuests = UniversalQuestMasterCache::GetQuestsForDungeon(currentMapId);
        
        bool hasQuests = false;
        for (uint32 questId : dungeonQuests)
        {
            if (player->GetQuestStatus(questId) == QUEST_STATUS_INCOMPLETE)
            {
                Quest const* quest = sObjectMgr->GetQuestTemplate(questId);
                if (!quest)
                    continue;
                
                // Calculate progress percentage
                uint32 totalObjectives = 0;
                uint32 completedObjectives = 0;
                
                for (uint8 i = 0; i < QUEST_OBJECTIVES_COUNT; ++i)
                {
                    if (quest->RequiredNpcOrGo[i] != 0 || quest->RequiredItemCount[i] != 0)
                    {
                        totalObjectives++;
                        uint32 required = quest->RequiredNpcOrGoCount[i] > 0 ? 
                                         quest->RequiredNpcOrGoCount[i] : quest->RequiredItemCount[i];
                        uint32 current = player->GetQuestSlotCounter(player->GetQuestSlot(questId), i);
                        if (current >= required)
                            completedObjectives++;
                    }
                }
                
                uint32 progressPercent = totalObjectives > 0 ? 
                                        (completedObjectives * 100 / totalObjectives) : 0;
                
                // Format quest with progress
                std::ostringstream oss;
                oss << "|cFFFFFF00" << quest->GetTitle() << "|r [" << progressPercent << "%]";
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, oss.str(), GOSSIP_SENDER_MAIN, ACTION_BACK_TO_MAIN);
                hasQuests = true;
            }
        }
        
        if (!hasQuests)
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "No quests in progress.", GOSSIP_SENDER_MAIN, ACTION_BACK_TO_MAIN);
        }
        
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "<< Back to Main Menu", GOSSIP_SENDER_MAIN, ACTION_BACK_TO_MAIN);
        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
    }

    void ShowStatistics(Player* player, Creature* creature)
    {
        std::string stats = FormatQuestStatistics(player);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, stats, GOSSIP_SENDER_MAIN, ACTION_BACK_TO_MAIN);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "<< Back to Main Menu", GOSSIP_SENDER_MAIN, ACTION_BACK_TO_MAIN);
        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
    }
};

// =====================================================================
// WORLD SCRIPT FOR CACHE INITIALIZATION
// =====================================================================

class UniversalQuestMasterWorldScript : public WorldScript
{
public:
    UniversalQuestMasterWorldScript() : WorldScript("UniversalQuestMasterWorldScript") { }

    void OnStartup() override
    {
        LOG_INFO("server.loading", ">> Loading Universal Quest Master Cache...");
        UniversalQuestMasterCache::LoadCache();
    }
};

// =====================================================================
// GM COMMAND SCRIPT FOR CACHE RELOAD
// =====================================================================

class UniversalQuestMasterCommandScript : public CommandScript
{
public:
    UniversalQuestMasterCommandScript() : CommandScript("UniversalQuestMasterCommandScript") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable reloadSubCommands =
        {
            { "dc_dungeon_quests", HandleReloadDungeonQuestsCommand, SEC_GAMEMASTER, Console::Yes }
        };

        static ChatCommandTable reloadCommands =
        {
            { "reload", reloadSubCommands }
        };

        return reloadCommands;
    }

    static bool HandleReloadDungeonQuestsCommand(ChatHandler* handler, Optional<PlayerIdentifier> /*target*/)
    {
        handler->PSendSysMessage("Reloading Universal Quest Master cache...");
        
        UniversalQuestMasterCache::ReloadCache();
        
        handler->PSendSysMessage("Done! Loaded %u dungeons, %u display IDs.",
                                UniversalQuestMasterCache::GetTotalQuestMappings(),
                                UniversalQuestMasterCache::GetTotalDisplayMappings());
        
        LOG_INFO("scripts.dc", "GM {} reloaded Universal Quest Master cache",
                 handler->GetSession() ? handler->GetSession()->GetPlayer()->GetName() : "Console");
        
        return true;
    }
};

// =====================================================================
// SCRIPT REGISTRATION
// =====================================================================

void AddSC_npc_universal_quest_master()
{
    new npc_universal_quest_master();
    new UniversalQuestMasterWorldScript();
    new UniversalQuestMasterCommandScript();

    LOG_INFO("server.loading", ">> Loaded Universal Quest Master NPC (Entry {})", NPC_UNIVERSAL_QUEST_MASTER);
}

