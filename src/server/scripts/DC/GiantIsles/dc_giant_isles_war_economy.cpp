/*
 * Giant Isles - Invasion war economy: the War Quartermaster
 * ==========================================================================
 * A gossip-driven token vendor for the Zandalari invasion (Phase 3). Players
 * earn Zandalari War-Tokens (item 400456) by defending Seeping Shores; this
 * NPC exchanges them for goods entirely through gossip, so it needs no custom
 * ItemExtendedCost / currency DBC entries.
 *
 * The currency item, the quartermaster creature (400365) and its spawn live in
 * Custom/.../GiantIsles/giant_isles_war_economy.sql. The shared item/NPC ids
 * come from dc_giant_isles_invasion_internal.h.
 * ==========================================================================
 */

#include "ScriptMgr.h"
#include "ScriptedGossip.h"
#include "Player.h"
#include "Creature.h"
#include "Item.h"
#include "Chat.h"
#include "Log.h"

#include "dc_giant_isles_invasion_internal.h"

using namespace DCGiantIsles;

namespace
{
    struct QuartermasterOffer
    {
        uint32 action;
        uint32 cost;     // War-Tokens spent
        uint32 itemId;   // reward item granted
        uint32 count;    // how many
        char const* label;
    };

    // Reward items are all stock 3.3.5a goods (verified to exist), so nothing
    // here depends on extra item_template inserts.
    std::array<QuartermasterOffer, 4> const Offers =
    {{
        { GOSSIP_ACTION_INFO_DEF + 1,  5, 33447, 5, "Field Medicine: 5x Runic Healing Potion (5 Tokens)" },
        { GOSSIP_ACTION_INFO_DEF + 2, 10, 46376, 2, "Battle Draughts: 2x Flask of the Frost Wyrm (10 Tokens)" },
        { GOSSIP_ACTION_INFO_DEF + 3, 25, 41599, 1, "Campaign Pack: Frostweave Bag (25 Tokens)" },
        { GOSSIP_ACTION_INFO_DEF + 4, 60, 49294, 1, "War Spoils: Ashen Sack of Gems (60 Tokens)" },
    }};

    constexpr uint32 GOSSIP_ACTION_INFO = GOSSIP_ACTION_INFO_DEF + 100;
    constexpr uint32 QUARTERMASTER_TEXT = 400365;

    class npc_giant_isles_war_quartermaster : public CreatureScript
    {
    public:
        npc_giant_isles_war_quartermaster() : CreatureScript("npc_giant_isles_war_quartermaster") { }

        bool OnGossipHello(Player* player, Creature* creature) override
        {
            if (!player || !creature)
                return false;

            SendQuartermasterMenu(player, creature);
            return true;
        }

        bool OnGossipSelect(Player* player, Creature* creature, uint32 sender, uint32 action) override
        {
            (void)sender;

            if (!player || !creature)
                return false;

            ClearGossipMenuFor(player);

            if (action == GOSSIP_ACTION_INFO)
            {
                player->GetSession()->SendAreaTriggerMessage(
                    "War-Tokens are earned by defending Seeping Shores against the Zandalari invasion. "
                    "The harder the fight, the greater the reward.");
                SendQuartermasterMenu(player, creature);
                return true;
            }

            QuartermasterOffer const* offer = nullptr;
            for (QuartermasterOffer const& o : Offers)
            {
                if (o.action == action)
                {
                    offer = &o;
                    break;
                }
            }

            if (!offer)
            {
                CloseGossipMenuFor(player);
                return true;
            }

            uint32 balance = player->GetItemCount(WAR_TOKEN_ITEM);
            if (balance < offer->cost)
            {
                ChatHandler(player->GetSession()).PSendSysMessage(
                    "|cffff2020[Quartermaster]|r You need %u War-Tokens for that, and carry only %u.",
                    offer->cost, balance);
                SendQuartermasterMenu(player, creature);
                return true;
            }

            // Make sure the reward will fit before spending anything.
            ItemPosCountVec dest;
            InventoryResult res = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, offer->itemId, offer->count);
            if (res != EQUIP_ERR_OK)
            {
                player->SendEquipError(res, nullptr, nullptr, offer->itemId);
                SendQuartermasterMenu(player, creature);
                return true;
            }

            player->DestroyItemCount(WAR_TOKEN_ITEM, offer->cost, true);

            if (Item* item = player->StoreNewItem(dest, offer->itemId, true))
                player->SendNewItem(item, offer->count, true, false);

            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cff00ff00[Quartermaster]|r Trade complete. %u War-Tokens spent (%u remaining).",
                offer->cost, player->GetItemCount(WAR_TOKEN_ITEM));

            LOG_DEBUG("scripts.dc", "Giant Isles war economy: {} bought item {} x{} for {} tokens",
                player->GetName(), offer->itemId, offer->count, offer->cost);

            SendQuartermasterMenu(player, creature);
            return true;
        }

    private:
        static void SendQuartermasterMenu(Player* player, Creature* creature)
        {
            uint32 balance = player->GetItemCount(WAR_TOKEN_ITEM);

            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cff00ccff[Quartermaster]|r You carry %u Zandalari War-Tokens.", balance);

            for (QuartermasterOffer const& o : Offers)
                AddGossipItemFor(player, GOSSIP_ICON_VENDOR, o.label, GOSSIP_SENDER_MAIN, o.action);

            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "What are War-Tokens?", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO);

            SendGossipMenuFor(player, QUARTERMASTER_TEXT, creature->GetGUID());
        }
    };
}

void AddSC_giant_isles_war_economy()
{
    new npc_giant_isles_war_quartermaster();

    LOG_INFO("scripts.dc", "Giant Isles war economy: War Quartermaster loaded");
}
