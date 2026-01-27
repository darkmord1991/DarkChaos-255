#include "ScriptMgr.h"
#include "Creature.h"
#include "Player.h"
#include "Chat.h"
#include "ScriptedGossip.h"
#include "WorldPacket.h"
#include "Opcodes.h"
#include "dc_guildhouse.h"

#include <string>

namespace
{
    struct DalaranGuardPOI
    {
        const char* name;
        uint32 map;
        float x;
        float y;
        float z;
        float o;
        uint32 poiIcon;
        uint32 menuIcon;
    };

    static const DalaranGuardPOI dalaran_guard_pois[] =
    {
        {"Bank", 1409, 1202.201f, 1135.176f, 530.336f, 3.296f, ICON_POI_SMALL_HOUSE, GOSSIP_ICON_TAXI}
    };

    void SendPoiMarker(Player* player, float x, float y, uint32 icon, uint32 flags, uint32 importance, std::string const& name)
    {
        if (!player || !player->GetSession())
            return;

        WorldPacket data(SMSG_GOSSIP_POI, 4 + 4 + 4 + 4 + 4 + 20);
        data << uint32(flags);
        data << float(x);
        data << float(y);
        data << uint32(icon);
        data << uint32(importance);
        data << name;

        player->GetSession()->SendPacket(&data);
    }
}

class DalaranGuardNPC : public CreatureScript
{
public:
    DalaranGuardNPC() : CreatureScript("DalaranGuardNPC") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        ClearGossipMenuFor(player);

        for (size_t i = 0; i < std::size(dalaran_guard_pois); ++i)
        {
            uint32 idx = static_cast<uint32>(i);
            DalaranGuardPOI const& poi = dalaran_guard_pois[i];
            std::string label = "Teleport: " + std::string(poi.name);
            AddGossipItemFor(player, poi.menuIcon, label, GOSSIP_SENDER_MAIN, idx);
        }

        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        if (action >= std::size(dalaran_guard_pois))
        {
            ChatHandler(player->GetSession()).SendSysMessage("Invalid destination selected.");
            return true;
        }

        if (!player || !player->GetGuildId())
        {
            ChatHandler(player->GetSession()).SendSysMessage("You are not in a guild.");
            return true;
        }

        GuildHouseData* data = GuildHouseManager::GetGuildHouseData(player->GetGuildId());
        if (!data)
        {
            ChatHandler(player->GetSession()).SendSysMessage("Your guild does not own a Guild House.");
            return true;
        }

        DalaranGuardPOI const& poi = dalaran_guard_pois[action];

        uint32 phase = data->phase ? data->phase : GetGuildPhase(player);
        if (phase)
            player->SetPhaseMask(phase, true);

        SendPoiMarker(player, poi.x, poi.y, poi.poiIcon, 0, 0, poi.name);
        ChatHandler(player->GetSession()).PSendSysMessage("Teleporting to {}", poi.name);
        CloseGossipMenuFor(player);

        player->TeleportTo(poi.map, poi.x, poi.y, poi.z, poi.o);

        if (phase && player->GetPhaseMask() != phase)
            player->SetPhaseMask(phase, true);

        return true;
    }
};

void AddSC_dc_dalaran_guard()
{
    new DalaranGuardNPC();
}
