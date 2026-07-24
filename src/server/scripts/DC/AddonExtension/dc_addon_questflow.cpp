/*
 * Dark Chaos - Auto-Quest Popup Handler (retail-style quest flow)
 * ===============================================================
 *
 * Ascension-inspired modern quest UX over the DC addon protocol:
 *
 *  - AUTO OFFER: entering a zone/area listed in `dc_quest_auto_offer` pushes a
 *    "quest available" popup to the client (module QPOP / SMSG_OFFER). Accepting
 *    adds the quest remotely - no questgiver visit needed.
 *
 *  - AUTO COMPLETE: when a quest's objectives complete and the quest is remote-
 *    completable (QUEST_FLAGS_AUTOCOMPLETE or listed in `dc_quest_auto_complete`),
 *    a "ready to turn in" popup is pushed (SMSG_COMPLETE_READY). Clicking it
 *    turns the quest in remotely, including reward-choice selection.
 *
 * Security: CMSG_COMPLETE_QUEST only rewards quests that pass the same
 * eligibility gate used for the push (flag or table) - a modified client cannot
 * remote-complete arbitrary quests.
 *
 * Copyright (C) 2026 Dark Chaos Development Team
 */

#include "dc_addon_namespace.h"
#include "ScriptMgr.h"
#include "Config.h"
#include "Player.h"
#include "WorldSession.h"
#include "DatabaseEnv.h"
#include "ObjectMgr.h"
#include "QuestDef.h"
#include "Log.h"

#include <unordered_map>
#include <unordered_set>
#include <vector>
#include <mutex>

namespace
{
    struct AutoOfferEntry
    {
        uint32 questId = 0;
        uint32 areaId = 0;      // 0 = whole zone
        uint8 minLevel = 0;
        uint8 maxLevel = 0;     // 0 = no cap
    };

    // zoneId -> offers in that zone. Loaded once at startup on the world thread;
    // read-only afterwards.
    std::unordered_map<uint32, std::vector<AutoOfferEntry>> s_autoOffersByZone;
    std::unordered_set<uint32> s_autoCompleteQuests;
    bool s_tablesLoaded = false;

    // Per-session dedupe so a popup is offered at most once per login session.
    std::unordered_map<uint64, std::unordered_set<uint32>> s_offeredThisSession;
    std::mutex s_offeredMutex;

    bool IsEnabled()
    {
        return sConfigMgr->GetOption<bool>("DC.AddonProtocol.QuestPopups.Enable", true);
    }

    void LoadQuestFlowTables()
    {
        s_autoOffersByZone.clear();
        s_autoCompleteQuests.clear();

        uint32 offers = 0;
        if (QueryResult result = WorldDatabase.Query(
            "SELECT quest_id, zone_id, area_id, min_level, max_level "
            "FROM dc_quest_auto_offer WHERE enabled = 1"))
        {
            do
            {
                Field* fields = result->Fetch();
                AutoOfferEntry entry;
                entry.questId = fields[0].Get<uint32>();
                uint32 zoneId = fields[1].Get<uint32>();
                entry.areaId = fields[2].Get<uint32>();
                entry.minLevel = fields[3].Get<uint8>();
                entry.maxLevel = fields[4].Get<uint8>();

                if (!sObjectMgr->GetQuestTemplate(entry.questId))
                {
                    LOG_ERROR("module.dc", "dc_quest_auto_offer: quest {} does not exist, skipped", entry.questId);
                    continue;
                }

                s_autoOffersByZone[zoneId].push_back(entry);
                ++offers;
            } while (result->NextRow());
        }

        uint32 completes = 0;
        if (QueryResult result = WorldDatabase.Query(
            "SELECT quest_id FROM dc_quest_auto_complete WHERE enabled = 1"))
        {
            do
            {
                uint32 questId = result->Fetch()[0].Get<uint32>();
                if (!sObjectMgr->GetQuestTemplate(questId))
                {
                    LOG_ERROR("module.dc", "dc_quest_auto_complete: quest {} does not exist, skipped", questId);
                    continue;
                }
                s_autoCompleteQuests.insert(questId);
                ++completes;
            } while (result->NextRow());
        }

        s_tablesLoaded = true;
        LOG_INFO("module.dc", "QuestPopups: loaded {} auto-offer entries, {} auto-complete quests", offers, completes);
    }

