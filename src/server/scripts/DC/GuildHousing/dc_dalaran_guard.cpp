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
    constexpr uint32 DALARAN_GUARD_TEXT_ID = 8000300;

    struct DalaranGuardPOI
    {
        const char* name;
        uint32 map;
        float x;
        float y;
        float z;
        float o;
        uint32 poiIcon;
        const char* gossipIcon;
        uint32 menuIcon;
    };

    static const DalaranGuardPOI dalaran_guard_pois[] =
    {
        {"Bank", 1409, 1202.201f, 1135.176f, 530.336f, 3.296f, ICON_POI_SMALL_HOUSE, "Interface\\Icons\\INV_Misc_Bag_04", GOSSIP_ICON_TAXI},
        {"Mythic+", 1409, 1102.5204f, 1198.4127f, 536.79785f, 1.6015308f, ICON_POI_SMALL_HOUSE, "Interface\\Icons\\Ability_DualWield", GOSSIP_ICON_TAXI},
        {"Training Grounds", 1409, 975.2226f, 1221.9116f, 542.86456f, 4.9999466f, ICON_POI_SMALL_HOUSE, "Interface\\Icons\\Ability_Warrior_WeaponMastery", GOSSIP_ICON_TAXI}
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

    static std::string MakeLargeGossipText(std::string const& icon, std::string const& text)
    {
        return "|T" + icon + ":40:40:-18|t " + text;
    }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        ClearGossipMenuFor(player);

        for (size_t i = 0; i < std::size(dalaran_guard_pois); ++i)
        {
            uint32 idx = static_cast<uint32>(i);
            DalaranGuardPOI const& poi = dalaran_guard_pois[i];
            std::string label = "Teleport: " + std::string(poi.name);
            std::string icon = (poi.gossipIcon && *poi.gossipIcon) ? poi.gossipIcon : "Interface\\Icons\\Spell_Arcane_TeleportDalaran";
            AddGossipItemFor(player, poi.menuIcon,
                MakeLargeGossipText(icon, label),
                GOSSIP_SENDER_MAIN, idx);
        }

        SendGossipMenuFor(player, DALARAN_GUARD_TEXT_ID, creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* /*creature*/, uint32 /*sender*/, uint32 action) override
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
