/*
 * Giant Isles - War Drum / Hydra summon
 * ==========================================================================
 * A standing war drum (gameobject) the player can "play". When the clicker is
 * on either faction's hydra quest, beating the drum summons the hydra boss at
 * the drum's shore. The hydra itself is data-driven (SmartAI); this script only
 * owns the drum -> summon interaction.
 * ==========================================================================
 */

#include "ScriptMgr.h"
#include "GameObject.h"
#include "GameObjectAI.h"
#include "Creature.h"
#include "CreatureAI.h"
#include "Player.h"
#include "ObjectMgr.h"
#include "ScriptedGossip.h"
#include "Chat.h"
#include "WorldSession.h"
#include "Log.h"
#include "../QOL/dc_questgiver_status_override.h"

using namespace std::chrono_literals;

namespace
{
    enum HydraDrumData : uint32
    {
        NPC_GIANT_ISLES_HYDRA   = 400360,
        GO_GIANT_ISLES_WAR_DRUM = 700016,
        QUEST_HYDRA_ALLIANCE    = 400342,
        QUEST_HYDRA_HORDE       = 400343,
        SOUND_WAR_DRUM          = 6674,   // deep war-horn/drum, also used by the invasion warning
    };

    // Hydra spawn / anchor point (from the design request). Map 1405 (Giant Isles).
    Position const HydraSummonPos = { 6323.4595f, 1068.7466f, 12.090531f, 6.1160235f };

    constexpr float HYDRA_PRESENCE_RANGE = 150.0f;

    bool PlayerIsOnHydraQuest(Player* player)
    {
        return player->GetQuestStatus(QUEST_HYDRA_ALLIANCE) == QUEST_STATUS_INCOMPLETE
            || player->GetQuestStatus(QUEST_HYDRA_HORDE) == QUEST_STATUS_INCOMPLETE;
    }

    class go_giant_isles_war_drum : public GameObjectScript
    {
    public:
        go_giant_isles_war_drum() : GameObjectScript("go_giant_isles_war_drum") { }

        bool OnGossipHello(Player* player, GameObject* go) override
        {
            if (!player || !go)
                return true;

            ChatHandler handler(player->GetSession());

            if (!PlayerIsOnHydraQuest(player) && !player->IsGameMaster())
            {
                handler.SendSysMessage("The war drum stays silent in your hands. Take up the call to slay the hydra before you sound it.");
                CloseGossipMenuFor(player);
                return true;
            }

            // Only one hydra at a time may answer the drums.
            if (go->FindNearestCreature(NPC_GIANT_ISLES_HYDRA, HYDRA_PRESENCE_RANGE, true))
            {
                handler.SendSysMessage("The hydra already prowls the shore!");
                CloseGossipMenuFor(player);
                return true;
            }

            // Preflight so a missing template/model gives a clear message instead of a silent no-op.
            CreatureTemplate const* tpl = sObjectMgr->GetCreatureTemplate(NPC_GIANT_ISLES_HYDRA);
            if (!tpl)
            {
                handler.SendSysMessage("The hydra cannot be summoned (missing creature_template 400360).");
                LOG_ERROR("scripts.dc", "go_giant_isles_war_drum: missing creature_template {} (player={})",
                    static_cast<uint32>(NPC_GIANT_ISLES_HYDRA), player->GetName());
                CloseGossipMenuFor(player);
                return true;
            }

            go->PlayDirectSound(SOUND_WAR_DRUM);

            // Despawn-on-death only; the "not attacked for 5 minutes" cleanup is
            // driven by the hydra's SmartAI (out-of-combat force despawn).
            if (Creature* hydra = go->SummonCreature(NPC_GIANT_ISLES_HYDRA, HydraSummonPos,
                TEMPSUMMON_DEAD_DESPAWN))
            {
                hydra->SetHomePosition(HydraSummonPos);

                if (CreatureAI* ai = hydra->AI())
                {
                    ai->Talk(1);             // spawn announcement (creature_text group 1)
                    ai->AttackStart(player); // engage the drummer (faction would auto-aggro anyway)
                }

                LOG_INFO("scripts.dc", "Giant Isles: hydra {} summoned by {} via war drum",
                    static_cast<uint32>(NPC_GIANT_ISLES_HYDRA), player->GetName());
            }
            else
            {
                handler.SendSysMessage("The hydra failed to rise. See the server log.");
                LOG_ERROR("scripts.dc", "go_giant_isles_war_drum: SummonCreature null for {} (player={}, map={})",
                    static_cast<uint32>(NPC_GIANT_ISLES_HYDRA), player->GetName(), go->GetMapId());
            }

            CloseGossipMenuFor(player);
            return true;
        }
    };

    // Generic Giant Isles questgiver: only overrides the overhead dialog status
    // so available daily/weekly quests render the blue "!" icon, via the shared
    // QoL helper (data-driven by the dc_questgiver_status_overrides table).
    // Used by Scholar Zal'ira (400525), the hydra daily quest giver. Gossip and
    // quest accept/reward stay on the default DB-driven path.
    class npc_giant_isles_questgiver : public CreatureScript
    {
    public:
        npc_giant_isles_questgiver() : CreatureScript("npc_giant_isles_questgiver") { }

        uint32 GetDialogStatus(Player* player, Creature* creature) override
        {
            return DCQuestgiverStatusOverride::GetDialogStatus(player, creature);
        }
    };
}

void AddSC_giant_isles_hydra_drum()
{
    new go_giant_isles_war_drum();
    new npc_giant_isles_questgiver();
}
