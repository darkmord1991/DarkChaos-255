#include "ScriptMgr.h"
#include "Creature.h"
#include "Player.h"
#include "Chat.h"
#include "ScriptedGossip.h"
#include "dc_guildhouse.h"
#include "DC/CrossSystem/CrossSystemUtilities.h"
#include "DC/CrossSystem/CrossSystemMapCoords.h"

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

    // POI sets are per guild-house skin. Map 1409 = the compact WotLK Dalaran house.
    static const DalaranGuardPOI dalaran_guard_pois_1409[] =
    {
        {"Bank", 1409, 1202.201f, 1135.176f, 530.336f, 3.296f, ICON_POI_SMALL_HOUSE, "Interface\\Icons\\INV_Misc_Bag_04", GOSSIP_ICON_TAXI},
        {"Mythic+", 1409, 1102.5204f, 1198.4127f, 536.79785f, 1.6015308f, ICON_POI_SMALL_HOUSE, "Interface\\Icons\\Ability_DualWield", GOSSIP_ICON_TAXI},
        {"Training Grounds", 1409, 975.2226f, 1221.9116f, 542.86456f, 4.9999466f, ICON_POI_SMALL_HOUSE, "Interface\\Icons\\Ability_Warrior_WeaponMastery", GOSSIP_ICON_TAXI}
    };

    // Map 1413 = the full multi-level Legion Dalaran. Anchors are the rigid-transform images of
    // the Legion source landmarks (see memory legion-dalaran-downport); they span the whole city,
    // from the Underbelly (Z ~= -373) up to Sunreaver's Sanctuary (Z ~= 955).
    static const DalaranGuardPOI dalaran_guard_pois_1413[] =
    {
        {"Krasus' Landing", 1413, 952.65f, 1206.65f, 543.19f, 3.822f, ICON_POI_SMALL_HOUSE, "Interface\\Icons\\Ability_Mount_Gryphon_01", GOSSIP_ICON_TAXI},
        {"Magus Commerce (Bank & Portals)", 1413, 1063.88f, 1163.76f, 536.09f, 3.822f, ICON_POI_SMALL_HOUSE, "Interface\\Icons\\INV_Misc_Bag_04", GOSSIP_ICON_TAXI},
        {"The Eventide (Vendors)", 1413, 1157.23f, 1012.90f, 525.29f, 3.822f, ICON_POI_SMALL_HOUSE, "Interface\\Icons\\INV_Misc_Coin_01", GOSSIP_ICON_TAXI},
        {"Violet Hold", 1413, 1100.53f, 1258.36f, 537.09f, 3.822f, ICON_POI_SMALL_HOUSE, "Interface\\Icons\\Ability_DualWield", GOSSIP_ICON_TAXI},
        {"Greyfang Enclave", 1413, 1237.43f, 1082.14f, 495.49f, 3.822f, ICON_POI_SMALL_HOUSE, "Interface\\Icons\\Ability_Rogue_Sprint", GOSSIP_ICON_TAXI},
        {"The Underbelly", 1413, 1130.60f, 978.88f, -372.91f, 3.822f, ICON_POI_SMALL_HOUSE, "Interface\\Icons\\Ability_Creature_Cursed_03", GOSSIP_ICON_TAXI},
        {"Chamber of the Guardian", 1413, 1274.03f, 928.46f, 749.79f, 3.822f, ICON_POI_SMALL_HOUSE, "Interface\\Icons\\Spell_Arcane_TeleportDalaran", GOSSIP_ICON_TAXI},
        {"Sunreaver's Sanctuary", 1413, 1232.42f, 952.55f, 955.19f, 3.822f, ICON_POI_SMALL_HOUSE, "Interface\\Icons\\INV_Jewelry_TrinketPVP_02", GOSSIP_ICON_TAXI}
    };

    // Resolve which POI set + count applies to the guild-house map the player will hop on.
    inline DalaranGuardPOI const* GetDalaranGuardPois(uint32 houseMap, size_t& count)
    {
        if (houseMap == 1413)
        {
            count = std::size(dalaran_guard_pois_1413);
            return dalaran_guard_pois_1413;
        }

        count = std::size(dalaran_guard_pois_1409);
        return dalaran_guard_pois_1409;
    }

    // The map the intra-house hop happens on: the player's current map if it is a guild-house
    // map, else their owned guild house's map, else the POI's own map.
    inline uint32 ResolveHouseMap(Player* player, GuildHouseData const* data, uint32 fallback)
    {
        if (player && IsGuildHouseMap(player->GetMapId()))
        {
            return player->GetMapId();
        }

        if (data && IsGuildHouseMap(data->map))
        {
            return data->map;
        }

        return fallback;
    }

}

class DalaranGuardNPC : public CreatureScript
{
public:
    DalaranGuardNPC() : CreatureScript("DalaranGuardNPC") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        ClearGossipMenuFor(player);

        // Pick the POI set for the skin the player will actually hop on (1409 vs the bigger 1413).
        GuildHouseData* data = player->GetGuildId() ? GuildHouseManager::GetGuildHouseData(player->GetGuildId()) : nullptr;
        uint32 const houseMap = ResolveHouseMap(player, data, creature->GetMapId());

        size_t count = 0;
        DalaranGuardPOI const* pois = GetDalaranGuardPois(houseMap, count);

        for (size_t i = 0; i < count; ++i)
        {
            uint32 idx = static_cast<uint32>(i);
            DalaranGuardPOI const& poi = pois[i];
            std::string label = "Teleport: " + std::string(poi.name);
            std::string icon = (poi.gossipIcon && *poi.gossipIcon) ? poi.gossipIcon : "Interface\\Icons\\Spell_Arcane_TeleportDalaran";
            AddGossipItemFor(player, poi.menuIcon,
                DCUtils::MakeLargeGossipText(icon, label),
                GOSSIP_SENDER_MAIN, idx);
        }

        SendGossipMenuFor(player, DALARAN_GUARD_TEXT_ID, creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
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

        // Intra-house POI hop on the map the player is actually in (or owns); keeps them inside
        // their own instance (same-map teleport, instance bind preserved).
        uint32 const ghMap = ResolveHouseMap(player, data, creature->GetMapId());

        size_t count = 0;
        DalaranGuardPOI const* pois = GetDalaranGuardPois(ghMap, count);

        if (action >= count)
        {
            ChatHandler(player->GetSession()).SendSysMessage("Invalid destination selected.");
            return true;
        }

        DalaranGuardPOI const& poi = pois[action];

        DC::MapCoords::SendPoiMarker(player, poi.x, poi.y, poi.poiIcon, 0, 0, poi.name);
        ChatHandler(player->GetSession()).PSendSysMessage("Teleporting to {}", poi.name);
        CloseGossipMenuFor(player);

        player->TeleportTo(ghMap, poi.x, poi.y, poi.z, poi.o);

        return true;
    }
};

void AddSC_dc_dalaran_guard()
{
    new DalaranGuardNPC();
}