    bool IsRemoteCompletable(Quest const* quest)
    {
        if (!quest)
            return false;
        if (quest->HasFlag(QUEST_FLAGS_AUTOCOMPLETE))
            return true;
        return s_autoCompleteQuests.find(quest->GetQuestId()) != s_autoCompleteQuests.end();
    }

    bool MarkOfferedOnce(Player* player, uint32 questId)
    {
        std::lock_guard<std::mutex> lock(s_offeredMutex);
        return s_offeredThisSession[player->GetGUID().GetRawValue()].insert(questId).second;
    }

    void ClearOfferedSession(Player* player)
    {
        std::lock_guard<std::mutex> lock(s_offeredMutex);
        s_offeredThisSession.erase(player->GetGUID().GetRawValue());
    }

    void SendQuestOffer(Player* player, Quest const* quest)
    {
        DCAddon::JsonMessage msg(DCAddon::Module::QUEST_POPUPS,
            DCAddon::Opcode::QuestPopups::SMSG_OFFER);
        msg.Set("q", quest->GetQuestId());
        msg.Set("t", quest->GetTitle());
        msg.Set("l", static_cast<uint32>(quest->GetQuestLevel()));
        msg.Send(player);
    }

    void SendQuestCompleteReady(Player* player, Quest const* quest)
    {
        DCAddon::JsonMessage msg(DCAddon::Module::QUEST_POPUPS,
            DCAddon::Opcode::QuestPopups::SMSG_COMPLETE_READY);
        msg.Set("q", quest->GetQuestId());
        msg.Set("t", quest->GetTitle());

        DCAddon::JsonValue choices;
        choices.SetArray();
        for (uint32 i = 0; i < quest->GetRewChoiceItemsCount(); ++i)
            if (quest->RewardChoiceItemId[i])
                choices.Push(DCAddon::JsonValue(quest->RewardChoiceItemId[i]));
        msg.Set("ch", choices);

        msg.Send(player);
    }

    // resend: bypass the once-per-session dedupe (still recording it) - used when
    // the CLIENT asks for offers. The login/zone pushes can race the addon's
    // handshake (the popup module isn't listening yet), so the addon re-requests
    // once it is ready and eligible offers are sent again.
    void EvaluateZoneOffers(Player* player, uint32 zoneId, uint32 areaId, bool resend = false)
    {
        if (!IsEnabled() || !player || !player->IsInWorld())
            return;

        auto it = s_autoOffersByZone.find(zoneId);
        if (it == s_autoOffersByZone.end())
            return;

        for (AutoOfferEntry const& entry : it->second)
        {
            if (entry.areaId && entry.areaId != areaId)
                continue;
            if (entry.minLevel && player->GetLevel() < entry.minLevel)
                continue;
            if (entry.maxLevel && player->GetLevel() > entry.maxLevel)
                continue;

            Quest const* quest = sObjectMgr->GetQuestTemplate(entry.questId);
            if (!quest)
                continue;
            if (player->GetQuestStatus(entry.questId) != QUEST_STATUS_NONE)
                continue; // already in log / done
            if (!player->CanTakeQuest(quest, false) || !player->CanAddQuest(quest, false))
                continue;
            if (!MarkOfferedOnce(player, entry.questId) && !resend)
                continue; // already offered this session

            SendQuestOffer(player, quest);
        }
    }
}

namespace DCAddon
{
    static void HandleAcceptQuest(Player* player, const ParsedMessage& msg)
    {
        if (!player || !IsEnabled() || !IsJsonMessage(msg))
            return;

        JsonValue req = GetJsonData(msg);
        if (!req.IsObject() || !req.HasKey("q") || !req["q"].IsNumber())
            return;

        uint32 questId = req["q"].AsUInt32();
        Quest const* quest = sObjectMgr->GetQuestTemplate(questId);
        if (!quest)
            return;

        // Only quests this system actually offers may be remote-accepted.
        bool offerable = false;
        for (auto const& [zoneId, entries] : s_autoOffersByZone)
        {
            for (AutoOfferEntry const& entry : entries)
                if (entry.questId == questId) { offerable = true; break; }
            if (offerable)
                break;
        }
        if (!offerable)
            return;

        if (player->GetQuestStatus(questId) != QUEST_STATUS_NONE)
            return;
        if (!player->CanTakeQuest(quest, true) || !player->CanAddQuest(quest, true))
            return;

        player->AddQuestAndCheckCompletion(quest, nullptr);
    }

