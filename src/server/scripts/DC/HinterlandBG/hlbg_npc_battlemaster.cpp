/*
 * Hinterlands BG Battlemaster NPC
 *
 * This NPC is a thin UI wrapper around the HLBG queue system implemented by
 * OutdoorPvPHL (not the core BattlegroundMgr queues).
 */

#include "hlbg.h"
#include "CreatureScript.h"
#include "Player.h"
#include "ScriptedCreature.h"
#include "ScriptedGossip.h"
#include "OutdoorPvP/OutdoorPvPMgr.h"
#include "Chat.h"
#include "ObjectMgr.h"

namespace
{
    constexpr uint32 HLBG_QUEST_DAILY = 920100;
    constexpr uint32 HLBG_QUEST_WEEKLY = 920101;

    enum HLBGGossipActions : uint32
    {
        ACTION_QUEUE_JOIN  = GOSSIP_ACTION_INFO_DEF + 1,
        ACTION_QUEUE_LEAVE = GOSSIP_ACTION_INFO_DEF + 2,
        ACTION_INFO        = GOSSIP_ACTION_INFO_DEF + 3,
        ACTION_QUEST_PROGRESS = GOSSIP_ACTION_INFO_DEF + 4,
    };

    OutdoorPvPHL* GetHL()
    {
        OutdoorPvP* opvp = sOutdoorPvPMgr->GetOutdoorPvPToZoneId(OutdoorPvPHLBuffZones[0]);
        return opvp ? dynamic_cast<OutdoorPvPHL*>(opvp) : nullptr;
    }
}

class npc_hinterlands_battlemaster : public CreatureScript
{
public:
    npc_hinterlands_battlemaster() : CreatureScript("npc_hinterlands_battlemaster") { }

    static std::string MakeLargeGossipText(std::string const& icon, std::string const& text)
    {
        return "|T" + icon + ":40:40:-18|t " + text;
    }

    static void AddQuestOption(Player* player, uint32 questId, std::string const& label)
    {
        Quest const* quest = sObjectMgr->GetQuestTemplate(questId);
        if (!quest)
            return;

        QuestStatus status = player->GetQuestStatus(questId);
        if (status == QUEST_STATUS_COMPLETE)
        {
            AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1,
                MakeLargeGossipText("Interface\\Icons\\Achievement_Quests_Completed_08", label + " |cFF00FF00(Complete)|r"),
                GOSSIP_SENDER_QUEST_REWARD, questId);
            return;
        }

        if (status == QUEST_STATUS_INCOMPLETE)
        {
            AddGossipItemFor(player, GOSSIP_ICON_INTERACT_2,
                MakeLargeGossipText("Interface\\Icons\\INV_Misc_Note_01", label + " |cFFFFFF00(In Progress)|r"),
                GOSSIP_SENDER_MAIN, ACTION_QUEST_PROGRESS);
            return;
        }

        if (status == QUEST_STATUS_NONE && player->CanTakeQuest(quest, false))
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT,
                MakeLargeGossipText("Interface\\Icons\\INV_Misc_Note_01", label),
                GOSSIP_SENDER_QUEST_MANUAL, questId);
        }
    }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (!player || !creature)
            return false;

        OutdoorPvPHL* hl = GetHL();
        if (!hl)
        {
            ChatHandler(player->GetSession()).SendNotification("HLBG system is not available right now.");
            return true;
        }

        ClearGossipMenuFor(player);

        if (hl->IsPlayerQueued(player))
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE,
                MakeLargeGossipText("Interface\\Icons\\Ability_Whirlwind", "Leave Hinterlands BG Queue"),
                GOSSIP_SENDER_MAIN, ACTION_QUEUE_LEAVE);
        else
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE,
                MakeLargeGossipText("Interface\\Icons\\Ability_Whirlwind", "Join Hinterlands BG Queue"),
                GOSSIP_SENDER_MAIN, ACTION_QUEUE_JOIN);

        AddQuestOption(player, HLBG_QUEST_DAILY, "Hinterland Daily: Claim Victory");
        AddQuestOption(player, HLBG_QUEST_WEEKLY, "Hinterland Weekly: Frontline Duty");

        AddGossipItemFor(player, GOSSIP_ICON_CHAT,
            MakeLargeGossipText("Interface\\Icons\\INV_Misc_QuestionMark", "What is Hinterlands BG?"),
            GOSSIP_SENDER_MAIN, ACTION_INFO);

        SendGossipMenuFor(player, player->GetGossipTextId(creature), creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 sender, uint32 action) override
    {
        if (!player || !creature)
            return false;

        ClearGossipMenuFor(player);

        if (sender == GOSSIP_SENDER_QUEST_MANUAL)
        {
            Quest const* quest = sObjectMgr->GetQuestTemplate(action);
            if (quest)
                player->PlayerTalkClass->SendQuestGiverQuestDetails(quest, creature->GetGUID(), true);
            return true;
        }

        if (sender == GOSSIP_SENDER_QUEST_REWARD)
        {
            Quest const* quest = sObjectMgr->GetQuestTemplate(action);
            if (quest && player->GetQuestStatus(action) == QUEST_STATUS_COMPLETE)
                player->PlayerTalkClass->SendQuestGiverOfferReward(quest, creature->GetGUID(), true);
            return true;
        }

        OutdoorPvPHL* hl = GetHL();
        if (!hl)
        {
            ChatHandler(player->GetSession()).SendNotification("HLBG system is not available right now.");
            CloseGossipMenuFor(player);
            return true;
        }

        switch (action)
        {
            case ACTION_QUEUE_JOIN: // Join
                hl->QueueCommandFromAddon(player, "queue", "join");
                CloseGossipMenuFor(player);
                return true;
            case ACTION_QUEUE_LEAVE: // Leave
                hl->QueueCommandFromAddon(player, "queue", "leave");
                CloseGossipMenuFor(player);
                return true;
            case ACTION_INFO: // Info
                ChatHandler(player->GetSession()).SendNotification("Hinterlands BG is a zone-wide PvP event in the Hinterlands. Use this NPC or .hlbg queue to join/leave.");
                return OnGossipHello(player, creature);
            case ACTION_QUEST_PROGRESS:
                ChatHandler(player->GetSession()).SendNotification("You already have this quest in progress. Complete it and return to turn it in.");
                return OnGossipHello(player, creature);
            default:
                return OnGossipHello(player, creature);
        }
    }
};

void AddSC_npc_hinterlands_battlemaster()
{
    new npc_hinterlands_battlemaster();
}
