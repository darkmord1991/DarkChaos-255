/*
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * Quest-driven phasing for the downported maps (750, 751, 861): see QuestPhaseLayer.h.
 *
 * Rules are loaded once at startup and only read afterwards, so the map threads read them without
 * a lock. The layer is recomputed on login, map change, area change and on the quest events that
 * move a status (accept, abandon, reward), and rechecked every few seconds on maps that have rules:
 * a status changed by any other path (an objective finishing, a GM command, a playerbot adding a
 * quest with Player::AddQuest, which raises no accept hook) is picked up within that interval.
 */

#include "QuestPhaseLayer.h"
#include "DBCStores.h"
#include "DatabaseEnv.h"
#include "DC/CrossSystem/PhaseLayers.h"
#include "GameTime.h"
#include "Log.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "QuestDef.h"
#include "ScriptMgr.h"
#include "Timer.h"

#include <unordered_map>
#include <vector>

namespace
{
    struct QuestPhaseRule
    {
        uint32 phaseMask;
        uint32 questId;
        uint32 questStatusMask;
        uint32 quest2Id;           // 0 = no second condition
        uint32 quest2StatusMask;
    };

    // A repeatable or daily quest reports NONE again once it is turned in (GetQuestStatus), but the
    // player keeps it in the rewarded set; this extra bit says "turned in at least once", so a stage a
    // daily unlocks (the Molten Front's Into the Fire, The Forlorn Spire) stays unlocked.
    constexpr uint32 STATUS_EVER_REWARDED = 1u << MAX_QUEST_STATUS;
    constexpr uint32 VALID_STATUS_MASK = ((1u << MAX_QUEST_STATUS) - 1) | STATUS_EVER_REWARDED;

    std::unordered_map<uint32, std::vector<QuestPhaseRule>> sRulesByMap;
    std::unordered_map<uint32, uint32> sBitsByMap;

    // How often a player on a map with rules is rechecked without a hook
    constexpr uint64 RECHECK_INTERVAL_MS = 5000;

    bool HasRulesOnMap(uint32 mapId)
    {
        return sRulesByMap.contains(mapId);
    }

    uint32 QuestStatusBits(Player const* player, uint32 questId)
    {
        uint32 bits = 1u << player->GetQuestStatus(questId);
        if (player->IsQuestRewarded(questId))
            bits |= STATUS_EVER_REWARDED;

        return bits;
    }

    void LoadRules()
    {
        uint32 const oldMSTime = getMSTime();
        sRulesByMap.clear();
        sBitsByMap.clear();

        // A query naming a missing table aborts the worldserver (errno 1146), and this code can be
        // deployed before the SQL that creates the table: ask information_schema first.
        QueryResult exists = WorldDatabase.Query("SELECT 1 FROM information_schema.TABLES "
            "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'dc_quest_phase'");
        if (!exists)
        {
            LOG_WARN("server.loading", ">> Table `dc_quest_phase` does not exist, quest phasing disabled.");
            return;
        }

        // The second quest condition came with r53; the r52 layout has no `quest2` columns
        bool const hasQuest2 = WorldDatabase.Query("SELECT 1 FROM information_schema.COLUMNS "
            "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'dc_quest_phase' AND COLUMN_NAME = 'quest2'") != nullptr;

        QueryResult result = WorldDatabase.Query(hasQuest2
            ? "SELECT `map`, `phase_mask`, `quest`, `quest_status_mask`, `quest2`, `quest2_status_mask` "
              "FROM `dc_quest_phase`"
            : "SELECT `map`, `phase_mask`, `quest`, `quest_status_mask` FROM `dc_quest_phase`");
        if (!result)
        {
            LOG_INFO("server.loading", ">> Loaded 0 quest phase rules. Table `dc_quest_phase` is empty.");
            return;
        }

        uint32 count = 0;
        do
        {
            Field* fields = result->Fetch();
            uint32 const mapId = fields[0].Get<uint16>();
            uint32 phaseMask = fields[1].Get<uint32>();
            uint32 const questId = fields[2].Get<uint32>();
            uint32 const statusMask = fields[3].Get<uint32>();
            uint32 const quest2Id = hasQuest2 ? fields[4].Get<uint32>() : 0;
            uint32 const quest2StatusMask = hasQuest2 ? fields[5].Get<uint32>() : 0;

            if (!sMapStore.LookupEntry(mapId))
            {
                LOG_ERROR("sql.sql", "Table `dc_quest_phase`: map {} does not exist, rule for quest {} skipped.",
                    mapId, questId);
                continue;
            }

            if (!sObjectMgr->GetQuestTemplate(questId))
            {
                LOG_ERROR("sql.sql", "Table `dc_quest_phase`: quest {} does not exist, rule on map {} skipped.",
                    questId, mapId);
                continue;
            }

            if (phaseMask & PHASEMASK_NORMAL)
            {
                LOG_ERROR("sql.sql", "Table `dc_quest_phase`: rule for quest {} on map {} includes phase 1, which "
                    "every player has; bit removed.", questId, mapId);
                phaseMask &= ~uint32(PHASEMASK_NORMAL);
            }

            if (uint32 const reserved = phaseMask & DarkChaos::PhaseLayers::ReservedBitsOnMap(mapId))
            {
                LOG_ERROR("sql.sql", "Table `dc_quest_phase`: rule for quest {} on map {} uses bits {} that another "
                    "system reserves there, rule skipped.", questId, mapId, reserved);
                continue;
            }

            if (!phaseMask || !(statusMask & VALID_STATUS_MASK))
            {
                LOG_ERROR("sql.sql", "Table `dc_quest_phase`: rule for quest {} on map {} has no phase bit or no "
                    "quest status, rule skipped.", questId, mapId);
                continue;
            }

            if (quest2Id && (!sObjectMgr->GetQuestTemplate(quest2Id) || !(quest2StatusMask & VALID_STATUS_MASK)))
            {
                LOG_ERROR("sql.sql", "Table `dc_quest_phase`: rule for quest {} on map {} has a second quest {} that "
                    "does not exist or has no quest status, rule skipped.", questId, mapId, quest2Id);
                continue;
            }

            sRulesByMap[mapId].push_back({ phaseMask, questId, statusMask & VALID_STATUS_MASK, quest2Id,
                quest2StatusMask & VALID_STATUS_MASK });
            sBitsByMap[mapId] |= phaseMask;
            ++count;
        } while (result->NextRow());

        LOG_INFO("server.loading", ">> Loaded {} quest phase rules on {} maps in {} ms", count, sRulesByMap.size(),
            GetMSTimeDiffToNow(oldMSTime));
    }
}