    static void HandleCompleteQuest(Player* player, const ParsedMessage& msg)
    {
        if (!player || !IsEnabled() || !IsJsonMessage(msg))
            return;

        JsonValue req = GetJsonData(msg);
        if (!req.IsObject() || !req.HasKey("q") || !req["q"].IsNumber())
            return;

        uint32 questId = req["q"].AsUInt32();
        uint32 choice = 0;
        if (req.HasKey("c") && req["c"].IsNumber())
            choice = req["c"].AsUInt32();

        Quest const* quest = sObjectMgr->GetQuestTemplate(questId);
        if (!quest || !IsRemoteCompletable(quest))
            return; // never remote-complete quests outside the eligibility gate

        if (player->GetQuestStatus(questId) != QUEST_STATUS_COMPLETE)
            return;

        uint32 choiceCount = quest->GetRewChoiceItemsCount();
        if (choiceCount > 0)
        {
            if (choice >= choiceCount || !quest->RewardChoiceItemId[choice])
                return;
        }
        else
            choice = 0;

        if (!player->CanRewardQuest(quest, choice, true))
            return;

        player->RewardQuest(quest, choice, player, true);
    }

    // Client-driven offer refresh. The addon sends this once its QPOP module is
    // registered and listening (PLAYER_ENTERING_WORLD), closing the login race
    // where the OnPlayerLogin push arrives before the addon loaded - the reason
    // "welcome" quests never appeared on a fresh character's first world join.
    static void HandleRequestOffers(Player* player, const ParsedMessage& /*msg*/)
    {
        if (!player || !IsEnabled() || !s_tablesLoaded)
            return;

        EvaluateZoneOffers(player, player->GetZoneId(), player->GetAreaId(), /*resend*/ true);
    }

    void RegisterQuestFlowHandlers()
    {
        // QPOP is intentionally not part of the central module table in
        // dc_addon_protocol.cpp, so it enables itself with the router here
        // (same self-contained pattern as DC-Graveyard/DC-Welcome).
        bool const enabled = IsEnabled();
        MessageRouter::Instance().SetModuleEnabled(Module::QUEST_POPUPS, enabled);
        if (!enabled)
            return;

        DC_REGISTER_HANDLER(Module::QUEST_POPUPS, Opcode::QuestPopups::CMSG_ACCEPT_QUEST, HandleAcceptQuest);
        DC_REGISTER_HANDLER(Module::QUEST_POPUPS, Opcode::QuestPopups::CMSG_COMPLETE_QUEST, HandleCompleteQuest);
        DC_REGISTER_HANDLER(Module::QUEST_POPUPS, Opcode::QuestPopups::CMSG_REQUEST_OFFERS, HandleRequestOffers);
    }
}

class DCQuestFlowWorldScript : public WorldScript
{
public:
    DCQuestFlowWorldScript() : WorldScript("DCQuestFlowWorldScript") { }

    void OnStartup() override
    {
        if (IsEnabled())
            LoadQuestFlowTables();
    }
};

class DCQuestFlowPlayerScript : public PlayerScript
{
public:
    DCQuestFlowPlayerScript() : PlayerScript("DCQuestFlowPlayerScript") { }

    void OnPlayerUpdateZone(Player* player, uint32 newZone, uint32 newArea) override
    {
        if (s_tablesLoaded)
            EvaluateZoneOffers(player, newZone, newArea);
    }

    void OnPlayerLogin(Player* player) override
    {
        // Evaluate the login zone too - UpdateZone may not fire until the player moves.
        if (s_tablesLoaded && player)
            EvaluateZoneOffers(player, player->GetZoneId(), player->GetAreaId());
    }

    void OnPlayerLogout(Player* player) override
    {
        ClearOfferedSession(player);
    }

    void OnPlayerCompleteQuest(Player* player, Quest const* quest) override
    {
        if (!IsEnabled() || !player || !quest)
            return;
        if (!IsRemoteCompletable(quest))
            return;

        SendQuestCompleteReady(player, quest);
    }
};

namespace DCAddon
{
    void AddQuestFlowScripts()
    {
        RegisterQuestFlowHandlers();
        new DCQuestFlowWorldScript();
        new DCQuestFlowPlayerScript();
    }
}
