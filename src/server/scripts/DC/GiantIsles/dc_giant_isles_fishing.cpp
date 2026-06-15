/*
 * Giant Isles - Primal Cook Exchange NPC
 * ============================================================================
 * Grak'zar (NPC 401119) stands near Angler Rolo on Nice's Nice Beach.
 * Players trade primal fish caught in the zone for unique buff food.
 *
 * Exchange table:
 *   5x Titan-Scale Lungfish  -> 1x Primal Fish Stew    (general: +AP/+SP)
 *   2x Primordial Thunderfin -> 1x Thunderfin Fillet   (physical: +AP/+Hit)
 *   3x Epoch Eel             -> 1x Epoch Eel Broth     (caster: +Crit/+Haste)
 *   2x Lungfish + 1 Thunderfin + 2x Eel -> 1x First Age Fish Feast (best-in-zone)
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Creature.h"
#include "GossipDef.h"
#include "DC/CrossSystem/RewardDistributor.h"
#include "Chat.h"
#include "ObjectMgr.h"
#include "Item.h"
#include "Log.h"

namespace DarkChaos::GiantIsles
{
    enum PrimalCookConst : uint32
    {
        // Fish currency
        ITEM_TITAN_LUNGFISH     = 900100,
        ITEM_THUNDERFIN         = 900101,
        ITEM_EPOCH_EEL          = 900102,

        // Buff food rewards
        ITEM_PRIMAL_FISH_STEW   = 900120,
        ITEM_THUNDERFIN_FILLET  = 900121,
        ITEM_EPOCH_EEL_BROTH    = 900122,
        ITEM_FIRST_AGE_FEAST    = 900123,

        // Gossip actions
        ACTION_TRADE_STEW       = 1,
        ACTION_TRADE_FILLET     = 2,
        ACTION_TRADE_BROTH      = 3,
        ACTION_TRADE_FEAST      = 4,

        // NPC greeting text (npc_text.ID)
        GOSSIP_TEXT_COOK        = 400119,
    };

    // Returns a colored gossip line; gray when the player lacks materials.
    static std::string RecipeLine(bool canCraft, std::string const& cost, std::string const& product)
    {
        if (canCraft)
            return "[" + cost + "] Cook me " + product;
        return "|cFF909090[" + cost + "] " + product + " -- need more fish|r";
    }

    // Attempts an exchange; removes costs only if all checks pass.
    // Returns false and notifies the player on failure.
    static bool TryExchange(
        Player* player,
        Creature* creature,
        std::initializer_list<std::pair<uint32, uint32>> costs, // {itemId, count}
        uint32 rewardId, uint32 rewardCount,
        char const* successMsg)
    {
        for (auto const& [id, count] : costs)
        {
            if (!player->HasItemCount(id, count))
            {
                creature->Whisper("Ya don't have enough of da ancient fish for dat recipe, mon.",
                    LANG_UNIVERSAL, player);
                return false;
            }
        }

        if (!sObjectMgr->GetItemTemplate(rewardId))
        {
            LOG_ERROR("scripts.dc", "PrimalCook: reward item {} not found in item_template", rewardId);
            return false;
        }

        for (auto const& [id, count] : costs)
            player->DestroyItemCount(id, count, true);

        // DistributeItem mails the reward on full bags — no silent data loss.
        DarkChaos::CrossSystem::GetRewardDistributor()->DistributeItem(
            player, rewardId, rewardCount, DarkChaos::CrossSystem::SystemId::None, "cook_exchange");
        creature->Whisper(successMsg, LANG_UNIVERSAL, player);
        return true;
    }

    class npc_giant_isles_primal_cook : public CreatureScript
    {
    public:
        npc_giant_isles_primal_cook() : CreatureScript("npc_giant_isles_primal_cook") {}

        bool OnGossipHello(Player* player, Creature* creature) override
        {
            ClearGossipMenuFor(player);

            bool canStew   = player->HasItemCount(ITEM_TITAN_LUNGFISH, 5);
            bool canFillet = player->HasItemCount(ITEM_THUNDERFIN, 2);
            bool canBroth  = player->HasItemCount(ITEM_EPOCH_EEL, 3);
            bool canFeast  = player->HasItemCount(ITEM_TITAN_LUNGFISH, 2)
                          && player->HasItemCount(ITEM_THUNDERFIN, 1)
                          && player->HasItemCount(ITEM_EPOCH_EEL, 2);

            AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1,
                RecipeLine(canStew,   "5x Titan-Scale Lungfish",           "Primal Fish Stew"),
                GOSSIP_SENDER_MAIN, ACTION_TRADE_STEW);

            AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1,
                RecipeLine(canFillet, "2x Primordial Thunderfin",          "Thunderfin Fillet"),
                GOSSIP_SENDER_MAIN, ACTION_TRADE_FILLET);

            AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1,
                RecipeLine(canBroth,  "3x Epoch Eel",                      "Epoch Eel Broth"),
                GOSSIP_SENDER_MAIN, ACTION_TRADE_BROTH);

            AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1,
                RecipeLine(canFeast,  "2 Lungfish + 1 Thunderfin + 2 Eel", "First Age Fish Feast"),
                GOSSIP_SENDER_MAIN, ACTION_TRADE_FEAST);

            SendGossipMenuFor(player, GOSSIP_TEXT_COOK, creature->GetGUID());
            return true;
        }

        bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
        {
            ClearGossipMenuFor(player);

            switch (action)
            {
                case ACTION_TRADE_STEW:
                    TryExchange(player, creature,
                        {{ITEM_TITAN_LUNGFISH, 5}},
                        ITEM_PRIMAL_FISH_STEW, 1,
                        "Grak'zar quickly stirs da pot... here, enjoy your Primal Fish Stew, mon!");
                    break;

                case ACTION_TRADE_FILLET:
                    TryExchange(player, creature,
                        {{ITEM_THUNDERFIN, 2}},
                        ITEM_THUNDERFIN_FILLET, 1,
                        "Even Grak'zar's blade tingles cutting dis fish! Your Thunderfin Fillet is ready.");
                    break;

                case ACTION_TRADE_BROTH:
                    TryExchange(player, creature,
                        {{ITEM_EPOCH_EEL, 3}},
                        ITEM_EPOCH_EEL_BROTH, 1,
                        "Da eel remembers ancient magics... let dat wisdom flow into ya. Epoch Eel Broth!");
                    break;

                case ACTION_TRADE_FEAST:
                    TryExchange(player, creature,
                        {{ITEM_TITAN_LUNGFISH, 2}, {ITEM_THUNDERFIN, 1}, {ITEM_EPOCH_EEL, 2}},
                        ITEM_FIRST_AGE_FEAST, 1,
                        "Only da worthy eat from da First Age Feast. Grak'zar is honored to prepare dis for ya!");
                    break;

                default:
                    break;
            }

            CloseGossipMenuFor(player);
            return true;
        }
    };

} // namespace DarkChaos::GiantIsles

void AddSC_dc_giant_isles_fishing()
{
    new DarkChaos::GiantIsles::npc_giant_isles_primal_cook();
}