namespace DarkChaos::QuestPhase
{
    uint32 BitsOnMap(uint32 mapId)
    {
        auto const itr = sBitsByMap.find(mapId);
        return itr != sBitsByMap.end() ? itr->second : 0;
    }

    void Refresh(Player* player)
    {
        if (!player || !player->IsInWorld())
            return;

        uint32 mask = 0;
        auto const itr = sRulesByMap.find(player->GetMapId());
        if (itr != sRulesByMap.end())
            for (QuestPhaseRule const& rule : itr->second)
                if ((QuestStatusBits(player, rule.questId) & rule.questStatusMask)
                    && (!rule.quest2Id || (QuestStatusBits(player, rule.quest2Id) & rule.quest2StatusMask)))
                    mask |= rule.phaseMask;

        if (mask)
            player->SetPhaseLayer(PhaseLayers::QuestPhase, mask, false);
        else
            player->ClearPhaseLayer(PhaseLayers::QuestPhase);
    }
}

class dc_quest_phase_world : public WorldScript
{
public:
    dc_quest_phase_world() : WorldScript("dc_quest_phase_world") { }

    void OnStartup() override
    {
        LoadRules();
    }
};

class dc_quest_phase_player : public PlayerScript
{
public:
    dc_quest_phase_player() : PlayerScript("dc_quest_phase_player",
    {
        PLAYERHOOK_ON_LOGIN,
        PLAYERHOOK_ON_MAP_CHANGED,
        PLAYERHOOK_ON_UPDATE_AREA,
        PLAYERHOOK_ON_PLAYER_QUEST_ACCEPT,
        PLAYERHOOK_ON_QUEST_ABANDON,
        PLAYERHOOK_ON_PLAYER_COMPLETE_QUEST,
        PLAYERHOOK_ON_UPDATE
    }) { }

    // The recheck. Stateless, so no per-player timer is shared between map threads: the guid gives
    // each player a fixed slot in the cycle, which also spreads the work over it. A player is rechecked
    // in the update whose time step crosses that slot.
    void OnPlayerUpdate(Player* player, uint32 diff) override
    {
        if (!HasRulesOnMap(player->GetMapId()))
            return;

        uint64 const now = uint64(GameTime::GetGameTimeMS().count());
        uint64 const slot = (now + uint64(player->GetGUID().GetCounter()) * 977) % RECHECK_INTERVAL_MS;
        if (slot < diff)
            DarkChaos::QuestPhase::Refresh(player);
    }

    void OnPlayerLogin(Player* player) override
    {
        DarkChaos::QuestPhase::Refresh(player);
    }

    void OnPlayerMapChanged(Player* player) override
    {
        DarkChaos::QuestPhase::Refresh(player);
    }

    void OnPlayerUpdateArea(Player* player, uint32 /*oldArea*/, uint32 /*newArea*/) override
    {
        DarkChaos::QuestPhase::Refresh(player);
    }

    void OnPlayerQuestAccept(Player* player, Quest const* /*quest*/) override
    {
        DarkChaos::QuestPhase::Refresh(player);
    }

    void OnPlayerQuestAbandon(Player* player, uint32 /*questId*/) override
    {
        DarkChaos::QuestPhase::Refresh(player);
    }

    // Called at the end of Player::RewardQuest, after the quest is marked rewarded
    void OnPlayerCompleteQuest(Player* player, Quest const* /*quest*/) override
    {
        DarkChaos::QuestPhase::Refresh(player);
    }
};

void AddSC_dc_quest_phase_layer()
{
    new dc_quest_phase_world();
    new dc_quest_phase_player();
}
